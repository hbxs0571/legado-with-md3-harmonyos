import { window, ColorMetrics } from '@kit.ArkUI';
import { preferences } from '@kit.ArkData';
import { ThemeModeResolver } from './ThemeModeResolver';
import { publishPaletteColors, resolvePaletteColors } from './ThemePalette';
import { THEME_MODE_FOLLOW_SYSTEM } from './ThemeSettingsRepository';

/**
 * 启动窗口（闪屏）底色：跟随主题。
 *
 * 上游 `app/src/main/res/values/themes.xml:18-21` 的 `Theme.App.Starting` 把
 * `windowSplashScreenBackground` 指向 `?attr/colorSurface`，那是 DayNight 资源，
 * 深色主题下自动取深色值。
 *
 * 本地 `entry/src/main/module.json5` 的 `startWindowBackground` 指向
 * `$color:start_window_background`。`base/element/color.json`（#F6F4F0）与
 * `dark/element/color.json`（#111217）两份资源都在，但启动窗口在应用主题生效前
 * 就画完了，系统只会用 `base/` 那份 —— 深色主题冷启动必然先白闪一下。
 *
 * `window.setStartWindowBackgroundColor`（API 20 起）允许运行时改这个底色，
 * 所以按当前主题显式设一次。任何失败都吞掉：这一句绝不能让应用起不来。
 */
const START_WINDOW_LIGHT: number = 0xFFF6F4F0;
const START_WINDOW_DARK: number = 0xFF111217;

/** 按深浅色设置启动窗口底色。moduleName / abilityName 与 module.json5 里的一致。 */
export function applyStartWindowBackgroundColor(isDark: boolean): void {
  try {
    const color = ColorMetrics.numeric(isDark ? START_WINDOW_DARK : START_WINDOW_LIGHT);
    window.setStartWindowBackgroundColor('entry', 'EntryAbility', color).catch(() => {});
  } catch (_) {
  }
}

/** 主题偏好文件名，与 `ThemeSettingsRepository.preferenceName` 一致。 */
const THEME_PREFERENCE_NAME: string = 'legado_theme';

/**
 * 首帧之前把主题色同步灌进 AppStorage。
 *
 * 为什么要有这一步：`Index` 的一套 `@StorageProp('themeColorSurfacePrimary')` 等默认值是**浅色**，
 * 真值要等 `restoreOnboarding` 里一串 `await` 走完、`applyThemeMode` → `applyThemeColors`
 * 才广播进来。深色主题下首帧就拿默认浅色画一遍 —— 用户说的「概率性白闪」就是这一帧。
 *
 * `ThemeSettingsRepository.load` 是异步的，赶不上首帧；这里改用它底下同一份偏好的**同步** API
 * （`preferences.getPreferencesSync` / `Preferences.getSync`，均 @since 10，基线 20 够用）。
 *
 * 必须在 `EntryAbility.onCreate` 里调：那里早于窗口创建、早于 `loadContent`、早于 Index 的
 * `aboutToAppear`，是唯一能赶在首帧之前的位置。
 *
 * 任何失败都吞掉：宁可退回 `@StorageProp` 的默认值，也不能让应用起不来。
 * 自定义配色（paletteIndex 12 的 6 个手选色）这里不读——它只影响进应用之后的观感，
 * 首帧闪一下可接受，读它反而要把 customTheme 的整条解析链拉进启动路径。
 */
export function preloadInitialThemeColors(context: Context): void {
  try {
    const store = preferences.getPreferencesSync(context, { name: THEME_PREFERENCE_NAME });
    const themeMode = store.getSync('themeMode', THEME_MODE_FOLLOW_SYSTEM) as string;
    const paletteIndex = store.getSync('paletteIndex', 0) as number;
    const isDark = ThemeModeResolver.isDarkTheme(themeMode, ThemeModeResolver.isSystemDark(context));
    publishPaletteColors(resolvePaletteColors(paletteIndex, isDark));
    // 顺带把「下一次」闪屏的底色也对齐（批 1 的既有能力），避免启动后又被异步那条覆盖成别的值。
    applyStartWindowBackgroundColor(isDark);
  } catch (_) {
  }
}
