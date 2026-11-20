/**
 * Global regex replacement that can be abandoned once a deadline passes.
 *
 * A JavaScript regex call cannot be interrupted, and on ArkTS a long one is worse than slow: the
 * regex executor never reaches a GC safepoint, so a shared-heap GC waits for the worker running
 * it while the UI thread waits for that GC. One pathological purification rule inside TaskPool
 * therefore froze the whole app (THREAD_BLOCK_6S) even though it never ran on the UI thread.
 *
 * Every native call made here is kept short instead:
 * - rules that cannot match a line break run line by line, so `.*` / `\W*` backtracking is bounded
 *   by the paragraph instead of the chapter;
 * - long chunks (and rules that do span lines) are matched one start position at a time with a
 *   sticky regex, which returns to the interpreter between attempts;
 * - the deadline is checked between calls and `null` is returned once it has passed, so the
 *   caller keeps the original text.
 */
export class BudgetedRegexReplace {
  /** 不超过该长度的分块直接交给原生 replace：单次调用的回溯量有上限，速度也最快。 */
  static readonly NATIVE_CHUNK_LIMIT: number = 256;
  private static readonly LINE_CHECK_INTERVAL: number = 8;
  private static readonly POSITION_CHECK_INTERVAL: number = 8;

  private readonly matcher: RegExp;
  private readonly sticky: RegExp;
  private readonly unicode: boolean;
  /** 规则显式跨行，必须对整段文本执行。 */
  readonly acrossLines: boolean;

  constructor(source: string, flags: string, textHasCarriageReturn: boolean) {
    const base = (flags || '').replace(/[gy]/g, '');
    this.matcher = new RegExp(source, base + 'g');
    this.sticky = new RegExp(source, base + 'y');
    this.unicode = base.includes('u');
    this.acrossLines = BudgetedRegexReplace.canMatchAcrossLines(source, base, textHasCarriageReturn);
  }

  /**
   * 规则是否“显式”依赖换行：字面的 `\n`、`\s`、`[\s\S]` 这类全字符类、dotAll 标志，或不带 m 标志
   * 的 `^`/`$`（锚定整段文本）。这些规则逐行执行会改变结果，只能整段执行。
   *
   * `\W`、`\D`、`[^x]` 只是“顺带”能匹配换行，按行执行：它们正是整章回溯的来源，代价是这类写法
   * 不再能跨段落吞字。文本里没有 `\r` 时，`\r\n` 永远匹配不上，不算跨行。
   */
  static canMatchAcrossLines(source: string, flags: string, textHasCarriageReturn: boolean): boolean {
    if ((flags || '').includes('s')) return true;
    const multiline = (flags || '').includes('m');
    let index = 0;
    let inClass = false;
    let negated = false;
    let classBreak = false;
    let classEscapes = '';
    while (index < source.length) {
      const ch = source.charAt(index);
      if (ch === '\\') {
        const next = source.charAt(index + 1);
        const isBreak = next === 'n' || next === 's' || (next === 'r' && textHasCarriageReturn) ||
          (next === 'x' && /^0[aAdD]/.test(source.substring(index + 2, index + 4))) ||
          (next === 'u' && /^000[aAdD]/.test(source.substring(index + 2, index + 6)));
        if (inClass) {
          if (isBreak) classBreak = true;
          classEscapes += next;
        } else {
          if (isBreak) return true;
          if (next === 'r' && source.startsWith('\\n', index + 2)) {
            index += 4;
            continue;
          }
        }
        index += 2;
        continue;
      }
      if (inClass) {
        if (ch === ']') {
          const anyChar = (classEscapes.includes('d') && classEscapes.includes('D')) ||
            (classEscapes.includes('w') && classEscapes.includes('W'));
          if (!negated && (classBreak || anyChar)) return true;
          inClass = false;
        } else if (ch === '\n') {
          classBreak = true;
        }
        index++;
        continue;
      }
      if (ch === '[') {
        inClass = true;
        negated = source.charAt(index + 1) === '^';
        classBreak = false;
        classEscapes = '';
        index += negated ? 2 : 1;
        continue;
      }
      if (ch === '\n' || ((ch === '^' || ch === '$') && !multiline)) return true;
      index++;
    }
    return false;
  }

  /** 返回替换后的文本；超过 deadline（Date.now() 时间戳）时返回 null，调用方应保留原文。 */
  replace(text: string, replacement: string, deadline: number): string | null {
    if (!text) return text;
    if (text.length <= BudgetedRegexReplace.NATIVE_CHUNK_LIMIT) {
      return Date.now() > deadline ? null : this.replaceNative(text, replacement);
    }
    if (this.acrossLines) return this.replaceStepped(text, replacement, deadline);

    const parts: string[] = [];
    let start = 0;
    let lines = 0;
    while (start <= text.length) {
      let end = text.indexOf('\n', start);
      if (end < 0) end = text.length;
      const line = text.substring(start, end);
      const long = line.length > BudgetedRegexReplace.NATIVE_CHUNK_LIMIT;
      if ((long || ++lines % BudgetedRegexReplace.LINE_CHECK_INTERVAL === 0) && Date.now() > deadline) return null;
      const replaced = long ? this.replaceStepped(line, replacement, deadline) : this.replaceNative(line, replacement);
      if (replaced === null) return null;
      parts.push(replaced);
      start = end + 1;
    }
    return parts.join('\n');
  }

  private replaceNative(chunk: string, replacement: string): string {
    this.matcher.lastIndex = 0;
    return chunk.replace(this.matcher, replacement);
  }

  /** 逐个起点尝试匹配，结果与原生全局 replace 一致，但每次原生调用只负责一个起点。 */
  private replaceStepped(chunk: string, replacement: string, deadline: number): string | null {
    const parts: string[] = [];
    let last = 0;
    let position = 0;
    let attempts = 0;
    while (position <= chunk.length) {
      if (++attempts % BudgetedRegexReplace.POSITION_CHECK_INTERVAL === 0 && Date.now() > deadline) return null;
      this.sticky.lastIndex = position;
      const match = this.sticky.exec(chunk);
      if (match === null || match[0].length === 0) {
        if (match !== null) {
          parts.push(chunk.substring(last, position), this.expand(match, chunk, position, replacement));
          last = position;
        }
        const code = this.unicode ? chunk.charCodeAt(position) : 0;
        const pair = code >= 0xD800 && code <= 0xDBFF && position + 1 < chunk.length &&
          (chunk.charCodeAt(position + 1) & 0xFC00) === 0xDC00;
        position += pair ? 2 : 1;
        continue;
      }
      parts.push(chunk.substring(last, position), this.expand(match, chunk, position, replacement));
      position += match[0].length;
      last = position;
    }
    parts.push(chunk.substring(last));
    return parts.join('');
  }

  /** 按 String.prototype.replace 的规则展开替换串里的 `$1`、`$&`、`$<name>` 等引用。 */
  private expand(match: RegExpExecArray, input: string, position: number, replacement: string): string {
    if (replacement.indexOf('$') < 0) return replacement;
    const groupCount = match.length - 1;
    let result = '';
    let index = 0;
    while (index < replacement.length) {
      const ch = replacement.charAt(index);
      const next = replacement.charAt(index + 1);
      if (ch !== '$' || !next) {
        result += ch;
        index++;
        continue;
      }
      if (next === '$') {
        result += '$';
        index += 2;
      } else if (next === '&') {
        result += match[0];
        index += 2;
      } else if (next === '`') {
        result += input.substring(0, position);
        index += 2;
      } else if (next === '\'') {
        result += input.substring(position + match[0].length);
        index += 2;
      } else if (next >= '0' && next <= '9') {
        const after = replacement.charAt(index + 2);
        const two = after >= '0' && after <= '9' ? parseInt(next + after, 10) : 0;
        const one = parseInt(next, 10);
        if (two >= 1 && two <= groupCount) {
          result += match[two] || '';
          index += 3;
        } else if (one >= 1 && one <= groupCount) {
          result += match[one] || '';
          index += 2;
        } else {
          result += '$';
          index++;
        }
      } else if (next === '<' && match.groups) {
        const close = replacement.indexOf('>', index + 2);
        if (close < 0) {
          result += '$';
          index++;
        } else {
          result += match.groups[replacement.substring(index + 2, close)] || '';
          index = close + 1;
        }
      } else {
        result += '$';
        index++;
      }
    }
    return result;
  }
}
