/** 与 Android ReplaceRule 字段对齐的本地规则模型。 */
export interface ReplaceRule {
  id: number;
  name: string;
  group: string;
  pattern: string;
  replacement: string;
  scope: string;
  scopeTitle: boolean;
  scopeContent: boolean;
  excludeScope: string;
  isEnabled: boolean;
  isRegex: boolean;
  timeoutMillisecond: number;
  order: number;
}

/** 为规则列表提供稳定键；展示字段变化时让 ArkUI 重建对应行。 */
export function replaceRuleRowKey(rule: ReplaceRule): string {
  return `${rule.id}_${rule.isEnabled ? 1 : 0}_${rule.name}_${rule.group}_${rule.pattern}_${rule.replacement}_${rule.scope}_${rule.excludeScope}_${rule.scopeContent ? 1 : 0}${rule.scopeTitle ? 1 : 0}_${rule.isRegex ? 1 : 0}`;
}
