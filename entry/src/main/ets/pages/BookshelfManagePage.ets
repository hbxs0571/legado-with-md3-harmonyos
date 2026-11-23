import { UiSwitchControl } from '../components/UiSwitchControl';
import { UiMenuItem, UiMenuPanel } from '../components/UiMenu';
import { UiDropdown } from '../components/settings/UiDropdown';
import { Book } from '../model/Book';
import { BookGroup } from '../model/BookGroup';
import { BookRepository } from '../data/BookRepository';
import { LocalBookRestorePlanner } from '../data/LocalBookRestorePlanner';
import { BookExporter, ExportTarget } from '../data/BookExporter';
import {
  BookExportSettings,
  BookExportSettingsStore,
  COMMON_EXPORT_CHARSETS,
  EXPORT_TYPES,
  defaultBookExportSettings,
  episodeExportFileNameOf
} from '../data/BookExportSettings';
import { AppGlyph } from '../components/AppGlyph';
import { AppLog, AppLogEntry } from '../lib/AppLog';
import { ChapterDownloadQueue, DownloadState } from '../bookSource/ChapterDownloadQueue';
import { fileIo, fileShare, picker } from '@kit.CoreFileKit';
import { Context } from '@kit.AbilityKit';
import { BODY_MEDIUM, BODY_SMALL, LABEL_LARGE, LABEL_MEDIUM, LABEL_SMALL, TITLE_LARGE, TITLE_MEDIUM, TITLE_SMALL, TITLE_SMALL_EMPHASIZED, TITLE_SMALL_LINE_HEIGHT } from '../components/typography/TypographyTokens';

/** 卡片式菜单的统一宽度，与书架页、详情页同口径。 */
const MANAGE_MENU_WIDTH: number = 260;


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
  /** 进页时的分组名；空串或「全部」都表示全部。 */
  @Prop initialGroupName: string = '';
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

  @StorageProp('themeColorSurfaceTertiary') themeColorSurfaceTertiary: string = '#F0F1F5';
  @StorageProp('themeColorTextPrimary') themeColorTextPrimary: string = '#F1F2F6';
  @StorageProp('themeColorTextSecondary') themeColorTextSecondary: string = '#AEB0BA';
  @StorageProp('themeColorTextTertiary') themeColorTextTertiary: string = '#858792';
  @StorageProp('themeColorAccent') themeColorAccent: string = '#B9C6FF';
  @StorageProp('themeColorSurfacePrimary') themeColorSurfacePrimary: string = '#17181E';
  @StorageProp('themeColorSurfaceElevated') themeColorSurfaceElevated: string = '#23242C';
  @StorageProp('themeColorSurfaceSecondary') themeColorSurfaceSecondary: string = '#1F2027';
  @StorageProp('appTopInset') appTopInset: number = 0;

  @State currentGroupName: string = '';
  @State isSearchMode: boolean = false;
  @State searchKey: string = '';
  @State selectionMode: boolean = false;
  /** 键用 bookUrl + id；book.id 是文件名派生的，同名异目录会撞键。 */
  @State selectedBookKeys: Set<string> = new Set<string>();
  @State showDeleteConfirm: boolean = false;
  @State deleteOriginalFile: boolean = false;
  @State pendingDeleteKeys: string[] = [];
  @State showExportSheet: boolean = false;
  @State showExportSettings: boolean = false;
  @State exportBooks: Book[] = [];
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
  @State showSegmentedExport: boolean = false;
  @State segmentedExportBook: Book | undefined = undefined;
  @State segmentedScope: string = '1-';
  @State segmentedVolumeSize: string = '1';
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
  @State preselectedGroupName: string = '';
  @State rowMenuKey: string = '';
  /** 批2（:457）：日志面板显隐；内容取 AppLog 内存缓冲快照。 */
  @State showLogSheet: boolean = false;
  @State logEntries: AppLogEntry[] = [];
  /**
   * 批2（:455 :459 :466）：每本书的下载状态，键是 bookKey(book)。
   * ArkUI 里 Map 原地 set 不触发刷新，一律整体替换（同 exportMsgByKey 的坑）。
   */
  @State bookDownloadStates: Map<string, DownloadState> = new Map<string, DownloadState>();

  private listScroller: Scroller = new Scroller();
  /** 下载队列订阅的取消函数；aboutToDisappear 必须调，否则页面销毁后回调还在跑。 */
  private downloadUnsubscribe: (() => void) | undefined = undefined;

  aboutToAppear(): void {
    this.currentGroupName = this.initialGroupName;
    this.downloadUnsubscribe = ChapterDownloadQueue.subscribe(() => this.refreshDownloadStates());
    this.refreshDownloadStates();
    void this.loadExportSettings();
  }

  aboutToDisappear(): void {
    if (this.downloadUnsubscribe !== undefined) {
      this.downloadUnsubscribe();
      this.downloadUnsubscribe = undefined;
    }
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
      const matchesSearch = keyword.length === 0 ||
        book.title.toLowerCase().includes(keyword) ||
        book.author.toLowerCase().includes(keyword);
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

  private selectedBooks(): Book[] {
    return this.books.filter((book: Book) => this.isSelected(book));
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
  private async chooseExportFolder(): Promise<void> {
    const context = this.getUIContext().getHostContext();
    if (context === undefined) { return; }
    try {
      const options = new picker.DocumentSelectOptions();
      options.selectMode = picker.DocumentSelectMode.FOLDER;
      options.maxSelectNumber = 1;
      const uris = await new picker.DocumentViewPicker(context).select(options);
      const uri = uris[0];
      if (uri === undefined) { return; }
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
    } catch (error) {
      this.onUnavailableAction(error instanceof Error ? `选择导出文件夹失败：${error.message}` : '选择导出文件夹失败');
    }
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

  /**
   * 批2（:471）：打开分段导出输入。
   * 上游 BookshelfManageScreen.kt:298 只在「单选一本书」时给这个入口，多选走普通导出，
   * 所以这里只接受单本，且从来不在选择模式的批量菜单里出现。
   */
  private openSegmentedExport(book: Book): void {
    this.segmentedExportBook = book;
    this.segmentedScope = `1-${Math.max(1, this.chapterCountHint(book))}`;
    this.segmentedVolumeSize = '1';
    this.showSegmentedExport = true;
  }

  /** 没读到章节数时给一个能覆盖全书的默认范围（上游默认把整本当一段）。 */
  private chapterCountHint(book: Book): number {
    const total = Number(book.chapterCount ?? '0');
    return Number.isFinite(total) && total > 0 ? Math.floor(total) : 1;
  }

  private runSegmentedExport(): void {
    const book = this.segmentedExportBook;
    if (book === undefined) {
      this.showSegmentedExport = false;
      return;
    }
    const scopeSpec = this.segmentedScope.trim();
    if (scopeSpec.length === 0) {
      this.onUnavailableAction('请先填章节范围');
      return;
    }
    const size = Math.floor(Number(this.segmentedVolumeSize));
    this.showSegmentedExport = false;
    this.onExportSegmented(book, scopeSpec, Number.isFinite(size) && size >= 1 ? size : 1);
  }

  private exportMsgOf(book: Book): string {
    return this.exportMsgByKey.get(this.rowKey(book)) ?? '';
  }

  private openExportSheet(books: Book[]): void {
    if (books.length === 0) { this.onUnavailableAction('当前没有可导出的书籍'); return; }
    this.exportBooks = books;
    this.exportMsgByKey = new Map<string, string>();
    this.showExportSettings = false;
    this.showExportSheet = true;
  }

  private async runExport(): Promise<void> {
    const context = this.getUIContext().getHostContext();
    if (context === undefined) { this.onUnavailableAction('无法访问本地文件'); return; }
    // 上游在「选完导出目录」时判 `isCustomEpubExportEnabled`：单本 + 开了自定义导出 + 格式是 epub
    // （`BookshelfManageScreen.kt:298`/`:336`，`BookshelfManageScreenViewModel.kt:93-94`）。
    // 本地没有「选完目录」这个时机，等价时机是点「导出」这一刻。
    if (this.exportBooks.length === 1 && this.isCustomEpubExportEnabled()) {
      const book = this.exportBooks[0];
      if (book !== undefined) {
        this.openCustomExportDialog(book);
        return;
      }
    }
    this.showExportSheet = false;
    await this.exportBooksInOrder(context, this.exportBooks, false);
  }

  /** 上游 `isCustomEpubExportEnabled`：`enableCustomExport && exportType == 1`。 */
  private isCustomEpubExportEnabled(): boolean {
    return this.exportSettings.enableCustomExport && this.exportSettings.exportType === 1;
  }

  /** 逐本导出，把每本的提示写回行内文案。`scopeSpec` 非空时走分段导出。 */
  private async exportBooksInOrder(context: Context, books: Book[], segmented: boolean,
    scopeSpec: string = '', chaptersPerVolume: number = 1): Promise<void> {
    const target = this.exportTarget();
    const total = books.length;
    for (let i = 0; i < total; i++) {
      const book = books[i];
      if (book === undefined) { continue; }
      const key = this.rowKey(book);
      this.putExportMsg(key, `第 ${i + 1} / 共 ${total} 本，正在导出…`);
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
      this.customScopeError = '请输入正确的章节范围';
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

  /** 每次打开删除框都从「未勾选」起步，不沿用上一次。 */
  private requestDelete(keys: string[]): void {
    if (keys.length === 0) { return; }
    this.pendingDeleteKeys = keys;
    this.deleteOriginalFile = false;
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
      await this.onLibraryChanged();
      this.clearSelection();
      this.onUnavailableAction(`已删除 ${targets.length} 本书`);
    } catch (error) {
      this.onUnavailableAction('删除失败，请重试');
    }
    this.pendingDeleteKeys = [];
  }

  private openGroupSelect(keys: string[]): void {
    if (keys.length === 0) { return; }
    this.groupSelectBookKeys = keys;
    // 所有选中书的 groupNames 排序后 join 完全一致才预选那个分组名，否则不预选。
    const selected = this.books.filter((book: Book) => keys.includes(this.rowKey(book)));
    let common = '';
    if (selected.length > 0) {
      const first = [...(selected[0].groupNames ?? [])].sort().join('、');
      const same = selected.every((book: Book) =>
        [...(book.groupNames ?? [])].sort().join('、') === first);
      common = same ? first : '';
    }
    this.preselectedGroupName = common;
    this.showGroupSelect = true;
  }

  private async applyGroup(groupName: string): Promise<void> {
    const context = this.getUIContext().getHostContext();
    if (context === undefined) { this.onUnavailableAction('无法访问本地书架'); return; }
    this.showGroupSelect = false;
    const keys = this.groupSelectBookKeys;
    const targets = this.books.filter((book: Book) => keys.includes(this.rowKey(book)));
    if (targets.length === 0) { return; }
    try {
      // group 列是位掩码；setBooksGroup 内部用 maskFromNames（加法，不用 32 位会被截断的位或）。
      await BookRepository.setBooksGroup(context, targets.map((book: Book) => this.bookKey(book)), groupName);
      await this.onLibraryChanged();
      this.clearSelection();
      this.onUnavailableAction(groupName.length > 0 ? `已移入「${groupName}」` : '已移出分组');
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
   */
  private moreMenuItems(): UiMenuItem[] {
    return [
      { key: 'download_all', title: '下载全部' },
      { key: 'log', title: '日志' },
      { key: 'export_all', title: '导出全部' }
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
          this.onDownloadAll(this.filteredBooks());
        } else if (key === 'log') {
          this.logEntries = AppLog.getAll();
          this.showLogSheet = true;
        } else if (key === 'export_all') {
          this.openExportSheet(this.filteredBooks());
        }
      }
    })
  }

  /** 选择模式操作。批2 补「下载」（:466）与「清除缓存」（:469）；批10 补「批量换源」（:564）。 */
  private selectionMenuItems(): UiMenuItem[] {
    return [
      { key: 'select_all', title: '全选' },
      { key: 'invert', title: '反选' },
      { key: 'move_group', title: '移入分组' },
      { key: 'batch_change_source', title: '批量换源' },
      { key: 'download_selected', title: '下载' },
      { key: 'clear_cache', title: '清除缓存' }
    ];
  }

  @Builder
  private SelectionMenu() {
    UiMenuPanel({
      items: this.selectionMenuItems(),
      panelWidth: MANAGE_MENU_WIDTH,
      onSelect: (key: string) => {
        this.selectionMenuVisible = false;
        if (key === 'select_all') {
          this.selectAllVisible();
        } else if (key === 'invert') {
          this.invertVisibleSelection();
        } else if (key === 'move_group') {
          const keys: string[] = this.selectedBooks().map((book: Book) => this.rowKey(book));
          this.openGroupSelect(keys);
        } else if (key === 'batch_change_source') {
          this.onBatchChangeSource(this.selectedBooks());
        } else if (key === 'download_selected') {
          this.onDownloadSelected(this.selectedBooks());
        } else if (key === 'clear_cache') {
          this.onClearSelectedCache(this.selectedBooks());
        }
      }
    })
  }

  // ---------------------------------------------------------------- 书籍行

  @Builder
  private BookRow(book: Book) {
    Column() {
      Row() {
        Column() {
          Text(book.title).fontSize(TITLE_MEDIUM).fontColor(this.themeColorTextPrimary).maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .onClick(() => this.onOpenBookInfo(book))
          Text(book.author.length > 0 ? book.author : '作者未知').fontSize(BODY_SMALL)
            .fontColor(this.themeColorTextSecondary).margin({ top: 2 }).maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Text(`${this.groupLabelOf(book)} · ${this.sourceFileLabelOf(book)}`).fontSize(LABEL_SMALL)
            .fontColor(this.themeColorAccent).margin({ top: 2 }).maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          if (this.exportMsgOf(book).length > 0) {
            Text(this.exportMsgOf(book)).fontSize(LABEL_SMALL).fontColor(this.themeColorTextTertiary)
              .margin({ top: 2 }).maxLines(1)
          }
        }.layoutWeight(1).alignItems(HorizontalAlign.Start)
        if (BookRepository.isOnlineBook(book)) {
          // 批2（:459）：在线书右端是下载状态；空闲时点一下开始下，跑起来后点一下停止。
          Row() {
            if (this.downloadStateOf(book) === 'done') {
              AppGlyph({ name: 'profileCheck', glyphSize: 16, tint: '#7BD88F' })
            } else if (this.isDownloadBusy(book)) {
              AppGlyph({ name: 'profileClose', glyphSize: 16, tint: this.themeColorAccent })
            } else {
              AppGlyph({ name: 'download', glyphSize: 16, tint: this.themeColorAccent })
            }
            Text(this.downloadStateLabelOf(book)).fontSize(LABEL_SMALL)
              .fontColor(this.themeColorTextSecondary).margin({ left: 4 })
          }
          .padding({ left: 8, right: 8, top: 3, bottom: 3 }).borderRadius(8)
          .backgroundColor(this.themeColorSurfaceElevated)
          .accessibilityText(`${book.title} ${this.downloadStateLabelOf(book)}`)
          .onClick(() => this.toggleBookDownload(book))
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
      // 行内按钮：批2 补「下载/停止」（:459），只在在线书上出现。
      Row() {
        Text('导出').fontSize(LABEL_SMALL).fontColor(this.themeColorAccent).layoutWeight(1).height(30)
          .textAlign(TextAlign.Center).onClick(() => this.openExportSheet([book]))
        if (BookRepository.isOnlineBook(book)) {
          Text(this.isDownloadBusy(book) ? '停止' : '下载').fontSize(LABEL_SMALL)
            .fontColor(this.themeColorAccent).layoutWeight(1).height(30).textAlign(TextAlign.Center)
            .onClick(() => this.toggleBookDownload(book))
        }
        Text('分组').fontSize(LABEL_SMALL).fontColor(this.themeColorAccent).layoutWeight(1).height(30)
          .textAlign(TextAlign.Center).onClick(() => this.openGroupSelect([this.rowKey(book)]))
        Text('更多').fontSize(LABEL_SMALL).fontColor(this.themeColorAccent).layoutWeight(1).height(30)
          .textAlign(TextAlign.Center)
          .onClick(() => this.rowMenuKey = this.rowMenuKey === this.rowKey(book) ? '' : this.rowKey(book))
      }.width('100%').margin({ top: 6 })
      // 「更多」展开的小菜单：删除书籍 + 分段导出（换源归批13、清缓存判不接）。
      // 批2（:471）：分段导出只在单本操作里出现，多选批量导出仍走上面的「导出」。
      if (this.rowMenuKey === this.rowKey(book)) {
        Row() {
          Text('分段导出').fontSize(BODY_SMALL).fontColor(this.themeColorAccent)
            .padding({ left: 12, right: 12, top: 6, bottom: 6 })
            .onClick(() => {
              this.rowMenuKey = '';
              this.openSegmentedExport(book);
            })
          Text('删除书籍').fontSize(BODY_SMALL).fontColor('#FF6B6B').padding({ left: 12, right: 12, top: 6, bottom: 6 })
            .onClick(() => {
              this.rowMenuKey = '';
              this.requestDelete([this.rowKey(book)]);
            })
          Text('取消').fontSize(BODY_SMALL).fontColor(this.themeColorTextSecondary)
            .padding({ left: 12, right: 12, top: 6, bottom: 6 })
            .onClick(() => this.rowMenuKey = '')
        }.width('100%').justifyContent(FlexAlign.End)
      }
    }
    .width('100%').padding({ left: 16, right: 16, top: 10, bottom: 10 })
    .backgroundColor(this.isSelected(book) ? '#2A2D3A' : this.themeColorSurfacePrimary)
    // 长按与短按必须互斥：onClick 与 gesture 并存时长按会顺带触发点击，
    // 表现是刚进选择模式就被又 toggle 一次、选中立刻消失（批7 封面同款坑）。
    .gesture(GestureGroup(GestureMode.Exclusive,
      LongPressGesture({ duration: 500 }).onAction(() => {
        this.selectionMode = true;
        this.toggleBookSelection(book);
      }),
      TapGesture({ count: 1 }).onAction(() => {
        if (this.selectionMode) { this.toggleBookSelection(book); }
      })
    ))
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
        .onClick(() => { void this.chooseExportFolder(); })
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
        placeholder: this.showCharsetDialog ? 'UTF-8' : '{name} {author}'
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
        Text('可用占位符：{name} {author} {group} {source} {remark}；留空则用「书名 作者：作者名」')
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
      Text('选择要导出的章节')
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
        // 上游：模板为空或不可解析时不显示预览，非空且解析失败时显示 Error（`:1257`/`:1319-1330`）。
        if (this.customFileNameInput.trim().length > 0) {
          Text(`Analyzed: ${this.customExportPreviewName()}`)
            .fontSize(LABEL_SMALL).fontColor(this.themeColorTextTertiary).width('100%').margin({ top: 4 })
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
        Text(this.showExportSettings ? '返回' : '导出设置').fontSize(LABEL_MEDIUM).fontColor(this.themeColorAccent)
          .onClick(() => this.showExportSettings = !this.showExportSettings)
      }.width('100%')
      if (this.showExportSettings) {
        this.ExportSettingsContent()
      } else {
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
          Text('导出').fontSize(LABEL_LARGE).fontColor('#101116').textAlign(TextAlign.Center)
            .layoutWeight(1).padding({ top: 12, bottom: 12 }).backgroundColor('#B9C6FF').borderRadius(14)
            .margin({ left: 10 }).onClick(async () => { await this.runExport(); })
        }.width('100%').margin({ top: 20 })
      }
    }.width('100%')
  }

  @Builder
  private GroupSelectContent() {
    Column() {
      Text('移入分组').fontSize(TITLE_LARGE).fontWeight(FontWeight.Medium).fontColor('#ECEEF2')
        .width('100%').margin({ bottom: 8 })
      if (this.preselectedGroupName.length > 0) {
        Text(`当前预选：${this.preselectedGroupName}`).fontSize(BODY_SMALL)
          .fontColor(this.themeColorTextTertiary).width('100%')
      }
      ForEach(this.moveGroupOptions(), (name: string) => {
        Row() {
          Text(name).fontSize(TITLE_SMALL).fontWeight(FontWeight.Bold).fontColor(this.themeColorTextPrimary).layoutWeight(1)
          if (name === (this.preselectedGroupName.length > 0 ? this.preselectedGroupName : '无分组')) {
            AppGlyph({ name: 'profileCheck', glyphSize: 16, tint: this.themeColorAccent })
          }
        }.width('100%').padding({ top: 10, bottom: 10 })
          .onClick(() => this.applyGroup(name === '无分组' ? '' : name))
      }, (name: string) => name)
      Text('取消').fontSize(LABEL_LARGE).fontColor('#C5C7D0').textAlign(TextAlign.Center)
        .width('100%').padding({ top: 12, bottom: 12 }).backgroundColor('#2A2B33').borderRadius(14)
        .margin({ top: 12 }).onClick(() => this.showGroupSelect = false)
    }.width('100%')
  }

  @Builder
  private SegmentedExportSheetContent() {
    Column() {
      Text('分段导出').fontSize(TITLE_LARGE).fontWeight(FontWeight.Medium).fontColor('#ECEEF2')
        .width('100%')
      Text(this.segmentedExportBook !== undefined ? this.segmentedExportBook.title : '')
        .fontSize(BODY_SMALL).fontColor(this.themeColorTextTertiary).width('100%').margin({ top: 4 })
      Text('章节范围').fontSize(LABEL_MEDIUM).fontColor(this.themeColorTextSecondary)
        .width('100%').margin({ top: 14 })
      TextInput({ placeholder: '如 1-10,15,20-22', text: this.segmentedScope })
        .height(44).width('100%').backgroundColor('#2A2B33').borderRadius(12)
        .fontColor('#ECEEF2').margin({ top: 6 })
        .onChange((value: string) => this.segmentedScope = value)
      Text('范围从 1 开始，逗号分隔多段，段内用 - 连起止。').fontSize(LABEL_SMALL)
        .fontColor(this.themeColorTextTertiary).width('100%').margin({ top: 4 })
      Text('每卷章节数').fontSize(LABEL_MEDIUM).fontColor(this.themeColorTextSecondary)
        .width('100%').margin({ top: 14 })
      TextInput({ placeholder: '1', text: this.segmentedVolumeSize })
        .height(44).width('100%').backgroundColor('#2A2B33').borderRadius(12)
        .fontColor('#ECEEF2').type(InputType.Number).margin({ top: 6 })
        .onChange((value: string) => this.segmentedVolumeSize = value)
      Row() {
        Text('取消').fontSize(LABEL_LARGE).fontColor('#C5C7D0').textAlign(TextAlign.Center)
          .layoutWeight(1).padding({ top: 12, bottom: 12 }).backgroundColor('#2A2B33').borderRadius(14)
          .onClick(() => this.showSegmentedExport = false)
        Text('导出').fontSize(LABEL_LARGE).fontColor('#101116').textAlign(TextAlign.Center)
          .layoutWeight(1).padding({ top: 12, bottom: 12 }).backgroundColor('#B9C6FF').borderRadius(14)
          .margin({ left: 10 }).onClick(() => this.runSegmentedExport())
      }.width('100%').margin({ top: 20 })
    }.width('100%')
  }

  /** 同一组件只挂一个 bindSheet，按状态分发内容（批3 同款，避免多个 bindSheet 只有最后生效）。 */
  @Builder
  private ManageSheet() {
    Column() {
      if (this.showDeleteConfirm) {
        this.DeleteConfirmContent()
      } else if (this.showExportSheet) {
        this.ExportSheetContent()
      } else if (this.showSegmentedExport) {
        this.SegmentedExportSheetContent()
      } else if (this.showGroupSelect) {
        this.GroupSelectContent()
      } else if (this.showLogSheet) {
        this.LogSheetContent()
      }
    }.width('100%').padding({ left: 20, right: 20, top: 8, bottom: 24 })
  }

  /**
   * 批2（:457）：日志面板。内容与书架页 BookshelfPage.ets:2228 的 LogSheetContent 同源
   * （都读 AppLog 的内存环形缓冲），两处看到的是同一批行，这是有意的设计。
   */
  @Builder
  private LogSheetContent() {
    Column() {
      Row() {
        Text('日志').fontSize(TITLE_LARGE).fontWeight(FontWeight.Bold).fontColor(this.themeColorTextPrimary)
        Blank()
        Text('清空').fontSize(LABEL_LARGE).fontColor(this.themeColorAccent).padding(6)
          .onClick(() => { AppLog.clear(); this.logEntries = []; })
      }.width('100%').padding({ top: 8, bottom: 12 })
      if (this.logEntries.length === 0) {
        Column() {
          Text('暂无日志').fontSize(LABEL_LARGE).fontColor(this.themeColorTextTertiary)
        }.width('100%').height(240).justifyContent(FlexAlign.Center)
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
            }.padding({ top: 12, bottom: 12 })
          }, (entry: AppLogEntry) => `${entry.timestamp}:${entry.message.length}`)
        }.width('100%').height(440).scrollBar(BarState.Off)
      }
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
          TextInput({ text: this.searchKey, placeholder: '筛选书名/作者' })
            .layoutWeight(1).height(40).fontSize(TITLE_SMALL)
            .onChange((value: string) => this.searchKey = value)
          Text('清除').fontSize(BODY_SMALL).fontColor(this.themeColorAccent)
            .onClick(() => this.searchKey = '')
        }.width('100%').padding({ left: 16, right: 16 })
      }
      Scroll(this.listScroller) {
        Column() {
          ForEach(this.filteredBooks(), (book: Book) => {
            this.BookRow(book)
          }, (book: Book) => this.rowKey(book))
          if (this.filteredBooks().length === 0) {
            Text('没有符合条件的书籍').fontSize(TITLE_SMALL).fontColor(this.themeColorTextSecondary)
              .width('100%').textAlign(TextAlign.Center).margin({ top: 60 })
          }
        }.width('100%')
      }.edgeEffect(EdgeEffect.Spring, { alwaysEnabled: false }).layoutWeight(1).scrollBar(BarState.Off)
      if (this.selectionMode) {
        Row() {
          Text(this.selectionTitle()).fontSize(BODY_SMALL).fontColor('#DCDDE4').layoutWeight(1)
          Text('操作').fontSize(BODY_SMALL).fontColor('#C4D1FF')
            .padding({ left: 10, right: 10, top: 5, bottom: 5 }).borderRadius(8)
            .backgroundColor(this.themeColorSurfaceElevated)
            .onClick(() => { this.selectionMenuVisible = !this.selectionMenuVisible; })
            .bindPopup(this.selectionMenuVisible, {
              builder: this.SelectionMenu,
              placement: Placement.BottomRight,
              popupColor: '#00000000',
              enableArrow: false,
              autoCancel: true,
              width: MANAGE_MENU_WIDTH,
              onStateChange: (event: PopupStateChangeParam) => { this.selectionMenuVisible = event.isVisible; }
            })
          Text('完成').fontSize(BODY_SMALL).fontColor('#C4D1FF')
            .padding({ left: 10, right: 10, top: 5, bottom: 5 }).borderRadius(8)
            .backgroundColor(this.themeColorSurfaceElevated)
            .onClick(() => this.clearSelection())
        }.width('100%').padding({ left: 16, right: 16, top: 8, bottom: 8 })
      }
    }.width('100%').height('100%').backgroundColor(this.themeColorSurfacePrimary)
      .bindSheet(this.showDeleteConfirm || this.showExportSheet || this.showGroupSelect || this.showLogSheet ||
        this.showSegmentedExport,
        this.ManageSheet(), {
          height: SheetSize.FIT_CONTENT, dragBar: true, showClose: false, backgroundColor: this.themeColorSurfaceTertiary,
          onDisappear: () => {
            this.showDeleteConfirm = false;
            this.showExportSheet = false;
            this.showGroupSelect = false;
            this.showLogSheet = false;
            this.showSegmentedExport = false;
          }
        })
  }
}
