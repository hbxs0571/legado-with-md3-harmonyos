import { Book } from '../model/Book';
import { BookCover } from '../components/BookCover';
import { AppGlyph } from '../components/AppGlyph';

@Component
export struct BookshelfPage {
  @Prop books: Book[] = [];
  @State selectedFilter: number = 0;
  @State showSearch: boolean = false;
  @State searchQuery: string = '';
  @State collapsedHeader: boolean = false;
  @State emptyFace: string = '(；′⌒`)';
  private readonly bookshelfScroller: Scroller = new Scroller();
  private readonly emptyFaces: string[] = ['(；′⌒`)', '(つ﹏⊂)', '(•̀ᴗ•́)و', '(๑•́ ₃ •̀๑)', '(눈‸눈)', '(ಥ﹏ಥ)', '(｡•́︿•̀｡)'];
  private readonly defaultGroupNames: string[] = ['本地未分组', '未观', '静候', '完结', '已阅'];
  onOpenBook: (book: Book) => void = () => {};
  onOpenBookInfo: (book: Book) => void = () => {};
  onSearch: () => void = () => {};
  onImportBook: () => Promise<Book | undefined> = async () => undefined;
  onUnavailableAction: (message: string) => void = (_message: string) => {};

  private getGroupNames(): string[] {
    return this.books.length === 0 ? ['全部'] : this.defaultGroupNames;
  }

  private getVisibleBooks(): Book[] {
    const groupNames = this.getGroupNames();
    const selectedGroup = groupNames[this.selectedFilter] ?? groupNames[0] ?? '全部';
    const query = this.searchQuery.trim().toLocaleLowerCase();
    return this.books.filter((book: Book) => {
      const groupName = book.groupName ?? (book.isLocal ? '本地未分组' : '完结');
      const matchesGroup = selectedGroup === '全部' || groupName === selectedGroup;
      const matchesQuery = query.length === 0 || book.title.toLocaleLowerCase().includes(query) ||
        book.author.toLocaleLowerCase().includes(query);
      return matchesGroup && matchesQuery;
    });
  }

  @Builder
  private MoreMenu() {
    Menu() {
      MenuItem({ startIcon: $r('app.media.menu_wifi'), content: '远程书籍' }).height(48)
        .onClick(() => this.onUnavailableAction('远程书籍导入尚未迁移'))
      MenuItem({ startIcon: $r('app.media.menu_save'), content: '添加本地' }).height(48)
        .onClick(async () => {
          const imported = await this.onImportBook();
          if (imported !== undefined) { this.selectedFilter = 0; }
        })
      MenuItem({ startIcon: $r('app.media.app_refresh'), content: '更新目录' }).height(48)
        .onClick(() => this.onUnavailableAction('批量更新目录尚未迁移'))
      MenuItem({ startIcon: $r('app.media.menu_grid'), content: '布局设置' }).height(48)
        .onClick(() => this.onUnavailableAction('书架布局设置尚未迁移'))
      MenuItem({ startIcon: $r('app.media.menu_carousel'), content: '分组管理' }).height(48)
        .onClick(() => this.onUnavailableAction('书架分组管理尚未迁移'))
      MenuItem({ startIcon: $r('app.media.menu_link'), content: '添加网址' }).height(48)
        .onClick(() => this.onUnavailableAction('网址导入尚未迁移'))
      MenuItem({ startIcon: $r('app.media.app_pencil'), content: '选择模式' }).height(48)
        .onClick(() => this.onUnavailableAction('书架选择模式尚未迁移'))
      MenuItem({ startIcon: $r('app.media.menu_bookmarks'), content: '书架管理' }).height(48)
        .onClick(() => this.onUnavailableAction('书架管理尚未迁移'))
      MenuItem({ startIcon: $r('app.media.menu_upload_file'), content: '导出书单' }).height(48)
        .onClick(() => this.onUnavailableAction('书单导出尚未迁移'))
      MenuItem({ startIcon: $r('app.media.app_cloud_download'), content: '导入书单' }).height(48)
        .onClick(() => this.onUnavailableAction('书单导入尚未迁移'))
      MenuItem({ startIcon: $r('app.media.profile_history'), content: '日志' }).height(48)
        .onClick(() => this.onUnavailableAction('日志界面尚未迁移'))
    }.backgroundColor('#1C1D23').fontColor('#E3E4E8').radius(20)
  }

  build() {
    Column() {
      Row() {
        if (this.collapsedHeader) {
          Text('书架').fontSize(20).fontWeight(FontWeight.Medium).fontColor('#E3E4E8')
        }
        Blank()
        Stack({ alignContent: Alignment.Center }) { AppGlyph({ name: 'search', glyphSize: 20 }) }.width(36).height(36).backgroundColor('#1C1D23').borderRadius(20)
          .onClick(() => {
            this.showSearch = !this.showSearch;
            if (!this.showSearch) { this.searchQuery = ''; }
          })
        Stack({ alignContent: Alignment.Center }) { AppGlyph({ name: 'more', glyphSize: 20 }) }
          .width(36).height(36).backgroundColor('#1C1D23').borderRadius(20).margin({ left: 8 })
          .bindMenu(this.MoreMenu, { placement: Placement.BottomRight })
      }.width('100%').height(56).padding({ left: 16, right: 16, top: 10, bottom: 0 })
      Row() {
        Text('书架').fontSize(28).fontWeight(FontWeight.Bold).fontColor('#E3E4E8')
      }.width('100%').height(this.collapsedHeader ? 0 : 58)
        .padding({ left: 16, right: 16, bottom: this.collapsedHeader ? 0 : 18 })
        .opacity(this.collapsedHeader ? 0 : 1)
        .animation({ duration: 220, curve: Curve.EaseInOut })

      if (this.showSearch) {
        Row() {
          AppGlyph({ name: 'search', glyphSize: 17 }).margin({ right: 9 })
          TextInput({ placeholder: '搜索书名或作者…', text: this.searchQuery })
            .fontSize(16).fontColor('#D8D9E0').placeholderColor('#92949E')
            .backgroundColor(Color.Transparent).layoutWeight(1)
            .onChange((value: string) => this.searchQuery = value)
        }.width('100%').padding({ left: 14, right: 14, top: 9, bottom: 9 })
          .margin({ left: 16, right: 16, bottom: 10 }).backgroundColor('#1C1D23').borderRadius(22)
      }

      Row() {
        ForEach(this.getGroupNames(), (groupName: string, index: number) => {
          ShelfFilter({ label: groupName, selected: this.selectedFilter === index })
            .onClick(() => this.selectedFilter = index)
        }, (groupName: string) => groupName)
      }.width('100%').padding({ left: 12, right: 12, bottom: 14 })
      if (this.getVisibleBooks().length > 0) {
        Grid(this.bookshelfScroller) {
          ForEach(this.getVisibleBooks(), (book: Book) => {
            GridItem() {
              Column() {
                BookCover({ book: book, compact: true, showChapterBadge: true })
                Text(book.title).fontSize(13).fontColor('#D8D9E0').maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis }).margin({ top: 7 })
              }.width('100%').alignItems(HorizontalAlign.Start)
                .onClick(() => {
                  if (book.bodyMissing === true) {
                    this.onOpenBookInfo(book);
                  } else {
                    this.onOpenBook(book);
                  }
                })
                .priorityGesture(LongPressGesture({ duration: 500 }).onAction((_event: GestureEvent): void => {
                  this.onOpenBookInfo(book);
                }))
            }
          }, (book: Book) => book.id)
        }.columnsTemplate('1fr 1fr 1fr').rowsGap(16).columnsGap(10).width('100%').padding({ left: 14, right: 14 }).layoutWeight(1).scrollBar(BarState.Off)
          .onScroll(() => {
            const shouldCollapse = Math.abs(this.bookshelfScroller.currentOffset().yOffset) > 60;
            if (this.collapsedHeader !== shouldCollapse) {
              animateTo({ duration: 220, curve: Curve.EaseInOut }, () => {
                this.collapsedHeader = shouldCollapse;
              });
            }
          })
      } else {
        Column() {
          Text(this.emptyFace).fontSize(32).fontColor('#D8D9E0').margin({ bottom: 14 })
            .onClick(() => {
              const currentIndex = this.emptyFaces.indexOf(this.emptyFace);
              this.emptyFace = this.emptyFaces[(currentIndex + 1) % this.emptyFaces.length];
            })
          Text(this.searchQuery.length > 0 ? '没有匹配的书籍' : this.books.length === 0
            ? '书架还空着，先去搜索书籍或从发现里添加吧！' : '这个分组还没有书籍')
            .width(220).fontSize(11).fontColor('#D8D9E0').textAlign(TextAlign.Center).maxLines(2)
        }.layoutWeight(1).width('100%').padding({ bottom: 104 }).justifyContent(FlexAlign.Center)
      }
    }.width('100%').height('100%').backgroundColor('#111217')
  }
}

@Component
struct ShelfFilter {
  @Prop label: string = '';
  @Prop selected: boolean = false;
  build() {
    Column() {
      Text(this.label).fontSize(12).fontColor(this.selected ? '#C4D1FF' : '#B6B8C2').padding({ left: 7, right: 7, top: 7, bottom: 7 })
      Row().width(42).height(2).backgroundColor('#AFC2FF').borderRadius(1)
        .opacity(this.selected ? 1 : 0)
        .animation({ duration: 180, curve: Curve.EaseInOut })
    }.layoutWeight(1).alignItems(HorizontalAlign.Center)
  }
}






