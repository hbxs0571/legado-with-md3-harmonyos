// 书源调试协调器（P10，任务书 14.3）。
// 引擎没有宿主可读的日志条目流（BookSourceDebugContext 是拉取式、宿主未透传），
// 因此在宿主侧包装 WebBookService 全链打点：阶段前后 Date.now() 计时，
// 自定义 {kind,message,elapsedMs,timestamp} 条目推给事件总线，调试页订阅显示。
// 目标 key 协议对齐上游 Debug.startDebug：Search 原文 / Explore 发现:: / Info 绝对URL / Toc ++ / Content --。
import { BookSource } from '@legado/sourceengine';
import { BookSourceRepository } from '../data/BookSourceRepository';
import { LegadoSourceMapper } from './LegadoSourceMapper';
import { WebBookService } from './WebBookService';
import { RemoteChapter, SearchBookItem } from './SourceModels';
import { DebugEntry, DebugEventKind, DebugTarget } from './BookSourceDebugModels';

const MAX_LOG_ENTRIES: number = 1000;
const MAX_MESSAGE_CHARS: number = 2000;

/** 全局调试事件总线：协调器写入，调试页订阅。单会话一次调试，与上游 Debug 单例等价。 */
export class DebugEventBus {
  private static startedAt: number = 0;
  private static seq: number = 0;
  private static entries: DebugEntry[] = [];
  private static stopped: boolean = false;
  private static listeners: ((entries: DebugEntry[]) => void)[] = [];

  static begin(): void {
    DebugEventBus.startedAt = Date.now();
    DebugEventBus.seq = 0;
    DebugEventBus.entries = [];
    DebugEventBus.stopped = false;
    DebugEventBus.notify();
  }

  static isStopped(): boolean {
    return DebugEventBus.stopped;
  }

  static stop(): void {
    DebugEventBus.stopped = true;
  }

  static emit(kind: DebugEventKind, message: string): void {
    const clipped = message.length > MAX_MESSAGE_CHARS ? message.slice(0, MAX_MESSAGE_CHARS) + '…' : message;
    DebugEventBus.seq += 1;
    const entry: DebugEntry = {
      id: DebugEventBus.seq,
      kind: kind,
      message: clipped,
      timestamp: Date.now(),
      elapsedMs: Date.now() - DebugEventBus.startedAt
    };
    DebugEventBus.entries.push(entry);
    if (DebugEventBus.entries.length > MAX_LOG_ENTRIES) {
      DebugEventBus.entries = DebugEventBus.entries.slice(DebugEventBus.entries.length - MAX_LOG_ENTRIES);
    }
    DebugEventBus.notify();
  }

  static snapshot(): DebugEntry[] {
    return DebugEventBus.entries.slice();
  }

  static clear(): void {
    DebugEventBus.entries = [];
    DebugEventBus.seq = 0;
    DebugEventBus.notify();
  }

  static subscribe(cb: (entries: DebugEntry[]) => void): void {
    DebugEventBus.listeners.push(cb);
  }

  static unsubscribe(cb: (entries: DebugEntry[]) => void): void {
    const i = DebugEventBus.listeners.indexOf(cb);
    if (i >= 0) DebugEventBus.listeners.splice(i, 1);
  }

  private static notify(): void {
    const snapshot = DebugEventBus.entries.slice();
    for (const cb of DebugEventBus.listeners) {
      cb(snapshot);
    }
  }
}

/** 按 target 拼调试 key，对齐上游 ViewModel.kt:91-97。 */
export function buildDebugKey(target: DebugTarget, query: string): string {
  if (target === 'Explore') return '发现::' + query;
  if (target === 'Toc') return '++' + query.replace(/^\+\+/, '');
  if (target === 'Content') return '--' + query.replace(/^--/, '');
  return query;
}

/** 调试执行结果（终态）。 */
export interface DebugRunResult {
  status: 'Success' | 'Failed' | 'Cancelled';
  message: string;
}

export class BookSourceDebugCoordinator {
  /** 仓储按 URL 找源并投影成引擎源；与 P9 登录协调器同款。 */
  private static resolveEngine(sourceUrl: string): BookSource | null {
    const all = BookSourceRepository.getAll();
    for (const local of all) {
      if (local.bookSourceUrl === sourceUrl) return LegadoSourceMapper.fromLocal(local);
    }
    return null;
  }

  private static checkStop(): boolean {
    return DebugEventBus.isStopped();
  }

  /** 启动一次调试：重置总线 → 按 key 前缀分派 → 终态。全部异常转成 Error 条目。 */
  static async run(sourceUrl: string, target: DebugTarget, query: string): Promise<DebugRunResult> {
    DebugEventBus.begin();
    const source = BookSourceDebugCoordinator.resolveEngine(sourceUrl);
    if (source === null) {
      const result: DebugRunResult = { status: 'Failed', message: '书源不存在：' + sourceUrl };
      DebugEventBus.emit('Error', result.message);
      return result;
    }
    const key = buildDebugKey(target, query);
    DebugEventBus.emit('Message', '目标 ' + target + '，书源 ' + source.bookSourceName + '，输入 ' + query);
    try {
      if (key.startsWith('发现::')) {
        await BookSourceDebugCoordinator.runExplore(source, key.slice(3));
      } else if (key.startsWith('++')) {
        await BookSourceDebugCoordinator.runToc(source, key.slice(2));
      } else if (key.startsWith('--')) {
        await BookSourceDebugCoordinator.runContent(source, key.slice(2));
      } else if (/^https?:\/\//i.test(key)) {
        await BookSourceDebugCoordinator.runInfo(source, key);
      } else {
        await BookSourceDebugCoordinator.runSearch(source, key);
      }
    } catch (e) {
      const message = e instanceof Error ? e.message : String(e);
      if (BookSourceDebugCoordinator.checkStop()) {
        DebugEventBus.emit('Message', '已停止');
        const cancelled: DebugRunResult = { status: 'Cancelled', message: '调试已停止' };
        return cancelled;
      }
      DebugEventBus.emit('Error', message);
      const failed: DebugRunResult = { status: 'Failed', message: message };
      return failed;
    }
    const ok: DebugRunResult = { status: 'Success', message: '调试完成' };
    return ok;
  }

  private static async runSearch(source: BookSource, keyword: string): Promise<void> {
    const t0 = Date.now();
    const books = await WebBookService.searchBook(source, keyword, 1);
    DebugEventBus.emit('SearchSource',
      '搜索「' + keyword + '」得到 ' + books.length + ' 条\n' + BookSourceDebugCoordinator.previewBooks(books));
    DebugEventBus.emit('Message', '搜索耗时 ' + (Date.now() - t0) + 'ms');
    if (books.length > 0) {
      await BookSourceDebugCoordinator.runInfo(source, books[0].bookUrl, books[0].origin);
    }
  }

  private static async runExplore(source: BookSource, url: string): Promise<void> {
    const books = await WebBookService.exploreBook(source, url, 1);
    DebugEventBus.emit('SearchSource',
      '发现得到 ' + books.length + ' 条\n' + BookSourceDebugCoordinator.previewBooks(books));
    if (books.length > 0) {
      await BookSourceDebugCoordinator.runInfo(source, books[0].bookUrl, books[0].origin);
    }
  }

  private static async runInfo(source: BookSource, bookUrl: string, _origin?: string): Promise<void> {
    if (BookSourceDebugCoordinator.checkStop()) return;
    const detail = await WebBookService.getBookInfo(source, bookUrl);
    DebugEventBus.emit('InfoSource',
      '书名：' + detail.name + '\n作者：' + detail.author + '\n目录：' + detail.tocUrl +
      '\n最新：' + detail.lastChapter);
    await BookSourceDebugCoordinator.runToc(source, detail.tocUrl || bookUrl);
  }

  private static async runToc(source: BookSource, tocUrl: string): Promise<void> {
    if (BookSourceDebugCoordinator.checkStop()) return;
    const chapters = await WebBookService.getChapterList(source, tocUrl);
    DebugEventBus.emit('TocSource',
      '目录 ' + chapters.length + ' 章\n' + BookSourceDebugCoordinator.previewChapters(chapters));
    if (chapters.length > 0) {
      await BookSourceDebugCoordinator.runContent(source, chapters[0].url);
    }
  }

  private static async runContent(source: BookSource, chapterUrl: string): Promise<void> {
    if (BookSourceDebugCoordinator.checkStop()) return;
    const content = await WebBookService.getContent(source, chapterUrl);
    DebugEventBus.emit('ContentSource',
      '正文 ' + content.length + ' 字\n' + content.slice(0, 300));
  }

  private static previewBooks(books: SearchBookItem[]): string {
    const lines: string[] = [];
    const n = Math.min(books.length, 5);
    for (let i = 0; i < n; i++) {
      lines.push((i + 1) + '. ' + books[i].name + ' / ' + books[i].author + ' — ' + books[i].bookUrl);
    }
    return lines.join('\n');
  }

  private static previewChapters(chapters: RemoteChapter[]): string {
    const lines: string[] = [];
    const n = Math.min(chapters.length, 5);
    for (let i = 0; i < n; i++) {
      lines.push((i + 1) + '. ' + chapters[i].title + ' — ' + chapters[i].url);
    }
    return lines.join('\n');
  }
}
