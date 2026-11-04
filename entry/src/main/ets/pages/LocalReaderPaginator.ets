import { LocalSemanticDocument, LocalSemanticParagraph } from '../data/LocalTextSemantics';
import { ChineseLineBreaker } from '../reader/ChineseLineBreaker';

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

/** 按设备字体度量分页，保留 Android 字符坐标，并对齐默认正文的非末行字距。 */
export class LocalReaderPaginator {
  private static findWordBreakIndex(
    text: string,
    nextCharacter: string,
    measureTextWidth: (text: string) => number,
    contentWidth: number
  ): number {
    if (!/^[\x21-\x7E]$/.test(nextCharacter)) { return -1; }
    const boundary = Math.max(text.lastIndexOf(' '), text.lastIndexOf('\t'));
    if (boundary <= 0) { return -1; }
    const nextWord = text.substring(boundary + 1) + nextCharacter;
    return measureTextWidth(nextWord) <= contentWidth ? boundary : -1;
  }

  /** 把一行文本切成 codePoint 序列，供避头尾判定（代理对算一个 cluster）。 */
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
    titleBlock: LocalReaderTitleBlock | undefined = undefined
  ): LocalReaderPage[] {
    const columns = columnCount >= 2 ? 2 : 1;
    if (contentWidth <= 0 || contentHeight <= 0 || lineHeight <= 0) {
      return [{ lines: [], startPosition: 0, endPosition: document.content.length, titleOnly: false, lineColumns: [] }];
    }
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
    let lineLastTextPartIndex: number = -1;
    // 命中排版的字号偏移与行上下距：只有落在命中区里的字才抬高本行、加留白。
    let currentLinePadTop = 0;
    let currentLinePadBottom = 0;
    let charHeight = lineHeight;
    let charPadTop = 0;
    let charPadBottom = 0;
    // 字符位置单调递增，命中区间也用同一个游标向前走，不必每个字都从头找。
    let offsetCursor = 0;
    const metricsAt = (position: number): void => {
      charHeight = lineHeight;
      charPadTop = 0;
      charPadBottom = 0;
      while (offsetCursor < sizeOffsets.length) {
        const span = sizeOffsets[offsetCursor];
        if (span === undefined) { break; }
        if (position < span.start) { return; }
        if (position < span.endExclusive) {
          charHeight = Math.max(1, lineHeight + span.extraHeight);
          charPadTop = span.padTop;
          charPadBottom = span.padBottom;
          return;
        }
        offsetCursor++;
      }
    };

    const currentPageCapacity = (): number => Math.max(lineHeight,
      contentHeight - (pages.length === 0 ? Math.max(0, firstPageReservedLines) * lineHeight : 0));
    const flushPage = (): void => {
      if (pageLines.length === 0) { return; }
      pages.push({
        lines: pageLines, startPosition: pageStart, endPosition: pageEnd,
        titleOnly: false, lineColumns: pageColumns
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
      lineLastTextPartIndex = -1;
      if (pageBreakAfter) { flushPage(); }
    };
    const addParagraph = (paragraph: LocalSemanticParagraph): void => {
      for (let partIndex = 0; partIndex < paragraph.parts.length; partIndex++) {
        const part = paragraph.parts[partIndex];
        if (part === undefined) { continue; }
        if (part.kind === 'text') {
          let cursor = 0;
          while (cursor < part.value.length) {
            const codePoint = part.value.codePointAt(cursor);
            const nextCursor = cursor + (codePoint !== undefined && codePoint > 0xFFFF ? 2 : 1);
            const character = part.value.substring(cursor, nextCursor);
            const position = part.startPosition + cursor;
            // 该字若落在高亮规则命中区里，本行要按规则的字号偏移与行上下距排版。
            metricsAt(position);
            const finalPosition = part.startPosition + nextCursor;
            const lastItem = lineItems[lineItems.length - 1];
            const mergePrevious = lastItem?.kind === 'text' && lineLastTextPartIndex === partIndex;
            const lastTextWidth = mergePrevious ? lastItem?.width ?? 0 : 0;
            const lastText = mergePrevious ? lastItem?.value ?? '' : '';
            const candidateText = lastText + character;
            const candidateWidth = measureTextWidth(candidateText);
            const nextLineWidth = lineWidth - lastTextWidth + candidateWidth;
            if (lineItems.length > 0 && nextLineWidth > contentWidth) {
              if (character === ' ' || character === '\t') {
                appendLine(position + nextCursor - cursor, true);
                cursor = nextCursor;
                continue;
              }
              const wordBreak = mergePrevious
                ? LocalReaderPaginator.findWordBreakIndex(lastText, character, measureTextWidth, contentWidth) : -1;
              if (wordBreak >= 0 && lastItem !== undefined && lastItem.kind === 'text') {
                const prefix = lastText.substring(0, wordBreak);
                const prefixWidth = measureTextWidth(prefix);
                const nextWord = lastText.substring(wordBreak + 1) + character;
                const nextWordWidth = measureTextWidth(nextWord);
                const nextWordStart = lastItem.startPosition + wordBreak + 1;
                lineItems[lineItems.length - 1] = {
                  kind: 'text', value: prefix, width: prefixWidth, height: lineHeight,
                  startPosition: lastItem.startPosition, endPosition: nextWordStart,
                  leadingIndent: lastItem.leadingIndent
                };
                lineWidth = lineWidth - lastTextWidth + prefixWidth;
                appendLine(nextWordStart, true);
                lineItems.push({
                  kind: 'text', value: nextWord, width: nextWordWidth, height: lineHeight,
                  startPosition: nextWordStart, endPosition: finalPosition,
                  leadingIndent: part.leadingIndent
                });
                lineWidth = nextWordWidth;
                lineLastTextPartIndex = partIndex;
                cursor = nextCursor;
                continue;
              }
              // 中文避头尾：上游 `ReaderPaginator.kt:559` 无条件用 ChineseLineBreaker，
              // 溢出时把本行末尾的标点/开引号一起搬到下一行，避免行首出现「，。！》」，
              // 也避免行尾挂一个开引号。找不到合法断点时才硬断。
              if (mergePrevious && lastItem !== undefined && lastItem.kind === 'text') {
                const carried = ChineseLineBreaker.resolve(LocalReaderPaginator.toClusters(lastText), character);
                if (carried > 0) {
                  const parts = ChineseLineBreaker.splitTail(lastText, carried);
                  const prefix = parts[0] ?? '';
                  const tail = parts[1] ?? '';
                  if (prefix.length === 0) {
                    lineItems.pop();
                    lineWidth = lineWidth - lastTextWidth;
                  } else {
                    const prefixWidth = measureTextWidth(prefix);
                    lineItems[lineItems.length - 1] = {
                      kind: 'text', value: prefix, width: prefixWidth, height: lineHeight,
                      startPosition: lastItem.startPosition, endPosition: lastItem.startPosition + prefix.length,
                      leadingIndent: lastItem.leadingIndent
                    };
                    lineWidth = lineWidth - lastTextWidth + prefixWidth;
                  }
                  appendLine(lastItem.startPosition + prefix.length, true);
                  // 被搬下来的标点与本字符一起成为下一行行首
                  const carriedText = tail + character;
                  const carriedWidth = measureTextWidth(carriedText);
                  lineItems.push({
                    kind: 'text', value: carriedText, width: carriedWidth, height: lineHeight,
                    startPosition: lastItem.startPosition + prefix.length, endPosition: finalPosition,
                    leadingIndent: false
                  });
                  lineWidth = carriedWidth;
                  lineLastTextPartIndex = partIndex;
                  cursor = nextCursor;
                  continue;
                }
              }
              appendLine(undefined, true);
              continue;
            }
            if (mergePrevious && lastItem !== undefined && lastItem.kind === 'text') {
              lineItems[lineItems.length - 1] = {
                kind: 'text', value: candidateText, width: candidateWidth, height: lineHeight,
                startPosition: lastItem.startPosition, endPosition: finalPosition,
                leadingIndent: part.leadingIndent
              };
            } else {
              lineItems.push({
                kind: 'text', value: character, width: candidateWidth, height: lineHeight,
                startPosition: position, endPosition: finalPosition,
                leadingIndent: part.leadingIndent
              });
            }
            currentLineHeight = Math.max(currentLineHeight, charHeight);
            currentLinePadTop = Math.max(currentLinePadTop, charPadTop);
            currentLinePadBottom = Math.max(currentLinePadBottom, charPadBottom);
            lineLastTextPartIndex = partIndex;
            lineWidth = nextLineWidth;
            cursor = nextCursor;
          }
        } else {
          const intrinsic = imageSizes.get(part.value);
          const sourceWidth = intrinsic?.width ?? 0;
          const sourceHeight = intrinsic?.height ?? 0;
          if (sourceWidth <= 0 || sourceHeight <= 0) { continue; }
          const normalizedImageStyle = imageStyle.toUpperCase();
          const inlineStyle = normalizedImageStyle === 'TEXT' ||
            (normalizedImageStyle === 'DEFAULT' &&
              sourceWidth < standaloneImageThreshold && sourceHeight < standaloneImageThreshold);
          if (inlineStyle) {
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
          if (lineItems.length > 0) { appendLine(undefined, true, paragraphSpacing); }
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
      }
      appendLine(paragraph.endPosition, false, paragraphSpacing);
    };

    /**
     * 章标题块：按段排成标题行，走与正文完全相同的 `appendLine` / `advanceColumn` 通道，
     * 因此标题会跟着正文一起翻页、一起滚动，不会被挤到画布外面去。
     *
     * 间距口径对齐上游 `ReaderPaginator.processBlock`（`:411`、`:425-430`）：
     * 首段之前加 `titleTopSpacingPx`，每段之后加「下一段还是标题 → 分段间距，否则 → 章标题下间距」。
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
        // 逐字断行：标题比正文宽时同样要折行，上游标题走同一个 ChineseLineBreaker。
        const clusters = LocalReaderPaginator.toClusters(segment.text);
        let lineClusters: string[] = [];
        let lineWidth = 0;
        let emittedLine = 0;
        const flushTitleLine = (spacing: number): void => {
          if (lineClusters.length === 0) { return; }
          lineItems = [{
            kind: 'text', value: lineClusters.join(''),
            width: lineWidth, height: segmentLineHeight,
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
          lineWidth = 0;
        };
        for (let clusterIndex = 0; clusterIndex < clusters.length; clusterIndex++) {
          const cluster = clusters[clusterIndex] as string;
          const clusterWidth = block.measureWidth(cluster, segment.fontSizeScale);
          if (lineClusters.length > 0 && lineWidth + clusterWidth > contentWidth) {
            flushTitleLine(0);
          }
          lineClusters.push(cluster);
          lineWidth += clusterWidth;
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

  /** 按同一排版规则计页；逐字测量时定期让出 UI 线程，不构造整书页面对象。 */
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
    titleBlock: LocalReaderTitleBlock | undefined = undefined
  ): Promise<number> {
    const columns = columnCount >= 2 ? 2 : 1;
    if (contentWidth <= 0 || contentHeight <= 0 || lineHeight <= 0) { return 1; }
    let pageCount = 0;
    let pageLineCount = 0;
    let pageUsedHeight = 0;
    // 与 paginate 同一套换列规则，否则全书画布与当页排版对不上。
    let columnIndex = 0;
    let lineItems: LocalReaderLineItem[] = [];
    let lineWidth = 0;
    let currentLineHeight = lineHeight;
    let lineLastTextPartIndex: number = -1;
    // 命中排版的字号偏移与行上下距：只有落在命中区里的字才抬高本行、加留白。
    let currentLinePadTop = 0;
    let currentLinePadBottom = 0;
    let charHeight = lineHeight;
    let charPadTop = 0;
    let charPadBottom = 0;
    // 字符位置单调递增，命中区间也用同一个游标向前走，不必每个字都从头找。
    let offsetCursor = 0;
    const metricsAt = (position: number): void => {
      charHeight = lineHeight;
      charPadTop = 0;
      charPadBottom = 0;
      while (offsetCursor < sizeOffsets.length) {
        const span = sizeOffsets[offsetCursor];
        if (span === undefined) { break; }
        if (position < span.start) { return; }
        if (position < span.endExclusive) {
          charHeight = Math.max(1, lineHeight + span.extraHeight);
          charPadTop = span.padTop;
          charPadBottom = span.padBottom;
          return;
        }
        offsetCursor++;
      }
    };
    let measuredCharacterCount = 0;

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
      lineLastTextPartIndex = -1;
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
        let lineWidth = 0;
        let emittedLine = 0;
        const flushTitleLine = (spacing: number): void => {
          if (lineClusters === 0) { return; }
          lineItems = [{
            kind: 'text', value: ' ', width: lineWidth, height: segmentLineHeight,
            startPosition: 0, endPosition: 0, leadingIndent: false,
            titleFontScale: segment.fontSizeScale
          }];
          currentLineHeight = segmentLineHeight;
          const verticalSpaceBefore = emittedLine === 0 ? Math.max(0, block.topSpacing) : 0;
          appendLine(spacing, verticalSpaceBefore);
          emittedLine++;
          lineClusters = 0;
          lineWidth = 0;
        };
        for (let clusterIndex = 0; clusterIndex < clusters.length; clusterIndex++) {
          const cluster = clusters[clusterIndex] as string;
          const clusterWidth = block.measureWidth(cluster, segment.fontSizeScale);
          if (lineClusters > 0 && lineWidth + clusterWidth > contentWidth) {
            flushTitleLine(0);
          }
          lineClusters++;
          lineWidth += clusterWidth;
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
      for (let partIndex = 0; partIndex < paragraph.parts.length; partIndex++) {
        const part = paragraph.parts[partIndex];
        if (part === undefined) { continue; }
        if (part.kind === 'text') {
          let cursor = 0;
          while (cursor < part.value.length) {
            const codePoint = part.value.codePointAt(cursor);
            const nextCursor = cursor + (codePoint !== undefined && codePoint > 0xFFFF ? 2 : 1);
            const character = part.value.substring(cursor, nextCursor);
            const position = part.startPosition + cursor;
            // 该字若落在高亮规则命中区里，本行要按规则的字号偏移与行上下距排版。
            metricsAt(position);
            const finalPosition = part.startPosition + nextCursor;
            const lastItem = lineItems[lineItems.length - 1];
            const mergePrevious = lastItem?.kind === 'text' && lineLastTextPartIndex === partIndex;
            const lastTextWidth = mergePrevious ? lastItem?.width ?? 0 : 0;
            const lastText = mergePrevious ? lastItem?.value ?? '' : '';
            const candidateText = lastText + character;
            const candidateWidth = measureTextWidth(candidateText);
            measuredCharacterCount++;
            const nextLineWidth = lineWidth - lastTextWidth + candidateWidth;
            if (lineItems.length > 0 && nextLineWidth > contentWidth) {
              if (character === ' ' || character === '\t') {
                appendLine(0, 0, false, false);
                cursor = nextCursor;
                continue;
              }
              const wordBreak = mergePrevious
                ? LocalReaderPaginator.findWordBreakIndex(lastText, character, measureTextWidth, contentWidth) : -1;
              if (wordBreak >= 0 && lastItem !== undefined && lastItem.kind === 'text') {
                const prefix = lastText.substring(0, wordBreak);
                const prefixWidth = measureTextWidth(prefix);
                const nextWord = lastText.substring(wordBreak + 1) + character;
                const nextWordWidth = measureTextWidth(nextWord);
                const nextWordStart = lastItem.startPosition + wordBreak + 1;
                lineItems[lineItems.length - 1] = {
                  kind: 'text', value: prefix, width: prefixWidth, height: lineHeight,
                  startPosition: lastItem.startPosition, endPosition: nextWordStart,
                  leadingIndent: lastItem.leadingIndent
                };
                lineWidth = lineWidth - lastTextWidth + prefixWidth;
                appendLine(0, 0, false, false);
                lineItems.push({
                  kind: 'text', value: nextWord, width: nextWordWidth, height: lineHeight,
                  startPosition: nextWordStart, endPosition: finalPosition, leadingIndent: part.leadingIndent
                });
                lineWidth = nextWordWidth;
                lineLastTextPartIndex = partIndex;
                cursor = nextCursor;
                continue;
              }
              appendLine(0, 0, false, false);
              continue;
            }
            if (mergePrevious && lastItem !== undefined && lastItem.kind === 'text') {
              lineItems[lineItems.length - 1] = {
                kind: 'text', value: candidateText, width: candidateWidth, height: lineHeight,
                startPosition: lastItem.startPosition, endPosition: finalPosition,
                leadingIndent: part.leadingIndent
              };
            } else {
              lineItems.push({
                kind: 'text', value: character, width: candidateWidth, height: lineHeight,
                startPosition: position, endPosition: finalPosition, leadingIndent: part.leadingIndent
              });
            }
            currentLineHeight = Math.max(currentLineHeight, charHeight);
            currentLinePadTop = Math.max(currentLinePadTop, charPadTop);
            currentLinePadBottom = Math.max(currentLinePadBottom, charPadBottom);
            lineLastTextPartIndex = partIndex;
            lineWidth = nextLineWidth;
            cursor = nextCursor;
            if (measuredCharacterCount % 256 === 0) { await yieldToUi(); }
          }
        } else {
          const intrinsic = imageSizes.get(part.value);
          const sourceWidth = intrinsic?.width ?? 0;
          const sourceHeight = intrinsic?.height ?? 0;
          if (sourceWidth <= 0 || sourceHeight <= 0) { continue; }
          const normalizedImageStyle = imageStyle.toUpperCase();
          const inlineStyle = normalizedImageStyle === 'TEXT' ||
            (normalizedImageStyle === 'DEFAULT' &&
              sourceWidth < standaloneImageThreshold && sourceHeight < standaloneImageThreshold);
          if (inlineStyle) {
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
          if (lineItems.length > 0) { appendLine(paragraphSpacing); }
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
      }
      appendLine(paragraphSpacing);
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
