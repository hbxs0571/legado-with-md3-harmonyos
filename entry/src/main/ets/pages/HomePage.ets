import { HEADER_COLLAPSE_THRESHOLD, HEADER_EXPAND_THRESHOLD } from '../components/UiTokens';
import { cardRadiusOf } from '../data/ThemeCardStyle';
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
import { DEFAULT_DAILY_READING_GOAL_MINUTES, MAX_DAILY_READING_GOAL_MINUTES } from '../data/HomeDashboardSettingsRepository';
import { BODY_MEDIUM, BODY_SMALL, HEADLINE_MEDIUM, LABEL_LARGE, LABEL_MEDIUM, LABEL_SMALL, TITLE_MEDIUM, TITLE_SMALL } from '../components/typography/TypographyTokens';
import { i18n, intl } from '@kit.LocalizationKit';

/** 首页右上角菜单的宽度，与详情页溢出菜单同口径。 */
const HOME_MENU_WIDTH: number = 260;

@Component
export struct HomePage {
  @StorageProp('themeColorSurfaceTertiary') themeColorSurfaceTertiary: string = '#F0F1F5';
  @StorageProp('themeColorTextPrimary') themeColorTextPrimary: string = '#1B1C22';
  @StorageProp('themeColorTextSecondary') themeColorTextSecondary: string = '#2E3038';
  @StorageProp('themeColorAccent') themeColorAccent: string = '#3F5BD9';
  @StorageProp('themeColorSurfacePrimary') themeColorSurfacePrimary: string = '#F5F6F8';
  @StorageProp('themeColorSurfaceElevated') themeColorSurfaceElevated: string = '#FFFFFF';
  /** WebDAV 卡副标题的常态色，上游 `onSurfaceVariant`。 */
  @StorageProp('themeColorOnSurfaceVariant') themeColorOnSurfaceVariant: string = '#45483D';
  /** WebDAV 卡副标题的失败色，上游 `colorScheme.error`。 */
  @StorageProp('themeColorError') themeColorError: string = '#BA1A1A';
  /**
   * 三个按钮的容器色。上游 `SmallTonalButton` 走 `SeriesIconButtonStyle.Tonal`，
   * 容器色解析成 `surfaceContainerLow`（`SeriesIconButton.kt:280`），禁用态换成 `outlineVariant`
   * （`SeriesIconButton.kt:288-292`）。本地 `themeColorSurfaceSecondary` 就是 surfaceContainerLow，
   * `themeColorOutlineVariant` 就是 outlineVariant（`data/ThemePalette.ets:1174`/`:1155`）。
   */
  @StorageProp('themeColorSurfaceSecondary') themeColorSurfaceSecondary: string = '#F0F1F5';
  @StorageProp('themeColorOutlineVariant') themeColorOutlineVariant: string = '#C5C8BA';
  @StorageProp('themeAppBackground') themeAppBackground: string = '';
  @StorageProp('themePureBlack') themePureBlack: boolean = false;
  @StorageProp('themeItemBackground') themeItemBackground: string = '';
  /**
   * 底部内缩档的两个输入，由 `pages/Index.ets` 的 `publishTopBottomBarStyle()` 广播。
   * 上游 `HomepageModuleFeed.kt:126`：`contentPadding(bottom = if (useFloatingBottomBar || enableBlur) 120.dp else 8.dp)`。
   */
  @StorageProp('themeUseFloatingBottomBar') themeUseFloatingBottomBar: boolean = false;
  @StorageProp('themeEnableBlur') themeEnableBlur: boolean = false;
  /**
   * 形状两键。首页四张卡在上游都是 `GlassCard`（`HomepageModuleFeed.kt:193` 等）且不传
   * `cornerRadius`，走默认值；`GlassCard.kt:78-82` 在「覆盖卡片圆角」打开时用全局值覆盖。
   * 本地这四张卡各写了一个接近值，未覆盖时保留它们，覆盖时统一跟随。
   */
  @StorageProp('themeCardOverride') themeCardOverride: boolean = false;
  @StorageProp('themeCardRadius') themeCardRadius: number = 16;
  @Prop books: Book[] = [];
  @Prop totalReadTimeMs: number = 0;
  // 今日阅读目标：由 Index 从偏好与今日阅读记录灌入，本页只显示与编辑（回写走 onGoalChange）。
  @Prop goalMinutes: number = DEFAULT_DAILY_READING_GOAL_MINUTES;
  @Prop todayReadMinutes: number = 0;
  /**
   * WebDAV 卡四态，照上游 `HomeViewModel.kt:363-368` 的 `HomeBackupState`：
   * `latestBackupName` 非空即有备份（`latest != null`），`backupLoading` 是 `isLoading`，
   * `backupLoadError` 是 `isLoadError`，`backupActionRunning` 是 `isActionRunning`。
   * 副标题文案的先后顺序也照上游 `HomeScreen.kt:1173-1195` 的 when 分支：加载中 → 有备份 → 失败 → 无备份。
   */
  @Prop latestBackupName: string = '';
  /** 最新备份的毫秒时间戳，0 表示没有；上游显示的是格式化后的时间而不是文件名。 */
  @Prop latestBackupTime: number = 0;
  @Prop backupLoading: boolean = false;
  @Prop backupLoadError: boolean = false;
  @Prop backupActionRunning: boolean = false;
  /** 上游 `HomeIntent.BackupClick` / `RestoreClick` / `BackupSettingsClick` / `RetryBackupInfo`。 */
  onBackupClick: () => void = () => {};
  onRestoreClick: () => void = () => {};
  onRetryBackupInfo: () => void = () => {};
  /**
   * 备份/恢复选项弹层：'' 关闭 / 'backup' 备份三选一 / 'restore' 恢复二选一。
   * 上游是 `HomeSheet.BackupOptions` 与 `HomeSheet.RestoreOptions` 两个 sheet
   * （`HomeScreen.kt:1375-1399`），本地复用本组件已有的那一个 bindSheet（同组件只能挂一个）。
   */
  @Prop backupSheet: string = '';
  onSelectBackupDestination: (destination: string) => void = (_destination: string) => {};
  onSelectRestoreDestination: (destination: string) => void = (_destination: string) => {};
  onDismissBackupSheet: () => void = () => {};
  onGoalChange: (minutes: number) => void = (_minutes: number) => {};
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
  /** 当前下拉距离（vp），来自 Refresh.onOffsetChange，用来驱动指示器齿轮跟手旋转。 */
  @State refreshPullOffset: number = 0;
  @State collapsedHeader: boolean = false;
  // 设定阅读目标对话框：铅笔按钮打开，确认回写偏好。
  @State showGoalDialog: boolean = false;
  @State goalDraft: string = '';
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
      refreshing: this.refreshing,
      pullDistance: this.refreshPullOffset
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
    // 上游 `HomeScreen.kt:448-452`：设置图标对应首页模块管理，文案取 `R.string.homepage_module_manage`。
    TopBarButton({
      icon: 'settings',
      showDivider: false,
      accessibilityLabel: '首页模块管理',
      onSelect: () => { this.showHomeOptions = !this.showHomeOptions; }
    })
    // menuMode: true 让 TopBarButton 不注册自己的 onClick，点击手势交给外层 bindPopup。
    // 上游 `HomeScreen.kt:454-457`：溢出菜单入口取 `R.string.more_menu`。
    TopBarButton({ icon: 'more', menuMode: true, accessibilityLabel: '更多菜单' })
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

  /**
   * 首页卡片圆角。四张卡（最近阅读 / 今日目标 / WebDAV 备份 / 摘要）在上游都不传
   * `cornerRadius`，走 `MiuixCardDefaults.CornerRadius`；本地此前分别写死 17/16/16/14。
   * 未开「覆盖卡片圆角」时保留这些值（与上游「不传即默认」的观感一致），
   * 打开后统一由全局值接管（`GlassCard.kt:78-82`）。
   */
  private homeCardRadius(perCardRadius: number): number {
    return cardRadiusOf(this.themeCardOverride, this.themeCardRadius, perCardRadius);
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
    const progress = this.goalMinutes > 0 ? Math.min(1, this.todayReadMinutes / this.goalMinutes) : 0;
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
        // 内容层用 `.position({ x: 0, y: 0 })`（见链首）钉在本来的位置：不设它，Refresh
        // 会依据下拉距离把整个子组件往下推，观感是「整页被拖下去」。上游 PullToRefreshBox
        // 只有指示器进出、内容不动（refresh.d.ts:100-104 的原话：给子组件设 position 后，
        // 子组件相对 Refresh 的位置固定，不随下拉手势下移）。
        Scroll(this.homeScroller) {
        Column() {
          if (this.visibleSections.includes('recentBook') && this.getLocalBooks().length > 0) {
            Stack({ alignContent: Alignment.Bottom }) {
            Column() {
              Row() {
                AppGlyph({ name: 'book', tint: this.themeColorAccent, glyphSize: 20 })
                Text(BookRepository.isBodyMissing(this.getRecentBook()) ? '已恢复书目 · 缺少正文' : '最近阅读')
                  .fontSize(BODY_MEDIUM).fontWeight(FontWeight.Medium).fontColor(this.themeColorTextSecondary).margin({ left: 10 })
              }.margin({ bottom: 10 })
              Row() {
                BookCover({ book: this.getRecentBook(), mini: true, displayWidth: 56, displayHeight: 78 })
                Column() {
                  Text(this.getRecentBook().title).fontSize(BODY_MEDIUM).fontWeight(FontWeight.Medium).fontColor(this.themeColorTextPrimary).maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
                  Text(this.recentBookSubtitle()).fontSize(BODY_SMALL).fontColor('#B6B8C2').margin({ top: 6 })
                  Text(this.getRecentBook().lastChapter).fontSize(BODY_SMALL).fontColor('#B6B8C2').margin({ top: 6 })
                }.alignItems(HorizontalAlign.Start).layoutWeight(1).margin({ left: 14 })
                Text(`${Math.round(this.getRecentBookProgress(this.getRecentBook()))}%`).fontSize(LABEL_SMALL).fontColor('#D7DFFB').padding({ left: 9, right: 9, top: 6, bottom: 6 }).backgroundColor('#383D50').borderRadius(8)
              }.width('100%')
            }.width('100%').padding({ left: 16, right: 16, top: 16, bottom: 14 })
            Progress({ value: this.getRecentBookProgress(this.getRecentBook()), total: 100, type: ProgressType.Linear })
              .width('100%').height(3).color(this.themeColorAccent).backgroundColor('#3A3B43')
              .animation({ duration: 300, curve: Curve.EaseInOut })
            }.width('100%').backgroundColor(this.themeAppBackground.length > 0 ? Color.Transparent : (this.themePureBlack ? '#121212' : this.themeColorSurfaceElevated)).borderRadius(this.homeCardRadius(17)).backgroundImage(this.themeItemBackground.length > 0 ? `file://${this.themeItemBackground}` : $r('app.media.transparent_pixel'), ImageRepeat.NoRepeat)
              .onClick(() => this.openBook(this.getRecentBook()))
          } else if (this.visibleSections.includes('recentBook')) {
            Column() {
              Row() {
                AppGlyph({ name: 'book', tint: this.themeColorAccent, glyphSize: 20 })
                Text('最近阅读').fontSize(TITLE_MEDIUM).fontWeight(FontWeight.Medium).fontColor(this.themeColorTextSecondary).margin({ left: 10 })
              }.alignSelf(ItemAlign.Start)
              Blank().layoutWeight(1)
              Text('暂无阅读记录').fontSize(TITLE_SMALL).fontColor('#AEB0BA').alignSelf(ItemAlign.Center)
              Blank().layoutWeight(1)
            }.width('100%').height(160).padding({ left: 16, right: 16, top: 16, bottom: 14 }).justifyContent(FlexAlign.Center)
              .backgroundColor(this.themeAppBackground.length > 0 ? Color.Transparent : (this.themePureBlack ? '#121212' : this.themeColorSurfaceElevated)).borderRadius(this.homeCardRadius(17)).alignItems(HorizontalAlign.Center).backgroundImage(this.themeItemBackground.length > 0 ? `file://${this.themeItemBackground}` : $r('app.media.transparent_pixel'), ImageRepeat.NoRepeat)
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
                    // 上游取 HomeScreen.kt:1031 bookAccessibilityLabel(name, author)
                    .accessibilityText(`${book.title}，${book.author}`)
                }, (book: Book) => book.id)
              }
            }.width('100%').scrollable(ScrollDirection.Horizontal).scrollBar(BarState.Off).margin({ top: 12 })
          }
          if (this.visibleSections.includes('dailyGoal')) {
          Column() {
            Row() {
              AppGlyph({ name: 'goal', tint: this.themeColorAccent, glyphSize: 20 })
              Text('今日阅读目标').fontSize(TITLE_MEDIUM).fontWeight(FontWeight.Medium).fontColor(this.themeColorTextSecondary).margin({ left: 10 })
              Blank()
              Stack({ alignContent: Alignment.Center }) { AppGlyph({ name: 'pencil', glyphSize: 18 }) }.width(36).height(36).backgroundColor('#24252C').borderRadius(22)
                .onClick(() => {
                  this.goalDraft = `${this.goalMinutes}`;
                  this.showGoalDialog = true;
                })
                // 上游取 HomeScreen.kt:1085 home_set_goal
                .accessibilityText('设定目标')
            }.width('100%')
            Stack({ alignContent: Alignment.Bottom }) {
              Canvas(this.goalContext).width(240).height(120).onReady(() => this.drawGoalArc())
              Column() {
                Text(`${this.todayReadMinutes} / ${this.goalMinutes}`).fontSize(HEADLINE_MEDIUM).fontWeight(FontWeight.Bold).fontColor(this.themeColorTextPrimary)
                Text('分钟').fontSize(BODY_SMALL).fontColor('#B6B8C2').margin({ top: 3 })
              }.width('100%').alignItems(HorizontalAlign.Center).margin({ bottom: 20 })
          }.width('100%').height(136)
          }.width('100%').padding(16).backgroundColor(this.themeAppBackground.length > 0 ? Color.Transparent : (this.themePureBlack ? '#121212' : this.themeColorSurfaceElevated)).borderRadius(this.homeCardRadius(16)).margin({ top: 12 }).backgroundImage(this.themeItemBackground.length > 0 ? `file://${this.themeItemBackground}` : $r('app.media.transparent_pixel'), ImageRepeat.NoRepeat)
          }
          if (this.visibleSections.includes('backup')) {
          Column({ space: 12 }) {
            Row({ space: 10 }) {
              // 上游 `HomeScreen.kt:1198` 的 `AppIcon(CloudSync, tint = primary, offset y = 1.dp)`。
              AppGlyph({ name: 'cloudSync', tint: this.themeColorAccent, glyphSize: 20 }).margin({ top: 1 })
              Column({ space: 2 }) {
                Text('WebDAV 备份').fontSize(TITLE_MEDIUM).fontWeight(FontWeight.Medium).fontColor(this.themeColorTextSecondary)
                // 四态顺序照上游 `HomeScreen.kt:1173-1195` 的 when：加载中 → 有备份 → 失败 → 无备份。
                // 有备份时上游显示的是 `DateFormat.getDateTimeInstance(MEDIUM, SHORT)` 格式化的时间，
                // 不是文件名；失败态用 colorScheme.error。
                Text(this.backupSubtitleText())
                  .fontSize(BODY_SMALL)
                  .fontColor(this.backupLoadError && !this.backupLoading ? this.themeColorError : this.themeColorOnSurfaceVariant)
              }.alignItems(HorizontalAlign.Start).layoutWeight(1)
              if (this.backupLoading || this.backupActionRunning) {
                // 上游 `AppContainedLoadingIndicator(size = 24.dp)`。
                LoadingProgress().width(24).height(24).color(this.themeColorAccent)
              }
            }.width('100%').alignItems(VerticalAlign.Center)
            if (this.backupLoadError && !this.backupLoading) {
              // 上游 `:1213-1220`：加载失败时整行只给一个「重试」按钮，不给备份/恢复/设置。
              this.BackupTonalButton('profileRefresh', '重试', !this.backupActionRunning, () => this.onRetryBackupInfo())
            } else {
              Row({ space: 8 }) {
                this.BackupTonalButton('cloudUpload', '备份', !this.backupActionRunning, () => this.onBackupClick())
                this.BackupTonalButton('cloudDownload', '恢复', !this.backupActionRunning, () => this.onRestoreClick())
                this.BackupTonalButton('settings', '设置', !this.backupActionRunning, () => this.onOpenBackup())
              }.width('100%')
            }
          }.width('100%').alignItems(HorizontalAlign.Start).padding(16).backgroundColor(this.themeAppBackground.length > 0 ? Color.Transparent : (this.themePureBlack ? '#121212' : this.themeColorSurfaceElevated)).borderRadius(this.homeCardRadius(16)).margin({ top: 12, bottom: 18 }).backgroundImage(this.themeItemBackground.length > 0 ? `file://${this.themeItemBackground}` : $r('app.media.transparent_pixel'), ImageRepeat.NoRepeat)
          }
          Column({ space: 12 }) {
            AppGlyph({ name: 'add', tint: this.themeColorTextSecondary, glyphSize: 32 })
            Text('暂无已加入的模块').fontSize(TITLE_SMALL).fontColor(this.themeColorTextSecondary)
            Row() {
              Text('浏览书源模块添加').fontSize(LABEL_LARGE).fontColor(this.themeColorAccent)
            }.padding({ left: 16, right: 16, top: 8, bottom: 8 })
              .backgroundColor(this.themeColorSurfaceElevated).borderRadius(this.homeCardRadius(14))
              .onClick(() => this.onUnavailableAction('浏览书源模块尚未迁移'))
          }.width('100%').constraintSize({ minHeight: 220 }).justifyContent(FlexAlign.Center)
            .alignItems(HorizontalAlign.Center)
        }.width('100%').alignItems(HorizontalAlign.Start).justifyContent(FlexAlign.Start)
          // 底部内缩：上游 `HomepageModuleFeed.kt:126` 是
          // `contentPadding(bottom = if (useFloatingBottomBar || enableBlur) 120.dp else 8.dp)`。
          // 抬起档（120）照做；未抬起档本地原本是 14（与首页顶部 8 的卡片间距配套），
          // 这一档不改，只在注释里登记与上游 8.dp 的差异。
          .padding({
            left: 16, right: 16, top: 8,
            bottom: this.themeUseFloatingBottomBar || this.themeEnableBlur ? 120 : 14
          })
          .constraintSize({ minHeight: '100%' })
        }.position({ x: 0, y: 0 })
        .edgeEffect(EdgeEffect.Spring).width('100%').height('100%').scrollBar(BarState.Off).onScroll(() => {
          const offset = this.homeScroller.currentOffset().yOffset;
          const shouldCollapse = offset > HEADER_COLLAPSE_THRESHOLD ? true : offset < HEADER_EXPAND_THRESHOLD ? false : this.collapsedHeader;
          if (shouldCollapse !== this.collapsedHeader) {
            // 顶部折叠是位移，用弹簧收尾更自然；弹簧不吃 duration，删掉（写了也不生效）。
            this.getUIContext().animateTo({ curve: curves.springMotion(0.35, 0.86) }, () => {
              this.collapsedHeader = shouldCollapse;
            });
          }
        })
      }.layoutWeight(1).refreshOffset(64)
        // 内容层已被 position 钉住不动，跟着下拉走的只有指示器，所以这里要 1（完全跟手）：
        // 压小比例会让指示器能拉出的距离也变短，上游不是这个手感
        // （refresh.d.ts 的 pullDownRatio：1 = 完全跟手）。
        .pullDownRatio(1)
        // 指示器最多下移 120vp：内容已被 position 钉住，只有指示器跟手，不封顶的话
        // 一拉就能滑到屏幕中部（实测到了 y≈1984），上游是「从顶部探出一小段」。
        .maxPullDownDistance(120)
        .onRefreshing(() => { this.handlePullToRefresh(); })
        // RefreshStatus: Inactive / Drag / OverDrag / Refresh / Done。
        // OverDrag 就是「已拉过阈值、松手会刷」，用它驱动指示器换对勾。
        .onStateChange((state: RefreshStatus) => {
          const armed = state === RefreshStatus.OverDrag;
          if (armed !== this.refreshArmed) { this.refreshArmed = armed; }
        })
        // 每帧报当前下拉距离（vp），喂给指示器做跟手旋转。
        .onOffsetChange((offset: number) => {
          this.refreshPullOffset = offset;
        })
    }.width('100%').height('100%').backgroundColor(this.themeAppBackground.length > 0 ? Color.Transparent : (this.themePureBlack ? '#000000' : this.themeColorSurfacePrimary))
      // 同一组件只挂一个 bindSheet（项目已踩过挂多个只有最后一个生效的坑），
      // 首页组件面板、设定阅读目标对话框、备份三选一、恢复二选一共用，按状态切换内容。
      // 上游这四个是独立组件：`HomeSheet`（组件面板）、`HomeDialog.SetReadingGoal`、
      // `HomeSheet.BackupOptions`、`HomeSheet.RestoreOptions`（`HomeScreen.kt:1375-1399`）。
      .bindSheet(this.showHomeOptions || this.showGoalDialog || this.backupSheet.length > 0, this.homeSheetContent(), {
        height: SheetSize.FIT_CONTENT,
        dragBar: true,
        showClose: false,
        backgroundColor: this.themeColorSurfaceTertiary,
        onDisappear: () => { this.showHomeOptions = false; this.showGoalDialog = false; this.onDismissBackupSheet(); }
      })
  }

  /** 确认设定阅读目标：解析输入、钳到 [1, 1440]（与上游 coerceIn 同口径）后回写偏好。 */
  private confirmGoal(): void {
    const parsed: number = parseInt(this.goalDraft, 10);
    const minutes: number = isNaN(parsed)
      ? this.goalMinutes
      : Math.min(MAX_DAILY_READING_GOAL_MINUTES, Math.max(1, parsed));
    this.onGoalChange(minutes);
    this.showGoalDialog = false;
  }

  /**
   * WebDAV 卡副标题四态文案，照上游 `HomeScreen.kt:1173-1195` 的 when 顺序：
   * `isLoading` → 加载中；`latestBackup != null` → 「最近备份：<时间>」；
   * `isLoadError` → 加载失败；否则 → 无备份。
   */
  private backupSubtitleText(): string {
    if (this.backupLoading) {
      return '正在获取备份信息…';
    }
    if (this.latestBackupTime > 0) {
      return `最近备份：${this.formatBackupTime(this.latestBackupTime)}`;
    }
    if (this.backupLoadError) {
      return '无法获取备份信息';
    }
    return '暂无 WebDAV 备份';
  }

  /**
   * 备份时间格式化。上游用 `DateFormat.getDateTimeInstance(DateFormat.MEDIUM, DateFormat.SHORT)`，
   * 中文环境下的形态是「2026年11月23日 23:15」。这里走 `@ohos.intl` 的
   * `DateTimeFormat`（`@ohos.intl.d.ts:791`），`dateStyle`/`timeStyle` 两档见 `:435-488`；
   * 不用 `toLocaleString()`：它拿不到 MEDIUM/SHORT 这两档粒度。
   */
  private formatBackupTime(timestamp: number): string {
    try {
      const options: intl.DateTimeOptions = { dateStyle: 'medium', timeStyle: 'short' };
      const formatter: intl.DateTimeFormat = new intl.DateTimeFormat(i18n.System.getSystemLocale(), options);
      return formatter.format(new Date(timestamp));
    } catch (_) {
      // 老设备没有 dateStyle/timeStyle 时退到逐字段拼，形态与 MEDIUM/SHORT 一致。
      const d: Date = new Date(timestamp);
      const p2 = (v: number): string => v < 10 ? '0' + v : String(v);
      return `${d.getFullYear()}年${d.getMonth() + 1}月${d.getDate()}日 ${p2(d.getHours())}:${p2(d.getMinutes())}`;
    }
  }

  /**
   * 卡上的一颗 `SmallTonalButton`（上游 `SmallTonalButton.kt:12-51`）：
   * 文字 + 18dp 图标、`labelMedium`、内距 8/4、间距 4、圆角 `RoundedCornerShape(50)`（胶囊）、
   * 容器 `surfaceContainerLow`、内容 `onSurfaceVariant`；禁用时容器换 `outlineVariant`、
   * 内容 alpha 0.38（`SeriesIconButton.kt:288-303`）。
   */
  @Builder
  private BackupTonalButton(icon: AppGlyphName, label: string, buttonEnabled: boolean, action: () => void) {
    Row({ space: 4 }) {
      AppGlyph({ name: icon, glyphSize: 18, tint: buttonEnabled ? this.themeColorOnSurfaceVariant : this.themeColorOnSurfaceVariant })
        .opacity(buttonEnabled ? 1 : 0.38)
      Text(label).fontSize(LABEL_MEDIUM).fontColor(this.themeColorOnSurfaceVariant).opacity(buttonEnabled ? 1 : 0.38)
    }
    .layoutWeight(1).justifyContent(FlexAlign.Center)
    .padding({ left: 8, right: 8, top: 4, bottom: 4 })
    .backgroundColor(buttonEnabled ? this.themeColorSurfaceSecondary : this.themeColorOutlineVariant)
    .borderRadius(50)
    .onClick(() => { if (buttonEnabled) { action(); } })
  }

  @Builder
  private homeSheetContent() {
    if (this.showGoalDialog) {
      this.goalDialogContent();
    } else if (this.backupSheet === 'backup') {
      this.backupOptionSheetContent();
    } else if (this.backupSheet === 'restore') {
      this.restoreOptionSheetContent();
    } else {
      this.homeOptionsSheetContent();
    }
  }

  /**
   * 备份三选一，对齐上游 `HomeScreen.kt:1375-1386` 的 `BackupOptionSheet`：
   * 标题「备份」，三张卡分别是「备份至本地」「备份至网络」「备份至本地与网络」
   * （文案取 `strings.xml:1045`/`:1046`/`:1044`）。
   */
  @Builder
  private backupOptionSheetContent() {
    Column() {
      Text('备份').fontSize(TITLE_MEDIUM).fontColor(this.themeColorTextPrimary)
        .alignSelf(ItemAlign.Start).padding({ left: 18, top: 16, bottom: 8 })
      Row({ space: 12 }) {
        this.BackupOptionCard('folder', '备份至本地', () => this.onSelectBackupDestination('local'))
        this.BackupOptionCard('cloud', '备份至网络', () => this.onSelectBackupDestination('webdav'))
      }.width('100%').padding({ left: 18, right: 18 })
      Row({ space: 12 }) {
        this.BackupOptionCard('grid', '备份至本地与网络', () => this.onSelectBackupDestination('both'))
        Blank().layoutWeight(1)
      }.width('100%').padding({ left: 18, right: 18, top: 12, bottom: 24 })
    }.width('100%').alignItems(HorizontalAlign.Start)
  }

  /**
   * 恢复二选一，对齐上游 `HomeScreen.kt:1387-1399` 的 `RestoreOptionSheet`：
   * 「从本地恢复」「从网络恢复」两张卡（文案取 `strings.xml:205` 与 `:190`）。
   */
  @Builder
  private restoreOptionSheetContent() {
    Column() {
      Text('恢复').fontSize(TITLE_MEDIUM).fontColor(this.themeColorTextPrimary)
        .alignSelf(ItemAlign.Start).padding({ left: 18, top: 16, bottom: 8 })
      Row({ space: 12 }) {
        this.BackupOptionCard('folder', '从本地恢复', () => this.onSelectRestoreDestination('local'))
        this.BackupOptionCard('cloud', '从网络恢复', () => this.onSelectRestoreDestination('webdav'))
      }.width('100%').padding({ left: 18, right: 18, bottom: 24 })
    }.width('100%').alignItems(HorizontalAlign.Start)
  }

  /** 弹层里的 100vp 方卡，对齐上游 `OptionCard`（`OptionSheet.kt:55-87`）。 */
  @Builder
  private BackupOptionCard(icon: AppGlyphName, label: string, action: () => void) {
    Column({ space: 8 }) {
      AppGlyph({ name: icon, glyphSize: 32, tint: this.themeColorAccent })
      Text(label).fontSize(LABEL_MEDIUM).fontColor(this.themeColorTextPrimary)
        .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis }).textAlign(TextAlign.Center)
    }.layoutWeight(1).height(100).justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
      .backgroundColor(this.themeColorSurfaceSecondary).borderRadius(12)
      .onClick(action)
  }

  /** 设定阅读目标对话框（上游 SetReadingGoal）：标题/标签照抄 strings.xml。 */
  @Builder
  private goalDialogContent() {
    Column() {
      Text('设定阅读目标').fontSize(TITLE_MEDIUM).fontColor(this.themeColorTextPrimary)
        .alignSelf(ItemAlign.Start).padding({ left: 18, top: 16, bottom: 8 })
      Row() {
        Text('目标（分钟）').fontSize(TITLE_SMALL).fontColor(this.themeColorTextSecondary).width(100)
        TextInput({ text: this.goalDraft, placeholder: '30' })
          .type(InputType.Number).fontSize(TITLE_SMALL).height(44).layoutWeight(1)
          .backgroundColor('#22232A').borderRadius(9)
          .onChange((value: string) => { this.goalDraft = value; })
      }.width('100%').padding({ left: 18, right: 18, top: 8, bottom: 8 })
      Row() {
        Text('取消').fontSize(LABEL_LARGE).fontColor(this.themeColorTextSecondary).padding(10)
          .onClick(() => { this.showGoalDialog = false; this.goalDraft = ''; })
        Blank()
        Text('确定').fontSize(LABEL_LARGE).fontColor(this.themeColorAccent).padding(10)
          .onClick(() => this.confirmGoal())
      }.width('100%').padding({ left: 10, right: 10, top: 6, bottom: 16 })
    }.width('100%').alignItems(HorizontalAlign.Start)
  }

  @Builder
  private homeOptionsSheetContent() {
    Column() {
      ForEach(HOME_DASHBOARD_SECTIONS, (section: HomeDashboardSection) => {
        // 整行可点（对齐上游 SwitchSettingItem），开关本身 interactive: false 只画不点。
        Row() {
          Text(this.sectionTitle(section)).fontSize(TITLE_MEDIUM).fontColor(this.themeColorTextSecondary).layoutWeight(1)
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
  /** 形状两键：摘要卡在上游也是不传 cornerRadius 的 GlassCard，理由见 HomePage.homeCardRadius()。 */
  @StorageProp('themeCardOverride') themeCardOverride: boolean = false;
  @StorageProp('themeCardRadius') themeCardRadius: number = 16;
  build() {
    Row() {
      AppGlyph({ name: this.icon, tint: this.themeColorAccent, glyphSize: 20 }).margin({ right: 12 })
      Column() {
        Text(this.title).fontSize(BODY_SMALL).fontColor('#B6B8C2')
        Row() {
          Text(this.value).fontSize(TITLE_MEDIUM).fontWeight(FontWeight.Medium).fontColor(this.themeColorTextSecondary)
          Text(this.unit).fontSize(BODY_SMALL).fontColor('#B6B8C2').margin({ left: 2 })
        }
      }.alignItems(HorizontalAlign.Start)
    }.width('100%').padding({ left: 16, right: 16, top: 10, bottom: 8 })
      .backgroundColor(this.themeAppBackground.length > 0 ? Color.Transparent : (this.themePureBlack ? '#121212' : this.themeColorSurfaceElevated)).borderRadius(cardRadiusOf(this.themeCardOverride, this.themeCardRadius, 14)).onClick(() => this.onSelect()).backgroundImage(this.themeItemBackground.length > 0 ? `file://${this.themeItemBackground}` : $r('app.media.transparent_pixel'), ImageRepeat.NoRepeat)
  }
}








