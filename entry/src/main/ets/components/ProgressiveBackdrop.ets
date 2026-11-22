/**
 * 垂直渐变模糊层，对齐上游 `ui/theme/HazeStyle.kt:47-61` 的
 * `progressive(HazeProgressive.verticalGradient(startIntensity = 1f, endIntensity = 0f))`。
 *
 * 上游靠 haze 库的 progressive 参数在一次采样里做强度梯度；ArkUI 的 `backdropBlur` 只有
 * 单一半径，没有强度渐变参数，所以这里把同一块区域切成 `bands` 条等高横带，每带各挂
 * 一个递减的 `backdropBlur` 半径——采样源仍是「组件背后」，与上游同源，只是强度被量化成
 * 若干级。这是任务书 12.3C 允许的「Stack 内分段模糊」，不是拿近似糊过去：
 * 每一条带都是真实的背景模糊，只是半径按位置递减。
 *
 * 该组件本身不画任何底色，底色仍由使用方（如顶栏）用自己的容器色叠在上面，
 * 与上游 `HazeLegado.custom(containerColor = ...)` 的叠法一致。
 */
@Component
export struct ProgressiveBackdrop {
  /** 顶端的模糊半径（vp）。底端恒为 0，中间线性递减。 */
  @Prop blurRadius: number = 0;
  /**
   * 分带数量。带上限是为了控制渲染开销：每条带都是一次独立的背景采样。
   * 8 条在 112vp 高的顶栏上每带 14vp，肉眼已看不出台阶。
   */
  @Prop bands: number = 8;

  /** 第 index 条带的半径：顶端满值，底端 0，线性递减。 */
  private bandRadius(index: number): number {
    if (this.bands <= 1) {
      return this.blurRadius;
    }
    const intensity = 1 - index / (this.bands - 1);
    return this.blurRadius * intensity;
  }

  build() {
    Column() {
      ForEach(Array.from({ length: this.bands }, (_unused: undefined, index: number) => index),
        (index: number) => {
          Column()
            .width('100%')
            .layoutWeight(1)
            .backdropBlur(this.bandRadius(index))
        },
        (index: number) => `progressive_band_${index}`)
    }
    .width('100%')
    .height('100%')
    // 分带之间不能有间隙，否则会露出未模糊的缝。
    .justifyContent(FlexAlign.Start)
  }
}
