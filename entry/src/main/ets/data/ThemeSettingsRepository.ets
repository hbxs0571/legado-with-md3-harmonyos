import { preferences } from '@kit.ArkData';
import {
  CONTAINER_OPACITY_DEFAULT,
  CARD_BORDER_WIDTH_DEFAULT,
  CARD_RADIUS_DEFAULT,
  DIVIDER_LENGTH_DEFAULT,
  DIVIDER_WIDTH_DEFAULT,
  normalizeCardBorderWidth,
  normalizeCardCornerRadius,
  normalizeContainerOpacity,
  normalizeDividerLength,
  normalizeDividerWidth
} from './ThemeCardStyle';

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

/** 全局字体缩放的合法区间，对齐上游 `AppShellSettings.fontScale` 的 8..16（即 0.8x..1.6x）。 */
export const FONT_SCALE_MIN: number = 8;
export const FONT_SCALE_MAX: number = 16;
export const FONT_SCALE_DEFAULT: number = 10;

/** 主题模式快照。 */
export interface ThemeSnapshot {
  /** 三值字符串 `"0"`/`"1"`/`"2"`，对齐上游 `AppShellSettings.themeMode`。 */
  themeMode: string;
  /** 调色板序号 0..4，对齐本地 `ThemeSettingsPage` 的五个 `ThemePaletteItem`。 */
  paletteIndex: number;
  /** 全局字体缩放 8..16，对齐上游 `constant/PreferKey.kt:6 fontScale`（默认 10 = 1.0x）。 */
  fontScale: number;
  /** 是否显示状态栏，对齐上游 `AppShellSettings.kt:10 showStatusBar`（默认 true）。 */
  showStatusBar: boolean;
  /** 是否启用滑动时动画，对齐上游 `AppShellSettings.kt:11 swipeAnimation`（默认 true）。 */
  swipeAnimation: boolean;
  /** 书籍详情页界面颜色是否跟随封面取色，对齐上游 `ThemeSettings.kt` 的 bookInfoFollowCoverColor（默认 true）。 */
  bookInfoFollowCoverColor: boolean;
  /** 网络封面背景模式，对齐上游 bookInfoNetworkCoverBackground（`off`/`on`/`off_for_default`，默认 `on`）。 */
  bookInfoNetworkCoverBackground: string;
  /** 默认封面背景模式，对齐上游 bookInfoDefaultCoverBackground（默认 `on`）。 */
  bookInfoDefaultCoverBackground: string;
  /** 容器底色不透明度 0..100，对齐上游 `ThemeSettings.kt:24 containerOpacity`（默认 100）。 */
  containerOpacity: number;
  /** 关闭设置分组圆角，对齐上游 `disableSplicedColumnGroupCornerRadius`（默认 false）。 */
  disableSplicedColumnGroupCornerRadius: boolean;
  /** 覆盖卡片圆角总开关，对齐上游 `overrideBaseCardCornerRadius`（默认 false）。 */
  overrideBaseCardCornerRadius: boolean;
  /** 卡片圆角数值 0..40，对齐上游 `baseCardCornerRadius`（默认 16）。 */
  baseCardCornerRadius: number;
  /** 覆盖卡片边框总开关，对齐上游 `overrideBaseCardBorder`（默认 false）。 */
  overrideBaseCardBorder: boolean;
  /** 边框宽度 0..5，对齐上游 `baseCardBorderWidth`（默认 1）。 */
  baseCardBorderWidth: number;
  /** 日间边框色 `#RRGGBB`，空串表示未设置。对齐上游 `baseCardBorderColor`。 */
  baseCardBorderColorDay: string;
  /** 夜间边框色 `#RRGGBB`，空串表示未设置。对齐上游 `baseCardBorderColorNight`。 */
  baseCardBorderColorNight: string;
  /** 显示分隔线，对齐上游 `ThemeSettings.kt:63 enableItemDivider`（默认 false）。 */
  enableItemDivider: boolean;
  /** 分隔线宽度 0..5，对齐上游 `itemDividerWidth`（默认 1）。 */
  itemDividerWidth: number;
  /** 分隔线长度 30..100（百分比），对齐上游 `itemDividerLength`（默认 80）。 */
  itemDividerLength: number;
  /** 分隔线颜色 `#RRGGBB`，空串表示未设置。对齐上游 `itemDividerColor`。 */
  itemDividerColor: string;
  /** 容器背景图总开关，对齐上游 `enableContainerBackgroundImage`（默认 false）。 */
  enableContainerBackgroundImage: boolean;
  /** 大容器日间背景图本地路径，空串表示未选择。对齐上游 `largeContainerBackgroundImageLight`。 */
  largeContainerBackgroundImageLight: string;
  /** 大容器夜间背景图本地路径。对齐上游 `largeContainerBackgroundImageDark`。 */
  largeContainerBackgroundImageDark: string;
  /** 项目日间背景图本地路径。对齐上游 `itemBackgroundImageLight`。 */
  itemBackgroundImageLight: string;
  /** 项目夜间背景图本地路径。对齐上游 `itemBackgroundImageDark`。 */
  itemBackgroundImageDark: string;
}

/** 书籍详情页背景封面的三种模式，取值与上游 `res/values/array_values.xml:135-139` 一致。 */
export const BOOK_INFO_BACKGROUND_OFF: string = 'off';
export const BOOK_INFO_BACKGROUND_ON: string = 'on';
export const BOOK_INFO_BACKGROUND_OFF_FOR_DEFAULT: string = 'off_for_default';

/** 背景封面模式的取值域归一，非法值回落到 `on`。 */
export function normalizeBookInfoBackground(value: string): string {
  if (value === BOOK_INFO_BACKGROUND_OFF || value === BOOK_INFO_BACKGROUND_OFF_FOR_DEFAULT) { return value; }
  return BOOK_INFO_BACKGROUND_ON;
}

/** 字体缩放夹取到 8..16，非法值回落到默认 10。 */
export function normalizeFontScale(value: number): number {
  if (!Number.isFinite(value)) { return FONT_SCALE_DEFAULT; }
  const rounded = Math.round(value);
  if (rounded < FONT_SCALE_MIN) { return FONT_SCALE_MIN; }
  if (rounded > FONT_SCALE_MAX) { return FONT_SCALE_MAX; }
  return rounded;
}

/**
 * 颜色串归一成 `#RRGGBB` 或 `#AARRGGBB`，其余一律返回空串（= 未设置）。
 *
 * 上游这四个颜色键是 Int（0 表示未设置，`FeatureSettingsRepositories.kt:384-385`），
 * 本地存字符串便于直接喂给 `ResourceColor`；空串对应上游的 0。
 */
export function normalizeThemeColor(value: string): string {
  if (value.length === 0) { return ''; }
  const trimmed = value.trim().toUpperCase();
  if (!/^#([0-9A-F]{6}|[0-9A-F]{8})$/.test(trimmed)) { return ''; }
  return trimmed;
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
    const defaults: ThemeSnapshot = {
      themeMode: THEME_MODE_FOLLOW_SYSTEM,
      paletteIndex: 0,
      fontScale: FONT_SCALE_DEFAULT,
      showStatusBar: true,
      swipeAnimation: true,
      bookInfoFollowCoverColor: true,
      bookInfoNetworkCoverBackground: BOOK_INFO_BACKGROUND_ON,
      bookInfoDefaultCoverBackground: BOOK_INFO_BACKGROUND_ON,
      containerOpacity: CONTAINER_OPACITY_DEFAULT,
      disableSplicedColumnGroupCornerRadius: false,
      overrideBaseCardCornerRadius: false,
      baseCardCornerRadius: CARD_RADIUS_DEFAULT,
      overrideBaseCardBorder: false,
      baseCardBorderWidth: CARD_BORDER_WIDTH_DEFAULT,
      baseCardBorderColorDay: '',
      baseCardBorderColorNight: '',
      enableItemDivider: false,
      itemDividerWidth: DIVIDER_WIDTH_DEFAULT,
      itemDividerLength: DIVIDER_LENGTH_DEFAULT,
      itemDividerColor: '',
      enableContainerBackgroundImage: false,
      largeContainerBackgroundImageLight: '',
      largeContainerBackgroundImageDark: '',
      itemBackgroundImageLight: '',
      itemBackgroundImageDark: ''
    };
    try {
      const store = await preferences.getPreferences(context, ThemeSettingsRepository.preferenceName);
      const themeMode = await store.get('themeMode', defaults.themeMode);
      const paletteIndex = await store.get('paletteIndex', defaults.paletteIndex);
      const fontScale = await store.get('fontScale', defaults.fontScale);
      const showStatusBar = await store.get('showStatusBar', defaults.showStatusBar);
      const swipeAnimation = await store.get('swipeAnimation', defaults.swipeAnimation);
      const followCoverColor = await store.get('bookInfoFollowCoverColor', defaults.bookInfoFollowCoverColor);
      const networkCoverBackground = await store.get('bookInfoNetworkCoverBackground', defaults.bookInfoNetworkCoverBackground);
      const defaultCoverBackground = await store.get('bookInfoDefaultCoverBackground', defaults.bookInfoDefaultCoverBackground);
      const containerOpacity = await store.get('containerOpacity', defaults.containerOpacity);
      const disableGroupCorner = await store.get('disableSplicedColumnGroupCornerRadius',
        defaults.disableSplicedColumnGroupCornerRadius);
      const overrideCardCorner = await store.get('overrideBaseCardCornerRadius', defaults.overrideBaseCardCornerRadius);
      const cardCornerRadius = await store.get('baseCardCornerRadius', defaults.baseCardCornerRadius);
      const overrideCardBorder = await store.get('overrideBaseCardBorder', defaults.overrideBaseCardBorder);
      const cardBorderWidth = await store.get('baseCardBorderWidth', defaults.baseCardBorderWidth);
      const borderColorDay = await store.get('baseCardBorderColorDay', defaults.baseCardBorderColorDay);
      const borderColorNight = await store.get('baseCardBorderColorNight', defaults.baseCardBorderColorNight);
      const enableDivider = await store.get('enableItemDivider', defaults.enableItemDivider);
      const dividerWidth = await store.get('itemDividerWidth', defaults.itemDividerWidth);
      const dividerLength = await store.get('itemDividerLength', defaults.itemDividerLength);
      const dividerColor = await store.get('itemDividerColor', defaults.itemDividerColor);
      const containerBg = await store.get('enableContainerBackgroundImage', defaults.enableContainerBackgroundImage);
      const largeLight = await store.get('largeContainerBackgroundImageLight', defaults.largeContainerBackgroundImageLight);
      const largeDark = await store.get('largeContainerBackgroundImageDark', defaults.largeContainerBackgroundImageDark);
      const itemLight = await store.get('itemBackgroundImageLight', defaults.itemBackgroundImageLight);
      const itemDark = await store.get('itemBackgroundImageDark', defaults.itemBackgroundImageDark);
      return {
        themeMode: typeof themeMode === 'string' ? ThemeSettingsRepository.normalizeThemeMode(themeMode) : defaults.themeMode,
        paletteIndex: typeof paletteIndex === 'number' ? Math.max(0, Math.min(4, paletteIndex)) : defaults.paletteIndex,
        fontScale: typeof fontScale === 'number' ? normalizeFontScale(fontScale) : defaults.fontScale,
        showStatusBar: typeof showStatusBar === 'boolean' ? showStatusBar : defaults.showStatusBar,
        swipeAnimation: typeof swipeAnimation === 'boolean' ? swipeAnimation : defaults.swipeAnimation,
        bookInfoFollowCoverColor: typeof followCoverColor === 'boolean' ? followCoverColor : defaults.bookInfoFollowCoverColor,
        bookInfoNetworkCoverBackground: typeof networkCoverBackground === 'string'
          ? normalizeBookInfoBackground(networkCoverBackground) : defaults.bookInfoNetworkCoverBackground,
        bookInfoDefaultCoverBackground: typeof defaultCoverBackground === 'string'
          ? normalizeBookInfoBackground(defaultCoverBackground) : defaults.bookInfoDefaultCoverBackground,
        containerOpacity: typeof containerOpacity === 'number'
          ? normalizeContainerOpacity(containerOpacity) : defaults.containerOpacity,
        disableSplicedColumnGroupCornerRadius: typeof disableGroupCorner === 'boolean'
          ? disableGroupCorner : defaults.disableSplicedColumnGroupCornerRadius,
        overrideBaseCardCornerRadius: typeof overrideCardCorner === 'boolean'
          ? overrideCardCorner : defaults.overrideBaseCardCornerRadius,
        baseCardCornerRadius: typeof cardCornerRadius === 'number'
          ? normalizeCardCornerRadius(cardCornerRadius) : defaults.baseCardCornerRadius,
        overrideBaseCardBorder: typeof overrideCardBorder === 'boolean'
          ? overrideCardBorder : defaults.overrideBaseCardBorder,
        baseCardBorderWidth: typeof cardBorderWidth === 'number'
          ? normalizeCardBorderWidth(cardBorderWidth) : defaults.baseCardBorderWidth,
        baseCardBorderColorDay: typeof borderColorDay === 'string'
          ? normalizeThemeColor(borderColorDay) : defaults.baseCardBorderColorDay,
        baseCardBorderColorNight: typeof borderColorNight === 'string'
          ? normalizeThemeColor(borderColorNight) : defaults.baseCardBorderColorNight,
        enableItemDivider: typeof enableDivider === 'boolean' ? enableDivider : defaults.enableItemDivider,
        itemDividerWidth: typeof dividerWidth === 'number'
          ? normalizeDividerWidth(dividerWidth) : defaults.itemDividerWidth,
        itemDividerLength: typeof dividerLength === 'number'
          ? normalizeDividerLength(dividerLength) : defaults.itemDividerLength,
        itemDividerColor: typeof dividerColor === 'string'
          ? normalizeThemeColor(dividerColor) : defaults.itemDividerColor,
        enableContainerBackgroundImage: typeof containerBg === 'boolean'
          ? containerBg : defaults.enableContainerBackgroundImage,
        largeContainerBackgroundImageLight: typeof largeLight === 'string'
          ? largeLight : defaults.largeContainerBackgroundImageLight,
        largeContainerBackgroundImageDark: typeof largeDark === 'string'
          ? largeDark : defaults.largeContainerBackgroundImageDark,
        itemBackgroundImageLight: typeof itemLight === 'string'
          ? itemLight : defaults.itemBackgroundImageLight,
        itemBackgroundImageDark: typeof itemDark === 'string'
          ? itemDark : defaults.itemBackgroundImageDark
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

  static async save(context: Context, snapshot: ThemeSnapshot): Promise<void> {
    const store = await preferences.getPreferences(context, ThemeSettingsRepository.preferenceName);
    await store.put('themeMode', ThemeSettingsRepository.normalizeThemeMode(snapshot.themeMode));
    await store.put('paletteIndex', Math.max(0, Math.min(4, snapshot.paletteIndex)));
    await store.put('fontScale', normalizeFontScale(snapshot.fontScale));
    await store.put('showStatusBar', snapshot.showStatusBar);
    await store.put('swipeAnimation', snapshot.swipeAnimation);
    await store.put('bookInfoFollowCoverColor', snapshot.bookInfoFollowCoverColor);
    await store.put('bookInfoNetworkCoverBackground',
      normalizeBookInfoBackground(snapshot.bookInfoNetworkCoverBackground));
    await store.put('bookInfoDefaultCoverBackground',
      normalizeBookInfoBackground(snapshot.bookInfoDefaultCoverBackground));
    await store.put('containerOpacity', normalizeContainerOpacity(snapshot.containerOpacity));
    await store.put('disableSplicedColumnGroupCornerRadius', snapshot.disableSplicedColumnGroupCornerRadius);
    await store.put('overrideBaseCardCornerRadius', snapshot.overrideBaseCardCornerRadius);
    await store.put('baseCardCornerRadius', normalizeCardCornerRadius(snapshot.baseCardCornerRadius));
    await store.put('overrideBaseCardBorder', snapshot.overrideBaseCardBorder);
    await store.put('baseCardBorderWidth', normalizeCardBorderWidth(snapshot.baseCardBorderWidth));
    await store.put('baseCardBorderColorDay', normalizeThemeColor(snapshot.baseCardBorderColorDay));
    await store.put('baseCardBorderColorNight', normalizeThemeColor(snapshot.baseCardBorderColorNight));
    await store.put('enableItemDivider', snapshot.enableItemDivider);
    await store.put('itemDividerWidth', normalizeDividerWidth(snapshot.itemDividerWidth));
    await store.put('itemDividerLength', normalizeDividerLength(snapshot.itemDividerLength));
    await store.put('itemDividerColor', normalizeThemeColor(snapshot.itemDividerColor));
    await store.put('enableContainerBackgroundImage', snapshot.enableContainerBackgroundImage);
    await store.put('largeContainerBackgroundImageLight', snapshot.largeContainerBackgroundImageLight);
    await store.put('largeContainerBackgroundImageDark', snapshot.largeContainerBackgroundImageDark);
    await store.put('itemBackgroundImageLight', snapshot.itemBackgroundImageLight);
    await store.put('itemBackgroundImageDark', snapshot.itemBackgroundImageDark);
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
