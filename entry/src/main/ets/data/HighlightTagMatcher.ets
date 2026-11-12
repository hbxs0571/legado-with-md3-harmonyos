import { HighlightTagRule } from '../model/HighlightTagRule';

/** 一个高亮块：命中的原始标签 + 规则标题（上游 `HighlightTag.title`）。 */
export interface HighlightedTag {
  matchedLabels: string[];
  title: string;
}

/**
 * 按高亮标签规则给标签归类（批 7 的 `:299`）。
 *
 * 对齐上游 `help/book/BookExtensions.kt:398-429`：规则按 order 顺序逐条试，
 * 一条标签只归**第一条**命中的规则（首次命中即 break），后面的规则不再拿它重复显示。
 * 非法正则跳过该条规则，不影响其它规则——上游 `Regex(...)` 抛错时也不会整体失败。
 *
 * 与上游的唯一差异：匹配源只有自定义标签与分类两路。上游还有一路「书源标签」
 * （`Book.kind` 里的来源标签），本地没有书源体系，不硬造。
 */
export function matchHighlightTags(labels: string[], rules: HighlightTagRule[]): HighlightedTag[] {
  const source = labels.filter((label: string) => label.length > 0);
  if (source.length === 0 || rules.length === 0) { return []; }
  const used: string[] = [];
  const result: HighlightedTag[] = [];
  rules.forEach((rule: HighlightTagRule) => {
    if (!rule.enabled) { return; }
    let regex: RegExp;
    try {
      regex = new RegExp(rule.pattern);
    } catch (_) {
      return;
    }
    const matched: string[] = [];
    source.forEach((label: string) => {
      if (used.includes(label)) { return; }
      if (regex.test(label)) { matched.push(label); }
    });
    if (matched.length === 0) { return; }
    matched.forEach((label: string) => used.push(label));
    result.push({ matchedLabels: matched, title: rule.title });
  });
  return result;
}
