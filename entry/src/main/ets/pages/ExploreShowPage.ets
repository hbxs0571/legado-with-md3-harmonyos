// 「按给定 exploreUrl 看结果」的一页。
//
// 对齐上游 `ui/book/explore/ExploreShowScreen.kt`（564 行）+ `ExploreShowViewModel.kt`（472 行）：
// - 顶栏：返回 / 布局与列数 / 分类选择 / 页码（`canJumpPage` 为真才画）。
// - 四档过滤（`BookFilterState`，来自封面设置 `exploreFilterState`）：全显 / 隐藏书架已有 /
//   隐藏同名同作者 / 只显不在书架。
// - 列表与网格两态，网格列数按朝向各存一份；切换布局时把滚动位置带过去。
// - 滚到底自动续页；某一页被过滤空但还有数据时强制再抓一页（`ForceLoadNext`）。
// - 长按弹预览（`SearchBookPreviewSheet`）。
//
// 与上游的差别（记入 `tmp/appearance-impl-report.md` 待办账本）：
// 1. 上游 `SaveSearchBooksUseCase.save` 会把结果写进 searchBooks 表；本地搜索结果不落库，
//    没有等价仓储，这一步省略。
// 2. 上游 `LaunchedEffect` 在组合期驱动加载；本地用 `aboutToAppear` + 滚动尾行 `onAppear`。
import { display } from '@kit.ArkUI';
import { BookSource } from '@legado/sourceengine';
import { BookSource as LocalBookSource } from '../model/BookSource';
import { Book } from '../model/Book';
import { BookSourceRepository } from '../data/BookSourceRepository';
import { LegadoSourceMapper } from '../bookSource/LegadoSourceMapper';
import { CoverSettings, DEFAULT_COVER_SETTINGS } from '../data/CoverSettingsRepository';
import {
  EXPLORE_GRID_COUNT_MAX,
  EXPLORE_GRID_COUNT_MIN,
  EXPLORE_GRID_LANDSCAPE_DEFAULT,
  EXPLORE_GRID_PORTRAIT_DEFAULT,
  EXPLORE_LAYOUT_MODE_GRID,
  EXPLORE_LAYOUT_MODE_LIST,
  ExploreLayoutSettings,
  ExploreLayoutSettingsRepository
} from '../data/ExploreLayoutSettings';
import { ExploreCoordinator, ExploreOutcome } from '../bookSource/ExploreCoordinator';
import { ExploreKind, ExploreKindParser } from '../bookSource/ExploreKind';
import { supportsPageSelection } from '../bookSource/PageSelection';
import { SearchBookItem } from '../bookSource/SourceModels';
import { bookCoverSharedElementKey } from '../data/BookCoverSharedElement';
import {
  BookShelfState,
  SearchBookGridItem,
  SearchBookListItem
} from '../components/booksource/SearchBookItems';
import { ExploreKindSelectSheet } from '../components/booksource/ExploreKindItem';
import { LoadMoreFooter } from '../components/booksource/LoadMoreFooter';
import { SearchBookPreviewSheet } from '../components/booksource/SearchBookPreviewSheet';
import { AppTopBar, TopBarBackButton, TopBarButton } from '../components/TopBar';
import { PullRefreshIndicator } from '../components/PullRefreshIndicator';
import { AppGlyph, AppGlyphName } from '../components/AppGlyph';
import { UiSlider } from '../components/settings/UiSlider';
import {
  BODY_SMALL,
  LABEL_LARGE,
  LABEL_MEDIUM,
  TITLE_SMALL
} from '../components/typography/TypographyTokens';
import {
  HEADER_COLLAPSE_THRESHOLD,
  HEADER_EXPAND_THRESHOLD,
  SPACE_12,
  SPACE_16,
  SPACE_4,
  SPACE_8
} from '../components/UiTokens';

/** 一页结果条数；上游没有显式常量，靠「本页是否为空」判断到底，本地沿用发现页的 20 条口径。 */
const PAGE_SIZE: number = 20;
/** 自动续页上限，对齐上游 `ExploreShowViewModel.kt:97 MAX_AUTO_PAGES = 3`。 */
const MAX_AUTO_PAGES: number = 3;
/** 自动续页间隔，对齐上游 `ExploreShowViewModel.kt:100 AUTO_PAGE_DELAY_MS = 500L`。 */
const AUTO_PAGE_DELAY_MS: number = 500;
/** 空对象：预览面板未打开时的占位。 */
const EMPTY_BOOK: SearchBookItem = {
  bookUrl: '', origin: '', originName: '', name: '', author: '', kind: '',
  coverUrl: '', intro: '', lastChapter: '', wordCount: '', updateTime: '', tocUrl: ''
};
/** 网格左右内边距，对齐上游 `contentPadding start/end = 12.dp`。 */
const GRID_PADDING: number = 12;
/** 网格横向间隔，对齐上游 `horizontalArrangement spacedBy(4.dp)`。 */
const GRID_GAP_H: number = 4;
/** 网格纵向间隔，对齐上游 `verticalArrangement spacedBy(8.dp)`。 */
const GRID_GAP_V: number = 8;

/**
 * 「按给定 exploreUrl 看结果」的一页。
 * 上游 `MainRouteExploreShow(title, sourceUrl, exploreUrl)`（`MainNavGraph.kt:583-591`）。
 */
@Component
export struct ExploreShowPage {
  @StorageProp('themeColorTextPrimary') themeColorTextPrimary: string = '#1B1C22';
  @StorageProp('themeColorTextSecondary') themeColorTextSecondary: string = '#4A4C55';
  @StorageProp('themeColorTextTertiary') themeColorTextTertiary: string = '#6A6D77';
  @StorageProp('themeColorAccent') themeColorAccent: string = '#3F5BD9';
  @StorageProp('themeColorSurfacePrimary') themeColorSurfacePrimary: string = '#FAF9FD';
  @StorageProp('themeColorSurfaceTertiary') themeColorSurfaceTertiary: string = '#F0F1F5';
  @StorageProp('themeColorSurfaceElevated') themeColorSurfaceElevated: string = '#FFFFFF';
  @StorageProp('themeColorOutlineVariant') themeColorOutlineVariant: string = '#C6C7D0';
  @StorageProp('themeAppBackground') themeAppBackground: string = '';
  @StorageProp('themePureBlack') themePureBlack: boolean = false;

  /** 页面标题：初始取分类标题，切分类后跟着变（上游 `state.selectedKindTitle ?: title`）。 */
  @Prop title: string = '';
  @Prop sourceUrl: string = '';
  @Prop exploreUrl: string = '';
  @Prop shelfBooks: Book[] = [];
  @Prop coverSettings: CoverSettings = DEFAULT_COVER_SETTINGS;
  @Prop isNight: boolean = false;
  /** 封面设置里的探索页过滤档位（0..3，上游 `BookFilterState`）。 */
  @Prop exploreFilterState: number = 0;

  onBack: () => void = () => {};
  onOpenBook: (item: SearchBookItem) => void = () => {};
  onUnavailableAction: (message: string) => void = () => {};

  @State books: SearchBookItem[] = [];
  @State loading: boolean = false;
  @State refreshing: boolean = false;
  @State isEnd: boolean = false;
  @State errorMsg: string = '';
  @State currentPage: number = 1;
  @State canJumpPage: boolean = false;
  @State layoutMode: number = EXPLORE_LAYOUT_MODE_LIST;
  @State gridPortrait: number = EXPLORE_GRID_PORTRAIT_DEFAULT;
  @State gridLandscape: number = EXPLORE_GRID_LANDSCAPE_DEFAULT;
  @State kinds: ExploreKind[] = [];
  @State selectedKindTitle: string = '';
  @State kindUrl: string = '';
  @State layoutSheetVisible: boolean = false;
  @State kindSheetVisible: boolean = false;
  @State jumpSheetVisible: boolean = false;
  @State jumpInput: string = '';
  @State previewVisible: boolean = false;
  @State previewItem: SearchBookItem = EMPTY_BOOK;
  @State previewSharedKey: string = '';
  @State collapsedHeader: boolean = false;
  @State landscape: boolean = false;
  /** 下拉刷新：指示器是否已过阈值（换对勾）、当前下拉距离（vp）。 */
  @State refreshArmed: boolean = false;
  @State refreshPullOffset: number = 0;

  /** 加载代次：切分类、刷新、跳页都自增，回来时对不上就丢弃（上游 `loadGeneration`）。 */
  private generation: number = 0;
  /** 已自动续页次数，对齐上游 `autoPageCount`。 */
  private autoPageCount: number = 0;
  private nextPage: number = 1;

  aboutToAppear(): void {
    this.kindUrl = this.exploreUrl;
    this.selectedKindTitle = '';
    this.canJumpPage = supportsPageSelection(this.exploreUrl);
    this.kinds = ExploreKindParser.parseForSource(this.sourceUrl);
    this.loadLayoutSettings();
    this.loadMore(true, false);
  }

  /** 读布局偏好（上游 `loadLayoutMode` + `loadGridCount`）。 */
  private loadLayoutSettings(): void {
    const context = this.getUIContext().getHostContext();
    const widthVp: number = this.getUIContext().px2vp(display.getDefaultDisplaySync().width);
    const heightVp: number = this.getUIContext().px2vp(display.getDefaultDisplaySync().height);
    this.landscape = widthVp > heightVp;
    if (context === undefined) { return; }
    ExploreLayoutSettingsRepository.load(context).then((settings: ExploreLayoutSettings): void => {
      this.layoutMode = settings.layoutMode;
      this.gridPortrait = settings.gridPortrait;
      this.gridLandscape = settings.gridLandscape;
    }).catch((): void => {
      // 读失败就用默认值，界面不因此中断。
    });
  }

  /** 是否网格态（上游 `isGridMode = state.layoutState == 1`）。 */
  private isGridMode(): boolean {
    return this.layoutMode === EXPLORE_LAYOUT_MODE_GRID;
  }

  /** 当前朝向该用的列数（上游 `gridCount`，横屏竖屏各存一份）。 */
  private gridCount(): number {
    return ExploreLayoutSettingsRepository.gridCountFor({
      layoutMode: this.layoutMode,
      gridPortrait: this.gridPortrait,
      gridLandscape: this.gridLandscape
    }, this.landscape);
  }

  /** 网格列模板，例如 3 列 → `1fr 1fr 1fr`。 */
  private columnsTemplate(): string {
    const count = Math.min(Math.max(this.gridCount(), EXPLORE_GRID_COUNT_MIN), EXPLORE_GRID_COUNT_MAX);
    const parts: string[] = [];
    for (let index = 0; index < count; index++) { parts.push('1fr'); }
    return parts.join(' ');
  }

  /** 页面标题：有选中分类就用分类标题，否则用传进来的标题。 */
  private pageTitle(): string {
    return this.selectedKindTitle.length > 0 ? this.selectedKindTitle : this.title;
  }

  /** 取书源（上游 `repository.getBookSource(sourceUrl)`），转成引擎侧的 `BookSource`。 */
  private findSource(): BookSource | null {
    const all: LocalBookSource[] = BookSourceRepository.getAll();
    for (const source of all) {
      if (source.bookSourceUrl === this.sourceUrl) {
        return LegadoSourceMapper.fromLocal(source);
      }
    }
    return null;
  }

  /**
   * 续页，对齐上游 `loadMore(isRefresh, forceLoad)`：
   * 加载中、或已到底且不是刷新/强制，直接返回。
   */
  private loadMore(isRefresh: boolean, forceLoad: boolean): void {
    if (this.loading) { return; }
    if (this.isEnd && !isRefresh && !forceLoad) { return; }
    const source = this.findSource();
    if (source === null) {
      this.errorMsg = '找不到这本书的书源，无法继续加载';
      this.loading = false;
      return;
    }
    if (this.kindUrl.length === 0) {
      // 上游 `incomingExploreUrl == null` 的路径：先列分类，让用户选。
      this.kindSheetVisible = true;
      this.loading = false;
      return;
    }
    this.generation++;
    const generation = this.generation;
    this.loading = true;
    this.refreshing = isRefresh;
    if (isRefresh || forceLoad) { this.isEnd = false; }
    this.errorMsg = '';
    if (isRefresh) {
      this.nextPage = 1;
      this.autoPageCount = 0;
      this.books = [];
    }
    if (forceLoad) { this.autoPageCount = 0; }
    const requestPage = this.nextPage;
    ExploreCoordinator.explore(source, this.kindUrl, requestPage).then((outcome: ExploreOutcome): void => {
      if (generation !== this.generation) { return; }
      if (outcome.error.length > 0) {
        this.errorMsg = outcome.error;
        this.finishLoading();
        return;
      }
      const existing: Set<string> = new Set<string>();
      for (const item of this.books) {
        if (item.bookUrl.length > 0) { existing.add(item.bookUrl); }
      }
      const fresh: SearchBookItem[] = [];
      for (const item of outcome.books) {
        if (item.bookUrl.length > 0 && existing.has(item.bookUrl)) { continue; }
        existing.add(item.bookUrl);
        fresh.push(item);
      }
      if (fresh.length === 0) {
        this.fetchNextAutoPageOrFinish(source, generation);
        return;
      }
      this.books = this.books.concat(fresh);
      this.currentPage = requestPage;
      this.nextPage = requestPage + 1;
      this.autoPageCount = 0;
      this.isEnd = outcome.books.length < PAGE_SIZE;
      this.finishLoading();
    }).catch((error: Error): void => {
      if (generation !== this.generation) { return; }
      this.errorMsg = error.message;
      this.finishLoading();
    });
  }

  /**
   * 本页被去重后为空：再抓一页，最多 3 页（上游 `fetchNextAutoPageOrFinish`）。
   * 上游这里是 `delay(500)` 后递归，本地同样延迟，避免对同一源连打。
   */
  private fetchNextAutoPageOrFinish(source: BookSource, generation: number): void {
    this.nextPage++;
    this.autoPageCount++;
    if (this.autoPageCount >= MAX_AUTO_PAGES) {
      this.isEnd = true;
      this.finishLoading();
      return;
    }
    setTimeout((): void => {
      if (generation !== this.generation) { return; }
      this.loading = false;
      this.loadMore(false, true);
    }, AUTO_PAGE_DELAY_MS);
  }

  private finishLoading(): void {
    this.loading = false;
    this.refreshing = false;
  }

  /** 刷新：清空后从第 1 页重抓（上游 `Refresh`）。 */
  private refresh(): void {
    this.loadMore(true, false);
  }

  /** 切分类（上游 `switchKind`）：重置页码与代次，用新 url 重抓。 */
  private switchKind(kind: ExploreKind): void {
    this.generation++;
    this.selectedKindTitle = kind.title;
    this.kindUrl = kind.url;
    this.canJumpPage = supportsPageSelection(kind.url);
    this.books = [];
    this.errorMsg = '';
    this.isEnd = false;
    this.nextPage = 1;
    this.autoPageCount = 0;
    this.loading = false;
    this.loadMore(true, false);
  }

  /** 跳页（上游 `jumpToPage`）：清空后从目标页抓。 */
  private jumpToPage(target: number): void {
    if (!this.canJumpPage) { return; }
    this.generation++;
    this.books = [];
    this.errorMsg = '';
    this.isEnd = false;
    this.nextPage = Math.max(1, Math.round(target));
    this.currentPage = this.nextPage;
    this.autoPageCount = 0;
    this.loading = false;
    this.loadMore(false, true);
  }

  /** 切换布局并落盘（上游 `toggleLayout`）。 */
  private toggleLayout(): void {
    const next = this.isGridMode() ? EXPLORE_LAYOUT_MODE_LIST : EXPLORE_LAYOUT_MODE_GRID;
    this.layoutMode = next;
    const context = this.getUIContext().getHostContext();
    if (context === undefined) { return; }
    ExploreLayoutSettingsRepository.saveLayoutMode(context, next).catch((): void => {
      // 落盘失败不影响本次切换，下次进来回到旧值。
    });
  }

  /** 改列数并落盘（上游 `saveGridCount`：按朝向选 key）。 */
  private saveGridCount(count: number): void {
    const clamped = ExploreLayoutSettingsRepository.clampGridCount(count);
    if (this.landscape) { this.gridLandscape = clamped; } else { this.gridPortrait = clamped; }
    const context = this.getUIContext().getHostContext();
    if (context === undefined) { return; }
    ExploreLayoutSettingsRepository.saveGridCount(context, clamped, this.landscape).catch((): void => {
      // 同上。
    });
  }

  /** 一本书在书架里的状态（对齐上游 `ResolveBookShelfStateUseCase`）。 */
  private shelfStateOf(item: SearchBookItem): BookShelfState {
    if (item.bookUrl.length > 0) {
      for (const book of this.shelfBooks) {
        if ((book.contentPath ?? '') === item.bookUrl) { return BookShelfState.IN_SHELF; }
      }
    }
    for (const book of this.shelfBooks) {
      if (book.title === item.name && book.author === item.author) {
        return BookShelfState.SAME_NAME_AUTHOR;
      }
    }
    return BookShelfState.NOT_IN_SHELF;
  }

  /**
   * 四档过滤（上游 `ExploreShowScreen.kt:171-184`）。
   * 过滤后为空时回落全显示 —— 上游靠 `ForceLoadNext` 再抓，本地保留这份兜底，
   * 免得「本页恰好全在书架」时用户看到空白页。
   */
  private filteredBooks(): SearchBookItem[] {
    const mode = this.exploreFilterState;
    if (mode !== 1 && mode !== 2 && mode !== 3) { return this.books; }
    const result: SearchBookItem[] = [];
    for (const item of this.books) {
      const state = this.shelfStateOf(item);
      if (mode === 1 && state !== BookShelfState.IN_SHELF) { result.push(item); }
      else if (mode === 2 && state !== BookShelfState.SAME_NAME_AUTHOR) { result.push(item); }
      else if (mode === 3 && state === BookShelfState.NOT_IN_SHELF) { result.push(item); }
    }
    return result.length > 0 ? result : this.books;
  }

  /** 共享元素键：网格 `explore:grid:N`、列表 `explore:list:N`（上游同名）。 */
  private sharedKeyOf(item: SearchBookItem, index: number): string {
    const scope = this.isGridMode() ? `explore:grid:${index}` : `explore:list:${index}`;
    return bookCoverSharedElementKey(item.bookUrl, scope);
  }

  /** 滚动到接近底部就续页（上游 `shouldLoadMore`：网格看最后一项，列表看倒数第三项）。 */
  private shouldLoadMore(index: number, total: number): boolean {
    if (total === 0 || this.loading || this.refreshing || this.isEnd) { return false; }
    if (this.errorMsg.length > 0) { return false; }
    return this.isGridMode() ? index >= total - 1 : index >= total - 3;
  }

  /** 滚动时折叠标题（对齐上游 `AppScaffold` 的 nested scroll 折叠，阈值与发现页一致）。 */
  private updateHeader(offset: number): void {
    if (offset > HEADER_COLLAPSE_THRESHOLD && !this.collapsedHeader) {
      this.collapsedHeader = true;
    } else if (offset < HEADER_EXPAND_THRESHOLD && this.collapsedHeader) {
      this.collapsedHeader = false;
    }
  }

  /** 打开长按预览。 */
  private openPreview(item: SearchBookItem, index: number): void {
    this.previewItem = item;
    this.previewSharedKey = this.sharedKeyOf(item, index);
    this.previewVisible = true;
  }

  /** 刷新指示器（与首页同一个组件，`PullRefreshIndicator`）。 */
  @Builder
  private RefreshIndicatorBuilder() {
    PullRefreshIndicator({
      armed: this.refreshArmed,
      refreshing: this.refreshing,
      pullDistance: this.refreshPullOffset
    })
  }

  /** 顶栏返回槽。 */
  @Builder
  private navSlot() {
    TopBarBackButton({ onSelect: () => { this.onBack(); } })
  }

  /** 顶栏动作：布局 / 分类 / 页码（上游 `actions` 三个按钮的顺序）。 */
  @Builder
  private topActions() {
    TopBarButton({
      icon: 'grid',
      accessibilityLabel: '切换布局',
      onSelect: () => { this.layoutSheetVisible = true; }
    })
    TopBarButton({
      icon: 'profileFilterAlt',
      accessibilityLabel: '选择或搜索分类',
      onSelect: () => { this.kindSheetVisible = true; }
    })
    if (this.canJumpPage) {
      Text(`${this.currentPage}`)
        .fontSize(LABEL_MEDIUM)
        .fontColor(this.themeColorTextPrimary)
        .padding({ left: SPACE_8, right: SPACE_8, top: SPACE_4, bottom: SPACE_4 })
        .accessibilityText('跳转页码')
        .onClick(() => {
          this.jumpInput = `${this.currentPage}`;
          this.jumpSheetVisible = true;
        })
    }
  }

  /**
   * 下拉刷新壳（上游 `ExploreShowScreen.kt:297-300` 的 `AppPullToRefresh`）。
   * 内容层用 `.position({ x: 0, y: 0 })` 钉住，不随下拉手势下移，只有指示器进出
   * （`refresh.d.ts:100-104`）。
   */
  @Builder
  private resultArea() {
    Refresh({ refreshing: this.refreshing, builder: () => { this.RefreshIndicatorBuilder(); } }) {
      Column() {
        if (this.errorMsg.length > 0 && this.books.length === 0) {
          // 首屏失败：错误态也在刷新壳里，下拉即可重试（上游同一片 `resultContent`）。
          Column() {
            Text('加载失败').fontSize(LABEL_MEDIUM).fontColor(this.themeColorTextSecondary)
            Text(this.errorMsg)
              .fontSize(BODY_SMALL)
              .fontColor(this.themeColorTextTertiary)
              .textAlign(TextAlign.Center)
              .margin({ top: SPACE_4, left: 24, right: 24 })
            Text('重试')
              .fontSize(LABEL_MEDIUM)
              .fontColor(this.themeColorAccent)
              .margin({ top: SPACE_12 })
              .onClick(() => { this.loadMore(true, false); })
          }
          .width('100%')
          .height('100%')
          .justifyContent(FlexAlign.Center)
        } else if (this.filteredBooks().length === 0 && !this.loading) {
          Column() {
            Text('暂无内容').fontSize(TITLE_SMALL).fontColor(this.themeColorTextSecondary)
          }
          .width('100%')
          .height('100%')
          .justifyContent(FlexAlign.Center)
        } else if (this.isGridMode()) {
          this.gridArea()
        } else {
          this.listArea()
        }
      }
      .width('100%')
      .height('100%')
      .position({ x: 0, y: 0 })
    }
    .layoutWeight(1)
    .refreshOffset(64)
    .pullDownRatio(1)
    .maxPullDownDistance(120)
    .onRefreshing(() => { this.refresh(); })
    .onStateChange((state: RefreshStatus) => {
      const armed = state === RefreshStatus.OverDrag;
      if (armed !== this.refreshArmed) { this.refreshArmed = armed; }
    })
    .onOffsetChange((offset: number) => { this.refreshPullOffset = offset; })
  }

  /**
   * 列表行。
   * 不收参数：`@Builder` 按值传参时，参数变了内部不会重建（ArkUI 只在首次构建时取值），
   * 首屏空数组进来之后即使 `books` 变成 10 条也画不出来。改成直接读 `filteredBooks()`。
   */
  @Builder
  private listArea() {
    List() {
      ForEach(this.filteredBooks(), (item: SearchBookItem, index: number) => {
        ListItem() {
          SearchBookListItem({
            item: item,
            shelfState: this.shelfStateOf(item),
            coverSettings: this.coverSettings,
            isNight: this.isNight,
            adaptCoverAspectRatio: true,
            sharedKey: this.sharedKeyOf(item, index),
            onSelect: () => { this.onOpenBook(item); },
            onLongPress: () => { this.openPreview(item, index); }
          })
        }
        .onAppear(() => {
          if (this.shouldLoadMore(index, this.filteredBooks().length)) { this.loadMore(false, false); }
        })
      }, (item: SearchBookItem, index: number) => `${item.bookUrl}:${index}`)

      if (!this.footerHidden()) {
        ListItem() {
          this.footer()
        }
      }
    }
    .width('100%')
    .layoutWeight(1)
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring)
    .cachedCount(4)
    .onDidScroll((scrollOffset: number, _scrollState: ScrollState) => {
      this.updateHeader(scrollOffset);
    })
  }

  /** 网格。同样不收参数，理由见 `listArea()`。 */
  @Builder
  private gridArea() {
    Grid() {
      ForEach(this.filteredBooks(), (item: SearchBookItem, index: number) => {
        GridItem() {
          SearchBookGridItem({
            item: item,
            shelfState: this.shelfStateOf(item),
            coverSettings: this.coverSettings,
            isNight: this.isNight,
            sharedKey: this.sharedKeyOf(item, index),
            onSelect: () => { this.onOpenBook(item); },
            onLongPress: () => { this.openPreview(item, index); }
          })
        }
        .padding({ left: GRID_GAP_H / 2, right: GRID_GAP_H / 2 })
        .onAppear(() => {
          if (this.shouldLoadMore(index, this.filteredBooks().length)) { this.loadMore(false, false); }
        })
      }, (item: SearchBookItem, index: number) => `${item.bookUrl}:${index}`)
    }
    .columnsTemplate(this.columnsTemplate())
    .columnsGap(GRID_GAP_H)
    .rowsGap(GRID_GAP_V)
    .padding({ left: GRID_PADDING, right: GRID_PADDING, top: SPACE_12 })
    .width('100%')
    .layoutWeight(1)
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring)
    .onDidScroll((scrollOffset: number, _scrollState: ScrollState) => {
      this.updateHeader(scrollOffset);
    })
  }

  /** 尾行是否该出现（上游 `showLoadMoreFooter`）。 */
  private footerHidden(): boolean {
    return this.refreshing || (!this.loading && this.errorMsg.length === 0 && !this.isEnd);
  }

  /** 尾行（`LoadMoreFooter`，`autoLoad = false` 对齐上游 `ExploreShowScreen.kt:500-517`）。 */
  @Builder
  private footer() {
    LoadMoreFooter({
      isLoading: this.loading,
      errorMsg: this.errorMsg,
      isEnd: this.isEnd,
      autoLoad: false,
      showLoadMore: true,
      onRetry: () => { this.loadMore(false, false); },
      onLoadMore: () => { this.loadMore(false, true); }
    })
  }

  /** 布局与列数面板（上游 `ExploreShowSheet.GridCount`）。 */
  @Builder
  private layoutSheet() {
    Column() {
      Text('布局模式')
        .fontSize(TITLE_SMALL)
        .fontColor(this.themeColorTextPrimary)
        .width('100%')
        .padding({ left: SPACE_16, right: SPACE_16, top: SPACE_12, bottom: SPACE_8 })

      Row() {
        Column({ space: SPACE_4 }) {
          Text('布局模式').fontSize(LABEL_LARGE).fontColor(this.themeColorTextPrimary)
          Text(this.isGridMode() ? '网格' : '列表')
            .fontSize(BODY_SMALL)
            .fontColor(this.themeColorTextTertiary)
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        AppGlyph({ name: 'grid', glyphSize: 20, tint: this.themeColorTextTertiary })
      }
      .width('100%')
      .padding({ left: SPACE_16, right: SPACE_16, top: SPACE_12, bottom: SPACE_12 })
      .onClick(() => { this.toggleLayout(); })

      if (this.isGridMode()) {
        UiSlider({
          title: '网格列数',
          value: this.gridCount(),
          minValue: EXPLORE_GRID_COUNT_MIN,
          maxValue: EXPLORE_GRID_COUNT_MAX,
          stepValue: 1,
          onChange: (value: number) => { this.saveGridCount(value); }
        })
      }

      Blank().height(32)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  /** 跳页面板（上游 `explore_jump_page` 对话框）。 */
  @Builder
  private jumpSheet() {
    Column() {
      Text('跳转页码')
        .fontSize(TITLE_SMALL)
        .fontColor(this.themeColorTextPrimary)
        .width('100%')
        .padding({ left: SPACE_16, right: SPACE_16, top: SPACE_12, bottom: SPACE_8 })

      TextInput({ text: this.jumpInput, placeholder: '页码' })
        .type(InputType.Number)
        .maxLength(4)
        .fontSize(LABEL_LARGE)
        .backgroundColor(this.themeColorSurfaceTertiary)
        .borderRadius(10)
        .margin({ left: SPACE_16, right: SPACE_16 })
        .onChange((value: string) => {
          // 上游 `it.filter(Char::isDigit).take(4)`：只留数字，最多四位。
          let digits = '';
          for (let index = 0; index < value.length && digits.length < 4; index++) {
            const char = value.charAt(index);
            if (char >= '0' && char <= '9') { digits += char; }
          }
          this.jumpInput = digits;
        })

      Row() {
        Text('取消')
          .fontSize(LABEL_LARGE)
          .fontColor(this.themeColorTextTertiary)
          .padding({ left: 24, right: 24, top: 12, bottom: 12 })
          .onClick(() => { this.jumpSheetVisible = false; })
        Text('跳转')
          .fontSize(LABEL_LARGE)
          .fontColor('#FFFFFF')
          .backgroundColor(this.themeColorAccent)
          .borderRadius(10)
          .padding({ left: 24, right: 24, top: 12, bottom: 12 })
          .enabled(this.jumpInput.length > 0)
          .onClick(() => {
            const target = Number.parseInt(this.jumpInput, 10);
            if (Number.isNaN(target) || target < 1) { return; }
            this.jumpSheetVisible = false;
            this.jumpToPage(target);
          })
      }
      .width('100%')
      .justifyContent(FlexAlign.End)
      .padding({ left: SPACE_16, right: SPACE_16, top: SPACE_16, bottom: 32 })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      Column() {
        AppTopBar({
          title: this.pageTitle(),
          subtitle: '',
          collapsed: this.collapsedHeader,
          hasNavigation: true,
          navigationIcon: () => { this.navSlot() },
          actions: () => { this.topActions() }
        })

        this.resultArea()
      }
      .width('100%')
      .height('100%')

      // 预览面板：上游 `SearchBookPreviewSheet`（长按弹出）。
      if (this.previewVisible) {
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor('#66000000')
          .onClick(() => { this.previewVisible = false; })

        Column() {
          SearchBookPreviewSheet({
            item: this.previewItem,
            shelfState: this.shelfStateOf(this.previewItem),
            coverSettings: this.coverSettings,
            isNight: this.isNight,
            sharedKey: this.previewSharedKey,
            onOpenDetail: () => {
              const item = this.previewItem;
              this.previewVisible = false;
              this.onOpenBook(item);
            },
            onAddToShelf: () => {
              const item = this.previewItem;
              this.previewVisible = false;
              this.onOpenBook(item);
            }
          })
        }
        .width('calc(100% - 32vp)')
        .padding({ left: SPACE_16, right: SPACE_16, top: SPACE_16 })
        .backgroundColor(this.themePureBlack ? '#17181E' : this.themeColorSurfaceElevated)
        .borderRadius(28)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.themeAppBackground.length > 0 ? Color.Transparent : (this.themePureBlack ? '#000000' : this.themeColorSurfacePrimary))
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP])
    // 同一组件只挂一个 bindSheet（项目已踩过挂多个只有最后一个生效的坑），
    // 三个面板共用这一个，按状态切内容。
    .bindSheet(this.anySheetVisible(), this.sheetContent(), {
      height: this.kindSheetVisible ? SheetSize.MEDIUM : SheetSize.FIT_CONTENT,
      dragBar: true,
      showClose: false,
      backgroundColor: this.themeColorSurfaceTertiary,
      onDisappear: () => {
        this.layoutSheetVisible = false;
        this.kindSheetVisible = false;
        this.jumpSheetVisible = false;
      }
    })
  }

  /** 三个面板是否有任意一个打开。 */
  private anySheetVisible(): boolean {
    return this.layoutSheetVisible || this.kindSheetVisible || this.jumpSheetVisible;
  }

  /** 合并面板内容：分类优先（面板最高），其余两个都是 FIT_CONTENT。 */
  @Builder
  private sheetContent() {
    if (this.kindSheetVisible) {
      this.kindSheet()
    } else if (this.layoutSheetVisible) {
      this.layoutSheet()
    } else {
      this.jumpSheet()
    }
  }

  @Builder
  private kindSheet() {
    Column() {
      ExploreKindSelectSheet({
        sourceUrl: this.sourceUrl,
        multiple: false,
        initialSelectedTitles: this.selectedKindTitle.length > 0 ? [this.selectedKindTitle] : [],
        onSelected: (kinds: ExploreKind[]) => {
          this.kindSheetVisible = false;
          if (kinds.length === 0) { return; }
          this.switchKind(kinds[0]);
        },
        onDismissRequest: () => { this.kindSheetVisible = false; }
      })
    }
    .width('100%')
    .height('100%')
  }
}
