import { pasteboard } from '@kit.BasicServicesKit';
import { Book } from '../../model/Book';
import { BookGroup, BookGroupDraft, BOOK_SORT_OPTIONS, BookSortOption, bookSortLabel } from '../../model/BookGroup';
import { TagGroupRule } from '../../model/TagGroupRule';
import { TagGroupRuleRepository } from '../../data/TagGroupRuleRepository';
import { AppGlyph } from '../AppGlyph';
import { UiSwitchControl } from '../UiSwitchControl';
import { UiMenuItem, UiMenuPanel } from '../UiMenu';
import { BODY_SMALL, LABEL_LARGE, LABEL_MEDIUM, LABEL_SMALL, TITLE_LARGE, TITLE_MEDIUM, TITLE_SMALL } from '../typography/TypographyTokens';

const EDITOR_MENU_WIDTH: number = 220;

/**
 * 分组编辑面板：新建与编辑共用一套表单。
 *
 * 上游 `ui/book/info/BookInfoSheets.kt:108-190` 的 `GroupSelectSheet` 里，
 * 「新建分组」与每行的「编辑」都指向**同一个** `GroupEditSheet`
 * （`GroupEditSheet(show = showAddGroup || editingGroup != null, group = editingGroup, ...)`）。
 * 本地原先这份表单内联在 `BookshelfPage` 里，书架管理页要用就得复制一份；
 * 按上游口径抽成独立组件，两个宿主共用同一实现。
 *
 * 组件自管草稿态（名称/排序/刷新/隐私/封面/标签规则），宿主只负责落库与回调。
 */
@Component
export struct GroupEditorSheet {
  /** 编辑目标；`undefined` 表示新建。 */
  @Prop @Watch('onEditingGroupChanged') editingGroup: BookGroup | undefined = undefined;
  /** 书架全部书籍，仅用于删除前统计该分组下的书数。 */
  @Prop books: Book[] = [];

  onSave: (groupId: number, draft: BookGroupDraft) => Promise<void> = async () => {};
  onChooseCover: (groupId: number) => Promise<string> = async () => '';
  onChooseCoverDraft: () => Promise<string> = async () => '';
  onClearCover: (groupId: number) => Promise<void> = async () => {};
  onRemove: (groupId: number) => void = () => {};
  onCancel: () => void = () => {};
  onMessage: (message: string) => void = () => {};
  onApplyTagGroupRules: () => Promise<void> = async () => {};

  @StorageProp('themeColorTextPrimary') themeColorTextPrimary: string = '#ECEEF2';
  @StorageProp('themeColorTextSecondary') themeColorTextSecondary: string = '#C5C7D0';
  @StorageProp('themeColorTextTertiary') themeColorTextTertiary: string = '#8B8D98';
  @StorageProp('themeColorAccent') themeColorAccent: string = '#B9C8FF';
  @StorageProp('themeColorSurfaceElevated') themeColorSurfaceElevated: string = '#23242B';

  @State private draftName: string = '';
  @State private draftSort: number = -1;
  @State private draftRefresh: boolean = true;
  @State private draftPrivate: boolean = false;
  @State private draftCover: string = '';
  @State private draftRuleEnabled: boolean = false;
  @State private draftRulePattern: string = '';
  @State private showRulePasteAuthorization: boolean = false;
  @State private sortMenuVisible: boolean = false;
  @State private pendingDeleteGroupId: number = -1;
  @State private showDisablePrivateConfirm: boolean = false;

  aboutToAppear(): void {
    this.loadDraft();
  }

  /** 编辑目标切换时重新灌草稿（宿主可能在面板常驻时换目标）。 */
  onEditingGroupChanged(): void {
    this.loadDraft();
  }

  private editingGroupIdOf(): number {
    const group = this.editingGroup;
    return group !== undefined ? group.groupId : -1;
  }

  private isEditing(): boolean {
    return this.editingGroupIdOf() > 0;
  }

  private loadDraft(): void {
    this.draftRuleEnabled = false;
    this.draftRulePattern = '';
    this.showRulePasteAuthorization = false;
    this.pendingDeleteGroupId = -1;
    this.showDisablePrivateConfirm = false;
    this.sortMenuVisible = false;
    const group = this.editingGroup;
    if (group === undefined) {
      this.draftName = '';
      this.draftSort = -1;
      this.draftRefresh = true;
      this.draftPrivate = false;
      this.draftCover = '';
      return;
    }
    this.draftName = group.groupName;
    this.draftSort = group.bookSort;
    this.draftRefresh = group.enableRefresh;
    this.draftPrivate = group.isPrivate;
    this.draftCover = group.cover ?? '';
    // 标签规则不在分组表里，单独存在 tag_group_rules，按同名回填。
    void this.loadRuleDraft(group.groupName);
  }

  private async loadRuleDraft(groupName: string): Promise<void> {
    const context = this.getUIContext().getHostContext();
    if (context === undefined) {
      return;
    }
    try {
      const rules = await TagGroupRuleRepository.load(context);
      const matched = rules.find((rule: TagGroupRule) => rule.groupName === groupName);
      if (matched !== undefined) {
        this.draftRuleEnabled = true;
        this.draftRulePattern = matched.pattern;
      }
    } catch (error) {
      // 规则读不出来只是回填不到，不影响编辑其它字段。
    }
  }

  /**
   * 关闭隐私分组要先二次确认：关闭后本组书籍会重新出现在公开书架。
   * 只有「原本就是隐私」的分组需要拦，新建时开关是自由切换的。
   */
  private toggleDraftPrivate(enabled: boolean): void {
    const group = this.editingGroup;
    if (!enabled && group !== undefined && group.isPrivate) {
      this.showDisablePrivateConfirm = true;
      return;
    }
    this.draftPrivate = enabled;
  }

  private async submitDraft(): Promise<void> {
    const name = this.draftName.trim();
    if (name.length === 0) {
      this.onMessage('分组名称不能为空');
      return;
    }
    const pattern = this.draftRulePattern.trim();
    if (this.draftRuleEnabled && pattern.length > 0) {
      // 先编译一次，正则写错在保存时就报出来，不留到自动分组时才炸。
      try {
        new RegExp(pattern);
      } catch (error) {
        this.onMessage('正则表达式不合法');
        return;
      }
    }
    const draft: BookGroupDraft = {
      groupName: name,
      enableRefresh: this.draftRefresh,
      bookSort: this.draftSort,
      isPrivate: this.draftPrivate,
      cover: this.draftCover.length > 0 ? this.draftCover : undefined
    };
    const groupId = this.editingGroupIdOf();
    try {
      await this.onSave(groupId, draft);
    } catch (error) {
      this.onMessage('保存分组失败');
      return;
    }
    await this.saveRuleDraft(name, pattern);
    await this.onApplyTagGroupRules();
  }

  /** 标签规则落库：启用且有正则则新增或覆盖同名规则，关闭则删掉同名规则。 */
  private async saveRuleDraft(groupName: string, pattern: string): Promise<void> {
    const context = this.getUIContext().getHostContext();
    if (context === undefined) {
      return;
    }
    try {
      const rules = await TagGroupRuleRepository.load(context);
      const index = rules.findIndex((rule: TagGroupRule) => rule.groupName === groupName);
      const next: TagGroupRule[] = rules.slice(0);
      if (this.draftRuleEnabled && pattern.length > 0) {
        if (index >= 0) {
          next[index] = { id: rules[index].id, pattern: pattern, groupName: groupName, order: rules[index].order };
        } else {
          next.push({ id: Date.now(), pattern: pattern, groupName: groupName, order: rules.length });
        }
      } else if (index >= 0) {
        next.splice(index, 1);
      } else {
        return;
      }
      await TagGroupRuleRepository.save(context, next);
    } catch (error) {
      this.onMessage('标签规则保存失败');
    }
  }

  private copyRule(): void {
    const rule: TagGroupRule = {
      id: 0,
      pattern: this.draftRulePattern,
      groupName: this.draftName.trim(),
      order: 0
    };
    const data = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, JSON.stringify(rule));
    pasteboard.getSystemPasteboard().setData(data).then(() => {
      this.onMessage('规则已复制');
    }).catch(() => {
      this.onMessage('规则复制失败');
    });
  }

  private async pasteRule(result: PasteButtonOnClickResult): Promise<void> {
    if (result !== PasteButtonOnClickResult.SUCCESS) {
      this.onMessage('未获得剪贴板授权');
      return;
    }
    try {
      const data = await pasteboard.getSystemPasteboard().getData();
      if (data.getRecordCount() === 0) {
        this.onMessage('剪贴板为空');
        return;
      }
      const parsed = JSON.parse(data.getRecord(0).toPlainText()) as TagGroupRule;
      if (typeof parsed.pattern === 'string') {
        this.draftRulePattern = parsed.pattern;
      }
    } catch (error) {
      this.onMessage('粘贴的规则格式不正确');
    }
  }

  private sortMenuItems(): UiMenuItem[] {
    return BOOK_SORT_OPTIONS.map((option: BookSortOption): UiMenuItem => {
      return { key: `${option.value}`, title: option.label, selected: option.value === this.draftSort };
    });
  }

  /** 删除分组：首次点变成「确认删除」，再点才真删，并算清这个组里有多少本书。 */
  private onDeleteClick(): void {
    const groupId = this.editingGroupIdOf();
    if (this.pendingDeleteGroupId !== groupId) {
      this.pendingDeleteGroupId = groupId;
      return;
    }
    const removed = this.editingGroup;
    const count = removed !== undefined
      ? this.books.filter((book: Book) => (book.groupNames ?? []).includes(removed.groupName)).length
      : 0;
    this.getUIContext().showAlertDialog({
      title: '删除分组',
      message: `该分组下的 ${count} 本书会移出到未分组`,
      autoCancel: true,
      primaryButton: { value: '取消', action: () => {} },
      secondaryButton: {
        value: '删除',
        action: () => {
          this.onRemove(groupId);
          this.pendingDeleteGroupId = -1;
        }
      }
    });
  }

  @Builder
  private SortMenu() {
    UiMenuPanel({
      items: this.sortMenuItems(),
      panelWidth: EDITOR_MENU_WIDTH,
      onSelect: (key: string) => {
        this.sortMenuVisible = false;
        this.draftSort = Number(key);
      }
    })
  }

  @Builder
  private DisablePrivateConfirm() {
    Column() {
      Text('关闭隐私分组').fontSize(TITLE_MEDIUM).fontColor(this.themeColorTextPrimary).width('100%')
      Text('关闭后，本组书籍可能在公开书架中显示，是否确认关闭？')
        .fontSize(BODY_SMALL).fontColor(this.themeColorTextSecondary).width('100%').margin({ top: 8 })
      Row() {
        Text('取消').fontSize(LABEL_LARGE).fontColor(this.themeColorTextTertiary).padding(8)
          .onClick(() => this.showDisablePrivateConfirm = false)
        Blank()
        Text('确认关闭').fontSize(LABEL_LARGE).fontColor('#D99AA5').padding(8)
          .onClick(() => {
            this.draftPrivate = false;
            this.showDisablePrivateConfirm = false;
          })
      }.width('100%').margin({ top: 12 })
    }
    .constraintSize({ maxWidth: 320 })
    .padding(18)
    .backgroundColor(this.themeColorSurfaceElevated)
    .borderRadius(12)
  }

  build() {
    Stack() {
      Column() {
        Row() {
          Text(this.isEditing() ? '编辑分组' : '新建分组')
            .fontSize(TITLE_LARGE).fontWeight(FontWeight.Medium).fontColor(this.themeColorTextPrimary).layoutWeight(1)
          // 上游编辑态的 endAction 是 GroupResetCoverAction（GroupManageSheet.kt:190-199），
          // 选了封面才出现，点一下清空封面。
          if (this.draftCover.length > 0) {
            Text('清除封面').fontSize(LABEL_LARGE).fontColor('#D99AA5').padding(8)
              .onClick(async () => {
                const groupId = this.editingGroupIdOf();
                if (groupId > 0) {
                  await this.onClearCover(groupId);
                }
                this.draftCover = '';
              })
          }
          Text('保存').fontSize(LABEL_LARGE).fontColor('#B9C8FF').padding(8)
            .onClick(async () => { await this.submitDraft(); })
          Text('取消').fontSize(LABEL_LARGE).fontColor(this.themeColorTextTertiary).padding(8)
            .onClick(() => this.onCancel())
        }.width('100%').padding({ left: 18, right: 12, top: 14, bottom: 10 })

        Scroll() {
          Column() {
            // C-2：上游 GroupEditSheet.kt:154-176 是
            // Row(fillMaxWidth(), Alignment.Top, spacedBy(16.dp)){ CoilBookCover(width=96.dp)
            //   .clickable{ selectImage.launch() }; Column(weight(1f), spacedBy(8.dp)){ 分组名称输入; 排序下拉 } }。
            // 即封面 96dp 宽、与右侧表单并排，不是上下堆叠。
            Row() {
              Stack({ alignContent: Alignment.Center }) {
                if (this.draftCover.length > 0) {
                  Image(this.draftCover).width('100%').height('100%').borderRadius(4).objectFit(ImageFit.Cover)
                } else {
                  AppGlyph({ name: 'add', glyphSize: 24, tint: this.themeColorTextTertiary })
                }
              }
              .width(96).aspectRatio(5 / 7).backgroundColor('#22232A').borderRadius(4)
              .onClick(async () => {
                // E-4：上游的 coverPath 是草稿态，新建分组也能先选封面，保存时一起落库。
                // 已保存的分组走落库接口，未保存的走只复制不写表的草稿接口。
                const groupId = this.editingGroupIdOf();
                if (groupId > 0) {
                  const cover = await this.onChooseCover(groupId);
                  if (cover.length > 0) {
                    this.draftCover = cover;
                  }
                } else {
                  const draft = await this.onChooseCoverDraft();
                  if (draft.length > 0) {
                    this.draftCover = draft;
                  }
                }
              })

              Column() {
                TextInput({ text: this.draftName, placeholder: '分组名称' }).width('100%').height(40)
                  .fontSize(TITLE_SMALL).fontColor(this.themeColorTextPrimary).placeholderColor(this.themeColorTextTertiary)
                  .backgroundColor('#22232A').borderRadius(9)
                  .onChange((value: string) => this.draftName = value)

                Row() {
                  Text('排序').fontSize(TITLE_SMALL).fontColor(this.themeColorTextSecondary).layoutWeight(1)
                  Text(bookSortLabel(this.draftSort)).fontSize(TITLE_SMALL).fontColor(this.themeColorAccent)
                    .onClick(() => { this.sortMenuVisible = !this.sortMenuVisible; })
                    .bindPopup(this.sortMenuVisible, {
                      builder: this.SortMenu,
                      placement: Placement.Bottom,
                      popupColor: '#00000000',
                      enableArrow: false,
                      autoCancel: true,
                      width: EDITOR_MENU_WIDTH,
                      onStateChange: (event: PopupStateChangeParam) => { this.sortMenuVisible = event.isVisible; }
                    })
                }.width('100%').height(40).padding({ left: 12, right: 12 })
                  .backgroundColor('#22232A').borderRadius(9).margin({ top: 8 })
              }.layoutWeight(1).alignItems(HorizontalAlign.Start).margin({ left: 16 })
            }.width('100%').alignItems(VerticalAlign.Top).padding({ left: 16, right: 16, top: 12, bottom: 12 })

            Row() {
              Column() {
                Text('下拉刷新').fontSize(TITLE_SMALL).fontColor(this.themeColorTextSecondary)
                Text('关闭后该分组的下拉刷新不触发；仅对本地 TXT 生效')
                  .fontSize(LABEL_SMALL).fontColor(this.themeColorTextTertiary).margin({ top: 3 })
              }.alignItems(HorizontalAlign.Start).layoutWeight(1)
              UiSwitchControl({
                checked: this.draftRefresh,
                interactive: false,
                onChange: (enabled: boolean) => this.draftRefresh = enabled
              })
            }.width('100%').padding({ left: 16, right: 16, top: 10, bottom: 10 })
            .onClick(() => this.draftRefresh = !this.draftRefresh)

            // 隐私分组（GroupEditSheet.kt:202-217）：标题与副标题照上游 private_group /
            // private_group_desc；关闭一个「原本就是隐私」的分组要先二次确认，
            // 因为关闭后本组书籍会重新出现在公开书架。
            Row() {
              Column() {
                Text('设为隐私分组').fontSize(TITLE_SMALL).fontColor(this.themeColorTextSecondary)
                Text('开启后，本分组内的书籍不会出现在公开书架，进入该分组需要验证。单本标记为私密的书不同：它仍留在书架上，封面与文字会被遮挡，验证后才显示。')
                  .fontSize(LABEL_SMALL).fontColor(this.themeColorTextTertiary).margin({ top: 3 })
              }.alignItems(HorizontalAlign.Start).layoutWeight(1)
              UiSwitchControl({
                checked: this.draftPrivate,
                interactive: false,
                onChange: (enabled: boolean) => this.toggleDraftPrivate(enabled)
              })
            }.width('100%').padding({ left: 16, right: 16, top: 10, bottom: 10 })
            .onClick(() => this.toggleDraftPrivate(!this.draftPrivate))

            // 标签匹配规则（:249 / :250）：本地不另建独立规则面板，开关与多行输入框
            // 直接放在分组编辑面板里，对应上游 GroupEditSheet.kt:221-238。
            Row() {
              Column() {
                Text('标签匹配规则').fontSize(TITLE_SMALL).fontColor(this.themeColorTextSecondary)
                Text(this.draftRuleEnabled ? '启用后分组将根据书籍标签自动匹配' : '关闭后分组为手动管理')
                  .fontSize(LABEL_SMALL).fontColor(this.themeColorTextTertiary).margin({ top: 3 })
              }.alignItems(HorizontalAlign.Start).layoutWeight(1)
              UiSwitchControl({
                checked: this.draftRuleEnabled,
                interactive: false,
                onChange: (enabled: boolean) => this.draftRuleEnabled = enabled
              })
            }.width('100%').padding({ left: 16, right: 16, top: 10, bottom: 10 })
            .onClick(() => this.draftRuleEnabled = !this.draftRuleEnabled)

            if (this.draftRuleEnabled) {
              Column() {
                TextArea({ placeholder: '匹配标签的正则表达式', text: this.draftRulePattern })
                  .fontSize(TITLE_SMALL).fontColor(this.themeColorTextPrimary)
                  .placeholderColor(this.themeColorTextTertiary)
                  .height(96).backgroundColor('#22232A').borderRadius(9).padding(10)
                  .width('100%')
                  .onChange((value: string) => this.draftRulePattern = value)
                Row() {
                  Text('复制').fontSize(LABEL_MEDIUM).fontColor(this.themeColorAccent).padding({ right: 16 })
                    .onClick(() => { this.copyRule(); })
                  Text('粘贴').fontSize(LABEL_MEDIUM).fontColor(this.themeColorAccent)
                    .onClick(() => this.showRulePasteAuthorization = true)
                  Blank()
                }.width('100%').padding({ top: 8 })
                // 读剪贴板需要 PasteButton 授权，不能裸调 getData()。
                if (this.showRulePasteAuthorization) {
                  PasteButton({ text: PasteDescription.PASTE, buttonType: ButtonType.Capsule })
                    .onClick(async (_event: ClickEvent, result: PasteButtonOnClickResult) => {
                      await this.pasteRule(result);
                      this.showRulePasteAuthorization = false;
                    })
                }
              }.width('100%').padding({ left: 16, right: 16, top: 4, bottom: 10 })
                .alignItems(HorizontalAlign.Start)
            }

            if (this.isEditing()) {
              Row() {
                Text(this.pendingDeleteGroupId === this.editingGroupIdOf() ? '确认删除' : '删除分组')
                  .fontSize(LABEL_LARGE).fontColor('#D99AA5').layoutWeight(1)
                  .onClick(() => this.onDeleteClick())
                if (this.pendingDeleteGroupId === this.editingGroupIdOf()) {
                  Text('取消').fontSize(LABEL_MEDIUM).fontColor(this.themeColorTextTertiary).padding({ left: 12 })
                    .onClick(() => this.pendingDeleteGroupId = -1)
                }
              }.width('100%').padding({ left: 16, right: 16, top: 16, bottom: 16 })
            }
          }.width('100%')
        }.edgeEffect(EdgeEffect.None).layoutWeight(1).scrollBar(BarState.Off)
      }.width('100%').height('100%').backgroundColor('#17181E')

      // 关闭隐私分组确认：浮在编辑面板之上（上游 GroupEditSheet.kt:301-311 是 AlertDialog）。
      if (this.showDisablePrivateConfirm) {
        Column() {
          this.DisablePrivateConfirm()
        }
        .width('100%').height('100%')
        .backgroundColor('#66000000')
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
      }
    }.width('100%').height('100%')
  }
}
