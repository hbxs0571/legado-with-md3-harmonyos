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
      settings.bookshelfTitleCenter = await BookshelfLayoutRepository.readBoolean(
        store, 'bookshelfTitleCenter', settings.bookshelfTitleCenter);
      settings.bookshelfTitleSmallFont = await BookshelfLayoutRepository.readBoolean(
        store, 'bookshelfTitleSmallFont', settings.bookshelfTitleSmallFont);
      settings.bookshelfGridCoverWidth = await BookshelfLayoutRepository.readInt(
        store, 'bookshelfGridCoverWidth', settings.bookshelfGridCoverWidth);
      settings.bookshelfListCoverWidth = await BookshelfLayoutRepository.readInt(
        store, 'bookshelfListCoverWidth', settings.bookshelfListCoverWidth);
      settings.bookshelfGridLayout = await BookshelfLayoutRepository.readInt(
        store, 'bookshelfGridLayout', settings.bookshelfGridLayout);
      settings.bookshelfLayoutCompact = await BookshelfLayoutRepository.readBoolean(
        store, 'bookshelfLayoutCompact', settings.bookshelfLayoutCompact);
      settings.bookshelfCardColor = await BookshelfLayoutRepository.readInt(
        store, 'bookshelfCardColor', settings.bookshelfCardColor);
      settings.bookshelfCardColorDark = await BookshelfLayoutRepository.readInt(
        store, 'bookshelfCardColorDark', settings.bookshelfCardColorDark);
      settings.bookshelfShowDivider = await BookshelfLayoutRepository.readBoolean(
        store, 'bookshelfShowDivider', settings.bookshelfShowDivider);
      settings.bookshelfListCoverCenter = await BookshelfLayoutRepository.readBoolean(
        store, 'bookshelfListCoverCenter', settings.bookshelfListCoverCenter);
      settings.bookshelfListIntroBelowContent = await BookshelfLayoutRepository.readBoolean(
        store, 'bookshelfListIntroBelowContent', settings.bookshelfListIntroBelowContent);
      settings.bookshelfShowIntro = await BookshelfLayoutRepository.readBoolean(
        store, 'bookshelfShowIntro', settings.bookshelfShowIntro);
      settings.bookshelfShowLatestChapter = await BookshelfLayoutRepository.readBoolean(
        store, 'bookshelfShowLatestChapter', settings.bookshelfShowLatestChapter);
      settings.bookshelfIntroMaxLines = await BookshelfLayoutRepository.readInt(
        store, 'bookshelfIntroMaxLines', settings.bookshelfIntroMaxLines);
      settings.showBookIntro = await BookshelfLayoutRepository.readBoolean(
        store, 'showBookIntro', settings.showBookIntro);
      settings.bookshelfSearchActionDirectToSearch = await BookshelfLayoutRepository.readBoolean(
        store, 'bookshelfSearchActionDirectToSearch', settings.bookshelfSearchActionDirectToSearch);
      settings.showBookshelfFastScroller = await BookshelfLayoutRepository.readBoolean(
        store, 'showBookshelfFastScroller', settings.showBookshelfFastScroller);
      settings.autoRefreshBook = await BookshelfLayoutRepository.readBoolean(
        store, 'auto_refresh', settings.autoRefreshBook);
      settings.saveTabPosition = await BookshelfLayoutRepository.readString(
        store, 'bookshelfSelectedGroupId', settings.saveTabPosition);
      settings.bookshelfLayoutModeLandscape = await BookshelfLayoutRepository.readInt(
        store, 'bookshelf_layout_landscape', settings.bookshelfLayoutModeLandscape);
      settings.bookshelfLayoutGridLandscape = await BookshelfLayoutRepository.readInt(
        store, 'bookshelfLayoutGridLandscape', settings.bookshelfLayoutGridLandscape);
      settings.bookshelfLayoutListLandscape = await BookshelfLayoutRepository.readInt(
        store, 'bookshelfLayoutListLandscape', settings.bookshelfLayoutListLandscape);
      settings.bookshelfFolderLayoutModePortrait = await BookshelfLayoutRepository.readInt(
        store, 'bookshelfFolderLayoutModePortrait', settings.bookshelfFolderLayoutModePortrait);
      settings.bookshelfFolderLayoutModeLandscape = await BookshelfLayoutRepository.readInt(
        store, 'bookshelfFolderLayoutModeLandscape', settings.bookshelfFolderLayoutModeLandscape);
      settings.bookshelfFolderLayoutGridPortrait = await BookshelfLayoutRepository.readInt(
        store, 'bookshelfFolderLayoutGridPortrait', settings.bookshelfFolderLayoutGridPortrait);
      settings.bookshelfFolderLayoutGridLandscape = await BookshelfLayoutRepository.readInt(
        store, 'bookshelfFolderLayoutGridLandscape', settings.bookshelfFolderLayoutGridLandscape);
      settings.bookshelfFolderLayoutListPortrait = await BookshelfLayoutRepository.readInt(
        store, 'bookshelfFolderLayoutListPortrait', settings.bookshelfFolderLayoutListPortrait);
      settings.bookshelfFolderLayoutListLandscape = await BookshelfLayoutRepository.readInt(
        store, 'bookshelfFolderLayoutListLandscape', settings.bookshelfFolderLayoutListLandscape);
      settings.bookshelfGroupListStyle = await BookshelfLayoutRepository.readInt(
        store, 'bookshelfGroupListStyle', settings.bookshelfGroupListStyle);
      settings.bookshelfGroupCoverCount = await BookshelfLayoutRepository.readInt(
        store, 'bookshelfGroupCoverCount', settings.bookshelfGroupCoverCount);
      settings.bookshelfRefreshingLimit = await BookshelfLayoutRepository.readInt(
        store, 'bookshelfRefreshingLimit', settings.bookshelfRefreshingLimit);
      settings.showBookshelfTabMenu = await BookshelfLayoutRepository.readBoolean(
        store, 'shouldShowExpandButton', settings.showBookshelfTabMenu);
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
      await store.put('bookshelfTitleCenter', snapshot.bookshelfTitleCenter);
      await store.put('bookshelfTitleSmallFont', snapshot.bookshelfTitleSmallFont);
      await store.put('bookshelfGridCoverWidth', snapshot.bookshelfGridCoverWidth);
      await store.put('bookshelfListCoverWidth', snapshot.bookshelfListCoverWidth);
      await store.put('bookshelfGridLayout', snapshot.bookshelfGridLayout);
      await store.put('bookshelfLayoutCompact', snapshot.bookshelfLayoutCompact);
      await store.put('bookshelfCardColor', snapshot.bookshelfCardColor);
      await store.put('bookshelfCardColorDark', snapshot.bookshelfCardColorDark);
      await store.put('bookshelfShowDivider', snapshot.bookshelfShowDivider);
      await store.put('bookshelfListCoverCenter', snapshot.bookshelfListCoverCenter);
      await store.put('bookshelfListIntroBelowContent', snapshot.bookshelfListIntroBelowContent);
      await store.put('bookshelfShowIntro', snapshot.bookshelfShowIntro);
      await store.put('bookshelfShowLatestChapter', snapshot.bookshelfShowLatestChapter);
      await store.put('bookshelfIntroMaxLines', snapshot.bookshelfIntroMaxLines);
      await store.put('showBookIntro', snapshot.showBookIntro);
      await store.put('bookshelfSearchActionDirectToSearch', snapshot.bookshelfSearchActionDirectToSearch);
      await store.put('showBookshelfFastScroller', snapshot.showBookshelfFastScroller);
      await store.put('auto_refresh', snapshot.autoRefreshBook);
      await store.put('bookshelfSelectedGroupId', snapshot.saveTabPosition);
      await store.put('bookshelf_layout_landscape', snapshot.bookshelfLayoutModeLandscape);
      await store.put('bookshelfLayoutGridLandscape', snapshot.bookshelfLayoutGridLandscape);
      await store.put('bookshelfLayoutListLandscape', snapshot.bookshelfLayoutListLandscape);
      await store.put('bookshelfFolderLayoutModePortrait', snapshot.bookshelfFolderLayoutModePortrait);
      await store.put('bookshelfFolderLayoutModeLandscape', snapshot.bookshelfFolderLayoutModeLandscape);
      await store.put('bookshelfFolderLayoutGridPortrait', snapshot.bookshelfFolderLayoutGridPortrait);
      await store.put('bookshelfFolderLayoutGridLandscape', snapshot.bookshelfFolderLayoutGridLandscape);
      await store.put('bookshelfFolderLayoutListPortrait', snapshot.bookshelfFolderLayoutListPortrait);
      await store.put('bookshelfFolderLayoutListLandscape', snapshot.bookshelfFolderLayoutListLandscape);
      await store.put('bookshelfGroupListStyle', snapshot.bookshelfGroupListStyle);
      await store.put('bookshelfGroupCoverCount', snapshot.bookshelfGroupCoverCount);
      await store.put('bookshelfRefreshingLimit', snapshot.bookshelfRefreshingLimit);
      await store.put('shouldShowExpandButton', snapshot.showBookshelfTabMenu);
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
    const titleCenter = BookshelfLayoutRepository.parseAndroidBoolean(values.get('bookshelfTitleCenter'));
    if (titleCenter !== undefined) { merged.bookshelfTitleCenter = titleCenter; }
    const titleSmallFont = BookshelfLayoutRepository.parseAndroidBoolean(values.get('bookshelfTitleSmallFont'));
    if (titleSmallFont !== undefined) { merged.bookshelfTitleSmallFont = titleSmallFont; }
    const gridCoverWidth = BookshelfLayoutRepository.parseAndroidInt(values.get('bookshelfGridCoverWidth'));
    if (gridCoverWidth !== undefined) { merged.bookshelfGridCoverWidth = gridCoverWidth; }
    const listCoverWidth = BookshelfLayoutRepository.parseAndroidInt(values.get('bookshelfListCoverWidth'));
    if (listCoverWidth !== undefined) { merged.bookshelfListCoverWidth = listCoverWidth; }
    const bookshelfGridLayout = BookshelfLayoutRepository.parseAndroidInt(values.get('bookshelfGridLayout'));
    if (bookshelfGridLayout !== undefined) { merged.bookshelfGridLayout = bookshelfGridLayout; }
    const bookshelfLayoutCompact = BookshelfLayoutRepository.parseAndroidBoolean(values.get('bookshelfLayoutCompact'));
    if (bookshelfLayoutCompact !== undefined) { merged.bookshelfLayoutCompact = bookshelfLayoutCompact; }
    const bookshelfCardColor = BookshelfLayoutRepository.parseAndroidInt(values.get('bookshelfCardColor'));
    if (bookshelfCardColor !== undefined) { merged.bookshelfCardColor = bookshelfCardColor; }
    const bookshelfCardColorDark = BookshelfLayoutRepository.parseAndroidInt(values.get('bookshelfCardColorDark'));
    if (bookshelfCardColorDark !== undefined) { merged.bookshelfCardColorDark = bookshelfCardColorDark; }
    const bookshelfShowDivider = BookshelfLayoutRepository.parseAndroidBoolean(values.get('bookshelfShowDivider'));
    if (bookshelfShowDivider !== undefined) { merged.bookshelfShowDivider = bookshelfShowDivider; }
    const bookshelfListCoverCenter = BookshelfLayoutRepository.parseAndroidBoolean(values.get('bookshelfListCoverCenter'));
    if (bookshelfListCoverCenter !== undefined) { merged.bookshelfListCoverCenter = bookshelfListCoverCenter; }
    const bookshelfListIntroBelowContent = BookshelfLayoutRepository.parseAndroidBoolean(values.get('bookshelfListIntroBelowContent'));
    if (bookshelfListIntroBelowContent !== undefined) { merged.bookshelfListIntroBelowContent = bookshelfListIntroBelowContent; }
    const bookshelfShowIntro = BookshelfLayoutRepository.parseAndroidBoolean(values.get('bookshelfShowIntro'));
    if (bookshelfShowIntro !== undefined) { merged.bookshelfShowIntro = bookshelfShowIntro; }
    const bookshelfShowLatestChapter = BookshelfLayoutRepository.parseAndroidBoolean(values.get('bookshelfShowLatestChapter'));
    if (bookshelfShowLatestChapter !== undefined) { merged.bookshelfShowLatestChapter = bookshelfShowLatestChapter; }
    const bookshelfIntroMaxLines = BookshelfLayoutRepository.parseAndroidInt(values.get('bookshelfIntroMaxLines'));
    if (bookshelfIntroMaxLines !== undefined) { merged.bookshelfIntroMaxLines = bookshelfIntroMaxLines; }
    const showBookIntro = BookshelfLayoutRepository.parseAndroidBoolean(values.get('showBookIntro'));
    if (showBookIntro !== undefined) { merged.showBookIntro = showBookIntro; }
    const bookshelfSearchActionDirectToSearch = BookshelfLayoutRepository.parseAndroidBoolean(values.get('bookshelfSearchActionDirectToSearch'));
    if (bookshelfSearchActionDirectToSearch !== undefined) { merged.bookshelfSearchActionDirectToSearch = bookshelfSearchActionDirectToSearch; }
    const showBookshelfFastScroller = BookshelfLayoutRepository.parseAndroidBoolean(values.get('showBookshelfFastScroller'));
    if (showBookshelfFastScroller !== undefined) { merged.showBookshelfFastScroller = showBookshelfFastScroller; }
    const autoRefreshBook = BookshelfLayoutRepository.parseAndroidBoolean(values.get('auto_refresh'));
    if (autoRefreshBook !== undefined) { merged.autoRefreshBook = autoRefreshBook; }
    const saveTabPosition = values.get('bookshelfSelectedGroupId');
    if (saveTabPosition !== undefined) { merged.saveTabPosition = saveTabPosition; }
    const bookshelfLayoutModeLandscape = BookshelfLayoutRepository.parseAndroidInt(values.get('bookshelf_layout_landscape'));
    if (bookshelfLayoutModeLandscape !== undefined) { merged.bookshelfLayoutModeLandscape = bookshelfLayoutModeLandscape; }
    const bookshelfLayoutGridLandscape = BookshelfLayoutRepository.parseAndroidInt(values.get('bookshelfLayoutGridLandscape'));
    if (bookshelfLayoutGridLandscape !== undefined) { merged.bookshelfLayoutGridLandscape = bookshelfLayoutGridLandscape; }
    const bookshelfLayoutListLandscape = BookshelfLayoutRepository.parseAndroidInt(values.get('bookshelfLayoutListLandscape'));
    if (bookshelfLayoutListLandscape !== undefined) { merged.bookshelfLayoutListLandscape = bookshelfLayoutListLandscape; }
    const bookshelfFolderLayoutModePortrait = BookshelfLayoutRepository.parseAndroidInt(values.get('bookshelfFolderLayoutModePortrait'));
    if (bookshelfFolderLayoutModePortrait !== undefined) { merged.bookshelfFolderLayoutModePortrait = bookshelfFolderLayoutModePortrait; }
    const bookshelfFolderLayoutModeLandscape = BookshelfLayoutRepository.parseAndroidInt(values.get('bookshelfFolderLayoutModeLandscape'));
    if (bookshelfFolderLayoutModeLandscape !== undefined) { merged.bookshelfFolderLayoutModeLandscape = bookshelfFolderLayoutModeLandscape; }
    const bookshelfFolderLayoutGridPortrait = BookshelfLayoutRepository.parseAndroidInt(values.get('bookshelfFolderLayoutGridPortrait'));
    if (bookshelfFolderLayoutGridPortrait !== undefined) { merged.bookshelfFolderLayoutGridPortrait = bookshelfFolderLayoutGridPortrait; }
    const bookshelfFolderLayoutGridLandscape = BookshelfLayoutRepository.parseAndroidInt(values.get('bookshelfFolderLayoutGridLandscape'));
    if (bookshelfFolderLayoutGridLandscape !== undefined) { merged.bookshelfFolderLayoutGridLandscape = bookshelfFolderLayoutGridLandscape; }
    const bookshelfFolderLayoutListPortrait = BookshelfLayoutRepository.parseAndroidInt(values.get('bookshelfFolderLayoutListPortrait'));
    if (bookshelfFolderLayoutListPortrait !== undefined) { merged.bookshelfFolderLayoutListPortrait = bookshelfFolderLayoutListPortrait; }
    const bookshelfFolderLayoutListLandscape = BookshelfLayoutRepository.parseAndroidInt(values.get('bookshelfFolderLayoutListLandscape'));
    if (bookshelfFolderLayoutListLandscape !== undefined) { merged.bookshelfFolderLayoutListLandscape = bookshelfFolderLayoutListLandscape; }
    const bookshelfGroupListStyle = BookshelfLayoutRepository.parseAndroidInt(values.get('bookshelfGroupListStyle'));
    if (bookshelfGroupListStyle !== undefined) { merged.bookshelfGroupListStyle = bookshelfGroupListStyle; }
    const bookshelfGroupCoverCount = BookshelfLayoutRepository.parseAndroidInt(values.get('bookshelfGroupCoverCount'));
    if (bookshelfGroupCoverCount !== undefined) { merged.bookshelfGroupCoverCount = bookshelfGroupCoverCount; }
    const bookshelfRefreshingLimit = BookshelfLayoutRepository.parseAndroidInt(values.get('bookshelfRefreshingLimit'));
    if (bookshelfRefreshingLimit !== undefined) { merged.bookshelfRefreshingLimit = bookshelfRefreshingLimit; }
    const shouldShowExpandButton = BookshelfLayoutRepository.parseAndroidBoolean(values.get('shouldShowExpandButton'));
    if (shouldShowExpandButton !== undefined) { merged.showBookshelfTabMenu = shouldShowExpandButton; }
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
    values.set('bookshelfTitleCenter', `${settings.bookshelfTitleCenter}`);
    values.set('bookshelfTitleSmallFont', `${settings.bookshelfTitleSmallFont}`);
    values.set('bookshelfGridCoverWidth', `${settings.bookshelfGridCoverWidth}`);
    values.set('bookshelfListCoverWidth', `${settings.bookshelfListCoverWidth}`);
    values.set('bookshelfGridLayout', `${settings.bookshelfGridLayout}`);
    values.set('bookshelfLayoutCompact', `${settings.bookshelfLayoutCompact}`);
    values.set('bookshelfCardColor', `${settings.bookshelfCardColor}`);
    values.set('bookshelfCardColorDark', `${settings.bookshelfCardColorDark}`);
    values.set('bookshelfShowDivider', `${settings.bookshelfShowDivider}`);
    values.set('bookshelfListCoverCenter', `${settings.bookshelfListCoverCenter}`);
    values.set('bookshelfListIntroBelowContent', `${settings.bookshelfListIntroBelowContent}`);
    values.set('bookshelfShowIntro', `${settings.bookshelfShowIntro}`);
    values.set('bookshelfShowLatestChapter', `${settings.bookshelfShowLatestChapter}`);
    values.set('bookshelfIntroMaxLines', `${settings.bookshelfIntroMaxLines}`);
    values.set('showBookIntro', `${settings.showBookIntro}`);
    values.set('bookshelfSearchActionDirectToSearch', `${settings.bookshelfSearchActionDirectToSearch}`);
    values.set('showBookshelfFastScroller', `${settings.showBookshelfFastScroller}`);
    values.set('auto_refresh', `${settings.autoRefreshBook}`);
    values.set('bookshelfSelectedGroupId', `${settings.saveTabPosition}`);
    values.set('bookshelf_layout_landscape', `${settings.bookshelfLayoutModeLandscape}`);
    values.set('bookshelfLayoutGridLandscape', `${settings.bookshelfLayoutGridLandscape}`);
    values.set('bookshelfLayoutListLandscape', `${settings.bookshelfLayoutListLandscape}`);
    values.set('bookshelfFolderLayoutModePortrait', `${settings.bookshelfFolderLayoutModePortrait}`);
    values.set('bookshelfFolderLayoutModeLandscape', `${settings.bookshelfFolderLayoutModeLandscape}`);
    values.set('bookshelfFolderLayoutGridPortrait', `${settings.bookshelfFolderLayoutGridPortrait}`);
    values.set('bookshelfFolderLayoutGridLandscape', `${settings.bookshelfFolderLayoutGridLandscape}`);
    values.set('bookshelfFolderLayoutListPortrait', `${settings.bookshelfFolderLayoutListPortrait}`);
    values.set('bookshelfFolderLayoutListLandscape', `${settings.bookshelfFolderLayoutListLandscape}`);
    values.set('bookshelfGroupListStyle', `${settings.bookshelfGroupListStyle}`);
    values.set('bookshelfGroupCoverCount', `${settings.bookshelfGroupCoverCount}`);
    values.set('bookshelfRefreshingLimit', `${settings.bookshelfRefreshingLimit}`);
    values.set('shouldShowExpandButton', `${settings.showBookshelfTabMenu}`);
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

  private static async readString(
    store: preferences.Preferences, key: string, fallback: string
  ): Promise<string> {
    const value = await store.get(key, fallback);
    return typeof value === 'string' ? value : fallback;
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
