import { Book } from '../model/Book';
import { BookCover } from './BookCover';

@Component
export struct BookCard {
  @Prop book: Book = {
    id: '', title: '', author: '', category: '', lastChapter: '', progress: 0,
    coverColor: '#52634E', coverMark: '书', isLocal: true
  };
  onOpen: (book: Book) => void = () => {};

  build() {
    Column() {
      Stack({ alignContent: Alignment.BottomStart }) {
        BookCover({ book: this.book })
        if (this.book.isLocal) {
          Text('本地')
            .fontSize(9)
            .fontColor('#4E5847')
            .padding({ left: 6, right: 6, top: 3, bottom: 3 })
            .backgroundColor('#F3EEDC')
            .borderRadius(5)
            .margin(5)
        }
      }
      .onClick(() => this.onOpen(this.book))
      Text(this.book.title)
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor('#302F29')
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .margin({ top: 10 })
      Text(this.book.lastChapter)
        .fontSize(11)
        .fontColor('#838178')
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .margin({ top: 5 })
      Progress({ value: Math.max(0, Math.min(100, this.book.progress)), total: 100, type: ProgressType.Linear })
        .height(3)
        .color('#68745E')
        .backgroundColor('#E4E0D7')
        .margin({ top: 9 })
    }
    .alignItems(HorizontalAlign.Start)
    .padding(12)
    .backgroundColor('#FFFEFB')
    .borderRadius(16)
    .onClick(() => this.onOpen(this.book))
  }
}

