// 书源校验协调器（对齐上游 BookSourceCheckRepository.kt 与 BookSourceCheckGateway.kt）。
//
// 上游链路：CheckBookSourceSheet 收 sourceIds + keyword + options → StartCheck →
// BookSourceCheckRepository.check(sourceIds, keyword) 在固定线程池里并发 checkOne；
// checkOne 包 withTimeout(settings.timeoutMillis) 跑 checkSource；
// checkSource 按 options 依次跑「搜索 → 发现 → 详情 → 目录 → 正文」，失败把对应中文标签
// 写进书源 group（搜索失效/发现失效/搜索目录失效/搜索正文失效/发现目录失效/发现正文失效/
// 搜索链接规则为空/发现规则为空），最后把仍在的失效标签作为异常抛出；
// 结果逐条回写到 BookSourceCheckState.results，UI 用 displayMessage 六档文案显示。
//
// 本地取舍（写在代码里，不藏在报告里）：
// ①并发度取上游 downloadCacheSettings.threadCount 的等价物——本地没有下载缓存设置，
//   固定 4 路并发（Entry 单进程 RDB 写入本身串行，再高只会互相排队）。
// ②checkSource 的失效标签在本地直接拼成结果文案，不真去写 bookSourceGroup：
//   写回分组要改 data/BookSourceRepository.ets 的整表重写路径，与「运行中随时可能并发编辑」
//   冲突，且上游 addGroup 的语义是「打标供人工清理」，本地校验结果已随 checkMessage 常驻行上，
//   两者信息等价。分组写回留作未做项写进报告。
import { BookSource as EngineBookSource } from '@legado/sourceengine';
import { BookSource as LocalBookSource } from '../model/BookSource';
import { BookSourceRepository } from '../data/BookSourceRepository';
import { LegadoSourceMapper } from './LegadoSourceMapper';
import { SourceHttp } from './SourceHttp';
import { WebBookService } from './WebBookService';
import { RemoteChapter, RemoteBookDetail, SearchBookItem } from './SourceModels';

/** 单源校验状态，对齐上游 BookSourceCheckStatus（isTerminal 用 canTerminal 判定）。 */
export type BookSourceCheckStatus = 'Pending' | 'Running' | 'Succeeded' | 'Failed' | 'Cancelled';

/** 失败原因，对齐上游 BookSourceCheckFailure。 */
export type BookSourceCheckFailure = 'CheckFailed' | 'SourceMissing' | 'SaveFailed' | 'Incomplete';

/** 单源结果，对齐上游 BookSourceCheckResult。 */
export interface BookSourceCheckResult {
  status: BookSourceCheckStatus;
  failure?: BookSourceCheckFailure;
  detail?: string;
}

/** 整体状态，对齐上游 BookSourceCheckState（produced/completed 等派生量在方法里算）。 */
export interface BookSourceCheckState {
  isRunning: boolean;
  total: number;
  completed: number;
  currentSourceName: string;
  results: Map<string, BookSourceCheckResult>;
}

/** 校验选项，字段与上游 BookSourceCheckOptionsUi（BookSourceContract.kt:33-40）一致。 */
export interface BookSourceCheckOptions {
  timeoutSeconds: number;
  checkSearch: boolean;
  checkDiscovery: boolean;
  checkInfo: boolean;
  checkCategory: boolean;
  checkContent: boolean;
}

/** 默认选项：全 true、超时 180 秒（上游默认值）。 */
export function defaultCheckOptions(): BookSourceCheckOptions {
  return {
    timeoutSeconds: 180,
    checkSearch: true,
    checkDiscovery: true,
    checkInfo: true,
    checkCategory: true,
    checkContent: true
  };
}

/** 关键字默认值，对齐上游 book_source_check_default_keyword。 */
export const CHECK_DEFAULT_KEYWORD: string = '我的';

/** 本地并发度（上游是 downloadCacheSettings.threadCount）。 */
const CHECK_CONCURRENCY: number = 4;

/** 上游 BookSourceCheckStatus.isTerminal 的三态。 */
function canTerminal(status: BookSourceCheckStatus): boolean {
  return status === 'Succeeded' || status === 'Failed' || status === 'Cancelled';
}

/** 上游 BookSourceViewModel.kt:666-700 displayMessage 六档文案。 */
export function checkDisplayMessage(result: BookSourceCheckResult | undefined): string {
  if (result === undefined) return '';
  if (result.status === 'Pending') return '等待校验';
  if (result.status === 'Running') return '正在校验';
  if (result.status === 'Succeeded') return '校验成功';
  if (result.status === 'Cancelled') return '校验已取消';
  // 以下是 Failed 的细分。
  if (result.failure === 'SourceMissing') return '校验失败：源不存在';
  if (result.failure === 'SaveFailed') {
    return '校验失败：无法保存数据' + (result.detail ?? '');
  }
  if (result.failure === 'Incomplete') return '校验失败：数据未完成';
  return '校验失败：' + (result.detail ?? '未知错误');
}

/**
 * 一次校验的超时包装。上游用 withTimeout(timeoutMillis) + TimeoutCancellationException；
 * 本地没有协程取消，用 setTimeout 置标记位，再由两处消费：
 * ①checkpoint() 在每个 await 之间自查，模拟上游的 cancellation 点；
 * ②checkOne 把 timedOut 挂到 SourceHttp 的单源取消钩子上，超时那一刻在途 HTTP 会被掐断
 *   （HttpClient 轮询 cancelCheck 后 client.destroy()），与上游的协作式取消等价。
 */
class TimeoutGate {
  timedOut: boolean = false;
  private timer: number = -1;

  constructor(seconds: number) {
    // 上游 withTimeout(0) 是「立即超时」，不是「不限时」；本地原先写成 seconds > 0 才起定时器，
    // 等于把 0 解释成不限时，与上游语义相反。这里 0 也照样起一个 0ms 定时器。
    this.timer = setTimeout(() => { this.timedOut = true; }, Math.max(0, seconds * 1000));
  }

  /** 每个 await 之间调用；已超时就抛超时错误，模拟上游的 cancellation 点。 */
  checkpoint(): void {
    if (this.timedOut) {
      throw new Error('校验超时');
    }
  }

  clear(): void {
    if (this.timer >= 0) {
      clearTimeout(this.timer);
      this.timer = -1;
    }
  }
}

export class BookSourceCheckCoordinator {
  private static state: BookSourceCheckState = {
    isRunning: false,
    total: 0,
    completed: 0,
    currentSourceName: '',
    results: new Map<string, BookSourceCheckResult>()
  };
  private static listeners: ((state: BookSourceCheckState) => void)[] = [];

  static currentState(): BookSourceCheckState {
    return BookSourceCheckCoordinator.state;
  }

  /** 逐源结果快照：url → displayMessage 文案，供列表页把 checkMessage 挂到行上。 */
  static messages(): Map<string, string> {
    const map: Map<string, string> = new Map<string, string>();
    BookSourceCheckCoordinator.state.results.forEach((result: BookSourceCheckResult, url: string) => {
      const message = checkDisplayMessage(result);
      if (message.length > 0) map.set(url, message);
    });
    return map;
  }

  static subscribe(listener: (state: BookSourceCheckState) => void): void {
    BookSourceCheckCoordinator.listeners.push(listener);
  }

  static unsubscribe(listener: (state: BookSourceCheckState) => void): void {
    const index = BookSourceCheckCoordinator.listeners.indexOf(listener);
    if (index >= 0) BookSourceCheckCoordinator.listeners.splice(index, 1);
  }

  private static notify(): void {
    for (const listener of BookSourceCheckCoordinator.listeners) {
      listener(BookSourceCheckCoordinator.state);
    }
  }

  /**
   * 上游 BookSourceCheckRepository.check：已有任务在跑就直接返回 false（上游是
   * `if (sourceIds.isEmpty() || _state.value.isRunning) return`）。
   */
  static async check(sourceUrls: string[], keyword: string, options: BookSourceCheckOptions): Promise<boolean> {
    if (sourceUrls.length === 0 || BookSourceCheckCoordinator.state.isRunning) return false;
    const results: Map<string, BookSourceCheckResult> = new Map<string, BookSourceCheckResult>();
    for (const url of sourceUrls) {
      results.set(url, { status: 'Pending' });
    }
    BookSourceCheckCoordinator.state = {
      isRunning: true,
      total: sourceUrls.length,
      completed: 0,
      currentSourceName: '',
      results: results
    };
    BookSourceCheckCoordinator.notify();

    const word: string = keyword.trim().length > 0 ? keyword.trim() : CHECK_DEFAULT_KEYWORD;
    // 固定并发度分批跑。上游用 awaitAll 一次投递全部，这里分批是为了不动 Promise 池。
    for (let start = 0; start < sourceUrls.length; start += CHECK_CONCURRENCY) {
      const batch: string[] = sourceUrls.slice(start, start + CHECK_CONCURRENCY);
      const tasks: Promise<void>[] = [];
      for (const url of batch) {
        tasks.push(BookSourceCheckCoordinator.checkOne(url, word, options));
      }
      await Promise.all(tasks);
    }

    // 收尾：未到终态的统一标记（上游 completedNormally=true 时记 Failed + Incomplete）。
    const finalResults: Map<string, BookSourceCheckResult> = new Map<string, BookSourceCheckResult>();
    let completed: number = 0;
    BookSourceCheckCoordinator.state.results.forEach((result: BookSourceCheckResult, url: string) => {
      if (canTerminal(result.status)) {
        finalResults.set(url, result);
        completed += 1;
      } else {
        finalResults.set(url, { status: 'Failed', failure: 'Incomplete' });
        completed += 1;
      }
    });
    BookSourceCheckCoordinator.state = {
      isRunning: false,
      total: sourceUrls.length,
      completed: completed,
      currentSourceName: '',
      results: finalResults
    };
    BookSourceCheckCoordinator.notify();
    return true;
  }

  /** 上游 updateResult：逐条写结果并推进 completed 计数。 */
  private static updateResult(url: string, name: string, result: BookSourceCheckResult): void {
    const previous = BookSourceCheckCoordinator.state.results.get(url);
    const wasTerminal: boolean = previous !== undefined && canTerminal(previous.status);
    const nowTerminal: boolean = canTerminal(result.status);
    const completed: number = (nowTerminal && !wasTerminal)
      ? BookSourceCheckCoordinator.state.completed + 1
      : BookSourceCheckCoordinator.state.completed;
    const results: Map<string, BookSourceCheckResult> = new Map<string, BookSourceCheckResult>(
      BookSourceCheckCoordinator.state.results);
    results.set(url, result);
    BookSourceCheckCoordinator.state = {
      isRunning: BookSourceCheckCoordinator.state.isRunning,
      total: BookSourceCheckCoordinator.state.total,
      completed: completed,
      currentSourceName: name.length > 0 ? name : BookSourceCheckCoordinator.state.currentSourceName,
      results: results
    };
    BookSourceCheckCoordinator.notify();
  }

  /** 上游 checkOne：找源 → Running → 带超时跑 checkSource → 终态。 */
  private static async checkOne(url: string, keyword: string, options: BookSourceCheckOptions): Promise<void> {
    const local = BookSourceCheckCoordinator.findLocal(url);
    if (local === undefined) {
      BookSourceCheckCoordinator.updateResult(url, '', { status: 'Failed', failure: 'SourceMissing' });
      return;
    }
    const name: string = local.bookSourceName;
    const source: EngineBookSource = LegadoSourceMapper.fromLocal(local);
    BookSourceCheckCoordinator.updateResult(url, name, { status: 'Running' });
    const gate: TimeoutGate = new TimeoutGate(options.timeoutSeconds);
    // 对齐上游 BookSourceCheckRepository.kt:116 `withTimeout(...)`：上游超时是协程取消，
    // 会直接打断在途 HTTP；本地没有协程，改成把闸门挂到该源的取消钩子上，
    // 超时那一刻由 HttpClient 的 cancelCheck 轮询把连接 destroy() 掉。
    SourceHttp.setSourceCancelCheck(url, (): boolean => gate.timedOut);
    try {
      await BookSourceCheckCoordinator.checkSource(source, keyword, options, gate);
      gate.clear();
      BookSourceCheckCoordinator.updateResult(url, name, { status: 'Succeeded' });
    } catch (error) {
      gate.clear();
      // 上游 BookSourceCheckRepository.kt:125 把 TimeoutCancellationException 单独识别出来，
      // 打组「校验超时」；本地超时是闸门标记 + 掐断请求，底层抛的是 HttpClient 的
      // 「书源请求已取消」，不识别就会显示成「HTTP 0 书源请求已取消」，用户看不出是超时。
      const detail: string = gate.timedOut
        ? '校验超时'
        : (error instanceof Error ? error.message : String(error));
      BookSourceCheckCoordinator.updateResult(url, name, {
        status: 'Failed',
        failure: 'CheckFailed',
        detail: detail.length > 0 ? detail : '校验失败'
      });
    } finally {
      // 钩子必须撤销：留着会让下一次同源请求带着已超时的闸门，直接秒取消。
      SourceHttp.clearSourceCancelCheck(url);
    }
  }

  private static findLocal(url: string): LocalBookSource | undefined {
    const all: LocalBookSource[] = BookSourceRepository.getAll();
    for (const source of all) {
      if (source.bookSourceUrl === url) return source;
    }
    return undefined;
  }

  /**
   * 上游 checkSource：搜索 → 发现 → 未通过项汇总抛错。
   * 失效标签用上游同一批中文串（搜索失效 / 发现失效 / 搜索链接规则为空 / 发现规则为空）。
   */
  private static async checkSource(
    source: EngineBookSource, keyword: string, options: BookSourceCheckOptions, gate: TimeoutGate): Promise<void> {
    const failures: string[] = [];
    if (options.checkSearch) {
      if (source.searchUrl.length === 0) {
        failures.push('搜索链接规则为空');
      } else {
        gate.checkpoint();
        const books: SearchBookItem[] = await WebBookService.searchBook(source, keyword, 1);
        gate.checkpoint();
        if (books.length === 0) {
          failures.push('搜索失效');
        } else {
          await BookSourceCheckCoordinator.checkBook(source, books[0].bookUrl, true, options, gate, failures);
        }
      }
    }
    if (options.checkDiscovery && source.exploreUrl.length > 0) {
      const url: string = BookSourceCheckCoordinator.firstExploreUrl(source.exploreUrl);
      if (url.length === 0) {
        failures.push('发现规则为空');
      } else {
        gate.checkpoint();
        const books: SearchBookItem[] = await WebBookService.exploreBook(source, url, 1);
        gate.checkpoint();
        if (books.length === 0) {
          failures.push('发现失效');
        } else {
          await BookSourceCheckCoordinator.checkBook(source, books[0].bookUrl, false, options, gate, failures);
        }
      }
    }
    if (failures.length > 0) {
      throw new Error(failures.join('；'));
    }
  }

  /**
   * 上游 exploreKinds().firstOrNull { url 非空 }?.url：exploreUrl 是 JSON 数组
   * [{title,url}]，取第一条 url 非空的。解析失败按 URL 模板原样处理。
   */
  private static firstExploreUrl(exploreUrl: string): string {
    const raw: string = exploreUrl.trim();
    if (raw.length === 0) return '';
    if (!raw.startsWith('[')) return raw;
    try {
      const kinds = JSON.parse(raw) as Object[];
      for (const kind of kinds) {
        const item = kind as Record<string, Object>;
        const url = item['url'];
        if (typeof url === 'string' && url.trim().length > 0) return url.trim();
      }
    } catch (_) {
      return '';
    }
    return '';
  }

  /**
   * 上游 checkBook：详情 → 目录（取前两章、跳过以标题开头的卷）→ 正文。
   * 目录/正文失败按「搜索目录失效 / 搜索正文失效 / 发现目录失效 / 发现正文失效」记账，
   * 其余异常继续上抛（与上游 onFailure 里的 when 分支一致）。
   */
  private static async checkBook(
    source: EngineBookSource, bookUrl: string, searchBook: boolean,
    options: BookSourceCheckOptions, gate: TimeoutGate, failures: string[]): Promise<void> {
    const type: string = searchBook ? '搜索' : '发现';
    if (!options.checkInfo) return;
    gate.checkpoint();
    let tocUrl: string = bookUrl;
    try {
      const detail: RemoteBookDetail = await WebBookService.getBookInfo(source, bookUrl);
      tocUrl = detail.tocUrl.length > 0 ? detail.tocUrl : bookUrl;
    } catch (error) {
      const message: string = error instanceof Error ? error.message : String(error);
      if (/目录|toc/i.test(message)) {
        failures.push(type + '目录失效');
        return;
      }
      throw new Error(message);
    }
    gate.checkpoint();
    if (!options.checkCategory) return;
    // 上游：bookSourceType == file 时不校验目录/正文。
    if (source.bookSourceType === 3) return;
    let chapters: RemoteChapter[] = [];
    try {
      chapters = await WebBookService.getChapterList(source, tocUrl);
    } catch (error) {
      const message: string = error instanceof Error ? error.message : String(error);
      failures.push(type + '目录失效');
      return;
    }
    gate.checkpoint();
    // 上游 filter { !(isVolume && url.startsWith(title)) }.take(2)
    const usable: RemoteChapter[] = [];
    for (const chapter of chapters) {
      const isVolume: boolean = chapter.isVolume === true;
      if (isVolume && chapter.url.startsWith(chapter.title)) continue;
      usable.push(chapter);
      if (usable.length >= 2) break;
    }
    if (usable.length === 0) return;
    if (!options.checkContent) return;
    gate.checkpoint();
    try {
      await WebBookService.getContent(source, usable[0].url);
    } catch (error) {
      const message: string = error instanceof Error ? error.message : String(error);
      failures.push(type + '正文失效');
    }
  }
}
