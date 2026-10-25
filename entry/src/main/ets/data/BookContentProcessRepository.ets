import { preferences } from '@kit.ArkData';
import { BookContentProcess, CONTENT_PROCESS_STATUS_DELETED, toContentProcessDisplayItem } from '../model/BookContentProcess';

/** 正文处理记录本地存取；JSON 字段与 Android 数据实体保持同名。 */
export class BookContentProcessRepository {
  private static readonly preferenceName: string = 'legado_book_content_processes';
  private static readonly preferenceKey: string = 'records_v1';
  private static cachedRecords: BookContentProcess[] = [];
  private static loadTask: Promise<void> | undefined = undefined;

  static getAll(): BookContentProcess[] {
    return BookContentProcessRepository.cachedRecords.map((item: BookContentProcess): BookContentProcess =>
      BookContentProcessRepository.copyRecord(item));
  }

  static async load(context: Context): Promise<void> {
    if (BookContentProcessRepository.loadTask !== undefined) {
      await BookContentProcessRepository.loadTask;
      return;
    }
    BookContentProcessRepository.loadTask = BookContentProcessRepository.loadFromPreferences(context);
    await BookContentProcessRepository.loadTask;
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

  static async waitUntilLoaded(): Promise<void> {
    if (BookContentProcessRepository.loadTask !== undefined) {
      await BookContentProcessRepository.loadTask;
    }
  }

  static getForChapter(bookUrl: string, chapterIndex: number): BookContentProcess[] {
    return BookContentProcessRepository.cachedRecords
      .filter((item: BookContentProcess) => item.bookUrl === bookUrl &&
        (item.chapterIndex === null || item.chapterIndex === undefined || item.chapterIndex === chapterIndex) &&
        item.status !== CONTENT_PROCESS_STATUS_DELETED && toContentProcessDisplayItem(item) !== undefined)
      .sort((left: BookContentProcess, right: BookContentProcess) =>
        left.sortOrder - right.sortOrder || left.createdAt - right.createdAt)
      .map((item: BookContentProcess): BookContentProcess => BookContentProcessRepository.copyRecord(item));
  }

  static async upsert(context: Context, process: BookContentProcess): Promise<void> {
    if (!BookContentProcessRepository.isValid(process)) {
      throw new Error('正文处理记录无效');
    }
    const next: BookContentProcess[] = BookContentProcessRepository.cachedRecords
      .filter((item: BookContentProcess) => item.id !== process.id)
      .map((item: BookContentProcess): BookContentProcess => BookContentProcessRepository.copyRecord(item));
    next.push(BookContentProcessRepository.copyRecord(process));
    await BookContentProcessRepository.persist(context, next);
  }

  static async setEnabled(context: Context, id: string, enabled: boolean): Promise<void> {
    const next: BookContentProcess[] = BookContentProcessRepository.cachedRecords.map(
      (item: BookContentProcess): BookContentProcess => item.id === id
        ? BookContentProcessRepository.copyWithEnabled(item, enabled, Date.now())
        : BookContentProcessRepository.copyRecord(item));
    await BookContentProcessRepository.persist(context, next);
  }

  static async markDeleted(context: Context, id: string): Promise<void> {
    const next: BookContentProcess[] = BookContentProcessRepository.cachedRecords.map(
      (item: BookContentProcess): BookContentProcess => item.id === id
        ? BookContentProcessRepository.copyWithStatus(item, CONTENT_PROCESS_STATUS_DELETED, Date.now())
        : BookContentProcessRepository.copyRecord(item));
    await BookContentProcessRepository.persist(context, next);
  }

  private static async persist(context: Context, records: BookContentProcess[]): Promise<void> {
    const ordered: BookContentProcess[] = records
      .map((item: BookContentProcess): BookContentProcess => BookContentProcessRepository.copyRecord(item))
      .sort((left: BookContentProcess, right: BookContentProcess) =>
        left.sortOrder - right.sortOrder || left.createdAt - right.createdAt);
    const store = await preferences.getPreferences(context, BookContentProcessRepository.preferenceName);
    await store.put(BookContentProcessRepository.preferenceKey, JSON.stringify(ordered));
    await store.flush();
    BookContentProcessRepository.cachedRecords = ordered;
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