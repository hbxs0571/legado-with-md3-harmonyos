import { preferences } from '@kit.ArkData';

/**
 * 书签/笔记列表的排列方向偏好（批5，:153）。
 *
 * 上游的书签列表没有方向开关 —— `AllBookmarkViewModel.kt:214` 恒按
 * `compareBy({ chapterIndex }, { chapterPosition })` 升序。盘面 :153 引到的
 * `reverse_toc`（`TocScreen.kt:447` → `TocViewModel.kt:700-708` 取反落库）是
 * 「同一个列表反复横跳、且选择要落盘」的形态参考，方向文案用上游
 * `values-zh-rCN/strings.xml:1795-1796` 的「升序 / 降序」。
 *
 * 存成偏好而不是页面状态：页面关掉再进来方向还得在，所以离开页面不重置。
 */
export const BOOKMARK_SORT_DEFAULT_DESCENDING: boolean = false;

export class BookmarkListSettingsRepository {
  private static readonly preferenceName: string = 'legado_bookmark_list';
  private static readonly sortDescendingKey: string = 'sortDescending';

  static async loadSortDescending(context: Context): Promise<boolean> {
    try {
      const store = await preferences.getPreferences(context, BookmarkListSettingsRepository.preferenceName);
      const value = await store.get(BookmarkListSettingsRepository.sortDescendingKey,
        BOOKMARK_SORT_DEFAULT_DESCENDING);
      return typeof value === 'boolean' ? value : BOOKMARK_SORT_DEFAULT_DESCENDING;
    } catch (_) {
      return BOOKMARK_SORT_DEFAULT_DESCENDING;
    }
  }

  static async saveSortDescending(context: Context, descending: boolean): Promise<void> {
    const store = await preferences.getPreferences(context, BookmarkListSettingsRepository.preferenceName);
    await store.put(BookmarkListSettingsRepository.sortDescendingKey, descending);
    await store.flush();
  }
}