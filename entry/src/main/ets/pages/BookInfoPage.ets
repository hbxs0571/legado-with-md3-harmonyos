import { DURATION_FADE } from '../components/UiTokens';
import { fileIo } from '@kit.CoreFileKit';
import { Book, BookMediaType, bookCoverColor } from '../model/Book';
import { BookGroup } from '../model/BookGroup';
import { BookRepository } from '../data/BookRepository';
import { AppGlyph, AppGlyphName } from '../components/AppGlyph';
import { BookCover } from '../components/BookCover';
import { BookInfoBackdropStyle, resolveBookInfoBackdropStyleFor } from '../data/BookInfoBackdropStyle';
import { ImageSeedColorExtractor } from '../data/ImageSeedColorExtractor';
import { CoverSettings, DEFAULT_COVER_SETTINGS } from '../data/CoverSettingsRepository';
import { BookReadRecordDay, BookReadRecordPanel, BookReadRecordSession } from '../model/ReadRecord';
import { HighlightTagRule } from '../model/HighlightTagRule';
import { HighlightedTag, matchHighlightTags } from '../data/HighlightTagMatcher';
import { pasteboard } from '@kit.BasicServicesKit';
import { common, Want } from '@kit.AbilityKit';
import {
  TopBarButton, TopBarBackButton, topBarButtonSize, topBarActionSpacing,
  TOP_BAR_SIDE_PADDING, TOP_BAR_ACTIONS_END
} from '../components/TopBar';
import { UiMenuItem, UiMenuPanel } from '../components/UiMenu';
import { AppLog } from '../lib/AppLog';
import { WebDavSync } from '../lib/WebDavSync';
import { RichIntro } from '../components/RichIntro';
import { BODY_LARGE, BODY_SMALL, BODY_SMALL_LINE_HEIGHT, HEADLINE_LARGE, HEADLINE_MEDIUM, LABEL_LARGE, LABEL_MEDIUM, LABEL_SMALL, TITLE_LARGE, TITLE_MEDIUM, TITLE_SMALL, TITLE_SMALL_LINE_HEIGHT } from '../components/typography/TypographyTokens';

/** 溢出菜单面板宽度。上游宽度由内容驱动，本地给固定宽并让长文案省略。 */
const OVERFLOW_MENU_WIDTH: number = 220;
/** 底栏 FAB 高度，对齐上游 ExtendedFloatingActionButton 的 56dp。 */
const READ_FAB_HEIGHT: number = 56;
/** 内容底部留白：给浮在内容上的 FAB 让位，对齐上游 `+ 88.dp`。 */
const CONTENT_BOTTOM_INSET: number = 88;

@Component
export struct BookInfoPage {
  @StorageProp('themeColorTextPrimary') themeColorTextPrimary: string = '#1B1C22';
  @StorageProp('themeColorTextSecondary') themeColorTextSecondary: string = '#2E3038';
  @StorageProp('themeColorTextTertiary') themeColorTextTertiary: string = '#6A6D77';
  @StorageProp('themeColorAccent') themeColorAccent: string = '#3F5BD9';
  @StorageProp('themeColorSurfacePrimary') themeColorSurfacePrimary: string = '#F5F6F8';
  @StorageProp('themeColorSurfaceSecondary') themeColorSurfaceSecondary: string = '#FFFFFF';
  @StorageProp('themeColorSurfaceTertiary') themeColorSurfaceTertiary: string = '#F0F1F5';
  /** surfaceContainerHigh 档，本地降级顶替上游的 secondaryContainer（ThemePalette 无该字段）。 */
  @StorageProp('themeColorSurfaceElevated') themeColorSurfaceElevated: string = '#FFFFFF';
  @StorageProp('themeAppBackground') themeAppBackground: string = '';
  @StorageProp('themePureBlack') themePureBlack: boolean = false;
  /**
   * 状态栏高度（vp）。打开全屏布局后本页内容画到状态栏底下，
   * 自绘顶栏与头部占位都要让出这一段，否则返回键与状态栏文字重叠。
   */
  @StorageProp('appTopInset') appTopInset: number = 0;
  /** 顶栏按钮版式（tonal / plain / outlined / glass / liquid），顶栏三颗按钮的底色由它决定。 */
  @StorageProp('themeTopBarButtonStyle') themeTopBarButtonStyle: string = 'tonal';
  // 批8（:369）：加入书架成功后 Index 会整体替换 selectedBook，@Watch 在这里接手
  // 上游 `BookInfoScreen.kt:1398-1414 LaunchedEffect(inBookshelf)` 的两段引导提示。
  @Prop @Watch('onBookPropChanged') book: Book = {
    id: '', title: '', author: '', category: '', lastChapter: '', progress: 0, isLocal: true
  };
  @Prop groups: BookGroup[] = [];
  /** 界面颜色是否跟随封面取色，对齐上游 `ThemeSettings.bookInfoFollowCoverColor`。 */
  @Prop followCoverColor: boolean = true;
  /** 网络封面背景模式，对齐上游 `bookInfoNetworkCoverBackground`。 */
  @Prop networkCoverBackground: string = 'on';
  /** 默认封面背景模式，对齐上游 `bookInfoDefaultCoverBackground`。 */
  @Prop defaultCoverBackground: string = 'on';
  /** 封面文字设置，从 Index 下发；详情页封面受 A8「限制封面比例」约束。 */
  @Prop coverSettings: CoverSettings = DEFAULT_COVER_SETTINGS;
  /** 全书架书目，删除面板用它找同名副本（批 7 的 `:338`）。 */
  @Prop books: Book[] = [];
  /** 高亮标签规则，从 Index 启动时 load 一次下发；详情页自己 await 会让首帧空。 */
  @Prop highlightTagRules: HighlightTagRule[] = [];
  /**
   * 批7（:1156）：简介富文本要的 baseUrl —— 在线书是书源地址，本地书是正文文件所在目录。
   * 为空时内联 HTML 里的相对链接按 about:blank 解析，不影响显示。
   */
  @Prop bookBaseUrl: string = '';
  /** 批7（:1164）：简介里 onclick 脚本要执行书源 JS，需要书源 URL；本地书为空。 */
  @Prop bookSourceUrl: string = '';
  /**
   * 批10（:553）：这本书所属书源的显示名，由 Index 从 Book.origin 反查 BookSourceRepository 注入。
   *
   * 页面自己不去查仓库（每次渲染都会走一次异步）。为空表示本地书、或源已删、或老数据没记源名，
   * 此时来源标签退回路径/「未知来源」，不硬造名字。
   */
  @Prop bookSourceName: string = '';
  /** 移出书架前是否二次确认（批 7 的 `:291`）。 */
  @Prop deleteAlertEnabled: boolean = true;
  onBack: () => void = () => {};
  /** 打开书籍信息编辑页（批 5 的独立整页，不是浮窗）。 */
  onOpenEditPage: () => void = () => {};
  onRead: () => void = () => {};
  onOpenCatalog: () => void = () => {};
  /** 打开换源面板（P8）；在线书与本地书都可换源。 */
  onOpenChangeSource: () => void = () => {};
  onOpenReadRecords: () => void = () => {};
  /** 本书阅读记录面板的数据由 Index 组装，详情页不直接 import 仓储。 */
  onLoadBookReadRecord: (book: Book) => Promise<BookReadRecordPanel> =
    async (_book: Book): Promise<BookReadRecordPanel> => {
      const empty: BookReadRecordPanel = { totalLabel: '0秒', days: [] };
      return empty;
    };
  /** 切禁用标记；Index 写库后刷新 books 与 selectedBook，@Prop book 随之更新。 */
  onToggleDisableReadRecord: (book: Book, disabled: boolean) => void = (_book: Book, _disabled: boolean) => {};
  /** deleteSource 为真时才清应用内导入副本；用户原始文件从不删。 */
  onRemoveFromShelf: (deleteSource: boolean) => void = (_deleteSource: boolean) => {};
  /** 置顶（:284）；Index 写 order 与 durChapterTime。 */
  onTopBook: () => void = () => {};
  /** 刷新书籍信息（:280）；返回是否真的换过目录，提示文案在 Index 侧给出。 */
  onRefreshBookInfo: (book: Book) => Promise<boolean> =
    async (_book: Book): Promise<boolean> => false;
  /** 翻转「删除前先确认」（:291）。 */
  onToggleDeleteAlert: () => void = () => {};
  /** 头部书名/作者点击后带关键词进搜索页（:296 `:297`）。 */
  onSearchKeyword: (keyword: string) => void = (_keyword: string) => {};
  /** 单本私密标记（:294）；Index 落库后刷新 books 与 selectedBook。 */
  onSetPrivate: (book: Book, isPrivate: boolean) => void = (_book: Book, _isPrivate: boolean) => {};
  onChooseCover: () => void = () => {};
  onRestoreCover: () => void = () => {};
  onSaveMetadata: (title: string, author: string, category: string, description: string,
    remark: string, customTag: string, groupNames: string[], bookType: BookMediaType, fixedType: boolean) => Promise<boolean> = async (_title: string, _author: string,
    _category: string, _description: string, _remark: string, _customTag: string, _groupNames: string[],
    _bookType: BookMediaType, _fixedType: boolean): Promise<boolean> => false;
  onUnavailableAction: (message: string) => void = (_message: string) => {};
  /** 批10（:565）：导出本书为 EPUB；落盘与保存对话框在 Index 侧（那边有 EpubExporter）。 */
  onExportEpub: () => void = () => {};
  /** 打开书源登录页（:283）：页面不做路由，只把书源 URL 交给 Index。 */
  onOpenSourceLogin: (sourceUrl: string) => void = (_sourceUrl: string) => {};
  /** 打开书源编辑页去改源变量（:285）：变量面板在书源编辑页里，详情页跳过去。 */
  onOpenSourceEdit: (sourceUrl: string) => void = (_sourceUrl: string) => {};
  /** 切换「允许更新」（:289）：Index 写库后刷新 books，@Prop book 随之更新。 */
  onToggleCanUpdate: (canUpdate: boolean) => void = (_canUpdate: boolean) => {};
  /**
   * 批9（:1004）：切换「拆分超长章节」。翻开关本身在这里不写库，
   * 落盘与重算目录都在 Index 侧（只有那边拿得到 refreshBookInfo 那条现成路径）。
   */
  onToggleSplitLongChapter: () => void = () => {};
  /**
   * 批8（:369）：书架里与本书同名且作者兼容的书，由 Index 的 `shelfConflictsWith` 算好传入
   * （对齐上游 `FindBookshelfConflictUseCase.kt:18-48`：空白归一 + 作者兼容 + 已下架不算冲突）。
   * 为空时回退到本页 `sameNameCopies()` 的按书名比对，保证老调用点行为不变。
   */
  @Prop shelfConflictCandidates: Book[] = [];
  /** 批8（:369）：点「放入书架」。清 notShelf 位、按 min-1 排序落库都在 Index 侧。 */
  onAddToShelf: () => void = () => {};
  /** 批8（:369）：冲突面板两个方向，mode = 'coexist' | 'migrate'（对齐上游同名 use case）。 */
  onResolveShelfConflict: (existingId: string, mode: string) => void =
    (_existingId: string, _mode: string) => {};
  /**
   * 批8（:1154）：长按书架卡直接进分组选择（上游 `ShelfDeleteSheet.kt` 文件头注释：
   * 「长按书架卡片直接进入分组选择，保持在详情页常态长按」）。
   * 分组落库复用书架页那条通道 `BookshelfPage.onSetBooksGroup → Index.setBooksGroupByKeys`。
   */
  onSetBooksGroup: (bookKeys: string[], groupName: string) => void =
    (_bookKeys: string[], _groupName: string) => {};
  /** 批8（:369）：刚点过「放入书架」，等书变成在架后播两段引导（上游 awaitingShelfAddition）。 */
  @State awaitingShelfAddition: boolean = false;
  @State showShelfRemoveHint: boolean = false;
  @State showLongPressGroupHint: boolean = false;
  /** 批8（:369）：同名冲突面板（共存 / 迁移）。 */
  @State conflictSheetVisible: boolean = false;
  /** 批8（:1154）：长按书架卡弹出的分组选择面板。 */
  @State groupSheetVisible: boolean = false;
  @State fileSizeLabel: string = '';
  @State collapsedHeader: boolean = false;
  @State backdropOpacity: number = 0;
  /** 从封面提取出的主色，空串表示尚未取到或取色失败。 */
  @State coverSeedColor: string = '';
  /** 本书阅读记录面板显隐与数据，照 F12 自绘全屏遮罩范式。 */
  @State readRecordPanelVisible: boolean = false;
  @State readRecordPanel: BookReadRecordPanel = { totalLabel: '0秒', days: [] };
  /** 书名是否展开（:296 长按菜单里的「展开/收起」）。 */
  @State titleExpanded: boolean = false;
  /** 命中高亮规则的标签块，aboutToAppear 算一次。 */
  @State highlightedTags: HighlightedTag[] = [];
  /** 溢出菜单显隐。挂 `bindPopup`，`onStateChange` 会回写这里。 */
  @State overflowVisible: boolean = false;
  /** 移出书架面板（:337）。 */
  @State deleteSheetVisible: boolean = false;
  /** 面板里「同时删除应用内副本」的勾选；每次打开都复位成未勾（:339）。 */
  @State deleteSourceChecked: boolean = false;
  /** 封面长按看大图（:301）。 */
  @State photoPreviewVisible: boolean = false;
  /** 溢出菜单「日志」打开的日志面板（上游 `BookInfoMenuAction.ShowLog` → `AppLogSheet`）。 */
  @State logSheetVisible: boolean = false;
  /** 日志面板的行，打开时从 AppLog 内存缓冲取一次。 */
  @State logEntries: string[] = [];
  private infoScroller: Scroller = new Scroller();

  aboutToAppear(): void {
    this.loadFileSize();
    this.loadCoverSeedColor();
    this.refreshHighlightedTags();
  }

  /**
   * 这本书是否已在书架。上游按 bookUrl 查库判在架（BookInfoViewModel.kt:358-362），
   * 本地用 BookRepository.isSameBook（在线书按 contentPath=bookUrl，本地书按文件路径）。
   * 不能按派生 id 判：在线书 URL 多以「/」结尾，id 取末段成空串，会大面积误判在架。
   */
  private inBookshelf(): boolean {
    return this.books.some((item: Book) => BookRepository.isSameBook(item, this.book));
  }

  /**
   * 冲突态：不在架、但书架里有同名书。对齐上游 `BookInfoScreen.kt:1423`
   * `conflictHighlight = !inBookshelf && hasShelfDuplicates`。
   * 批8（:369）：候选优先用 Index 传进来的 `shelfConflictCandidates`（带作者兼容判断），
   * 没有传时回退到本页按书名比对的老口径。
   */
  private shelfConflictHighlight(): boolean {
    return !this.inBookshelf() && this.conflictCandidates().length > 0;
  }

  /** 批8（:369）：同名副本候选，Index 传了就用它，没传就按书名比对。 */
  private conflictCandidates(): Book[] {
    if (this.shelfConflictCandidates.length > 0) { return this.shelfConflictCandidates; }
    return this.sameNameCopies();
  }

  /**
   * 书架卡文案，对齐上游 `BookInfoScreen.kt:1424-1430` 的五态顺序。
   *
   * 上游前两态（「点击删除」/「长按分组」）由 `LaunchedEffect(inBookshelf)` 在
   * 「刚加入书架」后的第 1 秒 / 第 2 秒各显示一次。批8（:369）本地补上了从详情页
   * 「放入书架」这条路，那两态现在真的到得了：`awaitingShelfAddition` 置位后等
   * `@Prop book` 变成在架，`onBookPropChanged` 里按 1000ms + 1000ms 播两段。
   */
  private shelfActionLabel(): string {
    if (this.showShelfRemoveHint) { return '点击删除'; }
    if (this.showLongPressGroupHint) { return '长按分组'; }
    if (this.inBookshelf()) { return '已在书架'; }
    if (this.shelfConflictHighlight()) { return '疑似重复'; }
    return '放入书架';
  }

  /**
   * 批8（:369）：`@Prop book` 整体替换后同步引导态（上游 `LaunchedEffect(inBookshelf)`）。
   * 加入成功时播「点击删除」1 秒 →「长按分组」1 秒；书不在架时三个状态全清。
   *
   * 用 book.notShelf 判「是否已入架」而不是 inBookshelf()：@Watch 由 book prop 触发时，
   * 同一批次的 books prop 可能尚未同步到本页，inBookshelf() 会读到旧 books 误判为「不在架」，
   * 从而把 awaitingShelfAddition 清掉、两段引导永远播不出来。notShelf 位是随 book 一起下发的，
   * 加入成功后由 true 变 false，正是「刚从详情页放入书架」的可靠信号。
   */
  private onBookPropChanged(): void {
    const nowOnShelf = this.book.notShelf !== true;
    if (this.awaitingShelfAddition && nowOnShelf) {
      this.awaitingShelfAddition = false;
      this.showShelfRemoveHint = true;
      setTimeout(() => {
        this.showShelfRemoveHint = false;
        this.showLongPressGroupHint = true;
        setTimeout(() => {
          this.showLongPressGroupHint = false;
        }, 1000);
      }, 1000);
      return;
    }
    if (!nowOnShelf) {
      this.awaitingShelfAddition = false;
      this.showShelfRemoveHint = false;
      this.showLongPressGroupHint = false;
    }
  }

  /**
   * 书架卡点击：在架时走移出面板（:337）；不在架时——有同名副本先弹冲突面板（共存/迁移），
   * 没有就直接「放入书架」（对齐上游 `BookInfoViewModel.onShelfCardClick` 的分支顺序）。
   */
  private onShelfCardClick(): void {
    if (this.inBookshelf()) {
      this.requestRemoveFromShelf();
      return;
    }
    if (this.conflictCandidates().length > 0) {
      this.conflictSheetVisible = true;
      return;
    }
    this.awaitingShelfAddition = true;
    this.onAddToShelf();
  }

  /** 批8（:369）：冲突面板点「共存」或「迁移」，交给 Index 落库后关面板。 */
  private applyShelfConflictChoice(existingId: string, mode: string): void {
    this.conflictSheetVisible = false;
    this.awaitingShelfAddition = true;
    this.onResolveShelfConflict(existingId, mode);
  }

  /**
   * 匹配源就是标签行的同一份数据（上游 `BookInfoViewModel.kt:1306-1308`：
   * 先 `getDisplayTagList()` 再 `parseHighlightedTags`），所以两边必须同源，
   * 否则会出现「标签行里还在、高亮区也有一份」的重复显示。
   */
  private refreshHighlightedTags(): void {
    this.highlightedTags = matchHighlightTags(this.allKindLabels(), this.highlightTagRules);
  }

  /**
   * 背景样式。对齐上游 `BookInfoScreen.kt:863-875`：使用默认封面时读默认封面那档，
   * 否则读网络封面那档；本地没有内置默认封面图，`usesDefaultCover` 恒为 false。
   */
  private backdropStyle(): BookInfoBackdropStyle {
    return resolveBookInfoBackdropStyleFor(false, this.defaultCoverBackground, this.networkCoverBackground);
  }

  /**
   * 取封面主色。
   *
   * 对齐上游 `BookInfoScreen.kt:807-847 rememberBookInfoColorTheme` 的三个前置：
   * 有封面、`showCover` 为真、`followCoverColor` 为真；任一不满足就不取色（返回空串）。
   */
  private loadCoverSeedColor(): void {
    this.coverSeedColor = '';
    const coverUri = this.book.coverUri;
    if (coverUri === undefined || coverUri.length === 0) { return; }
    if (!this.backdropStyle().showCover || !this.followCoverColor) { return; }
    ImageSeedColorExtractor.extract(coverUri).then((color: string) => {
      this.coverSeedColor = color;
    }).catch(() => {
      this.coverSeedColor = '';
    });
  }

  /** 取色叠层的颜色：主色半透明，对齐上游 `seedOverlay.copy(alpha = 0.34f)`。 */
  private seedOverlayColor(): string {
    const base: string = this.seedOverlayBaseColor();
    if (base.length === 0) { return ''; }
    return `#57${base.substring(1)}`;
  }

  /**
   * seed 叠层与渐变档共用的基色。
   *
   * 上游 `BookInfoScreen.kt:950-954` 是 `lerp(secondaryContainer, seedColor, 0.42f)` ——
   * 封面主色要先和主题的 secondaryContainer 按 0.42 插值，才拿去铺叠层与渐变。
   * 本地 `ThemePalette` 没有 secondaryContainer（`data/ThemePalette.ets:31-44` 只有 10 个字段），
   * 降级用 `themeColorSurfaceElevated`（= surfaceContainerHigh）顶替，其余算法照上游。
   */
  private seedOverlayBaseColor(): string {
    if (this.coverSeedColor.length < 7) { return ''; }
    return BookInfoPage.lerpHexColor(this.themeColorSurfaceElevated, this.coverSeedColor, 0.42);
  }

  /** 两个 `#RRGGBB` 按 t 线性插值，返回 `#RRGGBB`。上游对应 Compose 的 `lerp(Color, Color, Float)`。 */
  private static lerpHexColor(from: string, to: string, t: number): string {
    if (from.length < 7 || to.length < 7) { return to; }
    const clamp: (value: number) => number = (value: number) =>
      Math.max(0, Math.min(255, Math.round(value)));
    const mix: (offset: number) => number = (offset: number) =>
      clamp(parseInt(from.substring(offset, offset + 2), 16) * (1 - t)
        + parseInt(to.substring(offset, offset + 2), 16) * t);
    const hex: (value: number) => string = (value: number) =>
      value.toString(16).padStart(2, '0').toUpperCase();
    return `#${hex(mix(1))}${hex(mix(3))}${hex(mix(5))}`;
  }

  /**
   * 渐变层里某一档的主色。有 seed 就换成对应 alpha 的 8 位色，没有就返回全透明
   * —— 对齐上游 `seedOverlay.copy(alpha = 0.10f / 0.18f)` 在无 seed 时取 Transparent。
   */
  private seedGradientColor(alpha: number): string {
    const base: string = this.seedOverlayBaseColor();
    if (base.length === 0) { return '#00000000'; }
    const byte: number = Math.max(0, Math.min(255, Math.round(alpha * 255)));
    const hex: string = byte.toString(16).padStart(2, '0').toUpperCase();
    return `#${hex}${base.substring(1)}`;
  }

  /**
   * 渐变 0.40 那一档。上游写法是 `seedOverlay.copy(alpha = 0.18f)`，
   * 但注释写明了无 seed 时改取 `surface.copy(alpha = 0.35f)` —— 没有这一档，
   * 背景会从纯透明直接跳到 85% 底色，头部到内容之间就是一道硬边。
   */
  private midGradientColor(): string {
    return this.seedOverlayBaseColor().length > 0 ? this.seedGradientColor(0.18) : this.surfaceAlphaColor(0.35);
  }

  /**
   * 头部渐变的中档色，上游 `BookInfoScreen.kt:1195-1200`：
   * `applySeedOverlay` 为真取 `lerp(surface, seedColor, 0.08f).copy(alpha = 0.5f)`，
   * 否则取 `surface.copy(alpha = 0.5f)`。
   */
  private headerMidGradientColor(): string {
    const base: string = this.pageBaseColor();
    // 自定义背景图模式下 pageBaseColor() 是全透明，插值会算出黑色，这里直接给透明。
    if (base.length !== 7) { return '#00000000'; }
    if (this.backdropStyle().applySeedOverlay && this.coverSeedColor.length >= 7) {
      return this.withAlpha(BookInfoPage.lerpHexColor(base, this.coverSeedColor, 0.08), 0.5);
    }
    return this.withAlpha(base, 0.5);
  }

  /** 给 `#RRGGBB` 拼一个 8 位 alpha 前缀。 */
  private withAlpha(color: string, alpha: number): string {
    if (color.length < 7) { return color; }
    const byte: number = Math.max(0, Math.min(255, Math.round(alpha * 255)));
    const hex: string = byte.toString(16).padStart(2, '0').toUpperCase();
    return `#${hex}${color.substring(color.length - 6)}`;
  }

  /** 页面底色：跟随背景图与纯黑主题，正文卡片之外的那一层就用这个色。 */
  /**
   * 批7（:1164）：简介里 `<button>名称@onclick:脚本</button>` 的点击。
   *
   * 本轮只把通道打通并记账：真执行脚本要书源上下文（引擎 runRawScript），
   * 而本地在线书进详情页的通路还没接（见 :1161），所以这里不假装执行成功。
   */
  private handleIntroButtonClick(name: string, click: string): void {
    AppLog.put(`简介按钮：name=${name} click=${click}`);
    if (click.length === 0) {
      this.onUnavailableAction(`${name}：这个按钮没有绑定脚本`);
      return;
    }
    if (this.bookSourceUrl.length === 0) {
      this.onUnavailableAction('该动作需要书源上下文，当前书籍没有');
      return;
    }
    this.onUnavailableAction(`${name}：已收到脚本 ${click}，书源脚本执行尚未接入`);
  }

  /** 批7（:1165）：简介里的图片单击。上游 `IntroImageClick(click)` 带的是脚本或地址。 */
  private handleIntroImageClick(click: string): void {
    AppLog.put(`简介图片：click=${click}`);
    this.onUnavailableAction(click.startsWith('http') ? `查看图片：${click}` : '简介图片已点击，动作未接入');
  }

  /** 批7（:1165）：简介里的图片长按。上游 `IntroImageLongClick(source)` 只给图片地址。 */
  private handleIntroImageLongClick(source: string): void {
    AppLog.put(`简介图片长按：source=${source}`);
    this.onUnavailableAction('简介图片长按已收到，动作未接入');
  }

  private pageBaseColor(): string {
    if (this.themeAppBackground.length > 0) { return '#00000000'; }
    return this.themePureBlack ? '#000000' : this.themeColorSurfacePrimary;
  }

  /** 页面底色加自定义 alpha，对齐上游 `surface.copy(alpha = 0.85f)`。 */
  private surfaceAlphaColor(alpha: number): string {
    const byte: number = Math.max(0, Math.min(255, Math.round(alpha * 255)));
    const hex: string = byte.toString(16).padStart(2, '0').toUpperCase();
    const base: string = this.pageBaseColor();
    return `#${hex}${base.substring(base.length - 6)}`;
  }

  private loadFileSize(): void {
    // 上游 `BookExtensions.kt:361-365` 取的是**源文件**大小（`FileDoc.fromFile(bookUrl).size`），
    // 本地 bookUrl 是转出来的正文副本，副本大小与源文件差得远（EPUB 尤其）。
    // 所以优先用导入时记下的 `sourceSize`，没有（老记录）才退回副本大小。
    if (this.book.sourceSize !== undefined && this.book.sourceSize > 0) {
      this.fileSizeLabel = this.formatFileSize(this.book.sourceSize);
      return;
    }
    if (this.book.contentPath === undefined) { return; }
    try {
      this.fileSizeLabel = this.formatFileSize(fileIo.statSync(this.book.contentPath).size);
    } catch (_) {
      this.fileSizeLabel = '';
    }
  }

  /**
   * 上游 `ConvertExtensions.kt:87-94 formatFileSize()` 的口径：
   * 单位表 `b / kb / M / G / T`，指数按 log10 计算，数值走 `DecimalFormat("#.##")`
   * （最多两位小数、不补零）。本地原来写的是 `1024 / 1.1 KB / 1.10 MB` 三档、
   * 大单位固定两位小数，与上游的 `5.23 M`、`3133 b` 这类输出不一致。
   */
  private formatFileSize(bytes: number): string {
    if (bytes <= 0) { return '0'; }
    const units: string[] = ['b', 'kb', 'M', 'G', 'T'];
    let digitGroups = Math.floor(Math.log10(bytes) / Math.log10(1024));
    digitGroups = Math.max(0, Math.min(units.length - 1, digitGroups));
    const scaled = bytes / Math.pow(1024, digitGroups);
    // 对应 DecimalFormat("#.##")：四舍五入到两位小数，去掉末尾多余的 0。
    const rounded = Math.round(scaled * 100) / 100;
    const text = Number.isInteger(rounded) ? `${rounded}` : `${rounded}`.replace(/0+$/, '');
    return `${text} ${units[digitGroups] ?? 'b'}`;
  }

  private getFormatLabel(): string {
    if (this.book.format === 'epub') { return 'EPUB'; }
    if (this.book.format === 'txt') { return 'TXT'; }
    if (this.book.format === 'pdf') { return 'PDF'; }
    if (this.book.format === 'mobi') { return 'MOBI'; }
    if (this.book.format === 'umd') { return 'UMD'; }
    // 原来这里 `return this.book.category`，与标签行里单独渲染的 category 撞成重复项，
    // 空 category 时还会漏出一个空标签。上游 `getBookTypeName()` 认不出类型时返回
    // 「未知书籍」，但那是要参与判断的字面量（upKind 会跳过它），不能直接显示。
    return '';
  }

  /**
   * 上游 `BookExtensions.kt:114-127 getBookTypeName()` 的口径。
   *
   * 本地只有本地书，前五个格式分支之外补 audio / image 两档（`Book.bookType`）。
   * 认不出时返回空串，调用方据此跳过 —— 上游那里是「未知书籍」，但 upKind 明确
   * 只在 `typeName != "未知书籍"` 时才插入，语义等价。
   */
  private getBookTypeName(): string {
    const format = this.getFormatLabel();
    if (format.length > 0) { return format; }
    if (this.book.bookType === 'audio') { return '有声书'; }
    if (this.book.bookType === 'image') { return '漫画'; }
    return '';
  }

  private getCustomTags(): string[] {
    return (this.book.customTag ?? '').split(/[\n,，]/)
      .map((tag: string) => tag.trim()).filter((tag: string) => tag.length > 0);
  }

  /**
   * 标签行的内容，对齐上游 `BookExtensions.kt:343-379 upKind()` +
   * `:149-150 getDisplayTagList()`。
   *
   * 上游先把 `book.kind` 洗一遍（剔掉纯大小串与纯字数串、本地书在第 0 位插格式名、
   * 末尾补文件大小与字数），再取 `(customTagList + sourceTagList).distinct()`。
   * 本地 `book.kind` 的对应物是 `book.category`，`sourceTagList` 同理。
   *
   * 高亮命中的标签由 `refreshHighlightedTags()` 抽走，这里返回剩下的普通标签。
   */
  private regularKindLabels(): string[] {
    const all: string[] = this.allKindLabels();
    const highlighted: string[] = [];
    this.highlightedTags.forEach((item: HighlightedTag) => {
      item.matchedLabels.forEach((label: string) => highlighted.push(label));
    });
    return all.filter((label: string) => !highlighted.includes(label));
  }

  /** 洗过之后的完整标签数组（含高亮命中项），供高亮匹配与标签行共用。 */
  private allKindLabels(): string[] {
    // 上游两条正则：纯文件大小串、以「字」结尾的纯字数串。
    const fileSizePattern: RegExp = /^\d[\d,.]*\s*(b|kb|mb|gb|tb|k|m|g|t)$/i;
    const wordCountPattern: RegExp = /^.*?\d.*字$/;
    const kinds: string[] = (this.book.category ?? '').split(/[\n,，]/)
      .map((item: string) => item.trim())
      .filter((item: string) => item.length > 0
        && !fileSizePattern.test(item) && !wordCountPattern.test(item));
    // 本地书：在第 0 位插格式名（上游 `kinds.add(0, typeName)`）。
    if (this.book.isLocal) {
      const typeName = this.getBookTypeName();
      if (typeName.length > 0 && !kinds.includes(typeName)) { kinds.unshift(typeName); }
      // 再补文件大小。
      if (this.fileSizeLabel.length > 0) { kinds.push(this.fileSizeLabel); }
    }
    // 末尾补字数。
    const wordCount = (this.book.wordCount ?? '').trim();
    if (wordCount.length > 0) { kinds.push(wordCount); }
    // 再接用户自定义标签，最后整体去重（上游 `(getCustomTagList() + getSourceTagList()).distinct()`）。
    return Array.from(new Set(kinds.concat(this.getCustomTags())));
  }

  /**
   * 分组名那一格，对齐上游 `BookInfoScreen.kt:1363-1372` 的 `group_s`（`%s`）。
   *
   * 上游是 `bookGroupRepository.getGroupNames(book.group).joinToString(",")`，
   * 本地 `book.groupNames` 就是同源的名称集合；为空时不渲染这一格。
   */
  private groupNameLabel(): string {
    const names = this.book.groupNames ?? [];
    if (names.length > 0) { return names.join(','); }
    const legacy = (this.book.groupName ?? '').trim();
    return legacy.length > 0 ? legacy : '';
  }

  /** 第三行左段：状态。本地没有书源，这段永远不点击（:298）。 */
  private statusLabel(): string {
    if (BookRepository.isBodyMissing(this.book)) { return 'Android 备份 · 正文缺失'; }
    return this.book.isLocal ? '本地书籍' : '书籍详情';
  }

  /**
   * 来源行文案，对齐上游 `origin_show`（`BookInfoScreen.kt:1334-1339`，只有 `book.originName`）。
   *
   * 本地 `books.originName` 列在 `BookRepository.toBookArgs` 里写的是
   * `book.androidOriginalPath ?? getFileName(bookUrl)`（`data/BookRepository.ets:1562`），
   * 但 `readBookRow` 没有把它读回 `Book`，所以这里按同一口径现算：
   * 有 Android 原始路径就用它，否则取正文文件名（含扩展名，和上游一致）。
   * 两者都空时按上游 `origin_show` 语义返回空串，整行不渲染。
   */
  private originNameLabel(): string {
    // 上游 `Book.originName` 就是导入时的源文件名（`LocalBook.kt:268-278`）。
    // 本地优先用导入时记下的 `originFileName`；老记录没有这个字段时再退回
    // Android 迁移留下的原始路径 / 正文副本文件名。
    const importedName = this.book.originFileName ?? '';
    if (importedName.length > 0) { return importedName; }
    const original = this.book.androidOriginalPath ?? '';
    if (original.length > 0) { return original; }
    const bookUrl = this.book.contentPath ?? '';
    return bookUrl.length > 0 ? BookRepository.getFileName(bookUrl) : '';
  }

  /**
   * 第三行右段：来源。
   *
   * 上游 `originName` 是书源名。批10（:553）起三档：本地书固定「本地文件」→ 有书源名就用书源名
   * （Index 注入的 `bookSourceName`，对齐上游 `Book.originName`）→ 都没才退 `androidOriginalPath`。
   */
  private sourceLabel(): string {
    if (this.book.isLocal) { return '本地文件'; }
    if (this.bookSourceName.length > 0) { return this.bookSourceName; }
    const path = this.book.androidOriginalPath ?? '';
    return path.length > 0 ? path : '未知来源';
  }

  /**
   * 点来源：上游进书源详情页，本地没有书源体系。
   *
   * 本地书按上游口径直接 return（点击没有任何反应）；非本地缺正文记录则把
   * 记录的原始路径提示出来，不假装能打开书源编辑页。
   */
  private onOriginClick(): void {
    if (this.book.isLocal) { return; }
    this.onUnavailableAction(`来源：${this.sourceLabel()}`);
  }

  /** 摘要已读状态三分支（:313）。顺序与上游一致：未读 → 已读完 → 已读 N 章。 */
  private readStateLabel(): string {
    const chapterIndex = this.book.chapterIndex ?? 0;
    const chapterPosition = this.book.chapterProgress ?? 0;
    if (chapterIndex === 0 && chapterPosition <= 0) { return '未读'; }
    const total = this.getChapterTotal();
    if (total > 0 && chapterIndex + 1 >= total) { return '已读完'; }
    return `已读 ${chapterIndex + 1} 章`;
  }

  /** 同名副本（:338）。上游按书名+作者判冲突，本地书目没有稳定的 bookUrl 分组，按书名比对。 */
  private sameNameCopies(): Book[] {
    return this.books.filter((item: Book) =>
      !BookRepository.isSameBook(item, this.book) && item.title === this.book.title);
  }

  /** 传给 Index 定位书的稳定键：在线书用 contentPath(=bookUrl)，本地书用文件路径，兜底才用 id。 */
  private bookKey(book: Book): string {
    return book.contentPath ?? book.androidOriginalPath ?? book.id;
  }

  /**
   * 打开移出书架面板（:337）。关掉「删除前先确认」时直接移出，不弹面板（:291）。
   * 勾选框每次打开都从未勾选起步（:339）。
   */
  private requestRemoveFromShelf(): void {
    if (!this.deleteAlertEnabled) {
      this.onRemoveFromShelf(true);
      return;
    }
    this.deleteSourceChecked = false;
    this.deleteSheetVisible = true;
  }

  /** 封面长按看大图（:301）。两个路径都空时不打开，给提示。 */
  private openPhotoPreview(): void {
    const uri = this.book.customCoverUri ?? this.book.coverUri ?? '';
    if (uri.length === 0) {
      this.onUnavailableAction('这本书没有封面');
      return;
    }
    this.photoPreviewVisible = true;
  }

  /** 书名点击：带书名进搜索页（:296）。 */
  private searchByTitle(): void {
    if (this.book.title.length === 0) { return; }
    this.onSearchKeyword(this.book.title);
  }

  /** 作者点击：带作者进搜索页；作者为空时给提示，不静默（:297）。 */
  private searchByAuthor(): void {
    const author = this.book.author.trim();
    if (author.length === 0) {
      this.onUnavailableAction('作者未知，无法搜索作者');
      return;
    }
    this.onSearchKeyword(author);
  }

  private getChapterTotal(): number {
    // chapterTitles 已随迁移删除：章节数一律取 books 行的 totalChapterNum。
    const savedCount = Number(this.book.chapterCount ?? '0');
    return savedCount > 0 ? savedCount : 0;
  }

  private getReadChapterNumber(): number {
    if (this.book.progress <= 0 && (this.book.chapterProgress ?? 0) <= 0) { return 0; }
    return (this.book.chapterIndex ?? 0) + 1;
  }

  /** 动作卡「阅读记录」：先取数再显示自绘面板，避免异步期间闪空态。 */
  private async openReadRecordPanel(): Promise<void> {
    this.readRecordPanel = await this.onLoadBookReadRecord(this.book);
    this.readRecordPanelVisible = true;
  }

  /**
   * 自绘移出书架面板（:337），替代原来的系统确认框。
   *
   * 与上游 `ShelfDeleteSheet.kt` 的差异：上游勾选叫「删除源文件」，本地能删的只有
   * `BookRepository.discardImportedCopy` 清掉的 `book.contentPath`（应用内副本），
   * 用户选的原始文件应用无权删除，所以文案写「应用内副本」。
   */
  @Builder
  private DeleteSheet() {
    Column() {
      Text('移出书架？').fontSize(TITLE_LARGE).fontWeight(FontWeight.Medium).fontColor('#ECEEF2')
        .width('100%').margin({ bottom: 8 })
      Text(BookRepository.isBodyMissing(this.book)
        ? '移出后只删除这条缺正文书目记录；Android 兼容归档和原始文件不会更改。'
        : '移出后会清理应用内的导入副本，原始文件会保留。')
        .fontSize(TITLE_SMALL).lineHeight(TITLE_SMALL_LINE_HEIGHT).fontColor('#AEB0BA').width('100%')
      if (this.conflictCandidates().length > 0) {
        Text(this.conflictCandidates().length === 1
          ? `书架里还有 1 本同名书：${this.book.title}`
          : `书架里还有 ${this.conflictCandidates().length} 本同名书：${this.book.title}`)
          .fontSize(LABEL_MEDIUM).fontColor(this.themeColorTextTertiary).width('100%').margin({ top: 12 })
      }
      if (this.book.isLocal) {
        Row() {
          Toggle({ type: ToggleType.Checkbox, isOn: this.deleteSourceChecked })
            .onChange((value: boolean) => this.deleteSourceChecked = value)
          Text('同时删除应用内副本').fontSize(TITLE_SMALL).fontColor('#D0D2DB').margin({ left: 8 })
        }.width('100%').margin({ top: 12 })
      }
      Row() {
        Text('取消').fontSize(LABEL_LARGE).fontColor('#C5C7D0').textAlign(TextAlign.Center)
          .layoutWeight(1).padding({ top: 12, bottom: 12 }).backgroundColor('#2A2B33').borderRadius(14)
          .onClick(() => this.deleteSheetVisible = false)
        Text('移出书架').fontSize(LABEL_LARGE).fontColor('#101116').textAlign(TextAlign.Center)
          .layoutWeight(1).padding({ top: 12, bottom: 12 }).backgroundColor('#B9C6FF').borderRadius(14)
          .margin({ left: 10 }).onClick(() => {
            this.deleteSheetVisible = false;
            this.onRemoveFromShelf(this.deleteSourceChecked);
          })
      }.width('100%').margin({ top: 20 })
    }.width('100%').padding({ left: 20, right: 20, top: 8, bottom: 24 })
  }

  /**
   * 批8（:369）：同名冲突面板（共存 / 迁移）。
   *
   * 语义照上游 `ResolveBookshelfConflictUseCase.kt` 的文件头注释：
   * - 共存：两个副本都留架，阅读会话按各自 bookUrl 记账，**只搬元信息、不搬阅读记录**；
   * - 迁移：等价换源，旧书删除、阅读会话整体平移（平移不是累加）。
   * 落库在 Index（`resolveShelfConflictCoexist` / `resolveShelfConflictMigrate`），这里只做选择。
   */
  @Builder
  private ConflictSheet() {
    Column() {
      Text('发现同名书').fontSize(TITLE_LARGE).fontWeight(FontWeight.Medium).fontColor('#ECEEF2')
        .width('100%').margin({ bottom: 8 })
      Text(`书架里已有 ${this.conflictCandidates().length} 本同名书：${this.book.title}`)
        .fontSize(TITLE_SMALL).lineHeight(TITLE_SMALL_LINE_HEIGHT).fontColor('#AEB0BA').width('100%')
      Text('共存＝两本都留在书架，只同步封面等元信息，阅读进度互不影响；'
        + '迁移＝用当前书源替换原书，原书的阅读进度整体搬到新书。')
        .fontSize(LABEL_MEDIUM).lineHeight(TITLE_SMALL_LINE_HEIGHT)
        .fontColor(this.themeColorTextTertiary).width('100%').margin({ top: 8 })
      ForEach(this.conflictCandidates(), (item: Book) => {
        Column() {
          Text(item.title).fontSize(TITLE_SMALL).fontColor('#ECEEF2').width('100%')
          Text(`${item.author.length > 0 ? item.author : '作者未知'} · ${item.originName ?? '本地'} · `
            + `已读 ${(item.chapterIndex ?? 0) + 1} 章`)
            .fontSize(LABEL_MEDIUM).fontColor('#AEB0BA').width('100%').margin({ top: 2 })
          Row() {
            Text('共存').fontSize(LABEL_LARGE).fontColor('#D0D2DB').textAlign(TextAlign.Center)
              .layoutWeight(1).padding({ top: 10, bottom: 10 }).backgroundColor('#2A2B33').borderRadius(12)
              .onClick(() => this.applyShelfConflictChoice(this.bookKey(item), 'coexist'))
            Text('迁移进度').fontSize(LABEL_LARGE).fontColor('#101116').textAlign(TextAlign.Center)
              .layoutWeight(1).padding({ top: 10, bottom: 10 }).backgroundColor('#B9C6FF').borderRadius(12)
              .margin({ left: 10 }).onClick(() => this.applyShelfConflictChoice(this.bookKey(item), 'migrate'))
          }.width('100%').margin({ top: 8 })
        }.width('100%').padding(12).borderRadius(14).backgroundColor('#1B1C24')
          .margin({ top: 10 })
      }, (item: Book) => item.id)
      Text('取消').fontSize(LABEL_LARGE).fontColor('#C5C7D0').textAlign(TextAlign.Center)
        .width('100%').padding({ top: 12, bottom: 12 }).backgroundColor('#2A2B33').borderRadius(14)
        .margin({ top: 16 }).onClick(() => this.conflictSheetVisible = false)
    }.width('100%').padding({ left: 20, right: 20, top: 8, bottom: 24 })
  }

  /**
   * 批8（:1154）：长按书架卡进入的分组选择面板。
   * 列出全部可见分组 + 「不分组」；点一项即把这本书（bookKeys = [book.id]）挪过去，
   * 走的是书架页同一个落库通道 `Index.setBooksGroupByKeys`。
   */
  @Builder
  private GroupSheet() {
    Column() {
      Text('选择分组').fontSize(TITLE_LARGE).fontWeight(FontWeight.Medium).fontColor('#ECEEF2')
        .width('100%').margin({ bottom: 4 })
      Text(`把「${this.book.title}」移动到：`).fontSize(LABEL_MEDIUM).fontColor(this.themeColorTextTertiary)
        .width('100%').margin({ bottom: 8 })
      List() {
        ForEach(this.groups.filter((group: BookGroup) => group.show), (group: BookGroup) => {
          ListItem() {
            Text(group.groupName.length > 0 ? group.groupName : '未命名分组')
              .fontSize(TITLE_SMALL).fontColor('#ECEEF2').width('100%')
              .padding({ left: 12, right: 12, top: 12, bottom: 12 })
              .backgroundColor('#1B1C24').borderRadius(12).margin({ bottom: 8 })
              .onClick(() => {
                this.groupSheetVisible = false;
                this.onSetBooksGroup([this.book.id], group.groupName);
              })
          }
        }, (group: BookGroup) => String(group.groupId))
        ListItem() {
          // 空分组名 = 移出分组（BookRepository.setBooksGroup 的口径）。
          Text('不分组').fontSize(TITLE_SMALL).fontColor('#C5C7D0').width('100%')
            .padding({ left: 12, right: 12, top: 12, bottom: 12 })
            .backgroundColor('#14151B').borderRadius(12)
            .onClick(() => {
              this.groupSheetVisible = false;
              this.onSetBooksGroup([this.book.id], '');
            })
        }
      }.width('100%').height(this.groups.length > 5 ? 320 : 200).scrollBar(BarState.Off)
      Text('取消').fontSize(LABEL_LARGE).fontColor('#C5C7D0').textAlign(TextAlign.Center)
        .width('100%').padding({ top: 12, bottom: 12 }).backgroundColor('#2A2B33').borderRadius(14)
        .margin({ top: 12 }).onClick(() => this.groupSheetVisible = false)
    }.width('100%').padding({ left: 20, right: 20, top: 8, bottom: 24 })
  }

  /** 书名长按菜单（:296）：搜索书名 + 展开/收起。 */
  @Builder
  private TitleMenu() {
    Menu() {
      MenuItem({ content: '搜索书名' }).height(48).onClick(() => this.searchByTitle())
      MenuItem({ content: this.titleExpanded ? '收起' : '展开' }).height(48)
        .onClick(() => this.titleExpanded = !this.titleExpanded)
    }.backgroundColor('#17181E').fontColor('#F1F2F6').radius(20)
  }

  /** 封面全屏预览（:301）：点任意处关闭。 */
  @Builder
  private PhotoPreview() {
    Stack({ alignContent: Alignment.Center }) {
      Column().width('100%').height('100%').backgroundColor('#000000')
      Image(this.book.customCoverUri ?? this.book.coverUri ?? '')
        .objectFit(ImageFit.Contain).width('100%').height('100%')
      Column().width('100%').height('100%').backgroundColor('#01000000')
        .onClick(() => this.photoPreviewVisible = false)
    }.width('100%').height('100%').zIndex(1002)
  }

  /**
   * 溢出菜单的项。
   *
   * 顺序照上游 `BookInfoScreen.kt:1034-1143` 的 `BookInfoOverflowMenu`，19 项一项不落：
   * custom_button → edit → refresh → read_record → book_disable_read_record →
   * re_sync_webdav → upload_to_remote → login → set_source_variable → set_book_variable →
   * copy_book_url → copy_toc_url → to_top → allow_update → split_long_chapter →
   * delete_alert → clear_cache → log → private。
   *
   * **上游的显示条件在本地一律不判**：上游这些项各自挂着 `bookSourceUi != null`、
   * `hasLogin`、`isLocal == false` 之类的前置条件。本地书目以本地书为主，按条件判会大面积不显示；
   * 书源体系在批 8 之后已接入（`bookSource/` 目录、`openSourceLogin()` / `openSourceEdit()`
   * 都已接上），但在线书的这些前置条件仍不全具备。按用户要求「哪怕不做实际功能也要把所有按钮
   * 做出来」，这里全部列出，未接入的项在 `onOverflowSelect` 里提示「未接入」。
   */
  private overflowItems(): UiMenuItem[] {
    // 批10（:565）：导出 EPUB 仅对有正文的本地书出现。ArkTS 不允许在 spread 三元里写
    // 未声明类型的对象字面量（arkts-no-untyped-obj-literals / arkts-no-noninferrable-arr-literals），
    // 所以先显式声明成 UiMenuItem[] 再展开。
    const exportItems: UiMenuItem[] = [];
    if (this.book.isLocal && (this.book.contentPath ?? '').length > 0) {
      exportItems.push({ key: 'export_epub', title: '导出为 EPUB' });
    }
    const items: UiMenuItem[] = [
      { key: 'custom_button', title: '自定义按钮' },
      { key: 'edit', title: '编辑' },
      { key: 'refresh', title: '刷新' },
      { key: 'read_record', title: '阅读记录' },
      {
        key: 'book_disable_read_record',
        title: '独立关闭阅读记录',
        selected: this.book.disableReadRecord === true
      },
      { key: 're_sync_webdav', title: '重新同步远程书籍' },
      { key: 'upload_to_remote', title: '上传 WebDav' },
      { key: 'login', title: '登录' },
      { key: 'set_source_variable', title: '设置源变量' },
      { key: 'set_book_variable', title: '设置书籍变量' },
      { key: 'copy_book_url', title: '拷贝书籍 URL' },
      { key: 'copy_toc_url', title: '拷贝目录 URL' },
      ...exportItems,
      { key: 'to_top', title: '置顶' },
      // 允许更新：选中态对齐上游 isSelected = book.canUpdate（缺省视为 true）。
      { key: 'allow_update', title: '允许更新', selected: this.book.canUpdate !== false },
      // 拆分超长章节：勾选态对齐上游 `isSelected = book.splitLongChapter`（缺省 true），
      // 只在本地 TXT 上出现（上游 BookInfoScreen.kt:1115-1120 判 isLocal + text 类型）。
      {
        key: 'split_long_chapter',
        title: '拆分超长章节',
        selected: this.book.splitLongChapter !== false
      },
      { key: 'delete_alert', title: '删除提醒', selected: this.deleteAlertEnabled },
      { key: 'clear_cache', title: '清理缓存' },
      { key: 'log', title: '日志' },
      {
        key: 'private',
        title: this.book.isPrivate === true ? '取消私密标记' : '标记为私密',
        selected: this.book.isPrivate === true
      }
    ];
    return items;
  }

  /** 点溢出菜单某一项。关闭在回调里做，面板自己不关自己。 */
  private onOverflowSelect(key: string): void {
    this.overflowVisible = false;
    if (key === 'edit') {
      this.onOpenEditPage();
    } else if (key === 'refresh') {
      this.onRefreshBookInfo(this.book);
    } else if (key === 'read_record') {
      this.openReadRecordPanel();
    } else if (key === 'book_disable_read_record') {
      this.onToggleDisableReadRecord(this.book, !(this.book.disableReadRecord === true));
    } else if (key === 'copy_book_url') {
      this.copyBookUrl();
    } else if (key === 'copy_toc_url') {
      this.copyTocUrl();
    } else if (key === 'export_epub') {
      this.onExportEpub();
    } else if (key === 'login') {
      this.openSourceLogin();
    } else if (key === 'set_source_variable') {
      this.openSourceEdit();
    } else if (key === 'upload_to_remote') {
      this.uploadBook();
    } else if (key === 'allow_update') {
      this.onToggleCanUpdate(this.book.canUpdate === false);
    } else if (key === 'to_top') {
      this.onTopBook();
    } else if (key === 'split_long_chapter') {
      this.onToggleSplitLongChapter();
    } else if (key === 'delete_alert') {
      this.onToggleDeleteAlert();
    } else if (key === 'clear_cache') {
      this.clearBookCache();
    } else if (key === 'log') {
      this.openLogSheet();
    } else if (key === 'private') {
      this.onSetPrivate(this.book, this.book.isPrivate !== true);
    } else if (key === 'custom_button') {
      // 批10（:554）书源自定义按钮。上游 `BookSource.customButton` 只是个布尔开关，
      // 真正的执行链是 `customButtonRule`（选择器 + JS），本地移植的引擎
      // `third_party/harmony-book-source-engine/sourceengine/src/main/ets/model/data/Book.ts:355`
      // 只有 `customButton: boolean = false`，**没有 customButtonRule 字段**（全仓 grep 只此一处命中）。
      // 引擎不扩展就执行不了源脚本，这里如实说明缺什么，不弹假成功提示。
      this.onUnavailableAction('自定义按钮依赖书源引擎的 customButtonRule（选择器与脚本），本地引擎只移植了 customButton 开关，暂无法执行');
    } else {
      // 其余项按仓库约定仍然列出来，点了给一句「未接入」，不留死按钮。
      // 两项缺的东西完全不同，分别写清：
      //
      // re_sync_webdav —— 缺「远端书 → 本地书」的回写流程。
      //   上游 `ui/book/info/BookInfoViewModel.kt:790 syncFromRemote()` 只在 book.isLocal 时跑，
      //   调 `remoteBookRepository.syncBookFromRemote(book)` 把远端书拉回、删本地书、插回新书，
      //   不涉及脚本。本地 WebDAV 传输层已经齐：`lib/WebDav.ets:218 listFiles` / `:235 upload` /
      //   `:249 downloadTo` / `:264 delete`，上传书籍也跑通了（`lib/WebDavSync.ets:129 uploadBookFile`，
      //   入口本页 `uploadBook()`），备份与进度下载同样走这层。真正缺的是本地没有
      //   `RemoteBookRepository` 对应层、`model/Book.ets` 不记远端标识（上传只按
      //   `fileName = localPath.substring(...)` 复制，grep remoteUrl/webDavUrl 零命中），
      //   也没有把远端正文拉回后重新登记成书那段。
      //
      // set_book_variable —— 缺 `book.variable` 字段与书源上下文。
      //   上游 `BookInfoViewModel.kt:729 requestBookVariableSheet()` 开头就 `bookSource ?: throw`，
      //   编辑 `book.getCustomVariable()`（`data/entities/BaseBook.kt:30` → `Book.kt:130 variable`，
      //   JSON 键 custom），文案是「书籍变量可在 js 中通过 book.getVariable("custom") 获取」——
      //   设置并保存一份变量供书源脚本读取，不执行脚本；显示条件是 bookSourceUi != null。
      //   本地 `model/Book.ets` 无 variable 字段（grep 零命中），本地书也没有书源上下文；
      //   引擎侧有（`sourceengine/src/main/ets/model/data/Book.ts:37 variable`、`:58 variableMap`）
      //   但本地书模型没映射过来。
      this.onUnavailableAction(`${this.overflowTitleOf(key)} 未接入`);
    }
  }

  /** 按 key 反查菜单标题，给「未接入」提示用。 */
  private overflowTitleOf(key: string): string {
    const matched = this.overflowItems().find((item: UiMenuItem) => item.key === key);
    return matched === undefined ? key : matched.title;
  }

  /**
   * 拷贝书籍 URL（上游 `copy_book_url`）。
   *
   * 上游取 `book.bookUrl`；本地没有书源 URL，用 `androidOriginalPath`，
   * 再退到 `contentPath`。写剪贴板不需要 PasteButton 授权（读才需要）。
   */
  private copyBookUrl(): void {
    const url = (this.book.androidOriginalPath ?? '').length > 0
      ? (this.book.androidOriginalPath ?? '')
      : (this.book.contentPath ?? '');
    if (url.length === 0) {
      this.onUnavailableAction('这本书没有可拷贝的路径');
      return;
    }
    const data = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, url);
    pasteboard.getSystemPasteboard().setData(data).then(() => {
      this.onUnavailableAction('已拷贝书籍路径');
    }).catch(() => {
      this.onUnavailableAction('拷贝失败，剪贴板不可用');
    });
  }

  /**
   * 拷贝目录链接（:288），对齐上游 CopyText(book.tocUrl)。
   * 语义陷阱：本地书的第 9 列被借用成 tocRule（章节正则），readBookRow 里本地书
   * 的 tocUrl 恒为 undefined。所以本地书必须提示「没有目录链接」，绝不能退去复制 tocRule。
   */
  private copyTocUrl(): void {
    const url = this.book.tocUrl ?? '';
    if (url.length === 0) {
      this.onUnavailableAction('本地书籍没有目录链接');
      return;
    }
    const data = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, url);
    pasteboard.getSystemPasteboard().setData(data).then(() => {
      this.onUnavailableAction('已复制目录链接');
    }).catch(() => {
      this.onUnavailableAction('复制失败，剪贴板不可用');
    });
  }

  /**
   * 分享（:273 顶栏）：平台无 systemShare 面板（SDK api+kits 零命中，已核），
   * 走 Want 的 sendData；模拟器多半无响应方，失败则降级为复制书名与链接并明确提示。
   * 分享内容按上游口径：书名 + 作者 + 书链（在线书 bookUrl，本地书 contentPath）。
   */
  private shareBook(): void {
    const link = this.book.origin !== undefined && this.book.origin.length > 0 && this.book.origin !== 'loc_book'
      ? (this.book.tocUrl ?? this.book.origin ?? '')
      : (this.book.contentPath ?? '');
    const text = `${this.book.title} ${this.book.author} ${link}`.trim();
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext | undefined;
    if (context !== undefined) {
      const want: Want = {
        action: 'ohos.want.action.sendData',
        type: 'text/plain',
        parameters: { 'ability.params.stream': text, 'ohos.extra.param.key.content': text }
      };
      context.startAbility(want).then(() => {
        this.onUnavailableAction('已调起分享');
      }).catch(() => {
        this.copyShareFallback(text);
      });
      return;
    }
    this.copyShareFallback(text);
  }

  /** 分享降级：系统无分享面板时复制到剪贴板，并明确告知用户（不静默降级）。 */
  private copyShareFallback(text: string): void {
    const data = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, text);
    pasteboard.getSystemPasteboard().setData(data).then(() => {
      this.onUnavailableAction('已复制书名与链接');
    }).catch(() => {
      this.onUnavailableAction('分享失败，剪贴板不可用');
    });
  }

  /** 登录书源（:283）：本地书没有书源 URL，直接提示；否则把 URL 交给 Index 打开登录页。 */
  private openSourceLogin(): void {
    const sourceUrl = this.book.origin ?? '';
    if (sourceUrl.length === 0 || sourceUrl === 'loc_book') {
      this.onUnavailableAction('本地书籍没有书源，无法登录');
      return;
    }
    this.onOpenSourceLogin(sourceUrl);
  }

  /** 设置书源变量（:285）：变量面板在书源编辑页里，跳过去由用户点「变量」。 */
  private openSourceEdit(): void {
    const sourceUrl = this.book.origin ?? '';
    if (sourceUrl.length === 0 || sourceUrl === 'loc_book') {
      this.onUnavailableAction('本地书籍没有书源变量');
      return;
    }
    this.onOpenSourceEdit(sourceUrl);
  }

  /** 上传书籍（:278）：把唯一正文副本只读复制到 WebDAV，绝不删除或移动它。 */
  private uploadBook(): void {
    const localPath = this.book.contentPath ?? '';
    if (localPath.length === 0) {
      this.onUnavailableAction('本地书籍没有正文文件');
      return;
    }
    const fileName = localPath.substring(localPath.lastIndexOf('/') + 1);
    const context = this.getUIContext().getHostContext();
    if (context === undefined) {
      this.onUnavailableAction('上传失败，无法获取应用上下文');
      return;
    }
    WebDavSync.uploadBookFile(context, localPath, fileName).then(() => {
      AppLog.put(`[BookInfoPage] 已上传：${fileName}`);
      this.onUnavailableAction('已上传：' + fileName);
    }).catch((error: Error) => {
      this.onUnavailableAction('上传失败：' + error.message);
    });
  }

  /** 溢出菜单面板：批 1 的卡片式菜单，挂在「更多」按钮的 bindPopup 上。 */
  @Builder
  private OverflowMenuPopup() {
    UiMenuPanel({
      items: this.overflowItems(),
      panelWidth: OVERFLOW_MENU_WIDTH,
      onSelect: (key: string) => this.onOverflowSelect(key)
    })
  }

  /**
   * 溢出菜单「清理缓存」（上游 `BookInfoMenuAction.ClearCache`，`BookInfoScreen.kt:1126-1129`）。
   *
   * 上游清的是 `clearBookCacheUseCase` 管的缓存目录，不动 `bookUrl` 指向的书源正文。
   * 本地 `book.contentPath` 是导入时转出的**唯一正文副本**，删了这本书就读不了了
   * （那是「缓存管理」页 `confirmDeleteCache` 的语义，且有「恢复本地书」兜底），
   * 所以这里只清内存里的章节行与正文缓存，不碰磁盘副本。
   */
  private clearBookCache(): void {
    BookRepository.clearChapterCache();
    this.onUnavailableAction('已清理缓存');
  }

  /** 溢出菜单「日志」（上游 `BookInfoMenuAction.ShowLog` → `AppLogSheet`）。 */
  private openLogSheet(): void {
    this.logEntries = AppLog.getAll();
    this.logSheetVisible = true;
  }

  /** 日志面板：与书架页 `LogSheetContent` 同一形态，行取自 AppLog 内存缓冲。 */
  @Builder
  private LogSheet() {
    Column() {
      Row() {
        Text('日志').fontSize(TITLE_LARGE).fontWeight(FontWeight.Bold).fontColor(this.themeColorTextPrimary)
        Blank()
        Text('清空').fontSize(LABEL_MEDIUM).fontColor(this.themeColorAccent).padding(6)
          .onClick(() => { AppLog.clear(); this.logEntries = []; })
      }.width('100%').padding({ left: 16, right: 16, top: 18, bottom: 12 })
      if (this.logEntries.length === 0) {
        Column() {
          Text('暂无日志').fontSize(LABEL_MEDIUM).fontColor(this.themeColorTextTertiary)
        }.layoutWeight(1).width('100%').justifyContent(FlexAlign.Center)
      } else {
        List() {
          ForEach(this.logEntries, (line: string) => {
            ListItem() {
              Text(line).fontSize(LABEL_SMALL).fontColor(this.themeColorTextSecondary)
                .fontFamily('monospace').width('100%')
            }.padding({ left: 16, right: 16, top: 4, bottom: 4 })
          }, (line: string) => line)
        }.layoutWeight(1).width('100%').scrollBar(BarState.Off)
      }
    }.width('100%').height('100%').backgroundColor('#17181E')
  }

  build() {
    Column() {
      // 内容层 + FAB 层：FAB 浮在内容右下角（上游 floatingActionButton），不占布局高度。
      Stack({ alignContent: Alignment.BottomEnd }) {
      Stack({ alignContent: Alignment.TopStart }) {
      if (this.backdropStyle().showCover && this.book.coverUri !== undefined && this.book.coverUri.length > 0) {
        // 上游 BookInfoScreen.kt:965-989 的封面层不设 opacity，也不做淡入：整层靠 Crossfade
        // 换状态（书名/作者/封面/来源任一变化才重放），封面本身始终满不透明。
        // 本地原来挂 opacity 0→0.45 的 animateTo，等于把背景永远压掉一半，这里去掉。
        Image(this.book.coverUri).width('100%').height(480).objectFit(ImageFit.Cover)
          .blur(this.backdropStyle().blurCover ? 24 : 0)
      }
      if (this.backdropStyle().applySeedOverlay && this.seedOverlayColor().length > 0) {
        // 上游 :991-997 是 `Modifier.fillMaxSize()`：叠层铺满整屏，不是只盖住封面的 480。
        Column().width('100%').height('100%').backgroundColor(this.seedOverlayColor())
      }
      // 第三层：固定竖向渐变，上游 BookInfoBackdrop（BookInfoScreen.kt:927-1023）的
      // Brush.verticalGradient(colorStops = 0f 透明 / 0.20f seed 0.10 / 0.40f seed 0.18 /
      // 0.60f surface 0.85 / 0.80f surface / 1f surface)。本地原本缺这一层，所以背景
      // 从封面图直接切到页面底色，滚到底是一圈硬边界。
      Column()
        .width('100%')
        .height('100%')
        .linearGradient({
          angle: 180,
          colors: [
            ['#00000000', 0.0],
            [this.seedGradientColor(0.10), 0.20],
            [this.midGradientColor(), 0.40],
            [this.surfaceAlphaColor(0.85), 0.60],
            [this.pageBaseColor(), 0.80],
            [this.pageBaseColor(), 1.0]
          ]
        })
        .hitTestBehavior(HitTestMode.None)
      Scroll(this.infoScroller) {
        Column() {
          Stack() {
            Column() {
            // 顶栏占位：66 = 56（顶栏）+ 10（原视觉留白）。打开全屏布局后还要让出状态栏那一段。
            Blank().height(66 + this.appTopInset)

            Row() {
              // 封面：点击换封面、长按看大图（:301）。容器在调用处包，BookCover 内部加
              // onClick 会吞掉书架整卡的点击。
              Stack({ alignContent: Alignment.Center }) {
                BookCover({ book: this.book, displayWidth: 112, displayHeight: 157, coverSettings: this.coverSettings, applyAspectRatio: true })
              }
                // 长按与短按必须互斥：onClick 与 gesture 并存时长按会顺带触发点击，
                // 实测表现为长按打开换封面选择器。用 Exclusive 手势组，长按优先。
                .gesture(
                  GestureGroup(GestureMode.Exclusive,
                    LongPressGesture({ duration: 500 }).onAction(() => this.openPhotoPreview()),
                    TapGesture({ count: 1 }).onAction(() => this.onChooseCover())
                  )
                )
                .accessibilityText(`${this.book.title}，封面。点击更换封面，长按查看大图`)
              Column() {
                // 书名：点击进搜索、长按弹「搜索书名 / 展开收起」（:296）。
                Text(this.book.title).fontSize(HEADLINE_MEDIUM).fontWeight(FontWeight.Bold).fontColor('#F1F2F6')
                  .maxLines(this.titleExpanded ? 20 : 3).textOverflow({ overflow: TextOverflow.Ellipsis })
                  .onClick(() => this.searchByTitle())
                  .bindContextMenu(this.TitleMenu, ResponseType.LongPress,
                    { placement: Placement.BottomLeft })
                // 作者：点击进作者搜索（:297）。上游长按走另一分支，本地不做长按。
                Text(this.book.author.length > 0 ? this.book.author : '作者未知')
                  .fontSize(BODY_LARGE).fontColor('#D0D2DB').margin({ top: 8 })
                  .onClick(() => this.searchByAuthor())
                // 来源行：上游 `BookInfoScreen.kt:1334-1339` 只有一行
                // `origin_show`（`%s` = book.originName），没有「本地书籍 / 本地文件」这种
                // 状态前缀。本地原来拆成 statusLabel + ' · ' + sourceLabel 两段，
                // 用户在详情页看到的是「本地书籍 · 本地文件」，与上游不符，这里只留名字。
                Text(this.originNameLabel()).fontSize(LABEL_LARGE).fontColor('#9FA6C8')
                  .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
                  .margin({ top: 8 })
                  .onClick(() => this.onOriginClick())
                // 高亮标签行（:299）：在作者/来源行之后、普通标签行之前。
                if (this.highlightedTags.length > 0) {
                  Row() {
                    ForEach(this.highlightedTags, (item: HighlightedTag, index: number) => {
                      if (index > 0) {
                        Divider().vertical(true).height(18).strokeWidth(0.5).color('#6A6D77')
                          .margin({ left: 6, right: 6 })
                      }
                      Column() {
                        Text(item.title).fontSize(BODY_SMALL).fontColor('#E8C56B').maxLines(1)
                          .textOverflow({ overflow: TextOverflow.Ellipsis })
                        Text(item.matchedLabels.join('、')).fontSize(LABEL_SMALL).fontColor('#A99258')
                          .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
                      }.layoutWeight(1).alignItems(HorizontalAlign.Start)
                    }, (item: HighlightedTag, index: number) => `${index}-${item.title}`)
                  }.width('100%').margin({ top: 8 })
                }
              }.layoutWeight(1).alignItems(HorizontalAlign.Start).margin({ left: 16 })
            }.width('100%').alignItems(VerticalAlign.Center).padding({ left: 18, right: 18, bottom: 18 })

            // 标签行拆两路，对齐上游 `BookInfoScreen.kt:1354-1385`：
            // 左边一个分组名（`groupNames` 单串），右边是 kindLabels 的横向列表。
            // 本地原来把 category / groupNames / 格式名 / 大小 / 自定义标签五路混在一个
            // Row 里，`getFormatLabel()` 的 else 又回落到 category，于是同一个词出现两次，
            // 中间夹着一个空标签 —— 就是用户看到的「中间一个空白很小的像标签」。
            if ((this.groupNameLabel().length > 0 || this.regularKindLabels().length > 0)) {
              Scroll() {
                Row() {
                  if (this.groupNameLabel().length > 0) {
                    BookInfoTag({ label: this.groupNameLabel() })
                  }
                  ForEach(this.regularKindLabels(), (tag: string) => {
                    BookInfoTag({ label: tag })
                  }, (tag: string) => tag)
                }
              }
              .scrollable(ScrollDirection.Horizontal)
              .scrollBar(BarState.Off)
              // Scroll 的内容默认居中（书架分组栏也踩过同一条），这里必须显式左对齐，
              // 否则两三个标签会飘到整行中间，与上游 LazyRow 的左起排布不一致。
              .align(Alignment.Start)
              .width('100%').padding({ left: 18, right: 18, bottom: 20 })
            }
            // 头部自己的竖向渐变，上游 `BookInfoScreen.kt:1188-1206`：
            // Transparent → lerp(surface, seedColor, 0.08).copy(0.5) → surface，
            // 没有 seed 时中档退成 surface.copy(0.5)。原来这块注释写「头部不设自己的底色」，
            // 那是漏实现：没有这层，头部文字直接压在封面图上，滚到内容区又是一刀切。
            }.width('100%')
              .linearGradient({
                angle: 180,
                colors: [
                  ['#00000000', 0.0],
                  [this.headerMidGradientColor(), 0.5],
                  [this.pageBaseColor(), 1.0]
                ]
              })
          }.width('100%')

          Column() {

          // 上游 BookInfoActions（BookInfoScreen.kt:1391-1493）只有 4 张卡：
          // 书架 / 查看目录 / 换源 / 阅读记录。「禁用阅读记录」在上游只存在于溢出菜单里。
          // 容器底色、内边距与 8dp 间距照 `:1436-1442`：Row 铺 surface 底、横向 16 纵向 8。
          Row({ space: 8 }) {
            BookInfoAction({
              // 图标三态照 `:1445-1449`：冲突 → Shuffle、在架 → Outlined.Book、其余 → BookmarkAdd。
              // 本地没有 BookmarkAdd 资源，未在架那档用已有的 bookmark 图标，语义同为「收藏」。
              icon: this.shelfConflictHighlight() ? 'shuffle'
                : (this.inBookshelf() ? 'book' : 'bookmark'),
              label: this.shelfActionLabel(),
              highlight: this.shelfConflictHighlight(),
              onSelect: () => this.onShelfCardClick(),
              // 批8（:1154）：长按从「进编辑页」改成「弹分组选择」；编辑页入口仍在顶栏
              // `TopBarButton({ icon: 'edit' ... })`，功能不丢。不在架的书没有分组，长按无效。
              onLongPress: () => {
                if (this.inBookshelf()) { this.groupSheetVisible = true; }
              }
            })
            BookInfoAction({ icon: 'list', label: '查看目录', onSelect: () => this.onOpenCatalog() })
            BookInfoAction({ icon: 'swap', label: '换源', onSelect: () => this.onOpenChangeSource() })
            BookInfoAction({ icon: 'profileTimeline', label: '阅读记录', onSelect: () => this.openReadRecordPanel() })
          }.width('100%')
            .padding({ left: 16, right: 16, top: 8, bottom: 8 })
            .backgroundColor(this.themeColorSurfacePrimary)

          Column() {
            Text(this.book.progress > 0 ? `在读 · ${this.book.lastChapter}` : '尚未开始阅读')
              .fontSize(TITLE_LARGE).fontWeight(FontWeight.Bold).fontColor(this.themeColorTextPrimary)
            // 第二行是「最新章节」，不是「当前阅读章」：上游接的是 latestChapterTitle。
            Text(`最新 · ${this.book.latestChapterTitle ?? ''}`)
              .fontSize(TITLE_MEDIUM).fontColor(this.themeColorTextSecondary).margin({ top: 4 })
            Row() {
              Text(this.getChapterTotal() > 0 ? `共 ${this.getChapterTotal()} 章` : '章节总数待读取')
                .fontSize(TITLE_SMALL).fontColor(this.themeColorAccent)
              Text('  |  ').fontSize(TITLE_SMALL).fontColor(this.themeColorTextTertiary)
              Text(this.readStateLabel())
                .fontSize(TITLE_SMALL).fontColor(this.themeColorTextSecondary)
            }.margin({ top: 4 })
          }.width('100%').alignItems(HorizontalAlign.Start)
            // 上游 `BookInfoSummary`（BookInfoScreen.kt:1544-1550）是
            // `fillMaxWidth().background(surface).padding(start 16, end 16, top 8, bottom 16)`，
            // 铺满整宽、无圆角、无外边距。本地原来做成圆角 18 的独立卡片并带左右 16 外边距，
            // 往下滚时它就变成一张浮在正文上的卡片 —— 与上游的一整片底色不是一回事。
            .padding({ left: 16, right: 16, top: 8, bottom: 16 })

          if (BookRepository.isBodyMissing(this.book)) {
            Column() {
              Text('已恢复书目与阅读位置，缺少正文文件')
                .fontSize(BODY_LARGE).fontWeight(FontWeight.Medium).fontColor('#F0B2A8')
              Text('Android 备份只保存书架记录和阅读位置，不包含 TXT / EPUB 正文。重新选择原书文件后才能继续阅读。')
                .fontSize(TITLE_SMALL).lineHeight(TITLE_SMALL_LINE_HEIGHT).fontColor(this.themeColorTextSecondary).margin({ top: 8 })
              if ((this.book.androidOriginalPath ?? '').length > 0) {
                Text(`Android 原路径：${this.book.androidOriginalPath ?? ''}`)
                  .fontSize(BODY_SMALL).lineHeight(BODY_SMALL_LINE_HEIGHT).fontColor(this.themeColorTextTertiary).margin({ top: 8 })
              }
            }.width('100%').alignItems(HorizontalAlign.Start).padding(16)
              .backgroundColor('#2A1D20').borderRadius(16).margin({ left: 16, right: 16, bottom: 14 })
          }

          Column() {
            // 上游 `BookInfoScreen.kt:1533-1720 BookInfoSummary` 的简介区没有小标题、
            // 没有卡片底色，正文直接接在摘要下面，`bodyMedium` 也不设 maxLines。
            // 本地原来是一张「小说简介」标题 + 圆角 18 卡片，这一层去掉。
            //
            // 批7（:1156/:1157/:1158/:1164/:1165）：三个富文本前缀由 RichIntro 分派 ——
            // `<usehtml>` 与 `<useweb>` 走 Web（后者带同源拦截），`<md>` 走 MarkdownIntro，
            // 无前缀仍是这一处原来的 Text，字号行高颜色一个字没改。
            if (this.book.description !== undefined && this.book.description.trim().length > 0) {
              RichIntro({
                intro: this.book.description,
                baseUrl: this.bookBaseUrl,
                textColor: '#D0D2DB',
                webNotice: '简介页面含外部跳转，已拦截',
                onButtonClick: (name: string, click: string) => { this.handleIntroButtonClick(name, click); },
                onImageClick: (click: string) => { this.handleIntroImageClick(click); },
                onImageLongClick: (source: string) => { this.handleIntroImageLongClick(source); }
              })
            } else {
              // 上游 `R.string.intro_show_null` = 「简介：暂无简介」。
              Text('简介：暂无简介').fontSize(TITLE_SMALL).lineHeight(TITLE_SMALL_LINE_HEIGHT).fontColor('#BFC1CB')
                .alignSelf(ItemAlign.Start)
            }
            if ((this.book.remark ?? '').trim().length > 0) {
              // 备注卡可点：整块进元数据面板（:315），不单给正文加点击区。
              Column() {
                Text('备注').fontSize(TITLE_SMALL).fontWeight(FontWeight.Medium).fontColor(this.themeColorTextPrimary)
                  .alignSelf(ItemAlign.Start).margin({ top: 12 })
                Text(this.book.remark ?? '').fontSize(TITLE_SMALL).lineHeight(TITLE_SMALL_LINE_HEIGHT).fontColor('#BFC1CB')
                  .alignSelf(ItemAlign.Start).margin({ top: 4 })
              }.width('100%').onClick(() => this.onOpenEditPage())
            }
          }.width('100%').alignItems(HorizontalAlign.Start)
            .padding({ left: 16, right: 16, top: 8, bottom: 24 })
          // 头部以下铺一整片页面底色。上游 `BookInfoScreen.kt:419-427` 这一层是
          // `fillMaxWidth().background(surface).padding(bottom = 24.dp)`：动作卡、摘要、
          // 简介全部落在这一片不透明底色上，背景图只透在头部那一段。
          // 本地原来整列不铺底色，往下滚时封面图/渐变会从正文后面透出来，
          // 摘要那张圆角卡又浮在上面 —— 就是「下滑之后成这样了」的观感来源。
          }.width('100%').backgroundColor(this.pageBaseColor())
        }.width('100%').padding({ bottom: CONTENT_BOTTOM_INSET })
      }.edgeEffect(EdgeEffect.Spring, { alwaysEnabled: false }).width('100%').height('100%').scrollBar(BarState.Off).onScroll(() => {
        const shouldCollapse = Math.abs(this.infoScroller.currentOffset().yOffset) > 70;
        if (this.collapsedHeader !== shouldCollapse) { this.collapsedHeader = shouldCollapse; }
      })

      // 顶栏：上游 BookInfoTransparentTopAppBar（BookInfoScreen.kt:738-805）在顶部时完全透明，
      // 滚动后才是 scrolledContainerColor。三个动作按 BookInfoTopBarActions 的顺序：
      // 编辑（inBookshelf 才有）→ 分享 → 更多。
      Row() {
        TopBarBackButton({ onSelect: () => this.onBack() })
        Blank()
        Row({ space: topBarActionSpacing(this.themeTopBarButtonStyle) }) {
          TopBarButton({ icon: 'edit', onSelect: () => this.onOpenEditPage() })
          TopBarButton({ icon: 'share', onSelect: () => this.shareBook() })
          // menuMode: true 让 TopBarButton 不注册自己的 onSelect（否则内层点击会被它吃掉）；
          // bindPopup 要求宿主节点可点击，所以这里补一个只翻转显隐的 onClick。
          TopBarButton({ icon: 'more', menuMode: true })
            .onClick(() => { this.overflowVisible = !this.overflowVisible; })
            .bindPopup(this.overflowVisible, {
              builder: this.OverflowMenuPopup,
              placement: Placement.BottomRight,
              popupColor: '#00000000',
              enableArrow: false,
              autoCancel: true,
              width: OVERFLOW_MENU_WIDTH,
              onStateChange: (event: PopupStateChangeParam) => {
                this.overflowVisible = event.isVisible;
              }
            })
        }
        .height(topBarButtonSize(this.themeTopBarButtonStyle))
        .borderRadius(topBarButtonSize(this.themeTopBarButtonStyle) / 2)
      }.width('100%').height(64 + this.appTopInset)
        .padding({ left: TOP_BAR_SIDE_PADDING, right: TOP_BAR_ACTIONS_END, top: this.appTopInset })
        // 滚动后铺的是 `scrolledContainerColor` = surfaceContainer（本地 themeColorSurfaceElevated）。
        // 原来用的是 themeColorSurfacePrimary，与页面底色同值，看起来等于「没底色」。
        .backgroundColor(this.collapsedHeader ? this.themeColorSurfaceElevated : '#00000000')
        .animation({ duration: DURATION_FADE, curve: Curve.EaseInOut })
      }.width('100%').height('100%').backgroundColor(bookCoverColor(this.book))

      // 阅读按钮：上游是 ExtendedFloatingActionButton，浮在内容右下角，不是常驻底栏。
      if (this.readRecordPanelVisible === false) {
        Row() {
          AppGlyph({
            name: 'book',
            glyphSize: 17,
            tint: this.themePureBlack ? '#101114' : this.themeColorSurfacePrimary
          })
          Text(BookRepository.isBodyMissing(this.book) ? '缺少正文' : '阅读')
            .fontSize(TITLE_SMALL).fontWeight(FontWeight.Medium).margin({ left: 7 })
            .fontColor(this.themePureBlack ? '#101114' : this.themeColorSurfacePrimary)
        }
        .height(READ_FAB_HEIGHT)
        .padding({ left: 16, right: 20 })
        .borderRadius(16)
        .backgroundColor(this.themeColorAccent)
        .shadow({ radius: 12, color: '#33000000', offsetY: 4 })
        .margin({ right: 16, bottom: 16 })
        .onClick(() => this.onRead())
      }
      }.width('100%').layoutWeight(1)

      if (this.readRecordPanelVisible) {
        Stack({ alignContent: Alignment.Center }) {
          Column().width('100%').height('100%').backgroundColor('#99000000')
            .onClick(() => this.readRecordPanelVisible = false)
          Column() {
            Row() {
              Text('阅读记录').fontSize(TITLE_LARGE).fontWeight(FontWeight.Medium).fontColor('#ECEEF2').layoutWeight(1)
              Text('关闭').fontSize(LABEL_LARGE).fontColor('#C5C7D0').padding(8)
                .onClick(() => this.readRecordPanelVisible = false)
            }.width('100%').padding({ bottom: 12 })
            Column() {
              Text('累计阅读').fontSize(LABEL_MEDIUM).fontColor(this.themeColorTextSecondary)
              Text(this.readRecordPanel.totalLabel).fontSize(HEADLINE_LARGE).fontWeight(FontWeight.Bold)
                .fontColor(this.themeColorAccent).margin({ top: 6 })
            }.width('100%').padding(16).backgroundColor('#292A31').borderRadius(14)
              .alignItems(HorizontalAlign.Start)
            if (this.readRecordPanel.days.length === 0) {
              Text('暂无阅读记录').fontSize(TITLE_SMALL).fontColor('#AEB0BA')
                .width('100%').textAlign(TextAlign.Center).margin({ top: 28, bottom: 28 })
            } else {
              Scroll() {
                Column() {
                  ForEach(this.readRecordPanel.days, (day: BookReadRecordDay) => {
                    Column() {
                      Text(day.dateLabel).fontSize(TITLE_SMALL).fontWeight(600)
                        .fontColor(this.themeColorTextPrimary).alignSelf(ItemAlign.Start)
                        .margin({ top: 14, bottom: 8 })
                      ForEach(day.sessions, (session: BookReadRecordSession, sessionIndex: number) => {
                        Stack({ alignContent: Alignment.TopStart }) {
                          Column().width(2).height(48).backgroundColor('#3A3C46').margin({ left: 11 })
                          Column().width(8).height(8).borderRadius(4)
                            .backgroundColor(this.themeColorAccent).margin({ left: 8, top: 8 })
                          Column() {
                            Text(`${session.timeLabel} · ${session.durationLabel}`).fontSize(TITLE_SMALL)
                              .fontColor(this.themeColorTextPrimary)
                            if (session.chapterLabel.length > 0) {
                              Text(session.chapterLabel).fontSize(BODY_SMALL)
                                .fontColor(this.themeColorTextTertiary).margin({ top: 4 })
                            }
                          }.width('100%').alignItems(HorizontalAlign.Start)
                            .padding({ left: 28, top: 6, bottom: 10 })
                        }.width('100%')
                      }, (session: BookReadRecordSession, sessionIndex: number) =>
                        `${day.dateLabel}-${sessionIndex}-${session.timeLabel}-${session.durationLabel}`)
                    }.width('100%').alignItems(HorizontalAlign.Start)
                  }, (day: BookReadRecordDay, dayIndex: number) => `${dayIndex}-${day.dateLabel}`)
                }.width('100%')
              }.edgeEffect(EdgeEffect.None).layoutWeight(1).scrollBar(BarState.Off)
            }
            Text('查看全部').fontSize(LABEL_LARGE).fontColor('#B9C6FF').textAlign(TextAlign.Center)
              .width('100%').padding({ top: 14, bottom: 4 })
              .onClick(() => {
                this.readRecordPanelVisible = false;
                this.onOpenReadRecords();
              })
          }.width('90%').height('72%').padding(18)
            .backgroundColor(this.themeColorSurfaceSecondary).borderRadius(22)
            .onClick(() => {})
        }.width('100%').height('100%').zIndex(1001)
      }
      if (this.photoPreviewVisible) {
        this.PhotoPreview()
      }
    }.width('100%').height('100%').backgroundColor(this.themeAppBackground.length > 0 ? Color.Transparent : (this.themePureBlack ? '#000000' : this.themeColorSurfacePrimary))
      // 移出书架确认面板、日志面板与批8 的同名冲突面板共用这一个 bindSheet：
      // 同一节点挂两个 bindSheet 只有最后一个生效（书架页 :2118 踩过同一个坑），
      // 所以用一个合并条件 + 内容分支，不用两个独立 sheet。
      .bindSheet(this.deleteSheetVisible || this.logSheetVisible || this.conflictSheetVisible
        || this.groupSheetVisible, this.InfoSheetContent(), {
        height: this.logSheetVisible ? SheetSize.LARGE : SheetSize.FIT_CONTENT,
        dragBar: true,
        showClose: false,
        backgroundColor: '#17181E',
        onDisappear: () => {
          if (this.deleteSheetVisible) {
            this.deleteSheetVisible = false;
            // 每次打开都从未勾选起步（:339）。
            this.deleteSourceChecked = false;
          }
          this.conflictSheetVisible = false;
          this.groupSheetVisible = false;
          this.logSheetVisible = false;
        }
      })
  }

  /** 详情页 sheet 内容：日志优先，其余落回移出书架确认面板。 */
  @Builder
  InfoSheetContent() {
    if (this.logSheetVisible) {
      this.LogSheet()
    } else if (this.conflictSheetVisible) {
      this.ConflictSheet()
    } else if (this.groupSheetVisible) {
      this.GroupSheet()
    } else {
      this.DeleteSheet()
    }
  }
}

@Component
struct BookTypeChoice {
  @StorageProp('themeColorSurfaceElevated') themeColorSurfaceElevated: string = '#FFFFFF';
  @Prop label: string = '';
  @Prop selected: boolean = false;
  onSelect: () => void = () => {};
  build() {
    Text(this.label).fontSize(LABEL_MEDIUM).fontColor(this.selected ? '#F1F2F6' : '#C5C7D0')
      .textAlign(TextAlign.Center).layoutWeight(1).padding({ top: 9, bottom: 9 })
      .backgroundColor(this.selected ? '#46476B' : this.themeColorSurfaceElevated).borderRadius(10)
      .margin({ right: 6 }).onClick(() => this.onSelect())
  }
}

@Component
struct BookInfoTag {
  @StorageProp('themeColorTextSecondary') themeColorTextSecondary: string = '#2E3038';
  @Prop label: string = '';
  build() {
    Text(this.label).fontSize(LABEL_MEDIUM).fontColor(this.themeColorTextSecondary)
      .padding({ left: 10, right: 10, top: 6, bottom: 6 })
      .backgroundColor('#171820').borderRadius(14).margin({ right: 8 })
  }
}

@Component
struct BookInfoAction {
  @StorageProp('themeColorTextSecondary') themeColorTextSecondary: string = '#2E3038';
  @StorageProp('themeColorTextPrimary') themeColorTextPrimary: string = '#1B1C22';
  @StorageProp('themeColorSurfaceElevated') themeColorSurfaceElevated: string = '#FFFFFF';
  @StorageProp('themeAppBackground') themeAppBackground: string = '';
  @StorageProp('themePureBlack') themePureBlack: boolean = false;
  @Prop icon: AppGlyphName = 'book';
  @Prop label: string = '';
  /** 冲突态：底色用 secondaryContainer 档（本地降级成 surfaceElevated）。 */
  @Prop highlight: boolean = false;
  onSelect: () => void = () => {};
  /** 上游 `BookInfoActionCard` 的 `onLongClick`，只书架卡绑（`:1462`）。 */
  onLongPress: () => void = () => {};
  build() {
    Column() {
      AppGlyph({
        name: this.icon,
        glyphSize: 20,
        tint: this.highlight ? this.themeColorTextPrimary : this.themeColorTextSecondary
      }).margin({ bottom: 4 })
      // 上游 `:1495-1531` 文案是 bodySmall + maxLines 2，高度由内容决定，不是固定 72。
      Text(this.label)
        .fontSize(BODY_SMALL)
        .fontColor(this.highlight ? this.themeColorTextPrimary : this.themeColorTextSecondary)
        .maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
        .textAlign(TextAlign.Center)
    }.layoutWeight(1).constraintSize({ minHeight: 72 }).justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center).padding({ left: 8, right: 8, top: 12, bottom: 12 })
      .backgroundColor(this.themeAppBackground.length > 0
        ? Color.Transparent
        : (this.themePureBlack ? '#121212' : this.themeColorSurfaceElevated))
      .borderRadius(16)
      .onClick(() => this.onSelect())
      .gesture(LongPressGesture({ duration: 500 }).onAction(() => this.onLongPress()))
  }
}
