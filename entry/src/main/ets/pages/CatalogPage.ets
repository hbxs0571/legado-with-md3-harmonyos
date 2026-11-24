import { UiMenuItem, UiMenuPanel } from '../components/UiMenu';
import { Book, BookChapter, displayIntroOf } from '../model/Book';
import { ReaderBookmark } from '../model/ReaderBookmark';
import { ReaderMarking } from '../model/ReaderMarking';
import { BookCover } from '../components/BookCover';
import { AppGlyph, AppGlyphName } from '../components/AppGlyph';
import { BookRepository } from '../data/BookRepository';
import { ChapterDownloadQueue, DownloadState } from '../bookSource/ChapterDownloadQueue';
import { ReplaceRuleRepository } from '../data/ReplaceRuleRepository';
import { BODY_SMALL, BODY_SMALL_LINE_HEIGHT, LABEL_LARGE, LABEL_MEDIUM, LABEL_MEDIUM_LINE_HEIGHT, LABEL_SMALL, TITLE_SMALL, TITLE_SMALL_LINE_HEIGHT } from '../components/typography/TypographyTokens';

/** 卡片式菜单的统一宽度，与书架页、详情页同口径。 */
const CATALOG_MENU_WIDTH: number = 260;

interface CatalogChapter {
  title: string;
  index: number;
  isVolume: boolean;
  isInVolume: boolean;
  /** 目录层级：卷标题 0、卷内章节 1，与上游 `tocLevel` 同口径，用于多级缩进。 */
  tocLevel: number;
  /**
   * 本章字数，直接取自 chapters 表的 `wordCount` 预存字段（切章时已算好），
   * 对齐上游 `BookChapter.wordCount`——目录页永不读正文。空串表示该章没有预存字数。
   */
  wordCount: string;
}

/**
 * 目录列表的惰性数据源。
 *
 * 对齐上游 `TocScreen.kt:763` 的 `FastScrollLazyColumn` + 逐项 `item(key =)`：
 * 屏幕外的行不组合，滚动时只组合进入视口的那些行。原来用 `ForEach` 一次性组合
 * 全部章节，1378 章的书一打开就要给每一章建节点，滑动自然卡。
 *
 * 数据只在 `rebuildChapterView()` 里整批换一次（`onDataReloaded()`），
 * 不做逐帧重算——对齐上游 `TocViewModel.filterData` 是 `uiState` 派生值、
 * 不是每次读取都重算。
 */
class CatalogChapterDataSource implements IDataSource {
  private items: CatalogChapter[] = [];
  private listeners: DataChangeListener[] = [];

  totalCount(): number {
    return this.items.length;
  }

  getData(index: number): CatalogChapter {
    return this.items[index];
  }

  registerDataChangeListener(listener: DataChangeListener): void {
    if (this.listeners.indexOf(listener) < 0) { this.listeners.push(listener); }
  }

  unregisterDataChangeListener(listener: DataChangeListener): void {
    const position = this.listeners.indexOf(listener);
    if (position >= 0) { this.listeners.splice(position, 1); }
  }

  /** 整批换数据：通知所有监听者重新读取，而不是逐项 diff。 */
  setItems(items: CatalogChapter[]): void {
    this.items = items;
    this.listeners.forEach((listener: DataChangeListener) => listener.onDataReloaded());
  }
}

@Component
export struct CatalogPage {
  @StorageProp('themeColorTextPrimary') themeColorTextPrimary: string = '#1B1C22';
  @StorageProp('themeColorTextSecondary') themeColorTextSecondary: string = '#2E3038';
  @StorageProp('themeColorTextTertiary') themeColorTextTertiary: string = '#6A6D77';
  @StorageProp('themeColorAccent') themeColorAccent: string = '#3F5BD9';
  @StorageProp('themeColorSurfaceSecondary') themeColorSurfaceSecondary: string = '#FFFFFF';
  @StorageProp('themeColorSurfaceTertiary') themeColorSurfaceTertiary: string = '#F0F1F5';
  @StorageProp('themeColorSurfaceElevated') themeColorSurfaceElevated: string = '#FFFFFF';
  @Prop book: Book = {
    id: '', title: '', author: '', category: '', lastChapter: '', progress: 0, isLocal: true
  };
  @Prop selectedChapter: string = '';
  @Prop bookmarks: ReaderBookmark[] = [];
  @Prop markings: ReaderMarking[] = [];
  @Prop @Watch('onChapterViewInputChanged') useTitleReplacement: boolean = false;
  @Prop showWordCount: boolean = true;
  /**
   * 批2（TXT:480）：目录跳转加载态。Index 在 readChapter 期间置真，
   * 否则点章节到正文出现之间的空档看起来像「点了没反应」。
   */
  @Prop chapterLoading: boolean = false;
  /**
   * 批2（TXT:343）：每章的下载状态，键是章节下标。
   * 与书架卡、缓存页同源（ChapterDownloadQueue.subscribe），三处一起变才是「同一份状态」。
   */
  @State chapterDownloadStates: Map<number, DownloadState> = new Map<number, DownloadState>();
  @State @Watch('onChapterViewInputChanged') ascending: boolean = true;
  @State selectedTab: number = 1;
  @State @Watch('onChapterViewInputChanged') query: string = '';
  /** 书签/笔记页共用的搜索词，对应上游 `TocActionState.searchKey`。 */
  @State markQuery: string = '';
  /** 目录行的派生结果：按搜索词、折叠态、排序算一次，绘制时直接读。 */
  @State chapterView: CatalogChapter[] = [];
  /** 目录行的惰性数据源，与 chapterView 同步整批替换。 */
  private chapterDataSource: CatalogChapterDataSource = new CatalogChapterDataSource();
  /** 已折叠的卷头章节下标。 */
  @State @Watch('onChapterViewInputChanged') collapsedVolumes: Set<number> = new Set<number>();
  /** 吸顶显示的卷名；空串表示不显示。对齐上游 `stickyVolume`。 */
  @State stickyVolumeTitle: string = '';
  /** 列表首个可见项下标，吸顶判定要用。 */
  private stickyFirstVisibleIndex: number = 0;
  /** 首个可见项已滚出的距离，用于判断卷头是否已滚出 24vp。 */
  private stickyVolumeScrollOffset: number = 0;
  private chapterScroller: Scroller = new Scroller();
  /** 书签列表滚动器，用于打开时定位到当前章节。 */
  private bookmarkScroller: Scroller = new Scroller();
  private hasAutoScrolledCurrentChapter: boolean = false;
  /** 书签列表只自动定位一次，之后由用户自己滚动。 */
  private hasAutoScrolledBookmarks: boolean = false;
  onBack: () => void = () => {};
  onSelectChapter: (chapterIndex: number) => void = () => {};
  /** 上游书封/书名点击进书籍详情（`ReaderBookSheet.kt` 的 combinedClickable）。 */
  onOpenBookInfo: () => void = () => {};
  onOpenBookmark: (bookmarkId: string) => void = (_bookmarkId: string) => {};
  onEditBookmark: (bookmarkId: string) => void = (_bookmarkId: string) => {};
  onOpenMarking: (markingId: string) => void = (_markingId: string) => {};
  onEditMarking: (markingId: string) => void = (_markingId: string) => {};
  onTitleReplacementChange: (enabled: boolean) => void = (_enabled: boolean) => {};
  onShowWordCountChange: (enabled: boolean) => void = (_enabled: boolean) => {};
  /** 导出本书书签；isMarkdown 为 true 时导出 Markdown，否则导出 JSON。 */
  onExportBookmarks: (isMarkdown: boolean) => void = (_isMarkdown: boolean) => {};
  /** 重新识别当前书的目录，对应上游目录页「更新目录」。 */
  onRefreshToc: () => void = () => {};
  /** 打开替换净化规则管理，对应上游目录页「替换规则」。 */
  onOpenReplaceRules: () => void = () => {};
  /** 打开本地 TXT 目录规则，对应上游目录页「本地书籍选项 · 目录规则」。 */
  onOpenTxtTocRules: () => void = () => {};
  onUnavailableAction: (message: string) => void = (_message: string) => {};
  /** 批量为选中的章节各加一条书签，对应上游多选浮层的「加书签」。 */
  onAddBookmarksForChapters: (chapterIndexes: number[]) => void = (_indexes: number[]) => {};

  /** 多选模式：长按章节行进入，选中项显示勾选圈。 */
  @State selectionMode: boolean = false;
  // 三个卡片式菜单的显隐状态。
  @State catalogMoreVisible: boolean = false;
  @State chapterSelectionVisible: boolean = false;
  @State bookmarkExportVisible: boolean = false;
  /** 已选中的章节下标（对应 `chapterRows` 下标）。 */
  @State selectedChapterIndexes: Set<number> = new Set<number>();
  /** 多选浮层是否展开（对齐上游 `fabExpanded`）。 */
  @State selectionMenuExpanded: boolean = false;

  /** 目录行，打开页面时从 chapters 表读一次；章节已不在 Book 上。 */
  @State chapterRows: BookChapter[] = [];

  private downloadUnsubscribe: (() => void) | undefined = undefined;

  aboutToAppear(): void {
    // 只读章节行：字数在切章时已经写进 chapters 表的 wordCount 字段，
    // 目录页不再逐章读正文重算（上游 BookChapter.wordCount 同口径）。
    this.loadChapterRows();
    this.downloadUnsubscribe = ChapterDownloadQueue.subscribe(() => this.refreshChapterDownloadStates());
    this.refreshChapterDownloadStates();
  }

  aboutToDisappear(): void {
    if (this.downloadUnsubscribe !== undefined) {
      this.downloadUnsubscribe();
      this.downloadUnsubscribe = undefined;
    }
  }

  /** 批2（TXT:343）：把队列里每章的档位摊成 Map，整表换新才触发列表刷新。 */
  private refreshChapterDownloadStates(): void {
    if (!BookRepository.isOnlineBook(this.book)) {
      if (this.chapterDownloadStates.size > 0) {
        this.chapterDownloadStates = new Map<number, DownloadState>();
      }
      return;
    }
    const bookUrl = this.book.contentPath ?? this.book.androidOriginalPath ?? '';
    const next = new Map<number, DownloadState>();
    this.chapterRows.forEach((row: BookChapter) => {
      const state = ChapterDownloadQueue.chapterState(bookUrl, row.index);
      if (state !== 'idle') {
        next.set(row.index, state);
      }
    });
    this.chapterDownloadStates = next;
  }

  private chapterDownloadStateOf(chapterIndex: number): DownloadState {
    return this.chapterDownloadStates.get(chapterIndex) ?? 'idle';
  }

  /** 图标的读屏文案，与缓存页、书架卡同一套六档措辞。 */
  private chapterDownloadLabel(chapterIndex: number): string {
    const state = this.chapterDownloadStateOf(chapterIndex);
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
      return '下载失败';
    }
    return '未下载';
  }

  /** 点图标：空闲/失败/完成 → 只把这章入队；排队中/下载中 → 停整本（队列按书停，没有单章取消）。 */
  private toggleChapterDownload(chapterIndex: number): void {
    const bookUrl = this.book.contentPath ?? this.book.androidOriginalPath ?? '';
    const state = this.chapterDownloadStateOf(chapterIndex);
    if (state === 'queued' || state === 'running') {
      ChapterDownloadQueue.stop(bookUrl);
      this.refreshChapterDownloadStates();
      return;
    }
    const row = this.chapterRows.find((item: BookChapter) => item.index === chapterIndex);
    if (row === undefined) {
      return;
    }
    ChapterDownloadQueue.enqueue(this.book, [row]);
    this.refreshChapterDownloadStates();
  }

  private async loadChapterRows(): Promise<void> {
    const context = this.getUIContext().getHostContext();
    if (context === undefined) { return; }
    try {
      this.chapterRows = await BookRepository.loadChapters(context, this.book);
    } catch (error) {
      this.chapterRows = [];
      this.onUnavailableAction(`目录加载失败：${error instanceof Error ? error.message : `${error}`}`);
      return;
    }
    // 在线目录失败时 loadChapters 静默返回空数组，靠 lastTocError 区分「加载失败」
    // 与「真的没有目录」，避免把网络错误误报成「这本书没有目录」（:314）。
    if (BookRepository.lastTocError.length > 0) {
      this.onUnavailableAction(`目录加载失败：${BookRepository.lastTocError}`);
    }
    this.rebuildChapterView();
    // 章节行到位后才有下标可比，补算一次下载状态（TXT:343）。
    this.refreshChapterDownloadStates();
  }

  private getAllChapters(): string[] {
    const titles: string[] = [];
    this.chapterRows.forEach((row: BookChapter) => {
      titles.push(row.title);
    });
    return titles;
  }

  /**
   * 重算目录行：只在「章节行变了 / 搜索词变了 / 折叠态变了 / 排序变了」时调一次。
   *
   * 原来是 `getChapters()` 在 `build()` 里被调用两次、且在吸顶判定与滚动定位里各调一次，
   * 每一次都要对全书跑一遍标题替换正则 + 过滤 + 逆序，等于每帧重算一遍整张表——
   * 这就是「目录滑动卡」的主因。对齐上游 `TocViewModel.filterData`：
   * 它是 `uiState` 的派生值，输入不变就不重算。
   */
  private rebuildChapterView(): void {
    const keyword = this.query.trim();
    const rows = this.chapterRows;
    const chapters: CatalogChapter[] = [];
    const searching = keyword.length > 0;
    let insideCollapsedVolume = false;
    for (let index = 0; index < rows.length; index++) {
      const row = rows[index];
      if (row === undefined) { continue; }
      const isVolume = row.isVolume;
      if (!searching) {
        if (isVolume) { insideCollapsedVolume = this.collapsedVolumes.has(index); }
        else if (insideCollapsedVolume) { continue; }
      }
      const displayTitle = this.useTitleReplacement ? ReplaceRuleRepository.applyTitle(this.book, row.title) : row.title;
      // 搜索时卷名永远保留（上游 TocViewModel.filterData：`it.displayTitle.contains(key, true) || it.chapter.isVolume`），
      // 否则搜卷内某一章时，结果里看不出这章属于哪一卷。
      // 忽略大小写同样对齐上游的 `contains(key, true)`，英文书名/章节名才搜得到。
      const matched = displayTitle.toLowerCase().includes(keyword.toLowerCase());
      if (matched || (searching && isVolume)) {
        chapters.push({ title: displayTitle, index: index, isVolume: isVolume,
          isInVolume: !isVolume && this.isInsideAnyVolume(index, rows),
          tocLevel: row.tocLevel,
          // 预存字段直接用，不在这里读正文：上游 BookChapter.wordCount 同口径。
          wordCount: row.wordCount ?? '' });
      }
    }
    if (this.ascending) {
      this.setChapterView(chapters);
      return;
    }
    this.setChapterView(this.reverseTocHierarchy(chapters, rows));
  }

  /**
   * 逆序：保「父在子前」。
   *
   * 上游 `TocHierarchy.kt:56-86` 的 `reverseTocHierarchy()` 是先把章节按卷分组、
   * 整组倒排、组内章节再倒排，所以倒序后卷标题仍排在它的子章之前。
   * 原来只把整个数组 `for (i = len-1; i >= 0; i--)` 翻一遍，卷标题会掉到子章后面。
   */
  private reverseTocHierarchy(chapters: CatalogChapter[], rows: BookChapter[]): CatalogChapter[] {
    const reversed: CatalogChapter[] = [];
    let volumeHead: CatalogChapter | undefined = undefined;
    let buffer: CatalogChapter[] = [];
    const flush = (): void => {
      if (volumeHead !== undefined) { reversed.push(volumeHead); }
      for (let index = buffer.length - 1; index >= 0; index--) {
        const item = buffer[index];
        if (item !== undefined) { reversed.push(item); }
      }
      volumeHead = undefined;
      buffer = [];
    };
    for (let index = 0; index < chapters.length; index++) {
      const chapter = chapters[index];
      if (chapter === undefined) { continue; }
      if (chapter.isVolume) {
        flush();
        volumeHead = chapter;
        buffer = [];
        continue;
      }
      const row = rows[chapter.index];
      if (row !== undefined && row.isVolume) { flush(); }
      buffer.push(chapter);
    }
    flush();
    return reversed;
  }

  /** 写回派生结果并通知惰性列表整批刷新。 */
  private setChapterView(chapters: CatalogChapter[]): void {
    this.chapterView = chapters;
    this.chapterDataSource.setItems(chapters);
  }

  /**
   * 派生输入变了就重算一次目录行（搜索词 / 排序 / 折叠态 / 标题替换开关）。
   * 这样 `build()` 里可以直接读 `chapterView`，不再每帧调 `getChapters()`。
   */
  private onChapterViewInputChanged(): void {
    this.rebuildChapterView();
  }

  /** 卷内判断：往上找最近的一个卷标题，与上游 tocLevel 的语义一致。 */
  private isInsideAnyVolume(chapterIndex: number, rows: BookChapter[]): boolean {
    for (let index = chapterIndex - 1; index >= 0; index--) {
      if (rows[index]?.isVolume === true) { return true; }
    }
    return false;
  }

  private toggleVolume(chapterIndex: number): void {
    if (this.collapsedVolumes.has(chapterIndex)) { this.collapsedVolumes.delete(chapterIndex); }
    else { this.collapsedVolumes.add(chapterIndex); }
    this.collapsedVolumes = new Set<number>(this.collapsedVolumes);
  }

  /**
   * 当前阅读章节。上游 `ReaderBookSheet.kt:899-903` 把行背景分三档：
   * 多选选中 → `primaryContainer`、当前章 → `secondaryContainer`、其余 → `surfaceContainerLow`。
   * 本地没有 primaryContainer / secondaryContainer，降级用 `themeColorSurfaceElevated`
   * 与 `themeColorSurfaceTertiary` 两级（见 `data/ThemePalette.ets` 只有 10 个色字段）。
   */
  private isCurrentChapter(chapterIndex: number): boolean {
    const selectedIndex = this.book.chapterIndex ?? this.getAllChapters().indexOf(this.selectedChapter);
    return chapterIndex === selectedIndex;
  }

  /** 多选是否选中该章（与「当前阅读章」是两件事，别混用）。 */
  private isMarked(chapterIndex: number): boolean {
    return this.selectedChapterIndexes.has(chapterIndex);
  }

  /** 章节行三档背景色。 */
  private chapterRowBackground(chapterIndex: number): string {
    if (this.isMarked(chapterIndex)) { return this.themeColorSurfaceElevated; }
    if (this.isCurrentChapter(chapterIndex)) { return this.themeColorSurfaceTertiary; }
    return this.themeColorSurfaceSecondary;
  }

  /** 章节行三档文字色。 */
  private chapterRowForeground(chapterIndex: number): string {
    if (this.isMarked(chapterIndex) || this.isCurrentChapter(chapterIndex)) {
      return this.themeColorTextPrimary;
    }
    return this.themeColorTextSecondary;
  }

  private getTabLabel(index: number): string {
    if (index === 0) { return '信息'; }
    if (index === 1) { return '目录'; }
    if (index === 2) { return '书签'; }
    return '笔记';
  }

  /**
   * 笔记条目的 key 必须覆盖会变的展示字段，否则改完样式/备注后
   * ArkUI 复用旧节点，列表还显示「下划线」这类过期文案。
   */
  private markingItemKey(marking: ReaderMarking): string {
    return `${marking.id}_${marking.effect}_${marking.color}_${marking.note}_${marking.enabled ? 1 : 0}`;
  }

  /** 当前章节序号，口径与上游 `book.durChapterIndex` 一致。 */
  private getCurrentChapterIndex(): number {
    return this.book.chapterIndex ?? this.getAllChapters().indexOf(this.selectedChapter);
  }

  /** 上游 `item.isDur`：条目所属章节即当前阅读章节。 */
  private isCurrentChapterItem(chapterIndex: number): boolean {
    return chapterIndex === this.getCurrentChapterIndex();
  }

  /** 上游 `chapter_index_format` 的兜底章名：章名为空时显示「第 N 章」。 */
  private getChapterFallbackName(chapterIndex: number): string {
    return '第 ' + (chapterIndex + 1).toString() + ' 章';
  }

  /** 上游笔记条目第一行的创建时间 `yyyy-MM-dd HH:mm`。 */
  private formatCreatedTime(timestamp: number): string {
    const date = new Date(timestamp);
    if (!(date instanceof Date) || Number.isNaN(date.getTime())) { return ''; }
    const pad = (value: number): string => value < 10 ? '0' + value.toString() : value.toString();
    return date.getFullYear().toString() + '-' + pad(date.getMonth() + 1) + '-' + pad(date.getDate())
      + ' ' + pad(date.getHours()) + ':' + pad(date.getMinutes());
  }

  /**
   * 上游书签/笔记页共用的搜索词：只过滤当前页，不影响目录页的章节搜索。
   */
  private matchesBookmarkQuery(bookmark: ReaderBookmark): boolean {
    const keyword = this.markQuery.trim().toLowerCase();
    if (keyword.length === 0) { return true; }
    return bookmark.content.toLowerCase().includes(keyword);
  }

  private matchesMarkingQuery(marking: ReaderMarking): boolean {
    const keyword = this.markQuery.trim().toLowerCase();
    if (keyword.length === 0) { return true; }
    return marking.selectedText.toLowerCase().includes(keyword)
      || marking.note.toLowerCase().includes(keyword);
  }

  /**
   * 上游 `BookmarkDao.flowByBook` 按 `chapterIndex` 排序；同章内再按章内偏移，
   * 与「所有书签」页同一口径。本地存储顺序是新条目前插，与正文顺序无关，
   * 不排序会让首屏定位与「最后一个 chapterIndex <= 当前章节」的判断一起落错。
   */
  private getVisibleBookmarks(): ReaderBookmark[] {
    const matched = this.bookmarks.filter((bookmark: ReaderBookmark) => this.matchesBookmarkQuery(bookmark));
    return matched.sort((left: ReaderBookmark, right: ReaderBookmark) => {
      if (left.chapterIndex !== right.chapterIndex) { return left.chapterIndex - right.chapterIndex; }
      return left.chapterPosition - right.chapterPosition;
    });
  }

  /** 上游 `BookMarkingDao.flowByBook`：`order by chapterIndex, createdAt`。 */
  private getVisibleMarkings(): ReaderMarking[] {
    const matched = this.markings.filter((marking: ReaderMarking) => this.matchesMarkingQuery(marking));
    return matched.sort((left: ReaderMarking, right: ReaderMarking) => {
      if (left.chapterIndex !== right.chapterIndex) { return left.chapterIndex - right.chapterIndex; }
      return left.createdAt - right.createdAt;
    });
  }

  /**
   * 上游 `ReaderSheetBookmarkList` 的首次定位：滚到最后一个
   * `chapterIndex <= 当前章节` 的条目。
   */
  private scrollBookmarksToCurrentChapter(): void {
    if (this.hasAutoScrolledBookmarks) { return; }
    const visible = this.getVisibleBookmarks();
    if (visible.length === 0) { return; }
    const currentChapterIndex = this.getCurrentChapterIndex();
    if (currentChapterIndex < 0) { return; }
    let position = 0;
    for (let index = 0; index < visible.length; index++) {
      const bookmark = visible[index];
      if (bookmark !== undefined && bookmark.chapterIndex <= currentChapterIndex) { position = index; }
    }
    this.hasAutoScrolledBookmarks = true;
    setTimeout((): void => {
      this.bookmarkScroller.scrollToIndex(position, false);
    }, 100);
  }

  /**
   * 笔记条目属于其他书源时标红提示，对齐上游 `marks_other_source`：
   * `bookUrl.isNotBlank() && bookUrl != book?.bookUrl`。
   */
  private isMarkingFromOtherSource(marking: ReaderMarking): boolean {
    const currentSourceUrl = this.book.androidOriginalPath ?? this.book.contentPath ?? this.book.id;
    return marking.bookUrl.length > 0 && currentSourceUrl.length > 0 && marking.bookUrl !== currentSourceUrl;
  }

  private getSourceLabel(): string {
    if (!this.book.isLocal) { return '--'; }
    if (this.book.format === 'epub') { return '本地 EPUB'; }
    if (this.book.format === 'pdf') { return '本地 PDF'; }
    if (this.book.format === 'mobi') { return '本地 MOBI'; }
    if (this.book.format === 'umd') { return '本地 UMD'; }
    if (this.book.format === 'txt') { return '本地 TXT'; }
    return '本地';
  }

  /**
   * 信息页展示用的简介。上游 `ReaderBookSheet.kt:517-521` 先过 `HtmlFormatter.formatReadableText`：
   * 去 `<useweb>`/`<usehtml>`/`<md>` 前缀、丢掉 `@onclick:JS` 片段、剥 HTML 标签。
   * 本地没有 HtmlFormatter，这里做一个最小实现（剥标签 + 解常见实体 + 去三个前缀），
   * 与上游不等价，但比直接渲染带标签的原文好。
   */
  private displayIntro(): string {
    // 第九表 I-5：上游 `ReaderBookSheet.kt:515 val rawIntro = book?.getDisplayIntro()`，
    // 取的是「显示简介」（自定义简介优先）。本地原读 `description`（书源原值），
    // 用户在编辑页改写的简介在这里看不到。
    let text = displayIntroOf(this.book).trim();
    if (text.length === 0) { return ''; }
    text = text.replace(/^<(useweb|usehtml|md)>/i, '');
    text = text.replace(/@onclick:[^\s<>]*/gi, '');
    text = text.replace(/<[^>]*>/g, '');
    text = text.replace(/&nbsp;/g, ' ').replace(/&lt;/g, '<').replace(/&gt;/g, '>')
      .replace(/&amp;/g, '&').replace(/&quot;/g, '"');
    return text.trim();
  }

  private getCurrentChapterNumber(): number {
    const index = this.book.chapterIndex ?? this.getAllChapters().indexOf(this.selectedChapter);
    return index >= 0 ? index + 1 : 0;
  }

  private scrollToCurrentChapter(): void {
    if (this.selectedTab !== 1 || this.hasAutoScrolledCurrentChapter) { return; }
    const currentChapterIndex = this.book.chapterIndex ?? this.getAllChapters().indexOf(this.selectedChapter);
    const visibleIndex = this.chapterView.findIndex((chapter: CatalogChapter) =>
      chapter.index === currentChapterIndex);
    if (visibleIndex < 0) { return; }
    this.hasAutoScrolledCurrentChapter = true;
    setTimeout((): void => {
      this.chapterScroller.scrollToIndex(visibleIndex, false);
    }, 100);
  }

  private formatWordCount(wordCount: number): string {
    if (wordCount <= 0) { return ''; }
    if (wordCount > 10000) {
      return Number((wordCount / 10000).toFixed(1)).toString() + '万字';
    }
    return wordCount.toString() + '字';
  }

  /**
   * 切换字数显示。
   *
   * 上游这里只是改一个开关：字数本来就存在 `BookChapter.wordCount` 里，
   * 打开目录时不用为它做任何事。原来本地打开开关会触发 `loadChapterWordCounts()`
   * 把全书每章正文读一遍再 `content.length`——1378 章的书要 6 秒以上，
   * 这就是「打开目录慢」的根因。现在切换只改显示。
   */
  private toggleShowWordCount(): void {
    this.onShowWordCountChange(!this.showWordCount);
  }

  /**
   * 粘性卷头：对齐上游 `TocScreen.kt:270-295` 的 `stickyVolume`。
   *
   * 上游判定是「首个可见项不是卷标题」或「就是卷标题但已滚出 24」，
   * 且该卷未折叠时，才把卷名吸在列表顶部。ArkUI 的 List 没有内建 sticky header，
   * 这里用一层覆盖在列表上的浮层实现同样的观感。
   */
  private updateStickyVolume(firstVisibleIndex: number): void {
    if (this.selectedTab !== 1) { this.stickyVolumeTitle = ''; return; }
    const chapters = this.chapterView;
    if (firstVisibleIndex < 0 || firstVisibleIndex >= chapters.length) {
      this.stickyVolumeTitle = '';
      return;
    }
    const firstItem = chapters[firstVisibleIndex];
    if (firstItem === undefined) { this.stickyVolumeTitle = ''; return; }
    let volumeIndex = -1;
    if (firstItem.isVolume) {
      // 卷标题自己贴顶时，只有已经滚出 24vp 才显示浮层，否则会和列表里的那一行重叠成两层。
      if (this.stickyVolumeScrollOffset > 24) { volumeIndex = firstVisibleIndex; }
    } else {
      for (let index = firstVisibleIndex - 1; index >= 0; index--) {
        const candidate = chapters[index];
        if (candidate !== undefined && candidate.isVolume) { volumeIndex = index; break; }
      }
    }
    if (volumeIndex < 0) { this.stickyVolumeTitle = ''; return; }
    const volumeItem = chapters[volumeIndex];
    if (volumeItem === undefined || this.collapsedVolumes.has(volumeItem.index)) {
      this.stickyVolumeTitle = '';
      return;
    }
    this.stickyVolumeTitle = volumeItem.title;
  }

  /** 点击吸顶卷名滚回该卷开头。 */
  private scrollToStickyVolume(): void {
    const chapters = this.chapterView;
    const index = chapters.findIndex((chapter: CatalogChapter) => chapter.title === this.stickyVolumeTitle &&
      chapter.isVolume);
    if (index >= 0) { this.chapterScroller.scrollToIndex(index, true); }
  }
  /** 书签页「更多」菜单，对应上游 TocScreen 的书签导出两项。 */
  private bookmarkExportItems(): UiMenuItem[] {
    return [
      { key: 'json', title: '导出为 JSON' },
      { key: 'markdown', title: '导出为 Markdown' }
    ];
  }

  @Builder
  private BookmarkExportMenu() {
    UiMenuPanel({
      items: this.bookmarkExportItems(),
      panelWidth: CATALOG_MENU_WIDTH,
      onSelect: (key: string) => {
        this.bookmarkExportVisible = false;
        // JSON 与 Markdown 的布尔口径来自原 onClick 参数。
        this.onExportBookmarks(key === 'markdown');
      }
    })
  }

  /** 目录页「更多」菜单，对应上游 TocScreen 信息页那组菜单项。 */
  private catalogMoreItems(): UiMenuItem[] {
    // 条件项按原 if 分支顺序拼装，缺数据时不留空位。
    const items: UiMenuItem[] = [];
    if (this.isLocalTxt()) {
      items.push({ key: 'refresh_toc', title: '更新目录' });
    }
    items.push({ key: 'replace_rules', title: '替换规则' });
    if (this.book.isLocal) {
      items.push({ key: 'txt_toc_rules', title: '本地 TXT 目录规则' });
    }
    return items;
  }

  @Builder
  private CatalogMoreMenu() {
    UiMenuPanel({
      items: this.catalogMoreItems(),
      panelWidth: CATALOG_MENU_WIDTH,
      onSelect: (key: string) => {
        this.catalogMoreVisible = false;
        if (key === 'refresh_toc') {
          this.onRefreshToc();
        } else if (key === 'replace_rules') {
          this.onOpenReplaceRules();
        } else if (key === 'txt_toc_rules') {
          this.onOpenTxtTocRules();
        }
      }
    })
  }

  /** 当前书是否为可重新识别目录的本地 TXT。 */  private isLocalTxt(): boolean {
    return this.book.isLocal && this.book.format === 'txt' && this.book.contentPath !== undefined;
  }

  /** 长按章节行进入多选，并把该行选中（对齐上游 `ReaderBookSheet.kt:678-740` 的多选入口）。 */
  private enterSelectionMode(chapterIndex: number): void {
    this.selectionMode = true;
    const next = new Set<number>(this.selectedChapterIndexes);
    next.add(chapterIndex);
    this.selectedChapterIndexes = next;
  }

  private toggleChapterSelection(chapterIndex: number): void {
    const next = new Set<number>(this.selectedChapterIndexes);
    if (next.has(chapterIndex)) { next.delete(chapterIndex); } else { next.add(chapterIndex); }
    this.selectedChapterIndexes = next;
    if (next.size === 0) { this.selectionMode = false; }
  }

  private clearChapterSelection(): void {
    this.selectionMode = false;
    this.selectionMenuExpanded = false;
    this.selectedChapterIndexes = new Set<number>();
  }

  private selectAllChapters(): void {
    const next = new Set<number>();
    this.chapterView.forEach((chapter: CatalogChapter) => {
      if (!chapter.isVolume) { next.add(chapter.index); }
    });
    this.selectedChapterIndexes = next;
    this.selectionMode = next.size > 0;
  }

  private invertChapterSelection(): void {
    const next = new Set<number>();
    this.chapterView.forEach((chapter: CatalogChapter) => {
      if (!chapter.isVolume && !this.selectedChapterIndexes.has(chapter.index)) { next.add(chapter.index); }
    });
    this.selectedChapterIndexes = next;
    this.selectionMode = next.size > 0;
  }

  /**
   * 选择后续：把「已选里位置最靠后的那一章」之后的所有章加入选择。
   * 上游 TocViewModel.kt:794-800 selectFromLast 的三步：
   *   ① 取已选里 id 最大的（本地用 index，等价）
   *   ② 在当前显示顺序里找它的位置
   *   ③ 把它之后的全部加入（不取消前面已选的）
   * 顺序源必须是 chapterView（已过滤/可能逆序），不是 chapterRows。
   * 与上游一致：卷标题不进选择。
   */
  private selectFollowingChapters(): void {
    if (this.selectedChapterIndexes.size === 0) { return; }
    let maxSelectedIndex: number = -1;
    this.selectedChapterIndexes.forEach((index: number) => {
      if (index > maxSelectedIndex) { maxSelectedIndex = index; }
    });
    // 在显示顺序里定位：该章可能已被折叠/搜索过滤掉，找不到就不做。
    let position: number = -1;
    for (let i = 0; i < this.chapterView.length; i++) {
      const chapter = this.chapterView[i];
      if (chapter !== undefined && chapter.index === maxSelectedIndex) { position = i; break; }
    }
    if (position < 0) { return; }
    const next = new Set<number>();
    this.selectedChapterIndexes.forEach((index: number) => next.add(index));
    for (let i = position + 1; i < this.chapterView.length; i++) {
      const chapter = this.chapterView[i];
      if (chapter === undefined || chapter.isVolume) { continue; }
      next.add(chapter.index);
    }
    this.selectedChapterIndexes = next;
    this.selectionMode = next.size > 0;
  }

  /** 选中的章节各加一条书签，对齐上游 `TocIntent.AddBookmarksForSelected`。 */
  private addBookmarksForSelection(): void {
    const indexes: number[] = [];
    this.selectedChapterIndexes.forEach((index: number) => indexes.push(index));
    if (indexes.length === 0) { return; }
    indexes.sort((a: number, b: number) => a - b);
    this.onAddBookmarksForChapters(indexes);
    this.clearChapterSelection();
  }

  /**
   * 多选浮层。
   *
   * 上游 `ReaderBookSheet.kt:678-740` 的 `fabItems` 共 7 项：全选 / 反选 / 加书签 /
   * 下载选中 / 删除角色分配 / 删除朗读音频 / 取消选择。后三项属于下载与朗读链路，
   * 本地 TXT 离线阅读没有这两个功能，所以只保留其余四项；
   * 另补上游 TocViewModel.selectFromLast 的「选择后续」一项，共五项。
   */
  private chapterSelectionItems(): UiMenuItem[] {
    return [
      { key: 'select_all', title: '全选' },
      { key: 'invert', title: '反选' },
      { key: 'select_following', title: '选择后续' },
      { key: 'add_bookmark', title: `加书签（${this.selectedChapterIndexes.size}）` },
      { key: 'clear', title: '取消选择' }
    ];
  }

  @Builder
  private ChapterSelectionMenu() {
    UiMenuPanel({
      items: this.chapterSelectionItems(),
      panelWidth: CATALOG_MENU_WIDTH,
      onSelect: (key: string) => {
        this.chapterSelectionVisible = false;
        if (key === 'select_all') {
          this.selectAllChapters();
        } else if (key === 'invert') {
          this.invertChapterSelection();
        } else if (key === 'select_following') {
          this.selectFollowingChapters();
        } else if (key === 'add_bookmark') {
          this.addBookmarksForSelection();
        } else if (key === 'clear') {
          this.clearChapterSelection();
        }
      }
    })
  }

  /**
   * 目录页工具图标盒。上游 `CompactToolIconBox`：32dp 方盒、radius 10、
   * 选中态底色 `secondaryContainer`（本地降级 `themeColorSurfaceElevated`），
   * 图标本身 16-18dp 居中。原来本地是五个裸 AppGlyph，没有点击盒也没有选中底色。
   */
  @Builder
  private catalogToolBox(icon: AppGlyphName, active: boolean, action: () => void) {
    Stack({ alignContent: Alignment.Center }) {
      AppGlyph({ name: icon, glyphSize: 18,
        tint: active ? this.themeColorAccent : this.themeColorTextSecondary })
    }
    .width(32).height(32).borderRadius(10)
    .backgroundColor(active ? this.themeColorSurfaceElevated : Color.Transparent)
    .onClick(() => action())
    .accessibilityText(icon === 'profileFindReplace' ? '使用替换规则' : (icon === 'profileTimeline' ? '显示字数' : '反转目录'))
  }

  @Builder
  private CatalogTabPage(tab: number) {
    if (tab === 0) {
      // 上游 `ReaderBookSheet.kt:504-540 ReaderBookInformation`：四行（作者 / 书源 / 备注 / 简介），
      // `contentPadding(vertical = 8.dp)` + `Arrangement.spacedBy(8.dp)`，备注与简介为空时不占位。
      Scroll() {
        Column({ space: 8 }) {
          CatalogInformationRow({ label: '作者', value: this.book.author })
          CatalogInformationRow({ label: '书源', value: this.getSourceLabel() })
          if ((this.book.remark ?? '').trim().length > 0) {
            CatalogInformationRow({ label: '备注', value: this.book.remark ?? '' })
          }
          if (this.displayIntro().length > 0) {
            CatalogInformationRow({ label: '简介', value: this.displayIntro() })
          }
        }
        .width('100%')
        .padding({ top: 8, bottom: 8 })
      }.edgeEffect(EdgeEffect.Spring, { alwaysEnabled: false })
      .width('100%')
      .height('100%')
      .scrollBar(BarState.Off)
    } else if (tab === 1) {
      Column() {
        Row({ space: 6 }) {
          // 上游 `CompactSearchField`：带放大镜、`radius 10`、`height 32`。
          Row() {
            AppGlyph({ name: 'search', glyphSize: 14, tint: this.themeColorTextTertiary })
              .margin({ left: 10, right: 6 })
            TextInput({ placeholder: '搜索章节…', text: this.query })
              .fontSize(BODY_SMALL).fontColor(this.themeColorTextPrimary)
              .placeholderColor(this.themeColorTextTertiary)
              .backgroundColor(Color.Transparent)
              .layoutWeight(1).height(32)
              .padding({ left: 0, right: 0 })
              .onChange((value: string) => this.query = value)
          }
          .layoutWeight(1).height(32)
          .backgroundColor(this.themeColorSurfaceSecondary)
          .borderRadius(10)
          if (this.query.length > 0) {
            AppGlyph({ name: 'profileClose', glyphSize: 16, tint: this.themeColorTextSecondary })
              .width(24).onClick(() => this.query = '')
          }
          // 上游四个工具是 `CompactToolIconBox`（32dp 方盒、radius 10、选中 secondaryContainer）。
          this.catalogToolBox('profileFindReplace', this.useTitleReplacement,
            () => this.onTitleReplacementChange(!this.useTitleReplacement))
          this.catalogToolBox('profileTimeline', this.showWordCount,
            () => this.toggleShowWordCount())
          this.catalogToolBox('swap', !this.ascending, () => this.ascending = !this.ascending)
          Stack({ alignContent: Alignment.Center }) {
            AppGlyph({ name: 'more', glyphSize: 18, tint: this.themeColorTextSecondary })
          }
          .width(32).height(32).borderRadius(10)
          .backgroundColor(this.catalogMoreVisible ? this.themeColorSurfaceElevated : Color.Transparent)
          .onClick(() => { this.catalogMoreVisible = !this.catalogMoreVisible; })
          .accessibilityText('更多菜单')
          .bindPopup(this.catalogMoreVisible, {
            builder: this.CatalogMoreMenu,
            placement: Placement.BottomRight,
            popupColor: '#00000000',
            enableArrow: false,
            autoCancel: true,
            width: CATALOG_MENU_WIDTH,
            onStateChange: (event: PopupStateChangeParam) => { this.catalogMoreVisible = event.isVisible; }
          })
        }
        .padding({ left: 12, right: 12, bottom: 8 })

        Row() {
          Text(this.ascending ? '正序' : '倒序')
            .fontSize(LABEL_SMALL).fontColor('#AEB0B9')
          Blank()
          Text('共 ' + this.getAllChapters().length.toString() + ' 章')
            .fontSize(LABEL_SMALL).fontColor('#AEB0B9')
        }.padding({ left: 16, right: 16, bottom: 7 })

        // 多选工具条：长按章节行后出现，对齐上游 `ReaderBookSheet.kt:678-740` 的多选浮层
        if (this.selectionMode) {
          Row() {
            Text(`已选 ${this.selectedChapterIndexes.size} 章`)
              .fontSize(LABEL_SMALL).fontColor('#DCDDE4').layoutWeight(1)
            Text('操作')
              .fontSize(LABEL_SMALL).fontColor('#C4D1FF')
              .padding({ left: 10, right: 10, top: 5, bottom: 5 })
              .borderRadius(8)
              .backgroundColor(this.themeColorSurfaceSecondary)
              .onClick(() => { this.chapterSelectionVisible = !this.chapterSelectionVisible; })
              .bindPopup(this.chapterSelectionVisible, {
                builder: this.ChapterSelectionMenu,
                placement: Placement.BottomRight,
                popupColor: '#00000000',
                enableArrow: false,
                autoCancel: true,
                width: CATALOG_MENU_WIDTH,
                onStateChange: (event: PopupStateChangeParam) => { this.chapterSelectionVisible = event.isVisible; }
              })
            Text('完成')
              .fontSize(LABEL_SMALL).fontColor('#C4D1FF')
              .padding({ left: 10, right: 10, top: 5, bottom: 5 })
              .onClick(() => this.clearChapterSelection())
          }
          .width('100%')
          .padding({ left: 16, right: 16, bottom: 7 })
        }

        if (this.chapterView.length === 0) {
          Column() {
            Text(this.query.trim().length > 0 ? '没有找到相关章节' : '暂无目录')
              .fontSize(LABEL_MEDIUM).fontColor('#AEB0B9')
          }.width('100%').layoutWeight(1).justifyContent(FlexAlign.Center)
        } else {
          Stack({ alignContent: Alignment.TopStart }) {
          List({ scroller: this.chapterScroller }) {
            // 惰性列表：屏幕外的章节不组合。对齐上游 TocScreen.kt:763 的 FastScrollLazyColumn
            // + 逐项 item(key =)，key 用章节下标与标题，保证折叠/排序变化时能正确复用节点。
            LazyForEach(this.chapterDataSource, (chapter: CatalogChapter) => {
              ListItem() {
                Row() {
                  // 多选态：卷行不参与批量操作，只有章节行显示勾选圈
                  if (this.selectionMode && !chapter.isVolume) {
                    Stack({ alignContent: Alignment.Center }) {
                      Column()
                        .width(18).height(18).borderRadius(9)
                        .backgroundColor(this.selectedChapterIndexes.has(chapter.index) ? this.themeColorAccent : '#00000000')
                        .border({ width: 1.5, color: this.selectedChapterIndexes.has(chapter.index) ? this.themeColorAccent : '#7A7D88' })
                      if (this.selectedChapterIndexes.has(chapter.index)) {
                        // 对勾是 onPrimary 语义，但勾圈底已随主题（themeColorAccent），
                        // 原来的 #1A1B21 只适合深色的浅 accent；浅色主题 accent 是深蓝，
                        // 深勾会糊在底上，改取 surfaceContainerLow（深色≈#1A1B21、浅色=白）。
                        AppGlyph({ name: 'profileCheck', glyphSize: 12, tint: this.themeColorSurfaceSecondary })
                      }
                    }.width(26).margin({ right: 2 })
                  }
                  if (chapter.isVolume) {
                    // 上游 `ReaderBookSheet.kt` 卷行是 `ExpandMore` 18dp、`tint = primary`。
                    Image($r('app.media.profile_expand_more')).width(18).height(18)
                      .fillColor(this.themeColorAccent)
                      .rotate({ angle: this.collapsedVolumes.has(chapter.index) ? -90 : 0 })
                      .margin({ right: 4 })
                  }
                  Text(chapter.title).fontSize(chapter.isVolume ? 13 : 12)
                    .fontWeight(chapter.isVolume ? FontWeight.Medium : FontWeight.Normal)
                    .fontColor(chapter.isVolume
                      ? this.themeColorTextPrimary
                      : this.chapterRowForeground(chapter.index))
                    // 上游 `ReaderBookSheet.kt` 章节标题 maxLines = 2，本地原来 1 行把长章名截掉了。
                    .layoutWeight(1).maxLines(2)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                  // 字数直接读预存字段：上游 TocScreen 的章节行也是读 chapter.wordCount，不读正文。
                  // 上游是 `NormalCard(radius 8)` 里一个 8sp 的字数，这里套同形态的小卡片。
                  if (this.showWordCount && chapter.wordCount.length > 0) {
                    Text(chapter.wordCount)
                      .fontSize(LABEL_SMALL).fontColor(this.themeColorTextTertiary)
                      .padding({ left: 6, right: 6, top: 2, bottom: 2 })
                      .backgroundColor(this.themeColorSurfaceTertiary)
                      .borderRadius(8)
                      .margin({ right: 8 })
                  }
                  if (this.isCurrentChapter(chapter.index)) {
                    Image($r('app.media.app_locate')).width(16).height(16).fillColor(this.themeColorAccent)
                  }
                  // 批2（TXT:343）：章节右侧下载状态图标。上游 TocScreen.kt:960-1000 四态
                  // （下载中/成功/失败/本地空占位），切换 fade 200ms + scale 0.8。
                  // 这里只显示不响应点击：行本身的 onClick 负责开章节，避免一次点击打两个动作。
                  if (BookRepository.isOnlineBook(this.book) && this.chapterDownloadStateOf(chapter.index) !== 'idle') {
                    Row() {
                      if (this.chapterDownloadStateOf(chapter.index) === 'running') {
                        LoadingProgress().width(14).height(14).color(this.themeColorAccent)
                      } else if (this.chapterDownloadStateOf(chapter.index) === 'done') {
                        AppGlyph({ name: 'profileCheck', glyphSize: 14, tint: '#7BD88F' })
                      } else if (this.chapterDownloadStateOf(chapter.index) === 'failed') {
                        AppGlyph({ name: 'profileRunningWithErrors', glyphSize: 14, tint: '#E5484D' })
                      } else {
                        AppGlyph({ name: 'download', glyphSize: 14, tint: this.themeColorTextTertiary })
                      }
                    }
                    .width(16).height(16).margin({ left: 4 })
                    .transition(TransitionEffect.OPACITY.animation({ duration: 200 })
                      .combine(TransitionEffect.scale({ x: 0.8, y: 0.8 })))
                    .accessibilityText(this.chapterDownloadLabel(chapter.index))
                  }
                }
                .width('100%')
                // 多级缩进对齐上游 `ReaderBookSheet.kt:915-917`：只有 `tocLevel.coerceIn(0,6) * 10`，
                // 没有基础偏移；右内边距上游是 4dp。
                .padding({
                  left: Math.min(6, Math.max(0, chapter.tocLevel)) * 10,
                  right: 4,
                  top: 11,
                  bottom: 11
                })
                .backgroundColor(this.chapterRowBackground(chapter.index))
                .borderRadius(12)
                .onClick(() => {
                  if (this.selectionMode && !chapter.isVolume) {
                    this.toggleChapterSelection(chapter.index);
                    return;
                  }
                  if (chapter.isVolume) { this.toggleVolume(chapter.index); }
                  else { this.onSelectChapter(chapter.index); }
                })
                // 长按章节行进入多选（上游 ReaderBookSheet 多选入口）；卷行长按无动作
                .gesture(LongPressGesture({ duration: 500 }).onAction(() => {
                  if (!chapter.isVolume) { this.enterSelectionMode(chapter.index); }
                }))
              }.margin({ left: 12, right: 12, bottom: 6 })
            }, (chapter: CatalogChapter) => `${chapter.index}`)
          }
          .layoutWeight(1)
          .scrollBar(BarState.Off)
          .onScrollIndex((first: number, _last: number, _center: number) => {
            // 首个可见项变了，偏移从零重新累计。
            this.stickyFirstVisibleIndex = first;
            this.stickyVolumeScrollOffset = 0;
            this.updateStickyVolume(first);
          })
          .onDidScroll((scrollOffset: number, _state: ScrollState) => {
            // 卷标题自己贴顶时，靠累计偏移判断是否已滚出 24vp（上游 `firstVisibleItemScrollOffset > 24`）。
            const before = this.stickyVolumeScrollOffset;
            this.stickyVolumeScrollOffset += Math.abs(scrollOffset);
            if (before <= 24 && this.stickyVolumeScrollOffset > 24) {
              this.updateStickyVolume(this.stickyFirstVisibleIndex);
            }
          })
          .onAreaChange(() => this.scrollToCurrentChapter())

          // 吸顶卷头：盖在列表顶部，样式对齐上游 TextCard（圆角 8、内边距 8/6）。
          if (this.stickyVolumeTitle.length > 0) {
            Text(this.stickyVolumeTitle)
              .fontSize(LABEL_SMALL).fontColor('#DCDDE4').maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .padding({ left: 8, right: 8, top: 6, bottom: 6 })
              .backgroundColor(this.themeColorSurfaceSecondary)
              .borderRadius(8)
              .margin({ left: 16, top: 4 })
              .onClick(() => this.scrollToStickyVolume())
          }
          }
        }
      }
      .width('100%')
      .height('100%')
    } else if (tab === 2) {
      // 对齐上游 ReaderBookBookmarksPage：顶部搜索框 + 导出菜单，条目点按编辑、长按跳转。
      Column() {
        Row() {
          TextInput({ placeholder: '搜索', text: this.markQuery })
            .fontSize(BODY_SMALL).fontColor('#E1E2E8').placeholderColor('#A0A2AB')
            .backgroundColor(this.themeColorSurfaceSecondary).layoutWeight(1).borderRadius(12)
            .onChange((value: string) => this.markQuery = value)
          if (this.markQuery.length > 0) {
            AppGlyph({ name: 'profileClose', glyphSize: 16, tint: '#C5C7D0' })
              .width(32).onClick(() => this.markQuery = '')
          }
          Stack({ alignContent: Alignment.Center }) {
            AppGlyph({ name: 'more', glyphSize: 18, tint: this.themeColorTextSecondary })
          }
          .width(32)
          .height(32)
          .onClick(() => { this.bookmarkExportVisible = !this.bookmarkExportVisible; })
          .accessibilityText('更多菜单')
          .bindPopup(this.bookmarkExportVisible, {
            builder: this.BookmarkExportMenu,
            placement: Placement.BottomRight,
            popupColor: '#00000000',
            enableArrow: false,
            autoCancel: true,
            width: CATALOG_MENU_WIDTH,
            onStateChange: (event: PopupStateChangeParam) => { this.bookmarkExportVisible = event.isVisible; }
          })
        }
        .width('100%')
        .padding({ left: 12, right: 12, top: 4, bottom: 8 })

        if (this.getVisibleBookmarks().length === 0) {
          Column() {
            AppGlyph({ name: 'bookmark', glyphSize: 30, tint: this.themeColorAccent })
            Text(this.markQuery.length > 0 ? '没有找到相关书签' : '暂无书签')
              .fontSize(TITLE_SMALL).fontColor('#AEB0B9').margin({ top: 8 })
          }
          .width('100%')
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)
        } else {
          List({ scroller: this.bookmarkScroller }) {
            ForEach(this.getVisibleBookmarks(), (bookmark: ReaderBookmark) => {
              ListItem() {
                Column() {
                  Row() {
                    Text(bookmark.chapterName.length > 0 ? bookmark.chapterName
                      : this.getChapterFallbackName(bookmark.chapterIndex))
                      .fontSize(LABEL_MEDIUM)
                      .fontColor(this.isCurrentChapterItem(bookmark.chapterIndex) ? '#F0F1F5' : '#DCDDE4')
                      .layoutWeight(1).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
                    if (this.isCurrentChapterItem(bookmark.chapterIndex)) {
                      AppGlyph({ name: 'locate', glyphSize: 16,
                        tint: this.isCurrentChapterItem(bookmark.chapterIndex) ? '#F0F1F5' : '#DCDDE4' })
                    }
                  }.width('100%')
                  if (bookmark.bookText.length > 0) {
                    Text(bookmark.bookText).fontSize(BODY_SMALL).fontColor('#BFC1CA')
                      .maxLines(2).margin({ top: 4 }).textOverflow({ overflow: TextOverflow.Ellipsis })
                  }
                  if (bookmark.content.length > 0) {
                    Text(bookmark.content).fontSize(LABEL_SMALL).fontColor(this.themeColorAccent)
                      .maxLines(2).margin({ top: 4 }).textOverflow({ overflow: TextOverflow.Ellipsis })
                  }
                }
                .width('100%')
                .padding({ left: 12, right: 12, top: 10, bottom: 10 })
                .backgroundColor(this.isCurrentChapterItem(bookmark.chapterIndex) ? this.themeColorSurfaceTertiary : this.themeColorSurfaceSecondary)
                .borderRadius(12)
                .onClick(() => this.onEditBookmark(bookmark.id))
                .gesture(LongPressGesture({ duration: 500 })
                  .onAction((_event: GestureEvent): void => { this.onOpenBookmark(bookmark.id); }))
              }.margin({ left: 12, right: 12, bottom: 6 })
            }, (bookmark: ReaderBookmark) => bookmark.id)
          }
          .width('100%')
          .layoutWeight(1)
          .scrollBar(BarState.Off)
          .onAreaChange(() => this.scrollBookmarksToCurrentChapter())
        }
      }
      .width('100%')
      .height('100%')
    } else {
      // 对齐上游 ReaderBookMarkingsPage：第一行创建时间 + 章名 + 其他书源 + 定位图标。
      if (this.getVisibleMarkings().length === 0) {
        Column() {
          AppGlyph({ name: 'profileNoteAdd', glyphSize: 28, tint: this.themeColorAccent })
          Text(this.markQuery.length > 0 ? '没有找到相关笔记' : '暂无笔记')
            .fontSize(LABEL_LARGE).fontColor('#AEB0B9').margin({ top: 8 })
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
      } else {
        Scroll() {
          Column() {
            ForEach(this.getVisibleMarkings(), (marking: ReaderMarking) => {
              Column() {
                Row() {
                  Text(this.formatCreatedTime(marking.createdAt)).fontSize(LABEL_SMALL).fontColor('#C5C7D0')
                    .layoutWeight(1).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
                  Text(marking.chapterName.length > 0 ? marking.chapterName
                    : this.getChapterFallbackName(marking.chapterIndex))
                    .fontSize(LABEL_SMALL).fontColor(this.themeColorTextTertiary).maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis }).margin({ right: 4 })
                  if (this.isMarkingFromOtherSource(marking)) {
                    Text('其他书源').fontSize(LABEL_SMALL).fontColor('#E57373').margin({ right: 4 })
                  }
                  if (this.isCurrentChapterItem(marking.chapterIndex)) {
                    AppGlyph({ name: 'locate', glyphSize: 12, tint: '#C5C7D0' })
                  }
                }.width('100%')
                if (marking.selectedText.length > 0) {
                  Text(marking.selectedText).fontSize(LABEL_MEDIUM).fontColor('#E0E1E6').lineHeight(LABEL_MEDIUM_LINE_HEIGHT)
                    .maxLines(2).width('100%').margin({ top: 4 })
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                }
                if (marking.note.trim().length > 0) {
                  Text(marking.note).fontSize(BODY_SMALL).fontColor(this.themeColorAccent).lineHeight(BODY_SMALL_LINE_HEIGHT)
                    .maxLines(2).width('100%').margin({ top: 4 })
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                }
              }
              .width('100%').padding({ left: 12, right: 12, top: 10, bottom: 10 })
              .backgroundColor(this.isCurrentChapterItem(marking.chapterIndex) ? this.themeColorSurfaceTertiary : this.themeColorSurfaceSecondary)
              .borderRadius(12).margin({ bottom: 6 })
              .onClick(() => this.onEditMarking(marking.id))
              .gesture(LongPressGesture({ duration: 500 })
                .onAction((_event: GestureEvent): void => { this.onOpenMarking(marking.id); }))
            }, (marking: ReaderMarking) => this.markingItemKey(marking))
          }.padding({ left: 12, right: 12, top: 4, bottom: 24 })
        }.edgeEffect(EdgeEffect.Spring, { alwaysEnabled: false }).width('100%').height('100%').scrollBar(BarState.Off)
      }
    }
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('#99000000')
        .onClick(() => this.onBack())

      Column() {
        Row()
          .width(32)
          .height(4)
          .backgroundColor(this.themeColorTextSecondary)
          .borderRadius(4)
          .margin({ top: 9, bottom: 16 })
          .onClick(() => this.onBack())

        Row() {
          // 上游 `ReaderBookSheet.kt` 的书封是 `width(40.dp) + aspectRatio(5/7)` = 40×56，
          // 点击书封同样进书籍详情。
          // 本地 `mini: true` 是 48×68，偏大一圈。
          BookCover({ book: this.book, displayWidth: 40, displayHeight: 56, applyAspectRatio: true })
            .onClick(() => this.onOpenBookInfo())
          Column() {
            // 上游书名 `labelLargeEmphasized`（14sp Medium）、maxLines 2、可点进详情。
            Text(this.book.title).fontSize(LABEL_LARGE).fontWeight(FontWeight.Medium)
              .fontColor(this.themeColorTextPrimary).maxLines(2)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .onClick(() => this.onOpenBookInfo())
            // 上游副标题 `labelSmallEmphasized` + `basicMarquee()`：长章名滚动而不是截断。
            Text(this.book.lastChapter).fontSize(LABEL_SMALL).fontColor(this.themeColorTextSecondary)
              .margin({ top: 4 }).maxLines(1)
              .textOverflow({ overflow: TextOverflow.MARQUEE })
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)
          .margin({ left: 12 })
          Text(this.getCurrentChapterNumber().toString() + ' / ' + this.getAllChapters().length.toString())
            .fontSize(LABEL_SMALL)
            .fontColor(this.themeColorTextPrimary)
            .padding({ left: 9, right: 9, top: 6, bottom: 6 })
            .backgroundColor(this.themeColorSurfaceTertiary)
            .borderRadius(14)
        }
        .width('100%')
        .padding({ left: 14, right: 14, bottom: 12 })

        Row() {
          ForEach([0, 1, 2, 3], (index: number) => {
            // 上游 `CardTabRow.kt:118`：`labelMediumEmphasized`（12sp Medium），水平内边距 8dp。
            Text(this.getTabLabel(index))
              .fontSize(BODY_SMALL)
              .fontWeight(this.selectedTab === index ? FontWeight.Medium : FontWeight.Normal)
              .fontColor(this.selectedTab === index ? this.themeColorTextPrimary : this.themeColorTextSecondary)
              .textAlign(TextAlign.Center)
              .layoutWeight(1)
              .padding({ left: 8, right: 8, top: 8, bottom: 8 })
              .backgroundColor(this.selectedTab === index ? this.themeColorSurfaceElevated : Color.Transparent)
              .borderRadius(12)
              .margin({ left: index === 0 ? 12 : 4, right: index === 3 ? 12 : 4 })
              .animation({ duration: 200, curve: Curve.EaseInOut })
              .onClick(() => {
                this.selectedTab = index;
                if (index === 1) { this.scrollToCurrentChapter(); }
              })
              // 上游前三页长按 = 关 sheet + 开全屏页，本地没有全屏目录路由，未实现。
          }, (index: number) => index.toString())
        }
        .width('100%')
        .margin({ bottom: 10 })

        Swiper() {
          ForEach([0, 1, 2, 3], (index: number) => {
            this.CatalogTabPage(index)
          }, (index: number) => index.toString())
        }
        .index(this.selectedTab)
        .loop(false)
        .indicator(false)
        .onChange((index: number) => {
          this.selectedTab = index;
          if (index === 1) { this.scrollToCurrentChapter(); }
        })
        .layoutWeight(1)
        .width('100%')
      }
      .width('100%')
      .height('72%')
      // 上游 `AppModalBottomSheet.kt:62-64` 底色是 `surfaceContainer`，圆角走 M3 `large` = 16dp。
      .backgroundColor(this.themeColorSurfaceElevated)
      .borderRadius({ topLeft: 16, topRight: 16 })
      // 批2（TXT:480）：点章节到正文出现之间要等 readChapter，盖一层加载态。
      // 上游 TocScreen.kt 同位置画的是 20dp 下载中转圈，这里换成「转圈 + 加载中…」。
      if (this.chapterLoading) {
        Column() {
          LoadingProgress().width(28).height(28).color(this.themeColorAccent)
          Text('加载中…').fontSize(BODY_SMALL).fontColor(this.themeColorTextSecondary).margin({ top: 8 })
        }
        .width('100%').height('100%')
        .justifyContent(FlexAlign.Center)
        .backgroundColor('rgba(0,0,0,0.35)')
      }
    }
    .width('100%')
    .height('100%')
  }
}

@Component
struct CatalogInformationRow {
  @StorageProp('themeColorTextPrimary') themeColorTextPrimary: string = '#1B1C22';
  @StorageProp('themeColorTextSecondary') themeColorTextSecondary: string = '#2E3038';
  @StorageProp('themeColorTextTertiary') themeColorTextTertiary: string = '#6A6D77';
  @StorageProp('themeColorAccent') themeColorAccent: string = '#3F5BD9';
  @StorageProp('themeColorSurfaceSecondary') themeColorSurfaceSecondary: string = '#FFFFFF';
  @Prop label: string = '';
  @Prop value: string = '';

  build() {
    Column() {
      Text(this.label)
        .fontSize(LABEL_SMALL)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.themeColorAccent)
      Text(this.value.trim().length > 0 ? this.value : '--')
        .fontSize(TITLE_SMALL)
        .fontColor(this.themeColorTextSecondary)
        .lineHeight(TITLE_SMALL_LINE_HEIGHT)
        .margin({ top: 3 })
    }
    .width('100%')
    .padding({ left: 12, right: 12, top: 10, bottom: 10 })
    .backgroundColor(this.themeColorSurfaceSecondary)
    .borderRadius(14)
  }
}
