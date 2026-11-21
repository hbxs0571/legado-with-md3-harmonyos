/**
 * M3 派生色位公共入口（批 4，移植自 material-color-utilities，Apache-2.0）。
 *
 * 上游 legado-with-MD3 用 com.materialkolor:material-kolor 5.0.1，
 * 其算法源自 Google material-color-utilities；此目录是后者 TypeScript 实现的逐字移植，
 * 数值已经过黄金样本集逐位验证（见 entry/src/main/ets/reader/m3/verify_ets.ts）。
 *
 * 只暴露阅读器需要的两件事：
 *   1. determineDark(seedHex, appIsDark) —— deriveDarkFromColor=false 时明暗取应用主题
 *   2. resolveDynamicColor(seedHex, isDark, paletteStyle, slot) —— seed 派生指定色位
 */
import {Hct} from './hct/hct.ets';
import {SchemeTonalSpot} from './scheme/scheme_tonal_spot.ets';
import {SchemeNeutral} from './scheme/scheme_neutral.ets';
import {SchemeVibrant} from './scheme/scheme_vibrant.ets';
import {SchemeExpressive} from './scheme/scheme_expressive.ets';
import {SchemeRainbow} from './scheme/scheme_rainbow.ets';
import {SchemeFruitSalad} from './scheme/scheme_fruit_salad.ets';
import {SchemeMonochrome} from './scheme/scheme_monochrome.ets';
import {SchemeFidelity} from './scheme/scheme_fidelity.ets';
import {SchemeContent} from './scheme/scheme_content.ets';
import {DynamicScheme} from './dynamiccolor/dynamic_scheme.ets';
import {DynamicColor} from './dynamiccolor/dynamic_color.ets';
import {MaterialDynamicColors} from './dynamiccolor/material_dynamic_colors.ets';
import {Variant} from './dynamiccolor/variant.ets';

/** 与上游 ThemeResolver.kt:33-41 的 materialPaletteStyles 键一致。 */
export type M3PaletteStyle =
  'tonalSpot' | 'neutral' | 'vibrant' | 'expressive' | 'rainbow' |
  'fruitSalad' | 'monochrome' | 'fidelity' | 'content';

/** 菜单链需要的色位（上游 ReadBookColorTheme.kt 覆盖名单 + 菜单底色）。 */
export type M3ColorSlot =
  'background' | 'surface' | 'surfaceDim' | 'surfaceBright' |
  'surfaceContainerLowest' | 'surfaceContainerLow' | 'surfaceContainer' |
  'surfaceContainerHigh' | 'surfaceContainerHighest' |
  'primary' | 'onPrimary' | 'primaryContainer' | 'onPrimaryContainer' |
  'secondary' | 'onSecondary' | 'secondaryContainer' | 'onSecondaryContainer' |
  'tertiary' | 'onTertiary' | 'tertiaryContainer' | 'onTertiaryContainer' |
  'error' | 'onError' | 'errorContainer' | 'onErrorContainer';

const DEFAULT_CONTRAST: number = 0.0;

/**
 * 把持久化的样式字符串规范化为 M3PaletteStyle。
 * 对齐上游 `ThemeResolver.resolvePaletteStyle`（`ThemeResolver.kt:67-69`）：
 * 未知 / 空串一律回落 TonalSpot。
 */
export function normalizePaletteStyle(value: string): M3PaletteStyle {
  switch (value) {
    case 'neutral': return 'neutral';
    case 'vibrant': return 'vibrant';
    case 'expressive': return 'expressive';
    case 'rainbow': return 'rainbow';
    case 'fruitSalad': return 'fruitSalad';
    case 'monochrome': return 'monochrome';
    case 'fidelity': return 'fidelity';
    case 'content': return 'content';
    default: return 'tonalSpot';
  }
}

/** 解析 #RRGGBB / #AARRGGBB 为 argb；解析失败返回 fallback。 */
export function argbFromHex(hex: string, fallback: number): number {
  const s: string = hex.trim().replace('#', '');
  if (s.length !== 6 && s.length !== 8) { return fallback; }
  const v: number = parseInt(s, 16);
  if (isNaN(v)) { return fallback; }
  return s.length === 6 ? (0xFF000000 | v) >>> 0 : v >>> 0;
}

/** argb → 不带 alpha 的 #RRGGBB（菜单绘制只需 RGB）。 */
export function hexRgbFromArgb(argb: number): string {
  return '#' + (argb & 0x00FFFFFF).toString(16).padStart(6, '0').toUpperCase();
}

/** 由 paletteStyle 构造对应 scheme。未知名回落 tonalSpot（与上游 ThemeResolver.kt:68 一致）。 */
function makeScheme(seed: Hct, isDark: boolean, style: M3PaletteStyle): DynamicScheme {
  switch (style) {
    case 'neutral': return new SchemeNeutral(seed, isDark, DEFAULT_CONTRAST);
    case 'vibrant': return new SchemeVibrant(seed, isDark, DEFAULT_CONTRAST);
    case 'expressive': return new SchemeExpressive(seed, isDark, DEFAULT_CONTRAST);
    case 'rainbow': return new SchemeRainbow(seed, isDark, DEFAULT_CONTRAST);
    case 'fruitSalad': return new SchemeFruitSalad(seed, isDark, DEFAULT_CONTRAST);
    case 'monochrome': return new SchemeMonochrome(seed, isDark, DEFAULT_CONTRAST);
    case 'fidelity': return new SchemeFidelity(seed, isDark, DEFAULT_CONTRAST);
    case 'content': return new SchemeContent(seed, isDark, DEFAULT_CONTRAST);
    case 'tonalSpot':
    default: return new SchemeTonalSpot(seed, isDark, DEFAULT_CONTRAST);
  }
}

/**
 * 由种子色派生指定色位的 RGB 十六进制。
 * isDark 由调用方按应用主题给出（上游 deriveDarkFromColor=false，明暗不跟纸色）。
 */
export function resolveDynamicColor(seedHex: string, isDark: boolean,
  style: M3PaletteStyle, slot: M3ColorSlot): string {
  const seed: number = argbFromHex(seedHex, 0xFF000000);
  const scheme: DynamicScheme = makeScheme(Hct.fromInt(seed), isDark, style);
  const dynamicColor = colorSlot(slot);
  if (!dynamicColor) { return seedHex; }
  return hexRgbFromArgb(dynamicColor.getArgb(scheme) >>> 0);
}

/** ArkTS 禁止以变量索引类字段，用显式 switch 映射色位。 */
function colorSlot(slot: M3ColorSlot): DynamicColor | undefined {
  const c = MaterialDynamicColors;
  switch (slot) {
    case 'background': return c.background;
    case 'surface': return c.surface;
    case 'surfaceDim': return c.surfaceDim;
    case 'surfaceBright': return c.surfaceBright;
    case 'surfaceContainerLowest': return c.surfaceContainerLowest;
    case 'surfaceContainerLow': return c.surfaceContainerLow;
    case 'surfaceContainer': return c.surfaceContainer;
    case 'surfaceContainerHigh': return c.surfaceContainerHigh;
    case 'surfaceContainerHighest': return c.surfaceContainerHighest;
    case 'primary': return c.primary;
    case 'onPrimary': return c.onPrimary;
    case 'primaryContainer': return c.primaryContainer;
    case 'onPrimaryContainer': return c.onPrimaryContainer;
    case 'secondary': return c.secondary;
    case 'onSecondary': return c.onSecondary;
    case 'secondaryContainer': return c.secondaryContainer;
    case 'onSecondaryContainer': return c.onSecondaryContainer;
    case 'tertiary': return c.tertiary;
    case 'onTertiary': return c.onTertiary;
    case 'tertiaryContainer': return c.tertiaryContainer;
    case 'onTertiaryContainer': return c.onTertiaryContainer;
    case 'error': return c.error;
    case 'onError': return c.onError;
    case 'errorContainer': return c.errorContainer;
    case 'onErrorContainer': return c.onErrorContainer;
    default: return undefined;
  }
}

/** 一次性派生多个色位，避免同一 seed 重复构造 scheme。 */
export function resolveDynamicColors(seedHex: string, isDark: boolean,
  style: M3PaletteStyle, slots: M3ColorSlot[]): Record<string, string> {
  const seed: number = argbFromHex(seedHex, 0xFF000000);
  const scheme: DynamicScheme = makeScheme(Hct.fromInt(seed), isDark, style);
  const out: Record<string, string> = {};
  for (const slot of slots) {
    const dynamicColor = colorSlot(slot);
    if (dynamicColor) { out[slot] = hexRgbFromArgb(dynamicColor.getArgb(scheme) >>> 0); }
  }
  return out;
}

/** 暴露 variant 值供调用方判断（当前菜单链只用 tonalSpot；9 个 style 均已实现派生）。 */
export function variantOf(style: M3PaletteStyle): Variant {
  switch (style) {
    case 'neutral': return Variant.NEUTRAL;
    case 'vibrant': return Variant.VIBRANT;
    case 'expressive': return Variant.EXPRESSIVE;
    case 'rainbow': return Variant.RAINBOW;
    case 'fruitSalad': return Variant.FRUIT_SALAD;
    case 'monochrome': return Variant.MONOCHROME;
    case 'fidelity': return Variant.FIDELITY;
    case 'content': return Variant.CONTENT;
    default: return Variant.TONAL_SPOT;
  }
}
