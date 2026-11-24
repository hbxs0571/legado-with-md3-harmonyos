/**
 * 书架管理页的契约层，逐字段对齐上游
 * `ui/book/manage/BookshelfManageScreenViewModel.kt:81-191`。
 *
 * 上游是 Compose + ViewModel + StateFlow 的 MVI 结构：
 * - `BookshelfManageScreenExportConfig`（:81-95）10 个导出设置字段
 * - `BookshelfManageScreenUiState`（:97-126）19 个状态字段
 * - `BookshelfManageScreenIntent`（:128-185）38 类意图
 * - `BookshelfManageScreenEffect`（:187-191）3 类一次性副作用
 *
 * ArkTS 没有 sealed interface，用「接口 + 判别字段」等价表达：
 * 每个 Intent 带 `type` 枚举值，dispatch 里按 type 分发到具体分支；
 * Effect 同理，页面消费后丢弃（上游是 Channel 一次性事件）。
 */
import { Book } from '../model/Book';
import { BookGroup } from '../model/BookGroup';
import { BookSource } from '../model/BookSource';
import {
  BookExportSettings,
  defaultBookExportSettings
} from './BookExportSettings';
import {
  ChangeSourceMigrationOptions,
  defaultMigrationOptions
} from '../bookSource/ChangeSourceCoordinator';

/**
 * 导出配置。上游 `BookshelfManageScreenExportConfig`（:81-95）。
 *
 * 与本地 `BookExportSettings` 的关系：字段一一同名同义，本文件只额外提供
 * 上游的派生属性 `isCustomEpubExportEnabled`（`enableCustomExport && exportType == 1`，:93-94）。
 * 之所以不直接把派生属性塞进 `BookExportSettings`，是因为那份结构要落 preferences，
 * 派生值不该持久化。
 */
export type BookshelfManageExportConfig = BookExportSettings;

/** 上游 `isCustomEpubExportEnabled`（:93-94）：开启自定义导出且格式是 epub（下标 1）。 */
export function isCustomEpubExportEnabled(config: BookshelfManageExportConfig): boolean {
  return config.enableCustomExport && config.exportType === 1;
}

/** 导出格式清单。上游 `exportTypes = arrayListOf("txt", "epub")`（Screen:203）。 */
export const MANAGE_EXPORT_TYPES: string[] = ['txt', 'epub'];

/** 常用字符集。上游 `commonCharsets`（Screen:204）。 */
export const MANAGE_COMMON_CHARSETS: string[] =
  ['UTF-8', 'GBK', 'GB2312', 'GB18030', 'Big5', 'UTF-16'];

/**
 * 页面状态。上游 `BookshelfManageScreenUiState`（:97-126）19 个字段，逐个对应。
 *
 * 说明几处本地化：
 * - `selectedBookUrls` / `selectedBooks`：上游用 ImmutableSet/ImmutableList 保证
 *   「选中态跨分组保留实体」——切分组、搜关键词都不会丢选中。本地用数组 + Set 表达，
 *   但同样**持有 Book 实体**而不是只存 url，否则跨分组导出会按 url 回查而漏书。
 * - `bookSort` / `bookSortOrder`：上游从 bookshelfSettingsGateway 取全局设置，本地从入参 groups
 *   里拿当前分组的 bookSort（本地分组设置就带 bookSort）。
 * - `bookSources`：上游给「批量换源」的目标源列表，本地从 BookSourceRepository 取。
 */
export interface BookshelfManageUiState {
  /** 当前分组 id；-1 = 全部（上游 :98 默认 -1）。 */
  groupId: number;
  /** 当前分组名；null = 全部（上游 :99）。 */
  groupName: string | null;
  groupList: BookGroup[];
  books: Book[];
  /** 选中的 bookUrl 集合（上游 :107）。 */
  selectedBookUrls: string[];
  /** 选中的 Book 实体（上游 :112），跨分组保留。 */
  selectedBooks: Book[];
  /** 当前排序方式（上游 :113），3 = 手动排序。 */
  bookSort: number;
  /** 排序方向（上游 :114）。 */
  bookSortOrder: number;
  isDownloadRunning: boolean;
  isChangingSource: boolean;
  changeSourceProgress: string;
  changeSourceMessage: string;
  changeSourceError: string;
  /** 换源预览条目（上游 :120）。 */
  batchChangePreviewItems: BatchChangeSourcePreviewItem[];
  /** 换源迁移选项（上游 :121）。 */
  batchChangeOptions: ChangeSourceMigrationOptions;
  /**
   * 缓存版本号（上游 :122）。上游每次缓存变化 +1，用它当 remember 的 key 触发重算；
   * 本地在下载队列回调里递增，用来驱动列表重算「已缓存 N/M 章」。
   */
  cacheVersion: number;
  /** 删除时是否连带删源文件（上游 :123，默认取全局 LocalConfig.deleteBookOriginal）。 */
  deleteBookOriginal: boolean;
  exportConfig: BookshelfManageExportConfig;
  bookSources: BookSource[];
}

/** 空状态。上游各字段的默认值（:97-126）。 */
export function emptyManageUiState(): BookshelfManageUiState {
  return {
    groupId: -1,
    groupName: null,
    groupList: [],
    books: [],
    selectedBookUrls: [],
    selectedBooks: [],
    bookSort: -1,
    bookSortOrder: 0,
    isDownloadRunning: false,
    isChangingSource: false,
    changeSourceProgress: '',
    changeSourceMessage: '',
    changeSourceError: '',
    batchChangePreviewItems: [],
    batchChangeOptions: defaultMigrationOptions(),
    cacheVersion: 0,
    deleteBookOriginal: false,
    exportConfig: defaultBookExportSettings(),
    bookSources: []
  };
}

/** 换源预览状态。上游 `BatchChangeSourcePreviewStatus`（`ChangeBookSourceUseCase.kt:65-69`）。 */
export enum BatchChangeSourcePreviewStatus {
  /** 已匹配到候选书。 */
  Matched = 0,
  /** 没找到。 */
  NotFound = 1,
  /** 用户跳过不迁移。 */
  Skipped = 2
}

/** 单个候选源。上游 `BatchChangeSourceCandidate`（`ChangeBookSourceUseCase.kt`）。 */
export interface BatchChangeSourceCandidate {
  source: BookSource;
  book: Book;
  chapterCount: number;
}

/** 一本书的换源预览。上游 `BatchChangeSourcePreviewItem`（`ChangeBookSourceUseCase.kt:52-63`）。 */
export interface BatchChangeSourcePreviewItem {
  oldBook: Book;
  candidates: BatchChangeSourceCandidate[];
  /** 当前选中的候选下标；-1 = 未选。 */
  selectedCandidateIndex: number;
  status: BatchChangeSourcePreviewStatus;
  /** 当前选中的候选（由 selectedCandidateIndex 派生），没有则 null。 */
  selectedCandidate: BatchChangeSourceCandidate | null;
}

/** 换源结果。上游 `BatchChangeSourceResult`（`ChangeBookSourceUseCase.kt`）。 */
export interface BatchChangeSourceResult {
  succeeded: number;
  failed: number;
  skipped: number;
}

/** Intent 种类。上游 `BookshelfManageScreenIntent`（:128-185）38 类，逐个对应。 */
export enum ManageIntentType {
  Initialize = 'Initialize',
  ChangeGroup = 'ChangeGroup',
  StartDownloadForVisibleBooks = 'StartDownloadForVisibleBooks',
  StopDownload = 'StopDownload',
  ToggleBookDownload = 'ToggleBookDownload',
  DeleteBookDownload = 'DeleteBookDownload',
  ClearBookCache = 'ClearBookCache',
  ToggleBookSelection = 'ToggleBookSelection',
  SelectVisibleBooks = 'SelectVisibleBooks',
  InvertVisibleBooks = 'InvertVisibleBooks',
  ClearBookSelection = 'ClearBookSelection',
  MoveBooksToGroup = 'MoveBooksToGroup',
  DeleteBooks = 'DeleteBooks',
  ClearCachesForBooks = 'ClearCachesForBooks',
  MoveBookOrder = 'MoveBookOrder',
  DownloadBooks = 'DownloadBooks',
  ChangeBookSource = 'ChangeBookSource',
  BatchChangeBookSource = 'BatchChangeBookSource',
  MigratePreviewItem = 'MigratePreviewItem',
  SkipPreviewItem = 'SkipPreviewItem',
  SelectPreviewCandidate = 'SelectPreviewCandidate',
  UpdatePreviewItem = 'UpdatePreviewItem',
  AddPreviewItemToShelf = 'AddPreviewItemToShelf',
  OpenBookInfoPreview = 'OpenBookInfoPreview',
  MigrateAllPreviewItems = 'MigrateAllPreviewItems',
  AddAllPreviewItemsToShelf = 'AddAllPreviewItemsToShelf',
  DismissChangeSourceStatus = 'DismissChangeSourceStatus',
  DismissBatchChangePreview = 'DismissBatchChangePreview',
  SetExportUseReplace = 'SetExportUseReplace',
  SetEnableCustomExport = 'SetEnableCustomExport',
  SetExportNoChapterName = 'SetExportNoChapterName',
  SetExportToWebDav = 'SetExportToWebDav',
  SetExportPictureFile = 'SetExportPictureFile',
  SetParallelExportBook = 'SetParallelExportBook',
  SetExportType = 'SetExportType',
  SetExportCharset = 'SetExportCharset',
  SetBookExportFileName = 'SetBookExportFileName',
  SetEpisodeExportFileName = 'SetEpisodeExportFileName'
}

/**
 * 一个意图。上游是 sealed interface 的 38 个 data class/object，参数各不相同；
 * ArkTS 用单一接口 + 可选字段承载（字段名与上游构造参数同名），dispatch 时按 type 取用。
 */
export interface ManageIntent {
  type: ManageIntentType;
  /** Initialize / ChangeGroup：分组 id。 */
  groupId?: number;
  /** 各 Download 类：是否下载全部章节。 */
  downloadAllChapters?: boolean;
  /** 带书对象：ToggleBookDownload / ClearBookCache / OpenBookInfoPreview。 */
  book?: Book;
  /** 带 bookUrl 的操作：DeleteBookDownload / MigratePreviewItem / SkipPreviewItem。 */
  bookUrl?: string;
  /** 批量操作的书 url 集合。 */
  bookUrls?: string[];
  /** 可见书 url 集合（Select/Invert 用）。 */
  visibleBookUrls?: string[];
  /** 删除时是否删源文件。 */
  deleteOriginal?: boolean;
  /** 手动排序：源下标。 */
  fromIndex?: number;
  /** 手动排序：目标下标。 */
  toIndex?: number;
  /** 单本换源：旧书 url。 */
  oldBookUrl?: string;
  /** 换源：目标书源。 */
  source?: BookSource;
  /** 换源：目标书源列表。 */
  sources?: BookSource[];
  /** 换源：迁移选项。 */
  options?: ChangeSourceMigrationOptions;
  /** 换源预览：候选下标。 */
  candidateIndex?: number;
  /** 换源预览：目录章节数。 */
  chapterCount?: number;
  /** OpenBookInfoPreview：是否在书架上。 */
  inBookshelf?: boolean;
  /** 导出开关类：布尔值。 */
  enabled?: boolean;
  /** SetExportType：格式下标。 */
  exportTypeIndex?: number;
  /** SetExportCharset：字符集。 */
  charset?: string;
  /** SetBookExportFileName：文件名模板；空串等价 null。 */
  fileName?: string;
}

/**
 * 构造一个 Intent。
 *
 * 上游 38 类 Intent 每类带不同参数（`BookshelfManageScreenViewModel.kt:128-185`）；
 * 本地用一个可选字段全开的接口承载，第二参数传入要覆盖的字段。
 */
export function manageIntent(type: ManageIntentType, patch?: Partial<ManageIntent>): ManageIntent {
  const intent: ManageIntent = { type: type };
  if (patch === undefined) { return intent; }
  if (patch.groupId !== undefined) { intent.groupId = patch.groupId; }
  if (patch.downloadAllChapters !== undefined) { intent.downloadAllChapters = patch.downloadAllChapters; }
  if (patch.book !== undefined) { intent.book = patch.book; }
  if (patch.bookUrl !== undefined) { intent.bookUrl = patch.bookUrl; }
  if (patch.bookUrls !== undefined) { intent.bookUrls = patch.bookUrls; }
  if (patch.visibleBookUrls !== undefined) { intent.visibleBookUrls = patch.visibleBookUrls; }
  if (patch.deleteOriginal !== undefined) { intent.deleteOriginal = patch.deleteOriginal; }
  if (patch.fromIndex !== undefined) { intent.fromIndex = patch.fromIndex; }
  if (patch.toIndex !== undefined) { intent.toIndex = patch.toIndex; }
  if (patch.oldBookUrl !== undefined) { intent.oldBookUrl = patch.oldBookUrl; }
  if (patch.source !== undefined) { intent.source = patch.source; }
  if (patch.sources !== undefined) { intent.sources = patch.sources; }
  if (patch.options !== undefined) { intent.options = patch.options; }
  if (patch.candidateIndex !== undefined) { intent.candidateIndex = patch.candidateIndex; }
  if (patch.chapterCount !== undefined) { intent.chapterCount = patch.chapterCount; }
  if (patch.inBookshelf !== undefined) { intent.inBookshelf = patch.inBookshelf; }
  if (patch.enabled !== undefined) { intent.enabled = patch.enabled; }
  if (patch.exportTypeIndex !== undefined) { intent.exportTypeIndex = patch.exportTypeIndex; }
  if (patch.charset !== undefined) { intent.charset = patch.charset; }
  if (patch.fileName !== undefined) { intent.fileName = patch.fileName; }
  return intent;
}

/** Effect 种类。上游 `BookshelfManageScreenEffect`（:187-191）3 类。 */
export enum ManageEffectType {
  NotifyBookChanged = 'NotifyBookChanged',
  ShowMessage = 'ShowMessage',
  OpenBookInfo = 'OpenBookInfo'
}

/** 一次性副作用。上游 3 个 data class 的参数合并成一个接口。 */
export interface ManageEffect {
  type: ManageEffectType;
  bookUrl: string;
  message: string;
  name: string;
  author: string;
}
