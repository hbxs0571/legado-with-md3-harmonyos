// 书源编辑页与调试页共用的圆形 FAB。
// 对齐上游 AppFloatingActionButton.kt:60-68：未传 size 时 M3 默认 56dp，
// containerColor=primaryContainer、contentColor=primary，带 elevation 阴影。
// 本组件只承载形态与命中区（>=48vp），动作由调用方回调，不含业务逻辑。
import { AppGlyph, AppGlyphName } from '../AppGlyph';

@Component
export struct AppFab {
  // 兜底值只在主题令牌尚未广播时生效；运行时一律由 AppStorage 覆盖。
  @StorageProp('themeColorPrimaryContainer') fabContainerColor: string = '#354E16';
  @StorageProp('themeColorAccent') fabContentColor: string = '#3F5BD9';
  // 阴影色走主题 scrim 令牌（半透明黑），不新增硬编码色值。
  @StorageProp('themeColorScrim') fabShadowColor: string = '#33000000';

  @Prop icon: AppGlyphName = 'profileSave';
  @Prop fabAccessibilityText: string = '';
  onFabClick: () => void = () => {};

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
    .onClick(() => this.onFabClick())
  }
}
