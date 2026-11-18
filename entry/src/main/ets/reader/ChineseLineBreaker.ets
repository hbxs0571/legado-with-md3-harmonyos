/**
 * 中文断行，逐句移植上游 app/src/main/java/io/legado/app/feature/reader/core/layout/ChineseLineBreaker.kt。
 *
 * 四模式（上游 :207）：NORMAL / PULL_PREVIOUS / REWIND / HANG。
 * 语义差异说明：上游在排版循环里边排边判；本地把「某一 cluster 溢出时该从哪重启下一行」
 * 抽成纯函数 nextLineStart，breakLines 只负责遍历与状态累积，便于单测与回退。
 * 宽度由调用方用平台测宽器给出，本文件不依赖任何 UI/Context。
 */

/** 一次断点决策的结果（对应一次断行的全部副产物）。 */
export class ChineseLineBreakResult {
  /** 下一行的字符起点（上游 addStart 的 character）。 */
  nextCharStart: number = 0;
  /** 下一行的 cluster 起点（上游 addStart 的 cluster）。 */
  nextClusterStart: number = 0;
  /** 本行向下一行携带的宽度。 */
  carriedWidth: number = 0;
  /** 携带的字符数。 */
  carriedCharacters: number = 0;
  /** 携带的 cluster 数。 */
  carriedClusters: number = 0;
  /** 本行是否悬挂（悬挂行宽度可超出行宽上限）。 */
  hungLine: boolean = false;
  /** 采用的模式：0=NORMAL 1=PULL_PREVIOUS 2=REWIND 3=HANG（调试用）。 */
  mode: number = 0;
}

/** 断行模式常量，对应上游 enum class Mode。 */
const MODE_NORMAL: number = 0;
const MODE_PULL_PREVIOUS: number = 1;
const MODE_REWIND: number = 2;
const MODE_HANG: number = 3;

export class ChineseLineBreaker {
  private readonly clusters: string[];
  private readonly widthsPx: number[];
  private readonly indentCharacters: number;
  private readonly widthLimit: number;
  private readonly firstWidthLimit: number;
  private readonly ideographWidthPx: number;

  private starts: number[] = [0];
  private clusterStarts: number[] = [0];
  private widths: number[] = [];

  constructor(
    clusters: string[],
    widthsPx: number[],
    indentCharacters: number,
    widthPx: number,
    ideographWidthPx: number,
    letterSpacingPx: number,
    firstLineWidthPx: number = widthPx,
  ) {
    if (clusters.length !== widthsPx.length) {
      throw new Error('ChineseLineBreaker: clusters/widthsPx length mismatch');
    }
    this.clusters = clusters;
    this.widthsPx = widthsPx;
    this.indentCharacters = indentCharacters;
    this.widthLimit = widthPx + letterSpacingPx;
    this.firstWidthLimit = firstLineWidthPx + letterSpacingPx;
    this.ideographWidthPx = ideographWidthPx;
    this.breakLines();
  }

  /** 每行字符起点（上游 lineStarts）。 */
  get lineStarts(): number[] {
    return this.starts.slice();
  }

  /** 每行 cluster 起点（上游 lineClusterStarts）。 */
  get lineClusterStarts(): number[] {
    return this.clusterStarts.slice();
  }

  /** 每行像素宽度（上游 lineWidthsPx，悬挂行可超限）。 */
  get lineWidthsPx(): number[] {
    return this.widths.slice();
  }

  /** 行数（上游 lineCount）。 */
  get lineCount(): number {
    return this.widths.length;
  }

  /** 主遍历，逐句对应上游 breakLines()。 */
  private breakLines(): void {
    if (this.clusters.length === 0) { return; }
    let lineWidth = 0;
    let textLength = 0;
    for (let index = 0; index < this.clusters.length; index++) {
      const cluster: string = this.clusters[index];
      lineWidth += this.widthsPx[index];
      let carriedWidth = 0;
      let carriedCharacters = 0;
      let carriedClusters = 0;
      let hungLine = false;
      const currentWidthLimit = this.widths.length === 0 ? this.firstWidthLimit : this.widthLimit;
      // 行首不留词间空格：溢出到这里的空格留在本行行尾（不可见），由紧随其后的词首触发整词回退。
      const keepSpaceAtLineEnd = ChineseLineBreaker.isWordSpace(cluster) &&
        index > this.clusterStarts[this.clusterStarts.length - 1];
      if (lineWidth > currentWidthLimit && !keepSpaceAtLineEnd) {
        const lineStart = this.clusterStarts[this.clusterStarts.length - 1];
        const decision = ChineseLineBreaker.nextLineStart(
          this.clusters, this.widthsPx, this.ideographWidthPx,
          index, lineStart, this.indentCharacters, this.widths.length === 0, textLength);
        carriedWidth = decision.carriedWidth;
        carriedCharacters = decision.carriedCharacters;
        carriedClusters = decision.carriedClusters;
        hungLine = decision.hungLine;
        // 对应上游 addStart：先落起点，再记本行实际宽度。
        this.starts.push(decision.nextCharStart);
        this.clusterStarts.push(decision.nextClusterStart);
        this.widths.push(lineWidth - carriedWidth);
        lineWidth = carriedWidth;
      }
      if (index === this.clusters.length - 1) {
        if (this.starts.length === this.widths.length + 1) {
          // 悬挂已把标点留在本行、下一行从它之后开始，不再补一行。
          if (!hungLine) {
            this.starts.push(textLength + cluster.length);
            this.clusterStarts.push(index + 1);
            this.widths.push(lineWidth);
          }
        } else if (carriedClusters > 0) {
          this.starts.push(this.starts[this.starts.length - 1] + carriedCharacters);
          this.clusterStarts.push(this.clusterStarts[this.clusterStarts.length - 1] + carriedClusters);
          this.widths.push(lineWidth);
        }
      }
      textLength += cluster.length;
    }
  }

  /**
   * 纯函数：给定完整 cluster 序列与当前溢出 cluster，算出下一行从哪里开始。
   *
   * @param clusters 全部 cluster 字符串（标点判定与整词回退都依赖上下文）
   * @param widthsPx 每个 cluster 的宽度，与 lineWidth 同单位
   * @param ideographWidthPx 一个汉字的宽度，用来判断窄标点可压缩
   * @param index 当前溢出的 cluster 下标
   * @param lineStart 本行起点 cluster 下标
   * @param indentCharacters 首行缩进字符数（REWIND 回退下界用）
   * @param firstLine 当前是否为首行（REWIND 回退下界用）
   * @param textLength 当前 cluster 之前的累计字符数
   */
  static nextLineStart(
    clusters: string[],
    widthsPx: number[],
    ideographWidthPx: number,
    index: number,
    lineStart: number,
    indentCharacters: number,
    firstLine: boolean,
    textLength: number,
  ): ChineseLineBreakResult {
    const result = new ChineseLineBreakResult();
    const cluster: string = clusters[index];
    const clusterLength: number = cluster.length;

    // 可压缩窄标点：宽度小于一个汉字（对应上游 compressibleAt）。
    const compressibleAt = (at: number): boolean =>
      at >= 0 && at < widthsPx.length && widthsPx[at] < ideographWidthPx;

    // 对应上游 carryFrom(candidate)：按合法断点回退，算出携带量。
    const carryFrom = (candidate: number): void => {
      const start = ChineseLineBreaker.safeBreakStart(clusters, candidate, lineStart);
      let carriedWidth = 0;
      let carriedCharacters = 0;
      let carriedClusters = 0;
      for (let k = start; k <= index; k++) {
        carriedWidth += widthsPx[k];
        carriedCharacters += clusters[k].length;
        carriedClusters++;
      }
      result.carriedWidth = carriedWidth;
      result.carriedCharacters = carriedCharacters;
      result.carriedClusters = carriedClusters;
      result.nextCharStart = textLength - carriedCharacters + clusterLength;
      result.nextClusterStart = start;
    };

    // 与上游 :64-79 逐条对应。
    const previousClosing = index > 0 && ChineseLineBreaker.CLOSING.has(clusters[index - 1]);
    const previousOpening = index > 0 && ChineseLineBreaker.OPENING.has(clusters[index - 1]);
    const secondPreviousOpening = index > 1 && ChineseLineBreaker.OPENING.has(clusters[index - 2]);
    const nextClosing = index < clusters.length - 1 && ChineseLineBreaker.CLOSING.has(clusters[index + 1]);
    const clusterIsClosing = ChineseLineBreaker.CLOSING.has(cluster);
    let compressibleAround = false;
    if (previousOpening && secondPreviousOpening) {
      compressibleAround = compressibleAt(index - 1) || compressibleAt(index - 2);
    } else if (clusterIsClosing && previousClosing) {
      compressibleAround = compressibleAt(index) || compressibleAt(index - 1);
    } else if (clusterIsClosing && secondPreviousOpening) {
      compressibleAround = compressibleAt(index) || compressibleAt(index - 2);
    }

    // 悬挂条件：排除「下一字仍是收尾标点」（那种走 reCheck 回退）。
    const hangs = index > 0 && !compressibleAround && !nextClosing &&
      ((previousOpening && secondPreviousOpening) ||
        (clusterIsClosing && (previousClosing || secondPreviousOpening)));

    // 判定链，与上游 :84-92 对应。
    let mode: number = MODE_NORMAL;
    if (hangs) {
      mode = MODE_HANG;
    } else if (index > 0 && clusterIsClosing && clusters[index - 1] === cluster) {
      // 同一标点连打就地断行、本行填满。
      mode = MODE_NORMAL;
    } else if (index > 0 && (previousOpening || clusterIsClosing)) {
      mode = MODE_PULL_PREVIOUS;
    }

    // 可压缩标点会把收尾标点留到下一行行首，回退到更早的非标点边界。
    let rewindClusters = 0;
    const needsRecheck = mode === MODE_PULL_PREVIOUS && (previousClosing || nextClosing);
    if (needsRecheck && index > 2) {
      const rewindLineStart = firstLine ? indentCharacters : lineStart;
      mode = MODE_NORMAL;
      for (let candidate = index; candidate >= rewindLineStart + 1; candidate--) {
        if (candidate !== index) { rewindClusters++; }
        if (!ChineseLineBreaker.CLOSING.has(clusters[candidate]) &&
          !ChineseLineBreaker.OPENING.has(clusters[candidate - 1])) {
          mode = MODE_REWIND;
          break;
        }
      }
    }

    if (mode === MODE_NORMAL) {
      carryFrom(index);
    } else if (mode === MODE_PULL_PREVIOUS) {
      carryFrom(index - 1);
    } else if (mode === MODE_REWIND) {
      carryFrom(index - rewindClusters);
    } else {
      // HANG：标点留在本行（宽度超限），下一行从它之后开始，不携带任何宽度。
      result.carriedWidth = 0;
      result.nextCharStart = textLength + clusterLength;
      result.nextClusterStart = index + 1;
      result.carriedCharacters = 0;
      result.carriedClusters = 0;
      result.hungLine = true;
    }
    result.mode = mode;
    return result;
  }

  /**
   * 避头尾谓词（上游 companion object isForbiddenBreak，供第二层标点回拉复用）。
   * 唯一例外是同一个标点连打。
   */
  static isForbiddenBreak(previous: string, next: string): boolean {
    return (ChineseLineBreaker.CLOSING.has(next) && previous !== next) ||
      ChineseLineBreaker.OPENING.has(previous);
  }

  /** 是否收尾标点（不应落行首）。第二层后处理按这个判定拉回行尾。 */
  static isClosingMark(cluster: string): boolean {
    return ChineseLineBreaker.CLOSING.has(cluster);
  }

  /** 是否起始标点（不应留行尾）。第二层后处理按这个判定推到下一行。 */
  static isOpeningMark(cluster: string): boolean {
    return ChineseLineBreaker.OPENING.has(cluster);
  }

  /** 词间空格（含不换行空格、全角空格）：断行时只能留行尾，不能落行首。 */
  static isWordSpace(cluster: string): boolean {
    if (cluster.length === 0) { return false; }
    for (let i = 0; i < cluster.length; i++) {
      if (!ChineseLineBreaker.isSpaceCode(cluster.charCodeAt(i))) { return false; }
    }
    return true;
  }

  /** Java isWhitespace || isSpaceChar 的 BMP 并集。 */
  private static isSpaceCode(code: number): boolean {
    return code === 0x20 || (code >= 0x09 && code <= 0x0d) || code === 0x85 ||
      code === 0xa0 || code === 0x1680 || (code >= 0x2000 && code <= 0x200a) ||
      code === 0x2028 || code === 0x2029 || code === 0x202f ||
      code === 0x205f || code === 0x3000;
  }

  /** 对应上游 safeBreakStart：词首前紧贴开标点时连标点一起回退。 */
  private static safeBreakStart(clusters: string[], candidate: number, lineStart: number): number {
    const latinStart = ChineseLineBreaker.latinWordStartBefore(clusters, candidate);
    const start = latinStart === null ? candidate : latinStart;
    if (start <= lineStart) { return candidate; }
    let breakStart = start;
    while (breakStart > lineStart + 1 && ChineseLineBreaker.OPENING.has(clusters[breakStart - 1])) {
      breakStart--;
    }
    if (ChineseLineBreaker.OPENING.has(clusters[breakStart - 1])) { return candidate; }
    return breakStart;
  }

  /** 对应上游 latinWordStartBefore：index 处是否在一个 Latin 单词内部及其词首。 */
  private static latinWordStartBefore(clusters: string[], index: number): number | null {
    if (index === 0 || !ChineseLineBreaker.isLatinWordPart(clusters[index]) ||
      !ChineseLineBreaker.isLatinWordPart(clusters[index - 1])) {
      return null;
    }
    let start = index - 1;
    while (start > 0 && ChineseLineBreaker.isLatinWordPart(clusters[start - 1])) { start--; }
    return start;
  }

  /**
   * 对应上游 String.isLatinWordPart：Latin 字母/数字/组合标记/撇号组成的词。
   * 上游用 Character.isLetter + UnicodeScript.LATIN 精确判定；这里按 BMP 的 Latin 区段近似，
   * 覆盖实际书里会遇到的 Latin-1 补充、Latin 扩展 A/B、扩展附加（越南语）与全角字母，
   * 组合标记按 U+0300-U+036F 近似。必须含 Latin 字母，或全部为数字/撇号。
   */
  private static isLatinWordPart(cluster: string): boolean {
    if (cluster.length === 0) { return false; }
    let hasLatinLetter = false;
    let allDigitOrApostrophe = true;
    for (let i = 0; i < cluster.length; i++) {
      const code = cluster.charCodeAt(i);
      const isLatin = ChineseLineBreaker.isLatinLetterCode(code);
      const isDigit = code >= 0x30 && code <= 0x39;
      const isMark = code >= 0x0300 && code <= 0x036f;
      const isApostrophe = code === 0x27 || code === 0x2019;
      if (isLatin) {
        hasLatinLetter = true;
      } else if (!isDigit && !isApostrophe) {
        allDigitOrApostrophe = false;
        if (!isMark) { return false; }
      }
      if (!isDigit && !isApostrophe) { allDigitOrApostrophe = false; }
    }
    return hasLatinLetter || allDigitOrApostrophe;
  }

  /** Latin 字母的 BMP 区段近似（排除 × U+00D7 与 ÷ U+00F7 等非字母符号）。 */
  private static isLatinLetterCode(code: number): boolean {
    return (code >= 0x41 && code <= 0x5a) ||        // A-Z
      (code >= 0x61 && code <= 0x7a) ||             // a-z
      code === 0xaa || code === 0xba ||             // ª º
      (code >= 0xc0 && code <= 0xd6) ||             // À-Ö
      (code >= 0xd8 && code <= 0xf6) ||             // Ø-ö
      (code >= 0xf8 && code <= 0x2af) ||            // ø-ʯ（含 Latin-1 小写与 IPA 扩展）
      (code >= 0x1e00 && code <= 0x1eff) ||         // Latin 扩展附加（越南语等）
      code === 0x2071 || code === 0x207f ||         // ⁱ ⁿ
      (code >= 0x2c60 && code <= 0x2c7f) ||         // Latin 扩展 C
      (code >= 0xa720 && code <= 0xa7ff) ||         // Latin 扩展 D
      (code >= 0xff21 && code <= 0xff3a) ||         // 全角 Ａ-Ｚ
      (code >= 0xff41 && code <= 0xff5a);           // 全角 ａ-ｚ
  }

  // 收尾标点集合：逐字照抄上游 closing，一个字符不多不少。
  private static readonly CLOSING: Set<string> = new Set<string>([
    '！', '，', '。', '、', '；', '：', '？', '”', '’', '）', '］', '｝', '》',
    '〉', '〕', '】', '〗', '」', '』', '﹂', '﹄', '…', '—', '～', '·',
    '!', ',', '.', ':', ';', '?', ')', ']', '}', '>',
  ]);

  // 起始标点集合：逐字照抄上游 opening，一个字符不多不少。
  private static readonly OPENING: Set<string> = new Set<string>([
    '“', '‘', '（', '［', '｛', '《', '〈', '〔', '【', '〖', '『', '「', '﹁', '﹃',
    '(', '[', '{', '<',
  ]);
}
