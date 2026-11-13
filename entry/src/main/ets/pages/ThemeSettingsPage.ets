import { UiAction } from '../components/settings/UiAction';
import { UiDropdown } from '../components/settings/UiDropdown';
import { UiSlider } from '../components/settings/UiSlider';
import { AppGlyph } from '../components/AppGlyph';
import { appFontDisplayName } from '../data/AppFontSettings';
import { ThemeItemDivider } from '../components/ThemeItemDivider';
import { resolvePaletteColors, THEME_PALETTES, ThemePaletteDefinition } from '../data/ThemePalette';
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
  labelVisibilityLabel,
  mainNavigationLabel,
  orderedMainNavigation
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

@Component
export struct ThemeSettingsPage {
  @StorageProp('themeColorTextPrimary') themeColorTextPrimary: string = '#1B1C22';
  @StorageProp('themeColorTextSecondary') themeColorTextSecondary: string = '#2E3038';
  @StorageProp('themeColorTextTertiary') themeColorTextTertiary: string = '#6A6D77';
  @StorageProp('themeColorAccent') themeColorAccent: string = '#3F5BD9';
  @StorageProp('themeColorSurfacePrimary') themeColorSurfacePrimary: string = '#F5F6F8';
  @StorageProp('themeColorSurfaceSecondary') themeColorSurfaceSecondary: string = '#FFFFFF';
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
  onDefaultHomePageChange: (route: string) => void = () => {};
  onLabelVisibilityModeChange: (value: string) => void = () => {};
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
  /** 「字体设置」组是否展开；上游是一个 sheet（`FontSelectSheet`），本地用可展开组承接。 */
  @State appFontExpanded: boolean = false;
  /** 「顶栏与底栏」组是否展开。上游是一个 sheet，本地用可展开组承接。 */
  @State topBottomBarExpanded: boolean = false;
  @State collapsedHeader: boolean = false;
  /** 顶栏底色（含不透明度与模糊透明度），由 `Index.publishTopBottomBarStyle()` 广播。 */
  @StorageProp('themeTopBarBackground') themeTopBarBackground: string = '';
  /** 顶栏模糊半径；0 表示不模糊。 */
  @StorageProp('themeTopBarBlurRadius') themeTopBarBlurRadius: number = 0;
  private themeScroller: Scroller = new Scroller();

  private updateHeader(): void {
    const offset = this.themeScroller.currentOffset().yOffset;
    const shouldCollapse = offset > 70 ? true : offset < 24 ? false : this.collapsedHeader;
    if (shouldCollapse !== this.collapsedHeader) {
      animateTo({ duration: 220, curve: Curve.EaseInOut }, () => this.collapsedHeader = shouldCollapse);
    }
  }

  /**
   * 调色板预览色：查 `data/ThemePalette.ets` 的 14 套表。
   *
   * 上游 `ThemeColorButton`（`ThemeConfigScreen.kt:1077`）用 `getThemeColorPalette(...)` 现算一套配色，
   * 卡片底色取 `surfaceContainer`、48dp 圆上半圆取 `secondary`、下半圆取 `tertiary`、中心 24dp 圆取 `primary`。
   * 本地照抄这四处取色，日间/夜间按当前 `themeMode` 派生，所以点「深色」后预览色块也跟着换。
   */
  private paletteColor(index: number): string {
    return resolvePaletteColors(index, this.readerNightMode).surfaceContainer;
  }

  private paletteArcColor(index: number, upper: boolean): string {
    const colors = resolvePaletteColors(index, this.readerNightMode);
    return upper ? colors.secondary : colors.tertiary;
  }

  private paletteCenterColor(index: number): string {
    return resolvePaletteColors(index, this.readerNightMode).primary;
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

  private navigationSummary(): string {
    const visible: string[] = this.visibleNavigationOptions();
    const hidden = 3 - (this.showHome ? 1 : 0) - (this.showDiscovery ? 1 : 0) - (this.showRss ? 1 : 0);
    const base = `默认 ${mainNavigationLabel(this.defaultHomePage)}`;
    return hidden > 0 ? `${base} · 隐藏 ${hidden} 项` : `${base} · ${visible.length} 项`;
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

  @StorageProp('themeCardRadius') themeCardRadius: number = 16;
  @StorageProp('themeCardBorderWidth') themeCardBorderWidth: number = 0;
  @StorageProp('themeCardBorderColor') themeCardBorderColor: string = '#6A6D77';
  @StorageProp('themeCardBackground') themeCardBackground: string = '';
  @StorageProp('themeContainerBackground') themeContainerBackground: string = '';
  build() {
    Column() {
      Column() {
        Row() {
          Stack({ alignContent: Alignment.Center }) {
            Image($r('app.media.reader_back')).width(20).height(20).fillColor(this.themeColorTextSecondary)
          }.width(40).height(40).onClick(() => this.onBack())
          Text('外观').fontSize(22).fontWeight(FontWeight.Medium).fontColor(this.themeColorTextPrimary)
            .opacity(this.collapsedHeader ? 1 : 0)
          Blank()
        }.width('100%').height(64).padding({ left: 12, right: 16 })
        Text('外观').fontSize(28).fontWeight(FontWeight.Medium).fontColor(this.themeColorTextPrimary)
          .width('100%').height(72).padding({ left: 16, bottom: 14 })
          .opacity(this.collapsedHeader ? 0 : 1)
      }.width('100%').height(this.collapsedHeader ? 64 : 136).clip(true)
        .backgroundColor(this.themeTopBarBackground.length > 0 ? this.themeTopBarBackground
          : (this.themeAppBackground.length > 0 ? Color.Transparent
            : (this.themePureBlack ? '#000000' : this.themeColorSurfacePrimary)))
        .backdropBlur(this.themeTopBarBlurRadius)

      Scroll(this.themeScroller) {
        Column() {
          Column() {
            Column() {
              Row().width(54).height(12).backgroundColor('#AEB0B8').borderRadius(6)
              Column() {
                Row().width(30).height(5).backgroundColor(this.themeColorAccent).borderRadius(3)
                Row().width(42).height(7).backgroundColor(this.themeColorTextSecondary).borderRadius(4).margin({ top: 8 })
                Row().width(34).height(6).backgroundColor('#858792').borderRadius(3).margin({ top: 5 })
              }.width(62).height(95).padding(9).margin({ top: 8 }).backgroundColor('#454B62').borderRadius(8)
                .alignItems(HorizontalAlign.Start)
            }.width('100%').alignItems(HorizontalAlign.Start)
            Blank().layoutWeight(1)
            Row() {
              Row().width(28).height(8).backgroundColor(this.themeColorAccent).borderRadius(5)
              Blank()
              Row().width(14).height(14).backgroundColor(this.themeColorAccent).borderRadius(7)
            }.width('100%').padding({ left: 8, right: 8, top: 10, bottom: 10 })
              .backgroundColor(this.themeAppBackground.length > 0 ? Color.Transparent : (this.themePureBlack ? '#121212' : this.themeColorSurfaceElevated)).borderRadius(10)
          }.width(112).height(224).padding(10).backgroundColor(this.themeAppBackground.length > 0 ? Color.Transparent : (this.themePureBlack ? '#000000' : this.themeColorSurfacePrimary)).borderRadius(22)
            .border({ width: 1, color: this.themeColorAccent })
            .alignSelf(ItemAlign.Center).margin({ top: 18, bottom: 16 })

          if (this.showRefactorTip) {
            Row() {
              Text('仍有部分界面未用Compose重构，这些界面会与大部分界面有较大差异。')
                .fontSize(14).fontColor(this.themeColorTextSecondary).layoutWeight(1)
              AppGlyph({ name: 'profileClose', glyphSize: 18, tint: '#C5C7D0' })
                .onClick(() => this.showRefactorTip = false)
            }.width('calc(100% - 32vp)').padding(16).margin({ bottom: 24 })
              .backgroundColor(this.themeAppBackground.length > 0 ? Color.Transparent : (this.themePureBlack ? '#121212' : this.themeColorSurfaceElevated)).borderRadius(16)
              .transition(TransitionEffect.OPACITY.animation({ duration: 220, curve: Curve.EaseInOut }))
          }

          ThemeSectionTitle({ title: '主题模式' })
          Row() {
            ThemeModeItem({ title: '跟随系统', selected: this.themeMode === '0', first: true,
              onSelect: () => this.onThemeModeChange('0') })
            ThemeModeItem({ title: '浅色', selected: this.themeMode === '1',
              onSelect: () => this.onThemeModeChange('1') })
            ThemeModeItem({ title: '深色', selected: this.themeMode === '2', last: true,
              onSelect: () => this.onThemeModeChange('2') })
          }.width('calc(100% - 32vp)').margin({ left: 16, right: 16, bottom: 18 })
            .backgroundColor(this.themeCardBackground.length > 0 ? this.themeCardBackground : this.themeColorSurfaceSecondary).borderRadius(this.themeCardRadius).border({ width: this.themeCardBorderWidth, color: this.themeCardBorderColor }).backgroundImage(this.themeContainerBackground.length > 0 ? `file://${this.themeContainerBackground}` : $r('app.media.transparent_pixel'), ImageRepeat.NoRepeat)

          // 上游是 `LazyRow`（横向滚动、间距 16dp），14 项一屏放不下，所以横向 Scroll + 每项 64vp 固定宽。
          Scroll() {
            Row() {
              ForEach(THEME_PALETTES, (palette: ThemePaletteDefinition) => {
                ThemePaletteItem({
                  index: palette.index,
                  title: palette.name,
                  surfaceColor: this.paletteColor(palette.index),
                  upperColor: this.paletteArcColor(palette.index, true),
                  lowerColor: this.paletteArcColor(palette.index, false),
                  centerColor: this.paletteCenterColor(palette.index),
                  selected: this.paletteIndex === palette.index,
                  onSelect: () => this.onPaletteChange(palette.index)
                })
              }, (palette: ThemePaletteDefinition) => palette.index.toString())
            }.padding({ left: 16, right: 16 })
          }.scrollable(ScrollDirection.Horizontal).scrollBar(BarState.Off)
            .width('100%').align(Alignment.Start).padding({ bottom: 20 })

          Column() {
            Row() {
              Column() {
                Text('纯黑深色模式').fontSize(16).fontColor(this.themeColorTextSecondary)
                Text('使用纯黑阅读背景').fontSize(13).fontColor(this.themeColorTextTertiary).margin({ top: 3 })
              }.alignItems(HorizontalAlign.Start).layoutWeight(1)
              Toggle({ type: ToggleType.Switch, isOn: this.pureBlack })
                .onChange((enabled: boolean) => this.onPureBlackChange(enabled))
            }.padding({ left: 16, right: 16, top: 14, bottom: 14 })
            ThemeItemDivider()
            UiAction({ title: '字体设置', detail: this.appFontSummary(),
              onSelect: () => { this.appFontExpanded = !this.appFontExpanded } })
            if (this.appFontExpanded) {
              ThemeItemDivider()
              UiAction({ title: '选择字体文件', detail: '支持 .ttf / .otf / .ttc', onSelect: () => this.onPickAppFont() })
              ThemeItemDivider()
              UiAction({ title: '恢复系统字体', detail: '清除已选择的应用字体', onSelect: () => this.onClearAppFont() })
            }
            ThemeItemDivider()
            // 上游 `ThemeConfigScreen.kt:266-270`：只有 appTheme == "12"（自定义）时才显示这一行。
            if (this.paletteIndex === 12) {
              UiAction({ title: '自定义颜色', detail: this.customColorSummary(),
                onSelect: () => this.onOpenCustomTheme() })
              ThemeItemDivider()
            }
            UiAction({ title: '主题风格', detail: 'Material Design', onSelect: () => this.onUnavailableAction('主题风格切换尚未接入') })
            ThemeItemDivider()
            UiAction({ title: '切换图标', detail: '切换软件显示在桌面的图标', onSelect: () => this.onUnavailableAction('启动图标设置尚未迁移') })
            ThemeItemDivider()
            ThemeSwitchRow({ title: '预见性返回手势', detail: '启用系统预见性返回手势', checked: this.predictiveBack, onChange: (value: boolean) => this.onPredictiveBackChange(value) })
            ThemeItemDivider()
            ThemeSwitchRow({ title: '阅读界面共享元素动画', detail: '进入阅读界面时从封面展开，关闭后使用渐变过渡', checked: this.readerSharedElement, onChange: (value: boolean) => this.onReaderSharedElementChange(value) })
            ThemeItemDivider()
            Column() {
              Row() {
                Text('字体大小').fontSize(16).fontColor(this.themeColorTextSecondary).layoutWeight(1)
                Text(`${(this.fontScale / 10).toFixed(1)}x`).fontSize(14).fontColor(this.themeColorTextTertiary)
              }.width('100%')
              Slider({ value: this.fontScale, min: 8, max: 16, step: 1, style: SliderStyle.OutSet })
                .width('100%').onChange((value: number) => this.onFontScaleChange(value))
            }.width('100%').padding({ left: 16, right: 16, top: 12, bottom: 8 })
            ThemeItemDivider()
            UiAction({ title: '主题管理', detail: '管理、导入导出完整主题包', onSelect: () => this.onOpenThemeManage() })
            ThemeItemDivider()
            UiAction({ title: '背景图片', detail: this.appBackgroundSummary(), onSelect: () => { this.backgroundExpanded = !this.backgroundExpanded } })
            if (this.backgroundExpanded) {
              UiAction({ title: '日间背景图片', detail: this.appBackgroundImage.length > 0 ? '已选择，点击换图' : '选择图片', onSelect: () => this.onPickBackgroundImage(false) })
              ThemeItemDivider()
              Slider({ value: this.appBackgroundBlur, min: 0, max: 40, step: 1, style: SliderStyle.OutSet })
                .width('100%').padding({ left: 16, right: 16 }).onChange((value: number) => this.onBackgroundBlurChange(false, value))
              ThemeItemDivider()
              UiAction({ title: '夜间背景图片', detail: this.appBackgroundImageNight.length > 0 ? '已选择，点击换图' : '选择图片', onSelect: () => this.onPickBackgroundImage(true) })
              ThemeItemDivider()
              Slider({ value: this.appBackgroundNightBlur, min: 0, max: 40, step: 1, style: SliderStyle.OutSet })
                .width('100%').padding({ left: 16, right: 16 }).onChange((value: number) => this.onBackgroundBlurChange(true, value))
              ThemeItemDivider()
              UiAction({ title: '移除背景图片', detail: '同时清空日间与夜间', onSelect: () => { this.onClearBackgroundImage(false); this.onClearBackgroundImage(true); } })
            }
          }.width('calc(100% - 32vp)').margin({ left: 16, right: 16 }).backgroundColor(this.themeCardBackground.length > 0 ? this.themeCardBackground : this.themeColorSurfaceSecondary).borderRadius(this.themeCardRadius).border({ width: this.themeCardBorderWidth, color: this.themeCardBorderColor }).backgroundImage(this.themeContainerBackground.length > 0 ? `file://${this.themeContainerBackground}` : $r('app.media.transparent_pixel'), ImageRepeat.NoRepeat)

          ThemeSectionTitle({ title: '主界面' }).margin({ top: 20 })
          Column() {
            UiAction({ title: '首页与导航', detail: this.navigationSummary(), onSelect: () => { this.navigationExpanded = !this.navigationExpanded; } })
            if (this.navigationExpanded) {
              Column() {
                // 逐项显隐：上游 `setVisibilityForRoute`，书架与我的恒可见。
                ThemeSwitchRow({ title: '首页', detail: '在底部导航显示首页', checked: this.showHome, onChange: (value: boolean) => this.onNavigationVisibilityChange('home', value) })
                ThemeItemDivider()
                ThemeSwitchRow({ title: '发现', detail: '在底部导航显示发现', checked: this.showDiscovery, onChange: (value: boolean) => this.onNavigationVisibilityChange('explore', value) })
                ThemeItemDivider()
                ThemeSwitchRow({ title: '订阅', detail: '在底部导航显示订阅', checked: this.showRss, onChange: (value: boolean) => this.onNavigationVisibilityChange('rss', value) })
                ThemeItemDivider()
                // 默认主页面：只能选可见项，对齐上游 `MainNavigationSettingsSheet.kt:81-84`。
                UiDropdown({
                  title: '默认主页面',
                  option: this.defaultHomePage,
                  options: this.visibleNavigationOptions(),
                  labelOf: (value: string) => mainNavigationLabel(value),
                  onSelect: (value: string) => this.onDefaultHomePageChange(value)
                })
                ThemeItemDivider()
                UiDropdown({
                  title: '导航标签显示',
                  option: this.labelVisibilityMode,
                  options: LABEL_VISIBILITY_VALUES,
                  labelOf: (value: string) => labelVisibilityLabel(value),
                  onSelect: (value: string) => this.onLabelVisibilityModeChange(value)
                })
                ThemeItemDivider()
                // 拖排顺序：上游用可拖列表，本地用上下移两枚按钮承接同一个 onSetOrder。
                Text('主导航顺序').fontSize(16).fontColor(this.themeColorTextSecondary).width('100%').padding({ left: 16, right: 16, top: 12, bottom: 4 })
                ForEach(orderedMainNavigation(this.mainNavigationOrder), (navRoute: string) => {
                  Row() {
                    Text(mainNavigationLabel(navRoute)).fontSize(15).fontColor(this.themeColorTextTertiary).layoutWeight(1)
                    Button('上移').fontSize(13).height(32).backgroundColor(this.themeColorSurfaceTertiary).fontColor(this.themeColorTextSecondary).onClick(() => this.onNavigationMove(navRoute, true))
                    Button('下移').fontSize(13).height(32).margin({ left: 8 }).backgroundColor(this.themeColorSurfaceTertiary).fontColor(this.themeColorTextSecondary).onClick(() => this.onNavigationMove(navRoute, false))
                  }.width('100%').padding({ left: 16, right: 16, top: 6, bottom: 6 })
                }, (navRoute: string) => navRoute)
              }
              .transition(TransitionEffect.OPACITY.animation({ duration: 220 }))
            }
            ThemeItemDivider()
            ThemeSwitchRow({ title: '显示状态栏', checked: this.showStatusBarVisible, onChange: (value: boolean) => this.onShowStatusBarChange(value) })
            ThemeItemDivider()
            ThemeSwitchRow({ title: '启用滑动时动画', checked: this.swipeAnimationEnabled, onChange: (value: boolean) => this.onSwipeAnimationChange(value) })
            ThemeItemDivider()
            UiAction({ title: '顶栏与底栏', detail: this.topBottomBarSummary(), onSelect: () => { this.topBottomBarExpanded = !this.topBottomBarExpanded } })
            if (this.topBottomBarExpanded) {
              Column() {
                ThemeSwitchRow({ title: '使用折叠应用栏', checked: this.useFlexibleTopAppBar, onChange: (value: boolean) => this.onUseFlexibleTopAppBarChange(value) })
                ThemeItemDivider()
                UiDropdown({
                  title: '顶栏按钮样式',
                  option: this.topBarButtonStyle,
                  options: TOP_BAR_BUTTON_STYLES,
                  labelOf: (value: string) => topBarButtonStyleLabel(value),
                  onSelect: (value: string) => this.onTopBarButtonStyleChange(value)
                })
                ThemeItemDivider()
                if (this.topBarButtonStyle !== 'plain') {
                  ThemeSwitchRow({ title: '合并顶栏按钮', checked: this.mergeTopBarActions, onChange: (value: boolean) => this.onMergeTopBarActionsChange(value) })
                    .transition(TransitionEffect.OPACITY.animation({ duration: 220 }))
                  ThemeItemDivider()
                }
                ThemeSwitchRow({ title: '显示导航栏', detail: '仍可滑动切换页面', checked: this.showBottomView, onChange: (value: boolean) => this.onShowBottomViewChange(value) })
                ThemeItemDivider()
                ThemeSwitchRow({ title: '悬浮底栏', detail: '底部导航栏使用悬浮胶囊样式', checked: this.useFloatingBottomBar, onChange: (value: boolean) => this.onUseFloatingBottomBarChange(value) })
                if (this.useFloatingBottomBar) {
                  ThemeItemDivider()
                  ThemeSwitchRow({ title: '液态玻璃效果', detail: '为悬浮底栏启用液态玻璃高光效果', checked: this.useFloatingBottomBarLiquidGlass, onChange: (value: boolean) => this.onUseFloatingBottomBarLiquidGlassChange(value) })
                    .transition(TransitionEffect.OPACITY.animation({ duration: 220 }))
                  ThemeItemDivider()
                  UiSlider({
                    title: '底栏模糊强度',
                    detail: `液态玻璃扭曲程度 ${this.bottomBarLensRadius}vp`,
                    value: this.bottomBarLensRadius,
                    minValue: BOTTOM_BAR_LENS_RADIUS_MIN,
                    maxValue: BOTTOM_BAR_LENS_RADIUS_MAX,
                    onChange: (value: number) => this.onBottomBarLensRadiusChange(value)
                  })
                }
                ThemeItemDivider()
                if (this.enableBlur) {
                  UiSlider({
                    title: '顶栏模糊半径',
                    detail: `采样模糊强度 ${this.topBarBlurRadius}`,
                    value: this.topBarBlurRadius,
                    minValue: TOP_BAR_BLUR_RADIUS_MIN,
                    maxValue: TOP_BAR_BLUR_RADIUS_MAX,
                    onChange: (value: number) => this.onTopBarBlurRadiusChange(value)
                  })
                  ThemeItemDivider()
                  UiSlider({
                    title: '底栏模糊半径',
                    detail: `采样模糊强度 ${this.bottomBarBlurRadius}`,
                    value: this.bottomBarBlurRadius,
                    minValue: BOTTOM_BAR_BLUR_RADIUS_MIN,
                    maxValue: BOTTOM_BAR_BLUR_RADIUS_MAX,
                    onChange: (value: number) => this.onBottomBarBlurRadiusChange(value)
                  })
                  ThemeItemDivider()
                  UiSlider({
                    title: '顶栏模糊透明度',
                    detail: `${this.topBarBlurAlpha}%`,
                    value: this.topBarBlurAlpha,
                    minValue: BAR_BLUR_ALPHA_MIN,
                    maxValue: BAR_BLUR_ALPHA_MAX,
                    onChange: (value: number) => this.onTopBarBlurAlphaChange(value)
                  })
                  ThemeItemDivider()
                  UiSlider({
                    title: '底栏模糊透明度',
                    detail: `${this.bottomBarBlurAlpha}%`,
                    value: this.bottomBarBlurAlpha,
                    minValue: BAR_BLUR_ALPHA_MIN,
                    maxValue: BAR_BLUR_ALPHA_MAX,
                    onChange: (value: number) => this.onBottomBarBlurAlphaChange(value)
                  })
                } else {
                  UiSlider({
                    title: '顶栏不透明度',
                    detail: `${this.topBarOpacity}%`,
                    value: this.topBarOpacity,
                    minValue: TOP_BAR_OPACITY_MIN,
                    maxValue: TOP_BAR_OPACITY_MAX,
                    onChange: (value: number) => this.onTopBarOpacityChange(value)
                  })
                  ThemeItemDivider()
                  UiSlider({
                    title: '底栏不透明度',
                    detail: `${this.bottomBarOpacity}%`,
                    value: this.bottomBarOpacity,
                    minValue: TOP_BAR_OPACITY_MIN,
                    maxValue: TOP_BAR_OPACITY_MAX,
                    onChange: (value: number) => this.onBottomBarOpacityChange(value)
                  })
                }
              }
              .transition(TransitionEffect.OPACITY.animation({ duration: 220 }))
            }
            ThemeItemDivider()
            UiAction({ title: '导航布局', detail: '', onSelect: () => this.onUnavailableAction('导航布局设置尚未迁移') })
            ThemeItemDivider()
            UiAction({ title: '多窗布局', detail: '', onSelect: () => this.onUnavailableAction('多窗布局设置尚未迁移') })
          }.width('calc(100% - 32vp)').margin({ left: 16, right: 16 }).backgroundColor(this.themeCardBackground.length > 0 ? this.themeCardBackground : this.themeColorSurfaceSecondary).borderRadius(this.themeCardRadius).border({ width: this.themeCardBorderWidth, color: this.themeCardBorderColor }).backgroundImage(this.themeContainerBackground.length > 0 ? `file://${this.themeContainerBackground}` : $r('app.media.transparent_pixel'), ImageRepeat.NoRepeat)

          ThemeSectionTitle({ title: '书籍详情页' }).margin({ top: 20 })
          Column() {
            ThemeSwitchRow({ title: '界面颜色跟随封面取色', detail: '仅在显示背景封面时生效', checked: this.bookInfoFollowCoverColor, onChange: (value: boolean) => this.onBookInfoFollowCoverColorChange(value) })
            ThemeItemDivider()
            UiDropdown({ title: '网络封面背景设置', option: this.bookInfoNetworkCoverBackground, labelOf: (value: string) => this.coverBackgroundLabel(value), options: this.coverBackgroundOptions(), onSelect: (value: string) => this.onBookInfoCoverBackgroundChange(false, value) })
            ThemeItemDivider()
            UiDropdown({ title: '默认封面背景设置', option: this.bookInfoDefaultCoverBackground, labelOf: (value: string) => this.coverBackgroundLabel(value), options: this.coverBackgroundOptions(), onSelect: (value: string) => this.onBookInfoCoverBackgroundChange(true, value) })
          }.width('calc(100% - 32vp)').margin({ left: 16, right: 16 }).backgroundColor(this.themeCardBackground.length > 0 ? this.themeCardBackground : this.themeColorSurfaceSecondary).borderRadius(this.themeCardRadius).border({ width: this.themeCardBorderWidth, color: this.themeCardBorderColor }).backgroundImage(this.themeContainerBackground.length > 0 ? `file://${this.themeContainerBackground}` : $r('app.media.transparent_pixel'), ImageRepeat.NoRepeat)

          ThemeSectionTitle({ title: '护眼模式' }).margin({ top: 20 })
          Column() {
            ThemeSwitchRow({ title: '启用护眼模式', detail: '使用暖色调降低蓝光', checked: this.eyeProtectionEnabled, onChange: (value: boolean) => this.onEyeProtectionEnabledChange(value) })
            ThemeItemDivider()
            ThemeSwitchRow({ title: '深色模式时自动开启', detail: '跟随阅读界面的深色/浅色模式自动切换', checked: this.eyeProtectionAutoNight, onChange: (value: boolean) => this.onEyeProtectionAutoNightChange(value) })
            ThemeItemDivider()
            if (this.eyeProtectionEnabled || this.eyeProtectionAutoNight) {
              UiSlider({
                title: '色温',
                detail: this.eyeProtectionActive ? `当前生效：${this.eyeProtectionIntensity}` : `强度 ${this.eyeProtectionIntensity}`,
                value: this.eyeProtectionIntensity,
                minValue: 0,
                maxValue: 100,
                onChange: (value: number) => this.onEyeProtectionIntensityChange(value)
              })
                .transition(TransitionEffect.OPACITY.animation({ duration: 220 }))
              ThemeSwitchRow({ title: '定时开启', detail: '仅在设定的时间段内生效', checked: this.eyeProtectionSchedule, onChange: (value: boolean) => this.onEyeProtectionScheduleChange(value) })
                .transition(TransitionEffect.OPACITY.animation({ duration: 220 }))
              if (this.eyeProtectionSchedule) {
                UiAction({ title: '开始时间', detail: this.eyeProtectionStartTime, onSelect: () => this.pickEyeProtectionTime(true) })
                  .transition(TransitionEffect.OPACITY.animation({ duration: 220 }))
                UiAction({ title: '结束时间', detail: this.eyeProtectionEndTime, onSelect: () => this.pickEyeProtectionTime(false) })
                  .transition(TransitionEffect.OPACITY.animation({ duration: 220 }))
              }
            }
          }.width('calc(100% - 32vp)').margin({ left: 16, right: 16 }).backgroundColor(this.themeCardBackground.length > 0 ? this.themeCardBackground : this.themeColorSurfaceSecondary).borderRadius(this.themeCardRadius).border({ width: this.themeCardBorderWidth, color: this.themeCardBorderColor }).backgroundImage(this.themeContainerBackground.length > 0 ? `file://${this.themeContainerBackground}` : $r('app.media.transparent_pixel'), ImageRepeat.NoRepeat)

          ThemeSectionTitle({ title: '模糊效果' }).margin({ top: 20 })
          Column() {
            ThemeSwitchRow({ title: '启用控件模糊', detail: '顶栏与底栏采样背后内容做毛玻璃', checked: this.enableBlur, onChange: (value: boolean) => this.onEnableBlurChange(value) })
            ThemeItemDivider()
            if (this.enableBlur) {
              ThemeSwitchRow({ title: '启用渐变模糊', checked: this.enableProgressiveBlur, onChange: (value: boolean) => this.onEnableProgressiveBlurChange(value) })
                .transition(TransitionEffect.OPACITY.animation({ duration: 220 }))
            }
          }.width('calc(100% - 32vp)').margin({ left: 16, right: 16 }).backgroundColor(this.themeCardBackground.length > 0 ? this.themeCardBackground : this.themeColorSurfaceSecondary).borderRadius(this.themeCardRadius).border({ width: this.themeCardBorderWidth, color: this.themeCardBorderColor }).backgroundImage(this.themeContainerBackground.length > 0 ? `file://${this.themeContainerBackground}` : $r('app.media.transparent_pixel'), ImageRepeat.NoRepeat)

          ThemeSectionTitle({ title: '容器设置' }).margin({ top: 20 })
          Column() {
            ThemeSwitchRow({ title: '容器背景图', detail: '大容器和项目分别使用独立的日间/夜间图片', checked: this.enableContainerBackgroundImage, onChange: (value: boolean) => this.onEnableContainerBackgroundImageChange(value) })
            ThemeItemDivider()
            if (this.enableContainerBackgroundImage) {
              UiAction({ title: '大容器背景图片', detail: this.backgroundSummary(this.largeContainerBackgroundLight, this.largeContainerBackgroundDark), onSelect: () => this.onPickContainerBackground(true, false) })
                .transition(TransitionEffect.OPACITY.animation({ duration: 220 }))
              ThemeItemDivider()
              UiAction({ title: '项目背景图片', detail: this.backgroundSummary(this.itemBackgroundLight, this.itemBackgroundDark), onSelect: () => this.onPickContainerBackground(false, false) })
                .transition(TransitionEffect.OPACITY.animation({ duration: 220 }))
            }
            ThemeItemDivider()
            UiSlider({
              title: '容器背景不透明度',
              detail: `${this.containerOpacity}%`,
              value: this.containerOpacity,
              minValue: CONTAINER_OPACITY_MIN,
              maxValue: CONTAINER_OPACITY_MAX,
              onChange: (value: number) => this.onContainerOpacityChange(value)
            })
            ThemeItemDivider()
            ThemeSwitchRow({ title: '关闭设置分组圆角', detail: '让设置分组使用直角外轮廓', checked: this.disableGroupCorner, onChange: (value: boolean) => this.onDisableGroupCornerChange(value) })
            ThemeItemDivider()
            ThemeSwitchRow({ title: '覆盖卡片圆角', detail: '关闭时保留各卡片的默认值', checked: this.overrideCardCorner, onChange: (value: boolean) => this.onOverrideCardCornerChange(value) })
            ThemeItemDivider()
            if (this.overrideCardCorner) {
              UiSlider({
                title: '卡片圆角',
                detail: `${this.cardCornerRadius}vp`,
                value: this.cardCornerRadius,
                minValue: CARD_RADIUS_MIN,
                maxValue: CARD_RADIUS_MAX,
                onChange: (value: number) => this.onCardCornerRadiusChange(value)
              })
                .transition(TransitionEffect.OPACITY.animation({ duration: 220 }))
            }
            ThemeItemDivider()
            ThemeSwitchRow({ title: '覆盖卡片边框', detail: '关闭时保留各卡片的默认值', checked: this.overrideCardBorder, onChange: (value: boolean) => this.onOverrideCardBorderChange(value) })
            ThemeItemDivider()
            if (this.overrideCardBorder) {
              UiSlider({
                title: '边框宽度',
                detail: `${this.cardBorderWidth}vp`,
                value: this.cardBorderWidth,
                minValue: CARD_BORDER_WIDTH_MIN,
                maxValue: CARD_BORDER_WIDTH_MAX,
                onChange: (value: number) => this.onCardBorderWidthChange(value)
              })
                .transition(TransitionEffect.OPACITY.animation({ duration: 220 }))
              UiDropdown({
                title: '日间边框颜色',
                option: this.cardBorderColorDay, labelOf: (value: string) => this.borderColorLabel(value),
                options: this.cardBorderColorOptions(),
                onSelect: (value: string) => this.onCardBorderColorChange(false, value)
              })
                .transition(TransitionEffect.OPACITY.animation({ duration: 220 }))
              UiDropdown({
                title: '夜间边框颜色',
                option: this.cardBorderColorNight, labelOf: (value: string) => this.borderColorLabel(value),
                options: this.cardBorderColorOptions(),
                onSelect: (value: string) => this.onCardBorderColorChange(true, value)
              })
                .transition(TransitionEffect.OPACITY.animation({ duration: 220 }))
            }
            ThemeItemDivider()
            ThemeSwitchRow({ title: '显示分隔线', checked: this.enableItemDivider, onChange: (value: boolean) => this.onEnableItemDividerChange(value) })
            ThemeItemDivider()
            if (this.enableItemDivider) {
              UiSlider({
                title: '分隔线宽度', detail: `${this.dividerWidth}vp`,
                value: this.dividerWidth, minValue: DIVIDER_WIDTH_MIN, maxValue: DIVIDER_WIDTH_MAX,
                onChange: (value: number) => this.onDividerWidthChange(value)
              })
                .transition(TransitionEffect.OPACITY.animation({ duration: 220 }))
              UiSlider({
                title: '分隔线长度', detail: `${this.dividerLength}%`,
                value: this.dividerLength, minValue: DIVIDER_LENGTH_MIN, maxValue: DIVIDER_LENGTH_MAX,
                onChange: (value: number) => this.onDividerLengthChange(value)
              })
                .transition(TransitionEffect.OPACITY.animation({ duration: 220 }))
              UiDropdown({
                title: '分隔线颜色',
                option: this.dividerColor, labelOf: (value: string) => this.borderColorLabel(value),
                options: this.dividerColorOptions(),
                onSelect: (value: string) => this.onDividerColorChange(value)
              })
                .transition(TransitionEffect.OPACITY.animation({ duration: 220 }))
            }
          }.width('calc(100% - 32vp)').margin({ left: 16, right: 16 }).backgroundColor(this.themeCardBackground.length > 0 ? this.themeCardBackground : this.themeColorSurfaceSecondary).borderRadius(this.themeCardRadius).border({ width: this.themeCardBorderWidth, color: this.themeCardBorderColor }).backgroundImage(this.themeContainerBackground.length > 0 ? `file://${this.themeContainerBackground}` : $r('app.media.transparent_pixel'), ImageRepeat.NoRepeat)
          Column() {
            UiAction({ title: '恢复默认主题配置', detail: '恢复外观页设置，不影响已保存主题和封面', onSelect: () => this.confirmResetDefaults() })
          }.width('calc(100% - 32vp)').margin({ left: 16, right: 16, top: 20 }).backgroundColor(this.themeCardBackground.length > 0 ? this.themeCardBackground : this.themeColorSurfaceSecondary).borderRadius(this.themeCardRadius).border({ width: this.themeCardBorderWidth, color: this.themeCardBorderColor }).backgroundImage(this.themeContainerBackground.length > 0 ? `file://${this.themeContainerBackground}` : $r('app.media.transparent_pixel'), ImageRepeat.NoRepeat)
        }.width('100%').padding({ top: 4, bottom: 18 })
      }.layoutWeight(1).scrollBar(BarState.Off).onScroll(() => this.updateHeader())
    }.width('100%').height('100%').backgroundColor(this.themeAppBackground.length > 0 ? Color.Transparent : (this.themePureBlack ? '#000000' : this.themeColorSurfacePrimary))
  }
}

@Component
struct ThemeSectionTitle {
  @StorageProp('themeColorAccent') themeColorAccent: string = '#3F5BD9';
  @Prop title: string = '';
  build() {
    Text(this.title).fontSize(15).fontWeight(FontWeight.Medium).fontColor(this.themeColorAccent)
      .alignSelf(ItemAlign.Start).margin({ left: 18, bottom: 9 })
  }
}

@Component
struct ThemeModeItem {
  @Prop title: string = '';
  @Prop selected: boolean = false;
  @Prop first: boolean = false;
  @Prop last: boolean = false;
  onSelect: () => void = () => {};
  build() {
    Text(this.title).fontSize(14).fontColor(this.selected ? '#F0F1F5' : '#AEB0B9')
      .textAlign(TextAlign.Center).layoutWeight(1).padding({ top: 12, bottom: 12 })
      .backgroundColor(this.selected ? '#454B62' : Color.Transparent)
      .borderRadius({ topLeft: this.first ? 14 : 0, bottomLeft: this.first ? 14 : 0,
        topRight: this.last ? 14 : 0, bottomRight: this.last ? 14 : 0 })
      .onClick(() => this.onSelect())
  }
}

@Component
struct ThemePaletteItem {
  @StorageProp('themeColorAccent') themeColorAccent: string = '#3F5BD9';
  @StorageProp('themeColorTextPrimary') themeColorTextPrimary: string = '#1B1C22';
  @Prop index: number = 0;
  @Prop title: string = '';
  /** 卡片底色，取该套配色的 `surfaceContainer`（上游 `CardDefaults.cardColors(containerColor = colors.surfaceContainer)`）。 */
  @Prop surfaceColor: string = '#F0F1F5';
  /** 48dp 圆的上半圆，取 `secondary`。 */
  @Prop upperColor: string = '#5F74B8';
  /** 48dp 圆的下半圆，取 `tertiary`。 */
  @Prop lowerColor: string = '#4A5FA8';
  /** 中心 24dp 圆，取 `primary`。 */
  @Prop centerColor: string = '#3F5BD9';
  @Prop selected: boolean = false;
  onSelect: () => void = () => {};
  build() {
    Column() {
      // 上游卡片 64dp、圆角 16dp，选中时 2dp `primary` 描边；本地 56vp 与既有尺寸一致。
      Stack({ alignContent: Alignment.Center }) {
        // 用上下两个 42×21 的半圆拼出 42dp 圆：上半 `secondary`、下半 `tertiary`，中心再叠 20dp `primary`。
        Column() {
          Row().width(42).height(21).backgroundColor(this.upperColor)
            .borderRadius({ topLeft: 21, topRight: 21 })
          Row().width(42).height(21).backgroundColor(this.lowerColor)
            .borderRadius({ bottomLeft: 21, bottomRight: 21 })
        }.width(42).height(42).borderRadius(21).clip(true)
        Column().width(20).height(20).backgroundColor(this.centerColor).borderRadius(10)
        if (this.selected) {
          Stack({ alignContent: Alignment.Center }) {
            AppGlyph({ name: 'profileCheck', glyphSize: 18, tint: '#20212A' })
          }.width(34).height(34).backgroundColor(this.themeColorAccent).borderRadius(17)
        }
      }.width(56).height(56).backgroundColor(this.surfaceColor).borderRadius(14)
        .border({ width: this.selected ? 2 : 0, color: this.themeColorAccent }).onClick(() => this.onSelect())
      Text(this.title).fontSize(11)
        .fontColor(this.selected ? this.themeColorAccent : this.themeColorTextPrimary)
        .textAlign(TextAlign.Center).margin({ top: 8 })
    }.width(64).alignItems(HorizontalAlign.Center).margin({ right: 16 })
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
        Text(this.title).fontSize(16).fontColor(this.themeColorTextSecondary)
        if (this.detail.length > 0) {
          Text(this.detail).fontSize(12).fontColor(this.themeColorTextTertiary).margin({ top: 3 })
        }
      }.alignItems(HorizontalAlign.Start).layoutWeight(1)
      Toggle({ type: ToggleType.Switch, isOn: this.checked })
        .onChange((enabled: boolean) => this.onChange(enabled))
    }.padding({ left: 16, right: 16, top: 14, bottom: 14 })
  }
}
