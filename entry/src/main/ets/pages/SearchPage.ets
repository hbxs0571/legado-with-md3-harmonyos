import curves from '@ohos.curves';
import { Book } from '../model/Book';
import { BookGroup } from '../model/BookGroup';
import { BookRepository } from '../data/BookRepository';
import { BookSourceRepository } from '../data/BookSourceRepository';
import { BookCover } from '../components/BookCover';
import { AppGlyph } from '../components/AppGlyph';
import { AppTopBar, TopBarButton, TopBarBackButton } from '../components/TopBar';
import { CoverSettings, DEFAULT_COVER_SETTINGS } from '../data/CoverSettingsRepository';
import { SearchCoordinator, SearchProgress, SearchOutcome } from '../bookSource/SearchCoordinator';
import { MergedBook } from '../bookSource/SearchResultMerger';
import { SearchBookItem } from '../bookSource/SourceModels';

@Component
export struct SearchPage {
  @StorageProp('themeColorTextPrimary') themeColorTextPrimary: string = '#1B1C22';
  @StorageProp('themeColorTextSecondary') themeColorTextSecondary: string = '#2E3038';
  @StorageProp('themeColorTextTertiary') themeColorTextTertiary: string = '#6A6D77';
  @StorageProp('themeColorAccent') themeColorAccent: string = '#3F5BD9';
  @StorageProp('themeColorSurfacePrimary') themeColorSurfacePrimary: string = '#F5F6F8';
  @StorageProp('themeColorSurfaceTertiary') themeColorSurfaceTertiary: string = '#F0F1F5';
  @StorageProp('themeColorSurfaceElevated') themeColorSurfaceElevated: string = '#FFFFFF';
  @StorageProp('themeAppBackground') themeAppBackground: string = '';
  @StorageProp('themePureBlack') themePureBlack: boolean = false;
  @StorageProp('themeItemBackground') themeItemBackground: string = '';
  @Prop books: Book[] = [];
  @Prop groups: BookGroup[] = [];
  @Prop @Watch('onQueryChanged') query: string = '';
  @Prop selectedGroup: string = '全部书籍';
  @Prop @Watch('onScopeChanged') sourceScope: boolean = false;
  @Prop exactMatch: boolean = false;
  /** 封面文字设置，从 Index 下发；搜索结果封面受 A8「限制封面比例」约束。 */
  @Prop coverSettings: CoverSettings = DEFAULT_COVER_SETTINGS;
  @State showScopePanel: boolean = false;
  @State collapsedHeader: boolean = false;
  /** 在线多源搜索：结果快照、进度、四态。 */
  @State onlineBooks: MergedBook[] = [];
  @State onlineSearching: boolean = false;
  @State onlineSearchDone: boolean = false;
  @State onlineProgressText: string = '';
  /** 在线结果视图：平铺 / 按源分组。 */
  @State onlineViewMode: 'flat' | 'grouped' = 'flat';
  private cancelSearchFlag: boolean = false;
  private onlineScroller: Scroller = new Scroller();
  private suggestionScroller: Scroller = new Scroller();
  private resultsScroller: Scroller = new Scroller();
  onBack: () => void = () => {};
  onOpenBook: (book: Book) => void = (_book: Book) => {};
  /** 在线书加入书架（P3-E）。MergedBook 在 Index 侧转成在线 Book 落库。 */
  onAddOnlineBook: (item: MergedBook) => void = (_item: MergedBook) => {};
  onOpenSourceManage: () => void = () => {};
  onUnavailableAction: (message: string) => void = (_message: string) => {};
  onQueryChange: (query: string) => void = (_query: string) => {};
  onGroupChange: (group: string) => void = (_group: string) => {};
  onSourceScopeChange: (enabled: boolean) => void = (_enabled: boolean) => {};
  onExactMatchChange: (enabled: boolean) => void = (_enabled: boolean) => {};

  private getLocalBooks(): Book[] {
    return this.books.filter((book: Book) => BookRepository.isPersistableBook(book));
  }

  private getBookGroupNames(book: Book): string[] {
    if ((book.groupNames ?? []).length > 0) { return book.groupNames ?? []; }
    const legacyName = book.groupName?.trim() ?? '';
    return legacyName.length > 0 && legacyName !== '本地未分组' ? [legacyName] : [];
  }

  private getGroups(): string[] {
    const localBooks = this.getLocalBooks();
    const groups: string[] = ['全部书籍'];
    if (localBooks.some((book: Book) => this.getBookGroupNames(book).length === 0)) { groups.push('本地未分组'); }
    const userGroups = this.groups.filter((group: BookGroup) => group.groupId > 0);
    userGroups.filter((group: BookGroup) => group.show)
      .sort((left: BookGroup, right: BookGroup) => left.order - right.order)
      .forEach((group: BookGroup) => { if (!groups.includes(group.groupName)) { groups.push(group.groupName); } });
    localBooks.forEach((book: Book) => {
      this.getBookGroupNames(book).forEach((name: string) => {
        const definition = userGroups.find((group: BookGroup) => group.groupName === name);
        if (definition === undefined && !groups.includes(name)) { groups.push(name); }
      });
    });
    return groups;
  }

  private getResults(): Book[] {
    const keyword = this.query.trim().toLocaleLowerCase();
    if (keyword.length === 0 || this.sourceScope) { return []; }
    return this.getLocalBooks().filter((book: Book) => {
      const names = this.getBookGroupNames(book);
      const matchesGroup = this.selectedGroup === '全部书籍' ||
        (this.selectedGroup === '本地未分组' ? names.length === 0 : names.includes(this.selectedGroup));
      const title = book.title.toLocaleLowerCase();
      const author = book.author.toLocaleLowerCase();
      const matchesKeyword = this.exactMatch
        ? title === keyword || author === keyword
        : title.includes(keyword) || author.includes(keyword);
      return matchesGroup && matchesKeyword;
    });
  }

  /** 触发在线多源搜索：先确保书源缓存已载入，再并发搜索并增量刷新结果。 */
  private async startOnlineSearch(): Promise<void> {
    const keyword = this.query.trim();
    if (keyword.length === 0) {
      this.onUnavailableAction('请输入书名或作者');
      return;
    }
    if (this.onlineSearching) { return; }
    try {
      await BookSourceRepository.load(getContext(this));
    } catch (e) {
      this.onUnavailableAction('书源载入失败：' + String(e));
      return;
    }
    if (!SearchCoordinator.hasSearchableSource()) {
      this.onUnavailableAction('没有可搜索的在线书源，请先到书源管理导入并启用');
      return;
    }
    this.cancelSearchFlag = false;
    this.onlineBooks = [];
    this.onlineSearchDone = false;
    this.onlineSearching = true;
    this.onlineProgressText = '正在连接书源…';
    const outcome: SearchOutcome = await SearchCoordinator.search(
      keyword, 1, this.exactMatch,
      (p: SearchProgress) => {
        this.onlineBooks = p.books;
        this.onlineProgressText = `已搜索 ${p.finished}/${p.total} 个源 · ${p.books.length} 条结果` +
          (p.error ? ` · 最近失败：${p.sourceName}` : '');
      },
      () => this.cancelSearchFlag
    );
    this.onlineBooks = outcome.books;
    this.onlineSearching = false;
    this.onlineSearchDone = true;
    this.onlineProgressText = outcome.cancelled
      ? '搜索已取消'
      : `完成：${outcome.sourceFinished}/${outcome.sourceTotal} 个源 · ${outcome.books.length} 条结果`;
  }

  /** 退出/返回时真取消后台请求。 */
  private cancelOnlineSearch(): void {
    this.cancelSearchFlag = true;
    this.onlineSearching = false;
  }

  /** 输入变化防抖 400ms 后自动重搜；仅在线范围生效。 */
  private queryDebounceTimer: number = 0;
  private onQueryChanged(): void {
    this.onlineBooks = [];
    this.onlineSearchDone = false;
    if (!this.sourceScope || this.query.trim().length === 0) { return; }
    clearTimeout(this.queryDebounceTimer);
    this.queryDebounceTimer = setTimeout(() => {
      void this.startOnlineSearch();
    }, 400);
  }

  /** 切到在线范围且有关键词时立即拉起搜索。 */
  private onScopeChanged(): void {
    if (this.sourceScope && this.query.trim().length > 0) {
      void this.startOnlineSearch();
    } else if (!this.sourceScope) {
      this.cancelOnlineSearch();
    }
  }

  private searchOnline(): void {
    void this.startOnlineSearch();
  }

  private updateHeader(offset: number): void {
    const shouldCollapse = offset > 70 ? true : offset < 24 ? false : this.collapsedHeader;
    if (shouldCollapse !== this.collapsedHeader) {
      // 顶部折叠是位移，用弹簧收尾更自然；弹簧不吃 duration，删掉（写了也不生效）。
      this.getUIContext().animateTo({ curve: curves.springMotion(0.35, 0.86) }, () => {
        this.collapsedHeader = shouldCollapse;
      });
    }
  }

  @Builder searchNavSlot() {
    TopBarBackButton({ onSelect: () => this.onBack() })
  }

  /** 在线结果区：四态（搜索中转圈 / 无结果 / 结果列表尾部提示 / 结束）+ 两视图。 */
  @Builder onlineResultsView() {
    Column() {
      // 结果条 + 视图切换 + 进度
      Row() {
        Text(`在线书源 · ${this.onlineBooks.length}`).fontSize(16).fontColor(this.themeColorAccent)
        Blank()
        if (this.onlineSearching) {
          Text(this.onlineProgressText).fontSize(11).fontColor(this.themeColorTextTertiary).maxLines(1)
            .layoutWeight(1).margin({ left: 8 })
          Text('取消').fontSize(13).fontColor(this.themeColorAccent).margin({ left: 8 })
            .onClick(() => this.cancelOnlineSearch())
        } else {
          Text(this.onlineViewMode === 'flat' ? '平铺' : '按源')
            .fontSize(13).fontColor(this.themeColorAccent).margin({ left: 8 })
            .onClick(() => {
              this.onlineViewMode = this.onlineViewMode === 'flat' ? 'grouped' : 'flat';
            })
        }
      }.width('100%').padding({ left: 18, right: 18, top: 7, bottom: 8 })

      if (this.onlineSearching && this.onlineBooks.length === 0) {
        Column() {
          LoadingProgress().width(36).height(36).color(this.themeColorAccent)
          Text('正在搜索在线书源…').fontSize(14).fontColor(this.themeColorTextTertiary).margin({ top: 12 })
          Text(this.onlineProgressText).fontSize(12).fontColor(this.themeColorTextTertiary).margin({ top: 6 })
        }.layoutWeight(1).justifyContent(FlexAlign.Center)
      } else if (this.onlineSearchDone && this.onlineBooks.length === 0) {
        SearchEmptyState({ title: '没有找到相关书籍', detail: '换个关键词，或到书源管理检查启用的书源。' })
      } else {
        Scroll(this.onlineScroller) {
          Column() {
            if (this.onlineViewMode === 'flat') {
              ForEach(this.onlineBooks, (item: MergedBook, index: number) => {
                OnlineBookRow({ item: item, coverSettings: this.coverSettings,
                  onSelect: () => this.onOpenOnlineBook(item) })
              }, (item: MergedBook, index: number) => item.book.bookUrl + '_' + index)
            } else {
              ForEach(this.groupOnlineBooks(), (group: OnlineSourceGroup) => {
                Column() {
                  Row() {
                    Text(group.originName).fontSize(13).fontColor(this.themeColorAccent)
                      .fontWeight(FontWeight.Medium)
                    Text(` ${group.items.length}`).fontSize(12).fontColor(this.themeColorTextTertiary)
                  }.width('100%').padding({ left: 4, top: 10, bottom: 6 })
                  ForEach(group.items, (item: MergedBook, index: number) => {
                    OnlineBookRow({ item: item, coverSettings: this.coverSettings,
                      onSelect: () => this.onOpenOnlineBook(item) })
                  }, (item: MergedBook, index: number) => item.book.bookUrl + '_' + index)
                }.width('100%')
              }, (group: OnlineSourceGroup, index: number) => group.origin + '_' + index)
            }
            // 尾部四态
            if (this.onlineSearching) {
              Row() {
                LoadingProgress().width(18).height(18).color(this.themeColorAccent)
                Text(' 加载中…').fontSize(13).fontColor(this.themeColorTextTertiary)
              }.justifyContent(FlexAlign.Center).width('100%').padding({ top: 14, bottom: 14 })
            } else if (this.onlineSearchDone) {
              Text('已显示全部结果').fontSize(12).fontColor(this.themeColorTextTertiary)
                .width('100%').textAlign(TextAlign.Center).padding({ top: 14, bottom: 14 })
            }
          }.padding({ bottom: 12 })
        }.edgeEffect(EdgeEffect.Spring, { alwaysEnabled: false }).layoutWeight(1).scrollBar(BarState.Off)
          .onScroll(() => this.updateHeader(this.onlineScroller.currentOffset().yOffset))
      }
    }.layoutWeight(1).width('100%')
  }

  /** 按源分组：一条书若命中多源，归到它 origins[0]。 */
  private groupOnlineBooks(): OnlineSourceGroup[] {
    const groups: Map<string, OnlineSourceGroup> = new Map<string, OnlineSourceGroup>();
    for (const item of this.onlineBooks) {
      const origin = item.origins.length > 0 ? item.origins[0] : '';
      let group = groups.get(origin);
      if (group === undefined) {
        const created: OnlineSourceGroup = {
          origin: origin, originName: item.book.originName || origin, items: []
        };
        groups.set(origin, created);
        group = created;
      }
      group.items.push(item);
    }
    return Array.from(groups.values());
  }

  /**
   * 在线书点击（P3-E）：加入书架并打开阅读。
   * 对应上游 AddToBookshelfUseCase（搜索结果 → Book → 判重 → 落库）后进入阅读页。
   * 判重与落库在 Index 侧完成（它持有 books 与 context）。
   */
  private onOpenOnlineBook(item: MergedBook): void {
    this.onAddOnlineBook(item);
  }

  @Builder searchTopActions() {
    TopBarButton({ icon: 'settings', showDivider: false, onSelect: () => this.onUnavailableAction('搜索设置将在在线书源搜索接入后提供') })
    TopBarButton({
      icon: this.exactMatch ? 'searchPrecisionOn' : 'searchPrecisionOff',
      tint: this.exactMatch ? this.themeColorAccent : '',
      onSelect: () => this.onExactMatchChange(!this.exactMatch)
    })
    TopBarButton({
      icon: 'profileFilterAlt',
      tint: this.sourceScope || this.selectedGroup !== '全部书籍' ? this.themeColorAccent : '',
      onSelect: () => { this.showScopePanel = true; }
    })
  }

  build() {
    Stack() {
      Column() {
        AppTopBar({
          title: '搜索',
          collapsed: this.collapsedHeader,
          hasNavigation: true,
          navigationIcon: () => { this.searchNavSlot() },
          actions: () => { this.searchTopActions() }
        })

        Row() {
          AppGlyph({ name: 'search', glyphSize: 19, tint: '#C5C7D0' }).margin({ right: 9 })
          TextInput({ placeholder: '搜索书名、作者或书源…', text: this.query })
            .fontSize(17).fontColor(this.themeColorTextPrimary).placeholderColor(this.themeColorTextTertiary)
            .backgroundColor(Color.Transparent).layoutWeight(1)
            .onChange((value: string) => { this.collapsedHeader = false; this.onQueryChange(value); })
          if (this.query.length > 0) {
            Text('清除').fontSize(14).fontColor(this.themeColorAccent).margin({ left: 8 })
              .onClick(() => this.onQueryChange(''))
          }
        }.width('100%').padding({ left: 14, right: 14, top: 11, bottom: 11 })
          .margin({ left: 16, right: 16, top: 7, bottom: 8 })
          .backgroundColor(this.themeAppBackground.length > 0 ? Color.Transparent : (this.themePureBlack ? '#0A0A0A' : this.themeColorSurfaceTertiary)).borderRadius(24)

        if (this.query.trim().length === 0) {
          Scroll(this.suggestionScroller) {
            Column() {
              Row() {
                Text('书架').fontSize(18).fontWeight(FontWeight.Medium).fontColor(this.themeColorTextSecondary).layoutWeight(1)
                Text('本地').fontSize(13).fontColor(this.themeColorTextTertiary)
              }.padding({ left: 18, right: 18, top: 12, bottom: 8 })
              if (this.getLocalBooks().length === 0) {
                SearchEmptyState({ title: '书架暂无书籍', detail: '导入 TXT 或 EPUB 后，可在此搜索书名和作者。' })
              } else {
                ForEach(this.getLocalBooks(), (book: Book) => {
                  SearchBookRow({ book: book, coverSettings: this.coverSettings, onSelect: () => this.onOpenBook(book) })
                }, (book: Book) => book.id)
              }
              Row() {
                Text('搜索历史').fontSize(18).fontWeight(FontWeight.Medium).fontColor(this.themeColorTextSecondary).layoutWeight(1)
              }.padding({ left: 18, right: 18, top: 18, bottom: 8 })
              SearchEmptyState({ title: '暂无搜索历史', detail: '在线搜索记录将在搜索能力接入后显示。' })
            }.padding({ bottom: 18 })
          }.edgeEffect(EdgeEffect.Spring, { alwaysEnabled: false }).layoutWeight(1).scrollBar(BarState.Off)
            .onScroll(() => this.updateHeader(this.suggestionScroller.currentOffset().yOffset))
        } else if (this.sourceScope) {
          // 进入在线范围即触发搜索；关键词变化由外部 onQueryChange 驱动，此处只在首次进入时拉起。
          Column() {
            this.onlineResultsView()
            Row() {
              Text('管理书源').fontSize(14).fontColor(this.themeColorAccent)
            }.justifyContent(FlexAlign.Center).padding({ left: 22, right: 22, top: 10, bottom: 12 })
              .onClick(() => this.onOpenSourceManage())
          }.layoutWeight(1).width('100%')
        } else {
          if (this.getResults().length === 0) {
            Column() {
              SearchEmptyState({ title: '本地书架没有匹配结果', detail: '可调整书名或作者，在线书源搜索将在 P5 接入。' })
              Row() {
                Text('搜索在线书源').fontSize(16).fontColor('#151720').fontWeight(FontWeight.Medium)
              }.justifyContent(FlexAlign.Center).padding({ left: 22, right: 22, top: 13, bottom: 13 })
                .backgroundColor('#B9C8FF').borderRadius(24).margin({ bottom: 18 })
                .onClick(() => this.searchOnline())
            }.layoutWeight(1).width('100%').justifyContent(FlexAlign.Center)
          } else {
            Column() {
              Row() {
                Text(`本地书籍 · ${this.getResults().length}`).fontSize(16).fontColor(this.themeColorAccent)
                Blank()
                Text('点按继续阅读').fontSize(13).fontColor(this.themeColorTextTertiary)
              }.width('100%').padding({ left: 18, right: 18, top: 7, bottom: 8 })
              Scroll(this.resultsScroller) {
                Column() {
                  ForEach(this.getResults(), (book: Book) => {
                    SearchBookRow({ book: book, coverSettings: this.coverSettings, onSelect: () => this.onOpenBook(book) })
                  }, (book: Book) => book.id)
                }.padding({ bottom: 12 })
              }.edgeEffect(EdgeEffect.Spring, { alwaysEnabled: false }).layoutWeight(1).scrollBar(BarState.Off)
                .onScroll(() => this.updateHeader(this.resultsScroller.currentOffset().yOffset))
              Row() {
                Text('搜索在线书源').fontSize(16).fontColor('#151720').fontWeight(FontWeight.Medium)
              }.justifyContent(FlexAlign.Center).padding({ left: 22, right: 22, top: 13, bottom: 13 })
                .backgroundColor('#B9C8FF').borderRadius(24).margin({ bottom: 18 })
                .onClick(() => this.searchOnline())
            }.layoutWeight(1)
          }
        }
      }.width('100%').height('100%').backgroundColor(this.themeAppBackground.length > 0 ? Color.Transparent : (this.themePureBlack ? '#000000' : this.themeColorSurfacePrimary))

      if (this.showScopePanel) {
        SearchScopePanel({
          groups: this.getGroups(),
          selectedGroup: this.selectedGroup,
          sourceScope: this.sourceScope,
          onClose: () => this.showScopePanel = false,
          onGroupSelect: (group: string) => {
            this.onGroupChange(group);
            this.onSourceScopeChange(false);
            this.showScopePanel = false;
          },
          onSelectSources: () => {
            this.onSourceScopeChange(true);
            this.showScopePanel = false;
          },
          onOpenSourceManage: () => {
            this.showScopePanel = false;
            this.onOpenSourceManage();
          }
        }).transition(TransitionEffect.OPACITY.animation({ duration: 220, curve: Curve.EaseInOut }))
      }
    }.width('100%').height('100%').backgroundColor(this.themeAppBackground.length > 0 ? Color.Transparent : (this.themePureBlack ? '#000000' : this.themeColorSurfacePrimary))
  }
}

@Component
struct SearchBookRow {
  @StorageProp('themeColorTextPrimary') themeColorTextPrimary: string = '#1B1C22';
  @StorageProp('themeColorTextSecondary') themeColorTextSecondary: string = '#2E3038';
  @StorageProp('themeColorSurfaceElevated') themeColorSurfaceElevated: string = '#FFFFFF';
  @StorageProp('themeAppBackground') themeAppBackground: string = '';
  @StorageProp('themePureBlack') themePureBlack: boolean = false;
  @Prop book: Book = {
    id: '', title: '', author: '', category: '', lastChapter: '', progress: 0, isLocal: true
  };
  /** 封面文字设置，由 SearchPage 透传；搜索行封面受 A8「限制封面比例」约束。 */
  @Prop coverSettings: CoverSettings = DEFAULT_COVER_SETTINGS;
  onSelect: () => void = () => {};
  @StorageProp('themeItemBackground') themeItemBackground: string = '';
  build() {
    Row() {
      BookCover({ book: this.book, compact: true, coverSettings: this.coverSettings, applyAspectRatio: true })
      Column() {
        Text(this.book.title).fontSize(17).fontColor(this.themeColorTextPrimary).maxLines(1)
        Text(this.book.author).fontSize(14).fontColor('#AEB0BA').margin({ top: 5 }).maxLines(1)
        Text(this.book.lastChapter).fontSize(13).fontColor('#858792').margin({ top: 6 }).maxLines(1)
      }.alignItems(HorizontalAlign.Start).layoutWeight(1).margin({ left: 14 })
      Text(`${Math.round(this.book.progress)}%`).fontSize(13).fontColor(this.themeColorTextSecondary)
    }.width('100%').padding(12).backgroundColor(this.themeAppBackground.length > 0 ? Color.Transparent : (this.themePureBlack ? '#121212' : this.themeColorSurfaceElevated)).borderRadius(14).backgroundImage(this.themeItemBackground.length > 0 ? `file://${this.themeItemBackground}` : $r('app.media.transparent_pixel'), ImageRepeat.NoRepeat)
      .margin({ left: 16, right: 16, bottom: 9 }).onClick(() => this.onSelect())
  }
}

/** 按源分组的一组在线结果。 */
interface OnlineSourceGroup {
  origin: string;
  originName: string;
  items: MergedBook[];
}

/** 在线结果卡片：书名/作者/来源数/最新章节，命中多源时显示角标。 */
@Component
struct OnlineBookRow {
  @StorageProp('themeColorTextPrimary') themeColorTextPrimary: string = '#1B1C22';
  @StorageProp('themeColorTextTertiary') themeColorTextTertiary: string = '#6A6D77';
  @StorageProp('themeColorSurfaceElevated') themeColorSurfaceElevated: string = '#FFFFFF';
  @StorageProp('themeColorAccent') themeColorAccent: string = '#3F5BD9';
  @StorageProp('themeAppBackground') themeAppBackground: string = '';
  @StorageProp('themePureBlack') themePureBlack: boolean = false;
  @Prop item: MergedBook = { book: {
    bookUrl: '', origin: '', originName: '', name: '', author: '', kind: '', coverUrl: '',
    intro: '', lastChapter: '', wordCount: '', updateTime: '', tocUrl: ''
  }, origins: [], originCount: 0 };
  @Prop coverSettings: CoverSettings = DEFAULT_COVER_SETTINGS;
  onSelect: () => void = () => {};
  build() {
    Row() {
      Column() {
        Row() {
          Text(this.item.book.name).fontSize(16).fontColor(this.themeColorTextPrimary).maxLines(1)
            .layoutWeight(1)
          if (this.item.originCount > 1) {
            Text(`${this.item.originCount} 源`).fontSize(11).fontColor('#FFFFFF')
              .backgroundColor(this.themeColorAccent).borderRadius(9).padding({ left: 6, right: 6, top: 2, bottom: 2 })
              .margin({ left: 6 })
          }
        }.width('100%')
        Text(this.item.book.author || '佚名').fontSize(13).fontColor(this.themeColorTextTertiary).margin({ top: 5 }).maxLines(1)
        Row() {
          Text(this.item.book.lastChapter).fontSize(12).fontColor(this.themeColorTextTertiary).maxLines(1)
            .layoutWeight(1)
          Text(this.item.book.originName).fontSize(11).fontColor(this.themeColorTextTertiary).margin({ left: 6 }).maxLines(1)
        }.width('100%').margin({ top: 6 })
      }.alignItems(HorizontalAlign.Start).layoutWeight(1)
    }.width('100%').padding(12)
      .backgroundColor(this.themeAppBackground.length > 0 ? Color.Transparent : (this.themePureBlack ? '#121212' : this.themeColorSurfaceElevated))
      .borderRadius(14).margin({ left: 16, right: 16, bottom: 9 }).onClick(() => this.onSelect())
  }
}

@Component
struct SearchEmptyState {
  @StorageProp('themeColorTextSecondary') themeColorTextSecondary: string = '#2E3038';
  @StorageProp('themeColorTextTertiary') themeColorTextTertiary: string = '#6A6D77';
  @StorageProp('themeColorAccent') themeColorAccent: string = '#3F5BD9';
  @Prop title: string = '';
  @Prop detail: string = '';
  build() {
    Column() {
      AppGlyph({ name: 'search', glyphSize: 30, tint: this.themeColorAccent }).margin({ bottom: 14 })
      Text(this.title).fontSize(17).fontColor(this.themeColorTextSecondary)
      Text(this.detail).fontSize(14).fontColor(this.themeColorTextTertiary).textAlign(TextAlign.Center)
        .margin({ left: 28, right: 28, top: 8 })
    }.width('100%').padding({ top: 34, bottom: 34 })
      .justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
  }
}

@Component
struct SearchScopePanel {
  @StorageProp('themeColorTextPrimary') themeColorTextPrimary: string = '#1B1C22';
  @StorageProp('themeColorTextSecondary') themeColorTextSecondary: string = '#2E3038';
  @StorageProp('themeColorAccent') themeColorAccent: string = '#3F5BD9';
  @StorageProp('themeColorSurfaceSecondary') themeColorSurfaceSecondary: string = '#FFFFFF';
  @Prop groups: string[] = [];
  @Prop selectedGroup: string = '全部书籍';
  @Prop sourceScope: boolean = false;
  onClose: () => void = () => {};
  onGroupSelect: (group: string) => void = (_group: string) => {};
  onSelectSources: () => void = () => {};
  onOpenSourceManage: () => void = () => {};
  @State sourceTab: boolean = false;
  aboutToAppear(): void {
    this.sourceTab = this.sourceScope;
  }
  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      Column().width('100%').height('100%').backgroundColor('#99000000').onClick(() => this.onClose())
      Column() {
        Row() {
          Text('搜索范围').fontSize(20).fontWeight(FontWeight.Bold).fontColor(this.themeColorTextPrimary).layoutWeight(1)
          Text('完成').fontSize(15).fontColor(this.themeColorAccent).onClick(() => this.onClose())
        }.width('100%').padding({ left: 20, right: 20, top: 20, bottom: 14 })
        Row() {
          SearchScopeTab({ title: '书架分组', selected: !this.sourceTab, onSelect: () => this.sourceTab = false })
          SearchScopeTab({ title: '书源', selected: this.sourceTab, onSelect: () => this.sourceTab = true })
        }.padding({ left: 16, right: 16, bottom: 12 })
        if (!this.sourceTab) {
          List() {
            ForEach(this.groups, (group: string) => {
              ListItem() {
                Row() {
                  Text(group).fontSize(17).fontColor(this.themeColorTextSecondary).layoutWeight(1)
                  if (group === this.selectedGroup && !this.sourceScope) {
                    AppGlyph({ name: 'profileCheck', glyphSize: 18, tint: this.themeColorAccent })
                  }
                }.width('100%').padding({ left: 18, right: 18, top: 15, bottom: 15 })
                  .backgroundColor(this.themeColorSurfaceSecondary).borderRadius(12).margin({ left: 14, right: 14, bottom: 6 })
                  .onClick(() => this.onGroupSelect(group))
              }
            }, (group: string) => group)
          }.height(260).scrollBar(BarState.Off)
        } else {
          Column() {
            SearchEmptyState({ title: '尚无可选书源', detail: '书源搜索将在 P5 接入。可以先打开书源管理页面。' })
            Row() {
              Text('选择全部书源').fontSize(16).fontColor('#151720').fontWeight(FontWeight.Medium)
            }.justifyContent(FlexAlign.Center).padding({ left: 22, right: 22, top: 13, bottom: 13 })
              .backgroundColor('#B9C8FF').borderRadius(24).margin({ bottom: 10 })
              .onClick(() => this.onSelectSources())
            Row() {
              Text('管理书源').fontSize(16).fontColor('#151720').fontWeight(FontWeight.Medium)
            }.justifyContent(FlexAlign.Center).padding({ left: 22, right: 22, top: 13, bottom: 13 })
              .backgroundColor('#B9C8FF').borderRadius(24).margin({ bottom: 18 })
              .onClick(() => this.onOpenSourceManage())
          }.layoutWeight(1).width('100%').justifyContent(FlexAlign.Center)
        }
      }.width('100%').height('58%').backgroundColor('#17181E')
        .borderRadius({ topLeft: 24, topRight: 24 })
    }.width('100%').height('100%')
  }
}

@Component
struct SearchScopeTab {
  @StorageProp('themeColorTextPrimary') themeColorTextPrimary: string = '#1B1C22';
  @StorageProp('themeColorSurfaceTertiary') themeColorSurfaceTertiary: string = '#F0F1F5';
  @Prop title: string = '';
  @Prop selected: boolean = false;
  onSelect: () => void = () => {};
  build() {
    Text(this.title).fontSize(15).fontColor(this.selected ? this.themeColorTextPrimary : '#AEB0BA')
      .textAlign(TextAlign.Center).layoutWeight(1).padding({ top: 11, bottom: 11 })
      .backgroundColor(this.selected ? '#41485D' : this.themeColorSurfaceTertiary).borderRadius(20).margin({ right: 8 })
      .onClick(() => this.onSelect())
  }
}
