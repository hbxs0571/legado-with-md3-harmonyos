import { Book, BookMediaType } from '../model/Book';
import { BookGroup } from '../model/BookGroup';
import { AppTopBar, TopBarBackButton, TopBarButton } from '../components/TopBar';
import { BookCover } from '../components/BookCover';
import { AppGlyph } from '../components/AppGlyph';
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
    const saved: boolean = await this.onSave(this.title.trim(), this.author.trim(), this.category.trim(),
      this.description, this.remark, this.customTag, this.groupNames, this.bookType, this.fixedType,
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

  /** 封面右侧的三个动作，与上游一样竖排等宽。 */
  @Builder
  coverAction(icon: 'profileRefresh' | 'profileFolder' | 'profileHistory', label: string, action: () => void) {
    Row() {
      AppGlyph({ name: icon, glyphSize: 15, tint: this.themeColorTextSecondary })
      Text(label).fontSize(13).fontColor(this.themeColorTextPrimary).margin({ left: 6 })
    }
    .width('100%').height(34).justifyContent(FlexAlign.Center)
    .backgroundColor(this.themePureBlack ? '#161616' : this.themeColorSurfaceTertiary)
    .borderRadius(17)
    .onClick(() => action())
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
          Row({ space: SPACE_16 }) {
            BookCover({
              book: this.book,
              displayWidth: 110,
              displayHeight: 154,
              coverSettings: this.coverSettings,
              applyAspectRatio: true
            })
            Column({ space: SPACE_8 }) {
              // 上游三个封面动作（`BookInfoEditScreen.kt:193-208`）：
              // 「刷新封面」打开 ChangeCoverSheet（从书源拉网络封面）、
              // 「选择文件夹」走 SelectImageContract 选本地图片、「还原封面」清掉自定义封面。
              // 本地没有书源，「刷新封面」拉不到东西，所以只留后面两个；
              // 原来第一个按钮也绑 `onChooseCover`，与第二个完全重复，一并去掉。
              this.coverAction('profileFolder', '选择文件夹', () => this.onChooseCover())
              this.coverAction('profileHistory', '还原封面', () => this.onRestoreCover())
            }.layoutWeight(1)
          }.width('100%').alignItems(VerticalAlign.Center)

          // 书籍类型：上游是 ExposedDropdownMenuBox，这里用同一个卡片菜单承载。
          Column() {
            this.fieldLabel('书籍类型')
            Row() {
              Text(this.bookTypeLabel(this.bookType)).fontSize(FIELD_INPUT_SIZE)
                .fontColor(this.themeColorTextPrimary).layoutWeight(1)
              AppGlyph({ name: 'profileExpandMore', glyphSize: 20, tint: this.themeColorTextTertiary })
            }
            .width('100%').height(FIELD_MIN_HEIGHT).padding({ left: 14, right: 12 })
            .backgroundColor(this.inputSurface()).borderRadius(RADIUS_SHEET)
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
          }.width('100%')

          // 固定书籍类型：上游 SwitchSettingItem，整行可点，开关由 UiSwitch 自绘。
          Column() {
            UiSwitch({
              title: '固定书籍类型',
              detail: '开启后按上面的类型解析正文，不再自动识别',
              value: this.fixedType,
              onChange: (enabled: boolean) => { this.fixedType = enabled; }
            })
          }.width('100%').backgroundColor(this.inputSurface()).borderRadius(RADIUS_SHEET)

          Column() {
            this.m3Input('书名', this.title, '请输入书名', (value: string) => { this.title = value; })
          }.width('100%')

          Column() {
            this.m3Input('作者', this.author, '请输入作者', (value: string) => { this.author = value; })
          }.width('100%')

          // 封面链接：上游 `BookInfoEditScreen.kt:254-260` 的 `cover_url` 输入框。
          // 本地封面是导入时抽出的图片副本（`covers/<id>.img`），没有可编辑的 URL，
          // 这个字段只做展示与手工改写：写进去的是 `book.coverUri`，保存时一并落库。
          Column() {
            this.m3Input('封面链接', this.coverUrl, '请输入封面链接', (value: string) => { this.coverUrl = value; })
          }.width('100%')

          Column() {
            this.m3Input('分类', this.category, '请输入分类', (value: string) => { this.category = value; })
          }.width('100%')

          // 分组多选：上游是固定分组，本地分组是用户自建的可变集合，这里给一个可展开的勾选面板。
          Column() {
            this.fieldLabel('分组')
            Row() {
              Text(this.groupNames.length > 0 ? this.groupNames.join('、') : '本地未分组')
                .fontSize(FIELD_INPUT_SIZE).fontColor(this.themeColorTextPrimary)
                .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis }).layoutWeight(1)
              AppGlyph({ name: 'profileExpandMore', glyphSize: 20, tint: this.themeColorTextTertiary })
            }
            .width('100%').height(FIELD_MIN_HEIGHT).padding({ left: 14, right: 12 })
            .backgroundColor(this.inputSurface()).borderRadius(RADIUS_SHEET)
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

          Column() {
            this.m3Input('自定义标签', this.customTag, '多个标签用逗号分隔',
              (value: string) => { this.customTag = value; })
          }.width('100%')

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
        }
        .width('100%')
        .padding({ left: SPACE_16, right: SPACE_16, top: SPACE_12, bottom: SPACE_16 })
      }
      .layoutWeight(1)
      .width('100%')
      .scrollBar(BarState.Off)
      .align(Alignment.Top)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.pageSurface())
  }
}
