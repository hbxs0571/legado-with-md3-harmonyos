import {
  FONT_ROW_DETAIL, FONT_ROW_OPTION, FONT_ROW_TITLE, ROW_PADDING_H, ROW_PADDING_V, SPACE_2
} from '../UiTokens';

/** 设置行：标题 +（可选）数值 + 滑块 +（可选）说明。 */
@Component
export struct UiSlider {
  @StorageProp('themeColorTextPrimary') themeColorTextPrimary: string = '#1B1C22';
  @StorageProp('themeColorTextTertiary') themeColorTextTertiary: string = '#6A6D77';
  @StorageProp('themeColorAccent') themeColorAccent: string = '#3F5BD9';
  @StorageProp('themeColorSurfaceTertiary') themeColorSurfaceTertiary: string = '#F0F1F5';

  @Prop title: string = '';
  @Prop detail: string = '';
  @Prop value: number = 0;
  @Prop minValue: number = 0;
  @Prop maxValue: number = 100;
  @Prop stepValue: number = 1;

  onChange: (value: number) => void = (_value: number) => {};

  build() {
    Column() {
      Row() {
        Text(this.title).fontSize(FONT_ROW_TITLE).fontColor(this.themeColorTextPrimary)
        Blank()
        // 有说明时数值只出现在说明里，避免同一个数字显示两次（照 ThemeSettingsSlider 的做法）
        if (this.detail.length === 0) {
          Text('' + this.value).fontSize(FONT_ROW_OPTION).fontColor(this.themeColorAccent)
        }
      }
      .width('100%')

      Slider({
        value: this.value,
        min: this.minValue,
        max: this.maxValue,
        step: this.stepValue,
        style: SliderStyle.OutSet
      })
        .width('100%')
        .selectedColor(this.themeColorAccent)
        .trackColor(this.themeColorSurfaceTertiary)
        .onChange((value: number, mode: SliderChangeMode) => {
          // 只在这三个时机上报，拖动中的每一帧不回调，避免父级频繁落盘。
          if (mode === SliderChangeMode.Moving || mode === SliderChangeMode.Click ||
            mode === SliderChangeMode.End) {
            const clamped = Math.max(this.minValue, Math.min(this.maxValue, Math.round(value)));
            this.onChange(clamped);
          }
        })

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
  }
}
