// 章节下载队列（批2 前置，:455 :457 :459 :466 :145 :439 :441 :442 :443 :445 :446）。
//
// 为什么放 bookSource/ 不放 data/：它只依赖 OnlineBookProvider（接口在 data/，实现是本目录的
// OnlineBookService）与 model/Book，与提供器同层；放 data/ 会形成 data ← bookSource 的反向依赖。
//
// 职责边界（任务书批2 明确的三条，别越界）：
// 1. 只负责「驱动」与「记账」：取正文、落缓存都在 OnlineBookService.getContent 里完成，
//    队列**不再写一次缓存**，否则双写。
// 2. 串行执行，并发恒为 1。上游有 concurrentRate 概念，本地书源还没接并发控制，
//    真并发只会打爆对方站点，本批不做。
// 3. 失败不重试：标 failed 继续下一章（重试是另一件事）。
//
// 关于「停止后不再写缓存」的真实保证（诚实口径）：队列在每次开始新章节前判停止；
// 被停掉的队列不会再取下一章。正在抓取的那一章已经发出请求，本批无法做请求级取消
//（上游靠协程 cancel，本地 rcp 请求没有取消通道），它落盘取决于停止请求是否早于开抓 ——
// 停止早于开抓时以 allowCache=false 调用，provider 会跳过第 ③ 步写盘。

import { Book, BookChapter } from '../model/Book';
import { OnlineBookProvider } from '../data/OnlineBookProvider';

export type DownloadState = 'idle' | 'queued' | 'running' | 'paused' | 'done' | 'failed';

export interface DownloadTask {
  bookUrl: string;
  chapterIndex: number;
  state: DownloadState;
  error?: string;
}

export interface DownloadSnapshot {
  total: number;
  done: number;
  running: number;
  failed: number;
  paused: boolean;
}

type DownloadListener = (snapshot: DownloadSnapshot) => void;

/** 任务键：bookUrl + '#' + index，避免不同书的同名章号撞在一起。 */
function taskKey(bookUrl: string, chapterIndex: number): string {
  return `${bookUrl}#${chapterIndex}`;
}

export class ChapterDownloadQueue {
  private static provider: OnlineBookProvider | undefined = undefined;
  /** 待跑任务，先进先出；单本与多本混排，顺序即入队顺序。 */
  private static pending: DownloadTask[] = [];
  /** 状态表：键 taskKey，值是每次入队/开跑时新建的 DownloadTask（界面读它）。 */
  private static tasks: Map<string, DownloadTask> = new Map<string, DownloadTask>();
  /** 入队时记下 Book 与 BookChapter，出队跑的时候要传给提供器。 */
  private static books: Map<string, Book> = new Map<string, Book>();
  private static chapters: Map<string, BookChapter> = new Map<string, BookChapter>();
  private static listeners: DownloadListener[] = [];
  /** 已暂停的书（bookUrl 集合）。暂停的任务留在 pending 里等着，回来接着跑。 */
  private static pausedBooks: Set<string> = new Set<string>();
  /** 被停止的书；空串表示没停（全局停止时清空 pending，靠这个集合挡住「同一 tick 内又入队」）。 */
  private static stoppedBooks: Set<string> = new Set<string>();
  private static looping: boolean = false;

  /** 安装提供器。EntryAbility.onCreate 里与 BookRepository.installOnlineProvider 用同一个实例。 */
  static install(provider: OnlineBookProvider): void {
    ChapterDownloadQueue.provider = provider;
  }

  /**
   * 入队一批章节。已缓存的不入队（「下载全部」只下没下过的），
   * 已在队里的不重复入队（同章点两次不会跑两遍）。
   */
  static enqueue(book: Book, chapters: BookChapter[]): void {
    const provider = ChapterDownloadQueue.provider;
    if (provider === undefined) {
      return;
    }
    const bookUrl = ChapterDownloadQueue.bookKey(book);
    if (bookUrl.length === 0) {
      return;
    }
    // 重新入队即视为「这本书要跑」，把先前的停止/暂停标记摘掉。
    ChapterDownloadQueue.stoppedBooks.delete(bookUrl);
    ChapterDownloadQueue.pausedBooks.delete(bookUrl);
    let added = 0;
    for (let index = 0; index < chapters.length; index++) {
      const chapter = chapters[index];
      const key = taskKey(bookUrl, chapter.index);
      const existing = ChapterDownloadQueue.tasks.get(key);
      if (existing !== undefined) {
        // 之前停过或失败过的章：重新入队要把它们放回待跑队列，否则「停止后接着下」永远醒不过来。
        if (existing.state === 'paused' || existing.state === 'failed') {
          existing.state = 'queued';
          existing.error = undefined;
          ChapterDownloadQueue.books.set(bookUrl, book);
          ChapterDownloadQueue.chapters.set(key, chapter);
          ChapterDownloadQueue.pending.push(existing);
          added++;
        }
        continue;
      }
      if (provider.isChapterCached(book, chapter)) {
        // 已经下过：直接记 done，让界面一进来就显示对勾，而不是「未下载」。
        const cached: DownloadTask = { bookUrl: bookUrl, chapterIndex: chapter.index, state: 'done' };
        ChapterDownloadQueue.tasks.set(key, cached);
        continue;
      }
      const task: DownloadTask = { bookUrl: bookUrl, chapterIndex: chapter.index, state: 'queued' };
      ChapterDownloadQueue.tasks.set(key, task);
      ChapterDownloadQueue.books.set(bookUrl, book);
      ChapterDownloadQueue.chapters.set(key, chapter);
      ChapterDownloadQueue.pending.push(task);
      added++;
    }
    ChapterDownloadQueue.publish();
    if (added > 0) {
      ChapterDownloadQueue.run();
    }
  }

  /** 暂停一本书（任务留在队列里，resume 或再次 enqueue 能接着跑）。 */
  static pause(bookUrl: string): void {
    ChapterDownloadQueue.pausedBooks.add(bookUrl);
    const tasks = ChapterDownloadQueue.tasks;
    tasks.forEach((task: DownloadTask) => {
      if (task.bookUrl === bookUrl && task.state === 'queued') {
        task.state = 'paused';
      }
    });
    ChapterDownloadQueue.publish();
  }

  /**
   * 停止下载（不删已下载的缓存文件），等价于「不再往下跑」而不是丢弃进度。
   * 传 bookUrl 只停那一本，不传停全部。
   */
  static stop(bookUrl?: string): void {
    const target = bookUrl === undefined ? '' : bookUrl;
    if (target.length === 0) {
      ChapterDownloadQueue.pending = [];
      ChapterDownloadQueue.tasks.clear();
      ChapterDownloadQueue.chapters.clear();
      ChapterDownloadQueue.books.clear();
      ChapterDownloadQueue.pausedBooks.clear();
      ChapterDownloadQueue.stoppedBooks.clear();
      ChapterDownloadQueue.publish();
      return;
    }
    // 单书停止：保留任务表，把还没开抓的章标成「已暂停」，界面因此显示已暂停、
    // 再点一次「下载」能接着下；正在抓的那一章按 allowCache=false 落不了盘。
    ChapterDownloadQueue.pending = ChapterDownloadQueue.pending.filter((task: DownloadTask) => {
      if (task.bookUrl !== target) {
        return true;
      }
      task.state = 'paused';
      return false;
    });
    ChapterDownloadQueue.stoppedBooks.add(target);
    ChapterDownloadQueue.pausedBooks.add(target);
    ChapterDownloadQueue.publish();
  }

  /** 订阅快照变化，返回取消订阅函数；页面 aboutToDisappear 必须调它。 */
  static subscribe(listener: DownloadListener): () => void {
    ChapterDownloadQueue.listeners.push(listener);
    listener(ChapterDownloadQueue.snapshot(''));
    return () => {
      ChapterDownloadQueue.listeners = ChapterDownloadQueue.listeners.filter((item: DownloadListener) => item !== listener);
    };
  }

  /** 某本书的进度快照；传空串是全书汇总。 */
  static snapshot(bookUrl: string): DownloadSnapshot {
    const target = bookUrl;
    let total = 0;
    let done = 0;
    let running = 0;
    let failed = 0;
    ChapterDownloadQueue.tasks.forEach((task: DownloadTask) => {
      if (target.length > 0 && task.bookUrl !== target) {
        return;
      }
      total++;
      if (task.state === 'done') {
        done++;
      } else if (task.state === 'running') {
        running++;
      } else if (task.state === 'failed') {
        failed++;
      }
    });
    return {
      total: total,
      done: done,
      running: running,
      failed: failed,
      paused: target.length > 0 ? ChapterDownloadQueue.pausedBooks.has(target) : false
    };
  }

  /** 单章状态（章节行图标、缓存页六档都用它，不许各页自己另建一份）。 */
  static chapterState(bookUrl: string, chapterIndex: number): DownloadState {
    const task = ChapterDownloadQueue.tasks.get(taskKey(bookUrl, chapterIndex));
    return task === undefined ? 'idle' : task.state;
  }

  /** 该书是否还有排队/在跑的任务（书架卡片「下载中」状态用）。 */
  static isBookDownloading(bookUrl: string): boolean {
    const snapshot = ChapterDownloadQueue.snapshot(bookUrl);
    if (snapshot.paused) {
      return false;
    }
    return snapshot.running > 0 || snapshot.done + snapshot.failed < snapshot.total;
  }

  /** 队列长度（排着 + 在跑），界面上要显示「等待下载 N」时用它。 */
  static pendingCount(): number {
    return ChapterDownloadQueue.pending.length;
  }

  /** 清空所有记账（换账号/测试用，不删磁盘缓存）。 */
  static reset(): void {
    ChapterDownloadQueue.pending = [];
    ChapterDownloadQueue.tasks.clear();
    ChapterDownloadQueue.books.clear();
    ChapterDownloadQueue.chapters.clear();
    ChapterDownloadQueue.pausedBooks.clear();
    ChapterDownloadQueue.stoppedBooks.clear();
    ChapterDownloadQueue.publish();
  }

  /** 串行主循环：一次取一个任务跑，跑完再取下一个。 */
  private static run(): void {
    if (ChapterDownloadQueue.looping) {
      return;
    }
    ChapterDownloadQueue.looping = true;
    ChapterDownloadQueue.step();
  }

  private static step(): void {
    const provider = ChapterDownloadQueue.provider;
    if (provider === undefined) {
      ChapterDownloadQueue.looping = false;
      return;
    }
    const task = ChapterDownloadQueue.takeNextRunnable();
    if (task === undefined) {
      ChapterDownloadQueue.looping = false;
      ChapterDownloadQueue.publish();
      return;
    }
    const key = taskKey(task.bookUrl, task.chapterIndex);
    const book = ChapterDownloadQueue.books.get(task.bookUrl);
    const chapter = ChapterDownloadQueue.chapters.get(key);
    if (book === undefined || chapter === undefined) {
      ChapterDownloadQueue.tasks.delete(key);
      ChapterDownloadQueue.chapters.delete(key);
      ChapterDownloadQueue.step();
      return;
    }
    task.state = 'running';
    ChapterDownloadQueue.publish();
    // 停止请求早于开抓时不允许落盘（见文件头的诚实口径）。
    const allowCache = !ChapterDownloadQueue.stoppedBooks.has(task.bookUrl);
    provider.getContent(book, chapter, allowCache).then(() => {
      task.state = 'done';
      ChapterDownloadQueue.publish();
      ChapterDownloadQueue.step();
    }).catch((error: Error) => {
      // 失败不重试，标 failed 继续下一章。
      task.state = 'failed';
      task.error = error.message;
      ChapterDownloadQueue.publish();
      ChapterDownloadQueue.step();
    });
  }

  /** 取下一个可跑的任务：跳过被暂停的书；被停止的书任务已被清掉。 */
  private static takeNextRunnable(): DownloadTask | undefined {
    const pending = ChapterDownloadQueue.pending;
    for (let index = 0; index < pending.length; index++) {
      const task = pending[index];
      if (ChapterDownloadQueue.pausedBooks.has(task.bookUrl)) {
        continue;
      }
      pending.splice(index, 1);
      return task;
    }
    return undefined;
  }

  private static publish(): void {
    const listeners = ChapterDownloadQueue.listeners;
    for (let index = 0; index < listeners.length; index++) {
      try {
        listeners[index](ChapterDownloadQueue.snapshot(''));
      } catch (_) {
      }
    }
  }

  /** 队列里用的书键：与 BookRepository 的 bookUrl 口径一致。 */
  private static bookKey(book: Book): string {
    const url = book.contentPath ?? '';
    if (url.length > 0) {
      return url;
    }
    return book.androidOriginalPath ?? '';
  }
}