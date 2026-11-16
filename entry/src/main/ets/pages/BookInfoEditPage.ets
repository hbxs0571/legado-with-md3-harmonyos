import { Book, BookMediaType } from '../model/Book';
import { BookGroup } from '../model/BookGroup';
import { AppTopBar, TopBarBackButton, TopBarButton } from '../components/TopBar';
import { BookCover } from '../components/BookCover';
import { AppGlyph, AppGlyphName } from '../components/AppGlyph';
import { CoverSettings, DEFAULT_COVER_SETTINGS } from '../data/CoverSettingsRepository';
import { UiSwitch } from '../components/settings/UiSwitch';
import { UiMenuItem, UiMenuPanel } from '../components/UiMenu';
import { SPACE_8, SPACE_12, SPACE_16, RADIUS_SHEET } from '../components/UiTokens';

/** 编辑页顶栏用的保存按钮尺寸走 TopBar 的统一口径，这里只留菜单宽度与输入框常量。 */
const BOOK_TYPE_MENU_WIDTH: number = 220;
const FIELD_LABEL_SIZE: number = 13;
const FIELD_INPUT_SIZE: number = 15;
const FIELD_MIN_HEIGHT: number = 52;
/**
 * 输入框高度与圆角。
 *
 * 上游编辑页用的是 `AppTextField`（`ui/widget/components/AppTextField.kt`），
 * 走 material3 `TextFieldDefaults.shape` = 4dp 圆角、label 内嵌在框内、
 * 底部一条 1dp indicator。本地原来是自己画的 52 高 + 16 圆角 + 外置 label，
 * 与设置页的卡片行同一形态，和上游的输入框不是一回事。
 */
const FIELD_M3_HEIGHT: number = 56;
const FIELD_M3_RADIUS: number = 4;
const SUMMARY_MAX_LINES: number = 6;
/** 卡片圆角（上游 `NormalCard` 默认走 `shapes.large` = 16）。 */
const RADIUS_CARD: number = 16;

/**
 * 书籍信息编辑页。
 *
 * 对齐上游 `ui/book/info/edit/BookInfoEditScreen.kt` 的骨架：顶栏「书籍信息编辑」+ 返回 + 保存，
 * 内容区一张封面 + 三个封面动作 + 书籍类型下拉，然后是固定书籍类型开关与各输入框。
 *
 * 上游的知识卡（人物列表 / 关系网 / 世界知识 / 事件列表）与「封面链接」输入框本地没有对应能力，
 * 这里不画空壳；分组是多选，用一个可展开的标签区表达，而不是上游那个 readOnly 的书源分类行。
 */
@Component
export struct BookInfoEditPage {
  @StorageProp('themeColorTextPrimary') themeColorTextPrimary: string = '#1B1C22';
  @StorageProp('themeColorTextSecondary') themeColorTextSecondary: string = '#2E3038';
  @StorageProp('themeColorTextTertiary') themeColorTextTertiary: string = '#6A6D77';
  @StorageProp('themeColorAccent') themeColorAccent: string = '#3F5BD9';
  @StorageProp('themeColorSurfacePrimary') themeColorSurfacePrimary: string = '#F5F6F8';
  @StorageProp('themeColorSurfaceSecondary') themeColorSurfaceSecondary: string = '#FFFFFF';
  @StorageProp('themeColorSurfaceTertiary') themeColorSurfaceTertiary: string = '#F0F1F5';
  @StorageProp('themeAppBackground') themeAppBackground: string = '';
  @StorageProp('themePureBlack') themePureBlack: boolean = false;
  @StorageProp('appTopInset') appTopInset: number = 0;

  @Prop book: Book = {
    id: '', title: '', author: '', category: '', lastChapter: '', progress: 0, isLocal: true
  };
  @Prop groups: BookGroup[] = [];
  @Prop coverSettings: CoverSettings = DEFAULT_COVER_SETTINGS;
  @Prop followCoverColor: boolean = true;
  @Prop networkCoverBackground: string = 'on';
  @Prop defaultCoverBackground: string = 'on';

  onBack: () => void = () => {};
  /** 十个参数与 `Index.saveBookMetadata` 完全一致，直接转发，不在本页重写落库逻辑。 */
  onSave: (title: string, author: string, category: string, description: string, remark: string,
    customTag: string, groupNames: string[], bookType: BookMediaType, fixedType: boolean,
    coverUrl: string) => Promise<boolean> = () => Promise.resolve(false);
  onChooseCover: () => void = () => {};
  onRestoreCover: () => void = () => {};
  onUnavailableAction: (message: string) => void = () => {};

  @State private title: string = '';
  @State private author: string = '';
  @State private category: string = '';
  /** 封面链接（上游 `cover_url`）。本地就是 `book.coverUri` 的展示与手工改写。 */
  @State private coverUrl: string = '';
  @State private description: string = '';
  @State private remark: string = '';
  @State private customTag: string = '';
  /** 「我的标签」编辑器的草稿列表（上游 `KindEditor` 的 `kindList`，落库时拼回 customTag）。 */
  @State private kindList: string[] = [];
  /** 进页面时的标签快照，供「重置」还原（上游 `originalKindList`）。 */
  private originalKindList: string[] = [];
  /** 标签编辑弹窗：-1 表示新增，>=0 表示改第几项，null 表示弹窗关闭。 */
  @State private kindEditingIndex: number = -2;
  @State private kindEditingText: string = '';
  @State private groupNames: string[] = [];
  @State private bookType: BookMediaType = 'text';
  @State private fixedType: boolean = false;
  @State private bookTypeMenuVisible: boolean = false;
  @State private groupPickerVisible: boolean = false;
  @State private saving: boolean = false;

  aboutToAppear(): void {
    this.resetFromBook();
  }

  /** 每次进入都从当前书籍取一遍，避免上一本书的编辑残留带过来。 */
  private resetFromBook(): void {
    this.title = this.book.title;
    this.author = this.book.author;
    this.category = this.book.category;
    this.coverUrl = this.book.coverUri ?? '';
    this.description = this.book.description ?? '';
    this.remark = this.book.remark ?? '';
    this.customTag = this.book.customTag ?? '';
    // 我的标签：上游 `BookInfoEditViewModel.kt:68-78` 用 customTag 按逗号/换行切分去重，
    // 同时留一份 originalKindList 供「重置」还原。
    this.kindList = (this.book.customTag ?? '').split(/[\n,，]/).map((item: string) => item.trim())
      .filter((item: string) => item.length > 0);
    this.originalKindList = this.kindList.slice(0);
    this.groupNames = (this.book.groupNames ?? []).slice(0);
    this.bookType = this.book.bookType ?? 'text';
    this.fixedType = this.book.fixedType === true;
  }

  private pageSurface(): ResourceColor {
    if (this.themeAppBackground.length > 0) { return Color.Transparent; }
    return this.themePureBlack ? '#000000' : this.themeColorSurfacePrimary;
  }

  /** 输入框底色：比页面底亮一档，对齐上游 `surfaceInput`。 */
  private inputSurface(): ResourceColor {
    return this.themePureBlack ? '#141414' : this.themeColorSurfaceSecondary;
  }

  private bookTypeLabel(type: BookMediaType): string {
    if (type === 'audio') { return '音频'; }
    if (type === 'image') { return '图片'; }
    return '文本';
  }

  private bookTypeItems(): UiMenuItem[] {
    return [
      { key: 'text', title: '文本', selected: this.bookType === 'text' },
      { key: 'audio', title: '音频', selected: this.bookType === 'audio' },
      { key: 'image', title: '图片', selected: this.bookType === 'image' }
    ];
  }

  private hasGroup(groupName: string): boolean {
    return this.groupNames.indexOf(groupName) >= 0;
  }

  private toggleGroup(groupName: string): void {
    const next: string[] = this.groupNames.slice(0);
    const index = next.indexOf(groupName);
    if (index >= 0) {
      next.splice(index, 1);
    } else {
      next.push(groupName);
    }
    this.groupNames = next;
  }

  private async submit(): Promise<void> {
    if (this.saving) { return; }
    if (this.title.trim().length === 0) {
      this.onUnavailableAction('书名不能为空，未保存书籍信息');
      return;
    }
    this.saving = true;
    // 我的标签编辑器落库时拼回 customTag（上游 `BookInfoEditViewModel.kt:146`
    // 的 `book.customTag = currentState.kindList.joinToString(",").ifBlank { null }`）。
    const mergedTag: string = this.kindList.join(',');
    const saved: boolean = await this.onSave(this.title.trim(), this.author.trim(), this.category.trim(),
      this.description, this.remark, mergedTag, this.groupNames, this.bookType, this.fixedType,
      this.coverUrl.trim());
    this.saving = false;
    if (saved) {
      this.onBack();
    }
  }

  @Builder
  bookTypePopup() {
    UiMenuPanel({
      items: this.bookTypeItems(),
      panelWidth: BOOK_TYPE_MENU_WIDTH,
      onSelect: (key: string) => {
        this.bookTypeMenuVisible = false;
        this.bookType = key === 'audio' ? 'audio' : (key === 'image' ? 'image' : 'text');
      }
    })
  }

  @Builder
  groupPopup() {
    UiMenuPanel({
      items: this.groups.map((group: BookGroup): UiMenuItem => {
        return { key: String(group.groupId), title: group.groupName, selected: this.hasGroup(group.groupName) };
      }),
      panelWidth: BOOK_TYPE_MENU_WIDTH,
      onSelect: (key: string) => {
        const matched = this.groups.find((group: BookGroup) => String(group.groupId) === key);
        if (matched !== undefined) {
          this.toggleGroup(matched.groupName);
        }
      }
    })
  }

  /**
   * 封面右侧的圆形描边图标按钮，对齐上游 `MediumOutlinedButton(icon = ...)`
   * （`BookInfoEditScreen.kt:194-208` 的三个按钮只有图标、无文字）。
   */
  @Builder
  coverIconAction(icon: AppGlyphName, label: string, action: () => void) {
    Stack({ alignContent: Alignment.Center }) {
      AppGlyph({ name: icon, glyphSize: 18, tint: this.themeColorTextSecondary })
    }
    .width(44).height(44).borderRadius(22)
    .border({ width: 1, color: this.themeColorTextTertiary })
    .onClick(() => action())
    .accessibilityText(label)
  }

  /**
   * 知识卡：上游 `BookInfoEditScreen.kt:296-349` 的 `BookKnowledgeEditCard`。
   * 一张 `NormalCard`，标题「知识」+ 一行四个 `MediumOutlinedButton`
   * （人物 / 关系网 / 世界知识 / 事件列表）。本地没有知识库数据，
   * 四个按钮照上游列出来，点了提示未接入（用户要求按钮做全）。
   */
  @Builder
  knowledgeCard() {
    Column({ space: SPACE_12 }) {
      Text('知识').fontSize(15).fontWeight(FontWeight.Medium).fontColor(this.themeColorTextPrimary)
      Scroll() {
        Row({ space: SPACE_8 }) {
          this.knowledgeChip('list', '人物')
          this.knowledgeChip('group', '关系网')
          this.knowledgeChip('book', '世界知识')
          this.knowledgeChip('profileTimeline', '事件列表')
        }.alignItems(VerticalAlign.Center)
      }
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Off)
      .align(Alignment.Start)
      .width('100%')
    }
    .width('100%').alignItems(HorizontalAlign.Start)
    .padding(16)
    .backgroundColor(this.inputSurface()).borderRadius(RADIUS_CARD)
  }

  /** 知识卡的单个描边按钮（上游 `MediumOutlinedButton`）。 */
  @Builder
  knowledgeChip(icon: AppGlyphName, label: string) {
    Row() {
      AppGlyph({ name: icon, glyphSize: 16, tint: this.themeColorTextSecondary })
      Text(label).fontSize(13).fontColor(this.themeColorTextPrimary).margin({ left: 6 })
    }
    .height(34).padding({ left: 12, right: 12 })
    .border({ width: 1, color: this.themeColorTextTertiary })
    .borderRadius(17)
    .onClick(() => this.onUnavailableAction(`${label} 未接入`))
  }

  /**
   * 我的标签编辑器：上游 `KindEditor`（`BookInfoEditScreen.kt:408-549`）。
   *
   * 上游是 `LazyRow` + 可长按拖拽排序的 `KindChip`，右侧两个描边按钮
   * （重置 / 新增）；点 chip 弹对话框改名，对话框的否定按钮在编辑态是「删除」。
   * 本地用 `Scroll` + `Row` 承载，拖拽排序不做（ArkUI 的 List 才有 onMove），
   * 改名/新增/删除/重置四个动作都有。
   */
  @Builder
  kindEditor() {
    Column({ space: SPACE_8 }) {
      Text('我的标签').fontSize(FIELD_LABEL_SIZE).fontColor(this.themeColorTextTertiary)
      Row({ space: SPACE_8 }) {
        Scroll() {
          Row({ space: SPACE_8 }) {
            ForEach(this.kindList, (kind: string, index: number) => {
              Row() {
                Text(kind).fontSize(13).fontColor(this.themeColorTextPrimary)
                  .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
              }
              .padding({ left: 10, right: 10, top: 5, bottom: 5 })
              .backgroundColor(this.themePureBlack ? '#161616' : this.themeColorSurfaceTertiary)
              .borderRadius(8)
              .onClick(() => {
                this.kindEditingIndex = index;
                this.kindEditingText = kind;
              })
            }, (kind: string) => kind)
          }.alignItems(VerticalAlign.Center)
        }
        .scrollable(ScrollDirection.Horizontal)
        .scrollBar(BarState.Off)
        .align(Alignment.Start)
        .layoutWeight(1)

        // 重置：回到进页面时的标签快照（上游 `resetKinds()`）。
        Stack({ alignContent: Alignment.Center }) {
          AppGlyph({ name: 'profileHistory', glyphSize: 16, tint: this.themeColorTextSecondary })
        }.width(34).height(34).borderRadius(17)
        .border({ width: 1, color: this.themeColorTextTertiary })
        .onClick(() => { this.kindList = this.originalKindList.slice(0); })

        // 新增：editingIndex = -1（上游 `:493-494`）。
        Stack({ alignContent: Alignment.Center }) {
          AppGlyph({ name: 'add', glyphSize: 16, tint: this.themeColorTextSecondary })
        }.width(34).height(34).borderRadius(17)
        .border({ width: 1, color: this.themeColorTextTertiary })
        .onClick(() => {
          this.kindEditingIndex = -1;
          this.kindEditingText = '';
        })
      }.width('100%').alignItems(VerticalAlign.Center)
    }.width('100%').alignItems(HorizontalAlign.Start)
  }

  /** 标签编辑对话框：-1 新增、>=0 改名（上游 `:503-548` 的 `AppAlertDialog`）。 */
  @Builder
  kindDialog() {
    Column({ space: SPACE_16 }) {
      Text(this.kindEditingIndex === -1 ? '添加标签' : '编辑标签')
        .fontSize(17).fontWeight(FontWeight.Medium).fontColor(this.themeColorTextPrimary)
      Column() {
        this.m3Input('标签', this.kindEditingText, '请输入标签',
          (value: string) => { this.kindEditingText = value; })
      }.width('100%')
      Row({ space: SPACE_8 }) {
        Button(this.kindEditingIndex === -1 ? '取消' : '删除')
          .layoutWeight(1).height(40)
          .backgroundColor(this.themeColorSurfaceTertiary)
          .fontColor(this.themeColorTextPrimary)
          .onClick(() => { this.onKindDialogDismiss(); })
        Button('确定')
          .layoutWeight(1).height(40)
          .onClick(() => { this.onKindDialogConfirm(); })
      }.width('100%')
    }
    .width('86%').padding(20)
    .backgroundColor(this.themeColorSurfaceSecondary).borderRadius(22)
  }

  private onKindDialogConfirm(): void {
    const trimmed = this.kindEditingText.trim();
    if (trimmed.length > 0) {
      const next: string[] = this.kindList.slice(0);
      if (this.kindEditingIndex === -1) {
        if (next.indexOf(trimmed) < 0) { next.push(trimmed); }
      } else {
        next[this.kindEditingIndex] = trimmed;
      }
      // 上游 `onKindListChange` 里再做一次 distinct。
      this.kindList = Array.from(new Set(next));
    }
    this.kindEditingIndex = -2;
  }

  private onKindDialogDismiss(): void {
    // 编辑态的否定按钮是「删除」（上游 `:536-546`）。
    if (this.kindEditingIndex >= 0) {
      const next: string[] = this.kindList.slice(0);
      next.splice(this.kindEditingIndex, 1);
      this.kindList = next;
    }
    this.kindEditingIndex = -2;
  }

  @Builder
  fieldLabel(text: string) {
    Text(text).fontSize(FIELD_LABEL_SIZE).fontColor(this.themeColorTextTertiary)
      .width('100%').margin({ bottom: 6 })
  }

  /**
   * 单行输入框，对齐上游 `AppTextField`（material3 `TextFieldDefaults.shape`）：
   * 4dp 圆角、label 内嵌在框内左上、底部一条 indicator。
   *
   * ArkUI 的 `TextInput` 没有内嵌 label，所以用一个 Column 把 label 与输入行叠在
   * 同一块圆角底里，底部再画 1vp 的 indicator 线。
   */
  @Builder
  m3Input(label: string, text: string, placeholder: string, onChange: (value: string) => void) {
    Column() {
      Text(label).fontSize(FIELD_LABEL_SIZE).fontColor(this.themeColorTextTertiary)
        .width('100%').margin({ bottom: 2 })
      TextInput({ text: text, placeholder: placeholder })
        .fontSize(FIELD_INPUT_SIZE).fontColor(this.themeColorTextPrimary)
        .placeholderColor(this.themeColorTextTertiary)
        .backgroundColor(Color.Transparent)
        .padding({ left: 0, right: 0, top: 0, bottom: 6 })
        .height(30)
        .onChange((value: string) => onChange(value))
      // indicator：material3 未聚焦时是一条 `outline` 色的细线，聚焦后变 `primary`。
      Row().width('100%').height(1).backgroundColor(this.themeColorTextTertiary)
    }
    .width('100%').constraintSize({ minHeight: FIELD_M3_HEIGHT })
    .padding({ left: 16, right: 16, top: 8, bottom: 8 })
    .backgroundColor(this.inputSurface()).borderRadius(FIELD_M3_RADIUS)
  }

  @Builder
  navSlot() {
    TopBarBackButton({ onSelect: () => this.onBack() })
  }

  @Builder
  topActions() {
    // 保存按钮：上游是顶栏右侧一个 Save 图标，这里同样用 TopBarButton 而不是自绘圆底。
    TopBarButton({ icon: 'profileSave', showDivider: false, onSelect: () => { this.submit(); } })
  }

  build() {
    // 根节点用 Stack：页面本体 + 标签编辑弹窗浮层（ArkUI 要求 build 只有一个根节点）。
    Stack({ alignContent: Alignment.Center }) {
      Column() {
        AppTopBar({
          title: '书籍信息编辑',
          collapsed: false,
          hasNavigation: true,
          navigationIcon: () => { this.navSlot() },
          actions: () => { this.topActions() }
        })

      Scroll() {
        Column({ space: SPACE_16 }) {
          // 封面行：上游 `BookInfoEditScreen.kt:170-221` —— 左边 110dp 封面，
          // 右边一列：三个等间距的圆形描边图标按钮（刷新封面 / 选择文件夹 / 还原封面），
          // 下面 4dp 间隔再跟书籍类型下拉。
          Row({ space: SPACE_16 }) {
            BookCover({
              book: this.book,
              displayWidth: 110,
              displayHeight: 154,
              coverSettings: this.coverSettings,
              applyAspectRatio: true
            })
            Column({ space: SPACE_8 }) {
              Row({ space: SPACE_12 }) {
                // 「刷新封面」：上游打开 ChangeCoverSheet 从书源拉网络封面。
                // 本地没有书源，点了给一句未接入，不删按钮。
                this.coverIconAction('profileRefresh', '刷新封面', () => this.onUnavailableAction('刷新封面 未接入'))
                this.coverIconAction('profileFolder', '选择文件夹', () => this.onChooseCover())
                this.coverIconAction('profileHistory', '还原封面', () => this.onRestoreCover())
              }.justifyContent(FlexAlign.Center)
              Blank().height(4)
              // 书籍类型：上游是 ExposedDropdownMenuBox + AppTextField（readOnly + trailingIcon），
              // 本地用同形态的圆角 4 输入框 + 右侧展开箭头承载。
              Row() {
                Text(this.bookTypeLabel(this.bookType)).fontSize(FIELD_INPUT_SIZE)
                  .fontColor(this.themeColorTextPrimary).layoutWeight(1)
                AppGlyph({ name: 'profileExpandMore', glyphSize: 20, tint: this.themeColorTextTertiary })
              }
              .width('100%').height(FIELD_M3_HEIGHT).padding({ left: 16, right: 12 })
              .backgroundColor(this.inputSurface()).borderRadius(FIELD_M3_RADIUS)
              .onClick(() => { this.bookTypeMenuVisible = !this.bookTypeMenuVisible; })
              .bindPopup(this.bookTypeMenuVisible, {
                builder: this.bookTypePopup,
                placement: Placement.Bottom,
                popupColor: '#00000000',
                enableArrow: false,
                autoCancel: true,
                width: BOOK_TYPE_MENU_WIDTH,
                onStateChange: (event: PopupStateChangeParam) => { this.bookTypeMenuVisible = event.isVisible; }
              })
            }.layoutWeight(1).alignItems(HorizontalAlign.Center)
          }.width('100%').alignItems(VerticalAlign.Center)

          // 知识卡（上游 `:223-229`）。
          this.knowledgeCard()

          // 固定书籍类型（上游 `:231-236` 的 `SwitchSettingItem`）。
          Column() {
            UiSwitch({
              title: '固定书籍类型',
              detail: '书籍更新后不覆盖书籍类型',
              value: this.fixedType,
              onChange: (enabled: boolean) => { this.fixedType = enabled; }
            })
          }.width('100%').backgroundColor(this.inputSurface()).borderRadius(RADIUS_CARD)

          // 七个字段，顺序照上游 `:238-292`：
          // 书名 → 作者 → 封面链接 → 书源分类 → 我的标签 → 内容简介 → 书籍备注。
          Column() {
            this.m3Input('书名', this.title, '请输入书名', (value: string) => { this.title = value; })
          }.width('100%')

          Column() {
            this.m3Input('作者', this.author, '请输入作者', (value: string) => { this.author = value; })
          }.width('100%')

          // 封面链接：上游 `cover_url` 输入框。本地封面是导入时抽出的图片副本，
          // 这个字段写进去的是 `book.coverUri`，保存时一并落库（留空表示不改）。
          Column() {
            this.m3Input('封面链接', this.coverUrl, '请输入封面链接', (value: string) => { this.coverUrl = value; })
          }.width('100%')

          // 书源分类：上游 `:262-269` 是 readOnly 的 `source_kind` 展示行。
          // 本地没有书源，这里展示并允许改写本地的 `category`。
          Column() {
            this.m3Input('书源分类', this.category, '暂无分类', (value: string) => { this.category = value; })
          }.width('100%')

          // 我的标签（上游 `:271-276` 的 `KindEditor`）。
          this.kindEditor()

          Column() {
            this.fieldLabel('内容简介')
            TextArea({ text: this.description, placeholder: '请输入内容简介' })
              .fontSize(FIELD_INPUT_SIZE).fontColor(this.themeColorTextPrimary)
              .placeholderColor(this.themeColorTextTertiary)
              .backgroundColor(this.inputSurface()).borderRadius(FIELD_M3_RADIUS)
              .constraintSize({ minHeight: 120 }).padding({ left: 16, right: 16, top: 12, bottom: 12 })
              .onChange((value: string) => { this.description = value; })
          }.width('100%')

          Column() {
            this.fieldLabel('书籍备注')
            TextArea({ text: this.remark, placeholder: '请输入书籍备注' })
              .fontSize(FIELD_INPUT_SIZE).fontColor(this.themeColorTextPrimary)
              .placeholderColor(this.themeColorTextTertiary)
              .backgroundColor(this.inputSurface()).borderRadius(FIELD_M3_RADIUS)
              .constraintSize({ minHeight: 96 }).padding({ left: 16, right: 16, top: 12, bottom: 12 })
              .onChange((value: string) => { this.remark = value; })
          }.width('100%')

          // 分组多选：上游编辑页没有这一项（分组是书架的独立能力），
          // 本地分组是用户自建的可变集合，保留在这里并排在上游字段之后。
          Column() {
            this.fieldLabel('分组')
            Row() {
              Text(this.groupNames.length > 0 ? this.groupNames.join('、') : '本地未分组')
                .fontSize(FIELD_INPUT_SIZE).fontColor(this.themeColorTextPrimary)
                .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis }).layoutWeight(1)
              AppGlyph({ name: 'profileExpandMore', glyphSize: 20, tint: this.themeColorTextTertiary })
            }
            .width('100%').height(FIELD_M3_HEIGHT).padding({ left: 16, right: 12 })
            .backgroundColor(this.inputSurface()).borderRadius(FIELD_M3_RADIUS)
            .onClick(() => { this.groupPickerVisible = !this.groupPickerVisible; })
            .bindPopup(this.groupPickerVisible, {
              builder: this.groupPopup,
              placement: Placement.Bottom,
              popupColor: '#00000000',
              enableArrow: false,
              autoCancel: true,
              width: BOOK_TYPE_MENU_WIDTH,
              onStateChange: (event: PopupStateChangeParam) => { this.groupPickerVisible = event.isVisible; }
            })
          }.width('100%')
        }
        .width('100%')
        .padding({ left: SPACE_16, right: SPACE_16, top: SPACE_16, bottom: SPACE_16 })
      }.edgeEffect(EdgeEffect.Spring)
        .layoutWeight(1)
        .width('100%')
        .scrollBar(BarState.Off)
        .align(Alignment.Top)
      }
      .width('100%')
      .height('100%')
      .backgroundColor(this.pageSurface())

      // 标签编辑弹窗（上游 `AppAlertDialog`）：kindEditingIndex === -2 表示关闭。
      if (this.kindEditingIndex !== -2) {
        Stack({ alignContent: Alignment.Center }) {
          Column().width('100%').height('100%').backgroundColor('#99000000')
            .onClick(() => { this.kindEditingIndex = -2; })
          this.kindDialog()
        }.width('100%').height('100%').zIndex(100)
      }
    }
    .width('100%')
    .height('100%')
  }
}
