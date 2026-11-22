import {
  BAR_BLUR_ALPHA_MAX,
  BAR_BLUR_ALPHA_MIN,
  BOTTOM_BAR_BLUR_RADIUS_MAX,
  BOTTOM_BAR_BLUR_RADIUS_MIN,
  BOTTOM_BAR_LENS_RADIUS_MAX,
  BOTTOM_BAR_LENS_RADIUS_MIN,
  TOP_BAR_BLUR_RADIUS_MAX,
  TOP_BAR_BLUR_RADIUS_MIN,
  TOP_BAR_BUTTON_STYLES,
  TOP_BAR_OPACITY_MAX,
  TOP_BAR_OPACITY_MIN,
  topBarButtonStyleLabel
} from '../../data/TopBottomBarSettings';
import { HEADLINE_SMALL } from '../typography/TypographyTokens';
import { SPACE_12, SPACE_4, SPACE_8 } from '../UiTokens';
import { UiDropdown } from './UiDropdown';
import { UiSlider } from './UiSlider';
import { UiSwitch } from './UiSwitch';

/**
 * 顶栏与底栏设置面板。
 *
 * 上游是独立的 `TopBottomBarSettingsSheet.kt`（177 行），由「顶栏与底栏」入口的
 * `ThemeConfigIntent.ShowTopBottomBarSheet` 打开；本地此前把它做成外观页里的一个可展开组，
 * 批 2 改为 sheet，形态与其余六个面板一致。
 *
 * 十三个键与上游一一对应（`TopBottomBarSettingsSheet.kt:49-174`）：
 * - `useFlexibleTopAppBar`（`use_flexible_top_bar`）
 * - `topBarButtonStyle`（`top_bar_button_style`）
 * - `mergeTopBarActions`（`merge_top_bar_actions`，仅 topBarButtonStyle != 'plain' 时显示）
 * - `showBottomView`（`show_bottom_nav` + `be_swiped`）
 * - `useFloatingBottomBar`（`floating_bottom_bar` + `floating_bottom_bar_summary`）
 * - `useFloatingBottomBarLiquidGlass`（仅 useFloatingBottomBar 时显示）
 * - `bottomBarLensRadius`（`theme_config_bottom_bar_lens_radius`，0..50，默认 24）
 * - `topBarBlurRadius`（`theme_manage_top_bar_blur_radius`，0..30，默认 24）
 * - `bottomBarBlurRadius`（`theme_manage_bottom_bar_blur_radius`，0..10，默认 8）
 * - `topBarBlurAlpha` / `bottomBarBlurAlpha`（`theme_manage_*_bar_blur_opacity`，0..100，默认 73 / 40）
 * - `topBarOpacity` / `bottomBarOpacity`（`top_bar_opacity` / `bottom_bar_opacity`，0..100，默认 100）
 * 后两组互斥：`enableBlur` 为真走模糊半径与不透明度，否则走不透明度（上游 `:108-174`）。
 *
 * 上游 `isMiuixEngine` 分支本地无对应维度（本地只有一套渲染），所以
 * `useFlexibleTopAppBar` 与两条 `*_bar_opacity` 不做引擎条件包裹 —— 这一点与上游非 Miuix 分支一致。
 */
@Component
export struct TopBottomBarSettingsSheet {
  @StorageProp('themeColorTextPrimary') themeColorTextPrimary: string = '#1B1C22';
  @StorageProp('themeColorTextTertiary') themeColorTextTertiary: string = '#6A6D77';
  @StorageProp('themeColorAccent') themeColorAccent: string = '#3F5BD9';

  @Prop useFlexibleTopAppBar: boolean = true;
  @Prop topBarButtonStyle: string = 'tonal';
  @Prop mergeTopBarActions: boolean = false;
  @Prop showBottomView: boolean = true;
  @Prop useFloatingBottomBar: boolean = false;
  @Prop useFloatingBottomBarLiquidGlass: boolean = false;
  @Prop bottomBarLensRadius: number = 24;
  @Prop enableBlur: boolean = false;
  @Prop topBarBlurRadius: number = 24;
  @Prop bottomBarBlurRadius: number = 8;
  @Prop topBarBlurAlpha: number = 73;
  @Prop bottomBarBlurAlpha: number = 40;
  @Prop topBarOpacity: number = 100;
  @Prop bottomBarOpacity: number = 100;

  onUseFlexibleTopAppBarChange: (value: boolean) => void = (_value: boolean) => {};
  onTopBarButtonStyleChange: (value: string) => void = (_value: string) => {};
  onMergeTopBarActionsChange: (value: boolean) => void = (_value: boolean) => {};
  onShowBottomViewChange: (value: boolean) => void = (_value: boolean) => {};
  onUseFloatingBottomBarChange: (value: boolean) => void = (_value: boolean) => {};
  onUseFloatingBottomBarLiquidGlassChange: (value: boolean) => void = (_value: boolean) => {};
  onBottomBarLensRadiusChange: (value: number) => void = (_value: number) => {};
  onTopBarBlurRadiusChange: (value: number) => void = (_value: number) => {};
  onBottomBarBlurRadiusChange: (value: number) => void = (_value: number) => {};
  onTopBarBlurAlphaChange: (value: number) => void = (_value: number) => {};
  onBottomBarBlurAlphaChange: (value: number) => void = (_value: number) => {};
  onTopBarOpacityChange: (value: number) => void = (_value: number) => {};
  onBottomBarOpacityChange: (value: number) => void = (_value: number) => {};

  build() {
    Column() {
      // 上游 `AppModalBottomSheet` 的标题行（`AppModalBottomSheet.kt` 的 hasHeader 分支）
      Text('顶栏与底栏')
        .fontSize(HEADLINE_SMALL)
        .fontColor(this.themeColorTextPrimary)
        .width('100%')
        .textAlign(TextAlign.Center)
        .padding({ left: 56, right: 56, bottom: SPACE_12 })

      Scroll() {
        Column({ space: SPACE_4 }) {
          UiSwitch({
            title: '使用折叠应用栏',
            value: this.useFlexibleTopAppBar,
            showDivider: false,
            onChange: (value: boolean) => this.onUseFlexibleTopAppBarChange(value)
          })
          UiDropdown({
            showDivider: false,
            title: '顶栏按钮样式',
            option: this.topBarButtonStyle,
            options: TOP_BAR_BUTTON_STYLES,
            labelOf: (value: string) => topBarButtonStyleLabel(value),
            onSelect: (value: string) => this.onTopBarButtonStyleChange(value)
          })
          if (this.topBarButtonStyle !== 'plain') {
            UiSwitch({
              title: '合并顶栏按钮',
              value: this.mergeTopBarActions,
              showDivider: false,
              onChange: (value: boolean) => this.onMergeTopBarActionsChange(value)
            })
          }
          UiSwitch({
            title: '显示导航栏',
            detail: '仍可滑动切换页面',
            value: this.showBottomView,
            showDivider: false,
            onChange: (value: boolean) => this.onShowBottomViewChange(value)
          })
          UiSwitch({
            title: '悬浮底栏',
            detail: '底部导航栏使用悬浮胶囊样式',
            value: this.useFloatingBottomBar,
            showDivider: false,
            onChange: (value: boolean) => this.onUseFloatingBottomBarChange(value)
          })
          if (this.useFloatingBottomBar) {
            UiSwitch({
              title: '液态玻璃效果',
              detail: '为悬浮底栏启用液态玻璃高光效果',
              value: this.useFloatingBottomBarLiquidGlass,
              showDivider: false,
              onChange: (value: boolean) => this.onUseFloatingBottomBarLiquidGlassChange(value)
            })
            UiSlider({
              showDivider: false,
              title: '底栏模糊强度',
              detail: `液态玻璃扭曲程度 ${this.bottomBarLensRadius}vp`,
              value: this.bottomBarLensRadius,
              minValue: BOTTOM_BAR_LENS_RADIUS_MIN,
              maxValue: BOTTOM_BAR_LENS_RADIUS_MAX,
              onChange: (value: number) => this.onBottomBarLensRadiusChange(value)
            })
          }
          if (this.enableBlur) {
            UiSlider({
              showDivider: false,
              title: '顶栏模糊半径',
              detail: '模糊半径越大，系统运行越卡顿',
              value: this.topBarBlurRadius,
              minValue: TOP_BAR_BLUR_RADIUS_MIN,
              maxValue: TOP_BAR_BLUR_RADIUS_MAX,
              onChange: (value: number) => this.onTopBarBlurRadiusChange(value)
            })
            UiSlider({
              showDivider: false,
              title: '底栏模糊半径',
              detail: '模糊半径越大，系统运行越卡顿',
              value: this.bottomBarBlurRadius,
              minValue: BOTTOM_BAR_BLUR_RADIUS_MIN,
              maxValue: BOTTOM_BAR_BLUR_RADIUS_MAX,
              onChange: (value: number) => this.onBottomBarBlurRadiusChange(value)
            })
            UiSlider({
              showDivider: false,
              title: '顶栏模糊不透明度',
              detail: `${this.topBarBlurAlpha}%`,
              value: this.topBarBlurAlpha,
              minValue: BAR_BLUR_ALPHA_MIN,
              maxValue: BAR_BLUR_ALPHA_MAX,
              onChange: (value: number) => this.onTopBarBlurAlphaChange(value)
            })
            UiSlider({
              showDivider: false,
              title: '底栏模糊不透明度',
              detail: `${this.bottomBarBlurAlpha}%`,
              value: this.bottomBarBlurAlpha,
              minValue: BAR_BLUR_ALPHA_MIN,
              maxValue: BAR_BLUR_ALPHA_MAX,
              onChange: (value: number) => this.onBottomBarBlurAlphaChange(value)
            })
          } else {
            UiSlider({
              showDivider: false,
              title: '顶栏不透明度',
              detail: `${this.topBarOpacity}%`,
              value: this.topBarOpacity,
              minValue: TOP_BAR_OPACITY_MIN,
              maxValue: TOP_BAR_OPACITY_MAX,
              onChange: (value: number) => this.onTopBarOpacityChange(value)
            })
            UiSlider({
              showDivider: false,
              title: '底栏不透明度',
              detail: `${this.bottomBarOpacity}%`,
              value: this.bottomBarOpacity,
              minValue: TOP_BAR_OPACITY_MIN,
              maxValue: TOP_BAR_OPACITY_MAX,
              onChange: (value: number) => this.onBottomBarOpacityChange(value)
            })
          }
        }
        .width('100%')
        .padding({ bottom: SPACE_8 })
      }
      .width('100%')
      .layoutWeight(1)
      .scrollBar(BarState.Off)
    }
    .width('100%')
    .padding({ left: SPACE_12, right: SPACE_12 })
    .alignItems(HorizontalAlign.Center)
  }
}
