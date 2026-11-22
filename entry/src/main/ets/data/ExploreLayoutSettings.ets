import { preferences } from '@kit.ArkData';

/**
 * 探索页的展示偏好：布局模式 + 两套网格列数。
 *
 * 上游把这三个键放在通用的 `LocalPreferences`（`data/local/preferences/LocalPreferences.kt:21-23`）：
 *   EXPLORE_LAYOUT_MODE             intPreferencesKey("explore_layout_mode")
 *   EXPLORE_LAYOUT_GRID_PORTRAIT    intPreferencesKey("explore_layout_grid_portrait")
 *   EXPLORE_LAYOUT_GRID_LANDSCAPE   intPreferencesKey("explore_layout_grid_landscape")
 * 本地没有通用 preferences 门面（data/ 下都是按域划分的仓储），所以照 `BookInfoSettings.ets`
 * 那份最简范式单独建一个。
 *
 * 默认值对齐上游 `ExploreShowViewModel.kt:81-87`：
 * `layoutState = 0`（列表）、`gridCount = if (landscape) 7 else 3`。
 */

/** 布局模式：0 = 列表，1 = 网格（上游 `isGridMode = state.layoutState == 1`）。 */
export const EXPLORE_LAYOUT_MODE_LIST: number = 0;
export const EXPLORE_LAYOUT_MODE_GRID: number = 1;

/** 网格列数默认值（上游 `ExploreShowViewModel.kt:81-87`）。 */
export const EXPLORE_GRID_PORTRAIT_DEFAULT: number = 3;
export const EXPLORE_GRID_LANDSCAPE_DEFAULT: number = 7;

/** 列数可调范围：上游 `CompactSliderSettingItem(a11y_grid_columns, 1f..10f, steps = 8)`。 */
export const EXPLORE_GRID_COUNT_MIN: number = 1;
export const EXPLORE_GRID_COUNT_MAX: number = 10;

export interface ExploreLayoutSettings {
  /** 0 列表 / 1 网格。 */
  layoutMode: number;
  /** 竖屏网格列数。 */
  gridPortrait: number;
  /** 横屏网格列数。 */
  gridLandscape: number;
}

export const DEFAULT_EXPLORE_LAYOUT_SETTINGS: ExploreLayoutSettings = {
  layoutMode: EXPLORE_LAYOUT_MODE_LIST,
  gridPortrait: EXPLORE_GRID_PORTRAIT_DEFAULT,
  gridLandscape: EXPLORE_GRID_LANDSCAPE_DEFAULT
};

export class ExploreLayoutSettingsRepository {
  private static readonly preferenceName: string = 'legado_explore_layout';
  private static readonly keyLayoutMode: string = 'explore_layout_mode';
  private static readonly keyGridPortrait: string = 'explore_layout_grid_portrait';
  private static readonly keyGridLandscape: string = 'explore_layout_grid_landscape';
  private static cached: ExploreLayoutSettings = {
    layoutMode: EXPLORE_LAYOUT_MODE_LIST,
    gridPortrait: EXPLORE_GRID_PORTRAIT_DEFAULT,
    gridLandscape: EXPLORE_GRID_LANDSCAPE_DEFAULT
  };

  /** 列数夹在 1..10，对齐上游 `it.toInt().coerceIn(1, 10)`。 */
  static clampGridCount(count: number): number {
    if (!Number.isFinite(count)) { return EXPLORE_GRID_PORTRAIT_DEFAULT; }
    return Math.min(Math.max(Math.round(count), EXPLORE_GRID_COUNT_MIN), EXPLORE_GRID_COUNT_MAX);
  }

  /** 布局模式只认 0/1，其余回落列表。 */
  static clampLayoutMode(mode: number): number {
    return mode === EXPLORE_LAYOUT_MODE_GRID ? EXPLORE_LAYOUT_MODE_GRID : EXPLORE_LAYOUT_MODE_LIST;
  }

  private static publish(settings: ExploreLayoutSettings): void {
    ExploreLayoutSettingsRepository.cached = {
      layoutMode: ExploreLayoutSettingsRepository.clampLayoutMode(settings.layoutMode),
      gridPortrait: ExploreLayoutSettingsRepository.clampGridCount(settings.gridPortrait),
      gridLandscape: ExploreLayoutSettingsRepository.clampGridCount(settings.gridLandscape)
    };
  }

  /** 同步取当前缓存；未 load 过时给默认值。 */
  static get(): ExploreLayoutSettings {
    const snapshot = ExploreLayoutSettingsRepository.cached;
    return {
      layoutMode: snapshot.layoutMode,
      gridPortrait: snapshot.gridPortrait,
      gridLandscape: snapshot.gridLandscape
    };
  }

  /** 按当前朝向取该用的列数。 */
  static gridCountFor(settings: ExploreLayoutSettings, landscape: boolean): number {
    return landscape ? settings.gridLandscape : settings.gridPortrait;
  }

  /** 从偏好读一次并进缓存。 */
  static async load(context: Context): Promise<ExploreLayoutSettings> {
    let layoutMode = DEFAULT_EXPLORE_LAYOUT_SETTINGS.layoutMode;
    let gridPortrait = DEFAULT_EXPLORE_LAYOUT_SETTINGS.gridPortrait;
    let gridLandscape = DEFAULT_EXPLORE_LAYOUT_SETTINGS.gridLandscape;
    try {
      const store = await preferences.getPreferences(context, ExploreLayoutSettingsRepository.preferenceName);
      layoutMode = store.getSync(ExploreLayoutSettingsRepository.keyLayoutMode, layoutMode) as number;
      gridPortrait = store.getSync(ExploreLayoutSettingsRepository.keyGridPortrait, gridPortrait) as number;
      gridLandscape = store.getSync(ExploreLayoutSettingsRepository.keyGridLandscape, gridLandscape) as number;
    } catch (error) {
      console.error(`探索页布局设置读取失败：${error instanceof Error ? error.message : String(error)}`);
    }
    const settings: ExploreLayoutSettings = {
      layoutMode: ExploreLayoutSettingsRepository.clampLayoutMode(layoutMode),
      gridPortrait: ExploreLayoutSettingsRepository.clampGridCount(gridPortrait),
      gridLandscape: ExploreLayoutSettingsRepository.clampGridCount(gridLandscape)
    };
    ExploreLayoutSettingsRepository.publish(settings);
    return settings;
  }

  /** 写布局模式（上游 `toggleLayout`：切一下立刻落盘）。 */
  static async saveLayoutMode(context: Context, mode: number): Promise<void> {
    const next = ExploreLayoutSettingsRepository.get();
    next.layoutMode = ExploreLayoutSettingsRepository.clampLayoutMode(mode);
    await ExploreLayoutSettingsRepository.write(context, next);
  }

  /**
   * 写列数。上游 `saveGridCount`（ExploreShowViewModel.kt:347-360）按当前朝向选 key：
   * 横屏写 landscape、竖屏写 portrait，另一个保持不变。
   */
  static async saveGridCount(context: Context, count: number, landscape: boolean): Promise<void> {
    const next = ExploreLayoutSettingsRepository.get();
    const clamped = ExploreLayoutSettingsRepository.clampGridCount(count);
    if (landscape) {
      next.gridLandscape = clamped;
    } else {
      next.gridPortrait = clamped;
    }
    await ExploreLayoutSettingsRepository.write(context, next);
  }

  private static async write(context: Context, settings: ExploreLayoutSettings): Promise<void> {
    const store = await preferences.getPreferences(context, ExploreLayoutSettingsRepository.preferenceName);
    await store.put(ExploreLayoutSettingsRepository.keyLayoutMode, settings.layoutMode);
    await store.put(ExploreLayoutSettingsRepository.keyGridPortrait, settings.gridPortrait);
    await store.put(ExploreLayoutSettingsRepository.keyGridLandscape, settings.gridLandscape);
    await store.flush();
    ExploreLayoutSettingsRepository.publish(settings);
  }
}
