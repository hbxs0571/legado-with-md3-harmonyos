import { normalizeAppFontPath } from './AppFontSettings';
import { THEME_PALETTE_MAX, THEME_PALETTE_MIN } from './ThemePalette';
import {
  CustomThemeSnapshot, defaultCustomThemeSnapshot, normalizeCustomThemeSnapshot
} from './CustomThemeColors';
import { preferences } from '@kit.ArkData';
import { normalizeLabelVisibility } from './MainNavigationSettings';
import {
  BAR_BLUR_ALPHA_MAX, BAR_BLUR_ALPHA_MIN, BOTTOM_BAR_BLUR_ALPHA_DEFAULT, BOTTOM_BAR_BLUR_RADIUS_DEFAULT,
  BOTTOM_BAR_LENS_RADIUS_DEFAULT, BOTTOM_BAR_OPACITY_DEFAULT, TOP_BAR_BLUR_ALPHA_DEFAULT,
  TOP_BAR_BLUR_RADIUS_DEFAULT, TOP_BAR_BUTTON_STYLE_DEFAULT, TOP_BAR_OPACITY_DEFAULT,
  normalizeBarBlurAlpha, normalizeBottomBarBlurRadius, normalizeBottomBarLensRadius,
  normalizeBottomBarOpacity, normalizeTopBarBlurRadius, normalizeTopBarButtonStyle,
  normalizeTopBarOpacity
} from './TopBottomBarSettings';
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
  /** 调色板序号 0..13，对齐上游 `appTheme` 的 14 个取值（`res/values/array_values.xml:30-45`）。 */
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
  /**
   * 纯黑深色模式（AMOLED），对齐上游 `domain/model/settings/ThemeSettings.kt:6 isPureBlack`
   * 与 `constant/PreferKey.kt:365 pureBlack = "pure_black"`（默认 false）。
   */
  pureBlack: boolean;
  /** 全 App 日间背景图本地路径，空串表示未设置。对齐上游 `backgroundImage`。 */
  backgroundImage: string;
  /** 全 App 夜间背景图本地路径，空串表示未设置。对齐上游 `backgroundImageNight`。 */
  backgroundImageNight: string;
  /** 日间背景图虚化半径（vp），对齐上游 `backgroundImageBlurring`（默认 0）。 */
  backgroundImageBlurring: number;
  /** 夜间背景图虚化半径（vp），对齐上游 `backgroundImageNightBlurring`（默认 0）。 */
  backgroundImageNightBlurring: number;
  /** 首页是否出现在主导航里，对齐上游 `AppShellSettings.kt:6 showHome`（默认 true）。 */
  showHome: boolean;
  /** 发现是否出现在主导航里，对齐上游 `AppShellSettings.kt:7 showDiscovery`（默认 true）。 */
  showDiscovery: boolean;
  /** 订阅是否出现在主导航里，对齐上游 `AppShellSettings.kt:8 showRss`（默认 true）。 */
  showRss: boolean;
  /** 默认主页面 route，对齐上游 `AppShellSettings.kt:17 defaultHomePage`（默认 bookshelf）。 */
  defaultHomePage: string;
  /** 主导航顺序（逗号分隔），对齐上游 `AppShellSettings.kt:18 mainNavigationOrder`。 */
  mainNavigationOrder: string;
  /** 导航标签模式，对齐上游 `AppShellSettings.kt:19 labelVisibilityMode`（默认 auto）。 */
  labelVisibilityMode: string;
  /**
   * 预见性返回手势，对齐上游 `AppShellSettings.kt:9 predictiveBackEnabled`（默认 true）。
   * ArkUI 没有对应的系统能力（SDK 里 `predictiveBack` 零命中），只落盘不驱动渲染。
   */
  predictiveBack: boolean;
  /** 阅读界面共享元素动画，对齐上游 `AppShellSettings.kt:10 readerSharedElementEnabled`（默认 true）。 */
  readerSharedElement: boolean;
  /** 控件模糊总开关，对齐上游 `ThemeSettings.kt:33 enableBlur`（默认 false）。 */
  enableBlur: boolean;
  /** 渐变模糊，对齐上游 `ThemeSettings.kt:34 enableProgressiveBlur`（默认 false）。 */
  enableProgressiveBlur: boolean;
  /** 折叠应用栏，对齐上游 `ThemeSettings.kt:44 useFlexibleTopAppBar`（默认 true）。 */
  useFlexibleTopAppBar: boolean;
  /** 顶栏按钮样式，对齐上游 `ThemeSettings.kt:45 topBarButtonStyle`（默认 tonal）。 */
  topBarButtonStyle: string;
  /** 合并顶栏按钮，对齐上游 `ThemeSettings.kt:46 mergeTopBarActions`（默认 false）。 */
  mergeTopBarActions: boolean;
  /** 显示导航栏，对齐上游 `AppShellSettings.kt showBottomView`（默认 true）。 */
  showBottomView: boolean;
  /** 悬浮底栏，对齐上游 `AppShellSettings.kt useFloatingBottomBar`（默认 false）。 */
  useFloatingBottomBar: boolean;
  /** 悬浮底栏液态玻璃，对齐上游 `AppShellSettings.kt useFloatingBottomBarLiquidGlass`（默认 false）。 */
  useFloatingBottomBarLiquidGlass: boolean;
  /** 底栏模糊强度（液态玻璃扭曲程度），对齐上游 `ThemeSettings.kt:43 bottomBarLensRadius`（默认 24）。 */
  bottomBarLensRadius: number;
  /** 顶栏模糊半径，对齐上游 `ThemeSettings.kt:39 topBarBlurRadius`（默认 24）。 */
  topBarBlurRadius: number;
  /** 底栏模糊半径，对齐上游 `ThemeSettings.kt:40 bottomBarBlurRadius`（默认 8）。 */
  bottomBarBlurRadius: number;
  /** 顶栏模糊透明度，对齐上游 `ThemeSettings.kt:41 topBarBlurAlpha`（默认 73）。 */
  topBarBlurAlpha: number;
  /** 底栏模糊透明度，对齐上游 `ThemeSettings.kt:42 bottomBarBlurAlpha`（默认 40）。 */
  bottomBarBlurAlpha: number;
  /** 顶栏不透明度，对齐上游 `ThemeSettings.kt:35 topBarOpacity`（默认 100）。 */
  topBarOpacity: number;
  /** 底栏不透明度，对齐上游 `ThemeSettings.kt:36 bottomBarOpacity`（默认 100）。 */
  bottomBarOpacity: number;
  /** 应用字体文件在沙箱内的绝对路径；空串表示系统默认字体。对齐上游 `ThemeSettings.appFontPath`。 */
  appFontPath: string;
  /**
   * 自定义主题配色（上游 `appTheme == "12"` 那套 16 个键）。
   *
   * 上游是 16 个平铺键（`ThemeSettings.kt` 的 6 个颜色 + 6 个 `*Night` + 4 个开关/枚举），
   * 本地序列化成一个 JSON 字符串存在单键 `customTheme` 里，避免 preferences 里多出 16 个散键。
   */
  customTheme: CustomThemeSnapshot;
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
/**
 * 背景图虚化半径归一（0..40）。上游 `ThemeSettings.kt:54 backgroundImageBlurring: Int = 0`，
 * 界面滑块上限 40（`ThemeConfigScreen.kt:828-880` 的 BackgroundImageManageSheet）。
 */
export function normalizeBackgroundBlur(value: number): number {
  if (!Number.isFinite(value)) { return 0; }
  const rounded = Math.round(value);
  if (rounded < 0) { return 0; }
  return rounded > 40 ? 40 : rounded;
}

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
 * `customTheme` 单键（JSON 字符串）→ 快照；解析失败或格式不对一律回落默认。
 *
 * 上游这 16 个键是平铺在 preferences 里的（`FeatureSettingsRepositories.kt` 的 `toPrefMap()`），
 * 本地合成一个键，所以读回时要自己兜住脏数据，不能让一条坏 JSON 把整个主题设置带崩。
 */
export function parseCustomThemeSnapshot(raw: string): CustomThemeSnapshot {
  if (raw.length === 0) { return defaultCustomThemeSnapshot(); }
  try {
    const parsed = JSON.parse(raw) as CustomThemeSnapshot;
    if (parsed === null || typeof parsed !== 'object') { return defaultCustomThemeSnapshot(); }
    const fallback = defaultCustomThemeSnapshot();
    return normalizeCustomThemeSnapshot({
      enableDeepPersonalization: parsed.enableDeepPersonalization === true,
      paletteStyle: typeof parsed.paletteStyle === 'string' ? parsed.paletteStyle : fallback.paletteStyle,
      customContrast: typeof parsed.customContrast === 'string' ? parsed.customContrast : fallback.customContrast,
      materialVersion: typeof parsed.materialVersion === 'string' ? parsed.materialVersion : fallback.materialVersion,
      seedColorDay: typeof parsed.seedColorDay === 'string' ? parsed.seedColorDay : '',
      seedColorNight: typeof parsed.seedColorNight === 'string' ? parsed.seedColorNight : '',
      day: parsed.day !== undefined && parsed.day !== null ? parsed.day : fallback.day,
      night: parsed.night !== undefined && parsed.night !== null ? parsed.night : fallback.night
    });
  } catch (_) {
    return defaultCustomThemeSnapshot();
  }
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
      itemBackgroundImageDark: '',
      pureBlack: false,
      backgroundImage: '',
      backgroundImageNight: '',
      backgroundImageBlurring: 0,
      backgroundImageNightBlurring: 0,
      showHome: true,
      showDiscovery: true,
      showRss: true,
      defaultHomePage: 'bookshelf',
      mainNavigationOrder: 'home,bookshelf,explore,rss,my',
      labelVisibilityMode: 'auto',
      predictiveBack: true,
      readerSharedElement: true,
      enableBlur: false,
      enableProgressiveBlur: false,
      useFlexibleTopAppBar: true,
      topBarButtonStyle: TOP_BAR_BUTTON_STYLE_DEFAULT,
      mergeTopBarActions: false,
      showBottomView: true,
      useFloatingBottomBar: false,
      useFloatingBottomBarLiquidGlass: false,
      bottomBarLensRadius: BOTTOM_BAR_LENS_RADIUS_DEFAULT,
      topBarBlurRadius: TOP_BAR_BLUR_RADIUS_DEFAULT,
      bottomBarBlurRadius: BOTTOM_BAR_BLUR_RADIUS_DEFAULT,
      topBarBlurAlpha: TOP_BAR_BLUR_ALPHA_DEFAULT,
      bottomBarBlurAlpha: BOTTOM_BAR_BLUR_ALPHA_DEFAULT,
      topBarOpacity: TOP_BAR_OPACITY_DEFAULT,
      bottomBarOpacity: BOTTOM_BAR_OPACITY_DEFAULT,
      appFontPath: '',
      customTheme: defaultCustomThemeSnapshot()
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
      const pureBlack = await store.get('pureBlack', defaults.pureBlack);
      const appBgLight = await store.get('backgroundImage', defaults.backgroundImage);
      const appBgDark = await store.get('backgroundImageNight', defaults.backgroundImageNight);
      const appBgBlur = await store.get('backgroundImageBlurring', defaults.backgroundImageBlurring);
      const appBgNightBlur = await store.get('backgroundImageNightBlurring', defaults.backgroundImageNightBlurring);
      const showHome = await store.get('showHome', defaults.showHome);
      const showDiscovery = await store.get('showDiscovery', defaults.showDiscovery);
      const showRss = await store.get('showRss', defaults.showRss);
      const defaultHomePage = await store.get('defaultHomePage', defaults.defaultHomePage);
      const mainNavigationOrder = await store.get('mainNavigationOrder', defaults.mainNavigationOrder);
      const labelVisibilityMode = await store.get('labelVisibilityMode', defaults.labelVisibilityMode);
      const predictiveBack = await store.get('predictiveBack', defaults.predictiveBack);
      const readerSharedElement = await store.get('readerSharedElement', defaults.readerSharedElement);
      const enableBlur = await store.get('enableBlur', defaults.enableBlur);
      const enableProgressiveBlur = await store.get('enableProgressiveBlur', defaults.enableProgressiveBlur);
      const useFlexibleTopAppBar = await store.get('useFlexibleTopAppBar', defaults.useFlexibleTopAppBar);
      const topBarButtonStyle = await store.get('topBarButtonStyle', defaults.topBarButtonStyle);
      const mergeTopBarActions = await store.get('mergeTopBarActions', defaults.mergeTopBarActions);
      const showBottomView = await store.get('showBottomView', defaults.showBottomView);
      const useFloatingBottomBar = await store.get('useFloatingBottomBar', defaults.useFloatingBottomBar);
      const useFloatingBottomBarLiquidGlass =
        await store.get('useFloatingBottomBarLiquidGlass', defaults.useFloatingBottomBarLiquidGlass);
      const bottomBarLensRadius = await store.get('bottomBarLensRadius', defaults.bottomBarLensRadius);
      const topBarBlurRadius = await store.get('topBarBlurRadius', defaults.topBarBlurRadius);
      const bottomBarBlurRadius = await store.get('bottomBarBlurRadius', defaults.bottomBarBlurRadius);
      const topBarBlurAlpha = await store.get('topBarBlurAlpha', defaults.topBarBlurAlpha);
      const bottomBarBlurAlpha = await store.get('bottomBarBlurAlpha', defaults.bottomBarBlurAlpha);
      const topBarOpacity = await store.get('topBarOpacity', defaults.topBarOpacity);
      const bottomBarOpacity = await store.get('bottomBarOpacity', defaults.bottomBarOpacity);
      const appFontPath = await store.get('appFontPath', defaults.appFontPath);
      const customThemeRaw = await store.get('customTheme', '');
      return {
        themeMode: typeof themeMode === 'string' ? ThemeSettingsRepository.normalizeThemeMode(themeMode) : defaults.themeMode,
        paletteIndex: typeof paletteIndex === 'number' ? Math.max(THEME_PALETTE_MIN, Math.min(THEME_PALETTE_MAX, paletteIndex)) : defaults.paletteIndex,
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
          ? itemDark : defaults.itemBackgroundImageDark,
        pureBlack: typeof pureBlack === 'boolean' ? pureBlack : defaults.pureBlack,
        backgroundImage: typeof appBgLight === 'string' ? appBgLight : defaults.backgroundImage,
        backgroundImageNight: typeof appBgDark === 'string' ? appBgDark : defaults.backgroundImageNight,
        backgroundImageBlurring: typeof appBgBlur === 'number'
          ? normalizeBackgroundBlur(appBgBlur) : defaults.backgroundImageBlurring,
        backgroundImageNightBlurring: typeof appBgNightBlur === 'number'
          ? normalizeBackgroundBlur(appBgNightBlur) : defaults.backgroundImageNightBlurring,
        showHome: typeof showHome === 'boolean' ? showHome : defaults.showHome,
        showDiscovery: typeof showDiscovery === 'boolean' ? showDiscovery : defaults.showDiscovery,
        showRss: typeof showRss === 'boolean' ? showRss : defaults.showRss,
        defaultHomePage: typeof defaultHomePage === 'string' && defaultHomePage.length > 0
          ? defaultHomePage : defaults.defaultHomePage,
        mainNavigationOrder: typeof mainNavigationOrder === 'string' && mainNavigationOrder.length > 0
          ? mainNavigationOrder : defaults.mainNavigationOrder,
        labelVisibilityMode: typeof labelVisibilityMode === 'string'
          ? normalizeLabelVisibility(labelVisibilityMode) : defaults.labelVisibilityMode,
        predictiveBack: typeof predictiveBack === 'boolean' ? predictiveBack : defaults.predictiveBack,
        readerSharedElement: typeof readerSharedElement === 'boolean'
          ? readerSharedElement : defaults.readerSharedElement,
        enableBlur: typeof enableBlur === 'boolean' ? enableBlur : defaults.enableBlur,
        enableProgressiveBlur: typeof enableProgressiveBlur === 'boolean'
          ? enableProgressiveBlur : defaults.enableProgressiveBlur,
        useFlexibleTopAppBar: typeof useFlexibleTopAppBar === 'boolean'
          ? useFlexibleTopAppBar : defaults.useFlexibleTopAppBar,
        topBarButtonStyle: typeof topBarButtonStyle === 'string'
          ? normalizeTopBarButtonStyle(topBarButtonStyle) : defaults.topBarButtonStyle,
        mergeTopBarActions: typeof mergeTopBarActions === 'boolean'
          ? mergeTopBarActions : defaults.mergeTopBarActions,
        showBottomView: typeof showBottomView === 'boolean' ? showBottomView : defaults.showBottomView,
        useFloatingBottomBar: typeof useFloatingBottomBar === 'boolean'
          ? useFloatingBottomBar : defaults.useFloatingBottomBar,
        useFloatingBottomBarLiquidGlass: typeof useFloatingBottomBarLiquidGlass === 'boolean'
          ? useFloatingBottomBarLiquidGlass : defaults.useFloatingBottomBarLiquidGlass,
        bottomBarLensRadius: normalizeBottomBarLensRadius(
          typeof bottomBarLensRadius === 'number' ? bottomBarLensRadius : defaults.bottomBarLensRadius),
        topBarBlurRadius: normalizeTopBarBlurRadius(
          typeof topBarBlurRadius === 'number' ? topBarBlurRadius : defaults.topBarBlurRadius),
        bottomBarBlurRadius: normalizeBottomBarBlurRadius(
          typeof bottomBarBlurRadius === 'number' ? bottomBarBlurRadius : defaults.bottomBarBlurRadius),
        topBarBlurAlpha: normalizeBarBlurAlpha(
          typeof topBarBlurAlpha === 'number' ? topBarBlurAlpha : defaults.topBarBlurAlpha,
          TOP_BAR_BLUR_ALPHA_DEFAULT),
        bottomBarBlurAlpha: normalizeBarBlurAlpha(
          typeof bottomBarBlurAlpha === 'number' ? bottomBarBlurAlpha : defaults.bottomBarBlurAlpha,
          BOTTOM_BAR_BLUR_ALPHA_DEFAULT),
        topBarOpacity: normalizeTopBarOpacity(
          typeof topBarOpacity === 'number' ? topBarOpacity : defaults.topBarOpacity),
        bottomBarOpacity: normalizeBottomBarOpacity(
          typeof bottomBarOpacity === 'number' ? bottomBarOpacity : defaults.bottomBarOpacity),
        appFontPath: normalizeAppFontPath(typeof appFontPath === 'string' ? appFontPath : defaults.appFontPath),
        customTheme: parseCustomThemeSnapshot(typeof customThemeRaw === 'string' ? customThemeRaw : '')
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
    await store.put('paletteIndex', Math.max(THEME_PALETTE_MIN, Math.min(THEME_PALETTE_MAX, snapshot.paletteIndex)));
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
    await store.put('pureBlack', snapshot.pureBlack);
    await store.put('backgroundImage', snapshot.backgroundImage);
    await store.put('backgroundImageNight', snapshot.backgroundImageNight);
    await store.put('backgroundImageBlurring', normalizeBackgroundBlur(snapshot.backgroundImageBlurring));
    await store.put('backgroundImageNightBlurring', normalizeBackgroundBlur(snapshot.backgroundImageNightBlurring));
    await store.put('showHome', snapshot.showHome);
    await store.put('showDiscovery', snapshot.showDiscovery);
    await store.put('showRss', snapshot.showRss);
    await store.put('defaultHomePage', snapshot.defaultHomePage);
    await store.put('mainNavigationOrder', snapshot.mainNavigationOrder);
    await store.put('labelVisibilityMode', normalizeLabelVisibility(snapshot.labelVisibilityMode));
    await store.put('predictiveBack', snapshot.predictiveBack);
    await store.put('readerSharedElement', snapshot.readerSharedElement);
    await store.put('enableBlur', snapshot.enableBlur);
    await store.put('enableProgressiveBlur', snapshot.enableProgressiveBlur);
    await store.put('useFlexibleTopAppBar', snapshot.useFlexibleTopAppBar);
    await store.put('topBarButtonStyle', normalizeTopBarButtonStyle(snapshot.topBarButtonStyle));
    await store.put('mergeTopBarActions', snapshot.mergeTopBarActions);
    await store.put('showBottomView', snapshot.showBottomView);
    await store.put('useFloatingBottomBar', snapshot.useFloatingBottomBar);
    await store.put('useFloatingBottomBarLiquidGlass', snapshot.useFloatingBottomBarLiquidGlass);
    await store.put('bottomBarLensRadius', normalizeBottomBarLensRadius(snapshot.bottomBarLensRadius));
    await store.put('topBarBlurRadius', normalizeTopBarBlurRadius(snapshot.topBarBlurRadius));
    await store.put('bottomBarBlurRadius', normalizeBottomBarBlurRadius(snapshot.bottomBarBlurRadius));
    await store.put('topBarBlurAlpha', normalizeBarBlurAlpha(snapshot.topBarBlurAlpha, TOP_BAR_BLUR_ALPHA_DEFAULT));
    await store.put('bottomBarBlurAlpha',
      normalizeBarBlurAlpha(snapshot.bottomBarBlurAlpha, BOTTOM_BAR_BLUR_ALPHA_DEFAULT));
    await store.put('topBarOpacity', normalizeTopBarOpacity(snapshot.topBarOpacity));
    await store.put('bottomBarOpacity', normalizeBottomBarOpacity(snapshot.bottomBarOpacity));
    await store.put('appFontPath', normalizeAppFontPath(snapshot.appFontPath));
    await store.put('customTheme', JSON.stringify(normalizeCustomThemeSnapshot(snapshot.customTheme)));
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
