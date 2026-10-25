import { Book } from '../model/Book';
import { ReaderBookmark } from '../model/ReaderBookmark';
import { BookCover } from '../components/BookCover';
import { AppGlyph } from '../components/AppGlyph';

interface CatalogChapter {
  title: string;
  index: number;
}

@Component
export struct CatalogPage {
  @Prop book: Book = {
    id: '', title: '', author: '', category: '', lastChapter: '', progress: 0,
    coverColor: '#343845', coverMark: '书', isLocal: true
  };
  @Prop selectedChapter: string = '';
  @Prop bookmarks: ReaderBookmark[] = [];
  @State ascending: boolean = true;
  @State selectedTab: number = 1;
  @State query: string = '';
  onBack: () => void = () => {};
  onSelectChapter: (chapterIndex: number) => void = () => {};
  onOpenBookmark: (bookmarkId: string) => void = (_bookmarkId: string) => {};
  onEditBookmark: (bookmarkId: string) => void = (_bookmarkId: string) => {};

  private getAllChapters(): string[] {
    if (this.book.chapterTitles !== undefined && this.book.chapterTitles.length > 0) {
      return this.book.chapterTitles;
    }
    return [];
  }

  private getChapters(): CatalogChapter[] {
    const keyword = this.query.trim();
    const allChapters = this.getAllChapters();
    const chapters: CatalogChapter[] = [];
    for (let index = 0; index < allChapters.length; index++) {
      const title = allChapters[index];
      if (title.includes(keyword)) {
        chapters.push({ title: title, index: index });
      }
    }
    if (this.ascending) {
      return chapters;
    }
    const reversed: CatalogChapter[] = [];
    for (let index = chapters.length - 1; index >= 0; index--) {
      reversed.push(chapters[index]);
    }
    return reversed;
  }

  private isChapterSelected(chapterIndex: number): boolean {
    const selectedIndex = this.book.chapterIndex ?? this.getAllChapters().indexOf(this.selectedChapter);
    return chapterIndex === selectedIndex;
  }

  private getTabLabel(index: number): string {
    if (index === 0) { return '信息'; }
    if (index === 1) { return '目录'; }
    if (index === 2) { return '书签'; }
    return '笔记';
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      Column().width('100%').height('100%').backgroundColor('#99000000').onClick(() => this.onBack())
      Column() {
        Row().width(32).height(4).backgroundColor('#C6C7CE').borderRadius(4).margin({ top: 9, bottom: 16 })
          .onClick(() => this.onBack())
        Row() {
          BookCover({ book: this.book, mini: true })
          Column() {
            Text(this.book.title).fontSize(13).fontColor('#ECEEF2').maxLines(1)
            Text(this.book.lastChapter).fontSize(10).fontColor('#AEB0B9').margin({ top: 4 }).maxLines(1)
          }.alignItems(HorizontalAlign.Start).layoutWeight(1).margin({ left: 12 })
          Text(`${this.getAllChapters().indexOf(this.selectedChapter) + 1} / ${this.getAllChapters().length}`)
            .fontSize(10).fontColor('#ECEEF2').padding({ left: 9, right: 9, top: 6, bottom: 6 })
            .backgroundColor('#101116').borderRadius(14)
        }.width('100%').padding({ left: 14, right: 14, bottom: 12 })

        Row() {
          ForEach([0, 1, 2, 3], (index: number) => {
            Text(this.getTabLabel(index))
              .fontSize(11).fontColor(this.selectedTab === index ? '#F0F1F5' : '#B0B2BC')
              .textAlign(TextAlign.Center).layoutWeight(1).padding({ top: 8, bottom: 8 })
              .backgroundColor(this.selectedTab === index ? '#454B62' : '#1C1D23').borderRadius(12)
              .margin({ left: index === 0 ? 12 : 4, right: index === 3 ? 12 : 4 })
              .onClick(() => this.selectedTab = index)
          }, (index: number) => index.toString())
        }.width('100%').margin({ bottom: 10 })

        if (this.selectedTab === 1) {
          Row() {
            TextInput({ placeholder: '⌕ 搜索章节…', text: this.query })
              .fontSize(12).fontColor('#E1E2E8').placeholderColor('#A0A2AB')
              .backgroundColor('#1A1B21').layoutWeight(1).borderRadius(12)
              .onChange((value: string) => this.query = value)
            Image($r('app.media.app_refresh')).width(17).height(17).fillColor('#D8D9E0').width(35)
              .onClick(() => this.query = '')
            Text('#').fontSize(15).fontColor('#ECEEF2').width(35).textAlign(TextAlign.Center)
              .backgroundColor('#454B62').borderRadius(10).onClick(() => this.ascending = !this.ascending)
            Image($r('app.media.app_sort')).width(17).height(17).fillColor('#D8D9E0').width(32)
              .onClick(() => this.ascending = !this.ascending)
            AppGlyph({ name: 'more', glyphSize: 18, tint: '#D8D9E0' }).width(26)
              .onClick(() => this.ascending = !this.ascending)
          }.padding({ left: 12, right: 12, bottom: 8 })
          Row() {
            Text(this.ascending ? '正序' : '倒序').fontSize(10).fontColor('#AEB0B9')
            Blank()
            Text(`共 ${this.getAllChapters().length} 章`).fontSize(10).fontColor('#AEB0B9')
          }.padding({ left: 16, right: 16, bottom: 7 })
          Scroll() {
            Column() {
              ForEach(this.getChapters(), (chapter: CatalogChapter) => {
                Row() {
                  Text(chapter.title).fontSize(12)
                    .fontColor(this.isChapterSelected(chapter.index) ? '#F0F1F5' : '#D4D5DB')
                    .layoutWeight(1).maxLines(1)
                  if (this.isChapterSelected(chapter.index)) {
                    Image($r('app.media.app_locate')).width(16).height(16).fillColor('#C4D1FF')
                  }
                }.width('100%').padding({ left: 12, right: 12, top: 11, bottom: 11 })
                  .backgroundColor(this.isChapterSelected(chapter.index) ? '#454B62' : '#1A1B21')
                  .borderRadius(10).onClick(() => this.onSelectChapter(chapter.index))
              }, (chapter: CatalogChapter) => chapter.index.toString())
            }.padding({ left: 12, right: 12, bottom: 14 })
          }.layoutWeight(1).scrollBar(BarState.Off)
        } else if (this.selectedTab === 2) {
          if (this.bookmarks.length === 0) {
            Column() {
              AppGlyph({ name: 'bookmark', glyphSize: 30, tint: '#AFC2FF' })
              Text('暂无书签').fontSize(14).fontColor('#AEB0B9').margin({ top: 8 })
            }.width('100%').layoutWeight(1).justifyContent(FlexAlign.Center)
          } else {
            Scroll() {
              Column() {
                ForEach(this.bookmarks, (bookmark: ReaderBookmark) => {
                  Column() {
                    Row() {
                      Text(bookmark.chapterName).fontSize(13).fontColor('#AFC2FF')
                        .layoutWeight(1).maxLines(1)
                      Text('跳转').fontSize(11).fontColor('#D7DFFB')
                        .padding({ left: 10, right: 10, top: 6, bottom: 6 })
                        .backgroundColor('#454B62').borderRadius(14)
                        .onClick(() => this.onOpenBookmark(bookmark.id))
                      Text('编辑').fontSize(11).fontColor('#C5C7D0')
                        .padding({ left: 10, right: 10, top: 6, bottom: 6 })
                        .margin({ left: 6 }).backgroundColor('#292A31').borderRadius(14)
                        .onClick(() => this.onEditBookmark(bookmark.id))
                    }
                    if (bookmark.bookText.length > 0) {
                      Text(bookmark.bookText).fontSize(12).fontColor('#D4D5DB')
                        .maxLines(3).margin({ top: 7 }).textOverflow({ overflow: TextOverflow.Ellipsis })
                    }
                    if (bookmark.content.length > 0) {
                      Text(bookmark.content).fontSize(11).fontColor('#AEB0B9')
                        .maxLines(2).margin({ top: 5 }).textOverflow({ overflow: TextOverflow.Ellipsis })
                    }
                  }.width('100%').padding(12).backgroundColor('#1A1B21').borderRadius(10)
                    .margin({ bottom: 6 })
                }, (bookmark: ReaderBookmark) => bookmark.id)
              }.padding({ left: 12, right: 12, bottom: 14 })
            }.layoutWeight(1).scrollBar(BarState.Off)
          }
        } else {
          Column() {
            Text(this.getTabLabel(this.selectedTab)).fontSize(17).fontColor('#E4E5EA')
            Text(this.selectedTab === 0 ? this.book.author + ' · ' + this.book.category : '笔记尚未迁移')
              .fontSize(11).fontColor('#9A9CA6').margin({ top: 8 })
          }.width('100%').layoutWeight(1).justifyContent(FlexAlign.Center)
        }
      }
      .width('100%')
      .height('84%')
      .backgroundColor('#17181E')
      .borderRadius(22)
    }
    .width('100%')
    .height('100%')
  }
}
