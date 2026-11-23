import { ThemeItemDivider } from '../ThemeItemDivider';
import { ROW_PADDING_H, ROW_PADDING_V, SPACE_2 } from '../UiTokens';
import { BODY_SMALL_EMPHASIZED, LABEL_MEDIUM_EMPHASIZED, TITLE_MEDIUM } from '../typography/TypographyTokens';
/**
 * 设置行：点一下跳转或弹面板。
 *
 * 对齐上游 ui/widget/components/settingItem/ClickableSettingItem.kt：
 * - 文字列自上而下是 title → description → option（上游 supportingContent 那个
 *   Column 里 description 在上、option 在下，option 用强调色）；
 * - 右侧默认是右箭头；传了 swatchColor 就改画一个圆形色块（上游 trailingContent
 *   槽在传值时同样会顶掉 ChevronRight，见 ClickableSettingItem.kt:44-50）。
 *
 * 与上游的一处收窄：上游 trailingContent 是任意 @Composable，本地只有「圆形色块」
 * 这一种用法（封面文字色 / 阴影色），所以收成一个颜色入参，没有做成 @BuilderParam。
 */
@Component
export struct UiAction {
  @StorageProp('themeColorTextPrimary') themeColorTextPrimary: string = '#1B1C22';
  @StorageProp('themeColorTextTertiary') themeColorTextTertiary: string = '#6A6D77';
  @StorageProp('themeColorAccent') themeColorAccent: string = '#3F5BD9';
  // 按压底色兜底色：强调色取不出 alpha 时（理论上不会）退回 surfaceContainer。
  @StorageProp('themeColorSurfaceTertiary') themeColorSurfaceTertiary: string = '#F0F1F5';

  @Prop title: string = '';
  @Prop detail: string = '';
  /** 上游 option：渲染在标题与描述下方的强调色小字，例如色值 #RRGGBB。 */
  @Prop option: string = '';
  /** 非空时右侧改画这个颜色的圆形色块，不再画右箭头（上游 trailingContent 语义）。 */
  @Prop swatchColor: string = '';
  /** 色块置灰。上游没有这个参数，本地用它表达「这一项当前不生效」。 */
  @Prop swatchDisabled: boolean = false;
  /** 右箭头尺寸。各页现在混用 15/16/18，默认取 15（最常见）。 */
  @Prop chevronSize: number = 15;
  @Prop showDivider: boolean = true;
  /** >0 时描述文字单行截断（书籍保存位置显示目录 URI 用）；默认不限行。 */
  @Prop detailMaxLines: number = 0;

  onSelect: () => void = () => {};

  /**
   * 按压时的整行底色。
   *
   * 对齐上游 ClickableSettingItem 的 indication（Compose 默认水波纹 = onSurface 低透明度叠加）。
   * 不用 surfaceContainer 做按压色：设置页底色是 surfaceContainerLow，深色主题下两者只差
   * 1 个色阶（#1A1B21 vs #1B1C22），实测按下前后像素只差 (26,27,32)→(27,28,33)，肉眼看不出来。
   * 这里改用强调色的 15% alpha 叠在行底色上，任何主题下都有可见的染色。
   */
  private pressedBackground(): string {
    const accent = this.themeColorAccent;
    // 主题色是 #RRGGBB，前面补两位 alpha 变成 #AARRGGBB（ArkUI 八位色值口径）。
    if (accent.length === 7 && accent.charAt(0) === '#') {
      return '#26' + accent.substring(1);
    }
    return this.themeColorSurfaceTertiary;
  }

  build() {
    Column() {
      Row() {
        Column() {
          Text(this.title)
            .fontSize(TITLE_MEDIUM)
            .fontColor(this.themeColorTextPrimary)
            .width('100%');
          if (this.detail.length > 0) {
            Text(this.detail)
              .fontSize(BODY_SMALL_EMPHASIZED).fontWeight(FontWeight.Medium)
              .fontColor(this.themeColorTextTertiary)
              .width('100%')
              .margin({ top: SPACE_2 })
              .maxLines(this.detailMaxLines > 0 ? this.detailMaxLines : 1000)
              .textOverflow({ overflow: TextOverflow.Ellipsis });
          }
          // 上游 option 在 supportingContent 列里位于 description 之下。
          if (this.option.length > 0) {
            Text(this.option)
              .fontSize(LABEL_MEDIUM_EMPHASIZED).fontWeight(FontWeight.Medium)
              .fontColor(this.themeColorAccent)
              .width('100%')
              .margin({ top: SPACE_2 });
          }
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start);

        if (this.swatchColor.length > 0) {
          // 上游是 Box(size = 28.dp).clip(CircleShape).border(1.dp, outlineVariant, CircleShape)。
          Stack()
            .width(28)
            .height(28)
            .backgroundColor(this.swatchColor)
            .borderRadius(14)
            .border({ width: 1, color: this.themeColorTextTertiary })
            .opacity(this.swatchDisabled ? 0.4 : 1);
        } else {
          // AppGlyph 的 74 个名字里没有右箭头，7 个设置页现在全都直接用 reader_next，
          // 这里照旧用 Image，并按 docs/UI-RESTORE.md 的要求显式给 fillColor。
          Image($r('app.media.reader_next'))
            .width(this.chevronSize)
            .height(this.chevronSize)
            .fillColor(this.themeColorTextTertiary);
        }
      }
      .width('100%')
      .padding({ left: ROW_PADDING_H, right: ROW_PADDING_H, top: ROW_PADDING_V, bottom: ROW_PADDING_V })
      .stateStyles({
        pressed: { .backgroundColor(this.pressedBackground()) },
        normal: { .backgroundColor(Color.Transparent) }
      })
      .onClick(() => this.onSelect())
      // 整行合并成一个无障碍节点：上游 `SettingItem.kt:84` 与 `TinySettingItems.kt:132`
      // 都在整行挂 `.semantics(mergeDescendants = true)`，标题与右侧箭头读成一句。
      .accessibilityGroup(true);

      if (this.showDivider) {
        ThemeItemDivider();
      }
    }.width('100%');
  }
}
