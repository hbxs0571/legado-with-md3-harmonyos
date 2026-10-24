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
}

export interface LocalSemanticDocument {
  paragraphs: LocalSemanticParagraph[];
  content: string;
}

/** 按 Android 默认章节正文管线生成段落、图片占位和字符坐标。 */
export class LocalTextSemantics {
  static fromRawBody(rawBody: string): string {
    return LocalTextSemantics.parse(rawBody).content;
  }

  static parse(rawBody: string): LocalSemanticDocument {
    const paragraphs: LocalSemanticParagraph[] = [];
    const semanticContent: string[] = [];
    const imagePattern: RegExp = /\[\[EPUB_IMAGE:([^;\]\r\n]+)(?:;[^\]\r\n]*)?\]\]/g;
    const lines = rawBody.split(/\n/);
    let position = 0;
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
        const parts: LocalSemanticPart[] = [];
        const paragraphStart = position;
        const imageOnlyParagraph = /^\s*(?:\[\[EPUB_IMAGE:[^;\]\r\n]+(?:;[^\]\r\n]*)?\]\]\s*)+$/.test(paragraphText);
        if (!imageOnlyParagraph) {
          parts.push({ kind: 'text', value: '　　', startPosition: position, endPosition: position + 2, leadingIndent: true });
          semanticContent.push('　　');
          position += 2;
        }
        let cursor = 0;
        let match: RegExpExecArray | null = imagePattern.exec(paragraphText);
        while (match !== null) {
          if (match.index > cursor) {
            const text = paragraphText.substring(cursor, match.index);
            parts.push({ kind: 'text', value: text, startPosition: position, endPosition: position + text.length, leadingIndent: false });
            semanticContent.push(text);
            position += text.length;
          }
          const imageUri = match[1] ?? '';
          if (imageUri.length > 0) {
            parts.push({ kind: 'image', value: imageUri, startPosition: position, endPosition: position + 1, leadingIndent: false });
            semanticContent.push('\uFFFC');
            position++;
          }
          cursor = match.index + match[0].length;
          match = imagePattern.exec(paragraphText);
        }
        imagePattern.lastIndex = 0;
        if (cursor < paragraphText.length) {
          const text = paragraphText.substring(cursor);
          parts.push({ kind: 'text', value: text, startPosition: position, endPosition: position + text.length, leadingIndent: false });
          semanticContent.push(text);
          position += text.length;
        }
        semanticContent.push('\n');
        position++;
        paragraphs.push({ parts: parts, startPosition: paragraphStart, endPosition: position });
      }
    }
    return { paragraphs: paragraphs, content: semanticContent.join('') };
  }
}
