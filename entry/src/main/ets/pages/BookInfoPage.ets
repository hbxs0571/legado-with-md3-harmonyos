import { fileIo } from '@kit.CoreFileKit';
import { Book } from '../model/Book';
import { AppGlyph, AppGlyphName } from '../components/AppGlyph';
import { BookCover } from '../components/BookCover';

@Component
export struct BookInfoPage {
  @Prop book: Book = {
    id: '', title: '', author: '', category: '', lastChapter: '', progress: 0,
    coverColor: '#343845', coverMark: '书', isLocal: true
  };
  onBack: () => void = () => {};
  onRead: () => void = () => {};
  onOpenCatalog: () => void = () => {};
  onOpenReadRecords: () => void = () => {};
  onRemoveFromShelf: () => void = () => {};
  onUnavailableAction: (message: string) => void = (_message: string) => {};
  @State fileSizeLabel: string = '';

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

  build() {
    Column() {
      Scroll() {
        Column() {
          Stack() {
            if (this.book.coverUri !== undefined && this.book.coverUri.length > 0) {
              Image(this.book.coverUri).width('100%').height(320).objectFit(ImageFit.Cover).blur(36).opacity(0.45)
            }
            Column() {
            Row() {
              Stack({ alignContent: Alignment.Center }) {
                Image($r('app.media.reader_back')).width(20).height(20).fillColor('#F1F2F6')
              }.width(40).height(40).backgroundColor('#171820').borderRadius(20)
                .onClick(() => this.onBack())
              Blank()
              BookInfoIconButton({ icon: 'edit', onSelect: () => this.onUnavailableAction('本地书籍信息编辑尚未迁移') })
              BookInfoIconButton({ icon: 'share', onSelect: () => this.onUnavailableAction('书籍分享尚未迁移') })
              BookInfoIconButton({ icon: 'more', onSelect: () => this.onUnavailableAction('书籍更多操作尚未迁移') })
            }.width('100%').padding({ left: 16, right: 16, top: 8, bottom: 18 })

            Row() {
              BookCover({ book: this.book })
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
              BookInfoTag({ label: this.book.groupName ?? (this.book.isLocal ? '本地未分组' : '书架') })
              BookInfoTag({ label: this.getFormatLabel() })
              if (this.fileSizeLabel.length > 0) { BookInfoTag({ label: this.fileSizeLabel }) }
            }.width('100%').padding({ left: 18, right: 18, bottom: 20 })
            }.width('100%').backgroundColor('#55343845')
          }.width('100%').backgroundColor(this.book.coverColor)

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
          }.width('100%').alignItems(HorizontalAlign.Start).padding(18)
            .backgroundColor('#1B1C22').borderRadius(18).margin({ left: 16, right: 16, bottom: 24 })
        }.width('100%').padding({ bottom: 12 })
      }.layoutWeight(1).scrollBar(BarState.Off)

      Row() {
        Blank()
        Row() {
          AppGlyph({ name: 'book', glyphSize: 17, tint: '#F2F2F7' })
          Text(this.book.bodyMissing === true ? '缺少正文' : '阅读')
            .fontSize(14).fontWeight(FontWeight.Medium).fontColor('#F2F2F7').margin({ left: 7 })
        }.justifyContent(FlexAlign.Center).width(104).padding({ top: 13, bottom: 13 })
          .backgroundColor('#46476B').borderRadius(26).onClick(() => this.onRead())
      }.width('100%').justifyContent(FlexAlign.End).padding({ left: 20, right: 20, top: 8, bottom: 12 })
    }.width('100%').height('100%').backgroundColor('#111217')
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
