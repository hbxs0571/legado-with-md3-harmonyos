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
  onRemoveFromShelf: () => void = () => {};
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
  private infoScroller: Scroller = new Scroller();

  aboutToAppear(): void {
    this.loadFileSize();
    this.loadCoverSeedColor();
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

  private confirmRemoveFromShelf(): void {
    this.getUIContext().showAlertDialog({
      title: '移出书架？',
      message: BookRepository.isBodyMissing(this.book)
        ? '移出后只删除这条缺正文书目记录；Android 兼容归档和原始文件不会更改。'
        : '移出后会清理应用内的导入副本，原始文件会保留。',
      autoCancel: true,
      primaryButton: { value: '取消', action: () => {} },
      secondaryButton: {
        value: '移出书架',
        action: () => this.onRemoveFromShelf()
      }
    });
  }

  /** 顶栏「更多」菜单（:294）。只放能真做的项，不放点了没反应的占位。 */
  @Builder
  private BookInfoMoreMenu() {
    Menu() {
      MenuItem({ content: this.book.isPrivate === true ? '取消私密' : '设为私密' }).height(48)
        .onClick(() => this.onSetPrivate(this.book, this.book.isPrivate !== true))
    }.backgroundColor('#17181E').fontColor('#F1F2F6').radius(20)
  }

  private openMetadataEditor(): void {
    this.metadataTitle = this.book.title;
    this.metadataAuthor = this.book.author;
    this.metadataCategory = this.book.category;
    this.metadataDescription = this.book.description ?? '';
    this.metadataRemark = this.book.remark ?? '';
    this.metadataCustomTag = this.book.customTag ?? '';
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
      this.metadataCustomTag.trim(),
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
              BookCover({ book: this.book, displayWidth: 112, displayHeight: 157, coverSettings: this.coverSettings, applyAspectRatio: true })
              Column() {
                Text(this.book.title).fontSize(23).fontWeight(FontWeight.Bold).fontColor('#F1F2F6')
                  .maxLines(3).textOverflow({ overflow: TextOverflow.Ellipsis })
                Text(this.book.author.length > 0 ? this.book.author : '作者未知')
                  .fontSize(17).fontColor('#D0D2DB').margin({ top: 8 })
                Text(BookRepository.isBodyMissing(this.book) ? 'Android 备份 · 正文缺失' : this.book.isLocal ? '本地书籍' : '书籍详情')
                  .fontSize(14).fontColor('#B9C8FF').margin({ top: 8 })
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
              onSelect: () => this.confirmRemoveFromShelf()
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
              Text(this.getReadChapterNumber() > 0 ? `已读 ${this.getReadChapterNumber()} 章` : '未读')
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
              Text('备注').fontSize(16).fontWeight(FontWeight.Medium).fontColor(this.themeColorTextPrimary)
                .alignSelf(ItemAlign.Start).margin({ top: 16 })
              Text(this.book.remark ?? '').fontSize(14).lineHeight(21).fontColor('#BFC1CB')
                .alignSelf(ItemAlign.Start).margin({ top: 6 })
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
                TextInput({ text: this.metadataCustomTag, placeholder: '自定义标签（用逗号分隔）' }).width('100%').height(48)
                  .fontSize(15).fontColor('#ECEEF2').backgroundColor('#292A31').borderRadius(10)
                  .padding({ left: 12, right: 12 }).margin({ top: 10 })
                  .onChange((value: string) => this.metadataCustomTag = value)
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
    }.width('100%').height('100%').backgroundColor(this.themeAppBackground.length > 0 ? Color.Transparent : (this.themePureBlack ? '#000000' : this.themeColorSurfacePrimary))
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
