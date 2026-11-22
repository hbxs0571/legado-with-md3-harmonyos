/**
 * 顶栏与底栏设置。
 *
 * 对齐上游 `ui/config/themeConfig/TopBottomBarSettingsSheet.kt` 的 15 个键
 * （`ThemeSettings.kt:35-46` + `AppShellSettings.kt` 的三个 showBottomView/useFloatingBottomBar/
 * useFloatingBottomBarLiquidGlass），以及它引用的 `GlassDefaults.glassColor()`：
 * 未开模糊时直接用底色，开了模糊才把底色压到 `blurAlpha`。
 */

import { resolveGlassBarColor } from './GlassColor';

/** 顶栏按钮样式取值，对齐上游 `res/values/array_values.xml` 的 `top_bar_button_style_value`。 */
export const TOP_BAR_BUTTON_STYLES: string[] = ['plain', 'tonal', 'outlined', 'glass', 'liquid'];

export const TOP_BAR_BUTTON_STYLE_DEFAULT = 'tonal';

/** 中文标签，逐条对齐上游 `values-zh-rCN/arrays.xml:226-232` 的 `top_bar_button_style`。 */
export function topBarButtonStyleLabel(value: string): string {
  if (value === 'plain') { return '普通'; }
  if (value === 'outlined') { return '描边'; }
  if (value === 'glass') { return '半透明'; }
  if (value === 'liquid') { return '液态玻璃'; }
  return '填充';
}

export function normalizeTopBarButtonStyle(value: string): string {
  return TOP_BAR_BUTTON_STYLES.includes(value) ? value : TOP_BAR_BUTTON_STYLE_DEFAULT;
}

export const TOP_BAR_OPACITY_MIN = 0;
export const TOP_BAR_OPACITY_MAX = 100;
export const TOP_BAR_OPACITY_DEFAULT = 100;
export const BOTTOM_BAR_OPACITY_DEFAULT = 100;

export const TOP_BAR_BLUR_RADIUS_MIN = 0;
export const TOP_BAR_BLUR_RADIUS_MAX = 30;
export const TOP_BAR_BLUR_RADIUS_DEFAULT = 24;
export const BOTTOM_BAR_BLUR_RADIUS_MIN = 0;
export const BOTTOM_BAR_BLUR_RADIUS_MAX = 10;
export const BOTTOM_BAR_BLUR_RADIUS_DEFAULT = 8;

export const BAR_BLUR_ALPHA_MIN = 0;
export const BAR_BLUR_ALPHA_MAX = 100;
export const TOP_BAR_BLUR_ALPHA_DEFAULT = 73;
export const BOTTOM_BAR_BLUR_ALPHA_DEFAULT = 40;

export const BOTTOM_BAR_LENS_RADIUS_MIN = 0;
export const BOTTOM_BAR_LENS_RADIUS_MAX = 50;
export const BOTTOM_BAR_LENS_RADIUS_DEFAULT = 24;

/** 顶栏/底栏未开模糊时的底色，与 `theme_surface_elevated` 的日夜值一致。 */
const BAR_BASE_LIGHT = '#FFFFFF';
const BAR_BASE_DARK = '#1C1D23';

export interface TopBottomBarSnapshot {
  enableBlur: boolean;
  enableProgressiveBlur: boolean;
  useFlexibleTopAppBar: boolean;
  topBarButtonStyle: string;
  mergeTopBarActions: boolean;
  showBottomView: boolean;
  useFloatingBottomBar: boolean;
  useFloatingBottomBarLiquidGlass: boolean;
  bottomBarLensRadius: number;
  topBarBlurRadius: number;
  bottomBarBlurRadius: number;
  topBarBlurAlpha: number;
  bottomBarBlurAlpha: number;
  topBarOpacity: number;
  bottomBarOpacity: number;
}

function clampInt(value: number, min: number, max: number, fallback: number): number {
  if (!Number.isFinite(value)) { return fallback; }
  const rounded = Math.round(value);
  if (rounded < min) { return min; }
  if (rounded > max) { return max; }
  return rounded;
}

export function normalizeTopBarOpacity(value: number): number {
  return clampInt(value, TOP_BAR_OPACITY_MIN, TOP_BAR_OPACITY_MAX, TOP_BAR_OPACITY_DEFAULT);
}

export function normalizeBottomBarOpacity(value: number): number {
  return clampInt(value, TOP_BAR_OPACITY_MIN, TOP_BAR_OPACITY_MAX, BOTTOM_BAR_OPACITY_DEFAULT);
}

export function normalizeTopBarBlurRadius(value: number): number {
  return clampInt(value, TOP_BAR_BLUR_RADIUS_MIN, TOP_BAR_BLUR_RADIUS_MAX, TOP_BAR_BLUR_RADIUS_DEFAULT);
}

export function normalizeBottomBarBlurRadius(value: number): number {
  return clampInt(value, BOTTOM_BAR_BLUR_RADIUS_MIN, BOTTOM_BAR_BLUR_RADIUS_MAX, BOTTOM_BAR_BLUR_RADIUS_DEFAULT);
}

export function normalizeBarBlurAlpha(value: number, fallback: number): number {
  return clampInt(value, BAR_BLUR_ALPHA_MIN, BAR_BLUR_ALPHA_MAX, fallback);
}

export function normalizeBottomBarLensRadius(value: number): number {
  return clampInt(value, BOTTOM_BAR_LENS_RADIUS_MIN, BOTTOM_BAR_LENS_RADIUS_MAX, BOTTOM_BAR_LENS_RADIUS_DEFAULT);
}

/**
 * 顶栏/底栏底色。
 *
 * 实现已上收到 `data/GlassColor.ets` 的 `resolveGlassBarColor()`（批 6 合并）：
 * 上游这条规则是 `GlassDefaults.glassColor()` 之后再乘一次 opacity，两半必须一起算，
 * 分成两个文件各写一份会漂。这里只保留名字与参数顺序，供既有调用点继续用。
 */
export function resolveBarBackgroundColor(
  baseColor: string,
  opacityPercent: number,
  blurAlphaPercent: number,
  enableBlur: boolean
): string {
  return resolveGlassBarColor(baseColor, opacityPercent, blurAlphaPercent, enableBlur);
}

/** 顶栏底色（顶栏只在设置页出现，底色跟 `theme_surface_primary`）。 */
export function resolveTopBarBackground(snapshot: TopBottomBarSnapshot, isDark: boolean): string {
  return resolveBarBackgroundColor(
    isDark ? '#111217' : '#F5F6F8',
    snapshot.topBarOpacity,
    snapshot.topBarBlurAlpha,
    snapshot.enableBlur);
}

/** 底栏底色（底栏用 `theme_surface_elevated`）。 */
export function resolveBottomBarBackground(snapshot: TopBottomBarSnapshot, isDark: boolean): string {
  return resolveBarBackgroundColor(
    isDark ? BAR_BASE_DARK : BAR_BASE_LIGHT,
    snapshot.bottomBarOpacity,
    snapshot.bottomBarBlurAlpha,
    snapshot.enableBlur);
}

/** 底栏圆角：悬浮胶囊模式用 `bottomBarLensRadius`，否则 0。 */
export function resolveBottomBarCornerRadius(snapshot: TopBottomBarSnapshot): number {
  if (!snapshot.useFloatingBottomBar) { return 0; }
  return normalizeBottomBarLensRadius(snapshot.bottomBarLensRadius);
}
