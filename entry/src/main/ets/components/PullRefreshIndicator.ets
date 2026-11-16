import { AppGlyph, AppGlyphName } from './AppGlyph';

/**
 * 下拉刷新指示器：对齐上游 M3 的 `PullToRefreshDefaults.LoadingIndicator`。
 *
 * 上游（app/src/main/java/io/legado/app/ui/widget/components/AppPullToRefresh.kt:97-115）
 * 用的是 Material3 标准指示器：`surfaceContainerHigh` 色的圆形容器 + 内部进度/箭头。
 * 本地 `Refresh` 默认画的是系统原生指示器（一圈细线圆环），观感与 M3 完全不同，所以自绘一个。
 *
 * 尺寸取 40vp（M3 的 LoadingIndicator 是 40.dp 圆形）。
 * `refresh.d.ts` 明确要求自定义内容必须有固定高度，否则高度会跟着下拉距离塌成 0，
 * 所以这里对 40×40 写死，不用百分比或 constraintSize。
 */
@Component
export struct PullRefreshIndicator {
  @StorageProp('themeColorSurfaceElevated') themeColorSurfaceElevated: string = '#FFFFFF';
  @StorageProp('themeColorSurfaceTertiary') themeColorSurfaceTertiary: string = '#1B1C22';
  @StorageProp('themeColorAccent') themeColorAccent: string = '#3F5BD9';
  @StorageProp('themeColorTextTertiary') themeColorTextTertiary: string = '#6A6D77';
  /** 已拉过触发阈值（松手会刷新）。 */
  @Prop armed: boolean = false;
  /** 正在刷新。 */
  @Prop refreshing: boolean = false;

  build() {
    Stack({ alignContent: Alignment.Center }) {
      if (this.refreshing) {
        // 刷新中：转圈。写法与 BookshelfPage 书卡的 LoadingProgress 一致。
        LoadingProgress().width(22).height(22).color(this.themeColorAccent)
      } else {
        // 未刷新：下拉未过阈值显示刷新图标，过了阈值换成对勾提示「松手就刷」。
        // 这两个名字都在 AppGlyphName 里，绘制分支见 AppGlyph.ets 的 profileCheck / profileRefresh。
        AppGlyph({
          name: this.armed ? 'profileCheck' : 'profileRefresh' as AppGlyphName,
          glyphSize: 20,
          tint: this.armed ? this.themeColorAccent : this.themeColorTextTertiary
        })
      }
    }
    .width(40).height(40)
    .borderRadius(20)
    // 容器用 surfaceContainerHigh（M3 的 LoadingIndicator 就是这个色），
    // 比页面底色高一档，下拉时能看出是一个浮在上面的圆片。
    .backgroundColor(this.themeColorSurfaceElevated)
    // 深色下与深色背景贴得太近，加一层极淡的描边把轮廓托出来。
    .border({ width: 1, color: this.themeColorSurfaceTertiary })
  }
}
