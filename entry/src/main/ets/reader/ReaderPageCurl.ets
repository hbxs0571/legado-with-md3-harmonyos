/**
 * 折页（仿真翻页）几何与绘制载体。
 *
 * 逐行对齐上游 `feature/reader/core/transition/PageCurlGeometry.kt`（243 行）：
 * 触点 → 角点 → 两条二次贝塞尔控制线 → 交点/顶点 → 背面镜像矩阵。
 * 数值细节（`.0001` / `.1` 退化回退、`start1` 越界后重算触点、`hypot`）全部照抄，
 * 不做「看起来更好」的改写——折页只要有一处偏差，收尾就会抖。
 */
import { drawing } from '@kit.ArkGraphics2D';

/** 折页用到的点，上游 `data class CurlPoint(x, y)`。 */
export class CurlPoint {
  x: number = 0;
  y: number = 0;

  constructor(x: number = 0, y: number = 0) {
    this.x = x;
    this.y = y;
  }

  /** 上游 `val isFinite`：任一坐标非有限值就算无效，整帧丢弃。 */
  isFinite(): boolean {
    return Number.isFinite(this.x) && Number.isFinite(this.y);
  }
}

/** 背面镜像矩阵的六个分量，上游 `data class CurlMirror`。 */
export class CurlMirror {
  scaleX: number = 1;
  skewX: number = 0;
  skewY: number = 0;
  scaleY: number = 1;
  translateX: number = 0;
  translateY: number = 0;
}

/** 一帧折页的全部几何量，上游 `data class PageCurlFrame`。 */
export class PageCurlFrame {
  touch: CurlPoint = new CurlPoint();
  corner: CurlPoint = new CurlPoint();
  control1: CurlPoint = new CurlPoint();
  control2: CurlPoint = new CurlPoint();
  start1: CurlPoint = new CurlPoint();
  start2: CurlPoint = new CurlPoint();
  end1: CurlPoint = new CurlPoint();
  end2: CurlPoint = new CurlPoint();
  vertex1: CurlPoint = new CurlPoint();
  vertex2: CurlPoint = new CurlPoint();
  degrees: number = 0;
  touchToCornerDistance: number = 0;
  mirror: CurlMirror = new CurlMirror();

  isValid(): boolean {
    return this.touch.isFinite() && this.corner.isFinite() && this.control1.isFinite()
      && this.control2.isFinite() && this.start1.isFinite() && this.start2.isFinite()
      && this.end1.isFinite() && this.end2.isFinite() && this.vertex1.isFinite()
      && this.vertex2.isFinite();
  }
}

/**
 * 折页三道阴影的峰值颜色。
 *
 * 上游注释：渐变结构与色相沿用原版 GradientDrawable（0xFF111111 / 0x80111111 / 0xB0333333），
 * 峰值 alpha 整体按约六成调轻——全不透明的折缝黑边是「阴影偏重」观感的主要来源。
 */
export class ReaderCurlVisualPolicy {
  static readonly BACK_SHADOW_DARK_ARGB: number = 0x99111111;
  static readonly FRONT_SHADOW_DARK_ARGB: number = 0x4D111111;
  static readonly FOLDER_SHADOW_DARK_ARGB: number = 0x73333333;
}

/** 触点到折页量的换算，照上游 `object ReaderCurlTouchPolicy`。 */
export class ReaderCurlTouchPolicy {
  /**
   * 收尾下限占基准的比例。
   *
   * 上游注释：下限跟着基准走而不是写死 90ms——写死会让快速挡的短距离收尾
   * 慢得不成比例（90/240=37%，而 90/540 只有 17%），换挡就不再是「整体快慢」。
   */
  private static readonly MIN_SETTLE_FRACTION: number = 0.25;
  private static readonly DRAG_SNAP_FRACTION: number = 0.04;

  /** 仿真折页收尾时长：按剩余折页距离折算，且不低于基准的 1/4。 */
  static settleDurationMillis(currentX: number, targetX: number, pageWidth: number,
    baseDurationMillis: number): number {
    if (pageWidth <= 0 || baseDurationMillis <= 0) {
      return 0;
    }
    const distance = Math.abs(targetX - currentX);
    if (distance < 0.01) {
      return 0;
    }
    // 上游注释：一两个像素的末段距离过去会折算成 0ms，页面在 Compose 来得及
    // 呈现最后一帧折页之前就提交了。
    const minDurationMillis = Math.max(1,
      Math.trunc(baseDurationMillis * ReaderCurlTouchPolicy.MIN_SETTLE_FRACTION));
    return Math.max(minDurationMillis,
      Math.trunc(baseDurationMillis * distance / pageWidth));
  }

  /**
   * 横向拖动捕获后，让第一帧可见折页避开它的锁定角点。
   *
   * 上游注释：这样手指还停在页边时贝塞尔控制线不会塌陷，而是产生一个确定的「吸附」。
   */
  static dragX(isPrevious: boolean, rawX: number, pageWidth: number): number {
    if (pageWidth <= 0) {
      return rawX;
    }
    const inset = Math.max(pageWidth * ReaderCurlTouchPolicy.DRAG_SNAP_FRACTION, 1);
    if (isPrevious) {
      return Math.min(pageWidth, Math.max(inset, rawX));
    }
    return Math.min(pageWidth - inset, Math.max(0, rawX));
  }

  /** 把第一帧安全折页从角点插值出来，进页不会「弹」进来。 */
  static revealX(isPrevious: boolean, targetX: number, pageWidth: number,
    revealProgress: number): number {
    if (pageWidth <= 0) {
      return targetX;
    }
    const cornerX = isPrevious ? 0 : pageWidth;
    const progress = Math.min(1, Math.max(0, revealProgress));
    return cornerX + (targetX - cornerX) * progress;
  }

  /** 点击/按键翻页的起始触点 x。 */
  static programmaticX(isPrevious: boolean, pageWidth: number): number {
    return isPrevious ? 0 : pageWidth * 0.9;
  }

  /** 收尾终点 x：翻页成立就送出屏幕，不成立就退回原位。 */
  static settledX(isPrevious: boolean, committed: boolean, pageWidth: number): number {
    if (isPrevious) {
      return committed ? pageWidth : -pageWidth;
    }
    return committed ? -pageWidth : pageWidth;
  }

  /** 角点 y：PREVIOUS 固定在下边，NEXT 按触点落在上半还是下半决定。 */
  static cornerY(isPrevious: boolean, capturedY: number, pageHeight: number): number {
    if (isPrevious) {
      return pageHeight;
    }
    return capturedY <= pageHeight / 2 ? 0 : pageHeight;
  }

  /** 收尾终点角点 y：趋近 1 而不是 0，避免角点正好落在角上让控制线退化。 */
  static settledY(cornerY: number, pageHeight: number): number {
    return cornerY <= pageHeight / 2 ? 1 : pageHeight;
  }

  /** 拖动时的触点 y：PREVIOUS 恒在下边，NEXT 按捕获点落在哪一段决定。 */
  static dragY(isPrevious: boolean, capturedY: number, currentY: number, pageHeight: number): number {
    if (pageHeight <= 0) {
      return currentY;
    }
    if (isPrevious) {
      return pageHeight;
    }
    if (capturedY > pageHeight / 3 && capturedY < pageHeight / 2) {
      return 1;
    }
    if (capturedY >= pageHeight / 2 && capturedY < pageHeight * 2 / 3) {
      return pageHeight;
    }
    return currentY;
  }

  /** 点击翻页的起始触点 y。 */
  static programmaticY(isPrevious: boolean, sourceY: number, pageHeight: number): number {
    if (isPrevious) {
      return pageHeight;
    }
    return sourceY > pageHeight / 2 ? pageHeight * 0.9 : 1;
  }
}

/** 折页几何计算，照上游 `object PageCurlGeometry`。 */
export class PageCurlGeometry {
  /** 两条直线的交点；平行或任一方向退化成点返回 undefined，整帧作废。 */
  private static cross(p1: CurlPoint, p2: CurlPoint, p3: CurlPoint,
    p4: CurlPoint): CurlPoint | undefined {
    const dx1 = p2.x - p1.x;
    const dx2 = p4.x - p3.x;
    if (Math.abs(dx1) < 0.0001 || Math.abs(dx2) < 0.0001) {
      return undefined;
    }
    const a1 = (p2.y - p1.y) / dx1;
    const b1 = p1.y - a1 * p1.x;
    const a2 = (p4.y - p3.y) / dx2;
    const b2 = p3.y - a2 * p3.x;
    if (Math.abs(a1 - a2) < 0.0001) {
      return undefined;
    }
    const x = (b2 - b1) / (a1 - a2);
    const point = new CurlPoint(x, a1 * x + b1);
    return point.isFinite() ? point : undefined;
  }

  /** 二次贝塞尔中点 = (start + 2*control + end) / 4，上游 vertex1/vertex2。 */
  private static bezierMiddle(start: CurlPoint, control: CurlPoint, end: CurlPoint): CurlPoint {
    return new CurlPoint((start.x + 2 * control.x + end.x) / 4,
      (2 * control.y + start.y + end.y) / 4);
  }

  /** 由角点与触点求两条控制线的控制点，上游内嵌 `controls(point)`。 */
  private static controlsX(point: CurlPoint, corner: CurlPoint): number {
    const middleX = (point.x + corner.x) / 2;
    const middleY = (point.y + corner.y) / 2;
    let dx = corner.x - middleX;
    if (Math.abs(dx) < 0.0001) {
      dx = 0.0001;
    }
    return middleX - (corner.y - middleY) * (corner.y - middleY) / dx;
  }

  private static controlsY(point: CurlPoint, corner: CurlPoint): number {
    const middleX = (point.x + corner.x) / 2;
    const middleY = (point.y + corner.y) / 2;
    let dy = corner.y - middleY;
    if (Math.abs(dy) < 0.0001) {
      dy = 0.1;
    }
    return middleY - (corner.x - middleX) * (corner.x - middleX) / dy;
  }

  /**
   * 算一帧折页。
   *
   * `lockedCorner` 由调用方按方向锁死（程序化翻页要固定角点，否则触点每帧变化
   * 会让角点在上下边之间跳）。
   */
  static calculate(width: number, height: number, inputX: number, inputY: number,
    lockedCorner: CurlPoint | undefined): PageCurlFrame | undefined {
    if (width <= 0 || height <= 0) {
      return undefined;
    }
    let corner: CurlPoint;
    if (lockedCorner !== undefined) {
      corner = new CurlPoint(lockedCorner.x, lockedCorner.y);
    } else {
      corner = new CurlPoint(inputX <= width / 2 ? 0 : width, inputY <= height / 2 ? 0 : height);
    }
    // 上游注释：收尾动画把触点送出页外让折页连同阴影滑出屏幕；页外触点保持原值
    // 走原始贝塞尔计算，页内仍收敛到 .1 边界避免 0 值退化。
    let touchX = inputX;
    if (inputX >= 0 && inputX <= width) {
      touchX = Math.min(width - 0.1, Math.max(0.1, inputX));
    }
    let touchY = Math.min(height - 0.1, Math.max(0.1, inputY));
    let touch = new CurlPoint(touchX, touchY);
    let control1 = new CurlPoint(PageCurlGeometry.controlsX(touch, corner), corner.y);
    let control2 = new CurlPoint(corner.x, PageCurlGeometry.controlsY(touch, corner));
    let start1 = new CurlPoint(control1.x - (corner.x - control1.x) / 2, corner.y);
    if (touch.x > 0 && touch.x < width && (start1.x < 0 || start1.x > width)) {
      if (start1.x < 0) {
        // 上游就是 width - start1.x（start1.x 为负时等于 width + |start1.x|），照抄
        start1 = new CurlPoint(width - start1.x, start1.y);
      }
      const f1 = Math.max(0.1, Math.abs(corner.x - touch.x));
      const f2 = width * f1 / start1.x;
      const adjustedX = Math.abs(corner.x - f2);
      const f3 = Math.abs(corner.x - adjustedX) * Math.abs(corner.y - touch.y) / f1;
      touch = new CurlPoint(adjustedX, Math.abs(corner.y - f3));
      control1 = new CurlPoint(PageCurlGeometry.controlsX(touch, corner), corner.y);
      control2 = new CurlPoint(corner.x, PageCurlGeometry.controlsY(touch, corner));
      start1 = new CurlPoint(control1.x - (corner.x - control1.x) / 2, corner.y);
    }
    const start2 = new CurlPoint(corner.x,
      control2.y - (corner.y - control2.y) / 2);
    const end1 = PageCurlGeometry.cross(touch, control1, start1, start2);
    if (end1 === undefined) {
      return undefined;
    }
    const end2 = PageCurlGeometry.cross(touch, control2, start1, start2);
    if (end2 === undefined) {
      return undefined;
    }
    const frame = new PageCurlFrame();
    frame.touch = touch;
    frame.corner = corner;
    frame.control1 = control1;
    frame.control2 = control2;
    frame.start1 = start1;
    frame.start2 = start2;
    frame.end1 = end1;
    frame.end2 = end2;
    frame.vertex1 = PageCurlGeometry.bezierMiddle(start1, control1, end1);
    frame.vertex2 = PageCurlGeometry.bezierMiddle(start2, control2, end2);
    frame.touchToCornerDistance = Math.sqrt(
      (touch.x - corner.x) * (touch.x - corner.x)
      + (touch.y - corner.y) * (touch.y - corner.y));
    frame.degrees = Math.atan2(control1.x - corner.x, control2.y - corner.y) * 180 / Math.PI;
    // 背面镜像：以 control1 为原点把页面翻过来，distance 兜底 .0001 避免除零。
    const distance = Math.max(0.0001, Math.sqrt(
      (corner.x - control1.x) * (corner.x - control1.x)
      + (control2.y - corner.y) * (control2.y - corner.y)));
    const f8 = (corner.x - control1.x) / distance;
    const f9 = (control2.y - corner.y) / distance;
    const mirror = new CurlMirror();
    mirror.scaleX = 1 - 2 * f9 * f9;
    mirror.skewX = 2 * f8 * f9;
    mirror.skewY = 2 * f8 * f9;
    mirror.scaleY = 1 - 2 * f8 * f8;
    mirror.translateX = control1.x - (mirror.scaleX * control1.x + mirror.skewX * control1.y);
    mirror.translateY = control1.y - (mirror.skewX * control1.x + mirror.scaleY * control1.y);
    frame.mirror = mirror;
    return frame.isValid() ? frame : undefined;
  }
}

/**
 * 折页每帧复用的 Path 与 Matrix。
 *
 * 上游注释：折页是 60/120fps 热路径，逐帧新建 5 个 Path 只会给 GC 添压力；
 * 这里同样用 `rewind()` 复用缓冲（与上游 `Path.rebuild` 等价）。
 */
export class ReaderCurlRenderPaths {
  front: drawing.Path = new drawing.Path();
  reveal: drawing.Path = new drawing.Path();
  back: drawing.Path = new drawing.Path();
  frontShadowHorizontal: drawing.Path = new drawing.Path();
  frontShadowVertical: drawing.Path = new drawing.Path();
  mirror: drawing.Matrix = new drawing.Matrix();

  /** 角点在左下或右上时，阴影与控制点的相对方向要反过来（上游同名判断）。 */
  static isReverse(frame: PageCurlFrame, width: number, height: number): boolean {
    return (frame.corner.x === 0 && frame.corner.y === height)
      || (frame.corner.x === width && frame.corner.y === 0);
  }

  update(frame: PageCurlFrame, width: number, height: number): ReaderCurlRenderPaths {
    const reverse = ReaderCurlRenderPaths.isReverse(frame, width, height);
    const angle = reverse
      ? Math.PI / 4 - Math.atan2(frame.control1.y - frame.touch.y, frame.touch.x - frame.control1.x)
      : Math.PI / 4 - Math.atan2(frame.touch.y - frame.control1.y, frame.touch.x - frame.control1.x);
    const shadowX = frame.touch.x + 25 * 1.414 * Math.cos(angle);
    const shadowY = frame.touch.y + (reverse ? 1 : -1) * 25 * 1.414 * Math.sin(angle);

    this.front.rewind();
    this.front.moveTo(frame.start1.x, frame.start1.y);
    this.front.quadTo(frame.control1.x, frame.control1.y, frame.end1.x, frame.end1.y);
    this.front.lineTo(frame.touch.x, frame.touch.y);
    this.front.lineTo(frame.end2.x, frame.end2.y);
    this.front.quadTo(frame.control2.x, frame.control2.y, frame.start2.x, frame.start2.y);
    this.front.lineTo(frame.corner.x, frame.corner.y);
    this.front.close();

    this.reveal.rewind();
    this.reveal.moveTo(frame.start1.x, frame.start1.y);
    this.reveal.lineTo(frame.vertex1.x, frame.vertex1.y);
    this.reveal.lineTo(frame.vertex2.x, frame.vertex2.y);
    this.reveal.lineTo(frame.start2.x, frame.start2.y);
    this.reveal.lineTo(frame.corner.x, frame.corner.y);
    this.reveal.close();

    this.back.rewind();
    this.back.moveTo(frame.vertex2.x, frame.vertex2.y);
    this.back.lineTo(frame.vertex1.x, frame.vertex1.y);
    this.back.lineTo(frame.end1.x, frame.end1.y);
    this.back.lineTo(frame.touch.x, frame.touch.y);
    this.back.lineTo(frame.end2.x, frame.end2.y);
    this.back.close();

    this.frontShadowHorizontal.rewind();
    this.frontShadowHorizontal.moveTo(shadowX, shadowY);
    this.frontShadowHorizontal.lineTo(frame.touch.x, frame.touch.y);
    this.frontShadowHorizontal.lineTo(frame.control1.x, frame.control1.y);
    this.frontShadowHorizontal.lineTo(frame.start1.x, frame.start1.y);
    this.frontShadowHorizontal.close();

    this.frontShadowVertical.rewind();
    this.frontShadowVertical.moveTo(shadowX, shadowY);
    this.frontShadowVertical.lineTo(frame.touch.x, frame.touch.y);
    this.frontShadowVertical.lineTo(frame.control2.x, frame.control2.y);
    this.frontShadowVertical.lineTo(frame.start2.x, frame.start2.y);
    this.frontShadowVertical.close();

    // Matrix.setMatrix 的 9 元素顺序：scaleX, skewX, translateX, skewY, scaleY, translateY, persp0, persp1, persp2
    this.mirror.setMatrix([
      frame.mirror.scaleX, frame.mirror.skewX, frame.mirror.translateX,
      frame.mirror.skewY, frame.mirror.scaleY, frame.mirror.translateY,
      0, 0, 1
    ]);
    return this;
  }
}
