import { Book, BookChapter } from '../model/Book';
import { ReaderBookmark } from '../model/ReaderBookmark';
import { ReaderMarking } from '../model/ReaderMarking';
import { BookCover } from '../components/BookCover';
import { AppGlyph } from '../components/AppGlyph';
import { BookRepository } from '../data/BookRepository';
import { ReplaceRuleRepository } from '../data/ReplaceRuleRepository';

interface CatalogChapter {
  title: string;
  index: number;
  isVolume: boolean;
  isInVolume: boolean;
  /** 目录层级：卷标题 0、卷内章节 1，与上游 `tocLevel` 同口径，用于多级缩进。 */
  tocLevel: number;
}

@Component
export struct CatalogPage {
  @StorageProp('themeColorTextSecondary') themeColorTextSecondary: string = '#2E3038';
  @StorageProp('themeColorTextTertiary') themeColorTextTertiary: string = '#6A6D77';
  @StorageProp('themeColorAccent') themeColorAccent: string = '#3F5BD9';
  @StorageProp('themeColorSurfaceSecondary') themeColorSurfaceSecondary: string = '#FFFFFF';
  @StorageProp('themeColorSurfaceElevated') themeColorSurfaceElevated: string = '#FFFFFF';
  @Prop book: Book = {
    id: '', title: '', author: '', category: '', lastChapter: '', progress: 0, isLocal: true
  };
  @Prop selectedChapter: string = '';
  @Prop bookmarks: ReaderBookmark[] = [];
  @Prop markings: ReaderMarking[] = [];
  @Prop useTitleReplacement: boolean = false;
  @Prop showWordCount: boolean = true;
  @State ascending: boolean = true;
  @State selectedTab: number = 1;
  @State query: string = '';
  /** 书签/笔记页共用的搜索词，对应上游 `TocActionState.searchKey`。 */
  @State markQuery: string = '';
  @State chapterWordCounts: Map<number, string> = new Map<number, string>();
  @State wordCountsLoading: boolean = false;
  /** 已折叠的卷头章节下标。 */
  @State collapsedVolumes: Set<number> = new Set<number>();
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
  private wordCountGeneration: number = 0;
  onBack: () => void = () => {};
  onSelectChapter: (chapterIndex: number) => void = () => {};
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
  /** 已选中的章节下标（对应 `chapterRows` 下标）。 */
  @State selectedChapterIndexes: Set<number> = new Set<number>();
  /** 多选浮层是否展开（对齐上游 `fabExpanded`）。 */
  @State selectionMenuExpanded: boolean = false;

  /** 目录行，打开页面时从 chapters 表读一次；章节已不在 Book 上。 */
  @State chapterRows: BookChapter[] = [];

  aboutToAppear(): void {
    // 字数统计依赖 chapterRows，所以只在需要统计时串起来等；不统计时单独加载章节行。
    if (this.showWordCount) {
      this.loadChapterWordCountsAfterRows();
    } else {
      this.loadChapterRows();
    }
  }

  /** 先等章节行加载完，再统计字数。 */
  private async loadChapterWordCountsAfterRows(): Promise<void> {
    try {
      await this.loadChapterRows();
    } catch (_) {
      return;
    }
    if (this.chapterRows.length === 0) { return; }
    await this.loadChapterWordCounts();
  }

  aboutToDisappear(): void {
    this.wordCountGeneration++;
  }

  private async loadChapterRows(): Promise<void> {
    const context = this.getUIContext().getHostContext();
    if (context === undefined) { return; }
    try {
      this.chapterRows = await BookRepository.loadChapters(context, this.book);
    } catch (_) {
      this.chapterRows = [];
    }
  }

  private getAllChapters(): string[] {
    const titles: string[] = [];
    this.chapterRows.forEach((row: BookChapter) => {
      titles.push(row.title);
    });
    return titles;
  }

  private getChapters(): CatalogChapter[] {
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
          tocLevel: row.tocLevel });
      }
    }
    if (this.ascending) { return chapters; }
    const reversed: CatalogChapter[] = [];
    for (let index = chapters.length - 1; index >= 0; index--) {
      const chapter = chapters[index];
      if (chapter !== undefined) { reversed.push(chapter); }
    }
    return reversed;
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

  private isChapterSelected(chapterIndex: number): boolean {
    const selectedIndex = this.book.chapterIndex ?? this.getAllChapters().indexOf(this.selectedChapter);
    return chapterIndex === selectedIndex;
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
    return '本地 TXT';
  }

  private getCurrentChapterNumber(): number {
    const index = this.book.chapterIndex ?? this.getAllChapters().indexOf(this.selectedChapter);
    return index >= 0 ? index + 1 : 0;
  }

  private scrollToCurrentChapter(): void {
    if (this.selectedTab !== 1 || this.hasAutoScrolledCurrentChapter) { return; }
    const currentChapterIndex = this.book.chapterIndex ?? this.getAllChapters().indexOf(this.selectedChapter);
    const visibleIndex = this.getChapters().findIndex((chapter: CatalogChapter) =>
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
   * 粘性卷头：对齐上游 `TocScreen.kt:270-295` 的 `stickyVolume`。
   *
   * 上游判定是「首个可见项不是卷标题」或「就是卷标题但已滚出 24」，
   * 且该卷未折叠时，才把卷名吸在列表顶部。ArkUI 的 List 没有内建 sticky header，
   * 这里用一层覆盖在列表上的浮层实现同样的观感。
   */
  private updateStickyVolume(firstVisibleIndex: number): void {
    if (this.selectedTab !== 1) { this.stickyVolumeTitle = ''; return; }
    const chapters = this.getChapters();
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
    const chapters = this.getChapters();
    const index = chapters.findIndex((chapter: CatalogChapter) => chapter.title === this.stickyVolumeTitle &&
      chapter.isVolume);
    if (index >= 0) { this.chapterScroller.scrollToIndex(index, true); }
  }

  private async loadChapterWordCounts(): Promise<void> {
    if (this.book.contentPath === undefined || BookRepository.isBodyMissing(this.book) || this.wordCountsLoading) { return; }
    const generation = ++this.wordCountGeneration;
    this.wordCountsLoading = true;
    const counts = new Map<number, string>();
    try {
      // 必须把已加载的 chapterRows 传进去：不传时 forEachChapter 会退回 deriveChapters()，
      // 对全书正文再跑一遍目录规则正则（1378 章的书要 6 秒以上，直接把界面线程卡死）。
      await BookRepository.forEachChapter(
        this.book,
        async (content: string, chapterIndex: number): Promise<boolean> => {
          if (generation !== this.wordCountGeneration) { return false; }
          counts.set(chapterIndex, this.formatWordCount(content.length));
          return true;
        },
        false,
        this.chapterRows
      );
      if (generation === this.wordCountGeneration) { this.chapterWordCounts = counts; }
    } catch (_) {
      if (generation === this.wordCountGeneration) { this.onUnavailableAction('无法读取本地章节字数'); }
    } finally {
      if (generation === this.wordCountGeneration) { this.wordCountsLoading = false; }
    }
  }

  private toggleShowWordCount(): void {
    const enabled = !this.showWordCount;
    this.onShowWordCountChange(enabled);
    if (enabled && this.chapterWordCounts.size === 0) { this.loadChapterWordCounts(); }
    else if (!enabled) {
      this.wordCountGeneration++;
      this.wordCountsLoading = false;
    }
  }

  /** 书签页「更多」菜单，对应上游 TocScreen 的书签导出两项。 */
  @Builder
  private BookmarkExportMenu() {
    Menu() {
      MenuItem({ content: '导出为 JSON' }).height(44)
        .onClick(() => this.onExportBookmarks(false))
      MenuItem({ content: '导出为 Markdown' }).height(44)
        .onClick(() => this.onExportBookmarks(true))
    }
  }

  /** 目录页「更多」菜单，对应上游 TocScreen 信息页那组菜单项。 */
  @Builder
  private CatalogMoreMenu() {
    Menu() {
      if (this.isLocalTxt()) {
        MenuItem({ content: '更新目录' }).height(44)
          .onClick(() => this.onRefreshToc())
      }
      MenuItem({ content: '替换规则' }).height(44)
        .onClick(() => this.onOpenReplaceRules())
      if (this.book.isLocal) {
        MenuItem({ content: '本地 TXT 目录规则' }).height(44)
          .onClick(() => this.onOpenTxtTocRules())
      }
    }
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
    this.getChapters().forEach((chapter: CatalogChapter) => {
      if (!chapter.isVolume) { next.add(chapter.index); }
    });
    this.selectedChapterIndexes = next;
    this.selectionMode = next.size > 0;
  }

  private invertChapterSelection(): void {
    const next = new Set<number>();
    this.getChapters().forEach((chapter: CatalogChapter) => {
      if (!chapter.isVolume && !this.selectedChapterIndexes.has(chapter.index)) { next.add(chapter.index); }
    });
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
   * 本地 TXT 离线阅读没有这两个功能，所以只保留其余四项。
   */
  @Builder
  private ChapterSelectionMenu() {
    Menu() {
      MenuItem({ content: '全选' }).height(44).onClick(() => this.selectAllChapters())
      MenuItem({ content: '反选' }).height(44).onClick(() => this.invertChapterSelection())
      MenuItem({ content: `加书签（${this.selectedChapterIndexes.size}）` }).height(44)
        .onClick(() => this.addBookmarksForSelection())
      MenuItem({ content: '取消选择' }).height(44).onClick(() => this.clearChapterSelection())
    }
  }

  @Builder
  private CatalogTabPage(tab: number) {
    if (tab === 0) {
      Scroll() {
        Column() {
          CatalogInformationRow({ label: '作者', value: this.book.author })
          CatalogInformationRow({ label: '书源', value: this.getSourceLabel() })
          if ((this.book.description ?? '').trim().length > 0) {
            CatalogInformationRow({ label: '简介', value: this.book.description ?? '' })
          }
        }
        .width('100%')
        .padding({ top: 8, bottom: 14 })
      }
      .width('100%')
      .height('100%')
      .scrollBar(BarState.Off)
    } else if (tab === 1) {
      Column() {
        Row() {
          TextInput({ placeholder: '搜索章节…', text: this.query })
            .fontSize(12).fontColor('#E1E2E8').placeholderColor('#A0A2AB')
            .backgroundColor(this.themeColorSurfaceSecondary).layoutWeight(1).borderRadius(12)
            .onChange((value: string) => this.query = value)
          if (this.query.length > 0) {
            AppGlyph({ name: 'profileClose', glyphSize: 16, tint: '#C5C7D0' })
              .width(32).onClick(() => this.query = '')
          }
          AppGlyph({ name: 'profileFindReplace', glyphSize: 17,
            tint: this.useTitleReplacement ? this.themeColorAccent : this.themeColorTextSecondary })
            .width(32)
            .onClick(() => this.onTitleReplacementChange(!this.useTitleReplacement))
          AppGlyph({ name: 'profileTimeline', glyphSize: 17,
            tint: this.showWordCount ? this.themeColorAccent : this.themeColorTextSecondary })
            .width(32)
            .onClick(() => this.toggleShowWordCount())
          AppGlyph({ name: 'swap', glyphSize: 18, tint: this.ascending ? this.themeColorTextSecondary : this.themeColorAccent })
            .width(32).onClick(() => this.ascending = !this.ascending)
          Stack({ alignContent: Alignment.Center }) {
            AppGlyph({ name: 'more', glyphSize: 18, tint: this.themeColorTextSecondary })
          }
          .width(28)
          .height(32)
          .bindMenu(this.CatalogMoreMenu, { placement: Placement.BottomRight })
        }
        .padding({ left: 12, right: 12, bottom: 8 })

        Row() {
          Text(this.wordCountsLoading ? '正在统计章节字数' : this.ascending ? '正序' : '倒序')
            .fontSize(10).fontColor('#AEB0B9')
          Blank()
          Text('共 ' + this.getAllChapters().length.toString() + ' 章')
            .fontSize(10).fontColor('#AEB0B9')
        }.padding({ left: 16, right: 16, bottom: 7 })

        // 多选工具条：长按章节行后出现，对齐上游 `ReaderBookSheet.kt:678-740` 的多选浮层
        if (this.selectionMode) {
          Row() {
            Text(`已选 ${this.selectedChapterIndexes.size} 章`)
              .fontSize(11).fontColor('#DCDDE4').layoutWeight(1)
            Text('操作')
              .fontSize(11).fontColor('#C4D1FF')
              .padding({ left: 10, right: 10, top: 5, bottom: 5 })
              .borderRadius(8)
              .backgroundColor(this.themeColorSurfaceSecondary)
              .bindMenu(this.ChapterSelectionMenu, { placement: Placement.BottomRight })
            Text('完成')
              .fontSize(11).fontColor('#C4D1FF')
              .padding({ left: 10, right: 10, top: 5, bottom: 5 })
              .onClick(() => this.clearChapterSelection())
          }
          .width('100%')
          .padding({ left: 16, right: 16, bottom: 7 })
        }

        if (this.getChapters().length === 0) {
          Column() {
            Text(this.query.trim().length > 0 ? '没有找到相关章节' : '暂无目录')
              .fontSize(13).fontColor('#AEB0B9')
          }.width('100%').layoutWeight(1).justifyContent(FlexAlign.Center)
        } else {
          Stack({ alignContent: Alignment.TopStart }) {
          List({ scroller: this.chapterScroller }) {
            ForEach(this.getChapters(), (chapter: CatalogChapter) => {
              ListItem() {
                Row() {
                  // 多选态：卷行不参与批量操作，只有章节行显示勾选圈
                  if (this.selectionMode && !chapter.isVolume) {
                    Stack({ alignContent: Alignment.Center }) {
                      Column()
                        .width(18).height(18).borderRadius(9)
                        .backgroundColor(this.selectedChapterIndexes.has(chapter.index) ? '#C4D1FF' : '#00000000')
                        .border({ width: 1.5, color: this.selectedChapterIndexes.has(chapter.index) ? '#C4D1FF' : '#7A7D88' })
                      if (this.selectedChapterIndexes.has(chapter.index)) {
                        AppGlyph({ name: 'profileCheck', glyphSize: 12, tint: '#1A1B21' })
                      }
                    }.width(26).margin({ right: 2 })
                  }
                  if (chapter.isVolume) {
                    Image($r('app.media.profile_expand_more')).width(14).height(14)
                      .fillColor('#AEB0B9')
                      .rotate({ angle: this.collapsedVolumes.has(chapter.index) ? -90 : 0 })
                      .margin({ right: 4 })
                  }
                  Text(chapter.title).fontSize(chapter.isVolume ? 13 : 12)
                    .fontWeight(chapter.isVolume ? FontWeight.Medium : FontWeight.Normal)
                    .fontColor(this.isChapterSelected(chapter.index) ? '#F0F1F5' : (chapter.isVolume ? '#DCDDE4' : '#D4D5DB'))
                    .layoutWeight(1).maxLines(1)
                  if (this.showWordCount && this.chapterWordCounts.has(chapter.index)) {
                    Text(this.chapterWordCounts.get(chapter.index) ?? '')
                      .fontSize(10).fontColor('#AEB0B9').margin({ right: 8 })
                  }
                  if (this.isChapterSelected(chapter.index)) {
                    Image($r('app.media.app_locate')).width(16).height(16).fillColor('#C4D1FF')
                  }
                }
                .width('100%')
                // 多级缩进对齐上游 ReaderBookSheet.kt:890-935：行内基础 12dp + tocLevel×10dp，最多 6 级。
                .padding({ left: 12 + Math.min(6, Math.max(0, chapter.tocLevel)) * 10, right: 12, top: 11, bottom: 11 })
                .backgroundColor(this.isChapterSelected(chapter.index) ? '#454B62' : this.themeColorSurfaceSecondary)
                .borderRadius(10)
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
            }, (chapter: CatalogChapter) => `${chapter.index}_${chapter.isVolume ? 1 : 0}_${chapter.isInVolume ? 1 : 0}_${this.collapsedVolumes.has(chapter.index) ? 1 : 0}`)
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
              .fontSize(11).fontColor('#DCDDE4').maxLines(1)
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
            .fontSize(12).fontColor('#E1E2E8').placeholderColor('#A0A2AB')
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
          .bindMenu(this.BookmarkExportMenu, { placement: Placement.BottomRight })
        }
        .width('100%')
        .padding({ left: 12, right: 12, top: 4, bottom: 8 })

        if (this.getVisibleBookmarks().length === 0) {
          Column() {
            AppGlyph({ name: 'bookmark', glyphSize: 30, tint: this.themeColorAccent })
            Text(this.markQuery.length > 0 ? '没有找到相关书签' : '暂无书签')
              .fontSize(14).fontColor('#AEB0B9').margin({ top: 8 })
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
                      .fontSize(13)
                      .fontColor(this.isCurrentChapterItem(bookmark.chapterIndex) ? '#F0F1F5' : '#DCDDE4')
                      .layoutWeight(1).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
                    if (this.isCurrentChapterItem(bookmark.chapterIndex)) {
                      AppGlyph({ name: 'locate', glyphSize: 16,
                        tint: this.isCurrentChapterItem(bookmark.chapterIndex) ? '#F0F1F5' : '#DCDDE4' })
                    }
                  }.width('100%')
                  if (bookmark.bookText.length > 0) {
                    Text(bookmark.bookText).fontSize(12).fontColor('#BFC1CA')
                      .maxLines(2).margin({ top: 4 }).textOverflow({ overflow: TextOverflow.Ellipsis })
                  }
                  if (bookmark.content.length > 0) {
                    Text(bookmark.content).fontSize(11).fontColor(this.themeColorAccent)
                      .maxLines(2).margin({ top: 4 }).textOverflow({ overflow: TextOverflow.Ellipsis })
                  }
                }
                .width('100%')
                .padding({ left: 12, right: 12, top: 10, bottom: 10 })
                .backgroundColor(this.isCurrentChapterItem(bookmark.chapterIndex) ? '#303442' : this.themeColorSurfaceSecondary)
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
            .fontSize(14).fontColor('#AEB0B9').margin({ top: 8 })
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
                  Text(this.formatCreatedTime(marking.createdAt)).fontSize(10).fontColor('#C5C7D0')
                    .layoutWeight(1).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
                  Text(marking.chapterName.length > 0 ? marking.chapterName
                    : this.getChapterFallbackName(marking.chapterIndex))
                    .fontSize(10).fontColor(this.themeColorTextTertiary).maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis }).margin({ right: 4 })
                  if (this.isMarkingFromOtherSource(marking)) {
                    Text('其他书源').fontSize(10).fontColor('#E57373').margin({ right: 4 })
                  }
                  if (this.isCurrentChapterItem(marking.chapterIndex)) {
                    AppGlyph({ name: 'locate', glyphSize: 12, tint: '#C5C7D0' })
                  }
                }.width('100%')
                if (marking.selectedText.length > 0) {
                  Text(marking.selectedText).fontSize(13).fontColor('#E0E1E6').lineHeight(19)
                    .maxLines(2).width('100%').margin({ top: 4 })
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                }
                if (marking.note.trim().length > 0) {
                  Text(marking.note).fontSize(12).fontColor(this.themeColorAccent).lineHeight(17)
                    .maxLines(2).width('100%').margin({ top: 4 })
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                }
              }
              .width('100%').padding({ left: 12, right: 12, top: 10, bottom: 10 })
              .backgroundColor(this.isCurrentChapterItem(marking.chapterIndex) ? '#303442' : this.themeColorSurfaceSecondary)
              .borderRadius(12).margin({ bottom: 6 })
              .onClick(() => this.onEditMarking(marking.id))
              .gesture(LongPressGesture({ duration: 500 })
                .onAction((_event: GestureEvent): void => { this.onOpenMarking(marking.id); }))
            }, (marking: ReaderMarking) => this.markingItemKey(marking))
          }.padding({ left: 12, right: 12, top: 4, bottom: 24 })
        }.width('100%').height('100%').scrollBar(BarState.Off)
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
          .backgroundColor('#C6C7CE')
          .borderRadius(4)
          .margin({ top: 9, bottom: 16 })
          .onClick(() => this.onBack())

        Row() {
          BookCover({ book: this.book, mini: true })
          Column() {
            Text(this.book.title).fontSize(13).fontColor('#ECEEF2').maxLines(1)
            Text(this.book.lastChapter).fontSize(10).fontColor('#AEB0B9').margin({ top: 4 }).maxLines(1)
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)
          .margin({ left: 12 })
          Text(this.getCurrentChapterNumber().toString() + ' / ' + this.getAllChapters().length.toString())
            .fontSize(10)
            .fontColor('#ECEEF2')
            .padding({ left: 9, right: 9, top: 6, bottom: 6 })
            .backgroundColor('#101116')
            .borderRadius(14)
        }
        .width('100%')
        .padding({ left: 14, right: 14, bottom: 12 })

        Row() {
          ForEach([0, 1, 2, 3], (index: number) => {
            Text(this.getTabLabel(index))
              .fontSize(11)
              .fontColor(this.selectedTab === index ? '#F0F1F5' : '#B0B2BC')
              .textAlign(TextAlign.Center)
              .layoutWeight(1)
              .padding({ top: 8, bottom: 8 })
              .backgroundColor(this.selectedTab === index ? '#454B62' : this.themeColorSurfaceElevated)
              .borderRadius(12)
              .margin({ left: index === 0 ? 12 : 4, right: index === 3 ? 12 : 4 })
              .onClick(() => {
                this.selectedTab = index;
                if (index === 1) { this.scrollToCurrentChapter(); }
              })
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
      .backgroundColor('#17181E')
      .borderRadius({ topLeft: 22, topRight: 22 })
    }
    .width('100%')
    .height('100%')
  }
}

@Component
struct CatalogInformationRow {
  @StorageProp('themeColorAccent') themeColorAccent: string = '#3F5BD9';
  @StorageProp('themeColorSurfaceSecondary') themeColorSurfaceSecondary: string = '#FFFFFF';
  @Prop label: string = '';
  @Prop value: string = '';

  build() {
    Column() {
      Text(this.label)
        .fontSize(11)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.themeColorAccent)
      Text(this.value.trim().length > 0 ? this.value : '--')
        .fontSize(13)
        .fontColor('#D4D5DB')
        .lineHeight(19)
        .margin({ top: 3 })
    }
    .width('100%')
    .padding({ left: 12, right: 12, top: 10, bottom: 10 })
    .backgroundColor(this.themeColorSurfaceSecondary)
    .borderRadius(14)
  }
}
