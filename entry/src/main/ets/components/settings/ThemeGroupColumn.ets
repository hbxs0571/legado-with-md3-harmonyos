import { ThemeItemDivider } from '../ThemeItemDivider';
import { LABEL_LARGE } from '../typography/TypographyTokens';

/**
 * 设置分组容器，对齐上游 `ui/widget/components/SplicedColumnGroup.kt:42-138`。
 *
 * 上游这个组件同时承担四件事，本组件逐条承接：
 * ① 圆角三来源（`SplicedColumnGroup.kt:50-54`）：`disableSplicedColumnGroupCornerRadius` → 0、
 *    `overrideBaseCardCornerRadius` → `baseCardCornerRadius`、否则 16。这三来源在本地已由
 *    `data/ThemeCardStyle.ets:136-139 resolveGroupCornerRadius()` 算好并广播成 `themeGroupRadius`，
 *    本组件只读该键——分组卡片必须读 `themeGroupRadius` 而不是 `themeCardRadius`，
 *    否则「关闭设置分组圆角」开关管不到分组。
 * ② 边框默认不画（`SplicedColumnGroup.kt:55-68`）：只有 `overrideBaseCardBorder` 为真才有
 *    `BorderStroke`。本地 `resolveCardBorderWidth(snapshot, 0)` 在开关关闭时返回 0，
 *    `border({ width: 0 })` 即不画，语义等价，所以这里直接读 `themeCardBorderWidth`。
 * ③ 外层 `Column(padding(top = 8.dp, bottom = 8.dp))`（`:81`）与组标题
 *    `AdaptiveTitle(modifier = padding(start = 16.dp, bottom = 8.dp))`（`:83-86`）。
 *    标题字号取 `labelLarge`、色取 primary（`title/SmallTitle.kt:26-31`）。
 * ④ 组内 `verticalArrangement = Arrangement.spacedBy(2.dp)`（`:129`），本地用 `Column({ space: 2 })`。
 *
 * 卡片水平留白：上游水平 16 来自 `LazyColumn` 的 `adaptiveContentPadding`（`AdaptivePadding.kt:65`），
 * 本地页面没有水平内边距，所以由卡片自己 `margin({ left: 16, right: 16 })` 承担，
 * 标题 `padding({ left: 16 })` 与之左缘对齐。
 *
 * 与上游的差异：上游 `Box(...clip(RoundedCornerShape(cornerRadius)))` 内是一层
 * `Spacer(appContainerBackground(Large))` 负责容器背景图，本地用 `backgroundImage` 直接画在卡片上
 * 并加 `clip(true)` 把子内容裁进圆角，视觉等价（背景图铺满整卡、子内容不越界）。
 */
@Component
export struct ThemeGroupColumn {
  @StorageProp('themeColorSurfaceSecondary') themeColorSurfaceSecondary: string = '#FFFFFF';
  @StorageProp('themeColorAccent') themeColorAccent: string = '#3F5BD9';
  /** 分组圆角：由 `resolveGroupCornerRadius()` 广播，只有它响应「关闭设置分组圆角」。 */
  @StorageProp('themeGroupRadius') themeGroupRadius: number = 16;
  @StorageProp('themeCardBorderWidth') themeCardBorderWidth: number = 0;
  @StorageProp('themeCardBorderColor') themeCardBorderColor: string = '#6A6D77';
  @StorageProp('themeCardBackground') themeCardBackground: string = '';
  @StorageProp('themeContainerBackground') themeContainerBackground: string = '';

  /** 组标题。上游第 2 段与「恢复默认」段不传 title，这里同样传空串。 */
  @Prop title: string = '';

  @BuilderParam content: () => void = this.emptyContent;

  @Builder
  emptyContent() {
  }

  build() {
    Column() {
      if (this.title.length > 0) {
        Text(this.title)
          .fontSize(LABEL_LARGE)
          .fontColor(this.themeColorAccent)
          .alignSelf(ItemAlign.Start)
          .padding({ left: 16, bottom: 8 })
      }
      Column({ space: 2 }) {
        this.content();
      }
      .width('calc(100% - 32vp)')
      .margin({ left: 16, right: 16 })
      .backgroundColor(this.themeCardBackground.length > 0 ? this.themeCardBackground : this.themeColorSurfaceSecondary)
      .borderRadius(this.themeGroupRadius)
      .border({ width: this.themeCardBorderWidth, color: this.themeCardBorderColor })
      .backgroundImage(
        this.themeContainerBackground.length > 0
          ? 'file://' + this.themeContainerBackground
          : $r('app.media.transparent_pixel'),
        ImageRepeat.NoRepeat
      )
      .clip(true)
    }
    .width('100%')
    .padding({ top: 8, bottom: 8 })
  }
}

/**
 * 分组内的一个条目，负责它**前面**那条分隔线。
 *
 * 对齐上游 `SplicedColumnGroup.kt:149-162 SettingItemWithDivider`：先判
 * `enableItemDivider && currentIndex() > 0` 再画分隔线，然后才是内容——
 * 也就是「首项不画线，其余每项前面画一条」。
 *
 * 上游靠 `SplicedColumnGroupState.currentIndex` 自增来知道当前是第几项；
 * ArkUI 没有 `CompositionLocal`（全仓 `@Provide`/`@Consume` 零命中），容器无法感知
 * 子项序号，所以由调用点用 `first` 显式声明「我是不是本组第一个渲染出来的条目」。
 * 用布尔而不是序号，是因为条件渲染段（如 `if (this.appFontExpanded)`）会让序号算不准，
 * 而「是不是首项」在写法上始终确定。
 *
 * 是否真的画线仍由 `ThemeItemDivider` 自己读 `themeDividerWidth > 0` 决定，
 * 即「显示分隔线」开关关闭时这里画出来的也是空节点，与上游 `SettingItemDivider.kt:23`
 * 的 `if (!themeSettings.enableItemDivider) return` 一致。
 */
@Component
export struct ThemeGroupItem {
  /** 是否为本组第一个条目；为真时它前面不画分隔线。 */
  @Prop first: boolean = false;

  @BuilderParam content: () => void = this.emptyContent;

  @Builder
  emptyContent() {
  }

  build() {
    Column() {
      if (!this.first) {
        ThemeItemDivider()
      }
      this.content();
    }
    .width('100%')
  }
}
