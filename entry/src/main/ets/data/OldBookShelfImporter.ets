import { Book } from '../model/Book';

/**
 * 旧版本（myBookShelf.json）书架记录。字段全部可选：这份格式是十年前的，
 * 缺字段比完整记录更常见。嵌套的 bookInfoBean 单独用 Record 接。
 */
interface RawOldBook {
  noteUrl?: string;
  bookInfoBean?: Record<string, Object>;
  tag?: string;
  customCoverPath?: string;
  chapterListSize?: number;
  durChapter?: number;
  durChapterName?: string;
  durChapterPage?: number;
  finalDate?: number;
  lastChapterName?: string;
  serialNumber?: number;
  useReplaceRule?: boolean;
  newChapters?: number;
}

/** 解析结果。skipped 是没有 noteUrl（无法落库）的条目数，供界面如实反馈。 */
export interface OldBookShelfParse {
  books: Book[];
  skipped: number;
}

/** 旧版数据导入：解析 myBookShelf.json，转成本地书架记录。 */
export class OldBookShelfImporter {
  /**
   * 对照上游 api ImportOldData.kt:121-160 的 fromOldBooks。
   * 三处与上游不同（都要写进 BOOKSHELF 的差异说明）：
   * 1. 上游 bookUrl 直接当主键，本地主键是 id；这里用 noteUrl 的 FNV 哈希派生。
   * 2. 上游把 originName 存进独立列，本地没有该列，也不塞 androidOriginalPath
   *    （那里存的是 bookUrl，全仓 7 处按它当键比对，塞文件名会污染 key）。
   * 3. 上游 canUpdate / lastCheckCount 本地无消费方，丢弃。
   *
   * 判重按 noteUrl 比对，不按派生 id：books 表读回来时 id 是 bookIdFromUrl(bookUrl) 重算的，
   * 与这里的 FNV 派生值不一致，按 id 判重第二次导入仍会重复落一条（实测踩过）。
   */
  static parse(text: string, existingBookUrls: Set<string>): OldBookShelfParse {
    const trimmed = text.trim();
    if (trimmed.length === 0 || !trimmed.startsWith('[')) {
      return { books: [], skipped: 0 };
    }
    let items: RawOldBook[];
    try {
      items = JSON.parse(trimmed) as RawOldBook[];
    } catch (_) {
      return { books: [], skipped: 1 };
    }
    if (!Array.isArray(items)) {
      return { books: [], skipped: 1 };
    }
    const books: Book[] = [];
    let skipped = 0;
    for (let index = 0; index < items.length; index++) {
      const item = items[index];
      if (item === undefined || item === null) { skipped += 1; continue; }
      const book = OldBookShelfImporter.toBook(item, existingBookUrls);
      if (book === undefined) { skipped += 1; } else { books.push(book); }
    }
    return { books: books, skipped: skipped };
  }

  /** noteUrl 为空的条目没有落库依据；已存在的 bookUrl 直接跳过（与上游按 bookUrl 跳过一致）。 */
  private static toBook(raw: RawOldBook, existingBookUrls: Set<string>): Book | undefined {
    const noteUrl = typeof raw.noteUrl === 'string' ? raw.noteUrl.trim() : '';
    if (noteUrl.length === 0) {
      return undefined;
    }
    const info: Record<string, Object> = raw.bookInfoBean ?? {};
    const infoText = (key: string): string => {
      const value = info[key];
      return typeof value === 'string' ? value as string : '';
    };
    const title = infoText('name').trim();
    const id = OldBookShelfImporter.bookId(noteUrl);
    if (existingBookUrls.has(noteUrl)) {
      return undefined;
    }
    const totalChapters = Math.max(0, Math.trunc(Number(raw.chapterListSize ?? 0)));
    const chapterIndex = Math.max(0, Math.trunc(Number(raw.durChapter ?? 0)));
    const progress = totalChapters > 0 ? Math.min(100, chapterIndex / totalChapters * 100) : 0;
    // 旧版 tag 为 'loc_book' 表示本地书；其余是按来源域名分的在线书，本地一律按「缺正文」占位。
    const isLocalTag = typeof raw.tag === 'string' && raw.tag === 'loc_book';
    const book: Book = {
      id: id,
      title: title.length > 0 ? title : '未命名旧版书籍',
      author: infoText('author'),
      category: '本地',
      groupName: '本地未分组',
      groupNames: [],
      chapterIndex: chapterIndex,
      chapterProgress: Math.max(0, Math.trunc(Number(raw.durChapterPage ?? 0))),
      lastChapter: typeof raw.durChapterName === 'string' ? raw.durChapterName :
        (typeof raw.lastChapterName === 'string' ? raw.lastChapterName : ''),
      latestChapterTitle: typeof raw.lastChapterName === 'string' ? raw.lastChapterName : undefined,
      durChapterTime: Math.max(0, Math.trunc(Number(raw.finalDate ?? 0))),
      order: Math.trunc(Number(raw.serialNumber ?? 0)),
      progress: progress,
      chapterCount: totalChapters.toString(),
      description: infoText('introduce'),
      coverUri: infoText('coverUrl').length > 0 ? infoText('coverUrl') : undefined,
      customCoverUri: typeof raw.customCoverPath === 'string' && raw.customCoverPath.length > 0
        ? raw.customCoverPath : undefined,
      useReplaceRule: raw.useReplaceRule === true,
      // 没有正文本地副本，只有原始 bookUrl；与备份恢复的「缺正文占位书」同一种形态。
      androidOriginalPath: noteUrl,
      format: noteUrl.toLowerCase().endsWith('.epub') ? 'epub' : 'txt',
      isLocal: isLocalTag
    };
    return book;
  }

  /** 与 LocalBookRestorePlanner 的 FNV 派生保持同一思路，前缀区分来源，避免与恢复流程撞 id。 */
  private static bookId(noteUrl: string): string {
    let hash = 2166136261;
    for (let index = 0; index < noteUrl.length; index++) {
      hash ^= noteUrl.charCodeAt(index);
      hash = Math.imul(hash, 16777619) >>> 0;
    }
    return `old-shelf-${hash.toString(16)}`;
  }
}
