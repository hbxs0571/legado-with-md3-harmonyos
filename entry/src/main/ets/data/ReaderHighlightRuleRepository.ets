import { preferences } from '@kit.ArkData';
import { ReaderHighlightRule } from '../model/ReaderHighlightRule';

/** 批量导入结果，供界面如实反馈新增与覆盖的条数。 */
export interface ReaderHighlightRuleImportOutcome {
  added: number;
  updated: number;
  skipped: number;
}

/** Android HighlightRule 本地规则仓储；首次使用返回空集，不自动生成默认规则。 */
export class ReaderHighlightRuleRepository {
  private static readonly preferenceName: string = 'legado_reader_highlight_rules';
  private static readonly preferenceKey: string = 'rules_v1';
  private static saveQueue: Promise<void> = Promise.resolve();
  private static cachedRules: ReaderHighlightRule[] = [];

  static async load(context: Context): Promise<ReaderHighlightRule[]> {
    try {
      const store = await preferences.getPreferences(context, ReaderHighlightRuleRepository.preferenceName);
      const raw = await store.get(ReaderHighlightRuleRepository.preferenceKey, '[]');
      if (typeof raw !== 'string') {
        ReaderHighlightRuleRepository.cachedRules = [];
      } else {
        const parsed: ReaderHighlightRule[] = JSON.parse(raw);
        ReaderHighlightRuleRepository.cachedRules = parsed
          .filter((rule: ReaderHighlightRule) => ReaderHighlightRuleRepository.isRule(rule))
          .map((rule: ReaderHighlightRule, index: number) => ReaderHighlightRuleRepository.normalize(rule, index));
      }
    } catch (_) {
      ReaderHighlightRuleRepository.cachedRules = [];
    }
    return ReaderHighlightRuleRepository.copyRules(ReaderHighlightRuleRepository.cachedRules);
  }

  /**
   * 取当前缓存里的规则快照，供备份与界面同步读取。
   * 缓存只在 load() 之后才非空，备份链路必须先 await load()。
   */
  static getAll(): ReaderHighlightRule[] {
    return ReaderHighlightRuleRepository.copyRules(ReaderHighlightRuleRepository.cachedRules);
  }

  /**
   * 导出为与上游 highlightRule.json 一致的 JSON 数组。
   * 字段名逐字对齐 Android HighlightRule 实体，不含本地独有的运行时字段，
   * 因此 Android 端可直接读回；上游多出的 borderColor/borderWidth/borderRadius
   * 三个边框字段本地没有模型，缺失时由 Kotlin 默认值兜底。
   */
  static exportRules(rules: ReaderHighlightRule[]): string {
    const ordered: ReaderHighlightRule[] = rules.map((rule: ReaderHighlightRule, index: number) => {
      const copy = ReaderHighlightRuleRepository.copyRule(rule);
      copy.position = index;
      return copy;
    });
    return JSON.stringify(ordered, null, 2);
  }

  /**
   * 合并导入：同 id 或同 pattern 视为同一条，保留已有 id 与位置，用导入内容覆盖其余字段；
   * 其余新增。与上游 replaceAll 的全量替换不同，本地独有的规则会保留下来，
   * 避免「恢复一份旧备份就把新规则删光」的数据丢失。
   */
  static async importRules(context: Context, incoming: ReaderHighlightRule[]):
    Promise<ReaderHighlightRuleImportOutcome> {
    const next: ReaderHighlightRule[] = ReaderHighlightRuleRepository.copyRules(ReaderHighlightRuleRepository.cachedRules);
    let added = 0;
    let updated = 0;
    let skipped = 0;
    incoming.forEach((rule: ReaderHighlightRule) => {
      if (!ReaderHighlightRuleRepository.isRule(rule)) {
        skipped += 1;
        return;
      }
      const pattern = typeof rule.pattern === 'string' ? rule.pattern.trim() : '';
      // 空正则会命中每个字符位置，等于给整本书刷一层样式，按无效规则跳过。
      if (pattern.length === 0 || !ReaderHighlightRuleRepository.isValidRegex(pattern)) {
        skipped += 1;
        return;
      }
      const existingIndex = next.findIndex((item: ReaderHighlightRule) => item.id === rule.id ||
        (typeof item.pattern === 'string' && item.pattern.trim() === pattern));
      if (existingIndex >= 0) {
        const merged = ReaderHighlightRuleRepository.normalize(rule, next[existingIndex].position);
        merged.id = next[existingIndex].id;
        next[existingIndex] = merged;
        updated += 1;
      } else {
        next.push(ReaderHighlightRuleRepository.normalize(rule, next.length));
        added += 1;
      }
    });
    if (added === 0 && updated === 0) {
      return { added: added, updated: updated, skipped: skipped };
    }
    await ReaderHighlightRuleRepository.save(context, next);
    return { added: added, updated: updated, skipped: skipped };
  }

  /** 正则在本机能否编译；编译失败说明这条规则无法执行，导入时按无效跳过。 */
  private static isValidRegex(pattern: string): boolean {
    try {
      new RegExp(pattern, 'gu');
      return true;
    } catch (_) {
      return false;
    }
  }

  static save(context: Context, rules: ReaderHighlightRule[]): Promise<ReaderHighlightRule[]> {
    const operation = ReaderHighlightRuleRepository.saveQueue.then(async (): Promise<ReaderHighlightRule[]> => {
      const ordered = rules.map((rule: ReaderHighlightRule, index: number) =>
        ReaderHighlightRuleRepository.normalize(rule, index));
      const store = await preferences.getPreferences(context, ReaderHighlightRuleRepository.preferenceName);
      await store.put(ReaderHighlightRuleRepository.preferenceKey, JSON.stringify(ordered));
      await store.flush();
      ReaderHighlightRuleRepository.cachedRules = ordered;
      return ReaderHighlightRuleRepository.copyRules(ordered);
    });
    ReaderHighlightRuleRepository.saveQueue = operation.then(() => {}, () => {});
    return operation;
  }

  private static copyRule(rule: ReaderHighlightRule): ReaderHighlightRule {
    return {
      id: rule.id,
      name: rule.name,
      pattern: rule.pattern,
      sampleText: rule.sampleText,
      targetScope: rule.targetScope,
      enabled: rule.enabled,
      position: rule.position,
      textColor: rule.textColor,
      bgColor: rule.bgColor,
      underlineMode: rule.underlineMode,
      underlineColor: rule.underlineColor,
      underlineWidth: rule.underlineWidth,
      underlineOffset: rule.underlineOffset,
      underlineSvgPath: rule.underlineSvgPath,
      bgImage: rule.bgImage,
      bgImageFit: rule.bgImageFit,
      bgImageScale: rule.bgImageScale,
      configName: rule.configName,
      fontPath: rule.fontPath,
      fontWeight: rule.fontWeight,
      isItalic: rule.isItalic,
      fontSizeOffset: rule.fontSizeOffset,
      npLeft: rule.npLeft,
      npRight: rule.npRight,
      npTop: rule.npTop,
      npBottom: rule.npBottom,
      manualNineSlice: rule.manualNineSlice,
      letterSpacingBefore: rule.letterSpacingBefore,
      letterSpacingAfter: rule.letterSpacingAfter,
      lineSpacingTop: rule.lineSpacingTop,
      lineSpacingBottom: rule.lineSpacingBottom,
      bgLengthOffsetLeft: rule.bgLengthOffsetLeft,
      bgLengthOffsetRight: rule.bgLengthOffsetRight
    };
  }

  private static copyRules(rules: ReaderHighlightRule[]): ReaderHighlightRule[] {
    return rules.map((rule: ReaderHighlightRule) => ReaderHighlightRuleRepository.copyRule(rule));
  }

  /** 只收敛核心字段，其余 Android 样式字段按原值往返保存。 */
  private static normalize(rule: ReaderHighlightRule, position: number): ReaderHighlightRule {
    const copy = ReaderHighlightRuleRepository.copyRule(rule);
    copy.id = typeof rule.id === 'string' && rule.id.length > 0 ? rule.id : `highlight_${Date.now()}_${position}`;
    copy.name = typeof rule.name === 'string' ? rule.name : '';
    copy.pattern = typeof rule.pattern === 'string' ? rule.pattern : '';
    copy.sampleText = typeof rule.sampleText === 'string' ? rule.sampleText : '';
    copy.targetScope = typeof rule.targetScope === 'number' && [0, 1, 2].includes(rule.targetScope)
      ? rule.targetScope : 0;
    copy.enabled = typeof rule.enabled === 'boolean' ? rule.enabled : true;
    copy.position = position;
    copy.underlineMode = typeof rule.underlineMode === 'number' ? rule.underlineMode : 0;
    return copy;
  }

  private static isRule(value: ReaderHighlightRule): boolean {
    return value !== null && value !== undefined && typeof value === 'object' &&
      typeof value.name === 'string' && typeof value.pattern === 'string';
  }
}