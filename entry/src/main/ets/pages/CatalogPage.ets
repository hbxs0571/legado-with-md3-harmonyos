import { Book } from '../model/Book';
import { ReaderBookmark } from '../model/ReaderBookmark';
import { ReaderMarking, ReaderMarkingEffect } from '../model/ReaderMarking';
import { BookCover } from '../components/BookCover';
import { AppGlyph } from '../components/AppGlyph';
import { BookRepository } from '../data/BookRepository';
import { ReplaceRuleRepository } from '../data/ReplaceRuleRepository';

interface CatalogChapter {
  title: string;
  index: number;
  isVolume: boolean;
  isInVolume: boolean;
}

@Component
export struct CatalogPage {
  @Prop book: Book = {
    id: '', title: '', author: '', category: '', lastChapter: '', progress: 0,
    coverColor: '#343845', coverMark: '书', isLocal: true
  };
  @Prop selectedChapter: string = '';
  @Prop bookmarks: ReaderBookmark[] = [];
  @Prop markings: ReaderMarking[] = [];
  @Prop useTitleReplacement: boolean = false;
  @Prop showWordCount: boolean = true;
  @State ascending: boolean = true;
  @State selectedTab: number = 1;
  @State query: string = '';
  @State chapterWordCounts: Map<number, string> = new Map<number, string>();
  @State wordCountsLoading: boolean = false;
  /** 已折叠的卷头章节下标。 */
  @State collapsedVolumes: Set<number> = new Set<number>();
  private chapterScroller: Scroller = new Scroller();
  private hasAutoScrolledCurrentChapter: boolean = false;
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

  aboutToAppear(): void {
    if (this.showWordCount) { this.loadChapterWordCounts(); }
  }

  aboutToDisappear(): void {
    this.wordCountGeneration++;
  }

  private getAllChapters(): string[] {
    if (this.book.chapterTitles !== undefined && this.book.chapterTitles.length > 0) {
      return this.book.chapterTitles;
    }
    return [];
  }

  private getChapters(): CatalogChapter[] {
    const keyword = this.query.trim();
    const allChapters = this.getAllChapters();
    const volumeFlags = this.book.chapterVolumes;
    const chapters: CatalogChapter[] = [];
    const searching = keyword.length > 0;
    let insideCollapsedVolume = false;
    for (let index = 0; index < allChapters.length; index++) {
      const title = allChapters[index];
      if (title === undefined) { continue; }
      const isVolume = volumeFlags?.[index] === true;
      if (!searching) {
        if (isVolume) { insideCollapsedVolume = this.collapsedVolumes.has(index); }
        else if (insideCollapsedVolume) { continue; }
      }
      const displayTitle = this.useTitleReplacement ? ReplaceRuleRepository.applyTitle(this.book, title) : title;
      if (displayTitle.includes(keyword)) {
        chapters.push({ title: displayTitle, index: index, isVolume: isVolume,
          isInVolume: !isVolume && this.isInsideAnyVolume(index, volumeFlags) });
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

  private isInsideAnyVolume(chapterIndex: number, volumeFlags: boolean[] | undefined): boolean {
    if (volumeFlags === undefined) { return false; }
    for (let index = chapterIndex - 1; index >= 0; index--) {
      if (volumeFlags[index] === true) { return true; }
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

  private getMarkingEffectLabel(effect: ReaderMarkingEffect): string {
    if (effect === 'solid') { return '下划线'; }
    if (effect === 'double') { return '双下划线'; }
    if (effect === 'dashed') { return '虚线'; }
    if (effect === 'wave') { return '波浪线'; }
    if (effect === 'strike') { return '删除线'; }
    if (effect === 'highlight') { return '强调线'; }
    if (effect === 'background') { return '背景高亮'; }
    return '文字颜色';
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

  private async loadChapterWordCounts(): Promise<void> {
    if (this.book.contentPath === undefined || this.book.bodyMissing === true || this.wordCountsLoading) { return; }
    const generation = ++this.wordCountGeneration;
    this.wordCountsLoading = true;
    const counts = new Map<number, string>();
    try {
      await BookRepository.forEachChapter(
        this.book,
        async (content: string, chapterIndex: number): Promise<boolean> => {
          if (generation !== this.wordCountGeneration) { return false; }
          counts.set(chapterIndex, this.formatWordCount(content.length));
          return true;
        },
        false
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

  /** 当前书是否为可重新识别目录的本地 TXT。 */
  private isLocalTxt(): boolean {
    return this.book.isLocal && this.book.format === 'txt' && this.book.contentPath !== undefined;
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
            .backgroundColor('#1A1B21').layoutWeight(1).borderRadius(12)
            .onChange((value: string) => this.query = value)
          if (this.query.length > 0) {
            AppGlyph({ name: 'profileClose', glyphSize: 16, tint: '#C5C7D0' })
              .width(32).onClick(() => this.query = '')
          }
          AppGlyph({ name: 'profileFindReplace', glyphSize: 17,
            tint: this.useTitleReplacement ? '#AFC2FF' : '#D8D9E0' })
            .width(32)
            .onClick(() => this.onTitleReplacementChange(!this.useTitleReplacement))
          AppGlyph({ name: 'profileTimeline', glyphSize: 17,
            tint: this.showWordCount ? '#AFC2FF' : '#D8D9E0' })
            .width(32)
            .onClick(() => this.toggleShowWordCount())
          AppGlyph({ name: 'swap', glyphSize: 18, tint: this.ascending ? '#D8D9E0' : '#AFC2FF' })
            .width(32).onClick(() => this.ascending = !this.ascending)
          Stack({ alignContent: Alignment.Center }) {
            AppGlyph({ name: 'more', glyphSize: 18, tint: '#D8D9E0' })
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

        if (this.getChapters().length === 0) {
          Column() {
            Text(this.query.trim().length > 0 ? '没有找到相关章节' : '暂无目录')
              .fontSize(13).fontColor('#AEB0B9')
          }.width('100%').layoutWeight(1).justifyContent(FlexAlign.Center)
        } else {
          List({ scroller: this.chapterScroller }) {
            ForEach(this.getChapters(), (chapter: CatalogChapter) => {
              ListItem() {
                Row() {
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
                .padding({ left: chapter.isInVolume ? 26 : 12, right: 12, top: 11, bottom: 11 })
                .backgroundColor(this.isChapterSelected(chapter.index) ? '#454B62' : '#1A1B21')
                .borderRadius(10)
                .onClick(() => chapter.isVolume ? this.toggleVolume(chapter.index) : this.onSelectChapter(chapter.index))
              }.margin({ left: 12, right: 12, bottom: 6 })
            }, (chapter: CatalogChapter) => `${chapter.index}_${chapter.isVolume ? 1 : 0}_${chapter.isInVolume ? 1 : 0}_${this.collapsedVolumes.has(chapter.index) ? 1 : 0}`)
          }
          .layoutWeight(1)
          .scrollBar(BarState.Off)
          .onAreaChange(() => this.scrollToCurrentChapter())
        }
      }
      .width('100%')
      .height('100%')
    } else if (tab === 2) {
      Column() {
        Row() {
          Text('书签 ' + this.bookmarks.length.toString()).fontSize(11).fontColor('#AEB0B9')
          Blank()
          Stack({ alignContent: Alignment.Center }) {
            AppGlyph({ name: 'more', glyphSize: 18, tint: '#D8D9E0' })
          }
          .width(32)
          .height(32)
          .bindMenu(this.BookmarkExportMenu, { placement: Placement.BottomRight })
        }
        .width('100%')
        .padding({ left: 16, right: 12, bottom: 6 })

        if (this.bookmarks.length === 0) {
          Column() {
            AppGlyph({ name: 'bookmark', glyphSize: 30, tint: '#AFC2FF' })
            Text('暂无书签').fontSize(14).fontColor('#AEB0B9').margin({ top: 8 })
          }
          .width('100%')
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)
        } else {
          Scroll() {
            Column() {
              ForEach(this.bookmarks, (bookmark: ReaderBookmark) => {
                Column() {
                  Row() {
                    Text(bookmark.chapterName).fontSize(13).fontColor('#AFC2FF')
                      .layoutWeight(1).maxLines(1)
                    Text('跳转').fontSize(11).fontColor('#D7DFFB')
                      .padding({ left: 10, right: 10, top: 6, bottom: 6 })
                      .backgroundColor('#454B62').borderRadius(14)
                      .onClick(() => this.onOpenBookmark(bookmark.id))
                    Text('编辑').fontSize(11).fontColor('#C5C7D0')
                      .padding({ left: 10, right: 10, top: 6, bottom: 6 })
                      .margin({ left: 6 }).backgroundColor('#292A31').borderRadius(14)
                      .onClick(() => this.onEditBookmark(bookmark.id))
                  }
                  if (bookmark.bookText.length > 0) {
                    Text(bookmark.bookText).fontSize(12).fontColor('#D4D5DB')
                      .maxLines(3).margin({ top: 7 }).textOverflow({ overflow: TextOverflow.Ellipsis })
                  }
                  if (bookmark.content.length > 0) {
                    Text(bookmark.content).fontSize(11).fontColor('#AEB0B9')
                      .maxLines(2).margin({ top: 5 }).textOverflow({ overflow: TextOverflow.Ellipsis })
                  }
                }
                .width('100%')
                .padding(12)
                .backgroundColor('#1A1B21')
                .borderRadius(10)
                .margin({ bottom: 6 })
              }, (bookmark: ReaderBookmark) => bookmark.id)
            }
            .padding({ left: 12, right: 12, bottom: 14 })
          }
          .width('100%')
          .layoutWeight(1)
          .scrollBar(BarState.Off)
        }
      }
      .width('100%')
      .height('100%')
    } else {
      if (this.markings.length === 0) {
        Column() {
          AppGlyph({ name: 'profileNoteAdd', glyphSize: 28, tint: '#AFC2FF' })
          Text('暂无笔记').fontSize(14).fontColor('#AEB0B9').margin({ top: 8 })
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
      } else {
        Scroll() {
          Column() {
            ForEach(this.markings, (marking: ReaderMarking) => {
              Column() {
                Row() {
                  Text(marking.chapterName).fontSize(13).fontColor('#AFC2FF')
                    .layoutWeight(1).maxLines(1)
                  Text(this.getMarkingEffectLabel(marking.effect)).fontSize(10).fontColor(marking.color)
                    .padding({ left: 8, right: 8, top: 5, bottom: 5 })
                    .backgroundColor('#292A31').borderRadius(12)
                }
                Text(marking.selectedText).fontSize(13).fontColor('#E0E1E6').lineHeight(19)
                  .maxLines(4).width('100%').margin({ top: 7 })
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                  .onClick(() => this.onEditMarking(marking.id))
                if (marking.note.trim().length > 0) {
                  Text(marking.note).fontSize(12).fontColor('#AEB0B9').lineHeight(17)
                    .maxLines(3).width('100%').margin({ top: 6 })
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                }
                Row() {
                  Blank()
                  Text('定位').fontSize(11).fontColor('#D7DFFB')
                    .padding({ left: 10, right: 10, top: 6, bottom: 6 })
                    .backgroundColor('#454B62').borderRadius(14)
                    .onClick(() => this.onOpenMarking(marking.id))
                  Text('编辑').fontSize(11).fontColor('#C5C7D0')
                    .padding({ left: 10, right: 10, top: 6, bottom: 6 }).margin({ left: 6 })
                    .backgroundColor('#292A31').borderRadius(14)
                    .onClick(() => this.onEditMarking(marking.id))
                }.width('100%').margin({ top: 8 })
              }
              .width('100%').padding(12)
              .backgroundColor(marking.chapterName === this.selectedChapter ? '#303442' : '#1A1B21')
              .borderRadius(10).margin({ bottom: 6 })
            }, (marking: ReaderMarking) => this.markingItemKey(marking))
          }.padding({ left: 12, right: 12, bottom: 14 })
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
              .backgroundColor(this.selectedTab === index ? '#454B62' : '#1C1D23')
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
  @Prop label: string = '';
  @Prop value: string = '';

  build() {
    Column() {
      Text(this.label)
        .fontSize(11)
        .fontWeight(FontWeight.Medium)
        .fontColor('#AFC2FF')
      Text(this.value.trim().length > 0 ? this.value : '--')
        .fontSize(13)
        .fontColor('#D4D5DB')
        .lineHeight(19)
        .margin({ top: 3 })
    }
    .width('100%')
    .padding({ left: 12, right: 12, top: 10, bottom: 10 })
    .backgroundColor('#1A1B21')
    .borderRadius(14)
  }
}
