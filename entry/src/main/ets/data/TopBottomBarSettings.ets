/**
 * 顶栏与底栏设置。
 *
 * 对齐上游 `ui/config/themeConfig/TopBottomBarSettingsSheet.kt` 的 15 个键
 * （`ThemeSettings.kt:35-46` + `AppShellSettings.kt` 的三个 showBottomView/useFloatingBottomBar/
 * useFloatingBottomBarLiquidGlass），以及它引用的 `GlassDefaults.glassColor()`：
 * 未开模糊时直接用底色，开了模糊才把底色压到 `blurAlpha`。
 */

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

function toHex(value: number): string {
  const text = Math.round(value).toString(16).toUpperCase();
  return text.length < 2 ? `0${text}` : text;
}

function parseHex(color: string): number[] {
  const text = color.trim();
  if (text.length === 7) {
    return [parseInt(text.substring(1, 3), 16), parseInt(text.substring(3, 5), 16), parseInt(text.substring(5, 7), 16)];
  }
  if (text.length === 9) {
    return [parseInt(text.substring(3, 5), 16), parseInt(text.substring(5, 7), 16), parseInt(text.substring(7, 9), 16)];
  }
  return [255, 255, 255];
}

/**
 * 顶栏/底栏底色。
 *
 * 对齐上游 `GlassDefaults.glassColor()` + `AppNavigationBar.kt:60`：
 * 未开模糊时用不透明底色，开了模糊先把底色压到 `blurAlpha`，再乘 `opacity`。
 * 返回空串表示保持组件自己的资源色（不透明度 100 且未开模糊）。
 */
export function resolveBarBackgroundColor(
  baseColor: string,
  opacityPercent: number,
  blurAlphaPercent: number,
  enableBlur: boolean
): string {
  const opacity = clampInt(opacityPercent, TOP_BAR_OPACITY_MIN, TOP_BAR_OPACITY_MAX, TOP_BAR_OPACITY_DEFAULT) / 100;
  const blurAlpha = clampInt(blurAlphaPercent, BAR_BLUR_ALPHA_MIN, BAR_BLUR_ALPHA_MAX, 0) / 100;
  const effective = enableBlur ? blurAlpha * opacity : opacity;
  if (effective >= 0.999) { return ''; }
  const channels = parseHex(baseColor);
  const alpha = Math.round(effective * 255);
  return `#${toHex(alpha)}${toHex(channels[0])}${toHex(channels[1])}${toHex(channels[2])}`;
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
