import { curves } from '@kit.ArkUI';
import { AppGlyph } from './AppGlyph';

// 轨道与滑块的几何（对齐 M3 Switch 的公开规格）
const SWITCH_TRACK_WIDTH: number = 52;
const SWITCH_TRACK_HEIGHT: number = 32;
const SWITCH_THUMB_ON: number = 24;
const SWITCH_THUMB_OFF: number = 16;
// 按下时的滑块直径：SwitchTokens.PressedHandleWidth / PressedHandleHeight = 28
const SWITCH_THUMB_PRESSED: number = 28;
const SWITCH_ICON_SIZE: number = 16;
// 滑块与轨道边缘的留白：(32 − 24) / 2 = 4
const SWITCH_THUMB_INSET: number = 4;
// 轨道描边宽度：SwitchTokens.TrackOutlineWidth = 2dp
const SWITCH_TRACK_OUTLINE_WIDTH: number = 2;
// 禁用态合成用的 alpha（上游 SwitchTokens 的 Disabled* 一组）
const SWITCH_DISABLED_HANDLE_ALPHA: number = 0.38;
const SWITCH_DISABLED_TRACK_ALPHA: number = 0.12;
const SWITCH_DISABLED_OUTLINE_ALPHA: number = 0.12;

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
  @StorageProp('themeColorSurfaceHighest') themeColorSurfaceHighest: string = '#1D1E24';
  @StorageProp('themeColorTextPrimary') themeColorTextPrimary: string = '#1B1C22';
  @StorageProp('themeColorTextTertiary') themeColorTextTertiary: string = '#6A6D77';

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
  // 按压态：只驱动滑块尺寸，不做 stateLayer 水波纹（本地全仓 stateStyles 仅 1 处，另说）
  @State private pressed: boolean = false;

  aboutToAppear(): void {
    this.animChecked = this.checked;
  }

  aboutToDisappear(): void {
    this.pressed = false;
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

  /** 滑块尺寸：按下时一律 28（M3 的 PressedHandleWidth / Height），否则选中 24 / 未选中 16。 */
  private thumbSize(): number {
    if (this.pressed) {
      return SWITCH_THUMB_PRESSED;
    }
    return this.animChecked ? SWITCH_THUMB_ON : SWITCH_THUMB_OFF;
  }

  /**
   * 滑块左偏移。
   *
   * 按「圆心不动」推：M3 按下只是把滑块涨大，圆心不跳。两态的圆心分别是
   *   未选中 (32 − 16) / 2 + 16 / 2 = 16
   *   选中   52 − (32 − 24) / 2 − 24 / 2 = 36
   * 左偏移 = 圆心 − 当前直径 / 2。常态下与 M3 的 8 / 24 完全一致；
   * 按下态因此是 16 − 14 = 2 与 36 − 14 = 22（不是硬加 4dp 留白，那样竖直方向会只剩 2、水平 4，不同心）。
   */
  private thumbOffset(): number {
    const size = this.thumbSize();
    const center = this.animChecked
      ? SWITCH_TRACK_WIDTH - (SWITCH_TRACK_HEIGHT - SWITCH_THUMB_ON) / 2 - SWITCH_THUMB_ON / 2
      : (SWITCH_TRACK_HEIGHT - SWITCH_THUMB_OFF) / 2 + SWITCH_THUMB_OFF / 2;
    return center - size / 2;
  }

  /** 解析 `#RRGGBB` 为三通道；非法输入返回 null，由调用方回退原色。 */
  private parseHex(color: string): number[] | null {
    if (color.length !== 7 || color.charAt(0) !== '#') {
      return null;
    }
    const r = Number.parseInt(color.substring(1, 3), 16);
    const g = Number.parseInt(color.substring(3, 5), 16);
    const b = Number.parseInt(color.substring(5, 7), 16);
    if (Number.isNaN(r) || Number.isNaN(g) || Number.isNaN(b)) {
      return null;
    }
    return [r, g, b];
  }

  /**
   * M3 禁用态的 `fg.copy(alpha).compositeOver(bg)`。
   *
   * 上游不是整体降透明度，而是逐色合成：整体 0.38 会把描边一起淡掉，
   * 未选中禁用态反而比上游更看不见。
   */
  private compositeOver(fg: string, alpha: number, bg: string): string {
    const f = this.parseHex(fg);
    const b = this.parseHex(bg);
    if (f === null || b === null) {
      return fg;
    }
    const channel = (i: number): string => {
      const v = Math.round(f[i] * alpha + b[i] * (1 - alpha));
      const hex = Math.max(0, Math.min(255, v)).toString(16).toUpperCase();
      return hex.length === 1 ? `0${hex}` : hex;
    };
    return `#${channel(0)}${channel(1)}${channel(2)}`;
  }

  /**
   * 轨道色，逐条对齐 androidx SwitchTokens（v0_210）：
   *   选中            = Primary
   *   未选中          = SurfaceContainerHighest
   *   禁用·选中       = OnSurface α0.12 压在 Surface 上
   *   禁用·未选中     = SurfaceContainerHighest α0.12 压在 Surface 上
   *
   * 原来未选中取的是 surfaceContainer（深色 #1B1C22），与页面底色只差一档，
   * 屏幕上看起来像「隐形」，这正是本次要修的第一件事。
   * 纯黑模式下也不另换色：上游没有「纯黑轨道单独配色」这回事。
   */
  private trackColor(): string {
    if (!this.switchEnabled) {
      const base = this.animChecked ? this.themeColorTextPrimary : this.themeColorSurfaceHighest;
      return this.compositeOver(base, SWITCH_DISABLED_TRACK_ALPHA, this.themeColorSurfacePrimary);
    }
    return this.animChecked ? this.themeColorAccent : this.themeColorSurfaceHighest;
  }

  /**
   * 滑块色：
   *   选中        = OnPrimary（本地无该键，用 surfacePrimary 近似）
   *   未选中      = Outline（= themeColorTextTertiary）
   *   禁用·选中   = Surface
   *   禁用·未选中 = OnSurface α0.38 压在 Surface 上
   */
  private thumbColor(): string {
    if (!this.switchEnabled) {
      if (this.animChecked) {
        return this.themeColorSurfacePrimary;
      }
      return this.compositeOver(this.themeColorTextPrimary, SWITCH_DISABLED_HANDLE_ALPHA, this.themeColorSurfacePrimary);
    }
    return this.animChecked ? this.themeColorSurfacePrimary : this.themeColorTextTertiary;
  }

  /**
   * 轨道描边色：只有未选中态有描边（选中态上游是 Color.Transparent）。
   *   未选中        = Outline
   *   禁用·未选中   = OnSurface α0.12 压在 Surface 上
   */
  private trackOutlineColor(): string {
    if (this.animChecked) {
      return '#00000000';
    }
    if (!this.switchEnabled) {
      return this.compositeOver(this.themeColorTextPrimary, SWITCH_DISABLED_OUTLINE_ALPHA, this.themeColorSurfacePrimary);
    }
    return this.themeColorTextTertiary;
  }

  private handleClick(): void {
    if (!this.switchEnabled) {
      return;
    }
    const next: boolean = !this.checked;
    this.animateToChecked(next);
    this.onChange(next);
  }

  private updatePressed(next: boolean): void {
    if (this.pressed === next) {
      return;
    }
    this.getUIContext().animateTo({ curve: curves.springMotion(0.35, 0.9) }, () => {
      this.pressed = next;
    });
  }

  build() {
    Stack({ alignContent: Alignment.Start }) {
      // 轨道底色
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

      // 描边单独叠一层，不画在轨道本体上：ArkUI 的 .border() 会挤占内容区，
      // 画在轨道上会把滑块连同 8/24 的偏移一起顶掉 2vp。
      Column()
        .width(SWITCH_TRACK_WIDTH)
        .height(SWITCH_TRACK_HEIGHT)
        .borderRadius(SWITCH_TRACK_HEIGHT / 2)
        .border({ width: SWITCH_TRACK_OUTLINE_WIDTH, color: this.trackOutlineColor() })
        .hitTestBehavior(HitTestMode.None)
    }
    .width(SWITCH_TRACK_WIDTH)
    .height(SWITCH_TRACK_HEIGHT)
    .scale({ x: this.scaleValue, y: this.scaleValue })
    // interactive 为 false 时完全不接手势：否则内层 onClick 会把点击消费掉，
    // 外层整行的 onClick 收不到事件，出现「点开关不切换、点标题才切换」。
    .hitTestBehavior(this.interactive ? HitTestMode.Default : HitTestMode.None)
    .onTouch((event: TouchEvent) => {
      if (!this.interactive || !this.switchEnabled) {
        return;
      }
      if (event.type === TouchType.Down) {
        this.updatePressed(true);
      } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
        this.updatePressed(false);
      }
    })
    .onClick(() => {
      if (!this.interactive) {
        return;
      }
      this.handleClick();
    })
  }
}
