/**
 * 设置卡片外观的运行时解析。
 *
 * 上游把这组配置放在 `ThemeSettings`（`domain/model/settings/ThemeSettings.kt:24-31`）里，
 * 由 `ui/widget/components/card/GlassCard.kt:77-100` 与
 * `ui/widget/components/SplicedColumnGroup.kt:49-70` 消费：
 *
 * - `containerOpacity`（0..100，默认 100）→ 容器底色 alpha（`GlassCard.kt:155`）
 * - `disableSplicedColumnGroupCornerRadius`（默认 false）→ 分组圆角直接压 0
 * - `overrideBaseCardCornerRadius` + `baseCardCornerRadius`（0..40，默认 16）→ 覆盖卡片圆角
 * - `overrideBaseCardBorder` + `baseCardBorderWidth`（0..5，默认 1）+ 日/夜边框色 → 覆盖卡片边框
 *
 * 本地 24 处设置分组卡片都是「`theme_surface_secondary` 底 + 圆角 16」的同一种写法，
 * 所以这里把四个值解析成组件能直接用的原始类型（数字/颜色串），由 `pages/Index.ets`
 * 写进 `AppStorage`，各卡片组件用 `@StorageProp` 读——避免把八个字段逐层透传进二十多个 struct。
 */
export interface ThemeCardStyleSnapshot {
  /** 容器底色不透明度 0..100，默认 100。对齐上游 `containerOpacity`。 */
  containerOpacity: number;
  /** 关闭设置分组圆角。对齐上游 `disableSplicedColumnGroupCornerRadius`。 */
  disableSplicedColumnGroupCornerRadius: boolean;
  /** 覆盖卡片圆角总开关。对齐上游 `overrideBaseCardCornerRadius`。 */
  overrideBaseCardCornerRadius: boolean;
  /** 卡片圆角数值 0..40，默认 16。对齐上游 `baseCardCornerRadius`。 */
  baseCardCornerRadius: number;
  /** 覆盖卡片边框总开关。对齐上游 `overrideBaseCardBorder`。 */
  overrideBaseCardBorder: boolean;
  /** 边框宽度 0..5，默认 1。对齐上游 `baseCardBorderWidth`。 */
  baseCardBorderWidth: number;
  /** 日间边框色，空串表示用默认描边色。对齐上游 `baseCardBorderColor`（上游 0 = 未设置）。 */
  baseCardBorderColorDay: string;
  /** 夜间边框色，空串表示用默认描边色。对齐上游 `baseCardBorderColorNight`。 */
  baseCardBorderColorNight: string;
  /** 显示分隔线。对齐上游 `ThemeSettings.kt:63 enableItemDivider`（默认 false）。 */
  enableItemDivider: boolean;
  /** 分隔线宽度 0..5，默认 1。对齐上游 `ThemeSettings.kt:64 itemDividerWidth`。 */
  itemDividerWidth: number;
  /** 分隔线长度 30..100（百分比），默认 80。对齐上游 `ThemeSettings.kt:65 itemDividerLength`。 */
  itemDividerLength: number;
  /** 分隔线颜色，空串表示未设置。对齐上游 `ThemeSettings.kt:66 itemDividerColor`（上游 0 = 未设置）。 */
  itemDividerColor: string;
}

/** 分组卡片的默认圆角，与本地现有 24 处 `borderRadius(16)` 一致。 */
export const CARD_RADIUS_DEFAULT: number = 16;
/** 卡片圆角上限，对齐上游 `ThemeConfigScreen.kt:617` 滑块的 0..40。 */
export const CARD_RADIUS_MIN: number = 0;
export const CARD_RADIUS_MAX: number = 40;
/** 边框宽度区间，对齐上游 `ThemeConfigScreen.kt:640` 滑块的 0..5。 */
export const CARD_BORDER_WIDTH_MIN: number = 0;
export const CARD_BORDER_WIDTH_MAX: number = 5;
export const CARD_BORDER_WIDTH_DEFAULT: number = 1;
/** 容器不透明度区间，对齐上游 `ThemeConfigScreen.kt:585` 滑块的 0..100。 */
export const CONTAINER_OPACITY_MIN: number = 0;
export const CONTAINER_OPACITY_MAX: number = 100;
export const CONTAINER_OPACITY_DEFAULT: number = 100;
/** 分隔线宽度区间，对齐上游 `ThemeConfigScreen.kt:684` 滑块的 0..5。 */
export const DIVIDER_WIDTH_MIN: number = 0;
export const DIVIDER_WIDTH_MAX: number = 5;
export const DIVIDER_WIDTH_DEFAULT: number = 1;
/** 分隔线长度区间（百分比），对齐上游 `ThemeConfigScreen.kt:696` 滑块的 30..100。 */
export const DIVIDER_LENGTH_MIN: number = 30;
export const DIVIDER_LENGTH_MAX: number = 100;
export const DIVIDER_LENGTH_DEFAULT: number = 80;
/** 未设置分隔线颜色时的兜底色，对齐上游 `SettingItemDivider.kt:29` 的 `Color.Gray.copy(alpha = 0.3f)`。 */
export const DIVIDER_COLOR_FALLBACK: string = '#4D808080';

/** 卡片底色在浅色/深色下的基色，取 `base|dark/element/color.json` 的 `theme_surface_secondary`。 */
const SURFACE_SECONDARY_LIGHT: string = '#FFFFFF';
const SURFACE_SECONDARY_DARK: string = '#1A1B21';
/** 未配置边框色时的兜底描边色，取 `theme_text_tertiary`（近似上游 `outlineVariant`）。 */
const BORDER_FALLBACK_LIGHT: string = '#6A6D77';
const BORDER_FALLBACK_DARK: string = '#92949E';

function clampInt(value: number, min: number, max: number, fallback: number): number {
  if (!Number.isFinite(value)) { return fallback; }
  const rounded = Math.round(value);
  if (rounded < min) { return min; }
  if (rounded > max) { return max; }
  return rounded;
}

/** 容器不透明度归一，非法值回落 100。 */
export function normalizeContainerOpacity(value: number): number {
  return clampInt(value, CONTAINER_OPACITY_MIN, CONTAINER_OPACITY_MAX, CONTAINER_OPACITY_DEFAULT);
}

/** 卡片圆角归一，非法值回落 16。 */
export function normalizeCardCornerRadius(value: number): number {
  return clampInt(value, CARD_RADIUS_MIN, CARD_RADIUS_MAX, CARD_RADIUS_DEFAULT);
}

/** 边框宽度归一，非法值回落 1。 */
export function normalizeCardBorderWidth(value: number): number {
  return clampInt(value, CARD_BORDER_WIDTH_MIN, CARD_BORDER_WIDTH_MAX, CARD_BORDER_WIDTH_DEFAULT);
}

/** 分隔线宽度归一，非法值回落 1。 */
export function normalizeDividerWidth(value: number): number {
  return clampInt(value, DIVIDER_WIDTH_MIN, DIVIDER_WIDTH_MAX, DIVIDER_WIDTH_DEFAULT);
}

/** 分隔线长度归一，非法值回落 80。 */
export function normalizeDividerLength(value: number): number {
  return clampInt(value, DIVIDER_LENGTH_MIN, DIVIDER_LENGTH_MAX, DIVIDER_LENGTH_DEFAULT);
}

/**
 * 解析出实际生效的分隔线宽度；0 表示不画。
 *
 * 上游 `SettingItemDivider.kt:22-23` 在 `enableItemDivider` 为假时整条不渲染，
 * 所以这里把「开关关掉」也折算成宽度 0，组件只需判一个数。
 */
export function resolveDividerWidth(snapshot: ThemeCardStyleSnapshot): number {
  if (!snapshot.enableItemDivider) { return 0; }
  return normalizeDividerWidth(snapshot.itemDividerWidth);
}

/** 解析出分隔线长度（百分比）。对齐上游 `SettingItemDivider.kt:26`。 */
export function resolveDividerLength(snapshot: ThemeCardStyleSnapshot): number {
  return normalizeDividerLength(snapshot.itemDividerLength);
}

/** 解析出分隔线颜色；未设置时回落半透明灰。对齐上游 `SettingItemDivider.kt:27-31`。 */
export function resolveDividerColor(snapshot: ThemeCardStyleSnapshot): string {
  if (snapshot.itemDividerColor.length > 0) { return snapshot.itemDividerColor; }
  return DIVIDER_COLOR_FALLBACK;
}

/**
 * 解析出实际生效的圆角。
 *
 * 顺序与上游 `SplicedColumnGroup.kt:49-53` 一致：先看「关闭分组圆角」，再看「覆盖卡片圆角」，
 * 都不满足才是默认 16。
 */
export function resolveCardCornerRadius(snapshot: ThemeCardStyleSnapshot): number {
  if (snapshot.disableSplicedColumnGroupCornerRadius) { return 0; }
  if (snapshot.overrideBaseCardCornerRadius) { return normalizeCardCornerRadius(snapshot.baseCardCornerRadius); }
  return CARD_RADIUS_DEFAULT;
}

/** 解析出实际生效的边框宽度；0 表示不画边框。对齐上游 `GlassCard.kt:83-96`。 */
export function resolveCardBorderWidth(snapshot: ThemeCardStyleSnapshot): number {
  if (!snapshot.overrideBaseCardBorder) { return 0; }
  return normalizeCardBorderWidth(snapshot.baseCardBorderWidth);
}

/**
 * 解析出实际生效的边框色。
 *
 * 上游 `GlassCard.kt:84-86` 按日夜选 `baseCardBorderColor` / `baseCardBorderColorNight`，
 * 值为 0（未设置）时回落到 `colorScheme.outlineVariant`。
 */
export function resolveCardBorderColor(snapshot: ThemeCardStyleSnapshot, isDark: boolean): string {
  const configured = isDark ? snapshot.baseCardBorderColorNight : snapshot.baseCardBorderColorDay;
  if (configured.length > 0) { return configured; }
  return isDark ? BORDER_FALLBACK_DARK : BORDER_FALLBACK_LIGHT;
}

/**
 * 解析出卡片底色（带 alpha 的 ARGB 串）；返回空串表示「用 `theme_surface_secondary` 资源」。
 *
 * 上游 `GlassCard.kt:75-76` 与 `:155` 是把 `containerOpacity / 100f` 乘到容器色的 alpha 上，
 * 只影响底色、不影响文字——所以这里返回带 alpha 的颜色，而不是给整块加 `.opacity()`。
 *
 * 100% 时故意返回空串：让组件继续用 `$r('app.color.theme_surface_secondary')`，
 * 深浅色切换仍由 `base|dark` 两套资源目录负责，不把颜色值复制进代码。
 */
export function resolveCardBackgroundColor(snapshot: ThemeCardStyleSnapshot, isDark: boolean): string {
  const opacity = normalizeContainerOpacity(snapshot.containerOpacity);
  if (opacity >= CONTAINER_OPACITY_MAX) { return ''; }
  const base = isDark ? SURFACE_SECONDARY_DARK : SURFACE_SECONDARY_LIGHT;
  const alpha = Math.round(255 * opacity / 100);
  const hex = alpha.toString(16).toUpperCase().padStart(2, '0');
  return `#${hex}${base.substring(1)}`;
}
