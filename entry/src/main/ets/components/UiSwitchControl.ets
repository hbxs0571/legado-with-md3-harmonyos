import { curves } from '@kit.ArkUI';
import { AppGlyph } from './AppGlyph';

// 轨道与滑块的几何（对齐 M3 Switch 的公开规格）
const SWITCH_TRACK_WIDTH: number = 52;
const SWITCH_TRACK_HEIGHT: number = 32;
const SWITCH_THUMB_ON: number = 24;
const SWITCH_THUMB_OFF: number = 16;
const SWITCH_ICON_SIZE: number = 16;
// 滑块与轨道边缘的留白
const SWITCH_THUMB_INSET: number = 4;
// 禁用态透明度（上游 alpha = 0.38f）
const SWITCH_DISABLED_OPACITY: number = 0.38;

/**
 * 自绘开关：M3 Switch 的形状 + 滑块里一颗勾。
 *
 * 为什么不直接用 Toggle：SDK 的 Toggle 只有 selectedColor / switchPointColor /
 * switchStyle，没有任何「往滑块里放图标」的能力，而上游 IconSwitch 的核心
 * 就是 Switch + thumbContent 里的一颗 Check。
 *
 * 只画控件本身，不含标题与整行布局，所以既能被 UiSwitch 行内使用，
 * 也能直接替换页面里单独的 Toggle。
 */
@Component
export struct UiSwitchControl {
  @StorageProp('themeColorAccent') themeColorAccent: string = '#3F5BD9';
  @StorageProp('themeColorSurfacePrimary') themeColorSurfacePrimary: string = '#F5F6F8';
  @StorageProp('themeColorSurfaceSecondary') themeColorSurfaceSecondary: string = '#FFFFFF';
  @StorageProp('themeColorSurfaceTertiary') themeColorSurfaceTertiary: string = '#F0F1F5';
  @StorageProp('themeColorTextPrimary') themeColorTextPrimary: string = '#1B1C22';
  @StorageProp('themePureBlack') themePureBlack: boolean = false;

  @Prop @Watch('onCheckedPropChange') checked: boolean = false;
  @Prop switchEnabled: boolean = true;
  /** 关掉后滑块里不画任何图标（对齐上游 showIcon = false）。 */
  @Prop showIcon: boolean = true;
  /** 缩放系数，对齐上游 TinySwitch 的 0.72。 */
  @Prop scaleValue: number = 1;
  /**
   * 是否由控件自己处理点击。默认 true（单独使用）；
   * 被外层整行包住时传 false，只画不点，避免冒泡把一次点击切成两次。
   */
  @Prop interactive: boolean = true;

  onChange: (checked: boolean) => void = (_checked: boolean) => {};

  // 动画用的本地值：@Prop 变化时用 springMotion 补齐过渡，直接改 @Prop 是跳变的
  @State private animChecked: boolean = false;

  aboutToAppear(): void {
    this.animChecked = this.checked;
  }

  onCheckedPropChange(): void {
    if (this.animChecked === this.checked) {
      return;
    }
    this.animateToChecked(this.checked);
  }

  private animateToChecked(next: boolean): void {
    if (!this.switchEnabled) {
      this.animChecked = next;
      return;
    }
    this.getUIContext().animateTo({ curve: curves.springMotion(0.35, 0.9) }, () => {
      this.animChecked = next;
    });
  }

  private thumbSize(): number {
    return this.animChecked ? SWITCH_THUMB_ON : SWITCH_THUMB_OFF;
  }

  private thumbOffset(): number {
    return this.animChecked ? (SWITCH_TRACK_WIDTH - SWITCH_THUMB_ON - SWITCH_THUMB_INSET) : SWITCH_THUMB_INSET + SWITCH_THUMB_INSET;
  }

  private trackColor(): string {
    if (this.animChecked) {
      return this.themeColorAccent;
    }
    return this.themePureBlack ? '#3A3A3A' : this.themeColorSurfaceTertiary;
  }

  private thumbColor(): string {
    return this.animChecked ? this.themeColorSurfacePrimary : this.themeColorSurfaceSecondary;
  }

  private handleClick(): void {
    if (!this.switchEnabled) {
      return;
    }
    const next: boolean = !this.checked;
    this.animateToChecked(next);
    this.onChange(next);
  }

  build() {
    Stack({ alignContent: Alignment.Start }) {
      // 轨道
      Column()
        .width(SWITCH_TRACK_WIDTH)
        .height(SWITCH_TRACK_HEIGHT)
        .borderRadius(SWITCH_TRACK_HEIGHT / 2)
        .backgroundColor(this.trackColor())

      // 滑块（勾画在滑块里面）
      Stack({ alignContent: Alignment.Center }) {
        if (this.showIcon && this.animChecked) {
          AppGlyph({ name: 'profileCheck', glyphSize: SWITCH_ICON_SIZE, tint: this.themeColorTextPrimary })
        }
      }
      .width(this.thumbSize())
      .height(this.thumbSize())
      .borderRadius(this.thumbSize() / 2)
      .backgroundColor(this.thumbColor())
      .margin({ left: this.thumbOffset() })
    }
    .width(SWITCH_TRACK_WIDTH)
    .height(SWITCH_TRACK_HEIGHT)
    .scale({ x: this.scaleValue, y: this.scaleValue })
    .opacity(this.switchEnabled ? 1 : SWITCH_DISABLED_OPACITY)
    // interactive 为 false 时完全不接手势：否则内层 onClick 会把点击消费掉，
    // 外层整行的 onClick 收不到事件，出现「点开关不切换、点标题才切换」。
    .hitTestBehavior(this.interactive ? HitTestMode.Default : HitTestMode.None)
    .onClick(() => {
      if (!this.interactive) {
        return;
      }
      this.handleClick();
    })
  }
}
