import { UiSwitchControl } from '../components/UiSwitchControl';
import { UiMenuItem, UiMenuPanel } from '../components/UiMenu';
import { Book } from '../model/Book';
import { BookGroup } from '../model/BookGroup';
import { BookRepository } from '../data/BookRepository';
import { LocalBookRestorePlanner } from '../data/LocalBookRestorePlanner';
import { AppGlyph } from '../components/AppGlyph';
import { AppLog } from '../lib/AppLog';
import { ChapterDownloadQueue, DownloadState } from '../bookSource/ChapterDownloadQueue';
import { fileIo, picker } from '@kit.CoreFileKit';
import { util } from '@kit.ArkTS';
import { Context } from '@kit.AbilityKit';
import { BODY_SMALL, LABEL_LARGE, LABEL_MEDIUM, LABEL_SMALL, TITLE_LARGE, TITLE_MEDIUM, TITLE_SMALL, TITLE_SMALL_EMPHASIZED, TITLE_SMALL_LINE_HEIGHT } from '../components/typography/TypographyTokens';

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

  @StorageProp('themeColorTextPrimary') themeColorTextPrimary: string = '#F1F2F6';
  @StorageProp('themeColorTextSecondary') themeColorTextSecondary: string = '#AEB0BA';
  @StorageProp('themeColorTextTertiary') themeColorTextTertiary: string = '#858792';
  @StorageProp('themeColorAccent') themeColorAccent: string = '#B9C6FF';
  @StorageProp('themeColorSurfacePrimary') themeColorSurfacePrimary: string = '#17181E';
  @StorageProp('themeColorSurfaceElevated') themeColorSurfaceElevated: string = '#23242C';
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
  @State exportCharset: string = 'UTF-8';
  @State exportCustomCharset: string = '';
  @State exportFileNameTemplate: string = '{title}';
  @State exportWithChapterName: boolean = true;
  @State showGroupSelect: boolean = false;
  /** 批2（:471）：分段导出的输入与目标书。 */
  @State showSegmentedExport: boolean = false;
  @State segmentedExportBook: Book | undefined = undefined;
  @State segmentedScope: string = '1-';
  @State segmentedVolumeSize: string = '1';
  // 四个卡片式菜单的显隐状态，各自独立，避免互相顶掉。
  @State groupFilterVisible: boolean = false;
  @State moreMenuVisible: boolean = false;
  @State selectionMenuVisible: boolean = false;
  @State exportCharsetVisible: boolean = false;
  @State groupSelectBookKeys: string[] = [];
  @State preselectedGroupName: string = '';
  @State rowMenuKey: string = '';
  /** 批2（:457）：日志面板显隐；内容取 AppLog 内存缓冲快照。 */
  @State showLogSheet: boolean = false;
  @State logEntries: string[] = [];
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

  /** 模板占位符 {title}/{author}/{index}；空模板回落 {title}。 */
  private exportFileName(book: Book, index: number): string {
    const template = this.exportFileNameTemplate.trim().length > 0
      ? this.exportFileNameTemplate.trim() : '{title}';
    const name = template
      .replace(/\{title\}/g, book.title)
      .replace(/\{author\}/g, book.author.length > 0 ? book.author : '未知作者')
      .replace(/\{index\}/g, String(index + 1));
    const safe = name.replace(/[\/\\:*?"<>|]/g, '_');
    return safe.endsWith('.txt') ? safe : safe + '.txt';
  }

  private exportCharsetValue(): string {
    return this.exportCustomCharset.trim().length > 0 ? this.exportCustomCharset.trim() : this.exportCharset;
  }

  /**
   * 按指定字符集导出文本。utf-8 走字符串直写（全仓既有写法）；
   * 其它字符集用 TextEncoder 编成 ArrayBuffer 再写：SDK 的 writeSync 收
   * ArrayBuffer | string，直接把 Uint8Array 传进去在模拟器上会报 13900020（EINVAL）。
   * 当前 SDK 不支持的字符集编码失败时回落字符串直写，避免整批导出中断。
   */
  private async saveExportText(context: Context, fileName: string, content: string,
                               charset: string): Promise<boolean> {
    const options = new picker.DocumentSaveOptions();
    options.newFileNames = [fileName];
    options.fileSuffixChoices = ['TXT 文本|.txt'];
    const uris = await new picker.DocumentViewPicker(context).save(options);
    const uri = uris[0];
    if (uri === undefined) { return false; }
    const target = fileIo.openSync(uri, fileIo.OpenMode.WRITE_ONLY | fileIo.OpenMode.TRUNC);
    try {
      const normalized = charset.trim().toLowerCase();
      if (normalized.length === 0 || normalized === 'utf-8' || normalized === 'utf8') {
        fileIo.writeSync(target.fd, content);
      } else {
        let buffer: ArrayBuffer | undefined = undefined;
        try {
          const encoded: Uint8Array = util.TextEncoder.create(charset.trim()).encodeInto(content);
          buffer = encoded.buffer as ArrayBuffer;
        } catch (error) {
          buffer = undefined;
        }
        if (buffer !== undefined) { fileIo.writeSync(target.fd, buffer); }
        else { fileIo.writeSync(target.fd, content); }
      }
    } finally {
      fileIo.closeSync(target);
    }
    return true;
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
    this.showExportSheet = false;
    const total = this.exportBooks.length;
    for (let i = 0; i < total; i++) {
      const book = this.exportBooks[i];
      if (book === undefined) { continue; }
      const key = this.rowKey(book);
      this.putExportMsg(key, `第 ${i + 1} / 共 ${total} 本，正在选择保存位置…`);
      const body = BookRepository.readBookContentForPreview(book);
      if (body.length === 0) {
        this.putExportMsg(key, '没有可导出的纯文本正文');
        continue;
      }
      // 上游「导出包含章节名」控制是否插章节标题行；本地整本导出时章节名本就在正文里，
      // 这个开关只额外加一行书名/作者抬头（:468）。
      const header = this.exportWithChapterName ? `${book.title}\n${book.author}\n\n` : '';
      let message = '已导出';
      try {
        const saved = await this.saveExportText(context, this.exportFileName(book, i),
          header + body, this.exportCharsetValue());
        if (!saved) { message = '已取消'; }
      } catch (error) {
        message = '导出失败';
      }
      this.putExportMsg(key, message);
    }
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

  private exportCharsetItems(): UiMenuItem[] {
    return ['UTF-8', 'GBK', 'GB2312', 'GB18030', 'Big5', 'UTF-16'].map((charset: string): UiMenuItem => {
      return { key: charset, title: charset, selected: charset === this.exportCharset };
    });
  }

  @Builder
  private ExportCharsetMenu() {
    UiMenuPanel({
      items: this.exportCharsetItems(),
      panelWidth: MANAGE_MENU_WIDTH,
      onSelect: (key: string) => {
        this.exportCharsetVisible = false;
        this.exportCharset = key;
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

  @Builder
  private ExportSettingsContent() {
    Column() {
      Row() {
        Text('导出格式').fontSize(TITLE_SMALL_EMPHASIZED).fontColor(this.themeColorTextPrimary).layoutWeight(1)
        Text('TXT（EPUB 打包器未接入）').fontSize(BODY_SMALL).fontColor(this.themeColorTextTertiary)
      }.width('100%').padding({ top: 8, bottom: 8 })
      Row() {
        Text('导出字符集').fontSize(TITLE_SMALL_EMPHASIZED).fontColor(this.themeColorTextPrimary).layoutWeight(1)
        Text(this.exportCharset).fontSize(LABEL_MEDIUM).fontColor(this.themeColorAccent)
          .onClick(() => { this.exportCharsetVisible = !this.exportCharsetVisible; })
          .bindPopup(this.exportCharsetVisible, {
            builder: this.ExportCharsetMenu,
            placement: Placement.BottomRight,
            popupColor: '#00000000',
            enableArrow: false,
            autoCancel: true,
            width: MANAGE_MENU_WIDTH,
            onStateChange: (event: PopupStateChangeParam) => { this.exportCharsetVisible = event.isVisible; }
          })
      }.width('100%').padding({ top: 8, bottom: 8 })
      Row() {
        Text('自定义字符集').fontSize(TITLE_SMALL_EMPHASIZED).fontColor(this.themeColorTextPrimary).width(110)
        TextInput({ text: this.exportCustomCharset, placeholder: '留空用上面选的字符集' })
          .layoutWeight(1).height(36).fontSize(LABEL_MEDIUM)
          .onChange((value: string) => this.exportCustomCharset = value)
      }.width('100%').padding({ top: 8, bottom: 8 })
      Row() {
        Text('导出文件名').fontSize(TITLE_SMALL_EMPHASIZED).fontColor(this.themeColorTextPrimary).width(110)
        TextInput({ text: this.exportFileNameTemplate, placeholder: '{title}' })
          .layoutWeight(1).height(36).fontSize(LABEL_MEDIUM)
          .onChange((value: string) => this.exportFileNameTemplate = value)
      }.width('100%').padding({ top: 8, bottom: 8 })
      Text('占位符：{title} {author} {index}，空模板回落 {title}')
        .fontSize(LABEL_SMALL).fontColor(this.themeColorTextTertiary).width('100%')
      Row() {
        Text('导出包含章节名').fontSize(TITLE_SMALL_EMPHASIZED).fontColor(this.themeColorTextPrimary).layoutWeight(1)
        UiSwitchControl({
          checked: this.exportWithChapterName,
          interactive: false,
          onChange: (value: boolean) => this.exportWithChapterName = value
        })
      }.width('100%').padding({ top: 8, bottom: 8 })
        .onClick(() => this.exportWithChapterName = !this.exportWithChapterName)
    }.width('100%')
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
          ForEach(this.logEntries, (line: string) => {
            ListItem() {
              Text(line).fontSize(LABEL_SMALL).fontColor(this.themeColorTextSecondary)
                .fontFamily('monospace').width('100%')
            }.padding({ top: 4, bottom: 4 })
          }, (line: string) => line)
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
          height: SheetSize.FIT_CONTENT, dragBar: true, showClose: false, backgroundColor: '#17181E',
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
