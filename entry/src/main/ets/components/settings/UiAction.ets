import { ThemeItemDivider } from '../ThemeItemDivider';
import {
  FONT_ROW_DETAIL, FONT_ROW_OPTION, FONT_ROW_TITLE, ROW_PADDING_H, ROW_PADDING_V, SPACE_2
} from '../UiTokens';

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

  onSelect: () => void = () => {};

  build() {
    Column() {
      Row() {
        Column() {
          Text(this.title)
            .fontSize(FONT_ROW_TITLE)
            .fontColor(this.themeColorTextPrimary)
            .width('100%');
          if (this.detail.length > 0) {
            Text(this.detail)
              .fontSize(FONT_ROW_DETAIL)
              .fontColor(this.themeColorTextTertiary)
              .width('100%')
              .margin({ top: SPACE_2 });
          }
          // 上游 option 在 supportingContent 列里位于 description 之下。
          if (this.option.length > 0) {
            Text(this.option)
              .fontSize(FONT_ROW_OPTION)
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
      .onClick(() => this.onSelect());

      if (this.showDivider) {
        ThemeItemDivider();
      }
    }.width('100%');
  }
}
