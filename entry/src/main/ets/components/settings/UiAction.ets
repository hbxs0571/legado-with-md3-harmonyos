import { ThemeItemDivider } from '../ThemeItemDivider';
import {
  FONT_ROW_DETAIL, FONT_ROW_TITLE, ROW_PADDING_H, ROW_PADDING_V, SPACE_2
} from '../UiTokens';

/** 设置行：点一下跳转或弹面板。右侧是右箭头。 */
@Component
export struct UiAction {
  @StorageProp('themeColorTextPrimary') themeColorTextPrimary: string = '#1B1C22';
  @StorageProp('themeColorTextTertiary') themeColorTextTertiary: string = '#6A6D77';

  @Prop title: string = '';
  @Prop detail: string = '';
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
          .width('100%')
        if (this.detail.length > 0) {
          Text(this.detail)
            .fontSize(FONT_ROW_DETAIL)
            .fontColor(this.themeColorTextTertiary)
            .width('100%')
            .margin({ top: SPACE_2 })
        }
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      // AppGlyph 的 74 个名字里没有右箭头，7 个设置页现在全都直接用 reader_next，
      // 这里照旧用 Image，并按 docs/UI-RESTORE.md 的要求显式给 fillColor。
      Image($r('app.media.reader_next'))
        .width(this.chevronSize)
        .height(this.chevronSize)
        .fillColor(this.themeColorTextTertiary)
    }
    .width('100%')
    .padding({ left: ROW_PADDING_H, right: ROW_PADDING_H, top: ROW_PADDING_V, bottom: ROW_PADDING_V })
    .onClick(() => this.onSelect())
      if (this.showDivider) {
        ThemeItemDivider()
      }
    }.width('100%')
  }
}
