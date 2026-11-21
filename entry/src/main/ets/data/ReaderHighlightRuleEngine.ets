import { ReaderHighlightRange, ReaderHighlightRule, ReaderHighlightStyle } from '../model/ReaderHighlightRule';

/**
 * 批8 D 组（:923）：把 configName 当 JSON 数组字符串处理。
 * 对齐上游 HighlightRuleRepository.kt:411-431：
 * - 空（null/空白）= 全局规则，对所有排版生效；
 * - 非空 = 仅在列出的排版名里生效。
 * 解析失败回空数组，绝不抛（上游 runCatching{}.getOrElse{ emptyList() } 语义）。
 */
export function configNamesOf(configName: string | null | undefined): string[] {
  if (configName === null || configName === undefined || configName.trim().length === 0) { return []; }
  try {
    const parsed: string[] = JSON.parse(configName);
    if (!Array.isArray(parsed)) { return []; }
    const names: string[] = [];
    for (let index = 0; index < parsed.length; index++) {
      const item = parsed[index];
      if (typeof item === 'string' && item.length > 0) { names.push(item); }
    }
    return names;
  } catch (_) {
    return [];
  }
}

/** 空数组 → null（全局），否则序列化成 JSON 数组串。 */
export function toConfigNameJson(names: string[]): string | null {
  if (names.length === 0) { return null; }
  return JSON.stringify(names);
}

/** 规则在当前排版名下是否生效：空 configName = 全局生效；否则当前名在列表里才生效。 */
export function ruleMatchesConfig(rule: ReaderHighlightRule, currentConfigName: string): boolean {
  const names = configNamesOf(rule.configName);
  if (names.length === 0) { return true; }
  return names.includes(currentConfigName);
}

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

  /**
   * @param currentConfigName 当前排版名（本地 = 背景样式名）。空串表示未指定排版，
   *   此时仅全局规则生效。批8 D 组前这里的判定是「有 configName 就跳过」（做反了），
   *   现已改为上游语义：空 = 全局生效、非空 = 仅列出的排版名生效。
   */
  static findBodyRanges(text: string, rules: ReaderHighlightRule[],
    currentConfigName: string = ''): ReaderHighlightRange[] {
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
        !ruleMatchesConfig(rule, currentConfigName)) {
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