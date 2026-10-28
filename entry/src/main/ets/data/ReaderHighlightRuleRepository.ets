import { preferences } from '@kit.ArkData';
import { ReaderHighlightRule } from '../model/ReaderHighlightRule';

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