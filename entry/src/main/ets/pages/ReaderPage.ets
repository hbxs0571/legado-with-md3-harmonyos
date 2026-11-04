import { Book } from '../model/Book';
import { ReaderBookmark } from '../model/ReaderBookmark';
import { ReaderMarking, ReaderMarkingEffect } from '../model/ReaderMarking';
import { ReaderHighlightRule, ReaderHighlightRange } from '../model/ReaderHighlightRule';
import { ReaderHighlightRuleEngine } from '../data/ReaderHighlightRuleEngine';
import { ReaderHighlightRuleRepository } from '../data/ReaderHighlightRuleRepository';
import { ReaderHaptics } from '../data/ReaderHaptics';
import { ReaderHighlightRuleSheet } from './ReaderHighlightRuleSheet';
import { ReplaceRule } from '../model/ReplaceRule';
import { ReplaceRuleRepository } from '../data/ReplaceRuleRepository';
import { BookRepository } from '../data/BookRepository';
import { BookContentProcessRepository } from '../data/BookContentProcessRepository';
import { BookContentProcess } from '../model/BookContentProcess';
import { ReaderFontRepository } from '../data/ReaderFontRepository';
import { LocalSemanticDocument, LocalTextSemantics } from '../data/LocalTextSemantics';
import { ReaderTitleSegment, segmentReaderTitle } from '../data/ReaderTitleSegmentation';
import { READER_SELECTION_MENU_SUPPORTED, ReaderSelectionMenuItem, parseReaderSelectionMenuConfig } from '../data/ReaderSelectionMenu';
import { readerColumnCount } from '../data/ReaderColumnMode';
import { AppGlyph, AppGlyphName } from '../components/AppGlyph';
import { BookCover } from '../components/BookCover';
import { ReaderTextProcessingSheet } from './ReaderTextProcessingSheet';
import image from '@ohos.multimedia.image';
import { batteryInfo, pasteboard, settings } from '@kit.BasicServicesKit';
import { AnimatorResult, window } from '@kit.ArkUI';
import { LengthMetricsUnit } from '@kit.ArkUI';
import { Action, inputConsumer, KeyCode, KeyEvent } from '@kit.InputKit';
import {
  LocalReaderLine, LocalReaderLineItem, LocalReaderPage, LocalReaderPaginator, LocalReaderSizeOffset,
  LocalReaderTitleBlock, LocalReaderTitleSegment
} from './LocalReaderPaginator';
import { ReaderTextLayoutStyle } from '../reader/ReaderTextLayoutEngine';
import { ReaderCurlTouchPolicy } from '../reader/ReaderPageCurl';
import { HiddenSpan, scanHiddenSpans, toBodyOnly, toRawText } from '../reader/ReaderBodyOnlyFilter';
import {
  readerCanvasArgb, readerCanvasHandleDistance, readerCanvasHighlightDecoration,
  readerCanvasMarkingBackgroundArgb, readerCanvasMarkingDecoration, readerLengthToNumber,
  readerTextGlyphCount,
} from '../reader/ReaderCanvasStyleCodec';
import {
  ReaderCanvasDrawRequest, ReaderCanvasItemBox, ReaderCanvasLayout, ReaderCanvasMarking, ReaderCanvasPage,
  ReaderCanvasRenderer, ReaderCanvasStyle, ReaderCanvasStyleRange, ReaderCanvasTitleStyle, ReaderCanvasWindow,
  ReaderPageTransform, ReaderPageTransition,
  ReaderPageTransitionPolicy, ReaderScrollCrossing, ReaderScrollDecay, ReaderScrollPolicy, ReaderScrollResult,
  ReaderTransitionDirection, ReaderTransitionMode, ReaderTransitionTransforms,
  captureReaderDragDirection,
  readerTransitionModeFromPageAnim
} from '../reader/ReaderCanvasSurface';
import {
  ReaderBottomActionConfig, ReaderControlKind, READER_ACTION_OPTIONS, READER_LOCAL_BOTTOM_ACTION_DEFAULTS,
  READER_LOCAL_TOP_ACTION_DEFAULTS, ReaderActionOption, isReaderActionApplicable,
  ReaderInfoSettings, DEFAULT_READER_INFO_SETTINGS, ReaderPaddingSettings, DEFAULT_READER_PADDING_SETTINGS,
  ReaderSettingsRepository
} from '../data/ReaderSettingsRepository';
import {
  ReaderMoreActionConfig, READER_MORE_ACTION_DEFAULTS
} from '../data/ReaderMoreActionsRepository';
import { ReaderSearchNavItem } from '../model/ReaderSearchNav';

interface ReaderMoreAction {
  id: string;
  label: string;
  glyph: AppGlyphName;
  scopeLabel: string;
  migrated: boolean;
}

interface ReaderImageStyleOption {
  id: string;
  label: string;
}

const READER_IMAGE_STYLE_OPTIONS: ReaderImageStyleOption[] = [
  { id: 'DEFAULT', label: '默认' },
  { id: 'FULL', label: '全屏' },
  { id: 'TEXT', label: '文字嵌入' },
  { id: 'SINGLE', label: '单页' }
];

const READER_MORE_ACTIONS: ReaderMoreAction[] = [
  { id: 'source_custom_button', label: '书源自定义按钮', glyph: 'profileSource', scopeLabel: '仅支持该按钮的网络书', migrated: false },
  { id: 'change_source', label: '换源', glyph: 'swap', scopeLabel: '仅网络书', migrated: false },
  { id: 'refresh', label: '刷新', glyph: 'profileRefresh', scopeLabel: '仅网络书', migrated: false },
  { id: 'download', label: '离线缓存', glyph: 'cloudDownload', scopeLabel: '仅网络书', migrated: false },
  { id: 'audio_download', label: '听书下载', glyph: 'download', scopeLabel: '', migrated: false },
  { id: 'edit_content', label: '编辑内容', glyph: 'edit', scopeLabel: '', migrated: true },
  { id: 'add_bookmark', label: '添加书签', glyph: 'bookmark', scopeLabel: '', migrated: true },
  { id: 'text_processing', label: '文本处理', glyph: 'profileFindReplace', scopeLabel: '', migrated: true },
  { id: 'reverse_content', label: '反转内容', glyph: 'swap', scopeLabel: '', migrated: true },
  { id: 're_segment', label: '重新分段', glyph: 'list', scopeLabel: '', migrated: true },
  { id: 'del_ruby', label: '删除ruby标签', glyph: 'delete', scopeLabel: '仅EPUB', migrated: false },
  { id: 'del_h', label: '删除h标签', glyph: 'delete', scopeLabel: '仅EPUB', migrated: false },
  { id: 'toc_rule', label: 'TXT目录规则', glyph: 'profileRule', scopeLabel: '仅本地TXT', migrated: true },
  { id: 'charset', label: '设置编码', glyph: 'info', scopeLabel: '仅本地书', migrated: true },
  { id: 'image_style', label: '图片样式', glyph: 'book', scopeLabel: '', migrated: true },
  { id: 'page_anim', label: '翻页动画', glyph: 'profileSettings', scopeLabel: '', migrated: false },
  { id: 'simulated_reading', label: '模拟阅读', glyph: 'book', scopeLabel: '', migrated: false },
  { id: 'get_progress', label: '获取阅读进度', glyph: 'profileHistory', scopeLabel: '需配置阅读进度同步', migrated: false },
  { id: 'cover_progress', label: '覆盖阅读进度', glyph: 'profileHistory', scopeLabel: '需配置阅读进度同步', migrated: false },
  { id: 'highlight_rule', label: '高亮规则', glyph: 'profileRule', scopeLabel: '', migrated: true },
  { id: 'read_style', label: '阅读设置', glyph: 'profileSettings', scopeLabel: '', migrated: true },
  { id: 'bottom_button_config', label: '底栏按钮配置', glyph: 'profileSettings', scopeLabel: '', migrated: true },
  { id: 'log', label: '日志', glyph: 'info', scopeLabel: '', migrated: false }
];
const MORE_ACTION_CONFIG_ENTRY: ReaderMoreAction = {
  id: 'configure_more_actions', label: '配置更多操作', glyph: 'settings', scopeLabel: '', migrated: true
};
// 翻页动画六档，顺序与上游 GlobalThemePage.kt:353-360 的 cover/slide/simulation/scroll/fade/none 一致。
const READER_PAGE_ANIMATION_LABELS: string[] = ['覆盖', '滑动', '仿真', '滚动', '淡入淡出', '无动画'];
const READER_CHARSETS: string[] = ['UTF-8', 'GB2312', 'GB18030', 'GBK', 'Unicode', 'UTF-16', 'UTF-16LE', 'UTF-16BE', 'ASCII'];

interface ReaderContentSegment {
  kind: 'text' | 'image';
  value: string;
  startPosition: number;
}

interface ReaderIntrinsicImageSize {
  width: number;
  height: number;
}

interface ReaderBookmarkPageRange {
  start: number;
  end: number;
  text: string;
}

interface ReaderMarkingRange {
  start: number;
  end: number;
}

/**
 * 阅读页。
 *
 * 文件按四块排列，改动时先认块再找函数（行号会漂，按块名 + 函数名搜）：
 *
 * 1. **画布渲染**（`buildReaderCanvas*` / `paintReaderCanvas` / `ReaderCanvasStyleCodec`）
 *    —— 正文只由 `Canvas` 逐行绘制，绘制主体在 `reader/ReaderCanvasSurface.ets`；
 *    这里只负责把页面状态拼成 `ReaderCanvasDrawRequest`。
 * 2. **分页**（`rebuildReaderPages` / `scheduleReaderPaginationRebuild` /
 *    `calculateReaderBottomJustifyGap`）—— 尺寸驱动 + 防抖，产出 `localReaderPages`。
 * 3. **手势**（`build()` 里的 `LongPressGesture` / `PanGesture` /
 *    `startCanvasSelectionAt` / `dragCanvasSelectionTo` / `canvasHandleHit`）
 *    —— 选区坐标三口径都在这一块，见 `KNOWN-ISSUES` 的 KI-EXP3。
 * 4. **菜单**（顶栏/底栏 `@Builder`、`readerMarkingSelectionMenu`、
 *    `runSelectionMenuAction`）—— 纯 ArkUI，不进画布。
 */
@Component
export struct ReaderPage {
  /** 顶栏最多显示的动作数；上游 `ReadMenuActionDefs.kt:76` `MAX_TITLE_BAR_ACTIONS = 6`。 */
  private static readonly MAX_TITLE_BAR_ACTIONS: number = 6;
  /** 滚动模式进度刷新的节流窗口；上游 `ReadBookViewModel.kt:108` `READER_SYNC_MIN_INTERVAL_MS = 250L`。 */
  private static readonly SCROLL_PROGRESS_THROTTLE_MS: number = 250;
  @StorageProp('themeColorTextPrimary') themeColorTextPrimary: string = '#1B1C22';
  @StorageProp('themeColorTextSecondary') themeColorTextSecondary: string = '#2E3038';
  @StorageProp('themeColorTextTertiary') themeColorTextTertiary: string = '#6A6D77';
  @StorageProp('themeColorSurfacePrimary') themeColorSurfacePrimary: string = '#F5F6F8';
  @StorageProp('themeColorSurfaceSecondary') themeColorSurfaceSecondary: string = '#FFFFFF';
  @StorageProp('themeColorSurfaceElevated') themeColorSurfaceElevated: string = '#FFFFFF';
  @StorageProp('themeAppBackground') themeAppBackground: string = '';
  @StorageProp('themePureBlack') themePureBlack: boolean = false;
  @Prop @Watch('onStartAtChapterBeginningChanged') startAtChapterBeginning: boolean = false;
  @Prop @Watch('onBookChanged') book: Book = {
    id: '', title: '', author: '', category: '', lastChapter: '', progress: 0, isLocal: true
  };
  @Prop @Watch('onChapterTitleChanged') chapterTitle: string = '';
  @State @Watch('onDisplayChapterTitleChanged') displayChapterTitle: string = '';
  @Prop @Watch('onReplaceRulesChanged') replaceRules: ReplaceRule[] = [];
  @Prop @Watch('onReaderContentChanged') content: string = '';
  // 正文排版声明默认对齐上游「无数据」层 readConfig.json[0]，实例化时由 Index.ets 显式传值覆盖。
  @Prop @Watch('onPaginationInputsChanged') fontSize: number = 24;
  @Prop @Watch('onPaginationInputsChanged') paragraphSpacing: number = 6;
  @Prop @Watch('onPaginationInputsChanged') lineSpacing: number = 10;
  @Prop @Watch('onPaginationInputsChanged') letterSpacing: number = 0;
  @Prop @Watch('onPaginationInputsChanged') paragraphIndent: string = '　　';
  @Prop @Watch('onPaginationInputsChanged') textFontPath: string = '';
  @Prop @Watch('onPaginationInputsChanged') titleFontPath: string = '';
  @Prop @Watch('onPaginationInputsChanged') systemTypefaces: number = 0;
  @Prop @Watch('onPaginationInputsChanged') textItalic: boolean = false;
  @Prop @Watch('onPaginationInputsChanged') textBold: number = 0;
  // 标题排版十四个字段，对齐上游 help/config/ReadBookConfig.kt:596-608。
  // 全部进分页输入，改标题样式要重算分页（上游 titleStyle 参与排版度量）。
  @Prop @Watch('onPaginationInputsChanged') titleMode: number = 0;
  @Prop @Watch('onPaginationInputsChanged') titleSize: number = 4;
  @Prop @Watch('onPaginationInputsChanged') titleSizeRelative: boolean = true;
  @Prop @Watch('onPaginationInputsChanged') titleTopSpacing: number = 0;
  @Prop @Watch('onPaginationInputsChanged') titleBottomSpacing: number = 0;
  @Prop titleColor: string = '';
  @Prop titleColorNight: string = '';
  @Prop @Watch('onPaginationInputsChanged') titleBold: number = 500;
  @Prop @Watch('onPaginationInputsChanged') titleLineSpacingExtra: number = 12;
  @Prop @Watch('onPaginationInputsChanged') titleLineSpacingSub: number = 12;
  @Prop @Watch('onPaginationInputsChanged') titleSegType: number = 0;
  @Prop @Watch('onPaginationInputsChanged') titleSegScaling: number = 1;
  @Prop @Watch('onPaginationInputsChanged') titleSegDistance: number = 4;
  @Prop @Watch('onPaginationInputsChanged') titleSegFlag: string = '';
  @Prop textShadow: boolean = false;
  @Prop shadowRadius: number = 16;
  @Prop shadowDx: number = 1;
  @Prop shadowDy: number = 1;
  @Prop textShadowColor: string = '#3E3D3B';
  @Prop textShadowColorN: string = '#3E3D3B';
  @Prop @Watch('onReaderCanvasStyleChanged') underline: boolean = false;
  @Prop @Watch('onReaderCanvasStyleChanged') dottedLine: boolean = false;
  @Prop @Watch('onReaderCanvasStyleChanged') underlineColor: string = '#3E3D3B';
  @Prop @Watch('onReaderCanvasStyleChanged') underlineColorNight: string = '#ADADAD';
  @Prop @Watch('onReaderCanvasStyleChanged') underlineHeight: number = 1;
  // 上游 underlinePadding：默认 10，绘制时取 (值 - 10) 作相对偏移（LegacyReaderPaginationStyleFactory.kt:68）
  @Prop @Watch('onReaderCanvasStyleChanged') underlinePadding: number = 10;
  // 上游 underlineExtend：下划线是否撑满整列（ReaderPaginator.kt:449 的 extendToColumn）
  @Prop @Watch('onReaderCanvasStyleChanged') underlineExtend: boolean = false;
  // 上游 dottedBase / dottedRatio：虚线的实线段长与空隙，单位在上游是 px，本地按 vp 传给 strokeDashArray
  @Prop @Watch('onReaderCanvasStyleChanged') dottedBase: number = 6;
  @Prop @Watch('onReaderCanvasStyleChanged') dottedRatio: number = 6;
  @Prop @Watch('onReaderCanvasStyleChanged') readerNightMode: boolean = true;
  @Prop @Watch('onPaginationInputsChanged') textFullJustify: boolean = true;
  @Prop @Watch('onPaginationInputsChanged') textBottomJustify: boolean = true;
  @Prop @Watch('onProgressBehaviorChanged') progressBehavior: string = 'page';
  // 上游 readSliderMode："0" 常驻 / "1" 不显示（ReadBookMenuBarBottom.kt:161 的 AnimatedVisibility）
  @Prop readSliderMode: string = '0';
  // 上游 pageTouchSlop：0 = 用平台默认阈值（ReaderGestureSettingsPolicy.touchSlopPx）
  @Prop pageTouchSlop: number = 0;
  @Prop @Watch('onScreenOrientationChanged') screenOrientation: string = '0';
  @Prop @Watch('onKeepLightChanged') keepLight: string = '0';
  @Prop @Watch('onVolumeKeyPageChanged') volumeKeyPage: boolean = true;
  @Prop @Watch('onVolumeKeyPageChanged') keyPageOnLongPress: boolean = false;
  /** 自定义「上一页」按键，英文逗号分隔的键值串，对齐上游 prevKeys（ReadSettings.kt:60）。 */
  @Prop @Watch('onVolumeKeyPageChanged') prevKeys: string = '';
  /** 自定义「下一页」按键，对齐上游 nextKeys（ReadSettings.kt:61）。 */
  @Prop @Watch('onVolumeKeyPageChanged') nextKeys: string = '';
  /** 鼠标滚轮是否翻页，对齐上游 mouseWheelPage（ReadSettings.kt:28）。滚动模式本来靠滚轮滚动，不受此开关影响。 */
  @Prop mouseWheelPage: boolean = true;
  /** 划词菜单是否展开成多行，对齐上游 expandTextMenu（ReadSettings.kt:51）。 */
  @Prop expandTextMenu: boolean = false;
  /** 划词菜单是否显示图标，对齐上游 showSelectMenuIcon（ReadSettings.kt:52）。 */
  @Prop showSelectMenuIcon: boolean = true;
  /**
   * 横屏双页档位，对齐上游 doubleHorizontalPage（ReadSettings.kt:26）。
   * 取值四档：'0' 全局单页 / '1' 全局双页 / '2' 横屏双页 / '3' 平板或横屏双页，
   * 判定口径照 ReaderColumnMode.kt 的 columnCount()（'1' 对滚动模式也生效）。
   */
  @Prop @Watch('onPaginationInputsChanged') doubleHorizontalPage: string = '0';

  /**
   * 阅读亮度 1..100；上游 `readBrightness`（`ReadSettings.kt:22`，默认 100），
   * 窗口亮度取 `readBrightness / 100`（`ReadBookController.kt:3179-3187 applyReadBrightness`）。
   */
  @Prop @Watch('onReadBrightnessChanged') readBrightness: number = 100;
  /** 亮度条拖动时回写；上游 `ReadBookIntent.SetBrightness`（`ReadBookContract.kt:687`）。 */
  onReadBrightnessChange: (value: number) => void = (_value: number) => {};
  /** 亮度条形态；上游 `showBrightnessView`（`ReadSettings.kt:20`），"0" 关闭 / "1" 横排 / "2" 竖排。 */
  @Prop showBrightnessView: string = '0';
  /** 竖排亮度条贴哪一侧；上游 `brightnessVwPos`（`ReadSettings.kt:21`），"0" 左 / "1" 右。 */
  @Prop brightnessVwPos: string = '1';
  /**
   * 亮度是否跟随系统；上游 `brightnessAuto`（`ReadSettings.kt:23`，默认 true）。
   * 为真时窗口亮度交回系统（`BRIGHTNESS_OVERRIDE_NONE`），为假才用 `readBrightness / 100`。
   */
  @Prop @Watch('onReadBrightnessChanged') brightnessAuto: boolean = true;

  /** 正文行高适配；上游 `readBodyToLh`（`ReadSettings.kt:14`，默认 true）。上游只有只读快照，无渲染消费点。 */
  @Prop readBodyToLh: boolean = true;
  /** 自定义中文分行；上游 `useZhLayout`（`ReadSettings.kt:19`），只参与分页输入签名（`PageEstimateConfig.kt:23`）。 */
  @Prop @Watch('onPaginationInputsChanged') useZhLayout: boolean = false;
  /** 正文避让显示缺口；上游 `paddingDisplayCutouts`（`ReadSettings.kt:11`），见 `ReaderContentAvoidancePolicy.padding()`。 */
  @Prop @Watch('onPaginationInputsChanged') paddingDisplayCutouts: boolean = false;
  /** 适配书籍自带特殊样式；上游 `adaptSpecialStyle`（`ReadSettings.kt:18`），控制 `[newpage]`/`<usehtml>` 的解释。 */
  @Prop @Watch('onAdaptSpecialStyleChanged') adaptSpecialStyle: boolean = true;

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
  /**
   * 设置面板里是否有滑块正在被拖动；上游 `ReadBookMenuBar.kt:481` `LocalSliderDragState`。
   * 拖动期间顶栏/底栏不透明度压到 30% 以下，让用户看清背后正文的实时变化。
   * 由 `ReaderSettingsPage` 的滑块在 onChange 里写 AppStorage，这里订阅。
   */
  @StorageProp('readerMenuSliderDragging') menuSliderDragging: boolean = false;
  /** 标题栏胶囊；上游 `readMenuTopBarTitleCapsule`（`ReadSettings.kt:100`，默认 false）。 */
  @Prop readMenuTopBarTitleCapsule: boolean = false;
  /**
   * 标题栏显示方式，上游四值字符串（`ReadSettings.kt:12` 默认 "1"）：
   * "0" 书名在应用栏 + 章节名下一行；"1" 书名独立一行 + 章节名再一行；
   * "2" 只有书名（应用栏），无章节行；"3" 都不显示。
   */
  @Prop titleBarMode: string = '1';
  /** 标题栏精简；上游 `titleBarCompact`（`ReadSettings.kt:120`，默认 false），开启后顶栏只留「更多」。 */
  @Prop titleBarCompact: boolean = false;
  /** 标题栏图标样式 0 纯色 / 1 色调 / 2 描边；上游 `titleBarIconStyle`（`ReadSettings.kt:91`，默认 0）。 */
  @Prop titleBarIconStyle: number = 0;
  /** 顶栏模糊模式 0 关闭 / 1 液态玻璃 / 2 雾化；上游 `readMenuTopBarBlurMode`（`ReadSettings.kt:96`）。 */
  @Prop readMenuTopBarBlurMode: number = 0;
  /** 顶栏模糊样式 0 填充 / 1 渐变；上游 `readMenuTopBarBlurStyle`（`ReadSettings.kt:103`）。 */
  @Prop readMenuTopBarBlurStyle: number = 0;
  /** 顶栏按钮液态玻璃；上游 `readMenuTopBarLiquidGlassButtons`（`ReadSettings.kt:98`）。 */
  @Prop readMenuTopBarLiquidGlassButtons: boolean = false;
  /** 顶栏按钮合并成一个胶囊组；上游 `readMenuTopBarMergeButtons`（`ReadSettings.kt:99`）。 */
  @Prop readMenuTopBarMergeButtons: boolean = false;
  /** 菜单工具栏样式 0 跟随系统 / 1 跟随阅读背景 / 2 自定义；上游 `readBarStyle`（`ReadSettings.kt:69`，默认 1）。 */
  @Prop readBarStyle: number = 1;
  /** 菜单调色板样式，空串表示跟随系统；上游 `readMenuPaletteStyle`（`ReadSettings.kt:109`）。 */
  @Prop readMenuPaletteStyle: string = '';
  /** 菜单色板来源 0 种子色 / 1 自定义颜色；上游 `readMenuColorMode`（`ReadSettings.kt:88`，默认 1）。 */
  @Prop readMenuColorMode: number = 1;
  /** 菜单背景色，空串表示未设置；上游 `readMenuBgColor`（`ReadSettings.kt:80`）。 */
  @Prop readMenuBgColor: string = '';
  /** 菜单背景色（夜间）；上游 `readMenuBgColorNight`（`ReadSettings.kt:83`）。 */
  @Prop readMenuBgColorNight: string = '';
  /** 菜单容器色，空串时回落菜单背景色；上游 `readMenuContainerColor`（`ReadSettings.kt:82`）。 */
  @Prop readMenuContainerColor: string = '';
  /** 菜单容器色（夜间）；上游 `readMenuContainerColorNight`（`ReadSettings.kt:85`）。 */
  @Prop readMenuContainerColorNight: string = '';
  /** 菜单强调色，与「种子色」共用同一字段；上游 `readMenuAccentColor`（`ReadSettings.kt:81`）。 */
  @Prop readMenuAccentColor: string = '';
  /** 菜单强调色（夜间）；上游 `readMenuAccentColorNight`（`ReadSettings.kt:84`）。 */
  @Prop readMenuAccentColorNight: string = '';
  /** 菜单栏边框宽度 0–4，0 = 无边框（上游 readMenuBorderWidth，ReadSettings.kt:111 默认 1，夹 0–4）。 */
  @Prop readMenuBorderWidth: number = 1;
  /** 菜单栏边框颜色（日间），空串 = 未设置，回落主题 outlineVariant（上游 ReadSettings.kt:112）。 */
  @Prop readMenuBorderColor: string = '';
  /** 菜单栏边框颜色（夜间）（上游 ReadSettings.kt:113）。 */
  @Prop readMenuBorderColorNight: string = '';
  /** 菜单模糊半径 0–32（上游 readMenuBlurRadius，ReadSettings.kt:105 默认 24，夹 0–32）。 */
  @Prop readMenuBlurRadius: number = 24;
  /** 菜单文字与图标颜色（日间），空串 = 未设置，回落主题 onSurface（上游 ReadSettings.kt:86）。 */
  @Prop readMenuTextColor: string = '';
  /** 菜单文字与图标颜色（夜间）（上游 ReadSettings.kt:87）。 */
  @Prop readMenuTextColorNight: string = '';
  /** 菜单模糊层着色（日间），空串 = 未设置（上游 ReadSettings.kt:107）。 */
  @Prop readMenuBlurColor: string = '';
  /** 菜单模糊层着色（夜间）（上游 ReadSettings.kt:108）。 */
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

  /** 环境光日夜提醒的文案；空串表示当前没有提醒。 */
  @Prop dayNightReminderText: string = '';
  /** 点「切换到深色/浅色模式」。 */
  onAcceptDayNightReminder: () => void = () => {};
  /** 点「关闭」，本会话不再提示这一类。 */
  onDismissDayNightReminder: () => void = () => {};
  /** 划词菜单条目配置串，对齐上游 textSelectMenuConfig（ReadSettings.kt:53）；空串沿用内置顺序。 */
  @Prop textSelectMenuConfig: string = '';
  @Prop noAnimScrollPage: boolean = false;
  @Prop readingAnchorEnabled: boolean = true;
  @Prop swipeToAddBookmark: boolean = false;
  /** 阅读页右上角书签角标宽度（dp），0 表示不显示；对齐上游 bookmarkBadgeSize。 */
  @Prop bookmarkBadgeSize: number = 10;
  /** 自定义书签角标图片路径；空串表示用默认黄色丝带，对齐上游 bookmarkBadgeImage。 */
  @Prop bookmarkBadgeImage: string = '';
  @Prop selectText: boolean = true;
  /** 选择正文时震动；上游 ReadSettings.kt:41 selectVibrator，消费点见 ReaderHaptics。 */
  @Prop selectVibrator: boolean = false;
  @Prop bookmarks: ReaderBookmark[] = [];
  // 标记变化必须递增 revision，否则滚动模式的 ForEach 复用旧 Span、划线渲染不出来。
  @Prop @Watch('onMarkingsChanged') markings: ReaderMarking[] = [];
  @Prop readingAnchorAvailable: boolean = false;
  @Prop clickImageBehavior: string = '2';
  @Prop clickRegionActions: string[] = [];
  @Prop @Watch('onSystemBarSettingsChanged') hideStatusBar: boolean = false;
  @Prop @Watch('onSystemBarSettingsChanged') hideNavigationBar: boolean = false;
  @Prop @Watch('onImagePreviewCloseRevisionChanged') imagePreviewCloseRevision: number = 0;
  @Prop @Watch('onPageAnimationChanged') pageAnimation: number = 0;
  @Prop animationSpeed: number = 2;
  @Prop @Watch('onPaginationInputsChanged') infoSettings: ReaderInfoSettings = DEFAULT_READER_INFO_SETTINGS;
  @Prop @Watch('onPaginationInputsChanged') paddingSettings: ReaderPaddingSettings = DEFAULT_READER_PADDING_SETTINGS;
  @Prop @Watch('onImageStyleChanged') imageStyle: string = 'DEFAULT';
  @Prop replaceEnabled: boolean = true;
  @Prop replaceUsesDefault: boolean = true;
  @State contentProcesses: BookContentProcess[] = [];
  @State readerHighlightRules: ReaderHighlightRule[] = [];
  @State readerHighlightRanges: ReaderHighlightRange[] = [];
  // 命中排版（字号偏移 + 行上下距）的分页度量表，跟着 readerHighlightRanges 一起重算。
  private readerSizeOffsets: LocalReaderSizeOffset[] = [];
  @State highlightRuleSheetVisible: boolean = false;
  @State effectiveReplaceRuleIds: number[] = [];
  @Prop @Watch('onBookmarkTargetChanged') bookmarkTargetPosition: number = -1;
  @Prop @Watch('onBookmarkTargetChanged') bookmarkTargetRevision: number = 0;
  onBookmarkTargetConsumed: () => void = () => {};
  @Prop @Watch('onReaderCanvasStyleChanged') paperColor: string = '#000000';
  /** 正文颜色；上游 ReadBookConfig.kt:55-56 textColor / textColorNight，空串回落原有硬编码。 */
  @Prop @Watch('onReaderCanvasStyleChanged') readingTextColor: string = '';
  /** 强调色；上游 ReadBookConfig.kt:62 textAccentColor，用于链接、搜索结果与朗读段落。 */
  @Prop textAccentColor: string = '';
  /** 自定义背景图片的沙箱路径；空串表示没有，上游 ReadBookConfig.kt:549 bgType != 0 的情况。 */
  @Prop @Watch('onReaderCanvasStyleChanged') readerBackgroundImage: string = '';
  /** 背景图片不透明度百分比（0..100），上游 ReadBookConfig.kt:548 bgAlpha。 */
  @Prop backgroundAlpha: number = 100;
  /** 状态栏图标是否用深色；上游 ReadBookConfig.kt:552-553 darkStatusIcon / darkStatusIconNight。 */
  @Prop @Watch('onDarkStatusIconChanged') darkStatusIcon: boolean = true;
  @Prop showQuickActions: boolean = false;
  @Prop showControlsOnAppear: boolean = false;
  @Prop showBottomActionText: boolean = true;
  @Prop bottomIconStyle: number = 1;
  @Prop bottomItemsPerRow: number = 5;
  @Prop bottomRowCount: number = 1;
  @Prop bottomActions: ReaderBottomActionConfig[] = READER_LOCAL_BOTTOM_ACTION_DEFAULTS;
  @Prop topActions: ReaderBottomActionConfig[] = READER_LOCAL_TOP_ACTION_DEFAULTS;
  @Prop moreActions: ReaderMoreActionConfig[] = READER_MORE_ACTION_DEFAULTS;
  /**
   * 「更多」下拉菜单是否显示每项前置图标，上游 `showMenuIcon`（ReadSettings.kt:119，默认 false）。
   * 上游消费点 `ReadBookMenuBarFloating.kt:174-186`：为 true 才给菜单项传 `leadingIcon`。
   */
  @Prop showMenuIcon: boolean = false;
  /** 顶部工具栏附加区域，上游 `showReadTitleAddition`（ReadSettings.kt:55，默认 true）；上游无渲染消费点，本地只落库。 */
  @Prop showReadTitleAddition: boolean = true;
  /** 菜单不透明度 0-100，上游 `menuAlpha`（ReadSettings.kt:13，默认 100）；上游无渲染消费点，本地只落库。 */
  @Prop menuAlpha: number = 100;
  @State @Watch('onControlsVisibilityChanged') controlsVisible: boolean = false;
  /** 划词菜单「更多」是否就地展开；每次菜单重新弹出前由 onMenuShow 复位。 */
  @State selectionMenuMoreVisible: boolean = false;
  /** 上次点图片的时间戳：`clickImgWay === '4'` 的双击判定窗口 300ms。 */
  private imageTapTimestamp: number = 0;
  @State imagePreviewVisible: boolean = false;
  @State imagePreviewUri: string = '';
  @State overflowVisible: boolean = false;
  @State imageStyleMenuVisible: boolean = false;
  /** 「翻页动画」条目的二级菜单：上游点一下直接展开 6 项单选，不弹「未迁移」。 */
  /** 更多操作面板当前页（每页 8 格，对齐上游 chunked(8)）。 */
  @State moreActionPage: number = 0;
  @State pageAnimMenuVisible: boolean = false;
  @State moreActionConfigVisible: boolean = false;
  @State moreActionShellVisible: boolean = false;
  @State moreActionShellTitle: string = '';
  @State draftMoreActions: ReaderMoreActionConfig[] = READER_MORE_ACTION_DEFAULTS.map(
    (item: ReaderMoreActionConfig): ReaderMoreActionConfig => ({ id: item.id, enabled: item.enabled })
  );
  @State charsetDialogVisible: boolean = false;
  @State charsetOptionsExpanded: boolean = false;
  @State charsetInput: string = 'UTF-8';
  @State activeImageStyle: string = 'DEFAULT';
  @State readerProgress: number = 0;
  @State sliderProgressIndex: number = 0;
  @State viewportHeight: number = 0;
  @State readerContentWidth: number = 0;
  @State readerContentRevision: number = 0;
  @State readerBodyFontFamily: string = 'HarmonyOS Sans';
  @State readerTitleFontFamily: string = 'HarmonyOS Sans';
  @State imageSizes: Map<string, ReaderIntrinsicImageSize> = new Map<string, ReaderIntrinsicImageSize>();
  @State scrollOffset: number = 0;
  @State lastReportedProgress: number = -1;
  @State restoredProgressPosition: boolean = false;
  @State startPositionPending: boolean = false;
  /**
   * 换章交接标记（KI-REL1）。
   *
   * 上游换章是「先发布已有页、再补新页」，画布任何时刻都有 `pages.current`
   * （`ReadBookController.kt:2949-2965`）；本地是整章重排，所以用这个标记让
   * `onReaderContentChanged()` 保留上一章的页表当过渡帧，新页排好后再整表替换。
   * `chapterHandoffUpward` 记录这次换章是向上翻（落章末）还是向下翻（落章首）。
   */
  private chapterHandoffPending: boolean = false;
  private chapterHandoffUpward: boolean = false;
  /**
   * 上一次交接记的是哪本书。
   *
   * 换书时 `content` 同样会变，若不区分就会把上一本书的页表当过渡帧画出来。
   * 只有 book.id 没变才算「换章」，换书仍按原路径清空。
   */
  private chapterHandoffBookId: string = '';
  @State localReaderPages: LocalReaderPage[] = [];
  @State readerBottomJustifyGap: number = 0;
  @State fullBookPageCounts: number[] = [];
  @State fullBookPaginationReady: boolean = false;
  @State localSemanticContent: string = '';
  private localSemanticDocument: LocalSemanticDocument = {
    paragraphs: [], content: '', sourceLength: 0, sourcePositionMap: [0]
  };
  @State currentPageIndex: number = 0;
  @State pageTurnOffsetX: number = 0;
  @State pageTurnOffsetY: number = 0;
  @State pageTurnOpacity: number = 1;
  @State pageTurnAnimating: boolean = false;
  @State bookmarkPullOffset: number = 0;
  @State bookmarkPullArmed: boolean = false;
  @State bookmarkWillRemove: boolean = false;
  private pageTurnTimer: number = -1;
  /** 滚动模式进度节流定时器；`-1` 表示没有待刷新。 */
  private scrollProgressTimer: number = -1;
  private pendingScrollProgress: number = 0;
  // 分页输入防抖：几十个 @Prop 的 @Watch 会连续触发，合并成一帧后再排一次
  private static readonly PAGINATION_DEBOUNCE_MILLIS: number = 16;
  // 图片尺寸是一张张异步量出来的，窗口给长一点，让同一章的尺寸尽量聚成一批只排一次
  private static readonly IMAGE_SIZES_DEBOUNCE_MILLIS: number = 100;
  // 把手淡出的比淡入快：上游 SelectionHandleFadeOutMillis / SelectionHandleFadeInMillis
  private static readonly CANVAS_HANDLE_FADE_OUT_MILLIS: number = 90;
  private static readonly CANVAS_HANDLE_FADE_IN_MILLIS: number = 140;
  private paginationRebuildTimer: number = -1;
  // 本轮待排的重排是否只由图片尺寸变化触发；true 时跳过语义解析与高亮匹配，只重分页
  private imageSizesRebuildPending: boolean = false;
  // 防抖窗口长度：布局类输入合并一帧即可，图片尺寸要给足窗口让一批尺寸聚齐
  private paginationRebuildDelayMillis: number = ReaderPage.PAGINATION_DEBOUNCE_MILLIS;
  // 本轮分页是否用了「图片尺寸未就绪」的占位高度；尺寸到达后要再排一次
  private paginationUsesImagePlaceholder: boolean = false;
  // 画布渲染：四页窗口 + 逐行绘制（对齐上游 ReaderCanvasSurface）。
  // 一个 Canvas 持一个 DrawingRenderingContext，按 z 序把四页画进同一张画布。
  private readerCanvasContext: DrawingRenderingContext =
    new DrawingRenderingContext(LengthMetricsUnit.PX);
  private readerCanvasRenderer: ReaderCanvasRenderer = new ReaderCanvasRenderer();
  private readerCanvasReady: boolean = false;
  /**
   * 画布实测正文区高度（vp）。分页按公式算的 pageHeight 与画布真实可分高度并不等值：
   * 页脚实际占位比 getReaderInfoReserve(false) 的预留更大，公式会多算出几十 px，
   * 结果分页认为放得下、画到画布上时最后一行被下边缘裁掉半行。
   * 这里记下画布量到的真实高度，分页以「公式值」与「实测值」的较小者为准。
   */
  private readerCanvasBodyHeightVp: number = 0;
  /**
   * 上一次分页时用来算底部对齐位移的输入。底部对齐是「按当前页内容摊分剩余高度」，
   * 所以 gap 只对当时那一页成立；翻页后必须按新页重算，否则上一页的位移会套到新页上，
   * 把新页最后一行推出画布下边缘（表现为末行被裁掉一半）。
   */
  private readerBottomJustifyPageHeight: number = 0;
  private readerBottomJustifyLineHeight: number = 0;
  private readerBottomJustifyTitleLines: number = 0;
  // 渲染路径开关（逃生舱）：true 走画布逐行绘制，false 走老的 ArkUI Span 渲染。
  // 画布上还没有自绘选区，长按选词/拖把手/标笔记/高亮只有老路径能给；
  // 阶段 C 把选区画到画布上并通过验收后，这个开关与老路径一起删掉。
  // 用 @State 而非常量，是为了能临时改一行就切回去核对选区是否退化。
  @State canvasSelectionStart: number = -1;
  @State canvasSelectionEnd: number = -1;
  /** 长按后拖把手：1 = 拖起始把手，2 = 拖结束把手，0 = 没在拖。 */
  @State canvasSelectionDragging: number = 0;
  /** 选区菜单是否显示，以及菜单锚点（vp，相对阅读页 Stack）。 */
  @State canvasSelectionMenuVisible: boolean = false;
  /**
   * 划词菜单的进出场动画进度（0..1）。
   *
   * 上游 `ui/book/read/SelectionMenuMotion.kt:21-49`：入场淡入 360ms + 0.94→1 缩放 400ms，
   * 退场淡出 320ms + 1→0.96 缩放 280ms。本地用一个 Animator 同时推这两个量。
   */
  private canvasSelectionMenuAnimator: AnimatorResult | undefined = undefined;
  @State canvasSelectionMenuProgress: number = 0;
  @State canvasSelectionMenuX: number = 0;
  @State canvasSelectionMenuY: number = 0;
  /** 菜单卡实测宽高（vp）：锚点要靠它把卡片夹进屏幕，否则宽卡会顶出右边界。 */
  @State canvasSelectionMenuWidthVp: number = 0;
  @State canvasSelectionMenuHeightVp: number = 0;
  /** 长按计时器与按下点（px）。 */
  // 长按起选之后紧跟的那次抬手会再触发一次 TapGesture，
  // 上游用 suppressTap 吞掉它（ReaderCanvasSurface.kt:1035-1080），
  // 否则选区刚建好就被单击逻辑清掉，看起来像「选了没反应」。
  private canvasSuppressTap: boolean = false;
  private canvasLongPressTimer: number = -1;
  private canvasLongPressX: number = 0;
  private canvasLongPressY: number = 0;
  /** 最近一次绘制回填的把手位置（px），用来判断是否抓到了把手。 */
  private canvasHandleStartX: number = 0;
  private canvasHandleStartY: number = 0;
  private canvasHandleEndX: number = 0;
  private canvasHandleEndY: number = 0;
  // 竖线顶端：命中判定要把「竖线 + 圆柄」当一个胶囊，缺了顶端就只能按圆算，热区偏小。
  private canvasHandleStartTopY: number = 0;
  private canvasHandleEndTopY: number = 0;
  // 抓手时手指相对圆心的二维偏移。拖动过程中端点必须跟着「把手」走，不能用手指
  // 原样去 hit-test —— 圆心在行底下方一个 radius 处，手指天然落在文字行之外，
  // 直接取最近行会串到下一行（上游 selectionDragHandleCenter 就是同一个道理）。
  private canvasHandleGrabOffsetX: number = 0;
  private canvasHandleGrabOffsetY: number = 0;
  // 两个把手各自的透明度：拖动哪个就把哪个淡出，松手再淡入（上游 animateFloatAsState）
  private canvasHandleStartAlpha: number = 1;
  private canvasHandleEndAlpha: number = 1;
  private canvasHandleAnimator: AnimatorResult | undefined = undefined;
  /** 画布相对外层 Stack 的纵向偏移（vp），给选区菜单定位。 */
  private readerCanvasOffsetYVp: number = 0;
  private static readonly CANVAS_ID: string = 'reader_canvas';
  private static readonly STACK_ID: string = 'reader_root_stack';
  // 当前正在播放的转场；NONE 表示没有转场（只画 current）。
  private turnTransition: ReaderPageTransition = new ReaderPageTransition();
  private turnAnimator: AnimatorResult | undefined = undefined;
  private turnMode: ReaderTransitionMode = ReaderTransitionMode.NONE;
  // 仿真折页的触点与角点：逐帧写入，绘制期只读（上游 curlTouchX/curlTouchY/curlCornerY）
  private curlTouchX: number = 0;
  private curlTouchY: number = 0;
  private curlCornerY: number = 0;
  private curlRevealProgress: number = 1;
  /** 滚动拖拽上一帧的累计 offsetY（vp），用于把累计量换算成逐帧 delta。 */
  private scrollDragLastY: number = 0;
  /** 本次拖动是否已经因到章边界而转过章（一次拖动只转一次，避免连跳）。 */
  private scrollDragBoundaryTurned: boolean = false;
  /**
   * 横向拖动翻页的状态（上游 `ReaderHorizontalDrag`）。
   * 方向在越过 touch-slop 那一刻锁定，此后位移从锁定点算起——
   * 这样手指先横后竖、或反向回拖，都不会让页面从别处开始跟手。
   */
  private horizontalDragOriginVp: number = 0;
  private horizontalDragLocked: boolean = false;
  /** 上一帧已画出的位移（vp），收尾动画从它起步，不回到 0。 */
  private horizontalDragLastOffsetVp: number = 0;
  private curlPrevious: boolean = false;
  // 高亮样式区间的构造缓存（翻页动画每帧都会重建 request，不缓存会每帧新建上千对象）
  private canvasHighlights: ReaderCanvasStyleRange[] = [];
  private canvasHighlightSignature: string = '';
  // 翻页动画期的临时页索引：COVER 期间旧页仍是 currentPageIndex，新页已经作为 next 参与绘制，
  // 动画收尾才把索引换过去 —— 这样任何一帧都不会出现「两页都没画」。
  private turnTargetPageIndex: number = -1;
  private fullBookPaginationGeneration: number = 0;
  private fullBookPaginationKey: string = '';
  private pendingMarkingStart: number = -1;
  private pendingMarkingEnd: number = -1;
  private pendingMarkingText: string = '';
  private pendingMarkingRanges: Map<number, ReaderMarkingRange> = new Map<number, ReaderMarkingRange>();
  private lastReaderTapTimestamp: number = 0;
  @State pendingBookmarkTargetPosition: number = -1;
  @State autoPageActive: boolean = false;
  @State autoPageSettingsVisible: boolean = false;
  @State autoPageSecondsRemaining: number = 10;
  @State autoPageWaitingForChapter: boolean = false;
  @State contentEditVisible: boolean = false;
  @State contentEditTitle: string = '';
  @State contentEditBody: string = '';
  /**
   * 编辑弹层的「仅正文」折叠开关，对齐上游 `ReadContentEditDelegate` 的 `bodyOnly`。
   * 折叠只改编辑框里显示的文字，保存时按占位标记把原始片段插回。
   */
  @State contentEditBodyOnly: boolean = false;
  /** 打开编辑弹层那一刻扫描到的非正文片段，折叠与插回共用同一份。 */
  @State contentEditHiddenSpans: HiddenSpan[] = [];
  @State textProcessingVisible: boolean = false;
  @State currentBottomActionPage: number = 0;
  @Prop autoReadSpeedSeconds: number = 10;
  private autoPageTimer: number = -1;
  /** 自动翻页的逐帧揭示高度（vp），0 表示没有在揭示。 */
  private autoPageRevealVp: number = 0;
  private autoPageTurnAnimator: AnimatorResult | undefined = undefined;
  private titleGeneration: number = 0;
  private readerSystemBarRequestId: number = 0;
  /** 状态栏图标色的请求序号：连续改色时只认最后一次，避免异步返回乱序。 */
  private readerStatusBarIconRequestId: number = 0;
  /** 窗口亮度请求序号，用途同上。 */
  private readerBrightnessRequestId: number = 0;
  /** 显示缺口（刘海/挖孔）的左右与底部 inset，单位 vp；系统回调写入，配置关闭时不用。 */
  private readerDisplayCutoutLeft: number = 0;
  private readerDisplayCutoutRight: number = 0;
  private readerDisplayCutoutBottom: number = 0;
  private readerOrientationRequestId: number = 0;
  private originalReaderOrientation: window.Orientation = window.Orientation.UNSPECIFIED;
  private originalReaderOrientationCaptured: boolean = false;
  private keepLightTimer: number = -1;
  private keepLightRequestId: number = 0;
  private readerWindowActive: boolean = false;
  private volumeKeysSubscribed: boolean = false;
  private subscribedVolumeKeyLongPress: boolean | undefined = undefined;
  /** 已订阅的按键签名（音量开关|长按|上一页键串|下一页键串），变了才重订阅。 */
  private subscribedPageKeySignature: string = '';
  /**
   * 统一的翻页键回调。上游 ReadBookController.kt:2699 的 onKeyDown 里自定义映射优先，
   * 再落到音量键等内置语义；这里自定义映射命中就直接翻页，否则按音量键默认方向走。
   */
  private pageKeyHandler: (event: KeyEvent) => void = (event: KeyEvent): void => {
    if (event.action !== Action.DOWN || !this.readerWindowActive || this.controlsVisible) { return; }
    const code = event.key.code;
    const mapped = this.matchPageKey(code);
    if (mapped !== 0) {
      this.turnReaderPage(mapped);
      return;
    }
    if (code === KeyCode.KEYCODE_VOLUME_UP) { this.turnReaderPage(-1); }
    else if (code === KeyCode.KEYCODE_VOLUME_DOWN) { this.turnReaderPage(1); }
  };
  onBack: () => void = () => {};
  onOpenCatalog: () => void = () => {};
  /** 点/长按顶栏书名进书籍详情；上游 `ReadBookMenuBarTitle.kt:492-600` 的 `OpenBookInfo`。 */
  onOpenBookInfo: () => void = () => {};
  /** 亮度条「跟随系统」按钮；上游 `ReadBookIntent.ToggleBrightnessAuto`。 */
  onBrightnessAutoChange: (auto: boolean) => void = () => {};
  /** 亮度条「左右位置」按钮；上游 `ConfigUpdate.BrightnessVwPos`。 */
  onBrightnessVwPosChange: (position: string) => void = () => {};
  onRestoreReadingAnchor: () => void = () => {};
  onKeepReadingAnchor: () => void = () => {};
  onToggleCurrentPageBookmark: (start: number, end: number, pageText: string) => void =
    (_start: number, _end: number, _pageText: string) => {};

  onOpenSettings: () => void = () => {};
  onCharsetChange: (charset: string) => void = (_charset: string) => {};
  onOpenSearchContent: () => void = () => {};
  /**
   * 搜索结果集：从搜索页跳进来时由 `Index.ets` 传下来，正文两侧的「上一个/下一个」
   * 与底部结果条都读它（上游 `ReadBookState.searchResultIndex` 同用途）。
   */
  @Prop searchNavItems: ReaderSearchNavItem[] = [];
  @Prop @Watch('onSearchNavIndexChanged') searchNavIndex: number = -1;
  /** 跳到另一个搜索结果；`Index.ets` 负责重新读章与定位。 */
  onOpenSearchNavItem: (index: number) => void = (_index: number) => {};
  /** 收起搜索结果条（上游 `HideSearchMenu`）。 */
  onCloseSearchResult: () => void = () => {};
  onOpenReadAloud: () => void = () => {};
  onOpenImagePreview: (uri: string) => void = (_uri: string) => {};
  onCloseImagePreview: () => void = () => {};
  onControlsShown: () => void = () => {};
  onOpenTocRule: () => void = () => {};
  onToggleNightMode: () => void = () => {};
  @Prop eyeProtectionActive: boolean = false;
  onToggleEyeProtection: () => void = () => {};
  onMoreActionsChange: (actions: ReaderMoreActionConfig[]) => void = (_actions: ReaderMoreActionConfig[]) => {};
  onOpenBottomActionConfig: () => void = () => {};
  onUnavailableAction: (message: string) => void = (_message: string) => {};
  onImageStyleChange: (imageStyle: string) => void = (_imageStyle: string) => {};
  onPageAnimationChange: (animation: number) => void = (_animation: number) => {};
  onProgressChange: (bookId: string, chapterIndex: number, progress: number,
    chapterPosition: number, androidCoordinate: boolean) => void = () => {};
  onAddBookmark: (chapterPosition: number, pageText: string) => void = (_position: number, _pageText: string) => {};
  /** 点正文里的划线文字：打开这条笔记的编辑面板（上游 onMarkingClick）。 */
  onOpenMarking: (markingId: string) => void = (_markingId: string) => {};
  onCreateMarking: (chapterPosition: number, endPosition: number, selectedText: string) => void =
    (_position: number, _endPosition: number, _selectedText: string) => {};
  onSaveChapterContent: (chapterIndex: number, title: string, body: string) => void =
    (_chapterIndex: number, _title: string, _body: string) => {};
  onToggleReSegment: (enabled: boolean) => void = (_enabled: boolean) => {};
  onOpenReplaceRules: () => void = () => {};
  onReplaceRulesRefresh: () => void = () => {};
  onReplaceEnabledChange: (enabled: boolean) => void = (_enabled: boolean) => {};
  onReplaceResetToDefault: () => void = () => {};
  onRuleEnabledChange: (id: number, enabled: boolean) => void = (_id: number, _enabled: boolean) => {};
  /** 文本处理面板拖拽松手后回传新的规则顺序；上游对应 MoveReplaceRule。 */
  onRuleReorder: (orderedIds: number[]) => void = (_orderedIds: number[]) => {};
  onContentProcessToggle: (id: string, enabled: boolean) => void = (_id: string, _enabled: boolean) => {};
  onContentProcessDelete: (id: string) => void = (_id: string) => {};
  onSelectChapterIndex: (chapterIndex: number) => void = () => {};
  onTurnChapterBoundary: (delta: number) => void = (_delta: number) => {};
  /** 章边界提示文案；非空时当前页整屏只显示这一行（上游 `centeredReaderMessagePage`）。 */
  @State boundaryMessage: string = '';
  private boundaryMessageTimer: number = -1;
  onAutoReadSpeedChange: (seconds: number) => void = (_seconds: number) => {};
  onReadSessionStart: () => void = () => {};
  onReadSessionPulse: () => void = () => {};
  onReadSessionStop: () => void = () => {};
  private readSessionTimer: number = -1;
  onStartAtChapterBeginningResolved: () => void = () => {};

  aboutToAppear(): void {
    this.refreshReaderFontFamilies();
    this.loadChapterRows();
    this.readerWindowActive = true;
    this.startPositionPending = this.startAtChapterBeginning;
    if (this.bookmarkTargetPosition >= 0) { this.pendingBookmarkTargetPosition = this.bookmarkTargetPosition; }
    this.resetPageTurnTransition();
    if (this.showControlsOnAppear) {
      this.controlsVisible = true;
      this.onControlsShown();
    }
    this.onReadSessionStart();
    this.readSessionTimer = setInterval(() => this.onReadSessionPulse(), 30000);
    this.activeImageStyle = this.imageStyle;
    this.readerProgress = this.startPositionPending ? 0 : (this.book.chapterProgress ?? 0);
    this.lastReportedProgress = this.readerProgress;
    this.sliderProgressIndex = this.startPositionPending ? 0 : this.getChapterIndex();
    // 首排之前先把本章图片尺寸量好：排版期就用真实尺寸，图片解码完只重绘不重排
    this.primeContentImageSizesSync();
    if (this.startPositionPending) {
      this.restoredProgressPosition = false;
      this.scrollOffset = 0;
      this.rebuildReaderPages();
    }
    this.loadContentImageSizes();
    this.autoPageSecondsRemaining = this.autoReadSpeedSeconds;
    this.refreshDisplayChapterTitle();
    this.refreshContentProcesses();
    this.loadReaderHighlightRules();
    this.syncReaderSystemBars();
    this.applyReaderStatusBarIcon();
    this.applyReaderBrightness();
    this.applyReaderDisplayCutout();
    this.applyReaderOrientation(this.screenOrientation, true);
    this.applyKeepLight();
    this.syncVolumeKeyPage();
  }

  aboutToDisappear(): void {
    this.readerWindowActive = false;
    this.clearKeepLight();
    this.releaseVolumeKeys();
    this.syncReaderSystemBars(true);
    this.restoreReaderStatusBarIcon();
    this.restoreReaderBrightness();
    this.restoreReaderOrientation();
    this.fullBookPaginationGeneration++;
    this.stopAutoPageTimer();
    this.resetPageTurnTransition();
    if (this.scrollProgressTimer >= 0) {
      clearTimeout(this.scrollProgressTimer);
      this.scrollProgressTimer = -1;
    }
    if (this.boundaryMessageTimer >= 0) {
      clearTimeout(this.boundaryMessageTimer);
      this.boundaryMessageTimer = -1;
    }
    // 退出阅读页时释放画布缓存：clear() 会逐个 pixelMap.release()，不释放则带图 EPUB 反复进出会线性涨内存。
    // 换章复用缓存，那条路径只走 clearParagraphs()，不要改到这里来。
    this.readerCanvasRenderer.clear();
    if (this.readSessionTimer >= 0) {
      clearInterval(this.readSessionTimer);
      this.readSessionTimer = -1;
    }
    this.onReadSessionStop();
  }

  onControlsVisibilityChanged(): void {
    this.syncReaderSystemBars();
    this.syncVolumeKeyPage();
    // 自动翻页在菜单打开期间挂起（上游 autoPagePaused），关掉菜单再从整页重新计时
    if (this.autoPageActive) {
      if (this.controlsVisible) {
        this.cancelAutoPageTurn();
      } else {
        this.startAutoPageTurn();
      }
    }
  }

  onVolumeKeyPageChanged(): void {
    this.syncVolumeKeyPage();
  }

  onStartAtChapterBeginningChanged(): void {
    if (!this.startAtChapterBeginning) {
      this.startPositionPending = false;
      return;
    }
    this.startPositionPending = true;
    this.readerProgress = 0;
    this.lastReportedProgress = 0;
    this.sliderProgressIndex = 0;
    this.restoredProgressPosition = false;
    this.scrollOffset = 0;
    this.rebuildReaderPages();
  }

  private resolveStartPosition(): void {
    if (!this.startPositionPending) { return; }
    this.startPositionPending = false;
    this.onStartAtChapterBeginningResolved();
  }

  private syncVolumeKeyPage(): void {
    if (!this.readerWindowActive || (!this.volumeKeyPage && this.prevKeys.length === 0 && this.nextKeys.length === 0)
      || this.controlsVisible) {
      this.releaseVolumeKeys();
      return;
    }
    const signature = `${this.volumeKeyPage}|${this.keyPageOnLongPress}|${this.prevKeys}|${this.nextKeys}`;
    if (this.volumeKeysSubscribed && this.subscribedVolumeKeyLongPress === this.keyPageOnLongPress
      && this.subscribedPageKeySignature === signature) { return; }
    if (this.volumeKeysSubscribed) { this.releaseVolumeKeys(); }
    for (const code of this.collectPageKeyCodes()) {
      try {
        inputConsumer.on('keyPressed', {
          key: code, action: 1, isRepeat: this.keyPageOnLongPress
        }, this.pageKeyHandler);
      } catch (error) {
        console.error(`[ReaderPage] 订阅翻页键 ${code} 失败: ${error}`);
        // 该系统键不允许应用级抢占（inputConsumer 只在 API 21+ 放开媒体键，其余仅音量键），
        // 交给面板说明与 onKeyEvent 兜底，这里静默跳过，避免整组订阅失败。
      }
    }
    this.volumeKeysSubscribed = true;
    this.subscribedVolumeKeyLongPress = this.keyPageOnLongPress;
    this.subscribedPageKeySignature = signature;
  }

  /**
   * 该键是否允许用系统级 inputConsumer 抢占。上游是任意物理键（ReadBookController.kt:2699 的 onKeyDown），
   * 本地 SDK 只放开音量键（API 20 及以下）与媒体三键（API 21+），其余键无法从这里接管。
   */
  private isConsumablePageKey(code: number): boolean {
    return code === KeyCode.KEYCODE_VOLUME_UP || code === KeyCode.KEYCODE_VOLUME_DOWN
      || code === KeyCode.KEYCODE_MEDIA_NEXT || code === KeyCode.KEYCODE_MEDIA_PREVIOUS
      || code === KeyCode.KEYCODE_MEDIA_PLAY_PAUSE;
  }

  /** 把「英文逗号分隔的键值串」解析成去重的键值数组，非法项直接丢弃。 */
  private parsePageKeyCodes(value: string): number[] {
    const codes: number[] = [];
    for (const piece of value.split(',')) {
      const trimmed = piece.trim();
      if (trimmed.length === 0) { continue; }
      const parsed = Number(trimmed);
      if (!Number.isInteger(parsed) || parsed <= 0) { continue; }
      if (!codes.includes(parsed)) { codes.push(parsed); }
    }
    return codes;
  }

  /** 需要订阅的键集合：用户映射的可接管键 + 音量键开关打开时的两个默认键。 */
  private collectPageKeyCodes(): number[] {
    const codes: number[] = [];
    const mapped = this.parsePageKeyCodes(this.prevKeys).concat(this.parsePageKeyCodes(this.nextKeys));
    for (const code of mapped) {
      if (this.isConsumablePageKey(code) && !codes.includes(code)) { codes.push(code); }
    }
    if (this.volumeKeyPage) {
      if (!codes.includes(KeyCode.KEYCODE_VOLUME_UP)) { codes.push(KeyCode.KEYCODE_VOLUME_UP); }
      if (!codes.includes(KeyCode.KEYCODE_VOLUME_DOWN)) { codes.push(KeyCode.KEYCODE_VOLUME_DOWN); }
    }
    return codes;
  }

  /**
   * 该键映射到哪个方向：-1 上一页、1 下一页、0 未映射。
   * 自定义映射优先于内置语义，对齐上游 isPrevKey/isNextKey 在 onKeyDown 里排在所有内置键之前的顺序。
   */
  private matchPageKey(code: number): number {
    if (this.parsePageKeyCodes(this.prevKeys).includes(code)) { return -1; }
    if (this.parsePageKeyCodes(this.nextKeys).includes(code)) { return 1; }
    return 0;
  }

  private releaseVolumeKeys(): void {
    try { inputConsumer.off('keyPressed'); } catch (error) { console.error(`[ReaderPage] 取消翻页键订阅失败: ${error}`); }
    this.volumeKeysSubscribed = false;
    this.subscribedVolumeKeyLongPress = undefined;
    this.subscribedPageKeySignature = '';
  }

  onSystemBarSettingsChanged(): void {
    this.syncReaderSystemBars();
  }

  onScreenOrientationChanged(): void {
    this.applyReaderOrientation(this.screenOrientation);
  }

  onKeepLightChanged(): void {
    if (this.readerWindowActive) { this.applyKeepLight(); }
  }

  private clearKeepLight(): void {
    if (this.keepLightTimer >= 0) {
      clearTimeout(this.keepLightTimer);
      this.keepLightTimer = -1;
    }
    const requestId = ++this.keepLightRequestId;
    const context = this.getUIContext().getHostContext();
    if (context === undefined) { return; }
    window.getLastWindow(context).then((targetWindow: window.Window) => {
      if (requestId === this.keepLightRequestId) { targetWindow.setWindowKeepScreenOn(false).catch(() => {}); }
    }).catch(() => {});
  }

  private renewKeepLightTimeout(): void {
    if (this.readerWindowActive) { this.applyKeepLight(); }
  }

  private applyKeepLight(): void {
    if (this.keepLightTimer >= 0) {
      clearTimeout(this.keepLightTimer);
      this.keepLightTimer = -1;
    }
    const context = this.getUIContext().getHostContext();
    if (context === undefined) { return; }
    const seconds = Number.parseInt(this.keepLight, 10);
    let systemTimeout = 60000;
    try {
      systemTimeout = Number.parseInt(settings.getValueSync(context, settings.display.SCREEN_OFF_TIMEOUT, '60000'), 10);
    } catch (error) { console.error(`[ReaderPage] 读取系统息屏超时失败: ${error}`); }
    const shouldKeepOn = this.readerWindowActive && (seconds < 0 || (seconds > 0 &&
      seconds * 1000 > (Number.isFinite(systemTimeout) ? systemTimeout : 60000)));
    const requestId = ++this.keepLightRequestId;
    window.getLastWindow(context).then((targetWindow: window.Window) => {
      if (requestId === this.keepLightRequestId) { targetWindow.setWindowKeepScreenOn(shouldKeepOn).catch(() => {}); }
    }).catch(() => {});
    if (shouldKeepOn && seconds > 0) {
      this.keepLightTimer = setTimeout(() => this.clearKeepLight(), seconds * 1000);
    }
  }

  private applyReaderOrientation(value: string, captureOriginal: boolean = false): void {
    const context = this.getUIContext().getHostContext();
    if (context === undefined) { return; }
    const requestId = ++this.readerOrientationRequestId;
    let orientation: window.Orientation = window.Orientation.UNSPECIFIED;
    if (value === '1') { orientation = window.Orientation.PORTRAIT; }
    else if (value === '2') { orientation = window.Orientation.LANDSCAPE; }
    else if (value === '3') { orientation = window.Orientation.AUTO_ROTATION; }
    else if (value === '4') { orientation = window.Orientation.PORTRAIT_INVERTED; }
    else if (value === '5') { orientation = window.Orientation.LANDSCAPE_INVERTED; }
    window.getLastWindow(context).then((targetWindow: window.Window) => {
      if (requestId !== this.readerOrientationRequestId) { return; }
      if (captureOriginal && !this.originalReaderOrientationCaptured) {
        this.originalReaderOrientation = targetWindow.getPreferredOrientation();
        this.originalReaderOrientationCaptured = true;
      }
      targetWindow.setPreferredOrientation(orientation).catch(() => {});
    }).catch(() => {});
  }

  private restoreReaderOrientation(): void {
    const context = this.getUIContext().getHostContext();
    if (context === undefined) { return; }
    const requestId = ++this.readerOrientationRequestId;
    const orientation = this.originalReaderOrientationCaptured
      ? this.originalReaderOrientation : window.Orientation.UNSPECIFIED;
    this.originalReaderOrientationCaptured = false;
    window.getLastWindow(context).then((targetWindow: window.Window) => {
      if (requestId !== this.readerOrientationRequestId) { return; }
      targetWindow.setPreferredOrientation(orientation).catch(() => {});
    }).catch(() => {});
  }

  private syncReaderSystemBars(forceVisible: boolean = false): void {
    const context = this.getUIContext().getHostContext();
    if (context === undefined) { return; }
    const requestId = ++this.readerSystemBarRequestId;
    const showStatusBar = forceVisible || this.controlsVisible || !this.hideStatusBar;
    const showNavigationBar = forceVisible || this.controlsVisible || !this.hideNavigationBar;
    window.getLastWindow(context).then((targetWindow: window.Window) => {
      if (requestId !== this.readerSystemBarRequestId) { return; }
      Promise.all([
        targetWindow.setSpecificSystemBarEnabled('status', showStatusBar, false),
        targetWindow.setSpecificSystemBarEnabled('navigation', showNavigationBar, false),
        targetWindow.setSpecificSystemBarEnabled('navigationIndicator', showNavigationBar, false)
      ]).catch(() => {});
    }).catch(() => {});
  }

  /**
   * 按 `darkStatusIcon` 调系统状态栏图标色。
   * 上游是 `WindowCompat.getInsetsController(...).isAppearanceLightStatusBars = !isDarkTheme`
   * （`base/BaseActivity.kt:167`）；HOS 侧对应 `setWindowSystemBarProperties` 的 `statusBarContentColor`。
   * 深浅用 `#E5FFFFFF` / `#E5000000`，与 EntryAbility 里的默认值同一口径。
   */
  private applyReaderStatusBarIcon(): void {
    const context = this.getUIContext().getHostContext();
    if (context === undefined) { return; }
    const requestId = ++this.readerStatusBarIconRequestId;
    window.getLastWindow(context).then((targetWindow: window.Window) => {
      if (requestId !== this.readerStatusBarIconRequestId) { return; }
      targetWindow.setWindowSystemBarProperties({
        statusBarContentColor: this.darkStatusIcon ? '#E5000000' : '#E5FFFFFF'
      }).catch(() => {});
    }).catch(() => {});
  }

  /** 退出阅读页时把状态栏图标恢复成应用默认（EntryAbility 里设的浅色）。 */
  private restoreReaderStatusBarIcon(): void {
    const context = this.getUIContext().getHostContext();
    if (context === undefined) { return; }
    const requestId = ++this.readerStatusBarIconRequestId;
    window.getLastWindow(context).then((targetWindow: window.Window) => {
      if (requestId !== this.readerStatusBarIconRequestId) { return; }
      targetWindow.setWindowSystemBarProperties({ statusBarContentColor: '#E5FFFFFF' }).catch(() => {});
    }).catch(() => {});
  }

  onDarkStatusIconChanged(): void {
    if (this.readerWindowActive) { this.applyReaderStatusBarIcon(); }
  }

  /**
   * 按 `readBrightness` 设窗口亮度。
   * 上游是 `window.attributes.screenBrightness = readBrightness / 100f`
   * （`ReadBookController.kt:3179-3187`，`brightnessAuto` 为真时用 `BRIGHTNESS_OVERRIDE_NONE` 交回系统）。
   * HOS 侧对应 `setWindowBrightness`：传 -1 表示恢复系统亮度。
   */
  private applyReaderBrightness(): void {
    const context = this.getUIContext().getHostContext();
    if (context === undefined) { return; }
    const requestId = ++this.readerBrightnessRequestId;
    // 自动亮度时把亮度交回系统：上游用 BRIGHTNESS_OVERRIDE_NONE，HOS 对应 -1。
    const value = this.brightnessAuto ? -1 : Math.max(0, Math.min(1, this.readBrightness / 100));
    window.getLastWindow(context).then((targetWindow: window.Window) => {
      if (requestId !== this.readerBrightnessRequestId) { return; }
      targetWindow.setWindowBrightness(value).catch(() => {});
    }).catch(() => {});
  }

  /** 退出阅读页时把窗口亮度交回系统（对应上游 `lp.screenBrightness = originalScreenBrightness`，`ReadBookController.kt:3192`）。 */
  private restoreReaderBrightness(): void {
    const context = this.getUIContext().getHostContext();
    if (context === undefined) { return; }
    const requestId = ++this.readerBrightnessRequestId;
    window.getLastWindow(context).then((targetWindow: window.Window) => {
      if (requestId !== this.readerBrightnessRequestId) { return; }
      targetWindow.setWindowBrightness(-1).catch(() => {});
    }).catch(() => {});
  }

  onReadBrightnessChanged(): void {
    if (this.readerWindowActive) { this.applyReaderBrightness(); }
  }

  /**
   * 读取显示缺口（刘海 / 挖孔）避让量并写进三个 inset 字段。
   * 对齐上游 `ReaderContentAvoidancePolicy.padding()`（`ui/book/read/ReaderContentAvoidancePolicy.kt:34-51`）：
   * 只有 `paddingDisplayCutouts` 打开时才把缺口算进正文可用区，关闭时一律按 0 处理。
   * 顶部不在这里避让：状态栏占位已盖住顶部缺口，与上游 `statusPlaceholderGone` 的判法一致。
   */
  private applyReaderDisplayCutout(): void {
    const context = this.getUIContext().getHostContext();
    if (context === undefined) { return; }
    window.getLastWindow(context).then((targetWindow: window.Window) => {
      let area: window.AvoidArea | undefined = undefined;
      try {
        area = targetWindow.getWindowAvoidArea(window.AvoidAreaType.TYPE_CUTOUT);
      } catch (error) {
        console.error(`[ReaderPage] 读取屏幕缺口区域失败: ${error}`);
        return;
      }
      if (area === undefined || area.visible !== true) {
        this.readerDisplayCutoutLeft = 0;
        this.readerDisplayCutoutRight = 0;
        this.readerDisplayCutoutBottom = 0;
      } else {
        // getWindowAvoidArea 返回 px，排版全部按 vp 计算，这里用 UIContext 换算一次。
        const uiContext = this.getUIContext();
        this.readerDisplayCutoutLeft = Math.max(0, uiContext.px2vp(area.leftRect.width));
        this.readerDisplayCutoutRight = Math.max(0, uiContext.px2vp(area.rightRect.width));
        this.readerDisplayCutoutBottom = Math.max(0, uiContext.px2vp(area.bottomRect.height));
      }
      if (this.readerWindowActive) { this.rebuildReaderPages(); }
    }).catch(() => {});
  }

  /**
   * 适配特殊样式变化：`[newpage]`/`<usehtml>` 的解释方式变了，正文语义文档要重建。
   * 上游是重读章节正文（`ContentProcessor.kt:173` + `ReaderChapterSource.kt:158-166`），
   * 本地正文由父组件传入，这里只重建分页并让渲染 revision 前进。
   */
  onAdaptSpecialStyleChanged(): void {
    this.readerContentRevision += 1;
    this.rebuildReaderPages();
  }

  /**
   * 底栏背景填充色。对齐上游 `ReadBookMenuBarShared.kt:49-85` 的
   * `containerColor = surfaceColor.copy(alpha = (blurAlpha/100).coerceAtMost(0.6f))`：
   * 不透明度取 `readMenuBlurAlpha / 100`，并且**上限 0.6**，保证背后正文始终透得出来。
   */
  private readerBottomBarFillColor(): string {
    return this.readerMenuTintAlphaString(this.readerMenuContainerBaseColor());
  }

  /**
   * 底栏背景渐变。对齐上游 `ReadMenuBlurStyle`：
   * - `0` 填充（Solid）：两段同色，视觉上是纯色，等价于只用 `backgroundColor`；
   * - `1` 渐变（Progressive）：上浓下淡，等价于上游 `ReaderMenuTintStyle.Gradient` 分支
   *   （`ReadBookMenuBarShared.kt:41-47` 把 Progressive 映射成 Gradient）。
   * 模糊模式（0 关闭 / 1 液态玻璃 / 2 雾化）在 ArkUI 侧没有逐帧背景采样等价物，
   * 用降低不透明度近似，因此不额外影响这里的渐变。
   */
  private readerBottomBarGradient(): LinearGradientOptions {
    const base = this.readerMenuContainerBaseColor();
    if (this.readMenuBottomBarBlurStyle !== 1) {
      const solid = this.readerMenuTintAlphaString(base);
      return {
        angle: 180,
        colors: [[solid, 0.0], [solid, 1.0]]
      };
    }
    const top = this.readerMenuTintAlphaString(base);
    const bottom = this.readerMenuTintAlphaString(base, 0.25);
    return {
      angle: 180,
      colors: [[top, 0.0], [bottom, 1.0]]
    };
  }

  /** 底栏按钮表面是否加玻璃底色；上游 `readMenuBottomBarLiquidGlassButtons`（`ReadSettings.kt:101`）。 */
  private readerBottomBarButtonGlassEnabled(): boolean {
    return this.readMenuBottomBarLiquidGlassButtons;
  }

  /**
   * 顶栏背景填充色。与底栏共用上游 `readMenuBlurAlpha`（`ReadSettings.kt:106`，
   * `ReadBookMenuBarShared.kt:49-85` 把不透明度上限夹到 0.6），因此直接复用同一折算。
   */
  private readerTopBarFillColor(): string {
    return this.readerMenuTintAlphaString(this.readerMenuContainerBaseColor());
  }

  /** 顶栏背景渐变，语义同底栏；样式取上游 `readMenuTopBarBlurStyle`（0 填充 / 1 渐变）。 */
  private readerTopBarGradient(): LinearGradientOptions {
    const base = this.readerMenuContainerBaseColor();
    if (this.readMenuTopBarBlurStyle !== 1) {
      const solid = this.readerMenuTintAlphaString(base);
      return {
        angle: 180,
        colors: [[solid, 0.0], [solid, 1.0]]
      };
    }
    const top = this.readerMenuTintAlphaString(base);
    const bottom = this.readerMenuTintAlphaString(base, 0.25);
    return {
      angle: 180,
      colors: [[top, 0.0], [bottom, 1.0]]
    };
  }

  /**
   * 顶栏按钮表面填充。对齐上游 `ReadBookMenuBarTitle.kt:534-540`：
   * `iconStyle == 1`（色调）时用 surfaceContainerLow 做底，其余透明。
   */
  private readerTopBarButtonFillColor(): string {
    return this.titleBarIconStyle === 1 ? '#2A2B31' : 'Transparent';
  }

  /**
   * 顶栏按钮描边宽度。对齐上游 `ReadBookMenuBarTitle.kt:436`：
   * `iconStyle == 2`（描边）时未开液态玻璃才画 1vp 半透明边。
   */
  private readerTopBarButtonBorderWidth(): number {
    if (this.titleBarIconStyle !== 2) {
      return 0;
    }
    return this.readMenuTopBarLiquidGlassButtons ? 0 : 1;
  }

  /** 顶栏按钮是否用合并胶囊容器（上游 `readMenuTopBarMergeButtons`，`ReadBookMenuBarTitle.kt:973`）。 */
  private readerTopBarMergeEnabled(): boolean {
    return this.readMenuTopBarMergeButtons;
  }

  /**
   * 当前纸色是不是深色。上游用 `ReadStyleResolver.isNightTheme()` 判断，
   * 本地没有独立日夜状态，按纸色亮度折算（与 Index.isReaderBackgroundLight 同一口径，
   * 阈值 0.5）。解析不出来时按「浅色」处理。
   */
  private readerMenuIsNight(): boolean {
    const raw = this.paperColor.trim().toUpperCase();
    let hex = '';
    if (/^#[0-9A-F]{6}$/.test(raw)) { hex = raw.substring(1); }
    else if (/^#[0-9A-F]{8}$/.test(raw)) { hex = raw.substring(3); }
    if (hex.length !== 6) { return false; }
    const channel = (shift: number): number => {
      const srgb = parseInt(hex.substring(shift, shift + 2), 16) / 255;
      return srgb <= 0.03928 ? srgb / 12.92 : Math.pow((srgb + 0.055) / 1.055, 2.4);
    };
    const luminance = 0.2126 * channel(0) + 0.7152 * channel(2) + 0.0722 * channel(4);
    return luminance < 0.5;
  }

  /**
   * 菜单基底色（不含透明度）。逐条照上游 `ReadBookConfig.kt:154-178` 的 `resolvedMenuBgColor`：
   * `0` 跟随系统 → 日间白、夜间黑；`1` 跟随阅读背景 → 取当前纸色；
   * `2` 自定义 → 取 `readMenuBgColor`/`Night`（空串表示未设置，回落跟随系统那一档）。
   * `readMenuColorMode == 0`（种子色）时上游用强调色派生整套色板，本地取强调色作基底近似。
   */
  private readerMenuBaseColor(): string {
    // 上游 `readMenuTintColor`（ReadBookMenuBarShared.kt:76-92）优先级最高：夜间取
    // `readMenuBlurColorNight`、日间取 `readMenuBlurColor`，任一非未设置就盖过整条底色推导。
    const tint = this.readerMenuTintColor();
    if (tint.length > 0) { return tint; }
    if (this.readBarStyle === 1) { return this.paperColor; }
    if (this.readBarStyle === 2) {
      const custom = this.readerMenuIsNight() ? this.readMenuBgColorNight : this.readMenuBgColor;
      if (custom.length > 0) { return custom; }
      if (this.readMenuColorMode === 0) { return this.readerMenuAccentTint(); }
    }
    return this.readerMenuIsNight() ? '#000000' : '#FFFFFF';
  }

  /**
   * 菜单容器色（不含透明度）。上游 `readMenuContainerColor`/`Night` 为 0 时回落菜单背景色
   * （`ReadBookConfig.kt:123-132`），因此空串直接继承基底色。
   */
  private readerMenuContainerBaseColor(): string {
    const custom = this.readerMenuIsNight() ? this.readMenuContainerColorNight : this.readMenuContainerColor;
    return custom.length > 0 ? custom : this.readerMenuBaseColor();
  }

  /**
   * 菜单强调色。上游 `resolvedMenuAccentColor`（`ReadBookConfig.kt:180-181`）取
   * `readMenuAccentColor`/`Night`；未设置时上游回落到主题色，本地沿用原有硬编码 `#FFB1C8`。
   * 上游「种子色」与「强调色」共用同一字段（`SystemMenuPage.kt:308-368`），这里同样只读一处。
   */
  private readerMenuAccentTint(): string {
    const custom = this.readerMenuIsNight() ? this.readMenuAccentColorNight : this.readMenuAccentColor;
    return custom.length > 0 ? custom : '#FFB1C8';
  }

  /**
   * 菜单模糊层着色。逐条照上游 `readMenuTintColor`（`ReadBookMenuBarShared.kt:76-92`）：
   * 夜间看 `readMenuBlurColorNight`、日间看 `readMenuBlurColor`；日间未设置时再回落
   * `readMenuBlurColor`（上游第三段 `takeIf { it != 0 }` 的兜底）。空串表示两端都没设置。
   */
  private readerMenuTintColor(): string {
    const day = this.readMenuBlurColor.trim();
    const night = this.readMenuBlurColorNight.trim();
    if (this.readerMenuIsNight()) {
      return night.length > 0 ? night : '';
    }
    return day.length > 0 ? day : '';
  }

  /**
   * 菜单前景色（文字与图标）。上游 `readMenuTextColor`（`ReadBookMenuBarShared.kt:107-115`）
   * 取日夜对应值，未设置时回落主题 `onSurface`；本地按菜单底色明暗反色充当该回落值。
   */
  private readerMenuForeground(): string {
    const custom = this.readerMenuIsNight() ? this.readMenuTextColorNight : this.readMenuTextColor;
    if (custom.trim().length > 0) { return custom.trim(); }
    return this.readerMenuIsNight() ? '#D5C2C6' : '#3E3D3B';
  }

  /**
   * 菜单栏边框配置。上游 `readMenuBorderWidth`（`ReadBookConfig.kt:115` 夹 0–4）同时充当
   * 开关与宽度：`> 0` 才画描边（`SystemMenuPage.kt:398` 的 `borderEnabled`）；
   * 颜色取日夜对应值，未设置回落到前景色的半透明（上游回落 `outlineVariant`）。
   */
  private readerMenuBorderSettings(): BorderOptions {
    const width = Math.max(0, Math.min(4, Math.round(this.readMenuBorderWidth)));
    if (width <= 0) {
      return { width: 0 };
    }
    const custom = this.readerMenuIsNight() ? this.readMenuBorderColorNight : this.readMenuBorderColor;
    const color = custom.trim().length > 0
      ? custom.trim()
      : this.readerMenuForegroundAlpha('73');
    return { width: width, color: color };
  }

  /** 菜单模糊半径（vp）。上游 `readMenuBlurRadius` 夹 0–32，0 表示不模糊。 */
  private readerMenuBlurRadiusVp(): number {
    return Math.max(0, Math.min(32, Math.round(this.readMenuBlurRadius)));
  }

  /** 把 `#RRGGBB` / `#AARRGGBB` 折成 6 位 RGB；解析不了时按当前日夜取黑白。 */
  private readerMenuRgb(color: string): string {
    const raw = color.trim().toUpperCase();
    if (/^#[0-9A-F]{6}$/.test(raw)) { return raw.substring(1); }
    if (/^#[0-9A-F]{8}$/.test(raw)) { return raw.substring(3); }
    return this.readerMenuIsNight() ? '000000' : 'FFFFFF';
  }

  /**
   * 给菜单色叠上 `readMenuBlurAlpha` 决定的不透明度。上游
   * `ReadBookMenuBarShared.kt:49-85` 的口径是 `(blurAlpha/100).coerceAtMost(0.6f)`，
   * 因此这里同样把上限压到 0.6，保证背后正文透得出来。
   * `delta` 供渐变用：第二段色再降一点不透明度，等价上游 `ReaderMenuTintStyle.Gradient`。
   */
  private readerMenuTintAlphaString(color: string, delta: number = 0): string {
    // 上游 `ReadBookMenuBarTitle.kt:95-101` / `ReadBookMenuBar.kt:481-497`：拖滑块时把
    // 不透明度压到 `coerceAtMost(30)`，松手回到 `readMenuBlurAlpha`；两者都再夹一次 0.6 上限。
    const percent = this.menuSliderDragging
      ? Math.min(30, Math.max(0, Math.min(100, this.readMenuBlurAlpha)))
      : Math.max(0, Math.min(100, this.readMenuBlurAlpha));
    const alpha = Math.min(0.6, percent / 100);
    const effective = Math.max(0, alpha - delta);
    const channel = Math.round(effective * 255).toString(16).padStart(2, '0').toUpperCase();
    return '#' + channel + this.readerMenuRgb(color);
  }

  /** 给菜单前景色套一个固定 alpha 前缀（本地原先把 `#73`/`#B3` 半透明前景写死）。 */
  private readerMenuForegroundAlpha(alphaHex: string): string {
    return '#' + alphaHex + this.readerMenuRgb(this.readerMenuForeground());
  }

  private stopAutoPageTimer(): void {
    if (this.autoPageTimer >= 0) {
      clearInterval(this.autoPageTimer);
      this.autoPageTimer = -1;
    }
    this.cancelAutoPageTurn();
  }

  private cancelAutoPageTurn(): void {
    if (this.autoPageTurnAnimator !== undefined) {
      this.autoPageTurnAnimator.cancel();
      this.autoPageTurnAnimator = undefined;
    }
    if (this.autoPageRevealVp !== 0) {
      this.autoPageRevealVp = 0;
      this.paintReaderCanvas();
    }
  }

  /**
   * 自动翻页的一个整页周期：逐帧推进，而不是整页跳。
   *
   * 上游 `ReaderCanvasSurface.kt:890-920`：分页模式每帧 `autoRevealPx += viewport / 时长 * 帧间隔`，
   * 满一屏就翻页并把 `autoRevealPx` 归零；滚动模式则把同样的速度摊到 `scrollOffset` 上。
   * 本地用 `createAnimator` 逐帧回调代替 `withFrameNanos` 循环。
   */
  private startAutoPageTurn(): void {
    this.cancelAutoPageTurn();
    if (!this.autoPageActive || this.controlsVisible || this.autoPageSettingsVisible ||
      this.autoPageWaitingForChapter) {
      return;
    }
    const context = this.getUIContext();
    const duration = Math.max(1, Math.round(this.autoReadSpeedSeconds * 1000));
    const scrollMode = this.usesCanvasScroll();
    const viewportPx = context.vp2px(Math.max(1, this.viewportHeight));
    let appliedPx = 0;
    const animator = context.createAnimator({
      duration, easing: 'linear', delay: 0, fill: 'forwards', direction: 'normal', iterations: 1, begin: 0, end: 1
    });
    animator.onFrame = (progress: number) => {
      const clamped = Math.max(0, Math.min(1, progress));
      if (scrollMode) {
        // 滚动模式没有「下一页」，整段时间匀速推进一屏（上游 SCROLL 分支同口径）
        const target = viewportPx * clamped;
        this.applyReaderScrollDelta(target - appliedPx);
        appliedPx = target;
        return;
      }
      this.autoPageRevealVp = context.px2vp(viewportPx * clamped);
      this.paintReaderCanvas();
    };
    animator.onFinish = () => {
      this.autoPageTurnAnimator = undefined;
      if (!scrollMode && this.autoPageRevealVp !== 0) {
        this.autoPageRevealVp = 0;
      }
      if (!this.autoPageActive) {
        this.paintReaderCanvas();
        return;
      }
      if (!this.canTurnToNext()) {
        // 上游在分页模式翻到头就停；滚动模式不自动关（由用户停）
        if (!scrollMode) {
          this.autoPageActive = false;
          this.paintReaderCanvas();
          return;
        }
        this.startAutoPageTurn();
        return;
      }
      if (this.currentPageIndex + 1 < this.localReaderPages.length) {
        this.turnReaderPage(1);
      } else {
        this.autoPageWaitingForChapter = true;
        this.onTurnChapterBoundary(1);
      }
      this.startAutoPageTurn();
    };
    this.autoPageTurnAnimator = animator;
    animator.play();
  }

  private toggleAutoPage(): void {
    if (this.autoPageActive) {
      this.autoPageSettingsVisible = true;
      return;
    }
    this.autoPageActive = true;
    this.autoPageSecondsRemaining = this.autoReadSpeedSeconds;
    this.stopAutoPageTimer();
    this.startAutoPageTurn();
  }

  private setAutoPageSpeed(seconds: number): void {
    const value = Math.max(1, Math.min(120, Math.round(seconds)));
    this.autoPageSecondsRemaining = value;
    this.onAutoReadSpeedChange(value);
  }

  onBookmarkTargetChanged(): void {
    if (this.bookmarkTargetPosition < 0) { return; }
    this.resolveStartPosition();
    this.pendingBookmarkTargetPosition = this.bookmarkTargetPosition;
    this.rebuildReaderPages(true);
  }

  onChapterTitleChanged(): void {
    this.resetPageTurnTransition();
    this.autoPageWaitingForChapter = false;
    this.readerProgress = this.book.chapterProgress ?? 0;
    this.lastReportedProgress = this.readerProgress;
    this.sliderProgressIndex = this.getChapterIndex();
    this.restoredProgressPosition = false;
    this.scrollOffset = 0;
    // 这里不再 rebuildReaderPages()：标题定稿后会赋值 displayChapterTitle，
    // 触发 onDisplayChapterTitleChanged() 再排一次，那才是标题真正落定的时机。
    // 两处都排就是同一章排两遍，换章时白白多一次全章测量。
    this.refreshDisplayChapterTitle();
    this.refreshContentProcesses();
  }

  onBookChanged(): void {
    // 换书不是换章：作废交接标记，下一次正文到达按「换书」处理（清空页表）。
    this.chapterHandoffBookId = '';
    this.chapterHandoffPending = false;
    this.chapterHandoffUpward = false;
    this.onReadSessionStart();
    this.refreshDisplayChapterTitle();
    this.refreshContentProcesses();
  }

  onReplaceRulesChanged(): void {
    this.refreshDisplayChapterTitle();
    this.refreshContentProcesses();
  }

  /** 划线/笔记增删改后重建渲染：run 的分段与装饰都在 ForEach key 里，必须换 key。 */
  onMarkingsChanged(): void {
    this.readerContentRevision++;
    // 画布是高亮/笔记的唯一出口：markings 变了必须重画，否则要等下一次翻页才刷新
    this.invalidateReaderCanvas();
  }

  /**
   * 预载本书的章节行。
   *
   * 上游用 Room，DAO 同步返回章节列表；relationalStore 只能异步读，
   * 所以这里先把章节行灌进 BookRepository 的缓存，页面上的同步访问器
   * （getChapterCount / getChapterIndex / 分页 key）才拿得到真目录。
   * 缓存原本为空（比如直接深链进来）时补读一次并重建分页。
   */
  private async loadChapterRows(): Promise<void> {
    const context = this.getUIContext().getHostContext();
    if (context === undefined) { return; }
    const before = BookRepository.cachedChapterTitles(this.book).length;
    try {
      await BookRepository.loadChapters(context, this.book);
    } catch (error) {
      console.error(`[ReaderPage] 加载章节目录失败: ${error}`);
      return;
    }
    if (before === 0 && BookRepository.cachedChapterTitles(this.book).length > 0) {
      this.rebuildReaderPages();
      this.refreshDisplayChapterTitle();
    }
  }

  private async refreshDisplayChapterTitle(): Promise<void> {
    const generation = ++this.titleGeneration;
    const title = this.chapterTitle;
    const bookId = this.book.id;
    const displayTitle = await ReplaceRuleRepository.applyTitle(this.book, title);
    // 这里不再 onReplaceRulesRefresh()：它会经 Index 刷新 replaceRules，
    // 而 ReplaceRuleRepository.getAll() 每次都 map 出新数组引用，必然触发
    // @Prop @Watch('onReplaceRulesChanged') → 本方法，形成自激循环（从目录跳章卡死）。
    if (generation === this.titleGeneration && bookId === this.book.id && title === this.chapterTitle) {
      this.displayChapterTitle = displayTitle;
    }
  }

  private async refreshContentProcesses(): Promise<void> {
    const bookId = this.book.id;
    const chapterIndex = this.getChapterIndex();
    await BookContentProcessRepository.waitUntilLoaded();
    if (bookId === this.book.id && chapterIndex === this.getChapterIndex()) {
      this.contentProcesses = BookContentProcessRepository.getForChapter(bookId, chapterIndex);
      this.effectiveReplaceRuleIds = BookRepository.getEffectiveReplaceRuleIds(bookId, chapterIndex);
    }
  }
  onDisplayChapterTitleChanged(): void {
    this.rebuildReaderPages();
  }

  onReaderContentChanged(): void {
    this.resetPageTurnTransition();
    this.refreshContentProcesses();
    // 新章正文到了，章边界提示页必须撤掉，否则会一直停在「加载数据中…」
    this.clearBoundaryMessage();
    this.readerContentRevision++;
    this.imageSizes = new Map<string, ReaderIntrinsicImageSize>();
    // KI-REL1：换章不再清空 `localReaderPages` / `currentPageIndex` / `scrollOffset`。
    // 上游换章是「先发布已有页、再补新页」（ReadBookController.kt:2949-2965），画布任何
    // 时刻都有 pages.current；本地是整章重排，一旦重建提前返回（视口为 0、格式不符，
    // 见 rebuildReaderPages 开头），空数组就让画布整屏空白。保留上一章页作过渡帧，
    // 新页排好后由 rebuildReaderPages() 整表替换，中间不留无内容的帧。
    // KI-REL1：换章方向在这里定：chapterProgress 由上层在换章时写成 0（向下）或 100（向上）。
    // 只有同一本书内换章才走交接；换书必须清空，否则会把上一本书的页画出来。
    const sameBook = this.chapterHandoffBookId === this.book.id;
    this.chapterHandoffUpward = sameBook && (this.book.chapterProgress ?? 0) >= 99;
    this.chapterHandoffPending = sameBook;
    if (!sameBook) {
      this.localReaderPages = [];
      this.currentPageIndex = 0;
      this.scrollOffset = 0;
    }
    this.chapterHandoffBookId = this.book.id;
    this.restoredProgressPosition = false;
    this.localSemanticContent = '';
    this.localSemanticDocument = { paragraphs: [], content: '', sourceLength: 0, sourcePositionMap: [0] };
    // 换章后同样先同步量一次：否则新章的图会先按行高占位排一遍，再被尺寸到达推一遍
    this.primeContentImageSizesSync();
    this.loadContentImageSizes();
    this.rebuildReaderPages();
  }

  onPaginationInputsChanged(): void {
    // 分页输入是整批下发的：约 30 个 @Prop 各自 @Watch，设置页一次保存会连续触发几十次。
    // 每次都全量重排会把主线程占满（开书那 1-2 秒的卡顿有它一份），这里合并成一帧后只排一次。
    this.scheduleReaderPaginationRebuild();
  }

  /** 防抖调度：同一轮内多次调用只留最后一次真正的重排。 */
  private scheduleReaderPaginationRebuild(): void {
    this.refreshReaderFontFamilies();
    if (this.paginationRebuildTimer >= 0) {
      clearTimeout(this.paginationRebuildTimer);
    }
    const delay = this.paginationRebuildDelayMillis;
    this.paginationRebuildDelayMillis = ReaderPage.PAGINATION_DEBOUNCE_MILLIS;
    this.paginationRebuildTimer = setTimeout(() => {
      this.paginationRebuildTimer = -1;
      // 这一轮如果只有图片尺寸变了，语义解析与高亮结果都没变，跳过那两步只重分页。
      const incremental = this.imageSizesRebuildPending;
      this.imageSizesRebuildPending = false;
      this.rebuildReaderPages(false, incremental);
    }, delay);
  }

  /**
   * 图片尺寸陆续到达时的专用防抖入口。
   *
   * 一本 20 张图的章节，尺寸是一张张异步量出来的；每张都走一次全章重排
   * （LocalTextSemantics.parse + findBodyRanges + 全量分页）就是 20 次全章测量，
   * 这是「图片章节开书慢、翻页卡」的主因。这里只标记「这轮是尺寸变化」，
   * 由统一的防抖定时器在窗口末尾排一次增量重排。
   */
  private scheduleImageSizesPaginationRebuild(): void {
    this.imageSizesRebuildPending = true;
    // 窗口取两者较大：布局输入和尺寸变化撞在一起时，按尺寸的窗口等，保证一批尺寸都到齐再排。
    this.paginationRebuildDelayMillis = ReaderPage.IMAGE_SIZES_DEBOUNCE_MILLIS;
    this.scheduleReaderPaginationRebuild();
  }

  private cancelPendingPaginationRebuild(): void {
    if (this.paginationRebuildTimer >= 0) {
      clearTimeout(this.paginationRebuildTimer);
      this.paginationRebuildTimer = -1;
    }
  }

  private refreshReaderFontFamilies(): void {
    const context = this.getUIContext().getHostContext();
    if (context === undefined) {
      this.readerBodyFontFamily = ReaderFontRepository.systemTypefaceFamily(this.systemTypefaces);
      this.readerTitleFontFamily = ReaderFontRepository.systemTypefaceFamily(this.systemTypefaces);
      return;
    }
    this.readerBodyFontFamily = ReaderFontRepository.resolveFamily(context, this.textFontPath, this.systemTypefaces);
    this.readerTitleFontFamily = ReaderFontRepository.resolveFamily(context, this.titleFontPath, this.systemTypefaces);
  }

  private readerInfoFontFamily(isHeader: boolean): string {
    const context = this.getUIContext().getHostContext();
    const path = isHeader ? this.infoSettings.headerFont : this.infoSettings.footerFont;
    if (context === undefined) { return ReaderFontRepository.systemTypefaceFamily(this.systemTypefaces); }
    return ReaderFontRepository.resolveFamily(context, path, this.systemTypefaces);
  }

  // 高亮规则自带的字体（上游 fontPath → family）：空路径返回空数组表示沿用正文
  private highlightRuleFontFamilies(path: string | null | undefined): string[] {
    if (path === undefined || path === null || path.length === 0) { return []; }
    const context = this.getUIContext().getHostContext();
    if (context === undefined) { return []; }
    return [ReaderFontRepository.resolveFamily(context, path, this.systemTypefaces)];
  }

  onProgressBehaviorChanged(): void {
    this.sliderProgressIndex = this.pageAnimation === 3
      ? this.readerProgress
      : (this.progressBehavior === 'page' && this.localReaderPages.length > 0
        ? this.currentPageIndex : this.getChapterIndex());
  }


  private closeReaderImagePreview(): void {
    if (!this.imagePreviewVisible) { return; }
    this.imagePreviewVisible = false;
    this.imagePreviewUri = '';
    this.onCloseImagePreview();
  }

  onImagePreviewCloseRevisionChanged(): void {
    this.closeReaderImagePreview();
  }

  onPageAnimationChanged(): void {
    this.resetPageTurnTransition();
    this.restoredProgressPosition = false;
    if (this.pageAnimation === 3) {
      this.scrollOffset = 0;
    } else {
      this.rebuildReaderPages();
    }
  }

  onImageStyleChanged(): void {
    this.activeImageStyle = this.imageStyle;
    this.readerContentRevision++;
    this.rebuildReaderPages();
  }

  private imageStyleLabel(style: string): string {
    if (style === 'FULL') { return '全屏'; }
    if (style === 'TEXT') { return '文字嵌入'; }
    if (style === 'SINGLE') { return '单页'; }
    return '默认';
  }

  private reverseContentByCodePoint(content: string): string {
    const characters: string[] = [];
    for (let index = 0; index < content.length; index++) {
      const firstUnit = content.charCodeAt(index);
      if (firstUnit >= 0xD800 && firstUnit <= 0xDBFF && index + 1 < content.length) {
        const secondUnit = content.charCodeAt(index + 1);
        if (secondUnit >= 0xDC00 && secondUnit <= 0xDFFF) {
          characters.push(content.substring(index, index + 2));
          index++;
          continue;
        }
      }
      characters.push(content.charAt(index));
    }
    let reversed: string = '';
    for (let index = characters.length - 1; index >= 0; index--) {
      reversed += characters[index] ?? '';
    }
    return reversed;
  }

  private chooseImageStyle(style: string): void {
    this.activeImageStyle = style;
    this.readerContentRevision++;
    this.rebuildReaderPages();
    this.onImageStyleChange(style);
    this.imageStyleMenuVisible = false;
    this.overflowVisible = false;
  }

  private openCharsetDialog(): void {
    this.charsetInput = this.book.charset ?? 'UTF-8';
    this.charsetOptionsExpanded = false;
    this.charsetDialogVisible = true;
  }

  private applyCharset(): void {
    this.charsetDialogVisible = false;
    this.charsetOptionsExpanded = false;
    this.onCharsetChange(this.charsetInput);
  }

  // -------------------------------------------------------------------------
  // 分页
  //
  // 尺寸驱动：`readerContentWidth` / `viewportHeight` 到位才分页，且分页输入变化走
  // 防抖调度（`scheduleReaderPaginationRebuild`），避免 40 个 @Prop 各触发一次全量重排。
  // 图片缺尺寸时用占位高度参与分页（对齐上游 ReaderChapterBlockMeasurer），
  // 绝不因为一张图没就绪就把整章分页作废。
  // -------------------------------------------------------------------------

  /**
   * 重排当前章。
   *
   * @param forceProgressCommit 排版完成后立即上报进度（书签跳转等需要落位时用）。
   * @param onlyImageSizesChanged 本次重排只因为图片尺寸到齐。
   *   为 true 时跳过 `LocalTextSemantics.parse` 与 `ReaderHighlightRuleEngine.findBodyRanges`
   *   这两步全章扫描，直接复用上一次的结果，只重跑分页。
   *   正文与高亮规则都没变，这两步的产物必然一样，重算纯属浪费——
   *   一本 20 张图的章节，尺寸一张张到齐会走 20 次，全章解析就是 20 遍。
   */
  private rebuildReaderPages(forceProgressCommit: boolean = false,
    onlyImageSizesChanged: boolean = false): void {
    if ((this.book.format !== 'txt' && this.book.format !== 'epub') ||
      this.readerContentWidth <= 0 || this.viewportHeight <= 0) {
      // KI-REL1：换章交接期间不清空页表。上游任何时刻都有 pages.current
      // （`ReaderCanvasSurface.kt:254` 的 `pages.current ?: return` 只是「没有就不画」），
      // 本地若在这里清空，视口一时为 0 就会让画布整屏空白——那正是闪烁。
      // 保留上一章的页当过渡帧，等视口就绪后这次重排会重跑并整表替换。
      if (!this.chapterHandoffPending) {
        this.localReaderPages = [];
        this.readerBottomJustifyGap = 0;
      }
      return;
    }
    const context = this.getUIContext();
    const measureUtils = context.getMeasureUtils();
    const fontSize = this.fontSize * 1.05;
    const width = this.getBodyContentWidth();
    const baseLineHeight = ReaderFontRepository.measureLineHeight(context, this.readerBodyFontFamily, fontSize);
    const lineHeight = Math.max(1, baseLineHeight * this.lineSpacing / 10);
    const infoHeaderReserve = this.isReaderHeaderVisible() ? this.getReaderInfoReserve(true) : 0;
    const infoFooterReserve = this.isReaderFooterVisible() ? this.getReaderInfoReserve(false) : 0;
    const formulaPageHeight = this.getBodyContentHeight(infoHeaderReserve, infoFooterReserve);
    // 画布实测高度优先：公式算的预留比实际占位小，只用公式会让最后一行被画布下边缘裁掉。
    const pageHeight = this.readerCanvasBodyHeightVp > 0
      ? Math.max(lineHeight, Math.min(formulaPageHeight, this.readerCanvasBodyHeightVp))
      : Math.max(lineHeight, formulaPageHeight);
    // Android 段距范围为 0–20，每一档按行高的十分之一计算。
    const paragraphSpacing = baseLineHeight * this.paragraphSpacing / 10;
    // 只有图片尺寸到齐时，语义解析与高亮匹配的输入完全没变，直接复用上一轮结果。
    // 复用的前提是上一轮真的解析过（paragraphs 非空），否则退回全量。
    const reuseSemantic = onlyImageSizesChanged && this.localSemanticDocument.paragraphs.length > 0;
    const document = reuseSemantic
      ? this.localSemanticDocument
      : LocalTextSemantics.parse(this.content, this.paragraphIndent, this.adaptSpecialStyle);
    if (!reuseSemantic) {
      this.localSemanticContent = document.content;
      const nextRanges = ReaderHighlightRuleEngine.findBodyRanges(document.content, this.readerHighlightRules);
      if (nextRanges.length !== this.readerHighlightRanges.length) {
        this.readerContentRevision++;
      }
      this.readerHighlightRanges = nextRanges;
      this.readerSizeOffsets = this.buildReaderSizeOffsets();
      this.localSemanticDocument = document;
    }
    // 图片尺寸是异步量的，开书那一两秒里通常还没到齐。
    // 旧实现只要有一张缺尺寸就整章分页作废、退回「整章滚动」，等尺寸到了再切回分页，
    // 带图章节因此要经历两轮排版切换。上游 ReaderChapterBlockMeasurer.kt:457-462 的处理是
    // `placeholderExtent = lineHeight.coerceAtLeast(1f)`，用行高做正方形占位继续排版，
    // 尺寸到达后再按新尺寸重排一次——排版只有一套，切换时不会整页跳。
    const paginationImageSizes = new Map<string, ReaderIntrinsicImageSize>(this.imageSizes);
    const placeholderExtent = Math.max(1, lineHeight);
    let placeholderUsed = false;
    for (let paragraphIndex = 0; paragraphIndex < document.paragraphs.length; paragraphIndex++) {
      const paragraph = document.paragraphs[paragraphIndex];
      if (paragraph === undefined) { continue; }
      for (let partIndex = 0; partIndex < paragraph.parts.length; partIndex++) {
        const part = paragraph.parts[partIndex];
        if (part?.kind === 'image' && !paginationImageSizes.has(part.value)) {
          paginationImageSizes.set(part.value, { width: placeholderExtent, height: placeholderExtent });
          placeholderUsed = true;
        }
      }
    }
    this.paginationUsesImagePlaceholder = placeholderUsed;
    // 章标题进块流（上游标题是带 `isTitle` 的普通文本块，`ReaderPaginator.kt:1112-1116`）。
    // 标题不再是「首屏预留几行」——预留会让标题脱离排版流，滚动模式下不跟着滚（KI-REL2）。
    const singleImageStyle = this.activeImageStyle === 'SINGLE';
    const titleBlock = this.buildReaderTitleBlock(context, width, lineHeight,
      document.content.length, singleImageStyle);
    const paginatedPages = LocalReaderPaginator.paginate(
      document,
      width,
      pageHeight,
      lineHeight,
      paragraphSpacing,
      (text: string): number => {
        return ReaderFontRepository.measureTextWidthForPagination(
          context, text, this.readerBodyFontFamily, fontSize, this.getReaderFontWeight()) +
          this.getReaderTextLetterSpacingWidth(text, fontSize);
      },
      paginationImageSizes,
      this.activeImageStyle,
      context.px2vp(80),
      (ReaderFontRepository.measureTextWidth(context, '袮', this.readerBodyFontFamily, fontSize) +
        this.getReaderLetterSpacingVp(fontSize)),
      // 标题已进流，首屏不再预留任何行。
      0,
      this.textFullJustify,
      this.resolveReaderColumnCount(),
      this.readerSizeOffsets,
      titleBlock,
      // 断行交给系统原生文本引擎，样式必须与绘制正文同一套。
      this.buildReaderTextLayoutStyle(fontSize),
      // 页身份的章号（页层批次 3）：单章页表只填字段、不改行为。
      this.getChapterIndex()
    );
    const nextPages: LocalReaderPage[] = [];
    for (let pageIndex = 0; pageIndex < paginatedPages.length; pageIndex++) {
      const page = paginatedPages[pageIndex];
      if (page !== undefined) { nextPages.push(page); }
    }
    const percentPosition = Math.round(this.localSemanticContent.length * (this.book.chapterProgress ?? 0) / 100);
    let targetPosition = percentPosition;
    if (this.pendingBookmarkTargetPosition >= 0) {
      targetPosition = this.pendingBookmarkTargetPosition;
    } else if (this.startPositionPending) {
      targetPosition = 0;
    } else {
      // 阅读位置只有一套语义：durChapterPos 存字符坐标，渲染前换算一次。
      // 旧的 readerPositionVersion 已随迁移删除，存量位置在搬迁时折进了 durChapterPos。
      const savedPosition = Math.max(0, this.book.androidCharacterPosition ?? 0);
      if (savedPosition > 0) {
        targetPosition = LocalTextSemantics.toRenderPosition(this.localSemanticDocument, savedPosition);
      }
    }
    let pageIndex = 0;
    // 阅读位置 0% 就该落在本章第一页——单图模式下第一页是标题页，
    // 不能被下面的 startPosition 比较跳过（标题页与正文首页的 startPosition 都是 0）。
    if (targetPosition <= 0) {
      pageIndex = 0;
    } else {
      for (let index = 0; index < nextPages.length; index++) {
        const page = nextPages[index];
        if (page === undefined || page.titleOnly) { continue; }
        if (page.startPosition > targetPosition) { break; }
        pageIndex = index;
      }
    }
    // KI-REL1：向上翻章时落到新章最后一页，与上游「往回翻落章末」一致
    // （ReadBookController.kt:1387-1389 注释：往回翻时邻章排好的页直接接上）。
    // 只在换章那一次生效，设置变化引起的重排仍按阅读位置定位。
    const isChapterHandoff = this.chapterHandoffPending;
    if (this.chapterHandoffUpward && this.pendingBookmarkTargetPosition < 0 && !this.startPositionPending) {
      for (let index = nextPages.length - 1; index >= 0; index--) {
        const page = nextPages[index];
        if (page === undefined || page.titleOnly) { continue; }
        pageIndex = index;
        break;
      }
    }
    this.chapterHandoffUpward = false;
    this.chapterHandoffPending = false;
    this.localReaderPages = nextPages;
    this.currentPageIndex = pageIndex;
    // KI-REL1：换章后滚动偏移归零。连续滚动的偏移是「当前页之前的页高之和 + 页内偏移」，
    // 页表换了之后旧偏移对新章没有意义，不清掉新章一开篇就停在中间。
    if (!this.usesCanvasScroll() || isChapterHandoff) {
      this.scrollOffset = 0;
    }
    this.readerBottomJustifyPageHeight = pageHeight;
    this.readerBottomJustifyLineHeight = lineHeight;
    // 标题已进块流、算进页容量，底部对齐不再需要额外扣掉标题预留。
    this.readerBottomJustifyTitleLines = 0;
    this.readerBottomJustifyGap = this.calculateReaderBottomJustifyGap(pageHeight, lineHeight, 0);
    // 排版结果变了，画布要按新页重画，并把四页窗口里会用到的图先解进缓存。
    // 上游 ReaderCanvasSurface.kt:414-430 在翻页前就把 current/next/previous/nextPlus 的图全部预载，
    // 注释原文「翻页前先把 LRU 解好，绘制期直读必然命中，新页就不会出现『有字无气泡』的那一两帧」。
    this.readerCanvasRenderer.clearParagraphs();
    this.prefetchReaderCanvasWindow();
    this.paintReaderCanvas();
    const consumedBookmarkTarget = this.pendingBookmarkTargetPosition >= 0;
    this.pendingBookmarkTargetPosition = -1;
    if (this.pageAnimation !== 3 && forceProgressCommit) {
      this.reportReaderPageProgress();
    } else if (this.pageAnimation !== 3) {
      this.sliderProgressIndex = this.progressBehavior === 'page'
        ? this.currentPageIndex : this.getChapterIndex();
    }
    this.requestFullBookPagination();
    if (consumedBookmarkTarget) { this.onBookmarkTargetConsumed(); }
  }

  private calculateReaderBottomJustifyGap(pageHeight: number, lineHeight: number, titleReservedLines: number): number {
    const gaps = this.calculateReaderBottomJustifyGaps(pageHeight, lineHeight, titleReservedLines);
    return gaps.length > 0 ? (gaps[0] ?? 0) : 0;
  }

  /**
   * 逐列的底部对齐位移（上游 `ReaderPaginator.justifyColumnBottom()`）。
   *
   * 上游按列各算一份：每列有自己的行数与剩余高度，把整页行数混在一起摊分会让
   * 短的那一列被推下去。返回数组长度 = 列数；不需要对齐时返回全 0。
   */
  private calculateReaderBottomJustifyGaps(pageHeight: number, lineHeight: number,
    titleReservedLines: number): number[] {
    const columns = Math.max(1, this.resolveReaderColumnCount());
    const zeros: number[] = [];
    for (let index = 0; index < columns; index++) { zeros.push(0); }
    if (!this.textBottomJustify) { return zeros; }
    // 连续滚动没有「页底」这个概念：页高就是内容高，把剩余高度摊进行间会把
    // 下一章的行推到本页已有的行上（画布按 extent 堆叠，靠位移区分页）。
    if (this.usesCanvasScroll()) { return zeros; }
    const page = this.localReaderPages[this.currentPageIndex];
    if (page === undefined || page.titleOnly || page.lines.length <= 1) { return zeros; }
    const result: number[] = [];
    for (let column = 0; column < columns; column++) {
      let columnLines = 0;
      let usedHeight = 0;
      let lastHeight = 0;
      let lastImageOnly = false;
      for (let index = 0; index < page.lines.length; index++) {
        const line = page.lines[index];
        if (line === undefined) { continue; }
        const lineColumn = page.lineColumns.length > index ? (page.lineColumns[index] ?? 0) : 0;
        if (lineColumn !== column) { continue; }
        columnLines++;
        usedHeight += line.verticalSpaceBefore + line.height + line.paragraphSpacingAfter;
        lastHeight = line.height;
        lastImageOnly = line.imageOnly;
      }
      if (columnLines <= 1 || lastImageOnly) { result.push(0); continue; }
      // 标题已进块流，页容量里已经扣过标题高度，这里不再二次扣预留。
      const surplus = pageHeight - usedHeight;
      // 上游两条提前返回：剩余高度还够一行（或为负）就不摊分
      if (surplus <= 0 || surplus >= lastHeight + lineHeight) { result.push(0); continue; }
      result.push(surplus / (columnLines - 1));
    }
    return result;
  }

  /** 只重算当前页的底部对齐位移，不重排分页（翻页路径专用）。 */
  private refreshReaderBottomJustifyGap(): void {
    if (this.readerBottomJustifyPageHeight <= 0 || this.readerBottomJustifyLineHeight <= 0) {
      return;
    }
    this.readerBottomJustifyGap = this.calculateReaderBottomJustifyGap(
      this.readerBottomJustifyPageHeight, this.readerBottomJustifyLineHeight,
      this.readerBottomJustifyTitleLines);
  }

  private reportReaderPageProgress(): void {
    const page = this.localReaderPages[this.currentPageIndex];
    if (page === undefined) { return; }
    this.resolveStartPosition();
    this.sliderProgressIndex = this.progressBehavior === 'page'
      ? this.currentPageIndex : this.getChapterIndex();
    const renderPosition = Math.max(0, Math.min(this.localSemanticContent.length, page.startPosition));
    const position = LocalTextSemantics.toSourcePosition(this.localSemanticDocument, renderPosition);
    const progress = this.localSemanticDocument.sourceLength > 0
      ? position / this.localSemanticDocument.sourceLength * 100 : 0;
    this.readerProgress = progress;
    this.lastReportedProgress = Math.round(progress);
    this.emitReaderProgress(progress, position, true);
  }

  private emitReaderProgress(progress: number, chapterPosition: number, androidCoordinate: boolean): void {
    this.onProgressChange(this.book.id, this.getChapterIndex(), progress, chapterPosition, androidCoordinate);
  }

  private getCurrentPageBookmarkRange(): ReaderBookmarkPageRange | undefined {
    const page = this.localReaderPages[this.currentPageIndex];
    if (page === undefined || page.titleOnly) { return undefined; }
    const renderStart = Math.max(0, Math.min(this.localSemanticContent.length, page.startPosition));
    const renderEnd = Math.max(renderStart, Math.min(this.localSemanticContent.length, page.endPosition));
    if (renderEnd <= renderStart) { return undefined; }
    const start = LocalTextSemantics.toSourcePosition(this.localSemanticDocument, renderStart);
    const end = LocalTextSemantics.toSourcePosition(this.localSemanticDocument, renderEnd);
    if (end <= start) { return undefined; }
    return { start: start, end: end, text: this.localSemanticContent.substring(renderStart, renderEnd).trim() };
  }

  /**
   * 当前页是否已有书签，用于决定右上角角标是否显示。
   * 与 `hasBookmarkOnCurrentPage()` 复用同一页码区间判断，但额外要求本书匹配。
   */
  private shouldShowBookmarkBadge(): boolean {
    if (this.bookmarkBadgeSize <= 0) { return false; }
    // 上游只在分页模式显示角标（滚动模式没有固定页面边界）。
    if (this.pageAnimation === 3) { return false; }
    if (!this.book.isLocal) { return false; }
    return this.hasBookmarkOnCurrentPage();
  }

  /**
   * 把设置里存的沙箱绝对路径转成 `Image()` 能读的 `file://` URI。
   * `Image()` 不接受裸沙箱路径，直接传会渲染成空白；设置里存的是路径本身，
   * 与 `BookGroupRepository`/`BookRepository` 存封面图的约定一致，前缀在渲染时补。
   */
  private badgeImageSource(): string {
    const path = this.bookmarkBadgeImage;
    return path.startsWith('file://') ? path : `file://${path}`;
  }

  /**
   * 右上角角标：有自定义图片时铺满整块区域，否则画默认黄色丝带。
   * 与上游 `ReaderBookmarkBadgeRenderer` 一致——自定义图片按 `ImageFit.Contain` 居中缩放，
   * 不用铺满，避免变形。
   */
  @Builder
  private BookmarkBadgeRibbon() {
    if (this.bookmarkBadgeImage.length > 0) {
      Image(this.badgeImageSource())
        .width(this.bookmarkBadgeSize)
        .height(this.bookmarkBadgeSize * 2)
        .objectFit(ImageFit.Contain)
    } else {
      Image($r('app.media.app_bookmark_badge'))
        .width(this.bookmarkBadgeSize)
        .height(this.bookmarkBadgeSize * 2)
        .objectFit(ImageFit.Fill)
    }
  }

  /**
   * 当前页可朗读的正文（上游 `ReaderAccessibilityPolicy.snapshot` 的 `text = current.text`，
   * 即当前页可见内容整段）。图片元素跳过，行间用换行分隔。
   */
  private getCurrentPageAccessibilityText(): string {
    const page = this.localReaderPages[this.currentPageIndex];
    if (page === undefined) { return ''; }
    if (page.messageText !== undefined && page.messageText.length > 0) { return page.messageText; }
    const lines: string[] = [];
    for (let index = 0; index < page.lines.length; index++) {
      const line = page.lines[index];
      if (line === undefined) { continue; }
      let text = '';
      for (let itemIndex = 0; itemIndex < line.items.length; itemIndex++) {
        const item = line.items[itemIndex];
        if (item === undefined || item.kind !== 'text') { continue; }
        text += item.value;
      }
      if (text.length > 0) { lines.push(text); }
    }
    return lines.join('\n');
  }

  /**
   * 画布的无障碍描述：正文 + 章节 + 翻页可用性。
   * 上游在 `Box.clearAndSetSemantics` 里一次性给出这几项（`ReaderCanvasSurface.kt:922-980`）：
   * `text`、书签状态、`verticalScrollAxisRange`（能否前后翻）、两个自定义动作（上一页/下一页）。
   */
  private getCanvasAccessibilityDescription(): string {
    const pageText = this.getCurrentPageAccessibilityText();
    const parts: string[] = [];
    if (pageText.length > 0) { parts.push(pageText); }
    parts.push(`第 ${this.getChapterIndex() + 1} 章 ${this.chapterTitle}`);
    return parts.join('\n');
  }

  /** 无障碍状态描述：书签状态 + 能否前后翻（上游 accessibilityPage 的 stateDescription 与滚动轴范围）。 */
  private getCanvasAccessibilityStateDescription(): string {
    const states: string[] = [];
    states.push(this.hasBookmarkOnCurrentPage() ? '本页已加书签' : '本页未加书签');
    states.push(`第 ${this.currentPageIndex + 1} 页，共 ${this.localReaderPages.length} 页`);
    return states.join('，');
  }

  /** 无障碍翻页：越界不动（上游 accessibilityPageTurn 的守卫）。 */
  private accessibilityTurnPage(forward: boolean): void {
    this.turnReaderPage(forward ? 1 : -1);
  }

  private hasBookmarkOnCurrentPage(): boolean {
    const pageRange = this.getCurrentPageBookmarkRange();
    if (pageRange === undefined) { return false; }
    const chapterIndex = this.getChapterIndex();
    for (let index = 0; index < this.bookmarks.length; index++) {
      const bookmark = this.bookmarks[index];
      if (bookmark !== undefined && bookmark.bookId === this.book.id &&
        bookmark.chapterIndex === chapterIndex && bookmark.chapterPosition >= pageRange.start &&
        bookmark.chapterPosition < pageRange.end) { return true; }
    }
    return false;
  }

  private updateBookmarkPull(event: GestureEvent): void {
    if (!this.swipeToAddBookmark || !this.book.isLocal || this.pageAnimation === 3 ||
      event.offsetY <= 0 || event.offsetY <= Math.abs(event.offsetX) * 1.5) {
      this.bookmarkPullOffset = 0;
      this.bookmarkPullArmed = false;
      return;
    }
    this.bookmarkPullOffset = Math.min(event.offsetY, Math.max(0, this.viewportHeight * 0.6));
    this.bookmarkPullArmed = event.offsetY >= 80;
  }

  private finishBookmarkPull(event: GestureEvent): void {
    this.updateBookmarkPull(event);
    const shouldToggle = this.bookmarkPullArmed;
    const pageRange = shouldToggle ? this.getCurrentPageBookmarkRange() : undefined;
    this.bookmarkPullOffset = 0;
    this.bookmarkPullArmed = false;
    if (pageRange !== undefined) {
      this.onToggleCurrentPageBookmark(pageRange.start, pageRange.end, pageRange.text);
    }
  }

  /**
   * 连续滚动的一次翻页（上游 `tapScrollPage`，ReaderCanvasSurface.kt:679-737）。
   *
   * 步距不是整屏而是「滚到只剩一行」（`ReaderScrollPolicy.pageStep`），
   * 时长按位移折算，缓动固定线性（上游 ScrollPageStack 的 tween 就是 LinearEasing）。
   */
  private turnReaderScrollPage(delta: number): void {
    const window = ReaderCanvasWindow.of(this.localReaderPages, this.currentPageIndex);
    const current = window.current;
    if (current === undefined) {
      return;
    }
    const context = this.getUIContext();
    const request = this.buildReaderCanvasRequest(new ReaderTransitionTransforms());
    const viewportExtentPx = context.vp2px(Math.max(1, this.viewportHeight));
    const contentTopPx = this.readerScrollContentTopPx(request);
    const contentBottomPx = contentTopPx + viewportExtentPx;
    const lines = this.readerCanvasRenderer.scrollLineBoxes(request);
    const isPrevious = delta < 0;
    const distancePx = ReaderScrollPolicy.pageStep(lines, contentTopPx, contentBottomPx,
      isPrevious, viewportExtentPx);
    if (this.noAnimScrollPage) {
      if (this.applyReaderScrollDelta(distancePx)) {
        this.onTurnChapterBoundary(delta > 0 ? 1 : -1);
      }
      return;
    }
    const baseDuration = [240, 300, 360, 540][this.animationSpeed] ?? 360;
    const duration = Math.max(1,
      ReaderScrollPolicy.stepDurationMillis(distancePx, viewportExtentPx, baseDuration));
    this.pageTurnAnimating = true;
    this.cancelTurnAnimator();
    let applied = 0;
    let hitBoundary = false;
    const animator = context.createAnimator({
      duration, easing: 'linear', delay: 0, fill: 'forwards', direction: 'normal', iterations: 1, begin: 0, end: 1
    });
    animator.onFrame = (progress: number) => {
      const target = distancePx * progress;
      if (this.applyReaderScrollDelta(target - applied)) {
        hitBoundary = true;
      }
      applied = target;
    };
    animator.onFinish = () => {
      this.pageTurnAnimating = false;
      this.turnAnimator = undefined;
      this.updateProgress();
      // 上游 tapScrollPage 触界抛 ReaderScrollBoundaryReached 直接跳出这一段，
      // 顺带把这一下点击转成翻章；本地在动画收尾时补同样的动作。
      if (hitBoundary) {
        this.onTurnChapterBoundary(delta > 0 ? 1 : -1);
      }
    };
    this.turnAnimator = animator;
    animator.play();
  }

  /** 滚动坐标系里正文区的顶边（画布局部 px）。 */
  private readerScrollContentTopPx(request: ReaderCanvasDrawRequest): number {
    // 画布自己从 0 开始画，正文顶边就是 layout.originYpx；页眉与标题在画布之外
    return request.layout.originYpx;
  }

  /**
   * 把一段滚动位移落到 scrollOffset 上，越过页边界就换窗口。
   *
   * 上游 `applyScrollResult`：跨页时若邻页还没排好（新窗口为 null），
   * 这次越界偏移是相对邻页坐标系的，直接写会把当前页画到页外，所以钳回边界。
   */
  private applyReaderScrollDelta(deltaPx: number): boolean {
    const pages = this.localReaderPages;
    if (pages.length === 0) {
      return false;
    }
    const context = this.getUIContext();
    const viewportExtentPx = context.vp2px(Math.max(1, this.viewportHeight));
    const request = this.buildReaderCanvasRequest(new ReaderTransitionTransforms());
    const window = request.window;
    const current = window.current;
    if (current === undefined) {
      return false;
    }
    const currentExtentPx = this.readerCanvasRenderer.pageScrollExtent(current.page, current.pageIndex, request);
    const previousExtentPx = window.previous === undefined ? 0
      : this.readerCanvasRenderer.pageScrollExtent(window.previous.page, window.previous.pageIndex, request);
    const result: ReaderScrollResult = ReaderScrollPolicy.apply(
      context.vp2px(this.scrollOffset), deltaPx, previousExtentPx, currentExtentPx,
      viewportExtentPx, window.previous !== undefined, window.next !== undefined);
    if (result.crossing === ReaderScrollCrossing.NEXT) {
      if (this.currentPageIndex + 1 >= pages.length) {
        // 章末：上游 reportScrollBoundary 在滚动模式下静默，这里也不弹提示。
        // 但章末要先亮「继续滑动以加载下一章…」提示页，否则用户以为滚到头了。
        this.scrollOffset = context.px2vp(result.offsetPx);
        this.showChapterBoundaryMessage(1);
        this.paintReaderCanvas();
        return true;
      }
      this.currentPageIndex = this.currentPageIndex + 1;
      this.resetCanvasSelectionState();
    } else if (result.crossing === ReaderScrollCrossing.PREVIOUS) {
      if (this.currentPageIndex === 0) {
        this.scrollOffset = context.px2vp(result.offsetPx);
        this.paintReaderCanvas();
        return true;
      }
      this.currentPageIndex = this.currentPageIndex - 1;
      this.resetCanvasSelectionState();
    }
    this.scrollOffset = context.px2vp(result.offsetPx);
    this.refreshReaderBottomJustifyGap();
    this.paintReaderCanvas();
    return result.hitBoundary;
  }

  /** 当前页还能不能往回翻：非首页，或上一章存在。 */
  private canTurnToPrevious(): boolean {
    return this.currentPageIndex > 0 || this.getChapterIndex() > 0;
  }

  /** 当前页还能不能往后翻：非末页，或下一章存在。 */
  private canTurnToNext(): boolean {
    return this.currentPageIndex + 1 < this.localReaderPages.length ||
      this.getChapterIndex() + 1 < this.getChapterCount();
  }

  /**
   * 横向拖动的逐帧更新（上游 `ReaderCanvasSurface.kt:1304-1330`）。
   *
   * 越过 touch-slop 时锁定方向并记下锁定点，之后位移都从锁定点算——
   * 上游注释：方向在 touch-slop 处捕获，可见位移从捕获点开始。
   * 折页模式另外写触点，让纸角跟着手指走。
   */
  private updateHorizontalPageDrag(event: GestureEvent): void {
    if (this.pageAnimation === 5) { return; }
    if (this.usesCanvasScroll()) { return; }
    const context = this.getUIContext();
    const slop = this.pageTouchSlop > 0 ? this.pageTouchSlop : 36;
    if (!this.horizontalDragLocked) {
      if (Math.abs(event.offsetX) < slop) { return; }
      this.horizontalDragLocked = true;
      this.horizontalDragOriginVp = event.offsetX;
      // 折页：记下锁定时的触点，收尾要把它送出对边
      if (this.turnMode === ReaderTransitionMode.SIMULATION) {
        this.curlRevealProgress = 1;
      }
    }
    const direction = captureReaderDragDirection(event.offsetX - this.horizontalDragOriginVp);
    if (direction === ReaderTransitionDirection.NONE) { return; }
    const pageExtentPx = context.vp2px(Math.max(1, this.readerContentWidth));
    const dragPx = context.vp2px(event.offsetX - this.horizontalDragOriginVp);
    const transition = ReaderPageTransitionPolicy.drag(direction, dragPx, pageExtentPx,
      this.canTurnToPrevious(), this.canTurnToNext());
    if (transition.direction === ReaderTransitionDirection.NONE) {
      this.horizontalDragLastOffsetVp = 0;
      return;
    }
    const mode = readerTransitionModeFromPageAnim(this.pageAnimation);
    this.turnMode = mode;
    this.turnTransition = transition;
    this.horizontalDragLastOffsetVp = context.px2vp(transition.offsetPx);
    if (mode === ReaderTransitionMode.SIMULATION) {
      const isPrevious = direction === ReaderTransitionDirection.PREVIOUS;
      const pageHeightPx = context.vp2px(Math.max(1, this.viewportHeight));
      const finger = event.fingerList !== undefined && event.fingerList.length > 0
        ? event.fingerList[0] : undefined;
      const fingerX = finger === undefined ? 0 : context.vp2px(finger.localX);
      const fingerY = finger === undefined ? 0 : context.vp2px(finger.localY);
      this.curlPrevious = isPrevious;
      this.curlCornerY = ReaderCurlTouchPolicy.cornerY(isPrevious, fingerY, pageHeightPx);
      this.curlTouchX = ReaderCurlTouchPolicy.dragX(isPrevious, fingerX, pageExtentPx);
      this.curlTouchY = ReaderCurlTouchPolicy.dragY(isPrevious, fingerY, fingerY, pageHeightPx);
    }
    this.paintReaderCanvas();
  }

  /**
   * 横向拖动松手（上游 `settlePageTurn(release(...))`）。
   *
   * 判定口径全在 `ReaderPageTransitionPolicy.release()`：位移过 35% 或甩动过 900 px/s 就翻，
   * 否则回弹。收尾动画从当前位移起步，不回到 0 再重放，避免松手瞬间画面跳一下。
   */
  private finishHorizontalPageDrag(event: GestureEvent): void {
    const locked = this.horizontalDragLocked;
    const startOffsetVp = this.horizontalDragLastOffsetVp;
    this.horizontalDragLocked = false;
    this.horizontalDragLastOffsetVp = 0;
    if (!locked) {
      // 兜底：某些注入式输入只给抬手不给逐帧回调，此时退回「按总位移判翻页」，
      // 保证翻页永远不会因为拿不到 update 而失灵。
      const slop = this.pageTouchSlop > 0 ? this.pageTouchSlop : 36;
      if (event.offsetX < -slop) { this.turnReaderPage(1); }
      else if (event.offsetX > slop) { this.turnReaderPage(-1); }
      return;
    }
    const context = this.getUIContext();
    const pageExtentPx = context.vp2px(Math.max(1, this.readerContentWidth));
    // ArkUI 的 velocityX 单位是 vp/s，正方向「左→右」，与 offsetX 同号
    const velocityPxPerSecond = context.vp2px(event.velocityX ?? 0);
    const transition = this.turnTransition;
    const mode = readerTransitionModeFromPageAnim(this.pageAnimation);
    // 淡入转场松手判定只要求过 10%，而且不看甩动速度：上游
    // ReaderCanvasSurface.kt:1455-1462 在 fade 时把 velocityPxPerSecond 传 0、
    // commitProgress 传 0.1f。否则屏幕上刚淡了一点的手势会被当成「没翻」弹回去。
    const fadeTurn = mode === ReaderTransitionMode.FADE;
    const decision = ReaderPageTransitionPolicy.release(transition, fadeTurn ? 0 : velocityPxPerSecond,
      undefined, false,
      fadeTurn ? ReaderPageTransitionPolicy.FADE_COMMIT_PROGRESS
        : ReaderPageTransitionPolicy.COMMIT_PROGRESS);
    const isPrevious = transition.direction === ReaderTransitionDirection.PREVIOUS;
    const targetOffsetPx = decision.targetOffsetPx;
    const currentOffsetPx = context.vp2px(startOffsetVp);
    const baseDuration = [240, 300, 360, 540][this.animationSpeed] ?? 360;
    if (mode === ReaderTransitionMode.NONE) {
      // 无动画：直接按判定结果落页
      this.turnMode = ReaderTransitionMode.NONE;
      this.turnTransition = new ReaderPageTransition();
      if (decision.commit) {
        this.commitDraggedPageTurn(isPrevious);
      } else {
        this.paintReaderCanvas();
      }
      return;
    }
    const duration = Math.max(1, ReaderPageTransitionPolicy.settleDurationMillis(
      mode, currentOffsetPx, targetOffsetPx, pageExtentPx, baseDuration));
    this.pageTurnAnimating = true;
    this.cancelTurnAnimator();
    const animator = context.createAnimator({
      duration: duration,
      easing: mode === ReaderTransitionMode.SIMULATION ? 'linear' : 'ease-out',
      delay: 0,
      fill: 'forwards',
      direction: 'normal',
      iterations: 1,
      begin: 0,
      end: 1
    });
    animator.onFrame = (progress: number) => {
      this.turnTransition.offsetPx = currentOffsetPx + (targetOffsetPx - currentOffsetPx) * progress;
      this.paintReaderCanvas();
    };
    animator.onFinish = () => {
      this.turnAnimator = undefined;
      this.pageTurnAnimating = false;
      this.turnTransition = new ReaderPageTransition();
      this.turnMode = ReaderTransitionMode.NONE;
      if (decision.commit) {
        this.commitDraggedPageTurn(isPrevious);
      } else {
        this.paintReaderCanvas();
      }
    };
    this.turnAnimator = animator;
    animator.play();
  }

  /**
   * 抬手惯性：把首帧速度交给指数衰减曲线，逐帧落到 scrollOffset 上。
   * 撞到章边界就停下（上游 `throw ReaderScrollBoundaryReached()` 跳出这段）。
   */
  private startReaderScrollFling(velocityYVpPerSecond: number): void {
    if (!this.usesCanvasScroll()) { return; }
    const context = this.getUIContext();
    const velocityPxPerSecond = context.vp2px(velocityYVpPerSecond);
    const totalPx = ReaderScrollDecay.totalDistance(velocityPxPerSecond);
    // 位移不到一行就不值得起动画，直接停住
    if (Math.abs(totalPx) < context.vp2px(8)) { return; }
    this.cancelTurnAnimator();
    let applied = 0;
    const animator = context.createAnimator({
      duration: ReaderScrollDecay.DURATION_MILLIS,
      easing: 'linear',
      delay: 0,
      fill: 'forwards',
      direction: 'normal',
      iterations: 1,
      begin: 0,
      end: 1
    });
    animator.onFrame = (progress: number) => {
      const target = ReaderScrollDecay.distanceAt(velocityPxPerSecond,
        progress * ReaderScrollDecay.DURATION_MILLIS);
      const step = target - applied;
      applied = target;
      if (step === 0) { return; }
      if (this.applyReaderScrollDelta(step)) {
        // 到章边界：惯性结束，把这一下转成翻章（与点击翻页同口径）
        this.cancelTurnAnimator();
        this.updateProgress();
        this.onTurnChapterBoundary(step < 0 ? 1 : -1);
      }
    };
    animator.onFinish = () => {
      this.turnAnimator = undefined;
      this.updateProgress();
    };
    this.turnAnimator = animator;
    animator.play();
  }

  /** 拖动翻页落地：改索引并重绘；到章边界就交给换章回调。 */  private commitDraggedPageTurn(isPrevious: boolean): void {
    const nextPageIndex = this.currentPageIndex + (isPrevious ? -1 : 1);
    if (nextPageIndex < 0 || nextPageIndex >= this.localReaderPages.length) {
      this.resetCanvasSelectionState();
      this.paintReaderCanvas();
      this.showChapterBoundaryMessage(isPrevious ? -1 : 1);
      this.onTurnChapterBoundary(isPrevious ? -1 : 1);
      return;
    }
    this.currentPageIndex = nextPageIndex;
    this.resetCanvasSelectionState();
    this.refreshReaderBottomJustifyGap();
    this.reportReaderPageProgress();
    this.paintReaderCanvas();
  }

  private turnReaderPage(delta: number): void {
    if (this.pageTurnAnimating) { return; }    if (this.usesReaderCanvas() && this.localReaderPages.length === 0) { return; }
    if (this.usesCanvasScroll()) {
      this.turnReaderScrollPage(delta);
      return;
    }
    const nextPageIndex = this.currentPageIndex + delta;
    this.resolveStartPosition();
    if (nextPageIndex < 0 || nextPageIndex >= this.localReaderPages.length) {
      this.showChapterBoundaryMessage(delta);
      this.onTurnChapterBoundary(delta);
      return;
    }
    if (this.pageAnimation === 5) {
      this.currentPageIndex = nextPageIndex;
      this.reportReaderPageProgress();
      // 无动画翻页也要重绘：currentPageIndex 是 @State 但没有 @Watch，画布不会自己刷新。
      this.paintReaderCanvas();
      return;
    }
    const durationBySpeed: number[] = [240, 300, 360, 540];
    const baseDuration = durationBySpeed[this.animationSpeed] ?? 360;
    // 翻页方向：进度只增不减，负值一律算 PREVIOUS（上游 ReaderHorizontalDrag.capture 同口径）
    const turnDirection = delta > 0 ? ReaderTransitionDirection.NEXT : ReaderTransitionDirection.PREVIOUS;
    const mode = readerTransitionModeFromPageAnim(this.pageAnimation);
    const pageExtentPx = this.getUIContext().vp2px(Math.max(1, this.readerContentWidth));
    const pageHeightPx = this.getUIContext().vp2px(Math.max(1, this.viewportHeight));
    const targetOffsetPx = turnDirection === ReaderTransitionDirection.NEXT ? -pageExtentPx : pageExtentPx;
    const isPrevious = turnDirection === ReaderTransitionDirection.PREVIOUS;
    // 仿真折页的触点起讫：起点由 ReaderCurlTouchPolicy.programmaticX/Y 给出，
    // 终点把纸页送过对边，时长按剩余距离折算（上游 settlePageTurn 同款）。
    const simulation = mode === ReaderTransitionMode.SIMULATION;
    const startCurlX = simulation ? ReaderCurlTouchPolicy.programmaticX(isPrevious, pageExtentPx) : 0;
    const startCurlY = simulation
      ? ReaderCurlTouchPolicy.programmaticY(isPrevious, this.curlTouchY, pageHeightPx) : 0;
    const endCurlX = isPrevious ? pageExtentPx : -pageExtentPx;
    const endCurlY = simulation
      ? ReaderCurlTouchPolicy.settledY(
        ReaderCurlTouchPolicy.cornerY(isPrevious, startCurlY, pageHeightPx), pageHeightPx) : 0;
    if (simulation) {
      this.curlPrevious = isPrevious;
      this.curlRevealProgress = 1;
      this.curlTouchX = startCurlX;
      this.curlTouchY = startCurlY;
      this.curlCornerY = ReaderCurlTouchPolicy.cornerY(isPrevious, startCurlY, pageHeightPx);
    }
    const duration = simulation
      ? Math.max(1, ReaderCurlTouchPolicy.settleDurationMillis(startCurlX, endCurlX, pageExtentPx, baseDuration))
      : Math.max(1,
        ReaderPageTransitionPolicy.settleDurationMillis(mode, 0, targetOffsetPx, pageExtentPx, baseDuration));
    this.pageTurnAnimating = true;
    this.turnMode = mode;
    this.turnTargetPageIndex = nextPageIndex;
    this.turnTransition = new ReaderPageTransition();
    this.turnTransition.direction = turnDirection;
    this.turnTransition.pageExtentPx = pageExtentPx;
    this.turnTransition.dragging = true;
    // 转场交给画布自己画：旧页盖在新页上滑走，中间不留空帧。
    // 不在这里用 animateTo 平移 ArkUI 节点——上游的位移是各页独立变换，不是整块视图移出再移回。
    this.cancelTurnAnimator();
    const animator = this.getUIContext().createAnimator({
      duration: duration,
      // 折页用线性：滑出本身就是主体动作，减速收尾会让人以为翻页卡住
      easing: simulation ? 'linear' : 'ease-out',
      delay: 0,
      fill: 'forwards',
      direction: 'normal',
      iterations: 1,
      begin: 0,
      end: 1
    });
    animator.onFrame = (progress: number) => {
      if (simulation) {
        this.curlTouchX = startCurlX + (endCurlX - startCurlX) * progress;
        this.curlTouchY = startCurlY + (endCurlY - startCurlY) * progress;
      } else {
        this.turnTransition.offsetPx = targetOffsetPx * progress;
      }
      this.paintReaderCanvas();
    };
    animator.onFinish = () => {
      this.currentPageIndex = this.turnTargetPageIndex;
      this.turnTargetPageIndex = -1;
      this.turnMode = ReaderTransitionMode.NONE;
      this.turnTransition = new ReaderPageTransition();
      this.pageTurnAnimating = false;
      this.turnAnimator = undefined;
      // 上游 ReaderSelectionLifecyclePolicy：程序化翻页要清选区，否则旧页的选区会画到新页上
      this.resetCanvasSelectionState();
      // 换页后按新页重算底部对齐位移（只换索引不重排，避免翻页时整页重排卡顿）
      this.refreshReaderBottomJustifyGap();
      this.reportReaderPageProgress();
      this.paintReaderCanvas();
    };
    this.turnAnimator = animator;
    animator.play();
  }

  /** 打断正在跑的转场动画（关页、换章、重建分页时都要先停）。 */
  private cancelTurnAnimator(): void {    const animator = this.turnAnimator;
    this.turnAnimator = undefined;
    if (animator !== undefined) {
      try {
        animator.cancel();
      } catch (error) {
        console.error(`[ReaderPage] 取消翻页动画失败: ${error}`);
      }
    }
  }

  private resetPageTurnTransition(): void {
    if (this.pageTurnTimer >= 0) {
      clearTimeout(this.pageTurnTimer);
      this.pageTurnTimer = -1;
    }
    this.cancelTurnAnimator();
    this.turnMode = ReaderTransitionMode.NONE;
    this.turnTransition = new ReaderPageTransition();
    this.turnTargetPageIndex = -1;
    this.pageTurnOffsetX = 0;
    this.pageTurnOffsetY = 0;
    this.pageTurnOpacity = 1;
    this.pageTurnAnimating = false;
  }

  private turnReaderChapter(delta: number): void {
    this.onSelectChapterIndex(this.getChapterIndex() + delta);
  }

  private handleReaderTap(event: ClickEvent): void {
    this.handleReaderTapAt(event.x, event.y);
  }

  /**
   * 点正文里的划线文字 = 打开该条笔记。
   *
   * 上游 `ui/book/read/ReadBookController.kt:591-620 onComposeReaderElementClick`：命中
   * `ReaderElement.Text` 时先看 `markingId != null` → `onMarkingClick(markingId)`；本地等价于
   * 「手指位置落在哪条划线的字符范围里」，用画布的 `positionAt` 拿到字符下标再比区间。
   *
   * 返回 true 表示这次点击已经被笔记消费掉，不再走分区动作。
   */
  private handleMarkingTap(x: number, y: number): boolean {
    if (this.markings.length === 0) {
      return false;
    }
    const context = this.getUIContext();
    const xpx = context.vp2px(x);
    const ypx = this.canvasContentY(this.canvasViewportY(context, y));
    const position = this.readerCanvasRenderer.positionAt(xpx, ypx, this.buildReaderCanvasStyle());
    if (position < 0) {
      return false;
    }
    const chapterIndex = this.getChapterIndex();
    for (let index = this.markings.length - 1; index >= 0; index--) {
      const marking = this.markings[index];
      if (marking === undefined || !marking.enabled || marking.chapterIndex !== chapterIndex) {
        continue;
      }
      if (marking.chapterPosition <= position && marking.endPosition > position) {
        this.onOpenMarking(marking.id);
        return true;
      }
    }
    return false;
  }

  /**
   * 点击正文里的图片：四档行为照上游 `ReadBookController.kt:674-693 handleComposeImageClick`。
   *
   * - `0`（默认）：单击开大图
   * - `1`：直接开大图
   * - `2`：只把图片动作交给书源处理；本地没有在线书源动作，等价于不响应
   * - `3`：不响应
   * - `4`：双击才开大图（双击窗口 300ms）
   *
   * 返回 true 表示这次点击已经被图片消费掉。
   */
  private handleImageTap(x: number, y: number): boolean {
    const way = this.clickImageBehavior;
    if (way === '3') {
      return false;
    }
    const context = this.getUIContext();
    const xpx = context.vp2px(x);
    const ypx = this.canvasContentY(this.canvasViewportY(context, y));
    const box = this.readerCanvasRenderer.hitTestImageBox(xpx, ypx);
    if (box === undefined || box.item === undefined) {
      return false;
    }
    const uri = box.item.value;
    if (uri.length === 0) {
      return false;
    }
    const now = Date.now();
    const debounced = now - this.imageTapTimestamp < 300;
    this.imageTapTimestamp = now;
    if (way === '2') {
      // 上游只有在「在线 TXT + 有 action」时才执行；本地没有图片动作来源，等同不响应。
      return false;
    }
    if (way === '4') {
      // 双击才执行：第一次点击只记账，第二次落在窗口内才开图。
      if (!debounced) {
        return true;
      }
      this.openReaderImagePreview(uri);
      return true;
    }
    // `0` 与 `1` 都是单击开大图（上游 `1` 无条件开、默认分支忽略 300ms 去抖）。
    this.openReaderImagePreview(uri);
    return true;
  }

  /** 打开图片大图预览（上游 `ReadBookSheet.Photo`）。 */
  private openReaderImagePreview(uri: string): void {
    if (uri.length === 0) {
      return;
    }
    this.imagePreviewUri = uri;
    this.imagePreviewVisible = true;
  }

  private handleReaderTapAt(x: number, y: number): void {
    const now = Date.now();
    if (now - this.lastReaderTapTimestamp < 90) { return; }
    this.lastReaderTapTimestamp = now;
    if (this.readerContentWidth <= 0 || this.viewportHeight <= 0) { return; }
    // 点划线文字优先于分区动作：命中了就打开那条笔记（上游 markingId 分支排在最前）。
    if (this.handleMarkingTap(x, y)) { return; }
    // 其次看图：命中图片就按 clickImgWay 四档处理（上游 onComposeReaderElementClick 的 Image 分支）。
    if (this.handleImageTap(x, y)) { return; }
    const column = Math.max(0, Math.min(2, Math.floor(x / this.readerContentWidth * 3)));
    const row = Math.max(0, Math.min(2, Math.floor(y / this.viewportHeight * 3)));
    this.performReaderTapAction(row * 3 + column);
  }

  /**
   * 正中格的临时优先级：自动翻页面板 / 搜索条收起，各自抢在用户配置的动作之前。
   *
   * 上游 `ui/book/read/ReadBookController.kt:626-634` 的 `showComposeActionMenu()` 用 `when`
   * 依次判「朗读中 → 自动翻页中 → 搜索结果显示中 → 主菜单」。本地没有朗读，搜索条是独立路由，
   * 所以只保留自动翻页这一档，其余交给用户配置的动作。
   *
   * 返回 true 表示这次点击已被优先级分支消费掉。
   */
  private shouldUseCenterPriorityTap(): boolean {
    if (!this.autoPageActive) {
      return false;
    }
    // 自动翻页进行中点正中：先开自动翻页面板（让用户能调速/关掉），而不是开主菜单。
    if (!this.autoPageSettingsVisible) {
      this.autoPageSettingsVisible = true;
      return true;
    }
    return false;
  }

  private performReaderTapAction(index: number): void {
    // 正中格有状态优先级：自动翻页中先开自动翻页面板、搜索条显示中先收起搜索条，
    // 否则才走用户配置的动作（上游 ReadBookController.kt:626-634 showComposeActionMenu）。
    if (index === 4 && this.shouldUseCenterPriorityTap()) {
      return;
    }
    const action = this.clickRegionActions[index] ?? '无操作';
    if (action === '无操作') { return; }
    if (action === '菜单') {
      setTimeout(() => {
        this.controlsVisible = !this.controlsVisible;
      }, 100);
      return;
    }
    if (action === '下一页') { this.turnReaderPage(1); return; }
    if (action === '上一页') { this.turnReaderPage(-1); return; }
    if (action === '下一章') { this.turnReaderChapter(1); return; }
    if (action === '上一章') { this.turnReaderChapter(-1); return; }
    if (action === '添加书签') { this.addCurrentPageBookmark(); return; }
    if (action === '编辑内容') {
      this.openContentEditor();
      return;
    }
    if (action === '替换(启用/禁用)') { this.onReplaceEnabledChange(!this.replaceEnabled); return; }
    if (action === '目录') { this.onOpenCatalog(); return; }
    if (action === '全文搜索') { this.onOpenSearchContent(); return; }
    if (action === '同步阅读进度') { this.reportReaderPageProgress(); return; }
    this.onUnavailableAction(`${action}功能尚未迁移`);
  }

  private isPageProgressMode(): boolean {
    return this.pageAnimation !== 3 && this.progressBehavior === 'page' && this.localReaderPages.length > 0;
  }

  private getProgressSliderMaximum(): number {
    if (this.pageAnimation === 3) { return 100; }
    return this.isPageProgressMode() ? this.localReaderPages.length - 1 : this.getChapterCount() - 1;
  }

  private getProgressSliderThumbRatio(): number {
    const maximum = this.getProgressSliderMaximum();
    if (maximum <= 0) { return 0; }
    return Math.max(0, Math.min(1, this.sliderProgressIndex / maximum));
  }

  private getChapterCount(): number {
    // 章节行已拆进 chapters 表，优先用缓存里的真实行数，其次退回 books 行的 totalChapterNum。
    const titles = BookRepository.cachedChapterTitles(this.book);
    if (titles.length > 0) {
      return titles.length;
    }
    const count = Number(this.book.chapterCount ?? '');
    return Number.isInteger(count) && count > 0 ? count : 1;
  }

  private getChapterIndex(): number {
    const chapterCount = this.getChapterCount();
    if (this.book.chapterIndex !== undefined) {
      return Math.max(0, Math.min(chapterCount - 1, this.book.chapterIndex));
    }
    const titles = BookRepository.cachedChapterTitles(this.book);
    const index = titles.indexOf(this.chapterTitle);
    if (index >= 0) {
      return index;
    }
    return Math.max(0, Math.min(chapterCount - 1, Math.floor(this.book.progress / 100 * chapterCount)));
  }

  private getBottomActionPages(): ReaderControlKind[][][] {
    const actions: ReaderControlKind[] = [];
    this.bottomActions.forEach((item: ReaderBottomActionConfig) => {
      const option = READER_ACTION_OPTIONS.find((action: ReaderActionOption) => action.id === item.id);
      if (item.enabled && option !== undefined &&
        isReaderActionApplicable(option.id, this.book.isLocal, this.book.format)) {
        actions.push(option.id);
      }
    });
    if (actions.length === 0) { return []; }
    const itemsPerRow = Math.max(2, Math.min(8, this.bottomItemsPerRow));
    const rowCount = Math.max(1, Math.min(2, this.bottomRowCount));
    const pageSize = itemsPerRow * rowCount;
    const pages: ReaderControlKind[][][] = [];
    for (let pageStart = 0; pageStart < actions.length; pageStart += pageSize) {
      const pageActions = actions.slice(pageStart, pageStart + pageSize);
      const rows: ReaderControlKind[][] = [];
      for (let rowStart = 0; rowStart < pageActions.length; rowStart += itemsPerRow) {
        rows.push(pageActions.slice(rowStart, rowStart + itemsPerRow));
      }
      pages.push(rows);
    }
    return pages.length > 0 ? pages : [[actions]];
  }

  private getVisibleTopActions(): ReaderBottomActionConfig[] {
    const actions: ReaderBottomActionConfig[] = this.topActions.filter((item: ReaderBottomActionConfig) => {
      const option = READER_ACTION_OPTIONS.find((candidate: ReaderActionOption) => candidate.id === item.id);
      return item.enabled && option !== undefined &&
        isReaderActionApplicable(option.id, this.book.isLocal, this.book.format);
    });
    if (this.titleBarCompact) {
      // 上游 ReadMenuActionDefs.kt:506：精简顶部按钮时直接退回只显示「更多」。
      return [{ id: 'more_actions', enabled: true }];
    }
    if (actions.length > 0) {
      // ArkUI 顶栏 Row 中后插入的配置项靠左，因此反转数据以保持视觉顺序与配置列表一致。
      // 上游 `ReadMenuActionDefs.kt:76` `MAX_TITLE_BAR_ACTIONS = 6`，`:493-517` 用 `take(6)`
      // 直接丢弃第 7 个及之后的动作（上游没有溢出菜单概念），这里按同一口径截断。
      return actions.reverse().slice(0, ReaderPage.MAX_TITLE_BAR_ACTIONS);
    }
    return [{ id: 'more_actions', enabled: true }];
  }

  private getTopActionKind(id: string): ReaderControlKind {
    const option = READER_ACTION_OPTIONS.find((candidate: ReaderActionOption) => candidate.id === id);
    return option?.id ?? 'more_actions';
  }

  /**
   * 顶栏动作按钮。图标配色对齐上游 `titleBarIconStyle`：
   * 0 纯色（透明底）、1 色调（surfaceContainerLow 底）、2 描边（1vp 半透明边）。
   */
  @Builder
  private topActionButton(action: ReaderBottomActionConfig) {
    Stack({ alignContent: Alignment.Center }) {
      ReaderControlGlyph({ kind: this.getTopActionKind(action.id), glyphSize: 20, menuForeground: this.readerMenuForeground(), menuAccent: this.readerMenuAccentTint() })
    }
    .width(40).height(40)
    .margin({ left: this.readerTopBarMergeEnabled() ? 0 : 6 })
    .borderRadius(20)
    .backgroundColor(this.readerTopBarMergeEnabled() ? Color.Transparent : this.readerTopBarButtonFillColor())
    .border({
      width: this.readerTopBarMergeEnabled() ? 0 : this.readerTopBarButtonBorderWidth(),
      color: this.readerMenuForegroundAlpha('73')
    })
    .onClick(() => {
      this.selectBottomAction(this.getTopActionKind(action.id));
    })
  }

  /**
   * 顶栏右侧动作区。合并模式下按上游 `ReadBookMenuBarTitle.kt:973-996` 收进一个胶囊容器；
   * 非合并模式逐个按钮独立排列。
   */
  @Builder
  private readerTopActionGroup() {
    if (this.readerTopBarMergeEnabled()) {
      // 上游 `ReadBookMenuBarTitle.kt:823-900` `MenuTitleBarMergedGlassButton`：
      // 40dp 高胶囊内 `actions.forEachIndexed` 逐个排，**相邻按钮之间插一条 1×20dp 分隔线**
      // （`:747-756` `MergedGlassDivider`，alpha 0.15）。这里同口径：按钮之间插分隔线。
      Row() {
        ForEach(this.getVisibleTopActions(), (action: ReaderBottomActionConfig, index: number) => {
          if (index > 0) {
            this.readerMergedGlassDivider()
          }
          this.topActionButton(action)
        }, (action: ReaderBottomActionConfig) => action.id)
      }
      .height(40).borderRadius(20).margin({ left: 6 })
      .backgroundColor(this.readerTopBarButtonFillColor())
      .border({ width: this.readerTopBarButtonBorderWidth(), color: this.readerMenuForegroundAlpha('73') })
    } else {
      // 非合并模式：上游 `ReadBookMenuBarTitle.kt:975-985` 是 `spacedBy(6.dp)` 逐个独立排列。
      ForEach(this.getVisibleTopActions(), (action: ReaderBottomActionConfig) => {
        this.topActionButton(action)
      }, (action: ReaderBottomActionConfig) => action.id)
    }
  }

  /**
   * 合并胶囊里的按钮分隔线，对齐上游 `ReadBookMenuBarTitle.kt:747-756` `MergedGlassDivider`：
   * 宽 1vp、高 20vp、前景色 15% 透明度，且不参与无障碍朗读。
   */
  @Builder
  private readerMergedGlassDivider() {
    Column()
      .width(1).height(20)
      .backgroundColor(this.readerMenuForegroundAlpha('26'))
      .accessibilityLevel('no')
  }

  /**
   * 标题栏胶囊：把书名与章节名压成一行两段，对齐上游 `ReadBookMenuBarTitle.kt:492-620`
   * 的 `TitleCapsuleGlassLayout`（书名中等字重 + 章名小字 0.7 透明）。
   */
  @Builder
  private readerTitleCapsule() {
    Column() {
      Text(this.book.title).fontSize(14).fontWeight(FontWeight.Medium).fontColor(this.readerMenuForeground()).maxLines(1)
        .width('100%').textOverflow({ overflow: TextOverflow.Ellipsis })
      if (this.displayChapterTitle.length > 0) {
        Text(this.displayChapterTitle).fontSize(11).fontColor(this.readerMenuForegroundAlpha('B3')).maxLines(1)
          .width('100%').margin({ top: 2 }).textOverflow({ overflow: TextOverflow.Ellipsis })
      }
    }
    .layoutWeight(1).alignItems(HorizontalAlign.Start)
    .padding({ left: 12, right: 12, top: 4, bottom: 4 })
    .borderRadius(20)
    .backgroundColor(this.readerTopBarButtonFillColor())
    .border({ width: this.readerTopBarButtonBorderWidth(), color: this.readerMenuForegroundAlpha('73') })
    // 上游 `ReadBookMenuBarTitle.kt:492-600` `TitleCapsuleGlassLayout` 整块 combinedClickable：
    // 单击进书籍详情（OpenBookInfo）、长按直接进详情（OpenBookInfoDirect）。本地没有「阅读信息
    // Sheet」这个中间态，两种手势都落到书籍详情页 `AppRoute.BOOK_INFO`。
    .onClick(() => this.onOpenBookInfo())
    .gesture(LongPressGesture({ duration: 500 }).onAction((_event: GestureEvent): void => {
      this.onOpenBookInfo();
    }))
  }

  /** 顶栏是否显示行内书名（非胶囊模式且模式为 "0" 或 "2"）。 */
  private readerTitleInlineVisible(): boolean {
    return !this.readMenuTopBarTitleCapsule && this.titleBarMode !== '1' && this.titleBarMode !== '3';
  }

  /** 顶栏是否显示独立的书名行（模式 "1"，上游 `ReadBookMenuBarTitle.kt:239`）。 */
  private readerTitleOwnLineVisible(): boolean {
    return !this.readMenuTopBarTitleCapsule && this.titleBarMode === '1';
  }

  /** 顶栏是否显示章节行（模式 "0" 或 "1"，上游 `ReadBookMenuBarTitle.kt:259`）。 */
  private readerChapterLineVisible(): boolean {
    return !this.readMenuTopBarTitleCapsule &&
      (this.titleBarMode === '0' || this.titleBarMode === '1');
  }

  /** 顶栏是否显示胶囊（非模式 "3"；上游 `ReadBookMenuBarTitle.kt:198`）。 */
  private readerTitleCapsuleVisible(): boolean {
    return this.readMenuTopBarTitleCapsule && this.titleBarMode !== '3';
  }

  /**
   * 进度条的无障碍文案。上游 `ReadBookMenuBarBottom.kt:84-95` 用
   * `a11y_read_progress_page`（第 x / 共 y 页）或 `a11y_read_progress_chapter`（第 x / 共 y 章），
   * 选哪个看 `progressBarBehavior`（`ReadSettings.kt` 的 `progressBarBehavior`）。
   */
  private getProgressAccessibilityText(): string {
    const maximum = Math.max(0, this.getProgressSliderMaximum());
    const total = maximum + 1;
    const current = Math.max(0, Math.min(maximum, Math.round(this.sliderProgressIndex))) + 1;
    if (this.isPageProgressMode()) {
      return `第 ${current} / 共 ${total} 页`;
    }
    return `第 ${current} / 共 ${total} 章`;
  }

  /**
   * 底栏按钮右上角角标数。上游 `ReadBookMenuBarTool.kt:337` 只给「替换净化」按钮
   * （`replace_badge`）挂角标，值取 `state.effectiveReplaceCount` —— 即**本章真正被改写过**
   * 的规则条数（`ContentProcessor.kt:202` 只有 `mContent != tmp` 才计入），不是「已启用条数」。
   * 本地在 `BookRepository.rememberEffectiveReplaceRules` 里按章缓存同一口径。
   */
  private getBottomActionBadgeCount(kind: ReaderControlKind): number {
    if (kind !== 'replace_badge') { return 0; }
    return this.effectiveReplaceRuleIds.length;
  }

  private getBottomActionPageIndex(): number {
    return Math.max(0, Math.min(this.currentBottomActionPage, this.getBottomActionPages().length - 1));
  }

  /**
   * 浮动图标行的图标序列：与顶栏操作按钮同池（上游 `ReadBookMenuBarFloating.kt:411`
   * 直接读 `menuConfig.titleBarButtons`），只保留启用且对本书适用的项。
   */
  private readerFloatingIconKinds(): ReaderControlKind[] {
    const kinds: ReaderControlKind[] = [];
    this.floatingIcons.forEach((item: ReaderBottomActionConfig) => {
      const option = READER_ACTION_OPTIONS.find((action: ReaderActionOption) => action.id === item.id);
      if (item.enabled && option !== undefined &&
        isReaderActionApplicable(option.id, this.book.isLocal, this.book.format)) {
        kinds.push(option.id);
      }
    });
    return kinds;
  }

  /** 位置 0/2 靠左、1/3 靠右（上游 `ReadBookMenuBar.kt:172` 与 `:310-330` 的 Alignment 选择）。 */
  private readerFloatingIconAlignment(position: number): FlexAlign {
    return position === 0 || position === 2 ? FlexAlign.Start : FlexAlign.End;
  }

  /** 顶栏区的浮动图标行只在位置 0/1 出现。 */
  private readerFloatingIconTopVisible(): boolean {
    return this.showTitleBarIcons && this.titleBarIconPosition <= 1;
  }

  /**
   * 搜索结果浮层是否显示。上游 `ReadBookSearchBar.kt:24-95`：
   * `isShowingSearchResult && searchMenuVisible && !menuVisible` ——
   * 打开了主菜单就把搜索结果条让出去，收起菜单再回来。
   */
  private searchResultOverlayVisible(): boolean {
    return this.searchNavItems.length > 0 && this.searchNavIndex >= 0 &&
      this.searchNavIndex < this.searchNavItems.length && !this.controlsVisible;
  }

  /** 当前搜索结果所在章名；越界时给空串。 */
  private currentSearchNavTitle(): string {
    const item = this.searchNavItems[this.searchNavIndex];
    return item === undefined ? '' : item.chapterTitle;
  }

  /** 结果集换了（比如跳到了另一个结果），浮层要跟着重画。 */
  private onSearchNavIndexChanged(): void {
    this.paintReaderCanvas();
  }

  /** 菜单浮层区的浮动图标行只在位置 2/3 出现。 */
  private readerFloatingIconBottomVisible(): boolean {
    return this.showTitleBarIcons && this.titleBarIconPosition >= 2;
  }

  /** 自定义图标的 `file://` URI；未自定义时返回空串，调用方回落到内置字形。 */
  private readerFloatingIconCustomUri(kind: string): string {
    const icons: Map<string, string> = ReaderSettingsRepository.decodeCustomIconMap(this.titleBarCustomIcons);
    const path: string | undefined = icons.get(kind);
    if (path === undefined || path.length === 0) { return ''; }
    return path.startsWith('file://') ? path : `file://${path}`;
  }

  /**
   * 单个浮动图标。自定义图片走圆形裁切（上游 `ReadBookMenuBarFloating.kt:63-150` 的
   * `AsyncImage(clip = CircleShape)`）；否则用内置字形。液态玻璃开关只影响底色：
   * 打开时用半透明容器，关闭时透明底（对齐上游 `ReadMenuGlassButtonSurface` 的 glassEnabled）。
   */
  @Builder
  private readerFloatingIconButton(kind: ReaderControlKind) {
    Stack({ alignContent: Alignment.Center }) {
      if (this.readerFloatingIconCustomUri(kind).length > 0) {
        Image(this.readerFloatingIconCustomUri(kind)).width(24).height(24)
          .objectFit(ImageFit.Cover).borderRadius(12)
      } else {
        ReaderControlGlyph({
          kind: kind,
          glyphSize: 20,
          active: (kind === 'autoPage' && this.autoPageActive) ||
            (kind === 'eye_protection' && this.eyeProtectionActive),
          menuForeground: this.readerMenuForeground(),
          menuAccent: this.readerMenuAccentTint()
        })
      }
    }
    .width(36).height(36).borderRadius(18)
    .backgroundColor(this.readMenuFloatingIconLiquidGlass ? this.readerMenuForegroundAlpha('1F') : '#00000000')
    .onClick(() => this.selectBottomAction(kind))
    .gesture(LongPressGesture({ duration: 500 }).onAction((_event: GestureEvent): void => {
      this.longSelectBottomAction(kind);
    }))
  }

  /** 浮动图标整行，对齐上游 `FloatingIconRow`（`ReadBookMenuBarFloating.kt:63-150`）。 */
  @Builder
  private readerFloatingIconRow(position: number) {
    Row() {
      ForEach(this.readerFloatingIconKinds(), (kind: ReaderControlKind) => {
        this.readerFloatingIconButton(kind)
      }, (kind: ReaderControlKind) => kind)
    }
    .width('100%')
    .justifyContent(this.readerFloatingIconAlignment(position))
    .padding({ left: 16, right: 16, top: 4, bottom: 4 })
  }

  private getBottomActionLabel(kind: string): string {
    const option = READER_ACTION_OPTIONS.find((item: ReaderActionOption) => item.id === kind);
    return option?.label ?? kind;
  }

  private selectBottomAction(kind: ReaderControlKind): void {
    if (kind === 'catalog') { this.onOpenCatalog(); }
    else if (kind === 'search') { this.onOpenSearchContent(); }
    else if (kind === 'autoPage') { this.toggleAutoPage(); }
    else if (kind === 'voice') { this.onUnavailableAction('朗读播放尚未迁移'); }
    else if (kind === 'settings') { this.onOpenSettings(); }
    else if (kind === 'addBookmark') { this.addCurrentPageBookmark(); }
    else if (kind === 'theme') { this.onToggleNightMode(); }
    else if (kind === 'eye_protection') { this.onToggleEyeProtection(); }
    else if (kind === 'prev_chapter') { this.onTurnChapterBoundary(-1); }
    else if (kind === 'next_chapter') { this.onTurnChapterBoundary(1); }
    // 上游 `ReadMenuActionDefs.kt:443-449` 的 `replace` 与 `replace_badge` 是同一个面板，
    // 区别只在后者右上角多一枚「本章命中条数」角标。
    else if (kind === 'replace' || kind === 'replace_badge') { this.textProcessingVisible = true; }
    else if (kind === 'more_actions') { this.overflowVisible = true; }
    else if (kind === 'charset') { this.openCharsetDialog(); }
    else if (kind === 'toc_rule') { this.onOpenTocRule(); }
    else { this.onUnavailableAction(this.getBottomActionLabel(kind) + '功能尚未迁移'); }
  }

  /**
   * 打开「编辑内容」弹层。
   *
   * 打开时先按当前 `adaptSpecialStyle` 扫一遍非正文片段（`<img>`、`<usehtml>` 整段、
   * `[newpage]`），折叠开关与保存时的插回都复用这同一份扫描结果——上游
   * `ReadContentEditDelegate.adopt()` 也是打开时扫一次、之后不再重扫。
   */
  private openContentEditor(): void {
    this.contentEditTitle = this.chapterTitle;
    this.contentEditBody = this.content;
    this.contentEditHiddenSpans = scanHiddenSpans(this.content, this.adaptSpecialStyle);
    this.contentEditBodyOnly = false;
    this.contentEditVisible = true;
  }

  /** 切换「仅正文」：只改编辑框显示的文字，不动 `contentEditBody` 保存时的还原依据。 */
  private setContentEditBodyOnly(enabled: boolean): void {
    if (enabled === this.contentEditBodyOnly) {
      return;
    }
    if (enabled) {
      this.contentEditBody = toBodyOnly(this.contentEditBody, this.contentEditHiddenSpans);
    } else {
      this.contentEditBody = toRawText(this.contentEditBody, this.contentEditHiddenSpans);
    }
    this.contentEditBodyOnly = enabled;
  }

  private addCurrentPageBookmark(): void {
    const page = this.localReaderPages[this.currentPageIndex];
    if (page === undefined) {
      this.onUnavailableAction('当前页尚未完成分页，暂时无法添加书签');
      return;
    }
    const start = Math.max(0, Math.min(this.localSemanticContent.length, page.startPosition));
    const end = Math.max(start, Math.min(this.localSemanticContent.length, page.endPosition));
    this.onAddBookmark(start, this.localSemanticContent.substring(start, end).trim());
  }

  private longSelectBottomAction(kind: ReaderControlKind): void {
    if (kind === 'voice') { this.onOpenReadAloud(); }
  }

  private isMoreActionApplicable(id: string): boolean {
    if (id === 'source_custom_button') { return false; }
    if (id === 'change_source' || id === 'refresh' || id === 'download') { return !this.book.isLocal; }
    if (id === 'toc_rule') { return this.book.isLocal && this.book.format === 'txt'; }
    if (id === 'charset') { return this.book.isLocal; }
    if (id === 'del_ruby' || id === 'del_h') { return this.book.isLocal && this.book.format === 'epub'; }
    if (id === 'get_progress' || id === 'cover_progress') { return false; }
    return true;
  }

  /** 更多操作分页：每页 8 格（2 行 × 4 列），对齐上游 ReaderMoreActionsSheet.kt 的 chunked(8)。 */
  private getMoreActionPages(): ReaderMoreAction[][] {
    const visible: ReaderMoreAction[] = this.getVisibleMoreActions();
    const pages: ReaderMoreAction[][] = [];
    for (let index = 0; index < visible.length; index += 8) {
      pages.push(visible.slice(index, index + 8));
    }
    return pages.length > 0 ? pages : [[]];
  }

  /** 格子底部是否画展开箭头：上游只有换源 / 刷新 / 自定义按钮三项有二级菜单。 */
  private moreActionHasSubmenu(id: string): boolean {
    return id === 'change_source' || id === 'refresh' || id === 'source_custom_button';
  }

  private getVisibleMoreActions(): ReaderMoreAction[] {
    const actions: ReaderMoreAction[] = [];
    this.moreActions.forEach((config: ReaderMoreActionConfig) => {
      const action = READER_MORE_ACTIONS.find((item: ReaderMoreAction) => item.id === config.id);
      if (config.enabled && action !== undefined && this.isMoreActionApplicable(action.id)) {
        actions.push(action);
      }
    });
    return [...actions, MORE_ACTION_CONFIG_ENTRY];
  }

  private getMoreAction(id: string): ReaderMoreAction | undefined {
    return READER_MORE_ACTIONS.find((item: ReaderMoreAction) => item.id === id);
  }

  private openMoreActionConfig(): void {
    this.draftMoreActions = this.moreActions.map((item: ReaderMoreActionConfig): ReaderMoreActionConfig => ({
      id: item.id,
      enabled: item.enabled
    }));
    this.moreActionConfigVisible = true;
  }

  private toggleMoreAction(id: string): void {
    this.draftMoreActions = this.draftMoreActions.map((item: ReaderMoreActionConfig): ReaderMoreActionConfig => ({
      id: item.id,
      enabled: item.id === id ? !item.enabled : item.enabled
    }));
  }

  private moveMoreAction(index: number, delta: number): void {
    const target = index + delta;
    if (target < 0 || target >= this.draftMoreActions.length) { return; }
    const updated = this.draftMoreActions.map((item: ReaderMoreActionConfig): ReaderMoreActionConfig => ({
      id: item.id,
      enabled: item.enabled
    }));
    const current = updated[index];
    const neighbor = updated[target];
    if (current === undefined || neighbor === undefined) { return; }
    updated[index] = neighbor;
    updated[target] = current;
    this.draftMoreActions = updated;
  }

  @Builder
  private moreActionConfigRow(config: ReaderMoreActionConfig, index: number) {
    Row() {
      AppGlyph({ name: this.getMoreAction(config.id)?.glyph ?? 'more', glyphSize: 20,
        tint: config.enabled ? this.readerMenuForeground() : '#777984' }).margin({ right: 12 })
      Column() {
        Text(this.getMoreAction(config.id)?.label ?? config.id).fontSize(14)
          .fontColor(config.enabled ? '#E5E6EB' : '#777984')
        if ((this.getMoreAction(config.id)?.scopeLabel ?? '').length > 0) {
          Text(this.getMoreAction(config.id)?.scopeLabel ?? '')
            .fontSize(10).fontColor(this.themeColorTextTertiary).margin({ top: 2 })
        }
        if (this.getMoreAction(config.id)?.migrated === false) {
          Text('未迁移').fontSize(10).fontColor(this.themeColorTextTertiary).margin({ top: 2 })
        }
      }.layoutWeight(1).alignItems(HorizontalAlign.Start)
      Stack({ alignContent: Alignment.Center }) {
        Image(config.enabled ? $r('app.media.app_visibility') : $r('app.media.reader_visibility_off'))
          .width(20).height(20).fillColor(config.enabled ? this.readerMenuForeground() : '#777984')
      }.width(36).height(36).borderRadius(18).backgroundColor('#292A31')
        .onClick(() => this.toggleMoreAction(config.id))
      Column() {
        Image($r('app.media.reader_reorder_up')).width(16).height(16)
          .fillColor(index === 0 ? '#555761' : '#B9BBC4')
          .onClick(() => this.moveMoreAction(index, -1))
        Image($r('app.media.reader_reorder_down')).width(16).height(16)
          .fillColor(index === this.draftMoreActions.length - 1 ? '#555761' : '#B9BBC4')
          .onClick(() => this.moveMoreAction(index, 1))
      }.width(24).height(36).justifyContent(FlexAlign.SpaceBetween).margin({ left: 4 })
      Image($r('app.media.reader_drag_handle')).width(20).height(20).fillColor('#B9BBC4')
        .width(32).height(36)
    }.width('100%').padding({ left: 14, right: 14, top: 8, bottom: 8 })
      .backgroundColor('#202127').borderRadius(12).margin({ bottom: 8 })
  }

  private selectMoreAction(action: ReaderMoreAction): void {
    this.overflowVisible = false;
    if (action.id === 'configure_more_actions') {
      this.openMoreActionConfig();
    } else if (action.id === 'add_bookmark') {
      this.addCurrentPageBookmark();
    } else if (action.id === 'edit_content') {
      this.openContentEditor();
    } else if (action.id === 'reverse_content') {
      const page = this.localReaderPages[this.currentPageIndex];
      this.pendingBookmarkTargetPosition = page?.startPosition ?? 0;
      this.onSaveChapterContent(this.getChapterIndex(), this.chapterTitle,
        this.reverseContentByCodePoint(this.content));
    } else if (action.id === 're_segment') {
      const page = this.localReaderPages[this.currentPageIndex];
      this.pendingBookmarkTargetPosition = page?.startPosition ?? 0;
      this.onToggleReSegment(this.book.reSegment !== true);
    } else if (action.id === 'text_processing') {
      this.textProcessingVisible = true;
    } else if (action.id === 'charset') {
      this.openCharsetDialog();
    } else if (action.id === 'toc_rule') {
      this.onOpenTocRule();
    } else if (action.id === 'image_style') {
      this.imageStyleMenuVisible = true;
    } else if (action.id === 'page_anim') {
      // 上游 ReaderMoreActionsSheet.kt:207-211：page_anim 点一下直接展开单选菜单。
      this.pageAnimMenuVisible = true;
    } else if (action.id === 'read_style') {
      this.onOpenSettings();
    } else if (action.id === 'highlight_rule') {
      this.highlightRuleSheetVisible = true;
    } else if (action.id === 'bottom_button_config') {
      this.onOpenBottomActionConfig();
    } else {
      const option = this.getMoreAction(action.id);
      this.moreActionShellTitle = option?.label ?? action.label;
      this.moreActionShellVisible = true;
    }
  }

  @Builder
  private moreActionUnavailableSheet() {
    Stack({ alignContent: Alignment.Center }) {
      Column().width('100%').height('100%').backgroundColor('#99000000')
        .onClick(() => this.moreActionShellVisible = false)
      Column() {
        Row() {
          Text(this.moreActionShellTitle).fontSize(18).fontWeight(FontWeight.Medium).fontColor('#E5E6EB')
            .layoutWeight(1)
          Text('关闭').fontSize(13).fontColor('#C7C9D1').onClick(() => this.moreActionShellVisible = false)
        }.width('100%').padding({ bottom: 14 })
        Text('此操作尚未迁移，当前不会执行。')
          .fontSize(14).fontColor('#B7B8C1').width('100%')
        Row() {
          Text('知道了').fontSize(14).fontColor('#101116')
            .padding({ left: 22, right: 22, top: 10, bottom: 10 })
            .backgroundColor('#B9C6FF').borderRadius(18)
            .onClick(() => this.moreActionShellVisible = false)
        }.width('100%').justifyContent(FlexAlign.End).margin({ top: 20 })
      }.width('86%').padding(18).backgroundColor(this.themeColorSurfaceSecondary).borderRadius(20)
    }.width('100%').height('100%')
  }

  @Builder
  private moreActionConfigurationSheet() {
    Stack({ alignContent: Alignment.Bottom }) {
      Column().width('100%').height('100%').backgroundColor('#99000000')
        .onClick(() => this.moreActionConfigVisible = false)
      Column() {
        Row().width(32).height(4).backgroundColor('#C5C6CD').borderRadius(4).margin({ top: 10, bottom: 14 })
        Row() {
          Text('更多操作配置').fontSize(17).fontColor('#E5E6EB').layoutWeight(1)
          Text('取消').fontSize(13).fontColor('#C7C9D1').margin({ right: 18 })
            .onClick(() => this.moreActionConfigVisible = false)
          Text('保存').fontSize(13).fontColor('#C6D3FF')
            .onClick(() => {
              this.onMoreActionsChange(this.draftMoreActions.map(
                (item: ReaderMoreActionConfig): ReaderMoreActionConfig => ({ id: item.id, enabled: item.enabled })
              ));
              this.moreActionConfigVisible = false;
            })
        }.width('100%').padding({ left: 18, right: 18, bottom: 12 })
        Scroll() {
          Column() {
            ForEach(this.draftMoreActions, (config: ReaderMoreActionConfig, index: number) => {
              this.moreActionConfigRow(config, index)
            }, (config: ReaderMoreActionConfig) => config.id)
          }.width('100%').padding({ left: 14, right: 14, bottom: 12 })
        }.width('100%').layoutWeight(1).scrollBar(BarState.Off)
      }.width('100%').height('62%').backgroundColor('#D91A1B21')
        .borderRadius({ topLeft: 24, topRight: 24 })
    }.width('100%').height('100%')
  }

  private getWholeBookProgress(): number {
    const chapterCount = this.getChapterCount();
    const chapterIndex = this.getChapterIndex();
    if (this.pageAnimation !== 3) {
      const pageCount = this.localReaderPages.length;
      if (pageCount === 0 && chapterIndex === 0) { return 0; }
      const chapterProgress = pageCount > 0 ? (this.currentPageIndex + 1) / pageCount : 1;
      let progress = (chapterIndex + chapterProgress) / chapterCount * 100;
      if (progress >= 100 && (chapterIndex + 1 !== chapterCount || this.currentPageIndex + 1 !== pageCount)) {
        progress = 99.9;
      }
      return Math.max(0, Math.min(100, progress));
    }
    return Math.max(0, Math.min(100,
      (chapterIndex + this.readerProgress / 100) / chapterCount * 100));
  }

  private needsFullBookPageData(): boolean {
    const values: number[] = [
      this.infoSettings.tipHeaderLeft, this.infoSettings.tipHeaderMiddle, this.infoSettings.tipHeaderRight,
      this.infoSettings.tipFooterLeft, this.infoSettings.tipFooterMiddle, this.infoSettings.tipFooterRight
    ];
    const templates: string[] = [
      this.infoSettings.customTipHeaderLeft, this.infoSettings.customTipHeaderMiddle,
      this.infoSettings.customTipHeaderRight, this.infoSettings.customTipFooterLeft,
      this.infoSettings.customTipFooterMiddle, this.infoSettings.customTipFooterRight
    ];
    for (let index = 0; index < values.length; index++) {
      const value = values[index] ?? 0;
      const template = templates[index] ?? '';
      if (value === 19 || value === 20 || (value === 18 &&
        (template.includes('{FullPageIndex}') || template.includes('{FullPageSize}')))) {
        return true;
      }
    }
    return false;
  }

  private getFullBookPaginationLayoutKey(): string {
    const replaceKey = JSON.stringify([
      ReplaceRuleRepository.isBookEnabled(this.book),
      this.replaceRules.map((rule: ReplaceRule) => [
        rule.id, rule.name, rule.pattern, rule.replacement, rule.scope,
        rule.scopeTitle, rule.scopeContent, rule.excludeScope, rule.isEnabled,
        rule.isRegex, rule.timeoutMillisecond, rule.order
      ])
    ]);
    const processKey = JSON.stringify(BookContentProcessRepository.getAll()
      .filter((process: BookContentProcess) => process.bookUrl === this.book.id)
      .sort((left: BookContentProcess, right: BookContentProcess) =>
        left.id < right.id ? -1 : left.id > right.id ? 1 : 0)
      .map((process: BookContentProcess) => [
        process.id, process.chapterIndex, process.kind, process.stage, process.target,
        process.anchorJson, process.actionJson, process.styleJson, process.sourceContentHash,
        process.enabled, process.sortOrder, process.status, process.schemaVersion, process.updatedAt
      ]));
    const chapterKey = JSON.stringify([
      BookRepository.cachedChapterTitles(this.book),
      BookRepository.cachedChapterOffsets(this.book)
    ]);
    return [
      this.book.id, this.book.contentPath ?? '', this.readerContentRevision, this.fontSize,
      this.textFontPath, this.titleFontPath, this.systemTypefaces,
      this.paragraphSpacing, this.lineSpacing, this.letterSpacing, this.paragraphIndent,
      this.readerContentWidth, this.viewportHeight, this.activeImageStyle, this.resolveReaderColumnCount(),
      JSON.stringify(this.paddingSettings),
      this.useZhLayout,
      this.infoSettings.headerMode, this.infoSettings.footerMode,
      this.infoSettings.headerFont, this.infoSettings.footerFont,
      this.infoSettings.headerFontSize, this.infoSettings.footerFontSize, this.infoSettings.applyHeaderStyle,
      chapterKey, replaceKey, processKey
    ].join('|');
  }

  private requestFullBookPagination(): void {
    if (!this.needsFullBookPageData() || !this.book.isLocal || this.book.contentPath === undefined) {
      if (this.fullBookPaginationKey !== '' || this.fullBookPageCounts.length > 0) {
        this.fullBookPaginationGeneration++;
        this.fullBookPaginationKey = '';
        this.fullBookPageCounts = [];
        this.fullBookPaginationReady = false;
      }
      return;
    }
    if (this.readerContentWidth <= 0 || this.viewportHeight <= 0) { return; }
    const key = this.getFullBookPaginationLayoutKey();
    if (this.fullBookPaginationKey === key) { return; }
    this.fullBookPaginationKey = key;
    this.fullBookPaginationReady = false;
    this.fullBookPageCounts = [];
    const generation = ++this.fullBookPaginationGeneration;
    this.paginateFullBookPages(key, generation).catch(() => {
      if (generation === this.fullBookPaginationGeneration) {
        this.fullBookPaginationKey = '';
        this.fullBookPageCounts = [];
        this.fullBookPaginationReady = false;
      }
    });
  }

  private async paginateFullBookPages(key: string, generation: number): Promise<void> {
    const context = this.getUIContext();
    const measureUtils = context.getMeasureUtils();
    const fontSize = this.fontSize * 1.05;
    const width = this.getBodyContentWidth();
    const baseLineHeight = ReaderFontRepository.measureLineHeight(context, this.readerBodyFontFamily, fontSize);
    const lineHeight = Math.max(1, baseLineHeight * this.lineSpacing / 10);
    const infoHeaderReserve = this.isReaderHeaderVisible() ? this.getReaderInfoReserve(true) : 0;
    const infoFooterReserve = this.isReaderFooterVisible() ? this.getReaderInfoReserve(false) : 0;
    const pageHeight = Math.max(lineHeight, this.getBodyContentHeight(infoHeaderReserve, infoFooterReserve));
    const paragraphSpacing = baseLineHeight * this.paragraphSpacing / 10;
    const imageSizes = new Map<string, ReaderIntrinsicImageSize>(this.imageSizes);
    const glyphWidths = new Map<string, number>();
    let scannedGlyphCount = 0;
    let measuredGlyphCount = 0;
    const yieldToUi = async (): Promise<void> => {
      await new Promise<void>((resolve: () => void) => setTimeout(resolve, 0));
    };
    const cacheGlyphWidths = async (text: string): Promise<void> => {
      let cursor = 0;
      while (cursor < text.length) {
        const codePoint = text.codePointAt(cursor);
        const nextCursor = cursor + (codePoint !== undefined && codePoint > 0xFFFF ? 2 : 1);
        const glyph = text.substring(cursor, nextCursor);
        if (!glyphWidths.has(glyph)) {
          const width = ReaderFontRepository.measureTextWidth(
            context, glyph, this.readerBodyFontFamily, fontSize, this.getReaderFontWeight());
          glyphWidths.set(glyph, width + this.getReaderLetterSpacingVp(fontSize));
          measuredGlyphCount++;
          if (measuredGlyphCount % 8 === 0) { await yieldToUi(); }
        }
        cursor = nextCursor;
        scannedGlyphCount++;
        if (scannedGlyphCount % 512 === 0) { await yieldToUi(); }
      }
    };
    const cacheDocumentGlyphWidths = async (document: LocalSemanticDocument): Promise<void> => {
      for (let paragraphIndex = 0; paragraphIndex < document.paragraphs.length; paragraphIndex++) {
        const paragraph = document.paragraphs[paragraphIndex];
        if (paragraph === undefined) { continue; }
        for (let partIndex = 0; partIndex < paragraph.parts.length; partIndex++) {
          const part = paragraph.parts[partIndex];
          if (part?.kind === 'text') { await cacheGlyphWidths(part.value); }
        }
        if (paragraphIndex % 8 === 7) { await yieldToUi(); }
      }
    };
    const measureFromGlyphCache = (text: string): number => {
      let totalWidth = 0;
      let cursor = 0;
      while (cursor < text.length) {
        const codePoint = text.codePointAt(cursor);
        const nextCursor = cursor + (codePoint !== undefined && codePoint > 0xFFFF ? 2 : 1);
        totalWidth += glyphWidths.get(text.substring(cursor, nextCursor)) ?? 0;
        cursor = nextCursor;
      }
      return totalWidth;
    };
    const inlineImageWidth = ReaderFontRepository.measureTextWidth(
      context, '袮', this.readerBodyFontFamily, fontSize, this.getReaderFontWeight()) +
      this.getReaderLetterSpacingVp(fontSize);
    const pageCounts: number[] = [];
    await BookRepository.forEachChapter(this.book, async (
      chapterContent: string,
      chapterIndex: number
    ): Promise<boolean> => {
      if (generation !== this.fullBookPaginationGeneration || key !== this.getFullBookPaginationLayoutKey()) {
        return false;
      }
      const chapterRows = BookRepository.cachedChapters(this.book);
      const rawTitle = chapterRows[chapterIndex]?.title ??
        (chapterIndex === this.getChapterIndex() ? this.chapterTitle : '');
      const displayTitle = await ReplaceRuleRepository.applyTitle(this.book, rawTitle);
      const document = LocalTextSemantics.parse(chapterContent, this.paragraphIndent, this.adaptSpecialStyle);
      await cacheDocumentGlyphWidths(document);
      await this.loadImageSizesForDocument(document, imageSizes);
      const titleBlock = this.buildReaderTitleBlock(context, width, lineHeight,
        document.content.length, this.activeImageStyle === 'SINGLE', displayTitle);
      const pageCount = chapterIndex === this.getChapterIndex() && this.localReaderPages.length > 0
        ? this.localReaderPages.length
        : await LocalReaderPaginator.countPagesIncrementally(
          document,
          width,
          pageHeight,
          lineHeight,
          paragraphSpacing,
          (text: string): number => measureFromGlyphCache(text),
          imageSizes,
          this.activeImageStyle,
          context.px2vp(80),
          inlineImageWidth,
          // 标题已进块流，首屏不再预留行。
          0,
          this.resolveReaderColumnCount(),
          this.readerSizeOffsets,
          titleBlock,
          // 与当页排版同一套样式，否则全书画布页数会和实际翻页数对不上。
          this.buildReaderTextLayoutStyle(fontSize)
        );
      // 标题页已由分页器的 titlePageBreakAfter 产出，不再额外 +1。
      pageCounts.push(pageCount);
      return true;
    });
    const expectedChapterCount = Math.max(1, BookRepository.cachedChapterTitles(this.book).length);
    if (generation === this.fullBookPaginationGeneration && key === this.getFullBookPaginationLayoutKey() &&
      pageCounts.length === expectedChapterCount) {
      this.fullBookPageCounts = pageCounts;
      this.fullBookPaginationReady = true;
    }
  }

  private async loadImageSizesForDocument(
    document: LocalSemanticDocument,
    sizes: Map<string, ReaderIntrinsicImageSize>
  ): Promise<void> {
    for (let paragraphIndex = 0; paragraphIndex < document.paragraphs.length; paragraphIndex++) {
      const paragraph = document.paragraphs[paragraphIndex];
      if (paragraph === undefined) { continue; }
      for (let partIndex = 0; partIndex < paragraph.parts.length; partIndex++) {
        const part = paragraph.parts[partIndex];
        if (part?.kind !== 'image' || sizes.has(part.value)) { continue; }
        let source: image.ImageSource | undefined = undefined;
        try {
          source = image.createImageSource(part.value);
          const info = await source.getImageInfo();
          if (info.size.width > 0 && info.size.height > 0) {
            const density = info.density > 0 ? info.density / 160 : 1;
            const context = this.getUIContext();
            sizes.set(part.value, {
              width: context.px2vp(info.size.width / density),
              height: context.px2vp(info.size.height / density)
            });
          }
        } catch (error) {
          console.error(`[ReaderPage] 读取正文图片尺寸失败: ${error}`);
        } finally {
          if (source !== undefined) {
            try { await source.release(); } catch (error) { console.error(`[ReaderPage] 释放图片源失败: ${error}`); }
          }
        }
      }
    }
  }

  private getWholeBookPageIndex(): number {
    if (!this.fullBookPaginationReady || this.pageAnimation === 3) { return -1; }
    const chapterIndex = this.getChapterIndex();
    if (chapterIndex < 0 || chapterIndex >= this.fullBookPageCounts.length) { return -1; }
    let pageIndex = this.currentPageIndex + 1;
    for (let index = 0; index < chapterIndex; index++) {
      pageIndex += this.fullBookPageCounts[index] ?? 0;
    }
    return pageIndex;
  }

  private getWholeBookPageCount(): number {
    if (!this.fullBookPaginationReady || this.pageAnimation === 3) { return -1; }
    let total = 0;
    for (let index = 0; index < this.fullBookPageCounts.length; index++) {
      total += this.fullBookPageCounts[index] ?? 0;
    }
    return total;
  }

  private getWholeBookPageText(): string {
    const index = this.getWholeBookPageIndex();
    const count = this.getWholeBookPageCount();
    return index < 0 || count < 0 ? '全文 - / -' : `${index}/${count}`;
  }

  private getReaderFooterProgress(): string {
    const usesPageProgress = this.isPageProgressMode();
    const current = usesPageProgress ? this.currentPageIndex + 1 : this.getChapterIndex() + 1;
    const total = usesPageProgress ? this.localReaderPages.length : this.getChapterCount();
    return `${current}/${total}  ${this.getWholeBookProgress().toFixed(1)}%`;
  }

  // 上游 ReaderColumnMode.kt 的 columnCount()：'1' 恒双页（滚动模式也生效），
  // '2' 只在横屏且非滚动时双页，'3' 放宽到平板，其余单页。
  private resolveReaderColumnCount(): number {
    return readerColumnCount(this.doubleHorizontalPage, this.readerContentWidth, this.viewportHeight,
      this.pageAnimation === 3);
  }

  // 单列的横向步长（含左右内边距），对齐上游 ReaderPaginator.kt:86 的 columnStridePx。
  private getColumnStrideWidth(): number {
    const columns = this.resolveReaderColumnCount();
    return Math.max(1, this.readerContentWidth / columns);
  }

  // 列内文字可用宽度：步长减去左右内边距，对齐上游 ReaderPaginator.kt:87 的 contentWidthPx。
  // 双页时每列各自带左右内边距，所以这里必须按列宽算，不能按整页宽算。
  private getBodyContentWidth(): number {
    return Math.max(1, this.getColumnStrideWidth() - this.paddingSettings.paddingLeft - this.paddingSettings.paddingRight -
      this.readerCutoutLeftInset() - this.readerCutoutRightInset());
  }

  /**
   * 显示缺口避让量（vp）。对齐上游 `ReaderContentAvoidancePolicy.padding()`：
   * 关闭时不避让；开启时左右各按 cutout inset 让开，底部叠加 cutout 底部 inset。
   * 上游顶部只在状态栏占位消失时避让（占位本身已盖住刘海），本地由外层 Stack 的 paddingTop 承担状态栏，
   * 所以这里只处理左右与底部。
   */
  private readerCutoutLeftInset(): number {
    return this.paddingDisplayCutouts ? this.readerDisplayCutoutLeft : 0;
  }

  private readerCutoutRightInset(): number {
    return this.paddingDisplayCutouts ? this.readerDisplayCutoutRight : 0;
  }

  private readerCutoutBottomInset(): number {
    return this.paddingDisplayCutouts ? this.readerDisplayCutoutBottom : 0;
  }

  // 某一页内第 index 行落在哪一列（0 或 1）。分页器保证先填满第 0 列再填第 1 列。
  private lineColumnAt(lineIndex: number): number {
    return this.localReaderPages[this.currentPageIndex]?.lineColumns[lineIndex] ?? 0;
  }

  // 当前页要渲染哪几列。单页时只有 [0]，双页时 [0, 1]。
  private readerColumnIndexes(): number[] {
    const columns = this.resolveReaderColumnCount();
    const indexes: number[] = [];
    for (let column = 0; column < columns; column++) { indexes.push(column); }
    return indexes;
  }

  private getBodyContentHeight(headerReserve: number, footerReserve: number): number {
    return Math.max(1, this.viewportHeight - this.paddingSettings.paddingTop -
      this.paddingSettings.paddingBottom - headerReserve - footerReserve - this.readerCutoutBottomInset());
  }

  private getReaderInfoReserve(isHeader: boolean): number {
    const top = isHeader ? this.paddingSettings.headerPaddingTop : this.paddingSettings.footerPaddingTop;
    const bottom = isHeader ? this.paddingSettings.headerPaddingBottom : this.paddingSettings.footerPaddingBottom;
    return 22 + top + bottom;
  }

  private getReaderLineGapAfter(line: LocalReaderLine, itemIndex: number, item: LocalReaderLineItem): number {
    const nextItem = line.items[itemIndex + 1];
    return !item.leadingIndent && nextItem !== undefined && !nextItem.leadingIndent ? line.justifyGap : 0;
  }

  private getReaderLetterSpacingFp(fontSize: number): number {
    return this.letterSpacing * fontSize;
  }

  private getReaderLetterSpacingVp(fontSize: number): number {
    const context = this.getUIContext();
    return context.px2vp(context.fp2px(this.getReaderLetterSpacingFp(fontSize)));
  }

  private getReaderTextLetterSpacingWidth(value: string, fontSize: number): number {
    return readerTextGlyphCount(value) * this.getReaderLetterSpacingVp(fontSize);
  }

  /**
   * 断行引擎用的正文样式。
   *
   * 必须与绘制正文的 `buildReaderCanvasStyle()` 同一套口径（同一字体族、字号、
   * 字重、字间距），否则系统断出来的行宽与画出来的行宽会不一致：
   * 断行时说放得下、绘制时却超出去，表现为最后一个字被裁或两端对齐缝隙不对。
   */
  private buildReaderTextLayoutStyle(fontSize: number): ReaderTextLayoutStyle {
    const context = this.getUIContext();
    return {
      fontFamilies: [this.readerBodyFontFamily],
      fontSizeFp: fontSize,
      letterSpacingVp: this.getReaderLetterSpacingVp(fontSize),
      fontWeight: this.getReaderFontWeight(),
      // layoutSync 只认 px，换算比例由这里带进去，引擎侧不再调用全局 vp2px / fp2px。
      vpScalePx: context.vp2px(1),
      fpScalePx: context.fp2px(1)
    };
  }

  private createMarkingFromCurrentSelection(): void {
    const start = this.pendingMarkingStart;
    const end = this.pendingMarkingEnd;
    const selectedText = this.pendingMarkingText;
    this.pendingMarkingStart = -1;
    this.pendingMarkingEnd = -1;
    this.pendingMarkingText = '';
    if (!this.book.isLocal || BookRepository.isBodyMissing(this.book)) {
      this.onUnavailableAction('划线与笔记仅支持已有本地正文的书籍');
      return;
    }
    if (start < 0 || end <= start || selectedText.length === 0) {
      this.onUnavailableAction('没有取得有效的正文选区，请重新选择文字');
      return;
    }
    this.onCreateMarking(start, end, selectedText);
  }

  private getMarkingForTextRange(start: number, end: number): ReaderMarking | undefined {
    const chapterIndex = this.getChapterIndex();
    for (let index = this.markings.length - 1; index >= 0; index--) {
      const marking = this.markings[index];
      if (marking !== undefined && marking.enabled && marking.chapterIndex === chapterIndex &&
        marking.chapterPosition < end && marking.endPosition > start) {
        return marking;
      }
    }
    return undefined;
  }

  private getReaderFontWeight(): number {
    if (this.textBold === 0) { return 400; }
    if (this.textBold === 1) { return 900; }
    if (this.textBold === 2) { return 300; }
    return Math.max(100, Math.min(900, this.textBold));
  }

  /**
   * 标题字号（fp），对齐上游 ReadBookConfig.kt:669-676：
   * 相对模式 = 正文字号 + titleSize，绝对模式 = titleSize，两者都至少 1。
   */
  private resolveTitleSizeFp(): number {
    const resolved = this.titleSizeRelative ? this.fontSize + this.titleSize : this.titleSize;
    return Math.max(1, resolved);
  }

  /**
   * 标题字重，对齐上游 LegacyReaderPaginationStyleFactory.kt:113-119 的 resolveWeight：
   * 1 → 900、2 → 300、100..900 原值、其余（含默认 500）→ 400。
   */
  private resolveTitleWeight(): number {
    if (this.titleBold === 1) { return 900; }
    if (this.titleBold === 2) { return 300; }
    if (this.titleBold >= 100 && this.titleBold <= 900) { return this.titleBold; }
    return 400;
  }

  /** 标题颜色：配置为空串表示未设置，回落正文色（上游 resolvedTitleColor 取 0 时同理）。 */
  private resolveTitleColor(): string {
    const configured = this.readerNightMode ? this.titleColorNight : this.titleColor;
    return configured.length > 0 ? configured : this.getReadingTextColor();
  }

  /** 标题对齐：0 居左、1 居中、2 隐藏（隐藏时不渲染，这里只处理前两种）。 */
  private resolveTitleAlign(): TextAlign {
    return this.titleMode === 1 ? TextAlign.Center : TextAlign.Start;
  }

  /** 标题上间距，上游 titleTopSpacing 按 dp 直接换算（LegacyReaderPaginationStyleFactory.kt:101）。 */
  private resolveTitleTopSpacing(): number {
    return Math.max(0, this.titleTopSpacing);
  }

  /** 标题下间距，上游 titleBottomSpacing 按 dp 直接换算。 */
  private resolveTitleBottomSpacing(): number {
    return Math.max(0, this.titleBottomSpacing);
  }

  /**
   * 标题行距倍率，对齐上游 LegacyReaderPaginationStyleFactory.kt:98-101：
   * titleLineSpacingExtra / 10 与 titleLineSpacingSub / 10 都是「行高的十分之几」。
   * 首段用 Extra，副标题段用 Sub。
   */
  private resolveTitleLineSpacingFactor(isSubtitle: boolean): number {
    const configured = isSubtitle ? this.titleLineSpacingSub : this.titleLineSpacingExtra;
    return Math.max(0, configured) / 10;
  }

  /** 标题分段结果；titleSegType 为 0 时上游也走「整行为一段」，行为不变。 */
  private resolveTitleSegments(title: string = this.displayChapterTitle): ReaderTitleSegment[] {
    if (title.length === 0) { return []; }
    return segmentReaderTitle(title, {
      type: this.titleSegType,
      distance: this.titleSegDistance,
      delimiter: this.titleSegFlag,
      subtitleScale: this.titleSegScaling
    });
  }

  /** 是否渲染标题：上游 titleMode 为 2 时整块隐藏（ReadBookConfig.kt:267）。 */
  private isReaderTitleVisible(): boolean {
    return this.titleMode !== 2 && this.displayChapterTitle.length > 0;
  }

  /**
   * 标题渲染。按 titleSegType 切段后逐段渲染：首段用正常字号，副标题段按 titleSegScaling 缩放。
   * 对齐上游 ReaderTitleSegmentation 的分段 + LegacyReaderPaginationStyleFactory 的标题样式。
   */
  @Builder
  private ReaderTitleSegments(centered: boolean) {
    if (this.isReaderTitleVisible()) {
      Column() {
        ForEach(this.resolveTitleSegments(), (segment: ReaderTitleSegment, index: number) => {
          Text(segment.text)
            .fontSize(Math.max(1, this.resolveTitleSizeFp() * segment.fontSizeScale))
            .fontFamily(this.readerTitleFontFamily)
            .letterSpacing(this.getReaderLetterSpacingFp(
              Math.max(1, this.resolveTitleSizeFp() * segment.fontSizeScale)))
            .fontWeight(this.resolveTitleWeight())
            .fontColor(this.resolveTitleColor())
            .width('100%')
            .textAlign(centered ? TextAlign.Center : this.resolveTitleAlign())
            .lineHeight(Math.max(1, this.resolveTitleSizeFp() * segment.fontSizeScale) *
              (1 + this.resolveTitleLineSpacingFactor(segment.isSubtitle)))
        }, (segment: ReaderTitleSegment, index: number) =>
          `${this.readerContentRevision}-title-${index}-${segment.text}-${this.titleMode}-${this.titleColor}-${this.titleColorNight}`)
      }
      .width('100%')
      .alignItems(centered ? HorizontalAlign.Center : this.titleMode === 1 ? HorizontalAlign.Center : HorizontalAlign.Start)
      .padding({ top: this.resolveTitleTopSpacing(), bottom: this.resolveTitleBottomSpacing() })
    }
  }

  /**
   * 标题在分页时占多少行。逐段累加每段的行高（首段用 titleLineSpacingExtra，
   * 副标题段用 titleLineSpacingSub），再加上下间距与段间距。
   * 上游标题参与排版度量（LegacyReaderPaginationStyleFactory.kt:51-57），这里同口径。
   */
  private measureTitleReservedLines(context: UIContext, width: number, lineHeight: number,
    title: string = this.displayChapterTitle): number {
    // 标题不渲染（titleMode 为 2 或标题为空）时不占任何行高。
    if (!this.isReaderTitleVisible() || title.length === 0) { return 0; }
    const segments = segmentReaderTitle(title, {
      type: this.titleSegType,
      distance: this.titleSegDistance,
      delimiter: this.titleSegFlag,
      subtitleScale: this.titleSegScaling
    });
    const baseSize = this.resolveTitleSizeFp();
    let total = 0;
    for (let index = 0; index < segments.length; index++) {
      const segment = segments[index] as ReaderTitleSegment;
      const segmentSize = Math.max(1, baseSize * segment.fontSizeScale);
      const segmentWidth = ReaderFontRepository.measureTextWidth(
        context, segment.text, this.readerTitleFontFamily, segmentSize, this.resolveTitleWeight()) +
        this.getReaderTextLetterSpacingWidth(segment.text, segmentSize);
      const baseHeight = ReaderFontRepository.measureLineHeight(
        context, this.readerTitleFontFamily, segmentSize);
      const spacedHeight = baseHeight * (1 + this.resolveTitleLineSpacingFactor(segment.isSubtitle));
      const lines = Math.max(1, Math.ceil(segmentWidth / Math.max(1, width)));
      total += lines * spacedHeight;
    }
    return Math.ceil((total + this.titleTopSpacing + this.titleBottomSpacing) / lineHeight);
  }


  /**
   * 构造章标题块，交给分页器排进块流。
   *
   * 上游标题是带 `isTitle` 标记的普通文本块，与正文共用同一个 `y` 游标和同一条换页判定
   * （`ReaderPaginator.kt:1112-1116`），所以标题会跟着正文一起翻页、一起滚动。
   * 本地旧实现把标题留在画布外当 ArkUI 组件，滚动模式下标题不跟着滚，就成了 KI-REL2。
   *
   * 三个开关的口径照抄上游唯一生产赋值处 `LegacyReaderChapterPaginator.kt:291`、`:321-326`：
   * - `titlePageBreakAfter = singleImage && content.textList.isNotEmpty()`
   *   —— 只有单图模式且本章有正文，标题才独占一页；空正文的单图章不插纯标题页。
   * - `titlePageCenterVertical = content.textList.isEmpty() || singleImage`
   *   —— 空正文或单图模式时首页整页垂直居中。
   * - `titleAlignment = CENTER` 当 `titleMode == 1 || isVolume || 空正文 || singleImage`。
   *
   * @param contentLength 本章正文的字符数（用于判断「有没有正文」）
   * @param singleImage 当前是否单图模式（`activeImageStyle === 'SINGLE'`）
   */
  private buildReaderTitleBlock(context: UIContext, width: number, lineHeight: number,
    contentLength: number, singleImage: boolean, title: string = this.displayChapterTitle): LocalReaderTitleBlock | undefined {
    if (this.titleMode === 2 || title.length === 0) { return undefined; }
    const segments = this.resolveTitleSegments(title);
    if (segments.length === 0) { return undefined; }
    const baseSize = this.resolveTitleSizeFp();
    const hasBody = contentLength > 0;
    const isVolume = this.isCurrentChapterVolume();
    const titleSegments: LocalReaderTitleSegment[] = [];
    for (let index = 0; index < segments.length; index++) {
      const segment = segments[index] as ReaderTitleSegment;
      const segmentSize = Math.max(1, baseSize * segment.fontSizeScale);
      const baseHeight = ReaderFontRepository.measureLineHeight(context, this.readerTitleFontFamily, segmentSize);
      const segmentLineHeight = Math.max(1, baseHeight * (1 + this.resolveTitleLineSpacingFactor(segment.isSubtitle)));
      // 段间距：上游 `processBlock` 里「下一段还是标题 → titleSegmentSpacingPx × titleSpacingScale」，
      // 这里下一段是副标题就用副标题段距，否则用正文段距的同等口径。
      const nextSegment = index + 1 < segments.length ? segments[index + 1] as ReaderTitleSegment : undefined;
      const spacingAfter = nextSegment === undefined ? 0
        : Math.max(1, baseSize * (nextSegment.fontSizeScale)) * this.resolveTitleLineSpacingFactor(nextSegment.isSubtitle);
      titleSegments.push({
        text: segment.text,
        fontSizeScale: segment.fontSizeScale,
        lineHeightVp: segmentLineHeight,
        spacingAfter: spacingAfter
      });
    }
    return {
      segments: titleSegments,
      topSpacing: this.resolveTitleTopSpacing(),
      bottomSpacing: this.resolveTitleBottomSpacing(),
      centered: this.titleMode === 1 || isVolume || !hasBody || singleImage,
      pageBreakAfter: singleImage && hasBody,
      centerVertical: !hasBody || singleImage,
      measureWidth: (text: string, fontSizeScale: number): number => {
        const size = Math.max(1, baseSize * fontSizeScale);
        return ReaderFontRepository.measureTextWidth(context, text, this.readerTitleFontFamily, size,
          this.resolveTitleWeight()) + this.getReaderTextLetterSpacingWidth(text, size);
      }
    };
  }

  /** 当前章是不是分卷标题行（上游 `chapter.isVolume`）。 */
  private isCurrentChapterVolume(): boolean {
    const rows = BookRepository.cachedChapters(this.book);
    const chapterIndex = this.getChapterIndex();
    const row = rows[chapterIndex];
    return row !== undefined && row.isVolume === true;
  }

  private getReaderUnderlineColor(): string {
    return this.readerNightMode ? this.underlineColorNight : this.underlineColor;
  }

  // 上游 offsetPx = (underlinePadding - 10).dpToPx()：默认 10 时偏移为 0，配大则线下移、配小则上移。
  private resolveUnderlineOffsetVp(): number {
    return this.underlinePadding - 10;
  }

  // 上游 strokeWidth = widthPx.coerceAtLeast(1f)（ReaderPageDecorationDrawCache.kt）。
  private resolveUnderlineWidthVp(): number {
    return Math.max(1, this.underlineHeight);
  }

  // 上游 DashPathEffect(dashOnPx, dashOffPx)；非虚线时给空数组即实线。
  private resolveUnderlineDashArray(): number[] {
    if (!this.dottedLine) { return []; }
    return [Math.max(0.1, this.dottedBase), Math.max(0.1, this.dottedRatio)];
  }

  // 分页正文统一由这些自绘线表达「正文下划线」，Text.decoration 只留给划线/高亮规则。
  // 必须自绘：ArkUI 的 TextDecorationStyle 不开放虚线段长、间隔与竖直偏移，上游这四项无法用装饰表达。
  // 每条 Line 都与本层同尺寸，坐标按整层计，于是可以直接用页级 y 定位到各自行底。
  /**
   * 阅读菜单里的亮度条。上游由 `showBrightnessView` 控制是否显示，"0" 关闭 / "1" 横排 / "2" 竖排；
   * 两处用法：底栏横排 `ReadBookMenuBarBottom.kt:139`、顶栏竖排 `ReadBookMenuBar.kt:250-268`。
   *
   * 上游 `ReadBookMenuBarBottom.kt:376-459` `BrightnessBar` 两个方向都有按钮：
   * - 横排（`vertical = false`）：左「跟随系统」圆形按钮 + 滑块 + 右侧同宽占位；
   * - 竖排（`vertical = true`）：上「跟随系统」+ 滑块（高 168dp）+ 下「左右位置」，整条宽 56dp。
   * 本地原先把按钮全省了，竖排连数值都看不到。
   */
  @Builder private ReaderBrightnessBar(vertical: boolean) {
    if (vertical) {
      Column({ space: 10 }) {
        this.ReaderBrightnessButton('auto', this.brightnessAuto)
        this.ReaderBrightnessSlider(true)
        this.ReaderBrightnessButton('position', false)
        Text(`${Math.round(this.readBrightness)}`).fontSize(11).fontColor('#B7B8C1')
          .textAlign(TextAlign.Center)
      }
      .width(56)
      .padding({ top: 12, bottom: 12, left: 4, right: 4 })
    } else {
      Row({ space: 8 }) {
        this.ReaderBrightnessButton('auto', this.brightnessAuto)
        this.ReaderBrightnessSlider(false)
        Text(`${Math.round(this.readBrightness)}`).fontSize(11).fontColor('#B7B8C1').width(32)
          .textAlign(TextAlign.End)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
      .padding({ left: 16, right: 16, top: 4, bottom: 4 })
    }
  }

  /**
   * 亮度条上的圆形按钮。`auto` 切「亮度跟随系统」，`position` 切竖排亮度条贴左/贴右。
   * 上游分别是 `ReadBookIntent.ToggleBrightnessAuto`（`ReadBookViewModel.kt:1007`）与
   * `ConfigUpdate.BrightnessVwPos`（`ReadBookMenuBar.kt:257-259`）。
   */
  @Builder private ReaderBrightnessButton(kind: string, selected: boolean) {
    // 上游选中态是 `ReadMenuGlassIconButton(selected = true)`：图标换成主题强调色、底色保持玻璃，
    // 不是整块反白。本地原先把强调色拼成 `#RRGGBB33` 当底色，8 位色值接 2 位 alpha 会解析失败变白，
    // 看起来像选中态丢了。改成只染图标 + 一圈 1vp 强调色描边。
    Stack({ alignContent: Alignment.Center }) {
      if (kind === 'auto') {
        Image($r('app.media.profile_auto_awesome')).width(18).height(18)
          .fillColor(selected ? this.readerMenuAccentTint() : this.readerMenuForeground())
      } else {
        Image($r('app.media.app_swap')).width(18).height(18).fillColor(this.readerMenuForeground())
      }
    }
    .width(40).height(40)
    .borderRadius(20)
    .border({
      width: selected ? 1 : 0,
      color: selected ? this.readerMenuAccentTint() : Color.Transparent
    })
    .onClick(() => {
      if (kind === 'auto') {
        this.onBrightnessAutoChange(!this.brightnessAuto);
      } else {
        this.onBrightnessVwPosChange(this.brightnessVwPos === '0' ? '1' : '0');
      }
    })
  }

  @Builder private ReaderBrightnessSlider(vertical: boolean) {
    Slider({
      value: this.readBrightness,
      min: 1,
      max: 100,
      step: 1,
      style: SliderStyle.InSet,
      direction: vertical ? Axis.Vertical : Axis.Horizontal
    })
      .layoutWeight(vertical ? 0 : 1)
      .width(vertical ? 40 : undefined)
      // 上游 `ReadBookMenuBarBottom.kt:376-459` 竖排滑块固定高 168dp，横排跟行高 40dp。
      .height(vertical ? 168 : 40)
      .selectedColor(this.readerMenuAccentTint()).trackColor('#5A3F47').blockColor(this.readerMenuAccentTint())
      .trackThickness(6)
      .blockSize({ width: 14, height: 14 })
      .onChange((value: number, mode: SliderChangeMode) => {
        if (mode === SliderChangeMode.Moving || mode === SliderChangeMode.Click || mode === SliderChangeMode.End) {
          this.onReadBrightnessChange(Math.max(1, Math.min(100, Math.round(value))));
        }
      })
  }

  /**
   * 环境光日夜提醒胶囊，对齐上游 `ReadBookFloatingActionBar.ThemeReminderCapsule`：
   * 底部一条带「切换到深色/浅色模式」与「关闭」两个按钮的胶囊，5 秒后由 Index 侧定时关掉。
   */
  @Builder
  private ReaderDayNightReminderCapsule() {
    Row({ space: 8 }) {
      Row() {
        Text(this.dayNightReminderText).fontSize(13).fontColor('#101116')
      }
      .padding({ left: 16, right: 16, top: 9, bottom: 9 })
      .backgroundColor('#C6D3FF')
      .borderRadius(18)
      .onClick(() => this.onAcceptDayNightReminder())

      Row() {
        Text('关闭').fontSize(13).fontColor('#D9DAE0')
      }
      .padding({ left: 16, right: 16, top: 9, bottom: 9 })
      .backgroundColor('#2A2B33')
      .borderRadius(18)
      .onClick(() => this.onDismissDayNightReminder())
    }
    .padding({ left: 12, right: 12, top: 10, bottom: 10 })
    .backgroundColor('#E6242127')
    .borderRadius(20)
  }

  /**
   * 划词菜单。
   * 上游 `TextActionSelectionMenu.kt:122-124` 按 `textSelectMenuConfig` 里的 `showState` 分三组：
   * 0 一级、1 折叠、2 隐藏；`:166` 在 `expandTextMenu` 为真时走 `MultiLineMenuView`（一级 + 折叠一起平铺），
   * 为假时只平铺一级、折叠项收进「更多」弹层。本地按同一口径渲染：
   *   - 只渲染 `READER_SELECTION_MENU_SUPPORTED` 里那些**有真实处理函数**的条目，
   *     上游其余 11 项本地没有对应能力，塞进来就是点了没反应的假按钮（`README`/KNOWN-ISSUES 口径）。
   *   - 隐藏（showState 2）的条目不出现；`expandTextMenu` 决定折叠项是与一级同排还是收进「更多」。
   */
  // -------------------------------------------------------------------------
  // 菜单（纯 ArkUI，不进画布）
  // -------------------------------------------------------------------------

  @Builder
  private readerMarkingSelectionMenu() {
    Column() {
      if (this.expandTextMenu) {
        // 展开态：多行平铺卡片（上游 MultiLineMenuView）。
        Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Center }) {
          ForEach(this.resolveSelectionMenuItems(), (item: ReaderSelectionMenuItem) => {
            Row() {
              if (this.showSelectMenuIcon) { this.readerSelectionMenuIcon(item.id) }
              Text(item.title).fontSize(14).fontColor('#E5E6EB').margin({ left: this.showSelectMenuIcon ? 6 : 0 })
            }
            .padding({ left: 14, right: 14, top: 10, bottom: 10 })
            .onClick(() => this.runSelectionMenuAction(item.id))
          }, (item: ReaderSelectionMenuItem) =>
            `${item.id}-${this.showSelectMenuIcon}-${this.expandTextMenu}-${this.selectionMenuMoreVisible}`)
        }.backgroundColor('#242127').borderRadius(12)
      } else {
        // 折叠态：一行可横向滚动的快捷条 + 右端分隔线 + 三点钮
        // （上游 TextActionSelectionMenu.kt:355-415 QuickMenuView）。
        Row() {
          Scroll() {
            Row() {
              ForEach(this.resolveSelectionMenuItems(), (item: ReaderSelectionMenuItem, index: number) => {
                Row() {
                  if (this.showSelectMenuIcon) { this.readerSelectionMenuIcon(item.id) }
                  Text(item.title).fontSize(14).fontColor('#E5E6EB')
                    .margin({ left: this.showSelectMenuIcon ? 6 : 0 })
                }
                // 上游首项左距 16dp、其余 10dp，右端统一 8dp（QuickMenuView 的 itemsIndexed）。
                .padding({ left: index === 0 ? 16 : 10, right: 8, top: 10, bottom: 10 })
                .onClick(() => this.runSelectionMenuAction(item.id))
              }, (item: ReaderSelectionMenuItem) =>
                `${item.id}-${this.showSelectMenuIcon}-${this.expandTextMenu}-${this.selectionMenuMoreVisible}`)
            }
          }
          .scrollable(ScrollDirection.Horizontal)
          .scrollBar(BarState.Off)
          .align(Alignment.Start)
          // 折叠态一行：条目区吃掉剩余宽度，条目多了在内部横向滚动。
          .layoutWeight(1)
          if (this.resolveSelectionMenuItems().length > 0) {
            // 右端分隔线：高 20dp、宽 1dp、40% 透明（上游 VerticalDivider）
            Row().width(1).height(20).backgroundColor('#4A4C5666')
          }
          Row() {
            AppGlyph({
              name: this.hasCollapsedSelectionMenuItem() ? 'more' : 'settings',
              glyphSize: 16,
              tint: '#E5E6EB'
            })
          }
          // 有折叠项时点开更多，否则去菜单管理（上游 onMoreClick / onSettingsClick）
          .padding({ left: 12, right: 16, top: 12, bottom: 12 })
          .onClick(() => {
            if (this.hasCollapsedSelectionMenuItem()) {
              this.selectionMenuMoreVisible = true;
            } else {
              this.onOpenSettings();
            }
          })
        }
        .backgroundColor('#242127')
        .borderRadius(12)
        // 卡片按内容自适应宽度，但必须夹进视口：外层 Column 没有参照宽度，
        // 百分比 maxWidth 在这里不生效，只能用正文宽度算具体数值。
        .constraintSize({ maxWidth: Math.max(200, this.readerContentWidth * 0.92) })
        // 二级弹层打开时主卡缩到 0.96、透明度 0.82（上游 quickMenuScale/quickMenuAlpha，
        // 锚点在右端中点 TransformOrigin(1f, 0.5f)）
        .scale({
          x: this.selectionMenuMoreVisible ? 0.96 : 1,
          y: this.selectionMenuMoreVisible ? 0.96 : 1,
          centerX: '100%',
          centerY: '50%'
        })
        .opacity(this.selectionMenuMoreVisible ? 0.82 : 1)
        .animation({ duration: 400, curve: Curve.EaseOut })
      }
      if (!this.expandTextMenu && this.selectionMenuMoreVisible) {
        this.readerSelectionMoreMenu()
      }
    }
  }

  /**
   * 「更多」二级弹层（上游 `TextActionSelectionMenu.kt:469-547 MoreMenuView`）。
   *
   * 结构：顶部返回箭头行 → 0.8 宽分隔线 → 折叠项列表（最高 240dp，可竖滚）→
   * 0.8 宽分隔线 → 「编辑菜单项」行（进菜单管理）。
   */
  @Builder
  private readerSelectionMoreMenu() {
    Column() {
      Row() {
        Image($r('app.media.reader_back')).width(20).height(20).fillColor('#E5E6EB')
      }
      .width('100%')
      .justifyContent(FlexAlign.Start)
      .padding({ left: 16, right: 16, top: 12, bottom: 8 })
      .onClick(() => { this.selectionMenuMoreVisible = false; })
      Row().width('80%').height(1).backgroundColor('#4A4C5666')
      Scroll() {
        Column() {
          ForEach(this.collapsedSelectionMenuItems(), (item: ReaderSelectionMenuItem) => {
            Row() {
              if (this.showSelectMenuIcon) { this.readerSelectionMenuIcon(item.id) }
              Text(item.title).fontSize(14).fontColor('#E5E6EB')
                .margin({ left: this.showSelectMenuIcon ? 12 : 0 })
            }
            .width('100%')
            .padding({ left: 16, right: 16, top: 12, bottom: 12 })
            .onClick(() => this.runSelectionMenuAction(item.id))
          }, (item: ReaderSelectionMenuItem) => `more-${item.id}-${this.showSelectMenuIcon}`)
        }
      }
      .scrollable(ScrollDirection.Vertical)
      .scrollBar(BarState.Off)
      .constraintSize({ maxHeight: 240 })
      .align(Alignment.Top)
      Row().width('80%').height(1).backgroundColor('#4A4C5666')
      Row() {
        AppGlyph({ name: 'settings', glyphSize: 20, tint: '#E5E6EB' })
        Text('编辑菜单项').fontSize(13).fontColor('#E5E6EB').margin({ left: 12 })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 8, bottom: 12 })
      .onClick(() => {
        this.selectionMenuMoreVisible = false;
        this.onOpenSettings();
      })
    }
    .backgroundColor('#242127')
    .borderRadius(12)
    .constraintSize({ maxWidth: '92%' })
    .margin({ top: 6 })
  }

  /**
   * 当前该出现在菜单里的条目。
   * 上游读配置的顺序与「配置里没提到的条目追加到末尾」都交给 `parseReaderSelectionMenuConfig`；
   * 这里再按 `showState` 与本地能力过滤。
   */
  private resolveSelectionMenuItems(): ReaderSelectionMenuItem[] {
    const items = parseReaderSelectionMenuConfig(this.textSelectMenuConfig);
    const visible: ReaderSelectionMenuItem[] = [];
    const collapsed: ReaderSelectionMenuItem[] = [];
    for (let index = 0; index < items.length; index++) {
      const item = items[index];
      if (item === undefined || item.group === 2) { continue; }
      if (!READER_SELECTION_MENU_SUPPORTED.includes(item.id)) { continue; }
      if (item.group === 1) {
        collapsed.push(item);
      } else {
        visible.push(item);
      }
    }
    // expandTextMenu 为真时折叠项与一级同排（上游 activeMultiItems = showState 0 或 1）；
    // 为假时折叠项只出现在「更多」二级弹层里，主卡始终只放一级项。
    if (this.expandTextMenu) {
      return visible.concat(collapsed);
    }
    return visible;
  }

  /** 折叠项（只给「更多」二级弹层用）。 */
  private collapsedSelectionMenuItems(): ReaderSelectionMenuItem[] {
    const items = parseReaderSelectionMenuConfig(this.textSelectMenuConfig);
    const collapsed: ReaderSelectionMenuItem[] = [];
    for (let index = 0; index < items.length; index++) {
      const item = items[index];
      if (item === undefined || item.group !== 1) { continue; }
      if (!READER_SELECTION_MENU_SUPPORTED.includes(item.id)) { continue; }
      collapsed.push(item);
    }
    return collapsed;
  }

  /** 未展开时是否还有折叠项被收起来（决定要不要提示「更多」，本地不做弹层）。 */
  private hasCollapsedSelectionMenuItem(): boolean {
    if (this.expandTextMenu) { return false; }
    const items = parseReaderSelectionMenuConfig(this.textSelectMenuConfig);
    for (let index = 0; index < items.length; index++) {
      const item = items[index];
      if (item === undefined || item.group !== 1) { continue; }
      if (READER_SELECTION_MENU_SUPPORTED.includes(item.id)) { return true; }
    }
    return false;
  }

  /** 划词菜单条目的图标，与设置面板的 `readerTextMenuIcon` 保持同一套资源。 */
  @Builder
  private readerSelectionMenuIcon(id: string) {
    if (id === 'menu_copy') {
      Image($r('app.media.reader_menu_copy')).width(16).height(16).fillColor('#D9DAE0')
    } else if (id === 'menu_bookmark') {
      Image($r('app.media.reader_menu_bookmark')).width(16).height(16).fillColor('#D9DAE0')
    } else if (id === 'menu_mark') {
      Image($r('app.media.reader_menu_border_color')).width(16).height(16).fillColor('#D9DAE0')
    } else {
      Blank().width(16).height(16)
    }
  }

  /** 划词菜单条目的动作分发；只有三个本地已实现的能力。 */
  private runSelectionMenuAction(id: string): void {
    // 老路径的 bindSelectionMenu 会在点中条目后自动收起菜单，画布上得自己收：
    // 只藏菜单、保留选区色块，与 ArkUI 点完菜单仍保持选中的行为一致。
    this.canvasSelectionMenuVisible = false;
    this.animateCanvasSelectionMenu(false);
    this.paintReaderCanvas();
    if (id === 'menu_copy') { this.copyCurrentSelection(); return; }
    if (id === 'menu_bookmark') { this.bookmarkCurrentSelection(); return; }
    if (id === 'menu_mark') { this.createMarkingFromCurrentSelection(); return; }
  }

  /** 复制当前选区。对齐上游 R.id.menu_copy：直接写系统剪贴板。 */
  private async copyCurrentSelection(): Promise<void> {
    const text = this.pendingMarkingText;
    if (text.length === 0) {
      this.onUnavailableAction('没有取得有效的正文选区，请重新选择文字');
      return;
    }
    try {
      const data = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, text);
      await pasteboard.getSystemPasteboard().setData(data);
      this.onUnavailableAction('已复制');
    } catch (error) {
      console.error(`[ReaderPage] 写入剪贴板失败: ${error}`);
      this.onUnavailableAction('复制失败，请重试');
    }
  }

  /**
   * 用当前选区加书签。
   * 对齐上游 ReadBookController.kt:2046-2051 R.id.menu_bookmark：以选区起点为 chapterPos、
   * 选区文字为 bookText 新建书签，随后打开书签编辑面板（上游同样走 TextActionBookmark → openEditor）。
   */
  private bookmarkCurrentSelection(): void {
    const start = this.pendingMarkingStart;
    const text = this.pendingMarkingText;
    if (start < 0 || text.length === 0) {
      this.onUnavailableAction('没有取得有效的正文选区，请重新选择文字');
      return;
    }
    this.onAddBookmark(start, text);
  }






  private async loadReaderHighlightRules(): Promise<void> {
    const context = this.getUIContext().getHostContext();
    if (context === undefined) { return; }
    const rules = await ReaderHighlightRuleRepository.load(context);
    this.readerHighlightRules = rules;
    this.readerHighlightRanges = ReaderHighlightRuleEngine.findBodyRanges(this.localSemanticContent, rules);
    this.readerSizeOffsets = this.buildReaderSizeOffsets();
    // 滚动模式的内容 ForEach 以 readerContentRevision 为 key，规则变化必须递增才会重建 Span。
    this.readerContentRevision++;
    this.rebuildReaderPages();
  }

  private async saveReaderHighlightRules(rules: ReaderHighlightRule[]): Promise<ReaderHighlightRule[]> {
    const context = this.getUIContext().getHostContext();
    if (context === undefined) { throw new Error('阅读页面上下文不可用'); }
    const currentPage = this.localReaderPages[this.currentPageIndex];
    if (currentPage !== undefined && !currentPage.titleOnly) {
      this.pendingBookmarkTargetPosition = currentPage.startPosition;
    }
    const saved = await ReaderHighlightRuleRepository.save(context, rules);
    this.readerHighlightRules = saved;
    this.readerHighlightRanges = ReaderHighlightRuleEngine.findBodyRanges(this.localSemanticContent, saved);
    this.readerSizeOffsets = this.buildReaderSizeOffsets();
    this.readerContentRevision++;
    this.rebuildReaderPages();
    return saved;
  }



  private usesLocalPagination(): boolean {
    return (this.book.format === 'txt' || this.book.format === 'epub') && this.pageAnimation !== 3;
  }

  /**
   * 连续滚动也走画布（上游 ReaderCanvasSurface.kt:1517-1540 的 ScrollPageStack）。
   *
   * 改造前滚动模式退回 ArkUI `Scroll` 把整章铺开，一是有两套排版（KI-EXP2 的残留形态），
   * 二是拿不到行几何，KI-C3 的下划线四项与选区都只得分页模式才有。
   */
  private usesCanvasScroll(): boolean {
    return (this.book.format === 'txt' || this.book.format === 'epub') && this.pageAnimation === 3;
  }

  /** 是否走画布渲染：本地分页与连续滚动都算。 */
  private usesReaderCanvas(): boolean {
    return this.book.format === 'txt' || this.book.format === 'epub';
  }
  /**
   * 滚动模式的整章内容高度（vp）：所有页的滚动 extent 累加。
   *
   * 上游 `scrollExtentPx` 就是排版游标，章末页再加 `chapterEndPaddingPx`；
   * 这里与画布 `pageScrollExtent()` 用同一套累加口径，保证进度条与实际可滚范围一致。
   */
  private readerScrollContentHeight(): number {
    const pages = this.localReaderPages;
    if (pages.length === 0) {
      return Math.max(0, this.viewportHeight);
    }
    const endPadding = 20;
    const bodyHeight = this.getBodyContentHeight(
      this.isReaderHeaderVisible() ? this.getReaderInfoReserve(true) : 0,
      this.isReaderFooterVisible() ? this.getReaderInfoReserve(false) : 0);
    let total = 0;
    for (let index = 0; index < pages.length; index++) {
      const page = pages[index];
      if (page === undefined) {
        continue;
      }
      let used = 0;
      for (const line of page.lines) {
        used += line.verticalSpaceBefore + line.height + line.paragraphSpacingAfter;
      }
      if (page.titleOnly && used <= 0) {
        used = Math.max(1, bodyHeight);
      }
      total += Math.max(1, used);
      if (index === pages.length - 1) {
        total += endPadding;
      }
    }
    // 内容不足一屏时也要能停在一屏的高度上，与上游 minOf(0, viewport - extent) 同口径
    return Math.max(1, total);
  }

  /**
   * 滚动模式的可滚高度（vp）：整章内容高减去一屏。
   *
   * 画布把整章按页堆叠绘制，`scrollOffset` 就是这个堆叠坐标系里的平移量，
   * 所以可滚范围不再是 `Scroll` 组件的内容尺寸，而是 `readerScrollContentHeight()`。
   */
  private readerScrollTotalHeight(): number {
    return Math.max(0, this.readerScrollContentHeight() - this.viewportHeight);
  }

  /**
   * 章内绝对滚动位移（vp）：当前页之前的页 extent 之和 + 当前页内偏移。
   *
   * `scrollOffset` 只记「相对当前页」的平移（上游 scrollOffsetState 同口径），
   * 直接用它会每换一页就把进度打回 0，进度条与「跳到百分比」都会错。
   */
  private readerScrollAbsoluteOffset(): number {
    const pages = this.localReaderPages;
    let before = 0;
    for (let index = 0; index < this.currentPageIndex && index < pages.length; index++) {
      const page = pages[index];
      if (page === undefined) { continue; }
      let used = 0;
      for (const line of page.lines) {
        used += line.verticalSpaceBefore + line.height + line.paragraphSpacingAfter;
      }
      if (page.titleOnly && used <= 0) {
        used = Math.max(1, this.getBodyContentHeight(
          this.isReaderHeaderVisible() ? this.getReaderInfoReserve(true) : 0,
          this.isReaderFooterVisible() ? this.getReaderInfoReserve(false) : 0));
      }
      before += Math.max(1, used);
    }
    return before + this.scrollOffset;
  }

  /** 把章内绝对位移还原成「当前页索引 + 页内偏移」。 */
  private seekReaderScrollAbsolute(target: number): void {
    const pages = this.localReaderPages;
    if (pages.length === 0) {
      return;
    }
    const footerReserve = this.isReaderFooterVisible() ? this.getReaderInfoReserve(false) : 0;
    const headerReserve = this.isReaderHeaderVisible() ? this.getReaderInfoReserve(true) : 0;
    const bodyHeight = this.getBodyContentHeight(headerReserve, footerReserve);
    let remaining = Math.max(0, target);
    for (let index = 0; index < pages.length; index++) {
      const page = pages[index];
      if (page === undefined) { continue; }
      let used = 0;
      for (const line of page.lines) {
        used += line.verticalSpaceBefore + line.height + line.paragraphSpacingAfter;
      }
      if (page.titleOnly && used <= 0) { used = Math.max(1, bodyHeight); }
      const extent = Math.max(1, used);
      if (remaining < extent || index === pages.length - 1) {
        this.currentPageIndex = index;
        this.scrollOffset = Math.min(remaining, Math.max(0, extent - 1));
        return;
      }
      remaining -= extent;
    }
  }

  /**
   * 滚动模式下的进度刷新。上游 `ReadBookViewModel.kt:2506-2518` 把滚动热路径的进度发布
   * 延迟 250ms 再做（`composeProgressJob` + `delay(250L)`），拖拽期不逐帧刷新底栏，
   * 否则进度条数字跟着手指抖。这里同口径：连续调用只保留最后一次，250ms 后才真正落到
   * `sliderProgressIndex` 与进度回调上。
   */
  private updateProgress(): void {
    if (this.usesLocalPagination()) { return; }
    if (this.startPositionPending) { return; }
    const totalScrollHeight = this.readerScrollTotalHeight();
    if (totalScrollHeight <= 0) {
      return;
    }
    const progress = Math.max(0, Math.min(100,
      Math.round(this.readerScrollAbsoluteOffset() / totalScrollHeight * 100)));
    this.readerProgress = progress;
    if (!this.usesCanvasScroll()) {
      this.applyScrollProgress(progress);
      return;
    }
    this.pendingScrollProgress = progress;
    if (this.scrollProgressTimer >= 0) {
      clearTimeout(this.scrollProgressTimer);
    }
    this.scrollProgressTimer = setTimeout(() => {
      this.scrollProgressTimer = -1;
      this.applyScrollProgress(this.pendingScrollProgress);
    }, ReaderPage.SCROLL_PROGRESS_THROTTLE_MS);
  }

  /** 把节流后的进度落到滑块与进度回调上。 */
  private applyScrollProgress(progress: number): void {
    if (this.usesCanvasScroll()) { this.sliderProgressIndex = progress; }
    if (progress !== this.lastReportedProgress) {
      this.lastReportedProgress = progress;
      this.emitReaderProgress(progress, Math.round(this.content.length * progress / 100), false);
    }
  }

  private restoreProgressPosition(): void {
    if (this.usesLocalPagination()) { return; }
    if (this.startPositionPending) { return; }
    if (this.restoredProgressPosition) {
      return;
    }
    const totalScrollHeight = this.readerScrollTotalHeight();
    if (totalScrollHeight <= 0) {
      return;
    }
    this.restoredProgressPosition = true;
    const chapterProgress = this.book.chapterProgress ?? 0;
    this.seekReaderScrollAbsolute(totalScrollHeight * chapterProgress / 100);
    this.readerProgress = chapterProgress;
    this.lastReportedProgress = chapterProgress;
    this.sliderProgressIndex = chapterProgress;
    this.paintReaderCanvas();
  }

  private seekToProgress(progress: number): void {
    this.resolveStartPosition();
    const nextProgress = Math.max(0, Math.min(100, Math.round(progress)));
    const totalScrollHeight = this.readerScrollTotalHeight();
    if (totalScrollHeight <= 0) {
      return;
    }
    this.readerProgress = nextProgress;
    this.lastReportedProgress = nextProgress;
    this.seekReaderScrollAbsolute(totalScrollHeight * nextProgress / 100);
    this.refreshReaderBottomJustifyGap();
    this.paintReaderCanvas();
    this.emitReaderProgress(nextProgress, Math.round(this.content.length * nextProgress / 100), false);
  }

  private getDisplayContent(content: string): string {
    return content.split(/\r?\n/).map((line: string) => line.trim().length > 0
      ? this.paragraphIndent + line.trimStart() : line).join('\n');
  }

  private getReaderContentSegments(): ReaderContentSegment[] {
    const segments: ReaderContentSegment[] = [];
    const imagePattern: RegExp = /\[\[EPUB_IMAGE:([^;\]\r\n]+)(?:;[^\]\r\n]*)?\]\]/g;
    let match: RegExpExecArray | null = imagePattern.exec(this.content);
    let cursor = 0;
    while (match !== null) {
      if (match.index > cursor) {
        const textBeforeImage = this.content.substring(cursor, match.index);
        this.appendParagraphSegments(segments, textBeforeImage);
      }
      const imageUri = match[1] ?? '';
      if (imageUri.length > 0) {
        segments.push({ kind: 'image', value: imageUri, startPosition: -1 });
      }
      cursor = match.index + match[0].length;
      match = imagePattern.exec(this.content);
    }
    if (cursor < this.content.length) {
      const trailingText = this.content.substring(cursor);
      this.appendParagraphSegments(segments, trailingText);
    }
    if (segments.length === 0) {
      segments.push({ kind: 'text', value: this.content.length > 0 ? this.content : '选择一本书开始阅读。', startPosition: 0 });
    }
    const positioned: ReaderContentSegment[] = [];
    let searchFrom = 0;
    for (let index = 0; index < segments.length; index++) {
      const segment = segments[index];
      if (segment === undefined) { continue; }
      let startPosition = searchFrom;
      if (segment.kind === 'image') {
        const markerPosition = this.localSemanticContent.indexOf('\uFFFC', searchFrom);
        if (markerPosition >= 0) { startPosition = markerPosition; }
        searchFrom = startPosition + 1;
      } else {
        const displayText = this.getDisplayContent(segment.value);
        const textPosition = this.localSemanticContent.indexOf(displayText, searchFrom);
        if (textPosition >= 0) { startPosition = textPosition; }
        searchFrom = startPosition + displayText.length;
      }
      positioned.push({ kind: segment.kind, value: segment.value, startPosition: startPosition });
    }
    return positioned;
  }

  private appendParagraphSegments(segments: ReaderContentSegment[], text: string): void {
    const paragraphs = text.split(/\n\s*\n/);
    for (let index = 0; index < paragraphs.length; index++) {
      const paragraph = paragraphs[index];
      if (paragraph !== undefined && paragraph.trim().length > 0) {
        segments.push({ kind: 'text', value: paragraph, startPosition: -1 });
      }
    }
  }

  private async loadContentImageSizes(): Promise<void> {
    const segments = this.getReaderContentSegments();
    const nextSizes = new Map<string, ReaderIntrinsicImageSize>(this.imageSizes);
    let changed = false;
    for (let index = 0; index < segments.length; index++) {
      const segment = segments[index];
      if (segment === undefined || segment.kind !== 'image' || nextSizes.has(segment.value)) {
        continue;
      }
      let source: image.ImageSource | undefined = undefined;
      try {
        source = image.createImageSource(segment.value);
        const info = await source.getImageInfo();
        if (info.size.width > 0 && info.size.height > 0) {
          const density = info.density > 0 ? info.density / 160 : 1;
          const widthPx = info.size.width / density;
          const heightPx = info.size.height / density;
          const context = this.getUIContext();
          nextSizes.set(segment.value, {
            width: context.px2vp(widthPx),
            height: context.px2vp(heightPx)
          });
          changed = true;
        }
      } catch (error) {
        console.error(`[ReaderPage] 读取图片尺寸失败: ${error}`);
      } finally {
        if (source !== undefined) {
          try {
            await source.release();
          } catch (error) {
            console.error(`[ReaderPage] 释放图片源失败: ${error}`);
          }
        }
      }
    }
    if (changed) {
      this.imageSizes = nextSizes;
      // 不在这里直接重排：尺寸是一张张异步到齐的，20 张图就会排 20 次全章。
      // 交给防抖窗口，窗口末尾只排一次，且这一轮跳过语义解析与高亮匹配。
      this.scheduleImageSizesPaginationRebuild();
    }
  }

  /**
   * 首次排版前把本章图片尺寸量好（上游 `ReadBookController.kt:239-248` 的口径）。
   *
   * 上游在排版期就用 `ImageProvider.getImageSize` 拿到真实尺寸，异步解码完成只重绘，
   * 所以图片出现时正文不会跳。本地原来是「先按行高正方形占位排版、尺寸到了再重排」，
   * 每张图加载完都会把整章行位推一遍。这里在首排之前同步量一次，
   * 量到的尺寸直接进 `imageSizes`，之后的分页就用真实尺寸，不再有二次重排。
   *
   * 同步接口会阻塞当前线程（SDK 明确警告），所以只处理本章、只处理尚未量过的图，
   * 且章节图片数量很少时收益最大；量失败就退回异步路径，不阻塞开书。
   */
  private primeContentImageSizesSync(): void {
    const segments = this.getReaderContentSegments();
    let pending = 0;
    for (let index = 0; index < segments.length; index++) {
      const segment = segments[index];
      if (segment !== undefined && segment.kind === 'image' && !this.imageSizes.has(segment.value)) {
        pending++;
      }
    }
    if (pending === 0) {
      return;
    }
    const nextSizes = new Map<string, ReaderIntrinsicImageSize>(this.imageSizes);
    let changed = false;
    const context = this.getUIContext();
    for (let index = 0; index < segments.length; index++) {
      const segment = segments[index];
      if (segment === undefined || segment.kind !== 'image' || nextSizes.has(segment.value)) {
        continue;
      }
      let source: image.ImageSource | undefined = undefined;
      try {
        source = image.createImageSource(segment.value);
        const info = source.getImageInfoSync();
        if (info.size.width > 0 && info.size.height > 0) {
          const density = info.density > 0 ? info.density / 160 : 1;
          nextSizes.set(segment.value, {
            width: context.px2vp(info.size.width / density),
            height: context.px2vp(info.size.height / density)
          });
          changed = true;
        }
      } catch (error) {
        console.warn(`[ReaderPage] 同步读取图片尺寸失败，退回异步: ${error}`);
      } finally {
        if (source !== undefined) {
          try {
            source.release();
          } catch (error) {
            console.warn(`[ReaderPage] 释放图片源失败: ${error}`);
          }
        }
      }
    }
    if (changed) {
      this.imageSizes = nextSizes;
    }
  }





  // -------------------------------------------------------------------------
  // 画布渲染（阶段 A）
  //
  // 正文从「ArkUI 组件树逐行拼 Text/Span」改成「一个 Canvas 逐行绘制」，
  // 对齐上游 feature/reader/ReaderCanvasSurface.kt：
  //   - 页面窗口四页（previous/current/next/nextPlus）常驻内存，翻页只移动窗口；
  //   - 绘制顺序由 ReaderPageTransitionPolicy.transforms() 的 currentOnTop 决定；
  //   - 没有当前页（尺寸未就绪）就不画，绝不回落「整章滚动」那套排版。
  // -------------------------------------------------------------------------

  /** 当前视口下能拿到画布尺寸时才算就绪；尺寸为 0 时上游也是直接不画。 */
  private canPaintReaderCanvas(): boolean {
    return this.readerContentWidth > 0 && this.viewportHeight > 0 && this.localReaderPages.length > 0;
  }

  /**
   * 构造一帧的绘制输入。
   *
   * 位移/透明度的口径：`ReaderPageTransitionPolicy.transforms()` 全部按 px 计算，
   * 所以这里把 vp 的布局量统一换成 px，画布 context 也用 LengthMetricsUnit.PX。
   */
  /**
   * 章边界占位页（上游 `ReadBookController.kt:900-945` 的窗口装配）。
   *
   * 上游在两个位置给整屏居中的提示页：邻章还在读盘时给「加载数据中…」，
   * 连续滚动到章末时给「继续滑动以加载下一章…」。两者在本地都由
   * `boundaryMessage` 一个状态驱动——它是「当前页临时替换成提示页」，
   * 换章成功、正文到达后自动清空。
   */
  private appendBoundaryPlaceholders(window: ReaderCanvasWindow): void {
    if (this.boundaryMessage.length === 0) { return; }
    // KI-REL1：提示页只在「真的没有当前页」时顶上（开书第一帧、视口还没就绪）。
    // 上游 `ReaderCanvasSurface.kt:254` 的 `pages.current ?: return` 意味着有页就画页；
    // 本地旧实现无条件用提示页替换当前页，换章等待期间整屏只剩一行「加载数据中…」，
    // 那正是用户看到的空窗。现在有页就继续画页，正文始终在屏幕上。
    if (window.current !== undefined) { return; }
    window.current = new ReaderCanvasPage(this.messagePlaceholderPage(this.boundaryMessage),
      this.currentPageIndex);
  }

  /** 占位页：`lines` 为空、只带一行居中文案，不进正文页数统计。 */
  private messagePlaceholderPage(text: string): LocalReaderPage {
    return {
      lines: [], startPosition: 0, endPosition: 0, titleOnly: false, lineColumns: [], messageText: text
    };
  }

  /**
   * 翻到章边界时先亮提示页，再交给换章回调。
   *
   * 连续滚动给「继续滑动以加载下一章…」（上游 `keep_swipe_tip`），
   * 分页翻页给「加载数据中…」（上游 `data_loading`）——两者都是整屏居中的提示页。
   * 目标章不存在（全书第一页/最后一页）时不显示，越界提示仍由上层 toast 负责。
   */
  private showChapterBoundaryMessage(delta: number): void {
    const target = this.getChapterIndex() + delta;
    if (target < 0 || target >= this.getChapterCount()) { return; }
    const text = this.usesCanvasScroll() ? '继续滑动以加载下一章…' : '加载数据中…';
    this.boundaryMessage = text;
    this.paintReaderCanvas();
    // 兜底：换章失败（读盘报错、目标章缺失）时不能把提示页永远留在屏幕上
    if (this.boundaryMessageTimer >= 0) {
      clearTimeout(this.boundaryMessageTimer);
    }
    this.boundaryMessageTimer = setTimeout(() => {
      this.boundaryMessageTimer = -1;
      if (this.boundaryMessage.length > 0) {
        this.boundaryMessage = '';
        this.paintReaderCanvas();
      }
    }, 5000);
  }

  private clearBoundaryMessage(): void {
    if (this.boundaryMessageTimer >= 0) {
      clearTimeout(this.boundaryMessageTimer);
      this.boundaryMessageTimer = -1;
    }
    if (this.boundaryMessage.length > 0) {
      this.boundaryMessage = '';
      this.paintReaderCanvas();
    }
  }

  private buildReaderCanvasRequest(transforms: ReaderTransitionTransforms): ReaderCanvasDrawRequest {
    const request = new ReaderCanvasDrawRequest();
    request.window = ReaderCanvasWindow.of(this.localReaderPages, this.currentPageIndex);
    this.appendBoundaryPlaceholders(request.window);
    request.transforms = transforms;
    // 覆盖转场：移动页尾部外侧 36dp 的渐变阴影（上游 ReaderCanvasSurface.kt:1663-1687）。
    // 位移为 0 时不画——那正是「两页重合」的那一帧。
    if (this.turnMode === ReaderTransitionMode.COVER) {
      const pageWidthPx = this.getUIContext().vp2px(Math.max(1, this.readerContentWidth));
      const offsetPx = transforms.currentOnTop
        ? transforms.current.translationX
        : transforms.previous.translationX + pageWidthPx;
      if (offsetPx !== 0) {
        request.coverShadowEdgePx = transforms.currentOnTop
          ? pageWidthPx + offsetPx
          : offsetPx;
      }
    }
    // 自动翻页：分页模式下把「下一页揭开多少」带给画布，滚动模式不画（上游 else 分支）
    if (this.autoPageRevealVp > 0 && !this.usesCanvasScroll()) {
      request.autoRevealPx = this.getUIContext().vp2px(this.autoPageRevealVp);
      request.autoPageIndicatorArgb = readerCanvasArgb(this.readerMenuAccentTint(), 0xFF2E7CF6);
    }
    request.layout = this.buildReaderCanvasLayout();
    request.style = this.buildReaderCanvasStyle();
    request.titleStyle = this.buildReaderCanvasTitleStyle();
    request.markings = this.buildReaderCanvasMarkings();
    request.highlights = this.buildReaderCanvasHighlights();
    request.pageBackgroundArgb = this.readerCanvasPageBackgroundArgb();
    // 纸面底色始终不透明：折页时每页要先铺自己的纸，否则两页文字互相透出
    request.pageSurfaceArgb = readerCanvasArgb(this.paperColor, 0xFFFFFFFF);
    // 有自定义背景图时不铺纸面，否则背景图被纸色盖住
    request.pageSurfaceOpaque = this.readerBackgroundImage.length === 0;
    // 仿真折页：触点逐帧写入，绘制期只读；只有 SIMULATION 才走折页分支
    request.curlActive = this.turnMode === ReaderTransitionMode.SIMULATION;
    request.curlTouchX = this.curlTouchX;
    request.curlTouchY = this.curlTouchY;
    request.curlCornerY = this.curlCornerY;
    request.curlRevealProgress = this.curlRevealProgress;
    request.curlPrevious = this.curlPrevious;
    // 连续滚动：四页按 extent 堆叠、整栈按 scrollOffset 平移（上游 ScrollPageStack）。
    // 章末页要留一章末余白（上游 CHAPTER_END_PADDING_DP = 20dp），否则残页后面
    // 直接贴上一句「下一章」，与旧 View 的 `height = durY + 20dp` 不一致。
    request.scrollActive = this.usesCanvasScroll();
    request.scrollOffsetPx = this.getUIContext().vp2px(this.scrollOffset);
    request.scrollEndPaddingPx = this.getUIContext().vp2px(20);
    request.scrollLastPageIndex = this.localReaderPages.length - 1;
    // 选区：渲染坐标直接来自长按/拖把手，画布按元素切分后用 getRectsForRange 出高亮条带。
    request.selectionStart = this.canvasSelectionStart;
    request.selectionEnd = this.canvasSelectionEnd;
    const context = this.getUIContext();
    // 上游 SelectionHandleRadius = 7.dp、SelectionHandleStrokeWidth = 2.dp
    request.handleRadiusPx = context.vp2px(7);
    request.handleStrokeWidthPx = context.vp2px(2);
    // 上游 handleColor = selectionColor.copy(alpha = 1f)：竖线与圆柄同一支灰色，
    // 不再是「白圆 + 纸色描边」——纸色描边在深色纸上等于没有边，圆柄会糊成一团。
    request.handleFillArgb = request.selectionColorArgb | 0xFF000000;
    request.handleStrokeArgb = request.selectionColorArgb | 0xFF000000;
    request.handleStartAlpha = this.canvasHandleStartAlpha;
    request.handleEndAlpha = this.canvasHandleEndAlpha;
    return request;
  }

  private buildReaderCanvasLayout(): ReaderCanvasLayout {
    const layout = new ReaderCanvasLayout();
    const context = this.getUIContext();
    const columnCount = Math.max(1, this.resolveReaderColumnCount());
    const stride = Math.max(1, this.getColumnStrideWidth());
    layout.columnCount = columnCount;
    layout.columnStridePx = context.vp2px(stride);
    layout.bodyWidthPx = context.vp2px(this.getBodyContentWidth());
    layout.bodyHeightPx = context.vp2px(this.getBodyContentHeight(
      this.isReaderHeaderVisible() ? this.getReaderInfoReserve(true) : 0,
      this.isReaderFooterVisible() ? this.getReaderInfoReserve(false) : 0));
    // 列起点：第一列带左内边距与刘海内缩，第二列再偏移一个 stride。
    // 纵向原点必须是 0：Canvas 在 Column 里排在页眉/标题之后，已经自带那段偏移，
    // 这里再减一次 paddingTop + 页眉高度就会把正文整体往下推两遍。
    const leftPadding = context.vp2px(this.paddingSettings.paddingLeft + this.readerCutoutLeftInset());
    layout.originXpx = leftPadding;
    layout.originYpx = 0;
    layout.bottomJustifyGapPx = context.vp2px(this.readerBottomJustifyGap);
    // 双页模式按列各算一份（上游 justifyColumnBottom 逐列摊分）
    if (columnCount > 1) {
      const perColumn = this.calculateReaderBottomJustifyGaps(
        this.readerBottomJustifyPageHeight, this.readerBottomJustifyLineHeight,
        this.readerBottomJustifyTitleLines);
      const gapsPx: number[] = [];
      for (let index = 0; index < perColumn.length; index++) {
        gapsPx.push(context.vp2px(perColumn[index] ?? 0));
      }
      layout.bottomJustifyGapByColumn = gapsPx;
    }
    // 分页器的行高/字宽/图片尺寸都是 vp，绘制层要按 px 排，比例从这里带下去
    layout.vpScale = context.vp2px(1);
    layout.viewportWidthPx = context.vp2px(Math.max(1, this.readerContentWidth));
    layout.viewportHeightPx = context.vp2px(Math.max(1, this.viewportHeight));
    return layout;
  }

  /**
   * 章标题的绘制样式。上游标题与正文是两套 paint
   * （`LegacyReaderPaginationStyleFactory.kt:99-113`），字号、字重、字色都分开配。
   * 元素实际字号 = 这里的基准字号 × `LocalReaderLineItem.titleFontScale`。
   */
  private buildReaderCanvasTitleStyle(): ReaderCanvasTitleStyle {
    const style = new ReaderCanvasTitleStyle();
    const context = this.getUIContext();
    style.colorArgb = readerCanvasArgb(this.resolveTitleColor(), 0xFF000000);
    style.fontFamilies = [this.readerTitleFontFamily];
    style.fontSizePx = context.fp2px(this.resolveTitleSizeFp());
    style.fontWeight = this.resolveTitleWeight();
    // 上游 titlePaint 不带 letterSpacing；本地标题也按 0 画，保持与分页器测量一致。
    style.letterSpacingPx = 0;
    style.align = this.resolveTitleAlign() === TextAlign.Center ? 1 : 0;
    return style;
  }

  private buildReaderCanvasStyle(): ReaderCanvasStyle {
    const style = new ReaderCanvasStyle();
    const context = this.getUIContext();
    style.colorArgb = readerCanvasArgb(this.getReadingTextColor(), 0xFF000000);
    style.fontFamilies = [this.readerBodyFontFamily];
    style.fontSizePx = context.fp2px(this.fontSize * 1.05);
    style.fontWeight = this.getReaderFontWeight();
    style.italic = this.textItalic;
    style.letterSpacingPx = context.vp2px(this.getReaderLetterSpacingVp(this.fontSize * 1.05));
    style.underline = this.underline;
    style.underlineColorArgb = readerCanvasArgb(this.getReaderUnderlineColor(), 0xFF3E3D3B);
    style.underlineWidthPx = context.vp2px(this.resolveUnderlineWidthVp());
    style.underlineOffsetPx = context.vp2px(this.resolveUnderlineOffsetVp());
    style.underlineExtend = this.underlineExtend;
    style.dashIntervals = this.resolveUnderlineDashArray().map((value: number) => context.vp2px(value));
    return style;
  }

  /** 高亮/笔记：把本页可见的 marking 转成绘制层要的区间 + 颜色。 */
  private buildReaderCanvasMarkings(): ReaderCanvasMarking[] {
    const list: ReaderCanvasMarking[] = [];
    const page = this.localReaderPages[this.currentPageIndex];
    if (page === undefined) {
      return list;
    }
    const chapterIndex = this.getChapterIndex();
    for (let index = 0; index < this.markings.length; index++) {
      const marking = this.markings[index];
      if (!marking.enabled || marking.chapterIndex !== chapterIndex) {
        continue;
      }
      if (marking.chapterPosition >= page.endPosition || marking.endPosition <= page.startPosition) {
        continue;
      }
      const item = new ReaderCanvasMarking();
      item.start = marking.chapterPosition;
      item.end = marking.endPosition;
      item.backgroundArgb = readerCanvasMarkingBackgroundArgb(marking);
      item.decoration = readerCanvasMarkingDecoration(marking);
      item.decorationArgb = readerCanvasArgb(marking.color, 0xFF000000);
      list.push(item);
    }
    return list;
  }

  /**
   * 高亮规则命中的正文样式区间（上游 HighlightRule）。
   *
   * 画布逐元素绘制，只能把「区间 → 底色/字色/下划线」交给 ParagraphBuilder 分段，
   * 所以这里把 `readerHighlightRanges` 转成画布口径的区间数组：
   * 先放规则（按 position 升序，后面的覆盖前面的），再放用户划线里 effect==='text'
   * 的文字颜色——与老路径一致，用户手动标记压在高亮规则之上。
   *
   * 结果按 `readerContentRevision + 规则条数 + 划线条数` 缓存：翻页动画每帧都会构造
   * request，不缓存会每帧重建上千个对象。
   */
  /**
   * 命中排版对分页的影响（上游 `ReaderChapterBlockMeasurer.kt:376-392` 的测量口径）：
   * 字体、字重、斜体、颜色、下划线都不改行高，只有字号偏移与行上/下距会。
   * 这里把每条规则的整段命中位置转成分页器能用的度量表，`paginate` 与
   * `countPagesIncrementally` 共用，两边的页数才对得上。
   */
  private buildReaderSizeOffsets(): LocalReaderSizeOffset[] {
    const list: LocalReaderSizeOffset[] = [];
    if (this.readerHighlightRanges.length === 0) {
      return list;
    }
    const uiContext = this.getUIContext();
    const vpScale = uiContext.vp2px(1);
    const spScale = uiContext.fp2px(1);
    for (let index = 0; index < this.readerHighlightRanges.length; index++) {
      const range = this.readerHighlightRanges[index];
      if (range === undefined) {
        continue;
      }
      const rule = range.rule;
      // 上游对 <=0 一律当「没配」，行距不会被负值吃掉。
      const padTop = Math.max(0, rule.lineSpacingTop ?? 0) * vpScale;
      const padBottom = Math.max(0, rule.lineSpacingBottom ?? 0) * vpScale;
      const extraHeight = (rule.fontSizeOffset ?? 0) * spScale;
      if (padTop === 0 && padBottom === 0 && extraHeight === 0) {
        continue;
      }
      list.push({
        start: range.start,
        endExclusive: range.endExclusive,
        extraHeight: extraHeight,
        padTop: padTop,
        padBottom: padBottom
      });
    }
    // 分页器用单调游标扫这张表，必须按起点升序；同起点时长的在前，
    // 保证短区间不会被长区间整段跳过。
    list.sort((left: LocalReaderSizeOffset, right: LocalReaderSizeOffset): number => {
      if (left.start !== right.start) { return left.start - right.start; }
      return right.endExclusive - left.endExclusive;
    });
    return list;
  }

  private buildReaderCanvasHighlights(): ReaderCanvasStyleRange[] {
    const signature = `${this.readerContentRevision}|${this.readerHighlightRanges.length}|` +
      `${this.markings.length}|${this.getChapterIndex()}`;
    if (this.canvasHighlightSignature === signature) {
      return this.canvasHighlights;
    }
    const list: ReaderCanvasStyleRange[] = [];
    for (let index = 0; index < this.readerHighlightRanges.length; index++) {
      const range = this.readerHighlightRanges[index];
      if (range === undefined) {
        continue;
      }
      const rule = range.rule;
      // 命中排版四值：上游对 <=0 一律当「没配」（LegacyReaderStyleRangeMapper.kt:210-216），
      // 负值不能变负间距，否则后续字形会往回叠。
      const uiContext = this.getUIContext();
      const vpScale = uiContext.vp2px(1);
      const spScale = uiContext.fp2px(1);
      const spaceBeforePx = Math.max(0, rule.letterSpacingBefore ?? 0) * vpScale;
      const spaceAfterPx = Math.max(0, rule.letterSpacingAfter ?? 0) * vpScale;
      const sizeOffsetPx = Math.round((rule.fontSizeOffset ?? 0) * spScale);
      // 上游把 400 当「不覆盖」：它是 View 读者的持久化默认值，
      // 当成显式覆盖会把正文粗体拉回常规（LegacyReaderStyleRangeMapper.kt:352-358）。
      const weight = rule.fontWeight ?? 400;
      const overrideWeight = weight === 400 ? 0 : weight;
      // 上游 italic 非空 Boolean，false 就是显式「不斜体」，两个方向都要覆盖。
      const overrideItalic = rule.isItalic === true ? 1 : -1;
      const families = this.highlightRuleFontFamilies(rule.fontPath);
      const hasBase = (rule.textColor ?? 0) !== 0 || (rule.bgColor ?? 0) !== 0 ||
        readerCanvasHighlightDecoration(rule.underlineMode) !== 0 || (rule.bgImage ?? '').length > 0;
      const hasType = families.length > 0 || sizeOffsetPx !== 0 || overrideWeight !== 0;
      const hasSpace = spaceBeforePx > 0 || spaceAfterPx > 0;
      if (!hasBase && !hasType && !hasSpace) {
        // 整条规则什么都没配（只剩 italic=false 的默认值），画出来也没有区别。
        continue;
      }
      const build = (from: number, to: number, withBefore: boolean,
        withAfter: boolean): ReaderCanvasStyleRange => {
        const item = new ReaderCanvasStyleRange();
        item.start = from;
        item.end = to;
        item.textColorArgb = rule.textColor ?? 0;
        item.backgroundArgb = rule.bgColor ?? 0;
        item.decoration = readerCanvasHighlightDecoration(rule.underlineMode);
        item.decorationArgb = rule.underlineColor ?? rule.textColor ?? 0;
        // 规则自带的下划线粗细/偏移（dp），画布按 vp 口径逐行手绘时用
        item.underlineWidthVp = rule.underlineWidth ?? 0;
        item.underlineOffsetVp = rule.underlineOffset ?? 0;
        // 文字背景图（气泡图）：source/fit/scale 与九宫格四条切线、左右偏移
        item.bgImage = rule.bgImage ?? '';
        item.bgImageFit = rule.bgImageFit ?? 0;
        item.bgImageScale = rule.bgImageScale ?? 1;
        item.npLeft = rule.npLeft ?? 0.1;
        item.npRight = rule.npRight ?? 0.1;
        item.npTop = rule.npTop ?? 0.1;
        item.npBottom = rule.npBottom ?? 0.1;
        item.bgLengthOffsetLeft = rule.bgLengthOffsetLeft ?? 0;
        item.bgLengthOffsetRight = rule.bgLengthOffsetRight ?? 0;
        // 字体替换与字号偏移（上游 spToPx，已按 fp 换算）
        item.fontFamilies = families;
        item.fontWeightValue = overrideWeight;
        item.italicOverride = overrideItalic;
        item.fontSizeOffsetPx = sizeOffsetPx;
        // 命中字距：只有首字带「字前距」、只有末字带「字后距」，
        // 段内一个字都不加——段内也加调的就是整段字号了。
        item.letterSpacingBeforePx = withBefore ? spaceBeforePx : 0;
        item.letterSpacingAfterPx = withAfter ? spaceAfterPx : 0;
        return item;
      };
      if (range.endExclusive - range.start <= 1) {
        // 单字命中：它既是首字也是末字，两边都让。
        list.push(build(range.start, range.endExclusive, true, true));
      } else {
        list.push(build(range.start, range.start + 1, true, false));
        if (range.start + 1 < range.endExclusive - 1) {
          list.push(build(range.start + 1, range.endExclusive - 1, false, false));
        }
        list.push(build(range.endExclusive - 1, range.endExclusive, false, true));
      }
    }
    const chapterIndex = this.getChapterIndex();
    for (let index = 0; index < this.markings.length; index++) {
      const marking = this.markings[index];
      if (marking === undefined || !marking.enabled || marking.chapterIndex !== chapterIndex) {
        continue;
      }
      if (marking.effect !== 'text') {
        continue;
      }
      // 划线「文字颜色」：底色与下划线由 buildReaderCanvasMarkings 单独画，这里只管字色
      const item = new ReaderCanvasStyleRange();
      item.start = marking.chapterPosition;
      item.end = marking.endPosition;
      item.textColorArgb = readerCanvasArgb(marking.color, 0);
      list.push(item);
    }
    this.canvasHighlightSignature = signature;
    this.canvasHighlights = list;
    return list;
  }

  private readerCanvasPageBackgroundArgb(): number {
    // 有自定义背景图时画布不压底色（否则图片被盖住），由下层的 Image 兜底
    if (this.readerBackgroundImage.length > 0) {
      return 0x00000000;
    }
    return readerCanvasArgb(this.paperColor, 0xFFFFFFFF);
  }

  /** 没有转场时的绘制：只画 current，屏幕不空靠 renderer 铺底色兜底。 */
  /**
   * 记下画布的实测高度并驱动一次重排。
   * 首页会显示章节标题（那是画布之外的 ArkUI 组件），此时画布高度天然更矮，
   * 不能拿它当「一页可分多少」的口径，所以首页不采信，等翻到第二页再校准。
   */
  private syncReaderCanvasBodyHeight(heightVp: number): void {
    // 注意：Area 的 width/height 本来就是 vp（与 toDimension 的口径一致），
    // 这里绝不能再 px2vp 一次，否则分页高度会被缩小约 2.75 倍、一页只剩几行。
    if (heightVp <= 0) {
      return;
    }
    // 标题已进画布、不再占用画布外的纵向空间，首页与其余页的画布高度是同一个，
    // 不需要再对首页特殊处理（旧实现在首页跳过，是因为标题在画布之上）。
    if (Math.abs(heightVp - this.readerCanvasBodyHeightVp) < 1) {
      return;
    }
    this.readerCanvasBodyHeightVp = heightVp;
    this.rebuildReaderPages();
  }

  private paintReaderCanvas(): void {
    if (!this.readerCanvasReady) {
      return;
    }
    if (!this.canPaintReaderCanvas()) {
      return;
    }
    const transforms = this.turnMode === ReaderTransitionMode.NONE
      ? new ReaderTransitionTransforms()
      : ReaderPageTransitionPolicy.transforms(this.turnMode, this.turnTransition,
        this.getUIContext().vp2px(Math.max(1, this.readerContentWidth)));
    const request = this.buildReaderCanvasRequest(transforms);
    const canvas = this.readerCanvasContext.canvas;
    this.readerCanvasRenderer.draw(canvas, request);
    this.readerCanvasContext.invalidate();
    // 回填把手位置：拖把手时要用它判断有没有抓到，以及把菜单挪到选区上下方。
    this.canvasHandleStartX = request.selectionStartX;
    this.canvasHandleStartY = request.selectionStartY;
    this.canvasHandleEndX = request.selectionEndX;
    this.canvasHandleEndY = request.selectionEndY;
    this.canvasHandleStartTopY = request.selectionStartTopY;
    this.canvasHandleEndTopY = request.selectionEndTopY;
    if (this.canvasSelectionMenuVisible) {
      this.refreshCanvasSelectionMenuAnchor(request);
    }
  }

  /**
   * 划词菜单进出场：进度 0→1 淡入 + 缩放 0.94→1；关闭时 1→0 淡出 + 缩放 1→0.96。
   *
   * 时长与比例照上游 `SelectionMenuMotion.kt`：入场淡入 360ms、缩放 400ms（整段统一按 400ms
   * 跑完，透明度先到 1）、退场淡出 320ms、缩放 280ms（整段按 320ms）。
   */
  private animateCanvasSelectionMenu(show: boolean): void {
    if (this.canvasSelectionMenuAnimator !== undefined) {
      this.canvasSelectionMenuAnimator.cancel();
      this.canvasSelectionMenuAnimator = undefined;
    }
    const context = this.getUIContext();
    const duration = show ? 400 : 320;
    const startProgress = this.canvasSelectionMenuProgress;
    const endProgress = show ? 1 : 0;
    if (startProgress === endProgress) {
      return;
    }
    const animator = context.createAnimator({
      duration, easing: 'ease-out', delay: 0, fill: 'forwards', direction: 'normal',
      iterations: 1, begin: 0, end: 1
    });
    animator.onFrame = (progress: number) => {
      const value = Math.max(0, Math.min(1, progress));
      this.canvasSelectionMenuProgress = startProgress + (endProgress - startProgress) * value;
    };
    animator.onFinish = () => {
      this.canvasSelectionMenuProgress = endProgress;
      this.canvasSelectionMenuAnimator = undefined;
    };
    this.canvasSelectionMenuAnimator = animator;
    animator.play();
  }

  /** 菜单锚点：选区上方一排，放不下就挪到下方（上游 ReaderSelectionMenuAnchor）。 */
  // -------------------------------------------------------------------------
  // 手势与选区
  //
  // 三套坐标口径必须各自对齐，缺一条就会「选区跑到屏幕外」或「抓不到把手」：
  //   1. 四页窗口只对当前页记几何与画选区；
  //   2. 手指坐标用 canvasViewportY() 把 localY 换算到画布视口；
  //   3. 滚动模式再减 scrollOffset（canvasContentY）。
  // 拖动取位用 renderer.positionAt()（跨元素），端点跟把手走（canvasHandleGrabOffset）。
  // -------------------------------------------------------------------------

  /**
   * 菜单锚点：默认贴选区**下沿**（上游 `TextActionSelectionMenu.kt:674-735`）。
   *
   * 上游把菜单放在选区下方，并给末端选择柄留出净空（柄圆心在行底 +7dp、直径 14dp，
   * 预留 14dp）；只有下方放不下、上方放得下时才翻到上方。本地原来优先弹上方，
   * 选页面顶部第一行时菜单会盖住页眉，改成同一口径。
   */
  private refreshCanvasSelectionMenuAnchor(request: ReaderCanvasDrawRequest): void {
    const context = this.getUIContext();
    // 选区坐标是画布局部 px，菜单定位在外层 Stack 里，所以要加上画布自身在 Stack 中的偏移
    const offsetVp = this.readerCanvasOffsetYVp;
    const topVp = offsetVp + context.px2vp(Math.max(0, request.selectionTopY));
    const bottomVp = offsetVp + context.px2vp(Math.max(0, request.selectionBottomY));
    const centerVp = context.px2vp((request.selectionStartX + request.selectionEndX) / 2);
    // 菜单卡宽度是内容自适应（折叠态带「更多」、展开态多行），所以用实测宽度把卡片居中于
    // 选区再夹进屏幕；还没测得宽度时退回老的「中心 - 80」估算。
    const availableVp = Math.max(120, this.readerContentWidth > 0 ? this.readerContentWidth : 360);
    const menuWidthVp = this.canvasSelectionMenuWidthVp > 0
      ? Math.min(this.canvasSelectionMenuWidthVp, availableVp * 0.92)
      : 160;
    const preferredX = centerVp - menuWidthVp / 2;
    const maxXVp = Math.max(4, availableVp - menuWidthVp - 4);
    const menuX = Math.max(4, Math.min(maxXVp, preferredX));
    // 选择柄净空 14vp（柄圆心在行底 +7dp、直径 14dp），再留 12vp 垂直边距
    const handleClearanceVp: number = 14;
    const verticalMarginVp: number = 12;
    const menuHeightVp = this.canvasSelectionMenuHeightVp > 0
      ? Math.min(this.canvasSelectionMenuHeightVp, Math.max(44, this.viewportHeight * 0.5))
      : 44;
    const belowY = bottomVp + handleClearanceVp + verticalMarginVp;
    const aboveY = topVp - verticalMarginVp - menuHeightVp;
    const spaceBelow = this.viewportHeight - belowY;
    const spaceAbove = topVp - verticalMarginVp;
    // 下方放得下就贴下沿；否则上方够高才翻上去；两边都不够仍贴下沿并夹进屏幕
    let menuY = belowY;
    if (spaceBelow < menuHeightVp && spaceAbove >= menuHeightVp) {
      menuY = aboveY;
    }
    menuY = Math.max(0, Math.min(Math.max(0, this.viewportHeight - menuHeightVp), menuY));
    // 只在真的变了才写 @State，否则每次 paint 都触发一次 UI 重建，形成重绘循环
    if (Math.abs(menuX - this.canvasSelectionMenuX) > 0.5) {
      this.canvasSelectionMenuX = menuX;
    }
    if (Math.abs(menuY - this.canvasSelectionMenuY) > 0.5) {
      this.canvasSelectionMenuY = menuY;
    }
  }

  // -------------------------------------------------------------------------
  // 画布选区（阶段 C）：长按选词 → 拖把手 → 菜单
  // 上游把这块放在 ReaderCanvasSurface.kt 的手势里（LONG_PRESS_TIMEOUT_MILLIS = 600L），
  // 本地沿用同一套 pendingMarking* 记账，保证标笔记/复制/高亮链路完全不变。
  // -------------------------------------------------------------------------

  /** 只重置选区状态，不触发重绘（重排/翻页路径里调用，之后自己会画一次）。 */
  private resetCanvasSelectionState(): void {
    this.canvasCancelLongPress();
    this.canvasSelectionStart = -1;
    this.canvasSelectionEnd = -1;
    this.canvasSelectionDragging = 0;
    this.canvasHandleStartAlpha = 1;
    this.canvasHandleEndAlpha = 1;
    this.canvasSelectionMenuVisible = false;
    this.canvasSelectionMenuProgress = 0;
    this.selectionMenuMoreVisible = false;
    this.pendingMarkingRanges.clear();
    this.pendingMarkingStart = -1;
    this.pendingMarkingEnd = -1;
    this.pendingMarkingText = '';
  }

  /** 清空画布选区与菜单。 */
  private clearCanvasSelection(): void {
    this.resetCanvasSelectionState();
    this.paintReaderCanvas();
  }

  private canvasCancelLongPress(): void {
    if (this.canvasLongPressTimer >= 0) {
      clearTimeout(this.canvasLongPressTimer);
      this.canvasLongPressTimer = -1;
    }
  }

  /** 长按：起选。上游 ReaderSelectionPolicy.startWord —— 命中整词而不是单字。 */
  private startCanvasSelectionAt(xpx: number, ypx: number): void {
    const geo = this.readerCanvasRenderer.getGeometry();
    const box = this.readerCanvasRenderer.hitTestTextBox(xpx, ypx);
    if (box === undefined || box.item === undefined) {
      this.clearCanvasSelection();
      return;
    }
    const style = this.buildReaderCanvasStyle();
    const offset = this.readerCanvasRenderer.glyphOffsetAt(box, xpx, ypx, style);
    const word = this.readerCanvasRenderer.wordRangeAt(box, offset, style);
    const item = box.item;
    let start = item.startPosition + offset;
    let end = start;
    if (word !== undefined && word.end > word.start) {
      start = item.startPosition + word.start;
      end = item.startPosition + word.end;
    }
    if (end <= start) {
      // 空词（标点、空白）退化成单字，避免长按没反应。
      // 若偏移已经贴到元素末尾，start 就等于 item.endPosition，直接 +1 会被 min 夹回去，
      // 得到 start === end 的零长选区：drawSelection 拿不到任何矩形，两个把手也就无处可放
      // （表现为「长按有菜单但看不见选区、也抓不到把手」）。这种情况向前退一格。
      start = Math.max(item.startPosition, start - 1);
      end = Math.min(item.endPosition, start + 1);
    }
    this.canvasSelectionStart = start;
    this.canvasSelectionEnd = end;
    this.canvasSelectionDragging = 0;
    this.canvasSelectionMenuVisible = true;
    this.selectionMenuMoreVisible = false;
    this.animateCanvasSelectionMenu(true);
    ReaderHaptics.selectionStart(this.selectVibrator);
    this.syncCanvasSelectionToPending();
    this.paintReaderCanvas();
  }

  /**
   * 拖把手：按抓到的把手把另一端点固定，只移动被抓的那一端。
   * 上游是 grabbingStart/grabbingEnd + handleGrabOffset，本地等价于「锁定另一端」。
   */
  private dragCanvasSelectionTo(fingerXpx: number, fingerYpx: number): void {
    if (this.canvasSelectionDragging === 0 || this.canvasSelectionStart < 0) {
      return;
    }
    // 把手逻辑位置 = 手指 − 抓取偏移；圆心在行底下方一个 radius，减掉 radius 才回到行底。
    // 上游 selectionDragHandleCenter 之后再用 `y - selectionHandleRadiusPx` 做 hit-test。
    const radius = this.getUIContext().vp2px(7);
    const xpx = fingerXpx - this.canvasHandleGrabOffsetX;
    const ypx = fingerYpx - this.canvasHandleGrabOffsetY - radius;
    const style = this.buildReaderCanvasStyle();
    // 滚动模式选区要能跨 current + next + nextPlus（上游 ReaderPageWindow
    // .selectionPages()，last = 2）：窗口四页按 extent 堆叠，手指传进来的 ypx 已经是
    // canvasContentY() 换算的内容坐标，交给窗口命中按「落在哪一页内容区间」选 geometry。
    // 翻页模式仍走单页 positionAt（上游 extend 翻页 last = 0，只选当前页）。
    const position = this.usesCanvasScroll()
      ? this.readerCanvasRenderer.positionAtScrollWindow(xpx, ypx, style)
      : this.readerCanvasRenderer.positionAt(xpx, ypx, style);
    if (position < 0) {
      return;
    }
    if (this.canvasSelectionDragging === 1) {
      this.canvasSelectionStart = Math.min(position, this.canvasSelectionEnd - 1);
    } else {
      this.canvasSelectionEnd = Math.max(position, this.canvasSelectionStart + 1);
    }
    ReaderHaptics.selectionMove(this.selectVibrator);
    this.syncCanvasSelectionToPending();
    this.paintReaderCanvas();
  }

  /** 把画布选区写进 pendingMarking*，菜单动作（复制/书签/笔记）照旧可用。 */
  private syncCanvasSelectionToPending(): void {
    const start = this.canvasSelectionStart;
    const end = this.canvasSelectionEnd;
    this.pendingMarkingRanges.clear();
    if (start < 0 || end <= start) {
      this.pendingMarkingStart = -1;
      this.pendingMarkingEnd = -1;
      this.pendingMarkingText = '';
      return;
    }
    const page = this.localReaderPages[this.currentPageIndex];
    if (page === undefined) {
      return;
    }
    // 画布选区跨多行时按行拆成多个 range，与老 Span 路径的 part 记账等价
    for (let index = 0; index < page.lines.length; index++) {
      const line = page.lines[index];
      const lineStart = Math.max(start, line.startPosition);
      const lineEnd = Math.min(end, line.endPosition);
      if (lineEnd <= lineStart) {
        continue;
      }
      const range: ReaderMarkingRange = { start: lineStart, end: lineEnd };
      this.pendingMarkingRanges.set(index, range);
    }
    this.rebuildCanvasPendingMarkingRange(start, end);
  }

  /** 画布版 rebuildPendingMarkingRange：坐标已是渲染坐标，直接映射回源坐标再 trim。 */
  private rebuildCanvasPendingMarkingRange(start: number, end: number): void {
    const renderStart = Math.max(0, Math.min(this.localSemanticContent.length, start));
    const renderEnd = Math.max(renderStart, Math.min(this.localSemanticContent.length, end));
    const rawText = this.localSemanticContent.substring(renderStart, renderEnd);
    const leftTrim = rawText.length - rawText.trimStart().length;
    const selectedText = rawText.trim();
    if (selectedText.length === 0) {
      this.pendingMarkingStart = -1;
      this.pendingMarkingEnd = -1;
      this.pendingMarkingText = '';
      return;
    }
    this.pendingMarkingStart = renderStart + leftTrim;
    this.pendingMarkingEnd = this.pendingMarkingStart + selectedText.length;
    this.pendingMarkingText = selectedText;
  }

  /** 是否抓到了把手（上游 handleHitRadius 判定）。 */
  /**
   * 把手指的画布内视口坐标换成「内容坐标」。
   *
   * 版面几何（`hitTestTextBox` / `glyphOffsetAt` / 选区矩形）都是内容坐标：
   * 滚动模式下 `drawScrollSlot` 用 `canvas.translate(0, scrollOffsetPx)` 把整栈平移，
   * 几何本身没有平移。手指给的是视口坐标，所以要补回同一个偏移才能对上，
   * 否则长按选中的是别处、把手命中差出整整一个 scrollOffset（表现为「把手抓不住」）。
   */
  /**
   * 手指在画布视口内的 y（px）。
   *
   * 手势挂在最外层 Stack 上，`finger.localY` 相对 Stack；画布顶边用窗口坐标取，
   * 再减掉 Stack 自己在窗口里的顶边，得到「画布视口内」的像素偏移。
   */
  private canvasViewportY(context: UIContext, localYVp: number): number {
    // 手指 localY 相对外层 Stack，画布顶边相对 Stack 的距离要自己求：
    // 两者都用 getRectangleById 的 windowOffset（同一套屏幕坐标），相减时状态栏高度自动抵消。
    // 只减 `Area.position.y` 会漏掉父容器的标题栏/页眉占位（实测差 180px）。
    const canvasTop = this.componentWindowTopPx(ReaderPage.CANVAS_ID);
    const stackTop = this.componentWindowTopPx(ReaderPage.STACK_ID);
    const topPx = canvasTop - stackTop;
    return Math.max(0, context.vp2px(localYVp) - topPx);
  }

  /** 组件在屏幕上的顶边（px）；取不到时返回 0。 */
  private componentWindowTopPx(id: string): number {
    try {
      const rect = this.getUIContext().getComponentUtils().getRectangleById(id);
      if (rect !== undefined && rect.windowOffset !== undefined) {
        return rect.windowOffset.y;
      }
    } catch (error) {
      // 组件还没上树时取不到
    }
    return 0;
  }

  private canvasContentY(viewportYpx: number): number {
    if (!this.usesCanvasScroll()) {
      return viewportYpx;
    }
    // drawScrollSlot 里是 `canvas.translate(0, scrollOffsetPx)`，即
    // 屏幕 y = 内容 y + scrollOffsetPx，反过来内容 y = 屏幕 y − scrollOffsetPx。
    return viewportYpx - this.getUIContext().vp2px(this.scrollOffset);
  }

  /**
   * 命中判定照上游 `ReaderCanvasSurface.kt:1028`：热区 28vp，且把「竖线 + 圆柄」当作
   * 一个胶囊形手柄，求手指到「竖线顶端—圆心」中轴线的最短距离，而不是到圆心的直线距离。
   * 圆心本身在矩形 bottom 下方一个 radius 处，所以手指按在圆下方一点也能抓住。
   */
  private canvasHandleHit(xpx: number, ypx: number): number {
    if (this.canvasSelectionStart < 0 || this.canvasSelectionEnd <= this.canvasSelectionStart) {
      return 0;
    }
    const hitRadius = this.getUIContext().vp2px(28);
    const startDistance = readerCanvasHandleDistance(xpx, ypx, this.canvasHandleStartX,
      this.canvasHandleStartTopY, this.canvasHandleStartY);
    const endDistance = readerCanvasHandleDistance(xpx, ypx, this.canvasHandleEndX,
      this.canvasHandleEndTopY, this.canvasHandleEndY);
    if (startDistance <= hitRadius && startDistance <= endDistance) {
      return 1;
    }
    if (endDistance <= hitRadius) {
      return 2;
    }
    return 0;
  }

  /**
   * 把手淡入淡出：拖哪个就把哪个淡出，松手一起淡入。
   *
   * 上游 `animateFloatAsState` + tween，淡出 90ms（`SelectionHandleFadeOutMillis`）、
   * 淡入 140ms（`SelectionHandleFadeInMillis`）—— 淡出快、淡入慢，拖动手感才不糊。
   * 画布只读透明度，所以这里用 createAnimator 逐帧写字段并重绘。
   */
  private animateCanvasHandleTo(targetStart: number, targetEnd: number, duration: number): void {
    if (this.canvasHandleAnimator !== undefined) {
      try {
        this.canvasHandleAnimator.cancel();
      } catch (error) {
        console.error(`[ReaderPage] 取消选区把手动画失败: ${error}`);
      }
      this.canvasHandleAnimator = undefined;
    }
    const fromStart = this.canvasHandleStartAlpha;
    const fromEnd = this.canvasHandleEndAlpha;
    if (duration <= 0) {
      this.canvasHandleStartAlpha = targetStart;
      this.canvasHandleEndAlpha = targetEnd;
      this.paintReaderCanvas();
      return;
    }
    const animator = this.getUIContext().createAnimator({
      duration: duration,
      easing: 'ease-out',
      delay: 0,
      fill: 'forwards',
      direction: 'normal',
      iterations: 1,
      begin: 0,
      end: 1
    });
    animator.onFrame = (progress: number) => {
      this.canvasHandleStartAlpha = fromStart + (targetStart - fromStart) * progress;
      this.canvasHandleEndAlpha = fromEnd + (targetEnd - fromEnd) * progress;
      this.paintReaderCanvas();
    };
    animator.onFinish = () => {
      this.canvasHandleStartAlpha = targetStart;
      this.canvasHandleEndAlpha = targetEnd;
      this.canvasHandleAnimator = undefined;
      this.paintReaderCanvas();
    };
    this.canvasHandleAnimator = animator;
    animator.play();
  }

  /** 拖住一个把手时：该把手淡出，另一个保持可见（淡出 90ms，上游 SelectionHandleFadeOutMillis）。 */
  private fadeCanvasHandleForDrag(dragging: number): void {
    if (dragging === 1) {
      this.animateCanvasHandleTo(0, 1, ReaderPage.CANVAS_HANDLE_FADE_OUT_MILLIS);
    } else if (dragging === 2) {
      this.animateCanvasHandleTo(1, 0, ReaderPage.CANVAS_HANDLE_FADE_OUT_MILLIS);
    }
  }

  /** 松手：两个把手都恢复显示。 */
  private restoreCanvasHandleAlpha(): void {
    this.animateCanvasHandleTo(1, 1, ReaderPage.CANVAS_HANDLE_FADE_IN_MILLIS);
  }


  /** 页内容或样式变化：清段落缓存后重画。 */
  private invalidateReaderCanvas(): void {
    this.paintReaderCanvas();
  }

  /**
   * 只影响绘制、不影响排版的样式变更（下划线、颜色、背景图）。
   * 这些项不走 rebuildReaderPages——重排一次要全章测量，代价远大于重画一帧。
   */
  onReaderCanvasStyleChanged(): void {
    this.paintReaderCanvas();
  }

  /**
   * 四页窗口的图片预取。
   * 上游 ReaderCanvasSurface.kt:414-430 把 current/next/previous/nextPlus 的图一起解进 LRU，
   * 翻页那一刻绘制期直读必然命中，新页就不会闪「有字无图」的帧。
   */
  private prefetchReaderCanvasWindow(): void {
    if (this.localReaderPages.length === 0) {
      return;
    }
    const window = ReaderCanvasWindow.of(this.localReaderPages, this.currentPageIndex);
    this.readerCanvasRenderer.prefetch(window).catch((error: Error) => {
      console.warn(`[ReaderCanvas] 预取失败: ${error.message}`);
    });
    // 文字背景图（气泡图）也要随窗口预热，否则气泡晚一两帧才出现
    const sources: string[] = [];
    for (const highlight of this.buildReaderCanvasHighlights()) {
      if (highlight.bgImage.length > 0 && !sources.includes(highlight.bgImage)) {
        sources.push(highlight.bgImage);
      }
    }
    if (sources.length > 0) {
      this.readerCanvasRenderer.prefetchBackgrounds(sources).catch((error: Error) => {
        console.warn(`[ReaderCanvas] 文字背景图预取失败: ${error.message}`);
      });
    }
  }

  private onReaderContentAreaChanged(oldArea: Area, newArea: Area): void {
    this.rebuildReaderPages();
    if (this.usesLocalPagination()) { return; }
    // 连续滚动模式没有 Scroll 组件可量，进度只由分页累加高度推出（readerScrollTotalHeight）
    this.restoreProgressPosition();
    this.updateProgress();
  }

  private getReadingTextColor(): string {
    // 有配置色就用配置色（上游 textColor/textColorNight 可配任意色）；
    // 空串说明还没装载过设置，回落到上游无数据层 readConfig.json[0] 的正文色。
    if (this.readingTextColor.length > 0) { return this.readingTextColor; }
    return this.paperColor === '#000000' || this.paperColor === '#343832' || this.paperColor === '#3C3F43'
      ? '#ADADAD' : '#ff0b0b0b';
  }

  /** 背景图片的 `file://` URI；空串时返回空串，由调用方判断是否渲染。 */
  private backgroundImageSource(): string {
    const path = this.readerBackgroundImage;
    if (path.length === 0) { return ''; }
    return path.startsWith('file://') ? path : `file://${path}`;
  }

  /** 上游 readerBackgroundAlpha：0..100 百分比换算成 0..1。 */
  private backgroundImageAlpha(): number {
    return Math.max(0, Math.min(1, this.backgroundAlpha / 100));
  }

  private isReaderHeaderVisible(): boolean {
    // HOS 目前保留系统状态栏；Android 模式0在状态栏显示时隐藏页眉。
    return this.infoSettings.headerMode === 1;
  }

  private isReaderFooterVisible(): boolean {
    return this.infoSettings.footerMode !== 1;
  }

  private getReaderInfoFontSize(isHeader: boolean): number {
    const size = isHeader || this.infoSettings.applyHeaderStyle
      ? this.infoSettings.headerFontSize : this.infoSettings.footerFontSize;
    return size > 0 ? size : 12;
  }

  private getReaderInfoColor(isHeader: boolean): string {
    const useHeaderStyle = isHeader || this.infoSettings.applyHeaderStyle;
    const isNightPaper = this.paperColor === '#000000' || this.paperColor === '#343832' || this.paperColor === '#3C3F43';
    const configuredColor = useHeaderStyle
      ? (isNightPaper ? this.infoSettings.tipHeaderColorNight : this.infoSettings.tipHeaderColor)
      : (isNightPaper ? this.infoSettings.tipFooterColorNight : this.infoSettings.tipFooterColor);
    if (configuredColor === 0) { return this.getReadingTextColor(); }
    const unsignedColor = configuredColor < 0 ? configuredColor + 4294967296 : configuredColor;
    const hexColor = unsignedColor.toString(16).padStart(8, '0');
    return `#${hexColor.substring(2)}`;
  }

  private getReaderInfoDividerColor(): string {
    if (this.infoSettings.tipDividerColor === -1) { return '#66666A'; }
    if (this.infoSettings.tipDividerColor === 0) { return this.getReadingTextColor(); }
    const unsignedColor = this.infoSettings.tipDividerColor < 0
      ? this.infoSettings.tipDividerColor + 4294967296 : this.infoSettings.tipDividerColor;
    const hexColor = unsignedColor.toString(16).padStart(8, '0');
    return `#${hexColor.substring(2)}`;
  }

  private getReaderInfoValue(type: number, customTemplate: string): string {
    const currentPage = this.localReaderPages[this.currentPageIndex];
    const chapterCount = this.getChapterCount();
    const pageCount = this.localReaderPages.length;
    const chapterTitle = this.displayChapterTitle;
    const time = new Date();
    const timeText = `${time.getHours().toString().padStart(2, '0')}:${time.getMinutes().toString().padStart(2, '0')}`;
    const batteryPercent = Math.max(0, Math.min(100, batteryInfo.batterySOC));
    const progressText = `${this.getWholeBookProgress().toFixed(1)}%`;
    const fullPageIndex = this.getWholeBookPageIndex();
    const fullPageCount = this.getWholeBookPageCount();
    // Android 的自定义占位符在整本页数暂不可用时回退到本章页码和页数。
    const customFullPageIndex = fullPageIndex > 0 ? `${fullPageIndex}` : `${this.currentPageIndex + 1}`;
    const customFullPageCount = fullPageCount > 0 ? `${fullPageCount}` : `${Math.max(1, pageCount)}`;
    let value = '';
    if (type === 1) { value = chapterTitle; }
    else if (type === 2) { value = timeText; }
    else if (type === 3 || type === 10 || type === 13 || type === 14 || type === 15) { value = `${batteryPercent}%`; }
    else if (type === 4) { value = `${this.currentPageIndex + 1}/${pageCount > 0 ? pageCount : '-'}`; }
    else if (type === 5) { value = progressText; }
    else if (type === 6) { value = `${this.currentPageIndex + 1}/${pageCount > 0 ? pageCount : '-' }  ${progressText}`; }
    else if (type === 7) { value = this.book.title; }
    else if (type === 8 || type === 9 || type === 16) { value = `${timeText} ${batteryPercent}%`; }
    else if (type === 11) { value = `${this.getChapterIndex() + 1}/${chapterCount}`; }
    else if (type === 12 || type === 17) { value = `${chapterTitle} ›`; }
    else if (type === 18) {
      value = customTemplate
        .replaceAll('{BookName}', this.book.title)
        .replaceAll('{ChapterTitle}', chapterTitle)
        .replaceAll('{Time}', timeText)
        .replaceAll('{BatteryPercent}', `${batteryPercent}%`)
        .replaceAll('{ChapterIndex}', `${this.getChapterIndex() + 1}`)
        .replaceAll('{ChapterSize}', `${chapterCount}`)
        .replaceAll('{PageIndex}', `${this.currentPageIndex + 1}`)
        .replaceAll('{PageSize}', `${pageCount > 0 ? pageCount : '-'}`)
        .replaceAll('{PageRemaining}', `${pageCount > 0 ? Math.max(0, pageCount - this.currentPageIndex - 1) : '-'}`)
        .replaceAll('{ReadProgress}', progressText)
        .replaceAll('{FullPageIndex}', customFullPageIndex)
        .replaceAll('{FullPageSize}', customFullPageCount);
    } else if (type === 19) { value = this.getWholeBookPageText(); }
    else if (type === 20) { value = `${this.getWholeBookPageText()}  ${progressText}`; }
    if (currentPage === undefined && type === 4) { return '-'; }
    return value;
  }

  private getReaderInfoType(isHeader: boolean, position: number): number {
    if (isHeader) {
      if (position === 0) { return this.infoSettings.tipHeaderLeft; }
      if (position === 1) { return this.infoSettings.tipHeaderMiddle; }
      return this.infoSettings.tipHeaderRight;
    }
    if (position === 0) { return this.infoSettings.tipFooterLeft; }
    if (position === 1) { return this.infoSettings.tipFooterMiddle; }
    return this.infoSettings.tipFooterRight;
  }

  private getReaderInfoTemplate(isHeader: boolean, position: number): string {
    if (isHeader) {
      if (position === 0) { return this.infoSettings.customTipHeaderLeft; }
      if (position === 1) { return this.infoSettings.customTipHeaderMiddle; }
      return this.infoSettings.customTipHeaderRight;
    }
    if (position === 0) { return this.infoSettings.customTipFooterLeft; }
    if (position === 1) { return this.infoSettings.customTipFooterMiddle; }
    return this.infoSettings.customTipFooterRight;
  }

  /** 图形型 tip：只在页眉页脚画图标/电池，不画文字（上游 LegacyReaderPageDecorationFactory.kt:253-263）。 */
  private isReaderInfoGraphic(type: number): boolean {
    return type === 3 || type === 8 || type === 13 || type === 14 || type === 15 || type === 16;
  }

  /** 图形型 tip 里仍带文字的那几种（时间、章节名），其余图形型只画图标。 */
  private readerInfoGraphicKeepsText(type: number): boolean {
    return type === 8 || type === 16;
  }

  /**
   * 同一种 tip 只显示在最靠前的位置（上游 LegacyReaderPageDecorationFactory.kt:241-245）。
   * 这样左中右三栏重复选中同一项时，不会三处都显示同一段文字。
   */
  private isReaderInfoDuplicated(isHeader: boolean, position: number): boolean {
    const type = this.getReaderInfoType(isHeader, position);
    if (type === 0) { return false; }
    const template = this.getReaderInfoTemplate(isHeader, position);
    for (let index = 0; index < position; index++) {
      if (this.getReaderInfoType(isHeader, index) !== type) { continue; }
      // 自定义模板要连模板一起比：同是「自定义」但模板不同的两处都该显示。
      if (type === 18 && this.getReaderInfoTemplate(isHeader, index) !== template) { continue; }
      return true;
    }
    return false;
  }

  /** 电池图形（上游 tipBattery / tipBatteryClassic 的形态，用基础形状画，不引额外资源）。 */
  @Builder
  private ReaderInfoBattery(type: number, tint: string) {
    if (type === 3 || type === 8) {
      // 电池外框 + 内部填充。
      Row() {
        Stack({ alignContent: Alignment.Start }) {
          Row().width(`${Math.max(4, Math.min(100, this.readerInfoBatteryPercent()))}%`.toString())
            .height('100%').backgroundColor(tint).borderRadius(1)
        }.width(22).height(11).border({ width: 1, color: tint, radius: 2 })
        Column().width(2).height(5).backgroundColor(tint).borderRadius(1).margin({ left: 1 })
      }.height(12).justifyContent(FlexAlign.Center)
    } else if (type === 13) {
      // 电量内显：电池框里再叠一个百分比数字由外层文字负责，这里只画框与填充。
      Stack({ alignContent: Alignment.Start }) {
        Row().width(`${Math.max(4, Math.min(100, this.readerInfoBatteryPercent()))}%`.toString())
          .height('100%').backgroundColor(tint).borderRadius(1)
      }.width(26).height(12).border({ width: 1, color: tint, radius: 2 })
    } else if (type === 14) {
      // 仅电量图标：只画一段电量条。
      Stack({ alignContent: Alignment.Start }) {
        Row().width(`${Math.max(4, Math.min(100, this.readerInfoBatteryPercent()))}%`.toString())
          .height('100%').backgroundColor(tint).borderRadius(1)
      }.width(22).height(10).backgroundColor('#33FFFFFF').borderRadius(2)
    } else {
      // 经典电量：实心胶囊 + 百分比由外层文字负责，这里只画胶囊。
      Stack({ alignContent: Alignment.Start }) {
        Row().width(`${Math.max(6, Math.min(100, this.readerInfoBatteryPercent()))}%`.toString())
          .height('100%').backgroundColor(tint).borderRadius(2)
      }.width(24).height(9).backgroundColor('#33FFFFFF').borderRadius(2)
    }
  }

  private readerInfoBatteryPercent(): number {
    return Math.max(0, Math.min(100, batteryInfo.batterySOC));
  }

  @Builder
  private ReaderInfoRow(isHeader: boolean) {
    Column() {
      Row() {
        this.ReaderInfoSlot(isHeader, 0, TextAlign.Start)
        this.ReaderInfoSlot(isHeader, 1, TextAlign.Center)
        this.ReaderInfoSlot(isHeader, 2, TextAlign.End)
      }.width('100%').height(18)
      if ((isHeader && this.infoSettings.showHeaderLine) || (!isHeader && this.infoSettings.showFooterLine)) {
        Column().width('100%').height(1).backgroundColor(this.getReaderInfoDividerColor())
      }
    }.width('100%').padding({
      left: isHeader ? this.paddingSettings.headerPaddingLeft : this.paddingSettings.footerPaddingLeft,
      right: isHeader ? this.paddingSettings.headerPaddingRight : this.paddingSettings.footerPaddingRight,
      top: 2 + (isHeader ? this.paddingSettings.headerPaddingTop : this.paddingSettings.footerPaddingTop),
      bottom: 2 + (isHeader ? this.paddingSettings.headerPaddingBottom : this.paddingSettings.footerPaddingBottom)
    })
  }

  /** 页眉页脚的单栏内容：图形型 tip 画图标，文字型画文字，重复的 tip 留空。 */
  @Builder
  private ReaderInfoSlot(isHeader: boolean, position: number, align: TextAlign) {
    Row() {
      if (this.isReaderInfoGraphic(this.getReaderInfoType(isHeader, position)) &&
        !this.isReaderInfoDuplicated(isHeader, position)) {
        this.ReaderInfoBattery(this.getReaderInfoType(isHeader, position), this.getReaderInfoColor(isHeader))
        if (this.readerInfoGraphicKeepsText(this.getReaderInfoType(isHeader, position))) {
          Text(this.getReaderInfoValue(this.getReaderInfoType(isHeader, position),
            this.getReaderInfoTemplate(isHeader, position)))
            .fontSize(this.getReaderInfoFontSize(isHeader)).fontFamily(this.readerInfoFontFamily(isHeader))
            .fontColor(this.getReaderInfoColor(isHeader)).margin({ left: 4 })
            .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
        }
      } else {
        Text(this.isReaderInfoDuplicated(isHeader, position) ? ''
          : this.getReaderInfoValue(this.getReaderInfoType(isHeader, position),
            this.getReaderInfoTemplate(isHeader, position)))
          .fontSize(this.getReaderInfoFontSize(isHeader)).fontFamily(this.readerInfoFontFamily(isHeader))
          .fontColor(this.getReaderInfoColor(isHeader))
          .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
      }
    }.layoutWeight(1).height('100%')
      .justifyContent(align === TextAlign.Start ? FlexAlign.Start
        : align === TextAlign.Center ? FlexAlign.Center : FlexAlign.End)
  }

  build() {
    Stack() {
      // 自定义背景图片铺满整屏，垫在正文与底栏之下；不拦截触摸，透明度取 bgAlpha。
      if (this.readerBackgroundImage.length > 0) {
        Image(this.backgroundImageSource())
          .width('100%')
          .height('100%')
          .objectFit(ImageFit.Cover)
          .opacity(this.backgroundImageAlpha())
          .hitTestBehavior(HitTestMode.None)
      }
      // 只要格式走本地分页，就一律进画布分支——哪怕这一帧还没有排好页。
      // 上游 ReaderCanvasSurface.kt:254 是 `val current = pages.current ?: return`：
      // 没有当前页就什么都不画，绝不换「整章连续滚动」那套排版兜底，
      // 否则开书时先滚动再切分页，两套排版视觉不同，切换必然整页跳一次。
      // 连续滚动（pageAnimation === 3）现在也走画布：上游 ReaderCanvasSurface.kt:1517-1540
      // 在滚动模式下用同一个 Canvas 画 ScrollPageStack，不再有第二套 ArkUI 排版。
      if (this.usesReaderCanvas()) {
        Stack({ alignContent: Alignment.TopEnd }) {
          Column() {
            if (this.isReaderHeaderVisible()) {
              Column() { this.ReaderInfoRow(true) }
                .width('100%')
                .padding({
                  left: this.resolveReaderColumnCount() > 1 ? this.paddingSettings.paddingLeft : 0,
                  right: this.resolveReaderColumnCount() > 1 ? this.paddingSettings.paddingRight : 0
                })
            }
            // 章标题不再是画布外的 ArkUI 组件：它已经作为带 `titleFontScale` 的标题行
            // 排进块流，跟着正文一起翻页、一起滚动（上游 `ReaderPaginator.kt:1112-1116`）。
            // 旧实现在这里插 `ReaderTitleSegments`，滚动模式下标题不参与滚动栈平移，
            // 就是 KI-REL2「标题与正文分离」。
            // 正文：单个 Canvas 逐行绘制（对齐上游 ReaderCanvasSurface）。
            // 四页窗口按 z 序画进同一张画布，因此不能有多个 Canvas 抢同一个 context。
            Canvas(this.readerCanvasContext)
              .id(ReaderPage.CANVAS_ID)
              .width('100%')
              .layoutWeight(1)
              // 画布是纯绘制、自身没有任何文字节点，读屏软件原本读不到正文。
              // 上游用 `clearAndSetSemantics` 把整页文本、书签状态、翻页动作一次性挂上去
              // （`ReaderCanvasSurface.kt:922-980`），这里同样把描述、状态与两个自定义动作挂在画布上。
              .accessibilityText(this.getCanvasAccessibilityDescription())
              .accessibilityStateDescription(this.getCanvasAccessibilityStateDescription())
              .accessibilityCustomActions([
                {
                  name: '上一页',
                  onAction: () => { this.accessibilityTurnPage(false); }
                },
                {
                  name: '下一页',
                  onAction: () => { this.accessibilityTurnPage(true); }
                }
              ])
              .onReady(() => {
                this.readerCanvasReady = true;
                this.paintReaderCanvas();
              })
              .onAreaChange((oldArea: Area, newArea: Area) => {
                // 菜单要定位在外层 Stack 里，记下画布自己的纵向偏移（Area 的 position 单位是 vp）
                this.readerCanvasOffsetYVp = readerLengthToNumber(newArea.position.y ?? 0);
                this.syncReaderCanvasBodyHeight(readerLengthToNumber(newArea.height));
                this.paintReaderCanvas();
              })
            if (this.isReaderFooterVisible()) {
              Column() { this.ReaderInfoRow(false) }
                .width('100%')
                .padding({
                  left: this.resolveReaderColumnCount() > 1 ? this.paddingSettings.paddingLeft : 0,
                  right: this.resolveReaderColumnCount() > 1 ? this.paddingSettings.paddingRight : 0
                })
            }
          }
          .width('100%')
          .height('100%')
          // 左右内边距一律由每一列自己带（见正文那层 Row）。外层再加一次会让单页
          // 的左边距变成两倍（16vp → 32vp），右边距则被列宽顶出屏幕。
          .padding({
            left: 0,
            right: 0,
            top: this.paddingSettings.paddingTop,
            bottom: this.paddingSettings.paddingBottom
          })
          .translate({ x: this.pageTurnOffsetX, y: this.pageTurnOffsetY + this.bookmarkPullOffset })
          .opacity(this.pageTurnOpacity)
          // 书签角标贴在正文区右上角；与正文同属这层 Stack，翻页动画和下拉偏移一并作用。
          if (this.shouldShowBookmarkBadge()) {
            Column() {
              this.BookmarkBadgeRibbon()
            }
            // 上游 leftPx = 页宽 - 右内边距 - 6dp - 角标宽度，即右边距为「右内边距 + 6dp」；
            // topPx = 正文视口顶边，与页眉不重叠。
            .margin({
              top: this.paddingSettings.paddingTop + (this.isReaderHeaderVisible() ? this.getReaderInfoReserve(true) : 0),
              right: this.paddingSettings.paddingRight + 6
            })
            .translate({ x: this.pageTurnOffsetX, y: this.pageTurnOffsetY + this.bookmarkPullOffset })
            .opacity(this.pageTurnOpacity)
          }
          // 画布选区菜单：浮在选区上方（放不下就挪到下方），复用老路径同一套菜单项
          if ((this.canvasSelectionMenuVisible || this.canvasSelectionMenuProgress > 0.01) &&
            this.canvasSelectionStart >= 0) {
            Column() {
              this.readerMarkingSelectionMenu()
            }
            .position({ x: this.canvasSelectionMenuX, y: this.canvasSelectionMenuY })
            // 进出场：透明度线性走，缩放从 0.94 长到 1（退场收到 0.96）
            .opacity(this.canvasSelectionMenuProgress)
            .scale({
              x: 0.94 + 0.06 * this.canvasSelectionMenuProgress,
              y: 0.94 + 0.06 * this.canvasSelectionMenuProgress
            })
            // 卡片是按内容自适应宽高的，锚点需要实测尺寸才能把它夹进屏幕
            .onAreaChange((_oldArea: Area, newArea: Area) => {
              const widthVp = Number(newArea.width);
              const heightVp = Number(newArea.height);
              if (Math.abs(widthVp - this.canvasSelectionMenuWidthVp) > 0.5) {
                this.canvasSelectionMenuWidthVp = widthVp;
              }
              if (Math.abs(heightVp - this.canvasSelectionMenuHeightVp) > 0.5) {
                this.canvasSelectionMenuHeightVp = heightVp;
              }
            })
          }
        }
        .id(ReaderPage.STACK_ID)
        .width('100%')
        .height('100%')
        // 有自定义背景图片时这层不能压不透明底色，否则图片被盖住。
        .backgroundColor(this.readerBackgroundImage.length > 0 ? '#00000000' : this.paperColor)
        .onAreaChange((oldArea: Area, newArea: Area) => {
          this.readerContentWidth = readerLengthToNumber(newArea.width);
          this.viewportHeight = readerLengthToNumber(newArea.height);
          this.rebuildReaderPages();
        })
        .gesture(GestureGroup(GestureMode.Parallel,
          // 画布选区（阶段 C）：长按选词 → 拖把手。上游 LONG_PRESS_TIMEOUT_MILLIS = 600L。
          LongPressGesture({ repeat: false, duration: 600 })
            .onAction((event: GestureEvent) => {
              const finger = event.fingerList !== undefined && event.fingerList.length > 0
                ? event.fingerList[0] : undefined;
              if (finger === undefined) {
                return;
              }
              const context = this.getUIContext();
              this.canvasLongPressX = context.vp2px(finger.localX);
              // 手势挂在最外层 Stack 上，文字画布的局部坐标 = 手指坐标 - 画布自身偏移
              this.canvasLongPressY = this.canvasContentY(
                this.canvasViewportY(context, finger.localY));
              this.startCanvasSelectionAt(this.canvasLongPressX, this.canvasLongPressY);
              this.canvasSuppressTap = true;
            }),
          TapGesture().onAction((event: GestureEvent) => {
            const finger = event.fingerList[0];
            if (finger !== undefined) {
              if (this.canvasSuppressTap) {
                this.canvasSuppressTap = false;
                return;
              }
              if (this.canvasSelectionStart >= 0) {
                // 有选区时单击先收掉选区与菜单，不要误触翻页/菜单热区
                this.clearCanvasSelection();
                return;
              }
              this.handleReaderTapAt(finger.localX, finger.localY);
            }
          }),
          PanGesture({ direction: PanDirection.Horizontal })
            .onActionStart((event: GestureEvent) => {
              // 先判有没有抓到选区把手：抓到了这一段拖动就只挪把手，不翻页
              if (this.canvasSelectionStart < 0) {
                this.canvasSelectionDragging = 0;
                this.horizontalDragLocked = false;
                this.horizontalDragLastOffsetVp = 0;
                return;
              }
              const context = this.getUIContext();
              const finger = event.fingerList !== undefined && event.fingerList.length > 0
                ? event.fingerList[0] : undefined;
              if (finger === undefined) {
                return;
              }
              const hitX = context.vp2px(finger.localX);
              const hitY = this.canvasContentY(this.canvasViewportY(context, finger.localY));
              this.canvasSelectionDragging = this.canvasHandleHit(hitX, hitY);
              if (this.canvasSelectionDragging !== 0) {
                const fingerX = context.vp2px(finger.localX);
                const fingerY = this.canvasContentY(
                  this.canvasViewportY(context, finger.localY));
                const centerX = this.canvasSelectionDragging === 1
                  ? this.canvasHandleStartX : this.canvasHandleEndX;
                const centerY = this.canvasSelectionDragging === 1
                  ? this.canvasHandleStartY : this.canvasHandleEndY;
                this.canvasHandleGrabOffsetX = fingerX - centerX;
                this.canvasHandleGrabOffsetY = fingerY - centerY;
                this.fadeCanvasHandleForDrag(this.canvasSelectionDragging);
              }
            })
            .onActionUpdate((event: GestureEvent) => {
              if (this.canvasSelectionDragging === 0) {
                // 拖拽期就把页面跟着手指挪（上游 ReaderCanvasSurface.kt:1304-1330）：
                // 越过 touch-slop 时锁定方向并记下锁定点，之后位移从锁定点算起。
                this.updateHorizontalPageDrag(event);
                return;
              }              const context = this.getUIContext();
              const finger = event.fingerList !== undefined && event.fingerList.length > 0
                ? event.fingerList[0] : undefined;
              if (finger === undefined) {
                return;
              }
              this.dragCanvasSelectionTo(context.vp2px(finger.localX),
                this.canvasContentY(this.canvasViewportY(context, finger.localY)));
            })
            .onActionEnd((event: GestureEvent) => {
              if (this.canvasSelectionDragging !== 0) {
                this.canvasSelectionDragging = 0;
                this.restoreCanvasHandleAlpha();
                this.paintReaderCanvas();
                return;
              }
              this.finishHorizontalPageDrag(event);
            }),
          // 连续滚动的纵向拖动：delta 符号直接沿用 ArkUI 的 offsetY（手指向下为正），
          // 与上游 ReaderCanvasSurface.kt 拿 moveDelta.y 当 delta 同口径。
          // 拖拽期就会跨页（applyReaderScrollDelta 内部改 currentPageIndex），
          // 所以抬手时不需要再收口。
          PanGesture({ direction: this.usesCanvasScroll() ? PanDirection.Vertical : PanDirection.None })
            .onActionStart(() => {
              this.cancelTurnAnimator();
              this.pageTurnAnimating = false;
              this.scrollDragLastY = 0;
              this.scrollDragBoundaryTurned = false;
            })
            .onActionUpdate((event: GestureEvent) => {
              // ArkUI 的 offsetY 是相对手势起点的累计量，apply 要的是逐帧 delta
              const deltaVp = event.offsetY - this.scrollDragLastY;
              if (deltaVp === 0) {
                return;
              }
              this.scrollDragLastY = event.offsetY;
              // KI-REL1：拖动期到达章末就要换章。此前这里丢掉返回值，章末只亮
              // 「继续滑动以加载下一章…」提示页而不换章；慢速拖到章末再松手时速度不足
              // 8vp，惯性直接 return，于是永远停在本章末页——这正是「跳章」的另一半。
              // 与分页翻页（:2167）、惯性滚动（:2431）同口径：命中边界就转成换章。
              // 一次拖动只转一次：换章是异步的，后续帧仍会命中边界，不设闸门会连跳数章。
              if (this.scrollDragBoundaryTurned) {
                return;
              }
              if (this.applyReaderScrollDelta(this.getUIContext().vp2px(deltaVp))) {
                this.scrollDragBoundaryTurned = true;
                this.cancelTurnAnimator();
                this.updateProgress();
                this.onTurnChapterBoundary(deltaVp < 0 ? 1 : -1);
              }
            })
            .onActionEnd((event: GestureEvent) => {
              this.updateProgress();
              // 抬手惯性（上游 ReaderCanvasSurface.kt:1414-1452 animateDecay）。
              // 速度沿用 ArkUI 给的 velocityY（vp/s，手指向下为正），与 delta 同号。
              this.startReaderScrollFling(event.velocityY ?? 0);
            }),
          PanGesture({ direction: this.swipeToAddBookmark && this.book.isLocal && this.pageAnimation !== 3
            ? PanDirection.Vertical : PanDirection.None })
            .onActionStart(() => {
              this.bookmarkWillRemove = this.hasBookmarkOnCurrentPage();
              this.bookmarkPullOffset = 0;
              this.bookmarkPullArmed = false;
            })
            .onActionUpdate((event: GestureEvent) => this.updateBookmarkPull(event))
            .onActionEnd((event: GestureEvent) => this.finishBookmarkPull(event))
        ))
      }
      // 连续滚动与分页共用同一张画布（上游 ScrollPageStack），这里不再有第二套
      // ArkUI 排版分支：`Scroll` 整章铺开那套拿不到行几何，下划线与选区都缺。

      if (this.bookmarkPullArmed && !this.controlsVisible) {
        Row() {
          Text(this.bookmarkWillRemove ? '松手以取消书签' : '松手以添加书签')
            .fontSize(14).fontColor('#FFFFFF')
        }
        .padding({ left: 16, right: 16, top: 8, bottom: 8 })
        .backgroundColor('#A0000000')
        .borderRadius(24)
        .margin({ top: 72 })
        .alignSelf(ItemAlign.Center)
        .zIndex(10)
      }
      if (this.controlsVisible) {
        Stack() {
          Column()
            .width('100%')
            .height('100%')
            .backgroundColor('#01000000')
            .onClick(() => {
              this.controlsVisible = false;
              this.overflowVisible = false;
              this.imageStyleMenuVisible = false;
            })
          Column() {
            Column() {
              Row() {
                Stack({ alignContent: Alignment.Center }) {
                  Image($r('app.media.reader_back')).width(20).height(20).fillColor(this.readerMenuForeground())
                }.width(40).height(40).onClick(() => this.onBack())
                // 胶囊模式：书名 + 章节名压成一行两段，独占中间剩余宽度（上游 ReadBookMenuBarTitle.kt:198/492）。
                if (this.readerTitleCapsuleVisible()) {
                  this.readerTitleCapsule()
                } else {
                  // 非胶囊模式：仅 titleBarMode 为 "0"/"2" 时书名留在应用栏行内（:207）。
                  if (this.readerTitleInlineVisible()) {
                    // 上游 `ReadBookMenuBarTitle.kt:207-221`：非胶囊模式的书名同样 combinedClickable
                    // 进书籍详情，不是纯展示文本。
                    Text(this.book.title).fontSize(16).fontColor(this.readerMenuForeground()).maxLines(1)
                      .layoutWeight(1).padding({ left: 8, right: 8, top: 4, bottom: 4 })
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                      .onClick(() => this.onOpenBookInfo())
                      .gesture(LongPressGesture({ duration: 500 }).onAction((_event: GestureEvent): void => {
                        this.onOpenBookInfo();
                      }))
                  }
                  Blank().layoutWeight(1)
                }
                this.readerTopActionGroup()
              }.width('100%').padding({ left: 16, right: 16, top: 12, bottom: 4 })
              // 模式 "1"：书名单独占一行（上游 :239）。
              if (this.readerTitleOwnLineVisible()) {
                // 上游 `ReadBookMenuBarTitle.kt:239-252`：独占一行的书名同样可点进详情。
                Text(this.book.title).fontSize(16).fontColor(this.readerMenuForeground()).maxLines(1)
                  .width('100%').padding({ left: 16, right: 16, top: 4, bottom: 4 })
                  .onClick(() => this.onOpenBookInfo())
                  .gesture(LongPressGesture({ duration: 500 }).onAction((_event: GestureEvent): void => {
                    this.onOpenBookInfo();
                  }))
              }
              // 模式 "0"/"1"：章节名独占一行（上游 :259）。
              if (this.readerChapterLineVisible()) {
                Text(this.displayChapterTitle).fontSize(12).fontColor(this.readerMenuForeground()).maxLines(1)
                  .width('100%').padding({ left: 16, right: 16, top: 4, bottom: 8 })
              }
            }
            .width('100%')
            .backgroundColor(this.readerTopBarFillColor())
            .linearGradient(this.readerTopBarGradient())
            // KI-E2：菜单栏边框（宽度同时是开关）与背景模糊半径，对齐上游
            // `ReadBookMenuBarTitle.kt:504-521`（描边）与 `:131`（`blurRadius = readMenuBlurRadius`）。
            .border(this.readerMenuBorderSettings())
            .backdropBlur(this.readerMenuBlurRadiusVp())

          // KI-E3：位置 0/1 的浮动图标行贴在顶栏下方（上游 ReadBookMenuBar.kt:172）。
          if (this.readerFloatingIconTopVisible()) {
            this.readerFloatingIconRow(this.titleBarIconPosition)
          }

          if (this.showQuickActions) {
            Row() {
              ReaderControl({ kind: 'search', active: false, menuForeground: this.readerMenuForeground(), menuAccent: this.readerMenuAccentTint(), onSelect: () => this.onOpenSearchContent() })
              ReaderControl({ kind: 'autoPage', active: this.autoPageActive, menuForeground: this.readerMenuForeground(), menuAccent: this.readerMenuAccentTint(), onSelect: (): void => this.toggleAutoPage() })
              ReaderControl({ kind: 'catalog', active: false, menuForeground: this.readerMenuForeground(), menuAccent: this.readerMenuAccentTint(), onSelect: () => this.onOpenCatalog() })
              ReaderControl({ kind: 'voice', active: false, menuForeground: this.readerMenuForeground(), menuAccent: this.readerMenuAccentTint(), onSelect: (): void => { this.onUnavailableAction('朗读播放尚未迁移'); }, onLongSelect: (): void => { this.onOpenReadAloud(); } })
              ReaderControl({ kind: 'settings', active: false, menuForeground: this.readerMenuForeground(), menuAccent: this.readerMenuAccentTint(), onSelect: () => this.onOpenSettings() })
            }.width('100%').justifyContent(FlexAlign.Start).padding({ left: 18, right: 18, top: 8, bottom: 8 })
          }

          Blank().layoutWeight(1)

          // KI-E3：位置 2/3 的浮动图标行贴在菜单浮层上方（上游 ReadBookMenuBar.kt:310-330）。
          if (this.readerFloatingIconBottomVisible()) {
            this.readerFloatingIconRow(this.titleBarIconPosition)
          }

          Column() {
            // 横排亮度条贴在底栏里（上游 `ReadBookMenuBarBottom.kt:139`）；
            // 竖排的是独立浮层，不跟底栏一起排版，见下面 `showBrightnessView === '2'` 的分支。
            if (this.showBrightnessView === '1') {
              this.ReaderBrightnessBar(false)
            }
            // 上游 `ReadBookMenuBarBottom.kt:161-196`：`AnimatedVisibility(readSliderMode != "1")`
            // 只包住**中间那根 Slider**，两侧的上一章/下一章按钮在 `readSliderMode == "1"` 时仍然保留。
            // 本地原先把整行一起藏掉，隐藏进度条后连换章按钮都没了。
            Row() {
              Stack({ alignContent: Alignment.Center }) {
                Image($r('app.media.reader_back')).width(20).height(20).fillColor(this.readerMenuForeground())
              }.width(40).height(40).onClick(() => this.turnReaderChapter(-1))
              if (this.readSliderMode !== '1') {
                Stack({ alignContent: Alignment.Center }) {
                  Slider({
                    value: this.sliderProgressIndex,
                    min: 0,
                    max: Math.max(0, this.getProgressSliderMaximum()),
                    step: 1,
                    style: SliderStyle.InSet
                  })
                    .width('100%').height(40)
                    .selectedColor(this.readerMenuAccentTint()).trackColor('#5A3F47').blockColor('#00000000')
                    .trackThickness(6)
                    .blockSize({ width: 12, height: 12 })
                    .showSteps(true).stepColor(this.readerMenuAccentTint()).stepSize(3)
                    // 无障碍文案：上游 `ReadBookMenuBarBottom.kt:84-95` 按 `progressBarBehavior`
                    // 念「第 x / 共 y 页」或「第 x / 共 y 章」。本地没有读屏器自定义能力，
                    // 用 `accessibilityText` 把同一句挂在滑块上。
                    .accessibilityText(this.getProgressAccessibilityText())
                    .onChange((value: number, mode: SliderChangeMode) => {
                      const maximum = this.getProgressSliderMaximum();
                      const index = Math.max(0, Math.min(maximum, Math.round(value)));
                      this.sliderProgressIndex = index;
                      if (this.pageAnimation === 3) {
                        if (mode === SliderChangeMode.End || mode === SliderChangeMode.Click) {
                          this.seekToProgress(index);
                        }
                      } else if (this.isPageProgressMode()) {
                        this.currentPageIndex = index;
                        this.reportReaderPageProgress();
                        // 同上：页码没有 @Watch，改完必须显式重绘画布，否则拖进度条屏幕停在旧页。
                        this.paintReaderCanvas();
                      } else if (mode === SliderChangeMode.End || mode === SliderChangeMode.Click) {
                        this.onSelectChapterIndex(index);
                      }
                    })
                  Row() {
                    Blank().layoutWeight(this.getProgressSliderThumbRatio())
                    Column().width(5).height(40).backgroundColor(this.readerMenuAccentTint()).borderRadius(2.5)
                    Blank().layoutWeight(1 - this.getProgressSliderThumbRatio())
                  }.width('100%').height(40).padding({ left: 10, right: 10 })
                    .hitTestBehavior(HitTestMode.Transparent)
                }.layoutWeight(1).height(40)
              }
              Stack({ alignContent: Alignment.Center }) {
                Image($r('app.media.reader_arrow_forward')).width(20).height(20).fillColor(this.readerMenuForeground())
              }.width(40).height(40).onClick(() => this.turnReaderChapter(1))
            }.width('100%').height(40).padding({ left: 8, right: 8 })
            if (this.getBottomActionPages().length > 0) {
            Swiper() {
              ForEach(this.getBottomActionPages(), (rows: ReaderControlKind[][], _pageIndex: number) => {
                Column() {
                  ForEach(rows, (row: ReaderControlKind[], _rowIndex: number) => {
                    Row() {
                      ForEach(row, (kind: ReaderControlKind) => {
                        ReaderBottomAction({
                          kind: kind,
                          label: this.getBottomActionLabel(kind),
                          showLabel: this.showBottomActionText,
                          badgeCount: this.getBottomActionBadgeCount(kind),
                          active: (kind === 'autoPage' && this.autoPageActive) ||
                            (kind === 'eye_protection' && this.eyeProtectionActive),
                          iconStyle: this.bottomIconStyle,
                          menuForeground: this.readerMenuForeground(),
                          menuAccent: this.readerMenuAccentTint(),
                          onSelect: () => this.selectBottomAction(kind),
                          onLongSelect: () => this.longSelectBottomAction(kind)
                        }).width(40)
                      }, (kind: ReaderControlKind) => kind)
                    }.width('100%').justifyContent(FlexAlign.SpaceBetween)
                  }, (_row: ReaderControlKind[], rowIndex: number) => `${_pageIndex}-${rowIndex}`)
                }.width('100%').justifyContent(FlexAlign.Center)
              }, (_rows: ReaderControlKind[][], pageIndex: number) => `${pageIndex}`)
            }
              .width('100%')
              .index(this.getBottomActionPageIndex())
              .height((this.showBottomActionText ? 64 : 48) * Math.max(1, Math.min(2, this.bottomRowCount)) + 21)
              .loop(false)
              .indicator(false)
              .onChange((pageIndex: number) => this.currentBottomActionPage = pageIndex)
              .padding({ left: 8, right: 8, top: 4, bottom: 17 })
            }
          }
            // 底栏容器几何全部参数化，对齐上游 `ReadBookMenuBar.kt:416-440`：
            // 悬浮时左右留边、底部留 16vp 且四角同圆；非悬浮时铺满宽度、底部不留白，只圆上两个角。
            .width(this.readMenuFloatingBottomBar ? '92%' : '100%')
            .alignSelf(ItemAlign.Center)
            .padding({ left: 8, right: 8, top: 12, bottom: 0 })
            .backgroundColor(this.readerBottomBarFillColor())
            .linearGradient(this.readerBottomBarGradient())
            // KI-E2：底栏同样吃边框与模糊半径，对齐上游 `ReadBookMenuBar.kt:450`（描边）
            // 与 `:1027`（`blurRadius = menuConfig.readMenuBlurRadius`）。
            .border(this.readerMenuBorderSettings())
            .backdropBlur(this.readerMenuBlurRadiusVp())
            .borderRadius({
              topLeft: this.readMenuBottomCornerRadius,
              topRight: this.readMenuBottomCornerRadius,
              bottomLeft: this.readMenuFloatingBottomBar ? this.readMenuBottomCornerRadius : 0,
              bottomRight: this.readMenuFloatingBottomBar ? this.readMenuBottomCornerRadius : 0
            })
            .margin({ bottom: this.readMenuFloatingBottomBar ? 16 : 0 })

        }
          .width('100%')
          .height('100%')
          .hitTestBehavior(HitTestMode.Transparent)

          // 竖排亮度条：上游 `ReadBookMenuBar.kt:205-270` 是一块独立 Surface，
          // `align(if (brightnessIsLeft) CenterStart else CenterEnd)`，靠边留 8dp，
          // 进出场按贴边方向横滑 + 淡入淡出。本地没有进出场动画，位置与贴边规则一致。
          if (this.showBrightnessView === '2') {
            Row() {
              Column() {
                this.ReaderBrightnessBar(true)
              }
              .backgroundColor(this.readerBottomBarFillColor())
              .borderRadius(this.readMenuBottomCornerRadius)
              .border(this.readerMenuBorderSettings())
              .backdropBlur(this.readerMenuBlurRadiusVp())
              .padding({ top: 12, bottom: 12 })
            }
            .width('100%').height('100%')
            .padding({ left: 8, right: 8 })
            .justifyContent(this.brightnessVwPos === '0' ? FlexAlign.Start : FlexAlign.End)
            .alignItems(VerticalAlign.Center)
            .hitTestBehavior(HitTestMode.Transparent)
          }
        }
        .width('100%')
        .height('100%')
      }

      // 搜索结果浮层：正文两侧的「上一个/下一个」+ 底部结果条。
      // 上游 `ReadBookSearchBar.kt:24-95`（箭头）与 `ReadBookMenuBarSearch.kt`
      // （底部 pill：当前/总数 + 百分比 + 竖分隔线 + 章名，下面一行三枚按钮 2:1:0.55）。
      if (this.searchResultOverlayVisible()) {
        Row() {
          if (this.searchNavIndex > 0) {
            Stack({ alignContent: Alignment.Center }) {
              Image($r('app.media.reader_back')).width(20).height(20).fillColor(this.readerMenuForeground())
            }
            .width(44).height(44).borderRadius(22)
            .backgroundColor(this.readerBottomBarFillColor())
            .border(this.readerMenuBorderSettings())
            .onClick(() => this.onOpenSearchNavItem(this.searchNavIndex - 1))
          }
          Blank().layoutWeight(1)
          if (this.searchNavIndex < this.searchNavItems.length - 1) {
            Stack({ alignContent: Alignment.Center }) {
              Image($r('app.media.reader_arrow_forward')).width(20).height(20).fillColor(this.readerMenuForeground())
            }
            .width(44).height(44).borderRadius(22)
            .backgroundColor(this.readerBottomBarFillColor())
            .border(this.readerMenuBorderSettings())
            .onClick(() => this.onOpenSearchNavItem(this.searchNavIndex + 1))
          }
        }
        .width('100%')
        .height('100%')
        .padding({ left: 16, right: 16 })
        .alignItems(VerticalAlign.Center)
        .hitTestBehavior(HitTestMode.Transparent)

        // 结果条贴屏幕底部（上游 SearchBottomMenuContent 在底栏位置），
        // 所以外面套一层满高 Column + Blank 把内容推到底，不能靠 alignSelf 居中。
        Column() {
          Blank().layoutWeight(1)
          Column() {
            // 信息 pill：上游高 40、圆角 16、surfaceContainerLow 底、横向内边距 12。
            Row() {
            Text((this.searchNavIndex + 1).toString() + ' / ' + this.searchNavItems.length.toString())
              .fontSize(13).fontColor(this.readerMenuForeground())
            Blank().width(8)
            Text(Math.round((this.searchNavIndex + 1) * 100 / this.searchNavItems.length).toString() + '%')
              .fontSize(11).fontColor(this.readerMenuAccentTint())
              .padding({ left: 6, right: 6, top: 2, bottom: 2 })
              .backgroundColor(this.readerMenuForegroundAlpha('1A')).borderRadius(8)
            Blank().width(16)
            Column().width(1).height(8).backgroundColor(this.readerMenuForegroundAlpha('33'))
            Blank().width(16)
            Text(this.currentSearchNavTitle())
              .fontSize(12).fontColor(this.readerMenuForeground()).maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis }).layoutWeight(1)
          }
          .width('100%').height(40).padding({ left: 12, right: 12 })
          .backgroundColor(this.readerBottomBarFillColor()).borderRadius(16)
          .border(this.readerMenuBorderSettings())

          // 三枚按钮：权重 2 : 1 : 0.55（上游 SearchBottomMenuContent）。
          Row({ space: 8 }) {
            Row({ space: 6 }) {
              Image($r('app.media.app_search')).width(16).height(16).fillColor(this.readerMenuForeground())
              Text('所有结果').fontSize(12).fontColor(this.readerMenuForeground()).maxLines(1)
            }
            .layoutWeight(2).height(40).justifyContent(FlexAlign.Center)
            .backgroundColor(this.readerBottomBarFillColor()).borderRadius(16)
            .border(this.readerMenuBorderSettings())
            .onClick(() => this.onOpenSearchContent())

            Row() {
              Image($r('app.media.app_more')).width(16).height(16).fillColor(this.readerMenuForeground())
            }
            .layoutWeight(1).height(40).justifyContent(FlexAlign.Center)
            .backgroundColor(this.readerBottomBarFillColor()).borderRadius(16)
            .border(this.readerMenuBorderSettings())
            .onClick(() => { this.controlsVisible = true; })

            Row() {
              AppGlyph({ name: 'profileClose', glyphSize: 16, tint: this.readerMenuForeground() })
            }
            .layoutWeight(0.55).height(40).justifyContent(FlexAlign.Center)
            .backgroundColor(this.readerBottomBarFillColor()).borderRadius(16)
            .border(this.readerMenuBorderSettings())
            .onClick(() => this.onCloseSearchResult())
          }
          .width('100%').margin({ top: 8 })
          }
          .width('88%')
          .alignSelf(ItemAlign.Center)
          .margin({ bottom: 24 })
        }
        .width('100%').height('100%')
        .alignItems(HorizontalAlign.Center)
        .hitTestBehavior(HitTestMode.Transparent)
      }

      if (this.readingAnchorAvailable && this.readingAnchorEnabled && !this.controlsVisible &&
        !this.imagePreviewVisible && !this.overflowVisible) {
        Stack({ alignContent: Alignment.Bottom }) {
          Row() {
            Row() {
              AppGlyph({ name: 'profileHistory', glyphSize: 18, tint: '#DDE1F0' }).margin({ right: 8 })
              Text('返回原阅读位置').fontSize(14).fontColor('#ECEEF4')
            }.layoutWeight(1).onClick(() => this.onRestoreReadingAnchor())
            Text('关闭').fontSize(13).fontColor('#BFC2CD').padding({ left: 12, right: 6 })
              .onClick(() => this.onKeepReadingAnchor())
          }
          .width('88%')
          .padding({ left: 16, right: 14, top: 12, bottom: 12 })
          .backgroundColor('#D92B2D35')
          .borderRadius(24)
          .margin({ bottom: 96 })
          .alignSelf(ItemAlign.Center)
        }
        .width('100%')
        .height('100%')
        .hitTestBehavior(HitTestMode.Transparent)
      }
      if (this.autoPageSettingsVisible) {
        Column() {
          Blank().layoutWeight(1)
          Column() {
            Row() {
              Text('自动翻页').fontSize(17).fontWeight(FontWeight.Medium).fontColor('#ECECF0')
              Blank()
              Text('×').fontSize(23).fontColor('#C8C9D0').onClick(() => this.autoPageSettingsVisible = false)
            }.width('100%').padding({ bottom: 18 })
            Row() {
              Text('翻页间隔').fontSize(14).fontColor(this.themeColorTextSecondary)
              Blank()
              Text(`${this.autoReadSpeedSeconds} 秒`).fontSize(14).fontColor(this.themeColorTextSecondary)
            }.width('100%')
            Slider({ value: this.autoReadSpeedSeconds, min: 1, max: 120, step: 1, style: SliderStyle.InSet })
              .width('100%').selectedColor('#B9C6FF').trackColor('#565A6B').blockColor('#B9C6FF')
              .onChange((value: number, mode: SliderChangeMode) => {
                if (mode === SliderChangeMode.Moving || mode === SliderChangeMode.Click || mode === SliderChangeMode.End) {
                  this.setAutoPageSpeed(value);
                }
              })
            Row() {
              Text('目录').fontSize(13).fontColor('#E2E3E8').textAlign(TextAlign.Center).layoutWeight(1)
                .onClick(() => { this.autoPageSettingsVisible = false; this.onOpenCatalog(); })
              Text('停止').fontSize(13).fontColor('#E2E3E8').textAlign(TextAlign.Center).layoutWeight(1)
                .onClick(() => { this.autoPageActive = false; this.autoPageSettingsVisible = false; this.stopAutoPageTimer(); })
              Text('翻页设置').fontSize(13).fontColor('#E2E3E8').textAlign(TextAlign.Center).layoutWeight(1)
                .onClick(() => { this.autoPageSettingsVisible = false; this.onOpenSettings(); })
            }.width('100%').padding({ top: 18, bottom: 10 })
          }.width('100%').padding({ left: 20, right: 20, top: 18, bottom: 22 })
            .backgroundColor('#D931282A').borderRadius({ topLeft: 24, topRight: 24 })
        }.width('100%').height('100%').backgroundColor('#66000000')
          .onClick(() => this.autoPageSettingsVisible = false)
      }

      if (this.controlsVisible && this.overflowVisible) {
        Stack({ alignContent: Alignment.Bottom }) {
          Column().width('100%').height('100%').backgroundColor('#88000000')
            .onClick(() => {
              this.overflowVisible = false;
              this.imageStyleMenuVisible = false;
            })
          Column() {
            Row().width(32).height(4).backgroundColor('#C5C6CD').borderRadius(4)
              .alignSelf(ItemAlign.Center).margin({ top: 10, bottom: 14 })
            Row() {
              BookCover({ book: this.book, mini: true }).margin({ right: 12 })
              Column() {
                Text(this.book.title).fontSize(14).fontWeight(FontWeight.Medium).fontColor('#E5E6EB')
                  .maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
                Text(this.displayChapterTitle).fontSize(11).fontColor('#B7B8C1').maxLines(1)
                  .margin({ top: 4 })
              }.layoutWeight(1).alignItems(HorizontalAlign.Start)
              Text(`${this.getChapterIndex() + 1} / ${this.getChapterCount()}`)
                .fontSize(11).fontColor('#E5E6EB').padding({ left: 10, right: 10, top: 7, bottom: 7 })
                .backgroundColor(this.themeAppBackground.length > 0 ? Color.Transparent : (this.themePureBlack ? '#000000' : this.themeColorSurfacePrimary)).borderRadius(16)
            }.width('100%').padding({ left: 16, right: 16, bottom: 14 })
            // 上游 ReaderMoreActionsSheet.kt:314-416：4 列正方形格子，每页 chunked(8) 分页。
            Swiper() {
              ForEach(this.getMoreActionPages(), (page: ReaderMoreAction[], pageIndex: number) => {
                Grid() {
                  ForEach(page, (action: ReaderMoreAction) => {
                    GridItem() {
                      Column() {
                        if (this.showMenuIcon) {
                          AppGlyph({ name: action.glyph,
                            tint: action.id === 're_segment' && this.book.reSegment === true ? this.readerMenuAccentTint() : this.readerMenuForeground(),
                            glyphSize: 22 }).margin({ bottom: 8 })
                        }
                        Text(action.id === 're_segment' && this.book.reSegment === true
                          ? '重新分段（已启用）' : action.label)
                          .fontSize(11).fontColor('#E1DADD').textAlign(TextAlign.Center)
                          .maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
                        if (!action.migrated) {
                          Text('未迁移').fontSize(9).fontColor(this.themeColorTextTertiary).margin({ top: 2 })
                        }
                        // 上游 ReaderMenuActionSquare.kt:72-84：格子底部 16dp 点击带 + 12dp 展开箭头，
                        // 只有需要二次选择的条目才有（换源 / 刷新 / 自定义按钮）。
                        if (this.moreActionHasSubmenu(action.id)) {
                          Row() {
                            AppGlyph({ name: 'profileExpandMore', tint: this.readerMenuForeground(), glyphSize: 12 })
                          }.width('100%').height(16).justifyContent(FlexAlign.Center)
                        }
                      }.width('100%').aspectRatio(1).justifyContent(FlexAlign.Center)
                        .backgroundColor('#202127').borderRadius(16)
                        .onClick(() => this.selectMoreAction(action))
                    }
                  }, (action: ReaderMoreAction) => action.id)
                }.columnsTemplate('1fr 1fr 1fr 1fr').rowsGap(8).columnsGap(8).width('100%')
              }, (page: ReaderMoreAction[], pageIndex: number) => `page-${pageIndex}`)
            }.loop(false).indicator(false)
              .onChange((index: number) => this.moreActionPage = index)
              .width('100%').layoutWeight(1)
            Row() {
              ForEach(this.getMoreActionPages(), (page: ReaderMoreAction[], pageIndex: number) => {
                Row().width(6).height(6).borderRadius(3).margin({ right: 5 })
                  .backgroundColor(pageIndex === this.moreActionPage ? '#E5E6EB' : '#5A5C66')
              }, (page: ReaderMoreAction[], pageIndex: number) => `dot-${pageIndex}`)
            }.width('100%').justifyContent(FlexAlign.Center).padding({ bottom: 12 })
          }
          .width('100%').height('52%').backgroundColor(this.themeColorSurfaceSecondary)
          .borderRadius({ topLeft: 26, topRight: 26 })
        }
        .width('100%')
        .height('100%')
      }

      if (this.imageStyleMenuVisible) {
        Stack({ alignContent: Alignment.Center }) {
          Column().width('100%').height('100%').backgroundColor('#88000000')
            .onClick(() => this.imageStyleMenuVisible = false)
          Column() {
            Row() {
              Text('图片样式').fontSize(17).fontWeight(FontWeight.Medium).fontColor('#E5E6EB')
              Blank()
              Text('关闭').fontSize(13).fontColor('#C7C9D1').onClick(() => this.imageStyleMenuVisible = false)
            }.width('100%').padding({ bottom: 12 })
            ForEach(READER_IMAGE_STYLE_OPTIONS, (style: ReaderImageStyleOption) => {
              Row() {
                Text(style.label).fontSize(14).fontColor('#E5E6EB').layoutWeight(1)
                if (this.activeImageStyle === style.id) {
                  AppGlyph({ name: 'profileCheck', glyphSize: 18, tint: '#B9C6FF' })
                }
              }.width('100%').padding({ left: 12, right: 12, top: 12, bottom: 12 })
                .backgroundColor('#202127').borderRadius(12).margin({ bottom: 6 })
                .onClick(() => this.chooseImageStyle(style.id))
            }, (style: ReaderImageStyleOption) => style.id)
          }.width('86%').padding(16).backgroundColor(this.themeColorSurfaceSecondary).borderRadius(20)
        }.width('100%').height('100%')
      }

      if (this.pageAnimMenuVisible) {
        Stack({ alignContent: Alignment.Center }) {
          Column().width('100%').height('100%').backgroundColor('#88000000')
            .onClick(() => this.pageAnimMenuVisible = false)
          Column() {
            Row() {
              Text('翻页动画').fontSize(17).fontWeight(FontWeight.Medium).fontColor('#E5E6EB')
              Blank()
              Text('关闭').fontSize(13).fontColor('#C7C9D1')
                .onClick(() => this.pageAnimMenuVisible = false)
            }.width('100%').padding({ bottom: 12 })
            ForEach(READER_PAGE_ANIMATION_LABELS, (label: string, index: number) => {
              Row() {
                Text(label).fontSize(14).fontColor('#E5E6EB').layoutWeight(1)
                if (this.pageAnimation === index) {
                  AppGlyph({ name: 'profileCheck', glyphSize: 18, tint: '#B9C6FF' })
                }
              }.width('100%').padding({ left: 12, right: 12, top: 12, bottom: 12 })
                .backgroundColor('#202127').borderRadius(12).margin({ bottom: 6 })
                .onClick(() => {
                  this.onPageAnimationChange(index);
                  this.pageAnimMenuVisible = false;
                })
            }, (label: string) => label)
          }.width('86%').padding(16).backgroundColor(this.themeColorSurfaceSecondary).borderRadius(20)
        }.width('100%').height('100%')
      }

      if (this.moreActionConfigVisible) {
        this.moreActionConfigurationSheet()
      }

      if (this.moreActionShellVisible) {
        this.moreActionUnavailableSheet()
      }

      if (this.contentEditVisible) {
        Stack({ alignContent: Alignment.Center }) {
          Column().width('100%').height('100%').backgroundColor('#99000000')
            .onClick(() => this.contentEditVisible = false)
          Column() {
            Row() {
              Text('编辑内容').fontSize(18).fontWeight(FontWeight.Medium).fontColor('#ECEEF2')
              Blank()
              Text('取消').fontSize(14).fontColor('#C8C9D0').onClick(() => this.contentEditVisible = false)
            }.width('100%').padding({ bottom: 14 })
            // 「仅正文」开关：把 <img>/<usehtml>/[newpage] 折叠成〔图片1〕这类占位，
            // 对齐上游 ReadContentEditDelegate 的 bodyOnly 开关（ReaderBodyOnlyFilter）。
            Row() {
              Column() {
                Text('仅正文').fontSize(14).fontColor('#ECEEF2')
                Text('折叠图片、富文本与分页标记，避免误删源码')
                  .fontSize(11).fontColor('#9A9CA6').margin({ top: 2 })
              }.alignItems(HorizontalAlign.Start).layoutWeight(1)
              Toggle({ type: ToggleType.Switch, isOn: this.contentEditBodyOnly })
                .selectedColor('#B9C6FF')
                .onChange((isOn: boolean) => this.setContentEditBodyOnly(isOn))
            }
            .width('100%').padding({ top: 4, bottom: 10 })
            TextInput({ text: this.contentEditTitle, placeholder: '章节名称' })
              .width('100%').height(48).fontSize(15).fontColor('#ECEEF2')
              .backgroundColor('#292A31').borderRadius(10).padding({ left: 12, right: 12 })
              .onChange((value: string) => this.contentEditTitle = value)
            TextArea({ text: this.contentEditBody, placeholder: '章节正文' })
              .width('100%').layoutWeight(1).margin({ top: 10 })
              .fontSize(15).fontColor('#ECEEF2').backgroundColor('#292A31')
              .borderRadius(10).padding(12)
              .onChange((value: string) => this.contentEditBody = value)
            Row() {
              Text('还原').fontSize(14).fontColor(this.themeColorTextSecondary).layoutWeight(1).textAlign(TextAlign.Center)
                .onClick(() => {
                  // 还原也回到「折叠态」：与刚打开弹层时看到的一致，
                  // 用户点还原后再关掉「仅正文」仍能拿回完整正文。
                  this.contentEditTitle = this.chapterTitle;
                  this.contentEditBody = this.contentEditBodyOnly
                    ? toBodyOnly(this.content, this.contentEditHiddenSpans) : this.content;
                })
              Text('保存').fontSize(14).fontColor('#101116').textAlign(TextAlign.Center)
                .width(84).padding({ top: 10, bottom: 10 }).backgroundColor('#B9C6FF').borderRadius(18)
                .onClick(() => {
                  const currentPage = this.localReaderPages[this.currentPageIndex];
                  this.pendingBookmarkTargetPosition = currentPage?.startPosition ?? 0;
                  // 折叠态保存：按占位标记把原始片段插回，图片/富文本/分页标记不会丢。
                  const savedBody = this.contentEditBodyOnly
                    ? toRawText(this.contentEditBody, this.contentEditHiddenSpans) : this.contentEditBody;
                  this.onSaveChapterContent(this.getChapterIndex(), this.contentEditTitle, savedBody);
                  this.contentEditVisible = false;
                })
            }.width('100%').padding({ top: 14 })
          }
          .width('92%').height('76%').padding(18).backgroundColor(this.themeColorSurfaceSecondary).borderRadius(22)
          .onClick(() => {})
        }.width('100%').height('100%')
      }

      if (this.textProcessingVisible) {
        ReaderTextProcessingSheet({
          book: this.book,
          chapterTitle: this.displayChapterTitle,
          replaceEnabled: this.replaceEnabled,
          replaceUsesDefault: this.replaceUsesDefault,
          rules: this.replaceRules,
          contentProcesses: this.contentProcesses,
          effectiveRuleIds: this.effectiveReplaceRuleIds,
          onReplaceEnabledChange: (enabled: boolean) => this.onReplaceEnabledChange(enabled),
          onReplaceResetToDefault: () => this.onReplaceResetToDefault(),
          onRuleEnabledChange: (id: number, enabled: boolean) => this.onRuleEnabledChange(id, enabled),
          onRuleReorder: (orderedIds: number[]) => this.onRuleReorder(orderedIds),
          onContentProcessToggle: (id: string, enabled: boolean) => this.onContentProcessToggle(id, enabled),
          onContentProcessDelete: (id: string) => this.onContentProcessDelete(id),
          onClose: () => this.textProcessingVisible = false,
          onOpenReplaceRules: () => this.onOpenReplaceRules(),
          onUnavailableAction: (message: string) => this.onUnavailableAction(message)
        })
      }

      if (this.charsetDialogVisible) {
        Stack({ alignContent: Alignment.Center }) {
          Column().width('100%').height('100%').backgroundColor('#99000000')
            .onClick(() => {
              this.charsetDialogVisible = false;
              this.charsetOptionsExpanded = false;
            })
          Column() {
            Text('设置编码').fontSize(18).fontWeight(FontWeight.Medium).fontColor('#ECEEF2')
              .width('100%').margin({ bottom: 16 })
            Row() {
              TextInput({ text: this.charsetInput, placeholder: '输入或选择字符集' })
                .layoutWeight(1).height(48).fontSize(14).fontColor('#ECEEF2')
                .backgroundColor('#292A31').borderRadius(10).padding({ left: 12, right: 12 })
                .onChange((value: string) => this.charsetInput = value)
              Text(this.charsetOptionsExpanded ? '⌃' : '⌄').fontSize(22).fontColor('#D9DAE0')
                .width(38).height(48).textAlign(TextAlign.Center)
                .onClick(() => this.charsetOptionsExpanded = !this.charsetOptionsExpanded)
            }.width('100%')
            if (this.charsetOptionsExpanded) {
              Scroll() {
                Column() {
                  ForEach(READER_CHARSETS, (charset: string) => {
                    Row() {
                      Text(charset).fontSize(14).fontColor('#E1E2E7').layoutWeight(1)
                      if (this.charsetInput.trim().toLowerCase() === charset.toLowerCase()) {
                        Text('✓').fontSize(14).fontColor('#C5D0FF')
                      }
                    }.width('100%').padding({ left: 12, right: 12, top: 10, bottom: 10 })
                      .onClick(() => {
                        this.charsetInput = charset;
                        this.charsetOptionsExpanded = false;
                      })
                  }, (charset: string) => charset)
                }.width('100%')
              }.width('100%').height(220).margin({ top: 8 })
                .scrollBar(BarState.Off)
            }
            Row() {
              Blank().layoutWeight(1)
              Text('取消').fontSize(14).fontColor('#B9BBC4').padding({ left: 14, right: 14, top: 10, bottom: 10 })
                .onClick(() => {
                  this.charsetDialogVisible = false;
                  this.charsetOptionsExpanded = false;
                })
              Text('确定').fontSize(14).fontColor('#C5D0FF').padding({ left: 14, right: 14, top: 10, bottom: 10 })
                .onClick(() => this.applyCharset())
            }.width('100%').margin({ top: 12 })
          }
          .width('86%').padding(18).backgroundColor(this.themeAppBackground.length > 0 ? Color.Transparent : (this.themePureBlack ? '#121212' : this.themeColorSurfaceElevated)).borderRadius(20)
        }
        .width('100%').height('100%')
      }

      if (this.highlightRuleSheetVisible) {
        ReaderHighlightRuleSheet({
          rules: this.readerHighlightRules,
          chapterLength: this.localSemanticContent.length,
          onDismiss: () => this.highlightRuleSheetVisible = false,
          onSave: (rules: ReaderHighlightRule[]): Promise<ReaderHighlightRule[]> => this.saveReaderHighlightRules(rules)
        })
      }

      if (this.imagePreviewVisible) {
        Column() {
          Row() {
            Text('图片预览').fontSize(16).fontColor('#ECEEF2').layoutWeight(1)
            Image($r('app.media.profile_close')).width(22).height(22).fillColor('#ECEEF2')
              .padding(8).onClick(() => this.closeReaderImagePreview())
          }.width('100%').height(48).padding({ left: 16, right: 16 })
          Image(this.imagePreviewUri)
            .width('100%').layoutWeight(1).objectFit(ImageFit.Contain)
            .onClick(() => {})
        }
        .width('100%').height('100%')
        .padding({ top: 28, bottom: 20 })
        .backgroundColor('#FF000000')
        .onClick(() => {})
        .zIndex(1000)
      }

      // 环境光日夜提醒：贴底居中、底距 88vp，与上游 ReadBookFloatingActionBar 一致；
      // 阅读菜单展开时不显示（上游 `takeIf { !state.menuVisible }`）。
      if (this.dayNightReminderText.length > 0 && !this.controlsVisible) {
        Column() {
          Blank()
          Row() {
            this.ReaderDayNightReminderCapsule()
          }
          .width('100%')
          .justifyContent(FlexAlign.Center)
          .padding({ bottom: 88 })
        }
        .width('100%')
        .height('100%')
        // None：这层全屏容器自身不响应，子节点（胶囊两个按钮）照常响应。
        // 之前用 Default 会把整屏都拦住——提醒弹出的 5 秒里用户连菜单都唤不出来。
        .hitTestBehavior(HitTestMode.None)
        .zIndex(900)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.paperColor)
    .onTouch((event: TouchEvent) => {
      if (event.type === TouchType.Down) { this.renewKeepLightTimeout(); }
    })
    .focusable(true)
    // 鼠标滚轮翻页：仅分页模式接管，滚动模式本来就靠滚轮滚动（对齐上游
    // ReadBookController.kt:2845 的 mouseWheelPage，那里也是翻页而非滚动）。
    .onAxisEvent((event: AxisEvent) => {
      // 滚动模式也接管滚轮（上游 tapScrollPage 与滚轮走同一条步距策略）
      if (!this.mouseWheelPage || this.controlsVisible) { return; }
      if (event.action !== AxisAction.UPDATE) { return; }
      const vertical = event.axisVertical ?? 0;
      if (Math.abs(vertical) < 0.5) { return; }
      this.turnReaderPage(vertical > 0 ? 1 : -1);
    })
    // 自定义翻页按键的兜底入口：inputConsumer 只能抢占音量键与媒体键（API 21+），
    // 其余键靠这里冒泡接收，对齐上游 ReadBookController.kt:2699 的 onKeyDown。
    .onKeyEvent((event) => {
      if (event.type !== KeyType.Down || this.controlsVisible || !this.readerWindowActive) { return; }
      const mapped = this.matchPageKey(event.keyCode);
      if (mapped !== 0) {
        this.turnReaderPage(mapped);
        event.stopPropagation();
      }
    })
  }
}

@Component
struct ReaderControl {
  @Prop kind: ReaderControlKind = 'catalog';
  @Prop active: boolean = false;
  /** 菜单前景色（文字与图标），由 ReaderPage 按菜单配色折算后传入。 */
  @Prop menuForeground: string = '#D5C2C6';
  /** 菜单强调色（选中态），由 ReaderPage 按菜单配色折算后传入。 */
  @Prop menuAccent: string = '#FFB1C8';
  onSelect: () => void = () => {};
  onLongSelect: () => void = () => {};

  build() {
    Stack({ alignContent: Alignment.Center }) {
      ReaderControlGlyph({ kind: this.kind, glyphSize: 19, active: this.active, menuForeground: this.menuForeground, menuAccent: this.menuAccent })
    }.width(36).height(36).backgroundColor(this.active ? '#454B62' : '#303139').borderRadius(20)
      .parallelGesture(LongPressGesture({ duration: 500 }).onAction((_event: GestureEvent): void => { this.onLongSelect(); }))
      .onClick(() => this.onSelect())
  }
}

@Component
struct ReaderBottomAction {
  @Prop kind: ReaderControlKind = 'catalog';
  @Prop label: string = '';
  @Prop showLabel: boolean = true;
  @Prop active: boolean = false;
  @Prop iconStyle: number = 1;
  /** 右上角红色数字角标；0 不显示。上游 `ReadBookMenuBarTool.kt:337`/`:410-431`。 */
  @Prop badgeCount: number = 0;
  /** 菜单前景色（文字与图标），由 ReaderPage 按菜单配色折算后传入。 */
  @Prop menuForeground: string = '#D5C2C6';
  /** 菜单强调色（选中态），由 ReaderPage 按菜单配色折算后传入。 */
  @Prop menuAccent: string = '#FFB1C8';
  onSelect: () => void = () => {};
  onLongSelect: () => void = () => {};

  build() {
    Column() {
      Stack({ alignContent: Alignment.Center }) {
        ReaderControlGlyph({ kind: this.kind, glyphSize: 20, active: this.active, menuForeground: this.menuForeground, menuAccent: this.menuAccent })
        // 角标贴图标右上角，红色圆角底、白字；上游 `ReadBookMenuBarTool.kt:410-431`
        // 用 `Alignment.TopEnd` + `RoundedCornerShape(8.dp)` + `padding(horizontal 4, vertical 1)`。
        if (this.badgeCount > 0) {
          Text(`${this.badgeCount}`)
            .fontSize(9).fontColor('#FFFFFF')
            .backgroundColor('#B3261E').borderRadius(8)
            .padding({ left: 4, right: 4, top: 1, bottom: 1 })
            .align(Alignment.TopEnd)
        }
      }.width(40).height(40)
        .backgroundColor(this.active ? '#454B62' : (this.iconStyle === 1 ? '#292A31' : '#00000000'))
        .border({ width: this.iconStyle === 2 ? 1 : 0, color: '#8B8E98' })
        .borderRadius(20)
      if (this.showLabel) {
        Text(this.label).fontSize(9).fontColor('#E1E2E7').margin({ top: 3 })
      }
    }.layoutWeight(1).padding({ top: 3, bottom: 3 })
      .parallelGesture(LongPressGesture({ duration: 500 }).onAction((_event: GestureEvent): void => { this.onLongSelect(); }))
      .onClick(() => this.onSelect())
  }
}

@Component
struct ReaderControlGlyph {
  @Prop kind: ReaderControlKind = 'catalog';
  @Prop glyphSize: number = 20;
  @Prop active: boolean = false;
  /** 菜单前景色（文字与图标），由 ReaderPage 按菜单配色折算后传入。 */
  @Prop menuForeground: string = '#D5C2C6';
  /** 菜单强调色（选中态），由 ReaderPage 按菜单配色折算后传入。 */
  @Prop menuAccent: string = '#FFB1C8';

  build() {
    if (this.kind === 'search') {
      Image($r('app.media.reader_search')).width(this.glyphSize).height(this.glyphSize).fillColor(this.active ? this.menuAccent : this.menuForeground)
    } else if (this.kind === 'catalog') {
      Image($r('app.media.reader_toc')).width(this.glyphSize).height(this.glyphSize).fillColor(this.active ? this.menuAccent : this.menuForeground)
    } else if (this.kind === 'settings') {
      Image($r('app.media.reader_settings')).width(this.glyphSize).height(this.glyphSize).fillColor(this.active ? this.menuAccent : this.menuForeground)
    } else if (this.kind === 'autoPage') {
      Image(this.active ? $r('app.media.reader_pause') : $r('app.media.reader_play'))
        .width(this.glyphSize).height(this.glyphSize).fillColor(this.active ? this.menuAccent : this.menuForeground)
    } else if (this.kind === 'addBookmark') {
      Image($r('app.media.app_bookmark')).width(this.glyphSize).height(this.glyphSize).fillColor(this.menuForeground)
    } else if (this.kind === 'theme') {
      Image($r('app.media.app_daynight')).width(this.glyphSize).height(this.glyphSize).fillColor(this.menuForeground)
    } else if (this.kind === 'prev_chapter') {
      Image($r('app.media.app_previous')).width(this.glyphSize).height(this.glyphSize).fillColor(this.menuForeground)
    } else if (this.kind === 'next_chapter') {
      Image($r('app.media.reader_arrow_forward')).width(this.glyphSize).height(this.glyphSize).fillColor(this.menuForeground)
    } else if (this.kind === 'replace' || this.kind === 'replace_badge') {
      Image($r('app.media.profile_find_replace')).width(this.glyphSize).height(this.glyphSize).fillColor(this.menuForeground)
    } else if (this.kind === 'charset' || this.kind === 'translate') {
      Image($r('app.media.reader_translate')).width(this.glyphSize).height(this.glyphSize).fillColor(this.menuForeground)
    } else if (this.kind === 'more_actions' || this.kind === 'source_custom_button') {
      Image($r('app.media.reader_more')).width(this.glyphSize).height(this.glyphSize).fillColor(this.menuForeground)
    } else if (this.kind === 'download' || this.kind === 'audio_download') {
      Image($r('app.media.app_download')).width(this.glyphSize).height(this.glyphSize).fillColor(this.menuForeground)
    } else if (this.kind === 'refresh' || this.kind === 'refresh_current') {
      Image($r('app.media.app_refresh')).width(this.glyphSize).height(this.glyphSize).fillColor(this.menuForeground)
    } else if (this.kind === 'change_source') {
      Image($r('app.media.app_swap')).width(this.glyphSize).height(this.glyphSize).fillColor(this.menuForeground)
    } else if (this.kind === 'toc_rule') {
      Image($r('app.media.profile_rule')).width(this.glyphSize).height(this.glyphSize).fillColor(this.menuForeground)
    } else if (this.kind === 'ai_summary' || this.kind === 'ai_cast') {
      Image($r('app.media.profile_auto_awesome')).width(this.glyphSize).height(this.glyphSize).fillColor(this.menuForeground)
    } else if (this.kind === 'ai_rewrite') {
      Image($r('app.media.app_edit')).width(this.glyphSize).height(this.glyphSize).fillColor(this.menuForeground)
    } else if (this.kind === 'multi_role_read' || this.kind === 'multi_role_cast') {
      Image($r('app.media.app_group')).width(this.glyphSize).height(this.glyphSize).fillColor(this.menuForeground)
    } else if (this.kind === 'cast_table') {
      Image($r('app.media.app_list')).width(this.glyphSize).height(this.glyphSize).fillColor(this.menuForeground)
    } else if (this.kind === 'eye_protection') {
      Image($r('app.media.app_visibility')).width(this.glyphSize).height(this.glyphSize).fillColor(this.menuForeground)
    } else {
      Image($r('app.media.reader_voice')).width(this.glyphSize).height(this.glyphSize).fillColor(this.active ? this.menuAccent : this.menuForeground)
    }
  }
}




