// 多源搜索协调器（P3）：筛可搜源 → 限流并发 → 增量合并 → 取消。
// 照上游 SearchBooksUseCase.kt:89-207 的口径：筛源 / flatMapMerge / 每完成一个就合并 / 每源判 supportsNextPage。
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
  /** 本页任一源声明支持下一页（上游 `SourceSearchResult.Found.supportsNextPage`）。 */
  supportsNextPage: boolean;
  /** 合并层已到结果上限（上游 `merger.resultLimitReached`）。 */
  resultLimitReached: boolean;
}

/**
 * 搜索范围：对齐上游 `BookSearchScope` 在用例里的三个入参。
 *   - `groups`：分组名集合（空 = 不按分组限制）
 *   - `sourceUrls`：书源 URL 集合（非空 = 只搜这些源）
 *   - `types`：书源类型集合（空 = 不限类型；上游 `request.types`）
 */
export interface SearchScopeFilter {
  groups: string[];
  sourceUrls: string[];
  types: number[];
}

/** 空范围（等价上游 `isAll()`）。 */
export function emptySearchScopeFilter(): SearchScopeFilter {
  return { groups: [], sourceUrls: [], types: [] };
}

/** 单源搜索（展开书源面板用），对齐上游 `loadExpandedSourcePage`。 */
export interface SingleSourceOutcome {
  books: SearchBookItem[];
  error: string;
  supportsNextPage: boolean;
}

/** 上游 `SearchBooksUseCase.kt:393-398` 的三个分页正则。 */
const SEARCH_PAGE_SCRIPT_PATTERN: RegExp = /\{\{[\s\S]*?\}\}|<js>[\s\S]*?<\/js>|@js:[\s\S]*/i;
const SEARCH_PAGE_TOKEN_PATTERN: RegExp = /(?<![A-Za-z0-9_])page(?![A-Za-z0-9_])/;
const SEARCH_PAGE_GROUP_PATTERN: RegExp = /<[^<>]+>/;

export class SearchCoordinator {
  /** 并发上限：904 条源全并发会打爆模拟器网络栈，取 8（对齐任务书 7.2）。 */
  private static readonly CONCURRENCY: number = 8;

  /**
   * 上游 `BookSource.supportsSearchPage()`（SearchBooksUseCase.kt:381-391）：
   * `searchUrl` 非空，且「脚本段里出现独立的 page 记号」或「静态段里含 <...> 占位」。
   * 纯字符串判定，不发请求。
   */
  static supportsSearchPage(source: BookSource): boolean {
    const url = source.searchUrl ?? '';
    if (url.length === 0) { return false; }
    const scripts = url.match(new RegExp(SEARCH_PAGE_SCRIPT_PATTERN.source, 'gi'));
    if (scripts !== null) {
      for (const script of scripts) {
        if (SEARCH_PAGE_TOKEN_PATTERN.test(script)) { return true; }
      }
    }
    const staticUrl = url.replace(new RegExp(SEARCH_PAGE_SCRIPT_PATTERN.source, 'gi'), '');
    return SEARCH_PAGE_GROUP_PATTERN.test(staticUrl);
  }

  /**
   * 多源并发搜索。onProgress 每完成一个源回调一次；shouldCancel 返回 true 时停止派发新源。
   * 已在飞行中的请求靠 AnalyzeUrl 的取消钩子收口（见 SourceHttp.newAnalyzer 的 setCancelCheck 扩展点）。
   */
  static async search(
    keyword: string, page: number, exactMatch: boolean,
    scope: SearchScopeFilter,
    onProgress: (p: SearchProgress) => void,
    shouldCancel: () => boolean
  ): Promise<SearchOutcome> {
    const merger = new SearchResultMerger(keyword, exactMatch);
    const candidates: BookSource[] = SearchCoordinator.searchableSources(scope);
    let finished = 0;
    let supportsNextPage = false;
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
        // 上游 `:186-188`：第 2 页起，不支持翻页的源直接返回空结果，不再发请求。
        const pageSupported = SearchCoordinator.supportsSearchPage(source);
        if (page > 1 && !pageSupported) {
          finished += 1;
          onProgress({
            finished: finished, total: candidates.length, sourceName: source.bookSourceName,
            bookCount: 0, error: '', books: merger.getSortedList()
          });
          continue;
        }
        const result: SourceSearchResult = await BookSourceRuntime.searchOne(
          source.bookSourceUrl, keyword, page
        );
        if (!result.error) {
          for (const book of result.books) { merger.merge(book); }
          // 上游 `:129`：本页任一源「支持翻页且本页有结果」，就让 hasMore 保持为真。
          if (pageSupported && result.books.length > 0) { supportsNextPage = true; }
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
      sourceFinished: finished, cancelled: cancelled,
      supportsNextPage: supportsNextPage,
      // `MAX_RESULTS` 就是上游 `resultLimitReached` 的等价物。
      resultLimitReached: merger.count() >= SearchResultMerger.MAX_RESULTS
    };
  }

  /**
   * 单源搜索（展开书源面板）：只跑一个源，返回原始 `SearchBookItem` 列表。
   * 对齐上游 `SearchViewModel.loadExpandedSourcePage` 用 `exploreBooksUseCase` 单源取页的语义。
   */
  static async searchSingle(
    sourceUrl: string, keyword: string, page: number, _exactMatch: boolean
  ): Promise<SingleSourceOutcome> {
    const local = BookSourceRepository.getAll().find((item) => item.bookSourceUrl === sourceUrl);
    if (local === undefined || !local.enabled) {
      return { books: [], error: '书源不存在或未启用', supportsNextPage: false };
    }
    let source: BookSource | null = null;
    try {
      source = LegadoSourceMapper.fromLocal(local);
    } catch (error) {
      return {
        books: [], supportsNextPage: false,
        error: `书源解析失败：${error instanceof Error ? error.message : String(error)}`
      };
    }
    if (source === null) {
      return { books: [], error: '书源解析失败', supportsNextPage: false };
    }
    const pageSupported = SearchCoordinator.supportsSearchPage(source);
    if (page > 1 && !pageSupported) {
      return { books: [], error: '', supportsNextPage: false };
    }
    const result: SourceSearchResult = await BookSourceRuntime.searchOne(sourceUrl, keyword, page);
    return {
      books: result.books,
      error: result.error,
      supportsNextPage: pageSupported && result.books.length > 0
    };
  }

  /**
   * 筛出可搜索源：启用 + 文本类型 + searchUrl 非空（对齐上游 :89-105），
   * 再按范围收口——源 URL 集合非空时只留这些源，分组集合非空时只留组内源，
   * 类型集合非空时只留这些类型（上游 `request.types?.contains(source.bookSourceType)`）。
   */
  private static searchableSources(scope: SearchScopeFilter): BookSource[] {
    const result: BookSource[] = [];
    const all = BookSourceRepository.getAll();
    for (const local of all) {
      if (!local.enabled) { continue; }
      // 上游筛源不判类型为文本，类型过滤交给下面的 `scope.types`。
      if (scope.sourceUrls.length > 0 && !scope.sourceUrls.includes(local.bookSourceUrl)) { continue; }
      if (scope.groups.length > 0) {
        const group = local.bookSourceGroup ?? '';
        let hit = false;
        for (const name of scope.groups) {
          if (group === name) { hit = true; break; }
        }
        if (!hit) { continue; }
      }
      if (scope.types.length > 0 && !scope.types.includes(local.bookSourceType)) { continue; }
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

  /** 供"搜索在线书源"按钮判断是否有可用源（按范围收口后）。 */
  static hasSearchableSource(scope: SearchScopeFilter): boolean {
    return SearchCoordinator.searchableSources(scope).length > 0;
  }
}
