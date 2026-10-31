import { LocalSemanticDocument, LocalSemanticParagraph } from '../data/LocalTextSemantics';

export interface LocalReaderLineItem {
  kind: 'text' | 'image';
  value: string;
  width: number;
  height: number;
  startPosition: number;
  endPosition: number;
  leadingIndent: boolean;
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
}

export interface LocalReaderImageSize {
  width: number;
  height: number;
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
    columnCount: number = 1
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
      pageBreakAfter: boolean = false
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
      const stretchableGaps = Math.max(0, itemCount - 1 - Math.max(0, leadingIndentCount));
      const justifyGap = justify && fullJustify && stretchableGaps > 0
        ? Math.max(0, (contentWidth - naturalWidth) / stretchableGaps) : 0;
      if (pageBreakBefore && pageLines.length > 0) { flushPage(); }
      if (pageLines.length > 0 &&
        pageUsedHeight + verticalSpaceBefore + currentLineHeight > currentPageCapacity()) {
        advanceColumn();
      }
      if (pageLines.length === 0) { pageStart = lineStart; }
      const line: LocalReaderLine = {
        items: lineItems,
        height: currentLineHeight,
        paragraphSpacingAfter: spacingAfter,
        imageOnly: lineItems.length === 1 && lineItems[0]?.kind === 'image',
        verticalSpaceBefore: verticalSpaceBefore,
        startPosition: lineStart,
        endPosition: lineEnd,
        justifyGap: justifyGap,
        contentWidth: naturalWidth
      };
      pageLines.push(line);
      pageColumns.push(columnIndex);
      pageUsedHeight += verticalSpaceBefore + currentLineHeight + spacingAfter;
      pageEnd = lineEnd;
      lineItems = [];
      lineWidth = 0;
      currentLineHeight = lineHeight;
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
    columnCount: number = 1
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
        pageUsedHeight + verticalSpaceBefore + currentLineHeight > currentPageCapacity()) {
        advanceColumn();
      }
      pageLineCount++;
      pageUsedHeight += verticalSpaceBefore + currentLineHeight + spacingAfter;
      lineItems = [];
      lineWidth = 0;
      currentLineHeight = lineHeight;
      lineLastTextPartIndex = -1;
      if (pageBreakAfter) { flushPage(); }
    };
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
