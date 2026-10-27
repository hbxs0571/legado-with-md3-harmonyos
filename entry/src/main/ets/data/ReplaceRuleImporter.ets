import { ReplaceRule } from '../model/ReplaceRule';

/**
 * 导入解析结果。
 * skipped 记录无法解析或不合法的条目数，供界面如实反馈，不假装全部成功。
 */
export interface ReplaceRuleImportResult {
  rules: ReplaceRule[];
  skipped: number;
}

/** 单条原始规则；字段全部可选，兼容不同来源的缺省。 */
interface RawReplaceRule {
  id?: number;
  name?: string;
  group?: string;
  pattern?: string;
  replacement?: string;
  scope?: string;
  scopeTitle?: boolean;
  scopeContent?: boolean;
  excludeScope?: string;
  isEnabled?: boolean;
  isRegex?: boolean;
  timeoutMillisecond?: number;
  order?: number;
  // legado 旧版订阅格式字段，与上面的字段二选一。
  regex?: string;
  replaceSummary?: string;
  useTo?: string;
  enable?: boolean;
  serialNumber?: number;
}

/**
 * 解析替换规则文本。
 *
 * 兼容三种来源：
 * 1. 本项目导出的 JSON 数组（字段与本项目 ReplaceRule 一致）；
 * 2. legado 旧版规则订阅的 JSON 数组（regex/replaceSummary/useTo/enable/serialNumber）；
 * 3. 单个规则对象，来源同 1、2。
 *
 * 无法解析或正则非法的条目计入 skipped 后跳过，不影响其余条目，
 * 与 Android ReplaceAnalyzer 逐条过滤的语义一致。
 */
export class ReplaceRuleImporter {
  /** 解析入口；格式完全无法识别时返回空结果并把整段计入 skipped。 */
  static parse(text: string): ReplaceRuleImportResult {
    const trimmed = text.trim();
    if (trimmed.length === 0) {
      return { rules: [], skipped: 0 };
    }
    const rules: ReplaceRule[] = [];
    let skipped: number = 0;
    try {
      if (trimmed.startsWith('[')) {
        const items: RawReplaceRule[] = JSON.parse(trimmed);
        const reservedIds: number[] = [];
        items.forEach((item: RawReplaceRule) => {
          if (typeof item.id === 'number' && item.id > 0 && !reservedIds.includes(item.id)) {
            reservedIds.push(item.id);
          }
        });
        const assignedIds: number[] = [];
        items.forEach((item: RawReplaceRule) => {
          const rule = ReplaceRuleImporter.toRule(item, reservedIds, assignedIds);
          if (rule === undefined) {
            skipped += 1;
          } else {
            rules.push(rule);
          }
        });
        return { rules: rules, skipped: skipped };
      }
      if (trimmed.startsWith('{')) {
        const single: RawReplaceRule = JSON.parse(trimmed);
        const reservedIds: number[] = typeof single.id === 'number' && single.id > 0 ? [single.id] : [];
        const rule = ReplaceRuleImporter.toRule(single, reservedIds, []);
        if (rule === undefined) {
          return { rules: [], skipped: 1 };
        }
        return { rules: [rule], skipped: 0 };
      }
    } catch (_) {
      // 落到下面统一按「格式不可识别」处理。
    }
    return { rules: [], skipped: 1 };
  }

  /** 把一条原始数据转换成规则；缺少匹配内容或正则非法时返回 undefined。 */
  private static toRule(raw: RawReplaceRule, reservedIds: number[], assignedIds: number[]): ReplaceRule | undefined {
    if (raw === undefined || raw === null) {
      return undefined;
    }
    const pattern = ReplaceRuleImporter.pickString(raw.pattern, raw.regex);
    if (pattern.length === 0) {
      return undefined;
    }
    const isRegex = ReplaceRuleImporter.pickBoolean(raw.isRegex, true);
    if (isRegex && !ReplaceRuleImporter.isValidRegex(pattern)) {
      return undefined;
    }
    // scopeContent 缺省为 true：Android 实体默认作用于正文。
    const scopeContent = typeof raw.scopeContent === 'boolean' ? raw.scopeContent : true;
    const scopeTitle = raw.scopeTitle === true;
    const group = ReplaceRuleImporter.pickString(raw.group, '');
    const sourceId = typeof raw.id === 'number' && raw.id > 0 ? raw.id : 0;
    const id = sourceId > 0 && !assignedIds.includes(sourceId)
      ? sourceId : ReplaceRuleImporter.nextUniqueId(reservedIds, assignedIds);
    assignedIds.push(id);
    return {
      id: id,
      name: ReplaceRuleImporter.pickString(raw.name, raw.replaceSummary),
      group: group.length > 0 ? group : '默认',
      pattern: pattern,
      replacement: ReplaceRuleImporter.pickString(raw.replacement, ''),
      scope: ReplaceRuleImporter.pickString(raw.scope, raw.useTo),
      scopeTitle: scopeTitle,
      scopeContent: scopeContent,
      excludeScope: ReplaceRuleImporter.pickString(raw.excludeScope, ''),
      isEnabled: ReplaceRuleImporter.pickBoolean(raw.isEnabled, ReplaceRuleImporter.pickBoolean(raw.enable, true)),
      isRegex: isRegex,
      timeoutMillisecond: typeof raw.timeoutMillisecond === 'number' && raw.timeoutMillisecond > 0
        ? raw.timeoutMillisecond : 3000,
      order: typeof raw.order === 'number' ? raw.order
        : (typeof raw.serialNumber === 'number' ? raw.serialNumber : 0)
    };
  }

  /** 生成当前批次内不重复且不覆盖输入中显式 ID 的新标识。 */
  private static nextUniqueId(reservedIds: number[], assignedIds: number[]): number {
    let id = Date.now();
    while (reservedIds.includes(id) || assignedIds.includes(id)) {
      id += 1;
    }
    return id;
  }

  /** 取第一个非空字符串，用于主字段与旧版字段的二选一。 */
  private static pickString(primary: string | undefined, fallback: string | undefined): string {
    if (typeof primary === 'string' && primary.length > 0) {
      return primary;
    }
    return typeof fallback === 'string' ? fallback : '';
  }

  private static pickBoolean(primary: boolean | undefined, fallback: boolean): boolean {
    return typeof primary === 'boolean' ? primary : fallback;
  }

  /**
   * 校验正则是否可用。
   * 除语法外还拒绝以裸 | 结尾的表达式，这类写法在替换时容易触发超时，
   * 与 Android ReplaceRule.isValid() 的检查保持一致。
   */
  private static isValidRegex(pattern: string): boolean {
    try {
      new RegExp(pattern);
    } catch (_) {
      return false;
    }
    if (pattern.endsWith('|') && !pattern.endsWith('\\|')) {
      return false;
    }
    return true;
  }
}
