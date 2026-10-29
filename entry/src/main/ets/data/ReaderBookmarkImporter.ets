import { Book } from '../model/Book';
import { ReaderBookmark } from '../model/ReaderBookmark';
import { ReaderMarking, ReaderMarkingEffect } from '../model/ReaderMarking';

/** 一次导入的结果：新增、覆盖、跳过（匹配不到书或字段非法）。 */
export interface BookmarkImportOutcome {
  added: number;
  updated: number;
  skipped: number;
}

/** 由上游 styleJson 反推出的本地样式：效果 + `#RRGGBB` 颜色。 */
interface ResolvedMarkingStyle {
  effect: ReaderMarkingEffect;
  color: string;
}

/**
 * 解析 Android ZIP 备份里的 `bookmark.json` 与 `bookMarking.json`。
 *
 * 与 `ReaderBookmarkExporter` 互为逆向：导出时把本地拍平的 effect/color
 * 还原成上游的 anchorJson/styleJson，这里再把两段 JSON 拆回本地字段。
 * 不读不写仓储，合并语义由调用方决定。
 */
export class ReaderBookmarkImporter {
  /**
   * 合并书签，返回合并后的完整列表。
   *
   * 去重口径：按「书 id + 章节 + 章内位置 + 原文」判定同一条。上游主键是
   * 创建时间戳，但两端时钟不同源，用内容定位比时间更稳。
   * 匹配不到本地书籍的条目计入 skipped —— 本地没有正文就无法跳转，
   * 强行塞进去只会产生点了没反应的孤儿记录。
   */
  static mergeBookmarks(json: string, books: Book[], current: ReaderBookmark[],
    outcome: BookmarkImportOutcome): ReaderBookmark[] {
    const merged: ReaderBookmark[] = current.slice();
    const records = ReaderBookmarkImporter.parseArray(json);
    records.forEach((record: Record<string, Object>) => {
      const bookName = ReaderBookmarkImporter.readString(record, 'bookName');
      const bookAuthor = ReaderBookmarkImporter.readString(record, 'bookAuthor');
      const book = ReaderBookmarkImporter.findBook(books, bookName, bookAuthor);
      const chapterPosition = ReaderBookmarkImporter.readNumber(record, 'chapterPos', 0);
      const createdAt = ReaderBookmarkImporter.readNumber(record, 'time', 0);
      if (book === undefined || chapterPosition < 0 || createdAt <= 0) {
        outcome.skipped += 1;
        return;
      }
      const candidate: ReaderBookmark = {
        id: `${book.id}-${createdAt}`,
        bookId: book.id,
        bookName: bookName,
        bookAuthor: bookAuthor,
        bookUrl: ReaderBookmarkImporter.readString(record, 'bookUrl'),
        chapterIndex: ReaderBookmarkImporter.readNumber(record, 'chapterIndex', 0),
        chapterName: ReaderBookmarkImporter.readString(record, 'chapterName'),
        chapterPosition: chapterPosition,
        bookText: ReaderBookmarkImporter.readString(record, 'bookText'),
        content: ReaderBookmarkImporter.readString(record, 'content'),
        createdAt: createdAt
      };
      const existingIndex = merged.findIndex((item: ReaderBookmark) =>
        item.bookId === candidate.bookId && item.chapterIndex === candidate.chapterIndex &&
        item.chapterPosition === candidate.chapterPosition && item.bookText === candidate.bookText);
      if (existingIndex >= 0) {
        // 覆盖时保留本地 id：书签 id 被阅读页用于跳转与删除，换掉会打断已有引用。
        const kept = merged[existingIndex];
        candidate.id = kept !== undefined ? kept.id : candidate.id;
        merged[existingIndex] = candidate;
        outcome.updated += 1;
      } else {
        merged.push(candidate);
        outcome.added += 1;
      }
    });
    return merged;
  }

  /** 与 mergeBookmarks 同构：返回合并后的完整列表，计数累加进同一个 outcome。 */
  static mergeMarkings(json: string, books: Book[], current: ReaderMarking[],
    outcome: BookmarkImportOutcome): ReaderMarking[] {
    const merged: ReaderMarking[] = current.slice();
    const records = ReaderBookmarkImporter.parseArray(json);
    records.forEach((record: Record<string, Object>) => {
      const bookName = ReaderBookmarkImporter.readString(record, 'bookName');
      const bookAuthor = ReaderBookmarkImporter.readString(record, 'bookAuthor');
      const book = ReaderBookmarkImporter.findBook(books, bookName, bookAuthor);
      const id = ReaderBookmarkImporter.readString(record, 'id');
      const anchor = ReaderBookmarkImporter.parseObject(ReaderBookmarkImporter.readString(record, 'anchorJson'));
      const style = ReaderBookmarkImporter.parseObject(ReaderBookmarkImporter.readString(record, 'styleJson'));
      if (book === undefined || id.length === 0 || anchor === undefined) {
        outcome.skipped += 1;
        return;
      }
      const selectedText = ReaderBookmarkImporter.readString(anchor, 'selectedText');
      const chapterPosition = ReaderBookmarkImporter.readNumber(anchor, 'chapterPosition', -1);
      if (selectedText.length === 0 || chapterPosition < 0) {
        outcome.skipped += 1;
        return;
      }
      const resolved = ReaderBookmarkImporter.resolveEffect(style);
      if (resolved === undefined) {
        outcome.skipped += 1;
        return;
      }
      const createdAt = ReaderBookmarkImporter.readNumber(record, 'createdAt', 0);
      const updatedAt = ReaderBookmarkImporter.readNumber(record, 'updatedAt', 0);
      const now = Date.now();
      const candidate: ReaderMarking = {
        id: id,
        bookId: book.id,
        bookName: bookName,
        bookAuthor: bookAuthor,
        bookUrl: ReaderBookmarkImporter.readString(record, 'bookUrl'),
        chapterIndex: ReaderBookmarkImporter.readNumber(anchor, 'chapterIndex', 0),
        chapterName: ReaderBookmarkImporter.readString(record, 'chapterName'),
        chapterPosition: chapterPosition,
        // 上游 anchor 只存起点与选中文本，终点由文本长度推出来。
        endPosition: chapterPosition + selectedText.length,
        selectedText: selectedText,
        contextBefore: ReaderBookmarkImporter.readString(anchor, 'contextBefore'),
        contextAfter: ReaderBookmarkImporter.readString(anchor, 'contextAfter'),
        effect: resolved.effect,
        color: resolved.color,
        note: ReaderBookmarkImporter.readString(record, 'note'),
        enabled: ReaderBookmarkImporter.readBoolean(record, 'enabled', true),
        createdAt: createdAt > 0 ? createdAt : now,
        updatedAt: updatedAt > 0 ? updatedAt : now
      };
      const existingIndex = merged.findIndex((item: ReaderMarking) => item.id === candidate.id);
      if (existingIndex >= 0) {
        merged[existingIndex] = candidate;
        outcome.updated += 1;
      } else {
        merged.push(candidate);
        outcome.added += 1;
      }
    });
    return merged;
  }

  /**
   * 按「书名+作者」找本地书，对应上游 bookmarks/book_marks 的跨源关联键。
   * 作者为空时只按书名匹配，容忍上游缺作者字段的旧记录。
   */
  private static findBook(books: Book[], bookName: string, bookAuthor: string): Book | undefined {
    if (bookName.length === 0) { return undefined; }
    const exact = books.find((book: Book) => book.title === bookName && book.author === bookAuthor);
    if (exact !== undefined) { return exact; }
    return books.find((book: Book) => book.title === bookName);
  }

  /**
   * 上游样式反推本地效果，逐条对齐 `MarkingEffect.fromStyle`。
   * 判断顺序与上游一致：先看下划线模式，再看背景色，最后才是字体色。
   */
  private static resolveEffect(style: Record<string, Object> | undefined): ResolvedMarkingStyle | undefined {
    if (style === undefined) {
      // 上游 styleJson 可空，空样式按默认实线下划线 + 默认绿色处理，不丢记录。
      return { effect: 'solid', color: '#63C37D' };
    }
    const underlineMode = ReaderBookmarkImporter.readNumber(style, 'underlineMode', 0);
    if (underlineMode === 1) {
      return { effect: 'solid', color: ReaderBookmarkImporter.colorToCss(
        ReaderBookmarkImporter.readNumber(style, 'underlineColor', 0)) };
    }
    if (underlineMode === 3) {
      return { effect: 'wave', color: ReaderBookmarkImporter.colorToCss(
        ReaderBookmarkImporter.readNumber(style, 'underlineColor', 0)) };
    }
    if (underlineMode === 2) {
      return { effect: 'dashed', color: ReaderBookmarkImporter.colorToCss(
        ReaderBookmarkImporter.readNumber(style, 'underlineColor', 0)) };
    }
    if (underlineMode === 6) {
      return { effect: 'strike', color: ReaderBookmarkImporter.colorToCss(
        ReaderBookmarkImporter.readNumber(style, 'underlineColor', 0)) };
    }
    if (underlineMode === 7) {
      return { effect: 'highlight', color: ReaderBookmarkImporter.colorToCss(
        ReaderBookmarkImporter.readNumber(style, 'underlineColor', 0)) };
    }
    const bgColor = ReaderBookmarkImporter.readOptionalNumber(style, 'bgColor');
    if (bgColor !== undefined) {
      // 上游背景色固定带 0x33 alpha，本地存纯色、渲染时再补透明度。
      return { effect: 'background', color: ReaderBookmarkImporter.colorToCss(bgColor) };
    }
    const textColor = ReaderBookmarkImporter.readOptionalNumber(style, 'textColor');
    if (textColor !== undefined) {
      return { effect: 'text', color: ReaderBookmarkImporter.colorToCss(textColor) };
    }
    return { effect: 'solid', color: '#63C37D' };
  }

  /** Android ARGB 整数转本地 `#RRGGBB`；丢掉 alpha，本地渲染层自己决定透明度。 */
  private static colorToCss(color: number): string {
    const rgb = (color & 0x00FFFFFF) >>> 0;
    return `#${rgb.toString(16).padStart(6, '0').toUpperCase()}`;
  }

  /** 解析 JSON 数组；非数组或解析失败返回空数组，由调用方按 0 条处理。 */
  private static parseArray(json: string): Record<string, Object>[] {
    if (json.trim().length === 0) { return []; }
    let parsed: Object;
    try {
      parsed = JSON.parse(json) as Object;
    } catch (_) {
      return [];
    }
    if (!Array.isArray(parsed)) { return []; }
    const rows: Record<string, Object>[] = [];
    (parsed as Object[]).forEach((item: Object) => {
      if (item !== null && typeof item === 'object') {
        rows.push(item as Record<string, Object>);
      }
    });
    return rows;
  }

  /** 解析内嵌的 anchorJson/styleJson 字符串。 */
  private static parseObject(json: string): Record<string, Object> | undefined {
    if (json.trim().length === 0) { return undefined; }
    try {
      const parsed = JSON.parse(json) as Object;
      if (parsed === null || typeof parsed !== 'object') { return undefined; }
      return parsed as Record<string, Object>;
    } catch (_) {
      return undefined;
    }
  }

  private static readString(record: Record<string, Object>, key: string): string {
    const value = record[key];
    return typeof value === 'string' ? value : '';
  }

  private static readNumber(record: Record<string, Object>, key: string, fallback: number): number {
    const value = record[key];
    if (typeof value === 'number' && Number.isFinite(value)) { return Math.trunc(value); }
    return fallback;
  }

  private static readOptionalNumber(record: Record<string, Object>, key: string): number | undefined {
    const value = record[key];
    if (typeof value === 'number' && Number.isFinite(value)) { return Math.trunc(value); }
    return undefined;
  }

  private static readBoolean(record: Record<string, Object>, key: string, fallback: boolean): boolean {
    const value = record[key];
    return typeof value === 'boolean' ? value : fallback;
  }
}
