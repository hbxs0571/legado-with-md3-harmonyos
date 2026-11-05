import { Book, bookCoverMark } from '../model/Book';
import { BookGroup, BookGroupDraft, BOOK_SORT_OPTIONS, BookSortOption, bookSortLabel } from '../model/BookGroup';
import {
  BookshelfLayoutSettings, BookshelfLayoutOption, DEFAULT_BOOKSHELF_LAYOUT,
  BOOKSHELF_LAYOUT_MODE_OPTIONS, BOOKSHELF_SORT_ORDER_OPTIONS,
  BOOK_GROUP_STYLE_OPTIONS, BOOKSHELF_FOLDER_LAYOUT_MODE_OPTIONS,
  BOOKSHELF_GROUP_LIST_STYLE_OPTIONS,
  bookshelfLayoutOptionLabel, copyBookshelfLayout
} from '../model/BookshelfLayout';
import { BookshelfSort } from '../data/BookshelfSort';
import { CoverSettings, DEFAULT_COVER_SETTINGS } from '../data/CoverSettingsRepository';
import { BookRepository } from '../data/BookRepository';
import { BookCover } from '../components/BookCover';
import { BookGroupCard } from '../components/BookGroupCard';
import { AppGlyph } from '../components/AppGlyph';
import { normalizeCustomColor } from '../data/CustomThemeColors';
import { window } from '@kit.ArkUI';

/** 网格左右内边距，对应上游 BookshelfScreen.kt contentPadding horizontal 8.dp。 */
const BOOKSHELF_GRID_PADDING: number = 8;
/** 网格行间距与列间距，对应上游 BookshelfScreen.kt:1770-1772 的 spacedBy(8.dp)。 */
const BOOKSHELF_GRID_GAP: number = 8;
/**
 * 首屏封面预加载列数：本地没有封面预加载器
 * （`grep -rn 'preload\|Preload' entry/src/main/ets` 零命中），按 0 处理，
 * 不新建预加载系统；封面由 components/BookCover.ets 各卡片自行加载。
 * 对应 KI-SL-C3 / 对照表 C 块「首屏封面预加载列数」一行的本地落点。
 */
const BOOKSHELF_FIRST_SCREEN_PRELOAD_COLUMNS: number = 0;

/** 网格样式选项，对应上游 bookshelf_grid_layout（标准 / 紧凑 / 仅封面）。 */
const BOOKSHELF_GRID_STYLE_OPTIONS: BookshelfLayoutOption[] = [
  { value: 0, label: '标准' },
  { value: 1, label: '紧凑' },
  { value: 2, label: '仅封面' }
];

/** 卡片底色十六进制转 ARGB 整数；空串或非法值返回 0（= 跟随主题）。 */
function bookshelfCardHexToInt(hex: string): number {
  const normalized = normalizeCustomColor(hex);
  if (normalized.length === 0) { return 0; }
  const digits = normalized.slice(1);
  const argb = parseInt(digits.length === 6 ? `FF${digits}` : digits, 16);
  return Number.isFinite(argb) ? (argb | 0) : 0;
}

/** ARGB 整数转 #RRGGBB；0 返回空串（丢 alpha，对齐 ReaderMarkingEditor 的展示口径）。 */
function bookshelfCardIntToHex(color: number): string {
  if (color === 0) { return ''; }
  const unsigned = color >>> 0;
  const channel = (value: number): string => value.toString(16).padStart(2, '0');
  return `#${channel((unsigned >>> 16) & 0xFF)}${channel((unsigned >>> 8) & 0xFF)}${channel(unsigned & 0xFF)}`.toUpperCase();
}

@Component
export struct BookshelfPage {
  @StorageProp('themeColorTextPrimary') themeColorTextPrimary: string = '#1B1C22';
  @StorageProp('themeColorTextSecondary') themeColorTextSecondary: string = '#2E3038';
  @StorageProp('themeColorTextTertiary') themeColorTextTertiary: string = '#6A6D77';
  @StorageProp('themeColorAccent') themeColorAccent: string = '#3F5BD9';
  @StorageProp('themeColorSurfacePrimary') themeColorSurfacePrimary: string = '#F5F6F8';
  @StorageProp('themeColorSurfaceTertiary') themeColorSurfaceTertiary: string = '#F0F1F5';
  @StorageProp('themeColorSurfaceElevated') themeColorSurfaceElevated: string = '#FFFFFF';
  @StorageProp('themeAppBackground') themeAppBackground: string = '';
  @StorageProp('themePureBlack') themePureBlack: boolean = false;
  @StorageProp('themeItemBackground') themeItemBackground: string = '';
  @Prop books: Book[] = [];
  @Prop groups: BookGroup[] = [];
  /** 书架布局设置，来自 Index 的持久化状态。异步恢复完成后由 onLayoutChanged 灌入记住的分组。 */
  @Prop @Watch('onLayoutChanged') layout: BookshelfLayoutSettings = DEFAULT_BOOKSHELF_LAYOUT;
  /** 封面文字设置，来自 Index 的持久化状态。 */
  @Prop coverSettings: CoverSettings = DEFAULT_COVER_SETTINGS;
  /** 当前是否夜间主题，决定封面文字用日间还是夜间那一套开关与颜色。 */
  @Prop readerNightMode: boolean = false;
  @State showLayoutSheet: boolean = false;
  /** 布局面板编辑中的草稿；打开面板时从 layout 复制，确认后整体提交。 */
  @State layoutDraft: BookshelfLayoutSettings = copyBookshelfLayout(DEFAULT_BOOKSHELF_LAYOUT);
  @State selectedFilter: string = '全部';
  @State showGroupManager: boolean = false;
  @State showGroupEditor: boolean = false;
  @State editingGroupId: number = -1;
  @State draftName: string = '';
  @State draftSort: number = -1;
  @State draftRefresh: boolean = true;
  @State draftPrivate: boolean = false;
  @State draftCover: string = '';
  @State pendingDeleteGroupId: number = -1;
  @State showSearch: boolean = false;
  @State searchQuery: string = '';
  @State collapsedHeader: boolean = false;
  @State emptyFace: string = '(；′⌒`)';
  /**
   * 网格容器的实测宽度（vp）。
   *
   * 封面宽度要按格子宽度算（上游是 fillMaxWidth + aspectRatio 5:7），
   * 而格子宽度只有在布局完成后才知道，所以记下网格的 onAreaChange 结果。
   */
  @State bookshelfGridWidth: number = 0;
  /** 当前是否横屏：由窗口矩形（F1）与网格容器尺寸共同判断，横屏时布局取 Landscape 那套字段。 */
  @State isLandscape: boolean = false;
  /** 文件夹视图当前进入的分组名；空串表示停在根层（显示分组卡片）。 */
  @State folderViewGroup: string = '';
  /** 日间/夜间卡片底色的编辑中十六进制文本；0 值在界面上表现为空串。 */
  @State dayCardColorHex: string = '';
  @State nightCardColorHex: string = '';
  /** 记住上次分组只灌一次，避免后续设置对象刷新覆盖用户主动选择的页签。 */
  private tabPositionRestored: boolean = false;
  /** 书架窗口引用与尺寸回调，aboutToDisappear 时解绑，避免订阅泄漏。 */
  private bookshelfWindow: window.Window | undefined = undefined;
  private windowSizeListener: (size: window.Size) => void = (_size: window.Size): void => {};
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
  /** 按完整草稿新建分组，供分组编辑面板提交。 */
  onAddGroupDraft: (draft: BookGroupDraft) => Promise<void> = async (_draft: BookGroupDraft) => {};
  /** 保存编辑后的分组属性。 */
  onUpdateGroup: (id: number, draft: BookGroupDraft) => Promise<void> =
    async (_id: number, _draft: BookGroupDraft) => {};
  /** 选择分组封面，返回新的封面路径；用户取消时返回空串。 */
  onChooseGroupCover: (id: number) => Promise<string> = async (_id: number) => '';
  /** 清除分组封面。 */
  onClearGroupCover: (id: number) => Promise<void> = async (_id: number) => {};
  /** 把分组拖到另一个分组的位置。 */
  onMoveGroup: (fromId: number, toId: number) => Promise<void> = async (_fromId: number, _toId: number) => {};
  /** 保存书架布局设置。 */
  onSaveLayout: (settings: BookshelfLayoutSettings) => Promise<void> =
    async (_settings: BookshelfLayoutSettings) => {};
  onUnavailableAction: (message: string) => void = (_message: string) => {};

  /** 目录或进度变更后让书架卡片重建，避免 ArkUI 复用旧章节角标。 */
  private bookCardKey(book: Book): string {
    // 列表模式卡片会展示最新章节名与简介，这两个字段变化时也要让卡片重建。
    return `${book.id}_${book.chapterCount ?? ''}_${book.chapterIndex ?? 0}_${book.chapterProgress ?? 0}_${bookCoverMark(book)}_${BookRepository.isBodyMissing(book) ? 1 : 0}_${book.lastChapter}_${book.description ?? ''}`;
  }

  aboutToAppear(): void {
    // Index 的布局恢复是异步的；这里先尝试一次，若拿到的是默认值，@Watch 会在恢复完成后再灌一次。
    this.onLayoutChanged();
    this.resolveWindowOrientation();
  }

  aboutToDisappear(): void {
    if (this.bookshelfWindow !== undefined) {
      this.bookshelfWindow.off('windowSizeChange', this.windowSizeListener);
      this.bookshelfWindow = undefined;
    }
  }

  /**
   * 读取当前窗口方向（F1）：window.getLastWindow 取窗口矩形，width > height 即横屏；
   * 同时订阅 windowSizeChange，旋转后立刻刷新 isLandscape。
   * 网格容器的 onAreaChange 也会再兜底一次（组件级尺寸回调，旋转必触发）。
   */
  private resolveWindowOrientation(): void {
    const context = this.getUIContext().getHostContext();
    if (context === undefined) { return; }
    window.getLastWindow(context).then((targetWindow: window.Window) => {
      this.bookshelfWindow = targetWindow;
      const rect = targetWindow.getWindowProperties().windowRect;
      this.isLandscape = rect.width > rect.height;
      this.windowSizeListener = (size: window.Size): void => {
        const landscape: boolean = size.width > size.height;
        if (landscape !== this.isLandscape) { this.isLandscape = landscape; }
      };
      targetWindow.on('windowSizeChange', this.windowSizeListener);
    }).catch(() => {});
  }

  /** layout 异步恢复完成后，把记住的分组灌进当前筛选（只在拿到具体分组名时锁定）。 */
  private onLayoutChanged(): void {
    // 离开「文件夹」分组样式后清掉组内导航，避免下次切回时残留子视图。
    if (this.layout.bookGroupStyle !== 2 && this.folderViewGroup.length > 0) {
      this.folderViewGroup = '';
    }
    if (this.tabPositionRestored) { return; }
    const remembered = this.layout.saveTabPosition;
    if (remembered.length === 0 || remembered === '全部') { return; }
    if (this.getGroupNames().includes(remembered)) {
      this.tabPositionRestored = true;
      this.selectedFilter = remembered;
    }
  }

  /** 切换分组并写回「记住上次所在分组」。 */
  private async selectGroup(name: string): Promise<void> {
    this.tabPositionRestored = true;
    this.selectedFilter = name;
    const next = copyBookshelfLayout(this.layout);
    next.saveTabPosition = name;
    await this.onSaveLayout(next);
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
    // 「隐藏没有书籍的分组」只过滤自定义分组，「全部」永远保留。
    if (!this.layout.hideEmptyGroups) { return names; }
    return names.filter((name: string) => name === '全部' || this.countBooksInGroup(name) > 0);
  }

  /** 某个分组下的书籍数量，供隐藏空分组使用。 */
  private countBooksInGroup(name: string): number {
    return this.books.filter((book: Book) => {
      const names = book.groupNames ?? [];
      return name === '本地未分组' ? names.length === 0 : names.includes(name);
    }).length;
  }

  /**
   * 实际生效的分组筛选。
   *
   * 打开「隐藏没有书籍的分组」后当前选中的分组可能被过滤掉，
   * 此时回落到「全部」，避免出现页签消失但仍按旧分组过滤的空书架。
   */
  private activeFilter(): string {
    const names = this.getGroupNames();
    return names.includes(this.selectedFilter) ? this.selectedFilter : '全部';
  }

  private getVisibleBooks(): Book[] {
    const selectedGroup = this.activeFilter();
    const query = this.searchQuery.trim().toLocaleLowerCase();
    const filtered = this.books.filter((book: Book) => {
      const names = book.groupNames ?? [];
      const matchesGroup = selectedGroup === '全部' ||
        (selectedGroup === '本地未分组' ? names.length === 0 : names.includes(selectedGroup));
      const matchesQuery = query.length === 0 || book.title.toLocaleLowerCase().includes(query) ||
        book.author.toLocaleLowerCase().includes(query);
      return matchesGroup && matchesQuery;
    });
    // 分组设了自己的排序方式就覆盖书架全局，与上游 sortBooks() 的取值优先级一致。
    const activeGroup = this.groups.find((group: BookGroup) =>
      group.groupId > 0 && group.groupName === selectedGroup);
    return BookshelfSort.sortBooks(filtered, activeGroup,
      this.layout.bookshelfSort, this.layout.bookshelfSortOrder);
  }

  /** 只列自定义分组，按 order 升序，与上游 GroupManageSheet 一致。 */
  private getUserGroups(): BookGroup[] {
    return this.groups.filter((group: BookGroup) => group.groupId > 0)
      .sort((left: BookGroup, right: BookGroup) => left.order - right.order);
  }

  /** 文件夹根层显示的分组名清单：与页签共用 getGroupNames，保证「全部」与各分组一致。 */
  private getFolderGroups(): string[] {
    return this.getGroupNames();
  }

  /** 某分组卡片上的预览书籍；不套搜索框关键字，与上游 previewBooks 的组内取书一致。 */
  private getFolderPreviewBooks(groupName: string): Book[] {
    return this.books.filter((book: Book) => {
      const names = book.groupNames ?? [];
      return groupName === '全部' ? true
        : (groupName === '本地未分组' ? names.length === 0 : names.includes(groupName));
    });
  }

  /** 点分组卡片进入组内：同时把筛选切到该分组，让书籍网格显示该组的书。 */
  private openFolderGroup(name: string): void {
    this.folderViewGroup = name;
    this.selectedFilter = name;
  }

  /** 返回文件夹根层：清掉组内导航与筛选。 */
  private backToFolderRoot(): void {
    this.folderViewGroup = '';
    this.selectedFilter = '全部';
  }

  /** 分组卡片在网格里的稳定 key；属性变化后必须换 key，否则 ArkUI 会复用旧节点。 */
  private groupCardKey(group: BookGroup): string {
    return `${group.groupId}_${group.groupName}_${group.show ? 1 : 0}_${group.order}_${group.bookSort}_${group.isPrivate ? 1 : 0}_${group.cover ?? ''}`;
  }

  /** 打开分组编辑面板，把当前属性灌进草稿。 */
  private openGroupEditor(group: BookGroup | undefined): void {
    if (group === undefined) {
      this.editingGroupId = -1;
      this.draftName = '';
      this.draftSort = -1;
      this.draftRefresh = true;
      this.draftPrivate = false;
      this.draftCover = '';
    } else {
      this.editingGroupId = group.groupId;
      this.draftName = group.groupName;
      this.draftSort = group.bookSort;
      this.draftRefresh = group.enableRefresh;
      this.draftPrivate = group.isPrivate;
      this.draftCover = group.cover ?? '';
    }
    this.showGroupEditor = true;
  }

  /** 提交分组编辑面板；名称冲突等错误由调用方回传提示。 */
  private async submitGroupDraft(): Promise<void> {
    const name = this.draftName.trim();
    if (name.length === 0) { this.onUnavailableAction('分组名称不能为空'); return; }
    const draft: BookGroupDraft = {
      groupName: name,
      enableRefresh: this.draftRefresh,
      bookSort: this.draftSort,
      isPrivate: this.draftPrivate,
      cover: this.draftCover.length > 0 ? this.draftCover : undefined
    };
    if (this.editingGroupId > 0) {
      await this.onUpdateGroup(this.editingGroupId, draft);
      if (this.selectedFilter !== name) {
        const previous = this.groups.find((group: BookGroup) => group.groupId === this.editingGroupId);
        if (previous !== undefined && this.selectedFilter === previous.groupName) { this.selectedFilter = name; }
      }
    } else {
      await this.onAddGroupDraft(draft);
    }
    this.showGroupEditor = false;
  }

  /** 分组排序方式菜单，选项来自 BOOK_SORT_OPTIONS。 */
  @Builder
  private SortMenu() {
    Menu() {
      ForEach(BOOK_SORT_OPTIONS, (option: BookSortOption) => {
        MenuItem({ content: option.label }).height(44)
          .onClick(() => this.draftSort = option.value)
      }, (option: BookSortOption) => `${option.value}`)
    }.backgroundColor(this.themeAppBackground.length > 0 ? Color.Transparent : (this.themePureBlack ? '#121212' : this.themeColorSurfaceElevated)).fontColor(this.themeColorTextPrimary).radius(20)
  }

  @Builder
  private GroupCoverThumb(group: BookGroup, thumbSize: number) {
    Stack({ alignContent: Alignment.Center }) {
      if ((group.cover ?? '').length > 0) {
        Image(group.cover).width(thumbSize).height(thumbSize).borderRadius(10).objectFit(ImageFit.Cover)
      } else {
        Text(group.groupName.substring(0, 1)).fontSize(thumbSize / 2.4).fontColor('#C4D1FF')
      }
    }
    .width(thumbSize).height(thumbSize).backgroundColor('#22232A').borderRadius(10)
  }

  /** 隐藏页签布局仍可从管理面板选择全部当前可用的分组筛选。 */
  @Builder
  private GroupFilterMenu() {
    Menu() {
      ForEach(this.getGroupNames(), (groupName: string) => {
        MenuItem({ content: groupName === this.activeFilter() ? `✓ ${groupName}` : groupName }).height(44)
          .onClick(async () => {
            await this.selectGroup(groupName);
            this.showGroupManager = false;
          })
      }, (groupName: string) => groupName)
    }.backgroundColor(this.themeAppBackground.length > 0 ? Color.Transparent : (this.themePureBlack ? '#121212' : this.themeColorSurfaceElevated)).fontColor(this.themeColorTextPrimary).radius(20)
  }

  /** 分组管理：自适应网格卡片，对应上游 LazyVerticalGrid(GridCells.Adaptive(160.dp))。 */
  @Builder
  private GroupManagerGrid() {
    Column() {
      Row() {
        Text('分组管理').fontSize(19).fontWeight(FontWeight.Medium).fontColor(this.themeColorTextPrimary).layoutWeight(1)
        Text('新建').fontSize(14).fontColor('#B9C8FF').padding(8)
          .onClick(() => this.openGroupEditor(undefined))
        Text('完成').fontSize(14).fontColor('#B9C8FF').padding(8).onClick(() => this.showGroupManager = false)
      }.width('100%').padding({ left: 18, right: 12, top: 14, bottom: 10 })
      Row() {
        Text(`切换分组：${this.activeFilter()}`).fontSize(13).fontColor(this.themeColorAccent).layoutWeight(1)
          .bindMenu(this.GroupFilterMenu())
      }.width('100%').padding({ left: 18, right: 18, bottom: 10 })

      if (this.getUserGroups().length === 0) {
        Column() {
          Text('还没有自定义分组').fontSize(14).fontColor(this.themeColorTextTertiary)
          Text('点右上「新建」创建第一个分组').fontSize(12).fontColor('#6E7078').margin({ top: 6 })
        }.width('100%').padding({ top: 40, bottom: 40 }).justifyContent(FlexAlign.Center)
      } else {
        // 长按卡片进入拖拽排序，对应上游 rememberReorderableLazyGridState；
        // editMode(true) 是 Grid 内 ForEach.onMove 生效的前提。
        Grid() {
          ForEach(this.getUserGroups(), (group: BookGroup) => {
            GridItem() {
              Column() {
                Row() {
                  this.GroupCoverThumb(group, 40)
                  Blank()
                  Toggle({ type: ToggleType.Switch, isOn: group.show })
                    .onChange((visible: boolean) => {
                      this.onSetGroupVisible(group.groupId, visible);
                      if (!visible && this.selectedFilter === group.groupName) { this.selectedFilter = '全部'; }
                    })
                }.width('100%')
                Text(group.groupName).fontSize(14).fontColor(this.themeColorTextPrimary).maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                  .margin({ top: 10 }).width('100%')
                Text(`${bookSortLabel(group.bookSort)}${group.isPrivate ? ' · 私有标记未生效' : ''} · 分组刷新未接入`)
                  .fontSize(11).fontColor(this.themeColorTextTertiary).maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                  .margin({ top: 4 }).width('100%')
              }.width('100%').padding(12).backgroundColor(this.themeAppBackground.length > 0 ? Color.Transparent : (this.themePureBlack ? '#0A0A0A' : this.themeColorSurfaceTertiary)).borderRadius(14)
                .alignItems(HorizontalAlign.Start)
                .onClick(() => this.openGroupEditor(group))
            }
          }, (group: BookGroup) => this.groupCardKey(group))
            .onMove((from: number, to: number) => {
              const userGroups = this.getUserGroups();
              if (from < 0 || to < 0 || from >= userGroups.length || to >= userGroups.length) { return; }
              this.onMoveGroup(userGroups[from].groupId, userGroups[to].groupId);
            })
        }
        .columnsTemplate('1fr 1fr').columnsGap(10).rowsGap(10)
        .width('100%').layoutWeight(1).padding({ left: 16, right: 16, bottom: 18 })
        .scrollBar(BarState.Off).editMode(true)
      }
    }.width('100%').height('100%').backgroundColor('#17181E')
  }

  /** 分组编辑面板内容，对应上游 GroupEditSheet。 */
  @Builder
  private GroupEditorContent() {
    Column() {
      Row() {
        Text(this.editingGroupId > 0 ? '编辑分组' : '新建分组')
          .fontSize(19).fontWeight(FontWeight.Medium).fontColor(this.themeColorTextPrimary).layoutWeight(1)
        Text('保存').fontSize(14).fontColor('#B9C8FF').padding(8)
          .onClick(async () => { await this.submitGroupDraft(); })
        Text('取消').fontSize(14).fontColor(this.themeColorTextTertiary).padding(8)
          .onClick(() => this.showGroupEditor = false)
      }.width('100%').padding({ left: 18, right: 12, top: 14, bottom: 10 })
      Scroll() {
        Column() {
          // 封面：点击选图，长按清除，与上游 GroupEditContent 的封面项一致。
          Row() {
            Text('封面').fontSize(14).fontColor(this.themeColorTextSecondary).layoutWeight(1)
            Stack({ alignContent: Alignment.Center }) {
              if (this.draftCover.length > 0) {
                Image(this.draftCover).width(48).height(48).borderRadius(10).objectFit(ImageFit.Cover)
              } else {
                AppGlyph({ name: 'add', glyphSize: 18, tint: this.themeColorTextTertiary })
              }
            }
            .width(48).height(48).backgroundColor('#22232A').borderRadius(10)
            .onClick(async () => {
              if (this.editingGroupId <= 0) {
                this.onUnavailableAction('请先保存分组，再设置封面');
                return;
              }
              const cover = await this.onChooseGroupCover(this.editingGroupId);
              if (cover.length > 0) { this.draftCover = cover; }
            })
            if (this.draftCover.length > 0) {
              Text('清除').fontSize(12).fontColor('#D99AA5').padding({ left: 12 })
                .onClick(async () => {
                  if (this.editingGroupId > 0) { await this.onClearGroupCover(this.editingGroupId); }
                  this.draftCover = '';
                })
            }
          }.width('100%').padding({ left: 16, right: 16, top: 12, bottom: 12 })

          Row() {
            Text('分组名称').fontSize(14).fontColor(this.themeColorTextSecondary).width(88)
            TextInput({ text: this.draftName, placeholder: '分组名称' }).layoutWeight(1).height(40)
              .fontSize(14).fontColor(this.themeColorTextPrimary).placeholderColor(this.themeColorTextTertiary)
              .backgroundColor('#22232A').borderRadius(9)
              .onChange((value: string) => this.draftName = value)
          }.width('100%').padding({ left: 16, right: 16, top: 8, bottom: 8 })

          Row() {
            Text('排序方式').fontSize(14).fontColor(this.themeColorTextSecondary).layoutWeight(1)
            Text(bookSortLabel(this.draftSort)).fontSize(14).fontColor(this.themeColorAccent)
              .bindMenu(this.SortMenu())
          }.width('100%').padding({ left: 16, right: 16, top: 12, bottom: 12 })

          Row() {
            Column() {
              Text('下拉刷新').fontSize(14).fontColor(this.themeColorTextSecondary)
              Text('仅保存 Android 兼容字段；当前不控制实际更新').fontSize(11).fontColor(this.themeColorTextTertiary).margin({ top: 3 })
            }.alignItems(HorizontalAlign.Start).layoutWeight(1)
            Toggle({ type: ToggleType.Switch, isOn: this.draftRefresh })
              .onChange((enabled: boolean) => this.draftRefresh = enabled)
          }.width('100%').padding({ left: 16, right: 16, top: 10, bottom: 10 })

          Row() {
            Column() {
              Text('私有分组').fontSize(14).fontColor(this.themeColorTextSecondary)
              Text('仅保存兼容标记；当前不限制跨分组显示').fontSize(11).fontColor(this.themeColorTextTertiary).margin({ top: 3 })
            }.alignItems(HorizontalAlign.Start).layoutWeight(1)
            Toggle({ type: ToggleType.Switch, isOn: this.draftPrivate })
              .onChange((enabled: boolean) => this.draftPrivate = enabled)
          }.width('100%').padding({ left: 16, right: 16, top: 10, bottom: 10 })

          if (this.editingGroupId > 0) {
            Row() {
              Text(this.pendingDeleteGroupId === this.editingGroupId ? '确认删除' : '删除分组')
                .fontSize(14).fontColor('#D99AA5').layoutWeight(1)
                .onClick(() => {
                  if (this.pendingDeleteGroupId === this.editingGroupId) {
                    this.onRemoveGroup(this.editingGroupId);
                    const removed = this.groups.find((group: BookGroup) => group.groupId === this.editingGroupId);
                    if (removed !== undefined && this.selectedFilter === removed.groupName) {
                      this.selectedFilter = '全部';
                    }
                    this.pendingDeleteGroupId = -1;
                    this.showGroupEditor = false;
                  } else {
                    this.pendingDeleteGroupId = this.editingGroupId;
                  }
                })
              if (this.pendingDeleteGroupId === this.editingGroupId) {
                Text('取消').fontSize(13).fontColor(this.themeColorTextTertiary).padding({ left: 12 })
                  .onClick(() => this.pendingDeleteGroupId = -1)
              }
            }.width('100%').padding({ left: 16, right: 16, top: 16, bottom: 16 })
          }
        }.width('100%')
      }.layoutWeight(1).scrollBar(BarState.Off)
    }.width('100%').height('100%').backgroundColor('#17181E')
  }

  /** 分组面板：管理网格与编辑表单共用一个 sheet，避免同一组件挂两个 bindSheet 只有后者生效。 */
  @Builder
  private GroupManagerSheet() {
    if (this.showGroupEditor) {
      this.GroupEditorContent()
    } else {
      this.GroupManagerGrid()
    }
  }

  /** 当前方向下生效的布局模式（1 网格 / 0 列表）：竖屏取 Portrait，横屏取 Landscape。 */
  private activeLayoutMode(): number {
    return this.isLandscape
      ? this.layout.bookshelfLayoutModeLandscape : this.layout.bookshelfLayoutModePortrait;
  }

  /** 当前方向下生效的网格列数。 */
  private activeGridColumns(): number {
    return this.isLandscape
      ? this.layout.bookshelfLayoutGridLandscape : this.layout.bookshelfLayoutGridPortrait;
  }

  /** 当前方向下生效的列表列数。 */
  private activeListColumns(): number {
    return this.isLandscape
      ? this.layout.bookshelfLayoutListLandscape : this.layout.bookshelfLayoutListPortrait;
  }

  /** 文件夹视图：当前方向下生效的布局模式（1 网格 / 0 列表）。 */
  private activeFolderLayoutMode(): number {
    return this.isLandscape
      ? this.layout.bookshelfFolderLayoutModeLandscape : this.layout.bookshelfFolderLayoutModePortrait;
  }

  /** 文件夹视图：当前方向下生效的网格列数。 */
  private activeFolderGridColumns(): number {
    return this.isLandscape
      ? this.layout.bookshelfFolderLayoutGridLandscape : this.layout.bookshelfFolderLayoutGridPortrait;
  }

  /** 文件夹视图：当前方向下生效的列表列数。 */
  private activeFolderListColumns(): number {
    return this.isLandscape
      ? this.layout.bookshelfFolderLayoutListLandscape : this.layout.bookshelfFolderLayoutListPortrait;
  }

  /**
   * 文件夹根视图的列数模板：对齐上游 BookshelfScreen.kt:985
   * folderColumns = if (bookshelfFolderLayoutMode == 0) bookshelfFolderLayoutList else bookshelfFolderLayoutGrid，
   * 再按 :988 的 coerceAtLeast(1) 兜底。横竖屏各取一套值。
   */
  private folderColumnsTemplate(): string {
    const mode = this.activeFolderLayoutMode();
    const configured = mode === 1 ? this.activeFolderGridColumns() : this.activeFolderListColumns();
    const maximum = mode === 1 ? 8 : 5;
    const columns = Math.max(1, Math.min(maximum, Math.round(configured)));
    const template: string[] = [];
    for (let index = 0; index < columns; index += 1) { template.push('1fr'); }
    return template.join(' ');
  }

  /** 按当前方向与 Android 书架设置选择列表或网格的列数。 */
  private bookshelfColumnsTemplate(): string {
    const mode = this.activeLayoutMode();
    const configuredColumns = mode === 1 ? this.activeGridColumns() : this.activeListColumns();
    const maximum = mode === 1 ? 6 : 5;
    const columns = Math.max(1, Math.min(maximum, Math.round(configuredColumns)));
    const template: string[] = [];
    for (let index = 0; index < columns; index += 1) { template.push('1fr'); }
    return template.join(' ');
  }

  /** 当前生效的列数，供封面宽度换算用。 */
  private bookshelfColumnCount(): number {
    const mode = this.activeLayoutMode();
    const configuredColumns = mode === 1 ? this.activeGridColumns() : this.activeListColumns();
    const maximum = mode === 1 ? 6 : 5;
    return Math.max(1, Math.min(maximum, Math.round(configuredColumns)));
  }

  /**
   * 网格里单个格子能给出的封面宽度（vp）。
   *
   * 对齐上游 BookItem.kt:269-273：封面宽度由格子宽度决定，高度按 5:7 推导。
   * 格子宽度 = (网格可用宽 - 左右内边距 8*2 - 列间距 8*(列数-1)) / 列数，
   * 再减 8 给上游 BookshelfItemCover 的 padding(4.dp) 留位置。
   * 宽度未知时返回 0，调用方回落到 100% 让布局自己算。
   */
  private bookshelfCoverSlotWidth(): number {
    if (this.bookshelfGridWidth <= 0) { return 0; }
    const columns = this.bookshelfColumnCount();
    const available = this.bookshelfGridWidth - BOOKSHELF_GRID_PADDING * 2
      - BOOKSHELF_GRID_GAP * (columns - 1);
    if (available <= 0) { return 0; }
    return Math.max(0, Math.floor(available / columns) - 8);
  }

  /**
   * 书封宽度上限：格子宽与用户设置取小值。
   *
   * 上游 bookshelfGridCoverWidth 默认 120，作用是限制封面不要随格子无限放大；
   * 格子比它窄时以格子为准，保证「填满格子」与「用户设定」两个约束同时成立。
   */
  private bookshelfCoverWidthLimit(): number {
    const slot = this.bookshelfCoverSlotWidth();
    const configured = Math.max(0, Math.round(this.layout.bookshelfGridCoverWidth));
    if (slot <= 0) { return configured; }
    return configured > 0 ? Math.min(slot, configured) : slot;
  }

  /** 书封标题字号：上游 labelMedium 13sp、labelSmall 11sp。 */
  private bookshelfTitleFontSize(): number {
    return this.layout.bookshelfTitleSmallFont ? 11 : 13;
  }

  /** 卡片底色：日夜各一套，0 时透明（沿用主题背景）。 */
  private cardBackgroundColor(): ResourceColor {
    const color = this.readerNightMode
      ? this.layout.bookshelfCardColorDark : this.layout.bookshelfCardColor;
    return color === 0 ? Color.Transparent : bookshelfCardIntToHex(color);
  }

  /** 紧凑样式下封面内标题的渐变黑底，对齐上游 BookItem.kt:123-131 的垂直渐变。 */
  private coverTitleGradient(): LinearGradientOptions {
    return { angle: 180, colors: [['#00000000', 0.0], ['#B3000000', 1.0]] };
  }

  /** 打开布局面板：从已生效设置复制一份草稿，面板内改动只落到草稿。 */
  private openLayoutSheet(): void {
    this.layoutDraft = copyBookshelfLayout(this.layout);
    this.dayCardColorHex = bookshelfCardIntToHex(this.layoutDraft.bookshelfCardColor);
    this.nightCardColorHex = bookshelfCardIntToHex(this.layoutDraft.bookshelfCardColorDark);
    this.showLayoutSheet = true;
  }

  /** 提交布局草稿并关闭面板。 */
  private updateLayoutDraft(update: (draft: BookshelfLayoutSettings) => void): void {
    const draft = copyBookshelfLayout(this.layoutDraft);
    update(draft);
    this.layoutDraft = draft;
  }

  private async submitLayout(): Promise<void> {
    this.showLayoutSheet = false;
    await this.onSaveLayout(copyBookshelfLayout(this.layoutDraft));
    // 隐藏空分组或隐藏当前分组后，选中页签可能已不存在，回落到「全部」。
    if (!this.getGroupNames().includes(this.selectedFilter)) { this.selectedFilter = '全部'; }
  }

  /** 通用下拉：一个按钮 + 菜单，用于布局面板里的枚举项。 */
  @Builder
  private LayoutMenuRow(
    title: string, description: string, options: BookshelfLayoutOption[],
    current: number, onPick: (value: number) => void
  ) {
    Row() {
      Column() {
        Text(title).fontSize(14).fontColor(this.themeColorTextSecondary)
        if (description.length > 0) {
          Text(description).fontSize(11).fontColor(this.themeColorTextTertiary).margin({ top: 3 })
        }
      }.alignItems(HorizontalAlign.Start).layoutWeight(1)
      Text(bookshelfLayoutOptionLabel(options, current)).fontSize(14).fontColor(this.themeColorAccent)
        .bindMenu(this.LayoutOptionsMenu(options, onPick))
    }.width('100%').padding({ left: 16, right: 16, top: 12, bottom: 12 })
  }

  /** 枚举项菜单；ArkTS 不允许 bindMenu 传对象字面量数组，统一用 Builder 生成。 */
  @Builder
  private LayoutOptionsMenu(options: BookshelfLayoutOption[], onPick: (value: number) => void) {
    Menu() {
      ForEach(options, (option: BookshelfLayoutOption) => {
        MenuItem({ content: option.label }).height(44)
          .onClick(() => onPick(option.value))
      }, (option: BookshelfLayoutOption) => `${option.value}_${option.label}`)
    }.backgroundColor(this.themeAppBackground.length > 0 ? Color.Transparent : (this.themePureBlack ? '#121212' : this.themeColorSurfaceElevated)).fontColor(this.themeColorTextPrimary).radius(20)
  }

  /** 开关行。 */
  @Builder
  private LayoutSwitchRow(title: string, description: string, isOn: boolean, onToggle: (value: boolean) => void) {
    Row() {
      Column() {
        Text(title).fontSize(14).fontColor(this.themeColorTextSecondary)
        if (description.length > 0) {
          Text(description).fontSize(11).fontColor(this.themeColorTextTertiary).margin({ top: 3 })
        }
      }.alignItems(HorizontalAlign.Start).layoutWeight(1)
      Toggle({ type: ToggleType.Switch, isOn: isOn })
        .onChange((value: boolean) => onToggle(value))
    }.width('100%').padding({ left: 16, right: 16, top: 10, bottom: 10 })
  }

  /** 数值行：用 -/+ 加减，避免滑块在小屏上难以精确点中。 */
  @Builder
  private LayoutStepperRow(
    title: string, description: string, value: number,
    minimum: number, maximum: number, onStep: (delta: number) => void
  ) {
    Row() {
      Column() {
        Text(title).fontSize(14).fontColor(this.themeColorTextSecondary)
        if (description.length > 0) {
          Text(description).fontSize(11).fontColor(this.themeColorTextTertiary).margin({ top: 3 })
        }
      }.alignItems(HorizontalAlign.Start).layoutWeight(1)
      Text('−').fontSize(18).fontColor(value > minimum ? this.themeColorAccent : '#4A4C55')
        .width(36).height(32).textAlign(TextAlign.Center)
        .onClick(() => { if (value > minimum) { onStep(-1); } })
      Text(`${value}`).fontSize(14).fontColor(this.themeColorTextPrimary).width(34).textAlign(TextAlign.Center)
      Text('+').fontSize(18).fontColor(value < maximum ? this.themeColorAccent : '#4A4C55')
        .width(36).height(32).textAlign(TextAlign.Center)
        .onClick(() => { if (value < maximum) { onStep(1); } })
    }.width('100%').padding({ left: 16, right: 12, top: 10, bottom: 10 })
  }

  /** 卡片底色编辑行：预览方块 + hex 输入，复用 CustomThemePage.ColorEditor 的交互口径。 */
  @Builder
  private ColorPickerRow(title: string, hex: string, onHex: (value: string) => void) {
    Row() {
      Row().width(24).height(24).borderRadius(6)
        .backgroundColor(normalizeCustomColor(hex).length > 0 ? hex : this.themeColorSurfacePrimary)
        .border({ width: 1, color: this.themeColorTextTertiary })
      Text(title).fontSize(14).fontColor(this.themeColorTextSecondary).layoutWeight(1).margin({ left: 12 })
      TextInput({ text: hex, placeholder: '#RRGGBB' }).width(110).fontSize(12)
        .fontColor(this.themeColorTextPrimary)
        .onChange((value: string) => onHex(value))
    }.width('100%').padding({ left: 16, right: 16, top: 10, bottom: 10 })
  }

  /** 分区标题，对应上游 PillHeaderDivider。 */
  @Builder
  private LayoutSectionHeader(title: string) {
    Row() {
      Text(title).fontSize(12).fontColor(this.themeColorTextTertiary)
    }.width('100%').padding({ left: 16, right: 16, top: 14, bottom: 6 })
  }

  /**
   * 书架布局设置面板，对应上游 BookshelfConfigSheet。
   *
   * 只迁移当前项目已有数据模型能支撑的项；上游的封面尺寸、卡片颜色、
   * 标签徽标等依赖书籍字段或网络状态，留待后续轮次。
   */
  @Builder
  private LayoutSheetContent() {
    Column() {
      Row() {
        Text('书架布局').fontSize(19).fontWeight(FontWeight.Medium).fontColor(this.themeColorTextPrimary).layoutWeight(1)
        Text('完成').fontSize(14).fontColor('#B9C8FF').padding(8)
          .onClick(async () => { await this.submitLayout(); })
      }.width('100%').padding({ left: 18, right: 12, top: 14, bottom: 6 })

      Scroll() {
        Column() {
          this.LayoutSectionHeader('分组')
          this.LayoutMenuRow('分组样式', '页签 / 隐藏页签 / 文件夹', BOOK_GROUP_STYLE_OPTIONS,
            this.layoutDraft.bookGroupStyle,
            (value: number) => { this.updateLayoutDraft((draft: BookshelfLayoutSettings) => { draft.bookGroupStyle = value; }); })
          this.LayoutSwitchRow('隐藏没有书籍的分组', '页签只显示有书的分类',
            this.layoutDraft.hideEmptyGroups,
            (value: boolean) => { this.updateLayoutDraft((draft: BookshelfLayoutSettings) => { draft.hideEmptyGroups = value; }); })

          if (this.layoutDraft.bookGroupStyle === 2) {
            this.LayoutSectionHeader('文件夹（竖屏）')
            this.LayoutMenuRow('文件夹布局模式·竖屏', '列表 / 网格', BOOKSHELF_FOLDER_LAYOUT_MODE_OPTIONS,
              this.layoutDraft.bookshelfFolderLayoutModePortrait,
              (value: number) => { this.updateLayoutDraft((draft: BookshelfLayoutSettings) => { draft.bookshelfFolderLayoutModePortrait = value; }); })
            this.LayoutStepperRow('文件夹网格列数·竖屏', '网格模式下分组卡片每行个数',
              this.layoutDraft.bookshelfFolderLayoutGridPortrait, 1, 8,
              (delta: number) => { this.updateLayoutDraft((draft: BookshelfLayoutSettings) => { draft.bookshelfFolderLayoutGridPortrait += delta; }); })
            this.LayoutStepperRow('文件夹列表列数·竖屏', '列表模式下分组卡片每行个数',
              this.layoutDraft.bookshelfFolderLayoutListPortrait, 1, 5,
              (delta: number) => { this.updateLayoutDraft((draft: BookshelfLayoutSettings) => { draft.bookshelfFolderLayoutListPortrait += delta; }); })

            this.LayoutSectionHeader('文件夹（横屏）')
            this.LayoutMenuRow('文件夹布局模式·横屏', '列表 / 网格', BOOKSHELF_FOLDER_LAYOUT_MODE_OPTIONS,
              this.layoutDraft.bookshelfFolderLayoutModeLandscape,
              (value: number) => { this.updateLayoutDraft((draft: BookshelfLayoutSettings) => { draft.bookshelfFolderLayoutModeLandscape = value; }); })
            this.LayoutStepperRow('文件夹网格列数·横屏', '网格模式下分组卡片每行个数',
              this.layoutDraft.bookshelfFolderLayoutGridLandscape, 1, 8,
              (delta: number) => { this.updateLayoutDraft((draft: BookshelfLayoutSettings) => { draft.bookshelfFolderLayoutGridLandscape += delta; }); })
            this.LayoutStepperRow('文件夹列表列数·横屏', '列表模式下分组卡片每行个数',
              this.layoutDraft.bookshelfFolderLayoutListLandscape, 1, 5,
              (delta: number) => { this.updateLayoutDraft((draft: BookshelfLayoutSettings) => { draft.bookshelfFolderLayoutListLandscape += delta; }); })

            this.LayoutSectionHeader('文件夹列表样式')
            this.LayoutMenuRow('文件夹列表样式', '分组 / 紧凑列表 / 横排封面数量', BOOKSHELF_GROUP_LIST_STYLE_OPTIONS,
              this.layoutDraft.bookshelfGroupListStyle,
              (value: number) => { this.updateLayoutDraft((draft: BookshelfLayoutSettings) => { draft.bookshelfGroupListStyle = value; }); })
            if (this.layoutDraft.bookshelfGroupListStyle === 2) {
              this.LayoutStepperRow('横排封面数量', '分组卡片一行显示的封面数，不足右侧留空',
                this.layoutDraft.bookshelfGroupCoverCount, 1, 8,
                (delta: number) => { this.updateLayoutDraft((draft: BookshelfLayoutSettings) => { draft.bookshelfGroupCoverCount += delta; }); })
            }
          }

          this.LayoutSectionHeader('排序')
          this.LayoutMenuRow('排序方式', '', BOOK_SORT_OPTIONS, this.layoutDraft.bookshelfSort,
            (value: number) => { this.updateLayoutDraft((draft: BookshelfLayoutSettings) => { draft.bookshelfSort = value; }); })
          this.LayoutMenuRow('排序方向', '', BOOKSHELF_SORT_ORDER_OPTIONS, this.layoutDraft.bookshelfSortOrder,
            (value: number) => { this.updateLayoutDraft((draft: BookshelfLayoutSettings) => { draft.bookshelfSortOrder = value; }); })

          this.LayoutSectionHeader('布局')
          if (this.layoutDraft.bookshelfLayoutModePortrait === 0) {
            this.LayoutMenuRow('布局模式', '竖屏下的书架呈现方式',
              BOOKSHELF_LAYOUT_MODE_OPTIONS, 0,
              (value: number) => { this.updateLayoutDraft((draft: BookshelfLayoutSettings) => { draft.bookshelfLayoutModePortrait = value; }); })
          } else {
            this.LayoutMenuRow('布局模式', '竖屏下的书架呈现方式',
              BOOKSHELF_LAYOUT_MODE_OPTIONS, 1,
              (value: number) => { this.updateLayoutDraft((draft: BookshelfLayoutSettings) => { draft.bookshelfLayoutModePortrait = value; }); })
          }
          if (this.layoutDraft.bookshelfLayoutModePortrait === 1) {
            this.LayoutMenuRow('网格样式', '标准 / 紧凑（书名进封面）/ 仅封面',
              BOOKSHELF_GRID_STYLE_OPTIONS, this.layoutDraft.bookshelfGridLayout,
              (value: number) => { this.updateLayoutDraft((draft: BookshelfLayoutSettings) => { draft.bookshelfGridLayout = value; }); })
          }
          if (this.layoutDraft.bookshelfLayoutModePortrait === 1) {
            this.LayoutStepperRow('网格列数', '每行显示的书封数量',
              this.layoutDraft.bookshelfLayoutGridPortrait, 1, 6,
              (delta: number) => { this.updateLayoutDraft((draft: BookshelfLayoutSettings) => { draft.bookshelfLayoutGridPortrait += delta; }); })
          } else {
            this.LayoutStepperRow('列表列数', '每行显示的书封数量',
              this.layoutDraft.bookshelfLayoutListPortrait, 1, 5,
              (delta: number) => { this.updateLayoutDraft((draft: BookshelfLayoutSettings) => { draft.bookshelfLayoutListPortrait += delta; }); })
          }
          this.LayoutStepperRow('书名行数', '书封下方标题最多显示几行',
            this.layoutDraft.bookshelfTitleMaxLines, 1, 5,
            (delta: number) => { this.updateLayoutDraft((draft: BookshelfLayoutSettings) => { draft.bookshelfTitleMaxLines += delta; }); })
          this.LayoutSwitchRow('标题居中', '关闭后书名左对齐', this.layoutDraft.bookshelfTitleCenter,
            (value: boolean) => { this.updateLayoutDraft((draft: BookshelfLayoutSettings) => { draft.bookshelfTitleCenter = value; }); })
          this.LayoutSwitchRow('标题小字号', '书名用 11 号字，默认 13 号', this.layoutDraft.bookshelfTitleSmallFont,
            (value: boolean) => { this.updateLayoutDraft((draft: BookshelfLayoutSettings) => { draft.bookshelfTitleSmallFont = value; }); })

          this.LayoutSectionHeader('外观')
          this.LayoutSwitchRow('精简详情', '开启后卡片只留封面与书名', this.layoutDraft.bookshelfLayoutCompact,
            (value: boolean) => { this.updateLayoutDraft((draft: BookshelfLayoutSettings) => { draft.bookshelfLayoutCompact = value; }); })
          this.ColorPickerRow('日间卡片底色', this.dayCardColorHex,
            (value: string) => {
              this.dayCardColorHex = value;
              this.updateLayoutDraft((draft: BookshelfLayoutSettings) => { draft.bookshelfCardColor = bookshelfCardHexToInt(value); });
            })
          this.ColorPickerRow('夜间卡片底色', this.nightCardColorHex,
            (value: string) => {
              this.nightCardColorHex = value;
              this.updateLayoutDraft((draft: BookshelfLayoutSettings) => { draft.bookshelfCardColorDark = bookshelfCardHexToInt(value); });
            })
          this.LayoutStepperRow('网格封面宽度', '书封在格子里最宽能到多少，格子更窄时以格子为准',
            this.layoutDraft.bookshelfGridCoverWidth, 40, 200,
            (delta: number) => { this.updateLayoutDraft((draft: BookshelfLayoutSettings) => { draft.bookshelfGridCoverWidth = Math.max(40, Math.min(200, draft.bookshelfGridCoverWidth + delta * 10)); }); })
          this.LayoutStepperRow('列表封面宽度', '列表模式下书封宽度',
            this.layoutDraft.bookshelfListCoverWidth, 40, 200,
            (delta: number) => { this.updateLayoutDraft((draft: BookshelfLayoutSettings) => { draft.bookshelfListCoverWidth = Math.max(40, Math.min(200, draft.bookshelfListCoverWidth + delta * 10)); }); })
          // 列表模式详情开关：只在列表卡片里被读，网格分支不读。
          this.LayoutSwitchRow('（列表模式）显示简介', '列表卡片右侧显示书籍简介',
            this.layoutDraft.bookshelfShowIntro,
            (value: boolean) => { this.updateLayoutDraft((draft: BookshelfLayoutSettings) => { draft.bookshelfShowIntro = value; }); })
          this.LayoutSwitchRow('（列表模式）显示最新章节', '列表卡片右侧显示最新章节名',
            this.layoutDraft.bookshelfShowLatestChapter,
            (value: boolean) => { this.updateLayoutDraft((draft: BookshelfLayoutSettings) => { draft.bookshelfShowLatestChapter = value; }); })
          this.LayoutSwitchRow('书封阴影', '', this.layoutDraft.bookshelfCoverShadow,
            (value: boolean) => { this.updateLayoutDraft((draft: BookshelfLayoutSettings) => { draft.bookshelfCoverShadow = value; }); })

          this.LayoutSectionHeader('其它')
          this.LayoutSwitchRow('搜索按钮优先打开搜索页', '关闭后单击先进筛选、长按进搜索页',
            this.layoutDraft.bookshelfSearchActionDirectToSearch,
            (value: boolean) => { this.updateLayoutDraft((draft: BookshelfLayoutSettings) => { draft.bookshelfSearchActionDirectToSearch = value; }); })
          this.LayoutSwitchRow('显示快速滚动条', '书架右侧出现可拖动滚动条',
            this.layoutDraft.showBookshelfFastScroller,
            (value: boolean) => { this.updateLayoutDraft((draft: BookshelfLayoutSettings) => { draft.showBookshelfFastScroller = value; }); })
        }.width('100%').padding({ bottom: 24 })
      }.layoutWeight(1).scrollBar(BarState.Off)
    }.width('100%').height('100%').backgroundColor('#17181E')
  }

  /**
   * 书架上的半模态面板统一入口。
   *
   * 同一组件挂多个 bindSheet 只有最后一个生效（本项目已踩过的坑），
   * 所以布局面板与分组面板共用同一个 sheet，按状态分发内容。
   */
  @Builder
  private ShelfSheetContent() {
    if (this.showLayoutSheet) {
      this.LayoutSheetContent()
    } else {
      this.GroupManagerSheet()
    }
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
        .onClick(() => this.openLayoutSheet())
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
    }.backgroundColor(this.themeAppBackground.length > 0 ? Color.Transparent : (this.themePureBlack ? '#121212' : this.themeColorSurfaceElevated)).fontColor(this.themeColorTextPrimary).radius(20)
  }

  build() {
    Column() {
      Row() {
        if (this.collapsedHeader) {
          Text('书架').fontSize(20).fontWeight(FontWeight.Medium).fontColor(this.themeColorTextPrimary)
        }
        Blank()
        Stack({ alignContent: Alignment.Center }) { AppGlyph({ name: 'search', glyphSize: 20 }) }.width(36).height(36).backgroundColor(this.themeAppBackground.length > 0 ? Color.Transparent : (this.themePureBlack ? '#121212' : this.themeColorSurfaceElevated)).borderRadius(20)
          .onClick(() => {
            if (this.layout.bookshelfSearchActionDirectToSearch) {
              this.onSearch();
            } else {
              this.showSearch = !this.showSearch;
              if (!this.showSearch) { this.searchQuery = ''; }
            }
          })
          .priorityGesture(LongPressGesture({ duration: 500 }).onAction((_event: GestureEvent): void => {
            if (this.layout.bookshelfSearchActionDirectToSearch) {
              this.showSearch = !this.showSearch;
              if (!this.showSearch) { this.searchQuery = ''; }
            } else {
              this.onSearch();
            }
          }))
        Stack({ alignContent: Alignment.Center }) { AppGlyph({ name: 'more', glyphSize: 20 }) }
          .width(36).height(36).backgroundColor(this.themeAppBackground.length > 0 ? Color.Transparent : (this.themePureBlack ? '#121212' : this.themeColorSurfaceElevated)).borderRadius(20).margin({ left: 8 })
          .bindMenu(this.MoreMenu, { placement: Placement.BottomRight })
      }.width('100%').height(56).padding({ left: 16, right: 16, top: 10, bottom: 0 })
      Row() {
        Text('书架').fontSize(28).fontWeight(FontWeight.Bold).fontColor(this.themeColorTextPrimary)
      }.width('100%').height(this.collapsedHeader ? 0 : 58)
        .padding({ left: 16, right: 16, bottom: this.collapsedHeader ? 0 : 18 })
        .opacity(this.collapsedHeader ? 0 : 1)
        .animation({ duration: 220, curve: Curve.EaseInOut })

      if (this.showSearch) {
        Row() {
          AppGlyph({ name: 'search', glyphSize: 17 }).margin({ right: 9 })
          TextInput({ placeholder: '搜索书名或作者…', text: this.searchQuery })
            .fontSize(16).fontColor(this.themeColorTextSecondary).placeholderColor(this.themeColorTextTertiary)
            .backgroundColor(Color.Transparent).layoutWeight(1)
            .onChange((value: string) => this.searchQuery = value)
        }.width('100%').padding({ left: 14, right: 14, top: 9, bottom: 9 })
          .margin({ left: 16, right: 16, bottom: 10 }).backgroundColor(this.themeAppBackground.length > 0 ? Color.Transparent : (this.themePureBlack ? '#121212' : this.themeColorSurfaceElevated)).borderRadius(22).backgroundImage(this.themeItemBackground.length > 0 ? `file://${this.themeItemBackground}` : $r('app.media.transparent_pixel'), ImageRepeat.NoRepeat)
      }

      // 分组样式为「文件夹」时：根层显示分组卡片，点进分组后顶部给一条返回入口。
      if (this.layout.bookGroupStyle === 2) {
        Row() {
          if (this.folderViewGroup.length > 0) {
            Text('‹ 返回文件夹').fontSize(12).fontColor(this.themeColorAccent).padding(6)
              .onClick(() => { this.backToFolderRoot(); })
          }
          Text(this.folderViewGroup.length > 0 ? `当前分组：${this.folderViewGroup}` : '文件夹（点卡片进入分组）')
            .fontSize(12).fontColor(this.themeColorTextTertiary).layoutWeight(1)
        }.width('100%').padding({ left: 16, right: 16, bottom: 10 })
      } else if (this.layout.bookGroupStyle === 0) {
        // 分组样式为「隐藏页签」时不渲染顶部筛选栏，切换分组改由分组管理面板完成。
        Row() {
          ForEach(this.getGroupNames(), (groupName: string) => {
            ShelfFilter({ label: groupName, selected: this.activeFilter() === groupName })
              .onClick(async () => { await this.selectGroup(groupName); })
          }, (groupName: string) => groupName)
        }.width('100%').padding({ left: 12, right: 12, bottom: 14 })
      } else {
        Row() {
          Text(`当前分组：${this.activeFilter()}`).fontSize(12).fontColor(this.themeColorTextTertiary).layoutWeight(1)
          Text('切换分组').fontSize(12).fontColor(this.themeColorAccent).padding(6)
            .onClick(() => { this.showGroupEditor = false; this.showGroupManager = true; })
        }.width('100%').padding({ left: 16, right: 16, bottom: 10 })
      }
      if (this.layout.bookGroupStyle === 2 && this.folderViewGroup.length === 0) {
        // 文件夹根层：分组卡片网格，列数按横竖屏各取一套（KI-SL-C2）。
        Grid() {
          ForEach(this.getFolderGroups(), (groupName: string) => {
            GridItem() {
              BookGroupCard({
                groupName: groupName,
                books: this.getFolderPreviewBooks(groupName),
                coverCount: this.layout.bookshelfGroupCoverCount,
                listStyle: this.layout.bookshelfGroupListStyle,
                coverSettings: this.coverSettings,
                isNight: this.readerNightMode,
                onOpen: () => { this.openFolderGroup(groupName); }
              })
            }
          }, (groupName: string) => `folder_${groupName}_${this.getFolderPreviewBooks(groupName).length}_${this.layout.bookshelfGroupCoverCount}_${this.layout.bookshelfGroupListStyle}_${this.activeLayoutMode()}`)
        }
        .columnsTemplate(this.folderColumnsTemplate())
        .rowsGap(BOOKSHELF_GRID_GAP).columnsGap(BOOKSHELF_GRID_GAP).width('100%')
        .padding({ left: BOOKSHELF_GRID_PADDING, right: BOOKSHELF_GRID_PADDING })
        .layoutWeight(1).scrollBar(BarState.Off)
      } else if (this.getVisibleBooks().length > 0) {
        Grid(this.bookshelfScroller) {
          ForEach(this.getVisibleBooks(), (book: Book) => {
            GridItem() {
              Column() {
                if (this.activeLayoutMode() === 0) {
                  // 列表模式卡片：左封面右信息（上游 BookItem.kt:846 BookshelfListItem）。
                  // 封面宽度只认 bookshelfListCoverWidth；网格封面宽度不参与本分支。
                  Row() {
                    BookCover({
                      book: book,
                      compact: true,
                      showChapterBadge: true,
                      shadowEnabled: this.layout.bookshelfCoverShadow,
                      fillWidth: false,
                      displayWidth: this.layout.bookshelfListCoverWidth,
                      displayHeight: Math.round(this.layout.bookshelfListCoverWidth * 7 / 5),
                      coverSettings: this.coverSettings,
                      isNight: this.readerNightMode
                    })
                    Column() {
                      Text(book.title)
                        .fontSize(this.bookshelfTitleFontSize())
                        .fontColor(this.themeColorTextSecondary)
                        .maxLines(this.layout.bookshelfTitleMaxLines)
                        .textOverflow({ overflow: TextOverflow.Ellipsis })
                        .width('100%')
                        .textAlign(this.layout.bookshelfTitleCenter ? TextAlign.Center : TextAlign.Start)
                      // 列表详情：精简模式下整块不渲染（对齐上游 BookItem.kt:230 的 !isCompact）。
                      // 简介行数固定 2 行作版式常量，不读 bookshelfIntroMaxLines（该字段属 KI-SL-N1 不接范围）。
                      if (!this.layout.bookshelfLayoutCompact && this.layout.bookshelfShowIntro) {
                        Text(book.description ?? '')
                          .fontSize(11).fontColor(this.themeColorTextTertiary)
                          .maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
                          .width('100%')
                          .textAlign(TextAlign.Start)
                      }
                      if (!this.layout.bookshelfLayoutCompact && this.layout.bookshelfShowLatestChapter) {
                        Text(book.lastChapter)
                          .fontSize(11).fontColor(this.themeColorTextTertiary)
                          .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
                          .width('100%')
                          .textAlign(TextAlign.Start)
                      }
                    }.layoutWeight(1).alignItems(HorizontalAlign.Start)
                      .padding({ left: 8, right: 4 })
                  }.width('100%').alignItems(VerticalAlign.Top)
                } else {
                Stack({ alignContent: Alignment.Bottom }) {
                  BookCover({
                    book: book,
                    compact: true,
                    showChapterBadge: true,
                    shadowEnabled: this.layout.bookshelfCoverShadow,
                    fillWidth: true,
                    maxWidth: this.bookshelfCoverWidthLimit(),
                    coverSettings: this.coverSettings,
                    isNight: this.readerNightMode
                  })
                  if (this.layout.bookshelfGridLayout === 1) {
                    // 紧凑样式：书名移进封面内底部，白字配渐变黑底（上游 BookItem.kt:110-133）
                    Text(book.title).fontSize(this.bookshelfTitleFontSize()).fontColor('#FFFFFFFF')
                      .maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
                      .width('100%')
                      .textAlign(this.layout.bookshelfTitleCenter ? TextAlign.Center : TextAlign.Start)
                      .padding({ left: 4, right: 4, top: 14, bottom: 4 })
                      .linearGradient(this.coverTitleGradient())
                  }
                }.width('100%')
                if (this.layout.bookshelfGridLayout === 0) {
                  Text(book.title).fontSize(this.bookshelfTitleFontSize()).fontColor(this.themeColorTextSecondary)
                    .maxLines(this.layout.bookshelfTitleMaxLines)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                    .width('100%')
                    .textAlign(this.layout.bookshelfTitleCenter ? TextAlign.Center : TextAlign.Start)
                    .padding({ left: 4, right: 4, bottom: 4 })
                  // 精简详情关闭时补作者行（上游 BookItem.kt:230 if (!isCompact) 才渲染副信息）
                  if (!this.layout.bookshelfLayoutCompact) {
                    Text(book.author).fontSize(11).fontColor(this.themeColorTextTertiary)
                      .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
                      .width('100%')
                      .textAlign(this.layout.bookshelfTitleCenter ? TextAlign.Center : TextAlign.Start)
                      .padding({ left: 4, right: 4, bottom: 4 })
                  }
                }
                }
              }.width('100%').alignItems(HorizontalAlign.Center)
                .backgroundColor(this.cardBackgroundColor())
                .borderRadius(8)
                .onClick(() => {
                  if (BookRepository.isBodyMissing(book)) {
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
        }
        .columnsTemplate(this.bookshelfColumnsTemplate())
        .rowsGap(BOOKSHELF_GRID_GAP).columnsGap(BOOKSHELF_GRID_GAP).width('100%')
        .padding({ left: BOOKSHELF_GRID_PADDING, right: BOOKSHELF_GRID_PADDING })
        .layoutWeight(1).scrollBar(this.layout.showBookshelfFastScroller ? BarState.On : BarState.Off)
          .onAreaChange((_oldArea: Area, newArea: Area) => {
            // 记下网格可用宽度，封面宽度按格子宽度换算（见 bookshelfCoverSlotWidth）
            const width = parseFloat(String(newArea.width));
            const height = parseFloat(String(newArea.height));
            if (Number.isFinite(width) && Math.abs(width - this.bookshelfGridWidth) > 0.5) {
              this.bookshelfGridWidth = width;
            }
            // 旋转会改变容器宽高，这里再兜底刷新一次方向（窗口尺寸回调之外的第二道保险）。
            if (Number.isFinite(width) && Number.isFinite(height)) {
              const landscape: boolean = width > height;
              if (landscape !== this.isLandscape) { this.isLandscape = landscape; }
            }
          })
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
          Text(this.emptyFace).fontSize(32).fontColor(this.themeColorTextSecondary).margin({ bottom: 14 })
            .onClick(() => {
              const currentIndex = this.emptyFaces.indexOf(this.emptyFace);
              this.emptyFace = this.emptyFaces[(currentIndex + 1) % this.emptyFaces.length];
            })
          Text(this.searchQuery.length > 0 ? '没有匹配的书籍' : this.books.length === 0
            ? '书架还空着，先去搜索书籍或从发现里添加吧！' : '这个分组还没有书籍')
            .width(220).fontSize(11).fontColor(this.themeColorTextSecondary).textAlign(TextAlign.Center).maxLines(2)
          if (this.searchQuery.length > 0) {
            Text('全局搜索').fontSize(13).fontColor(this.themeColorAccent)
              .padding({ left: 16, right: 16, top: 8, bottom: 8 }).margin({ top: 14 })
              .backgroundColor(this.themeAppBackground.length > 0 ? Color.Transparent : (this.themePureBlack ? '#121212' : this.themeColorSurfaceElevated))
              .borderRadius(18)
              .onClick(() => this.onSearch())
          }
        }.layoutWeight(1).width('100%').padding({ bottom: 104 }).justifyContent(FlexAlign.Center)
      }
    }.width('100%').height('100%').backgroundColor(this.themeAppBackground.length > 0 ? Color.Transparent : (this.themePureBlack ? '#000000' : this.themeColorSurfacePrimary))
      .bindSheet(this.showGroupManager || this.showLayoutSheet, this.ShelfSheetContent(), {
        height: SheetSize.LARGE, dragBar: true, showClose: false, backgroundColor: '#17181E'
      })
  }
}

@Component
struct ShelfFilter {
  @StorageProp('themeColorAccent') themeColorAccent: string = '#3F5BD9';
  @Prop label: string = '';
  @Prop selected: boolean = false;
  build() {
    Column() {
      Text(this.label).fontSize(12).fontColor(this.selected ? '#C4D1FF' : '#B6B8C2').padding({ left: 7, right: 7, top: 7, bottom: 7 })
      Row().width(42).height(2).backgroundColor(this.themeColorAccent).borderRadius(1)
        .opacity(this.selected ? 1 : 0)
        .animation({ duration: 180, curve: Curve.EaseInOut })
    }.layoutWeight(1).alignItems(HorizontalAlign.Center)
  }
}






