import { preferences, relationalStore } from '@kit.ArkData';
import { ReaderBookmark } from '../model/ReaderBookmark';
import { RdbStore } from './RdbStore';
import { RdbCodec } from './RdbCodec';

/**
 * 书签仓储。
 *
 * 表结构对齐上游 Bookmark.kt：主键是 time（= 本地 createdAt），
 * 没有本地独有的 id / bookId 列。这两个字段在读出时按需反推：
 *   bookId  ← 从 bookUrl 取文件名去掉 .txt（本地书 bookUrl = <filesDir>/books/<bookId>.txt）
 *   id      ← bookId + '-' + time，与本地原有 id 格式一致
 * 这样 UI 层的 40 处 bookmark.id / bookmark.bookId 引用零改动。
 *
 * preferences 的旧解析逻辑保留在这里：搬迁要用，DB 不可用时 load 也要回退到它。
 */
export class ReaderBookmarkRepository {
  private static readonly preferenceName: string = 'legado_reader_bookmarks';
  private static saveQueue: Promise<void> = Promise.resolve();

  /** 上游 BookmarkDao.all 的排序：书名、作者按拼音，再按章节与章内位置。 */
  private static readonly selectAll: string =
    'SELECT time, bookName, bookAuthor, bookUrl, chapterIndex, chapterPos, ' +
    'chapterName, bookText, content FROM bookmarks ' +
    'ORDER BY bookName COLLATE LOCALES, bookAuthor COLLATE LOCALES, chapterIndex, chapterPos';

  static async load(context: Context): Promise<ReaderBookmark[]> {
    try {
      const store = await RdbStore.getStore(context);
      const resultSet = await store.querySql(ReaderBookmarkRepository.selectAll);
      try {
        return ReaderBookmarkRepository.readAll(resultSet);
      } finally {
        resultSet.close();
      }
    } catch (error) {
      // 不再回退读 preferences：老数据已由 RdbCleanup 清掉，回退只会读到空。
      // 记日志并返回空表，调用方按「没有书签」处理，与上游 DAO 读到空表一致。
      console.error(`书签读取失败：${error instanceof Error ? error.message : String(error)}`);
      return [];
    }
  }

  static save(context: Context, bookmarks: ReaderBookmark[]): Promise<void> {
    const operation = ReaderBookmarkRepository.saveQueue.then(async (): Promise<void> => {
      const store = await RdbStore.getStore(context);
      store.beginTransaction();
      try {
        await ReaderBookmarkRepository.replaceAll(store, bookmarks);
        store.commit();
      } catch (error) {
        store.rollBack();
        throw error as Error;
      }
    });
    ReaderBookmarkRepository.saveQueue = operation.catch(() => {});
    return operation;
  }

  /**
   * 搬迁：把 preferences 里的老数据写入 DB。
   * 由 RdbMigration 在它自己的事务里调用，所以这里不再开事务（嵌套事务会报错）。
   */
  static async migrateFromPreferences(context: Context, store: relationalStore.RdbStore): Promise<void> {
    const bookmarks = await ReaderBookmarkRepository.loadFromPreferences(context);
    await ReaderBookmarkRepository.replaceAll(store, bookmarks);
  }

  /** 整表重写：先清空再逐条插入。事务由调用方负责。 */
  private static async replaceAll(
    store: relationalStore.RdbStore,
    bookmarks: ReaderBookmark[]
  ): Promise<void> {
    await store.executeSql('DELETE FROM bookmarks');
    // 主键 time 可能撞车（同毫秒创建），用已占用的集合递增消解
    const usedTimes: Set<number> = new Set<number>();
    for (let index = 0; index < bookmarks.length; index++) {
      const bookmark = bookmarks[index];
      if (bookmark === undefined) { continue; }
      const time = ReaderBookmarkRepository.uniqueTime(usedTimes, bookmark.createdAt);
      const values: relationalStore.ValuesBucket = {
        'time': time,
        'bookName': bookmark.bookName,
        'bookAuthor': bookmark.bookAuthor,
        'bookUrl': bookmark.bookUrl,
        'chapterIndex': bookmark.chapterIndex,
        'chapterPos': bookmark.chapterPosition,
        'chapterName': bookmark.chapterName,
        'bookText': bookmark.bookText,
        'content': bookmark.content
      };
      await store.insert('bookmarks', values, relationalStore.ConflictResolution.ON_CONFLICT_REPLACE);
    }
  }

  /** 取一个未被占用的时间戳：撞车时 +1 直到空闲。 */
  private static uniqueTime(usedTimes: Set<number>, candidate: number): number {
    let time = Number.isFinite(candidate) && candidate > 0 ? Math.trunc(candidate) : Date.now();
    while (usedTimes.has(time)) {
      time += 1;
    }
    usedTimes.add(time);
    return time;
  }

  /** 结果集 → 模型。列下标先取一次复用，避免每行都查列名。 */
  private static readAll(resultSet: relationalStore.ResultSet): ReaderBookmark[] {
    const timeIndex = RdbCodec.column(resultSet, 'time');
    const bookNameIndex = RdbCodec.column(resultSet, 'bookName');
    const bookAuthorIndex = RdbCodec.column(resultSet, 'bookAuthor');
    const bookUrlIndex = RdbCodec.column(resultSet, 'bookUrl');
    const chapterIndexIndex = RdbCodec.column(resultSet, 'chapterIndex');
    const chapterPosIndex = RdbCodec.column(resultSet, 'chapterPos');
    const chapterNameIndex = RdbCodec.column(resultSet, 'chapterName');
    const bookTextIndex = RdbCodec.column(resultSet, 'bookText');
    const contentIndex = RdbCodec.column(resultSet, 'content');
    const bookmarks: ReaderBookmark[] = [];
    while (resultSet.goToNextRow()) {
      const time = RdbCodec.integer(resultSet, timeIndex);
      const bookUrl = RdbCodec.text(resultSet, bookUrlIndex);
      const bookId = ReaderBookmarkRepository.bookIdFromBookUrl(bookUrl);
      bookmarks.push({
        id: `${bookId}-${time.toString()}`,
        bookId: bookId,
        bookName: RdbCodec.text(resultSet, bookNameIndex),
        bookAuthor: RdbCodec.text(resultSet, bookAuthorIndex),
        bookUrl: bookUrl,
        chapterIndex: RdbCodec.integer(resultSet, chapterIndexIndex),
        chapterName: RdbCodec.text(resultSet, chapterNameIndex),
        chapterPosition: RdbCodec.integer(resultSet, chapterPosIndex),
        bookText: RdbCodec.text(resultSet, bookTextIndex),
        content: RdbCodec.text(resultSet, contentIndex),
        createdAt: time
      });
    }
    return bookmarks;
  }

  /**
   * 从 bookUrl 反推 bookId。
   * 本地书的 bookUrl 是 <filesDir>/books/<bookId>.txt，取文件名去后缀即可；
   * 从 Android 导入的书 bookUrl 是原始路径，退而取文件名本身。
   */
  private static bookIdFromBookUrl(bookUrl: string): string {
    if (bookUrl.length === 0) { return ''; }
    const slash = bookUrl.lastIndexOf('/');
    const fileName = slash >= 0 ? bookUrl.substring(slash + 1) : bookUrl;
    return fileName.endsWith('.txt') ? fileName.substring(0, fileName.length - 4) : fileName;
  }

  /**
   * 旧 preferences 解析。格式：`v1\n` 头 + 每行 11 字段用 | 分隔、每字段 encodeURIComponent，
   * 字段序 [id, bookId, bookName, bookAuthor, bookUrl, chapterIndex, chapterName,
   * chapterPosition, bookText, content, createdAt]。
   * 搬迁与 DB 回退都用这份逻辑，保持与迁移前完全一致。
   */
  private static async loadFromPreferences(context: Context): Promise<ReaderBookmark[]> {
    try {
      const store = await preferences.getPreferences(context, ReaderBookmarkRepository.preferenceName);
      const value = await store.get('records', 'v1\n');
      if (typeof value !== 'string' || !value.startsWith('v1\n')) { return []; }
      const rows = value.substring(3).split('\n');
      const bookmarks: ReaderBookmark[] = [];
      for (let index = 0; index < rows.length; index++) {
        const row = rows[index];
        if (row === undefined || row.length === 0) { continue; }
        const fields = row.split('|');
        if (fields.length !== 11) { continue; }
        try {
          const chapterIndex = Number(fields[5]);
          const chapterPosition = Number(fields[7]);
          const createdAt = Number(fields[10]);
          if (!Number.isInteger(chapterIndex) || chapterIndex < 0 ||
            !Number.isInteger(chapterPosition) || chapterPosition < 0 ||
            !Number.isFinite(createdAt) || createdAt <= 0) { continue; }
          bookmarks.push({
            id: decodeURIComponent(fields[0]),
            bookId: decodeURIComponent(fields[1]),
            bookName: decodeURIComponent(fields[2]),
            bookAuthor: decodeURIComponent(fields[3]),
            bookUrl: decodeURIComponent(fields[4]),
            chapterIndex: chapterIndex,
            chapterName: decodeURIComponent(fields[6]),
            chapterPosition: chapterPosition,
            bookText: decodeURIComponent(fields[8]),
            content: decodeURIComponent(fields[9]),
            createdAt: createdAt
          });
        } catch (_) {
          continue;
        }
      }
      return bookmarks;
    } catch (_) {
      return [];
    }
  }
}
