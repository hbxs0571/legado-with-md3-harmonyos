import { preferences, relationalStore } from '@kit.ArkData';
import { BookContentProcess, CONTENT_PROCESS_STATUS_DELETED, toContentProcessDisplayItem } from '../model/BookContentProcess';
import { RdbCodec } from './RdbCodec';
import { RdbStore } from './RdbStore';
import { RdbSchema } from './RdbSchema';

/**
 * 正文处理记录本地存取；列名与 Android 数据实体保持同名。
 *
 * 存储：book_content_processes 表（对齐上游 BookContentProcess 实体）。
 * load() 把整表读进 cachedRecords，getForChapter() 保持同步（读缓存），
 * 写操作单行落库后同步更新缓存。preferences 只作为搬迁来源。
 */
export class BookContentProcessRepository {
  private static readonly preferenceName: string = 'legado_book_content_processes';
  private static readonly preferenceKey: string = 'records_v1';
  private static readonly selectAll: string =
    'SELECT `id`, `bookUrl`, `chapterIndex`, `kind`, `stage`, `target`, `anchorJson`, `actionJson`, `styleJson`, ' +
      '`source`, `aiArtifactId`, `sourceContentHash`, `enabled`, `sortOrder`, `status`, `schemaVersion`, ' +
      '`createdAt`, `updatedAt` FROM `book_content_processes` ORDER BY `sortOrder`, `createdAt`';
  private static readonly upsertSql: string =
    'INSERT OR REPLACE INTO `book_content_processes` ' +
      '(`id`, `bookUrl`, `chapterIndex`, `kind`, `stage`, `target`, `anchorJson`, `actionJson`, `styleJson`, ' +
      '`source`, `aiArtifactId`, `sourceContentHash`, `enabled`, `sortOrder`, `status`, `schemaVersion`, ' +
      '`createdAt`, `updatedAt`) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)';
  private static cachedRecords: BookContentProcess[] = [];
  private static loadTask: Promise<void> | undefined = undefined;

  static getAll(): BookContentProcess[] {
    return BookContentProcessRepository.cachedRecords.map((item: BookContentProcess): BookContentProcess =>
      BookContentProcessRepository.copyRecord(item));
  }

  /**
   * 从 DB 读全表进缓存；幂等，同一轮启动只读一次。
   * DB 读失败时回退 preferences 老键，只读不写（写回由 RdbMigration 负责）。
   */
  static async load(context: Context): Promise<void> {
    if (BookContentProcessRepository.loadTask !== undefined) {
      await BookContentProcessRepository.loadTask;
      return;
    }
    BookContentProcessRepository.loadTask = BookContentProcessRepository.loadFromDb(context);
    await BookContentProcessRepository.loadTask;
  }

  private static async loadFromDb(context: Context): Promise<void> {
    try {
      const store = await RdbStore.getStore(context);
      await RdbSchema.ensure(store);
      const resultSet = await store.querySql(BookContentProcessRepository.selectAll);
      try {
        BookContentProcessRepository.cachedRecords = BookContentProcessRepository.readAll(resultSet);
      } finally {
        resultSet.close();
      }
    } catch (_) {
      await BookContentProcessRepository.loadFromPreferences(context);
    }
  }

  private static async loadFromPreferences(context: Context): Promise<void> {
    try {
      const store = await preferences.getPreferences(context, BookContentProcessRepository.preferenceName);
      const value = await store.get(BookContentProcessRepository.preferenceKey, '[]');
      if (typeof value !== 'string') {
        BookContentProcessRepository.cachedRecords = [];
      } else {
        const parsed: BookContentProcess[] = JSON.parse(value);
        BookContentProcessRepository.cachedRecords = parsed
          .filter((item: BookContentProcess) => BookContentProcessRepository.isValid(item))
          .sort((left: BookContentProcess, right: BookContentProcess) =>
            left.sortOrder - right.sortOrder || left.createdAt - right.createdAt);
      }
    } catch (_) {
      BookContentProcessRepository.cachedRecords = [];
    }
  }

  /**
   * 把 preferences 老数据搬进 DB，由 RdbMigration 在事务里调用。
   * 不开事务、不写标记：事务与标记都由 RdbMigration 统一管。
   */
  static async migrateFromPreferences(context: Context, store: relationalStore.RdbStore): Promise<void> {
    await BookContentProcessRepository.loadFromPreferences(context);
    const legacy = BookContentProcessRepository.cachedRecords;
    if (legacy.length === 0) { return; }
    await store.executeSql('DELETE FROM `book_content_processes`');
    for (let index = 0; index < legacy.length; index++) {
      const item = legacy[index];
      if (item === undefined) { continue; }
      await store.executeSql(BookContentProcessRepository.upsertSql, BookContentProcessRepository.toArgs(item));
    }
  }

  static async waitUntilLoaded(): Promise<void> {
    if (BookContentProcessRepository.loadTask !== undefined) {
      await BookContentProcessRepository.loadTask;
    }
  }

  /**
   * 取某本书某章可渲染的处理记录（同步，读缓存）。
   *
   * 过滤条件照抄上游 BookContentProcessDao：bookUrl 相等、
   * chapterIndex 为 null（全书生效）或等于目标章节、且未被软删除。
   * 缓存尚未 load() 时返回空数组（上游同样是空结果集，不额外告警）。
   */
  static getForChapter(bookUrl: string, chapterIndex: number): BookContentProcess[] {
    const matched: BookContentProcess[] = [];
    BookContentProcessRepository.cachedRecords.forEach((item: BookContentProcess) => {
      if (item.bookUrl !== bookUrl) { return; }
      const sameChapter = item.chapterIndex === null || item.chapterIndex === undefined ||
        item.chapterIndex === chapterIndex;
      if (!sameChapter) { return; }
      if (item.status === CONTENT_PROCESS_STATUS_DELETED) { return; }
      if (toContentProcessDisplayItem(item) === undefined) { return; }
      matched.push(BookContentProcessRepository.copyRecord(item));
    });
    return BookContentProcessRepository.sortRecords(matched);
  }

  /**
   * 写入一条记录（同 id 覆盖）。
   * 失败态：写库失败直接抛错，缓存不更新，调用方拿到的仍是旧数据。
   */
  static async upsert(context: Context, process: BookContentProcess): Promise<void> {
    if (!BookContentProcessRepository.isValid(process)) {
      throw new Error('正文处理记录无效');
    }
    const store = await RdbStore.getStore(context);
    await RdbSchema.ensure(store);
    await store.executeSql(BookContentProcessRepository.upsertSql, BookContentProcessRepository.toArgs(process));
    const next: BookContentProcess[] = BookContentProcessRepository.cachedRecords
      .filter((item: BookContentProcess) => item.id !== process.id)
      .map((item: BookContentProcess): BookContentProcess => BookContentProcessRepository.copyRecord(item));
    next.push(BookContentProcessRepository.copyRecord(process));
    BookContentProcessRepository.cachedRecords = BookContentProcessRepository.sortRecords(next);
  }

  /** 启用/停用单条记录，只改 enabled 与 updatedAt 两列。 */
  static async setEnabled(context: Context, id: string, enabled: boolean): Promise<void> {
    const updatedAt = Date.now();
    const store = await RdbStore.getStore(context);
    await RdbSchema.ensure(store);
    await store.executeSql('UPDATE `book_content_processes` SET `enabled` = ?, `updatedAt` = ? WHERE `id` = ?',
      [enabled ? 1 : 0, updatedAt, id]);
    BookContentProcessRepository.cachedRecords = BookContentProcessRepository.sortRecords(
      BookContentProcessRepository.cachedRecords.map((item: BookContentProcess): BookContentProcess => item.id === id
        ? BookContentProcessRepository.copyWithEnabled(item, enabled, updatedAt)
        : BookContentProcessRepository.copyRecord(item)));
  }

  /** 软删除单条记录（status 置 3），与上游 markDeleted 一致，不物理删行。 */
  static async markDeleted(context: Context, id: string): Promise<void> {
    const updatedAt = Date.now();
    const store = await RdbStore.getStore(context);
    await RdbSchema.ensure(store);
    await store.executeSql('UPDATE `book_content_processes` SET `status` = ?, `updatedAt` = ? WHERE `id` = ?',
      [CONTENT_PROCESS_STATUS_DELETED, updatedAt, id]);
    BookContentProcessRepository.cachedRecords = BookContentProcessRepository.sortRecords(
      BookContentProcessRepository.cachedRecords.map((item: BookContentProcess): BookContentProcess => item.id === id
        ? BookContentProcessRepository.copyWithStatus(item, CONTENT_PROCESS_STATUS_DELETED, updatedAt)
        : BookContentProcessRepository.copyRecord(item)));
  }

  private static sortRecords(records: BookContentProcess[]): BookContentProcess[] {
    return records.sort((left: BookContentProcess, right: BookContentProcess) =>
      left.sortOrder - right.sortOrder || left.createdAt - right.createdAt);
  }

  /** 把模型摊平成 SQL 绑定参数；顺序必须与 upsertSql 的列顺序一致。 */
  private static toArgs(item: BookContentProcess): relationalStore.ValueType[] {
    return [
      item.id,
      item.bookUrl,
      item.chapterIndex === undefined ? null : item.chapterIndex,
      item.kind,
      item.stage,
      item.target,
      item.anchorJson,
      item.actionJson,
      item.styleJson === undefined ? null : item.styleJson,
      item.source,
      item.aiArtifactId === undefined ? null : item.aiArtifactId,
      item.sourceContentHash === undefined ? null : item.sourceContentHash,
      item.enabled ? 1 : 0,
      item.sortOrder,
      item.status,
      item.schemaVersion,
      item.createdAt,
      item.updatedAt
    ];
  }

  /** 从结果集读出全部记录。列顺序与 selectAll 一致。 */
  private static readAll(resultSet: relationalStore.ResultSet): BookContentProcess[] {
    const idIndex = RdbCodec.column(resultSet, 'id');
    const bookUrlIndex = RdbCodec.column(resultSet, 'bookUrl');
    const chapterIndexIndex = RdbCodec.column(resultSet, 'chapterIndex');
    const kindIndex = RdbCodec.column(resultSet, 'kind');
    const stageIndex = RdbCodec.column(resultSet, 'stage');
    const targetIndex = RdbCodec.column(resultSet, 'target');
    const anchorJsonIndex = RdbCodec.column(resultSet, 'anchorJson');
    const actionJsonIndex = RdbCodec.column(resultSet, 'actionJson');
    const styleJsonIndex = RdbCodec.column(resultSet, 'styleJson');
    const sourceIndex = RdbCodec.column(resultSet, 'source');
    const aiArtifactIdIndex = RdbCodec.column(resultSet, 'aiArtifactId');
    const sourceContentHashIndex = RdbCodec.column(resultSet, 'sourceContentHash');
    const enabledIndex = RdbCodec.column(resultSet, 'enabled');
    const sortOrderIndex = RdbCodec.column(resultSet, 'sortOrder');
    const statusIndex = RdbCodec.column(resultSet, 'status');
    const schemaVersionIndex = RdbCodec.column(resultSet, 'schemaVersion');
    const createdAtIndex = RdbCodec.column(resultSet, 'createdAt');
    const updatedAtIndex = RdbCodec.column(resultSet, 'updatedAt');
    const records: BookContentProcess[] = [];
    while (resultSet.goToNextRow()) {
      // 模型里这四列是 `| null`（对齐上游 Kotlin 的 `Int?`/`String?`），
      // 而 RdbCodec 的可空读取返回 `| undefined`，所以这里显式折成 null。
      const chapterIndex = RdbCodec.optionalInteger(resultSet, chapterIndexIndex);
      const styleJson = RdbCodec.optionalText(resultSet, styleJsonIndex);
      const aiArtifactId = RdbCodec.optionalText(resultSet, aiArtifactIdIndex);
      const sourceContentHash = RdbCodec.optionalText(resultSet, sourceContentHashIndex);
      records.push({
        id: RdbCodec.text(resultSet, idIndex),
        bookUrl: RdbCodec.text(resultSet, bookUrlIndex),
        chapterIndex: chapterIndex === undefined ? null : chapterIndex,
        kind: RdbCodec.text(resultSet, kindIndex),
        stage: RdbCodec.text(resultSet, stageIndex),
        target: RdbCodec.text(resultSet, targetIndex),
        anchorJson: RdbCodec.text(resultSet, anchorJsonIndex),
        actionJson: RdbCodec.text(resultSet, actionJsonIndex),
        styleJson: styleJson === undefined ? null : styleJson,
        source: RdbCodec.text(resultSet, sourceIndex),
        aiArtifactId: aiArtifactId === undefined ? null : aiArtifactId,
        sourceContentHash: sourceContentHash === undefined ? null : sourceContentHash,
        enabled: RdbCodec.boolean(resultSet, enabledIndex, true),
        sortOrder: RdbCodec.integer(resultSet, sortOrderIndex),
        status: RdbCodec.integer(resultSet, statusIndex),
        schemaVersion: RdbCodec.integer(resultSet, schemaVersionIndex),
        createdAt: RdbCodec.integer(resultSet, createdAtIndex),
        updatedAt: RdbCodec.integer(resultSet, updatedAtIndex)
      });
    }
    return records;
  }

  private static isValid(item: BookContentProcess): boolean {
    return typeof item.id === 'string' && item.id.length > 0 &&
      typeof item.bookUrl === 'string' && typeof item.kind === 'string' &&
      typeof item.stage === 'string' && typeof item.target === 'string' &&
      typeof item.anchorJson === 'string' && typeof item.actionJson === 'string' &&
      typeof item.enabled === 'boolean' && typeof item.sortOrder === 'number' &&
      typeof item.status === 'number' && typeof item.createdAt === 'number' &&
      typeof item.updatedAt === 'number';
  }

  private static copyRecord(item: BookContentProcess): BookContentProcess {
    return {
      id: item.id,
      bookUrl: item.bookUrl,
      chapterIndex: item.chapterIndex,
      kind: item.kind,
      stage: item.stage,
      target: item.target,
      anchorJson: item.anchorJson,
      actionJson: item.actionJson,
      styleJson: item.styleJson,
      source: item.source,
      aiArtifactId: item.aiArtifactId,
      sourceContentHash: item.sourceContentHash,
      enabled: item.enabled,
      sortOrder: item.sortOrder,
      status: item.status,
      schemaVersion: item.schemaVersion,
      createdAt: item.createdAt,
      updatedAt: item.updatedAt
    };
  }

  private static copyWithEnabled(item: BookContentProcess, enabled: boolean, updatedAt: number): BookContentProcess {
    return {
      id: item.id, bookUrl: item.bookUrl, chapterIndex: item.chapterIndex, kind: item.kind, stage: item.stage,
      target: item.target, anchorJson: item.anchorJson, actionJson: item.actionJson, styleJson: item.styleJson,
      source: item.source, aiArtifactId: item.aiArtifactId, sourceContentHash: item.sourceContentHash,
      enabled: enabled, sortOrder: item.sortOrder, status: item.status, schemaVersion: item.schemaVersion,
      createdAt: item.createdAt, updatedAt: updatedAt
    };
  }

  private static copyWithStatus(item: BookContentProcess, status: number, updatedAt: number): BookContentProcess {
    return {
      id: item.id, bookUrl: item.bookUrl, chapterIndex: item.chapterIndex, kind: item.kind, stage: item.stage,
      target: item.target, anchorJson: item.anchorJson, actionJson: item.actionJson, styleJson: item.styleJson,
      source: item.source, aiArtifactId: item.aiArtifactId, sourceContentHash: item.sourceContentHash,
      enabled: item.enabled, sortOrder: item.sortOrder, status: status, schemaVersion: item.schemaVersion,
      createdAt: item.createdAt, updatedAt: updatedAt
    };
  }

}
