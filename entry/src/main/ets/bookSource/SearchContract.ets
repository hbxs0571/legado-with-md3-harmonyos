/**
 * 搜索页契约（状态 / Intent / Effect）。
 *
 * 逐项对齐上游 `ui/book/search/SearchContract.kt`（173 行）：
 *   `SearchResultItemUi` / `ContentQualityResultUi` / `ContentQualityUiState` /
 *   `SearchUiState`（41 字段）/ `SearchEmptyScopeAction` / `SearchIntent`（40 类）/
 *   `SearchEffect`（3 类）。
 *
 * ArkTS 没有密封类，用「带 kind 判别字段的接口 + 构造工厂」表达 sealed interface，
 * 与 `ExploreShowContract.ets` 同一套写法。
 */
import { BookSource } from '../model/BookSource';
import { SearchKeyword } from '../model/SearchKeyword';
import { SearchBookItem } from './SourceModels';
import { BookShelfState } from '../components/booksource/SearchBookItems';
import { BookshelfConflict, ConflictBookSummary } from '../components/booksource/BookshelfConflictSheet';
import { ChangeSourceMigrationOptions } from './ChangeSourceCoordinator';

/**
 * 上游 `SearchContract.kt:22-25 SearchResultItemUi`：结果项 + 它在书架里的状态。
 * `originCount` 对应上游 `item.book.origins.size`（`SearchBook.kt:89 val origins`）——
 * 上游把命中源集合挂在 `SearchBook` 上；本地 `SearchBookItem` 不带该集合，
 * 合并层 `MergedBook.originCount` 持有同一个值，落结果项时精确搬过来，不做回算。
 */
export interface SearchResultItemUi {
  book: SearchBookItem;
  shelfState: BookShelfState;
  originCount: number;
}

/** 上游 `:28-35 ContentQualityResultUi`：单本书的检测结果。 */
export interface ContentQualityResultUi {
  sourceName: string;
  sampledChapterCount: number;
  matchedChapterCount: number;
  keywordHits: number;
  excluded: boolean;
  errorMessage: string;
}

/** 上游 `:9-15 ContentQualityStage`（同名枚举，本地放这里以免多一个文件）。 */
export enum ContentQualityStage {
  ChapterCount = 0,
  ContentCleaning = 1,
  KeywordMatching = 2,
  Excluding = 3,
  Completed = 4
}

/** 上游 `:37-49 ContentQualityUiState`：11 字段，默认值与上游逐字相同。 */
export interface ContentQualityUiState {
  showSheet: boolean;
  chapterSpec: string;
  keywords: string;
  skipHeadChars: string;
  isRunning: boolean;
  /** null 表示还没开始；用 -1 表示「无阶段」以免引入可空数值。 */
  stage: ContentQualityStage;
  processedBooks: number;
  totalBooks: number;
  currentBookName: string;
  /** key 为 `${origin}:${bookUrl}`（上游 `qualityKey`）。 */
  results: Map<string, ContentQualityResultUi>;
}

/** 上游默认值 `chapterSpec="1,3,5"` / `keywords="主角"` / `skipHeadChars="300"`。 */
export function emptyContentQualityUiState(): ContentQualityUiState {
  return {
    showSheet: false,
    chapterSpec: '1,3,5',
    keywords: '主角',
    skipHeadChars: '300',
    isRunning: false,
    stage: ContentQualityStage.ChapterCount,
    processedBooks: 0,
    totalBooks: 0,
    currentBookName: '',
    results: new Map<string, ContentQualityResultUi>()
  };
}

/** 上游 `:95-98 SearchEmptyScopeAction`。 */
export interface SearchEmptyScopeAction {
  scopeDisplay: string;
  /** 触发时的匹配模式（true = 精准）。上游存 MatchMode 枚举，这里用布尔等价表达。 */
  wasExactMatch: boolean;
}

/**
 * 上游 `:52-93 SearchUiState`：41 字段逐项镜像。
 * 字段顺序与上游一致，便于对照检查。
 */
export interface SearchUiState {
  query: string;
  committedQuery: string;
  results: SearchResultItemUi[];
  history: SearchKeyword[];
  /** 书架提示（上游 `bookshelfHints: ImmutableList<BookShelfItem>`），本地用书架快照的书名/作者/bookUrl。 */
  bookshelfHints: SearchShelfHint[];
  enabledGroups: string[];
  enabledSources: BookSource[];
  scopeDisplay: string;
  scopeDisplayNames: string[];
  selectedScopeSourceUrls: string[];
  isAllScope: boolean;
  isSourceScope: boolean;
  /** 上游 `matchMode: MatchMode`，本地用布尔（true = EXACT）。 */
  exactMatch: boolean;
  isSearching: boolean;
  isManualStop: boolean;
  hasMore: boolean;
  processedSources: number;
  totalSources: number;
  selectedSourceTypes: number[];
  showScopeSheet: boolean;
  showSettingsSheet: boolean;
  showClearHistoryDialog: boolean;
  showSuggestions: boolean;
  emptyScopeAction: SearchEmptyScopeAction | undefined;
  savedScrollIndex: number;
  savedScrollOffset: number;
  expandedSourceUrl: string;
  expandedSourceName: string;
  expandedSourceBooks: SearchBookItem[];
  expandedSourceLoading: boolean;
  expandedSourceEnd: boolean;
  expandedSourceError: string;
  expandedSourcePage: number;
  showExpandedSource: boolean;
  layoutMode: number;
  expandedSourceSavedScrollIndex: number;
  expandedSourceSavedScrollOffset: number;
  contentQuality: ContentQualityUiState;
  bookshelfConflict: BookshelfConflict | undefined;
  isResolvingBookshelfConflict: boolean;
}

/** 书架提示条目（上游 `BookShelfItem` 的最小子集：够渲染「书名 + 作者」并去重）。 */
export interface SearchShelfHint {
  bookUrl: string;
  name: string;
  author: string;
}

/** 上游 `SearchUiState` 的默认构造（除 scope 三项外都是空值）。 */
export function emptySearchUiState(): SearchUiState {
  return {
    query: '',
    committedQuery: '',
    results: [],
    history: [],
    bookshelfHints: [],
    enabledGroups: [],
    enabledSources: [],
    scopeDisplay: '',
    scopeDisplayNames: [],
    selectedScopeSourceUrls: [],
    isAllScope: true,
    isSourceScope: false,
    exactMatch: false,
    isSearching: false,
    isManualStop: false,
    hasMore: true,
    processedSources: 0,
    totalSources: 0,
    selectedSourceTypes: [],
    showScopeSheet: false,
    showSettingsSheet: false,
    showClearHistoryDialog: false,
    showSuggestions: true,
    emptyScopeAction: undefined,
    savedScrollIndex: 0,
    savedScrollOffset: 0,
    expandedSourceUrl: '',
    expandedSourceName: '',
    expandedSourceBooks: [],
    expandedSourceLoading: false,
    expandedSourceEnd: false,
    expandedSourceError: '',
    expandedSourcePage: 1,
    showExpandedSource: false,
    layoutMode: 0,
    expandedSourceSavedScrollIndex: 0,
    expandedSourceSavedScrollOffset: 0,
    contentQuality: emptyContentQualityUiState(),
    bookshelfConflict: undefined,
    isResolvingBookshelfConflict: false
  };
}

/**
 * 上游 `:100-158 SearchIntent`：40 类。
 * 用 kind 字符串判别；带参的 Intent 用构造工厂填字段。
 */
export type SearchIntentKind =
  | 'Initialize' | 'UpdateQuery' | 'SubmitSearch' | 'LoadMore' | 'StopSearch'
  | 'ClearSearchResults' | 'PauseEngine' | 'ResumeEngine' | 'UseHistoryKeyword'
  | 'OpenSearchBook' | 'AddToShelf' | 'OpenBookshelfBook' | 'ExpandSource'
  | 'DismissExpandedSource' | 'LoadMoreExpandedSource' | 'OpenExpandedSourceBook'
  | 'DeleteHistory' | 'SetClearHistoryDialogVisible' | 'ConfirmClearHistory'
  | 'SetScopeSheetVisible' | 'SetSettingsSheetVisible' | 'OpenContentQuality'
  | 'CloseContentQuality' | 'UpdateContentQualityChapterSpec'
  | 'UpdateContentQualityKeywords' | 'UpdateContentQualitySkipHeadChars'
  | 'StartContentQuality' | 'SetLayoutMode' | 'ToggleSourceType'
  | 'ClearAllSourceTypes' | 'SelectAllScope' | 'ApplyScopeSelection'
  | 'ToggleScopeGroup' | 'ToggleScopeSource' | 'RemoveScopeItem' | 'SetMatchMode'
  | 'ConfirmEmptyScopeAction' | 'DismissEmptyScopeAction' | 'OpenSourceManage'
  | 'SaveScrollState' | 'SaveExpandedSourceScrollState' | 'DismissBookshelfConflict'
  | 'OpenBookshelfConflictBook' | 'CoexistWithBookshelfConflict' | 'MigrateBookshelfConflict';

/** 上游 Intent 携带的参数全集（按需填，未用的保持默认）。 */
export interface SearchIntent {
  kind: SearchIntentKind;
  key: string;
  scopeRaw: string;
  query: string;
  showSuggestions: boolean;
  keyword: string;
  book: SearchBookItem | undefined;
  sharedCoverKey: string;
  historyItem: SearchKeyword | undefined;
  visible: boolean;
  mode: number;
  type: number;
  groupName: string;
  source: BookSource | undefined;
  scopeName: string;
  groupNames: string[];
  sources: BookSource[];
  isSourceScope: boolean;
  index: number;
  offset: number;
  summary: ConflictBookSummary | undefined;
  existingBookUrl: string;
  options: ChangeSourceMigrationOptions | undefined;
  value: string;
}

/** 造一个只填了 kind 的 Intent（其余字段给中性默认值）。 */
export function searchIntent(kind: SearchIntentKind): SearchIntent {
  return {
    kind: kind,
    key: '',
    scopeRaw: '',
    query: '',
    showSuggestions: true,
    keyword: '',
    book: undefined,
    sharedCoverKey: '',
    historyItem: undefined,
    visible: false,
    mode: 0,
    type: 0,
    groupName: '',
    source: undefined,
    scopeName: '',
    groupNames: [],
    sources: [],
    isSourceScope: false,
    index: 0,
    offset: 0,
    summary: undefined,
    existingBookUrl: '',
    options: undefined,
    value: ''
  };
}

/** 上游 `:160-173 SearchEffect`：3 类。 */
export type SearchEffectKind = 'OpenBookInfo' | 'OpenSourceManage' | 'ShowMessage';

export interface SearchEffect {
  kind: SearchEffectKind;
  name: string;
  author: string;
  bookUrl: string;
  origin: string;
  coverPath: string;
  sharedCoverKey: string;
  message: string;
}

export function searchEffect(kind: SearchEffectKind): SearchEffect {
  return {
    kind: kind,
    name: '',
    author: '',
    bookUrl: '',
    origin: '',
    coverPath: '',
    sharedCoverKey: '',
    message: ''
  };
}

/** 上游 `SearchEffect.OpenBookInfo(name, author, bookUrl, origin, coverPath, sharedCoverKey)`。 */
export function openBookInfoEffect(book: SearchBookItem, sharedCoverKey: string): SearchEffect {
  const effect: SearchEffect = searchEffect('OpenBookInfo');
  effect.name = book.name;
  effect.author = book.author;
  effect.bookUrl = book.bookUrl;
  effect.origin = book.origin;
  effect.coverPath = book.coverUrl;
  effect.sharedCoverKey = sharedCoverKey;
  return effect;
}

export function showMessageEffect(message: string): SearchEffect {
  const effect: SearchEffect = searchEffect('ShowMessage');
  effect.message = message;
  return effect;
}

/** 上游 `SearchViewModel.kt:832 qualityKey(book) = "${origin}:${bookUrl}"`。 */
export function qualityKeyOf(book: SearchBookItem): string {
  return `${book.origin}:${book.bookUrl}`;
}
