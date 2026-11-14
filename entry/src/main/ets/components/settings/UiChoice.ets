import { ThemeItemDivider } from '../ThemeItemDivider';
import {
  FONT_ROW_DETAIL, FONT_ROW_OPTION, FONT_ROW_TITLE, ROW_PADDING_H, ROW_PADDING_V, SPACE_2, SPACE_4
} from '../UiTokens';

/**
 * 设置行：点一下在若干选项间循环切换（上游 DropdownListSettingItem 的简化形态）。
 *
 * 值与回调都在父级：本组件只报「切到了第几个」，不自己存 selectedIndex。
 */
@Component
export struct UiChoice {
  @StorageProp('themeColorTextPrimary') themeColorTextPrimary: string = '#1B1C22';
  @StorageProp('themeColorTextTertiary') themeColorTextTertiary: string = '#6A6D77';
  @StorageProp('themeColorAccent') themeColorAccent: string = '#3F5BD9';

  @Prop title: string = '';
  @Prop detail: string = '';
  @Prop options: string[] = [];
  @Prop selectedIndex: number = 0;
  @Prop showDivider: boolean = true;

  onSelect: (index: number) => void = (_index: number) => {};

  build() {
    Column() {
    Column() {
      Row() {
        Text(this.title)
          .fontSize(FONT_ROW_TITLE)
          .fontColor(this.themeColorTextPrimary)
          .layoutWeight(1)
        if (this.options.length > 0) {
          Text(this.options[Math.min(this.selectedIndex, this.options.length - 1)])
            .fontSize(FONT_ROW_OPTION)
            .fontColor(this.themeColorAccent)
        }
      }
      .width('100%')

      if (this.detail.length > 0) {
        Text(this.detail)
          .fontSize(FONT_ROW_DETAIL)
          .fontColor(this.themeColorTextTertiary)
          .width('100%')
          .margin({ top: SPACE_2 })
      }
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
    .padding({ left: ROW_PADDING_H, right: ROW_PADDING_H, top: ROW_PADDING_V, bottom: ROW_PADDING_V })
    .onClick(() => {
      if (this.options.length === 0) {
        return;
      }
      this.onSelect((this.selectedIndex + 1) % this.options.length);
    })
      if (this.showDivider) {
        ThemeItemDivider()
      }
    }.width('100%')
  }
}
