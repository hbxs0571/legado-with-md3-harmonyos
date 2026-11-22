// 发现分类的条目与分类选择面板。
//
// 对齐上游三个文件：
// - `ui/widget/components/explore/ExploreKindItem.kt`（146 行）：分类条目的外观 ——
//   `GlassCard(cornerRadius = 12.dp)`，选中时 `primaryContainer` 底 + `onPrimaryContainer` 字，
//   可点时 `onSurface` 字，不可点时 `primary` 字；文字 `labelMediumEmphasized` 居中单行，
//   尾部图标绝对贴在 `CenterEnd`（padding end 8dp），文字右侧让位 18dp。
// - `ui/widget/components/explore/ExploreKindMultiTypeItem.kt`（398 行）：按 `kind.type`
//   分五种交互 —— `url` 点开链接、`button` 执行 action、`text` 输入框（debounce 600ms）、
//   `toggle` 轮转 chars、`select` 弹下拉；解析失败的分类点开看完整报错。
// - `ui/widget/components/explore/ExploreKindSelectSheet.kt`（170 行）：分类选择面板 ——
//   顶部搜索行（占位「选择或搜索分类」），下面按 `calculateExploreKindRows(kinds, 6)` 分行，
//   单选模式点条目即提交并关闭。
//
// 与上游的一处差别（记入 `tmp/appearance-impl-report.md` 待办账本）：
// 上游 `TextTypeItem` 的输入框组件是 `ExploreKindCompactTextField`（未在本地移植），
// 这里用 `TextInput` 按同一套尺寸（圆角 12、垂直 8 内边距、`labelMediumEmphasized` 字号）自绘。
import { BookSourceStageWebRuntime } from '@legado/sourceengine';
import {
  calculateExploreKindRows,
  ExploreKind,
  ExploreKindParser,
  ExploreKindSpan,
  exploreKindErrorMsg,
  EXPLORE_KIND_TYPE_BUTTON,
  EXPLORE_KIND_TYPE_SELECT,
  EXPLORE_KIND_TYPE_TEXT,
  EXPLORE_KIND_TYPE_TOGGLE,
  EXPLORE_KIND_TYPE_URL
} from '../../bookSource/ExploreKind';
import { ExploreKindAction, ExploreKindActionOutcome } from '../../bookSource/ExploreKindAction';
import { AppGlyph, AppGlyphName } from '../AppGlyph';
import {
  BODY_MEDIUM,
  LABEL_MEDIUM,
  LABEL_MEDIUM_EMPHASIZED,
  LABEL_MEDIUM_EMPHASIZED_LINE_HEIGHT,
  LABEL_SMALL
} from '../typography/TypographyTokens';
import { SPACE_12, SPACE_16, SPACE_4, SPACE_8 } from '../UiTokens';
import { UiMenuItem, UiMenuPanel } from '../UiMenu';

/** 分类条目占的列数上限（上游 `calculateExploreKindRows(kinds, 6)`）。 */
const KIND_MAX_SPAN: number = 6;
/** 分类条目圆角，对齐上游 `ExploreKindItem.kt:52 val cornerRadius = 12.dp`。 */
const KIND_CORNER_RADIUS: number = 12;
/** 尾部图标尺寸，对齐上游 `Modifier.height(14.dp)`。 */
const TRAILING_ICON_SIZE: number = 14;
/** 尾部图标右侧留白，对齐上游 `padding(end = 8.dp)`。 */
const TRAILING_ICON_END: number = 8;
/** 文字右侧为尾部图标让出的宽度，对齐上游 `padding(end = 18.dp)`。 */
const TRAILING_TEXT_INSET: number = 18;
/** 输入框 debounce，对齐上游 `TextTypeItem` 的 `delay(600)`。 */
const TEXT_ACTION_DEBOUNCE_MS: number = 600;

/**
 * 一条发现分类。`showTrailing` 由类型决定，`selected` 由面板决定。
 * 上游 `ExploreKindMultiTypeItem` 的 `content` 参数（调用方自绘）在本地两处调用方都不传，
 * 所以不提供该插槽。
 */
@Component
export struct ExploreKindItem {
  @StorageProp('themeColorTextPrimary') themeColorTextPrimary: string = '#1B1C22';
  @StorageProp('themeColorPrimaryContainer') themeColorPrimaryContainer: string = '#DCE1FF';
  @StorageProp('themeColorOnPrimaryContainer') themeColorOnPrimaryContainer: string = '#00174B';
  @StorageProp('themeColorAccent') themeColorAccent: string = '#3F5BD9';
  @StorageProp('themeColorSurfaceTertiary') themeColorSurfaceTertiary: string = '#F0F1F5';
  @StorageProp('themeColorOutlineVariant') themeColorOutlineVariant: string = '#C6C7D0';

  @Prop kind: ExploreKind = new ExploreKind();
  @Prop sourceUrl: string = '';
  /** 面板多选模式下是否已选中。 */
  @Prop selected: boolean = false;
  /** 面板单选模式：点条目直接提交（上游 `onClick != null` 的分支）。 */
  @Prop submitOnClick: boolean = false;
  /** 面板多选模式：点条目切换选中。 */
  @Prop toggleOnClick: boolean = false;

  /** 点 url 型分类：把解析出的 url 交给面板（面板负责提交并关闭）。 */
  onOpenUrl: (kind: ExploreKind, url: string) => void = () => {};
  /** 点条目（单选/多选模式）。 */
  onItemClick: (kind: ExploreKind) => void = () => {};
  /** 脚本要求刷新分类列表（上游 `java.reUiView()`）。 */
  onRefreshKinds: () => void = () => {};
  /** 提示信息（脚本返回的 toast / 错误）。 */
  onMessage: (text: string) => void = () => {};

  /** 求值 viewName 之后的显示名；空串表示还没算出来，用 kind.title。 */
  @State private displayName: string = '';
  /** toggle / select 的当前取值。 */
  @State private currentValue: string = '';
  @State private selectVisible: boolean = false;
  @State private textValue: string = '';
  @State private errorDetail: string = '';
  @State private errorVisible: boolean = false;

  private textActionTimer: number = -1;

  /** 上游 `kind.chars?.filterNotNull().takeUnless { it.isNullOrEmpty() } ?: listOf("chars", "is null")`。 */
  private charsList(): string[] {
    if (this.kind.hasChars && this.kind.chars.length > 0) { return this.kind.chars; }
    return ['chars', 'is null'];
  }

  /** 上游 `kind.style().layout_justifySelf != "right"`：为真时取值在文字左侧。 */
  private valueOnLeft(): boolean {
    return this.kind.style.layoutJustifySelf !== 'right';
  }

  /** 上游 `rememberTrailingIcon`：button→箭头、toggle→刷新、select→展开，其余不画。 */
  private trailingGlyph(): string {
    if (this.kind.type === EXPLORE_KIND_TYPE_BUTTON) { return 'arrowForward'; }
    if (this.kind.type === EXPLORE_KIND_TYPE_TOGGLE) { return 'profileRefresh'; }
    if (this.kind.type === EXPLORE_KIND_TYPE_SELECT) { return 'unfoldMore'; }
    return '';
  }

  private trailingTint(): string {
    if (this.selected) {
      // 上游 `onPrimaryContainer.copy(alpha = 0.7f)`。
      return this.themeColorOnPrimaryContainer;
    }
    return this.themeColorOutlineVariant;
  }

  /** 上游 `ExploreKindItem` 的三档内容色。 */
  private contentColor(): string {
    if (this.selected) { return this.themeColorOnPrimaryContainer; }
    if (this.clickable()) { return this.themeColorTextPrimary; }
    return this.themeColorAccent;
  }

  /** 上游 `isClickable`：错误项、面板的两种点法、url/button 都算可点。 */
  private clickable(): boolean {
    if (exploreKindErrorMsg(this.kind).length > 0) { return true; }
    if (this.submitOnClick || this.toggleOnClick) { return true; }
    return this.kind.type === EXPLORE_KIND_TYPE_URL || this.kind.type === EXPLORE_KIND_TYPE_BUTTON
      || this.kind.type === EXPLORE_KIND_TYPE_TOGGLE || this.kind.type === EXPLORE_KIND_TYPE_SELECT;
  }

  /** 卡片底色：选中用 primaryContainer，否则 surfaceContainer（本地对应 surfaceTertiary）。 */
  private containerColor(): string {
    return this.selected ? this.themeColorPrimaryContainer : this.themeColorSurfaceTertiary;
  }

  /** 显示文字：toggle 把取值贴在标题左/右，select 把取值接在标题后。 */
  private labelText(): string {
    const name = this.displayName.length > 0 ? this.displayName : this.kind.title;
    if (this.kind.type === EXPLORE_KIND_TYPE_TOGGLE) {
      return this.valueOnLeft() ? `${this.currentValue}${name}` : `${name}${this.currentValue}`;
    }
    if (this.kind.type === EXPLORE_KIND_TYPE_SELECT) {
      return `${name} ${this.currentValue}`;
    }
    return name;
  }

  aboutToAppear(): void {
    this.currentValue = this.initialValue();
    this.textValue = this.initialValue();
    this.resolveDisplayName();
  }

  /** 上游 toggle/select 的初值：default ?: chars.first()。 */
  private initialValue(): string {
    if (this.kind.type !== EXPLORE_KIND_TYPE_TOGGLE && this.kind.type !== EXPLORE_KIND_TYPE_SELECT) {
      return '';
    }
    if (this.kind.default.length > 0) { return this.kind.default; }
    const chars = this.charsList();
    return chars.length > 0 ? chars[0] : '';
  }

  /** 上游 `ExploreKindItemState.ResolveDisplayName`：viewName 为空时直接用 title。 */
  private async resolveDisplayName(): Promise<void> {
    if (this.kind.viewName.trim().length === 0) { return; }
    const context = this.getUIContext().getHostContext();
    if (context === undefined) { return; }
    const map = await ExploreKindAction.infoMapOf(context, this.sourceUrl);
    const name = await ExploreKindAction.resolveDisplayName(this.sourceUrl, this.kind.viewName, map);
    if (name.length > 0) { this.displayName = name; }
  }

  /** 上游 `state.updateValue`：写 infoMap 并落盘。 */
  private async updateValue(value: string): Promise<void> {
    const context = this.getUIContext().getHostContext();
    if (context === undefined) { return; }
    await ExploreKindAction.putValue(context, this.sourceUrl, this.kind.title, value);
  }

  /** 上游 `state.executeAction`。 */
  private async executeAction(): Promise<void> {
    const action = this.kind.action.trim();
    if (action.length === 0) { return; }
    const context = this.getUIContext().getHostContext();
    if (context === undefined) { return; }
    const map = await ExploreKindAction.infoMapOf(context, this.sourceUrl);
    const outcome: ExploreKindActionOutcome =
      await ExploreKindAction.runAction(context, this.sourceUrl, action, map);
    if (outcome.refreshRequested) { this.onRefreshKinds(); }
    if (outcome.message.length > 0) { this.onMessage(outcome.message); }
  }

  /** 上游 toggle：点一次轮转到下一个 char，然后执行 action。 */
  private toggleNext(): void {
    const chars = this.charsList();
    const currentIndex = chars.indexOf(this.currentValue);
    const nextIndex = currentIndex < 0 ? 0 : (currentIndex + 1) % chars.length;
    this.currentValue = chars[nextIndex];
    this.updateValue(this.currentValue);
    this.executeAction();
  }

  /** 上游 select：选中不同项才写值并执行 action。 */
  private pickOption(option: string): void {
    this.selectVisible = false;
    if (option === this.currentValue) { return; }
    this.currentValue = option;
    this.updateValue(option);
    this.executeAction();
  }

  /** 上游 text：值变即写 infoMap，有 action 时 debounce 600ms 执行。 */
  private onTextChange(value: string): void {
    this.textValue = value;
    this.updateValue(value);
    if (this.kind.action.trim().length === 0) { return; }
    if (this.textActionTimer >= 0) {
      clearTimeout(this.textActionTimer);
      this.textActionTimer = -1;
    }
    this.textActionTimer = setTimeout(() => {
      this.textActionTimer = -1;
      this.executeAction();
    }, TEXT_ACTION_DEBOUNCE_MS);
  }

  /** 卡片点击的总入口，对齐上游 `ExploreKindMultiTypeItem` 的 when 分支顺序。 */
  private onCardClick(): void {
    const error = exploreKindErrorMsg(this.kind);
    if (error.length > 0) {
      this.errorDetail = error;
      this.errorVisible = true;
      return;
    }
    if (this.toggleOnClick) {
      this.onItemClick(this.kind);
      return;
    }
    if (this.submitOnClick) {
      this.onItemClick(this.kind);
      return;
    }
    if (this.kind.type === EXPLORE_KIND_TYPE_URL) {
      if (this.kind.url.trim().length > 0) {
        this.onOpenUrl(this.kind, this.kind.url.trim());
      }
      return;
    }
    if (this.kind.type === EXPLORE_KIND_TYPE_BUTTON) {
      this.executeAction();
      return;
    }
    if (this.kind.type === EXPLORE_KIND_TYPE_TOGGLE) {
      this.toggleNext();
      return;
    }
    if (this.kind.type === EXPLORE_KIND_TYPE_SELECT) {
      this.selectVisible = true;
    }
  }

  private optionItems(): UiMenuItem[] {
    const items: UiMenuItem[] = [];
    for (const option of this.charsList()) {
      items.push({ key: option, title: option, selected: option === this.currentValue });
    }
    return items;
  }

  /** 错误详情：标题「错误详情」，可拷贝全文（对齐上游 `AppAlertDialog` 那套）。 */
  private showErrorDetails(): void {
    this.errorVisible = false;
  }

  @Builder
  OptionMenu() {
    UiMenuPanel({
      items: this.optionItems(),
      panelWidth: 200,
      onSelect: (key: string) => { this.pickOption(key); }
    })
  }

  /** 尾部图标层：绝对贴在右端，与文字层叠。 */
  @Builder
  TrailingIcon() {
    Row() {
      AppGlyph({
        // 上游按 type 选图标；`trailingGlyph()` 只会返回三档已存在的图标名。
        name: this.trailingGlyph() as AppGlyphName,
        glyphSize: TRAILING_ICON_SIZE,
        tint: this.trailingTint()
      })
    }
    .width('100%')
    .padding({ right: TRAILING_ICON_END })
    .justifyContent(FlexAlign.End)
  }

  build() {
    Column() {
      if (this.kind.type === EXPLORE_KIND_TYPE_TEXT) {
        // 上游 `TextTypeItem`：输入框本体就是条目，不套卡片文字层。
        TextInput({ text: this.textValue, placeholder: this.kind.title })
          .fontSize(LABEL_MEDIUM_EMPHASIZED)
          .fontColor(this.contentColor())
          .placeholderColor(this.themeColorOutlineVariant)
          .backgroundColor(this.containerColor())
          .borderRadius(KIND_CORNER_RADIUS)
          .height(40)
          .padding({ left: SPACE_12, right: SPACE_12 })
          .onChange((value: string) => { this.onTextChange(value); })
      } else {
        Stack({ alignContent: Alignment.Center }) {
          Text(this.labelText())
            .fontSize(LABEL_MEDIUM_EMPHASIZED)
            .lineHeight(LABEL_MEDIUM_EMPHASIZED_LINE_HEIGHT)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.contentColor())
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .textAlign(TextAlign.Center)
            .width('100%')
            .padding({
              left: SPACE_12,
              right: this.trailingGlyph().length > 0 ? SPACE_12 + TRAILING_TEXT_INSET : SPACE_12
            })
          if (this.trailingGlyph().length > 0) {
            this.TrailingIcon();
          }
        }
        .width('100%')
        .constraintSize({ minHeight: 40 })
        .padding({ top: SPACE_8, bottom: SPACE_8 })
        .backgroundColor(this.containerColor())
        .borderRadius(KIND_CORNER_RADIUS)
        .accessibilityText(this.labelText())
        .onClick(() => { this.onCardClick(); })
      }
    }
    .width('100%')
    .bindPopup(this.selectVisible, {
      builder: () => { this.OptionMenu(); },
      placement: Placement.Bottom,
      enableArrow: false,
      autoCancel: true,
      onStateChange: (event: PopupStateChangeParam) => {
        if (!event.isVisible) { this.selectVisible = false; }
      }
    })
    .bindSheet(this.errorVisible, this.ErrorSheet(), {
      backgroundColor: this.themeColorSurfaceTertiary,
      height: SheetSize.FIT_CONTENT,
      dragBar: true,
      showClose: false,
      onDisappear: () => { this.errorVisible = false; }
    })
  }

  /** 错误详情底部弹层（本地没有带自定义内容的 AlertDialog，用 sheet 承载并给「拷贝内容」）。 */
  @Builder
  ErrorSheet() {
    Column() {
      Text('错误详情')
        .fontSize(LABEL_MEDIUM)
        .fontColor(this.themeColorTextPrimary)
        .margin({ bottom: SPACE_12 })
      Scroll() {
        Text(this.errorDetail)
          .fontSize(BODY_MEDIUM)
          .fontColor(this.themeColorTextPrimary)
          .width('100%')
      }
      .constraintSize({ maxHeight: 400 })
      .scrollable(ScrollDirection.Vertical)
      .scrollBar(BarState.Off)
      .align(Alignment.TopStart)
      .width('100%')
      Row() {
        Text('关闭')
          .fontSize(LABEL_MEDIUM)
          .fontColor(this.themeColorTextPrimary)
          .padding({ left: SPACE_16, right: SPACE_16, top: SPACE_8, bottom: SPACE_8 })
          .onClick(() => { this.showErrorDetails(); })
      }
      .width('100%')
      .justifyContent(FlexAlign.End)
      .margin({ top: SPACE_12 })
    }
    .width('100%')
    .padding(SPACE_16)
    .alignItems(HorizontalAlign.Start)
  }
}

/** 面板多选时的提交按钮文案与图标（上游 `MediumTonalButton(icon = Check)`）。 */
@Component
export struct ExploreKindSelectSheet {
  @StorageProp('themeColorTextPrimary') themeColorTextPrimary: string = '#1B1C22';
  @StorageProp('themeColorTextTertiary') themeColorTextTertiary: string = '#6A6D77';
  @StorageProp('themeColorAccent') themeColorAccent: string = '#3F5BD9';
  @StorageProp('themeColorSurfaceTertiary') themeColorSurfaceTertiary: string = '#F0F1F5';
  @StorageProp('themeColorOutlineVariant') themeColorOutlineVariant: string = '#C6C7D0';

  @Prop sourceUrl: string = '';
  /** 上游 `multiple`；探索页用单选（点分类即切换）。 */
  @Prop multiple: boolean = false;
  /** 上游 `initialSelectedTitles`。 */
  @Prop initialSelectedTitles: string[] = [];

  /** 选中一条或多条分类（单选时长度恒为 1）。 */
  onSelected: (kinds: ExploreKind[]) => void = () => {};
  onDismissRequest: () => void = () => {};

  @State private kinds: ExploreKind[] = [];
  @State private selectedTitles: string[] = [];
  @State private query: string = '';
  @State private revision: number = 0;

  aboutToAppear(): void {
    this.selectedTitles = this.initialSelectedTitles.slice();
    this.reloadKinds();
  }

  /** 上游 `repository.getSourceExploreKinds(sourceUrl)`。 */
  private reloadKinds(): void {
    if (this.sourceUrl.length === 0) {
      this.kinds = [];
      return;
    }
    this.kinds = ExploreKindParser.parseForSource(this.sourceUrl);
    this.revision++;
  }

  /** 脚本要求刷新分类：重解析一遍（上游 `refreshSourceExploreKinds` 先清缓存再取）。 */
  private refreshKinds(): void {
    this.reloadKinds();
  }

  /** 上游 `filteredKinds`：标题或 url 包含查询串（忽略大小写）。 */
  private filteredKinds(): ExploreKind[] {
    const query = this.query.trim().toLowerCase();
    if (query.length === 0) { return this.kinds; }
    return this.kinds.filter((kind: ExploreKind): boolean => {
      if (kind.title.toLowerCase().indexOf(query) >= 0) { return true; }
      return kind.url.toLowerCase().indexOf(query) >= 0;
    });
  }

  /** 上游 `kindRows = calculateExploreKindRows(filteredKinds, 6)`。 */
  private kindRows(): ExploreKindSpan[][] {
    return calculateExploreKindRows(this.filteredKinds(), KIND_MAX_SPAN);
  }

  private isSelected(kind: ExploreKind): boolean {
    return this.selectedTitles.indexOf(kind.title) >= 0;
  }

  /** 单选：点条目即提交并关闭（上游 `onSelected(listOf(kind)); onDismissRequest()`）。 */
  private onKindClick(kind: ExploreKind): void {
    if (!this.multiple) {
      this.onSelected([kind]);
      this.onDismissRequest();
      return;
    }
    const index = this.selectedTitles.indexOf(kind.title);
    if (index >= 0) {
      this.selectedTitles.splice(index, 1);
      this.selectedTitles = this.selectedTitles.slice();
    } else {
      this.selectedTitles = this.selectedTitles.concat([kind.title]);
    }
  }

  /** url 型分类被点：单选时带上解析出的 url 提交。 */
  private onKindOpenUrl(kind: ExploreKind, url: string): void {
    if (this.multiple) { return; }
    const picked = new ExploreKind();
    picked.title = kind.title;
    picked.url = url;
    picked.type = kind.type;
    picked.action = kind.action;
    picked.chars = kind.chars.slice();
    picked.hasChars = kind.hasChars;
    picked.default = kind.default;
    picked.viewName = kind.viewName;
    picked.style = kind.style;
    this.onSelected([picked]);
    this.onDismissRequest();
  }

  /** 多选模式右上角确认（上游 `endAction` 的 `MediumTonalButton(icon = Check)`）。 */
  private confirmMulti(): void {
    const picked = this.kinds.filter((kind: ExploreKind): boolean => this.isSelected(kind));
    this.onSelected(picked);
    this.onDismissRequest();
  }

  private toast(message: string): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message: message });
    } catch (_) {
      // toast 失败不影响分类面板本身。
    }
  }

  build() {
    Column() {
      // 搜索行：对齐上游 `SearchBar(placeholder = select_or_search_category, autoFocus = false)`。
      Row() {
        AppGlyph({ name: 'search', glyphSize: 20, tint: this.themeColorTextTertiary })
          .margin({ left: SPACE_12 });
        TextInput({ text: this.query, placeholder: '选择或搜索分类' })
          .fontSize(LABEL_MEDIUM)
          .fontColor(this.themeColorTextPrimary)
          .placeholderColor(this.themeColorTextTertiary)
          .backgroundColor(Color.Transparent)
          .layoutWeight(1)
          .padding({ left: SPACE_8 })
          .onChange((value: string) => { this.query = value; });
        if (this.multiple && this.selectedTitles.length > 0) {
          Row() {
            AppGlyph({ name: 'profileCheck', glyphSize: 20, tint: this.themeColorAccent })
          }
          .padding({ left: SPACE_12, right: SPACE_12 })
          .accessibilityText('确认')
          .onClick(() => { this.confirmMulti(); })
        }
      }
      .width('100%')
      .height(48)
      .backgroundColor(this.themeColorSurfaceTertiary)
      .borderRadius(24)
      .margin({ bottom: SPACE_12 })

      if (this.kindRows().length === 0) {
        Column() {
          Text('这个书源没有配置发现分类')
            .fontSize(LABEL_MEDIUM)
            .fontColor(this.themeColorTextTertiary)
        }
        .width('100%')
        .padding({ top: SPACE_16, bottom: SPACE_16 })
        .alignItems(HorizontalAlign.Center)
      } else {
        List() {
          ForEach(this.kindRows(), (row: ExploreKindSpan[], rowIndex: number) => {
            ListItem() {
              Row() {
                ForEach(row, (span: ExploreKindSpan, spanIndex: number) => {
                  Column() {
                    ExploreKindItem({
                      kind: span.kind,
                      sourceUrl: this.sourceUrl,
                      selected: this.isSelected(span.kind),
                      submitOnClick: !this.multiple,
                      toggleOnClick: this.multiple,
                      onOpenUrl: (kind: ExploreKind, url: string) => {
                        this.onKindOpenUrl(kind, url);
                      },
                      onItemClick: (kind: ExploreKind) => { this.onKindClick(kind); },
                      onRefreshKinds: () => { this.refreshKinds(); },
                      onMessage: (text: string) => { this.toast(text); }
                    })
                  }
                  .layoutWeight(span.span)
                  .margin({ left: spanIndex > 0 ? SPACE_8 : 0 })
                }, (span: ExploreKindSpan, spanIndex: number) => `${span.kind.title}:${spanIndex}`)
              }
              .width('100%')
              .padding({ top: SPACE_4, bottom: SPACE_4 })
            }
          }, (row: ExploreKindSpan[], rowIndex: number) => `row:${rowIndex}:${this.revision}`)
        }
        .width('100%')
        .layoutWeight(1)
        .scrollBar(BarState.Off)
        .padding({ bottom: SPACE_16 })
      }
    }
    .width('100%')
    .padding({ left: SPACE_16, right: SPACE_16, top: SPACE_16 })
  }
}
