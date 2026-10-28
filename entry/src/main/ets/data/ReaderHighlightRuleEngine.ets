import { ReaderHighlightRange, ReaderHighlightRule, ReaderHighlightStyle } from '../model/ReaderHighlightRule';

/** Android 正文高亮规则在 HOS 当前章节中的有限兼容实现。 */
export class ReaderHighlightRuleEngine {
  static readonly maximumPatternLength: number = 256;
  static readonly maximumChapterCharacters: number = 150000;
  static readonly maximumRuleCount: number = 64;
  static compilePattern(pattern: string): RegExp {
    let source = pattern;
    let flags = 'gu';
    const inlineFlags = /^\(\?([ims]+)\)/.exec(source);
    if (inlineFlags !== null) {
      const requested = inlineFlags[1] ?? '';
      source = source.substring(inlineFlags[0].length);
      for (let index = 0; index < requested.length; index++) {
        const flag = requested.charAt(index);
        if (!flags.includes(flag)) { flags += flag; }
      }
    }
    // Android Java Pattern 的 IsHan 属性在 ECMAScript RegExp 中使用 Script=Han 表示。
    source = source.replace(/\\p\{IsHan\}/g, '\\p{Script=Han}');
    return new RegExp(source, flags);
  }

  static isSupported(pattern: string): boolean {
    if (pattern.length === 0 || pattern.length > ReaderHighlightRuleEngine.maximumPatternLength ||
      ReaderHighlightRuleEngine.hasKnownDangerousStructure(pattern)) { return false; }
    try {
      ReaderHighlightRuleEngine.compilePattern(pattern);
      return true;
    } catch (_) {
      return false;
    }
  }

  private static hasKnownDangerousStructure(pattern: string): boolean {
    // 拒绝常见的嵌套重复、重复分支和重复反向引用；这只是风险筛查，不是执行超时保证。
    return /\([^)]*[+*{][^)]*\)[+*{]/.test(pattern) ||
      /\([^)]*\|[^)]*\)[+*{]/.test(pattern) ||
      /\\[1-9][0-9]*(?:[*+?]|\{[0-9])/.test(pattern);
  }

  static findBodyRanges(text: string, rules: ReaderHighlightRule[]): ReaderHighlightRange[] {
    if (text.length > ReaderHighlightRuleEngine.maximumChapterCharacters ||
      rules.length > ReaderHighlightRuleEngine.maximumRuleCount) { return []; }
    const ranges: ReaderHighlightRange[] = [];
    const ordered = [...rules].sort((left: ReaderHighlightRule, right: ReaderHighlightRule) =>
      left.position - right.position);
    for (let index = 0; index < ordered.length; index++) {
      const rule = ordered[index];
      if (rule === undefined || !rule.enabled || rule.pattern.trim().length === 0 ||
        !ReaderHighlightRuleEngine.isSupported(rule.pattern) ||
        (rule.targetScope !== 0 && rule.targetScope !== 2) ||
        (rule.configName !== null && rule.configName !== undefined && rule.configName.trim().length > 0)) {
        continue;
      }
      let matcher: RegExp;
      try {
        matcher = ReaderHighlightRuleEngine.compilePattern(rule.pattern);
      } catch (_) {
        continue;
      }
      let match = matcher.exec(text);
      while (match !== null) {
        const matchedText = match[0] ?? '';
        const start = match.index;
        if (matchedText.length > 0) {
          ranges.push({
            start: start,
            endExclusive: start + matchedText.length,
            priority: index,
            rule: rule
          });
        } else {
          // 避免零宽正则重复命中同一字符位置。
          const codePoint = text.codePointAt(matcher.lastIndex);
          matcher.lastIndex += codePoint !== undefined && codePoint > 0xFFFF ? 2 : 1;
        }
        match = matcher.exec(text);
      }
    }
    return ranges;
  }

  /** 与 Android 同优先级后规则覆盖前规则的 resolver 一致。 */
  static resolve(ranges: ReaderHighlightRange[], start: number, endExclusive: number): ReaderHighlightStyle | undefined {
    let winner: ReaderHighlightRange | undefined;
    for (let index = 0; index < ranges.length; index++) {
      const range = ranges[index];
      if (range !== undefined && range.start < endExclusive && range.endExclusive > start &&
        (winner === undefined || range.priority >= winner.priority)) {
        winner = range;
      }
    }
    if (winner === undefined) { return undefined; }
    return {
      textColor: winner.rule.textColor,
      bgColor: winner.rule.bgColor,
      underlineMode: winner.rule.underlineMode,
      underlineColor: winner.rule.underlineColor
    };
  }

  static colorToCss(color: number | null | undefined): string | undefined {
    if (color === null || color === undefined) { return undefined; }
    const unsigned = color >>> 0;
    const alpha = (unsigned >>> 24) & 0xFF;
    const red = (unsigned >>> 16) & 0xFF;
    const green = (unsigned >>> 8) & 0xFF;
    const blue = unsigned & 0xFF;
    const alphaText = alpha.toString(16).padStart(2, '0');
    const redText = red.toString(16).padStart(2, '0');
    const greenText = green.toString(16).padStart(2, '0');
    const blueText = blue.toString(16).padStart(2, '0');
    return `#${alphaText}${redText}${greenText}${blueText}`.toUpperCase();
  }

  static colorFromCss(value: string): number | undefined {
    const normalized = value.trim().replace(/^#/, '');
    if (!/^(?:[0-9A-Fa-f]{6}|[0-9A-Fa-f]{8})$/.test(normalized)) { return undefined; }
    const full = normalized.length === 6 ? `FF${normalized}` : normalized;
    const parsed = Number.parseInt(full, 16);
    return Number.isFinite(parsed) ? parsed | 0 : undefined;
  }
}