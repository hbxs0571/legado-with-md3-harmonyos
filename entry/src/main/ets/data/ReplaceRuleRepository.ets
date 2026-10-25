import { preferences } from '@kit.ArkData';
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

/** 持久化替换规则并提供与本地章节读取共用的有序执行入口。 */
export class ReplaceRuleRepository {
  private static readonly preferenceName: string = 'legado_replace_rules';
  private static readonly preferenceKey: string = 'rules_v1';
  private static readonly defaultEnabledKey: string = 'default_enabled_v1';
  private static readonly bookOverridesKey: string = 'book_overrides_v1';
  private static cachedRules: ReplaceRule[] = [];
  private static defaultEnabled: boolean = true;
  private static bookOverrides: BookReplaceOverride[] = [];

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
}
