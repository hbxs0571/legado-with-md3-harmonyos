// 书源事件回调（对应上游 SourceCallBack.callBackBook）。
//
// 上游在删除书架书籍时对非本地书调 `SourceCallBack.callBackBook(DEL_BOOK_SHELF, source, book)`，
// 书源若开了 `eventListener` 且填了 `ruleContent.callBackJs`，就用
// `source.evalJS(jsStr) { put("event", event); put("result", result); put("book", book); put("chapter", chapter) }`
// 跑一段脚本，让书源自己感知「书被移出书架」。
//
// 本地引擎的 `ContentRule`（`third_party/harmony-book-source-engine/.../model/data/Book.ts:460-473`）
// 没有 callBackJs 字段，`LegadoSourceMapper.ets` 也如实注释「callBackJs 引擎无，静默跳过」。
// 但引擎的 `BookSourceScriptRunner.runRawScript` 能跑任意裸 JS，且可以把调用方要注入的变量塞进执行环境，
// 所以这里从书源原始 JSON 里读出 callBackJs 再交给它执行，不改引擎源码。
//
// 一个平台限制：`runRawScript` 的 bindings 只收 `Record<string, string>`（`env.ctx.put(name, value)`
// 只接受字符串），而上游注入的 `book` / `chapter` 是对象，脚本里会写 `book.name`、`chapter.title`。
// 因此这里把 book 拍成 JSON 作为脚本前缀 `var book = {...};` 注入，而不是走 bindings——
// 这样 `book.name` 这类成员访问照常可用，语义与上游一致。

import { BookSource, BookSourceScriptRunner } from '@legado/sourceengine';
import { AppLog } from '../lib/AppLog';
import { Book } from '../model/Book';
import { BookSourceRuntime } from './BookSourceRuntime';

/** 上游 `SourceCallBack` 的事件常量里本地会用到的那几个。 */
export const CALLBACK_EVENT_DEL_BOOK_SHELF: string = 'delBookShelf';
export const CALLBACK_EVENT_ADD_BOOK_SHELF: string = 'addBookShelf';

export class BookSourceCallback {
  /**
   * 跑书源的事件回调。与上游 `SourceCallBack.callBackBook` 同口径：
   * 书源为空 / 书为空 / 没开 eventListener / 没填 callBackJs 时静默返回；
   * 脚本出错只记日志，不向调用方抛（删书主流程不能因为回调失败而失败）。
   */
  static callBackBook(event: string, sourceUrl: string, book: Book | undefined): void {
    if (sourceUrl.length === 0 || book === undefined) { return; }
    const source: BookSource | null = BookSourceRuntime.resolve(sourceUrl);
    if (source === null || source.eventListener !== true) { return; }
    const code = BookSourceCallback.callBackJsOf(source);
    if (code.length === 0) { return; }
    // 上游把事件名 / 结果 / 书 / 章节都放进执行环境；本地没有章节上下文，chapter 固定 null。
    const bindings: Record<string, string> = {};
    bindings['event'] = event;
    bindings['result'] = '';
    const prefix = `var book = ${BookSourceCallback.bookJson(book)};\nvar chapter = null;\n`;
    try {
      BookSourceScriptRunner.runRawScript(source, `${prefix}${code}`, bindings);
    } catch (error) {
      AppLog.put(`${source.bookSourceName}\n书源执行回调事件${event}出错\n${error instanceof Error ? error.message : String(error)}`);
    }
  }

  /** 从书源原始 JSON 里读 `ruleContent.callBackJs`；引擎类型没这个字段，只能走原文。 */
  private static callBackJsOf(source: BookSource): string {
    const raw = source.rawSourceJson ?? '';
    if (raw.length === 0) { return ''; }
    try {
      const parsed = JSON.parse(raw) as Record<string, Object>;
      const contentRule = parsed['ruleContent'];
      if (contentRule === undefined || contentRule === null) { return ''; }
      const value = (contentRule as Record<string, Object>)['callBackJs'];
      if (typeof value !== 'string') { return ''; }
      return value.trim();
    } catch (_error) {
      return '';
    }
  }

  /**
   * 把本地 Book 拍成上游 Book 实体的字段名。
   *
   * 书源的 callBackJs 是按上游 `io.legado.app.data.entities.Book` 写的（`book.bookUrl` / `book.name` /
   * `book.author` / `book.origin` …），本地模型字段名不同（`contentPath` / `title`），
   * 所以这里显式映射，不能直接 `JSON.stringify(book)`。
   */
  private static bookJson(book: Book): string {
    const payload: Record<string, string | number> = {};
    payload['bookUrl'] = book.contentPath ?? book.androidOriginalPath ?? '';
    payload['name'] = book.title;
    payload['author'] = book.author;
    payload['origin'] = book.origin ?? '';
    payload['originName'] = book.originName ?? '';
    payload['tocUrl'] = book.tocUrl ?? '';
    payload['latestChapterTitle'] = book.latestChapterTitle ?? '';
    payload['durChapterTitle'] = book.lastChapter;
    payload['durChapterIndex'] = book.chapterIndex ?? 0;
    payload['durChapterPos'] = book.chapterProgress ?? 0;
    payload['totalChapterNum'] = Number.parseInt(book.chapterCount ?? '0', 10) || 0;
    payload['group'] = 0;
    return JSON.stringify(payload);
  }
}
