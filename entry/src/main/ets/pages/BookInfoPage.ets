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
  @State metadataEditorVisible: boolean = false;
  @State metadataTitle: string = '';
  @State metadataAuthor: string = '';
  @State metadataCategory: string = '';
  @State metadataDescription: string = '';
  @State metadataRemark: string = '';
  @State metadataCustomTag: string = '';
  @State metadataGroupNames: string[] = [];
  @State metadataBookType: BookMediaType = 'text';
  @State metadataFixedType: boolean = false;
  /** 从封面提取出的主色，空串表示尚未取到或取色失败。 */
  @State coverSeedColor: string = '';
  /** 本书阅读记录面板显隐与数据，照 F12 自绘全屏遮罩范式。 */
  @State readRecordPanelVisible: boolean = false;
  @State readRecordPanel: BookReadRecordPanel = { totalLabel: '0秒', days: [] };
  /** 书名是否展开（:296 长按菜单里的「展开/收起」）。 */
  @State titleExpanded: boolean = false;
  /** 命中高亮规则的标签块，aboutToAppear 算一次。 */
  @State highlightedTags: HighlightedTag[] = [];
  /** 标签编辑器的 chip 列表（:332）；保存时 join 成 customTag。 */
  @State metadataTags: string[] = [];
  @State metadataTagInput: string = '';
  @State metadataTagEditing: boolean = false;
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

  /** 标签编辑器里加一个标签（:332）；重名忽略，不重复加。 */
  private addMetadataTag(): void {
    const value = this.metadataTagInput.trim();
    this.metadataTagInput = '';
    this.metadataTagEditing = false;
    if (value.length === 0) { return; }
    if (this.metadataTags.includes(value)) { return; }
    this.metadataTags = [...this.metadataTags, value];
  }

  private removeMetadataTag(tag: string): void {
    this.metadataTags = this.metadataTags.filter((item: string) => item !== tag);
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

  /** 顶栏「更多」菜单（:294）。只放能真做的项，不放点了没反应的占位。 */
  @Builder
  private BookInfoMoreMenu() {
    Menu() {
      MenuItem({ content: this.book.isPrivate === true ? '取消私密' : '设为私密' }).height(48)
        .onClick(() => this.onSetPrivate(this.book, this.book.isPrivate !== true))
      MenuItem({ content: '置顶' }).height(48).onClick(() => this.onTopBook())
      MenuItem({ content: '刷新书籍信息' }).height(48).onClick(async () => {
        await this.onRefreshBookInfo(this.book);
      })
      MenuItem({ content: this.deleteAlertEnabled ? '删除时不再确认' : '删除前先确认' })
        .height(48).onClick(() => this.onToggleDeleteAlert())
    }.backgroundColor('#17181E').fontColor('#F1F2F6').radius(20)
  }

  private openMetadataEditor(): void {
    this.metadataTitle = this.book.title;
    this.metadataAuthor = this.book.author;
    this.metadataCategory = this.book.category;
    this.metadataDescription = this.book.description ?? '';
    this.metadataRemark = this.book.remark ?? '';
    this.metadataCustomTag = this.book.customTag ?? '';
    this.metadataTags = this.getCustomTags();
    this.metadataTagInput = '';
    this.metadataTagEditing = false;
    this.metadataGroupNames = [...(this.book.groupNames ?? [])];
    this.metadataBookType = this.book.bookType ?? 'text';
    this.metadataFixedType = this.book.fixedType === true;
    this.metadataEditorVisible = true;
  }

  private async saveMetadata(): Promise<void> {
    const title = this.metadataTitle.trim();
    if (title.length === 0) {
      this.onUnavailableAction('书名不能为空，未保存书籍信息');
      return;
    }
    const saved = await this.onSaveMetadata(
      title,
      this.metadataAuthor.trim(),
      this.metadataCategory.trim(),
      this.metadataDescription.trim(),
      this.metadataRemark.trim(),
      this.metadataTags.join(','),
      this.metadataGroupNames,
      this.metadataBookType,
      this.metadataFixedType
    );
    if (saved) { this.metadataEditorVisible = false; }
  }

  private toggleMetadataGroup(name: string, selected: boolean): void {
    if (selected && !this.metadataGroupNames.includes(name)) {
      this.metadataGroupNames = [...this.metadataGroupNames, name];
    } else if (!selected) {
      this.metadataGroupNames = this.metadataGroupNames.filter((item: string) => item !== name);
    }
  }

  build() {
    Column() {
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
      Scroll(this.infoScroller) {
        Column() {
          Stack() {
            Column() {
            Blank().height(66)

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
            }.width('100%').backgroundColor('#55343845')
          }.width('100%')

          Column() {

          Row() {
            BookInfoAction({
              icon: 'bookmark',
              label: BookRepository.isBodyMissing(this.book) ? '移出缺正文记录' : '已在书架',
              onSelect: () => this.requestRemoveFromShelf()
            })
            BookInfoAction({ icon: 'list', label: '查看目录', onSelect: () => this.onOpenCatalog() })
            BookInfoAction({ icon: 'swap', label: '换源', onSelect: () => this.onUnavailableAction('在线换源将在 P5 接入') })
            BookInfoAction({ icon: 'clock', label: '阅读记录', onSelect: () => this.openReadRecordPanel() })
            BookInfoAction({
              icon: 'clock',
              label: this.book.disableReadRecord === true ? '启用阅读记录' : '禁用阅读记录',
              onSelect: () => this.onToggleDisableReadRecord(this.book, !(this.book.disableReadRecord === true))
            })
          }.width('100%').padding({ left: 12, right: 12, top: 14, bottom: 16 })

          Column() {
            Text(this.book.progress > 0 ? `在读 · ${this.book.lastChapter}` : '尚未开始阅读')
              .fontSize(19).fontWeight(FontWeight.Bold).fontColor(this.themeColorTextPrimary)
            Text(`最新 · ${this.book.lastChapter.length > 0 ? this.book.lastChapter : '尚无章节信息'}`)
              .fontSize(16).fontColor('#BFC1CB').margin({ top: 8 })
            Row() {
              Text(this.getChapterTotal() > 0 ? `共 ${this.getChapterTotal()} 章` : '章节总数待读取')
                .fontSize(14).fontColor(this.themeColorAccent)
              Text('  |  ').fontSize(14).fontColor('#777B88')
              Text(this.readStateLabel())
                .fontSize(14).fontColor(this.themeColorAccent)
            }.margin({ top: 8 })
            Row() {
              Row().width(`${Math.max(0, Math.min(100, this.book.progress))}%`).height(5)
                .backgroundColor(this.themeColorAccent).borderRadius(3)
              Blank()
            }.width('100%').height(5).backgroundColor('#3A3C46').borderRadius(3).margin({ top: 12 })
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
              }.width('100%').onClick(() => this.openMetadataEditor())
            }
          }.width('100%').alignItems(HorizontalAlign.Start).padding(18)
            .backgroundColor(this.themeAppBackground.length > 0 ? Color.Transparent : (this.themePureBlack ? '#0A0A0A' : this.themeColorSurfaceTertiary)).borderRadius(18).margin({ left: 16, right: 16, bottom: 24 })
          }.width('100%').backgroundColor(this.themeAppBackground.length > 0 ? Color.Transparent : (this.themePureBlack ? '#000000' : this.themeColorSurfacePrimary))
        }.width('100%').padding({ bottom: 12 })
      }.width('100%').height('100%').scrollBar(BarState.Off).onScroll(() => {
        const shouldCollapse = Math.abs(this.infoScroller.currentOffset().yOffset) > 70;
        if (this.collapsedHeader !== shouldCollapse) { this.collapsedHeader = shouldCollapse; }
      })

      Row() {
        Stack({ alignContent: Alignment.Center }) {
          Image($r('app.media.reader_back')).width(20).height(20).fillColor('#F1F2F6')
        }.width(40).height(40).backgroundColor('#171820').borderRadius(20)
          .onClick(() => this.onBack())
        Blank().layoutWeight(1)
        BookInfoIconButton({ icon: 'edit', onSelect: () => this.openMetadataEditor() })
        BookInfoIconButton({ icon: 'share', onSelect: () => this.onUnavailableAction('书籍分享尚未迁移') })
        // 「更多」改成真实菜单（:294）。批7 会把置顶/刷新书籍信息/删除确认陆续接进来。
        Stack({ alignContent: Alignment.Center }) { AppGlyph({ name: 'more', glyphSize: 19, tint: '#F1F2F6' }) }
          .width(40).height(40).backgroundColor('#171820').borderRadius(20).margin({ left: 8 })
          .bindMenu(this.BookInfoMoreMenu, { placement: Placement.BottomRight })
      }.width('100%').height(56).padding({ left: 16, right: 16, top: 8, bottom: 8 })
        .backgroundColor(this.collapsedHeader ? this.themeColorSurfacePrimary : '#00000000')
        .animation({ duration: 220, curve: Curve.EaseInOut })
      }.layoutWeight(1).width('100%').backgroundColor(bookCoverColor(this.book))

      Row() {
        Blank()
        Row() {
          AppGlyph({ name: 'book', glyphSize: 17, tint: '#F2F2F7' })
          Text(BookRepository.isBodyMissing(this.book) ? '缺少正文' : '阅读')
            .fontSize(14).fontWeight(FontWeight.Medium).fontColor('#F2F2F7').margin({ left: 7 })
        }.justifyContent(FlexAlign.Center).width(104).padding({ top: 13, bottom: 13 })
          .backgroundColor('#46476B').borderRadius(26).onClick(() => this.onRead())
      }.width('100%').justifyContent(FlexAlign.End).padding({ left: 20, right: 20, top: 8, bottom: 12 })

      if (this.metadataEditorVisible) {
        Stack({ alignContent: Alignment.Center }) {
          Column().width('100%').height('100%').backgroundColor('#99000000')
            .onClick(() => this.metadataEditorVisible = false)
          Column() {
            Row() {
              Text('编辑书籍信息').fontSize(18).fontWeight(FontWeight.Medium).fontColor('#ECEEF2').layoutWeight(1)
              Text('取消').fontSize(14).fontColor('#C5C7D0').padding(8)
                .onClick(() => this.metadataEditorVisible = false)
            }.width('100%').padding({ bottom: 12 })
            Scroll() {
              Column() {
                Row() {
                  BookCover({ book: this.book, displayWidth: 58, displayHeight: 82, cornerRadius: 7, coverSettings: this.coverSettings })
                    .width(58).height(82)
                  Column() {
                    Text('封面').fontSize(15).fontWeight(FontWeight.Medium).fontColor('#ECEEF2')
                    Text('仅更改应用内封面副本，原始小说文件保持不变')
                      .fontSize(12).fontColor('#AEB0BA').margin({ top: 4, bottom: 8 })
                    Row() {
                      Text('选择图片').fontSize(13).fontColor('#B9C6FF').padding({ right: 16 })
                        .onClick(() => this.onChooseCover())
                      Text('还原封面').fontSize(13).fontColor('#BFC1CB')
                        .onClick(() => this.onRestoreCover())
                    }
                  }.alignItems(HorizontalAlign.Start).layoutWeight(1).margin({ left: 14 })
                }.width('100%').padding(12).backgroundColor('#292A31').borderRadius(12)
                Column() {
                  Text('书籍类型').fontSize(14).fontColor('#ECEEF2').margin({ bottom: 8 })
                  Row() {
                    BookTypeChoice({ label: '文本', selected: this.metadataBookType === 'text', onSelect: () => this.metadataBookType = 'text' })
                    BookTypeChoice({ label: '音频', selected: this.metadataBookType === 'audio', onSelect: () => this.metadataBookType = 'audio' })
                    BookTypeChoice({ label: '图片', selected: this.metadataBookType === 'image', onSelect: () => this.metadataBookType = 'image' })
                  }.width('100%')
                  Row() {
                    Text('固定书籍类型').fontSize(13).fontColor('#C5C7D0').layoutWeight(1)
                    Toggle({ type: ToggleType.Switch, isOn: this.metadataFixedType })
                      .onChange((value: boolean) => this.metadataFixedType = value)
                  }.width('100%').margin({ top: 8 })
                }.width('100%').padding(12).backgroundColor('#292A31').borderRadius(12).margin({ bottom: 10 })
                Column() {
                  Text('书架分组（可多选）').fontSize(14).fontColor('#ECEEF2').margin({ bottom: 8 })
                  if (this.groups.filter((group: BookGroup) => group.groupId > 0).length === 0) {
                    Text('暂无自定义分组，可从书架右上角的分组管理中添加')
                      .fontSize(12).fontColor(this.themeColorTextTertiary)
                  } else {
                    ForEach(this.groups.filter((group: BookGroup) => group.groupId > 0), (group: BookGroup) => {
                      Row() {
                        Text(group.groupName).fontSize(13).fontColor(this.themeColorTextSecondary).layoutWeight(1)
                        Toggle({ type: ToggleType.Checkbox, isOn: this.metadataGroupNames.includes(group.groupName) })
                          .onChange((selected: boolean) => this.toggleMetadataGroup(group.groupName, selected))
                      }.width('100%').padding({ top: 5, bottom: 5 })
                    }, (group: BookGroup) => `${group.groupId}`)
                  }
                }.width('100%').padding(12).backgroundColor('#292A31').borderRadius(12).margin({ bottom: 10 })
                TextInput({ text: this.metadataTitle, placeholder: '书名' }).width('100%').height(48)
                  .fontSize(15).fontColor('#ECEEF2').backgroundColor('#292A31').borderRadius(10)
                  .padding({ left: 12, right: 12 }).onChange((value: string) => this.metadataTitle = value)
                TextInput({ text: this.metadataAuthor, placeholder: '作者' }).width('100%').height(48)
                  .fontSize(15).fontColor('#ECEEF2').backgroundColor('#292A31').borderRadius(10)
                  .padding({ left: 12, right: 12 }).margin({ top: 10 })
                  .onChange((value: string) => this.metadataAuthor = value)
                TextInput({ text: this.metadataCategory, placeholder: '分类' }).width('100%').height(48)
                  .fontSize(15).fontColor('#ECEEF2').backgroundColor('#292A31').borderRadius(10)
                  .padding({ left: 12, right: 12 }).margin({ top: 10 })
                  .onChange((value: string) => this.metadataCategory = value)
                // 标签编辑器改成 chip 行（:332）：逐个增删。不做拖拽——标签顺序只影响
                // 这一行的排布，对其它界面没有意义。
                Column() {
                  Text('自定义标签').fontSize(14).fontColor('#ECEEF2').margin({ top: 10, bottom: 8 })
                  Flex({ wrap: FlexWrap.Wrap }) {
                    ForEach(this.metadataTags, (tag: string) => {
                      Row() {
                        Text(tag).fontSize(13).fontColor('#ECEEF2')
                        Stack({ alignContent: Alignment.Center }) {
                          AppGlyph({ name: 'profileClose', glyphSize: 11, tint: '#9AA0B4' })
                        }.width(20).height(20).margin({ left: 4 })
                          .onClick(() => this.removeMetadataTag(tag))
                      }.padding({ left: 10, right: 6, top: 6, bottom: 6 })
                        .backgroundColor('#33353D').borderRadius(14).margin({ right: 8, bottom: 8 })
                    }, (tag: string) => tag)
                    Text('＋').fontSize(15).fontColor('#B9C6FF')
                      .padding({ left: 12, right: 12, top: 6, bottom: 6 })
                      .backgroundColor('#293A5C').borderRadius(14).margin({ bottom: 8 })
                      .onClick(() => this.metadataTagEditing = true)
                  }.width('100%')
                  if (this.metadataTagEditing) {
                    Row() {
                      TextInput({ text: this.metadataTagInput, placeholder: '输入标签后点添加' })
                        .layoutWeight(1).height(44).fontSize(14).fontColor('#ECEEF2')
                        .backgroundColor('#33353D').borderRadius(10).padding({ left: 12, right: 12 })
                        .onChange((value: string) => this.metadataTagInput = value)
                      Text('添加').fontSize(13).fontColor('#B9C6FF').padding(10)
                        .onClick(() => this.addMetadataTag())
                    }.width('100%')
                  }
                }.width('100%').alignItems(HorizontalAlign.Start)
                TextArea({ text: this.metadataDescription, placeholder: '小说简介' }).width('100%').height(180)
                  .fontSize(15).fontColor('#ECEEF2').backgroundColor('#292A31').borderRadius(10)
                  .padding(12).margin({ top: 10 })
                  .onChange((value: string) => this.metadataDescription = value)
                TextArea({ text: this.metadataRemark, placeholder: '备注' }).width('100%').height(120)
                  .fontSize(15).fontColor('#ECEEF2').backgroundColor('#292A31').borderRadius(10)
                  .padding(12).margin({ top: 10 })
                  .onChange((value: string) => this.metadataRemark = value)
              }.width('100%')
            }.layoutWeight(1).scrollBar(BarState.Off)
            Row() {
              Blank().layoutWeight(1)
              Text('保存').fontSize(14).fontColor('#101116').textAlign(TextAlign.Center)
                .width(84).padding({ top: 10, bottom: 10 }).backgroundColor('#B9C6FF').borderRadius(18)
                .onClick(() => this.saveMetadata())
            }.width('100%').padding({ top: 12 })
          }
          .width('90%').height('78%').padding(18).backgroundColor(this.themeColorSurfaceSecondary).borderRadius(22)
          .onClick(() => {})
        }.width('100%').height('100%').zIndex(1000)
      }

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
struct BookInfoIconButton {
  @Prop icon: AppGlyphName = 'info';
  onSelect: () => void = () => {};
  build() {
    Stack({ alignContent: Alignment.Center }) {
      AppGlyph({ name: this.icon, glyphSize: 19, tint: '#F1F2F6' })
    }.width(40).height(40).backgroundColor('#171820').borderRadius(20)
      .margin({ left: 8 }).onClick(() => this.onSelect())
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
