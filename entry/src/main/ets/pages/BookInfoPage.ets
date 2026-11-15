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

/** 溢出菜单面板宽度。上游宽度由内容驱动，本地给固定宽并让长文案省略。 */
const OVERFLOW_MENU_WIDTH: number = 260;
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
  /** 导出为 EPUB：只对本地书可用；落盘与提示文案都在 Index 侧。 */
  onExportEpub: (book: Book) => void = (_book: Book) => {};
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
  private infoScroller: Scroller = new Scroller();

  aboutToAppear(): void {
    this.loadFileSize();
    this.loadCoverSeedColor();
    this.refreshHighlightedTags();
  }

  /** 匹配源只有自定义标签与分类两路：本地没有书源标签，不硬造（:299）。 */
  private refreshHighlightedTags(): void {
    const labels: string[] = this.getCustomTags();
    if (this.book.category.length > 0) { labels.push(this.book.category); }
    this.highlightedTags = matchHighlightTags(labels, this.highlightTagRules);
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
    if (this.coverSeedColor.length === 0) { return ''; }
    return `#57${this.coverSeedColor.substring(1)}`;
  }

  /**
   * 渐变层里某一档的主色。有 seed 就换成对应 alpha 的 8 位色，没有就返回全透明
   * —— 对齐上游 `seedOverlay.copy(alpha = 0.10f / 0.18f)` 在无 seed 时取 Transparent。
   */
  private seedGradientColor(alpha: number): string {
    if (this.coverSeedColor.length === 0) { return '#00000000'; }
    const byte: number = Math.max(0, Math.min(255, Math.round(alpha * 255)));
    const hex: string = byte.toString(16).padStart(2, '0').toUpperCase();
    return `#${hex}${this.coverSeedColor.substring(1)}`;
  }

  /**
   * 渐变 0.40 那一档。上游写法是 `seedOverlay.copy(alpha = 0.18f)`，
   * 但注释写明了无 seed 时改取 `surface.copy(alpha = 0.35f)` —— 没有这一档，
   * 背景会从纯透明直接跳到 85% 底色，头部到内容之间就是一道硬边。
   */
  private midGradientColor(): string {
    return this.coverSeedColor.length > 0 ? this.seedGradientColor(0.18) : this.surfaceAlphaColor(0.35);
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
    // fileSizeBytes 已随迁移删除：一律按正文文件实际大小统计。
    if (this.book.contentPath === undefined || this.book.format === 'epub') { return; }
    try {
      this.fileSizeLabel = this.formatFileSize(fileIo.statSync(this.book.contentPath).size);
    } catch (_) {
      this.fileSizeLabel = '';
    }
  }

  private formatFileSize(bytes: number): string {
    if (bytes < 1024) { return `${bytes} B`; }
    if (bytes < 1024 * 1024) { return `${(bytes / 1024).toFixed(1)} KB`; }
    return `${(bytes / (1024 * 1024)).toFixed(2)} MB`;
  }

  private getFormatLabel(): string {
    if (this.book.format === 'epub') { return 'EPUB'; }
    if (this.book.format === 'txt') { return 'TXT'; }
    if (this.book.format === 'pdf') { return 'PDF'; }
    if (this.book.format === 'mobi') { return 'MOBI'; }
    if (this.book.format === 'umd') { return 'UMD'; }
    return this.book.category;
  }

  private getCustomTags(): string[] {
    return (this.book.customTag ?? '').split(/[\n,，]/)
      .map((tag: string) => tag.trim()).filter((tag: string) => tag.length > 0);
  }

  /** 第三行左段：状态。本地没有书源，这段永远不点击（:298）。 */
  private statusLabel(): string {
    if (BookRepository.isBodyMissing(this.book)) { return 'Android 备份 · 正文缺失'; }
    return this.book.isLocal ? '本地书籍' : '书籍详情';
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
   * 顺序照上游 `BookInfoScreen.kt:1034-1143` 的 `BookInfoOverflowMenu`
   * （custom_button → edit → refresh → read_record → book_disable_read_record →
   *  … → to_top → … → delete_alert → … → private），去掉本地没有对应能力的项后不补空位。
   * 上游 19 项里本地能做 8 项：书源变量、WebDAV 重同步、拆分超长章节、清理缓存、
   * 日志这些没有数据模型支撑，做了就是编。
   */
  private overflowItems(): UiMenuItem[] {
    const items: UiMenuItem[] = [
      { key: 'edit', title: '编辑' },
      { key: 'refresh', title: '刷新' },
      { key: 'read_record', title: '阅读记录' },
      {
        key: 'book_disable_read_record',
        title: this.book.disableReadRecord === true ? '启用阅读记录' : '禁用阅读记录',
        selected: this.book.disableReadRecord === true
      },
      { key: 'copy_book_url', title: '拷贝书籍 URL' },
      { key: 'to_top', title: '置顶' },
      { key: 'delete_alert', title: '删除提醒', selected: this.deleteAlertEnabled },
      {
        key: 'private',
        title: this.book.isPrivate === true ? '取消私密标记' : '标记为私密',
        selected: this.book.isPrivate === true
      }
    ];
    // 导出为 EPUB 是本地扩展（上游导出在 ExportBookService，不在溢出菜单里）。
    if (this.book.isLocal === true) {
      items.push({ key: 'export_epub', title: '导出为 EPUB' });
    }
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
    } else if (key === 'private') {
      this.onSetPrivate(this.book, this.book.isPrivate !== true);
    } else if (key === 'export_epub') {
      this.onExportEpub(this.book);
    }
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

  build() {
    Column() {
      // 内容层 + FAB 层：FAB 浮在内容右下角（上游 floatingActionButton），不占布局高度。
      Stack({ alignContent: Alignment.BottomEnd }) {
      Stack({ alignContent: Alignment.TopStart }) {
      if (this.backdropStyle().showCover && this.book.coverUri !== undefined && this.book.coverUri.length > 0) {
        Image(this.book.coverUri).width('100%').height(480).objectFit(ImageFit.Cover)
          .blur(this.backdropStyle().blurCover ? 24 : 0)
          .opacity(this.backdropOpacity).onAppear(() => {
            this.backdropOpacity = 0;
            animateTo({ duration: 800, curve: Curve.EaseInOut }, () => this.backdropOpacity = 0.45);
          })
      }
      if (this.backdropStyle().applySeedOverlay && this.seedOverlayColor().length > 0) {
        Column().width('100%').height(480).backgroundColor(this.seedOverlayColor())
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
                // 第三行拆两段：状态段不可点，来源段可点（:298）。
                Row() {
                  Text(this.statusLabel()).fontSize(14).fontColor('#B9C8FF')
                  Text(' · ').fontSize(14).fontColor('#777B88')
                  Text(this.sourceLabel()).fontSize(14).fontColor('#9FA6C8')
                    .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis }).layoutWeight(1)
                    .onClick(() => this.onOriginClick())
                }.width('100%').margin({ top: 8 })
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

            Row() {
              if (this.book.category.length > 0) { BookInfoTag({ label: this.book.category }) }
              if ((this.book.groupNames ?? []).length > 0) {
                ForEach(this.book.groupNames ?? [], (groupName: string) => {
                  BookInfoTag({ label: groupName })
                }, (groupName: string) => groupName)
              } else {
                BookInfoTag({ label: this.book.groupName ?? (this.book.isLocal ? '本地未分组' : '书架') })
              }
              BookInfoTag({ label: this.getFormatLabel() })
              if (this.fileSizeLabel.length > 0) { BookInfoTag({ label: this.fileSizeLabel }) }
              ForEach(this.getCustomTags(), (tag: string) => {
                BookInfoTag({ label: tag })
              }, (tag: string) => tag)
            }.width('100%').padding({ left: 18, right: 18, bottom: 20 })
            // 头部不设自己的底色：底色来自背景层的三段渐变（上游 BookInfoHeader 也是这样），
            // 原来这块硬编码的 '#55343845' 会在渐变上压出一块紫灰。
            }.width('100%')
          }.width('100%')

          Column() {

          // 上游 BookInfoActions（BookInfoScreen.kt:1391-1493）只有 4 张卡：
          // 书架 / 查看目录 / 换源 / 阅读记录。「禁用阅读记录」在上游只存在于溢出菜单里。
          Row() {
            BookInfoAction({
              icon: 'bookmark',
              label: BookRepository.isBodyMissing(this.book) ? '移出缺正文记录' : '已在书架',
              onSelect: () => this.requestRemoveFromShelf()
            })
            BookInfoAction({ icon: 'list', label: '查看目录', onSelect: () => this.onOpenCatalog() })
            BookInfoAction({ icon: 'swap', label: '换源', onSelect: () => this.onUnavailableAction('在线换源将在 P5 接入') })
            BookInfoAction({ icon: 'profileTimeline', label: '阅读记录', onSelect: () => this.openReadRecordPanel() })
          }.width('100%').padding({ left: 12, right: 12, top: 14, bottom: 16 })

          Column() {
            Text(this.book.progress > 0 ? `在读 · ${this.book.lastChapter}` : '尚未开始阅读')
              .fontSize(19).fontWeight(FontWeight.Bold).fontColor(this.themeColorTextPrimary)
            // 第二行是「最新章节」，不是「当前阅读章」：上游接的是 latestChapterTitle。
            Text(`最新 · ${this.book.latestChapterTitle ?? ''}`)
              .fontSize(16).fontColor(this.themeColorTextSecondary).margin({ top: 8 })
            Row() {
              Text(this.getChapterTotal() > 0 ? `共 ${this.getChapterTotal()} 章` : '章节总数待读取')
                .fontSize(14).fontColor(this.themeColorAccent)
              Text('  |  ').fontSize(14).fontColor(this.themeColorTextTertiary)
              Text(this.readStateLabel())
                .fontSize(14).fontColor(this.themeColorTextSecondary)
            }.margin({ top: 8 })
          }.width('100%').alignItems(HorizontalAlign.Start).padding(18)
            .backgroundColor(this.themeAppBackground.length > 0 ? Color.Transparent : (this.themePureBlack ? '#0A0A0A' : this.themeColorSurfaceTertiary)).borderRadius(18).margin({ left: 16, right: 16, bottom: 14 })

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
            Text('小说简介').fontSize(20).fontWeight(FontWeight.Bold).fontColor(this.themeColorTextPrimary)
              .alignSelf(ItemAlign.Start)
            if (this.book.description !== undefined && this.book.description.trim().length > 0) {
              Text(this.book.description).fontSize(16).lineHeight(25).fontColor('#D0D2DB')
                .alignSelf(ItemAlign.Start).margin({ top: 12 })
            } else {
              Text('暂无小说简介').fontSize(16).fontColor('#BFC1CB').alignSelf(ItemAlign.Start)
                .margin({ top: 12 })
              Text(this.book.isLocal ? '本地导入文件没有附带简介信息。' : '当前没有可显示的简介内容。')
                .fontSize(14).lineHeight(21).fontColor('#858792').alignSelf(ItemAlign.Start)
                .margin({ top: 6 })
            }
            if ((this.book.remark ?? '').trim().length > 0) {
              // 备注卡可点：整块进元数据面板（:315），不单给正文加点击区。
              Column() {
                Text('备注').fontSize(16).fontWeight(FontWeight.Medium).fontColor(this.themeColorTextPrimary)
                  .alignSelf(ItemAlign.Start).margin({ top: 16 })
                Text(this.book.remark ?? '').fontSize(14).lineHeight(21).fontColor('#BFC1CB')
                  .alignSelf(ItemAlign.Start).margin({ top: 6 })
              }.width('100%').onClick(() => this.onOpenEditPage())
            }
          }.width('100%').alignItems(HorizontalAlign.Start).padding(18)
            .backgroundColor(this.themeAppBackground.length > 0 ? Color.Transparent : (this.themePureBlack ? '#0A0A0A' : this.themeColorSurfaceTertiary)).borderRadius(18).margin({ left: 16, right: 16, bottom: 24 })
          // 内容列不铺底色：底色由第三层渐变给（上游 BookInfoBackdrop 的 0.60→1.0 段），
          // 铺了就从头部到内容一刀切，渐变看不出来。
          }.width('100%')
        }.width('100%').padding({ bottom: CONTENT_BOTTOM_INSET })
      }.width('100%').height('100%').scrollBar(BarState.Off).onScroll(() => {
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
        .backgroundColor(this.collapsedHeader ? this.themeColorSurfacePrimary : '#00000000')
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
              }.layoutWeight(1).scrollBar(BarState.Off)
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
      .bindSheet(this.deleteSheetVisible, this.DeleteSheet(), {
        height: SheetSize.FIT_CONTENT,
        dragBar: true,
        showClose: false,
        backgroundColor: '#17181E',
        onDisappear: () => {
          this.deleteSheetVisible = false;
          // 每次打开都从未勾选起步（:339）。
          this.deleteSourceChecked = false;
        }
      })
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
  @StorageProp('themeColorSurfaceElevated') themeColorSurfaceElevated: string = '#FFFFFF';
  @StorageProp('themeAppBackground') themeAppBackground: string = '';
  @StorageProp('themePureBlack') themePureBlack: boolean = false;
  @Prop icon: AppGlyphName = 'book';
  @Prop label: string = '';
  onSelect: () => void = () => {};
  build() {
    Column() {
      AppGlyph({ name: this.icon, glyphSize: 20, tint: this.themeColorTextSecondary }).margin({ bottom: 7 })
      Text(this.label).fontSize(12).fontColor(this.themeColorTextSecondary).maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }.layoutWeight(1).height(72).justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
      .backgroundColor(this.themeAppBackground.length > 0 ? Color.Transparent : (this.themePureBlack ? '#121212' : this.themeColorSurfaceElevated)).borderRadius(14).margin({ left: 4, right: 4 })
      .onClick(() => this.onSelect())
  }
}
