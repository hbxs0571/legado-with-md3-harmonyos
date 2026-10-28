import { Book } from '../model/Book';
import { AppGlyph } from './AppGlyph';

@Component
export struct BookCover {
  @Prop book: Book = {
    id: '', title: '', author: '', category: '', lastChapter: '', progress: 0,
    coverColor: '#343845', coverMark: '书', isLocal: true
  };
  @Prop compact: boolean = false;
  @Prop mini: boolean = false;
  @Prop displayWidth: number = 0;
  @Prop displayHeight: number = 0;
  @Prop cornerRadius: number = 7;
  @Prop showChapterBadge: boolean = false;
  /** 书封阴影，对应上游 bookshelfCoverShadow。 */
  @Prop shadowEnabled: boolean = false;
  @State imageFailed: boolean = false;

  private hasCoverImage(): boolean {
    return this.book.coverUri !== undefined && this.book.coverUri.length > 0 && !this.imageFailed;
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      if (this.hasCoverImage() && this.book.coverUri !== undefined) {
        Image(this.book.coverUri)
          .width('100%')
          .height('100%')
          .objectFit(ImageFit.Cover)
          .borderRadius(this.cornerRadius)
          .onError(() => this.imageFailed = true)
      }
      Column() {
        if (this.showChapterBadge || this.book.bodyMissing === true) {
          Row() {
            if (this.book.bodyMissing === true) {
              Text('缺正文').fontSize(8).fontColor('#FFE0DC')
                .padding({ left: 4, right: 4, top: 2, bottom: 2 })
                .backgroundColor('#8B3A3A').borderRadius(5)
            }
            Blank()
            if (this.showChapterBadge && this.book.chapterCount !== undefined) {
              Text(this.book.chapterCount)
                .fontSize(8)
                .fontColor('#E6E7EC')
                .padding({ left: 4, right: 4, top: 2, bottom: 2 })
                .backgroundColor('#15161BCC')
                .borderRadius(5)
            }
          }.width('100%').height(14)
        }
        if (!this.hasCoverImage()) {
          Text(this.book.coverMark)
            .fontSize(this.mini ? 21 : this.compact ? 29 : 40)
            .fontWeight(FontWeight.Bold)
            .fontColor('#F1F2F6')
            .width(this.mini ? 36 : this.compact ? 50 : 68)
            .textAlign(TextAlign.Center)
        } else {
          Blank()
        }
        Blank()
        if (this.showChapterBadge) {
          Row() {
            AppGlyph({ name: 'bookmark', tint: '#C4C9D7', glyphSize: 16 })
            Blank()
          }.width('100%').height(16)
        }
      }
      .width('100%')
      .height('100%')
      .padding({ left: 5, right: 5, top: 5, bottom: 5 })
      .alignItems(HorizontalAlign.Center)
      .justifyContent(FlexAlign.SpaceBetween)
    }
    .width(this.displayWidth > 0 ? this.displayWidth : this.mini ? 48 : this.compact ? 70 : 92)
    .height(this.displayHeight > 0 ? this.displayHeight : this.mini ? 68 : this.compact ? 100 : 128)
    .backgroundColor(this.book.coverColor)
    .borderRadius(this.cornerRadius)
    .shadow(this.shadowEnabled
      ? { radius: 6, color: '#66000000', offsetX: 0, offsetY: 2 }
      : { radius: 0, color: Color.Transparent, offsetX: 0, offsetY: 0 })
  }
}
