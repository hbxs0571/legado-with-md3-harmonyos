import { preferences, relationalStore } from '@kit.ArkData';
import { fileIo, picker } from '@kit.CoreFileKit';
import { util } from '@kit.ArkTS';
import { TxtTocRule } from '../model/TxtTocRule';
import { RdbCodec } from './RdbCodec';
import { RdbStore } from './RdbStore';
import { RdbSchema } from './RdbSchema';

/** 批量导入结果，供界面如实反馈新增与覆盖的条数。 */
export interface TxtTocRuleImportOutcome {
  added: number;
  updated: number;
  skipped: number;
}

/**
 * 从启用的规则里挑一条最贴合样本文本的规则。
 * 返回值里的 rule 为空表示没有任何规则达到命中门槛，调用方应退回按字数分章。
 */
export interface TxtTocRuleSelection {
  rule?: TxtTocRule;
  /** 选中规则的「章节样」匹配数，便于界面对照。 */
  matches: number;
}

/**
 * TXT 目录规则的持久化与匹配。
 *
 * 匹配策略对齐上游 app/src/main/java/io/legado/app/model/localBook/TxtTocRuleSelector.kt：
 * - 单条规则至少要有 2 处「章节样」匹配才算命中。像「正文」「尾声」「楔子」这类词
 *   在简介里偶发出现一次，若只要求 1 处，误判会把整本书压成一章，读起来就是空白。
 * - 相邻匹配必须间隔超过 1000 字符才计数。章节之间总隔着正文，而「匹配每一行」的
 *   错误规则会被间隔条件压到很低，不会被当成章节规则。
 * - 规则按 serialNumber 升序参与匹配，命中数相等时低序号优先。
 */
export class TxtTocRuleRepository {
  private static readonly preferenceName: string = 'legado_txt_toc_rules';
  private static readonly preferenceKey: string = 'rules_v1';
  /** 认定一条规则命中所需要的最少章节样匹配数，与上游 MIN_TXT_TOC_CHAPTER_MATCHES 一致。 */
  static readonly minimumChapterMatches: number = 2;
  /** 相邻两次匹配之间至少相隔的字符数，与上游 countChapterLikeMatches 的 minGap 一致。 */
  static readonly minimumMatchGap: number = 1000;
  /** 导入文件大小上限，防止误选大文件占满内存。 */
  private static readonly maximumImportBytes: number = 8 * 1024 * 1024;
  private static readonly selectAll: string =
    'SELECT `id`, `name`, `chapterRule`, `volumeRule`, `example`, `serialNumber`, `enable` ' +
      'FROM `txtTocRules` ORDER BY `serialNumber`';
  private static readonly upsertSql: string =
    'INSERT OR REPLACE INTO `txtTocRules` ' +
      '(`id`, `name`, `chapterRule`, `volumeRule`, `example`, `serialNumber`, `enable`) VALUES (?, ?, ?, ?, ?, ?, ?)';
  private static readonly deleteSql: string = 'DELETE FROM `txtTocRules` WHERE `id` = ?';
  private static readonly deleteAllSql: string = 'DELETE FROM `txtTocRules`';
  private static readonly updateEnabledSql: string = 'UPDATE `txtTocRules` SET `enable` = ? WHERE `id` = ?';
  private static readonly updateOrderSql: string = 'UPDATE `txtTocRules` SET `serialNumber` = ? WHERE `id` = ?';
  private static cachedRules: TxtTocRule[] = [];

  static getAll(): TxtTocRule[] {
    return TxtTocRuleRepository.cachedRules.map((rule: TxtTocRule) => TxtTocRuleRepository.copyRule(rule));
  }

  /** 按 id 取单条规则，供编辑页回填；找不到返回 undefined。 */
  static findById(id: number): TxtTocRule | undefined {
    const found = TxtTocRuleRepository.cachedRules.find((rule: TxtTocRule) => rule.id === id);
    return found === undefined ? undefined : TxtTocRuleRepository.copyRule(found);
  }

  /** 只取启用的规则，按 serialNumber 升序；匹配与阅读链路都用这一份。 */
  static getEnabled(): TxtTocRule[] {
    return TxtTocRuleRepository.cachedRules
      .filter((rule: TxtTocRule) => rule.enable && rule.chapterRule.trim().length > 0)
      .map((rule: TxtTocRule) => TxtTocRuleRepository.copyRule(rule));
  }

  /** 将 Android/Java 正则开头的 (?i)、(?m)、(?im) 转成 JS RegExp flags。 */
  static compileRegex(pattern: string, baseFlags: string = 'm'): RegExp {
    const inline = /^\(\?([ims]+)\)/.exec(pattern);
    let source = pattern;
    let flags = baseFlags;
    if (inline !== null) {
      const requested = inline[1] ?? '';
      source = pattern.substring(inline[0].length);
      for (let index = 0; index < requested.length; index++) {
        const flag = requested.charAt(index);
        if (!flags.includes(flag)) { flags += flag; }
      }
    }
    return new RegExp(source, flags);
  }

  static isValidRegex(pattern: string, flags: string = 'm'): boolean {
    try {
      TxtTocRuleRepository.compileRegex(pattern, flags);
      return true;
    } catch (_) {
      return false;
    }
  }

  /**
   * 从 DB 读全表进缓存（按 serialNumber 升序），供同步 getter 使用。
   * 失败态：DB 读不出来时回退 preferences 老键，界面不至于变空；只读不写，
   * 写回由 RdbMigration 负责，否则用户把规则删光后重启，老数据会被再搬回来。
   */
  static async load(context: Context): Promise<TxtTocRule[]> {
    try {
      const store = await RdbStore.getStore(context);
      await RdbSchema.ensure(store);
      const resultSet = await store.querySql(TxtTocRuleRepository.selectAll);
      try {
        TxtTocRuleRepository.cachedRules = TxtTocRuleRepository.readAll(resultSet);
      } finally {
        resultSet.close();
      }
    } catch (_) {
      await TxtTocRuleRepository.loadFromPreferences(context);
    }
    return TxtTocRuleRepository.getAll();
  }

  /** 从 preferences 老键读一次，只作为搬迁来源与 DB 读失败时的兜底。 */
  private static async loadFromPreferences(context: Context): Promise<void> {
    try {
      const store = await preferences.getPreferences(context, TxtTocRuleRepository.preferenceName);
      const raw = await store.get(TxtTocRuleRepository.preferenceKey, '[]');
      if (typeof raw !== 'string') {
        TxtTocRuleRepository.cachedRules = [];
      } else {
        const parsed: TxtTocRule[] = JSON.parse(raw);
        TxtTocRuleRepository.cachedRules = parsed
          .filter((item: TxtTocRule) => TxtTocRuleRepository.isRule(item))
          .map((rule: TxtTocRule) => TxtTocRuleRepository.normalize(rule));
      }
    } catch (_) {
      TxtTocRuleRepository.cachedRules = [];
    }
  }

  /**
   * 把 preferences 老数据搬进 DB，由 RdbMigration 在事务里调用。
   * 搬迁是唯一会整批重排 serialNumber 的场景（对齐上游 updateAllOrders）。
   * 不开事务、不写标记：事务与标记都由 RdbMigration 统一管。
   */
  static async migrateFromPreferences(context: Context, store: relationalStore.RdbStore): Promise<void> {
    await TxtTocRuleRepository.loadFromPreferences(context);
    const legacy = TxtTocRuleRepository.cachedRules;
    if (legacy.length === 0) { return; }
    await store.executeSql(TxtTocRuleRepository.deleteAllSql);
    for (let index = 0; index < legacy.length; index++) {
      const item = legacy[index];
      if (item === undefined) { continue; }
      const copy = TxtTocRuleRepository.copyRule(item);
      copy.serialNumber = index;
      await store.executeSql(TxtTocRuleRepository.upsertSql, TxtTocRuleRepository.toArgs(copy));
    }
    TxtTocRuleRepository.cachedRules = legacy.map((rule: TxtTocRule, index: number) => {
      const copy = TxtTocRuleRepository.copyRule(rule);
      copy.serialNumber = index;
      return copy;
    });
  }

  /** 把结果集读成规则数组；example 是可空列，缺失时折成 undefined。 */
  private static readAll(resultSet: relationalStore.ResultSet): TxtTocRule[] {
    const idIndex = RdbCodec.column(resultSet, 'id');
    const nameIndex = RdbCodec.column(resultSet, 'name');
    const chapterRuleIndex = RdbCodec.column(resultSet, 'chapterRule');
    const volumeRuleIndex = RdbCodec.column(resultSet, 'volumeRule');
    const exampleIndex = RdbCodec.column(resultSet, 'example');
    const serialNumberIndex = RdbCodec.column(resultSet, 'serialNumber');
    const enableIndex = RdbCodec.column(resultSet, 'enable');
    const rules: TxtTocRule[] = [];
    while (resultSet.goToNextRow()) {
      rules.push({
        id: RdbCodec.integer(resultSet, idIndex),
        name: RdbCodec.text(resultSet, nameIndex),
        chapterRule: RdbCodec.text(resultSet, chapterRuleIndex),
        volumeRule: RdbCodec.text(resultSet, volumeRuleIndex),
        example: RdbCodec.optionalText(resultSet, exampleIndex),
        serialNumber: RdbCodec.integer(resultSet, serialNumberIndex, -1),
        enable: RdbCodec.boolean(resultSet, enableIndex, true)
      });
    }
    return rules;
  }

  /** 绑定参数，顺序与 upsertSql 的列顺序严格一致。 */
  private static toArgs(rule: TxtTocRule): relationalStore.ValueType[] {
    return [
      rule.id,
      rule.name,
      rule.chapterRule,
      rule.volumeRule,
      rule.example === undefined ? null : rule.example,
      rule.serialNumber,
      rule.enable ? 1 : 0
    ];
  }

  /**
   * 保存一条规则：同 id 覆盖，否则追加。
   * 正则语法错误直接抛错，由调用方提示，不静默存入一条永远无法生效的规则。
   */
  static async save(context: Context, rule: TxtTocRule): Promise<void> {
    if (!TxtTocRuleRepository.isRule(rule)) {
      throw new Error('TXT 目录规则无效');
    }
    const pattern = rule.chapterRule.trim();
    const emptyDefaultRule = pattern.length === 0 && rule.name.trim() === '默认分章规则';
    if (pattern.length === 0 && !emptyDefaultRule) {
      throw new Error('章节正则不能为空');
    }
    if (pattern.length > 0 && !TxtTocRuleRepository.isValidRegex(pattern, 'm')) {
      throw new Error('章节正则格式无效');
    }
    const volumePattern = rule.volumeRule.trim();
    if (volumePattern.length > 0) {
      if (!TxtTocRuleRepository.isValidRegex(volumePattern, 'm')) {
        throw new Error('分卷正则格式无效');
      }
    }
    const existingIndex = TxtTocRuleRepository.cachedRules.findIndex((item: TxtTocRule) => item.id === rule.id);
    const store = await RdbStore.getStore(context);
    await RdbSchema.ensure(store);
    if (existingIndex >= 0) {
      // 同 id 覆盖：只写这一行，serialNumber 沿用原有排序位置。
      const merged = TxtTocRuleRepository.normalize(rule);
      merged.serialNumber = TxtTocRuleRepository.cachedRules[existingIndex].serialNumber;
      await store.executeSql(TxtTocRuleRepository.upsertSql, TxtTocRuleRepository.toArgs(merged));
      const next = [...TxtTocRuleRepository.cachedRules];
      next[existingIndex] = merged;
      TxtTocRuleRepository.cachedRules = next;
    } else {
      const added = TxtTocRuleRepository.normalize(rule);
      added.serialNumber = TxtTocRuleRepository.cachedRules.length;
      await store.executeSql(TxtTocRuleRepository.upsertSql, TxtTocRuleRepository.toArgs(added));
      TxtTocRuleRepository.cachedRules = [...TxtTocRuleRepository.cachedRules, added];
    }
  }

  static async remove(context: Context, id: number): Promise<void> {
    const store = await RdbStore.getStore(context);
    await RdbSchema.ensure(store);
    await store.executeSql(TxtTocRuleRepository.deleteSql, [id]);
    TxtTocRuleRepository.cachedRules =
      TxtTocRuleRepository.cachedRules.filter((rule: TxtTocRule) => rule.id !== id);
  }

  /**
   * 批量删除。
   * @returns 实际删除的条数，用于区分「没选中」与「选中项已不存在」。
   */
  static async removeBatch(context: Context, ids: number[]): Promise<number> {
    if (ids.length === 0) {
      return 0;
    }
    const next = TxtTocRuleRepository.cachedRules.filter((rule: TxtTocRule) => !ids.includes(rule.id));
    const removed = TxtTocRuleRepository.cachedRules.length - next.length;
    if (removed === 0) {
      return 0;
    }
    const store = await RdbStore.getStore(context);
    await RdbSchema.ensure(store);
    await store.beginTransaction();
    try {
      for (let index = 0; index < ids.length; index++) {
        await store.executeSql(TxtTocRuleRepository.deleteSql, [ids[index]]);
      }
      await store.commit();
    } catch (error) {
      await store.rollBack();
      throw new Error(`TXT 目录规则删除失败：${error instanceof Error ? error.message : String(error)}`);
    }
    TxtTocRuleRepository.cachedRules = next;
    return removed;
  }

  static async setEnabled(context: Context, id: number, enabled: boolean): Promise<void> {
    const store = await RdbStore.getStore(context);
    await RdbSchema.ensure(store);
    await store.executeSql(TxtTocRuleRepository.updateEnabledSql, [enabled ? 1 : 0, id]);
    TxtTocRuleRepository.cachedRules = TxtTocRuleRepository.cachedRules.map((rule: TxtTocRule) => {
      if (rule.id !== id) {
        return rule;
      }
      const copy = TxtTocRuleRepository.copyRule(rule);
      copy.enable = enabled;
      return copy;
    });
  }

  /**
   * 批量启用/停用。
   * @returns 实际改变的条数，避免把「本来就是这个状态」算作本次结果。
   */
  static async setEnabledBatch(context: Context, ids: number[], enabled: boolean): Promise<number> {
    if (ids.length === 0) {
      return 0;
    }
    const changedIds: number[] = [];
    const next = TxtTocRuleRepository.cachedRules.map((rule: TxtTocRule) => {
      if (ids.includes(rule.id) && rule.enable !== enabled) {
        changedIds.push(rule.id);
        const copy = TxtTocRuleRepository.copyRule(rule);
        copy.enable = enabled;
        return copy;
      }
      return rule;
    });
    if (changedIds.length === 0) {
      return 0;
    }
    const store = await RdbStore.getStore(context);
    await RdbSchema.ensure(store);
    await store.beginTransaction();
    try {
      for (let index = 0; index < changedIds.length; index++) {
        await store.executeSql(TxtTocRuleRepository.updateEnabledSql, [enabled ? 1 : 0, changedIds[index]]);
      }
      await store.commit();
    } catch (error) {
      await store.rollBack();
      throw new Error(`TXT 目录规则启停失败：${error instanceof Error ? error.message : String(error)}`);
    }
    TxtTocRuleRepository.cachedRules = next;
    return changedIds.length;
  }

  /**
   * 把规则移动到指定位置，用于排序与拖拽。
   * 落位后重排 serialNumber，让存储顺序与匹配优先级保持一致。
   */
  static async moveRule(context: Context, fromId: number, toIndex: number): Promise<void> {
    const fromIndex = TxtTocRuleRepository.cachedRules.findIndex((rule: TxtTocRule) => rule.id === fromId);
    if (fromIndex < 0) {
      return;
    }
    const next = [...TxtTocRuleRepository.cachedRules];
    const moved = next.splice(fromIndex, 1)[0];
    const target = Math.max(0, Math.min(next.length, toIndex));
    next.splice(target, 0, moved);
    await TxtTocRuleRepository.writeOrders(context, next);
  }

  /**
   * 把规则移到列表最前或最后，对应上游条目下拉的置顶/置底。
   * 与 moveRule 一样重排 serialNumber。
   */
  static async moveToEdge(context: Context, id: number, toTop: boolean): Promise<boolean> {
    const index = TxtTocRuleRepository.cachedRules.findIndex((rule: TxtTocRule) => rule.id === id);
    if (index < 0) {
      return false;
    }
    const next = [...TxtTocRuleRepository.cachedRules];
    const moved = next.splice(index, 1)[0];
    if (toTop) {
      next.unshift(moved);
    } else {
      next.push(moved);
    }
    await TxtTocRuleRepository.writeOrders(context, next);
    return true;
  }

  /**
   * 批量导入：同 id 或同章节正则视为同一条，命中时保留已有 id 覆盖其余字段。
   * 非法正则条目计入 skipped 后跳过，不因为一条坏规则丢掉整份文件。
   */
  static async importRules(context: Context, incoming: TxtTocRule[]): Promise<TxtTocRuleImportOutcome> {
    const next = [...TxtTocRuleRepository.cachedRules];
    let added = 0;
    let updated = 0;
    let skipped = 0;
    incoming.forEach((rule: TxtTocRule) => {
      if (!TxtTocRuleRepository.isRule(rule)) {
        skipped += 1;
        return;
      }
      const pattern = rule.chapterRule.trim();
      const emptyDefaultRule = pattern.length === 0 && rule.name.trim() === '默认分章规则';
      if ((pattern.length === 0 && !emptyDefaultRule) ||
        (pattern.length > 0 && !TxtTocRuleRepository.isValidRegex(pattern, 'm'))) {
        skipped += 1;
        return;
      }
      const existingIndex = next.findIndex((item: TxtTocRule) => item.id === rule.id ||
        (pattern.length > 0 && item.chapterRule.trim() === pattern) ||
        (emptyDefaultRule && item.chapterRule.trim().length === 0 && item.name.trim() === '默认分章规则'));
      if (existingIndex >= 0) {
        const merged = TxtTocRuleRepository.normalize(rule);
        merged.id = next[existingIndex].id;
        merged.serialNumber = next[existingIndex].serialNumber;
        next[existingIndex] = merged;
        updated += 1;
      } else {
        next.push(TxtTocRuleRepository.normalize(rule));
        added += 1;
      }
    });
    if (added === 0 && updated === 0) {
      return { added: added, updated: updated, skipped: skipped };
    }
    // 新增的规则排在末尾，序号接在现有最大序号之后，避免与已有行撞号。
    let nextOrder = next.length - added;
    for (let index = 0; index < next.length; index++) {
      const item = next[index];
      if (item.serialNumber < 0 || index >= next.length - added) {
        item.serialNumber = nextOrder;
        nextOrder += 1;
      }
    }
    const store = await RdbStore.getStore(context);
    await RdbSchema.ensure(store);
    await store.beginTransaction();
    try {
      for (let index = 0; index < next.length; index++) {
        const item = next[index];
        await store.executeSql(TxtTocRuleRepository.upsertSql, TxtTocRuleRepository.toArgs(item));
      }
      await store.commit();
    } catch (error) {
      await store.rollBack();
      throw new Error(`TXT 目录规则导入失败：${error instanceof Error ? error.message : String(error)}`);
    }
    TxtTocRuleRepository.cachedRules = next;
    return { added: added, updated: updated, skipped: skipped };
  }

  /**
   * 按数组顺序重写 serialNumber，只更新序号真的变了的行。
   * 对齐上游 TxtTocRuleDao.updateAllOrders（逐条 updateOrder）。
   */
  private static async writeOrders(context: Context, rules: TxtTocRule[]): Promise<void> {
    const ordered = rules.map((rule: TxtTocRule, index: number) => {
      const copy = TxtTocRuleRepository.copyRule(rule);
      copy.serialNumber = index;
      return copy;
    });
    const store = await RdbStore.getStore(context);
    await RdbSchema.ensure(store);
    await store.beginTransaction();
    try {
      for (let index = 0; index < ordered.length; index++) {
        const item = ordered[index];
        const previous = rules[index];
        if (previous !== undefined && previous.serialNumber === item.serialNumber) {
          continue;
        }
        await store.executeSql(TxtTocRuleRepository.updateOrderSql, [item.serialNumber, item.id]);
      }
      await store.commit();
    } catch (error) {
      await store.rollBack();
      throw new Error(`TXT 目录规则排序失败：${error instanceof Error ? error.message : String(error)}`);
    }
    TxtTocRuleRepository.cachedRules = ordered;
  }

  /**
   * 导出为与上游 txtTocRule.json 一致的 JSON 数组。
   * 字段名用 chapterRule/volumeRule/example/serialNumber/enable，Android 端可直接读回。
   */
  static exportRules(rules: TxtTocRule[]): string {
    const ordered: TxtTocRule[] = rules.map((rule: TxtTocRule, index: number) => {
      const copy = TxtTocRuleRepository.copyRule(rule);
      copy.serialNumber = index;
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
    options.fileSuffixFilters = ['TXT 目录规则|.json', '文本规则|.txt'];
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
      if (size > TxtTocRuleRepository.maximumImportBytes) {
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
    options.newFileNames = [`txtTocRule-${Date.now()}.json`];
    options.fileSuffixChoices = ['JSON 规则|.json'];
    const uris = await new picker.DocumentViewPicker(context).save(options);
    const uri = uris[0];
    if (uri === undefined) {
      return false;
    }
    // 内容直接传字符串，由底层按 UTF-8 编码。
    // 之前先 encodeInto 成 Uint8Array 再 writeSync，在模拟器上报 13900020（EINVAL），
    // 文件被创建出来但大小为 0。
    const target = fileIo.openSync(uri, fileIo.OpenMode.WRITE_ONLY | fileIo.OpenMode.TRUNC);
    try {
      fileIo.writeSync(target.fd, content);
    } finally {
      fileIo.closeSync(target);
    }
    return true;
  }

  /**
   * 按章节正则反查这本书该用哪条分卷正则，对应上游 TextFile.getVolumePattern()。
   *
   * 上游在全部规则里找 chapterRule 完全相同的那条（含已禁用的）：分卷正则跟着章节正则走，
   * 书里只缓存章节正则，所以每次都要反查回来。找不到或正则非法时返回空串，表示不分卷。
   */
  static resolveVolumeRule(chapterRule: string): string {
    const pattern = chapterRule.trim();
    if (pattern.length === 0) {
      return '';
    }
    const rules = TxtTocRuleRepository.getAll();
    for (let index = 0; index < rules.length; index++) {
      const rule = rules[index];
      if (rule.chapterRule.trim() !== pattern) {
        continue;
      }
      const volumeRule = rule.volumeRule.trim();
      if (volumeRule.length === 0) {
        return '';
      }
      try {
        TxtTocRuleRepository.compileRegex(volumeRule, 'm');
      } catch (_) {
        // 分卷正则语法错误只影响分卷，不该让整条目录规则失效。
        return '';
      }
      return volumeRule;
    }
    return '';
  }

  /**
   * 判断一组章节标题里哪些是分卷标题。
   *
   * 与上游 analyze() 一致：分卷正则命中的章节标题额外带上 isVolume 标记，
   * 它本身仍是章节（有起点、有正文），只是目录页把它当作卷头渲染。
   * 没有分卷正则时全部返回 false。
   */
  static markVolumeTitles(titles: string[], volumeRule: string): boolean[] {
    const flags: boolean[] = [];
    const pattern = volumeRule.trim();
    if (pattern.length === 0) {
      for (let index = 0; index < titles.length; index++) {
        flags.push(false);
      }
      return flags;
    }
    let regex: RegExp;
    try {
      regex = TxtTocRuleRepository.compileRegex(pattern, 'm');
    } catch (_) {
      for (let index = 0; index < titles.length; index++) {
        flags.push(false);
      }
      return flags;
    }
    for (let index = 0; index < titles.length; index++) {
      regex.lastIndex = 0;
      flags.push(regex.test(titles[index] ?? ''));
    }
    return flags;
  }

  /**
   * 从启用的规则里挑一条最贴合样本文本的规则。
   * 实现对齐上游 selectTxtTocRule：倒序遍历（低序号优先），命中数严格大于当前最大值才替换，
   * 因此命中数相等时先参与的高序号被后到的低序号覆盖。
   */
  static selectForSample(sample: string): TxtTocRuleSelection {
    // 样本必须先统一行尾：ArkTS 的正则在多行模式下只把 \n 当作行终止符，
    // $ 不会匹配到 \r 之前，而 Windows 文本每行都以 \r\n 结尾。
    // 不归一的话，所有以 `.{0,30}$` 收尾的内置规则在 CRLF 文本上都会 0 命中，
    // 书会被误判成「没有可用目录规则」而退回按字数分章。
    // 章节切分本身不受影响：splitChapterStarts 逐行处理时已经去掉了行尾 \r。
    const normalized = sample.indexOf('\r') >= 0 ? sample.replace(/\r\n?/g, '\n') : sample;
    const rules = TxtTocRuleRepository.getEnabled();
    let maxMatches = TxtTocRuleRepository.minimumChapterMatches;
    let best: TxtTocRule | undefined = undefined;
    let bestMatches = 0;
    for (let index = rules.length - 1; index >= 0; index--) {
      const rule = rules[index];
      let pattern: RegExp;
      try {
        pattern = TxtTocRuleRepository.compileRegex(rule.chapterRule, 'gm');
      } catch (_) {
        // 语法错误的规则直接跳过，不影响其余规则参与匹配。
        continue;
      }
      const matches = TxtTocRuleRepository.countChapterLikeMatches(pattern, normalized);
      if (matches >= maxMatches) {
        maxMatches = matches;
        best = rule;
        bestMatches = matches;
      }
    }
    return { rule: best, matches: bestMatches };
  }

  /**
   * 统计「章节样」的匹配数。
   * 空匹配（如 (?=…) 或空正则）不构成章节，直接跳过；
   * 与上一处计数的间隔不超过 minimumMatchGap 的匹配也不计数。
   */
  static countChapterLikeMatches(pattern: RegExp, sample: string): number {
    let start = 0;
    let count = 0;
    let match = pattern.exec(sample);
    while (match !== null) {
      const value = match[0];
      if (value.length > 0) {
        const matchStart = match.index;
        if (start === 0 || matchStart - start > TxtTocRuleRepository.minimumMatchGap) {
          count += 1;
          start = matchStart + value.length;
        }
      } else {
        // 零宽匹配要手动推进，否则 exec 会原地死循环。
        pattern.lastIndex += 1;
      }
      if (pattern.lastIndex > sample.length) {
        break;
      }
      match = pattern.exec(sample);
    }
    return count;
  }

  /**
   * 用一条规则切出章节的起始偏移。
   *
   * 逐行匹配、命中则记录该行行首偏移，而不是整段 findAll。两个原因：
   * 1. 本地阅读器按「章节起点到下一章起点」取正文，起点落在行首才不会有半截标题；
   * 2. 逐行判断天然把「正文里提到的第X章」挡在外面，只有独占一行的标题才算章节。
   *
   * 注意这里用原始行（只去掉行尾 \r）参与匹配，不做 trim：
   * 内置规则「目录(去空白)」靠 (?<=[　\s]) 识别「　第1章」这类带缩进的标题，
   * trim 掉前导空白会让这条规则永远匹配不到。
   */
  static splitChapterStarts(content: string, chapterRule: string): number[] {
    const pattern = chapterRule.trim();
    if (pattern.length === 0) {
      return [];
    }
    let regex: RegExp;
    try {
      regex = TxtTocRuleRepository.compileRegex(pattern, 'm');
    } catch (_) {
      return [];
    }
    const starts: number[] = [];
    const lines = content.split('\n');
    let offset = 0;
    for (let index = 0; index < lines.length; index++) {
      const rawLine = lines[index] ?? '';
      const line = rawLine.replace(/\r$/, '');
      if (line.trim().length > 0) {
        regex.lastIndex = 0;
        if (regex.test(line)) {
          starts.push(offset);
        }
      }
      offset += rawLine.length + (index < lines.length - 1 ? 1 : 0);
    }
    return starts;
  }

  /**
   * 读取打包在 rawfile 里的内置规则库。
   * 读不到或解析失败时返回空数组，由调用方提示，不阻断规则页其它操作。
   */
  static loadBuiltinRules(context: Context): TxtTocRule[] {
    try {
      const bytes = context.resourceManager.getRawFileContentSync('txttoc/builtin-rules.json');
      const text = new util.TextDecoder('utf-8').decodeToString(bytes);
      const parsed: TxtTocRule[] = JSON.parse(text);
      return parsed
        .filter((item: TxtTocRule) => TxtTocRuleRepository.isRule(item))
        .map((rule: TxtTocRule) => TxtTocRuleRepository.normalize(rule));
    } catch (_) {
      return [];
    }
  }

  private static copyRule(rule: TxtTocRule): TxtTocRule {
    return {
      id: rule.id,
      name: rule.name,
      chapterRule: rule.chapterRule,
      volumeRule: rule.volumeRule,
      example: rule.example,
      serialNumber: rule.serialNumber,
      enable: rule.enable
    };
  }

  /** 补齐缺失字段并做类型收敛，避免旧数据或手工编辑的 JSON 把 undefined 带进匹配链路。 */
  private static normalize(rule: TxtTocRule): TxtTocRule {
    return {
      id: typeof rule.id === 'number' ? rule.id : Date.now(),
      name: typeof rule.name === 'string' ? rule.name : '',
      chapterRule: typeof rule.chapterRule === 'string' ? rule.chapterRule : '',
      volumeRule: typeof rule.volumeRule === 'string' ? rule.volumeRule : '',
      example: typeof rule.example === 'string' ? rule.example : undefined,
      serialNumber: typeof rule.serialNumber === 'number' ? rule.serialNumber : -1,
      enable: typeof rule.enable === 'boolean' ? rule.enable : true
    };
  }

  private static isRule(value: TxtTocRule): boolean {
    return value !== null && value !== undefined && typeof value.id === 'number' &&
      typeof value.name === 'string' && typeof value.chapterRule === 'string';
  }
}
