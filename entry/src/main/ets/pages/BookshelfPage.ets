import { Book } from '../model/Book';
import { BookGroup } from '../model/BookGroup';
import { BookCover } from '../components/BookCover';
import { AppGlyph } from '../components/AppGlyph';

@Component
export struct BookshelfPage {
  @Prop books: Book[] = [];
  @Prop groups: BookGroup[] = [];
  @State selectedFilter: string = '全部';
  @State showGroupManager: boolean = false;
  @State newGroupName: string = '';
  @State editingGroupId: number = -1;
  @State editingGroupName: string = '';
  @State pendingDeleteGroupId: number = -1;
  @State showSearch: boolean = false;
  @State searchQuery: string = '';
  @State collapsedHeader: boolean = false;
  @State emptyFace: string = '(；′⌒`)';
  private readonly bookshelfScroller: Scroller = new Scroller();
  private readonly emptyFaces: string[] = ['(；′⌒`)', '(つ﹏⊂)', '(•̀ᴗ•́)و', '(๑•́ ₃ •̀๑)', '(눈‸눈)', '(ಥ﹏ಥ)', '(｡•́︿•̀｡)'];
  onOpenBook: (book: Book) => void = () => {};
  onOpenBookInfo: (book: Book) => void = () => {};
  onSearch: () => void = () => {};
  onImportBook: () => Promise<Book | undefined> = async () => undefined;
  /** 重新识别全部本地 TXT 的目录。 */
  onRefreshToc: () => Promise<void> = async () => {};
  onAddGroup: (name: string) => void = (_name: string) => {};
  onRenameGroup: (id: number, name: string) => void = (_id: number, _name: string) => {};
  onSetGroupVisible: (id: number, visible: boolean) => void = (_id: number, _visible: boolean) => {};
  onRemoveGroup: (id: number) => void = (_id: number) => {};
  onUnavailableAction: (message: string) => void = (_message: string) => {};

  /** 目录或进度变更后让书架卡片重建，避免 ArkUI 复用旧章节角标。 */
  private bookCardKey(book: Book): string {
    return `${book.id}_${book.chapterCount ?? ''}_${book.chapterIndex ?? 0}_${book.chapterProgress ?? 0}_${book.coverMark ?? ''}_${book.bodyMissing === true ? 1 : 0}`;
  }

  private getGroupNames(): string[] {
    const names: string[] = ['全部'];
    const userGroups = this.groups.filter((group: BookGroup) => group.groupId > 0);
    if (this.books.some((book: Book) => (book.groupNames ?? []).length === 0)) { names.push('本地未分组'); }
    userGroups.filter((group: BookGroup) => group.show)
      .sort((left: BookGroup, right: BookGroup) => left.order - right.order)
      .forEach((group: BookGroup) => {
        if (!names.includes(group.groupName)) { names.push(group.groupName); }
      });
    // 旧数据中的名称若没有分组定义则仍可见；已明确隐藏的分组保持隐藏。
    this.books.forEach((book: Book) => {
      (book.groupNames ?? []).forEach((name: string) => {
        const definition = userGroups.find((group: BookGroup) => group.groupName === name);
        if (name.length > 0 && definition === undefined && !names.includes(name)) { names.push(name); }
      });
    });
    return names;
  }

  private getVisibleBooks(): Book[] {
    const selectedGroup = this.selectedFilter;
    const query = this.searchQuery.trim().toLocaleLowerCase();
    return this.books.filter((book: Book) => {
      const names = book.groupNames ?? [];
      const matchesGroup = selectedGroup === '全部' ||
        (selectedGroup === '本地未分组' ? names.length === 0 : names.includes(selectedGroup));
      const matchesQuery = query.length === 0 || book.title.toLocaleLowerCase().includes(query) ||
        book.author.toLocaleLowerCase().includes(query);
      return matchesGroup && matchesQuery;
    });
  }

  @Builder
  private GroupManagerSheet() {
    Column() {
      Row() {
        Text('分组管理').fontSize(19).fontWeight(FontWeight.Medium).fontColor('#E3E4E8').layoutWeight(1)
        Text('完成').fontSize(14).fontColor('#B9C8FF').padding(8).onClick(() => this.showGroupManager = false)
      }.width('100%').padding({ left: 18, right: 12, top: 14, bottom: 10 })
      Row() {
        TextInput({ text: this.newGroupName, placeholder: '新分组名称' }).layoutWeight(1).height(42)
          .fontSize(14).fontColor('#E3E4E8').placeholderColor('#92949E')
          .backgroundColor('#22232A').borderRadius(10).padding({ left: 12, right: 12 })
          .onChange((value: string) => this.newGroupName = value)
        Text('添加').fontSize(14).fontColor('#B9C8FF').padding({ left: 14, right: 10 })
          .onClick(() => {
            const name = this.newGroupName.trim();
            if (name.length === 0) { this.onUnavailableAction('分组名称不能为空'); return; }
            this.onAddGroup(name);
            this.newGroupName = '';
          })
      }.width('100%').padding({ left: 16, right: 16, bottom: 10 })
      Scroll() {
        Column() {
          ForEach(this.groups.filter((group: BookGroup) => group.groupId > 0), (group: BookGroup) => {
            Row() {
              if (this.editingGroupId === group.groupId) {
                TextInput({ text: this.editingGroupName, placeholder: '分组名称' }).layoutWeight(1).height(40)
                  .fontSize(14).fontColor('#E3E4E8').backgroundColor('#22232A').borderRadius(9)
                  .onChange((value: string) => this.editingGroupName = value)
                Text('保存').fontSize(13).fontColor('#B9C8FF').padding(8).onClick(() => {
                  const name = this.editingGroupName.trim();
                  if (name.length === 0) { this.onUnavailableAction('分组名称不能为空'); return; }
                  this.onRenameGroup(group.groupId, name);
                  if (this.selectedFilter === group.groupName) { this.selectedFilter = name; }
                  this.editingGroupId = -1;
                })
                Text('取消').fontSize(13).fontColor('#92949E').padding(8).onClick(() => this.editingGroupId = -1)
              } else {
                Text(group.groupName).fontSize(14).fontColor('#E3E4E8').layoutWeight(1).maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                Toggle({ type: ToggleType.Switch, isOn: group.show })
                  .onChange((visible: boolean) => {
                    this.onSetGroupVisible(group.groupId, visible);
                    if (!visible && this.selectedFilter === group.groupName) { this.selectedFilter = '全部'; }
                  })
                Text('改名').fontSize(12).fontColor('#B9C8FF').padding(8).onClick(() => {
                  this.editingGroupId = group.groupId; this.editingGroupName = group.groupName;
                })
                Text(this.pendingDeleteGroupId === group.groupId ? '确认删除' : '删除')
                  .fontSize(12).fontColor('#D99AA5').padding(8).onClick(() => {
                    if (this.pendingDeleteGroupId === group.groupId) {
                      this.onRemoveGroup(group.groupId);
                      if (this.selectedFilter === group.groupName) { this.selectedFilter = '全部'; }
                      this.pendingDeleteGroupId = -1;
                    } else { this.pendingDeleteGroupId = group.groupId; }
                  })
                if (this.pendingDeleteGroupId === group.groupId) {
                  Text('取消').fontSize(12).fontColor('#92949E').padding(6)
                    .onClick(() => this.pendingDeleteGroupId = -1)
                }
              }
            }.width('100%').padding({ left: 16, right: 12, top: 8, bottom: 8 })
              .backgroundColor('#1B1C22').borderRadius(12).margin({ bottom: 8 })
          }, (group: BookGroup) => `${group.groupId}`)
          if (this.groups.filter((group: BookGroup) => group.groupId > 0).length === 0) {
            Text('还没有自定义分组').fontSize(13).fontColor('#92949E').padding(18)
          }
        }.width('100%').padding({ left: 16, right: 16, bottom: 18 })
      }.layoutWeight(1).scrollBar(BarState.Off)
    }.width('100%').height('100%').backgroundColor('#17181E')
  }

  @Builder
  private MoreMenu() {
    Menu() {
      MenuItem({ startIcon: $r('app.media.menu_wifi'), content: '远程书籍' }).height(48)
        .onClick(() => this.onUnavailableAction('远程书籍导入尚未迁移'))
      MenuItem({ startIcon: $r('app.media.menu_save'), content: '添加本地' }).height(48)
        .onClick(async () => {
          const imported = await this.onImportBook();
          if (imported !== undefined) { this.selectedFilter = '全部'; }
        })
      MenuItem({ startIcon: $r('app.media.app_refresh'), content: '更新目录' }).height(48)
        .onClick(async () => { await this.onRefreshToc(); })
      MenuItem({ startIcon: $r('app.media.menu_grid'), content: '布局设置' }).height(48)
        .onClick(() => this.onUnavailableAction('书架布局设置尚未迁移'))
      MenuItem({ startIcon: $r('app.media.menu_carousel'), content: '分组管理' }).height(48)
        .onClick(() => this.showGroupManager = true)
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
        ForEach(this.getGroupNames(), (groupName: string) => {
          ShelfFilter({ label: groupName, selected: this.selectedFilter === groupName })
            .onClick(() => this.selectedFilter = groupName)
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
          }, (book: Book) => this.bookCardKey(book))
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
      .bindSheet(this.showGroupManager, this.GroupManagerSheet(), {
        height: SheetSize.LARGE, dragBar: true, showClose: false, backgroundColor: '#17181E'
      })
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






