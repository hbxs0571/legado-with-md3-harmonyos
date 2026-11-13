import curves from '@ohos.curves';
import { AppGlyph } from '../AppGlyph';
import {
  EXPAND_BUTTONS_BOTTOM, EXPAND_BUTTONS_TOP, EXPAND_PADDING_BOTTOM, FONT_INPUT,
  FONT_ROW_DETAIL, FONT_ROW_OPTION, FONT_ROW_TITLE, RADIUS_INNER, ROW_PADDING_H, ROW_PADDING_V, SPACE_2
} from '../UiTokens';

/**
 * 设置行：点一下行内展开输入框 + 「默认 / 确定」。
 *
 * 行为照上游 InputSettingItem.kt：
 * - 展开时把当前值灌进输入框；
 * - 「默认」把 defaultValue 填进输入框（不收起、不回调）；
 * - 「确定」回调 onConfirm(text) 后收起。
 */
@Component
export struct UiInput {
  @StorageProp('themeColorTextPrimary') themeColorTextPrimary: string = '#1B1C22';
  @StorageProp('themeColorTextSecondary') themeColorTextSecondary: string = '#2E3038';
  @StorageProp('themeColorTextTertiary') themeColorTextTertiary: string = '#6A6D77';
  @StorageProp('themeColorAccent') themeColorAccent: string = '#3F5BD9';
  @StorageProp('themeColorSurfaceTertiary') themeColorSurfaceTertiary: string = '#F0F1F5';

  @Prop title: string = '';
  @Prop detail: string = '';
  @Prop value: string = '';
  /** 「默认」按钮填回的值（上游同名参数 defaultValue: String? = ""）。 */
  @Prop defaultValue: string = '';

  onConfirm: (text: string) => void = (_text: string) => {};

  @State expanded: boolean = false;
  @State editValue: string = '';

  build() {
    Column() {
      Row() {
        Column() {
          Text(this.title).fontSize(FONT_ROW_TITLE).fontColor(this.themeColorTextPrimary).width('100%')
          if (this.detail.length > 0) {
            Text(this.detail)
              .fontSize(FONT_ROW_DETAIL)
              .fontColor(this.themeColorTextTertiary)
              .width('100%')
              .margin({ top: SPACE_2 })
          }
          // 展开时收起这个只读值，避免与输入框里的内容重复显示。
          if (!this.expanded) {
            Text(this.value)
              .fontSize(FONT_ROW_OPTION)
              .fontColor(this.themeColorAccent)
              .width('100%')
              .margin({ top: SPACE_2 });
          }
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        AppGlyph({ name: 'profileExpandMore', glyphSize: 22, tint: this.themeColorTextTertiary })
          .rotate({ angle: this.expanded ? 180 : 0 })
          .animation({ curve: curves.springMotion(0.35, 0.9) });
      }
      .width('100%')
      .padding({ left: ROW_PADDING_H, right: ROW_PADDING_H, top: ROW_PADDING_V, bottom: ROW_PADDING_V })
      .onClick(() => {
        // 展开瞬间把当前值灌进去，否则会看到上一次编辑残留（上游 LaunchedEffect 同口径）。
        this.editValue = this.value;
        // 进入动画作用域后再改状态，否则 if 分支的增删是瞬时的（弹簧不吃 duration）。
        this.getUIContext().animateTo({ curve: curves.springMotion(0.35, 0.9) }, () => {
          this.expanded = !this.expanded;
        });
      })

      if (this.expanded) {
        Column() {
          TextInput({ text: this.editValue, placeholder: this.title })
            .fontSize(FONT_INPUT)
            .fontColor(this.themeColorTextPrimary)
            .backgroundColor(this.themeColorSurfaceTertiary)
            .borderRadius(RADIUS_INNER)
            .width('100%')
            .onChange((text: string) => {
              this.editValue = text;
            });

          Row() {
            // 「默认」= 填回默认值，不收起、不回调（上游 ConfirmDismissButtonsRow 的 onDismiss）。
            Text('默认')
              .fontSize(FONT_INPUT)
              .fontColor(this.themeColorTextSecondary)
              .onClick(() => {
                this.editValue = this.defaultValue;
              });
            Blank()
            Text('确定')
              .fontSize(FONT_INPUT)
              .fontColor(this.themeColorAccent)
              .onClick(() => {
                this.onConfirm(this.editValue);
                this.expanded = false;
              });
          }
          .width('100%')
          .padding({ top: EXPAND_BUTTONS_TOP, bottom: EXPAND_BUTTONS_BOTTOM });
        }
        .width('100%')
        .padding({ left: ROW_PADDING_H, right: ROW_PADDING_H, bottom: EXPAND_PADDING_BOTTOM })
        .transition(TransitionEffect.asymmetric(
          TransitionEffect.OPACITY.combine(TransitionEffect.translate({ y: -8 })),
          TransitionEffect.OPACITY
        ));
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }
}
