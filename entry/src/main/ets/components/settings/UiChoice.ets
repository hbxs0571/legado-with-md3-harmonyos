import { BODY_SMALL_EMPHASIZED, LABEL_MEDIUM_EMPHASIZED, TITLE_MEDIUM } from '../typography/TypographyTokens';

import { ThemeItemDivider } from '../ThemeItemDivider';
import { ROW_PADDING_H, ROW_PADDING_V, SPACE_2, SPACE_4 } from '../UiTokens';

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
  @StorageProp('themeColorSurfaceTertiary') themeColorSurfaceTertiary: string = '#F0F1F5';

  @Prop title: string = '';
  @Prop detail: string = '';
  @Prop options: string[] = [];
  @Prop selectedIndex: number = 0;
  @Prop showDivider: boolean = true;

  onSelect: (index: number) => void = (_index: number) => {};

  /**
   * 按压时的整行底色：照 UiAction 用强调色 15% alpha，避免满宽行缩放挤内容。
   * 主题色不是 #RRGGBB 时退回 surfaceContainer。
   */
  private pressedBackground(): string {
    const accent = this.themeColorAccent;
    if (accent.length === 7 && accent.charAt(0) === '#') {
      return '#26' + accent.substring(1);
    }
    return this.themeColorSurfaceTertiary;
  }

  build() {
    Column() {
    Column() {
      Row() {
        Text(this.title)
          .fontSize(TITLE_MEDIUM)
          .fontColor(this.themeColorTextPrimary)
          .layoutWeight(1)
        if (this.options.length > 0) {
          Text(this.options[Math.min(this.selectedIndex, this.options.length - 1)])
            .fontSize(LABEL_MEDIUM_EMPHASIZED).fontWeight(FontWeight.Medium)
            .fontColor(this.themeColorAccent)
        }
      }
      .width('100%')

      if (this.detail.length > 0) {
        Text(this.detail)
          .fontSize(BODY_SMALL_EMPHASIZED).fontWeight(FontWeight.Medium)
          .fontColor(this.themeColorTextTertiary)
          .width('100%')
          .margin({ top: SPACE_2 })
      }
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
    .padding({ left: ROW_PADDING_H, right: ROW_PADDING_H, top: ROW_PADDING_V, bottom: ROW_PADDING_V })
    .stateStyles({
      pressed: { .backgroundColor(this.pressedBackground()) },
      normal: { .backgroundColor(Color.Transparent) }
    })

    .onClick(() => {
      if (this.options.length === 0) {
        return;
      }
      this.onSelect((this.selectedIndex + 1) % this.options.length);
    })
    // 整行合并成一个无障碍节点：上游 `SettingItem.kt:84` 的 `.semantics(mergeDescendants = true)`，
    // 标题与当前取值读成一句。
    .accessibilityGroup(true)
      if (this.showDivider) {
        ThemeItemDivider()
      }
    }.width('100%')
  }
}
