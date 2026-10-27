import { preferences } from '@kit.ArkData';
import { fileIo, picker } from '@kit.CoreFileKit';
import { util } from '@kit.ArkTS';
import { Book } from '../model/Book';
import { ReplaceRule } from '../model/ReplaceRule';

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

/** 持久化替换规则并提供与本地章节读取共用的有序执行入口。 */
export class ReplaceRuleRepository {
  private static readonly preferenceName: string = 'legado_replace_rules';
  private static readonly preferenceKey: string = 'rules_v1';
  private static readonly defaultEnabledKey: string = 'default_enabled_v1';
  private static readonly bookOverridesKey: string = 'book_overrides_v1';
  private static readonly groupsKey: string = 'groups_v1';
  private static readonly sortModeKey: string = 'sort_mode_v1';
  /** 默认分组名，与 Android 的「默认」保持一致。 */
  static readonly defaultGroup: string = '默认';
  /** 导入文件大小上限，防止误选大文件占满内存。 */
  private static readonly maximumImportBytes: number = 8 * 1024 * 1024;
  private static cachedRules: ReplaceRule[] = [];
  private static defaultEnabled: boolean = true;
  private static bookOverrides: BookReplaceOverride[] = [];
  /** 显式创建过的分组；规则里出现的分组另行并入，空分组靠这份清单保留。 */
  private static explicitGroups: string[] = [];
  private static sortMode: string = 'asc';

  static getAll(): ReplaceRule[] {
    return ReplaceRuleRepository.cachedRules.map((rule: ReplaceRule) => ReplaceRuleRepository.copyRule(rule));
  }

  static async load(context: Context): Promise<ReplaceRule[]> {
    try {
      const store = await preferences.getPreferences(context, ReplaceRuleRepository.preferenceName);
      const raw = await store.get(ReplaceRuleRepository.preferenceKey, '[]');
      const savedDefault = await store.get(ReplaceRuleRepository.defaultEnabledKey, true);
      ReplaceRuleRepository.defaultEnabled = typeof savedDefault === 'boolean' ? savedDefault : true;
      const savedOverrides = await store.get(ReplaceRuleRepository.bookOverridesKey, '[]');
      ReplaceRuleRepository.bookOverrides = typeof savedOverrides === 'string'
        ? ReplaceRuleRepository.parseOverrides(savedOverrides) : [];
      const savedGroups = await store.get(ReplaceRuleRepository.groupsKey, '[]');
      ReplaceRuleRepository.explicitGroups = typeof savedGroups === 'string'
        ? ReplaceRuleRepository.parseGroups(savedGroups) : [];
      const savedSortMode = await store.get(ReplaceRuleRepository.sortModeKey, 'asc');
      ReplaceRuleRepository.sortMode = typeof savedSortMode === 'string' &&
        ReplaceRuleRepository.isValidSortMode(savedSortMode) ? savedSortMode : 'asc';
      if (typeof raw !== 'string') {
        ReplaceRuleRepository.cachedRules = [];
      } else {
        const parsed: ReplaceRule[] = JSON.parse(raw);
        ReplaceRuleRepository.cachedRules = parsed
          .filter((item: ReplaceRule) => ReplaceRuleRepository.isRule(item))
          .sort((left: ReplaceRule, right: ReplaceRule) => left.order - right.order || left.id - right.id);
      }
    } catch (_) {
      ReplaceRuleRepository.cachedRules = [];
    }
    return ReplaceRuleRepository.getAll();
  }

  /**
   * 返回全部分组：默认分组始终在首位，其后是显式创建的分组与规则中实际出现的分组。
   * 显式清单保证空分组在规则被删光后仍然存在。
   */
  static getGroups(): string[] {
    const groups: string[] = [ReplaceRuleRepository.defaultGroup];
    ReplaceRuleRepository.explicitGroups.forEach((group: string) => {
      if (group.length > 0 && !groups.includes(group)) { groups.push(group); }
    });
    ReplaceRuleRepository.cachedRules.forEach((rule: ReplaceRule) => {
      const group = typeof rule.group === 'string' ? rule.group.trim() : '';
      if (group.length > 0 && !groups.includes(group)) { groups.push(group); }
    });
    return groups;
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
    if (existingIndex >= 0) {
      next[existingIndex] = ReplaceRuleRepository.copyRule(rule);
    } else {
      const added = ReplaceRuleRepository.copyRule(rule);
      added.order = next.length;
      next.push(added);
    }
    await ReplaceRuleRepository.persist(context, next);
  }

  static async setEnabled(context: Context, id: number, enabled: boolean): Promise<void> {
    await ReplaceRuleRepository.persist(context, ReplaceRuleRepository.cachedRules.map((rule: ReplaceRule) =>
      rule.id === id ? ReplaceRuleRepository.withEnabled(rule, enabled) : rule));
  }

  static async remove(context: Context, id: number): Promise<void> {
    await ReplaceRuleRepository.persist(context,
      ReplaceRuleRepository.cachedRules.filter((rule: ReplaceRule) => rule.id !== id));
  }

  /** 新建分组；分组名重复或为空时不做改动。 */
  static async addGroup(context: Context, group: string): Promise<void> {
    const name = group.trim();
    if (name.length === 0 || name === ReplaceRuleRepository.defaultGroup ||
      ReplaceRuleRepository.getGroups().includes(name)) {
      return;
    }
    await ReplaceRuleRepository.persistGroups(context, [...ReplaceRuleRepository.explicitGroups, name]);
  }

  /**
   * 重命名分组，同时改写该分组下所有规则的 group 字段。
   * 目标是默认分组时不处理，避免与内置分组语义冲突。
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
    const next = ReplaceRuleRepository.cachedRules.map((rule: ReplaceRule) =>
      (typeof rule.group === 'string' && rule.group.trim() === from)
        ? ReplaceRuleRepository.withGroup(rule, to) : rule);
    const nextGroups = ReplaceRuleRepository.explicitGroups.map((group: string) => group === from ? to : group);
    await ReplaceRuleRepository.persist(context, next);
    await ReplaceRuleRepository.persistGroups(context, nextGroups);
  }

  /**
   * 删除分组，该分组下的规则回落到默认分组。
   * 规则本身保留，符合 Android delGroup 只清空分组的语义。
   */
  static async removeGroup(context: Context, group: string): Promise<void> {
    const name = group.trim();
    if (name.length === 0 || name === ReplaceRuleRepository.defaultGroup) { return; }
    const next = ReplaceRuleRepository.cachedRules.map((rule: ReplaceRule) =>
      (typeof rule.group === 'string' && rule.group.trim() === name)
        ? ReplaceRuleRepository.withGroup(rule, ReplaceRuleRepository.defaultGroup) : rule);
    const nextGroups = ReplaceRuleRepository.explicitGroups.filter((item: string) => item !== name);
    await ReplaceRuleRepository.persist(context, next);
    await ReplaceRuleRepository.persistGroups(context, nextGroups);
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

  private static async moveToEdge(context: Context, id: number, toTop: boolean): Promise<void> {
    const index = ReplaceRuleRepository.cachedRules.findIndex((rule: ReplaceRule) => rule.id === id);
    if (index < 0) { return; }
    const next = [...ReplaceRuleRepository.cachedRules];
    const moved = next.splice(index, 1)[0];
    // desc 模式下数组尾部对应视觉顶部，故取反。
    const toArrayHead = ReplaceRuleRepository.sortMode === 'desc' ? !toTop : toTop;
    if (toArrayHead) {
      next.unshift(moved);
    } else {
      next.push(moved);
    }
    await ReplaceRuleRepository.persist(context, next);
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
    // 导入过程中可能出现分组，落盘时一并登记，避免空分组丢失。
    const groups = [...ReplaceRuleRepository.explicitGroups];
    incoming.forEach((rule: ReplaceRule) => {
      const group = rule.group.trim();
      if (group.length > 0 && group !== ReplaceRuleRepository.defaultGroup && !groups.includes(group)) {
        groups.push(group);
      }
    });
    await ReplaceRuleRepository.persist(context, next);
    if (groups.length !== ReplaceRuleRepository.explicitGroups.length) {
      await ReplaceRuleRepository.persistGroups(context, groups);
    }
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
    const encoder = new util.TextEncoder();
    const bytes = encoder.encodeInto(content);
    const target = fileIo.openSync(uri, fileIo.OpenMode.WRITE_ONLY | fileIo.OpenMode.TRUNC);
    try {
      fileIo.writeSync(target.fd, bytes.buffer as ArrayBuffer);
    } finally {
      fileIo.closeSync(target);
    }
    return true;
  }

  static applyContent(book: Book, chapterTitle: string, content: string): string {
    return ReplaceRuleRepository.applyContentWithResult(book, chapterTitle, content).text;
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
  private static async persist(context: Context, rules: ReplaceRule[]): Promise<void> {
    const ordered = rules.map((rule: ReplaceRule, index: number) => {
      const copy = ReplaceRuleRepository.copyRule(rule);
      copy.order = index;
      return copy;
    });
    const store = await preferences.getPreferences(context, ReplaceRuleRepository.preferenceName);
    await store.put(ReplaceRuleRepository.preferenceKey, JSON.stringify(ordered));
    await store.flush();
    ReplaceRuleRepository.cachedRules = ordered;
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

  private static async persistGroups(context: Context, groups: string[]): Promise<void> {
    const store = await preferences.getPreferences(context, ReplaceRuleRepository.preferenceName);
    await store.put(ReplaceRuleRepository.groupsKey, JSON.stringify(groups));
    await store.flush();
    ReplaceRuleRepository.explicitGroups = groups;
  }

  private static parseGroups(raw: string): string[] {
    try {
      const parsed: string[] = JSON.parse(raw);
      return parsed.filter((item: string) => typeof item === 'string' && item.trim().length > 0);
    } catch (_) {
      return [];
    }
  }
}
