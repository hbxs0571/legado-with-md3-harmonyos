import { LocalSemanticDocument, LocalSemanticParagraph, LocalSemanticPart } from '../data/LocalTextSemantics';
import {
  ReaderTextLayoutEngine,
  ReaderTextLayoutLine,
  ReaderTextLayoutPart,
  ReaderTextLayoutStyle
} from '../reader/ReaderTextLayoutEngine';

export interface LocalReaderLineItem {
  kind: 'text' | 'image';
  value: string;
  width: number;
  height: number;
  startPosition: number;
  endPosition: number;
  leadingIndent: boolean;
  /**
   * 章标题字号的相对倍数（0 或未设置表示正文元素）。
   *
   * 上游标题是排版流里的普通文本块，只是带 `isTitle` 标记、字号按段缩放
   * （`ReaderChapterSource.kt:8-14`、`ReaderChapterBlockMeasurer.kt:260-270`）。
   * 绘制层据此换用标题样式，而不是另起一套画布外组件。
   */
  titleFontScale?: number;
}

export interface LocalReaderLine {
  items: LocalReaderLineItem[];
  height: number;
  paragraphSpacingAfter: number;
  imageOnly: boolean;
  verticalSpaceBefore: number;
  startPosition: number;
  endPosition: number;
  justifyGap: number;
  /** 该行未拉伸时的文字实际宽度，供自绘下划线决定线段右端。 */
  contentWidth: number;
  /** 1 = 本行水平居中（标题段），0 或未设置 = 按正文对齐。 */
  titleAlign?: number;
  /** 本行是章标题行：不参与两端对齐，也不落正文命中样式。 */
  titleLine?: boolean;
}

/** 一段章标题（按 `titleSegType` 切段后的结果）。 */
export interface LocalReaderTitleSegment {
  text: string;
  /** 相对标题基准字号的倍数（副标题段由 `titleSegScaling` 缩放）。 */
  fontSizeScale: number;
  /**
   * 该段的行高（vp）。
   *
   * 上游首段与副标题段用不同的行距倍率（`titleLineSpacingExtra` / `titleLineSpacingSub`，
   * 见 `LegacyReaderPaginationStyleFactory.kt:98-101`），所以行高按段算好带进来，
   * 分页器不自己推。
   */
  lineHeightVp: number;
  /** 该段之后的分段间距（vp）。 */
  spacingAfter: number;
}

/**
 * 章标题块：上游把标题当普通文本块排进块流，与正文共用同一个 `y` 游标与
 * 同一条「`y + 行高 > contentBottom` 就换页」判定（`ReaderPaginator.kt:1112-1116`）。
 * 这里同样按块交给分页器，标题因此会跟着正文一起翻页、一起滚动。
 */
export interface LocalReaderTitleBlock {
  segments: LocalReaderTitleSegment[];
  /** 标题块上间距（vp，上游 `titleTopSpacingPx`）。 */
  topSpacing: number;
  /** 标题排完、后面接正文时的下间距（vp，上游 `titleBottomSpacingPx`）。 */
  bottomSpacing: number;
  /** 标题是否水平居中（上游 `titleAlignment`）。 */
  centered: boolean;
  /** 标题排完后强制断页（上游 `titlePageBreakAfter`）。 */
  pageBreakAfter: boolean;
  /** 首页只有标题时整页垂直居中（上游 `titlePageCenterVertical`）。 */
  centerVertical: boolean;
  /** 按段内相对字号倍率测量文字宽度（vp）。 */
  measureWidth: (text: string, fontSizeScale: number) => number;
}

export interface LocalReaderPage {
  lines: LocalReaderLine[];
  startPosition: number;
  endPosition: number;
  titleOnly: boolean;
  /**
   * 每行落在第几列（双页模式用），长度与 `lines` 相同。
   * 对齐上游 `ReaderPaginator.advanceColumn()`：先填满第 0 列再填第 1 列，
   * 两列都满才 `finishPage()`，即「一个 page 装两列」。单页模式下全为 0。
   */
  lineColumns: number[];
  /**
   * 整屏居中的提示文案（「加载数据中…」/「继续滑动以加载下一章…」）。
   * 有值即占位页：不排正文，`lines` 为空，绘制时整屏居中画这一行字。
   * 对齐上游 `ReadBookController.centeredReaderMessagePage`（`ReadBookController.kt:3051-3100`）。
   */
  messageText?: string;
  /**
   * 整页内容垂直居中。
   *
   * 上游 `titlePageCenterVertical`：页成型后回改第一页，把整页元素按 `delta` 平移
   * （`ReaderPaginator.kt:50-51`、`:369-389`）。判据是「页内全是 `emphasized` 的 Text」，
   * 即本页只有标题。
   */
  centerVertical?: boolean;
}

export interface LocalReaderImageSize {
  width: number;
  height: number;
}

/**
 * 命中排版对排版的唯一影响（上游 `ReaderChapterBlockMeasurer.kt:376-392`）：
 * 只有字号偏移会改行高，行上/下距是行级留白；颜色、下划线、字重、斜体都只影响绘制。
 * 数值与 `lineHeight` 同单位（vp）。
 */
export interface LocalReaderSizeOffset {
  start: number;
  endExclusive: number;
  extraHeight: number;
  padTop: number;
  padBottom: number;
}

/** 一行命中排版折算出的行高与上下留白（内部用）。 */
interface LocalReaderLineMetrics {
  height: number;
  padTop: number;
  padBottom: number;
}

/**
 * 按设备字体度量分页，保留 Android 字符坐标，并对齐默认正文的非末行字距。
 *
 * 断行交给系统原生文本引擎（`reader/ReaderTextLayoutEngine.ets` → `@ohos.graphics.text`），
 * 与上游 Android 的 `StaticLayout` 同一底座：中文避头尾、中西文混排断点、字距都按系统
 * 语言惯例处理。本类只负责「行落在哪一列、行高多少、切到哪一页」。
 */
export class LocalReaderPaginator {

  /** 把一行文本切成 codePoint 序列，供章标题折行（代理对算一个 cluster）。 */
  private static toClusters(text: string): string[] {
    const clusters: string[] = [];
    let cursor = 0;
    while (cursor < text.length) {
      const codePoint = text.codePointAt(cursor);
      const step = codePoint !== undefined && codePoint > 0xFFFF ? 2 : 1;
      clusters.push(text.substring(cursor, cursor + step));
      cursor += step;
    }
    return clusters;
  }

  /**
   * 按行区间扫一遍命中排版，求该行需要抬到多高、上下各留多少白。
   *
   * 旧实现逐字推进游标；改成按行算之后，判据变成「行区间与命中区间是否相交」，
   * 一行里只要有一个字落在命中区，整行就按该区的字号偏移抬高——与逐字取 `max` 等价。
   */
  private static metricsForRange(startPosition: number, endPosition: number, lineHeight: number,
    sizeOffsets: LocalReaderSizeOffset[]): LocalReaderLineMetrics {
    let height = lineHeight;
    let padTop = 0;
    let padBottom = 0;
    for (let index = 0; index < sizeOffsets.length; index++) {
      const span = sizeOffsets[index];
      if (span === undefined) { continue; }
      if (span.endExclusive <= startPosition || span.start >= endPosition) { continue; }
      height = Math.max(height, Math.max(1, lineHeight + span.extraHeight));
      padTop = Math.max(padTop, span.padTop);
      padBottom = Math.max(padBottom, span.padBottom);
    }
    return { height: height, padTop: padTop, padBottom: padBottom };
  }

  static paginate(
    document: LocalSemanticDocument,
    contentWidth: number,
    contentHeight: number,
    lineHeight: number,
    paragraphSpacing: number,
    measureTextWidth: (text: string) => number,
    imageSizes: Map<string, LocalReaderImageSize>,
    imageStyle: string,
    standaloneImageThreshold: number,
    inlineImageWidth: number,
    firstPageReservedLines: number,
    fullJustify: boolean = true,
    columnCount: number = 1,
    sizeOffsets: LocalReaderSizeOffset[] = [],
    titleBlock: LocalReaderTitleBlock | undefined = undefined,
    textStyle: ReaderTextLayoutStyle | undefined = undefined
  ): LocalReaderPage[] {
    const columns = columnCount >= 2 ? 2 : 1;
    if (contentWidth <= 0 || contentHeight <= 0 || lineHeight <= 0) {
      return [{ lines: [], startPosition: 0, endPosition: document.content.length, titleOnly: false, lineColumns: [] }];
    }
    // 断行交给系统引擎；没有字体样式时引擎退回逐 cluster 自量（老口径）。
    const engine = new ReaderTextLayoutEngine(contentWidth, textStyle, measureTextWidth);
    const pages: LocalReaderPage[] = [];
    let pageLines: LocalReaderLine[] = [];
    let pageColumns: number[] = [];
    let pageStart = 0;
    let pageEnd = 0;
    let pageUsedHeight = 0;
    // 当前正在填的列号；上游 ReaderPaginator 用 columnIndex。
    let columnIndex = 0;
    let lineItems: LocalReaderLineItem[] = [];
    let lineWidth = 0;
    let currentLineHeight = lineHeight;
    // 命中排版的字号偏移与行上下距：只有落在命中区里的字才抬高本行、加留白。
    let currentLinePadTop = 0;
    let currentLinePadBottom = 0;

    const currentPageCapacity = (): number => Math.max(lineHeight,
      contentHeight - (pages.length === 0 ? Math.max(0, firstPageReservedLines) * lineHeight : 0));
    const flushPage = (): void => {
      if (pageLines.length === 0) { return; }
      // 标题页判定：本页所有行都是标题行（titleLine===true）。
      // 与上游 ReaderPaginator 把标题当普通文本块排进同一 y 游标、靠 titleLine 标记区分一致；
      // 之前这里硬编码 false，导致下游 9 处 titleOnly 分支全成死代码（见 layer2-decision §2A）。
      const pageIsTitleOnly = pageLines.length > 0 &&
        pageLines.every((line: LocalReaderLine) => line.titleLine === true);
      pages.push({
        lines: pageLines, startPosition: pageStart, endPosition: pageEnd,
        titleOnly: pageIsTitleOnly, lineColumns: pageColumns
      });
      pageLines = [];
      pageColumns = [];
      pageUsedHeight = 0;
      columnIndex = 0;
    };
    /** 当前列已满：还有下一列就换列（清空已用高度），否则出页。对齐 advanceColumn()。 */
    const advanceColumn = (): void => {
      if (columnIndex + 1 < columns) {
        columnIndex++;
        pageUsedHeight = 0;
        return;
      }
      flushPage();
    };
    const appendLine = (
      endPosition?: number,
      justify: boolean = false,
      spacingAfter: number = 0,
      verticalSpaceBefore: number = 0,
      pageBreakBefore: boolean = false,
      pageBreakAfter: boolean = false,
      titleLine: boolean = false,
      titleAlign: number = 0
    ): void => {
      if (lineItems.length === 0) { return; }
      const lineStart = lineItems[0]?.startPosition ?? 0;
      const lastItem = lineItems[lineItems.length - 1];
      const lineEnd = Math.max(endPosition ?? 0, lastItem?.endPosition ?? lineStart);
      let itemCount = 0;
      let leadingIndentCount = 0;
      let naturalWidth = 0;
      for (let itemIndex = 0; itemIndex < lineItems.length; itemIndex++) {
        const item = lineItems[itemIndex];
        if (item === undefined) { continue; }
        naturalWidth += item.width;
        if (item.kind === 'image') {
          itemCount++;
        } else {
          let textCursor = 0;
          let clusterCount = 0;
          while (textCursor < item.value.length) {
            const codePoint = item.value.codePointAt(textCursor);
            textCursor += codePoint !== undefined && codePoint > 0xFFFF ? 2 : 1;
            clusterCount++;
          }
          itemCount += clusterCount;
          if (item.leadingIndent) { leadingIndentCount += clusterCount; }
        }
      }
      // 对齐 Android 正文两端对齐：首行缩进间距不拉伸，段末行不走这条分支。
      // 标题行同样不拉伸——上游标题块 `bodyAlignment` 只作用在正文，标题按自己的对齐排。
      const stretchableGaps = Math.max(0, itemCount - 1 - Math.max(0, leadingIndentCount));
      const justifyGap = justify && fullJustify && !titleLine && stretchableGaps > 0
        ? Math.max(0, (contentWidth - naturalWidth) / stretchableGaps) : 0;
      if (pageBreakBefore && pageLines.length > 0) { flushPage(); }
      if (pageLines.length > 0 &&
        pageUsedHeight + verticalSpaceBefore + currentLinePadTop + currentLineHeight +
          currentLinePadBottom > currentPageCapacity()) {
        advanceColumn();
      }
      if (pageLines.length === 0) { pageStart = lineStart; }
      const line: LocalReaderLine = {
        items: lineItems,
        height: currentLineHeight,
        paragraphSpacingAfter: spacingAfter + currentLinePadBottom,
        imageOnly: lineItems.length === 1 && lineItems[0]?.kind === 'image',
        verticalSpaceBefore: verticalSpaceBefore + currentLinePadTop,
        startPosition: lineStart,
        endPosition: lineEnd,
        justifyGap: justifyGap,
        contentWidth: naturalWidth,
        titleAlign: titleAlign,
        titleLine: titleLine
      };
      pageLines.push(line);
      pageColumns.push(columnIndex);
      pageUsedHeight += verticalSpaceBefore + currentLinePadTop + currentLineHeight +
        currentLinePadBottom + spacingAfter;
      pageEnd = lineEnd;
      lineItems = [];
      lineWidth = 0;
      currentLineHeight = lineHeight;
      currentLinePadTop = 0;
      currentLinePadBottom = 0;
      if (pageBreakAfter) { flushPage(); }
    };
    /**
     * 把系统引擎给出的一行落进当前行缓冲。
     *
     * `keepOpen` 为真时不落地，只把片段推进 `lineItems`——行内图片要接着排在同一行，
     * 必须先留着这一行的空位（上游 `TEXT` 图片样式与文字同排）。
     */
    const applyTextLine = (layoutLine: ReaderTextLayoutLine, lineEndPosition: number,
      justify: boolean, spacingAfter: number, keepOpen: boolean): void => {
      if (layoutLine.items.length === 0) { return; }
      const metrics = LocalReaderPaginator.metricsForRange(layoutLine.startPosition,
        layoutLine.endPosition, lineHeight, sizeOffsets);
      for (let itemIndex = 0; itemIndex < layoutLine.items.length; itemIndex++) {
        const layoutItem = layoutLine.items[itemIndex];
        if (layoutItem === undefined) { continue; }
        lineItems.push({
          kind: 'text', value: layoutItem.value, width: layoutItem.width, height: lineHeight,
          startPosition: layoutItem.startPosition, endPosition: layoutItem.endPosition,
          leadingIndent: layoutItem.leadingIndent
        });
      }
      lineWidth += layoutLine.width;
      currentLineHeight = Math.max(currentLineHeight, metrics.height);
      currentLinePadTop = Math.max(currentLinePadTop, metrics.padTop);
      currentLinePadBottom = Math.max(currentLinePadBottom, metrics.padBottom);
      if (keepOpen) { return; }
      appendLine(lineEndPosition, justify, spacingAfter);
    };
    const addParagraph = (paragraph: LocalSemanticParagraph): void => {
      // 连续文本 part 先攒成一段再交给系统引擎断行：断点要跨 part 连续，
      // 逐 part 单独断行会在 part 边界人为制造换行（行内图片、富文本块都会切 part）。
      let runParts: ReaderTextLayoutPart[] = [];
      const flushRun = (finalEndPosition: number, keepLastLine: boolean, lastJustify: boolean,
        lastSpacing: number): void => {
        if (runParts.length === 0) { return; }
        const pendingParts: ReaderTextLayoutPart[] = runParts;
        runParts = [];
        // 行内图片已经占满整行时先换行，否则这一段文字会挤在同一行里。
        if (lineItems.length > 0 && lineWidth >= contentWidth) { appendLine(undefined, true); }
        // 首行剩余宽度 = 内容宽 - 当前行已排掉的宽度（只有行内图片会是非零）。
        const firstLineWidth = lineItems.length > 0 ? lineWidth : 0;
        const layoutLines = engine.layout(pendingParts, firstLineWidth);
        for (let index = 0; index < layoutLines.length; index++) {
          const layoutLine = layoutLines[index];
          if (layoutLine === undefined) { continue; }
          const isLastLine = index === layoutLines.length - 1;
          const lineEnd = isLastLine
            ? Math.max(finalEndPosition, layoutLine.endPosition) : layoutLine.endPosition;
          applyTextLine(layoutLine, lineEnd, isLastLine ? lastJustify : true,
            isLastLine ? lastSpacing : 0, isLastLine && keepLastLine);
        }
      };
      for (let partIndex = 0; partIndex < paragraph.parts.length; partIndex++) {
        const part = paragraph.parts[partIndex];
        if (part === undefined) { continue; }
        if (part.kind === 'text') {
          runParts.push({
            value: part.value, startPosition: part.startPosition, leadingIndent: part.leadingIndent
          });
          continue;
        }
        const intrinsic = imageSizes.get(part.value);
        const sourceWidth = intrinsic?.width ?? 0;
        const sourceHeight = intrinsic?.height ?? 0;
        // 尺寸还没到（应当极少见）：当成不存在，后面这段文字继续接着排。
        if (sourceWidth <= 0 || sourceHeight <= 0) { continue; }
        const normalizedImageStyle = imageStyle.toUpperCase();
        const inlineStyle = normalizedImageStyle === 'TEXT' ||
          (normalizedImageStyle === 'DEFAULT' &&
            sourceWidth < standaloneImageThreshold && sourceHeight < standaloneImageThreshold);
        if (inlineStyle) {
          // 行内图片与文字同排：把文字流的末行留着不落地，图片接在同一行后面。
          flushRun(part.startPosition, true, false, 0);
          const width = Math.max(1, inlineImageWidth);
          const height = width * sourceHeight / sourceWidth;
          if (lineItems.length > 0 && lineWidth + width > contentWidth) { appendLine(undefined, true); }
          currentLineHeight = Math.max(currentLineHeight, height);
          lineItems.push({
            kind: 'image', value: part.value, width: width, height: height,
            startPosition: part.startPosition, endPosition: part.endPosition,
            leadingIndent: false
          });
          lineWidth += width;
          continue;
        }

        const singlePage = normalizedImageStyle === 'SINGLE';
        const fullWidth = normalizedImageStyle === 'FULL';
        // 块级图片独占整行：先把前面的文字收掉，末行按上游口径继续参与拉伸。
        flushRun(part.startPosition, false, true, paragraphSpacing);
        if (singlePage && pageLines.length > 0) { flushPage(); }
        let availablePageHeight = currentPageCapacity();
        let scale = singlePage || fullWidth
          ? Math.min(contentWidth / sourceWidth, availablePageHeight / sourceHeight)
          : Math.min(1, contentWidth / sourceWidth, availablePageHeight / sourceHeight);
        let width = sourceWidth * scale;
        let height = sourceHeight * scale;
        if (pageLines.length > 0 && pageUsedHeight + height > currentPageCapacity()) {
          flushPage();
          availablePageHeight = currentPageCapacity();
          scale = singlePage || fullWidth
            ? Math.min(contentWidth / sourceWidth, availablePageHeight / sourceHeight)
            : Math.min(1, contentWidth / sourceWidth, availablePageHeight / sourceHeight);
          width = sourceWidth * scale;
          height = sourceHeight * scale;
        }
        const verticalSpaceBefore = singlePage ? Math.max(0, (availablePageHeight - height) / 2) : 0;
        currentLineHeight = height;
        lineItems.push({
          kind: 'image', value: part.value, width: width, height: height,
          startPosition: part.startPosition, endPosition: part.endPosition,
          leadingIndent: false
        });
        lineWidth = width;
        appendLine(part.endPosition, false, paragraphSpacing, verticalSpaceBefore, singlePage, singlePage);
      }
      flushRun(paragraph.endPosition, false, false, paragraphSpacing);
    };

    /**
     * 章标题块：按段排成标题行，走与正文完全相同的 `appendLine` / `advanceColumn` 通道，
     * 因此标题会跟着正文一起翻页、一起滚动，不会被挤到画布外面去。
     *
     * 间距口径对齐上游 `ReaderPaginator.processBlock`（`:411`、`:425-430`）：
     * 首段之前加 `titleTopSpacingPx`，每段之后加「下一段还是标题 → 分段间距，否则 → 章标题下间距」。
     *
     * 标题不走系统断行引擎：各段字号按 `fontSizeScale` 缩放、字体族与正文不同
     * （`readerTitleFontFamily`），而 `textStyle` 只描述正文一套。断行仍按 cluster 折，
     * 与旧实现一致。
     */
    const addTitleBlock = (block: LocalReaderTitleBlock): void => {
      for (let segmentIndex = 0; segmentIndex < block.segments.length; segmentIndex++) {
        const segment = block.segments[segmentIndex];
        if (segment === undefined || segment.text.length === 0) { continue; }
        const isLastSegment = segmentIndex === block.segments.length - 1;
        const segmentLineHeight = Math.max(1, segment.lineHeightVp);
        const spacingAfter = isLastSegment
          ? Math.max(0, block.bottomSpacing)
          : Math.max(0, segment.spacingAfter);
        const clusters = LocalReaderPaginator.toClusters(segment.text);
        let lineClusters: string[] = [];
        let titleLineWidth = 0;
        let emittedLine = 0;
        const flushTitleLine = (spacing: number): void => {
          if (lineClusters.length === 0) { return; }
          lineItems = [{
            kind: 'text', value: lineClusters.join(''),
            width: titleLineWidth, height: segmentLineHeight,
            startPosition: 0, endPosition: 0, leadingIndent: false,
            titleFontScale: segment.fontSizeScale
          }];
          currentLineHeight = segmentLineHeight;
          // 标题上间距只加在整个标题块的第一行上（上游 `if (isTitle && index == 0) y += titleTopSpacingPx`）。
          const verticalSpaceBefore = emittedLine === 0 ? Math.max(0, block.topSpacing) : 0;
          appendLine(undefined, false, spacing, verticalSpaceBefore, false, false, true,
            block.centered ? 1 : 0);
          emittedLine++;
          lineClusters = [];
          titleLineWidth = 0;
        };
        for (let clusterIndex = 0; clusterIndex < clusters.length; clusterIndex++) {
          const cluster = clusters[clusterIndex] as string;
          const clusterWidth = block.measureWidth(cluster, segment.fontSizeScale);
          if (lineClusters.length > 0 && titleLineWidth + clusterWidth > contentWidth) {
            flushTitleLine(0);
          }
          lineClusters.push(cluster);
          titleLineWidth += clusterWidth;
        }
        flushTitleLine(spacingAfter);
      }
      // 上游 titlePageBreakAfter：标题段排版结束后立即断页，让章标题独占一页。
      if (block.pageBreakAfter && pageLines.length > 0) { flushPage(); }
    };

    // 标题块恒在块流最前（上游 `ReaderChapterSource.kt:109-111`：titles + body）。
    if (titleBlock !== undefined && titleBlock.segments.length > 0) {
      addTitleBlock(titleBlock);
    }

    for (let index = 0; index < document.paragraphs.length; index++) {
      const paragraph = document.paragraphs[index];
      if (paragraph === undefined) { continue; }
      if (paragraph.pageBreak) {
        // `[newpage]`：本段之后强制换页（上游 ReaderChapterSourceBlock.PageBreak）。
        if (pageLines.length > 0) { flushPage(); }
        continue;
      }
      addParagraph(paragraph);
    }
    flushPage();
    if (pages.length === 0) {
      return [{ lines: [], startPosition: 0, endPosition: document.content.length, titleOnly: false, lineColumns: [] }];
    }
    // 上游 titlePageCenterVertical：第一页只有标题时整页垂直居中
    // （`ReaderPaginator.kt:369-389` 按「页内全是 emphasized 的 Text」判定）。
    if (titleBlock !== undefined && titleBlock.centerVertical) {
      const first = pages[0];
      if (first !== undefined && first.lines.length > 0 &&
        first.lines.every((line: LocalReaderLine) => line.titleLine === true)) {
        first.centerVertical = true;
      }
    }
    return pages;
  }

  /**
   * 按同一排版规则计页；不构造整书页面对象，定期让出 UI 线程。
   *
   * 断行同样走 `ReaderTextLayoutEngine`，保证全书画布页数与当页排版用的是同一套断点。
   */
  static async countPagesIncrementally(
    document: LocalSemanticDocument,
    contentWidth: number,
    contentHeight: number,
    lineHeight: number,
    paragraphSpacing: number,
    measureTextWidth: (text: string) => number,
    imageSizes: Map<string, LocalReaderImageSize>,
    imageStyle: string,
    standaloneImageThreshold: number,
    inlineImageWidth: number,
    firstPageReservedLines: number,
    columnCount: number = 1,
    sizeOffsets: LocalReaderSizeOffset[] = [],
    titleBlock: LocalReaderTitleBlock | undefined = undefined,
    textStyle: ReaderTextLayoutStyle | undefined = undefined
  ): Promise<number> {
    const columns = columnCount >= 2 ? 2 : 1;
    if (contentWidth <= 0 || contentHeight <= 0 || lineHeight <= 0) { return 1; }
    const engine = new ReaderTextLayoutEngine(contentWidth, textStyle, measureTextWidth);
    let pageCount = 0;
    let pageLineCount = 0;
    let pageUsedHeight = 0;
    // 与 paginate 同一套换列规则，否则全书画布与当页排版对不上。
    let columnIndex = 0;
    let lineItems: LocalReaderLineItem[] = [];
    let lineWidth = 0;
    let currentLineHeight = lineHeight;
    // 命中排版的字号偏移与行上下距：只有落在命中区里的字才抬高本行、加留白。
    let currentLinePadTop = 0;
    let currentLinePadBottom = 0;
    // 每排 8 行让一次 UI 线程，替代原先「每 256 个字让一次」的节流。
    let emittedLineCount = 0;

    const currentPageCapacity = (): number => Math.max(lineHeight,
      contentHeight - (pageCount === 0 ? Math.max(0, firstPageReservedLines) * lineHeight : 0));
    const flushPage = (): void => {
      if (pageLineCount === 0) { return; }
      pageCount++;
      pageLineCount = 0;
      pageUsedHeight = 0;
      columnIndex = 0;
    };
    const advanceColumn = (): void => {
      if (columnIndex + 1 < columns) {
        columnIndex++;
        pageUsedHeight = 0;
        return;
      }
      flushPage();
    };
    const appendLine = (
      spacingAfter: number = 0,
      verticalSpaceBefore: number = 0,
      pageBreakBefore: boolean = false,
      pageBreakAfter: boolean = false
    ): void => {
      if (lineItems.length === 0) { return; }
      if (pageBreakBefore && pageLineCount > 0) { flushPage(); }
      if (pageLineCount > 0 &&
        pageUsedHeight + verticalSpaceBefore + currentLinePadTop + currentLineHeight +
          currentLinePadBottom > currentPageCapacity()) {
        advanceColumn();
      }
      pageLineCount++;
      pageUsedHeight += verticalSpaceBefore + currentLinePadTop + currentLineHeight +
        currentLinePadBottom + spacingAfter;
      lineItems = [];
      lineWidth = 0;
      currentLineHeight = lineHeight;
      currentLinePadTop = 0;
      currentLinePadBottom = 0;
      if (pageBreakAfter) { flushPage(); }
    };
    const addTitleBlock = (block: LocalReaderTitleBlock): void => {
      for (let segmentIndex = 0; segmentIndex < block.segments.length; segmentIndex++) {
        const segment = block.segments[segmentIndex];
        if (segment === undefined || segment.text.length === 0) { continue; }
        const isLastSegment = segmentIndex === block.segments.length - 1;
        const segmentLineHeight = Math.max(1, segment.lineHeightVp);
        const spacingAfter = isLastSegment
          ? Math.max(0, block.bottomSpacing)
          : Math.max(0, segment.spacingAfter);
        const clusters = LocalReaderPaginator.toClusters(segment.text);
        let lineClusters = 0;
        let titleLineWidth = 0;
        let emittedLine = 0;
        const flushTitleLine = (spacing: number): void => {
          if (lineClusters === 0) { return; }
          lineItems = [{
            kind: 'text', value: ' ', width: titleLineWidth, height: segmentLineHeight,
            startPosition: 0, endPosition: 0, leadingIndent: false,
            titleFontScale: segment.fontSizeScale
          }];
          currentLineHeight = segmentLineHeight;
          const verticalSpaceBefore = emittedLine === 0 ? Math.max(0, block.topSpacing) : 0;
          appendLine(spacing, verticalSpaceBefore);
          emittedLine++;
          lineClusters = 0;
          titleLineWidth = 0;
        };
        for (let clusterIndex = 0; clusterIndex < clusters.length; clusterIndex++) {
          const cluster = clusters[clusterIndex] as string;
          const clusterWidth = block.measureWidth(cluster, segment.fontSizeScale);
          if (lineClusters > 0 && titleLineWidth + clusterWidth > contentWidth) {
            flushTitleLine(0);
          }
          lineClusters++;
          titleLineWidth += clusterWidth;
        }
        flushTitleLine(spacingAfter);
      }
      if (block.pageBreakAfter && pageLineCount > 0) { flushPage(); }
    };

    // 标题块恒在块流最前（上游 `ReaderChapterSource.kt:109-111`：titles + body）。
    if (titleBlock !== undefined && titleBlock.segments.length > 0) {
      addTitleBlock(titleBlock);
    }

    const yieldToUi = async (): Promise<void> => {
      await new Promise<void>((resolve: () => void) => setTimeout(resolve, 0));
    };
    const addParagraph = async (paragraph: LocalSemanticParagraph): Promise<void> => {
      let runParts: ReaderTextLayoutPart[] = [];
      const flushRun = async (keepLastLine: boolean, lastSpacing: number): Promise<void> => {
        if (runParts.length === 0) { return; }
        const pendingParts: ReaderTextLayoutPart[] = runParts;
        runParts = [];
        if (lineItems.length > 0 && lineWidth >= contentWidth) { appendLine(); }
        const firstLineWidth = lineItems.length > 0 ? lineWidth : 0;
        const layoutLines = engine.layout(pendingParts, firstLineWidth);
        for (let index = 0; index < layoutLines.length; index++) {
          const layoutLine = layoutLines[index];
          if (layoutLine === undefined || layoutLine.items.length === 0) { continue; }
          const isLastLine = index === layoutLines.length - 1;
          const metrics = LocalReaderPaginator.metricsForRange(layoutLine.startPosition,
            layoutLine.endPosition, lineHeight, sizeOffsets);
          for (let itemIndex = 0; itemIndex < layoutLine.items.length; itemIndex++) {
            const layoutItem = layoutLine.items[itemIndex];
            if (layoutItem === undefined) { continue; }
            lineItems.push({
              kind: 'text', value: layoutItem.value, width: layoutItem.width, height: lineHeight,
              startPosition: layoutItem.startPosition, endPosition: layoutItem.endPosition,
              leadingIndent: layoutItem.leadingIndent
            });
          }
          lineWidth += layoutLine.width;
          currentLineHeight = Math.max(currentLineHeight, metrics.height);
          currentLinePadTop = Math.max(currentLinePadTop, metrics.padTop);
          currentLinePadBottom = Math.max(currentLinePadBottom, metrics.padBottom);
          if (isLastLine && keepLastLine) { continue; }
          appendLine(isLastLine ? lastSpacing : 0);
          emittedLineCount++;
          if (emittedLineCount % 8 === 0) { await yieldToUi(); }
        }
      };
      for (let partIndex = 0; partIndex < paragraph.parts.length; partIndex++) {
        const part: LocalSemanticPart | undefined = paragraph.parts[partIndex];
        if (part === undefined) { continue; }
        if (part.kind === 'text') {
          runParts.push({
            value: part.value, startPosition: part.startPosition, leadingIndent: part.leadingIndent
          });
          continue;
        }
        const intrinsic = imageSizes.get(part.value);
        const sourceWidth = intrinsic?.width ?? 0;
        const sourceHeight = intrinsic?.height ?? 0;
        if (sourceWidth <= 0 || sourceHeight <= 0) { continue; }
        const normalizedImageStyle = imageStyle.toUpperCase();
        const inlineStyle = normalizedImageStyle === 'TEXT' ||
          (normalizedImageStyle === 'DEFAULT' &&
            sourceWidth < standaloneImageThreshold && sourceHeight < standaloneImageThreshold);
        if (inlineStyle) {
          await flushRun(true, 0);
          const width = Math.max(1, inlineImageWidth);
          const height = width * sourceHeight / sourceWidth;
          if (lineItems.length > 0 && lineWidth + width > contentWidth) { appendLine(); }
          currentLineHeight = Math.max(currentLineHeight, height);
          lineItems.push({
            kind: 'image', value: part.value, width: width, height: height,
            startPosition: part.startPosition, endPosition: part.endPosition, leadingIndent: false
          });
          lineWidth += width;
          continue;
        }
        const singlePage = normalizedImageStyle === 'SINGLE';
        const fullWidth = normalizedImageStyle === 'FULL';
        await flushRun(false, paragraphSpacing);
        if (singlePage && pageLineCount > 0) { flushPage(); }
        let availablePageHeight = currentPageCapacity();
        let scale = singlePage || fullWidth
          ? Math.min(contentWidth / sourceWidth, availablePageHeight / sourceHeight)
          : Math.min(1, contentWidth / sourceWidth, availablePageHeight / sourceHeight);
        let width = sourceWidth * scale;
        let height = sourceHeight * scale;
        if (pageLineCount > 0 && pageUsedHeight + height > currentPageCapacity()) {
          flushPage();
          availablePageHeight = currentPageCapacity();
          scale = singlePage || fullWidth
            ? Math.min(contentWidth / sourceWidth, availablePageHeight / sourceHeight)
            : Math.min(1, contentWidth / sourceWidth, availablePageHeight / sourceHeight);
          width = sourceWidth * scale;
          height = sourceHeight * scale;
        }
        const verticalSpaceBefore = singlePage ? Math.max(0, (availablePageHeight - height) / 2) : 0;
        currentLineHeight = height;
        lineItems.push({
          kind: 'image', value: part.value, width: width, height: height,
          startPosition: part.startPosition, endPosition: part.endPosition, leadingIndent: false
        });
        lineWidth = width;
        appendLine(paragraphSpacing, verticalSpaceBefore, singlePage, singlePage);
      }
      await flushRun(false, paragraphSpacing);
      await yieldToUi();
    };

    for (let index = 0; index < document.paragraphs.length; index++) {
      const paragraph = document.paragraphs[index];
      if (paragraph === undefined) { continue; }
      if (paragraph.pageBreak) {
        // 与 paginate 同一套分页标记语义，否则全书画布页数与当页排版对不上。
        if (pageLineCount > 0) { flushPage(); }
        continue;
      }
      await addParagraph(paragraph);
    }
    flushPage();
    return Math.max(1, pageCount);
  }
}
