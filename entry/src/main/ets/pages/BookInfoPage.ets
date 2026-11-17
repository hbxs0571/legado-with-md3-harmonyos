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
import {
  TopBarButton, TopBarBackButton, topBarButtonSize, topBarActionSpacing,
  TOP_BAR_SIDE_PADDING, TOP_BAR_ACTIONS_END
} from '../components/TopBar';
import { UiMenuItem, UiMenuPanel } from '../components/UiMenu';
import { AppLog } from '../lib/AppLog';

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
  @Prop book: Book = {
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
  /** 移出书架前是否二次确认（批 7 的 `:291`）。 */
  @Prop deleteAlertEnabled: boolean = true;
  onBack: () => void = () => {};
  /** 打开书籍信息编辑页（批 5 的独立整页，不是浮窗）。 */
  onOpenEditPage: () => void = () => {};
  onRead: () => void = () => {};
  onOpenCatalog: () => void = () => {};
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

  /** 这本书是否已在书架。本地 `books` 就是书架全量，按 id 判即可。 */
  private inBookshelf(): boolean {
    return this.books.some((item: Book) => item.id === this.book.id);
  }

  /**
   * 冲突态：不在架、但书架里有同名书。对齐上游 `BookInfoScreen.kt:1423`
   * `conflictHighlight = !inBookshelf && hasShelfDuplicates`。
   */
  private shelfConflictHighlight(): boolean {
    return !this.inBookshelf() && this.sameNameCopies().length > 0;
  }

  /**
   * 书架卡文案，对齐上游 `BookInfoScreen.kt:1424-1430` 的五态顺序。
   *
   * 上游前两态（「点击删除」/「长按分组」）由 `LaunchedEffect(inBookshelf)` 在
   * 「刚加入书架」后的 1 秒 / 2 秒各显示一次。本地没有「从详情页把书挂回书架」这条
   * 路径（加入书架只发生在导入时，`Book.isNotShelf` 这一列本地也不存在），那两态
   * 永远到不了，所以这里不摆一个空转的定时器，只保留可达的三态。
   * 没做的那两态写进收尾的「未做到」，不假装实现。
   */
  private shelfActionLabel(): string {
    if (this.inBookshelf()) { return '已在书架'; }
    if (this.shelfConflictHighlight()) { return '疑似重复'; }
    return '放入书架';
  }

  /** 书架卡点击：在架时走移出面板；不在架时给出可达的导入入口提示。 */
  private onShelfCardClick(): void {
    if (!this.inBookshelf()) {
      this.onUnavailableAction('请通过「添加本地」导入这本书加入书架');
      return;
    }
    this.requestRemoveFromShelf();
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
   * 上游 `originName` 是书源名；本地没有书源，只能落到 `androidOriginalPath`
   * （Android 迁移过来的原始路径），再退一步给「本地文件」。
   */
  private sourceLabel(): string {
    if (this.book.isLocal) { return '本地文件'; }
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
      item.id !== this.book.id && item.title === this.book.title);
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
      Text('移出书架？').fontSize(18).fontWeight(FontWeight.Medium).fontColor('#ECEEF2')
        .width('100%').margin({ bottom: 8 })
      Text(BookRepository.isBodyMissing(this.book)
        ? '移出后只删除这条缺正文书目记录；Android 兼容归档和原始文件不会更改。'
        : '移出后会清理应用内的导入副本，原始文件会保留。')
        .fontSize(14).lineHeight(21).fontColor('#AEB0BA').width('100%')
      if (this.sameNameCopies().length > 0) {
        Text(this.sameNameCopies().length === 1
          ? `书架里还有 1 本同名书：${this.book.title}`
          : `书架里还有 ${this.sameNameCopies().length} 本同名书：${this.book.title}`)
          .fontSize(13).fontColor(this.themeColorTextTertiary).width('100%').margin({ top: 12 })
      }
      if (this.book.isLocal) {
        Row() {
          Toggle({ type: ToggleType.Checkbox, isOn: this.deleteSourceChecked })
            .onChange((value: boolean) => this.deleteSourceChecked = value)
          Text('同时删除应用内副本').fontSize(14).fontColor('#D0D2DB').margin({ left: 8 })
        }.width('100%').margin({ top: 12 })
      }
      Row() {
        Text('取消').fontSize(15).fontColor('#C5C7D0').textAlign(TextAlign.Center)
          .layoutWeight(1).padding({ top: 12, bottom: 12 }).backgroundColor('#2A2B33').borderRadius(14)
          .onClick(() => this.deleteSheetVisible = false)
        Text('移出书架').fontSize(15).fontColor('#101116').textAlign(TextAlign.Center)
          .layoutWeight(1).padding({ top: 12, bottom: 12 }).backgroundColor('#B9C6FF').borderRadius(14)
          .margin({ left: 10 }).onClick(() => {
            this.deleteSheetVisible = false;
            this.onRemoveFromShelf(this.deleteSourceChecked);
          })
      }.width('100%').margin({ top: 20 })
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
   * `hasLogin`、`isLocal == false` 之类的前置条件，本地没有书源系统、书目全是本地书，
   * 照条件判等于全都不显示。按用户要求「哪怕不做实际功能也要把所有按钮做出来」，
   * 这里全部列出，未接入的项在 `onOverflowSelect` 里提示「未接入」。
   */
  private overflowItems(): UiMenuItem[] {
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
      { key: 'to_top', title: '置顶' },
      { key: 'allow_update', title: '允许更新' },
      { key: 'split_long_chapter', title: '拆分超长章节' },
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
    } else if (key === 'to_top') {
      this.onTopBook();
    } else if (key === 'delete_alert') {
      this.onToggleDeleteAlert();
    } else if (key === 'clear_cache') {
      this.clearBookCache();
    } else if (key === 'log') {
      this.openLogSheet();
    } else if (key === 'private') {
      this.onSetPrivate(this.book, this.book.isPrivate !== true);
    } else {
      // 其余 8 项（custom_button / re_sync_webdav / upload_to_remote / login /
      // set_source_variable / set_book_variable / copy_toc_url / allow_update /
      // split_long_chapter）依赖书源、远程书库或排版引擎，本地没有对应能力。
      // 按用户要求仍然列出来，点了给一句「未接入」，不留死按钮。
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
        Text('日志').fontSize(18).fontWeight(FontWeight.Bold).fontColor(this.themeColorTextPrimary)
        Blank()
        Text('清空').fontSize(13).fontColor(this.themeColorAccent).padding(6)
          .onClick(() => { AppLog.clear(); this.logEntries = []; })
      }.width('100%').padding({ left: 16, right: 16, top: 18, bottom: 12 })
      if (this.logEntries.length === 0) {
        Column() {
          Text('暂无日志').fontSize(13).fontColor(this.themeColorTextTertiary)
        }.layoutWeight(1).width('100%').justifyContent(FlexAlign.Center)
      } else {
        List() {
          ForEach(this.logEntries, (line: string) => {
            ListItem() {
              Text(line).fontSize(11).fontColor(this.themeColorTextSecondary)
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
                Text(this.book.title).fontSize(23).fontWeight(FontWeight.Bold).fontColor('#F1F2F6')
                  .maxLines(this.titleExpanded ? 20 : 3).textOverflow({ overflow: TextOverflow.Ellipsis })
                  .onClick(() => this.searchByTitle())
                  .bindContextMenu(this.TitleMenu, ResponseType.LongPress,
                    { placement: Placement.BottomLeft })
                // 作者：点击进作者搜索（:297）。上游长按走另一分支，本地不做长按。
                Text(this.book.author.length > 0 ? this.book.author : '作者未知')
                  .fontSize(17).fontColor('#D0D2DB').margin({ top: 8 })
                  .onClick(() => this.searchByAuthor())
                // 来源行：上游 `BookInfoScreen.kt:1334-1339` 只有一行
                // `origin_show`（`%s` = book.originName），没有「本地书籍 / 本地文件」这种
                // 状态前缀。本地原来拆成 statusLabel + ' · ' + sourceLabel 两段，
                // 用户在详情页看到的是「本地书籍 · 本地文件」，与上游不符，这里只留名字。
                Text(this.originNameLabel()).fontSize(14).fontColor('#9FA6C8')
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
                        Text(item.title).fontSize(12).fontColor('#E8C56B').maxLines(1)
                          .textOverflow({ overflow: TextOverflow.Ellipsis })
                        Text(item.matchedLabels.join('、')).fontSize(11).fontColor('#A99258')
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
              onLongPress: () => this.onOpenEditPage()
            })
            BookInfoAction({ icon: 'list', label: '查看目录', onSelect: () => this.onOpenCatalog() })
            BookInfoAction({ icon: 'swap', label: '换源', onSelect: () => this.onUnavailableAction('在线换源将在 P5 接入') })
            BookInfoAction({ icon: 'profileTimeline', label: '阅读记录', onSelect: () => this.openReadRecordPanel() })
          }.width('100%')
            .padding({ left: 16, right: 16, top: 8, bottom: 8 })
            .backgroundColor(this.themeColorSurfacePrimary)

          Column() {
            Text(this.book.progress > 0 ? `在读 · ${this.book.lastChapter}` : '尚未开始阅读')
              .fontSize(19).fontWeight(FontWeight.Bold).fontColor(this.themeColorTextPrimary)
            // 第二行是「最新章节」，不是「当前阅读章」：上游接的是 latestChapterTitle。
            Text(`最新 · ${this.book.latestChapterTitle ?? ''}`)
              .fontSize(16).fontColor(this.themeColorTextSecondary).margin({ top: 4 })
            Row() {
              Text(this.getChapterTotal() > 0 ? `共 ${this.getChapterTotal()} 章` : '章节总数待读取')
                .fontSize(14).fontColor(this.themeColorAccent)
              Text('  |  ').fontSize(14).fontColor(this.themeColorTextTertiary)
              Text(this.readStateLabel())
                .fontSize(14).fontColor(this.themeColorTextSecondary)
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
                .fontSize(17).fontWeight(FontWeight.Medium).fontColor('#F0B2A8')
              Text('Android 备份只保存书架记录和阅读位置，不包含 TXT / EPUB 正文。重新选择原书文件后才能继续阅读。')
                .fontSize(14).lineHeight(21).fontColor(this.themeColorTextSecondary).margin({ top: 8 })
              if ((this.book.androidOriginalPath ?? '').length > 0) {
                Text(`Android 原路径：${this.book.androidOriginalPath ?? ''}`)
                  .fontSize(12).lineHeight(18).fontColor(this.themeColorTextTertiary).margin({ top: 8 })
              }
            }.width('100%').alignItems(HorizontalAlign.Start).padding(16)
              .backgroundColor('#2A1D20').borderRadius(16).margin({ left: 16, right: 16, bottom: 14 })
          }

          Column() {
            // 上游 `BookInfoScreen.kt:1533-1720 BookInfoSummary` 的简介区没有小标题、
            // 没有卡片底色，正文直接接在摘要下面，`bodyMedium` 也不设 maxLines。
            // 本地原来是一张「小说简介」标题 + 圆角 18 卡片，这一层去掉。
            //
            // 上游三个富文本前缀 `<useweb>` / `<usehtml>` / `<md>` 本批未实现（需要
            // WebView / HTML / Markdown 三套渲染器），这里一律按纯文本显示，不做伪装。
            if (this.book.description !== undefined && this.book.description.trim().length > 0) {
              Text(this.book.description).fontSize(14).lineHeight(22).fontColor('#D0D2DB')
                .alignSelf(ItemAlign.Start)
            } else {
              // 上游 `R.string.intro_show_null` = 「简介：暂无简介」。
              Text('简介：暂无简介').fontSize(14).lineHeight(22).fontColor('#BFC1CB')
                .alignSelf(ItemAlign.Start)
            }
            if ((this.book.remark ?? '').trim().length > 0) {
              // 备注卡可点：整块进元数据面板（:315），不单给正文加点击区。
              Column() {
                Text('备注').fontSize(14).fontWeight(FontWeight.Medium).fontColor(this.themeColorTextPrimary)
                  .alignSelf(ItemAlign.Start).margin({ top: 12 })
                Text(this.book.remark ?? '').fontSize(14).lineHeight(22).fontColor('#BFC1CB')
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
          TopBarButton({ icon: 'share', onSelect: () => this.onUnavailableAction('书籍分享尚未迁移') })
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
        .animation({ duration: 220, curve: Curve.EaseInOut })
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
            .fontSize(14).fontWeight(FontWeight.Medium).margin({ left: 7 })
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
              Text('阅读记录').fontSize(18).fontWeight(FontWeight.Medium).fontColor('#ECEEF2').layoutWeight(1)
              Text('关闭').fontSize(14).fontColor('#C5C7D0').padding(8)
                .onClick(() => this.readRecordPanelVisible = false)
            }.width('100%').padding({ bottom: 12 })
            Column() {
              Text('累计阅读').fontSize(13).fontColor(this.themeColorTextSecondary)
              Text(this.readRecordPanel.totalLabel).fontSize(28).fontWeight(FontWeight.Bold)
                .fontColor(this.themeColorAccent).margin({ top: 6 })
            }.width('100%').padding(16).backgroundColor('#292A31').borderRadius(14)
              .alignItems(HorizontalAlign.Start)
            if (this.readRecordPanel.days.length === 0) {
              Text('暂无阅读记录').fontSize(14).fontColor('#AEB0BA')
                .width('100%').textAlign(TextAlign.Center).margin({ top: 28, bottom: 28 })
            } else {
              Scroll() {
                Column() {
                  ForEach(this.readRecordPanel.days, (day: BookReadRecordDay) => {
                    Column() {
                      Text(day.dateLabel).fontSize(14).fontWeight(FontWeight.Medium)
                        .fontColor(this.themeColorTextPrimary).alignSelf(ItemAlign.Start)
                        .margin({ top: 14, bottom: 8 })
                      ForEach(day.sessions, (session: BookReadRecordSession, sessionIndex: number) => {
                        Stack({ alignContent: Alignment.TopStart }) {
                          Column().width(2).height(48).backgroundColor('#3A3C46').margin({ left: 11 })
                          Column().width(8).height(8).borderRadius(4)
                            .backgroundColor(this.themeColorAccent).margin({ left: 8, top: 8 })
                          Column() {
                            Text(`${session.timeLabel} · ${session.durationLabel}`).fontSize(14)
                              .fontColor(this.themeColorTextPrimary)
                            if (session.chapterLabel.length > 0) {
                              Text(session.chapterLabel).fontSize(12)
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
            Text('查看全部').fontSize(14).fontColor('#B9C6FF').textAlign(TextAlign.Center)
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
      // 移出书架确认面板与日志面板共用这一个 bindSheet：
      // 同一节点挂两个 bindSheet 只有最后一个生效（书架页 :2118 踩过同一个坑），
      // 所以用一个合并条件 + 内容分支，不用两个独立 sheet。
      .bindSheet(this.deleteSheetVisible || this.logSheetVisible, this.InfoSheetContent(), {
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
          this.logSheetVisible = false;
        }
      })
  }

  /** 详情页 sheet 内容：日志优先，其余落回移出书架确认面板。 */
  @Builder
  InfoSheetContent() {
    if (this.logSheetVisible) {
      this.LogSheet()
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
    Text(this.label).fontSize(13).fontColor(this.selected ? '#F1F2F6' : '#C5C7D0')
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
    Text(this.label).fontSize(13).fontColor(this.themeColorTextSecondary)
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
        .fontSize(12)
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
