// H-6 网址导入：对齐上游 domain/usecase/AddBookUseCase.kt 的完整语义。
//
// 上游把「按网址建书」拆成三步：按 baseUrl 找 enabled 书源 → 按 bookUrlPattern 兜底匹配 →
// 取详情写库（同书同作者时走迁移、否则 order = minOrder - 1 插入）。本地书源以 sourceJson
// 为唯一真值，所以匹配要在 LegadoSourceMapper 映射出的引擎对象上做。

import { Book, BookChapter } from '../model/Book';
import { BookSource } from '../model/BookSource';
import { BookRepository } from './BookRepository';
import { BookSourceRepository } from './BookSourceRepository';
import { LegadoSourceMapper } from '../bookSource/LegadoSourceMapper';
import { WebBookService } from '../bookSource/WebBookService';
import { RemoteBookDetail, RemoteChapter } from '../bookSource/SourceModels';
import { AppLog } from '../lib/AppLog';
import { Context } from '@kit.AbilityKit';

/** 一次网址导入的汇总结果。 */
export interface AddBookByUrlResult {
  successCount: number;
  /** 逐条失败原因，供调用方汇总成一句提示。 */
  failures: string[];
  /** 本次新增或更新的书目（已落库），供调用方刷新内存书架。 */
  addedBooks: Book[];
}

export class AddBookByUrlUseCase {
  /**
   * 上游 `NetworkUtils.getBaseUrl`：取 scheme://host[:port]，无 scheme 时返回空。
   * 上游用 okhttp HttpUrl，这里按同一口径手写。
   */
  static baseUrlOf(bookUrl: string): string {
    const trimmed = bookUrl.trim();
    const match = /^(https?):\/\/([^/?#]+)/i.exec(trimmed);
    if (match === null) { return ''; }
    return `${match[1].toLowerCase()}://${match[2].toLowerCase()}`;
  }

  /**
   * 上游 `getBookSourceAddBook(baseUrl)`：enabled 且 bookSourceUrl 正好等于 baseUrl。
   * 注意上游 SQL 只判 `enabled = 1`，不判 bookSourceType，这里同样不判。
   */
  static sourceByBaseUrl(baseUrl: string): BookSource | undefined {
    if (baseUrl.length === 0) { return undefined; }
    return BookSourceRepository.getAll().find((source: BookSource) =>
      source.enabled === true && source.bookSourceUrl === baseUrl);
  }

  /**
   * 上游 `hasBookUrlPattern` 兜底：enabled、bookUrlPattern 去空白后非空且非 'NONE'，
   * 按 customOrder 升序遍历，第一条 `bookUrl.matches(pattern)` 命中的胜出。
   */
  static sourceByUrlPattern(bookUrl: string): BookSource | undefined {
    const candidates = BookSourceRepository.getAll()
      .filter((source: BookSource): boolean => source.enabled === true)
      .sort((a: BookSource, b: BookSource): number => a.customOrder - b.customOrder);
    for (let index = 0; index < candidates.length; index++) {
      const source = candidates[index];
      const engine = LegadoSourceMapper.fromLocal(source);
      const pattern = (engine.bookUrlPattern ?? '').trim();
      if (pattern.length === 0 || pattern === 'NONE') { continue; }
      try {
        if (new RegExp(pattern).test(bookUrl)) { return source; }
      } catch (_error) {
        // 上游 runCatching 吞掉非法正则，继续试下一条。
      }
    }
    return undefined;
  }

  /** 上游 `bookSourceRepository.getBook(bookInfo.name, bookInfo.author)` 的同名同作者查重。 */
  static async findByTitleAuthor(context: Context, title: string, author: string): Promise<Book | undefined> {
    const all = await BookRepository.loadImportedBooks(context);
    return all.find((book: Book): boolean => book.title === title && book.author === author);
  }

  /** 把上游 RemoteBookDetail 映射成本地 Book（字段一一对应，order 由调用方给）。 */
  static bookOf(detail: RemoteBookDetail, order: number): Book {
    return {
      id: detail.bookUrl,
      title: detail.name,
      author: detail.author,
      category: detail.kind,
      lastChapter: detail.lastChapter,
      progress: 0,
      coverUri: detail.coverUrl,
      chapterCount: detail.wordCount,
      description: detail.intro,
      origin: detail.origin,
      originName: detail.originName,
      tocUrl: detail.tocUrl,
      isLocal: false,
      order: order
    };
  }

  /** 上游 migrateTo：同书同作者时用新详情覆盖可变字段，保留阅读进度与分组。 */
  static mergeInto(existing: Book, detail: RemoteBookDetail): Book {
    // ArkTS 禁对象展开（arkts-no-spread），用仓储深拷贝后逐字段覆盖。
    const next: Book = BookRepository.copyBook(existing);
    next.title = detail.name;
    next.author = detail.author;
    next.category = detail.kind;
    next.lastChapter = detail.lastChapter;
    next.coverUri = detail.coverUrl;
    next.chapterCount = detail.wordCount;
    next.description = detail.intro;
    next.origin = detail.origin;
    next.originName = detail.originName;
    next.tocUrl = detail.tocUrl;
    return next;
  }

  /**
   * 在线目录 → 本地 BookChapter 行，口径与 OnlineBookService.getChapterList 一致：
   * 在线章节靠 url + index 标识，卷标题 tocLevel 0、卷内 1，start/end 不设。
   */
  static chapterRowsOf(bookUrl: string, remote: RemoteChapter[]): BookChapter[] {
    const rows: BookChapter[] = [];
    for (let index = 0; index < remote.length; index++) {
      const chapter = remote[index];
      const volume = chapter.isVolume === true;
      const row: BookChapter = {
        url: chapter.url,
        title: chapter.title,
        isVolume: volume,
        tocLevel: volume ? 0 : 1,
        bookUrl: bookUrl,
        index: index
      };
      rows.push(row);
    }
    return rows;
  }

  /**
   * 主流程，对齐上游 `AddBookUseCase.execute(bookUrls, onProgress)`。
   * bookUrls 允许换行分隔多条，逐条处理，单条失败不影响其余。
   */
  static async execute(context: Context, bookUrls: string,
    onProgress: (successCount: number) => void = (_count: number): void => {}): Promise<AddBookByUrlResult> {
    let successCount = 0;
    const failures: string[] = [];
    const addedBooks: Book[] = [];
    const urls = bookUrls.split('\n');

    for (let index = 0; index < urls.length; index++) {
      const bookUrl = urls[index].trim();
      if (bookUrl.length === 0) { continue; }

      const existingByUrl = await BookRepository.getBookByUrl(context, bookUrl);
      if (existingByUrl !== undefined && existingByUrl !== null) {
        successCount++;
        onProgress(successCount);
        continue;
      }

      const baseUrl = AddBookByUrlUseCase.baseUrlOf(bookUrl);
      if (baseUrl.length === 0) {
        failures.push(`${bookUrl}：网址格式不对`);
        continue;
      }

      const source = AddBookByUrlUseCase.sourceByBaseUrl(baseUrl)
        ?? AddBookByUrlUseCase.sourceByUrlPattern(bookUrl);
      if (source === undefined) {
        failures.push(`${bookUrl}：没有匹配的书源`);
        continue;
      }

      try {
        const engine = LegadoSourceMapper.fromLocal(source);
        const detail = await WebBookService.getBookInfo(engine, bookUrl);
        const same = await AddBookByUrlUseCase.findByTitleAuthor(context, detail.name, detail.author);
        if (same !== undefined) {
          const chapters: RemoteChapter[] = await WebBookService.getChapterList(
            engine, detail.tocUrl.length > 0 ? detail.tocUrl : bookUrl);
          const merged = AddBookByUrlUseCase.mergeInto(same, detail);
          await BookRepository.saveImportedBooks(context, [merged]);
          await BookRepository.saveChapters(context, merged.id,
            AddBookByUrlUseCase.chapterRowsOf(merged.id, chapters));
          addedBooks.push(merged);
        } else {
          const minOrder = await BookRepository.getMinOrder(context);
          const created = AddBookByUrlUseCase.bookOf(detail, minOrder - 1);
          await BookRepository.saveImportedBooks(context, [created]);
          addedBooks.push(created);
        }
        successCount++;
        onProgress(successCount);
      } catch (error) {
        const message = error instanceof Error ? error.message : String(error);
        failures.push(`${bookUrl}：${message}`);
        AppLog.put(`添加网址出错 ${bookUrl}: ${message}`);
      }
    }

    return { successCount, failures, addedBooks };
  }
}
