import { preferences } from '@kit.ArkData';

/**
 * 主题模式取值域。
 *
 * 上游 `themeMode` 是字符串三值（`domain/model/settings/AppShellSettings.kt:4` 默认 `"0"`）：
 * `"0"` 跟随系统 / `"1"` 亮色 / `"2"` 暗色。本地 `OnboardingRepository` 原先存的是 number
 * 0/1/2，接全局前在这里统一成字符串，避免留两套取值域。
 */
export const THEME_MODE_FOLLOW_SYSTEM: string = '0';
export const THEME_MODE_LIGHT: string = '1';
export const THEME_MODE_DARK: string = '2';

/** 主题模式快照。 */
export interface ThemeSnapshot {
  /** 三值字符串 `"0"`/`"1"`/`"2"`，对齐上游 `AppShellSettings.themeMode`。 */
  themeMode: string;
  /** 调色板序号 0..4，对齐本地 `ThemeSettingsPage` 的五个 `ThemePaletteItem`。 */
  paletteIndex: number;
}

/**
 * 主题设置仓库。
 *
 * 只做「themeMode + paletteIndex 的落盘与读回」两件事，不持有任何界面状态——
 * 全局状态在 `pages/Index.ets`，夜间模式的实际应用在 `entryability/EntryAbility.ets`。
 *
 * 存储键与上游 `constant/PreferKey.kt:9 const val themeMode = "themeMode"` 同名。
 */
export class ThemeSettingsRepository {
  private static readonly preferenceName: string = 'legado_theme';

  private static normalizeThemeMode(value: string): string {
    if (value === THEME_MODE_LIGHT || value === THEME_MODE_DARK) { return value; }
    return THEME_MODE_FOLLOW_SYSTEM;
  }

  static async load(context: Context): Promise<ThemeSnapshot> {
    const defaults: ThemeSnapshot = { themeMode: THEME_MODE_FOLLOW_SYSTEM, paletteIndex: 0 };
    try {
      const store = await preferences.getPreferences(context, ThemeSettingsRepository.preferenceName);
      const themeMode = await store.get('themeMode', defaults.themeMode);
      const paletteIndex = await store.get('paletteIndex', defaults.paletteIndex);
      return {
        themeMode: typeof themeMode === 'string' ? ThemeSettingsRepository.normalizeThemeMode(themeMode) : defaults.themeMode,
        paletteIndex: typeof paletteIndex === 'number' ? Math.max(0, Math.min(4, paletteIndex)) : defaults.paletteIndex
      };
    } catch (_) {
      return defaults;
    }
  }

  /**
   * 是否已经显式选过主题。
   *
   * 首次启动时没有这条记录，`restoreOnboarding` 需要据此决定「用向导里选的值」还是「用已存的全局值」，
   * 否则每次冷启动都会把用户在主题设置页改过的值冲回向导里的旧值。
   */
  static async hasStoredThemeMode(context: Context): Promise<boolean> {
    try {
      const store = await preferences.getPreferences(context, ThemeSettingsRepository.preferenceName);
      return await store.has('themeMode');
    } catch (_) {
      return false;
    }
  }

  static async save(context: Context, themeMode: string, paletteIndex: number): Promise<void> {
    const store = await preferences.getPreferences(context, ThemeSettingsRepository.preferenceName);
    await store.put('themeMode', ThemeSettingsRepository.normalizeThemeMode(themeMode));
    await store.put('paletteIndex', Math.max(0, Math.min(4, paletteIndex)));
    await store.flush();
  }

  /** number 0/1/2（向导与主题页用的形态）转成上游的字符串三值。 */
  static fromModeNumber(value: number): string {
    if (value === 1) { return THEME_MODE_LIGHT; }
    if (value === 2) { return THEME_MODE_DARK; }
    return THEME_MODE_FOLLOW_SYSTEM;
  }

  /** 字符串三值转回 number 0/1/2，供仍是数字口径的界面使用。 */
  static toModeNumber(value: string): number {
    if (value === THEME_MODE_LIGHT) { return 1; }
    if (value === THEME_MODE_DARK) { return 2; }
    return 0;
  }
}
