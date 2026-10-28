import { Book } from '../model/Book';
import { BookGroup, BookGroupDraft, BOOK_SORT_OPTIONS, BookSortOption, bookSortLabel } from '../model/BookGroup';
import {
  BookshelfLayoutSettings, BookshelfLayoutOption, DEFAULT_BOOKSHELF_LAYOUT,
  BOOKSHELF_LAYOUT_MODE_OPTIONS, BOOKSHELF_SORT_ORDER_OPTIONS,
  bookshelfLayoutOptionLabel, copyBookshelfLayout
} from '../model/BookshelfLayout';
import { BookshelfSort } from '../data/BookshelfSort';
import { BookCover } from '../components/BookCover';
import { AppGlyph } from '../components/AppGlyph';

@Component
export struct BookshelfPage {
  @Prop books: Book[] = [];
  @Prop groups: BookGroup[] = [];
  /** 书架布局设置，来自 Index 的持久化状态。 */
  @Prop layout: BookshelfLayoutSettings = DEFAULT_BOOKSHELF_LAYOUT;
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
    }.backgroundColor('#1C1D23').fontColor('#E3E4E8').radius(20)
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
          .onClick(() => {
            this.selectedFilter = groupName;
            this.showGroupManager = false;
          })
      }, (groupName: string) => groupName)
    }.backgroundColor('#1C1D23').fontColor('#E3E4E8').radius(20)
  }

  /** 分组管理：自适应网格卡片，对应上游 LazyVerticalGrid(GridCells.Adaptive(160.dp))。 */
  @Builder
  private GroupManagerGrid() {
    Column() {
      Row() {
        Text('分组管理').fontSize(19).fontWeight(FontWeight.Medium).fontColor('#E3E4E8').layoutWeight(1)
        Text('新建').fontSize(14).fontColor('#B9C8FF').padding(8)
          .onClick(() => this.openGroupEditor(undefined))
        Text('完成').fontSize(14).fontColor('#B9C8FF').padding(8).onClick(() => this.showGroupManager = false)
      }.width('100%').padding({ left: 18, right: 12, top: 14, bottom: 10 })
      Row() {
        Text(`切换分组：${this.activeFilter()}`).fontSize(13).fontColor('#AFC2FF').layoutWeight(1)
          .bindMenu(this.GroupFilterMenu())
      }.width('100%').padding({ left: 18, right: 18, bottom: 10 })

      if (this.getUserGroups().length === 0) {
        Column() {
          Text('还没有自定义分组').fontSize(14).fontColor('#92949E')
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
                Text(group.groupName).fontSize(14).fontColor('#E3E4E8').maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                  .margin({ top: 10 }).width('100%')
                Text(`${bookSortLabel(group.bookSort)}${group.isPrivate ? ' · 私有标记未生效' : ''} · 分组刷新未接入`)
                  .fontSize(11).fontColor('#92949E').maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                  .margin({ top: 4 }).width('100%')
              }.width('100%').padding(12).backgroundColor('#1B1C22').borderRadius(14)
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
          .fontSize(19).fontWeight(FontWeight.Medium).fontColor('#E3E4E8').layoutWeight(1)
        Text('保存').fontSize(14).fontColor('#B9C8FF').padding(8)
          .onClick(async () => { await this.submitGroupDraft(); })
        Text('取消').fontSize(14).fontColor('#92949E').padding(8)
          .onClick(() => this.showGroupEditor = false)
      }.width('100%').padding({ left: 18, right: 12, top: 14, bottom: 10 })
      Scroll() {
        Column() {
          // 封面：点击选图，长按清除，与上游 GroupEditContent 的封面项一致。
          Row() {
            Text('封面').fontSize(14).fontColor('#D8D9E0').layoutWeight(1)
            Stack({ alignContent: Alignment.Center }) {
              if (this.draftCover.length > 0) {
                Image(this.draftCover).width(48).height(48).borderRadius(10).objectFit(ImageFit.Cover)
              } else {
                AppGlyph({ name: 'add', glyphSize: 18, tint: '#92949E' })
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
            Text('分组名称').fontSize(14).fontColor('#D8D9E0').width(88)
            TextInput({ text: this.draftName, placeholder: '分组名称' }).layoutWeight(1).height(40)
              .fontSize(14).fontColor('#E3E4E8').placeholderColor('#92949E')
              .backgroundColor('#22232A').borderRadius(9)
              .onChange((value: string) => this.draftName = value)
          }.width('100%').padding({ left: 16, right: 16, top: 8, bottom: 8 })

          Row() {
            Text('排序方式').fontSize(14).fontColor('#D8D9E0').layoutWeight(1)
            Text(bookSortLabel(this.draftSort)).fontSize(14).fontColor('#AFC2FF')
              .bindMenu(this.SortMenu())
          }.width('100%').padding({ left: 16, right: 16, top: 12, bottom: 12 })

          Row() {
            Column() {
              Text('下拉刷新').fontSize(14).fontColor('#D8D9E0')
              Text('仅保存 Android 兼容字段；当前不控制实际更新').fontSize(11).fontColor('#92949E').margin({ top: 3 })
            }.alignItems(HorizontalAlign.Start).layoutWeight(1)
            Toggle({ type: ToggleType.Switch, isOn: this.draftRefresh })
              .onChange((enabled: boolean) => this.draftRefresh = enabled)
          }.width('100%').padding({ left: 16, right: 16, top: 10, bottom: 10 })

          Row() {
            Column() {
              Text('私有分组').fontSize(14).fontColor('#D8D9E0')
              Text('仅保存兼容标记；当前不限制跨分组显示').fontSize(11).fontColor('#92949E').margin({ top: 3 })
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
                Text('取消').fontSize(13).fontColor('#92949E').padding({ left: 12 })
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

  /** 按 Android 书架设置选择列表或网格的列数。 */
  private bookshelfColumnsTemplate(): string {
    const configuredColumns = this.layout.bookshelfLayoutModePortrait === 1
      ? this.layout.bookshelfLayoutGridPortrait : this.layout.bookshelfLayoutListPortrait;
    const maximum = this.layout.bookshelfLayoutModePortrait === 1 ? 6 : 5;
    const columns = Math.max(1, Math.min(maximum, Math.round(configuredColumns)));
    const template: string[] = [];
    for (let index = 0; index < columns; index += 1) { template.push('1fr'); }
    return template.join(' ');
  }

  /** 打开布局面板：从已生效设置复制一份草稿，面板内改动只落到草稿。 */
  private openLayoutSheet(): void {
    this.layoutDraft = copyBookshelfLayout(this.layout);
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
        Text(title).fontSize(14).fontColor('#D8D9E0')
        if (description.length > 0) {
          Text(description).fontSize(11).fontColor('#92949E').margin({ top: 3 })
        }
      }.alignItems(HorizontalAlign.Start).layoutWeight(1)
      Text(bookshelfLayoutOptionLabel(options, current)).fontSize(14).fontColor('#AFC2FF')
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
    }.backgroundColor('#1C1D23').fontColor('#E3E4E8').radius(20)
  }

  /** 开关行。 */
  @Builder
  private LayoutSwitchRow(title: string, description: string, isOn: boolean, onToggle: (value: boolean) => void) {
    Row() {
      Column() {
        Text(title).fontSize(14).fontColor('#D8D9E0')
        if (description.length > 0) {
          Text(description).fontSize(11).fontColor('#92949E').margin({ top: 3 })
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
        Text(title).fontSize(14).fontColor('#D8D9E0')
        if (description.length > 0) {
          Text(description).fontSize(11).fontColor('#92949E').margin({ top: 3 })
        }
      }.alignItems(HorizontalAlign.Start).layoutWeight(1)
      Text('−').fontSize(18).fontColor(value > minimum ? '#AFC2FF' : '#4A4C55')
        .width(36).height(32).textAlign(TextAlign.Center)
        .onClick(() => { if (value > minimum) { onStep(-1); } })
      Text(`${value}`).fontSize(14).fontColor('#E3E4E8').width(34).textAlign(TextAlign.Center)
      Text('+').fontSize(18).fontColor(value < maximum ? '#AFC2FF' : '#4A4C55')
        .width(36).height(32).textAlign(TextAlign.Center)
        .onClick(() => { if (value < maximum) { onStep(1); } })
    }.width('100%').padding({ left: 16, right: 12, top: 10, bottom: 10 })
  }

  /** 分区标题，对应上游 PillHeaderDivider。 */
  @Builder
  private LayoutSectionHeader(title: string) {
    Row() {
      Text(title).fontSize(12).fontColor('#92949E')
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
        Text('书架布局').fontSize(19).fontWeight(FontWeight.Medium).fontColor('#E3E4E8').layoutWeight(1)
        Text('完成').fontSize(14).fontColor('#B9C8FF').padding(8)
          .onClick(async () => { await this.submitLayout(); })
      }.width('100%').padding({ left: 18, right: 12, top: 14, bottom: 6 })

      Scroll() {
        Column() {
          this.LayoutSectionHeader('分组')
          this.LayoutSwitchRow('隐藏分组页签', '开启后可在分组管理面板选择当前分组',
            this.layoutDraft.bookGroupStyle === 1,
            (hidden: boolean) => { this.updateLayoutDraft((draft: BookshelfLayoutSettings) => { draft.bookGroupStyle = hidden ? 1 : 0; }); })
          this.LayoutSwitchRow('隐藏没有书籍的分组', '页签只显示有书的分类',
            this.layoutDraft.hideEmptyGroups,
            (value: boolean) => { this.updateLayoutDraft((draft: BookshelfLayoutSettings) => { draft.hideEmptyGroups = value; }); })

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

          this.LayoutSectionHeader('外观')
          this.LayoutSwitchRow('书封阴影', '', this.layoutDraft.bookshelfCoverShadow,
            (value: boolean) => { this.updateLayoutDraft((draft: BookshelfLayoutSettings) => { draft.bookshelfCoverShadow = value; }); })
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

      // 分组样式为「隐藏页签」时不渲染顶部筛选栏，切换分组改由分组管理面板完成。
      if (this.layout.bookGroupStyle === 0) {
        Row() {
          ForEach(this.getGroupNames(), (groupName: string) => {
            ShelfFilter({ label: groupName, selected: this.activeFilter() === groupName })
              .onClick(() => this.selectedFilter = groupName)
          }, (groupName: string) => groupName)
        }.width('100%').padding({ left: 12, right: 12, bottom: 14 })
      } else {
        Row() {
          Text(`当前分组：${this.activeFilter()}`).fontSize(12).fontColor('#92949E').layoutWeight(1)
          Text('切换分组').fontSize(12).fontColor('#AFC2FF').padding(6)
            .onClick(() => { this.showGroupEditor = false; this.showGroupManager = true; })
        }.width('100%').padding({ left: 16, right: 16, bottom: 10 })
      }
      if (this.getVisibleBooks().length > 0) {
        Grid(this.bookshelfScroller) {
          ForEach(this.getVisibleBooks(), (book: Book) => {
            GridItem() {
              Column() {
                BookCover({
                  book: book,
                  compact: true,
                  showChapterBadge: true,
                  shadowEnabled: this.layout.bookshelfCoverShadow
                })
                Text(book.title).fontSize(13).fontColor('#D8D9E0')
                  .maxLines(this.layout.bookshelfTitleMaxLines)
                  .textOverflow({ overflow: TextOverflow.Ellipsis }).margin({ top: 7 })
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
        }
        .columnsTemplate(this.bookshelfColumnsTemplate())
        .rowsGap(16).columnsGap(10).width('100%').padding({ left: 14, right: 14 })
        .layoutWeight(1).scrollBar(BarState.Off)
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
      .bindSheet(this.showGroupManager || this.showLayoutSheet, this.ShelfSheetContent(), {
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






