import { DURATION_FADE, HEADER_COLLAPSE_THRESHOLD, HEADER_EXPAND_THRESHOLD } from '../components/UiTokens';
import { UiSwitchControl } from '../components/UiSwitchControl';
import { CollapsingSettingsHeader } from '../components/CollapsingSettingsHeader';
import curves from '@ohos.curves';
import { UiAction } from '../components/settings/UiAction';
import { UiDropdown } from '../components/settings/UiDropdown';
import { UiSlider } from '../components/settings/UiSlider';
import { AppGlyph } from '../components/AppGlyph';
import { ThemeModeSelector, ThemeColorSelector } from '../components/ThemeSelectors';
import { appFontDisplayName } from '../data/AppFontSettings';
import { AppFontSheet } from '../components/settings/AppFontSheet';
import { NavIconManageSheet } from '../components/settings/NavIconManageSheet';
import { TopBottomBarSettingsSheet } from '../components/settings/TopBottomBarSettingsSheet';
import { LauncherIconPickerSheet } from '../components/settings/LauncherIconPickerSheet';
import {
  BackgroundImageManageSheet, BackgroundImageExtraOption, blurExtraOption
} from '../components/theme/BackgroundImageManageSheet';
import { MainNavigationSettingsSheet } from '../components/theme/MainNavigationSettingsSheet';
import { ThemeGroupColumn, ThemeGroupItem } from '../components/settings/ThemeGroupColumn';
import { ThemeRefactorTipStore } from '../data/ThemeRefactorTipStore';
import { resolvePaletteColors, ThemePaletteColors } from '../data/ThemePalette';
import {
  CustomThemeSnapshot, defaultCustomThemeSnapshot, hasCustomColor
} from '../data/CustomThemeColors';
import {
  BOOK_INFO_BACKGROUND_OFF,
  BOOK_INFO_BACKGROUND_OFF_FOR_DEFAULT,
  BOOK_INFO_BACKGROUND_ON
} from '../data/ThemeSettingsRepository';
import {
  LABEL_VISIBILITY_VALUES,
  TABLET_INTERFACE_VALUES,
  labelVisibilityLabel,
  mainNavigationLabel,
  orderedMainNavigation,
  tabletInterfaceLabel
} from '../data/MainNavigationSettings';
import {
  BAR_BLUR_ALPHA_MAX,
  BAR_BLUR_ALPHA_MIN,
  BOTTOM_BAR_BLUR_RADIUS_MAX,
  BOTTOM_BAR_BLUR_RADIUS_MIN,
  BOTTOM_BAR_LENS_RADIUS_MAX,
  BOTTOM_BAR_LENS_RADIUS_MIN,
  TOP_BAR_BLUR_RADIUS_MAX,
  TOP_BAR_BLUR_RADIUS_MIN,
  TOP_BAR_BUTTON_STYLES,
  TOP_BAR_OPACITY_MAX,
  TOP_BAR_OPACITY_MIN,
  topBarButtonStyleLabel
} from '../data/TopBottomBarSettings';
import {
  CARD_BORDER_WIDTH_MAX,
  CARD_BORDER_WIDTH_MIN,
  CARD_RADIUS_MAX,
  CARD_RADIUS_MIN,
  CONTAINER_OPACITY_MAX,
  CONTAINER_OPACITY_MIN,
  DIVIDER_LENGTH_MAX,
  DIVIDER_LENGTH_MIN,
  DIVIDER_WIDTH_MAX,
  DIVIDER_WIDTH_MIN
} from '../data/ThemeCardStyle';
import { BODY_SMALL, LABEL_LARGE, LABEL_LARGE_EMPHASIZED, LABEL_MEDIUM, TITLE_MEDIUM, TITLE_SMALL } from '../components/typography/TypographyTokens';

@Component
export struct ThemeSettingsPage {
  @StorageProp('themeColorTextPrimary') themeColorTextPrimary: string = '#1B1C22';
  @StorageProp('themeColorTextSecondary') themeColorTextSecondary: string = '#2E3038';
  @StorageProp('themeColorTextTertiary') themeColorTextTertiary: string = '#6A6D77';
  @StorageProp('themeColorAccent') themeColorAccent: string = '#3F5BD9';
  @StorageProp('themeColorSurfacePrimary') themeColorSurfacePrimary: string = '#F5F6F8';
  @StorageProp('themeColorSurfaceTertiary') themeColorSurfaceTertiary: string = '#F0F1F5';
  @StorageProp('themeColorSurfaceElevated') themeColorSurfaceElevated: string = '#FFFFFF';
  @StorageProp('themeAppBackground') themeAppBackground: string = '';
  @StorageProp('themePureBlack') themePureBlack: boolean = false;
  onBack: () => void = () => {};
  onUnavailableAction: (message: string) => void = (_message: string) => {};
  /** 当前全局 themeMode（`"0"` 跟随系统 / `"1"` 亮色 / `"2"` 暗色），由 Index 传入。 */
  @Prop themeMode: string = '0';
  /** 当前调色板序号，由 Index 传入。 */
  @Prop paletteIndex: number = 0;
  /** 用户选了深色模式三选项之一，参数是三值字符串。 */
  onThemeModeChange: (themeMode: string) => void = (_themeMode: string) => {};
  /** 用户选了调色板，参数是序号 0..13（对齐上游 `appTheme` 的 14 个取值）。 */
  onPaletteChange: (paletteIndex: number) => void = (_paletteIndex: number) => {};
  /** 当前是否深色，用于调色板预览色按日/夜取值；由 Index 传入（`ThemeModeResolver.isDarkTheme` 派生）。 */
  @Prop readerNightMode: boolean = false;
  /** 自定义主题配色快照，只用来生成「自定义颜色」行的摘要文案。 */
  @Prop customTheme: CustomThemeSnapshot = defaultCustomThemeSnapshot();
  /** 打开自定义颜色页；上游 `ThemeConfigScreen.kt:266-270` 的 `onNavigateToCustomTheme`。 */
  onOpenCustomTheme: () => void = () => {};
  /** 主题包管理入口，对齐上游 `ThemeManageScreen`。 */
  onOpenThemeManage: () => void = () => {};
  /** 全局字体缩放 8..16（10 = 1.0x），对齐上游 `AppShellSettings.kt:5 fontScale`。 */
  @Prop fontScale: number = 10;
  /** 是否显示状态栏，对齐上游 `AppShellSettings.kt:10 showStatusBar`。 */
  @Prop showStatusBarVisible: boolean = true;
  /** 是否启用滑动时动画，对齐上游 `AppShellSettings.kt:11 swipeAnimation`。 */
  @Prop swipeAnimationEnabled: boolean = true;
  /** 字体大小滑块回调。 */
  onFontScaleChange: (fontScale: number) => void = (_fontScale: number) => {};
  /** 显示状态栏开关回调。 */
  onShowStatusBarChange: (visible: boolean) => void = (_visible: boolean) => {};
  /** 滑动动画开关回调。 */
  onSwipeAnimationChange: (enabled: boolean) => void = (_enabled: boolean) => {};
  /** 书籍详情页界面颜色是否跟随封面取色，对齐上游 `ThemeSettings.bookInfoFollowCoverColor`。 */
  @Prop bookInfoFollowCoverColor: boolean = true;
  /** 网络封面背景模式 `off`/`on`/`off_for_default`。 */
  @Prop bookInfoNetworkCoverBackground: string = 'on';
  /** 默认封面背景模式。 */
  @Prop bookInfoDefaultCoverBackground: string = 'on';
  /** 无关联规则时按作者搜索，对齐上游 `bookInfoAuthorSearchFallback`（默认 false）。 */
  @Prop bookInfoAuthorSearchFallback: boolean = false;
  onBookInfoAuthorSearchFallbackChange: (enabled: boolean) => void = (_enabled: boolean) => {};
  onBookInfoFollowCoverColorChange: (enabled: boolean) => void = (_enabled: boolean) => {};
  /** 封面背景下拉回调，`isDefaultCover` 区分「网络封面」与「默认封面」两行。 */
  onBookInfoCoverBackgroundChange: (isDefaultCover: boolean, value: string) => void =
    (_isDefaultCover: boolean, _value: string) => {};
  /** 容器底色不透明度 0..100，对齐上游 `ThemeSettings.kt:24 containerOpacity`。 */
  @Prop containerOpacity: number = CONTAINER_OPACITY_MAX;
  /** 关闭设置分组圆角，对齐上游 `disableSplicedColumnGroupCornerRadius`。 */
  @Prop disableGroupCorner: boolean = false;
  /** 覆盖卡片圆角总开关，对齐上游 `overrideBaseCardCornerRadius`。 */
  @Prop overrideCardCorner: boolean = false;
  /** 卡片圆角数值 0..40，对齐上游 `baseCardCornerRadius`。 */
  @Prop cardCornerRadius: number = 16;
  /** 覆盖卡片边框总开关，对齐上游 `overrideBaseCardBorder`。 */
  @Prop overrideCardBorder: boolean = false;
  /** 边框宽度 0..5，对齐上游 `baseCardBorderWidth`。 */
  @Prop cardBorderWidth: number = 1;
  /** 日间边框色 `#RRGGBB`，空串表示未设置。 */
  @Prop cardBorderColorDay: string = '';
  /** 夜间边框色 `#RRGGBB`，空串表示未设置。 */
  @Prop cardBorderColorNight: string = '';
  /** 显示分隔线，对齐上游 `ThemeSettings.kt:63 enableItemDivider`。 */
  @Prop enableItemDivider: boolean = false;
  /** 分隔线宽度 0..5，对齐上游 `itemDividerWidth`。 */
  @Prop dividerWidth: number = 1;
  /** 分隔线长度 30..100（百分比），对齐上游 `itemDividerLength`。 */
  @Prop dividerLength: number = 80;
  /** 分隔线颜色 `#RRGGBB`，空串表示未设置。 */
  @Prop dividerColor: string = '';
  /** 容器背景图总开关，对齐上游 `enableContainerBackgroundImage`。 */
  @Prop enableContainerBackgroundImage: boolean = false;
  /** 大容器日间/夜间背景图路径，空串表示未选择。 */
  @Prop largeContainerBackgroundLight: string = '';
  @Prop largeContainerBackgroundDark: string = '';
  /** 项目日间/夜间背景图路径。 */
  @Prop itemBackgroundLight: string = '';
  @Prop itemBackgroundDark: string = '';
  onContainerOpacityChange: (value: number) => void = (_value: number) => {};
  onDisableGroupCornerChange: (value: boolean) => void = (_value: boolean) => {};
  onOverrideCardCornerChange: (value: boolean) => void = (_value: boolean) => {};
  onCardCornerRadiusChange: (value: number) => void = (_value: number) => {};
  onOverrideCardBorderChange: (value: boolean) => void = (_value: boolean) => {};
  onCardBorderWidthChange: (value: number) => void = (_value: number) => {};
  /** 边框颜色回调，`isNight` 区分日间/夜间两行。 */
  onCardBorderColorChange: (isNight: boolean, value: string) => void =
    (_isNight: boolean, _value: string) => {};
  /** 恢复默认主题配置回调（上游 `ThemeConfigIntent.ResetDefaults`）。 */
  onResetDefaults: () => void = () => {};
  /** 显示分隔线开关回调。 */
  onEnableItemDividerChange: (enabled: boolean) => void = (_enabled: boolean) => {};
  /** 分隔线宽度回调。 */
  onDividerWidthChange: (value: number) => void = (_value: number) => {};
  /** 分隔线长度回调。 */
  onDividerLengthChange: (value: number) => void = (_value: number) => {};
  /** 分隔线颜色回调。 */
  onDividerColorChange: (value: string) => void = (_value: string) => {};
  /** 容器背景图总开关回调。 */
  onEnableContainerBackgroundImageChange: (enabled: boolean) => void = (_enabled: boolean) => {};
  /** 选背景图回调，`isLarge` 区分大容器/项目，`isNight` 区分夜间/日间。 */
  onPickContainerBackground: (isLarge: boolean, isNight: boolean) => void =
    (_isLarge: boolean, _isNight: boolean) => {};
  /** 纯黑深色模式，对齐上游 `ThemeSettings.kt:6 isPureBlack`（默认 false）。 */
  @Prop pureBlack: boolean = false;
  /** 纯黑深色模式开关回调。 */
  onPureBlackChange: (enabled: boolean) => void = (_enabled: boolean) => {};
  /** 全 App 日间背景图路径，对齐上游 `backgroundImage`。 */
  @Prop appBackgroundImage: string = '';
  /** 全 App 夜间背景图路径，对齐上游 `backgroundImageNight`。 */
  @Prop appBackgroundImageNight: string = '';
  /** 日间背景图虚化半径，对齐上游 `backgroundImageBlurring`。 */
  @Prop appBackgroundBlur: number = 0;
  /** 夜间背景图虚化半径，对齐上游 `backgroundImageNightBlurring`。 */
  @Prop appBackgroundNightBlur: number = 0;
  /** 选背景图回调，`isNight` 区分夜间/日间。 */
  onPickBackgroundImage: (isNight: boolean) => void = (_isNight: boolean) => {};
  /** 背景图虚化半径回调。 */
  onBackgroundBlurChange: (isNight: boolean, blur: number) => void =
    (_isNight: boolean, _blur: number) => {};
  /** 清空背景图回调。 */
  onClearBackgroundImage: (isNight: boolean) => void = (_isNight: boolean) => {};
  /** 护眼模式总开关，与阅读设置页共用同一份全局状态。 */
  @Prop eyeProtectionEnabled: boolean = false;
  /** 深色模式时自动开启护眼。 */
  @Prop eyeProtectionAutoNight: boolean = false;
  /** 护眼是否按时间段生效。 */
  @Prop eyeProtectionSchedule: boolean = false;
  /** 护眼强度 0..100，对齐上游 `colorTemperature`。 */
  @Prop eyeProtectionIntensity: number = 50;
  /** 定时开始时间 `HH:mm`。 */
  @Prop eyeProtectionStartTime: string = '22:00';
  /** 定时结束时间 `HH:mm`。 */
  @Prop eyeProtectionEndTime: string = '07:00';
  /** 护眼当前是否正在生效，用于色温行显示实际值。 */
  @Prop eyeProtectionActive: boolean = false;
  onEyeProtectionEnabledChange: (enabled: boolean) => void = (_enabled: boolean) => {};
  onEyeProtectionAutoNightChange: (enabled: boolean) => void = (_enabled: boolean) => {};
  onEyeProtectionScheduleChange: (enabled: boolean) => void = (_enabled: boolean) => {};
  onEyeProtectionIntensityChange: (intensity: number) => void = (_intensity: number) => {};
  onEyeProtectionStartTimeChange: (time: string) => void = (_time: string) => {};
  onEyeProtectionEndTimeChange: (time: string) => void = (_time: string) => {};
  @State backgroundExpanded: boolean = false;
  @State showRefactorTip: boolean = true;

  /**
   * 进页面时读提示条的关闭状态。上游 `theme.showRefactorTip` 是持久化偏好
   * （`FeatureSettingsRepositories.kt:427-429`），关一次永久关；本地原先只有 `@State`。
   */
  aboutToAppear(): void {
    const context = this.getUIContext().getHostContext();
    if (context === undefined) {
      return;
    }
    ThemeRefactorTipStore.load(context).then((visible: boolean) => {
      this.showRefactorTip = visible;
    });
  }

  /** 关闭提示条并落盘，下次进外观页不再出现。 */
  private dismissRefactorTip(): void {
    this.showRefactorTip = false;
    const context = this.getUIContext().getHostContext();
    if (context !== undefined) {
      ThemeRefactorTipStore.saveHidden(context);
    }
  }
  /** 预见性返回手势；上游 `AppShellSettings.kt:9 predictiveBackEnabled`。 */
  @Prop predictiveBack: boolean = true;
  onPredictiveBackChange: (enabled: boolean) => void = () => {};
  /** 阅读界面共享元素动画；上游 `AppShellSettings.kt:10 readerSharedElementEnabled`。 */
  @Prop readerSharedElement: boolean = true;
  onReaderSharedElementChange: (enabled: boolean) => void = () => {};
  /** 主导航显隐与顺序；上游 `AppShellSettings.kt:6-8` + `:17-19`。 */
  @Prop showHome: boolean = true;
  @Prop showDiscovery: boolean = true;
  @Prop showRss: boolean = true;
  @Prop defaultHomePage: string = 'bookshelf';
  @Prop mainNavigationOrder: string = 'home,bookshelf,explore,rss,my';
  @Prop labelVisibilityMode: string = 'auto';
  onNavigationVisibilityChange: (route: string, visible: boolean) => void = () => {};
  onNavigationMove: (route: string, up: boolean) => void = () => {};
  /**
   * 拖拽重排回调：把第 `from` 项移到第 `to` 位。
   * 对齐上游 `MainNavigationSettingsSheet.kt:38-46` 的 `navigationItems.move(from.index, to.index)`，
   * 落盘走 `data/MainNavigationSettings.ets` 的 `moveNavigationTo`。
   */
  onNavigationReorder: (from: number, to: number) => void = () => {};
  /** 正在拖动的主导航线条目 route；`onItemDragStart` 记下，`onItemDrop` 用完清空。 */
  @State draggingRoute: string = '';
  onDefaultHomePageChange: (route: string) => void = () => {};
  onLabelVisibilityModeChange: (value: string) => void = () => {};
  /**
   * 平板界面四档（批6 :385）。上游 `PreferKey.tabletInterface`，默认 auto；
   * 判据在 `data/MainNavigationSettings.ets`，渲染在 `pages/Index.ets` 的 NavigationRail。
   */
  @Prop tabletInterface: string = 'auto';
  onTabletInterfaceChange: (value: string) => void = () => {};
  /** 「首页与导航」组是否展开。上游是一个 sheet，本地用可展开组承接。 */
  @State navigationExpanded: boolean = false;
  @State followCoverColor: boolean = true;
  /** 模糊效果两项；上游 `ThemeSettings.kt:33-34 enableBlur`/`enableProgressiveBlur`。 */
  @Prop enableBlur: boolean = false;
  onEnableBlurChange: (enabled: boolean) => void = () => {};
  @Prop enableProgressiveBlur: boolean = false;
  onEnableProgressiveBlurChange: (enabled: boolean) => void = () => {};
  /** 顶栏与底栏的 13 项；上游 `TopBottomBarSettingsSheet.kt`。 */
  @Prop useFlexibleTopAppBar: boolean = true;
  onUseFlexibleTopAppBarChange: (enabled: boolean) => void = () => {};
  @Prop topBarButtonStyle: string = 'tonal';
  onTopBarButtonStyleChange: (value: string) => void = () => {};
  @Prop mergeTopBarActions: boolean = false;
  onMergeTopBarActionsChange: (enabled: boolean) => void = () => {};
  @Prop showBottomView: boolean = true;
  onShowBottomViewChange: (enabled: boolean) => void = () => {};
  @Prop useFloatingBottomBar: boolean = false;
  onUseFloatingBottomBarChange: (enabled: boolean) => void = () => {};
  @Prop useFloatingBottomBarLiquidGlass: boolean = false;
  onUseFloatingBottomBarLiquidGlassChange: (enabled: boolean) => void = () => {};
  @Prop bottomBarLensRadius: number = 24;
  onBottomBarLensRadiusChange: (value: number) => void = () => {};
  @Prop topBarBlurRadius: number = 24;
  onTopBarBlurRadiusChange: (value: number) => void = () => {};
  @Prop bottomBarBlurRadius: number = 8;
  onBottomBarBlurRadiusChange: (value: number) => void = () => {};
  @Prop topBarBlurAlpha: number = 73;
  onTopBarBlurAlphaChange: (value: number) => void = () => {};
  @Prop bottomBarBlurAlpha: number = 40;
  onBottomBarBlurAlphaChange: (value: number) => void = () => {};
  @Prop topBarOpacity: number = 100;
  onTopBarOpacityChange: (value: number) => void = () => {};
  @Prop bottomBarOpacity: number = 100;
  onBottomBarOpacityChange: (value: number) => void = () => {};
  /** 应用字体文件路径；空串表示系统默认字体。上游 `ThemeSettings.appFontPath`。 */
  @Prop appFontPath: string = '';
  onPickAppFont: () => void = () => {};
  onClearAppFont: () => void = () => {};
  /** 用户自选的字体文件夹；空串表示未配置。上游 `ReadSettings.fontFolder`。 */
  @Prop fontFolder: string = '';
  onChangeFontFolder: (path: string) => void = (_path: string) => {};
  /** 选中已有字体（不走系统文件选择器，直接指向已导入的那份副本）。 */
  onSelectAppFont: (path: string) => void = (_path: string) => {};
  /** 十个导航图标槽位；空串表示用内置矢量图标。上游 `AppShellSettings.kt:20-29`。 */
  @Prop navIconHome: string = '';
  @Prop navIconBookshelf: string = '';
  @Prop navIconExplore: string = '';
  @Prop navIconRss: string = '';
  @Prop navIconMy: string = '';
  @Prop navIconHomeSelected: string = '';
  @Prop navIconBookshelfSelected: string = '';
  @Prop navIconExploreSelected: string = '';
  @Prop navIconRssSelected: string = '';
  @Prop navIconMySelected: string = '';
  /** 选中某个槽位的新图标文件（已复制进沙箱）。 */
  onSelectNavIcon: (slot: string, path: string) => void = (_slot: string, _path: string) => {};
  /** 清空某个槽位。 */
  onClearNavIcon: (slot: string) => void = (_slot: string) => {};
  /** 当前正在使用的桌面图标 id，空串表示默认图标（对齐上游 `PreferKey.launcherIcon`）。 */
  @Prop launcherIconId: string = '';
  /** 切换桌面图标成功后回调，参数是新 id，空串表示已恢复默认。 */
  onLauncherIconChange: (iconId: string) => void = (_iconId: string) => {};
  /**
   * 当前打开的 sheet 键；空串表示全关。
   *
   * 同一节点只能挂一个 `bindSheet`（多个只生效最后一个，见
   * `pages/AppCoverSettingsPage.ets:435` 的注释），所以用这个键切内容。
   */
  @State activeSheet: string = '';
  @State collapsedHeader: boolean = false;
  private themeScroller: Scroller = new Scroller();

  private updateHeader(): void {
    const offset = this.themeScroller.currentOffset().yOffset;
    const shouldCollapse = offset > HEADER_COLLAPSE_THRESHOLD ? true : offset < HEADER_EXPAND_THRESHOLD ? false : this.collapsedHeader;
    if (shouldCollapse !== this.collapsedHeader) {
      // 顶部折叠是位移，用弹簧收尾更自然；弹簧不吃 duration，删掉（写了也不生效）。
      this.getUIContext().animateTo({ curve: curves.springMotion(0.35, 0.86) }, () => {
        this.collapsedHeader = shouldCollapse;
      });
    }
  }

  /**
   * 预览卡用的整套配色：上游 `ThemeCard`（`ThemeConfigScreen.kt:1195-1207`）按当前主题现算一套
   * `getThemeColors(...)`，五个色块分别取 `onSurfaceVariant`（顶条）/ `secondaryContainer`（书块）/
   * `secondary`（书块角标）/ `surfaceContainer`（底条）/ `primary`（底条圆点）/ `surface`（卡底）。
   *
   * 上游这套预览色由 `getThemeColors(context, value, isDark, isAmoled, paletteStyle,
   * customLightSeedColor, customNightSeedColor)` 现算（`ThemeConfigScreen.kt:1330`），七个入参里
   * `isAmoled`（纯黑）与两个 seedColor（自定义配色）会影响结果；本地调色板是 14 档静态表
   * （`data/ThemePalette.ets`），`resolvePaletteColors(index, isDark)` 只吃「档位 + 深色」两维，
   * 纯黑由各页面 `themePureBlack ? '#000000' : ...` 的条件替换承接、自定义配色的 seed 本地不参与
   * 调色板求值，所以预览卡与上游在「纯黑 / 自定义 seed」两种情形下会有色差。这条差异登记在报告
   * 待办账本「主题管理页 / 自定义主题页」两行的备注里，不在本函数内伪造入参。
   */
  private previewPalette(): ThemePaletteColors {
    return resolvePaletteColors(this.paletteIndex, this.readerNightMode);
  }

  /** 封面背景模式的中文文案，对齐上游 `values-zh-rCN/strings.xml:1751-1753`。 */
  /** 背景图行摘要：上游 `BackgroundImageManageSheet` 的两个路径都空时显示「选择图片」，否则「已选择」。 */
  private appBackgroundSummary(): string {
    const day = this.appBackgroundImage.length > 0;
    const night = this.appBackgroundImageNight.length > 0;
    if (day && night) { return '日间/夜间已选择'; }
    if (day) { return '已选日间，点击展开'; }
    if (night) { return '已选夜间，点击展开'; }
    return '日间/夜间背景图与背景虚化';
  }

  /** 「首页与导航」行的摘要文案：显示可见项数量与默认页。 */
  /** 「字体设置」行的摘要：未选时提示系统默认，已选时显示文件名。 */
  private appFontSummary(): string {
    if (this.appFontPath.length === 0) { return '系统默认字体'; }
    return appFontDisplayName(this.appFontPath);
  }

  /**
   * 「自定义颜色」行的摘要。
   *
   * 对齐上游 `ThemeConfigScreen.kt:266-270` 那行的 description：没有单独摘要时留空即可，
   * 这里给一句能说明当前状态的短文案，避免一行只有标题看不出是否已设色。
   */
  private customColorSummary(): string {
    if (this.customTheme.enableDeepPersonalization) {
      return hasCustomColor(this.customTheme.day) || hasCustomColor(this.customTheme.night)
        ? '已自定义日间/夜间颜色' : '自定义日间/夜间颜色';
    }
    return this.customTheme.seedColorDay.length > 0 || this.customTheme.seedColorNight.length > 0
      ? '已设置种子色' : '用种子色生成整套配色';
  }

  /** 「顶栏与底栏」行的摘要文案。 */
  private topBottomBarSummary(): string {
    const barParts: string[] = [];
    if (!this.showBottomView) { barParts.push('无导航栏'); }
    else if (this.useFloatingBottomBar) { barParts.push('悬浮底栏'); }
    if (this.enableBlur) { barParts.push(`模糊 ${this.topBarBlurRadius}/${this.bottomBarBlurRadius}`); }
    else { barParts.push(`不透明度 ${this.topBarOpacity}%/${this.bottomBarOpacity}%`); }
    barParts.push(topBarButtonStyleLabel(this.topBarButtonStyle));
    return barParts.join(' · ');
  }

  /**
   * sheet 高度。
   *
   * 字体 / 导航图标 / 启动图标三个面板是长列表，上游 `AppModalBottomSheet` 走可滚动内容，
   * 本地给固定 620；背景图片与首页与导航是定长内容，用 `SheetSize.FIT_CONTENT` 贴合内容，
   * 否则面板下方留一大片空白（上游这两个面板就是内容多高就多高）。
   */
  private sheetHeight(): SheetSize | number {
    if (this.activeSheet === 'backgroundImage' || this.activeSheet === 'mainNavigation') {
      return SheetSize.FIT_CONTENT;
    }
    return 620;
  }

  private navigationSummary(): string {
    const visible: string[] = this.visibleNavigationOptions();
    const hidden = 3 - (this.showHome ? 1 : 0) - (this.showDiscovery ? 1 : 0) - (this.showRss ? 1 : 0);
    const base = `默认 ${mainNavigationLabel(this.defaultHomePage)}`;
    return hidden > 0 ? `${base} · 隐藏 ${hidden} 项` : `${base} · ${visible.length} 项`;
  }

  /**
   * 「导航栏图标」行的摘要，对齐上游 `MainNavigationSettingsSheet.kt:90-96`：
   * 有自定义时是 `theme_config_nav_icons_custom_count`（已设置 %1$d 个自定义图标），
   * 否则是 `theme_config_nav_icons_default`（使用默认图标）。
   */
  private navIconSummary(): string {
    const paths: string[] = this.navIconPaths();
    let count = 0;
    for (const path of paths) {
      if (path.length > 0) {
        count++;
      }
    }
    return count > 0 ? `已设置 ${count} 个自定义图标` : '使用默认图标';
  }

  /** 十个槽位按 `NAV_ICON_SLOTS` 顺序排成数组，供面板与摘要共用。 */
  private navIconPaths(): string[] {
    const paths: string[] = [];
    paths.push(this.navIconHome);
    paths.push(this.navIconBookshelf);
    paths.push(this.navIconExplore);
    paths.push(this.navIconRss);
    paths.push(this.navIconMy);
    paths.push(this.navIconHomeSelected);
    paths.push(this.navIconBookshelfSelected);
    paths.push(this.navIconExploreSelected);
    paths.push(this.navIconRssSelected);
    paths.push(this.navIconMySelected);
    return paths;
  }

  /** 已设置的自定义图标数量，供「首页与导航」sheet 的图标行摘要用。 */
  private customNavIconCount(): number {
    const paths: string[] = this.navIconPaths();
    let count = 0;
    for (const path of paths) {
      if (path.length > 0) {
        count++;
      }
    }
    return count;
  }

  /** 可见导航项（按配置顺序），供「默认主页面」下拉使用。 */
  private visibleNavigationOptions(): string[] {
    const ordered = orderedMainNavigation(this.mainNavigationOrder);
    const result: string[] = [];
    for (let index = 0; index < ordered.length; index++) {
      const route = ordered[index];
      if (route === 'home' && !this.showHome) { continue; }
      if (route === 'explore' && !this.showDiscovery) { continue; }
      if (route === 'rss' && !this.showRss) { continue; }
      result.push(route);
    }
    return result;
  }

  /** 主导航全量顺序（含隐藏项），拖拽列表按它渲染。 */
  private navigationOrderRoutes(): string[] {
    return orderedMainNavigation(this.mainNavigationOrder);
  }

  private coverBackgroundOptions(): string[] {
    return [BOOK_INFO_BACKGROUND_ON, BOOK_INFO_BACKGROUND_OFF, BOOK_INFO_BACKGROUND_OFF_FOR_DEFAULT];
  }

  /** 护眼定时的起止时间选择，对齐阅读设置页同名能力。 */
  private pickEyeProtectionTime(isStart: boolean): void {
    const current = isStart ? this.eyeProtectionStartTime : this.eyeProtectionEndTime;
    const parts: string[] = current.split(':');
    const selected: Date = new Date();
    selected.setHours(Number(parts[0]), Number(parts[1]), 0, 0);
    this.getUIContext().showTimePickerDialog({
      selected: selected,
      useMilitaryTime: true,
      onAccept: (value: TimePickerResult): void => {
        const hourText = value.hour < 10 ? `0${value.hour}` : `${value.hour}`;
        const minuteText = value.minute < 10 ? `0${value.minute}` : `${value.minute}`;
        const time = `${hourText}:${minuteText}`;
        if (isStart) {
          this.onEyeProtectionStartTimeChange(time);
        } else {
          this.onEyeProtectionEndTimeChange(time);
        }
      }
    });
  }

  /**
   * 边框颜色候选。
   *
   * 上游用 `ColorPickerSheet`（`ui/widget/components/dialog/ColorPickerSheet.kt:51`）：
   * 取色盘 + hex 输入 + 「重置」（置透明）。本地没有取色盘组件，用下拉给一组预设色 + 「默认描边色」，
   * 语义对齐「重置回未设置」——空串即上游的 `baseCardBorderColor = 0`。
   */
  private cardBorderColorOptions(): string[] {
    return ['', '#3F5BD9', '#AFC2FF', '#92949E', '#6A6D77', '#F4D45E', '#A6D28A'];
  }

  /**
   * 背景图选择行的摘要文案。
   *
   * 上游 `ThemeConfigScreen.kt:545`/`:564` 在两个路径都空时显示 `select_image`（「选择图片」），
   * 否则显示 `selected`（「已选择」）。本地把「日/夜各选没选」直接摊开，比「已选择」更好用。
   */
  private backgroundSummary(light: string, dark: string): string {
    const hasLight = light.length > 0;
    const hasDark = dark.length > 0;
    if (!hasLight && !hasDark) { return '选择图片'; }
    if (hasLight && hasDark) { return '日间/夜间已选择'; }
    return hasLight ? '已选日间，点击换图' : '已选夜间，点击换图';
  }

  /** 分隔线颜色候选，与边框色同一组预设；空串即上游 `itemDividerColor = 0` 的「默认灰」。 */
  private dividerColorOptions(): string[] {
    return ['', '#3F5BD9', '#AFC2FF', '#92949E', '#6A6D77', '#F4D45E', '#A6D28A'];
  }

  /**
   * 恢复默认主题配置的二次确认。
   *
   * 上游 `ThemeConfigScreen.kt:752` 弹 `AppAlertDialog`，文案取
   * `theme_config_reset_defaults` / `theme_config_reset_defaults_confirm`（`values-zh-rCN/strings.xml:1776-1778`）。
   */
  /** 封面背景三档，对齐上游 values-zh-rCN/strings.xml:1751-1753。 */
  private coverBackgroundLabel(value: string): string {
    if (value === BOOK_INFO_BACKGROUND_OFF) { return '关闭模糊封面'; }
    if (value === BOOK_INFO_BACKGROUND_OFF_FOR_DEFAULT) { return '不显示背景封面'; }
    return '开启模糊封面';
  }

  /** 边框色 / 分隔线色：空串是上游 baseCardBorderColor = 0 的「未设置」，色值原样显示。 */
  private borderColorLabel(value: string): string {
    if (value.length === 0) { return '默认描边色'; }
    return value;
  }

  private confirmResetDefaults(): void {
    this.getUIContext().showAlertDialog({
      title: '恢复默认主题配置',
      message: '将恢复外观页中的主题、界面布局、背景图片、应用字体和导航图标等配置。已保存的主题、封面图集和书籍封面不会被删除。',
      autoCancel: true,
      primaryButton: {
        value: '取消',
        action: () => {}
      },
      secondaryButton: {
        value: '恢复',
        fontColor: this.themeColorAccent,
        action: () => this.onResetDefaults()
      }
    });
  }

  /**
   * sheet 内容分发。
   *
   * 一个节点只能挂一个 `bindSheet`，多个只生效最后一个，所以按 `activeSheet` 切内容
   * （同 `pages/AppCoverSettingsPage.ets:435` 的写法）。
   */
  @Builder
  private SheetContent() {
    if (this.activeSheet === 'font') {
      AppFontSheet({
        selectedPath: this.appFontPath,
        folderPath: this.fontFolder,
        onSelectFont: (path: string) => {
          this.onSelectAppFont(path);
          this.activeSheet = '';
        },
        onClearFont: () => {
          this.onClearAppFont();
          this.activeSheet = '';
        },
        onFolderChange: (path: string) => this.onChangeFontFolder(path)
      })
    } else if (this.activeSheet === 'navIcon') {
      NavIconManageSheet({
        slotPaths: this.navIconPaths(),
        onSelectIcon: (slot: string, path: string) => this.onSelectNavIcon(slot, path),
        onClearIcon: (slot: string) => this.onClearNavIcon(slot)
      })
    } else if (this.activeSheet === 'topBottomBar') {
      TopBottomBarSettingsSheet({
        useFlexibleTopAppBar: this.useFlexibleTopAppBar,
        topBarButtonStyle: this.topBarButtonStyle,
        mergeTopBarActions: this.mergeTopBarActions,
        showBottomView: this.showBottomView,
        useFloatingBottomBar: this.useFloatingBottomBar,
        useFloatingBottomBarLiquidGlass: this.useFloatingBottomBarLiquidGlass,
        bottomBarLensRadius: this.bottomBarLensRadius,
        enableBlur: this.enableBlur,
        topBarBlurRadius: this.topBarBlurRadius,
        bottomBarBlurRadius: this.bottomBarBlurRadius,
        topBarBlurAlpha: this.topBarBlurAlpha,
        bottomBarBlurAlpha: this.bottomBarBlurAlpha,
        topBarOpacity: this.topBarOpacity,
        bottomBarOpacity: this.bottomBarOpacity,
        onUseFlexibleTopAppBarChange: (value: boolean) => this.onUseFlexibleTopAppBarChange(value),
        onTopBarButtonStyleChange: (value: string) => this.onTopBarButtonStyleChange(value),
        onMergeTopBarActionsChange: (value: boolean) => this.onMergeTopBarActionsChange(value),
        onShowBottomViewChange: (value: boolean) => this.onShowBottomViewChange(value),
        onUseFloatingBottomBarChange: (value: boolean) => this.onUseFloatingBottomBarChange(value),
        onUseFloatingBottomBarLiquidGlassChange: (value: boolean) => this.onUseFloatingBottomBarLiquidGlassChange(value),
        onBottomBarLensRadiusChange: (value: number) => this.onBottomBarLensRadiusChange(value),
        onTopBarBlurRadiusChange: (value: number) => this.onTopBarBlurRadiusChange(value),
        onBottomBarBlurRadiusChange: (value: number) => this.onBottomBarBlurRadiusChange(value),
        onTopBarBlurAlphaChange: (value: number) => this.onTopBarBlurAlphaChange(value),
        onBottomBarBlurAlphaChange: (value: number) => this.onBottomBarBlurAlphaChange(value),
        onTopBarOpacityChange: (value: number) => this.onTopBarOpacityChange(value),
        onBottomBarOpacityChange: (value: number) => this.onBottomBarOpacityChange(value)
      })
    } else if (this.activeSheet === 'launcherIcon') {
      LauncherIconPickerSheet({
        selectedId: this.launcherIconId,
        onDismiss: () => { this.activeSheet = ''; },
        onIconChanged: (iconId: string) => this.onLauncherIconChange(iconId)
      })
    } else if (this.activeSheet === 'backgroundImage') {
      // 上游 `BackgroundImageManageSheet.kt:60-70` 在背景图面板里给的是 `Blur` 档：
      // 日夜两格 + 两档虚化滑块（0..100，默认 0），滑块只在对应图存在时才画。
      BackgroundImageManageSheet({
        title: '背景图片',
        lightPath: this.appBackgroundImage,
        darkPath: this.appBackgroundImageNight,
        extraOption: blurExtraOption(this.appBackgroundBlur, this.appBackgroundNightBlur),
        onDismissRequest: () => { this.activeSheet = ''; },
        onSelectLight: () => this.onPickBackgroundImage(false),
        onSelectDark: () => this.onPickBackgroundImage(true),
        onRemoveLight: () => this.onClearBackgroundImage(false),
        onRemoveDark: () => this.onClearBackgroundImage(true),
        onLightBlurChange: (value: number) => this.onBackgroundBlurChange(false, value),
        onDarkBlurChange: (value: number) => this.onBackgroundBlurChange(true, value),
        onOpacityChange: (_value: number) => {}
      })
    } else if (this.activeSheet === 'mainNavigation') {
      MainNavigationSettingsSheet({
        mainNavigationOrder: this.mainNavigationOrder,
        defaultHomePage: this.defaultHomePage,
        labelVisibilityMode: this.labelVisibilityMode,
        showHome: this.showHome,
        showDiscovery: this.showDiscovery,
        showRss: this.showRss,
        customNavIconCount: this.customNavIconCount(),
        onDismissRequest: () => { this.activeSheet = ''; },
        onNavigationVisibilityChange: (route: string, visible: boolean) =>
          this.onNavigationVisibilityChange(route, visible),
        onNavigationReorder: (from: number, to: number) => this.onNavigationReorder(from, to),
        onNavigationMove: (route: string, up: boolean) => this.onNavigationMove(route, up),
        onDefaultHomePageChange: (route: string) => this.onDefaultHomePageChange(route),
        onLabelVisibilityModeChange: (value: string) => this.onLabelVisibilityModeChange(value),
        onOpenNavIcons: () => { this.activeSheet = 'navIcon'; }
      })
    }
  }

  build() {
    Column() {
      CollapsingSettingsHeader({ title: '外观', collapsed: this.collapsedHeader, onBack: () => this.onBack() })
      Scroll(this.themeScroller) {
        Column() {
          Column() {
            // 上游 `ThemeCard`（`ThemeConfigScreen.kt:1209-1277`）：128×256dp、16dp 圆角、1dp primary 描边，
            // 卡内是三个抽象色块（顶条 / 书块 / 底条），不是缩小版界面截图 —— 原先这里画了假文字条，
            // 且三个色值写死成灰，切配色时不跟着变，所以看起来「怪」。
            Column() {
              // 顶条 48×16，圆角 8，色 onSurfaceVariant，距顶/左各 12。
              Row().width(48).height(16).borderRadius(8)
                .backgroundColor(this.previewPalette().onSurfaceVariant)
                .margin({ top: 12, left: 12 })
              // 书块 56×80，圆角 8，色 secondaryContainer；内部右上角 16×12、圆角 4 的 secondary 角标。
              Stack({ alignContent: Alignment.TopEnd }) {
                Column().width(56).height(80).borderRadius(8)
                  .backgroundColor(this.previewPalette().secondaryContainer)
                Row().width(16).height(12).borderRadius(4)
                  .backgroundColor(this.previewPalette().secondary)
                  .margin({ top: 4, right: 4 })
              }.margin({ top: 8, left: 12 })
              Blank().layoutWeight(1)
              // 底条整宽 40 高、左右各 4、无圆角，色 surfaceContainer；中心 20 实心圆 primary。
              Stack({ alignContent: Alignment.Center }) {
                Row().width('100%').height(40).backgroundColor(this.previewPalette().surfaceContainer)
                Row().width(20).height(20).borderRadius(10).backgroundColor(this.previewPalette().primary)
              }.width('100%').margin({ left: 4, right: 4 })
            }.width(128).height(256)
              .backgroundColor(this.previewPalette().surface)
              .borderRadius(16)
              .border({ width: 1, color: this.previewPalette().primary })
              .alignItems(HorizontalAlign.Start)
              .clip(true)
              .alignSelf(ItemAlign.Center).margin({ top: 18, bottom: 16 })
          }.width('100%').alignItems(HorizontalAlign.Center)

          if (this.showRefactorTip) {
            Row() {
              Text('仍有部分界面未用Compose重构，这些界面会与大部分界面有较大差异。')
                .fontSize(LABEL_LARGE_EMPHASIZED).fontColor(this.themeColorTextSecondary).layoutWeight(1)
              AppGlyph({ name: 'profileClose', glyphSize: 18, tint: '#C5C7D0' })
                .onClick(() => this.dismissRefactorTip())
                .accessibilityText('关闭')
            }.width('calc(100% - 32vp)').padding(16).margin({ bottom: 24 })
              .backgroundColor(this.themeAppBackground.length > 0 ? Color.Transparent : (this.themePureBlack ? '#121212' : this.themeColorSurfaceElevated)).borderRadius(16)
              .transition(TransitionEffect.OPACITY.animation({ duration: DURATION_FADE, curve: Curve.EaseInOut }))
          }

          // 上游「主题模式」一个分组里同时放模式三档与配色两行（`ThemeConfigScreen.kt:223`/`:237`），
          // 本地原先拆成两张独立卡，这里合成一张，分隔线由条目自己负责。
          ThemeGroupColumn({ title: '主题模式' }) {
            ThemeGroupItem({ first: true }) {
              ThemeModeSelector({
                selectedMode: this.themeMode === '1' ? 1 : this.themeMode === '2' ? 2 : 0,
                onModeSelected: (mode: number) => this.onThemeModeChange(mode.toString())
              }).padding({ top: 12, bottom: 12 })
            }
            ThemeGroupItem() {
              ThemeColorSelector({
                selectedIndex: this.paletteIndex,
                isDark: this.readerNightMode,
                onPaletteSelected: (index: number) => this.onPaletteChange(index)
              }).padding({ top: 12, bottom: 12 })
            }
          }

          ThemeGroupColumn() {
            ThemeGroupItem({ first: true }) {
              Row() {
                Column() {
                  Text('纯黑深色模式').fontSize(TITLE_MEDIUM).fontColor(this.themeColorTextSecondary)
                }.alignItems(HorizontalAlign.Start).layoutWeight(1)
                // 整行可点：点标题一侧也能切换（对齐上游 SwitchSettingItem）。
                UiSwitchControl({
                  checked: this.pureBlack,
                  interactive: false,
                  onChange: (enabled: boolean) => this.onPureBlackChange(enabled)
                })
              }.width('100%').padding({ left: 16, right: 16, top: 14, bottom: 14 })
                .onClick(() => this.onPureBlackChange(!this.pureBlack))
            }
            ThemeGroupItem() {
              // 上游 `ThemeConfigScreen.kt:948` 是一个 ListSettingItem，点开 `FontSelectSheet`；
              // 本地同样点开 sheet（不再用可展开组承接，展开组放不下搜索/排序/网格）。
              UiAction({showDivider: false, title: '字体设置', detail: this.appFontSummary(),
                onSelect: () => { this.activeSheet = 'font'; } })
            }
            // 上游 `ThemeConfigScreen.kt:266-270`：只有 appTheme == "12"（自定义）时才显示这一行。
            if (this.paletteIndex === 12) {
              ThemeGroupItem() {
                UiAction({showDivider: false, title: '自定义颜色', detail: this.customColorSummary(),
                  onSelect: () => this.onOpenCustomTheme() })
              }
            }
            ThemeGroupItem() {
              // 上游 `ThemeConfigScreen.kt:272-280` 打开 `LauncherIconPickerSheet`（8 个内置图标）；
              // 鸿蒙的图标包由 AGC 下发，改用 `@kit.AppGalleryKit` 的 appInfoManager 查询与切换。
              UiAction({showDivider: false, title: '切换图标', detail: '切换软件显示在桌面的图标',
                onSelect: () => { this.activeSheet = 'launcherIcon'; } })
            }
            ThemeGroupItem() {
              ThemeSwitchRow({ title: '预见性返回手势', detail: '启用系统预见性返回手势', checked: this.predictiveBack, onChange: (value: boolean) => this.onPredictiveBackChange(value) })
            }
            ThemeGroupItem() {
              ThemeSwitchRow({ title: '阅读界面共享元素动画', detail: '进入阅读界面时从封面展开，关闭后使用渐变过渡', checked: this.readerSharedElement, onChange: (value: boolean) => this.onReaderSharedElementChange(value) })
            }
            ThemeGroupItem() {
              Column() {
                Row() {
                  Text('字体大小').fontSize(TITLE_MEDIUM).fontColor(this.themeColorTextSecondary).layoutWeight(1)
                  Text(`当前字体大小: ${(this.fontScale / 10).toFixed(1)}`).fontSize(TITLE_SMALL).fontColor(this.themeColorTextTertiary)
                }.width('100%')
                Slider({ value: this.fontScale, min: 8, max: 16, step: 1, style: SliderStyle.OutSet })
                  .width('100%').onChange((value: number) => this.onFontScaleChange(value))
              }.width('100%').padding({ left: 16, right: 16, top: 12, bottom: 8 })
            }
            ThemeGroupItem() {
              UiAction({showDivider: false, title: '主题管理', detail: '管理、导入导出完整主题包', onSelect: () => this.onOpenThemeManage() })
            }
            // 背景图片：上游是 `BackgroundImageManageSheet`（199 行）—— 日夜两格 + 两档虚化滑块，
            // 不是行内展开。本地改走 sheet（`activeSheet = 'backgroundImage'`）。
            ThemeGroupItem() {
              UiAction({showDivider: false, title: '背景图片', detail: this.appBackgroundSummary(), onSelect: () => { this.activeSheet = 'backgroundImage'; } })
            }
          }

          ThemeGroupColumn({ title: '主界面' }) {
            // 首页与导航：上游是 `MainNavigationSettingsSheet`（195 行）—— 默认主页 / 标签显示方式 /
            // 导航栏图标入口 / 可拖拽的显隐列表，不是行内展开。本地改走 sheet。
            ThemeGroupItem({ first: true }) {
              UiAction({showDivider: false, title: '首页与导航', detail: this.navigationSummary(), onSelect: () => { this.activeSheet = 'mainNavigation'; } })
            }
            // 平板界面：上游 `AppShellSettings` 的 tabletInterface 档位，决定底栏还是左侧栏。
            // 四档判据（自动/始终侧栏/横屏侧栏/始终底栏）在 data/MainNavigationSettings.ets。
            ThemeGroupItem() {
              UiDropdown({showDivider: false,
                title: '平板界面',
                option: this.tabletInterface,
                options: TABLET_INTERFACE_VALUES,
                labelOf: (value: string) => tabletInterfaceLabel(value),
                onSelect: (value: string) => this.onTabletInterfaceChange(value)
              })
            }
            ThemeGroupItem() {
              ThemeSwitchRow({ title: '显示状态栏', checked: this.showStatusBarVisible, onChange: (value: boolean) => this.onShowStatusBarChange(value) })
            }
            ThemeGroupItem() {
              ThemeSwitchRow({ title: '启用滑动时动画', checked: this.swipeAnimationEnabled, onChange: (value: boolean) => this.onSwipeAnimationChange(value) })
            }
            ThemeGroupItem() {
              UiAction({showDivider: false, title: '顶栏与底栏', detail: this.topBottomBarSummary(), onSelect: () => { this.activeSheet = 'topBottomBar'; } })
            }
          }

          ThemeGroupColumn({ title: '书籍详情页' }) {
            ThemeGroupItem({ first: true }) {
              ThemeSwitchRow({ title: '界面颜色跟随封面取色', detail: '仅在显示背景封面时生效', checked: this.bookInfoFollowCoverColor, onChange: (value: boolean) => this.onBookInfoFollowCoverColorChange(value) })
            }
            ThemeGroupItem() {
              UiDropdown({showDivider: false, title: '网络封面背景设置', option: this.bookInfoNetworkCoverBackground, labelOf: (value: string) => this.coverBackgroundLabel(value), options: this.coverBackgroundOptions(), onSelect: (value: string) => this.onBookInfoCoverBackgroundChange(false, value) })
            }
            ThemeGroupItem() {
              UiDropdown({showDivider: false, title: '默认封面背景设置', option: this.bookInfoDefaultCoverBackground, labelOf: (value: string) => this.coverBackgroundLabel(value), options: this.coverBackgroundOptions(), onSelect: (value: string) => this.onBookInfoCoverBackgroundChange(true, value) })
            }
            ThemeGroupItem() {
              ThemeSwitchRow({
                title: '无关联规则时按作者搜索',
                detail: '书源未配置关联书籍（relatedBooks）规则时，用当前书源搜索作者名，把作者的其它作品显示为关联书籍',
                checked: this.bookInfoAuthorSearchFallback,
                onChange: (value: boolean) => this.onBookInfoAuthorSearchFallbackChange(value)
              })
            }
          }

          ThemeGroupColumn({ title: '护眼模式' }) {
            ThemeGroupItem({ first: true }) {
              ThemeSwitchRow({ title: '启用护眼模式', detail: '使用暖色调降低蓝光', checked: this.eyeProtectionEnabled, onChange: (value: boolean) => this.onEyeProtectionEnabledChange(value) })
            }
            ThemeGroupItem() {
              ThemeSwitchRow({ title: '深色模式时自动开启', detail: '跟随阅读界面的深色/浅色模式自动切换', checked: this.eyeProtectionAutoNight, onChange: (value: boolean) => this.onEyeProtectionAutoNightChange(value) })
            }
            if (this.eyeProtectionEnabled || this.eyeProtectionAutoNight) {
              ThemeGroupItem() {
                UiSlider({showDivider: false,
                  title: '色温',
                  detail: this.eyeProtectionActive ? `当前生效：${this.eyeProtectionIntensity}` : `强度 ${this.eyeProtectionIntensity}`,
                  value: this.eyeProtectionIntensity,
                  minValue: 0,
                  maxValue: 100,
                  onChange: (value: number) => this.onEyeProtectionIntensityChange(value)
                })
                  .transition(TransitionEffect.OPACITY.animation({ duration: DURATION_FADE }))
              }
              ThemeGroupItem() {
                ThemeSwitchRow({ title: '定时开启', detail: '仅在设定的时间段内生效', checked: this.eyeProtectionSchedule, onChange: (value: boolean) => this.onEyeProtectionScheduleChange(value) })
                  .transition(TransitionEffect.OPACITY.animation({ duration: DURATION_FADE }))
              }
              if (this.eyeProtectionSchedule) {
                ThemeGroupItem() {
                  UiAction({showDivider: false, title: '开始时间', detail: this.eyeProtectionStartTime, onSelect: () => this.pickEyeProtectionTime(true) })
                    .transition(TransitionEffect.OPACITY.animation({ duration: DURATION_FADE }))
                }
                ThemeGroupItem() {
                  UiAction({showDivider: false, title: '结束时间', detail: this.eyeProtectionEndTime, onSelect: () => this.pickEyeProtectionTime(false) })
                    .transition(TransitionEffect.OPACITY.animation({ duration: DURATION_FADE }))
                }
              }
            }
          }

          ThemeGroupColumn({ title: '模糊效果' }) {
            ThemeGroupItem({ first: true }) {
              ThemeSwitchRow({ title: '启用控件模糊', detail: '顶栏与底栏采样背后内容做毛玻璃', checked: this.enableBlur, onChange: (value: boolean) => this.onEnableBlurChange(value) })
            }
            if (this.enableBlur) {
              ThemeGroupItem() {
                ThemeSwitchRow({ title: '启用渐变模糊', checked: this.enableProgressiveBlur, onChange: (value: boolean) => this.onEnableProgressiveBlurChange(value) })
                  .transition(TransitionEffect.OPACITY.animation({ duration: DURATION_FADE }))
              }
            }
          }

          ThemeGroupColumn({ title: '容器设置' }) {
            ThemeGroupItem({ first: true }) {
              ThemeSwitchRow({ title: '容器背景图', detail: '大容器和项目分别使用独立的日间/夜间图片', checked: this.enableContainerBackgroundImage, onChange: (value: boolean) => this.onEnableContainerBackgroundImageChange(value) })
            }
            if (this.enableContainerBackgroundImage) {
              ThemeGroupItem() {
                UiAction({showDivider: false, title: '大容器背景图片', detail: this.backgroundSummary(this.largeContainerBackgroundLight, this.largeContainerBackgroundDark), onSelect: () => this.onPickContainerBackground(true, false) })
                  .transition(TransitionEffect.OPACITY.animation({ duration: DURATION_FADE }))
              }
              ThemeGroupItem() {
                UiAction({showDivider: false, title: '项目背景图片', detail: this.backgroundSummary(this.itemBackgroundLight, this.itemBackgroundDark), onSelect: () => this.onPickContainerBackground(false, false) })
                  .transition(TransitionEffect.OPACITY.animation({ duration: DURATION_FADE }))
              }
            }
            ThemeGroupItem() {
              UiSlider({showDivider: false,
                title: '容器背景不透明度',
                detail: `${this.containerOpacity}%`,
                value: this.containerOpacity,
                minValue: CONTAINER_OPACITY_MIN,
                maxValue: CONTAINER_OPACITY_MAX,
                onChange: (value: number) => this.onContainerOpacityChange(value)
              })
            }
            // 上游 disable_spliced_group_corner_radius_summary 原文含内部类名「SplicedColumnGroup」，
            // 属上游文案缺陷；本地保留更可读的表述（任务书 6.2 允许偏离）。
            ThemeGroupItem() {
              ThemeSwitchRow({ title: '关闭设置分组圆角', detail: '让设置分组使用直角外轮廓', checked: this.disableGroupCorner, onChange: (value: boolean) => this.onDisableGroupCornerChange(value) })
            }
            ThemeGroupItem() {
              ThemeSwitchRow({ title: '覆盖卡片圆角', detail: '关闭时保留各卡片的默认值', checked: this.overrideCardCorner, onChange: (value: boolean) => this.onOverrideCardCornerChange(value) })
            }
            if (this.overrideCardCorner) {
              ThemeGroupItem() {
                UiSlider({showDivider: false,
                  title: '卡片圆角',
                  detail: `${this.cardCornerRadius}vp`,
                  value: this.cardCornerRadius,
                  minValue: CARD_RADIUS_MIN,
                  maxValue: CARD_RADIUS_MAX,
                  onChange: (value: number) => this.onCardCornerRadiusChange(value)
                })
                  .transition(TransitionEffect.OPACITY.animation({ duration: DURATION_FADE }))
              }
            }
            ThemeGroupItem() {
              ThemeSwitchRow({ title: '覆盖卡片边框', detail: '关闭时保留各卡片的默认值', checked: this.overrideCardBorder, onChange: (value: boolean) => this.onOverrideCardBorderChange(value) })
            }
            if (this.overrideCardBorder) {
              ThemeGroupItem() {
                UiSlider({showDivider: false,
                  title: '边框宽度',
                  detail: `${this.cardBorderWidth}vp`,
                  value: this.cardBorderWidth,
                  minValue: CARD_BORDER_WIDTH_MIN,
                  maxValue: CARD_BORDER_WIDTH_MAX,
                  onChange: (value: number) => this.onCardBorderWidthChange(value)
                })
                  .transition(TransitionEffect.OPACITY.animation({ duration: DURATION_FADE }))
              }
              ThemeGroupItem() {
                UiDropdown({showDivider: false,
                  title: '日间边框颜色',
                  option: this.cardBorderColorDay, labelOf: (value: string) => this.borderColorLabel(value),
                  options: this.cardBorderColorOptions(),
                  onSelect: (value: string) => this.onCardBorderColorChange(false, value)
                })
                  .transition(TransitionEffect.OPACITY.animation({ duration: DURATION_FADE }))
              }
              ThemeGroupItem() {
                UiDropdown({showDivider: false,
                  title: '夜间边框颜色',
                  option: this.cardBorderColorNight, labelOf: (value: string) => this.borderColorLabel(value),
                  options: this.cardBorderColorOptions(),
                  onSelect: (value: string) => this.onCardBorderColorChange(true, value)
                })
                  .transition(TransitionEffect.OPACITY.animation({ duration: DURATION_FADE }))
              }
            }
            ThemeGroupItem() {
              ThemeSwitchRow({ title: '显示分隔线', checked: this.enableItemDivider, onChange: (value: boolean) => this.onEnableItemDividerChange(value) })
            }
            if (this.enableItemDivider) {
              ThemeGroupItem() {
                UiSlider({showDivider: false,
                  title: '分隔线宽度', detail: `${this.dividerWidth}vp`,
                  value: this.dividerWidth, minValue: DIVIDER_WIDTH_MIN, maxValue: DIVIDER_WIDTH_MAX,
                  onChange: (value: number) => this.onDividerWidthChange(value)
                })
                  .transition(TransitionEffect.OPACITY.animation({ duration: DURATION_FADE }))
              }
              ThemeGroupItem() {
                UiSlider({showDivider: false,
                  title: '分隔线长度', detail: `${this.dividerLength}%`,
                  value: this.dividerLength, minValue: DIVIDER_LENGTH_MIN, maxValue: DIVIDER_LENGTH_MAX,
                  onChange: (value: number) => this.onDividerLengthChange(value)
                })
                  .transition(TransitionEffect.OPACITY.animation({ duration: DURATION_FADE }))
              }
              ThemeGroupItem() {
                UiDropdown({showDivider: false,
                  title: '分隔线颜色',
                  option: this.dividerColor, labelOf: (value: string) => this.borderColorLabel(value),
                  options: this.dividerColorOptions(),
                  onSelect: (value: string) => this.onDividerColorChange(value)
                })
                  .transition(TransitionEffect.OPACITY.animation({ duration: DURATION_FADE }))
              }
            }
          }
          ThemeGroupColumn() {
            ThemeGroupItem({ first: true }) {
              UiAction({showDivider: false, title: '恢复默认主题配置', detail: '恢复外观页设置，不影响已保存主题和封面', onSelect: () => this.confirmResetDefaults() })
            }
          }
        }.width('100%').padding({ top: 4, bottom: 18 })
      }.edgeEffect(EdgeEffect.Spring, { alwaysEnabled: false }).layoutWeight(1).scrollBar(BarState.Off).onScroll(() => this.updateHeader())
    }.width('100%').height('100%').backgroundColor(this.themeAppBackground.length > 0 ? Color.Transparent : (this.themePureBlack ? '#000000' : this.themeColorSurfacePrimary))
      .bindSheet(this.activeSheet.length > 0, this.SheetContent(), {
        // 面板高度按内容取：字体/导航图标/启动图标是三行以上长列表，给 620；
        // 背景图片与首页与导航是定长内容，FIT_CONTENT 才不留大片空白。
        height: this.sheetHeight(),
        dragBar: true,
        showClose: false,
        // 上游 `AppModalBottomSheet.kt:62` `sheetContainerColor = surfaceContainer`
        // （本地 `themeColorSurfaceTertiary`）。用 `surfaceContainerHigh`
        // （`themeColorSurfaceElevated`）会与面板里的卡片同色，卡片边界看不出来。
        backgroundColor: this.themeColorSurfaceTertiary,
        onDisappear: () => { this.activeSheet = ''; }
      })
  }
}

@Component
struct ThemeSwitchRow {
  @StorageProp('themeColorTextSecondary') themeColorTextSecondary: string = '#2E3038';
  @StorageProp('themeColorTextTertiary') themeColorTextTertiary: string = '#6A6D77';
  @Prop title: string = '';
  @Prop detail: string = '';
  @Prop checked: boolean = false;
  onChange: (enabled: boolean) => void = (_enabled: boolean) => {};
  build() {
    Row() {
      Column() {
        Text(this.title).fontSize(TITLE_MEDIUM).fontColor(this.themeColorTextSecondary)
        if (this.detail.length > 0) {
          Text(this.detail).fontSize(BODY_SMALL).fontColor(this.themeColorTextTertiary).margin({ top: 3 })
        }
      }.alignItems(HorizontalAlign.Start).layoutWeight(1)
      UiSwitchControl({
        checked: this.checked,
        interactive: false,
        onChange: (enabled: boolean) => this.onChange(enabled)
      })
    }.padding({ left: 16, right: 16, top: 14, bottom: 14 })
      .onClick(() => this.onChange(!this.checked))
  }
}
