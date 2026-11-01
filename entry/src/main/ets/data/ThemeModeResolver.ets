import { ConfigurationConstant } from '@kit.AbilityKit';
import { resourceManager } from '@kit.LocalizationKit';
import { THEME_MODE_DARK, THEME_MODE_LIGHT } from '../data/ThemeSettingsRepository';

/**
 * 深浅色主题的唯一派生点。
 *
 * 对齐上游 `domain/model/settings/AppUiConfiguration.kt:11-15`：
 *
 * ```
 * isDarkTheme = when (themeMode) {
 *   "1" -> false            // 亮色
 *   "2" -> true             // 暗色
 *   else -> isSystemDarkTheme
 * }
 * ```
 *
 * 与上游的差异（平台机制不同，不照抄）：
 * 上游 `help/config/ThemeConfigStore.kt:70-89 initNightMode()` 把三值映射成
 * `AppCompatDelegate.setDefaultNightMode(MODE_NIGHT_*)`，由 Android 框架换整套资源。
 * ArkUI 没有 `AppCompatDelegate`，对应能力是 `ApplicationContext.setColorMode()`：
 * 它让系统按 `resources/dark` 限定目录重新解析资源，配合本类的派生值即可达到同样效果。
 */
export class ThemeModeResolver {
  /**
   * 系统当前是否深色。
   *
   * `context.resourceManager.getConfigurationSync()` 返回的是 `resourceManager.Configuration`，
   * 它的 `colorMode` 属于 `resourceManager.ColorMode`（DARK=0 / LIGHT=1），与
   * `ConfigurationConstant.ColorMode` 是两个互不相通的枚举，不能混比。
   */
  static isSystemDark(context: Context): boolean {
    try {
      const configuration = context.resourceManager.getConfigurationSync();
      return configuration.colorMode === resourceManager.ColorMode.DARK;
    } catch (_) {
      return false;
    }
  }

  /** 直接读一个 context 当前的深色状态，供启动时与配置变更回调共用。 */
  static currentDark(context: Context): boolean {
    return ThemeModeResolver.isSystemDark(context);
  }

  /**
   * 三值 + 系统色模式 → 是否深色。
   *
   * @param themeMode 上游口径的三值字符串 `"0"`/`"1"`/`"2"`
   * @param systemDark 系统当前是否深色，仅当 `themeMode` 为 `"0"` 时参与判定
   */
  static isDarkTheme(themeMode: string, systemDark: boolean): boolean {
    if (themeMode === THEME_MODE_LIGHT) { return false; }
    if (themeMode === THEME_MODE_DARK) { return true; }
    return systemDark;
  }

  /**
   * 三值 → `ConfigurationConstant.ColorMode`，供 `setColorMode` 使用。
   *
   * `"0"` 跟随系统时必须传 `COLOR_MODE_NOT_SET`，否则应用会盖住系统设置，
   * 「跟随系统」这一支就失效了。
   */
  static toColorMode(themeMode: string): ConfigurationConstant.ColorMode {
    if (themeMode === THEME_MODE_LIGHT) { return ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT; }
    if (themeMode === THEME_MODE_DARK) { return ConfigurationConstant.ColorMode.COLOR_MODE_DARK; }
    return ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET;
  }

  /**
   * 把三值应用到系统色模式，让 `resources/dark` 生效。
   *
   * 与上游 `ThemeConfigStore.initNightMode()` 的差别：上游在应用启动早期就能调
   * `setDefaultNightMode`，这里受 SDK 限制必须等窗口创建且页面 loadContent 之后，
   * 所以启动路径在 `EntryAbility` 里、切换路径在这里。
   */
  static apply(context: Context, themeMode: string): void {
    try {
      context.getApplicationContext().setColorMode(ThemeModeResolver.toColorMode(themeMode));
    } catch (_) {
    }
  }
}
