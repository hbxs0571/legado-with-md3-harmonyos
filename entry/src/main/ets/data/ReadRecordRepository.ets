import { preferences, relationalStore } from '@kit.ArkData';
import { Book } from '../model/Book';
import { ReadRecordDetail, ReadRecordRepairReport, ReadRecordSession, ReadRecordSummary, ReadTimeRecord } from '../model/ReadRecord';
import { RdbCodec } from './RdbCodec';
import { RdbSchema } from './RdbSchema';
import { RdbStore } from './RdbStore';

/** 由会话派生的两层数据：按日明细与书籍汇总。 */
interface ReadRecordDerived {
  details: ReadRecordDetail[];
  summaries: ReadRecordSummary[];
}

/** 备份写出/恢复用的三张表快照，字段名与上游 Room 实体一致。 */
export interface ReadRecordBackupSnapshot {
  summaries: ReadRecordSummary[];
  details: ReadRecordDetail[];
  sessions: ReadRecordSession[];
}

/**
 * 阅读记录仓储，对应上游 io.legado.app.data.repository.ReadRecordRepository。
 *
 * 三层结构（会话 / 按日明细 / 书籍汇总）分别落在三张表里：
 * - `readRecordSession`：一次连续阅读一行，是唯一的权威数据源；
 * - `readRecordDetail`：按「书名 + 作者 + 日期」聚合，跨午夜的会话会被切到两个日期；
 * - `readRecord`：按「书名 + 作者」聚合的累计时长。
 *
 * 明细与汇总都能从会话重算出来，这样做是为了和上游的读写路径一致，
 * 备份文件（readRecord.json / readRecordDetail.json / readRecordSession.json）可以直接映射。
 *
 * 列名陷阱：上游把「本次阅读时所在的章节序号」存进 `readRecordSession.words` 列，
 * 列名写着 words 但语义是章节序号，读取时要映射回模型的 chapterIndex。
 */
export class ReadRecordRepository {
  /** 阅读记录总开关仍留在 preferences：上游同样放在 localPreferences，不进数据库。 */
  private static readonly preferenceName: string = 'legado_read_records';
  private static readonly enabledKey: string = 'enabled';
  /** 老版本的会话文本键，只在搬迁时读一次。 */
  private static readonly legacySessionsKey: string = 'sessions_v1';
  /** 删除确认「不再提醒」长期档，键名与上游 READ_RECORD_SKIP_DELETE_CONFIRM 一致。 */
  private static readonly skipDeleteConfirmKey: string = 'readRecordSkipDeleteConfirm';
  /** 作者为空的旧记录归属决定，键名与上游 READ_RECORD_ALIAS_DECISIONS 一致。 */
  private static readonly aliasDecisionsKey: string = 'readRecordAliasDecisions';
  /** 归属决定里 key 与 MERGE/KEEP 的分隔符，与上游 ReadRecordAliasDecision.SEPARATOR 一致。 */
  private static readonly aliasDecisionSeparator: string = '\u0001';

  private static readonly selectSessions: string =
    'SELECT `deviceId`, `bookName`, `bookAuthor`, `bookUrl`, `startTime`, `endTime`, `words` ' +
      'FROM `readRecordSession`';
  private static readonly selectDetails: string =
    'SELECT `deviceId`, `bookName`, `bookAuthor`, `date`, `readTime`, `readWords`, ' +
      '`firstReadTime`, `lastReadTime` FROM `readRecordDetail`';
  private static readonly selectSummaries: string =
    'SELECT `deviceId`, `bookName`, `bookAuthor`, `readTime`, `lastRead` FROM `readRecord`';
  private static readonly insertSession: string =
    'INSERT OR REPLACE INTO `readRecordSession` ' +
      '(`deviceId`, `bookName`, `bookAuthor`, `bookUrl`, `startTime`, `endTime`, `words`) ' +
      'VALUES (?, ?, ?, ?, ?, ?, ?)';
  private static readonly insertDetail: string =
    'INSERT OR REPLACE INTO `readRecordDetail` ' +
      '(`deviceId`, `bookName`, `bookAuthor`, `date`, `readTime`, `readWords`, ' +
      '`firstReadTime`, `lastReadTime`) VALUES (?, ?, ?, ?, ?, ?, ?, ?)';
  private static readonly insertSummary: string =
    'INSERT OR REPLACE INTO `readRecord` ' +
      '(`deviceId`, `bookName`, `bookAuthor`, `readTime`, `lastRead`) VALUES (?, ?, ?, ?, ?)';
  private static readonly deleteSessions: string = 'DELETE FROM `readRecordSession`';
  private static readonly deleteDetails: string = 'DELETE FROM `readRecordDetail`';
  private static readonly deleteSummaries: string = 'DELETE FROM `readRecord`';
  private static readonly deleteSessionsByBook: string =
    'DELETE FROM `readRecordSession` WHERE `bookName` = ? AND `bookAuthor` = ?';
  private static readonly deleteDetailsByBook: string =
    'DELETE FROM `readRecordDetail` WHERE `bookName` = ? AND `bookAuthor` = ?';
  private static readonly deleteSummaryByBook: string =
    'DELETE FROM `readRecord` WHERE `bookName` = ? AND `bookAuthor` = ?';
  /** 按会话的完整复合键删一条会话（选择模式的时间线条目）。 */
  private static readonly deleteSessionByExactKey: string =
    'DELETE FROM `readRecordSession` WHERE `bookName` = ? AND `bookAuthor` = ? ' +
    'AND `bookUrl` = ? AND `startTime` = ? AND `endTime` = ?';
  /**
   * 按「设备 + 书名 + 作者 + 自然日」删该日的会话（选择模式的汇总条目）。
   * 日期口径与上游 ReadRecordDao.kt:355-366 一致：用 localtime 把 startTime 转成 yyyy-MM-dd 后比较。
   */
  private static readonly deleteSessionsByBookAndDate: string =
    'DELETE FROM `readRecordSession` WHERE `deviceId` = ? AND `bookName` = ? AND `bookAuthor` = ? ' +
    "AND STRFTIME('%Y-%m-%d', datetime(`startTime` / 1000, 'unixepoch', 'localtime')) = ?";
  /** 单独禁用判定：取精确命中行与全部禁用行，由调用方按文件名派生规则比对。 */
  private static readonly selectDisableReadRecord: string =
    'SELECT `bookUrl`, `disableReadRecord` FROM `books` ' +
    'WHERE `bookUrl` = ? OR `disableReadRecord` = 1';

  /** 一次阅读不足这个时长就不记账，对应上游 ReadBook.MIN_READ_DURATION。 */
  static readonly minimumReadDurationMs: number = 10 * 1000;
  /** 自动提交间隔，对应上游 ReadBook.AUTO_SAVE_INTERVAL。 */
  static readonly autoSaveIntervalMs: number = 120 * 1000;
  /** 连续会话合并阈值，对应上游 CONTINUOUS_READ_SESSION_GAP_MILLIS。 */
  static readonly continuousSessionGapMs: number = 20 * 60 * 1000;

  private static saveQueue: Promise<void> = Promise.resolve();

  // ---- 当前进行中的会话（内存态，对应上游 ReadBook.currentActiveSession） ----
  private static activeBookId: string = '';
  private static activeBookName: string = '';
  private static activeBookAuthor: string = '';
  private static activeStartTime: number = 0;
  private static activeEndTime: number = 0;
  private static activeChapterIndex: number = 0;

  /**
   * 阅读记录总开关，对应上游 localPreferences 里的 readRecordEnabled。
   *
   * 写入是异步的，读取走内存缓存：saveSession 在热路径上需要同步判断。
   * 应用启动时调 loadEnabled 把持久化值读进缓存。
   */
  private static enabledCache: boolean = true;

  static isEnabled(): boolean {
    return ReadRecordRepository.enabledCache;
  }

  static async loadEnabled(context: Context): Promise<boolean> {
    try {
      const store = await preferences.getPreferences(context, ReadRecordRepository.preferenceName);
      const value = await store.get(ReadRecordRepository.enabledKey, '1');
      ReadRecordRepository.enabledCache = value !== '0';
    } catch (_) {
      ReadRecordRepository.enabledCache = true;
    }
    return ReadRecordRepository.enabledCache;
  }

  static async setEnabled(context: Context, enabled: boolean): Promise<void> {
    if (!enabled) {
      await ReadRecordRepository.saveQueue;
      ReadRecordRepository.discardActive();
    }
    ReadRecordRepository.enabledCache = enabled;
    await ReadRecordRepository.putEnabled(context, enabled ? '1' : '0');
  }

  // ---------------------------------------------------------------- 读

  static async loadSessions(context: Context): Promise<ReadRecordSession[]> {
    try {
      const store = await RdbStore.getStore(context);
      await RdbSchema.ensure(store);
      const resultSet = await store.querySql(ReadRecordRepository.selectSessions);
      try {
        return ReadRecordRepository.readSessions(resultSet);
      } finally {
        resultSet.close();
      }
    } catch (_) {
      return [];
    }
  }

  static async loadDetails(context: Context): Promise<ReadRecordDetail[]> {
    try {
      const store = await RdbStore.getStore(context);
      await RdbSchema.ensure(store);
      const resultSet = await store.querySql(ReadRecordRepository.selectDetails);
      try {
        return ReadRecordRepository.readDetails(resultSet);
      } finally {
        resultSet.close();
      }
    } catch (_) {
      return [];
    }
  }

  static async loadSummaries(context: Context): Promise<ReadRecordSummary[]> {
    try {
      const store = await RdbStore.getStore(context);
      await RdbSchema.ensure(store);
      const resultSet = await store.querySql(ReadRecordRepository.selectSummaries);
      try {
        return ReadRecordRepository.readSummaries(resultSet);
      } finally {
        resultSet.close();
      }
    } catch (_) {
      return [];
    }
  }

  /** 结果集 → 会话列表。列名与 selectSessions 一致，`words` 列读成 chapterIndex。 */
  private static readSessions(resultSet: relationalStore.ResultSet): ReadRecordSession[] {
    const deviceIdIndex = RdbCodec.column(resultSet, 'deviceId');
    const bookNameIndex = RdbCodec.column(resultSet, 'bookName');
    const bookAuthorIndex = RdbCodec.column(resultSet, 'bookAuthor');
    const bookUrlIndex = RdbCodec.column(resultSet, 'bookUrl');
    const startTimeIndex = RdbCodec.column(resultSet, 'startTime');
    const endTimeIndex = RdbCodec.column(resultSet, 'endTime');
    const wordsIndex = RdbCodec.column(resultSet, 'words');
    const sessions: ReadRecordSession[] = [];
    while (resultSet.goToNextRow()) {
      const startTime = RdbCodec.integer(resultSet, startTimeIndex);
      const endTime = RdbCodec.integer(resultSet, endTimeIndex);
      // 起止时间倒置的行直接丢掉：它们是历史数据里的坏行，参与统计只会让时长变成负数
      if (endTime <= startTime) { continue; }
      sessions.push({
        deviceId: RdbCodec.text(resultSet, deviceIdIndex),
        bookName: RdbCodec.text(resultSet, bookNameIndex),
        bookAuthor: RdbCodec.text(resultSet, bookAuthorIndex),
        bookUrl: RdbCodec.text(resultSet, bookUrlIndex),
        startTime: startTime,
        endTime: endTime,
        chapterIndex: RdbCodec.integer(resultSet, wordsIndex)
      });
    }
    return sessions.sort((left: ReadRecordSession, right: ReadRecordSession) => right.endTime - left.endTime);
  }

  /** 结果集 → 按日明细。列名与 selectDetails 一致。 */
  private static readDetails(resultSet: relationalStore.ResultSet): ReadRecordDetail[] {
    const deviceIdIndex = RdbCodec.column(resultSet, 'deviceId');
    const bookNameIndex = RdbCodec.column(resultSet, 'bookName');
    const bookAuthorIndex = RdbCodec.column(resultSet, 'bookAuthor');
    const dateIndex = RdbCodec.column(resultSet, 'date');
    const readTimeIndex = RdbCodec.column(resultSet, 'readTime');
    const readWordsIndex = RdbCodec.column(resultSet, 'readWords');
    const firstReadTimeIndex = RdbCodec.column(resultSet, 'firstReadTime');
    const lastReadTimeIndex = RdbCodec.column(resultSet, 'lastReadTime');
    const details: ReadRecordDetail[] = [];
    while (resultSet.goToNextRow()) {
      const readTime = RdbCodec.integer(resultSet, readTimeIndex);
      if (readTime <= 0) { continue; }
      details.push({
        deviceId: RdbCodec.text(resultSet, deviceIdIndex),
        bookName: RdbCodec.text(resultSet, bookNameIndex),
        bookAuthor: RdbCodec.text(resultSet, bookAuthorIndex),
        date: RdbCodec.text(resultSet, dateIndex),
        readTime: readTime,
        readWords: RdbCodec.integer(resultSet, readWordsIndex),
        firstReadTime: RdbCodec.integer(resultSet, firstReadTimeIndex),
        lastReadTime: RdbCodec.integer(resultSet, lastReadTimeIndex)
      });
    }
    return details.sort((left: ReadRecordDetail, right: ReadRecordDetail) => right.date.localeCompare(left.date));
  }

  /** 结果集 → 书籍汇总。列名与 selectSummaries 一致。 */
  private static readSummaries(resultSet: relationalStore.ResultSet): ReadRecordSummary[] {
    const deviceIdIndex = RdbCodec.column(resultSet, 'deviceId');
    const bookNameIndex = RdbCodec.column(resultSet, 'bookName');
    const bookAuthorIndex = RdbCodec.column(resultSet, 'bookAuthor');
    const readTimeIndex = RdbCodec.column(resultSet, 'readTime');
    const lastReadIndex = RdbCodec.column(resultSet, 'lastRead');
    const summaries: ReadRecordSummary[] = [];
    while (resultSet.goToNextRow()) {
      const readTime = RdbCodec.integer(resultSet, readTimeIndex);
      if (readTime <= 0) { continue; }
      summaries.push({
        deviceId: RdbCodec.text(resultSet, deviceIdIndex),
        bookName: RdbCodec.text(resultSet, bookNameIndex),
        bookAuthor: RdbCodec.text(resultSet, bookAuthorIndex),
        readTime: readTime,
        lastRead: RdbCodec.integer(resultSet, lastReadIndex)
      });
    }
    return summaries.sort((left: ReadRecordSummary, right: ReadRecordSummary) => right.lastRead - left.lastRead);
  }

  /**
   * 转成旧版扁平记录，供阅读记录页现有的三种视图直接渲染。
   *
   * 旧视图只认 id/bookId/bookName/bookAuthor/startTime/endTime/durationMs，
   * 这里按会话一一映射，等页面改成直接读会话与明细后再撤掉。
   */
  static toTimelineRecords(sessions: ReadRecordSession[]): ReadTimeRecord[] {
    const records: ReadTimeRecord[] = [];
    for (const session of sessions) {
      records.push({
        id: `${session.bookUrl}-${session.startTime}-${session.endTime}`,
        bookId: session.bookUrl,
        bookName: session.bookName,
        bookAuthor: session.bookAuthor,
        startTime: session.startTime,
        endTime: session.endTime,
        durationMs: session.endTime - session.startTime,
        chapterIndex: session.chapterIndex
      });
    }
    return records;
  }

  // ---------------------------------------------------------------- 展示辅助

  /** 时长四段格式化：天/小时/分钟/秒任意非零都拼，全零返回「0秒」。 */
  static formatDuration(millis: number): string {
    const days = Math.floor(millis / (1000 * 60 * 60 * 24));
    const hours = Math.floor((millis % (1000 * 60 * 60 * 24)) / (1000 * 60 * 60));
    const minutes = Math.floor((millis % (1000 * 60 * 60)) / (1000 * 60));
    const seconds = Math.floor((millis % (1000 * 60)) / 1000);
    const d = days > 0 ? `${days}天` : '';
    const h = hours > 0 ? `${hours}小时` : '';
    const m = minutes > 0 ? `${minutes}分钟` : '';
    const s = seconds > 0 ? `${seconds}秒` : '';
    const text = `${d}${h}${m}${s}`;
    return text.length === 0 ? '0秒' : text;
  }

  /** 复制一条会话；ArkTS 不支持对象展开，逐字段构造。 */
  private static cloneSession(session: ReadRecordSession, endTime: number): ReadRecordSession {
    return {
      deviceId: session.deviceId,
      bookName: session.bookName,
      bookAuthor: session.bookAuthor,
      bookUrl: session.bookUrl,
      startTime: session.startTime,
      endTime: endTime,
      chapterIndex: session.chapterIndex
    };
  }

  /**
   * 合并相邻的同书会话，对应上游 mergeContinuousSessions。
   * 只看相邻两条，间隔不超过 continuousSessionGapMs 就延长上一条的结束时间。
   */
  static mergeContinuousSessions(sessions: ReadRecordSession[]): ReadRecordSession[] {
    const merged: ReadRecordSession[] = [];
    for (const current of sessions) {
      const last = merged.length > 0 ? merged[merged.length - 1] : undefined;
      if (last !== undefined && current.bookName === last.bookName &&
        current.bookAuthor === last.bookAuthor &&
        (current.startTime - last.endTime) <= ReadRecordRepository.continuousSessionGapMs) {
        merged[merged.length - 1] = ReadRecordRepository.cloneSession(last, current.endTime);
      } else {
        merged.push(ReadRecordRepository.cloneSession(current, current.endTime));
      }
    }
    return merged;
  }

  /** 日期友好化：今天/昨天/N天前（2~5 天），其余原样返回 yyyy-MM-dd。 */
  static formatFriendlyDate(dateKey: string): string {
    const todayMidnight = ReadRecordRepository.midnightOf(ReadRecordRepository.toDateKey(Date.now()));
    const inputMidnight = ReadRecordRepository.midnightOf(dateKey);
    if (inputMidnight === 0) { return dateKey; }
    const daysBetween = Math.round((todayMidnight - inputMidnight) / (1000 * 60 * 60 * 24));
    if (daysBetween === 0) { return '今天'; }
    if (daysBetween === 1) { return '昨天'; }
    if (daysBetween >= 2 && daysBetween <= 5) { return `${daysBetween}天前`; }
    return dateKey;
  }

  // ---------------------------------------------------------------- 本书维度

  /** 按（书名, 作者）取一本书的累计汇总，对应上游 getBookReadTime。 */
  static async loadBookSummaries(context: Context, bookName: string, bookAuthor: string): Promise<ReadRecordSummary> {
    const summaries = await ReadRecordRepository.loadSummaries(context);
    const matched = summaries.find((item: ReadRecordSummary) =>
      item.bookName === bookName && item.bookAuthor === bookAuthor);
    if (matched !== undefined) { return matched; }
    return { deviceId: '', bookName: bookName, bookAuthor: bookAuthor, readTime: 0, lastRead: 0 };
  }

  /**
   * 按副本取本书会话并按自然日分组：日倒序、天内按开始时间倒序。
   * 对应上游 toTimelineDays；bookUrl 为空的历史记录退回按（书名, 作者）匹配。
   */
  static async loadBookTimelineDays(
    context: Context, bookUrl: string, bookName: string, bookAuthor: string
  ): Promise<ReadRecordSession[][]> {
    const sessions = await ReadRecordRepository.loadSessions(context);
    const groups: Map<string, ReadRecordSession[]> = new Map<string, ReadRecordSession[]>();
    for (const session of sessions) {
      const matched = bookUrl.length > 0 ? session.bookUrl === bookUrl :
        (session.bookName === bookName && session.bookAuthor === bookAuthor);
      if (!matched) { continue; }
      const dateKey = ReadRecordRepository.toDateKey(session.startTime);
      const day = groups.get(dateKey);
      if (day === undefined) { groups.set(dateKey, [session]); }
      else { day.push(session); }
    }
    const dateKeys: string[] = Array.from(groups.keys()).sort(
      (left: string, right: string) => right.localeCompare(left));
    const days: ReadRecordSession[][] = [];
    for (const dateKey of dateKeys) {
      const day = groups.get(dateKey) ?? [];
      day.sort((left: ReadRecordSession, right: ReadRecordSession) => right.startTime - left.startTime);
      days.push(day);
    }
    return days;
  }

  // ---------------------------------------------------------------- 删除

  /** 删会话行并按剩余会话整体重算明细与汇总；会话是权威源，删派生行会被重算写回。 */
  private static async deleteSessionsAndRebuild(
    context: Context, sql: string, args: relationalStore.ValueType[]
  ): Promise<void> {
    await ReadRecordRepository.saveQueue;
    const store = await RdbStore.getStore(context);
    await RdbSchema.ensure(store);
    store.beginTransaction();
    try {
      await store.executeSql(sql, args);
      store.commit();
    } catch (error) {
      store.rollBack();
      throw new Error(`删除阅读记录失败：${(error as Error).message}`);
    }
    const sessions = await ReadRecordRepository.loadSessions(context);
    await ReadRecordRepository.rebuildDetailsAndSummaries(context, sessions);
  }

  /** 单条删除：时间线条目按会话复合键定位。 */
  static async deleteSessionById(context: Context, session: ReadRecordSession): Promise<void> {
    await ReadRecordRepository.deleteSessionsAndRebuild(context, ReadRecordRepository.deleteSessionByExactKey, [
      session.bookName, session.bookAuthor, session.bookUrl, session.startTime, session.endTime
    ]);
  }

  /** 单条删除：汇总条目按（设备, 书名, 作者, 日期）删该日的底层会话。 */
  static async deleteDetailByIdKey(
    context: Context, deviceId: string, bookName: string, bookAuthor: string, date: string
  ): Promise<void> {
    await ReadRecordRepository.deleteSessionsAndRebuild(context, ReadRecordRepository.deleteSessionsByBookAndDate, [
      deviceId, bookName, bookAuthor, date
    ]);
  }

  /** 单条删除：最后阅读条目按（书名, 作者）删这本书的全部会话。 */
  static async deleteSummaryByKey(context: Context, bookName: string, bookAuthor: string): Promise<void> {
    await ReadRecordRepository.deleteSessionsAndRebuild(context, ReadRecordRepository.deleteSessionsByBook, [
      bookName, bookAuthor
    ]);
  }

  // ---------------------------------------------------------------- 单书禁用

  /**
   * 由 books.bookUrl 派生 Book.id，规则与 BookRepository.bookIdFromUrl 一致：
   * 按 / 取文件名、解百分号编码、去掉最后一个扩展名。
   */
  private static idFromBookUrl(bookUrl: string): string {
    const separator = bookUrl.lastIndexOf('/');
    const rawName = separator >= 0 ? bookUrl.substring(separator + 1) : bookUrl;
    let fileName = rawName;
    try {
      fileName = decodeURIComponent(rawName);
    } catch (_) {
      // 不是合法百分号编码时按原样处理
    }
    const dotIndex = fileName.lastIndexOf('.');
    return dotIndex > 0 ? fileName.substring(0, dotIndex) : fileName;
  }

  /**
   * 查某本书是否单独关闭了阅读记录。
   * 会话的 bookUrl 是 Book.id（文件名），books 表 bookUrl 列存完整路径，
   * 因此把精确命中行与全部禁用行一起取出，再按文件名派生规则比对。
   */
  static async isBookReadRecordDisabled(context: Context, bookUrl: string): Promise<boolean> {
    if (bookUrl.length === 0) { return false; }
    try {
      const store = await RdbStore.getStore(context);
      await RdbSchema.ensure(store);
      const resultSet = await store.querySql(ReadRecordRepository.selectDisableReadRecord, [bookUrl]);
      try {
        const urlIndex = RdbCodec.column(resultSet, 'bookUrl');
        const disabledIndex = RdbCodec.column(resultSet, 'disableReadRecord');
        while (resultSet.goToNextRow()) {
          if (!RdbCodec.boolean(resultSet, disabledIndex, false)) { continue; }
          const path = RdbCodec.text(resultSet, urlIndex);
          // 会话的 bookUrl 是 Book.id（文件名去扩展名），books 列存完整路径，
          // 两边按同一套派生规则比对，避免前缀同名书误命中。
          if (path === bookUrl || ReadRecordRepository.idFromBookUrl(path) === bookUrl) { return true; }
        }
        return false;
      } finally {
        resultSet.close();
      }
    } catch (_) {
      return false;
    }
  }


  // ---------------------------------------------------------------- 会话

  /**
   * 开始（或继续）一本书的阅读会话。
   *
   * 与上游 ReadBook.initReadTime 一致：切换到另一本书时先把上一本提交掉；
   * 同一本书重复调用不会重置起点。
   */
  static async start(context: Context, book: Book, chapterIndex: number): Promise<void> {
    if (ReadRecordRepository.activeBookId.length > 0 && ReadRecordRepository.activeBookId !== book.id) {
      await ReadRecordRepository.commit(context);
    }
    if (ReadRecordRepository.activeBookId === book.id && ReadRecordRepository.activeStartTime > 0) {
      ReadRecordRepository.activeChapterIndex = chapterIndex;
      return;
    }
    const now = Date.now();
    ReadRecordRepository.activeBookId = book.id;
    ReadRecordRepository.activeBookName = book.title;
    ReadRecordRepository.activeBookAuthor = book.author;
    ReadRecordRepository.activeStartTime = now;
    ReadRecordRepository.activeEndTime = now;
    ReadRecordRepository.activeChapterIndex = chapterIndex;
  }

  /** 续写当前会话的结束时间与所在章节。 */
  static touch(chapterIndex: number): void {
    if (ReadRecordRepository.activeStartTime <= 0) { return; }
    ReadRecordRepository.activeEndTime = Date.now();
    ReadRecordRepository.activeChapterIndex = chapterIndex;
  }

  /**
   * 结束当前会话并落库。
   *
   * 不足 minimumReadDurationMs 的会话直接丢弃（上游 MIN_READ_DURATION 语义），
   * 避免快速翻页产生大量碎片记录。
   */
  static async commit(context: Context): Promise<void> {
    const startTime = ReadRecordRepository.activeStartTime;
    const endTime = ReadRecordRepository.activeEndTime;
    const bookId = ReadRecordRepository.activeBookId;
    const bookName = ReadRecordRepository.activeBookName;
    const bookAuthor = ReadRecordRepository.activeBookAuthor;
    const chapterIndex = ReadRecordRepository.activeChapterIndex;
    if (startTime <= 0) { return; }
    ReadRecordRepository.activeBookId = '';
    ReadRecordRepository.activeBookName = '';
    ReadRecordRepository.activeBookAuthor = '';
    ReadRecordRepository.activeStartTime = 0;
    ReadRecordRepository.activeEndTime = 0;
    ReadRecordRepository.activeChapterIndex = 0;
    if (endTime - startTime < ReadRecordRepository.minimumReadDurationMs) { return; }
    await ReadRecordRepository.saveSession(context, {
      deviceId: '',
      bookName: bookName,
      bookAuthor: bookAuthor,
      bookUrl: bookId,
      startTime: startTime,
      endTime: endTime,
      chapterIndex: chapterIndex
    });
  }

  /** 丢弃当前会话，不落库（例如用户切走且时长不足）。 */
  static discardActive(): void {
    ReadRecordRepository.activeBookId = '';
    ReadRecordRepository.activeBookName = '';
    ReadRecordRepository.activeBookAuthor = '';
    ReadRecordRepository.activeStartTime = 0;
    ReadRecordRepository.activeEndTime = 0;
    ReadRecordRepository.activeChapterIndex = 0;
  }

  /**
   * 写入一条会话，并同步更新按日明细与书籍汇总。
   *
   * 去重口径与上游 saveReadSession 一致：同一本书 + 同一副本 + 相同起止时间视为同一条。
   */
  static async saveSession(context: Context, session: ReadRecordSession): Promise<boolean> {
    if (!ReadRecordRepository.isEnabled()) { return false; }
    // 单独为某本书关掉记录时只跳过这本书，其他书照常；对齐上游 saveReadSession 的判定。
    if (await ReadRecordRepository.isBookReadRecordDisabled(context, session.bookUrl)) { return false; }
    if (session.endTime <= session.startTime) { return false; }
    const normalized: ReadRecordSession = {
      deviceId: session.deviceId,
      bookName: ReadRecordRepository.normalizeIdentity(session.bookName),
      bookAuthor: ReadRecordRepository.normalizeIdentity(session.bookAuthor),
      bookUrl: session.bookUrl,
      startTime: session.startTime,
      endTime: session.endTime,
      chapterIndex: session.chapterIndex
    };
    const operation = ReadRecordRepository.saveQueue.then(async (): Promise<boolean> => {
      const sessions = await ReadRecordRepository.loadSessions(context);
      const exists = sessions.some((item: ReadRecordSession) =>
        item.bookUrl === normalized.bookUrl && item.bookName === normalized.bookName &&
        item.bookAuthor === normalized.bookAuthor && item.startTime === normalized.startTime &&
        item.endTime === normalized.endTime);
      if (exists) { return false; }
      const store = await RdbStore.getStore(context);
      await RdbSchema.ensure(store);
      await store.executeSql(ReadRecordRepository.insertSession, [
        normalized.deviceId, normalized.bookName, normalized.bookAuthor, normalized.bookUrl,
        normalized.startTime, normalized.endTime, normalized.chapterIndex
      ]);
      sessions.push(normalized);
      sessions.sort((left: ReadRecordSession, right: ReadRecordSession) => left.startTime - right.startTime);
      await ReadRecordRepository.rebuildDetailsAndSummaries(context, sessions);
      return true;
    });
    ReadRecordRepository.saveQueue = operation.then((): void => {}, (): void => {});
    return operation;
  }

  // ---------------------------------------------------------------- 重算

  /**
   * 按会话算出按日明细与书籍汇总。
   *
   * 会话是唯一权威数据源，明细与汇总都是派生结果，所以每次写入后整体重算，
   * 避免增量累加在跨午夜拆分、去重、删除等场景下产生偏差。
   * 把「算」和「写」拆开是为了让存量搬迁能直接复用同一份算法。
   */
  static computeDerived(sessions: ReadRecordSession[]): ReadRecordDerived {
    const detailMap: Map<string, ReadRecordDetail> = new Map<string, ReadRecordDetail>();
    const summaryMap: Map<string, ReadRecordSummary> = new Map<string, ReadRecordSummary>();
    for (const session of sessions) {
      const segments = ReadRecordRepository.splitByDate(session);
      for (const date of segments.keys()) {
        const duration = segments.get(date) ?? 0;
        if (duration <= 0) { continue; }
        const detailKey = `${session.bookName}\u0000${session.bookAuthor}\u0000${date}`;
        const bounds = ReadRecordRepository.boundsOnDate(session, date);
        const existing = detailMap.get(detailKey);
        if (existing === undefined) {
          detailMap.set(detailKey, {
            deviceId: session.deviceId,
            bookName: session.bookName,
            bookAuthor: session.bookAuthor,
            date: date,
            readTime: duration,
            readWords: ReadRecordRepository.isStartDate(session, date) ? session.chapterIndex : 0,
            firstReadTime: bounds[0],
            lastReadTime: bounds[1]
          });
        } else {
          existing.readTime += duration;
          existing.readWords += ReadRecordRepository.isStartDate(session, date) ? session.chapterIndex : 0;
          existing.firstReadTime = ReadRecordRepository.minPositive(existing.firstReadTime, bounds[0]);
          existing.lastReadTime = Math.max(existing.lastReadTime, bounds[1]);
        }
      }
      const summaryKey = `${session.bookName}\u0000${session.bookAuthor}`;
      const summary = summaryMap.get(summaryKey);
      const duration = session.endTime - session.startTime;
      if (summary === undefined) {
        summaryMap.set(summaryKey, {
          deviceId: session.deviceId,
          bookName: session.bookName,
          bookAuthor: session.bookAuthor,
          readTime: duration,
          lastRead: session.endTime
        });
      } else {
        summary.readTime += duration;
        summary.lastRead = Math.max(summary.lastRead, session.endTime);
      }
    }
    const details: ReadRecordDetail[] = Array.from(detailMap.values());
    const summaries: ReadRecordSummary[] = Array.from(summaryMap.values());
    return { details: details, summaries: summaries };
  }

  /** 按会话重算并写回明细与汇总两张派生表。 */
  private static async rebuildDetailsAndSummaries(context: Context, sessions: ReadRecordSession[]): Promise<void> {
    const store = await RdbStore.getStore(context);
    await RdbSchema.ensure(store);
    // 明细与汇总都是派生数据，重算就是整表替换：一个事务内先清空再逐行写入，
    // 中途失败整体回滚，不会留下「会话已写、派生层还是旧的」的中间态。
    store.beginTransaction();
    try {
      await ReadRecordRepository.rewriteDerived(store, sessions);
      store.commit();
    } catch (error) {
      store.rollBack();
      throw new Error(`阅读记录重算失败：${(error as Error).message}`);
    }
  }

  /**
   * 用给定会话重算并覆盖明细与汇总两张派生表。
   *
   * 不开事务：调用方负责（运行期路径自己开事务，搬迁路径由 RdbMigration 开）。
   */
  private static async rewriteDerived(
    store: relationalStore.RdbStore,
    sessions: ReadRecordSession[]
  ): Promise<void> {
    const derived = ReadRecordRepository.computeDerived(sessions);
    await store.executeSql(ReadRecordRepository.deleteDetails);
    for (const detail of derived.details) {
      await store.executeSql(ReadRecordRepository.insertDetail, [
        detail.deviceId, detail.bookName, detail.bookAuthor, detail.date,
        detail.readTime, detail.readWords, detail.firstReadTime, detail.lastReadTime
      ]);
    }
    await store.executeSql(ReadRecordRepository.deleteSummaries);
    for (const summary of derived.summaries) {
      await store.executeSql(ReadRecordRepository.insertSummary, [
        summary.deviceId, summary.bookName, summary.bookAuthor, summary.readTime, summary.lastRead
      ]);
    }
  }

  /**
   * 把一段会话按本地时区午夜切开，返回「日期 → 该日时长」。
   *
   * 对应上游 ReadRecordRepository.durationByDate（ReadRecordRepository.kt:45-58）：
   * 一条 23:50 读到次日 00:20 的会话，必须分别记到两天，否则日历热力图的当天时长会失真。
   */
  private static splitByDate(session: ReadRecordSession): Map<string, number> {
    const result: Map<string, number> = new Map<string, number>();
    if (session.endTime <= session.startTime) { return result; }
    let cursor = session.startTime;
    while (cursor < session.endTime) {
      const date = ReadRecordRepository.toDateKey(cursor);
      const nextMidnight = ReadRecordRepository.nextMidnight(cursor);
      const segmentEnd = Math.min(session.endTime, nextMidnight);
      result.set(date, (result.get(date) ?? 0) + (segmentEnd - cursor));
      cursor = segmentEnd;
    }
    return result;
  }

  /** 会话落在指定日期的起止时间戳，对应上游 boundsOnDate。 */
  private static boundsOnDate(session: ReadRecordSession, date: string): number[] {
    const midnight = ReadRecordRepository.midnightOf(date);
    const nextMidnight = ReadRecordRepository.nextMidnight(midnight);
    const segmentStart = Math.max(session.startTime, midnight);
    const segmentEnd = Math.min(session.endTime, nextMidnight);
    return [segmentStart, segmentEnd];
  }

  private static isStartDate(session: ReadRecordSession, date: string): boolean {
    return ReadRecordRepository.toDateKey(session.startTime) === date;
  }

  /** 时间戳 → 本地时区 yyyy-MM-dd。 */
  static toDateKey(timestamp: number): string {
    const date = new Date(timestamp);
    const month = (date.getMonth() + 1).toString().padStart(2, '0');
    const day = date.getDate().toString().padStart(2, '0');
    return `${date.getFullYear()}-${month}-${day}`;
  }

  /** 时间戳所在日期的次日零点（本地时区）。 */
  private static nextMidnight(timestamp: number): number {
    const date = new Date(timestamp);
    return new Date(date.getFullYear(), date.getMonth(), date.getDate() + 1).getTime();
  }

  /** yyyy-MM-dd → 该日本地零点时间戳。 */
  private static midnightOf(dateKey: string): number {
    const parts = dateKey.split('-');
    const year = Number(parts[0]);
    const month = Number(parts[1]);
    const day = Number(parts[2]);
    if (!Number.isFinite(year) || !Number.isFinite(month) || !Number.isFinite(day)) { return 0; }
    return new Date(year, month - 1, day).getTime();
  }

  private static minPositive(left: number, right: number): number {
    if (left <= 0) { return right; }
    if (right <= 0) { return left; }
    return Math.min(left, right);
  }

  /**
   * 规范化书名/作者：折叠连续空白并去除首尾空白。
   *
   * 对应上游 ReadRecordIdentity.normalize。同一本书在不同来源下可能带非零宽空格、
   * 全半角或首尾空白差异，不收敛就会在汇总里分裂成多条记录。
   */
  static normalizeIdentity(value: string): string {
    return (value ?? '').replace(/[\u0020\u00A0\u1680\u2000-\u200A\u202F\u205F\u3000\t\r\n]+/g, ' ').trim();
  }

  // ---------------------------------------------------------------- 写

  /**
   * 整表替换会话：事务内先清空再逐行写入。
   *
   * 只有 repair / migrateLegacy 这类「重算全部会话」的维护路径用它，
   * 日常追加走 saveSession 的单行 INSERT。
   */
  private static async replaceSessions(context: Context, sessions: ReadRecordSession[]): Promise<void> {
    const store = await RdbStore.getStore(context);
    await RdbSchema.ensure(store);
    store.beginTransaction();
    try {
      await store.executeSql(ReadRecordRepository.deleteSessions);
      for (const item of sessions) {
        await store.executeSql(ReadRecordRepository.insertSession, [
          item.deviceId, item.bookName, item.bookAuthor, item.bookUrl,
          item.startTime, item.endTime, item.chapterIndex
        ]);
      }
      store.commit();
    } catch (error) {
      store.rollBack();
      throw new Error(`阅读会话写入失败：${(error as Error).message}`);
    }
  }

  /** 阅读记录总开关仍写 preferences，与上游把开关放在 localPreferences 一致。 */
  private static async putEnabled(context: Context, value: string): Promise<void> {
    const store = await preferences.getPreferences(context, ReadRecordRepository.preferenceName);
    await store.put(ReadRecordRepository.enabledKey, value);
    await store.flush();
  }

  /** 读删除确认「不再提醒」长期档；读失败按未勾选处理。 */
  static async loadSkipDeleteConfirm(context: Context): Promise<boolean> {
    try {
      const store = await preferences.getPreferences(context, ReadRecordRepository.preferenceName);
      const value = await store.get(ReadRecordRepository.skipDeleteConfirmKey, '0');
      return value !== '0';
    } catch (_) {
      return false;
    }
  }

  /** 写删除确认「不再提醒」长期档；动作单的「恢复删除确认」把它写回 false。 */
  static async setSkipDeleteConfirm(context: Context, skip: boolean): Promise<void> {
    const store = await preferences.getPreferences(context, ReadRecordRepository.preferenceName);
    await store.put(ReadRecordRepository.skipDeleteConfirmKey, skip ? '1' : '0');
    await store.flush();
  }

  // ---------------------------------------------------------------- 合并与归属

  /**
   * 合并候选：同书名、不同作者的其他汇总行。
   * 对应上游 getMergeCandidates（ReadRecordRepository.kt:339-346）的同书名优先口径。
   */
  static async loadMergeCandidates(context: Context, target: ReadRecordSummary): Promise<ReadRecordSummary[]> {
    const summaries = await ReadRecordRepository.loadSummaries(context);
    return summaries.filter((item: ReadRecordSummary) =>
      item.bookName === target.bookName && item.bookAuthor !== target.bookAuthor);
  }

  /**
   * 把 sources 的会话整体改判为 target 的（书名，作者），再按会话重算派生表。
   * 会话是唯一权威源，绝不把 readTime 直接相加（上游 mergeIndependentReadRecords 同口径）。
   */
  static async mergeReadRecords(context: Context, target: ReadRecordSummary,
    sources: ReadRecordSummary[]): Promise<void> {
    if (sources.length === 0) { return; }
    await ReadRecordRepository.saveQueue;
    const sourceKeys: Set<string> = new Set<string>();
    for (const source of sources) {
      sourceKeys.add(`${source.bookName}\u0000${source.bookAuthor}`);
    }
    const sessions = await ReadRecordRepository.loadSessions(context);
    const merged: ReadRecordSession[] = sessions.map((item: ReadRecordSession) => {
      if (sourceKeys.has(`${item.bookName}\u0000${item.bookAuthor}`)) {
        return {
          deviceId: item.deviceId, bookName: target.bookName, bookAuthor: target.bookAuthor,
          bookUrl: item.bookUrl, startTime: item.startTime, endTime: item.endTime,
          chapterIndex: item.chapterIndex
        };
      }
      return item;
    });
    await ReadRecordRepository.replaceSessions(context, merged);
    await ReadRecordRepository.rebuildDetailsAndSummaries(context, merged);
  }

  /** 同书名且作者为空的旧汇总行，对应上游 getUnknownAuthorRecords。 */
  static async loadUnknownAuthorRecords(context: Context, bookName: string): Promise<ReadRecordSummary[]> {
    const summaries = await ReadRecordRepository.loadSummaries(context);
    return summaries.filter((item: ReadRecordSummary) =>
      item.bookName === bookName && item.bookAuthor.length === 0);
  }

  /** 归属决定的稳定键：书名 + 空字符 + 作者，与施工图口径一致。 */
  static aliasKey(bookName: string, author: string): string {
    return `${bookName}\u0000${author}`;
  }

  private static async loadAliasDecisionText(context: Context): Promise<string> {
    try {
      const store = await preferences.getPreferences(context, ReadRecordRepository.preferenceName);
      const value = await store.get(ReadRecordRepository.aliasDecisionsKey, '');
      return value as string;
    } catch (_) {
      return '';
    }
  }

  /** 读某本书的归属决定：MERGE / KEEP / 空串（未决定）。 */
  static async loadAliasDecision(context: Context, key: string): Promise<string> {
    const text = await ReadRecordRepository.loadAliasDecisionText(context);
    const prefix = `${key}${ReadRecordRepository.aliasDecisionSeparator}`;
    for (const line of text.split('\n')) {
      if (line.startsWith(prefix)) { return line.slice(prefix.length); }
    }
    return '';
  }

  /** 记住归属决定：先移除同 key 的旧行，再追加新行。 */
  static async saveAliasDecision(context: Context, key: string, merge: boolean): Promise<void> {
    const store = await preferences.getPreferences(context, ReadRecordRepository.preferenceName);
    const old = await ReadRecordRepository.loadAliasDecisionText(context);
    const prefix = `${key}${ReadRecordRepository.aliasDecisionSeparator}`;
    const kept: string[] = old.split('\n').filter((line: string) =>
      line.length > 0 && !line.startsWith(prefix));
    kept.push(`${prefix}${merge ? 'MERGE' : 'KEEP'}`);
    await store.put(ReadRecordRepository.aliasDecisionsKey, kept.join('\n'));
    await store.flush();
  }

  /** 清除全部归属决定，对应上游 ReadRecordAliasDelegate.clearDecisions。 */
  static async clearAliasDecisions(context: Context): Promise<void> {
    const store = await preferences.getPreferences(context, ReadRecordRepository.preferenceName);
    await store.put(ReadRecordRepository.aliasDecisionsKey, '');
    await store.flush();
  }

  // ---------------------------------------------------------------- 维护

  /** 清空全部阅读记录（会话、明细、汇总一起清）。 */
  static async clearAll(context: Context): Promise<void> {
    await ReadRecordRepository.saveQueue;
    ReadRecordRepository.discardActive();
    const store = await RdbStore.getStore(context);
    await RdbSchema.ensure(store);
    // 三张表一起清，放在一个事务里：上游 clearReadRecords 同样是事务内清三表
    store.beginTransaction();
    try {
      await store.executeSql(ReadRecordRepository.deleteSessions);
      await store.executeSql(ReadRecordRepository.deleteDetails);
      await store.executeSql(ReadRecordRepository.deleteSummaries);
      store.commit();
    } catch (error) {
      store.rollBack();
      throw new Error(`清空阅读记录失败：${(error as Error).message}`);
    }
  }

  /**
   * 删除指定书籍的全部阅读记录，对应上游 deleteReadRecord。
   *
   * 三张表按「书名 + 作者」一起删：会话是权威源，明细与汇总都从会话派生，
   * 删完不需要重算——其他书的行本来就没被碰。
   */
  static async removeBook(context: Context, bookName: string, bookAuthor: string): Promise<void> {
    await ReadRecordRepository.saveQueue;
    const name = ReadRecordRepository.normalizeIdentity(bookName);
    const author = ReadRecordRepository.normalizeIdentity(bookAuthor);
    const store = await RdbStore.getStore(context);
    await RdbSchema.ensure(store);
    store.beginTransaction();
    try {
      await store.executeSql(ReadRecordRepository.deleteSessionsByBook, [name, author]);
      await store.executeSql(ReadRecordRepository.deleteDetailsByBook, [name, author]);
      await store.executeSql(ReadRecordRepository.deleteSummaryByBook, [name, author]);
      store.commit();
    } catch (error) {
      store.rollBack();
      throw new Error(`删除阅读记录失败：${(error as Error).message}`);
    }
  }

  /**
   * 只读扫描问题，不改数据，对应上游 scanReadRecordIssues。
   *
   * 检查三项：重复的阅读时段、书名/作者写法不规范、明细与会话不一致。
   */
  static async scanIssues(context: Context): Promise<ReadRecordRepairReport> {
    const sessions = await ReadRecordRepository.loadSessions(context);
    const seen: Set<string> = new Set<string>();
    let duplicateSessionCount = 0;
    let normalizedRecordCount = 0;
    for (const session of sessions) {
      const key = `${session.bookName}\u0000${session.bookAuthor}\u0000${session.bookUrl}\u0000` +
        `${session.startTime}\u0000${session.endTime}`;
      if (seen.has(key)) {
        duplicateSessionCount += 1;
      } else {
        seen.add(key);
      }
      if (session.bookName !== ReadRecordRepository.normalizeIdentity(session.bookName) ||
        session.bookAuthor !== ReadRecordRepository.normalizeIdentity(session.bookAuthor)) {
        normalizedRecordCount += 1;
      }
    }
    const expectedSummaryTime: Map<string, number> = new Map<string, number>();
    const expectedSummaryLastRead: Map<string, number> = new Map<string, number>();
    const expectedDetailTime: Map<string, number> = new Map<string, number>();
    for (const session of sessions) {
      const summaryKey = `${session.bookName}\u0000${session.bookAuthor}`;
      expectedSummaryTime.set(summaryKey,
        (expectedSummaryTime.get(summaryKey) ?? 0) + (session.endTime - session.startTime));
      expectedSummaryLastRead.set(summaryKey,
        Math.max(expectedSummaryLastRead.get(summaryKey) ?? 0, session.endTime));
      const segments = ReadRecordRepository.splitByDate(session);
      for (const date of segments.keys()) {
        const detailKey = `${session.bookName}\u0000${session.bookAuthor}\u0000${date}`;
        expectedDetailTime.set(detailKey,
          (expectedDetailTime.get(detailKey) ?? 0) + (segments.get(date) ?? 0));
      }
    }
    const summaries = await ReadRecordRepository.loadSummaries(context);
    const actualSummaries: Map<string, ReadRecordSummary> = new Map<string, ReadRecordSummary>();
    for (const summary of summaries) {
      actualSummaries.set(`${summary.bookName}\u0000${summary.bookAuthor}`, summary);
    }
    const summaryKeys: Set<string> = new Set<string>();
    for (const key of expectedSummaryTime.keys()) { summaryKeys.add(key); }
    for (const key of actualSummaries.keys()) { summaryKeys.add(key); }
    let mergedCount = 0;
    for (const key of summaryKeys) {
      const summary = actualSummaries.get(key);
      if (summary === undefined || summary.readTime !== (expectedSummaryTime.get(key) ?? 0) ||
        summary.lastRead !== (expectedSummaryLastRead.get(key) ?? 0)) { mergedCount += 1; }
    }
    const details = await ReadRecordRepository.loadDetails(context);
    const actualDetailTime: Map<string, number> = new Map<string, number>();
    for (const detail of details) {
      actualDetailTime.set(`${detail.bookName}\u0000${detail.bookAuthor}\u0000${detail.date}`, detail.readTime);
    }
    const detailKeys: Set<string> = new Set<string>();
    for (const key of expectedDetailTime.keys()) { detailKeys.add(key); }
    for (const key of actualDetailTime.keys()) { detailKeys.add(key); }
    for (const key of detailKeys) {
      if ((actualDetailTime.get(key) ?? 0) !== (expectedDetailTime.get(key) ?? 0)) { mergedCount += 1; }
    }
    return {
      duplicateSessionCount: duplicateSessionCount,
      mergedCount: mergedCount,
      normalizedRecordCount: normalizedRecordCount
    };
  }

  /**
   * 修复阅读记录，对应上游 repairReadRecordIdentities。
   *
   * 实际动作：规范化书名/作者、删除重复会话、按会话重算明细与汇总。
   * 因为明细与汇总都是派生数据，重算一步就能修掉大部分偏差。
   */
  static async repair(context: Context): Promise<ReadRecordRepairReport> {
    const report = await ReadRecordRepository.scanIssues(context);
    const sessions = await ReadRecordRepository.loadSessions(context);
    const seen: Set<string> = new Set<string>();
    const normalized: ReadRecordSession[] = [];
    for (const session of sessions) {
      const item: ReadRecordSession = {
        deviceId: session.deviceId,
        bookName: ReadRecordRepository.normalizeIdentity(session.bookName),
        bookAuthor: ReadRecordRepository.normalizeIdentity(session.bookAuthor),
        bookUrl: session.bookUrl,
        startTime: session.startTime,
        endTime: session.endTime,
        chapterIndex: session.chapterIndex
      };
      const key = `${item.bookName}\u0000${item.bookAuthor}\u0000${item.bookUrl}\u0000` +
        `${item.startTime}\u0000${item.endTime}`;
      if (seen.has(key)) { continue; }
      seen.add(key);
      normalized.push(item);
    }
    normalized.sort((left: ReadRecordSession, right: ReadRecordSession) => left.startTime - right.startTime);
    await ReadRecordRepository.replaceSessions(context, normalized);
    await ReadRecordRepository.rebuildDetailsAndSummaries(context, normalized);
    return report;
  }

  // ---------------------------------------------------------------- 备份与恢复

  /**
   * 恢复备份里的三张表：合并进现有库后按会话重算派生层。
   * 对应上游 Restore.kt:425-487 的导入口径 + ReadRecordRepository.kt:961 的重算口径。
   * 会话按完整身份跳过已有副本；汇总/明细取「现有值与导入值取较大」保证重复导入幂等；
   * 最后由会话整体重算明细与汇总，仅对没有会话支撑的历史行保留导入值。
   */
  static async restoreFromBackup(
    context: Context,
    summaries: ReadRecordSummary[],
    details: ReadRecordDetail[],
    sessions: ReadRecordSession[]
  ): Promise<void> {
    await ReadRecordRepository.saveQueue;
    const store = await RdbStore.getStore(context);
    await RdbSchema.ensure(store);
    store.beginTransaction();
    try {
      // 汇总：与现有行合并，取较大时长/最后阅读时间。
      const existingSummaries = await store.querySql(ReadRecordRepository.selectSummaries);
      let summaryRows: ReadRecordSummary[] = [];
      try {
        summaryRows = ReadRecordRepository.readSummaries(existingSummaries);
      } finally {
        existingSummaries.close();
      }
      const mergedSummaries: Map<string, ReadRecordSummary> = new Map<string, ReadRecordSummary>();
      for (const item of summaryRows) {
        mergedSummaries.set(`${item.deviceId}\u0000${item.bookName}\u0000${item.bookAuthor}`, item);
      }
      for (const item of summaries) {
        const key = `${item.deviceId}\u0000${item.bookName}\u0000${item.bookAuthor}`;
        const found = mergedSummaries.get(key);
        if (found === undefined) {
          mergedSummaries.set(key, item);
        } else {
          mergedSummaries.set(key, {
            deviceId: found.deviceId, bookName: found.bookName, bookAuthor: found.bookAuthor,
            readTime: Math.max(found.readTime, item.readTime),
            lastRead: Math.max(found.lastRead, item.lastRead)
          });
        }
      }

      // 明细：与现有行合并，四个统计值取较大/较小正数值。
      const existingDetails = await store.querySql(ReadRecordRepository.selectDetails);
      let detailRows: ReadRecordDetail[] = [];
      try {
        detailRows = ReadRecordRepository.readDetails(existingDetails);
      } finally {
        existingDetails.close();
      }
      const mergedDetails: Map<string, ReadRecordDetail> = new Map<string, ReadRecordDetail>();
      for (const item of detailRows) {
        mergedDetails.set(`${item.deviceId}\u0000${item.bookName}\u0000${item.bookAuthor}\u0000${item.date}`, item);
      }
      for (const item of details) {
        const key = `${item.deviceId}\u0000${item.bookName}\u0000${item.bookAuthor}\u0000${item.date}`;
        const found = mergedDetails.get(key);
        if (found === undefined) {
          mergedDetails.set(key, item);
        } else {
          mergedDetails.set(key, {
            deviceId: found.deviceId, bookName: found.bookName, bookAuthor: found.bookAuthor,
            date: found.date,
            readTime: Math.max(found.readTime, item.readTime),
            readWords: Math.max(found.readWords, item.readWords),
            firstReadTime: ReadRecordRepository.minPositive(found.firstReadTime, item.firstReadTime),
            lastReadTime: Math.max(found.lastReadTime, item.lastReadTime)
          });
        }
      }

      // 会话：按完整身份跳过已有副本。
      const existingSessions = await store.querySql(ReadRecordRepository.selectSessions);
      let sessionRows: ReadRecordSession[] = [];
      try {
        sessionRows = ReadRecordRepository.readSessions(existingSessions);
      } finally {
        existingSessions.close();
      }
      const seen: Set<string> = new Set<string>();
      const mergedSessions: ReadRecordSession[] = [];
      for (const item of sessionRows) {
        seen.add(ReadRecordRepository.sessionIdentity(item));
        mergedSessions.push(item);
      }
      for (const item of sessions) {
        const key = ReadRecordRepository.sessionIdentity(item);
        if (seen.has(key)) { continue; }
        seen.add(key);
        mergedSessions.push(item);
      }

      // 派生层由会话重算；没有会话支撑的历史汇总/明细沿用导入值（对齐上游 reconcile）。
      const derived = ReadRecordRepository.computeDerived(mergedSessions);
      const finalDetails: Map<string, ReadRecordDetail> = new Map<string, ReadRecordDetail>(mergedDetails);
      for (const item of derived.details) {
        finalDetails.set(`${item.deviceId}\u0000${item.bookName}\u0000${item.bookAuthor}\u0000${item.date}`, item);
      }
      const finalSummaries: Map<string, ReadRecordSummary> = new Map<string, ReadRecordSummary>(mergedSummaries);
      for (const item of derived.summaries) {
        finalSummaries.set(`${item.deviceId}\u0000${item.bookName}\u0000${item.bookAuthor}`, item);
      }
      const detailList: ReadRecordDetail[] = Array.from(finalDetails.values());
      const summaryList: ReadRecordSummary[] = Array.from(finalSummaries.values());

      await store.executeSql(ReadRecordRepository.deleteSessions);
      for (const item of mergedSessions) {
        await store.executeSql(ReadRecordRepository.insertSession, [
          item.deviceId, item.bookName, item.bookAuthor, item.bookUrl,
          item.startTime, item.endTime, item.chapterIndex
        ]);
      }
      await store.executeSql(ReadRecordRepository.deleteDetails);
      for (const item of detailList) {
        await store.executeSql(ReadRecordRepository.insertDetail, [
          item.deviceId, item.bookName, item.bookAuthor, item.date,
          item.readTime, item.readWords, item.firstReadTime, item.lastReadTime
        ]);
      }
      await store.executeSql(ReadRecordRepository.deleteSummaries);
      for (const item of summaryList) {
        await store.executeSql(ReadRecordRepository.insertSummary, [
          item.deviceId, item.bookName, item.bookAuthor, item.readTime, item.lastRead
        ]);
      }
      store.commit();
    } catch (error) {
      store.rollBack();
      throw new Error(`阅读记录恢复失败：${(error as Error).message}`);
    }
  }

  /** 会话的完整身份，与上游 getSession 的七个字段一致（words = 本地 chapterIndex）。 */
  private static sessionIdentity(item: ReadRecordSession): string {
    return `${item.deviceId}\u0000${item.bookName}\u0000${item.bookAuthor}\u0000` +
      `${item.bookUrl}\u0000${item.startTime}\u0000${item.endTime}\u0000${item.chapterIndex}`;
  }

  /** 备份写出用：三张表的当前内容，字段名与上游实体一致。 */
  static async exportForBackup(context: Context): Promise<ReadRecordBackupSnapshot> {
    const summaries = await ReadRecordRepository.loadSummaries(context);
    const details = await ReadRecordRepository.loadDetails(context);
    const sessions = await ReadRecordRepository.loadSessions(context);
    return { summaries: summaries, details: details, sessions: sessions };
  }

  // ---------------------------------------------------------------- 迁移

  /**
   * 从旧版扁平记录（legado_read_time_records 的 v1 协议）迁移到会话层。
   *
   * 旧记录只有 id/bookId/bookName/bookAuthor/startTime/endTime/durationMs，
   * 正好能一一映射成会话（bookUrl 取 bookId，chapterIndex 未知记 0）。
   *
   * 只在搬迁阶段调用（由 RdbMigration.migrateThirdBatch 统一驱动），
   * 所以不开事务、不清老键：事务由调用方开，老键由 RdbCleanup 统一删。
   * 必须排在 migrateFromPreferences 之后执行：那条路径是整表覆盖，
   * 先跑会把这里追加进去的更老记录一起删掉。
   *
   * 返回本次新增的会话条数。
   */
  static async migrateLegacyInto(context: Context, store: relationalStore.RdbStore): Promise<number> {
    // 当前库里已有的会话（含 migrateFromPreferences 刚写进去的），用于去重
    const resultSet = await store.querySql(ReadRecordRepository.selectSessions);
    let sessions: ReadRecordSession[] = [];
    try {
      sessions = ReadRecordRepository.readSessions(resultSet);
    } finally {
      resultSet.close();
    }
    const existing: Set<string> = new Set<string>();
    for (const item of sessions) {
      existing.add(`${item.bookUrl}\u0000${item.startTime}\u0000${item.endTime}`);
    }
    const legacy = await preferences.getPreferences(context, 'legado_read_time_records');
    const value = await legacy.get('records', 'v1\n');
    if (typeof value !== 'string' || !value.startsWith('v1\n')) { return 0; }
    const rows = value.substring(3).split('\n');
    let migrated = 0;
    for (const row of rows) {
      if (row === undefined || row.length === 0) { continue; }
      try {
        const fields = row.split('|');
        if (fields.length !== 7) { continue; }
        const startTime = Number(fields[4]);
        const endTime = Number(fields[5]);
        if (!Number.isFinite(startTime) || !Number.isFinite(endTime) || endTime <= startTime) { continue; }
        const bookId = decodeURIComponent(fields[1]);
        const key = `${bookId}\u0000${startTime}\u0000${endTime}`;
        if (existing.has(key)) { continue; }
        existing.add(key);
        const session: ReadRecordSession = {
          deviceId: '',
          bookName: ReadRecordRepository.normalizeIdentity(decodeURIComponent(fields[2])),
          bookAuthor: ReadRecordRepository.normalizeIdentity(decodeURIComponent(fields[3])),
          bookUrl: bookId,
          startTime: startTime,
          endTime: endTime,
          chapterIndex: 0
        };
        sessions.push(session);
        await store.executeSql(ReadRecordRepository.insertSession, [
          session.deviceId, session.bookName, session.bookAuthor, session.bookUrl,
          session.startTime, session.endTime, session.chapterIndex
        ]);
        migrated += 1;
      } catch (_) {
        continue;
      }
    }
    // 派生层只要会话有变化就整体重算一次，搬完三张表就是自洽的
    if (migrated > 0) {
      await ReadRecordRepository.rewriteDerived(store, sessions);
    }
    return migrated;
  }

  /**
   * 把 preferences 里的会话搬进 readRecordSession 表，并重算两层派生数据。
   *
   * 只搬 `sessions_v1`：按日明细与书籍汇总都是从会话算出来的，
   * 运行期写入路径（saveSession / removeBook）也是先写会话再整体重算，
   * 搬完立即用同一份算法重算，派生层不会与老版本数据漂移。
   * `enabled` 开关按上游语义留在 preferences，不在这里处理。
   *
   * 不开事务、不写标记：事务与标记都由 RdbMigration 统一管。
   */
  static async migrateFromPreferences(context: Context, store: relationalStore.RdbStore): Promise<void> {
    const legacy = await preferences.getPreferences(context, ReadRecordRepository.preferenceName);
    const value = await legacy.get(ReadRecordRepository.legacySessionsKey, 'v1\n');
    if (typeof value !== 'string' || !value.startsWith('v1\n')) { return; }
    const rows = value.substring(3).split('\n');
    const sessions: ReadRecordSession[] = [];
    for (let index = 0; index < rows.length; index++) {
      const row = rows[index];
      if (row === undefined || row.length === 0) { continue; }
      try {
        const fields = row.split('|');
        if (fields.length !== 7) { continue; }
        const startTime = Number(fields[4]);
        const endTime = Number(fields[5]);
        const chapterIndex = Number(fields[6]);
        if (!Number.isFinite(startTime) || !Number.isFinite(endTime) || endTime <= startTime) { continue; }
        sessions.push({
          deviceId: decodeURIComponent(fields[0]),
          bookName: decodeURIComponent(fields[1]),
          bookAuthor: decodeURIComponent(fields[2]),
          bookUrl: decodeURIComponent(fields[3]),
          startTime: startTime,
          endTime: endTime,
          chapterIndex: Number.isFinite(chapterIndex) ? chapterIndex : 0
        });
      } catch (_) {
        continue;
      }
    }
    // 老版本可能只是开过阅读记录、一条会话都没有，这种时候什么都不写。
    if (sessions.length === 0) { return; }
    sessions.sort((left: ReadRecordSession, right: ReadRecordSession) => right.endTime - left.endTime);
    await store.executeSql(ReadRecordRepository.deleteSessions);
    for (const session of sessions) {
      await store.executeSql(ReadRecordRepository.insertSession, [
        session.deviceId, session.bookName, session.bookAuthor, session.bookUrl,
        session.startTime, session.endTime, session.chapterIndex
      ]);
    }
    // 派生层跟着会话一起重建，搬完三张表就是自洽的。
    await ReadRecordRepository.rewriteDerived(store, sessions);
  }
}
