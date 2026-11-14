import { ThemeItemDivider } from '../ThemeItemDivider';
import {
  FONT_ROW_DETAIL, FONT_ROW_TITLE, ROW_PADDING_H, ROW_PADDING_V, SPACE_2
} from '../UiTokens';

/**
 * 设置行：标题 +（可选）说明 + 右侧开关。
 *
 * 两种模式：
 * - 默认（受控）：值只从 value 来，改动只走 onChange。父级必须回写 value，否则开关会弹回原状。
 * - preview: true（预览）：组件自己存一份 @State，拨动有效但不回调、不落盘。
 *   这是给「界面已有、后端没接」的那些开关用的，保持改造前的可见行为。
 *
 * 受控模式下不存值副本，是为了修掉改造前的一个缺陷：CacheSettingsSwitch /
 * PrivacySettingsSwitch 用 @Prop + @State + aboutToAppear 同步，而 aboutToAppear
 * 只跑一次，父级之后改值开关不会跟着动。
 */
@Component
export struct UiSwitch {
  @StorageProp('themeColorTextPrimary') themeColorTextPrimary: string = '#1B1C22';
  @StorageProp('themeColorTextTertiary') themeColorTextTertiary: string = '#6A6D77';
  @StorageProp('themeColorAccent') themeColorAccent: string = '#3F5BD9';

  @Prop title: string = '';
  @Prop detail: string = '';
  @Prop value: boolean = false;
  @Prop disabled: boolean = false;
  /** true = 预览模式：自己存值、不回调。给尚未接后端的开关用。 */
  @Prop preview: boolean = false;
  @Prop showDivider: boolean = true;

  onChange: (enabled: boolean) => void = (_enabled: boolean) => {};

  @State private previewValue: boolean = false;

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

      Toggle({ type: ToggleType.Switch, isOn: this.preview ? this.previewValue : this.value })
        .selectedColor(this.themeColorAccent)
        .enabled(!this.disabled)
        .opacity(this.disabled ? 0.4 : 1)
        .onChange((isOn: boolean) => {
          if (this.preview) {
            this.previewValue = isOn;
            return;
          }
          this.onChange(isOn);
        })
    }
    .width('100%')
    .padding({ left: ROW_PADDING_H, right: ROW_PADDING_H, top: ROW_PADDING_V, bottom: ROW_PADDING_V })
      if (this.showDivider) {
        ThemeItemDivider()
      }
    }.width('100%')
  }
}
