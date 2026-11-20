// 多源搜索协调器（P3）：筛可搜源 → 限流并发 → 增量合并 → 取消。
// 照上游 SearchBooksUseCase.kt:89-160 的三段口径：筛源 / flatMapMerge / 每完成一个就合并。
import { BookSource } from '@legado/sourceengine';
import { BookSourceRepository } from '../data/BookSourceRepository';
import { LegadoSourceMapper } from './LegadoSourceMapper';
import { BookSourceRuntime, SourceSearchResult } from './BookSourceRuntime';
import { SourceHttp } from './SourceHttp';
import { MergedBook, SearchResultMerger } from './SearchResultMerger';
import { SearchBookItem } from './SourceModels';

/** 单源完成后的进度，UI 用来做"边搜边出"与四态。 */
export interface SearchProgress {
  finished: number;   // 已完成源数
  total: number;      // 参与搜索的源总数
  sourceName: string;
  bookCount: number;
  error: string;
  books: MergedBook[]; // 当前合并快照，UI 用它做"边搜边出"
}

/** 搜索总结果。 */
export interface SearchOutcome {
  books: MergedBook[];
  sourceTotal: number;
  sourceFinished: number;
  cancelled: boolean;
}

export class SearchCoordinator {
  /** 并发上限：904 条源全并发会打爆模拟器网络栈，取 8（对齐任务书 7.2）。 */
  private static readonly CONCURRENCY: number = 8;

  /**
   * 多源并发搜索。onProgress 每完成一个源回调一次；shouldCancel 返回 true 时停止派发新源。
   * 已在飞行中的请求靠 AnalyzeUrl 的取消钩子收口（见 SourceHttp.newAnalyzer 的 setCancelCheck 扩展点）。
   */
  static async search(
    keyword: string, page: number, exactMatch: boolean,
    onProgress: (p: SearchProgress) => void,
    shouldCancel: () => boolean
  ): Promise<SearchOutcome> {
    const merger = new SearchResultMerger(keyword, exactMatch);
    const candidates: BookSource[] = SearchCoordinator.searchableSources();
    let finished = 0;
    // 取消钩子挂到引擎请求层：在途请求在限流队列/重试/重定向检查点立即退出，不等自然结束。
    SourceHttp.setCancelCheck(shouldCancel);

    // 固定并发窗口：用下标游标派发，避免一次 new 出 904 个 Promise。
    let next = 0;
    const worker = async (): Promise<void> => {
      while (true) {
        if (shouldCancel()) { return; }
        const index = next;
        next += 1;
        if (index >= candidates.length) { return; }
        const source = candidates[index];
        const result: SourceSearchResult = await BookSourceRuntime.searchOne(
          source.bookSourceUrl, keyword, page
        );
        if (!result.error) {
          for (const book of result.books) { merger.merge(book); }
        }
        finished += 1;
        onProgress({
          finished: finished, total: candidates.length, sourceName: result.sourceName,
          bookCount: result.books.length, error: result.error, books: merger.getSortedList()
        });
      }
    };

    const workerCount = Math.min(SearchCoordinator.CONCURRENCY, candidates.length);
    const workers: Promise<void>[] = [];
    for (let i = 0; i < workerCount; i++) { workers.push(worker()); }
    await Promise.all(workers);
    SourceHttp.clearCancelCheck();

    const cancelled = shouldCancel();
    return {
      books: merger.getSortedList(), sourceTotal: candidates.length,
      sourceFinished: finished, cancelled: cancelled
    };
  }

  /** 筛出可搜索源：启用 + 文本类型 + searchUrl 非空（对齐上游 :89-105）。 */
  private static searchableSources(): BookSource[] {
    const result: BookSource[] = [];
    const all = BookSourceRepository.getAll();
    for (const local of all) {
      if (!local.enabled || local.bookSourceType !== 0) { continue; }
      let source: BookSource | null = null;
      try {
        source = LegadoSourceMapper.fromLocal(local);
      } catch (_) {
        continue;
      }
      if (source !== null && source.searchUrl.length > 0) { result.push(source); }
    }
    return result;
  }

  /** 供"搜索在线书源"按钮判断是否有可用源。 */
  static hasSearchableSource(): boolean {
    return SearchCoordinator.searchableSources().length > 0;
  }
}
