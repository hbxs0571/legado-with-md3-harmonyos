import { fileIo } from '@kit.CoreFileKit';
import { Book, BookMediaType } from '../model/Book';
import { BookGroup } from '../model/BookGroup';
import { AppGlyph, AppGlyphName } from '../components/AppGlyph';
import { BookCover } from '../components/BookCover';

@Component
export struct BookInfoPage {
  @Prop book: Book = {
    id: '', title: '', author: '', category: '', lastChapter: '', progress: 0,
    coverColor: '#343845', coverMark: '书', isLocal: true
  };
  @Prop groups: BookGroup[] = [];
  onBack: () => void = () => {};
  onRead: () => void = () => {};
  onOpenCatalog: () => void = () => {};
  onOpenReadRecords: () => void = () => {};
  onRemoveFromShelf: () => void = () => {};
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
  private infoScroller: Scroller = new Scroller();

  aboutToAppear(): void {
    this.loadFileSize();
  }

  private loadFileSize(): void {
    if (this.book.fileSizeBytes !== undefined && this.book.fileSizeBytes > 0) {
      this.fileSizeLabel = this.formatFileSize(this.book.fileSizeBytes);
      return;
    }
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
    const savedCount = Number(this.book.chapterCount ?? '0');
    return savedCount > 0 ? savedCount : (this.book.chapterTitles?.length ?? 0);
  }

  private getReadChapterNumber(): number {
    if (this.book.progress <= 0 && (this.book.chapterProgress ?? 0) <= 0) { return 0; }
    return (this.book.chapterIndex ?? 0) + 1;
  }

  private confirmRemoveFromShelf(): void {
    this.getUIContext().showAlertDialog({
      title: '移出书架？',
      message: this.book.bodyMissing === true
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
      if (this.book.coverUri !== undefined && this.book.coverUri.length > 0) {
        Image(this.book.coverUri).width('100%').height(480).objectFit(ImageFit.Cover).blur(24)
          .opacity(this.backdropOpacity).onAppear(() => {
            this.backdropOpacity = 0;
            animateTo({ duration: 800, curve: Curve.EaseInOut }, () => this.backdropOpacity = 0.45);
          })
      }
      Scroll(this.infoScroller) {
        Column() {
          Stack() {
            Column() {
            Blank().height(66)

            Row() {
              BookCover({ book: this.book, displayWidth: 112, displayHeight: 157 })
              Column() {
                Text(this.book.title).fontSize(23).fontWeight(FontWeight.Bold).fontColor('#F1F2F6')
                  .maxLines(3).textOverflow({ overflow: TextOverflow.Ellipsis })
                Text(this.book.author.length > 0 ? this.book.author : '作者未知')
                  .fontSize(17).fontColor('#D0D2DB').margin({ top: 8 })
                Text(this.book.bodyMissing === true ? 'Android 备份 · 正文缺失' : this.book.isLocal ? '本地书籍' : '书籍详情')
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
              label: this.book.bodyMissing === true ? '移出缺正文记录' : '已在书架',
              onSelect: () => this.confirmRemoveFromShelf()
            })
            BookInfoAction({ icon: 'list', label: '查看目录', onSelect: () => this.onOpenCatalog() })
            BookInfoAction({ icon: 'swap', label: '换源', onSelect: () => this.onUnavailableAction('在线换源将在 P5 接入') })
            BookInfoAction({ icon: 'clock', label: '阅读记录', onSelect: () => this.onOpenReadRecords() })
          }.width('100%').padding({ left: 12, right: 12, top: 14, bottom: 16 })

          Column() {
            Text(this.book.progress > 0 ? `在读 · ${this.book.lastChapter}` : '尚未开始阅读')
              .fontSize(19).fontWeight(FontWeight.Bold).fontColor('#E3E4E8')
            Text(`最新 · ${this.book.lastChapter.length > 0 ? this.book.lastChapter : '尚无章节信息'}`)
              .fontSize(16).fontColor('#BFC1CB').margin({ top: 8 })
            Row() {
              Text(this.getChapterTotal() > 0 ? `共 ${this.getChapterTotal()} 章` : '章节总数待读取')
                .fontSize(14).fontColor('#AFC2FF')
              Text('  |  ').fontSize(14).fontColor('#777B88')
              Text(this.getReadChapterNumber() > 0 ? `已读 ${this.getReadChapterNumber()} 章` : '未读')
                .fontSize(14).fontColor('#AFC2FF')
            }.margin({ top: 8 })
            Row() {
              Row().width(`${Math.max(0, Math.min(100, this.book.progress))}%`).height(5)
                .backgroundColor('#AFC2FF').borderRadius(3)
              Blank()
            }.width('100%').height(5).backgroundColor('#3A3C46').borderRadius(3).margin({ top: 12 })
          }.width('100%').alignItems(HorizontalAlign.Start).padding(18)
            .backgroundColor('#1B1C22').borderRadius(18).margin({ left: 16, right: 16, bottom: 14 })

          if (this.book.bodyMissing === true) {
            Column() {
              Text('已恢复书目与阅读位置，缺少正文文件')
                .fontSize(17).fontWeight(FontWeight.Medium).fontColor('#F0B2A8')
              Text('Android 备份只保存书架记录和阅读位置，不包含 TXT / EPUB 正文。重新选择原书文件后才能继续阅读。')
                .fontSize(14).lineHeight(21).fontColor('#D8D9E0').margin({ top: 8 })
              if ((this.book.androidOriginalPath ?? '').length > 0) {
                Text(`Android 原路径：${this.book.androidOriginalPath ?? ''}`)
                  .fontSize(12).lineHeight(18).fontColor('#92949E').margin({ top: 8 })
              }
            }.width('100%').alignItems(HorizontalAlign.Start).padding(16)
              .backgroundColor('#2A1D20').borderRadius(16).margin({ left: 16, right: 16, bottom: 14 })
          }

          Column() {
            Text('小说简介').fontSize(20).fontWeight(FontWeight.Bold).fontColor('#E3E4E8')
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
              Text('备注').fontSize(16).fontWeight(FontWeight.Medium).fontColor('#E3E4E8')
                .alignSelf(ItemAlign.Start).margin({ top: 16 })
              Text(this.book.remark ?? '').fontSize(14).lineHeight(21).fontColor('#BFC1CB')
                .alignSelf(ItemAlign.Start).margin({ top: 6 })
            }
          }.width('100%').alignItems(HorizontalAlign.Start).padding(18)
            .backgroundColor('#1B1C22').borderRadius(18).margin({ left: 16, right: 16, bottom: 24 })
          }.width('100%').backgroundColor('#111217')
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
        BookInfoIconButton({ icon: 'more', onSelect: () => this.onUnavailableAction('书籍更多操作尚未迁移') })
      }.width('100%').height(56).padding({ left: 16, right: 16, top: 8, bottom: 8 })
        .backgroundColor(this.collapsedHeader ? '#111217' : '#00000000')
        .animation({ duration: 220, curve: Curve.EaseInOut })
      }.layoutWeight(1).width('100%').backgroundColor(this.book.coverColor)

      Row() {
        Blank()
        Row() {
          AppGlyph({ name: 'book', glyphSize: 17, tint: '#F2F2F7' })
          Text(this.book.bodyMissing === true ? '缺少正文' : '阅读')
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
                  BookCover({ book: this.book, displayWidth: 58, displayHeight: 82, cornerRadius: 7 })
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
                      .fontSize(12).fontColor('#92949E')
                  } else {
                    ForEach(this.groups.filter((group: BookGroup) => group.groupId > 0), (group: BookGroup) => {
                      Row() {
                        Text(group.groupName).fontSize(13).fontColor('#D8D9E0').layoutWeight(1)
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
          .width('90%').height('78%').padding(18).backgroundColor('#1A1B21').borderRadius(22)
          .onClick(() => {})
        }.width('100%').height('100%').zIndex(1000)
      }
    }.width('100%').height('100%').backgroundColor('#111217')
  }
}

@Component
struct BookTypeChoice {
  @Prop label: string = '';
  @Prop selected: boolean = false;
  onSelect: () => void = () => {};
  build() {
    Text(this.label).fontSize(13).fontColor(this.selected ? '#F1F2F6' : '#C5C7D0')
      .textAlign(TextAlign.Center).layoutWeight(1).padding({ top: 9, bottom: 9 })
      .backgroundColor(this.selected ? '#46476B' : '#1C1D23').borderRadius(10)
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
  @Prop label: string = '';
  build() {
    Text(this.label).fontSize(13).fontColor('#D8D9E0')
      .padding({ left: 10, right: 10, top: 6, bottom: 6 })
      .backgroundColor('#171820').borderRadius(14).margin({ right: 8 })
  }
}

@Component
struct BookInfoAction {
  @Prop icon: AppGlyphName = 'book';
  @Prop label: string = '';
  onSelect: () => void = () => {};
  build() {
    Column() {
      AppGlyph({ name: this.icon, glyphSize: 20, tint: '#D8D9E0' }).margin({ bottom: 7 })
      Text(this.label).fontSize(12).fontColor('#D8D9E0').maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }.layoutWeight(1).height(72).justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
      .backgroundColor('#1C1D23').borderRadius(14).margin({ left: 4, right: 4 })
      .onClick(() => this.onSelect())
  }
}
