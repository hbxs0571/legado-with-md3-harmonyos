import { Book, BookMediaType, displayIntroOf } from '../model/Book';
import { BookGroup } from '../model/BookGroup';
import { AppTopBar, TopBarBackButton, TopBarButton } from '../components/TopBar';
import { BookCover } from '../components/BookCover';
import { AppGlyph, AppGlyphName } from '../components/AppGlyph';
import { CoverSettings, DEFAULT_COVER_SETTINGS } from '../data/CoverSettingsRepository';
import { UiSwitch } from '../components/settings/UiSwitch';
import { UiMenuItem, UiMenuPanel } from '../components/UiMenu';
import { HEADER_COLLAPSE_THRESHOLD, HEADER_EXPAND_THRESHOLD, SPACE_8, SPACE_12, SPACE_16 } from '../components/UiTokens';
import { BODY_MEDIUM, LABEL_LARGE_EMPHASIZED, LABEL_MEDIUM, TITLE_MEDIUM, TYPE_SCALE_BODY_LARGE } from '../components/typography/TypographyTokens';
import { BookKnowledgeSheet } from '../components/BookKnowledgeSheet';
import { ChangeCoverSheet } from '../components/booksource/ChangeCoverSheet';
import { AppAlertDialog } from '../components/AppAlertDialog';
import { UiHaptics } from '../data/UiHaptics';
import { curves, window } from '@kit.ArkUI';

/** 编辑页顶栏用的保存按钮尺寸走 TopBar 的统一口径，这里只留菜单宽度与输入框常量。 */
const BOOK_TYPE_MENU_WIDTH: number = 220;
// 输入框文字：上游 material3 TextField 的 textStyle 默认是 LocalTextStyle.current，
// 而 MaterialTheme 把 LocalTextStyle 提供成 typography.bodyLarge（M3 原生 16sp）。
const FIELD_MIN_HEIGHT: number = 52;
/**
 * 输入框高度与圆角。
 *
 * 上游编辑页用的是 `AppTextField`（`ui/widget/components/AppTextField.kt`），
 * 走 material3 `TextFieldDefaults.shape` = 4dp 圆角、label 内嵌在框内（默认
 * `labelPosition = TextFieldLabelPosition.Inside()`）、底部一条 1dp indicator。
 */
const FIELD_M3_HEIGHT: number = 56;
const FIELD_M3_RADIUS: number = 4;
const SUMMARY_MAX_LINES: number = 6;
/** 卡片圆角（上游 `NormalCard` 默认走 `shapes.large` = 16）。 */
const RADIUS_CARD: number = 16;
/**
 * 封面行三个描边按钮的尺寸。
 *
 * 上游是 `MediumOutlinedButton(icon = ..., contentDescription = ...)`，
 * 而 `MediumOutlinedButton` 无文字时取 `MediumSeriesIconButtonSize = DpSize(40.dp, 40.dp)`、
 * 图标 `MediumSeriesIconSize = IconButtonDefaults.mediumIconSize`（24dp）、
 * 描边 `BorderStroke(1.dp, outlineVariant)`（`SeriesIconButton.kt`）。
 * 本地原来画的是 44×44 圆 + 18 图标 + textTertiary 描边，三处都不对。
 */
const COVER_ACTION_SIZE: number = 40;
const COVER_ACTION_ICON: number = 24;
/**
 * 知识卡与「我的标签」里的胶囊按钮尺寸。
 *
 * 上游同为 `MediumOutlinedButton`：有文字时 `size = null`，靠
 * `SeriesButtonContent(iconSize = MediumSeriesIconSize, textStyle = labelMedium,
 * padding = PaddingValues(horizontal = 16.dp, vertical = 12.dp), spacing = 8.dp)` 撑出高度，
 * 即 24 图标 + 12+12 纵向内边距 = 48 高、左右各 16。本地原来画成 34 高 + 12 左右 + 6 间距。
 */
const CHIP_ICON: number = 24;
const CHIP_PADDING_H: number = 16;
const CHIP_PADDING_V: number = 12;
const CHIP_SPACING: number = 8;
/** 「我的标签」标题与内容之间、容器上下内边距（上游 `padding(vertical = 8.dp)` + `spacedBy(4.dp)`）。 */
const KIND_EDITOR_PADDING_V: number = 8;
const KIND_EDITOR_SPACING: number = 4;
/** KindChip 内文字内边距（上游 `padding(horizontal = 8.dp, vertical = 4.dp)`，外层 `padding(2.dp)`）。 */
const KIND_CHIP_PADDING_H: number = 10;
const KIND_CHIP_PADDING_V: number = 6;
const KIND_CHIP_RADIUS: number = 8;
/** 标签编辑对话框宽度（上游 M3 `AlertDialog` 的 312dp）。 */
const DIALOG_WIDTH: number = 312;

/**
 * 书籍信息编辑页。
 *
 * 逐项对齐上游 `ui/book/info/edit/BookInfoEditScreen.kt`（578 行）与
 * `ui/book/info/edit/BookInfoEditViewModel.kt`（191 行）：
 *
 * - 顶栏 `GlassMediumFlexibleTopAppBar`：标题「书籍信息编辑」+ 返回 + 保存（Save 图标），
 *   随内容滚动连续折叠（本地用 `AppTopBar` 的 `collapseFraction`）。
 * - 内容区 `Column(padding 16.dp)`：封面行（110dp 封面 + 三个 40dp 描边图标按钮 + 书籍类型下拉）
 *   → 知识卡 → 固定书籍类型开关 → 七个字段（书名/作者/封面链接/书源分类/我的标签/内容简介/书籍备注），
 *   字段之间 `Spacer(8.dp)`，大区块之间 `Spacer(16.dp)`。
 * - 保存链路（J 区）落在 `Index.saveBookMetadata`：自定义封面写 `customCoverUri`、自定义简介写
 *   `customIntro`、空标签存 null、保存后跑标签分组规则与缓存目录搬迁、失败区分同名冲突。
 *
 * ArkTS 无 ViewModel/Flow，状态源留在页面内（同第七表 ExploreShowPage、第八表 SearchPage 做法）。
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
  /** 知识卡与 KindChip 的容器色：上游 `NormalCard` 默认 `surfaceContainer`。 */
  @StorageProp('themeColorSurfaceContainer') themeColorSurfaceContainer: string = '#F1F2F6';
  /** 输入框底色。上游 `surfaceInput`，见 `inputSurface()` 的注释。 */
  @StorageProp('themeColorSurfaceInput') themeColorSurfaceInput: string = '#E2E3D8';
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
  /** 封面链接（上游 `cover_url`）。本地展示「显示封面」并允许手工改写。 */
  @State private coverUrl: string = '';
  @State private description: string = '';
  @State private remark: string = '';
  @State private customTag: string = '';
  /** 「我的标签」编辑器的草稿列表（上游 `KindEditor` 的 `kindList`，落库时拼回 customTag）。 */
  @State private kindList: string[] = [];
  /** 进页面时的标签快照，供「重置」还原（上游 `originalKindList`）。 */
  @State private originalKindList: string[] = [];
  /** 标签编辑弹窗：-1 表示新增，>=0 表示改第几项，-2 表示弹窗关闭（上游 `editingIndex: Int?`）。 */
  @State private kindEditingIndex: number = -2;
  @State private kindEditingText: string = '';
  @State private groupNames: string[] = [];
  @State private bookType: BookMediaType = 'text';
  @State private fixedType: boolean = false;
  @State private bookTypeMenuVisible: boolean = false;
  @State private groupPickerVisible: boolean = false;
  @State private saving: boolean = false;
  /** 知识库四面板是否显示；initialTab 决定打开哪个面板（0 人物/1 关系网/2 世界知识/3 事件）。 */
  @State private knowledgeSheetVisible: boolean = false;
  @State private knowledgeSheetTab: number = 0;
  /** 换封面面板（B-9）：上游 `showChangeCoverSheet`，点「刷新封面」打开。 */
  @State private changeCoverVisible: boolean = false;

  /** 顶栏随滚动折叠（A-5）：`collapsed` 两态 + `collapseFraction` 连续进度。 */
  @State private collapsedHeader: boolean = false;
  @State private headerFraction: number = 0;
  /** 输入法高度（A-8）：本地没有 `imePadding()`，用 `keyboardHeightChange` 自己让出底部空间。 */
  @State private keyboardHeight: number = 0;

  private scroller: Scroller = new Scroller();
  /** 当前标签编辑弹窗的 id（openCustomDialog 返回），-1 表示未开。 */
  private kindDialogId: number = -1;
  /** openCustomDialog 的 builder 需要存成成员（@Builder 方法不能直接传给 SDK）。 */
  private kindDialogBuilder: (() => void) | undefined = undefined;
  private editWindow: window.Window | undefined = undefined;
  private keyboardListener: ((height: number) => void) | undefined = undefined;

  aboutToAppear(): void {
    this.resetFromBook();
    this.bindKeyboardAvoidance();
  }

  aboutToDisappear(): void {
    this.unbindKeyboardAvoidance();
    this.closeKindDialog();
  }

  /**
   * A-8：`.imePadding()` 的本地等价。
   *
   * 上游 `BookInfoEditContent` 挂 `Modifier.imePadding()`，键盘弹起时整块内容上推。
   * ArkUI 侧无同名修饰符（全仓 `imePadding` / `KeyboardAvoidMode` 0 命中），
   * 用 `window.on('keyboardHeightChange')`（`@ohos.window.d.ts` 的该事件给出键盘高度 px）自建：
   * 把高度换算成 vp 后作为内容区底部留白，键盘收起时归零。
   */
  private bindKeyboardAvoidance(): void {
    const context = this.getUIContext().getHostContext();
    if (context === undefined) { return; }
    window.getLastWindow(context).then((targetWindow: window.Window) => {
      this.editWindow = targetWindow;
      this.keyboardListener = (height: number): void => {
        const density: number = this.getUIContext().getHostContext() === undefined
          ? 1 : (this.getUIContext().vp2px(1) || 1);
        const vp: number = density > 0 ? Math.round(height / density) : 0;
        if (vp !== this.keyboardHeight) { this.keyboardHeight = vp; }
      };
      targetWindow.on('keyboardHeightChange', this.keyboardListener);
    }).catch(() => {});
  }

  private unbindKeyboardAvoidance(): void {
    if (this.editWindow !== undefined && this.keyboardListener !== undefined) {
      this.editWindow.off('keyboardHeightChange', this.keyboardListener);
    }
    this.editWindow = undefined;
    this.keyboardListener = undefined;
  }

  /** A-9：上游 `uiState.book?.let { ... }`，book 为 null 时整页内容不渲染。 */
  private hasBook(): boolean {
    return this.book.id.length > 0;
  }

  /** 每次进入都从当前书籍取一遍，避免上一本书的编辑残留带过来。 */
  private resetFromBook(): void {
    this.title = this.book.title;
    this.author = this.book.author;
    this.category = this.book.category;
    // I-4：上游 `coverUrl = it.getDisplayCover()`（自定义封面优先，见 `Book.kt:183`）。
    const customCover: string = this.book.customCoverUri ?? '';
    this.coverUrl = customCover.length > 0 ? customCover : (this.book.coverUri ?? '');
    // I-5：上游 `intro = it.getDisplayIntro()`（自定义简介优先，见 `Book.kt:185`）。
    this.description = displayIntroOf(this.book);
    this.remark = this.book.remark ?? '';
    this.customTag = this.book.customTag ?? '';
    // I-7：上游 `customTags = it.customTag?.splitNotBlank(",", "\n").orEmpty().distinct()`。
    // 本地原来只切分不去重，重复标签会在编辑器里出现两次。
    this.kindList = this.splitTags(this.book.customTag ?? '');
    this.originalKindList = this.kindList.slice(0);
    this.groupNames = (this.book.groupNames ?? []).slice(0);
    this.bookType = this.book.bookType ?? 'text';
    this.fixedType = this.book.fixedType === true;
  }

  /** 按逗号/中文逗号/换行切分并去重（上游 `splitNotBlank(",", "\n")` + `.distinct()`）。 */
  private splitTags(raw: string): string[] {
    const parts: string[] = raw.split(/[\n,，]/);
    const result: string[] = [];
    for (const part of parts) {
      const trimmed: string = part.trim();
      if (trimmed.length > 0 && result.indexOf(trimmed) < 0) { result.push(trimmed); }
    }
    return result;
  }

  /**
   * I-6：书源分类只读展示。
   *
   * 上游 `sourceKindList = it.kind?.splitNotBlank(",", "\n").orEmpty().distinct()`，
   * 用 `joinToString(", ")` 填进 readOnly 的输入框。本地 `book.kind` 是同一语义的字段
   * （`model/Book.ets:145`，与 books 表 kind 列同列）；本地书没有 kind，回落到 `category`。
   */
  private sourceKindText(): string {
    const kind: string = this.book.kind ?? '';
    const raw: string = kind.length > 0 ? kind : this.category;
    return this.splitTags(raw).join(', ');
  }

  private pageSurface(): ResourceColor {
    if (this.themeAppBackground.length > 0) { return Color.Transparent; }
    return this.themePureBlack ? '#000000' : this.themeColorSurfacePrimary;
  }

  /** 输入框底色：对齐上游 `surfaceInput`（`BookInfoEditScreen.kt:242` 起七处 `AppTextField`）。 */
  private inputSurface(): ResourceColor {
    return this.themePureBlack ? '#141414' : this.themeColorSurfaceInput;
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

  /** A-5：顶栏随内容滚动折叠，口径同 `AppBackupSettingsPage.updateHeader`。 */
  private updateHeader(): void {
    const offset: number = this.scroller.currentOffset().yOffset;
    const shouldCollapse: boolean = offset > HEADER_COLLAPSE_THRESHOLD ? true
      : offset < HEADER_EXPAND_THRESHOLD ? false : this.collapsedHeader;
    if (shouldCollapse !== this.collapsedHeader) {
      this.getUIContext().animateTo({ curve: curves.springMotion(0.35, 0.86) }, () => {
        this.collapsedHeader = shouldCollapse;
      });
    }
    const fraction: number = Math.max(0, Math.min(1, offset / HEADER_COLLAPSE_THRESHOLD));
    if (fraction !== this.headerFraction) { this.headerFraction = fraction; }
  }

  // ── 我的标签：拖动排序（G-4/G-5/G-6/G-7）─────────────────────────────────

  /**
   * 拖动重排。
   *
   * 上游 `moveKind(from, to) { mutable.add(to, mutable.removeAt(from)); onKindListChange(mutable) }`，
   * 本地用 ArkUI `List` 的 `onItemDragStart` / `onItemDrop` 承载（`BookshelfManagePage.ets:2253-2279`
   * 是同一套范式的先例），回调里按同样的「先删后插」改写。
   */
  private moveKind(from: number, to: number): void {
    if (from === to || from < 0 || to < 0) { return; }
    if (from >= this.kindList.length || to >= this.kindList.length) { return; }
    const next: string[] = this.kindList.slice(0);
    const moved: string[] = next.splice(from, 1);
    next.splice(to, 0, moved[0]);
    this.setKindList(next);
  }

  /**
   * I-13：去重收到统一 setter。
   *
   * 上游所有改标签的入口都走 `onKindListChange(kindList) { copy(kindList = kindList.distinct()) }`，
   * 去重只在这一处发生。本地原来只有对话框确认那一处去重，拖动排序与重置都绕过去了。
   */
  private setKindList(next: string[]): void {
    const deduped: string[] = [];
    for (const item of next) {
      if (deduped.indexOf(item) < 0) { deduped.push(item); }
    }
    // G-8：上游 `KindChip` 外层挂 `.animateItem()`，标签增删与拖动后位置变化走默认 spring 动画。
    // ArkUI 的 List 没有同名能力，用 `animateTo` 包住整份列表替换，位移与淡入都能被感知到。
    this.getUIContext().animateTo({ curve: curves.springMotion(0.35, 0.86) }, () => {
      this.kindList = deduped;
    });
  }

  // ── 标签编辑对话框（H-1..H-10）：AppAlertDialog + openCustomDialog ──────────

  private openKindDialog(): void {
    if (this.kindDialogId >= 0) { return; }
    this.kindDialogBuilder = (): void => { this.kindDialog(); };
    this.getUIContext().getPromptAction().openCustomDialog({
      builder: this.kindDialogBuilder,
      autoCancel: true,
      alignment: DialogAlignment.Center,
      onWillDismiss: () => {
        this.kindDialogId = -1;
        this.kindEditingIndex = -2;
      }
    }).then((id: number) => {
      this.kindDialogId = id;
    }).catch((error: Error) => {
      console.error(`[BookInfoEdit] 打开标签编辑对话框失败: ${error}`);
    });
  }

  private closeKindDialog(): void {
    if (this.kindDialogId >= 0) {
      this.getUIContext().getPromptAction().closeCustomDialog(this.kindDialogId);
      this.kindDialogId = -1;
    }
    this.kindEditingIndex = -2;
  }

  private onKindDialogConfirm(): void {
    const trimmed: string = this.kindEditingText.trim();
    if (trimmed.length > 0) {
      const next: string[] = this.kindList.slice(0);
      if (this.kindEditingIndex === -1) {
        if (next.indexOf(trimmed) < 0) { next.push(trimmed); }
      } else {
        next[this.kindEditingIndex] = trimmed;
      }
      this.setKindList(next);
    }
    this.closeKindDialog();
  }

  private onKindDialogDismiss(): void {
    // 编辑态的否定按钮是「删除」（上游 `:536-546`）。
    if (this.kindEditingIndex >= 0) {
      const next: string[] = this.kindList.slice(0);
      next.splice(this.kindEditingIndex, 1);
      this.setKindList(next);
    }
    this.closeKindDialog();
  }

  // ── @Builder ──────────────────────────────────────────────────────────────

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
   * 封面右侧的描边图标按钮，对齐上游 `MediumOutlinedButton(icon = ...)`
   * （`BookInfoEditScreen.kt:194-208` 三个按钮只有图标、无文字）：
   * 40×40、图标 24、`BorderStroke(1.dp, outlineVariant)`。
   */
  @Builder
  coverIconAction(icon: AppGlyphName, label: string, action: () => void) {
    Stack({ alignContent: Alignment.Center }) {
      AppGlyph({ name: icon, glyphSize: COVER_ACTION_ICON, tint: this.themeColorTextSecondary })
    }
    .width(COVER_ACTION_SIZE).height(COVER_ACTION_SIZE).borderRadius(COVER_ACTION_SIZE / 2)
    .border({ width: 1, color: this.themeColorTextTertiary })
    .onClick(() => action())
    .accessibilityText(label)
  }

  /**
   * 知识卡：上游 `BookInfoEditScreen.kt:296-349` 的 `BookKnowledgeEditCard`。
   * 一张 `NormalCard`（默认 `surfaceContainer` 底 + 16 圆角），标题「知识」+ 一行四个
   * `MediumOutlinedButton`（人物 / 关系网 / 世界知识 / 剧情事件）。
   */
  @Builder
  knowledgeCard() {
    Column({ space: SPACE_12 }) {
      Text('知识').fontSize(TITLE_MEDIUM).fontWeight(FontWeight.Medium).fontColor(this.themeColorTextPrimary)
      Scroll() {
        Row({ space: CHIP_SPACING }) {
          this.knowledgeChip('list', '人物', 0)
          this.knowledgeChip('group', '关系网', 1)
          this.knowledgeChip('book', '世界知识', 2)
          this.knowledgeChip('profileTimeline', '剧情事件', 3)
        }.alignItems(VerticalAlign.Center)
      }
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Off)
      .align(Alignment.Start)
      .width('100%')
    }
    .width('100%').alignItems(HorizontalAlign.Start)
    .padding(16)
    .backgroundColor(this.themeColorSurfaceContainer).borderRadius(RADIUS_CARD)
  }

  /**
   * 知识卡的单个描边按钮（上游 `MediumOutlinedButton`），tabIndex 对应面板 tab。
   * E-5：`enabled = bookUrl.isNotEmpty()` —— 没有书标识时四个按钮禁用（上游同款判定）。
   */
  @Builder
  knowledgeChip(icon: AppGlyphName, label: string, tabIndex: number) {
    Row({ space: CHIP_SPACING }) {
      AppGlyph({ name: icon, glyphSize: CHIP_ICON, tint: this.themeColorTextSecondary })
      Text(label).fontSize(LABEL_MEDIUM).fontColor(this.themeColorTextPrimary)
    }
    .padding({ left: CHIP_PADDING_H, right: CHIP_PADDING_H, top: CHIP_PADDING_V, bottom: CHIP_PADDING_V })
    .border({ width: 1, color: this.themeColorTextTertiary })
    .borderRadius((CHIP_ICON + CHIP_PADDING_V * 2) / 2)
    .enabled(this.knowledgeBookUrl().length > 0)
    .opacity(this.knowledgeBookUrl().length > 0 ? 1 : 0.38)
    .onClick(() => {
      this.knowledgeSheetTab = tabIndex;
      this.knowledgeSheetVisible = true;
    })
  }

  /** 知识库的书籍标识（上游 `uiState.book?.bookUrl.orEmpty()`）。 */
  private knowledgeBookUrl(): string {
    const contentPath: string = this.book.contentPath ?? '';
    if (contentPath.length > 0) { return contentPath; }
    return this.book.androidOriginalPath ?? '';
  }

  /**
   * 我的标签编辑器：上游 `KindEditor`（`BookInfoEditScreen.kt:408-549`）。
   *
   * 结构：`Column(padding vertical 8.dp, spacedBy 4.dp)` → 标题「我的标签」（`AppText` 默认
   * bodyMedium + onSurface）→ `Row` 内 `LazyRow(fadingEdge, contentPadding vertical 4.dp,
   * spacedBy 8.dp)` + 重置 + 新增两个 40dp 描边按钮。
   * 本地 `LazyRow` 对应横向 `List`：既拿到 `fadingEdge`，也拿到 `editMode(true)` 的拖拽回调。
   */
  @Builder
  kindEditor() {
    Column({ space: KIND_EDITOR_SPACING }) {
      Text('我的标签').fontSize(BODY_MEDIUM).fontColor(this.themeColorTextPrimary)
        .width('100%').textAlign(TextAlign.Start)
      Row({ space: CHIP_SPACING }) {
        List({ space: CHIP_SPACING }) {
          ForEach(this.kindList, (kind: string, index: number) => {
            ListItem() {
              this.kindChip(kind, index)
            }
          }, (kind: string) => kind)
        }
        .listDirection(Axis.Horizontal)
        .height(CHIP_ICON + CHIP_PADDING_V * 2 + KIND_CHIP_PADDING_V * 2 + 4)
        .padding({ top: 4, bottom: 4 })
        .layoutWeight(1)
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.Spring)
        // G-3：上游 `fadingEdge(listState)`，两端渐隐提示还能横向滚。
        .fadingEdge(true)
        // G-4：上游 `ReorderableItem` + `longPressDraggableHandle`，本地走 List 的拖拽回调。
        .editMode(true)
        .onItemDragStart((_event: ItemDragInfo, itemIndex: number) => {
          // G-5：上游 `onDragStarted { performHapticFeedback(GestureThresholdActivate) }`。
          UiHaptics.dragThresholdActivate();
          this.dragFrom = itemIndex;
        })
        .onItemDragMove((_event: ItemDragInfo, itemIndex: number, insertIndex: number) => {
          // G-5：上游跨位时发 `SegmentFrequentTick`。
          if (insertIndex !== itemIndex) { UiHaptics.dragTick(); }
        })
        .onItemDrop((_event: ItemDragInfo, itemIndex: number, insertIndex: number, isSuccess: boolean) => {
          // G-5：上游 `onDragStopped { performDragEnd }`。
          UiHaptics.dragEnd();
          if (!isSuccess) { return; }
          this.moveKind(itemIndex, insertIndex);
        })

        // G-13：重置，图标是上游 `Icons.Default.Replay`（本地新增 replay 字形）。
        this.kindAction('replay', '重置', () => { this.setKindList(this.originalKindList.slice(0)); })
        // G-14：新增，`editingIndex = -1`。
        this.kindAction('add', '添加', () => {
          this.kindEditingIndex = -1;
          this.kindEditingText = '';
          this.openKindDialog();
        })
      }.width('100%').alignItems(VerticalAlign.Center)
    }
    .width('100%').alignItems(HorizontalAlign.Start)
    .padding({ top: KIND_EDITOR_PADDING_V, bottom: KIND_EDITOR_PADDING_V })
  }

  /** 拖拽起点下标（G-6 需要判断哪一枚正在被拖，用于抬升 + 层级）。 */
  @State private dragFrom: number = -1;

  /**
   * 单枚标签胶囊：上游 `KindChip`（`:551-578`）。
   *
   * `NormalCard(cornerRadius = 8.dp, containerColor = surfaceContainer, elevation = if (isDragging) 2.dp else 0.dp)`
   * 外套 `padding(2.dp).zIndex(if (isDragging) 1f else 0f)`，内层文字
   * `labelLargeEmphasized` + `padding(horizontal 8.dp, vertical 4.dp)`。
   */
  @Builder
  kindChip(kind: string, index: number) {
    Row() {
      Text(kind).fontSize(LABEL_LARGE_EMPHASIZED).fontWeight(FontWeight.Medium)
        .fontColor(this.themeColorTextPrimary).maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .padding({ left: KIND_CHIP_PADDING_H, right: KIND_CHIP_PADDING_H, top: KIND_CHIP_PADDING_V, bottom: KIND_CHIP_PADDING_V })
    .backgroundColor(this.themeColorSurfaceContainer).borderRadius(KIND_CHIP_RADIUS)
    // G-6：拖拽中抬升 2dp + 层级提到最前（上游 `elevation = 2.dp` + `zIndex(1f)`）。
    .shadow(this.dragFrom === index
      ? { radius: 4, color: '#33000000', offsetY: 2 } : { radius: 0, color: '#00000000', offsetY: 0 })
    .zIndex(this.dragFrom === index ? 1 : 0)
    // G-7：上游 `reorderAccessibility(index, itemCount, onMove)` 让读屏用户能上下移动标签。
    // ArkUI 没有对应修饰符，用 accessibilityText 把位置与「可长按拖动」说出来。
    .accessibilityText(`${kind}，第 ${index + 1} 个，共 ${this.kindList.length} 个，长按可拖动排序`)
    .onClick(() => {
      this.kindEditingIndex = index;
      this.kindEditingText = kind;
      this.openKindDialog();
    })
  }

  /** 标签编辑器右侧的 40dp 描边图标按钮（上游 `MediumOutlinedButton(icon = ...)`）。 */
  @Builder
  kindAction(icon: AppGlyphName, label: string, action: () => void) {
    Stack({ alignContent: Alignment.Center }) {
      AppGlyph({ name: icon, glyphSize: COVER_ACTION_ICON, tint: this.themeColorTextSecondary })
    }
    .width(COVER_ACTION_SIZE).height(COVER_ACTION_SIZE).borderRadius(COVER_ACTION_SIZE / 2)
    .border({ width: 1, color: this.themeColorTextTertiary })
    .onClick(() => action())
    .accessibilityText(label)
  }

  /**
   * 标签编辑对话框：-1 新增、>=0 改名（上游 `:503-548` 的 `AppAlertDialog`）。
   * H-1/H-9/H-10：宽度 312、圆角 28、M3 默认宽度——都落在 `AppAlertDialog` 里。
   */
  @Builder
  kindDialog() {
    AppAlertDialog({
      title: this.kindEditingIndex === -1 ? '添加标签' : '编辑标签',
      confirmText: '确认',
      dismissText: this.kindEditingIndex === -1 ? '取消' : '删除',
      onConfirm: () => { this.onKindDialogConfirm(); },
      onDismiss: () => { this.onKindDialogDismiss(); },
      content: () => { this.kindDialogContent() }
    })
  }

  @Builder
  kindDialogContent() {
    Column() {
      this.m3Input('标签', this.kindEditingText, '请输入标签',
        (value: string) => { this.kindEditingText = value; })
    }.width('100%')
  }

  @Builder
  fieldLabel(text: string) {
    Text(text).fontSize(LABEL_MEDIUM).fontColor(this.themeColorTextTertiary)
      .width('100%').margin({ bottom: 6 })
  }

  /**
   * 单行输入框，对齐上游 `AppTextField`（material3 `TextFieldDefaults.shape`）：
   * 4dp 圆角、label 内嵌在框内左上（`labelPosition = TextFieldLabelPosition.Inside()`）、
   * 底部一条 indicator。
   *
   * F-10/F-12：本地原来把 label 画在圆角底**外面**（`fieldLabel` 独立一行），
   * 上游是内嵌在同一块底里的浮动 label，这里改成同块。
   */
  @Builder
  m3Input(label: string, text: string, placeholder: string, onChange: (value: string) => void) {
    Column() {
      Text(label).fontSize(LABEL_MEDIUM).fontColor(this.themeColorTextTertiary)
        .width('100%').margin({ bottom: 2 })
      TextInput({ text: text, placeholder: placeholder })
        .fontSize(TYPE_SCALE_BODY_LARGE).fontColor(this.themeColorTextPrimary)
        .placeholderColor(this.themeColorTextTertiary)
        .backgroundColor(Color.Transparent)
        .padding({ left: 0, right: 0, top: 0, bottom: 6 })
        .height(30)
        .onChange((value: string) => onChange(value))
      // indicator：material3 未聚焦时是一条 `outline` 色的细线。
      Row().width('100%').height(1).backgroundColor(this.themeColorTextTertiary)
    }
    .width('100%').constraintSize({ minHeight: FIELD_M3_HEIGHT })
    .padding({ left: 16, right: 16, top: 8, bottom: 8 })
    .backgroundColor(this.inputSurface()).borderRadius(FIELD_M3_RADIUS)
  }

  /** 只读输入框（书源分类）：同一形态，但不可编辑（上游 `readOnly = true`）。 */
  @Builder
  m3ReadonlyInput(label: string, text: string) {
    Column() {
      Text(label).fontSize(LABEL_MEDIUM).fontColor(this.themeColorTextTertiary)
        .width('100%').margin({ bottom: 2 })
      Text(text.length > 0 ? text : '暂无分类')
        .fontSize(TYPE_SCALE_BODY_LARGE)
        .fontColor(text.length > 0 ? this.themeColorTextPrimary : this.themeColorTextTertiary)
        .width('100%').maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
        .height(30)
      Row().width('100%').height(1).backgroundColor(this.themeColorTextTertiary)
    }
    .width('100%').constraintSize({ minHeight: FIELD_M3_HEIGHT })
    .padding({ left: 16, right: 16, top: 8, bottom: 8 })
    .backgroundColor(this.inputSurface()).borderRadius(FIELD_M3_RADIUS)
  }

  /**
   * 多行输入框（内容简介 / 书籍备注）：上游也是 `AppTextField`
   * （`lineLimits = TextFieldLineLimits.Default` → 多行），label 同样内嵌在框内。
   */
  @Builder
  m3TextArea(label: string, text: string, placeholder: string, minHeight: number,
    onChange: (value: string) => void) {
    Column() {
      Text(label).fontSize(LABEL_MEDIUM).fontColor(this.themeColorTextTertiary)
        .width('100%').margin({ bottom: 2 })
      TextArea({ text: text, placeholder: placeholder })
        .fontSize(TYPE_SCALE_BODY_LARGE).fontColor(this.themeColorTextPrimary)
        .placeholderColor(this.themeColorTextTertiary)
        .backgroundColor(Color.Transparent)
        .padding({ left: 0, right: 0, top: 0, bottom: 6 })
        .constraintSize({ minHeight: minHeight - 40 })
        .onChange((value: string) => onChange(value))
      Row().width('100%').height(1).backgroundColor(this.themeColorTextTertiary)
    }
    .width('100%').constraintSize({ minHeight: minHeight })
    .padding({ left: 16, right: 16, top: 8, bottom: 8 })
    .backgroundColor(this.inputSurface()).borderRadius(FIELD_M3_RADIUS)
  }

  @Builder
  navSlot() {
    TopBarBackButton({ onSelect: () => this.onBack() })
  }

  @Builder
  topActions() {
    // 保存按钮：上游是顶栏右侧一个 Save 图标（`Icons.Default.Save` + `R.string.save`）。
    TopBarButton({ icon: 'profileSave', showDivider: false, accessibilityLabel: '保存', onSelect: () => { this.submit(); } })
  }

  /** 换封面面板（B-9）：上游 `ChangeCoverSheet`，选中即回写封面链接。 */
  @Builder
  changeCoverContent() {
    ChangeCoverSheet({
      bookName: this.title,
      author: this.author,
      isNight: false,
      onSelect: (coverUrl: string) => {
        this.coverUrl = coverUrl;
        this.changeCoverVisible = false;
      },
      onMessage: (message: string) => { this.onUnavailableAction(message); }
    })
  }

  build() {
    // 根节点用 Stack：页面本体 + 换封面面板浮层 + 知识库面板（ArkUI 要求 build 只有一个根节点）。
    Stack({ alignContent: Alignment.Center }) {
      Column() {
        AppTopBar({
          title: '书籍信息编辑',
          collapsed: this.collapsedHeader,
          collapseFraction: this.headerFraction,
          hasNavigation: true,
          navigationIcon: () => { this.navSlot() },
          actions: () => { this.topActions() }
        })

        // A-9：上游 `uiState.book?.let { ... }`，没有书时内容区整块不渲染。
        if (this.hasBook()) {
          Scroll(this.scroller) {
            Column() {
              // 封面行：上游 `:170-221` —— 左边 110dp 封面，右边一列：三个 40dp 描边图标按钮
              // （刷新封面 / 选择文件夹 / 还原封面），下面 4dp 间隔再跟书籍类型下拉。
              Row({ space: SPACE_16 }) {
                BookCover({
                  book: this.book,
                  displayWidth: 110,
                  displayHeight: 154,
                  coverSettings: this.coverSettings,
                  applyAspectRatio: true,
                  // B-4：上游画的是 `uiState.coverUrl` 这个草稿值，换封面面板选完 / 改「封面链接」
                  // 要立刻在预览里看到，不必先保存。
                  overrideCoverUri: this.coverUrl
                })
                Column({ space: SPACE_8 }) {
                  Row({ space: SPACE_12 }) {
                    // B-9：上游 `onClick = { showChangeCoverSheet = true }`，接换封面面板。
                    this.coverIconAction('profileRefresh', '刷新封面', () => { this.changeCoverVisible = true; })
                    this.coverIconAction('profileFolder', '选择文件夹', () => this.onChooseCover())
                    this.coverIconAction('replay', '封面已重置', () => this.onRestoreCover())
                  }.justifyContent(FlexAlign.Center)
                  Blank().height(4)
                  // C-1/C-2/C-5：上游 `BookTypeDropdown` 是 `ExposedDropdownMenuBox`
                  // 内一个带 label「书籍类型」的 readOnly `AppTextField`，整体再
                  // `padding(horizontal = 8.dp)`。本地原来没有 label，也没有这段水平内边距。
                  Column() {
                    this.bookTypeField()
                  }.width('100%').padding({ left: 8, right: 8 })
                }.layoutWeight(1).alignItems(HorizontalAlign.Center)
              }.width('100%').alignItems(VerticalAlign.Center)

              // F-7：大区块之间 `Spacer(16.dp)`（上游 `:222` / `:230` / `:237` 三处）。
              Blank().height(SPACE_16)
              this.knowledgeCard()

              Blank().height(SPACE_16)
              // D-2：固定书籍类型开关。上游 `SwitchSettingItem` 自带 `inputSurface` 底与分隔线，
              // 本地 `UiSwitch` 也画了底色，容器再包一层就会叠出两种灰，这里只留组件自身。
              UiSwitch({
                title: '固定书籍类型',
                detail: '书籍更新后不覆盖书籍类型',
                value: this.fixedType,
                showDivider: false,
                onChange: (enabled: boolean) => { this.fixedType = enabled; }
              })

              Blank().height(SPACE_16)
              // F-7：字段之间 `Spacer(8.dp)`，共六处（上游 `:239` `:246` `:253` `:260` `:267` `:274` `:281`）。
              this.m3Input('书名', this.title, '请输入书名', (value: string) => { this.title = value; })
              Blank().height(SPACE_8)
              this.m3Input('作者', this.author, '请输入作者', (value: string) => { this.author = value; })
              Blank().height(SPACE_8)
              this.m3Input('封面链接', this.coverUrl, '请输入封面链接', (value: string) => { this.coverUrl = value; })
              Blank().height(SPACE_8)
              // F-4：书源分类是 readOnly 展示（上游 `onValueChange = {}` + `readOnly = true`），
              // 本地原来允许编辑并写回 category，与上游语义不符。
              this.m3ReadonlyInput('书源分类', this.sourceKindText())
              Blank().height(SPACE_8)
              this.kindEditor()
              Blank().height(SPACE_8)
              this.m3TextArea('内容简介', this.description, '请输入内容简介', 120,
                (value: string) => { this.description = value; })
              Blank().height(SPACE_8)
              this.m3TextArea('书籍备注', this.remark, '请输入书籍备注', 96,
                (value: string) => { this.remark = value; })

              // F-13：分组多选是本地扩展（上游编辑页没有分组字段），排在上游字段之后。
              Blank().height(SPACE_8)
              Column() {
                this.fieldLabel('分组')
                Row() {
                  Text(this.groupNames.length > 0 ? this.groupNames.join('、') : '本地未分组')
                    .fontSize(TYPE_SCALE_BODY_LARGE).fontColor(this.themeColorTextPrimary)
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
            .padding({ left: SPACE_16, right: SPACE_16, top: SPACE_16, bottom: SPACE_16 + this.keyboardHeight })
          }
          // A-6：上游是裸 `verticalScroll(rememberScrollState())`，没有 edgeEffect。
          .edgeEffect(EdgeEffect.None)
          .layoutWeight(1)
          .width('100%')
          .scrollBar(BarState.Off)
          .align(Alignment.Top)
          .onDidScroll(() => { this.updateHeader(); })
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor(this.pageSurface())

      // 换封面面板（B-9）：遮罩 + 底部面板，形态对齐上游 `AppModalBottomSheet`。
      if (this.changeCoverVisible) {
        Stack({ alignContent: Alignment.Bottom }) {
          Column().width('100%').height('100%').backgroundColor('#99000000')
            .onClick(() => { this.changeCoverVisible = false; })
          Column() {
            this.changeCoverContent()
          }
          .width('100%')
          .backgroundColor(this.themeColorSurfaceTertiary)
          .borderRadius({ topLeft: 28, topRight: 28 })
        }.width('100%').height('100%').zIndex(110)
      }

      // 知识库四面板，四个 chip 打开对应 tab。
      if (this.knowledgeSheetVisible) {
        BookKnowledgeSheet({
          bookUrl: this.knowledgeBookUrl(),
          initialTab: this.knowledgeSheetTab,
          onClose: () => { this.knowledgeSheetVisible = false; }
        }).width('100%').height('100%').zIndex(120)
      }
    }
    .width('100%')
    .height('100%')
  }

  /** 书籍类型下拉（C-1）：带 label 的 readOnly 输入框 + 右侧展开箭头 + 弹出菜单。 */
  @Builder
  bookTypeField() {
    // C-5：上游 `BookInfoEditScreen.kt:370` `ExposedDropdownMenuBox(modifier = Modifier.padding(horizontal = 8.dp))`
    // —— 整个下拉框外层再左右各收 8dp，比其余字段窄一圈。本地原来只有框内边距，缺这一层。
    Column() {
      Column() {
        Text('书籍类型').fontSize(LABEL_MEDIUM).fontColor(this.themeColorTextTertiary)
          .width('100%').margin({ bottom: 2 })
        Row() {
          Text(this.bookTypeLabel(this.bookType)).fontSize(TYPE_SCALE_BODY_LARGE)
            .fontColor(this.themeColorTextPrimary).layoutWeight(1)
          AppGlyph({ name: 'profileExpandMore', glyphSize: 20, tint: this.themeColorTextTertiary })
        }.width('100%').height(30)
        Row().width('100%').height(1).backgroundColor(this.themeColorTextTertiary)
      }
      .width('100%').constraintSize({ minHeight: FIELD_M3_HEIGHT })
      .padding({ left: 16, right: 16, top: 8, bottom: 8 })
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
    }
    .width('100%').padding({ left: 8, right: 8 })
  }
}
