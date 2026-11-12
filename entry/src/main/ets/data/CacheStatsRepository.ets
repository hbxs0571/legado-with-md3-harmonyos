import { Context } from '@kit.AbilityKit';
import { fileIo } from '@kit.CoreFileKit';
import { Book } from '../model/Book';
import { LocalBookRestorePlanner } from './LocalBookRestorePlanner';

/**
 * 缓存管理页里每本书的本地统计。
 *
 * 本地没有在线章节缓存：正文是一整个 txt/epub 文件，导入即「全部已缓存」。
 * 所以 imported 为真时已缓存章节数恒等于章节总数、进度恒 100%——这是本地事实，不是算错。
 * 上游 BookCacheManageViewModel.kt:244 用 filterNot { it.isLocal || it.isAudio } 把本地书
 * 直接过滤掉，那套「下载中/等待/暂停/失败」状态在本地不成立，这一页只做本地意义的缓存。
 */
export interface BookCacheStat {
  bookUrl: string;
  chapterCount: number;
  imported: boolean;
  sizeBytes: number;
}

export class CacheStatsRepository {
  /** 逐本算：章节数来自 book.chapterCount；占用取应用内导入副本的实际大小。 */
  static async load(context: Context, books: Book[]): Promise<Map<string, BookCacheStat>> {
    const result: Map<string, BookCacheStat> = new Map<string, BookCacheStat>();
    for (let index = 0; index < books.length; index++) {
      const book = books[index];
      if (book === undefined) { continue; }
      const key = LocalBookRestorePlanner.bookUrlOf(book);
      const chapterCount = Number(book.chapterCount ?? '0');
      const path = book.contentPath;
      let imported = false;
      if (path !== undefined && path.length > 0) {
        try { imported = fileIo.accessSync(path); } catch (_error) { imported = false; }
      }
      let sizeBytes = 0;
      if (imported && path !== undefined) {
        try { sizeBytes = fileIo.statSync(path).size; } catch (_error) { sizeBytes = 0; }
      }
      result.set(key, {
        bookUrl: key,
        chapterCount: Number.isNaN(chapterCount) ? 0 : chapterCount,
        imported: imported,
        sizeBytes: sizeBytes
      });
    }
    return result;
  }
}
