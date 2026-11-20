// 多源搜索协调器（P2 骨架，P3 填实）：并发搜索 + 结果合并。
import { SourceSearchResult } from './BookSourceRuntime';

export class SearchCoordinator {
  /**
   * P3 实现：并发查启用书源 → 每个源跑 BookSourceRuntime.searchOne → 增量合并。
   * 现在只保留签名，方法体抛异常以免被调用方误以为已可用。
   */
  static async search(_keyword: string, _page: number): Promise<SourceSearchResult[]> {
    throw new Error('P3 未实现：多源并发搜索');
  }
}
