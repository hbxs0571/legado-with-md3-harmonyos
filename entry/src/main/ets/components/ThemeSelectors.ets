import { AppGlyph, AppGlyphName } from './AppGlyph';
import { resolvePaletteColors, THEME_PALETTES, ThemePaletteColors, ThemePaletteDefinition } from '../data/ThemePalette';

/**
 * 主题模式三档连体分段按钮。
 *
 * 上游 `ui/config/themeConfig/ThemeConfigScreen.kt:1004-1040` `ThemeModeSelector`：
 * 三档权重 `1.2f` / `1f` / `1f`（`:1021`）、档间距 `Arrangement.spacedBy(ButtonGroupDefaults.ConnectedSpaceBetween)`
 * （`:1019`，M3 该常量为 2dp）、首档 `connectedLeadingButtonShapes()` / 末档 `connectedTrailingButtonShapes()` /
 * 中间 `connectedMiddleButtonShapes()`（`:1028-1032`）、内容
 * `Icon(ToggleButtonDefaults.IconSize = 18dp) + Spacer(IconSpacing = 8dp) + Text(labelLarge = 14sp, maxLines 1)`（`:1034-1036`）。
 *
 * 欢迎页（`feature/onboarding/OnboardingScreen.kt:340`）与外观页（`ThemeConfigScreen.kt:223`）用的是同一个组件，
 * 所以这里抽成公共件，两页共用。
 *
 * 三处与上游不同的近似，都因本地缺对应色键 / 缺平台能力：
 * ① M3 `ToggleButton` 选中态是 `secondaryContainer` / `onSecondaryContainer`，本地只有 8 个广播键
 *    （`data/ThemePalette.ets:513-522`：accent、text×3、surface×4），没有 `secondaryContainer`，
 *    改用 `themeColorAccent` 底 + `themeColorSurfacePrimary` 字。这一组是欢迎页改动前的既有做法，
 *    选中一眼可辨，与本地整体调性一致。曾考虑「`themeColorSurfaceElevated` 底 + `themeColorAccent` 字」
 *    （更接近 M3 tonal），但三档并排时整块强调色更能表达「当前档位」，故选前者。
 * ② ArkUI 没有 `ButtonGroupDefaults`，外角按「40vp 高、全圆」取 20、内角取档间距 2，与 M3 的
 *    `connectedXxxButtonShapes()` 数值一致。
 * ③ 三档文案本地写死成中文，与其余页面一致；上游取 `R.string.flow_sys` / `light_mode` / `dark_mode`。
 */
@Component
export struct ThemeModeSelector {
  /** 当前模式：0 跟随系统 / 1 浅色 / 2 深色。 */
  @Prop selectedMode: number = 0;
  /** 选中回调，参数是模式值。 */
  onModeSelected: (mode: number) => void = (_mode: number) => {};

  @StorageProp('themeColorAccent') themeColorAccent: string = '#3F5BD9';
  @StorageProp('themeColorSurfacePrimary') themeColorSurfacePrimary: string = '#F5F6F8';
  @StorageProp('themeColorTextTertiary') themeColorTextTertiary: string = '#6A6D77';

  /** 图标色：选中与标题同色，未选走三级文字色。 */
  private itemColor(mode: number): string {
    return this.selectedMode === mode ? this.themeColorSurfacePrimary : this.themeColorTextTertiary;
  }

  /**
   * 单档。`position` 决定圆角：leading 左圆右方、middle 四角 2、trailing 左方右圆。
   * 圆角写成三档字面量而不是算出来的值，与上游三个 shapes 分支一一对应。
   */
  @Builder
  private modeItem(label: string, icon: AppGlyphName, mode: number, weight: number, position: string) {
    Row({ space: 8 }) {
      AppGlyph({ name: icon, glyphSize: 18, tint: this.itemColor(mode) })
      Text(label).fontSize(14).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
        .fontColor(this.itemColor(mode))
    }
    .height(40)
    .layoutWeight(weight)
    .justifyContent(FlexAlign.Center)
    .padding({ left: 12, right: 12 })
    .backgroundColor(this.selectedMode === mode ? this.themeColorAccent : Color.Transparent)
    .borderRadius(position === 'leading'
      ? { topLeft: 20, bottomLeft: 20, topRight: 2, bottomRight: 2 }
      : position === 'trailing'
        ? { topLeft: 2, bottomLeft: 2, topRight: 20, bottomRight: 20 }
        : { topLeft: 2, bottomLeft: 2, topRight: 2, bottomRight: 2 })
    .accessibilityText(label + (this.selectedMode === mode ? '，已选中' : ''))
    .onClick(() => { this.onModeSelected(mode); })
  }

  build() {
    // 档间用独立的 `Row().width(2)` 当间距，不用 `margin`：
    // `layoutWeight` 与 `margin` 同用时按「扣掉 margin 后的宽度」分配，三档比例会偏离 1.2/1/1；
    // 独立子节点则是先扣间距、再按 weight 分，与上游 `spacedBy(2.dp)` 同序。
    Row() {
      this.modeItem('跟随系统', 'brightness_medium', 0, 1.2, 'leading')
      Row().width(2).height(40)
      this.modeItem('浅色', 'light_mode', 1, 1, 'middle')
      Row().width(2).height(40)
      this.modeItem('深色', 'dark_mode', 2, 1, 'trailing')
    }
    .width('100%')
    .height(40)
  }
}

/**
 * 14 套配色横滑列表。
 *
 * 上游 `ThemeConfigScreen.kt:1043-1073` `ThemeColorSelector` 是
 * `LazyRow(horizontalArrangement = Arrangement.spacedBy(16.dp))` —— 横向滚动，装不下就滑，
 * 不是把 14 套等分塞进一屏。ArkUI 用 `Scroll(Horizontal)` + `Row({ space: 16 })` 等价。
 *
 * 上游按 `showEInkTheme` 过滤掉「电子书」那一档（`ThemeConfigScreen.kt:234-236`），
 * 本地全仓无 `showEInkTheme` 这个开关，所以 14 档全显示，不做过滤。
 */
@Component
export struct ThemeColorSelector {
  /** 当前选中的配色序号 0–13。 */
  @Prop selectedIndex: number = 0;
  /** 取日间还是夜间色值（`resolvePaletteColors(index, isDark)` 的第二参）。 */
  @Prop isDark: boolean = true;
  /** 选中回调，参数是配色序号。 */
  onPaletteSelected: (index: number) => void = (_index: number) => {};

  build() {
    Scroll() {
      Row({ space: 16 }) {
        ForEach(THEME_PALETTES, (palette: ThemePaletteDefinition) => {
          ThemeColorItem({
            title: palette.name,
            paletteIndex: palette.index,
            isDark: this.isDark,
            selected: this.selectedIndex === palette.index,
            onSelect: () => { this.onPaletteSelected(palette.index); }
          })
        }, (palette: ThemePaletteDefinition) => palette.index.toString())
      }
    }
    .scrollable(ScrollDirection.Horizontal)
    .scrollBar(BarState.Off)
    .width('100%')
    // 内容不足一屏时必须靠左；不写 align 会居中，第 13/14 项少时看起来像整体缩进。
    .align(Alignment.Start)
  }
}

/**
 * 单张配色卡。上游 `ThemeConfigScreen.kt:1077-1183` `ThemeColorButton`。
 *
 * 规格逐条对应：
 * - `Card(size(64), RoundedCornerShape(16), containerColor = colors.surfaceContainer)`（`:1113-1119`）
 * - 三色圆：48 大小，上 `secondary` 半圆（`drawArc -90/180`）、下 `tertiary` 半圆（`drawArc 90/180`）、
 *   中心 24 圆 `primary`（`:1125-1155`）
 * - 选中边框：`BorderStroke(2, LegadoTheme.colorScheme.primary)`（`:1115-1118`）——
 *   **注意是全局当前主题的 primary，不是被选中配色自己的 primary**，对应本地 `themeColorAccent`
 * - 选中勾：40×40、圆角 12、`Icon(Check, size 24, tint = onPrimary)`（`:1157-1171`）——
 *   **上游这个 Box 没有 background**，勾直接浮在三色圆上；本地按源码不画底色，
 *   tint 用 `themeColorSurfacePrimary` 近似 `onPrimary`（与模式选择器的选中字同一取舍）
 * - 名字：`labelSmall` 11sp、`Spacer(12)`、选中 `primary` 未选 `onSurface`（`:1175-1181`）
 *
 * 卡底与三色圆用**该配色自己的**色值（`resolvePaletteColors`），描边与名字用**当前主题的** accent，
 * 这个混用在源码里就是这样，不是笔误。
 */
@Component
struct ThemeColorItem {
  @Prop title: string = '';
  @Prop paletteIndex: number = 0;
  @Prop isDark: boolean = true;
  @Prop selected: boolean = false;
  onSelect: () => void = () => {};

  @StorageProp('themeColorAccent') themeColorAccent: string = '#3F5BD9';
  @StorageProp('themeColorTextPrimary') themeColorTextPrimary: string = '#1B1C22';
  @StorageProp('themeColorSurfacePrimary') themeColorSurfacePrimary: string = '#F5F6F8';

  /** 该配色自己的色值；查的是常量表，开销可忽略，不缓存成 @State（否则换肤时不更新）。 */
  private colors(): ThemePaletteColors {
    return resolvePaletteColors(this.paletteIndex, this.isDark);
  }

  build() {
    Column() {
      Stack({ alignContent: Alignment.Center }) {
        // 三色圆：上 24 高 secondary 半圆 + 下 24 高 tertiary 半圆，合起来外径 48。
        Column() {
          Row().width(48).height(24).backgroundColor(this.colors().secondary)
            .borderRadius({ topLeft: 24, topRight: 24 })
          Row().width(48).height(24).backgroundColor(this.colors().tertiary)
            .borderRadius({ bottomLeft: 24, bottomRight: 24 })
        }
        .width(48).height(48)
        // clip 必须在外层，否则两个半圆各带圆角会在中线处漏出直角缝隙。
        .clip(true)
        Row().width(24).height(24).backgroundColor(this.colors().primary).borderRadius(12)
        if (this.selected) {
          Stack({ alignContent: Alignment.Center }) {
            AppGlyph({ name: 'profileCheck', glyphSize: 24, tint: this.themeColorSurfacePrimary })
          }
          .width(40).height(40).borderRadius(12)
        }
      }
      .width(64).height(64)
      .clip(true)
      .backgroundColor(this.colors().surfaceContainer)
      .borderRadius(16)
      .border({ width: this.selected ? 2 : 0, color: this.themeColorAccent })
      .animation({ duration: 180, curve: Curve.EaseOut })
      .accessibilityText(this.title + (this.selected ? '，已选中' : ''))
      .onClick(() => { this.onSelect(); })

      // 名字在 64×64 的框外：上游 Card 只包三色圆，Spacer(12) 之后才是文字。
      // 塞进带边框的容器会把卡变成 64×76 的竖条。
      Text(this.title)
        .fontSize(11).maxLines(1).textAlign(TextAlign.Center)
        .fontColor(this.selected ? this.themeColorAccent : this.themeColorTextPrimary)
        .margin({ top: 12 })
    }
    .width(64)
    .alignItems(HorizontalAlign.Center)
  }
}
