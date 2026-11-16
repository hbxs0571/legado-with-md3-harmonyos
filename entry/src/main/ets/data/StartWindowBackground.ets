import { window, ColorMetrics } from '@kit.ArkUI';

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
