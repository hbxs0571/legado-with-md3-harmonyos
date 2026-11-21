import { curves } from '@kit.ArkUI';

/**
 * 下拉刷新指示器：对齐上游 M3 `PullToRefreshDefaults.LoadingIndicator`。
 *
 * 上游（app/src/main/java/io/legado/app/ui/widget/components/AppPullToRefresh.kt:104-110）
 * 用的是 Material3 Expressive 的 LoadingIndicator。它的形状来源是
 * `LoadingIndicatorDefaults.DeterminateIndicatorPolygons`（androidx.compose.material3）：
 *
 *   listOf(
 *     MaterialShapes.Circle.transformed(rotateZ(360f / 20)),   // 圆，预先转 18°
 *     MaterialShapes.SoftBurst,                                 // 软爆裂
 *   )
 *
 * 也就是：**在「圆」和「软爆裂（SoftBurst）」之间连续变形**，同时整体在旋转。
 * SoftBurst 是圆润的八瓣轮廓，不是尖齿齿轮，中间实心没有孔；圆预转 18° 是为了
 * 让变形时顶点对得更齐。
 *
 * 本地没有 RoundedPolygon 插值 API，所以用 `Canvas` 自己画轮廓：
 *   - 轮廓取径向函数 `r(θ) = R - depth * (R - R0) * (1 - cos(corners*θ)) / 2`。
 *     `depth = 0` 时 r 恒等于 R —— 正圆；`depth = 1` 时 r 在 R 与 R0 之间余弦起伏
 *     —— 圆润八瓣，正是 SoftBurst 的观感；中间值就是平滑 morph。
 *     用连续函数而不是「交替内外半径折线」，是因为折线画出来是尖齿（齿轮），
 *     而 SoftBurst 的瓣是圆头的。
 *   - 旋转：下拉时由下拉距离驱动；刷新中由定时器匀速转。
 *
 * 为什么用 Canvas 而不是别的：
 *   - `Path` 组件的 `commands` 坐标按 px 解释、`width/height` 却按 vp，22 单位视口
 *     画在 22vp 里只剩不到 1/4 且偏到左上角（实测过）。
 *   - `Image` 只能给一张静止的图，变不了形。
 *
 * 重绘的驱动方式（踩过坑，不要改回去）：
 *   一开始用常驻 `setInterval(16ms)` 轮询重绘，结果**拖拽全程指示器纹丝不动**，
 *   松手后 500ms 内才补上几帧变化——下拉手势占着主线程，定时器回调排不上队。
 *   现在改成：下拉阶段由 `@Watch('pullDistance')` 在每次 `onOffsetChange` 更新属性时
 *   直接重绘（数据驱动、跟手）；只有 `refreshing` 期间才启动定时器做自转。
 *
 * 尺寸取 40vp（M3 LoadingIndicator 是 40dp）。`refresh.d.ts:109-112` 明确要求自定义
 * 内容必须有固定高度，否则高度会跟着下拉距离塌成 0，所以这里写死 40×40。
 */
@Component
export struct PullRefreshIndicator {
  @StorageProp('themeColorSurfaceElevated') themeColorSurfaceElevated: string = '#FFFFFF';
  @StorageProp('themeColorSurfaceTertiary') themeColorSurfaceTertiary: string = '#1B1C22';
  @StorageProp('themeColorAccent') themeColorAccent: string = '#3F5BD9';
  @StorageProp('themeColorTextTertiary') themeColorTextTertiary: string = '#6A6D77';

  /** 已拉过触发阈值（松手会刷新）。 */
  @Prop @Watch('onPullStateChanged') armed: boolean = false;
  /** 正在刷新。 */
  @Prop @Watch('onRefreshStateChanged') refreshing: boolean = false;
  /** 当前下拉距离（vp），由 Refresh.onOffsetChange 传进来，驱动形变程度与跟手旋转。
   *  不叫 offset：`offset` 是 CustomComponent 自带属性名，重名会编译报错。 */
  @Prop @Watch('onPullStateChanged') pullDistance: number = 0;

  private settings: RenderingContextSettings = new RenderingContextSettings(true);
  private ctx: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings);
  /** 刷新中的自转角度来源（毫秒），只用于 Canvas 重绘，不进状态系统。 */
  private spinClock: number = 0;
  private timerId: number = -1;

  aboutToDisappear(): void {
    this.stopSpin();
  }

  /** 下拉相关属性变化：立刻按新状态重绘一帧（不依赖定时器）。 */
  onPullStateChanged(): void {
    this.render();
  }

  /** 刷新状态切换：进入刷新启动自转定时器，退出则停表并重绘。 */
  onRefreshStateChanged(): void {
    if (this.refreshing) {
      this.spinClock = 0;
      this.startSpin();
    } else {
      this.stopSpin();
    }
    this.render();
  }

  private startSpin(): void {
    this.stopSpin();
    this.timerId = setInterval(() => {
      this.spinClock += 16;
      if (this.spinClock > 1000000) { this.spinClock = 0; }
      this.render();
    }, 16);
  }

  private stopSpin(): void {
    if (this.timerId >= 0) {
      clearInterval(this.timerId);
      this.timerId = -1;
    }
  }

  /** 容器：过阈值时略微放大（上游是形状 morph 到位，本地用尺寸一起提示）。 */
  private containerScale(): number {
    if (this.refreshing) { return 1; }
    return this.armed ? 1.06 : 1;
  }

  /**
   * 按当前状态重算轮廓并绘制。
   *
   * depth 就是「圆 ↔ 软爆裂」的插值进度：0 = 正圆，1 = 完整的 SoftBurst。
   */
  private render(): void {
    const size: number = 22;
    const cx: number = size / 2;
    const cy: number = size / 2;
    const corners: number = 8;         // SoftBurst 的瓣数
    const outerR: number = 9.6;        // 瓣尖半径
    const innerR: number = 6.6;        // 瓣谷半径（只有 depth=1 时才用到）
    const baseAngle: number = Math.PI / 10;  // 上游 Circle 预转 360/20 = 18°

    let depth: number = 0;
    let angle: number = baseAngle;
    if (this.refreshing) {
      const seconds: number = this.spinClock / 1000;
      // 变形周期 1.6s：sin 从 -1 到 1，映射到 0..1，来回在圆与软爆裂之间走。
      depth = (Math.sin(seconds * Math.PI * 2 / 1.6) + 1) / 2;
      // 自转 1.4s 一圈，叠在 baseAngle 上。
      angle = baseAngle + seconds * Math.PI * 2 / 1.4;
    } else {
      const drag: number = this.pullDistance > 0 ? this.pullDistance : 0;
      // 归一化进度：与 Refresh.maxPullDownDistance(120) 同尺度，拖到底才算 1。
      const t: number = Math.min(drag / 120, 1);
      // 形变取 t 的平方（缓入）。
      // 起因是实测：指示器从 Refresh 容器顶边往下滑，前面几十 vp 整个藏在顶栏后面，
      // 等它露出来时如果形变已过半，用户看到的就是一个不动的图标——连续抓帧里
      // 露头那几帧形状几乎一样，确认了这一点。平方让前半程还基本是正圆，
      // 形变集中发生在「已经看得见」的后半程，肉眼能跟到圆→八瓣的整个过程。
      depth = t * t;
      // 跟手旋转：整段拖动转 300°。
      // 角度用线性的 t 而不是 depth：depth 是 t²（形变缓入），如果旋转也吃缓入，
      // 前几十 vp 几乎不动，用户会觉得「拖了半天没反应」。旋转线性、形变缓入，
      // 这样一往下拉立刻能看到它在转，继续拉才逐渐变成八瓣。
      // 8 瓣形状有 45° 的旋转对称性，所以「转了多少度」和「看起来转了多少」不是一回事：
      // 取 45° 的整数倍（180° / 270° / 360°）时，松手前的终点与起点长得一模一样，
      // 中间只是瓣位来回晃，实测看起来像没转（90° 那版就是这样）；
      // 取 300°（45° 的 6.67 倍）让瓣位在整段行程里连续推进 6 轮多、终点与起点错开 30°，
      // 每 vp 约 2.5°，拖拽帧间隔（≈110ms）下每帧十来度，是连续的旋转而不是抖动。
      angle = baseAngle + t * Math.PI * 5 / 3;
    }

    const accent: boolean = this.armed || this.refreshing;
    this.ctx.clearRect(0, 0, size, size);
    this.ctx.fillStyle = accent ? this.themeColorAccent : this.themeColorTextTertiary;
    this.ctx.beginPath();

    // 轮廓采样：360 个点足够平滑，且远小于一帧的绘制预算。
    const steps: number = 360;
    // 旋转必须作用在「点坐标」上，不能加进取样角 theta。
    // 踩过的坑：原来写 `theta = angle + i*Δ`、`wave = (1 - cos(corners*theta))/2`，
    // 半径和位置用的是同一个 theta，theta 起点偏移只是把闭合曲线换个参数起点重画一遍，
    // 曲线本身一模一样 —— 实测连续抓帧里 8θ 相位恒为 0，用户看到的就是「完全不旋转」。
    const cosA: number = Math.cos(angle);
    const sinA: number = Math.sin(angle);
    for (let i = 0; i <= steps; i++) {
      const theta: number = i * Math.PI * 2 / steps;
      // (1 - cos(corners*theta)) / 2 在 0..1 之间以 corners 为周期起伏：
      // depth=0 时半径恒为 outerR（正圆）；depth=1 时在 outerR / innerR 之间走（软爆裂）。
      const wave: number = (1 - Math.cos(corners * theta)) / 2;
      const radius: number = outerR - depth * (outerR - innerR) * wave;
      const px: number = radius * Math.cos(theta);
      const py: number = radius * Math.sin(theta);
      // 绕 Center 整体旋转 angle 弧度。
      const x: number = cx + px * cosA - py * sinA;
      const y: number = cy + px * sinA + py * cosA;
      if (i === 0) {
        this.ctx.moveTo(x, y);
      } else {
        this.ctx.lineTo(x, y);
      }
    }
    this.ctx.closePath();
    this.ctx.fill();
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      Canvas(this.ctx)
        .width(22).height(22)
        .onReady(() => {
          // 组件插入时立刻画一帧，避免出现空白圆片。
          this.render();
        })
    }
    .width(40).height(40)
    .borderRadius(20)
    // 容器用比页面底色高一档的 surface（M3 LoadingIndicator 的容器色）。
    .backgroundColor(this.themeColorSurfaceElevated)
    // 再加一层极淡描边托轮廓。
    .border({ width: 1, color: this.themeColorSurfaceTertiary })
    .scale({ x: this.containerScale(), y: this.containerScale() })
    .animation({ curve: curves.springMotion(0.3, 0.9) })
    // 内容层被 position 钉住之后会盖住指示器（实测只在内容顶边之上露出 9vp 一条），
    // 所以这里必须把指示器抬到内容之上。Refresh 的 builder 与内容是同层兄弟节点。
    .zIndex(9999)
  }
}
