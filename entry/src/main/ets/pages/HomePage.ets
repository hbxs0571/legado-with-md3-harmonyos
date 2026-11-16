import curves from '@ohos.curves';
import { Book } from '../model/Book';
import { BookRepository } from '../data/BookRepository';
import { BookCover } from '../components/BookCover';
import { AppGlyph, AppGlyphName } from '../components/AppGlyph';
import { AppTopBar, TopBarButton } from '../components/TopBar';
import { HomeDashboardSection, HOME_DASHBOARD_SECTIONS } from '../data/HomeDashboardSettingsRepository';
import { UiMenuItem, UiMenuPanel } from '../components/UiMenu';
import { UiSwitchControl } from '../components/UiSwitchControl';
import { PullRefreshIndicator } from '../components/PullRefreshIndicator';

/** 首页右上角菜单的宽度，与详情页溢出菜单同口径。 */
const HOME_MENU_WIDTH: number = 260;

@Component
export struct HomePage {
  @StorageProp('themeColorTextPrimary') themeColorTextPrimary: string = '#1B1C22';
  @StorageProp('themeColorTextSecondary') themeColorTextSecondary: string = '#2E3038';
  @StorageProp('themeColorAccent') themeColorAccent: string = '#3F5BD9';
  @StorageProp('themeColorSurfacePrimary') themeColorSurfacePrimary: string = '#F5F6F8';
  @StorageProp('themeColorSurfaceElevated') themeColorSurfaceElevated: string = '#FFFFFF';
  @StorageProp('themeAppBackground') themeAppBackground: string = '';
  @StorageProp('themePureBlack') themePureBlack: boolean = false;
  @StorageProp('themeItemBackground') themeItemBackground: string = '';
  @Prop books: Book[] = [];
  @Prop totalReadTimeMs: number = 0;
  onOpenBook: (book: Book) => void = () => {};
  onOpenBookInfo: (book: Book) => void = () => {};
  onOpenBookshelf: () => void = () => {};
  onOpenReadRecords: () => void = () => {};
  onOpenBackup: () => void = () => {};
  onUnavailableAction: (message: string) => void = (_message: string) => {};
  @Prop visibleSections: HomeDashboardSection[] = [...HOME_DASHBOARD_SECTIONS];
  onSectionVisibilityChange: (section: HomeDashboardSection, visible: boolean) => void = (_section: HomeDashboardSection, _visible: boolean) => {};
  /** 下拉刷新：由 Index 重读 books 与阅读记录后返回。 */
  onPullRefresh: () => Promise<void> = async () => {};
  @State showHomeOptions: boolean = false;
  @State moreMenuVisible: boolean = false;
  @State refreshing: boolean = false;
  /** 下拉已过触发阈值（松手就会刷新），只喂给自绘指示器换图标用。 */
  @State refreshArmed: boolean = false;
  @State collapsedHeader: boolean = false;
  private homeScroller: Scroller = new Scroller();

  /**
   * 下拉刷新。
   *
   * 上游对应 HomepageViewModel.kt:648-663 的 onRefresh()：取消在途加载、重新从各模块
   * 拉一遍、全部结束后把 isRefreshing 置回 false。本地首页没有「模块」，数据源是 books
   * 表与 read_record 表，所以等价于重读这两张表（Index.refreshHomeFromPull）。
   */
  private async handlePullToRefresh(): Promise<void> {
    if (this.refreshing) { return; }
    this.refreshing = true;
    try {
      await this.onPullRefresh();
    } catch (_) {
      // 刷新失败不该把界面卡在转圈状态，只收掉指示器。
    } finally {
      this.refreshing = false;
    }
  }

  /**
   * 自绘指示器。
   *
   * `Refresh` 的自定义入口有 `builder`（CustomBuilder，API 10）与 `refreshingContent`
   * （ComponentContent，API 12）两个，同时设时 builder 不生效。
   * 这里选 builder：它的类型就是箭头函数，在 struct 里直接写最省事；
   * refreshingContent 要另外构造 ComponentContent，在 @Component 里用不方便。
   * 代价是 API 12 的注记说 builder 在刷新过程中可能被销毁重建——对本地这个
   * 只有一个静态圆片的指示器没有影响（重建后状态从 @State 重读，画面一致）。
   */
  @Builder
  private RefreshIndicatorBuilder() {
    PullRefreshIndicator({
      armed: this.refreshArmed,
      refreshing: this.refreshing
    });
  }

  private sectionTitle(section: HomeDashboardSection): string {
    if (section === 'recentBook') { return '最近阅读'; }
    if (section === 'totalBooks') { return '累计阅读'; }
    if (section === 'totalTime') { return '阅读时长'; }
    if (section === 'recentBooks') { return '最近阅读记录'; }
    if (section === 'dailyGoal') { return '今日阅读目标'; }
    return 'WebDAV 备份';
  }

  @Builder
  private MoreMenu() {
    // 菜单内容交给 UiMenuPanel 画（浅容器 + 深卡片），不再用系统 Menu。
    UiMenuPanel({
      items: this.moreMenuItems(),
      panelWidth: HOME_MENU_WIDTH,
      onSelect: (key: string) => {
        this.moreMenuVisible = false;
        if (key === 'home_sections') { this.showHomeOptions = true; }
      }
    })
  }

  private moreMenuItems(): UiMenuItem[] {
    return [{ key: 'home_sections', title: '首页组件' }];
  }

  @Builder homeTopActions() {
    TopBarButton({
      icon: 'settings',
      showDivider: false,
      onSelect: () => { this.showHomeOptions = !this.showHomeOptions; }
    })
    // menuMode: true 让 TopBarButton 不注册自己的 onClick，点击手势交给外层 bindPopup。
    TopBarButton({ icon: 'more', menuMode: true })
      .onClick(() => { this.moreMenuVisible = !this.moreMenuVisible; })
      .bindPopup(this.moreMenuVisible, {
        builder: this.MoreMenu,
        placement: Placement.BottomRight,
        popupColor: '#00000000',
        enableArrow: false,
        autoCancel: true,
        width: HOME_MENU_WIDTH,
        onStateChange: (event: PopupStateChangeParam) => { this.moreMenuVisible = event.isVisible; }
      })
  }

  private getLocalBooks(): Book[] {
    return this.books.filter((book: Book) => BookRepository.isPersistableBook(book));
  }

  private getRecentBook(): Book {
    const localBooks = this.getLocalBooks();
    for (let index = localBooks.length - 1; index >= 0; index--) {
      const book = localBooks[index];
      if (book !== undefined && book.contentPath !== undefined) {
        return book;
      }
    }
    const localBook = localBooks[localBooks.length - 1];
    if (localBook !== undefined) {
      return localBook;
    }
    return this.books[0] ?? {
      id: '', title: '', author: '', category: '', lastChapter: '', progress: 0, isLocal: true
    };
  }

  /** 最近阅读卡副标题：EPUB 显示元数据作者，其余按本地格式给不写死兜底的标签。 */
  private recentBookSubtitle(): string {
    const book = this.getRecentBook();
    if (book.format === 'epub') { return book.author.length > 0 ? book.author : '本地 EPUB'; }
    if (book.format === 'pdf') { return '本地 PDF'; }
    if (book.format === 'mobi') { return '本地 MOBI'; }
    if (book.format === 'umd') { return '本地 UMD'; }
    if (book.format === 'txt') { return '本地 TXT'; }
    return '本地';
  }

  private getRecentBooks(): Book[] {
    const localBooks = this.getLocalBooks();
    const start = Math.max(0, localBooks.length - 6);
    return localBooks.slice(start).reverse();
  }

  private openBook(book: Book): void {
    if (BookRepository.isBodyMissing(book)) {
      this.onOpenBookInfo(book);
    } else {
      this.onOpenBook(book);
    }
  }

  private getRecentBookProgress(book: Book): number {
    return Math.max(0, Math.min(100, book.progress));
  }

  private getLocalBookCount(): number {
    return this.getLocalBooks().length;
  }

  private getReadTimeLabel(): string {
    const totalHours = this.totalReadTimeMs / 3600000;
    return totalHours.toFixed(1);
  }

  private settings: RenderingContextSettings = new RenderingContextSettings(true);
  private goalContext: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings);

  private drawGoalArc(): void {
    const width = this.goalContext.width;
    const height = this.goalContext.height;
    const centerX = width / 2;
    const centerY = height - 10;
    const radius = Math.min(width * 0.4, height * 0.82);
    const progress = 0;
    this.goalContext.clearRect(0, 0, width, height);
    this.goalContext.beginPath();
    this.goalContext.arc(centerX, centerY, radius, Math.PI, 0, false);
    this.goalContext.strokeStyle = '#353741';
    this.goalContext.lineWidth = width * 0.044;
    this.goalContext.lineCap = 'round';
    this.goalContext.stroke();
    this.goalContext.beginPath();
    this.goalContext.arc(centerX, centerY, radius, Math.PI, Math.PI * (1 - progress), false);
    this.goalContext.strokeStyle = '#AFC2FF';
    this.goalContext.lineWidth = width * 0.044;
    this.goalContext.lineCap = 'round';
    this.goalContext.stroke();
  }

  build() {
    Column() {
      AppTopBar({
        title: '首页',
        collapsed: this.collapsedHeader,
        actions: () => { this.homeTopActions() }
      })
      Refresh({
        refreshing: this.refreshing,
        builder: () => { this.RefreshIndicatorBuilder(); }
      }) {
        Scroll(this.homeScroller) {
        Column() {
          if (this.visibleSections.includes('recentBook') && this.getLocalBooks().length > 0) {
            Stack({ alignContent: Alignment.Bottom }) {
            Column() {
              Row() {
                AppGlyph({ name: 'book', tint: this.themeColorAccent, glyphSize: 20 })
                Text(BookRepository.isBodyMissing(this.getRecentBook()) ? '已恢复书目 · 缺少正文' : '最近阅读')
                  .fontSize(16).fontWeight(FontWeight.Medium).fontColor(this.themeColorTextSecondary).margin({ left: 10 })
              }.margin({ bottom: 10 })
              Row() {
                BookCover({ book: this.getRecentBook(), mini: true, displayWidth: 56, displayHeight: 78 })
                Column() {
                  Text(this.getRecentBook().title).fontSize(16).fontWeight(FontWeight.Medium).fontColor(this.themeColorTextPrimary).maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
                  Text(this.recentBookSubtitle()).fontSize(12).fontColor('#B6B8C2').margin({ top: 6 })
                  Text(this.getRecentBook().lastChapter).fontSize(12).fontColor('#B6B8C2').margin({ top: 6 })
                }.alignItems(HorizontalAlign.Start).layoutWeight(1).margin({ left: 14 })
                Text(`${Math.round(this.getRecentBookProgress(this.getRecentBook()))}%`).fontSize(11).fontColor('#D7DFFB').padding({ left: 9, right: 9, top: 6, bottom: 6 }).backgroundColor('#383D50').borderRadius(8)
              }.width('100%')
            }.width('100%').padding({ left: 16, right: 16, top: 16, bottom: 14 })
            Progress({ value: this.getRecentBookProgress(this.getRecentBook()), total: 100, type: ProgressType.Linear })
              .width('100%').height(3).color(this.themeColorAccent).backgroundColor('#3A3B43')
              .animation({ duration: 300, curve: Curve.EaseInOut })
            }.width('100%').backgroundColor(this.themeAppBackground.length > 0 ? Color.Transparent : (this.themePureBlack ? '#121212' : this.themeColorSurfaceElevated)).borderRadius(17).backgroundImage(this.themeItemBackground.length > 0 ? `file://${this.themeItemBackground}` : $r('app.media.transparent_pixel'), ImageRepeat.NoRepeat)
              .onClick(() => this.openBook(this.getRecentBook()))
          } else if (this.visibleSections.includes('recentBook')) {
            Column() {
              Row() {
                AppGlyph({ name: 'book', tint: this.themeColorAccent, glyphSize: 20 })
                Text('最近阅读').fontSize(16).fontWeight(FontWeight.Medium).fontColor(this.themeColorTextSecondary).margin({ left: 10 })
              }.alignSelf(ItemAlign.Start)
              Blank().layoutWeight(1)
              Text('暂无阅读记录').fontSize(14).fontColor('#AEB0BA').alignSelf(ItemAlign.Center)
              Blank().layoutWeight(1)
            }.width('100%').height(160).padding({ left: 16, right: 16, top: 16, bottom: 14 }).justifyContent(FlexAlign.Center)
              .backgroundColor(this.themeAppBackground.length > 0 ? Color.Transparent : (this.themePureBlack ? '#121212' : this.themeColorSurfaceElevated)).borderRadius(17).alignItems(HorizontalAlign.Center).backgroundImage(this.themeItemBackground.length > 0 ? `file://${this.themeItemBackground}` : $r('app.media.transparent_pixel'), ImageRepeat.NoRepeat)
          }
          if (this.visibleSections.includes('totalBooks') || this.visibleSections.includes('totalTime')) {
            Row() {
              if (this.visibleSections.includes('totalBooks')) {
                SummaryCard({ icon: 'chart', title: '累计阅读', value: `${this.getLocalBookCount()}`, unit: '本', onSelect: () => this.onOpenBookshelf() }).layoutWeight(1)
              }
              if (this.visibleSections.includes('totalTime')) {
                SummaryCard({ icon: 'accessTime', title: '阅读时长', value: this.getReadTimeLabel(), unit: '小时', onSelect: () => this.onOpenReadRecords() }).layoutWeight(1)
                  .margin({ left: this.visibleSections.includes('totalBooks') ? 12 : 0 })
              }
            }.margin({ top: 12 })
          }
          if (this.visibleSections.includes('recentBooks') && this.getRecentBooks().length > 0) {
            Scroll() {
              Row() {
                ForEach(this.getRecentBooks(), (book: Book) => {
                  BookCover({ book: book, mini: true, displayWidth: 60, displayHeight: 84, cornerRadius: 12 })
                    .margin({ right: 8 }).onClick(() => this.openBook(book))
                }, (book: Book) => book.id)
              }
            }.width('100%').scrollable(ScrollDirection.Horizontal).scrollBar(BarState.Off).margin({ top: 12 })
          }
          if (this.visibleSections.includes('dailyGoal')) {
          Column() {
            Row() {
              AppGlyph({ name: 'goal', tint: this.themeColorAccent, glyphSize: 20 })
              Text('今日阅读目标').fontSize(16).fontWeight(FontWeight.Medium).fontColor(this.themeColorTextSecondary).margin({ left: 10 })
              Blank()
              Stack({ alignContent: Alignment.Center }) { AppGlyph({ name: 'pencil', glyphSize: 18 }) }.width(36).height(36).backgroundColor('#24252C').borderRadius(22)
                .onClick(() => this.onUnavailableAction('阅读目标设置尚未迁移'))
            }.width('100%')
            Stack({ alignContent: Alignment.Bottom }) {
              Canvas(this.goalContext).width(240).height(120).onReady(() => this.drawGoalArc())
              Column() {
                Text('0 / 30').fontSize(24).fontWeight(FontWeight.Bold).fontColor(this.themeColorTextPrimary)
                Text('分钟').fontSize(12).fontColor('#B6B8C2').margin({ top: 3 })
              }.width('100%').alignItems(HorizontalAlign.Center).margin({ bottom: 20 })
          }.width('100%').height(136)
          }.width('100%').padding(16).backgroundColor(this.themeAppBackground.length > 0 ? Color.Transparent : (this.themePureBlack ? '#121212' : this.themeColorSurfaceElevated)).borderRadius(16).margin({ top: 12 }).backgroundImage(this.themeItemBackground.length > 0 ? `file://${this.themeItemBackground}` : $r('app.media.transparent_pixel'), ImageRepeat.NoRepeat)
          }
          if (this.visibleSections.includes('backup')) {
          Column() {
            Row() {
              AppGlyph({ name: 'cloudSync', tint: this.themeColorAccent, glyphSize: 20 })
              Column() {
                Text('WebDAV 备份').fontSize(16).fontWeight(FontWeight.Medium).fontColor(this.themeColorTextSecondary)
                Text('暂无 WebDAV 备份').fontSize(12).fontColor('#AEB0BA').margin({ top: 4 })
              }.alignItems(HorizontalAlign.Start).margin({ left: 10 })
            }.width('100%')
            Row() {
              Row() {
                AppGlyph({ name: 'cloudUpload', glyphSize: 15 })
                Text('备份').fontSize(14).fontColor('#C5C7D0').margin({ left: 5 })
              }.layoutWeight(1).justifyContent(FlexAlign.Center).padding({ top: 8, bottom: 8 }).backgroundColor('#17181E').borderRadius(14)
                .onClick(() => this.onUnavailableAction('WebDAV 备份尚未迁移'))
              Row() {
                AppGlyph({ name: 'cloudDownload', glyphSize: 15 })
                Text('恢复').fontSize(14).fontColor('#C5C7D0').margin({ left: 5 })
              }.layoutWeight(1).justifyContent(FlexAlign.Center).padding({ top: 8, bottom: 8 }).backgroundColor('#17181E').borderRadius(14).margin({ left: 8 })
                .onClick(() => this.onUnavailableAction('WebDAV 恢复尚未迁移'))
              Row() {
                AppGlyph({ name: 'settings', glyphSize: 15 })
                Text('设置').fontSize(14).fontColor('#C5C7D0').margin({ left: 5 })
              }.layoutWeight(1).justifyContent(FlexAlign.Center).padding({ top: 8, bottom: 8 }).backgroundColor('#17181E').borderRadius(14).margin({ left: 8 })
                .onClick(() => this.onUnavailableAction('WebDAV 设置尚未迁移'))
            }.margin({ top: 12 })
          }.width('100%').padding(16).backgroundColor(this.themeAppBackground.length > 0 ? Color.Transparent : (this.themePureBlack ? '#121212' : this.themeColorSurfaceElevated)).borderRadius(16).margin({ top: 12, bottom: 18 }).backgroundImage(this.themeItemBackground.length > 0 ? `file://${this.themeItemBackground}` : $r('app.media.transparent_pixel'), ImageRepeat.NoRepeat)
          }
          Column() {
            Text('未选择任何书源集').fontSize(14).fontColor('#AEB0BA').textAlign(TextAlign.Center)
          }.width('100%').height('100%').justifyContent(FlexAlign.Center)
            .alignItems(HorizontalAlign.Center)
        }.width('100%').alignItems(HorizontalAlign.Start).justifyContent(FlexAlign.Start)
          .padding({ left: 16, right: 16, top: 8, bottom: 14 })
          .constraintSize({ minHeight: '100%' })
        }.edgeEffect(EdgeEffect.Spring).width('100%').height('100%').scrollBar(BarState.Off).onScroll(() => {
          const offset = this.homeScroller.currentOffset().yOffset;
          const shouldCollapse = offset > 70 ? true : offset < 24 ? false : this.collapsedHeader;
          if (shouldCollapse !== this.collapsedHeader) {
            // 顶部折叠是位移，用弹簧收尾更自然；弹簧不吃 duration，删掉（写了也不生效）。
            this.getUIContext().animateTo({ curve: curves.springMotion(0.35, 0.86) }, () => {
              this.collapsedHeader = shouldCollapse;
            });
          }
        })
      }.layoutWeight(1).refreshOffset(64)
        .onRefreshing(() => { this.handlePullToRefresh(); })
        // RefreshStatus: Inactive / Drag / OverDrag / Refresh / Done。
        // OverDrag 就是「已拉过阈值、松手会刷」，用它驱动指示器换对勾。
        .onStateChange((state: RefreshStatus) => {
          const armed = state === RefreshStatus.OverDrag;
          if (armed !== this.refreshArmed) { this.refreshArmed = armed; }
        })
    }.width('100%').height('100%').backgroundColor(this.themeAppBackground.length > 0 ? Color.Transparent : (this.themePureBlack ? '#000000' : this.themeColorSurfacePrimary))
      .bindSheet(this.showHomeOptions, this.homeOptionsSheetContent(), {
        height: SheetSize.FIT_CONTENT,
        dragBar: true,
        showClose: false,
        backgroundColor: this.themeColorSurfaceElevated,
        onDisappear: () => this.showHomeOptions = false
      })
  }

  @Builder
  private homeOptionsSheetContent() {
    Column() {
      ForEach(HOME_DASHBOARD_SECTIONS, (section: HomeDashboardSection) => {
        // 整行可点（对齐上游 SwitchSettingItem），开关本身 interactive: false 只画不点。
        Row() {
          Text(this.sectionTitle(section)).fontSize(16).fontColor(this.themeColorTextSecondary).layoutWeight(1)
          UiSwitchControl({
            checked: this.visibleSections.includes(section),
            interactive: false,
            onChange: (visible: boolean) => this.onSectionVisibilityChange(section, visible)
          })
        }
        .width('100%').padding({ left: 16, right: 16, top: 10, bottom: 10 })
        .onClick(() => this.onSectionVisibilityChange(section, !this.visibleSections.includes(section)))
      }, (section: HomeDashboardSection) => section)
    }.width('100%').padding({ top: 8, bottom: 8 })
  }
}

@Component
struct SummaryCard {
  @StorageProp('themeColorTextSecondary') themeColorTextSecondary: string = '#2E3038';
  @StorageProp('themeColorAccent') themeColorAccent: string = '#3F5BD9';
  @StorageProp('themeColorSurfaceElevated') themeColorSurfaceElevated: string = '#FFFFFF';
  @StorageProp('themeAppBackground') themeAppBackground: string = '';
  @StorageProp('themePureBlack') themePureBlack: boolean = false;
  @Prop icon: AppGlyphName = 'chart';
  @Prop title: string = '';
  @Prop value: string = '';
  @Prop unit: string = '';
  onSelect: () => void = () => {};
  @StorageProp('themeItemBackground') themeItemBackground: string = '';
  build() {
    Row() {
      AppGlyph({ name: this.icon, tint: this.themeColorAccent, glyphSize: 20 }).margin({ right: 12 })
      Column() {
        Text(this.title).fontSize(12).fontColor('#B6B8C2')
        Row() {
          Text(this.value).fontSize(16).fontWeight(FontWeight.Medium).fontColor(this.themeColorTextSecondary)
          Text(this.unit).fontSize(12).fontColor('#B6B8C2').margin({ left: 2 })
        }
      }.alignItems(HorizontalAlign.Start)
    }.width('100%').padding({ left: 16, right: 16, top: 10, bottom: 8 })
      .backgroundColor(this.themeAppBackground.length > 0 ? Color.Transparent : (this.themePureBlack ? '#121212' : this.themeColorSurfaceElevated)).borderRadius(14).onClick(() => this.onSelect()).backgroundImage(this.themeItemBackground.length > 0 ? `file://${this.themeItemBackground}` : $r('app.media.transparent_pixel'), ImageRepeat.NoRepeat)
  }
}








