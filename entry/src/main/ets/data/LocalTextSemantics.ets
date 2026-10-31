export interface LocalSemanticPart {
  kind: 'text' | 'image';
  value: string;
  startPosition: number;
  endPosition: number;
  leadingIndent: boolean;
}

export interface LocalSemanticParagraph {
  parts: LocalSemanticPart[];
  startPosition: number;
  endPosition: number;
  /** 该段是 `[newpage]` 分页标记，只有 `adaptSpecialStyle` 开启时才会被识别（上游 `ReaderChapterSource.kt:158`）。 */
  pageBreak: boolean;
  /** 该段是 `<usehtml>...</usehtml>` 富文本块，只有 `adaptSpecialStyle` 开启时才会被识别（上游 `ReaderChapterSource.kt:162`）。 */
  richHtml: boolean;
}

export interface LocalSemanticDocument {
  paragraphs: LocalSemanticParagraph[];
  content: string;
  /** 不含 HOS 为显示缩进补入的字符，和 Android 正文章内位置同源。 */
  sourceLength: number;
  /** 渲染坐标到原文坐标的映射，虚拟缩进映射到同一个原文位置。 */
  sourcePositionMap: number[];
}

/** 按 Android 默认章节正文管线生成段落、图片占位和字符坐标。 */
export class LocalTextSemantics {
  static fromRawBody(rawBody: string): string {
    return LocalTextSemantics.parse(rawBody).content;
  }

  static toSourcePosition(document: LocalSemanticDocument, renderPosition: number): number {
    const index = Math.max(0, Math.min(document.content.length, Math.trunc(renderPosition)));
    return document.sourcePositionMap[index] ?? document.sourceLength;
  }

  static toRenderPosition(document: LocalSemanticDocument, sourcePosition: number): number {
    const target = Math.max(0, Math.min(document.sourceLength, Math.trunc(sourcePosition)));
    for (let index = 0; index < document.sourcePositionMap.length; index++) {
      if ((document.sourcePositionMap[index] ?? 0) >= target) { return index; }
    }
    return document.content.length;
  }

  /**
   * 按 Android 默认章节正文管线生成段落、图片占位和字符坐标。
   *
   * [adaptSpecialStyle] 对齐上游 `ReadSettings.adaptSpecialStyle`（默认开）：开启时 `[newpage]`
   * 独占一段即成为一个换页点、`<usehtml>...</usehtml>` 整段成为富文本块（渲染层不显示源码）；
   * 关闭时两者都按字面文字显示（`ReaderChapterSource.kt:158-166`、`ReaderBodyOnlyFilter.kt:56-60`）。
   */
  static parse(rawBody: string, paragraphIndent: string = '　　', adaptSpecialStyle: boolean = true): LocalSemanticDocument {
    const paragraphs: LocalSemanticParagraph[] = [];
    const semanticContent: string[] = [];
    const sourcePositionMap: number[] = [0];
    const imagePattern: RegExp = /\[\[EPUB_IMAGE:([^;\]\r\n]+)(?:;[^\]\r\n]*)?\]\]/g;
    const lines = rawBody.length === 0 ? [] : rawBody.split(/\r\n|\n|\r/);
    let position = 0;
    let sourcePosition = 0;
    const appendRenderOnly = (value: string): void => {
      semanticContent.push(value);
      for (let unit = 0; unit < value.length; unit++) {
        sourcePositionMap.push(sourcePosition);
        position++;
      }
    };
    const appendBoth = (value: string): void => {
      semanticContent.push(value);
      for (let unit = 0; unit < value.length; unit++) {
        position++;
        sourcePosition++;
        sourcePositionMap.push(sourcePosition);
      }
    };
    const appendSourceOnly = (value: string): void => {
      sourcePosition += value.length;
      sourcePositionMap[sourcePositionMap.length - 1] = sourcePosition;
    };
    for (let index = 0; index < lines.length; index++) {
      const line = lines[index] ?? '';
      let start = 0;
      let end = line.length;
      while (start < end && ((line.charCodeAt(start) ?? 0) <= 0x20 || line[start] === '　')) {
        start++;
      }
      while (end > start && ((line.charCodeAt(end - 1) ?? 0) <= 0x20 || line[end - 1] === '　')) {
        end--;
      }
      if (end > start) {
        const paragraphText = line.substring(start, end);
        const trimmedText = paragraphText.trim();
        if (adaptSpecialStyle && trimmedText === '[newpage]') {
          // 分页标记：独占一段，渲染层据此换页，不显示源码（上游 ReaderChapterSource.kt:158）。
          appendSourceOnly(line.substring(0, start));
          const pageBreakStart = position;
          appendBoth(paragraphText);
          appendSourceOnly(line.substring(end));
          appendBoth('\n');
          paragraphs.push({
            parts: [], startPosition: pageBreakStart, endPosition: position,
            pageBreak: true, richHtml: false
          });
          continue;
        }
        const isRichHtml = adaptSpecialStyle && trimmedText.startsWith('<usehtml>') &&
          trimmedText.endsWith('</usehtml>');
        const parts: LocalSemanticPart[] = [];
        const paragraphStart = position;
        const imageOnlyParagraph = /^\s*(?:\[\[EPUB_IMAGE:[^;\]\r\n]+(?:;[^\]\r\n]*)?\]\]\s*)+$/.test(paragraphText);
        appendSourceOnly(line.substring(0, start));
        if (isRichHtml) {
          // 富文本块：整段作为一个 part，源码不逐字进入正文排版（上游 ReaderChapterSource.kt:162）。
          // 源码偏移已在上面统一 appendSourceOnly 过一次，这里只补正文与段尾换行。
          parts.push({
            kind: 'text', value: paragraphText, startPosition: position,
            endPosition: position + paragraphText.length, leadingIndent: false
          });
          appendBoth(paragraphText);
          appendSourceOnly(line.substring(end));
          appendBoth('\n');
          paragraphs.push({
            parts: parts, startPosition: paragraphStart, endPosition: position,
            pageBreak: false, richHtml: true
          });
          continue;
        }
        if (!imageOnlyParagraph && paragraphIndent.length > 0) {
          parts.push({ kind: 'text', value: paragraphIndent, startPosition: position,
            endPosition: position + paragraphIndent.length, leadingIndent: true });
          appendRenderOnly(paragraphIndent);
        }
        let cursor = 0;
        let match: RegExpExecArray | null = imagePattern.exec(paragraphText);
        while (match !== null) {
          if (match.index > cursor) {
            const text = paragraphText.substring(cursor, match.index);
            parts.push({ kind: 'text', value: text, startPosition: position, endPosition: position + text.length, leadingIndent: false });
            appendBoth(text);
          }
          const imageUri = match[1] ?? '';
          if (imageUri.length > 0) {
            parts.push({ kind: 'image', value: imageUri, startPosition: position, endPosition: position + 1, leadingIndent: false });
            appendBoth('\uFFFC');
          }
          cursor = match.index + match[0].length;
          match = imagePattern.exec(paragraphText);
        }
        imagePattern.lastIndex = 0;
        if (cursor < paragraphText.length) {
          const text = paragraphText.substring(cursor);
          parts.push({ kind: 'text', value: text, startPosition: position, endPosition: position + text.length, leadingIndent: false });
          appendBoth(text);
        }
        appendSourceOnly(line.substring(end));
        appendBoth('\n');
        paragraphs.push({ parts: parts, startPosition: paragraphStart, endPosition: position, pageBreak: false, richHtml: false });
      } else {
        // 空段落不绘制，但原文换行仍占 Android 正文字符坐标。
        appendSourceOnly(line);
        appendSourceOnly('\n');
      }
    }
    return {
      paragraphs: paragraphs,
      content: semanticContent.join(''),
      sourceLength: sourcePosition,
      sourcePositionMap: sourcePositionMap
    };
  }
}
