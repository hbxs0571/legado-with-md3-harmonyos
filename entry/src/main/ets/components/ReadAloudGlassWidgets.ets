
/**
 * 朗读面板共享的「磨砂玻璃」视觉组件。
 *
 * 视觉依据（上游源码）：
 *   - GlassCard.kt:155      containerOpacity alpha + appContainerBackground(Item)；
 *   - AppContainerBackground.kt:60-63  卡片底色 alpha = glassCardBackgroundOpacity/100；
 *   - ValueStepper.kt:20-73 SmallOutlinedButton(−) + TextCard(值) + SmallOutlinedButton(+)；
 *   - TinySettingItems.kt:287-373 TinySliderSettingItem 常态显示 ValueStepper，
 *     点卡片才用 AnimatedVisibility 展开 AppSlider。
 *
 * 鸿蒙没有 Compose 的 nine-patch 容器背景图，这里用「带 alpha 的主题色 + backdropBlur」近似
 * 上游半透明磨砂玻璃；主题色槽位跟随日夜主题，与上游 containerColor 取色一致。
 */

/**
 * 把 6 位 #RRGGBB 主题色转成带 alpha 的 8 位 #AARRGGBB。
 * alpha 对齐上游 GlassCard 的 `containerColor.alpha * alpha`（containerOpacity/100）。
 */
export function glassColor(color: string, alpha: number): string {
  const a: number = Math.round(Math.max(0, Math.min(1, alpha)) * 255);
  let hex: string = a.toString(16);
  if (hex.length < 2) { hex = '0' + hex; }
  hex = hex.toUpperCase();
  if (color.length === 7 && color.charAt(0) === '#') {
    return '#' + hex + color.substring(1);
  }
  return color;
}

/**
 * ValueStepper（上游 ValueStepper.kt）：减号描边钮 + 值 TextCard + 加号描边钮。
 * 加减号各自消费点击，不触发展开（父级把展开绑在标题区而非整卡片）。
 * 注： ArkTS 的 @Component 基类占用 enabled 属性名，这里用 stepperEnabled 代替。
 */
@Component
export struct AloudStepper {
  @StorageProp('themeColorSurfaceElevated') themeColorSurfaceElevated: string = '#FFFFFF';
  @StorageProp('themeColorTextPrimary') themeColorTextPrimary: string = '#1B1C22';
  @StorageProp('themeColorTextTertiary') themeColorTextTertiary: string = '#6A6D77';
  @Prop valueText: string = '';
  @Prop stepperEnabled: boolean = true;
  onDec: () => void = () => {};
  onInc: () => void = () => {};

  build() {
    Row({ space: 6 }) {
      Text('−')
        .fontSize(18).fontWeight(FontWeight.Medium)
        .fontColor(this.stepperEnabled ? this.themeColorTextPrimary : this.themeColorTextTertiary)
        .width(30).height(30).textAlign(TextAlign.Center)
        .backgroundColor(glassColor(this.themeColorSurfaceElevated, 0.9))
        .borderRadius(15)
        .onClick(() => this.onDec())
      Text(this.valueText)
        .fontSize(13).fontColor(this.stepperEnabled ? this.themeColorTextPrimary : this.themeColorTextTertiary)
        .padding({ left: 10, right: 10, top: 5, bottom: 5 })
        .backgroundColor(glassColor(this.themeColorSurfaceElevated, 0.9))
        .borderRadius(8)
      Text('+')
        .fontSize(18).fontWeight(FontWeight.Medium)
        .fontColor(this.stepperEnabled ? this.themeColorTextPrimary : this.themeColorTextTertiary)
        .width(30).height(30).textAlign(TextAlign.Center)
        .backgroundColor(glassColor(this.themeColorSurfaceElevated, 0.9))
        .borderRadius(15)
        .onClick(() => this.onInc())
    }
    .enabled(this.stepperEnabled)
  }
}

/**
 * TinySliderSettingItem（上游 :287-373）：常态显示 `− 值 +`，点标题区展开滑杆。
 * 卡片本身是半透明磨砂玻璃，能透出后面的正文；禁用态整体半透明（上游 alpha 0.5）。
 * 注： ArkTS 的 @Component 基类占用 enabled 属性名，这里用 settingEnabled 代替。
 */
@Component
export struct AloudSliderSetting {
  @StorageProp('themeColorSurfaceSecondary') themeColorSurfaceSecondary: string = '#FFFFFF';
  @StorageProp('themeColorTextPrimary') themeColorTextPrimary: string = '#1B1C22';
  @StorageProp('themeColorTextSecondary') themeColorTextSecondary: string = '#494C59';
  @StorageProp('themeColorTextTertiary') themeColorTextTertiary: string = '#6A6D77';
  @StorageProp('themeColorAccent') themeColorAccent: string = '#3F5BD9';
  @Prop label: string = '';
  @Prop description: string = '';
  @Prop valueText: string = '';
  @Prop value: number = 0;
  @Prop min: number = 0;
  @Prop max: number = 100;
  @Prop step: number = 1;
  @Prop settingEnabled: boolean = true;
  @State expanded: boolean = false;
  onChange: (value: number) => void = (_value: number): void => {};
  onCommit: () => void = () => {};

  private stepBy(delta: number): void {
    const next: number = Math.max(this.min, Math.min(this.max, this.value + delta * this.step));
    this.onChange(next);
    this.onCommit();
  }

  build() {
    Column() {
      Row() {
        // 标题区可点展开；加减号在右侧、不在此 Row 内，故不会误触发展开。
        Column() {
          Text(this.label).fontSize(14).fontWeight(FontWeight.Medium)
            .fontColor(this.settingEnabled ? this.themeColorTextPrimary : this.themeColorTextTertiary)
          if (this.description.length > 0) {
            Text(this.description).fontSize(11).fontColor(this.themeColorTextSecondary)
              .margin({ top: 2 }).maxLines(2)
          }
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        .onClick(() => { if (this.settingEnabled) { this.expanded = !this.expanded; } })

        if (!this.expanded) {
          AloudStepper({ valueText: this.valueText, stepperEnabled: this.settingEnabled,
            onDec: (): void => this.stepBy(-1), onInc: (): void => this.stepBy(1) })
        } else {
          Text(this.valueText).fontSize(13).fontColor(this.themeColorAccent)
            .onClick(() => { this.expanded = false; })
        }
      }
      .width('100%')

      if (this.expanded) {
        Slider({ value: this.value, min: this.min, max: this.max, step: this.step, style: SliderStyle.OutSet })
          .width('100%').selectedColor(this.themeColorAccent).enabled(this.settingEnabled)
          .margin({ top: 6, bottom: 2 })
          .onChange((v: number, mode: SliderChangeMode): void => {
            this.onChange(v);
            if (mode === SliderChangeMode.End) { this.onCommit(); }
          })
      }
    }
    .width('100%')
    .padding({ left: 12, right: 12, top: 10, bottom: 10 })
    .backgroundColor(glassColor(this.themeColorSurfaceSecondary, 0.55))
    .backdropBlur(16)
    .borderRadius(12)
    .margin({ left: 12, right: 12, bottom: 6 })
    .opacity(this.settingEnabled ? 1 : 0.5)
  }
}
