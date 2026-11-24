/**
 * 搜索页。
 *
 * 逐项对齐上游 `ui/book/search/`：
 *   - `SearchContract.kt`（173 行）：`SearchUiState` 41 字段 / `SearchIntent` 45 类 / `SearchEffect` 3 类
 *   - `SearchScreen.kt`（1209 行）：顶栏三动作、`SearchBar`、FAB、建议面板、两布局、计数卡、六个 Sheet
 *   - `SearchViewModel.kt`（1105 行）：`onIntent` 45 分支、提交/加载更多/内容质量/展开源/范围编解码
 *   - `SearchBooksUseCase.kt`（399 行）：筛源 / 限流并发 / 合并 / `hasMore`
 *
 * ArkTS 没有 ViewModel 与 Flow，所以状态源留在页面 struct 内（同第七表 ExploreShowPage 的做法），
 * 但字段与分支逐条按上游建镜像：`state: SearchUiState` 承载 41 字段，`onIntent` 承载 45 类。
 */
import curves from '@ohos.curves';
import { Book } from '../model/Book';
import { BookGroup } from '../model/BookGroup';
import { BookSource } from '../model/BookSource';
import { BookRepository } from '../data/BookRepository';
import { BookSourceRepository } from '../data/BookSourceRepository';
import { CoverSettings, DEFAULT_COVER_SETTINGS } from '../data/CoverSettingsRepository';
import { SearchKeyword } from '../model/SearchKeyword';
import { SearchKeywordRepository } from '../data/SearchKeywordRepository';
import { SearchBookRepository } from '../data/SearchBookRepository';
import { LocalPreferencesRepository, LocalPreferencesKeys } from '../data/LocalPreferencesRepository';
import { PrivateAccessRepository, isPrivateBook } from '../data/PrivateAccessRepository';
import { bookCoverSharedElementKey } from '../data/BookCoverSharedElement';
import { SearchCoordinator, SearchProgress, SearchOutcome, SearchScopeFilter } from '../bookSource/SearchCoordinator';
import { MergedBook } from '../bookSource/SearchResultMerger';
import { SearchBookItem } from '../bookSource/SourceModels';
import { ChangeSourceMigrationOptions, defaultMigrationOptions } from '../bookSource/ChangeSourceCoordinator';
import {
  ContentQualityResultUi, ContentQualityStage, ContentQualityUiState, SearchEffect, SearchIntent,
  SearchIntentKind, SearchResultItemUi, SearchShelfHint, SearchUiState, SearchEmptyScopeAction,
  emptyContentQualityUiState, emptySearchUiState, openBookInfoEffect, qualityKeyOf, searchEffect,
  searchIntent, showMessageEffect
} from '../bookSource/SearchContract';
import {
  encodeGroups, encodeSourceScope, encodeSources,
  scopeDisplay, scopeDisplayNames, scopeGroupNames, scopeIsAll, scopeIsSource,
  scopeRemove, scopeSourceUrls
} from '../bookSource/SearchScopeCodec';
import { ContentQualityChecker, ContentQualityConfig, ContentQualityProgress } from '../bookSource/ContentQualityChecker';
import { AppGlyph, AppGlyphName } from '../components/AppGlyph';
import { AppTopBar, TopBarButton, TopBarBackButton } from '../components/TopBar';
import { AppFab } from '../components/booksource/AppFab';
import { AppAlertDialog } from '../components/AppAlertDialog';
import { SearchBar } from '../components/booksource/SearchBar';
import { SelectionItemCard, SmallPlainIconButton } from '../components/booksource/SelectionItemCard';
import { ScopeSelectSheet, ScopeSelection, ScopeSourceChoice } from '../components/booksource/ScopeSelectSheet';
import { ContentQualitySheet } from '../components/booksource/ContentQualitySheet';
import { ExpandedSourceContent } from '../components/booksource/ExpandedSourceContent';
import { SearchSettingsSheet } from '../components/booksource/SearchSettingsSheet';
import {
  BookShelfState, SearchBookGridItem, SearchBookListItem, searchBookToBook
} from '../components/booksource/SearchBookItems';
import { SearchBookPreviewSheet } from '../components/booksource/SearchBookPreviewSheet';
import {
  BookshelfConflict, BookshelfConflictSheet, ConflictBookSummary
} from '../components/booksource/BookshelfConflictSheet';
import { LoadMoreFooter } from '../components/booksource/LoadMoreFooter';
import {
  BODY_MEDIUM, BODY_SMALL, LABEL_LARGE, LABEL_MEDIUM, LABEL_SMALL, TITLE_SMALL
} from '../components/typography/TypographyTokens';
import {
  HEADER_COLLAPSE_THRESHOLD, HEADER_EXPAND_THRESHOLD, SPACE_12, SPACE_16, SPACE_24, SPACE_4, SPACE_8
} from '../components/UiTokens';

/** 上游 `SearchScreen.kt:187` 的 `debounce(200)`。 */
const QUERY_DEBOUNCE_MS: number = 200;
/** 上游 `SearchScreen.kt:531` 的列表 `contentPadding(top = 48.dp, bottom = 8.dp)`。 */
const RESULT_LIST_TOP_PADDING: number = 48;
const RESULT_LIST_BOTTOM_PADDING: number = 8;
/** 上游平铺列表 `spacedBy(8.dp)`，分组列表 `spacedBy(4.dp)`。 */
const FLAT_ITEM_GAP: number = 8;
const GROUPED_ITEM_GAP: number = 4;
/** 上游 `SearchSourceSection.kt:108` 的横向卡片宽 100dp。 */
const SOURCE_SECTION_ITEM_WIDTH: number = 100;
/** 上游 `SearchSourceSection.kt:86` 的 `spacedBy(12.dp)` 与 `gradientWidth = 16.dp`。 */
const SOURCE_SECTION_GAP: number = 12;
const SOURCE_SECTION_FADE: number = 16;
/** 上游 `SearchScreen.kt:592` 的计数卡 `padding(top = 6.dp)`。 */
const FLOATING_SUMMARY_TOP: number = 6;
/** 上游 `SearchViewModel.kt:52` 的 `EXACT_SEARCH_SINGLE_PAGE_RESULT_THRESHOLD = 3`。 */
const EXACT_SEARCH_SINGLE_PAGE_RESULT_THRESHOLD: number = 3;
/** 空书源占位（`SearchBookItem` 无默认值构造，ArkTS 需要显式给一个）。 */
const EMPTY_SEARCH_BOOK: SearchBookItem = {
  bookUrl: '', origin: '', originName: '', name: '', author: '', kind: '',
  coverUrl: '', intro: '', lastChapter: '', wordCount: '', updateTime: '', tocUrl: ''
};

/** 一个「按来源分组」的结果段：对齐上游 `SourceGroup(origin, sourceName, items)`。 */
interface SourceGroup {
  origin: string;
  sourceName: string;
  items: SearchResultItemUi[];
}

@Component
export struct SearchPage {
  @StorageProp('themeColorTextPrimary') themeColorTextPrimary: string = '#1B1C22';
  @StorageProp('themeColorTextSecondary') themeColorTextSecondary: string = '#4A4C55';
  @StorageProp('themeColorTextTertiary') themeColorTextTertiary: string = '#6A6D77';
  @StorageProp('themeColorAccent') themeColorAccent: string = '#3F5BD9';
  @StorageProp('themeColorSurfacePrimary') themeColorSurfacePrimary: string = '#F5F6F8';
  @StorageProp('themeColorSurfaceTertiary') themeColorSurfaceTertiary: string = '#F0F1F5';
  @StorageProp('themeColorSurfaceElevated') themeColorSurfaceElevated: string = '#FFFFFF';
  @StorageProp('themeColorSurfaceContainer') themeColorSurfaceContainer: string = '#F1F2F6';
  @StorageProp('themeColorSurfaceContainerLow') themeColorSurfaceContainerLow: string = '#F7F7FB';
  @StorageProp('themeColorOnCardContainer') themeColorOnCardContainer: string = '#4C662B';
  @StorageProp('themeColorSecondaryContainer') themeColorSecondaryContainer: string = '#DDE1F5';
  @StorageProp('themeColorOnSecondaryContainer') themeColorOnSecondaryContainer: string = '#00174B';
  @StorageProp('themeColorOutlineVariant') themeColorOutlineVariant: string = '#C6C7D0';
  @StorageProp('themeAppBackground') themeAppBackground: string = '';
  @StorageProp('themePureBlack') themePureBlack: boolean = false;

  /** 书架全量（提示区与书架状态判定都读它）。 */
  @Prop books: Book[] = [];
  /** 分组定义（私密分组集合用来过滤提示区）。 */
  @Prop groups: BookGroup[] = [];
  /** 进页时的初始关键词（上游从导航参数带入）。 */
  @Prop initialQuery: string = '';
  @Prop coverSettings: CoverSettings = DEFAULT_COVER_SETTINGS;
  @Prop isNight: boolean = false;

  onBack: () => void = () => {};
  /** 上游 `SearchEffect.OpenBookInfo` → `onBookClick(SearchBook, sharedCoverKey)`。 */
  onOpenBookInfo: (item: SearchBookItem, sharedCoverKey: string) => void =
    (_item: SearchBookItem, _sharedCoverKey: string) => {};
  /** 上游 `SearchIntent.AddToShelf`：返回该书的全部副本，非空即需要弹冲突面板。 */
  onAddToShelf: (item: SearchBookItem) => Promise<ConflictBookSummary[]> =
    (_item: SearchBookItem) => Promise.resolve([]);
  /** 上游冲突面板的四种处置。空串表示成功。 */
  onResolveShelfConflict: (existingBookUrl: string, incomingBookUrl: string, mode: string,
    options: ChangeSourceMigrationOptions) => Promise<string> =
    (_existing: string, _incoming: string, _mode: string, _options: ChangeSourceMigrationOptions) => Promise.resolve('');
  onOpenSourceManage: () => void = () => {};
  /** 建议区点书架里的书 → 打开阅读（上游 `SearchIntent.OpenBookshelfBook`）。 */
  onOpenBookshelfBook: (book: Book) => void = (_book: Book) => {};
  /** 上游 `SearchEffect.ShowMessage`。 */
  onMessage: (message: string) => void = (_message: string) => {};
  /** 关键词/范围变化回写给 Index 做持久化（跨页返回保持）。 */
  onQueryPersist: (query: string) => void = (_query: string) => {};
  onScopePersist: (scopeRaw: string) => void = (_scopeRaw: string) => {};

  /** 41 字段统一状态；上游是 `MutableStateFlow<SearchUiState>`。 */
  @State state: SearchUiState = emptySearchUiState();
  @State collapsedHeader: boolean = false;

  /** 当前搜索页号（上游 ViewModel 私有字段 `currentSearchPage`）。 */
  private currentSearchPage: number = 1;
  /**
   * 本页开始前的已合并结果数（上游 `SearchViewModel.kt:118 resultCountBeforeCurrentPage`）。
   *
   * 上游在 `startSearch` 里先记下 `searchResultBooks.size`（`:640`），Finished 时用它判
   * `searchResultBooks.size > resultCountBeforeCurrentPage`（`:700`），即「本页比开始前
   * 多出了结果」。第 2 页若全是第 1 页已有的重复书，这个判据为假 → 不再有下一页。
   */
  private resultCountBeforePage: number = 0;
  /** 加载代次：换关键词/换范围时自增，回来对不上就丢弃（上游 `searchJob?.cancel()`）。 */
  private generation: number = 0;
  /** 手动停止标记：`shouldCancel` 读它。 */
  private stopFlag: boolean = false;
  /** 输入框文本（`SearchBar` 自持，这里留一份用于提交归一化）。 */
  private queryInput: string = '';
  /** 提交时用来抑制一次防抖（上游 `ignoreNextDebouncedQuery`）。 */
  private ignoreNextDebouncedQuery: string = '';
  /** 结果是否吸顶（上游 `keepResultsPinnedToTop`）。 */
  private keepResultsPinnedToTop: boolean = true;
  private queryDebounceTimer: number = 0;
  /** 提示区缓存：`books` 变化才重算，避免每帧过滤 900 本书。 */
  private hintCacheKey: string = '';
  private hintCache: SearchShelfHint[] = [];
  private flatScroller: Scroller = new Scroller();
  private groupedScroller: Scroller = new Scroller();
  private expandedScroller: Scroller = new Scroller();

  // ───────────────────────── 生命周期 ─────────────────────────

  aboutToAppear(): void {
    this.queryInput = this.initialQuery;
    this.restorePreferences();
    void this.loadHistory();
    this.refreshHints();
    if (this.initialQuery.trim().length > 0) {
      this.submitSearch(this.initialQuery);
    }
  }

  aboutToDisappear(): void {
    // 上游 `DisposableEffect(Unit) { onDispose { PauseEngine } }`：离开页面停止派发新源。
    this.stopFlag = true;
    clearTimeout(this.queryDebounceTimer);
    this.saveScrollState();
  }

  /** 读持久化的布局模式 / 范围 / 精准开关（上游 `SearchViewModel.kt:442-490`）。 */
  private restorePreferences(): void {
    const context = getContext(this);
    try {
      const mode = LocalPreferencesRepository.getInt(LocalPreferencesKeys.SEARCH_LAYOUT_MODE, 0);
      const scopeRaw = LocalPreferencesRepository.getString(LocalPreferencesKeys.SEARCH_SCOPE, '');
      const exact = LocalPreferencesRepository.getBoolean(LocalPreferencesKeys.MATCH_MODE, false);
      this.applyLayoutMode(mode);
      this.applyScope(scopeRaw);
      this.patch((next: SearchUiState) => { next.exactMatch = exact; });
    } catch (error) {
      console.error(`搜索偏好读取失败：${error instanceof Error ? error.message : String(error)}`);
    }
    // 首次进入时把默认值也落一次，保证后续读到的是显式值。
    void this.persistLayoutMode(this.state.layoutMode);
  }

  // ───────────────────────── 状态工具 ─────────────────────────

  /** 41 字段整体拷贝；上游每个 Intent 都走 `_state.update { it.copy(...) }`。 */
  private cloneState(): SearchUiState {
    const src = this.state;
    const next = emptySearchUiState();
    next.query = src.query;
    next.committedQuery = src.committedQuery;
    next.results = src.results;
    next.history = src.history;
    next.bookshelfHints = src.bookshelfHints;
    next.enabledGroups = src.enabledGroups;
    next.enabledSources = src.enabledSources;
    next.scopeDisplay = src.scopeDisplay;
    next.scopeDisplayNames = src.scopeDisplayNames;
    next.selectedScopeSourceUrls = src.selectedScopeSourceUrls;
    next.isAllScope = src.isAllScope;
    next.isSourceScope = src.isSourceScope;
    next.exactMatch = src.exactMatch;
    next.isSearching = src.isSearching;
    next.isManualStop = src.isManualStop;
    next.hasMore = src.hasMore;
    next.processedSources = src.processedSources;
    next.totalSources = src.totalSources;
    next.selectedSourceTypes = src.selectedSourceTypes;
    next.showScopeSheet = src.showScopeSheet;
    next.showSettingsSheet = src.showSettingsSheet;
    next.showClearHistoryDialog = src.showClearHistoryDialog;
    next.showSuggestions = src.showSuggestions;
    next.emptyScopeAction = src.emptyScopeAction;
    next.savedScrollIndex = src.savedScrollIndex;
    next.savedScrollOffset = src.savedScrollOffset;
    next.expandedSourceUrl = src.expandedSourceUrl;
    next.expandedSourceName = src.expandedSourceName;
    next.expandedSourceBooks = src.expandedSourceBooks;
    next.expandedSourceLoading = src.expandedSourceLoading;
    next.expandedSourceEnd = src.expandedSourceEnd;
    next.expandedSourceError = src.expandedSourceError;
    next.expandedSourcePage = src.expandedSourcePage;
    next.showExpandedSource = src.showExpandedSource;
    next.layoutMode = src.layoutMode;
    next.expandedSourceSavedScrollIndex = src.expandedSourceSavedScrollIndex;
    next.expandedSourceSavedScrollOffset = src.expandedSourceSavedScrollOffset;
    next.contentQuality = src.contentQuality;
    next.bookshelfConflict = src.bookshelfConflict;
    next.isResolvingBookshelfConflict = src.isResolvingBookshelfConflict;
    return next;
  }

  /** 统一改状态入口：拷一份 → 交给回调改 → 整体替换（触发 ArkUI 重渲染）。 */
  private patch(updater: (next: SearchUiState) => void): void {
    const next = this.cloneState();
    updater(next);
    this.state = next;
  }

  private intentOf(kind: SearchIntentKind): SearchIntent {
    return searchIntent(kind);
  }

  // ───────────────────────── 派生值（@Builder 里只能用方法，不能用 getter） ─────────────────────────

  private resultsOf(): SearchResultItemUi[] {
    return this.state.results;
  }

  private layoutModeOf(): number {
    return this.state.layoutMode;
  }

  private isSourceGroupedMode(): boolean {
    return this.state.layoutMode === 1;
  }

  private showSuggestionsOf(): boolean {
    return this.state.showSuggestions;
  }

  private isSearchingOf(): boolean {
    return this.state.isSearching;
  }

  private hasMoreOf(): boolean {
    return this.state.hasMore;
  }

  private committedQueryOf(): string {
    return this.state.committedQuery;
  }

  private processedSourcesOf(): number {
    return this.state.processedSources;
  }

  private totalSourcesOf(): number {
    return this.state.totalSources;
  }

  /** 上游 `:308-310`：计数卡在「已提交或正在搜」时出现；进度卡在「有源总数」时出现。 */
  private showResultCountCard(): boolean {
    return this.state.committedQuery.length > 0 || this.state.isSearching;
  }

  private showSourceProgressCard(): boolean {
    return this.state.totalSources > 0;
  }

  private resultCountText(): string {
    return `结果 ${this.state.results.length}`;
  }

  private sourceProgressText(): string {
    return ` · 进度 ${this.state.processedSources}/${this.state.totalSources}`;
  }

  /** 上游 `:392` `showFab = isSearching || (committedQuery.isNotBlank() && hasMore)`。 */
  private showFab(): boolean {
    return this.state.isSearching || (this.state.committedQuery.length > 0 && this.state.hasMore);
  }

  private fabIconOf(): AppGlyphName {
    return this.state.isSearching ? 'stop' : 'playArrow';
  }

  private fabTooltipOf(): string {
    return this.state.isSearching ? '停止' : '开始';
  }

  private fabLabelOf(): string {
    return this.state.isSearching ? '停止搜索' : '加载更多';
  }

  /** 上游 `SearchScreen.kt:203-212`：允许触底加载的四个条件。 */
  private readyToLoad(): boolean {
    return !this.state.isSearching && this.state.hasMore && !this.state.isManualStop && !this.state.showSuggestions;
  }

  /** 上游 `:170-183` 的 `shouldLoadMore`：`total > 0 && lastVisible >= total - 3`。 */
  private shouldLoadMore(lastVisible: number, total: number): boolean {
    return total > 0 && lastVisible >= total - 3;
  }

  private isAllScopeOf(): boolean {
    return this.state.isAllScope;
  }

  private scopeDisplayOf(): string {
    return this.state.scopeDisplay;
  }

  private selectedScopeSourceUrlsOf(): string[] {
    return this.state.selectedScopeSourceUrls;
  }

  private scopeDisplayNamesOf(): string[] {
    return this.state.scopeDisplayNames;
  }

  private isSourceScopeOf(): boolean {
    return this.state.isSourceScope;
  }

  private contentQualityOf(): ContentQualityUiState {
    return this.state.contentQuality;
  }

  /** 内容质量检测阶段：-1 表示未开始（`ContentQualityStage` 是枚举，用 -1 当哨兵）。 */
  private contentQualityStageOf(): number {
    const quality = this.state.contentQuality;
    if (!quality.isRunning && quality.results.size === 0 && quality.processedBooks === 0) {
      return -1;
    }
    return quality.stage as number;
  }

  private excludedCountOf(): number {
    let count = 0;
    this.state.contentQuality.results.forEach((value: ContentQualityResultUi) => {
      if (value.excluded) { count += 1; }
    });
    return count;
  }

  private isQualityMasked(book: SearchBookItem): boolean {
    const hit = this.state.contentQuality.results.get(qualityKeyOf(book));
    return hit !== undefined && hit.excluded;
  }

  // ───────────────────────── 书架提示区与私密过滤 ─────────────────────────

  /** 私密分组 id 集合（上游 `rememberPrivateLockedBookUrls` 的入参来源）。 */
  private privateGroupIds(): number[] {
    const ids: number[] = [];
    for (const group of this.groups) {
      if (group.isPrivate) { ids.push(group.groupId); }
    }
    return ids;
  }

  /** 私密书在提示区必须过滤掉，否则会把书名/作者泄漏给未解锁用户（上游 A-6/E-7）。 */
  private isHintLocked(book: Book): boolean {
    return isPrivateBook(book, this.privateGroupIds());
  }

  /** 书架提示：可持久化的书，去掉私密书。 */
  private refreshHints(): void {
    const shelf = this.books.filter((book: Book) => BookRepository.isPersistableBook(book));
    let key = `${shelf.length}|${this.privateGroupIds().length}`;
    for (const book of shelf) {
      key += `|${book.id}:${book.title}:${book.author}`;
    }
    if (key === this.hintCacheKey) { return; }
    this.hintCacheKey = key;
    const hints: SearchShelfHint[] = [];
    for (const book of shelf) {
      if (this.isHintLocked(book)) { continue; }
      hints.push({ bookUrl: book.contentPath ?? book.id, name: book.title, author: book.author });
    }
    this.hintCache = hints;
    this.patch((next: SearchUiState) => { next.bookshelfHints = hints; });
  }

  /** 结果项的书架状态：先判在架（contentPath 相等），再判同名同作者。 */
  private shelfStateOf(item: SearchBookItem): BookShelfState {
    const shelf = this.books.filter((book: Book) => BookRepository.isPersistableBook(book));
    for (const book of shelf) {
      if ((book.contentPath ?? '') === item.bookUrl) { return BookShelfState.IN_SHELF; }
    }
    for (const book of shelf) {
      if (book.title === item.name && book.author === item.author) {
        return BookShelfState.SAME_NAME_AUTHOR;
      }
    }
    return BookShelfState.NOT_IN_SHELF;
  }

  /** 把合并结果包成 `SearchResultItemUi`（上游 `:1040-1063` 的 mergeSearchResults）。 */
  private wrapResults(merged: MergedBook[]): SearchResultItemUi[] {
    const list: SearchResultItemUi[] = [];
    for (const item of merged) {
      // `originCount` 直接取合并层的命中源数（上游 `book.origins.size`），不做回算。
      list.push({ book: item.book, shelfState: this.shelfStateOf(item.book), originCount: item.originCount });
    }
    return list;
  }

  // ───────────────────────── 历史 ─────────────────────────

  private async loadHistory(): Promise<void> {
    try {
      const history = await SearchKeywordRepository.loadAll(getContext(this));
      this.patch((next: SearchUiState) => { next.history = history; });
    } catch (error) {
      console.error(`搜索历史读取失败：${error instanceof Error ? error.message : String(error)}`);
      this.patch((next: SearchUiState) => { next.history = []; });
    }
  }

  private async rememberKeyword(keyword: string): Promise<void> {
    try {
      await SearchKeywordRepository.saveKeyword(getContext(this), keyword);
      await this.loadHistory();
    } catch (error) {
      console.error(`搜索历史写入失败：${error instanceof Error ? error.message : String(error)}`);
    }
  }

  // ───────────────────────── 范围编解码 ─────────────────────────

  /** 把 scope 原始串落到状态：组集合 / 源集合 / 全部 / 单源标志。 */
  private applyScope(scopeRaw: string): void {
    const groupNames = scopeGroupNames(scopeRaw);
    const sourceUrls = scopeSourceUrls(scopeRaw);
    const allSources = BookSourceRepository.getAll();
    const enabled: BookSource[] = [];
    for (const source of allSources) {
      if (source.enabled) { enabled.push(source); }
    }
    // 上游 `getBookSourceParts()` 最终 `sortedBy { it.customOrder }`。
    enabled.sort((left: BookSource, right: BookSource) => left.customOrder - right.customOrder);
    this.patch((next: SearchUiState) => {
      next.enabledSources = enabled;
      next.enabledGroups = groupNames;
      next.selectedScopeSourceUrls = sourceUrls;
      next.scopeDisplay = scopeDisplay(scopeRaw, '全部书源');
      next.scopeDisplayNames = scopeDisplayNames(scopeRaw);
      next.isAllScope = scopeIsAll(scopeRaw);
      next.isSourceScope = scopeIsSource(scopeRaw);
    });
  }

  /** 应用一次范围选择（上游 `ApplyScopeSelection`）。 */
  private applyScopeSelection(groupNames: string[], sources: ScopeSourceChoice[], isSourceScope: boolean): void {
    let raw = '';
    if (sources.length > 0) {
      // 上游 `encodeSourceScope(name, url)` 逐项编码；本地 `encodeSources` 内部走同一规则。
      raw = encodeSources(sources);
    } else if (groupNames.length > 0) {
      raw = encodeGroups(groupNames);
    }
    this.onScopePersist(raw);
    void this.persistScope(raw);
    this.applyScope(raw);
    this.patch((next: SearchUiState) => { next.showScopeSheet = false; });
    // 上游 `restartCommittedSearchIfNeeded`：范围变了且已有关键词，就重搜。
    if (this.state.committedQuery.length > 0) {
      this.startSearch(this.state.committedQuery, 1);
    }
  }

  private async persistScope(scopeRaw: string): Promise<void> {
    try {
      await LocalPreferencesRepository.putString(getContext(this), LocalPreferencesKeys.SEARCH_SCOPE, scopeRaw);
    } catch (error) {
      console.error(`搜索范围保存失败：${error instanceof Error ? error.message : String(error)}`);
    }
  }

  private applyLayoutMode(mode: number): void {
    const normalized = mode === 1 ? 1 : 0;
    this.patch((next: SearchUiState) => { next.layoutMode = normalized; });
  }

  private async persistLayoutMode(mode: number): Promise<void> {
    try {
      await LocalPreferencesRepository.putInt(getContext(this), LocalPreferencesKeys.SEARCH_LAYOUT_MODE, mode);
    } catch (error) {
      console.error(`搜索布局保存失败：${error instanceof Error ? error.message : String(error)}`);
    }
  }

  private async persistMatchMode(exact: boolean): Promise<void> {
    try {
      await LocalPreferencesRepository.putBoolean(getContext(this), LocalPreferencesKeys.MATCH_MODE, exact);
    } catch (error) {
      console.error(`精准搜索开关保存失败：${error instanceof Error ? error.message : String(error)}`);
    }
  }

  // ───────────────────────── 搜索主流程 ─────────────────────────

  /**
   * 提交搜索（上游 `submitSearch` :579-619）：归一化 → 抑制一次防抖 → 重置结果 → 从第 1 页开始。
   * 空关键词直接忽略。
   */
  private submitSearch(rawQuery: string): void {
    const normalized = rawQuery.trim();
    if (normalized.length === 0) { return; }
    this.ignoreNextDebouncedQuery = normalized;
    this.queryInput = normalized;
    if (normalized !== this.state.query) {
      this.patch((next: SearchUiState) => { next.query = normalized; });
    }
    this.onQueryPersist(normalized);
    void this.rememberKeyword(normalized);
    this.stopFlag = false;
    this.generation += 1;
    this.currentSearchPage = 1;
    this.keepResultsPinnedToTop = true;
    this.patch((next: SearchUiState) => {
      next.committedQuery = normalized;
      next.results = [];
      next.isSearching = false;
      next.isManualStop = false;
      next.hasMore = true;
      next.processedSources = 0;
      next.totalSources = 0;
      next.showSuggestions = false;
      next.emptyScopeAction = undefined;
      next.contentQuality = emptyContentQualityUiState();
      next.expandedSourceUrl = '';
      next.expandedSourceName = '';
      next.expandedSourceBooks = [];
      next.expandedSourcePage = 1;
      next.showExpandedSource = false;
    });
    this.startSearch(normalized, 1);
  }

  /**
   * 执行一页搜索。上游 `startSearch(keyword, page)` → `SearchBooksUseCase.execute`。
   * 第 1 页替换结果，后续页追加（`mergeSearchResults`）。
   */
  private async startSearch(keyword: string, page: number): Promise<void> {
    const generation = this.generation;
    // 上游 `:640 resultCountBeforeCurrentPage = searchResultBooks.size`。
    this.resultCountBeforePage = this.state.results.length;
    this.patch((next: SearchUiState) => {
      next.isSearching = true;
      next.isManualStop = false;
    });
    try {
      await BookSourceRepository.load(getContext(this));
    } catch (error) {
      if (generation !== this.generation) { return; }
      this.patch((next: SearchUiState) => { next.isSearching = false; });
      this.emitEffect(showMessageEffect('书源载入失败'));
      return;
    }
    const scope: SearchScopeFilter = {
      groups: this.state.enabledGroups,
      sourceUrls: this.state.selectedScopeSourceUrls,
      types: this.state.selectedSourceTypes
    };
    if (!SearchCoordinator.hasSearchableSource(scope)) {
      if (generation !== this.generation) { return; }
      this.patch((next: SearchUiState) => { next.isSearching = false; next.hasMore = false; });
      this.emitEffect(showMessageEffect('没有可搜索的在线书源，请先到书源管理导入并启用'));
      return;
    }
    const outcome: SearchOutcome = await SearchCoordinator.search(
      keyword, page, this.state.exactMatch, scope,
      (progress: SearchProgress) => {
        if (generation !== this.generation) { return; }
        // 边搜边出：每完成一个源就把当前合并快照刷进结果。
        this.patch((next: SearchUiState) => {
          next.results = this.wrapResults(progress.books);
          next.processedSources = progress.finished;
          next.totalSources = progress.total;
        });
      },
      () => this.stopFlag
    );
    if (generation !== this.generation) { return; }
    // 上游 `:131 gateway.saveSearchBooks(result.books)`：每页结果落 searchBooks 表。
    const pageBooks: SearchBookItem[] = [];
    for (const item of outcome.books) { pageBooks.push(item.book); }
    try {
      await SearchBookRepository.save(getContext(this), pageBooks);
    } catch (error) {
      console.error(`搜索结果落库失败：${error instanceof Error ? error.message : String(error)}`);
    }
    const results = this.wrapResults(outcome.books);
    // 上游 `:694 val hasNewPageResults = searchResultBooks.size > resultCountBeforeCurrentPage`
    // 表达的是「本页比搜索前多出了结果」，不是「本页有结果」。第 2 页若全是重复书，
    // 上游判 false（不再有下一页），本地只判 length>0 会误判成还有下一页。
    const hasNewPageResults = results.length > this.resultCountBeforePage;
    // 上游 `:669-715 handleSearchEvent(Finished)`：hasMore 由「有新增结果 + 支持下一页 + 未到上限」共同决定。
    const exactShouldStop = this.state.exactMatch &&
      results.length < EXACT_SEARCH_SINGLE_PAGE_RESULT_THRESHOLD && page === 1;
    const more = outcome.supportsNextPage && hasNewPageResults &&
      !outcome.resultLimitReached && !exactShouldStop;
    this.patch((next: SearchUiState) => {
      next.results = results;
      next.isSearching = false;
      next.processedSources = outcome.sourceFinished;
      next.totalSources = outcome.sourceTotal;
      // 手动停止时不动 hasMore：上游 `stopSearch` 是 `searchJob?.cancel()`，协程被取消后
      // Finished 事件根本不发，hasMore 保持取消前的值。本地 `SearchCoordinator.search`
      // 用返回值 `cancelled` 表达取消、仍会走到这里，若不跳过就会把 hasMore 覆盖成 false，
      // FAB 随之消失（它的显示条件依赖 hasMore），用户再也点不到「开始」继续加载。
      if (!outcome.cancelled) {
        next.hasMore = more;
      }
      next.isManualStop = outcome.cancelled;
      if (results.length === 0 && !outcome.cancelled && !next.isAllScope) {
        next.emptyScopeAction = {
          scopeDisplay: next.scopeDisplay, wasExactMatch: next.exactMatch
        } as SearchEmptyScopeAction;
      }
    });
    // 搜索中结果吸顶（上游 `:282-290`）。
    if (this.keepResultsPinnedToTop && results.length > 0) {
      this.scrollResultsToTop();
    }
  }

  /** 加载下一页（上游 `loadMore` :621-635）。 */
  private loadMore(): void {
    if (this.state.committedQuery.length === 0) { return; }
    if (this.state.isSearching) { return; }
    if (!this.state.hasMore) { return; }
    this.currentSearchPage += 1;
    this.startSearch(this.state.committedQuery, this.currentSearchPage);
  }

  private stopSearch(): void {
    this.stopFlag = true;
    this.patch((next: SearchUiState) => {
      // 上游 `SearchViewModel.kt:717-727 stopSearch(manualStop = true)` 只改这两项：
      // `isSearching = false` 与 `isManualStop = manualStop || it.isManualStop`。
      // **不能动 hasMore**——它表达的是「还有下一页可取」，与「这次搜索是否被手动停掉」
      // 是两件事。上游 FAB 的显示条件 `:392 showFab = isSearching || (committedQuery
      // .isNotBlank() && hasMore)` 正是靠 hasMore 在停止后仍为真，才把按钮从 Stop 换成
      // PlayArrow「开始」，让用户能继续加载下一页。这里若一并置 false，FAB 会直接消失，
      // 用户再也点不到「开始」。
      next.isManualStop = true;
      next.isSearching = false;
    });
  }

  private clearResults(): void {
    this.patch((next: SearchUiState) => {
      next.results = [];
      next.committedQuery = '';
      next.hasMore = true;
      next.isManualStop = false;
      next.processedSources = 0;
      next.totalSources = 0;
      next.emptyScopeAction = undefined;
    });
  }

  private scrollResultsToTop(): void {
    if (this.isSourceGroupedMode()) {
      this.groupedScroller.scrollToIndex(0, true);
    } else {
      this.flatScroller.scrollToIndex(0, true);
    }
  }

  /** 滚动位置保存（上游 `SaveScrollState`）。 */
  private saveScrollState(): void {
    const offset = this.isSourceGroupedMode()
      ? this.groupedScroller.currentOffset().yOffset
      : this.flatScroller.currentOffset().yOffset;
    if (offset <= 0) { return; }
    const index = this.isSourceGroupedMode() ? this.groupedFirstIndex : this.flatFirstIndex;
    this.patch((next: SearchUiState) => {
      next.savedScrollIndex = index;
      next.savedScrollOffset = Math.round(offset);
    });
  }

  private flatFirstIndex: number = 0;
  private groupedFirstIndex: number = 0;

  /** 进页恢复滚动（上游 `:252-259`）。 */
  private restoreScrollState(): void {
    const index = this.state.savedScrollIndex;
    const offset = this.state.savedScrollOffset;
    if (index <= 0 && offset <= 0) { return; }
    if (this.isSourceGroupedMode()) {
      this.groupedScroller.scrollToIndex(index, false, ScrollAlign.START);
    } else {
      this.flatScroller.scrollToIndex(index, false, ScrollAlign.START);
    }
    this.patch((next: SearchUiState) => {
      next.savedScrollIndex = 0;
      next.savedScrollOffset = 0;
    });
  }

  // ───────────────────────── Effect ─────────────────────────

  /** 三类 Effect 的统一出口（上游 `SearchEffect`）。 */
  private emitEffect(effect: SearchEffect): void {
    if (effect.kind === 'OpenBookInfo') {
      const item: SearchBookItem = {
        bookUrl: effect.bookUrl, origin: effect.origin, originName: '', name: effect.name,
        author: effect.author, kind: '', coverUrl: effect.coverPath, intro: '',
        lastChapter: '', wordCount: '', updateTime: '', tocUrl: effect.bookUrl
      };
      this.onOpenBookInfo(item, effect.sharedCoverKey);
      return;
    }
    if (effect.kind === 'OpenSourceManage') {
      this.onOpenSourceManage();
      return;
    }
    this.onMessage(effect.message);
  }

  // ───────────────────────── 45 类 Intent ─────────────────────────

  private onIntent(intent: SearchIntent): void {
    switch (intent.kind) {
      case 'Initialize':
        this.refreshHints();
        this.applyScope(intent.scopeRaw);
        break;
      case 'UpdateQuery':
        this.updateQuery(intent.query);
        break;
      case 'SubmitSearch':
        this.submitSearch(this.queryInput);
        break;
      case 'LoadMore':
        this.loadMore();
        break;
      case 'StopSearch':
        this.stopSearch();
        break;
      case 'ClearSearchResults':
        this.clearResults();
        break;
      case 'PauseEngine':
        this.stopFlag = true;
        break;
      case 'ResumeEngine':
        this.stopFlag = false;
        break;
      case 'UseHistoryKeyword':
        this.useHistoryKeyword(intent.keyword);
        break;
      case 'OpenSearchBook':
        this.openSearchBook(intent.book, intent.sharedCoverKey);
        break;
      case 'AddToShelf':
        void this.requestAddToShelf(intent.book);
        break;
      case 'OpenBookshelfBook':
        this.openBookshelfBook(intent.book === undefined ? undefined : searchBookToBook(intent.book));
        break;
      case 'ExpandSource':
        void this.expandSource(intent.key);
        break;
      case 'DismissExpandedSource':
        this.patch((next: SearchUiState) => { next.showExpandedSource = false; });
        break;
      case 'LoadMoreExpandedSource':
        void this.loadExpandedSourcePage();
        break;
      case 'OpenExpandedSourceBook':
        this.openSearchBook(intent.book, '');
        break;
      case 'DeleteHistory':
        void this.deleteHistory(intent.keyword);
        break;
      case 'SetClearHistoryDialogVisible':
        this.patch((next: SearchUiState) => { next.showClearHistoryDialog = intent.visible; });
        break;
      case 'ConfirmClearHistory':
        void this.clearHistory();
        break;
      case 'SetScopeSheetVisible':
        this.patch((next: SearchUiState) => { next.showScopeSheet = intent.visible; });
        break;
      case 'SetSettingsSheetVisible':
        this.patch((next: SearchUiState) => { next.showSettingsSheet = intent.visible; });
        break;
      case 'OpenContentQuality':
        this.openContentQuality();
        break;
      case 'CloseContentQuality':
        this.closeContentQuality();
        break;
      case 'UpdateContentQualityChapterSpec':
        this.patchContentQuality((quality: ContentQualityUiState) => { quality.chapterSpec = intent.value; });
        break;
      case 'UpdateContentQualityKeywords':
        this.patchContentQuality((quality: ContentQualityUiState) => { quality.keywords = intent.value; });
        break;
      case 'UpdateContentQualitySkipHeadChars':
        this.patchContentQuality((quality: ContentQualityUiState) => { quality.skipHeadChars = intent.value; });
        break;
      case 'StartContentQuality':
        void this.startContentQuality();
        break;
      case 'SetLayoutMode':
        this.applyLayoutMode(intent.mode);
        void this.persistLayoutMode(intent.mode);
        break;
      case 'ToggleSourceType':
        this.toggleSourceType(intent.type);
        break;
      case 'ClearAllSourceTypes':
        this.clearAllSourceTypes();
        break;
      case 'SelectAllScope':
        this.applyScopeSelection([], [], false);
        break;
      case 'ApplyScopeSelection':
        this.applyScopeSelection(intent.groupNames, this.choicesOf(intent.sources), intent.isSourceScope);
        break;
      case 'ToggleScopeGroup':
        this.toggleScopeGroup(intent.groupName);
        break;
      case 'ToggleScopeSource':
        this.toggleScopeSource(intent.source);
        break;
      case 'RemoveScopeItem':
        this.removeScopeItem(intent.scopeName);
        break;
      case 'SetMatchMode':
        this.patch((next: SearchUiState) => { next.exactMatch = intent.mode === 1; });
        void this.persistMatchMode(intent.mode === 1);
        if (this.state.committedQuery.length > 0) {
          this.startSearch(this.state.committedQuery, 1);
        }
        break;
      case 'ConfirmEmptyScopeAction':
        void this.confirmEmptyScopeAction();
        break;
      case 'DismissEmptyScopeAction':
        this.patch((next: SearchUiState) => { next.emptyScopeAction = undefined; });
        break;
      case 'OpenSourceManage':
        this.emitEffect(searchEffect('OpenSourceManage'));
        break;
      case 'SaveScrollState':
        this.patch((next: SearchUiState) => {
          next.savedScrollIndex = intent.index;
          next.savedScrollOffset = intent.offset;
        });
        break;
      case 'SaveExpandedSourceScrollState':
        this.patch((next: SearchUiState) => {
          next.expandedSourceSavedScrollIndex = intent.index;
          next.expandedSourceSavedScrollOffset = intent.offset;
        });
        break;
      case 'DismissBookshelfConflict':
        this.patch((next: SearchUiState) => {
          next.bookshelfConflict = undefined;
          next.isResolvingBookshelfConflict = false;
        });
        break;
      case 'OpenBookshelfConflictBook':
        this.openBookshelfConflictBook();
        break;
      case 'CoexistWithBookshelfConflict':
        void this.resolveBookshelfConflict(intent.existingBookUrl, intent.options ?? defaultMigrationOptions(), true);
        break;
      case 'MigrateBookshelfConflict':
        void this.resolveBookshelfConflict(intent.existingBookUrl, intent.options ?? defaultMigrationOptions(), false);
        break;
      default:
        break;
    }
  }

  /** 输入变化：只改 `query`（上游 `updateQuery` :559-577），防抖后提交。 */
  private updateQuery(query: string): void {
    this.queryInput = query;
    this.patch((next: SearchUiState) => {
      next.query = query;
      next.showSuggestions = query.trim().length === 0;
    });
    clearTimeout(this.queryDebounceTimer);
    if (query.trim().length === 0) {
      this.clearResults();
      return;
    }
    this.queryDebounceTimer = setTimeout(() => {
      const trimmed = query.trim();
      if (this.ignoreNextDebouncedQuery === trimmed) {
        this.ignoreNextDebouncedQuery = '';
        return;
      }
      if (trimmed !== this.state.committedQuery) {
        const intent = this.intentOf('UpdateQuery');
        intent.query = trimmed;
        this.submitSearch(trimmed);
      }
    }, QUERY_DEBOUNCE_MS);
  }

  private useHistoryKeyword(keyword: string): void {
    this.queryInput = keyword;
    this.patch((next: SearchUiState) => { next.query = keyword; });
    this.submitSearch(keyword);
  }

  private async deleteHistory(keyword: string): Promise<void> {
    try {
      await SearchKeywordRepository.deleteKeyword(getContext(this), keyword);
      await this.loadHistory();
    } catch (error) {
      console.error(`搜索历史删除失败：${error instanceof Error ? error.message : String(error)}`);
    }
  }

  private async clearHistory(): Promise<void> {
    try {
      await SearchKeywordRepository.clearAll(getContext(this));
      await this.loadHistory();
    } catch (error) {
      console.error(`搜索历史清空失败：${error instanceof Error ? error.message : String(error)}`);
    }
    this.patch((next: SearchUiState) => { next.showClearHistoryDialog = false; });
  }

  private openSearchBook(book: SearchBookItem | undefined, sharedCoverKey: string): void {
    if (book === undefined) { return; }
    this.emitEffect(openBookInfoEffect(book, sharedCoverKey));
  }

  private openBookshelfBook(book: Book | undefined): void {
    if (book === undefined) { return; }
    this.onOpenBookshelfBook(book);
  }

  // ───────────────────────── 加入书架与冲突 ─────────────────────────

  private async requestAddToShelf(book: SearchBookItem | undefined): Promise<void> {
    if (book === undefined) { return; }
    try {
      const copies = await this.onAddToShelf(book);
      if (copies.length > 0) {
        const conflict: BookshelfConflict = new BookshelfConflict();
        conflict.incoming = this.summaryOf(book);
        conflict.candidates = copies;
        this.patch((next: SearchUiState) => { next.bookshelfConflict = conflict; });
        return;
      }
      this.emitEffect(showMessageEffect('书籍已添加到书架'));
    } catch (error) {
      this.emitEffect(showMessageEffect(`加入书架失败：${error instanceof Error ? error.message : String(error)}`));
    }
  }

  private summaryOf(book: SearchBookItem): ConflictBookSummary {
    const summary: ConflictBookSummary = new ConflictBookSummary();
    summary.bookUrl = book.bookUrl;
    summary.name = book.name;
    summary.author = book.author;
    summary.coverUrl = book.coverUrl;
    summary.origin = book.origin;
    summary.sourceName = book.originName;
    return summary;
  }

  private openBookshelfConflictBook(): void {
    const conflict = this.state.bookshelfConflict;
    if (conflict === undefined) { return; }
    this.patch((next: SearchUiState) => { next.bookshelfConflict = undefined; });
    const incoming = conflict.incoming;
    if (incoming !== undefined) {
      const item: SearchBookItem = {
        bookUrl: incoming.bookUrl, origin: incoming.origin, originName: incoming.sourceName,
        name: incoming.name, author: incoming.author, kind: '',
        coverUrl: incoming.coverUrl ?? '', intro: '', lastChapter: '', wordCount: '',
        updateTime: '', tocUrl: incoming.bookUrl
      };
      this.emitEffect(openBookInfoEffect(item, ''));
    }
  }

  private async resolveBookshelfConflict(existingBookUrl: string, options: ChangeSourceMigrationOptions,
    coexist: boolean): Promise<void> {
    const conflict = this.state.bookshelfConflict;
    if (conflict === undefined) { return; }
    this.patch((next: SearchUiState) => { next.isResolvingBookshelfConflict = true; });
    try {
      const failure = await this.onResolveShelfConflict(
        existingBookUrl, conflict.incoming.bookUrl, coexist ? 'coexist' : 'migrate', options);
      if (failure.length > 0) {
        this.emitEffect(showMessageEffect(failure));
      } else {
        this.emitEffect(showMessageEffect(coexist ? '已加入书架（与原书共存）' : '已迁移进度'));
      }
      this.patch((next: SearchUiState) => {
        next.bookshelfConflict = undefined;
        next.isResolvingBookshelfConflict = false;
      });
    } catch (error) {
      this.patch((next: SearchUiState) => { next.isResolvingBookshelfConflict = false; });
      this.emitEffect(showMessageEffect(`处理书架冲突出错\n${error instanceof Error ? error.message : String(error)}`));
    }
  }

  // ───────────────────────── 内容质量检测 ─────────────────────────

  private patchContentQuality(updater: (quality: ContentQualityUiState) => void): void {
    const current = this.state.contentQuality;
    const nextQuality = emptyContentQualityUiState();
    nextQuality.showSheet = current.showSheet;
    nextQuality.chapterSpec = current.chapterSpec;
    nextQuality.keywords = current.keywords;
    nextQuality.skipHeadChars = current.skipHeadChars;
    nextQuality.isRunning = current.isRunning;
    nextQuality.stage = current.stage;
    nextQuality.processedBooks = current.processedBooks;
    nextQuality.totalBooks = current.totalBooks;
    nextQuality.currentBookName = current.currentBookName;
    nextQuality.results = current.results;
    updater(nextQuality);
    this.patch((next: SearchUiState) => { next.contentQuality = nextQuality; });
  }

  private openContentQuality(): void {
    this.patchContentQuality((quality: ContentQualityUiState) => { quality.showSheet = true; });
    this.patch((next: SearchUiState) => { next.showSettingsSheet = false; });
  }

  private closeContentQuality(): void {
    this.patchContentQuality((quality: ContentQualityUiState) => { quality.showSheet = false; });
  }

  /** 上游 `startContentQuality` :761-818：关键词按分隔符拆开去重，跳过字数兜底 300。 */
  private async startContentQuality(): Promise<void> {
    const quality = this.state.contentQuality;
    const keywords: string[] = [];
    for (const raw of quality.keywords.split(/[,，;；\s]+/)) {
      const word = raw.trim();
      if (word.length > 0 && !keywords.includes(word)) { keywords.push(word); }
    }
    if (keywords.length === 0) { keywords.push('主角'); }
    const skip = Number.parseInt(quality.skipHeadChars, 10);
    const config: ContentQualityConfig = {
      chapterSpec: quality.chapterSpec,
      keywords: keywords,
      skipHeadChars: Number.isNaN(skip) ? 300 : Math.max(skip, 0)
    };
    const books: SearchBookItem[] = [];
    for (const item of this.state.results) { books.push(item.book); }
    this.patchContentQuality((state: ContentQualityUiState) => {
      state.isRunning = true;
      state.stage = ContentQualityStage.ChapterCount;
      state.processedBooks = 0;
      state.totalBooks = books.length;
      state.currentBookName = '';
      state.results = new Map<string, ContentQualityResultUi>();
    });
    const collected = new Map<string, ContentQualityResultUi>();
    await ContentQualityChecker.execute(books, config, (progress: ContentQualityProgress) => {
      this.patchContentQuality((state: ContentQualityUiState) => {
        state.stage = progress.stage;
        state.processedBooks = progress.processedBooks;
        state.totalBooks = progress.totalBooks;
        state.currentBookName = progress.currentBookName;
        state.results = new Map<string, ContentQualityResultUi>(collected);
      });
    }, () => this.stopFlag, (result: ContentQualityResultUi, key: string) => {
      collected.set(key, result);
    });
    this.patchContentQuality((state: ContentQualityUiState) => {
      state.isRunning = false;
      state.stage = ContentQualityStage.Completed;
      state.results = new Map<string, ContentQualityResultUi>(collected);
    });
  }

  // ───────────────────────── 搜索类型与范围 ─────────────────────────

  private toggleSourceType(type: number): void {
    const selected = this.state.selectedSourceTypes.slice();
    const index = selected.indexOf(type);
    if (index >= 0) {
      selected.splice(index, 1);
    } else {
      selected.push(type);
    }
    this.patch((next: SearchUiState) => { next.selectedSourceTypes = selected; });
  }

  private clearAllSourceTypes(): void {
    this.patch((next: SearchUiState) => { next.selectedSourceTypes = []; });
  }

  private choicesOf(sources: BookSource[]): ScopeSourceChoice[] {
    const choices: ScopeSourceChoice[] = [];
    for (const source of sources) {
      choices.push({ name: source.bookSourceName, url: source.bookSourceUrl });
    }
    return choices;
  }

  /** 上游 `toggleScopeGroup` :833-847：切到组范围并清空源范围。 */
  private toggleScopeGroup(groupName: string): void {
    const groups = this.state.enabledGroups.slice();
    const index = groups.indexOf(groupName);
    if (index >= 0) {
      groups.splice(index, 1);
    } else {
      groups.push(groupName);
    }
    const raw = encodeGroups(groups);
    this.applyScopeSelection(groups, [], false);
  }

  /** 上游 `toggleScopeSource` :849-873：切到源范围并清空组范围。 */
  private toggleScopeSource(source: BookSource | undefined): void {
    if (source === undefined) { return; }
    const urls = this.state.selectedScopeSourceUrls.slice();
    const index = urls.indexOf(source.bookSourceUrl);
    const choices: ScopeSourceChoice[] = [];
    if (index >= 0) {
      urls.splice(index, 1);
    } else {
      urls.push(source.bookSourceUrl);
    }
    for (const url of urls) {
      for (const candidate of this.state.enabledSources) {
        if (candidate.bookSourceUrl === url) {
          choices.push({ name: candidate.bookSourceName, url: url });
        }
      }
    }
    this.applyScopeSelection([], choices, true);
  }

  private removeScopeItem(scopeName: string): void {
    const currentRaw = this.state.isSourceScope
      ? encodeSources(this.choicesOf(this.state.enabledSources.filter((source: BookSource) =>
        this.state.selectedScopeSourceUrls.includes(source.bookSourceUrl))))
      : encodeGroups(this.state.enabledGroups);
    const nextRaw = scopeRemove(currentRaw, scopeName);
    this.applyScopeSelection(scopeGroupNames(nextRaw),
      this.choicesOf(this.state.enabledSources.filter((source: BookSource) =>
        scopeSourceUrls(nextRaw).includes(source.bookSourceUrl))), scopeIsSource(nextRaw));
  }

  /** 上游 `handleEmptyScopeActionConfirmed` :875-893：切全部分组，或关掉精准搜索。 */
  private async confirmEmptyScopeAction(): Promise<void> {
    const action = this.state.emptyScopeAction;
    if (action === undefined) { return; }
    this.patch((next: SearchUiState) => { next.emptyScopeAction = undefined; });
    if (action.wasExactMatch) {
      this.patch((next: SearchUiState) => { next.exactMatch = false; });
      void this.persistMatchMode(false);
      if (this.state.committedQuery.length > 0) {
        this.startSearch(this.state.committedQuery, 1);
      }
      return;
    }
    this.applyScopeSelection([], [], false);
  }

  // ───────────────────────── 展开书源 ─────────────────────────

  /** 上游 `ExpandSource(origin, sourceName)`：打开面板并取第 1 页。 */
  private async expandSource(origin: string): Promise<void> {
    console.error(`[T8DBG] expandSource origin=${origin}`);
    let sourceName = origin;
    for (const item of this.state.results) {
      if (item.book.origin === origin && item.book.originName.length > 0) {
        sourceName = item.book.originName;
        break;
      }
    }
    const local: SearchBookItem[] = [];
    for (const item of this.state.results) {
      if (item.book.origin === origin) { local.push(item.book); }
    }
    this.patch((next: SearchUiState) => {
      next.expandedSourceUrl = origin;
      next.expandedSourceName = sourceName;
      next.expandedSourceBooks = local;
      next.expandedSourcePage = 1;
      next.expandedSourceEnd = local.length === 0;
      next.expandedSourceError = '';
      next.showExpandedSource = true;
    });
    await this.loadExpandedSourcePage();
  }

  /**
   * 上游 `loadExpandedSourcePage` :1005-1034：用同一个关键词在该源上再取一页。
   * 本地 `SearchCoordinator.search` 是多源的，这里用单源搜索（`BookSourceRuntime.searchOne`）。
   */
  private async loadExpandedSourcePage(): Promise<void> {
    const origin = this.state.expandedSourceUrl;
    const keyword = this.state.committedQuery;
    if (origin.length === 0 || keyword.length === 0) { return; }
    if (this.state.expandedSourceLoading) { return; }
    if (this.state.expandedSourceEnd && this.state.expandedSourceBooks.length > 0) { return; }
    this.patch((next: SearchUiState) => {
      next.expandedSourceLoading = true;
      next.expandedSourceError = '';
    });
    const page = this.state.expandedSourcePage;
    const outcome = await SearchCoordinator.searchSingle(origin, keyword, page, this.state.exactMatch);
    if (outcome.error.length > 0) {
      this.patch((next: SearchUiState) => {
        next.expandedSourceLoading = false;
        next.expandedSourceError = outcome.error;
      });
      return;
    }
    const existing: SearchBookItem[] = this.state.expandedSourceBooks.slice();
    const seen: string[] = [];
    for (const book of existing) { seen.push(book.bookUrl); }
    let added = 0;
    for (const book of outcome.books) {
      if (seen.includes(book.bookUrl)) { continue; }
      existing.push(book);
      seen.push(book.bookUrl);
      added += 1;
    }
    const atEnd = added === 0 || !outcome.supportsNextPage;
    this.patch((next: SearchUiState) => {
      next.expandedSourceBooks = existing;
      next.expandedSourceLoading = false;
      next.expandedSourceEnd = atEnd;
      next.expandedSourcePage = atEnd ? page : page + 1;
    });
  }

  // ───────────────────────── 按来源分组 ─────────────────────────

  private sourceGroups(): SourceGroup[] {
    const groups: SourceGroup[] = [];
    for (const item of this.state.results) {
      const origin = item.book.origin;
      let group: SourceGroup | undefined = undefined;
      for (const candidate of groups) {
        if (candidate.origin === origin) { group = candidate; break; }
      }
      if (group === undefined) {
        group = {
          origin: origin,
          sourceName: item.book.originName.length > 0 ? item.book.originName : origin,
          items: []
        };
        groups.push(group);
      }
      group.items.push(item);
    }
    return groups;
  }

  // ───────────────────────── 顶栏 ─────────────────────────

  private updateHeader(offset: number): void {
    const shouldCollapse = offset > HEADER_COLLAPSE_THRESHOLD
      ? true
      : (offset < HEADER_EXPAND_THRESHOLD ? false : this.collapsedHeader);
    if (shouldCollapse !== this.collapsedHeader) {
      this.getUIContext().animateTo({ curve: curves.springMotion(0.35, 0.86) }, () => {
        this.collapsedHeader = shouldCollapse;
      });
    }
  }

  /** 打开面板前先收焦点与软键盘（上游 `:328-329` / `:351-352`）。 */
  private hideKeyboard(): void {
    try {
      this.getUIContext().getFocusController().clearFocus();
    } catch (error) {
      console.error(`收键盘失败：${error instanceof Error ? error.message : String(error)}`);
    }
  }

  @Builder
  private navSlot() {
    TopBarBackButton({ onSelect: () => { this.onBack(); } })
  }

  /**
   * 顶栏三动作（上游 `:312-391`）：设置 / 精准 / 筛选。
   * 上游用 `TopBarAnimatedActionButton(checked=...)`，本地 `TopBarButton` 没有 checked，
   * 选中态一律用 `tint` 表达（与 ExploreShowPage 的既有做法一致）。
   */
  @Builder
  private topActions() {
    TopBarButton({
      icon: 'settings',
      showDivider: false,
      tint: (this.isSourceGroupedMode() || this.state.selectedSourceTypes.length > 0)
        ? this.themeColorAccent : '',
      accessibilityLabel: '设置',
      onSelect: () => {
        this.hideKeyboard();
        const intent = this.intentOf('SetSettingsSheetVisible');
        intent.visible = true;
        this.onIntent(intent);
      }
    })
    TopBarButton({
      icon: this.state.exactMatch ? 'searchPrecisionOn' : 'searchPrecisionOff',
      tint: this.state.exactMatch ? this.themeColorAccent : '',
      accessibilityLabel: '精准搜索',
      onSelect: () => {
        this.hideKeyboard();
        const intent = this.intentOf('SetMatchMode');
        intent.mode = this.state.exactMatch ? 0 : 1;
        this.onIntent(intent);
      }
    })
    TopBarButton({
      icon: 'profileFilterAlt',
      tint: !this.state.isAllScope ? this.themeColorAccent : '',
      accessibilityLabel: '筛选',
      onSelect: () => {
        this.hideKeyboard();
        const intent = this.intentOf('SetScopeSheetVisible');
        intent.visible = true;
        this.onIntent(intent);
      }
    })
  }

  // ───────────────────────── 计数卡（上游 SearchFloatingSummary） ─────────────────────────

  @Builder
  private floatingSummary() {
    Row() {
      if (this.showResultCountCard()) {
        Text(this.resultCountText())
          .fontSize(LABEL_SMALL)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.themeColorOnCardContainer)
      }
      if (this.showSourceProgressCard()) {
        Text(this.sourceProgressText())
          .fontSize(LABEL_SMALL)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.themeColorOnCardContainer)
      }
    }
    .padding({ left: SPACE_12, right: SPACE_12, top: SPACE_8, bottom: SPACE_8 })
    .backgroundColor(this.themeColorSurfaceContainer)
    .borderRadius(16)
  }

  // ───────────────────────── 建议面板 ─────────────────────────

  @Builder
  private suggestionPanel() {
    List({ space: SPACE_4 }) {
      // 书架提示：图标 + 标题（上游去掉自创的「本地」尾标）。
      ListItem() {
        Row({ space: SPACE_8 }) {
          AppGlyph({ name: 'book', glyphSize: 18, tint: this.themeColorTextSecondary })
          Text('书架')
            .fontSize(TITLE_SMALL)
            .fontColor(this.themeColorTextSecondary)
            .layoutWeight(1)
        }
        .width('100%')
        .padding({ left: SPACE_16, right: SPACE_16, top: SPACE_12, bottom: SPACE_8 })
      }
      ForEach(this.state.bookshelfHints, (hint: SearchShelfHint) => {
        ListItem() {
          SelectionItemCard({
            title: hint.name,
            subtitle: hint.author,
            inSelectionMode: false,
            onToggleSelection: () => {
              const book = this.books.find((candidate: Book) =>
                (candidate.contentPath ?? candidate.id) === hint.bookUrl);
              if (book !== undefined) { this.onOpenBookshelfBook(book); }
            }
          })
        }
        .padding({ left: SPACE_16, right: SPACE_16 })
      }, (hint: SearchShelfHint) => hint.bookUrl)

      // 历史：图标 + 标题 + 「清除所有」。
      ListItem() {
        Row({ space: SPACE_8 }) {
          AppGlyph({ name: 'profileHistory', glyphSize: 18, tint: this.themeColorTextSecondary })
          Text('搜索历史')
            .fontSize(TITLE_SMALL)
            .fontColor(this.themeColorTextSecondary)
            .layoutWeight(1)
          if (this.state.history.length > 0) {
            Text('清除所有')
              .fontSize(LABEL_MEDIUM)
              .fontColor(this.themeColorAccent)
              .padding({ left: SPACE_8, right: SPACE_8, top: SPACE_4, bottom: SPACE_4 })
              .onClick(() => {
                const intent = this.intentOf('SetClearHistoryDialogVisible');
                intent.visible = true;
                this.onIntent(intent);
              })
          }
        }
        .width('100%')
        .padding({ left: SPACE_16, right: SPACE_16, top: SPACE_16, bottom: SPACE_8 })
      }
      if (this.state.history.length === 0) {
        ListItem() {
          Text('没有内容哦')
            .fontSize(BODY_SMALL)
            .fontColor(this.themeColorTextTertiary)
            .width('100%')
            .textAlign(TextAlign.Center)
            .padding({ top: SPACE_12, bottom: SPACE_12 })
        }
      }
      ForEach(this.state.history, (keyword: SearchKeyword) => {
        ListItem() {
          SelectionItemCard({
            title: keyword.word,
            inSelectionMode: false,
            hasTrailingAction: true,
            onToggleSelection: () => {
              const intent = this.intentOf('UseHistoryKeyword');
              intent.keyword = keyword.word;
              this.onIntent(intent);
            },
            trailingAction: () => { this.historyDeleteSlot(keyword.word) }
          })
        }
        .padding({ left: SPACE_16, right: SPACE_16 })
      }, (keyword: SearchKeyword) => keyword.word)
    }
    .width('100%')
    .layoutWeight(1)
    .padding({ bottom: SPACE_16 })
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring)
  }

  @Builder
  private historyDeleteSlot(word: string) {
    SmallPlainIconButton({
      icon: 'profileClose',
      iconSize: 18,
      label: '删除',
      onSelect: () => {
        const intent = this.intentOf('DeleteHistory');
        intent.keyword = word;
        this.onIntent(intent);
      }
    })
  }

  // ───────────────────────── 结果区 ─────────────────────────

  /** 平铺布局（上游 `:531-587`）。 */
  @Builder
  private flatResults() {
    List({ space: FLAT_ITEM_GAP, scroller: this.flatScroller }) {
      ForEach(this.state.results, (entry: SearchResultItemUi, index: number) => {
        ListItem() {
          SearchBookListItem({
            item: entry.book,
            shelfState: entry.shelfState,
            sourceCount: entry.originCount,
            qualityMasked: this.isQualityMasked(entry.book),
            adaptCoverAspectRatio: true,
            coverSettings: this.coverSettings,
            isNight: this.isNight,
            sharedKey: bookCoverSharedElementKey(entry.book.bookUrl, `search:${entry.book.origin}`),
            onSelect: () => {
              if (this.isQualityMasked(entry.book)) { return; }
              const intent = this.intentOf('OpenSearchBook');
              intent.book = entry.book;
              intent.sharedCoverKey = bookCoverSharedElementKey(entry.book.bookUrl, `search:${entry.book.origin}`);
              this.onIntent(intent);
            },
            onLongPress: () => { this.openPreview(entry.book); }
          })
        }
        .padding({ left: SPACE_16, right: SPACE_16 })
        .onAppear(() => {
          if (this.readyToLoad() && this.shouldLoadMore(index, this.state.results.length)) {
            this.onIntent(this.intentOf('LoadMore'));
          }
        })
      }, (entry: SearchResultItemUi) => `${entry.book.origin}:${entry.book.bookUrl}`)
      ListItem() {
        this.footerSlot(true)
      }
      .width('100%')
    }
    .width('100%')
    .layoutWeight(1)
    .padding({ top: RESULT_LIST_TOP_PADDING, bottom: RESULT_LIST_BOTTOM_PADDING })
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring)
    .cachedCount(4)
    .onDidScroll(() => { this.updateHeader(this.flatScroller.currentOffset().yOffset); })
    .onScrollIndex((first: number, _last: number) => { this.flatFirstIndex = first; })
    .onAppear(() => { this.restoreScrollState(); })
  }

  /** 分组布局（上游 `:476-529`）：每个源一段横向卡片列表。 */
  @Builder
  private groupedResults() {
    List({ space: GROUPED_ITEM_GAP, scroller: this.groupedScroller }) {
      ForEach(this.sourceGroups(), (group: SourceGroup, groupIndex: number) => {
        ListItem() {
          this.sourceSection(group, groupIndex)
        }
        .width('100%')
      }, (group: SourceGroup) => `header_${group.origin}`)
      ListItem() {
        this.footerSlot(true)
      }
      .width('100%')
    }
    .width('100%')
    .layoutWeight(1)
    .padding({ top: RESULT_LIST_TOP_PADDING, bottom: RESULT_LIST_BOTTOM_PADDING })
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring)
    .onDidScroll(() => { this.updateHeader(this.groupedScroller.currentOffset().yOffset); })
    .onScrollIndex((first: number, _last: number) => { this.groupedFirstIndex = first; })
    .onAppear(() => { this.restoreScrollState(); })
  }

  /** 上游 `SearchSourceSection`：标题行（源名 + 计数卡 + 查看全部）+ 横向 100vp 网格卡。 */
  @Builder
  private sourceSection(group: SourceGroup, groupIndex: number) {
    Column() {
      Row() {
        Text(group.sourceName)
          .fontSize(TITLE_SMALL)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.themeColorTextPrimary)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(`${group.items.length}`)
          .fontSize(LABEL_SMALL)
          .fontColor(this.themeColorTextSecondary)
          .padding({ left: SPACE_4, right: SPACE_4, top: 1, bottom: 1 })
          .backgroundColor(this.themeColorSurfaceContainer)
          .borderRadius(4)
          .margin({ left: SPACE_12 })
        Blank()
        Row({ space: SPACE_4 }) {
          Text('全部显示')
            .fontSize(LABEL_SMALL)
            .fontColor(this.themeColorOnSecondaryContainer)
          AppGlyph({ name: 'arrowForward', glyphSize: 14, tint: this.themeColorOnSecondaryContainer })
        }
        .padding({ left: SPACE_12, right: SPACE_12, top: SPACE_4, bottom: SPACE_4 })
        .backgroundColor(this.themeColorSecondaryContainer)
        .borderRadius(20)
        .onClick(() => {
          const intent = this.intentOf('ExpandSource');
          intent.key = group.origin;
          this.onIntent(intent);
        })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
      .padding({ left: SPACE_16, right: SPACE_16, top: SPACE_8, bottom: SPACE_8 })

      List({ space: SOURCE_SECTION_GAP }) {
        ForEach(group.items, (entry: SearchResultItemUi, index: number) => {
          ListItem() {
            SearchBookGridItem({
              item: entry.book,
              shelfState: entry.shelfState,
              qualityMasked: this.isQualityMasked(entry.book),
              coverSettings: this.coverSettings,
              isNight: this.isNight,
              sharedKey: bookCoverSharedElementKey(entry.book.bookUrl,
                `search_source:${groupIndex}:${index}`),
              onSelect: () => {
                if (this.isQualityMasked(entry.book)) { return; }
                const intent = this.intentOf('OpenSearchBook');
                intent.book = entry.book;
                intent.sharedCoverKey = bookCoverSharedElementKey(entry.book.bookUrl,
                  `search_source:${groupIndex}:${index}`);
                this.onIntent(intent);
              },
              onLongPress: () => { this.openPreview(entry.book); }
            })
          }
          .width(SOURCE_SECTION_ITEM_WIDTH)
        }, (entry: SearchResultItemUi) => `${entry.book.origin}:${entry.book.bookUrl}`)
      }
      .listDirection(Axis.Horizontal)
      .width('100%')
      .height(this.sectionListHeight())
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
      .fadingEdge(true)
      .contentStartOffset(SPACE_16)
      .contentEndOffset(SPACE_16)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  /** 横向卡片区高度：100vp 宽 5:7 封面 + 两行标题。 */
  private sectionListHeight(): number {
    return Math.round(SOURCE_SECTION_ITEM_WIDTH * 7 / 5) + 52;
  }

  /** 尾部三态（上游 `SearchResultFooter` :1062-1111）。 */
  @Builder
  private footerSlot(hasResult: boolean) {
    Column() {
      if (this.state.isSearching) {
        Row({ space: SPACE_8 }) {
          LoadingProgress().width(18).height(18).color(this.themeColorAccent)
          Text('加载中…')
            .fontSize(LABEL_MEDIUM)
            .fontColor(this.themeColorTextTertiary)
        }
        .justifyContent(FlexAlign.Center)
      } else if (!hasResult && this.state.committedQuery.length > 0) {
        Text('没有内容哦')
          .fontSize(BODY_SMALL)
          .fontColor(this.themeColorTextTertiary)
      } else if (this.state.hasMore) {
        Text('上拉或点击按钮加载更多')
          .fontSize(BODY_SMALL)
          .fontColor(this.themeColorTextTertiary)
      } else {
        Text('没有内容哦')
          .fontSize(BODY_SMALL)
          .fontColor(this.themeColorTextTertiary)
      }
    }
    .width('100%')
    .padding({ top: SPACE_24, bottom: SPACE_24 })
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }

  // ───────────────────────── 预览 ─────────────────────────

  @State previewVisible: boolean = false;
  @State previewBook: SearchBookItem = EMPTY_SEARCH_BOOK;
  @State previewSharedKey: string = '';

  private openPreview(book: SearchBookItem): void {
    this.previewBook = book;
    this.previewSharedKey = bookCoverSharedElementKey(book.bookUrl, `search:${book.origin}`);
    this.previewVisible = true;
  }

  // ───────────────────────── Sheet 内容 ─────────────────────────

  @Builder
  private sheetContent() {
    if (this.state.contentQuality.showSheet) {
      ContentQualitySheet({
        chapterSpec: this.state.contentQuality.chapterSpec,
        keywords: this.state.contentQuality.keywords,
        skipHeadChars: this.state.contentQuality.skipHeadChars,
        isRunning: this.state.contentQuality.isRunning,
        stage: this.contentQualityStageOf(),
        processedBooks: this.state.contentQuality.processedBooks,
        totalBooks: this.state.contentQuality.totalBooks,
        currentBookName: this.state.contentQuality.currentBookName,
        resultCount: this.state.contentQuality.results.size,
        excludedCount: this.excludedCountOf(),
        onChapterSpecChange: (value: string) => {
          const intent = this.intentOf('UpdateContentQualityChapterSpec');
          intent.value = value;
          this.onIntent(intent);
        },
        onKeywordsChange: (value: string) => {
          const intent = this.intentOf('UpdateContentQualityKeywords');
          intent.value = value;
          this.onIntent(intent);
        },
        onSkipHeadCharsChange: (value: string) => {
          const intent = this.intentOf('UpdateContentQualitySkipHeadChars');
          intent.value = value;
          this.onIntent(intent);
        },
        onStart: () => { this.onIntent(this.intentOf('StartContentQuality')); },
        onDismissRequest: () => { this.onIntent(this.intentOf('CloseContentQuality')); }
      })
    } else if (this.state.showScopeSheet) {
      ScopeSelectSheet({
        initialIsAll: this.state.isAllScope,
        initialIsSourceScope: this.state.isSourceScope,
        initialGroupNames: this.state.enabledGroups,
        initialSourceUrls: this.state.selectedScopeSourceUrls,
        groups: this.enabledGroupNames(),
        sources: this.choicesOf(this.state.enabledSources),
        onOpenSourceManage: () => { this.onIntent(this.intentOf('OpenSourceManage')); },
        onApplyScope: (selection: ScopeSelection) => {
          const intent = this.intentOf('ApplyScopeSelection');
          intent.groupNames = selection.groupNames;
          intent.isSourceScope = selection.isSourceScope;
          const picked: BookSource[] = [];
          for (const choice of selection.sources) {
            for (const source of this.state.enabledSources) {
              if (source.bookSourceUrl === choice.url) { picked.push(source); }
            }
          }
          intent.sources = picked;
          this.onIntent(intent);
        },
        onDismissRequest: () => {
          const intent = this.intentOf('SetScopeSheetVisible');
          intent.visible = false;
          this.onIntent(intent);
        }
      })
    } else if (this.state.showSettingsSheet) {
      SearchSettingsSheet({
        layoutMode: this.state.layoutMode,
        selectedSourceTypes: this.state.selectedSourceTypes,
        onLayoutModeChange: (mode: number) => {
          const intent = this.intentOf('SetLayoutMode');
          intent.mode = mode;
          this.onIntent(intent);
        },
        onOpenContentQuality: () => { this.onIntent(this.intentOf('OpenContentQuality')); },
        onToggleSourceType: (type: number) => {
          const intent = this.intentOf('ToggleSourceType');
          intent.type = type;
          this.onIntent(intent);
        },
        onClearAllSourceTypes: () => { this.onIntent(this.intentOf('ClearAllSourceTypes')); }
      })
    } else if (this.state.showExpandedSource) {
      ExpandedSourceContent({
        sourceName: this.state.expandedSourceName,
        books: this.state.expandedSourceBooks,
        isLoading: this.state.expandedSourceLoading,
        isEnd: this.state.expandedSourceEnd,
        errorMsg: this.state.expandedSourceError,
        coverSettings: this.coverSettings,
        isNight: this.isNight,
        onLoadMore: () => { this.onIntent(this.intentOf('LoadMoreExpandedSource')); },
        onBookClick: (book: SearchBookItem) => {
          const intent = this.intentOf('OpenExpandedSourceBook');
          intent.book = book;
          this.onIntent(intent);
        },
        onBookLongClick: (book: SearchBookItem) => { this.openPreview(book); }
      })
    }
  }

  /** 范围选择面板要展示的分组名（只列非私密、可见的用户分组）。 */
  private enabledGroupNames(): string[] {
    const names: string[] = [];
    for (const group of this.groups) {
      if (group.groupId <= 0) { continue; }
      if (!group.show) { continue; }
      if (group.isPrivate) { continue; }
      names.push(group.groupName);
    }
    return names;
  }

  private sheetVisible(): boolean {
    return this.state.contentQuality.showSheet || this.state.showScopeSheet ||
      this.state.showSettingsSheet || this.state.showExpandedSource;
  }

  // ───────────────────────── 根布局 ─────────────────────────

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Column() {
        AppTopBar({
          title: '搜索',
          collapsed: this.collapsedHeader,
          hasNavigation: true,
          navigationIcon: () => { this.navSlot() },
          actions: () => { this.topActions() }
        })

        Row() {
          SearchBar({
            query: this.state.query,
            placeholder: '搜索书名、作者',
            showClear: this.state.query.length > 0,
            clearLabel: '清除',
            onQueryChange: (value: string) => {
              this.collapsedHeader = false;
              const intent = this.intentOf('UpdateQuery');
              intent.query = value;
              this.onIntent(intent);
            },
            onSearch: (value: string) => { this.submitSearch(value); },
            onClear: () => {
              this.queryInput = '';
              const intent = this.intentOf('UpdateQuery');
              intent.query = '';
              this.onIntent(intent);
            }
          })
        }
        .width('100%')
        .padding({ left: SPACE_16, right: SPACE_16 })

        Stack({ alignContent: Alignment.Top }) {
          if (this.state.showSuggestions) {
            this.suggestionPanel()
          } else if (this.state.results.length === 0 && !this.state.isSearching) {
            Column() {
              this.footerSlot(false)
            }
            .width('100%')
            .layoutWeight(1)
            .justifyContent(FlexAlign.Center)
          } else if (this.isSourceGroupedMode()) {
            this.groupedResults()
          } else {
            this.flatResults()
          }

          // 顶部吸附计数卡（上游 `TopFloatingStickyItem`）。
          if (this.showResultCountCard() || this.showSourceProgressCard()) {
            Row() {
              this.floatingSummary()
            }
            .width('100%')
            .justifyContent(FlexAlign.Center)
            .padding({ top: FLOATING_SUMMARY_TOP })
            .hitTestBehavior(HitTestMode.Transparent)
          }
        }
        .width('100%')
        .layoutWeight(1)
      }
      .width('100%')
      .height('100%')
      .backgroundColor(this.themeAppBackground.length > 0
        ? Color.Transparent
        : (this.themePureBlack ? '#000000' : this.themeColorSurfacePrimary))

      // FAB：搜索中停止、空闲加载下一页。
      if (this.showFab()) {
        Row() {
          AppFab({
            icon: this.fabIconOf(),
            fabAccessibilityText: this.fabLabelOf(),
            onFabClick: () => {
              this.onIntent(this.intentOf(this.state.isSearching ? 'StopSearch' : 'LoadMore'));
            }
          })
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.End)
        .alignItems(VerticalAlign.Bottom)
        .padding({ right: SPACE_16, bottom: 32 })
        .hitTestBehavior(HitTestMode.Transparent)
      }

      // 预览面板（上游 `SearchBookPreviewSheet`）。
      if (this.previewVisible) {
        Column() {
          Column()
            .width('100%')
            .layoutWeight(1)
            .backgroundColor('#99000000')
            .onClick(() => { this.previewVisible = false; })
          SearchBookPreviewSheet({
            item: this.previewBook,
            shelfState: this.shelfStateOf(this.previewBook),
            coverSettings: this.coverSettings,
            isNight: this.isNight,
            sharedKey: this.previewSharedKey,
            onOpenDetail: () => {
              this.previewVisible = false;
              const intent = this.intentOf('OpenSearchBook');
              intent.book = this.previewBook;
              intent.sharedCoverKey = this.previewSharedKey;
              this.onIntent(intent);
            },
            onAddToShelf: () => {
              this.previewVisible = false;
              const intent = this.intentOf('AddToShelf');
              intent.book = this.previewBook;
              this.onIntent(intent);
            }
          })
        }
        .width('100%')
        .height('100%')
      }

      // 冲突面板（上游 `BookshelfConflictSheet`）。
      if (this.state.bookshelfConflict !== undefined) {
        BookshelfConflictSheet({
          conflict: this.state.bookshelfConflict,
          isResolving: this.state.isResolvingBookshelfConflict,
          onDismissRequest: () => { this.onIntent(this.intentOf('DismissBookshelfConflict')); },
          onOpenExistingBook: (_summary: ConflictBookSummary) => {
            this.onIntent(this.intentOf('OpenBookshelfConflictBook'));
          },
          onCoexist: (existingBookUrl: string, options: ChangeSourceMigrationOptions) => {
            const intent = this.intentOf('CoexistWithBookshelfConflict');
            intent.existingBookUrl = existingBookUrl;
            intent.options = options;
            this.onIntent(intent);
          },
          onMigrate: (existingBookUrl: string, options: ChangeSourceMigrationOptions) => {
            const intent = this.intentOf('MigrateBookshelfConflict');
            intent.existingBookUrl = existingBookUrl;
            intent.options = options;
            this.onIntent(intent);
          }
        })
      }

      // 清空历史确认（上游 `AppAlertDialog(draw / sure_clear_search_history)`）。
      if (this.state.showClearHistoryDialog) {
        AppAlertDialog({
          title: '提醒',
          text: '是否确认清除所有搜索历史记录',
          confirmText: '确认',
          dismissText: '取消',
          onConfirm: () => { this.onIntent(this.intentOf('ConfirmClearHistory')); },
          onDismiss: () => {
            const intent = this.intentOf('SetClearHistoryDialogVisible');
            intent.visible = false;
            this.onIntent(intent);
          }
        })
      }

      // 空范围提示（上游 `AppAlertDialog(emptyScopeAction)`）。
      if (this.state.emptyScopeAction !== undefined) {
        AppAlertDialog({
          title: '提醒',
          text: this.emptyScopeText(),
          confirmText: '确认',
          dismissText: '取消',
          onConfirm: () => { this.onIntent(this.intentOf('ConfirmEmptyScopeAction')); },
          onDismiss: () => { this.onIntent(this.intentOf('DismissEmptyScopeAction')); }
        })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.themeAppBackground.length > 0
      ? Color.Transparent
      : (this.themePureBlack ? '#000000' : this.themeColorSurfacePrimary))
    .bindSheet(this.sheetVisible(), this.sheetContent(), {
      // 展开源面板的内容是 `layoutWeight(1)` 的列表，高度必须由 Sheet 给定；
      // 若用 `FIT_CONTENT` 会形成「内容要高度、高度看内容」的循环，面板高度塌成 0
      // 而表现为「点了没反应」。上游 `ExpandedSourceSheet` 是整屏高的底部面板，
      // 这里对应 `LARGE`。范围选择面板固定 `MEDIUM`，其余内容自适应。
      height: this.state.showExpandedSource
        ? SheetSize.LARGE
        : (this.state.showScopeSheet ? SheetSize.MEDIUM : SheetSize.FIT_CONTENT),
      dragBar: true,
      showClose: false,
      backgroundColor: this.themeColorSurfaceTertiary,
      onDisappear: () => {
        this.patch((next: SearchUiState) => {
          next.showScopeSheet = false;
          next.showSettingsSheet = false;
          next.showExpandedSource = false;
          next.contentQuality = emptyContentQualityUiState();
        });
      }
    })
  }

  /** 空范围提示文案：精准搜索下问「是否关闭精准搜索」，否则问「是否切换到全部分组」。 */
  private emptyScopeText(): string {
    const action = this.state.emptyScopeAction;
    if (action === undefined) { return ''; }
    if (action.wasExactMatch) {
      return `${action.scopeDisplay}分组搜索结果为空，是否关闭精准搜索？`;
    }
    return `${action.scopeDisplay}分组搜索结果为空，是否切换到全部分组？`;
  }
}
