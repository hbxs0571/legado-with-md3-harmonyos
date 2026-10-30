import { preferences, relationalStore } from '@kit.ArkData';
import { fileIo, picker } from '@kit.CoreFileKit';
import { util } from '@kit.ArkTS';
import { Book } from '../model/Book';
import { ReplaceRule } from '../model/ReplaceRule';
import { RdbCodec } from './RdbCodec';
import { RdbSchema } from './RdbSchema';
import { RdbStore } from './RdbStore';

interface ReplaceRuleApplyResult {
  text: string;
  effectiveRuleIds: number[];
}
interface BookReplaceOverride {
  bookId: string;
  enabled: boolean;
}
/** 批量导入结果，供界面如实反馈新增与覆盖的数量。 */
export interface ReplaceRuleImportOutcome {
  added: number;
  updated: number;
}
/** 规则试跑结果：单条规则是否改变了样例文本。 */
export interface ReplaceRulePreviewLine {
  ruleId: number;
  name: string;
  changed: boolean;
}
/** 规则试跑的完整结果：最终文本 + 每条规则的生效情况。 */
export interface ReplaceRulePreviewResult {
  text: string;
  lines: ReplaceRulePreviewLine[];
}

/** 持久化替换规则并提供与本地章节读取共用的有序执行入口。 */
export class ReplaceRuleRepository {
  private static readonly preferenceName: string = 'legado_replace_rules';
  /** 老版本的规则 JSON 键，仅搬迁时读取。 */
  private static readonly preferenceKey: string = 'rules_v1';
  private static readonly defaultEnabledKey: string = 'default_enabled_v1';
  private static readonly bookOverridesKey: string = 'book_overrides_v1';
  private static readonly sortModeKey: string = 'sort_mode_v1';
  /** 默认分组名，与 Android 的「默认」保持一致。 */
  static readonly defaultGroup: string = '默认';
  /** 导入文件大小上限，防止误选大文件占满内存。 */
  private static readonly maximumImportBytes: number = 8 * 1024 * 1024;
  /** 分组分隔符，与上游 AppPattern.splitGroupRegex 一致。 */
  private static readonly splitGroupPattern: RegExp = /[,;，；]/;
  /** 重命名/删除分组时上游只用逗号拆分（ReplaceRuleRepository.kt:117/132），照抄这处不一致。 */
  private static readonly commaPattern: RegExp = /,/;
  private static cachedRules: ReplaceRule[] = [];
  private static defaultEnabled: boolean = true;
  private static bookOverrides: BookReplaceOverride[] = [];
  private static sortMode: string = 'desc';

  /** 全量读取：sortOrder 升序，与上游 flowAllAsc 一致。 */
  private static readonly selectAll: string =
    'SELECT `id`, `name`, `group`, `pattern`, `replacement`, `scope`, `scopeTitle`, ' +
      '`scopeContent`, `excludeScope`, `isEnabled`, `isRegex`, `timeoutMillisecond`, `sortOrder` ' +
      'FROM `replace_rules` ORDER BY `sortOrder` ASC';

  private static readonly upsertSql: string =
    'INSERT OR REPLACE INTO `replace_rules` (`id`, `name`, `group`, `pattern`, `replacement`, `scope`, ' +
      '`scopeTitle`, `scopeContent`, `excludeScope`, `isEnabled`, `isRegex`, `timeoutMillisecond`, `sortOrder`) ' +
      'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)';

  private static readonly deleteSql: string = 'DELETE FROM `replace_rules` WHERE `id` = ?';

  private static readonly deleteByIdsSql: string = 'DELETE FROM `replace_rules` WHERE `id` IN (';

  private static readonly updateEnabledSql: string =
    'UPDATE `replace_rules` SET `isEnabled` = ? WHERE `id` = ?';

  private static readonly updateEnabledByIdsSql: string =
    'UPDATE `replace_rules` SET `isEnabled` = ? WHERE `id` IN (';

  private static readonly updateOrderSql: string =
    'UPDATE `replace_rules` SET `sortOrder` = ? WHERE `id` = ?';

  private static readonly updateGroupSql: string =
    'UPDATE `replace_rules` SET `group` = ? WHERE `id` = ?';

  /** 无分组规则：与上游 noGroup 一致（group 为 NULL 或空串）。 */
  private static readonly selectNoGroupSql: string =
    'SELECT * FROM `replace_rules` WHERE `group` IS NULL OR `group` = \'\'';

  /** 按分组名模糊捞候选：与上游 getByGroup 一致。 */
  private static readonly selectByGroupLikeSql: string =
    'SELECT * FROM `replace_rules` WHERE `group` LIKE \'%\' || ? || \'%\'';

  static getAll(): ReplaceRule[] {
    return ReplaceRuleRepository.cachedRules.map((rule: ReplaceRule) => ReplaceRuleRepository.copyRule(rule));
  }

  static async load(context: Context): Promise<ReplaceRule[]> {
    let needsMigrate = false;
    try {
      // 只有三个纯设置项留在 preferences：它们不是表数据，上游也放在 PreferKey 里。
      const store = await preferences.getPreferences(context, ReplaceRuleRepository.preferenceName);
      const savedDefault = await store.get(ReplaceRuleRepository.defaultEnabledKey, true);
      ReplaceRuleRepository.defaultEnabled = typeof savedDefault === 'boolean' ? savedDefault : true;
      const savedOverrides = await store.get(ReplaceRuleRepository.bookOverridesKey, '[]');
      ReplaceRuleRepository.bookOverrides = typeof savedOverrides === 'string'
        ? ReplaceRuleRepository.parseOverrides(savedOverrides) : [];
      const savedSortMode = await store.get(ReplaceRuleRepository.sortModeKey, 'desc');
      ReplaceRuleRepository.sortMode = typeof savedSortMode === 'string' &&
        ReplaceRuleRepository.isValidSortMode(savedSortMode) ? savedSortMode : 'desc';
      const rules = await ReplaceRuleRepository.loadFromDb(context);
      ReplaceRuleRepository.cachedRules = rules.map((rule: ReplaceRule) => {
        if (ReplaceRuleRepository.needsScopeMigration(rule)) {
          needsMigrate = true;
          return ReplaceRuleRepository.withScopeContent(rule, true);
        }
        return rule;
      });
    } catch (_) {
      ReplaceRuleRepository.cachedRules = [];
      needsMigrate = false;
    }
    // 迁移结果写回存储，避免每次启动重复判断，也让其他读取路径看到一致的数据。
    if (needsMigrate) {
      try {
        await ReplaceRuleRepository.writeAll(context, ReplaceRuleRepository.cachedRules);
      } catch (_) {
        // 写回失败不影响本次已加载的规则，下次启动会再次尝试。
      }
    }
    return ReplaceRuleRepository.getAll();
  }

  /** 整表覆盖写：只在设置项迁移这种一次性场景使用，常规写入走单行 SQL。 */
  private static async writeAll(context: Context, rules: ReplaceRule[]): Promise<void> {
    const store = await RdbStore.getStore(context);
    await RdbSchema.ensure(store);
    store.beginTransaction();
    try {
      for (const item of rules) {
        await store.executeSql(ReplaceRuleRepository.upsertSql, ReplaceRuleRepository.toArgs(item));
      }
      store.commit();
    } catch (error) {
      store.rollBack();
      throw new Error(`替换规则写入失败：${error instanceof Error ? error.message : String(error)}`);
    }
  }

  /**
   * 按数组下标重写 sortOrder。
   * 与上游 updateAllOrders 一致，只更新序号真变了的行，避免无谓写入。
   */
  private static async writeOrders(context: Context, rules: ReplaceRule[]): Promise<void> {
    const ordered = rules.map((rule: ReplaceRule, index: number) => {
      const copy = ReplaceRuleRepository.copyRule(rule);
      copy.order = index;
      return copy;
    });
    const store = await RdbStore.getStore(context);
    await RdbSchema.ensure(store);
    store.beginTransaction();
    try {
      for (const item of ordered) {
        const previous = ReplaceRuleRepository.cachedRules.find((rule: ReplaceRule) => rule.id === item.id);
        if (previous !== undefined && previous.order === item.order) {
          continue;
        }
        await store.executeSql(ReplaceRuleRepository.updateOrderSql, [item.order, item.id]);
      }
      store.commit();
    } catch (error) {
      store.rollBack();
      throw new Error(`替换规则排序失败：${error instanceof Error ? error.message : String(error)}`);
    }
    ReplaceRuleRepository.cachedRules = ordered;
  }

  /** 从 DB 读整张 replace_rules 表。 */
  private static async loadFromDb(context: Context): Promise<ReplaceRule[]> {
    const store = await RdbStore.getStore(context);
    await RdbSchema.ensure(store);
    const resultSet = await store.querySql(ReplaceRuleRepository.selectAll);
    try {
      return ReplaceRuleRepository.readAll(resultSet);
    } finally {
      resultSet.close();
    }
  }

  /** 从老 preferences 读规则，仅供搬迁使用。 */
  private static async loadFromPreferences(context: Context): Promise<ReplaceRule[]> {
    const store = await preferences.getPreferences(context, ReplaceRuleRepository.preferenceName);
    const raw = await store.get(ReplaceRuleRepository.preferenceKey, '[]');
    if (typeof raw !== 'string') {
      return [];
    }
    const parsed: ReplaceRule[] = JSON.parse(raw);
    return parsed
      .filter((item: ReplaceRule) => ReplaceRuleRepository.isRule(item))
      .sort((left: ReplaceRule, right: ReplaceRule) => left.order - right.order || left.id - right.id)
      .map((rule: ReplaceRule) => ReplaceRuleRepository.copyRule(rule));
  }

  /**
   * 把 preferences 里的老规则搬进 DB；由 RdbMigration 在事务内调用，这里不开事务、不写标记。
   * 只读不写：老数据在搬迁完成后仍原样保留（计划要求至少留一个大版本）。
   */
  static async migrateFromPreferences(context: Context, store: relationalStore.RdbStore): Promise<void> {
    const legacy = await ReplaceRuleRepository.loadFromPreferences(context);
    if (legacy.length === 0) {
      return;
    }
    const ordered = legacy.map((rule: ReplaceRule, index: number) => {
      const copy = ReplaceRuleRepository.copyRule(rule);
      copy.order = index;
      return copy;
    });
    await store.executeSql('DELETE FROM `replace_rules`');
    for (const rule of ordered) {
      await store.executeSql(ReplaceRuleRepository.upsertSql, ReplaceRuleRepository.toArgs(rule));
    }
    ReplaceRuleRepository.cachedRules = ordered;
  }

  /** 把结果集读成规则数组；可空文本列读出 undefined 后折成空串。 */
  private static readAll(resultSet: relationalStore.ResultSet): ReplaceRule[] {
    const rules: ReplaceRule[] = [];
    while (resultSet.goToNextRow()) {
      const group = RdbCodec.optionalText(resultSet, resultSet.getColumnIndex('group'));
      const scope = RdbCodec.optionalText(resultSet, resultSet.getColumnIndex('scope'));
      const excludeScope = RdbCodec.optionalText(resultSet, resultSet.getColumnIndex('excludeScope'));
      rules.push({
        id: RdbCodec.integer(resultSet, resultSet.getColumnIndex('id')),
        name: RdbCodec.text(resultSet, resultSet.getColumnIndex('name')),
        group: group === undefined ? '' : group,
        pattern: RdbCodec.text(resultSet, resultSet.getColumnIndex('pattern')),
        replacement: RdbCodec.text(resultSet, resultSet.getColumnIndex('replacement')),
        scope: scope === undefined ? '' : scope,
        scopeTitle: RdbCodec.boolean(resultSet, resultSet.getColumnIndex('scopeTitle'), false),
        scopeContent: RdbCodec.boolean(resultSet, resultSet.getColumnIndex('scopeContent'), true),
        excludeScope: excludeScope === undefined ? '' : excludeScope,
        isEnabled: RdbCodec.boolean(resultSet, resultSet.getColumnIndex('isEnabled'), true),
        isRegex: RdbCodec.boolean(resultSet, resultSet.getColumnIndex('isRegex'), true),
        timeoutMillisecond: RdbCodec.integer(resultSet, resultSet.getColumnIndex('timeoutMillisecond'), 3000),
        order: RdbCodec.integer(resultSet, resultSet.getColumnIndex('sortOrder'))
      });
    }
    return rules;
  }

  /** 转成 executeSql 的绑定参数；空串写回 NULL，与上游的可空字段语义对齐。 */
  private static toArgs(rule: ReplaceRule): relationalStore.ValueType[] {
    return [
      rule.id,
      rule.name,
      rule.group.length === 0 ? null : rule.group,
      rule.pattern,
      rule.replacement,
      rule.scope.length === 0 ? null : rule.scope,
      rule.scopeTitle ? 1 : 0,
      rule.scopeContent ? 1 : 0,
      rule.excludeScope.length === 0 ? null : rule.excludeScope,
      rule.isEnabled ? 1 : 0,
      rule.isRegex ? 1 : 0,
      rule.timeoutMillisecond,
      rule.order
    ];
  }

  /** 把 id 列表拼成 `?, ?, ?` 占位串，供 IN 查询/更新使用。 */
  private static placeholders(count: number): string {
    const parts: string[] = [];
    for (let index = 0; index < count; index++) {
      parts.push('?');
    }
    return parts.join(', ');
  }

  /**
   * 旧版本新建规则时 scopeContent 初始值为 false，且不会随保存纠正，
   * 导致这些规则既不作用于正文也不出现在试跑结果里，实际等于无效规则。
   * 上游 ReplaceRule 的 scopeContent 默认为 true，因此标题与正文都不生效的规则
   * 视为上述历史缺陷遗留，加载时补成正文规则。
   */
  private static needsScopeMigration(rule: ReplaceRule): boolean {
    return rule.scopeTitle === false && rule.scopeContent === false;
  }

  /**
   * 返回规则里出现过的全部分组（不含「全部」「默认」这类界面占位项）。
   *
   * 与上游 ReplaceRuleDao.dealGroups 一致：分组不单独存储，
   * 每条规则的 group 可以是多值串（"仙侠,都市"），按 [,;，；] 拆分后去重，
   * 再按中文拼音序排列。因此「空分组」这个概念不存在——规则删光，分组就消失。
   *
   * 这里不前置「默认」：上游 allGroups 也不前置，由各界面自己拼
   * （列表页拼「全部」+ 本结果，编辑页拼「默认」+ 本结果）。
   */
  static getGroups(): string[] {
    const collected: string[] = [];
    ReplaceRuleRepository.cachedRules.forEach((rule: ReplaceRule) => {
      ReplaceRuleRepository.splitGroups(rule.group).forEach((group: string) => {
        if (group.length > 0 && !collected.includes(group)) {
          collected.push(group);
        }
      });
    });
    collected.sort((left: string, right: string) => left.localeCompare(right, 'zh-Hans-CN'));
    return collected;
  }

  /** 按上游 splitNotBlank 语义拆分多值分组串：拆分后逐项 trim 并丢掉空项。 */
  static splitGroups(group: string): string[] {
    if (typeof group !== 'string' || group.length === 0) {
      return [];
    }
    const parts = group.split(ReplaceRuleRepository.splitGroupPattern);
    const result: string[] = [];
    parts.forEach((part: string) => {
      const trimmed = part.trim();
      if (trimmed.length > 0) {
        result.push(trimmed);
      }
    });
    return result;
  }

  /**
   * 判断一条规则的 group 是否包含指定分组。
   * 界面按分组筛选时必须用这个，不能直接比较整串——group 是多值字段。
   */
  static groupContains(group: string, target: string): boolean {
    return ReplaceRuleRepository.splitGroups(group).includes(target);
  }

  static getSortMode(): string {
    return ReplaceRuleRepository.sortMode;
  }

  static async setSortMode(context: Context, mode: string): Promise<void> {
    if (!ReplaceRuleRepository.isValidSortMode(mode)) { return; }
    const store = await preferences.getPreferences(context, ReplaceRuleRepository.preferenceName);
    await store.put(ReplaceRuleRepository.sortModeKey, mode);
    await store.flush();
    ReplaceRuleRepository.sortMode = mode;
  }

  private static isValidSortMode(mode: string): boolean {
    return mode === 'asc' || mode === 'desc' || mode === 'name_asc' || mode === 'name_desc';
  }

  static getDefaultEnabled(): boolean {
    return ReplaceRuleRepository.defaultEnabled;
  }

  static isBookEnabled(book: Book): boolean {
    const override = ReplaceRuleRepository.bookOverrides.find((item: BookReplaceOverride) => item.bookId === book.id);
    return override === undefined ? ReplaceRuleRepository.defaultEnabled : override.enabled;
  }

  static isBookUsingDefault(book: Book): boolean {
    return !ReplaceRuleRepository.bookOverrides.some((item: BookReplaceOverride) => item.bookId === book.id);
  }

  static isRuleApplicableToBook(rule: ReplaceRule, book: Book): boolean {
    return ReplaceRuleRepository.matchesBook(rule, book);
  }

  static async setDefaultEnabled(context: Context, enabled: boolean): Promise<void> {
    const store = await preferences.getPreferences(context, ReplaceRuleRepository.preferenceName);
    await store.put(ReplaceRuleRepository.defaultEnabledKey, enabled);
    await store.flush();
    ReplaceRuleRepository.defaultEnabled = enabled;
  }

  static async setBookEnabled(context: Context, book: Book, enabled: boolean): Promise<void> {
    const next = ReplaceRuleRepository.bookOverrides.filter((item: BookReplaceOverride) => item.bookId !== book.id);
    next.push({ bookId: book.id, enabled: enabled });
    await ReplaceRuleRepository.persistBookOverrides(context, next);
  }

  static async clearBookEnabledOverride(context: Context, book: Book): Promise<void> {
    const next = ReplaceRuleRepository.bookOverrides.filter((item: BookReplaceOverride) => item.bookId !== book.id);
    await ReplaceRuleRepository.persistBookOverrides(context, next);
  }

  private static async persistBookOverrides(context: Context, next: BookReplaceOverride[]): Promise<void> {
    const store = await preferences.getPreferences(context, ReplaceRuleRepository.preferenceName);
    await store.put(ReplaceRuleRepository.bookOverridesKey, JSON.stringify(next));
    await store.flush();
    ReplaceRuleRepository.bookOverrides = next;
  }

  static async save(context: Context, rule: ReplaceRule): Promise<void> {
    if (!ReplaceRuleRepository.isRule(rule) || rule.pattern.trim().length === 0) {
      throw new Error('替换规则无效');
    }
    if (rule.isRegex) {
      try {
        new RegExp(rule.pattern);
      } catch (_) {
        throw new Error('正则表达式无效');
      }
      if (rule.pattern.endsWith('|') && !rule.pattern.endsWith('\\|')) {
        throw new Error('正则表达式无效');
      }
    }
    const existingIndex = ReplaceRuleRepository.cachedRules.findIndex((item: ReplaceRule) => item.id === rule.id);
    const next = [...ReplaceRuleRepository.cachedRules];
    const target = ReplaceRuleRepository.copyRule(rule);
    if (existingIndex >= 0) {
      // 编辑已有规则时保留原顺序，避免改一次名字就跳到列表末尾。
      target.order = next[existingIndex].order;
      next[existingIndex] = target;
    } else {
      // 新规则追加到末尾：上游取 maxOrder + 1，这里用当前最大序号 + 1，语义一致。
      let maxOrder = -1;
      next.forEach((item: ReplaceRule) => {
        if (item.order > maxOrder) {
          maxOrder = item.order;
        }
      });
      target.order = maxOrder + 1;
      next.push(target);
    }
    const store = await RdbStore.getStore(context);
    await RdbSchema.ensure(store);
    await store.executeSql(ReplaceRuleRepository.upsertSql, ReplaceRuleRepository.toArgs(target));
    ReplaceRuleRepository.cachedRules = next;
  }

  static async setEnabled(context: Context, id: number, enabled: boolean): Promise<void> {
    const store = await RdbStore.getStore(context);
    await RdbSchema.ensure(store);
    await store.executeSql(ReplaceRuleRepository.updateEnabledSql, [enabled ? 1 : 0, id]);
    ReplaceRuleRepository.cachedRules = ReplaceRuleRepository.cachedRules.map((rule: ReplaceRule) =>
      rule.id === id ? ReplaceRuleRepository.withEnabled(rule, enabled) : rule);
  }

  /**
   * 批量启用/停用。
   * 只统计状态真正发生变化的条目，界面据此如实反馈，
   * 避免把「本来就已经启用」的规则算作本次操作的结果。
   * @returns 实际改变的条数。
   */
  static async setEnabledBatch(context: Context, ids: number[], enabled: boolean): Promise<number> {
    if (ids.length === 0) {
      return 0;
    }
    const changedIds: number[] = [];
    const next = ReplaceRuleRepository.cachedRules.map((rule: ReplaceRule) => {
      if (ids.includes(rule.id) && rule.isEnabled !== enabled) {
        changedIds.push(rule.id);
        return ReplaceRuleRepository.withEnabled(rule, enabled);
      }
      return rule;
    });
    if (changedIds.length === 0) {
      return 0;
    }
    const store = await RdbStore.getStore(context);
    await RdbSchema.ensure(store);
    const sql = ReplaceRuleRepository.updateEnabledByIdsSql +
      ReplaceRuleRepository.placeholders(changedIds.length) + ')';
    const args: relationalStore.ValueType[] = [enabled ? 1 : 0];
    changedIds.forEach((id: number) => args.push(id));
    await store.executeSql(sql, args);
    ReplaceRuleRepository.cachedRules = next;
    return changedIds.length;
  }

  /**
   * 批量删除。
   * @returns 实际删除的条数，用于区分「没选中」与「选中项已不存在」。
   */
  static async removeBatch(context: Context, ids: number[]): Promise<number> {
    if (ids.length === 0) {
      return 0;
    }
    const next = ReplaceRuleRepository.cachedRules.filter((rule: ReplaceRule) => !ids.includes(rule.id));
    const removed = ReplaceRuleRepository.cachedRules.length - next.length;
    if (removed === 0) {
      return 0;
    }
    const store = await RdbStore.getStore(context);
    await RdbSchema.ensure(store);
    const sql = ReplaceRuleRepository.deleteByIdsSql + ReplaceRuleRepository.placeholders(ids.length) + ')';
    const args: relationalStore.ValueType[] = [];
    ids.forEach((id: number) => args.push(id));
    await store.executeSql(sql, args);
    ReplaceRuleRepository.cachedRules = next;
    return removed;
  }

  /** 批量移到当前排序下的最前或最后，方向规则同 moveToTop。 */
  static async moveBatchToTop(context: Context, ids: number[]): Promise<number> {
    return ReplaceRuleRepository.moveBatchToEdge(context, ids, true);
  }

  /** 批量移到当前排序下的最后，方向规则同 moveToTop。 */
  static async moveBatchToBottom(context: Context, ids: number[]): Promise<number> {
    return ReplaceRuleRepository.moveBatchToEdge(context, ids, false);
  }

  /**
   * 把选中规则整体移到数组一端，选中项之间的相对顺序保持不变。
   * 与单条 moveToEdge 一致：desc 模式下数组尾部对应视觉顶部，故取反。
   */
  static async moveBatchToEdge(context: Context, ids: number[], toTop: boolean): Promise<number> {
    if (ids.length === 0) {
      return 0;
    }
    const selected = ReplaceRuleRepository.cachedRules.filter((rule: ReplaceRule) => ids.includes(rule.id));
    if (selected.length === 0) {
      return 0;
    }
    const rest = ReplaceRuleRepository.cachedRules.filter((rule: ReplaceRule) => !ids.includes(rule.id));
    const toArrayHead = ReplaceRuleRepository.sortMode === 'desc' ? !toTop : toTop;
    const next = toArrayHead ? selected.concat(rest) : rest.concat(selected);
    await ReplaceRuleRepository.writeOrders(context, next);
    return selected.length;
  }

  static async remove(context: Context, id: number): Promise<void> {
    const next = ReplaceRuleRepository.cachedRules.filter((rule: ReplaceRule) => rule.id !== id);
    if (next.length === ReplaceRuleRepository.cachedRules.length) {
      return;
    }
    const store = await RdbStore.getStore(context);
    await RdbSchema.ensure(store);
    await store.executeSql(ReplaceRuleRepository.deleteSql, [id]);
    ReplaceRuleRepository.cachedRules = next;
  }

  /**
   * 新建分组。
   *
   * 与上游 ReplaceRuleRepository.addGroup 一致：分组不单独存储，
   * 所以「新建分组」实际是把当前所有无分组的规则批量归入该组。
   * 组里没有规则时分组自然不存在，这正是上游的行为。
   */
  static async addGroup(context: Context, group: string): Promise<void> {
    const name = group.trim();
    if (name.length === 0 || name === ReplaceRuleRepository.defaultGroup) {
      return;
    }
    const store = await RdbStore.getStore(context);
    await RdbSchema.ensure(store);
    const resultSet = await store.querySql(ReplaceRuleRepository.selectNoGroupSql);
    const targets: ReplaceRule[] = [];
    try {
      targets.push(...ReplaceRuleRepository.readAll(resultSet));
    } finally {
      resultSet.close();
    }
    if (targets.length === 0) {
      return;
    }
    store.beginTransaction();
    try {
      for (const item of targets) {
        await store.executeSql(ReplaceRuleRepository.updateGroupSql, [name, item.id]);
      }
      store.commit();
    } catch (error) {
      store.rollBack();
      throw new Error(`分组创建失败：${error instanceof Error ? error.message : String(error)}`);
    }
    const changed = new Map<number, string>();
    targets.forEach((item: ReplaceRule) => changed.set(item.id, name));
    ReplaceRuleRepository.cachedRules = ReplaceRuleRepository.cachedRules.map((rule: ReplaceRule) => {
      const nextGroup = changed.get(rule.id);
      return nextGroup === undefined ? rule : ReplaceRuleRepository.withGroup(rule, nextGroup);
    });
  }

  /**
   * 重命名分组，同时改写该分组下所有规则的 group 字段。
   * 目标是默认分组时不处理，避免与内置分组语义冲突。
   *
   * 与上游 upGroup 一致：先按 `group LIKE '%名字%'` 捞候选，再逐条拆分多值串，
   * 删旧名加新名后拼回。上游这里只用逗号拆分（`splitNotBlank(",")`），
   * 与 getGroups 用 [,;，；] 拆分并不一致，此处照抄。
   */
  static async renameGroup(context: Context, oldName: string, newName: string): Promise<void> {
    const from = oldName.trim();
    const to = newName.trim();
    if (from.length === 0 || to.length === 0 || from === to ||
      from === ReplaceRuleRepository.defaultGroup || to === ReplaceRuleRepository.defaultGroup) {
      return;
    }
    if (ReplaceRuleRepository.getGroups().includes(to)) {
      throw new Error('分组名称已存在');
    }
    await ReplaceRuleRepository.rewriteGroups(context, from, to);
  }

  /**
   * 删除分组：把该分组从规则的 group 字段里摘掉，其余分组保留。
   * 与上游 delGroup 一致，同样只按逗号拆分。
   */
  static async removeGroup(context: Context, group: string): Promise<void> {
    const name = group.trim();
    if (name.length === 0 || name === ReplaceRuleRepository.defaultGroup) {
      return;
    }
    await ReplaceRuleRepository.rewriteGroups(context, name, '');
  }

  /**
   * 把候选规则 group 里的 oldName 换成 newName（newName 为空表示删除该分组）。
   * 上游用 HashSet 去重后 TextUtils.join(",") 拼回，这里用数组去重再 join。
   */
  private static async rewriteGroups(context: Context, oldName: string, newName: string): Promise<void> {
    const store = await RdbStore.getStore(context);
    await RdbSchema.ensure(store);
    const resultSet = await store.querySql(ReplaceRuleRepository.selectByGroupLikeSql, [oldName]);
    const candidates: ReplaceRule[] = [];
    try {
      candidates.push(...ReplaceRuleRepository.readAll(resultSet));
    } finally {
      resultSet.close();
    }
    if (candidates.length === 0) {
      return;
    }
    const rewritten = new Map<number, string>();
    candidates.forEach((item: ReplaceRule) => {
      const parts = item.group.split(ReplaceRuleRepository.commaPattern);
      const kept: string[] = [];
      parts.forEach((part: string) => {
        const trimmed = part.trim();
        if (trimmed.length === 0 || trimmed === oldName) {
          return;
        }
        if (!kept.includes(trimmed)) {
          kept.push(trimmed);
        }
      });
      if (newName.length > 0 && !kept.includes(newName)) {
        kept.push(newName);
      }
      rewritten.set(item.id, kept.join(','));
    });
    store.beginTransaction();
    try {
      for (const item of candidates) {
        const next = rewritten.get(item.id);
        if (next === undefined) {
          continue;
        }
        await store.executeSql(ReplaceRuleRepository.updateGroupSql, [next.length === 0 ? null : next, item.id]);
      }
      store.commit();
    } catch (error) {
      store.rollBack();
      throw new Error(`分组改写失败：${error instanceof Error ? error.message : String(error)}`);
    }
    ReplaceRuleRepository.cachedRules = ReplaceRuleRepository.cachedRules.map((rule: ReplaceRule) => {
      const nextGroup = rewritten.get(rule.id);
      return nextGroup === undefined ? rule : ReplaceRuleRepository.withGroup(rule, nextGroup);
    });
  }

  /**
   * 把规则移到当前排序下的最前。
   * order 恒等于数组下标，因此「新的在前」（desc）模式下移到数组末尾才是视觉最前。
   */
  static async moveToTop(context: Context, id: number): Promise<void> {
    await ReplaceRuleRepository.moveToEdge(context, id, true);
  }

  /** 把规则移到当前排序下的最后，方向规则同 moveToTop。 */
  static async moveToBottom(context: Context, id: number): Promise<void> {
    await ReplaceRuleRepository.moveToEdge(context, id, false);
  }

  /**
   * 拖拽排序：把 from 位置的规则挪到 to 位置。
   *
   * 参数用「视觉下标」而不是数组下标：列表可能被搜索或分组筛选过，
   * 界面拿到的是筛选结果里的位置，这里先按 id 换算回存储数组的真实位置，
   * 避免筛选态下拖拽改错规则。
   *
   * 与上游 BaseRuleViewModel.moveItemInList() 语义一致：移除后插入，
   * 返回 false 表示下标越界或规则已不存在，界面不必刷新。
   */
  static async moveRule(context: Context, fromId: number, toId: number): Promise<boolean> {
    const rules = ReplaceRuleRepository.cachedRules;
    const fromIndex = rules.findIndex((rule: ReplaceRule) => rule.id === fromId);
    const toIndex = rules.findIndex((rule: ReplaceRule) => rule.id === toId);
    if (fromIndex < 0 || toIndex < 0 || fromIndex === toIndex) {
      return false;
    }
    const next = [...rules];
    const moved = next.splice(fromIndex, 1)[0];
    next.splice(toIndex, 0, moved);
    await ReplaceRuleRepository.writeOrders(context, next);
    return true;
  }

  /**
   * 单条移到一端。
   * 与上游 toTop/toBottom 一致：不改动其他规则，只把本条的 order 设成
   * 全表最小 - 1（移到数组头部）或全表最大 + 1（移到数组尾部），
   * 其余规则的 order 保持不变，下次整表重排时再收敛。
   */
  private static async moveToEdge(context: Context, id: number, toTop: boolean): Promise<void> {
    const rules = ReplaceRuleRepository.cachedRules;
    const index = rules.findIndex((rule: ReplaceRule) => rule.id === id);
    if (index < 0) {
      return;
    }
    // desc 模式下数组尾部对应视觉顶部，故取反。
    const toArrayHead = ReplaceRuleRepository.sortMode === 'desc' ? !toTop : toTop;
    let minOrder = Number.MAX_SAFE_INTEGER;
    let maxOrder = Number.MIN_SAFE_INTEGER;
    rules.forEach((rule: ReplaceRule) => {
      if (rule.order < minOrder) {
        minOrder = rule.order;
      }
      if (rule.order > maxOrder) {
        maxOrder = rule.order;
      }
    });
    const targetOrder = toArrayHead ? minOrder - 1 : maxOrder + 1;
    const moved = ReplaceRuleRepository.withOrder(rules[index], targetOrder);
    const next = rules.map((rule: ReplaceRule) => rule.id === id ? moved : rule);
    const store = await RdbStore.getStore(context);
    await RdbSchema.ensure(store);
    await store.executeSql(ReplaceRuleRepository.updateOrderSql, [targetOrder, id]);
    ReplaceRuleRepository.cachedRules = next;
  }

  /**
   * 批量导入规则。
   *
   * 去重口径：同 id 或同 pattern 视为同一条规则，命中时保留已有规则的 id 与 order，
   * 用导入内容覆盖其余字段。这样重复导入同一份文件不会产生副本，
   * 也符合 Android 以 pattern 判断「是否同一条规则」的 hasChanged 语义。
   *
   * @returns 新增条数与更新条数，供界面如实反馈。
   */
  static async importRules(context: Context, incoming: ReplaceRule[]): Promise<ReplaceRuleImportOutcome> {
    if (incoming.length === 0) {
      return { added: 0, updated: 0 };
    }
    const next = [...ReplaceRuleRepository.cachedRules];
    let added: number = 0;
    let updated: number = 0;
    incoming.forEach((rule: ReplaceRule) => {
      const index = next.findIndex((item: ReplaceRule) => item.id === rule.id || item.pattern === rule.pattern);
      if (index >= 0) {
        const existing = next[index];
        const merged = ReplaceRuleRepository.copyRule(rule);
        merged.id = existing.id;
        merged.order = existing.order;
        next[index] = merged;
        updated += 1;
      } else {
        const created = ReplaceRuleRepository.copyRule(rule);
        created.order = next.length;
        next.push(created);
        added += 1;
      }
    });
    if (added === 0 && updated === 0) {
      return { added: 0, updated: 0 };
    }
    const store = await RdbStore.getStore(context);
    await RdbSchema.ensure(store);
    store.beginTransaction();
    try {
      for (const item of next) {
        await store.executeSql(ReplaceRuleRepository.upsertSql, ReplaceRuleRepository.toArgs(item));
      }
      store.commit();
    } catch (error) {
      store.rollBack();
      throw new Error(`替换规则导入失败：${error instanceof Error ? error.message : String(error)}`);
    }
    ReplaceRuleRepository.cachedRules = next;
    return { added: added, updated: updated };
  }

  /** 导出为与本项目导入格式一致的 JSON 文本；只导出给定规则。 */
  static exportRules(rules: ReplaceRule[]): string {
    const ordered = rules.map((rule: ReplaceRule, index: number) => {
      const copy = ReplaceRuleRepository.copyRule(rule);
      copy.order = index;
      return copy;
    });
    return JSON.stringify(ordered, null, 2);
  }

  /**
   * 弹出文件选择器读取规则文件文本。
   * 用户取消时返回空字符串，由调用方区分「取消」与「读取失败」。
   * 文件上限 8 MB：规则文本通常只有几十 KB，超限说明选错了文件。
   * 注意：选择器返回的是 docs:// 授权 URI，必须先 openSync 拿到 fd 再读，
   * 直接对 URI 调 readTextSync 在部分设备上会失败。
   */
  static async pickImportFile(context: Context): Promise<string> {
    const options = new picker.DocumentSelectOptions();
    options.fileSuffixFilters = ['替换规则|.json', '文本规则|.txt'];
    options.maxSelectNumber = 1;
    const uris = await new picker.DocumentViewPicker(context).select(options);
    const uri = uris[0];
    if (uri === undefined) {
      return '';
    }
    const source = fileIo.openSync(uri, fileIo.OpenMode.READ_ONLY);
    try {
      const size = fileIo.statSync(source.fd).size;
      if (size <= 0) {
        throw new Error('规则文件为空');
      }
      if (size > ReplaceRuleRepository.maximumImportBytes) {
        throw new Error('规则文件超过 8 MB');
      }
      const buffer = new ArrayBuffer(size);
      const read = fileIo.readSync(source.fd, buffer);
      const decoder = util.TextDecoder.create('utf-8');
      return decoder.decodeToString(new Uint8Array(buffer.slice(0, read)));
    } finally {
      fileIo.closeSync(source);
    }
  }

  /**
   * 弹出保存对话框写入导出文本。
   * @returns 是否真的写入了文件；用户取消返回 false。
   */
  static async saveExportFile(context: Context, content: string): Promise<boolean> {
    const options = new picker.DocumentSaveOptions();
    options.newFileNames = [`replaceRules-${Date.now()}.json`];
    options.fileSuffixChoices = ['JSON 规则|.json'];
    const uris = await new picker.DocumentViewPicker(context).save(options);
    const uri = uris[0];
    if (uri === undefined) {
      return false;
    }
    // 内容直接传字符串，由底层按 UTF-8 编码，避免 Uint8Array 导出触发 13900020（EINVAL）。
    const target = fileIo.openSync(uri, fileIo.OpenMode.WRITE_ONLY | fileIo.OpenMode.TRUNC);
    try {
      fileIo.writeSync(target.fd, content);
    } finally {
      fileIo.closeSync(target);
    }
    return true;
  }

  static applyContent(book: Book, chapterTitle: string, content: string): string {
    return ReplaceRuleRepository.applyContentWithResult(book, chapterTitle, content).text;
  }

  /**
   * 对样例文本试跑当前启用的规则，用于编辑页的「测试」按钮。
   * 与 applyContentWithResult 保持同一执行口径：先按行 trim 归一化，再按 order 顺序逐条应用。
   * 这里刻意不传 Book：测试时用户关心的是规则本身的效果，
   * 用书籍作用域过滤会让「为什么这条没生效」变得难以解释。
   * @returns 每条规则是否真的改变了文本，以及最终的文本。
   */
  static previewContent(source: string): ReplaceRulePreviewResult {
    let result = ReplaceRuleRepository.normalizeLines(source);
    const lines: ReplaceRulePreviewLine[] = [];
    ReplaceRuleRepository.cachedRules
      .filter((rule: ReplaceRule) => rule.isEnabled && rule.scopeContent && rule.pattern.length > 0)
      .forEach((rule: ReplaceRule) => {
        const before = result;
        try {
          const replaced = rule.isRegex
            ? result.replace(new RegExp(rule.pattern, 'g'), rule.replacement)
            : result.split(rule.pattern).join(rule.replacement);
          result = replaced;
        } catch (_) {
          // 无效正则不改变文本，在结果里标为未生效，让用户看到是规则本身有问题。
        }
        lines.push({
          ruleId: rule.id,
          name: rule.name.length > 0 ? rule.name : rule.pattern,
          changed: result !== before
        });
      });
    return { text: result, lines: lines };
  }

  /** 与 applyContent 相同的行归一化：逐行 trim 后用 \n 连接。 */
  static normalizeLines(source: string): string {
    return source.split(/\r?\n/).map((line: string) => line.trim()).join('\n');
  }

  static applyContentWithResult(book: Book, chapterTitle: string, content: string): ReplaceRuleApplyResult {
    if (!ReplaceRuleRepository.isBookEnabled(book)) {
      return { text: content, effectiveRuleIds: [] };
    }
    const rules = ReplaceRuleRepository.cachedRules.filter((rule: ReplaceRule) =>
      rule.isEnabled && rule.scopeContent && ReplaceRuleRepository.matchesBook(rule, book));
    let result = content.split(/\r?\n/).map((line: string) => line.trim()).join('\n');
    const effectiveRuleIds: number[] = [];
    for (const rule of rules) {
      if (rule.pattern.length === 0) {
        continue;
      }
      try {
        const replaced = rule.isRegex
          ? result.replace(new RegExp(rule.pattern, 'g'), rule.replacement)
          : result.split(rule.pattern).join(rule.replacement);
        if (replaced !== result) {
          result = replaced;
          effectiveRuleIds.push(rule.id);
        }
      } catch (_) {
        // 无效或当前运行时不支持的正则不改变正文，避免阅读中断。
      }
    }
    return { text: result, effectiveRuleIds: effectiveRuleIds };
  }
  static applyContentForLength(book: Book, content: string): string {
    if (!ReplaceRuleRepository.isBookEnabled(book)) {
      return content;
    }
    let result = content.split(/\r?\n/).map((line: string) => line.trim()).join('\n');
    const rules = ReplaceRuleRepository.cachedRules.filter((rule: ReplaceRule) =>
      rule.isEnabled && rule.scopeContent && !rule.isRegex && ReplaceRuleRepository.matchesBook(rule, book));
    for (const rule of rules) {
      if (rule.pattern.length > 0) {
        result = result.split(rule.pattern).join(rule.replacement);
      }
    }
    return result;
  }
  static applyTitle(book: Book, title: string): string {
    let result = title.replace(/[\r\n]/g, '');
    if (!ReplaceRuleRepository.isBookEnabled(book)) {
      return result;
    }
    for (const rule of ReplaceRuleRepository.cachedRules) {
      if (!rule.isEnabled || !rule.scopeTitle || !ReplaceRuleRepository.matchesBook(rule, book) ||
        rule.pattern.length === 0) {
        continue;
      }
      try {
        const replaced = rule.isRegex
          ? result.replace(new RegExp(rule.pattern, 'g'), rule.replacement)
          : result.split(rule.pattern).join(rule.replacement);
        if (replaced.trim().length > 0) {
          result = replaced;
        }
      } catch (_) {
        // 标题规则失败时沿用上一步结果。
      }
    }
    return result;
  }
  private static matchesBook(rule: ReplaceRule, book: Book): boolean {
    const scope = typeof rule.scope === 'string' ? rule.scope : '';
    const excludeScope = typeof rule.excludeScope === 'string' ? rule.excludeScope : '';
    const candidates: string[] = [book.title, book.isLocal ? 'loc_book' : ''];
    const inScope = scope.length === 0 || candidates.some((candidate: string) =>
      candidate.length > 0 && ReplaceRuleRepository.sqliteLike(scope, `%${candidate}%`));
    const excluded = excludeScope.length > 0 && candidates.some((candidate: string) =>
      candidate.length > 0 && ReplaceRuleRepository.sqliteLike(excludeScope, `%${candidate}%`));
    return inScope && !excluded;
  }

  /** 模拟 Android SQLite LIKE：%/_ 保留通配语义，默认仅 ASCII 大小写不敏感。 */
  private static sqliteLike(value: string, pattern: string): boolean {
    let expression = '^';
    const normalizedPattern = ReplaceRuleRepository.asciiLower(pattern);
    for (let index = 0; index < normalizedPattern.length; index++) {
      const character = normalizedPattern.charAt(index);
      if (character === '%') {
        expression += '[\\s\\S]*';
      } else if (character === '_') {
        expression += '[\\s\\S]';
      } else {
        if ('\\\\^$.*+?()[]{}|'.includes(character)) {
          expression += '\\';
        }
        expression += character;
      }
    }
    expression += '$';
    try {
      return new RegExp(expression).test(ReplaceRuleRepository.asciiLower(value));
    } catch (_) {
      return false;
    }
  }

  private static asciiLower(value: string): string {
    let result = '';
    for (let index = 0; index < value.length; index++) {
      const code = value.charCodeAt(index);
      result += code >= 65 && code <= 90 ? String.fromCharCode(code + 32) : value.charAt(index);
    }
    return result;
  }

  private static isRule(value: ReplaceRule): boolean {
    return typeof value.id === 'number' && typeof value.name === 'string' &&
      typeof value.pattern === 'string' && typeof value.replacement === 'string' &&
      typeof value.scopeTitle === 'boolean' && typeof value.scopeContent === 'boolean' &&
      typeof value.isEnabled === 'boolean' && typeof value.isRegex === 'boolean';
  }

  private static parseOverrides(raw: string): BookReplaceOverride[] {
    try {
      const parsed: BookReplaceOverride[] = JSON.parse(raw);
      return parsed.filter((item: BookReplaceOverride) =>
        typeof item.bookId === 'string' && typeof item.enabled === 'boolean');
    } catch (_) {
      return [];
    }
  }

  private static copyRule(rule: ReplaceRule): ReplaceRule {
    return {
      id: rule.id,
      name: rule.name,
      group: rule.group,
      pattern: rule.pattern,
      replacement: rule.replacement,
      scope: rule.scope,
      scopeTitle: rule.scopeTitle,
      scopeContent: rule.scopeContent,
      excludeScope: rule.excludeScope,
      isEnabled: rule.isEnabled,
      isRegex: rule.isRegex,
      timeoutMillisecond: rule.timeoutMillisecond,
      order: rule.order
    };
  }

  private static withEnabled(rule: ReplaceRule, enabled: boolean): ReplaceRule {
    return {
      id: rule.id,
      name: rule.name,
      group: rule.group,
      pattern: rule.pattern,
      replacement: rule.replacement,
      scope: rule.scope,
      scopeTitle: rule.scopeTitle,
      scopeContent: rule.scopeContent,
      excludeScope: rule.excludeScope,
      isEnabled: enabled,
      isRegex: rule.isRegex,
      timeoutMillisecond: rule.timeoutMillisecond,
      order: rule.order
    };
  }

  private static withGroup(rule: ReplaceRule, group: string): ReplaceRule {
    return {
      id: rule.id,
      name: rule.name,
      group: group,
      pattern: rule.pattern,
      replacement: rule.replacement,
      scope: rule.scope,
      scopeTitle: rule.scopeTitle,
      scopeContent: rule.scopeContent,
      excludeScope: rule.excludeScope,
      isEnabled: rule.isEnabled,
      isRegex: rule.isRegex,
      timeoutMillisecond: rule.timeoutMillisecond,
      order: rule.order
    };
  }

  /** 复制规则并改写作用范围标志，供历史数据迁移使用。 */
  private static withScopeContent(rule: ReplaceRule, scopeContent: boolean): ReplaceRule {
    return {
      id: rule.id,
      name: rule.name,
      group: rule.group,
      pattern: rule.pattern,
      replacement: rule.replacement,
      scope: rule.scope,
      scopeTitle: rule.scopeTitle,
      scopeContent: scopeContent,
      excludeScope: rule.excludeScope,
      isEnabled: rule.isEnabled,
      isRegex: rule.isRegex,
      timeoutMillisecond: rule.timeoutMillisecond,
      order: rule.order
    };
  }

  /** 复制一条规则并把 order 换成给定值；用于排序类操作构造新对象。 */
  private static withOrder(rule: ReplaceRule, order: number): ReplaceRule {
    return {
      id: rule.id,
      name: rule.name,
      group: rule.group,
      pattern: rule.pattern,
      replacement: rule.replacement,
      scope: rule.scope,
      scopeTitle: rule.scopeTitle,
      scopeContent: rule.scopeContent,
      excludeScope: rule.excludeScope,
      isEnabled: rule.isEnabled,
      isRegex: rule.isRegex,
      timeoutMillisecond: rule.timeoutMillisecond,
      order: order
    };
  }
}
