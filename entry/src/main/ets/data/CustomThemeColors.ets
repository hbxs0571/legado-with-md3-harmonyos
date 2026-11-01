import { ThemePaletteColors } from './ThemePalette';

/**
 * 自定义主题配色（上游 `appTheme == "12"` 那一套）。
 *
 * 上游口径：`ui/config/customTheme/CustomThemeScreen.kt`（269 行）是入口页，
 * `ui/config/customTheme/CustomThemeViewModel.kt` 每次改动直接写 `ThemeSettingsGateway`，
 * 最终由 `ui/theme/AppTheme.kt:110-125` 的 `generateColorScheme(userPalette, darkTheme)` 生效。
 *
 * 两种模式（`enableDeepPersonalization`，上游 `PreferKey.kt:255` 默认 false）：
 * ① 关：用种子色生成整套配色（`CustomColorScheme(seed, paletteStyle, colorSpec, customContrast)`）；
 * ② 开：日/夜各 6 个手选颜色（`theme_manage_primary_color` 等 6 个条目）。
 *
 * 本地与上游的两处差异，都写在对应函数注释里：
 * - 种子色模式本地只把种子色落到 `primary`，其余 7 个色位沿用内置默认配色
 *   （ArkUI 没有 materialkolor 的 HCT 算法，`ets/api` 下 `hct|dynamicColor|materialkolor` 零命中）；
 * - `paletteStyle` / `customContrast` / `materialVersion` 三个下拉只落盘不产生渲染差异，
 *   因为它们的消费者同样是被替换掉的 HCT 生成器。
 */

/** 日/夜各 6 个手选颜色。空串表示未设置（上游用 Int 0 表示同一语义）。 */
export interface CustomThemeColorSet {
  /** 主题色，上游 `themeColor` / `themeColorNight`。 */
  primary: string;
  /** 次要主题色，上游 `secondaryThemeColor` / `secondaryThemeColorNight`。 */
  secondary: string;
  /** 主要字体色，上游 `primaryTextColor` / `primaryTextColorNight`。 */
  primaryText: string;
  /** 次要字体色，上游 `secondaryTextColor` / `secondaryTextColorNight`。 */
  secondaryText: string;
  /** 背景色，上游 `themeBackgroundColor` / `themeBackgroundColorNight`。 */
  background: string;
  /** 标签容器色，上游 `labelContainerColor` / `labelContainerColorNight`。 */
  labelContainer: string;
}

/** 自定义主题配色的完整快照，作为 `ThemeSnapshot.customTheme` 存进 `legado_theme`。 */
export interface CustomThemeSnapshot {
  /** 深度个性化开关，上游 `PreferKey.kt:255 enableDeepPersonalization`（默认 false）。 */
  enableDeepPersonalization: boolean;
  /** 色板风格，上游 `paletteStyle`（默认 `tonalSpot`）。 */
  paletteStyle: string;
  /** 对比度，上游 `customContrast`（默认 `Default`）。 */
  customContrast: string;
  /** Material 版本，上游 `materialVersion`（默认 `material3`）。 */
  materialVersion: string;
  /** 日间种子色，上游 `customPrimary`（Int 0 = 未设置）。 */
  seedColorDay: string;
  /** 夜间种子色，上游 `customNightPrimary`。 */
  seedColorNight: string;
  day: CustomThemeColorSet;
  night: CustomThemeColorSet;
}

/** 色板风格取值与中文名，逐条对齐 `res/values-zh-rCN/arrays.xml` 的 `paletteStyle` 与 `array_values.xml:101-111`。 */
export const CUSTOM_PALETTE_STYLES: string[] = [
  'tonalSpot', 'neutral', 'vibrant', 'expressive', 'rainbow',
  'fruitSalad', 'monochrome', 'fidelity', 'content'
];
export const CUSTOM_PALETTE_STYLE_LABELS: string[] = [
  '柔和', '中性', '鲜艳', '表现力', '彩虹', '水果拼盘', '单色', '仿真', '内容取色'
];

/** 对比度取值与中文名，对齐 `customContrast`（默认/较强/最强）与 `array_values.xml:153-157`。 */
export const CUSTOM_CONTRASTS: string[] = ['Default', 'Medium', 'High'];
export const CUSTOM_CONTRAST_LABELS: string[] = ['默认', '较强', '最强'];

/** Material 版本，对齐 `materialVersion` 与 `array_values.xml:113-116`。 */
export const CUSTOM_MATERIAL_VERSIONS: string[] = ['material3', 'material3Expressive'];
export const CUSTOM_MATERIAL_VERSION_LABELS: string[] = [
  'Material 3 (2021)', 'Material 3 Expressive (2025)'
];

/** 六个手选色位的标题，逐条对齐 `values-zh-rCN/strings.xml:1729-1734`。 */
export const CUSTOM_COLOR_SLOT_LABELS: string[] = [
  '主题色', '次要主题色', '主要字体色', '次要字体色', '背景色', '标签容器色'
];

/**
 * 某个色位未设置时的兜底色，逐条对齐上游 `ui/theme/AppTheme.kt:110-121` 里的 6 个默认值。
 * 上游在 `customColors.xxx != 0` 时用用户色、否则用这些硬编码值。
 */
const SLOT_FALLBACK: CustomThemeColorSet = {
  primary: '#6750A4',
  secondary: '#625B71',
  primaryText: '#1C1B1F',
  secondaryText: '#49454F',
  background: '#FEF7FF',
  labelContainer: '#F7F2FA'
};

/**
 * 上游 `generateColorScheme` 里与用户色无关的两个固定色：
 * `outline = Color(0xFF79747E)`、`outlineVariant = Color(0xFFC4C7C5)`，日夜都一样。
 * 本地 8 个色位里 `outline` 对应 `theme_text_tertiary`，所以这里只取前者。
 */
const CUSTOM_OUTLINE: string = '#79747E';

/** 颜色串归一成 `#RRGGBB` / `#AARRGGBB`，其余返回空串（= 未设置）。与 `normalizeThemeColor` 同口径。 */
export function normalizeCustomColor(value: string): string {
  if (value.length === 0) { return ''; }
  const trimmed = value.trim().toUpperCase();
  if (!/^#([0-9A-F]{6}|[0-9A-F]{8})$/.test(trimmed)) { return ''; }
  return trimmed;
}

function emptyColorSet(): CustomThemeColorSet {
  return {
    primary: '', secondary: '', primaryText: '', secondaryText: '', background: '', labelContainer: ''
  };
}

/** 默认快照：深度个性化关、色板柔和、对比度默认、Material 3、颜色全未设置。 */
export function defaultCustomThemeSnapshot(): CustomThemeSnapshot {
  return {
    enableDeepPersonalization: false,
    paletteStyle: 'tonalSpot',
    customContrast: 'Default',
    materialVersion: 'material3',
    seedColorDay: '',
    seedColorNight: '',
    day: emptyColorSet(),
    night: emptyColorSet()
  };
}

/** 快照归一：未知取值一律回落默认，颜色串走 `normalizeCustomColor`。 */
export function normalizeCustomThemeSnapshot(value: CustomThemeSnapshot): CustomThemeSnapshot {
  const normalizeSet = (set: CustomThemeColorSet): CustomThemeColorSet => {
    return {
      primary: normalizeCustomColor(set.primary),
      secondary: normalizeCustomColor(set.secondary),
      primaryText: normalizeCustomColor(set.primaryText),
      secondaryText: normalizeCustomColor(set.secondaryText),
      background: normalizeCustomColor(set.background),
      labelContainer: normalizeCustomColor(set.labelContainer)
    };
  };
  return {
    enableDeepPersonalization: value.enableDeepPersonalization,
    paletteStyle: CUSTOM_PALETTE_STYLES.includes(value.paletteStyle) ? value.paletteStyle : 'tonalSpot',
    customContrast: CUSTOM_CONTRASTS.includes(value.customContrast) ? value.customContrast : 'Default',
    materialVersion: CUSTOM_MATERIAL_VERSIONS.includes(value.materialVersion)
      ? value.materialVersion : 'material3',
    seedColorDay: normalizeCustomColor(value.seedColorDay),
    seedColorNight: normalizeCustomColor(value.seedColorNight),
    day: normalizeSet(value.day),
    night: normalizeSet(value.night)
  };
}

/** 按日夜取一套手选颜色；夜间未设的色位回落到日间，对齐上游 `ThemeSettings.customColors(isDark)`。 */
export function resolveCustomColorSet(snapshot: CustomThemeSnapshot, isDark: boolean): CustomThemeColorSet {
  if (!isDark) { return snapshot.day; }
  const pick = (night: string, day: string): string => night.length > 0 ? night : day;
  return {
    primary: pick(snapshot.night.primary, snapshot.day.primary),
    secondary: pick(snapshot.night.secondary, snapshot.day.secondary),
    primaryText: pick(snapshot.night.primaryText, snapshot.day.primaryText),
    secondaryText: pick(snapshot.night.secondaryText, snapshot.day.secondaryText),
    background: pick(snapshot.night.background, snapshot.day.background),
    labelContainer: pick(snapshot.night.labelContainer, snapshot.day.labelContainer)
  };
}

/** 六个色位是否至少设了一个，对齐上游 `ThemeCustomColors.hasCustomColor`。 */
export function hasCustomColor(colors: CustomThemeColorSet): boolean {
  return colors.primary.length > 0 || colors.secondary.length > 0 ||
    colors.primaryText.length > 0 || colors.secondaryText.length > 0 ||
    colors.background.length > 0 || colors.labelContainer.length > 0;
}

/**
 * 六个手选色位 → 本地 8 个语义色位。
 *
 * 逐条对齐上游 `ui/theme/UserCustomTheme.kt:13-95 generateColorScheme`：
 *   primary             = primaryColor
 *   onSurface           = primaryFontColor
 *   onSurfaceVariant    = secondaryFontColor
 *   outline             = #79747E（上游固定值）
 *   surface             = backgroundColor
 *   surfaceContainerLow = labelContainerColor
 *   surfaceContainer    = backgroundColor
 *   surfaceContainerHigh= backgroundColor
 * 两个预览色位：secondary = secondaryColor，tertiary = secondaryColor（上游 `tertiary = secondaryColor`）。
 */
export function buildCustomPaletteColors(
  colors: CustomThemeColorSet, fallback: ThemePaletteColors
): ThemePaletteColors {
  const primary = colors.primary.length > 0 ? colors.primary : SLOT_FALLBACK.primary;
  const secondary = colors.secondary.length > 0 ? colors.secondary : SLOT_FALLBACK.secondary;
  const primaryText = colors.primaryText.length > 0 ? colors.primaryText : SLOT_FALLBACK.primaryText;
  const secondaryText = colors.secondaryText.length > 0 ? colors.secondaryText : SLOT_FALLBACK.secondaryText;
  const background = colors.background.length > 0 ? colors.background : SLOT_FALLBACK.background;
  const labelContainer = colors.labelContainer.length > 0
    ? colors.labelContainer : SLOT_FALLBACK.labelContainer;
  return {
    primary: primary,
    onSurface: primaryText,
    onSurfaceVariant: secondaryText,
    outline: CUSTOM_OUTLINE,
    surface: background,
    surfaceContainerLow: labelContainer,
    surfaceContainer: background,
    surfaceContainerHigh: background,
    secondary: secondary,
    tertiary: secondary
  };
}

/**
 * 自定义配色最终该用的 8 个色位；不是自定义主题（`paletteIndex != 12`）时返回 `undefined`，
 * 由调用方继续走内置调色板表。
 *
 * 深度个性化开：6 个手选色位直接映射（见 `buildCustomPaletteColors`）。
 * 深度个性化关（种子色模式）：本地只把种子色落到 `primary`，其余 7 位沿用内置默认配色——
 * 上游这里走的是 `CustomColorScheme(seed, ...)` 的 HCT 生成，ArkUI 没有等价算法，
 * 与其编一套假算法，不如如实回落并把这个差异写进 ZIP-THEME。
 */
export function resolveCustomPaletteColors(
  snapshot: CustomThemeSnapshot, isDark: boolean, fallback: ThemePaletteColors
): ThemePaletteColors | undefined {
  if (snapshot.enableDeepPersonalization) {
    return buildCustomPaletteColors(resolveCustomColorSet(snapshot, isDark), fallback);
  }
  // 夜间种子色未设时回落日间种子色，对齐上游 `customColors(isDark)` 的「夜间未设用日间」口径。
  const effectiveSeed = isDark
    ? (snapshot.seedColorNight.length > 0 ? snapshot.seedColorNight : snapshot.seedColorDay)
    : snapshot.seedColorDay;
  if (effectiveSeed.length === 0) {
    return undefined;
  }
  return {
    primary: effectiveSeed,
    onSurface: fallback.onSurface,
    onSurfaceVariant: fallback.onSurfaceVariant,
    outline: fallback.outline,
    surface: fallback.surface,
    surfaceContainerLow: fallback.surfaceContainerLow,
    surfaceContainer: fallback.surfaceContainer,
    surfaceContainerHigh: fallback.surfaceContainerHigh,
    secondary: fallback.secondary,
    tertiary: fallback.tertiary
  };
}
