import {
  ReaderBackgroundStyle, READER_BACKGROUND_STYLES, READER_STYLE_PRESET_COUNT
} from '../data/ReaderSettingsRepository';
import { ReaderFontEntry, ReaderFontRepository } from '../data/ReaderFontRepository';
import { READER_COLUMN_MODE_TITLES, readerColumnModeTitle } from '../data/ReaderColumnMode';
import {
  defaultReaderSelectionMenuItems,
  parseReaderSelectionMenuConfig,
  ReaderSelectionMenuItem,
  serializeReaderSelectionMenuConfig
} from '../data/ReaderSelectionMenu';
import {
  ReaderActionOption, ReaderBottomActionConfig, READER_ACTION_OPTIONS,
  READER_LOCAL_BOTTOM_ACTION_DEFAULTS, READER_LOCAL_TOP_ACTION_DEFAULTS,
  ReaderInfoSettings, DEFAULT_READER_INFO_SETTINGS, ReaderPaddingSettings, DEFAULT_READER_PADDING_SETTINGS,
  copyReaderPaddingSettings, updateReaderInfoSettings,
  READER_CLICK_REGION_ACTIONS, READER_CLICK_REGION_DEFAULTS
} from '../data/ReaderSettingsRepository';

type ReaderInfoSlot = 'headerLeft' | 'headerMiddle' | 'headerRight' | 'footerLeft' | 'footerMiddle' | 'footerRight';
type ReaderFontTarget = 'body' | 'title' | 'header' | 'footer';

const READ_INFO_TIP_VALUES: number[] = [0, 7, 1, 12, 17, 2, 3, 15, 13, 14, 10, 4, 5, 11, 6, 8, 16, 9, 19, 20, 18];
const READER_INFO_COLOR_VALUES: number[] = [0, -1, -16777216, -8355712, -65536, -16711936, -16776961];
const READER_INFO_COLOR_CHOICES: string[] = ['跟随正文', '白色', '黑色', '灰色', '红色', '绿色', '蓝色'];
const CLICK_REGION_NAMES: string[] = ['左上', '上中', '右上', '左中', '中间', '右中', '左下', '下中', '右下'];
const READER_BODY_WEIGHT_VALUES: number[] = [300, 400, 500, 700, 900];
// 标题取色候选：正文用的八色之外补上深浅两端，「跟随正文」由单独一行入口负责（空串不能画成色块）。
const READER_TITLE_COLORS: string[] = ['#38383B', '#000000', '#3C3F43', '#FFFFFF', '#D8D8DC', '#ADADAD', '#FF8C00', '#5A8DEE'];
// 上游 paletteStyle_value（values/array_values.xml:101-111）九项；索引 0 是「跟随系统」，
// 用空串承载（SystemMenuPage.kt:277-291 的 entryValues 第一个元素就是 ""）。
const MENU_PALETTE_VALUES: string[] = ['', 'tonalSpot', 'neutral', 'vibrant', 'expressive',
  'rainbow', 'fruitSalad', 'monochrome', 'fidelity', 'content'];
// 菜单配色弹层的色板：沿用正文效果色板，另加两档中性灰便于做菜单底色与容器色。
const MENU_COLOR_PALETTE: string[] = ['#FFFFFF', '#E6E1E7', '#D0CBD1', '#9A9CA5',
  '#3D3D46', '#31282A', '#1A1B21', '#000000', '#FFB1C8', '#5A8DEE'];
const READER_EFFECT_COLORS: string[] = [
  '#3E3D3B', '#ADADAD', '#FFFFFF', '#000000', '#FF8C00', '#5A8DEE', '#63C37D', '#DB4B4B'
];
/** 自定义背景色板：比强调色板多几个常见纸色，对齐上游 bg_color 的取色场景。 */
const READER_BACKGROUND_COLORS: string[] = [
  '#FFFFFF', '#EEEEEE', '#DDC090', '#C2D8AA', '#ABCEE0', '#DBB8E2', '#FFC0EDC6', '#000000', '#3C3F43', '#343832'
];
interface ReaderTextMenuEntry {
  id: string;
  title: string;
  group: number;
}
const READER_TEXT_MENU_DEFAULTS: ReaderTextMenuEntry[] = [
  { id: 'menu_copy', title: '复制', group: 0 },
  { id: 'menu_share_str', title: '分享', group: 0 },
  { id: 'menu_browser', title: '浏览器', group: 0 },
  { id: 'menu_aloud', title: '朗读', group: 0 },
  { id: 'menu_bookmark', title: '书签', group: 0 },
  { id: 'menu_mark', title: '笔记', group: 0 },
  { id: 'menu_dict', title: '字典', group: 0 },
  { id: 'menu_replace', title: '替换', group: 0 },
  { id: 'menu_edit', title: '编辑', group: 0 },
  { id: 'menu_ai_clean', title: 'AI 净化', group: 0 },
  { id: 'menu_ai_rewrite', title: 'AI 改写', group: 0 },
  { id: 'menu_search_content', title: '全文搜索', group: 0 },
  { id: 'menu_insert_bgm_before', title: '插入(前)', group: 0 },
  { id: 'menu_insert_bgm_after', title: '插入(后)', group: 0 }
];

interface ReaderMenuSettingsEntry {
  title: string;
  detail: string;
  section?: boolean;
}

interface ReaderUiSection {
  title: string;
  items: ReaderMenuSettingsEntry[];
}

@Component
export struct ReaderSettingsPage {
  @StorageProp('themeColorTextTertiary') themeColorTextTertiary: string = '#6A6D77';
  @StorageProp('themeColorAccent') themeColorAccent: string = '#3F5BD9';
  @StorageProp('themeColorSurfaceSecondary') themeColorSurfaceSecondary: string = '#FFFFFF';
  @Prop fontSize: number = 19;
  @Prop paragraphSpacing: number = 2;
  @Prop lineSpacing: number = 12;
  @Prop letterSpacing: number = 0.1;
  @Prop paragraphIndent: string = '　　';
  @Prop textFont: string = '';
  @Prop titleFont: string = '';
  @Prop systemTypefaces: number = 0;
  @Prop textItalic: boolean = false;
  @Prop textBold: number = 500;
  @Prop textShadow: boolean = false;
  @Prop shadowRadius: number = 16;
  @Prop shadowDx: number = 1;
  @Prop shadowDy: number = 1;
  @Prop textShadowColor: string = '#3E3D3B';
  @Prop textShadowColorN: string = '#3E3D3B';
  @Prop underline: boolean = false;
  @Prop dottedLine: boolean = false;
  @Prop underlineColor: string = '#3E3D3B';
  @Prop underlineColorNight: string = '#ADADAD';
  @Prop underlineHeight: number = 1;
  @Prop underlinePadding: number = 10;
  @Prop underlineExtend: boolean = false;
  @Prop dottedBase: number = 6;
  @Prop dottedRatio: number = 6;
  onTextItalicChange: (enabled: boolean) => void = (_enabled: boolean) => {};
  onTextBoldChange: (weight: number) => void = (_weight: number) => {};
  onTextShadowChange: (enabled: boolean) => void = (_enabled: boolean) => {};
  onShadowRadiusChange: (value: number) => void = (_value: number) => {};
  onShadowDxChange: (value: number) => void = (_value: number) => {};
  onShadowDyChange: (value: number) => void = (_value: number) => {};
  onTextShadowColorChange: (value: string, night: boolean) => void = (_value: string, _night: boolean) => {};
  onUnderlineChange: (enabled: boolean) => void = (_enabled: boolean) => {};
  onDottedLineChange: (enabled: boolean) => void = (_enabled: boolean) => {};
  onUnderlineColorChange: (value: string, night: boolean) => void = (_value: string, _night: boolean) => {};
  onUnderlineHeightChange: (value: number) => void = (_value: number) => {};
  onUnderlinePaddingChange: (value: number) => void = (_value: number) => {};
  onUnderlineExtendChange: (enabled: boolean) => void = (_enabled: boolean) => {};
  onDottedBaseChange: (value: number) => void = (_value: number) => {};
  onDottedRatioChange: (value: number) => void = (_value: number) => {};
  @Prop textFullJustify: boolean = true;
  @Prop textBottomJustify: boolean = true;
  @Prop paperIndex: number = 2;
  /** 背景样式表，前 READER_STYLE_PRESET_COUNT 份是内置预设、其后是自建；paperIndex 是它的下标。 */
  @Prop backgroundStyles: ReaderBackgroundStyle[] = READER_BACKGROUND_STYLES;
  @Prop shareLayout: boolean = false;
  @Prop readerNightMode: boolean = true;
  @Prop eyeProtectionActive: boolean = false;
  @Prop eyeProtectionEnabled: boolean = false;
  @Prop eyeProtectionAutoNight: boolean = false;
  @Prop eyeProtectionSchedule: boolean = false;
  @Prop eyeProtectionIntensity: number = 50;
  @Prop eyeProtectionStartTime: string = '22:00';
  @Prop eyeProtectionEndTime: string = '07:00';
  @Prop showBottomActionText: boolean = true;
  @Prop bottomIconStyle: number = 1;
  @Prop bottomItemsPerRow: number = 5;
  @Prop bottomRowCount: number = 1;
  @Prop bottomActions: ReaderBottomActionConfig[] = READER_LOCAL_BOTTOM_ACTION_DEFAULTS;
  @Prop topActions: ReaderBottomActionConfig[] = READER_LOCAL_TOP_ACTION_DEFAULTS;
  @Prop progressBehavior: string = 'page';
  // 上游 readSliderMode："0" 常驻 / "1" 不显示
  @Prop readSliderMode: string = '0';
  // 上游 pageTouchSlop：0 = 系统默认阈值，范围 0–1000
  @Prop pageTouchSlop: number = 0;
  @Prop screenOrientation: string = '0';
  @Prop keepLight: string = '0';
  @Prop volumeKeyPage: boolean = true;
  @Prop keyPageOnLongPress: boolean = false;
  @Prop noAnimScrollPage: boolean = false;
  /** 自定义「上一页」按键串，对齐上游 prevKeys（ReadSettings.kt:60）。 */
  @Prop prevKeys: string = '';
  /** 自定义「下一页」按键串，对齐上游 nextKeys（ReadSettings.kt:61）。 */
  @Prop nextKeys: string = '';
  /** 鼠标滚轮翻页开关，对齐上游 mouseWheelPage（ReadSettings.kt:28）。 */
  @Prop mouseWheelPage: boolean = true;
  @Prop readingAnchorEnabled: boolean = true;
  @Prop swipeToAddBookmark: boolean = false;
  @Prop bookmarkBadgeSize: number = 10;
  /** 自定义书签角标图片路径；空串表示默认丝带。 */
  @Prop bookmarkBadgeImage: string = '';
  @Prop selectText: boolean = true;
  /** 滑动进度条时震动；上游 ReadSettings.kt:36 sliderVibrator。 */
  @Prop sliderVibrator: boolean = false;
  /** 选择正文时震动；上游 ReadSettings.kt:41 selectVibrator。 */
  @Prop selectVibrator: boolean = false;
  /** 中文简繁体转换档位：0 = 不转换、1 = 繁转简、2 = 简转繁。上游 ReadSettings.kt:118。 */
  @Prop chineseConverterType: number = 0;
  /** 正文日间/夜间颜色；上游 ReadBookConfig.kt:55-56 textColor / textColorNight。 */
  @Prop textColor: string = '#38383B';
  @Prop textColorNight: string = '#D8D8DC';
  /** 正文强调色；上游 ReadBookConfig.kt:62 textAccentColor。 */
  @Prop textAccentColor: string = '#834E00';
  @Prop textAccentColorNight: string = '#FE4D55';
  /** 自定义背景；空串表示沿用内置六方案。上游 ReadBookConfig.kt:537-551。 */
  @Prop bgStr: string = '';
  @Prop bgStrNight: string = '';
  @Prop bgType: number = 0;
  @Prop bgTypeNight: number = 0;
  @Prop bgAlpha: number = 100;
  @Prop darkStatusIcon: boolean = true;
  @Prop darkStatusIconNight: boolean = false;
  // 标题排版十四个字段，对齐上游 help/config/ReadBookConfig.kt:596-608。
  @Prop titleMode: number = 0;
  @Prop titleSize: number = 4;
  @Prop titleSizeRelative: boolean = true;
  @Prop titleTopSpacing: number = 0;
  @Prop titleBottomSpacing: number = 0;
  @Prop titleColor: string = '';
  @Prop titleColorNight: string = '';
  @Prop titleBold: number = 500;
  @Prop titleLineSpacingExtra: number = 12;
  @Prop titleLineSpacingSub: number = 12;
  @Prop titleSegType: number = 0;
  @Prop titleSegScaling: number = 1;
  @Prop titleSegDistance: number = 4;
  @Prop titleSegFlag: string = '';
  /** 划词菜单是否展开成多行，对齐上游 expandTextMenu（ReadSettings.kt:51）。 */
  @Prop expandTextMenu: boolean = false;
  /** 划词菜单是否显示图标，对齐上游 showSelectMenuIcon（ReadSettings.kt:52）。 */
  @Prop showSelectMenuIcon: boolean = true;
  /** 横屏双页档位，对齐上游 doubleHorizontalPage（ReadSettings.kt:26），四档 '0'..'3'。 */
  @Prop doubleHorizontalPage: string = '0';
  /** 环境光日夜提醒开关；上游 `autoSuggestDayNight`（`ReadSettings.kt:43`）。 */
  @Prop autoSuggestDayNight: boolean = false;
  /** 禁用返回键；上游 `disableReturnKey`（`ReadSettings.kt:50`）。 */
  @Prop disableReturnKey: boolean = false;
  /** 阅读亮度 1..100；上游 `readBrightness`（`ReadSettings.kt:22`，默认 100）。 */
  @Prop readBrightness: number = 100;
  /** 亮度条形态；上游 `showBrightnessView`（`ReadSettings.kt:20`），"0" 关闭 / "1" 横排 / "2" 竖排。 */
  @Prop showBrightnessView: string = '0';
  /** 竖排亮度条贴哪一侧；上游 `brightnessVwPos`（`ReadSettings.kt:21`），"0" 左 / "1" 右。 */
  @Prop brightnessVwPos: string = '1';
  /** 亮度是否跟随系统；上游 `brightnessAuto`（`ReadSettings.kt:23`，默认 true）。 */
  @Prop brightnessAuto: boolean = true;
  /** 正文行高适配；上游 `readBodyToLh`（默认 true）。上游只有配置没有渲染消费点，本地同样只落库。 */
  @Prop readBodyToLh: boolean = true;
  /** 自定义中文分行；上游 `useZhLayout`（默认 false），只参与分页签名。 */
  @Prop useZhLayout: boolean = false;
  /** 填充刘海区域；上游 `paddingDisplayCutouts`（默认 false），见 `ReaderContentAvoidancePolicy`。 */
  @Prop paddingDisplayCutouts: boolean = false;
  /** 适配特殊样式；上游 `adaptSpecialStyle`（默认 true），控制 `[newpage]`/`<usehtml>` 的解释。 */
  @Prop adaptSpecialStyle: boolean = true;
  /** 底栏圆角（vp）；上游 `readMenuBottomCornerRadius`（`ReadSettings.kt:94`，默认 32，夹 0-32）。 */
  @Prop readMenuBottomCornerRadius: number = 32;
  /** 底栏是否悬浮；上游 `readMenuFloatingBottomBar`（`ReadSettings.kt:95`，默认 true）。 */
  @Prop readMenuFloatingBottomBar: boolean = true;
  /** 底栏模糊模式；0 关闭 / 1 液态玻璃 / 2 雾化（`ReadSettings.kt:97`、`PreferKey.kt:498`）。 */
  @Prop readMenuBottomBarBlurMode: number = 0;
  /** 底栏模糊样式；0 填充 / 1 渐变（`ReadSettings.kt:104`、`PreferKey.kt:504`）。 */
  @Prop readMenuBottomBarBlurStyle: number = 0;
  /** 底栏按钮液态玻璃；上游 `readMenuBottomBarLiquidGlassButtons`（`ReadSettings.kt:101`）。 */
  @Prop readMenuBottomBarLiquidGlassButtons: boolean = false;
  /** 菜单不透明度 0-100；底栏与顶栏共用上游 `readMenuBlurAlpha`（`ReadSettings.kt:106`，默认 85）。 */
  @Prop readMenuBlurAlpha: number = 85;
  /** 标题栏胶囊；上游 `readMenuTopBarTitleCapsule`（`ReadSettings.kt:100`）。 */
  @Prop readMenuTopBarTitleCapsule: boolean = false;
  /** 标题栏显示方式，上游四值 "0"-"3"（`ReadSettings.kt:12`）。 */
  @Prop titleBarMode: string = '1';
  /** 标题栏精简；上游 `titleBarCompact`（`ReadSettings.kt:120`）。 */
  @Prop titleBarCompact: boolean = false;
  /** 标题栏图标样式 0 纯色 / 1 色调 / 2 描边；上游 `titleBarIconStyle`（`ReadSettings.kt:91`）。 */
  @Prop titleBarIconStyle: number = 0;
  /** 顶栏模糊模式 0/1/2；上游 `readMenuTopBarBlurMode`（`ReadSettings.kt:96`）。 */
  @Prop readMenuTopBarBlurMode: number = 0;
  /** 顶栏模糊样式 0 填充 / 1 渐变；上游 `readMenuTopBarBlurStyle`（`ReadSettings.kt:103`）。 */
  @Prop readMenuTopBarBlurStyle: number = 0;
  /** 顶栏按钮液态玻璃；上游 `readMenuTopBarLiquidGlassButtons`（`ReadSettings.kt:98`）。 */
  @Prop readMenuTopBarLiquidGlassButtons: boolean = false;
  /** 顶栏按钮合并；上游 `readMenuTopBarMergeButtons`（`ReadSettings.kt:99`）。 */
  @Prop readMenuTopBarMergeButtons: boolean = false;
  /** 菜单工具栏样式 0 跟随系统 / 1 跟随阅读背景 / 2 自定义；上游 `readBarStyle`（`ReadSettings.kt:69`）。 */
  @Prop readBarStyle: number = 1;
  /** 菜单调色板样式，空串表示跟随系统；上游 `readMenuPaletteStyle`（`ReadSettings.kt:109`）。 */
  @Prop readMenuPaletteStyle: string = '';
  /** 菜单色板来源 0 种子色 / 1 自定义颜色；上游 `readMenuColorMode`（`ReadSettings.kt:88`）。 */
  @Prop readMenuColorMode: number = 1;
  /** 菜单背景色，空串表示未设置；上游 `readMenuBgColor`/`readMenuBgColorNight`（`ReadSettings.kt:80`/`:83`）。 */
  @Prop readMenuBgColor: string = '';
  @Prop readMenuBgColorNight: string = '';
  /** 菜单容器色，空串表示未设置；上游 `readMenuContainerColor`/`Night`（`ReadSettings.kt:82`/`:85`）。 */
  @Prop readMenuContainerColor: string = '';
  @Prop readMenuContainerColorNight: string = '';
  /** 菜单强调色，与「种子色」共用；上游 `readMenuAccentColor`/`Night`（`ReadSettings.kt:81`/`:84`）。 */
  @Prop readMenuAccentColor: string = '';
  @Prop readMenuAccentColorNight: string = '';
  /** 菜单栏边框宽度 0–4，0 = 无边框（上游 readMenuBorderWidth，夹 0–4）。 */
  @Prop readMenuBorderWidth: number = 1;
  /** 菜单栏边框颜色（日间），空串 = 未设置（上游 readMenuBorderColor）。 */
  @Prop readMenuBorderColor: string = '';
  /** 菜单栏边框颜色（夜间）（上游 readMenuBorderColorNight）。 */
  @Prop readMenuBorderColorNight: string = '';
  /** 菜单模糊半径 0–32（上游 readMenuBlurRadius，默认 24）。 */
  @Prop readMenuBlurRadius: number = 24;
  /** 菜单文字与图标颜色（日间），空串 = 未设置（上游 readMenuTextColor）。 */
  @Prop readMenuTextColor: string = '';
  /** 菜单文字与图标颜色（夜间）（上游 readMenuTextColorNight）。 */
  @Prop readMenuTextColorNight: string = '';
  /** 菜单模糊层着色（日间），空串 = 未设置（上游 readMenuBlurColor）。 */
  @Prop readMenuBlurColor: string = '';
  /** 菜单模糊层着色（夜间）（上游 readMenuBlurColorNight）。 */
  @Prop readMenuBlurColorNight: string = '';
  /** 显示浮动图标行（上游 showTitleBarIcons，ReadSettings.kt:117，默认 false）。 */
  @Prop showTitleBarIcons: boolean = false;
  /** 浮动图标位置 0 左上 / 1 右上 / 2 左下 / 3 右下（上游 titleBarIconPosition，默认 3）。 */
  @Prop titleBarIconPosition: number = 3;
  /** 浮动图标液态玻璃按钮（上游 readMenuFloatingIconLiquidGlass，默认 false）。 */
  @Prop readMenuFloatingIconLiquidGlass: boolean = false;
  /** 浮动图标行的按钮池；上游与顶栏操作按钮同池（ReadBookMenuBarFloating.kt:411）。 */
  @Prop floatingIcons: ReaderBottomActionConfig[] = READER_LOCAL_BOTTOM_ACTION_DEFAULTS;
  /** 浮动图标自定义图标路径表（`id,path;` 编码），上游 titleBarCustomIcons。 */
  @Prop titleBarCustomIcons: string = '';
  /** 底栏菜单自定义图标路径表（`id,path;` 编码），上游 readMenuCustomIcons（ReadSettings.kt:114）。 */
  @Prop readMenuCustomIcons: string = '';
  /** 「更多」下拉菜单是否显示每项前置图标，上游 `showMenuIcon`（ReadSettings.kt:119，默认 false）。 */
  @Prop showMenuIcon: boolean = false;
  /** 顶部工具栏附加区域，上游 `showReadTitleAddition`（ReadSettings.kt:55，默认 true）；上游无渲染消费点，只落库。 */
  @Prop showReadTitleAddition: boolean = true;
  /** 菜单不透明度 0-100，上游 `menuAlpha`（ReadSettings.kt:13，默认 100）；上游无渲染消费点，只落库。 */
  @Prop menuAlpha: number = 100;
  /** 划词菜单条目配置串，对齐上游 textSelectMenuConfig（ReadSettings.kt:53）。 */
  @Prop textSelectMenuConfig: string = '';
  @Prop maxLengthWithNoToc: number = 3000;
  @Prop clickImageBehavior: string = '2';
  @Prop clickRegionActions: string[] = READER_CLICK_REGION_DEFAULTS;
  @Prop hideStatusBar: boolean = false;
  @Prop hideNavigationBar: boolean = false;
  @Prop infoSettings: ReaderInfoSettings = DEFAULT_READER_INFO_SETTINGS;
  @Prop paddingSettings: ReaderPaddingSettings = DEFAULT_READER_PADDING_SETTINGS;
  @Prop showQuickActions: boolean = false;
  @Prop asSheet: boolean = false;
  @Prop openBottomActionConfigOnAppear: boolean = false;
  @State selectedSettingsTab: number = 0;
  @State previousMainSettingsTab: number = 0;
  @State selectedMenuSettingsTab: number = 0;
  @State bottomActionConfigVisible: boolean = false;
  @State topActionConfigVisible: boolean = false;
  /** 浮动图标配置面板（上游 FloatingBarIconConfigSheet），复用顶栏操作按钮的草稿与行渲染。 */
  @State floatingIconConfigVisible: boolean = false;
  @State detailSheetVisible: boolean = false;
  @State detailSheetTitle: string = '';
  @State detailSheetDescription: string = '';
  @State detailSelectedOption: string = '';
  @State fontTarget: ReaderFontTarget = 'body';
  @State fontEntries: ReaderFontEntry[] = [];
  @State detailCustomText: string = '';
  /** 「编辑背景样式」草稿：打开详情页时从当前样式灌入，保存时才回写。 */
  @State editingStyleIndex: number = 0;
  @State editingStyleName: string = '';
  @State editingStyleDayColor: string = '';
  @State editingStyleNightColor: string = '';
  @State selectedClickRegionIndex: number = 4;
  @State previousPageKeys: string = '';
  @State nextPageKeys: string = '';
  @State primaryTextMenuExpanded: boolean = true;
  @State collapsedTextMenuExpanded: boolean = true;
  @State hiddenTextMenuExpanded: boolean = false;
  @State textMenuEntries: ReaderTextMenuEntry[] = READER_TEXT_MENU_DEFAULTS.map(
    (item: ReaderTextMenuEntry): ReaderTextMenuEntry => ({ id: item.id, title: item.title, group: item.group })
  );
  private detailInfoSlot: ReaderInfoSlot | undefined = undefined;
  @Prop pageAnimationIndex: number = 0;
  @Prop animationSpeedIndex: number = 2;
  @State infoSubTab: number = 0;
  @State moreSubTab: number = 0;
  @State draftBottomActions: ReaderBottomActionConfig[] = READER_LOCAL_BOTTOM_ACTION_DEFAULTS.map(
    (item: ReaderBottomActionConfig): ReaderBottomActionConfig => ({ id: item.id, enabled: item.enabled })
  );
  @State draftTopActions: ReaderBottomActionConfig[] = READER_LOCAL_TOP_ACTION_DEFAULTS.map(
    (item: ReaderBottomActionConfig): ReaderBottomActionConfig => ({ id: item.id, enabled: item.enabled })
  );
  private backgroundScroller: Scroller = new Scroller();
  private menuSettingsScroller: Scroller = new Scroller();
  // 工具栏样式 / 色板来源 / 调色板风格的选中态不再用本地 @State 假值承载，
  // 一律读 @Prop（readBarStyle / readMenuColorMode / readMenuPaletteStyle）的真值。
  // 浮动图标显示开关改为读 @Prop showTitleBarIcons（上游 showTitleBarIcons 字段）。

  aboutToAppear(): void {
    this.syncTextMenuEntriesFromConfig();
    this.loadReaderFontEntries();
    if (this.openBottomActionConfigOnAppear) {
      this.selectedSettingsTab = 1;
      this.selectedMenuSettingsTab = 1;
      this.draftBottomActions = this.bottomActions.map(
        (item: ReaderBottomActionConfig): ReaderBottomActionConfig => ({ id: item.id, enabled: item.enabled })
      );
      this.bottomActionConfigVisible = true;
    }
  }

  onBack: () => void = () => {};
  onFontSizeChange: (fontSize: number) => void = () => {};
  onTextFontChange: (path: string) => void = (_path: string) => {};
  onTitleFontChange: (path: string) => void = (_path: string) => {};
  onSystemTypefacesChange: (index: number) => void = (_index: number) => {};
  onTextFullJustifyChange: (enabled: boolean) => void = (_enabled: boolean) => {};
  onTextBottomJustifyChange: (enabled: boolean) => void = (_enabled: boolean) => {};
  onParagraphSpacingChange: (value: number) => void = (_value: number) => {};
  onLineSpacingChange: (value: number) => void = (_value: number) => {};
  onLetterSpacingChange: (value: number) => void = (_value: number) => {};
  onParagraphIndentCountChange: (count: number) => void = (_count: number) => {};
  onPaperChange: (paperIndex: number) => void = () => {};
  /** 新增样式，返回新下标（调用方据此切过去）。 */
  onAddBackgroundStyle: () => number = () => 0;
  /** 改某个样式的名字与日/夜背景色。 */
  onUpdateBackgroundStyle: (index: number, name: string, dayColor: string, nightColor: string) => void =
    (_index: number, _name: string, _dayColor: string, _nightColor: string) => {};
  /** 删掉一个自建样式。 */
  onRemoveBackgroundStyle: (index: number) => void = (_index: number) => {};
  /** 把自建样式从 from 挪到 to。 */
  onMoveBackgroundStyle: (from: number, to: number) => void = (_from: number, _to: number) => {};
  onShareLayoutChange: (enabled: boolean) => void = (_enabled: boolean) => {};
  onToggleNightMode: () => void = () => {};
  onEyeProtectionToggle: () => void = () => {};
  onEyeProtectionEnabledChange: (enabled: boolean) => void = (_enabled: boolean) => {};
  onEyeProtectionAutoNightChange: (enabled: boolean) => void = (_enabled: boolean) => {};
  onEyeProtectionScheduleChange: (enabled: boolean) => void = (_enabled: boolean) => {};
  onEyeProtectionIntensityChange: (value: number) => void = (_value: number) => {};
  onEyeProtectionStartTimeChange: (value: string) => void = (_value: string) => {};
  onEyeProtectionEndTimeChange: (value: string) => void = (_value: string) => {};
  onBottomActionTextChange: (enabled: boolean) => void = (_enabled: boolean) => {};
  onBottomIconStyleChange: (style: number) => void = (_style: number) => {};
  onBottomItemsPerRowChange: (count: number) => void = (_count: number) => {};
  onBottomRowCountChange: (count: number) => void = (_count: number) => {};
  onBottomActionsChange: (actions: ReaderBottomActionConfig[]) => void = (_actions: ReaderBottomActionConfig[]) => {};
  onTopActionsChange: (actions: ReaderBottomActionConfig[]) => void = (_actions: ReaderBottomActionConfig[]) => {};
  onProgressBehaviorChange: (value: string) => void = (_value: string) => {};
  onReadSliderModeChange: (value: string) => void = (_value: string) => {};
  onPageTouchSlopChange: (value: number) => void = (_value: number) => {};
  onScreenOrientationChange: (value: string) => void = (_value: string) => {};
  onKeepLightChange: (value: string) => void = (_value: string) => {};
  onVolumeKeyPageChange: (enabled: boolean) => void = (_enabled: boolean) => {};
  onKeyPageOnLongPressChange: (enabled: boolean) => void = (_enabled: boolean) => {};
  onNoAnimScrollPageChange: (enabled: boolean) => void = (_enabled: boolean) => {};
  onPrevKeysChange: (value: string) => void = (_value: string) => {};
  onNextKeysChange: (value: string) => void = (_value: string) => {};
  onMouseWheelPageChange: (enabled: boolean) => void = (_enabled: boolean) => {};
  onReadingAnchorEnabledChange: (enabled: boolean) => void = (_enabled: boolean) => {};
  onSwipeToAddBookmarkChange: (enabled: boolean) => void = (_enabled: boolean) => {};
  /** 书签角标宽度（dp）；0 表示不显示角标。 */
  onBookmarkBadgeSizeChange: (value: number) => void = (_value: number) => {};
  /** 选择自定义角标图片；成功后由上层写入 `bookmarkBadgeImage`。 */
  onPickBookmarkBadgeImage: () => void = () => {};
  /** 恢复默认角标（清空自定义图片）。 */
  onResetBookmarkBadgeImage: () => void = () => {};
  onMaxLengthWithNoTocChange: (value: number) => void = (_value: number) => {};
  onClickImageBehaviorChange: (value: string) => void = (_value: string) => {};
  onClickRegionActionsChange: (actions: string[]) => void = (_actions: string[]) => {};
  onHideStatusBarChange: (enabled: boolean) => void = (_enabled: boolean) => {};
  onHideNavigationBarChange: (enabled: boolean) => void = (_enabled: boolean) => {};
  onPageAnimationChange: (animation: number) => void = (_animation: number) => {};
  onAnimationSpeedChange: (speed: number) => void = (_speed: number) => {};
  onInfoSettingsChange: (settings: ReaderInfoSettings) => void = (_settings: ReaderInfoSettings) => {};
  onPaddingSettingsChange: (settings: ReaderPaddingSettings) => void = (_settings: ReaderPaddingSettings) => {};
  onQuickActionsChange: (enabled: boolean) => void = (_enabled: boolean) => {};
  onUnavailableAction: (message: string) => void = (_message: string) => {};
  onSelectTextChange: (enabled: boolean) => void = (_enabled: boolean) => {};
  onSliderVibratorChange: (enabled: boolean) => void = (_enabled: boolean) => {};
  onSelectVibratorChange: (enabled: boolean) => void = (_enabled: boolean) => {};
  onChineseConverterTypeChange: (value: number) => void = (_value: number) => {};
  onTextColorChange: (value: string, night: boolean) => void = (_value: string, _night: boolean) => {};
  onTextAccentColorChange: (value: string, night: boolean) => void = (_value: string, _night: boolean) => {};
  onBackgroundColorChange: (value: string, night: boolean) => void = (_value: string, _night: boolean) => {};
  onBackgroundImageChange: (path: string, night: boolean) => void = (_path: string, _night: boolean) => {};
  onBgAlphaChange: (value: number) => void = (_value: number) => {};
  onDarkStatusIconChange: (enabled: boolean, night: boolean) => void = (_enabled: boolean, _night: boolean) => {};
  onPickBackgroundImage: (night: boolean) => void = (_night: boolean) => {};
  onTitleModeChange: (value: number) => void = (_value: number) => {};
  onTitleSizeChange: (value: number) => void = (_value: number) => {};
  onTitleSizeRelativeChange: (relative: boolean) => void = (_relative: boolean) => {};
  onTitleSpacingChange: (top: number, bottom: number) => void = (_top: number, _bottom: number) => {};
  onTitleColorChange: (value: string, night: boolean) => void = (_value: string, _night: boolean) => {};
  onTitleBoldChange: (value: number) => void = (_value: number) => {};
  onTitleLineSpacingChange: (extra: number, sub: number) => void = (_extra: number, _sub: number) => {};
  onTitleSegTypeChange: (value: number) => void = (_value: number) => {};
  onTitleSegScalingChange: (value: number) => void = (_value: number) => {};
  onTitleSegDistanceChange: (value: number) => void = (_value: number) => {};
  onTitleSegFlagChange: (value: string) => void = (_value: string) => {};
  onExpandTextMenuChange: (enabled: boolean) => void = (_enabled: boolean) => {};
  onShowSelectMenuIconChange: (enabled: boolean) => void = (_enabled: boolean) => {};
  onDoubleHorizontalPageChange: (value: string) => void = (_value: string) => {};
  onAutoSuggestDayNightChange: (enabled: boolean) => void = (_enabled: boolean) => {};
  onDisableReturnKeyChange: (enabled: boolean) => void = (_enabled: boolean) => {};
  onReadBrightnessChange: (value: number) => void = (_value: number) => {};
  onShowBrightnessViewChange: (value: string) => void = (_value: string) => {};
  onBrightnessVwPosChange: (value: string) => void = (_value: string) => {};
  onBrightnessAutoChange: (enabled: boolean) => void = (_enabled: boolean) => {};
  onReadBodyToLhChange: (enabled: boolean) => void = (_enabled: boolean) => {};
  onUseZhLayoutChange: (enabled: boolean) => void = (_enabled: boolean) => {};
  onPaddingDisplayCutoutsChange: (enabled: boolean) => void = (_enabled: boolean) => {};
  onAdaptSpecialStyleChange: (enabled: boolean) => void = (_enabled: boolean) => {};
  onReadMenuBottomCornerRadiusChange: (value: number) => void = (_value: number) => {};
  onReadMenuFloatingBottomBarChange: (enabled: boolean) => void = (_enabled: boolean) => {};
  onReadMenuBottomBarBlurModeChange: (value: number) => void = (_value: number) => {};
  onReadMenuBottomBarBlurStyleChange: (value: number) => void = (_value: number) => {};
  onReadMenuBottomBarLiquidGlassButtonsChange: (enabled: boolean) => void = (_enabled: boolean) => {};
  onReadMenuBlurAlphaChange: (value: number) => void = (_value: number) => {};
  onReadMenuTopBarTitleCapsuleChange: (enabled: boolean) => void = (_enabled: boolean) => {};
  onTitleBarModeChange: (value: string) => void = (_value: string) => {};
  onTitleBarCompactChange: (enabled: boolean) => void = (_enabled: boolean) => {};
  onTitleBarIconStyleChange: (value: number) => void = (_value: number) => {};
  onReadMenuTopBarBlurModeChange: (value: number) => void = (_value: number) => {};
  onReadMenuTopBarBlurStyleChange: (value: number) => void = (_value: number) => {};
  onReadMenuTopBarLiquidGlassButtonsChange: (enabled: boolean) => void = (_enabled: boolean) => {};
  onReadMenuTopBarMergeButtonsChange: (enabled: boolean) => void = (_enabled: boolean) => {};
  onReadBarStyleChange: (value: number) => void = (_value: number) => {};
  onReadMenuPaletteStyleChange: (value: string) => void = (_value: string) => {};
  onReadMenuColorModeChange: (value: number) => void = (_value: number) => {};
  onReadMenuBgColorChange: (value: string) => void = (_value: string) => {};
  onReadMenuBgColorNightChange: (value: string) => void = (_value: string) => {};
  onReadMenuContainerColorChange: (value: string) => void = (_value: string) => {};
  onReadMenuContainerColorNightChange: (value: string) => void = (_value: string) => {};
  onReadMenuAccentColorChange: (value: string) => void = (_value: string) => {};
  onReadMenuAccentColorNightChange: (value: string) => void = (_value: string) => {};
  onReadMenuBorderWidthChange: (value: number) => void = (_value: number) => {};
  onReadMenuBorderColorChange: (value: string) => void = (_value: string) => {};
  onReadMenuBorderColorNightChange: (value: string) => void = (_value: string) => {};
  onReadMenuBlurRadiusChange: (value: number) => void = (_value: number) => {};
  onReadMenuTextColorChange: (value: string) => void = (_value: string) => {};
  onReadMenuTextColorNightChange: (value: string) => void = (_value: string) => {};
  onReadMenuBlurColorChange: (value: string) => void = (_value: string) => {};
  onReadMenuBlurColorNightChange: (value: string) => void = (_value: string) => {};
  onShowTitleBarIconsChange: (value: boolean) => void = (_value: boolean) => {};
  onTitleBarIconPositionChange: (value: number) => void = (_value: number) => {};
  onReadMenuFloatingIconLiquidGlassChange: (value: boolean) => void = (_value: boolean) => {};
  onFloatingIconsChange: (value: ReaderBottomActionConfig[]) => void = (_value: ReaderBottomActionConfig[]) => {};
  onTitleBarCustomIconsChange: (value: string) => void = (_value: string) => {};
  onReadMenuCustomIconsChange: (value: string) => void = (_value: string) => {};
  onShowMenuIconChange: (enabled: boolean) => void = (_enabled: boolean) => {};
  onShowReadTitleAdditionChange: (enabled: boolean) => void = (_enabled: boolean) => {};
  onMenuAlphaChange: (value: number) => void = (_value: number) => {};
  onTextSelectMenuConfigChange: (value: string) => void = (_value: string) => {};

  /** 某一组的背景图片路径；空串表示这一组没有自定义图片（bgType 为 0 时 bgStr 是纯色）。 */
  private getBackgroundImageOf(night: boolean): string {
    const type = night ? this.bgTypeNight : this.bgType;
    return type !== 0 ? (night ? this.bgStrNight : this.bgStr) : '';
  }

  /** 背景图片一行：显示是否已选，并提供「选择图片」「清除」两个动作。 */
  @Builder
  private BackgroundImageRow(title: string, night: boolean) {
    Row() {
      Column() {
        Text(title).fontSize(13).fontColor('#E2E3E8')
        Text(this.getBackgroundImageOf(night).length > 0 ? '已选择图片' : '未选择图片')
          .fontSize(10).fontColor('#9A9CA5').margin({ top: 4 })
      }.alignItems(HorizontalAlign.Start).layoutWeight(1)
      Text('选择').fontSize(11).fontColor('#C6D3FF')
        .padding({ left: 12, right: 12, top: 7, bottom: 7 })
        .backgroundColor('#292A31').borderRadius(8)
        .onClick(() => this.onPickBackgroundImage(night))
      if (this.getBackgroundImageOf(night).length > 0) {
        Text('清除').fontSize(11).fontColor('#C6D3FF')
          .padding({ left: 12, right: 12, top: 7, bottom: 7 })
          .backgroundColor('#292A31').borderRadius(8).margin({ left: 8 })
          .onClick(() => this.onBackgroundImageChange('', night))
      }
    }.width('100%').padding(12).backgroundColor('#202127').borderRadius(12)
  }

  /** 三段式选择器：点一次弹一个内联选择条，选中就落库。标题的对齐与字重都用它。 */
  @Builder
  private TitleChoiceRow(title: string, choices: string[], selectedIndex: number, onSelect: (index: number) => void) {
    Column() {
      Row() {
        Text(title).fontSize(13).fontColor('#E2E3E8').layoutWeight(1)
        Text(choices[selectedIndex] ?? choices[0] ?? '').fontSize(11).fontColor('#D3D4DC')
      }.width('100%')
      Row() {
        ForEach(choices, (label: string, index: number) => {
          Text(label).fontSize(11)
            .fontColor(selectedIndex === index ? '#ECECF0' : '#B7B8C1')
            .layoutWeight(1).textAlign(TextAlign.Center).padding(8)
            .backgroundColor(selectedIndex === index ? '#454B62' : '#15161B').borderRadius(8)
            .margin({ right: 4 })
            .onClick(() => onSelect(index))
        }, (label: string, index: number) => `${title}-${index}-${label}-${selectedIndex}`)
      }.width('100%').margin({ top: 8 })
    }.width('100%').padding(12).backgroundColor('#202127').borderRadius(12)
  }

  /** 标题排版：十四个字段全部可配，对齐上游 TypographyTabs 的标题页。 */
  @Builder
  private TitleTypographySettings() {
    Column() {
      // 位置模式：0 居左 / 1 居中 / 2 隐藏（ReadBookConfig.kt:267）。
      this.TitleChoiceRow('标题位置', ['居左显示', '居中显示', '隐藏标题'],
        Math.max(0, Math.min(2, this.titleMode)), (index: number) => this.onTitleModeChange(index))
      // 字号：relative 决定是「正文 + n」还是绝对号数（ReadBookConfig.kt:669-676）。
      MenuSettingSlider({
        title: `标题字号（${this.getTitleSizeLabel()}）`,
        value: this.titleSize,
        minValue: this.titleSizeRelative ? 0 : 5,
        maxValue: this.titleSizeRelative ? 40 : 60,
        stepValue: 1,
        onChange: (value: number) => this.onTitleSizeChange(value)
      })
      MenuSettingSwitch({
        title: '字号相对正文', detail: '关闭后按绝对号数显示',
        checked: this.titleSizeRelative,
        onChange: (enabled: boolean) => this.onTitleSizeRelativeChange(enabled)
      })
      // 上下间距（ReadBookConfig.kt:298/301），单位与上游一致按 dp。
      MenuSettingSlider({
        title: '标题上间距', value: this.titleTopSpacing, minValue: 0, maxValue: 60, stepValue: 1,
        onChange: (value: number) => this.onTitleSpacingChange(value, this.titleBottomSpacing)
      })
      MenuSettingSlider({
        title: '标题下间距', value: this.titleBottomSpacing, minValue: 0, maxValue: 60, stepValue: 1,
        onChange: (value: number) => this.onTitleSpacingChange(this.titleTopSpacing, value)
      })
      // 字重：档位与上游 resolveWeight 一致（LegacyReaderPaginationStyleFactory.kt:113-119）。
      this.TitleChoiceRow('标题字重', ['纤细', '常规', '中等', '粗体', '特粗'],
        Math.max(0, [300, 400, 500, 700, 900].indexOf(this.titleBold)),
        (index: number) => this.onTitleBoldChange([300, 400, 500, 700, 900][index] ?? 500))
      // 行距：Extra 是首段、Sub 是分段后的副标题段（LegacyReaderPaginationStyleFactory.kt:99-101）。
      MenuSettingSlider({
        title: '标题行距', value: this.titleLineSpacingExtra, minValue: 0, maxValue: 20, stepValue: 1,
        onChange: (value: number) => this.onTitleLineSpacingChange(value, this.titleLineSpacingSub)
      })
      MenuSettingSlider({
        title: '标题副项行距', value: this.titleLineSpacingSub, minValue: 0, maxValue: 20, stepValue: 1,
        onChange: (value: number) => this.onTitleLineSpacingChange(this.titleLineSpacingExtra, value)
      })
      // 标题取色：空串表示跟随正文（上游 titleColor 取 0 时回落正文色）。
      MenuSettingPalette({
        title: `日间标题颜色（${this.getTitleColorLabel(false)}）`,
        colors: READER_TITLE_COLORS,
        selectedColor: this.titleColor,
        onChange: (color: string) => this.onTitleColorChange(color, false)
      })
      MenuSettingPalette({
        title: `夜间标题颜色（${this.getTitleColorLabel(true)}）`,
        colors: READER_TITLE_COLORS,
        selectedColor: this.titleColorNight,
        onChange: (color: string) => this.onTitleColorChange(color, true)
      })
      Row() {
        Text('标题颜色跟随正文').fontSize(11).fontColor('#C6D3FF')
          .onClick(() => {
            this.onTitleColorChange('', false);
            this.onTitleColorChange('', true);
          })
      }.width('100%').padding(12).backgroundColor('#202127').borderRadius(12)
      // 分段：上游把标题切成多段，首段正常字号、后续段按缩放（ReaderTitleSegmentation.kt）。
      this.TitleChoiceRow(`标题分段（${this.getTitleSegTypeLabel()}）`, ['不分段', '按字数', '按分隔符', '按正则'],
        Math.max(0, Math.min(3, this.titleSegType)), (index: number) => this.onTitleSegTypeChange(index))
      if (this.titleSegType === 1) {
        MenuSettingSlider({
          title: '分段字数', value: this.titleSegDistance, minValue: 1, maxValue: 40, stepValue: 1,
          onChange: (value: number) => this.onTitleSegDistanceChange(value)
        })
      } else if (this.titleSegType !== 0) {
        TextInput({ text: this.titleSegFlag, placeholder: this.titleSegType === 2 ? '分隔符，多个用英文逗号分隔' : '正则表达式' })
          .width('100%').height(44).backgroundColor('#202127').borderRadius(12)
          .fontSize(12).fontColor('#E5E6EB').margin({ bottom: 8 })
          .onChange((value: string) => this.onTitleSegFlagChange(value))
      }
      if (this.titleSegType !== 0) {
        MenuSettingSlider({
          title: '副标题字号比例', value: this.titleSegScaling, minValue: 1, maxValue: 2, stepValue: 0.1,
          onChange: (value: number) => this.onTitleSegScalingChange(value)
        })
      }
      Text('标题样式参与分页度量：改字号、行距、间距或分段后，章节页数会重新计算。标题颜色留空时跟随正文色。')
        .fontSize(10).fontColor(this.themeColorTextTertiary).width('100%').padding(12)
    }.width('100%').padding({ bottom: 16 })
  }

  /** 把设置里存的沙箱绝对路径转成 `Image()` 能读的 `file://` URI（裸路径会渲染空白）。 */
  private badgeImageSource(): string {
    const path = this.bookmarkBadgeImage;
    return path.startsWith('file://') ? path : `file://${path}`;
  }

  @Builder
  private settingsContent(showHandle: boolean) {
    Column() {
      if (showHandle) {
        Row().width(32).height(4).backgroundColor('#C5C6CD').borderRadius(4).margin({ top: 10, bottom: 14 })
      }
      Row() {
        Row() {
          Image($r('app.media.reader_back')).width(22).height(22).fillColor('#E5E6EB')
        }.width(38).height(38).justifyContent(FlexAlign.Center)
          .backgroundColor('#292A31').borderRadius(19).onClick(() => {
            if (this.selectedSettingsTab >= 2) { this.selectedSettingsTab = this.previousMainSettingsTab; }
            else { this.onBack(); }
          })
        Text(this.selectedSettingsTab === 2 ? '信息' : this.selectedSettingsTab === 3 ? '更多设置' : '阅读界面')
          .fontSize(17).fontColor('#E5E6EB').margin({ left: 10 })
        Blank()
      }.width('100%').padding({ left: 16, right: 16, bottom: 14 })

      if (this.selectedSettingsTab < 2) {
        Swiper() {
          this.globalSettingsPage()
          this.menuSettingsContent()
        }
        .index(this.selectedSettingsTab)
        .loop(false)
        .indicator(false)
        .onChange((index: number) => this.selectSettingsTab(index))
        .layoutWeight(1)
        .width('100%')
      } else if (this.selectedSettingsTab === 2) {
        this.informationSettingsContent()
      } else {
        this.moreSettingsContent()
      }

      if (this.selectedSettingsTab < 2) {
        Row() {
          Text('全局').fontSize(10).fontColor('#E7E8ED').layoutWeight(1).textAlign(TextAlign.Center)
            .backgroundColor(this.selectedSettingsTab === 0 ? '#454B62' : '#1E1F25')
            .borderRadius(15).padding(8).onClick(() => this.selectSettingsTab(0))
          Text('菜单').fontSize(10).fontColor('#C1C2CA').layoutWeight(1).textAlign(TextAlign.Center)
            .backgroundColor(this.selectedSettingsTab === 1 ? '#454B62' : '#1E1F25')
            .borderRadius(15).padding(8).onClick(() => this.selectSettingsTab(1))
          Text('信息').fontSize(10).fontColor('#C1C2CA').layoutWeight(1).textAlign(TextAlign.Center)
            .backgroundColor('#1E1F25').borderRadius(15).padding(8).onClick(() => this.selectSettingsTab(2))
          Text('更多').fontSize(10).fontColor('#C1C2CA').layoutWeight(1).textAlign(TextAlign.Center)
            .backgroundColor('#1E1F25').borderRadius(15).padding(8).onClick(() => this.selectSettingsTab(3))
        }.padding({ left: 14, right: 14, top: 10, bottom: 16 })
      }
    }.width('100%').height('100%')
      .backgroundColor(this.asSheet ? '#D91A1B21' : this.themeColorSurfaceSecondary)
      .borderRadius(this.asSheet ? 22 : 0).clip(this.asSheet)
  }

  @Builder
  private globalSettingsPage() {
    // 整页纵向可滚动：字号卡 + 背景样式卡行 + 翻页动画行加起来比面板高，
    // 不滚的话最后一行会被底部 tab 栏盖住（上游 GlobalThemePage 也是 verticalScroll）。
    Scroll() {
      Column() {
        Row() {
          Column() {
            Row() {
              Text('字号').fontSize(14).fontColor('#D9DAE0').layoutWeight(1)
              Text(this.fontSize.toString()).fontSize(12).fontColor('#E5E6EB')
            }
            Slider({
              value: this.fontSize,
              min: 5,
              max: 50,
              step: 1,
              style: SliderStyle.OutSet
            })
              .selectedColor('#B9C6FF')
              .trackColor('#4B4D59')
              .blockColor('#B9C6FF')
              .onChange((value: number, mode: SliderChangeMode) => {
                if (mode === SliderChangeMode.Moving || mode === SliderChangeMode.Click ||
                  mode === SliderChangeMode.End) {
                  this.onFontSizeChange(Math.round(value))
                }
              })
          }
          .layoutWeight(1)
          Stack({ alignContent: Alignment.Center }) {
            Image($r('app.media.reader_info_text_fields'))
              .width(22)
              .height(22)
              .fillColor('#E5E6EB')
          }
          .width(56)
          .height(56)
          .backgroundColor('#292A31')
          .borderRadius(12)
          .margin({ left: 10 })
          .onClick(() => this.openDetailSheet('排版设置', '正文、标题、页眉页脚与边距设置'))
        }
        .padding(12)
        .backgroundColor('#202127')
        .borderRadius(13)

        Row() {
          Text('背景').fontSize(14).fontColor('#D9DAE0').layoutWeight(1)
          Text('长按自定义').fontSize(10).fontColor('#8F929D')
            .onClick(() => this.openDetailSheet('自定义阅读背景', '背景图片、背景颜色与文字颜色设置'))
          Image($r('app.media.app_visibility')).width(18).height(18)
            .fillColor(this.eyeProtectionActive ? '#C6D3FF' : '#D9DAE0').margin({ left: 10 })
            .onClick(() => this.onEyeProtectionToggle())
            .gesture(LongPressGesture({ duration: 500 }).onAction(() => {
              this.openDetailSheet('护眼设置', '护眼模式与色温参数');
            }))
          Image(this.readerNightMode ? $r('app.media.app_moon') : $r('app.media.app_daynight'))
            .width(18).height(18).fillColor('#D9DAE0').margin({ left: 9 })
            .onClick(() => this.onToggleNightMode())
        }.margin({ top: 13, bottom: 8 })

        Scroll(this.backgroundScroller) {
          Row() {
            BackgroundShareOption({ selected: this.shareLayout })
              .margin({ right: 8 }).onClick(() => this.onShareLayoutChange(!this.shareLayout))
            ForEach(this.backgroundStyles, (style: ReaderBackgroundStyle, styleIndex: number) => {
              BackgroundOption({
                label: this.getBackgroundStyleLabel(style),
                color: this.readerNightMode ? style.nightColor : style.dayColor,
                selected: this.paperIndex === styleIndex
              }).margin({ right: 8 })
                .onClick(() => this.onPaperChange(styleIndex))
                .gesture(LongPressGesture({ duration: 500 }).onAction(() => {
                  // 长按进「改这一份样式」，对齐上游 StyleCard 的 onLongClick → onOpenBgTextConfig。
                  this.editingStyleIndex = styleIndex;
                  this.openDetailSheet('编辑背景样式', '修改这一份样式的名字与日间、夜间背景颜色');
                }))
            }, (style: ReaderBackgroundStyle) => `${style.id}|${style.name}|${style.dayColor}|${style.nightColor}`)
            BackgroundStyleActionCard({
              icon: $r('app.media.app_add'), selected: false
            }).margin({ right: 8 }).onClick(() => this.onAddBackgroundStyle())
            BackgroundStyleActionCard({
              icon: $r('app.media.reader_arrow_forward'), selected: false
            }).onClick(() => this.openDetailSheet('主题列表', '管理全部背景样式：新增、删除、排序'))
          }.height(56)
        }.width('100%').height(56).scrollable(ScrollDirection.Horizontal).scrollBar(BarState.Off)

        Row() {
          Text('翻页动画').fontSize(12).fontColor('#D9DAE0').layoutWeight(1)
          Text(this.getPageAnimationLabel()).fontSize(11).fontColor('#D9DAE0').padding(8)
            .backgroundColor('#292A31').borderRadius(8)
            .onClick(() => this.openDetailSheet('翻页动画', '覆盖、滑动、仿真、滚动、淡入淡出、无动画'))
          Image($r('app.media.app_anim_speed')).width(20).height(20).fillColor('#D9DAE0').margin({ left: 12 })
          .onClick(() => this.openDetailSheet('翻页动画速度', `当前：${this.getAnimationSpeedLabel()}；可选极速、快速、适中、优雅`))
          Image($r('app.media.app_padding')).width(20).height(20).fillColor('#D9DAE0').margin({ left: 14 })
            .onClick(() => this.openDetailSheet('页边距', '页面内边距与正文留白设置'))
        }.padding(13).backgroundColor('#202127').borderRadius(13).margin({ top: 13 })
      }.width('100%').padding({ left: 14, right: 14, bottom: 14 })
    }
    .width('100%')
    .layoutWeight(1)
    .scrollBar(BarState.Off)
    .align(Alignment.Top)
  }

  private selectSettingsTab(index: number): void {
    if (index >= 2 && this.selectedSettingsTab < 2) {
      this.previousMainSettingsTab = this.selectedSettingsTab;
    }
    this.selectedSettingsTab = index;
  }

  @Builder
  private menuSettingsContent() {
    Column() {
      Row() {
        Text('菜单栏').fontSize(11).fontColor(this.selectedMenuSettingsTab === 0 ? '#ECECF0' : '#B7B8C1')
          .layoutWeight(1).textAlign(TextAlign.Center)
          .backgroundColor(this.selectedMenuSettingsTab === 0 ? '#454B62' : '#202127')
          .borderRadius(15).padding(8).onClick(() => this.selectedMenuSettingsTab = 0)
        Text('底栏布局').fontSize(11).fontColor(this.selectedMenuSettingsTab === 1 ? '#ECECF0' : '#B7B8C1')
          .layoutWeight(1).textAlign(TextAlign.Center)
          .backgroundColor(this.selectedMenuSettingsTab === 1 ? '#454B62' : '#202127')
          .borderRadius(15).padding(8).onClick(() => this.selectedMenuSettingsTab = 1)
        Text('顶栏布局').fontSize(11).fontColor(this.selectedMenuSettingsTab === 2 ? '#ECECF0' : '#B7B8C1')
          .layoutWeight(1).textAlign(TextAlign.Center)
          .backgroundColor(this.selectedMenuSettingsTab === 2 ? '#454B62' : '#202127')
          .borderRadius(15).padding(8).onClick(() => this.selectedMenuSettingsTab = 2)
      }.width('100%').padding({ left: 14, right: 14, bottom: 8 })

      Scroll(this.menuSettingsScroller) {
        Column() {
          if (this.selectedMenuSettingsTab === 1) {
            MenuSettingOption({
              title: '滑动条显示样式',
              detail: this.readSliderMode === '1' ? '不显示' : '常驻',
              migrated: true
            }).margin({ left: 14, right: 14, bottom: 8 })
              .onClick(() => this.openDetailSheet('滑动条显示样式', '底栏是否显示进度滑动条'))
            MenuSettingSwitch({
              title: '显示底栏图标名称',
              detail: '在阅读操作图标下显示文字',
              checked: this.showBottomActionText,
              onChange: (enabled: boolean) => this.onBottomActionTextChange(enabled)
            }).margin({ left: 14, right: 14, bottom: 8 })
            MenuSettingIconStyle({
              value: this.bottomIconStyle,
              onChange: (style: number) => this.onBottomIconStyleChange(style)
            }).margin({ left: 14, right: 14, bottom: 8 })
            MenuSettingSlider({
              title: '每行图标数',
              value: this.bottomItemsPerRow,
              minValue: 2,
              maxValue: 8,
              onChange: (count: number) => this.onBottomItemsPerRowChange(count)
            }).margin({ left: 14, right: 14, bottom: 8 })
            MenuSettingSlider({
              title: '底栏图标行数',
              value: this.bottomRowCount,
              minValue: 1,
              maxValue: 2,
              onChange: (count: number) => this.onBottomRowCountChange(count)
            }).margin({ left: 14, right: 14, bottom: 8 })
          } else if (this.selectedMenuSettingsTab === 2) {
            MenuSettingSwitch({
              title: '快捷图标行',
              detail: '在标题栏下方显示快捷阅读操作',
              checked: this.showQuickActions,
              onChange: (enabled: boolean) => this.onQuickActionsChange(enabled)
            }).margin({ left: 14, right: 14, bottom: 8 })
          }
          ForEach(this.getMenuSettingsEntries(), (entry: ReaderMenuSettingsEntry) => {
            this.menuSettingsEntry(entry)
          }, (entry: ReaderMenuSettingsEntry) => `${this.selectedMenuSettingsTab}-${entry.title}`)
        }.width('100%').padding({ top: 4, bottom: 8 })
      }.width('100%').layoutWeight(1).scrollBar(BarState.Off)
    }.width('100%').layoutWeight(1)
  }

  @Builder
  private menuSettingsEntry(entry: ReaderMenuSettingsEntry) {
    if (entry.section === true) {
      MenuSettingSection({ title: entry.title })
    } else if (!this.isMenuSettingsEntryVisible(entry.title)) {
      Blank().height(0)
    } else if (entry.title === '底栏按钮配置' || entry.title === '标题栏操作按钮' || entry.title === '标题栏悬浮图标配置') {
      MenuSettingOption({ title: entry.title, detail: entry.detail, migrated: true })
        .onClick(() => this.handleMenuSettingsEntryClick(entry))
    } else if (this.isMenuToggle(entry.title)) {
      MenuSettingSwitch({
        title: entry.title,
        detail: entry.detail,
        checked: entry.title === '菜单栏边框'
          // 上游开关本体就是 readMenuBorderWidth > 0（SystemMenuPage.kt:398），没有独立布尔字段。
          ? this.readMenuBorderWidth > 0
          : entry.title === '显示标题栏图标'
            ? this.showTitleBarIcons
            : entry.title === '悬浮图标液态玻璃按钮'
              ? this.readMenuFloatingIconLiquidGlass
            : entry.title === '底栏悬浮'
              ? this.readMenuFloatingBottomBar
              : entry.title === '底栏模糊'
                // 上游「模糊效果」开关只看「是否不等于 None」，写回时固定 Haze（SystemMenuPage.kt:670-680）。
                ? this.readMenuBottomBarBlurMode !== 0
                : entry.title === '底栏液态玻璃'
                  // 上游「液态玻璃背景」只在悬浮时出现，勾选写 LiquidGlass(1)（SystemMenuPage.kt:707-726）。
                  ? this.readMenuBottomBarBlurMode === 1
                  : entry.title === '底栏按钮液态玻璃'
                    ? this.readMenuBottomBarLiquidGlassButtons
                    : entry.title === '标题栏胶囊'
                      ? this.readMenuTopBarTitleCapsule
                      : entry.title === '标题栏紧凑'
                        ? this.titleBarCompact
                        : entry.title === '顶栏模糊'
                          // 上游「模糊效果」开关只认 Haze(2)（SystemMenuPage.kt:790-800）。
                          ? this.readMenuTopBarBlurMode === 2
                          : entry.title === '顶栏液态玻璃按钮'
                            ? this.readMenuTopBarLiquidGlassButtons
                            : entry.title === '合并标题栏按钮' ? this.readMenuTopBarMergeButtons : false,
        onChange: (enabled: boolean) => {
          if (entry.title === '菜单栏边框') {
            // 打开时给上游默认宽度 1，关闭时写 0（SystemMenuPage.kt:401-406 的 BorderWidth(if (it) 1 else 0)）。
            this.onReadMenuBorderWidthChange(enabled ? 1 : 0);
          }
          else if (entry.title === '显示标题栏图标') { this.onShowTitleBarIconsChange(enabled); }
          else if (entry.title === '悬浮图标液态玻璃按钮') { this.onReadMenuFloatingIconLiquidGlassChange(enabled); }
          else if (entry.title === '底栏悬浮') { this.onReadMenuFloatingBottomBarChange(enabled); }
          else if (entry.title === '底栏模糊') {
            // 打开写 Haze(2)、关闭写 None(0)，与上游开关的两个取值一致。
            this.onReadMenuBottomBarBlurModeChange(enabled ? 2 : 0);
          }
          else if (entry.title === '底栏液态玻璃') {
            // 上游：勾选写 LiquidGlass(1)；取消时若当前不是 None 就退回 Haze(2)，否则 None(0)。
            const next = enabled ? 1 : (this.effectiveBottomBarBlurMode() !== 0 ? 2 : 0);
            this.onReadMenuBottomBarBlurModeChange(next);
          }
          else if (entry.title === '底栏按钮液态玻璃') { this.onReadMenuBottomBarLiquidGlassButtonsChange(enabled); }
          else if (entry.title === '标题栏胶囊') { this.onReadMenuTopBarTitleCapsuleChange(enabled); }
          else if (entry.title === '标题栏紧凑') { this.onTitleBarCompactChange(enabled); }
          else if (entry.title === '顶栏模糊') {
            // 上游：开写 Haze(2)、关写 None(0)，样式取当前值（SystemMenuPage.kt:790-805）。
            this.onReadMenuTopBarBlurModeChange(enabled ? 2 : 0);
          }
          else if (entry.title === '顶栏液态玻璃按钮') { this.onReadMenuTopBarLiquidGlassButtonsChange(enabled); }
          else if (entry.title === '合并标题栏按钮') { this.onReadMenuTopBarMergeButtonsChange(enabled); }
          else { this.showNotMigrated(entry.title); }
        }
      })
    } else if (this.isMenuSlider(entry.title)) {
      MenuSettingSlider({
        title: entry.title,
        value: this.menuSliderValue(entry.title),
        minValue: this.menuSliderMinimum(entry.title),
        maxValue: this.menuSliderMaximum(entry.title),
        onChange: (value: number) => {
          if (entry.title === '底栏圆角') { this.onReadMenuBottomCornerRadiusChange(value); }
          else if (entry.title === '底栏模糊透明度') { this.onReadMenuBlurAlphaChange(value); }
          else if (entry.title === '菜单栏边框宽度') { this.onReadMenuBorderWidthChange(value); }
          else if (entry.title === '菜单模糊半径') { this.onReadMenuBlurRadiusChange(value); }
          // 上游只有 read_menu_blur_alpha 一个字段，菜单栏 tab 与底栏 tab 共用同一项（SystemMenuPage.kt:448-456），
          // 因此这里与「底栏模糊透明度」写同一个回调。
          else if (entry.title === '菜单模糊透明度') { this.onReadMenuBlurAlphaChange(value); }
          else { this.showNotMigrated(entry.title); }
        }
      })
    } else if (this.getMenuChoices(entry.title).length > 0) {
      MenuSettingSegments({
        title: entry.title,
        choices: this.getMenuChoices(entry.title),
        selectedIndex: this.getMenuSelectedIndex(entry.title),
        onSelect: (index: number) => {
          if (entry.title === '工具栏样式') { this.onReadBarStyleChange(index); }
          if (entry.title === '菜单颜色来源') { this.onReadMenuColorModeChange(index); }
          if (entry.title === '调色板风格') { this.onReadMenuPaletteStyleChange(MENU_PALETTE_VALUES[index] ?? ''); }
          if (entry.title === '显示亮度视图') { this.onShowBrightnessViewChange(['0', '1', '2'][index] ?? '0'); }
          if (entry.title === '亮度条位置') { this.onBrightnessVwPosChange(index === 0 ? '0' : '1'); }
          if (entry.title === '标题栏模式') { this.onTitleBarModeChange(['0', '1', '2', '3'][index] ?? '1'); }
          if (entry.title === '标题栏悬浮图标位置') { this.onTitleBarIconPositionChange(index); }
          if (entry.title === '标题栏图标样式') { this.onTitleBarIconStyleChange(index); }
          if (entry.title === '顶栏模糊样式') { this.onReadMenuTopBarBlurStyleChange(index === 1 ? 1 : 0); }
          this.openDetailSheet(entry.title, entry.detail);
        }
      })
    } else if (this.isMenuColor(entry.title)) {
      MenuSettingColor({
        title: entry.title,
        detail: entry.detail,
        dayColor: this.menuColorDay(entry.title),
        nightColor: this.menuColorNight(entry.title)
      })
        .onClick(() => this.openDetailSheet(entry.title, entry.detail))
    } else {
      MenuSettingOption({ title: entry.title, detail: entry.detail })
        .onClick(() => this.openDetailSheet(entry.title, entry.detail))
    }
  }

  private handleMenuSettingsEntryClick(entry: ReaderMenuSettingsEntry): void {
    if (entry.title === '底栏按钮配置') {
      this.draftBottomActions = this.bottomActions.map(
        (item: ReaderBottomActionConfig): ReaderBottomActionConfig => ({ id: item.id, enabled: item.enabled })
      );
      this.bottomActionConfigVisible = true;
    } else if (entry.title === '标题栏操作按钮') {
      this.draftTopActions = this.topActions.map(
        (item: ReaderBottomActionConfig): ReaderBottomActionConfig => ({ id: item.id, enabled: item.enabled })
      );
      this.topActionConfigVisible = true;
    } else if (entry.title === '标题栏悬浮图标配置') {
      // 上游 FloatingBarIconConfigSheet 走通用按钮配置面板（排序 + 开关 + 自定义图标），
      // 这里复用顶栏操作按钮那套 sheet，只把草稿源换成浮动图标池。
      this.draftTopActions = this.floatingIcons.map(
        (item: ReaderBottomActionConfig): ReaderBottomActionConfig => ({ id: item.id, enabled: item.enabled })
      );
      this.floatingIconConfigVisible = true;
    }
  }

  /**
   * 实际生效的底栏模糊模式。对齐上游 `SystemMenuPage.kt:560-568`：
   * 非悬浮时如果存的是液态玻璃(1)，实际按雾化(2)渲染 —— 因为液态玻璃需要悬浮形状才成立。
   */
  private effectiveBottomBarBlurMode(): number {
    if (!this.readMenuFloatingBottomBar && this.readMenuBottomBarBlurMode === 1) { return 2; }
    return this.readMenuBottomBarBlurMode;
  }

  private isMenuToggle(title: string): boolean {
    return ['显示标题栏图标', '悬浮图标液态玻璃按钮', '标题栏胶囊', '标题栏紧凑', '顶栏液态玻璃按钮',
      '合并标题栏按钮', '显示图标文字', '底栏悬浮', '底栏模糊', '顶栏模糊', '底栏液态玻璃',
      '底栏按钮液态玻璃', '菜单栏边框'].includes(title);
  }

  private isMenuSlider(title: string): boolean {
    return title.includes('透明度') || title.includes('半径') || title.includes('边框宽度') || title.includes('圆角');
  }

  private isMenuColor(title: string): boolean {
    return title.includes('颜色') || title.includes('色');
  }

  private menuSliderValue(title: string): number {
    // 已接的两项读真值，其余仍是被 KI-E1/E2 接管的占位值。
    if (title === '底栏模糊透明度') { return this.readMenuBlurAlpha; }
    if (title === '底栏圆角') { return this.readMenuBottomCornerRadius; }
    if (title === '菜单栏边框宽度') { return this.readMenuBorderWidth; }
    if (title === '菜单模糊半径') { return this.readMenuBlurRadius; }
    if (title === '菜单模糊透明度') { return this.readMenuBlurAlpha; }
    if (title.includes('透明度')) { return 70; }
    if (title.includes('圆角')) { return 20; }
    if (title.includes('宽度')) { return 1; }
    return 8;
  }

  private menuSliderMaximum(title: string): number {
    // 底栏圆角上限对齐上游 0f..32f（SystemMenuPage.kt:645-655）。
    if (title === '底栏圆角') { return 32; }
    if (title.includes('透明度')) { return 100; }
    if (title.includes('边框宽度')) { return 4; }
    if (title.includes('宽度')) { return 10; }
    return 32;
  }

  private menuSliderMinimum(title: string): number {
    return title.includes('边框宽度') ? 1 : 0;
  }

  /**
   * 写回菜单颜色项的日/夜值。四项分别对应上游三个字段：
   * 「菜单背景颜色」→ readMenuBgColor / Night；「菜单容器颜色」→ readMenuContainerColor / Night；
   * 「种子色」与「菜单强调颜色」→ readMenuAccentColor / Night（上游两处 UI 共用这一对字段）。
   * 再点一次已选中的颜色 = 清除，回到上游的「0 = 未设置」。
   */
  private applyMenuColor(title: string, color: string, night: boolean): void {
    const current = night ? this.menuColorNight(title) : this.menuColorDay(title);
    const next = current.toUpperCase() === color.toUpperCase() ? '' : color;
    if (title === '菜单背景颜色') {
      if (night) { this.onReadMenuBgColorNightChange(next); } else { this.onReadMenuBgColorChange(next); }
      return;
    }
    if (title === '菜单容器颜色') {
      if (night) { this.onReadMenuContainerColorNightChange(next); } else { this.onReadMenuContainerColorChange(next); }
      return;
    }
    if (title === '菜单栏边框颜色') {
      if (night) { this.onReadMenuBorderColorNightChange(next); } else { this.onReadMenuBorderColorChange(next); }
      return;
    }
    if (title === '菜单文字颜色') {
      if (night) { this.onReadMenuTextColorNightChange(next); } else { this.onReadMenuTextColorChange(next); }
      return;
    }
    if (title === '菜单模糊颜色') {
      if (night) { this.onReadMenuBlurColorNightChange(next); } else { this.onReadMenuBlurColorChange(next); }
      return;
    }
    if (night) { this.onReadMenuAccentColorNightChange(next); } else { this.onReadMenuAccentColorChange(next); }
  }

  /**
   * 菜单颜色项的日间色。四项分别对应上游 `SystemMenuPage.kt:308-368` 的
   * `dayMenuAccentColor`（种子色与强调色共用）、`dayMenuBgColor`、`dayMenuContainerColor`；
   * 空串即上游的「0 = 未设置」。
   */
  private menuColorDay(title: string): string {
    if (title === '菜单背景颜色') { return this.readMenuBgColor; }
    if (title === '菜单容器颜色') { return this.readMenuContainerColor; }
    if (title === '菜单栏边框颜色') { return this.readMenuBorderColor; }
    if (title === '菜单文字颜色') { return this.readMenuTextColor; }
    if (title === '菜单模糊颜色') { return this.readMenuBlurColor; }
    return this.readMenuAccentColor;
  }

  /** 菜单颜色项的夜间色，与 `menuColorDay` 一一对应，取上游的 xxxNight。 */
  private menuColorNight(title: string): string {
    if (title === '菜单背景颜色') { return this.readMenuBgColorNight; }
    if (title === '菜单容器颜色') { return this.readMenuContainerColorNight; }
    if (title === '菜单栏边框颜色') { return this.readMenuBorderColorNight; }
    if (title === '菜单文字颜色') { return this.readMenuTextColorNight; }
    if (title === '菜单模糊颜色') { return this.readMenuBlurColorNight; }
    return this.readMenuAccentColorNight;
  }

  private getMenuChoices(title: string): string[] {
    if (title === '工具栏样式') { return ['跟随系统', '跟随阅读背景', '自定义']; }
    if (title === '调色板风格') { return ['跟随系统', '柔和', '中性', '鲜艳', '表现力', '彩虹', '水果拼盘', '单色', '仿真', '内容取色']; }
    if (title === '菜单颜色来源') { return ['种子色', '自定义颜色']; }
    if (title === '显示亮度视图') { return ['关闭', '横排', '竖排']; }
    if (title === '亮度条位置') { return ['左侧', '右侧']; }
    // 上游 title_bar_mode 四值（values-zh-rCN/arrays.xml:242-247、array_values.xml:146-151）：
    // "0" 书名在应用栏 + 章节名下一行；"1" 书名独立一行 + 章节名再一行；
    // "2" 只有书名（应用栏），无章节行；"3" 都不显示。
    if (title === '标题栏模式') {
      return ['在应用栏上显示', '在独立行上显示', '仅显示标题', '不显示'];
    }
    // 上游 title_bar_icon_position 四值（values-zh-rCN/strings.xml:2486-2489）。
    if (title === '标题栏悬浮图标位置') { return ['左上', '右上', '左下', '右下']; }
    if (title.includes('图标样式')) { return ['纯色', '色调', '描边']; }
    if (title.includes('模糊样式')) { return ['纯色', '渐变']; }
    return [];
  }

  private getMenuSelectedIndex(title: string): number {
    if (title === '工具栏样式') { return Math.max(0, Math.min(2, this.readBarStyle)); }
    if (title === '菜单颜色来源') { return Math.max(0, Math.min(1, this.readMenuColorMode)); }
    if (title === '调色板风格') {
      const paletteIndex = MENU_PALETTE_VALUES.indexOf(this.readMenuPaletteStyle);
      return paletteIndex >= 0 ? paletteIndex : 0;
    }
    if (title === '显示亮度视图') { return ['0', '1', '2'].indexOf(this.showBrightnessView); }
    if (title === '亮度条位置') { return this.brightnessVwPos === '0' ? 0 : 1; }
    if (title === '底栏模糊样式') { return this.readMenuBottomBarBlurStyle === 1 ? 1 : 0; }
    if (title === '标题栏模式') { return Math.max(0, ['0', '1', '2', '3'].indexOf(this.titleBarMode)); }
    if (title === '标题栏悬浮图标位置') { return Math.max(0, Math.min(3, this.titleBarIconPosition)); }
    if (title === '标题栏图标样式') { return Math.max(0, Math.min(2, this.titleBarIconStyle)); }
    if (title === '顶栏模糊样式') { return this.readMenuTopBarBlurStyle === 1 ? 1 : 0; }
    return 0;
  }

  private applyDetailChoicePreview(choice: string): void {
    this.detailSelectedOption = choice;
    const choices = this.getDetailChoices(this.detailSheetTitle);
    const choiceIndex = choices.indexOf(choice);
    if (this.detailSheetTitle === '显示模式' && choiceIndex >= 0) {
      this.onInfoSettingsChange(updateReaderInfoSettings(this.infoSettings, {
        headerMode: this.infoSubTab === 0 ? choiceIndex : this.infoSettings.headerMode,
        footerMode: this.infoSubTab === 1 ? (choiceIndex === 1 ? 1 : 0) : this.infoSettings.footerMode
      }));
    }
    if (this.detailInfoSlot !== undefined && this.detailSheetTitle.endsWith('显示内容') && choiceIndex >= 0) {
      const tipValue = READ_INFO_TIP_VALUES[choiceIndex] ?? 0;
      if (tipValue === 18) {
        this.detailCustomText = this.getInfoTipTemplate(this.detailInfoSlot);
      } else {
        this.saveInfoTip(this.detailInfoSlot, tipValue);
      }
    }
    if (this.detailSheetTitle === '工具栏样式' && choiceIndex >= 0) {
      this.onReadBarStyleChange(choiceIndex);
    }
    if (this.detailSheetTitle === '菜单颜色来源' && choiceIndex >= 0) {
      this.onReadMenuColorModeChange(choiceIndex);
    }
    if (this.detailSheetTitle === '调色板风格' && choiceIndex >= 0) {
      this.onReadMenuPaletteStyleChange(MENU_PALETTE_VALUES[choiceIndex] ?? '');
    }
    if (this.detailSheetTitle === '显示亮度视图' && choiceIndex >= 0) {
      this.onShowBrightnessViewChange(['0', '1', '2'][choiceIndex] ?? '0');
    }
    if (this.detailSheetTitle === '亮度条位置' && choiceIndex >= 0) {
      this.onBrightnessVwPosChange(choiceIndex === 0 ? '0' : '1');
    }
    if (this.detailSheetTitle === '底栏模糊样式' && choiceIndex >= 0) {
      this.onReadMenuBottomBarBlurStyleChange(choiceIndex === 1 ? 1 : 0);
    }
    if (this.detailSheetTitle === '标题栏模式' && choiceIndex >= 0) {
      this.onTitleBarModeChange(['0', '1', '2', '3'][choiceIndex] ?? '1');
    }
    if (this.detailSheetTitle === '标题栏图标样式' && choiceIndex >= 0) {
      this.onTitleBarIconStyleChange(choiceIndex);
    }
    // 浮动图标位置四值（上游 title_bar_icon_position，SystemMenuPage.kt:512-520）。
    if (this.detailSheetTitle === '标题栏悬浮图标位置' && choiceIndex >= 0) {
      this.onTitleBarIconPositionChange(choiceIndex);
    }
    if (this.detailSheetTitle === '顶栏模糊样式' && choiceIndex >= 0) {
      this.onReadMenuTopBarBlurStyleChange(choiceIndex === 1 ? 1 : 0);
    }
    if (this.detailSheetTitle === '中文简繁体转换' && choiceIndex >= 0) {
      this.onChineseConverterTypeChange(choiceIndex);
    }
    if (this.detailSheetTitle === '翻页动画' && choiceIndex >= 0) { this.onPageAnimationChange(choiceIndex); }
    if (this.detailSheetTitle === '翻页动画速度' && choiceIndex >= 0) { this.onAnimationSpeedChange(choiceIndex); }
    if (this.detailSheetTitle === '屏幕方向' && choiceIndex >= 0) { this.onScreenOrientationChange(choiceIndex.toString()); }
    if (this.detailSheetTitle === '保持屏幕常亮' && choiceIndex >= 0) {
      this.onKeepLightChange(['0', '60', '300', '600', '-1'][choiceIndex] ?? '0');
    }
    if (this.detailSheetTitle === '横屏双页' && choiceIndex >= 0) {
      this.onDoubleHorizontalPageChange(['0', '1', '2', '3'][choiceIndex] ?? '0');
    }
    if (this.detailSheetTitle === '进度条行为' && choiceIndex >= 0) {
      this.onProgressBehaviorChange(choiceIndex === 1 ? 'chapter' : 'page');
    }
    if (this.detailSheetTitle === '滑动条显示样式' && choiceIndex >= 0) {
      this.onReadSliderModeChange(choiceIndex === 1 ? '1' : '0');
    }
    if (this.detailSheetTitle === '点击图片行为' && choiceIndex >= 0) {
      this.onClickImageBehaviorChange(choiceIndex.toString());
    }
    if (choiceIndex >= 0 && this.detailSheetTitle === '页眉日间文字颜色') {
      this.onInfoSettingsChange(updateReaderInfoSettings(this.infoSettings, {
        tipHeaderColor: READER_INFO_COLOR_VALUES[choiceIndex] ?? 0
      }));
    }
    if (choiceIndex >= 0 && this.detailSheetTitle === '页眉夜间文字颜色') {
      this.onInfoSettingsChange(updateReaderInfoSettings(this.infoSettings, {
        tipHeaderColorNight: READER_INFO_COLOR_VALUES[choiceIndex] ?? 0
      }));
    }
    if (choiceIndex >= 0 && this.detailSheetTitle === '页脚日间文字颜色') {
      this.onInfoSettingsChange(updateReaderInfoSettings(this.infoSettings, {
        tipFooterColor: READER_INFO_COLOR_VALUES[choiceIndex] ?? 0
      }));
    }
    if (choiceIndex >= 0 && this.detailSheetTitle === '页脚夜间文字颜色') {
      this.onInfoSettingsChange(updateReaderInfoSettings(this.infoSettings, {
        tipFooterColorNight: READER_INFO_COLOR_VALUES[choiceIndex] ?? 0
      }));
    }
    if (choiceIndex >= 0 && this.detailSheetTitle === '分割线颜色') {
      const dividerColors: number[] = [-1, 0, -16777216, -8355712, -1, -65536, -16711936, -16776961];
      this.onInfoSettingsChange(updateReaderInfoSettings(this.infoSettings, {
        tipDividerColor: dividerColors[choiceIndex] ?? -1
      }));
    }
  }

  private isMenuSettingsEntryVisible(title: string): boolean {
    // 底栏布局子页的两条互斥规则必须先判：下面那句 tab 短路会直接 return true，
    // 放在短路之后等于永不生效（本函数第一版就踩了这个坑）。
    // 与上游两个 AnimatedVisibility 一一对应 —— 非悬浮才显示「模糊样式」下拉，
    // 悬浮才显示「液态玻璃背景」开关（SystemMenuPage.kt:684-726）。
    // 上游 AnimatedVisibility(visible = !preferences.readMenuTopBarTitleCapsule)
    // 包住了「菜单标题显示方式」下拉（SystemMenuPage.kt:730 一带），胶囊开着就不显示。
    // 注意：必须写在下面 selectedMenuSettingsTab 短路之前，否则在标题栏 tab 里永不生效。
    if (title === '标题栏模式') { return !this.readMenuTopBarTitleCapsule; }
    if (title === '底栏模糊样式') { return !this.readMenuFloatingBottomBar; }
    if (title === '底栏液态玻璃') { return this.readMenuFloatingBottomBar; }
    if (this.selectedMenuSettingsTab !== 0) { return true; }
    // 三条可见性逐条照上游 SystemMenuPage.kt:276-320 的 AnimatedVisibility：
    // 调色板风格 showPaletteStyle = bottomMode == 1 || (bottomMode == 2 && colorMode == 0)；
    // 色板来源 bottomMode == 2；种子色 = 色板来源为种子色；三个自定义颜色 = 色板来源为自定义颜色。
    if (title === '调色板风格') {
      return this.readBarStyle === 1 || (this.readBarStyle === 2 && this.readMenuColorMode === 0);
    }
    if (title === '菜单颜色来源') { return this.readBarStyle === 2; }
    if (title === '亮度条位置') { return this.showBrightnessView === '2'; }
    if (title === '种子色') { return this.readBarStyle === 2 && this.readMenuColorMode === 0; }
    if (title === '菜单背景颜色' || title === '菜单容器颜色' || title === '菜单强调颜色') {
      return this.readBarStyle === 2 && this.readMenuColorMode === 1;
    }
    if (title === '标题栏悬浮图标配置' || title === '标题栏悬浮图标位置' || title === '悬浮图标液态玻璃按钮') {
      // 上游 SystemMenuPage.kt:497-500 用 AnimatedVisibility(visible = preferences.showTitleBarIcons) 包住这三项。
      return this.showTitleBarIcons;
    }
    // 上游 SystemMenuPage.kt:408-436 用 AnimatedVisibility(visible = borderEnabled) 包住宽度与颜色，
    // borderEnabled 就是 readMenuBorderWidth > 0。
    if (title === '菜单栏边框宽度' || title === '菜单栏边框颜色') { return this.readMenuBorderWidth > 0; }
    return true;
  }

  private getInfoTipValue(slot: ReaderInfoSlot): number {
    if (slot === 'headerLeft') { return this.infoSettings.tipHeaderLeft; }
    if (slot === 'headerMiddle') { return this.infoSettings.tipHeaderMiddle; }
    if (slot === 'headerRight') { return this.infoSettings.tipHeaderRight; }
    if (slot === 'footerLeft') { return this.infoSettings.tipFooterLeft; }
    if (slot === 'footerMiddle') { return this.infoSettings.tipFooterMiddle; }
    return this.infoSettings.tipFooterRight;
  }

  private getInfoTipTemplate(slot: ReaderInfoSlot): string {
    if (slot === 'headerLeft') { return this.infoSettings.customTipHeaderLeft; }
    if (slot === 'headerMiddle') { return this.infoSettings.customTipHeaderMiddle; }
    if (slot === 'headerRight') { return this.infoSettings.customTipHeaderRight; }
    if (slot === 'footerLeft') { return this.infoSettings.customTipFooterLeft; }
    if (slot === 'footerMiddle') { return this.infoSettings.customTipFooterMiddle; }
    return this.infoSettings.customTipFooterRight;
  }

  private setInfoTipValue(settings: ReaderInfoSettings, slot: ReaderInfoSlot, value: number): ReaderInfoSettings {
    if (slot === 'headerLeft') { return updateReaderInfoSettings(settings, { tipHeaderLeft: value }); }
    if (slot === 'headerMiddle') { return updateReaderInfoSettings(settings, { tipHeaderMiddle: value }); }
    if (slot === 'headerRight') { return updateReaderInfoSettings(settings, { tipHeaderRight: value }); }
    if (slot === 'footerLeft') { return updateReaderInfoSettings(settings, { tipFooterLeft: value }); }
    if (slot === 'footerMiddle') { return updateReaderInfoSettings(settings, { tipFooterMiddle: value }); }
    return updateReaderInfoSettings(settings, { tipFooterRight: value });
  }

  private setInfoTipTemplate(settings: ReaderInfoSettings, slot: ReaderInfoSlot, value: string): ReaderInfoSettings {
    if (slot === 'headerLeft') { return updateReaderInfoSettings(settings, { customTipHeaderLeft: value }); }
    if (slot === 'headerMiddle') { return updateReaderInfoSettings(settings, { customTipHeaderMiddle: value }); }
    if (slot === 'headerRight') { return updateReaderInfoSettings(settings, { customTipHeaderRight: value }); }
    if (slot === 'footerLeft') { return updateReaderInfoSettings(settings, { customTipFooterLeft: value }); }
    if (slot === 'footerMiddle') { return updateReaderInfoSettings(settings, { customTipFooterMiddle: value }); }
    return updateReaderInfoSettings(settings, { customTipFooterRight: value });
  }

  private saveInfoTip(slot: ReaderInfoSlot, value: number, template: string = ''): void {
    let next: ReaderInfoSettings = this.infoSettings;
    const slots: ReaderInfoSlot[] = ['headerLeft', 'headerMiddle', 'headerRight', 'footerLeft', 'footerMiddle', 'footerRight'];
    if (value !== 0) {
      for (let index = 0; index < slots.length; index++) {
        const other = slots[index];
        if (other !== undefined && other !== slot && this.getInfoTipValue(other) === value) {
          next = this.setInfoTipValue(next, other, 0);
        }
      }
    }
    next = this.setInfoTipValue(next, slot, value);
    if (value === 18) { next = this.setInfoTipTemplate(next, slot, template); }
    this.onInfoSettingsChange(next);
  }

  private openInfoTipSheet(position: string): void {
    const isHeader = this.infoSubTab === 0;
    const slot: ReaderInfoSlot = isHeader
      ? (position === '左侧' ? 'headerLeft' : position === '中间' ? 'headerMiddle' : 'headerRight')
      : (position === '左侧' ? 'footerLeft' : position === '中间' ? 'footerMiddle' : 'footerRight');
    this.openDetailSheet(`${position}显示内容`, '选择此位置显示的信息类型');
    this.detailInfoSlot = slot;
    const value = this.getInfoTipValue(slot);
    const index = READ_INFO_TIP_VALUES.indexOf(value);
    this.detailSelectedOption = this.getInfoTipChoices()[index] ?? '无';
    this.detailCustomText = this.getInfoTipTemplate(slot);
  }

  private saveCustomInfoTip(): void {
    if (this.detailInfoSlot === undefined) { return; }
    this.saveInfoTip(this.detailInfoSlot, 18, this.detailCustomText);
    this.detailSheetVisible = false;
  }

  private getInfoModeLabel(): string {
    if (this.infoSubTab === 0) {
      return ['状态栏显示时隐藏', '显示', '隐藏'][this.infoSettings.headerMode] ?? '状态栏显示时隐藏';
    }
    return this.infoSettings.footerMode === 1 ? '隐藏' : '显示';
  }

  @Builder
  private informationSettingsContent() {
    Column() {
      Row() {
        Text('页眉').fontSize(11).fontColor(this.infoSubTab === 0 ? '#ECECF0' : '#B7B8C1')
          .layoutWeight(1).textAlign(TextAlign.Center).backgroundColor(this.infoSubTab === 0 ? '#454B62' : '#202127')
          .borderRadius(14).padding(8).onClick(() => this.infoSubTab = 0)
        Text('页脚').fontSize(11).fontColor(this.infoSubTab === 1 ? '#ECECF0' : '#B7B8C1')
          .layoutWeight(1).textAlign(TextAlign.Center).backgroundColor(this.infoSubTab === 1 ? '#454B62' : '#202127')
          .borderRadius(14).padding(8).margin({ left: 8 }).onClick(() => this.infoSubTab = 1)
        Stack({ alignContent: Alignment.Center }) {
          Image($r('app.media.app_padding')).width(18).height(18).fillColor('#D9DAE0')
        }.width(40).height(40).backgroundColor('#202127').borderRadius(10).margin({ left: 8 })
          .onClick(() => this.openDetailSheet('页边距', '页面内边距与正文留白设置'))
      }.width('100%').padding({ left: 14, right: 14, bottom: 8 })
      Scroll() {
        Column() {
          Text('内容').fontSize(12).fontColor(this.themeColorAccent).width('100%').padding({ left: 4, top: 6, bottom: 4 })
          ReaderInfoSettingRow({
            iconKind: 0,
            title: this.infoSubTab === 0 ? '页眉' : '页脚',
            choices: [this.getInfoModeLabel()],
            onSelect: (_index: number) => this.openDetailSheet('显示模式', '选择不显示、章节信息、阅读进度或自定义内容')
          })
          ForEach(['左侧', '中间', '右侧'], (position: string) => {
            ReaderInfoSettingRow({
              iconKind: position === '左侧' ? 1 : position === '中间' ? 2 : 3,
              title: position,
              choices: this.getInfoTipChoices(),
              selectedIndex: Math.max(0, READ_INFO_TIP_VALUES.indexOf(this.getInfoTipValue(
                this.infoSubTab === 0
                  ? (position === '左侧' ? 'headerLeft' : position === '中间' ? 'headerMiddle' : 'headerRight')
                  : (position === '左侧' ? 'footerLeft' : position === '中间' ? 'footerMiddle' : 'footerRight')
              ))),
              onSelect: (_index: number) => this.openInfoTipSheet(position)
            })
          }, (position: string) => position)
          Text('分隔线').fontSize(12).fontColor(this.themeColorAccent).width('100%').padding({ left: 4, top: 10, bottom: 4 })
          ReaderInfoSwitchRow({
            title: '显示分割线', detail: '显示页眉/页脚分隔线',
            checked: this.infoSubTab === 0 ? this.infoSettings.showHeaderLine : this.infoSettings.showFooterLine,
            onChange: (enabled: boolean) => this.onInfoSettingsChange(updateReaderInfoSettings(this.infoSettings, {
              showHeaderLine: this.infoSubTab === 0 ? enabled : this.infoSettings.showHeaderLine,
              showFooterLine: this.infoSubTab === 1 ? enabled : this.infoSettings.showFooterLine
            }))
          })
          ReaderInfoColorRow({ iconKind: 4, title: '分割线', detail: '页眉与页脚共用' })
            .onClick(() => this.openDetailSheet('分割线颜色', '选择页眉/页脚分割线颜色'))
          Text('文字字体').fontSize(12).fontColor(this.themeColorAccent)
            .width('100%').padding({ left: 4, top: 10, bottom: 4 })
          if (this.infoSubTab === 1) {
            MenuSettingSwitch({
              title: '应用页眉样式', detail: '页脚文字继承页眉样式', checked: this.infoSettings.applyHeaderStyle,
              onChange: (enabled: boolean) => this.onInfoSettingsChange(
                updateReaderInfoSettings(this.infoSettings, { applyHeaderStyle: enabled }))
            })
          }
          if (this.infoSubTab === 0 || !this.infoSettings.applyHeaderStyle) {
            ReaderInfoOptionRow({ iconKind: 5, title: '选择字体', detail: '选择字体' })
              .onClick(() => this.showNotMigrated('页眉/页脚字体选择'))
            ReaderInfoSliderRow({
              iconKind: 6, title: '字号',
              value: this.infoSubTab === 0 ? this.infoSettings.headerFontSize : this.infoSettings.footerFontSize,
              minValue: 0, maxValue: 100,
              onChange: (value: number) => this.onInfoSettingsChange(updateReaderInfoSettings(this.infoSettings, {
                headerFontSize: this.infoSubTab === 0 ? value : this.infoSettings.headerFontSize,
                footerFontSize: this.infoSubTab === 1 ? value : this.infoSettings.footerFontSize
              }))
            })
            ReaderInfoColorRow({ iconKind: 7, title: '日间文字颜色', detail: '阅读器日间样式' })
              .onClick(() => this.openDetailSheet(
                this.infoSubTab === 0 ? '页眉日间文字颜色' : '页脚日间文字颜色', '选择信息文字颜色'))
            ReaderInfoColorRow({ iconKind: 7, title: '夜间文字颜色', detail: '阅读器夜间样式' })
              .onClick(() => this.openDetailSheet(
                this.infoSubTab === 0 ? '页眉夜间文字颜色' : '页脚夜间文字颜色', '选择信息文字颜色'))
          }
          Text('页眉/页脚模式、提示内容、分隔线和字号会保存到阅读样式。字体文件选择与颜色取色器尚未迁移。')
            .fontSize(10).fontColor(this.themeColorTextTertiary).width('100%').textAlign(TextAlign.Center).padding(12)
        }.width('100%').padding({ left: 14, right: 14, bottom: 12 })
      }.layoutWeight(1).scrollBar(BarState.Off)
    }.width('100%').layoutWeight(1)
  }

  @Builder
  private moreSettingsContent() {
    Column() {
      Scroll() {
        Column() {
          Text('屏幕设置').fontSize(12).fontColor(this.themeColorAccent).width('100%').padding({ left: 4, top: 6, bottom: 4 })
          MenuSettingOption({ title: '屏幕方向', detail: '跟随系统 / 竖屏 / 横屏', migrated: true }).onClick(() => this.openDetailSheet('屏幕方向', '选择系统、竖屏或横屏'))
          MenuSettingOption({ title: '保持屏幕常亮', detail: this.getDetailChoices('保持屏幕常亮')[Math.max(0, ['0', '60', '300', '600', '-1'].indexOf(this.keepLight))] ?? '默认', migrated: true }).onClick(() => this.openDetailSheet('保持屏幕常亮', '设置阅读期间的屏幕超时'))
          MenuSettingSwitch({ title: '隐藏状态栏', detail: '沉浸式阅读', checked: this.hideStatusBar,
            onChange: (enabled: boolean) => this.onHideStatusBarChange(enabled) })
          MenuSettingSwitch({ title: '隐藏导航栏', detail: '沉浸式阅读', checked: this.hideNavigationBar,
            onChange: (enabled: boolean) => this.onHideNavigationBarChange(enabled) })
          MenuSettingSwitch({ title: '填充刘海区域', detail: '把显示缺口算进正文可用区', checked: this.paddingDisplayCutouts,
            onChange: (enabled: boolean) => this.onPaddingDisplayCutoutsChange(enabled) })
          MenuSettingSwitch({ title: '扩展到刘海', detail: '上游同名字段只做配置，没有对应渲染效果', checked: this.readBodyToLh,
            onChange: (enabled: boolean) => this.onReadBodyToLhChange(enabled) })
          MenuSettingSwitch({ title: '适配特殊样式', detail: '按标记解释正文里的分段与富文本', checked: this.adaptSpecialStyle,
            onChange: (enabled: boolean) => this.onAdaptSpecialStyleChange(enabled) })
          MenuSettingSwitch({ title: '使用自定义中文分行', detail: '改后重新计算分页', checked: this.useZhLayout,
            onChange: (enabled: boolean) => this.onUseZhLayoutChange(enabled) })
          MenuSettingOption({ title: '护眼设置', detail: '护眼模式与色温', migrated: true })
            .onClick(() => this.openDetailSheet('护眼设置', '配置护眼模式、色温与日夜参数'))
          Text('翻页控制').fontSize(12).fontColor(this.themeColorAccent).width('100%').padding({ left: 4, top: 10, bottom: 4 })
          MenuSettingSlider({
            title: '滑动翻页阈值',
            value: this.pageTouchSlop,
            minValue: 0,
            maxValue: 1000,
            stepValue: 10,
            onChange: (value: number) => this.onPageTouchSlopChange(value)
          })
          Text('滑动翻页阈值（0 = 系统默认值）').fontSize(10).fontColor('#898B95')
            .width('100%').padding({ left: 18, right: 18, bottom: 8 })
          MenuSettingOption({
            title: '横屏双页', detail: readerColumnModeTitle(this.doubleHorizontalPage), migrated: true
          }).onClick(() => this.openDetailSheet('横屏双页', '选择单页、双页以及双页生效的屏幕形态'))
          MenuSettingOption({
            title: '进度条行为', detail: this.progressBehavior === 'chapter' ? '章节进度' : '页码进度', migrated: true
          }).onClick(() => this.openDetailSheet('进度条行为', '设置拖动进度条的定位方式'))
          MenuSettingSwitch({ title: '鼠标滚轮翻页', detail: '分页模式下用滚轮翻页', checked: this.mouseWheelPage,
            onChange: (enabled: boolean) => this.onMouseWheelPageChange(enabled) })
          MenuSettingSwitch({ title: '音量键翻页', detail: '按音量键切换页面', checked: this.volumeKeyPage,
            onChange: (enabled: boolean) => this.onVolumeKeyPageChange(enabled) })
          MenuSettingSwitch({ title: '朗读时允许音量键翻页', detail: '朗读期间使用音量键翻页', checked: false }).onClick(() => this.showNotMigrated('朗读时音量键翻页'))
          MenuSettingSwitch({ title: '长按按键翻页', detail: '长按音量键连续翻页', checked: this.keyPageOnLongPress,
            onChange: (enabled: boolean) => this.onKeyPageOnLongPressChange(enabled) })
          MenuSettingSwitch({ title: '下滑添加书签', detail: '下滑翻动当前页以添加或取消书签', checked: this.swipeToAddBookmark,
            onChange: (enabled: boolean) => this.onSwipeToAddBookmarkChange(enabled) })
          MenuSettingOption({ title: '书签标记', detail: this.bookmarkBadgeImage.length > 0 ? '自定义图片' : '默认', migrated: true })
            .onClick(() => this.openDetailSheet('书签标记', '选择书签标记图片或恢复默认'))
          MenuSettingSlider({
            title: '书签标记大小', value: this.bookmarkBadgeSize, minValue: 0, maxValue: 50,
            onChange: (value: number) => this.onBookmarkBadgeSizeChange(value)
          })
          Text('其他').fontSize(12).fontColor(this.themeColorAccent).width('100%').padding({ left: 4, top: 10, bottom: 4 })
          MenuSettingSwitch({ title: '进度条触感反馈', detail: '拖动时提供触觉反馈', checked: this.sliderVibrator,
            onChange: (enabled: boolean) => this.onSliderVibratorChange(enabled) })
          MenuSettingSwitch({ title: '使用新版目录', detail: '使用新的目录面板', checked: true }).onClick(() => this.showNotMigrated('使用新版目录'))
          MenuSettingSlider({ title: '无目录书籍分段长度', value: this.maxLengthWithNoToc, minValue: 3000, maxValue: 100000, stepValue: 100,
            onChange: (value: number) => this.onMaxLengthWithNoTocChange(value) })
          MenuSettingSwitch({ title: '文字选择触感反馈', detail: '选择正文时提供触觉反馈', checked: this.selectVibrator,
            onChange: (enabled: boolean) => this.onSelectVibratorChange(enabled) })
          MenuSettingSwitch({ title: '自动切换书源', detail: '当前书源失效时尝试其它书源', checked: false }).onClick(() => this.showNotMigrated('自动切换书源'))
          MenuSettingSwitch({ title: '换源结果应用于全部书籍', detail: '同步更新其它书籍的书源', checked: false }).onClick(() => this.showNotMigrated('换源结果应用于全部书籍'))
          MenuSettingSwitch({ title: '自动切换日夜模式提醒', detail: '根据环境光提醒切换浅色/深色模式', checked: this.autoSuggestDayNight, onChange: (enabled: boolean) => this.onAutoSuggestDayNightChange(enabled) })
          MenuSettingSwitch({ title: '阅读位置锚点', detail: '跳转章节两次及以上后可返回原阅读位置', checked: this.readingAnchorEnabled,
            onChange: (enabled: boolean) => this.onReadingAnchorEnabledChange(enabled) })
          MenuSettingSwitch({ title: '朗读悬浮窗分离提醒', detail: '分离朗读控制时显示提醒', checked: true }).onClick(() => this.showNotMigrated('朗读悬浮窗分离提醒'))
          MenuSettingSwitch({ title: '允许选择正文', detail: '长按正文显示选择菜单', checked: this.selectText,
            onChange: (enabled: boolean) => this.onSelectTextChange(enabled) })
          MenuSettingSwitch({ title: '滚动翻页无动画', detail: '关闭滚动翻页过渡动画',
            checked: this.noAnimScrollPage,
            onChange: (enabled: boolean) => this.onNoAnimScrollPageChange(enabled) })
          MenuSettingSwitch({ title: '优化正文渲染', detail: '使用优化渲染方式', checked: true }).onClick(() => this.showNotMigrated('优化正文渲染'))
          MenuSettingOption({ title: '点击图片行为', detail: this.getClickImageBehaviorLabel(), migrated: true })
            .onClick(() => this.openDetailSheet('点击图片行为', '选择正文图片的点击行为'))
          MenuSettingOption({ title: '点击区域配置', detail: '设置屏幕各区域的触摸动作', migrated: true }).onClick(() => this.openDetailSheet('点击区域配置', '配置九宫格点按动作，并应用到阅读界面。'))
          MenuSettingSwitch({ title: '禁用返回键', detail: '阻止阅读时返回键退出', checked: this.disableReturnKey, onChange: (enabled: boolean) => this.onDisableReturnKeyChange(enabled) })
          MenuSettingOption({ title: '自定义翻页按键', detail: this.getPageKeysLabel(), migrated: true }).onClick(() => this.openDetailSheet('自定义翻页按键', '录制物理按键作为上一页/下一页'))
          MenuSettingOption({ title: '选中文字菜单', detail: '配置文本选择后的操作', migrated: true }).onClick(() => this.openDetailSheet('选中文字菜单', '排序、分组与图标开关，保存后随备份同步'))
          // 「展示顶部工具栏附加区域」上游 showReadTitleAddition（ReadSettings.kt:55，默认 true）：
          // 上游只有字段与设置界面（MoreConfigSheet.kt:458 / ReadConfigScreen.kt:418）、没有渲染消费点，本地只落库。
          MenuSettingSwitch({
            title: '展示顶部工具栏附加区域', detail: '上游只落库，无渲染效果',
            checked: this.showReadTitleAddition,
            onChange: (enabled: boolean) => this.onShowReadTitleAdditionChange(enabled)
          })
          // 「展示菜单项图标」上游 showMenuIcon（ReadSettings.kt:119，默认 false）：
          // 消费点 ReadBookMenuBarFloating.kt:174-186 的 OverflowDropdownMenu，本地对应「更多」网格面板的图标。
          MenuSettingSwitch({
            title: '展示菜单项图标', detail: '在「更多」面板中显示每项图标',
            checked: this.showMenuIcon,
            onChange: (enabled: boolean) => this.onShowMenuIconChange(enabled)
          })
          Text('未迁移项目保留原版设置入口；当前仅呈现设置界面，不执行对应业务。')
            .fontSize(10).fontColor(this.themeColorTextTertiary).width('100%').textAlign(TextAlign.Center).padding(12)
        }.width('100%').padding({ left: 14, right: 14, bottom: 12 })
      }.layoutWeight(1).scrollBar(BarState.Off)
    }.width('100%').layoutWeight(1)
  }

  /**
   * 用已保存的配置串重建条目表。
   * 上游 `ReadBookController.kt:2204` 读回时也是「按配置顺序排列 + 配置里没提到的追加到末尾」，
   * 空串或坏 JSON 回落内置顺序（`parseReaderSelectionMenuConfig` 内已处理）。
   */
  private syncTextMenuEntriesFromConfig(): void {
    const parsed = parseReaderSelectionMenuConfig(this.textSelectMenuConfig, defaultReaderSelectionMenuItems());
    this.textMenuEntries = parsed.map(
      (item: ReaderSelectionMenuItem): ReaderTextMenuEntry => ({ id: item.id, title: item.title, group: item.group })
    );
  }

  /** 把当前条目表序列化落库，对齐上游 `saveMenuConfig` → `viewModel.setTextSelectMenuConfig(GSON.toJson(...))`。 */
  private saveTextMenuConfig(): void {
    const items: ReaderSelectionMenuItem[] = this.textMenuEntries.map(
      (item: ReaderTextMenuEntry): ReaderSelectionMenuItem => ({ id: item.id, title: item.title, group: item.group })
    );
    this.onTextSelectMenuConfigChange(serializeReaderSelectionMenuConfig(items));
  }

  private getTextMenuEntries(group: number): ReaderTextMenuEntry[] {
    return this.textMenuEntries.filter((item: ReaderTextMenuEntry) => item.group === group);
  }

  private moveTextMenuEntry(id: string, targetGroup: number): void {
    this.textMenuEntries = this.textMenuEntries.map((item: ReaderTextMenuEntry) =>
      item.id === id ? { id: item.id, title: item.title, group: targetGroup } : item
    );
  }

  private reorderTextMenuEntry(id: string, direction: number, group: number): void {
    const groupItems = this.getTextMenuEntries(group);
    const currentGroupIndex = groupItems.findIndex((item: ReaderTextMenuEntry) => item.id === id);
    const targetGroupIndex = currentGroupIndex + direction;
    if (currentGroupIndex < 0 || targetGroupIndex < 0 || targetGroupIndex >= groupItems.length) { return; }
    const currentIndex = this.textMenuEntries.findIndex((item: ReaderTextMenuEntry) => item.id === id);
    const targetItem = groupItems[targetGroupIndex];
    if (currentIndex < 0 || targetItem === undefined) { return; }
    const targetIndex = this.textMenuEntries.findIndex((item: ReaderTextMenuEntry) => item.id === targetItem.id);
    if (targetIndex < 0) { return; }
    const nextEntries = this.textMenuEntries.slice();
    const currentItem = nextEntries[currentIndex];
    const displacedItem = nextEntries[targetIndex];
    if (currentItem === undefined || displacedItem === undefined) { return; }
    nextEntries[currentIndex] = displacedItem;
    nextEntries[targetIndex] = currentItem;
    this.textMenuEntries = nextEntries;
  }

  private isTextMenuGroupExpanded(group: number): boolean {
    if (group === 0) { return this.primaryTextMenuExpanded; }
    if (group === 1) { return this.collapsedTextMenuExpanded; }
    return this.hiddenTextMenuExpanded;
  }

  private toggleTextMenuGroup(group: number): void {
    if (group === 0) { this.primaryTextMenuExpanded = !this.primaryTextMenuExpanded; }
    else if (group === 1) { this.collapsedTextMenuExpanded = !this.collapsedTextMenuExpanded; }
    else { this.hiddenTextMenuExpanded = !this.hiddenTextMenuExpanded; }
  }

  @Builder
  private readerTextMenuIcon(id: string) {
    if (id === 'menu_copy') {
      Image($r('app.media.reader_menu_copy')).width(18).height(18).fillColor('#D9DAE0')
    } else if (id === 'menu_share_str') {
      Image($r('app.media.reader_menu_share')).width(18).height(18).fillColor('#D9DAE0')
    } else if (id === 'menu_browser') {
      Image($r('app.media.reader_menu_language')).width(18).height(18).fillColor('#D9DAE0')
    } else if (id === 'menu_aloud') {
      Image($r('app.media.reader_menu_volume_up')).width(18).height(18).fillColor('#D9DAE0')
    } else if (id === 'menu_bookmark') {
      Image($r('app.media.reader_menu_bookmark')).width(18).height(18).fillColor('#D9DAE0')
    } else if (id === 'menu_mark') {
      Image($r('app.media.reader_menu_border_color')).width(18).height(18).fillColor('#D9DAE0')
    } else if (id === 'menu_dict') {
      Image($r('app.media.reader_menu_book')).width(18).height(18).fillColor('#D9DAE0')
    } else if (id === 'menu_replace') {
      Image($r('app.media.reader_menu_find_replace')).width(18).height(18).fillColor('#D9DAE0')
    } else if (id === 'menu_edit') {
      Image($r('app.media.reader_menu_edit')).width(18).height(18).fillColor('#D9DAE0')
    } else if (id === 'menu_ai_clean' || id === 'menu_ai_rewrite') {
      Image($r('app.media.reader_menu_smart_toy')).width(18).height(18).fillColor('#D9DAE0')
    } else if (id === 'menu_search_content') {
      Image($r('app.media.reader_menu_search')).width(18).height(18).fillColor('#D9DAE0')
    } else if (id === 'menu_insert_bgm_before') {
      Image($r('app.media.reader_menu_queue_music')).width(18).height(18).fillColor('#D9DAE0')
    } else if (id === 'menu_insert_bgm_after') {
      Image($r('app.media.reader_menu_playlist_add')).width(18).height(18).fillColor('#D9DAE0')
    } else {
      Blank().width(18).height(18)
    }
  }

  private async loadReaderFontEntries(): Promise<void> {
    const context = this.getUIContext().getHostContext();
    if (context === undefined) { return; }
    this.fontEntries = ReaderFontRepository.listFonts(context);
  }

  private openFontSelection(): void {
    const target = this.detailSelectedOption;
    if (target === '标题') { this.fontTarget = 'title'; }
    else if (target === '页眉') { this.fontTarget = 'header'; }
    else if (target === '页脚') { this.fontTarget = 'footer'; }
    else { this.fontTarget = 'body'; }
    const targetLabel = this.getFontTargetLabel();
    this.openDetailSheet('选择字体', `为${targetLabel}选择字体`);
  }

  private getFontTargetLabel(): string {
    if (this.fontTarget === 'title') { return '标题'; }
    if (this.fontTarget === 'header') { return '页眉'; }
    if (this.fontTarget === 'footer') { return '页脚'; }
    return '正文';
  }

  private getFontTargetPath(): string {
    if (this.fontTarget === 'title') { return this.titleFont; }
    if (this.fontTarget === 'header') { return this.infoSettings.headerFont; }
    if (this.fontTarget === 'footer') { return this.infoSettings.footerFont; }
    return this.textFont;
  }

  /** 中文简繁体转换档位的显示文案，与详情面板的三个选项一一对应。 */
  /** 标题字号标签：相对模式显示成「正文 + n」，绝对模式直接显示 sp。 */
  private getTitleSizeLabel(): string {
    return this.titleSizeRelative ? `正文 + ${this.titleSize}` : `${this.titleSize} 号`;
  }

  /** 标题颜色标签；空串表示未设置、跟随正文色（对齐上游 titleColor 取 0 时回落正文色）。 */
  private getTitleColorLabel(night: boolean): string {
    const configured = night ? this.titleColorNight : this.titleColor;
    return configured.length > 0 ? configured : '跟随正文';
  }

  /** 标题分段模式标签，对齐上游 titleSegType（ReadBookConfig.kt:280）。 */
  private getTitleSegTypeLabel(): string {
    return ['不分段', '按字数分段', '按分隔符分段', '按正则分段'][Math.max(0, Math.min(3, this.titleSegType))] ?? '不分段';
  }

  private getChineseConverterLabel(): string {
    return ['关闭简繁转换', '繁体转简体', '简体转繁体'][Math.max(0, Math.min(2, this.chineseConverterType))]
      ?? '关闭简繁转换';
  }

  /** 自定义翻页按键的副标题：未配置时显示「未配置」，否则显示两串原文。 */
  private getPageKeysLabel(): string {
    const prev = this.prevKeys.trim();
    const next = this.nextKeys.trim();
    if (prev.length === 0 && next.length === 0) { return '未配置'; }
    return `上 ${prev.length === 0 ? '—' : prev} / 下 ${next.length === 0 ? '—' : next}`;
  }

  private getCurrentFontDisplayName(): string {
    const selectedPath = this.getFontTargetPath();
    if (selectedPath.length === 0) {
      return ['默认字体', '衬线字体', '等宽字体'][Math.max(0, Math.min(2, this.systemTypefaces))] ?? '默认字体';
    }
    const selected = this.fontEntries.find((entry: ReaderFontEntry) => entry.path === selectedPath);
    return selected?.displayName ?? '字体文件不可用（点按“默认字体”清除）';
  }

  private setFontPathForCurrentTarget(path: string): void {
    if (this.fontTarget === 'title') {
      this.onTitleFontChange(path);
    } else if (this.fontTarget === 'header') {
      this.onInfoSettingsChange(updateReaderInfoSettings(this.infoSettings, { headerFont: path }));
    } else if (this.fontTarget === 'footer') {
      this.onInfoSettingsChange(updateReaderInfoSettings(this.infoSettings, { footerFont: path }));
    } else {
      this.onTextFontChange(path);
    }
  }

  private returnToTypographyFromFontPicker(): void {
    this.detailSheetTitle = '排版设置';
    this.detailSheetDescription = '正文、标题、页眉页脚与边距设置';
    this.detailSelectedOption = this.getFontTargetLabel();
  }

  private async importReaderFontFile(): Promise<void> {
    const context = this.getUIContext().getHostContext();
    if (context === undefined) { this.onUnavailableAction('无法访问本地字体文件'); return; }
    try {
      const imported = await ReaderFontRepository.importFont(context);
      if (imported === undefined) { return; }
      this.fontEntries = ReaderFontRepository.listFonts(context);
      ReaderFontRepository.resolveFamily(context, imported.path, this.systemTypefaces);
      this.onUnavailableAction(`已导入字体：${imported.displayName}`);
    } catch (error) {
      this.onUnavailableAction(error instanceof Error ? error.message : '导入字体失败');
    }
  }

  private async importReaderFontFolder(): Promise<void> {
    const context = this.getUIContext().getHostContext();
    if (context === undefined) { this.onUnavailableAction('无法访问本地字体文件'); return; }
    try {
      const importedCount = await ReaderFontRepository.importFontFolder(context);
      this.fontEntries = ReaderFontRepository.listFonts(context);
      this.onUnavailableAction(importedCount > 0
        ? `已导入 ${importedCount} 个字体文件`
        : '所选目录没有 TTF 或 OTF 字体文件');
    } catch (_) {
      this.onUnavailableAction('此设备不能选择字体目录，请改用“导入字体文件”');
    }
  }

  private chooseSystemTypeface(index: number): void {
    this.onSystemTypefacesChange(index);
    this.setFontPathForCurrentTarget('');
    this.returnToTypographyFromFontPicker();
  }

  private chooseReaderFont(font: ReaderFontEntry): void {
    const context = this.getUIContext().getHostContext();
    if (context === undefined || ReaderFontRepository.resolveFamily(context, font.path, this.systemTypefaces) ===
      ReaderFontRepository.systemTypefaceFamily(this.systemTypefaces)) {
      this.onUnavailableAction('字体文件无法加载，请重新导入');
      return;
    }
    this.setFontPathForCurrentTarget(font.path);
    this.returnToTypographyFromFontPicker();
  }

  private openDetailSheet(title: string, description: string): void {
    this.detailSheetTitle = title;
    this.detailSheetDescription = description;
    this.detailInfoSlot = undefined;
    const choices = this.getDetailChoices(title);
    // 自定义翻页按键面板是即时编辑式，打开时把已保存的键值串灌进输入框作为草稿。
    if (title === '自定义翻页按键') {
      this.previousPageKeys = this.prevKeys;
      this.nextPageKeys = this.nextKeys;
    }
    // 选中文字菜单是草稿式编辑：每次打开都用已落库的配置重建条目表。
    if (title === '选中文字菜单') {
      this.syncTextMenuEntriesFromConfig();
    }
    // 「编辑背景样式」用长按那一份当草稿，关闭不保存就丢弃。
    if (title === '编辑背景样式') {
      const index = Math.max(0, Math.min(this.backgroundStyles.length - 1, this.editingStyleIndex));
      const current = this.backgroundStyles[index];
      this.editingStyleIndex = index;
      this.editingStyleName = current === undefined ? '' : current.name;
      this.editingStyleDayColor = current === undefined ? '' : current.dayColor;
      this.editingStyleNightColor = current === undefined ? '' : current.nightColor;
    }
    if (title === '排版设置') {
      this.detailSelectedOption = '正文';
    } else if (title === '页边距') {
      this.detailSelectedOption = '正文';
    } else if (title === '显示模式') {
      this.detailSelectedOption = this.infoSubTab === 0
        ? (choices[this.infoSettings.headerMode] ?? choices[0] ?? '')
        : (this.infoSettings.footerMode === 1 ? choices[1] ?? '' : choices[0] ?? '');
    } else if (title === '翻页动画') {
      this.detailSelectedOption = choices[this.pageAnimationIndex] ?? choices[0] ?? '';
    } else if (title === '翻页动画速度') {
      this.detailSelectedOption = choices[this.animationSpeedIndex] ?? choices[2] ?? '';
    } else if (title === '中文简繁体转换') {
      this.detailSelectedOption = choices[this.chineseConverterType] ?? choices[0] ?? '';
    } else if (title === '横屏双页') {
      const modeIndex = ['0', '1', '2', '3'].indexOf(this.doubleHorizontalPage);
      this.detailSelectedOption = choices[Math.max(0, modeIndex)] ?? choices[0] ?? '';
    } else if (title === '进度条行为') {
      this.detailSelectedOption = this.progressBehavior === 'chapter'
        ? (choices[1] ?? choices[0] ?? '') : (choices[0] ?? '');
    } else if (title === '滑动条显示样式') {
      this.detailSelectedOption = this.readSliderMode === '1'
        ? (choices[1] ?? choices[0] ?? '') : (choices[0] ?? '');
    } else if (title === '屏幕方向') {
      const orientationIndex = Math.max(0, Math.min(5, Number.parseInt(this.screenOrientation, 10)));
      this.detailSelectedOption = choices[orientationIndex] ?? choices[0] ?? '';
    } else if (title === '保持屏幕常亮') {
      this.detailSelectedOption = choices[Math.max(0, ['0', '60', '300', '600', '-1'].indexOf(this.keepLight))] ?? choices[0] ?? '';
    } else if (title === '点击图片行为') {
      const behaviorIndex = Math.max(0, ['0', '1', '2', '3', '4'].indexOf(this.clickImageBehavior));
      this.detailSelectedOption = choices[behaviorIndex] ?? choices[0] ?? '';
    } else if (title === '分割线颜色' || title.endsWith('文字颜色')) {
      const values: number[] = title === '分割线颜色'
        ? [-1, 0, -16777216, -8355712, -1, -65536, -16711936, -16776961]
        : READER_INFO_COLOR_VALUES;
      const configuredValue = this.getReaderInfoColorValue(title);
      const selectedIndex = values.indexOf(configuredValue);
      this.detailSelectedOption = choices[selectedIndex >= 0 ? selectedIndex : 0] ?? choices[0] ?? '';
    } else {
      this.detailSelectedOption = choices[0] ?? '';
    }
    this.detailSheetVisible = true;
  }

  private showEyeProtectionTimePicker(isStart: boolean): void {
    const current = isStart ? this.eyeProtectionStartTime : this.eyeProtectionEndTime;
    const parts: string[] = current.split(':');
    const hour: number = Number(parts[0]);
    const minute: number = Number(parts[1]);
    const selected: Date = new Date();
    selected.setHours(hour, minute, 0, 0);
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

  private getPageAnimationLabel(): string {
    const choices = this.getDetailChoices('翻页动画');
    return choices[this.pageAnimationIndex] ?? choices[0] ?? '覆盖';
  }

  private getAnimationSpeedLabel(): string {
    const choices = this.getDetailChoices('翻页动画速度');
    return choices[this.animationSpeedIndex] ?? choices[2] ?? '适中';
  }

  /** 亮度条形态的回显文案，取值对齐上游 brightness_bar_off/horizontal/vertical。 */
  private getBrightnessViewDetail(): string {
    const choices = ['关闭', '横排', '竖排'];
    const index = ['0', '1', '2'].indexOf(this.showBrightnessView);
    return choices[Math.max(0, index)] ?? choices[0] ?? '';
  }

  /** 亮度条位置的回显文案，对齐上游 brightness_bar_left/right。 */
  private getBrightnessPositionDetail(): string {
    return this.brightnessVwPos === '0' ? '左侧' : '右侧';
  }

  /**
   * 样式卡上的名字。新建样式的名字是空的（上游 `asNewStyle()` 把 name 清空留给用户起），
   * 卡片上回落成「背景样式」，与上游 `StyleCard` 的 `config.name.ifBlank { "背景样式" }` 一致。
   */
  private getBackgroundStyleLabel(style: ReaderBackgroundStyle): string {
    return style.name.length > 0 ? style.name : '背景样式';
  }

  private getDetailChoices(title: string): string[] {
    if (title === '工具栏样式') { return ['跟随系统', '跟随阅读背景', '自定义']; }
    if (title === '调色板风格') { return ['跟随系统', '柔和', '中性', '鲜艳', '表现力', '彩虹', '水果拼盘', '单色', '仿真', '内容取色']; }
    if (title === '菜单颜色来源') { return ['种子色', '自定义颜色']; }
    if (title === '显示亮度视图') { return ['关闭', '横排', '竖排']; }
    if (title === '亮度条位置') { return ['左侧', '右侧']; }
    // 上游 title_bar_mode 四值（values-zh-rCN/arrays.xml:242-247、array_values.xml:146-151）：
    // "0" 书名在应用栏 + 章节名下一行；"1" 书名独立一行 + 章节名再一行；
    // "2" 只有书名（应用栏），无章节行；"3" 都不显示。
    if (title === '标题栏模式') {
      return ['在应用栏上显示', '在独立行上显示', '仅显示标题', '不显示'];
    }
    // 上游 title_bar_icon_position 四值（values-zh-rCN/strings.xml:2486-2489）。
    if (title === '标题栏悬浮图标位置') { return ['左上', '右上', '左下', '右下']; }
    if (title.includes('图标样式')) { return ['纯色', '色调', '描边']; }
    if (title.includes('模糊样式')) { return ['纯色', '渐变']; }
    if (title === '中文简繁体转换') { return ['关闭简繁转换', '繁体转简体', '简体转繁体']; }
    if (title === '翻页动画') { return ['覆盖', '滑动', '仿真', '滚动', '淡入淡出', '无动画']; }
    if (title === '翻页动画速度') { return ['极速', '快速', '适中', '优雅']; }
    if (title === '显示模式') {
      return this.infoSubTab === 0 ? ['状态栏显示时隐藏', '显示', '隐藏'] : ['显示', '隐藏'];
    }
    if (title === '页眉日间文字颜色' || title === '页眉夜间文字颜色' ||
      title === '页脚日间文字颜色' || title === '页脚夜间文字颜色') {
      return READER_INFO_COLOR_CHOICES;
    }
    if (title === '分割线颜色') {
      return ['默认分隔线', '跟随正文', '黑色', '灰色', '白色', '红色', '绿色', '蓝色'];
    }
    if (title === '左侧显示内容' || title === '中间显示内容' || title === '右侧显示内容') {
      return this.getInfoTipChoices();
    }
    if (title === '屏幕方向') { return ['跟随系统', '竖屏', '横屏', '传感器自动', '反向竖屏', '反向横屏']; }
    if (title === '保持屏幕常亮') { return ['默认', '1分钟', '5分钟', '10分钟', '常亮']; }
    if (title === '横屏双页') { return READER_COLUMN_MODE_TITLES; }
    if (title === '进度条行为') { return ['页码进度', '章节进度']; }
    if (title === '滑动条显示样式') { return ['常驻', '不显示']; }
    if (title === '点击图片行为') { return ['新版行为', '预览图片', '经典', '禁用点击', '双击']; }
    if (title === '信息字体' || title === '选择字体') { return ['默认字体', '系统字体', '选择本地字体']; }
    if (title === '分割线颜色' || title === '文字颜色' || title === '信息颜色') {
      return ['跟随正文', '默认颜色', '自定义颜色'];
    }
    if (title === '自定义提示') { return ['书名', '章节名', '页码', '时间', '自定义文本']; }
    return [];
  }

  private getClickImageBehaviorLabel(): string {
    const choices = this.getDetailChoices('点击图片行为');
    const behaviorIndex = Math.max(0, ['0', '1', '2', '3', '4'].indexOf(this.clickImageBehavior));
    return choices[behaviorIndex] ?? choices[2] ?? '经典';
  }

  private getReaderInfoColorValue(title: string): number {
    if (title === '页眉日间文字颜色') { return this.infoSettings.tipHeaderColor; }
    if (title === '页眉夜间文字颜色') { return this.infoSettings.tipHeaderColorNight; }
    if (title === '页脚日间文字颜色') { return this.infoSettings.tipFooterColor; }
    if (title === '页脚夜间文字颜色') { return this.infoSettings.tipFooterColorNight; }
    return this.infoSettings.tipDividerColor;
  }

  private getPaddingValue(side: string): number {
    if (this.detailSelectedOption === '页眉') {
      if (side === '上') { return this.paddingSettings.headerPaddingTop; }
      if (side === '下') { return this.paddingSettings.headerPaddingBottom; }
      if (side === '左') { return this.paddingSettings.headerPaddingLeft; }
      return this.paddingSettings.headerPaddingRight;
    }
    if (this.detailSelectedOption === '页脚') {
      if (side === '上') { return this.paddingSettings.footerPaddingTop; }
      if (side === '下') { return this.paddingSettings.footerPaddingBottom; }
      if (side === '左') { return this.paddingSettings.footerPaddingLeft; }
      return this.paddingSettings.footerPaddingRight;
    }
    if (side === '上') { return this.paddingSettings.paddingTop; }
    if (side === '下') { return this.paddingSettings.paddingBottom; }
    if (side === '左') { return this.paddingSettings.paddingLeft; }
    return this.paddingSettings.paddingRight;
  }

  private updatePadding(side: string, value: number): void {
    const next: ReaderPaddingSettings = copyReaderPaddingSettings(this.paddingSettings);
    if (this.detailSelectedOption === '页眉') {
      if (side === '上') { next.headerPaddingTop = value; }
      else if (side === '下') { next.headerPaddingBottom = value; }
      else if (side === '左') { next.headerPaddingLeft = value; }
      else { next.headerPaddingRight = value; }
    } else if (this.detailSelectedOption === '页脚') {
      if (side === '上') { next.footerPaddingTop = value; }
      else if (side === '下') { next.footerPaddingBottom = value; }
      else if (side === '左') { next.footerPaddingLeft = value; }
      else { next.footerPaddingRight = value; }
    } else {
      if (side === '上') { next.paddingTop = value; }
      else if (side === '下') { next.paddingBottom = value; }
      else if (side === '左') { next.paddingLeft = value; }
      else { next.paddingRight = value; }
    }
    this.onPaddingSettingsChange(next);
  }

  private getInfoTipChoices(): string[] {
    return ['无', '书名', '标题', '带箭头的标题（系统字体）', '带箭头的标题', '时间', '电量', '经典电量',
      '电量内显', '仅电量图标', '电量%', '页数', '进度(%)', '进度(xx/yyy)', '页数及进度', '时间及电量',
      '经典电量及时间', '时间及电量%', '全文页数', '全文页数及进度', '自定义'];
  }

  private showNotMigrated(title: string): void {
    this.openDetailSheet(title, '此选项的原版 UI 已呈现；实际设置逻辑尚未迁移。');
  }

  private settingsSheetHeight(): string {
    if (this.selectedSettingsTab === 0) { return '62%'; }
    if (this.selectedSettingsTab === 1) { return '68%'; }
    if (this.selectedSettingsTab === 2) { return '70%'; }
    return '86%';
  }

  private settingsSheetWidth(): string {
    return this.selectedSettingsTab === 3 ? '100%' : '88%';
  }

  @Builder
  private detailSheet() {
    Stack({ alignContent: Alignment.Center }) {
      Column().width('100%').height('100%').backgroundColor('#99000000').onClick(() => this.detailSheetVisible = false)
      Column() {
        Row().width(32).height(4).backgroundColor('#C5C6CD').borderRadius(4).margin({ top: 10, bottom: 14 })
        Row() {
          Text(this.detailSheetTitle).fontSize(17).fontColor('#E5E6EB').layoutWeight(1)
          Text('关闭').fontSize(13).fontColor('#C6D3FF').onClick(() => this.detailSheetVisible = false)
        }.width('100%').padding({ left: 18, right: 18, bottom: 12 })
        Text(this.detailSheetDescription).fontSize(13).fontColor('#D3D4DC').width('100%').padding({ left: 18, right: 18, top: 10, bottom: 18 })
        if (this.detailSheetTitle === '种子色' || this.detailSheetTitle === '菜单背景颜色' ||
          this.detailSheetTitle === '菜单容器颜色' || this.detailSheetTitle === '菜单强调颜色' ||
          this.detailSheetTitle === '菜单栏边框颜色' || this.detailSheetTitle === '菜单文字颜色' ||
          this.detailSheetTitle === '菜单模糊颜色') {
          Scroll() {
            Column() {
              // 上游 SystemMenuPage.kt:308-368 的 TinyColorModeSettingItem 是「日间 + 夜间」双色点，
              // 点任一侧都弹同一个取色器（COLOR_MENU_ACCENT / COLOR_MENU_BG / COLOR_MENU_CONTAINER），
              // 这里照抄成日/夜两块并列色板。「种子色」与「菜单强调颜色」在上游共用 readMenuAccentColor，
              // 因此两块色板读写同一对字段（日间 readMenuAccentColor / 夜间 readMenuAccentColorNight）。
              MenuSettingPalette({
                title: this.detailSheetTitle + '（日间）',
                colors: MENU_COLOR_PALETTE,
                selectedColor: this.menuColorDay(this.detailSheetTitle),
                onChange: (color: string) => this.applyMenuColor(this.detailSheetTitle, color, false)
              })
              MenuSettingPalette({
                title: this.detailSheetTitle + '（夜间）',
                colors: MENU_COLOR_PALETTE,
                selectedColor: this.menuColorNight(this.detailSheetTitle),
                onChange: (color: string) => this.applyMenuColor(this.detailSheetTitle, color, true)
              })
              Text('「种子色」与「菜单强调颜色」共用同一组字段（上游 readMenuAccentColor / Night）；' +
                '菜单背景色、容器色未设置时回落到主题默认值，边框色回落描边默认色，' +
                '文字色回落 onSurface，模糊色未设置时不影响底色。')
                .fontSize(10).fontColor(this.themeColorTextTertiary).width('100%').padding(10)
            }.width('100%').padding({ left: 18, right: 18, bottom: 16 })
          }.height(360).scrollBar(BarState.Off)
        } else if (this.detailSheetTitle === '自定义阅读背景') {
          Scroll() {
            Column() {
              // 上游 BgTextConfigSheet 是日/夜两组并列（TinyColorModeSettingItem 日间+夜间双色、
              // TinyBgImageModeSettingItem 日/夜双图），这里同样两组同时显示，不做「编辑哪一组」切换。
              MenuSettingPalette({
                title: '日间背景颜色',
                colors: READER_BACKGROUND_COLORS,
                selectedColor: this.bgType === 0 ? this.bgStr : '',
                onChange: (color: string) => this.onBackgroundColorChange(color, false)
              })
              MenuSettingPalette({
                title: '夜间背景颜色',
                colors: READER_BACKGROUND_COLORS,
                selectedColor: this.bgTypeNight === 0 ? this.bgStrNight : '',
                onChange: (color: string) => this.onBackgroundColorChange(color, true)
              })
              this.BackgroundImageRow('日间背景图片', false)
              this.BackgroundImageRow('夜间背景图片', true)
              MenuSettingSlider({
                title: '背景透明度',
                value: this.bgAlpha,
                minValue: 0,
                maxValue: 100,
                stepValue: 5,
                onChange: (value: number) => this.onBgAlphaChange(value)
              })
              MenuSettingSwitch({
                title: '日间深色状态栏图标',
                detail: '状态栏图标改用深色，浅色背景更清楚',
                checked: this.darkStatusIcon,
                onChange: (enabled: boolean) => this.onDarkStatusIconChange(enabled, false)
              })
              MenuSettingSwitch({
                title: '夜间深色状态栏图标',
                detail: '状态栏图标改用深色，浅色背景更清楚',
                checked: this.darkStatusIconNight,
                onChange: (enabled: boolean) => this.onDarkStatusIconChange(enabled, true)
              })
              MenuSettingPalette({
                title: '日间文字颜色',
                colors: READER_EFFECT_COLORS,
                selectedColor: this.textColor,
                onChange: (color: string) => this.onTextColorChange(color, false)
              })
              MenuSettingPalette({
                title: '夜间文字颜色',
                colors: READER_EFFECT_COLORS,
                selectedColor: this.textColorNight,
                onChange: (color: string) => this.onTextColorChange(color, true)
              })
              MenuSettingPalette({
                title: '日间强调色',
                colors: READER_EFFECT_COLORS,
                selectedColor: this.textAccentColor,
                onChange: (color: string) => this.onTextAccentColorChange(color, false)
              })
              MenuSettingPalette({
                title: '夜间强调色',
                colors: READER_EFFECT_COLORS,
                selectedColor: this.textAccentColorNight,
                onChange: (color: string) => this.onTextAccentColorChange(color, true)
              })
              Text('强调色用于链接、搜索结果与朗读中的段落；背景透明度只作用于背景图片。')
                .fontSize(10).fontColor(this.themeColorTextTertiary).width('100%').padding(10)
            }.width('100%').padding({ left: 18, right: 18, bottom: 16 })
          }.height(460).scrollBar(BarState.Off)
        } else if (this.detailSheetTitle === '编辑背景样式') {
          Scroll() {
            Column() {
              Text('样式名称').fontSize(12).fontColor('#AEB0B9').width('100%').padding({ top: 6, bottom: 6 })
              TextInput({ text: this.editingStyleName, placeholder: '给这份样式起个名字' })
                .fontSize(13).fontColor('#E5E6EB').placeholderColor(this.themeColorTextTertiary)
                .backgroundColor('#292A31').borderRadius(10).padding(12)
                .onChange((value: string) => this.editingStyleName = value)
              MenuSettingPalette({
                title: '日间背景颜色',
                colors: READER_BACKGROUND_COLORS,
                selectedColor: this.editingStyleDayColor,
                onChange: (color: string) => this.editingStyleDayColor = color
              }).margin({ top: 12 })
              MenuSettingPalette({
                title: '夜间背景颜色',
                colors: READER_BACKGROUND_COLORS,
                selectedColor: this.editingStyleNightColor,
                onChange: (color: string) => this.editingStyleNightColor = color
              }).margin({ top: 12 })
              Text('改名与改色只影响这一份样式；其余样式与自定义背景图不受影响。')
                .fontSize(10).fontColor(this.themeColorTextTertiary).width('100%').padding(10)
              Text('保存').fontSize(13).fontColor('#ECEEF4').textAlign(TextAlign.Center)
                .width('100%').padding({ top: 11, bottom: 11 })
                .backgroundColor(this.themeColorAccent).borderRadius(10)
                .onClick(() => {
                  this.onUpdateBackgroundStyle(this.editingStyleIndex, this.editingStyleName,
                    this.editingStyleDayColor, this.editingStyleNightColor);
                  this.detailSheetVisible = false;
                })
            }.width('100%').padding({ left: 18, right: 18, bottom: 16 })
          }.height(460).scrollBar(BarState.Off)
        } else if (this.detailSheetTitle === '主题列表') {
          // 对齐上游 ThemeListContent：预设那几份钉死不可删，自建的可以删、可以上下挪。
          Scroll() {
            Column() {
              ForEach(this.backgroundStyles, (style: ReaderBackgroundStyle, styleIndex: number) => {
                Row() {
                  Stack({ alignContent: Alignment.Center }) {
                    Text(this.getBackgroundStyleLabel(style)).fontSize(11).maxLines(2).textAlign(TextAlign.Center)
                      .fontColor('#3E3D3B')
                  }.width(44).height(56)
                    .backgroundColor(this.readerNightMode ? style.nightColor : style.dayColor)
                    .borderRadius(9).clip(true)
                    .border({
                      width: this.paperIndex === styleIndex ? 2 : 1,
                      color: this.paperIndex === styleIndex ? this.themeColorAccent : '#33343C'
                    })
                    .onClick(() => this.onPaperChange(styleIndex))
                  Column() {
                    // layoutWeight 要放在 Column 上，放到 Text 上会把 Column 撑高、名字与标签被拉开一大截。
                    Text(this.getBackgroundStyleLabel(style)).fontSize(13).fontColor('#E5E6EB')
                    Text(styleIndex < READER_STYLE_PRESET_COUNT ? '预设' : '自建')
                      .fontSize(10).fontColor(this.themeColorTextTertiary).margin({ top: 2 })
                  }.alignItems(HorizontalAlign.Start).justifyContent(FlexAlign.Center)
                    .layoutWeight(1).margin({ left: 12 })
                  if (styleIndex >= READER_STYLE_PRESET_COUNT) {
                    Image($r('app.media.reader_arrow_forward')).width(16).height(16)
                      .fillColor('#9EA0AA').rotate({ angle: 270 })
                      .onClick(() => this.onMoveBackgroundStyle(styleIndex, styleIndex - 1))
                    Image($r('app.media.profile_delete')).width(16).height(16)
                      .fillColor('#D98A8A').margin({ left: 12 })
                      .onClick(() => this.onRemoveBackgroundStyle(styleIndex))
                  }
                }.width('100%').padding({ top: 8, bottom: 8 })
              }, (style: ReaderBackgroundStyle) => `${style.id}|${style.name}|${style.dayColor}|${style.nightColor}`)
              Text('前 5 份是内置预设，不能删除也不能移动；自建样式可以删掉、可以上移。')
                .fontSize(10).fontColor(this.themeColorTextTertiary).width('100%').padding(10)
            }.width('100%').padding({ left: 18, right: 18, bottom: 16 })
          }.height(460).scrollBar(BarState.Off)
        } else if (this.detailSheetTitle === '选择字体') {
          Scroll() {
            Column() {
              Text('当前字体').fontSize(12).fontColor(this.themeColorAccent).width('100%').padding({ top: 8, bottom: 6 })
              Text(this.getCurrentFontDisplayName()).fontSize(14).fontColor('#E5E6EB').width('100%')
                .padding(12).backgroundColor('#202127').borderRadius(10)
              Text('系统字体').fontSize(12).fontColor(this.themeColorAccent).width('100%').padding({ top: 14, bottom: 6 })
              Row() {
                ForEach(['默认字体', '衬线字体', '等宽字体'], (label: string, index: number) => {
                  Text(label).fontSize(11).fontColor(this.getFontTargetPath().length === 0 && this.systemTypefaces === index
                    ? '#ECEEF4' : '#B7B8C1')
                    .textAlign(TextAlign.Center).layoutWeight(1).padding({ top: 10, bottom: 10 })
                    .backgroundColor(this.getFontTargetPath().length === 0 && this.systemTypefaces === index
                      ? '#454B62' : '#202127').borderRadius(10).margin({ right: 5 })
                    .onClick(() => this.chooseSystemTypeface(index))
                }, (label: string) => label)
              }.width('100%')
              Row() {
                Text('导入字体文件').fontSize(13).fontColor('#E5E6EB').layoutWeight(1)
                Text('选择 TTF/OTF').fontSize(11).fontColor(this.themeColorAccent)
              }.width('100%').padding(12).backgroundColor('#202127').borderRadius(10)
                .margin({ top: 12, bottom: 6 }).onClick(() => this.importReaderFontFile())
              Row() {
                Text('导入字体目录').fontSize(13).fontColor('#E5E6EB').layoutWeight(1)
                Text('支持时可用').fontSize(11).fontColor(this.themeColorTextTertiary)
              }.width('100%').padding(12).backgroundColor('#202127').borderRadius(10)
                .margin({ bottom: 8 }).onClick(() => this.importReaderFontFolder())
              if (this.fontEntries.length === 0) {
                Text('尚无导入字体。可选择单个字体文件；已选字体复制到应用私有目录。')
                  .fontSize(11).fontColor(this.themeColorTextTertiary).width('100%').padding(12)
              } else {
                Text('已导入字体').fontSize(12).fontColor(this.themeColorAccent).width('100%').padding({ top: 10, bottom: 6 })
                ForEach(this.fontEntries, (font: ReaderFontEntry) => {
                  Row() {
                    Column() {
                      Text(font.displayName).fontSize(13).fontColor('#E5E6EB').maxLines(1)
                      Text(font.familyName).fontSize(10).fontColor(this.themeColorTextTertiary).maxLines(1).margin({ top: 3 })
                    }.alignItems(HorizontalAlign.Start).layoutWeight(1)
                    if (this.getFontTargetPath() === font.path) {
                      Image($r('app.media.app_check')).width(18).height(18).fillColor(this.themeColorAccent)
                    } else {
                      Text('选择').fontSize(11).fontColor(this.themeColorAccent)
                    }
                  }.width('100%').padding(12).backgroundColor('#202127').borderRadius(10).margin({ bottom: 6 })
                    .onClick(() => this.chooseReaderFont(font))
                }, (font: ReaderFontEntry) => font.familyName)
              }
            }.width('100%').padding({ left: 18, right: 18, bottom: 16 })
          }.width('100%').layoutWeight(1).scrollBar(BarState.Off)
        } else if (this.detailSheetTitle === '排版设置') {
          Scroll() {
          Column() {
            Row() {
              ForEach(['正文', '标题', '页眉', '页脚'], (label: string) => {
                Text(label).fontSize(11).fontColor('#D9DAE0').layoutWeight(1).textAlign(TextAlign.Center)
                  .padding(9).backgroundColor('#292A31').borderRadius(8).margin({ right: 4 })
                  .onClick(() => this.detailSelectedOption = label)
              }, (label: string) => label)
            }.width('100%').padding({ left: 18, right: 18, bottom: 8 })
            if (this.detailSelectedOption === '标题') {
              this.TitleTypographySettings()
            } else {
            MenuSettingOption({ title: '字体', detail: this.getCurrentFontDisplayName(), migrated: true })
              .onClick(() => this.openFontSelection())
            MenuSettingSlider({ title: '字号', value: this.fontSize, minValue: 5, maxValue: 50 })
            MenuSettingOption({ title: '颜色', detail: '日间 / 夜间' }).onClick(() => this.openDetailSheet('信息颜色', '选择文字颜色'))
            MenuSettingOption({ title: '效果', detail: '斜体 / 字重 / 阴影 / 下划线', migrated: true })
              .onClick(() => this.openDetailSheet('文字效果', '配置文字效果'))
            MenuSettingOption({ title: '缩进', detail: '全角空格数（0–4）', migrated: true }).onClick(() => this.openDetailSheet('正文排版', '调整正文排版'))
            MenuSettingOption({ title: '字距', detail: '字符间距设置', migrated: true }).onClick(() => this.openDetailSheet('正文排版', '调整正文排版'))
            MenuSettingOption({ title: '段距', detail: '按行高比例设置', migrated: true }).onClick(() => this.openDetailSheet('正文排版', '调整正文排版'))
            MenuSettingOption({ title: '行距', detail: '行高比例设置', migrated: true }).onClick(() => this.openDetailSheet('正文排版', '调整正文排版'))
            MenuSettingOption({ title: '文字对齐', detail: '两端对齐 / 底部对齐', migrated: true }).onClick(() => this.openDetailSheet('文字对齐', '选择正文对齐方式'))
            MenuSettingOption({ title: '中文简繁体转换', detail: this.getChineseConverterLabel(), migrated: true })
              .onClick(() => this.openDetailSheet('中文简繁体转换', '按档位转换正文与章节标题的字形'))
            Text('正文和标题支持系统字体及导入的 TTF/OTF；字体族会参与文字测量和分页。页眉页脚字体沿用各自选项。').fontSize(10).fontColor(this.themeColorTextTertiary).width('100%').padding(12)
            }
          }.width('100%').padding({ bottom: 16 })
          }.width('100%').layoutWeight(1).scrollBar(BarState.Off)
        } else if (this.detailSheetTitle === '文字效果') {
          Scroll() {
            Column() {
              MenuSettingSwitch({
                title: '斜体', detail: '正文使用斜体字形', checked: this.textItalic,
                onChange: (enabled: boolean) => this.onTextItalicChange(enabled)
              })
              Column() {
                Text('字重').fontSize(13).fontColor('#E2E3E8').width('100%').margin({ bottom: 8 })
                Row() {
                  ForEach(['纤细', '常规', '中等', '粗体', '特粗'], (label: string, index: number) => {
                    Text(label).fontSize(11).fontColor(this.textBold === (READER_BODY_WEIGHT_VALUES[index] ?? 500) ? '#ECECF0' : '#B7B8C1')
                      .layoutWeight(1).textAlign(TextAlign.Center).padding(8)
                      .backgroundColor(this.textBold === (READER_BODY_WEIGHT_VALUES[index] ?? 500) ? '#454B62' : '#15161B').borderRadius(8)
                      .margin({ right: 4 }).onClick(() => this.onTextBoldChange(READER_BODY_WEIGHT_VALUES[index] ?? 500))
                  }, (label: string) => label)
                }.width('100%')
              }.width('100%').padding(12).backgroundColor('#202127').borderRadius(12)
              MenuSettingSwitch({
                title: '文字阴影', detail: '为正文绘制阴影', checked: this.textShadow,
                onChange: (enabled: boolean) => this.onTextShadowChange(enabled)
              })
              if (this.textShadow) {
                MenuSettingPalette({
                  title: this.readerNightMode ? '夜间阴影颜色' : '日间阴影颜色',
                  colors: READER_EFFECT_COLORS,
                  selectedColor: this.readerNightMode ? this.textShadowColorN : this.textShadowColor,
                  onChange: (color: string) => this.onTextShadowColorChange(color, this.readerNightMode)
                })
                MenuSettingSlider({ title: '阴影半径', value: this.shadowRadius, minValue: 0, maxValue: 100,
                  onChange: (value: number) => this.onShadowRadiusChange(value) })
                MenuSettingSlider({ title: '阴影横向偏移', value: this.shadowDx, minValue: -50, maxValue: 50,
                  onChange: (value: number) => this.onShadowDxChange(value) })
                MenuSettingSlider({ title: '阴影纵向偏移', value: this.shadowDy, minValue: -50, maxValue: 50,
                  onChange: (value: number) => this.onShadowDyChange(value) })
              }
              MenuSettingSwitch({
                title: '正文下划线', detail: '对每行正文添加下划线', checked: this.underline,
                onChange: (enabled: boolean) => this.onUnderlineChange(enabled)
              })
              MenuSettingSwitch({
                title: '虚线下划线', detail: '将正文下划线显示为虚线', checked: this.dottedLine,
                onChange: (enabled: boolean) => this.onDottedLineChange(enabled)
              })
              if (this.underline) {
                MenuSettingPalette({
                  title: this.readerNightMode ? '夜间下划线颜色' : '日间下划线颜色',
                  colors: READER_EFFECT_COLORS,
                  selectedColor: this.readerNightMode ? this.underlineColorNight : this.underlineColor,
                  onChange: (color: string) => this.onUnderlineColorChange(color, this.readerNightMode)
                })
                MenuSettingSlider({ title: '下划线粗细', value: this.underlineHeight, minValue: 0, maxValue: 10,
                  onChange: (value: number) => this.onUnderlineHeightChange(value) })
                MenuSettingSlider({ title: '离字间距', value: this.underlinePadding, minValue: 0, maxValue: 20,
                  onChange: (value: number) => this.onUnderlinePaddingChange(value) })
                MenuSettingSwitch({
                  title: '撑满整行', detail: '下划线延伸到页面左右边距',
                  checked: this.underlineExtend,
                  onChange: (enabled: boolean) => this.onUnderlineExtendChange(enabled)
                })
                if (this.dottedLine) {
                  MenuSettingSlider({ title: '实线段长', value: this.dottedBase, minValue: 0, maxValue: 20,
                    onChange: (value: number) => this.onDottedBaseChange(value) })
                  MenuSettingSlider({ title: '空隙长度', value: this.dottedRatio, minValue: 0, maxValue: 20,
                    onChange: (value: number) => this.onDottedRatioChange(value) })
                }
              }
              Text('高亮规则依赖 Android 规则库；当前 HOS 尚无兼容规则仓储，本页不伪造规则列表。')
                .fontSize(10).fontColor(this.themeColorTextTertiary).width('100%').padding(12)
            }.width('100%').padding({ left: 18, right: 18, bottom: 16 })
          }.height(440).scrollBar(BarState.Off)
        } else if (this.detailSheetTitle === '文字对齐') {
          Column() {
            MenuSettingSwitch({
              title: '两端对齐',
              detail: '将换行行的文字间距拉伸至正文宽度',
              checked: this.textFullJustify,
              onChange: (enabled: boolean) => this.onTextFullJustifyChange(enabled)
            })
            MenuSettingSwitch({
              title: '底部对齐',
              detail: '将适量的页底留白分配到各行之间',
              checked: this.textBottomJustify,
              onChange: (enabled: boolean) => this.onTextBottomJustifyChange(enabled)
            })
            Text('设置会立即保存并应用。两端对齐改变行内间距；底部对齐只移动本页文字，不改章节位置。')
              .fontSize(10).fontColor(this.themeColorTextTertiary).width('100%').padding(12)
          }.width('100%').padding({ left: 18, right: 18, bottom: 16 })
        } else if (this.detailSheetTitle === '选中文字菜单') {
          Scroll() {
            Column() {
              MenuSettingSwitch({
                title: '展开文字菜单', detail: '折叠菜单项是否与一级菜单同排展开',
                checked: this.expandTextMenu,
                onChange: (enabled: boolean) => this.onExpandTextMenuChange(enabled)
              })
              MenuSettingSwitch({
                title: '显示菜单图标', detail: '在文字菜单操作项旁显示图标',
                checked: this.showSelectMenuIcon,
                onChange: (enabled: boolean) => this.onShowSelectMenuIconChange(enabled)
              })
              Row() {
                Text('主菜单').fontSize(13).fontColor('#E5E6EB').layoutWeight(1)
                Text(`${this.getTextMenuEntries(0).length}`).fontSize(11).fontColor('#AEB0B9')
                Image($r('app.media.profile_expand_more')).width(18).height(18).fillColor('#AEB0B9')
                  .rotate({ angle: this.primaryTextMenuExpanded ? 180 : 0 }).margin({ left: 8 })
              }.width('100%').padding(12).backgroundColor('#292A31').borderRadius(10).margin({ top: 8, bottom: 5 })
                .onClick(() => this.toggleTextMenuGroup(0))
              if (this.primaryTextMenuExpanded) {
                ForEach(this.getTextMenuEntries(0), (item: ReaderTextMenuEntry) => {
                  Row() {
                    if (this.showSelectMenuIcon) { this.readerTextMenuIcon(item.id) }
                    Text(item.title).fontSize(12).fontColor('#E5E6EB').layoutWeight(1).margin({ left: 8 })
                    Image($r('app.media.reader_reorder_up')).width(16).height(16).fillColor('#C8CAD2')
                      .padding(5).onClick(() => this.reorderTextMenuEntry(item.id, -1, 0))
                    Image($r('app.media.reader_reorder_down')).width(16).height(16).fillColor('#C8CAD2')
                      .padding(5).onClick(() => this.reorderTextMenuEntry(item.id, 1, 0))
                    Image($r('app.media.app_reduce')).width(17).height(17).fillColor('#C8CAD2')
                      .padding(5).onClick(() => this.moveTextMenuEntry(item.id, 1))
                    Image($r('app.media.reader_visibility_off')).width(17).height(17).fillColor('#C8CAD2')
                      .padding(5).onClick(() => this.moveTextMenuEntry(item.id, 2))
                  }.width('100%').padding({ left: 10, right: 5, top: 5, bottom: 5 })
                    .backgroundColor('#202127').borderRadius(9).margin({ bottom: 4 })
                }, (item: ReaderTextMenuEntry) => item.id)
              }
              Row() {
                Text('折叠菜单').fontSize(13).fontColor('#E5E6EB').layoutWeight(1)
                Text(`${this.getTextMenuEntries(1).length}`).fontSize(11).fontColor('#AEB0B9')
                Image($r('app.media.profile_expand_more')).width(18).height(18).fillColor('#AEB0B9')
                  .rotate({ angle: this.collapsedTextMenuExpanded ? 180 : 0 }).margin({ left: 8 })
              }.width('100%').padding(12).backgroundColor('#292A31').borderRadius(10).margin({ top: 5, bottom: 5 })
                .onClick(() => this.toggleTextMenuGroup(1))
              if (this.collapsedTextMenuExpanded) {
                ForEach(this.getTextMenuEntries(1), (item: ReaderTextMenuEntry) => {
                  Row() {
                    if (this.showSelectMenuIcon) { this.readerTextMenuIcon(item.id) }
                    Text(item.title).fontSize(12).fontColor('#E5E6EB').layoutWeight(1).margin({ left: 8 })
                    Image($r('app.media.reader_reorder_up')).width(16).height(16).fillColor('#C8CAD2')
                      .padding(5).onClick(() => this.reorderTextMenuEntry(item.id, -1, 1))
                    Image($r('app.media.reader_reorder_down')).width(16).height(16).fillColor('#C8CAD2')
                      .padding(5).onClick(() => this.reorderTextMenuEntry(item.id, 1, 1))
                    Image($r('app.media.app_add')).width(17).height(17).fillColor('#C8CAD2')
                      .padding(5).onClick(() => this.moveTextMenuEntry(item.id, 0))
                    Image($r('app.media.reader_visibility_off')).width(17).height(17).fillColor('#C8CAD2')
                      .padding(5).onClick(() => this.moveTextMenuEntry(item.id, 2))
                  }.width('100%').padding({ left: 10, right: 5, top: 5, bottom: 5 })
                    .backgroundColor('#202127').borderRadius(9).margin({ bottom: 4 })
                }, (item: ReaderTextMenuEntry) => item.id)
              }
              Row() {
                Text('隐藏项目').fontSize(13).fontColor('#E5E6EB').layoutWeight(1)
                Text(`${this.getTextMenuEntries(2).length}`).fontSize(11).fontColor('#AEB0B9')
                Image($r('app.media.profile_expand_more')).width(18).height(18).fillColor('#AEB0B9')
                  .rotate({ angle: this.hiddenTextMenuExpanded ? 180 : 0 }).margin({ left: 8 })
              }.width('100%').padding(12).backgroundColor('#292A31').borderRadius(10).margin({ top: 5, bottom: 5 })
                .onClick(() => this.toggleTextMenuGroup(2))
              if (this.hiddenTextMenuExpanded) {
                ForEach(this.getTextMenuEntries(2), (item: ReaderTextMenuEntry) => {
                  Row() {
                    if (this.showSelectMenuIcon) { this.readerTextMenuIcon(item.id) }
                    Text(item.title).fontSize(12).fontColor('#E5E6EB').layoutWeight(1).margin({ left: 8 })
                    Image($r('app.media.app_add')).width(17).height(17).fillColor('#C8CAD2')
                      .padding(5).onClick(() => this.moveTextMenuEntry(item.id, 0))
                  }.width('100%').padding({ left: 10, right: 5, top: 5, bottom: 5 })
                    .backgroundColor('#202127').borderRadius(9).margin({ bottom: 4 })
                }, (item: ReaderTextMenuEntry) => item.id)
              }
              Column() {
                Text('Android 系统提供的文字处理应用项暂未迁移。')
                  .fontSize(11).fontColor('#AEB0B9').width('100%')
                Text('排序、分组与两个开关点「保存」后落库，并随备份同步；阅读页菜单只显示已实现能力的条目。')
                  .fontSize(10).fontColor(this.themeColorTextTertiary).width('100%').margin({ top: 5 })
              }.padding(12).backgroundColor('#202127').borderRadius(10).margin({ top: 8 })
              Row() {
                Blank()
                Text('保存').fontSize(13).fontColor('#101116')
                  .padding({ left: 20, right: 20, top: 10, bottom: 10 })
                  .backgroundColor('#C6D3FF').borderRadius(18)
                  .onClick(() => {
                    this.saveTextMenuConfig();
                    this.onUnavailableAction('选中文字菜单配置已保存');
                  })
              }.width('100%').padding({ top: 10 })
            }.width('100%').padding({ left: 18, right: 18, bottom: 16 })
          }.layoutWeight(1).scrollBar(BarState.Off)
        } else if (this.detailSheetTitle === '点击区域配置') {
          Scroll() {
            Column() {
              Text('点击阅读页面的分区，再选择该区域的动作。')
                .fontSize(12).fontColor('#AEB0B9').width('100%').padding({ top: 4, bottom: 10 })
              ForEach([0, 1, 2], (rowIndex: number) => {
                Row() {
                  ForEach([0, 1, 2], (columnIndex: number) => {
                    Column() {
                      Text(CLICK_REGION_NAMES[rowIndex * 3 + columnIndex] ?? '')
                        .fontSize(10).fontColor('#AEB0B9').margin({ bottom: 4 })
                      Text(this.clickRegionActions[rowIndex * 3 + columnIndex] ?? '无操作')
                        .fontSize(12).fontColor('#E5E6EB').textAlign(TextAlign.Center)
                    }.layoutWeight(1).height(58).justifyContent(FlexAlign.Center)
                      .backgroundColor(this.selectedClickRegionIndex === rowIndex * 3 + columnIndex ? '#454B62' : '#292A31')
                      .borderRadius(10).margin({ right: columnIndex < 2 ? 6 : 0, bottom: 6 })
                      .onClick(() => this.selectedClickRegionIndex = rowIndex * 3 + columnIndex)
                  }, (columnIndex: number) => `column-${columnIndex}`)
                }.width('100%')
              }, (rowIndex: number) => `row-${rowIndex}`)
              Text(`设置${CLICK_REGION_NAMES[this.selectedClickRegionIndex] ?? ''}区域动作`)
                .fontSize(12).fontColor(this.themeColorAccent).width('100%').padding({ top: 8, bottom: 6 })
              ForEach(READER_CLICK_REGION_ACTIONS, (action: string) => {
                Row() {
                  Text(action).fontSize(13).fontColor('#E5E6EB').layoutWeight(1)
                  if ((this.clickRegionActions[this.selectedClickRegionIndex] ?? '') === action) {
                    Image($r('app.media.app_check')).width(18).height(18).fillColor(this.themeColorAccent)
                  }
                }.width('100%').padding(10).backgroundColor(
                  (this.clickRegionActions[this.selectedClickRegionIndex] ?? '') === action ? '#34394C' : '#202127'
                ).borderRadius(9).margin({ bottom: 5 }).onClick(() => {
                  const nextActions: string[] = this.clickRegionActions.map((current: string, index: number) =>
                    index === this.selectedClickRegionIndex ? action : current
                  );
                  this.onClickRegionActionsChange(nextActions);
                })
              }, (action: string) => action)
              Text('动作会立即保存，并应用到阅读页对应分区。未迁移的动作会明确提示。')
                .fontSize(10).fontColor(this.themeColorTextTertiary).width('100%').textAlign(TextAlign.Center).padding(12)
            }.width('100%').padding({ left: 18, right: 18, bottom: 16 })
          }.layoutWeight(1).scrollBar(BarState.Off)
        } else if (this.detailSheetTitle === '自定义翻页按键') {
          Scroll() {
            Column() {
              Text('上一页按键').fontSize(12).fontColor('#AEB0B9').width('100%').padding({ top: 6, bottom: 6 })
              TextInput({ text: this.previousPageKeys, placeholder: '按键码，多个用英文逗号分隔' })
                .fontSize(13).fontColor('#E5E6EB').placeholderColor(this.themeColorTextTertiary)
                .backgroundColor('#292A31').borderRadius(10).padding(12)
                .onChange((value: string) => this.previousPageKeys = value)
              Text('下一页按键').fontSize(12).fontColor('#AEB0B9').width('100%').padding({ top: 12, bottom: 6 })
              TextInput({ text: this.nextPageKeys, placeholder: '按键码，多个用英文逗号分隔' })
                .fontSize(13).fontColor('#E5E6EB').placeholderColor(this.themeColorTextTertiary)
                .backgroundColor('#292A31').borderRadius(10).padding(12)
                .onChange((value: string) => this.nextPageKeys = value)
              Text('将焦点放到输入框按下物理按键会自动录入键值，多个按键会自动用英文逗号隔开。')
                .fontSize(11).fontColor('#AEB0B9').width('100%').padding({ top: 10, bottom: 6 })
              Text('当前可由系统接管翻页的按键只有音量键与媒体键（上一曲/下一曲/播放暂停）；其余键值会被保存并随备份同步，但按下时只有应用窗口持有焦点才会生效。')
                .fontSize(10).fontColor(this.themeColorTextTertiary).width('100%').padding({ bottom: 14 })
              Row() {
                Text('重置').fontSize(13).fontColor('#D3D4DC').padding({ left: 18, right: 18, top: 10, bottom: 10 })
                  .backgroundColor('#292A31').borderRadius(18)
                  .onClick(() => { this.previousPageKeys = ''; this.nextPageKeys = ''; })
                Blank()
                Text('确定').fontSize(13).fontColor('#101116').padding({ left: 20, right: 20, top: 10, bottom: 10 })
                  .backgroundColor('#C6D3FF').borderRadius(18)
                  .onClick(() => {
                    this.onPrevKeysChange(this.previousPageKeys);
                    this.onNextKeysChange(this.nextPageKeys);
                    this.detailSheetVisible = false;
                  })
              }.width('100%')
            }.width('100%').padding({ left: 18, right: 18, bottom: 16 })
          }.layoutWeight(1).scrollBar(BarState.Off)
        } else if (this.detailSheetTitle === '护眼设置') {
          Scroll() {
            Column() {
              MenuSettingSwitch({
                title: '启用护眼模式', detail: '使用暖色调降低蓝光',
                checked: this.eyeProtectionEnabled,
                onChange: (enabled: boolean) => this.onEyeProtectionEnabledChange(enabled)
              })
              MenuSettingSwitch({
                title: '深色模式时自动开启', detail: '跟随阅读界面的深色/浅色模式自动切换',
                checked: this.eyeProtectionAutoNight,
                onChange: (enabled: boolean) => this.onEyeProtectionAutoNightChange(enabled)
              })
              if (this.eyeProtectionEnabled || this.eyeProtectionAutoNight) {
                MenuSettingSlider({
                  title: '护眼强度', value: this.eyeProtectionIntensity, minValue: 0, maxValue: 100,
                  onChange: (value: number) => this.onEyeProtectionIntensityChange(value)
                })
                MenuSettingSwitch({
                  title: '定时开启', detail: '仅在设定的时间段内生效',
                  checked: this.eyeProtectionSchedule,
                  onChange: (enabled: boolean) => this.onEyeProtectionScheduleChange(enabled)
                })
                if (this.eyeProtectionSchedule) {
                  Row() {
                    Text('开始时间').fontSize(12).fontColor('#D9DAE0')
                    Blank()
                    Text(this.eyeProtectionStartTime).fontSize(12).fontColor('#C6D3FF')
                    Text('›').fontSize(20).fontColor(this.themeColorTextTertiary).margin({ left: 8 })
                  }.width('100%').padding({ top: 10, bottom: 6 }).onClick(() => this.showEyeProtectionTimePicker(true))
                  Row() {
                    Text('结束时间').fontSize(12).fontColor('#D9DAE0')
                    Blank()
                    Text(this.eyeProtectionEndTime).fontSize(12).fontColor('#C6D3FF')
                    Text('›').fontSize(20).fontColor(this.themeColorTextTertiary).margin({ left: 8 })
                  }.width('100%').padding({ top: 6, bottom: 8 }).onClick(() => this.showEyeProtectionTimePicker(false))
                }
              }
              Text('设置会立即保存并应用到阅读页面；定时支持跨越午夜。')
                .fontSize(10).fontColor(this.themeColorTextTertiary).width('100%').textAlign(TextAlign.Center).padding(12)
            }.width('100%').padding({ left: 18, right: 18, bottom: 16 })
          }.layoutWeight(1).scrollBar(BarState.Off)
        } else if (this.detailSheetTitle === '书签标记') {
          Column() {
            Text('当前标记').fontSize(12).fontColor(this.themeColorAccent).width('100%').padding({ top: 4, bottom: 8 })
            Row() {
              Stack({ alignContent: Alignment.Center }) {
                // 有自定义图片时预览真实图片，否则用内置书签图标示意默认丝带。
                if (this.bookmarkBadgeImage.length > 0) {
                  Image(this.badgeImageSource())
                    .width(Math.max(12, Math.min(58, this.bookmarkBadgeSize * 2)))
                    .height(Math.max(12, Math.min(58, this.bookmarkBadgeSize * 2)))
                    .objectFit(ImageFit.Contain)
                } else {
                  Image($r('app.media.app_bookmark')).width(Math.max(8, this.bookmarkBadgeSize))
                    .height(Math.max(8, this.bookmarkBadgeSize)).fillColor('#C6D3FF')
                }
              }.width(62).height(62).backgroundColor('#292A31').borderRadius(12)
              Column() {
                Text(this.bookmarkBadgeImage.length > 0 ? '自定义图片' : '默认')
                  .fontSize(14).fontColor('#E5E6EB')
                Text('角标大小：' + this.bookmarkBadgeSize.toString() + 'dp')
                  .fontSize(11).fontColor('#AEB0B9').margin({ top: 5 })
              }.alignItems(HorizontalAlign.Start).margin({ left: 12 })
              Blank()
            }.width('100%').padding(12).backgroundColor('#202127').borderRadius(12)
            MenuSettingOption({ title: '选择书签标记图片', detail: '使用本地图片作为阅读页角标', migrated: true })
              .onClick(() => this.onPickBookmarkBadgeImage())
            if (this.bookmarkBadgeImage.length > 0) {
              MenuSettingOption({ title: '恢复默认', detail: '移除自定义角标图片', migrated: true })
                .onClick(() => this.onResetBookmarkBadgeImage())
            }
            MenuSettingSlider({
              title: '角标大小（dp）', value: this.bookmarkBadgeSize, minValue: 0, maxValue: 50,
              onChange: (value: number) => this.onBookmarkBadgeSizeChange(value)
            })
            Text('角标大小会立即保存并应用到阅读页右上角；0 表示不显示角标。自定义图片保存在应用内，可随时恢复默认。')
              .fontSize(10).fontColor(this.themeColorTextTertiary).width('100%').padding(12)
          }.width('100%').padding({ left: 18, right: 18, bottom: 16 })
        } else if (this.detailSheetTitle === '页边距') {
          Column() {
            Row() {
              ForEach(['正文', '页眉', '页脚'], (label: string) => {
                Text(label).fontSize(11).fontColor('#D9DAE0').layoutWeight(1).textAlign(TextAlign.Center)
                  .padding(9).backgroundColor('#292A31').borderRadius(8).margin({ right: 4 })
                  .onClick(() => this.detailSelectedOption = label)
              }, (label: string) => label)
            }.width('100%').padding({ bottom: 8 })
            MenuSettingSlider({ title: '上边距', value: this.getPaddingValue('上'), minValue: 0,
              maxValue: this.detailSelectedOption === '正文' ? 200 : 300,
              onChange: (value: number) => this.updatePadding('上', value) })
            MenuSettingSlider({ title: '下边距', value: this.getPaddingValue('下'), minValue: 0,
              maxValue: this.detailSelectedOption === '正文' ? 200 : 300,
              onChange: (value: number) => this.updatePadding('下', value) })
            MenuSettingSlider({ title: '左边距', value: this.getPaddingValue('左'), minValue: 0,
              maxValue: this.detailSelectedOption === '正文' ? 200 : 300,
              onChange: (value: number) => this.updatePadding('左', value) })
            MenuSettingSlider({ title: '右边距', value: this.getPaddingValue('右'), minValue: 0,
              maxValue: this.detailSelectedOption === '正文' ? 200 : 300,
              onChange: (value: number) => this.updatePadding('右', value) })
            Text('边距会立即保存并应用到阅读页。').fontSize(10).fontColor(this.themeColorTextTertiary).width('100%').padding(12)
          }.width('100%').padding({ left: 18, right: 18, bottom: 16 })
        } else if (this.detailSheetTitle === '正文排版') {
          Column() {
            Row() {
              Text('缩进').fontSize(13).fontColor('#E2E3E8').layoutWeight(1)
              Text(this.paragraphIndent.length.toString()).fontSize(12).fontColor('#D3D4DC')
            }.width('100%')
            Slider({ value: this.paragraphIndent.length, min: 0, max: 4, step: 1, style: SliderStyle.InSet })
              .width('100%').selectedColor(this.themeColorAccent).trackColor('#454751').blockColor(this.themeColorAccent)
              .onChange((value: number, mode: SliderChangeMode) => {
                if (mode === SliderChangeMode.Moving || mode === SliderChangeMode.Click || mode === SliderChangeMode.End) {
                  this.onParagraphIndentCountChange(Math.max(0, Math.min(4, Math.round(value))));
                }
              })
            Row() {
              Text('字距').fontSize(13).fontColor('#E2E3E8').layoutWeight(1)
              Text(this.letterSpacing.toFixed(2)).fontSize(12).fontColor('#D3D4DC')
            }.width('100%').margin({ top: 12 })
            Slider({ value: this.letterSpacing * 100 + 50, min: 0, max: 100, step: 1, style: SliderStyle.InSet })
              .width('100%').selectedColor(this.themeColorAccent).trackColor('#454751').blockColor(this.themeColorAccent)
              .onChange((value: number, mode: SliderChangeMode) => {
                if (mode === SliderChangeMode.Moving || mode === SliderChangeMode.Click || mode === SliderChangeMode.End) {
                  this.onLetterSpacingChange((Math.round(value) - 50) / 100);
                }
              })
            Row() {
              Text('段距').fontSize(13).fontColor('#E2E3E8').layoutWeight(1)
              Text((this.paragraphSpacing / 10).toFixed(1)).fontSize(12).fontColor('#D3D4DC')
            }.width('100%').margin({ top: 12 })
            Slider({ value: this.paragraphSpacing, min: 0, max: 20, step: 1, style: SliderStyle.InSet })
              .width('100%').selectedColor(this.themeColorAccent).trackColor('#454751').blockColor(this.themeColorAccent)
              .onChange((value: number, mode: SliderChangeMode) => {
                if (mode === SliderChangeMode.Moving || mode === SliderChangeMode.Click || mode === SliderChangeMode.End) {
                  this.onParagraphSpacingChange(Math.max(0, Math.min(20, Math.round(value))));
                }
              })
            Row() {
              Text('行距').fontSize(13).fontColor('#E2E3E8').layoutWeight(1)
              Text(((this.lineSpacing - 10) / 10).toFixed(1)).fontSize(12).fontColor('#D3D4DC')
            }.width('100%').margin({ top: 12 })
            Slider({ value: this.lineSpacing, min: 0, max: 20, step: 1, style: SliderStyle.InSet })
              .width('100%').selectedColor(this.themeColorAccent).trackColor('#454751').blockColor(this.themeColorAccent)
              .onChange((value: number, mode: SliderChangeMode) => {
                if (mode === SliderChangeMode.Moving || mode === SliderChangeMode.Click || mode === SliderChangeMode.End) {
                  this.onLineSpacingChange(Math.max(0, Math.min(20, Math.round(value))));
                }
              })
            Text('缩进为全角空格，范围0–4；字距按 em 比例调整（-0.50–0.50）。段距和行距遵循 Android 配置。更改后立即保存并应用。')
              .fontSize(10).fontColor(this.themeColorTextTertiary).width('100%').padding({ top: 10, bottom: 12 })
          }.width('100%').padding({ left: 18, right: 18, bottom: 16 })
        } else {
          Scroll() {
            Column() {
              ForEach(this.getDetailChoices(this.detailSheetTitle), (choice: string) => {
                Row() {
                  Text(choice).fontSize(13).fontColor('#E5E6EB').layoutWeight(1)
                  if (this.detailSelectedOption === choice) {
                    Image($r('app.media.app_check')).width(18).height(18).fillColor(this.themeColorAccent)
                  }
                }.width('100%').padding(12).backgroundColor(
                  this.detailSelectedOption === choice ? '#34394C' : '#202127'
                ).borderRadius(10).margin({ bottom: 6 }).onClick(() => this.applyDetailChoicePreview(choice))
              }, (choice: string) => choice)
              if (this.detailInfoSlot !== undefined && this.detailSelectedOption === '自定义') {
                TextInput({ text: this.detailCustomText, placeholder: '输入自定义提示内容' })
                  .fontSize(13).fontColor('#E5E6EB').placeholderColor(this.themeColorTextTertiary)
                  .backgroundColor('#292A31').borderRadius(10).padding(12)
                  .onChange((value: string) => this.detailCustomText = value)
                Text('可用变量：{BookName}、{ChapterTitle}、{Time}、{BatteryPercent}、{ChapterIndex}、{ChapterSize}、{PageIndex}、{PageSize}、{PageRemaining}、{ReadProgress}、{FullPageIndex}、{FullPageSize}')
                  .fontSize(10).fontColor(this.themeColorTextTertiary).width('100%').padding({ top: 8, bottom: 8 })
                Text('保存').fontSize(13).fontColor('#101116').padding({ left: 18, right: 18, top: 9, bottom: 9 })
                  .backgroundColor('#C6D3FF').borderRadius(18).alignSelf(ItemAlign.End)
                  .onClick(() => this.saveCustomInfoTip())
              }
              if (this.getDetailChoices(this.detailSheetTitle).length === 0 &&
                this.detailSheetTitle !== '自定义阅读背景' &&
                this.detailSheetTitle !== '编辑背景样式' &&
                this.detailSheetTitle !== '主题列表') {
                Text('此配置项的实际操作尚未迁移。').fontSize(12).fontColor('#A9ABB5').width('100%').padding(12)
              }
              Text(this.detailSheetTitle === '自定义阅读背景' ||
                this.detailSheetTitle === '编辑背景样式' ||
                this.detailSheetTitle === '主题列表' ||
                this.detailSheetTitle === '翻页动画' || this.detailSheetTitle === '翻页动画速度' ||
                this.detailSheetTitle === '横屏双页' ||
                this.detailSheetTitle === '进度条行为' || this.detailSheetTitle === '滑动条显示样式' ||
                this.detailSheetTitle === '中文简繁体转换' ||
                this.detailSheetTitle === '点击图片行为' ||
                this.detailSheetTitle === '屏幕方向' ||
                this.detailSheetTitle === '标题栏模式' ||
                this.detailSheetTitle === '标题栏图标样式' ||
                this.detailSheetTitle === '顶栏模糊样式' ||
                this.detailSheetTitle === '底栏模糊样式' ||
                this.detailSheetTitle === '工具栏样式' ||
                this.detailSheetTitle === '调色板风格' ||
                this.detailSheetTitle === '菜单颜色来源' ||
                this.detailSheetTitle === '种子色' ||
                this.detailSheetTitle === '菜单背景颜色' ||
                this.detailSheetTitle === '菜单容器颜色' ||
                this.detailSheetTitle === '菜单强调颜色' ||
                this.detailSheetTitle === '菜单栏边框颜色' ||
                this.detailSheetTitle === '菜单文字颜色' ||
                this.detailSheetTitle === '菜单模糊颜色' ||
                this.detailSheetTitle === '显示模式' ||
                this.detailSheetTitle === '正文排版' ||
                this.detailInfoSlot !== undefined
                ? '选择后立即应用并保存；自定义内容需点击保存。' : '仅展示选择预览，不保存设置。')
                .fontSize(10).fontColor(this.themeColorTextTertiary)
                .width('100%').textAlign(TextAlign.Center).padding(12)
            }.width('100%').padding({ left: 18, right: 18, bottom: 16 })
          }.width('100%').layoutWeight(1).scrollBar(BarState.Off)
        }
      }.width('88%').height('86%').backgroundColor('#F21A1B21').borderRadius(22)
    }.width('100%').height('100%')
  }

  private getMenuSettingsEntries(): ReaderMenuSettingsEntry[] {
    if (this.selectedMenuSettingsTab === 0) {
      return [
        { title: '工具栏样式', detail: '跟随系统 / 跟随阅读背景 / 自定义' },
        { title: '调色板风格', detail: '跟随系统颜色 / 固定风格' },
        { title: '菜单颜色来源', detail: '种子色 / 自定义颜色' },
        { title: '种子色', detail: '日间强调色 / 夜间强调色' },
        { title: '菜单背景颜色', detail: '日间与夜间背景色' },
        { title: '菜单容器颜色', detail: '日间与夜间容器色' },
        { title: '菜单强调颜色', detail: '日间与夜间强调色' },
        { title: '显示亮度调节控件', detail: '', section: true },
        { title: '显示亮度视图', detail: this.getBrightnessViewDetail() },
        { title: '亮度条位置', detail: this.getBrightnessPositionDetail() },
        { title: '菜单边框', detail: '', section: true },
        { title: '菜单栏边框', detail: '显示菜单栏边框' },
        { title: '菜单栏边框宽度', detail: '1–4 dp' },
        { title: '菜单栏边框颜色', detail: '日间 / 夜间' },
        { title: '模糊和颜色', detail: '', section: true },
        { title: '菜单模糊半径', detail: '0–32 dp' },
        { title: '菜单模糊透明度', detail: '0–100%' },
        { title: '菜单文字颜色', detail: '日间 / 夜间' },
        { title: '菜单模糊颜色', detail: '日间 / 夜间' },
        { title: '悬浮图标设置', detail: '', section: true },
        { title: '显示标题栏图标', detail: '显示/隐藏悬浮操作图标' },
        { title: '标题栏悬浮图标配置', detail: '图标内容与显示位置' },
        { title: '标题栏悬浮图标位置', detail: '顶栏左侧 / 右侧 / 底栏左侧 / 右侧' },
        { title: '悬浮图标液态玻璃按钮', detail: '开 / 关' }
      ];
    }
    if (this.selectedMenuSettingsTab === 1) {
      return [
        { title: '底栏按钮配置', detail: '排序、显示与长按动作' },
        { title: '底栏布局', detail: '', section: true },
        { title: '底栏圆角', detail: '设置底栏卡片圆角' },
        { title: '底栏悬浮', detail: '悬浮显示与位置' },
        { title: '底栏模糊', detail: '开关雾化背景' },
        { title: '底栏模糊样式', detail: '纯色 / 渐变' },
        { title: '底栏模糊透明度', detail: '调整背景透明程度' },
        { title: '底栏液态玻璃', detail: '悬浮底栏背景效果' },
        { title: '底栏按钮液态玻璃', detail: '按钮表面效果' }
      ];
    }
    return [
      { title: '标题栏胶囊', detail: '合并标题与章节信息' },
      { title: '标题栏模式', detail: '标题与正文信息展示' },
      { title: '标题栏操作按钮', detail: '按钮配置与排序' },
      { title: '标题栏紧凑', detail: '开 / 关' },
      { title: '标题栏图标样式', detail: '纯色 / 色调 / 描边' },
        { title: '顶栏模糊', detail: '开启 / 关闭' },
        { title: '顶栏模糊样式', detail: '纯色 / 渐变' },
        { title: '顶栏液态玻璃按钮', detail: '开 / 关' },
      { title: '合并标题栏按钮', detail: '开 / 关' }
    ];
  }

  private getBottomActionLabel(id: string): string {
    const option = READER_ACTION_OPTIONS.find((item: ReaderActionOption) => item.id === id);
    return option?.label ?? id;
  }

  private getBottomActionOption(id: string): ReaderActionOption | undefined {
    return READER_ACTION_OPTIONS.find((item: ReaderActionOption) => item.id === id);
  }

  private moveBottomAction(index: number, delta: number): void {
    const target = index + delta;
    if (target < 0 || target >= this.draftBottomActions.length) { return; }
    const updated = this.draftBottomActions.map(
      (item: ReaderBottomActionConfig): ReaderBottomActionConfig => ({ id: item.id, enabled: item.enabled })
    );
    const current = updated[index];
    const neighbor = updated[target];
    if (current === undefined || neighbor === undefined) { return; }
    updated[index] = neighbor;
    updated[target] = current;
    this.draftBottomActions = updated;
  }

  private toggleBottomAction(id: string, enabled: boolean): void {
    this.draftBottomActions = this.draftBottomActions.map((item: ReaderBottomActionConfig): ReaderBottomActionConfig => ({
      id: item.id,
      enabled: item.id === id ? enabled : item.enabled
    }));
  }

  private getTopActionLabel(id: string): string {
    return this.getBottomActionLabel(id);
  }

  private moveTopAction(index: number, delta: number): void {
    const target = index + delta;
    if (target < 0 || target >= this.draftTopActions.length) { return; }
    const updated = this.draftTopActions.map(
      (item: ReaderBottomActionConfig): ReaderBottomActionConfig => ({ id: item.id, enabled: item.enabled })
    );
    const current = updated[index];
    const neighbor = updated[target];
    if (current === undefined || neighbor === undefined) { return; }
    updated[index] = neighbor;
    updated[target] = current;
    this.draftTopActions = updated;
  }

  private toggleTopAction(id: string, enabled: boolean): void {
    this.draftTopActions = this.draftTopActions.map((item: ReaderBottomActionConfig): ReaderBottomActionConfig => ({
      id: item.id,
      enabled: item.id === id ? enabled : item.enabled
    }));
  }

  @Builder
  private bottomActionConfigurationSheet() {
    Stack({ alignContent: Alignment.Bottom }) {
      Column().width('100%').height('100%').backgroundColor('#99000000')
        .onClick(() => this.bottomActionConfigVisible = false)
      Column() {
        Row().width(32).height(4).backgroundColor('#C5C6CD').borderRadius(4).margin({ top: 10, bottom: 14 })
        Row() {
          Text('底栏按钮配置').fontSize(17).fontColor('#E5E6EB').layoutWeight(1)
          Text('取消').fontSize(13).fontColor('#C7C9D1').margin({ right: 18 })
            .onClick(() => this.bottomActionConfigVisible = false)
          Text('保存').fontSize(13).fontColor('#C6D3FF')
            .onClick(() => {
              this.onBottomActionsChange(this.draftBottomActions.map(
                (item: ReaderBottomActionConfig): ReaderBottomActionConfig => ({ id: item.id, enabled: item.enabled })
              ));
              this.bottomActionConfigVisible = false;
            })
        }.width('100%').padding({ left: 18, right: 18, bottom: 12 })
        Scroll() {
          Column() {
            ForEach(this.draftBottomActions, (item: ReaderBottomActionConfig, index: number) => {
              Row() {
                this.BottomActionConfigIcon(item.id, item.enabled)
                Column() {
                  Text(this.getBottomActionLabel(item.id)).fontSize(14)
                    .fontColor(item.enabled ? '#E5E6EB' : '#777984')
                  if (this.getBottomActionOption(item.id)?.scopeLabel) {
                    Text(this.getBottomActionOption(item.id)?.scopeLabel ?? '')
                      .fontSize(10).fontColor(this.themeColorTextTertiary).margin({ top: 2 })
                  }
                  if (this.getBottomActionOption(item.id)?.migrated === false) {
                    Text('未迁移').fontSize(10).fontColor(this.themeColorTextTertiary).margin({ top: 2 })
                  }
                }.layoutWeight(1).alignItems(HorizontalAlign.Start)
                Stack({ alignContent: Alignment.Center }) {
                  Image(item.enabled ? $r('app.media.app_visibility') : $r('app.media.reader_visibility_off'))
                    .width(20).height(20).fillColor(item.enabled ? '#D5C2C6' : '#777984')
                }.width(36).height(36).borderRadius(18).backgroundColor('#292A31')
                  .onClick(() => this.toggleBottomAction(item.id, !item.enabled))
                Column() {
                  Image($r('app.media.reader_reorder_up')).width(16).height(16)
                    .fillColor(index === 0 ? '#555761' : '#B9BBC4')
                    .onClick(() => this.moveBottomAction(index, -1))
                  Image($r('app.media.reader_reorder_down')).width(16).height(16)
                    .fillColor(index === this.draftBottomActions.length - 1 ? '#555761' : '#B9BBC4')
                    .onClick(() => this.moveBottomAction(index, 1))
                }.width(24).height(36).justifyContent(FlexAlign.SpaceBetween).margin({ left: 4 })
                Stack({ alignContent: Alignment.Center }) {
                  Image($r('app.media.reader_drag_handle')).width(20).height(20).fillColor('#B9BBC4')
                }.width(32).height(36)
              }.width('100%').padding({ left: 14, right: 14, top: 8, bottom: 8 })
                .backgroundColor('#202127').borderRadius(12).margin({ bottom: 8 })
            }, (item: ReaderBottomActionConfig) => item.id)
          }.width('100%').padding({ left: 14, right: 14, bottom: 12 })
        }.width('100%').layoutWeight(1).scrollBar(BarState.Off)
      }.width('100%').height('62%').backgroundColor('#D91A1B21')
        .borderRadius({ topLeft: 24, topRight: 24 })
    }.width('100%').height('100%')
  }

  @Builder
  private BottomActionConfigIcon(id: string, enabled: boolean) {
    if (id === 'search') {
      Image($r('app.media.reader_search')).width(20).height(20).fillColor(enabled ? '#D5C2C6' : '#777984').margin({ right: 12 })
    } else if (id === 'autoPage') {
      Image($r('app.media.reader_play')).width(20).height(20).fillColor(enabled ? '#D5C2C6' : '#777984').margin({ right: 12 })
    } else if (id === 'catalog') {
      Image($r('app.media.reader_toc')).width(20).height(20).fillColor(enabled ? '#D5C2C6' : '#777984').margin({ right: 12 })
    } else if (id === 'voice') {
      Image($r('app.media.reader_voice')).width(20).height(20).fillColor(enabled ? '#D5C2C6' : '#777984').margin({ right: 12 })
    } else if (id === 'settings') {
      Image($r('app.media.reader_settings')).width(20).height(20).fillColor(enabled ? '#D5C2C6' : '#777984').margin({ right: 12 })
    } else if (id === 'addBookmark') {
      Image($r('app.media.app_bookmark')).width(20).height(20).fillColor(enabled ? '#D5C2C6' : '#777984').margin({ right: 12 })
    } else if (id === 'theme') {
      Image($r('app.media.app_daynight')).width(20).height(20).fillColor(enabled ? '#D5C2C6' : '#777984').margin({ right: 12 })
    } else if (id === 'eye_protection') {
      Image($r('app.media.app_visibility')).width(20).height(20).fillColor(enabled ? '#D5C2C6' : '#777984').margin({ right: 12 })
    } else if (id === 'prev_chapter') {
      Image($r('app.media.app_previous')).width(20).height(20).fillColor(enabled ? '#D5C2C6' : '#777984').margin({ right: 12 })
    } else if (id === 'next_chapter') {
      Image($r('app.media.reader_arrow_forward')).width(20).height(20).fillColor(enabled ? '#D5C2C6' : '#777984').margin({ right: 12 })
    } else if (id === 'replace' || id === 'replace_badge') {
      Image($r('app.media.profile_find_replace')).width(20).height(20).fillColor(enabled ? '#D5C2C6' : '#777984').margin({ right: 12 })
    } else if (id === 'translate' || id === 'charset') {
      Image($r('app.media.reader_translate')).width(20).height(20).fillColor(enabled ? '#D5C2C6' : '#777984').margin({ right: 12 })
    } else if (id === 'refresh_current' || id === 'refresh') {
      Image($r('app.media.app_refresh')).width(20).height(20).fillColor(enabled ? '#D5C2C6' : '#777984').margin({ right: 12 })
    } else if (id === 'change_source') {
      Image($r('app.media.app_swap')).width(20).height(20).fillColor(enabled ? '#D5C2C6' : '#777984').margin({ right: 12 })
    } else if (id === 'download' || id === 'audio_download') {
      Image($r('app.media.app_download')).width(20).height(20).fillColor(enabled ? '#D5C2C6' : '#777984').margin({ right: 12 })
    } else if (id === 'toc_rule') {
      Image($r('app.media.profile_rule')).width(20).height(20).fillColor(enabled ? '#D5C2C6' : '#777984').margin({ right: 12 })
    } else if (id === 'source_custom_button' || id === 'more_actions') {
      Image($r('app.media.reader_more')).width(20).height(20).fillColor(enabled ? '#D5C2C6' : '#777984').margin({ right: 12 })
    } else if (id === 'ai_summary' || id === 'ai_cast') {
      Image($r('app.media.profile_auto_awesome')).width(20).height(20).fillColor(enabled ? '#D5C2C6' : '#777984').margin({ right: 12 })
    } else if (id === 'ai_rewrite') {
      Image($r('app.media.app_edit')).width(20).height(20).fillColor(enabled ? '#D5C2C6' : '#777984').margin({ right: 12 })
    } else if (id === 'multi_role_read' || id === 'multi_role_cast') {
      Image($r('app.media.app_group')).width(20).height(20).fillColor(enabled ? '#D5C2C6' : '#777984').margin({ right: 12 })
    } else if (id === 'cast_table') {
      Image($r('app.media.app_list')).width(20).height(20).fillColor(enabled ? '#D5C2C6' : '#777984').margin({ right: 12 })
    } else {
      Image($r('app.media.reader_more')).width(20).height(20).fillColor(enabled ? '#D5C2C6' : '#777984').margin({ right: 12 })
    }
  }

  /** 关闭按钮配置面板：顶栏操作按钮与浮动图标共用一个 sheet，两个标志一起复位。 */
  private closeButtonConfigSheet(): void {
    this.topActionConfigVisible = false;
    this.floatingIconConfigVisible = false;
  }

  @Builder
  private topActionConfigurationSheet() {
    Stack({ alignContent: Alignment.Bottom }) {
      Column().width('100%').height('100%').backgroundColor('#99000000')
        .onClick(() => this.closeButtonConfigSheet())
      Column() {
        Row().width(32).height(4).backgroundColor('#C5C6CD').borderRadius(4).margin({ top: 10, bottom: 14 })
        Row() {
          // 同一个 sheet 服务两个入口：顶栏操作按钮与浮动图标（上游 FloatingBarIconConfigSheet
          // 同样复用 ButtonIconConfigSheet，只换标题与保存目标）。
          Text(this.floatingIconConfigVisible ? '浮动图标' : '顶栏按钮配置')
            .fontSize(17).fontColor('#E5E6EB').layoutWeight(1)
          Text('取消').fontSize(13).fontColor('#C7C9D1').margin({ right: 18 })
            .onClick(() => this.closeButtonConfigSheet())
          Text('保存').fontSize(13).fontColor('#C6D3FF')
            .onClick(() => {
              const saved = this.draftTopActions.map(
                (item: ReaderBottomActionConfig): ReaderBottomActionConfig => ({ id: item.id, enabled: item.enabled })
              );
              if (this.floatingIconConfigVisible) {
                this.onFloatingIconsChange(saved);
              } else {
                this.onTopActionsChange(saved);
              }
              this.closeButtonConfigSheet();
            })
        }.width('100%').padding({ left: 18, right: 18, bottom: 12 })
        Scroll() {
          Column() {
          ForEach(this.draftTopActions, (item: ReaderBottomActionConfig, index: number) => {
            Row() {
              this.BottomActionConfigIcon(item.id, item.enabled)
              Column() {
                Text(this.getTopActionLabel(item.id)).fontSize(14)
                  .fontColor(item.enabled ? '#E5E6EB' : '#777984')
                if (this.getBottomActionOption(item.id)?.scopeLabel) {
                  Text(this.getBottomActionOption(item.id)?.scopeLabel ?? '')
                    .fontSize(10).fontColor(this.themeColorTextTertiary).margin({ top: 2 })
                }
                if (this.getBottomActionOption(item.id)?.migrated === false) {
                  Text('未迁移').fontSize(10).fontColor(this.themeColorTextTertiary).margin({ top: 2 })
                }
              }.layoutWeight(1).alignItems(HorizontalAlign.Start)
              Stack({ alignContent: Alignment.Center }) {
                Image(item.enabled ? $r('app.media.app_visibility') : $r('app.media.reader_visibility_off'))
                  .width(20).height(20).fillColor(item.enabled ? '#D5C2C6' : '#777984')
              }.width(36).height(36).borderRadius(18).backgroundColor('#292A31')
                .onClick(() => this.toggleTopAction(item.id, !item.enabled))
              Column() {
                Image($r('app.media.reader_reorder_up')).width(16).height(16)
                  .fillColor(index === 0 ? '#555761' : '#B9BBC4')
                  .onClick(() => this.moveTopAction(index, -1))
                Image($r('app.media.reader_reorder_down')).width(16).height(16)
                  .fillColor(index === this.draftTopActions.length - 1 ? '#555761' : '#B9BBC4')
                  .onClick(() => this.moveTopAction(index, 1))
              }.width(24).height(36).justifyContent(FlexAlign.SpaceBetween).margin({ left: 4 })
              Image($r('app.media.reader_drag_handle')).width(20).height(20).fillColor('#B9BBC4')
                .width(32).height(36).margin({ left: 4 })
            }.width('100%').padding({ left: 14, right: 14, top: 8, bottom: 8 })
              .backgroundColor('#202127').borderRadius(12).margin({ bottom: 8 })
          }, (item: ReaderBottomActionConfig) => item.id)
          }.width('100%').padding({ left: 14, right: 14, bottom: 12 })
        }.width('100%').layoutWeight(1).scrollBar(BarState.Off)
      }.width('100%').height('62%').backgroundColor('#D91A1B21')
        .borderRadius({ topLeft: 24, topRight: 24 })
    }.width('100%').height('100%')
  }

  build() {
    if (this.asSheet) {
      Stack({ alignContent: this.selectedSettingsTab === 2 ? Alignment.Center : Alignment.Bottom }) {
        Column().width('100%').height('100%').backgroundColor('#88000000').onClick(() => this.onBack())
        Column() {
          this.settingsContent(true)
        }.width(this.settingsSheetWidth()).height(this.settingsSheetHeight()).alignSelf(ItemAlign.Center)
          .backgroundColor('#D91A1B21').borderRadius(22)
          .margin({ left: 8, right: 8, bottom: this.selectedSettingsTab === 2 ? 0 : 16 })
          .offset({ x: 0, y: this.selectedSettingsTab === 2 ? -18 : 0 })
        if (this.bottomActionConfigVisible) {
          this.bottomActionConfigurationSheet()
        }
        if (this.topActionConfigVisible || this.floatingIconConfigVisible) {
          this.topActionConfigurationSheet()
        }
        if (this.detailSheetVisible) {
          this.detailSheet()
        }
      }.width('100%').height('100%')
    } else {
      Stack({ alignContent: Alignment.Center }) {
        Column() {
          this.settingsContent(false)
        }.width('100%').height('100%')
        if (this.bottomActionConfigVisible) {
          this.bottomActionConfigurationSheet()
        }
        if (this.topActionConfigVisible || this.floatingIconConfigVisible) {
          this.topActionConfigurationSheet()
        }
        if (this.detailSheetVisible) {
          this.detailSheet()
        }
      }.width('100%').height('100%')
    }
  }
}

@Component
struct BackgroundShareOption {
  @StorageProp('themeColorAccent') themeColorAccent: string = '#3F5BD9';
  @Prop selected: boolean = false;

  build() {
    Column() {
      Image($r('app.media.menu_grid')).width(20).height(20).fillColor('#E4E5EA')
    }.width(40).height(56).justifyContent(FlexAlign.Center)
      .backgroundColor(this.selected ? '#34394C' : '#15161B')
      .borderRadius(9)
      .border({ width: this.selected ? 2 : 1, color: this.selected ? this.themeColorAccent : '#33343C' })
  }
}

/** 样式行末尾的纯动作卡：「+」新增样式与「>」进主题列表，两者都不代表某个具体样式。 */
@Component
struct BackgroundStyleActionCard {
  @StorageProp('themeColorAccent') themeColorAccent: string = '#3F5BD9';
  @Prop icon: Resource = $r('app.media.app_add');
  @Prop selected: boolean = false;

  build() {
    Column() {
      Image(this.icon).width(18).height(18).fillColor('#E4E5EA')
    }.width(40).height(56).justifyContent(FlexAlign.Center)
      .backgroundColor('#15161B')
      .borderRadius(9)
      .border({ width: 1, color: '#33343C' })
  }
}

@Component
struct MenuSettingIconStyle {
  @Prop value: number = 1;
  onChange: (style: number) => void = (_style: number) => {};

  build() {
    Column() {
      Text('底栏图标样式').fontSize(13).fontColor('#E2E3E8').width('100%').margin({ bottom: 10 })
      Row() {
        ForEach(['纯色', '色调', '描边'], (label: string, index: number) => {
          Text(label).fontSize(11).fontColor(this.value === index ? '#ECECF0' : '#B7B8C1')
            .layoutWeight(1).textAlign(TextAlign.Center)
            .backgroundColor(this.value === index ? '#454B62' : '#15161B')
            .borderRadius(11).padding(9).margin({ left: index === 0 ? 0 : 6 })
            .onClick(() => this.onChange(index))
        }, (label: string) => label)
      }.width('100%')
    }.width('100%').padding(12).backgroundColor('#202127').borderRadius(12)
  }
}

@Component
struct MenuSettingSlider {
  @StorageProp('themeColorAccent') themeColorAccent: string = '#3F5BD9';
  @Prop title: string = '';
  @Prop value: number = 5;
  @Prop minValue: number = 1;
  @Prop maxValue: number = 8;
  @Prop stepValue: number = 1;
  onChange: (value: number) => void = (_value: number) => {};

  build() {
    Column() {
      Row() {
        Text(this.title).fontSize(13).fontColor('#E2E3E8').layoutWeight(1)
        Text(`${this.value}`).fontSize(12).fontColor('#D3D4DC')
      }.width('100%')
      Slider({ value: this.value, min: this.minValue, max: this.maxValue, step: this.stepValue, style: SliderStyle.InSet })
        .width('100%').selectedColor(this.themeColorAccent).trackColor('#454751').blockColor(this.themeColorAccent)
        .showSteps(true).stepColor(this.themeColorAccent).stepSize(3)
        // 拖动期把「滑块正在拖」广播到 AppStorage，阅读页据此把顶栏/底栏压到 30% 以下，
        // 让用户能看见背后正文的实时变化（上游 `TinySettingItems.kt:349-356` 的
        // `LocalSliderDragState.startDragging/stopDragging` 同口径）。
        .onTouch((event: TouchEvent) => {
          if (event.type === TouchType.Down) {
            AppStorage.setOrCreate('readerMenuSliderDragging', true);
          } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
            AppStorage.setOrCreate('readerMenuSliderDragging', false);
          }
        })
        .onChange((value: number, mode: SliderChangeMode) => {
          if (mode === SliderChangeMode.Moving || mode === SliderChangeMode.Click || mode === SliderChangeMode.End) {
            this.onChange(Math.max(this.minValue, Math.min(this.maxValue, Math.round(value))));
          }
        })
    }.width('100%').padding(12).backgroundColor('#202127').borderRadius(12)
  }
}

@Component
struct MenuSettingChoice {
  @Prop title: string = '';
  @Prop value: string = 'page';
  onChange: (value: string) => void = (_value: string) => {};

  build() {
    Column() {
      Text(this.title).fontSize(13).fontColor('#E2E3E8').width('100%').margin({ bottom: 10 })
      Row() {
        Text('页码').fontSize(11).fontColor(this.value === 'page' ? '#ECECF0' : '#B7B8C1')
          .layoutWeight(1).textAlign(TextAlign.Center)
          .backgroundColor(this.value === 'page' ? '#454B62' : '#15161B')
          .borderRadius(11).padding(9).onClick(() => this.onChange('page'))
        Text('章节').fontSize(11).fontColor(this.value === 'chapter' ? '#ECECF0' : '#B7B8C1')
          .layoutWeight(1).textAlign(TextAlign.Center)
          .backgroundColor(this.value === 'chapter' ? '#454B62' : '#15161B')
          .borderRadius(11).padding(9).margin({ left: 8 }).onClick(() => this.onChange('chapter'))
      }.width('100%')
    }.width('100%').padding(12).backgroundColor('#202127').borderRadius(12)
  }
}

@Component
struct MenuSettingSwitch {
  @Prop title: string = '';
  @Prop detail: string = '';
  @Prop checked: boolean = false;
  onChange: (enabled: boolean) => void = (_enabled: boolean) => {};

  build() {
    Row() {
      Column() {
        Text(this.title).fontSize(13).fontColor('#E2E3E8')
        Text(this.detail).fontSize(10).fontColor('#9A9CA5').margin({ top: 4 })
      }.alignItems(HorizontalAlign.Start).layoutWeight(1)
      Toggle({ type: ToggleType.Switch, isOn: this.checked })
        .onChange((enabled: boolean) => this.onChange(enabled))
    }.width('100%').padding(12).backgroundColor('#202127').borderRadius(12)
  }
}

@Component
struct MenuSettingPalette {
  @StorageProp('themeColorAccent') themeColorAccent: string = '#3F5BD9';
  @Prop title: string = '';
  @Prop colors: string[] = [];
  @Prop selectedColor: string = '';
  onChange: (color: string) => void = (_color: string) => {};

  build() {
    Column() {
      Row() {
        Text(this.title).fontSize(13).fontColor('#E2E3E8').layoutWeight(1)
        Text(this.selectedColor).fontSize(10).fontColor('#AEB0B9')
      }.width('100%').margin({ bottom: 10 })
      Row() {
        ForEach(this.colors, (color: string) => {
          Stack({ alignContent: Alignment.Center }) {
            Circle().width(27).height(27).fill(color)
            if (this.selectedColor.toUpperCase() === color.toUpperCase()) {
              Circle().width(33).height(33).fill(Color.Transparent)
                .stroke(this.themeColorAccent).strokeWidth(2)
            }
          }.width(38).height(38).onClick(() => this.onChange(color))
        }, (color: string) => color)
      }.width('100%').justifyContent(FlexAlign.SpaceBetween)
    }.width('100%').padding(12).backgroundColor('#202127').borderRadius(12)
  }
}

@Component
struct MenuSettingSection {
  @StorageProp('themeColorAccent') themeColorAccent: string = '#3F5BD9';
  @Prop title: string = '';

  build() {
    Text(this.title).fontSize(12).fontColor(this.themeColorAccent).width('100%')
      .padding({ left: 4, top: 10, bottom: 4 })
  }
}

@Component
struct MenuSettingSegments {
  @Prop title: string = '';
  @Prop choices: string[] = [];
  @Prop selectedIndex: number = 0;
  onSelect: (index: number) => void = (_index: number) => {};

  build() {
    Row() {
      Text(this.title).fontSize(13).fontColor('#E2E3E8').layoutWeight(1).maxLines(1)
      Text(this.choices[this.selectedIndex] ?? this.choices[0] ?? '')
        .fontSize(11).fontColor('#D3D4DC').padding({ left: 10, right: 10, top: 6, bottom: 6 })
        .backgroundColor('#292A31').borderRadius(8)
      Text('⌄').fontSize(15).fontColor('#A7A9B3').margin({ left: 4 })
    }.width('100%').height(46).padding(8).backgroundColor('#202127').borderRadius(12)
      .onClick(() => this.onSelect(this.selectedIndex))
  }
}

@Component
struct ReaderInfoSettingRow {
  @Prop iconKind: number = 0;
  @Prop title: string = '';
  @Prop choices: string[] = [];
  @Prop selectedIndex: number = 0;
  onSelect: (index: number) => void = (_index: number) => {};

  build() {
    Row() {
      if (this.iconKind === 0) {
        Image($r('app.media.reader_info_heading')).width(20).height(20).fillColor('#D9DAE0').margin({ right: 14 })
      } else if (this.iconKind === 1) {
        Image($r('app.media.reader_info_align_left')).width(20).height(20).fillColor('#D9DAE0').margin({ right: 14 })
      } else if (this.iconKind === 2) {
        Image($r('app.media.reader_info_align_center')).width(20).height(20).fillColor('#D9DAE0').margin({ right: 14 })
      } else {
        Image($r('app.media.reader_info_align_right')).width(20).height(20).fillColor('#D9DAE0').margin({ right: 14 })
      }
      Text(this.title).fontSize(13).fontColor('#E2E3E8').layoutWeight(1).maxLines(1)
      Text(this.choices[this.selectedIndex] ?? this.choices[0] ?? '')
        .fontSize(11).fontColor('#D3D4DC').padding({ left: 10, right: 10, top: 6, bottom: 6 })
        .backgroundColor('#292A31').borderRadius(8)
      Text('⌄').fontSize(15).fontColor('#A7A9B3').margin({ left: 4 })
    }.width('100%').height(50).padding(10).backgroundColor('#202127').borderRadius(12)
      .onClick(() => this.onSelect(this.selectedIndex))
  }
}

@Component
struct ReaderInfoColorRow {
  @Prop iconKind: number = 4;
  @Prop title: string = '';
  @Prop detail: string = '';

  build() {
    Row() {
      if (this.iconKind === 4) {
        Image($r('app.media.reader_info_palette')).width(20).height(20).fillColor('#D9DAE0').margin({ right: 14 })
      } else {
        Image($r('app.media.reader_info_color_text')).width(20).height(20).fillColor('#D9DAE0').margin({ right: 14 })
      }
      Column() {
        Text(this.title).fontSize(13).fontColor('#E2E3E8')
        Text(this.detail).fontSize(10).fontColor('#9A9CA5').margin({ top: 4 })
      }.alignItems(HorizontalAlign.Start).layoutWeight(1)
      Row() {
        Column().width(22).height(22).backgroundColor('#E6E1E7').borderRadius(11)
        Column().width(22).height(22).backgroundColor('#3D3D46').borderRadius(11).margin({ left: 5 })
      }
      Text('›').fontSize(20).fontColor('#A7A9B3').margin({ left: 8 })
    }.width('100%').padding(10).backgroundColor('#202127').borderRadius(12)
  }
}

@Component
struct ReaderInfoSwitchRow {
  @Prop title: string = '';
  @Prop detail: string = '';
  @Prop checked: boolean = false;
  onChange: (enabled: boolean) => void = (_enabled: boolean) => {};

  build() {
    Row() {
      Image($r('app.media.reader_info_minimize')).width(20).height(20).fillColor('#D9DAE0').margin({ right: 14 })
      Column() {
        Text(this.title).fontSize(13).fontColor('#E2E3E8')
        Text(this.detail).fontSize(10).fontColor('#9A9CA5').margin({ top: 4 })
      }.alignItems(HorizontalAlign.Start).layoutWeight(1)
      Toggle({ type: ToggleType.Switch, isOn: this.checked })
        .onChange((enabled: boolean) => this.onChange(enabled))
    }.width('100%').padding(10).backgroundColor('#202127').borderRadius(12)
  }
}

@Component
struct ReaderInfoOptionRow {
  @Prop iconKind: number = 5;
  @Prop title: string = '';
  @Prop detail: string = '';

  build() {
    Row() {
      Image($r('app.media.reader_info_text_fields')).width(20).height(20).fillColor('#D9DAE0').margin({ right: 14 })
      Column() {
        Text(this.title).fontSize(13).fontColor('#E2E3E8')
        Text(this.detail).fontSize(10).fontColor('#9A9CA5').margin({ top: 4 })
      }.alignItems(HorizontalAlign.Start).layoutWeight(1)
      Text('›').fontSize(20).fontColor('#A7A9B3')
    }.width('100%').padding(10).backgroundColor('#202127').borderRadius(12)
  }
}

@Component
struct ReaderInfoSliderRow {
  @StorageProp('themeColorAccent') themeColorAccent: string = '#3F5BD9';
  @Prop iconKind: number = 6;
  @Prop title: string = '';
  @Prop value: number = 16;
  @Prop minValue: number = 0;
  @Prop maxValue: number = 100;
  onChange: (value: number) => void = (_value: number) => {};

  build() {
    Column() {
      Row() {
        Image($r('app.media.reader_info_format_size')).width(20).height(20).fillColor('#D9DAE0').margin({ right: 14 })
        Text(this.title).fontSize(13).fontColor('#E2E3E8').layoutWeight(1)
        Text(`${this.value}`).fontSize(12).fontColor('#D3D4DC')
      }.width('100%')
      Slider({ value: this.value, min: this.minValue, max: this.maxValue, step: 1, style: SliderStyle.InSet })
        .width('100%').selectedColor(this.themeColorAccent).trackColor('#454751').blockColor(this.themeColorAccent)
        .onChange((value: number, mode: SliderChangeMode) => {
          if (mode === SliderChangeMode.Moving || mode === SliderChangeMode.Click || mode === SliderChangeMode.End) {
            this.onChange(Math.max(this.minValue, Math.min(this.maxValue, Math.round(value))));
          }
        })
    }.width('100%').padding(10).backgroundColor('#202127').borderRadius(12)
  }
}

@Component
struct MenuSettingColor {
  @Prop title: string = '';
  @Prop detail: string = '';
  /** 日间色；空串表示上游「0 = 未设置」，显示成占位灰。 */
  @Prop dayColor: string = '';
  /** 夜间色；空串同上。 */
  @Prop nightColor: string = '';

  build() {
    Row() {
      Column() {
        Text(this.title).fontSize(13).fontColor('#E2E3E8')
        Text(this.detail).fontSize(10).fontColor('#9A9CA5').margin({ top: 4 })
      }.alignItems(HorizontalAlign.Start).layoutWeight(1)
      Row() {
        Column().width(22).height(22)
          .backgroundColor(this.dayColor.length > 0 ? this.dayColor : '#3D3D46')
          .border({ width: this.dayColor.length > 0 ? 0 : 1, color: '#5A5C66' })
          .borderRadius(11)
        Column().width(22).height(22)
          .backgroundColor(this.nightColor.length > 0 ? this.nightColor : '#E6E1E7')
          .border({ width: this.nightColor.length > 0 ? 0 : 1, color: '#5A5C66' })
          .borderRadius(11).margin({ left: 5 })
      }
      Text('›').fontSize(20).fontColor('#A7A9B3').margin({ left: 8 })
    }.width('100%').padding(12).backgroundColor('#202127').borderRadius(12)
  }
}

@Component
struct MenuSettingOption {
  @Prop title: string = '';
  @Prop detail: string = '';
  @Prop migrated: boolean = false;

  build() {
    Row() {
      Column() {
        Text(this.title).fontSize(13).fontColor('#E2E3E8')
        Text(this.detail).fontSize(10).fontColor('#9A9CA5').margin({ top: 4 })
      }.alignItems(HorizontalAlign.Start).layoutWeight(1)
      if (!this.migrated) {
        Text('尚未迁移').fontSize(9).fontColor('#898B95').margin({ right: 8 })
      }
      Text('›').fontSize(20).fontColor('#A7A9B3')
    }.width('100%').padding(12).backgroundColor('#202127').borderRadius(12)
  }
}

@Component
struct BackgroundOption {
  @StorageProp('themeColorAccent') themeColorAccent: string = '#3F5BD9';
  @Prop label: string = '';
  @Prop color: string = '#000000';
  @Prop selected: boolean = false;

  build() {
    // 选中态对齐上游 `StyleCard`（GlobalThemePage.kt:540-560）：不是卡片下方挂个勾，
    // 而是底部一条满宽横带，勾画在横带里。横带用 secondaryContainer 色、勾用 onSecondaryContainer。
    Column() {
      Stack({ alignContent: Alignment.Center }) {
        Text(this.label).fontSize(10).maxLines(2).textAlign(TextAlign.Center)
          .fontColor(this.color.toLowerCase() === '#000000' || this.color.toLowerCase() === '#3c3f43'
            ? '#E4E5EA' : '#585963')
          .padding({ left: 2, right: 2 })
      }.width('100%').layoutWeight(1)
      if (this.selected) {
        Column() {
          Image($r('app.media.app_check')).width(10).height(10).fillColor('#1B1D25')
        }.width('100%').height(12).justifyContent(FlexAlign.Center)
          .backgroundColor('#C6D3FF')
      }
    }.width(44).height(56).justifyContent(FlexAlign.Center).backgroundColor(this.color)
      .borderRadius(11).clip(true)
      .border({ width: this.selected ? 2 : 1, color: this.selected ? this.themeColorAccent : '#33343C' })
  }
}
