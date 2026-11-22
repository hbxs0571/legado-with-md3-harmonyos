// 批 4：M3 派生色位（移植自 material-color-utilities，Apache-2.0）；菜单底色按种子色派生
import { resolveDynamicColor, normalizePaletteStyle, M3PaletteStyle, M3ColorSlot } from '../reader/m3/index';
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
// 批5（:127）：快速标记面板要复用「上次样式」的解析（encodeStyle/decodeStyle 同一份口径）
import { ReaderMarkingRepository } from '../data/ReaderMarkingRepository';
import { BookContentProcess } from '../model/BookContentProcess';
// 批5（:123）：标记渲染前的锚点重定位复用内容处理引擎的 findTargetRange
import { BookContentProcessEngine } from '../data/BookContentProcessEngine';
import { ReaderFontRepository } from '../data/ReaderFontRepository';
import { LocalSemanticDocument, LocalTextSemantics } from '../data/LocalTextSemantics';
// 批 11：EPUB 行内样式区间类型（sidecar 反序列化结果）
import { EpubInlineStyleRange } from '../data/EpubRepository';
import { ReaderTitleSegment, segmentReaderTitle } from '../data/ReaderTitleSegmentation';
import { READER_SELECTION_MENU_SUPPORTED, ReaderSelectionMenuItem, parseReaderSelectionMenuConfig } from '../data/ReaderSelectionMenu';
import { readerColumnCount } from '../data/ReaderColumnMode';
import { AppGlyph, AppGlyphName } from '../components/AppGlyph';
import { UiSwitchControl } from '../components/UiSwitchControl';
import { BookCover } from '../components/BookCover';
import { ReaderTextProcessingSheet } from './ReaderTextProcessingSheet';
import { ReaderSheetShell } from '../components/ReaderSheetShell';
// 批5（:127）：划词「划线/笔记」改成贴选区的行内快速标记面板
import { ReaderQuickMarkPanel } from '../components/ReaderQuickMarkPanel';
import image from '@ohos.multimedia.image';
import { fileIo } from '@kit.CoreFileKit';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { batteryInfo, pasteboard, settings } from '@kit.BasicServicesKit';
import { common, Want } from '@kit.AbilityKit';
import { WantLauncher } from '../lib/WantLauncher';
import { AppLog } from '../lib/AppLog';
import { AnimatorResult, window } from '@kit.ArkUI';
import { LengthMetricsUnit } from '@kit.ArkUI';
import { Action, inputConsumer, KeyCode, KeyEvent } from '@kit.InputKit';
import {
  LocalReaderLine, LocalReaderLineItem, LocalReaderPage, LocalReaderPaginator, LocalReaderSizeOffset,
  LocalReaderTitleBlock, LocalReaderTitleSegment
} from './LocalReaderPaginator';
import { ReadAloudSpan, EMPTY_READ_ALOUD_SPAN } from '../readaloud/SystemTtsPlayer';
import {
  ReadAloudSettingsRepository, ReadAloudSettingsSnapshot,
  DEFAULT_READ_ALOUD_SETTINGS, copyReadAloudSettings
} from '../data/ReadAloudSettingsRepository';
import { ReaderTextLayoutStyle } from '../reader/ReaderTextLayoutEngine';
import { ReaderChapterPageCache } from '../reader/ReaderChapterPageCache';
// 页身份与跨章页表定位的纯函数（页层批次 3 建、批次 4 补全）。
import {
  ReaderChapterPagePosition, canTurnNext, canTurnPrevious, chapterPosition,
  locateChapterPage, locateOrNull, rebasePageIndex
} from '../reader/ReaderPageIdentity';
import { ReaderCurlTouchPolicy } from '../reader/ReaderPageCurl';
import { HiddenSpan, scanHiddenSpans, toBodyOnly, toRawText } from '../reader/ReaderBodyOnlyFilter';
import {
  readerCanvasArgb, readerCanvasHandleDistance, readerCanvasHighlightDecoration,
  readerCanvasMarkingBackgroundArgb, readerCanvasMarkingDecoration, readerLengthToNumber,
  readerTextGlyphCount,
} from '../reader/ReaderCanvasStyleCodec';
import {
  ReaderCanvasDecorationRow, ReaderCanvasDecorationTip,
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
import { BODY_LARGE, BODY_MEDIUM, BODY_SMALL, HEADLINE_MEDIUM, HEADLINE_SMALL, LABEL_LARGE, LABEL_LARGE_EMPHASIZED, LABEL_MEDIUM, LABEL_SMALL, TITLE_LARGE, TITLE_MEDIUM, TITLE_SMALL, TITLE_SMALL_EMPHASIZED } from '../components/typography/TypographyTokens';

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
  { id: 'source_custom_button', label: '自定义按钮', glyph: 'profileSource', scopeLabel: '仅在线书籍', migrated: false },
  // 上游 MoreActionIds（ReadBookContract.kt:545-552）第 2-5 位：书源四项。
  // 本地 book.isLocal 恒 true、书源引擎未接（见 isMoreActionApplicable），
  // 所以它们只出现在配置面板里、带「未迁移」，永远不会成为格子。
  { id: 'source_login', label: '登录', glyph: 'profileWeb', scopeLabel: '仅在线书籍', migrated: false },
  { id: 'source_pay', label: '购买', glyph: 'profileSell', scopeLabel: '仅在线书籍', migrated: false },
  { id: 'edit_source', label: '编辑源', glyph: 'edit', scopeLabel: '仅在线书籍', migrated: false },
  { id: 'disable_source', label: '禁用源', glyph: 'lock', scopeLabel: '仅在线书籍', migrated: false },
  { id: 'change_source', label: '换源', glyph: 'swap', scopeLabel: '仅在线书籍', migrated: false },
  { id: 'refresh', label: '刷新章节', glyph: 'profileRefresh', scopeLabel: '仅在线书籍', migrated: false },
  { id: 'download', label: '离线缓存', glyph: 'cloudDownload', scopeLabel: '仅在线书籍', migrated: false },
  { id: 'audio_download', label: '听书下载', glyph: 'download', scopeLabel: '', migrated: false },
  // 上游 MoreActionIds 第 10 位 ai_chat。AI 在范围之外（见 docs/PROJECT.md），只入池不实现。
  { id: 'ai_chat', label: 'AI 对话', glyph: 'sparkles', scopeLabel: '', migrated: false },
  { id: 'edit_content', label: '编辑内容', glyph: 'edit', scopeLabel: '', migrated: true },
  { id: 'add_bookmark', label: '添加书签', glyph: 'bookmark', scopeLabel: '', migrated: true },
  { id: 'text_processing', label: '文本处理', glyph: 'profileFindReplace', scopeLabel: '', migrated: true },
  { id: 'reverse_content', label: '反转内容', glyph: 'swap', scopeLabel: '', migrated: true },
  { id: 're_segment', label: '重新分段', glyph: 'list', scopeLabel: '', migrated: true },
  { id: 'del_ruby', label: '删除ruby标签', glyph: 'delete', scopeLabel: '', migrated: true },
  { id: 'del_h', label: '删除h标签', glyph: 'delete', scopeLabel: '', migrated: true },
  { id: 'toc_rule', label: 'TXT 目录规则', glyph: 'profileRule', scopeLabel: '', migrated: true },
  { id: 'charset', label: '设置编码', glyph: 'info', scopeLabel: '', migrated: true },
  { id: 'image_style', label: '图片样式', glyph: 'book', scopeLabel: '', migrated: true },
  { id: 'page_anim', label: '本书翻页动画', glyph: 'profileSettings', scopeLabel: '', migrated: false },
  { id: 'simulated_reading', label: '模拟追读', glyph: 'book', scopeLabel: '', migrated: true },
  { id: 'get_progress', label: '拉取云端进度', glyph: 'profileHistory', scopeLabel: '', migrated: false },
  { id: 'cover_progress', label: '覆盖云端进度', glyph: 'profileHistory', scopeLabel: '', migrated: false },
  { id: 'highlight_rule', label: '高亮规则', glyph: 'profileRule', scopeLabel: '', migrated: true },
  { id: 'read_style', label: '阅读界面', glyph: 'profileSettings', scopeLabel: '', migrated: true },
  { id: 'bottom_button_config', label: '配置底部按钮', glyph: 'profileSettings', scopeLabel: '', migrated: true },
  { id: 'log', label: '日志', glyph: 'info', scopeLabel: '', migrated: false }
];
const MORE_ACTION_CONFIG_ENTRY: ReaderMoreAction = {
  id: 'configure_more_actions', label: '配置更多菜单', glyph: 'settings', scopeLabel: '', migrated: true
};
// 翻页动画六档，顺序与上游 GlobalThemePage.kt:353-360 的 cover/slide/simulation/scroll/fade/none 一致。
const READER_PAGE_ANIMATION_LABELS: string[] = ['覆盖', '滑动', '仿真', '滚动', '淡入淡出', '无动画'];
/** 大图预览缩放上限，对齐上游 PhotoView.kt:38 MAX_SCALE = 2.5f。 */
const IMAGE_PREVIEW_MAX_SCALE: number = 2.5;
/** 翻页动画「默认」档（上游 R.string.btn_default_s → -1），选中即回落全局设置。 */
const READER_PAGE_ANIM_DEFAULT: number = -1;
const READER_CHARSETS: string[] = ['UTF-8', 'GB2312', 'GB18030', 'GBK', 'Unicode', 'UTF-16', 'UTF-16LE', 'UTF-16BE', 'ASCII'];

/**
 * Slider 拇指行程两端的内缩（vp）。2026-11-20 在 1280x2832、密度 3.5 的模拟器上实测：
 * 把系统圆点拇指临时涂成 `#FF00FF` 后按像素量它的真实边界中点（涂透明时量不到，
 * 早先只能靠「选中色段端点」间接推，端点被刻度点覆盖，误差大）。
 * Slider bounds X0=341px/X1=939px（W=598px=170.86vp），max=14；
 * 注入点击后读回的 v 与拇指中点：v=0 -> 389.50px，v=14 -> 889.00px。
 * A1=(389.50-341)/3.5=13.857vp，A2=(939-889.00)/3.5=14.286vp，均值 14.071 -> 取 14.07。
 * 复核：travel=170.86-2*14.07=142.72vp=499.5px，与实测 889.00-389.50=499.5px 吻合。
 * 对照实验：把本组件外层 padding 从 5vp 改成 18vp 各构建一次，两端内缩逐像素相同
 * （48.5px / 50.0px），说明该内缩是 Slider 相对自身 bounds 的固定量，与 padding 无关；
 * 早先注释把 6vp + 5vp 当成它的来源是错的，此处按实测取值。
 */
const SLIDER_THUMB_TRAVEL_INSET: number = 14.07;

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
  /**
   * 邻章预读请求的在途超时。超过这个时间还没拿到邻章正文，就允许重新请求。
   *
   * 宿主侧对同一章有「在途 / 已下发」两道去重，但对「这一章刚刚变成正文」
   * 这类情况会静默不回应；阅读页若把「已请求」当永久状态，邻章就再也排不出来，
   * 章末只能滚进空白承接页。1.5 秒足够覆盖一次正常的读盘 + 排版往返。
   */
  private static readonly ADJACENT_REQUEST_TIMEOUT_MS: number = 1500;
  @StorageProp('themeColorTextPrimary') themeColorTextPrimary: string = '#1B1C22';
  @StorageProp('themeColorTextSecondary') themeColorTextSecondary: string = '#2E3038';
  @StorageProp('themeColorTextTertiary') themeColorTextTertiary: string = '#6A6D77';
  @StorageProp('themeColorSurfacePrimary') themeColorSurfacePrimary: string = '#F5F6F8';
  @StorageProp('themeColorSurfaceSecondary') themeColorSurfaceSecondary: string = '#FFFFFF';
  @StorageProp('themeColorSurfaceElevated') themeColorSurfaceElevated: string = '#FFFFFF';
  // 批3：主色底上的文字字面量改走主题色位，默认值取本地默认配色「草野」夜档真值。
  @StorageProp('themeColorOnPrimary') themeColorOnPrimary: string = '#1F3701';
  // 批6：菜单选中态由 M3 派生近似改为主题真色位 secondaryContainer，默认值取草野夜档真值。
  @StorageProp('themeColorSecondaryContainer') themeColorSecondaryContainer: string = '#404A33';
  @StorageProp('themeAppBackground') themeAppBackground: string = '';
  @StorageProp('themePureBlack') themePureBlack: boolean = false;
  // 「编辑内容」与「设置编码」两个浮层原来整块写死深色字面量，切主题纹丝不动。
  // 按 ThemePalette.publishPaletteColors() 的既有映射换成主题键：
  // 主文字=onSurface(themeColorTextPrimary)、次要文字=onSurfaceVariant(themeColorTextTertiary)、
  // 输入框底=surfaceContainer(themeColorSurfaceTertiary)、强调=primary(themeColorAccent)。
  @StorageProp('themeColorSurfaceTertiary') themeColorSurfaceTertiary: string = '#F0F1F5';
  @StorageProp('themeColorAccent') themeColorAccent: string = '#3F5BD9';
  /**
   * 状态栏高度（vp），由 `pages/Index.ets` 的 `publishAppTopInset()` 广播。
   *
   * 上游阅读器面板的让位在面板层：`ReadBookMenuBarTitle.kt:167-171` 外层
   * `windowInsetsPadding(WindowInsets.safeDrawing.only(Top + Horizontal))`，
   * 标题行 `:174-180` 只 `padding(horizontal = 16.dp, vertical = 4.dp)`。
   * 本地面板只有这一行内容，把 inset 加进行 padding 是等价近似。
   */
  @StorageProp('appTopInset') appTopInset: number = 0;
  /**
   * 手势条 / 三键导航高度（vp），由 `pages/Index.ets` 的 `publishAppBottomInset()` 广播。
   *
   * 上游 `ReadBookMenuBar.kt:500-506` 非悬浮时 `surfaceWindowInsetSides` 只留 Horizontal
   * （面板底色一路铺到导航栏），靠 `:629` 的 `bottomPadding = navBarHeight + 16.dp` 让内容避让。
   * 本地 `.expandSafeArea` 那层等价于「底色铺满」，缺的就是这份内容让位。
   */
  @StorageProp('appBottomInset') appBottomInset: number = 0;
  /** 底栏进度条轨道实测宽度（vp），由 Slider 的 `onAreaChange` 写入，自绘拇指按它定位。 */
  @State sliderTrackWidth: number = 0;
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
  /**
   * 批10（:569）这本书所属书源的名字；空串表示「没有可用书源」，标题胶囊右端就不画圆点。
   * 由 `Index.ets` 查 `BookSourceRepository` 后注入 —— 阅读页不自己去查仓库，
   * 免得每翻一页都扫一遍书源表。上游判据是 `!state.isLocalBook && state.bookSource != null`
   * （`ReadBookMenuBarTitle.kt:593`），本地书源对象被删掉时这里就是空串，等价于上游的 null。
   */
  @Prop bookSourceName: string = '';
  @Prop selectText: boolean = true;
  /** 选择正文时震动；上游 ReadSettings.kt:41 selectVibrator，消费点见 ReaderHaptics。 */
  @Prop selectVibrator: boolean = false;
  @Prop bookmarks: ReaderBookmark[] = [];
  // 标记变化必须递增 revision，否则滚动模式的 ForEach 复用旧 Span、划线渲染不出来。
  @Prop @Watch('onMarkingsChanged') markings: ReaderMarking[] = [];
  /** 上次用过的标记样式（上游 ReadSettings.lastMarkingStyle），批5（:127）快速标记面板默认取它。 */
  @Prop lastMarkingStyle: string = '';
  @Prop readingAnchorAvailable: boolean = false;
  @Prop clickImageBehavior: string = '2';
  @Prop clickRegionActions: string[] = [];
  @Prop @Watch('onSystemBarSettingsChanged') hideStatusBar: boolean = false;
  @Prop @Watch('onSystemBarSettingsChanged') hideNavigationBar: boolean = false;
  @Prop @Watch('onImagePreviewCloseRevisionChanged') imagePreviewCloseRevision: number = 0;
  @Prop @Watch('onPageAnimationChanged') pageAnimation: number = 0;
  /** 当前主题档位（上游 appTheme），电子书 = 4，由 Index 以 @Prop 传入。 */
  @Prop themePaletteIndex: number = 0;
  /** 电子书主题独立的翻页动画档（上游 pageAnimEInk，默认 4 = 淡入淡出）。 */
  @Prop pageAnimationEInk: number = 4;
  @Prop animationSpeed: number = 2;
  @Prop @Watch('onPaginationInputsChanged') infoSettings: ReaderInfoSettings = DEFAULT_READER_INFO_SETTINGS;
  @Prop @Watch('onPaginationInputsChanged') paddingSettings: ReaderPaddingSettings = DEFAULT_READER_PADDING_SETTINGS;
  @Prop @Watch('onImageStyleChanged') imageStyle: string = 'DEFAULT';
  @Prop replaceEnabled: boolean = true;
  @Prop replaceUsesDefault: boolean = true;
  @State contentProcesses: BookContentProcess[] = [];
  @State readerHighlightRules: ReaderHighlightRule[] = [];
  @State readerHighlightRanges: ReaderHighlightRange[] = [];
  // 批8 D 组（:923）：当前排版名（本地 = 背景样式名），由 Index 传入；
  // 高亮规则按 configName 是否包含它决定是否生效（空 = 全局规则恒生效）。
  @Prop @Watch('onCurrentConfigNameChanged') currentConfigName: string = '';
  // 批8 D 组（:923）：可选的排版名（= 背景样式名），供高亮规则编辑页的「应用排版」chip。
  @Prop availableConfigNames: string[] = [];
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
  /**
   * 批4：当前朗读段区间（语义正文坐标，与 LocalReaderLineItem.startPosition 同源）。
   * @Watch 在段切换时跟随位置 + 重绘；start<0 表示无朗读段。
   */
  @Prop @Watch('onReadAloudSpanChanged') readAloudSpan: ReadAloudSpan = EMPTY_READ_ALOUD_SPAN;
  /**
   * 批6：应用内朗读胶囊（上游是系统悬浮窗，三方做不到；退出阅读器即消失）。
   * 播放中且 showReadAloudCapsule 为真时显示；位置可拖、松手存偏好。
   */
  @Prop @Watch('onCapsuleSettingsChanged') readAloudCapsuleSettings: ReadAloudSettingsSnapshot =
    DEFAULT_READ_ALOUD_SETTINGS;
  @Prop @Watch('onCapsuleActiveChanged') readAloudActive: boolean = false;
  /** 批6：播放状态（0 空闲/1 播放/2 暂停），决定播放暂停图标方向与封面是否旋转。 */
  @Prop @Watch('onCapsuleAloudStateChanged') capsuleAloudState: number = 0;
  @State capsuleX: number = 0;
  @State capsuleY: number = 0;
  @State capsuleCollapsed: boolean = false;
  @State capsuleDragBaseX: number = 0;
  @State capsuleDragBaseY: number = 0;
  @State capsuleCoverAngle: number = 0;
  /** 渲染宽度（vp）：折叠 56 / 展开 140，animateTo 320ms 插值以还原上游连续揭示。 */
  @State capsuleWidthAnim: number = 56;
  /** 位置是否已从偏好换算成渲染中心坐标（尺寸到位后只换算一次）。 */
  private capsulePosInitialized: boolean = false;
  /** 胶囊中心距屏幕底部的默认距离（上游 CapsuleDefaultCenterFromBottomDp = 72）。 */
  private readonly capsuleCenterFromBottom: number = 72;
  /** 胶囊自动收起计时器（上游 3 秒无操作折叠）。 */
  private capsuleCollapseTimer: number = -1;
  /** 封面旋转计时器（上游播放时封面 20 秒转一圈）。 */
  private capsuleCoverTimer: number = -1;
  /** 胶囊尺寸（vp），位置钳位用；折叠态只露封面、展开态揭示按钮。 */
  private readonly capsuleCoverSize: number = 48;
  private readonly capsuleWidthCollapsed: number = 56;
  private readonly capsuleWidthExpanded: number = 140;
  private readonly capsuleHeight: number = 56;
  /** 自定义背景图片的沙箱路径；空串表示没有，上游 ReadBookConfig.kt:549 bgType != 0 的情况。 */
  @Prop @Watch('onReaderCanvasStyleChanged') readerBackgroundImage: string = '';
  /** 背景图片不透明度百分比（0..100），上游 ReadBookConfig.kt:548 bgAlpha。 */
  @Prop backgroundAlpha: number = 100;
  /** 状态栏图标是否用深色；上游 ReadBookConfig.kt:552-553 darkStatusIcon / darkStatusIconNight。 */
  @Prop @Watch('onDarkStatusIconChanged') darkStatusIcon: boolean = true;
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
  /** 大图预览缩放倍数：上游 PhotoView 钳制在 1..2.5（PhotoView.kt:38/501-506）。 */
  @State imagePreviewScale: number = 1;
  /** 拖动位移（px），与缩放一起组成预览的 transform。 */
  @State imagePreviewOffsetX: number = 0;
  @State imagePreviewOffsetY: number = 0;
  /** 手势开始时的基准值，供 PinchGesture / PanGesture 叠加。 */
  private imagePreviewBaseScale: number = 1;
  private imagePreviewBaseOffsetX: number = 0;
  private imagePreviewBaseOffsetY: number = 0;
  @State overflowVisible: boolean = false;
  @State imageStyleMenuVisible: boolean = false;
  /** 「翻页动画」条目的二级菜单：上游点一下直接展开 6 项单选，不弹「未迁移」。 */
  /** 更多操作面板当前页（每页 8 格，对齐上游 chunked(8)）。 */
  @State moreActionPage: number = 0;
  /** 哪一格展开了二级菜单（空串 = 都没展开）。上游 ReaderMenuActionSquare.kt:72-75 的三角点击带。 */
  @State moreActionMenuId: string = '';
  @State pageAnimMenuVisible: boolean = false;
  /** 「模拟追读」面板（上游 Book.config 四项），点确定时由上层一次落库。 */
  @State simulatedReadingVisible: boolean = false;
  @State simReadEnabled: boolean = false;
  @State simReadStartDate: string = '';
  @State simReadDailyInput: string = '3';
  @State simReadStartChapterInput: string = '0';
  @State moreActionConfigVisible: boolean = false;
  @State moreActionShellVisible: boolean = false;
  @State moreActionShellTitle: string = '';
  /**
   * 批10（:570）长按「换源 / 刷新章节」格子弹出的二级菜单：'' 表示没展开，
   * 值是格子的 id（`change_source` / `refresh`）。上游 `ReadMenuLongPressDropdown`
   * 由 `ReadMenuLongPressMenu.ChangeSource / Refresh` 两个枚举值分派
   * （`ReadBookMenuBarTitle.kt:796-821`）。
   */
  @State longPressMenuId: string = '';
  @State draftMoreActions: ReaderMoreActionConfig[] = READER_MORE_ACTION_DEFAULTS.map(
    (item: ReaderMoreActionConfig): ReaderMoreActionConfig => ({ id: item.id, enabled: item.enabled })
  );
  @State charsetDialogVisible: boolean = false;
  @State charsetOptionsExpanded: boolean = false;
  @State charsetInput: string = 'UTF-8';
  @State activeImageStyle: string = 'DEFAULT';
  @State readerProgress: number = 0;
  @State sliderProgressIndex: number = 0;
  // 分页档拖动进度条时，上一次已经跳到的预览页号。
  // 对齐上游 `ReadBookMenuBarBottom.kt:77` 的 previewPageIndex：拖动过程中
  // 系统会连续派发同一个整数值，重复跳同一页会让画布反复重绘而闪烁。
  @State sliderDragPreviewPageIndex: number = -1;
  @State viewportHeight: number = 0;
  @State @Watch('onCapsuleViewportChanged') readerContentWidth: number = 0;
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
  // 跨章续接的位移（vp）。章末越过页界的那一小段负余量在这里暂存，
  // 等新章页表在 rebuildReaderPages 里落定后当作新章首页的初始偏移，
  // 对齐上游「换章时 scrollOffset 直接续写」。不存的话换章重排会把这段位移丢掉，
  // 手指没抬起的后续位移就断了，用户必须松手再滑一次才能继续。
  private pendingChapterScrollVp: number = 0;
  // 章界交接进行中：实测换章时 book / chapterTitle / content 三个 @Watch 会依次触发
  // （selectChapter 换 selectedBook 引用还会触发 onBookChanged 把交接标记作废），
  // 任何一个清零点在这段窗口动手都会吃掉余量，所以用它挡住清零，直到页表落定消费。
  private chapterBoundaryContinuation: boolean = false;
  /**
   * 这一次「滚动跨章」的目标章号，-1 表示没有。
   *
   * 与 `chapterHandoffPending` 的区别是**谁决定位置**：后者只看书号没变，
   * 由 `onReaderContentChanged` 置位，位置仍按 `book.androidCharacterPosition`
   * 字符坐标重定位；本字段为真（等于当前章号）时位置**已经由 `currentPageIndex`
   * 表达**——用户就是这么滚过来的——重建必须按页身份接回同一页。
   *
   * 存章号而不是布尔：从滚进邻章到宿主把正文送到，中间可能夹着几次
   * 「仍是旧章」的重建（图片尺寸、标题定稿）。布尔会被它们吃掉，
   * 章号只有等真正重建到那一章时才消费并清零。
   */
  private scrollDrivenHandoffChapter: number = -1;
  /**
   * 正在向宿主请求的邻章章号，-1 表示没有在途请求。
   *
   * 每次 `rebuildReaderPages` 收尾都会检查邻章页是否齐备；没有它的话同一个
   * 请求会在每次重排（换章两遍、图片尺寸到达、设置变更都触发）里重复发出，
   * 宿主侧就变成反复读盘。
   */
  private pendingAdjacentChapter: number = -1;
  /** 上一次预读请求的时刻（毫秒），用于给在途请求超时重发。 */
  private pendingAdjacentChapterAt: number = 0;
  /** 已经成功下发并排进页表的邻章章号，-1 表示还没有；防止同一章反复要。 */
  private deliveredAdjacentChapter: number = -1;
  /**
   * 上一次交接记的是哪本书。
   *
   * 换书时 `content` 同样会变，若不区分就会把上一本书的页表当过渡帧画出来。
   * 只有 book.id 没变才算「换章」，换书仍按原路径清空。
   */
  private chapterHandoffBookId: string = '';
  /**
   * 上一次 `book` @Prop 指向的书 id，用来区分「换书」与「同书换章/进度回写」。
   *
   * `onBookChanged` 每次 `selectedBook` 重新赋值都会触发——不只是换书换章，
   * 滚动模式每 250ms 回写一次阅读进度也会触发。早前这里比的是
   * `chapterHandoffBookId`（只在正文送达时才写），首次进书它还是空串，
   * 于是每一帧滚动都被当成「换书」处理，把刚置上的 `scrollDrivenHandoffChapter`
   * 抹掉——跨章守位因此从来没生效过。用独立字段记录「上一次看到的是哪本书」，
   * 与交接状态解耦。
   */
  private observedBookId: string = '';
  @State localReaderPages: LocalReaderPage[] = [];
  /**
   * 是否有一轮流式分页正在跑（#1013）。**不加 @State**：它不参与 UI 重建，
   * 只用来让 `insertBoundaryPlaceholders` 在页表「只排了一半」时收手。
   */
  private paginationStreaming: boolean = false;
  /** 流式分页的轮次令牌：换章/重排就自增，旧轮次看到令牌不符自己停下，不残留旧页。 */
  private paginationStreamToken: number = 0;
  @State readerBottomJustifyGap: number = 0;
  @State fullBookPageCounts: number[] = [];
  @State fullBookPaginationReady: boolean = false;
  @State localSemanticContent: string = '';
  private localSemanticDocument: LocalSemanticDocument = {
    paragraphs: [], content: '', sourceLength: 0, sourcePositionMap: [0]
  };
  /**
   * 当前页在「窗口页表」里的数组下标。
   *
   * 页层批次 4 后 `localReaderPages` 是跨章窗口页表（当前章 ±1 章 + 显示章），
   * 所以这个下标**不是全书下标，也不是章内下标**——只是 `localReaderPages[index]`
   * 的位置。要显示「本章第几页 / 共几页」或换算章内位置，一律用
   * `chapterPosition(this.localReaderPages, this.currentPageIndex)` 现算，
   * 不要拿这个数当章内页号用。页表插入 / 删除 / 换章后旧下标失效，
   * 定位由 `rebasePageIndex` / `locateOrNull` / `locateChapterPage` 按页身份重查。
   */
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
  /** 底栏动作区上下内边距（`.padding({ top: 4, bottom: 17 })`）之和。 */
  private static readonly BOTTOM_ACTION_PADDING: number = 21;
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
   * 实测值与 `getReaderInfoReserve()` 的公式值来自两条不同的路径（ArkUI 测量 vs 手算），
   * 二者一旦不等，分页就会认为放得下、画到画布上时最后一行被下边缘裁掉半行。
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
  // 批5（:127）行内快速标记面板：可见性、样式、备注草稿、命中的已有标记 id、面板锚点
  @State quickMarkVisible: boolean = false;
  @State quickMarkStyle: ReaderMarkingEffect = 'solid';
  @State quickMarkNote: string = '';
  @State quickMarkExistingId: string = '';
  @State quickMarkAnchorX: number = 0;
  @State quickMarkAnchorY: number = 0;
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
  /**
   * 本次拖动是否已经因为滚到章边界而发过换章请求。
   *
   * 页层批次 4 起它的职责收窄为「一次拖动只发一次换章请求」的**去重闸门**，
   * 不再负责把手势停住：帧照常喂给 `applyReaderScrollDelta`，占位页在页表里，
   * 位移能继续往前走。旧语义是发请求后丢弃所有后续帧、直到换章页表落定，
   * 读盘那段时间手指还在动、画面却不动 —— 那正是「必须抬手重新滑」的来源。
   *
   * 只在 `PanGesture.onActionStart` 复位，**不再**在 `onReaderContentChanged`
   * 里复位：换章页表落定时手指可能还按着，此时复位会让同一次拖动再发一次
   * 换章请求，连跳两章。
   */
  private scrollDragBoundaryTurned: boolean = false;
  /** 抬手惯性里是否已经发过换章请求（一次惯性只发一次，避免连跳）。 */
  private scrollFlingBoundaryTurned: boolean = false;
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
  // 批 11：EPUB 行内样式 sidecar 缓存：key 为 bookId，避免每次重绘都读盘。
  private epubStyleCache: Map<string, Record<string, EpubInlineStyleRange[]> | null> = new Map();
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
  /**
   * 批10（:569）点标题胶囊右端的书源圆点：弹书源下拉（上游 `ReadMenuSourceDropdown`，
   * `ReadBookMenuBarTitle.kt:639-690`）。本地这四项里「登录 / 章节付费 / 编辑源 / 禁用源」
   * 只有「编辑源」有落地页，其余由上层如实提示未迁移，不在这里假装能用。
   */
  onOpenSourceMenu: () => void = () => {};
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
  /** :224 全文搜索：带选中文字作初值；老调用方（底栏/菜单）不传参即空串。 */
  onOpenSearchContent: (initialQuery?: string) => void = (_initialQuery?: string) => {};
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
  /** 底栏「朗读」点击：开始/停止朗读（上游 ReadMenuActionDefs.kt:407 的 LongClickReadAloud 之外的点击分支）。 */
  onToggleReadAloud: () => void = () => {};
  /** :111 划词「朗读」：从选中位置开始朗读（上游 menu_aloud 走 ReadAloud 起点参数）。 */
  onReadAloudFromPosition: (position: number) => void = (_position: number) => {};
  /** 批6：胶囊播放暂停按钮 —— 直接切播放/暂停，不改朗读的启停状态。 */
  onCapsulePauseToggle: () => void = () => {};
  /** 批6：胶囊停止按钮 —— 停止朗读。 */
  onCapsuleStop: () => void = () => {};
  /**
   * 胶囊封面在完全展开态被点击 —— 对齐上游 onOpenPlayer，打开听书界面
   * （pages/ReadAloudPlayerPage.ets 全屏浮层）。
   */
  onCapsuleOpenPlayer: () => void = () => {};
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
  /**
   * 批10（:570）长按「换源」格子 → 二级菜单「换源」：整本书换到新源（上游
   * `MenuBookChangeSource` → `ReadBookSheet.ChangeBookSource`，`ReadBookMenuBarTitle.kt:765-768`）。
   */
  onOpenChangeSource: () => void = () => {};
  /**
   * 批10（:570）长按「换源」格子 → 二级菜单「更换本章源」（上游 `MenuChapterChangeSource`
   * → `ReadBookSheet.ChangeChapterSource`）。本地没有单章换源面板，上层如实提示未迁移。
   */
  onOpenChapterChangeSource: () => void = () => {};
  /**
   * 批10（:570）长按「刷新章节」格子 → 二级菜单「刷新本章」（上游 `MenuRefreshDur`）：
   * 删掉本章缓存后重新抓一次正文。
   */
  onRefreshCurrentChapter: () => void = () => {};
  /**
   * 批10（:570）长按「刷新章节」格子 → 二级菜单「刷新后续」（上游 `MenuRefreshAfter`）：
   * 清掉本章之后的缓存并重拉目录。本地实现在上层。
   */
  onRefreshAfterChapter: () => void = () => {};
  onImageStyleChange: (imageStyle: string) => void = (_imageStyle: string) => {};
  onPageAnimationChange: (animation: number) => void = (_animation: number) => {};
  /** 设置当前书的翻页动画（上游 Book.config.pageAnim），由上层落库并回填 selectedBook。 */
  onPageAnimChange: (animation: number) => void = (_animation: number) => {};
  /** 模拟追读四项落地（上游 Book.config.readSimulating/startDate/startChapter/dailyChapters）。 */
  onSimulatedReadingChange: (enabled: boolean, startDate: string, startChapter: number,
    dailyChapters: number) => void = (_enabled: boolean, _startDate: string, _startChapter: number,
    _dailyChapters: number) => {};
  onProgressChange: (bookId: string, chapterIndex: number, progress: number,
    chapterPosition: number, androidCoordinate: boolean) => void = () => {};
  onAddBookmark: (chapterPosition: number, pageText: string) => void = (_position: number, _pageText: string) => {};
  /** 点正文里的划线文字：打开这条笔记的编辑面板（上游 onMarkingClick）。 */
  onOpenMarking: (markingId: string) => void = (_markingId: string) => {};
  onCreateMarking: (chapterPosition: number, endPosition: number, selectedText: string) => void =
    (_position: number, _endPosition: number, _selectedText: string) => {};
  /**
   * 批5（:127）行内快速标记「应用」：命中已有标记（existingId 非空）就改它，否则新建。
   * 与 onCreateMarking 分开，是因为这条不经过标记编辑 Sheet，直接落库。
   */
  onApplyQuickMarking: (chapterPosition: number, endPosition: number, selectedText: string,
    effect: ReaderMarkingEffect, note: string, existingId: string) => void =
    (_position: number, _endPosition: number, _selectedText: string, _effect: ReaderMarkingEffect,
      _note: string, _existingId: string) => {};
  /** 批5（:127）行内快速标记「删除」：上游 DismissQuickMarking 的对应动作。 */
  onDeleteQuickMarking: (markingId: string) => void = (_markingId: string) => {};
  onSaveChapterContent: (chapterIndex: number, title: string, body: string) => void =
    (_chapterIndex: number, _title: string, _body: string) => {};
  onToggleReSegment: (enabled: boolean) => void = (_enabled: boolean) => {};
  onToggleDelTag: (tag: number, enabled: boolean) => void = (_tag: number, _enabled: boolean) => {};
  onOpenReplaceRules: () => void = () => {};
  /** :220 划词「替换」：把选中文字作 pattern 草稿带进新建规则页（预填，不立即替换）。 */
  onOpenReplaceRulesWithPattern: (pattern: string) => void = (_pattern: string) => {};
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
  /**
   * 请求宿主预读某一章正文（滚动模式邻章预排用）。
   *
   * 正文通道原本是单向的：宿主把整章通过 `@Prop content` 一次性下发，阅读页
   * 没有任何办法自己去要邻章。预排邻章必须先由阅读页开口，宿主读完再经
   * `adjacentChapterPayload` 送回来。
   */
  onRequestAdjacentChapter: (chapterIndex: number) => void = (_chapterIndex: number) => {};
  /**
   * 宿主预读到的邻章正文，编码为 `章号 \u0000 正文`；空串表示没有。
   *
   * 章号与正文必须**一次赋值**送达。用两个 `@Prop` 分开发会在两次赋值之间
   * 各触发一次 Watch，中间帧要么「新章号 + 旧正文」要么「旧章号 + 新正文」，
   * 两种都会按错的章号排错页。合成一份字符串就没有这个中间态。
   *
   * 邻章正文只用一次（parse → paginate → 页进页表），之后只剩页。
   * 不复用 `this.content` 装它：`this.content` 的使用点全是「当前章正文」语义，
   * 混用会让页码、进度、书签全部错位。
   */
  @Prop @Watch('onAdjacentChapterChanged') adjacentChapterPayload: string = '';
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
    // `@Prop` 的**首次赋值不触发 @Watch**，`onBookChanged` 第一次真正跑到是在
    // `book` 被重新赋值的时候——而滚动模式下第一次重新赋值恰好就是换章那一帧。
    // 不在这里先记下书 id，`observedBookId` 会一直是空串，那次被误判成「换书」，
    // 把刚由 `applyReaderScrollDelta` 置上的 `scrollDrivenHandoffChapter` 清掉，
    // 跨章守位直接失效（设备日志里 `bookChanged clearHandoff` + `keepPos sd=-1`）。
    this.observedBookId = this.book.id;
    // 同理：`onReaderContentChanged` 用 `chapterHandoffBookId` 区分「换书」与「换章」，
    // 而它只在正文送达时才写。首次进书正文是首赋（同样不触发 @Watch），这个字段
    // 会一直是空串，第一次换章就被判成「换书」把页表整窗清掉。这里一并落上。
    this.chapterHandoffBookId = this.book.id;
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
    this.sliderProgressIndex = 0;
    if (!this.startPositionPending) {
      this.syncProgressIndexFromPosition();
    }
    // 批6：胶囊位置从偏好载入（杀进程重开仍记住）——尺寸到位后按上游坐标语义换算。
    this.syncCapsulePositionFromSettings();
    // 首排之前先把本章图片尺寸量好：排版期就用真实尺寸，图片解码完只重绘不重排
    this.primeContentImageSizesSync();
    if (this.startPositionPending) {
      this.restoredProgressPosition = false;
      this.scrollOffset = 0;
      if (!this.chapterBoundaryContinuation) { this.pendingChapterScrollVp = 0; }
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
    // 批5：关阅读页释放章页快照（内存缓存不跨进程，退出即清）。
    ReaderChapterPageCache.clear();
    this.stopAutoPageTimer();
    if (this.capsuleCollapseTimer >= 0) {
      clearTimeout(this.capsuleCollapseTimer);
      this.capsuleCollapseTimer = -1;
    }
    if (this.capsuleCoverTimer >= 0) {
      clearInterval(this.capsuleCoverTimer);
      this.capsuleCoverTimer = -1;
    }
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
    if (!this.chapterBoundaryContinuation) { this.pendingChapterScrollVp = 0; }
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
    // hideStatusBar 现在有两个后果：①页眉在 headerMode 既非 1 也非 2 时跟随显隐
    // ②正文区的状态栏占位归零/恢复（见 readerStatusBarReserve）。两者都改排版输入，
    // 所以不再按 headerMode 分档，一律重排。
    this.onPaginationInputsChanged();
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
   * 注意这里只读 `TYPE_CUTOUT` 的 left / right / bottom 三个方向，**没读 topRect、也没读 `TYPE_SYSTEM`**：
   * 竖屏主路径的顶部避让由 `@StorageProp('appTopInset')`（`pages/Index.ets` 广播）覆盖，
   * 但横屏或异形屏上若正文被顶部刘海压住，根因就在这份缺口读数不全。此处只标注事实，未改逻辑。
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
    // 上游 `ReadBookMenuBar.kt:1033-1040`：菜单栏底色恒取 `surfaceContainerHigh`，
    // 而 `surfaceContainerHigh` 在 `ReadBookColorTheme.kt:291-297` 被改写成「菜单背景色」
    // （`readMenuBgColor`/`Night`），即本地的 `readerMenuBaseColor()`。
    // `surfaceContainerLow`（= 容器色）是按钮与项容器的底色，不是菜单栏底色。
    return this.readerMenuTintAlphaString(this.readerMenuBaseColor());
  }

  /**
   * 底栏背景渐变。对齐上游 `ReaderMenuVisuals.kt:12-25` 的 `readerMenuSurfaceBrush`：
   * - `0` 填充（Fill）：两段同色，等于纯色；
   * - `1` 渐变：`Brush.verticalGradient` 在 Bottom 位置是 `[Transparent, opaque]`，
   *   即**上透下浓**（本地原先是上浓下淡，方向反了）。
   * 位置 0 在顶部、1 在底部，与上游 verticalGradient 的语义一致。
   */
  private readerBottomBarGradient(): LinearGradientOptions {
    const base = this.readerMenuBaseColor();
    if (this.readMenuBottomBarBlurStyle !== 1) {
      const solid = this.readerMenuTintAlphaString(base);
      return {
        angle: 180,
        colors: [[solid, 0.0], [solid, 1.0]]
      };
    }
    // 上游第二段是 Color.Transparent（alpha 全 0），不是「再降 0.25」。
    const clear = '#' + '00' + this.readerMenuRgb(base);
    const opaque = this.readerMenuTintAlphaString(base);
    return {
      angle: 180,
      colors: [[clear, 0.0], [opaque, 1.0]]
    };
  }

  /** 底栏按钮表面是否加玻璃底色；上游 `readMenuBottomBarLiquidGlassButtons`（`ReadSettings.kt:101`）。 */
  private readerBottomBarButtonGlassEnabled(): boolean {
    return this.readMenuBottomBarLiquidGlassButtons;
  }

  /** 底栏按钮外径。上游 `ReadBookMenuBarBottom.kt:245`：玻璃开关打开时 48，否则 40。 */
  private readerBottomActionOuterSize(): number {
    return this.readerBottomBarButtonGlassEnabled() ? 48 : 40;
  }

  /**
   * 顶栏背景填充色。与底栏共用上游 `readMenuBlurAlpha`（`ReadSettings.kt:106`，
   * `ReadBookMenuBarShared.kt:49-85` 把不透明度上限夹到 0.6），因此直接复用同一折算。
   */
  private readerTopBarFillColor(): string {
    // 同底栏：菜单栏底色是 `surfaceContainerHigh` = 菜单背景色（见 readerBottomBarFillColor）。
    return this.readerMenuTintAlphaString(this.readerMenuBaseColor());
  }

  /**
   * 顶栏背景渐变。对齐上游 `ReaderMenuVisuals.kt:12-25`：Top 位置是 `[opaque, Transparent]`，
   * 即**上浓下透**（这一档方向本来就对，但第二段应是全透明，不是降 0.25）。
   */
  private readerTopBarGradient(): LinearGradientOptions {
    const base = this.readerMenuBaseColor();
    if (this.readMenuTopBarBlurStyle !== 1) {
      const solid = this.readerMenuTintAlphaString(base);
      return {
        angle: 180,
        colors: [[solid, 0.0], [solid, 1.0]]
      };
    }
    const opaque = this.readerMenuTintAlphaString(base);
    const clear = '#' + '00' + this.readerMenuRgb(base);
    return {
      angle: 180,
      colors: [[opaque, 0.0], [clear, 1.0]]
    };
  }

  /**
   * 顶栏按钮表面填充。对齐上游 `ReadBookMenuBarTitle.kt:1008-1016` 的
   * `readMenuIconButtonContainerColor(selected, iconStyle)`：`iconStyle == 1`（色调）时
   * 走 `surfaceContainerLow`，即本地的菜单容器色（`ReadBookColorTheme.kt:296`）；
   * 其余透明。选中态由 `readerMenuItemFill()` 接管。
   */
  private readerTopBarButtonFillColor(): string {
    return this.titleBarIconStyle === 1 ? this.readerMenuContainerBaseColor() : 'Transparent';
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
   * 顶栏按钮外径。上游 `ReadBookMenuBarTitle.kt:439-440`：
   * `outerSize = if (glassEnabled) 48.dp else 40.dp`，内层内容区恒 40。
   * 合并胶囊模式不受影响：上游 `MenuTitleBarMergedGlassButton` 的容器高度就是 40，
   * 外层若变 48 会撑破胶囊，所以合并模式下锁 40。
   */
  private readerTopBarButtonOuterSize(): number {
    if (this.readerTopBarMergeEnabled()) { return 40; }
    return this.readMenuTopBarLiquidGlassButtons ? 48 : 40;
  }

  /**
   * 菜单文字阴影。对齐上游 `ReadBookMenuBarShared.kt:19`：
   * 黑色 12% 不透明、无偏移、模糊 12。`#1F000000` 的 0x1F = 31/255 ≈ 12%。
   * ArkUI 的 `.textShadow` 参数是（radius, color, offsetX, offsetY），radius 单位是 vp。
   */
  private readerMenuTextShadow(): ShadowOptions {
    return { radius: 12, color: '#1F000000', offsetX: 0, offsetY: 0 };
  }

  /**
   * 标题栏胶囊的描边。上游 `ReadBookMenuBarTitle.kt:503-515` 的优先级是
   * 「有菜单边框配置线 > iconStyle == 2 的 1dp 线 > 无」。
   * `'73'` 是 45%，与上游 `onSurfaceVariant.copy(alpha = 0.45f)` 同口径。
   */
  private readerTitleCapsuleBorder(): BorderOptions {
    // 直接重算宽度而不用 `configured.width > 0`：BorderOptions.width 的静态类型是
    // Length（number | string | Resource），取出来做数值比较在严格模式下不合法。
    const width = Math.max(0, Math.min(4, Math.round(this.readMenuBorderWidth)));
    if (width > 0) { return this.readerMenuBorderSettings(); }
    if (this.titleBarIconStyle === 2) {
      return { width: 1, color: this.readerMenuForegroundAlpha('73') };
    }
    return { width: 0 };
  }

  /**
   * 当前是不是夜间。上游 `ReadStyleResolver.isNightTheme()`（`ReadStyleResolver.kt:57-59`）=
   * `ReadSessionState.isDarkThemeOverride ?: isNightThemeCompat`，而 `isNightThemeCompat`
   * 由 `AppShellSettings.themeMode` 决定（`"1"` 日 / `"2"` 夜 / 其余跟系统），**与纸色无关**。
   *
   * 本地 `readerNightMode` 的唯一来源是全局 `themeMode`（见 `pages/Index.ets:337` 的注释），
   * 与上游同口径，因此直接用它。KI-THEME3 第 7 条：r353 前按纸色亮度折算，
   * 导致「浅色纸 + 夜间主题」时菜单取日间色。
   */
  private readerMenuIsNight(): boolean {
    return this.readerNightMode;
  }

  /**
   * 菜单基底色（不含透明度）。
   *
   * 上游菜单底色走 `ReadBookMenuBar.kt:1033-1040` 的 `readMenuColors(readBarStyle)`：
   * `2` 自定义 → `surfaceContainerHigh`，其余 → `surfaceContainerHigh`。
   * 而 `surfaceContainerHigh` 在 `ReadBookColorTheme.kt:286-298` 被改写成「菜单背景色」
   * （`readMenuBgColor`/`Night`），style 0 时返回 `null` 即继承应用主题的 `surfaceContainerHigh`。
   *
   * 注意：上游 `ReadBookConfig.kt:154-178` 的 `resolvedMenuBgColor` **不是菜单底色**，
   * 它全仓只有 `ReadBookController.kt:1904` 一个消费点，用来决定状态栏图标明暗。
   * r353 前本地照抄了它，属取错对象（KI-THEME3 第 1 条）。
   *
   * 第 1/2/8 条（批 2）：只对齐「色位」与「明暗」，seed 派生（批 4）未做。
   * 上游 `ReadBookColorTheme.kt:106`/`:160` 的 `deriveDarkFromColor = false` 让明暗取应用主题
   * （`ReadBookColorTheme.kt:208`/`:217` 的 `fallbackDark = LegadoTheme.isDark`），
   * 纸色只作 seed；菜单底色 = 派生方案的 `surfaceContainerHigh`（`ReadBookMenuBar.kt:1034`/`:1038`，
   * tone 日 92 / 夜 17，见 material-color-utilities `color_spec_2021.ts:222-231`）。
   * 本地读应用主题的 `themeColorSurfaceElevated`（绑定见 `ThemePalette.ets:908`），色位同名、明暗同源；
   * 未还原 seed 派生，色位不随纸色色相变化——用户换纸色后菜单底色不变。
   */
  private readerMenuBaseColor(): string {
    // 模糊层着色优先级最高。上游 `ReadBookMenuBarShared.kt:52` 与
    // `ReadBookMenuBarTitle.kt:113` 都写成 `readMenuTintColor(menuConfig) ?: colors.background`，
    // 即 tint 非未设置时**直接顶替**底色，不是叠在底色上。
    const tint = this.readerMenuTintColor();
    if (tint.length > 0) { return tint; }
    if (this.readBarStyle === 2) {
      const custom = this.readerMenuIsNight() ? this.readMenuBgColorNight : this.readMenuBgColor;
      if (custom.length > 0) { return custom; }
      // 种子档（`readMenuColorMode == 0`）：上游 `rememberCustomReadMenuTheme`
      // （`ReadBookColorTheme.kt:152-161`）用强调色作 seed 派生整套色位，
      // 菜单底色取派生方案的 `surfaceContainerHigh`。批 4 已移植派生能力，按同语义派生。
      if (this.readMenuColorMode === 0) {
        // 色板风格跟随 `readMenuPaletteStyle`（索引 1 的传参链已接通）；空串/未知值按上游回落 tonalSpot。
        const accent: string = this.readerMenuAccentTint();
        const style: M3PaletteStyle = normalizePaletteStyle(this.readMenuPaletteStyle);
        return resolveDynamicColor(accent, this.readerMenuIsNight(), style,
          'surfaceContainerHigh' as M3ColorSlot);
      }
      // 上游 `readMenuBackgroundColor`（`ReadBookColorTheme.kt:304-310`）未设置时回落
      // `durConfig.menuBgColor(isNight)`，其默认值见 `ReadBookConfig.kt:540-546`：
      // 日 `#EEEFE3` / 夜 `#BFCBAD`（草野配色的 light surface / dark surface）。
      return this.readerMenuIsNight() ? '#BFCBAD' : '#EEEFE3';
    }
    if (this.readBarStyle === 1) {
      // 上游 `ReadBookColorTheme.kt:66-106` 以纸色为 seed 派生整套色位
      // （`deriveDarkFromColor = false`，明暗取应用主题 `ReadBookColorTheme.kt:208`/`:217`），
      // 菜单底色 = 派生方案的 `surfaceContainerHigh`（`ReadBookMenuBar.kt:1034`/`:1038`，
      // tone 日 92 / 夜 17，见 material-color-utilities `color_spec_2021.ts:222-231`）。
      // 批 4：本地已移植派生能力，色位随纸色色相变化。
      // 色板风格跟随 `readMenuPaletteStyle`（索引 1 的传参链已接通）；空串/未知值按上游回落 tonalSpot。
      // 明暗取应用主题（`readerMenuIsNight()` ↔ `readerNightMode`），与上游 deriveDarkFromColor=false 同口径。
      const style: M3PaletteStyle = normalizePaletteStyle(this.readMenuPaletteStyle);
      return resolveDynamicColor(this.paperColor, this.readerMenuIsNight(), style,
        'surfaceContainerHigh' as M3ColorSlot);
    }
    // style 0：上游 `rememberReadBookColorTheme` 返回 null → 完全继承应用主题，
    // 菜单底色即应用主题的 `surfaceContainerHigh`，本地对应 `themeColorSurfaceElevated`。
    return this.themeColorSurfaceElevated;
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
   * 菜单项 / 按钮的容器底色。
   * 上游 `ReadBookMenuBarTitle.kt:1008-1016` 的 `readMenuIconButtonContainerColor(selected, iconStyle)`：
   * 选中走 secondaryContainer，`iconStyle == 1`（色调）走 surfaceContainerLow，其余透明。
   * `iconStyle == 1` 的 surfaceContainerLow 就是本地的菜单容器色（见 `ReadBookColorTheme.kt:296`）。
   */
  private readerMenuItemFill(selected: boolean, iconStyle: number): string {
    if (selected) { return this.readerMenuSelectedFill(); }
    if (iconStyle === 1) { return this.readerMenuContainerBaseColor(); }
    return 'Transparent';
  }

  /**
   * 选中态容器底色。上游是 `secondaryContainer`（ReadBookMenuBarTitle.kt:1008-1016）。
   * 批6：原先用 mixHexColor(强调色, 菜单底色, 0.7) 近似 M3 派生色——那是近似值，
   * 换主题时不跟真色位走；现改读主题真色位 themeColorSecondaryContainer。
   */
  private readerMenuSelectedFill(): string {
    return this.themeColorSecondaryContainer;
  }

  /**
   * 菜单强调色。上游 `readMenuAccentColor`（`ReadBookColorTheme.kt:312-320`）取
   * `readMenuAccentColor`/`Night`；未设置时回落 `durConfig.menuAccentColor(isNight)`，
   * 其默认值见 `ReadBookConfig.kt:540-546`：日 `#EEEFE3` / 夜 `#586249`
   * （草野配色的 light surface / dark primary），**不是硬编码的粉色**。
   *
   * 上游「种子色」与「强调色」共用同一字段（`SystemMenuPage.kt:308-368`），这里同样只读一处。
   * KI-THEME3 第 5 条：r353 前未设置时写死 `#FFB1C8`。
   */
  private readerMenuAccentTint(): string {
    const custom = this.readerMenuIsNight() ? this.readMenuAccentColorNight : this.readMenuAccentColor;
    return custom.length > 0 ? custom : (this.readerMenuIsNight() ? '#586249' : '#EEEFE3');
  }

  /**
   * 菜单模糊层着色。逐条照上游 `readMenuTintColor`（`ReadBookMenuBarShared.kt:76-92`）三段：
   *
   * ```
   * menuConfig.readMenuBlurColorNight.takeIf { it != 0 && isNightTheme() }
   *   ?: menuConfig.readMenuBlurColor.takeIf { it != 0 && !isNightTheme() }
   *   ?: menuConfig.readMenuBlurColor.takeIf { it != 0 }
   * ```
   *
   * 第三段是兜底：**夜间但 `Night` 未设置时，仍回落日间的 `readMenuBlurColor`**。
   * KI-THEME3 第 9 条：r353 前缺第三段，夜间且 `Night` 为空时返回空串、丢掉了日间着色。
   * 空串表示两端都没设置。
   */
  private readerMenuTintColor(): string {
    const day = this.readMenuBlurColor.trim();
    const night = this.readMenuBlurColorNight.trim();
    if (this.readerMenuIsNight() && night.length > 0) { return night; }
    if (!this.readerMenuIsNight() && day.length > 0) { return day; }
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

  /**
   * 底栏进度条自绘拇指的水平偏移（相对 Stack 中心）。
   * 上游 `ReadBookMenuBarTool.kt:74-160` 的 handle 是 4dp×44dp 竖条，
   * 位置由 value 在 valueRange 里的比例算出。ArkUI 系统 Slider 的 InSet 样式轨道两端
   * 各留半个拇指宽度，所以可用行程是 `轨道宽 - 拇指宽`，中心点再平移半个行程。
   */
  private sliderThumbOffset(): number {
    const maximum = Math.max(0, this.getProgressSliderMaximum());
    if (maximum <= 0 || this.sliderTrackWidth <= 0) { return 0; }
    const ratio = Math.max(0, Math.min(1, this.sliderProgressIndex / maximum));
    const travel = Math.max(0, this.sliderTrackWidth - SLIDER_THUMB_TRAVEL_INSET * 2);
    return ratio * travel - travel / 2;
  }

  /**
   * 顶栏是否启用玻璃/雾化档。上游 `ReadBookMenuBarTitle.kt:1000-1006`：   * `readMenuTopBarHazeEnabled = hazeState != null && mode == Haze`，`blurRadius = readMenuBlurRadius`。
   * ArkUI 没有 haze 系统，2 档用「模糊半径翻倍」近似，不是等价实现。
   */
  private readerTopBarBlurRadiusVp(): number {
    if (this.readMenuTopBarBlurMode === 0) { return 0; }
    return this.readMenuTopBarBlurMode === 2
      ? this.readerMenuBlurRadiusVp() * 2
      : this.readerMenuBlurRadiusVp();
  }

  /**
   * 底栏是否启用玻璃/雾化档。上游 `ReadBookMenuBar.kt:978-997`：
   * 非悬浮时液态玻璃档被强制降级成雾化档（`readMenuBottomBarEffectiveBlurMode`）。
   * 同样地，2 档用模糊翻倍近似 ArkUI 无 haze 的现状。
   */
  private readerBottomBarBlurRadiusVp(): number {
    const effective = (!this.readMenuFloatingBottomBar && this.readMenuBottomBarBlurMode === 1)
      ? 2 : this.readMenuBottomBarBlurMode;
    if (effective === 0) { return 0; }
    return effective === 2
      ? this.readerMenuBlurRadiusVp() * 2
      : this.readerMenuBlurRadiusVp();
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

  /**
   * 划词卡片的容器底色。
   * 上游取 `surfaceBright`，它在 `ReadBookColorTheme.kt:270-284` 的 `withReadSurfaceColors`
   * 里被改成「阅读背景色」；本地没有这个色位，按同一语义直接用纸色（`paperColor`）。
   * 其余两档（跟随系统 / 跟随菜单）上游回落到主题的 surfaceBright，本地用菜单底色近似，
   * 差别是「比正文背景亮一档还是暗一档」，验收只判卡片能不能从正文里分出来。
   */
  private readerSelectionCardColor(): string {
    if (this.readBarStyle === 1) { return this.paperColor; }
    return this.readerMenuBaseColor();
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
      const position = chapterPosition(this.localReaderPages, this.currentPageIndex);
      if (position !== undefined && position.pageIndex + 1 < position.pageCount) {
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
    this.syncProgressIndexFromPosition();
    // 页层批次 4：滚动驱动换章时标题变化**不是**「换章完成、位置归零」的信号。
    // 用户是一路滚进来的，`currentPageIndex + scrollOffset` 就是眼睛正看着的位置；
    // 这里把它清零等于在换章瞬间把画面拍回页顶——又一处「跳」。
    if (this.usesCanvasScroll() && this.scrollDrivenHandoffChapter >= 0) {
      this.chapterBoundaryContinuation = true;
    } else {
      this.restoredProgressPosition = false;
      this.scrollOffset = 0;
      if (!this.chapterBoundaryContinuation) { this.pendingChapterScrollVp = 0; }
    }
    // 这里不再 rebuildReaderPages()：标题定稿后会赋值 displayChapterTitle，
    // 触发 onDisplayChapterTitleChanged() 再排一次，那才是标题真正落定的时机。
    // 两处都排就是同一章排两遍，换章时白白多一次全章测量。
    this.refreshDisplayChapterTitle();
    this.refreshContentProcesses();
  }

  onBookChanged(): void {
    // 关键：**换章也会走到这里**。宿主换章时会给 `book` 重新赋值
    // （`selectedBook` 变了），`@Prop` 引用一变这个 Watch 就触发，而此时的
    // `chapterHandoffBookId` 还停在上一轮交接记下的同一本书 id 上。
    //
    // 早前这里无条件清 `chapterHandoffBookId` / `scrollDrivenHandoffChapter`，
    // 于是滚动跨章那一刻，守位标记刚由 `applyReaderScrollDelta` 置上就被这里
    // 抹掉，`rebuildReaderPages` 只能退回按宿主回传的字符坐标定位——画面从
    // 邻章页被拽回新章首页，用户看到的就是「跨章那一下跳」。这也解释了为什么
    // 设备日志里 `keepPos sdChapter=-1`：标记从来没活到重建那一步。
    //
    // 只有 book.id 真的变了才当作换书处理；同书换章保留交接标记。
    const sameBook = this.observedBookId.length > 0 && this.observedBookId === this.book.id;
    this.observedBookId = this.book.id;
    if (!sameBook) {
      // 批5：换书时旧书的章页快照全部作废，不能拿去套新书。
      ReaderChapterPageCache.clear();
      // 换书不是换章：作废交接标记，下一次正文到达按「换书」处理（清空页表）。
      this.chapterHandoffBookId = '';
      this.chapterHandoffPending = false;
      this.chapterHandoffUpward = false;
      // 换书必须作废滚动驱动标记：它是「哪一章的位置由滚动决定」，
      // 换了书之后那个章号指向的是另一本书的章。
      this.scrollDrivenHandoffChapter = -1;
      this.onReadSessionStart();
    }
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
    // 标题替换规则定稿后赋值 displayChapterTitle 会走到这里；这是换章帧第二次全量排版的真实来源。
    console.info(`[ReaderBench] titleChangedRebuild title=${this.displayChapterTitle}`);
    this.rebuildReaderPages();
  }

  onReaderContentChanged(): void {
    const changedAt = Date.now();
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
      // 页层批次 4：整窗清空。换书不能留上一本书的窗口表（含邻章缓存页），
      // 页表内下标与滚动偏移一并归位。
      this.localReaderPages = [];
      this.currentPageIndex = 0;
      this.scrollOffset = 0;
      if (!this.chapterBoundaryContinuation) { this.pendingChapterScrollVp = 0; }
    }
    this.chapterHandoffBookId = this.book.id;
    // 页层批次 4：滚动驱动换章时**不重置** `restoredProgressPosition`。
    //
    // 重置它的后果是：`onReaderContentAreaChanged` 紧接着会调
    // `restoreProgressPosition()`，那里按宿主回传的 `book.chapterProgress`
    // 做一次绝对位移 seek。滚动驱动换章时用户位置已经由
    // `currentPageIndex + scrollOffset` 精确表达，再按滞后的整章百分比 seek
    // 一次，向下就拽回新章章首、向上就拽到新章章末 —— 设备上看到的「回跳」
    // 正是它。换章之后不再需要这个 seek。
    if (!(this.usesCanvasScroll() && this.scrollDrivenHandoffChapter >= 0)) {
      this.restoredProgressPosition = false;
    }
    this.localSemanticContent = '';
    this.localSemanticDocument = { paragraphs: [], content: '', sourceLength: 0, sourcePositionMap: [0] };
    // 换章后同样先同步量一次：否则新章的图会先按行高占位排一遍，再被尺寸到达推一遍
    this.primeContentImageSizesSync();
    this.loadContentImageSizes();
    this.rebuildReaderPages();
    // 页层批次 4：这里不再清 `scrollDragBoundaryTurned`。
    //
    // 旧语义下它是「换章期间丢弃所有帧」的闸门，所以必须在页表落定时打开；
    // 新语义下它只是「一次拖动只发一次换章请求」的去重标记，复位点是
    // `PanGesture.onActionStart`。换章页表落定时手指往往还按着，若在这里复位，
    // 同一次拖动会再发一次换章请求，一次长甩连跳两章。
    console.info(`[ReaderBench] contentChanged totalMs=${Date.now() - changedAt} ` +
      `pages=${this.localReaderPages.length}`);
  }

  onPaginationInputsChanged(): void {
    // 批5：任一排版输入变化，旧章快照全部作废（滚动模式走不到 requestFullBookPagination
    // 的排版键分支，这里兜住）。clear 是幂等的，批量触发清多次无副作用。
    ReaderChapterPageCache.clear();
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
      // 批 3 确认打点：标记这次 rebuild 来自防抖合并回调（@Prop 批量更新）。
      console.info(`[ReaderBench] debouncedRebuild incremental=${incremental}`);
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
    this.syncProgressIndexFromPosition();
  }


  private closeReaderImagePreview(): void {
    if (!this.imagePreviewVisible) { return; }
    this.imagePreviewVisible = false;
    this.imagePreviewUri = '';
    this.imagePreviewScale = 1;
    this.imagePreviewOffsetX = 0;
    this.imagePreviewOffsetY = 0;
    this.imagePreviewBaseScale = 1;
    this.imagePreviewBaseOffsetX = 0;
    this.imagePreviewBaseOffsetY = 0;
    this.onCloseImagePreview();
  }

  /**
   * 把当前预览的图存进相册。SaveButton 已给临时媒体库授权，
   * 走 createAsset + fileIo 写入，不需要 WRITE_IMAGEVIDEO 常规权限。
   * 转 JPEG 字节沿用 EpubExporter.packAsJpeg 的成熟写法。
   */
  private async saveReaderImageToGallery(): Promise<void> {
    const uri = this.imagePreviewUri;
    if (uri.length === 0) { return; }
    let source: image.ImageSource | undefined;
    let pixelMap: image.PixelMap | undefined;
    let packer: image.ImagePacker | undefined;
    try {
      source = image.createImageSource(uri);
      if (source === undefined) { this.onUnavailableAction('保存失败：无法读取图片'); return; }
      pixelMap = await source.createPixelMap();
      if (pixelMap === undefined) { this.onUnavailableAction('保存失败：无法解码图片'); return; }
      packer = image.createImagePacker();
      const options: image.PackingOption = { format: 'image/jpeg', quality: 100 };
      const packed = await packer.packToData(pixelMap, options);
      if (packed === undefined) { this.onUnavailableAction('保存失败：无法编码图片'); return; }
      const bytes = new Uint8Array(packed);
      const helper = photoAccessHelper.getPhotoAccessHelper(getContext(this));
      const title = 'IMG_' + Date.now();
      const assetUri = await helper.createAsset(photoAccessHelper.PhotoType.IMAGE, 'jpg', { title: title });
      const file = fileIo.openSync(assetUri, fileIo.OpenMode.WRITE_ONLY | fileIo.OpenMode.TRUNC);
      try {
        fileIo.writeSync(file.fd, bytes.buffer);
      } finally {
        fileIo.closeSync(file);
      }
      this.onUnavailableAction('已保存到相册');
    } catch (error) {
      this.onUnavailableAction('保存失败：' + JSON.stringify(error));
    } finally {
      if (packer !== undefined) { await packer.release(); }
      if (pixelMap !== undefined) { await pixelMap.release(); }
      if (source !== undefined) { source.release(); }
    }
  }

  onImagePreviewCloseRevisionChanged(): void {
    this.closeReaderImagePreview();
  }

  onPageAnimationChanged(): void {
    this.resetPageTurnTransition();
    this.restoredProgressPosition = false;
    if (this.pageAnimation === 3) {
      this.scrollOffset = 0;
      if (!this.chapterBoundaryContinuation) { this.pendingChapterScrollVp = 0; }
    } else {
      this.rebuildReaderPages();
    }
  }

  onImageStyleChanged(): void {
    this.activeImageStyle = this.imageStyle;
    this.readerContentRevision++;
    this.rebuildReaderPages();
  }

  /** 图片书（PDF / 漫画包）默认样式下强制走 SINGLE 一图一页（批 8）；
   *  用户手动选的 FULL / TEXT / SINGLE 保持原值，四个取值的语义不变。 */
  private effectiveImageStyle(): string {
    return this.book.bookType === 'image' && this.activeImageStyle === 'DEFAULT'
      ? 'SINGLE' : this.activeImageStyle;
  }

  /**
   * 本书实际生效的翻页动画。四级回落：
   *   ① 本书独立配置（book.pageAnim，null / <0 = 未设置）
   *   ② 电子书主题档（pageAnimationEInk，仅当当前主题是「电子书」= index 4）
   *   ③ 全局配置（pageAnimation）
   * 上游对应 ReadBookConfig.kt:807-817 currentModeValue(eInk, night, day) + :929/:936 pageAnim；
   * 本书配置优先于 EInk 档（Book.getPageAnim() 先看 config.pageAnim）。
   * 见 app/src/main/java/io/legado/app/data/entities/Book.kt:274-285 getPageAnim()。
   */
  private effectivePageAnim(): number {
    // ?? undefined 把 null 与 undefined 一并归一为「未设置」，对齐上游 null 语义。
    const perBook = this.book.pageAnim ?? undefined;
    if (perBook === undefined || perBook < 0) {
      if (this.readerThemeIsEInk()) {
        return Math.max(0, Math.min(5, this.pageAnimationEInk));
      }
      return this.pageAnimation;
    }
    return Math.max(0, Math.min(5, perBook));
  }

  /** 当前主题是不是「电子书」那一档（上游 appTheme == "4"，ThemePalette.ets:212 index 4）。 */
  private readerThemeIsEInk(): boolean {
    return this.themePaletteIndex === 4;
  }

  /** 菜单选中档位：-1 = 默认（跟随全局），0..5 = 本书显式选择。 */
  private selectedPageAnimIndex(): number {
    const perBook = this.book.pageAnim ?? undefined;
    if (perBook === undefined || perBook < 0) {
      return READER_PAGE_ANIM_DEFAULT;
    }
    return Math.max(0, Math.min(5, perBook));
  }

  /** 打开系统日期选择器；开始日草稿为空时默认今天。 */
  private openSimReadDatePicker(): void {
    let selected = new Date();
    if (/^\d{4}-\d{2}-\d{2}$/.test(this.simReadStartDate)) {
      const parts = this.simReadStartDate.split('-');
      selected = new Date(Number(parts[0]), Number(parts[1]) - 1, Number(parts[2]));
    }
    this.getUIContext().showDatePickerDialog({
      start: new Date(2020, 0, 1),
      end: new Date(2100, 11, 31),
      selected: selected,
      onDateAccept: (value: Date) => {
        this.simReadStartDate = this.formatSimReadDate(value);
      }
    });
  }

  /** Date -> yyyy-MM-dd，全部用本地年月日，避开 toISOString 的 UTC 偏移。 */
  private formatSimReadDate(d: Date): string {
    const y = d.getFullYear();
    const m = `${d.getMonth() + 1}`.padStart(2, '0');
    const day = `${d.getDate()}`.padStart(2, '0');
    return `${y}-${m}-${day}`;
  }

  /** 校验草稿并一次性交给上层落地四项。 */
  private confirmSimulatedReading(): void {
    const date = this.simReadStartDate.trim();
    if (date.length > 0 && !/^\d{4}-\d{2}-\d{2}$/.test(date)) {
      this.onUnavailableAction('开始日格式应为 yyyy-MM-dd，例如 2026-11-01');
      return;
    }
    const daily = Number(this.simReadDailyInput);
    const startChapter = Number(this.simReadStartChapterInput);
    const dailyValue = Number.isFinite(daily) ? Math.max(0, Math.round(daily)) : 3;
    const startValue = Number.isFinite(startChapter) ? Math.max(0, Math.round(startChapter)) : 0;
    this.onSimulatedReadingChange(this.simReadEnabled, date, startValue, dailyValue);
    this.simulatedReadingVisible = false;
    this.overflowVisible = false;
  }

  /** 选中某档后交给上层写回本书并落库，然后立刻按新档位重排。 */
  private choosePageAnim(anim: number): void {
    this.onPageAnimChange(anim);
    this.pageAnimMenuVisible = false;
    this.overflowVisible = false;
    // 照 onPageAnimationChanged() 的五个动作做，但不能直接调它：它读全局 this.pageAnimation，
    // 这里改的是本书值，调它会按旧档位重排。落库是异步的，this.book 尚未被上层更新，
    // 所以用「即将生效的 anim」判滚动/分页；选默认(-1)时实际生效的是全局值。
    this.resetPageTurnTransition();
    this.restoredProgressPosition = false;
    const next = anim >= 0 ? Math.max(0, Math.min(5, anim))
      : (this.readerThemeIsEInk() ? Math.max(0, Math.min(5, this.pageAnimationEInk)) : this.pageAnimation);
    if (next === 3) {
      this.scrollOffset = 0;
      if (!this.chapterBoundaryContinuation) { this.pendingChapterScrollVp = 0; }
    } else {
      this.rebuildReaderPages();
    }
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
  /**
   * 拼跨章窗口页表（对应上游 `retainChapterWindow`，
   * `ReaderPageNavigator.kt:36-43`）：保留当前章 ±1 章的页，当前章一律用本次
   * 新排的页，邻章页来自换章时 `onReaderContentChanged` 保留下来的旧页
   * （本轮不预取、不流式发布、不做增量分页）。
   *
   * 上游还保留 `it.id.chapterIndex == displayedChapterIndex` 的显示章；本地
   * displayedChapterIndex 恒等于当前章，已落在 ±1 范围内，故不另设参数。
   * 结果按 (chapterIndex, pageIndex) 升序，保证 `ReaderCanvasWindow.of()` 的
   * previous/current/next 连续、`locateOrNull` 的 break 成立。
   * `retainChapterWindow` 按任务书不单独暴露，就地写在这里。
   */
  private mergeChapterPages(
    currentChapterPages: LocalReaderPage[], chapterIndex: number): LocalReaderPage[] {
    const windowPages: LocalReaderPage[] = [];
    for (const page of this.localReaderPages) {
      const pageChapter = page.chapterIndex ?? 0;
      // 当前章用新排的页，旧页表里同章的页一律丢弃，避免新旧页混用。
      if (pageChapter === chapterIndex) { continue; }
      if (pageChapter < chapterIndex - 1 || pageChapter > chapterIndex + 1) { continue; }
      windowPages.push(page);
    }
    for (const page of currentChapterPages) {
      windowPages.push(page);
    }
    windowPages.sort((left: LocalReaderPage, right: LocalReaderPage): number => {
      const chapterDelta = (left.chapterIndex ?? 0) - (right.chapterIndex ?? 0);
      if (chapterDelta !== 0) { return chapterDelta; }
      return (left.pageIndex ?? 0) - (right.pageIndex ?? 0);
    });
    return windowPages;
  }

  /** 当前页的章内位置（窗口页表下标 → 章身份 + 章内页号 + 本章页数）。 */
  private currentChapterPosition(): ReaderChapterPagePosition | undefined {
    return chapterPosition(this.localReaderPages, this.currentPageIndex);
  }

  /**
   * 把某一章的页换进窗口页表（页层批次 4，邻章预排专用）。
   *
   * 与 `mergeChapterPages` 的区别：那个是「当前章整章替换」——新页属于
   * `chapterIndex`，同章的旧页一律丢弃。邻章预排的新页**不属于当前章**，
   * 用它会把当前章页删光。这里只替换 `chapterIndex` 那一章的旧页，
   * 其余章原样保留，当前章的页与下标一个都不动。
   *
   * 结果同样按 (chapterIndex, pageIndex) 升序，保证窗口四页连续。
   */
  private mergeAdjacentChapterPages(
    chapterPages: LocalReaderPage[], chapterIndex: number): LocalReaderPage[] {
    const merged: LocalReaderPage[] = [];
    for (const page of this.localReaderPages) {
      if ((page.chapterIndex ?? 0) === chapterIndex) { continue; }
      merged.push(page);
    }
    for (const page of chapterPages) {
      merged.push(page);
    }
    merged.sort((left: LocalReaderPage, right: LocalReaderPage): number => {
      const chapterDelta = (left.chapterIndex ?? 0) - (right.chapterIndex ?? 0);
      if (chapterDelta !== 0) { return chapterDelta; }
      return (left.pageIndex ?? 0) - (right.pageIndex ?? 0);
    });
    return merged;
  }

  /**
   * 页表里有没有某一章的页。
   *
   * 窗口表最多装「当前章 ±1」，所以这里只要判断该章有没有被排进来过。
   * 占位页不参与这个判断——占位页是「等着被替换」的记号，不是「已经有正文」。
   */
  private hasChapterPages(chapterIndex: number): boolean {
    for (const page of this.localReaderPages) {
      if ((page.chapterIndex ?? 0) === chapterIndex && page.messageText === undefined) { return true; }
    }
    return false;
  }

  /**
   * 章边界占位页：把「还没有正文的那一侧」变成页表里的一张真页（页层批次 4）。
   *
   * 批 2 让「已经排进页表的邻章」有画面，但首次进章、预读还没回来的时候，
   * 章末之外仍然什么都没有——滚到头就没有页可以承接。这里在页表两端各补一张，
   * 让滚动位移算得到它、画布堆得下它。
   *
   * **章的归属是整件事的关键**：占位页的 `chapterIndex` 填「目标章」章号，
   * 不是当前章。填当前章会让 `chapterPosition()` 把它算进本章页数（页码变成
   * 「第 N 页 / 共 N+1 页」、进度分母偏大）；填目标章则让 `chapterPosition`
   * 按章过滤时绕开它，而 `mergeChapterPages` / `mergeAdjacentChapterPages`
   * 在真页到达时按章整体丢弃，占位页自动清理。
   *
   * 只补真缺的那一侧：已有真页就不补，免得真页和占位页同时存在。
   */
  private insertBoundaryPlaceholders(pages: LocalReaderPage[], chapterIndex: number): void {
    // 流式分页期间页表是「已排出的一截」，此时补占位页会让每次 onPage 都往中间插一张
    // 空白页、越排越多；整章排完由 applyReaderPages 一次性补（#1013）。
    if (!this.usesCanvasScroll() || this.paginationStreaming) { return; }
    const nextChapter = chapterIndex + 1;
    if (nextChapter < this.getChapterCount() && !this.hasChapterPagesIn(pages, nextChapter) &&
      !this.hasPlaceholderIn(pages, nextChapter)) {
      // 文案留空：这是一张**空白承接页**，不是提示屏。
      // 页层批次 4 复盘（用户实测反馈「有些时候还能看到继续滚动到下一张」）：
      // 画一行「继续滑动以加载下一章…」等于把加载态怼到用户脸上，与「首尾相连」
      // 的目标正相反。留空的占位页仍然进页表、仍然参与滚动几何（`pageScrollExtent`
      // 对 `messageText !== undefined` 的页按一整屏算），手指滚过去是干净的一屏空白，
      // 预读追上后它会被邻章真页按章整体替换掉。
      pages.push(this.boundaryPlaceholderPage('', nextChapter));
    }
    const previousChapter = chapterIndex - 1;
    if (previousChapter >= 0 && !this.hasChapterPagesIn(pages, previousChapter) &&
      !this.hasPlaceholderIn(pages, previousChapter)) {
      pages.unshift(this.boundaryPlaceholderPage('', previousChapter));
    }
  }

  /** 指定页表里有没有某一章的真页（不含占位页）。 */
  private hasChapterPagesIn(pages: LocalReaderPage[], chapterIndex: number): boolean {
    for (const page of pages) {
      if ((page.chapterIndex ?? 0) === chapterIndex && page.messageText === undefined) { return true; }
    }
    return false;
  }

  /** 指定页表里有没有某一章的占位页。 */
  private hasPlaceholderIn(pages: LocalReaderPage[], chapterIndex: number): boolean {
    for (const page of pages) {
      if ((page.chapterIndex ?? 0) === chapterIndex && page.messageText !== undefined) { return true; }
    }
    return false;
  }

  /**
   * 章边界占位页：`lines` 为空、只带一行居中文案，`chapterIndex` 填目标章。
   *
   * `pageScrollExtent` 里 `messageText !== undefined && used <= 0` 会让它退成一屏
   * 高度，所以它能在堆叠里占一屏、被滚进去。
   */
  private boundaryPlaceholderPage(text: string, chapterIndex: number): LocalReaderPage {
    return {
      lines: [], startPosition: 0, endPosition: 0, titleOnly: false,
      lineColumns: [], messageText: text, chapterIndex: chapterIndex, pageIndex: 0
    };
  }

  /**
   * 向宿主请求预排邻章正文（页层批次 4）。
   *
   * 滚动与分页模式都做：翻到章末时下一章已在内存，翻章不用现场读盘+排版。
   * 一次只请求一章，优先下一章——向下读是主路径。
   *
   * 三种情况不请求：已在途（`pendingAdjacentChapter`）、已经下发过且页还在
   * （`deliveredAdjacentChapter` + `hasChapterPages`）、目标章越界。
   */
  private prefetchAdjacentChapters(): void {
    // 批7：原来只在画布滚动模式下预排（非滚动模式直接 return）。
    // 分页模式同样受益于邻章预热：翻到章末时下一章已在内存，不用现场读盘+排版。
    // 上游对应机制是 ensureBoundaryPlaceholderPages（ReadBookController.kt:1085）+
    // 换章时 promote（:2935-2955），本项只借「先热邻章」这一点。
    // 主体逻辑（hasChapterPages / 在途超时 / onRequestAdjacentChapter）不依赖滚动窗口，
    // 探针已在分页模式验证：不崩、不串章、换章前邻章页已就绪。
    // P3-E：在线书也预热邻章（正文由提供器缓存优先，重复请求不重复抓网）。
    const currentChapter = this.getChapterIndex();
    const nextChapter = currentChapter + 1;
    const previousChapter = currentChapter - 1;
    const needsNext = nextChapter < this.getChapterCount() && !this.hasChapterPages(nextChapter);
    const needsPrevious = previousChapter >= 0 && !this.hasChapterPages(previousChapter);
    if (!needsNext && !needsPrevious) { return; }
    const target = needsNext ? nextChapter : previousChapter;
    // 请求只在路上，不是永久放弃：宿主可能因为「这一章刚刚变成正文」、
    // 章节标题还没读出来等原因静默不回应，回应对阅读页就是永不到达。
    // 早前只比章号，一旦这种静默发生，`pendingAdjacentChapter` 会一直停在
    // 那个章号上，之后每次 rebuild 都被这一句挡掉，邻章再也排不出来——
    // 章末就只能滚进一张空白承接页，跨章那一下自然不是首尾相连。
    // 这里给在途请求设一个超时窗口，过了就允许重发。
    if (this.pendingAdjacentChapter === target &&
      Date.now() - this.pendingAdjacentChapterAt < ReaderPage.ADJACENT_REQUEST_TIMEOUT_MS) {
      return;
    }
    if (this.deliveredAdjacentChapter === target && this.hasChapterPages(target)) { return; }
    this.pendingAdjacentChapter = target;
    this.pendingAdjacentChapterAt = Date.now();
    console.info(`[ReaderBench] adjacentRequest chapter=${target} from=${currentChapter}`);
    this.onRequestAdjacentChapter(target);
  }

  /**
   * 宿主预读回来的邻章正文：排成页并并进窗口页表（页层批次 4）。
   *
   * 这里是本轮唯一「排完不动阅读位置」的排版入口，四条纪律：
   * 不改 `currentPageIndex`、不改 `scrollOffset`、不调 `updateProgress()`，
   * 除了最后一次 `paintReaderCanvas()` 之外不产生任何副作用。邻章页只给绘制层
   * 提供可堆叠的画面、给换章提供已就绪的页，阅读位置始终停在当前章。
   *
   * 排版必须在 UI 线程同步做：测宽回调 `measureTextWidthForPagination` 依赖
   * `getUIContext()`，进不了 taskpool。这段会有一帧可见的卡顿，但发生在章末
   * 之前，不影响正在读的这屏。
   */
  private onAdjacentChapterChanged(): void {
    // 载荷是「章号 \u0000 正文」，一次赋值送达，不存在「新章号 + 旧正文」的中间帧。
    const payload = this.adjacentChapterPayload;
    const separator = payload.indexOf('\u0000');
    if (separator <= 0) { return; }
    const adjacentChapter = Number.parseInt(payload.substring(0, separator), 10);
    const content = payload.substring(separator + 1);
    if (!Number.isFinite(adjacentChapter) || adjacentChapter < 0 || content.length === 0) { return; }
    const currentChapter = this.getChapterIndex();
    // 翻了两章以上的旧结果直接丢：窗口表只保留 ±1，排进来也会被 mergeChapterPages 丢掉。
    if (Math.abs(adjacentChapter - currentChapter) !== 1) {
      if (this.pendingAdjacentChapter === adjacentChapter) { this.pendingAdjacentChapter = -1; }
      return;
    }
    if (this.pendingAdjacentChapter === adjacentChapter) { this.pendingAdjacentChapter = -1; }
    // 两个 @Prop 会各触发一次 Watch（先章号、再正文），同一章可能被送进来两次；
    // 已经排过且页还在就不再重排，否则每章白排两遍。
    if (this.deliveredAdjacentChapter === adjacentChapter && this.hasChapterPages(adjacentChapter)) {
      return;
    }
    // 视口/正文宽度没就绪时排出来的页是错的，等下一次 rebuild 再请求。
    if (this.readerContentWidth <= 0 || this.viewportHeight <= 0) {
      return;
    }
    const startedAt = Date.now();
    const context = this.getUIContext();
    // 排版输入必须与 rebuildReaderPages 完全一致，否则邻章页的行高/页高与本章不同，
    // 堆叠起来就会出现「跨章那一跳高度突变」。
    const fontSize = this.fontSize * 1.05;
    const width = this.getBodyContentWidth();
    const baseLineHeight = ReaderFontRepository.measureLineHeight(
      context, this.readerBodyFontFamily, fontSize);
    const lineHeight = Math.max(1, baseLineHeight * this.lineSpacing / 10);
    const infoHeaderReserve = this.isReaderHeaderVisible() ? this.getReaderInfoReserve(true) : 0;
    const infoFooterReserve = this.isReaderFooterVisible() ? this.getReaderInfoReserve(false) : 0;
    const formulaPageHeight = this.getBodyContentHeight(infoHeaderReserve, infoFooterReserve);
    const pageHeight = this.readerCanvasBodyHeightVp > 0
      ? Math.max(lineHeight, Math.min(formulaPageHeight, this.readerCanvasBodyHeightVp))
      : Math.max(lineHeight, formulaPageHeight);
    const paragraphSpacing = baseLineHeight * this.paragraphSpacing / 10;
    const document = LocalTextSemantics.parse(content, this.paragraphIndent, this.adaptSpecialStyle);
    // 邻章图片尺寸这里拿不到（`imageSizes` 是本章的，键是 path），一律按行高占位。
    // 邻章页本来就只用于「跨章那几帧」，等真换过去时 `loadContentImageSizes` 会重排一次。
    const adjacentImageSizes = new Map<string, ReaderIntrinsicImageSize>();
    const placeholderExtent = Math.max(1, lineHeight);
    for (let paragraphIndex = 0; paragraphIndex < document.paragraphs.length; paragraphIndex++) {
      const paragraph = document.paragraphs[paragraphIndex];
      if (paragraph === undefined) { continue; }
      for (let partIndex = 0; partIndex < paragraph.parts.length; partIndex++) {
        const part = paragraph.parts[partIndex];
        if (part?.kind === 'image' && !adjacentImageSizes.has(part.value)) {
          adjacentImageSizes.set(part.value, { width: placeholderExtent, height: placeholderExtent });
        }
      }
    }
    const singleImageStyle = this.effectiveImageStyle() === 'SINGLE';
    // 标题块必须用**邻章自己的标题**：之前传空串，邻章首页就没有标题块，
    // 与换章后宿主送来的真页（带标题）排版不一致——页表整表替换时正文会整体
    // 位移一截，用户看到的就是跨章那一下「跳」。章标题从章节缓存里取，同步可得。
    const adjacentTitle = this.resolvePaginationTitle(adjacentChapter);
    const titleBlock = this.buildReaderTitleBlock(context, width, lineHeight,
      document.content.length, singleImageStyle, adjacentTitle);
    const pages = LocalReaderPaginator.paginate(
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
      adjacentImageSizes,
      this.effectiveImageStyle(),
      context.px2vp(80),
      (ReaderFontRepository.measureTextWidth(context, '袮', this.readerBodyFontFamily, fontSize) +
        this.getReaderLetterSpacingVp(fontSize)),
      0,
      this.textFullJustify,
      this.resolveReaderColumnCount(),
      this.readerSizeOffsets,
      titleBlock,
      this.buildReaderTextLayoutStyle(fontSize),
      adjacentChapter,
      this.textBottomJustify,
      this.usesCanvasScroll()
    );
    // 当前页身份必须在 merge 之前取：merge 会重排页表，下标会变。
    const currentPage = this.localReaderPages[this.currentPageIndex];
    const currentPageChapter = currentPage?.chapterIndex ?? currentChapter;
    const currentPageChapterIndex = currentPage?.pageIndex ?? 0;
    // 不能用 mergeChapterPages：它的语义是「用新页替换 chapterIndex 那一章的旧页」，
    // 而这里的 pages 属于邻章，传邻章号会把当前章的页整章丢掉、把邻章页算进
    // 当前章页码（实测页码变成 18/24）。邻章合并只换邻章那一章。
    this.localReaderPages = this.mergeAdjacentChapterPages(pages, adjacentChapter);
    // 页表重排后当前页下标会漂，按页身份重新定位一次；找不到才退回原下标。
    const rebased = rebasePageIndex(this.localReaderPages, currentPageChapter, currentPageChapterIndex);
    if (rebased >= 0 && rebased !== this.currentPageIndex) { this.currentPageIndex = rebased; }
    this.deliveredAdjacentChapter = adjacentChapter;
    this.readerCanvasRenderer.clearParagraphs();
    this.paintReaderCanvas();
    console.info(`[ReaderBench] adjacentPaginated chapter=${adjacentChapter} ` +
      `pages=${pages.length} ms=${Date.now() - startedAt} title=[${adjacentTitle}]`);
  }

  /** 当前页的章内页号（0 起），用于页码显示与进度条；窗口表未就绪时退回页表下标。 */
  private currentChapterPageIndex(): number {
    return this.currentChapterPosition()?.pageIndex ?? this.currentPageIndex;
  }

  /** 本章页数，用于页码分母；窗口表未就绪时退回页表长度。 */
  private currentChapterPageCount(): number {
    return this.currentChapterPosition()?.pageCount ?? this.localReaderPages.length;
  }

  private rebuildReaderPages(forceProgressCommit: boolean = false,
    onlyImageSizesChanged: boolean = false): void {
    const startedAt = Date.now();
    // P3-E：在线书 isLocal=false，但同样要走画布排版；这里只看视口是否就绪，
    // 不再以 isLocal 拒绝（原移植把 isLocal 当成「能否排版」，上游并无此约束）。
    if (this.readerContentWidth <= 0 || this.viewportHeight <= 0) {
      // KI-REL1：换章交接期间不清空页表。上游任何时刻都有 pages.current
      // （`ReaderCanvasSurface.kt:254` 的 `pages.current ?: return` 只是「没有就不画」），
      // 本地若在这里清空，视口一时为 0 就会让画布整屏空白——那正是闪烁。
      // 保留上一章的页当过渡帧，等视口就绪后这次重排会重跑并整表替换。
      if (!this.chapterHandoffPending) {
        // 页层批次 4：整窗清空——`localReaderPages` 是跨章窗口表，
        // 换书 / 非交接的早返回要把邻章缓存页一并丢弃，并把页表内下标归位，
        // 否则旧下标会落在新页表之外的空位上。
        this.localReaderPages = [];
        this.currentPageIndex = 0;
        this.readerBottomJustifyGap = 0;
      }
      // 视口还没就绪就早退，这帧不排页；交接进行中余量要留到下一次重排消费。
      if (!this.chapterBoundaryContinuation) { this.pendingChapterScrollVp = 0; }
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
    const semanticsStartedAt = Date.now();
    const reuseSemantic = onlyImageSizesChanged && this.localSemanticDocument.paragraphs.length > 0;
    const document = reuseSemantic
      ? this.localSemanticDocument
      : LocalTextSemantics.parse(this.content, this.paragraphIndent, this.adaptSpecialStyle);
    if (!reuseSemantic) {
      this.localSemanticContent = document.content;
      const nextRanges = ReaderHighlightRuleEngine.findBodyRanges(
        document.content, this.readerHighlightRules, this.currentConfigName);
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
    const singleImageStyle = this.effectiveImageStyle() === 'SINGLE';
    // 页层批次 4：正文标题块必须走 `resolvePaginationTitle`，与邻章预排同一口径。
    //
    // 之前这里吃默认参数 `displayChapterTitle`：换章时 `content` 先到、标题是异步
    // `ReplaceRuleRepository.applyTitle` 之后才赋值，于是第一次重排用的是**上一章的
    // 标题**，第二次重排才换成新标题。而邻章预排用的是章节缓存里的真标题。
    // 两边标题不同 → 标题块宽度/行数不同 → 页数不同（实测第 3 章预排 6 页、真页 7 页），
    // 页表整表替换时正文整体错位，用户看到的跨章那一下「跳」就是它。
    const titleBlock = this.buildReaderTitleBlock(context, width, lineHeight,
      document.content.length, singleImageStyle, this.resolvePaginationTitle(this.getChapterIndex()));
    // 批5：已排章的内存快照。只缓存最贵的 paginate 产物，语义解析/高亮/定位/绘制
    // 副作用全部照常走——任务书骨架里在复用分支调 onReaderContentChanged() 会递归
    // 触发本方法，故不采用那条路径。布局键排除单调递增的 revision，换回同章才能命中。
    // 图片尺寸参与排版（未到齐时用行高占位），编进键避免占位页被当成最终页复用。
    const imageSizeKey = Array.from(paginationImageSizes.entries())
      .map((entry: [string, ReaderIntrinsicImageSize]) =>
        `${entry[0]}:${entry[1].width}x${entry[1].height}`).sort().join(',');
    const paginationCacheKey = ReaderChapterPageCache.key(
      this.book.contentPath ?? '', this.getChapterIndex(),
      this.getPaginationLayoutKey(0) + '|imgs=' + imageSizeKey +
      '|body=' + this.contentFingerprint(this.content));
    const cachedPages = ReaderChapterPageCache.get(paginationCacheKey);
    const paginateStartedAt = Date.now();
    // 流式分页（#1013）：只在「没有缓存页」且「正文够长」时走。短章同步排完比起一轮
    // 异步更快（8000 字约 16 页，是同步排开始肉眼可见的门槛）；缓存命中时本来就不用排。
    if (cachedPages === undefined && this.content.length > 8000) {
      this.startReaderPaginationStreaming(document, width, pageHeight, lineHeight, paragraphSpacing,
        fontSize, paginationImageSizes, titleBlock, paginationCacheKey, onlyImageSizesChanged,
        forceProgressCommit);
      return;
    }
    const paginatedPages = cachedPages ?? LocalReaderPaginator.paginate(
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
      this.effectiveImageStyle(),
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
      this.getChapterIndex(),
      this.textBottomJustify,
      this.usesCanvasScroll()
    );
    const positionStartedAt = this.applyReaderPages(paginatedPages, cachedPages,
      paginationCacheKey, onlyImageSizesChanged, pageHeight, lineHeight);
    // 批 1 计时：只取时间戳 + 打日志，不改任何分支。positionMs 含定位/钳位/预解图/重绘，
    // 正是要观察的渲染开销。任务模板的 paginateMs 实为「语义解析段」，故另补 paginatorMs
    // 标出真正的 LocalReaderPaginator.paginate 耗时，便于判定最大项。
    console.info(`[ReaderBench] rebuild semanticsMs=${semanticsStartedAt - startedAt} ` +
      `paginateMs=${paginateStartedAt - semanticsStartedAt} ` +
      `positionMs=${Date.now() - paginateStartedAt} ` +
      `pages=${this.localReaderPages.length} onlyImages=${onlyImageSizesChanged} ` +
      `reuseSemantic=${reuseSemantic} paginatorMs=${positionStartedAt - paginateStartedAt} ` +
      `renderMs=${Date.now() - positionStartedAt} ` +
      `title=[${this.resolvePaginationTitle(this.getChapterIndex())}] ` +
      `contentLen=${document.content.length} chPages=${this.currentChapterPageCount()}`);
    this.finishReaderPagination(forceProgressCommit);
  }

  /**
   * 把已排好的整章页装进阅读页（#1013 从 `rebuildReaderPages` 原样抽出）。
   *
   * 抽出来的唯一目的是让流式分页（`startReaderPaginationStreaming`）在整章排完后
   * 复用同一段落位逻辑——同步路径与流式路径的落点必须一模一样，抄第二份必然走偏。
   * 段内代码逐字节搬运，只把 `paginatedPages` / `cachedPages` / `paginationCacheKey` /
   * `onlyImageSizesChanged` / `pageHeight` / `lineHeight` 改成形参。
   *
   * @returns 定位段的起始时间戳，供调用方的 `[ReaderBench]` 计时日志续算。
   */
  private applyReaderPages(paginatedPages: LocalReaderPage[],
    cachedPages: LocalReaderPage[] | undefined, paginationCacheKey: string,
    onlyImageSizesChanged: boolean, pageHeight: number, lineHeight: number): number {
    const context = this.getUIContext();
    const nextPages: LocalReaderPage[] = [];
    for (let pageIndex = 0; pageIndex < paginatedPages.length; pageIndex++) {
      const page = paginatedPages[pageIndex];
      if (page !== undefined) { nextPages.push(page); }
    }
    // 批5：本章页表排好后留一份内存快照（最多 3 章），换回同章且布局键未变时直接复用。
    if (cachedPages === undefined && nextPages.length > 0) {
      ReaderChapterPageCache.put(paginationCacheKey, nextPages);
    }
    // 页层批次 4：拼跨章窗口页表（当前章 ±1 章 + 当前章新排页），
    // 邻章页来自换章时保留的旧页；后续定位一律在窗口表上按页身份查下标。
    const chapterIndex = this.getChapterIndex();
    const mergedPages = this.mergeChapterPages(nextPages, chapterIndex);
    // 页层批次 4：还没排出来的那一侧补一张占位页进页表，让手指不抬也能滚过去。
    this.insertBoundaryPlaceholders(mergedPages, chapterIndex);
    const positionStartedAt = Date.now();
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
    // 阅读位置 0% 落本章第一页——单图模式下第一页是标题页，
    // 不能被 startPosition 比较跳过（标题页与正文首页的 startPosition 都是 0）。
    // 页层批次 4：滚动模式下「重排不能动阅读位置」。
    //
    // 滚动模式的权威位置是 `currentPageIndex + scrollOffset`（每帧由手势直接改），
    // 而下面按 `book.androidCharacterPosition` 的定位走的是**宿主回传的进度**，
    // 那条链路有 250ms 节流（`updateProgress`），天然比手势滞后。只要滚动途中发生
    // 一次重排（图片尺寸异步到达、`displayChapterTitle` 定稿、正文区尺寸变化都会触发），
    // 就会拿几百毫秒前的旧字符坐标把画面拽回上一页——用户看到的就是「页码在一张
    // 之内来回跳几次才真正翻过去」。
    //
    // 所以滚动模式在没有外部跳转意图时一律按页身份保持当前页；一旦有书签跳转、
    // 章首待处理、换章交接，仍走下面那套按目标位置的定位。
    const previousPage = this.localReaderPages[this.currentPageIndex];
    // 滚动驱动换章：位置已经由 `currentPageIndex` 表达（用户就是这么滚进来的），
    // 重建后必须按页身份接回同一页，否则会落回新章首页，视觉上倒跳。
    // 标记存章号：从「滚进邻章页」到「宿主把该章正文送到」之间可能还夹着几次
    // 仍是旧章的重建，那几次也必须按页身份守住位置，不能把下标拽回旧章。
    const previousPageChapter = previousPage?.chapterIndex ?? 0;
    // 外部跳转意图（书签跳转、章首待处理）拥有位置决定权，滚动驱动标记让位。
    // 标记**不在正文送达后立刻清**：换章之后还会夹着若干次重排（图片尺寸到达、
    // 正文区尺寸变化），那几次也必须守住位置，否则每一次都会按宿主回传的整章
    // 百分比把画面拽回去——设备上的「回跳」就是这么来的。真正的清零点有三个：
    // 换书（`onBookChanged`）、滚进别的一章（下面按章号改写）、外部跳转意图（这里）。
    if (this.scrollDrivenHandoffChapter >= 0 &&
      (this.pendingBookmarkTargetPosition >= 0 || this.startPositionPending)) {
      this.scrollDrivenHandoffChapter = -1;
    }
    const scrollDrivenHandoff = this.usesCanvasScroll() && this.scrollDrivenHandoffChapter >= 0 &&
      previousPage !== undefined && previousPageChapter === this.scrollDrivenHandoffChapter;
    const keepScrollPosition = this.usesCanvasScroll() &&
      this.pendingBookmarkTargetPosition < 0 && !this.startPositionPending &&
      previousPage !== undefined &&
      (scrollDrivenHandoff ||
        (previousPageChapter === chapterIndex &&
          !this.chapterHandoffPending && !this.chapterBoundaryContinuation));
    let pageIndex = keepScrollPosition
      ? rebasePageIndex(mergedPages, previousPage?.chapterIndex ?? 0, previousPage?.pageIndex ?? 0)
      : -1;
    if (pageIndex < 0) {
      pageIndex = locateChapterPage(mergedPages, chapterIndex, 0);
      if (targetPosition > 0) {
        const located = locateOrNull(mergedPages, chapterIndex, targetPosition);
        if (located >= 0) { pageIndex = located; }
      }
    }
    // 页表插入 / 删除 / 换章后旧下标失效：定位没命中时按旧页身份重查一次
    // （`rebasePageIndex`，`ReaderPageNavigator.kt:32-33`），仍找不到才落章首。
    if (pageIndex < 0) {
      const rebased = previousPage === undefined ? -1
        : rebasePageIndex(mergedPages, previousPage.chapterIndex ?? 0, previousPage.pageIndex ?? 0);
      pageIndex = rebased >= 0 ? rebased : 0;
    }
    // KI-REL1：向上翻章时落到新章最后一页，与上游「往回翻落章末」一致
    // （ReadBookController.kt:1387-1389 注释：往回翻时邻章排好的页直接接上）。
    // `locateChapterPage` 内部 coerceIn，传窗口表长度即钳到本章末页。
    const isChapterHandoff = this.chapterHandoffPending;
    if (this.chapterHandoffUpward && this.pendingBookmarkTargetPosition < 0 && !this.startPositionPending) {
      const last = locateChapterPage(mergedPages, chapterIndex, mergedPages.length);
      if (last >= 0) { pageIndex = last; }
    }
    this.chapterHandoffUpward = false;
    this.chapterHandoffPending = false;
    this.localReaderPages = mergedPages;
    this.currentPageIndex = pageIndex;
    // KI-REL1：换章后滚动偏移归零。连续滚动的偏移是「当前页之前的页高之和 + 页内偏移」，
    // 页表换了之后旧偏移对新章没有意义，不清掉新章一开篇就停在中间。
    // 但滚动到章界触发的交接是例外：越界那点余量本来就是「该往新章推多远」，
    // 归零等于把手指还没抬起的位移丢掉，用户就得松手重滑（对齐上游直接续写 scrollOffset）。
    if (!this.usesCanvasScroll()) {
      this.scrollOffset = 0;
    } else if (scrollDrivenHandoff) {
      // 滚动驱动换章：`currentPageIndex` 已经指到邻章那一页，`scrollOffset` 也是
      // 相对那一页顶边的真实位移，两者一起构成用户看到的位置。这里**什么都不动**，
      // 重建后画面就停在原处——这是「首尾相连」的关键。
      console.info(`[ReaderBench] scrollDriven land pageIdx=${this.currentPageIndex} ` +
        `scrollOffset=${this.scrollOffset}`);
    } else if (isChapterHandoff || this.chapterBoundaryContinuation) {
      // 落点是新章某页，余量必须钳在「这一页自己能滚的范围」内。快速甩动时
      // 一帧的 delta 可能比整页还高，不钳就会滚过页底露出空白（此时页表里没有
      // 下一页可接，因为 localReaderPages 只装本章）。
      const landingPage = this.localReaderPages[this.currentPageIndex];
      if (landingPage !== undefined) {
        const landingRequest = this.buildReaderCanvasRequest(new ReaderTransitionTransforms());
        const landingExtent = this.readerCanvasRenderer.pageScrollExtent(
          landingPage, this.currentPageIndex, landingRequest);
        // pageScrollExtent 按 layout.vpScale 算的是 px，余量存的是 vp；
        // 不换算就把 px 当 vp 钳会让钳位形同虚设，快速甩动时越过页底露白。
        const landingExtentVp = context.px2vp(landingExtent);
        this.scrollOffset = Math.max(-landingExtentVp, Math.min(0, this.pendingChapterScrollVp));
      }
      console.info(`[ReaderBench] handoff landed scrollOffset=${this.scrollOffset} pending=${this.pendingChapterScrollVp}`);
    }
    this.pendingChapterScrollVp = 0;
    this.chapterBoundaryContinuation = false;
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
    // 页层批次 4：本章页表已就位，看看邻章页齐不齐；缺哪侧就向宿主开口要一章。
    // 放在 paintReaderCanvas 之后：预读是纯副作用，不能挡住本帧的重绘。
    this.prefetchAdjacentChapters();
    return positionStartedAt;
  }

  /**
   * 排版收尾：进度上报、整书页数请求、书签目标消费（#1013 从 `rebuildReaderPages` 抽出）。
   *
   * 同步路径与流式路径都要跑这一步，抽出来避免两条路径的收尾动作分叉。
   */
  private finishReaderPagination(forceProgressCommit: boolean): void {
    // 书签目标必须在清空之前取：清空后再判就永远是「没消费过」。
    const consumedBookmarkTarget = this.pendingBookmarkTargetPosition >= 0;
    this.pendingBookmarkTargetPosition = -1;
    if (this.effectivePageAnim() !== 3 && forceProgressCommit) {
      this.reportReaderPageProgress();
    } else {
      this.syncProgressIndexFromPosition();
    }
    this.requestFullBookPagination();
    if (consumedBookmarkTarget) { this.onBookmarkTargetConsumed(); }
  }

  /**
   * 流式分页外壳（#1013 / #1015）：起一轮异步排版，每排出一页就刷新页表。
   *
   * 三条不变量：
   * ① `rebuildReaderPages` 保持同步（全文 20 处同步调用），本方法立刻返回，
   *    本帧仍显示上一轮页表；
   * ② 令牌 `paginationStreamToken` 保证换章/重排时旧轮次自己停下，不残留旧页；
   * ③ 流式失败（`shouldAbort` 之外的真异常）退回同步重排一次，不把整章留空。
   *
   * #1015：滚动模式下当前页由 `currentPageIndex + scrollOffset` 决定，页表变长不影响
   * 当前帧，逐页重绘纯属浪费——每 4 页刷一次即可；翻页模式每页都要看见，必须逐页刷。
   * 上游 `ReaderPartialPagePolicy.kt:27-42 shouldPublishPage` 服务的是「窗口是不可变快照、
   * 何时换窗」，本地 onPage 本来就是每页到就刷，照搬那套判据只会刷得更少、首屏更慢。
   */
  private startReaderPaginationStreaming(document: LocalSemanticDocument, width: number,
    pageHeight: number, lineHeight: number, paragraphSpacing: number, fontSize: number,
    imageSizes: Map<string, ReaderIntrinsicImageSize>,
    titleBlock: LocalReaderTitleBlock | undefined, paginationCacheKey: string,
    onlyImageSizesChanged: boolean, forceProgressCommit: boolean): void {
    const token = ++this.paginationStreamToken;
    this.paginationStreaming = true;
    const context = this.getUIContext();
    const streamed: LocalReaderPage[] = [];
    let paintedCount = 0;
    const publish = (page: LocalReaderPage): void => {
      if (this.paginationStreamToken !== token) { return; }
      streamed.push(page);
      this.localReaderPages = streamed.slice();
      if (this.usesCanvasScroll()) {
        // 滚动模式：每 4 页刷一次，前 4 页逐页刷（首屏要尽快看见字）。
        if (streamed.length <= 4 || streamed.length - paintedCount >= 4) {
          paintedCount = streamed.length;
          this.paintReaderCanvas();
        }
        return;
      }
      this.paintReaderCanvas();
    };
    void LocalReaderPaginator.paginateStreaming(
      document, width, pageHeight, lineHeight, paragraphSpacing,
      (value: string): number => {
        return ReaderFontRepository.measureTextWidthForPagination(
          context, value, this.readerBodyFontFamily, fontSize, this.getReaderFontWeight()) +
          this.getReaderTextLetterSpacingWidth(value, fontSize);
      },
      imageSizes,
      this.effectiveImageStyle(),
      context.px2vp(80),
      (ReaderFontRepository.measureTextWidth(context, '袮', this.readerBodyFontFamily, fontSize) +
        this.getReaderLetterSpacingVp(fontSize)),
      // 标题已进流，首屏不再预留任何行。
      0,
      publish,
      (): boolean => this.paginationStreamToken !== token,
      this.textFullJustify,
      this.resolveReaderColumnCount(),
      this.readerSizeOffsets,
      titleBlock,
      this.buildReaderTextLayoutStyle(fontSize),
      this.getChapterIndex(),
      this.textBottomJustify,
      this.usesCanvasScroll()
    ).then((pages: LocalReaderPage[]): void => {
      if (this.paginationStreamToken !== token) { return; }
      this.paginationStreaming = false;
      const positionStartedAt = this.applyReaderPages(pages, undefined,
        paginationCacheKey, onlyImageSizesChanged, pageHeight, lineHeight);
      console.info(`[ReaderBench] streaming pages=${pages.length} ` +
        `renderMs=${Date.now() - positionStartedAt} contentLen=${document.content.length} ` +
        `chPages=${this.currentChapterPageCount()}`);
      this.finishReaderPagination(forceProgressCommit);
    }).catch((error: Error): void => {
      if (this.paginationStreamToken !== token) { return; }
      this.paginationStreaming = false;
      AppLog.put(`流式分页失败，退回同步：${error.message}`);
      console.error(`[ReaderBench] streaming failed: ${error.message}`);
      this.rebuildReaderPages(forceProgressCommit);
    });
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

  /**
   * 批4：朗读段切换时把当前段首字位置翻到可见页，并回写阅读进度。
   * 上游 ReadBookController.bodyParagraphAt + upTextChapterAloudSpan 的同源实现：
   * 段首语义坐标 → 本章内页号 → currentPageIndex / scrollOffset → 进度写库。
   * 只在 start>=0 时跟随；stop 上报 start<0 时只重绘清高亮，不挪动页面。
   */
  private onReadAloudSpanChanged(): void {
    if (!this.usesReaderCanvas()) {
      this.invalidateReaderCanvas();
      return;
    }
    const span = this.readAloudSpan;
    if (span.start >= 0 && this.localReaderPages.length > 0) {
      const chapterIndex = this.getChapterIndex();
      const chapterPages: number[] = [];
      for (let i = 0; i < this.localReaderPages.length; i++) {
        const pg = this.localReaderPages[i];
        if (pg !== undefined && (pg.chapterIndex ?? 0) === chapterIndex) { chapterPages.push(i); }
      }
      // 严格对齐上游 findReadAloudPageIndex（BaseReadAloudService.kt:2137-2149）：
      // 只要朗读位置超过下一章内页的 pageStart 就往后翻；pageStart 排除标题坐标。
      const chapterOrdinal = this.findReadAloudPageOrdinal(span.start, chapterPages);
      // 对齐上游：高亮按段逐句走（只着色），可见页只在「跨页」时跳到目标页页首，
      // 页内不做连续滚动（BaseReadAloudService.moveToReadAloudPage / syncReaderToPlaybackPage）。
      const target = locateChapterPage(this.localReaderPages, chapterIndex, chapterOrdinal);
      if (target >= 0 && target !== this.currentPageIndex) {
        if (this.usesCanvasScroll()) {
          this.seekReaderScrollAbsolute(this.chapterPageStartVp(chapterOrdinal));
        } else {
          this.currentPageIndex = target;
        }
      }
      // 位置回写：段首语义坐标 → 源字符坐标 → 百分比 → 宿主落库。
      const renderPos = Math.max(0, Math.min(this.localSemanticContent.length, span.start));
      const sourcePos = LocalTextSemantics.toSourcePosition(this.localSemanticDocument, renderPos);
      const progress = this.localSemanticDocument.sourceLength > 0
        ? sourcePos / this.localSemanticDocument.sourceLength * 100 : 0;
      this.readerProgress = progress;
      this.lastReportedProgress = Math.round(progress);
      this.emitReaderProgress(progress, sourcePos, true);
    }
    this.invalidateReaderCanvas();
  }

  /** 进度环百分比：当前段首坐标 / 本章正文长度（与段高亮同一语义坐标口径）。 */
  private currentAloudProgress(): number {
    const total = this.localSemanticContent.length;
    if (total <= 0 || this.readAloudSpan.start < 0) { return 0; }
    return Math.max(0, Math.min(100,
      Math.round(this.readAloudSpan.start / total * 100)));
  }

  // ---- 批6：朗读胶囊 helpers（上游 ReadAloudCapsule.kt / CapsulePosition.kt） ----
  /** 胶囊是否处于暂停态：上游 isPaused 决定封面是否旋转、播放暂停图标方向。 */
  private capsulePaused(): boolean {
    return this.capsuleAloudState !== 1;
  }

  /** 按上游 tween(320) 连续展开/折叠；仅展开态重新起自动收起计时。 */
  private setCapsuleCollapsed(collapsed: boolean): void {
    const target = collapsed ? this.capsuleWidthCollapsed : this.capsuleWidthExpanded;
    this.getUIContext().animateTo({ duration: 320, curve: Curve.EaseInOut }, () => {
      this.capsuleWidthAnim = target;
      this.capsuleCollapsed = collapsed;
    });
    if (!collapsed) { this.resetCapsuleCollapseTimer(); }
  }

  /** 进入播放态展开胶囊并起 3 秒自动收起计时；停止时清计时并复位（上游 ReadAloudCapsule.kt:189-195）。 */
  private onCapsuleActiveChanged(): void {
    // 上游 collapsed 初值由保存位置决定（贴边即折叠），进入播放态不强制展开。
    this.syncCapsuleCoverRotation();
    if (this.readAloudActive && !this.capsuleCollapsed) {
      this.resetCapsuleCollapseTimer();
    } else if (this.capsuleCollapseTimer >= 0) {
      clearTimeout(this.capsuleCollapseTimer);
      this.capsuleCollapseTimer = -1;
    }
  }

  /** 播放状态变化：控制封面旋转（暂停停转）与自动收起计时。 */
  private onCapsuleAloudStateChanged(): void {
    this.syncCapsuleCoverRotation();
    if (!this.readAloudActive || this.capsulePaused()) { return; }
    this.resetCapsuleCollapseTimer();
  }

  /** 上游封面播放时 20 秒转一圈（coverRotation:141-149），暂停即停。 */
  private syncCapsuleCoverRotation(): void {
    if (this.capsuleCoverTimer >= 0) {
      clearInterval(this.capsuleCoverTimer);
      this.capsuleCoverTimer = -1;
    }
    if (!this.readAloudActive || this.capsuleAloudState !== 1) { return; }
    this.capsuleCoverTimer = setInterval(() => {
      this.capsuleCoverAngle = (this.capsuleCoverAngle + 3) % 360;
    }, 100);
  }

  /** 封面点击（上游 :310-313）：折叠/半展开时先展开，完全展开时打开听书界面 player。 */
  private onCapsuleCoverClick(): void {
    if (this.capsuleCollapsed) {
      this.setCapsuleCollapsed(false);
    } else {
      this.onCapsuleOpenPlayer();
    }
    this.resetCapsuleCollapseTimer();
  }

  /** 任何触摸重置自动收起计时；仅在播放中 + 开关开 + 当前展开时重新计时。 */
  private resetCapsuleCollapseTimer(): void {
    if (this.capsuleCollapseTimer >= 0) {
      clearTimeout(this.capsuleCollapseTimer);
      this.capsuleCollapseTimer = -1;
    }
    if (this.readAloudActive && this.readAloudCapsuleSettings.capsuleAutoCollapse && !this.capsuleCollapsed) {
      this.capsuleCollapseTimer = setTimeout(() => {
        this.setCapsuleCollapsed(true);
        this.capsuleCollapseTimer = -1;
      }, 3000);
    }
  }

  private onCapsuleSettingsChanged(): void {
    this.syncCapsulePositionFromSettings();
  }

  /**
   * 上游 CapsulePosition.kt:5-6 明确：偏好存的是相对屏幕底部中央的中心偏移（vp），
   * 不是左上坐标。默认 0,0 → 胶囊中心落在屏幕中央、距底 72vp（上游 CapsuleDefaultCenterFromBottomDp）。
   */
  private syncCapsulePositionFromSettings(): void {
    if (this.readerContentWidth <= 0 || this.viewportHeight <= 0) { return; }
    this.capsuleX = this.readerContentWidth / 2 + this.readAloudCapsuleSettings.capsuleOffsetX;
    this.capsuleY = this.viewportHeight - this.capsuleCenterFromBottom
      - this.readAloudCapsuleSettings.capsuleOffsetY;
    // 上游 collapsed 初值（ReadAloudCapsule.kt:166）：保存位置贴左右边缘则初始即折叠。
    const edge = this.readerContentWidth / 2;
    this.capsuleCollapsed = edge > 0 &&
      (this.readAloudCapsuleSettings.capsuleOffsetX <= -edge + 0.5 ||
       this.readAloudCapsuleSettings.capsuleOffsetX >= edge - 0.5);
    this.capsuleWidthAnim = this.capsuleCollapsed
      ? this.capsuleWidthCollapsed : this.capsuleWidthExpanded;
    this.capsulePosInitialized = true;
  }

  /** 阅读区尺寸到位后首次换算位置（aboutToAppear 时还没有尺寸）。 */
  private onCapsuleViewportChanged(): void {
    if (!this.capsulePosInitialized) { this.syncCapsulePositionFromSettings(); }
  }

  /** 胶囊是否可见：播放中 + 设置开启。 */
  private capsuleVisible(): boolean {
    return this.readAloudActive && this.readAloudCapsuleSettings.showReadAloudCapsule;
  }

  /** 位置钳位：限制在视口内，否则拖出屏幕就再也找不回来（本地必须多写）。 */
  private clampCapsule(x: number, y: number): void {
    const halfW = this.capsuleCurrentWidth() / 2;
    const halfH = this.capsuleHeight / 2;
    this.capsuleX = Math.max(halfW, Math.min(x, this.readerContentWidth - halfW));
    this.capsuleY = Math.max(halfH, Math.min(y, this.viewportHeight - halfH));
  }

  /** 胶囊当前宽度：展开态揭示按钮，折叠态只剩封面。 */
  private capsuleCurrentWidth(): number {
    return this.capsuleCollapsed ? this.capsuleWidthCollapsed : this.capsuleWidthExpanded;
  }

  /**
   * 上游 capsulePresentationOffsetX（CapsulePosition.kt:42-52）：展开时中心连续让位，
   * 保证完整胶囊不出屏。本地按当前渲染宽度把中心再钳位一次（不改存储的 capsuleX）。
   */
  private capsuleRenderX(): number {
    const half = this.capsuleWidthAnim / 2;
    const w = this.readerContentWidth > 0 ? this.readerContentWidth : half * 2;
    return Math.max(half, Math.min(this.capsuleX, w - half));
  }

  /** 松手存偏好：把钳位后的坐标写回仓库（capsuleOffsetX/Y）。 */
  private persistCapsulePosition(): void {
    const context = this.getUIContext().getHostContext();
    if (context === undefined) { return; }
    const updated: ReadAloudSettingsSnapshot =
      copyReadAloudSettings(this.readAloudCapsuleSettings);
    // 反弹回上游坐标语义：相对底部中央的中心偏移。
    // 边缘吸附时 capsuleX 被设为视口边界（0 或屏宽），要还原成 ±edge 供 dockSide 判定，
    // 而不是 (0 - W/2) 直接存。
    const halfW: number = this.readerContentWidth / 2;
    if (this.capsuleX <= 0) {
      updated.capsuleOffsetX = -halfW;
    } else if (this.capsuleX >= this.readerContentWidth) {
      updated.capsuleOffsetX = halfW;
    } else {
      updated.capsuleOffsetX = this.capsuleX - halfW;
    }
    updated.capsuleOffsetY = this.viewportHeight - this.capsuleCenterFromBottom - this.capsuleY;
    ReadAloudSettingsRepository.save(context, updated);
  }

  private reportReaderPageProgress(): void {
    const page = this.localReaderPages[this.currentPageIndex];
    if (page === undefined) { return; }
    this.resolveStartPosition();
    this.syncProgressIndexFromPosition();
    const renderPosition = Math.max(0, Math.min(this.localSemanticContent.length, page.startPosition));
    const position = LocalTextSemantics.toSourcePosition(this.localSemanticDocument, renderPosition);
    const progress = this.localSemanticDocument.sourceLength > 0
      ? position / this.localSemanticDocument.sourceLength * 100 : 0;
    this.readerProgress = progress;
    this.lastReportedProgress = Math.round(progress);
    this.emitReaderProgress(progress, position, true);
  }

  private emitReaderProgress(progress: number, chapterPosition: number, androidCoordinate: boolean): void {
    // 滚动模式跨章后，可见页可能已经落在邻章（手指滚过去的），而 `book.chapterIndex`
    // 要等换章请求往返才更新。进度几何（`readerScrollContentHeight` /
    // `readerScrollAbsoluteOffset`）一律按**当前页所属章**算，这里报的章号必须同口径，
    // 否则宿主会把「下一章的百分比」记到上一章上。
    // 宿主那侧有章号闸门（`acceptReaderProgress` 发现章号不符就丢弃），
    // 短暂的不一致只会丢一帧进度，不会写坏数据。
    const pageChapter = this.usesCanvasScroll()
      ? (this.currentChapterPosition()?.chapterIndex ?? this.getChapterIndex())
      : this.getChapterIndex();
    this.onProgressChange(this.book.id, pageChapter, progress, chapterPosition, androidCoordinate);
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
    if (this.effectivePageAnim() === 3) { return false; }
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
    states.push(`第 ${this.currentChapterPageIndex() + 1} 页，共 ${this.currentChapterPageCount()} 页`);
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
    if (!this.swipeToAddBookmark || !this.book.isLocal || this.effectivePageAnim() === 3 ||
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
    // 页层批次 4：滚动越界的「有上/下一页」按**页表**判断，不是按本章。
    //
    // 章末端口按本章算的话，章末那一下 `hasNext` 恒为 false，`apply` 只会返回
    // `hitBoundary`、永远不会返回 crossing NEXT —— 下面那段「章末把越界位移记进
    // `pendingChapterScrollVp`」就成了死代码，换章位移必然丢失（c33d815 修的问题
    // 被回退）。页表跨章之后，章末的下一页就是邻章页（真页或占位页），
    // crossing 能正常触达章末分支，位移带着走。
    //
    // `apply` 里 `!hasNext` 的「章末不够一屏钳回」分支随之不再触发：
    // 章末之后有占位页承接，钳位由章末分支的 `scrollOffset = overshootVp` 接管。
    const hasPreviousPage = this.currentPageIndex > 0;
    const hasNextPage = this.currentPageIndex + 1 < pages.length;
    const result: ReaderScrollResult = ReaderScrollPolicy.apply(
      context.vp2px(this.scrollOffset), deltaPx, previousExtentPx, currentExtentPx,
      viewportExtentPx, hasPreviousPage, hasNextPage);
    if (result.crossing === ReaderScrollCrossing.NEXT) {
      // 页层批次 4 修正（2026-11-10）：**页表里有下一页就推进过去，不再按「本章
      // 是否还有页」判章末**。
      //
      // 旧写法用 `position.pageIndex + 1 >= position.pageCount` 判章末：窗口页表
      // 跨章之后，本章末页的下一页明明是邻章真页，这个条件却照样为真，于是走到
      // 下面那条「钳住 + 等异步换章」的分支——手指还在动、画面却钉在章末页不动，
      // 要等 `rebuildReaderPages` 整表重排才重新落点，用户看到的就是一次跳跃。
      // 那正是「不是首尾相连」的直接来源。
      //
      // 现在只有页表**真的没有下一页**（全书末页，或邻章还没预排到）才钳住；
      // 有下一页一律推进，跨到邻章页也照常推进，画面首尾相接。
      if (!hasNextPage) {
        // 页表里没有下一页：这里是真边界。把位移钳在「本页刚好滚出屏幕」之内，
        // 记进 `pendingChapterScrollVp` 供换章落点消费，再让调用方发换章请求。
        // 用 `result.offsetPx` 的 crossing 残差不行——残差越过即归零，画面会被
        // 拽回原页，所以用带上限的单调位移。
        const currentExtentVp = context.px2vp(currentExtentPx);
        const rawOffsetVp = this.scrollOffset + context.px2vp(deltaPx);
        const clampedOffsetVp = Math.max(-currentExtentVp, Math.min(0, rawOffsetVp));
        this.scrollOffset = clampedOffsetVp;
        this.pendingChapterScrollVp = clampedOffsetVp;
        this.chapterBoundaryContinuation = true;
        this.paintReaderCanvas();
        // 后面还有下一章才需要换章；全书末页就只是滚到头。
        return this.getChapterIndex() + 1 < this.getChapterCount();
      }
      // 推进到下一页：下标 +1 即视觉上的下一页（页表按 (chapterIndex, pageIndex) 升序）。
      this.currentPageIndex = this.currentPageIndex + 1;
      this.resetCanvasSelectionState();
      // 位移照常落到新页上（`result.offsetPx` 是相对新页顶边的残差）。
      this.scrollOffset = context.px2vp(result.offsetPx);
      this.paintReaderCanvas();
      // 滚进邻章的页：位置已经落在邻章正文上，但宿主 `book.chapterIndex` /
      // `content` 还停在旧章。这里只标记「这次换章是滚动驱动的」，让重建时
      // 按页身份保住位置（见 `rebuildReaderPages` 的 `scrollDrivenChapterHandoff`），
      // 再由调用方发 `onTurnChapterBoundary` 让正文跟上。位置一秒都不动。
      const landed = chapterPosition(pages, this.currentPageIndex);
      if (landed !== undefined && landed.chapterIndex !== this.getChapterIndex()) {
        this.scrollDrivenHandoffChapter = landed.chapterIndex;
        this.chapterBoundaryContinuation = true;
        return true;
      }
      return result.hitBoundary;
    } else if (result.crossing === ReaderScrollCrossing.PREVIOUS) {
      if (!hasPreviousPage) {
        // 章首：向上换章的镜像分支。
        // 与章末同一套：把「越过首页顶边多少」带进新章，否则落定后会跳回顶部。
        //
        // 位移口径同样换成带上下限的单调值：向上滚 `scrollOffset` 为正，
        // 上限是「上一张页刚好顶到屏幕顶」= `previousExtentVp`，下限 0。
        // 这样手指向上时上一张页（邻章真页或占位页）会真的从上面滑进来，
        // 而不是靠 crossing 残差把画面拽回去。
        //
        // 落点取舍：`pendingChapterScrollVp` 是正值，而落点钳位是
        // `Math.min(0, pendingChapterScrollVp)`，正向值会被抹成 0 —— 向上换章的
        // 落点本轮**不追求精确**，允许落在上一章末页顶部。这个取舍登记在
        // `docs/KNOWN-ISSUES.md`，不是漏做。
        const previousExtentVp = context.px2vp(previousExtentPx);
        const rawOffsetVp = this.scrollOffset + context.px2vp(deltaPx);
        const clampedOffsetVp = Math.max(0, Math.min(previousExtentVp, rawOffsetVp));
        this.scrollOffset = clampedOffsetVp;
        this.pendingChapterScrollVp = clampedOffsetVp;
        this.chapterBoundaryContinuation = true;
        this.paintReaderCanvas();
        return this.getChapterIndex() > 0;
      }
      // 推进到上一页（镜像）：跨进上一章的页同样只标记、不改阅读位置。
      this.currentPageIndex = this.currentPageIndex - 1;
      this.resetCanvasSelectionState();
      this.scrollOffset = context.px2vp(result.offsetPx);
      this.paintReaderCanvas();
      const landed = chapterPosition(pages, this.currentPageIndex);
      if (landed !== undefined && landed.chapterIndex !== this.getChapterIndex()) {
        this.scrollDrivenHandoffChapter = landed.chapterIndex;
        this.chapterBoundaryContinuation = true;
        return true;
      }
      return result.hitBoundary;
    }
    this.scrollOffset = context.px2vp(result.offsetPx);
    this.paintReaderCanvas();
    return result.hitBoundary;
  }

  /** 当前页还能不能往回翻（上游 `canTurnPrevious`：窗口有上一页或还有上一章）。 */
  private canTurnToPrevious(): boolean {
    return canTurnPrevious(this.localReaderPages, this.currentPageIndex, this.getChapterIndex() > 0);
  }

  /** 当前页还能不能往后翻（上游 `canTurnNext`：窗口有下一页或还有下一章）。 */
  private canTurnToNext(): boolean {
    return canTurnNext(this.localReaderPages, this.currentPageIndex,
      this.getChapterIndex() + 1 < this.getChapterCount());
  }

  /**
   * 横向拖动的逐帧更新（上游 `ReaderCanvasSurface.kt:1304-1330`）。
   *
   * 越过 touch-slop 时锁定方向并记下锁定点，之后位移都从锁定点算——
   * 上游注释：方向在 touch-slop 处捕获，可见位移从捕获点开始。
   * 折页模式另外写触点，让纸角跟着手指走。
   */
  private updateHorizontalPageDrag(event: GestureEvent): void {
    if (this.effectivePageAnim() === 5) { return; }
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
    const mode = readerTransitionModeFromPageAnim(this.effectivePageAnim());
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
    const mode = readerTransitionModeFromPageAnim(this.effectivePageAnim());
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
    // 页层批次 4：每次抬手惯性重置换章去重标记（防连跳的粒度是「一次惯性」）。
    this.scrollFlingBoundaryTurned = false;
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
      // 页层批次 4：命中章边界后**不结束惯性**。旧实现在这里 `cancelTurnAnimator()`
      // 直接掐掉动画，视觉上就是「甩到章末突然停住」，正是要修掉的那一半。
      // 现在惯性继续把位移喂给页表：章末之后是占位页或已排好的邻章页，
      // 能一直推到底，换章请求只发一次（`scrollFlingBoundaryTurned` 去重）。
      const hitBoundary = this.applyReaderScrollDelta(step);
      if (hitBoundary && !this.scrollFlingBoundaryTurned) {
        this.scrollFlingBoundaryTurned = true;
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
    // 页层批次 4：章内 ±1 页换算成窗口页表下标，章边界按 `chapterPosition` 判。
    const position = chapterPosition(this.localReaderPages, this.currentPageIndex);
    const localNext = position === undefined ? -1 : position.pageIndex + (isPrevious ? -1 : 1);
    if (position === undefined || localNext < 0 || localNext >= position.pageCount) {
      this.resetCanvasSelectionState();
      this.paintReaderCanvas();
      this.showChapterBoundaryMessage(isPrevious ? -1 : 1);
      this.onTurnChapterBoundary(isPrevious ? -1 : 1);
      return;
    }
    const nextPageIndex = locateChapterPage(this.localReaderPages, position.chapterIndex, localNext);
    this.currentPageIndex = nextPageIndex;
    this.resetCanvasSelectionState();
    this.reportReaderPageProgress();
    this.paintReaderCanvas();
  }

  private turnReaderPage(delta: number): void {
    if (this.pageTurnAnimating) { return; }    if (this.usesReaderCanvas() && this.localReaderPages.length === 0) { return; }
    if (this.usesCanvasScroll()) {
      this.turnReaderScrollPage(delta);
      return;
    }
    // 页层批次 4：`delta` 是章内翻页数，先按 `chapterPosition` 换算成章内页号，
    // 再 `locateChapterPage` 换回窗口页表下标；越出本章就交给换章回调。
    const position = chapterPosition(this.localReaderPages, this.currentPageIndex);
    const localNext = position === undefined ? -1 : position.pageIndex + delta;
    const nextPageIndex = position === undefined ? -1
      : locateChapterPage(this.localReaderPages, position.chapterIndex, localNext);
    this.resolveStartPosition();
    if (position === undefined || localNext < 0 || localNext >= position.pageCount || nextPageIndex < 0) {
      this.showChapterBoundaryMessage(delta);
      this.onTurnChapterBoundary(delta);
      return;
    }
    if (this.effectivePageAnim() === 5) {
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
    const mode = readerTransitionModeFromPageAnim(this.effectivePageAnim());
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
    // 不复位的话第二张图会继承上一张的缩放与位移，看着像坏了。
    this.imagePreviewScale = 1;
    this.imagePreviewOffsetX = 0;
    this.imagePreviewOffsetY = 0;
    this.imagePreviewBaseScale = 1;
    this.imagePreviewBaseOffsetX = 0;
    this.imagePreviewBaseOffsetY = 0;
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
    // 上游 ReadBookViewModel.kt:2162-2181 calculateSeekMax 只按 progressBarBehavior 分流，不按翻页动画。
    return this.progressBehavior === 'page' && this.localReaderPages.length > 0;
  }

  /**
   * 从当前位置重置滑块进度索引（页码档=章内页号，章节档=章号）。
   * 唯一的 sliderProgressIndex 重置入口，避免各调用点语义漂移。
   */
  private syncProgressIndexFromPosition(): void {
    const maximum = Math.max(0, this.getProgressSliderMaximum());
    const raw = this.isPageProgressMode() && this.localReaderPages.length > 0
      ? this.currentChapterPageIndex() : this.getChapterIndex();
    this.sliderProgressIndex = Math.max(0, Math.min(maximum, raw));
  }

  private getProgressSliderMaximum(): number {
    // 上游 ReadBookViewModel.kt:2172-2181 calculateSeekMax 不按滚动档固定刻度；
    // 页码档上限为本章页数-1，章节档为章节数-1。
    return this.isPageProgressMode() ? this.currentChapterPageCount() - 1 : this.getChapterCount() - 1;
  }

  private getChapterCount(): number {
    const realCount = this.realChapterCount();
    const simulated = this.simulatedChapterCount(realCount);
    return simulated !== undefined ? simulated : realCount;
  }

  /** 真实章节数：原有逻辑原样搬过来，行为不变。 */
  private realChapterCount(): number {
    const titles = BookRepository.cachedChapterTitles(this.book);
    if (titles.length > 0) {
      return titles.length;
    }
    const count = Number(this.book.chapterCount ?? '');
    return Number.isInteger(count) && count > 0 ? count : 1;
  }

  /**
   * 模拟追读下的可读章数。未开启时返回 undefined（调用方用真实章数）。
   * 上游 Book.simulatedTotalChapterNum()，见 help/book/BookExtensions.kt:709-731：
   *   chaptersToUnlock = max(0, startChapter + daysPassed * dailyChapters)
   *   result = min(totalChapterNum, chaptersToUnlock)
   * daysPassed = startDate.daysUntil(today) + 1，解析失败或未设置都回落到 1。
   */
  private simulatedChapterCount(realCount: number): number | undefined {
    if (this.book.readSimulating !== true) {
      return undefined;
    }
    const start = this.book.startDate;
    let daysPassed = 1;
    if (start !== undefined && start.length >= 10) {
      const parts = start.split('-');
      const year = Number(parts[0]);
      const month = Number(parts[1]);
      const day = Number(parts[2]);
      if (Number.isInteger(year) && Number.isInteger(month) && Number.isInteger(day)) {
        // 自己拆年月日再 Date.UTC：Date.parse('yyyy-MM-dd') 按 UTC 解析，
        // 与 Date.now() 的本地口径混用会跨时区偏一天。
        const startUtc = Date.UTC(year, month - 1, day);
        const now = new Date();
        const todayUtc = Date.UTC(now.getFullYear(), now.getMonth(), now.getDate());
        daysPassed = Math.max(1, Math.floor((todayUtc - startUtc) / 86400000) + 1);
      }
    }
    const startChapter = Math.max(0, this.book.startChapter ?? 0);
    const daily = Math.max(0, this.book.dailyChapters ?? 3);
    const unlock = Math.max(0, startChapter + daysPassed * daily);
    // realCount 必须是真实章数；追到最新就停在这里。
    return Math.min(realCount, unlock);
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
      // 上游 `ReadMenuActionDefs.kt:76` `MAX_TITLE_BAR_ACTIONS = 6`，`:493-517` 用 `take(6)`
      // 直接丢弃第 7 个及之后的动作（上游没有溢出菜单概念），这里按同一口径截断。
      // 顺序即配置顺序：上游 `ReadMenuActionDefs.kt:493-518` 是
      // `.filter { enabled }.mapNotNull { defs }.filter { applicable }.take(6)`，不反转。
      // 原先这里写了 `reverse()`，依据是「Row 中后插入靠左」——该前提在本页不成立：
      // `readerTopActionGroup()`（`:2875`）两个分支都用 `ForEach(this.getVisibleTopActions(), …)`
      // 正序渲染，第一个元素就是最左，反转只会把「更多」顶到最左。
      return actions.slice(0, ReaderPage.MAX_TITLE_BAR_ACTIONS);
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
    .width(this.readerTopBarButtonOuterSize()).height(this.readerTopBarButtonOuterSize())
    .margin({ left: this.readerTopBarMergeEnabled() ? 0 : 6 })
    .borderRadius(this.readerTopBarButtonOuterSize() / 2)
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
    // 上游 `ReadBookMenuBarTitle.kt:517-628` 的外层是 Row（weight 1 / height 40 /
    // padding horizontal 12）：左边 Column 装书名与章名，右边在有书源时接一个 24vp 宽的圆点热区。
    Row() {
      Column() {
        // 胶囊内书名恒 1 行：40vp 定高装不下两行，上游 `TitleCapsuleGlassLayout` 也是 `maxLines = 1`
        // （`ReadBookMenuBarTitle.kt:556`）。
        Text(this.book.title).fontSize(LABEL_LARGE).fontWeight(FontWeight.Medium).fontColor(this.readerMenuForeground()).maxLines(1)
          .width('100%').textOverflow({ overflow: TextOverflow.Ellipsis })
          .textShadow(this.readerMenuTextShadow())
        if (this.displayChapterTitle.length > 0) {
          Text(this.displayChapterTitle).fontSize(LABEL_SMALL).fontColor(this.readerMenuForegroundAlpha('B3')).maxLines(1)
            .width('100%').margin({ top: 2 }).textOverflow({ overflow: TextOverflow.Ellipsis })
            .textShadow(this.readerMenuTextShadow())
        }
      }
      .layoutWeight(1).alignItems(HorizontalAlign.Start)
      // 批10（:569）标题胶囊右端书源圆点：8vp 圆点 + 24vp 宽满高热区，对齐上游
      // `ReadBookMenuBarTitle.kt:596-628`（`Spacer(4.dp)` + `Box(width(24.dp).fillMaxHeight())`
      // 内套 `Box(size(8.dp), CircleShape)`）。没有书源（本地书、或源已被删）就不画，
      // 免得出现一个点了没反应的空圆点 —— 这是任务书验收第 13 条的硬要求。
      if (this.bookSourceName.length > 0) {
        Row().width(4)
        Stack({ alignContent: Alignment.Center }) {
          Circle().width(8).height(8).fill(this.readerMenuForeground())
        }
        .width(24).height('100%')
        .accessibilityText('书源')
        .onClick(() => this.onOpenSourceMenu())
      }
    }
    .layoutWeight(1).alignItems(VerticalAlign.Center)
    .padding({ left: 12, right: 12, top: 4, bottom: 4 })
    .borderRadius(20)
    .backgroundColor(this.readerTopBarButtonFillColor())
    .border(this.readerTitleCapsuleBorder())
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
    else if (kind === 'voice') { this.onToggleReadAloud(); }
    else if (kind === 'settings') { this.onOpenSettings(); }
    else if (kind === 'addBookmark') { this.addCurrentPageBookmark(); }
    else if (kind === 'theme') { this.onToggleNightMode(); }
    else if (kind === 'eye_protection') { this.onToggleEyeProtection(); }
    else if (kind === 'prev_chapter') { this.onTurnChapterBoundary(-1); }
    else if (kind === 'next_chapter') { this.onTurnChapterBoundary(1); }
    // 上游 `ReadMenuActionDefs.kt:443-449` 的 `replace` 与 `replace_badge` 是同一个面板，
    // 区别只在后者右上角多一枚「本章命中条数」角标。
    else if (kind === 'replace' || kind === 'replace_badge') { this.textProcessingVisible = true; }
    else if (kind === 'more_actions') { this.moreActionMenuId = ''; this.overflowVisible = true; }
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
    // 书源四项：本地 book.isLocal 恒 true（见 data/BookRepository.ets 导入链只做本地书），
    // 上游条件是 !isLocalBook 一类，写 !isLocal 与写 false 行为完全等价；
    // 直接写 false 并留这行注释，免得后来接书源的人以为「条件已经写好了，只是这本书没开」。
    if (id === 'source_login' || id === 'source_pay') { return false; }
    if (id === 'edit_source' || id === 'disable_source') { return false; }
    // AI 在范围之外，见 docs/PROJECT.md。
    if (id === 'ai_chat') { return false; }
    if (id === 'change_source' || id === 'refresh' || id === 'download') { return !this.book.isLocal; }
    if (id === 'toc_rule') { return this.book.isLocal && this.book.format === 'txt'; }
    if (id === 'charset') { return this.book.isLocal; }
    if (id === 'del_ruby' || id === 'del_h') { return this.book.isLocal && this.book.format === 'epub'; }
    // 上游条件是 inBookshelf && isReadingProgressSyncConfigured。本地 WebDAV 已落地（lib/WebDav.ets），
    // inBookshelf 也判得出，但进度同步的读写入口本批不做，放进格子就是个点不动的格。
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

  /** 显式设值版：配置行的开关走这个，不做取反（上游 ConfigListEntry 的 Switch 是设值语义）。 */
  private setMoreActionEnabled(id: string, enabled: boolean): void {
    this.draftMoreActions = this.draftMoreActions.map((item: ReaderMoreActionConfig): ReaderMoreActionConfig => ({
      id: item.id,
      enabled: item.id === id ? enabled : item.enabled
    }));
  }

  /** List.onMove 的回调：把第 from 项搬到 to 位（对应上游 ReorderableConfigList 的拖拽结果）。 */
  private moveMoreActionTo(from: number, to: number): void {
    if (from === to || from < 0 || to < 0
      || from >= this.draftMoreActions.length || to >= this.draftMoreActions.length) {
      return;
    }
    const updated = this.draftMoreActions.slice();
    const moved = updated.splice(from, 1)[0];
    if (moved === undefined) { return; }
    updated.splice(to, 0, moved);
    this.draftMoreActions = updated;
  }

  @Builder
  private moreActionConfigRow(config: ReaderMoreActionConfig) {
    Row() {
      AppGlyph({ name: this.getMoreAction(config.id)?.glyph ?? 'more', glyphSize: 20,
        tint: config.enabled ? this.readerMenuForeground() : '#777984' }).margin({ right: 12 })
      Column() {
        Text(this.getMoreAction(config.id)?.label ?? config.id).fontSize(TITLE_SMALL)
          .fontColor(config.enabled ? '#E5E6EB' : '#777984')
        if ((this.getMoreAction(config.id)?.scopeLabel ?? '').length > 0) {
          Text(this.getMoreAction(config.id)?.scopeLabel ?? '')
            .fontSize(LABEL_SMALL).fontColor(this.themeColorTextTertiary).margin({ top: 2 })
        }
        if (this.getMoreAction(config.id)?.migrated === false) {
          Text('未迁移').fontSize(LABEL_SMALL).fontColor(this.themeColorTextTertiary).margin({ top: 2 })
        }
      }.layoutWeight(1).alignItems(HorizontalAlign.Start)
      // 上游 MoreActionsConfigContent（ReaderMoreActionsSheet.kt:276-306）右侧是开关，
      // 不是本地的眼睛图标；开关只改启用，不改顺序。
      UiSwitchControl({
        checked: config.enabled,
        interactive: true,
        onChange: (value: boolean) => { this.setMoreActionEnabled(config.id, value); }
      })
      // 拖拽把手：顺序由 List.onMove 的拖拽手势决定，把手本身只是视觉提示，
      // 所以这里显式关掉命中测试，避免它吃掉半个拖拽手势。
      Image($r('app.media.reader_drag_handle')).width(20).height(20).fillColor('#B9BBC4')
        .width(32).height(36).margin({ left: 4 })
        .hitTestBehavior(HitTestMode.None)
    }.width('100%').padding({ left: 14, right: 14, top: 8, bottom: 8 })
      .backgroundColor(this.themeColorSurfaceSecondary).borderRadius(12)
  }

  private selectMoreAction(action: ReaderMoreAction): void {
    this.overflowVisible = false;
    // 选中任一动作即收起上次展开的三角态，避免下次开面板还残留高亮。
    this.moreActionMenuId = '';
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
    } else if (action.id === 'del_ruby' || action.id === 'del_h') {
      const tag = action.id === 'del_ruby' ? 4 : 2;
      const enabled = ((this.book.delTag ?? 0) & tag) === 0;
      const page = this.localReaderPages[this.currentPageIndex];
      this.pendingBookmarkTargetPosition = page?.startPosition ?? 0;
      this.onToggleDelTag(tag, enabled);
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
    } else if (action.id === 'simulated_reading') {
      // 打开面板时把已落库的四项灌进草稿，取消不改任何值。
      this.simReadEnabled = this.book.readSimulating === true;
      this.simReadStartDate = this.book.startDate ?? '';
      this.simReadDailyInput = `${this.book.dailyChapters ?? 3}`;
      this.simReadStartChapterInput = `${this.book.startChapter ?? 0}`;
      this.simulatedReadingVisible = true;
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

  /**
   * 批10（:570）长按「换源 / 刷新章节」格子后弹出的二级菜单。
   * 上游 `ReadMenuLongPressDropdown`（`ReadBookMenuBarTitle.kt:796-821`）按
   * `ReadMenuLongPressMenu.ChangeSource / Refresh` 分派两组：
   * - ChangeSource（:765-772）：换源 `change_origin` / 更换本章源 `chapter_change_source`
   * - Refresh（:776-789）：刷新本章 `menu_refresh_dur` / 刷新后续 `menu_refresh_after`
   * 本地能真跑的是「换源」「刷新本章」；「更换本章源」「刷新后续」没有对应实现，
   * 由上层 `onOpenChapterChangeSource` / `onRefreshAfterChapter` 如实提示未迁移，
   * 这里不伪造成功（任务书验收第 15 条）。
   */
  private longPressMenuItems(): string[] {
    if (this.longPressMenuId === 'change_source') {
      return ['换源', '更换本章源'];
    }
    if (this.longPressMenuId === 'refresh') {
      return ['刷新本章', '刷新后续'];
    }
    return [];
  }

  private selectLongPressMenu(label: string): void {
    const menu = this.longPressMenuId;
    this.longPressMenuId = '';
    if (menu === 'change_source') {
      if (label === '换源') { this.onOpenChangeSource(); return; }
      if (label === '更换本章源') { this.onOpenChapterChangeSource(); return; }
    }
    if (menu === 'refresh') {
      if (label === '刷新本章') { this.onRefreshCurrentChapter(); return; }
      if (label === '刷新后续') { this.onRefreshAfterChapter(); return; }
    }
  }

  @Builder
  private readerLongPressMenu() {
    Stack({ alignContent: Alignment.Center }) {
      Column().width('100%').height('100%').backgroundColor('#66000000')
        .onClick(() => this.longPressMenuId = '')
      Column() {
        ForEach(this.longPressMenuItems(), (label: string) => {
          Row() {
            Text(label).fontSize(LABEL_LARGE).fontColor('#E5E6EB').layoutWeight(1)
          }.width('100%').padding({ left: 16, right: 16, top: 14, bottom: 14 })
            .onClick(() => this.selectLongPressMenu(label))
        }, (label: string) => label)
        Row() {
          Text('取消').fontSize(LABEL_MEDIUM).fontColor('#C7C9D1')
            .padding({ left: 16, right: 16, top: 12, bottom: 12 })
            .onClick(() => this.longPressMenuId = '')
        }.width('100%').justifyContent(FlexAlign.End)
      }.width('78%').padding({ top: 8, bottom: 8 })
        .backgroundColor(this.themeColorSurfaceSecondary).borderRadius(20)
    }.width('100%').height('100%')
  }

  @Builder
  private moreActionUnavailableSheet() {
    Stack({ alignContent: Alignment.Center }) {
      Column().width('100%').height('100%').backgroundColor('#66000000')
        .onClick(() => this.moreActionShellVisible = false)
      Column() {
        Row() {
          Text(this.moreActionShellTitle).fontSize(TITLE_LARGE).fontWeight(FontWeight.Medium).fontColor('#E5E6EB')
            .layoutWeight(1)
          Text('关闭').fontSize(LABEL_MEDIUM).fontColor('#C7C9D1').onClick(() => this.moreActionShellVisible = false)
        }.width('100%').padding({ bottom: 14 })
        Text('此操作尚未迁移，当前不会执行。')
          .fontSize(TITLE_SMALL).fontColor('#B7B8C1').width('100%')
        Row() {
          Text('知道了').fontSize(LABEL_LARGE).fontColor(this.themeColorOnPrimary)
            .padding({ left: 22, right: 22, top: 10, bottom: 10 })
            .backgroundColor('#B9C6FF').borderRadius(18)
            .onClick(() => this.moreActionShellVisible = false)
        }.width('100%').justifyContent(FlexAlign.End).margin({ top: 20 })
      }.width('86%').padding(18).backgroundColor(this.themeColorSurfaceSecondary).borderRadius(20)
    }.width('100%').height('100%')
  }

  @Builder
  private moreActionConfigurationSheet() {
    ReaderSheetShell({
      scrimColor: '#66000000',
      panelColor: '#D91A1B21',
      panelHeight: '62%',
      onDismiss: () => this.moreActionConfigVisible = false
    }) {
        Row() {
          Text('更多操作配置').fontSize(BODY_LARGE).fontColor('#E5E6EB').layoutWeight(1)
          Text('取消').fontSize(LABEL_MEDIUM).fontColor('#C7C9D1').margin({ right: 18 })
            .onClick(() => this.moreActionConfigVisible = false)
          Text('保存').fontSize(LABEL_MEDIUM).fontColor('#C6D3FF')
            .onClick(() => {
              this.onMoreActionsChange(this.draftMoreActions.map(
                (item: ReaderMoreActionConfig): ReaderMoreActionConfig => ({ id: item.id, enabled: item.enabled })
              ));
              this.moreActionConfigVisible = false;
            })
        }.width('100%').padding({ left: 18, right: 18, bottom: 12 })
        // 上游 MoreActionsConfigContent 用 ReorderableConfigList：右侧开关 + 左侧拖拽把手，
        // 没有上下箭头。ArkUI 里改为 List + 长按拖拽排序。
        // 注意 onMove 挂在 ForEach 上（不是 List 上），List 只负责提供容器。
        // 也不能用 Scroll 再包 List：两层滚动容器会让 List 拿不到自己的滚动手势，onMove 一起失效。
        // 不调 `editMode(true)`：该 API 自 API 9 起已废弃且无替代物，长按拖拽由 onMove 自身驱动；
        // 批 4 上机实测（`uinput -M -g` 4 秒慢拖）在去掉它之后仍能换序。
        List() {
          ForEach(this.draftMoreActions, (config: ReaderMoreActionConfig) => {
            ListItem() {
              this.moreActionConfigRow(config)
            }.width('100%').margin({ bottom: 8 })
          }, (config: ReaderMoreActionConfig) => config.id)
            .onMove((from: number, to: number) => this.moveMoreActionTo(from, to))
        }.width('100%').layoutWeight(1).scrollBar(BarState.Off)
        .padding({ left: 14, right: 14, bottom: 12 })
    }
  }

  private getWholeBookProgress(): number {
    const chapterCount = this.getChapterCount();
    const chapterIndex = this.getChapterIndex();
    if (this.effectivePageAnim() !== 3) {
      // 页层批次 4：分母与分子都取当前章（窗口表还含邻章页，不能拿 length 当章页数）。
      const position = chapterPosition(this.localReaderPages, this.currentPageIndex);
      const pageCount = position?.pageCount ?? this.localReaderPages.length;
      const localPageIndex = position?.pageIndex ?? this.currentPageIndex;
      if (pageCount === 0 && chapterIndex === 0) { return 0; }
      const chapterProgress = pageCount > 0 ? (localPageIndex + 1) / pageCount : 1;
      let progress = (chapterIndex + chapterProgress) / chapterCount * 100;
      if (progress >= 100 && (chapterIndex + 1 !== chapterCount || localPageIndex + 1 !== pageCount)) {
        progress = 99.9;
      }
      return Math.max(0, Math.min(100, progress));
    }
    // 页层批次 4：滚动模式的分母章节取「可见页所属章」，不是宿主章号。
    // 跨章瞬间宿主的 `book.chapterIndex` 要等 `selectChapter` 落盘才更新，
    // 而页表与 `readerProgress` 已经按新章算了；两边不同源就会在页脚上闪一次
    // 「33.3% → 0.0% → 33.3%」（用户看到的整本进度回跳）。
    const visibleChapter = this.currentChapterPosition()?.chapterIndex ?? chapterIndex;
    return Math.max(0, Math.min(100,
      (visibleChapter + this.readerProgress / 100) / chapterCount * 100));
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

  /**
   * 正文内容指纹（FNV-1a 32 位），供章页快照键区分同一章的不同正文。
   * 不能用 readerContentRevision：它单调递增，换回同一章会永远 miss 批5的快照；
   * 正文没变时指纹稳定仍能命中，编辑正文后指纹改变就让旧页表失效。
   */
  private contentFingerprint(text: string): string {
    let hash = 2166136261;
    for (let i = 0; i < text.length; i++) {
      hash ^= text.charCodeAt(i);
      hash = Math.imul(hash, 16777619) >>> 0;
    }
    return hash.toString(36);
  }

  private getFullBookPaginationLayoutKey(): string {
    return this.getPaginationLayoutKey(this.readerContentRevision);
  }

  /**
   * 排版布局键的本体。revision 参数化是为了给章节快照键复用同一套排版输入
   * （字号/行距/边距/字体/列数/页面尺寸/替换规则等），但排除 readerContentRevision：
   * 它每次换章/规则变更都单调递增，含它做章快照键会让换回同一章永远 miss。
   */
  private getPaginationLayoutKey(revision: number): string {
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
      this.book.id, this.book.contentPath ?? '', revision, this.fontSize,
      this.textFontPath, this.titleFontPath, this.systemTypefaces,
      this.paragraphSpacing, this.lineSpacing, this.letterSpacing, this.paragraphIndent,
      // adaptSpecialStyle 决定 [newpage] 与 <usehtml> 是否被识别，直接改变段落结构；
      // 章页快照键固定用 revision=0，revision 自增拦不住，必须自己进键。
      this.adaptSpecialStyle,
      this.readerContentWidth, this.viewportHeight, this.effectiveImageStyle(), this.resolveReaderColumnCount(),
      JSON.stringify(this.paddingSettings),
      this.useZhLayout, this.effectivePageAnim(),
      this.infoSettings.headerMode, this.infoSettings.footerMode,
      this.infoSettings.headerFont, this.infoSettings.footerFont,
      this.infoSettings.headerFontSize, this.infoSettings.footerFontSize, this.infoSettings.applyHeaderStyle,
      chapterKey, replaceKey, processKey
    ].join('|');
  }

  private requestFullBookPagination(): void {
    // 批 2 验收打点：needs=1 说明页脚确实配了「全文页数」类占位符，
    // skipScroll=1 说明本次是滚动模式、全书分页被跳过（改前会照跑不误）。
    console.info(`[ReaderBench] fullBookPagination skipScroll=${this.effectivePageAnim() === 3 ? 1 : 0} needs=${this.needsFullBookPageData() ? 1 : 0}`);
    // 滚动模式的进度不走页数（getWholeBookPageIndex / getWholeBookPageCount 直接返回 -1），
    // 全书逐章分页算完没人读，却会占住排版线程，是换章顿挫的来源之一。
    // 并入早退：既不再启动，也借现有代际清理打断正在跑的任务并清掉已算结果。
    if (!this.needsFullBookPageData() || !this.book.isLocal || this.book.contentPath === undefined ||
      this.effectivePageAnim() === 3) {
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
    // 批5：排版输入变了，旧章快照全部作废，否则拿旧页表套新字号。
    ReaderChapterPageCache.clear();
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
    console.info(`[ReaderBench] fullBookPagination started gen=${generation}`);
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
      // 切到滚动模式后逐章检查一次，及时打断已在跑的全书分页（沿用现有循环返回，不另造取消机制）。
      if (this.effectivePageAnim() === 3 || generation !== this.fullBookPaginationGeneration ||
        key !== this.getFullBookPaginationLayoutKey()) {
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
        document.content.length, this.effectiveImageStyle() === 'SINGLE', displayTitle);
      const pageCount = chapterIndex === this.getChapterIndex() && this.localReaderPages.length > 0
        ? this.currentChapterPageCount()
        : await LocalReaderPaginator.countPagesIncrementally(
          document,
          width,
          pageHeight,
          lineHeight,
          paragraphSpacing,
          (text: string): number => measureFromGlyphCache(text),
          imageSizes,
          this.effectiveImageStyle(),
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
    if (!this.fullBookPaginationReady || this.effectivePageAnim() === 3) { return -1; }
    const chapterIndex = this.getChapterIndex();
    if (chapterIndex < 0 || chapterIndex >= this.fullBookPageCounts.length) { return -1; }
    // 页层批次 4：全书页码累加的是本章页号，不是窗口表下标。
    let pageIndex = (chapterPosition(this.localReaderPages, this.currentPageIndex)?.pageIndex
      ?? this.currentPageIndex) + 1;
    for (let index = 0; index < chapterIndex; index++) {
      pageIndex += this.fullBookPageCounts[index] ?? 0;
    }
    return pageIndex;
  }

  private getWholeBookPageCount(): number {
    if (!this.fullBookPaginationReady || this.effectivePageAnim() === 3) { return -1; }
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
    // 页层批次 4：页码与本章页数一律按当前章现算（窗口表含邻章页）。
    const current = usesPageProgress ? this.currentChapterPageIndex() + 1 : this.getChapterIndex() + 1;
    const total = usesPageProgress ? this.currentChapterPageCount() : this.getChapterCount();
    return `${current}/${total}  ${this.getWholeBookProgress().toFixed(1)}%`;
  }

  // 上游 ReaderColumnMode.kt 的 columnCount()：'1' 恒双页（滚动模式也生效），
  // '2' 只在横屏且非滚动时双页，'3' 放宽到平板，其余单页。
  private resolveReaderColumnCount(): number {
    return readerColumnCount(this.doubleHorizontalPage, this.readerContentWidth, this.viewportHeight,
      this.effectivePageAnim() === 3);
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
    // 状态栏占位与页眉预留是两笔独立的扣减，见 readerStatusBarReserve() 的注释：
    // 上游 paddingTopPx = paddingTop + contentPaddingTop + headerExtentPx（LegacyReaderChapterPaginator.kt:267）。
    return Math.max(1, this.viewportHeight - this.paddingSettings.paddingTop -
      this.paddingSettings.paddingBottom - this.readerStatusBarReserve() -
      headerReserve - footerReserve - this.readerCutoutBottomInset());
  }

  /**
   * 页眉页脚在正文之外占掉的纵向高度。
   *
   * 必须与 `ReaderInfoRow()` 的真实布局逐项对上，否则会多排一次版：
   * 公式算高了 → 画布实测更矮 → `syncReaderCanvasBodyHeight` 触发 `rebuildReaderPages()`，
   * 用户看到开书时正文跳一下。真实占位 = 内容行 18 + 分隔线 1（可选）+ padding 上下各 2。
   * 上游 `ReaderCanvasSurface.kt:3035` 的页脚也是这个构成（18 + divider + padding）。
   */
  private getReaderInfoReserve(isHeader: boolean): number {
    const top = isHeader ? this.paddingSettings.headerPaddingTop : this.paddingSettings.footerPaddingTop;
    const bottom = isHeader ? this.paddingSettings.headerPaddingBottom : this.paddingSettings.footerPaddingBottom;
    const showLine = isHeader ? this.infoSettings.showHeaderLine : this.infoSettings.showFooterLine;
    return 18 + (showLine ? 1 : 0) + 4 + top + bottom;
  }

  /**
   * 状态栏占位高度（vp）。
   *
   * 对齐上游 `ui/book/read/ReaderContentAvoidancePolicy.kt:30-48` 的 statusPlaceholderGone 分支：
   * 占位存在时正文顶部让开一整条状态栏，hideStatusBar 打开时让位归零、正文上移贴顶。
   *
   * 与页眉是两件事，必须叠加：页眉是「画在让位区之下的一条装饰」，状态栏占位是「让位区本身」。
   * 上游 `LegacyReaderChapterPaginator.kt:267` 的 paddingTopPx = paddingTop + contentPaddingTop + headerExtent
   * 就是这个叠加关系。
   *
   * 高度取 @StorageProp('appTopInset')：`pages/Index.ets:799-807` 的 publishAppTopInset()
   * 读 TYPE_SYSTEM 的 topRect.height 后 px2vp 广播，与上游 statusBarTopPx 同源同口径。
   * 它由 getWindowAvoidArea 采样、不是逐帧跟随可见性——菜单开关不会改这个值，
   * 所以本轮不会引入「开关菜单整章重排」。
   */
  private readerStatusBarReserve(): number {
    // 上游 statusPlaceholderGone = hideStatusBar || inMultiWindow。
    // 本地没有多窗口形态（docs/PROJECT.md 范围之外），只判 hideStatusBar。
    if (this.hideStatusBar) { return 0; }
    // 取整到 0.5vp：状态栏高度是设备常数，亚像素抖动会让分页键每帧变化、反复重排。
    return Math.max(0, Math.round(this.appTopInset * 2) / 2);
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

  /**
   * 批5（:127）行内快速标记：打开贴选区的样式面板。
   *
   * 命中判定按「同一章节 + 同一区间 + 同一段选中文字」找已有标记（上游 OpenQuickMarkingEdit 的口径），
   * 命中就把它的样式与备注预填进来，点「应用」时走编辑而不是新建，避免同一段文字叠两条标记。
   */
  private openQuickMarkPanel(): void {
    if (!this.book.isLocal || BookRepository.isBodyMissing(this.book)) {
      this.onUnavailableAction('划线与笔记仅支持已有本地正文的书籍');
      return;
    }
    const start = this.pendingMarkingStart;
    const end = this.pendingMarkingEnd;
    const selectedText = this.selectedText();
    if (start < 0 || end <= start || selectedText.length === 0) {
      this.onUnavailableAction('没有取得有效的正文选区，请重新选择文字');
      return;
    }
    // 面板锚在划词菜单刚让出来的位置（菜单本来就贴着选区，见 refreshCanvasSelectionMenuAnchor）。
    // 面板固定宽 300vp、高约 200vp：先夹进屏内，下方放不下就翻到上面。
    const panelWidth = 300;
    const panelHeight = 200;
    const maxX = Math.max(4, this.readerContentWidth - panelWidth - 4);
    this.quickMarkAnchorX = Math.min(Math.max(4, this.canvasSelectionMenuX), maxX);
    this.quickMarkAnchorY = this.canvasSelectionMenuY + panelHeight <= this.viewportHeight - 4
      ? this.canvasSelectionMenuY
      : Math.max(4, this.canvasSelectionMenuY - panelHeight - 8);
    const existing = this.findMarkingForExactRange(start, end, selectedText);
    this.quickMarkExistingId = existing === undefined ? '' : existing.id;
    this.quickMarkStyle = existing === undefined ? this.readerLastMarkingEffect() : existing.effect;
    this.quickMarkNote = existing === undefined ? '' : existing.note;
    this.quickMarkVisible = true;
  }

  private closeQuickMarkPanel(): void {
    this.quickMarkVisible = false;
    this.clearCanvasSelection();
  }

  /** 同章 + 同区间 + 同文字；与 getMarkingForTextRange 的「相交」口径不同，这里要求完全一致。 */
  private findMarkingForExactRange(start: number, end: number, selectedText: string): ReaderMarking | undefined {
    const chapterIndex = this.getChapterIndex();
    for (let index = 0; index < this.markings.length; index++) {
      const marking = this.markings[index];
      if (marking !== undefined && marking.chapterIndex === chapterIndex &&
        marking.chapterPosition === start && marking.endPosition === end &&
        marking.selectedText === selectedText) {
        return marking;
      }
    }
    return undefined;
  }

  /** 上次用过的样式（上游「记住上次样式」）；没记过就按实线下划线（decodeStyle 自带默认回落）。 */
  private readerLastMarkingEffect(): ReaderMarkingEffect {
    return ReaderMarkingRepository.decodeStyle(this.lastMarkingStyle).effect;
  }

  private applyQuickMarking(): void {
    const start = this.pendingMarkingStart;
    const end = this.pendingMarkingEnd;
    const selectedText = this.selectedText();
    if (start < 0 || end <= start || selectedText.length === 0) {
      this.onUnavailableAction('没有取得有效的正文选区，请重新选择文字');
      return;
    }
    this.onApplyQuickMarking(start, end, selectedText, this.quickMarkStyle, this.quickMarkNote,
      this.quickMarkExistingId);
    this.quickMarkVisible = false;
    this.clearCanvasSelection();
  }

  private deleteQuickMarking(): void {
    if (this.quickMarkExistingId.length === 0) {
      return;
    }
    this.onDeleteQuickMarking(this.quickMarkExistingId);
    this.quickMarkVisible = false;
    this.clearCanvasSelection();
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
   * 排版本题块用的章标题。
   *
   * 章节缓存（`BookRepository.cachedChapterTitles`，同步可读）是唯一来源：
   * 邻章预排时当前章标题还没切过去，真页重排时 `displayChapterTitle` 又滞后于
   * `applyTitle`，只有章节缓存两处都能立刻拿到**同一个**字符串。标题块参与排版流
   * （会占行、会决定首页断页），两边只要差一个字，排出来的页数和页内断点就不同，
   * 页表整表替换时必然错位。显示层的替换规则效果留在页眉，不进排版。
   */
  private resolvePaginationTitle(chapterIndex: number): string {
    const titles = BookRepository.cachedChapterTitles(this.book);
    const cached = titles[chapterIndex];
    if (cached !== undefined && cached.length > 0) { return cached; }
    return this.displayChapterTitle;
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
        spacingAfter: spacingAfter,
        // 标题改走正文同一个断行引擎（#1016）后，引擎要按段拿字体族/字号/字重/字间距，
        // 否则断出来的行宽与画出来的行宽对不上（断行说放得下、绘制却超出去）。
        fontFamilies: [this.readerTitleFontFamily],
        fontSizeFp: segmentSize,
        fontWeight: this.resolveTitleWeight(),
        letterSpacingVp: this.getReaderLetterSpacingVp(segmentSize)
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
      },
      vpScalePx: context.vp2px(1),
      fpScalePx: context.fp2px(1)
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
        // 上游 `ReadBookMenuBarBottom.kt:376-459` 竖排只有「按钮 + 滑块 + 按钮」，没有数值文字；
        // 本地原来那块 11 号数值是自造的，已删。删后底部空出约 11vp 属正常。
      }
      // 上游竖排整条宽 `buttonGlassEnabled ? 64.dp : 56.dp`。
      .width(this.readerBottomBarButtonGlassEnabled() ? 64 : 56)
      .padding({ top: 12, bottom: 12, left: 4, right: 4 })
    } else {
      Row({ space: 8 }) {
        this.ReaderBrightnessButton('auto', this.brightnessAuto)
        this.ReaderBrightnessSlider(false)
        // 上游横排右端是 `Spacer(Modifier.width(buttonSize))`——纯占位，不显示数值。
        Row().width(this.readerBottomBarButtonGlassEnabled() ? 48 : 40)
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
      // 上游 `updateSliderValue` 里 `if (brightnessAuto) return`，且滑块 `enabled = !brightnessAuto`：
      // 跟随系统亮度时滑块拖不动。
      .enabled(!this.brightnessAuto)
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
        Text(this.dayNightReminderText).fontSize(LABEL_MEDIUM).fontColor(this.themeColorOnPrimary)
      }
      .padding({ left: 16, right: 16, top: 9, bottom: 9 })
      .backgroundColor('#C6D3FF')
      .borderRadius(18)
      .onClick(() => this.onAcceptDayNightReminder())

      Row() {
        Text('关闭').fontSize(LABEL_MEDIUM).fontColor('#D9DAE0')
      }
      .padding({ left: 16, right: 16, top: 9, bottom: 9 })
      .backgroundColor(this.themeColorSurfaceTertiary)
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
        // 展开态：多行平铺卡片（上游 TextActionSelectionMenu.kt:166-190 + MultiLineMenuView :311-352）。
        // 条目竖排（图标在上、文字在下）、横向 8dp 排开，整卡最高 300dp 超出内部竖滚。
        Column() {
          Scroll() {
            Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Center }) {
              ForEach(this.resolveSelectionMenuItems(), (item: ReaderSelectionMenuItem) => {
                this.selectionMenuColumnItem(item, 12, 8)
              }, (item: ReaderSelectionMenuItem) =>
                `${item.id}-${this.showSelectMenuIcon}-${this.expandTextMenu}-${this.selectionMenuMoreVisible}`)

              // 上游 MultiLineMenuView 末尾追加的「编辑菜单项」行（:330-350）。
              Row() {
                AppGlyph({ name: 'settings', glyphSize: 16, tint: this.readerMenuForeground() })
                Text('编辑菜单项').fontSize(LABEL_SMALL)
                  .fontColor(this.readerMenuForeground()).margin({ left: 6 })
              }
              .padding({ left: 16, right: 16, top: 12, bottom: 12 })
              .onClick(() => {
                this.canvasSelectionMenuVisible = false;
                this.animateCanvasSelectionMenu(false);
                this.paintReaderCanvas();
                this.onOpenSettings();
              })
            }
          }.edgeEffect(EdgeEffect.Spring, { alwaysEnabled: false })
          .scrollable(ScrollDirection.Vertical)
          .scrollBar(BarState.Off)
          .align(Alignment.Top)
          // 卡片本体宽度口径照上游 `menuCardWidth = 屏幕宽 - 32`（TextActionSelectionMenu.kt:107）。
          .constraintSize({ maxHeight: 300, maxWidth: Math.max(160, this.readerContentWidth - 32) })
          .backgroundColor(this.readerSelectionCardColor())
          .borderRadius(12)
          // 上游是 elevation 12dp 的双层投影（环境光 + 键光），ArkUI 只有单层 shadow。
          // 上机实测：`readBarStyle == 1` 时卡片底色就是纸色，与正文背景同像素（26,26,26），
          // `{ radius: 12, color: '#40000000', offsetY: 4 }` 在这块深色同色面上看不出边界，
          // 所以这一档改走描边兜底（任务书 6.3 的 B 档），不是投影。
          .border({ width: 1, color: this.readerMenuForegroundAlpha('26') })
        }
        // 注：上游在这一层还有 `menuShadowPadding = 12dp` 给投影留边。本地改走描边后不需要，
        // 加了反而会把卡片再缩一圈、并让它在选区上方多顶 12vp。
      } else {
        // 折叠态：一行可横向滚动的快捷条 + 右端分隔线 + 三点钮
        // （上游 TextActionSelectionMenu.kt:354-418 QuickMenuView）。
        // 外面这层 Column 不能省：挂载点是 position 定位、宽度撑满整屏，
        // 只有 Column{ Row } 这种嵌套才让卡片收缩到内容宽（实测省掉它卡片会拉满 1280px）。
        Column() {
          Row() {
            Scroll() {
              Row() {
                ForEach(this.resolveSelectionMenuItems(), (item: ReaderSelectionMenuItem, index: number) => {
                  this.selectionMenuColumnItem(item, 12, 8, index)
                }, (item: ReaderSelectionMenuItem) =>
                  `${item.id}-${this.showSelectMenuIcon}-${this.expandTextMenu}-${this.selectionMenuMoreVisible}`)
              }
            }
            .scrollable(ScrollDirection.Horizontal)
            .scrollBar(BarState.Off)
            .align(Alignment.Start)
            // 折叠态一行：条目区吃掉剩余宽度，条目多了在内部横向滚动。
            // 注意这里必须是 flexShrink 不能是 layoutWeight —— 父 Row 没有定宽，
            // layoutWeight(1) 会把整行撑到满屏（实测卡片拉到 1280px 溢出屏幕右缘）。
            .flexShrink(1)
          if (this.resolveSelectionMenuItems().length > 0) {
            // 右端分隔线：高 20dp、宽 1dp、40% 透明（上游 `outlineVariant.copy(alpha = 0.4f)`）。
            Row().width(1).height(20).backgroundColor(this.readerMenuForegroundAlpha('66'))
          }
          Row() {
            AppGlyph({
              name: this.hasCollapsedSelectionMenuItem() ? 'more' : 'settings',
              glyphSize: 16,
              tint: this.readerMenuForeground()
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
        .backgroundColor(this.readerSelectionCardColor())
        .borderRadius(12)
        // 卡片按内容自适应宽度，但必须夹进视口：外层 Column 没有参照宽度，
        // 百分比 maxWidth 在这里不生效，只能用正文宽度算具体数值。
        .constraintSize({ maxWidth: Math.max(200, this.readerContentWidth * 0.92) })
        // 上游 elevation 6.dp（折叠态比展开态低一档）。与展开态同理，同色纸面上单层 shadow
        // 看不出边界，一并改走描边（任务书 6.3 的 B 档）。
        .border({ width: 1, color: this.readerMenuForegroundAlpha('26') })
        // 二级弹层打开时主卡缩到 0.96、透明度 0.82（上游 quickMenuScale tween 400 / quickMenuAlpha tween 360，
        // 锚点在右端中点 TransformOrigin(1f, 0.5f)）。ArkUI 一个 .animation() 管全部属性，
        // 做不到两个时长，这里取 400 —— 是把上游两档合并成一个值，不是漏了 360。
        .scale({
          x: this.selectionMenuMoreVisible ? 0.96 : 1,
          y: this.selectionMenuMoreVisible ? 0.96 : 1,
          centerX: '100%',
          centerY: '50%'
        })
        .opacity(this.selectionMenuMoreVisible ? 0.82 : 1)
        .animation({ duration: 400, curve: Curve.EaseOut })
        }
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
    // 外层只负责给投影留边（menuShadowPadding = 12dp），底色与圆角在内层卡片上。
    Column() {
      Column() {
        Row() {
          Image($r('app.media.reader_back')).width(20).height(20).fillColor(this.readerMenuForeground())
        }
        .width('100%')
        .justifyContent(FlexAlign.Start)
        .padding({ left: 16, right: 16, top: 12, bottom: 8 })
        .onClick(() => { this.selectionMenuMoreVisible = false; })
        .accessibilityText('返回')
        Row().width('80%').height(1).backgroundColor(this.readerMenuForegroundAlpha('66'))
        Scroll() {
          Column() {
            ForEach(this.collapsedSelectionMenuItems(), (item: ReaderSelectionMenuItem) => {
              // 这一层上游是横排（MoreMenuView :500-520），不要跟着主卡改成竖排。
              Row() {
                if (this.showSelectMenuIcon) { this.readerSelectionMenuIcon(item.id) }
                Text(item.title).fontSize(LABEL_MEDIUM).fontColor(this.readerMenuForeground())
                  .margin({ left: this.showSelectMenuIcon ? 12 : 0 })
              }
              .width('100%')
              .padding({ left: 16, right: 16, top: 12, bottom: 12 })
              .onClick(() => this.runSelectionMenuAction(item.id))
            }, (item: ReaderSelectionMenuItem) => `more-${item.id}-${this.showSelectMenuIcon}`)
          }
        }.edgeEffect(EdgeEffect.Spring, { alwaysEnabled: false })
        .scrollable(ScrollDirection.Vertical)
        .scrollBar(BarState.Off)
        .constraintSize({ maxHeight: 240 })
        .align(Alignment.Top)
        Row().width('80%').height(1).backgroundColor(this.readerMenuForegroundAlpha('66'))
        Row() {
          AppGlyph({ name: 'settings', glyphSize: 20, tint: this.readerMenuForeground() })
          Text('编辑菜单项').fontSize(LABEL_MEDIUM).fontColor(this.readerMenuForeground()).margin({ left: 12 })
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 8, bottom: 12 })
        .onClick(() => {
          this.selectionMenuMoreVisible = false;
          this.onOpenSettings();
        })
      }
      .backgroundColor(this.readerSelectionCardColor())
      .borderRadius(12)
      // 上游用 `width(IntrinsicSize.Max)`（宽度贴合最宽子项），ArkUI 没有这个原语。
      // 里面的分隔线与各行都写着 `width('100%')`，只有父宽确定时才肯跟随：
      // 用 constraintSize 只收住了卡片自身的背景宽度，子项仍按未约束的可用宽度布局
      // （实测卡片背景 767px、里面各行却拉到 1244px 溢出屏幕）。所以这里给确定宽度。
      .width(Math.max(160, this.readerContentWidth * 0.6))
      // 与主卡同理：同色纸面上单层 shadow 看不出边界，改走描边（任务书 6.3 的 B 档）。
      .border({ width: 1, color: this.readerMenuForegroundAlpha('26') })
      // 进出场：上游是 AnimatedVisibility(enter = fadeIn(360) + scaleIn(0.94, tween 400),
      // exit = fadeOut(240) + scaleOut(0.96, tween 280))；ArkUI 的 .animation() 只认一个时长，
      // 进 360 / 退 240 做不到分开，取中间 300，且不做 @State + animateTo 双路径。
      .opacity(this.selectionMenuMoreVisible ? 1 : 0)
      .scale({
        x: this.selectionMenuMoreVisible ? 1 : 0.94,
        y: this.selectionMenuMoreVisible ? 1 : 0.94,
        // 贴折叠卡的右端长出来（上游锚点在锚点元素方向）。
        centerX: '100%',
        centerY: '0%'
      })
      .animation({ duration: 300, curve: Curve.EaseOut })
    }
    .constraintSize({ maxWidth: '92%' })
    // 上游这一层还有 `shadowPadding` 给投影留边；本地主卡已改走描边，这一层同样不需要，
    // 保持原来的 `margin({ top: 6 })` 贴住折叠卡下方即可（任务书 6.6 允许的退化写法）。
    .margin({ top: 6 })
  }

  /**
   * 划词菜单条目（展开态与折叠态共用一套形状）。
   * 对齐上游 `TextActionSelectionMenu.kt:311-352`：`Column` 竖排居中，图标在上、
   * `Spacer(4.dp)` 之后是 `labelMedium` = 13sp 的文字；展开态条目内边距 `verticalPadding = 12.dp`。
   * 折叠态首项左距 16dp、其余 10dp，右端统一 8dp（`QuickMenuView` 的 itemsIndexed），由 `firstIndex` 传入。
   */
  @Builder
  selectionMenuColumnItem(item: ReaderSelectionMenuItem, verticalPadding: number, endPadding: number,
    firstIndex: number = -1) {
    Column() {
      if (this.showSelectMenuIcon) {
        this.readerSelectionMenuIcon(item.id)
        // 上游 Spacer(4.dp)：图标在上、文字在下。
        Blank().height(4)
      }
      Text(item.title)
        .fontSize(LABEL_MEDIUM)
        .fontColor(this.readerMenuForeground())
        .maxLines(1)
    }
    .padding({
      left: firstIndex < 0 ? 0 : (firstIndex === 0 ? 16 : 10),
      right: endPadding,
      top: verticalPadding,
      bottom: verticalPadding
    })
    .alignItems(HorizontalAlign.Center)
    .onClick(() => this.runSelectionMenuAction(item.id))
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

  /** 划词菜单条目的动作分发；白名单 READER_SELECTION_MENU_SUPPORTED 里的每一项在这里都有真分支。 */
  private runSelectionMenuAction(id: string): void {
    // 老路径的 bindSelectionMenu 会在点中条目后自动收起菜单，画布上得自己收：
    // 只藏菜单、保留选区色块，与 ArkUI 点完菜单仍保持选中的行为一致。
    this.canvasSelectionMenuVisible = false;
    this.animateCanvasSelectionMenu(false);
    this.paintReaderCanvas();
    if (id === 'menu_copy') { this.copyCurrentSelection(); return; }
    if (id === 'menu_bookmark') { this.bookmarkCurrentSelection(); return; }
    if (id === 'menu_mark') { this.openQuickMarkPanel(); return; }
    // 批4（r358）：五项接真，每一项都有独立真处理函数。
    if (id === 'menu_share_str') { this.shareSelection(); return; }
    if (id === 'menu_browser') { this.openSelectionInBrowser(); return; }
    if (id === 'menu_aloud') { this.readAloudFromSelection(); return; }
    if (id === 'menu_replace') { this.onOpenReplaceRulesWithPattern(this.selectedText()); return; }
    if (id === 'menu_search_content') { this.onOpenSearchContent(this.selectedText()); return; }
  }

  /** 当前选中的正文文本；与 copyCurrentSelection 同源，取不到就是空串。 */
  private selectedText(): string {
    return this.pendingMarkingText;
  }

  /**
   * :214 划词分享。系统无 sendData 接收方时降级复制到剪贴板（与批1书分享同口径），
   * 降级行为写进差异说明；不静默失败。
   */
  private shareSelection(): void {
    const text = this.selectedText();
    if (text.length === 0) {
      this.onUnavailableAction('没有取得有效的正文选区，请重新选择文字');
      return;
    }
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext | undefined;
    if (context !== undefined) {
      const want: Want = {
        action: 'ohos.want.action.sendData',
        type: 'text/plain',
        parameters: { 'ability.params.stream': text, 'ohos.extra.param.key.content': text }
      };
      context.startAbility(want).then(() => {
        this.onUnavailableAction('已调起分享');
      }).catch(() => {
        this.copySelectionFallback(text);
      });
      return;
    }
    this.copySelectionFallback(text);
  }

  /** 划词分享降级：写剪贴板并明确告知。 */
  private copySelectionFallback(text: string): void {
    const data = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, text);
    pasteboard.getSystemPasteboard().setData(data).then(() => {
      this.onUnavailableAction('已复制选中文字');
    }).catch(() => {
      this.onUnavailableAction('分享失败，剪贴板不可用');
    });
  }

  /**
   * :215 划词「浏览器打开」。只认选中文本里第一段 http(s) URL（/(https?:\/\/\S+)/），
   * 不瞎猜；没有 URL 就提示。
   * 批3（r359）：跳转封装收进 `lib/WantLauncher.ets`，与 :105「在浏览器打开」共用一份，
   * 免得同一个 viewData want 写两遍。
   */
  private openSelectionInBrowser(): void {
    const text = this.selectedText();
    const match = text.match(/(https?:\/\/\S+)/);
    if (match === null || match[1] === undefined || match[1].length === 0) {
      this.onUnavailableAction('选中内容里没有链接');
      return;
    }
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext | undefined;
    WantLauncher.openUrl(context, match[1]).then((opened: boolean) => {
      if (!opened) {
        this.onUnavailableAction('没有应用可以打开该链接');
      }
    });
  }

  /** :111 划词「朗读」：把当前选区的起止位置交给上层，从选中处开始朗读。 */
  private readAloudFromSelection(): void {
    if (this.selectedText().length === 0) {
      this.onUnavailableAction('没有取得有效的正文选区，请重新选择文字');
      return;
    }
    this.onReadAloudFromPosition(this.pendingMarkingStart);
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
    this.readerHighlightRanges = ReaderHighlightRuleEngine.findBodyRanges(
      this.localSemanticContent, rules, this.currentConfigName);
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
    this.readerHighlightRanges = ReaderHighlightRuleEngine.findBodyRanges(
      this.localSemanticContent, saved, this.currentConfigName);
    this.readerSizeOffsets = this.buildReaderSizeOffsets();
    this.readerContentRevision++;
    this.rebuildReaderPages();
    return saved;
  }



  private usesLocalPagination(): boolean {
    // P3-E：在线书也要走画布分页，不再以 isLocal 限制。
    return this.effectivePageAnim() !== 3;
  }

  /**
   * 连续滚动也走画布（上游 ReaderCanvasSurface.kt:1517-1540 的 ScrollPageStack）。
   *
   * 改造前滚动模式退回 ArkUI `Scroll` 把整章铺开，一是有两套排版（KI-EXP2 的残留形态），
   * 二是拿不到行几何，KI-C3 的下划线四项与选区都只得分页模式才有。
   */
  private usesCanvasScroll(): boolean {
    // P3-E：在线书同样走连续滚动画布。
    return this.effectivePageAnim() === 3;
  }

  /** 是否走画布渲染：在线书与本地书都走同一套画布。 */
  private usesReaderCanvas(): boolean {
    return true;
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
    // 页层批次 4：滚动进度是「本章」的进度，窗口表里的邻章页不能算进本章可滚高度，
    // 否则分母偏大、进度条与跳百分比都会漂移（B8 第 8 行偏移延续本轮仍不做）。
    const current = pages[this.currentPageIndex];
    const currentChapter = current?.chapterIndex ?? this.getChapterIndex();
    const endPadding = 20;
    const bodyHeight = this.getBodyContentHeight(
      this.isReaderHeaderVisible() ? this.getReaderInfoReserve(true) : 0,
      this.isReaderFooterVisible() ? this.getReaderInfoReserve(false) : 0);
    let total = 0;
    let lastChapterPage = false;
    for (let index = 0; index < pages.length; index++) {
      const page = pages[index];
      if (page === undefined) {
        continue;
      }
      if ((page.chapterIndex ?? 0) !== currentChapter) {
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
      lastChapterPage = true;
    }
    // 章末页再加 chapterEndPadding：只有本章真的有页时才加。
    if (lastChapterPage) {
      total += endPadding;
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
    // 页层批次 4：只累加「本章、当前页之前」的页 extent，窗口表里排在前面的
    // 上一章页不算进本章绝对位移。
    const current = pages[this.currentPageIndex];
    const currentChapter = current?.chapterIndex ?? this.getChapterIndex();
    let before = 0;
    for (let index = 0; index < this.currentPageIndex && index < pages.length; index++) {
      const page = pages[index];
      if (page === undefined) { continue; }
      if ((page.chapterIndex ?? 0) !== currentChapter) { continue; }
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
    // scrollOffset 负值=往后读（见 ReaderScrollPolicy.apply 的 crossing NEXT），
    // 故当前页内已读量是 -scrollOffset（正值），绝对位移随阅读前进递增。
    return before - this.scrollOffset;
  }

  /** 把章内绝对位移还原成「当前页索引 + 页内偏移」。 */
  private seekReaderScrollAbsolute(target: number): void {
    if (!this.chapterBoundaryContinuation) { this.pendingChapterScrollVp = 0; }
    const pages = this.localReaderPages;
    if (pages.length === 0) {
      return;
    }
    // 页层批次 4：只在本章页里还原「当前页索引 + 页内偏移」，
    // 窗口表里的邻章页不参与，落点 `index` 仍是窗口页表下标。
    const current = pages[this.currentPageIndex];
    const currentChapter = current?.chapterIndex ?? this.getChapterIndex();
    const chapterIndexes: number[] = [];
    for (let index = 0; index < pages.length; index++) {
      const page = pages[index];
      if (page === undefined) { continue; }
      if ((page.chapterIndex ?? 0) === currentChapter) { chapterIndexes.push(index); }
    }
    const footerReserve = this.isReaderFooterVisible() ? this.getReaderInfoReserve(false) : 0;
    const headerReserve = this.isReaderHeaderVisible() ? this.getReaderInfoReserve(true) : 0;
    const bodyHeight = this.getBodyContentHeight(headerReserve, footerReserve);
    let remaining = Math.max(0, target);
    for (let order = 0; order < chapterIndexes.length; order++) {
      const index = chapterIndexes[order] ?? -1;
      const page = pages[index];
      if (page === undefined) { continue; }
      let used = 0;
      for (const line of page.lines) {
        used += line.verticalSpaceBefore + line.height + line.paragraphSpacingAfter;
      }
      if (page.titleOnly && used <= 0) { used = Math.max(1, bodyHeight); }
      const extent = Math.max(1, used);
      if (remaining < extent || order === chapterIndexes.length - 1) {
        this.currentPageIndex = index;
        // 与 readerScrollAbsoluteOffset 互逆：页内已读 remaining → scrollOffset 取负。
        // 批4 曾写成正值，导致朗读高亮跟随时内容往回滚。
        this.scrollOffset = -Math.min(remaining, Math.max(0, extent - 1));
        return;
      }
      remaining -= extent;
    }
  }

  /**
   * 页内正文首行的章内字符位置。严格对齐上游 ReaderPageNavigator.pageStart(:267-275)：
   * 取页内「非标题元素」的最小 startPosition。本地标题行 titleLine=true 且 startPosition=0，
   * 与正文不同坐标空间，不能当页首，否则朗读定位会被拖进标题坐标。全标题页回退到
   * page.startPosition（对应上游 start==Int.MAX 时返回 0）。
   */
  private readerPageBodyStart(page: LocalReaderPage): number {
    let start = Number.MAX_SAFE_INTEGER;
    for (const line of page.lines) {
      if (line.titleLine === true) { continue; }
      if (line.startPosition < start) { start = line.startPosition; }
    }
    return start === Number.MAX_SAFE_INTEGER ? page.startPosition : start;
  }

  /**
   * 对齐上游 BaseReadAloudService.findReadAloudPageIndex(:2137-2149)：
   * 从本章第一页起，只要朗读位置超过下一章内页的 pageStart（排除标题）就往后翻。
   * chapterPages 是本章各页在页表里的下标，按章内页序排列。
   */
  private findReadAloudPageOrdinal(chapterPosition: number, chapterPages: number[]): number {
    if (chapterPages.length === 0) { return 0; }
    let ordinal = 0;
    while (ordinal + 1 < chapterPages.length) {
      const nextIdx = chapterPages[ordinal + 1] ?? -1;
      const nextPage = this.localReaderPages[nextIdx];
      if (nextPage === undefined) { break; }
      if (chapterPosition > this.readerPageBodyStart(nextPage)) { ordinal++; } else { break; }
    }
    return ordinal;
  }

  /**
   * 章内第 chapterOrdinal 页「正文首行」的绝对位移（vp）。对齐上游
   * syncReaderToPlaybackPage → chapter.pageStart(pageIndex)：朗读跨页时把可见页定位到
   * 目标页正文首行（排除标题），页内不连续滚动。
   * - 目标页之前的章内页：累加整页 extent（滚动栈里页与页紧挨）；
   * - 目标页本身：只累加正文首行之前那几行（标题行）的高度，使正文首行落在视口顶部。
   * extent 口径与 seekReaderScrollAbsolute / readerScrollAbsoluteOffset 一致。
   */
  private chapterPageStartVp(chapterOrdinal: number): number {
    const pages = this.localReaderPages;
    const current = pages[this.currentPageIndex];
    const currentChapter = current?.chapterIndex ?? this.getChapterIndex();
    const footerReserve = this.isReaderFooterVisible() ? this.getReaderInfoReserve(false) : 0;
    const headerReserve = this.isReaderHeaderVisible() ? this.getReaderInfoReserve(true) : 0;
    const bodyHeight = this.getBodyContentHeight(headerReserve, footerReserve);
    let startVp = 0;
    let order = 0;
    for (let index = 0; index < pages.length && order <= chapterOrdinal; index++) {
      const page = pages[index];
      if (page === undefined || (page.chapterIndex ?? 0) !== currentChapter) { continue; }
      if (order < chapterOrdinal) {
        let used = 0;
        for (const line of page.lines) {
          used += line.verticalSpaceBefore + line.height + line.paragraphSpacingAfter;
        }
        if (page.titleOnly && used <= 0) { used = Math.max(1, bodyHeight); }
        startVp += Math.max(1, used);
      } else {
        const bodyStart = this.readerPageBodyStart(page);
        for (const line of page.lines) {
          if (line.titleLine === true || line.startPosition >= bodyStart) { break; }
          startVp += line.verticalSpaceBefore + line.height + line.paragraphSpacingAfter;
        }
      }
      order++;
    }
    return startVp;
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
    this.syncProgressIndexFromPosition();
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
    // 页层批次 4：滚动驱动换章进行中不走绝对位移还原。
    // 这里还有一套位置（页表下标 + 页内偏移）是用户眼睛正看着的，
    // 用宿主的整章百分比覆盖它就是一次回跳。
    if (this.usesCanvasScroll() && this.scrollDrivenHandoffChapter >= 0) {
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
    this.syncProgressIndexFromPosition();
    this.paintReaderCanvas();
  }

  /**
   * 页码档：把滑块值（章内页号）换算成窗口页表下标并跳过去。
   * 上游 ReadBookController.publishDirectReaderWindow 每换页刷新、ViewModel 节流落库。
   * currentChapterPosition() 为 undefined（页表未就绪）时直接 return，不加兜底。
   */
  private seekToChapterPage(chapterPageIndex: number): void {
    const position = this.currentChapterPosition();
    if (position === undefined) { return; }
    const target = locateChapterPage(this.localReaderPages, position.chapterIndex, chapterPageIndex);
    if (target < 0) { return; }
    if (this.scrollProgressTimer >= 0) {
      clearTimeout(this.scrollProgressTimer);
      this.scrollProgressTimer = -1;
    }
    this.currentPageIndex = target;
    this.scrollOffset = 0;
    this.resetCanvasSelectionState();
    this.paintReaderCanvas();
    this.reportReaderPageProgress();
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
    // 批 3 确认打点：异步图片尺寸是否变化、是否会调度第二次 rebuild。
    console.info(`[ReaderBench] imageSizesReloaded rebuildAgain=${changed}`);
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
   * 翻到章边界时先记下提示文案，再交给换章回调。
   *
   * 连续滚动给「继续滑动以加载下一章…」（上游 `keep_swipe_tip`），
   * 分页翻页给「加载数据中…」（上游 `data_loading`）。
   * 目标章不存在（全书第一页/最后一页）时不显示，越界提示仍由上层 toast 负责。
   *
   * 页层批次 4 起，滚动模式的提示页**进页表**（`insertBoundaryPlaceholders`
   * 在章末补一张 `messageText` 页），不再把当前槽整张替换成提示文字——旧实现
   * 的前提是页表只有本章、章外没有可画的东西，页表跨章之后这个前提不成立了。
   * 这里只负责记文案与 5 秒兜底清空，`boundaryMessage` 不再参与画面装配。
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
    // 页层批次 4：章末 20dp padding 只加给「当前章末页」在窗口表里的下标。
    // 单章页表时 length-1 就是章末；跨章窗口下 length-1 是下一章末页，
    // 直接沿用会把 padding 加错页、让本章滚动 extent 与进度条分母不一致。
    const scrollCurrent = this.localReaderPages[this.currentPageIndex];
    const scrollChapter = scrollCurrent?.chapterIndex ?? this.getChapterIndex();
    // 第三参取一个必然超出章内页数的值，`locateChapterPage` 内部会钳到该章末页。
    // 用 MAX_SAFE_INTEGER 而不是 `length`，免得依赖「表长必然大于本章页数」这个隐含前提。
    request.scrollLastPageIndex = locateChapterPage(
      this.localReaderPages, scrollChapter, Number.MAX_SAFE_INTEGER);
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
    // 页眉页脚都搬进画布：两行装饰的取数与纵向尺寸各自喂给渲染层，
    // 取数口径仍走 ReaderInfoSlot 那套，页眉页脚共用一处，改一处两边都坏。
    request.headerDecoration = this.buildReaderHeaderDecoration(request);
    request.footerDecoration = this.buildReaderFooterDecoration(request);
    return request;
  }

  /**
   * 把页脚槽位从 ArkUI 组件翻译成画布可画的纯数据。
   *
   * 取数口径与 ReaderInfoSlot 完全一致（type / value / 图形型 / 重复留空），
   * 只把「画什么组件」换成「字符串 + 图形型编号」；纵向各项都用 vp2px 换算，
   * 逐项对齐 getReaderInfoReserve(false) 的预留，分页与绘制才不会各算一套。
   */
  private buildReaderFooterDecoration(request: ReaderCanvasDrawRequest): ReaderCanvasDecorationRow {
    const row = new ReaderCanvasDecorationRow();
    row.visible = this.isReaderFooterVisible();
    if (!row.visible) {
      return row;
    }
    const context = this.getUIContext();
    // 页脚贴在正文区**底边之下**：正文区从 originYpx 开始、高 bodyHeightPx，
    // 所以底边 = originYpx + bodyHeightPx。原来直接用 bodyHeightPx 当坐标，
    // 少加了 originYpx，页脚会画进正文区里（状态栏占位加上后误差更大）。
    row.originYpx = request.layout.originYpx + request.layout.bodyHeightPx;
    row.lineHeightPx = context.vp2px(18);
    row.fontSizePx = context.vp2px(this.getReaderInfoFontSize(false));
    row.fontFamilies = [this.readerInfoFontFamily(false)];
    row.colorArgb = readerCanvasArgb(this.getReaderInfoColor(false), 0xFF000000);
    const twoColumns = this.resolveReaderColumnCount() > 1;
    row.paddingLeftPx = context.vp2px(this.paddingSettings.footerPaddingLeft +
      (twoColumns ? this.paddingSettings.paddingLeft : 0));
    row.paddingRightPx = context.vp2px(this.paddingSettings.footerPaddingRight +
      (twoColumns ? this.paddingSettings.paddingRight : 0));
    row.paddingTopPx = context.vp2px(2 + this.paddingSettings.footerPaddingTop);
    row.paddingBottomPx = context.vp2px(2 + this.paddingSettings.footerPaddingBottom);
    if (this.infoSettings.showFooterLine) {
      row.dividerColorArgb = readerCanvasArgb(this.getReaderInfoDividerColor(), -1);
      row.dividerThicknessPx = context.vp2px(1);
    }
    for (let position = 0; position < 3; position++) {
      const type = this.getReaderInfoType(false, position);
      const duplicated = this.isReaderInfoDuplicated(false, position);
      const graphic = this.isReaderInfoGraphic(type) && !duplicated;
      const value = this.getReaderInfoValue(type, this.getReaderInfoTemplate(false, position));
      const tip = new ReaderCanvasDecorationTip();
      tip.alignment = position;
      tip.batteryPercent = this.readerInfoBatteryPercent();
      if (graphic) {
        tip.visual = type;
        tip.text = this.readerInfoGraphicKeepsText(type) ? value : '';
      } else {
        tip.visual = 0;
        tip.text = duplicated ? '' : value;
      }
      // 空槽整条丢弃：上游 tips() 也是 text 为空且非图形就不收，避免占位挤压中/右槽。
      if (tip.visual === 0 && tip.text.length === 0) {
        continue;
      }
      row.tips.push(tip);
    }
    return row;
  }

  /**
   * 把页眉槽位从 ArkUI 组件翻译成画布可画的纯数据。
   *
   * 与页脚版同一套口径，只是取数换成页眉那一侧：页眉让开状态栏（originYpx 取
   * readerStatusBarReserve，见下方 6318 起的说明），正文由 layout.originYpx 让出
   * headerReserve。各项都用 vp2px 换算，逐项对齐
   * getReaderInfoReserve(true) 的预留，分页与绘制才不会各算一套。
   */
  private buildReaderHeaderDecoration(request: ReaderCanvasDrawRequest): ReaderCanvasDecorationRow {
    const row = new ReaderCanvasDecorationRow();
    row.visible = this.isReaderHeaderVisible();
    if (!row.visible) {
      return row;
    }
    const context = this.getUIContext();
    // 页眉不是贴画布顶，而是贴在状态栏让位区之下——上游页眉装饰行的
    // paddingTopPx 里含 contentPaddingTopPx（LegacyReaderPageDecorationFactory.kt:185），
    // 所以状态栏那一条是空的，页眉从它下面开始。
    row.originYpx = context.vp2px(this.readerStatusBarReserve());
    row.lineHeightPx = context.vp2px(18);
    row.fontSizePx = context.vp2px(this.getReaderInfoFontSize(true));
    row.fontFamilies = [this.readerInfoFontFamily(true)];
    row.colorArgb = readerCanvasArgb(this.getReaderInfoColor(true), 0xFF000000);
    const twoColumns = this.resolveReaderColumnCount() > 1;
    row.paddingLeftPx = context.vp2px(this.paddingSettings.headerPaddingLeft +
      (twoColumns ? this.paddingSettings.paddingLeft : 0));
    row.paddingRightPx = context.vp2px(this.paddingSettings.headerPaddingRight +
      (twoColumns ? this.paddingSettings.paddingRight : 0));
    row.paddingTopPx = context.vp2px(2 + this.paddingSettings.headerPaddingTop);
    row.paddingBottomPx = context.vp2px(2 + this.paddingSettings.headerPaddingBottom);
    if (this.infoSettings.showHeaderLine) {
      row.dividerColorArgb = readerCanvasArgb(this.getReaderInfoDividerColor(), -1);
      row.dividerThicknessPx = context.vp2px(1);
    }
    for (let position = 0; position < 3; position++) {
      const type = this.getReaderInfoType(true, position);
      const duplicated = this.isReaderInfoDuplicated(true, position);
      const graphic = this.isReaderInfoGraphic(type) && !duplicated;
      const value = this.getReaderInfoValue(type, this.getReaderInfoTemplate(true, position));
      const tip = new ReaderCanvasDecorationTip();
      tip.alignment = position;
      tip.batteryPercent = this.readerInfoBatteryPercent();
      if (graphic) {
        tip.visual = type;
        tip.text = this.readerInfoGraphicKeepsText(type) ? value : '';
      } else {
        tip.visual = 0;
        tip.text = duplicated ? '' : value;
      }
      // 空槽整条丢弃：与页脚同口径，避免占位挤压中/右槽。
      if (tip.visual === 0 && tip.text.length === 0) {
        continue;
      }
      row.tips.push(tip);
    }
    return row;
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
    const leftPadding = context.vp2px(this.paddingSettings.paddingLeft + this.readerCutoutLeftInset());
    layout.originXpx = leftPadding;
    const headerReserve = this.isReaderHeaderVisible() ? this.getReaderInfoReserve(true) : 0;
    // 正文纵向原点 = 状态栏占位 + 页眉预留。上游页眉装饰行的 paddingTop 就是
    // headerPaddingTop + contentPaddingTop（LegacyReaderPageDecorationFactory.kt:185），
    // 正文从装饰行下方开始，所以两笔都要加进来。
    layout.originYpx = context.vp2px(this.readerStatusBarReserve() + headerReserve);
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
      // 批5（:123）：先按锚点文本确认这条标记在这个正文里还能不能对得上（上游 BookContentProcessEngine.kt:25-46）。
      // 存储里的偏移是创建时的，正文被替换规则或重新分段改过之后可能已经指向别的文字；
      // 对不上就用 :101-131 的三级退让重定位，仍然对不上就这一条不渲染。渲染期绝不写回存储，也不弹提示。
      const range = this.resolveMarkingRenderRange(marking);
      if (range === undefined) {
        continue;
      }
      if (range.start >= page.endPosition || range.end <= page.startPosition) {
        continue;
      }
      const item = new ReaderCanvasMarking();
      item.start = range.start;
      item.end = range.end;
      item.backgroundArgb = readerCanvasMarkingBackgroundArgb(marking);
      item.decoration = readerCanvasMarkingDecoration(marking);
      item.decorationArgb = readerCanvasArgb(marking.color, 0xFF000000);
      list.push(item);
    }
    return list;
  }

  /**
   * 批5（:123）标记渲染用的区间解析。
   *
   * 判定顺序（与上游 BookContentProcessEngine.kt:25-46 一致）：
   * 1. 当前语义正文里 `[chapterPosition, endPosition)` 取出来的文字等于 `selectedText` → 原偏移直接可用；
   * 2. 不等 → `locateAnchor` 三级退让重定位，命中就用重定位后的区间；
   * 3. 都不成 → 返回 undefined，调用方跳过这一条（不渲染，也不改存储）。
   * `selectedText` 为空的老数据（划线功能最早那批没存锚点文本）无法校验，按原偏移渲染，避免误吞已有标记。
   */
  private resolveMarkingRenderRange(marking: ReaderMarking): ReaderMarkingRange | undefined {
    const content = this.localSemanticContent;
    const storedStart = Math.max(0, marking.chapterPosition);
    const storedEnd = Math.max(storedStart, marking.endPosition);
    if (marking.selectedText.length === 0 || content.length === 0) {
      return { start: storedStart, end: storedEnd };
    }
    if (content.slice(storedStart, storedEnd) === marking.selectedText) {
      return { start: storedStart, end: storedEnd };
    }
    const relocated = BookContentProcessEngine.locateAnchor(content, marking.selectedText, storedStart);
    if (relocated === undefined) {
      return undefined;
    }
    return { start: relocated.start, end: relocated.end };
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

  /**
   * 批 11：读取本书的 EPUB 行内样式 sidecar（老书无此文件，返回 null）。
   * 样式在导入时按章下标落盘到 ${booksDirectory}/${bookId}.styles.json。
   */
  private epubInlineStylesForChapter(chapterIndex: number): EpubInlineStyleRange[] {
    const bookId = this.book.id;
    if (bookId.length === 0) { return []; }
    if (!this.epubStyleCache.has(bookId)) {
      let parsed: Record<string, EpubInlineStyleRange[]> | null = null;
      try {
        const context = this.getUIContext().getHostContext();
        if (context === undefined) { return []; }
        const stylesPath = `${context.filesDir}/books/${bookId}.styles.json`;
        if (fileIo.accessSync(stylesPath)) {
          const text = fileIo.readTextSync(stylesPath);
          if (text.length > 0) {
            const raw = JSON.parse(text) as Record<string, EpubInlineStyleRange[]>;
            parsed = raw;
          }
        }
      } catch (_) {
        // 格式损坏等异常按无样式处理，老书行为完全不变。
        parsed = null;
      }
      this.epubStyleCache.set(bookId, parsed);
    }
    const byChapter = this.epubStyleCache.get(bookId);
    if (byChapter === null || byChapter === undefined) { return []; }
    const ranges = byChapter[`${chapterIndex}`];
    return ranges === undefined ? [] : ranges;
  }

  /**
   * 批 11：把 sidecar 里的锚点样式转换到画布正文坐标系。
   * 锚点是导入时同一 htmlToText 管线的产物；替换规则/分段/缩进都会让原始数字偏移漂移，
   * 所以用 anchorText 在最终正文里 indexOf 重定位，searchFrom 递增防止重复词互相抢占。
   */
  private buildEpubStyleRanges(chapterIndex: number): ReaderCanvasStyleRange[] {
    const out: ReaderCanvasStyleRange[] = [];
    const styles = this.epubInlineStylesForChapter(chapterIndex);
    if (styles.length === 0) { return out; }
    let searchFrom = 0;
    for (const item of styles) {
      if (item === null || item === undefined || item.anchorText.length === 0) { continue; }
      const found = this.localSemanticContent.indexOf(item.anchorText, searchFrom);
      if (found < 0) { continue; }
      const start = found;
      const end = Math.min(this.localSemanticContent.length, start + item.anchorText.length);
      searchFrom = end;
      const range = new ReaderCanvasStyleRange();
      range.start = start;
      range.end = end;
      range.textColorArgb = item.colorArgb ?? 0;
      range.fontWeightValue = item.bold === true ? 700 : 0;
      range.italicOverride = item.italic === true ? 1 : 0;
      range.decoration = item.underline === true ? 1 : 0;
      // decorationArgb=0 时画布回退 textColorArgb；无色的下划线就用正文色。
      range.decorationArgb = 0;
      out.push(range);
    }
    return out;
  }

  private buildReaderCanvasHighlights(): ReaderCanvasStyleRange[] {
    const signature = `${this.readerContentRevision}|${this.readerHighlightRanges.length}|` +
      `${this.markings.length}|${this.getChapterIndex()}|` +
      `${this.readAloudSpan.revision}|${this.readAloudSpan.start}|${this.readAloudSpan.end}`;
    if (this.canvasHighlightSignature === signature) {
      return this.canvasHighlights;
    }
    const list: ReaderCanvasStyleRange[] = [];
    // 批 11：EPUB 行内样式先入列，随后 push 的用户高亮规则按数组顺序覆盖它。
    // 老书没有 sidecar，这里注入空数组，正文绘制与改动前逐字一致。
    for (const epubRange of this.buildEpubStyleRanges(this.getChapterIndex())) {
      list.push(epubRange);
    }
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
        readerCanvasHighlightDecoration(rule.underlineMode) !== 0 || (rule.bgImage ?? '').length > 0 ||
        (rule.borderColor ?? 0) !== 0 || (rule.underlineSvgPath ?? '').length > 0;
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
        // 自定义 SVG 下划线（mode 5）的路径串，空串表示没配
        item.underlineSvgPath = rule.underlineSvgPath ?? '';
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
        // 边框三件套是一个整体：颜色没给，粗细与圆角就不单独存在。
        item.borderColorArgb = rule.borderColor ?? 0;
        item.borderWidthPx = (rule.borderColor ?? 0) !== 0 ? (rule.borderWidth ?? 1) * vpScale : 0;
        item.borderRadiusPx = (rule.borderColor ?? 0) !== 0 ? (rule.borderRadius ?? 4) * vpScale : 0;
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
    // 批4：正在朗读的段落底色，取强调色（上游 resolvedColorArgb = accentColor）。
    // 半透明底色压在字形之下，跟随 onSpanChange 逐段移动。
    if (this.readAloudSpan.start >= 0 && this.readAloudSpan.end > this.readAloudSpan.start) {
      const spoken = new ReaderCanvasStyleRange();
      spoken.start = this.readAloudSpan.start;
      spoken.end = Math.min(this.readAloudSpan.end, this.localSemanticContent.length);
      spoken.backgroundArgb = readerCanvasArgb(this.textAccentColor, 0x22FFB1C8) & 0x3FFFFFFF;
      list.push(spoken);
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
   * 记下正文区的实测高度并驱动一次重排。
   * 页脚搬进画布后 Canvas 本身长高了 footerReserve，调用方已把那段扣掉再传进来，
   * 所以这里拿到的仍是「一页可分多少」的口径，不会因为多一条页脚就误判重排。
   */
  private syncReaderCanvasBodyHeight(heightVp: number): void {
    // 注意：Area 的 width/height 本来就是 vp（与 toDimension 的口径一致），
    // 这里绝不能再 px2vp 一次，否则分页高度会被缩小约 2.75 倍、一页只剩几行。
    if (heightVp <= 0) {
      return;
    }
    // 标题已进画布、不再占用画布外的纵向空间，首页与其余页的画布高度是同一个，
    // 不需要再对首页特殊处理（旧实现在首页跳过，是因为标题在画布之上）。
    // 亚像素（0.x vp）的测量差是正常噪声，不值得整章重排一次；1.5vp 以上才是真差异。
    if (Math.abs(heightVp - this.readerCanvasBodyHeightVp) < 1.5) {
      return;
    }
    // 批 3 确认打点：区分「第二次 rebuild 来自画布高度同步」而非图片路径。
    console.info(`[ReaderBench] canvasHeightRebuild deltaVp=${(heightVp - this.readerCanvasBodyHeightVp).toFixed(1)}`);
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
   * 批8 D 组（:923）：切换排版/背景样式时，带 configName 的规则命中集变了，
   * 必须重算高亮区间并重建分页，否则要翻页或改规则才生效（面板显示生效、正文不生效）。
   */
  onCurrentConfigNameChanged(): void {
    if (this.localSemanticContent.length === 0) { return; }
    const next = ReaderHighlightRuleEngine.findBodyRanges(
      this.localSemanticContent, this.readerHighlightRules, this.currentConfigName);
    this.readerHighlightRanges = next;
    this.readerSizeOffsets = this.buildReaderSizeOffsets();
    this.readerContentRevision++;
    this.rebuildReaderPages();
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
    // 图片解码尺寸要按版面实际铺开的像素算，而版面只在 layoutPage 里产出，
    // 所以预取要把当前的绘制请求一起传进去（批9 :1009）。
    this.readerCanvasRenderer.prefetch(window, this.buildReaderCanvasRequest(new ReaderTransitionTransforms()))
      .catch((error: Error) => {
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
    // 批5：上游 ReadStyleResolver.currentMode()/isNightTheme() 按主题模式判，不按纸色值。
    return this.readerMenuIsNight() ? '#ADADAD' : '#ff0b0b0b';
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
    // 上游 `LegacyReaderPageDecorationFactory.kt:333` 三档：1 显示 / 2 隐藏 / 0（含其它值）跟随状态栏。
    // 「跟随状态栏」= 状态栏显示时隐藏页眉，所以取 hideStatusBar 的反面；这一档下两者互斥、不同时出现。
    const mode = this.infoSettings.headerMode;
    if (mode === 1) { return true; }
    if (mode === 2) { return false; }
    return this.hideStatusBar;
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
    // 批5：上游 ReadBookConfig.tipHeaderColor 按 isNightTheme() 判（ReadBookConfig.kt:442）。
    const isNightPaper = this.readerMenuIsNight();
    const configuredColor = useHeaderStyle
      ? (isNightPaper ? this.infoSettings.tipHeaderColorNight : this.infoSettings.tipHeaderColor)
      : (isNightPaper ? this.infoSettings.tipFooterColorNight : this.infoSettings.tipFooterColor);
    if (configuredColor === 0) { return this.getReadingTextColor(); }
    const unsignedColor = configuredColor < 0 ? configuredColor + 4294967296 : configuredColor;
    const hexColor = unsignedColor.toString(16).padStart(8, '0');
    return `#${hexColor.substring(2)}`;
  }

  private getReaderInfoDividerColor(): string {
    // `-1` 是「跟随主题」的默认值。上游 `LegacyReaderPageDecorationFactory.kt:152` 取
    // `R.color.divider`，`app/src/main/res/values/colors.xml:591` 为 `#66666666`（alpha 0x66）。
    // 本地原先返回不带 alpha 的 6 位不透明深灰，比上游实心得多，页脚那道线才会抢注意力。
    if (this.infoSettings.tipDividerColor === -1) { return '#66666666'; }
    if (this.infoSettings.tipDividerColor === 0) { return this.getReadingTextColor(); }
    const unsignedColor = this.infoSettings.tipDividerColor < 0
      ? this.infoSettings.tipDividerColor + 4294967296 : this.infoSettings.tipDividerColor;
    const hexColor = unsignedColor.toString(16).padStart(8, '0');
    return `#${hexColor.substring(2)}`;
  }

  private getReaderInfoValue(type: number, customTemplate: string): string {
    const currentPage = this.localReaderPages[this.currentPageIndex];
    const chapterCount = this.getChapterCount();
    // 页层批次 4：页码 / 本章页数按当前章现算，窗口表含邻章页不能直接用 length。
    const pageCount = this.currentChapterPageCount();
    const localPageIndex = this.currentChapterPageIndex() + 1;
    const chapterTitle = this.displayChapterTitle;
    const time = new Date();
    const timeText = `${time.getHours().toString().padStart(2, '0')}:${time.getMinutes().toString().padStart(2, '0')}`;
    const batteryPercent = Math.max(0, Math.min(100, batteryInfo.batterySOC));
    const progressText = `${this.getWholeBookProgress().toFixed(1)}%`;
    const fullPageIndex = this.getWholeBookPageIndex();
    const fullPageCount = this.getWholeBookPageCount();
    // Android 的自定义占位符在整本页数暂不可用时回退到本章页码和页数。
    const customFullPageIndex = fullPageIndex > 0 ? `${fullPageIndex}` : `${localPageIndex}`;
    const customFullPageCount = fullPageCount > 0 ? `${fullPageCount}` : `${Math.max(1, pageCount)}`;
    let value = '';
    if (type === 1) { value = chapterTitle; }
    else if (type === 2) { value = timeText; }
    else if (type === 3 || type === 10 || type === 13 || type === 14 || type === 15) { value = `${batteryPercent}%`; }
    else if (type === 4) { value = `${localPageIndex}/${pageCount > 0 ? pageCount : '-'}`; }
    else if (type === 5) { value = progressText; }
    else if (type === 6) { value = `${localPageIndex}/${pageCount > 0 ? pageCount : '-' }  ${progressText}`; }
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
        .replaceAll('{PageIndex}', `${localPageIndex}`)
        .replaceAll('{PageSize}', `${pageCount > 0 ? pageCount : '-'}`)
        .replaceAll('{PageRemaining}', `${pageCount > 0 ? Math.max(0, pageCount - localPageIndex) : '-'}`)
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
            // 页眉也搬进画布（见 headerDecoration）：这里不再放 ArkUI 节点，
            // 否则 Canvas 会被压矮一整条页眉，正文原点又会与 layout.originYpx 重复偏移。
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
                // 页眉页脚都搬进画布后 Canvas 实测高度里同时含状态栏占位与这两段预留，
                // 都要扣掉才是「正文区高」；漏一段就会让实测值比公式多一整条装饰，
                // syncReaderCanvasBodyHeight 再触发 rebuildReaderPages()，批 3 的抖动就回来了。
                this.syncReaderCanvasBodyHeight(readerLengthToNumber(newArea.height) -
                  this.readerStatusBarReserve() -
                  (this.isReaderHeaderVisible() ? this.getReaderInfoReserve(true) : 0) -
                  (this.isReaderFooterVisible() ? this.getReaderInfoReserve(false) : 0));
                this.paintReaderCanvas();
              })
            // 页脚已搬进画布（见 footerDecoration）：这里不再放 ArkUI 节点，
            // 否则 Canvas 会被压矮一整条页脚、装饰线又会浮在界面层而不是纸上。
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
              top: this.readerStatusBarReserve() +
                this.paddingSettings.paddingTop + (this.isReaderHeaderVisible() ? this.getReaderInfoReserve(true) : 0),
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
              // 上面更新的是「下一帧」锚点用的实际尺寸。展开态条目折行后实测比上一帧宽，
              // 右端会顶出屏幕被裁（实测 1056px 卡片停在 x=224，右侧 80px 不可见）。
              // 这里用刚量到的尺寸把位置收回屏内，位置变化不会再改尺寸，不会自激。
              if (widthVp > 0 && this.readerContentWidth > 0) {
                const maxX = Math.max(4, this.readerContentWidth - widthVp - 4);
                if (this.canvasSelectionMenuX > maxX) {
                  this.canvasSelectionMenuX = maxX;
                }
              }
              if (heightVp > 0 && this.viewportHeight > 0) {
                const maxY = Math.max(0, this.viewportHeight - heightVp - 4);
                if (this.canvasSelectionMenuY > maxY) {
                  this.canvasSelectionMenuY = maxY;
                }
              }
            })
          }
          // 批5（:127）行内快速标记面板：锚在划词菜单让出来的位置（菜单本来就贴着选区），
          // 七种样式 + 备注 + 应用/删除；落库走 Index 侧标记仓储，不经过标记编辑 Sheet。
          if (this.quickMarkVisible) {
            Column() {
              ReaderQuickMarkPanel({
                quickStyle: this.quickMarkStyle,
                quickNote: this.quickMarkNote,
                existingMarking: this.quickMarkExistingId.length > 0,
                onStyleChange: (style: ReaderMarkingEffect) => {
                  this.quickMarkStyle = style;
                },
                onNoteChange: (note: string) => {
                  this.quickMarkNote = note;
                },
                onApply: () => {
                  this.applyQuickMarking();
                },
                onDelete: () => {
                  this.deleteQuickMarking();
                },
                onClose: () => {
                  this.closeQuickMarkPanel();
                }
              })
            }
            .position({ x: this.quickMarkAnchorX, y: this.quickMarkAnchorY })
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
              // 与分页翻页、惯性滚动同口径：命中边界就转成换章。
              //
              // 页层批次 4：这里**不再**在发过请求后丢弃后续帧。旧实现一命中边界就把
              // `scrollDragBoundaryTurned` 当闸门、`return` 掉所有帧，而换章要
              // `await readChapter` 读盘，那段时间手指还在动、画面却完全不动 ——
              // 用户只能松手再滑一次。现在帧照常喂给 `applyReaderScrollDelta`：
              // 章末之后是占位页/邻章页，位移能继续往前走，画面跟着手指走。
              // 闸门只负责「一次拖动只发一次换章请求」，防连跳。
              const hitBoundary = this.applyReaderScrollDelta(this.getUIContext().vp2px(deltaVp));
              if (hitBoundary && !this.scrollDragBoundaryTurned) {
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
          PanGesture({ direction: this.swipeToAddBookmark && this.book.isLocal && this.effectivePageAnim() !== 3
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
            .fontSize(TITLE_SMALL).fontColor('#FFFFFF')
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
                }.width(this.readerTopBarButtonOuterSize()).height(this.readerTopBarButtonOuterSize()).onClick(() => this.onBack())
                // 胶囊模式：书名 + 章节名压成一行两段，独占中间剩余宽度（上游 ReadBookMenuBarTitle.kt:198/492）。
                if (this.readerTitleCapsuleVisible()) {
                  this.readerTitleCapsule()
                } else {
                  // 非胶囊模式：仅 titleBarMode 为 "0"/"2" 时书名留在应用栏行内（:207）。
                  if (this.readerTitleInlineVisible()) {
                    // 上游 `ReadBookMenuBarTitle.kt:207-221`：非胶囊模式的书名同样 combinedClickable
                    // 进书籍详情，不是纯展示文本。
                    // 上游 `ReadBookMenuBarTitle.kt:213` 的书名是 `maxLines = 2`
                    // （`maxLines(2)` + `Ellipsis` 正是上游的组合，不要删 textOverflow）。
                    Text(this.book.title).fontSize(BODY_MEDIUM).fontColor(this.readerMenuForeground()).maxLines(2)
                      .layoutWeight(1).padding({ left: 8, right: 8, top: 4, bottom: 4 })
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                      .textShadow(this.readerMenuTextShadow())
                      .onClick(() => this.onOpenBookInfo())
                      .gesture(LongPressGesture({ duration: 500 }).onAction((_event: GestureEvent): void => {
                        this.onOpenBookInfo();
                      }))
                  }
                  Blank().layoutWeight(1)
                }
                this.readerTopActionGroup()
              // top 里叠上 appTopInset：原来写死 12，顶栏按钮压在状态栏图标上。
              // 上游让位在面板层（`ReadBookMenuBarTitle.kt:167-171` 的 windowInsetsPadding），
              // 本地面板只有这一行，加到行 padding 上等价。
              }.width('100%').padding({ left: 16, right: 16, top: 12 + this.appTopInset, bottom: 4 })
              // 模式 "1"：书名单独占一行（上游 :239）。
              if (this.readerTitleOwnLineVisible()) {
                // 上游 `ReadBookMenuBarTitle.kt:241`：独占一行的书名 `maxLines = 2`，同样可点进详情。
                Text(this.book.title).fontSize(BODY_MEDIUM).fontColor(this.readerMenuForeground()).maxLines(2)
                  .width('100%').padding({ left: 16, right: 16, top: 4, bottom: 4 })
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                  .textShadow(this.readerMenuTextShadow())
                  .onClick(() => this.onOpenBookInfo())
                  .gesture(LongPressGesture({ duration: 500 }).onAction((_event: GestureEvent): void => {
                    this.onOpenBookInfo();
                  }))
              }
              // 模式 "0"/"1"：章节名独占一行（上游 :259）。
              if (this.readerChapterLineVisible()) {
                Row() {
                  Text(this.displayChapterTitle).fontSize(BODY_SMALL).fontColor(this.readerMenuForeground()).maxLines(1)
                    .textShadow(this.readerMenuTextShadow())
                    .layoutWeight(1).padding({ left: 16, top: 4, bottom: 8 })
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                  // 上游 `ReadBookMenuBarTitle.kt:288-311`：章名行右侧还有一个书源名，点开书源下拉。
                  // 批10（:569）之前这里留空（注释写「书源引擎未接入」已过时，批8 起在线书能进阅读页）。
                  // 有书源时显示源名文本 + 书源下拉入口；没有源（本地书 / 源已删）整段不画。
                  if (this.bookSourceName.length > 0) {
                    Row() {
                      Text(this.bookSourceName).fontSize(BODY_SMALL).fontColor(this.readerMenuForegroundAlpha('B3'))
                        .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
                        .textShadow(this.readerMenuTextShadow())
                    }.padding({ left: 8, right: 16, top: 4, bottom: 8 })
                      .onClick(() => this.onOpenSourceMenu())
                  }
                }.width('100%')
              }
            }
            .width('100%')
            // 渐变档下透明端会露出 backgroundColor 的实色，方向一改就露馅，
            // 所以渐变档把底色让给渐变（上游 `ReaderMenuVisuals.kt:12-25` 只用 Brush，不再叠实色）。
            .backgroundColor(this.readMenuTopBarBlurStyle === 1 ? Color.Transparent : this.readerTopBarFillColor())
            .linearGradient(this.readerTopBarGradient())
            // KI-E2：菜单栏边框（宽度同时是开关）与背景模糊半径，对齐上游
            // `ReadBookMenuBarTitle.kt:504-521`（描边）与 `:131`（`blurRadius = readMenuBlurRadius`）。
            .border(this.readerMenuBorderSettings())
            // 模糊只在该档启用时才开：None 档靠底色/渐变显形，不该整片模糊。
            .backdropBlur(this.readerTopBarBlurRadiusVp())

          // KI-E3：位置 0/1 的浮动图标行贴在顶栏下方（上游 ReadBookMenuBar.kt:172）。
          if (this.readerFloatingIconTopVisible()) {
            this.readerFloatingIconRow(this.titleBarIconPosition)
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
              // 换章按钮尺寸跟随玻璃开关：上游 `ReadBookMenuBarBottom.kt:161-196` 用的是
              // 与底栏按钮同一个 `BottomBarGlassIconButton`（`buttonGlassEnabled ? 48 : 40`）。
              Stack({ alignContent: Alignment.Center }) {
                Image($r('app.media.reader_back')).width(20).height(20).fillColor(this.readerMenuForeground())
              }.width(this.readerBottomActionOuterSize()).height(this.readerBottomActionOuterSize())
                .onClick(() => this.turnReaderChapter(-1))
              if (this.readSliderMode !== '1') {
                // 上游 `ReadMenuSlider`（`ReadBookMenuBarTool.kt:67-113`）普通档走
                // `AppSlider` → material3 `Slider` 默认外观，也就是 M3 的形态：
                // 16dp 粗轨道 + 4dp×44dp 的竖条 handle + 轨道上的小圆点刻度。
                // ArkUI 系统 Slider 的 DEFAULT 拇指只能是圆点、SHAPE 需要 RectAttribute 实例
                // （组件构建器造不出来），所以这里拆成两层：系统 Slider 负责轨道/刻度/拖拽，
                // 拇指改成自绘的竖条叠在上面，按同一百分比定位。
                Stack({ alignContent: Alignment.Center }) {
                  Slider({
                    value: this.sliderProgressIndex,
                    min: 0,
                    max: Math.max(0, this.getProgressSliderMaximum()),
                    step: 1,
                    style: SliderStyle.InSet
                  })
                    .width('100%').height(52)
                    .selectedColor(this.readerMenuAccentTint())
                    .trackColor(this.readerMenuForegroundAlpha('33'))
                    // 系统圆点拇指涂透明，位置让给下面的竖条。
                    .blockColor(Color.Transparent)
                    .blockBorderColor(Color.Transparent)
                    .trackThickness(16)
                    // 刻度是轨道上的小暗点，不是一排强调色亮点。
                    .showSteps(true).stepColor(this.readerMenuForegroundAlpha('73')).stepSize(4)
                    .enabled(Math.max(0, this.getProgressSliderMaximum()) > 0)
                    .onAreaChange((_oldArea: Area, newArea: Area) => {
                      const width = Number(newArea.width);
                      if (!Number.isNaN(width) && width > 0) { this.sliderTrackWidth = width; }
                    })                    // 无障碍文案：上游 `ReadBookMenuBarBottom.kt:84-95` 按 `progressBarBehavior`
                    // 念「第 x / 共 y 页」或「第 x / 共 y 章」。本地没有读屏器自定义能力，
                    // 用 `accessibilityText` 把同一句挂在滑块上。
                    .accessibilityText(this.getProgressAccessibilityText())
                    .onChange((value: number, mode: SliderChangeMode) => {
                      const maximum = this.getProgressSliderMaximum();
                      const index = Math.max(0, Math.min(maximum, Math.round(value)));
                      // 松手/点击之后不再处于拖动过程，清掉预览页号，下一次拖动重新从 -1 起算。
                      if (mode !== SliderChangeMode.Moving) {
                        this.sliderDragPreviewPageIndex = -1;
                      }
                      this.sliderProgressIndex = index;
                      if (this.isPageProgressMode()) {
                        // 拖动过程中同一个整数值会被连续派发，已经停在这一页就不再重绘。
                        if (mode === SliderChangeMode.Moving && index === this.sliderDragPreviewPageIndex) {
                          return;
                        }
                        this.sliderDragPreviewPageIndex = index;
                        this.seekToChapterPage(index);
                      } else if (mode === SliderChangeMode.End || mode === SliderChangeMode.Click) {
                        this.onSelectChapterIndex(index);
                      }
                    })
                  // 自绘竖条拇指：M3 的 handle 是 4dp 宽、44dp 高的圆角竖条（上游
                  // `ReadBookMenuBarTool.kt:320`），ArkUI 系统 Slider 的拇指只能是圆点
                  // （SHAPE 档要 RectAttribute 实例，组件构建器造不出来），所以在轨道上
                  // 按同一百分比叠一根竖条。竖条尺寸就地写字面量，只有这一处用。
                  // Stack 是 Center 对齐，offset 从中心起算。
                  Row()
                    .width(4).height(44).borderRadius(2)
                    .backgroundColor(this.readerMenuForeground())
                    .offset({ x: this.sliderThumbOffset() })
                    .hitTestBehavior(HitTestMode.None)
                }.layoutWeight(1).height(52)
                  // 内缩 18vp/侧，上游是三层叠加：`ReadBookMenuBarBottom.kt:165` 的 16dp
                  // 行内边距已由外层 Row 承担，这里只补
                  // `ReadBookMenuBarBottom.kt:194-196` 的 `padding(horizontal = 8.dp)`
                  // + `ReadBookMenuBarTool.kt:104` 的 5dp + `ReaderMenuPrimitives.kt:121` 的 5dp
                  // = 8+5+5 = 18vp。玻璃拇指档（`ReadMenuLiquidSlider`，
                  // `ReadBookMenuBarTool.kt:81` 起）不叠那两层 5dp，是 13vp。
                  .padding({ left: 18, right: 18 })
              }
              Stack({ alignContent: Alignment.Center }) {
                Image($r('app.media.reader_arrow_forward')).width(20).height(20).fillColor(this.readerMenuForeground())
              }.width(this.readerBottomActionOuterSize()).height(this.readerBottomActionOuterSize())
                .onClick(() => this.turnReaderChapter(1))
            }.width('100%').height(this.readerBottomActionOuterSize())
              // 上游 `ReadBookMenuBarBottom.kt:162-169`：`padding(vertical = 4.dp).padding(horizontal = 16.dp)`。
              .padding({ left: 16, right: 16, top: 4, bottom: 4 })
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
                          itemFill: this.readerMenuItemFill(false, this.bottomIconStyle),
                          itemFillSelected: this.readerMenuSelectedFill(),
                          menuForegroundAlpha: this.readerMenuForegroundAlpha('73'),
                          outerSize: this.readerBottomActionOuterSize(),
                          onSelect: () => this.selectBottomAction(kind),
                          onLongSelect: () => this.longSelectBottomAction(kind)
                        }).width(this.readerBottomActionOuterSize())
                      }, (kind: ReaderControlKind) => kind)
                    }.width('100%').justifyContent(FlexAlign.SpaceBetween)
                  }, (_row: ReaderControlKind[], rowIndex: number) => `${_pageIndex}-${rowIndex}`)
                }.width('100%').justifyContent(FlexAlign.Center)
              }, (_rows: ReaderControlKind[][], pageIndex: number) => `${pageIndex}`)
            }
              .width('100%')
              .index(this.getBottomActionPageIndex())
              // 高度算式参数化：`+ 24` / `+ 8` 是从旧常量反推的（40+24=64、40+8=48），
              // 40 档时结果与改前完全一致；玻璃档按钮变 48，两个档位各自跟上。
              .height((this.showBottomActionText ? this.readerBottomActionOuterSize() + 24
                : this.readerBottomActionOuterSize() + 8)
                * Math.max(1, Math.min(2, this.bottomRowCount)) + ReaderPage.BOTTOM_ACTION_PADDING)
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
            // 非悬浮档在底部叠 appBottomInset：上游 `ReadBookMenuBar.kt:500-506` 非悬浮时
            // 底色一路铺到导航栏、`:629` 用 `bottomPadding = navBarHeight + 16.dp` 让内容避让，
            // 本地缺的就是这份内容让位。悬浮档靠下面的 margin bottom 16 已让开，不重复叠。
            .padding({
              left: 8,
              right: 8,
              top: 12,
              bottom: this.readMenuFloatingBottomBar ? 0 : this.appBottomInset
            })
            // 同顶栏：渐变档让底色给渐变，避免透明端露出实色。
            .backgroundColor(this.readMenuBottomBarBlurStyle === 1 ? Color.Transparent : this.readerBottomBarFillColor())
            .linearGradient(this.readerBottomBarGradient())
            // KI-E2：底栏同样吃边框与模糊半径，对齐上游 `ReadBookMenuBar.kt:450`（描边）
            // 与 `:1027`（`blurRadius = menuConfig.readMenuBlurRadius`）。
            .border(this.readerMenuBorderSettings())
            .backdropBlur(this.readerBottomBarBlurRadiusVp())
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
              .backdropBlur(this.readerBottomBarBlurRadiusVp())
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
          // 上游 `ReadBookSearchBar.kt:41-91`：`AppFloatingActionButton` 没传 size，
          // 用 M3 默认 56dp；底色 `surfaceContainerLow`（= 菜单容器色），图标色 `onSurfaceVariant`；
          // 带 FAB 阴影、没有描边（`border` 默认 null）。
          // 「跟随阅读背景」档下 `surfaceContainerLow` 就是纸色（`ReadBookColorTheme.kt:270-284`），
          // 与正文同色，全靠 elevation 6dp 托起。实测 `.shadow` 在深色纸面上采样与背景同值
          // （#1A1A1A），看不出边界，所以按任务书 7.1 的退化条款改用淡描边，不同时上两样。
          if (this.searchNavIndex > 0) {
            Stack({ alignContent: Alignment.Center }) {
              Image($r('app.media.reader_back')).width(20).height(20).fillColor(this.readerMenuForeground())
            }
            .width(56).height(56).borderRadius(28)
            .backgroundColor(this.readerMenuContainerBaseColor())
            .border({ width: 1, color: this.readerMenuForegroundAlpha('14') })
            .onClick(() => this.onOpenSearchNavItem(this.searchNavIndex - 1))
            .accessibilityText('上一个结果')
          }
          Blank().layoutWeight(1)
          if (this.searchNavIndex < this.searchNavItems.length - 1) {
            Stack({ alignContent: Alignment.Center }) {
              Image($r('app.media.reader_arrow_forward')).width(20).height(20).fillColor(this.readerMenuForeground())
            }
            .width(56).height(56).borderRadius(28)
            .backgroundColor(this.readerMenuContainerBaseColor())
            .border({ width: 1, color: this.readerMenuForegroundAlpha('14') })
            .onClick(() => this.onOpenSearchNavItem(this.searchNavIndex + 1))
            .accessibilityText('下一个结果')
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
          // 上游 `ReadBookMenuBarSearch.kt`：父 Column 给 `padding(top = 12, horizontal = 16)`，
          // 即结果条占满屏宽减 32vp，不再是本地的 88% 居中。
          Column() {
            // 信息 pill：上游 `SearchPillSurface` 高 40、圆角 16、`surfaceContainerLow` 底
            // （= 菜单容器色）、横向内边距 12。N/M 用 `labelSmallEmphasized` = 11sp。
            Row() {
            Text((this.searchNavIndex + 1).toString() + ' / ' + this.searchNavItems.length.toString())
              .fontSize(LABEL_SMALL).fontColor(this.readerMenuForeground())
            Blank().width(8)
            // 百分比徽标走上游 `TextCard` 默认值：11sp、圆角 8、内边距 H8 V4、底色 `surfaceContainer`
            // （本地取菜单背景色近似，容器色是 surfaceContainerLow，低一档）。
            Text(Math.round((this.searchNavIndex + 1) * 100 / this.searchNavItems.length).toString() + '%')
              .fontSize(LABEL_SMALL).fontColor(this.readerMenuAccentTint())
              .padding({ left: 8, right: 8, top: 4, bottom: 4 })
              .backgroundColor(this.readerMenuBaseColor()).borderRadius(8)
            Blank().width(16)
            // 分隔线：上游 `outlineVariant` 实色，深色下约 40% 量级。
            Column().width(1).height(8).backgroundColor(this.readerMenuForegroundAlpha('66'))
            Blank().width(16)
            Text(this.currentSearchNavTitle())
              .fontSize(LABEL_SMALL).fontColor(this.readerMenuForeground()).maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis }).layoutWeight(1)
          }
          .width('100%').height(40).padding({ left: 12, right: 12 })
          .backgroundColor(this.readerMenuContainerBaseColor()).borderRadius(16)
          .border(this.readerMenuBorderSettings())

          // 三枚按钮：权重 2 : 1 : 0.55（上游 SearchBottomMenuContent）。
          // 图标色走上游 `primary`（本地强调色），文字 `onSurfaceVariant`（本地前景色）、13sp。
          Row({ space: 8 }) {
            Row({ space: 8 }) {
              Image($r('app.media.app_search')).width(16).height(16).fillColor(this.readerMenuAccentTint())
              Text('所有结果').fontSize(LABEL_MEDIUM).fontColor(this.readerMenuForeground()).maxLines(1)
            }
            .layoutWeight(2).height(40).justifyContent(FlexAlign.Center)
            .padding({ left: 12, right: 12 })
            .backgroundColor(this.readerMenuContainerBaseColor()).borderRadius(16)
            .border(this.readerMenuBorderSettings())
            .onClick(() => this.onOpenSearchContent())

            // 上游这枚按钮带「主菜单」文字，不只是纯图标。
            Row({ space: 8 }) {
              Image($r('app.media.app_more')).width(16).height(16).fillColor(this.readerMenuAccentTint())
              Text('主菜单').fontSize(LABEL_MEDIUM).fontColor(this.readerMenuForeground()).maxLines(1)
            }
            .layoutWeight(1).height(40).justifyContent(FlexAlign.Center)
            .padding({ left: 12, right: 12 })
            .backgroundColor(this.readerMenuContainerBaseColor()).borderRadius(16)
            .border(this.readerMenuBorderSettings())
            .onClick(() => { this.controlsVisible = true; })

            Row() {
              AppGlyph({ name: 'profileClose', glyphSize: 16, tint: this.readerMenuAccentTint() })
            }
            .layoutWeight(0.55).height(40).justifyContent(FlexAlign.Center)
            .padding({ left: 12, right: 12 })
            .backgroundColor(this.readerMenuContainerBaseColor()).borderRadius(16)
            .border(this.readerMenuBorderSettings())
            .onClick(() => this.onCloseSearchResult())
            .accessibilityText('退出')
          }
          .width('100%').margin({ top: 8 })
          }
          .width('100%')
          .padding({ left: 16, right: 16 })
          .margin({ top: 12, bottom: 24 })
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
              Text('返回原阅读位置').fontSize(LABEL_LARGE).fontColor('#ECEEF4')
            }.layoutWeight(1).onClick(() => this.onRestoreReadingAnchor())
            Text('关闭').fontSize(LABEL_MEDIUM).fontColor('#BFC2CD').padding({ left: 12, right: 6 })
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
              Text('自动翻页').fontSize(BODY_LARGE).fontWeight(FontWeight.Medium).fontColor('#ECECF0')
              Blank()
              Text('×').fontSize(HEADLINE_MEDIUM).fontColor('#C8C9D0').onClick(() => this.autoPageSettingsVisible = false)
            }.width('100%').padding({ bottom: 18 })
            Row() {
              Text('翻页间隔').fontSize(TITLE_SMALL).fontColor(this.themeColorTextSecondary)
              Blank()
              Text(`${this.autoReadSpeedSeconds} 秒`).fontSize(TITLE_SMALL).fontColor(this.themeColorTextSecondary)
            }.width('100%')
            Slider({ value: this.autoReadSpeedSeconds, min: 1, max: 120, step: 1, style: SliderStyle.InSet })
              .width('100%').selectedColor('#B9C6FF').trackColor('#565A6B').blockColor('#B9C6FF')
              .onChange((value: number, mode: SliderChangeMode) => {
                if (mode === SliderChangeMode.Moving || mode === SliderChangeMode.Click || mode === SliderChangeMode.End) {
                  this.setAutoPageSpeed(value);
                }
              })
            Row() {
              Text('目录').fontSize(LABEL_MEDIUM).fontColor('#E2E3E8').textAlign(TextAlign.Center).layoutWeight(1)
                .onClick(() => { this.autoPageSettingsVisible = false; this.onOpenCatalog(); })
              Text('停止').fontSize(LABEL_MEDIUM).fontColor('#E2E3E8').textAlign(TextAlign.Center).layoutWeight(1)
                .onClick(() => { this.autoPageActive = false; this.autoPageSettingsVisible = false; this.stopAutoPageTimer(); })
              Text('翻页设置').fontSize(LABEL_MEDIUM).fontColor('#E2E3E8').textAlign(TextAlign.Center).layoutWeight(1)
                .onClick(() => { this.autoPageSettingsVisible = false; this.onOpenSettings(); })
            }.width('100%').padding({ top: 18, bottom: 10 })
          }.width('100%').padding({ left: 20, right: 20, top: 18, bottom: 22 })
            .backgroundColor('#D931282A').borderRadius({ topLeft: 24, topRight: 24 })
        }.width('100%').height('100%').backgroundColor('#66000000')
          .onClick(() => this.autoPageSettingsVisible = false)
      }

      if (this.controlsVisible && this.overflowVisible) {
        ReaderSheetShell({
          scrimColor: '#66000000',
          panelColor: this.themeColorSurfaceSecondary,
          panelHeight: '52%',
          onDismiss: () => {
            this.overflowVisible = false;
            this.imageStyleMenuVisible = false;
          }
        }) {
            Row() {
              BookCover({ book: this.book, mini: true }).margin({ right: 12 })
              Column() {
                Text(this.book.title).fontSize(LABEL_LARGE).fontWeight(FontWeight.Medium).fontColor('#E5E6EB')
                  .maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
                Text(this.displayChapterTitle).fontSize(LABEL_SMALL).fontColor('#B7B8C1').maxLines(1)
                  .margin({ top: 4 })
              }.layoutWeight(1).alignItems(HorizontalAlign.Start)
              Text(`${this.getChapterIndex() + 1} / ${this.getChapterCount()}`)
                .fontSize(LABEL_SMALL).fontColor('#E5E6EB').padding({ left: 10, right: 10, top: 7, bottom: 7 })
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
                          .fontSize(LABEL_SMALL).fontColor('#E1DADD').textAlign(TextAlign.Center)
                          .maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
                        if (!action.migrated) {
                          Text('未迁移').fontSize(LABEL_SMALL).fontColor(this.themeColorTextTertiary).margin({ top: 2 })
                        }
                        // 上游 ReaderMenuActionSquare.kt:72-84：格子底部 16dp 点击带 + 12dp 展开箭头，
                        // 只有需要二次选择的条目才有（换源 / 刷新 / 自定义按钮）。
                        if (this.moreActionHasSubmenu(action.id)) {
                          Divider().color(this.readerMenuForegroundAlpha('26')).strokeWidth(1).width('100%')
                          // 这条 16 高的点击带是独立点击区：点它只展开二级菜单，不触发格子本身的主操作。
                          Row() {
                            AppGlyph({ name: 'profileExpandMore', tint: this.readerMenuForeground(), glyphSize: 12 })
                          }.width('100%').height(16).justifyContent(FlexAlign.Center)
                            .onClick(() => {
                              this.moreActionMenuId = this.moreActionMenuId === action.id ? '' : action.id;
                            })
                        }
                      }.width('100%').aspectRatio(1).justifyContent(FlexAlign.Center)
                        .backgroundColor(this.moreActionMenuId === action.id
                          ? this.readerMenuSelectedFill()
                          : this.themeColorSurfaceSecondary).borderRadius(16)
                        .onClick(() => this.selectMoreAction(action))
                        // 批10（:570）「换源 / 刷新章节」两格长按弹二级菜单，对齐上游
                        // `ReadMenuLongPressDropdown`（`ReadBookMenuBarTitle.kt:796-821`）。
                        // 其余格子没有二级菜单，长按不挂手势，行为与改前一致。
                        .gesture(LongPressGesture({ duration: 500 }).onAction((_event: GestureEvent): void => {
                          if (action.id === 'change_source' || action.id === 'refresh') {
                            this.longPressMenuId = action.id;
                          }
                        }))
                    }
                  }, (action: ReaderMoreAction) => action.id)
                }.edgeEffect(EdgeEffect.None).columnsTemplate('1fr 1fr 1fr 1fr').rowsGap(8).columnsGap(8).width('100%')
              }, (page: ReaderMoreAction[], pageIndex: number) => `page-${pageIndex}`)
            }.loop(false).indicator(false)
              .onChange((index: number) => {
                this.moreActionPage = index;
                // 翻页时清掉三角展开态：展开的那一格已经不在视野里。
                this.moreActionMenuId = '';
              })
              .width('100%').layoutWeight(1)
            Row() {
              ForEach(this.getMoreActionPages(), (page: ReaderMoreAction[], pageIndex: number) => {
                Row().width(6).height(6).borderRadius(3).margin({ right: 5 })
                  .backgroundColor(pageIndex === this.moreActionPage ? '#E5E6EB' : '#5A5C66')
              }, (page: ReaderMoreAction[], pageIndex: number) => `dot-${pageIndex}`)
            }.width('100%').justifyContent(FlexAlign.Center).padding({ bottom: 12 })
        }
      }

      if (this.imageStyleMenuVisible) {
        Stack({ alignContent: Alignment.Center }) {
          Column().width('100%').height('100%').backgroundColor('#88000000')
            .onClick(() => this.imageStyleMenuVisible = false)
          Column() {
            Row() {
              Text('图片样式').fontSize(BODY_LARGE).fontWeight(FontWeight.Medium).fontColor('#E5E6EB')
              Blank()
              Text('关闭').fontSize(LABEL_MEDIUM).fontColor('#C7C9D1').onClick(() => this.imageStyleMenuVisible = false)
            }.width('100%').padding({ bottom: 12 })
            ForEach(READER_IMAGE_STYLE_OPTIONS, (style: ReaderImageStyleOption) => {
              Row() {
                Text(style.label).fontSize(LABEL_LARGE_EMPHASIZED).fontColor('#E5E6EB').layoutWeight(1)
                if (this.activeImageStyle === style.id) {
                  AppGlyph({ name: 'profileCheck', glyphSize: 18, tint: '#B9C6FF' })
                }
              }.width('100%').padding({ left: 12, right: 12, top: 12, bottom: 12 })
                .backgroundColor(this.themeColorSurfaceSecondary).borderRadius(12).margin({ bottom: 6 })
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
              Text('翻页动画').fontSize(BODY_LARGE).fontWeight(FontWeight.Medium).fontColor('#E5E6EB')
              Blank()
              Text('关闭').fontSize(LABEL_MEDIUM).fontColor('#C7C9D1')
                .onClick(() => this.pageAnimMenuVisible = false)
            }.width('100%').padding({ bottom: 12 })
            // 「默认」档（上游 R.string.btn_default_s → -1）：回落全局设置；未设置同义。
            Row() {
              Text('默认').fontSize(LABEL_LARGE_EMPHASIZED).fontColor('#E5E6EB').layoutWeight(1)
              if (this.selectedPageAnimIndex() === READER_PAGE_ANIM_DEFAULT) {
                AppGlyph({ name: 'profileCheck', glyphSize: 18, tint: '#B9C6FF' })
              }
            }.width('100%').padding({ left: 12, right: 12, top: 12, bottom: 12 })
              .backgroundColor(this.themeColorSurfaceSecondary).borderRadius(12).margin({ bottom: 6 })
              .onClick(() => this.choosePageAnim(READER_PAGE_ANIM_DEFAULT))
            ForEach(READER_PAGE_ANIMATION_LABELS, (label: string, index: number) => {
              Row() {
                Text(label).fontSize(LABEL_LARGE_EMPHASIZED).fontColor('#E5E6EB').layoutWeight(1)
                if (this.selectedPageAnimIndex() === index) {
                  AppGlyph({ name: 'profileCheck', glyphSize: 18, tint: '#B9C6FF' })
                }
              }.width('100%').padding({ left: 12, right: 12, top: 12, bottom: 12 })
                .backgroundColor(this.themeColorSurfaceSecondary).borderRadius(12).margin({ bottom: 6 })
                .onClick(() => this.choosePageAnim(index))
            }, (label: string) => label)
          }.width('86%').padding(16).backgroundColor(this.themeColorSurfaceSecondary).borderRadius(20)
        }.width('100%').height('100%')
      }

      if (this.simulatedReadingVisible) {
        Stack({ alignContent: Alignment.Center }) {
          Column().width('100%').height('100%').backgroundColor('#88000000')
            .onClick(() => this.simulatedReadingVisible = false)
          Column() {
            Row() {
              Text('模拟追读').fontSize(BODY_LARGE).fontWeight(FontWeight.Medium).fontColor('#E5E6EB')
              Blank()
              Text('关闭').fontSize(LABEL_MEDIUM).fontColor('#C7C9D1')
                .onClick(() => this.simulatedReadingVisible = false)
            }.width('100%').padding({ bottom: 12 })
            Row() {
              Column() {
                Text('模拟追读').fontSize(TITLE_SMALL_EMPHASIZED).fontColor('#E5E6EB')
                Text('按开始日与日更数逐日解锁章节，追到最新即停')
                  .fontSize(LABEL_SMALL).fontColor('#9AA0AA').margin({ top: 2 })
              }.alignItems(HorizontalAlign.Start).layoutWeight(1)
              UiSwitchControl({
                checked: this.simReadEnabled,
                onChange: (isOn: boolean) => { this.simReadEnabled = isOn; }
              })
            }.width('100%').padding({ left: 12, right: 12, top: 10, bottom: 10 })
              .backgroundColor(this.themeColorSurfaceSecondary).borderRadius(12).margin({ bottom: 6 })
            Row() {
              Text('开始日').fontSize(TITLE_SMALL).fontColor('#E5E6EB').layoutWeight(1)
              Text(this.simReadStartDate.length > 0 ? this.simReadStartDate : '今天')
                .fontSize(LABEL_MEDIUM).fontColor('#B9C6FF')
            }.width('100%').padding({ left: 12, right: 12, top: 12, bottom: 12 })
              .backgroundColor(this.themeColorSurfaceSecondary).borderRadius(12).margin({ bottom: 6 })
              .onClick(() => this.openSimReadDatePicker())
            Row() {
              Text('日更数').fontSize(TITLE_SMALL).fontColor('#E5E6EB').layoutWeight(1)
              TextInput({ text: this.simReadDailyInput, placeholder: '3' })
                .width(100).fontSize(TITLE_SMALL).fontColor('#E5E6EB')
                .backgroundColor(this.themeColorSurfaceTertiary).borderRadius(8)
                .onChange((text: string) => { this.simReadDailyInput = text; })
            }.width('100%').padding({ left: 12, right: 12, top: 10, bottom: 10 })
              .backgroundColor(this.themeColorSurfaceSecondary).borderRadius(12).margin({ bottom: 6 })
            Row() {
              Text('起始章').fontSize(TITLE_SMALL).fontColor('#E5E6EB').layoutWeight(1)
              TextInput({ text: this.simReadStartChapterInput, placeholder: '0' })
                .width(100).fontSize(TITLE_SMALL).fontColor('#E5E6EB')
                .backgroundColor(this.themeColorSurfaceTertiary).borderRadius(8)
                .onChange((text: string) => { this.simReadStartChapterInput = text; })
            }.width('100%').padding({ left: 12, right: 12, top: 10, bottom: 10 })
              .backgroundColor(this.themeColorSurfaceSecondary).borderRadius(12).margin({ bottom: 12 })
            Row() {
              Text('取消').fontSize(LABEL_LARGE).fontColor('#C7C9D1').layoutWeight(1)
                .textAlign(TextAlign.Center)
                .onClick(() => this.simulatedReadingVisible = false)
              Text('确定').fontSize(LABEL_LARGE).fontColor('#B9C6FF').layoutWeight(1)
                .textAlign(TextAlign.Center)
                .onClick(() => this.confirmSimulatedReading())
            }.width('100%')
          }.width('86%').padding(16).backgroundColor(this.themeColorSurfaceSecondary).borderRadius(20)
        }.width('100%').height('100%')
      }

      if (this.moreActionConfigVisible) {
        this.moreActionConfigurationSheet()
      }

      if (this.moreActionShellVisible) {
        this.moreActionUnavailableSheet()
      }

      // 批10（:570）长按换源 / 刷新格子的二级菜单。
      if (this.longPressMenuId.length > 0) {
        this.readerLongPressMenu()
      }

      if (this.contentEditVisible) {
        Stack({ alignContent: Alignment.Center }) {
          // 遮罩用 M3 的 scrim 口径 Black α0.32（0x52），原来是 0x99 = 60%，比上游深一倍。
          Column().width('100%').height('100%').backgroundColor('#52000000')
            .onClick(() => this.contentEditVisible = false)
          Column() {
            Row() {
              Text('编辑内容').fontSize(TITLE_LARGE).fontWeight(FontWeight.Medium).fontColor(this.themeColorTextPrimary)
              Blank()
              Text('取消').fontSize(LABEL_LARGE).fontColor(this.themeColorTextTertiary).onClick(() => this.contentEditVisible = false)
            }.width('100%').padding({ bottom: 14 })
            // 「仅正文」开关：把 <img>/<usehtml>/[newpage] 折叠成〔图片1〕这类占位，
            // 对齐上游 ReadContentEditDelegate 的 bodyOnly 开关（ReaderBodyOnlyFilter）。
            Row() {
              Column() {
                Text('仅正文').fontSize(LABEL_LARGE_EMPHASIZED).fontColor(this.themeColorTextPrimary)
                Text('折叠图片、富文本与分页标记，避免误删源码')
                  .fontSize(LABEL_SMALL).fontColor(this.themeColorTextTertiary).margin({ top: 2 })
              }.alignItems(HorizontalAlign.Start).layoutWeight(1)
              // 上游这处是 RoundDropdownMenuItem（ContentEditSheet.kt:125-132）里的开关项，
              // 本地保留「行内开关」的形态，只把 Toggle 换成与全仓一致的 UiSwitchControl。
              UiSwitchControl({
                checked: this.contentEditBodyOnly,
                onChange: (isOn: boolean) => this.setContentEditBodyOnly(isOn)
              })
            }
            .width('100%').padding({ top: 4, bottom: 10 })
            TextInput({ text: this.contentEditTitle, placeholder: '章节名称' })
              .width('100%').height(48).fontSize(LABEL_LARGE).fontColor(this.themeColorTextPrimary)
              .backgroundColor(this.themeColorSurfaceTertiary).borderRadius(10).padding({ left: 12, right: 12 })
              .onChange((value: string) => this.contentEditTitle = value)
            TextArea({ text: this.contentEditBody, placeholder: '章节正文' })
              .width('100%').layoutWeight(1).margin({ top: 10 })
              .fontSize(LABEL_LARGE).fontColor(this.themeColorTextPrimary).backgroundColor(this.themeColorSurfaceTertiary)
              .borderRadius(10).padding(12)
              .onChange((value: string) => this.contentEditBody = value)
            Row() {
              Text('还原').fontSize(LABEL_LARGE_EMPHASIZED).fontColor(this.themeColorTextSecondary).layoutWeight(1).textAlign(TextAlign.Center)
                .onClick(() => {
                  // 还原也回到「折叠态」：与刚打开弹层时看到的一致，
                  // 用户点还原后再关掉「仅正文」仍能拿回完整正文。
                  this.contentEditTitle = this.chapterTitle;
                  this.contentEditBody = this.contentEditBodyOnly
                    ? toBodyOnly(this.content, this.contentEditHiddenSpans) : this.content;
                })
              // 保存按钮：底=primary、字=onPrimary；本地没有 OnPrimary 键，用 surfacePrimary 近似。
              Text('保存').fontSize(LABEL_LARGE).fontColor(this.themeColorSurfacePrimary).textAlign(TextAlign.Center)
                .width(84).padding({ top: 10, bottom: 10 }).backgroundColor(this.themeColorAccent).borderRadius(18)
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
          // 遮罩同「编辑内容」浮层：M3 scrim = Black α0.32（0x52）。
          Column().width('100%').height('100%').backgroundColor('#52000000')
            .onClick(() => {
              this.charsetDialogVisible = false;
              this.charsetOptionsExpanded = false;
            })
          Column() {
            Text('设置编码').fontSize(TITLE_LARGE).fontWeight(FontWeight.Medium).fontColor(this.themeColorTextPrimary)
              .width('100%').margin({ bottom: 16 })
            Row() {
              TextInput({ text: this.charsetInput, placeholder: '输入或选择字符集' })
                .layoutWeight(1).height(48).fontSize(TITLE_SMALL).fontColor(this.themeColorTextPrimary)
                .backgroundColor(this.themeColorSurfaceTertiary).borderRadius(10).padding({ left: 12, right: 12 })
                .onChange((value: string) => this.charsetInput = value)
              Text(this.charsetOptionsExpanded ? '⌃' : '⌄').fontSize(HEADLINE_MEDIUM).fontColor(this.themeColorTextTertiary)
                .width(38).height(48).textAlign(TextAlign.Center)
                .onClick(() => this.charsetOptionsExpanded = !this.charsetOptionsExpanded)
            }.width('100%')
            if (this.charsetOptionsExpanded) {
              Scroll() {
                Column() {
                  ForEach(READER_CHARSETS, (charset: string) => {
                    Row() {
                      Text(charset).fontSize(LABEL_LARGE_EMPHASIZED).fontColor(this.themeColorTextPrimary).layoutWeight(1)
                      if (this.charsetInput.trim().toLowerCase() === charset.toLowerCase()) {
                        Text('✓').fontSize(TITLE_SMALL).fontColor(this.themeColorAccent)
                      }
                    }.width('100%').padding({ left: 12, right: 12, top: 10, bottom: 10 })
                      .onClick(() => {
                        this.charsetInput = charset;
                        this.charsetOptionsExpanded = false;
                      })
                  }, (charset: string) => charset)
                }.width('100%')
              }.edgeEffect(EdgeEffect.None).width('100%').height(220).margin({ top: 8 })
                .scrollBar(BarState.Off)
            }
            Row() {
              Blank().layoutWeight(1)
              Text('取消').fontSize(LABEL_LARGE).fontColor(this.themeColorTextTertiary).padding({ left: 14, right: 14, top: 10, bottom: 10 })
                .onClick(() => {
                  this.charsetDialogVisible = false;
                  this.charsetOptionsExpanded = false;
                })
              Text('确定').fontSize(LABEL_LARGE).fontColor(this.themeColorAccent).padding({ left: 14, right: 14, top: 10, bottom: 10 })
                .onClick(() => this.applyCharset())
            }.width('100%').margin({ top: 12 })
          }
          // 纯黑是本地功能开关（上游没有这个概念），保留；其余走主题 surfaceContainerHigh。
          .width('86%').padding(18).backgroundColor(this.themeAppBackground.length > 0 ? Color.Transparent : (this.themePureBlack ? '#121212' : this.themeColorSurfaceElevated)).borderRadius(20)
        }
        .width('100%').height('100%')
      }

      if (this.highlightRuleSheetVisible) {
        ReaderHighlightRuleSheet({
          rules: this.readerHighlightRules,
          chapterLength: this.localSemanticContent.length,
          configNames: this.availableConfigNames,
          currentConfigName: this.currentConfigName,
          onDismiss: () => this.highlightRuleSheetVisible = false,
          onSave: (rules: ReaderHighlightRule[]): Promise<ReaderHighlightRule[]> => this.saveReaderHighlightRules(rules)
        })
      }

      if (this.imagePreviewVisible) {
        Column() {
          Row() {
            Text('图片预览').fontSize(TITLE_MEDIUM).fontColor('#ECEEF2').layoutWeight(1)
            Image($r('app.media.profile_close')).width(22).height(22).fillColor('#ECEEF2')
              .padding(8).onClick(() => this.closeReaderImagePreview())
          }.width('100%').height(48).padding({ left: 16, right: 16 })
          Stack({ alignContent: Alignment.Center }) {
            // 点击空白处关闭（保留现有行为）
            Column()
              .width('100%')
              .height('100%')
              .onClick(() => this.closeReaderImagePreview())
            Image(this.imagePreviewUri)
              .objectFit(ImageFit.Contain)
              .width('100%')
              .height('100%')
              .scale({ x: this.imagePreviewScale, y: this.imagePreviewScale })
              .translate({ x: this.imagePreviewOffsetX, y: this.imagePreviewOffsetY })
              // 双指缩放：fingers 默认 2，钳制下限 1、上限 2.5（PhotoView.kt:501-506）。
              .gesture(
                PinchGesture({ fingers: 2 })
                  .onActionStart(() => {
                    this.imagePreviewBaseScale = this.imagePreviewScale;
                  })
                  .onActionUpdate((event: GestureEvent) => {
                    const next = Math.max(1, Math.min(IMAGE_PREVIEW_MAX_SCALE, this.imagePreviewBaseScale * event.scale));
                    this.imagePreviewScale = next;
                    // 缩回 1 时位移必须归零，否则图会停在屏幕外。
                    if (next <= 1) {
                      this.imagePreviewOffsetX = 0;
                      this.imagePreviewOffsetY = 0;
                    }
                  })
              )
              // 放大后单指拖动平移；缩放为 1 时不响应，交给上层点击关闭。
              .gesture(
                PanGesture()
                  .onActionStart(() => {
                    this.imagePreviewBaseOffsetX = this.imagePreviewOffsetX;
                    this.imagePreviewBaseOffsetY = this.imagePreviewOffsetY;
                  })
                  .onActionUpdate((event: GestureEvent) => {
                    if (this.imagePreviewScale <= 1) { return; }
                    this.imagePreviewOffsetX = this.imagePreviewBaseOffsetX + event.offsetX;
                    this.imagePreviewOffsetY = this.imagePreviewBaseOffsetY + event.offsetY;
                  })
              )
              // 双击：放大到 2.5 与回正之间切换（PhotoView.kt:1204-1235）。
              .gesture(
                TapGesture({ count: 2 })
                  .onAction(() => {
                    if (this.imagePreviewScale > 1) {
                      this.imagePreviewScale = 1;
                      this.imagePreviewOffsetX = 0;
                      this.imagePreviewOffsetY = 0;
                    } else {
                      this.imagePreviewScale = IMAGE_PREVIEW_MAX_SCALE;
                    }
                  })
              )
          }
          .layoutWeight(1)
          .width('100%')
          // 长按保存：SaveButton 安全控件（免 WRITE_IMAGEVIDEO 权限）。
          // 上游是长按弹系统分享面板（PhotoSheet.kt:82-97），本地改成右下角常驻按钮，
          // 因为 ArkUI 的 LongPressGesture 与 PanGesture 在同一节点上容易互相吞掉。
          Row() {
            SaveButton({
              icon: SaveIconStyle.FULL_FILLED,
              text: SaveDescription.SAVE_IMAGE,
              buttonType: ButtonType.Capsule
            })
              .onClick(async (event: ClickEvent, result: SaveButtonOnClickResult) => {
                if (result === SaveButtonOnClickResult.SUCCESS) {
                  await this.saveReaderImageToGallery();
                } else {
                  this.onUnavailableAction('未获得保存授权');
                }
              })
          }
          .width('100%')
          .justifyContent(FlexAlign.End)
          .padding({ right: 16, bottom: 12 })
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

      // 批6：朗读胶囊 —— 应用内浮层（退出阅读器即消失，平台无系统悬浮窗能力）。
      // 结构照上游 ReadAloudCapsule.kt：封面圆图（点击展开/开player）+ 播放暂停 + 进度环内含停止。
      // 日白夜黑底色不跟随主题（上游 capsuleSurfaceColor）。
      if (this.capsuleVisible()) {
        Row() {
          // 封面圆图：折叠态唯一元素；点击折叠时展开、完全展开时开听书界面 player。
          Stack({ alignContent: Alignment.Center }) {
            if (this.book.coverUri !== undefined && this.book.coverUri.length > 0) {
              Image(this.book.coverUri)
                .width(this.capsuleCoverSize).height(this.capsuleCoverSize)
                .borderRadius(this.capsuleCoverSize / 2)
                .objectFit(ImageFit.Cover)
            } else {
              Text(this.book.title.length > 0 ? this.book.title.substring(0, 1) : '书')
                .fontSize(HEADLINE_SMALL).fontWeight(FontWeight.Bold)
                .fontColor(this.readerNightMode ? '#1B1C22' : '#FFFFFF')
            }
          }
          .width(this.capsuleCoverSize).height(this.capsuleCoverSize)
          .borderRadius(this.capsuleCoverSize / 2)
          .backgroundColor(this.readerNightMode ? '#E5E6EB' : '#3A3B42')
          .clip(true)
          .rotate({ angle: this.capsuleCoverAngle })
          .onClick(() => this.onCapsuleCoverClick())

          // 展开态揭示：播放暂停 + 进度环内含停止（上游 CapsuleContent:400-455）。
          if (!this.capsuleCollapsed) {
            Row() {
              // 播放暂停按钮：isPaused ? PlayArrow : Pause。
              Stack({ alignContent: Alignment.Center }) {
                Image($r(this.capsulePaused() ? 'app.media.reader_play' : 'app.media.reader_pause'))
                  .width(20).height(20)
                  .fillColor(this.readerNightMode ? '#FFFFFF' : '#000000')
              }
              .width(36).height(36)
              .borderRadius(18)
              .backgroundColor(this.readerNightMode ? '#1AFFFFFF' : '#1A000000')
              .onClick(() => { this.onCapsulePauseToggle(); this.resetCapsuleCollapseTimer(); })
              .accessibilityText(this.capsulePaused() ? '继续朗读' : '暂停朗读')

              // 进度环 + 中间停止按钮（上游 CircularProgressIndicator + Close）。
              Stack({ alignContent: Alignment.Center }) {
                Progress({ value: this.readAloudSpan.start >= 0 ? this.currentAloudProgress() : 0,
                  total: 100, type: ProgressType.Ring })
                  .width(36).height(36)
                  .color(this.readerNightMode ? '#99FFFFFF' : '#99000000')
                Image($r('app.media.profile_close'))
                  .width(16).height(16)
                  .fillColor(this.readerNightMode ? '#FFFFFF' : '#000000')
                  .onClick(() => this.onCapsuleStop())
              }
              .width(36).height(36)
            }
            .width(84).height(40)
            .margin({ left: 4 })
          }
        }
        .width(this.capsuleWidthAnim)
        .height(this.capsuleHeight)
        .padding({ left: 4, right: 4 })
        .backgroundColor(this.readerNightMode ? '#FF000000' : '#FFFFFFFF')
        .borderRadius(28)
        .shadow({ radius: 12, color: '#66000000', offsetY: 2 })
        .position({ x: this.capsuleRenderX() - this.capsuleWidthAnim / 2, y: this.capsuleY - this.capsuleHeight / 2 })
        .gesture(
          PanGesture()
            .onActionStart(() => {
              this.capsuleDragBaseX = this.capsuleX;
              this.capsuleDragBaseY = this.capsuleY;
              this.resetCapsuleCollapseTimer();
            })
            .onActionUpdate((event: GestureEvent) => {
              this.clampCapsule(this.capsuleDragBaseX + event.offsetX,
                this.capsuleDragBaseY + event.offsetY);
            })
            .onActionEnd(() => {
              // 上游 snapCapsuleOffsetX：松手时距边缘 72vp 内吸附到边线（中心偏移 ±W/2）。
              const edge = this.readerContentWidth / 2;
              const offsetX = this.capsuleX - edge;
              if (edge - Math.abs(offsetX) <= 72) {
                // 上游语义：吸附保存 ±edge（capsuleDockSide 据此判贴边折叠）；
                // 渲染中心由 capsuleRenderX 钳到可见范围，应用内浮层不出屏。
                this.capsuleX = offsetX < 0 ? 0 : this.readerContentWidth;
              }
              this.persistCapsulePosition();
              // 上游 capsuleDockSide != 0：吸附到边缘即折叠。
              const halfW = this.capsuleWidthCollapsed / 2;
              if (this.capsuleX <= halfW || this.capsuleX >= this.readerContentWidth - halfW) {
                this.setCapsuleCollapsed(true);
              }
              this.resetCapsuleCollapseTimer();
            })
        )
        .onClick(() => this.resetCapsuleCollapseTimer())
        .zIndex(950)
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
  /** 菜单强调色（选中态），由 ReaderPage 按菜单配色折算后传入。上游 `ReadBookConfig.kt:542` 日间默认 `#EEEFE3`。 */
  @Prop menuAccent: string = '#EEEFE3';
  /** 项容器底色（未选中），见 readerMenuItemFill。 */
  @Prop itemFill: string = '#00000000';
  /** 项容器底色（选中），见 readerMenuSelectedFill。 */
  @Prop itemFillSelected: string = '#00000000';
  /** 描边色（iconStyle === 2 时用），由 ReaderPage 传 menuForegroundAlpha('73')。 */
  @Prop menuForegroundAlpha: string = '#73D5C2C6';
  /** 按钮内层尺寸；上游 `ReadBookMenuBarBottom.kt:245`（玻璃 48 / 普通 40）。 */
  @Prop outerSize: number = 40;
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
            .fontSize(LABEL_SMALL).fontColor('#FFFFFF')
            .backgroundColor('#B3261E').borderRadius(8)
            .padding({ left: 4, right: 4, top: 1, bottom: 1 })
            .align(Alignment.TopEnd)
        }
      }.width(this.outerSize).height(this.outerSize)
        .backgroundColor(this.active ? this.itemFillSelected : this.itemFill)
        .border({ width: this.iconStyle === 2 ? 1 : 0, color: this.menuForegroundAlpha })
        .borderRadius(this.outerSize / 2)
      if (this.showLabel) {
        // 上游 `ReadBookMenuBarTool.kt:355-364`：`labelSmall` = 11sp，单行、居中。
        // 上游那层还带 `unbounded = true`（文字可横向溢出父宽），ArkUI 没有等价物；
        // 本地按钮是 40/48 定宽 + SpaceBetween，真放开会让相邻文字互相压，本批不做。
        // 实测 11 号在 40vp 按钮里「自动翻页」只能显示三个字（被裁），退到 10 号。
        Text(this.label)
          .fontSize(LABEL_SMALL)
          .fontColor(this.menuForeground)
          .maxLines(1)
          .textAlign(TextAlign.Center)
          .width('100%')
          .margin({ top: 2 })
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
  /** 菜单强调色（选中态），由 ReaderPage 按菜单配色折算后传入。上游 `ReadBookConfig.kt:542` 日间默认 `#EEEFE3`。 */
  @Prop menuAccent: string = '#EEEFE3';

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
      // 上游 `ReadMenuActionDefs.kt:156-159` 用 `Icons.AutoMirrored.Filled.Toc`（目录列表形）。
      // `profile_rule` 是「规则/订阅」图标，语义不符，改用与目录按钮共用的 `reader_toc`。
      Image($r('app.media.reader_toc')).width(this.glyphSize).height(this.glyphSize).fillColor(this.menuForeground)
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




