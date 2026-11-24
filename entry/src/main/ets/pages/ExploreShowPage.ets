// 「按给定 exploreUrl 看结果」的一页。
//
// 对齐上游 `ui/book/explore/ExploreShowScreen.kt`（564 行）+ `ExploreShowViewModel.kt`（472 行）：
// - 顶栏：返回 / 布局与列数 / 分类选择 / 页码（`canJumpPage` 为真才画）。
// - 四档过滤（`BookFilterState`，来自封面设置 `exploreFilterState`）：全显 / 隐藏书架已有 /
//   隐藏同名同作者 / 只显不在书架。
// - 列表与网格两态，网格列数按朝向各存一份；切换布局时把滚动位置带过去。
// - 滚到底自动续页；某一页被过滤空但还有数据时强制再抓一页（`ForceLoadNext`）。
// - 长按弹预览（`SearchBookPreviewSheet`）。
//
// 与上游的差别（记入 `tmp/appearance-impl-report.md` 待办账本）：
// 1. 上游 `SaveSearchBooksUseCase.save` 会把结果写进 searchBooks 表；本地搜索结果不落库，
//    没有等价仓储，这一步省略。
// 2. 上游 `LaunchedEffect` 在组合期驱动加载；本地用 `aboutToAppear` + 滚动尾行 `onAppear`。
import { display } from '@kit.ArkUI';
import { BookSource } from '@legado/sourceengine';
import { BookSource as LocalBookSource } from '../model/BookSource';
import { Book } from '../model/Book';
import { BookSourceRepository } from '../data/BookSourceRepository';
import { LegadoSourceMapper } from '../bookSource/LegadoSourceMapper';
import { CoverSettings, DEFAULT_COVER_SETTINGS } from '../data/CoverSettingsRepository';
import {
  EXPLORE_GRID_COUNT_MAX,
  EXPLORE_GRID_COUNT_MIN,
  EXPLORE_GRID_LANDSCAPE_DEFAULT,
  EXPLORE_GRID_PORTRAIT_DEFAULT,
  EXPLORE_LAYOUT_MODE_GRID,
  EXPLORE_LAYOUT_MODE_LIST,
  ExploreLayoutSettings,
  ExploreLayoutSettingsRepository
} from '../data/ExploreLayoutSettings';
import { ExploreCoordinator, ExploreOutcome } from '../bookSource/ExploreCoordinator';
import { ExploreKind, ExploreKindParser } from '../bookSource/ExploreKind';
import { supportsPageSelection } from '../bookSource/PageSelection';
import { SearchBookItem } from '../bookSource/SourceModels';
import { SearchBookRepository } from '../data/SearchBookRepository';
import { bookCoverSharedElementKey } from '../data/BookCoverSharedElement';
import {
  BookShelfState,
  SearchBookGridItem,
  SearchBookListItem
} from '../components/booksource/SearchBookItems';
import { ExploreKindSelectSheet } from '../components/booksource/ExploreKindItem';
import { LoadMoreFooter } from '../components/booksource/LoadMoreFooter';
import { SearchBookPreviewSheet } from '../components/booksource/SearchBookPreviewSheet';
import {
  BookshelfConflict,
  BookshelfConflictSheet,
  ConflictBookSummary
} from '../components/booksource/BookshelfConflictSheet';
import { ChangeSourceMigrationOptions } from '../bookSource/ChangeSourceCoordinator';
import { AppTopBar, TopBarBackButton, TopBarButton } from '../components/TopBar';
import { PullRefreshIndicator } from '../components/PullRefreshIndicator';
import { AppGlyph, AppGlyphName } from '../components/AppGlyph';
import { UiSlider } from '../components/settings/UiSlider';
import {
  BODY_SMALL,
  LABEL_LARGE,
  LABEL_MEDIUM,
  TITLE_SMALL
} from '../components/typography/TypographyTokens';
import {
  HEADER_COLLAPSE_THRESHOLD,
  HEADER_EXPAND_THRESHOLD,
  SPACE_12,
  SPACE_16,
  SPACE_4,
  SPACE_8
} from '../components/UiTokens';
import {
  combineExploreShowUiState,
  emptyExplorePageState,
  emptyExploreShowDisplayState,
  emptyExploreShowKindState,
  emptyExploreShowLoadState,
  ExploreBookItemUi,
  ExplorePageState,
  ExploreShowDisplayState,
  ExploreShowEffect,
  ExploreShowIntent,
  ExploreShowIntentKind,
  ExploreShowKindState,
  ExploreShowLoadState,
  ExploreShowSheet,
  ExploreShowUiState,
  openBookInfoEffect,
  showMessageEffect
} from '../bookSource/ExploreShowContract';

/** 一页结果条数；上游没有显式常量，靠「本页是否为空」判断到底，本地沿用发现页的 20 条口径。 */
const PAGE_SIZE: number = 20;
/** 自动续页上限，对齐上游 `ExploreShowViewModel.kt:97 MAX_AUTO_PAGES = 3`。 */
const MAX_AUTO_PAGES: number = 3;
/** 自动续页间隔，对齐上游 `ExploreShowViewModel.kt:100 AUTO_PAGE_DELAY_MS = 500L`。 */
const AUTO_PAGE_DELAY_MS: number = 500;
/** 空对象：预览面板未打开时的占位。 */
const EMPTY_BOOK: SearchBookItem = {
  bookUrl: '', origin: '', originName: '', name: '', author: '', kind: '',
  coverUrl: '', intro: '', lastChapter: '', wordCount: '', updateTime: '', tocUrl: ''
};
/** 网格左右内边距，对齐上游 `contentPadding start/end = 12.dp`。 */
const GRID_PADDING: number = 12;
/** 网格横向间隔，对齐上游 `horizontalArrangement spacedBy(4.dp)`。 */
const GRID_GAP_H: number = 4;
/** 网格纵向间隔，对齐上游 `verticalArrangement spacedBy(8.dp)`。 */
const GRID_GAP_V: number = 8;
/** 上游 `ExploreShowScreen.kt:559` 的 `padding(4.dp)`：每个网格项自己的内边距。 */
const GRID_ITEM_PADDING: number = 4;
/** 网格底部内边距，对齐上游 `bottom = bottomPadding + 12.dp`。 */
const GRID_PADDING_BOTTOM: number = 12;
/** 列表底部内边距，对齐上游 `bottom = bottomPadding + 16.dp`。 */
const LIST_PADDING_BOTTOM: number = 16;
/** 布局切换转场时长，对齐上游 `Crossfade(animationSpec = tween(250))`。 */
const LAYOUT_CROSSFADE_MS: number = 250;
/** 嵌入主界面时的底部预留，对齐上游 `embeddedInMain ? 108.dp : 12.dp`。 */
const EMBEDDED_BOTTOM_INSET: number = 108;

/**
 * 「按给定 exploreUrl 看结果」的一页。
 * 上游 `MainRouteExploreShow(title, sourceUrl, exploreUrl)`（`MainNavGraph.kt:583-591`）。
 */
@Component
export struct ExploreShowPage {
  @StorageProp('themeColorTextPrimary') themeColorTextPrimary: string = '#1B1C22';
  @StorageProp('themeColorTextSecondary') themeColorTextSecondary: string = '#4A4C55';
  @StorageProp('themeColorTextTertiary') themeColorTextTertiary: string = '#6A6D77';
  @StorageProp('themeColorAccent') themeColorAccent: string = '#3F5BD9';
  @StorageProp('themeColorSurfacePrimary') themeColorSurfacePrimary: string = '#FAF9FD';
  @StorageProp('themeColorSurfaceTertiary') themeColorSurfaceTertiary: string = '#F0F1F5';
  @StorageProp('themeColorSurfaceElevated') themeColorSurfaceElevated: string = '#FFFFFF';
  @StorageProp('themeColorOutlineVariant') themeColorOutlineVariant: string = '#C6C7D0';
  @StorageProp('themeAppBackground') themeAppBackground: string = '';
  @StorageProp('themePureBlack') themePureBlack: boolean = false;

  /** 页面标题：初始取分类标题，切分类后跟着变（上游 `state.selectedKindTitle ?: title`）。 */
  @Prop title: string = '';
  @Prop sourceUrl: string = '';
  @Prop exploreUrl: string = '';
  /**
   * 书架快照。上游 `observeBookshelf()` 是流观察，书架一变就重算每本书的 shelfState；
   * 本地是入参快照，靠 `@Watch` 复刻同一时机（见 `onShelfBooksChanged()`）。
   */
  @Prop @Watch('onShelfBooksChanged') shelfBooks: Book[] = [];
  @Prop coverSettings: CoverSettings = DEFAULT_COVER_SETTINGS;
  @Prop isNight: boolean = false;
  /** 封面设置里的探索页过滤档位（0..3，上游 `BookFilterState`）。 */
  @Prop exploreFilterState: number = 0;

  onBack: () => void = () => {};
  onOpenBook: (item: SearchBookItem) => void = () => {};
  /** 带共享元素键的跳详情（上游 `onBookClick(book, sharedCoverKey)`）。 */
  onOpenBookWithSharedKey: (item: SearchBookItem, sharedCoverKey: string) => void =
    (item: SearchBookItem, _sharedCoverKey: string) => { this.onOpenBook(item); };
  /**
   * 加架（上游 `AddToShelf` 走 `BookshelfConflictController.addToShelf`）。
   * 返回空数组表示加架成功；非空表示书架里有这些疑似同一作品的候选。
   */
  onAddToShelf: (item: SearchBookItem) => Promise<ConflictBookSummary[]> =
    (_item: SearchBookItem) => Promise.resolve([]);
  /**
   * 冲突处置：`coexist` 留两本 / `migrate` 搬进度。
   * 返回空串表示成功，非空是给用户看的错误文案。
   */
  onResolveShelfConflict: (existingBookUrl: string, incomingBookUrl: string, mode: string,
    options: ChangeSourceMigrationOptions) => Promise<string> =
    (_existingBookUrl: string, _incomingBookUrl: string, _mode: string,
      _options: ChangeSourceMigrationOptions) => Promise.resolve('');
  onUnavailableAction: (message: string) => void = () => {};
  /**
   * Effect 出口。上游这一环在 `ExploreShowRouteScreen`（`ExploreShowScreen.kt:103-119`）：
   * `LaunchedEffect(viewModel) { viewModel.effects.collect { effect -> ... } }`。
   * 默认实现就地分派，保持本页被单独挂载时的行为不变。
   */
  onEffect: (effect: ExploreShowEffect) => void =
    (effect: ExploreShowEffect) => { this.dispatchEffectLocally(effect); };

  /**
   * 结果项。上游 `ExploreShowUiState.books` 是 `ExploreBookItemUi`（书 + 书架状态），
   * 不是裸 SearchBook：书架状态在装载时就折进元素，过滤与渲染都直接读，不再每次现算。
   */
  @State books: ExploreBookItemUi[] = [];
  /** 加载状态源（上游 `ExploreShowLoadState`，:32-37）。 */
  @State loadState: ExploreShowLoadState = emptyExploreShowLoadState();
  /** 分页状态源（上游 `ExplorePageState`，:468-472）。 */
  @State pageState: ExplorePageState = emptyExplorePageState();
  /** 展示状态源（上游 `ExploreShowDisplayState`，:44-49）。 */
  @State displayState: ExploreShowDisplayState = emptyExploreShowDisplayState();
  @State gridPortrait: number = EXPLORE_GRID_PORTRAIT_DEFAULT;
  @State gridLandscape: number = EXPLORE_GRID_LANDSCAPE_DEFAULT;
  /** 分类状态源（上游 `ExploreShowKindState`，:39-42）。 */
  @State kindState: ExploreShowKindState = emptyExploreShowKindState();
  @State kindUrl: string = '';
  /** 跳页对话框（上游 `ExploreShowScreen.kt:456` 的局部 `showJumpPageDialog`，不在 UiState 里）。 */
  @State showJumpPageDialog: boolean = false;
  /** 加架冲突（上游 `ExploreShowUiState.bookshelfConflict`）。 */
  @State bookshelfConflict: BookshelfConflict | undefined = undefined;
  /** 冲突处置中（上游 `ExploreShowUiState.isResolvingBookshelfConflict`）。 */
  @State isResolvingBookshelfConflict: boolean = false;
  @State jumpInput: string = '';
  @State previewVisible: boolean = false;
  @State previewItem: SearchBookItem = EMPTY_BOOK;
  @State previewSharedKey: string = '';
  @State collapsedHeader: boolean = false;
  @State landscape: boolean = false;
  /** 下拉刷新：指示器是否已过阈值（换对勾）、当前下拉距离（vp）。 */
  @State refreshArmed: boolean = false;
  @State refreshPullOffset: number = 0;
  /**
   * 两种布局各自的首个可见项下标（上游 `listState.firstVisibleItemIndex` /
   * `gridState.firstVisibleItemIndex`）。切布局时互相同步，避免回到顶部。
   */
  @State listFirstIndex: number = 0;
  @State gridFirstIndex: number = 0;
  /** 本次切布局后要跳到的位置；-1 表示不跳。 */
  @State pendingScrollIndex: number = -1;
  /** 是否嵌入主界面（上游 `embeddedInMain`）。 */
  @Prop embeddedInMain: boolean = false;

  /**
   * 嵌入态的上内边距（上游 `embeddedPadding.calculateTopPadding()`）。
   * 独立页由 Scaffold 给，嵌入态由外部容器给，所以两套值分开传。
   */
  @Prop embeddedPaddingTop: number = 0;

  /** 嵌入态的下内边距（上游 `embeddedPadding.calculateBottomPadding()`）。 */
  @Prop embeddedPaddingBottom: number = 0;

  // ---- 四个状态源的读写口 ----
  //
  // 上游是 `_loadState.update { copy(...) }` / `_kindState.update {...}`，每次写都产
  // 一个新对象；ArkTS 的 @State 同样不跟踪对象内部字段，所以这里也一律「整对象替换」。
  // 读侧保留与上游同名的 getter，模板与逻辑里的读点不用改写法。

  /**
   * 【嵌套 struct 首帧兜底】D-2 拆分后本页作为 RouteScreen 子组件挂载，实测首次 initialRender
   * 时 @State 的 interface 状态对象可能尚未就绪（jscrash: "Cannot read property length/xxx of
   * undefined"，落点在 pageTitle / resultArea）。以下几处 getter 一律先把状态读进局部变量再
   * 逐层判空，等价于上游 Kotlin 可空字段的 `?: 默认值`；ArkTS 会把单行 getter 内联成直接属性
   * 访问、丢掉判空，所以必须写成多行局部变量形式。
   */
  /** 加载中（上游 `state.isLoading`）。 */
  private loadingOf(): boolean {
    const s: ExploreShowLoadState | undefined = this.loadState;
    return s !== undefined && s.isLoading === true;
  }

  /** 下拉刷新中（上游 `state.isRefreshing`）。 */
  private refreshingOf(): boolean {
    const s: ExploreShowLoadState | undefined = this.loadState;
    return s !== undefined && s.isRefreshing === true;
  }

  /** 已到底（上游 `state.isEnd`）。 */
  private isEndOf(): boolean {
    const s: ExploreShowLoadState | undefined = this.loadState;
    return s !== undefined && s.isEnd === true;
  }

  /** 错误文案（上游 `state.errorMsg`）。 */
  private errorMsgOf(): string {
    const s: ExploreShowLoadState | undefined = this.loadState;
    return s === undefined || s.errorMsg === undefined ? '' : s.errorMsg;
  }

  /** 当前页（上游 `state.currentPage`）。 */
  private currentPageOf(): number {
    const s: ExplorePageState | undefined = this.pageState;
    return s === undefined || s.currentPage === undefined ? 1 : s.currentPage;
  }

  /** 能否跳页（上游 `state.canJumpPage`）。 */
  private canJumpPageOf(): boolean {
    const s: ExplorePageState | undefined = this.pageState;
    return s !== undefined && s.canJumpPage === true;
  }

  /** 分类列表（上游 `state.kinds`）。 */
  private kindsOf(): ExploreKind[] {
    const s: ExploreShowKindState | undefined = this.kindState;
    return s === undefined || s.kinds === undefined ? [] : s.kinds;
  }

  /**
   * 选中分类标题（上游 `state.selectedKindTitle`）。
   * 【嵌套 struct 首帧兜底】D-2 拆分后本页作为 RouteScreen 子组件挂载，实测首次 initialRender
   * 时 @State 的 interface 对象字段可能尚未就绪（jscrash: pageTitle "Cannot read property
   * length of undefined"）。这里对字段做空安全兜底，等价于上游 Kotlin 可空 String 的 `?: ""`。
   */
  private selectedKindTitleOf(): string {
    const state: ExploreShowKindState | undefined = this.kindState;
    return state === undefined || state.selectedKindTitle === undefined ? '' : state.selectedKindTitle;
  }

  /** 布局模式（上游 `state.layoutState`）。 */
  private layoutModeOf(): number {
    const s: ExploreShowDisplayState | undefined = this.displayState;
    return s === undefined || s.layoutState === undefined ? 0 : s.layoutState;
  }

  /** 当前底部面板（上游 `state.sheet`）。 */
  private sheetOf(): ExploreShowSheet {
    const s: ExploreShowDisplayState | undefined = this.displayState;
    return s === undefined || s.sheet === undefined ? ExploreShowSheet.None : s.sheet;
  }

  /** 写加载状态：只覆盖传入的字段（上游 `_loadState.update { it.copy(...) }`）。 */
  private patchLoad(isLoading: boolean | undefined, isRefreshing: boolean | undefined,
    isEnd: boolean | undefined, errorMsg: string | undefined): void {
    const next: ExploreShowLoadState = {
      isLoading: isLoading === undefined ? this.loadState.isLoading : isLoading,
      isRefreshing: isRefreshing === undefined ? this.loadState.isRefreshing : isRefreshing,
      isEnd: isEnd === undefined ? this.loadState.isEnd : isEnd,
      errorMsg: errorMsg === undefined ? this.loadState.errorMsg : errorMsg
    };
    this.loadState = next;
  }

  /** 写分页状态。 */
  private patchPage(currentPage: number | undefined, canJumpPage: boolean | undefined): void {
    const next: ExplorePageState = {
      currentPage: currentPage === undefined ? this.pageState.currentPage : currentPage,
      canJumpPage: canJumpPage === undefined ? this.pageState.canJumpPage : canJumpPage
    };
    this.pageState = next;
  }

  /** 写分类状态。 */
  private patchKind(kinds: ExploreKind[] | undefined, selectedKindTitle: string | undefined): void {
    const next: ExploreShowKindState = {
      kinds: kinds === undefined ? this.kindState.kinds : kinds,
      selectedKindTitle: selectedKindTitle === undefined
        ? this.kindState.selectedKindTitle : selectedKindTitle
    };
    this.kindState = next;
  }

  /** 写展示状态。 */
  private patchDisplay(sourceUrl: string | undefined, layoutState: number | undefined,
    gridCount: number | undefined, sheet: ExploreShowSheet | undefined): void {
    const next: ExploreShowDisplayState = {
      sourceUrl: sourceUrl === undefined ? this.displayState.sourceUrl : sourceUrl,
      layoutState: layoutState === undefined ? this.displayState.layoutState : layoutState,
      gridCount: gridCount === undefined ? this.displayState.gridCount : gridCount,
      sheet: sheet === undefined ? this.displayState.sheet : sheet
    };
    this.displayState = next;
  }

  /**
   * 合成 UiState（上游 `combineUiState()`，:198-257）。
   * 上游由四个 flow combine 出来，本地按需现合成；`books` 与 `conflict` 直接取当前值。
   */
  private uiState(): ExploreShowUiState {
    return combineExploreShowUiState(this.loadState, this.kindState, this.displayState,
      this.books, this.pageState, this.exploreFilterState, this.bookshelfConflict,
      this.isResolvingBookshelfConflict);
  }

  /** 加载代次：切分类、刷新、跳页都自增，回来时对不上就丢弃（上游 `loadGeneration`）。 */
  private generation: number = 0;
  /** 已自动续页次数，对齐上游 `autoPageCount`。 */
  private autoPageCount: number = 0;
  private nextPage: number = 1;
  /** 触发冲突的那本书，`coexist`/`migrate` 要用它的 bookUrl（上游 `pendingBook`）。 */
  private pendingShelfBook: SearchBookItem | undefined = undefined;
  /** 重入保护（上游 `initialized`）：同一对 url 已加载过就不再重抓。 */
  private initialized: boolean = false;
  /** 已初始化时记下的 url 对，用于 `initData` 判重。 */
  private loadedSourceUrl: string = '';
  private loadedExploreUrl: string = '';

  aboutToAppear(): void {
    this.loadLayoutSettings();
    const init = this.intentOf('InitData');
    init.sourceUrl = this.sourceUrl;
    init.exploreUrl = this.exploreUrl;
    this.onIntent(init);
  }

  /**
   * 初始化（上游 `ExploreShowViewModel.initData`，:259-292）。
   * 上游的重入保护：同一对 url 已经初始化过就直接返回，不重抓。
   */
  private initData(sourceUrl: string, exploreUrl: string): void {
    if (this.initialized && this.loadedSourceUrl === sourceUrl
      && this.loadedExploreUrl === exploreUrl) {
      return;
    }
    this.initialized = true;
    this.loadedSourceUrl = sourceUrl;
    this.loadedExploreUrl = exploreUrl;
    this.kindUrl = exploreUrl;
    this.patchKind(ExploreKindParser.parseForSource(sourceUrl), '');
    this.patchPage(1, supportsPageSelection(exploreUrl));
    this.loadMore(true, false);
  }

  /** 读布局偏好（上游 `loadLayoutMode` + `loadGridCount`）。 */
  private loadLayoutSettings(): void {
    const context = this.getUIContext().getHostContext();
    const widthVp: number = this.getUIContext().px2vp(display.getDefaultDisplaySync().width);
    const heightVp: number = this.getUIContext().px2vp(display.getDefaultDisplaySync().height);
    this.landscape = widthVp > heightVp;
    if (context === undefined) { return; }
    ExploreLayoutSettingsRepository.load(context).then((settings: ExploreLayoutSettings): void => {
      this.patchDisplay(undefined, settings.layoutMode, undefined, undefined);
      this.gridPortrait = settings.gridPortrait;
      this.gridLandscape = settings.gridLandscape;
    }).catch((): void => {
      // 读失败就用默认值，界面不因此中断。
    });
  }

  /** 是否网格态（上游 `isGridMode = state.layoutState == 1`）。 */
  private isGridMode(): boolean {
    return this.layoutModeOf() === EXPLORE_LAYOUT_MODE_GRID;
  }

  /** 当前朝向该用的列数（上游 `gridCount`，横屏竖屏各存一份）。 */
  private gridCount(): number {
    return ExploreLayoutSettingsRepository.gridCountFor({
      layoutMode: this.layoutModeOf(),
      gridPortrait: this.gridPortrait,
      gridLandscape: this.gridLandscape
    }, this.landscape);
  }

  /** 网格列模板，例如 3 列 → `1fr 1fr 1fr`。 */
  private columnsTemplate(): string {
    const count = Math.min(Math.max(this.gridCount(), EXPLORE_GRID_COUNT_MIN), EXPLORE_GRID_COUNT_MAX);
    const parts: string[] = [];
    for (let index = 0; index < count; index++) { parts.push('1fr'); }
    return parts.join(' ');
  }

  /**
   * 页面标题：有选中分类就用分类标题，否则用传进来的标题。
   * 【嵌套 struct 首帧兜底】D-2 拆分后本页作为 RouteScreen 子组件挂载，实测首次 initialRender
   * 时状态源对象的字段可能尚未就绪。这里不直接读 getter（ArkTS 会把 getter 内联成属性访问、
   * 丢掉 getter 里的判空），而是先把状态读进局部变量再逐层判空；等价于上游 Kotlin 可空串的 `?: ""`。
   */
  private pageTitle(): string {
    const kind: ExploreShowKindState | undefined = this.kindState;
    const selected: string = (kind === undefined || kind.selectedKindTitle === undefined)
      ? '' : kind.selectedKindTitle;
    const fallback: string = this.title === undefined ? '' : this.title;
    return selected.length > 0 ? selected : fallback;
  }

  /** 取书源（上游 `repository.getBookSource(sourceUrl)`），转成引擎侧的 `BookSource`。 */
  private findSource(): BookSource | null {
    const all: LocalBookSource[] = BookSourceRepository.getAll();
    for (const source of all) {
      if (source.bookSourceUrl === this.sourceUrl) {
        return LegadoSourceMapper.fromLocal(source);
      }
    }
    return null;
  }

  /**
   * 续页，对齐上游 `loadMore(isRefresh, forceLoad)`：
   * 加载中、或已到底且不是刷新/强制，直接返回。
   */
  private loadMore(isRefresh: boolean, forceLoad: boolean): void {
    if (this.loadingOf()) { return; }
    if (this.isEndOf() && !isRefresh && !forceLoad) { return; }
    const source = this.findSource();
    if (source === null) {
      this.patchLoad(false, undefined, undefined,
        '找不到这本书的书源，无法继续加载');
      return;
    }
    if (this.kindUrl.length === 0) {
      // 上游 `incomingExploreUrl == null` 的路径：先列分类，让用户选。
      this.patchDisplay(undefined, undefined, undefined, ExploreShowSheet.KindSelect);
      this.patchLoad(false, undefined, undefined, undefined);
      return;
    }
    this.generation++;
    const generation = this.generation;
    this.patchLoad(true, isRefresh, (isRefresh || forceLoad) ? false : undefined, '');
    if (isRefresh) {
      this.nextPage = 1;
      this.autoPageCount = 0;
      this.books = [];
    }
    if (forceLoad) { this.autoPageCount = 0; }
    const requestPage = this.nextPage;
    ExploreCoordinator.explore(source, this.kindUrl, requestPage).then((outcome: ExploreOutcome): void => {
      if (generation !== this.generation) { return; }
      if (outcome.error.length > 0) {
        this.patchLoad(undefined, undefined, undefined, outcome.error);
        this.finishLoading();
        return;
      }
      // 上游 `fetchPage` 在去重之前就把整页结果落 searchBooks 表：
      // 换源、换封面、精确搜索都靠这张表，落库失败不影响本页展示。
      this.saveSearchBooks(outcome.books);
      const existing: Set<string> = new Set<string>();
      for (const entry of this.books) {
        if (entry.book.bookUrl.length > 0) { existing.add(entry.book.bookUrl); }
      }
      const fresh: SearchBookItem[] = [];
      for (const item of outcome.books) {
        if (item.bookUrl.length > 0 && existing.has(item.bookUrl)) { continue; }
        existing.add(item.bookUrl);
        fresh.push(item);
      }
      if (fresh.length === 0) {
        this.fetchNextAutoPageOrFinish(source, generation);
        return;
      }
      this.books = this.books.concat(this.wrapBooks(fresh));
      this.patchPage(requestPage, undefined);
      this.nextPage = requestPage + 1;
      this.autoPageCount = 0;
      this.patchLoad(undefined, undefined, outcome.books.length < PAGE_SIZE, undefined);
      this.finishLoading();
    }).catch((error: Error): void => {
      if (generation !== this.generation) { return; }
      this.patchLoad(undefined, undefined, undefined, error.message);
      this.finishLoading();
    });
  }

  /**
   * 本页被去重后为空：再抓一页，最多 3 页（上游 `fetchNextAutoPageOrFinish`）。
   * 上游这里是 `delay(500)` 后递归，本地同样延迟，避免对同一源连打。
   */
  private fetchNextAutoPageOrFinish(source: BookSource, generation: number): void {
    this.nextPage++;
    this.autoPageCount++;
    if (this.autoPageCount >= MAX_AUTO_PAGES) {
      this.patchLoad(undefined, undefined, true, undefined);
      this.finishLoading();
      return;
    }
    setTimeout((): void => {
      if (generation !== this.generation) { return; }
      this.patchLoad(false, undefined, undefined, undefined);
      this.loadMore(false, true);
    }, AUTO_PAGE_DELAY_MS);
  }

  /**
   * 把一页探索结果写进 searchBooks 缓存（上游 `saveSearchBooksUseCase.save(result.books)`）。
   * 写失败只记日志：缓存缺失不影响当前页展示，也不该打断翻页。
   */
  private saveSearchBooks(books: SearchBookItem[]): void {
    if (books.length === 0) { return; }
    const context = this.getUIContext().getHostContext();
    if (context === undefined) { return; }
    SearchBookRepository.save(context, books).catch((error: Error): void => {
      console.error(`探索结果落库失败：${error.message}`);
    });
  }

  private finishLoading(): void {
    this.patchLoad(false, false, undefined, undefined);
  }

  /** 刷新：清空后从第 1 页重抓（上游 `Refresh`）。 */
  private refresh(): void {
    this.loadMore(true, false);
  }

  /** 切分类（上游 `switchKind`）：重置页码与代次，用新 url 重抓。 */
  private switchKind(kind: ExploreKind): void {
    this.generation++;
    this.patchKind(undefined, kind.title);
    this.kindUrl = kind.url;
    this.patchPage(undefined, supportsPageSelection(kind.url));
    this.books = [];
    this.patchLoad(false, undefined, false, '');
    this.nextPage = 1;
    this.autoPageCount = 0;
    this.loadMore(true, false);
  }

  /** 跳页（上游 `jumpToPage`）：清空后从目标页抓。 */
  private jumpToPage(target: number): void {
    if (!this.canJumpPageOf()) { return; }
    this.generation++;
    this.books = [];
    this.patchLoad(false, undefined, false, '');
    this.nextPage = Math.max(1, Math.round(target));
    this.patchPage(this.nextPage, undefined);
    this.autoPageCount = 0;
    this.loadMore(false, true);
  }

  /**
   * 切换布局并落盘（上游 `toggleLayout` + `ExploreShowScreen.kt:216-226` 的位置同步）。
   * 上游用 `LaunchedEffect(isGridMode)` 把对方的 firstVisibleItemIndex 搬过来；
   * 本地没有 LaunchedEffect，改成切之前先记下当前布局的位置，切完让新布局跳过去。
   */
  private toggleLayout(): void {
    const next = this.isGridMode() ? EXPLORE_LAYOUT_MODE_LIST : EXPLORE_LAYOUT_MODE_GRID;
    this.pendingScrollIndex = this.isGridMode() ? this.gridFirstIndex : this.listFirstIndex;
    this.patchDisplay(undefined, next, undefined, undefined);
    const context = this.getUIContext().getHostContext();
    if (context === undefined) { return; }
    ExploreLayoutSettingsRepository.saveLayoutMode(context, next).catch((): void => {
      // 落盘失败不影响本次切换，下次进来回到旧值。
    });
  }

  /** 改列数并落盘（上游 `saveGridCount`：按朝向选 key）。 */
  private saveGridCount(count: number): void {
    const clamped = ExploreLayoutSettingsRepository.clampGridCount(count);
    if (this.landscape) { this.gridLandscape = clamped; } else { this.gridPortrait = clamped; }
    const context = this.getUIContext().getHostContext();
    if (context === undefined) { return; }
    ExploreLayoutSettingsRepository.saveGridCount(context, clamped, this.landscape).catch((): void => {
      // 同上。
    });
  }

  /** 一本书在书架里的状态（对齐上游 `ResolveBookShelfStateUseCase`）。 */
  private shelfStateOf(item: SearchBookItem): BookShelfState {
    if (item.bookUrl.length > 0) {
      for (const book of this.shelfBooks) {
        if ((book.contentPath ?? '') === item.bookUrl) { return BookShelfState.IN_SHELF; }
      }
    }
    for (const book of this.shelfBooks) {
      if (book.title === item.name && book.author === item.author) {
        return BookShelfState.SAME_NAME_AUTHOR;
      }
    }
    return BookShelfState.NOT_IN_SHELF;
  }

  /** 把一批搜索结果包成 `ExploreBookItemUi`（书架状态在装载时定下来）。 */
  private wrapBooks(items: SearchBookItem[]): ExploreBookItemUi[] {
    const wrapped: ExploreBookItemUi[] = [];
    for (const item of items) {
      wrapped.push({ book: item, shelfState: this.shelfStateOf(item) });
    }
    return wrapped;
  }

  /**
   * 书架快照变化（上游 `observeBookshelf()` 收到新书架 → `combineUiState()` 重算）。
   * ArkUI 的 @State 数组不跟踪元素内部字段，必须整体换数组才会重渲染。
   */
  private onShelfBooksChanged(): void {
    this.recomputeShelfStates();
  }

  /** 按当前书架重算所有结果项的 shelfState。 */
  private recomputeShelfStates(): void {
    const next: ExploreBookItemUi[] = [];
    let changed = false;
    for (const entry of this.books) {
      const state = this.shelfStateOf(entry.book);
      if (state !== entry.shelfState) { changed = true; }
      next.push({ book: entry.book, shelfState: state });
    }
    if (changed) { this.books = next; }
  }

  /** 上次过滤的输入快照（对应上游 `remember(state.books, filterStateId)` 的 key）。 */
  private filterCacheBooks: ExploreBookItemUi[] | undefined = undefined;
  private filterCacheStateId: number = -1;
  private filterCacheResult: ExploreBookItemUi[] = [];

  /**
   * 四档过滤（上游 `ExploreShowScreen.kt:160-169` 的 `BookFilterState.fromId`）。
   * 过滤后可能为空：上游不兜底，而是由 `ForceLoadNext` 再抓下一页（见 `resultArea()`）。
   * 这里同样不回落全显，否则「隐藏书架已有」这条过滤会被静默绕过。
   *
   * 上游用 `remember(state.books, filterStateId)` 缓存这次计算；本地加一层同样语义的
   * 快照比对，避免每次 build 都跑一遍 `shelfStateOf`（O(书数 × 书架数)）。
   * 缓存键与上游一致：`books` 引用 + `filterStateId`。书架状态已折进 `ExploreBookItemUi`，
   * 书架变化走 `recomputeShelfStates()` 换整个数组，引用自然变，缓存自动失效。
   */
  private filteredBooks(): ExploreBookItemUi[] {
    const mode = this.exploreFilterState;
    if (mode !== 1 && mode !== 2 && mode !== 3) { return this.books; }
    if (this.filterCacheBooks === this.books && this.filterCacheStateId === mode) {
      return this.filterCacheResult;
    }
    const result: ExploreBookItemUi[] = [];
    for (const entry of this.books) {
      const state = entry.shelfState;
      if (mode === 1 && state !== BookShelfState.IN_SHELF) { result.push(entry); }
      else if (mode === 2 && state !== BookShelfState.SAME_NAME_AUTHOR) { result.push(entry); }
      else if (mode === 3 && state === BookShelfState.NOT_IN_SHELF) { result.push(entry); }
    }
    this.filterCacheBooks = this.books;
    this.filterCacheStateId = mode;
    this.filterCacheResult = result;
    return result;
  }

  /** 共享元素键：网格 `explore:grid:N`、列表 `explore:list:N`（上游同名）。 */
  private sharedKeyOf(item: SearchBookItem, index: number): string {
    const scope = this.isGridMode() ? `explore:grid:${index}` : `explore:list:${index}`;
    return bookCoverSharedElementKey(item.bookUrl, scope);
  }

  /** 滚动到接近底部就续页（上游 `shouldLoadMore`：网格看最后一项，列表看倒数第三项）。 */
  private shouldLoadMore(index: number, total: number): boolean {
    if (total === 0 || this.loadingOf() || this.refreshingOf() || this.isEndOf()) { return false; }
    if (this.errorMsgOf().length > 0) { return false; }
    return this.isGridMode() ? index >= total - 1 : index >= total - 3;
  }

  /** 滚动时折叠标题（对齐上游 `AppScaffold` 的 nested scroll 折叠，阈值与发现页一致）。 */
  private updateHeader(offset: number): void {
    if (offset > HEADER_COLLAPSE_THRESHOLD && !this.collapsedHeader) {
      this.collapsedHeader = true;
    } else if (offset < HEADER_EXPAND_THRESHOLD && this.collapsedHeader) {
      this.collapsedHeader = false;
    }
  }

  /**
   * 预览面板的书架状态（上游 `ExploreShowScreen.kt:482-498`）：从当前结果里找同 bookUrl 的
   * 元素读它的 shelfState，找不到才回落 NOT_IN_SHELF。
   */
  private previewShelfState(): BookShelfState {
    const url = this.previewItem.bookUrl;
    for (const entry of this.books) {
      if (entry.book.bookUrl === url) { return entry.shelfState; }
    }
    return BookShelfState.NOT_IN_SHELF;
  }

  /** 打开长按预览。 */
  private openPreview(item: SearchBookItem, index: number): void {
    this.previewItem = item;
    this.previewSharedKey = this.sharedKeyOf(item, index);
    this.previewVisible = true;
  }

  // ── Intent 分派（上游 `ExploreShowViewModel.kt:113-165` 的 `onIntent` 16 分支） ──
  //
  // 上游 ViewModel 收 Intent 再改状态；本地页面自己持有状态，所以 onIntent 就是
  // 「按 kind 落到对应私有方法」的一层分派。保留这层的意义是可对照：
  // 上游有哪 16 类意图，这里就有哪 16 个分支，缺哪类一眼能看出来。

  /** 造一条只带 kind 的 Intent（字段由调用方按需补）。 */
  private intentOf(kind: string): ExploreShowIntent {
    const intent: ExploreShowIntent = {
      kind: kind as ExploreShowIntentKind,
      sourceUrl: '',
      exploreUrl: '',
      value: 0,
      kind_: undefined,
      sheet: ExploreShowSheet.None,
      book: undefined,
      sharedCoverKey: '',
      summary: undefined,
      existingBookUrl: '',
      options: undefined
    };
    return intent;
  }

  /** 打开某个底部面板（上游 `ShowSheet`）。 */
  private showSheet(sheet: ExploreShowSheet): void {
    const intent = this.intentOf('ShowSheet');
    intent.sheet = sheet;
    this.onIntent(intent);
  }

  /** 发一条 Effect（上游 `_effects.tryEmit(effect)`）。 */
  private emitEffect(effect: ExploreShowEffect): void {
    this.onEffect(effect);
  }

  /** 默认的 Effect 分派（上游 `ExploreShowRouteScreen` 里那段 `when (effect)`）。 */
  private dispatchEffectLocally(effect: ExploreShowEffect): void {
    if (effect.kind === 'OpenBookInfo') {
      // 上游 `ExploreShowScreen.kt:103-119`：把 Effect 六字段还原成一条 SearchBook 交给上层。
      const item: SearchBookItem = {
        bookUrl: effect.bookUrl,
        origin: effect.origin,
        originName: '',
        name: effect.name,
        author: effect.author,
        kind: '',
        coverUrl: effect.coverPath,
        intro: '',
        lastChapter: '',
        wordCount: '',
        updateTime: '',
        tocUrl: effect.bookUrl
      };
      this.onOpenBookWithSharedKey(item, effect.sharedCoverKey);
      return;
    }
    this.onUnavailableAction(effect.message);
  }

  /** 分派一条 Intent（上游 `ExploreShowViewModel.onIntent` 的 16 个 `when` 分支）。 */
  private onIntent(intent: ExploreShowIntent): void {
    const kind = intent.kind;
    if (kind === 'InitData') {
      this.initData(intent.sourceUrl, intent.exploreUrl);
    } else if (kind === 'LoadMore') {
      this.loadMore(false, false);
    } else if (kind === 'JumpToPage') {
      this.jumpToPage(intent.value);
    } else if (kind === 'ForceLoadNext') {
      this.loadMore(false, true);
    } else if (kind === 'Refresh') {
      this.refresh();
    } else if (kind === 'SwitchKind') {
      const target = intent.kind_;
      if (target !== undefined) { this.switchKind(target); }
    } else if (kind === 'ToggleLayout') {
      this.toggleLayout();
    } else if (kind === 'SaveGridCount') {
      this.saveGridCount(intent.value);
    } else if (kind === 'ShowSheet') {
      this.patchDisplay(undefined, undefined, undefined, intent.sheet);
    } else if (kind === 'DismissSheet') {
      this.patchDisplay(undefined, undefined, undefined, ExploreShowSheet.None);
    } else if (kind === 'OpenBook') {
      const book = intent.book;
      if (book !== undefined) { this.emitEffect(openBookInfoEffect(book, intent.sharedCoverKey)); }
    } else if (kind === 'AddToShelf') {
      const book = intent.book;
      if (book !== undefined) { this.requestAddToShelf(book); }
    } else if (kind === 'DismissBookshelfConflict') {
      this.dismissBookshelfConflict();
    } else if (kind === 'OpenBookshelfConflictBook') {
      this.openBookshelfConflictBook();
    } else if (kind === 'CoexistWithBookshelfConflict') {
      this.resolveBookshelfConflict(intent.existingBookUrl, intent.options, true);
    } else if (kind === 'MigrateBookshelfConflict') {
      this.resolveBookshelfConflict(intent.existingBookUrl, intent.options, false);
    }
  }

  /** 把一条搜索结果转成冲突面板的摘要（上游 `ConflictBookSummary`）。 */
  private summaryOf(item: SearchBookItem): ConflictBookSummary {
    const summary = new ConflictBookSummary();
    summary.bookUrl = item.bookUrl;
    summary.name = item.name;
    summary.author = item.author;
    summary.coverUrl = item.coverUrl;
    summary.customCoverUrl = '';
    summary.origin = item.origin;
    summary.sourceName = item.originName;
    summary.totalChapterNum = 0;
    summary.latestChapterTitle = item.lastChapter;
    return summary;
  }

  /**
   * 加架（上游 `BookshelfConflictController.addToShelf`，:46-58）。
   * 加成功就 toast「书籍已添加到书架」；有冲突就弹 `BookshelfConflictSheet`。
   */
  private requestAddToShelf(item: SearchBookItem): void {
    this.pendingShelfBook = item;
    this.onAddToShelf(item).then((candidates: ConflictBookSummary[]): void => {
      if (candidates.length === 0) {
        this.pendingShelfBook = undefined;
        this.emitEffect(showMessageEffect('书籍已添加到书架'));
        return;
      }
      const conflict = new BookshelfConflict();
      conflict.incoming = this.summaryOf(item);
      conflict.candidates = candidates;
      this.bookshelfConflict = conflict;
    }).catch((error: Error): void => {
      this.pendingShelfBook = undefined;
      this.emitEffect(showMessageEffect('加入书架失败：' + error.message));
    });
  }

  /** 收起冲突面板并清掉 pending（上游 `BookshelfConflictController.dismiss`）。 */
  private dismissBookshelfConflict(): void {
    this.bookshelfConflict = undefined;
    this.pendingShelfBook = undefined;
  }

  /**
   * 打开冲突里的已有副本（上游 `OpenBookshelfConflictBook`）。
   * 上游注释：**先收起 Sheet 再导航**，否则返回本页时 Sheet 会重新显示并吃掉一次返回键。
   */
  private openBookshelfConflictBook(): void {
    const conflict = this.bookshelfConflict;
    if (conflict === undefined) { return; }
    const summary = conflict.candidates.length > 0 ? conflict.candidates[0] : conflict.incoming;
    this.dismissBookshelfConflict();
    const item: SearchBookItem = {
      bookUrl: summary.bookUrl,
      origin: summary.origin,
      originName: summary.sourceName,
      name: summary.name,
      author: summary.author,
      kind: '',
      coverUrl: summary.displayCover(),
      intro: '',
      lastChapter: summary.latestChapterTitle,
      wordCount: '',
      updateTime: '',
      tocUrl: summary.bookUrl
    };
    // 上游 `sharedCoverKey = null`，这里传空串表示不做共享动画。
    this.emitEffect(openBookInfoEffect(item, ''));
  }

  /**
   * 处置冲突（上游 `BookshelfConflictController.resolve`，:73-121）。
   * 成功/失败都先收起面板再 toast，与上游一致。
   */
  private resolveBookshelfConflict(existingBookUrl: string, options: ChangeSourceMigrationOptions | undefined,
    coexist: boolean): void {
    const pending = this.pendingShelfBook;
    if (pending === undefined || options === undefined) { return; }
    this.isResolvingBookshelfConflict = true;
    const mode = coexist ? 'coexist' : 'migrate';
    this.onResolveShelfConflict(existingBookUrl, pending.bookUrl, mode, options).then((error: string): void => {
      this.isResolvingBookshelfConflict = false;
      this.bookshelfConflict = undefined;
      this.pendingShelfBook = undefined;
      if (error.length === 0) {
        this.emitEffect(showMessageEffect(coexist ? '已加入书架（与原书共存）' : '已迁移进度'));
      } else {
        this.emitEffect(showMessageEffect(error));
      }
    }).catch((failure: Error): void => {
      this.isResolvingBookshelfConflict = false;
      this.bookshelfConflict = undefined;
      this.pendingShelfBook = undefined;
      this.emitEffect(showMessageEffect('处理书架冲突出错\n' + failure.message));
    });
  }


  /** 刷新指示器（与首页同一个组件，`PullRefreshIndicator`）。 */
  @Builder
  private RefreshIndicatorBuilder() {
    PullRefreshIndicator({
      armed: this.refreshArmed,
      refreshing: this.refreshingOf(),
      pullDistance: this.refreshPullOffset
    })
  }

  /** 顶栏返回槽。 */
  @Builder
  private navSlot() {
    TopBarBackButton({ onSelect: () => { this.onBack(); } })
  }

  /** 顶栏动作：布局 / 分类 / 页码（上游 `actions` 三个按钮的顺序）。 */
  @Builder
  private topActions() {
    TopBarButton({
      icon: 'grid',
      accessibilityLabel: '切换布局',
      onSelect: () => { this.showSheet(ExploreShowSheet.GridCount); }
    })
    TopBarButton({
      icon: 'profileFilterAlt',
      accessibilityLabel: '选择或搜索分类',
      onSelect: () => { this.showSheet(ExploreShowSheet.KindSelect); }
    })
    if (this.canJumpPageOf()) {
      Text(`${this.currentPageOf()}`)
        .fontSize(LABEL_MEDIUM)
        .fontColor(this.themeColorTextPrimary)
        .padding({ left: SPACE_8, right: SPACE_8, top: SPACE_4, bottom: SPACE_4 })
        .accessibilityText('跳转页码')
        .onClick(() => {
          this.jumpInput = `${this.currentPageOf()}`;
          this.showJumpPageDialog = true;
        })
    }
  }

  /**
   * 下拉刷新壳（上游 `ExploreShowScreen.kt:297-300` 的 `AppPullToRefresh`）。
   * 内容层用 `.position({ x: 0, y: 0 })` 钉住，不随下拉手势下移，只有指示器进出
   * （`refresh.d.ts:100-104`）。
   */
  /**
   * 【嵌套 struct 首帧兜底】ArkTS 在 @Builder 里读取 `get` 访问器时会被编译期内联成对同名底层
   * 字段的直接访问，绕过 getter 体内的判空（实测 jscrash: "Cannot read property length of
   * undefined" 落在 `this.errorMsgOf().length`，而 getter 本身已判空）。所以这里用普通方法拿状态——
   * 与 pageTitle() 一样已验证不会被内联；@Builder 顶层又不允许写 const，故只能走方法调用。
   */
  private safeLoad(): ExploreShowLoadState {
    const s: ExploreShowLoadState | undefined = this.loadState;
    return (s === undefined || s.errorMsg === undefined) ? emptyExploreShowLoadState() : s;
  }

  /** 同上：@Builder 内不直接读 this.books，走普通方法兜底。 */
  private safeBooks(): ExploreBookItemUi[] {
    return this.books === undefined ? [] : this.books;
  }

  @Builder
  private resultArea() {
    Refresh({ refreshing: this.safeLoad().isRefreshing, builder: () => { this.RefreshIndicatorBuilder(); } }) {
      Column() {
        if (this.safeLoad().errorMsg.length > 0 && this.safeBooks().length === 0) {
          // 首屏失败：错误态也在刷新壳里，下拉即可重试（上游同一片 `resultContent`）。
          Column() {
            Text('加载失败').fontSize(LABEL_MEDIUM).fontColor(this.themeColorTextSecondary)
            Text(this.safeLoad().errorMsg)
              .fontSize(BODY_SMALL)
              .fontColor(this.themeColorTextTertiary)
              .textAlign(TextAlign.Center)
              .margin({ top: SPACE_4, left: 24, right: 24 })
            Text('重试')
              .fontSize(LABEL_MEDIUM)
              .fontColor(this.themeColorAccent)
              .margin({ top: SPACE_12 })
              .onClick(() => { this.loadMore(true, false); })
          }
          .width('100%')
          .height('100%')
          .justifyContent(FlexAlign.Center)
        } else if (this.filteredBooks().length === 0 && !this.safeLoad().isLoading) {
          // 过滤后为空：若还有下一页就自动再抓（上游 `ExploreShowScreen.kt:210-214`
          // 的 `ForceLoadNext`），真的到底了才显示空态。
          Column() {
            if (!this.safeLoad().isEnd && this.safeBooks().length > 0) {
              LoadingProgress()
                .width(28)
                .height(28)
                .color(this.themeColorAccent)
            } else {
              Text('暂无内容').fontSize(TITLE_SMALL).fontColor(this.themeColorTextSecondary)
            }
          }
          .width('100%')
          .height('100%')
          .justifyContent(FlexAlign.Center)
          .onAppear(() => {
            if (!this.safeLoad().isEnd && this.safeBooks().length > 0 && !this.safeLoad().isLoading) {
              this.onIntent(this.intentOf('ForceLoadNext'));
            }
          })
        } else if (this.isGridMode()) {
          this.gridArea()
        } else {
          this.listArea()
        }
      }
      .width('100%')
      .height('100%')
      .position({ x: 0, y: 0 })
    }
    .layoutWeight(1)
    .refreshOffset(64)
    .pullDownRatio(1)
    .maxPullDownDistance(120)
    .onRefreshing(() => { this.refresh(); })
    .onStateChange((state: RefreshStatus) => {
      const armed = state === RefreshStatus.OverDrag;
      if (armed !== this.refreshArmed) { this.refreshArmed = armed; }
    })
    .onOffsetChange((offset: number) => { this.refreshPullOffset = offset; })
  }

  /**
   * 列表行。
   * 不收参数：`@Builder` 按值传参时，参数变了内部不会重建（ArkUI 只在首次构建时取值），
   * 首屏空数组进来之后即使 `books` 变成 10 条也画不出来。改成直接读 `filteredBooks()`。
   */
  @Builder
  private listArea() {
    List({ scroller: this.listScroller }) {
      ForEach(this.filteredBooks(), (entry: ExploreBookItemUi, index: number) => {
        ListItem() {
          SearchBookListItem({
            item: entry.book,
            shelfState: entry.shelfState,
            coverSettings: this.coverSettings,
            isNight: this.isNight,
            adaptCoverAspectRatio: true,
            sharedKey: this.sharedKeyOf(entry.book, index),
            onSelect: () => {
              const open = this.intentOf('OpenBook');
              open.book = entry.book;
              open.sharedCoverKey = this.sharedKeyOf(entry.book, index);
              this.onIntent(open);
            },
            onLongPress: () => { this.openPreview(entry.book, index); }
          })
        }
        .transition(TransitionEffect.OPACITY.animation({ duration: 200 }))
        .onAppear(() => {
          if (this.shouldLoadMore(index, this.filteredBooks().length)) {
            this.onIntent(this.intentOf('LoadMore'));
          }
        })
      }, (entry: ExploreBookItemUi, index: number) => `${entry.book.bookUrl}:${index}`)

      if (!this.footerHidden()) {
        ListItem() {
          this.footer()
        }
      }
    }
    .width('100%')
    .layoutWeight(1)
    .padding({ bottom: this.listBottomPadding() })
    // 布局切换的淡入淡出（上游 `Crossfade(animationSpec = tween(250))`）。
    .transition(TransitionEffect.OPACITY.animation({ duration: LAYOUT_CROSSFADE_MS }))
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring)
    .cachedCount(4)
    .onDidScroll((scrollOffset: number, _scrollState: ScrollState) => {
      this.updateHeader(scrollOffset);
    })
    // 首个可见项下标（上游 `listState.firstVisibleItemIndex`）：`Scroller` 没有
    // 现成的下标读取接口，只能靠这个回调记。
    .onScrollIndex((first: number, _last: number, _center: number) => {
      this.listFirstIndex = first;
    })
    .onAppear(() => { this.applyPendingScroll(); })
  }

  /** 网格。同样不收参数，理由见 `listArea()`。 */
  @Builder
  private gridArea() {
    Grid(this.gridScroller) {
      ForEach(this.filteredBooks(), (entry: ExploreBookItemUi, index: number) => {
        GridItem() {
          SearchBookGridItem({
            item: entry.book,
            shelfState: entry.shelfState,
            coverSettings: this.coverSettings,
            isNight: this.isNight,
            sharedKey: this.sharedKeyOf(entry.book, index),
            onSelect: () => {
              const open = this.intentOf('OpenBook');
              open.book = entry.book;
              open.sharedCoverKey = this.sharedKeyOf(entry.book, index);
              this.onIntent(open);
            },
            onLongPress: () => { this.openPreview(entry.book, index); }
          })
        }
        // 上游 `ExploreShowScreen.kt:559`：`ExploreBookGridItem` 自带 `padding(4.dp)`，
        // 外层再加 `spacedBy(4.dp)` 列间隔与 `spacedBy(8.dp)` 行间隔，两者是叠加关系。
        .padding(GRID_ITEM_PADDING)
        .transition(TransitionEffect.OPACITY.animation({ duration: 200 }))
        .onAppear(() => {
          if (this.shouldLoadMore(index, this.filteredBooks().length)) {
            this.onIntent(this.intentOf('LoadMore'));
          }
        })
      }, (entry: ExploreBookItemUi, index: number) => `${entry.book.bookUrl}:${index}`)

      // 加载更多占满整行（上游 `item(span = { GridItemSpan(maxLineSpan) })`）。
      if (!this.footerHidden()) {
        GridItem() {
          this.footer()
        }
        .columnStart(0)
        .columnEnd(-1)
      }
    }
    .columnsTemplate(this.columnsTemplate())
    .columnsGap(GRID_GAP_H)
    .rowsGap(GRID_GAP_V)
    .padding({
      left: GRID_PADDING,
      right: GRID_PADDING,
      top: SPACE_12,
      bottom: this.gridBottomPadding()
    })
    .width('100%')
    .layoutWeight(1)
    // 布局切换的淡入淡出（上游 `Crossfade(animationSpec = tween(250))`）。
    .transition(TransitionEffect.OPACITY.animation({ duration: LAYOUT_CROSSFADE_MS }))
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring)
    .onDidScroll((scrollOffset: number, _scrollState: ScrollState) => {
      this.updateHeader(scrollOffset);
    })
    // 同列表：`Scroller` 没有下标读取接口，靠 `onScrollIndex` 记。
    // Grid 的这个回调只有两个参数（`grid.d.ts:561`），与 List 的三参数不同。
    .onScrollIndex((first: number, _last: number) => {
      this.gridFirstIndex = first;
    })
    .onAppear(() => { this.applyPendingScroll(); })
  }

  /** 两个滚动控制器（上游 `listState` / `gridState`）。 */
  private listScroller: Scroller = new Scroller();
  private gridScroller: Scroller = new Scroller();

  /** 网格底部内边距（上游 `bottom + (embeddedInMain ? 108.dp : 12.dp)`）。 */
  private gridBottomPadding(): number {
    return this.embeddedInMain ? EMBEDDED_BOTTOM_INSET : GRID_PADDING_BOTTOM;
  }

  /** 列表底部内边距（上游 `bottom + (embeddedInMain ? 108.dp : 16.dp)`）。 */
  private listBottomPadding(): number {
    return this.embeddedInMain ? EMBEDDED_BOTTOM_INSET : LIST_PADDING_BOTTOM;
  }

  /**
   * 切布局后把新布局滚到旧布局的位置（上游 `ExploreShowScreen.kt:216-226`）。
   * 只在 `pendingScrollIndex >= 0` 时动一次，滚完复位，避免每次 onAppear 都跳。
   */
  private applyPendingScroll(): void {
    const target = this.pendingScrollIndex;
    if (target < 0) { return; }
    this.pendingScrollIndex = -1;
    if (target === 0) { return; }
    if (this.isGridMode()) {
      this.gridScroller.scrollToIndex(target, true);
    } else {
      this.listScroller.scrollToIndex(target, true);
    }
  }

  /** 尾行是否该出现（上游 `showLoadMoreFooter`）。 */
  private footerHidden(): boolean {
    return this.refreshingOf() || (!this.loadingOf() && this.errorMsgOf().length === 0 && !this.isEndOf());
  }

  /** 尾行（`LoadMoreFooter`，`autoLoad = false` 对齐上游 `ExploreShowScreen.kt:500-517`）。 */
  @Builder
  private footer() {
    LoadMoreFooter({
      isLoading: this.loadingOf(),
      errorMsg: this.errorMsgOf(),
      isEnd: this.isEndOf(),
      autoLoad: false,
      showLoadMore: true,
      onRetry: () => { this.loadMore(false, false); },
      onLoadMore: () => { this.loadMore(false, true); }
    })
  }

  /** 布局与列数面板（上游 `ExploreShowSheet.GridCount`）。 */
  @Builder
  private layoutSheet() {
    Column() {
      Text('布局模式')
        .fontSize(TITLE_SMALL)
        .fontColor(this.themeColorTextPrimary)
        .width('100%')
        .padding({ left: SPACE_16, right: SPACE_16, top: SPACE_12, bottom: SPACE_8 })

      Row() {
        Column({ space: SPACE_4 }) {
          Text('布局模式').fontSize(LABEL_LARGE).fontColor(this.themeColorTextPrimary)
          Text(this.isGridMode() ? '网格' : '列表')
            .fontSize(BODY_SMALL)
            .fontColor(this.themeColorTextTertiary)
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        AppGlyph({ name: 'grid', glyphSize: 20, tint: this.themeColorTextTertiary })
      }
      .width('100%')
      .padding({ left: SPACE_16, right: SPACE_16, top: SPACE_12, bottom: SPACE_12 })
      .onClick(() => { this.onIntent(this.intentOf('ToggleLayout')); })

      if (this.isGridMode()) {
        UiSlider({
          title: '网格列数',
          value: this.gridCount(),
          minValue: EXPLORE_GRID_COUNT_MIN,
          maxValue: EXPLORE_GRID_COUNT_MAX,
          stepValue: 1,
          onChange: (value: number) => {
            const save = this.intentOf('SaveGridCount');
            save.value = value;
            this.onIntent(save);
          }
        })
      }

      Blank().height(32)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  /**
   * 跳页对话框（上游 `ExploreShowScreen.kt:456-480` 的 `AppAlertDialog` + `AppTextField`）。
   * 上游是对话框不是底部面板，本地改成遮罩 + 居中卡片。
   */
  @Builder
  private jumpDialog() {
    Stack({ alignContent: Alignment.Center }) {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('#66000000')
        .onClick(() => { this.showJumpPageDialog = false; })

      Column() {
        Text('跳转页码')
          .fontSize(TITLE_SMALL)
          .fontColor(this.themeColorTextPrimary)
          .width('100%')

        TextInput({ text: this.jumpInput, placeholder: '页码' })
          .type(InputType.Number)
          .maxLength(4)
          .fontSize(LABEL_LARGE)
          .backgroundColor(this.themeColorSurfaceTertiary)
          .borderRadius(10)
          .margin({ top: SPACE_12 })
          .onChange((value: string) => {
            // 上游 `it.filter(Char::isDigit).take(4)`：只留数字，最多四位。
            let digits = '';
            for (let index = 0; index < value.length && digits.length < 4; index++) {
              const char = value.charAt(index);
              if (char >= '0' && char <= '9') { digits += char; }
            }
            this.jumpInput = digits;
          })

        Row() {
          Text('取消')
            .fontSize(LABEL_LARGE)
            .fontColor(this.themeColorTextTertiary)
            .padding({ left: 20, right: 20, top: 10, bottom: 10 })
            .onClick(() => { this.showJumpPageDialog = false; })
          Text('跳转')
            .fontSize(LABEL_LARGE)
            .fontColor('#FFFFFF')
            .backgroundColor(this.themeColorAccent)
            .borderRadius(10)
            .padding({ left: 20, right: 20, top: 10, bottom: 10 })
            .enabled(this.jumpInput.length > 0)
            .onClick(() => {
              const target = Number.parseInt(this.jumpInput, 10);
              if (Number.isNaN(target) || target < 1) { return; }
              this.showJumpPageDialog = false;
              const jump = this.intentOf('JumpToPage');
              jump.value = target;
              this.onIntent(jump);
            })
        }
        .width('100%')
        .justifyContent(FlexAlign.End)
        .margin({ top: SPACE_16 })
      }
      .width('calc(100% - 64vp)')
      .padding({ left: SPACE_16, right: SPACE_16, top: SPACE_16, bottom: SPACE_16 })
      .backgroundColor(this.themeColorSurfaceElevated)
      .borderRadius(20)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .height('100%')
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      Column() {
        // 上游 `if (embeddedInMain) resultContent(embeddedPadding) else AppScaffold{...}`：
        // 嵌入主界面时不自带顶栏，标题与返回由外层承担。
        if (!this.embeddedInMain) {
          AppTopBar({
            title: this.pageTitle(),
            subtitle: '',
            collapsed: this.collapsedHeader,
            hasNavigation: true,
            navigationIcon: () => { this.navSlot() },
            actions: () => { this.topActions() }
          })
        }

        this.resultArea()
      }
      .width('100%')
      .height('100%')
      .padding({
        top: this.embeddedInMain ? this.embeddedPaddingTop : 0,
        bottom: this.embeddedInMain ? this.embeddedPaddingBottom : 0
      })

      // 预览面板：上游 `SearchBookPreviewSheet`（长按弹出）。
      if (this.previewVisible) {
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor('#66000000')
          .onClick(() => { this.previewVisible = false; })

        Column() {
          SearchBookPreviewSheet({
            item: this.previewItem,
            shelfState: this.previewShelfState(),
            coverSettings: this.coverSettings,
            isNight: this.isNight,
            sharedKey: this.previewSharedKey,
            onOpenDetail: () => {
              const item = this.previewItem;
              const sharedKey = this.previewSharedKey;
              this.previewVisible = false;
              this.onOpenBookWithSharedKey(item, sharedKey);
            },
            onAddToShelf: () => {
              const item = this.previewItem;
              this.previewVisible = false;
              const add = this.intentOf('AddToShelf');
              add.book = item;
              this.onIntent(add);
            }
          })
        }
        .width('calc(100% - 32vp)')
        .padding({ left: SPACE_16, right: SPACE_16, top: SPACE_16 })
        .backgroundColor(this.themePureBlack ? '#17181E' : this.themeColorSurfaceElevated)
        .borderRadius(28)
      }

      // 加架冲突面板（上游 `ExploreShowScreen.kt:269-280` 的 `BookshelfConflictSheet`）。
      if (this.bookshelfConflict !== undefined) {
        Column() {
          BookshelfConflictSheet({
            conflict: this.bookshelfConflict,
            isResolving: this.isResolvingBookshelfConflict,
            onDismissRequest: () => { this.onIntent(this.intentOf('DismissBookshelfConflict')); },
            onOpenExistingBook: (_summary: ConflictBookSummary) => {
              this.onIntent(this.intentOf('OpenBookshelfConflictBook'));
            },
            onCoexist: (existingBookUrl: string, options: ChangeSourceMigrationOptions) => {
              const coexist = this.intentOf('CoexistWithBookshelfConflict');
              coexist.existingBookUrl = existingBookUrl;
              coexist.options = options;
              this.onIntent(coexist);
            },
            onMigrate: (existingBookUrl: string, options: ChangeSourceMigrationOptions) => {
              const migrate = this.intentOf('MigrateBookshelfConflict');
              migrate.existingBookUrl = existingBookUrl;
              migrate.options = options;
              this.onIntent(migrate);
            }
          })
        }
        .width('100%')
        .height('100%')
      }

      // 跳页对话框（上游 `showJumpPageDialog`）。
      if (this.showJumpPageDialog) {
        this.jumpDialog()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.themeAppBackground.length > 0 ? Color.Transparent : (this.themePureBlack ? '#000000' : this.themeColorSurfacePrimary))
    // 嵌入态由外层容器处理安全区，自己不再展开（上游 embeddedInMain 时不套 AppScaffold）。
    .expandSafeArea(this.embeddedInMain ? [] : [SafeAreaType.SYSTEM],
      this.embeddedInMain ? [] : [SafeAreaEdge.TOP])
    // 同一组件只挂一个 bindSheet（项目已踩过挂多个只有最后一个生效的坑），
    // 两个底部面板共用这一个，按 `sheet` 枚举切内容。
    .bindSheet(this.sheetOf() !== ExploreShowSheet.None, this.sheetContent(), {
      height: this.sheetOf() === ExploreShowSheet.KindSelect ? SheetSize.MEDIUM : SheetSize.FIT_CONTENT,
      dragBar: true,
      showClose: false,
      backgroundColor: this.themeColorSurfaceTertiary,
      onDisappear: () => {
        this.patchDisplay(undefined, undefined, undefined, ExploreShowSheet.None);
      }
    })
  }

  /** 合并面板内容：分类面板最高，布局面板 FIT_CONTENT。 */
  @Builder
  private sheetContent() {
    if (this.sheetOf() === ExploreShowSheet.KindSelect) {
      this.kindSheet()
    } else {
      this.layoutSheet()
    }
  }

  @Builder
  private kindSheet() {
    Column() {
      ExploreKindSelectSheet({
        sourceUrl: this.sourceUrl,
        multiple: false,
        initialSelectedTitles: this.selectedKindTitleOf().length > 0 ? [this.selectedKindTitleOf()] : [],
        onSelected: (kinds: ExploreKind[]) => {
          this.patchDisplay(undefined, undefined, undefined, ExploreShowSheet.None);
          if (kinds.length === 0) { return; }
          this.switchKind(kinds[0]);
        },
        onDismissRequest: () => {
          this.patchDisplay(undefined, undefined, undefined, ExploreShowSheet.None);
        }
      })
    }
    .width('100%')
    .height('100%')
  }
}

/**
 * 「探索结果」路由层。对齐上游 `ui/book/explore/ExploreShowScreen.kt:90-134` 的 `ExploreShowRouteScreen`：
 * 上游这一层只做两件事——① 从 ViewModel 收 state；② 收 Effect 并分派
 * （`OpenBookInfo` → `onBookClick(book, sharedCoverKey)`、`ShowMessage` → `toastOnUi`）。
 * 本地状态源留在 `ExploreShowPage` 内部（ArkTS 无 ViewModel / StateFlow，@State 数组也不跟踪元素内部字段），
 * 所以这一层承担第 ② 件：把页面发上来的 Effect 翻译成对外的两个回调。
 */
@Component
export struct ExploreShowRouteScreen {
  @Prop title: string = '';
  @Prop sourceUrl: string = '';
  @Prop exploreUrl: string = '';
  @Prop shelfBooks: Book[] = [];
  @Prop coverSettings: CoverSettings = DEFAULT_COVER_SETTINGS;
  @Prop isNight: boolean = false;
  @Prop exploreFilterState: number = 0;
  @Prop embeddedInMain: boolean = false;
  @Prop embeddedPaddingTop: number = 0;
  @Prop embeddedPaddingBottom: number = 0;

  onBack: () => void = () => {};
  /** 上游 `onBookClick: (SearchBook, String?) -> Unit`。 */
  onBookClick: (item: SearchBookItem, sharedCoverKey: string) => void = () => {};
  /** 上游 `appCtx.toastOnUi(effect.message)`。 */
  onMessage: (message: string) => void = () => {};
  onAddToShelf: (item: SearchBookItem) => Promise<ConflictBookSummary[]> =
    (_item: SearchBookItem) => Promise.resolve([]);
  onResolveShelfConflict: (existingBookUrl: string, incomingBookUrl: string, mode: string,
    options: ChangeSourceMigrationOptions) => Promise<string> =
    (_existingBookUrl: string, _incomingBookUrl: string, _mode: string,
      _options: ChangeSourceMigrationOptions) => Promise.resolve('');

  /** 上游 `when (effect) { is OpenBookInfo -> onBookClick(...); is ShowMessage -> toastOnUi(...) }`。 */
  private dispatch(effect: ExploreShowEffect): void {
    if (effect.kind === 'OpenBookInfo') {
      const item: SearchBookItem = {
        bookUrl: effect.bookUrl,
        origin: effect.origin,
        originName: '',
        name: effect.name,
        author: effect.author,
        kind: '',
        coverUrl: effect.coverPath,
        intro: '',
        lastChapter: '',
        wordCount: '',
        updateTime: '',
        tocUrl: effect.bookUrl
      };
      this.onBookClick(item, effect.sharedCoverKey);
      return;
    }
    this.onMessage(effect.message);
  }

  build() {
    ExploreShowPage({
      title: this.title,
      sourceUrl: this.sourceUrl,
      exploreUrl: this.exploreUrl,
      shelfBooks: this.shelfBooks,
      coverSettings: this.coverSettings,
      isNight: this.isNight,
      exploreFilterState: this.exploreFilterState,
      embeddedInMain: this.embeddedInMain,
      embeddedPaddingTop: this.embeddedPaddingTop,
      embeddedPaddingBottom: this.embeddedPaddingBottom,
      onBack: () => { this.onBack(); },
      onOpenBook: (item: SearchBookItem) => { this.onBookClick(item, ''); },
      onOpenBookWithSharedKey: (item: SearchBookItem, sharedCoverKey: string) => {
        this.onBookClick(item, sharedCoverKey);
      },
      onAddToShelf: (item: SearchBookItem) => this.onAddToShelf(item),
      onResolveShelfConflict: (existingBookUrl: string, incomingBookUrl: string, mode: string,
        options: ChangeSourceMigrationOptions) => this.onResolveShelfConflict(
          existingBookUrl, incomingBookUrl, mode, options),
      onUnavailableAction: (message: string) => { this.onMessage(message); },
      onEffect: (effect: ExploreShowEffect) => { this.dispatch(effect); }
    })
      .width('100%')
      .height('100%')
  }
}
