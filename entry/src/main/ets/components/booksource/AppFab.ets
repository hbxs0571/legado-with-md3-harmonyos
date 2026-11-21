// 书源编辑页与调试页共用的圆形 FAB。
// 对齐上游 AppFloatingActionButton.kt:60-68：未传 size 时 M3 默认 56dp，
// containerColor=primaryContainer、contentColor=primary，带 elevation 阴影。
// 本组件只承载形态与命中区（>=48vp），动作由调用方回调，不含业务逻辑。
//
// tooltip（上游 AppFloatingActionButton.kt:100 的 TooltipBox）：
// M3 Tooltip.kt:98/:162 在触摸设备上的触发动作是**长按**；ArkUI 的 bindTips 依赖鼠标悬浮、
// 手机触屏不弹，所以这里用 bindPopup + LongPressGesture 自建长按气泡。
// 度量照 M3 Tooltip 默认值：圆角 4、文字 BodySmall(12sp/16sp)、内边距水平 8 垂直 4、
// 最小 40x24、最大宽 200、箭头 16x8、与锚点间距 4、无阴影（tonalElevation/shadowElevation 均为 0）。
import { AppGlyph, AppGlyphName } from '../AppGlyph';
import { BODY_SMALL, BODY_SMALL_LINE_HEIGHT } from '../typography/TypographyTokens';

@Component
export struct AppFab {
  // 兜底值只在主题令牌尚未广播时生效；运行时一律由 AppStorage 覆盖。
  @StorageProp('themeColorPrimaryContainer') fabContainerColor: string = '#354E16';
  @StorageProp('themeColorAccent') fabContentColor: string = '#3F5BD9';
  // 阴影色走主题 scrim 令牌（半透明黑），不新增硬编码色值。
  @StorageProp('themeColorScrim') fabShadowColor: string = '#33000000';
  // M3 Tooltip 容器色默认 inverseSurface、文字 inverseOnSurface。
  // 本地调色板未发布这两个色位，用 surfaceContainerHighest + onSurface 作容器/文字（同层对比度最高的组合）。
  @StorageProp('themeColorSurfaceHighest') fabTipBackground: string = '#E1E2E7';
  @StorageProp('themeColorTextPrimary') fabTipTextColor: string = '#1A1B20';

  @Prop icon: AppGlyphName = 'profileSave';
  @Prop fabAccessibilityText: string = '';
  onFabClick: () => void = () => {};

  /** 长按气泡显隐；bindPopup 的 onStateChange 负责复位。 */
  @State private tipVisible: boolean = false;

  /** 气泡内容：M3 Tooltip 的 BodySmall + 水平 8 / 垂直 4 内边距 + 4 圆角 + 最大宽 200。 */
  @Builder TipContent() {
    Text(this.fabAccessibilityText)
      .fontSize(BODY_SMALL)
      .lineHeight(BODY_SMALL_LINE_HEIGHT)
      .fontColor(this.fabTipTextColor)
      .padding({ left: 8, right: 8, top: 4, bottom: 4 })
      .constraintSize({ minWidth: 40, minHeight: 24, maxWidth: 200 })
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      AppGlyph({ name: this.icon, glyphSize: 24, tint: this.fabContentColor })
    }
    .width(56)
    .height(56)
    .borderRadius(28)
    .backgroundColor(this.fabContainerColor)
    .shadow({ radius: 6, color: this.fabShadowColor, offsetX: 0, offsetY: 3 })
    .accessibilityText(this.fabAccessibilityText)
    // 长按弹 tooltip（M3 触摸设备的触发方式），短按仍是 FAB 动作本身。
    .gesture(
      LongPressGesture({ repeat: false, duration: 500 })
        .onAction(() => { this.tipVisible = true; })
    )
    .onClick(() => this.onFabClick())
    // 气泡放在 FAB 上方（上游 TooltipAnchor.Above，AppFloatingActionButton.kt:100），
    // 带 16x8 箭头、4 圆角、无遮罩；点其它位置或再点 FAB 即消失。
    .bindPopup(this.tipVisible && this.fabAccessibilityText.length > 0, {
      builder: () => { this.TipContent(); },
      placement: Placement.Top,
      popupColor: this.fabTipBackground,
      enableArrow: true,
      arrowWidth: 16,
      arrowHeight: 8,
      radius: 4,
      autoCancel: true,
      mask: false,
      onStateChange: (event: PopupStateChangeParam) => {
        if (!event.isVisible) { this.tipVisible = false; }
      }
    })
  }
}
