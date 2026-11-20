// 单源执行链门面（P2）：对 UI 暴露 searchOne / detail / toc / content 四个静态方法。
// 从仓储按书源 URL 读一条 → LegadoSourceMapper 投影成引擎 BookSource → 交 WebBookService。
import { BookSource } from '@legado/sourceengine';
import { BookSourceRepository } from '../data/BookSourceRepository';
import { LegadoSourceMapper } from './LegadoSourceMapper';
import { WebBookService } from './WebBookService';
import { RemoteBookDetail, RemoteChapter, SearchBookItem } from './SourceModels';

/** 单源搜索结果：带来源与耗时，供 P3 多源合并与结果四态使用。 */
export interface SourceSearchResult {
  sourceUrl: string;
  sourceName: string;
  books: SearchBookItem[];
  error: string;        // 空串表示成功
  elapsedMs: number;
}

export class BookSourceRuntime {
  /** 按 URL 从仓储取源并映射；找不到返回 null。 */
  private static resolveSource(sourceUrl: string): BookSource | null {
    const all = BookSourceRepository.getAll();
    for (const local of all) {
      if (local.bookSourceUrl === sourceUrl) {
        return LegadoSourceMapper.fromLocal(local);
      }
    }
    return null;
  }

  /** 单源搜索：成功返回条目，失败返回 error 非空的结果（不抛异常，便于并发编排）。 */
  static async searchOne(sourceUrl: string, keyword: string, page: number): Promise<SourceSearchResult> {
    const t0 = Date.now();
    const src = BookSourceRuntime.resolveSource(sourceUrl);
    if (src === null) {
      return {
        sourceUrl: sourceUrl, sourceName: '', books: [],
        error: '书源不存在：' + sourceUrl, elapsedMs: Date.now() - t0
      };
    }
    try {
      const books = await WebBookService.searchBook(src, keyword, page);
      return {
        sourceUrl: sourceUrl, sourceName: src.bookSourceName, books: books,
        error: '', elapsedMs: Date.now() - t0
      };
    } catch (e) {
      return {
        sourceUrl: sourceUrl, sourceName: src.bookSourceName, books: [],
        error: e instanceof Error ? e.message : String(e), elapsedMs: Date.now() - t0
      };
    }
  }

  /** 详情。 */
  static async detail(sourceUrl: string, bookUrl: string): Promise<RemoteBookDetail> {
    const src = BookSourceRuntime.resolveSource(sourceUrl);
    if (src === null) throw new Error('书源不存在：' + sourceUrl);
    return WebBookService.getBookInfo(src, bookUrl);
  }

  /** 目录。 */
  static async toc(sourceUrl: string, bookUrl: string, tocUrl: string): Promise<RemoteChapter[]> {
    const src = BookSourceRuntime.resolveSource(sourceUrl);
    if (src === null) throw new Error('书源不存在：' + sourceUrl);
    return WebBookService.getChapterList(src, tocUrl || bookUrl);
  }

  /** 正文。 */
  static async content(sourceUrl: string, chapterUrl: string): Promise<string> {
    const src = BookSourceRuntime.resolveSource(sourceUrl);
    if (src === null) throw new Error('书源不存在：' + sourceUrl);
    return WebBookService.getContent(src, chapterUrl);
  }
}
