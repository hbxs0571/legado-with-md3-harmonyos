import { Book } from '../model/Book';
import { BookGroup } from '../model/BookGroup';
import { BookCover } from '../components/BookCover';
import { AppGlyph } from '../components/AppGlyph';

@Component
export struct SearchPage {
  @Prop books: Book[] = [];
  @Prop groups: BookGroup[] = [];
  @Prop query: string = '';
  @Prop selectedGroup: string = '全部书籍';
  @Prop sourceScope: boolean = false;
  @Prop exactMatch: boolean = false;
  @State showScopePanel: boolean = false;
  @State collapsedHeader: boolean = false;
  private suggestionScroller: Scroller = new Scroller();
  private resultsScroller: Scroller = new Scroller();
  onBack: () => void = () => {};
  onOpenBook: (book: Book) => void = (_book: Book) => {};
  onOpenSourceManage: () => void = () => {};
  onUnavailableAction: (message: string) => void = (_message: string) => {};
  onQueryChange: (query: string) => void = (_query: string) => {};
  onGroupChange: (group: string) => void = (_group: string) => {};
  onSourceScopeChange: (enabled: boolean) => void = (_enabled: boolean) => {};
  onExactMatchChange: (enabled: boolean) => void = (_enabled: boolean) => {};

  private getLocalBooks(): Book[] {
    return this.books.filter((book: Book) => book.contentPath !== undefined || book.bodyMissing === true);
  }

  private getBookGroupNames(book: Book): string[] {
    if ((book.groupNames ?? []).length > 0) { return book.groupNames ?? []; }
    const legacyName = book.groupName?.trim() ?? '';
    return legacyName.length > 0 && legacyName !== '本地未分组' ? [legacyName] : [];
  }

  private getGroups(): string[] {
    const localBooks = this.getLocalBooks();
    const groups: string[] = ['全部书籍'];
    if (localBooks.some((book: Book) => this.getBookGroupNames(book).length === 0)) { groups.push('本地未分组'); }
    const userGroups = this.groups.filter((group: BookGroup) => group.groupId > 0);
    userGroups.filter((group: BookGroup) => group.show)
      .sort((left: BookGroup, right: BookGroup) => left.order - right.order)
      .forEach((group: BookGroup) => { if (!groups.includes(group.groupName)) { groups.push(group.groupName); } });
    localBooks.forEach((book: Book) => {
      this.getBookGroupNames(book).forEach((name: string) => {
        const definition = userGroups.find((group: BookGroup) => group.groupName === name);
        if (definition === undefined && !groups.includes(name)) { groups.push(name); }
      });
    });
    return groups;
  }

  private getResults(): Book[] {
    const keyword = this.query.trim().toLocaleLowerCase();
    if (keyword.length === 0 || this.sourceScope) { return []; }
    return this.getLocalBooks().filter((book: Book) => {
      const names = this.getBookGroupNames(book);
      const matchesGroup = this.selectedGroup === '全部书籍' ||
        (this.selectedGroup === '本地未分组' ? names.length === 0 : names.includes(this.selectedGroup));
      const title = book.title.toLocaleLowerCase();
      const author = book.author.toLocaleLowerCase();
      const matchesKeyword = this.exactMatch
        ? title === keyword || author === keyword
        : title.includes(keyword) || author.includes(keyword);
      return matchesGroup && matchesKeyword;
    });
  }

  private searchOnline(): void {
    if (this.query.trim().length === 0) {
      this.onUnavailableAction('请输入书名或作者');
      return;
    }
    this.onUnavailableAction('在线书源搜索将在 P5 接入；当前仅搜索已导入的本地书籍');
  }

  private updateHeader(offset: number): void {
    const shouldCollapse = offset > 70 ? true : offset < 24 ? false : this.collapsedHeader;
    if (shouldCollapse !== this.collapsedHeader) {
      animateTo({ duration: 220, curve: Curve.EaseInOut }, () => this.collapsedHeader = shouldCollapse);
    }
  }

  build() {
    Stack() {
      Column() {
        Column() {
          Row() {
            Image($r('app.media.reader_back')).width(20).height(20).fillColor('#E3E4E8')
              .width(40).height(40).onClick(() => this.onBack())
            Text('搜索').fontSize(22).fontWeight(FontWeight.Medium).fontColor('#E3E4E8')
              .opacity(this.collapsedHeader ? 1 : 0)
            Blank()
            Stack({ alignContent: Alignment.Center }) {
              AppGlyph({ name: 'settings', glyphSize: 20, tint: '#D8D9E0' })
            }.width(36).height(36).backgroundColor('#1C1D23').borderRadius(18)
              .onClick(() => this.onUnavailableAction('搜索设置将在在线书源搜索接入后提供'))
            Stack({ alignContent: Alignment.Center }) {
              AppGlyph({ name: this.exactMatch ? 'searchPrecisionOn' : 'searchPrecisionOff', glyphSize: 20,
                tint: this.exactMatch ? '#AFC2FF' : '#D8D9E0' })
            }.width(36).height(36).backgroundColor('#1C1D23').borderRadius(18).margin({ left: 8 })
              .onClick(() => this.onExactMatchChange(!this.exactMatch))
            Stack({ alignContent: Alignment.Center }) {
              AppGlyph({ name: 'profileFilterAlt', glyphSize: 20,
                tint: this.sourceScope || this.selectedGroup !== '全部书籍' ? '#AFC2FF' : '#D8D9E0' })
            }.width(36).height(36).backgroundColor('#1C1D23').borderRadius(18).margin({ left: 8 })
              .onClick(() => this.showScopePanel = true)
          }.width('100%').height(64).padding({ left: 12, right: 12 })
          Text('搜索').fontSize(28).fontWeight(FontWeight.Medium).fontColor('#E3E4E8')
            .width('100%').height(72).padding({ left: 16, bottom: 14 })
            .opacity(this.collapsedHeader ? 0 : 1)
        }.width('100%').height(this.collapsedHeader ? 64 : 136).clip(true)

        Row() {
          AppGlyph({ name: 'search', glyphSize: 19, tint: '#C5C7D0' }).margin({ right: 9 })
          TextInput({ placeholder: '搜索书名、作者或书源…', text: this.query })
            .fontSize(17).fontColor('#E3E4E8').placeholderColor('#92949E')
            .backgroundColor(Color.Transparent).layoutWeight(1)
            .onChange((value: string) => { this.collapsedHeader = false; this.onQueryChange(value); })
          if (this.query.length > 0) {
            Text('清除').fontSize(14).fontColor('#AFC2FF').margin({ left: 8 })
              .onClick(() => this.onQueryChange(''))
          }
        }.width('100%').padding({ left: 14, right: 14, top: 11, bottom: 11 })
          .margin({ left: 16, right: 16, top: 7, bottom: 8 })
          .backgroundColor('#1B1C22').borderRadius(24)

        if (this.query.trim().length === 0) {
          Scroll(this.suggestionScroller) {
            Column() {
              Row() {
                Text('书架').fontSize(18).fontWeight(FontWeight.Medium).fontColor('#D8D9E0').layoutWeight(1)
                Text('本地').fontSize(13).fontColor('#92949E')
              }.padding({ left: 18, right: 18, top: 12, bottom: 8 })
              if (this.getLocalBooks().length === 0) {
                SearchEmptyState({ title: '书架暂无书籍', detail: '导入 TXT 或 EPUB 后，可在此搜索书名和作者。' })
              } else {
                ForEach(this.getLocalBooks(), (book: Book) => {
                  SearchBookRow({ book: book, onSelect: () => this.onOpenBook(book) })
                }, (book: Book) => book.id)
              }
              Row() {
                Text('搜索历史').fontSize(18).fontWeight(FontWeight.Medium).fontColor('#D8D9E0').layoutWeight(1)
              }.padding({ left: 18, right: 18, top: 18, bottom: 8 })
              SearchEmptyState({ title: '暂无搜索历史', detail: '在线搜索记录将在搜索能力接入后显示。' })
            }.padding({ bottom: 18 })
          }.layoutWeight(1).scrollBar(BarState.Off)
            .onScroll(() => this.updateHeader(this.suggestionScroller.currentOffset().yOffset))
        } else if (this.sourceScope) {
          Column() {
            SearchEmptyState({ title: '在线书源搜索尚未接入', detail: '搜索范围、书源选择和在线结果将在 P5 接入。当前没有伪造搜索结果。' })
            Row() {
              Text('管理书源').fontSize(16).fontColor('#151720').fontWeight(FontWeight.Medium)
            }.justifyContent(FlexAlign.Center).padding({ left: 22, right: 22, top: 13, bottom: 13 })
              .backgroundColor('#B9C8FF').borderRadius(24).margin({ bottom: 18 })
              .onClick(() => this.onOpenSourceManage())
          }.layoutWeight(1).width('100%').justifyContent(FlexAlign.Center)
        } else {
          if (this.getResults().length === 0) {
            Column() {
              SearchEmptyState({ title: '本地书架没有匹配结果', detail: '可调整书名或作者，在线书源搜索将在 P5 接入。' })
              Row() {
                Text('搜索在线书源').fontSize(16).fontColor('#151720').fontWeight(FontWeight.Medium)
              }.justifyContent(FlexAlign.Center).padding({ left: 22, right: 22, top: 13, bottom: 13 })
                .backgroundColor('#B9C8FF').borderRadius(24).margin({ bottom: 18 })
                .onClick(() => this.searchOnline())
            }.layoutWeight(1).width('100%').justifyContent(FlexAlign.Center)
          } else {
            Column() {
              Row() {
                Text(`本地书籍 · ${this.getResults().length}`).fontSize(16).fontColor('#AFC2FF')
                Blank()
                Text('点按继续阅读').fontSize(13).fontColor('#92949E')
              }.width('100%').padding({ left: 18, right: 18, top: 7, bottom: 8 })
              Scroll(this.resultsScroller) {
                Column() {
                  ForEach(this.getResults(), (book: Book) => {
                    SearchBookRow({ book: book, onSelect: () => this.onOpenBook(book) })
                  }, (book: Book) => book.id)
                }.padding({ bottom: 12 })
              }.layoutWeight(1).scrollBar(BarState.Off)
                .onScroll(() => this.updateHeader(this.resultsScroller.currentOffset().yOffset))
              Row() {
                Text('搜索在线书源').fontSize(16).fontColor('#151720').fontWeight(FontWeight.Medium)
              }.justifyContent(FlexAlign.Center).padding({ left: 22, right: 22, top: 13, bottom: 13 })
                .backgroundColor('#B9C8FF').borderRadius(24).margin({ bottom: 18 })
                .onClick(() => this.searchOnline())
            }.layoutWeight(1)
          }
        }
      }.width('100%').height('100%').backgroundColor('#111217')

      if (this.showScopePanel) {
        SearchScopePanel({
          groups: this.getGroups(),
          selectedGroup: this.selectedGroup,
          sourceScope: this.sourceScope,
          onClose: () => this.showScopePanel = false,
          onGroupSelect: (group: string) => {
            this.onGroupChange(group);
            this.onSourceScopeChange(false);
            this.showScopePanel = false;
          },
          onSelectSources: () => {
            this.onSourceScopeChange(true);
            this.showScopePanel = false;
          },
          onOpenSourceManage: () => {
            this.showScopePanel = false;
            this.onOpenSourceManage();
          }
        }).transition(TransitionEffect.OPACITY.animation({ duration: 220, curve: Curve.EaseInOut }))
      }
    }.width('100%').height('100%').backgroundColor('#111217')
  }
}

@Component
struct SearchBookRow {
  @Prop book: Book = {
    id: '', title: '', author: '', category: '', lastChapter: '', progress: 0,
    coverColor: '#39424B', coverMark: '书', isLocal: true
  };
  onSelect: () => void = () => {};
  build() {
    Row() {
      BookCover({ book: this.book, compact: true })
      Column() {
        Text(this.book.title).fontSize(17).fontColor('#E3E4E8').maxLines(1)
        Text(this.book.author).fontSize(14).fontColor('#AEB0BA').margin({ top: 5 }).maxLines(1)
        Text(this.book.lastChapter).fontSize(13).fontColor('#858792').margin({ top: 6 }).maxLines(1)
      }.alignItems(HorizontalAlign.Start).layoutWeight(1).margin({ left: 14 })
      Text(`${Math.round(this.book.progress)}%`).fontSize(13).fontColor('#D8D9E0')
    }.width('100%').padding(12).backgroundColor('#1C1D23').borderRadius(14)
      .margin({ left: 16, right: 16, bottom: 9 }).onClick(() => this.onSelect())
  }
}

@Component
struct SearchEmptyState {
  @Prop title: string = '';
  @Prop detail: string = '';
  build() {
    Column() {
      AppGlyph({ name: 'search', glyphSize: 30, tint: '#AFC2FF' }).margin({ bottom: 14 })
      Text(this.title).fontSize(17).fontColor('#D8D9E0')
      Text(this.detail).fontSize(14).fontColor('#92949E').textAlign(TextAlign.Center)
        .margin({ left: 28, right: 28, top: 8 })
    }.width('100%').padding({ top: 34, bottom: 34 })
      .justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
  }
}

@Component
struct SearchScopePanel {
  @Prop groups: string[] = [];
  @Prop selectedGroup: string = '全部书籍';
  @Prop sourceScope: boolean = false;
  onClose: () => void = () => {};
  onGroupSelect: (group: string) => void = (_group: string) => {};
  onSelectSources: () => void = () => {};
  onOpenSourceManage: () => void = () => {};
  @State sourceTab: boolean = false;
  aboutToAppear(): void {
    this.sourceTab = this.sourceScope;
  }
  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      Column().width('100%').height('100%').backgroundColor('#99000000').onClick(() => this.onClose())
      Column() {
        Row() {
          Text('搜索范围').fontSize(20).fontWeight(FontWeight.Bold).fontColor('#E3E4E8').layoutWeight(1)
          Text('完成').fontSize(15).fontColor('#AFC2FF').onClick(() => this.onClose())
        }.width('100%').padding({ left: 20, right: 20, top: 20, bottom: 14 })
        Row() {
          SearchScopeTab({ title: '书架分组', selected: !this.sourceTab, onSelect: () => this.sourceTab = false })
          SearchScopeTab({ title: '书源', selected: this.sourceTab, onSelect: () => this.sourceTab = true })
        }.padding({ left: 16, right: 16, bottom: 12 })
        if (!this.sourceTab) {
          List() {
            ForEach(this.groups, (group: string) => {
              ListItem() {
                Row() {
                  Text(group).fontSize(17).fontColor('#D8D9E0').layoutWeight(1)
                  if (group === this.selectedGroup && !this.sourceScope) {
                    AppGlyph({ name: 'profileCheck', glyphSize: 18, tint: '#AFC2FF' })
                  }
                }.width('100%').padding({ left: 18, right: 18, top: 15, bottom: 15 })
                  .backgroundColor('#1A1B21').borderRadius(12).margin({ left: 14, right: 14, bottom: 6 })
                  .onClick(() => this.onGroupSelect(group))
              }
            }, (group: string) => group)
          }.height(260).scrollBar(BarState.Off)
        } else {
          Column() {
            SearchEmptyState({ title: '尚无可选书源', detail: '书源搜索将在 P5 接入。可以先打开书源管理页面。' })
            Row() {
              Text('选择全部书源').fontSize(16).fontColor('#151720').fontWeight(FontWeight.Medium)
            }.justifyContent(FlexAlign.Center).padding({ left: 22, right: 22, top: 13, bottom: 13 })
              .backgroundColor('#B9C8FF').borderRadius(24).margin({ bottom: 10 })
              .onClick(() => this.onSelectSources())
            Row() {
              Text('管理书源').fontSize(16).fontColor('#151720').fontWeight(FontWeight.Medium)
            }.justifyContent(FlexAlign.Center).padding({ left: 22, right: 22, top: 13, bottom: 13 })
              .backgroundColor('#B9C8FF').borderRadius(24).margin({ bottom: 18 })
              .onClick(() => this.onOpenSourceManage())
          }.layoutWeight(1).width('100%').justifyContent(FlexAlign.Center)
        }
      }.width('100%').height('58%').backgroundColor('#17181E')
        .borderRadius({ topLeft: 24, topRight: 24 })
    }.width('100%').height('100%')
  }
}

@Component
struct SearchScopeTab {
  @Prop title: string = '';
  @Prop selected: boolean = false;
  onSelect: () => void = () => {};
  build() {
    Text(this.title).fontSize(15).fontColor(this.selected ? '#E3E4E8' : '#AEB0BA')
      .textAlign(TextAlign.Center).layoutWeight(1).padding({ top: 11, bottom: 11 })
      .backgroundColor(this.selected ? '#41485D' : '#1B1C22').borderRadius(20).margin({ right: 8 })
      .onClick(() => this.onSelect())
  }
}
