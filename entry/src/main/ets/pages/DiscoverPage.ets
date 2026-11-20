import curves from '@ohos.curves';
import { AppGlyph } from '../components/AppGlyph';
import { AppTopBar, TopBarButton } from '../components/TopBar';
import { BookSource } from '@legado/sourceengine';
import { BookSourceRepository } from '../data/BookSourceRepository';
import { ExploreCoordinator, ExploreOutcome } from '../bookSource/ExploreCoordinator';
import { ExploreMenu } from '../bookSource/ExploreMenuParser';
import { SearchBookItem } from '../bookSource/SourceModels';
import { MergedBook } from '../bookSource/SearchResultMerger';

const DISCOVER_MENU_WIDTH: number = 260;

/** 一张发现结果卡片：封面/书名/作者/来源。 */
@Component
struct ExploreBookCard {
  @StorageProp('themeColorTextPrimary') themeColorTextPrimary: string = '#1B1C22';
  @StorageProp('themeColorTextTertiary') themeColorTextTertiary: string = '#6A6D77';
  @StorageProp('themeColorSurfaceElevated') themeColorSurfaceElevated: string = '#FFFFFF';
  @StorageProp('themeAppBackground') themeAppBackground: string = '';
  @StorageProp('themePureBlack') themePureBlack: boolean = false;
  @Prop item: SearchBookItem = {
    bookUrl: '', origin: '', originName: '', name: '', author: '', kind: '', coverUrl: '',
    intro: '', lastChapter: '', wordCount: '', updateTime: '', tocUrl: ''
  };
  onSelect: () => void = () => {};

  build() {
    Row() {
      if (this.item.coverUrl.length > 0) {
        Image(this.item.coverUrl)
          .width(52).height(72).borderRadius(5).objectFit(ImageFit.Cover)
          .margin({ right: 12 })
          .alt($r('app.media.transparent_pixel'))
      }
      Column() {
        Text(this.item.name).fontSize(16).fontColor(this.themeColorTextPrimary).maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis }).width('100%')
        Text(this.item.author || '佚名').fontSize(13).fontColor(this.themeColorTextTertiary)
          .margin({ top: 5 }).maxLines(1).width('100%')
        Row() {
          Text(this.item.lastChapter).fontSize(12).fontColor(this.themeColorTextTertiary)
            .maxLines(1).layoutWeight(1)
          Text(this.item.originName).fontSize(11).fontColor(this.themeColorTextTertiary)
            .margin({ left: 6 }).maxLines(1)
        }.width('100%').margin({ top: 6 })
      }.alignItems(HorizontalAlign.Start).layoutWeight(1)
    }.width('100%').padding(12)
      .backgroundColor(this.themeAppBackground.length > 0 ? Color.Transparent : (this.themePureBlack ? '#121212' : this.themeColorSurfaceElevated))
      .borderRadius(14).margin({ left: 16, right: 16, bottom: 9 })
      .onClick(() => this.onSelect())
  }
}

@Component
export struct DiscoverPage {
  @StorageProp('themeColorTextPrimary') themeColorTextPrimary: string = '#1B1C22';
  @StorageProp('themeColorTextSecondary') themeColorTextSecondary: string = '#2E3038';
  @StorageProp('themeColorTextTertiary') themeColorTextTertiary: string = '#6A6D77';
  @StorageProp('themeColorAccent') themeColorAccent: string = '#3F5BD9';
  @StorageProp('themeColorSurfacePrimary') themeColorSurfacePrimary: string = '#F5F6F8';
  @StorageProp('themeColorSurfaceElevated') themeColorSurfaceElevated: string = '#FFFFFF';
  @StorageProp('themeAppBackground') themeAppBackground: string = '';
  @StorageProp('themePureBlack') themePureBlack: boolean = false;
  @StorageProp('themeItemBackground') themeItemBackground: string = '';
  onUnavailableAction: (message: string) => void = (_message: string) => {};
  onOpenOnlineBook: (item: MergedBook) => void = (_item: MergedBook) => {};

  @State exploreSources: BookSource[] = [];
  @State selectedSourceUrl: string = '';
  @State menus: ExploreMenu[] = [];
  @State selectedMenuUrl: string = '';
  @State resultBooks: SearchBookItem[] = [];
  @State loading: boolean = false;
  @State hasMore: boolean = true;
  @State page: number = 1;
  @State errorMessage: string = '';
  @State collapsedHeader: boolean = false;
  private exploreScroller: Scroller = new Scroller();
  private sourceScroller: Scroller = new Scroller();

  aboutToAppear(): void {
    this.reloadSources();
  }

  /** 载入有发现能力的书源，并默认选中第一个。 */
  private async reloadSources(): Promise<void> {
    const context = this.getUIContext().getHostContext();
    if (context === undefined) { return; }
    await BookSourceRepository.load(context);
    const sources = ExploreCoordinator.getExploreSources();
    this.exploreSources = sources;
    if (sources.length === 0) {
      this.selectedSourceUrl = '';
      this.menus = [];
      this.resultBooks = [];
      return;
    }
    // 保留上次选中；否则选第一个。
    let picked: BookSource | undefined = sources.find((s: BookSource) => s.bookSourceUrl === this.selectedSourceUrl);
    if (picked === undefined && sources.length > 0) { picked = sources[0]; }
    if (picked === undefined) { return; }
    this.selectedSourceUrl = picked.bookSourceUrl;
    this.onSourceSelected(picked);
  }

  /** 选中源：解析分类 chip，清结果。 */
  private onSourceSelected(source: BookSource): void {
    this.selectedSourceUrl = source.bookSourceUrl;
    this.menus = ExploreCoordinator.parseMenus(source);
    this.selectedMenuUrl = this.menus.length > 0 ? this.menus[0].url : '';
    this.resultBooks = [];
    this.errorMessage = '';
    this.page = 1;
    this.hasMore = true;
    if (this.selectedMenuUrl.length > 0) {
      this.loadPage(1, false);
    }
  }

  /** 选中分类：从第 1 页重抓。 */
  private onMenuSelected(menu: ExploreMenu): void {
    if (menu.url === this.selectedMenuUrl) { return; }
    this.selectedMenuUrl = menu.url;
    this.resultBooks = [];
    this.errorMessage = '';
    this.page = 1;
    this.hasMore = true;
    this.loadPage(1, false);
  }

  /** 抓第 page 页；append=true 时追加并去重。 */
  private async loadPage(nextPage: number, append: boolean): Promise<void> {
    const source = this.exploreSources.find((s: BookSource) => s.bookSourceUrl === this.selectedSourceUrl);
    if (source === undefined || this.selectedMenuUrl.length === 0) { return; }
    if (this.loading) { return; }
    this.loading = true;
    this.errorMessage = '';
    const outcome: ExploreOutcome = await ExploreCoordinator.explore(source, this.selectedMenuUrl, nextPage);
    this.loading = false;
    if (outcome.error.length > 0) {
      this.errorMessage = outcome.error;
      this.hasMore = false;
      return;
    }
    if (outcome.books.length === 0) {
      this.hasMore = false;
      return;
    }
    if (append) {
      const seen = new Set<string>();
      for (const b of this.resultBooks) { seen.add(b.bookUrl); }
      const fresh = outcome.books.filter((b: SearchBookItem) => {
        if (seen.has(b.bookUrl)) { return false; }
        seen.add(b.bookUrl);
        return true;
      });
      this.resultBooks = this.resultBooks.concat(fresh);
      if (fresh.length === 0) { this.hasMore = false; }
    } else {
      this.resultBooks = outcome.books;
    }
    this.page = nextPage;
    // 一页满 20 条才认为还有下一页，避免末页再发一次空请求。
    if (outcome.books.length < 20) { this.hasMore = false; }
  }

  /** 底部"加载更多"进入视口时触发（滚动到底自动翻页）。 */
  private onReachBottom(): void {
    if (this.loading || !this.hasMore || this.selectedMenuUrl.length === 0) { return; }
    this.loadPage(this.page + 1, true);
  }

  /** 点书：构造 MergedBook 交给 Index 的「加入书架并打开」链路。 */
  private openBook(item: SearchBookItem): void {
    if (item.bookUrl.length === 0) {
      this.onUnavailableAction('该书没有可用的详情地址');
      return;
    }
    const merged: MergedBook = { book: item, origins: [item.origin], originCount: 1 };
    this.onOpenOnlineBook(merged);
  }

  private updateHeader(offset: number): void {
    const shouldCollapse = offset > 70 ? true : offset < 24 ? false : this.collapsedHeader;
    if (shouldCollapse === this.collapsedHeader) { return; }
    this.getUIContext().animateTo({ curve: curves.springMotion(0.35, 0.86) }, () => {
      this.collapsedHeader = shouldCollapse;
    });
  }

  /** 横向 chip：书源列表。 */
  @Builder
  private SourceChips() {
    Scroll(this.sourceScroller) {
      Row() {
        ForEach(this.exploreSources, (source: BookSource) => {
          Text(source.bookSourceName)
            .fontSize(13)
            .fontColor(source.bookSourceUrl === this.selectedSourceUrl ? '#FFFFFF' : this.themeColorTextSecondary)
            .backgroundColor(source.bookSourceUrl === this.selectedSourceUrl ? this.themeColorAccent : this.themeColorSurfaceElevated)
            .borderRadius(16).padding({ left: 12, right: 12, top: 7, bottom: 7 })
            .margin({ right: 8 })
            .onClick(() => this.onSourceSelected(source))
        }, (source: BookSource) => source.bookSourceUrl)
      }.padding({ left: 16, right: 16, top: 8, bottom: 8 })
    }.scrollable(ScrollDirection.Horizontal).scrollBar(BarState.Off)
      .width('100%')
  }

  /** 横向 chip：当前源的分类。 */
  @Builder
  private MenuChips() {
    Scroll() {
      Row() {
        ForEach(this.menus, (menu: ExploreMenu, index: number) => {
          Text(menu.title)
            .fontSize(12)
            .fontColor(menu.url === this.selectedMenuUrl ? '#FFFFFF' : this.themeColorTextTertiary)
            .backgroundColor(menu.url === this.selectedMenuUrl ? this.themeColorAccent : this.themeColorSurfaceElevated)
            .borderRadius(14).padding({ left: 10, right: 10, top: 5, bottom: 5 })
            .margin({ right: 6 })
            .onClick(() => this.onMenuSelected(menu))
        }, (menu: ExploreMenu, index: number) => menu.url + index.toString())
      }.padding({ left: 16, right: 16, top: 2, bottom: 10 })
    }.scrollable(ScrollDirection.Horizontal).scrollBar(BarState.Off)
      .width('100%')
  }

  /** 发现结果区：错误/空/列表/翻页四态。 */
  @Builder
  private ResultArea() {
    if (this.errorMessage.length > 0) {
      Column() {
        Text('加载失败').fontSize(15).fontColor(this.themeColorTextSecondary)
        Text(this.errorMessage).fontSize(12).fontColor(this.themeColorTextTertiary)
          .textAlign(TextAlign.Center).margin({ top: 6, left: 24, right: 24 })
        Text('重试').fontSize(13).fontColor(this.themeColorAccent).margin({ top: 12 })
          .onClick(() => this.loadPage(this.page, false))
      }.width('100%').layoutWeight(1).justifyContent(FlexAlign.Center)
    } else if (this.selectedSourceUrl.length === 0) {
      Column() {
        Text('当前没有发现源！').fontSize(14).fontColor(this.themeColorTextSecondary)
        Text('在书源管理中启用带发现规则的书源').fontSize(12).fontColor(this.themeColorTextTertiary)
          .margin({ top: 8 })
      }.width('100%').layoutWeight(1).justifyContent(FlexAlign.Center)
    } else if (this.resultBooks.length === 0 && !this.loading) {
      Column() {
        Text('暂无内容').fontSize(14).fontColor(this.themeColorTextSecondary)
      }.width('100%').layoutWeight(1).justifyContent(FlexAlign.Center)
    } else {
      Scroll(this.exploreScroller) {
        Column() {
          ForEach(this.resultBooks, (item: SearchBookItem) => {
            ExploreBookCard({ item: item, onSelect: () => this.openBook(item) })
          }, (item: SearchBookItem) => item.bookUrl)

          if (this.loading) {
            Row() {
              Text('加载中…').fontSize(13).fontColor(this.themeColorTextTertiary)
            }.width('100%').justifyContent(FlexAlign.Center).padding(14)
          } else if (this.hasMore) {
            Row() {
              Text('加载更多').fontSize(13).fontColor(this.themeColorAccent)
            }.width('100%').justifyContent(FlexAlign.Center).padding(14)
              .onAppear(() => this.onReachBottom())
          } else if (this.resultBooks.length > 0) {
            Row() {
              Text('没有更多了').fontSize(12).fontColor(this.themeColorTextTertiary)
            }.width('100%').justifyContent(FlexAlign.Center).padding(14)
          }
        }.padding({ top: 4, bottom: 16 }).constraintSize({ minHeight: '100%' })
      }.layoutWeight(1).scrollBar(BarState.Off).edgeEffect(EdgeEffect.Spring)
        .onDidScroll((_x: number, _y: number) => this.updateHeader(this.exploreScroller.currentOffset().yOffset))
    }
  }

  // @BuilderParam 槽位须传 @Builder 方法引用；内联 lambda 直接实例化 struct 会
  // 在运行时变成裸构造函数调用（class constructor cannot called without 'new'）。
  @Builder discoverActionsSlot() {
    TopBarButton({
      icon: 'profileRefresh',
      showDivider: false,
      onSelect: () => {
        this.resultBooks = [];
        this.errorMessage = '';
        this.page = 1;
        this.hasMore = true;
        this.reloadSources();
      }
    })
  }

  build() {
    Column() {
      AppTopBar({
        title: '发现',
        subtitle: '',
        collapsed: this.collapsedHeader,
        actions: () => { this.discoverActionsSlot() }
      })

      if (this.exploreSources.length > 0) {
        this.SourceChips()
        if (this.menus.length > 0) {
          this.MenuChips()
        }
      }
      this.ResultArea()
    }.width('100%').height('100%').backgroundColor(this.themeAppBackground.length > 0 ? Color.Transparent : (this.themePureBlack ? '#000000' : this.themeColorSurfacePrimary))
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP])
  }
}
