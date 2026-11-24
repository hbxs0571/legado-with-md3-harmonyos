import { Book } from '../model/Book';
import { BookSource } from '../model/BookSource';
import { BookRepository } from '../data/BookRepository';
import { BookSourceRepository } from '../data/BookSourceRepository';
import { LegadoSourceMapper } from './LegadoSourceMapper';
import { WebBookService } from './WebBookService';
import { SearchBookItem } from './SourceModels';

/**
 * 书单导入时的「按书源精确搜索补全」，对应上游
 * `WebBook.preciseSearchAwait`（model/webBook/WebBook.kt:475-494）与
 * `ImportBookshelfUseCase.importByJson`（domain/usecase/ImportBookshelfUseCase.kt:66-109）。
 *
 * 上游判据是「搜索结果里 name 与 author 都严格相等」才算命中，取第一条；搜不到就
 * 不入库，只 toast「没有搜索到<书名><作者>」。本地照此实现——不再像以前那样落一条
 * 「缺正文」的本地书目记录冒充导入成功。
 *
 * 并发口径：上游用 `Semaphore(threadCount)` 让「多本书」并行，单本书内部是按书源
 * 顺序串行、命中即 break。本地没有 threadCount 设置，固定 8 路，与
 * ChangeSourceCoordinator / ChangeCoverCoordinator 同口径。
 */
export const PRECISE_SEARCH_CONCURRENCY: number = 8;

/** 一条书单条目的补全结果。 */
export interface PreciseSearchOutcome {
  /** 搜到并转成本地在线书目的条目。 */
  books: Book[];
  /** 所有启用书源都没搜到的「书名 作者」，用于逐条提示。 */
  missing: string[];
}

/** 待补全的一条书单条目。 */
export interface PreciseSearchEntry {
  name: string;
  author: string;
  intro: string;
}

export class PreciseSearchCoordinator {
  /**
   * 单本书：按 customOrder 顺序逐个源精确搜索，命中即停。
   * 与上游 `for (s in bookSourceParts) { foundBook = preciseSearchAwait(...); if (foundBook != null) break }` 一致。
   */
  static async searchOne(name: string, author: string): Promise<Book | undefined> {
    if (name.length === 0) { return undefined; }
    const all: BookSource[] = BookSourceRepository.getAll();
    const targetSources: BookSource[] = all.filter((source: BookSource) =>
      source.enabled === true && source.bookSourceType === 0 && source.bookSourceUrl.length > 0);
    targetSources.sort((a: BookSource, b: BookSource) => a.customOrder - b.customOrder);
    const keyword: string = author.length > 0 ? `${name} ${author}` : name;
    for (let index = 0; index < targetSources.length; index++) {
      const source = targetSources[index];
      const hit = await PreciseSearchCoordinator.probe(source, name, author, keyword);
      if (hit !== undefined) {
        return hit;
      }
    }
    return undefined;
  }

  /** 单个书源探一次：取搜索结果第一条，name/author 严格相等才算命中。 */
  private static async probe(source: BookSource, name: string, author: string,
    keyword: string): Promise<Book | undefined> {
    try {
      const engine = LegadoSourceMapper.fromSourceJson(source.sourceJson);
      const books: SearchBookItem[] = await WebBookService.searchBook(engine, keyword, 1);
      if (books.length === 0) {
        return undefined;
      }
      const first = books[0];
      // 上游 filter = { fName, fAuthor, _ -> fName == name && fAuthor == author }，两个字段都要严格相等。
      if (first.name !== name || first.author !== author) {
        return undefined;
      }
      return PreciseSearchCoordinator.toBook(first, name, author);
    } catch (error) {
      return undefined;
    }
  }

  /**
   * 搜索结果转本地在线书目。
   *
   * 字段口径照 `Index.onlineBookFromSearch`（同一批搜索结果的落地方式），只把
   * `order` 固定成 0——上游 `importByJson` 里 `bookRepository.insert(book)` 用的就是
   * Book 的默认 order（0），没有重排。
   */
  static toBook(item: SearchBookItem, name: string, author: string): Book {
    const bookUrl: string = item.bookUrl;
    const book: Book = {
      id: BookRepository.bookIdFromUrl(bookUrl),
      title: name.length > 0 ? name : item.name,
      author: author.length > 0 ? author : item.author,
      category: item.kind,
      kind: item.kind.length > 0 ? item.kind : undefined,
      lastChapter: item.lastChapter,
      progress: 0,
      chapterIndex: 0,
      chapterCount: '0',
      wordCount: item.wordCount.length > 0 ? item.wordCount : undefined,
      latestChapterTitle: item.lastChapter.length > 0 ? item.lastChapter : undefined,
      coverUri: item.coverUrl.length > 0 ? item.coverUrl : undefined,
      contentPath: bookUrl,
      isLocal: false,
      origin: item.origin,
      originName: item.originName,
      tocUrl: item.tocUrl.length > 0 ? item.tocUrl : bookUrl,
      notShelf: false,
      order: 0
    };
    return book;
  }

  /**
   * 批量补全：8 路并发跑条目，每本书内部仍按书源顺序串行。
   *
   * `existing` 里已有同名同作者的书直接跳过（上游 `bookRepository.getBook(name, author) != null`
   * 就不处理），既不进 books 也不进 missing。
   */
  static async searchMany(entries: PreciseSearchEntry[], existing: Book[],
    onProgress: (done: number, total: number) => void): Promise<PreciseSearchOutcome> {
    const result: PreciseSearchOutcome = { books: [], missing: [] };
    const pending: PreciseSearchEntry[] = [];
    const seen: string[] = [];
    for (let index = 0; index < entries.length; index++) {
      const entry = entries[index];
      if (entry === undefined || entry.name.length === 0) { continue; }
      const key = `${entry.name}\u0000${entry.author}`;
      if (seen.indexOf(key) >= 0) { continue; }
      seen.push(key);
      const duplicated = existing.some((book: Book) =>
        book.title === entry.name && book.author === entry.author);
      if (duplicated) { continue; }
      pending.push(entry);
    }
    const total: number = pending.length;
    if (total === 0) {
      onProgress(0, 0);
      return result;
    }
    let cursor: number = 0;
    let done: number = 0;
    const worker = async (): Promise<void> => {
      while (cursor < pending.length) {
        const index = cursor;
        cursor++;
        const entry = pending[index];
        const found = await PreciseSearchCoordinator.searchOne(entry.name, entry.author);
        if (found !== undefined) {
          result.books.push(found);
        } else {
          result.missing.push(entry.author.length > 0 ? `${entry.name} ${entry.author}` : entry.name);
        }
        done++;
        onProgress(done, total);
      }
    };
    const workers: Promise<void>[] = [];
    for (let index = 0; index < PRECISE_SEARCH_CONCURRENCY && index < total; index++) {
      workers.push(worker());
    }
    await Promise.all(workers);
    return result;
  }
}
