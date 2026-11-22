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
// 标记写回（第 21 轮补齐）：上游 BookSourceCheckRepository.kt:133 每条源校验完就
// `bookSourceRepository.updateSources(source)`，把 addGroup 打的失效标签、addErrorComment 写的
// 错误注释、以及 respondTime 一起落库。本地同样写回，逻辑在 BookSourceCheckMarking.ets，
// 本文件负责在 checkOne 里调它、在整批结束时一次性 save。
//
// 本地取舍（写在代码里，不藏在报告里）：
// ①并发度取上游 downloadCacheSettings.threadCount 的等价物——本地没有下载缓存设置，
//   固定 4 路并发（Entry 单进程 RDB 写入本身串行，再高只会互相排队）。
// ②写回时机：上游逐源 updateSources，本地攒到整批结束一次性 save。本地 save 是整表
//   DELETE + 逐行 INSERT（904 行），逐源调用会把校验拖成分钟级；代价是校验中途杀进程
//   会丢本批标记。这条差异写进报告。
// ③「js失效」判定：上游靠 ScriptException/WrappedException 类型，本地引擎抛的是普通
//   Error，只能按消息特征识别（见 isScriptError），属近似实现。
import { BookSource as EngineBookSource } from '@legado/sourceengine';
import { Context } from '@kit.AbilityKit';
import { BookSource as LocalBookSource } from '../model/BookSource';
import { BookSourceRepository } from '../data/BookSourceRepository';
import { AppLog } from '../lib/AppLog';
import { BookSourceCheckMarking } from './BookSourceCheckMarking';
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

/**
 * 上游 NoStackTraceException 的等价物：checkSource 末尾把「仍在的失效标签」汇总抛出去
 * （BookSourceCheckRepository.kt:212-213）。上游靠这个类型把「汇总错误」和真正的异常区分开——
 * checkOne 的 when 里 `!is NoStackTraceException -> addGroup("网站失效")`，汇总错误不会被打成
 * 网站失效（标签已经在 checkSource 里加过了）。
 */
export class BookSourceCheckSummaryError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'BookSourceCheckSummaryError';
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
  /** 本批校验的内存标记：url → 标记对象，整批结束后一次性写回。 */
  private static pendingMarkings: Map<string, BookSourceCheckMarking> = new Map<string, BookSourceCheckMarking>();
  /** 写回标记要用的 Context；由 check() 的调用方传入（页面手里才有 getHostContext）。 */
  private static flushContext: Context | undefined = undefined;

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
   * context 用于校验结束后把 addGroup / addErrorComment / respondTime 写回库；
   * 上游不需要传（Repository 自带 Dao），本地 Repository 是静态方法且要 Context，所以从页面传进来。
   */
  static async check(sourceUrls: string[], keyword: string, options: BookSourceCheckOptions,
    context?: Context): Promise<boolean> {
    if (sourceUrls.length === 0 || BookSourceCheckCoordinator.state.isRunning) return false;
    BookSourceCheckCoordinator.flushContext = context;
    BookSourceCheckCoordinator.pendingMarkings = new Map<string, BookSourceCheckMarking>();
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
    // 上游 BookSourceCheckRepository.kt:133 逐源 updateSources；本地攒到这里一次性写回。
    // 必须在 notify 之前：列表页收到回调时会 rebuildVisibleSources，此时库里应已是新分组。
    await BookSourceCheckCoordinator.flushMarkings();
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

  /** 上游 checkOne：找源 → Running → 带超时跑 checkSource → 打标记 → 终态。 */
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
    const marking: BookSourceCheckMarking = new BookSourceCheckMarking(local);
    const startedAt: number = Date.now();
    // 上游 BookSourceCheckRepository.kt:114 `startedAt` 与 :131 失败时的 respondTime 口径：
    // 失败记 `timeoutMillis + now - startedAt`，也就是把等待超时的时间也算进去。
    const timeoutMillis: number = Math.max(0, options.timeoutSeconds * 1000);
    try {
      await BookSourceCheckCoordinator.checkSource(source, keyword, options, gate, marking);
      gate.clear();
      // 上游 :120-121 成功 `source.respondTime = System.currentTimeMillis() - startedAt`。
      marking.setRespondTime(Date.now() - startedAt);
      BookSourceCheckCoordinator.pendingMarkings.set(url, marking);
      BookSourceCheckCoordinator.updateResult(url, name, { status: 'Succeeded' });
    } catch (error) {
      gate.clear();
      // 上游 BookSourceCheckRepository.kt:125 把 TimeoutCancellationException 单独识别出来，
      // 打组「校验超时」；本地超时是闸门标记 + 掐断请求，底层抛的是 HttpClient 的
      // 「书源请求已取消」，不识别就会显示成「HTTP 0 书源请求已取消」，用户看不出是超时。
      const detail: string = gate.timedOut
        ? '校验超时'
        : (error instanceof Error ? error.message : String(error));
      // 上游 :125-131 的 when 分支：超时 → 校验超时；脚本异常 → js失效；其余（除汇总错误）
      // → 网站失效。汇总错误（checkSource 末尾把仍在的失效标签抛出来）不打组，标签已经加过。
      if (gate.timedOut) {
        marking.addGroup('校验超时');
      } else if (BookSourceCheckCoordinator.isScriptError(detail)) {
        marking.addGroup('js失效');
      } else if (!(error instanceof BookSourceCheckSummaryError)) {
        marking.addGroup('网站失效');
      }
      marking.addErrorComment(detail.length > 0 ? detail : '校验失败');
      marking.setRespondTime(timeoutMillis + Date.now() - startedAt);
      BookSourceCheckCoordinator.pendingMarkings.set(url, marking);
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

  /**
   * 上游靠 `is ScriptException, is WrappedException` 类型判「js失效」；本地引擎抛的全是普通
   * Error（AnalyzeUrl.ts / RuleExecutionService.ts / NativeExpr.ts / NativeSourceRunner.ts 都
   * 只 extend Error），没有类型可用，只能按消息特征识别。属近似实现，写进报告。
   */
  private static isScriptError(message: string): boolean {
    if (message.length === 0) return false;
    return /js|脚本|script|eval|语法|SyntaxError|TypeError|ReferenceError|is not a function|undefined is not/i
      .test(message);
  }

  /**
   * 把本批校验的标记写回库：group 落到 book_sources 表列，comment/respondTime 落进 sourceJson。
   * 上游是每条源校验完就 updateSources（BookSourceCheckRepository.kt:133），本地攒到整批结束
   * 一次性 save——本地 save 是整表 DELETE + 逐行 INSERT，逐源调用会把校验拖成分钟级。
   */
  private static async flushMarkings(): Promise<void> {
    if (BookSourceCheckCoordinator.pendingMarkings.size === 0) return;
    const context: Context | undefined = BookSourceCheckCoordinator.flushContext;
    const pending: Map<string, BookSourceCheckMarking> = BookSourceCheckCoordinator.pendingMarkings;
    BookSourceCheckCoordinator.pendingMarkings = new Map<string, BookSourceCheckMarking>();
    if (context === undefined) return;
    const all: LocalBookSource[] = BookSourceRepository.getAll();
    let changed: boolean = false;
    const next: LocalBookSource[] = [];
    for (const source of all) {
      const marking = pending.get(source.bookSourceUrl);
      if (marking === undefined) {
        next.push(source);
        continue;
      }
      next.push(marking.applyTo(source));
      changed = true;
    }
    if (!changed) return;
    try {
      await BookSourceRepository.save(context, next);
    } catch (error) {
      // 写回失败不回滚校验结果：用户看到的是校验结论，标记只是给人工清理用的旁注。
      const message: string = error instanceof Error ? error.message : String(error);
      AppLog.put('校验标记写回失败:' + message);
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
   * 失效标签用上游同一批中文串（搜索失效 / 发现失效 / 搜索链接规则为空 / 发现规则为空），
   * 并且按上游 :186-193 addGroup / :195-201 removeGroup 真正写进分组：通过的分支要把上一轮
   * 留下的同名标签摘掉，否则一条已经修好的源会永远挂着旧标签。
   */
  private static async checkSource(
    source: EngineBookSource, keyword: string, options: BookSourceCheckOptions, gate: TimeoutGate,
    marking: BookSourceCheckMarking): Promise<void> {
    // 上游 :185-186：每轮先清掉上一轮的失效分组与错误注释，再按本轮结果重新打。
    marking.removeInvalidGroups();
    marking.removeErrorComment();
    // 上游 :190 `source.getCheckKeyword(keyword)`：规则自带的 checkKeyWord 优先。
    const word: string = marking.getCheckKeyword(keyword);
    if (options.checkSearch) {
      if (source.searchUrl.length === 0) {
        marking.addGroup('搜索链接规则为空');
      } else {
        marking.removeGroup('搜索链接规则为空');
        gate.checkpoint();
        const books: SearchBookItem[] = await WebBookService.searchBook(source, word, 1);
        gate.checkpoint();
        if (books.length === 0) {
          marking.addGroup('搜索失效');
        } else {
          marking.removeGroup('搜索失效');
          await BookSourceCheckCoordinator.checkBook(source, books[0].bookUrl, true, options, gate, marking);
        }
      }
    }
    if (options.checkDiscovery && source.exploreUrl.length > 0) {
      const url: string = BookSourceCheckCoordinator.firstExploreUrl(source.exploreUrl);
      if (url.length === 0) {
        marking.addGroup('发现规则为空');
      } else {
        marking.removeGroup('发现规则为空');
        gate.checkpoint();
        const books: SearchBookItem[] = await WebBookService.exploreBook(source, url, 1);
        gate.checkpoint();
        if (books.length === 0) {
          marking.addGroup('发现失效');
        } else {
          marking.removeGroup('发现失效');
          await BookSourceCheckCoordinator.checkBook(source, books[0].bookUrl, false, options, gate, marking);
        }
      }
    }
    // 上游 :212-213：把仍在的失效标签汇总抛出（NoStackTraceException，不打「网站失效」）。
    const invalid: string = marking.getInvalidGroupNames();
    if (invalid.length > 0) {
      throw new BookSourceCheckSummaryError(invalid);
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
   *
   * 本地与上游的一处差异：上游靠 TocEmptyException / ContentEmptyException 判空，
   * 本地 WebBookService.getChapterList 空目录返回 []、getContent 空正文返回 ''，都不抛错，
   * 所以这里显式判空后自己打标签（上游 BookChapterList.kt:123-125、BookContent.kt:204-206）。
   */
  private static async checkBook(
    source: EngineBookSource, bookUrl: string, searchBook: boolean,
    options: BookSourceCheckOptions, gate: TimeoutGate, marking: BookSourceCheckMarking): Promise<void> {
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
        marking.addGroup(type + '目录失效');
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
      marking.addGroup(type + '目录失效');
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
    if (usable.length === 0) {
      // 上游 TocEmptyException → addGroup("${type}目录失效")。
      marking.addGroup(type + '目录失效');
      return;
    }
    if (!options.checkContent) return;
    gate.checkpoint();
    let content: string = '';
    try {
      content = await WebBookService.getContent(source, usable[0].url);
    } catch (error) {
      const message: string = error instanceof Error ? error.message : String(error);
      marking.addGroup(type + '正文失效');
      return;
    }
    if (content.trim().length === 0) {
      // 上游 ContentEmptyException("内容为空") → addGroup("${type}正文失效")。
      marking.addGroup(type + '正文失效');
      return;
    }
    // 上游 onSuccess：目录/正文都过就把这两个标签摘掉。
    marking.removeGroup(type + '目录失效');
    marking.removeGroup(type + '正文失效');
  }
}
