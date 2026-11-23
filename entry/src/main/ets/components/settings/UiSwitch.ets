import { BODY_SMALL_EMPHASIZED, TITLE_MEDIUM } from '../typography/TypographyTokens';

import { ThemeItemDivider } from '../ThemeItemDivider';
import { ROW_PADDING_H, ROW_PADDING_V, SPACE_2 } from '../UiTokens';
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
  @StorageProp('themeColorSurfaceTertiary') themeColorSurfaceTertiary: string = '#F0F1F5';

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

  /**
   * 按压时的整行底色：照 UiAction 用强调色 15% alpha，避免满宽行缩放挤内容。
   * disabled 时这类行不该有反馈，返回全透明；主题色异常退回 surfaceContainer。
   */
  private pressedBackground(): string {
    if (this.disabled) {
      return '#00000000';
    }
    const accent = this.themeColorAccent;
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
            .width('100%')
          if (this.detail.length > 0) {
            Text(this.detail)
              .fontSize(BODY_SMALL_EMPHASIZED).fontWeight(FontWeight.Medium)
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
      .stateStyles({
        pressed: { .backgroundColor(this.pressedBackground()) },
        normal: { .backgroundColor(Color.Transparent) }
      })
      .onClick(() => {
        this.applyValue(!this.value);
      })
      .opacity(this.disabled ? 0.38 : 1)
      // 整行合并成一个无障碍节点：上游 `ui/widget/components/settingItem/SettingItem.kt:84`
      // 与 `TinySettingItems.kt:132` 都在整行挂 `.semantics(mergeDescendants = true)`，
      // 读屏会把标题、说明、开关状态读成一句，而不是分成三个可聚焦节点。
      .accessibilityGroup(true)
      if (this.showDivider) {
        ThemeItemDivider()
      }
    }.width('100%')
  }
}
