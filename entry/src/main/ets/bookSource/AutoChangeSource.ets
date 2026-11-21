// 批10（:527）：自动换源。
// 对齐上游 legado-with-MD3/.../ui/book/read/ReadBookLoadDelegate.kt:400-442 autoChangeSource：
//   ① 开关 autoChangeSource 关闭时直接返回（由调用方判，本类只管找源）；
//   ② 全源并发（并发数取「搜索并发」设置，上限 9，同 TocRefreshQueue）跑精确搜索；
//   ③ 精确匹配口径照上游 WebBook.kt:484 的 `fName == name && fAuthor == author`，
//      关键词只用书名（上游 searchBookAwait(bookSource, name, filter=...) 不带作者）；
//   ④ 候选命中后：tocUrl 空则取详情补；取目录；取第 1 章正文做连通性验证（上游取
//      `toc.getOrElse(book.durChapterIndex)`，搜索转出来的 Book 该值恒为 0，即第 1 章）；
//   ⑤ 第一个跑通整套流程的源胜出（上游 mapParallelSafe + take(1)），其余丢弃；
//   ⑥ 全部失败给出原因汇总，调用方 toast「自动换源失败」。
// 上游在这条链上**没有确认弹窗**，换过去时照迁阅读进度（changeTo(options) 带迁移），
// 任务书 :3520 要求「必须弹确认」与上游冲突，按工作区长期口径对齐上游，改判写进提交信息。
import { BookSourceRepository } from '../data/BookSourceRepository';
import { CacheSettingsRepository } from '../data/CacheSettingsRepository';
import { BookSourceRuntime } from './BookSourceRuntime';
import { ChangeSourceCandidate } from './ChangeSourceCoordinator';
import { SearchBookItem, RemoteChapter } from './SourceModels';

/** 自动换源结果。candidate 为 null 表示没找到可用书源，reason 给出汇总原因。 */
export interface AutoChangeSourceOutcome {
  candidate: ChangeSourceCandidate | null;
  reason: string;
}

export class AutoChangeSource {
  /** 上游 AppConst.MAX_THREAD = 9；本地取「搜索并发」设置（对应上游 threadCount）。 */
  private static readonly MAX_CONCURRENCY: number = 9;

  static concurrency(): number {
    const configured = CacheSettingsRepository.get().updateSearchThreads;
    const usable = Number.isFinite(configured) ? Math.floor(configured) : 1;
    return Math.min(AutoChangeSource.MAX_CONCURRENCY, Math.max(1, usable));
  }

  /**
   * 找第一个可用的换源目标。并发探测，谁先跑通整套流程谁胜出（上游 take(1) 语义）。
   * 不做取消：调用方是开书流程，这本书读完这一轮就够了，继续跑的探测器结果被丢弃。
   */
  static async find(title: string, author: string): Promise<AutoChangeSourceOutcome> {
    const all = BookSourceRepository.getAll();
    const sources: string[] = [];
    const names: string[] = [];
    for (const source of all) {
      if (!source.enabled) { continue; }
      if (source.bookSourceType !== 0) { continue; }
      if (source.bookSourceUrl.length === 0) { continue; }
      sources.push(source.bookSourceUrl);
      names.push(source.bookSourceName);
    }
    if (sources.length === 0) {
      return { candidate: null, reason: '没有启用的文本书源' };
    }
    const total = sources.length;
    // 失败原因按源记一行，够定位就行（上游只把最后一次异常放进 toast）。
    const reasons: string[] = [];
    return new Promise<AutoChangeSourceOutcome>((resolve: (value: AutoChangeSourceOutcome) => void) => {
      let cursor = 0;
      let probed = 0;
      let settled = false;
      const finish = (outcome: AutoChangeSourceOutcome): void => {
        if (settled) { return; }
        settled = true;
        resolve(outcome);
      };
      const worker = async (): Promise<void> => {
        while (!settled && cursor < total) {
          const index = cursor++;
          const sourceUrl = sources[index];
          const sourceName = names[index];
          try {
            const candidate = await AutoChangeSource.probe(sourceUrl, sourceName, title, author);
            if (candidate !== null) {
              finish({ candidate: candidate, reason: '' });
              return;
            }
            reasons.push(`${sourceName}：没搜到完全同名的书或目录/正文不可用`);
          } catch (e) {
            reasons.push(`${sourceName}：${e instanceof Error ? e.message : String(e)}`);
          }
          probed += 1;
          if (!settled && probed >= total) {
            finish({ candidate: null, reason: reasons.join('；') });
            return;
          }
        }
      };
      const workers: Promise<void>[] = [];
      const window = Math.min(AutoChangeSource.concurrency(), total);
      for (let i = 0; i < window; i++) { workers.push(worker()); }
      Promise.all(workers).then(() => {
        // 兜底：worker 因 settled 提前退出时上面已经 resolve 过，这里只处理异常情况。
        if (!settled) { finish({ candidate: null, reason: reasons.join('；') }); }
      }, (e: Error) => {
        finish({ candidate: null, reason: e.message });
      });
    });
  }

  /**
   * 单源探测：精确搜索 → 补 tocUrl → 取目录 → 取第 1 章正文验证。
   * 任一步不通过返回 null（照上游：拿不到就换下一个源，不重试）。
   */
  private static async probe(
    sourceUrl: string, sourceName: string, title: string, author: string
  ): Promise<ChangeSourceCandidate | null> {
    const search = await BookSourceRuntime.searchOne(sourceUrl, title, 1);
    if (search.error.length > 0 || search.books.length === 0) { return null; }
    let matched: SearchBookItem | null = null;
    for (const item of search.books) {
      if (item.name === title && item.author === author) {
        matched = item;
        break;
      }
    }
    if (matched === null) { return null; }
    let tocUrl = matched.tocUrl;
    if (tocUrl.length === 0) {
      const detail = await BookSourceRuntime.detail(sourceUrl, matched.bookUrl);
      tocUrl = detail.tocUrl.length > 0 ? detail.tocUrl : matched.bookUrl;
    }
    const chapters: RemoteChapter[] = await BookSourceRuntime.toc(sourceUrl, matched.bookUrl, tocUrl);
    if (chapters.length === 0) { return null; }
    const first = chapters[0];
    if (first === undefined) { return null; }
    // 正文验证：上游 getContentAwait 抛异常才算失败，正文为空串照过（不少源首章就是版权声明）。
    await BookSourceRuntime.content(sourceUrl, first.url);
    return {
      sourceUrl: sourceUrl,
      sourceName: sourceName,
      book: matched,
      chapters: chapters,
      chapterCount: chapters.length,
      verified: true,
      message: ''
    };
  }
}
