// 探索结果页的契约层：UiState / 三类 sheet / 16 类 Intent / 2 类 Effect。
//
// 逐条对齐上游 `ui/book/explore/ExploreShowContract.kt`（86 行）：
// - `ExploreShowUiState`（:14-31，16 字段）
// - `ExploreBookItemUi`（:34-37，book + shelfState）
// - `ExploreShowSheet`（:39-43，None / KindSelect / GridCount）
// - `ExploreShowIntent`（:45-73，16 类）
// - `ExploreShowEffect`（:75-85，OpenBookInfo / ShowMessage）
//
// ArkTS 没有密封类，用「带 kind 判别字段的接口 + 构造工厂」表达同一组语义：
// 每种 Intent 是一个 interface（继承 `ExploreShowIntentBase` 的 `kind`），
// 用 `exploreShowIntent(kind, patch)` 造对象，页面侧按 `kind` 分派。
import { SearchBookItem } from './SourceModels';
import { ExploreKind } from './ExploreKind';
import { BookShelfState } from '../components/booksource/SearchBookItems';
import { BookshelfConflict, ConflictBookSummary } from '../components/booksource/BookshelfConflictSheet';
import { ChangeSourceMigrationOptions } from './ChangeSourceCoordinator';

/** 三类底部面板（上游 `ExploreShowSheet`）。 */
export enum ExploreShowSheet {
  None = 0,
  KindSelect = 1,
  GridCount = 2
}

/** 结果项 UI 模型（上游 `ExploreBookItemUi`：书 + 它在书架里的状态）。 */
export interface ExploreBookItemUi {
  book: SearchBookItem;
  shelfState: BookShelfState;
}

/** 结果页 UI 状态（上游 `ExploreShowUiState` 的 16 个字段，顺序一致）。 */
export interface ExploreShowUiState {
  sourceUrl: string;
  books: ExploreBookItemUi[];
  kinds: ExploreKind[];
  selectedKindTitle: string;
  layoutState: number;
  gridCount: number;
  isLoading: boolean;
  isRefreshing: boolean;
  isEnd: boolean;
  errorMsg: string;
  sheet: ExploreShowSheet;
  filterStateId: number;
  bookshelfConflict: BookshelfConflict | undefined;
  isResolvingBookshelfConflict: boolean;
  currentPage: number;
  canJumpPage: boolean;
}

/**
 * 加载状态源（上游 `ExploreShowViewModel.kt:32-37` 的 `ExploreShowLoadState`）。
 * 上游是独立 flow，`combineUiState()` 里与其它源合成；本地同样先各自成形再合成。
 */
export interface ExploreShowLoadState {
  isLoading: boolean;
  isRefreshing: boolean;
  isEnd: boolean;
  errorMsg: string;
}

/**
 * 分类状态源（上游 `:39-42` 的 `ExploreShowKindState`）。
 */
export interface ExploreShowKindState {
  kinds: ExploreKind[];
  selectedKindTitle: string;
}

/**
 * 展示状态源（上游 `:44-49` 的 `ExploreShowDisplayState`）。
 */
export interface ExploreShowDisplayState {
  sourceUrl: string;
  layoutState: number;
  gridCount: number;
  sheet: ExploreShowSheet;
}

/**
 * 分页状态源（上游 `:468-472` 的 `ExplorePageState`）。
 */
export interface ExplorePageState {
  currentPage: number;
  canJumpPage: boolean;
}

/** 空加载状态（对齐上游 data class 默认值）。 */
export function emptyExploreShowLoadState(): ExploreShowLoadState {
  const state: ExploreShowLoadState = {
    isLoading: false,
    isRefreshing: false,
    isEnd: false,
    errorMsg: ''
  };
  return state;
}

/** 空分类状态。 */
export function emptyExploreShowKindState(): ExploreShowKindState {
  const state: ExploreShowKindState = {
    kinds: [],
    selectedKindTitle: ''
  };
  return state;
}

/** 空展示状态。 */
export function emptyExploreShowDisplayState(): ExploreShowDisplayState {
  const state: ExploreShowDisplayState = {
    sourceUrl: '',
    layoutState: 0,
    gridCount: 3,
    sheet: ExploreShowSheet.None
  };
  return state;
}

/** 空分页状态。 */
export function emptyExplorePageState(): ExplorePageState {
  const state: ExplorePageState = {
    currentPage: 1,
    canJumpPage: false
  };
  return state;
}

/**
 * 合成 UiState（上游 `ExploreShowViewModel.kt:198-257` 的 `combineUiState()`）。
 *
 * 上游是四个 flow 的 `combine`：`books`（rawBooks × 书架集合经
 * `ResolveBookShelfStateUseCase`）、`loadAndKind`（loadState × kindState）、
 * `displayAndCoverSettings`（displayState × 封面设置 × pageState），最后三者再合成。
 * 本地没有 flow，改成一个纯函数把同一组输入拼成同一个 16 字段结构，
 * 字段来源与上游逐个对应，页面只从合成结果读。
 */
export function combineExploreShowUiState(load: ExploreShowLoadState,
  kind: ExploreShowKindState, display: ExploreShowDisplayState,
  books: ExploreBookItemUi[], page: ExplorePageState,
  filterStateId: number, conflict: BookshelfConflict | undefined,
  isResolvingConflict: boolean): ExploreShowUiState {
  const state: ExploreShowUiState = {
    sourceUrl: display.sourceUrl,
    books: books,
    kinds: kind.kinds,
    selectedKindTitle: kind.selectedKindTitle,
    layoutState: display.layoutState,
    gridCount: display.gridCount,
    isLoading: load.isLoading,
    isRefreshing: load.isRefreshing,
    isEnd: load.isEnd,
    errorMsg: load.errorMsg,
    sheet: display.sheet,
    filterStateId: filterStateId,
    bookshelfConflict: conflict,
    isResolvingBookshelfConflict: isResolvingConflict,
    currentPage: page.currentPage,
    canJumpPage: page.canJumpPage
  };
  return state;
}

/** 空状态：字段值与上游 data class 的默认值逐一对应。 */
export function emptyExploreShowUiState(): ExploreShowUiState {
  const state: ExploreShowUiState = {
    sourceUrl: '',
    books: [],
    kinds: [],
    selectedKindTitle: '',
    layoutState: 0,
    gridCount: 3,
    isLoading: false,
    isRefreshing: false,
    isEnd: false,
    errorMsg: '',
    sheet: ExploreShowSheet.None,
    filterStateId: 0,
    bookshelfConflict: undefined,
    isResolvingBookshelfConflict: false,
    currentPage: 1,
    canJumpPage: false
  };
  return state;
}

/** 16 类 Intent 的判别值（上游 `ExploreShowIntent` 的 16 个子类型）。 */
export type ExploreShowIntentKind =
  'InitData'
  | 'LoadMore'
  | 'JumpToPage'
  | 'ForceLoadNext'
  | 'Refresh'
  | 'SwitchKind'
  | 'ToggleLayout'
  | 'SaveGridCount'
  | 'ShowSheet'
  | 'DismissSheet'
  | 'OpenBook'
  | 'AddToShelf'
  | 'DismissBookshelfConflict'
  | 'OpenBookshelfConflictBook'
  | 'CoexistWithBookshelfConflict'
  | 'MigrateBookshelfConflict';

/**
 * 一条 Intent。上游每种 Intent 携带的字段不同，这里用可空字段并集承载，
 * 各 `kind` 只读自己那几个（与上游 `when` 分支一一对应）。
 */
export interface ExploreShowIntent {
  kind: ExploreShowIntentKind;
  /** InitData：书源地址。 */
  sourceUrl: string;
  /** InitData：初始分类地址（可空）。 */
  exploreUrl: string;
  /** JumpToPage / SaveGridCount：页码或列数。 */
  value: number;
  /** SwitchKind：目标分类。 */
  kind_: ExploreKind | undefined;
  /** ShowSheet：要打开的面板。 */
  sheet: ExploreShowSheet;
  /** OpenBook / AddToShelf：目标书。 */
  book: SearchBookItem | undefined;
  /** OpenBook：共享封面键。 */
  sharedCoverKey: string;
  /** OpenBookshelfConflictBook：冲突里被点的副本。 */
  summary: ConflictBookSummary | undefined;
  /** Coexist / Migrate：书架里已有的那本。 */
  existingBookUrl: string;
  /** Coexist / Migrate：携带数据选项。 */
  options: ChangeSourceMigrationOptions | undefined;
}

/** 造一条 Intent：只填 `kind` 与该 kind 需要的字段，其余保持默认。 */
export function exploreShowIntent(kind: ExploreShowIntentKind): ExploreShowIntent {
  const intent: ExploreShowIntent = {
    kind: kind,
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

/** 2 类 Effect 的判别值（上游 `ExploreShowEffect`）。 */
export type ExploreShowEffectKind = 'OpenBookInfo' | 'ShowMessage';

/** 一条 Effect。`OpenBookInfo` 带上游六字段（:76-83）。 */
export interface ExploreShowEffect {
  kind: ExploreShowEffectKind;
  name: string;
  author: string;
  bookUrl: string;
  origin: string;
  coverPath: string;
  sharedCoverKey: string;
  message: string;
}

/** 造一条 Effect。 */
export function exploreShowEffect(kind: ExploreShowEffectKind): ExploreShowEffect {
  const effect: ExploreShowEffect = {
    kind: kind,
    name: '',
    author: '',
    bookUrl: '',
    origin: '',
    coverPath: '',
    sharedCoverKey: '',
    message: ''
  };
  return effect;
}

/** `OpenBookInfo` 的便捷构造（上游 `ExploreShowViewModel.kt:125-134` 的六字段映射）。 */
export function openBookInfoEffect(book: SearchBookItem, sharedCoverKey: string): ExploreShowEffect {
  const effect = exploreShowEffect('OpenBookInfo');
  effect.name = book.name;
  effect.author = book.author;
  effect.bookUrl = book.bookUrl;
  effect.origin = book.origin;
  effect.coverPath = book.coverUrl;
  effect.sharedCoverKey = sharedCoverKey;
  return effect;
}

/** `ShowMessage` 的便捷构造。 */
export function showMessageEffect(message: string): ExploreShowEffect {
  const effect = exploreShowEffect('ShowMessage');
  effect.message = message;
  return effect;
}
