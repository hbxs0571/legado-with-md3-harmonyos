import { Book } from '../model/Book';
import { BookCover } from '../components/BookCover';
import { AppGlyph } from '../components/AppGlyph';

@Component
export struct CatalogPage {
  @Prop book: Book = {
    id: '', title: '', author: '', category: '', lastChapter: '', progress: 0,
    coverColor: '#343845', coverMark: '书', isLocal: true
  };
  @Prop selectedChapter: string = '';
  @State ascending: boolean = true;
  @State selectedTab: number = 1;
  @State query: string = '';
  onBack: () => void = () => {};
  onSelectChapter: (chapterTitle: string) => void = () => {};

  private getAllChapters(): string[] {
    if (this.book.chapterTitles !== undefined && this.book.chapterTitles.length > 0) {
      return this.book.chapterTitles;
    }
    return [];
  }

  private getChapters(): string[] {
    const keyword = this.query.trim();
    const chapters = this.getAllChapters().filter((title: string) => title.includes(keyword));
    if (this.ascending) {
      return chapters;
    }
    const reversed: string[] = [];
    for (let index = chapters.length - 1; index >= 0; index--) {
      reversed.push(chapters[index]);
    }
    return reversed;
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
              ForEach(this.getChapters(), (chapterTitle: string) => {
                Row() {
                  Text(chapterTitle).fontSize(12).fontColor(chapterTitle === this.selectedChapter ? '#F0F1F5' : '#D4D5DB')
                    .layoutWeight(1).maxLines(1)
                  if (chapterTitle === this.selectedChapter) {
                    Image($r('app.media.app_locate')).width(16).height(16).fillColor('#C4D1FF')
                  }
                }.width('100%').padding({ left: 12, right: 12, top: 11, bottom: 11 })
                  .backgroundColor(chapterTitle === this.selectedChapter ? '#454B62' : '#1A1B21')
                  .borderRadius(10).onClick(() => this.onSelectChapter(chapterTitle))
              }, (chapterTitle: string) => chapterTitle)
            }.padding({ left: 12, right: 12, bottom: 14 })
          }.layoutWeight(1).scrollBar(BarState.Off)
        } else {
          Column() {
            Text(this.getTabLabel(this.selectedTab)).fontSize(17).fontColor('#E4E5EA')
            Text(this.selectedTab === 0 ? `${this.book.author} · ${this.book.category}` : '暂无内容')
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
