import { ThemeModeResolver } from './ThemeModeResolver';

/**
 * 主题配色的本地色值表。
 *
 * 对齐上游 `ui/theme/AppThemeMode.kt` 的 14 个取值（`res/values/array_values.xml:30-45` 的 `"0".."13"`
 * 与 `res/values-zh-rCN/arrays.xml:160-175` 的中文名一一对应）：
 *
 *   0 动态取色 / 1 草野 / 2 柠檬 / 3 黑白 / 4 电子书 / 5 晴空 / 6 八月 / 7 新浪潮
 *   8 春 / 9 千禧年 / 10 隐海修会 / 11 乐队 / 12 自定义 / 13 透明
 *
 * 上游每套 colorScheme 有 45 个字段（`ui/theme/colorScheme/*ColorScheme.kt`），本地只落 8 个语义色位——
 * 正好覆盖 `resources/{base,dark}/element/color.json` 里的 8 个 `theme_*` 颜色资源，逐条对应关系：
 *
 *   primary             → theme_accent
 *   onSurface           → theme_text_primary
 *   onSurfaceVariant    → theme_text_secondary
 *   outline             → theme_text_tertiary
 *   surface             → theme_surface_primary
 *   surfaceContainerLow → theme_surface_secondary
 *   surfaceContainer    → theme_surface_tertiary
 *   surfaceContainerHigh→ theme_surface_elevated
 *
 * 两处与上游不一致，都写在各自的字段注释里：
 * ① `动态取色`（index 0）与 `自定义`（index 12）在本地回落成本地内置默认配色——
 *    ArkUI 没有 Android 12 `dynamicColorScheme` 的等价能力（`ets/api` 下 `dynamicColor|Monet` 零命中），
 *    自定义配色另由 A6 承接，见 [深色模式对照表](../../docs/parity/ZIP-THEME.md)。
 * ② `透明`（index 13）上游把容器色留空由背景图透出，本地 8 个色位是实色，
 *    仅取上游 `TransparentColorScheme` 的实色部分。
 */
export interface ThemePaletteColors {
  primary: string;
  onSurface: string;
  onSurfaceVariant: string;
  outline: string;
  surface: string;
  surfaceContainerLow: string;
  surfaceContainer: string;
  surfaceContainerHigh: string;
  /** 仅用于调色板色块预览（上游 `ThemeColorButton` 的上半圆），不参与全局换肤。 */
  secondary: string;
  /** 仅用于调色板色块预览（上游 `ThemeColorButton` 的下半圆），不参与全局换肤。 */
  tertiary: string;
}

/** 一套配色 = 序号 + 中文名 + 日间色值 + 夜间色值。 */
export interface ThemePaletteDefinition {
  index: number;
  name: string;
  light: ThemePaletteColors;
  dark: ThemePaletteColors;
}

/** 调色板取值范围，对齐上游 `array_values.xml:30-45` 的 `"0".."13"`。 */
export const THEME_PALETTE_MIN: number = 0;
export const THEME_PALETTE_MAX: number = 13;

/** 本地内置默认配色（= `resources/base/element/color.json` 的 8 个 `theme_*`），供动态取色与自定义回落。 */
const DEFAULT_LIGHT: ThemePaletteColors = {
  primary: '#3F5BD9',
  onSurface: '#1B1C22',
  onSurfaceVariant: '#2E3038',
  outline: '#6A6D77',
  surface: '#F5F6F8',
  surfaceContainerLow: '#FFFFFF',
  surfaceContainer: '#F0F1F5',
  surfaceContainerHigh: '#FFFFFF',
  secondary: '#5F74B8',
  tertiary: '#4A5FA8',
};

const DEFAULT_DARK: ThemePaletteColors = {
  primary: '#AFC2FF',
  onSurface: '#E3E4E8',
  onSurfaceVariant: '#D8D9E0',
  outline: '#92949E',
  surface: '#111217',
  surfaceContainerLow: '#1A1B21',
  surfaceContainer: '#1B1C22',
  surfaceContainerHigh: '#1C1D23',
  secondary: '#9FB0E8',
  tertiary: '#8A9BD8',
};

/** 14 套配色，序号即上游 `appTheme` 取值。 */
export const THEME_PALETTES: ThemePaletteDefinition[] = [
  {
    index: 0,
    name: '动态取色',
    light: {
      primary: '#3F5BD9',
      onSurface: '#1B1C22',
      onSurfaceVariant: '#2E3038',
      outline: '#6A6D77',
      surface: '#F5F6F8',
      surfaceContainerLow: '#FFFFFF',
      surfaceContainer: '#F0F1F5',
      surfaceContainerHigh: '#FFFFFF',
      secondary: '#5F74B8',
      tertiary: '#4A5FA8',
    },
    dark: {
      primary: '#AFC2FF',
      onSurface: '#E3E4E8',
      onSurfaceVariant: '#D8D9E0',
      outline: '#92949E',
      surface: '#111217',
      surfaceContainerLow: '#1A1B21',
      surfaceContainer: '#1B1C22',
      surfaceContainerHigh: '#1C1D23',
      secondary: '#9FB0E8',
      tertiary: '#8A9BD8',
    }
  },
  {
    index: 1,
    name: '草野',
    light: {
      primary: '#4C662B',
      onSurface: '#1A1C16',
      onSurfaceVariant: '#44483D',
      outline: '#75796C',
      surface: '#F9FAEF',
      surfaceContainerLow: '#F3F4E9',
      surfaceContainer: '#EEEFE3',
      surfaceContainerHigh: '#E8E9DE',
      secondary: '#586249',
      tertiary: '#386663',
    },
    dark: {
      primary: '#B1D18A',
      onSurface: '#E2E3D8',
      onSurfaceVariant: '#C5C8BA',
      outline: '#8F9285',
      surface: '#12140E',
      surfaceContainerLow: '#1A1C16',
      surfaceContainer: '#1E201A',
      surfaceContainerHigh: '#282B24',
      secondary: '#BFCBAD',
      tertiary: '#A0D0CB',
    }
  },
  {
    index: 2,
    name: '柠檬',
    light: {
      primary: '#6D5E0F',
      onSurface: '#1E1B13',
      onSurfaceVariant: '#4B4739',
      outline: '#7C7767',
      surface: '#FFF9EE',
      surfaceContainerLow: '#FAF3E5',
      surfaceContainer: '#F4EDDF',
      surfaceContainerHigh: '#EEE8DA',
      secondary: '#665E40',
      tertiary: '#43664E',
    },
    dark: {
      primary: '#DBC66E',
      onSurface: '#E8E2D4',
      onSurfaceVariant: '#CDC6B4',
      outline: '#969080',
      surface: '#15130B',
      surfaceContainerLow: '#1E1B13',
      surfaceContainer: '#222017',
      surfaceContainerHigh: '#2D2A21',
      secondary: '#D1C6A1',
      tertiary: '#A9D0B3',
    }
  },
  {
    index: 3,
    name: '黑白',
    light: {
      primary: '#5C5C5C',
      onSurface: '#1C1B1B',
      onSurfaceVariant: '#444748',
      outline: '#747878',
      surface: '#F8F8F8',
      surfaceContainerLow: '#F7F3F2',
      surfaceContainer: '#F1EDEC',
      surfaceContainerHigh: '#EBE7E7',
      secondary: '#5F5E5E',
      tertiary: '#5E5B5D',
    },
    dark: {
      primary: '#C7C6C6',
      onSurface: '#E5E2E1',
      onSurfaceVariant: '#C4C7C7',
      outline: '#8E918F',
      surface: '#141313',
      surfaceContainerLow: '#1C1B1B',
      surfaceContainer: '#201F1F',
      surfaceContainerHigh: '#2A2A2A',
      secondary: '#C8C6C5',
      tertiary: '#CBC5C7',
    }
  },
  {
    index: 4,
    name: '电子书',
    light: {
      primary: '#000000',
      onSurface: '#000000',
      onSurfaceVariant: '#000000',
      outline: '#000000',
      surface: '#FFFFFF',
      surfaceContainerLow: '#FFFFFF',
      surfaceContainer: '#FFFFFF',
      surfaceContainerHigh: '#FFFFFF',
      secondary: '#000000',
      tertiary: '#000000',
    },
    dark: {
      primary: '#FFFFFF',
      onSurface: '#FFFFFF',
      onSurfaceVariant: '#C4C7C5',
      outline: '#8E918F',
      surface: '#000000',
      surfaceContainerLow: '#1C1B1B',
      surfaceContainer: '#000000',
      surfaceContainerHigh: '#2A2A2A',
      secondary: '#FFFFFF',
      tertiary: '#FFFFFF',
    }
  },
  {
    index: 5,
    name: '晴空',
    light: {
      primary: '#3B608F',
      onSurface: '#191C20',
      onSurfaceVariant: '#43474E',
      outline: '#73777F',
      surface: '#F8F9FF',
      surfaceContainerLow: '#F2F3FA',
      surfaceContainer: '#EDEDF4',
      surfaceContainerHigh: '#E7E8EE',
      secondary: '#545F71',
      tertiary: '#6D5677',
    },
    dark: {
      primary: '#A5C9FE',
      onSurface: '#E1E2E9',
      onSurfaceVariant: '#C3C6CF',
      outline: '#8D9199',
      surface: '#111318',
      surfaceContainerLow: '#191C20',
      surfaceContainer: '#1D2024',
      surfaceContainerHigh: '#282A2F',
      secondary: '#BCC7DC',
      tertiary: '#D9BDE3',
    }
  },
  {
    index: 6,
    name: '八月',
    light: {
      primary: '#8F4C37',
      onSurface: '#231917',
      onSurfaceVariant: '#53433F',
      outline: '#85736E',
      surface: '#FFF8F6',
      surfaceContainerLow: '#FFF1ED',
      surfaceContainer: '#FCEAE5',
      surfaceContainerHigh: '#F7E4E0',
      secondary: '#77574D',
      tertiary: '#6B5D2F',
    },
    dark: {
      primary: '#FFB59F',
      onSurface: '#F1DFDA',
      onSurfaceVariant: '#D8C2BC',
      outline: '#A08C87',
      surface: '#1A110F',
      surfaceContainerLow: '#231917',
      surfaceContainer: '#271D1B',
      surfaceContainerHigh: '#322825',
      secondary: '#E7BDB2',
      tertiary: '#D8C68D',
    }
  },
  {
    index: 7,
    name: '新浪潮',
    light: {
      primary: '#8B4A62',
      onSurface: '#22191C',
      onSurfaceVariant: '#514347',
      outline: '#837377',
      surface: '#FFF8F8',
      surfaceContainerLow: '#FFF0F2',
      surfaceContainer: '#FAEAED',
      surfaceContainerHigh: '#F4E4E7',
      secondary: '#74565F',
      tertiary: '#7D5635',
    },
    dark: {
      primary: '#FFB0CA',
      onSurface: '#EFDFE2',
      onSurfaceVariant: '#D5C2C6',
      outline: '#9E8C90',
      surface: '#191114',
      surfaceContainerLow: '#22191C',
      surfaceContainer: '#261D20',
      surfaceContainerHigh: '#31282A',
      secondary: '#E2BDC7',
      tertiary: '#EFBC94',
    }
  },
  {
    index: 8,
    name: '春',
    light: {
      primary: '#8F4A4D',
      onSurface: '#221919',
      onSurfaceVariant: '#524343',
      outline: '#857373',
      surface: '#FFF8F7',
      surfaceContainerLow: '#FFF0F0',
      surfaceContainer: '#FCEAE9',
      surfaceContainerHigh: '#F6E4E4',
      secondary: '#765657',
      tertiary: '#755A2F',
    },
    dark: {
      primary: '#FFB3B4',
      onSurface: '#F0DEDE',
      onSurfaceVariant: '#D7C1C1',
      outline: '#9F8C8C',
      surface: '#1A1111',
      surfaceContainerLow: '#221919',
      surfaceContainer: '#271D1D',
      surfaceContainerHigh: '#322828',
      secondary: '#E6BDBD',
      tertiary: '#E6C18D',
    }
  },
  {
    index: 9,
    name: '千禧年',
    light: {
      primary: '#565992',
      onSurface: '#1B1B21',
      onSurfaceVariant: '#46464F',
      outline: '#777680',
      surface: '#FBF8FF',
      surfaceContainerLow: '#F5F2FA',
      surfaceContainer: '#F0ECF4',
      surfaceContainerHigh: '#EAE7EF',
      secondary: '#5C5D72',
      tertiary: '#78536B',
    },
    dark: {
      primary: '#BFC2FF',
      onSurface: '#E4E1E9',
      onSurfaceVariant: '#C7C5D0',
      outline: '#918F9A',
      surface: '#131318',
      surfaceContainerLow: '#1B1B21',
      surfaceContainer: '#1F1F25',
      surfaceContainerHigh: '#2A292F',
      secondary: '#C5C4DD',
      tertiary: '#E8B9D5',
    }
  },
  {
    index: 10,
    name: '隐海修会',
    light: {
      primary: '#6B5E10',
      onSurface: '#1E1C13',
      onSurfaceVariant: '#4A4739',
      outline: '#7C7768',
      surface: '#FFF9EC',
      surfaceContainerLow: '#F9F3E5',
      surfaceContainer: '#F4EDDF',
      surfaceContainerHigh: '#EEE8DA',
      secondary: '#475D92',
      tertiary: '#01677D',
    },
    dark: {
      primary: '#D9C76F',
      onSurface: '#E8E2D4',
      onSurfaceVariant: '#CCC6B4',
      outline: '#969180',
      surface: '#15130C',
      surfaceContainerLow: '#1E1C13',
      surfaceContainer: '#222017',
      surfaceContainerHigh: '#2C2A21',
      secondary: '#B1C5FF',
      tertiary: '#86D1EA',
    }
  },
  {
    index: 11,
    name: '乐队',
    light: {
      primary: '#8E4958',
      onSurface: '#22191B',
      onSurfaceVariant: '#524345',
      outline: '#847375',
      surface: '#FFF8F7',
      surfaceContainerLow: '#FFF0F1',
      surfaceContainer: '#FBEAEB',
      surfaceContainerHigh: '#F5E4E6',
      secondary: '#75565C',
      tertiary: '#4D5C92',
    },
    dark: {
      primary: '#FFB1C0',
      onSurface: '#EFDEE0',
      onSurfaceVariant: '#D6C2C4',
      outline: '#9F8C8F',
      surface: '#191113',
      surfaceContainerLow: '#22191B',
      surfaceContainer: '#261D1F',
      surfaceContainerHigh: '#312829',
      secondary: '#E4BDC3',
      tertiary: '#B6C4FF',
    }
  },
  {
    index: 12,
    name: '自定义',
    light: {
      primary: '#3F5BD9',
      onSurface: '#1B1C22',
      onSurfaceVariant: '#2E3038',
      outline: '#6A6D77',
      surface: '#F5F6F8',
      surfaceContainerLow: '#FFFFFF',
      surfaceContainer: '#F0F1F5',
      surfaceContainerHigh: '#FFFFFF',
      secondary: '#5F74B8',
      tertiary: '#4A5FA8',
    },
    dark: {
      primary: '#AFC2FF',
      onSurface: '#E3E4E8',
      onSurfaceVariant: '#D8D9E0',
      outline: '#92949E',
      surface: '#111217',
      surfaceContainerLow: '#1A1B21',
      surfaceContainer: '#1B1C22',
      surfaceContainerHigh: '#1C1D23',
      secondary: '#9FB0E8',
      tertiary: '#8A9BD8',
    }
  },
  {
    index: 13,
    name: '透明',
    light: {
      primary: '#000000',
      onSurface: '#1E1C13',
      onSurfaceVariant: '#000000',
      outline: '#7C7768',
      surface: '#FFFFFF',
      surfaceContainerLow: '#FFFFFF',
      surfaceContainer: '#FFFFFF',
      surfaceContainerHigh: '#FFFFFF',
      secondary: '#000000',
      tertiary: '#000000',
    },
    dark: {
      primary: '#FFFFFF',
      onSurface: '#EDE6FF',
      onSurfaceVariant: '#FFFFFF',
      outline: '#FFFFFF',
      surface: '#FFFFFF',
      surfaceContainerLow: '#000000',
      surfaceContainer: '#FFFFFF',
      surfaceContainerHigh: '#FFFFFF',
      secondary: '#FFFFFF',
      tertiary: '#FFFFFF',
    }
  },
];

/** 序号归一：越界一律回落 0（动态取色），对齐上游 `appTheme` 默认值 `"0"`。 */
export function normalizePaletteIndex(index: number): number {
  if (!Number.isFinite(index)) { return THEME_PALETTE_MIN; }
  const rounded = Math.round(index);
  if (rounded < THEME_PALETTE_MIN || rounded > THEME_PALETTE_MAX) { return THEME_PALETTE_MIN; }
  return rounded;
}

/** 序号 → 中文名；越界回落第 0 项，避免界面上出现空白标题。 */
export function themePaletteName(index: number): string {
  return THEME_PALETTES[normalizePaletteIndex(index)].name;
}

/**
 * 序号 + 日夜 → 8 个色位。
 *
 * 上游由 `ThemeEngine.getColorScheme(context, mode, darkTheme, isAmoled, ...)` 现算，
 * 这里直接查表；纯黑（`isAmoled`）由 `themePureBlack` 那套条件式替换承接，不在本函数里叠加，
 * 否则会和 r309 的 `#000000` 覆盖打两次架。
 */
export function resolvePaletteColors(index: number, isDark: boolean): ThemePaletteColors {
  const definition = THEME_PALETTES[normalizePaletteIndex(index)];
  return isDark ? definition.dark : definition.light;
}

/**
 * 把一套配色广播到 AppStorage，供各 struct 的 `@StorageProp` 订阅。
 *
 * 键名必须与 130 个 struct 里 `@StorageProp('themeColorXxx')` 的写法**逐字一致**：
 * 那批键是按 8 个 `theme_*` 颜色资源命名的（`themeColorTextPrimary` 等），
 * 所以这里按资源映射改名，不能直接用 `primary`/`onSurface` 这些上游字段名。
 */
export function publishPaletteColors(colors: ThemePaletteColors): void {
  AppStorage.setOrCreate('themeColorAccent', colors.primary);
  AppStorage.setOrCreate('themeColorTextPrimary', colors.onSurface);
  AppStorage.setOrCreate('themeColorTextSecondary', colors.onSurfaceVariant);
  AppStorage.setOrCreate('themeColorTextTertiary', colors.outline);
  AppStorage.setOrCreate('themeColorSurfacePrimary', colors.surface);
  AppStorage.setOrCreate('themeColorSurfaceSecondary', colors.surfaceContainerLow);
  AppStorage.setOrCreate('themeColorSurfaceTertiary', colors.surfaceContainer);
  AppStorage.setOrCreate('themeColorSurfaceElevated', colors.surfaceContainerHigh);
}

/** 序号 + `themeMode` + 系统色模式 → 广播当前该用的配色。`themeMode` 三值口径见 `ThemeModeResolver`。 */
export function applyPalette(context: Context, index: number, themeMode: string): ThemePaletteColors {
  const isDark = ThemeModeResolver.isDarkTheme(themeMode, ThemeModeResolver.isSystemDark(context));
  const colors = resolvePaletteColors(index, isDark);
  publishPaletteColors(colors);
  return colors;
}

/**
 * 同上，但传入了自定义配色时优先用它。
 *
 * 上游 `ui/theme/AppTheme.kt:105-125`：`appTheme == Custom && enableDeepPersonalization && hasCustomColor`
 * 时走 `generateColorScheme(userPalette, ...)`，否则继续走 `ThemeEngine.getColorScheme`。
 * 本地按同一顺序：调用方算出 `customColors`（`undefined` 表示不走自定义）就优先用，否则查内置调色板表。
 */
export function applyThemeColors(
  context: Context, index: number, themeMode: string,
  customColors: ThemePaletteColors | undefined
): ThemePaletteColors {
  const isDark = ThemeModeResolver.isDarkTheme(themeMode, ThemeModeResolver.isSystemDark(context));
  const colors = customColors !== undefined ? customColors : resolvePaletteColors(index, isDark);
  publishPaletteColors(colors);
  return colors;
}
