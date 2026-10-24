@Component
export struct ReaderSearchPage {
  @Prop bookTitle: string = '';
  @Prop content: string = '';
  onUnavailableAction: (message: string) => void = (_message: string) => {};
  @State query: string = '';
  onBack: () => void = () => {};

  private getMatches(): string[] {
    const keyword = this.query.trim();
    if (keyword.length === 0) {
      return [];
    }
    const matches: string[] = [];
    const lines = this.content.split(/\r?\n/);
    for (let index = 0; index < lines.length && matches.length < 30; index++) {
      if (lines[index].includes(keyword)) {
        matches.push(lines[index].trim());
      }
    }
    return matches;
  }

  build() {
    Column() {
      Row() {
        Stack({ alignContent: Alignment.Center }) {
          Image($r('app.media.reader_back')).width(22).height(22).fillColor('#E4E5EA')
        }.width(40).height(40).backgroundColor('#1B1C22').borderRadius(22).onClick(() => this.onBack())
        Blank()
        Image($r('app.media.app_refresh')).width(20).height(20).fillColor('#D8D9E0').width(38)
          .onClick(() => this.query = '')
        Image($r('app.media.app_code')).width(18).height(18).fillColor('#D8D9E0').width(42)
          .onClick(() => this.onUnavailableAction('正则搜索尚未接入'))
      }.padding({ left: 16, right: 16, top: 14, bottom: 18 })

      Text('搜索内容').fontSize(23).fontWeight(FontWeight.Bold).fontColor('#E5E6EA')
        .alignSelf(ItemAlign.Start).margin({ left: 18, bottom: 12 })
      Row() {
        AppSearchGlyph()
        TextInput({ placeholder: '搜索…', text: this.query })
          .fontSize(14).fontColor('#E3E4E8').placeholderColor('#8C8E98')
          .backgroundColor(Color.Transparent).layoutWeight(1)
          .onChange((value: string) => this.query = value)
      }.padding({ left: 14, right: 14, top: 7, bottom: 7 }).backgroundColor('#1B1C22').borderRadius(24)
        .margin({ left: 16, right: 16 })

      Row() {
        Text('当前章节 · 最多30条').fontSize(12).fontColor('#AFC2FF')
        Blank()
        Row() {
          Image($r('app.media.app_book')).width(13).height(13).fillColor('#25262C')
          Text('本章').fontSize(11).fontColor('#25262C').margin({ left: 5 })
        }.padding({ left: 10, right: 10, top: 6, bottom: 6 })
          .backgroundColor('#F0F1F5').borderRadius(16)
      }.padding({ left: 18, right: 18, top: 13, bottom: 8 })

      if (this.query.trim().length === 0) {
        Column() {
          Text('(つ﹏⊂)').fontSize(27).fontColor('#E3E4E8')
          Text('输入关键词搜索本章正文').fontSize(11).fontColor('#B4B5BC').margin({ top: 8 })
          Text(this.bookTitle).fontSize(10).fontColor('#747680').margin({ top: 18 })
        }.width('100%').layoutWeight(1).justifyContent(FlexAlign.Center)
      } else if (this.getMatches().length === 0) {
        Column() {
          Text('没有找到匹配内容').fontSize(14).fontColor('#BFC0C8')
          Text(this.bookTitle).fontSize(11).fontColor('#777984').margin({ top: 8 })
        }.width('100%').layoutWeight(1).justifyContent(FlexAlign.Center)
      } else {
        List() {
          ForEach(this.getMatches(), (line: string, index: number) => {
            ListItem() {
              Text(line).fontSize(13).fontColor('#D9DAE0').maxLines(3)
                .width('100%').padding(14).backgroundColor('#1B1C22').borderRadius(12)
            }.margin({ left: 16, right: 16, bottom: 8 })
          }, (line: string, index: number) => `${index}-${line.substring(0, 12)}`)
        }.layoutWeight(1).scrollBar(BarState.Off)
      }
    }.width('100%').height('100%').backgroundColor('#111217')
  }
}

@Component
struct AppSearchGlyph {
  build() {
    Image($r('app.media.reader_search')).width(20).height(20).fillColor('#C9CAD2').width(30)
  }
}
