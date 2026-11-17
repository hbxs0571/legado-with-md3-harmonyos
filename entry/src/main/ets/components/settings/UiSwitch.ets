import { ThemeItemDivider } from '../ThemeItemDivider';
import {
  FONT_ROW_DETAIL, FONT_ROW_TITLE, ROW_PADDING_H, ROW_PADDING_V, SPACE_2
} from '../UiTokens';
import { UiSwitchControl } from '../UiSwitchControl';

/**
 * 设置行：标题 +（可选）说明 + 右侧开关。
 *
 * 受控模式：值只从 value 来，改动只走 onChange。父级必须回写 value，否则开关会弹回原状。
 * 不存值副本，是为了修掉改造前的一个缺陷：CacheSettingsSwitch /
 * PrivacySettingsSwitch 用 @Prop + @State + aboutToAppear 同步，而 aboutToAppear
 * 只跑一次，父级之后改值开关不会跟着动。
 *
 * 右侧开关是自绘的 UiSwitchControl（对齐上游 AdaptiveSwitch）：选中时滑块里有一颗勾，
 * 未选中空白。**整行可点**，对齐上游 SwitchSettingItem 的 onClick —— 原来的 Toggle
 * 只有开关本体能点，点标题没反应。
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
  @Prop showDivider: boolean = true;

  onChange: (enabled: boolean) => void = (_enabled: boolean) => {};

  private applyValue(next: boolean): void {
    if (this.disabled) {
      return;
    }
    this.onChange(next);
  }

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

        // interactive: false —— 点击由整行负责，控件内部再挂一次会让点开关切成两次
        UiSwitchControl({
          checked: this.value,
          switchEnabled: !this.disabled,
          interactive: false,
          onChange: (checked: boolean) => {
            this.applyValue(checked);
          }
        })
      }
      .width('100%')
      .padding({ left: ROW_PADDING_H, right: ROW_PADDING_H, top: ROW_PADDING_V, bottom: ROW_PADDING_V })
      .onClick(() => {
        this.applyValue(!this.value);
      })
      .opacity(this.disabled ? 0.38 : 1)
      if (this.showDivider) {
        ThemeItemDivider()
      }
    }.width('100%')
  }
}
