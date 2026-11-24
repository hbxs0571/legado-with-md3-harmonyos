import curves from '@ohos.curves';
import { Book, bookCoverMark } from '../model/Book';
import { BookGroup, BookGroupDraft, BOOK_SORT_OPTIONS, BookSortOption, bookSortLabel } from '../model/BookGroup';
import {
  BookshelfLayoutSettings, BookshelfLayoutOption, DEFAULT_BOOKSHELF_LAYOUT,
  BOOKSHELF_LAYOUT_MODE_OPTIONS, BOOKSHELF_SORT_ORDER_OPTIONS,
  BOOK_GROUP_STYLE_OPTIONS, BOOKSHELF_FOLDER_LAYOUT_MODE_OPTIONS,
  BOOKSHELF_GROUP_LIST_STYLE_OPTIONS,
  bookshelfLayoutOptionLabel, copyBookshelfLayout, TagColorPair, parseTagColors
} from '../model/BookshelfLayout';
import { BookshelfSort } from '../data/BookshelfSort';
import { CoverSettings, DEFAULT_COVER_SETTINGS } from '../data/CoverSettingsRepository';
import { BookRepository } from '../data/BookRepository';
import { BookGroupRepository } from '../data/BookGroupRepository';
import { BookCover } from '../components/BookCover';
import { bookCoverSharedElementKey, bookshelfSharedCoverSourceId } from '../data/BookCoverSharedElement';
import { BookGroupCard } from '../components/BookGroupCard';
import { GroupEditorSheet } from '../components/booksource/GroupEditorSheet';
import { AppGlyph, AppGlyphName } from '../components/AppGlyph';
import { AppTopBar, TopBarButton } from '../components/TopBar';
import { UiMenuItem, UiMenuPanel } from '../components/UiMenu';
import { UiSwitchControl } from '../components/UiSwitchControl';
// 上游五个 AppAlertDialog（密码/添加网址/批量下载/批量删除/确认执行分组）都是居中对话框，
// 本地用 openCustomDialog + AppAlertDialog 承载（showAlertDialog 带不了输入框）。
import { AppAlertDialog } from '../components/AppAlertDialog';
import { DialogCheckRow, DialogTextInput } from '../components/DialogInputs';
import { PullRefreshIndicator } from '../components/PullRefreshIndicator';
import { normalizeCustomColor } from '../data/CustomThemeColors';
import { cardRadiusOf } from '../data/ThemeCardStyle';
import { AppLog, AppLogEntry } from '../lib/AppLog';
import { BookshelfListEntry, BookshelfListTransfer } from '../data/BookshelfListTransfer';
import { AddBookByUrlUseCase } from '../data/AddBookByUrlUseCase';
// A-29/A-30：书单条目要按启用书源精确搜索补全成在线书（上游 ImportBookshelfUseCase.importByJson）
import { PreciseSearchCoordinator } from '../bookSource/PreciseSearchCoordinator';
// A-30 的「上传」支路：对齐上游 uploadRepository.upload（DirectLinkUpload.upLoad）
import { DirectLinkUpload, DirectLinkUploadStore } from '../lib/DirectLinkUpload';
import { window } from '@kit.ArkUI';
import { toTimeAgo } from '../lib/TimeAgo';
import { LocalBookRestorePlanner } from '../data/LocalBookRestorePlanner';
import { argbToColorHex, hexToArgb, deriveTagBgColor, baseHueFromHex, generateTagColors } from '../lib/TagColorUtils';
import { TagGroupRuleRepository } from '../data/TagGroupRuleRepository';
import { TagGroupRule } from '../model/TagGroupRule';
import { pasteboard } from '@kit.BasicServicesKit';
import {
  PRIVATE_UNLOCK_EVERY_TIME, PrivateAccessRepository, PrivateBiometricStatus,
  isPrivateBook, requiresPrivateUnlock
} from '../data/PrivateAccessRepository';
import {
  BODY_MEDIUM, BODY_SMALL, LABEL_LARGE, LABEL_MEDIUM, LABEL_SMALL, LABEL_SMALL_EMPHASIZED,
  TITLE_LARGE, TITLE_MEDIUM, TITLE_SMALL
} from '../components/typography/TypographyTokens';
// G-4：简介要过上游 HtmlFormatter（列表卡不是直显原始 HTML）。
import { formatIntroText, formatSummaryText } from '../lib/HtmlFormatter';
// F-4/F-5：顶栏折叠阈值改走统一令牌（70/24 双向滞回），不再本页硬编码 60。
import { HEADER_COLLAPSE_THRESHOLD, HEADER_EXPAND_THRESHOLD } from '../components/UiTokens';
// H-3：拖拽阈值激活 / 跨位 / 松手三处触感，对齐上游 longPressDraggableHandle 的两个回调。
import { UiHaptics } from '../data/UiHaptics';
import {
  AutoGroupApplyResultUi,
  AutoGroupBookUi,
  AutoGroupEngine,
  AutoGroupError,
  AutoGroupGroupUi,
  AutoGroupIgnoredBookUi,
  AutoGroupOptions,
  AutoGroupPhase,
  AutoGroupPlan
} from '../data/AutoGroupEngine';

/**
 * 卡片式菜单的统一宽度，与详情页溢出菜单同口径。
 *
 * 上游 RoundDropdownMenu 本身**没有宽度参数**（RoundDropdownMenu.kt:52-60），由 DropdownMenu 按内容
 * 自适应；本地 UiMenuPanel 用固定宽。260 在 365vp 视口下占 71%，观感上比上游宽一圈，
 * 收到 220（约 60%）作为内容自适应的近似值。
 */
const SHELF_MENU_WIDTH: number = 220;

/** 网格左右内边距基数，对应上游 BookshelfScreen.kt contentPadding horizontal 8.dp。 */
const BOOKSHELF_GRID_PADDING: number = 8;
/**
 * C-3：书籍网格实际左右内边距 = 8 + 4 = 12。
 *
 * 上游不是直接给 8dp，而是 `contentPadding = adaptiveContentPaddingBookshelf(horizontal = 8.dp)`
 * （BookshelfScreen.kt:1767-1771），该函数内部再叠一层
 * `horizontal = if (miuix) 6.dp + horizontal else 4.dp + horizontal`（AdaptivePadding.kt:114-121）。
 * 本项目对齐 M3 引擎，故取 4dp 叠加。
 */
const BOOKSHELF_GRID_PADDING_EXTRA: number = 4;
/** 网格行间距与列间距，对应上游 BookshelfScreen.kt:1770-1772 的 spacedBy(8.dp)。 */
const BOOKSHELF_GRID_GAP: number = 8;

/** 网格样式选项，对应上游 bookshelf_grid_layout（标准 / 紧凑 / 仅封面）。 */
const BOOKSHELF_GRID_STYLE_OPTIONS: BookshelfLayoutOption[] = [
  { value: 0, label: '标准' },
  { value: 1, label: '紧凑' },
  { value: 2, label: '仅封面' }
];

/**
 * 书架卡片 Grid 的数据源（:154）。
 *
 * 与 pages/CatalogPage.ets 的 CatalogChapterDataSource 同一套写法：数据整批换
 * （onDataReloaded），不做逐项 diff。getVisibleBooks() 要过一遍筛选 + 排序，
 * 绝不能在 getData(index) 里再算一次——getData 会被逐项调用，放进去就是 O(n²)。
 */
class BookshelfBookDataSource implements IDataSource {
  private items: Book[] = [];
  private listeners: DataChangeListener[] = [];

  totalCount(): number {
    return this.items.length;
  }

  getData(index: number): Book {
    return this.items[index];
  }

  registerDataChangeListener(listener: DataChangeListener): void {
    if (this.listeners.indexOf(listener) < 0) { this.listeners.push(listener); }
  }

  unregisterDataChangeListener(listener: DataChangeListener): void {
    const position = this.listeners.indexOf(listener);
    if (position >= 0) { this.listeners.splice(position, 1); }
  }

  /** 整批换数据：通知所有监听者重新读取。 */
  setItems(items: Book[]): void {
    this.items = items;
    this.listeners.forEach((listener: DataChangeListener) => listener.onDataReloaded());
  }
}

/**
 * 简介排版缓存，对齐上游 `BookItem.kt:289-324` 的 `formattedIntroCache`。
 *
 * LazyForEach 滚出视口的卡片会销毁、滚回来重建，每次重建都会重新跑一遍 HtmlFormatter 的
 * 多轮正则；400+ 本书上下滚动足以把主线程打满。这里以「行数设置 + 原始简介」为键全局只排一次版，
 * 上限 500 条避免无限增长（上游 MAX_ENTRIES 同为 500）。
 * 网格模式不展示简介、不参与解析——调用点只在列表分支里。
 */
class IntroFormatCache {
  private static readonly MAX_ENTRIES: number = 500;
  private static readonly STORE: Map<string, string> = new Map<string, string>();

  static getOrFormat(intro: string, maxLines: number): string {
    if (intro.length === 0) { return ''; }
    const key = `${maxLines}|${intro}`;
    const cached = IntroFormatCache.STORE.get(key);
    if (cached !== undefined) { return cached; }
    // 上游口径：行数 0（不限）用 formatIntroText 保留段落，限行时压成单行摘要。
    const formatted = maxLines === 0 ? formatIntroText(intro) : formatSummaryText(intro);
    if (IntroFormatCache.STORE.size >= IntroFormatCache.MAX_ENTRIES) {
      const oldest = IntroFormatCache.STORE.keys().next();
      if (!oldest.done) { IntroFormatCache.STORE.delete(oldest.value); }
    }
    IntroFormatCache.STORE.set(key, formatted);
    return formatted;
  }
}

/** 卡片底色十六进制转 ARGB 整数；空串或非法值返回 0（= 跟随主题）。 */
function bookshelfCardHexToInt(hex: string): number {
  const normalized = normalizeCustomColor(hex);
  if (normalized.length === 0) { return 0; }
  const digits = normalized.slice(1);
  const argb = parseInt(digits.length === 6 ? `FF${digits}` : digits, 16);
  return Number.isFinite(argb) ? (argb | 0) : 0;
}

/** ARGB 整数转 #RRGGBB；0 返回空串（丢 alpha，对齐 ReaderMarkingEditor 的展示口径）。 */
function bookshelfCardIntToHex(color: number): string {
  if (color === 0) { return ''; }
  const unsigned = color >>> 0;
  const channel = (value: number): string => value.toString(16).padStart(2, '0');
  return `#${channel((unsigned >>> 16) & 0xFF)}${channel((unsigned >>> 8) & 0xFF)}${channel(unsigned & 0xFF)}`.toUpperCase();
}

@Component
export struct BookshelfPage {
  @StorageProp('themeColorTextPrimary') themeColorTextPrimary: string = '#1B1C22';
  @StorageProp('themeColorTextSecondary') themeColorTextSecondary: string = '#2E3038';
  @StorageProp('themeColorTextTertiary') themeColorTextTertiary: string = '#6A6D77';
  @StorageProp('themeColorAccent') themeColorAccent: string = '#3F5BD9';
  @StorageProp('themeColorSurfacePrimary') themeColorSurfacePrimary: string = '#F5F6F8';
  @StorageProp('themeColorSurfaceTertiary') themeColorSurfaceTertiary: string = '#F0F1F5';
  @StorageProp('themeColorSurfaceSecondary') themeColorSurfaceSecondary: string = '#E9EBF0';
  @StorageProp('themeColorSurfaceElevated') themeColorSurfaceElevated: string = '#FFFFFF';
  /** 书架卡片底色兜底。上游 `BookItem.kt:186` / `:583` 在用户没设卡片色时用 `cardContainer`。 */
  @StorageProp('themeColorCardContainer') themeColorCardContainer: string = '#FFFFFF';
  // B-7：列表未读徽标的字色。上游 TextCard 默认 contentColor = onCardContainer
  // （TextCard.kt:43-44），徽标本身不传配色，所以字色就是 onCardContainer。
  @StorageProp('themeColorOnCardContainer') themeColorOnCardContainer: string = '#3B4A7A';
  /**
   * 卡片选中态底色。上游 `BookItem.kt:99`（网格 Box.background）与 `:186`（列表 NormalCard.containerColor）
   * 选中时都铺 `secondaryContainer`；本地此前只有勾选圈变色、整格底色不变。
   */
  @StorageProp('themeColorSecondaryContainer') themeColorSecondaryContainer: string = '#DCE1FF';
  /** 列表卡右侧信息列的字色基准。上游 `AppText` 默认 `onSurface` / `onSurfaceVariant`。 */
  @StorageProp('themeColorOnSurface') themeColorOnSurface: string = '#1B1C22';
  @StorageProp('themeColorOnSurfaceVariant') themeColorOnSurfaceVariant: string = '#2E3038';
  /** 分组管理卡片底色：上游 GroupManageSheet.kt:311 GlassCard(containerColor = onSheetContent)。 */
  @StorageProp('themeColorOnSheetContent') themeColorOnSheetContent: string = '#1F2027';
  /** 简介「在下方」用的 GlassCard 容器色。上游 `BookItem.kt:931` 传 `cardContainer`。 */
  @StorageProp('themeColorSurfaceContainerLow') themeColorSurfaceContainerLow: string = '#F7F8FA';
  /** 上游 AiAutoGroupSheet.kt:381/411/515 用 surfaceContainer 作输入框底色，补这一档订阅。 */
  @StorageProp('themeColorSurfaceContainer') themeColorSurfaceContainer: string = '#F1F2F6';
  /** 卡片色输入框未设置时的初始色。上游 `BookshelfConfigSheet.kt:677` 用 `surfaceVariant`。 */
  @StorageProp('themeColorSurfaceVariant') themeColorSurfaceVariant: string = '#E1E4D5';
  /**
   * 形状四键。上游 `GlassCard.kt:78-96` 的 BaseCard 是
   * `if (overrideBaseCardCornerRadius) baseCardCornerRadius.dp else cornerRadius`，
   * 也就是「覆盖没开时用调用点自己写的值」。书架书卡对应 `BookItem.kt:184` 的 8.dp，
   * 分组卡对应 `GroupManageSheet.kt:310` 的 12.dp —— 这两个数只有未覆盖时生效，
   * 覆盖打开后统一被 `themeCardRadius` 吃掉，所以要把「覆盖开关」也订阅下来。
   */
  @StorageProp('themeCardOverride') themeCardOverride: boolean = false;
  @StorageProp('themeCardRadius') themeCardRadius: number = 16;
  @StorageProp('themeCardBorderOverride') themeCardBorderOverride: boolean = false;
  @StorageProp('themeCardBorderWidth') themeCardBorderWidth: number = 0;
  @StorageProp('themeCardBorderColor') themeCardBorderColor: string = '#6A6D77';
  @StorageProp('themeAppBackground') themeAppBackground: string = '';
  @StorageProp('themePureBlack') themePureBlack: boolean = false;
  @StorageProp('themeItemBackground') themeItemBackground: string = '';
  /**
   * 底部内缩档的两个输入，由 `pages/Index.ets` 的 `publishTopBottomBarStyle()` 广播。
   * 上游 `BookshelfViewModel.kt:718/737`：`useRaisedBottomInset = useFloatingBottomBar || enableBlur`，
   * 消费点 `BookshelfScreen.kt:999/1769` 把底部内边距在 120.dp 与 8.dp 之间二选一。
   */
  @StorageProp('themeUseFloatingBottomBar') themeUseFloatingBottomBar: boolean = false;
  @StorageProp('themeEnableBlur') themeEnableBlur: boolean = false;
  /** 书目：变化时重算 LazyForEach 数据源（:154）。 */
  @Prop @Watch('onBookshelfDataDirty') books: Book[] = [];
  @Prop groups: BookGroup[] = [];
  /** 书架布局设置，来自 Index 的持久化状态。异步恢复完成后由 onLayoutChanged 灌入记住的分组。 */
  @Prop @Watch('onLayoutChanged') layout: BookshelfLayoutSettings = DEFAULT_BOOKSHELF_LAYOUT;
  /** 封面文字设置，来自 Index 的持久化状态。 */
  @Prop coverSettings: CoverSettings = DEFAULT_COVER_SETTINGS;
  /** 当前是否夜间主题，决定封面文字用日间还是夜间那一套开关与颜色。 */
  @Prop readerNightMode: boolean = false;
  /**
   * 阅读界面共享元素动画开关（外观页「阅读界面共享元素动画」）。
   *
   * 对齐上游 `AppShellSettings.kt:13 readerSharedElementEnabled`：关闭时不登记共享元素键，
   * 封面与阅读页之间退回普通淡入淡出。
   */
  @Prop readerSharedElement: boolean = true;
  /** 正在刷新目录的书主键集合（来自 Index），网格卡据此显示更新中转圈（:120）。 */
  @Prop refreshingBookIds: string[] = [];
  /**
   * 批3（r359）：自动刷新目录的待更新本数，由 TocRefreshQueue 通过 AppStorage 键
   * tocPendingCount 推送（上游 postUpBooksCount 走 UP_BOOKSHELF 事件同款做法）。
   * 标题尾巴用它，且只在「显示等待更新数量」打开时拼，见 bookshelfTitle()。
   */
  @StorageLink('tocPendingCount') tocPendingCount: number = 0;
  /**
   * :368（批6，r360）：书架首屏数据是否在加载，由 Index 驱动（启动恢复与两条下拉刷新）。
   * 只用来决定标题是「逐字淡入中」还是「已到位直接整串显示」。
   */
  @Prop @Watch('onBookshelfLoadingChanged') bookshelfLoading: boolean = false;
  /**
   * A-22 回到顶部请求计数（上游 BookshelfScreen.kt:469-482 LaunchedEffect(scrollToTopRequest)）。
   * 底栏重复点「书架」时 Index 自增，这里滚到首项；文件夹根层与主网格各有一个 Scroller，
   * 按当前视图选（上游也是 when { isShowingFolderRoot -> folderGridState; else -> groupGridStates }）。
   */
  @Prop @Watch('onScrollToTopRequest') scrollToTopRequest: number = 0;
  /**
   * 标题逐字淡入进度：>= 999 表示已到位（普通整段渲染，且之后不再重淡入）；
   * 0 表示一个字都还没亮。真正的逐字错开在 AppTopBar.titleLine 里按 index*24ms 的延迟实现，
   * 这里只负责在加载开始/结束时把值推到两端。
   */
  @State titleRevealStep: number = 999;
  @State showLayoutSheet: boolean = false;
  /** 五个卡片式菜单各自的显隐；每个挂载点一份，互不干扰。 */
  @State sortMenuVisible: boolean = false;
  @State groupFilterVisible: boolean = false;
  @State groupManageMenuVisible: boolean = false;
  /** 正在拖动的分组 id：用于给被拖起的卡片加抬升阴影（上游 GroupManageSheet.kt:306-308 animateDpAsState(8.dp)）。 */
  @State draggingGroupId: number = -1;
  @State selectionGroupVisible: boolean = false;
  /** H-5：编辑态「移动」多选分组 Sheet 的显隐与已勾选组名。 */
  @State showMoveGroupSheet: boolean = false;
  @State moveGroupSelectedNames: string[] = [];
  @State layoutMenuVisible: boolean = false;
  @State moreMenuVisible: boolean = false;
  /** 布局面板编辑中的草稿；打开面板时从 layout 复制，确认后整体提交。 */
  @State layoutDraft: BookshelfLayoutSettings = copyBookshelfLayout(DEFAULT_BOOKSHELF_LAYOUT);
  @State @Watch('onBookshelfDataDirty') selectedFilter: string = '全部';
  @State showGroupManager: boolean = false;
  /**
   * 分组编辑面板的编辑目标；`undefined` 表示新建，`undefined` + showGroupEditor 为假表示不在编辑态。
   *
   * 第十表 H-4：编辑表单已抽成 `components/booksource/GroupEditorSheet.ets`，
   * 与书架管理页共用同一实现（上游 `BookInfoSheets.kt:108-190` 的 `GroupSelectSheet`
   * 里「新建分组」与每行「编辑」都指向同一个 `GroupEditSheet`）。
   * 草稿态（名称/排序/刷新/隐私/封面/标签规则）全部搬进组件，本页只留「编辑哪个组」。
   */
  @State showGroupEditor: boolean = false;
  @State editingGroup: BookGroup | undefined = undefined;
  @State showSearch: boolean = false;
  @State @Watch('onBookshelfDataDirty') searchQuery: string = '';
  @State collapsedHeader: boolean = false;
  /**
   * 网格容器的实测宽度（vp）。
   *
   * 封面宽度要按格子宽度算（上游是 fillMaxWidth + aspectRatio 5:7），
   * 而格子宽度只有在布局完成后才知道，所以记下网格的 onAreaChange 结果。
   */
  @State bookshelfGridWidth: number = 0;
  /** 当前是否横屏：由窗口矩形（F1）与网格容器尺寸共同判断，横屏时布局取 Landscape 那套字段。 */
  @State isLandscape: boolean = false;
  /** 文件夹视图当前进入的分组名；空串表示停在根层（显示分组卡片）。 */
  @State folderViewGroup: string = '';
  /** 日间/夜间卡片底色的编辑中十六进制文本；0 值在界面上表现为空串。 */
  @State dayCardColorHex: string = '';
  @State nightCardColorHex: string = '';
  /** 日志面板是否展开；与分组/布局面板共用同一个 bindSheet。 */
  @State showLogSheet: boolean = false;
  /** 打开日志面板时抓取的 AppLog 快照，清空后置空数组触发刷新。 */
  @State logEntries: AppLogEntry[] = [];
  /**
   * 数值行的展开键：对齐上游 CompactSliderSettingItem 的 `expanded`，
   * 同一时刻只展开一个滑块，键就是该行的标题。
   */
  @State layoutSliderExpandedKey: string = '';
  /**
   * 「标签显示内容」对话框开关（D-2 / F-5）。
   * 对齐上游 BookshelfConfigSheet.kt:659-665 的 `if (showTagContentDialog) BookshelfTagContentDialog(...)`，
   * 上游是独立对话框，不是行内展开。
   */
  @State showTagContentDialog: boolean = false;
  /** 对话框内的三个复选草稿；确认时才写回 layoutDraft（上游 rememberSaveable 语义）。 */
  @State tagDialogCustom: boolean = false;
  @State tagDialogSource: boolean = false;
  @State tagDialogWordCount: boolean = false;
  /** 标签行取色缓存：总开关关掉时为空数组，卡片侧统一回落主题色（:124）。 */
  @State cachedTagColors: TagColorPair[] = [];
  /** 配色管理页是否展开；与布局/日志/分组面板共用同一个 bindSheet。 */
  @State showTagColorPage: boolean = false;
  /** 配色管理页编辑中的配色数组，整体替换才触发 @State 刷新。 */
  @State tagColorsDraft: TagColorPair[] = [];
  /** 取色器（hex 输入行）是否展开。 */
  @State showTagColorPicker: boolean = false;
  /** 取色器正在编辑的配色下标。 */
  @State tagColorEditIndex: number = -1;
  /** 取色器输入的文字色 hex。 */
  @State tagColorPickerHex: string = '';
  /** 「粘贴」需先弹 PasteButton 授权层，不能直接读剪贴板（ProfileSubPages.ets:1394）。 */
  @State showRulePasteAuthorization: boolean = false;
  /** 独立标签规则面板是否打开（C-15：上游 TagGroupRuleEditSheet）。 */
  @State showTagRuleEdit: boolean = false;
  /** 正在编辑的规则 id；0 表示新建。 */
  @State editingTagRuleId: number = 0;
  /** 规则面板里的分组名与匹配表达式草稿。 */
  @State tagRuleName: string = '';
  @State tagRulePattern: string = '';
  /** 规则面板右上「更多菜单」的展开态。 */
  @State tagRuleMenuVisible: boolean = false;
  /** C-14：AI 自动分组面板的开关与整套会话状态（对齐上游 AiAutoGroupUiState）。 */
  @State showAiAutoGroup: boolean = false;
  @State aiPhase: AutoGroupPhase = 'LoadingSource';
  @State aiIncrementalOnly: boolean = true;
  @State aiIncludeBookIntro: boolean = false;
  @State aiDeepThinking: boolean = false;
  @State aiGroupingInstruction: string = '';
  @State aiGroups: AutoGroupGroupUi[] = [];
  @State aiIgnoredBooks: AutoGroupIgnoredBookUi[] = [];
  @State aiApplyResult: AutoGroupApplyResultUi | undefined = undefined;
  @State aiErrorText: string = '';
  @State aiRevisionInstruction: string = '';
  @State aiNewGroupName: string = '';
  @State aiBatchText: string = '';
  /** 当前展开「移动」菜单的书（bookUrl）；空串表示没有展开。 */
  @State aiMoveMenuKey: string = '';
  /** 选择模式（:87 / :142-144）。进入后卡片点击改勾选，顶栏换关闭按钮。 */
  @State selectionMode: boolean = false;
  /** 下拉刷新进行中。与单本刷新的 refreshingBookIds 是两件事：这个是整批转圈。 */
  @State pullRefreshing: boolean = false;
  /** 下拉已过触发阈值，只喂给自绘指示器换图标用。 */
  @State pullArmed: boolean = false;
  /** 当前下拉距离（vp），来自 Refresh.onOffsetChange，驱动指示器齿轮跟手旋转。 */
  @State pullOffsetValue: number = 0;
  /**
   * 已选书籍的键集合（:142-144）。
   * 键一律用 bookUrl（contentPath 优先），不用 book.id —— id 是文件名去扩展名派生的，
   * 同名但不同目录的两本书会撞键，而 books 表主键是 bookUrl。
   * ArkTS 的 @State 不认识 Set 的原地增删，全部改用 new Set(...) 整体赋值。
   */
  @State selectedBookKeys: Set<string> = new Set<string>();
  /** H-6：网址导入对话框（对齐上游 BookshelfOverlay.AddUrlDialog）。 */
  /**
   * H-4：拖动中的临时列表（上游 `BookshelfScreen.kt:1730` 的 `draggingBooks`）。
   * 拖动期间可见书读它、不落库；松手（onDrop）才交给 onMoveBooks 保存。
   * ArkTS 对 `Book[] | null` 的窄化不友好，用「空数组 + dragActive」表达「没有临时列表」。
   */
  @State draggingBooks: Book[] = [];
  @State dragActive: boolean = false;
  /** H-6：网址导入对话框的输入内容（对话框关闭时清空）。 */
  @State addUrlInput: string = '';
  /**
   * A-29/A-30：书单导入/导出各自的上游 `FilePickerSheet` 面板
   * （`ui/widget/components/filePicker/FilePickerSheet.kt:22-78`）。
   * 上游导入是「选系统文件 + 输入URL」两条路，导出是「选系统文件夹 + 上传 URL」两条路；
   * 本地原来各只有一条（直接弹系统选择器），这里补齐成 OptionSheet 形态的面板。
   */
  @State showImportSheet: boolean = false;
  @State showExportSheet: boolean = false;
  /** 批量删除时是否同时删掉应用内导入副本（:149）；每次打开面板都从未勾选起步。 */
  @State batchDeleteSource: boolean = false;
  /**
   * 私密体系状态（批6）。@StorageProp 直接订阅 AppStorage：
   * PrivateAccessRepository 每次 publish 后这三个值都会重建，不需要自己传回调。
   */
  @StorageProp('privateEnabled') privateEnabled: boolean = false;
  @StorageProp('privateHasPassword') privateHasPassword: boolean = false;
  @StorageProp('privateUnlocked') privateUnlocked: boolean = false;
  /** 两个验证时机开关：关掉后对应的分组/书籍不再要求验证（对齐上游 verifyOnEnterGroup/verifyOnOpenBook）。 */
  @StorageProp('privateVerifyOnEnterGroup') privateVerifyOnEnterGroup: boolean = true;
  @StorageProp('privateVerifyOnOpenBook') privateVerifyOnOpenBook: boolean = true;
  /**
   * 「每次都验证」档的单独授权集合。必须用 @StorageProp 订阅：该档解锁只调
   * PrivateAccessRepository.grant()，改的是 AppStorage 里的这两个数组，
   * 没有订阅的话输对密码后 build 没有依赖变化，锁定页不会换成内容。
   */
  @StorageProp('privateGrantedBookKeys') privateGrantedBookKeys: string[] = [];
  @StorageProp('privateGrantedGroupIds') privateGrantedGroupIds: number[] = [];
  /** 密码对话框的输入与错误（对话框关闭时清空）；pending* 记录这一次是为哪个分组/哪本书解锁。 */
  @State passwordInput: string = '';
  @State passwordError: string = '';
  @State pendingUnlockGroupId: number = 0;
  @State pendingUnlockBookKey: string = '';
  /**
   * 五个 M3 AlertDialog 的对话框 id 与 builder（口径同 BookshelfManagePage 的导出输入框）。
   * 上游这五处都是 `AppAlertDialog`，不是底部 sheet；本地改用 openCustomDialog 承载，
   * 所以它们既不在 `bindSheet` 条件里，也不在 `ShelfSheetContent()` 的分支链里。
   */
  private batchDeleteDialogId: number = -1;
  private batchDeleteDialogBuilder: (() => void) | undefined = undefined;
  private batchDownloadDialogId: number = -1;
  private batchDownloadDialogBuilder: (() => void) | undefined = undefined;
  private addUrlDialogId: number = -1;
  private addUrlDialogBuilder: (() => void) | undefined = undefined;
  private passwordDialogId: number = -1;
  private passwordDialogBuilder: (() => void) | undefined = undefined;
  private aiApplyDialogId: number = -1;
  private aiApplyDialogBuilder: (() => void) | undefined = undefined;
  /** 记住上次分组只灌一次，避免后续设置对象刷新覆盖用户主动选择的页签。 */
  private tabPositionRestored: boolean = false;
  /** 书架窗口引用与尺寸回调，aboutToDisappear 时解绑，避免订阅泄漏。 */
  private bookshelfWindow: window.Window | undefined = undefined;
  private windowSizeListener: (size: window.Size) => void = (_size: window.Size): void => {};
  private readonly bookshelfScroller: Scroller = new Scroller();
  /** 文件夹根层分组网格的滚动控制器（A-22 回到顶部要按视图选 Scroller）。 */
  private readonly folderScroller: Scroller = new Scroller();
  onOpenBook: (book: Book, sharedCoverKey: string) => void = () => {};
  onOpenBookInfo: (book: Book) => void = () => {};
  onSearch: () => void = () => {};
  onImportBook: () => Promise<Book | undefined> = async () => undefined;
  /** 重新识别全部本地 TXT 的目录。 */
  onRefreshToc: () => Promise<void> = async () => {};
  /** 批2（:145）：书架「更多 → 下载全部」。只对在线书有意义，本地书由 Index 侧跳过并说明。 */
  onDownloadBooks: (books: Book[]) => void = (_books: Book[]) => {};
  /** 下拉刷新：参数是当前分组名，由 Index 侧按分组与刷新上限取书。 */
  onPullRefresh: (groupName: string) => void = (_groupName: string) => {};
  onAddGroup: (name: string) => void = (_name: string) => {};
  onRenameGroup: (id: number, name: string) => void = (_id: number, _name: string) => {};
  onSetGroupVisible: (id: number, visible: boolean) => void = (_id: number, _visible: boolean) => {};
  onRemoveGroup: (id: number) => void = (_id: number) => {};
  /** 按完整草稿新建分组，供分组编辑面板提交。 */
  onAddGroupDraft: (draft: BookGroupDraft) => Promise<void> = async (_draft: BookGroupDraft) => {};
  /** 保存编辑后的分组属性。 */
  onUpdateGroup: (id: number, draft: BookGroupDraft) => Promise<void> =
    async (_id: number, _draft: BookGroupDraft) => {};
  /** 选择分组封面，返回新的封面路径；用户取消时返回空串。 */
  onChooseGroupCover: (id: number) => Promise<string> = async (_id: number) => '';
  /** 为「尚未保存」的分组选封面：只复制副本并返回路径，不写分组表（上游 coverPath 草稿态）。 */
  onChooseGroupCoverDraft: () => Promise<string> = async () => '';
  /** 清除分组封面。 */
  onClearGroupCover: (id: number) => Promise<void> = async (_id: number) => {};
  /** 把分组拖到另一个分组的位置。 */
  onMoveGroup: (fromId: number, toId: number) => Promise<void> = async (_fromId: number, _toId: number) => {};
  /** 保存书架布局设置。 */
  onSaveLayout: (settings: BookshelfLayoutSettings) => Promise<void> =
    async (_settings: BookshelfLayoutSettings) => {};
  onUnavailableAction: (message: string) => void = (_message: string) => {};
  /** 把导入书单解析出的新书交给 Index 落库并刷新书架。 */
  onImportBookList: (books: Book[]) => Promise<void> = async (_books: Book[]) => {};
  /** 全量应用标签匹配规则，交给 Index 落库并刷新书架（:241）。 */
  onApplyTagGroupRules: () => Promise<void> = async () => {};
  /** 把若干本书挪到指定分组（:146）；走替换语义，空串表示移回未分组。 */
  onSetBooksGroup: (bookKeys: string[], groupName: string) => Promise<void> =
    async (_bookKeys: string[], _groupName: string) => {};
  /** 批量删书（:148 / :149）；deleteSource 只决定要不要清应用内导入副本。 */
  onDeleteBooks: (books: Book[], deleteSource: boolean) => Promise<void> =
    async (_books: Book[], _deleteSource: boolean) => {};
  /** 拖拽重排后把新顺序交给 Index 落库并同步内存（:138）。 */
  onMoveBooks: (ordered: Book[]) => Promise<void> = async (_ordered: Book[]) => {};
  /** 批量把书设成**多个**分组（H-5：上游 GroupSelectSheet 是多选，掩码加减）。 */
  onSetBooksGroupsByNames: (bookKeys: string[], groupNames: string[]) => Promise<void> =
    async (_bookKeys: string[], _groupNames: string[]) => {};
  /** 批量设/取消单本私密标记（:294 / :147）；由 Index 落库后刷新 books。 */
  onSetBooksPrivate: (bookKeys: string[], isPrivate: boolean) => Promise<void> =
    async (_bookKeys: string[], _isPrivate: boolean) => {};
  /**
   * 进书架管理页（上游 `BookshelfScreen.kt:744-752`）：
   * `onNavigateToCache(uiState.groups.getOrNull(uiState.selectedGroupIndex)?.groupId ?: -1L)`。
   * 第十表 H-8：入口参数就是 **groupId**，不是分组名——上游 `MainRouteCache(groupId)` 一路带进去，
   * 管理页 `LaunchedEffect(groupId) { Initialize(groupId) }` 再按它取书单。
   */
  onOpenBookshelfManage: (groupId: number) => void = (_groupId: number) => {};

  /** 目录或进度变更后让书架卡片重建，避免 ArkUI 复用旧章节角标。 */
  /** 书卡 Grid 的数据源（:154）；只覆盖书卡，分组卡 Grid 仍是 ForEach。 */
  private bookshelfData: BookshelfBookDataSource = new BookshelfBookDataSource();
  /**
   * 非空时显示全屏加载遮罩，内容即提示文案；空串不显示（:156）。
   * 上游那个对话框不可取消（Dialog(onDismissRequest = {})），本地同样不可取消。
   */
  @State busyText: string = '';

  /** 数据源脏了：整批重算一次可见书（:154）。LazyForEach 不会自己跟着 build 重算。 */
  private onBookshelfDataDirty(): void {
    this.bookshelfData.setItems(this.getVisibleBooks());
    // :368（批6，r360）：书到位了就不再等 loading 翻转——直接置满，避免出现卡在 0 的标题。
    if (!this.bookshelfLoading) { this.titleRevealStep = 999; }
  }

  /**
   * :368（批6，r360）加载态翻转：开始时把进度清零（标题先隐去），结束时一次性置满。
   * 置满的那一次状态变化会让每个字带着自己的延迟淡入——不需要定时器逐字推进。
   */
  private onBookshelfLoadingChanged(): void {
    this.titleRevealStep = this.bookshelfLoading ? 0 : 999;
  }

  private bookCardKey(book: Book): string {
    // 列表模式卡片会展示最新章节名与简介，这两个字段变化时也要让卡片重建。
    // 后两位是私密标记与当前锁定态（:325）：ArkUI 的 ForEach 在 key 不变时直接复用旧节点，
    // 把这两项漏在 key 外面，改「设为私密」或重启后解锁态变化都不会重画锁遮罩。
    return `${book.id}_${book.chapterCount ?? ''}_${book.chapterIndex ?? 0}_${book.chapterProgress ?? 0}_${bookCoverMark(book)}_${BookRepository.isBodyMissing(book) ? 1 : 0}_${book.lastChapter}_${book.description ?? ''}_${book.isPrivate === true ? 1 : 0}_${this.isBookLocked(book) ? 1 : 0}`;
  }

  /** A-22：底栏重复点「书架」→ 当前视图滚到首项（上游 animateScrollToItem(0)）。 */
  private onScrollToTopRequest(): void {
    if (this.scrollToTopRequest <= 0) { return; }
    const target: Scroller = (this.layout.bookGroupStyle === 2 && this.folderViewGroup.length === 0)
      ? this.folderScroller
      : this.bookshelfScroller;
    try {
      target.scrollToIndex(0, true);
    } catch (_error) {
      // 网格还没挂载（空态 / 私密锁定面板）时 scrollToIndex 会抛，忽略即可。
    }
  }

  aboutToAppear(): void {
    // Index 的布局恢复是异步的；这里先尝试一次，若拿到的是默认值，@Watch 会在恢复完成后再灌一次。
    this.onLayoutChanged();
    this.resolveWindowOrientation();
    AppLog.put(`书架已显示 ${this.books.length} 本书`);
    this.refreshCachedTagColors();
    this.onBookshelfDataDirty();
    // :368（批6，r360）：初始值就是「加载中」时 @Watch 不会触发，这里补一次。
    if (this.bookshelfLoading) { this.titleRevealStep = 0; }
  }

  aboutToDisappear(): void {
    if (this.bookshelfWindow !== undefined) {
      this.bookshelfWindow.off('windowSizeChange', this.windowSizeListener);
      this.bookshelfWindow = undefined;
    }
  }

  /**
   * 读取当前窗口方向（F1）：window.getLastWindow 取窗口矩形，width > height 即横屏；
   * 同时订阅 windowSizeChange，旋转后立刻刷新 isLandscape。
   * 网格容器的 onAreaChange 也会再兜底一次（组件级尺寸回调，旋转必触发）。
   */
  private resolveWindowOrientation(): void {
    const context = this.getUIContext().getHostContext();
    if (context === undefined) { return; }
    window.getLastWindow(context).then((targetWindow: window.Window) => {
      this.bookshelfWindow = targetWindow;
      const rect = targetWindow.getWindowProperties().windowRect;
      this.isLandscape = rect.width > rect.height;
      this.windowSizeListener = (size: window.Size): void => {
        const landscape: boolean = size.width > size.height;
        if (landscape !== this.isLandscape) { this.isLandscape = landscape; }
      };
      targetWindow.on('windowSizeChange', this.windowSizeListener);
    }).catch(() => {});
  }

  /** layout 异步恢复完成后，把记住的分组灌进当前筛选（只在拿到具体分组名时锁定）。 */
  private onLayoutChanged(): void {
    // 布局异步恢复完成后重新解析标签配色缓存（:124 的渲染总开关在这里生效）。
    this.refreshCachedTagColors();
    // 离开「文件夹」分组样式后清掉组内导航，避免下次切回时残留子视图。
    if (this.layout.bookGroupStyle !== 2 && this.folderViewGroup.length > 0) {
      this.folderViewGroup = '';
    }
    if (this.tabPositionRestored) { return; }
    const remembered = this.layout.saveTabPosition;
    if (remembered.length === 0 || remembered === '全部') { return; }
    if (this.getGroupNames().includes(remembered)) {
      this.tabPositionRestored = true;
      this.selectedFilter = remembered;
    }
    // layout 里带着排序方式与排序方向，换排序就是换可见书的顺序（:154）。
    this.onBookshelfDataDirty();
  }

  /** 切换分组并写回「记住上次所在分组」。 */
  private async selectGroup(name: string): Promise<void> {
    this.tabPositionRestored = true;
    this.selectedFilter = name;
    const next = copyBookshelfLayout(this.layout);
    next.saveTabPosition = name;
    await this.onSaveLayout(next);
  }

  private getGroupNames(): string[] {
    const names: string[] = ['全部'];
    const userGroups = this.groups.filter((group: BookGroup) => group.groupId > 0);
    // 「本地未分组」是内置分组，show 由分组管理里的开关控制，默认 false。
    // 对齐上游：AppDatabase.kt:433 插入时 show = 0，BookGroupDao.kt:24 只取 show > 0，
    // 所以未手动打开前它不出现在页签上（此前本地是「有未分组书就无条件显示」）。
    if (this.isLocalNoneGroupVisible() && this.books.some((book: Book) => (book.groupNames ?? []).length === 0)) {
      names.push(BookGroupRepository.LOCAL_NONE_GROUP_NAME);
    }
    userGroups.filter((group: BookGroup) => group.show)
      .sort((left: BookGroup, right: BookGroup) => left.order - right.order)
      .forEach((group: BookGroup) => {
        if (!names.includes(group.groupName)) { names.push(group.groupName); }
      });
    // 旧数据中的名称若没有分组定义则仍可见；已明确隐藏的分组保持隐藏。
    this.books.forEach((book: Book) => {
      (book.groupNames ?? []).forEach((name: string) => {
        const definition = userGroups.find((group: BookGroup) => group.groupName === name);
        if (name.length > 0 && definition === undefined && !names.includes(name)) { names.push(name); }
      });
    });
    // 「隐藏没有书籍的分组」只过滤自定义分组，「全部」永远保留。
    if (!this.layout.hideEmptyGroups) { return names; }
    return names.filter((name: string) => name === '全部' || this.countBooksInGroup(name) > 0);
  }

  /** 「本地未分组」内置分组的当前显示态；库里缺这一行时按上游默认（false）处理。 */
  private isLocalNoneGroupVisible(): boolean {
    const builtin = this.groups.find((group: BookGroup) =>
      group.groupId === BookGroupRepository.LOCAL_NONE_GROUP_ID);
    return builtin !== undefined && builtin.show;
  }

  /** 某个分组下的书籍数量，供隐藏空分组使用。 */
  private countBooksInGroup(name: string): number {
    return this.books.filter((book: Book) => {
      const names = book.groupNames ?? [];
      return name === '本地未分组' ? names.length === 0 : names.includes(name);
    }).length;
  }

  /**
   * 实际生效的分组筛选。
   *
   * 打开「隐藏没有书籍的分组」后当前选中的分组可能被过滤掉，
   * 此时回落到「全部」，避免出现页签消失但仍按旧分组过滤的空书架。
   */
  private activeFilter(): string {
    const names = this.getGroupNames();
    return names.includes(this.selectedFilter) ? this.selectedFilter : '全部';
  }

  /**
   * 当前生效分组的 groupId（第十表 H-8）。
   *
   * 对齐上游 `BookshelfScreen.kt:747-749`：
   * `uiState.groups.getOrNull(uiState.selectedGroupIndex)?.groupId ?: -1L`。
   * 上游页签列表里的第一项是「全部」，它的 groupId 就是 `BookGroup.IdAll = -1L`；
   * 本地页签按名字组织，所以这里按名字反查：
   * - 「全部」→ `-1`（IdAll）
   * - 「本地未分组」→ `BookGroupRepository.LOCAL_NONE_GROUP_ID`（`-5`，与上游 IdLocalNone 同值）
   * - 其余 → 分组定义里的 groupId
   * - 查不到（页签被过滤掉时已回落到「全部」，理论上不会走到）→ `-1`
   */
  private activeGroupId(): number {
    const name = this.activeFilter();
    if (name === '全部') { return -1; }
    if (name === BookGroupRepository.LOCAL_NONE_GROUP_NAME) {
      return BookGroupRepository.LOCAL_NONE_GROUP_ID;
    }
    const group = this.groups.find((item: BookGroup) => item.groupName === name);
    return group !== undefined ? group.groupId : -1;
  }

  /**
   * 当前是否允许下拉刷新。
   *
   * 对齐上游 BookshelfScreen.kt:929-930：
   *   pullToRefreshEnabled = (currentGroup?.enableRefresh ?: true) && !isEditMode
   * 上游注释特别强调这里不能缓存（分组开关会变），所以每次都现算，不放进 remember/derivedStateOf。
   */
  private canPullRefresh(): boolean {
    if (this.selectionMode) { return false; }
    const current = this.activeFilter();
    // '全部' 没有对应的分组定义，按上游默认值 true 处理。
    if (current === '全部') { return true; }
    const group = this.groups.find((item: BookGroup) => item.groupName === current);
    return group === undefined ? true : group.enableRefresh;
  }

  /** 下拉触发。上游同样是 `if (isRefreshing) return`，重复触发直接忽略。 */
  private async handlePullRefresh(): Promise<void> {
    if (this.pullRefreshing) { return; }
    this.pullRefreshing = true;
    try {
      await this.onPullRefresh(this.activeFilter());
    } finally {
      this.pullRefreshing = false;
    }
  }

  /**
   * 下拉指示器。与首页 HomePage.RefreshIndicatorBuilder 是同一个组件，
   * 两处下拉长得一致（任务书 6.8：书架不能和主页两个样式）。
   */
  @Builder
  private pullIndicatorBuilder() {
    PullRefreshIndicator({
      armed: this.pullArmed,
      refreshing: this.pullRefreshing,
      pullDistance: this.pullOffsetValue
    });
  }

  /**
   * 顶栏标题，照上游 BookshelfViewModel.kt:921-947 的 buildTitle 四分支：
   * 搜索态且页签模式 → 「书架」；搜索态或隐藏页签 → 当前分组名（取不到回落「书架」）；
   * 文件夹模式 → 根层「书架」、进入分组后显示分组名；其余 → 「书架」。
   * 上游末尾的「有更新书时拼 (N)」这一支由批3（r359）补上，见下方 waitUp；
   * 「编辑态一律『书架』」这一支还没接（选择模式已在 :202 就位，标题这一处仍是纯标题口径）。
   */
  private bookshelfTitle(): string {
    // A-3：对齐上游 BookshelfScreen.kt:1356-1361——加载中标题固定显示 R.string.loading「加载中…」，
    // 数据到位后才换成真实标题（本地另保留 titleRevealStep 的逐字淡入）。
    if (this.bookshelfLoading) {
      return '加载中…';
    }
    const shelf = '书架';
    const inSearch = this.showSearch;
    const style = this.layout.bookGroupStyle;
    const groupName = this.activeFilter();
    const hasGroup = groupName.length > 0 && groupName !== '全部';
    let title = shelf;
    if (inSearch && style === 0) {
      title = shelf;
    } else if (inSearch || style === 1) {
      title = hasGroup ? groupName : shelf;
    } else if (style === 2) {
      title = this.folderViewGroup.length > 0 ? this.folderViewGroup : shelf;
    }
    // 批3（r359）：尾巴只在「显示等待更新数量」打开时拼，计数来自 TocRefreshQueue
    // （waitUp.size + onUp.size，上游 postUpBooksCount 同款）。注意不是书架里
    // lastCheckCount > 0 的书数——那是「上次刷出多少新章」，两者语义不同。
    const waitUp = this.layout.showWaitUpCount ? this.tocPendingCount : 0;
    return waitUp > 0 ? `${title} (${waitUp})` : title;
  }

  /**
   * 顶栏副标题，照上游 BookshelfViewModel.kt:676-698：搜索态显示「共 N 本」，
   * 编辑态显示「已选 N 本 · 本组共 M 本」，其余为空（不渲染）。
   * 选择模式字段 `selectionMode` 已在 :202 就位，但副标题这一处的编辑态分支还没接，
   * 目前只做搜索态一支；返回空串表示不显示。
   */
  private bookshelfSubtitle(): string {
    // A-4：对齐上游 BookshelfViewModel.kt:676-698 的三分支——编辑态由
    // bookshelf_selected_count「已选%1$d本」+ bookshelf_total_count「共%1$d本」两段拼成，
    // 搜索态只给总数，其余不显示。
    if (this.selectionMode) {
      return `已选${this.selectedBookKeys.size}本 · 共${this.getVisibleBooks().length}本`;
    }
    if (this.showSearch) {
      return `共${this.getVisibleBooks().length}本`;
    }
    return '';
  }

  /**
   * 「标签显示内容」右侧描述：开着的三项用 · 连起来。
   * 一项没开时对齐上游 BookshelfConfigSheet.kt:512-513 的 `.ifEmpty { bookshelf_tag_none }`
   * （zh-rCN「未选择显示内容」），文案用上游术语「用户标签 / 书源分类 / 字数」。
   */
  private tagSourcesLabel(): string {
    const selected: string[] = [];
    if (this.layoutDraft.bookshelfShowCustomTags) { selected.push('用户标签'); }
    if (this.layoutDraft.bookshelfShowSourceTags) { selected.push('书源分类'); }
    if (this.layoutDraft.bookshelfShowWordCount) { selected.push('字数'); }
    return selected.length > 0 ? selected.join(' · ') : '未选择显示内容';
  }

  /** 打开标签内容对话框：草稿取当前设置（上游 rememberSaveable 初始值）。 */
  private openTagContentDialog(): void {
    this.tagDialogCustom = this.layoutDraft.bookshelfShowCustomTags;
    this.tagDialogSource = this.layoutDraft.bookshelfShowSourceTags;
    this.tagDialogWordCount = this.layoutDraft.bookshelfShowWordCount;
    this.showTagContentDialog = true;
  }

  /** 确认：三项一起写回（上游 onConfirm 的 `it.copy(bookshelfShowCustomTags = ..., ...)`）。 */
  private applyTagContentDialog(): void {
    this.updateLayoutDraft((draft: BookshelfLayoutSettings) => {
      draft.bookshelfShowCustomTags = this.tagDialogCustom;
      draft.bookshelfShowSourceTags = this.tagDialogSource;
      draft.bookshelfShowWordCount = this.tagDialogWordCount;
    });
    this.showTagContentDialog = false;
  }
  /** 标签行取色缓存：总开关关掉时传空数组，卡片侧统一回落主题色（:124）。 */
  private refreshCachedTagColors(): void {
    this.cachedTagColors = this.layout.enableCustomTagColors
      ? parseTagColors(this.layout.customTagColorsJson) : [];
  }

  /** 标签行第 index 个标签的文字色；配色为空或该项为 0 时回落主题强调色。 */
  private tagTextColor(index: number): string {
    if (this.cachedTagColors.length === 0) { return this.themeColorAccent; }
    const pair = this.cachedTagColors[index % this.cachedTagColors.length];
    return pair !== undefined && pair.textColor !== 0 ? argbToColorHex(pair.textColor) : this.themeColorAccent;
  }

  /** 标签行第 index 个标签的背景色；两个 0 都回落主题次级底色，避免画纯黑块。 */
  private tagBgColor(index: number): string {
    if (this.cachedTagColors.length === 0) { return this.themeColorSurfaceTertiary; }
    const pair = this.cachedTagColors[index % this.cachedTagColors.length];
    return pair !== undefined && pair.bgColor !== 0 ? argbToColorHex(pair.bgColor) : this.themeColorSurfaceTertiary;
  }

  /** 「管理标签配色」入口的描述：当前布局草稿里有几组配色。 */
  private tagColorsCount(): number {
    return parseTagColors(this.layoutDraft.customTagColorsJson).length;
  }

  /** 打开配色管理页：草稿从当前布局草稿解析，容错非法 JSON。 */
  private openTagColorPage(): void {
    this.tagColorsDraft = parseTagColors(this.layoutDraft.customTagColorsJson);
    this.showTagColorPicker = false;
    this.showTagColorPage = true;
  }

  /**
   * 配色页每次改动都即时落库：草稿序列化回 layoutDraft，经 onSaveLayout 写盘，
   * 同时刷新标签行取色缓存，不依赖布局面板「完成」才生效。
   */
  private async persistTagColors(): Promise<void> {
    const next = copyBookshelfLayout(this.layoutDraft);
    next.customTagColorsJson = JSON.stringify(this.tagColorsDraft);
    this.layoutDraft = copyBookshelfLayout(next);
    await this.onSaveLayout(copyBookshelfLayout(next));
    this.cachedTagColors = next.enableCustomTagColors ? parseTagColors(next.customTagColorsJson) : [];
  }

  /** 「生成」：按主题色相整组替换成 8 组（上游 TagColorGenerator 口径）。 */
  private async generateTagColors(): Promise<void> {
    this.tagColorsDraft = generateTagColors(baseHueFromHex(this.themeColorAccent));
    await this.persistTagColors();
  }

  /** 「添加」：追加一组 (0,0) 并立刻打开取色器编辑它。 */
  private async addTagColor(): Promise<void> {
    const empty: TagColorPair = { textColor: 0, bgColor: 0 };
    const next: TagColorPair[] = [...this.tagColorsDraft, empty];
    this.tagColorsDraft = next;
    await this.persistTagColors();
    this.openTagColorPicker(next.length - 1);
  }

  /** 删除第 index 组配色。 */
  private async removeTagColor(index: number): Promise<void> {
    const next: TagColorPair[] = this.tagColorsDraft.slice();
    next.splice(index, 1);
    this.tagColorsDraft = next;
    await this.persistTagColors();
  }

  /** 打开取色器：带出该项文字色，输入 hex 后由背景色按 HSL 推导。 */
  private openTagColorPicker(index: number): void {
    this.tagColorEditIndex = index;
    const pair = this.tagColorsDraft[index];
    this.tagColorPickerHex = pair !== undefined && pair.textColor !== 0 ? argbToColorHex(pair.textColor) : '';
    this.showTagColorPicker = true;
  }

  /** 取色器确定：只取文字色，背景色由 deriveTagBgColor 推导（同色相低饱和高亮）。 */
  private async confirmTagColor(): Promise<void> {
    const color = hexToArgb(this.tagColorPickerHex);
    if (color === 0) { this.onUnavailableAction('颜色格式不对，请输入 #RRGGBB'); return; }
    const next: TagColorPair[] = this.tagColorsDraft.slice();
    const index = this.tagColorEditIndex;
    if (index >= 0 && index < next.length) {
      const updated: TagColorPair = { textColor: color, bgColor: deriveTagBgColor(color) };
      next[index] = updated;
    }
    this.tagColorsDraft = next;
    this.showTagColorPicker = false;
    await this.persistTagColors();
  }


  /** 未读章节数角标文字：showUnread 且未读>0 才有值（上游 BookItem.kt:752）。 */
  private unreadTextOf(book: Book): string {
    if (!this.layout.showUnread) { return ''; }
    const unread = BookRepository.unreadOf(book);
    return unread > 0 ? `${unread}` : '';
  }

  /** 更新红点：showUnread 与 showUnreadNew 同时开且 lastCheckCount>0（上游耦合，别拆）。 */
  private showBadgeDotOf(book: Book): boolean {
    return this.layout.showUnread && this.layout.showUnreadNew && (book.lastCheckCount ?? 0) > 0;
  }

  /**
   * 书籍类型标签：照上游 `BookItem.kt:754-764` 的五分支写。
   *
   * 上游口径是 `when { isAudio -> 音频; isImage -> 漫画; type and webFile > 0 -> 网页文件;
   * isLocal -> 本地; else -> 小说 }`，文案取 `values-zh-rCN/strings.xml` 的 audio/manga/web_file/local/noval。
   * 本地 `Book` 没有 `webFile` 位标志（`BookMediaType` 只有 text/audio/image），第三个分支留空实现。
   * 改前这里按 `book.format` 映射成 EPUB/PDF/MOBI/UMD/TXT，是上游不存在的一档口径。
   */
  private bookTypeLabel(book: Book): string {
    if (!this.layout.showTip) { return ''; }
    if (book.bookType === 'audio') { return '音频'; }
    if (book.bookType === 'image') { return '漫画'; }
    // 上游第三分支是 `(book.type and BookType.webFile) > 0`；本地无 webFile 位，故不实现。
    if (book.isLocal) { return '本地'; }
    return '小说';
  }

  /** 标签拼接顺序：自定义标签 → 来源分类(去重) → 字数，三段各由对应开关控制。 */
  private displayTagsOf(book: Book): string[] {
    if (!this.layout.bookshelfShowTag) { return []; }
    const tags: string[] = [];
    const sources: string[] = [];
    if (this.layout.bookshelfShowCustomTags) { sources.push(book.customTag ?? ''); }
    if (this.layout.bookshelfShowSourceTags) { sources.push(book.category); }
    for (const raw of sources) {
      const pieces = raw.split(/[,\n]/);
      for (const piece of pieces) {
        const tag = piece.trim();
        if (tag.length > 0 && tags.indexOf(tag) < 0) { tags.push(tag); }
      }
    }
    if (this.layout.bookshelfShowWordCount) {
      const wc = book.wordCount ?? '';
      if (wc.length > 0 && tags.indexOf(wc) < 0) { tags.push(wc); }
    }
    return tags;
  }

  /**
   * 作者行：精简模式合成「作者 • N章未读」，未读为 0 只显示作者。
   *
   * 文案取上游 `values-zh-rCN/strings.xml` 的 `author_read = %1$s • %2$d章未读`
   * （`BookItem.kt:865-869` 的 `stringResource(R.string.author_read, book.author, unreadCount)`）；
   * 改前本地用的是「作者 · N 未读」，分隔符与「章」字都跟上游不一致。
   */
  private authorLineOf(book: Book): string {
    const author = book.author.length > 0 ? book.author : '作者未知';
    if (this.layout.bookshelfLayoutCompact) {
      const unread = BookRepository.unreadOf(book);
      return unread > 0 ? `${author} • ${unread}章未读` : author;
    }
    return author;
  }

  /**
   * 列表卡简介文本：先过 HtmlFormatter，再按「行数设置」走摘要或全文（上游 BookItem.kt:742-749）。
   *
   * 空简介返回空串，调用方据此不渲染整块（上游 `showIntro = showIntroText && intro != null`）。
   */
  private introTextOf(book: Book): string {
    return IntroFormatCache.getOrFormat(book.description ?? '', this.layout.bookshelfIntroMaxLines);
  }

  /** 简介是否真的会显示：详情总门 + 显示简介开关 + 有内容（上游 `:739-749`）。 */
  private hasIntroOf(book: Book): boolean {
    return this.showsListDetails() && this.layout.bookshelfShowIntro && this.introTextOf(book).length > 0;
  }

  /**
   * 搜索命中书源名：处于搜索态、搜索词非空、且书源名包含搜索词时返回书源名（上游 `BookItem.kt:765-773`）。
   *
   * 上游是 `book.originName.contains(searchKey, ignoreCase = true)`，本地书源名在 `book.originName`。
   */
  private matchedSourceLabelOf(book: Book): string {
    const key = this.searchQuery.trim();
    if (key.length === 0) { return ''; }
    const origin = book.originName ?? '';
    if (origin.length === 0) { return ''; }
    return origin.toLocaleLowerCase().includes(key.toLocaleLowerCase()) ? origin : '';
  }

  /**
   * 卡片无障碍文案，对齐上游 `BookItem.kt:814-823` + `:1078-1090` 的 `bookAccessibilityLabel`。
   *
   * 上游按「书名、作者、未读数+未读、加载中、当前阅读章、最新章节、命中书源、类型标签」顺序拼接，
   * 空串跳过、去重、以「, 」连接。锁定态整段换成 `private_hidden_label`（已隐藏），不泄漏书名。
   */
  private a11yLabelOf(book: Book): string {
    if (this.isBookLocked(book)) { return '已隐藏'; }
    const details: string[] = [];
    const unread = this.unreadTextOf(book);
    const parts: string[] = [
      book.title,
      book.author,
      unread.length > 0 ? `${unread} 未读` : '',
      this.refreshingOf(book) ? '加载中…' : '',
      book.lastChapter,
      book.latestChapterTitle ?? '',
      this.matchedSourceLabelOf(book),
      this.bookTypeLabel(book)
    ];
    for (const part of parts) {
      const text = part.trim();
      if (text.length > 0 && details.indexOf(text) < 0) { details.push(text); }
    }
    return details.join(', ');
  }

  /** 该书是否正在刷新目录（refreshingBookIds 用 contentPath 作主键）。 */
  private refreshingOf(book: Book): boolean {
    const key = book.contentPath ?? book.androidOriginalPath ?? '';
    return this.refreshingBookIds.indexOf(key) >= 0;
  }

  /**
   * 横向可滚动标签行。标签按索引取 customTagColors 里的配色（index % size），
   * 两个 0 都回落主题色；总开关由 refreshCachedTagColors 控制（:124）。
   */
  @Builder
  private BookTagRow(book: Book) {
    if (this.displayTagsOf(book).length > 0) {
      Scroll() {
        Row({ space: 4 }) {
          ForEach(this.displayTagsOf(book), (tag: string, index: number) => {
            Text(tag).fontSize(LABEL_SMALL_EMPHASIZED).fontWeight(FontWeight.Medium)
              .fontColor(this.tagTextColor(index))
              .padding({ left: 6, right: 6, top: 2, bottom: 2 })
              .backgroundColor(this.tagBgColor(index)).borderRadius(4)
          }, (tag: string) => tag)
        }
      }.scrollable(ScrollDirection.Horizontal).scrollBar(BarState.Off).width('100%')
        .margin({ top: 2, bottom: 2 })
    }
  }

  private getVisibleBooks(): Book[] {
    // H-4：拖动中一律读临时列表（上游 :1730 `displayBooks = draggingBooks ?: ... ?: books`）。
    // 拖拽期间若还按 books 重算，落库前的顺序会被筛选+排序覆盖，拖动看起来「弹回去」。
    if (this.dragActive) { return this.draggingBooks; }
    const selectedGroup = this.activeFilter();
    const query = this.searchQuery.trim().toLocaleLowerCase();
    const filtered = this.books.filter((book: Book) => {
      const names = book.groupNames ?? [];
      const matchesGroup = selectedGroup === '全部' ||
        (selectedGroup === '本地未分组' ? names.length === 0 : names.includes(selectedGroup));
      const matchesQuery = query.length === 0 || book.title.toLocaleLowerCase().includes(query) ||
        book.author.toLocaleLowerCase().includes(query);
      return matchesGroup && matchesQuery;
    });
    // 分组设了自己的排序方式就覆盖书架全局，与上游 sortBooks() 的取值优先级一致。
    const activeGroup = this.groups.find((group: BookGroup) =>
      group.groupId > 0 && group.groupName === selectedGroup);
    return BookshelfSort.sortBooks(filtered, activeGroup,
      this.layout.bookshelfSort, this.layout.bookshelfSortOrder);
  }

  /** 书籍的稳定键：与 books 表主键同口径（contentPath 优先），不用 book.id。 */
  private bookKey(book: Book): string {
    return LocalBookRestorePlanner.bookUrlOf(book);
  }

  /**
   * 当前分组的分组 id，用作共享元素键的来源标识。
   *
   * 对齐上游 `BookshelfScreen.kt:1778` 的 `bookshelfSharedCoverSourceId(sharedCoverGroupId)`：
   * 「全部」与「本地未分组」不是真实分组，用 0 表示，键里就不带来源段。
   */
  private sharedCoverSourceId(): string {
    const selectedGroup = this.activeFilter();
    const group = this.groups.find((item: BookGroup) => item.groupName === selectedGroup);
    return bookshelfSharedCoverSourceId(group === undefined ? 0 : group.groupId);
  }

  /**
   * 封面共享元素键。同一本书在不同分组页里键不同，避免两个页签同时在场时抢同一个锚点。
   *
   * 对齐上游 `ui/main/BookCoverSharedElement.kt:17-20 bookCoverSharedElementKey`。
   */
  private sharedCoverKeyOf(book: Book): string {
    if (!this.readerSharedElement) {
      return '';
    }
    return bookCoverSharedElementKey(this.bookKey(book), this.sharedCoverSourceId());
  }

  private isBookSelected(book: Book): boolean {
    return this.selectedBookKeys.has(this.bookKey(book));
  }

  /** 进/出选择模式（:87 / :142）；退出时清空选中集合。 */
  private toggleSelectionMode(): void {
    if (this.selectionMode) {
      this.clearSelection();
      return;
    }
    this.selectionMode = true;
    this.selectedBookKeys = new Set<string>();
  }

  /** 退出选择模式并清空选中（:87 顶栏关闭按钮与工具条「完成」都走这里）。 */
  private clearSelection(): void {
    this.selectionMode = false;
    this.selectedBookKeys = new Set<string>();
  }

  /** 单本切换选中（:142）；选中集合清空时自动退出选择模式，与 CatalogPage 同口径。 */
  private toggleBookSelection(book: Book): void {
    const key = this.bookKey(book);
    const next = new Set<string>(this.selectedBookKeys);
    if (next.has(key)) {
      next.delete(key);
    } else {
      next.add(key);
    }
    this.selectedBookKeys = next;
    if (next.size === 0) {
      this.selectionMode = false;
    }
  }

  /** 全选当前可见书（:143）；只看 getVisibleBooks()，不是全库，上游方法名就叫 SelectAllVisible。 */
  private selectAllVisible(): void {
    const next = new Set<string>(this.selectedBookKeys);
    this.getVisibleBooks().forEach((book: Book) => { next.add(this.bookKey(book)); });
    this.selectedBookKeys = next;
  }

  /** 反选当前可见书（:144）；只翻转可见那批，不可见的选中保持不变。 */
  private invertVisibleSelection(): void {
    const next = new Set<string>(this.selectedBookKeys);
    this.getVisibleBooks().forEach((book: Book) => {
      const key = this.bookKey(book);
      if (next.has(key)) {
        next.delete(key);
      } else {
        next.add(key);
      }
    });
    this.selectedBookKeys = next;
    if (next.size === 0) {
      this.selectionMode = false;
    }
  }

  /** 已选中的书籍对象，顺序按书架当前排序。 */
  private selectedBooks(): Book[] {
    return this.books.filter((book: Book) => this.selectedBookKeys.has(this.bookKey(book)));
  }

  /**
   * H-5：打开「选择分组」多选 Sheet。
   * 预勾选口径对齐上游 resolveSelectionGroupMask（BookshelfManageScreen.kt:365-370）：
   * 所有选中书的分组名排序后完全一致才预勾，否则一个都不勾。
   */
  private openMoveGroupSheet(): void {
    const sets = this.selectedBooks().map((book: Book) => (book.groupNames ?? []).slice().sort());
    let preset: string[] = [];
    if (sets.length > 0) {
      const first = sets[0];
      const same = sets.every((names: string[]) => names.length === first.length &&
        names.every((name: string, index: number) => name === first[index]));
      if (same) { preset = first.slice(); }
    }
    this.moveGroupSelectedNames = preset;
    this.showMoveGroupSheet = true;
  }

  /** H-5：勾选/取消一个分组（上游 selectedGroupId ± group.groupId 的名字版）。 */
  private toggleMoveGroupName(groupName: string): void {
    const index = this.moveGroupSelectedNames.indexOf(groupName);
    if (index >= 0) {
      const next = this.moveGroupSelectedNames.slice();
      next.splice(index, 1);
      this.moveGroupSelectedNames = next;
    } else {
      this.moveGroupSelectedNames = this.moveGroupSelectedNames.concat([groupName]);
    }
  }

  /** H-5：确认多选，一次写入多个分组名。 */
  private async confirmMoveGroups(): Promise<void> {
    const keys: string[] = [];
    this.selectedBooks().forEach((book: Book) => { keys.push(this.bookKey(book)); });
    const names = this.moveGroupSelectedNames.slice();
    this.showMoveGroupSheet = false;
    if (keys.length === 0) { return; }
    await this.onSetBooksGroupsByNames(keys, names);
    this.onUnavailableAction(names.length === 0
      ? `已移动 ${keys.length} 本到未分组`
      : `已移动 ${keys.length} 本到${names.join('、')}`);
    this.clearSelection();
  }

  /** 把选中的书挪到目标分组（:146）；'本地未分组' 传空串让掩码变成 0。 */
  private async moveSelectedToGroup(groupName: string): Promise<void> {
    const keys: string[] = [];
    this.selectedBooks().forEach((book: Book) => { keys.push(this.bookKey(book)); });
    if (keys.length === 0) { return; }
    const target = groupName === '本地未分组' ? '' : groupName;
    await this.onSetBooksGroup(keys, target);
    this.onUnavailableAction(`已移动 ${keys.length} 本到${target.length > 0 ? target : '未分组'}`);
    this.clearSelection();
  }

  /** 删除选中的书（:148 / :149）；对话框里才有「删除源文件」的勾选。 */
  private async executeBatchDelete(): Promise<void> {
    const books = this.selectedBooks();
    // 勾选值要在关框前取：closeBatchDeleteDialog 会把它复位。
    const deleteOriginal = this.batchDeleteSource;
    this.closeBatchDeleteDialog();
    if (books.length === 0) { return; }
    try {
      await this.onDeleteBooks(books, deleteOriginal);
    } finally {
      this.batchDeleteSource = false;
      this.clearSelection();
    }
  }

  /**
   * 拖拽重排是否可用（:138）：只有当前生效的排序方式是「手动」（bookSort === 3）才有意义。
   * BookshelfSort.compareBySort 六档里只有手动那档读 order，其它排序下拖完屏幕不会有变化，
   * 这是上游行为，不是没生效。
   */
  private canReorderBooks(): boolean {
    const group = this.groups.find((item: BookGroup) =>
      item.groupId > 0 && item.groupName === this.activeFilter());
    const sort = group !== undefined && group.bookSort >= 0 ? group.bookSort : this.layout.bookshelfSort;
    return sort === 3;
  }

  /**
   * H-4：拖拽开始，把当前可见书拍成临时列表（上游 `BookshelfViewModel.kt:1119-1121 startDraggingBooks`）。
   * 拖动过程中只改这份临时列表，不动 books，也不落库。
   */
  private startDragging(): void {
    if (this.dragActive) { return; }
    this.draggingBooks = this.getVisibleBooks().slice();
    this.dragActive = true;
    this.bookshelfData.setItems(this.draggingBooks);
  }

  /**
   * 拖动中把第 from 本挪到第 to 本（上游 `BookshelfViewModel.kt:1123-1130 moveDraggingBook`）：
   * 只改临时列表并刷新数据源，松手才保存。`from === to` 与越界一律忽略。
   */
  private moveDragging(from: number, to: number): void {
    if (!this.dragActive) { this.startDragging(); }
    const source = this.draggingBooks;
    if (from < 0 || to < 0 || from >= source.length || to >= source.length || from === to) { return; }
    const reordered: Book[] = source.slice();
    const moved = reordered.splice(from, 1)[0];
    if (moved === undefined) { return; }
    reordered.splice(to, 0, moved);
    this.draggingBooks = reordered;
    this.bookshelfData.setItems(reordered);
  }

  /**
   * 松手结束拖拽（上游 `BookshelfViewModel.kt:1132-1137 finishDraggingBooks`）：
   * 把临时列表交给 onMoveBooks 落库，然后清空临时态。
   * 上游是先把顺序交给 `pendingSavedBooks` 再异步保存，本地 Index 的 onMoveBooks 会回填 books，
   * 清掉 dragActive 之后 getVisibleBooks 立刻读回落库后的 books，观感一致。
   */
  private async finishDragging(): Promise<void> {
    if (!this.dragActive) { return; }
    const ordered = this.draggingBooks;
    this.dragActive = false;
    this.draggingBooks = [];
    this.bookshelfData.setItems(this.getVisibleBooks());
    await this.onMoveBooks(ordered);
  }

  /** 选择模式工具条里的「移动」菜单：列自定义分组再加「未分组」。 */
  @Builder
  private SelectionGroupMenu() {
    UiMenuPanel({
      items: this.selectionGroupItems(),
      panelWidth: SHELF_MENU_WIDTH,
      onSelect: (key: string) => {
        this.selectionGroupVisible = false;
        this.moveSelectedToGroup(key);
      }
    })
  }

  private selectionGroupItems(): UiMenuItem[] {
    // E-12：当前所在分组打勾（上游 BookshelfScreen.kt:1258-1296 的 trailingIcon 分支，
    // currentMenuGroupId == group.groupId 时画 Check）。UiMenuPanel 用 selected 渲染勾与强调色。
    const current = this.activeFilter();
    return this.getGroupNames()
      .filter((name: string) => name !== '全部')
      .map((groupName: string): UiMenuItem => {
        return {
          key: groupName,
          title: groupName === '本地未分组' ? '未分组' : groupName,
          selected: groupName === current
        };
      });
  }

  /**
   * 批量删除确认框，对齐上游 `BookshelfScreen.kt:1540-1573` 的 `AppAlertDialog`：
   * 标题 `delete_selected`（删除选中）、正文 `bookshelf_selected_count`（已选%1$d本）、
   * 有本地书时正文下方加一个「删除源文件」勾选（上游 `delete_book_file`）、按钮「删除」/「取消」。
   */
  @Builder
  private BatchDeleteDialog() {
    AppAlertDialog({
      title: '删除选中',
      text: `已选${this.selectedBookKeys.size}本`,
      confirmText: '删除',
      dismissText: '取消',
      onConfirm: () => { void this.executeBatchDelete(); },
      onDismiss: () => { this.closeBatchDeleteDialog(); }
    }) {
      if (this.selectedBooks().some((book: Book) => book.isLocal)) {
        DialogCheckRow({
          label: '删除源文件',
          initialChecked: this.batchDeleteSource,
          onCheckedChange: (checked: boolean) => { this.batchDeleteSource = checked; }
        })
      }
    }
  }

  private openBatchDeleteDialog(): void {
    this.batchDeleteSource = false;
    if (this.batchDeleteDialogId >= 0) { return; }
    this.batchDeleteDialogBuilder = (): void => { this.BatchDeleteDialog(); };
    this.getUIContext().getPromptAction().openCustomDialog({
      builder: this.batchDeleteDialogBuilder,
      autoCancel: true,
      alignment: DialogAlignment.Center,
      onWillDismiss: () => {
        this.batchDeleteDialogId = -1;
        this.batchDeleteSource = false;
      }
    }).then((id: number) => {
      this.batchDeleteDialogId = id;
    }).catch((error: Error) => {
      console.error(`[Bookshelf] 打开删除确认对话框失败: ${error}`);
    });
  }

  private closeBatchDeleteDialog(): void {
    this.batchDeleteSource = false;
    if (this.batchDeleteDialogId >= 0) {
      this.getUIContext().getPromptAction().closeCustomDialog(this.batchDeleteDialogId);
      this.batchDeleteDialogId = -1;
    }
  }

  /**
   * H-5：「选择分组」多选面板，对齐上游 GroupSelectSheet（BookInfoSheets.kt:108-190）。
   * 逐组一行：勾选框 + 组名 + 右侧编辑按钮；底部确认写入多分组掩码。
   * 上游 startAction 的「新增分组」在这里落成右上「新建」，复用本地分组编辑面板。
   */
  @Builder
  private MoveGroupSheetContent() {
    Column() {
      Row() {
        Text('选择分组').fontSize(TITLE_LARGE).fontWeight(FontWeight.Bold)
          .fontColor(this.themeColorTextPrimary).layoutWeight(1)
        Text('新建').fontSize(LABEL_MEDIUM).fontColor(this.themeColorAccent).padding(6)
          .onClick(() => { this.showMoveGroupSheet = false; this.openGroupEditor(undefined); })
      }.width('100%').padding({ left: 16, right: 16, top: 18, bottom: 12 })
      List({ space: 8 }) {
        ForEach(this.getGroupNames().filter((name: string) => name !== '全部'), (groupName: string) => {
          ListItem() {
            Row({ space: 10 }) {
              // 上游 leadingContent = AppCheckbox。AppGlyphName 没有「空勾」图标，
              // 这里自绘：18×18 圆角 4 方块，选中填充强调色并叠白勾，未选中只描边。
              Stack({ alignContent: Alignment.Center }) {
                if (this.moveGroupSelectedNames.indexOf(groupName) >= 0) {
                  AppGlyph({ name: 'profileCheck', glyphSize: 14, tint: '#101116' })
                }
              }
              .width(18).height(18).borderRadius(4)
              .backgroundColor(this.moveGroupSelectedNames.indexOf(groupName) >= 0
                ? this.themeColorAccent : Color.Transparent)
              .border({
                width: this.moveGroupSelectedNames.indexOf(groupName) >= 0 ? 0 : 1.5,
                color: this.themeColorTextTertiary
              })
              Text(groupName === '本地未分组' ? '未分组' : groupName)
                .fontSize(LABEL_LARGE).fontColor(this.themeColorTextPrimary).layoutWeight(1)
                .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
              // 上游 trailingAction = SmallPlainButton(Edit) → GroupEditSheet
              Text('编辑').fontSize(LABEL_SMALL).fontColor(this.themeColorTextSecondary).padding(6)
                .onClick(() => {
                  const target = this.groups.find((group: BookGroup) => group.groupName === groupName);
                  if (target !== undefined) {
                    this.showMoveGroupSheet = false;
                    this.openGroupEditor(target);
                  }
                })
            }
            .width('100%').padding({ left: 14, right: 14, top: 12, bottom: 12 })
            .borderRadius(12).backgroundColor(this.themeColorSurfaceSecondary)
            .onClick(() => { this.toggleMoveGroupName(groupName); })
          }
        }, (groupName: string) => groupName)
      }.layoutWeight(1).width('100%').scrollBar(BarState.Off)
        .padding({ left: 16, right: 16 })
      Row({ space: 12 }) {
        Text('取消').fontSize(LABEL_LARGE).fontColor(this.themeColorTextSecondary)
          .layoutWeight(1).textAlign(TextAlign.Center).padding({ top: 12, bottom: 12 })
          .borderRadius(12).backgroundColor(this.themeColorSurfaceSecondary)
          .onClick(() => { this.showMoveGroupSheet = false; })
        Text('确认').fontSize(LABEL_LARGE).fontColor(this.themeColorSurfacePrimary)
          .layoutWeight(1).textAlign(TextAlign.Center).padding({ top: 12, bottom: 12 })
          .borderRadius(12).backgroundColor(this.themeColorAccent)
          .onClick(() => { void this.confirmMoveGroups(); })
      }.width('100%').padding({ left: 16, right: 16, top: 12, bottom: 16 })
    }.width('100%').height('100%').backgroundColor('#17181E')
  }

  /**
   * H-10：批量下载二次确认，对齐上游 `BookshelfScreen.kt:1526-1538`：
   * `AppAlertDialog(title = R.string.draw「提醒」, text = R.string.sure_cache_book「是否确认开始缓存？」)`。
   * 正文不带数量（本地原先自造了「共 N 本。」）。
   */
  @Builder
  private BatchDownloadConfirmDialog() {
    AppAlertDialog({
      title: '提醒',
      text: '是否确认开始缓存？',
      confirmText: '确认',
      dismissText: '取消',
      onConfirm: () => {
        const books = this.selectedBooks();
        this.closeBatchDownloadDialog();
        this.onDownloadBooks(books);
      },
      onDismiss: () => { this.closeBatchDownloadDialog(); }
    })
  }

  private openBatchDownloadDialog(): void {
    if (this.batchDownloadDialogId >= 0) { return; }
    this.batchDownloadDialogBuilder = (): void => { this.BatchDownloadConfirmDialog(); };
    this.getUIContext().getPromptAction().openCustomDialog({
      builder: this.batchDownloadDialogBuilder,
      autoCancel: true,
      alignment: DialogAlignment.Center,
      onWillDismiss: () => { this.batchDownloadDialogId = -1; }
    }).then((id: number) => {
      this.batchDownloadDialogId = id;
    }).catch((error: Error) => {
      console.error(`[Bookshelf] 打开下载确认对话框失败: ${error}`);
    });
  }

  private closeBatchDownloadDialog(): void {
    if (this.batchDownloadDialogId >= 0) {
      this.getUIContext().getPromptAction().closeCustomDialog(this.batchDownloadDialogId);
      this.batchDownloadDialogId = -1;
    }
  }

  /** C-14 的「确认执行分组方案」对话框，对应上游 AppAlertDialog(ai_auto_group_confirm_*)。 */
  @Builder
  private AiApplyConfirmDialog() {
    AppAlertDialog({
      title: '确认执行分组方案',
      text: this.aiIncrementalOnly
        ? `将创建 ${this.aiNewGroupCount()} 个分组，为 ${this.aiAssignedCount()} 本未分组书籍设置分组，跳过 ${this.aiIgnoredBooks.length} 本书。已分组书籍和私密分组保持不变。`
        : `将创建 ${this.aiNewGroupCount()} 个分组，调整 ${this.aiAssignedCount()} 本书，跳过 ${this.aiIgnoredBooks.length} 本书。现有公开分组归属会被替换，私密分组保持不变。`,
      confirmText: '执行',
      dismissText: '取消',
      onConfirm: () => {
        this.closeAiApplyDialog();
        void this.aiConfirmApply();
      },
      onDismiss: () => { this.closeAiApplyDialog(); }
    })
  }

  private openAiApplyDialog(): void {
    if (this.aiApplyDialogId >= 0) { return; }
    this.aiApplyDialogBuilder = (): void => { this.AiApplyConfirmDialog(); };
    this.getUIContext().getPromptAction().openCustomDialog({
      builder: this.aiApplyDialogBuilder,
      autoCancel: true,
      alignment: DialogAlignment.Center,
      onWillDismiss: () => { this.aiApplyDialogId = -1; }
    }).then((id: number) => {
      this.aiApplyDialogId = id;
    }).catch((error: Error) => {
      console.error(`[Bookshelf] 打开分组方案确认对话框失败: ${error}`);
    });
  }

  private closeAiApplyDialog(): void {
    if (this.aiApplyDialogId >= 0) {
      this.getUIContext().getPromptAction().closeCustomDialog(this.aiApplyDialogId);
      this.aiApplyDialogId = -1;
    }
  }

  /** 当前所有私密分组的 id（:150 / :257）。分组上的 isPrivate 标记早就有，这里只是取出来用。 */  private privateGroupIds(): number[] {
    return this.getUserGroups()
      .filter((group: BookGroup) => group.isPrivate === true)
      .map((group: BookGroup) => group.groupId);
  }

  /** 这本书命中的第一个私密分组 id，没有则 0；单独授权时用它。 */
  private privateGroupIdOf(book: Book): number {
    const names = book.groupNames ?? [];
    const hit = this.getUserGroups().find((group: BookGroup) =>
      group.isPrivate === true && names.includes(group.groupName));
    return hit === undefined ? 0 : hit.groupId;
  }

  /**
   * 这本书现在要不要锁（:325）：单本标记并上所属私密分组，再看解锁有效期。
   *
   * 这里必须真的读一下 privateEnabled / privateUnlocked：`requiresPrivateUnlock` 读的是
   * AppStorage 静态快照，那次读取不会被 ArkUI 当成重绘依赖；只有 build 期间读过的
   * @StorageProp 才算。少了这两句，输对密码后书架不会重画，锁定页会一直停在原样。
   */
  private isBookLocked(book: Book): boolean {
    if (this.privateEnabled !== true) { return false; }
    if (!this.privateVerifyOnOpenBook) { return false; }
    if (!isPrivateBook(book, this.privateGroupIds())) { return false; }
    if (PrivateAccessRepository.get().unlockScope === PRIVATE_UNLOCK_EVERY_TIME) {
      // 读一下订阅到的授权集合，让 grant() 之后能触发重绘。
      const key = this.bookKey(book);
      const groupId = this.privateGroupIdOf(book);
      const granted = this.privateGrantedBookKeys.indexOf(key) >= 0
        || (groupId > 0 && this.privateGrantedGroupIds.indexOf(groupId) >= 0);
      return !granted;
    }
    if (this.privateUnlocked) { return false; }
    return requiresPrivateUnlock(this.bookKey(book), this.privateGroupIdOf(book));
  }

  /** 某个分组卡是否该画成锁定态（:257）。读 privateEnabled / privateUnlocked 的理由同 isBookLocked。 */
  private isGroupLocked(groupName: string): boolean {
    if (this.privateEnabled !== true) { return false; }
    if (!this.privateVerifyOnEnterGroup) { return false; }
    if (groupName === '全部' || groupName === '本地未分组') { return false; }
    const group = this.getUserGroups().find((item: BookGroup) => item.groupName === groupName);
    if (group === undefined || group.isPrivate !== true) { return false; }
    if (PrivateAccessRepository.get().unlockScope === PRIVATE_UNLOCK_EVERY_TIME) {
      const granted = this.privateGrantedGroupIds.indexOf(group.groupId) >= 0;
      return !granted;
    }
    if (this.privateUnlocked) { return false; }
    return requiresPrivateUnlock('', group.groupId);
  }

  /** 当前分组是不是「锁着的私密分组」：是就把整块内容换成锁定页（:150）。 */
  private activeGroupLocked(): boolean {
    return this.isGroupLocked(this.activeFilter());
  }

  /** 弹密码面板；bookKey 为空串表示只解这个分组。 */
  /** 能否直接弹系统生物验证框（上游 PrivateAccess.kt:70-72
   *  `canUseBiometricShortcut = biometricEnabled && biometricStatus == Available`）。 */
  private canUseBiometricShortcut(): boolean {
    return PrivateAccessRepository.isBiometricEnabled() &&
      PrivateAccessRepository.detectBiometricStatus() === PrivateBiometricStatus.AVAILABLE;
  }

  /** 解锁成功后的统一收尾：按解锁有效期授权并清空挂起目标（密码与生物两条路共用）。 */
  private completeUnlock(): void {
    if (PrivateAccessRepository.get().unlockScope === PRIVATE_UNLOCK_EVERY_TIME) {
      PrivateAccessRepository.grant(this.pendingUnlockBookKey, this.pendingUnlockGroupId);
    } else {
      PrivateAccessRepository.unlock();
    }
    this.closePasswordDialog();
    this.pendingUnlockGroupId = 0;
    this.pendingUnlockBookKey = '';
  }

  private requestPrivateUnlock(groupId: number, bookKey: string): void {
    if (!this.privateHasPassword) {
      // 没设过密码时不能假装能验证，直接引导去设置页（上游 private_content_no_password 口径）。
      this.onUnavailableAction('还没有设置本地密码，请到「我的 → 设置 → 隐私设置」设置后再查看');
      return;
    }
    // H-13：已解锁直接放行（上游 BookshelfViewModel.kt:857）。
    if (this.privateUnlocked) { return; }
    this.pendingUnlockGroupId = groupId;
    this.pendingUnlockBookKey = bookKey;
    this.passwordInput = '';
    this.passwordError = '';
    // H-13：能弹系统生物验证框就先弹（上游 :865-869 → Screen:261-282）。
    // 取消/失败回落密码面板，与上游 onFallback → ShowOverlay(PrivatePassword(target)) 一致。
    if (this.canUseBiometricShortcut()) {
      PrivateAccessRepository.authenticateBiometric(
        () => { this.completeUnlock(); },
        (_message: string) => { this.openPasswordDialog(); }
      );
      return;
    }
    this.openPasswordDialog();
  }

  /** 校验密码；通过后按当前解锁有效期授权这一次并关面板（:151）。 */
  private async submitPassword(): Promise<void> {
    const context = this.getUIContext().getHostContext();
    if (context === undefined) { return; }
    const ok = await PrivateAccessRepository.verifyPassword(context, this.passwordInput);
    if (!ok) {
      // 失败只报「密码错误」，不区分「没设过」与「不对」，避免泄露状态。
      // 上游走 snackbar（BookshelfViewModel.kt:872-887），这里先关框再提示，避免被对话框遮住。
      this.closePasswordDialog();
      this.onUnavailableAction('密码错误');
      return;
    }
    this.completeUnlock();
  }

  /** 选择模式里的私密按钮文案：全都没标才是「设为私密」（:147）。 */
  private selectionTargetPrivate(): boolean {
    return this.selectedBooks().every((book: Book) => book.isPrivate !== true);
  }

  /** 批量设/取消私密标记（:147）。 */
  private async toggleSelectedPrivate(): Promise<void> {
    const keys: string[] = [];
    this.selectedBookKeys.forEach((key: string) => { keys.push(key); });
    if (keys.length === 0) { return; }
    await this.onSetBooksPrivate(keys, this.selectionTargetPrivate());
  }

  /**
   * 私密分组锁定页（:150）。
   * 只替换「这个分组自己的内容」，顶栏与分组页签保持不动——否则用户会被卡在锁定页里，
   * 连相邻分组都切不过去（上游 PrivateGroupLockedPage 的注释）。
   * 两种文案分开：设过密码给「验证后查看」，没设过给「设置本地密码」。
   */
  @Builder
  private PrivateGroupLockedPanel() {
    Column() {
      AppGlyph({ name: 'lock', glyphSize: 34, tint: this.themeColorTextTertiary })
      Text(this.privateHasPassword ? '这个分组已锁定' : '这个分组是私密分组')
        .fontSize(TITLE_MEDIUM).fontColor(this.themeColorTextPrimary).margin({ top: 12 })
      Text(this.privateHasPassword ? '验证后可以查看组内书籍' : '先在隐私设置里设置本地密码，才能查看组内书籍')
        .fontSize(BODY_SMALL).fontColor(this.themeColorTextTertiary).margin({ top: 6 })
      Text(this.privateHasPassword ? '验证后查看' : '设置本地密码')
        .fontSize(LABEL_MEDIUM).fontColor(this.themeColorAccent).padding({ left: 18, right: 18, top: 8, bottom: 8 })
        .backgroundColor(this.themeColorSurfaceElevated).borderRadius(16).margin({ top: 16 })
        .onClick(() => {
          if (!this.privateHasPassword) {
            this.onUnavailableAction('请到「我的 → 设置 → 隐私设置」设置本地密码');
            return;
          }
          const group = this.getUserGroups().find((item: BookGroup) => item.groupName === this.activeFilter());
          this.requestPrivateUnlock(group === undefined ? 0 : group.groupId, '');
        })
    }.width('100%').layoutWeight(1).justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
  }

  /**
   * 密码输入对话框，对齐上游 `BookshelfScreen.kt:1436-1458`：
   * 标题 `private_unlock_password_title`（输入本地密码）、一个密码输入框、按钮「确认」/「取消」。
   * 上游校验失败不写在框内，而是 `ShowSnackbar(private_unlock_password_error)` 并保留对话框
   * （`BookshelfViewModel.kt:872-887`）；本地同样走 toast，但先关框再提示，避免 toast 被对话框遮挡。
   */
  @Builder
  private PasswordDialog() {
    AppAlertDialog({
      title: '输入本地密码',
      confirmText: '确认',
      dismissText: '取消',
      onConfirm: () => { void this.submitPassword(); },
      onDismiss: () => { this.closePasswordDialog(); }
    }) {
      DialogTextInput({
        initialText: this.passwordInput,
        placeholder: '输入本地密码',
        maxLines: 1,
        isPassword: true,
        onValueChange: (value: string) => { this.passwordInput = value; }
      })
    }
  }

  private openPasswordDialog(): void {
    this.passwordInput = '';
    this.passwordError = '';
    if (this.passwordDialogId >= 0) { return; }
    this.passwordDialogBuilder = (): void => { this.PasswordDialog(); };
    this.getUIContext().getPromptAction().openCustomDialog({
      builder: this.passwordDialogBuilder,
      autoCancel: true,
      alignment: DialogAlignment.Center,
      onWillDismiss: () => {
        this.passwordDialogId = -1;
        this.passwordInput = '';
        this.passwordError = '';
      }
    }).then((id: number) => {
      this.passwordDialogId = id;
    }).catch((error: Error) => {
      console.error(`[Bookshelf] 打开密码对话框失败: ${error}`);
    });
  }

  private closePasswordDialog(): void {
    if (this.passwordDialogId >= 0) {
      this.getUIContext().getPromptAction().closeCustomDialog(this.passwordDialogId);
      this.passwordDialogId = -1;
    }
    this.passwordInput = '';
    this.passwordError = '';
  }

  /** 只列自定义分组，按 order 升序，与上游 GroupManageSheet 一致。 */
  private getUserGroups(): BookGroup[] {
    return this.groups.filter((group: BookGroup) => group.groupId > 0)
      .sort((left: BookGroup, right: BookGroup) => left.order - right.order);
  }

  /**
   * 分组管理面板要列的分组。
   *
   * 上游 GroupManageSheet.kt:86 读 `allGroupsFlow`（= flowAll，含 show=0 的内置行），
   * 所以「本地未分组」在管理面板里始终可见、可切显隐，即使它没显示在页签上。
   * 本地对应做法：自定义分组 + 内置的「本地未分组」一行。
   */
  private getManageGroups(): BookGroup[] {
    const manage = this.getUserGroups();
    const builtin = this.groups.find((group: BookGroup) =>
      group.groupId === BookGroupRepository.LOCAL_NONE_GROUP_ID);
    if (builtin !== undefined) { manage.unshift(builtin); }
    return manage;
  }

  /**
   * 分组管理卡片的副标题。
   *
   * 上游 GroupManageSheet.kt:238-243 的 subtitle 是 `group.getManageName(context).suffix`，
   * 即「内置名后缀 / 自定义分组为空」。本地分组模型没有内置名体系（本地未分组靠
   * groupId <= 0 判定），所以：内置组给一句固定说明，自定义组给书数 + 排序 + 私密标记。
   */
  private groupManageSubtitleOf(group: BookGroup): string {
    if (this.isBuiltinGroup(group)) { return '系统内置分组'; }
    const privateSuffix = group.isPrivate ? ' · 私有' : '';
    return `${this.countBooksInGroup(group.groupName)} 本 · ${bookSortLabel(group.bookSort)}${privateSuffix}`;
  }

  /** 内置分组不可编辑/删除，只有显隐开关可用（对齐上游 GroupManageSheet 对内置行的处理）。 */
  private isBuiltinGroup(group: BookGroup): boolean {
    return group.groupId <= 0;
  }

  /** 文件夹根层显示的分组名清单：与页签共用 getGroupNames，保证「全部」与各分组一致。 */
  private getFolderGroups(): string[] {
    return this.getGroupNames();
  }

  /** 某分组卡片上的预览书籍；不套搜索框关键字，与上游 previewBooks 的组内取书一致。 */
  private getFolderPreviewBooks(groupName: string): Book[] {
    return this.books.filter((book: Book) => {
      const names = book.groupNames ?? [];
      return groupName === '全部' ? true
        : (groupName === '本地未分组' ? names.length === 0 : names.includes(groupName));
    });
  }

  /** 点分组卡片进入组内：同时把筛选切到该分组，让书籍网格显示该组的书。 */
  private openFolderGroup(name: string): void {
    this.folderViewGroup = name;
    this.selectedFilter = name;
  }

  /** 返回文件夹根层：清掉组内导航与筛选。 */
  private backToFolderRoot(): void {
    this.folderViewGroup = '';
    this.selectedFilter = '全部';
  }

  /** 分组卡片在网格里的稳定 key；属性变化后必须换 key，否则 ArkUI 会复用旧节点。 */
  private groupCardKey(group: BookGroup): string {
    return `${group.groupId}_${group.groupName}_${group.show ? 1 : 0}_${group.order}_${group.bookSort}_${group.isPrivate ? 1 : 0}_${group.cover ?? ''}`;
  }

  /** 打开分组编辑面板；表单本身由 GroupEditorSheet 自管草稿态。 */
  private openGroupEditor(group: BookGroup | undefined): void {
    this.editingGroup = group;
    // 长按文件夹视图的分组卡也会走到这里，此时分组管理面板还没打开；
    // bindSheet 的开关条件是 showGroupManager，所以要一并置真，否则面板不弹出。
    this.showGroupManager = true;
    this.showGroupEditor = true;
  }

  /**
   * 分组保存：`groupId > 0` 走更新，`-1` 走新建。
   *
   * 第十表 H-4：表单与规则落库搬进 GroupEditorSheet 后，本页只保留落库分派，
   * 以及「当前筛选正好是这个组」时跟着改名，避免筛选器指向已不存在的组名。
   */
  private async saveGroupDraft(groupId: number, draft: BookGroupDraft): Promise<void> {
    if (groupId > 0) {
      const previous = this.groups.find((group: BookGroup) => group.groupId === groupId);
      await this.onUpdateGroup(groupId, draft);
      if (previous !== undefined && this.selectedFilter === previous.groupName
        && this.selectedFilter !== draft.groupName) {
        this.selectedFilter = draft.groupName;
      }
    } else {
      await this.onAddGroupDraft(draft);
    }
  }

  @Builder
  private GroupCoverThumb(group: BookGroup, thumbSize: number) {
    Stack({ alignContent: Alignment.Center }) {
      if ((group.cover ?? '').length > 0) {
        Image(group.cover).width(thumbSize).height(thumbSize).borderRadius(10).objectFit(ImageFit.Cover)
      } else {
        Text(group.groupName.substring(0, 1)).fontSize(thumbSize / 2.4).fontColor('#C4D1FF')
      }
    }
    .width(thumbSize).height(thumbSize).backgroundColor('#22232A').borderRadius(10)
  }

  /** 隐藏页签布局仍可从管理面板选择全部当前可用的分组筛选。 */
  @Builder
  private GroupFilterMenu() {
    UiMenuPanel({
      items: this.groupFilterItems(),
      panelWidth: SHELF_MENU_WIDTH,
      onSelect: (key: string) => {
        this.groupFilterVisible = false;
        this.selectGroupFromMenu(key);
      }
    })
  }

  private groupFilterItems(): UiMenuItem[] {
    return this.getGroupNames().map((groupName: string): UiMenuItem => {
      // 原来靠文案前面的勾表示当前分组，卡片式菜单改用右侧勾，文案保持干净。
      return { key: groupName, title: groupName, selected: groupName === this.activeFilter() };
    });
  }

  private async selectGroupFromMenu(groupName: string): Promise<void> {
    await this.selectGroup(groupName);
    this.showGroupManager = false;
  }

  /** 分组管理顶栏「＋」菜单（上游 GroupManageSheet.kt:150 的四项里，AI 自动分组
   *  对应本表 :239 已判不适用，不做）。
   *
   *  「添加标签匹配规则」在本地不另建独立面板（上游 TagGroupRuleEditSheet.kt）：
   *  规则段就放在分组编辑面板里（:249 / :250），两条路径写的是同一张 tag_group_rules 表，
   *  做一套就够，两套反而要维护两条写入路径。这里直接打开一个已有分组的编辑面板，
   *  让用户在里面录表达式。 */
  @Builder
  private GroupManageMoreMenu() {
    UiMenuPanel({
      items: this.groupManageMenuItems(),
      panelWidth: SHELF_MENU_WIDTH,
      onSelect: (key: string) => {
        this.groupManageMenuVisible = false;
        this.onGroupManageMenuSelect(key);
      }
    })
  }

  private groupManageMenuItems(): UiMenuItem[] {
    // 顺序与文案对齐上游 GroupManageSheet.kt:160-186 的四项（AI 自动分组在 C-14 单独补）。
    return [
      { key: 'new_group', title: '新建分组' },
      { key: 'ai_auto_group', title: 'AI 自动分组' },
      { key: 'add_tag_rule', title: '新建标签分组' },
      { key: 'sync_tag_rule', title: '同步标签分组' }
    ];
  }

  private onGroupManageMenuSelect(key: string): void {
    if (key === 'new_group') {
      this.openGroupEditor(undefined);
      return;
    }
    if (key === 'ai_auto_group') {
      this.openAiAutoGroup();
      return;
    }
    if (key === 'sync_tag_rule') {
      this.onApplyTagGroupRules();
      return;
    }
    // C-15：上游 tag_group_add_rule 打开的是独立的 TagGroupRuleEditSheet，
    // 不是「拿一个已有分组去改」。这里同样开独立面板，新建规则。
    this.openTagRuleEditor(undefined);
  }

  /**
   * C-14：打开 AI 自动分组面板。上游 StartSession 先读书架（LoadingSource），
   * 再进预检页；本地书架数据已在内存，同样先亮一次 LoadingSource 再转 Preflight，
   * 保持与上游一致的阶段序列。
   */
  private openAiAutoGroup(): void {
    this.aiPhase = 'LoadingSource';
    this.aiIncrementalOnly = true;
    this.aiIncludeBookIntro = false;
    this.aiDeepThinking = false;
    this.aiGroupingInstruction = '';
    this.aiGroups = [];
    this.aiIgnoredBooks = [];
    this.aiApplyResult = undefined;
    this.aiErrorText = '';
    this.aiRevisionInstruction = '';
    this.aiNewGroupName = '';
    this.closeAiApplyDialog();
    this.aiBatchText = '';
    this.showAiAutoGroup = true;
    setTimeout(() => {
      if (this.aiPhase === 'LoadingSource') { this.aiPhase = 'Preflight'; }
    }, 60);
  }

  /** 参与分析的公开分组：私密分组不参与（上游：私密分组保持不变）。 */
  private aiPublicGroups(): BookGroup[] {
    return this.getUserGroups().filter((group: BookGroup) => !group.isPrivate);
  }

  /** 增量模式下的候选书数，用于预检页「将分析 N 本书」。 */
  private aiCandidateCount(): number {
    const privateNames: string[] = this.getUserGroups()
      .filter((group: BookGroup) => group.isPrivate)
      .map((group: BookGroup) => group.groupName);
    return this.books.filter((book: Book) => {
      if (book.notShelf === true || book.isPrivate === true) { return false; }
      const names: string[] = book.groupNames === undefined ? [] : book.groupNames;
      if (names.some((name: string) => privateNames.indexOf(name) >= 0)) { return false; }
      if (this.aiIncrementalOnly && names.length > 0) { return false; }
      return true;
    }).length;
  }

  /** 已有公开分组数与已有分组的书籍数（预检页第二行）。 */
  private aiExistingGroupedCount(): number {
    return this.books.filter((book: Book) => {
      const names: string[] = book.groupNames === undefined ? [] : book.groupNames;
      return names.length > 0;
    }).length;
  }

  /** 执行一次分析，进 Reviewing 或 Error。 */
  private runAiAnalyze(): void {
    const options: AutoGroupOptions = {
      incrementalOnly: this.aiIncrementalOnly,
      includeBookIntro: this.aiIncludeBookIntro,
      enableDeepThinking: this.aiDeepThinking,
      groupingInstruction: this.aiGroupingInstruction
    };
    try {
      const plan: AutoGroupPlan = AutoGroupEngine.analyze({
        books: this.books,
        publicGroups: this.aiPublicGroups(),
        options: options
      });
      this.aiGroups = plan.groups;
      this.aiIgnoredBooks = plan.ignoredBooks;
      this.aiErrorText = '';
      this.aiBatchText = '';
      this.aiPhase = 'Reviewing';
    } catch (error) {
      const kind = error instanceof AutoGroupError ? (error as AutoGroupError).kind : 'Unexpected';
      this.aiErrorText = kind === 'EmptyBookshelf'
        ? '书架没有可分析的书籍。'
        : 'AI 自动分组失败。';
      this.aiPhase = 'Error';
    }
  }

  /** 预检页「开始分析」。 */
  private aiStartAnalyze(): void {
    if (this.aiCandidateCount() === 0) {
      this.aiErrorText = this.aiIncrementalOnly
        ? '没有未分组书籍可分析，可关闭增量分组以分析整个书架。'
        : '书架没有可分析的书籍。';
      this.aiPhase = 'Error';
      return;
    }
    this.aiPhase = 'Analyzing';
    setTimeout(() => {
      if (this.aiPhase !== 'Analyzing') { return; }
      this.runAiAnalyze();
    }, 80);
  }

  /** Review 页「重新调整」：把调整要求并进补充要求后重算。 */
  private aiRevise(): void {
    const extra = this.aiRevisionInstruction.trim();
    if (extra.length === 0) {
      this.onUnavailableAction('请输入调整要求');
      return;
    }
    this.aiGroupingInstruction = this.aiGroupingInstruction.length > 0
      ? `${this.aiGroupingInstruction}；${extra}`
      : extra;
    this.aiRevisionInstruction = '';
    this.aiPhase = 'Revising';
    setTimeout(() => {
      if (this.aiPhase !== 'Revising') { return; }
      this.runAiAnalyze();
    }, 80);
  }

  /** Review 页改分组名；复用标志保持不变。 */
  private aiRenameGroup(key: string, name: string): void {
    this.aiGroups = this.aiGroups.map((group: AutoGroupGroupUi): AutoGroupGroupUi => {
      if (group.key !== key) { return group; }
      return {
        key: group.key,
        name: name,
        description: group.description,
        reuseExisting: group.reuseExisting,
        books: group.books
      };
    });
  }

  /** Review 页删分组：组里的书转入未处理，不丢书。 */
  private aiRemoveGroup(key: string): void {
    const target = this.aiGroups.find((group: AutoGroupGroupUi) => group.key === key);
    if (target === undefined) { return; }
    const moved: AutoGroupIgnoredBookUi[] = target.books.map((book: AutoGroupBookUi): AutoGroupIgnoredBookUi => {
      return { bookUrl: book.bookUrl, name: book.name, author: book.author, reason: '已从方案中移除' };
    });
    this.aiIgnoredBooks = this.aiIgnoredBooks.concat(moved);
    this.aiGroups = this.aiGroups.filter((group: AutoGroupGroupUi) => group.key !== key);
  }

  /** Review 页新增一个空分组。 */
  private aiAddGroup(): void {
    const name = this.aiNewGroupName.trim();
    if (name.length === 0) {
      this.onUnavailableAction('分组名称不能为空');
      return;
    }
    if (this.aiGroups.some((group: AutoGroupGroupUi) => group.key === name)) {
      this.onUnavailableAction('分组名称已存在');
      return;
    }
    const reuse = this.aiPublicGroups().some((group: BookGroup) => group.groupName === name);
    this.aiGroups = this.aiGroups.concat([{
      key: name,
      name: name,
      description: '手动新增的分组',
      reuseExisting: reuse,
      books: []
    }]);
    this.aiNewGroupName = '';
  }

  /** Review 页把一本书移到另一组。 */
  private aiMoveBook(bookUrl: string, targetKey: string): void {
    let moved: AutoGroupBookUi | undefined = undefined;
    this.aiGroups = this.aiGroups.map((group: AutoGroupGroupUi): AutoGroupGroupUi => {
      const hit = group.books.find((book: AutoGroupBookUi) => book.bookUrl === bookUrl);
      if (hit === undefined) { return group; }
      moved = hit;
      return {
        key: group.key,
        name: group.name,
        description: group.description,
        reuseExisting: group.reuseExisting,
        books: group.books.filter((book: AutoGroupBookUi) => book.bookUrl !== bookUrl)
      };
    });
    if (moved === undefined) { return; }
    const target = moved as AutoGroupBookUi;
    this.aiGroups = this.aiGroups.map((group: AutoGroupGroupUi): AutoGroupGroupUi => {
      if (group.key !== targetKey) { return group; }
      return {
        key: group.key,
        name: group.name,
        description: group.description,
        reuseExisting: group.reuseExisting,
        books: group.books.concat([target])
      };
    });
  }

  /** Review 页把一本书标成不处理。 */
  private aiIgnoreBook(bookUrl: string): void {
    let moved: AutoGroupBookUi | undefined = undefined;
    this.aiGroups = this.aiGroups.map((group: AutoGroupGroupUi): AutoGroupGroupUi => {
      const hit = group.books.find((book: AutoGroupBookUi) => book.bookUrl === bookUrl);
      if (hit === undefined) { return group; }
      moved = hit;
      return {
        key: group.key,
        name: group.name,
        description: group.description,
        reuseExisting: group.reuseExisting,
        books: group.books.filter((book: AutoGroupBookUi) => book.bookUrl !== bookUrl)
      };
    });
    if (moved === undefined) { return; }
    const target = moved as AutoGroupBookUi;
    this.aiIgnoredBooks = this.aiIgnoredBooks.concat([{
      bookUrl: target.bookUrl,
      name: target.name,
      author: target.author,
      reason: '手动不处理'
    }]);
  }

  /** 方案里已分配的书本数。 */
  private aiAssignedCount(): number {
    return AutoGroupEngine.assignedBookCount(this.aiGroups);
  }

  /** 方案里要新建的分组数。 */
  private aiNewGroupCount(): number {
    return AutoGroupEngine.newGroupCount(this.aiGroups);
  }

  /** 确认执行：新建缺失的分组，再按组批量写书的 groupNames。 */
  private async aiConfirmApply(): Promise<void> {
    this.aiPhase = 'Applying';
    try {
      const existingNames: string[] = this.getUserGroups().map((group: BookGroup) => group.groupName);
      let created = 0;
      let reused = 0;
      for (let index = 0; index < this.aiGroups.length; index++) {
        const group = this.aiGroups[index];
        if (existingNames.indexOf(group.name) >= 0) {
          reused += 1;
          continue;
        }
        const draft: BookGroupDraft = {
          groupName: group.name,
          enableRefresh: true,
          bookSort: -1,
          isPrivate: false
        };
        await this.onAddGroupDraft(draft);
        created += 1;
      }
      const byId: Map<string, Book> = new Map<string, Book>();
      this.books.forEach((book: Book) => { byId.set(book.id, book); });
      let updated = 0;
      for (let index = 0; index < this.aiGroups.length; index++) {
        const group = this.aiGroups[index];
        const keys: string[] = [];
        group.books.forEach((item: AutoGroupBookUi) => {
          const book = byId.get(item.bookUrl);
          if (book !== undefined) { keys.push(this.bookKey(book)); }
        });
        if (keys.length === 0) { continue; }
        if (this.aiIncrementalOnly) {
          // 增量：追加到已有分组，不清空原有归属。
          const merged: string[] = [];
          group.books.forEach((item: AutoGroupBookUi) => {
            item.currentGroupNames.forEach((name: string) => {
              if (merged.indexOf(name) < 0) { merged.push(name); }
            });
          });
          if (merged.indexOf(group.name) < 0) { merged.push(group.name); }
          await this.onSetBooksGroupsByNames(keys, merged);
        } else {
          await this.onSetBooksGroupsByNames(keys, [group.name]);
        }
        updated += keys.length;
      }
      this.aiApplyResult = {
        createdGroupCount: created,
        reusedGroupCount: reused,
        updatedBookCount: updated,
        ignoredBookCount: this.aiIgnoredBooks.length
      };
      this.aiPhase = 'Result';
      this.onUnavailableAction('AI 自动分组已完成');
    } catch (error) {
      this.aiErrorText = 'AI 自动分组失败。';
      this.aiPhase = 'Error';
    }
  }

  /** 结果页「重新分析」回到预检。 */
  private aiRestart(): void {
    this.aiGroups = [];
    this.aiIgnoredBooks = [];
    this.aiApplyResult = undefined;
    this.aiErrorText = '';
    this.aiRevisionInstruction = '';
    this.aiPhase = 'Preflight';
  }

  /** 打开独立标签规则面板；rule 为空表示新建（对应上游 editingTagRule = null）。 */
  private openTagRuleEditor(rule: TagGroupRule | undefined): void {
    if (rule === undefined) {
      this.editingTagRuleId = 0;
      this.tagRuleName = '';
      this.tagRulePattern = '';
    } else {
      this.editingTagRuleId = rule.id;
      this.tagRuleName = rule.groupName;
      this.tagRulePattern = rule.pattern;
    }
    this.tagRuleMenuVisible = false;
    this.showTagRuleEdit = true;
  }

  /** 规则面板「更多菜单」：拷贝规则 / 粘贴规则（上游 TagGroupRuleEditSheet.kt:87-109）。 */
  private tagRuleMenuItems(): UiMenuItem[] {
    return [
      { key: 'copy_rule', title: '拷贝规则' },
      { key: 'paste_rule', title: '粘贴规则' }
    ];
  }

  /** 当前规则草稿拼成实体，形状与上游 GSON.toJson(rule) 一致：{id,pattern,groupName,order}。 */
  private currentTagRule(): TagGroupRule {
    return {
      id: this.editingTagRuleId,
      pattern: this.tagRulePattern.trim(),
      groupName: this.tagRuleName.trim(),
      order: 0
    };
  }

  /** 拷贝当前规则到剪贴板（上游 TagGroupRuleViewModel.copyRule）。 */
  private async copyCurrentTagRule(): Promise<void> {
    try {
      const data = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, JSON.stringify(this.currentTagRule()));
      await pasteboard.getSystemPasteboard().setData(data);
      this.onUnavailableAction('规则已复制');
    } catch (error) {
      this.onUnavailableAction('规则复制失败');
    }
  }

  /** 粘贴规则：分组名与表达式一并回填（上游 pasteRule 后两者都赋值）。 */
  private async pasteCurrentTagRule(result: PasteButtonOnClickResult): Promise<void> {
    if (result !== PasteButtonOnClickResult.SUCCESS) {
      this.onUnavailableAction('未获得剪贴板授权');
      return;
    }
    try {
      const data = await pasteboard.getSystemPasteboard().getData();
      if (data.getRecordCount() === 0) { this.onUnavailableAction('剪贴板没有内容'); return; }
      const parsed = JSON.parse(data.getRecord(0).toPlainText()) as TagGroupRule;
      if (typeof parsed.pattern === 'string') { this.tagRulePattern = parsed.pattern; }
      if (typeof parsed.groupName === 'string') { this.tagRuleName = parsed.groupName; }
    } catch (error) {
      this.onUnavailableAction('格式不对');
    }
  }

  /**
   * 保存规则（上游 TagGroupRuleIntent.SaveRule：isNew ? insert : update，随后 autoApplyRules）。
   * 规则按 groupName 关联分组，所以这里先校验名称，再写表并全量同步。
   */
  private async submitTagRule(): Promise<void> {
    const name = this.tagRuleName.trim();
    const pattern = this.tagRulePattern.trim();
    if (name.length === 0) { this.onUnavailableAction('分组名称不能为空'); return; }
    if (pattern.length === 0) { this.onUnavailableAction('匹配规则不能为空'); return; }
    try {
      new RegExp(pattern);
    } catch (error) {
      this.onUnavailableAction('正则表达式不合法');
      return;
    }
    const context = this.getUIContext().getHostContext();
    if (context === undefined) { return; }
    const rules = await TagGroupRuleRepository.load(context);
    const isNew = this.editingTagRuleId <= 0;
    if (isNew) {
      // 上游 id: Long = System.currentTimeMillis()，order 取当前条数。
      rules.push({ id: Date.now(), pattern: pattern, groupName: name, order: rules.length });
    } else {
      const index = rules.findIndex((rule: TagGroupRule) => rule.id === this.editingTagRuleId);
      if (index >= 0) {
        const existing = rules[index];
        rules[index] = { id: existing.id, pattern: pattern, groupName: name, order: existing.order };
      } else {
        rules.push({ id: this.editingTagRuleId, pattern: pattern, groupName: name, order: rules.length });
      }
    }
    await TagGroupRuleRepository.save(context, rules);
    this.showTagRuleEdit = false;
    await this.onApplyTagGroupRules();
  }

  /**
   * C-14：AI 自动分组面板。整体结构与上游 `ui/main/bookshelf/autoGroup/AiAutoGroupSheet.kt`
   * 一一对应：标题「AI 自动分组」，按 phase 切六种内容（预检 / 进度 / 方案 / 结果 / 错误），
   * Reviewing 时右上角是「确认执行」，Result 时右上角是「关闭」。
   */
  @Builder
  private AiAutoGroupContent() {
    Column() {
      Row() {
        Text('AI 自动分组').fontSize(TITLE_LARGE).fontWeight(FontWeight.Medium)
          .fontColor(this.themeColorTextPrimary).layoutWeight(1)
        if (this.aiPhase === 'Reviewing') {
          Text('确认执行').fontSize(LABEL_LARGE)
            .fontColor(this.aiAssignedCount() > 0 ? '#B9C8FF' : this.themeColorTextTertiary)
            .padding(8)
            .onClick(() => {
              if (this.aiAssignedCount() > 0) { this.openAiApplyDialog(); }
            })
        } else if (this.aiPhase === 'Result') {
          Text('关闭').fontSize(LABEL_LARGE).fontColor('#B9C8FF').padding(8)
            .onClick(() => { this.showAiAutoGroup = false; })
        }
      }.width('100%').padding({ left: 12, right: 12, top: 14, bottom: 10 })

      if (this.aiPhase === 'LoadingSource') {
        this.AiAutoGroupProgress('正在读取书架', false)
      } else if (this.aiPhase === 'Preflight') {
        this.AiAutoGroupPreflight()
      } else if (this.aiPhase === 'Analyzing') {
        this.AiAutoGroupProgress('正在分析书架', true)
      } else if (this.aiPhase === 'Revising') {
        this.AiAutoGroupProgress('正在调整方案', true)
      } else if (this.aiPhase === 'Applying') {
        this.AiAutoGroupProgress('正在应用分组', false)
      } else if (this.aiPhase === 'Reviewing') {
        this.AiAutoGroupReview()
      } else if (this.aiPhase === 'Result') {
        this.AiAutoGroupResult()
      } else {
        this.AiAutoGroupError()
      }
    }.width('100%').height('100%').backgroundColor('#17181E')
  }

  /** 进度页，对应上游 AutoGroupProgressContent（最小高 180，转圈 + 文案 + 可选批次 + 可选取消）。 */
  @Builder
  private AiAutoGroupProgress(text: string, cancellable: boolean) {
    Column() {
      LoadingProgress().width(40).height(40).color(this.themeColorAccent)
      Text(text).fontSize(LABEL_MEDIUM).fontColor(this.themeColorTextPrimary).margin({ top: 16 })
      if (this.aiBatchText.length > 0) {
        Text(this.aiBatchText).fontSize(LABEL_SMALL).fontColor(this.themeColorTextSecondary).margin({ top: 6 })
      }
      if (cancellable) {
        Text('取消').fontSize(LABEL_LARGE).fontColor(this.themeColorTextTertiary)
          .padding({ left: 16, right: 16, top: 8, bottom: 8 }).margin({ top: 16 })
          .borderRadius(12).backgroundColor('#22232A')
          .onClick(() => {
            this.aiPhase = 'Preflight';
            this.onUnavailableAction('已取消');
          })
      }
    }.width('100%').constraintSize({ minHeight: 180 }).justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }

  /** 预检页，对应上游 AutoGroupPreflightContent。 */
  @Builder
  private AiAutoGroupPreflight() {
    Scroll() {
      Column({ space: 12 }) {
        // 概览卡：将分析 N 本 / 说明 / 已有分组摘要。
        Column({ space: 8 }) {
          Text(`将分析 ${this.aiCandidateCount()} 本书`).fontSize(TITLE_MEDIUM)
            .fontWeight(FontWeight.Medium).fontColor(this.themeColorTextPrimary).width('100%')
          Text(this.aiIncrementalOnly
            ? '仅分析尚未加入公开分组的书籍，并保持现有分组归属不变。私密分组中的书籍不会参与。'
            : '会按书籍分类、自定义标签与书名关键词生成分组方案，现有公开分组归属会被替换，私密分组保持不变。方案在确认前不会修改书架。')
            .fontSize(BODY_MEDIUM).fontColor(this.themeColorOnSurfaceVariant).width('100%')
          Text(`已有 ${this.aiPublicGroups().length} 个用户分组，${this.aiExistingGroupedCount()} 本书已有分组。`)
            .fontSize(BODY_SMALL).fontColor(this.themeColorOnSurfaceVariant).width('100%')
        }.width('100%').padding(16).backgroundColor(this.themeColorOnSheetContent).borderRadius(12)
        .alignItems(HorizontalAlign.Start)

        // 三个开关，对应上游 SplicedColumnGroup 里的三个 SwitchSettingItem。
        Column() {
          this.AiAutoGroupSwitch('增量分组', '仅分析尚未加入公开分组的书籍，并保持现有分组归属不变。',
            this.aiIncrementalOnly, (value: boolean) => { this.aiIncrementalOnly = value; })
          Divider().strokeWidth(0.5).color('#2A2B33')
          this.AiAutoGroupSwitch('参考书籍简介', '开启后会把书籍简介作为分组参考。本地引擎按分类与标签判定，该开关仅记录选择。',
            this.aiIncludeBookIntro, (value: boolean) => { this.aiIncludeBookIntro = value; })
          Divider().strokeWidth(0.5).color('#2A2B33')
          this.AiAutoGroupSwitch('启用深度思考', '可提升分类信息不明确时的分组质量，但会显著增加处理时间。',
            this.aiDeepThinking, (value: boolean) => { this.aiDeepThinking = value; })
        }.width('100%').backgroundColor(this.themeColorOnSheetContent).borderRadius(12)

        // 补充要求。
        Column() {
          Text('补充分组要求').fontSize(LABEL_SMALL).fontColor(this.themeColorTextSecondary).width('100%')
          TextArea({
            text: this.aiGroupingInstruction,
            placeholder: '例如：按题材分组；玄幻和仙侠合并；分组数量控制在 8 个以内'
          })
            .width('100%').constraintSize({ minHeight: 72, maxHeight: 120 }).margin({ top: 6 })
            .fontSize(TITLE_SMALL).fontColor(this.themeColorTextPrimary)
            .placeholderColor(this.themeColorTextTertiary)
            .backgroundColor(this.themeColorOnSheetContent).borderRadius(9).padding(10)
            .onChange((value: string) => { this.aiGroupingInstruction = value; })
        }.width('100%').alignItems(HorizontalAlign.Start)

        if (this.aiErrorText.length > 0) {
          Text(this.aiErrorText).fontSize(BODY_SMALL).fontColor('#D99AA5').width('100%')
        }
        if (this.aiIncrementalOnly && this.aiCandidateCount() === 0 && this.aiErrorText.length === 0) {
          Text('没有未分组书籍可分析，可关闭增量分组以分析整个书架。')
            .fontSize(BODY_SMALL).fontColor('#B9C8FF').width('100%')
        }

        Row() {
          Text('取消').fontSize(LABEL_LARGE).fontColor(this.themeColorTextTertiary).padding(10)
            .onClick(() => { this.showAiAutoGroup = false; })
          Blank()
          Text('开始分析').fontSize(LABEL_LARGE)
            .fontColor(this.aiCandidateCount() > 0 ? '#B9C8FF' : this.themeColorTextTertiary).padding(10)
            .onClick(() => { if (this.aiCandidateCount() > 0) { this.aiStartAnalyze(); } })
        }.width('100%').padding({ top: 4, bottom: 16 })

        Blank()
      }.width('100%').padding({ left: 16, right: 16 })
    }.edgeEffect(EdgeEffect.None).layoutWeight(1).scrollBar(BarState.Off)
  }

  /** 预检页的单行开关，样式对齐书架设置面板里的开关行。 */
  @Builder
  private AiAutoGroupSwitch(title: string, description: string, checked: boolean,
    onChange: (value: boolean) => void) {
    Row() {
      Column() {
        Text(title).fontSize(TITLE_SMALL).fontColor(this.themeColorTextSecondary)
        Text(description).fontSize(LABEL_SMALL).fontColor(this.themeColorTextTertiary).margin({ top: 3 })
      }.alignItems(HorizontalAlign.Start).layoutWeight(1)
      UiSwitchControl({
        checked: checked,
        interactive: false,
        onChange: onChange
      })
    }.width('100%').padding({ left: 16, right: 16, top: 10, bottom: 10 })
    .onClick(() => onChange(!checked))
  }

  /** 方案页，对应上游 AutoGroupReviewContent。 */
  @Builder
  private AiAutoGroupReview() {
    Scroll() {
      Column({ space: 12 }) {
        // 四指标摘要卡。
        Row() {
          this.AiAutoGroupMetric('分组', `${this.aiGroups.length}`)
          this.AiAutoGroupMetric('新建', `${this.aiNewGroupCount()}`)
          this.AiAutoGroupMetric('书籍', `${this.aiAssignedCount()}`)
          this.AiAutoGroupMetric('跳过', `${this.aiIgnoredBooks.length}`)
        }.width('100%').padding(16).backgroundColor(this.themeColorOnSheetContent).borderRadius(12)
        .justifyContent(FlexAlign.SpaceBetween)

        // 调整要求 + 重新调整 / 确认执行。
        Column({ space: 8 }) {
          TextArea({ text: this.aiRevisionInstruction, placeholder: '让 AI 调整方案' })
            .width('100%').constraintSize({ minHeight: 56, maxHeight: 96 })
            .fontSize(TITLE_SMALL).fontColor(this.themeColorTextPrimary)
            .placeholderColor(this.themeColorTextTertiary)
            .backgroundColor(this.themeColorSurfaceContainer).borderRadius(9).padding(10)
            .onChange((value: string) => { this.aiRevisionInstruction = value; })
          Row({ space: 8 }) {
            Text('重新调整').fontSize(LABEL_LARGE)
              .fontColor(this.aiRevisionInstruction.trim().length > 0 ? '#B9C8FF' : this.themeColorTextTertiary)
              .padding({ left: 14, right: 14, top: 8, bottom: 8 }).borderRadius(12).backgroundColor('#22232A')
              .onClick(() => { if (this.aiRevisionInstruction.trim().length > 0) { this.aiRevise(); } })
            Text('确认执行').fontSize(LABEL_LARGE)
              .fontColor(this.aiAssignedCount() > 0 ? '#1A1B21' : this.themeColorTextTertiary)
              .padding({ left: 14, right: 14, top: 8, bottom: 8 }).borderRadius(12)
              .backgroundColor(this.aiAssignedCount() > 0 ? '#B9C8FF' : '#22232A')
              .onClick(() => { if (this.aiAssignedCount() > 0) { this.openAiApplyDialog(); } })
          }.width('100%')
        }.width('100%').padding(12).backgroundColor(this.themeColorOnSheetContent).borderRadius(12)
        .alignItems(HorizontalAlign.Start)

        // 新增分组输入行。
        Row({ space: 8 }) {
          TextInput({ text: this.aiNewGroupName, placeholder: '新增分组' })
            .layoutWeight(1).height(44).fontSize(TITLE_SMALL).fontColor(this.themeColorTextPrimary)
            .placeholderColor(this.themeColorTextTertiary)
            .backgroundColor(this.themeColorOnSheetContent).borderRadius(9)
            .onChange((value: string) => { this.aiNewGroupName = value; })
          Row() {
            AppGlyph({ name: 'add', glyphSize: 18, tint: '#1A1B21' })
          }.width(44).height(44).borderRadius(12).backgroundColor('#B9C8FF')
          .justifyContent(FlexAlign.Center).alignItems(VerticalAlign.Center)
          .onClick(() => { this.aiAddGroup(); })
        }.width('100%')

        // 分组卡列表。
        ForEach(this.aiGroups, (group: AutoGroupGroupUi) => {
          Column({ space: 8 }) {
            Row({ space: 8 }) {
              TextInput({ text: group.name })
                .layoutWeight(1).height(44).fontSize(TITLE_SMALL).fontColor(this.themeColorTextPrimary)
                .backgroundColor(this.themeColorSurfaceContainer).borderRadius(9)
                .onChange((value: string) => { this.aiRenameGroup(group.key, value); })
              Text(group.reuseExisting ? '复用分组' : '新建分组')
                .fontSize(LABEL_SMALL).fontColor(this.themeColorOnSurfaceVariant)
              Row() {
                AppGlyph({ name: 'delete', glyphSize: 16, tint: this.themeColorTextTertiary })
              }.width(36).height(36).borderRadius(10).backgroundColor('#22232A')
              .justifyContent(FlexAlign.Center).alignItems(VerticalAlign.Center)
              .onClick(() => { this.aiRemoveGroup(group.key); })
            }.width('100%')
            if (group.description.length > 0) {
              Text(group.description).fontSize(BODY_SMALL).fontColor(this.themeColorOnSurfaceVariant)
                .maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis }).width('100%')
            }
            ForEach(group.books, (book: AutoGroupBookUi) => {
              Row({ space: 8 }) {
                Column() {
                  Text(book.name).fontSize(TITLE_SMALL).fontColor(this.themeColorTextPrimary).maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                  Text(book.author.length > 0
                    ? `${book.author}${book.currentGroupNames.length > 0 ? ' · 原分组：' + book.currentGroupNames.join(', ') : ''}`
                    : (book.currentGroupNames.length > 0 ? `原分组：${book.currentGroupNames.join(', ')}` : ''))
                    .fontSize(BODY_SMALL).fontColor(this.themeColorOnSurfaceVariant).maxLines(1)
                    .margin({ top: 2 })
                  if (book.reason.length > 0) {
                    Text(book.reason).fontSize(BODY_SMALL).fontColor(this.themeColorOnSurfaceVariant)
                      .maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis }).margin({ top: 2 })
                  }
                }.alignItems(HorizontalAlign.Start).layoutWeight(1)
                // 「移动」下拉：列出除本组外的其它组。
                Text('移动').fontSize(LABEL_SMALL).fontColor(this.themeColorAccent).padding(6)
                  .bindMenu(this.aiMoveMenuItems(group.key, book.bookUrl))
                Row() {
                  AppGlyph({ name: 'profileClose', glyphSize: 14, tint: this.themeColorTextTertiary })
                }.width(32).height(32).borderRadius(9).backgroundColor('#22232A')
                .justifyContent(FlexAlign.Center).alignItems(VerticalAlign.Center)
                .onClick(() => { this.aiIgnoreBook(book.bookUrl); })
              }.width('100%').padding(10).backgroundColor(this.themeColorSurfaceContainer).borderRadius(9)
            }, (book: AutoGroupBookUi) => `${group.key}_${book.bookUrl}`)
          }.width('100%').padding(12).backgroundColor(this.themeColorOnSheetContent).borderRadius(12)
          .alignItems(HorizontalAlign.Start)
        }, (group: AutoGroupGroupUi) => group.key)

        // 未处理书单卡。
        if (this.aiIgnoredBooks.length > 0) {
          Column({ space: 6 }) {
            Text(`不处理 ${this.aiIgnoredBooks.length} 本`).fontSize(TITLE_SMALL)
              .fontWeight(FontWeight.Medium).fontColor(this.themeColorTextPrimary).width('100%')
            ForEach(this.aiIgnoredBooks.slice(0, 12), (book: AutoGroupIgnoredBookUi) => {
              Text(book.reason.length > 0 ? `${book.name} · ${book.reason}` : book.name)
                .fontSize(BODY_SMALL).fontColor(this.themeColorOnSurfaceVariant).maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis }).width('100%')
            }, (book: AutoGroupIgnoredBookUi) => `ignored_${book.bookUrl}`)
            if (this.aiIgnoredBooks.length > 12) {
              Text(`还有 ${this.aiIgnoredBooks.length - 12} 本未显示`)
                .fontSize(BODY_SMALL).fontColor(this.themeColorOnSurfaceVariant).width('100%')
            }
          }.width('100%').padding(12).backgroundColor(this.themeColorOnSheetContent).borderRadius(12)
          .alignItems(HorizontalAlign.Start)
        }

        Blank()
      }.width('100%').padding({ left: 16, right: 16, bottom: 24 })
    }.edgeEffect(EdgeEffect.None).layoutWeight(1).scrollBar(BarState.Off)
  }

  /** 摘要卡里的单个指标，对应上游 SummaryMetric。 */
  @Builder
  private AiAutoGroupMetric(label: string, value: string) {
    Column() {
      Text(value).fontSize(TITLE_MEDIUM).fontWeight(FontWeight.Medium).fontColor(this.themeColorTextPrimary)
      Text(label).fontSize(BODY_SMALL).fontColor(this.themeColorOnSurfaceVariant)
    }.alignItems(HorizontalAlign.Center)
  }

  /** 结果页，对应上游 AutoGroupResultContent。 */
  @Builder
  private AiAutoGroupResult() {
    Column({ space: 12 }) {
      Row({ space: 12 }) {
        AppGlyph({ name: 'profileCheck', glyphSize: 18, tint: this.themeColorTextPrimary })
        Text(this.aiApplyResult === undefined ? ''
          : `已创建 ${this.aiApplyResult.createdGroupCount} 个分组，复用 ${this.aiApplyResult.reusedGroupCount} 个分组，更新 ${this.aiApplyResult.updatedBookCount} 本书，跳过 ${this.aiApplyResult.ignoredBookCount} 本书。`)
          .fontSize(BODY_MEDIUM).fontColor(this.themeColorTextPrimary).layoutWeight(1)
      }.width('100%').padding(16).backgroundColor(this.themeColorOnSheetContent).borderRadius(12)
      .alignItems(VerticalAlign.Center)

      Row() {
        Text('重新分析').fontSize(LABEL_LARGE).fontColor(this.themeColorTextTertiary).padding(10)
          .onClick(() => { this.aiRestart(); })
        Blank()
        Text('完成').fontSize(LABEL_LARGE).fontColor('#B9C8FF').padding(10)
          .onClick(() => { this.showAiAutoGroup = false; })
      }.width('100%').padding({ left: 16, right: 16 })
      Blank()
    }.width('100%').padding({ left: 16, right: 16, top: 4 }).layoutWeight(1)
  }

  /** 错误页，对应上游 AutoGroupErrorContent。 */
  @Builder
  private AiAutoGroupError() {
    Column({ space: 12 }) {
      Column({ space: 8 }) {
        Text('自动分组失败').fontSize(TITLE_MEDIUM).fontWeight(FontWeight.Medium)
          .fontColor(this.themeColorTextPrimary).width('100%')
        Text(this.aiErrorText.length > 0 ? this.aiErrorText : '未知错误')
          .fontSize(BODY_MEDIUM).fontColor(this.themeColorOnSurfaceVariant).width('100%')
      }.width('100%').padding(16).backgroundColor(this.themeColorOnSheetContent).borderRadius(12)
      .alignItems(HorizontalAlign.Start)

      Row() {
        Text('关闭').fontSize(LABEL_LARGE).fontColor(this.themeColorTextTertiary).padding(10)
          .onClick(() => { this.showAiAutoGroup = false; })
        Blank()
        Text('重新分析').fontSize(LABEL_LARGE).fontColor('#B9C8FF').padding(10)
          .onClick(() => { this.aiRestart(); })
      }.width('100%').padding({ left: 16, right: 16 })
      Blank()
    }.width('100%').padding({ left: 16, right: 16, top: 4 }).layoutWeight(1)
  }

  /** 「移动」下拉的菜单项：目标组名 + 点击移书（对应上游 RoundDropdownMenuItem「移到 X」）。 */
  private aiMoveMenuItems(currentKey: string, bookUrl: string): MenuElement[] {
    const elements: MenuElement[] = [];
    this.aiGroups.forEach((group: AutoGroupGroupUi) => {
      if (group.key === currentKey) { return; }
      elements.push({
        value: `移到 ${group.name}`,
        action: () => { this.aiMoveBook(bookUrl, group.key); }
      });
    });
    return elements;
  }

  /**
   * 独立标签规则面板，对应上游 `ui/tagGroupRule/TagGroupRuleEditSheet.kt`：
   * 标题按 isNew 取「新建标签分组 / 编辑分组规则」，左侧关闭、右侧「更多菜单」
   * （拷贝规则 / 粘贴规则），内容两个输入框，右下角保存。
   */
  @Builder
  private TagRuleEditContent() {
    Column() {
      Row() {
        Text('关闭').fontSize(LABEL_LARGE).fontColor(this.themeColorTextTertiary).padding(8)
          .onClick(() => this.showTagRuleEdit = false)
        Text(this.editingTagRuleId > 0 ? '编辑分组规则' : '新建标签分组')
          .fontSize(TITLE_LARGE).fontWeight(FontWeight.Medium).fontColor(this.themeColorTextPrimary)
          .layoutWeight(1).textAlign(TextAlign.Center)
        Text('更多菜单').fontSize(LABEL_LARGE).fontColor('#B9C8FF').padding(8)
          .onClick(() => { this.tagRuleMenuVisible = !this.tagRuleMenuVisible; })
          .bindPopup(this.tagRuleMenuVisible, {
            builder: this.TagRuleMoreMenu,
            placement: Placement.Bottom,
            popupColor: '#00000000',
            enableArrow: false,
            autoCancel: true,
            width: SHELF_MENU_WIDTH,
            onStateChange: (event: PopupStateChangeParam) => { this.tagRuleMenuVisible = event.isVisible; }
          })
      }.width('100%').padding({ left: 12, right: 12, top: 14, bottom: 10 })

      Scroll() {
        Column() {
          Text('分组名称').fontSize(LABEL_SMALL).fontColor(this.themeColorTextSecondary).width('100%')
          TextInput({ text: this.tagRuleName, placeholder: '分组名称' }).width('100%').height(44).margin({ top: 6 })
            .fontSize(TITLE_SMALL).fontColor(this.themeColorTextPrimary).placeholderColor(this.themeColorTextTertiary)
            .backgroundColor('#22232A').borderRadius(9)
            .onChange((value: string) => this.tagRuleName = value)

          Text('匹配规则（匹配书籍标签）').fontSize(LABEL_SMALL).fontColor(this.themeColorTextSecondary)
            .width('100%').margin({ top: 16 })
          TextArea({ text: this.tagRulePattern, placeholder: '匹配书籍标签的正则表达式' })
            .width('100%').constraintSize({ minHeight: 96 }).margin({ top: 6 })
            .fontSize(TITLE_SMALL).fontColor(this.themeColorTextPrimary).placeholderColor(this.themeColorTextTertiary)
            .backgroundColor('#22232A').borderRadius(9).padding(10)
            .onChange((value: string) => this.tagRulePattern = value)

          if (this.showRulePasteAuthorization) {
            // PasteButton 自身没有 margin 修饰符，间距由外层容器给。
            Column() {
              PasteButton({ text: PasteDescription.PASTE, buttonType: ButtonType.Capsule })
                .onClick(async (_event: ClickEvent, result: PasteButtonOnClickResult) => {
                  await this.pasteCurrentTagRule(result);
                  this.showRulePasteAuthorization = false;
                })
            }.width('100%').alignItems(HorizontalAlign.Start).margin({ top: 8 })
          }
          Blank()
        }.width('100%').alignItems(HorizontalAlign.Start).padding({ left: 16, right: 16, bottom: 120 })
      }.edgeEffect(EdgeEffect.None).layoutWeight(1).scrollBar(BarState.Off)
    }.width('100%').height('100%').backgroundColor('#17181E')
      .overlay(this.TagRuleSaveButton(), { align: Alignment.BottomEnd })
  }

  /** 规则面板右下角保存键，对应上游 AppFloatingActionButton(icon = Save, align = BottomEnd)。 */
  @Builder
  private TagRuleSaveButton() {
    Row() {
      AppGlyph({ name: 'profileSave', glyphSize: 20, tint: '#1A1B21' })
    }
    .width(52).height(52).borderRadius(16).backgroundColor('#B9C8FF')
    .justifyContent(FlexAlign.Center).alignItems(VerticalAlign.Center)
    .margin({ right: 16, bottom: 24 })
    .onClick(async () => { await this.submitTagRule(); })
    .accessibilityText('保存规则')
  }

  @Builder
  private TagRuleMoreMenu() {
    UiMenuPanel({
      items: this.tagRuleMenuItems(),
      panelWidth: SHELF_MENU_WIDTH,
      onSelect: (key: string) => {
        this.tagRuleMenuVisible = false;
        if (key === 'copy_rule') { this.copyCurrentTagRule(); return; }
        this.showRulePasteAuthorization = true;
      }
    })
  }

  /** 分组管理：自适应网格卡片，对应上游 LazyVerticalGrid(GridCells.Adaptive(160.dp))。 */
  @Builder
  private GroupManagerGrid() {
    Column() {
      Row() {
        Text('分组管理').fontSize(TITLE_LARGE).fontWeight(FontWeight.Medium).fontColor(this.themeColorTextPrimary).layoutWeight(1)
        Text('新建').fontSize(LABEL_LARGE).fontColor('#B9C8FF').padding(8)
          .onClick(() => { this.groupManageMenuVisible = !this.groupManageMenuVisible; })
          .bindPopup(this.groupManageMenuVisible, {
            builder: this.GroupManageMoreMenu,
            placement: Placement.Bottom,
            popupColor: '#00000000',
            enableArrow: false,
            autoCancel: true,
            width: SHELF_MENU_WIDTH,
            onStateChange: (event: PopupStateChangeParam) => { this.groupManageMenuVisible = event.isVisible; }
          })
        Text('完成').fontSize(LABEL_LARGE).fontColor('#B9C8FF').padding(8).onClick(() => this.showGroupManager = false)
      }.width('100%').padding({ left: 18, right: 12, top: 14, bottom: 10 })
      Row() {
        Text(`切换分组：${this.activeFilter()}`).fontSize(LABEL_MEDIUM).fontColor(this.themeColorAccent).layoutWeight(1)
          .onClick(() => { this.groupFilterVisible = !this.groupFilterVisible; })
          .bindPopup(this.groupFilterVisible, {
            builder: this.GroupFilterMenu,
            placement: Placement.Bottom,
            popupColor: '#00000000',
            enableArrow: false,
            autoCancel: true,
            width: SHELF_MENU_WIDTH,
            onStateChange: (event: PopupStateChangeParam) => { this.groupFilterVisible = event.isVisible; }
          })
      }.width('100%').padding({ left: 18, right: 18, bottom: 10 })

      if (this.getManageGroups().length === 0) {
        Column() {
          Text('还没有自定义分组').fontSize(TITLE_SMALL).fontColor(this.themeColorTextTertiary)
          Text('点右上「新建」创建第一个分组').fontSize(BODY_SMALL).fontColor('#6E7078').margin({ top: 6 })
        }.width('100%').padding({ top: 40, bottom: 40 }).justifyContent(FlexAlign.Center)
      } else {
        // 长按卡片进入拖拽排序，对应上游 rememberReorderableLazyGridState；
        // editMode(true) 是 Grid 内 ForEach.onMove 生效的前提。
        Grid() {
          ForEach(this.getManageGroups(), (group: BookGroup) => {
            GridItem() {
              Column() {
                Row() {
                  this.GroupCoverThumb(group, 40)
                  Blank()
                  UiSwitchControl({
                    checked: group.show,
                    onChange: (visible: boolean) => {
                      this.onSetGroupVisible(group.groupId, visible);
                      if (!visible && this.selectedFilter === group.groupName) { this.selectedFilter = '全部'; }
                    }
                  })
                }.width('100%')
                // B-6/B-7：上游 GroupManageSheet.kt:348-357 —— 标题 titleSmall、最多 2 行，
                // 紧跟一个 12vp 的编辑图标（点击进编辑由整卡 onClick 承担）。
                Row() {
                  Text(group.groupName).fontSize(TITLE_SMALL).fontColor(this.themeColorTextPrimary).maxLines(2)
                    .textOverflow({ overflow: TextOverflow.Ellipsis }).layoutWeight(1)
                  AppGlyph({ name: 'edit', glyphSize: 12, tint: this.themeColorTextTertiary }).margin({ left: 2 })
                }.width('100%').margin({ top: 10 }).alignItems(VerticalAlign.Center)
                // B-8：上游 :360-366 —— 副标题 bodySmall + onSurfaceVariant + 单行省略。
                if (this.groupManageSubtitleOf(group).length > 0) {
                  Text(this.groupManageSubtitleOf(group))
                    .fontSize(BODY_SMALL).fontColor(this.themeColorOnSurfaceVariant).maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                    .margin({ top: 4 }).width('100%')
                }
              }.width('100%').padding(12)
                // B-5：上游 :311 GlassCard(cornerRadius = 12.dp, containerColor = onSheetContent)。
                .backgroundColor(this.themeColorOnSheetContent).borderRadius(this.groupCardRadius())
                // B-4：上游 :306-308 拖动中 elevation 8.dp + :307 zIndex 1f。
                .shadow(this.draggingGroupId === group.groupId
                  ? { radius: 8, color: '#66000000', offsetX: 0, offsetY: 3 }
                  : { radius: 0, color: Color.Transparent, offsetX: 0, offsetY: 0 })
                .zIndex(this.draggingGroupId === group.groupId ? 1 : 0)
                .alignItems(HorizontalAlign.Start)
                // 内置分组没有可编辑字段（上游对内置行也不给编辑入口），点了不打开编辑面板。
                .onClick(() => {
                  if (this.isBuiltinGroup(group)) { return; }
                  this.openGroupEditor(group);
                })
            }
          }, (group: BookGroup) => this.groupCardKey(group))
            .onMove((from: number, to: number) => {
              // 网格里第一格是内置的「本地未分组」，不参与排序；
              // 所以按同一份列表取，涉及内置行的拖动直接忽略。
              const managed = this.getManageGroups();
              if (from < 0 || to < 0 || from >= managed.length || to >= managed.length) { return; }
              if (this.isBuiltinGroup(managed[from]) || this.isBuiltinGroup(managed[to])) { return; }
              this.onMoveGroup(managed[from].groupId, managed[to].groupId);
            }, {
              // B-4：上游 GroupManageSheet.kt:322-327 在 longPressDraggableHandle 的
              // onDragStarted / onDragStopped 里发 GestureThresholdActivate / GestureEnd 两档震动。
              onDragStart: (index: number): void => {
                const managed = this.getManageGroups();
                this.draggingGroupId = (index >= 0 && index < managed.length) ? managed[index].groupId : -1;
                UiHaptics.dragThresholdActivate();
              },
              onDrop: (_index: number): void => {
                this.draggingGroupId = -1;
                UiHaptics.dragEnd();
              }
            })
        }.edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
        // B-2：上游 GroupManageSheet.kt:227-228 horizontalArrangement/verticalArrangement = spacedBy(8.dp)。
        .columnsTemplate('1fr 1fr').columnsGap(8).rowsGap(8)
        .width('100%').layoutWeight(1).padding({ left: 16, right: 16, bottom: 18 })
        .scrollBar(BarState.Off).editMode(true)
      }
    }.width('100%').height('100%').backgroundColor('#17181E')
  }

  /** 分组面板：管理网格与编辑表单共用一个 sheet，避免同一组件挂两个 bindSheet 只有后者生效。 */
  @Builder
  private GroupManagerSheet() {
    if (this.showAiAutoGroup) {
      this.AiAutoGroupContent()
    } else if (this.showTagRuleEdit) {
      this.TagRuleEditContent()
    } else if (this.showGroupEditor) {
      // 编辑表单是公共组件，书架管理页用同一份实现（上游 BookInfoSheets.kt:108-190）。
      GroupEditorSheet({
        editingGroup: this.editingGroup,
        books: this.books,
        onSave: (groupId: number, draft: BookGroupDraft) => this.saveGroupDraft(groupId, draft),
        onChooseCover: (groupId: number) => this.onChooseGroupCover(groupId),
        onChooseCoverDraft: () => this.onChooseGroupCoverDraft(),
        onClearCover: (groupId: number) => this.onClearGroupCover(groupId),
        onRemove: (groupId: number) => {
          this.onRemoveGroup(groupId);
          if (this.editingGroup !== undefined && this.selectedFilter === this.editingGroup.groupName) {
            this.selectedFilter = '全部';
          }
          this.showGroupEditor = false;
        },
        onCancel: () => this.showGroupEditor = false,
        onMessage: (message: string) => this.onUnavailableAction(message),
        onApplyTagGroupRules: () => this.onApplyTagGroupRules()
      }).width('100%').height('100%')
    } else {
      this.GroupManagerGrid()
    }
  }

  /** 当前方向下生效的布局模式（1 网格 / 0 列表）：竖屏取 Portrait，横屏取 Landscape。 */
  private activeLayoutMode(): number {
    return this.isLandscape
      ? this.layout.bookshelfLayoutModeLandscape : this.layout.bookshelfLayoutModePortrait;
  }

  /** 当前方向下生效的网格列数。 */
  private activeGridColumns(): number {
    return this.isLandscape
      ? this.layout.bookshelfLayoutGridLandscape : this.layout.bookshelfLayoutGridPortrait;
  }

  /** 当前方向下生效的列表列数。 */
  private activeListColumns(): number {
    return this.isLandscape
      ? this.layout.bookshelfLayoutListLandscape : this.layout.bookshelfLayoutListPortrait;
  }

  /** 列表详情区是否渲染：对齐上游 BookItem.kt:738 的 showListDetails（列表模式 + 非精简 + 总开关）。 */
  private showsListDetails(): boolean {
    return this.activeLayoutMode() === 0 && !this.layout.bookshelfLayoutCompact && this.layout.showBookIntro;
  }

  /** 简介最大行数：上游 0 表示不限（BookItem.kt:1058 用 Int.MAX_VALUE 兜底）。 */
  private introMaxLines(): number {
    return this.layout.bookshelfIntroMaxLines > 0 ? this.layout.bookshelfIntroMaxLines : 999;
  }

  /** 简介行数的描述文案：0 时显示全部，否则显示「最多 N 行」。 */
  private introMaxLinesDescription(): string {
    const lines = this.layoutDraft.bookshelfIntroMaxLines;
    return lines === 0 ? '显示全部' : `最多 ${lines} 行`;
  }

  /** 面板草稿里当前方向生效的布局模式：面板未提交前只读草稿，不读已保存值。 */
  private activeDraftLayoutMode(): number {
    return this.isLandscape
      ? this.layoutDraft.bookshelfLayoutModeLandscape : this.layoutDraft.bookshelfLayoutModePortrait;
  }

  /** 面板草稿里当前方向生效的网格列数。 */
  private activeDraftGridColumns(): number {
    return this.isLandscape
      ? this.layoutDraft.bookshelfLayoutGridLandscape : this.layoutDraft.bookshelfLayoutGridPortrait;
  }

  /** 面板草稿里当前方向生效的列表列数。 */
  private activeDraftListColumns(): number {
    return this.isLandscape
      ? this.layoutDraft.bookshelfLayoutListLandscape : this.layoutDraft.bookshelfLayoutListPortrait;
  }

  /** 文件夹视图：当前方向下生效的布局模式（1 网格 / 0 列表）。 */
  private activeFolderLayoutMode(): number {
    return this.isLandscape
      ? this.layout.bookshelfFolderLayoutModeLandscape : this.layout.bookshelfFolderLayoutModePortrait;
  }

  /** 文件夹视图：当前方向下生效的网格列数。 */
  private activeFolderGridColumns(): number {
    return this.isLandscape
      ? this.layout.bookshelfFolderLayoutGridLandscape : this.layout.bookshelfFolderLayoutGridPortrait;
  }

  /** 文件夹视图：当前方向下生效的列表列数。 */
  private activeFolderListColumns(): number {
    return this.isLandscape
      ? this.layout.bookshelfFolderLayoutListLandscape : this.layout.bookshelfFolderLayoutListPortrait;
  }

  /**
   * 文件夹根视图的列数模板：对齐上游 BookshelfScreen.kt:985
   * folderColumns = if (bookshelfFolderLayoutMode == 0) bookshelfFolderLayoutList else bookshelfFolderLayoutGrid，
   * 再按 :988 的 coerceAtLeast(1) 兜底。横竖屏各取一套值。
   */
  private folderColumnsTemplate(): string {
    const mode = this.activeFolderLayoutMode();
    const configured = mode === 1 ? this.activeFolderGridColumns() : this.activeFolderListColumns();
    // 上限只留 1，对齐上游 BookshelfScreen.kt:988 的 folderColumns.coerceAtLeast(1)。
    const columns = Math.max(1, Math.round(configured));
    const template: string[] = [];
    for (let index = 0; index < columns; index += 1) { template.push('1fr'); }
    return template.join(' ');
  }

  /** 按当前方向与 Android 书架设置选择列表或网格的列数。 */
  private bookshelfColumnsTemplate(): string {
    // 批10：与 coverCacheCount 共用同一套列数判据，两处各算一遍必然对不上。
    const columns = this.bookshelfColumnCount();
    const template: string[] = [];
    for (let index = 0; index < columns; index += 1) { template.push('1fr'); }
    return template.join(' ');
  }

  /** 当前生效的列数，供封面宽度换算用。 */
  private bookshelfColumnCount(): number {
    const mode = this.activeLayoutMode();
    const configuredColumns = mode === 1 ? this.activeGridColumns() : this.activeListColumns();
    return Math.max(1, Math.round(configuredColumns));
  }

  /**
   * C-2：网格行/列间距。
   *
   * 对齐上游 `BookshelfScreen.kt:1002-1003`/`:1772-1773` 的
   * `spacedBy(if (isGridMode) 8.dp else 0.dp)`——**只有网格模式是 8dp，列表模式为 0**。
   * 原先两处都无条件写死 8，会让列表行距比上游多 8vp。
   */
  private gridGap(): number {
    return this.activeLayoutMode() === 1 ? BOOKSHELF_GRID_GAP : 0;
  }

  /**
   * C-7：LazyForEach 预加载条数，对齐上游 `BookshelfCoverPreloader.kt` 的首屏预取口径。
   *
   * 上游（BookshelfCoverPreloader.kt:30/:33/:36）：网格 `MAX_PRELOAD_BOOKS = 24`、列表 `LIST_PRELOAD_BOOKS = 10`、
   * 估算可见行 `ESTIMATED_VISIBLE_ROWS = 5`，`limit = (columns.coerceAtLeast(1) * 5).coerceIn(1, 24)`（:261），
   * 列表分支直接取 10。本地走 LazyForEach 自身的虚拟化，不需要命令式解码，
   * 但**条数上限要与上游同一口径**，否则视口外的封面进队列的时机比上游晚。
   */
  private coverCacheCount(): number {
    if (this.activeLayoutMode() !== 1) { return 10; }
    return Math.min(24, Math.max(1, this.bookshelfColumnCount() * 5));
  }

  /**
   * 列表底部内缩：`useFloatingBottomBar || enableBlur` 时 120vp，否则 8vp。
   *
   * 对齐上游 `BookshelfViewModel.kt:718/737` 的
   * `useRaisedBottomInset = appShellSettings.useFloatingBottomBar || themeSettings.enableBlur`，
   * 消费点 `BookshelfScreen.kt:999`（网格）与 `:1769`（列表）都是
   * `bottom = if (uiState.useRaisedBottomInset) 120.dp else 8.dp`。
   * 这两个开关不在本组件的参数里，走 AppStorage 广播（见 `pages/Index.ets` 的 `publishTopBottomBarStyle()`）。
   */
  private raisedBottomInset(): number {
    return this.themeUseFloatingBottomBar || this.themeEnableBlur ? 120 : 8;
  }

  /**
   * 网格里单个格子能给出的封面宽度（vp）。
   *
   * 对齐上游 BookItem.kt:269-273：封面宽度由格子宽度决定，高度按 5:7 推导。
   * 格子宽度 = (网格可用宽 - 左右内边距 8*2 - 列间距 8*(列数-1)) / 列数，
   * 再减 8 给上游 BookshelfItemCover 的 padding(4.dp) 留位置。
   * 宽度未知时返回 0，调用方回落到 100% 让布局自己算。
   */
  private bookshelfCoverSlotWidth(): number {
    if (this.bookshelfGridWidth <= 0) { return 0; }
    const columns = this.bookshelfColumnCount();
    // C-3：可用宽按实际左右内边距（8+4=12）扣，与网格 padding 保持同一口径。
    const available = this.bookshelfGridWidth - this.gridHorizontalPadding() * 2
      - this.gridGap() * (columns - 1);
    if (available <= 0) { return 0; }
    return Math.max(0, Math.floor(available / columns) - 8);
  }

  /**
   * C-3：网格左右内边距。
   *
   * 对齐上游 `AdaptivePadding.kt:114-121`——M3 引擎下为 `4.dp + 传入的 8.dp = 12dp`。
   */
  private gridHorizontalPadding(): number {
    return BOOKSHELF_GRID_PADDING + BOOKSHELF_GRID_PADDING_EXTRA;
  }

  /**
   * 网格封面列的宽度（vp）：直接取设置值 `bookshelfGridCoverWidth`。
   *
   * 上游 `BookItem.kt:839` 把 `settings.bookshelfGridCoverWidth` 原样传给
   * `BookshelfGridItem(coverWidth = ...)`，`:107` 就是 `Column(Modifier.width(coverWidth.dp))`，
   * **没有**「和格子宽取小」这一步——格子比封面窄时上游允许溢出。
   * 改前这里用 `Math.min(格子宽, 设置值)` 钳了一道，属于上游没有的约束。
   *
   * 设置值缺失（0）时退回格子宽，格子宽也未知时给 84（上游 `coverWidth` 形参默认值）。
   */
  private gridCoverColumnWidth(): number {
    const configured = Math.max(0, Math.round(this.layout.bookshelfGridCoverWidth));
    if (configured > 0) { return configured; }
    const slot = this.bookshelfCoverSlotWidth();
    return slot > 0 ? slot : 84;
  }

  /** 书封标题字号：上游 labelMedium 13sp、labelSmall 11sp。 */
  private bookshelfTitleFontSize(): number {
    return this.layout.bookshelfTitleSmallFont ? 11 : 13;
  }

  /** 卡片底色：日夜各一套；0 表示用户没自定义，回落 `cardContainer`。
   *  上游 `BookItem.kt:186` / `:583` 是 `if (cardColor != 0) Color(cardColor) else colorScheme.cardContainer`，
   *  不是透明 —— 透明会让卡片和页面底色糊成一片，看不出格子边界。
   */
  private cardBackgroundColor(): ResourceColor {
    const color = this.readerNightMode
      ? this.layout.bookshelfCardColorDark : this.layout.bookshelfCardColor;
    return color === 0 ? this.themeColorCardContainer : bookshelfCardIntToHex(color);
  }

  /**
   * 卡片底色：选择态且该书已选时铺 `secondaryContainer`，否则走自定义/主题底色。
   *
   * 上游网格 `BookItem.kt:99` 是
   * `.then(if (isSelected) Modifier.background(secondaryContainer) else Modifier)`；
   * 列表 `:186` 是 `containerColor = if (isSelected) secondaryContainer else if (cardColor != 0) Color(cardColor) else cardContainer`。
   * 两个分支选中态取同一档色，所以这里合并成一个判断。
   */
  private cardContainerColorOf(book: Book): ResourceColor {
    if (this.selectionMode && this.isBookSelected(book)) { return this.themeColorSecondaryContainer; }
    return this.cardBackgroundColor();
  }

  /**
   * 卡片圆角：网格固定 4vp、列表 8vp。
   *
   * 上游网格是 `BookItem.kt:98` 的 `.clip(RoundedCornerShape(4.dp))`——硬编码，不受
   * 「覆盖卡片圆角」主题项影响；列表是 `:184` 的 `NormalCard(cornerRadius = 8.dp)`，
   * 会被 `GlassCard.kt:78-82` 的全局覆盖替换，所以只有列表走 `bookCardRadius()`。
   */
  private cardCornerOf(): number {
    return this.activeLayoutMode() === 0 ? this.bookCardRadius() : 4;
  }

  /**
   * 书架卡片圆角。上游 `BookItem.kt:184` 写 `NormalCard(cornerRadius = 8.dp)`，
   * `GlassCard.kt:78-82` 在「覆盖卡片圆角」打开时把它换成全局 `baseCardCornerRadius`。
   */
  private bookCardRadius(): number {
    return cardRadiusOf(this.themeCardOverride, this.themeCardRadius, 8);
  }

  /** 分组卡片圆角。上游 `GroupManageSheet.kt:310` 写 `GlassCard(cornerRadius = 12.dp)`。 */
  private groupCardRadius(): number {
    return cardRadiusOf(this.themeCardOverride, this.themeCardRadius, 12);
  }

  /** 紧凑样式下封面内标题的渐变黑底，对齐上游 BookItem.kt:123-131 的垂直渐变。 */
  private coverTitleGradient(): LinearGradientOptions {
    return { angle: 180, colors: [['#00000000', 0.0], ['#B3000000', 1.0]] };
  }

  /** 打开布局面板：从已生效设置复制一份草稿，面板内改动只落到草稿。
   *  卡片色输入框的初始值：用户没设过（0）时回落 `surfaceVariant`，
   *  对齐上游 `BookshelfConfigSheet.kt:677` 的
   *  `if (settings.bookshelfCardColor != 0) settings.bookshelfCardColor else colorScheme.surfaceVariant.toArgb()`。
   */
  private openLayoutSheet(): void {
    this.layoutDraft = copyBookshelfLayout(this.layout);
    this.dayCardColorHex = this.layoutDraft.bookshelfCardColor === 0
      ? this.themeColorSurfaceVariant : bookshelfCardIntToHex(this.layoutDraft.bookshelfCardColor);
    this.nightCardColorHex = this.layoutDraft.bookshelfCardColorDark === 0
      ? this.themeColorSurfaceVariant : bookshelfCardIntToHex(this.layoutDraft.bookshelfCardColorDark);
    this.showLayoutSheet = true;
  }

  /** 提交布局草稿并关闭面板。 */
  private updateLayoutDraft(update: (draft: BookshelfLayoutSettings) => void): void {
    const draft = copyBookshelfLayout(this.layoutDraft);
    update(draft);
    this.layoutDraft = draft;
  }

  private async submitLayout(): Promise<void> {
    this.showLayoutSheet = false;
    await this.onSaveLayout(copyBookshelfLayout(this.layoutDraft));
    // 布局提交后刷新标签配色缓存，卡片不用等 @Watch 回来再变色。
    this.refreshCachedTagColors();
    // 隐藏空分组或隐藏当前分组后，选中页签可能已不存在，回落到「全部」。
    if (!this.getGroupNames().includes(this.selectedFilter)) { this.selectedFilter = '全部'; }
  }

  /** 通用下拉：一个按钮 + 菜单，用于布局面板里的枚举项。 */
  @Builder
  private LayoutMenuRow(
    title: string, description: string, options: BookshelfLayoutOption[],
    current: number, onPick: (value: number) => void
  ) {
    Row() {
      Column() {
        Text(title).fontSize(TITLE_SMALL).fontColor(this.themeColorTextSecondary)
        if (description.length > 0) {
          Text(description).fontSize(LABEL_SMALL).fontColor(this.themeColorTextTertiary).margin({ top: 3 })
        }
      }.alignItems(HorizontalAlign.Start).layoutWeight(1)
      Text(bookshelfLayoutOptionLabel(options, current)).fontSize(TITLE_SMALL).fontColor(this.themeColorAccent)
        .onClick(() => { this.layoutMenuVisible = !this.layoutMenuVisible; })
        .bindPopup(this.layoutMenuVisible, {
          builder: () => { this.LayoutOptionsMenu(options, current, onPick) },
          placement: Placement.Bottom,
          popupColor: '#00000000',
          enableArrow: false,
          autoCancel: true,
          width: SHELF_MENU_WIDTH,
          onStateChange: (event: PopupStateChangeParam) => { this.layoutMenuVisible = event.isVisible; }
        })
    }.width('100%').padding({ left: 16, right: 16, top: 12, bottom: 12 })
  }

  /** 枚举项菜单；ArkTS 不允许 bindMenu 传对象字面量数组，统一用 Builder 生成。 */
  @Builder
  private LayoutOptionsMenu(options: BookshelfLayoutOption[], current: number, onPick: (value: number) => void) {
    UiMenuPanel({
      items: this.layoutOptionItems(options, current),
      panelWidth: SHELF_MENU_WIDTH,
      onSelect: (key: string) => {
        this.layoutMenuVisible = false;
        onPick(Number(key));
      }
    })
  }

  private layoutOptionItems(options: BookshelfLayoutOption[], current: number): UiMenuItem[] {
    return options.map((option: BookshelfLayoutOption): UiMenuItem => {
      return { key: `${option.value}`, title: option.label, selected: option.value === current };
    });
  }

  /** 开关行。 */
  @Builder
  private LayoutSwitchRow(title: string, description: string, isOn: boolean, onToggle: (value: boolean) => void) {
    Row() {
      Column() {
        Text(title).fontSize(TITLE_SMALL).fontColor(this.themeColorTextSecondary)
        if (description.length > 0) {
          Text(description).fontSize(LABEL_SMALL).fontColor(this.themeColorTextTertiary).margin({ top: 3 })
        }
      }.alignItems(HorizontalAlign.Start).layoutWeight(1)
      UiSwitchControl({
        checked: isOn,
        interactive: false,
        onChange: (value: boolean) => onToggle(value)
      })
    }
    .width('100%').padding({ left: 16, right: 16, top: 10, bottom: 10 })
    .onClick(() => onToggle(!isOn))
  }

  /**
   * 数值行，对齐上游 `CompactSliderSettingItem`（CompactSettingItems.kt:124-230）：
   * 行内是 `ValueStepper`（±1 步进 + 数值），点标题展开后是 `Slider`（按 valueRange 分档）。
   *
   * 上游 `ValueStepper`（ValueStepper.kt:19-73）的 `stepSize` 默认 1f，`coerceIn(valueRange)` 夹取；
   * 展开的 `Slider` 步长由 `steps` 推出——七处调用都是「档位数 = 区间长度 + 1」，等价于步长 1。
   * 展开状态由 `layoutSliderExpandedKey` 记录，同一时刻只开一个（上游每行各自 remember，互不影响，
   * 这里收成一个键，视觉上更接近设置面板的单开手风琴）。
   */
  @Builder
  private LayoutSliderRow(
    title: string, description: string, value: number,
    minimum: number, maximum: number, onChange: (value: number) => void
  ) {
    Column() {
      Row() {
        Column() {
          Text(title).fontSize(TITLE_SMALL).fontColor(this.themeColorTextSecondary)
          if (description.length > 0) {
            Text(description).fontSize(LABEL_SMALL).fontColor(this.themeColorTextTertiary).margin({ top: 3 })
          }
        }.alignItems(HorizontalAlign.Start).layoutWeight(1)
          .onClick(() => {
            this.layoutSliderExpandedKey = this.layoutSliderExpandedKey === title ? '' : title;
          })
        Text('−').fontSize(TITLE_LARGE).fontColor(value > minimum ? this.themeColorAccent : '#4A4C55')
          .width(36).height(32).textAlign(TextAlign.Center)
          .accessibilityText('减小')
          .onClick(() => { onChange(Math.max(minimum, Math.min(maximum, value - 1))); })
        Text(`${value}`).fontSize(TITLE_SMALL).fontColor(this.themeColorTextPrimary).width(34).textAlign(TextAlign.Center)
        Text('+').fontSize(TITLE_LARGE).fontColor(value < maximum ? this.themeColorAccent : '#4A4C55')
          .width(36).height(32).textAlign(TextAlign.Center)
          .accessibilityText('增大')
          .onClick(() => { onChange(Math.max(minimum, Math.min(maximum, value + 1))); })
      }.width('100%')
      if (this.layoutSliderExpandedKey === title) {
        Slider({ value: value, min: minimum, max: maximum, step: 1, style: SliderStyle.OutSet })
          .width('100%')
          .selectedColor(this.themeColorAccent)
          .trackColor(this.themeColorSurfaceTertiary)
          .showSteps(true)
          .accessibilityText(title)
          .onChange((current: number, mode: SliderChangeMode) => {
            if (mode === SliderChangeMode.Moving || mode === SliderChangeMode.Click || mode === SliderChangeMode.End) {
              onChange(Math.max(minimum, Math.min(maximum, Math.round(current))));
            }
          })
      }
    }.width('100%').padding({ left: 16, right: 12, top: 10, bottom: 10 })
  }

  /**
   * 标签显示内容对话框，对齐上游 `BookshelfTagContentDialog`（BookshelfConfigSheet.kt:695-742）：
   * AppAlertDialog + 三个 CheckboxItem（用户标签 / 书源分类 / 字数）+ 确认 / 取消。
   */
  @Builder
  private TagContentDialog() {
    Column() {
      Text('标签显示内容').fontSize(TITLE_LARGE).fontWeight(FontWeight.Medium)
        .fontColor(this.themeColorTextPrimary).width('100%')
      Column() {
        this.TagContentCheckRow('用户标签', this.tagDialogCustom,
          (checked: boolean) => { this.tagDialogCustom = checked; })
        this.TagContentCheckRow('书源分类', this.tagDialogSource,
          (checked: boolean) => { this.tagDialogSource = checked; })
        this.TagContentCheckRow('字数', this.tagDialogWordCount,
          (checked: boolean) => { this.tagDialogWordCount = checked; })
      }.width('100%').margin({ top: 10 })
      Row() {
        Text('取消').fontSize(LABEL_LARGE).fontColor(this.themeColorTextTertiary).padding(10)
          .onClick(() => { this.showTagContentDialog = false; })
        Blank()
        Text('确认').fontSize(LABEL_LARGE).fontColor('#B9C8FF').padding(10)
          .onClick(() => { this.applyTagContentDialog(); })
      }.width('100%').margin({ top: 14 })
    }.width('86%').constraintSize({ maxWidth: 340 }).padding(18)
      .backgroundColor(this.themeColorSurfaceElevated).borderRadius(12)
      .alignItems(HorizontalAlign.Start)
  }

  /** 对话框里的一行复选；整行可点，命中区域比 Checkbox 本体大。 */
  @Builder
  private TagContentCheckRow(title: string, checked: boolean, onChange: (value: boolean) => void) {
    Row({ space: 10 }) {
      Checkbox().select(checked).onChange((value: boolean) => onChange(value))
      Text(title).fontSize(LABEL_LARGE).fontColor(this.themeColorTextPrimary).layoutWeight(1)
    }.width('100%').padding({ top: 6, bottom: 6 })
      .onClick(() => onChange(!checked))
  }

  /** 对话框遮罩：盖住整个布局面板，点面板外的区域不关闭（对齐上游 AlertDialog 的模态行为）。 */
  @Builder
  private TagContentDialogOverlay() {
    if (this.showTagContentDialog) {
      Column() {
        this.TagContentDialog()
      }.width('100%').height('100%').backgroundColor('#66000000')
        .justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
    }
  }

  /** 卡片底色编辑行：预览方块 + hex 输入，复用 CustomThemePage.ColorEditor 的交互口径。 */
  @Builder
  private ColorPickerRow(title: string, hex: string, onHex: (value: string) => void) {
    Row() {
      Row().width(24).height(24).borderRadius(6)
        .backgroundColor(normalizeCustomColor(hex).length > 0 ? hex : this.themeColorSurfacePrimary)
        .border({ width: 1, color: this.themeColorTextTertiary })
      Text(title).fontSize(TITLE_SMALL).fontColor(this.themeColorTextSecondary).layoutWeight(1).margin({ left: 12 })
      TextInput({ text: hex, placeholder: '#RRGGBB' }).width(110).fontSize(BODY_SMALL)
        .fontColor(this.themeColorTextPrimary)
        .onChange((value: string) => onHex(value))
    }.width('100%').padding({ left: 16, right: 16, top: 10, bottom: 10 })
  }

  /** 分区标题，对应上游 PillHeaderDivider。 */
  @Builder
  private LayoutSectionHeader(title: string) {
    Row() {
      Text(title).fontSize(BODY_SMALL).fontColor(this.themeColorTextTertiary)
    }.width('100%').padding({ left: 16, right: 16, top: 14, bottom: 6 })
  }

  /**
   * 书架布局设置面板，对应上游 BookshelfConfigSheet。
   *
   * 只迁移当前项目已有数据模型能支撑的项；上游的封面尺寸、卡片颜色、
   * 标签徽标等依赖书籍字段或网络状态，留待后续轮次。
   */
  @Builder
  private LayoutSheetContent() {
    Column() {
      Row() {
        Text('书架布局').fontSize(TITLE_LARGE).fontWeight(FontWeight.Medium).fontColor(this.themeColorTextPrimary).layoutWeight(1)
        Text('完成').fontSize(LABEL_LARGE).fontColor('#B9C8FF').padding(8)
          .onClick(async () => { await this.submitLayout(); })
      }.width('100%').padding({ left: 18, right: 12, top: 14, bottom: 6 })

      Scroll() {
        Column() {
          this.LayoutSectionHeader('分组')
          this.LayoutMenuRow('分组样式', '页签 / 隐藏页签 / 文件夹', BOOK_GROUP_STYLE_OPTIONS,
            this.layoutDraft.bookGroupStyle,
            (value: number) => { this.updateLayoutDraft((draft: BookshelfLayoutSettings) => { draft.bookGroupStyle = value; }); })
          this.LayoutSwitchRow('隐藏没有书籍的分组', '页签只显示有书的分类',
            this.layoutDraft.hideEmptyGroups,
            (value: boolean) => { this.updateLayoutDraft((draft: BookshelfLayoutSettings) => { draft.hideEmptyGroups = value; }); })

          if (this.layoutDraft.bookGroupStyle === 2) {
            this.LayoutSectionHeader('文件夹（竖屏）')
            this.LayoutMenuRow('文件夹布局模式·竖屏', '列表 / 网格', BOOKSHELF_FOLDER_LAYOUT_MODE_OPTIONS,
              this.layoutDraft.bookshelfFolderLayoutModePortrait,
              (value: number) => { this.updateLayoutDraft((draft: BookshelfLayoutSettings) => { draft.bookshelfFolderLayoutModePortrait = value; }); })
            this.LayoutSliderRow('文件夹网格列数·竖屏', '网格模式下分组卡片每行个数',
              this.layoutDraft.bookshelfFolderLayoutGridPortrait, 1, 15,
              (value: number) => {
                this.updateLayoutDraft((draft: BookshelfLayoutSettings) => {
                  draft.bookshelfFolderLayoutGridPortrait = value;
                });
              })
            this.LayoutSliderRow('文件夹列表列数·竖屏', '列表模式下分组卡片每行个数',
              this.layoutDraft.bookshelfFolderLayoutListPortrait, 1, 5,
              (value: number) => {
                this.updateLayoutDraft((draft: BookshelfLayoutSettings) => {
                  draft.bookshelfFolderLayoutListPortrait = value;
                });
              })

            this.LayoutSectionHeader('文件夹（横屏）')
            this.LayoutMenuRow('文件夹布局模式·横屏', '列表 / 网格', BOOKSHELF_FOLDER_LAYOUT_MODE_OPTIONS,
              this.layoutDraft.bookshelfFolderLayoutModeLandscape,
              (value: number) => { this.updateLayoutDraft((draft: BookshelfLayoutSettings) => { draft.bookshelfFolderLayoutModeLandscape = value; }); })
            this.LayoutSliderRow('文件夹网格列数·横屏', '网格模式下分组卡片每行个数',
              this.layoutDraft.bookshelfFolderLayoutGridLandscape, 1, 15,
              (value: number) => {
                this.updateLayoutDraft((draft: BookshelfLayoutSettings) => {
                  draft.bookshelfFolderLayoutGridLandscape = value;
                });
              })
            this.LayoutSliderRow('文件夹列表列数·横屏', '列表模式下分组卡片每行个数',
              this.layoutDraft.bookshelfFolderLayoutListLandscape, 1, 5,
              (value: number) => {
                this.updateLayoutDraft((draft: BookshelfLayoutSettings) => {
                  draft.bookshelfFolderLayoutListLandscape = value;
                });
              })

            this.LayoutSectionHeader('文件夹列表样式')
            this.LayoutMenuRow('文件夹列表样式', '分组 / 紧凑列表 / 横排封面数量', BOOKSHELF_GROUP_LIST_STYLE_OPTIONS,
              this.layoutDraft.bookshelfGroupListStyle,
              (value: number) => { this.updateLayoutDraft((draft: BookshelfLayoutSettings) => { draft.bookshelfGroupListStyle = value; }); })
            if (this.layoutDraft.bookshelfGroupListStyle === 2) {
              this.LayoutSliderRow('横排封面数量', '分组卡片一行显示的封面数，不足右侧留空',
                this.layoutDraft.bookshelfGroupCoverCount, 1, 10,
                (value: number) => {
                  this.updateLayoutDraft((draft: BookshelfLayoutSettings) => {
                    draft.bookshelfGroupCoverCount = value;
                  });
                })
            }
          }

          this.LayoutSectionHeader('排序')
          this.LayoutMenuRow('排序方式', '', BOOK_SORT_OPTIONS, this.layoutDraft.bookshelfSort,
            (value: number) => { this.updateLayoutDraft((draft: BookshelfLayoutSettings) => { draft.bookshelfSort = value; }); })
          this.LayoutMenuRow('排序方向', '', BOOKSHELF_SORT_ORDER_OPTIONS, this.layoutDraft.bookshelfSortOrder,
            (value: number) => { this.updateLayoutDraft((draft: BookshelfLayoutSettings) => { draft.bookshelfSortOrder = value; }); })

          this.LayoutSectionHeader('布局')
          // 布局模式按当前方向读写：横屏写 bookshelfLayoutModeLandscape，对齐上游
          // BookshelfConfigSheet.kt:247-265（同一个下拉按 isLandscape 分支写两个字段）。
          this.LayoutMenuRow('布局模式', this.isLandscape ? '横屏下的书架呈现方式' : '竖屏下的书架呈现方式',
            BOOKSHELF_LAYOUT_MODE_OPTIONS, this.activeDraftLayoutMode(),
            (value: number) => {
              this.updateLayoutDraft((draft: BookshelfLayoutSettings) => {
                if (this.isLandscape) { draft.bookshelfLayoutModeLandscape = value; }
                else { draft.bookshelfLayoutModePortrait = value; }
              });
            })
          if (this.activeDraftLayoutMode() === 1) {
            this.LayoutMenuRow('网格样式', '标准 / 紧凑（书名进封面）/ 仅封面',
              BOOKSHELF_GRID_STYLE_OPTIONS, this.layoutDraft.bookshelfGridLayout,
              (value: number) => { this.updateLayoutDraft((draft: BookshelfLayoutSettings) => { draft.bookshelfGridLayout = value; }); })
          }
          // 列数上限对齐上游 BookshelfConfigSheet.kt:288（valueRange = 1f..15f）与 :412（1f..5f）；
          // 夹取已收进 LayoutSliderRow 内部（Math.max/min），这里只做字段写入。
          if (this.activeDraftLayoutMode() === 1) {
            this.LayoutSliderRow('网格列数', '每行显示的书封数量',
              this.activeDraftGridColumns(), 1, 15,
              (value: number) => {
                this.updateLayoutDraft((draft: BookshelfLayoutSettings) => {
                  if (this.isLandscape) {
                    draft.bookshelfLayoutGridLandscape = value;
                  } else {
                    draft.bookshelfLayoutGridPortrait = value;
                  }
                });
              })
          } else {
            this.LayoutSliderRow('列表列数', '每行显示的书封数量',
              this.activeDraftListColumns(), 1, 5,
              (value: number) => {
                this.updateLayoutDraft((draft: BookshelfLayoutSettings) => {
                  if (this.isLandscape) {
                    draft.bookshelfLayoutListLandscape = value;
                  } else {
                    draft.bookshelfLayoutListPortrait = value;
                  }
                });
              })
          }
          // 列表详情区：对齐上游 BookshelfConfigSheet.kt:332 的 AnimatedVisibility(layoutMode != 1)，
          // 整串只在列表模式下出现；内部结构照 :338 / :425 / :434-488 的顺序与嵌套。
          if (this.activeDraftLayoutMode() !== 1) {
            this.LayoutSwitchRow('显示分隔线', '列表卡片之间显示一条细横线',
              this.layoutDraft.bookshelfShowDivider,
              (value: boolean) => { this.updateLayoutDraft((draft: BookshelfLayoutSettings) => { draft.bookshelfShowDivider = value; }); })
            // 显示详情区总开关（上游 R.string.show_more_info，默认 false）：本地下面的四项都它的子项。
            this.LayoutSwitchRow('显示更多信息', '列表卡片展开简介、最新章节等详情',
              this.layoutDraft.showBookIntro,
              (value: boolean) => { this.updateLayoutDraft((draft: BookshelfLayoutSettings) => { draft.showBookIntro = value; }); })
            if (this.layoutDraft.showBookIntro) {
              this.LayoutSwitchRow('封面垂直居中', '关闭后列表封面与文字顶部对齐',
                this.layoutDraft.bookshelfListCoverCenter,
                (value: boolean) => { this.updateLayoutDraft((draft: BookshelfLayoutSettings) => { draft.bookshelfListCoverCenter = value; }); })
              this.LayoutSwitchRow('显示最新章节', '列表卡片显示最后阅读的章节名',
                this.layoutDraft.bookshelfShowLatestChapter,
                (value: boolean) => { this.updateLayoutDraft((draft: BookshelfLayoutSettings) => { draft.bookshelfShowLatestChapter = value; }); })
              this.LayoutSwitchRow('显示简介', '列表卡片显示书籍简介',
                this.layoutDraft.bookshelfShowIntro,
                (value: boolean) => { this.updateLayoutDraft((draft: BookshelfLayoutSettings) => { draft.bookshelfShowIntro = value; }); })
              // 上游 :465 的额外条件是 settings.bookshelfShowIntro && layoutMode == 0。
              if (this.layoutDraft.bookshelfShowIntro && this.activeDraftLayoutMode() === 0) {
                this.LayoutSwitchRow('简介在封面和信息下方', '开启后简介单独铺在卡片底部',
                  this.layoutDraft.bookshelfListIntroBelowContent,
                  (value: boolean) => { this.updateLayoutDraft((draft: BookshelfLayoutSettings) => { draft.bookshelfListIntroBelowContent = value; }); })
              }
              // 上游 :477 的额外条件是 settings.bookshelfShowIntro；valueRange 0f..10f，0 表示显示全部。
              if (this.layoutDraft.bookshelfShowIntro) {
                this.LayoutSliderRow('简介行数', `简介最多显示几行，0 表示显示全部（当前${this.introMaxLinesDescription()}）`,
                  this.layoutDraft.bookshelfIntroMaxLines, 0, 10,
                  (value: number) => {
                    this.updateLayoutDraft((draft: BookshelfLayoutSettings) => {
                      draft.bookshelfIntroMaxLines = value;
                    });
                  })
              }
            }
          }
          this.LayoutSectionHeader('标签')
          this.LayoutSwitchRow('显示标签', '在书卡上显示自定义标签、来源分类与字数',
            this.layoutDraft.bookshelfShowTag,
            (value: boolean) => { this.updateLayoutDraft((draft: BookshelfLayoutSettings) => { draft.bookshelfShowTag = value; }); })
          if (this.layoutDraft.bookshelfShowTag) {
            // D-2 / F-5：上游是 CompactClickableSettingItem + 独立对话框，
            // 描述串是「用户标签 · 书源分类 · 字数」，未选择时显示 bookshelf_tag_none。
            Row() {
              Column() {
                Text('标签显示内容').fontSize(TITLE_SMALL).fontColor(this.themeColorTextSecondary)
                Text(this.tagSourcesLabel()).fontSize(LABEL_SMALL).fontColor(this.themeColorTextTertiary).margin({ top: 3 })
              }.alignItems(HorizontalAlign.Start).layoutWeight(1)
              AppGlyph({ name: 'profileExpandMore', glyphSize: 16 })
            }.width('100%').padding({ left: 16, right: 16, top: 12, bottom: 12 })
              .onClick(() => { this.openTagContentDialog(); })
            this.LayoutSwitchRow('自定义标签配色', '开启后按下面的配色给标签行取色',
              this.layoutDraft.enableCustomTagColors,
              (value: boolean) => { this.updateLayoutDraft((draft: BookshelfLayoutSettings) => { draft.enableCustomTagColors = value; }); })
            if (this.layoutDraft.enableCustomTagColors) {
              Row() {
                Column() {
                  Text('管理标签配色').fontSize(TITLE_SMALL).fontColor(this.themeColorTextSecondary)
                  Text(`${this.tagColorsCount()} 组配色`).fontSize(LABEL_SMALL).fontColor(this.themeColorTextTertiary).margin({ top: 3 })
                }.alignItems(HorizontalAlign.Start).layoutWeight(1)
                AppGlyph({ name: 'profileExpandMore', glyphSize: 16 })
              }.width('100%').padding({ left: 16, right: 16, top: 12, bottom: 12 })
                .onClick(() => { this.openTagColorPage(); })
            }
          }
          this.LayoutSectionHeader('徽标')
          this.LayoutSwitchRow('显示未读数', '在封面角标与标题右侧显示未读章节数',
            this.layoutDraft.showUnread,
            (value: boolean) => { this.updateLayoutDraft((draft: BookshelfLayoutSettings) => { draft.showUnread = value; }); })
          this.LayoutSwitchRow('显示更新红点', '有新增章节时显示红点（需同时开显示未读数）',
            this.layoutDraft.showUnreadNew,
            (value: boolean) => { this.updateLayoutDraft((draft: BookshelfLayoutSettings) => { draft.showUnreadNew = value; }); })
          this.LayoutSwitchRow('显示等待更新数', '控制标题末尾待更新书数 (N)',
            this.layoutDraft.showWaitUpCount,
            (value: boolean) => { this.updateLayoutDraft((draft: BookshelfLayoutSettings) => { draft.showWaitUpCount = value; }); })
          this.LayoutSwitchRow('显示书籍计数', '在分组卡上显示书籍数',
            this.layoutDraft.showBookCount,
            (value: boolean) => { this.updateLayoutDraft((draft: BookshelfLayoutSettings) => { draft.showBookCount = value; }); })
          this.LayoutSwitchRow('显示最后更新时间', '非本地书显示最近更新时间的相对文案',
            this.layoutDraft.showLastUpdateTime,
            (value: boolean) => { this.updateLayoutDraft((draft: BookshelfLayoutSettings) => { draft.showLastUpdateTime = value; }); })
          this.LayoutSwitchRow('显示书籍类型', '在卡片上显示 本地 / EPUB 等类型',
            this.layoutDraft.showTip,
            (value: boolean) => { this.updateLayoutDraft((draft: BookshelfLayoutSettings) => { draft.showTip = value; }); })
          this.LayoutSliderRow('书名行数', '书封下方标题最多显示几行',
            this.layoutDraft.bookshelfTitleMaxLines, 1, 5,
            (value: number) => {
              this.updateLayoutDraft((draft: BookshelfLayoutSettings) => {
                draft.bookshelfTitleMaxLines = value;
              });
            })
          this.LayoutSwitchRow('标题居中', '关闭后书名左对齐', this.layoutDraft.bookshelfTitleCenter,
            (value: boolean) => { this.updateLayoutDraft((draft: BookshelfLayoutSettings) => { draft.bookshelfTitleCenter = value; }); })
          this.LayoutSwitchRow('标题小字号', '书名用 11 号字，默认 13 号', this.layoutDraft.bookshelfTitleSmallFont,
            (value: boolean) => { this.updateLayoutDraft((draft: BookshelfLayoutSettings) => { draft.bookshelfTitleSmallFont = value; }); })

          this.LayoutSectionHeader('外观')
          this.LayoutSwitchRow('精简详情', '开启后卡片只留封面与书名', this.layoutDraft.bookshelfLayoutCompact,
            (value: boolean) => { this.updateLayoutDraft((draft: BookshelfLayoutSettings) => { draft.bookshelfLayoutCompact = value; }); })
          this.ColorPickerRow('日间卡片底色', this.dayCardColorHex,
            (value: string) => {
              this.dayCardColorHex = value;
              this.updateLayoutDraft((draft: BookshelfLayoutSettings) => { draft.bookshelfCardColor = bookshelfCardHexToInt(value); });
            })
          this.ColorPickerRow('夜间卡片底色', this.nightCardColorHex,
            (value: string) => {
              this.nightCardColorHex = value;
              this.updateLayoutDraft((draft: BookshelfLayoutSettings) => { draft.bookshelfCardColorDark = bookshelfCardHexToInt(value); });
            })
          // 取值范围对齐上游 BookshelfConfigSheet.kt:319-327 的 `valueRange = 40f..150f, steps = 110`。
          this.LayoutSliderRow('网格封面宽度', '书封在格子里最宽能到多少，格子更窄时以格子为准',
            this.layoutDraft.bookshelfGridCoverWidth, 40, 150,
            (value: number) => { this.updateLayoutDraft((draft: BookshelfLayoutSettings) => { draft.bookshelfGridCoverWidth = value; }); })
          // 取值范围对齐上游 BookshelfConfigSheet.kt:202-210 / :399-407 的 `valueRange = 40f..120f, steps = 80`。
          this.LayoutSliderRow('列表封面宽度', '列表模式下书封宽度',
            this.layoutDraft.bookshelfListCoverWidth, 40, 120,
            (value: number) => { this.updateLayoutDraft((draft: BookshelfLayoutSettings) => { draft.bookshelfListCoverWidth = value; }); })
          // 列表模式的「显示简介 / 显示最新章节」已移进「布局」组的详情区（受 showBookIntro 总开关约束），
          // 这里不再重复。
          this.LayoutSwitchRow('书封阴影', '', this.layoutDraft.bookshelfCoverShadow,
            (value: boolean) => { this.updateLayoutDraft((draft: BookshelfLayoutSettings) => { draft.bookshelfCoverShadow = value; }); })

          this.LayoutSectionHeader('其它')
          this.LayoutSwitchRow('搜索按钮优先打开搜索页', '关闭后单击先进筛选、长按进搜索页',
            this.layoutDraft.bookshelfSearchActionDirectToSearch,
            (value: boolean) => { this.updateLayoutDraft((draft: BookshelfLayoutSettings) => { draft.bookshelfSearchActionDirectToSearch = value; }); })
          this.LayoutSwitchRow('显示快速滚动条', '书架右侧出现可拖动滚动条',
            this.layoutDraft.showBookshelfFastScroller,
            (value: boolean) => { this.updateLayoutDraft((draft: BookshelfLayoutSettings) => { draft.showBookshelfFastScroller = value; }); })
          this.LayoutSwitchRow('页签栏菜单按钮', '页签栏右端出现分组下拉按钮',
            this.layoutDraft.showBookshelfTabMenu,
            (value: boolean) => { this.updateLayoutDraft((draft: BookshelfLayoutSettings) => { draft.showBookshelfTabMenu = value; }); })
          this.LayoutSliderRow('书架更新线程数', '',
            this.layoutDraft.bookshelfRefreshingLimit, 0, 100,
            (value: number) => {
              this.updateLayoutDraft((draft: BookshelfLayoutSettings) => {
                draft.bookshelfRefreshingLimit = value;
              });
            })
        }.width('100%').padding({ bottom: 24 })
      }.edgeEffect(EdgeEffect.None).layoutWeight(1).scrollBar(BarState.Off)
    }.width('100%').height('100%').backgroundColor('#17181E')
      .overlay(this.TagContentDialogOverlay(), { align: Alignment.Center })
  }

  /**
   * 书架上的半模态面板统一入口。
   *
   * 同一组件挂多个 bindSheet 只有最后一个生效（本项目已踩过的坑），
   * 所以布局面板与分组面板共用同一个 sheet，按状态分发内容。
   */
  @Builder
  private ShelfSheetContent() {
    if (this.showMoveGroupSheet) {
      this.MoveGroupSheetContent()
    } else if (this.showTagColorPage) {
      this.TagColorSheet()
    } else if (this.showLayoutSheet) {
      this.LayoutSheetContent()
    } else if (this.showLogSheet) {
      this.LogSheetContent()
    } else if (this.showImportSheet) {
      this.ImportSheetContent()
    } else if (this.showExportSheet) {
      this.ExportSheetContent()
    } else {
      this.GroupManagerSheet()
    }
  }

  /** 日志面板：显示 AppLog 的内存缓冲，底部一键清空。对应上游 AppLogSheet。 */
  @Builder
  private LogSheetContent() {
    Column() {
      Row() {
        Text('日志').fontSize(TITLE_LARGE).fontWeight(FontWeight.Bold).fontColor(this.themeColorTextPrimary)
        Blank()
        Text('清空').fontSize(LABEL_MEDIUM).fontColor(this.themeColorAccent).padding(6)
          .onClick(() => { AppLog.clear(); this.logEntries = []; })
      }.width('100%').padding({ left: 16, right: 16, top: 18, bottom: 12 })
      if (this.logEntries.length === 0) {
        Column() {
          Text('暂无日志').fontSize(LABEL_MEDIUM).fontColor(this.themeColorTextTertiary)
        }.layoutWeight(1).width('100%').justifyContent(FlexAlign.Center)
      } else {
        List() {
          ForEach(this.logEntries, (entry: AppLogEntry) => {
            ListItem() {
              // 上游 AppLogSheet.kt:115-135：时间行 labelMedium/outline，正文 bodyMedium/onSurface。
              Column() {
                Text(AppLog.formatTime(entry.timestamp)).fontSize(LABEL_MEDIUM)
                  .fontColor(this.themeColorTextTertiary).width('100%')
                Text(entry.content()).fontSize(BODY_MEDIUM).fontColor(this.themeColorTextPrimary)
                  .maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
                  .width('100%').margin({ top: 4 })
              }.width('100%').alignItems(HorizontalAlign.Start)
            }.padding({ left: 16, right: 16, top: 12, bottom: 12 })
          }, (entry: AppLogEntry) => `${entry.timestamp}:${entry.message.length}`)
        }.layoutWeight(1).width('100%').scrollBar(BarState.Off)
      }
    }.width('100%').height('100%').backgroundColor('#17181E')
  }

  /**
   * 配色管理页（:211）。上游是独立底部弹层 LabelColorManageSheet.kt，本地复用书架
   * 的同一个 bindSheet，避免同组件挂多个 sheet 只有最后一个生效。
   */
  @Builder
  private TagColorSheet() {
    Column() {
      Row() {
        Text('‹ 返回').fontSize(LABEL_LARGE).fontColor(this.themeColorAccent).padding(6)
          .onClick(() => { this.showTagColorPage = false; })
        Text('管理标签配色').fontSize(TITLE_LARGE).fontWeight(FontWeight.Bold)
          .fontColor(this.themeColorTextPrimary).layoutWeight(1).textAlign(TextAlign.Center)
        Text('生成').fontSize(LABEL_MEDIUM).fontColor(this.themeColorAccent).padding(6)
          .onClick(async () => { await this.generateTagColors(); })
        Text('添加').fontSize(LABEL_MEDIUM).fontColor(this.themeColorAccent).padding(6)
          .onClick(async () => { await this.addTagColor(); })
      }.width('100%').padding({ left: 12, right: 12, top: 16, bottom: 12 })

      if (this.tagColorsDraft.length === 0) {
        Column() {
          Text('暂无配色，点「生成」创建 8 组').fontSize(LABEL_MEDIUM).fontColor(this.themeColorTextTertiary)
        }.layoutWeight(1).width('100%').justifyContent(FlexAlign.Center)
      } else {
        Scroll() {
          Column() {
            ForEach(this.tagColorsDraft, (pair: TagColorPair, index: number) => {
              Row() {
                Text(`颜色 ${index + 1}`).fontSize(BODY_SMALL)
                  .fontColor(pair.textColor !== 0 ? argbToColorHex(pair.textColor) : this.themeColorTextPrimary)
                  .padding({ left: 10, right: 10, top: 8, bottom: 8 })
                  .backgroundColor(pair.bgColor !== 0 ? argbToColorHex(pair.bgColor) : this.themeColorSurfaceTertiary)
                  .borderRadius(6)
                Blank()
                Text('编辑').fontSize(LABEL_MEDIUM).fontColor(this.themeColorAccent).padding(6)
                  .onClick(() => { this.openTagColorPicker(index); })
                Text('删除').fontSize(LABEL_MEDIUM).fontColor('#D99AA5').padding(6)
                  .onClick(async () => { await this.removeTagColor(index); })
              }.width('100%').padding({ left: 16, right: 12, top: 6, bottom: 6 })
            }, (pair: TagColorPair, index: number) => `${index}_${pair.textColor}_${pair.bgColor}`)
          }
        }.edgeEffect(EdgeEffect.None).layoutWeight(1).width('100%').scrollBar(BarState.Off)
      }

      if (this.showTagColorPicker) {
        Row() {
          TextInput({ text: this.tagColorPickerHex, placeholder: '#RRGGBB 文字色' })
            .layoutWeight(1).fontSize(BODY_SMALL).fontColor(this.themeColorTextPrimary)
            .onChange((value: string) => { this.tagColorPickerHex = value; })
          Text('取消').fontSize(LABEL_MEDIUM).fontColor(this.themeColorTextTertiary).padding(6)
            .onClick(() => { this.showTagColorPicker = false; })
          Text('确定').fontSize(LABEL_MEDIUM).fontColor(this.themeColorAccent).padding(6)
            .onClick(async () => { await this.confirmTagColor(); })
        }.width('100%').padding({ left: 16, right: 12, top: 8, bottom: 16 })
      }
    }.width('100%').height('100%').backgroundColor('#17181E')
  }

  /** 导出书单：写 bookshelf.json，字段与上游 ExportBookshelfUseCase 一致。 */
  private async exportBookList(): Promise<void> {
    const context = this.getUIContext().getHostContext();
    if (context === undefined) { return; }
    try {
      const saved = await BookshelfListTransfer.exportList(context, this.books);
      if (saved) {
        // 上游 exportToUri 成功固定 toast「导出成功」（BookshelfViewModel.kt:1358）。
        AppLog.put(`书单导出成功，共 ${this.books.length} 本`);
        this.onUnavailableAction('导出成功');
      }
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      // 上游 exportToUri 失败是「导出失败\n${message}」（:1360）。
      this.onUnavailableAction(`导出失败\n${message}`);
      AppLog.put(`书单导出失败: ${message}`);
    }
  }

  /**
   * A-30 的「上传」支路：把书单 JSON 传到直链上传服务，成功拿到可分享 URL。
   *
   * 上游 `BookshelfViewModel.kt:1364-1381 uploadBookshelf`：
   * `uploadRepository.upload(fileName = "bookshelf.json", file = json, contentType = "application/json")`
   * → 成功把 URL 塞 `pendingUploadUrlFlow`，`BookshelfScreen.kt:357-370` 弹 snackbar
   * 「上传成功: $url」并带「复制链接」action；失败「上传失败: ...」。
   * 本地上传实现是 `lib/DirectLinkUpload.ets`（对齐上游 `DirectLinkUpload.upLoad`），
   * 规则由用户在「其它设置 → 直链上传」里配置。
   */
  private async uploadBookList(): Promise<void> {
    const context = this.getUIContext().getHostContext();
    if (context === undefined) { return; }
    if (this.books.length === 0) {
      // 上游 exportBookshelf 空列表抛 NoStackTraceException("书籍不能为空")。
      this.onUnavailableAction('书籍不能为空');
      return;
    }
    const json = BookshelfListTransfer.toJson(this.books);
    this.busyText = '上传中…';
    try {
      const rule = await DirectLinkUploadStore.loadRule(context);
      const url = await DirectLinkUpload.upload(context, 'bookshelf.json', json, 'application/json', rule);
      AppLog.put(`书单上传成功: ${url}`);
      this.getUIContext().showAlertDialog({
        title: '上传成功',
        message: url,
        autoCancel: true,
        primaryButton: { value: '关闭', action: () => {} },
        secondaryButton: {
          value: '复制链接',
          action: () => { void this.copyUploadUrl(url); }
        }
      });
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      this.onUnavailableAction(`上传失败: ${message}`);
      AppLog.put(`书单上传失败: ${message}`);
    } finally {
      this.busyText = '';
    }
  }

  /** 上传成功后「复制链接」：对齐上游 snackbar 的 actionLabel（BookshelfScreen.kt:361-368）。 */
  private async copyUploadUrl(url: string): Promise<void> {
    try {
      const data = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, url);
      await pasteboard.getSystemPasteboard().setData(data);
      this.onUnavailableAction('链接已复制');
    } catch (error) {
      this.onUnavailableAction('复制失败');
    }
  }

  /**
   * 导入书单（选系统文件那条路）。
   *
   * 对齐上游 `ImportBookshelfUseCase.importByJson`（:66-109）：书单条目只有书名/作者，
   * 必须用全部启用书源精确搜索补全成在线书才入库，搜不到的提示「没有搜索到<书名><作者>」。
   * 补全逻辑在 `bookSource/PreciseSearchCoordinator.ets`。
   *
   * 上游 `groupId = uiState.groups.getOrNull(uiState.selectedGroupIndex)?.groupId ?: -1L`
   * 且 `if (groupId > 0) book.group = groupId`——本地分组按名字存（Book.groupNames），
   * 所以等价做法是把当前筛选分组名写进 groupNames。
   */
  private async importBookList(): Promise<void> {
    const context = this.getUIContext().getHostContext();
    if (context === undefined) { return; }
    try {
      const entries = await BookshelfListTransfer.selectAndParse(context);
      if (entries === undefined) { return; }
      await this.applyImportedEntries(entries);
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      this.onUnavailableAction(`书单导入失败：${message}`);
      AppLog.put(`书单导入失败: ${message}`);
    }
  }

  /** 把解析出的书单条目补全成在线书并落库；搜不到的逐条提示。 */
  private async applyImportedEntries(entries: BookshelfListEntry[]): Promise<void> {
    const searchEntries = BookshelfListTransfer.toSearchEntries(entries);
    if (searchEntries.length === 0) {
      this.onUnavailableAction('书单里没有可导入的书目');
      return;
    }
    this.busyText = '导入中...';
    try {
      const outcome = await PreciseSearchCoordinator.searchMany(searchEntries, this.books,
        (done: number, total: number) => {
          this.busyText = `导入中... (${done}/${total})`;
        });
      const filter = this.activeFilter();
      if (filter !== '全部') {
        for (let index = 0; index < outcome.books.length; index++) {
          const book = outcome.books[index];
          book.groupNames = [filter];
          book.groupName = filter;
        }
      }
      if (outcome.books.length > 0) {
        await this.onImportBookList(outcome.books);
        AppLog.put(`书单导入成功，新增 ${outcome.books.length} 本`);
        this.onUnavailableAction('成功');
      }
      // 上游逐条 toast「没有搜索到<name><author>」；本地没有逐条 toast 队列，聚合成一条，
      // 条目多时只列前 3 个并带总数，避免提示框被撑爆。
      if (outcome.missing.length > 0) {
        const shown = outcome.missing.slice(0, 3).join('、');
        const more = outcome.missing.length > 3 ? ` 等 ${outcome.missing.length} 本` : '';
        this.onUnavailableAction(`没有搜索到<${shown}>${more}`);
      }
      if (outcome.books.length === 0 && outcome.missing.length === 0) {
        this.onUnavailableAction('书单里没有可导入的新书（可能都已存在）');
      }
    } finally {
      this.busyText = '';
    }
  }

  @Builder
  private MoreMenu() {
    UiMenuPanel({
      items: this.moreMenuItems(),
      panelWidth: SHELF_MENU_WIDTH,
      onSelect: (key: string) => {
        this.moreMenuVisible = false;
        this.onMoreMenuSelect(key);
      }
    })
  }

  private moreMenuItems(): UiMenuItem[] {
    // 图标逐项对齐上游 BookshelfScreen.kt:694-778：远程书籍 Wifi、布局设置 GridView、
    // 分组管理 ViewCarousel、添加网址 Link、导出书单 UploadFile。
    // 改前这五项分别是 cloud / list / folder / web / profileSave，其中「导出书单」与「添加本地」
    // 共用 profileSave，两行图标完全一样。
    return [
      { key: 'remote_book', title: '远程书籍', icon: 'wifi' },
      { key: 'import_local', title: '添加本地', icon: 'profileSave' },
      { key: 'refresh_toc', title: '更新目录', icon: 'profileRefresh' },
      { key: 'layout', title: '布局设置', icon: 'grid' },
      { key: 'group_manage', title: '分组管理', icon: 'carousel' },
      { key: 'add_url', title: '添加网址', icon: 'link' },
      { key: 'selection_mode', title: '选择模式', icon: 'edit' },
      { key: 'shelf_manage', title: '书架管理', icon: 'bookmark' },
      { key: 'export_list', title: '导出书单', icon: 'uploadFile' },
      { key: 'import_list', title: '导入书单', icon: 'cloudDownload' },
      { key: 'log', title: '日志', icon: 'profileHistory' }
    ];
  }

  private async onMoreMenuSelect(key: string): Promise<void> {
    if (key === 'remote_book') {
      this.onUnavailableAction('远程书籍导入尚未迁移');
      return;
    }
    if (key === 'import_local') {
      // 多选后先进确认页（批 10 的 :555）——真正导入在 Index 的确认页回调里。
      // 解析整本正文 + 建目录 + 写库期间屏幕没有任何变化，用户会以为点漏了（:156）。
      this.busyText = '正在导入，请稍候…';
      try {
        await this.onImportBook();
      } finally {
        // finally 不能省：导入抛异常时遮罩必须撤掉，否则书架永久卡在一层黑纱上。
        this.busyText = '';
      }
      return;
    }
    if (key === 'refresh_toc') {
      this.busyText = '正在重新识别目录…';
      try {
        await this.onRefreshToc();
      } finally {
        this.busyText = '';
      }
      return;
    }
    if (key === 'layout') {
      this.openLayoutSheet();
      return;
    }
    if (key === 'group_manage') {
      this.showGroupManager = true;
      return;
    }
    if (key === 'add_url') {
      // H-6：上游 BookshelfScreen.kt:1483-1491 走 SourceInputDialog，确认后 AddBookByUrl。
      this.openAddUrlDialog();
      return;
    }
    if (key === 'selection_mode') {
      this.toggleSelectionMode();
      return;
    }
    if (key === 'shelf_manage') {
      this.onOpenBookshelfManage(this.activeGroupId());
      return;
    }
    if (key === 'export_list') {
      // 上游 BookshelfScreen.kt:1507-1519：导出书单先弹 FilePickerSheet（选系统文件夹 / 上传 URL 两条路）。
      this.showExportSheet = true;
      return;
    }
    if (key === 'import_list') {
      // 上游 BookshelfScreen.kt:1493-1505：导入书单先弹 FilePickerSheet（选系统文件 / 输入URL 两条路）。
      this.showImportSheet = true;
      return;
    }
    if (key === 'log') {
      this.logEntries = AppLog.getAll();
      this.showLogSheet = true;
    }
  }

  /**
   * A-29：导入书单面板，对齐上游 `FilePickerSheet`（`ui/widget/components/filePicker/FilePickerSheet.kt:22-78`）
   * 在 `BookshelfScreen.kt:1493-1505` 的调用形态：
   * `title = import_bookshelf`，两条路 `onSelectSysFile`（选系统文件）与
   * `onManualInput`（跳 `AddUrlDialog`）。上游 `allowExtensions = arrayOf("json", "txt")`。
   *
   * 布局对齐上游 `OptionSheet`（`ui/widget/components/modalBottomSheet/OptionSheet.kt:25-87`）：
   * 每行最多 2 张卡、卡间距 12、卡高 100、圆角 12、底色 onSheetContent，
   * 卡内 32vp 图标（primary）+ 8vp 间隔 + labelMedium 单行文字。
   */
  @Builder
  private ImportSheetContent() {
    Column() {
      Row() {
        Text('导入书单').fontSize(TITLE_LARGE).fontWeight(FontWeight.Bold)
          .fontColor(this.themeColorTextPrimary).layoutWeight(1)
      }.width('100%').padding({ left: 18, right: 18, top: 14, bottom: 12 })
      Row({ space: 12 }) {
        this.FilePickerOptionCard('profileSave', '系统文件选择器', () => {
          this.showImportSheet = false;
          void this.importBookList();
        })
        this.FilePickerOptionCard('edit', '输入URL', () => {
          // 上游 onManualInput 是 `onIntent(ShowOverlay(BookshelfOverlay.AddUrlDialog))`，
          // 复用的就是「添加网址」那个对话框（其确认动作固定是 AddBookByUrl）。
          this.showImportSheet = false;
          this.openAddUrlDialog();
        })
      }.width('100%').padding({ left: 18, right: 18 }).alignItems(VerticalAlign.Top)
      Column().height(24)
    }.width('100%')
  }

  /**
   * A-30：导出书单面板，对齐上游 `FilePickerSheet` 在 `BookshelfScreen.kt:1507-1519` 的调用形态：
   * `title = export_bookshelf`，两条路 `onSelectSysDir`（选系统文件夹存 bookshelf.json）与
   * `onUpload`（`BookshelfIntent.UploadBookshelf` → 直链上传拿 URL）。
   */
  @Builder
  private ExportSheetContent() {
    Column() {
      Row() {
        Text('导出书单').fontSize(TITLE_LARGE).fontWeight(FontWeight.Bold)
          .fontColor(this.themeColorTextPrimary).layoutWeight(1)
      }.width('100%').padding({ left: 18, right: 18, top: 14, bottom: 12 })
      Row({ space: 12 }) {
        this.FilePickerOptionCard('folder', '系统文件夹选择器', () => {
          this.showExportSheet = false;
          void this.exportBookList();
        })
        this.FilePickerOptionCard('cloudUpload', '上传 URL', () => {
          this.showExportSheet = false;
          void this.uploadBookList();
        })
      }.width('100%').padding({ left: 18, right: 18 }).alignItems(VerticalAlign.Top)
      Column().height(24)
    }.width('100%')
  }

  /** 上游 `OptionCard`（`OptionSheet.kt:55-87`）的等价卡片：weight 1 + 高 100 + 圆角 12 + onSheetContent 底。 */
  @Builder
  private FilePickerOptionCard(icon: AppGlyphName, label: string, action: () => void) {
    Column({ space: 8 }) {
      AppGlyph({ name: icon, glyphSize: 32, tint: this.themeColorAccent })
      Text(label).fontSize(LABEL_MEDIUM).fontColor(this.themeColorTextPrimary)
        .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis }).textAlign(TextAlign.Center)
    }
    .layoutWeight(1).height(100).justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
    .backgroundColor(this.themeColorOnSheetContent).borderRadius(12)
    .onClick(action)
  }

  /**
   * H-6：网址导入对话框，对齐上游 `SourceInputDialog`（`ImportComponents.kt:56-105`）：
   * 外层是 `AppAlertDialog`（标题 `add_book_url`「添加书籍网址」），正文一个 `maxLines = 5` 的输入框
   * （`label = hint`「请输入 URL 或 JSON」），按钮「确认」/「取消」；
   * 上游 `onConfirm` 里 `if (text.isNotBlank()) onConfirm(text)` —— 空输入不提交，但不禁用按钮。
   * 书架页调用点（`BookshelfScreen.kt:1483-1491`）没传 historyValues，所以这里也没有历史 chip 行。
   */
  @Builder
  private AddUrlDialog() {
    AppAlertDialog({
      title: '添加书籍网址',
      confirmText: '确认',
      dismissText: '取消',
      onConfirm: () => { void this.submitAddUrl(); },
      onDismiss: () => { this.closeAddUrlDialog(); }
    }) {
      DialogTextInput({
        initialText: this.addUrlInput,
        placeholder: '请输入 URL 或 JSON',
        maxLines: 5,
        onValueChange: (value: string) => { this.addUrlInput = value; }
      })
    }
  }

  private openAddUrlDialog(): void {
    this.addUrlInput = '';
    if (this.addUrlDialogId >= 0) { return; }
    this.addUrlDialogBuilder = (): void => { this.AddUrlDialog(); };
    this.getUIContext().getPromptAction().openCustomDialog({
      builder: this.addUrlDialogBuilder,
      autoCancel: true,
      alignment: DialogAlignment.Center,
      onWillDismiss: () => {
        this.addUrlDialogId = -1;
        this.addUrlInput = '';
      }
    }).then((id: number) => {
      this.addUrlDialogId = id;
    }).catch((error: Error) => {
      console.error(`[Bookshelf] 打开添加网址对话框失败: ${error}`);
    });
  }

  private closeAddUrlDialog(): void {
    if (this.addUrlDialogId >= 0) {
      this.getUIContext().getPromptAction().closeCustomDialog(this.addUrlDialogId);
      this.addUrlDialogId = -1;
    }
    this.addUrlInput = '';
  }

  /**
   * H-6 提交：空输入直接忽略（上游 `if (text.isNotBlank()) onConfirm(text)`）；
   * 有输入则跑 AddBookByUrlUseCase 的完整流程，成功后提示并刷新书架。
   */
  private async submitAddUrl(): Promise<void> {
    const raw = this.addUrlInput.trim();
    if (raw.length === 0) { return; }
    this.closeAddUrlDialog();
    const context = this.getUIContext().getHostContext();
    if (context === undefined) { return; }
    this.busyText = '添加中…';
    try {
      const result = await AddBookByUrlUseCase.execute(context, raw, (count: number) => {
        this.busyText = `添加中… (${count})`;
      });
      if (result.successCount > 0) {
        this.onUnavailableAction('添加成功');
        await this.onImportBookList([]);
      } else {
        const reason = result.failures.length > 0 ? `：${result.failures[0]}` : '';
        this.onUnavailableAction(`添加网址失败${reason}`);
      }
    } finally {
      this.busyText = '';
    }
  }

  /**
   * A-7：编辑态顶栏左侧的关闭按钮，对齐上游 `TopBarNavigationButton(Close, cancel_select)`。
   * 上游文案取 `R.string.cancel_select`（zh-rCN「取消选择」）。
   */
  @Builder
  private SelectionExitIcon() {
    Row() {
      AppGlyph({ name: 'profileClose', glyphSize: 20, tint: this.themeColorTextPrimary })
    }
    .width(40).height(40).justifyContent(FlexAlign.Center)
    .borderRadius(20)
    .accessibilityText('取消选择')
    .onClick(() => { this.clearSelection(); })
  }

  @Builder bookshelfTopActions() {
    if (this.selectionMode) {
      // G-1/G-2/G-4/G-5/G-6：编辑态六个动作在顶栏 actions 槽（上游 BookshelfScreen.kt:609-681
      // 全部 AnimatedVisibility(visible = isEditMode)）——全选 / 反选 / 下载 / 移入分组 /
      // 私密标记 / 删除选中。顶栏左侧的退出按钮由 AppTopBar 的 navigationIcon 承担（A-7）。
      TopBarButton({ icon: 'selectAll', showDivider: false, accessibilityLabel: '全选', onSelect: () => this.selectAllVisible() })
      TopBarButton({ icon: 'profileRefresh', showDivider: false, accessibilityLabel: '反选', onSelect: () => this.invertVisibleSelection() })
      // :627-629 空选时点下载不弹框。
      TopBarButton({
        icon: 'download', showDivider: false, accessibilityLabel: '下载',
        disabled: this.selectedBookKeys.size === 0,
        onSelect: () => { if (this.selectedBookKeys.size > 0) { this.openBatchDownloadDialog(); } }
      })
      // :638-640 空选时点移组不弹面板。
      TopBarButton({
        icon: 'bookmark', showDivider: false, accessibilityLabel: '移入分组',
        disabled: this.selectedBookKeys.size === 0,
        onSelect: () => { if (this.selectedBookKeys.size > 0) { this.openMoveGroupSheet(); } }
      })
      // :646-669 可见条件「编辑态且已设过本地密码」；文案随目标态切换。
      if (this.privateHasPassword) {
        TopBarButton({
          icon: 'lock', showDivider: false,
          accessibilityLabel: this.selectionTargetPrivate() ? '设为私密' : '取消私密',
          disabled: this.selectedBookKeys.size === 0,
          onSelect: () => { if (this.selectedBookKeys.size > 0) { void this.toggleSelectedPrivate(); } }
        })
      }
      // :674-676 空选时点删除不弹确认框。
      TopBarButton({
        icon: 'delete', showDivider: false, accessibilityLabel: '删除选中',
        disabled: this.selectedBookKeys.size === 0,
        onSelect: () => {
          if (this.selectedBookKeys.size > 0) { this.openBatchDeleteDialog(); }
        }
      })
    } else {
      // B-1：上游 :1365-1371 同一颗按钮，点按与长按各有一个 contentDescription
      // （bookshelfSearchActionDirectToSearch 决定谁是「搜索」谁是「筛选」），
      // 长按的语义标签单独挂在 GestureGroup 上。
      TopBarButton({
        icon: 'search',
        showDivider: false,
        accessibilityLabel: this.layout.bookshelfSearchActionDirectToSearch ? '搜索' : '筛选',
        onSelect: () => {
          if (this.layout.bookshelfSearchActionDirectToSearch) {
            this.onSearch();
          } else {
            this.showSearch = !this.showSearch;
            if (!this.showSearch) { this.searchQuery = ''; }
          }
        }
      }).accessibilityText(this.layout.bookshelfSearchActionDirectToSearch ? '搜索' : '筛选')
      .priorityGesture(LongPressGesture({ duration: 500 }).onAction((_event: GestureEvent): void => {
        if (this.layout.bookshelfSearchActionDirectToSearch) {
          this.showSearch = !this.showSearch;
          if (!this.showSearch) { this.searchQuery = ''; }
        } else {
          this.onSearch();
        }
      }))
      // menuMode: true 让 TopBarButton 不注册 onClick，点击交给外层 bindPopup。
      // 上游书架顶栏的溢出菜单入口文案取 `R.string.more_menu`（`BookshelfScreen.kt` 的 actions 尾段）。
      TopBarButton({ icon: 'more', menuMode: true, accessibilityLabel: '更多菜单' })
        .onClick(() => { this.moreMenuVisible = !this.moreMenuVisible; })
        .bindPopup(this.moreMenuVisible, {
          builder: this.MoreMenu,
          placement: Placement.BottomRight,
          popupColor: '#00000000',
          enableArrow: false,
          autoCancel: true,
          width: SHELF_MENU_WIDTH,
          onStateChange: (event: PopupStateChangeParam) => { this.moreMenuVisible = event.isVisible; }
        })
    }
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
    Column() {
      AppTopBar({
        // A-7：编辑态顶栏左侧给关闭按钮，对齐上游 BookshelfScreen.kt:1348-1354
        // `if (uiState.isEditMode) TopBarNavigationButton(Close, cancel_select)`。
        hasNavigation: this.selectionMode,
        navigationIcon: () => { this.SelectionExitIcon() },
        title: this.bookshelfTitle(),
        // :368（批6，r360）：首屏数据到位前标题逐字淡入，到位后由 999 切回整段渲染。
        titleRevealStep: this.titleRevealStep,
        subtitle: this.bookshelfSubtitle(),
        collapsed: this.collapsedHeader,
        actions: () => { this.bookshelfTopActions() }
      })

      if (this.showSearch) {
        Row() {
          AppGlyph({ name: 'search', glyphSize: 17 }).margin({ right: 9 })
          TextInput({ placeholder: '筛选书名/作者/书源/分组', text: this.searchQuery })
            .fontSize(TITLE_MEDIUM).fontColor(this.themeColorTextSecondary).placeholderColor(this.themeColorTextTertiary)
            .backgroundColor(Color.Transparent).layoutWeight(1)
            .enterKeyType(EnterKeyType.Search)
            .onChange((value: string) => this.searchQuery = value)
            // G-20：上游 BookshelfScreen.kt:602-606 提交后跳全局搜索
            // （`rawQuery.trim().takeIf{ it.isNotEmpty() }?.let(onNavigateToSearch)`）。
            .onSubmit((_enterKey: EnterKeyType, _event: SubmitEvent) => {
              const raw = this.searchQuery.trim();
              if (raw.length > 0) { this.onSearch(); }
            })
          if (this.searchQuery.length > 0) {
            AppGlyph({ name: 'profileClose', glyphSize: 14 }).margin({ left: 6 })
              .onClick(() => { this.searchQuery = ''; })
              .accessibilityText('清除')
          }
        }.width('100%').padding({ left: 14, right: 14, top: 9, bottom: 9 })
          .margin({ left: 16, right: 16, bottom: 10 }).backgroundColor(this.themeAppBackground.length > 0 ? Color.Transparent : (this.themePureBlack ? '#121212' : this.themeColorSurfaceElevated)).borderRadius(22).backgroundImage(this.themeItemBackground.length > 0 ? `file://${this.themeItemBackground}` : $r('app.media.transparent_pixel'), ImageRepeat.NoRepeat)
          .transition(TransitionEffect.OPACITY.combine(TransitionEffect.scale({ x: 1, y: 0.6 })).animation({ curve: curves.springMotion(0.3, 0.85) }))
      }

      // 分组样式为「文件夹」时：根层显示分组卡片，点进分组后顶部给一条返回入口。
      if (this.layout.bookGroupStyle === 2) {
        Row() {
          if (this.folderViewGroup.length > 0) {
            Text('‹ 返回文件夹').fontSize(BODY_SMALL).fontColor(this.themeColorAccent).padding(6)
              .onClick(() => { this.backToFolderRoot(); })
          }
          Text(this.folderViewGroup.length > 0 ? `当前分组：${this.folderViewGroup}` : '文件夹（点卡片进入分组）')
            .fontSize(BODY_SMALL).fontColor(this.themeColorTextTertiary).layoutWeight(1)
        }.width('100%').padding({ left: 16, right: 16, bottom: 10 })
      } else if (this.layout.bookGroupStyle === 0) {
        // 分组样式为「隐藏页签」时不渲染顶部筛选栏，切换分组改由分组管理面板完成。
        Row() {
          Scroll() {
            Row() {
              ForEach(this.getGroupNames(), (groupName: string) => {
                ShelfFilter({ label: groupName, selected: this.activeFilter() === groupName })
                  .onClick(async () => { await this.selectGroup(groupName); })
              }, (groupName: string) => groupName)
            }
          }.layoutWeight(1).scrollable(ScrollDirection.Horizontal).scrollBar(BarState.Off)
            // Scroll 的内容区默认居中（实测单个分组时 Text 落在 x=535 而不是 x=0）。
            // 上游 PrimaryScrollableTabRow 是从左往右排，这里显式靠左。
            .align(Alignment.Start)
          if (this.layout.showBookshelfTabMenu) {
            // 上游 BookshelfScreen.kt:809-821 是 SmallToggleButton(ToggleStyle.Outlined)：
            // 描边 1dp、未选中前景 onSurfaceVariant。本地补一条描边，形态从「裸图标」变成「描边按钮」。
            Stack({ alignContent: Alignment.Center }) { AppGlyph({ name: 'list', glyphSize: 18 }) }
              .width(34).height(34).backgroundColor(this.themeAppBackground.length > 0 ? Color.Transparent : (this.themePureBlack ? '#121212' : this.themeColorSurfaceElevated)).borderRadius(17)
              .border({ width: 1, color: this.themeColorTextSecondary })
              .onClick(() => { this.groupFilterVisible = !this.groupFilterVisible; })
              .accessibilityText('分组管理')
              .bindPopup(this.groupFilterVisible, {
                builder: this.GroupFilterMenu,
                placement: Placement.Bottom,
                popupColor: '#00000000',
                enableArrow: false,
                autoCancel: true,
                width: SHELF_MENU_WIDTH,
                onStateChange: (event: PopupStateChangeParam) => { this.groupFilterVisible = event.isVisible; }
              })
          }
        // 整栏内边距对齐上游 adaptiveHorizontalPaddingTab()：material 引擎下 start 0 / end 16
        // （AdaptivePadding.kt:19-20）。每项的 8 由 ShelfFilter 自己出（AppTabRow.kt:91）。
        //
        // 但 start 取 8 而不是上游的 0：上游第一个分组文字距屏幕左缘只有 8dp（Tab 自带的
        // padding），而顶栏标题是 M3 的 16dp 起始内边距，两者本来就差 8dp。本地视觉上表现为
        // 分组比标题「凸出去」一截，所以给整栏补上这 8，让首项文字左缘与标题左缘落在同一条竖线上。
        }.width('100%').padding({ left: 8, right: 16, bottom: 14 })
      } else {
        Row() {
          Text(`当前分组：${this.activeFilter()}`).fontSize(BODY_SMALL).fontColor(this.themeColorTextTertiary).layoutWeight(1)
          Text('切换分组').fontSize(BODY_SMALL).fontColor(this.themeColorAccent).padding(6)
            .onClick(() => { this.groupFilterVisible = !this.groupFilterVisible; })
            .bindPopup(this.groupFilterVisible, {
              builder: this.GroupFilterMenu,
              placement: Placement.Bottom,
              popupColor: '#00000000',
              enableArrow: false,
              autoCancel: true,
              width: SHELF_MENU_WIDTH,
              onStateChange: (event: PopupStateChangeParam) => { this.groupFilterVisible = event.isVisible; }
            })
        }.width('100%').padding({ left: 16, right: 16, bottom: 10 })
      }
      if (this.selectionMode) {
        // 选择模式工具条（:142-144 / :146 / :148）。
        Row() {
          // E-9：底栏最左是关闭图标按钮（上游 BookshelfScreen.kt:1208-1219
          // TextCard(Close, surfaceContainerHighest, cornerRadius=16) → exitEditMode）。
          Row() {
            AppGlyph({ name: 'profileClose', glyphSize: 18, tint: this.themeColorTextPrimary })
          }
          .width(32).height(32).borderRadius(16)
          .backgroundColor(this.themeColorSurfaceElevated)
          .justifyContent(FlexAlign.Center)
          .accessibilityText('关闭')
          .onClick(() => this.clearSelection())
          // E-10：上游底栏是「已选 N 本 · 共 M 本」双计数
          // （BookshelfScreen.kt:1221-1236，bookshelf_selected_count + bookshelf_total_count），
          // 本地原先只有已选数，补上本组总数。
          Text(`已选 ${this.selectedBookKeys.size} 本 · 共 ${this.getVisibleBooks().length} 本`)
            .fontSize(BODY_SMALL)
            .fontColor(this.themeColorTextPrimary).layoutWeight(1)
          // G-1/G-2/G-4/G-5/G-6：全选/反选/下载/移组/私密/删除已移到顶栏 actions
          // （上游 BookshelfScreen.kt:609-681），底栏只留关闭 + 双计数 + 组名 chip
          // （上游 :1199-1255 的 NormalCard 内容）。
          // E-11：底栏组名 chip（上游 BookshelfScreen.kt:1238-1253
          // TextCard(summary.groupName, cornerRadius=16) → GroupMenu），点开分组菜单。
          Text(this.activeFilter()).fontSize(LABEL_SMALL).fontColor(this.themeColorTextSecondary)
            .padding({ left: 10, right: 10, top: 4, bottom: 4 })
            .backgroundColor(this.themeColorSurfaceElevated).borderRadius(16)
            .onClick(() => { this.selectionGroupVisible = !this.selectionGroupVisible; })
            .bindPopup(this.selectionGroupVisible, {
              builder: this.SelectionGroupMenu,
              placement: Placement.Bottom,
              popupColor: '#00000000',
              enableArrow: false,
              autoCancel: true,
              width: SHELF_MENU_WIDTH,
              onStateChange: (event: PopupStateChangeParam) => { this.selectionGroupVisible = event.isVisible; }
            })
        }.width('100%').padding({ left: 16, right: 12, bottom: 8 })
      }
      if (this.layout.bookGroupStyle === 2 && this.folderViewGroup.length === 0) {
        // 文件夹根层：分组卡片网格，列数按横竖屏各取一套（KI-SL-C2）。
        Grid(this.folderScroller) {
          ForEach(this.getFolderGroups(), (groupName: string) => {
            GridItem() {
              BookGroupCard({
                groupName: groupName,
                books: this.getFolderPreviewBooks(groupName),
                coverCount: this.layout.bookshelfGroupCoverCount,
                listStyle: this.layout.bookshelfGroupListStyle,
                coverSettings: this.coverSettings,
                isNight: this.readerNightMode,
                listCoverWidth: this.layout.bookshelfListCoverWidth,
                showCount: this.layout.showBookCount,
                // :384 分组卡封面阴影：书架布局开关的直接消费点。
                coverShadow: this.layout.bookshelfCoverShadow,
                showDivider: this.layout.bookshelfShowDivider,
                // 私密分组锁定态（:257）：锁定时不画预览、不显示计数、组名旁加锁图标。
                locked: this.isGroupLocked(groupName),
                onOpen: () => { this.openFolderGroup(groupName); },
                // 长按分组卡直接进该分组的编辑面板（:107，上游 GroupEditSheet 入口）。
                onLongPress: (name: string) => {
                  const target = this.groups.find((item: BookGroup) => item.groupName === name);
                  if (target !== undefined) { this.openGroupEditor(target); }
                }
              })
            }
          }, (groupName: string) => `folder_${groupName}_${this.getFolderPreviewBooks(groupName).length}_${this.layout.bookshelfGroupCoverCount}_${this.layout.bookshelfGroupListStyle}_${this.activeLayoutMode()}`)
        }.edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
        .columnsTemplate(this.folderColumnsTemplate())
        .rowsGap(this.gridGap()).columnsGap(this.gridGap()).width('100%')
        .padding({
          left: this.gridHorizontalPadding(), right: this.gridHorizontalPadding(),
          bottom: this.raisedBottomInset()
        })
        .layoutWeight(1).scrollBar(BarState.Off)
      } else if (this.activeGroupLocked()) {
        this.PrivateGroupLockedPanel()
      } else if (this.bookshelfData.totalCount() > 0) {
        // 下拉刷新只包「卡片滚动区」这一层：包整个 Column 的话顶栏会跟着一起下移。
        // 是否可刷由 canPullRefresh() 现算（编辑态/分组开关都会变，不能缓存）。
        Refresh({
          refreshing: this.pullRefreshing,
          builder: () => { this.pullIndicatorBuilder(); }
        }) {
        // 与首页同一处理：Grid 上的 `.position({ x: 0, y: 0 })`（见链首）钉住内容层，
        // 下拉只出指示器，内容不跟着手指走（refresh.d.ts:100-104）。
        Grid(this.bookshelfScroller) {
          // :154：LazyForEach 只创建视口内 + cachedCount 的项，ForEach 是首帧全量建。
          LazyForEach(this.bookshelfData, (book: Book) => {
            GridItem() {
              Stack({ alignContent: Alignment.TopEnd }) {
              Column() {
                if (this.activeLayoutMode() === 0) {
                  // 列表模式卡片：左封面右信息（上游 BookItem.kt:846 BookshelfListItem）。
                  // 封面宽度只认 bookshelfListCoverWidth；网格封面宽度不参与本分支。
                  Column() {
                    Row() {
                      // B-2/C-4：上游 `BookItem.kt:200` 是 `Box(Modifier.width(coverWidth.dp))`，
                      // 里面 `:271-273` 再套 `Box(Modifier.padding(4.dp).fillMaxWidth().aspectRatio(5f/7f))`。
                      // 所以封面盒宽 = 设置值、总高按 5:7 由盒宽推导，图片本身比盒小 8vp（左右各 4）。
                      Column() {
                        BookCover({
                        book: book,
                        compact: true,
                        showChapterBadge: true,
                        // A-5/C-3：上游 `BookItem.kt:275` 封面 `.clip(RoundedCornerShape(4.dp))`，
                        // `:274` 阴影也是 `RoundedCornerShape(4.dp)`。ArkUI 的 `.shadow()` 形状
                        // 跟随组件 borderRadius，所以这里显式给 4，阴影圆角才与上游一致。
                        cornerRadius: 4,
                        shadowEnabled: this.layout.bookshelfCoverShadow,
                        // 盒内填满：宽度高度都交给外层盒子定，见下方 .width/.aspectRatio/.padding。
                        fillWidth: true,
                        maxWidth: 0,
                        coverSettings: this.coverSettings,
                        isNight: this.readerNightMode,
                        // 更新目录进度线画在封面底部（上游 BookItem.kt:782 的
                        // `isUpdating = isUpdating && !locked`：锁定态不显示进度）。
                        isUpdating: this.refreshingOf(book) && !this.isBookLocked(book),
                        // 私密书封面盖一层锁遮罩（:325）。
                        locked: this.isBookLocked(book),
                        // 共享元素源端（上游 BookItem.kt:797 同一位置）。
                        sharedKey: this.sharedCoverKeyOf(book),
                        a11yText: this.a11yLabelOf(book)
                        })
                      }.width(this.layout.bookshelfListCoverWidth)
                        .aspectRatio(5 / 7)
                        .padding(4)
                      Column() {
                        // 1) 书名行 + 行末未读徽标（上游 BookItem.kt:210-221）
                        Row({ space: 0 }) {
                          Text(this.isBookLocked(book) ? '' : book.title)
                            .fontSize(this.bookshelfTitleFontSize())
                            .fontColor(this.themeColorTextSecondary)
                            .maxLines(this.layout.bookshelfTitleMaxLines)
                            .textOverflow({ overflow: TextOverflow.Ellipsis })
                            .layoutWeight(1)
                            .textAlign(this.layout.bookshelfTitleCenter ? TextAlign.Center : TextAlign.Start)
                          // B-7：上游 `:853-864` 的 TextCard（iconSize 12、圆角 4、水平内边距 4、垂直 0，
                          // 底色 cardContainer、字色 onCardContainer），外层 `:220` 再给 top/start 各 4dp。
                          if (!this.isBookLocked(book) && this.unreadTextOf(book).length > 0) {
                            Row({ space: 4 }) {
                              if (this.showBadgeDotOf(book)) {
                                AppGlyph({ name: 'profileRefresh', glyphSize: 12, tint: this.themeColorOnCardContainer })
                              }
                              Text(this.unreadTextOf(book))
                                .fontSize(LABEL_SMALL_EMPHASIZED).fontWeight(FontWeight.Medium)
                                .fontColor(this.themeColorOnCardContainer)
                                .maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
                            }.padding({ left: 4, right: 4, top: 0, bottom: 0 })
                              .backgroundColor(this.themeColorCardContainer).borderRadius(4)
                              .margin({ top: 4, left: 4 })
                          }
                        }.width('100%').alignItems(VerticalAlign.Top)
                        // 2) 作者行（上游 `:865-869` 的 subTitle，渲染在 `:222-229`，bodySmall 单行）
                        if (!this.isBookLocked(book)) {
                          Text(this.authorLineOf(book))
                            .fontSize(BODY_SMALL).fontColor(this.themeColorTextTertiary)
                            .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
                            .width('100%').textAlign(TextAlign.Start)
                        }
                        // 3) 当前阅读章（上游 `:870` 的 desc = durChapterTitle，本地字段是 lastChapter），
                        //    上游 `:230` 只在非精简模式渲染。
                        if (!this.isBookLocked(book) && !this.layout.bookshelfLayoutCompact
                          && book.lastChapter.length > 0) {
                          Text(book.lastChapter)
                            .fontSize(LABEL_SMALL_EMPHASIZED).fontColor(this.themeColorTextTertiary)
                            .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
                            .width('100%').textAlign(TextAlign.Start)
                        }
                        // 4) 更新时间 + 最新章节（上游 `:924-940` 的 extra，同一 Row，半透明 onSurface）
                        if (!this.isBookLocked(book) && this.showsListDetails()
                          && this.layout.bookshelfShowLatestChapter) {
                          Row({ space: 4 }) {
                            if (this.layout.showLastUpdateTime && !book.isLocal
                              && book.latestChapterTime !== undefined) {
                              Text(toTimeAgo(book.latestChapterTime))
                                .fontSize(LABEL_SMALL_EMPHASIZED).fontColor(this.themeColorOnSurface)
                                .opacity(0.5).margin({ right: 4 })
                            }
                            if ((book.latestChapterTitle ?? '').length > 0) {
                              Text(book.latestChapterTitle ?? '')
                                .fontSize(LABEL_SMALL_EMPHASIZED).fontColor(this.themeColorOnSurface)
                                .opacity(0.5).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
                                .layoutWeight(1)
                            }
                          }.width('100%')
                        }
                        // 5) 标签行 + 简介（上游 `:912-924` 的 columnContent，整块受 locked 与 showListDetails 控制）
                        if (!this.isBookLocked(book) && this.showsListDetails()) {
                          this.BookTagRow(book)
                          if (this.hasIntroOf(book) && !this.layout.bookshelfListIntroBelowContent) {
                            Text(this.introTextOf(book))
                              .fontSize(BODY_SMALL).fontColor(this.themeColorOnSurfaceVariant)
                              .maxLines(this.introMaxLines()).textOverflow({ overflow: TextOverflow.Ellipsis })
                              .width('100%').textAlign(TextAlign.Start)
                              .padding({ top: 4, bottom: 4 })
                          }
                        }
                      }.layoutWeight(1).alignItems(HorizontalAlign.Start)
                        // B-4：上游 `BookItem.kt:204-209`
                        // `Column(Modifier.weight(1f).padding(top=4, bottom=4, end=8, start=4), verticalArrangement = Center)`。
                        .padding({ left: 4, right: 8, top: 4, bottom: 4 })
                        .justifyContent(FlexAlign.Center)
                    }.width('100%')
                      // 封面垂直居中（上游 BookItem.kt:194 的 bookshelfListCoverCenter）。
                      .alignItems(this.layout.bookshelfListCoverCenter ? VerticalAlign.Center : VerticalAlign.Top)
                    // G-5：简介铺在卡片底部（上游 BookItem.kt:927-941 的 bottomContent）——
                    // 外面是 `GlassCard(Modifier.padding(all = 4.dp), cornerRadius = 4.dp, containerColor = cardContainer)`，
                    // 里面 `BookItemIntro(Modifier.padding(horizontal = 8.dp))`，BookItemIntro 自带上下 4dp。
                    if (!this.isBookLocked(book) && this.hasIntroOf(book)
                      && this.layout.bookshelfListIntroBelowContent) {
                      Column() {
                        Text(this.introTextOf(book))
                          .fontSize(BODY_SMALL).fontColor(this.themeColorOnSurfaceVariant)
                          .maxLines(this.introMaxLines()).textOverflow({ overflow: TextOverflow.Ellipsis })
                          .width('100%').textAlign(TextAlign.Start)
                          .padding({ left: 8, right: 8, top: 4, bottom: 4 })
                      }.width('100%')
                        .backgroundColor(this.themeColorCardContainer)
                        .borderRadius(4)
                        .margin(4)
                    }
                    // 列表卡片之间的细横线（上游 BookItem.kt:253-260 的 HorizontalDivider，0.5dp、水平留白 16dp）。
                    if (this.layout.bookshelfShowDivider) {
                      Column() {
                        Divider().strokeWidth(0.5).color(this.themeColorTextTertiary).opacity(0.5).width('100%')
                      }.width('100%').padding({ left: 16, right: 16 })
                    }
                  }.width('100%')
                    // C-5：列表卡上下各留 4dp（上游 BookItem.kt:178-182
                    // `NormalCard(modifier.fillMaxWidth().padding(vertical = 4.dp))`）。
                    .padding({ top: 4, bottom: 4 })
                } else {
                Stack({ alignContent: Alignment.Bottom }) {
                  // A-9/C-4：上游 `BookItem.kt:107` 的 `Column(Modifier.width(coverWidth.dp))`
                  // 内再套 `:271-273` 的 `Box(padding(4.dp).fillMaxWidth().aspectRatio(5f/7f))`。
                  Column() {
                    BookCover({
                    book: book,
                    compact: true,
                    showChapterBadge: false,
                    // A-5/C-3：同列表分支，封面圆角与阴影形状都固定 4（上游 BookItem.kt:274-275）。
                    cornerRadius: 4,
                    // 上游 BookItem.kt:792 `badgeText = if (locked) null else ...`：
                    // 锁定态不显示未读角标，否则未读数是真实信息泄漏。
                    badgeText: this.isBookLocked(book) ? '' : this.unreadTextOf(book),
                    showBadgeDot: this.isBookLocked(book) ? false : this.showBadgeDotOf(book),
                    // I-1：左下角标签 = 搜索命中书源名 ?: 类型标签（上游 BookItem.kt:794）；
                    // 锁定态整块不显示（`:794` 的 `if (locked) null`）。
                    leftBottomText: this.isBookLocked(book) ? ''
                      : (this.matchedSourceLabelOf(book).length > 0
                        ? this.matchedSourceLabelOf(book) : this.bookTypeLabel(book)),
                    shadowEnabled: this.layout.bookshelfCoverShadow,
                    // 盒内填满：宽高由外层盒子（设置值 × 5:7）决定。
                    fillWidth: true,
                    maxWidth: 0,
                    coverSettings: this.coverSettings,
                    isNight: this.readerNightMode,
                    // 更新目录进度线画在封面底部（上游 BookItem.kt:782 `isUpdating && !locked`）。
                    isUpdating: this.refreshingOf(book) && !this.isBookLocked(book),
                    // 私密书封面盖一层锁遮罩（:325）。
                    locked: this.isBookLocked(book),
                    // 共享元素源端（上游 BookItem.kt:797 同一位置）。
                    sharedKey: this.sharedCoverKeyOf(book),
                    a11yText: this.a11yLabelOf(book)
                    })
                  }.width(this.gridCoverColumnWidth())
                    .aspectRatio(5 / 7)
                    .padding(4)
                  if (this.layout.bookshelfGridLayout === 1) {
                    // 紧凑样式：书名移进封面内底部，白字配渐变黑底（上游 BookItem.kt:110-133）
                    Text(this.isBookLocked(book) ? '' : book.title)
                      .fontSize(this.bookshelfTitleFontSize()).fontColor('#FFFFFFFF')
                      .maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
                      .width('100%')
                      .textAlign(this.layout.bookshelfTitleCenter ? TextAlign.Center : TextAlign.Start)
                      .padding({ left: 4, right: 4, top: 14, bottom: 4 })
                      .linearGradient(this.coverTitleGradient())
                  }
                }.width(this.gridCoverColumnWidth())
                if (this.layout.bookshelfGridLayout === 0) {
                  // 上游 BookItem.kt:135-146：网格卡（gridStyle 0）只有封面 + 书名两样，
                  // 作者 / 类型标签 / 更新时间 / 标签行都只在列表模式（BookshelfListItem）里出现。
                  // 改前这四行也画在网格卡上，所以本地网格卡比上游多四行。
                  Text(this.isBookLocked(book) ? '' : book.title)
                    .fontSize(this.bookshelfTitleFontSize()).fontColor(this.themeColorTextSecondary)
                    .maxLines(this.layout.bookshelfTitleMaxLines)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                    .width(this.gridCoverColumnWidth())
                    .textAlign(this.layout.bookshelfTitleCenter ? TextAlign.Center : TextAlign.Start)
                    .padding({ left: 4, right: 4, bottom: 4 })
                }
                }
              }.width('100%').alignItems(HorizontalAlign.Center)
                .backgroundColor(this.cardContainerColorOf(book))
                .borderRadius(this.cardCornerOf())
                // H-7/I-5：整卡作为一个无障碍节点，对齐上游 `BookItem.kt:282-287`
                // `semantics(mergeDescendants = true) { contentDescription = label;
                // role = Role.Button; if (isSelected) selected = true }`。
                // group 之后子节点（封面/书名/角标）不再单独聚焦，读屏只念这一整段。
                .accessibilityGroup(true)
                .accessibilityRole(AccessibilityRoleType.BUTTON)
                .accessibilitySelected(this.selectionMode && this.isBookSelected(book))
                .accessibilityText(this.a11yLabelOf(book))
                // 按下轻缩：书卡面积大，0.96 只缩 4%，比 LIGHT 默认的 0.9 克制。
                // 不用 stateStyles 换底色——卡片底色由封面/主题决定，换色会盖掉卡片自身的层次。
                .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.96 })
                .onClick(() => {
                  // 选择模式下点击=切换选中，不打开书（:142 验收第 12 条）。
                  if (this.selectionMode) { this.toggleBookSelection(book); return; }
                  // 锁着的私密书不进阅读器，先验密码（:325 的「打开前校验」）。
                  if (this.isBookLocked(book)) {
                    this.requestPrivateUnlock(this.privateGroupIdOf(book), this.bookKey(book));
                    return;
                  }
                  if (BookRepository.isBodyMissing(book)) {
                    this.onOpenBookInfo(book);
                  } else {
                    // 带上共享元素键：上游 BookshelfScreen.kt:1778 算完键后一路传到阅读页。
                    this.onOpenBook(book, this.sharedCoverKeyOf(book));
                  }
                })
                // 手动排序下 Grid 的 onMove 拖拽同样靠长按启动，卡片这层必须先让位：
                // onGestureJudgeBegin 在判定阶段否决卡片长按，拖拽才能交给父级 Grid。
                // 其它排序方式 Grid 不启用 editMode，长按仍是「进详情」，行为不变。
                .onGestureJudgeBegin((info: GestureInfo, _event: BaseGestureEvent): GestureJudgeResult => {
                  if (this.canReorderBooks() && info.type === GestureControl.GestureType.LONG_PRESS_GESTURE) {
                    return GestureJudgeResult.REJECT;
                  }
                  return GestureJudgeResult.CONTINUE;
                })
                .gesture(LongPressGesture({ duration: 500 }).onAction((_event: GestureEvent): void => {
                  if (this.selectionMode) { this.toggleBookSelection(book); return; }
                  if (this.isBookLocked(book)) {
                    this.requestPrivateUnlock(this.privateGroupIdOf(book), this.bookKey(book));
                    return;
                  }
                  this.onOpenBookInfo(book);
                }))
              if (this.selectionMode) {
                // 勾选圈样式照 CatalogPage.ets:648-660：18×18 圆、选中底 #C4D1FF、1.5 边框。
                Stack({ alignContent: Alignment.Center }) {
                  Column().width(18).height(18).borderRadius(9)
                    .backgroundColor(this.isBookSelected(book) ? '#C4D1FF' : '#00000000')
                    .border({ width: 1.5, color: this.isBookSelected(book) ? '#C4D1FF' : '#7A7D88' })
                  if (this.isBookSelected(book)) {
                    AppGlyph({ name: 'profileCheck', glyphSize: 12, tint: '#1A1B21' })
                  }
                }.width(26).height(26).margin({ top: 4, right: 4 })
              }
              }
            }
          }, (book: Book) => this.bookCardKey(book))
            // H-3/H-4：`DynamicNode.onMove` 的第二个参数是 `ItemDragEventHandler`
            // （common.d.ts:25770-25799，@since 20；本项目 compatibleSdkVersion 6.0.0(20)），
            // 提供 onLongPress / onDragStart / onMoveThrough / onDrop 四个回调，
            // 正好承载上游 `longPressDraggableHandle` 的 onDragStarted / onDragStopped 与
            // `rememberReorderableLazyGridState` 的跨位 tick。
            .onMove((from: number, to: number) => {
              // 拖拽重排只在「手动」排序下看得见效果（:138）。
              this.moveDragging(from, to);
            }, {
              onDragStart: (_index: number): void => {
                this.startDragging();
                UiHaptics.dragThresholdActivate();
              },
              onMoveThrough: (_from: number, _to: number): void => {
                UiHaptics.dragTick();
              },
              onDrop: (_index: number): void => {
                UiHaptics.dragEnd();
                this.finishDragging();
              }
            })
        }.position({ x: 0, y: 0 })
        .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
        .columnsTemplate(this.bookshelfColumnsTemplate())
        .rowsGap(this.gridGap()).columnsGap(this.gridGap()).width('100%')
        .padding({
          left: this.gridHorizontalPadding(), right: this.gridHorizontalPadding(),
          bottom: this.raisedBottomInset()
        })
        // C-7：预加载条数按上游 BookshelfCoverPreloader 口径（网格 cols*5 上限 24 / 列表 10），
        // LazyForEach 只建「视口 + cachedCount」的项，视口外这些卡的封面会提前进入加载队列。
        .cachedCount(this.coverCacheCount())
        .scrollBar(this.layout.showBookshelfFastScroller ? BarState.On : BarState.Off)
          // editMode(true) 是 ForEach.onMove 生效的前提，与分组网格同一套写法（:138）。
          .editMode(this.canReorderBooks())
          .onAreaChange((_oldArea: Area, newArea: Area) => {
            // 记下网格可用宽度，封面宽度按格子宽度换算（见 bookshelfCoverSlotWidth）
            const width = parseFloat(String(newArea.width));
            const height = parseFloat(String(newArea.height));
            if (Number.isFinite(width) && Math.abs(width - this.bookshelfGridWidth) > 0.5) {
              this.bookshelfGridWidth = width;
            }
            // 旋转会改变容器宽高，这里再兜底刷新一次方向（窗口尺寸回调之外的第二道保险）。
            if (Number.isFinite(width) && Number.isFinite(height)) {
              const landscape: boolean = width > height;
              if (landscape !== this.isLandscape) { this.isLandscape = landscape; }
            }
          })
          .onScroll(() => {
            // F-4/F-5：折叠阈值与方向对齐其余 19 页的 UiTokens 口径（收 70 / 展 24），
            // 双向滞回：超过 70 折叠、回落到 24 以下展开、中间区间保持原状。
            const yOffset = Math.abs(this.bookshelfScroller.currentOffset().yOffset);
            const shouldCollapse = yOffset > HEADER_COLLAPSE_THRESHOLD
              ? true
              : (yOffset < HEADER_EXPAND_THRESHOLD ? false : this.collapsedHeader);
            if (this.collapsedHeader !== shouldCollapse) {
              // 顶部折叠是位移，用弹簧收尾更自然；弹簧不吃 duration，删掉（写了也不生效）。
              this.getUIContext().animateTo({ curve: curves.springMotion(0.35, 0.86) }, () => {
                this.collapsedHeader = shouldCollapse;
              });
            }
          })
        }
        // refreshOffset 与 HomePage.ets:305 保持一致（promptText 未设时默认也是 64vp）。
        .onRefreshing(() => { this.handlePullRefresh(); })
        // RefreshStatus 的 OverDrag 就是「已拉过阈值、松手会刷」，用它换指示器图标。
        .onStateChange((state: RefreshStatus) => {
          const armed = state === RefreshStatus.OverDrag;
          if (armed !== this.pullArmed) { this.pullArmed = armed; }
        })
        .pullToRefresh(this.canPullRefresh())
        .refreshOffset(64)
        // 与首页同一口径：内容层被 position 钉住，跟着下拉走的只有指示器，
        // 所以比例要 1（完全跟手），压小会让能拉的距离也变短。
        .pullDownRatio(1)
        // 与首页同口径：指示器最多下移 120vp。
        .maxPullDownDistance(120)
        // 每帧报当前下拉距离（vp），喂给指示器做跟手旋转。
        .onOffsetChange((offset: number) => {
          this.pullOffsetValue = offset;
        })
        .layoutWeight(1)
      } else {
        // D-2/D-4/D-5：照上游 BookshelfScreen.kt:1670-1696——只有两态（搜索态 / 非搜索态），
        // 无表情轮换、无「这个分组还没有书籍」第三分支；文案用上游 zh-rCN 原文。
        Column() {
          Text(this.searchQuery.length > 0
            ? '没有书籍，尝试全局搜索'
            : '书架还空着，先去搜索书籍或从发现里添加吧！')
            .width(220).fontSize(LABEL_SMALL).fontColor(this.themeColorTextSecondary).textAlign(TextAlign.Center).maxLines(2)
          if (this.searchQuery.length > 0) {
            Text('全局搜索').fontSize(LABEL_MEDIUM).fontColor(this.themeColorAccent)
              .padding({ left: 16, right: 16, top: 8, bottom: 8 }).margin({ top: 14 })
              .backgroundColor(this.themeAppBackground.length > 0 ? Color.Transparent : (this.themePureBlack ? '#121212' : this.themeColorSurfaceElevated))
              .borderRadius(18)
              .onClick(() => this.onSearch())
          }
        }.layoutWeight(1).width('100%').padding({ bottom: 120 }).justifyContent(FlexAlign.Center)
      }
    }.width('100%').height('100%').backgroundColor(this.themeAppBackground.length > 0 ? Color.Transparent : (this.themePureBlack ? '#000000' : this.themeColorSurfacePrimary))
      .bindSheet(this.showGroupManager || this.showLayoutSheet || this.showLogSheet || this.showTagColorPage || this.showMoveGroupSheet || this.showTagRuleEdit || this.showAiAutoGroup || this.showImportSheet || this.showExportSheet, this.ShelfSheetContent(), {
        height: SheetSize.LARGE, dragBar: true, showClose: false, backgroundColor: this.themeColorSurfaceTertiary,
        onDisappear: () => { this.showMoveGroupSheet = false; this.showGroupManager = false; this.showLayoutSheet = false; this.showLogSheet = false; this.showTagColorPage = false; this.showTagColorPicker = false; this.showRulePasteAuthorization = false; this.showTagRuleEdit = false; this.tagRuleMenuVisible = false; this.showRulePasteAuthorization = false; this.showAiAutoGroup = false; this.aiMoveMenuKey = ''; this.showGroupEditor = false; this.showImportSheet = false; this.showExportSheet = false; }
      })

      // 全屏加载态（:156）。上游 BookshelfScreen.kt:1575-1602 是一层不可取消的 Dialog，
      // 本地不走 CustomDialog（全仓零先例），改成页面内遮罩：同样的视觉，同样的不可取消。
      if (this.busyText.length > 0) {
        Column() {
          Column() {
            LoadingProgress().width(40).height(40).color(this.themeColorAccent)
            Text(this.busyText).fontSize(LABEL_MEDIUM).fontColor(this.themeColorTextSecondary)
              .margin({ top: 16 }).textAlign(TextAlign.Center).maxLines(2)
          }
          .padding(24).borderRadius(12)
          .backgroundColor(this.themeColorSurfaceElevated)
          .alignItems(HorizontalAlign.Center).constraintSize({ maxWidth: 260 })
        }
        .width('100%').height('100%')
        .justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
        .backgroundColor('#66000000')
        // 吃掉点击：不加这一行，手指会穿到底下的卡片上把书打开。
        // 也不要写成 onClick(() => this.busyText = '')——上游那个对话框不可取消。
        // 光有 onClick 不够：实测遮罩期间点空白区域仍会穿透到下层书卡，
        // HitTestMode.Block 让这一层自己独占命中测试，事件不再往下分发。
        .hitTestBehavior(HitTestMode.Block)
        .onClick(() => {})
        .transition(TransitionEffect.OPACITY.animation({ duration: 160, curve: Curve.EaseInOut }))
      }
    }
    .width('100%').height('100%')
  }
}

@Component
struct ShelfFilter {
  @StorageProp('themeColorAccent') themeColorAccent: string = '#3F5BD9';
  @StorageProp('themeColorTextSecondary') themeColorTextSecondary: string = '#2E3038';
  @Prop label: string = '';
  @Prop selected: boolean = false;
  build() {
    // 上游 AppTabRow.kt:88-92：labelLargeEmphasized = 14sp Medium、maxLines 1 + Ellipsis，
    // 颜色 if (selected) primary else onSurfaceVariant。本地对应 themeColorAccent / themeColorTextSecondary。
    //
    // 选中指示器用 Text 自己的底边描边，不用另起一个 Row：
    // 描边宽度 = 文字宽 + 左右各 8 的内边距，正好等于 material3 Tab 的宽度（指示器跟 Tab 同宽）。
    // 改前是 Column 里一个 `Row().width('100%')`，而 Column 在横向 Scroll 里拿到的约束是视口宽，
    // 于是下划线撑满整屏、文字被居中 —— 这才是「分组居中 + 大片空白」的真身。
    Text(this.label)
      .fontSize(LABEL_LARGE)
      .fontWeight(this.selected ? FontWeight.Medium : FontWeight.Normal)
      .fontColor(this.selected ? this.themeColorAccent : this.themeColorTextSecondary)
      .maxLines(1)
      .textOverflow({ overflow: TextOverflow.Ellipsis })
      .textAlign(TextAlign.Center)
      .padding({ left: 8, right: 8, top: 7, bottom: 7 })
      // material3 的 Tab 在可滚动 TabRow 里有 ScrollableTabMinWidth = 72.dp 的下限，
      // 内容不足 72 时由 Tab 居中留白 —— 这才是上游页签之间间距比本地大的原因。
      // 本地只有「文字宽 + 16」，两个分组挨得很近。这里补上同一个下限。
      .constraintSize({ minWidth: 72 })
      .border({
        width: { bottom: 2 },
        color: this.selected ? this.themeColorAccent : Color.Transparent
      })
      .animation({ duration: 180, curve: Curve.EaseInOut })
  }
}






