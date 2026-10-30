import { preferences, relationalStore } from '@kit.ArkData';
import { Book } from '../model/Book';
import { ReaderSearchHistoryEntry } from '../model/ReaderSearchHistory';
import { RdbStore } from './RdbStore';
import { RdbCodec } from './RdbCodec';

/**
 * 搜索历史仓储。
 *
 * 表结构对齐上游 SearchContentHistory.kt：主键 id 自增，索引 (bookName, bookAuthor, query) UNIQUE。
 * 上游没有 bookId 列，所以「按书过滤」改用书名 + 作者——
 * 这与上游 SearchContentHistoryDao.getByBook 完全一致，也与上游已知问题
 * （同名同作者的两本书共享搜索历史）保持一致，本批不修。
 *
 * 本地 id 原本是 `bookId|query` 拼出来的字符串，现在由库自增生成，
 * 读出时转成字符串交给 UI，id 只用于列表 key 与删除定位，不参与业务判断。
 */
export class ReaderSearchHistoryRepository {
  private static readonly preferenceName: string = 'legado_reader_search_history';
  private static readonly preferenceKey: string = 'records_v1';
  private static saveQueue: Promise<void> = Promise.resolve();

  /** 上游 SearchContentHistoryDao.getAll：按时间倒序。 */
  private static readonly selectAll: string =
    'SELECT id, bookName, bookAuthor, query, time FROM search_content_history ORDER BY time DESC';

  static async load(context: Context): Promise<ReaderSearchHistoryEntry[]> {
    try {
      const store = await RdbStore.getStore(context);
      const resultSet = await store.querySql(ReaderSearchHistoryRepository.selectAll);
      try {
        return ReaderSearchHistoryRepository.readAll(resultSet);
      } finally {
        resultSet.close();
      }
    } catch (_) {
      return ReaderSearchHistoryRepository.loadFromPreferences(context);
    }
  }

  /**
   * 记录一次搜索。
   * 上游靠 UNIQUE 索引 + onConflict=REPLACE 实现「同书同词只留一条」，
   * 这里同样用 ON_CONFLICT_REPLACE，冲突时 time 被更新成当前时间。
   */
  static async saveQuery(context: Context, book: Book, query: string): Promise<ReaderSearchHistoryEntry[]> {
    const normalized = query.trim();
    if (normalized.length === 0) { return ReaderSearchHistoryRepository.load(context); }
    const operation = ReaderSearchHistoryRepository.saveQueue.then(async (): Promise<void> => {
      const store = await RdbStore.getStore(context);
      const values: relationalStore.ValuesBucket = {
        'bookName': book.title,
        'bookAuthor': book.author,
        'query': normalized,
        'time': Date.now()
      };
      await store.insert(
        'search_content_history', values, relationalStore.ConflictResolution.ON_CONFLICT_REPLACE);
    });
    ReaderSearchHistoryRepository.saveQueue = operation.catch(() => {});
    await operation;
    return ReaderSearchHistoryRepository.load(context);
  }

  static async delete(context: Context, id: string): Promise<ReaderSearchHistoryEntry[]> {
    const numericId = Number.parseInt(id, 10);
    if (Number.isInteger(numericId)) {
      const operation = ReaderSearchHistoryRepository.saveQueue.then(async (): Promise<void> => {
        const store = await RdbStore.getStore(context);
        await store.executeSql('DELETE FROM search_content_history WHERE id = ?', [numericId]);
      });
      ReaderSearchHistoryRepository.saveQueue = operation.catch(() => {});
      await operation;
    }
    return ReaderSearchHistoryRepository.load(context);
  }

  /**
   * 清空搜索历史。
   * 上游 deleteByBook 用 bookName + bookAuthor 定位，本方法签名与之对齐
   * （原签名是 bookId，因表里没有该列而不得不改；全项目仅 ReaderSearchPage 一处调用）。
   */
  static async clear(
    context: Context,
    bookName: string,
    bookAuthor: string,
    onlyThisBook: boolean
  ): Promise<ReaderSearchHistoryEntry[]> {
    const operation = ReaderSearchHistoryRepository.saveQueue.then(async (): Promise<void> => {
      const store = await RdbStore.getStore(context);
      if (onlyThisBook) {
        await store.executeSql(
          'DELETE FROM search_content_history WHERE bookName = ? AND bookAuthor = ?',
          [bookName, bookAuthor]);
      } else {
        await store.executeSql('DELETE FROM search_content_history');
      }
    });
    ReaderSearchHistoryRepository.saveQueue = operation.catch(() => {});
    await operation;
    return ReaderSearchHistoryRepository.load(context);
  }

  /** 搬迁：由 RdbMigration 在它自己的事务里调用，所以这里不再开事务。 */
  static async migrateFromPreferences(context: Context, store: relationalStore.RdbStore): Promise<void> {
    const entries = await ReaderSearchHistoryRepository.loadFromPreferences(context);
    await store.executeSql('DELETE FROM search_content_history');
    for (let index = 0; index < entries.length; index++) {
      const entry = entries[index];
      if (entry === undefined) { continue; }
      const values: relationalStore.ValuesBucket = {
        'bookName': entry.bookName,
        'bookAuthor': entry.bookAuthor,
        'query': entry.query,
        'time': entry.updatedAt
      };
      await store.insert(
        'search_content_history', values, relationalStore.ConflictResolution.ON_CONFLICT_REPLACE);
    }
  }

  private static readAll(resultSet: relationalStore.ResultSet): ReaderSearchHistoryEntry[] {
    const idIndex = RdbCodec.column(resultSet, 'id');
    const bookNameIndex = RdbCodec.column(resultSet, 'bookName');
    const bookAuthorIndex = RdbCodec.column(resultSet, 'bookAuthor');
    const queryIndex = RdbCodec.column(resultSet, 'query');
    const timeIndex = RdbCodec.column(resultSet, 'time');
    const entries: ReaderSearchHistoryEntry[] = [];
    while (resultSet.goToNextRow()) {
      const query = RdbCodec.text(resultSet, queryIndex);
      // 空查询词没有展示价值，与迁移前的过滤口径一致
      if (query.trim().length === 0) { continue; }
      entries.push({
        id: RdbCodec.integer(resultSet, idIndex).toString(),
        bookName: RdbCodec.text(resultSet, bookNameIndex),
        bookAuthor: RdbCodec.text(resultSet, bookAuthorIndex),
        query: query,
        updatedAt: RdbCodec.integer(resultSet, timeIndex)
      });
    }
    return entries;
  }

  /**
   * 旧 preferences 解析（JSON 数组）。
   * 搬迁与 DB 回退共用；老数据的 bookId 字段直接丢弃——
   * 表结构对齐上游后没有这一列，而按书名 + 作者过滤与上游行为一致。
   */
  private static async loadFromPreferences(context: Context): Promise<ReaderSearchHistoryEntry[]> {
    try {
      const store = await preferences.getPreferences(context, ReaderSearchHistoryRepository.preferenceName);
      const saved = await store.get(ReaderSearchHistoryRepository.preferenceKey, '[]');
      if (typeof saved !== 'string') { return []; }
      const parsed: ReaderSearchHistoryEntry[] = JSON.parse(saved);
      const entries: ReaderSearchHistoryEntry[] = [];
      for (let index = 0; index < parsed.length; index++) {
        const entry = parsed[index];
        if (entry === undefined || entry === null) { continue; }
        if (typeof entry.bookName !== 'string' || typeof entry.bookAuthor !== 'string' ||
          typeof entry.query !== 'string' || !Number.isFinite(entry.updatedAt)) { continue; }
        if (entry.query.trim().length === 0) { continue; }
        entries.push({
          id: typeof entry.id === 'string' ? entry.id : '',
          bookName: entry.bookName,
          bookAuthor: entry.bookAuthor,
          query: entry.query,
          updatedAt: entry.updatedAt
        });
      }
      return entries.sort((left: ReaderSearchHistoryEntry, right: ReaderSearchHistoryEntry) =>
        right.updatedAt - left.updatedAt);
    } catch (_) {
      return [];
    }
  }
}
