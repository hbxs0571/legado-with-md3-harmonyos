/**
 * 阅读域底部弹层的统一外壳，对应上游
 * ui/widget/components/modalBottomSheet/AppModalBottomSheet.kt 的 Material 默认分支：
 * - scrim：上游 ModalBottomSheet 自带，业务不设色；这里默认 #66000000，传空串不画。
 * - 抓手：BottomSheetDefaults.DragHandle(color = onSurfaceVariant)，对应 rsetHandle；
 *   上游有 8 处本地面板带抓手，其余面板本来没有，靠 showHandle 区分，不凭空加。
 * - 顶部圆角：MaterialExpressiveTheme(shapes = Shapes()) 的 extraLarge = 28vp，全仓统一。
 * - 高度：上游 heightIn(max = 容器高 * 0.8f)。panelHeight 传 'auto' 时不设 height，
 *   改用 constraintSize({maxHeight:'80%'}) 交给内容撑开并以屏幕 80% 为上限（批 0 探针 1 已验）。
 * - 内容内边距：上游 contentPaddingEnabled 时 start/end/bottom 各 16vp。本地各面板
 *   内容区大多已自带 16vp 左右 padding，外壳默认不再叠加（否则双倍缩进）；确需统一
 *   内边距的面板可传 contentPadding=true。
 *
 * 注意：对齐上游不等于改造成 bindSheet——阅读页是自绘 Canvas + 自绘浮层，
 * bindSheet 是页面级平台浮层，两者叠一起返回手势/遮挡顺序都要重做，超出本任务范围。
 */
@Component
export struct ReaderSheetShell {
  @StorageProp('rsetHandle') rsetHandle: string = '#6A6D77';
  @StorageProp('themeColorSurfaceTertiary') themeColorSurfaceTertiary: string = '#1A1B21';
  /** 遮罩色，空串表示不画遮罩。 */
  @Prop scrimColor: string = '#66000000';
  /** 面板底色，空串表示用 surfaceContainer（对应 themeColorSurfaceTertiary）。 */
  @Prop panelColor: string = '';
  @Prop panelWidth: string = '100%';
  /** 面板高度；'auto' 表示内容驱动不设 height，批 4 会用到。 */
  @Prop panelHeight: string = '70%';
  /** 是否画抓手，默认画；本地 4 处面板原本无抓手，迁移时传 false。 */
  @Prop showHandle: boolean = true;
  /** 是否由外壳补 start/end/bottom 16vp 内边距，默认关闭（各面板内容已自带）。 */
  @Prop contentPadding: boolean = false;
  /** backdropBlur 强度，0 表示不加模糊（朗读域玻璃底面板传 30）。 */
  @Prop blurRadius: number = 0;
  onDismiss: () => void = () => {};
  @BuilderParam content: () => void = this.emptyContent;

  @Builder
  emptyContent() {
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      if (this.scrimColor.length > 0) {
        Column().width('100%').height('100%').backgroundColor(this.scrimColor)
          .onClick(() => this.onDismiss())
      }
      Column() {
        if (this.showHandle) {
          // 抓手：32x4，圆角保持本地现值 4（上游 DragHandle 精确圆角未取证，见交付说明）。
          Row().width(32).height(4).backgroundColor(this.rsetHandle).borderRadius(4)
            .alignSelf(ItemAlign.Center).margin({ top: 10, bottom: 14 })
        }
        this.content()
      }
      .width(this.panelWidth)
      // 'auto'：不写 height，靠内容撑开；constraintSize 上限 80% 对齐上游 heightIn(max=容器高*0.8)。
      .height(this.panelHeight === 'auto' ? undefined : this.panelHeight)
      .constraintSize(this.panelHeight === 'auto' ? { maxHeight: '80%' } : {})
      .padding(this.contentPadding ? { left: 16, right: 16, bottom: 16 } : {})
      .backgroundColor(this.panelColor.length > 0 ? this.panelColor : this.themeColorSurfaceTertiary)
      .backdropBlur(this.blurRadius)
      .borderRadius({ topLeft: 28, topRight: 28 })
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%').height('100%')
  }
}
