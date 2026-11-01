import { DIVIDER_COLOR_FALLBACK } from '../data/ThemeCardStyle';

/**
 * 设置条目之间的分隔线。
 *
 * 对齐上游 `ui/widget/components/divider/SettingItemDivider.kt:16-45`：
 * 关闭时整条不渲染（这里由 `themeDividerWidth <= 0` 表示）；宽度取 `itemDividerWidth`、
 * 长度取 `itemDividerLength`（百分比，水平居中）；颜色未设置时回落到
 * `Color.Gray.copy(alpha = 0.3f)`，两端用圆角修圆。
 *
 * 三个取值都由 `pages/Index.ets` 的 `publishThemeCardStyle()` 写进 AppStorage，
 * 所以任意页面里的分隔线都跟着同一份状态走。
 */
@Component
export struct ThemeItemDivider {
  @StorageProp('themeDividerWidth') themeDividerWidth: number = 0;
  @StorageProp('themeDividerLength') themeDividerLength: number = 80;
  @StorageProp('themeDividerColor') themeDividerColor: string = '';

  build() {
    if (this.themeDividerWidth > 0) {
      Row() {
        Row()
          .width(`${this.themeDividerLength}%`)
          .height(this.themeDividerWidth)
          .backgroundColor(this.themeDividerColor.length > 0 ? this.themeDividerColor : DIVIDER_COLOR_FALLBACK)
          .borderRadius(this.themeDividerWidth / 2)
      }.width('100%').justifyContent(FlexAlign.Center)
    }
  }
}
