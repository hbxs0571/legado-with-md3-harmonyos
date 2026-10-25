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
