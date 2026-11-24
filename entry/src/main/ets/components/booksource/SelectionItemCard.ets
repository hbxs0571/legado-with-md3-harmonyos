/**
 * 列表项卡片（可选中的那种）。
 *
 * 逐项对齐上游 `ui/widget/components/card/SelectionItemCard.kt`（371 行）的
 * `SelectionItemCard` + `SelectionItemCardContent` 两段：
 *   - 容器：`GlassCard(cornerRadius = 12.dp, containerColor = animatedContainerColor)`，
 *     其中 `animatedContainerColor` 在「选中」时取 `selectedContainerColor ?: secondaryContainer`，
 *     否则取 `containerColor ?: surfaceContainerLow`，动画 200ms `FastOutSlowInEasing`。
 *   - 左侧：`AnimatedVisibility(inSelectionMode || leadingContent != null)`，里面
 *     `AnimatedContent(inSelectionMode)`——选择模式下画复选框，否则画 `leadingContent`。
 *   - 主体：`ListItem`（非 miuix）或 `BasicComponent`（miuix）：标题 `titleSmall` 单行省略，
 *     副标题 `bodySmall` 单行省略（`supportingContent` 优先于 `subtitle`）。
 *   - 右侧：`Row(spacedBy 8.dp, padding end 8.dp)`，依次是开关、编辑按钮、`trailingAction`、更多菜单。
 *   - 语义：`inSelectionMode` 时 `semantics { selected = isSelected; role = Role.Button }`。
 *
 * 本仓没有 `GlassCard` / `ListItem` / `AppCheckbox` / `SmallPlainButton`，
 * 所以容器用 `Column + backgroundColor + borderRadius`、勾选框用 `Row + border` 自绘、
 * 右侧按钮用 `AppGlyph` 拼装；`supportingContent` / `trailingAction` / `leadingContent`
 * 用 `@BuilderParam` 保留上游的插槽语义。
 */
import { AppGlyph, AppGlyphName } from '../AppGlyph';
import { BODY_SMALL, TITLE_SMALL } from '../typography/TypographyTokens';

@Component
export struct SelectionItemCard {
  @StorageProp('themeColorSecondaryContainer') themeColorSecondaryContainer: string = '#DDE1F5';
  @StorageProp('themeColorSurfaceContainerLow') themeColorSurfaceContainerLow: string = '#F7F7FB';
  @StorageProp('themeColorOnSurface') themeColorOnSurface: string = '#1B1C22';
  @StorageProp('themeColorOnSurfaceVariant') themeColorOnSurfaceVariant: string = '#4A4C55';
  @StorageProp('themeColorAccent') themeColorAccent: string = '#3F5BD9';

  @Prop title: string = '';
  @Prop subtitle: string = '';
  /** 选中态。`inSelectionMode` 为真时它同时决定勾选框与容器色。 */
  @Prop isSelected: boolean = false;
  /** 选择模式：为真时左侧画勾选框（上游 `AnimatedContent(inSelectionMode)`）。 */
  @Prop inSelectionMode: boolean = false;
  /** 容器圆角，上游固定 12dp；留参数给调用方按需覆盖。 */
  @Prop cardCornerRadius: number = 12;
  /** 未选中时的底色；上游 `containerColor ?: surfaceContainerLow`。 */
  @Prop containerColor: string = '';
  /** 选中时的底色；上游 `selectedContainerColor ?: secondaryContainer`。 */
  @Prop selectedContainerColor: string = '';
  /** 无障碍描述（上游 `contentDescription`）。 */
  @Prop contentDescription: string = '';

  /** 点击整行（上游 `GlassCard(onClick = onToggleSelection)`）。 */
  onToggleSelection: () => void = () => {};

  /** 右侧插槽（上游 `trailingAction`）。 */
  @BuilderParam trailingAction: () => void = this.EmptySlot;
  /** 左侧非选择模式下的插槽（上游 `leadingContent`）。 */
  @BuilderParam leadingContent: () => void = this.EmptySlot;
  /** 副标题位置的插槽，优先于 `subtitle`（上游 `supportingContent`）。 */
  @BuilderParam supportingContent: () => void = this.EmptySlot;

  /** 是否传了插槽：`@BuilderParam` 无法判空，用显式开关代替。 */
  @Prop hasTrailingAction: boolean = false;
  @Prop hasLeadingContent: boolean = false;
  @Prop hasSupportingContent: boolean = false;

  @Builder
  EmptySlot() {
  }

  /** 上游 `animatedContainerColor`：选中 → selectedContainerColor ?: secondaryContainer。 */
  private cardColor(): string {
    if (this.isSelected) {
      return this.selectedContainerColor.length > 0 ? this.selectedContainerColor : this.themeColorSecondaryContainer;
    }
    return this.containerColor.length > 0 ? this.containerColor : this.themeColorSurfaceContainerLow;
  }

  build() {
    Row() {
      // 上游 `AnimatedVisibility(inSelectionMode || leadingContent != null)` + `Box(padding(start = 12.dp))`。
      if (this.inSelectionMode || this.hasLeadingContent) {
        Row() {
          if (this.inSelectionMode) {
            // 上游 `AppCheckbox(checked = isSelected, onCheckedChange = null)`。
            Stack({ alignContent: Alignment.Center }) {
              Column()
                .width(18)
                .height(18)
                .borderRadius(4)
                .backgroundColor(this.isSelected ? this.themeColorAccent : Color.Transparent)
                .border({ width: 1.5, color: this.isSelected ? this.themeColorAccent : this.themeColorOnSurfaceVariant })
              if (this.isSelected) {
                AppGlyph({ name: 'profileCheck', glyphSize: 12, tint: '#FFFFFF' })
              }
            }
            .width(18)
            .height(18)
          } else {
            this.leadingContent()
          }
        }
        .padding({ left: 12 })
      }

      // 上游 `ListItem`：标题 + 副标题（supportingContent 优先）。
      Column() {
        Text(this.title)
          .fontSize(TITLE_SMALL)
          .fontColor(this.themeColorOnSurface)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
          .textAlign(TextAlign.Start)
        if (this.hasSupportingContent) {
          this.supportingContent()
        } else if (this.subtitle.length > 0) {
          Text(this.subtitle)
            .fontSize(BODY_SMALL)
            .fontColor(this.themeColorOnSurfaceVariant)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')
            .textAlign(TextAlign.Start)
            .margin({ top: 2 })
        }
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      .padding({ left: 12, top: 10, bottom: 10 })

      // 上游右侧 `Row(spacedBy 8.dp, padding end 8.dp)`。
      Row({ space: 8 }) {
        if (this.hasTrailingAction) {
          this.trailingAction()
        }
      }
      .padding({ right: 8 })
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
    .backgroundColor(this.cardColor())
    .borderRadius(this.cardCornerRadius)
    // 上游 `animateColorAsState(..., tween(200))`：选中态切换时底色渐变。
    .animation({ duration: 200, curve: Curve.FastOutSlowIn })
    .onClick(() => { this.onToggleSelection(); })
    .accessibilityGroup(true)
    .accessibilityText(this.contentDescription.length > 0 ? this.contentDescription : this.title)
  }
}

/**
 * 行尾的小图标按钮。
 *
 * 上游 `SmallPlainButton(onClick, icon, contentDescription)`（`button/series/SmallPlainButton.kt`）：
 * 无底色的 32dp 方形点击区，图标 `labelLarge` 尺寸、`onSurfaceVariant` 着色。
 * 本仓没有这个组件，搜索页的历史项删除、分组项编辑等都用它，所以在同一文件里给出等价实现。
 */
@Component
export struct SmallPlainIconButton {
  @StorageProp('themeColorOnSurfaceVariant') themeColorOnSurfaceVariant: string = '#4A4C55';

  @Prop icon: AppGlyphName = 'profileClose';
  @Prop iconSize: number = 20;
  @Prop buttonSize: number = 32;
  @Prop label: string = '';

  onSelect: () => void = () => {};

  build() {
    Stack({ alignContent: Alignment.Center }) {
      AppGlyph({ name: this.icon, glyphSize: this.iconSize, tint: this.themeColorOnSurfaceVariant })
    }
    .width(this.buttonSize)
    .height(this.buttonSize)
    .borderRadius(this.buttonSize / 2)
    .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.9 })
    .accessibilityText(this.label)
    .onClick(() => { this.onSelect(); })
  }
}
