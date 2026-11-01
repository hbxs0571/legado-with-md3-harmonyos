import { fileIo, picker } from '@kit.CoreFileKit';
import zlib from '@ohos.zlib';
import {
  CUSTOM_CONTRASTS, CUSTOM_MATERIAL_VERSIONS, CUSTOM_PALETTE_STYLES,
  CustomThemeSnapshot, normalizeCustomThemeSnapshot
} from './CustomThemeColors';
import { THEME_MODE_DARK, THEME_MODE_FOLLOW_SYSTEM, THEME_MODE_LIGHT, ThemeSnapshot } from './ThemeSettingsRepository';
import { THEME_PALETTE_MAX, THEME_PALETTE_MIN } from './ThemePalette';

/**
 * 主题包管理，对应上游 `help/config/ThemePackageManager.kt`（1254 行）。
 *
 * 上游把「当前主题设置」序列化成 `ThemeExportData`（约 110 个字段），资源文件
 * （背景图 / 导航图标 / 字体 / 封面图集）单独打包成 `assets/` 下的条目，清单写在
 * `manifest.json`（`formatVersion` + `name` + `config` + `assets` + `coverAlbums`）。
 *
 * 本地的能力边界：
 * - 颜色：上游是 ARGB Int（0 表示未设置），本地内部是 `#RRGGBB` 字符串；跨格式时
 *   按 `0xFFRRGGBB` ↔ `#RRGGBB` 互转，所以导出的 JSON 能被 Android 直接读，反之亦然。
 * - 资产：本地只有 6 张容器/全 App 背景图与 1 个应用字体；上游的 10 个导航图标与
 *   封面图集在本地没有对应功能（`grep navIcon|coverAlbum` 全仓 0 命中），所以导出时
 *   这两类条目**不产生**，导入时忽略并计数，不造假实现。
 */

/** 主题包格式版本，对齐上游 `ThemePackageManager.kt` 的 `FORMAT_VERSION`。 */
export const THEME_PACKAGE_FORMAT_VERSION: number = 1;
/** 清单文件名，对齐上游 `MANIFEST_PATH`。 */
export const THEME_MANIFEST_PATH: string = 'manifest.json';
/** 已存主题的根目录名，对齐上游 `SAVED_THEME_DIR`。 */
export const SAVED_THEME_DIR: string = 'saved_themes';
/** 单个主题包最多条目数，对齐上游 `MAX_ENTRY_COUNT`。 */
export const MAX_THEME_ENTRY_COUNT: number = 4096;
/** 单个条目最大字节数（64 MB），对齐上游 `MAX_ENTRY_BYTES`。 */
export const MAX_THEME_ENTRY_BYTES: number = 64 * 1024 * 1024;
/** 解包后总字节上限（512 MB），对齐上游 `MAX_TOTAL_BYTES`。 */
export const MAX_THEME_TOTAL_BYTES: number = 512 * 1024 * 1024;

/** 资产 key，逐条对齐上游 `ASSET_*` 常量。 */
export const ASSET_BACKGROUND_LIGHT: string = 'background.light';
export const ASSET_BACKGROUND_DARK: string = 'background.dark';
export const ASSET_CONTAINER_LARGE_LIGHT: string = 'container.large.light';
export const ASSET_CONTAINER_LARGE_DARK: string = 'container.large.dark';
export const ASSET_CONTAINER_ITEM_LIGHT: string = 'container.item.light';
export const ASSET_CONTAINER_ITEM_DARK: string = 'container.item.dark';
export const ASSET_FONT_APP: string = 'font.app';

/**
 * 主题包的便携配置，字段名逐条对齐上游 `domain/model/settings/ThemeExportData.kt`。
 *
 * 只保留本地有对应功能的字段；上游的 `launcherIcon`（切换图标，本地不适用）、
 * 10 个 `navIcon*`（本地无导航图标自定义）、封面相关 12 个字段（本地无封面图集）
 * 不写入，导入时也不会凭空造出来。
 */
export interface ThemePortableConfig {
  appTheme: string;
  themeMode: string;
  isPureBlack: boolean;
  paletteStyle: string;
  materialVersion: string;
  customContrast: string;
  enableDeepPersonalization: boolean;
  fontScale: number;
  isPredictiveBackEnabled: boolean;
  containerOpacity: number;
  overrideBaseCardCornerRadius: boolean;
  baseCardCornerRadius: number;
  overrideBaseCardBorder: boolean;
  baseCardBorderWidth: number;
  baseCardBorderColor: number;
  baseCardBorderColorNight: number;
  disableSplicedColumnGroupCornerRadius: boolean;
  enableItemDivider: boolean;
  itemDividerWidth: number;
  itemDividerLength: number;
  itemDividerColor: number;
  enableBlur: boolean;
  enableProgressiveBlur: boolean;
  topBarBlurRadius: number;
  bottomBarBlurRadius: number;
  topBarBlurAlpha: number;
  bottomBarBlurAlpha: number;
  bottomBarLensRadius: number;
  topBarOpacity: number;
  bottomBarOpacity: number;
  showHome: boolean;
  showDiscovery: boolean;
  showRss: boolean;
  showStatusBar: boolean;
  swipeAnimation: boolean;
  showBottomView: boolean;
  useFloatingBottomBar: boolean;
  useFloatingBottomBarLiquidGlass: boolean;
  labelVisibilityMode: string;
  defaultHomePage: string;
  mainNavigationOrder: string;
  useFlexibleTopAppBar: boolean;
  topBarButtonStyle: string;
  mergeTopBarActions: boolean;
  enableContainerBackgroundImage: boolean;
  bgImageBlurring: number;
  bgImageNBlurring: number;
  bookInfoFollowCoverColor: boolean;
  bookInfoNetworkCoverBackground: string;
  bookInfoDefaultCoverBackground: string;
  themeColor: number;
  secondaryThemeColor: number;
  primaryTextColor: number;
  secondaryTextColor: number;
  themeBackgroundColor: number;
  labelContainerColor: number;
  themeColorNight: number;
  secondaryThemeColorNight: number;
  primaryTextColorNight: number;
  secondaryTextColorNight: number;
  themeBackgroundColorNight: number;
  labelContainerColorNight: number;
  cPrimary: number;
  cNPrimary: number;
}

/** 主题包清单，对齐上游 `ThemePackageManifest`。 */
export interface ThemePackageManifest {
  formatVersion: number;
  name: string;
  config: ThemePortableConfig;
  assets: Record<string, string>;
}

/** 已存主题的列表项，对齐上游 `SavedTheme`（这里只带本地用得上的字段）。 */
export interface SavedThemeEntry {
  /** 目录名（`theme_<URL 编码后的名字>`），作为唯一标识。 */
  directoryName: string;
  /** 显示名，来自清单的 `name`。 */
  name: string;
  /** 清单里的配置，供列表画日/夜色点与「应用」。 */
  config: ThemePortableConfig;
  /** 资产 key → 目录内的绝对路径。 */
  assets: Record<string, string>;
  /** 目录绝对路径。 */
  rootPath: string;
}

/** 导入结果：配置 + 已经落到沙箱里的资产路径。 */
export interface ThemePackageImport {
  name: string;
  config: ThemePortableConfig;
  assets: Record<string, string>;
  /** 被忽略的上游资产数（导航图标 / 封面图集），用于给用户如实提示。 */
  ignoredAssetCount: number;
}

/** 旧版主题迁移结果，对齐上游 `LegacyThemeMigrationResult`。 */
export interface LegacyThemeMigrationResult {
  migratedCount: number;
  failedCount: number;
}

/** 一份「当前主题」的输入：设置快照 + 主题模式。 */
export interface ThemePackageSource {
  snapshot: ThemeSnapshot;
  themeMode: string;
}

/** 本地支持的资产条目：key → 设置快照里的路径字段 + 包内基础路径。 */
interface AssetSource {
  key: string;
  path: string;
  entryBase: string;
}

/** 空清单，用于兜底。 */
function emptyConfig(): ThemePortableConfig {
  return {
    appTheme: '0',
    themeMode: THEME_MODE_FOLLOW_SYSTEM,
    isPureBlack: false,
    paletteStyle: 'tonalSpot',
    materialVersion: 'material3',
    customContrast: 'Default',
    enableDeepPersonalization: false,
    fontScale: 10,
    isPredictiveBackEnabled: true,
    containerOpacity: 100,
    overrideBaseCardCornerRadius: false,
    baseCardCornerRadius: 16,
    overrideBaseCardBorder: false,
    baseCardBorderWidth: 1,
    baseCardBorderColor: 0,
    baseCardBorderColorNight: 0,
    disableSplicedColumnGroupCornerRadius: false,
    enableItemDivider: false,
    itemDividerWidth: 1,
    itemDividerLength: 80,
    itemDividerColor: 0,
    enableBlur: false,
    enableProgressiveBlur: false,
    topBarBlurRadius: 24,
    bottomBarBlurRadius: 8,
    topBarBlurAlpha: 73,
    bottomBarBlurAlpha: 40,
    bottomBarLensRadius: 24,
    topBarOpacity: 100,
    bottomBarOpacity: 100,
    showHome: true,
    showDiscovery: true,
    showRss: true,
    showStatusBar: true,
    swipeAnimation: true,
    showBottomView: true,
    useFloatingBottomBar: false,
    useFloatingBottomBarLiquidGlass: false,
    labelVisibilityMode: 'auto',
    defaultHomePage: 'bookshelf',
    mainNavigationOrder: 'home,bookshelf,explore,rss,my',
    useFlexibleTopAppBar: true,
    topBarButtonStyle: 'tonal',
    mergeTopBarActions: false,
    enableContainerBackgroundImage: false,
    bgImageBlurring: 0,
    bgImageNBlurring: 0,
    bookInfoFollowCoverColor: true,
    bookInfoNetworkCoverBackground: 'on',
    bookInfoDefaultCoverBackground: 'on',
    themeColor: 0,
    secondaryThemeColor: 0,
    primaryTextColor: 0,
    secondaryTextColor: 0,
    themeBackgroundColor: 0,
    labelContainerColor: 0,
    themeColorNight: 0,
    secondaryThemeColorNight: 0,
    primaryTextColorNight: 0,
    secondaryTextColorNight: 0,
    themeBackgroundColorNight: 0,
    labelContainerColorNight: 0,
    cPrimary: 0,
    cNPrimary: 0
  };
}

/** `#RRGGBB` / `#AARRGGBB` → ARGB Int；空串或非法一律 0（= 未设置，对齐上游 Int 0）。 */
export function colorToArgbInt(value: string): number {
  if (typeof value !== 'string') { return 0; }
  const trimmed = value.trim().toUpperCase();
  if (trimmed.length === 0) { return 0; }
  if (/^#[0-9A-F]{6}$/.test(trimmed)) {
    const rgb = Number.parseInt(trimmed.substring(1), 16);
    return (0xFF000000 + rgb) | 0;
  }
  if (/^#[0-9A-F]{8}$/.test(trimmed)) {
    const argb = Number.parseInt(trimmed.substring(1), 16);
    // 8 位本地存的是 #AARRGGBB，与 ARGB Int 位序一致，直接转。
    return argb | 0;
  }
  return 0;
}

/** ARGB Int → `#RRGGBB`；0 或全透明返回空串（对齐上游「未设置」）。 */
export function colorFromArgbInt(value: number): string {
  if (!Number.isFinite(value)) { return ''; }
  const argb = Math.trunc(value) >>> 0;
  if (argb === 0) { return ''; }
  const alpha = (argb >>> 24) & 0xFF;
  if (alpha === 0) { return ''; }
  const rgb = argb & 0xFFFFFF;
  const hex = rgb.toString(16).toUpperCase().padStart(6, '0');
  return `#${hex}`;
}

/** 主题模式归一，非法值回落「跟随系统」。 */
function normalizeMode(value: string): string {
  if (value === THEME_MODE_LIGHT || value === THEME_MODE_DARK) { return value; }
  return THEME_MODE_FOLLOW_SYSTEM;
}

/** 调色板序号归一，非法值回落 0（对齐 `normalizePaletteIndex`）。 */
function normalizePalette(value: number): number {
  if (!Number.isFinite(value)) { return 0; }
  const rounded = Math.trunc(value);
  if (rounded < THEME_PALETTE_MIN) { return THEME_PALETTE_MIN; }
  if (rounded > THEME_PALETTE_MAX) { return THEME_PALETTE_MAX; }
  return rounded;
}

/** 设置快照 → 便携配置。 */
export function toPortableConfig(source: ThemePackageSource): ThemePortableConfig {
  const snapshot = source.snapshot;
  const custom = normalizeCustomThemeSnapshot(snapshot.customTheme);
  const day = custom.day;
  const night = custom.night;
  const config = emptyConfig();
  config.appTheme = `${normalizePalette(snapshot.paletteIndex)}`;
  config.themeMode = normalizeMode(source.themeMode);
  config.isPureBlack = snapshot.pureBlack;
  config.paletteStyle = custom.paletteStyle;
  config.materialVersion = custom.materialVersion;
  config.customContrast = custom.customContrast;
  config.enableDeepPersonalization = custom.enableDeepPersonalization;
  config.fontScale = snapshot.fontScale;
  config.isPredictiveBackEnabled = snapshot.predictiveBack;
  config.containerOpacity = snapshot.containerOpacity;
  config.overrideBaseCardCornerRadius = snapshot.overrideBaseCardCornerRadius;
  config.baseCardCornerRadius = snapshot.baseCardCornerRadius;
  config.overrideBaseCardBorder = snapshot.overrideBaseCardBorder;
  config.baseCardBorderWidth = snapshot.baseCardBorderWidth;
  config.baseCardBorderColor = colorToArgbInt(snapshot.baseCardBorderColorDay);
  config.baseCardBorderColorNight = colorToArgbInt(snapshot.baseCardBorderColorNight);
  config.disableSplicedColumnGroupCornerRadius = snapshot.disableSplicedColumnGroupCornerRadius;
  config.enableItemDivider = snapshot.enableItemDivider;
  config.itemDividerWidth = snapshot.itemDividerWidth;
  config.itemDividerLength = snapshot.itemDividerLength;
  config.itemDividerColor = colorToArgbInt(snapshot.itemDividerColor);
  config.enableBlur = snapshot.enableBlur;
  config.enableProgressiveBlur = snapshot.enableProgressiveBlur;
  config.topBarBlurRadius = snapshot.topBarBlurRadius;
  config.bottomBarBlurRadius = snapshot.bottomBarBlurRadius;
  config.topBarBlurAlpha = snapshot.topBarBlurAlpha;
  config.bottomBarBlurAlpha = snapshot.bottomBarBlurAlpha;
  config.bottomBarLensRadius = snapshot.bottomBarLensRadius;
  config.topBarOpacity = snapshot.topBarOpacity;
  config.bottomBarOpacity = snapshot.bottomBarOpacity;
  config.showHome = snapshot.showHome;
  config.showDiscovery = snapshot.showDiscovery;
  config.showRss = snapshot.showRss;
  config.showStatusBar = snapshot.showStatusBar;
  config.swipeAnimation = snapshot.swipeAnimation;
  config.showBottomView = snapshot.showBottomView;
  config.useFloatingBottomBar = snapshot.useFloatingBottomBar;
  config.useFloatingBottomBarLiquidGlass = snapshot.useFloatingBottomBarLiquidGlass;
  config.labelVisibilityMode = snapshot.labelVisibilityMode;
  config.defaultHomePage = snapshot.defaultHomePage;
  config.mainNavigationOrder = snapshot.mainNavigationOrder;
  config.useFlexibleTopAppBar = snapshot.useFlexibleTopAppBar;
  config.topBarButtonStyle = snapshot.topBarButtonStyle;
  config.mergeTopBarActions = snapshot.mergeTopBarActions;
  config.enableContainerBackgroundImage = snapshot.enableContainerBackgroundImage;
  config.bgImageBlurring = snapshot.backgroundImageBlurring;
  config.bgImageNBlurring = snapshot.backgroundImageNightBlurring;
  config.bookInfoFollowCoverColor = snapshot.bookInfoFollowCoverColor;
  config.bookInfoNetworkCoverBackground = snapshot.bookInfoNetworkCoverBackground;
  config.bookInfoDefaultCoverBackground = snapshot.bookInfoDefaultCoverBackground;
  config.themeColor = colorToArgbInt(day.primary);
  config.secondaryThemeColor = colorToArgbInt(day.secondary);
  config.primaryTextColor = colorToArgbInt(day.primaryText);
  config.secondaryTextColor = colorToArgbInt(day.secondaryText);
  config.themeBackgroundColor = colorToArgbInt(day.background);
  config.labelContainerColor = colorToArgbInt(day.labelContainer);
  config.themeColorNight = colorToArgbInt(night.primary);
  config.secondaryThemeColorNight = colorToArgbInt(night.secondary);
  config.primaryTextColorNight = colorToArgbInt(night.primaryText);
  config.secondaryTextColorNight = colorToArgbInt(night.secondaryText);
  config.themeBackgroundColorNight = colorToArgbInt(night.background);
  config.labelContainerColorNight = colorToArgbInt(night.labelContainer);
  config.cPrimary = colorToArgbInt(custom.seedColorDay);
  config.cNPrimary = colorToArgbInt(custom.seedColorNight);
  return config;
}

/** 便携配置 → 设置快照的补丁（只覆盖主题相关字段，其余保持原值）。 */
export interface ThemeConfigPatch {
  paletteIndex: number;
  themeMode: string;
  pureBlack: boolean;
  fontScale: number;
  predictiveBack: boolean;
  containerOpacity: number;
  overrideBaseCardCornerRadius: boolean;
  baseCardCornerRadius: number;
  overrideBaseCardBorder: boolean;
  baseCardBorderWidth: number;
  baseCardBorderColorDay: string;
  baseCardBorderColorNight: string;
  disableSplicedColumnGroupCornerRadius: boolean;
  enableItemDivider: boolean;
  itemDividerWidth: number;
  itemDividerLength: number;
  itemDividerColor: string;
  enableBlur: boolean;
  enableProgressiveBlur: boolean;
  topBarBlurRadius: number;
  bottomBarBlurRadius: number;
  topBarBlurAlpha: number;
  bottomBarBlurAlpha: number;
  bottomBarLensRadius: number;
  topBarOpacity: number;
  bottomBarOpacity: number;
  showHome: boolean;
  showDiscovery: boolean;
  showRss: boolean;
  showStatusBar: boolean;
  swipeAnimation: boolean;
  showBottomView: boolean;
  useFloatingBottomBar: boolean;
  useFloatingBottomBarLiquidGlass: boolean;
  labelVisibilityMode: string;
  defaultHomePage: string;
  mainNavigationOrder: string;
  useFlexibleTopAppBar: boolean;
  topBarButtonStyle: string;
  mergeTopBarActions: boolean;
  enableContainerBackgroundImage: boolean;
  backgroundImageBlurring: number;
  backgroundImageNightBlurring: number;
  bookInfoFollowCoverColor: boolean;
  bookInfoNetworkCoverBackground: string;
  bookInfoDefaultCoverBackground: string;
  customTheme: CustomThemeSnapshot;
}

/** 便携配置 → 补丁。缺失字段按上游默认值补齐，不信任外部 JSON。 */
export function fromPortableConfig(config: ThemePortableConfig): ThemeConfigPatch {
  const base = emptyConfig();
  const pick = (value: ThemePortableConfig, fallback: ThemePortableConfig): ThemePortableConfig => {
    // 这里只做「补齐」不做校验：真正的类型兜底在 parsePortableConfig 里做，
    // 走到这里时 config 已经是干净对象。
    return value === null || value === undefined ? fallback : value;
  };
  const source = pick(config, base);
  const custom: CustomThemeSnapshot = normalizeCustomThemeSnapshot({
    enableDeepPersonalization: source.enableDeepPersonalization === true,
    paletteStyle: source.paletteStyle,
    customContrast: source.customContrast,
    materialVersion: source.materialVersion,
    seedColorDay: colorFromArgbInt(source.cPrimary),
    seedColorNight: colorFromArgbInt(source.cNPrimary),
    day: {
      primary: colorFromArgbInt(source.themeColor),
      secondary: colorFromArgbInt(source.secondaryThemeColor),
      primaryText: colorFromArgbInt(source.primaryTextColor),
      secondaryText: colorFromArgbInt(source.secondaryTextColor),
      background: colorFromArgbInt(source.themeBackgroundColor),
      labelContainer: colorFromArgbInt(source.labelContainerColor)
    },
    night: {
      primary: colorFromArgbInt(source.themeColorNight),
      secondary: colorFromArgbInt(source.secondaryThemeColorNight),
      primaryText: colorFromArgbInt(source.primaryTextColorNight),
      secondaryText: colorFromArgbInt(source.secondaryTextColorNight),
      background: colorFromArgbInt(source.themeBackgroundColorNight),
      labelContainer: colorFromArgbInt(source.labelContainerColorNight)
    }
  });
  const paletteIndex = Number.parseInt(source.appTheme, 10);
  return {
    paletteIndex: normalizePalette(Number.isFinite(paletteIndex) ? paletteIndex : 0),
    themeMode: normalizeMode(source.themeMode),
    pureBlack: source.isPureBlack === true,
    fontScale: source.fontScale,
    predictiveBack: source.isPredictiveBackEnabled !== false,
    containerOpacity: source.containerOpacity,
    overrideBaseCardCornerRadius: source.overrideBaseCardCornerRadius === true,
    baseCardCornerRadius: source.baseCardCornerRadius,
    overrideBaseCardBorder: source.overrideBaseCardBorder === true,
    baseCardBorderWidth: source.baseCardBorderWidth,
    baseCardBorderColorDay: colorFromArgbInt(source.baseCardBorderColor),
    baseCardBorderColorNight: colorFromArgbInt(source.baseCardBorderColorNight),
    disableSplicedColumnGroupCornerRadius: source.disableSplicedColumnGroupCornerRadius === true,
    enableItemDivider: source.enableItemDivider === true,
    itemDividerWidth: source.itemDividerWidth,
    itemDividerLength: source.itemDividerLength,
    itemDividerColor: colorFromArgbInt(source.itemDividerColor),
    enableBlur: source.enableBlur === true,
    enableProgressiveBlur: source.enableProgressiveBlur === true,
    topBarBlurRadius: source.topBarBlurRadius,
    bottomBarBlurRadius: source.bottomBarBlurRadius,
    topBarBlurAlpha: source.topBarBlurAlpha,
    bottomBarBlurAlpha: source.bottomBarBlurAlpha,
    bottomBarLensRadius: source.bottomBarLensRadius,
    topBarOpacity: source.topBarOpacity,
    bottomBarOpacity: source.bottomBarOpacity,
    showHome: source.showHome !== false,
    showDiscovery: source.showDiscovery !== false,
    showRss: source.showRss !== false,
    showStatusBar: source.showStatusBar !== false,
    swipeAnimation: source.swipeAnimation !== false,
    showBottomView: source.showBottomView !== false,
    useFloatingBottomBar: source.useFloatingBottomBar === true,
    useFloatingBottomBarLiquidGlass: source.useFloatingBottomBarLiquidGlass === true,
    labelVisibilityMode: source.labelVisibilityMode,
    defaultHomePage: source.defaultHomePage,
    mainNavigationOrder: source.mainNavigationOrder,
    useFlexibleTopAppBar: source.useFlexibleTopAppBar !== false,
    topBarButtonStyle: source.topBarButtonStyle,
    mergeTopBarActions: source.mergeTopBarActions === true,
    enableContainerBackgroundImage: source.enableContainerBackgroundImage === true,
    backgroundImageBlurring: source.bgImageBlurring,
    backgroundImageNightBlurring: source.bgImageNBlurring,
    bookInfoFollowCoverColor: source.bookInfoFollowCoverColor !== false,
    bookInfoNetworkCoverBackground: source.bookInfoNetworkCoverBackground,
    bookInfoDefaultCoverBackground: source.bookInfoDefaultCoverBackground,
    customTheme: custom
  };
}

/** 从任意 JSON 文本解析便携配置，逐字段做类型兜底；解析失败返回 undefined。 */
export function parsePortableConfig(raw: string): ThemePortableConfig | undefined {
  if (raw.length === 0) { return undefined; }
  let parsed: Record<string, Object>;
  try {
    const value = JSON.parse(raw) as Record<string, Object>;
    if (value === null || typeof value !== 'object') { return undefined; }
    parsed = value;
  } catch (_) {
    return undefined;
  }
  const base = emptyConfig();
  const readString = (key: string, fallback: string): string => {
    const value = parsed[key];
    return typeof value === 'string' ? value : fallback;
  };
  const readNumber = (key: string, fallback: number): number => {
    const value = parsed[key];
    return typeof value === 'number' && Number.isFinite(value) ? value : fallback;
  };
  const readBoolean = (key: string, fallback: boolean): boolean => {
    const value = parsed[key];
    return typeof value === 'boolean' ? value : fallback;
  };
  return {
    appTheme: readString('appTheme', base.appTheme),
    themeMode: readString('themeMode', base.themeMode),
    isPureBlack: readBoolean('isPureBlack', base.isPureBlack),
    paletteStyle: readString('paletteStyle', base.paletteStyle),
    materialVersion: readString('materialVersion', base.materialVersion),
    customContrast: readString('customContrast', base.customContrast),
    enableDeepPersonalization: readBoolean('enableDeepPersonalization', base.enableDeepPersonalization),
    fontScale: readNumber('fontScale', base.fontScale),
    isPredictiveBackEnabled: readBoolean('isPredictiveBackEnabled', base.isPredictiveBackEnabled),
    containerOpacity: readNumber('containerOpacity', base.containerOpacity),
    overrideBaseCardCornerRadius: readBoolean('overrideBaseCardCornerRadius', base.overrideBaseCardCornerRadius),
    baseCardCornerRadius: readNumber('baseCardCornerRadius', base.baseCardCornerRadius),
    overrideBaseCardBorder: readBoolean('overrideBaseCardBorder', base.overrideBaseCardBorder),
    baseCardBorderWidth: readNumber('baseCardBorderWidth', base.baseCardBorderWidth),
    baseCardBorderColor: readNumber('baseCardBorderColor', base.baseCardBorderColor),
    baseCardBorderColorNight: readNumber('baseCardBorderColorNight', base.baseCardBorderColorNight),
    disableSplicedColumnGroupCornerRadius: readBoolean('disableSplicedColumnGroupCornerRadius',
      base.disableSplicedColumnGroupCornerRadius),
    enableItemDivider: readBoolean('enableItemDivider', base.enableItemDivider),
    itemDividerWidth: readNumber('itemDividerWidth', base.itemDividerWidth),
    itemDividerLength: readNumber('itemDividerLength', base.itemDividerLength),
    itemDividerColor: readNumber('itemDividerColor', base.itemDividerColor),
    enableBlur: readBoolean('enableBlur', base.enableBlur),
    enableProgressiveBlur: readBoolean('enableProgressiveBlur', base.enableProgressiveBlur),
    topBarBlurRadius: readNumber('topBarBlurRadius', base.topBarBlurRadius),
    bottomBarBlurRadius: readNumber('bottomBarBlurRadius', base.bottomBarBlurRadius),
    topBarBlurAlpha: readNumber('topBarBlurAlpha', base.topBarBlurAlpha),
    bottomBarBlurAlpha: readNumber('bottomBarBlurAlpha', base.bottomBarBlurAlpha),
    bottomBarLensRadius: readNumber('bottomBarLensRadius', base.bottomBarLensRadius),
    topBarOpacity: readNumber('topBarOpacity', base.topBarOpacity),
    bottomBarOpacity: readNumber('bottomBarOpacity', base.bottomBarOpacity),
    showHome: readBoolean('showHome', base.showHome),
    showDiscovery: readBoolean('showDiscovery', base.showDiscovery),
    showRss: readBoolean('showRss', base.showRss),
    showStatusBar: readBoolean('showStatusBar', base.showStatusBar),
    swipeAnimation: readBoolean('swipeAnimation', base.swipeAnimation),
    showBottomView: readBoolean('showBottomView', base.showBottomView),
    useFloatingBottomBar: readBoolean('useFloatingBottomBar', base.useFloatingBottomBar),
    useFloatingBottomBarLiquidGlass: readBoolean('useFloatingBottomBarLiquidGlass',
      base.useFloatingBottomBarLiquidGlass),
    labelVisibilityMode: readString('labelVisibilityMode', base.labelVisibilityMode),
    defaultHomePage: readString('defaultHomePage', base.defaultHomePage),
    mainNavigationOrder: readString('mainNavigationOrder', base.mainNavigationOrder),
    useFlexibleTopAppBar: readBoolean('useFlexibleTopAppBar', base.useFlexibleTopAppBar),
    topBarButtonStyle: readString('topBarButtonStyle', base.topBarButtonStyle),
    mergeTopBarActions: readBoolean('mergeTopBarActions', base.mergeTopBarActions),
    enableContainerBackgroundImage: readBoolean('enableContainerBackgroundImage',
      base.enableContainerBackgroundImage),
    bgImageBlurring: readNumber('bgImageBlurring', base.bgImageBlurring),
    bgImageNBlurring: readNumber('bgImageNBlurring', base.bgImageNBlurring),
    bookInfoFollowCoverColor: readBoolean('bookInfoFollowCoverColor', base.bookInfoFollowCoverColor),
    bookInfoNetworkCoverBackground: readString('bookInfoNetworkCoverBackground',
      base.bookInfoNetworkCoverBackground),
    bookInfoDefaultCoverBackground: readString('bookInfoDefaultCoverBackground',
      base.bookInfoDefaultCoverBackground),
    themeColor: readNumber('themeColor', base.themeColor),
    secondaryThemeColor: readNumber('secondaryThemeColor', base.secondaryThemeColor),
    primaryTextColor: readNumber('primaryTextColor', base.primaryTextColor),
    secondaryTextColor: readNumber('secondaryTextColor', base.secondaryTextColor),
    themeBackgroundColor: readNumber('themeBackgroundColor', base.themeBackgroundColor),
    labelContainerColor: readNumber('labelContainerColor', base.labelContainerColor),
    themeColorNight: readNumber('themeColorNight', base.themeColorNight),
    secondaryThemeColorNight: readNumber('secondaryThemeColorNight', base.secondaryThemeColorNight),
    primaryTextColorNight: readNumber('primaryTextColorNight', base.primaryTextColorNight),
    secondaryTextColorNight: readNumber('secondaryTextColorNight', base.secondaryTextColorNight),
    themeBackgroundColorNight: readNumber('themeBackgroundColorNight', base.themeBackgroundColorNight),
    labelContainerColorNight: readNumber('labelContainerColorNight', base.labelContainerColorNight),
    cPrimary: readNumber('cPrimary', base.cPrimary),
    cNPrimary: readNumber('cNPrimary', base.cNPrimary)
  };
}

/** 已存主题目录名：`theme_` + URL 编码后的名字，对齐上游 `savedThemeDir`。 */
export function savedThemeDirectoryName(name: string): string {
  const trimmed = name.trim();
  if (trimmed.length === 0) { return 'theme_theme'; }
  return `theme_${encodeURIComponent(trimmed)}`;
}

/** 目录名还原显示名（清单缺失时的兜底）。 */
export function savedThemeDisplayName(directoryName: string): string {
  const raw = directoryName.startsWith('theme_') ? directoryName.substring(6) : directoryName;
  try {
    return decodeURIComponent(raw);
  } catch (_) {
    return raw;
  }
}

/** 取扩展名（带点，小写）；没有扩展名时用 fallback。 */
function fileExtension(path: string, fallback: string): string {
  const dot = path.lastIndexOf('.');
  if (dot < 0 || dot < path.lastIndexOf('/')) { return fallback; }
  const suffix = path.substring(dot).toLowerCase();
  if (suffix.length <= 1 || suffix.length > 6) { return fallback; }
  return suffix;
}

/** 写文本文件（覆盖），写完立刻关 fd，避免句柄泄漏。 */
function writeTextFile(path: string, content: string): void {
  const file = fileIo.openSync(path,
    fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC);
  try {
    fileIo.writeSync(file.fd, content);
  } finally {
    fileIo.closeSync(file);
  }
}

/** 递归删除目录（不存在时静默）。 */
function removeDirectory(path: string): void {
  if (!fileIo.accessSync(path)) { return; }
  const names = fileIo.listFileSync(path);
  for (let index = 0; index < names.length; index++) {
    const child = `${path}/${names[index]}`;
    const stat = fileIo.statSync(child);
    if (stat.isDirectory()) {
      removeDirectory(child);
    } else {
      fileIo.unlinkSync(child);
    }
  }
  fileIo.rmdirSync(path);
}

/** 递归收集目录下的相对路径（升序，保证打包顺序稳定）。 */
function collectFiles(root: string, prefix: string, out: string[]): void {
  const names = fileIo.listFileSync(root).sort();
  for (let index = 0; index < names.length; index++) {
    const name = names[index];
    const child = `${root}/${name}`;
    const relative = prefix.length === 0 ? name : `${prefix}/${name}`;
    const stat = fileIo.statSync(child);
    if (stat.isDirectory()) {
      collectFiles(child, relative, out);
    } else {
      out.push(relative);
    }
  }
}

/**
 * 主题包仓库。
 *
 * 目录结构对齐上游 `saved_themes`：每个已存主题一个 `theme_<编码名>/` 目录，
 * 内含 `manifest.json` 与 `assets/…`；导出时把整个目录打成 zip。
 */
export class ThemePackageRepository {
  /** 已存主题根目录。 */
  private static rootDirectory(context: Context): string {
    const root = `${context.filesDir}/${SAVED_THEME_DIR}`;
    if (!fileIo.accessSync(root)) { fileIo.mkdirSync(root, true); }
    return root;
  }

  /** 缓存目录（导入解包 / 导出打包的临时区）。 */
  private static workDirectory(context: Context): string {
    const root = `${context.cacheDir}/theme-package-work`;
    if (!fileIo.accessSync(root)) { fileIo.mkdirSync(root, true); }
    return root;
  }

  /** 当前设置里的资产条目（6 张背景图 + 1 个字体），对齐上游 `assetSources`。 */
  private static assetSources(snapshot: ThemeSnapshot): AssetSource[] {
    return [
      { key: ASSET_BACKGROUND_LIGHT, path: snapshot.backgroundImage, entryBase: 'assets/background/light' },
      { key: ASSET_BACKGROUND_DARK, path: snapshot.backgroundImageNight, entryBase: 'assets/background/dark' },
      {
        key: ASSET_CONTAINER_LARGE_LIGHT, path: snapshot.largeContainerBackgroundImageLight,
        entryBase: 'assets/container/large/light'
      },
      {
        key: ASSET_CONTAINER_LARGE_DARK, path: snapshot.largeContainerBackgroundImageDark,
        entryBase: 'assets/container/large/dark'
      },
      {
        key: ASSET_CONTAINER_ITEM_LIGHT, path: snapshot.itemBackgroundImageLight,
        entryBase: 'assets/container/item/light'
      },
      {
        key: ASSET_CONTAINER_ITEM_DARK, path: snapshot.itemBackgroundImageDark,
        entryBase: 'assets/container/item/dark'
      },
      { key: ASSET_FONT_APP, path: snapshot.appFontPath, entryBase: 'assets/font/app' }
    ];
  }

  /** 清单里的 `assets` 为空对象。 */
  private static emptyAssets(): Record<string, string> {
    return {};
  }

  /** 把资产文件复制进目标目录，返回 key → 目录内相对路径。 */
  private static copyAssetsInto(
    snapshot: ThemeSnapshot, targetRoot: string, relative: boolean
  ): Record<string, string> {
    const assets = ThemePackageRepository.emptyAssets();
    const sources = ThemePackageRepository.assetSources(snapshot);
    for (let index = 0; index < sources.length; index++) {
      const source = sources[index];
      if (source.path.length === 0 || !fileIo.accessSync(source.path)) { continue; }
      const entry = `${source.entryBase}${fileExtension(source.path, '.bin')}`;
      const destination = `${targetRoot}/${entry}`;
      const parent = destination.substring(0, destination.lastIndexOf('/'));
      if (!fileIo.accessSync(parent)) { fileIo.mkdirSync(parent, true); }
      fileIo.copyFileSync(source.path, destination);
      assets[source.key] = relative ? entry : destination;
    }
    return assets;
  }

  /** 清单里的资产相对路径 → 沙箱绝对路径（用于「应用」）。 */
  private static resolveAssetPaths(rootPath: string, assets: Record<string, string>): Record<string, string> {
    const resolved = ThemePackageRepository.emptyAssets();
    const keys = Object.keys(assets);
    for (let index = 0; index < keys.length; index++) {
      const key = keys[index];
      const relative = assets[key];
      if (typeof relative !== 'string' || relative.length === 0) { continue; }
      const absolute = `${rootPath}/${relative}`;
      if (fileIo.accessSync(absolute)) { resolved[key] = absolute; }
    }
    return resolved;
  }

  /** 生成清单文本。 */
  private static manifestText(name: string, config: ThemePortableConfig,
    assets: Record<string, string>): string {
    const manifest: ThemePackageManifest = {
      formatVersion: THEME_PACKAGE_FORMAT_VERSION,
      name: name,
      config: config,
      assets: assets
    };
    return JSON.stringify(manifest);
  }

  /** 读清单；缺失或坏 JSON 返回 undefined。 */
  private static readManifest(rootPath: string): ThemePackageManifest | undefined {
    const path = `${rootPath}/${THEME_MANIFEST_PATH}`;
    if (!fileIo.accessSync(path)) { return undefined; }
    const raw = fileIo.readTextSync(path);
    if (raw.length === 0) { return undefined; }
    let parsed: Record<string, Object>;
    try {
      const value = JSON.parse(raw) as Record<string, Object>;
      if (value === null || typeof value !== 'object') { return undefined; }
      parsed = value;
    } catch (_) {
      return undefined;
    }
    const configValue = parsed['config'];
    const config = typeof configValue === 'object' && configValue !== null
      ? parsePortableConfig(JSON.stringify(configValue)) : undefined;
    if (config === undefined) { return undefined; }
    const formatValue = parsed['formatVersion'];
    const formatVersion = typeof formatValue === 'number' ? formatValue : 0;
    const nameValue = parsed['name'];
    const name = typeof nameValue === 'string' ? nameValue : '';
    const assetsValue = parsed['assets'];
    const assets = ThemePackageRepository.emptyAssets();
    if (typeof assetsValue === 'object' && assetsValue !== null) {
      const record = assetsValue as Record<string, Object>;
      const keys = Object.keys(record);
      for (let index = 0; index < keys.length; index++) {
        const key = keys[index];
        const value = record[key];
        if (typeof value === 'string') { assets[key] = value; }
      }
    }
    return { formatVersion: formatVersion, name: name, config: config, assets: assets };
  }

  /** 已存主题列表（按名字升序）。 */
  static loadSavedThemes(context: Context): SavedThemeEntry[] {
    const root = ThemePackageRepository.rootDirectory(context);
    const names = fileIo.listFileSync(root).sort();
    const result: SavedThemeEntry[] = [];
    for (let index = 0; index < names.length; index++) {
      const directoryName = names[index];
      if (!directoryName.startsWith('theme_')) { continue; }
      const rootPath = `${root}/${directoryName}`;
      const stat = fileIo.statSync(rootPath);
      if (!stat.isDirectory()) { continue; }
      const manifest = ThemePackageRepository.readManifest(rootPath);
      if (manifest === undefined) { continue; }
      result.push({
        directoryName: directoryName,
        name: manifest.name.length > 0 ? manifest.name : savedThemeDisplayName(directoryName),
        config: manifest.config,
        assets: ThemePackageRepository.resolveAssetPaths(rootPath, manifest.assets),
        rootPath: rootPath
      });
    }
    return result;
  }

  /** 已存主题里是否存在同名（去重比较用）。 */
  static savedThemeExists(context: Context, name: string): boolean {
    const target = `${ThemePackageRepository.rootDirectory(context)}/${savedThemeDirectoryName(name)}`;
    return fileIo.accessSync(target);
  }

  /**
   * 保存当前配置为主题，对齐上游 `saveTheme` → `saveThemeFolder`。
   *
   * 先写 `theme_<名>_<时间>.tmp` 临时目录，写完再整体替换目标目录，
   * 避免中途失败留下半个主题。
   */
  static saveTheme(context: Context, name: string, source: ThemePackageSource): void {
    const root = ThemePackageRepository.rootDirectory(context);
    const directoryName = savedThemeDirectoryName(name);
    const target = `${root}/${directoryName}`;
    const temporary = `${root}/${directoryName}_${Date.now()}.tmp`;
    if (fileIo.accessSync(temporary)) { removeDirectory(temporary); }
    fileIo.mkdirSync(temporary, true);
    try {
      const assets = ThemePackageRepository.copyAssetsInto(source.snapshot, temporary, true);
      const config = toPortableConfig(source);
      writeTextFile(`${temporary}/${THEME_MANIFEST_PATH}`,
        ThemePackageRepository.manifestText(name.trim(), config, assets));
      if (fileIo.accessSync(target)) { removeDirectory(target); }
      fileIo.renameSync(temporary, target);
      // 上游 `saveThemeFolder` 末尾会删掉同名的旧版 `.json`，本地同样处理。
      const legacy = `${root}/${directoryName}.json`;
      if (fileIo.accessSync(legacy)) { fileIo.unlinkSync(legacy); }
    } catch (error) {
      if (fileIo.accessSync(temporary)) { removeDirectory(temporary); }
      throw error as Error;
    }
  }

  /** 删除已存主题，对齐上游 `deleteSavedTheme`。 */
  static deleteSavedTheme(context: Context, directoryName: string): void {
    const target = `${ThemePackageRepository.rootDirectory(context)}/${directoryName}`;
    if (!fileIo.accessSync(target)) { return; }
    removeDirectory(target);
  }

  /**
   * 重命名已存主题：改清单里的 `name`，目录名跟着变。
   *
   * 上游 `EditThemeSheet` 的改名走 `saveTheme(newName)` 再删旧目录；这里同样按
   * 「写新目录 → 删旧目录」做，保证中途失败时旧主题还在。
   */
  static renameSavedTheme(context: Context, directoryName: string, nextName: string): void {
    const root = ThemePackageRepository.rootDirectory(context);
    const sourceRoot = `${root}/${directoryName}`;
    const manifest = ThemePackageRepository.readManifest(sourceRoot);
    if (manifest === undefined) { throw new Error('主题目录已损坏，无法重命名'); }
    const trimmed = nextName.trim();
    if (trimmed.length === 0) { throw new Error('主题名称不能为空'); }
    const nextDirectory = savedThemeDirectoryName(trimmed);
    if (nextDirectory === directoryName) {
      writeTextFile(`${sourceRoot}/${THEME_MANIFEST_PATH}`,
        ThemePackageRepository.manifestText(trimmed, manifest.config, manifest.assets));
      return;
    }
    const targetRoot = `${root}/${nextDirectory}`;
    const temporary = `${root}/${nextDirectory}_${Date.now()}.tmp`;
    if (fileIo.accessSync(temporary)) { removeDirectory(temporary); }
    fileIo.mkdirSync(temporary, true);
    try {
      const relative: string[] = [];
      collectFiles(sourceRoot, '', relative);
      for (let index = 0; index < relative.length; index++) {
        const entry = relative[index];
        if (entry === THEME_MANIFEST_PATH) { continue; }
        const destination = `${temporary}/${entry}`;
        const parent = destination.substring(0, destination.lastIndexOf('/'));
        if (!fileIo.accessSync(parent)) { fileIo.mkdirSync(parent, true); }
        fileIo.copyFileSync(`${sourceRoot}/${entry}`, destination);
      }
      writeTextFile(`${temporary}/${THEME_MANIFEST_PATH}`,
        ThemePackageRepository.manifestText(trimmed, manifest.config, manifest.assets));
      if (fileIo.accessSync(targetRoot)) { removeDirectory(targetRoot); }
      fileIo.renameSync(temporary, targetRoot);
      removeDirectory(sourceRoot);
    } catch (error) {
      if (fileIo.accessSync(temporary)) { removeDirectory(temporary); }
      throw error as Error;
    }
  }

  /** 读一个已存主题的配置与资产路径，供「应用」使用。 */
  static readSavedTheme(context: Context, directoryName: string): ThemePackageImport | undefined {
    const rootPath = `${ThemePackageRepository.rootDirectory(context)}/${directoryName}`;
    const manifest = ThemePackageRepository.readManifest(rootPath);
    if (manifest === undefined) { return undefined; }
    return {
      name: manifest.name.length > 0 ? manifest.name : savedThemeDisplayName(directoryName),
      config: manifest.config,
      assets: ThemePackageRepository.resolveAssetPaths(rootPath, manifest.assets),
      ignoredAssetCount: 0
    };
  }

  /** 把目录打成 zip 并让用户选保存位置，返回是否保存成功。 */
  private static async saveZipToUser(context: Context, directory: string,
    suggestedName: string): Promise<boolean> {
    const work = ThemePackageRepository.workDirectory(context);
    const zipPath = `${work}/${suggestedName.replace(/[\\/:*?"<>|]/g, '_')}.zip`;
    if (fileIo.accessSync(zipPath)) { fileIo.unlinkSync(zipPath); }
    const relative: string[] = [];
    collectFiles(directory, '', relative);
    if (relative.length === 0 || relative.length > MAX_THEME_ENTRY_COUNT) {
      throw new Error('主题包里没有可导出的条目或条目数量过多');
    }
    // 用 compressFile 压整个目录（保留 assets/… 的相对层级）；compressFiles 会把
    // 每个文件平铺到 zip 根，同名资产（如两张 light.jpg）会互相覆盖。
    await zlib.compressFile(directory, zipPath, {});
    try {
      const options = new picker.DocumentSaveOptions();
      options.newFileNames = [`${suggestedName.replace(/[\\/:*?"<>|]/g, '_')}.zip`];
      options.fileSuffixChoices = ['Legado 主题包|.zip'];
      const uris = await new picker.DocumentViewPicker(context).save(options);
      const uri = uris[0];
      if (uri === undefined) { return false; }
      const input = fileIo.openSync(zipPath, fileIo.OpenMode.READ_ONLY);
      try {
        const output = fileIo.openSync(uri, fileIo.OpenMode.WRITE_ONLY | fileIo.OpenMode.TRUNC);
        try {
          fileIo.copyFileSync(input.fd, output.fd);
        } finally {
          fileIo.closeSync(output);
        }
      } finally {
        fileIo.closeSync(input);
      }
      return true;
    } finally {
      if (fileIo.accessSync(zipPath)) { fileIo.unlinkSync(zipPath); }
    }
  }

  /** 导出当前主题为 zip，对齐上游 `exportPackage`（走 `exportAssets` 分支）。 */
  static async exportCurrentTheme(context: Context, name: string,
    source: ThemePackageSource): Promise<boolean> {
    const work = ThemePackageRepository.workDirectory(context);
    const staging = `${work}/export-${Date.now()}`;
    fileIo.mkdirSync(staging, true);
    try {
      const assets = ThemePackageRepository.copyAssetsInto(source.snapshot, staging, true);
      const config = toPortableConfig(source);
      writeTextFile(`${staging}/${THEME_MANIFEST_PATH}`,
        ThemePackageRepository.manifestText(name.trim(), config, assets));
      return await ThemePackageRepository.saveZipToUser(context, staging,
        name.trim().length > 0 ? name.trim() : 'theme');
    } finally {
      if (fileIo.accessSync(staging)) { removeDirectory(staging); }
    }
  }

  /** 导出已存主题，对齐上游 `exportSavedThemeFolder`（整目录打包）。 */
  static async exportSavedTheme(context: Context, entry: SavedThemeEntry): Promise<boolean> {
    return ThemePackageRepository.saveZipToUser(context, entry.rootPath, entry.name);
  }

  /** 校验解包目录里的条目数与体积，对齐上游 `extractPackage` 的限额检查。 */
  private static validateExtracted(root: string): void {
    const relative: string[] = [];
    collectFiles(root, '', relative);
    if (relative.length > MAX_THEME_ENTRY_COUNT) {
      throw new Error('主题包条目数超过上限');
    }
    let total: number = 0;
    for (let index = 0; index < relative.length; index++) {
      const entry = relative[index];
      // 防路径穿越：上游 `resolvePackageFile` 用 canonicalFile 比对，这里直接拒绝可疑路径。
      if (entry.startsWith('/') || entry.includes('\\') || entry.split('/').includes('..')
        || entry.split('/').includes('.')) {
        throw new Error('主题包内含有非法路径');
      }
      const stat = fileIo.statSync(`${root}/${entry}`);
      if (stat.size > MAX_THEME_ENTRY_BYTES) { throw new Error('主题包内单个文件超过 64 MB'); }
      total += stat.size;
      if (total > MAX_THEME_TOTAL_BYTES) { throw new Error('主题包解压后超过 512 MB'); }
    }
  }

  /** 把包内资产复制到私有目录，返回 key → 沙箱绝对路径。 */
  private static importAssetsInto(context: Context, extracted: string,
    assets: Record<string, string>): Record<string, string> {
    const directory = `${context.filesDir}/theme-package-assets/${Date.now()}`;
    const imported = ThemePackageRepository.emptyAssets();
    let created: boolean = false;
    const keys = Object.keys(assets);
    for (let index = 0; index < keys.length; index++) {
      const key = keys[index];
      const relative = assets[key];
      if (typeof relative !== 'string' || relative.length === 0) { continue; }
      const source = `${extracted}/${relative}`;
      if (!fileIo.accessSync(source)) { continue; }
      if (!created) {
        fileIo.mkdirSync(directory, true);
        created = true;
      }
      const target = `${directory}/${key.replace(/[^A-Za-z0-9]+/g, '-')}${fileExtension(source, '.bin')}`;
      fileIo.copyFileSync(source, target);
      imported[key] = target;
    }
    return imported;
  }

  /** 导入主题包 zip，对齐上游 `importPackage`。 */
  static async importPackage(context: Context): Promise<ThemePackageImport | undefined> {
    const options = new picker.DocumentSelectOptions();
    options.fileSuffixFilters = ['Legado 主题包|.zip'];
    options.maxSelectNumber = 1;
    const uris = await new picker.DocumentViewPicker(context).select(options);
    const uri = uris[0];
    if (uri === undefined) { return undefined; }
    const work = ThemePackageRepository.workDirectory(context);
    const staging = `${work}/import-${Date.now()}`;
    const zipPath = `${work}/import-${Date.now()}.zip`;
    fileIo.mkdirSync(staging, true);
    try {
      const source = fileIo.openSync(uri, fileIo.OpenMode.READ_ONLY);
      try {
        fileIo.copyFileSync(source.fd, zipPath);
      } finally {
        fileIo.closeSync(source);
      }
      await zlib.decompressFile(zipPath, staging);
      ThemePackageRepository.validateExtracted(staging);
      const manifest = ThemePackageRepository.readManifest(staging);
      if (manifest === undefined) {
        throw new Error('主题包缺少 manifest.json 或格式不正确');
      }
      if (manifest.formatVersion > THEME_PACKAGE_FORMAT_VERSION) {
        throw new Error('主题包格式版本高于当前应用支持');
      }
      const imported = ThemePackageRepository.importAssetsInto(context, staging, manifest.assets);
      // 上游资产共 17 类，本地只认 7 类；其余计数后如实提示，不静默吞掉。
      const ignoredAssetCount = Object.keys(manifest.assets).length - Object.keys(imported).length;
      return {
        name: manifest.name,
        config: manifest.config,
        assets: imported,
        ignoredAssetCount: Math.max(0, ignoredAssetCount)
      };
    } finally {
      if (fileIo.accessSync(staging)) { removeDirectory(staging); }
      if (fileIo.accessSync(zipPath)) { fileIo.unlinkSync(zipPath); }
    }
  }

  /** 导入旧版 JSON 配置，对齐上游 `importLegacyJson`。 */
  static async importLegacyJson(context: Context): Promise<ThemePackageImport | undefined> {
    const options = new picker.DocumentSelectOptions();
    options.fileSuffixFilters = ['主题配置文件|.json'];
    options.maxSelectNumber = 1;
    const uris = await new picker.DocumentViewPicker(context).select(options);
    const uri = uris[0];
    if (uri === undefined) { return undefined; }
    // 选择器给的是 file uri，`readTextSync` 只认沙箱路径，所以先落到缓存再读。
    const work = ThemePackageRepository.workDirectory(context);
    const tempPath = `${work}/legacy-${Date.now()}.json`;
    let raw: string = '';
    try {
      const input = fileIo.openSync(uri, fileIo.OpenMode.READ_ONLY);
      try {
        fileIo.copyFileSync(input.fd, tempPath);
      } finally {
        fileIo.closeSync(input);
      }
      const stat = fileIo.statSync(tempPath);
      if (stat.size <= 0 || stat.size > 4 * 1024 * 1024) {
        throw new Error('主题配置文件为空或超过 4 MB');
      }
      raw = fileIo.readTextSync(tempPath);
    } finally {
      if (fileIo.accessSync(tempPath)) { fileIo.unlinkSync(tempPath); }
    }
    const config = parsePortableConfig(raw);
    if (config === undefined) { throw new Error('主题配置文件不是有效的 JSON'); }
    return {
      name: '',
      config: config,
      assets: ThemePackageRepository.emptyAssets(),
      ignoredAssetCount: 0
    };
  }

  /** 是否存在旧版已存主题（`saved_themes/*.json`），对齐上游 `hasLegacySavedThemes`。 */
  static hasLegacySavedThemes(context: Context): boolean {
    const root = ThemePackageRepository.rootDirectory(context);
    const names = fileIo.listFileSync(root);
    for (let index = 0; index < names.length; index++) {
      const name = names[index];
      if (!name.toLowerCase().endsWith('.json')) { continue; }
      if (fileIo.statSync(`${root}/${name}`).isFile()) { return true; }
    }
    return false;
  }

  /** 迁移旧版已存主题，对齐上游 `migrateLegacySavedThemes`。 */
  static migrateLegacySavedThemes(context: Context): LegacyThemeMigrationResult {
    const root = ThemePackageRepository.rootDirectory(context);
    const names = fileIo.listFileSync(root).sort();
    let migratedCount: number = 0;
    let failedCount: number = 0;
    for (let index = 0; index < names.length; index++) {
      const name = names[index];
      if (!name.toLowerCase().endsWith('.json')) { continue; }
      const path = `${root}/${name}`;
      if (!fileIo.statSync(path).isFile()) { continue; }
      const displayName = name.substring(0, name.length - 5);
      try {
        const config = parsePortableConfig(fileIo.readTextSync(path));
        if (config === undefined) {
          failedCount += 1;
          continue;
        }
        // 旧版只有配置、没有资产，所以这里直接写清单目录。
        const directoryName = savedThemeDirectoryName(displayName);
        const target = `${root}/${directoryName}`;
        if (fileIo.accessSync(target)) { removeDirectory(target); }
        fileIo.mkdirSync(target, true);
        writeTextFile(`${target}/${THEME_MANIFEST_PATH}`,
          ThemePackageRepository.manifestText(displayName, config,
            ThemePackageRepository.emptyAssets()));
        fileIo.unlinkSync(path);
        migratedCount += 1;
      } catch (_) {
        failedCount += 1;
      }
    }
    return { migratedCount: migratedCount, failedCount: failedCount };
  }

  /**
   * 把「应用主题」得到的资产路径写回设置快照。
   *
   * 上游 `prepareForApply` 会把包内资产解出来回填到 `bgImageLight` 等字段，
   * 本地同样只回填能对应上的 7 类。
   */
  static applyAssetsToSnapshot(snapshot: ThemeSnapshot, assets: Record<string, string>): void {
    const take = (key: string): string => {
      const value = assets[key];
      return typeof value === 'string' ? value : '';
    };
    if (take(ASSET_BACKGROUND_LIGHT).length > 0) { snapshot.backgroundImage = take(ASSET_BACKGROUND_LIGHT); }
    if (take(ASSET_BACKGROUND_DARK).length > 0) { snapshot.backgroundImageNight = take(ASSET_BACKGROUND_DARK); }
    if (take(ASSET_CONTAINER_LARGE_LIGHT).length > 0) {
      snapshot.largeContainerBackgroundImageLight = take(ASSET_CONTAINER_LARGE_LIGHT);
    }
    if (take(ASSET_CONTAINER_LARGE_DARK).length > 0) {
      snapshot.largeContainerBackgroundImageDark = take(ASSET_CONTAINER_LARGE_DARK);
    }
    if (take(ASSET_CONTAINER_ITEM_LIGHT).length > 0) {
      snapshot.itemBackgroundImageLight = take(ASSET_CONTAINER_ITEM_LIGHT);
    }
    if (take(ASSET_CONTAINER_ITEM_DARK).length > 0) {
      snapshot.itemBackgroundImageDark = take(ASSET_CONTAINER_ITEM_DARK);
    }
    if (take(ASSET_FONT_APP).length > 0) { snapshot.appFontPath = take(ASSET_FONT_APP); }
  }

  /** 便携配置里的三个自定义配色下拉取值是否在合法域内（导入时归一用）。 */
  static normalizePortableEnums(config: ThemePortableConfig): ThemePortableConfig {
    if (!CUSTOM_PALETTE_STYLES.includes(config.paletteStyle)) { config.paletteStyle = 'tonalSpot'; }
    if (!CUSTOM_CONTRASTS.includes(config.customContrast)) { config.customContrast = 'Default'; }
    if (!CUSTOM_MATERIAL_VERSIONS.includes(config.materialVersion)) {
      config.materialVersion = 'material3';
    }
    return config;
  }

  /** 日/夜色点预览用：取清单里 6 个色位的前三个（对齐上游 `ThemeColorGroup` 的 3 个圆点）。 */
  static previewColors(config: ThemePortableConfig, isNight: boolean): string[] {
    if (isNight) {
      return [
        colorFromArgbInt(config.themeColorNight),
        colorFromArgbInt(config.secondaryThemeColorNight),
        colorFromArgbInt(config.themeBackgroundColorNight)
      ];
    }
    return [
      colorFromArgbInt(config.themeColor),
      colorFromArgbInt(config.secondaryThemeColor),
      colorFromArgbInt(config.themeBackgroundColor)
    ];
  }

  /** 同目录名去重：重名时追加「 2」「 3」，对齐上游 `uniqueSavedThemeName`。 */
  static uniqueSavedThemeName(context: Context, name: string): string {
    const base = name.trim().length > 0 ? name.trim() : '未命名主题';
    if (!ThemePackageRepository.savedThemeExists(context, base)) { return base; }
    let index: number = 2;
    while (ThemePackageRepository.savedThemeExists(context, `${base} ${index}`)) { index += 1; }
    return `${base} ${index}`;
  }
}
