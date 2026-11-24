// 换封面协调器（第五表 H2-1）：按书名并发搜全部启用书源，收集能直接用作封面的 coverUrl。
// 口径对齐上游 `ui/book/changecover/ChangeCoverViewModel.kt`：
//   1. `search(source)` 先判 `source.getSearchRule().coverUrl.isNullOrBlank()` → 无封面规则的源直接跳过；
//   2. **搜索关键词只有书名**（上游 `:155-157 WebBook.searchBookAwait(source, name, shouldBreak = { it > 0 })`），
//      作者只用于事后比对，不拼进关键词；
//   3. 搜到第一本后要求 `searchBook.name == name && searchBook.author == author && coverUrl 非空` 才收；
//   4. 单源 `withTimeout(60000L)`（上游 `:139`），超时按无结果处理，不让一个慢源拖死整轮；
//   5. 列表首项永远是「默认封面」（coverUrl = 'use_default_cover'），由页面按该项还原内置封面；
//   6. 并发度对齐上游 `threadCount`（本仓固定 8，与 ChangeSourceCoordinator 同口径）。
// 与 ChangeSourceCoordinator 的区别：换源要校验目录，换封面只要封面 URL，故不取目录、不做校验。
import { BookSourceRepository } from '../data/BookSourceRepository';
import { LegadoSourceMapper } from './LegadoSourceMapper';
import { WebBookService } from './WebBookService';
import { SearchBookItem } from './SourceModels';
import { AppLog } from '../lib/AppLog';

/** 默认封面项的 coverUrl 哨兵值，对齐上游 `ChangeCoverViewModel.defaultCover`。 */
export const CHANGE_COVER_DEFAULT_URL: string = 'use_default_cover';

/** 默认封面项的显示名，对齐上游 `originName = "默认封面"`。 */
export const CHANGE_COVER_DEFAULT_NAME: string = '默认封面';

/** 单源搜索超时，对齐上游 `ChangeCoverViewModel.kt:139 withTimeout(60000L)`。 */
const PROBE_TIMEOUT_MS: number = 60000;

/** 一条换封面候选。 */
export interface ChangeCoverCandidate {
  /** 封面地址；默认封面项是 CHANGE_COVER_DEFAULT_URL。 */
  coverUrl: string;
  /** 来源名（默认封面项固定「默认封面」）。 */
  originName: string;
  /** 来源 bookSourceUrl；默认封面项为空串。 */
  sourceUrl: string;
}

/**
 * 一轮搜索的失败原因计数（诊断用）。
 *
 * 903 个源逐个写日志会把 AppLog 的 100 条上限冲爆，改成计数后只在收尾写一条汇总，
 * 既能看出「卡在哪一步」，又不影响正常日志。
 */
class ChangeCoverStats {
  noRule: number = 0;
  searchError: number = 0;
  emptyResult: number = 0;
  authorMismatch: number = 0;
  noCover: number = 0;
}

export class ChangeCoverCoordinator {
  /**
   * 搜换封面候选。`author` 必须已去掉「作者：」前缀（与上游 `initData` 一致）。
   *
   * **流式回填**：上游 `ChangeCoverViewModel.kt:65-72` 的 `searchSuccess` 每收到一本书就
   * `trySend(defaultCover + searchBooks.sortedBy { originOrder })`，界面立刻长出一项；
   * 本地书源动辄数百个，等全部跑完再一次性返回要几分钟，表现就是「一直正在搜索封面…」。
   * 所以这里每命中一个就通过 `onFound` 推给界面。
   *
   * `onFound` 收到的是**完整候选列表**（默认封面 + 目前已找到的全部），
   * 与上游 `trySend` 的载荷形状一致，调用方直接整体替换即可。
   */
  static async searchCovers(
    name: string,
    author: string,
    onFound?: (candidates: ChangeCoverCandidate[]) => void
  ): Promise<ChangeCoverCandidate[]> {
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

    const found: ChangeCoverCandidate[] = [];
    let cursor = 0;
    // 诊断计数：AppLog 只留 100 条，903 个源必须聚合成少数几条才有观测价值。
    const stats = new ChangeCoverStats();
    const worker = async (): Promise<void> => {
      while (cursor < targetSources.length) {
        const idx = cursor++;
        const src = targetSources[idx];
        const hit = await ChangeCoverCoordinator.probeCover(
          src.bookSourceUrl, src.bookSourceName, src.sourceJson, name, author, stats
        );
        if (hit !== null) {
          found.push(hit);
          // 上游 `searchSuccess` 的等价物：命中一个就整份推一次。
          if (onFound !== undefined) { onFound(result.concat(found)); }
        }
      }
    };
    const workers: Promise<void>[] = [];
    for (let i = 0; i < 8 && i < targetSources.length; i++) { workers.push(worker()); }
    await Promise.all(workers);
    for (const item of found) { result.push(item); }
    AppLog.put(`封面换源汇总《${name}》/「${author}」 源${targetSources.length} 无封面规则${stats.noRule} 搜索异常${stats.searchError} 零结果${stats.emptyResult} 作者不符${stats.authorMismatch} 封面空${stats.noCover} 命中${found.length}`);
    return result;
  }

  /**
   * 单源探测：无封面规则直接跳过；搜到后校验书名 + 作者 + coverUrl。
   *
   * 关键词只传书名：上游 `:155-157` 是 `WebBook.searchBookAwait(source, name, ...)`，
   * 作者仅用于 `:158` 的结果比对。拼成「书名 作者」会让绝大多数书源搜不到东西
   * （它们的搜索接口按整串匹配书名），表现就是「一直正在搜索封面…最后只剩默认封面」。
   */
  private static async probeCover(
    sourceUrl: string, sourceName: string, sourceJson: string,
    name: string, author: string, stats: ChangeCoverStats
  ): Promise<ChangeCoverCandidate | null> {
    try {
      const source = LegadoSourceMapper.fromSourceJson(sourceJson);
      // 上游判据：没有封面规则的书源不可能给出封面，直接跳过（避免白跑一次网络请求）。
      if (!source.searchRule.coverUrl || source.searchRule.coverUrl.length === 0) {
        stats.noRule += 1;
        return null;
      }
      const books: SearchBookItem[] = await ChangeCoverCoordinator.withTimeout(
        WebBookService.searchBook(source, name, 1), PROBE_TIMEOUT_MS
      );
      if (books.length === 0) {
        stats.emptyResult += 1;
        return null;
      }
      const first = books[0];
      // 上游 `search(source)` 的三个必要条件：书名一致、作者一致、封面非空。
      if (first.name !== name || first.author !== author) {
        stats.authorMismatch += 1;
        ChangeCoverCoordinator.diag(`作者/书名不符 ${sourceName}：期望「${name}」/「${author}」 实得「${first.name}」/「${first.author}」`);
        return null;
      }
      if (first.coverUrl.length === 0) {
        stats.noCover += 1;
        ChangeCoverCoordinator.diag(`封面为空 ${sourceName}：搜到《${first.name}》`);
        return null;
      }
      ChangeCoverCoordinator.diag(`命中 ${sourceName}：${first.coverUrl}`);
      return { coverUrl: first.coverUrl, originName: sourceName, sourceUrl: sourceUrl };
    } catch (error) {
      stats.searchError += 1;
      ChangeCoverCoordinator.diag(`搜索异常 ${sourceName}：${error instanceof Error ? error.message : String(error)}`);
      return null;
    }
  }

  /** 诊断日志计数：AppLog 只留 100 条，903 个源会把有用信息冲掉，故只记前若干条。 */
  private static diagCount: number = 0;

  /**
   * 诊断日志：只在计数未超限时写 AppLog，避免刷屏冲掉其它日志。
   *
   * 用 AppLog 而不是 hilog —— 本工程全程不用 hilog（只有注释提到），
   * 而 AppLog 在详情页的「日志」面板里能直接看到，是唯一可上机观测的通道。
   */
  private static diag(message: string): void {
    if (ChangeCoverCoordinator.diagCount >= 30) { return; }
    ChangeCoverCoordinator.diagCount += 1;
    AppLog.put(`封面换源#${ChangeCoverCoordinator.diagCount} ${message}`);
  }

  /**
   * 给单个书源的搜索套一层超时。
   *
   * 上游 `:139 withTimeout(60000L)` 到点抛 `TimeoutCancellationException`，被外层
   * `:145 catch` 吃掉；ArkTS 没有协程取消，用 `Promise.race` 复刻同一语义：
   * 到点按「这一源没结果」返回空数组，在途请求自行结束。
   */
  private static withTimeout<T>(task: Promise<T>, timeoutMs: number): Promise<T> {
    return new Promise<T>((resolve: (value: T) => void, reject: (reason: Error) => void) => {
      let settled: boolean = false;
      const timer: number = setTimeout(() => {
        if (settled) { return; }
        settled = true;
        // 与上游一致：超时按「这一源没有结果」处理，不当作整轮失败。
        reject(new Error('timeout'));
      }, timeoutMs);
      task.then((value: T) => {
        if (settled) { return; }
        settled = true;
        clearTimeout(timer);
        resolve(value);
      }).catch((error: Error) => {
        if (settled) { return; }
        settled = true;
        clearTimeout(timer);
        reject(error);
      });
    });
  }
}
