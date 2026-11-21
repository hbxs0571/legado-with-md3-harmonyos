// 批3（r359）：自动刷新目录的待更新队列。
// 照上游 legado-with-MD3/.../ui/main/bookshelf/BookshelfViewModel.kt:1158-1300 的
// upAllBookToc / addToWaitUp / startUpTocJobLocked / markBookUpdateStarted /
// markBookUpdateFinished / finishUpTocJob / postUpBooksCount 搬过来：
//   - waitUp 与 onUp 两个 Set，同一个 bookUrl 不会重复排（上游两个 contains 判断）
//   - 一次最多跑 concurrency 本，单本失败不打断整批
//   - 计数 = waitUp.size + onUp.size，结束三空判定（waitUp/onUp 都空且 running 落回 false）
//   - 计数变化主动推给界面：上游走 UP_BOOKSHELF 事件 + postUpBooksCount，
//     本地用 AppStorage 键 tocPendingCount，书架标题用 @StorageLink 订阅
import { CacheSettingsRepository } from './CacheSettingsRepository';

/** 单本书的刷新动作。实现方负责自己记失败日志，不要抛出来打断整批。 */
export type TocRefreshHandler = (bookUrl: string) => Promise<void>;

export class TocRefreshQueue {
  /** 界面订阅这个 AppStorage 键，值变化即重算标题尾巴。 */
  static readonly PENDING_COUNT_KEY: string = 'tocPendingCount';

  /** 上游 AppConst.MAX_THREAD = 9。 */
  private static readonly MAX_CONCURRENCY: number = 9;

  private static waitUp: Set<string> = new Set<string>();
  private static onUp: Set<string> = new Set<string>();
  private static handler: TocRefreshHandler | undefined = undefined;
  private static running: boolean = false;
  /** 取消代数：cancel 后正在跑的循环看到代数变了就收工，不再写库。 */
  private static generation: number = 0;

  /**
   * 并发数：上游 `Math.min(9, CacheSettingsRepository.get().updateSearchThreads)`。
   * updateSearchThreads 对应上游「缓存/导出并发 threadCount」，不是下载线程数。
   */
  static concurrency(): number {
    const configured = CacheSettingsRepository.get().updateSearchThreads;
    const usable = Number.isFinite(configured) ? Math.floor(configured) : 1;
    return Math.min(TocRefreshQueue.MAX_CONCURRENCY, Math.max(1, usable));
  }

  /**
   * 排队。已在排或正在刷的 url 直接跳过（上游 addToWaitUp 的两个 contains 判断）。
   * handler 每次 add 都覆盖成最新的那个——同一轮里所有书用同一份刷新实现。
   */
  static add(urls: string[], handler: TocRefreshHandler): void {
    TocRefreshQueue.handler = handler;
    let added = 0;
    for (const url of urls) {
      if (url.length === 0) { continue; }
      if (TocRefreshQueue.waitUp.has(url) || TocRefreshQueue.onUp.has(url)) { continue; }
      TocRefreshQueue.waitUp.add(url);
      added += 1;
    }
    TocRefreshQueue.publish();
    if (added > 0 && !TocRefreshQueue.running) {
      TocRefreshQueue.launch();
    }
  }

  /** 上游 postUpBooksCount：waitUp.size + onUp.size。 */
  static pendingCount(): number {
    return TocRefreshQueue.waitUp.size + TocRefreshQueue.onUp.size;
  }

  static isRunning(): boolean {
    return TocRefreshQueue.running;
  }

  /** 清空队列与计数（换账号/退出登录、或测试用）。正在跑的那一轮会在下一批前停下。 */
  static cancel(): void {
    TocRefreshQueue.generation += 1;
    TocRefreshQueue.waitUp.clear();
    TocRefreshQueue.onUp.clear();
    TocRefreshQueue.running = false;
    TocRefreshQueue.publish();
  }

  private static publish(): void {
    AppStorage.setOrCreate(TocRefreshQueue.PENDING_COUNT_KEY, TocRefreshQueue.pendingCount());
  }

  private static launch(): void {
    TocRefreshQueue.start().then(() => {}, () => {});
  }

  /** 一批一批地跑，每批最多 concurrency 本；跑完再看队列里有没有新排进来的。 */
  private static async start(): Promise<void> {
    if (TocRefreshQueue.running) { return; }
    TocRefreshQueue.running = true;
    const gen = TocRefreshQueue.generation;
    try {
      while (gen === TocRefreshQueue.generation && TocRefreshQueue.waitUp.size > 0) {
        const limit = TocRefreshQueue.concurrency();
        const batch: string[] = [];
        TocRefreshQueue.waitUp.forEach((url: string) => {
          if (batch.length < limit) { batch.push(url); }
        });
        for (const url of batch) {
          TocRefreshQueue.waitUp.delete(url);
          TocRefreshQueue.onUp.add(url);
        }
        TocRefreshQueue.publish();
        const handler = TocRefreshQueue.handler;
        const tasks: Promise<void>[] = [];
        for (const url of batch) {
          const running: Promise<void> = handler === undefined ? Promise.resolve() : handler(url);
          // 单本失败不打断整批：这里把 rejection 就地吃掉再交给 Promise.all 等齐，
          // 语义等价上游 onEachParallel + allSettled（失败日志由 handler 自己记）。
          // 不用 Promise.allSettled 是因为 ArkTS 的 lib 目标不保证有它。
          tasks.push(running.then(() => {
            TocRefreshQueue.markFinished(url);
          }, () => {
            TocRefreshQueue.markFinished(url);
          }));
        }
        await Promise.all(tasks);
        TocRefreshQueue.publish();
      }
    } finally {
      TocRefreshQueue.running = false;
      TocRefreshQueue.publish();
      // 上游 finishUpTocJob：本轮结束时若又有书排进来，重启一轮（restarted=true）。
      if (gen === TocRefreshQueue.generation && TocRefreshQueue.waitUp.size > 0) {
        TocRefreshQueue.launch();
      }
    }
  }

  /** 上游 markBookUpdateFinished：从 onUp 拿掉并重新播报计数。 */
  private static markFinished(url: string): void {
    TocRefreshQueue.onUp.delete(url);
    TocRefreshQueue.publish();
  }
}