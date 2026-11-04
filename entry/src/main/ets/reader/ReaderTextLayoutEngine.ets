import { text } from '@kit.ArkGraphics2D';

/**
 * 正文排版断行引擎：把断行交给系统原生文本引擎，与上游 legado 的 `StaticLayout` 同一底座。
 *
 * 上游 Android 的正文断行由 `StaticLayout` 完成（系统原生断行 + CJK 禁则 + 两端对齐）。
 * 本地此前是「逐字自量」：对每个字调 `ReaderFontRepository.measureTextWidthForPagination`
 * 取宽度再自己拼行，所以中文避头尾（TXT-READER.md B1）一直没接，行高与两端对齐的终点
 * 也和上游差零点几 px，改一次字号还要整章重测。
 *
 * 本文件把「断行」这一件事交给 `@ohos.graphics.text`：
 * `ParagraphBuilder` 建段 → `layoutSync(width)` → `getLineMetrics(i)` 取每行字符区间，
 * 等价于上游的 `StaticLayout.getLineStart()` / `getLineEnd()`。
 *
 * 段落构建与逐行切页算法参考 wip3l/qingye-reader 的 `core/reader/ReaderV2Paginator`
 * （GPL-3.0，本仓库同为 GPL-3.0），按其条款使用；代码按本地接口重写，未整文件复制。
 *
 * ## 单位口径（本项目返工最多的地方，改之前先把这段读完）
 *
 * - 本文件对外**全部用 vp / fp**：`contentWidthVp` 与 `letterSpacingVp` 是 vp，
 *   `fontSizeFp` 是 fp，`ReaderTextLayoutLine.width` 与各 item 的 `width` 是 vp。
 * - `ParagraphBuilder` / `layoutSync` **只认 px**，所以进 `layoutSync` 之前一律换成 px
 *   （见 `renderStyle()` 与 `breakRanges()`）。
 * - 出函数只带「字符区间 + vp 宽度」，**不带任何 px**。行高、段距、切页仍由
 *   `LocalReaderPaginator` 按 vp 计算，两边口径不许混。
 * - vp / fp 到 px 的换算比例由调用方经 `ReaderTextLayoutStyle.vpScalePx` /
 *   `fpScalePx` 带进来（调用方用 `UIContext.vp2px(1)` / `fp2px(1)` 取），
 *   **本文件不调用已废弃的全局 `vp2px` / `fp2px`，也不要拿 1 当比例或自己乘 2/3**。
 *
 * ## API 基线
 *
 * 本仓库 `build-profile.json5` 是 `compatibleSdkVersion 5.0.0(12)`、
 * `targetSdkVersion 5.0.0(12)`，所以下面这些字段**一个都不能写**，写了 `assembleHap`
 * 直接构建失败：
 * - `ParagraphStyle.lineSpacing`（since 21）
 * - `ParagraphStyle.includeFontPadding`（since 23）
 * - `ParagraphStyle.trailingSpaceOptimized` / `autoSpace` / `verticalAlign`（since 20）
 * - `ParagraphStyle.compressHeadPunctuation` / `fallbackLineSpacing`（since 23）
 *
 * 因为 `lineSpacing` 用不了，行距不能交给 `Paragraph`，必须由调用方算好的
 * `lineHeight`（vp）施加——这也是本引擎只回答「哪些字在哪一行」，不产出绘制用
 * `Paragraph` 的原因：本地绘制走 `ReaderCanvasSurface.getParagraph()` 逐行自绘，
 * 行盒高度取自 `LocalReaderLine.height`。同理 `includeFontPadding` 缺失带来的
 * 首行墨迹裁切风险不落在本文件（绘制侧的段落本来就带一个字号余量）。
 */

/** 正文排版样式，必须与绘制正文时用的那一套保持一致，否则断行与绘制会对不上。 */
export interface ReaderTextLayoutStyle {
  /** 字体族，顺序即回退顺序。 */
  fontFamilies: string[];
  /** 字号，单位 fp（与阅读设置里的字号同单位，绘制侧 `fp2px` 后使用）。 */
  fontSizeFp: number;
  /** 字间距，单位 vp（绘制侧 `vp2px` 后使用）。 */
  letterSpacingVp: number;
  /** 字重（100..900）。 */
  fontWeight: number;
  /** vp → px 的换算比例（调用方 `UIContext.vp2px(1)`）。 */
  vpScalePx: number;
  /** fp → px 的换算比例（调用方 `UIContext.fp2px(1)`）。 */
  fpScalePx: number;
}

/** 参与断行的一个文本片段（一段正文里连续的文本 part，不含图片）。 */
export interface ReaderTextLayoutPart {
  value: string;
  /** 片段首字符在整章正文里的绝对位置，用于回填命中排版与字符坐标。 */
  startPosition: number;
  /** 段首缩进片段：两端对齐时不参与拉伸。 */
  leadingIndent: boolean;
}

/** 断行结果里的一行，按 part 边界切成片段。 */
export interface ReaderTextLayoutItem {
  value: string;
  /** 未拉伸时的文字宽度（vp）。 */
  width: number;
  /** 片段首字符的绝对位置。 */
  startPosition: number;
  /** 片段尾字符的绝对位置（不含）。 */
  endPosition: number;
  leadingIndent: boolean;
}

/** 一行断行结果。 */
export interface ReaderTextLayoutLine {
  items: ReaderTextLayoutItem[];
  /** 本行未拉伸时的文字总宽（vp）。 */
  width: number;
  /** 行首字符的绝对位置。 */
  startPosition: number;
  /** 行尾字符的绝对位置（不含）。 */
  endPosition: number;
}

/** 断行区间：`[start, end)`，下标是字符串里的 UTF-16 码元位置。 */
interface ReaderTextLineRange {
  start: number;
  end: number;
}

/**
 * 把样式换成 `ParagraphBuilder` 认的 px 口径。
 *
 * `heightOnly: true` + `halfLeading: false` 让行高只按字形高度算，不额外加上下留白，
 * 与绘制侧 `ReaderCanvasSurface.getParagraph()` 的口径一致；`locale: 'zh-Hans'` 让
 * CJK 走中文断行惯例（这也是避头尾的来源）。
 */
function renderStyle(style: ReaderTextLayoutStyle): text.TextStyle {
  const textStyle: text.TextStyle = {
    fontFamilies: style.fontFamilies,
    fontSize: style.fontSizeFp * style.fpScalePx,
    letterSpacing: style.letterSpacingVp * style.vpScalePx,
    fontWeight: style.fontWeight,
    heightOnly: true,
    halfLeading: false,
    locale: 'zh-Hans'
  };
  return textStyle;
}

/** 按内容宽度把所有 fragment 切成行。 */
export class ReaderTextLayoutEngine {
  /** 系统引擎不可用时的兜底只记一次日志，避免逐段刷屏。 */
  private static fallbackLogged: boolean = false;
  // 临时调试计数：交付前删除

  private readonly contentWidthVp: number;
  private readonly style: ReaderTextLayoutStyle | undefined;
  private readonly measureWidth: (textValue: string) => number;

  constructor(contentWidthVp: number, style: ReaderTextLayoutStyle | undefined,
    measureWidth: (textValue: string) => number) {
    this.contentWidthVp = contentWidthVp;
    this.style = style;
    this.measureWidth = measureWidth;
  }

  /**
   * 把一组连续文本 part 断成行。
   *
   * `firstLineWidthVp` 是当前行**已经排掉**的内容宽度（只有「行内图片后面接文字」
   * 会是非零）。非零时首行按剩余宽度切一段，剩下的整段再交给系统引擎——
   * 这是本地 inline 图片与文字同行的语义，轻页（把图片当独立块）没有对应，
   * 所以按本地现有语义在他们之上做适配。
   */
  layout(parts: ReaderTextLayoutPart[], firstLineWidthVp: number = 0): ReaderTextLayoutLine[] {
    const lines: ReaderTextLayoutLine[] = [];
    const runText = this.joinParts(parts);
    const offsets = this.partOffsets(parts);
    if (runText.length === 0) {
      return lines;
    }
    let firstLineEnd = 0;
    if (firstLineWidthVp > 0) {
      const available = this.contentWidthVp - firstLineWidthVp;
      if (available > 0) {
        firstLineEnd = this.fitClusters(runText, 0, available);
      }
      if (firstLineEnd > 0) {
        lines.push(this.buildLine(runText, parts, offsets, 0, firstLineEnd));
      }
    }
    const rest = runText.substring(firstLineEnd);
    const ranges = this.breakRanges(rest);
    for (let index = 0; index < ranges.length; index++) {
      const range = ranges[index] as ReaderTextLineRange;
      const start = firstLineEnd + range.start;
      const end = firstLineEnd + range.end;
      if (end <= start) {
        continue;
      }
      lines.push(this.buildLine(runText, parts, offsets, start, end));
    }
    return lines;
  }

  private joinParts(parts: ReaderTextLayoutPart[]): string {
    let value = '';
    for (let index = 0; index < parts.length; index++) {
      const part = parts[index] as ReaderTextLayoutPart;
      value += part.value;
    }
    return value;
  }

  /** 每个 part 在整串文本里的起始偏移。 */
  private partOffsets(parts: ReaderTextLayoutPart[]): number[] {
    const offsets: number[] = [];
    let cursor = 0;
    for (let index = 0; index < parts.length; index++) {
      const part = parts[index] as ReaderTextLayoutPart;
      offsets.push(cursor);
      cursor += part.value.length;
    }
    return offsets;
  }

  /**
   * 交给系统原生文本引擎断行，取每行的字符区间。
   *
   * 这是本引擎的核心：`layoutSync(widthPx)` 之后 `getLineMetrics(i)` 同时给出
   * `startIndex` / `endIndex`，中文避头尾（「，。」不落行首、「“《」不挂行尾）
   * 由系统按 `WordBreak.BREAK_WORD` + `locale: 'zh-Hans'` 的语言惯例处理，
   * 不再需要本地自造的避头尾表。
   */
  private breakRanges(value: string): ReaderTextLineRange[] {
    if (value.length === 0) {
      return [];
    }
    if (this.style === undefined || !(this.contentWidthVp > 0)) {
      return this.fitRanges(value);
    }
    const layoutWidthPx = this.contentWidthVp * this.style.vpScalePx;
    if (!(layoutWidthPx > 0)) {
      return this.fitRanges(value);
    }
    const ranges: ReaderTextLineRange[] = [];
    try {
      const paragraphStyle: text.ParagraphStyle = {
        textStyle: renderStyle(this.style),
        textDirection: text.TextDirection.LTR,
        align: text.TextAlign.START,
        wordBreak: text.WordBreak.BREAK_WORD,
        breakStrategy: text.BreakStrategy.GREEDY
      };
      const builder = new text.ParagraphBuilder(paragraphStyle, text.FontCollection.getGlobalInstance());
      builder.addText(value);
      const paragraph = builder.build();
      paragraph.layoutSync(layoutWidthPx);
      const lineCount = paragraph.getLineCount();
      let cursor = 0;
      for (let index = 0; index < lineCount; index++) {
        const metrics: text.LineMetrics | undefined = paragraph.getLineMetrics(index);
        if (metrics === undefined) {
          break;
        }
        const rawStart = metrics.startIndex;
        const rawEnd = metrics.endIndex;
        const start = rawStart > cursor ? rawStart : cursor;
        const end = rawEnd > start ? rawEnd : Math.min(value.length, start + 1);
        if (start >= value.length) {
          break;
        }
        ranges.push({ start: start, end: end });
        cursor = end;
        if (cursor >= value.length) {
          break;
        }
      }
    } catch (error) {
      if (!ReaderTextLayoutEngine.fallbackLogged) {
        ReaderTextLayoutEngine.fallbackLogged = true;
        console.error(`[ReaderTextLayoutEngine] 系统断行不可用，退回逐 cluster 自量：${error}`);
      }
      return this.fitRanges(value);
    }
    if (ranges.length === 0) {
      return this.fitRanges(value);
    }
    this.reclaimTrailingSpaces(value, ranges);
    const last = ranges[ranges.length - 1] as ReaderTextLineRange;
    if (last.end < value.length) {
      last.end = value.length;
    }
    return ranges;
  }

  /**
   * 行尾空格不占宽度的补偿（等价 API 20 的 `ParagraphStyle.trailingSpaceOptimized`）。
   *
   * 本地 targetSdk 是 12，没有这个开关，系统断行会把行尾那一个空格算进行宽，
   * 于是西文比上游 `StaticLayout` 少排一个词：实测同一本英文书同一章、同一字号，
   * 关闭补偿时 18 页、上游口径 17 页（+5.9%）。中文行尾没有空格，此函数不动中文。
   *
   * 做法只回收「空格 + 紧随其后的一个完整词」，且该词必须整词落在下一行内，
   * 不用重新猜测断点：判定依据仍是本行的实测宽度不超过可用宽。
   */
  private reclaimTrailingSpaces(value: string, ranges: ReaderTextLineRange[]): void {
    for (let index = 0; index + 1 < ranges.length; index++) {
      const current = ranges[index] as ReaderTextLineRange;
      const next = ranges[index + 1] as ReaderTextLineRange;
      let cursor = current.end;
      while (true) {
        // 行尾必须是空格才谈得上「不占宽度」；中文没有空格，直接退出。
        let scan = cursor;
        while (scan < value.length && value.charCodeAt(scan) === 0x20) {
          scan++;
        }
        if (scan === cursor) {
          break;
        }
        let wordEnd = scan;
        while (wordEnd < value.length && value.charCodeAt(wordEnd) !== 0x20 &&
          value.charCodeAt(wordEnd) !== 0x09) {
          wordEnd++;
        }
        // 整词必须落在下一行内，否则会把下一行整行吃掉。
        if (wordEnd <= scan || wordEnd > next.end) {
          break;
        }
        if (this.measureWidth(value.substring(current.start, wordEnd)) > this.contentWidthVp) {
          break;
        }
        // 抽词是把下一行的首词挪上来，下一行因此变短。若变短后明显不满一行，
        // 两端对齐会把这一行的词距拉开（实测中英混排出现「b r e a k i n g .」与
        // 「本　章　英　文」被撑满，以及「t h e  p a r a g r a p h」被拉开），
        // 放弃这次回收。阈值取四分之三：只有下一行仍接近排满时才值得抽词。
        let restStart = wordEnd;
        while (restStart < next.end && this.isBlankCode(value.charCodeAt(restStart))) {
          restStart++;
        }
        if (this.measureWidth(value.substring(restStart, next.end)) < this.contentWidthVp * 0.75) {
          break;
        }
        cursor = wordEnd;
        current.end = wordEnd;
        next.start = wordEnd;
      }
    }
  }

  /** 逐 cluster 自量折行：只在没有字体样式或系统引擎不可用时兜底，不做禁则。 */
  private fitRanges(value: string): ReaderTextLineRange[] {
    const ranges: ReaderTextLineRange[] = [];
    let cursor = 0;
    while (cursor < value.length) {
      const end = this.fitClusters(value, cursor, this.contentWidthVp);
      if (end <= cursor) {
        break;
      }
      ranges.push({ start: cursor, end: end });
      cursor = end;
    }
    if (ranges.length === 0) {
      ranges.push({ start: 0, end: value.length });
    }
    return ranges;
  }

  /**
   * 从 `begin` 起按可用宽度（vp）切出最长的一行，返回行尾下标。
   *
   * 只用在两处：没有字体样式时的兜底，以及「行内图片已占掉一部分宽度」的首行。
   * 这里是逐 cluster 各自测量、不加 kerning，所以只做兜底，正常断行一律走系统引擎。
   */
  private fitClusters(value: string, begin: number, availableVp: number): number {
    let cursor = begin;
    let width = 0;
    let end = begin;
    while (cursor < value.length) {
      const codePoint = value.codePointAt(cursor);
      const step = codePoint !== undefined && codePoint > 0xFFFF ? 2 : 1;
      const clusterWidth = this.measureWidth(value.substring(cursor, cursor + step));
      if (end > begin && width + clusterWidth > availableVp) {
        break;
      }
      width += clusterWidth;
      cursor += step;
      end = cursor;
    }
    if (end === begin && value.length > begin) {
      // 单个 cluster 就超宽：至少放一个，否则外层的循环永远不前进。
      const codePoint = value.codePointAt(begin);
      end = begin + (codePoint !== undefined && codePoint > 0xFFFF ? 2 : 1);
    }
    return end;
  }

  /**
   * 把一段字符区间变成一行（按 part 边界切片）。
   *
   * 行首与行尾的空白都不进 item：上游 `StaticLayout` 断行后行尾空白不参与排版，
   * 行首空白在断行时已被丢掉。宽度用 `measureWidth` 逐片段重新量，保持与绘制侧
   * （字形宽 + 每字字间距）同一口径，这样 `contentWidth` / `justifyGap` 的终点才
   * 与两端对齐的绘制结果一致。
   */
  private buildLine(runText: string, parts: ReaderTextLayoutPart[], offsets: number[],
    lineStart: number, lineEnd: number): ReaderTextLayoutLine {
    // 段首缩进是语义空白（`LocalTextSemantics` 插的两个全角空格），不是折断留下的
    // 行尾空白，必须保留成一个 `leadingIndent` item：否则首行白丢两个字的容量，
    // 两端对齐还会按「不含缩进」的字数分摊空隙，把首行字距拉到极宽。
    const keepIndent = lineStart === 0 && parts.length > 0 &&
      (parts[0] as ReaderTextLayoutPart).leadingIndent;
    let trimmedStart = lineStart;
    let trimmedEnd = lineEnd;
    if (!keepIndent) {
      while (trimmedStart < trimmedEnd && this.isBlankCode(runText.charCodeAt(trimmedStart))) {
        trimmedStart++;
      }
    }
    while (trimmedEnd > trimmedStart && this.isBlankCode(runText.charCodeAt(trimmedEnd - 1))) {
      trimmedEnd--;
    }
    if (trimmedEnd <= trimmedStart) {
      // 整行都是空白（空行）：保留原区间，否则这一行会凭空消失、字符坐标断链。
      trimmedStart = lineStart;
      trimmedEnd = lineEnd;
    }
    const items: ReaderTextLayoutItem[] = [];
    let width = 0;
    for (let partIndex = 0; partIndex < parts.length; partIndex++) {
      const part = parts[partIndex] as ReaderTextLayoutPart;
      const partOffset = offsets[partIndex] as number;
      const sliceStart = Math.max(trimmedStart, partOffset);
      const sliceEnd = Math.min(trimmedEnd, partOffset + part.value.length);
      if (sliceEnd <= sliceStart) {
        continue;
      }
      const sliceValue = runText.substring(sliceStart, sliceEnd);
      const sliceWidth = this.measureWidth(sliceValue);
      items.push({
        value: sliceValue,
        width: sliceWidth,
        startPosition: part.startPosition + (sliceStart - partOffset),
        endPosition: part.startPosition + (sliceEnd - partOffset),
        leadingIndent: part.leadingIndent
      });
      width += sliceWidth;
    }
    const first = items.length > 0 ? items[0] as ReaderTextLayoutItem : undefined;
    const last = items.length > 0 ? items[items.length - 1] as ReaderTextLayoutItem : undefined;
    return {
      items: items,
      width: width,
      startPosition: first !== undefined ? first.startPosition : trimmedStart,
      endPosition: last !== undefined ? last.endPosition : trimmedEnd
    };
  }

  /** 半角空格 / 制表符 / 全角空格：断行后不占宽度。 */
  private isBlankCode(code: number): boolean {
    return code === 0x20 || code === 0x09 || code === 0x3000;
  }
}
