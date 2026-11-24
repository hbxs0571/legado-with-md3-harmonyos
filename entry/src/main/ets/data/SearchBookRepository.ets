import { relationalStore } from '@kit.ArkData';
import { SearchBookItem } from '../bookSource/SourceModels';
import { RdbStore } from './RdbStore';
import { RdbCodec } from './RdbCodec';

/**
 * 搜索结果缓存仓储（对应上游 `data/dao/SearchBookDao.kt` + `SearchRepository`）。
 *
 * 上游在探索页每抓一页就 `saveSearchBooksUseCase.save(result.books)`，
 * 把结果写进 searchBooks 表；这张表随后被换源（`changeSourceSearch`）、
 * 换封面（`getEnableHasCover`）、精确搜索（`getFirstByNameAuthor`）复用。
 * 本地原先完全不落库，探索页翻完即丢，这三条链路都拿不到数据。
 *
 * 表结构见 `RdbSchema.createSearchBooks`（v12）。
 * 写入口径对齐上游 `SearchBook` 的 `init { }`：kind 截 1000、intro 截 5000、
 * latestChapterTitle 截 200。
 */
export class SearchBookRepository {
  /** 上游 `BookType.text = 0b1000`。搜索结果都是文本书，固定写 8。 */
  private static readonly typeText: number = 8;
  /** 上游 `init` 里的三个截断长度。 */
  private static readonly kindLimit: number = 1000;
  private static readonly introLimit: number = 5000;
  private static readonly chapterTitleLimit: number = 200;

  /** 串行化写入，避免同页多批结果互相覆盖。 */
  private static saveQueue: Promise<void> = Promise.resolve();

  /** 上游 `SearchBookDao.getSearchBook(bookUrl)`。 */
  private static readonly selectByBookUrl: string =
    'SELECT * FROM searchBooks WHERE bookUrl = ?';

  /**
   * 上游 `SearchBookDao.getFirstByNameAuthor`：
   * `select * from searchBooks where name = :name and author = :author
   *  and origin in (select bookSourceUrl from book_sources) order by originOrder limit 1`
   */
  private static readonly selectFirstByNameAuthor: string =
    'SELECT * FROM searchBooks WHERE name = ? AND author = ? ' +
    'AND origin IN (SELECT bookSourceUrl FROM book_sources) ORDER BY originOrder LIMIT 1';

  /**
   * 上游 `SearchBookDao.getEnableHasCover`：书名作者精确、封面非空、书源启用，按 customOrder 排。
   * 上游把 customOrder 从 book_sources 里 inner join 出来当 originOrder 用，这里同样 join。
   */
  private static readonly selectEnableHasCover: string =
    'SELECT t1.* FROM searchBooks AS t1 INNER JOIN book_sources AS t2 ' +
    'ON t1.origin = t2.bookSourceUrl ' +
    "WHERE t1.name = ? AND t1.author = ? AND t1.coverUrl IS NOT NULL AND t1.coverUrl <> '' " +
    'AND t2.enabled = 1 ORDER BY t2.customOrder';

  /** 上游 `SearchBookDao.clearExpired(time)`：清掉 time 早于给定时刻的缓存。 */
  private static readonly deleteExpired: string = 'DELETE FROM searchBooks WHERE time < ?';

  /**
   * 批量写入搜索结果（上游 `SaveSearchBooksUseCase.save(books)`）。
   *
   * 冲突策略是 REPLACE：同一 bookUrl 再次搜到就刷新时间与章节名，
   * 与上游 `@Insert(onConflict = OnConflictStrategy.REPLACE)` 一致。
   * 没有 bookUrl 的条目直接跳过——它是主键，空值写进去会互相覆盖。
   */
  static async save(context: Context, books: SearchBookItem[]): Promise<void> {
    if (books.length === 0) { return; }
    const operation = SearchBookRepository.saveQueue.then(async (): Promise<void> => {
      const store = await RdbStore.getStore(context);
      const now = Date.now();
      for (const book of books) {
        if (book.bookUrl.length === 0) { continue; }
        const values: relationalStore.ValuesBucket = {
          'bookUrl': book.bookUrl,
          'origin': book.origin,
          'originName': book.originName,
          'type': SearchBookRepository.typeText,
          'name': book.name,
          'author': book.author,
          'kind': SearchBookRepository.clip(book.kind, SearchBookRepository.kindLimit),
          'coverUrl': book.coverUrl,
          'intro': SearchBookRepository.clip(book.intro, SearchBookRepository.introLimit),
          'wordCount': book.wordCount,
          'latestChapterTitle':
            SearchBookRepository.clip(book.lastChapter, SearchBookRepository.chapterTitleLimit),
          'tocUrl': book.tocUrl,
          'time': now,
          // 搜索结果没有变量表与耗时数据，与上游新建实例的默认值一致
          'originOrder': 0,
          'chapterWordCount': -1,
          'respondTime': -1
        };
        await store.insert(
          'searchBooks', values, relationalStore.ConflictResolution.ON_CONFLICT_REPLACE);
      }
    });
    SearchBookRepository.saveQueue = operation.catch(() => {});
    await operation;
  }

  /** 上游 `SearchBookDao.getSearchBook(bookUrl)`；没有返回 undefined。 */
  static async get(context: Context, bookUrl: string): Promise<SearchBookItem | undefined> {
    if (bookUrl.length === 0) { return undefined; }
    try {
      const store = await RdbStore.getStore(context);
      const resultSet = await store.querySql(
        SearchBookRepository.selectByBookUrl, [bookUrl]);
      try {
        if (!resultSet.goToNextRow()) { return undefined; }
        return SearchBookRepository.readRow(resultSet);
      } finally {
        resultSet.close();
      }
    } catch (error) {
      console.error(`搜索缓存读取失败：${error instanceof Error ? error.message : String(error)}`);
      return undefined;
    }
  }

  /** 上游 `SearchBookDao.getFirstByNameAuthor`；没有返回 undefined。 */
  static async firstByNameAuthor(
    context: Context, name: string, author: string
  ): Promise<SearchBookItem | undefined> {
    try {
      const store = await RdbStore.getStore(context);
      const resultSet = await store.querySql(
        SearchBookRepository.selectFirstByNameAuthor, [name, author]);
      try {
        if (!resultSet.goToNextRow()) { return undefined; }
        return SearchBookRepository.readRow(resultSet);
      } finally {
        resultSet.close();
      }
    } catch (error) {
      console.error(`搜索缓存读取失败：${error instanceof Error ? error.message : String(error)}`);
      return undefined;
    }
  }

  /** 上游 `SearchBookDao.getEnableHasCover`：换封面面板用它列出候选封面。 */
  static async enableHasCover(
    context: Context, name: string, author: string
  ): Promise<SearchBookItem[]> {
    try {
      const store = await RdbStore.getStore(context);
      const resultSet = await store.querySql(
        SearchBookRepository.selectEnableHasCover, [name, author]);
      try {
        const books: SearchBookItem[] = [];
        while (resultSet.goToNextRow()) {
          books.push(SearchBookRepository.readRow(resultSet));
        }
        return books;
      } finally {
        resultSet.close();
      }
    } catch (error) {
      console.error(`搜索缓存读取失败：${error instanceof Error ? error.message : String(error)}`);
      return [];
    }
  }

  /**
   * 上游 `SearchBookDao.clearExpired(time)`。
   * 上游没有定时清理任务，只有备份恢复后按时间裁一次；本地同样只在需要时显式调用。
   */
  static async clearExpired(context: Context, before: number): Promise<void> {
    const operation = SearchBookRepository.saveQueue.then(async (): Promise<void> => {
      const store = await RdbStore.getStore(context);
      await store.executeSql(SearchBookRepository.deleteExpired, [before]);
    });
    SearchBookRepository.saveQueue = operation.catch(() => {});
    await operation;
  }

  /** 上游 `init` 的 `take(n)`；n <= 0 视为不截断（上游 take 对非正数返回空串，这里跟随）。 */
  private static clip(value: string, limit: number): string {
    if (limit <= 0) { return ''; }
    return value.length > limit ? value.substring(0, limit) : value;
  }

  /** 把一行 searchBooks 读成 UI 层用的 SearchBookItem（字段名对齐 SourceModels）。 */
  private static readRow(resultSet: relationalStore.ResultSet): SearchBookItem {
    return {
      bookUrl: RdbCodec.text(resultSet, RdbCodec.column(resultSet, 'bookUrl')),
      origin: RdbCodec.text(resultSet, RdbCodec.column(resultSet, 'origin')),
      originName: RdbCodec.text(resultSet, RdbCodec.column(resultSet, 'originName')),
      name: RdbCodec.text(resultSet, RdbCodec.column(resultSet, 'name')),
      author: RdbCodec.text(resultSet, RdbCodec.column(resultSet, 'author')),
      kind: RdbCodec.text(resultSet, RdbCodec.column(resultSet, 'kind')),
      coverUrl: RdbCodec.text(resultSet, RdbCodec.column(resultSet, 'coverUrl')),
      intro: RdbCodec.text(resultSet, RdbCodec.column(resultSet, 'intro')),
      // 上游字段名是 latestChapterTitle，UI 层的 SearchBookItem 沿用 lastChapter
      lastChapter: RdbCodec.text(resultSet, RdbCodec.column(resultSet, 'latestChapterTitle')),
      wordCount: RdbCodec.text(resultSet, RdbCodec.column(resultSet, 'wordCount')),
      // updateTime 是搜索结果里的「更新于」文本，不是 time 列（time 是缓存写入时刻）
      updateTime: '',
      tocUrl: RdbCodec.text(resultSet, RdbCodec.column(resultSet, 'tocUrl'))
    };
  }
}
