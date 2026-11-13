import { Book } from '../model/Book';
import { BookRepository } from '../data/BookRepository';
import { BookCover } from '../components/BookCover';
import { AppGlyph, AppGlyphName } from '../components/AppGlyph';
import { HomeDashboardSection, HOME_DASHBOARD_SECTIONS } from '../data/HomeDashboardSettingsRepository';

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
  @State showHomeOptions: boolean = false;
  @State refreshing: boolean = false;
  @State collapsedHeader: boolean = false;
  /** 顶栏底色（含不透明度与模糊透明度），由 `Index.publishTopBottomBarStyle()` 广播。 */
  @StorageProp('themeTopBarBackground') themeTopBarBackground: string = '';
  /** 顶栏模糊半径；0 表示不模糊。 */
  @StorageProp('themeTopBarBlurRadius') themeTopBarBlurRadius: number = 0;
  private homeScroller: Scroller = new Scroller();

  private handlePullToRefresh(): void {
    this.refreshing = true;
    this.onUnavailableAction('首页数据刷新尚未迁移');
    setTimeout(() => this.refreshing = false, 500);
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
    Menu() {
      MenuItem({ content: '首页组件' }).height(48)
        .onClick(() => this.showHomeOptions = true)
    }.backgroundColor(this.themeAppBackground.length > 0 ? Color.Transparent : (this.themePureBlack ? '#121212' : this.themeColorSurfaceElevated)).fontColor(this.themeColorTextPrimary).radius(20)
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
      Column() {
        Row() {
          Text('首页').fontSize(22).fontWeight(FontWeight.Medium).fontColor(this.themeColorTextPrimary)
            .opacity(this.collapsedHeader ? 1 : 0)
          Blank()
          Stack({ alignContent: Alignment.Center }) { AppGlyph({ name: 'settings', glyphSize: 20 }) }
            .width(36).height(36).backgroundColor(this.themeAppBackground.length > 0 ? Color.Transparent : (this.themePureBlack ? '#121212' : this.themeColorSurfaceElevated)).borderRadius(22)
            .onClick(() => this.showHomeOptions = !this.showHomeOptions)
          Stack({ alignContent: Alignment.Center }) { AppGlyph({ name: 'more', glyphSize: 20 }) }
            .width(36).height(36).backgroundColor(this.themeAppBackground.length > 0 ? Color.Transparent : (this.themePureBlack ? '#121212' : this.themeColorSurfaceElevated)).borderRadius(22).margin({ left: 8 })
            .bindMenu(this.MoreMenu, { placement: Placement.BottomRight })
        }.width('100%').height(64).padding({ left: 16, right: 12 })
        Text('首页').fontSize(28).fontWeight(FontWeight.Medium).fontColor(this.themeColorTextPrimary)
          .width('100%').height(72).padding({ left: 16, bottom: 14 })
          .opacity(this.collapsedHeader ? 0 : 1)
      }.width('100%').height(this.collapsedHeader ? 64 : 136).clip(true)
        .backgroundColor(this.themeTopBarBackground.length > 0 ? this.themeTopBarBackground
          : (this.themeAppBackground.length > 0 ? Color.Transparent
            : (this.themePureBlack ? '#000000' : this.themeColorSurfacePrimary)))
        .backdropBlur(this.themeTopBarBlurRadius)
      Refresh({ refreshing: this.refreshing }) {
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
                  Text(this.getRecentBook().format === 'epub' ? this.getRecentBook().author : '本地 TXT').fontSize(12).fontColor('#B6B8C2').margin({ top: 6 })
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
        }.width('100%').height('100%').scrollBar(BarState.Off).onScroll(() => {
          const offset = this.homeScroller.currentOffset().yOffset;
          const shouldCollapse = offset > 70 ? true : offset < 24 ? false : this.collapsedHeader;
          if (shouldCollapse !== this.collapsedHeader) {
            animateTo({ duration: 220, curve: Curve.EaseInOut }, () => this.collapsedHeader = shouldCollapse);
          }
        })
      }.layoutWeight(1).refreshOffset(64).onRefreshing(() => this.handlePullToRefresh())
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
        Row() {
          Text(this.sectionTitle(section)).fontSize(16).fontColor(this.themeColorTextSecondary).layoutWeight(1)
          Toggle({ type: ToggleType.Switch, isOn: this.visibleSections.includes(section) })
            .onChange((visible: boolean) => this.onSectionVisibilityChange(section, visible))
        }.width('100%').padding({ left: 16, right: 16, top: 10, bottom: 10 })
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








