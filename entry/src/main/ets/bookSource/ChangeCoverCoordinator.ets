// 换封面协调器（第五表 H2-1）：按书名 + 作者并发搜全部启用书源，收集能直接用作封面的 coverUrl。
// 口径对齐上游 `ui/book/info/ChangeCoverViewModel.kt`：
//   1. `search(source)` 先判 `source.getSearchRule().coverUrl.isNullOrBlank()` → 无封面规则的源直接跳过；
//   2. 搜到第一本后要求 `searchBook.name == name && searchBook.author == author && coverUrl 非空` 才收；
//   3. 列表首项永远是「默认封面」（coverUrl = 'use_default_cover'），由页面按该项还原内置封面；
//   4. 并发度对齐上游 `threadCount`（本仓固定 8，与 ChangeSourceCoordinator 同口径）。
// 与 ChangeSourceCoordinator 的区别：换源要校验目录，换封面只要封面 URL，故不取目录、不做校验。
import { BookSourceRepository } from '../data/BookSourceRepository';
import { LegadoSourceMapper } from './LegadoSourceMapper';
import { WebBookService } from './WebBookService';
import { SearchBookItem } from './SourceModels';

/** 默认封面项的 coverUrl 哨兵值，对齐上游 `ChangeCoverViewModel.defaultCover`。 */
export const CHANGE_COVER_DEFAULT_URL: string = 'use_default_cover';

/** 默认封面项的显示名，对齐上游 `originName = "默认封面"`。 */
export const CHANGE_COVER_DEFAULT_NAME: string = '默认封面';

/** 一条换封面候选。 */
export interface ChangeCoverCandidate {
  /** 封面地址；默认封面项是 CHANGE_COVER_DEFAULT_URL。 */
  coverUrl: string;
  /** 来源名（默认封面项固定「默认封面」）。 */
  originName: string;
  /** 来源 bookSourceUrl；默认封面项为空串。 */
  sourceUrl: string;
}

export class ChangeCoverCoordinator {
  /**
   * 搜换封面候选。`author` 必须已去掉「作者：」前缀（与上游 `initData` 一致）。
   * 返回顺序：默认封面在前，其余按书源 customOrder 出现顺序追加。
   */
  static async searchCovers(name: string, author: string): Promise<ChangeCoverCandidate[]> {
    const result: ChangeCoverCandidate[] = [];
    result.push({
      coverUrl: CHANGE_COVER_DEFAULT_URL,
      originName: CHANGE_COVER_DEFAULT_NAME,
      sourceUrl: ''
    });
    if (name.length === 0) { return result; }

    const all = BookSourceRepository.getAll();
    const targetSources = all.filter((s) => s.enabled && s.bookSourceType === 0 && s.bookSourceUrl.length > 0);
    targetSources.sort((a, b) => a.customOrder - b.customOrder);

    const keyword = author.length > 0 ? `${name} ${author}` : name;
    const found: ChangeCoverCandidate[] = [];
    let cursor = 0;
    const worker = async (): Promise<void> => {
      while (cursor < targetSources.length) {
        const idx = cursor++;
        const src = targetSources[idx];
        const hit = await ChangeCoverCoordinator.probeCover(
          src.bookSourceUrl, src.bookSourceName, src.sourceJson, name, author, keyword
        );
        if (hit !== null) { found.push(hit); }
      }
    };
    const workers: Promise<void>[] = [];
    for (let i = 0; i < 8 && i < targetSources.length; i++) { workers.push(worker()); }
    await Promise.all(workers);
    for (const item of found) { result.push(item); }
    return result;
  }

  /** 单源探测：无封面规则直接跳过；搜到后校验书名 + 作者 + coverUrl。 */
  private static async probeCover(
    sourceUrl: string, sourceName: string, sourceJson: string,
    name: string, author: string, keyword: string
  ): Promise<ChangeCoverCandidate | null> {
    try {
      const source = LegadoSourceMapper.fromSourceJson(sourceJson);
      // 上游判据：没有封面规则的书源不可能给出封面，直接跳过（避免白跑一次网络请求）。
      if (!source.searchRule.coverUrl || source.searchRule.coverUrl.length === 0) { return null; }
      const books: SearchBookItem[] = await WebBookService.searchBook(source, keyword, 1);
      if (books.length === 0) { return null; }
      const first = books[0];
      // 上游 `search(source)` 的三个必要条件：书名一致、作者一致、封面非空。
      if (first.name !== name || first.author !== author) { return null; }
      if (first.coverUrl.length === 0) { return null; }
      return { coverUrl: first.coverUrl, originName: sourceName, sourceUrl: sourceUrl };
    } catch (_) {
      return null;
    }
  }
}
