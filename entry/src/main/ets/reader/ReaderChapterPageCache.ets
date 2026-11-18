import { LocalReaderPage } from '../pages/LocalReaderPaginator';

/**
 * 一章已排好页表的内存快照。
 * 对齐上游 ReaderChapterPaginationSnapshot.kt:3-22 的目的（换回同一章不重排），
 * 但本地保留整张页表而不是紧凑下标：本地页对象里有列信息（lineColumns），
 * 只存 pageStarts 反推不出来，硬压成紧凑格式反而要多写一份还原逻辑。
 */
export class ReaderChapterPageCache {
  /** 最多留几章。3 章 = 上一章 + 当前 + 下一章，够覆盖来回翻。 */
  private static readonly LIMIT: number = 3;
  /** key = `${contentPath}|${chapterIndex}|${layoutKey}`，layoutKey 覆盖所有排版输入。 */
  private static cache: Map<string, LocalReaderPage[]> = new Map<string, LocalReaderPage[]>();

  static key(contentPath: string, chapterIndex: number, layoutKey: string): string {
    return `${contentPath}|${chapterIndex}|${layoutKey}`;
  }

  static get(key: string): LocalReaderPage[] | undefined {
    return ReaderChapterPageCache.cache.get(key);
  }

  static put(key: string, pages: LocalReaderPage[]): void {
    ReaderChapterPageCache.cache.delete(key);
    ReaderChapterPageCache.cache.set(key, pages);
    ReaderChapterPageCache.evict();
  }

  static clear(): void {
    ReaderChapterPageCache.cache.clear();
  }

  private static evict(): void {
    while (ReaderChapterPageCache.cache.size > ReaderChapterPageCache.LIMIT) {
      let firstKey: string = '';
      for (const key of ReaderChapterPageCache.cache.keys()) { firstKey = key; break; }
      if (firstKey.length === 0) { return; }
      ReaderChapterPageCache.cache.delete(firstKey);
    }
  }
}
