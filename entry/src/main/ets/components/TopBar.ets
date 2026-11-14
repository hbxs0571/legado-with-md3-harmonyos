import { AppGlyph, AppGlyphName } from './AppGlyph';

// 全部来自 M3 官方 token，不要凭手感改。
// 出处：androidx compose material3 的 tokens/AppBarSmallTokens.kt、tokens/AppBarMediumFlexibleTokens.kt、tokens/TypeScaleTokens.kt，
// 以及 AppBar.kt 的 TopAppBarHorizontalPadding / TopAppBarTitleInset。

/** 收起行高，AppBarSmallTokens.ContainerHeight。 */
export const TOP_BAR_COLLAPSED_HEIGHT: number = 64;
/** 展开高（无副标题），AppBarMediumFlexibleTokens.ContainerHeight。 */
export const TOP_BAR_EXPANDED_HEIGHT: number = 112;
/** 展开高（有副标题），AppBarMediumFlexibleTokens.LargeContainerHeight。 */
export const TOP_BAR_EXPANDED_HEIGHT_SUBTITLE: number = 136;
/** 展开标题字号，TypeScaleTokens.HeadlineMedium。 */
export const TOP_BAR_TITLE_EXPANDED_SIZE: number = 28;
/** 收起标题字号，TypeScaleTokens.TitleLarge。 */
export const TOP_BAR_TITLE_COLLAPSED_SIZE: number = 22;
/** 展开副标题字号，TypeScaleTokens.LabelLarge。 */
export const TOP_BAR_SUBTITLE_SIZE: number = 14;
/** 顶栏左右最小内边距，AppBar.kt 的 TopAppBarHorizontalPadding。 */
export const TOP_BAR_SIDE_PADDING: number = 4;
/** 无导航按钮时标题的左起点，= max(12, 0) + 4。 */
export const TOP_BAR_TITLE_START: number = 16;
/** 动作区右端距屏幕边，= 4（布局）+ 12（上游外层 Box）。 */
export const TOP_BAR_ACTIONS_END: number = 16;

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
  /** 「使用折叠应用栏」：关掉后恒 64 高单行（上游 pinned 分支）。 */
  @StorageProp('themeUseFlexibleTopAppBar') themeUseFlexibleTopAppBar: boolean = true;
  /** 「顶栏按钮样式」五档，决定动作区的行高、间距与胶囊。 */
  @StorageProp('themeTopBarButtonStyle') themeTopBarButtonStyle: string = 'tonal';
  /** 「合并顶栏按钮」：为真且样式非 plain 时动作区包成一颗胶囊。 */
  @StorageProp('themeMergeTopBarActions') themeMergeTopBarActions: boolean = false;

  @Prop title: string = '';
  /** 非空即「有副标题」：展开高从 112 变 136，大标题下多一行小字。 */
  @Prop subtitle: string = '';
  @Prop collapsed: boolean = false;
  /** 是否有左侧导航按钮。没有时标题左起点 16，有则紧接按钮右缘（44 或 40）。 */
  @Prop hasNavigation: boolean = false;
  @BuilderParam navigationIcon: () => void = this.emptySlot;
  @BuilderParam actions: () => void = this.emptySlot;

  @Builder emptySlot() {}

  private expandedHeight(): number {
    return this.subtitle.length > 0 ? TOP_BAR_EXPANDED_HEIGHT_SUBTITLE : TOP_BAR_EXPANDED_HEIGHT;
  }

  private totalHeight(): number {
    if (!this.themeUseFlexibleTopAppBar) { return TOP_BAR_COLLAPSED_HEIGHT; }
    return this.collapsed ? TOP_BAR_COLLAPSED_HEIGHT : this.expandedHeight();
  }

  private expandedBodyHeight(): number {
    return this.expandedHeight() - TOP_BAR_COLLAPSED_HEIGHT;
  }

  /**
   * 展开标题的底边距。
   * M3 是 MediumTitleBottomPadding = 24，但那个值配的是两行按 collapsedFraction 联动插值；
   * 本地布尔折叠要保证 112 / 136 的固定高度内不裁字，按可用空间收敛：
   * 无副标题（展开区 48，标题约 36）取 8；有副标题（展开区 72，标题+副标题约 56）取 12。
   */
  private titleBottomPadding(): number {
    return this.subtitle.length > 0 ? 12 : 8;
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
    Column() {
      // 第一行：收起态标题 + 导航 + 动作。这一行在任何折叠状态下都在，只是标题透明度在变。
      Row() {
        if (this.hasNavigation) {
          Row() { this.navigationIcon() }.padding({ left: TOP_BAR_SIDE_PADDING })
        }
        Text(this.title)
          .fontSize(TOP_BAR_TITLE_COLLAPSED_SIZE)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.themeColorTextPrimary)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .padding({ left: this.hasNavigation ? 0 : TOP_BAR_TITLE_START, right: TOP_BAR_SIDE_PADDING })
          // 折叠被关掉时这一行就是常驻标题，不需要淡入淡出。
          .opacity(!this.themeUseFlexibleTopAppBar || this.collapsed ? 1 : 0)
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
      if (this.themeUseFlexibleTopAppBar) {
        Column() {
          Text(this.title)
            .fontSize(TOP_BAR_TITLE_EXPANDED_SIZE)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.themeColorTextPrimary)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')
            .textAlign(TextAlign.Start)
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
        .height(this.expandedBodyHeight())
        .justifyContent(FlexAlign.End)
        .padding({ left: TOP_BAR_TITLE_START, right: TOP_BAR_TITLE_START, bottom: this.titleBottomPadding() })
        .opacity(this.collapsed ? 0 : 1)
      }
    }
    .width('100%')
    .height(this.totalHeight())
    .clip(true)
    .backgroundColor(this.themeTopBarBackground.length > 0 ? this.themeTopBarBackground
      : (this.themeAppBackground.length > 0 ? '#00000000'
        : (this.themePureBlack ? '#000000' : this.themeColorSurfacePrimary)))
    .backdropBlur(this.themeTopBarBlurRadius)
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
    .onClick(() => this.onSelect())
  }
}
