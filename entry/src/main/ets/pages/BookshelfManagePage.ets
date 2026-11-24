import { UiSwitchControl } from '../components/UiSwitchControl';
import { UiMenuItem, UiMenuPanel } from '../components/UiMenu';
import { UiDropdown } from '../components/settings/UiDropdown';
import { GroupEditorSheet } from '../components/booksource/GroupEditorSheet';
import { Book } from '../model/Book';
import { BookGroup, BookGroupDraft } from '../model/BookGroup';
import { BookRepository } from '../data/BookRepository';
import { BookGroupRepository } from '../data/BookGroupRepository';
import { LocalBookRestorePlanner } from '../data/LocalBookRestorePlanner';
import { BookExporter, ExportTarget } from '../data/BookExporter';
// 第十表 F-12：导出的后台长时任务，对齐上游 `ExportBookService` 前台 Service。
import { ExportBackgroundTask } from '../data/ExportBackgroundTask';
import {
  BookExportSettings,
  BookExportSettingsStore,
  COMMON_EXPORT_CHARSETS,
  EXPORT_TYPES,
  defaultBookExportSettings,
  episodeExportFileNameOf
} from '../data/BookExportSettings';
import { AppGlyph } from '../components/AppGlyph';
import { AppLogSheet } from '../components/AppLogSheet';
import { ChapterDownloadQueue, DownloadState } from '../bookSource/ChapterDownloadQueue';
import { fileIo, fileShare, picker } from '@kit.CoreFileKit';
import { Context } from '@kit.AbilityKit';
import { BODY_MEDIUM, BODY_SMALL, LABEL_LARGE, LABEL_MEDIUM, LABEL_SMALL, TITLE_LARGE, TITLE_MEDIUM, TITLE_SMALL, TITLE_SMALL_EMPHASIZED, TITLE_SMALL_LINE_HEIGHT } from '../components/typography/TypographyTokens';
import { BookSourceRepository } from '../data/BookSourceRepository';
import { BookSource } from '../model/BookSource';
import { realAuthorOf } from '../data/BookExportSettings';
import { OtherSettingsRepository } from '../data/OtherSettingsRepository';
import {
  BookshelfManageUiState,
  ManageEffect,
  ManageEffectType,
  ManageIntent,
  ManageIntentType,
  BatchChangeSourcePreviewItem,
  emptyManageUiState,
  isCustomEpubExportEnabled as computeCustomEpubEnabled,
  MANAGE_COMMON_CHARSETS,
  MANAGE_EXPORT_TYPES,
  manageIntent
} from '../data/BookshelfManageState';

/** 卡片式菜单的统一宽度，与书架页、详情页同口径。 */
const MANAGE_MENU_WIDTH: number = 260;
/**
 * B-8 / C-14：列表行间距。上游 `BookshelfManageScreen.kt:538`
 * `verticalArrangement = Arrangement.spacedBy(8.dp)`。
 */
const MANAGE_ROW_GAP: number = 8;
/** C-1：卡片圆角。上游 `GlassCard` 走 M3 shapes.medium，封面内圆角 4dp（`BookItem.kt:275`）。 */
const MANAGE_CARD_RADIUS: number = 12;
/** C-10：选中态容器色。上游 `secondaryContainer`（`BookshelfManageScreen.kt:551-559`）。 */
const MANAGE_ROW_SELECTED_COLOR: string = '#2A2D3A';
/** C-15：上游 `R.string.no_group` =「未分组」。 */
const MANAGE_NO_GROUP_TEXT: string = '未分组';


/**
 * 书架管理页（:447–:475）。上游是 BookshelfManageScreen.kt，本地原先整页未建。
 *
 * 与上游的差异（逐行写进 BOOKSHELF.md 差异说明）：
 * - 上游「下载 / 停止」类按钮服务在线书的章节抓取。批2（:455 :459 :466）已接：
 *   顶栏「更多 → 下载全部」、行内「下载/停止」、选择模式「下载」，三者都调 Index 侧
 *   downloadSelectedBooks（内部只挑没缓存过的章，再交给 ChapterDownloadQueue）。
 *   本地书（isLocal）正文本来就在磁盘上，不给下载入口，右端仍显示「本地书」。
 * - 上游右侧徽标显示「已缓存 N/M 章」；本地按下载队列快照显示六档文字（:442/:459）。
 * - 本地 Book 没有 origin/originName，第三行左半用 groupNames、右半用 androidOriginalPath 的文件名。
 * - 导出走鸿蒙 DocumentViewPicker.save()，每本弹一次系统保存框（:471）。
 * - 删除用自绘 bindSheet（系统 AlertDialog 放不下勾选框），复用批5 的 BookRepository.deleteBooks。
 * - 独立 EPUB 导出打包器见 data/EpubExporter.ets（批10 :565 接在书籍详情页溢出菜单，只对本地书出现）；
 *   批量换源（批10 :564）接在选择模式菜单，面板是 pages/BatchChangeSourceSheet.ets。
 */

@Component
export struct BookshelfManagePage {
  @Prop books: Book[] = [];
  @Prop groups: BookGroup[] = [];
  /**
   * 进页时的分组 **groupId**（上游 `BookshelfManageRouteScreen(groupId)` →
   * `LaunchedEffect(groupId) { Initialize(groupId) }`，`BookshelfManageScreen.kt:139-153`）。
   * 第十表 H-8：上游入口参数就是 groupId，`-1` 即 `BookGroup.IdAll`「全部」。
   */
  @Prop initialGroupId: number = -1;
  /**
   * 第十表 G-12：批量换源「确认」后的清空选择信号。
   *
   * 上游 `BookshelfManageScreen.kt:801-817` 的 `ChangeSourceMigrationOptionsSheet.onConfirm`
   * 里在 `dispatch(BatchChangeBookSource(...))` 之后紧接 `clearSelection()` ——
   * 选择态是页面自己的状态，批量换源面板拿不到它，所以由 Index 在确认后把这个值 +1，
   * 这里监听到变化就清空选择，等价上游那次 `clearSelection()`。
   */
  @Prop @Watch('onBatchSourceConfirmSignal') batchSourceConfirmSignal: number = 0;
  onBack: () => void = () => {};
  onOpenBookInfo: (book: Book) => void = (_book: Book) => {};
  /** 批量改动后通知 Index 重载书架。 */
  onLibraryChanged: () => Promise<void> = async () => {};
  onUnavailableAction: (message: string) => void = (_message: string) => {};
  /** 批2（:455）：顶栏「更多 → 下载全部」；只下没缓存过的章节，由 Index 统一入队。 */
  onDownloadAll: (books: Book[]) => void = (_books: Book[]) => {};
  /** 批2（:466）：选择模式「下载」。 */
  onDownloadSelected: (books: Book[]) => void = (_books: Book[]) => {};
  /** 批2（:469）：选择模式「清除缓存」，Index 侧按 isLocal 分流后才动磁盘。 */
  onClearSelectedCache: (books: Book[]) => void = (_books: Book[]) => {};
  /** 批2（:471）：单本「分段导出」，按范围挑章、每卷 N 章拆成多个 EPUB。 */
  onExportSegmented: (book: Book, scopeSpec: string, chaptersPerVolume: number) => void =
    (_book: Book, _scopeSpec: string, _chaptersPerVolume: number) => {};
  /** 批10（:564）：选择模式「批量换源」，交给 Index 打开 BatchChangeSourceSheet。 */
  onBatchChangeSource: (books: Book[]) => void = (_books: Book[]) => {};
  /**
   * G-1：行内「更多 → 换源」的单本换源入口。上游 `BookshelfManageScreen.kt:770-788` 的
   * `ChangeSourceSheet(data=singleChangeSourceBook)` 是「按书名自动搜候选」的单本流程，
   * 与选择模式下的批量向导（`BatchChangeSourceSheet`）不是同一条链，不能合并。
   */
  onOpenChangeSource: (book: Book) => void = (_book: Book) => {};

  /**
   * 第十表 H-4：选组面板里的「新建分组 / 编辑」走 `GroupEditorSheet`，
   * 与书架页共用同一份表单；落库与选封面由 Index 统一提供。
   */
  onAddGroupDraft: (draft: BookGroupDraft) => Promise<void> = async (_draft: BookGroupDraft) => {};
  onUpdateGroup: (groupId: number, draft: BookGroupDraft) => Promise<void> =
    async (_groupId: number, _draft: BookGroupDraft) => {};
  onChooseGroupCover: (groupId: number) => Promise<string> = async (_groupId: number) => '';
  onChooseGroupCoverDraft: () => Promise<string> = async () => '';
  onClearGroupCover: (groupId: number) => Promise<void> = async (_groupId: number) => {};
  onRemoveGroup: (groupId: number) => void = (_groupId: number) => {};
  onApplyTagGroupRules: () => Promise<void> = async () => {};

  @StorageProp('themeColorSurfaceTertiary') themeColorSurfaceTertiary: string = '#F0F1F5';
  @StorageProp('themeColorTextPrimary') themeColorTextPrimary: string = '#F1F2F6';
  @StorageProp('themeColorTextSecondary') themeColorTextSecondary: string = '#AEB0BA';
  @StorageProp('themeColorTextTertiary') themeColorTextTertiary: string = '#858792';
  @StorageProp('themeColorAccent') themeColorAccent: string = '#B9C6FF';
  @StorageProp('themeColorSurfacePrimary') themeColorSurfacePrimary: string = '#17181E';
  @StorageProp('themeColorSurfaceElevated') themeColorSurfaceElevated: string = '#23242C';
  @StorageProp('themeColorSurfaceSecondary') themeColorSurfaceSecondary: string = '#1F2027';
  /**
   * C-1 / C-10：上游 GlassCard 的容器色取 `surfaceContainer`（非 miuix 引擎）或
   * `surfaceContainerLow`（miuix 引擎），选中态取 `secondaryContainer`
   * （BookshelfManageScreen.kt:551-559 `animateColorAsState`）。
   */
  @StorageProp('themeColorSurfaceContainer') themeColorSurfaceContainer: string = '#1E1F25';
  @StorageProp('themeColorSurfaceContainerLow') themeColorSurfaceContainerLow: string = '#191A20';
  @StorageProp('themeColorSecondaryContainer') themeColorSecondaryContainer: string = '#DCE7C8';
  @StorageProp('appTopInset') appTopInset: number = 0;

  @State currentGroupName: string = '';
  @State isSearchMode: boolean = false;
  @State searchKey: string = '';
  @State selectionMode: boolean = false;
  /** 键用 bookUrl + id；book.id 是文件名派生的，同名异目录会撞键。 */
  @State selectedBookKeys: Set<string> = new Set<string>();
  @State showDeleteConfirm: boolean = false;
  @State deleteOriginalFile: boolean = false;
  /** B-7：选择态 FAB 菜单展开态（上游 `fabMenuExpanded`，:181 saveable）。 */
  @State fabMenuExpanded: boolean = false;
  /** C-11：拖动排序当前拖起的下标（-1 表示没在拖）。 */
  @State draggingIndex: number = -1;
  /** C-11：拖动浮起预览显示的书名。 */
  @State dragPreviewTitle: string = '';
  /** D-10：批量换源进度/错误框可见性（上游 `isChangingSource || changeSourceError != null`）。 */
  @State showChangeSourceStatus: boolean = false;
  /** D-9：导出文件夹选择中间 Sheet（上游 `showFilePickerSheet`）。 */
  @State showExportFolderPicker: boolean = false;
  @State pendingDeleteKeys: string[] = [];
  @State showExportSheet: boolean = false;
  @State showExportSettings: boolean = false;
  @State exportBooks: Book[] = [];
  /**
   * 选目录这条路上「选完要继续导出」的那批书（第十表 F-4）。
   *
   * 对齐上游 `BookshelfManageScreen.kt:326-350 startExportForBooks(books)`：
   * 目录为空/不可写时先 `selectExportFolder(books)` 把 books 记进 `pendingExportBooks`，
   * 等目录选择器的回调（`:279-312`）拿着这批书继续判自定义导出或逐本导出。
   * 本地原来 `chooseExportFolder()` 选完只保存路径就结束，那批书就丢了，
   * 用户点了「导出」却什么都没发生 —— 这里补上同一个「待办批次」。
   */
  @State pendingExportBooks: Book[] = [];
  @State exportMsgByKey: Map<string, string> = new Map<string, string>();
  /**
   * 导出设置，10 个字段与上游 `BookExportSettings.kt:3-14` 一一对应，存 preferences
   * （`BookExportSettingsStore`）。原先这里的 exportCharset / exportCustomCharset /
   * exportFileNameTemplate / exportWithChapterName 四个 @State 是本地自造形态：
   * 占位符是 {title}/{author}/{index}、字符集靠一个自由输入框、没有替换净化与插图开关。
   * 改成整份设置对象后，字段名与语义都按上游来，跨端导出的行为才对得上。
   */
  @State exportSettings: BookExportSettings = defaultBookExportSettings();
  /** 「导出文件夹」当前值；上游存在 ACache 的 exportBookPath 键下，本地存 preferences。 */
  @State exportFolderPath: string = '';
  /** 导出文件夹最近一次的可写探测结果，用来决定设置行说明文字。 */
  @State exportFolderWritable: boolean = true;
  /** 自定义字符集对话框的输入暂存（点确定才写回 exportSettings）。 */
  @State exportCharsetDraft: string = '';
  /** 导出文件名对话框的输入暂存。 */
  @State exportFileNameDraft: string = '';
  /** 两个输入对话框的显隐；都用 openCustomDialog 弹出（showAlertDialog 带不了输入框）。 */
  @State showCharsetDialog: boolean = false;
  @State showFileNameDialog: boolean = false;
  /** openCustomDialog 的 builder 需存成成员，且每次重开重建以刷新内部输入态。 */
  private exportDialogBuilder: () => void = () => {};
  private exportDialogId: number = -1;

  @State showGroupSelect: boolean = false;
  /** 批2（:471）：分段导出的输入与目标书。 */
  @State segmentedExportBook: Book | undefined = undefined;
  /**
   * 自定义导出对话框（上游 `BookshelfManageScreen.kt:1248-1371`）。
   * 上游的触发条件是「刚选完导出目录 + 只选了一本书 + `enableCustomExport && exportType == 1`」
   * （`isCustomEpubExportEnabled`，`BookshelfManageScreenViewModel.kt:93-94`），本地没有「选完目录」
   * 这个时机，等价时机是点「导出」那一刻，所以在 `runExport` 里判。
   */
  @State showCustomExportDialog: boolean = false;
  /** true = 导出全本；false = 按下面的范围挑章。 */
  @State customExportAllChapter: boolean = true;
  @State customScopeInput: string = '1-';
  @State customVolumeSizeInput: string = '1';
  @State customFileNameInput: string = '';
  /** 范围格式错误时的提示（上游 `customEpubScopeError`，文案见 `strings.xml:1620`）。 */
  @State customScopeError: string = '';
  private customExportDialogBuilder: () => void = () => {};
  private customExportDialogId: number = -1;
  // 四个卡片式菜单的显隐状态，各自独立，避免互相顶掉。
  @State groupFilterVisible: boolean = false;
  @State moreMenuVisible: boolean = false;
  @State selectionMenuVisible: boolean = false;
  @State groupSelectBookKeys: string[] = [];
  /** 第十表 H-4：选组面板是多选，这里是当前选中的组名集合（上游是 group 位掩码）。 */
  @State selectedGroupNames: string[] = [];
  /** 打开选组面板时要编辑的分组（「新建分组 / 每行编辑」共用同一个编辑面板）。 */
  @State groupEditing: BookGroup | undefined = undefined;
  @State showGroupEditor: boolean = false;
  @State rowMenuKey: string = '';
  /** 日志面板显隐；面板内容由公共组件 AppLogSheet 自己从 AppLog 取。 */
  @State showLogSheet: boolean = false;
  /**
   * 批2（:455 :459 :466）：每本书的下载状态，键是 bookKey(book)。
   * ArkUI 里 Map 原地 set 不触发刷新，一律整体替换（同 exportMsgByKey 的坑）。
   */
  @State bookDownloadStates: Map<string, DownloadState> = new Map<string, DownloadState>();
  /** D-4：批量缓存确认框（上游 `showBatchDownloadConfirmDialog`，`BookshelfManageScreen.kt:913-930`）。 */
  @State showBatchDownloadConfirm: boolean = false;
  /** D-5：下载全部确认框（上游 `showDownloadAllConfirmDialog`，`:995-1012`）。 */
  @State showDownloadAllConfirm: boolean = false;

  private listScroller: Scroller = new Scroller();
  /** 下载队列订阅的取消函数；aboutToDisappear 必须调，否则页面销毁后回调还在跑。 */
  private downloadUnsubscribe: (() => void) | undefined = undefined;

  /**
   * A-2（上游 `BookshelfManageScreenViewModel.kt:97-126`）：统一状态对象。
   *
   * 上游是 ViewModel 里的一个 StateFlow<UiState>，19 个字段一次成形；本地原先散成 30 多个
   * @State，跨分组选中、cacheVersion 这类跨字段一致性无处收敛。这里引入 uiState 作为
   * 「上游那一个对象」的等价物：凡是上游 UiState 里有字段的，都从它读；页面自己的纯 UI
   * 显隐（showExportSheet 等 28 个）仍留在 @State —— 上游那些也是 Screen 里的 remember，
   * 不在 UiState 内。
   */
  @State uiState: BookshelfManageUiState = emptyManageUiState();
  /**
   * A-7（上游 :128-185）：38 类 Intent 的统一入口。
   * 所有用户动作都先变成 Intent 再落地，方便逐条对照上游的分支逻辑。
   */
  private pendingEffects: ManageEffect[] = [];

  aboutToAppear(): void {
    // 第十表 H-8：上游 `initialize(groupId)` 末尾是 `refreshGroupName(groupId)`
    // （`BookshelfManageScreenViewModel.kt:585-592`：
    //  `bookGroupRepository.getByID(groupId)?.groupName ?: context.getString(R.string.no_group)`）。
    // 本地按同一个口径反查：先按 groupId 找分组定义，找不到就回落「全部」。
    this.currentGroupName = this.groupNameForId(this.initialGroupId);
    this.downloadUnsubscribe = ChapterDownloadQueue.subscribe(() => this.refreshDownloadStates());
    this.refreshDownloadStates();
    void this.loadExportSettings();
    // A-1/A-7：上游进页第一件事是 dispatch(Initialize(groupId))，把分组、书单、书源一次装满。
    this.dispatch(manageIntent(ManageIntentType.Initialize));
  }

  /**
   * groupId → 分组名（第十表 H-8，对齐上游 `refreshGroupName`）。
   *
   * 上游的内置分组常量见 `data/entities/BookGroup.kt:31-44`：
   * `IdAll = -1L`（全部）、`IdLocalNone = -5L`（本地未分组）等；
   * 其余走 `bookGroupRepository.getByID(groupId)?.groupName`。
   * 本地 `BookGroupRepository.LOCAL_NONE_GROUP_ID` 就是 `-5`，与上游同值。
   * 返回空串表示「全部」（本地 `currentGroupName` 的既有约定）。
   */
  private groupNameForId(groupId: number): string {
    if (groupId === -1) { return ''; }
    if (groupId === BookGroupRepository.LOCAL_NONE_GROUP_ID) {
      return BookGroupRepository.LOCAL_NONE_GROUP_NAME;
    }
    const group = this.groups.find((item: BookGroup) => item.groupId === groupId);
    return group !== undefined ? group.groupName : '';
  }

  aboutToDisappear(): void {
    if (this.downloadUnsubscribe !== undefined) {
      this.downloadUnsubscribe();
      this.downloadUnsubscribe = undefined;
    }
  }

  /**
   * B-10（上游 `BookshelfManageScreen.kt:275-277`
   * `BackHandler(enabled = inSelectionMode) { clearSelection() }`）：
   * 选择态下按系统返回键先退出选择态，而不是直接退出页面。
   * 返回 true 表示已消费该次返回。
   */
  onBackPress(): boolean {
    if (this.selectionMode) {
      this.clearSelection();
      return true;
    }
    return false;
  }

  // ---------------------------------------------------------------- A 区：Intent 分派

  /**
   * A-7（上游 `BookshelfManageScreenViewModel.kt:128-185` 的 38 类 Intent）。
   *
   * 上游每个 Intent 在 ViewModel 里有一个 when 分支改 UiState；这里同构：
   * 按 type 改 this.uiState（整体换新对象以触发刷新），再统一消费 effects。
   */
  private dispatch(intent: ManageIntent): void {
    switch (intent.type) {
      case ManageIntentType.Initialize:
        this.handleInitialize();
        break;
      case ManageIntentType.ChangeGroup:
        this.handleChangeGroup(intent.groupId ?? -1);
        break;
      case ManageIntentType.ToggleBookSelection: {
        const url = intent.bookUrl ?? '';
        if (url.length > 0) { this.toggleSelectionByUrl(url); }
        break;
      }
      case ManageIntentType.SelectVisibleBooks:
        this.handleSelectVisible(intent.visibleBookUrls ?? []);
        break;
      case ManageIntentType.InvertVisibleBooks:
        this.handleInvertVisible(intent.visibleBookUrls ?? []);
        break;
      case ManageIntentType.ClearBookSelection:
        this.clearSelection();
        break;
      case ManageIntentType.MoveBookOrder: {
        const from = intent.fromIndex ?? -1;
        const to = intent.toIndex ?? -1;
        if (from >= 0 && to >= 0) { void this.handleMoveBookOrder(from, to); }
        break;
      }
      case ManageIntentType.SetExportUseReplace:
        void this.patchExportSettings((draft: BookExportSettings) => {
          draft.exportUseReplace = intent.enabled === true;
        });
        break;
      case ManageIntentType.SetEnableCustomExport:
        void this.patchExportSettings((draft: BookExportSettings) => {
          draft.enableCustomExport = intent.enabled === true;
        });
        break;
      case ManageIntentType.SetExportNoChapterName:
        void this.patchExportSettings((draft: BookExportSettings) => {
          draft.exportNoChapterName = intent.enabled === true;
        });
        break;
      case ManageIntentType.SetExportToWebDav:
        void this.patchExportSettings((draft: BookExportSettings) => {
          draft.exportToWebDav = intent.enabled === true;
        });
        break;
      case ManageIntentType.SetExportPictureFile:
        void this.patchExportSettings((draft: BookExportSettings) => {
          draft.exportPictureFile = intent.enabled === true;
        });
        break;
      case ManageIntentType.SetParallelExportBook:
        void this.patchExportSettings((draft: BookExportSettings) => {
          draft.parallelExportBook = intent.enabled === true;
        });
        break;
      case ManageIntentType.SetExportType:
        void this.patchExportSettings((draft: BookExportSettings) => {
          draft.exportType = intent.exportTypeIndex ?? 0;
        });
        break;
      case ManageIntentType.SetExportCharset:
        void this.patchExportSettings((draft: BookExportSettings) => {
          draft.exportCharset = (intent.charset ?? '').length > 0 ? (intent.charset ?? '') : 'UTF-8';
        });
        break;
      case ManageIntentType.SetBookExportFileName:
        void this.patchExportSettings((draft: BookExportSettings) => {
          draft.bookExportFileName = intent.fileName ?? '';
        });
        break;
      case ManageIntentType.SetEpisodeExportFileName:
        void this.patchExportSettings((draft: BookExportSettings) => {
          draft.episodeExportFileName = intent.fileName ?? '';
        });
        break;
      case ManageIntentType.ClearCachesForBooks: {
        const urls = intent.bookUrls ?? [];
        if (urls.length > 0) {
          const books = this.books.filter((book: Book) => urls.includes(this.bookKey(book)));
          this.onClearSelectedCache(books);
          this.bumpCacheVersion();
        }
        break;
      }
      case ManageIntentType.DeleteBooks: {
        const urls = intent.bookUrls ?? [];
        if (urls.length > 0) { void this.deleteBooksByUrl(urls, intent.deleteOriginal === true); }
        break;
      }
      case ManageIntentType.MoveBooksToGroup: {
        const urls = intent.bookUrls ?? [];
        const gid = intent.groupId ?? 0;
        if (urls.length > 0) { void this.moveBooksToGroupByUrl(urls, gid); }
        break;
      }
      case ManageIntentType.DownloadBooks: {
        const urls = intent.bookUrls ?? [];
        const targets = this.books.filter((book: Book) => urls.includes(this.bookKey(book)));
        if (targets.length > 0) { this.onDownloadSelected(targets); }
        break;
      }
      case ManageIntentType.StartDownloadForVisibleBooks:
        this.onDownloadAll(this.visibleBooks());
        break;
      case ManageIntentType.StopDownload:
        ChapterDownloadQueue.stop();
        this.refreshDownloadStates();
        break;
      case ManageIntentType.ToggleBookDownload: {
        const book = intent.book;
        if (book !== undefined) { this.toggleBookDownload(book); }
        break;
      }
      case ManageIntentType.OpenBookInfoPreview: {
        const book = intent.book;
        if (book !== undefined) { this.onOpenBookInfo(book); }
        break;
      }
      case ManageIntentType.BatchChangeBookSource: {
        const urls = intent.bookUrls ?? [];
        const targets = this.books.filter((book: Book) => urls.includes(this.bookKey(book)));
        if (targets.length > 0) {
          // D-10：上游换源进行中会弹出「批量换源」进度框（:867-901），本地换源交给
          // Index 的 BatchChangeSourceSheet 向导，但状态框仍按上游三态呈现。
          this.uiState = this.nextState({ isChangingSource: true, changeSourceError: '', changeSourceProgress: '' });
          this.showChangeSourceStatus = true;
          this.onBatchChangeSource(targets);
        }
        break;
      }
      case ManageIntentType.DismissChangeSourceStatus:
        this.uiState = this.nextState({ isChangingSource: false, changeSourceError: '', changeSourceProgress: '' });
        break;
      case ManageIntentType.DismissBatchChangePreview:
        this.uiState = this.nextState({ batchChangePreviewItems: [] });
        break;
      default:
        break;
    }
    this.consumeEffects();
  }

  /** A-1：上游 `Initialize(groupId)` —— 装分组、书单、书源、导出配置、删除默认值。 */
  private handleInitialize(): void {
    const groupSort = this.currentGroupSort();
    const sources: BookSource[] = BookSourceRepository.getAll();
    this.uiState = this.nextState({
      groupId: this.currentGroupId(),
      groupName: this.currentGroupName.length > 0 ? this.currentGroupName : null,
      groupList: this.groups,
      books: this.books,
      bookSort: groupSort,
      bookSortOrder: 0,
      deleteBookOriginal: this.uiState.deleteBookOriginal,
      exportConfig: this.exportSettings,
      bookSources: sources,
      selectedBookUrls: this.selectedBookKeys.size > 0 ? this.selectedUrlsFromKeys() : [],
      selectedBooks: this.selectedBooks()
    });
  }

  /** 上游 `ChangeGroup(groupId)`：切分组。本地按分组名切换（本地 Book 无 group 位掩码）。 */
  private handleChangeGroup(groupId: number): void {
    if (groupId <= 0) {
      this.currentGroupName = '';
    } else {
      const group = this.groups.find((item: BookGroup) => item.groupId === groupId);
      this.currentGroupName = group !== undefined ? group.groupName : '';
    }
    this.uiState = this.nextState({
      groupId: groupId,
      groupName: this.currentGroupName.length > 0 ? this.currentGroupName : null,
      bookSort: this.currentGroupSort()
    });
  }

  /** 整体换新对象，ArkUI 才会认为 @State 变了。 */
  private nextState(patch: Partial<BookshelfManageUiState>): BookshelfManageUiState {
    return {
      groupId: patch.groupId !== undefined ? patch.groupId : this.uiState.groupId,
      groupName: patch.groupName !== undefined ? patch.groupName : this.uiState.groupName,
      groupList: patch.groupList !== undefined ? patch.groupList : this.uiState.groupList,
      books: patch.books !== undefined ? patch.books : this.uiState.books,
      selectedBookUrls: patch.selectedBookUrls !== undefined ? patch.selectedBookUrls : this.uiState.selectedBookUrls,
      selectedBooks: patch.selectedBooks !== undefined ? patch.selectedBooks : this.uiState.selectedBooks,
      bookSort: patch.bookSort !== undefined ? patch.bookSort : this.uiState.bookSort,
      bookSortOrder: patch.bookSortOrder !== undefined ? patch.bookSortOrder : this.uiState.bookSortOrder,
      isDownloadRunning: patch.isDownloadRunning !== undefined ? patch.isDownloadRunning : this.uiState.isDownloadRunning,
      isChangingSource: patch.isChangingSource !== undefined ? patch.isChangingSource : this.uiState.isChangingSource,
      changeSourceProgress: patch.changeSourceProgress !== undefined ? patch.changeSourceProgress : this.uiState.changeSourceProgress,
      changeSourceMessage: patch.changeSourceMessage !== undefined ? patch.changeSourceMessage : this.uiState.changeSourceMessage,
      changeSourceError: patch.changeSourceError !== undefined ? patch.changeSourceError : this.uiState.changeSourceError,
      batchChangePreviewItems: patch.batchChangePreviewItems !== undefined ? patch.batchChangePreviewItems : this.uiState.batchChangePreviewItems,
      batchChangeOptions: patch.batchChangeOptions !== undefined ? patch.batchChangeOptions : this.uiState.batchChangeOptions,
      cacheVersion: patch.cacheVersion !== undefined ? patch.cacheVersion : this.uiState.cacheVersion,
      deleteBookOriginal: patch.deleteBookOriginal !== undefined ? patch.deleteBookOriginal : this.uiState.deleteBookOriginal,
      exportConfig: patch.exportConfig !== undefined ? patch.exportConfig : this.uiState.exportConfig,
      bookSources: patch.bookSources !== undefined ? patch.bookSources : this.uiState.bookSources
    };
  }

  /**
   * A-6（上游 :187-191）：3 类 Effect 的消费端。
   * 上游走 Channel 一次性发出，Screen 在 LaunchedEffect 里消费；这里 dispatch 末尾统一消费。
   */
  private consumeEffects(): void {
    const effects = this.pendingEffects;
    this.pendingEffects = [];
    effects.forEach((effect: ManageEffect) => {
      if (effect.type === ManageEffectType.ShowMessage) {
        this.onUnavailableAction(effect.message);
      } else if (effect.type === ManageEffectType.OpenBookInfo) {
        const book = this.books.find((item: Book) => this.bookKey(item) === effect.bookUrl);
        if (book !== undefined) { this.onOpenBookInfo(book); }
      }
    });
  }

  /** 发一个 Effect，dispatch 末尾统一消费。 */
  private emitEffect(effect: ManageEffect): void {
    this.pendingEffects.push(effect);
  }

  /** A-8（上游 `cacheVersion: Long`）：缓存变化就 +1，驱动列表重算「已缓存 N/M 章」。 */
  private bumpCacheVersion(): void {
    this.uiState = this.nextState({ cacheVersion: this.uiState.cacheVersion + 1 });
  }

  /** 当前分组的排序方式（本地分组设置就带 bookSort；无分组时取 -1 默认）。 */
  private currentGroupSort(): number {
    const name = this.currentGroupName;
    if (name.length === 0) { return -1; }
    const group = this.groups.find((item: BookGroup) => item.groupName === name);
    return group !== undefined ? group.bookSort : -1;
  }

  /** 当前分组 id（本地按名字反查；无分组时 -1）。 */
  private currentGroupId(): number {
    const name = this.currentGroupName;
    if (name.length === 0) { return -1; }
    const group = this.groups.find((item: BookGroup) => item.groupName === name);
    return group !== undefined ? group.groupId : -1;
  }

  /** 选中键 → url 列表。 */
  private selectedUrlsFromKeys(): string[] {
    return this.books
      .filter((book: Book) => this.selectedBookKeys.has(this.rowKey(book)))
      .map((book: Book) => this.bookKey(book));
  }

  /** 按 url 切选中（上游 ToggleBookSelection 收 bookUrl）。 */
  private toggleSelectionByUrl(bookUrl: string): void {
    const book = this.books.find((item: Book) => this.bookKey(item) === bookUrl);
    if (book !== undefined) { this.toggleBookSelection(book); }
  }

  /** 上游 SelectVisibleBooks：只选当前可见的。 */
  private handleSelectVisible(urls: string[]): void {
    const next = new Set<string>(this.selectedBookKeys);
    this.books.forEach((book: Book) => {
      if (urls.includes(this.bookKey(book))) { next.add(this.rowKey(book)); }
    });
    this.selectedBookKeys = next;
    this.selectionMode = next.size > 0;
    void this.resolveSelectedBooks();
  }

  /** 上游 InvertVisibleBooks：`(selected - visible) + (visible - selected)`（:76-79）。 */
  private handleInvertVisible(urls: string[]): void {
    const next = new Set<string>(this.selectedBookKeys);
    this.books.forEach((book: Book) => {
      if (!urls.includes(this.bookKey(book))) { return; }
      const key = this.rowKey(book);
      if (next.has(key)) { next.delete(key); } else { next.add(key); }
    });
    this.selectedBookKeys = next;
    if (next.size === 0) { this.selectionMode = false; }
    void this.resolveSelectedBooks();
  }

  /** A-5 / C-11：手动排序（上游 MoveBookOrder(fromIndex, toIndex)）。 */
  private async handleMoveBookOrder(fromIndex: number, toIndex: number): Promise<void> {
    const context = this.getUIContext().getHostContext();
    if (context === undefined) { return; }
    const visible = this.visibleBooks();
    if (fromIndex >= visible.length || toIndex >= visible.length) { return; }
    const ordered = visible.slice();
    const moved = ordered.splice(fromIndex, 1)[0];
    if (moved === undefined) { return; }
    ordered.splice(toIndex, 0, moved);
    try {
      await BookRepository.saveBookOrder(context, ordered, this.uiState.bookSortOrder > 0);
      await this.onLibraryChanged();
    } catch (error) {
      this.emitEffect({
        type: ManageEffectType.ShowMessage, bookUrl: '', message: '调整排序失败',
        name: '', author: ''
      });
    }
  }

  /** 上游 DeleteBooks(bookUrls, deleteOriginal)。 */
  private async deleteBooksByUrl(urls: string[], deleteOriginal: boolean): Promise<void> {
    const context = this.getUIContext().getHostContext();
    if (context === undefined) { return; }
    const targets = this.books.filter((book: Book) => urls.includes(this.bookKey(book)));
    if (targets.length === 0) { return; }
    try {
      await BookRepository.deleteBooks(context, targets, deleteOriginal);
      await this.onLibraryChanged();
      this.clearSelection();
      this.emitEffect({
        type: ManageEffectType.ShowMessage, bookUrl: '', message: `已删除 ${targets.length} 本书`,
        name: '', author: ''
      });
    } catch (error) {
      this.emitEffect({
        type: ManageEffectType.ShowMessage, bookUrl: '', message: '删除失败，请重试',
        name: '', author: ''
      });
    }
  }

  /** 上游 MoveBooksToGroup(bookUrls, groupId)。 */
  private async moveBooksToGroupByUrl(urls: string[], groupId: number): Promise<void> {
    const context = this.getUIContext().getHostContext();
    if (context === undefined) { return; }
    const group = this.groups.find((item: BookGroup) => item.groupId === groupId);
    const groupName = group !== undefined ? group.groupName : '';
    const targets = this.books.filter((book: Book) => urls.includes(this.bookKey(book)));
    if (targets.length === 0) { return; }
    try {
      await BookRepository.setBooksGroup(context, targets.map((book: Book) => this.bookKey(book)), groupName);
      await this.onLibraryChanged();
      this.clearSelection();
      this.emitEffect({
        type: ManageEffectType.ShowMessage, bookUrl: '',
        message: groupName.length > 0 ? `已移入「${groupName}」` : '已移出分组',
        name: '', author: ''
      });
    } catch (error) {
      this.emitEffect({
        type: ManageEffectType.ShowMessage, bookUrl: '', message: '修改分组失败',
        name: '', author: ''
      });
    }
  }

  /** 当前可见（过滤后）的书。 */
  private visibleBooks(): Book[] {
    return this.filteredBooks();
  }

  /**
   * C-11：上游 `canReorderBooks = state.bookSort == 3 && !isSearchMode && selectedBookUrls.isEmpty()`
   * （BookshelfManageScreen.kt:443）。只有「手动排序」分组、非搜索态、非选择态时才允许拖动。
   */
  private canReorderBooks(): boolean {
    return this.currentGroupSort() === 3 && !this.isSearchMode && this.selectedBookKeys.size === 0;
  }

  /**
   * C-11：ArkUI `List.onItemDrop` 的 `insertIndex` 是「插到原数组第几项之前」，
   * 上游 reorderable 的 `toIndex` 是「移除后应落的最终下标」，这里做一次换算后
   * 复用 `handleMoveBookOrder`（移除 + 插入），避免两套排序逻辑。
   */
  private dropReorder(fromIndex: number, insertIndex: number): void {
    const total = this.filteredBooks().length;
    if (fromIndex < 0 || fromIndex >= total || insertIndex < 0 || insertIndex > total) { return; }
    if (insertIndex === fromIndex || insertIndex === fromIndex + 1) { return; }
    const toIndex = insertIndex > fromIndex ? insertIndex - 1 : insertIndex;
    if (toIndex === fromIndex) { return; }
    void this.handleMoveBookOrder(fromIndex, toIndex);
  }

  // ---------------------------------------------------------------- C 区：行渲染辅助

  /**
   * C-6：上游 `BookshelfManageScreen.kt:637-647`
   * `TextCard(if(book.isLocal) local_book else download_count(cacheCount, book.totalChapterNum))`。
   * 本地 Book 没有 totalChapterNum（只有 chapterCount?: string），用 chapterCount 兜底。
   */
  private totalChapterNumOf(book: Book): number {
    const total = Number(book.chapterCount ?? '0');
    return Number.isFinite(total) && total > 0 ? Math.floor(total) : 0;
  }

  /**
   * C-6：已缓存章节数。上游 `viewModel.getCacheCount(bookUrl) ?: 0`，
   * 随 `renderVersion`（= cacheVersion）重算。
   */
  private cacheCountOf(book: Book): number {
    // 读一次 cacheVersion，让 @State 依赖成立、版本变化时重算。
    const version = this.uiState.cacheVersion;
    if (version < 0) { return 0; }
    return BookRepository.cachedChapterTitles(book).length;
  }

  /**
   * C-13：上游 `:547-548/754-761` 的失败文案行：
   * `downloadFailureText = getDownloadFailureMessage(bookUrl)?.let { stringResource(R.string.cache_download_failed, it) }`
   * →「缓存失败：%1$s」。
   */
  private downloadFailureTextOf(book: Book): string {
    const snapshot = ChapterDownloadQueue.snapshot(this.bookKey(book));
    if (snapshot.failed <= 0) { return ''; }
    return `缓存失败：${snapshot.failed} 章未下载成功`;
  }

  /**
   * C-15：上游 `:218-230` 的 `groupNameResolver`。
   *
   * 上游按 `book.group` 位掩码与 `groupList` 现算：`book.group <= 0L` 或掩码命中为空 →「未分组」，
   * 否则把命中的组名用「、」拼起来。
   * 本地 `Book` 没有 `group` 位掩码字段（只有 `groupNames: string[]`），无法逐位对齐；
   * 这里按 groupNames 现算并做同一套兜底：**过滤掉已不存在的分组名**
   * （等价于上游「掩码命中为空」），兜底文案对齐上游「未分组」。
   */
  private groupNameResolver(book: Book): string {
    const names = book.groupNames ?? [];
    if (names.length === 0) { return MANAGE_NO_GROUP_TEXT; }
    const alive = names.filter((name: string) =>
      this.groups.some((group: BookGroup) => group.groupName === name));
    return alive.length > 0 ? alive.join('、') : MANAGE_NO_GROUP_TEXT;
  }

  /** C-4：上游 `book.getRealAuthor()` —— 剥「作者：」「著」前缀，不补兜底文案。 */
  private realAuthorOf(book: Book): string {
    return realAuthorOf(book.author);
  }

  /**
   * 批2（:459）：把队列快照摊成「每本书一个档位」，整张 Map 换新才触发卡片刷新。
   * 档位判定顺序照上游 CACHE_STATE 的语义：暂停 > 在跑 > 有失败 > 全成 > 空。
   */
  private refreshDownloadStates(): void {
    const next = new Map<string, DownloadState>();
    this.books.forEach((book: Book) => {
      const key = this.bookKey(book);
      const snapshot = ChapterDownloadQueue.snapshot(key);
      let state: DownloadState = 'idle';
      if (snapshot.total > 0) {
        if (snapshot.paused) {
          state = 'paused';
        } else if (snapshot.running > 0) {
          state = 'running';
        } else if (snapshot.done + snapshot.failed >= snapshot.total) {
          state = snapshot.failed > 0 ? 'failed' : 'done';
        } else {
          state = 'queued';
        }
      }
      next.set(key, state);
    });
    this.bookDownloadStates = next;
  }

  private downloadStateOf(book: Book): DownloadState {
    return this.bookDownloadStates.get(this.bookKey(book)) ?? 'idle';
  }

  /**
   * 批2（:442）：六档文案，与缓存管理页同一套措辞，用户在这两页看到的字要一致。
   * 上游枚举在 BookCache 的 CACHE_STATE_*（未缓存/排队/下载中/暂停/完成/失败）。
   */
  private downloadStateLabelOf(book: Book): string {
    const state = this.downloadStateOf(book);
    if (state === 'queued') {
      return '排队中';
    }
    if (state === 'running') {
      return '下载中';
    }
    if (state === 'paused') {
      return '已暂停';
    }
    if (state === 'done') {
      return '已下载';
    }
    if (state === 'failed') {
      return '失败';
    }
    return '未下载';
  }

  /** 已经被队列挡下（暂停）或跑到一半时，图标换成停止。 */
  private isDownloadBusy(book: Book): boolean {
    const state = this.downloadStateOf(book);
    return state === 'queued' || state === 'running';
  }

  private toggleBookDownload(book: Book): void {
    if (this.isDownloadBusy(book)) {
      ChapterDownloadQueue.stop(this.bookKey(book));
      this.refreshDownloadStates();
      return;
    }
    this.onDownloadSelected([book]);
  }

  /** 书目的主键路径，与 deleteBook / setBooksGroup 同口径（contentPath 优先）。 */
  private bookKey(book: Book): string {
    return LocalBookRestorePlanner.bookUrlOf(book);
  }

  /**
   * 复合键：缺正文备份书的 bookUrl 可能是空串，拼上 id 才不重复；
   * 再拼分组名与私密标记，否则移组 / 改私密后 key 不变，ForEach 会复用旧卡片、
   * 第三行分组文案不刷新（批6 bookCardKey 缺 isPrivate 同款坑）。
   */
  private rowKey(book: Book): string {
    return this.bookKey(book) + '_' + book.id + '_' + (book.groupNames ?? []).join('、')
      + '_' + (book.isPrivate === true ? '1' : '0');
  }

  private pageTitle(): string {
    return this.currentGroupName.length > 0 && this.currentGroupName !== '全部'
      ? this.currentGroupName : '离线缓存';
  }

  private groupOptions(): string[] {
    const names: string[] = ['全部'];
    this.groups.forEach((group: BookGroup) => {
      if (group.groupId > 0 && group.groupName.length > 0 && !names.includes(group.groupName)) {
        names.push(group.groupName);
      }
    });
    return names;
  }

  private moveGroupOptions(): string[] {
    const names: string[] = ['无分组'];
    this.groups.forEach((group: BookGroup) => {
      if (group.groupId > 0 && group.groupName.length > 0 && !names.includes(group.groupName)) {
        names.push(group.groupName);
      }
    });
    return names;
  }

  /**
   * 多选面板的候选项：只列真实分组。
   *
   * 上游 `GroupSelectSheet(groups = userGroups)` 的列表里没有「未分组」这一项，
   * 清空分组就是全不选再确认（掩码 0L）。本地沿用同一口径，
   * `moveGroupOptions()` 里那个「无分组」哨兵只留给别处用。
   */
  private groupNamesForSelection(): string[] {
    const names: string[] = [];
    this.groups.forEach((group: BookGroup) => {
      if (group.groupId > 0 && group.groupName.length > 0 && !names.includes(group.groupName)) {
        names.push(group.groupName);
      }
    });
    return names;
  }

  private effectiveGroup(): string {
    return this.currentGroupName.length > 0 ? this.currentGroupName : '全部';
  }

  /**
   * 当前分组 + 搜索关键字过滤。与上游 BookCacheManageScreen 的位与分组判定不同：
   * 本地 Book 只有 groupNames 名字数组，没有 group 位掩码，所以用 includes。
   * 搜索只比书名与作者，大小写不敏感。
   */
  private filteredBooks(): Book[] {
    const keyword = this.searchKey.trim().toLowerCase();
    return this.books.filter((book: Book) => {
      let matchesGroup = this.effectiveGroup() === '全部';
      if (!matchesGroup) {
        matchesGroup = (book.groupNames ?? []).includes(this.currentGroupName);
      }
      // B-3：上游 `filteredBooks` 比 **4 个字段**
      // —— name / getRealAuthor() / originName / groupNameResolver(book)
      // （BookshelfManageScreen.kt:231-243，均 `contains(key, true)` 忽略大小写）。
      const matchesSearch = keyword.length === 0 ||
        book.title.toLowerCase().includes(keyword) ||
        this.realAuthorOf(book).toLowerCase().includes(keyword) ||
        (book.originName ?? '').toLowerCase().includes(keyword) ||
        this.groupNameResolver(book).toLowerCase().includes(keyword);
      return matchesGroup && matchesSearch;
    });
  }

  private isSelected(book: Book): boolean {
    return this.selectedBookKeys.has(this.rowKey(book));
  }

  private toggleBookSelection(book: Book): void {
    const key = this.rowKey(book);
    const next = new Set<string>(this.selectedBookKeys);
    if (next.has(key)) { next.delete(key); } else { next.add(key); }
    this.selectedBookKeys = next;
    if (next.size === 0) { this.selectionMode = false; }
    void this.resolveSelectedBooks();
  }

  /** 全选只作用当前列表可见的书，不是全库（上游 SelectVisibleBooks 同义）。 */
  private selectAllVisible(): void {
    const next = new Set<string>(this.selectedBookKeys);
    this.filteredBooks().forEach((book: Book) => next.add(this.rowKey(book)));
    this.selectedBookKeys = next;
  }

  private invertVisibleSelection(): void {
    const next = new Set<string>(this.selectedBookKeys);
    this.filteredBooks().forEach((book: Book) => {
      const key = this.rowKey(book);
      if (next.has(key)) { next.delete(key); } else { next.add(key); }
    });
    this.selectedBookKeys = next;
    if (next.size === 0) { this.selectionMode = false; }
  }

  private clearSelection(): void {
    this.selectedBookKeys = new Set<string>();
    this.selectionMode = false;
    this.rowMenuKey = '';
  }

  /**
   * 第十表 G-12：批量换源确认后清空选择。
   *
   * 上游 `BookshelfManageScreen.kt:806-816` 的 `onConfirm` 在派发 `BatchChangeBookSource`
   * 之后立刻 `clearSelection()`；本地换源面板是 Index 上的覆盖层，拿不到本页的选择态，
   * 所以由 Index 在确认那一刻把 `batchSourceConfirmSignal` 加一，这里监听到就清空。
   */
  private onBatchSourceConfirmSignal(): void {
    if (this.batchSourceConfirmSignal <= 0) { return; }
    this.clearSelection();
  }

  /**
   * H-2：选中书籍的实体列表。
   *
   * 上游（`BookshelfManageScreenViewModel.kt:382-405 resolveSelectedBooks`）从数据库按
   * `getBooksByUrls` 回查实体，并把查不到 url 从选中集合里剔除——因为书可能在本页之外
   * 被删（详情页删除、换源回滚），分组不影响存在性，所以跨分组选中不会被清掉。
   *
   * 本地 `this.books` 是 Index 传入的全量书架，用它回查即可覆盖跨分组；
   * 但仅靠内存列表在「页面停留期间别处删了书」时会留脏，所以这里优先用
   * `uiState.selectedBooks`（由 `resolveSelectedBooks()` 查库填充）。
   */
  private selectedBooks(): Book[] {
    const urls = this.selectedUrlsFromKeys();
    if (urls.length === 0) { return []; }
    if (this.uiState.selectedBooks.length > 0) { return this.uiState.selectedBooks; }
    const urlSet = new Set<string>(urls);
    return this.books.filter((book: Book) => urlSet.has(this.bookKey(book)));
  }

  /**
   * H-2：按 url 查库回填 `uiState.selectedBooks`，并剔除已不存在的书。
   * 对齐上游 `resolveSelectedBooks()`（:387-405）：先查实体，再把
   * `selectedBookUrls` 与「查得到的 url 集合」求交，避免选中集合留下已删的书。
   */
  private async resolveSelectedBooks(): Promise<void> {
    const urls = this.selectedUrlsFromKeys();
    if (urls.length === 0) {
      this.uiState = this.nextState({ selectedBooks: [] });
      return;
    }
    const context = this.getUIContext().getHostContext();
    if (context === undefined) { return; }
    try {
      const books = await BookRepository.getBooksByUrls(context, urls);
      const existing = new Set<string>(books.map((book: Book) => this.bookKey(book)));
      const nextKeys = new Set<string>();
      this.selectedBookKeys.forEach((key: string) => {
        const hit = books.find((book: Book) => this.rowKey(book) === key);
        if (hit !== undefined) { nextKeys.add(key); }
      });
      this.selectedBookKeys = nextKeys;
      this.uiState = this.nextState({
        selectedBookUrls: Array.from(existing),
        selectedBooks: books
      });
      if (nextKeys.size === 0) { this.selectionMode = false; }
    } catch (error) {
      console.error(`回查选中书籍失败：${error instanceof Error ? error.message : String(error)}`);
    }
  }

  /** 跨分组多选时把不在当前列表的本数写出来（上游 selectionTitle 同义）。 */
  private selectionTitle(): string {
    const total = this.selectedBookKeys.size;
    const inView = this.filteredBooks().filter((book: Book) => this.isSelected(book)).length;
    const outOfView = total - inView;
    if (outOfView > 0) {
      return `已选 ${total} 本（${outOfView} 本不在当前列表）`;
    }
    return `已选 ${total}/${this.filteredBooks().length}`;
  }

  private groupLabelOf(book: Book): string {
    const names = book.groupNames ?? [];
    return names.length > 0 ? names.join('、') : '无分组';
  }

  private sourceFileLabelOf(book: Book): string {
    const path = book.androidOriginalPath ?? '';
    if (path.length === 0) { return '本地文件'; }
    const parts = path.split('/');
    return parts[parts.length - 1];
  }

  /**
   * 导出设置落盘。上游每个开关都立即写 preferences（`BookExportSettingsRepository.kt:26-53`），
   * 这里同样每次改动即存，不攒到导出时再写：用户改完设置直接退出页面也不丢。
   */
  private async persistExportSettings(next: BookExportSettings): Promise<void> {
    this.exportSettings = next;
    const context = this.getUIContext().getHostContext();
    if (context === undefined) { return; }
    try {
      await BookExportSettingsStore.save(context, next);
    } catch (error) {
      console.error(`[BookshelfManage] 导出设置保存失败: ${error}`);
    }
  }

  /** 改单个字段：先 clone 再改再存，避免直接改 @State 持有的对象。 */
  private async patchExportSettings(patch: (draft: BookExportSettings) => void): Promise<void> {
    const draft = BookExportSettingsStore.clone(this.exportSettings);
    patch(draft);
    await this.persistExportSettings(draft);
  }

  /**
   * 打开「自定义字符集」/「导出文件名」输入对话框。
   * 上游是两个独立的 AppAlertDialog（`BookshelfManageScreen.kt:1195-1215` 与 `:1217-1240`），
   * 本地用一个对话框 + 一个开关区分，形态照 `pages/AppBackupSettingsPage.ets:404-433`：
   * 用 openCustomDialog 而非 showAlertDialog —— 后者带不了输入框。
   */
  private openExportInputDialog(charset: boolean): void {
    this.showCharsetDialog = charset;
    this.showFileNameDialog = !charset;
    if (this.exportDialogId >= 0) { return; }
    this.exportDialogBuilder = (): void => { this.ExportInputDialogContent(); };
    this.getUIContext().getPromptAction().openCustomDialog({
      builder: this.exportDialogBuilder,
      autoCancel: false,
      alignment: DialogAlignment.Center,
      onWillDismiss: () => {
        this.exportDialogId = -1;
        this.showCharsetDialog = false;
        this.showFileNameDialog = false;
      }
    }).then((id: number) => {
      this.exportDialogId = id;
    }).catch((error: Error) => {
      console.error(`[BookshelfManage] 打开导出输入对话框失败: ${error}`);
    });
  }

  private closeExportInputDialog(): void {
    this.showCharsetDialog = false;
    this.showFileNameDialog = false;
    if (this.exportDialogId >= 0) {
      this.getUIContext().getPromptAction().closeCustomDialog(this.exportDialogId);
      this.exportDialogId = -1;
    }
  }

  /** 确认输入：字符集空串按上游回落 UTF-8（`BookshelfManageScreen.kt:1236`）。 */
  private async confirmExportInput(): Promise<void> {
    if (this.showCharsetDialog) {
      const value = this.exportCharsetDraft.trim();
      await this.patchExportSettings((draft: BookExportSettings) => {
        draft.exportCharset = value.length > 0 ? value : 'UTF-8';
      });
    } else {
      const value = this.exportFileNameDraft.trim();
      await this.patchExportSettings((draft: BookExportSettings) => {
        draft.bookExportFileName = value;
      });
    }
    this.closeExportInputDialog();
  }

  private async loadExportSettings(): Promise<void> {
    const context = this.getUIContext().getHostContext();
    if (context === undefined) { return; }
    try {
      this.exportSettings = await BookExportSettingsStore.load(context);
      // 目录读写与可写探测都在 BookExporter，详情页与分段导出读的是同一份。
      this.exportFolderPath = await BookExporter.loadFolder(context);
      this.exportFolderWritable = this.exportFolderPath.length === 0
        ? true : BookExporter.canWriteInto(this.exportFolderPath);
    } catch (error) {
      console.error(`[BookshelfManage] 导出设置读取失败: ${error}`);
    }
  }

  /**
   * 「导出文件夹」行：对齐上游 `selectExportFolder()`（`BookshelfManageScreen.kt:281-311`）的
   * `OpenDocumentTree` —— 选一个目录并记住，之后导出直接写进去，不再弹保存框。
   * 可写探测在 `BookExporter.canWriteInto`（与 `pages/Index.ets:6867-6884` 同法）。
   */
  /**
   * D-9：上游选导出目录前先弹 `FilePickerSheet(show, title = export_folder,
   *   onSelectSysDir = { exportDir.launch(null) })`（BookshelfManageScreen.kt:903-911），
   * 里面只有一张「系统文件夹选择」卡片（FilePickerSheet.kt:38-44，
   * `OptionCard(icon = FolderOpen, text = sys_folder_picker)`，卡片 100dp 高、
   * 圆角 12dp、底色 onSheetContent、图标 32dp primary）。
   * 本地原来点「导出文件夹」直接起 DocumentViewPicker，缺这一层选择；这里补上。
   */
  @Builder
  private ExportFolderPickerContent() {
    Column() {
      Text('导出文件夹').fontSize(TITLE_LARGE).fontWeight(FontWeight.Medium).fontColor(this.themeColorTextPrimary)
        .width('100%').margin({ bottom: 16 })
      Row() {
        Column() {
          AppGlyph({ name: 'folder', glyphSize: 32, tint: this.themeColorAccent })
          Text('系统文件夹选择').fontSize(LABEL_MEDIUM).fontColor(this.themeColorTextPrimary).margin({ top: 8 }).maxLines(1)
        }.width('100%').height(100).justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
        .borderRadius(12).backgroundColor(this.themeColorSurfaceSecondary)
        .onClick(() => {
          this.showExportFolderPicker = false;
          void this.chooseExportFolder();
        })
        .accessibilityText('系统文件夹选择')
      }.width('100%')
      Text('取消').fontSize(LABEL_LARGE).fontColor('#C5C7D0').textAlign(TextAlign.Center)
        .width('100%').padding({ top: 12, bottom: 12 }).backgroundColor('#2A2B33').borderRadius(14)
        .margin({ top: 16 })
        .onClick(() => this.showExportFolderPicker = false)
    }.width('100%')
  }

  private async chooseExportFolder(): Promise<void> {
    const context = this.getUIContext().getHostContext();
    if (context === undefined) { return; }
    try {
      const options = new picker.DocumentSelectOptions();
      options.selectMode = picker.DocumentSelectMode.FOLDER;
      options.maxSelectNumber = 1;
      const uris = await new picker.DocumentViewPicker(context).select(options);
      const uri = uris[0];
      if (uri === undefined) {
        // 用户没选出目录（取消，或该设备的目录选择器选不出东西）：
        // 上游 `BookshelfManageScreen.kt:279-312` 在 `!isReadyPath` 时直接 return，什么也不做；
        // 但本地 `BookExporter.ets:70` 本来就有「目录为空 → 每本弹一次系统保存框」的兜底路径，
        // 把这条路彻底掐掉会让导出在这类设备上完全不可用（实测本机模拟器 FOLDER 模式
        // 进入目录后底部「完成」按钮消失，无法选中任何目录）。所以这里退到兜底：
        // 目录留空，那批书照常导出，只是每本弹一次保存框。
        const waiting = this.pendingExportBooks;
        this.pendingExportBooks = [];
        if (waiting.length === 0) { return; }
        this.showExportSheet = false;
        await this.exportBooksInOrder(context, waiting, false);
        return;
      }
      try {
        await fileShare.persistPermission([{
          uri: uri,
          operationMode: fileShare.OperationMode.READ_MODE | fileShare.OperationMode.WRITE_MODE
        }]);
      } catch (error) {
        // 授权失败本次仍可用，只是重启后失效，不阻断用户。
        console.error(`[BookshelfManage] 记住导出目录授权失败: ${error}`);
      }
      const writable = BookExporter.canWriteInto(uri);
      this.exportFolderPath = writable ? uri : '';
      this.exportFolderWritable = writable;
      await BookExporter.saveFolder(context, this.exportFolderPath);
      if (!writable) {
        this.onUnavailableAction('这个目录应用写不进去，已忽略');
      }
      // 第十表 F-4：对齐上游目录选择回调（`BookshelfManageScreen.kt:279-312`）——
      // 选完目录不是结束，而是拿着 `pendingExportBooks` 继续：
      // 单本 + 开了自定义 EPUB 导出 → 弹自定义导出框；否则逐本导出。
      const pending = this.pendingExportBooks;
      this.pendingExportBooks = [];
      if (pending.length === 0) { return; }
      // 不可写时上面已把 exportFolderPath 清空、并提示过用户；这里不 return，
      // 让它落到「目录为空 → 每本弹一次系统保存框」的兜底路径，导出照样能完成。
      if (writable && pending.length === 1 && this.isCustomEpubExportEnabled()) {
        const only = pending[0];
        if (only !== undefined) {
          this.openCustomExportDialog(only);
          return;
        }
      }
      this.showExportSheet = false;
      await this.exportBooksInOrder(context, pending, false);
    } catch (error) {
      this.onUnavailableAction(error instanceof Error ? `选择导出文件夹失败：${error.message}` : '选择导出文件夹失败');
    }
  }

  /**
   * 导出入口（第十表 F-4）：对齐上游 `startExportForBooks(books)`（`BookshelfManageScreen.kt:331-350`）。
   *
   * 上游三段判定，本地逐段照搬：
   * 1. 目录为空或不可写 → 先记下这批书、弹目录选择（选完回调里继续导出，见 `chooseExportFolder`）；
   * 2. 单本 + 开了自定义 EPUB 导出 → 弹自定义导出框（直接用已记住的目录）；
   * 3. 其余 → 逐本导出。
   */
  private async startExportForBooks(books: Book[]): Promise<void> {
    if (books.length === 0) { return; }
    const context = this.getUIContext().getHostContext();
    if (context === undefined) { this.onUnavailableAction('无法访问本地文件'); return; }
    const hasFolder = this.exportFolderPath.length > 0 && this.exportFolderWritable;
    if (!hasFolder) {
      this.pendingExportBooks = books;
      this.showExportFolderPicker = true;
      return;
    }
    if (books.length === 1 && this.isCustomEpubExportEnabled()) {
      const only = books[0];
      if (only !== undefined) {
        this.openCustomExportDialog(only);
        return;
      }
    }
    this.showExportSheet = false;
    await this.exportBooksInOrder(context, books, false);
  }

  /**
   * 把当前设置与导出目录打包成 `ExportTarget` 交给 `BookExporter`。
   *
   * 导出执行层统一放在 `data/BookExporter.ets`：上游的 `ExportBookService` 被三处调用
   * （书架管理页导出 / 详情页导出 EPUB / 分段导出），三处读同一份设置与同一个目录。
   * 页面只负责设置读写、目录选择与输入对话框，拼正文与落盘都在执行层。
   */
  private exportTarget(): ExportTarget {
    return {
      settings: this.exportSettings,
      folderPath: this.exportFolderPath,
      folderWritable: this.exportFolderWritable
    };
  }

  /** 导出一本书（TXT 或 EPUB），落盘后按 `exportToWebDav` 上传。实现见 `BookExporter.exportOne`。 */
  private async exportOneBook(context: Context, book: Book): Promise<string> {
    return await BookExporter.exportOne(context, book, this.exportTarget());
  }

  /** Map 原地 set 不触发 @State 刷新，一律整体替换。 */
  private putExportMsg(key: string, text: string): void {
    const next = new Map<string, string>(this.exportMsgByKey);
    next.set(key, text);
    this.exportMsgByKey = next;
  }

  private exportMsgOf(book: Book): string {
    return this.exportMsgByKey.get(this.rowKey(book)) ?? '';
  }

  /** 没读到章节数时给一个能覆盖全书的默认范围（上游自定义导出默认把整本当一段）。 */
  private chapterCountHint(book: Book): number {
    const total = Number(book.chapterCount ?? '0');
    return Number.isFinite(total) && total > 0 ? Math.floor(total) : 1;
  }

  private openExportSheet(books: Book[]): void {
    if (books.length === 0) { this.onUnavailableAction('当前没有可导出的书籍'); return; }
    this.exportBooks = books;
    this.exportMsgByKey = new Map<string, string>();
    this.showExportSettings = false;
    this.showExportSheet = true;
  }

  /**
   * 「导出」按钮（第十表 F-4）。
   *
   * 上游没有这个按钮：它的等价动作是 `startExportForBooks(exportSheetBooks)`
   * （`BookshelfManageScreen.kt:331-350`），由导出面板里的确认触发。
   * 本地保留按钮形态，但判定链整段交给 `startExportForBooks`，
   * 保证「没目录先选目录、选完继续导出」这条路径与上游一致。
   */
  private async runExport(): Promise<void> {
    await this.startExportForBooks(this.exportBooks);
  }

  /** 上游 `isCustomEpubExportEnabled`：`enableCustomExport && exportType == 1`。 */
  private isCustomEpubExportEnabled(): boolean {
    return this.exportSettings.enableCustomExport && this.exportSettings.exportType === 1;
  }

  /**
   * 逐本导出，把每本的提示写回行内文案。`scopeSpec` 非空时走分段导出。
   *
   * 第十表 F-12：上游把导出交给 `ExportBookService`（前台 Service，`BookshelfManageScreen.kt:1332-1343`
   * `startService<ExportBookService> { action = start; putExtra("bookUrl" / "exportType" / "exportPath") }`），
   * 用户切走应用也继续导。本地用 `ExportBackgroundTask` 申请 DATA_TRANSFER 长时任务承载同一语义：
   * 每本开始前刷新一次通知（既给用户看进度，也满足系统「持续更新否则取消」的要求），
   * 全部结束才释放。申请失败时 `ExportBackgroundTask` 内部降级为前台导出，不影响落盘。
   */
  private async exportBooksInOrder(context: Context, books: Book[], segmented: boolean,
    scopeSpec: string = '', chaptersPerVolume: number = 1): Promise<void> {
    const target = this.exportTarget();
    const total = books.length;
    await ExportBackgroundTask.begin(context);
    try {
      for (let i = 0; i < total; i++) {
        const book = books[i];
        if (book === undefined) { continue; }
        const key = this.rowKey(book);
        this.putExportMsg(key, `第 ${i + 1} / 共 ${total} 本，正在导出…`);
        await ExportBackgroundTask.updateProgress(book.title, i + 1, total);
        let message = '已导出';
        try {
          if (segmented) {
            const written = await BookExporter.exportSegmented(context, book, scopeSpec, chaptersPerVolume, target);
            message = written === 0 ? '已取消' : `已导出 ${written} 卷`;
          } else {
            message = await BookExporter.exportOne(context, book, target);
          }
        } catch (error) {
          message = error instanceof Error ? `导出失败：${error.message}` : '导出失败';
        }
        this.putExportMsg(key, message);
      }
    } finally {
      // 无论成功、失败还是中途抛错，都要释放长时任务，否则通知条会一直挂着。
      await ExportBackgroundTask.end();
    }
  }

  /**
   * 打开自定义导出对话框（上游 `BookshelfManageScreen.kt:1248-1371` 的 AppAlertDialog）。
   * 上游用 AppAlertDialog 内嵌两个 RadioButton + 三个 AppTextField，本地同样用
   * openCustomDialog 承载（showAlertDialog 带不了输入框）。
   */
  private openCustomExportDialog(book: Book): void {
    this.showExportSheet = false;
    this.segmentedExportBook = book;
    this.customExportAllChapter = true;
    this.customScopeInput = `1-${Math.max(1, this.chapterCountHint(book))}`;
    this.customVolumeSizeInput = '1';
    this.customFileNameInput = this.exportSettings.episodeExportFileName;
    this.customScopeError = '';
    this.showCustomExportDialog = true;
    if (this.customExportDialogId >= 0) { return; }
    this.customExportDialogBuilder = (): void => { this.CustomExportDialogContent(); };
    this.getUIContext().getPromptAction().openCustomDialog({
      builder: this.customExportDialogBuilder,
      autoCancel: false,
      alignment: DialogAlignment.Center,
      onWillDismiss: () => {
        this.customExportDialogId = -1;
        this.showCustomExportDialog = false;
        this.customScopeError = '';
      }
    }).then((id: number) => {
      this.customExportDialogId = id;
    }).catch((error: Error) => {
      console.error(`[BookshelfManage] 打开自定义导出对话框失败: ${error}`);
    });
  }

  private closeCustomExportDialog(): void {
    this.showCustomExportDialog = false;
    this.customScopeError = '';
    if (this.customExportDialogId >= 0) {
      this.getUIContext().getPromptAction().closeCustomDialog(this.customExportDialogId);
      this.customExportDialogId = -1;
    }
  }

  /**
   * 上游 `verificationField`（`utils/CustomExportUtils.kt:30-32`）：整串必须匹配
   * `\d+(-\d+)?(,\d+(-\d+)?)*`，与 `EpubExporter.parseScope` 的宽松解析不是一回事 ——
   * 上游是「先整串校验，不通过就不导出」，本地同口径。
   */
  private isValidScopeSpec(text: string): boolean {
    return new RegExp('^\\d+(-\\d+)?(,\\d+(-\\d+)?)*$').test(text);
  }

  /** 自定义导出的「分析结果」预览（上游 `"$resultAnalyzedText: ${getExportFileName("epub", 1, 模板)}"`）。 */
  private customExportPreviewName(): string {
    const book = this.segmentedExportBook;
    if (book === undefined) { return ''; }
    return episodeExportFileNameOf(book, 'epub', 1, this.customFileNameInput.trim());
  }

  /** 确认自定义导出：全本走普通 EPUB，否则按范围与每卷章数走分段。 */
  private async confirmCustomExport(): Promise<void> {
    const book = this.segmentedExportBook;
    if (book === undefined) { this.closeCustomExportDialog(); return; }
    const context = this.getUIContext().getHostContext();
    if (context === undefined) { this.onUnavailableAction('无法访问本地文件'); return; }
    if (this.customExportAllChapter) {
      this.closeCustomExportDialog();
      await this.exportBooksInOrder(context, [book], false);
      return;
    }
    const scopeSpec = this.customScopeInput.trim();
    if (!this.isValidScopeSpec(scopeSpec)) {
      this.customScopeError = '请输入正确的范围';
      return;
    }
    this.customScopeError = '';
    const fileName = this.customFileNameInput.trim();
    if (fileName.length > 0) {
      await this.patchExportSettings((draft: BookExportSettings) => {
        draft.episodeExportFileName = fileName;
      });
    }
    const size = Math.floor(Number(this.customVolumeSizeInput));
    this.closeCustomExportDialog();
    await this.exportBooksInOrder(context, [book], true, scopeSpec,
      Number.isFinite(size) && size >= 1 ? size : 1);
  }

  /**
   * H-3：删除框初值取全局 `deleteBookOriginal`（上游 `BookshelfManageScreen.kt:201`
   * `var deleteOriginalBookFile by remember { mutableStateOf(state.deleteBookOriginal) }`，
   * 而 state 初值来自 `LocalConfig.deleteBookOriginal`，`BookshelfManageScreenViewModel.kt:123`）。
   * 本地落在 `OtherSettingsRepository`（键名照抄上游 `deleteBookOriginal`）。
   */
  private requestDelete(keys: string[]): void {
    if (keys.length === 0) { return; }
    this.pendingDeleteKeys = keys;
    this.deleteOriginalFile = OtherSettingsRepository.get().deleteBookOriginal;
    this.uiState = this.nextState({ deleteBookOriginal: this.deleteOriginalFile });
    this.showDeleteConfirm = true;
  }

  /** 勾选框只在待删集合里有本地书时出现；本地书 isLocal 恒真。 */
  private hasLocalBookIn(keys: string[]): boolean {
    return this.books.some((book: Book) => keys.includes(this.rowKey(book)) && book.isLocal);
  }

  private async confirmDelete(): Promise<void> {
    const context = this.getUIContext().getHostContext();
    if (context === undefined) { this.onUnavailableAction('无法访问本地书架'); return; }
    const targets = this.books.filter((book: Book) => this.pendingDeleteKeys.includes(this.rowKey(book)));
    this.showDeleteConfirm = false;
    if (targets.length === 0) { this.clearSelection(); return; }
    try {
      // 复用批5 的 deleteBooks：逐本 deleteBook（清章节表与书目）+ 可选清应用内导入副本。
      // 它是窄 DELETE，不会把刚删的书又 upsert 回去，因此这里不需要再 saveImportedBooks。
      await BookRepository.deleteBooks(context, targets, this.deleteOriginalFile);
      // H-3：用户这次的选择写回全局，下次进删除框按它给初值
      // （上游 `BookshelfManageScreenViewModel.kt:729 LocalConfig.deleteBookOriginal = deleteOriginal`）。
      const settings = OtherSettingsRepository.get();
      settings.deleteBookOriginal = this.deleteOriginalFile;
      await OtherSettingsRepository.save(context, settings);
      await this.onLibraryChanged();
      this.clearSelection();
      this.onUnavailableAction(`已删除 ${targets.length} 本书`);
    } catch (error) {
      this.onUnavailableAction('删除失败，请重试');
    }
    this.pendingDeleteKeys = [];
  }

  /**
   * 打开选组面板并算预选。
   *
   * 第十表 H-4：上游 `BookshelfManageScreen.kt:365-370 resolveSelectionGroupMask()` 是
   * 「所有选中书的 group 掩码全同 → 预选该掩码，否则 0L（不预选）」；面板本身
   * `BookInfoSheets.kt:108-190 GroupSelectSheet` 用位掩码做**多选**，每点一行
   * `selectedGroupId ± group.groupId`。本地没有掩码列，等价物是 groupNames 数组：
   * 全同则整份预选，不同则空。
   */
  private openGroupSelect(keys: string[]): void {
    if (keys.length === 0) { return; }
    this.groupSelectBookKeys = keys;
    const selected = this.books.filter((book: Book) => keys.includes(this.rowKey(book)));
    let preset: string[] = [];
    if (selected.length > 0) {
      const first = [...(selected[0].groupNames ?? [])].sort();
      const same = selected.every((book: Book) => {
        const names = [...(book.groupNames ?? [])].sort();
        return names.length === first.length && names.every((name: string, index: number) => name === first[index]);
      });
      preset = same ? first : [];
    }
    this.selectedGroupNames = preset;
    this.showGroupSelect = true;
  }

  /** 多选：点一行即在该组名上取反（上游 `selectedGroupId ± group.groupId`）。 */
  private toggleGroupName(groupName: string): void {
    const current = this.selectedGroupNames.slice(0);
    const index = current.indexOf(groupName);
    if (index >= 0) {
      current.splice(index, 1);
    } else {
      current.push(groupName);
    }
    this.selectedGroupNames = current;
  }

  private isGroupNameSelected(groupName: string): boolean {
    return this.selectedGroupNames.includes(groupName);
  }

  /**
   * 落库：整份替换为选中的组名集合。
   *
   * 上游 `BookshelfManageScreenViewModel.kt:716-724 moveBooksToGroup` 直接把掩码
   * `replaceGroup(bookUrls, safeGroupId)` 写进去，多选组合的掩码是合法输入；
   * 本地 `BookRepository.setBooksGroups` 同款整份替换（内部 maskFromNames）。
   */
  /** 打开分组编辑面板；`undefined` 表示新建（上游 GroupSelectSheet 的 startAction）。 */
  private openGroupEditor(group: BookGroup | undefined): void {
    this.groupEditing = group;
    this.showGroupEditor = true;
  }

  /**
   * 分组保存：`groupId > 0` 更新、`-1` 新建。
   * 改名时同步「当前分组筛选」与「选组面板里已选中的名字」，否则它们会指向旧名。
   */
  private async saveGroupDraft(groupId: number, draft: BookGroupDraft): Promise<void> {
    if (groupId > 0) {
      const previous = this.groups.find((group: BookGroup) => group.groupId === groupId);
      await this.onUpdateGroup(groupId, draft);
      if (previous !== undefined) {
        if (this.currentGroupName === previous.groupName) { this.currentGroupName = draft.groupName; }
        const index = this.selectedGroupNames.indexOf(previous.groupName);
        if (index >= 0) {
          const next = this.selectedGroupNames.slice(0);
          next[index] = draft.groupName;
          this.selectedGroupNames = next;
        }
      }
    } else {
      await this.onAddGroupDraft(draft);
    }
  }

  private async applyGroupSelection(): Promise<void> {
    const context = this.getUIContext().getHostContext();
    if (context === undefined) { this.onUnavailableAction('无法访问本地书架'); return; }
    this.showGroupSelect = false;
    const keys = this.groupSelectBookKeys;
    const names = this.selectedGroupNames.slice(0);
    const targets = this.books.filter((book: Book) => keys.includes(this.rowKey(book)));
    if (targets.length === 0) { return; }
    try {
      await BookRepository.setBooksGroups(context, targets.map((book: Book) => this.bookKey(book)), names);
      await this.onLibraryChanged();
      this.clearSelection();
      this.onUnavailableAction(names.length === 0
        ? `已移动 ${targets.length} 本到未分组`
        : `已移动 ${targets.length} 本到${names.join('、')}`);
    } catch (error) {
      this.onUnavailableAction('修改分组失败');
    }
  }

  // ---------------------------------------------------------------- 菜单

  private groupFilterItems(): UiMenuItem[] {
    // 选中项改为右侧勾，不再在文案里拼「✓ 」。
    return this.groupOptions().map((name: string): UiMenuItem => {
      return { key: name, title: name, selected: name === this.effectiveGroup() };
    });
  }

  @Builder
  private GroupFilterMenu() {
    UiMenuPanel({
      items: this.groupFilterItems(),
      panelWidth: MANAGE_MENU_WIDTH,
      onSelect: (key: string) => {
        this.groupFilterVisible = false;
        this.currentGroupName = key;
      }
    })
  }

  /**
   * 顶栏「更多」。批2 补两条：下载全部（:455，上游 downloadAll）与日志（:457，上游 AppLogSheet），
   * 都落在本页，不再走占位 toast。
   * B-5：顺序按上游 `dropDownMenuContent`（:494-518）——下载全部 / 导出全部 / PillDivider / 日志。
   */
  private moreMenuItems(): UiMenuItem[] {
    return [
      { key: 'download_all', title: '下载全部' },
      { key: 'export_all', title: '导出全部' },
      { key: 'divider', title: '', divider: true },
      { key: 'log', title: '日志' }
    ];
  }

  @Builder
  private MoreMenu() {
    UiMenuPanel({
      items: this.moreMenuItems(),
      panelWidth: MANAGE_MENU_WIDTH,
      onSelect: (key: string) => {
        this.moreMenuVisible = false;
        if (key === 'download_all') {
          // D-5：上游先弹「是否确认开始缓存？」二次确认（:995-1012），
          // 确认后才 StartDownloadForVisibleBooks(state.books, downloadAllChapters=true)。
          this.showDownloadAllConfirm = true;
        } else if (key === 'log') {
          this.showLogSheet = true;
        } else if (key === 'export_all') {
          this.openExportSheet(this.filteredBooks());
        }
      }
    })
  }

  /**
   * D-3：选择态操作项。上游是 `fabItems` 8 项（`BookshelfManageScreen.kt:371-441`）：
   * 全选 / 反选 / 缓存选中 / 批量换源 / 移入分组 / 导出选中 / 清除缓存 / 删除。
   * 本地原为 6 项，缺「导出选中」与「删除」。
   */
  private selectionMenuItems(): UiMenuItem[] {
    return [
      { key: 'select_all', title: '全选' },
      { key: 'invert', title: '反选' },
      { key: 'download_selected', title: '缓存选中' },
      { key: 'batch_change_source', title: '批量换源' },
      { key: 'move_group', title: '移入分组' },
      { key: 'export_selected', title: '导出选中' },
      { key: 'clear_cache', title: '清除缓存' },
      { key: 'delete', title: '删除' }
    ];
  }

  /**
   * B-6 / B-7：选择态 FAB 菜单。上游 `fabItems` 8 项，每项都带
   * `selectedBookUrls.isNotEmpty()` 前置判空（BookshelfManageScreen.kt:371-441）。
   * 本地选择态必然非空（selectionMode 由选中集驱动），所以这里不再逐项判空。
   */
  @Builder
  private FabMenu() {
    UiMenuPanel({
      items: this.selectionMenuItems(),
      panelWidth: MANAGE_MENU_WIDTH,
      onSelect: (key: string) => {
        this.fabMenuExpanded = false;
        this.handleSelectionAction(key);
      }
    })
  }

  @Builder
  private SelectionMenu() {
    UiMenuPanel({
      items: this.selectionMenuItems(),
      panelWidth: MANAGE_MENU_WIDTH,
      onSelect: (key: string) => {
        this.selectionMenuVisible = false;
        this.handleSelectionAction(key);
      }
    })
  }

  /** 选择态 8 项动作的统一分发（FAB 与旧「操作」菜单共用）。 */
  private handleSelectionAction(key: string): void {
    if (key === 'select_all') {
      this.dispatch(manageIntent(ManageIntentType.SelectVisibleBooks,
        { visibleBookUrls: this.filteredBooks().map((book: Book) => this.bookKey(book)) }));
    } else if (key === 'invert') {
      this.dispatch(manageIntent(ManageIntentType.InvertVisibleBooks,
        { visibleBookUrls: this.filteredBooks().map((book: Book) => this.bookKey(book)) }));
    } else if (key === 'move_group') {
      const keys: string[] = this.selectedBooks().map((book: Book) => this.rowKey(book));
      this.openGroupSelect(keys);
    } else if (key === 'batch_change_source') {
      this.onBatchChangeSource(this.selectedBooks());
    } else if (key === 'download_selected') {
      // D-4：上游先弹「是否确认开始缓存？」二次确认（:913-930）。
      this.showBatchDownloadConfirm = true;
    } else if (key === 'export_selected') {
      this.openExportSheet(this.selectedBooks());
    } else if (key === 'clear_cache') {
      this.onClearSelectedCache(this.selectedBooks());
      this.bumpCacheVersion();
    } else if (key === 'delete') {
      this.requestDelete(this.selectedBooks().map((book: Book) => this.rowKey(book)));
    }
  }

  // ---------------------------------------------------------------- 书籍行

  @Builder
  private BookRow(book: Book) {
    Column() {
      Row() {
        Column() {
          Text(book.title).fontSize(TITLE_SMALL_EMPHASIZED).fontColor(this.themeColorTextPrimary).maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .onClick(() => this.dispatch(manageIntent(ManageIntentType.OpenBookInfoPreview, { book: book, inBookshelf: true })))
          Text(this.realAuthorOf(book)).fontSize(BODY_SMALL)
            .fontColor(this.themeColorTextSecondary).margin({ top: 2 }).maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Text(`${this.groupNameResolver(book)} | ${this.sourceFileLabelOf(book)}`).fontSize(LABEL_SMALL)
            .fontColor(this.themeColorAccent).margin({ top: 2 }).maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          if (this.exportMsgOf(book).length > 0) {
            Text(this.exportMsgOf(book)).fontSize(LABEL_SMALL).fontColor(this.themeColorTextTertiary)
              .margin({ top: 2 }).maxLines(1)
          }
          if (this.downloadFailureTextOf(book).length > 0) {
            Text(this.downloadFailureTextOf(book)).fontSize(LABEL_SMALL).fontColor('#FF6B6B')
              .margin({ top: 2 }).maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
        }.layoutWeight(1).alignItems(HorizontalAlign.Start)
        if (BookRepository.isOnlineBook(book)) {
          Text(`${this.cacheCountOf(book)}/${this.totalChapterNumOf(book)}`).fontSize(LABEL_SMALL)
            .fontColor(this.themeColorTextSecondary)
            .padding({ left: 8, right: 8, top: 3, bottom: 3 }).borderRadius(8)
            .backgroundColor(this.themeColorSurfaceElevated)
            .accessibilityText(`${book.title} 已缓存 ${this.cacheCountOf(book)} 章，共 ${this.totalChapterNumOf(book)} 章`)
        } else {
          Text('本地书').fontSize(LABEL_SMALL).fontColor('#B9C6FF')
            .padding({ left: 8, right: 8, top: 3, bottom: 3 }).borderRadius(8)
            .backgroundColor(this.themeColorSurfaceElevated)
        }
        if (this.selectionMode) {
          Stack({ alignContent: Alignment.Center }) {
            Column().width(18).height(18).borderRadius(9)
              .backgroundColor(this.isSelected(book) ? '#C4D1FF' : '#00000000')
              .border({ width: 1.5, color: this.isSelected(book) ? '#C4D1FF' : '#7A7D88' })
            if (this.isSelected(book)) {
              AppGlyph({ name: 'profileCheck', glyphSize: 12, tint: '#1A1B21' })
            }
          }.width(26).height(26).margin({ left: 8 })
        }
      }.width('100%')
      // C-8：按钮组顺序对齐上游 —— 下载/停止 → 导出 → 分组 → 更多，之间加竖分隔线。
      Row() {
        if (BookRepository.isOnlineBook(book)) {
          this.RowActionButton(this.isDownloadBusy(book) ? '停止' : '下载',
            () => this.dispatch(manageIntent(ManageIntentType.ToggleBookDownload, { book: book })))
          Divider().vertical(true).height(16).color('#3A3D48').margin({ left: 4, right: 4 })
        }
        this.RowActionButton('导出', () => this.openExportSheet([book]))
        Divider().vertical(true).height(16).color('#3A3D48').margin({ left: 4, right: 4 })
        this.RowActionButton('分组', () => this.openGroupSelect([this.rowKey(book)]))
        Divider().vertical(true).height(16).color('#3A3D48').margin({ left: 4, right: 4 })
        this.RowActionButton('更多',
          () => this.rowMenuKey = this.rowMenuKey === this.rowKey(book) ? '' : this.rowKey(book))
      }.width('100%').margin({ top: 6 }).alignItems(VerticalAlign.Center)
      // C-9：上游「更多」菜单 3 项 —— 换源 / 删除书籍 / 删除缓存。
      if (this.rowMenuKey === this.rowKey(book)) {
        Row() {
          Text('换源').fontSize(BODY_SMALL).fontColor(this.themeColorAccent)
            .padding({ left: 12, right: 12, top: 6, bottom: 6 })
            .onClick(() => {
              this.rowMenuKey = '';
              // G-1：上游这一项是单本 ChangeSourceSheet（自动搜候选），不是批量向导。
              this.onOpenChangeSource(book);
            })
          Text('删除书籍').fontSize(BODY_SMALL).fontColor('#FF6B6B').padding({ left: 12, right: 12, top: 6, bottom: 6 })
            .onClick(() => {
              this.rowMenuKey = '';
              this.requestDelete([this.rowKey(book)]);
            })
          Text('删除缓存').fontSize(BODY_SMALL).fontColor(this.themeColorAccent)
            .padding({ left: 12, right: 12, top: 6, bottom: 6 })
            .onClick(() => {
              this.rowMenuKey = '';
              this.onClearSelectedCache([book]);
              this.bumpCacheVersion();
            })
        }.width('100%').justifyContent(FlexAlign.End)
      }
    }
    // C-2：上游卡片内边距 vertical 12dp / horizontal 4dp（:591-595）。
    .width('100%').padding({ left: 4, right: 4, top: 12, bottom: 12 })
    .borderRadius(MANAGE_CARD_RADIUS)
    // C-1 / C-10：上游 `GlassCard(containerColor = animatedContainerColor)`，其中
    // `animatedContainerColor = animateColorAsState(if(isSelected) secondaryContainer
    // else if(isMiuix) surfaceContainer else surfaceContainerLow, tween(200))`
    // （BookshelfManageScreen.kt:551-559）。ArkUI 无 miuix 引擎，取非 miuix 分支 surfaceContainerLow。
    .backgroundColor(this.isSelected(book) ? this.themeColorSecondaryContainer : this.themeColorSurfaceContainerLow)
    // C-12：上游 onClick 与 onLongClick 都是 toggleBookSelection（:587-588）。
    .gesture(GestureGroup(GestureMode.Exclusive,
      LongPressGesture({ duration: 500 }).onAction(() => {
        this.dispatch(manageIntent(ManageIntentType.ToggleBookSelection, { bookUrl: this.bookKey(book) }));
      }),
      TapGesture({ count: 1 }).onAction(() => {
        this.dispatch(manageIntent(ManageIntentType.ToggleBookSelection, { bookUrl: this.bookKey(book) }));
      })
    ))
    // C-10：选中色 200ms 过渡（上游 animateColorAsState + tween(200, FastOutSlowInEasing)）。
    .animation({ duration: 200, curve: Curve.FastOutSlowIn })
  }

  /** C-8：行内动作按钮（上游 SmallTonalButton weight(1f)，文字色 onSurfaceVariant）。 */
  @Builder
  private RowActionButton(label: string, onTap: () => void) {
    Text(label).fontSize(LABEL_SMALL).fontColor(this.themeColorAccent)
      .layoutWeight(1).height(30).textAlign(TextAlign.Center)
      .onClick(onTap)
  }

  // ---------------------------------------------------------------- 三个 sheet

  @Builder
  private DeleteConfirmContent() {
    Column() {
      Text('删除书籍').fontSize(TITLE_LARGE).fontWeight(FontWeight.Medium).fontColor('#ECEEF2')
        .width('100%').margin({ bottom: 8 })
      Text(`已选 ${this.pendingDeleteKeys.length} 本。删除后应用内副本会被清理，Android 兼容归档不会更改。`)
        .fontSize(TITLE_SMALL).lineHeight(TITLE_SMALL_LINE_HEIGHT).fontColor('#AEB0BA').width('100%')
      if (this.hasLocalBookIn(this.pendingDeleteKeys)) {
        Row() {
          Toggle({ type: ToggleType.Checkbox, isOn: this.deleteOriginalFile })
            .onChange((value: boolean) => this.deleteOriginalFile = value)
          Text('删除源文件（应用内导入副本）').fontSize(TITLE_SMALL).fontColor('#D0D2DB').margin({ left: 8 })
        }.width('100%').margin({ top: 12 })
      }
      Row() {
        Text('取消').fontSize(LABEL_LARGE).fontColor('#C5C7D0').textAlign(TextAlign.Center)
          .layoutWeight(1).padding({ top: 12, bottom: 12 }).backgroundColor('#2A2B33').borderRadius(14)
          .onClick(() => this.showDeleteConfirm = false)
        Text('删除').fontSize(LABEL_LARGE).fontColor('#101116').textAlign(TextAlign.Center)
          .layoutWeight(1).padding({ top: 12, bottom: 12 }).backgroundColor('#B9C6FF').borderRadius(14)
          .margin({ left: 10 }).onClick(async () => { await this.confirmDelete(); })
      }.width('100%').margin({ top: 20 })
    }.width('100%')
  }

  /**
   * 导出设置面板，11 项逐条对齐上游 `BookshelfManageScreen.kt:1020-1150` 的 LazyColumn：
   * 格式下拉 / 字符集下拉 / 自定义字符集 / 导出文件夹 / 导出文件名 / 替换净化 /
   * 自定义导出 / 导出包含章节名 / 导出到 WebDav / 导出插图文件 / 并行导出。
   */
  @Builder
  private ExportSettingsContent() {
    Column() {
      UiDropdown({
        title: '导出格式',
        option: EXPORT_TYPES[this.exportSettings.exportType] ?? 'txt',
        options: EXPORT_TYPES,
        onSelect: (value: string) => {
          const index = EXPORT_TYPES.indexOf(value);
          void this.patchExportSettings((draft: BookExportSettings) => {
            draft.exportType = index < 0 ? 0 : index;
          });
        }
      })
      UiDropdown({
        title: '导出字符集',
        option: this.exportSettings.exportCharset,
        options: COMMON_EXPORT_CHARSETS,
        onSelect: (value: string) => {
          void this.patchExportSettings((draft: BookExportSettings) => {
            draft.exportCharset = value;
          });
        }
      })
      Row() {
        Text('自定义字符集').fontSize(TITLE_SMALL_EMPHASIZED).fontColor(this.themeColorTextPrimary).layoutWeight(1)
        Text(this.exportSettings.exportCharset).fontSize(BODY_SMALL).fontColor(this.themeColorTextTertiary)
      }.width('100%').padding({ top: 10, bottom: 10 })
        .onClick(() => {
          this.exportCharsetDraft = this.exportSettings.exportCharset;
          this.openExportInputDialog(true);
        })
      Row() {
        Text('导出文件夹').fontSize(TITLE_SMALL_EMPHASIZED).fontColor(this.themeColorTextPrimary).layoutWeight(1)
        Text(this.exportFolderPath.length > 0 ? this.exportFolderPath : '未选择')
          .fontSize(BODY_SMALL).fontColor(this.themeColorTextTertiary)
          .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis }).layoutWeight(1)
          .textAlign(TextAlign.End)
      }.width('100%').padding({ top: 10, bottom: 10 })
        // D-9：先弹「导出文件夹」选择层（上游 FilePickerSheet），再起系统目录选择器。
        .onClick(() => { this.showExportFolderPicker = true; })
      Row() {
        Text('导出文件名').fontSize(TITLE_SMALL_EMPHASIZED).fontColor(this.themeColorTextPrimary).layoutWeight(1)
        Text(this.exportSettings.bookExportFileName.length > 0
          ? this.exportSettings.bookExportFileName : '默认')
          .fontSize(BODY_SMALL).fontColor(this.themeColorTextTertiary)
          .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis }).layoutWeight(1)
          .textAlign(TextAlign.End)
      }.width('100%').padding({ top: 10, bottom: 10 })
        .onClick(() => {
          this.exportFileNameDraft = this.exportSettings.bookExportFileName;
          this.openExportInputDialog(false);
        })
      Row() {
        Text('替换净化').fontSize(TITLE_SMALL_EMPHASIZED).fontColor(this.themeColorTextPrimary).layoutWeight(1)
        UiSwitchControl({
          checked: this.exportSettings.exportUseReplace,
          interactive: false,
          onChange: (value: boolean) => {
            void this.patchExportSettings((draft: BookExportSettings) => {
              draft.exportUseReplace = value;
            });
          }
        })
      }.width('100%').padding({ top: 10, bottom: 10 })
        .onClick(() => {
          void this.patchExportSettings((draft: BookExportSettings) => {
            draft.exportUseReplace = !draft.exportUseReplace;
          });
        })
      Row() {
        Text('自定义导出').fontSize(TITLE_SMALL_EMPHASIZED).fontColor(this.themeColorTextPrimary).layoutWeight(1)
        UiSwitchControl({
          checked: this.exportSettings.enableCustomExport,
          interactive: false,
          onChange: (value: boolean) => {
            void this.patchExportSettings((draft: BookExportSettings) => {
              draft.enableCustomExport = value;
            });
          }
        })
      }.width('100%').padding({ top: 10, bottom: 10 })
        .onClick(() => {
          void this.patchExportSettings((draft: BookExportSettings) => {
            draft.enableCustomExport = !draft.enableCustomExport;
          });
        })
      Row() {
        Text('导出包含章节名').fontSize(TITLE_SMALL_EMPHASIZED).fontColor(this.themeColorTextPrimary).layoutWeight(1)
        UiSwitchControl({
          checked: !this.exportSettings.exportNoChapterName,
          interactive: false,
          onChange: (value: boolean) => {
            void this.patchExportSettings((draft: BookExportSettings) => {
              draft.exportNoChapterName = !value;
            });
          }
        })
      }.width('100%').padding({ top: 10, bottom: 10 })
        .onClick(() => {
          void this.patchExportSettings((draft: BookExportSettings) => {
            draft.exportNoChapterName = !draft.exportNoChapterName;
          });
        })
      Row() {
        Text('导出到WebDav').fontSize(TITLE_SMALL_EMPHASIZED).fontColor(this.themeColorTextPrimary).layoutWeight(1)
        UiSwitchControl({
          checked: this.exportSettings.exportToWebDav,
          interactive: false,
          onChange: (value: boolean) => {
            void this.patchExportSettings((draft: BookExportSettings) => {
              draft.exportToWebDav = value;
            });
          }
        })
      }.width('100%').padding({ top: 10, bottom: 10 })
        .onClick(() => {
          void this.patchExportSettings((draft: BookExportSettings) => {
            draft.exportToWebDav = !draft.exportToWebDav;
          });
        })
      Row() {
        Text('导出插图文件').fontSize(TITLE_SMALL_EMPHASIZED).fontColor(this.themeColorTextPrimary).layoutWeight(1)
        UiSwitchControl({
          checked: this.exportSettings.exportPictureFile,
          interactive: false,
          onChange: (value: boolean) => {
            void this.patchExportSettings((draft: BookExportSettings) => {
              draft.exportPictureFile = value;
            });
          }
        })
      }.width('100%').padding({ top: 10, bottom: 10 })
        .onClick(() => {
          void this.patchExportSettings((draft: BookExportSettings) => {
            draft.exportPictureFile = !draft.exportPictureFile;
          });
        })
      Row() {
        Text('并行导出').fontSize(TITLE_SMALL_EMPHASIZED).fontColor(this.themeColorTextPrimary).layoutWeight(1)
        UiSwitchControl({
          checked: this.exportSettings.parallelExportBook,
          interactive: false,
          onChange: (value: boolean) => {
            void this.patchExportSettings((draft: BookExportSettings) => {
              draft.parallelExportBook = value;
            });
          }
        })
      }.width('100%').padding({ top: 10, bottom: 10 })
        .onClick(() => {
          void this.patchExportSettings((draft: BookExportSettings) => {
            draft.parallelExportBook = !draft.parallelExportBook;
          });
        })
    }.width('100%')
  }

  /**
   * 字符集 / 文件名输入对话框。形态照上游 AppAlertDialog（标题 + 一个输入框 + 确定/取消），
   * 视觉用本仓 M3 对话框口径：`pages/AppBackupSettingsPage.ets:730-792` 的 312 宽 + 24 内距 + 28 圆角。
   */
  @Builder
  private ExportInputDialogContent() {
    Column() {
      Text(this.showCharsetDialog ? '设置字符集' : '导出文件名')
        .fontSize(TITLE_MEDIUM).fontWeight(FontWeight.Medium).fontColor(this.themeColorTextPrimary)
        .width('100%')
      TextInput({
        text: this.showCharsetDialog ? this.exportCharsetDraft : this.exportFileNameDraft,
        placeholder: this.showCharsetDialog ? 'UTF-8' : '{name} - {author}'
      })
        .height(44).fontSize(BODY_MEDIUM).width('100%').margin({ top: 16 })
        .onChange((value: string) => {
          if (this.showCharsetDialog) {
            this.exportCharsetDraft = value;
          } else {
            this.exportFileNameDraft = value;
          }
        })
      if (!this.showCharsetDialog) {
        // F-2：帮助文案按上游 `R.string.export_file_name_template_help`
        // （`BookshelfManageScreen.kt:215`）措辞对齐。
        Text('可用变量：{name} 书名、{author} 作者、{group} 分组、{source} 书源、{remark} 备注')
          .fontSize(LABEL_SMALL).fontColor(this.themeColorTextTertiary).width('100%').margin({ top: 8 })
      }
      Row() {
        Button('取消').type(ButtonType.Normal).layoutWeight(1).height(40).borderRadius(20)
          .fontColor(this.themeColorTextSecondary).backgroundColor(this.themeColorSurfaceSecondary)
          .onClick(() => this.closeExportInputDialog())
        Button('确定').type(ButtonType.Normal).layoutWeight(1).height(40).borderRadius(20)
          .fontColor('#101116').backgroundColor(this.themeColorAccent).margin({ left: 12 })
          .onClick(async () => { await this.confirmExportInput(); })
      }.width('100%').margin({ top: 24 })
    }
    .width(312).padding(24)
    .backgroundColor(this.themeColorSurfaceElevated).borderRadius(28)
  }

  /**
   * 自定义导出对话框内容，逐项对齐上游 `BookshelfManageScreen.kt:1248-1371`：
   * 两个单选（全本 / 按范围）+ 范围输入（含错误提示）+ 每卷章数 + 分卷文件名模板 +
   * 「Analyzed: 预览名」。上游只在「按范围」时显示后三行，这里同构。
   */
  @Builder
  private CustomExportDialogContent() {
    Column() {
      Text('选择待导出章节')
        .fontSize(TITLE_MEDIUM).fontWeight(FontWeight.Medium).fontColor(this.themeColorTextPrimary)
        .width('100%')
      Row() {
        Radio({ value: 'all', group: 'customExportScope' })
          .checked(this.customExportAllChapter)
          .onChange((checked: boolean) => { if (checked) { this.customExportAllChapter = true; } })
        Text('导出全部').fontSize(BODY_MEDIUM).fontColor(this.themeColorTextPrimary).layoutWeight(1)
      }.width('100%').margin({ top: 12 })
      Row() {
        Radio({ value: 'range', group: 'customExportScope' })
          .checked(!this.customExportAllChapter)
          .onChange((checked: boolean) => { if (checked) { this.customExportAllChapter = false; } })
        Text('按章节范围导出').fontSize(BODY_MEDIUM).fontColor(this.themeColorTextPrimary).layoutWeight(1)
      }.width('100%').margin({ top: 4 })
      if (!this.customExportAllChapter) {
        // F-7：占位示例按上游 `BookshelfManageScreen.kt:1289` 的 `"1-5,8,10-18"`。
        TextInput({ text: this.customScopeInput, placeholder: '1-5,8,10-18' })
          .height(44).fontSize(BODY_MEDIUM).width('100%').margin({ top: 12 })
          .onChange((value: string) => {
            this.customScopeInput = value;
            this.customScopeError = '';
          })
        if (this.customScopeError.length > 0) {
          Text(this.customScopeError).fontSize(LABEL_SMALL).fontColor('#F2B8B5')
            .width('100%').margin({ top: 4 })
        }
        Text('每个文件包含的章节数').fontSize(LABEL_MEDIUM).fontColor(this.themeColorTextSecondary)
          .width('100%').margin({ top: 12 })
        TextInput({ text: this.customVolumeSizeInput, placeholder: '1' })
          .height(44).fontSize(BODY_MEDIUM).width('100%').type(InputType.Number).margin({ top: 4 })
          .onChange((value: string) => { this.customVolumeSizeInput = value; })
        Text('分卷文件名模板').fontSize(LABEL_MEDIUM).fontColor(this.themeColorTextSecondary)
          .width('100%').margin({ top: 12 })
        TextInput({ text: this.customFileNameInput, placeholder: '{name} - {author}' })
          .height(44).fontSize(BODY_MEDIUM).width('100%').margin({ top: 4 })
          .onChange((value: string) => { this.customFileNameInput = value; })
        // F-9：上游 `BookshelfManageScreen.kt:1319-1330` —— 模板能解析时显示
        // 「解析示例: 文件名」，非空但解析失败时显示 Error。
        if (this.customFileNameInput.trim().length > 0) {
          if (this.customExportPreviewName().length > 0) {
            Text(`解析示例：${this.customExportPreviewName()}`)
              .fontSize(LABEL_SMALL).fontColor(this.themeColorTextTertiary).width('100%').margin({ top: 4 })
          } else {
            Text('Error').fontSize(LABEL_SMALL).fontColor('#F2B8B5').width('100%').margin({ top: 4 })
          }
        }
      }
      Row() {
        Button('取消').type(ButtonType.Normal).layoutWeight(1).height(40).borderRadius(20)
          .fontColor(this.themeColorTextSecondary).backgroundColor(this.themeColorSurfaceSecondary)
          .onClick(() => this.closeCustomExportDialog())
        Button('确定').type(ButtonType.Normal).layoutWeight(1).height(40).borderRadius(20)
          .fontColor('#101116').backgroundColor(this.themeColorAccent).margin({ left: 12 })
          .onClick(async () => { await this.confirmCustomExport(); })
      }.width('100%').margin({ top: 24 })
    }
    .width(312).padding(24)
    .backgroundColor(this.themeColorSurfaceElevated).borderRadius(28)
  }

  @Builder
  private ExportSheetContent() {
    Column() {
      Row() {
        Text(this.showExportSettings ? '导出设置' : '导出').fontSize(TITLE_LARGE)
          .fontWeight(FontWeight.Medium).fontColor('#ECEEF2').layoutWeight(1)
        // E-2：上游 startAction 是 `MediumTonalButton(icon = if(showExportSettings) Upload else Settings)`
        // —— 图标按钮，不是文字按钮。
        Row() {
          AppGlyph({
            name: this.showExportSettings ? 'uploadFile' : 'settings',
            glyphSize: 18,
            tint: this.themeColorAccent
          })
        }.padding({ left: 10, right: 10, top: 6, bottom: 6 }).borderRadius(18)
          .backgroundColor(this.themeColorSurfaceElevated)
          .accessibilityText(this.showExportSettings ? '导出' : '导出设置')
          .onClick(() => this.showExportSettings = !this.showExportSettings)
      }.width('100%')
      // E-3：上游 `AnimatedContent(targetState=showExportSettings, fadeIn() togetherWith fadeOut())`
      // —— 两页之间淡入淡出切换，不是瞬切。
      if (this.showExportSettings) {
        Column() {
          this.ExportSettingsContent()
        }.width('100%').transition(TransitionEffect.OPACITY.animation({ duration: 200 }))
      } else {
        Column() {
          Text(`本次导出（${this.exportBooks.length} 本）`).fontSize(LABEL_MEDIUM)
            .fontColor(this.themeColorTextSecondary).width('100%').margin({ top: 12 })
          ForEach(this.exportBooks, (book: Book) => {
            Text(book.title).fontSize(LABEL_LARGE).fontColor(this.themeColorTextPrimary).maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis }).width('100%').padding({ top: 5, bottom: 5 })
          }, (book: Book) => this.rowKey(book))
          Row() {
            Text('取消').fontSize(LABEL_LARGE).fontColor('#C5C7D0').textAlign(TextAlign.Center)
              .layoutWeight(1).padding({ top: 12, bottom: 12 }).backgroundColor('#2A2B33').borderRadius(14)
              .onClick(() => this.showExportSheet = false)
            // E-16：上游确认按钮是 `MediumTonalButton(Upload, text=export)` —— 带 Upload 图标。
            Row() {
              AppGlyph({ name: 'uploadFile', glyphSize: 16, tint: '#101116' })
              Text('导出').fontSize(LABEL_LARGE).fontColor('#101116').margin({ left: 6 })
            }.layoutWeight(1).justifyContent(FlexAlign.Center)
              .padding({ top: 12, bottom: 12 }).backgroundColor('#B9C6FF').borderRadius(14)
              .margin({ left: 10 }).onClick(async () => { await this.runExport(); })
          }.width('100%').margin({ top: 20 })
        }.width('100%').transition(TransitionEffect.OPACITY.animation({ duration: 200 }))
      }
    }.width('100%')
  }

  /**
   * 选组面板：多选 + 新建分组 + 每行编辑。
   *
   * 对齐上游 `BookInfoSheets.kt:108-190 GroupSelectSheet`：标题 `group_select`，
   * 右上「新建」（`group_add`）与每行「编辑」（`edit`）都打开同一个 `GroupEditSheet`，
   * 底部「确认」（`confirm`）。上游用位掩码 `selectedGroupId and group.groupId != 0L`
   * 判选中、`± group.groupId` 切换；本地等价物是 `selectedGroupNames` 数组。
   */
  @Builder
  private GroupSelectContent() {
    Column() {
      Row() {
        Text('分组选择').fontSize(TITLE_LARGE).fontWeight(FontWeight.Medium).fontColor('#ECEEF2').layoutWeight(1)
        // 上游 startAction = MediumTonalButton(Icons.Default.Add, group_add)。
        Row() {
          AppGlyph({ name: 'add', glyphSize: 20, tint: this.themeColorAccent })
          Text('新建分组').fontSize(LABEL_MEDIUM).fontColor(this.themeColorAccent).margin({ left: 6 })
        }
        .padding({ left: 12, right: 12, top: 8, bottom: 8 })
        .borderRadius(20)
        .onClick(() => this.openGroupEditor(undefined))
        .accessibilityText('新建分组')
      }.width('100%').margin({ bottom: 8 })

      List({ space: 8 }) {
        ForEach(this.groupNamesForSelection(), (name: string) => {
          ListItem() {
            Row() {
              // 18×18 自绘勾选框：选中填强调色 + 勾，未选只留描边。
              Stack({ alignContent: Alignment.Center }) {
                if (this.isGroupNameSelected(name)) {
                  AppGlyph({ name: 'profileCheck', glyphSize: 14, tint: '#101116' })
                }
              }
              .width(18).height(18).borderRadius(4)
              .backgroundColor(this.isGroupNameSelected(name) ? this.themeColorAccent : '#00000000')
              .border({
                width: this.isGroupNameSelected(name) ? 0 : 1.5,
                color: this.themeColorTextTertiary
              })
              Text(name).fontSize(TITLE_SMALL).fontColor(this.themeColorTextPrimary)
                .layoutWeight(1).margin({ left: 10 })
              // 每行「编辑」：上游 trailingAction = SmallPlainButton(Icons.Default.Edit, edit)。
              Text('编辑').fontSize(LABEL_MEDIUM).fontColor(this.themeColorTextSecondary).padding(6)
                .onClick(() => {
                  const target = this.groups.find((group: BookGroup) => group.groupName === name);
                  if (target !== undefined) { this.openGroupEditor(target); }
                })
            }
            .width('100%').padding({ left: 14, right: 14, top: 12, bottom: 12 })
            .borderRadius(12).backgroundColor(this.themeColorSurfaceSecondary)
            .onClick(() => this.toggleGroupName(name))
          }
        }, (name: string) => name)
      }.width('100%').constraintSize({ maxHeight: 420 }).scrollBar(BarState.Off)

      Row({ space: 12 }) {
        Text('取消').fontSize(LABEL_LARGE).fontColor('#C5C7D0').textAlign(TextAlign.Center).layoutWeight(1)
          .padding({ top: 12, bottom: 12 }).backgroundColor('#2A2B33').borderRadius(14)
          .onClick(() => this.showGroupSelect = false)
        // 上游 endAction = MediumTonalButton(Icons.Default.Check, confirm)。
        Text('确认').fontSize(LABEL_LARGE).fontColor('#101116').textAlign(TextAlign.Center).layoutWeight(1)
          .padding({ top: 12, bottom: 12 }).backgroundColor(this.themeColorAccent).borderRadius(14)
          .onClick(() => { void this.applyGroupSelection(); })
      }.width('100%').margin({ top: 12 })
    }.width('100%')
  }


  /** 同一组件只挂一个 bindSheet，按状态分发内容（批3 同款，避免多个 bindSheet 只有最后生效）。 */
  @Builder
  private ManageSheet() {
    Column() {
      if (this.showDeleteConfirm) {
        this.DeleteConfirmContent()
      } else if (this.showBatchDownloadConfirm) {
        this.BatchDownloadConfirmContent()
      } else if (this.showDownloadAllConfirm) {
        this.DownloadAllConfirmContent()
      } else if (this.showChangeSourceStatus) {
        // D-10：批量换源进度/错误框（上游是 AppAlertDialog，不是 sheet，见 ChangeSourceStatusDialog 注释）。
        this.ChangeSourceStatusContent()
      } else if (this.showExportFolderPicker) {
        // D-9：导出文件夹选择中间层（上游 FilePickerSheet）。
        this.ExportFolderPickerContent()
      } else if (this.showExportSheet) {
        this.ExportSheetContent()
      } else if (this.showGroupEditor) {
        // 第十表 H-4：分组编辑表单与书架页共用同一个组件（上游 GroupSelectSheet → GroupEditSheet）。
        GroupEditorSheet({
          editingGroup: this.groupEditing,
          books: this.books,
          onSave: (groupId: number, draft: BookGroupDraft) => this.saveGroupDraft(groupId, draft),
          onChooseCover: (groupId: number) => this.onChooseGroupCover(groupId),
          onChooseCoverDraft: () => this.onChooseGroupCoverDraft(),
          onClearCover: (groupId: number) => this.onClearGroupCover(groupId),
          onRemove: (groupId: number) => {
            this.onRemoveGroup(groupId);
            const removed = this.groupEditing;
            if (removed !== undefined) {
              if (this.currentGroupName === removed.groupName) { this.currentGroupName = ''; }
              const index = this.selectedGroupNames.indexOf(removed.groupName);
              if (index >= 0) {
                const next = this.selectedGroupNames.slice(0);
                next.splice(index, 1);
                this.selectedGroupNames = next;
              }
            }
            this.showGroupEditor = false;
          },
          onCancel: () => this.showGroupEditor = false,
          onMessage: (message: string) => this.onUnavailableAction(message),
          onApplyTagGroupRules: () => this.onApplyTagGroupRules()
        }).width('100%').height('100%')
      } else if (this.showGroupSelect) {
        this.GroupSelectContent()
      } else if (this.showLogSheet) {
        // D-8：日志面板改走公共组件（上游 BookshelfManageScreen.kt:1242-1245 的 AppLogSheet）。
        AppLogSheet({
          show: this.showLogSheet,
          onDismissRequest: () => { this.showLogSheet = false; }
        })
      }
    }.width('100%').padding({ left: 20, right: 20, top: 8, bottom: 24 })
  }

  /**
   * D-10：批量换源进行中 / 失败提示框。
   * 上游 `AppAlertDialog(show = isChangingSource || changeSourceError != null,
   *   title = change_source_batch, confirmText = if(isChangingSource) null else ok)`
   * （BookshelfManageScreen.kt:867-901），正文三态：错误 → error 色文案；
   * 进度 → changeSourceProgress；都没有 → 「准备中」，进行中时附环形进度。
   */
  @Builder
  private ChangeSourceStatusContent() {
    Column() {
      Text('批量换源').fontSize(TITLE_LARGE).fontWeight(FontWeight.Medium).fontColor(this.themeColorTextPrimary)
        .width('100%').margin({ bottom: 12 })
      if (this.uiState.isChangingSource) {
        Row() {
          LoadingProgress().width(22).height(22).color(this.themeColorAccent)
          Text(this.uiState.changeSourceProgress.length > 0 ? this.uiState.changeSourceProgress : '准备中')
            .fontSize(BODY_MEDIUM).fontColor(this.themeColorTextSecondary)
            .layoutWeight(1).margin({ left: 12 })
        }.width('100%').margin({ bottom: 20 })
      } else {
        Text(this.uiState.changeSourceError.length > 0 ? this.uiState.changeSourceError : '准备中')
          .fontSize(BODY_MEDIUM)
          .fontColor(this.uiState.changeSourceError.length > 0 ? '#FF6B6B' : this.themeColorTextSecondary)
          .width('100%').margin({ bottom: 20 })
      }
      // 上游进行中时 confirmText = null（不给确认按钮），只有结束/失败才可关闭。
      if (!this.uiState.isChangingSource) {
        Text('确认').fontSize(LABEL_LARGE).fontColor('#101116').textAlign(TextAlign.Center)
          .width('100%').padding({ top: 12, bottom: 12 }).backgroundColor('#B9C6FF').borderRadius(14)
          .onClick(() => {
            this.showChangeSourceStatus = false;
            this.dispatch(manageIntent(ManageIntentType.DismissChangeSourceStatus));
          })
      }
    }.width('100%')
  }

  /**
   * D-4：批量缓存确认框。上游 `BookshelfManageScreen.kt:913-930`
   * `AppAlertDialog(showBatchDownloadConfirmDialog, title=draw, text=sure_cache_book,
   *   onConfirm → DownloadBooks(selectedBookUrls, downloadAllChapters=false))`
   * 文案：title「提醒」/ text「是否确认开始缓存？」/ 确认「确认」/ 取消「取消」。
   */
  @Builder
  private BatchDownloadConfirmContent() {
    Column() {
      Text('提醒').fontSize(TITLE_LARGE).fontWeight(FontWeight.Medium).fontColor(this.themeColorTextPrimary)
        .width('100%').margin({ bottom: 12 })
      Text(`是否确认开始缓存？共 ${this.selectedBooks().length} 本。`)
        .fontSize(BODY_MEDIUM).fontColor(this.themeColorTextSecondary).width('100%')
        .margin({ bottom: 20 })
      Row() {
        Button('取消').type(ButtonType.Normal).layoutWeight(1).height(40).borderRadius(20)
          .backgroundColor(this.themeColorSurfaceElevated).fontColor(this.themeColorTextPrimary)
          .onClick(() => this.showBatchDownloadConfirm = false)
        Button('确认').type(ButtonType.Normal).layoutWeight(1).height(40).borderRadius(20)
          .margin({ left: 12 }).backgroundColor(this.themeColorAccent).fontColor('#1A1B21')
          .onClick(() => {
            this.showBatchDownloadConfirm = false;
            this.dispatch(manageIntent(ManageIntentType.DownloadBooks, {
              bookUrls: this.selectedBooks().map((book: Book) => this.bookKey(book)),
              downloadAllChapters: false
            }));
          })
      }.width('100%')
    }.width('100%')
  }

  /**
   * D-5：下载全部确认框。上游 `:995-1012`
   * `AppAlertDialog(showDownloadAllConfirmDialog, title=draw, text=sure_cache_book,
   *   onConfirm → StartDownloadForVisibleBooks(state.books, downloadAllChapters=true))`
   */
  @Builder
  private DownloadAllConfirmContent() {
    Column() {
      Text('提醒').fontSize(TITLE_LARGE).fontWeight(FontWeight.Medium).fontColor(this.themeColorTextPrimary)
        .width('100%').margin({ bottom: 12 })
      Text(`是否确认开始缓存？共 ${this.filteredBooks().length} 本，将下载全部章节。`)
        .fontSize(BODY_MEDIUM).fontColor(this.themeColorTextSecondary).width('100%')
        .margin({ bottom: 20 })
      Row() {
        Button('取消').type(ButtonType.Normal).layoutWeight(1).height(40).borderRadius(20)
          .backgroundColor(this.themeColorSurfaceElevated).fontColor(this.themeColorTextPrimary)
          .onClick(() => this.showDownloadAllConfirm = false)
        Button('确认').type(ButtonType.Normal).layoutWeight(1).height(40).borderRadius(20)
          .margin({ left: 12 }).backgroundColor(this.themeColorAccent).fontColor('#1A1B21')
          .onClick(() => {
            this.showDownloadAllConfirm = false;
            this.dispatch(manageIntent(ManageIntentType.StartDownloadForVisibleBooks,
              { downloadAllChapters: true }));
          })
      }.width('100%')
    }.width('100%')
  }

  build() {
    Column() {
      Row() {
        Text('‹ 返回').fontSize(LABEL_LARGE).fontColor(this.themeColorAccent)
          .onClick(() => this.onBack())
        Text(this.pageTitle()).fontSize(TITLE_LARGE).fontWeight(FontWeight.Medium)
          .fontColor(this.themeColorTextPrimary).margin({ left: 12 }).layoutWeight(1)
          .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
        AppGlyph({ name: 'search', glyphSize: 20, tint: this.themeColorTextPrimary })
          .width(40).height(40).onClick(() => this.isSearchMode = !this.isSearchMode)
          .accessibilityText('搜索')
        AppGlyph({ name: 'profileFilterAlt', glyphSize: 20, tint: this.themeColorTextPrimary })
          .width(40).height(40)
          .onClick(() => { this.groupFilterVisible = !this.groupFilterVisible; })
          // 上游取 BookSourceScreen.kt:916-985 分组筛选
          .accessibilityText('按分组筛选')
          .bindPopup(this.groupFilterVisible, {
            builder: this.GroupFilterMenu,
            placement: Placement.BottomRight,
            popupColor: '#00000000',
            enableArrow: false,
            autoCancel: true,
            width: MANAGE_MENU_WIDTH,
            onStateChange: (event: PopupStateChangeParam) => { this.groupFilterVisible = event.isVisible; }
          })
          .accessibilityText('分组筛选')
        AppGlyph({ name: 'more', glyphSize: 20, tint: this.themeColorTextPrimary })
          .width(40).height(40)
          .onClick(() => { this.moreMenuVisible = !this.moreMenuVisible; })
          .accessibilityText('更多菜单')
          .bindPopup(this.moreMenuVisible, {
            builder: this.MoreMenu,
            placement: Placement.BottomRight,
            popupColor: '#00000000',
            enableArrow: false,
            autoCancel: true,
            width: MANAGE_MENU_WIDTH,
            onStateChange: (event: PopupStateChangeParam) => { this.moreMenuVisible = event.isVisible; }
          })
      }.width('100%').padding({ left: 12, right: 12, top: 8 + this.appTopInset, bottom: 8 })
      if (this.isSearchMode) {
        Row() {
          TextInput({ text: this.searchKey, placeholder: '筛选书名/作者/书源/分组' })
            .layoutWeight(1).height(40).fontSize(TITLE_SMALL)
            .onChange((value: string) => this.searchKey = value)
          Text('清除').fontSize(BODY_SMALL).fontColor(this.themeColorAccent)
            .onClick(() => this.searchKey = '')
        }.width('100%').padding({ left: 16, right: 16 })
      }
      // C-11：手动排序分组下用 List 承载，才能拿到 ArkUI 的拖拽回调
      // （上游 `ReorderableItem(enabled = canReorderBooks)` + `longPressDraggableHandle`，:563-586）。
      // 非手动排序时保持普通 Scroll（List 的拖拽态会改变滚动惯性）。
      if (this.canReorderBooks()) {
        List({ space: MANAGE_ROW_GAP }) {
          ForEach(this.filteredBooks(), (book: Book, index: number) => {
            ListItem() {
              this.BookRow(book)
            }
          }, (book: Book) => this.rowKey(book))
        }
        .width('100%').layoutWeight(1).scrollBar(BarState.Off)
        .editMode(true)
        .onItemDragStart((_event: ItemDragInfo, itemIndex: number) => {
          this.draggingIndex = itemIndex;
          this.dragPreviewTitle = this.filteredBooks()[itemIndex] !== undefined
            ? this.filteredBooks()[itemIndex].title : '';
        })
        .onItemDrop((_event: ItemDragInfo, itemIndex: number, insertIndex: number, isSuccess: boolean) => {
          this.draggingIndex = -1;
          this.dragPreviewTitle = '';
          if (!isSuccess) { return; }
          this.dropReorder(itemIndex, insertIndex);
        })
        .onItemDragMove((_event: ItemDragInfo, itemIndex: number, insertIndex: number) => {
          this.draggingIndex = itemIndex;
        })
        .onItemDragLeave((_event: ItemDragInfo, itemIndex: number) => {
          this.draggingIndex = itemIndex;
        })
      } else {
        Scroll(this.listScroller) {
          Column({ space: MANAGE_ROW_GAP }) {
            // B-9：上游没有独立空态——`ListScaffold` 与 `FastScrollLazyColumn` 都不画空提示
            // （`ListScaffold.kt` 全文只有 `selectedIds.isEmpty()` 一处 isEmpty，是选择态底栏条件；
            // `BookshelfManageScreen.kt` 全文无 EmptyMessage）。列表为空就是空白，故删掉本地自造的空态行。
            ForEach(this.filteredBooks(), (book: Book) => {
              this.BookRow(book)
            }, (book: Book) => this.rowKey(book))
          }.width('100%')
        }.edgeEffect(EdgeEffect.Spring, { alwaysEnabled: false }).layoutWeight(1).scrollBar(BarState.Off)
      }
      if (this.selectionMode) {
        // B-6 / B-7 / D-3：选择态右下角 FAB 菜单。
        // 上游 `AppFloatingActionButtonMenu(Modifier.offset(x = 16.dp, y = 16.dp),
        // expanded = fabMenuExpanded, items = fabItems)`（BookshelfManageScreen.kt:371-441 / :520）。
        // ArkUI 无同名组件，用「圆钮 + bindPopup 菜单」等价实现，位移取 offset(16,16)。
        Row() {
          Text(this.selectionTitle()).fontSize(BODY_SMALL).fontColor('#DCDDE4').layoutWeight(1)
          Text('完成').fontSize(BODY_SMALL).fontColor('#C4D1FF')
            .padding({ left: 10, right: 10, top: 5, bottom: 5 }).borderRadius(8)
            .backgroundColor(this.themeColorSurfaceElevated)
            .onClick(() => this.clearSelection())
        }.width('100%').padding({ left: 16, right: 16, top: 8, bottom: 8 })
        Stack({ alignContent: Alignment.BottomEnd }) {
          Column()
            .width(56).height(56).borderRadius(16)
            .backgroundColor(this.themeColorAccent)
            .margin({ right: 16, bottom: 16 })
            .justifyContent(FlexAlign.Center)
            .onClick(() => { this.fabMenuExpanded = !this.fabMenuExpanded; })
            .accessibilityText('批量操作')
            .bindPopup(this.fabMenuExpanded, {
              builder: this.FabMenu,
              placement: Placement.TopRight,
              popupColor: '#00000000',
              enableArrow: false,
              autoCancel: true,
              width: MANAGE_MENU_WIDTH,
              onStateChange: (event: PopupStateChangeParam) => { this.fabMenuExpanded = event.isVisible; }
            })
          AppGlyph({ name: 'more', glyphSize: 24, tint: '#101116' })
            .width(56).height(56).margin({ right: 16, bottom: 16 })
            .hitTestBehavior(HitTestMode.Transparent)
        }.width('100%').layoutWeight(1)
      }
    }.width('100%').height('100%').backgroundColor(this.themeColorSurfacePrimary)
      .bindSheet(this.showDeleteConfirm || this.showExportSheet || this.showGroupSelect || this.showLogSheet ||
        this.showBatchDownloadConfirm || this.showDownloadAllConfirm ||
        this.showChangeSourceStatus || this.showExportFolderPicker || this.showGroupEditor,
        this.ManageSheet(), {
          height: SheetSize.FIT_CONTENT, dragBar: true, showClose: false, backgroundColor: this.themeColorSurfaceTertiary,
          onDisappear: () => {
            this.showDeleteConfirm = false;
            this.showExportSheet = false;
            this.showGroupSelect = false;
            this.showLogSheet = false;
            this.showBatchDownloadConfirm = false;
            this.showDownloadAllConfirm = false;
            this.showChangeSourceStatus = false;
            this.showExportFolderPicker = false;
            this.showGroupEditor = false;
          }
        })
  }
}
