import { preferences } from '@kit.ArkData';

/**
 * 通用本地 UI 状态偏好门面，对齐上游
 * `data/local/preferences/LocalPreferences.kt`（库定义 + 键表）与
 * `data/repository/SettingsRepository.kt`（读写门面）。
 *
 * 上游的容器是 `preferencesDataStore(name = "local_ui_status")`（`LocalPreferences.kt:13`），
 * 键由 `object LocalPreferencesKeys` 集中声明（`:15-79`）；读写经 `SettingsRepository`
 * 的 `getPreference(key, default)` / `updatePreference(key, value)` 统一走一遍。
 * 本地此前没有这层通用门面，每个页面各建一个按域命名的 preferences 库
 * （如探索页的 `legado_explore_layout`），键名虽然照抄上游，容器却是另一份。
 *
 * 本文件按上游形状补齐两件事：
 *   ① 库名统一为 `local_ui_status`，键名与上游逐字相同；
 *   ② 提供 `getInt/putInt/getString/putString/getBoolean/putBoolean` 通用读写，
 *      新增键只需在 `LocalPreferencesKeys` 里加一行，不必再建库。
 *
 * 迁移：早期版本把探索页三个键写在 `legado_explore_layout` 库里。`load()` 首次调用时
 * 若 `__local_ui_status_migrated_to_settings` 不为 true，就把旧库的值搬进新库并置位，
 * 对齐上游 `LocalUiStatusMigration`（`SettingsRepository.kt:44-59`）的「搬一次、留标记」语义。
 */

/** 上游 `LocalPreferences.kt:13` 的库名。 */
export const LOCAL_PREFERENCES_NAME: string = 'local_ui_status';

/** 早期本地库名，仅用于一次性迁移。 */
const LEGACY_EXPLORE_PREFERENCES_NAME: string = 'legado_explore_layout';

/**
 * 键表，对齐上游 `LocalPreferencesKeys`（`LocalPreferences.kt:15-79`）。
 * 只收录本地已落地的键；新增时照上游命名加在这里。
 */
export class LocalPreferencesKeys {
  /** 上游 `MIGRATED_TO_SETTINGS`：迁移完成标记。 */
  static readonly MIGRATED_TO_SETTINGS: string = '__local_ui_status_migrated_to_settings';
  /** 上游 `SHOW_THEME_REFACTOR_TIP`。 */
  static readonly SHOW_THEME_REFACTOR_TIP: string = 'show_theme_refactor_tip';
  /** 上游 `SEARCH_LAYOUT_MODE`：搜索结果页布局模式。 */
  static readonly SEARCH_LAYOUT_MODE: string = 'search_layout_mode';
  /** 上游 `SEARCH_SCOPE`：搜索范围。 */
  static readonly SEARCH_SCOPE: string = 'search_scope';
  /** 上游 `MATCH_MODE`：搜索匹配模式。 */
  static readonly MATCH_MODE: string = 'match_mode';
  /** 上游 `EXPLORE_LAYOUT_MODE`：探索结果页布局模式（0 列表 / 1 网格）。 */
  static readonly EXPLORE_LAYOUT_MODE: string = 'explore_layout_mode';
  /** 上游 `EXPLORE_LAYOUT_GRID_PORTRAIT`：竖屏网格列数。 */
  static readonly EXPLORE_LAYOUT_GRID_PORTRAIT: string = 'explore_layout_grid_portrait';
  /** 上游 `EXPLORE_LAYOUT_GRID_LANDSCAPE`：横屏网格列数。 */
  static readonly EXPLORE_LAYOUT_GRID_LANDSCAPE: string = 'explore_layout_grid_landscape';
  /** 上游 `READ_URL_IN_BROWSER`。 */
  static readonly READ_URL_IN_BROWSER: string = 'read_url_in_browser';
}

export class LocalPreferencesRepository {
  private static store: preferences.Preferences | undefined = undefined;
  private static migrating: Promise<void> | undefined = undefined;

  /** 取库句柄；未 load 过时返回 undefined（读侧退化为默认值，与上游 requireCore 前的行为一致）。 */
  private static current(): preferences.Preferences | undefined {
    return LocalPreferencesRepository.store;
  }

  /**
   * 打开库并完成一次性迁移。多次调用只真正执行一次；
   * 与 `load` 并发时复用同一个 Promise，避免重复迁移。
   */
  static async load(context: Context): Promise<void> {
    if (LocalPreferencesRepository.store !== undefined) { return; }
    const running = LocalPreferencesRepository.migrating;
    if (running !== undefined) {
      await running;
      return;
    }
    const task: Promise<void> = LocalPreferencesRepository.openAndMigrate(context);
    LocalPreferencesRepository.migrating = task;
    try {
      await task;
    } finally {
      LocalPreferencesRepository.migrating = undefined;
    }
  }

  private static async openAndMigrate(context: Context): Promise<void> {
    const store = await preferences.getPreferences(context, LOCAL_PREFERENCES_NAME);
    LocalPreferencesRepository.store = store;
    await LocalPreferencesRepository.migrateLegacyExploreKeys(context, store);
  }

  /**
   * 把早期 `legado_explore_layout` 库里的三个键搬进新库。
   * 语义对齐上游 `LocalUiStatusMigration`：已有值不覆盖、搬完置位标记。
   */
  private static async migrateLegacyExploreKeys(context: Context,
    store: preferences.Preferences): Promise<void> {
    const migrated = store.getSync(LocalPreferencesKeys.MIGRATED_TO_SETTINGS, false) as boolean;
    if (migrated) { return; }
    try {
      const legacy = await preferences.getPreferences(context, LEGACY_EXPLORE_PREFERENCES_NAME);
      const mode = legacy.getSync(LocalPreferencesKeys.EXPLORE_LAYOUT_MODE, -1) as number;
      const portrait = legacy.getSync(LocalPreferencesKeys.EXPLORE_LAYOUT_GRID_PORTRAIT, -1) as number;
      const landscape = legacy.getSync(LocalPreferencesKeys.EXPLORE_LAYOUT_GRID_LANDSCAPE, -1) as number;
      if (mode >= 0 && store.getSync(LocalPreferencesKeys.EXPLORE_LAYOUT_MODE, -1) === -1) {
        await store.put(LocalPreferencesKeys.EXPLORE_LAYOUT_MODE, mode);
      }
      if (portrait >= 0 &&
        (store.getSync(LocalPreferencesKeys.EXPLORE_LAYOUT_GRID_PORTRAIT, -1) as number) === -1) {
        await store.put(LocalPreferencesKeys.EXPLORE_LAYOUT_GRID_PORTRAIT, portrait);
      }
      if (landscape >= 0 &&
        (store.getSync(LocalPreferencesKeys.EXPLORE_LAYOUT_GRID_LANDSCAPE, -1) as number) === -1) {
        await store.put(LocalPreferencesKeys.EXPLORE_LAYOUT_GRID_LANDSCAPE, landscape);
      }
    } catch (error) {
      // 旧库不存在是正常情况（全新安装），不阻断新库使用
      console.info(`本地 UI 状态迁移：旧库不存在或读取失败 ${error instanceof Error ? error.message : String(error)}`);
    }
    await store.put(LocalPreferencesKeys.MIGRATED_TO_SETTINGS, true);
    await store.flush();
  }

  /** 同步读 int；未 load 时返回默认值（对齐上游 `getPreference(key, default)` 的回落语义）。 */
  static getInt(key: string, defaultValue: number): number {
    const store = LocalPreferencesRepository.current();
    if (store === undefined) { return defaultValue; }
    return store.getSync(key, defaultValue) as number;
  }

  /** 同步读 string。 */
  static getString(key: string, defaultValue: string): string {
    const store = LocalPreferencesRepository.current();
    if (store === undefined) { return defaultValue; }
    return store.getSync(key, defaultValue) as string;
  }

  /** 同步读 boolean。 */
  static getBoolean(key: string, defaultValue: boolean): boolean {
    const store = LocalPreferencesRepository.current();
    if (store === undefined) { return defaultValue; }
    return store.getSync(key, defaultValue) as boolean;
  }

  /** 写 int 并落盘（对齐上游 `updatePreference`：先落盘再让读侧可见）。 */
  static async putInt(context: Context, key: string, value: number): Promise<void> {
    const store = await LocalPreferencesRepository.require(context);
    await store.put(key, value);
    await store.flush();
  }

  /** 写 string 并落盘。 */
  static async putString(context: Context, key: string, value: string): Promise<void> {
    const store = await LocalPreferencesRepository.require(context);
    await store.put(key, value);
    await store.flush();
  }

  /** 写 boolean 并落盘。 */
  static async putBoolean(context: Context, key: string, value: boolean): Promise<void> {
    const store = await LocalPreferencesRepository.require(context);
    await store.put(key, value);
    await store.flush();
  }

  /** 批量写多个 int 键，只 flush 一次（探索页「布局模式 + 列数」同批写入）。 */
  static async putInts(context: Context, values: Map<string, number>): Promise<void> {
    const store = await LocalPreferencesRepository.require(context);
    values.forEach((value: number, key: string) => {
      store.putSync(key, value);
    });
    await store.flush();
  }

  private static async require(context: Context): Promise<preferences.Preferences> {
    await LocalPreferencesRepository.load(context);
    const store = LocalPreferencesRepository.current();
    if (store === undefined) {
      throw new Error('LocalPreferencesRepository 未初始化');
    }
    return store;
  }
}
