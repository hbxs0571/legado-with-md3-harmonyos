import {
  BookContentProcess, CONTENT_PROCESS_KIND_USER_HIGHLIGHT, CONTENT_PROCESS_KIND_USER_UNDERLINE,
  CONTENT_PROCESS_STAGE_CONTENT, CONTENT_PROCESS_STATUS_ACTIVE,
  TextProcessAction, TextProcessAnchor
} from '../model/BookContentProcess';

export interface ContentProcessApplyResult {
  text: string;
  effectiveProcesses: BookContentProcess[];
}

interface SourceRange {
  start: number;
  end: number;
}

interface NormalizedText {
  text: string;
  sourceIndices: number[];
}

/** 按 Android BookContentProcessEngine 的锚点和动作规则处理当前章节正文。 */
export class BookContentProcessEngine {
  static apply(content: string, processes: BookContentProcess[]): ContentProcessApplyResult {
    if (content.length === 0 || processes.length === 0) {
      return { text: content, effectiveProcesses: [] };
    }
    let output = content;
    const effective: BookContentProcess[] = [];
    for (const process of processes) {
      if (!process.enabled || process.status !== CONTENT_PROCESS_STATUS_ACTIVE ||
        process.stage !== CONTENT_PROCESS_STAGE_CONTENT) {
        continue;
      }
      let anchor: TextProcessAnchor;
      try {
        anchor = JSON.parse(process.anchorJson);
      } catch (_) {
        continue;
      }
      if (typeof anchor.selectedText !== 'string' ||
        (anchor.chapterPosition !== null && anchor.chapterPosition !== undefined &&
          typeof anchor.chapterPosition !== 'number')) {
        continue;
      }
      if (process.kind === CONTENT_PROCESS_KIND_USER_UNDERLINE ||
        process.kind === CONTENT_PROCESS_KIND_USER_HIGHLIGHT) {
        // Android 的用户划线/高亮只标记正文区间，不执行动作或改变正文。
        if (BookContentProcessEngine.findTargetRange(output, anchor) !== undefined) {
          effective.push(process);
        }
        continue;
      }
      let action: TextProcessAction;
      try {
        action = JSON.parse(process.actionJson);
      } catch (_) {
        continue;
      }
      if (typeof action.type !== 'string') {
        continue;
      }
      const range = BookContentProcessEngine.findTargetRange(output, anchor);
      if (range === undefined) {
        continue;
      }
      let next = output;
      if (action.type === 'replace') {
        next = output.slice(0, range.start) +
          BookContentProcessEngine.normalizeProcessText(action.replacement ?? '') + output.slice(range.end);
      } else if (action.type === 'delete') {
        next = output.slice(0, range.start) + output.slice(range.end);
      } else if (action.type === 'insert_before') {
        next = output.slice(0, range.start) +
          BookContentProcessEngine.normalizeProcessText(action.text ?? '') + output.slice(range.start);
      } else if (action.type === 'insert_after') {
        next = output.slice(0, range.end) +
          BookContentProcessEngine.normalizeProcessText(action.text ?? '') + output.slice(range.end);
      }
      if (next !== output) {
        output = next;
        effective.push(process);
      }
    }
    return { text: output, effectiveProcesses: effective };
  }

  static normalizeProcessText(text: string): string {
    return text.split(/\r?\n/).map((line: string) => BookContentProcessEngine.trimProcessText(line))
      .join('\n').replace(/^[\s　]+|[\s　]+$/g, '');
  }

  private static findTargetRange(content: string, anchor: TextProcessAnchor): SourceRange | undefined {
    const candidates = [
      anchor.selectedText,
      BookContentProcessEngine.normalizeProcessText(anchor.selectedText)
    ].map((value: string) => value.trim()).filter((value: string, index: number, values: string[]) =>
      value.length > 0 && values.indexOf(value) === index);
    const approximatePosition = anchor.chapterPosition ?? 0;
    for (const candidate of candidates) {
      const start = BookContentProcessEngine.findClosestOccurrence(content, candidate, approximatePosition);
      if (start >= 0) {
        return { start: start, end: start + candidate.length };
      }
    }
    const normalized = BookContentProcessEngine.normalizeForMatching(content);
    for (const candidate of candidates) {
      const normalizedCandidate = BookContentProcessEngine.normalizeForMatching(candidate).text;
      if (normalizedCandidate.length === 0) {
        continue;
      }
      const range = BookContentProcessEngine.findClosestNormalizedOccurrence(
        normalized, normalizedCandidate, approximatePosition);
      if (range !== undefined) {
        return range;
      }
    }
    return undefined;
  }

  private static findClosestOccurrence(content: string, target: string, approximatePosition: number): number {
    let match = content.indexOf(target);
    if (match < 0) {
      return -1;
    }
    let closest = match;
    let closestDistance = Math.abs(match - approximatePosition);
    while (match >= 0) {
      const distance = Math.abs(match - approximatePosition);
      if (distance < closestDistance) {
        closest = match;
        closestDistance = distance;
      }
      match = content.indexOf(target, match + 1);
    }
    return closest;
  }

  private static normalizeForMatching(value: string): NormalizedText {
    let normalized: string = '';
    const sourceIndices: number[] = [];
    for (let index = 0; index < value.length; index++) {
      const character = value.charAt(index);
      if (!BookContentProcessEngine.isProcessWhitespace(character)) {
        normalized += character;
        sourceIndices.push(index);
      }
    }
    return { text: normalized, sourceIndices: sourceIndices };
  }

  private static findClosestNormalizedOccurrence(
    normalizedContent: NormalizedText,
    normalizedTarget: string,
    approximatePosition: number
  ): SourceRange | undefined {
    let match = normalizedContent.text.indexOf(normalizedTarget);
    if (match < 0) {
      return undefined;
    }
    let closestStart = normalizedContent.sourceIndices[match];
    let closestEnd = normalizedContent.sourceIndices[match + normalizedTarget.length - 1] + 1;
    let closestDistance = Math.abs(closestStart - approximatePosition);
    while (match >= 0) {
      const sourceStart = normalizedContent.sourceIndices[match];
      const distance = Math.abs(sourceStart - approximatePosition);
      if (distance < closestDistance) {
        closestStart = sourceStart;
        closestEnd = normalizedContent.sourceIndices[match + normalizedTarget.length - 1] + 1;
        closestDistance = distance;
      }
      match = normalizedContent.text.indexOf(normalizedTarget, match + 1);
    }
    return { start: closestStart, end: closestEnd };
  }

  private static trimProcessText(value: string): string {
    let start = 0;
    let end = value.length;
    while (start < end && BookContentProcessEngine.isProcessWhitespace(value.charAt(start))) {
      start++;
    }
    while (end > start && BookContentProcessEngine.isProcessWhitespace(value.charAt(end - 1))) {
      end--;
    }
    return value.substring(start, end);
  }

  private static isProcessWhitespace(character: string): boolean {
    return character === '　' || /\s/.test(character) || character.charCodeAt(0) <= 0x20;
  }
}
