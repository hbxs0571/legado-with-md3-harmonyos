import { preferences } from '@kit.ArkData';
import { Context } from '@kit.AbilityKit';
import {
  BookshelfLayoutSettings, DEFAULT_BOOKSHELF_LAYOUT, copyBookshelfLayout
} from '../model/BookshelfLayout';

/**
 * 书架布局设置仓储。
 *
 * 与 ReaderSettingsRepository 不同，这里不做全量快照序列化：
 * 每个字段单独存一个 key，key 名与 Android PreferKey 完全一致，
 * 这样备份 config.xml 时可以直接按同名键读写，不需要额外映射表。
 */
export class BookshelfLayoutRepository {
  private static readonly preferenceName: string = 'legado_bookshelf_layout';
  private static cached: BookshelfLayoutSettings = copyBookshelfLayout(DEFAULT_BOOKSHELF_LAYOUT);
  private static loaded: boolean = false;
  private static saveQueue: Promise<void> = Promise.resolve();

  /** 读缓存；未 load 过时返回默认值。 */
  static get(): BookshelfLayoutSettings {
    return copyBookshelfLayout(BookshelfLayoutRepository.cached);
  }

  static isLoaded(): boolean {
    return BookshelfLayoutRepository.loaded;
  }

  /** 从 preferences 读取全部字段，缺项按默认值补齐。 */
  static async load(context: Context): Promise<BookshelfLayoutSettings> {
    const settings = copyBookshelfLayout(DEFAULT_BOOKSHELF_LAYOUT);
    try {
      const store = await preferences.getPreferences(context, BookshelfLayoutRepository.preferenceName);
      settings.bookGroupStyle = await BookshelfLayoutRepository.readInt(
        store, 'bookGroupStyle', settings.bookGroupStyle);
      settings.hideEmptyGroups = await BookshelfLayoutRepository.readBoolean(
        store, 'hideEmptyGroups', settings.hideEmptyGroups);
      settings.bookshelfSort = await BookshelfLayoutRepository.readInt(
        store, 'bookshelfSort', settings.bookshelfSort);
      settings.bookshelfSortOrder = await BookshelfLayoutRepository.readInt(
        store, 'bookshelfSortOrder', settings.bookshelfSortOrder);
      settings.bookshelfLayoutModePortrait = await BookshelfLayoutRepository.readInt(
        store, 'bookshelfLayoutPortrait', settings.bookshelfLayoutModePortrait);
      settings.bookshelfLayoutGridPortrait = await BookshelfLayoutRepository.readInt(
        store, 'bookshelfLayoutGridPortrait', settings.bookshelfLayoutGridPortrait);
      settings.bookshelfLayoutListPortrait = await BookshelfLayoutRepository.readInt(
        store, 'bookshelfLayoutListPortrait', settings.bookshelfLayoutListPortrait);
      settings.bookshelfTitleMaxLines = await BookshelfLayoutRepository.readInt(
        store, 'bookshelfTitleMaxLines', settings.bookshelfTitleMaxLines);
      settings.bookshelfCoverShadow = await BookshelfLayoutRepository.readBoolean(
        store, 'bookshelfCoverShadow', settings.bookshelfCoverShadow);
    } catch (_) {
      // 读失败时保持默认值：书架能用比抛错中断启动更重要。
    }
    BookshelfLayoutRepository.cached = copyBookshelfLayout(settings);
    BookshelfLayoutRepository.loaded = true;
    return copyBookshelfLayout(settings);
  }

  /** 覆盖保存整份设置，并按字段写回 preferences。 */
  static async save(context: Context, settings: BookshelfLayoutSettings): Promise<void> {
    const snapshot = copyBookshelfLayout(settings);
    // 串行写入，并将错误交给界面反馈；写入成功后再更新缓存。
    const operation = BookshelfLayoutRepository.saveQueue.then(async (): Promise<void> => {
      const store = await preferences.getPreferences(context, BookshelfLayoutRepository.preferenceName);
      await store.put('bookGroupStyle', snapshot.bookGroupStyle);
      await store.put('hideEmptyGroups', snapshot.hideEmptyGroups);
      await store.put('bookshelfSort', snapshot.bookshelfSort);
      await store.put('bookshelfSortOrder', snapshot.bookshelfSortOrder);
      await store.put('bookshelfLayoutPortrait', snapshot.bookshelfLayoutModePortrait);
      await store.put('bookshelfLayoutGridPortrait', snapshot.bookshelfLayoutGridPortrait);
      await store.put('bookshelfLayoutListPortrait', snapshot.bookshelfLayoutListPortrait);
      await store.put('bookshelfTitleMaxLines', snapshot.bookshelfTitleMaxLines);
      await store.put('bookshelfCoverShadow', snapshot.bookshelfCoverShadow);
      await store.flush();
      BookshelfLayoutRepository.cached = copyBookshelfLayout(snapshot);
      BookshelfLayoutRepository.loaded = true;
    });
    BookshelfLayoutRepository.saveQueue = operation.then((): void => undefined, (): void => undefined);
    await operation;
  }

  /**
   * 从 Android config.xml 的键值里挑出书架布局字段。
   *
   * 供备份恢复使用：只覆盖 xml 中确实存在的键，缺失的保持当前值，
   * 与上游恢复时逐项 readPreference 的语义一致。
   */
  static mergeFromAndroidValues(
    current: BookshelfLayoutSettings,
    values: Map<string, string>
  ): BookshelfLayoutSettings {
    const merged = copyBookshelfLayout(current);
    const groupStyle = BookshelfLayoutRepository.parseAndroidInt(values.get('bookGroupStyle'));
    if (groupStyle !== undefined) { merged.bookGroupStyle = groupStyle; }
    const hideEmpty = BookshelfLayoutRepository.parseAndroidBoolean(values.get('hideEmptyGroups'));
    if (hideEmpty !== undefined) { merged.hideEmptyGroups = hideEmpty; }
    const sort = BookshelfLayoutRepository.parseAndroidInt(values.get('bookshelfSort'));
    if (sort !== undefined) { merged.bookshelfSort = sort; }
    const sortOrder = BookshelfLayoutRepository.parseAndroidInt(values.get('bookshelfSortOrder'));
    if (sortOrder !== undefined) { merged.bookshelfSortOrder = sortOrder; }
    const mode = BookshelfLayoutRepository.parseAndroidInt(values.get('bookshelfLayoutPortrait'));
    if (mode !== undefined) { merged.bookshelfLayoutModePortrait = mode; }
    const grid = BookshelfLayoutRepository.parseAndroidInt(values.get('bookshelfLayoutGridPortrait'));
    if (grid !== undefined) { merged.bookshelfLayoutGridPortrait = grid; }
    const list = BookshelfLayoutRepository.parseAndroidInt(values.get('bookshelfLayoutListPortrait'));
    if (list !== undefined) { merged.bookshelfLayoutListPortrait = list; }
    const titleLines = BookshelfLayoutRepository.parseAndroidInt(values.get('bookshelfTitleMaxLines'));
    if (titleLines !== undefined) { merged.bookshelfTitleMaxLines = titleLines; }
    const shadow = BookshelfLayoutRepository.parseAndroidBoolean(values.get('bookshelfCoverShadow'));
    if (shadow !== undefined) { merged.bookshelfCoverShadow = shadow; }
    return merged;
  }

  /** 把当前设置转成写进 config.xml 的键值对，供备份使用。 */
  static toAndroidValues(settings: BookshelfLayoutSettings): Map<string, string> {
    const values = new Map<string, string>();
    values.set('bookGroupStyle', `${settings.bookGroupStyle}`);
    values.set('hideEmptyGroups', `${settings.hideEmptyGroups}`);
    values.set('bookshelfSort', `${settings.bookshelfSort}`);
    values.set('bookshelfSortOrder', `${settings.bookshelfSortOrder}`);
    values.set('bookshelfLayoutPortrait', `${settings.bookshelfLayoutModePortrait}`);
    values.set('bookshelfLayoutGridPortrait', `${settings.bookshelfLayoutGridPortrait}`);
    values.set('bookshelfLayoutListPortrait', `${settings.bookshelfLayoutListPortrait}`);
    values.set('bookshelfTitleMaxLines', `${settings.bookshelfTitleMaxLines}`);
    values.set('bookshelfCoverShadow', `${settings.bookshelfCoverShadow}`);
    return values;
  }

  private static async readInt(
    store: preferences.Preferences, key: string, fallback: number
  ): Promise<number> {
    const value = await store.get(key, fallback);
    return typeof value === 'number' && Number.isFinite(value) ? value : fallback;
  }

  private static async readBoolean(
    store: preferences.Preferences, key: string, fallback: boolean
  ): Promise<boolean> {
    const value = await store.get(key, fallback);
    return typeof value === 'boolean' ? value : fallback;
  }

  private static parseAndroidInt(raw: string | undefined): number | undefined {
    if (raw === undefined) { return undefined; }
    const value = Number(raw);
    return Number.isInteger(value) ? value : undefined;
  }

  private static parseAndroidBoolean(raw: string | undefined): boolean | undefined {
    if (raw === undefined) { return undefined; }
    const value = raw.toLowerCase();
    if (value === 'true') { return true; }
    if (value === 'false') { return false; }
    return undefined;
  }
}
