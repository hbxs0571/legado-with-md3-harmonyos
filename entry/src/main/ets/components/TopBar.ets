import { AppGlyph, AppGlyphName } from './AppGlyph';
import { ProgressiveBackdrop } from './ProgressiveBackdrop';
import { cubicBezierEasing } from './motion/CubicBezier';
import { TYPE_SCALE_HEADLINE_MEDIUM, TYPE_SCALE_LABEL_LARGE, TYPE_SCALE_TITLE_LARGE } from './typography/TypographyTokens';

// 全部来自 M3 官方 token，不要凭手感改。
// 出处：androidx compose material3 的 tokens/AppBarSmallTokens.kt、tokens/AppBarMediumFlexibleTokens.kt；
// 字号不再写在本文件，改为引 components/typography/TypographyTokens.ets 的 TYPE_SCALE_*，
// 那里记了上游两套排版值的区别与出处（GlassTopAppBar.kt:76 等）。

/** 收起行高，AppBarSmallTokens.ContainerHeight。 */
export const TOP_BAR_COLLAPSED_HEIGHT: number = 64;
/** 展开高（无副标题），AppBarMediumFlexibleTokens.ContainerHeight。 */
export const TOP_BAR_EXPANDED_HEIGHT: number = 112;
/** 展开高（有副标题），AppBarMediumFlexibleTokens.LargeContainerHeight。 */
export const TOP_BAR_EXPANDED_HEIGHT_SUBTITLE: number = 136;
/** 展开标题字号，M3 原生 headlineMedium。 */
export const TOP_BAR_TITLE_EXPANDED_SIZE: number = TYPE_SCALE_HEADLINE_MEDIUM;
/** 收起标题字号，M3 原生 titleLarge。 */
export const TOP_BAR_TITLE_COLLAPSED_SIZE: number = TYPE_SCALE_TITLE_LARGE;
/** 展开副标题字号，M3 原生 labelLarge。 */
export const TOP_BAR_SUBTITLE_SIZE: number = TYPE_SCALE_LABEL_LARGE;
/** 顶栏左右最小内边距，AppBar.kt 的 TopAppBarHorizontalPadding。 */
export const TOP_BAR_SIDE_PADDING: number = 4;
/** 无导航按钮时标题的左起点，= max(12, 0) + 4。 */
export const TOP_BAR_TITLE_START: number = 16;
/** 动作区右端距屏幕边，= 4（布局）+ 12（上游外层 Box）。 */
export const TOP_BAR_ACTIONS_END: number = 16;
/**
 * 展开标题底边距，M3 `MediumTitleBottomPadding = 24.dp`（AppBar.kt:3611-3612）。
 * 注意这与「展开区剩余高度」是两件事：上游把它交给布局按基线算，
 * 本地见 `titleBottomPadding()` 的注释。
 */
export const TOP_BAR_MEDIUM_TITLE_BOTTOM_PADDING: number = 24;
/**
 * 收起行标题透明度缓动：M3 `TopTitleAlphaEasing = CubicBezierEasing(.8f, 0f, .8f, .15f)`
 * （AppBar.kt:3609）。collapsedFraction 从 0 到 1 时，收起行标题按这条曲线淡入。
 */
export const topTitleAlphaEasing: (fraction: number) => number = cubicBezierEasing(0.8, 0, 0.8, 0.15);

/** 按钮尺寸：plain 40，其余四档 36（TopBarButton.kt 的 MediumSeriesIconButtonSize / TopBarSeriesIconButtonSize）。 */
export function topBarButtonSize(style: string): number {
  return style === 'plain' ? 40 : 36;
}

/** 图标尺寸：plain 24，其余四档 20。 */
export function topBarIconSize(style: string): number {
  return style === 'plain' ? 24 : 20;
}

/** 动作之间的间距：plain 4，其余 8（TopBarButton.kt 的 topBarActionSpacing）。 */
export function topBarActionSpacing(style: string): number {
  return style === 'plain' ? 4 : 8;
}

/**
 * 统一顶栏。结构照上游 `ui/widget/components/topbar/GlassMediumFlexibleTopAppBar.kt`：
 * 外层容器自己画底，内部两行——第一行（收起态，含导航按钮与动作）常驻、第二行（展开态大标题，
 * 导航与动作都为空）随折叠收起。M3 里两行靠 scrolledOffset 连续插值，本地是布尔折叠 + 弹簧，
 * 所以用「外层总高在 64 与展开高之间切换 + clip」近似：视觉等价，不是像素等价。
 */
@Component
export struct AppTopBar {
  @StorageProp('themeColorTextPrimary') themeColorTextPrimary: string = '#1B1C22';
  @StorageProp('themeColorTextSecondary') themeColorTextSecondary: string = '#2E3038';
  @StorageProp('themeColorTextTertiary') themeColorTextTertiary: string = '#6A6D77';
  @StorageProp('themeColorSurfacePrimary') themeColorSurfacePrimary: string = '#F5F6F8';
  @StorageProp('themeColorSurfaceSecondary') themeColorSurfaceSecondary: string = '#FFFFFF';
  @StorageProp('themeColorSurfaceTertiary') themeColorSurfaceTertiary: string = '#F0F1F5';
  @StorageProp('themeAppBackground') themeAppBackground: string = '';
  @StorageProp('themePureBlack') themePureBlack: boolean = false;
  /** 顶栏底色（含不透明度与模糊），由 `Index.publishTopBottomBarStyle()` 广播。 */
  @StorageProp('themeTopBarBackground') themeTopBarBackground: string = '';
  @StorageProp('themeTopBarBlurRadius') themeTopBarBlurRadius: number = 0;
  /**
   * 「启用渐变模糊」，对齐上游 `ThemeSettings.kt:38 enableProgressiveBlur`（默认 false）。
   * 上游在 `HazeStyle.kt:51-58` 里用它决定 haze 的 `HazeProgressive.verticalGradient(1f, 0f)`，
   * 即模糊强度自上而下线性衰减到 0；本地靠 `components/ProgressiveBackdrop.ets` 分带实现。
   */
  @StorageProp('themeEnableProgressiveBlur') themeEnableProgressiveBlur: boolean = false;
  /** 「使用折叠应用栏」：关掉后恒 64 高单行（上游 pinned 分支）。 */
  @StorageProp('themeUseFlexibleTopAppBar') themeUseFlexibleTopAppBar: boolean = true;
  /** 「顶栏按钮样式」五档，决定动作区的行高、间距与胶囊。 */
  @StorageProp('themeTopBarButtonStyle') themeTopBarButtonStyle: string = 'tonal';
  /** 「合并顶栏按钮」：为真且样式非 plain 时动作区包成一颗胶囊。 */
  @StorageProp('themeMergeTopBarActions') themeMergeTopBarActions: boolean = false;
  /**
   * 状态栏高度（vp）。打开全屏布局后内容画到状态栏底下，顶栏必须自己让出这一段，
   * 否则标题行会被状态栏文字压住。由 `Index` 读 `getWindowAvoidArea(TYPE_SYSTEM)` 后广播；
   * 阅读器页面自管状态栏显隐，那里广播 0。
   */
  @StorageProp('appTopInset') appTopInset: number = 0;

  @Prop title: string = '';
  /**
   * :368（批6，r360）标题逐字淡入的进度：
   * >= 999 表示「已到位」，按普通整段 `Text(this.title)` 渲染（其余所有页面都是这个值）；
   * 小于 999 时把标题拆成单字，第 index 个字在 `index < titleRevealStep` 时不透明。
   * 逐字间隔不靠定时器推 step，而是每个字各自挂 `.animation({ delay: index * 24 })`——
   * 一次状态变化就能让全部字符按错开的延迟依次亮起，比 i 个 setTimeout 干净得多。
   * 依据上游 BookshelfViewModel/UiUtils 的标题逐字显现，本地用隐式动画等价实现。
   */
  @Prop titleRevealStep: number = 999;
  /** 非空即「有副标题」：展开高从 112 变 136，大标题下多一行小字。 */
  @Prop subtitle: string = '';
  @Prop collapsed: boolean = false;
  /**
   * 连续折叠进度 0..1，由页面按滚动偏移算好后传入（对齐 M3 `collapsedFraction`）。
   * 传 -1（默认）表示「调用方没有连续进度」，此时退回 `collapsed` 布尔两态。
   */
  @Prop collapseFraction: number = -1;
  /** 是否有左侧导航按钮。没有时标题左起点 16，有则紧接按钮右缘（44 或 40）。 */
  @Prop hasNavigation: boolean = false;
  @BuilderParam navigationIcon: () => void = this.emptySlot;
  @BuilderParam actions: () => void = this.emptySlot;

  @Builder emptySlot() {}

  /**
   * 标题行本身。收起行与展开大标题字号不同，所以字号作为参数传进来，
   * 其余（字重、颜色、逐字淡入）两处一致。
   */
  @Builder
  private titleLine(fontSize: number) {
    if (this.titleRevealStep < 999) {
      Row() {
        ForEach(Array.from(this.title), (ch: string, index: number) => {
          Text(ch)
            .fontSize(fontSize)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.themeColorTextPrimary)
            .opacity(index < this.titleRevealStep ? 1 : 0)
            // 每个字自己带延迟：step 一次性跳到满值时，它们按 index*24ms 依次淡入。
            .animation({ duration: 160, delay: index * 24, curve: Curve.EaseOut })
        }, (ch: string, index: number) => `reveal_${index}_${ch}`)
      }
      // 单字都是 Text 且排成一行，Row 自己不会折行；超出部分交给 clip 裁掉（等价 maxLines(1)+省略）。
      .clip(true)
    } else {
      Text(this.title)
        .fontSize(fontSize)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.themeColorTextPrimary)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
  }

  private expandedHeight(): number {
    return this.subtitle.length > 0 ? TOP_BAR_EXPANDED_HEIGHT_SUBTITLE : TOP_BAR_EXPANDED_HEIGHT;
  }

  /**
   * 折叠进度 0..1，等价 M3 `TopAppBarState.collapsedFraction = heightOffset / heightOffsetLimit`
   * （AppBar.kt:2106-2110）。
   * 上游由滚动偏移连续驱动；本组件接收外部算好的 `collapseFraction`，
   * 收不到时退化为 `collapsed ? 1 : 0`（保持旧行为，避免未迁移页面视觉突变）。
   */
  private fraction(): number {
    const raw = this.collapseFraction >= 0 ? this.collapseFraction : (this.collapsed ? 1 : 0);
    return Math.min(1, Math.max(0, raw));
  }

  /** 下行（展开大标题）当前布局高度 = 满高 × (1 - fraction)，对齐 M3 的 layoutHeight 收缩。 */
  private currentExpandedBodyHeight(): number {
    return this.expandedBodyHeight() * (1 - this.fraction());
  }

  private totalHeight(): number {
    if (!this.themeUseFlexibleTopAppBar) { return TOP_BAR_COLLAPSED_HEIGHT; }
    return TOP_BAR_COLLAPSED_HEIGHT + this.currentExpandedBodyHeight();
  }

  private expandedBodyHeight(): number {
    return this.expandedHeight() - TOP_BAR_COLLAPSED_HEIGHT;
  }

  /**
   * 展开标题的底边距。
   * 上游 M3 是 `MediumTitleBottomPadding = 24.dp`（AppBar.kt:3611-3612），由布局按基线算：
   * `paddingFromBottom = 24 - (titleHeight - baseline)`，放不下时按 `maxLayoutHeight` 收敛。
   * 本地 Text 拿不到基线，改为「在剩余空间里留出 24 与可用高度的较小者」——
   * 展开态 48 高的下半区里标题约 36 高，剩 12，所以实际生效值是 12，与上游收敛结果同向。
   */
  private titleBottomPadding(): number {
    const body = this.expandedBodyHeight();
    const titleHeight = this.subtitle.length > 0 ? 56 : 36;
    return Math.max(0, Math.min(TOP_BAR_MEDIUM_TITLE_BOTTOM_PADDING, body - titleHeight));
  }

  /** 收起行标题透明度：M3 `TopTitleAlphaEasing.transform(collapsedFraction)`（AppBar.kt:2835）。 */
  private topTitleAlpha(): number {
    return topTitleAlphaEasing(this.fraction());
  }

  /** 展开行标题透明度：M3 `1f - collapsedFraction`（AppBar.kt:2836）。 */
  private bottomTitleAlpha(): number {
    return 1 - this.fraction();
  }

  private mergedCapsule(): boolean {
    return this.themeMergeTopBarActions && this.themeTopBarButtonStyle !== 'plain';
  }

  private actionsSpacing(): number {
    return this.mergedCapsule() ? 0 : topBarActionSpacing(this.themeTopBarButtonStyle);
  }

  /** 胶囊底色，对齐 TopBarButton.kt 的 TopBarActionsRow：tonal→surfaceContainerLow；玻璃两档→surfaceContainerHighest；outlined→透明。 */
  private capsuleBackground(): string {
    if (!this.mergedCapsule()) { return '#00000000'; }
    if (this.themeTopBarButtonStyle === 'outlined') { return '#00000000'; }
    if (this.themeAppBackground.length > 0) { return '#00000000'; }
    if (this.themeTopBarButtonStyle === 'glass' || this.themeTopBarButtonStyle === 'liquid') {
      return this.themePureBlack ? '#1C1C1C' : this.themeColorSurfaceTertiary;
    }
    return this.themePureBlack ? '#121212' : this.themeColorSurfaceSecondary;
  }

  build() {
    Stack() {
      // 模糊层独立成一层，放在内容之下：ArkUI 的 backdropBlur 采样的是「组件背后」，
      // 拆出来之后采样源仍是顶栏背后的页面内容，与原来挂在内容节点上等价；
      // 拆开是为了让「渐变模糊」能用多条不同半径的横带拼出强度梯度（见 ProgressiveBackdrop）。
      if (this.themeTopBarBlurRadius > 0) {
        if (this.themeEnableProgressiveBlur) {
          ProgressiveBackdrop({ blurRadius: this.themeTopBarBlurRadius })
        } else {
          Column().width('100%').height('100%').backdropBlur(this.themeTopBarBlurRadius)
        }
      }
      Column() {
        // 第一行：收起态标题 + 导航 + 动作。这一行在任何折叠状态下都在，只是标题透明度在变。
        Row() {
          if (this.hasNavigation) {
            Row() { this.navigationIcon() }.padding({ left: TOP_BAR_SIDE_PADDING })
          }
          Row() {
            this.titleLine(TOP_BAR_TITLE_COLLAPSED_SIZE)
          }
          .padding({ left: this.hasNavigation ? 0 : TOP_BAR_TITLE_START, right: TOP_BAR_SIDE_PADDING })
          // 收起行标题透明度：M3 走 TopTitleAlphaEasing(collapsedFraction)，不是布尔两态。
          // 折叠被关掉时这一行就是常驻标题，恒为 1。
          .opacity(!this.themeUseFlexibleTopAppBar ? 1 : this.topTitleAlpha())
          Blank()
          Row({ space: this.actionsSpacing() }) { this.actions() }
            .height(topBarButtonSize(this.themeTopBarButtonStyle))
            .borderRadius(topBarButtonSize(this.themeTopBarButtonStyle) / 2)
            .backgroundColor(this.capsuleBackground())
            .border({
              width: this.mergedCapsule() && this.themeTopBarButtonStyle === 'outlined' ? 1 : 0,
              color: this.themeColorTextTertiary
            })
            .clip(true)
        }
        .width('100%')
        .height(TOP_BAR_COLLAPSED_HEIGHT)
        // 右端留 16：这个 padding 放在外层 Row 上，不能放在动作 Row 上——
        // 放在动作 Row 上会被当作胶囊的内边距，胶囊会向右多出 16 宽。
        .padding({ right: TOP_BAR_ACTIONS_END })

        // 第二行：展开态大标题（+ 可选副标题）。导航与动作都不放，照 TwoRowsTopAppBar 的第二行。
        // M3 里这一行的布局高度 = maxLayoutHeight + heightOffset，随 collapsedFraction 连续收缩
        // （AppBar.kt:3123-3128 + 2920），所以这里高度也按比例收缩而不是布尔切换。
        if (this.themeUseFlexibleTopAppBar && this.currentExpandedBodyHeight() > 0) {
          Column() {
            Column() {
              this.titleLine(TOP_BAR_TITLE_EXPANDED_SIZE)
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)
            if (this.subtitle.length > 0) {
              Text(this.subtitle)
                .fontSize(TOP_BAR_SUBTITLE_SIZE)
                .fontColor(this.themeColorTextSecondary)
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
                .width('100%')
                .textAlign(TextAlign.Start)
            }
          }
          .width('100%')
          .height(this.currentExpandedBodyHeight())
          .justifyContent(FlexAlign.End)
          .padding({ left: TOP_BAR_TITLE_START, right: TOP_BAR_TITLE_START, bottom: this.titleBottomPadding() })
          .clip(true)
          // 展开行标题透明度：M3 `1f - collapsedFraction`。
          .opacity(this.bottomTitleAlpha())
        }
      }
      .width('100%')
      .height('100%')
      // 状态栏让位：内容整体下移 appTopInset，模糊层不受影响（它铺满整块）。
      .padding({ top: this.appTopInset })
    }
    .width('100%')
    // 高度加 appTopInset：多出来的这段就是状态栏让位，不给它的话两行会被压扁。
    .height(this.totalHeight() + this.appTopInset)
    .clip(true)
    .backgroundColor(this.themeTopBarBackground.length > 0 ? this.themeTopBarBackground
      : (this.themeAppBackground.length > 0 ? '#00000000'
        : (this.themePureBlack ? '#000000' : this.themeColorSurfacePrimary)))
  }
}

/**
 * 顶栏动作按钮。尺寸与底色跟「顶栏按钮样式」五档走，对齐上游 `TopBarButton.kt` 的 TopBarButton：
 * plain 40×40 透明底；tonal 36×36 有底；outlined 36×36 透明底 + 1dp 描边；
 * glass / liquid 用 surfaceContainerHighest 近似（本地没有这个 M3 键）。
 * 合并态下自身不画底（胶囊底由 AppTopBar 画），只在左边缘画一条分隔竖线。
 */
@Component
export struct TopBarButton {
  @StorageProp('themeColorTextPrimary') themeColorTextPrimary: string = '#1B1C22';
  @StorageProp('themeColorTextTertiary') themeColorTextTertiary: string = '#6A6D77';
  @StorageProp('themeColorSurfaceSecondary') themeColorSurfaceSecondary: string = '#FFFFFF';
  @StorageProp('themeColorSurfaceElevated') themeColorSurfaceElevated: string = '#FFFFFF';
  @StorageProp('themeAppBackground') themeAppBackground: string = '';
  @StorageProp('themePureBlack') themePureBlack: boolean = false;
  @StorageProp('themeTopBarButtonStyle') themeTopBarButtonStyle: string = 'tonal';
  @StorageProp('themeMergeTopBarActions') themeMergeTopBarActions: boolean = false;

  @Prop icon: AppGlyphName = 'more';
  /** 非空时覆盖图标颜色（用于「已启用」的强调态，例如精确匹配、筛选生效）。 */
  @Prop tint: string = '';
  /** 关闭态：透明度 0.38 且不响应点击（对齐上游 disabledContentColor）。 */
  @Prop disabled: boolean = false;
  /**
   * 合并态下是否画左侧分隔竖线；**动作行里第一个按钮传 false**。
   * 上游靠 `positionInParent().x > 0` 自动判断，ArkUI 拿不到稳定的布局后坐标，
   * 所以改成显式参数（与 `UiSection` 系列组件的 `showDivider` 同一套做法）。
   */
  @Prop showDivider: boolean = true;
  /**
   * 菜单模式：该按钮由外层 `bindMenu` 打开菜单。置 true 时组件内不注册 onClick，
   * 否则内层点击手势会抢掉 bindMenu 的点击，菜单弹不出来（实测结论）。
   */
  @Prop menuMode: boolean = false;
  /**
   * 无障碍文案，对齐上游 `TopBarActionButton(contentDescription = ...)`。
   * 上游每个动作按钮都带 contentDescription（`BookSourceDebugScreen.kt:79` 的「清空日志」、
   * `BookSourceEditScreen.kt:104` 的 debug_source、`:109` 的 more_menu），
   * 不传则读屏只能报出图标，故做成显式参数，文案由调用方按上游字符串填。
   */
  @Prop accessibilityLabel: string = '';
  onSelect: () => void = () => {};

  private merged(): boolean {
    return this.themeMergeTopBarActions && this.themeTopBarButtonStyle !== 'plain';
  }

  private buttonSize(): number {
    return topBarButtonSize(this.themeTopBarButtonStyle);
  }

  private iconSize(): number {
    return topBarIconSize(this.themeTopBarButtonStyle);
  }

  private contentColor(): string {
    return this.tint.length > 0 ? this.tint : this.themeColorTextPrimary;
  }

  /** 非合并态的按钮底色；合并态返回透明，底色由外层胶囊统一画。 */
  private containerColor(): string {
    if (this.merged()) { return '#00000000'; }
    const style = this.themeTopBarButtonStyle;
    if (style === 'plain' || style === 'outlined') { return '#00000000'; }
    if (this.themeAppBackground.length > 0) { return '#00000000'; }
    if (style === 'glass' || style === 'liquid') {
      return this.themePureBlack ? '#1C1C1C' : this.themeColorSurfaceElevated;
    }
    // tonal
    return this.themePureBlack ? '#121212' : this.themeColorSurfaceSecondary;
  }

  /** 按钮内容：合并态分隔竖线 + 图标，两种模式共用。 */
  @Builder buttonContent() {
    // 合并态的分隔竖线：高度 40%、纵向居中（对应上游 30%→70%）。
    if (this.merged() && this.showDivider) {
      Column()
        .width(1)
        .height(this.buttonSize() * 0.4)
        .backgroundColor(this.themeColorTextTertiary)
        .opacity(0.15)
        .position({ x: 0, y: this.buttonSize() * 0.3 })
    }
    AppGlyph({ name: this.icon, glyphSize: this.iconSize(), tint: this.contentColor() })
  }

  build() {
    if (this.menuMode) {
      // 不注册 onClick：bindMenu 的可点击节点落在自定义组件外层，内层 Stack 一旦 clickable
      // 就会抢走点击手势，菜单弹不出来（对照：未迁移发现页的原版 Stack 无 onClick，可正常弹出）。
      Stack({ alignContent: Alignment.Center }) { this.buttonContent() }
        .width(this.buttonSize())
        .height(this.buttonSize())
        .borderRadius(this.buttonSize() / 2)
        .backgroundColor(this.containerColor())
        .border({
          width: !this.merged() && this.themeTopBarButtonStyle === 'outlined' ? 1 : 0,
          color: this.themeColorTextTertiary
        })
        .opacity(this.disabled ? 0.38 : 1)
        .enabled(!this.disabled)
        .accessibilityText(this.accessibilityLabel)
    } else {
      Stack({ alignContent: Alignment.Center }) { this.buttonContent() }
        .width(this.buttonSize())
        .height(this.buttonSize())
        .borderRadius(this.buttonSize() / 2)
        .backgroundColor(this.containerColor())
        .border({
          width: !this.merged() && this.themeTopBarButtonStyle === 'outlined' ? 1 : 0,
          color: this.themeColorTextTertiary
        })
        .opacity(this.disabled ? 0.38 : 1)
        .enabled(!this.disabled)
        // 上游 `TopBarActionButton(contentDescription = ...)`（`TopBarButton.kt:335-380`）的
        // 文案挂在同一个 `TopBarButton` 上，与是否 menuMode 无关；这里原先只在 menuMode
        // 分支挂了 `.accessibilityText`，普通动作按钮漏掉，读屏只报图标。
        .accessibilityText(this.accessibilityLabel)
        // 按下缩放：按钮 36/40vp，LIGHT 默认 0.9 只有 3-4vp 位移，观感是「按下去」。
        .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.9 })
        .onClick(() => {
          if (!this.disabled) { this.onSelect(); }
        })
    }
  }
}

/** 顶栏左侧导航按钮。40×40 无底，图标取主题主文字色（上游 TopBarNavigationButton 的 onSurface）。 */
@Component
export struct TopBarBackButton {
  @StorageProp('themeColorTextPrimary') themeColorTextPrimary: string = '#1B1C22';
  onSelect: () => void = () => {};

  build() {
    Row() {
      Image($r('app.media.reader_back')).width(20).height(20).fillColor(this.themeColorTextPrimary)
    }
    .width(40).height(40).justifyContent(FlexAlign.Center).borderRadius(20)
    .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.9 })
    .onClick(() => this.onSelect())
    .accessibilityText('返回')
  }
}
