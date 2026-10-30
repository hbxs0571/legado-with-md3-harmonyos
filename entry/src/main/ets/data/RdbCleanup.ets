import { preferences } from '@kit.ArkData';
import { RdbMigration } from './RdbMigration';

/**
 * 清理已迁走的 preferences 老数据。
 *
 * 上游的做法是「默认删」：`SharedPreferencesMigration` 的 `cleanUp()`
 * 默认实现会在搬迁成功后删掉源 SharedPreferences 文件，要保留必须
 * 显式写 `override suspend fun cleanUp() = Unit`。这里对齐默认语义。
 *
 * 三条保护：
 * 1. 三批搬迁标记必须全部写完才动手——少一个批次就说明还有数据没搬，
 *    此时删掉老数据等于丢数据。
 * 2. 清理自己也有标记，删完写时间戳，之后不再重复走。
 * 3. 全程 try/catch：清理失败不写标记、不抛异常、不阻塞启动，
 *    下个版本启动时重试。数据已经在 SQLite 里，界面照常可用。
 *
 * 只删「已迁走」的键，未迁的一律留着：
 * - `legado_read_records` 的 `enabled`（上游存在偏好里，不是表）
 * - `legado_replace_rules` 的 `default_enabled_v1` 与 `sort_mode_v1`
 *   （上游 `PreferKey.replaceEnableDefault` / `PreferKey.replaceSortMode`）
 */
export class RdbCleanup {
  /** 清理完成的标记键，值存完成时间戳。 */
  private static readonly markerKey: string = 'rdb_cleanup_v1_1';
  private static readonly preferenceName: string = 'legado_rdb_cleanup';

  /** 整个文件都只存已迁走数据的 preferences，直接删文件。 */
  private static readonly wholeFiles: string[] = [
    'legado_reader_bookmarks',
    'legado_reader_markings',
    'legado_reader_search_history',
    'legado_txt_toc_rules',
    'book_group_store',
    'legado_reader_highlight_rules',
    'legado_book_content_processes',
    'legado_local_books',
    'legado_read_time_records'
  ];

  /**
   * 按需清理：三批搬迁全部完成且尚未清理过时执行。
   *
   * 返回 true 表示本次实际删了东西。
   */
  static async runIfNeeded(context: Context): Promise<boolean> {
    try {
      if (await RdbCleanup.isDone(context)) {
        return false;
      }
      if (!(await RdbCleanup.migrationFinished(context))) {
        return false;
      }
      await RdbCleanup.cleanup(context);
      await RdbCleanup.writeMarker(context);
      return true;
    } catch (error) {
      // 清理是可重试的后台动作，失败不该让启动流程受影响
      if (error instanceof Error) {
        console.error(`RdbCleanup 清理失败，下个版本重试：${error.message}`);
      }
      return false;
    }
  }

  /** 已清理过。 */
  static async isDone(context: Context): Promise<boolean> {
    try {
      const store = await preferences.getPreferences(context, RdbCleanup.preferenceName);
      const value = await store.get(RdbCleanup.markerKey, 0);
      return typeof value === 'number' && value > 0;
    } catch (_) {
      return false;
    }
  }

  /** 三批搬迁标记是否全部已写。任何一批没完成都不能删老数据。 */
  private static async migrationFinished(context: Context): Promise<boolean> {
    const first = await RdbMigration.isDone(context, 'rdb_migrated_v1_1');
    if (!first) {
      return false;
    }
    const second = await RdbMigration.isDone(context, 'rdb_migrated_v1_2');
    if (!second) {
      return false;
    }
    return await RdbMigration.isDone(context, 'rdb_migrated_v1_3');
  }

  private static async cleanup(context: Context): Promise<void> {
    // 9 个文件里没有需要保留的键，整文件删掉最干净
    for (const name of RdbCleanup.wholeFiles) {
      try {
        await preferences.deletePreferences(context, name);
      } catch (_) {
        // 单个文件删不掉不影响其它文件继续删；标记仍会写入，
        // 但残留的文件不含独有数据，不会造成一致性问题
      }
    }
    // 两个文件里混着要保留的键，只能按键删
    await RdbCleanup.deleteKeys(context, 'legado_read_records', ['sessions_v1']);
    await RdbCleanup.deleteKeys(context, 'legado_replace_rules', ['rules_v1', 'book_overrides_v1']);
  }

  /** 从指定 preferences 里删掉若干键，然后 flush。 */
  private static async deleteKeys(context: Context, name: string, keys: string[]): Promise<void> {
    try {
      const store = await preferences.getPreferences(context, name);
      for (const key of keys) {
        await store.delete(key);
      }
      await store.flush();
    } catch (_) {
      // 同 cleanup：删不掉就留着，不影响其它键与后续启动
    }
  }

  private static async writeMarker(context: Context): Promise<void> {
    const store = await preferences.getPreferences(context, RdbCleanup.preferenceName);
    await store.put(RdbCleanup.markerKey, Date.now());
    await store.flush();
  }
}
