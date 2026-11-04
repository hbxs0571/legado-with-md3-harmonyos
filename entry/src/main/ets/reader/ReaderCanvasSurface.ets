import { text, drawing, common2D } from '@kit.ArkGraphics2D';
import { image } from '@kit.ImageKit';
import { LocalReaderLine, LocalReaderLineItem, LocalReaderPage } from '../pages/LocalReaderPaginator';
import {
  CurlPoint, PageCurlFrame, PageCurlGeometry, ReaderCurlRenderPaths, ReaderCurlTouchPolicy,
  ReaderCurlVisualPolicy
} from './ReaderPageCurl';
import {
  isNinePatchSource, ReaderNineSliceLayout, ReaderTextBackgroundImage, ReaderTextBackgroundRun
} from './ReaderTextBackground';

/**
 * 画布正文渲染层（阶段 A）。
 *
 * 对齐上游 feature/reader/ReaderCanvasSurface.kt：
 * - 页面窗口（previous / current / next / nextPlus）而不是单页；
 * - 逐行逐元素绘制（paragraph.paint / drawImageRect），不再生成 Span 组件树；
 * - 转场按 ReaderPageTransition.kt 的 transforms() 计算每页位移与 z 序；
 * - 没有当前页就什么都不画（上游 `val current = pages.current ?: return`），
 *   绝不回落到「整章连续滚动」那套排版。
 *
 * 单位口径：进入画布的一切坐标都是物理像素（px）。Paragraph.layoutSync / paint /
 * TextStyle.fontSize / Run.getPositions 全按 px，而分页器按 vp 计算，所以由调用方
 * 用 vp2px / fp2px 换算好再塞进来，画布层不做 vp 换算。
 */

// ---------------------------------------------------------------------------
// 转场模型（照抄 ReaderPageTransition.kt）
// ---------------------------------------------------------------------------

export enum ReaderTransitionMode {
  COVER = 0,
  SLIDE = 1,
  SIMULATION = 2,
  SCROLL = 3,
  FADE = 4,
  NONE = 5
}

export enum ReaderTransitionDirection {
  NONE = 0,
  PREVIOUS = 1,
  NEXT = 2
}

/** `fromPageAnim(value: Int)`：0 覆盖 / 1 滑动 / 2 仿真 / 3 滚动 / 4 淡入 / 其他 无。 */
export function readerTransitionModeFromPageAnim(value: number): ReaderTransitionMode {
  if (value === 0) {
    return ReaderTransitionMode.COVER;
  }
  if (value === 1) {
    return ReaderTransitionMode.SLIDE;
  }
  if (value === 2) {
    return ReaderTransitionMode.SIMULATION;
  }
  if (value === 3) {
    return ReaderTransitionMode.SCROLL;
  }
  if (value === 4) {
    return ReaderTransitionMode.FADE;
  }
  return ReaderTransitionMode.NONE;
}

/** `data class ReaderPageTransform(translationX, translationY, alpha)`，长度单位 px。 */
export class ReaderPageTransform {
  translationX: number = 0;
  translationY: number = 0;
  alpha: number = 1;
}

/** `data class ReaderTransitionTransforms(previous, current, next, currentOnTop)`。 */
export class ReaderTransitionTransforms {
  previous: ReaderPageTransform = new ReaderPageTransform();
  current: ReaderPageTransform = new ReaderPageTransform();
  next: ReaderPageTransform = new ReaderPageTransform();
  currentOnTop: boolean = false;
  /**
   * 上游用 `previous == null` / `next == null` 表示「这一页本回合不参与绘制」。
   * 本地 transform 是必填对象，所以用这两个标记保留同一语义 —— 否则「无转场」时
   * 邻页会以位移 0 的身份盖在 current 上，画出错误的页。
   */
  drawsPrevious: boolean = false;
  drawsNext: boolean = false;
}

/** `data class ReaderPageTransition(direction, offsetPx, pageExtentPx, dragging)`。 */
export class ReaderPageTransition {
  direction: ReaderTransitionDirection = ReaderTransitionDirection.NONE;
  offsetPx: number = 0;
  pageExtentPx: number = 0;
  dragging: boolean = false;

  /** `progress = if (pageExtentPx <= 0f) 0f else (abs(offsetPx) / pageExtentPx).coerceIn(0f, 1f)`。 */
  progress(): number {
    if (this.pageExtentPx <= 0) {
      return 0;
    }
    const ratio = Math.abs(this.offsetPx) / this.pageExtentPx;
    return Math.min(1, Math.max(0, ratio));
  }

  clone(): ReaderPageTransition {
    const next = new ReaderPageTransition();
    next.direction = this.direction;
    next.offsetPx = this.offsetPx;
    next.pageExtentPx = this.pageExtentPx;
    next.dragging = this.dragging;
    return next;
  }
}

/** `data class ReaderTransitionDecision(targetOffsetPx, commit)`。 */
export class ReaderTransitionDecision {
  targetOffsetPx: number = 0;
  commit: boolean = false;
}

/** 拖动方向在 touch-slop 处锁定后不再改变（`ReaderHorizontalDrag.capture`）。 */
export function captureReaderDragDirection(totalDeltaPx: number): ReaderTransitionDirection {
  if (totalDeltaPx > 0) {
    return ReaderTransitionDirection.PREVIOUS;
  }
  if (totalDeltaPx < 0) {
    return ReaderTransitionDirection.NEXT;
  }
  return ReaderTransitionDirection.NONE;
}

/**
 * `object ReaderPageTransitionPolicy`：拖动钳制、松手判定、时长折算、transforms()。
 * 常量全部来自 ReaderPageTransition.kt / ReaderPageTurnSpeed.kt，不要改。
 */
export class ReaderPageTransitionPolicy {
  static readonly COMMIT_PROGRESS: number = 0.35;
  static readonly FLING_VELOCITY_PX_PER_SECOND: number = 900;
  static readonly BASE_DURATION_MILLIS: number = 360;
  /** 淡入转场松手判定阈值只有 10%（上游 ReaderCanvasSurface.kt:1457 的 `if (fade) 0.1f`）。 */
  static readonly FADE_COMMIT_PROGRESS: number = 0.1;
  /** 覆盖转场尾部阴影：宽 36dp、色 0x30111111（上游 ReaderCoverShadowPolicy）。 */
  static readonly COVER_SHADOW_WIDTH_DP: number = 36;
  static readonly COVER_SHADOW_ARGB: number = 0x30111111;

  /** FADE 取整段基准时长，其余按剩余距离缩放（`settleDurationMillis`）。 */
  static settleDurationMillis(mode: ReaderTransitionMode, currentOffsetPx: number, targetOffsetPx: number,
    pageExtentPx: number, baseDurationMillis: number): number {
    if (mode === ReaderTransitionMode.FADE) {
      return baseDurationMillis;
    }
    if (pageExtentPx <= 0) {
      return 0;
    }
    const remaining = Math.abs(targetOffsetPx - currentOffsetPx) / pageExtentPx;
    const scaled = Math.trunc(baseDurationMillis * remaining);
    return Math.min(baseDurationMillis, Math.max(0, scaled));
  }

  /** 拖动期位移：方向锁定时按可用方向钳制；不可翻页时恒为 0 且 dragging=false。 */
  static drag(direction: ReaderTransitionDirection, deltaPx: number, pageExtentPx: number,
    hasPrevious: boolean, hasNext: boolean): ReaderPageTransition {
    const result = new ReaderPageTransition();
    result.direction = direction;
    result.pageExtentPx = pageExtentPx;
    let available = false;
    if (direction === ReaderTransitionDirection.PREVIOUS && hasPrevious) {
      available = true;
      result.offsetPx = Math.min(pageExtentPx, Math.max(0, deltaPx));
    } else if (direction === ReaderTransitionDirection.NEXT && hasNext) {
      available = true;
      result.offsetPx = Math.min(0, Math.max(-pageExtentPx, deltaPx));
    }
    if (!available) {
      result.offsetPx = 0;
      result.dragging = false;
      result.direction = ReaderTransitionDirection.NONE;
      return result;
    }
    result.dragging = result.offsetPx !== 0;
    return result;
  }

  /**
   * 松手判定（`release`）：
   * `commit = !cancelled && dragging && (movingForward ?: (progress >= 0.35 || velocityCommits))`。
   * 上游 `movingForward` 只在最后一段拖动方向明确时才有值，否则回落到位移/速度阈值。
   */
  static release(transition: ReaderPageTransition, velocityPxPerSecond: number,
    movingForward?: boolean, cancelled: boolean = false,
    commitProgress: number = ReaderPageTransitionPolicy.COMMIT_PROGRESS): ReaderTransitionDecision {
    const decision = new ReaderTransitionDecision();
    if (transition.direction === ReaderTransitionDirection.NONE) {
      return decision;
    }
    let velocityCommits = false;
    if (transition.direction === ReaderTransitionDirection.PREVIOUS) {
      velocityCommits = velocityPxPerSecond >= ReaderPageTransitionPolicy.FLING_VELOCITY_PX_PER_SECOND;
    } else if (transition.direction === ReaderTransitionDirection.NEXT) {
      velocityCommits = velocityPxPerSecond <= -ReaderPageTransitionPolicy.FLING_VELOCITY_PX_PER_SECOND;
    }
    const commitByDistance = movingForward !== undefined
      ? movingForward
      : (transition.progress() >= commitProgress || velocityCommits);
    decision.commit = !cancelled && transition.dragging && commitByDistance;
    if (decision.commit) {
      decision.targetOffsetPx = transition.direction === ReaderTransitionDirection.PREVIOUS
        ? transition.pageExtentPx
        : -transition.pageExtentPx;
    } else {
      decision.targetOffsetPx = 0;
    }
    return decision;
  }

  /**
   * `transforms(mode)`：阶段 A 只落地 COVER，其余分支先按上游语义写全，
   * 但 SLIDE / FADE / 折页 / 滚动在阶段 B 才接到手势与绘制。
   * 上游用 `previous/next == null` 表示「本回合不画这一页」，这里用 drawsPrevious/drawsNext 等价表达。
   */
  static transforms(mode: ReaderTransitionMode, transition: ReaderPageTransition,
    pageWidthPx: number): ReaderTransitionTransforms {
    const out = new ReaderTransitionTransforms();
    if (transition.direction === ReaderTransitionDirection.NONE) {
      // 上游 null 分支：只画 current，邻页一个都不参与（否则邻页位移 0 会盖在 current 上）
      return out;
    }
    const progress = transition.progress();
    const width = pageWidthPx;
    const offset = transition.offsetPx;
    if (transition.direction === ReaderTransitionDirection.PREVIOUS) {
      if (mode === ReaderTransitionMode.FADE) {
        out.previous.alpha = progress;
        out.drawsPrevious = true;
      } else if (mode === ReaderTransitionMode.COVER) {
        out.previous.translationX = -width + offset;
        out.drawsPrevious = true;
      } else if (mode === ReaderTransitionMode.SLIDE) {
        out.previous.translationX = -width + offset;
        out.current.translationX = offset;
        out.drawsPrevious = true;
      }
      return out;
    }
    // NEXT
    if (mode === ReaderTransitionMode.FADE) {
      out.next.alpha = progress;
      out.drawsNext = true;
    } else if (mode === ReaderTransitionMode.COVER) {
      // 旧页盖在上面滑出，新页位移 0 就在原位 —— 屏幕任何一帧都不会空。
      out.current.translationX = offset;
      out.currentOnTop = true;
      out.drawsNext = true;
    } else if (mode === ReaderTransitionMode.SLIDE) {
      out.current.translationX = offset;
      out.next.translationX = width + offset;
      out.currentOnTop = true;
      out.drawsNext = true;
    }
    return out;
  }
}

// ---------------------------------------------------------------------------
// 连续滚动（照抄 ReaderScrollState.kt）
// ---------------------------------------------------------------------------

export enum ReaderScrollCrossing {
  NONE = 0,
  PREVIOUS = 1,
  NEXT = 2
}

export class ReaderScrollResult {
  offsetPx: number = 0;
  crossing: ReaderScrollCrossing = ReaderScrollCrossing.NONE;
  hitBoundary: boolean = false;
}

/** 一行的纵向区间（滚动坐标系，已含 stackOffset）。 */
export class ReaderScrollLine {
  top: number = 0;
  bottom: number = 0;
}

export class ReaderScrollPolicy {
  /**
   * 滚动模式的下一页/上一页步距：滚到只剩一行，而不是整屏。
   *
   * 上游 `ReaderScrollPolicy.pageStep`：NEXT 取最远可见行的顶边、PREVIOUS 取最近
   * 可见行的底边，钳进 [0, viewport]；为 0（整屏都被同一行占满）时退回整屏。
   */
  static pageStep(lines: ReaderScrollLine[], contentTopPx: number, contentBottomPx: number,
    isPrevious: boolean, viewportExtentPx: number): number {
    const viewport = viewportExtentPx > 0 ? viewportExtentPx : 1;
    let maxTop = -Number.MAX_VALUE;
    let minBottom = Number.MAX_VALUE;
    let visible = 0;
    for (const line of lines) {
      if (line.bottom <= contentTopPx || line.top >= contentBottomPx) {
        continue;
      }
      visible = visible + 1;
      if (line.top > maxTop) {
        maxTop = line.top;
      }
      if (line.bottom < minBottom) {
        minBottom = line.bottom;
      }
    }
    // 可见区里没有正文（整页是图或空白）：退化成整屏
    if (visible === 0) {
      return isPrevious ? viewport : -viewport;
    }
    const raw = isPrevious
      ? viewport - (minBottom - contentTopPx)
      : maxTop - contentTopPx;
    const distance = Math.max(0, Math.min(viewport, raw));
    const effective = distance > 0 ? distance : viewport;
    return isPrevious ? effective : -effective;
  }

  /** 步进时长按位移折算（上游 stepDurationMillis，线性缓动）。 */
  static stepDurationMillis(distancePx: number, viewportExtentPx: number,
    animationSpeedMillis: number): number {
    if (viewportExtentPx <= 0) {
      return animationSpeedMillis;
    }
    const duration = animationSpeedMillis * Math.abs(distancePx) / viewportExtentPx;
    return Math.max(1, Math.trunc(duration));
  }

  /**
   * 把一次滚动位移落到偏移上，越过页边界时返回 crossing 让调用方换窗口。
   * 上游 `ReaderScrollPolicy.apply` 逐分支照抄，含「章末不够一屏时钳回」的兜底。
   */
  static apply(offsetPx: number, deltaPx: number, previousExtentPx: number,
    currentExtentPx: number, viewportExtentPx: number, hasPrevious: boolean,
    hasNext: boolean): ReaderScrollResult {
    const result = new ReaderScrollResult();
    if (currentExtentPx <= 0) {
      result.offsetPx = 0;
      return result;
    }
    const next = offsetPx + deltaPx;
    if (next > 0) {
      if (hasPrevious && previousExtentPx > 0) {
        result.offsetPx = next - previousExtentPx;
        result.crossing = ReaderScrollCrossing.PREVIOUS;
        return result;
      }
      result.offsetPx = 0;
      result.hitBoundary = true;
      return result;
    }
    if (!hasNext && next < 0 && next + currentExtentPx < viewportExtentPx) {
      result.offsetPx = Math.min(0, viewportExtentPx - currentExtentPx);
      result.hitBoundary = true;
      return result;
    }
    if (next < -currentExtentPx) {
      if (hasNext) {
        result.offsetPx = next + currentExtentPx;
        result.crossing = ReaderScrollCrossing.NEXT;
        return result;
      }
      result.offsetPx = Math.min(0, viewportExtentPx - currentExtentPx);
      result.hitBoundary = true;
      return result;
    }
    result.offsetPx = next;
    return result;
  }
}

/**
 * 抬手后的滚动惯性（上游 `ReaderCanvasSurface.kt:1414-1452` 的
 * `Animatable(0f).animateDecay(velocity, scrollDecay)`）。
 *
 * 上游用的是 Compose 的 spline-based decay（`rememberSplineBasedDecay`，
 * 见 `feature/reader/ReaderCanvasSurface.kt:17`/`:261`），**源码无显式摩擦常数**——
 * 摩擦系数随设备 density 实时由 Compose 的 spline 曲线算出，无法逐位对齐。
 * 本地自定的 `DECAY_RATE_PER_SECOND = 3.3` / `DURATION_MILLIS = 1200` 是经验值，
 * 只保证同形（本质都是指数衰减：v(t) = v0·e^(-λt)，总位移 v0/λ），
 * 不追求与上游数值一致。
 * ArkUI 没有 animateDecay，这里把同一条曲线拆成「总位移 + 剩余比例」两个纯函数，
 * 由调用方按帧驱动，保证首帧速度与手指抬起速度连续、末端自然停住。
 */
export class ReaderScrollDecay {
  /** 衰减率（1/s）：取值让 2000vp/s 的甩动大约滑 600vp，与 Android 手感接近。 */
  static readonly DECAY_RATE_PER_SECOND: number = 3.3;
  /** 惯性动画的总时长：到这个时刻残余速度已不足首帧的 2%。 */
  static readonly DURATION_MILLIS: number = 1200;

  /** 给定首帧速度，整段惯性会滑过的距离（带符号）。 */
  static totalDistance(velocityPxPerSecond: number): number {
    const rate = ReaderScrollDecay.DECAY_RATE_PER_SECOND;
    const total = ReaderScrollDecay.DURATION_MILLIS / 1000;
    return velocityPxPerSecond / rate * (1 - Math.exp(-rate * total));
  }

  /** 第 elapsedMillis 毫秒时已经滑过的距离（带符号）。 */
  static distanceAt(velocityPxPerSecond: number, elapsedMillis: number): number {
    const rate = ReaderScrollDecay.DECAY_RATE_PER_SECOND;
    const elapsed = Math.max(0, Math.min(ReaderScrollDecay.DURATION_MILLIS, elapsedMillis)) / 1000;
    return velocityPxPerSecond / rate * (1 - Math.exp(-rate * elapsed));
  }
}

// ---------------------------------------------------------------------------
// 页面窗口（照抄 ReaderPage.kt 的 ReaderPageWindow / ReaderPageNavigator.window）
// ---------------------------------------------------------------------------

export class ReaderCanvasPage {
  page: LocalReaderPage;
  pageIndex: number;

  constructor(page: LocalReaderPage, pageIndex: number) {
    this.page = page;
    this.pageIndex = pageIndex;
  }
}

export class ReaderCanvasWindow {
  previous: ReaderCanvasPage | undefined = undefined;
  current: ReaderCanvasPage | undefined = undefined;
  next: ReaderCanvasPage | undefined = undefined;
  nextPlus: ReaderCanvasPage | undefined = undefined;

  /** `ReaderPageNavigator.window(pages, pageIndex)`：一次给出相邻四页。 */
  static of(pages: LocalReaderPage[], pageIndex: number): ReaderCanvasWindow {
    const window = new ReaderCanvasWindow();
    if (pageIndex < 0 || pageIndex >= pages.length) {
      return window;
    }
    window.current = new ReaderCanvasPage(pages[pageIndex], pageIndex);
    if (pageIndex > 0) {
      window.previous = new ReaderCanvasPage(pages[pageIndex - 1], pageIndex - 1);
    }
    if (pageIndex + 1 < pages.length) {
      window.next = new ReaderCanvasPage(pages[pageIndex + 1], pageIndex + 1);
    }
    if (pageIndex + 2 < pages.length) {
      window.nextPlus = new ReaderCanvasPage(pages[pageIndex + 2], pageIndex + 2);
    }
    return window;
  }

  /** 预取用：窗口里所有非空页。 */
  all(): ReaderCanvasPage[] {
    const list: ReaderCanvasPage[] = [];
    if (this.previous !== undefined) {
      list.push(this.previous);
    }
    if (this.current !== undefined) {
      list.push(this.current);
    }
    if (this.next !== undefined) {
      list.push(this.next);
    }
    if (this.nextPlus !== undefined) {
      list.push(this.nextPlus);
    }
    return list;
  }
}

// ---------------------------------------------------------------------------
// 绘制输入
// ---------------------------------------------------------------------------

/** 版面几何，全部 px。列宽、正文宽高来自 ReaderPage 的既有布局计算（vp → px）。 */
export class ReaderCanvasLayout {
  /** 正文区左边缘（含 padding 与刘海内缩已算掉的列起点）。 */
  originXpx: number = 0;
  /** 正文区上边缘。 */
  originYpx: number = 0;
  bodyWidthPx: number = 0;
  bodyHeightPx: number = 0;
  columnCount: number = 1;
  columnStridePx: number = 0;
  /** 底部对齐的逐行位移（vp 的对齐值已换算成 px）。单列时用这一项。 */
  bottomJustifyGapPx: number = 0;
  /**
   * 逐列的底部对齐位移（px）。双页模式两列的剩余高度不同，上游 `justifyColumnBottom()`
   * 是按列各算一份的，所以这里存一份数组；为空时回落到 `bottomJustifyGapPx`。
   */
  bottomJustifyGapByColumn: number[] = [];
  /**
   * vp → px 的比例（等于 `vp2px(1)`）。
   * 分页器（LocalReaderPaginator）产出的行高、行距、字宽、图片尺寸全是 vp，
   * 而画布 context 与 Paragraph 一律按 px，所以这些量在绘制时必须乘上它。
   * 只作用于 vp 量：本类里已带 Px 后缀的字段与 style 里的 xPx 字段都已是 px，不要再乘。
   */
  vpScale: number = 1;
  viewportWidthPx: number = 0;
  viewportHeightPx: number = 0;
}

/** 正文样式，全部 px。 */
export class ReaderCanvasStyle {
  colorArgb: number = 0xFF000000;
  fontFamilies: string[] = [];
  fontSizePx: number = 16;
  /** 100..900，绘制时映射成 text.FontWeight 枚举。 */
  fontWeight: number = 400;
  italic: boolean = false;
  letterSpacingPx: number = 0;
  underline: boolean = false;
  underlineColorArgb: number = 0xFF000000;
  underlineWidthPx: number = 1;
  /** 下划线相对行盒底部的偏移（可负，对应 underlinePadding − 10）。 */
  underlineOffsetPx: number = 0;
  underlineExtend: boolean = false;
  dashIntervals: number[] = [];
  imagePlaceholderArgb: number = 0x2E808080;
}

/**
 * 章标题样式（全部 px）。
 *
 * 上游标题是排版流里的普通文本块，只是换了一套 paint
 * （`LegacyReaderPaginationStyleFactory.kt:99-113` 的 titleStyle/titlePaint）：
 * 字号、字重、字色、字距、行距倍率都跟正文分开。本地因此不能复用 `ReaderCanvasStyle`，
 * 否则标题会被当成正文画。
 */
export class ReaderCanvasTitleStyle {
  colorArgb: number = 0xFF000000;
  fontFamilies: string[] = [];
  /** 标题基准字号（px）；元素实际字号 = 它 × `LocalReaderLineItem.titleFontScale`。 */
  fontSizePx: number = 16;
  fontWeight: number = 400;
  /** 标题字距（px）。上游 titlePaint 不带 letterSpacing，默认 0。 */
  letterSpacingPx: number = 0;
  /** 1 = 水平居中（上游 `titleAlignment == CENTER`），0 = 起始对齐。 */
  align: number = 0;
}

/**
 * 一块待合并的文字底色矩形（画布坐标）。
 *
 * 上游 `feature/reader/core/style/ReaderBackgroundBounds.kt` 会把同一视觉行上相邻同色的
 * 底色块并成一条连续色带，否则排版按样式段切分后逐段铺色，字与字之间会留缝。
 */
class ReaderCanvasBackgroundRect {
  left: number = 0;
  top: number = 0;
  right: number = 0;
  bottom: number = 0;
  colorArgb: number = 0;
}

/** 一条高亮 / 笔记标记，start/end 是渲染坐标（与 LocalReaderLineItem 同口径）。 */
/** 分段后的「文本 + 生效样式」，供 ParagraphBuilder 逐段 pushStyle。 */
class ReaderCanvasStyledSegment {
  text: string = '';
  range: ReaderCanvasStyleRange | undefined = undefined;
}

/**
 * 正文样式区间（高亮规则 / 划线「文字颜色」）。
 *
 * 坐标与 `LocalReaderLineItem.startPosition` 同口径（渲染坐标）。
 * 数组顺序即优先级：后面的区间覆盖前面的重叠部分——上游
 * `LegacyReaderStyleRangeMapper.map()` 里高亮规则按 `position` 升序、用户划线
 * 用 `priority = 10_000 + index` 压在上面，同一句里「上层的赢」。
 */
export class ReaderCanvasStyleRange {
  start: number = 0;
  /** 规则自带的下划线粗细（vp，0 表示沿用正文下划线的口径）。 */
  underlineWidthVp: number = 0;
  /** 规则自带的下划线偏移（vp，相对行盒底部，可负）。 */
  underlineOffsetVp: number = 0;
  end: number = 0;
  /** 0 表示不覆盖文字颜色。 */
  textColorArgb: number = 0;
  /** 0 表示没有底色。 */
  backgroundArgb: number = 0;
  /** 0 无 / 1 实线 / 2 虚线 / 3 波浪 / 4 双线 / 6 删除线（对齐 TextDecorationType）。 */
  decoration: number = 0;
  decorationArgb: number = 0;
  /** 文字背景图（气泡图）源路径，空串表示无。 */
  bgImage: string = '';
  /** 0 平铺 / 1 等比内缩居中裁剪 / 2 等比填充居中 / 3 九宫格。 */
  bgImageFit: number = 0;
  /** 图片大小 0.1~5。 */
  bgImageScale: number = 1;
  npLeft: number = 0.1;
  npRight: number = 0.1;
  npTop: number = 0.1;
  npBottom: number = 0.1;
  /** 九宫格左右偏移（vp，画布换算 px），可负。 */
  bgLengthOffsetLeft: number = 0;
  bgLengthOffsetRight: number = 0;
  /**
   * 命中排版：规则自带的字体族。空数组表示沿用正文默认字体。
   *
   * 上游 `LegacyReaderStyleRangeMapper.kt:210-300` 把 `fontPath` 解析成 family 后挂到
   * `ReaderCharacterStyle`，绘制时逐段换字体。
   */
  fontFamilies: string[] = [];
  /** 命中排版：字重 0 表示不覆盖；非 0 用 100..900 口径。 */
  fontWeightValue: number = 0;
  /** 命中排版：0 不覆盖 / 1 强制斜体 / -1 强制不斜。 */
  italicOverride: number = 0;
  /** 命中排版：字号偏移（px，规则里是 sp/dp 口径，注入时已换算）。 */
  fontSizeOffsetPx: number = 0;
  /** 命中排版：命中首字之前多出的间距（px）。 */
  letterSpacingBeforePx: number = 0;
  /** 命中排版：命中末字之后多出的间距（px）。 */
  letterSpacingAfterPx: number = 0;
}

export class ReaderCanvasMarking {
  start: number = 0;
  end: number = 0;
  /** 背景色（含 alpha）。 */
  backgroundArgb: number = 0;
  /** 0 无下划线 / 1 实线 / 2 虚线 / 3 波浪（波浪暂按实线画）。 */
  decoration: number = 0;
  decorationArgb: number = 0;
}

export class ReaderCanvasDrawRequest {
  window: ReaderCanvasWindow = new ReaderCanvasWindow();
  transforms: ReaderTransitionTransforms = new ReaderTransitionTransforms();
  layout: ReaderCanvasLayout = new ReaderCanvasLayout();
  style: ReaderCanvasStyle = new ReaderCanvasStyle();
  /**
   * 章标题样式。标题行（`LocalReaderLine.titleLine === true`）按它绘制，
   * 不走 `style`——上游标题与正文是两套 paint（`LegacyReaderPaginationStyleFactory.kt:99-113`）。
   */
  titleStyle: ReaderCanvasTitleStyle = new ReaderCanvasTitleStyle();
  markings: ReaderCanvasMarking[] = [];
  /** 高亮规则命中的正文样式区间（底色/字色/下划线），与 markings 一起参与逐元素绘制。 */
  highlights: ReaderCanvasStyleRange[] = [];
  /** 页面底色（画布先整体铺一层，滚动/翻页时就靠它保证不透明）。 */
  pageBackgroundArgb: number = 0xFFFFFFFF;
  /**
   * 覆盖转场尾部阴影的起点（px，<0 表示本帧不画）。
   *
   * 上游 `ReaderCanvasSurface.kt:1663-1687`：COVER 且有位移时，在移动页的尾部边缘
   * 向右铺一条 36dp 的水平渐变（`0x30111111` → 透明），盖住下方静止页。
   */
  coverShadowEdgePx: number = -1;
  /**
   * 自动翻页：下一页从顶部揭开的高度（px），<=0 表示本帧不画。
   *
   * 上游 `ReaderCanvasSurface.kt:1700-1720`：分页模式下每帧把下一页按 `autoRevealPx`
   * 裁剪后贴上来，并在揭示线下沿画一条 1px 指示线。滚动模式不走这条路径。
   */
  autoRevealPx: number = 0;
  /** 自动翻页指示线颜色（上游 autoPageIndicatorColor = colorScheme.primary）。 */
  autoPageIndicatorArgb: number = 0xFF2E7CF6;
  /** 选区（渲染坐标，与 LocalReaderLineItem.startPosition 同口径）；start < 0 表示没有选区。 */
  selectionStart: number = -1;
  selectionEnd: number = -1;
  /** 选区底色，上游 legacySelectionFill = Color(0x63858585)。 */
  selectionColorArgb: number = 0x63858585;
  /** 把手：半径与描边（上游 SelectionHandleRadius = 7.dp、SelectionHandleStrokeWidth = 2.dp）。 */
  handleRadiusPx: number = 0;
  handleStrokeWidthPx: number = 0;
  handleFillArgb: number = 0xFFFFFFFF;
  handleStrokeArgb: number = 0xFF2E7CF6;
  /**
   * 两个把手各自的透明度（0..1）。
   *
   * 上游用 `animateFloatAsState` 做「拖动哪个就把哪个淡出、松手再淡入」：
   * 拖动中该把手淡出 90ms（`SelectionHandleFadeOutMillis`），松手淡入 140ms
   * （`SelectionHandleFadeInMillis`）。本地由 `ReaderPage` 用 `createAnimator`
   * 逐帧写这两个值，画布只按值绘制，不做动画。
   */
  handleStartAlpha: number = 1;
  handleEndAlpha: number = 1;
  /** 绘制后回填：选区首/末矩形与两个把手位置（px），调用方拿来给菜单定位与命中判定。 */
  selectionStartX: number = 0;
  selectionStartY: number = 0;
  selectionEndX: number = 0;
  selectionEndY: number = 0;
  selectionTopY: number = 0;
  selectionBottomY: number = 0;
  /** 回填：两个把手竖线的上端（矩形 top），把手是「竖线 + 圆柄」的胶囊形。 */
  selectionStartTopY: number = 0;
  selectionEndTopY: number = 0;
  /**
   * 折页（SIMULATION）的触点与角点，单位 px。
   *
   * 上游 `SimulationPageStack`：`touchX/touchY/cornerY/revealProgress` 由手势或收尾动画
   * 逐帧写入，绘制期只读。只有在 `transforms.mode === SIMULATION` 且 `curlActive` 时才走折页分支。
   */
  /**
   * 折页里每页自己的纸面底色（始终不透明）。
   *
   * 上游折页是把整页位图快照 blit 上去的，一张快照天然带着自己的纸底；
   * 本地是逐元素自绘，字与字之间是透明的，两页叠在一起会互相透出双重字影，
   * 所以折页里每画一页前先按这块底色铺一次纸面。
   */
  pageSurfaceArgb: number = 0xFFFFFFFF;
  /**
   * 纸面是否不透明（没有自定义背景图时为真）。
   *
   * 上游每页都是位图快照，一张快照天然不透明；本地逐元素自绘，字与字之间是空的。
   * 翻页转场两页会重叠在一起（COVER 旧页滑走时正压在新页上），不铺纸面就会两页
   * 文字互相透出。有自定义背景图时不能铺，否则图片被纸色盖住。
   */
  pageSurfaceOpaque: boolean = true;
  /**
   * 连续滚动（SCROLL）模式。
   *
   * 上游 `ReaderCanvasSurface.kt:1517-1540` 在滚动模式下走 `ScrollPageStack`：
   * 四页按 `scrollExtentPx` 首尾堆叠、整栈按 `scrollOffsetPx` 平移，
   * 而不是像分页那样给每页一个独立的翻页变换。
   */
  scrollActive: boolean = false;
  /** 整栈的纵向平移（px，≤0 表示已经往上滚过一段）。 */
  scrollOffsetPx: number = 0;
  /** 章末页额外留白（上游 CHAPTER_END_PADDING_DP = 20dp）。 */
  scrollEndPaddingPx: number = 0;
  /** 本章最后一页的下标（章末留白只加在它身上）。 */
  scrollLastPageIndex: number = -1;
  curlActive: boolean = false;
  curlTouchX: number = 0;
  curlTouchY: number = 0;
  curlCornerY: number = 0;
  curlRevealProgress: number = 1;
  /** 折页方向：true 表示上一页（从右往左翻回来），与 ReaderTransitionDirection 同义。 */
  curlPrevious: boolean = false;
}

// ---------------------------------------------------------------------------
// 颜色 / 字重工具
// ---------------------------------------------------------------------------

/** ARGB 数值 → common2D.Color（0..255 整数）。 */
export function readerCanvasColor(argb: number): common2D.Color {
  const value = Math.trunc(Math.abs(argb)) >>> 0;
  const color: common2D.Color = {
    alpha: (value >>> 24) & 0xFF,
    red: (value >>> 16) & 0xFF,
    green: (value >>> 8) & 0xFF,
    blue: value & 0xFF
  };
  return color;
}

/** 带 alpha 覆盖。 */
export function readerCanvasAlphaColor(argb: number, alpha: number): common2D.Color {
  const base = readerCanvasColor(argb);
  const color: common2D.Color = {
    alpha: Math.min(255, Math.max(0, Math.round(alpha * 255))),
    red: base.red,
    green: base.green,
    blue: base.blue
  };
  return color;
}

/** 数值字重 → text.FontWeight 枚举（枚举不是数值，必须映射）。 */
export function readerCanvasFontWeight(weight: number): text.FontWeight {
  if (weight >= 900) {
    return text.FontWeight.W900;
  }
  if (weight >= 800) {
    return text.FontWeight.W800;
  }
  if (weight >= 700) {
    return text.FontWeight.W700;
  }
  if (weight >= 600) {
    return text.FontWeight.W600;
  }
  if (weight >= 500) {
    return text.FontWeight.W500;
  }
  if (weight >= 400) {
    return text.FontWeight.W400;
  }
  if (weight >= 300) {
    return text.FontWeight.W300;
  }
  if (weight >= 200) {
    return text.FontWeight.W200;
  }
  return text.FontWeight.W100;
}

/**
 * 一个已定位的行内元素盒（px，页内绝对坐标）。
 * 版面几何在绘制时顺带产出，命中测试直接复用，避免「绘制」与「命中」两套坐标算法漂移。
 */
export class ReaderCanvasItemBox {
  item: LocalReaderLineItem | undefined = undefined;
  lineIndex: number = 0;
  itemIndex: number = 0;
  /** 元素绘制左边缘。 */
  left: number = 0;
  /** 元素绘制上边缘（文本是段落排版顶边，图片是图顶边）。 */
  top: number = 0;
  widthPx: number = 1;
  heightPx: number = 1;
  /** 该行行盒顶边，选区高亮与把手定位要用。 */
  lineTop: number = 0;
  /** 行内拉伸叠进 letterSpacing 的附加间距（px）。 */
  extraSpacingPx: number = 0;
}

/** 一行在版面上的位置。 */
export class ReaderCanvasLineBox {
  line: LocalReaderLine | undefined = undefined;
  lineIndex: number = 0;
  left: number = 0;
  top: number = 0;
  heightPx: number = 1;
}

/** 一页的版面几何。 */
export class ReaderCanvasPageGeometry {
  pageIndex: number = -1;
  boxes: ReaderCanvasItemBox[] = [];
  lines: ReaderCanvasLineBox[] = [];
}

interface ReaderCanvasParagraph {
  paragraph: text.Paragraph;
  heightPx: number;
}

// ---------------------------------------------------------------------------
// 渲染器：段落缓存 + 图片缓存 + 逐行绘制
// ---------------------------------------------------------------------------

export class ReaderCanvasRenderer {
  /** 最近一次绘制产出的版面几何（订阅选区命中用）。 */
  private geometry: ReaderCanvasPageGeometry = new ReaderCanvasPageGeometry();
  private paragraphCache: Map<string, ReaderCanvasParagraph> = new Map<string, ReaderCanvasParagraph>();
  private imageCache: Map<string, image.PixelMap> = new Map<string, image.PixelMap>();
  private imageLoading: Set<string> = new Set<string>();
  /** 文字背景图（气泡图）缓存：与正文图片分开，`.9.png` 必须按原尺寸解，否则引导边被降采样吃掉。 */
  private bgImageCache: Map<string, image.PixelMap> = new Map<string, image.PixelMap>();
  private bgImageLoading: Set<string> = new Set<string>();
  /** 折页五条路径与镜像矩阵，逐帧复用（Path.rewind 清形不换对象）。 */
  private curlPaths: ReaderCurlRenderPaths = new ReaderCurlRenderPaths();

  private static readonly PARAGRAPH_CACHE_LIMIT: number = 1024;
  private static readonly IMAGE_CACHE_LIMIT: number = 32;
  private static readonly BG_IMAGE_CACHE_LIMIT: number = 16;

  /**
   * 预取：把窗口里四页用到的图片全部解进 LRU。
   * 上游注释：翻页前先把 LRU 解好，绘制期直读必然命中，新页就不会出现
   * 「有字无气泡」的那一两帧（翻页闪一下）。
   */
  async prefetch(window: ReaderCanvasWindow): Promise<void> {
    const pages = window.all();
    for (const entry of pages) {
      for (const line of entry.page.lines) {
        for (const item of line.items) {
          if (item.kind !== 'image') {
            continue;
          }
          if (this.imageCache.has(item.value) || this.imageLoading.has(item.value)) {
            continue;
          }
          await this.loadImage(item.value);
        }
      }
    }
  }

  private async loadImage(source: string): Promise<void> {
    this.imageLoading.add(source);
    try {
      const imageSource = image.createImageSource(source);
      const info = await imageSource.getImageInfo();
      const density = info.density > 0 ? info.density / 160 : 1;
      const pixelMap = await imageSource.createPixelMap({
        desiredSize: {
          width: Math.max(1, Math.round(info.size.width / density)),
          height: Math.max(1, Math.round(info.size.height / density))
        }
      });
      this.imageCache.set(source, pixelMap);
      imageSource.release();
    } catch (error) {
      // 解不开的图留着当占位，不影响正文绘制
      console.warn(`[ReaderCanvas] 图片预取失败: ${error}`);
    } finally {
      this.imageLoading.delete(source);
    }
    if (this.imageCache.size > ReaderCanvasRenderer.IMAGE_CACHE_LIMIT) {
      // 超出上限就丢最早进来的那张（Map 保持插入顺序）
      let firstKey: string = '';
      for (const key of this.imageCache.keys()) {
        firstKey = key;
        break;
      }
      if (firstKey.length > 0) {
        const dropped = this.imageCache.get(firstKey);
        this.imageCache.delete(firstKey);
        dropped?.release();
      }
    }
  }

  /**
   * 预取文字背景图：规则里的 bgImage 源，`.9.png` 按原尺寸解，其余按 density 降采样。
   * 上游在排版期就预热（LegacyReaderStyleRangeMapper 遍历 runs 逐个 load），
   * 否则气泡会晚一两帧才出现。
   */
  async prefetchBackgrounds(sources: string[]): Promise<void> {
    for (const source of sources) {
      if (source.length === 0) {
        continue;
      }
      if (this.bgImageCache.has(source) || this.bgImageLoading.has(source)) {
        continue;
      }
      await this.loadBackgroundImage(source);
    }
  }

  private async loadBackgroundImage(source: string): Promise<void> {
    this.bgImageLoading.add(source);
    try {
      const imageSource = image.createImageSource(source);
      const info = await imageSource.getImageInfo();
      const isNinePatch = isNinePatchSource(source);
      const density = info.density > 0 ? info.density / 160 : 1;
      // 九宫格引导边只有 1px，降采样会吃掉切线，必须原尺寸解出
      const pixelMap = await imageSource.createPixelMap(isNinePatch
        ? { editable: false }
        : {
          desiredSize: {
            width: Math.max(1, Math.round(info.size.width / density)),
            height: Math.max(1, Math.round(info.size.height / density))
          }
        });
      this.bgImageCache.set(source, pixelMap);
      imageSource.release();
    } catch (error) {
      console.warn(`[ReaderCanvas] 文字背景图预取失败: ${error}`);
    } finally {
      this.bgImageLoading.delete(source);
    }
    if (this.bgImageCache.size > ReaderCanvasRenderer.BG_IMAGE_CACHE_LIMIT) {
      let firstKey: string = '';
      for (const key of this.bgImageCache.keys()) {
        firstKey = key;
        break;
      }
      if (firstKey.length > 0) {
        const dropped = this.bgImageCache.get(firstKey);
        this.bgImageCache.delete(firstKey);
        dropped?.release();
      }
    }
  }

  clear(): void {
    this.paragraphCache.clear();
    for (const pixelMap of this.imageCache.values()) {
      pixelMap.release();
    }
    this.imageCache.clear();
    this.imageLoading.clear();
    for (const pixelMap of this.bgImageCache.values()) {
      pixelMap.release();
    }
    this.bgImageCache.clear();
    this.bgImageLoading.clear();
  }

  /** 只清段落缓存（字体、字号、颜色、对齐等样式变更时调用）。 */
  clearParagraphs(): void {
    this.paragraphCache.clear();
  }

  /**
   * 绘制一帧。z 序照上游 ReaderCanvasSurface.kt:1636-1650：
   * currentOnTop → 先 next、再 current、再 previous；否则 previous、current、next。
   */
  draw(canvas: drawing.Canvas, request: ReaderCanvasDrawRequest): void {
    const window = request.window;
    const transforms = request.transforms;

    // 先铺一层不透明底色，再判断有没有当前页。
    // 「没有当前页」在上游是 `pages.current ?: return`（直接不绘制，不换排版兜底），
    // 但底色必须照铺：Canvas 是透明的，不铺就会露出下层的自定义背景图，
    // 于是「还没排好」的那一两帧会闪一下背景——这属于我们要避免的空帧。
    const brush = new drawing.Brush();
    brush.setColor(readerCanvasColor(request.pageBackgroundArgb));
    canvas.attachBrush(brush);
    canvas.drawRect(0, 0, request.layout.viewportWidthPx, request.layout.viewportHeightPx);
    canvas.detachBrush();
    if (window.current === undefined) {
      // 没有当前页就不画正文，绝不回落到「整章连续滚动」那套排版
      return;
    }
    // 仿真折页走独立合成路径（上游 SimulationPageStack）：
    // 底下是翻起的那一页的整页、上层按曲线裁剪出折页与背面。
    // 覆盖整页自绘，不能用任何 slot 平移近似。
    if (request.curlActive) {
      this.drawCurl(canvas, request);
      return;
    }
    // 连续滚动：四页按 extent 首尾堆叠、整栈平移（上游 ScrollPageStack）
    if (request.scrollActive) {
      this.drawScroll(canvas, request);
      return;
    }
    // z 序严格照上游 ReaderCanvasSurface.kt:1643-1663：
    //   currentOnTop && drawsNext → next
    //   → current
    //   → drawsPrevious → previous
    //   → !currentOnTop && drawsNext → next
    // 不能简单地「按方向前后颠倒」：PREVIOUS 时 currentOnTop=false，
    // previous 必须画在 current 之上（它才是滑进来的那一页）。
    if (transforms.currentOnTop && transforms.drawsNext) {
      this.drawSlot(canvas, window.next, transforms.next, request, false, false);
    }
    this.drawSlot(canvas, window.current, transforms.current, request, true, true);
    if (transforms.drawsPrevious) {
      this.drawSlot(canvas, window.previous, transforms.previous, request, false, false);
    }
    if (!transforms.currentOnTop && transforms.drawsNext) {
      this.drawSlot(canvas, window.next, transforms.next, request, false, false);
    }
    // 覆盖转场尾部阴影画在四页之后：它就是「移动页盖在静止页上」的那道投影。
    if (request.coverShadowEdgePx >= 0) {
      this.drawCoverShadow(canvas, request);
    }
    // 自动翻页：下一页从顶部揭开，揭示线下沿一条 1px 指示线。
    if (request.autoRevealPx > 0) {
      this.drawAutoPageReveal(canvas, request);
    }

  }

  /**
   * 自动翻页一帧：把下一页按揭示高度从顶部裁出来贴上，再画 1px 指示线。
   *
   * 逐项照上游 `ReaderCanvasSurface.kt:1700-1720`：
   * `clipRect(bottom = reveal)` 内画下一页本身，指示线画在揭示线下沿（reveal - 1px）。
   * 本地没有「页快照层」，直接用同一套 `drawSlot` 重画下一页，效果等价。
   */
  private drawAutoPageReveal(canvas: drawing.Canvas,
    request: ReaderCanvasDrawRequest): void {
    const layout = request.layout;
    const reveal = Math.min(request.autoRevealPx, layout.viewportHeightPx);
    if (reveal <= 0) {
      return;
    }
    canvas.save();
    canvas.clipRect({
      left: 0, top: 0, right: layout.viewportWidthPx, bottom: reveal
    }, drawing.ClipOp.INTERSECT, true);
    const slot: ReaderCanvasPage | undefined = request.window.next;
    if (slot !== undefined) {
      this.drawSlot(canvas, slot, new ReaderPageTransform(), request, false, false);
    }
    canvas.restore();
    // 指示线：揭示线本身，宽 1px、贴在下沿（上游 indicatorTopPx = reveal - 1）
    const pen = new drawing.Pen();
    pen.setColor(readerCanvasColor(request.autoPageIndicatorArgb));
    pen.setStrokeWidth(1);
    canvas.attachPen(pen);
    const y = Math.max(0, reveal - 1);
    canvas.drawLine(0, y, layout.viewportWidthPx, y);
    canvas.detachPen();
  }

  /**
   * 覆盖转场尾部阴影：从边缘向右 36dp 的水平渐变（`0x30111111` → 透明）。
   *
   * 上游 `ReaderCoverShadowPolicy.edgePx()`：PREVIOUS 取位移量本身，
   * NEXT 取「页宽 + 位移」。这里由调用方算好边缘位置传进来。
   */
  private drawCoverShadow(canvas: drawing.Canvas, request: ReaderCanvasDrawRequest): void {
    const edge = request.coverShadowEdgePx;
    const vp = Math.max(0.0001, request.layout.vpScale);
    const shadowWidth = ReaderPageTransitionPolicy.COVER_SHADOW_WIDTH_DP * vp;
    if (shadowWidth <= 0) {
      return;
    }
    const startPoint: common2D.Point = { x: edge, y: 0 };
    const endPoint: common2D.Point = { x: edge + shadowWidth, y: 0 };
    const brush = new drawing.Brush();
    brush.setShaderEffect(drawing.ShaderEffect.createLinearGradient(startPoint, endPoint,
      [ReaderPageTransitionPolicy.COVER_SHADOW_ARGB, 0x00000000], drawing.TileMode.CLAMP, null, null));
    canvas.attachBrush(brush);
    canvas.drawRect(edge, 0, edge + shadowWidth, request.layout.viewportHeightPx);
    canvas.detachBrush();
  }

  /**
   * 连续滚动一帧（上游 `ScrollPageStack`，ReaderCanvasSurface.kt:1903-2057）。
   *
   * previous 放在 `offset − extent(previous)`、current 放在 `offset`、
   * next 放在 `offset + extent(current)`、nextPlus 再往后一页；
   * 每页按自己的 stackOffset 平移后整页绘制，超出视口的部分裁掉。
   */
  private drawScroll(canvas: drawing.Canvas, request: ReaderCanvasDrawRequest): void {
    const window = request.window;
    const current = window.current;
    if (current === undefined) {
      return;
    }
    const offset = request.scrollOffsetPx;
    const currentExtent = this.pageScrollExtent(current.page, current.pageIndex, request);
    if (window.previous !== undefined) {
      this.drawScrollSlot(canvas, window.previous,
        offset - this.pageScrollExtent(window.previous.page, window.previous.pageIndex, request),
        request, false, false);
    }
    this.drawScrollSlot(canvas, current, offset, request, true, true);
    if (window.next !== undefined) {
      const nextOffset = offset + currentExtent;
      this.drawScrollSlot(canvas, window.next, nextOffset, request, false, false);
      if (window.nextPlus !== undefined) {
        this.drawScrollSlot(canvas, window.nextPlus,
          nextOffset + this.pageScrollExtent(window.next.page, window.next.pageIndex, request),
          request, false, false);
      }
    }
  }

  /** 滚动栈里的一页：按 stackOffset 平移后整页画，超出视口的部分裁掉。 */
  private drawScrollSlot(canvas: drawing.Canvas, slot: ReaderCanvasPage,
    stackOffsetY: number, request: ReaderCanvasDrawRequest,
    recordGeometry: boolean, drawSelection: boolean): void {
    const layout = request.layout;
    canvas.save();
    // 滚动栈天然会画出视口之外（上一页还在上面、下一页还在下面），必须裁
    canvas.clipRect({
      left: 0, top: 0, right: layout.viewportWidthPx, bottom: layout.viewportHeightPx
    }, drawing.ClipOp.INTERSECT, true);
    canvas.translate(0, stackOffsetY);
    if (request.pageSurfaceOpaque) {
      this.fillPageSurface(canvas, request, layout.viewportWidthPx, layout.viewportHeightPx);
    }
    this.drawPage(canvas, slot.page, slot.pageIndex, request, recordGeometry, drawSelection);
    canvas.restore();
  }

  /**
   * 一页在滚动栈里占的高度（px）。
   *
   * 上游 `scrollExtentPx` 就是排版游标（`ReaderPaginator.kt:1126-1172`）：
   * 章末页额外加 `chapterEndPaddingPx`，且**不**向内容区高度收口——收口会让
   * 残页后面的空白顶满一屏，必须滚过整屏空白才接上下一章正文。
   */
  pageScrollExtent(page: LocalReaderPage, pageIndex: number,
    request: ReaderCanvasDrawRequest): number {
    const vp = Math.max(0.0001, request.layout.vpScale);
    let used = 0;
    for (const line of page.lines) {
      used += (line.verticalSpaceBefore + line.height + line.paragraphSpacingAfter) * vp;
    }
    if ((page.titleOnly || page.messageText !== undefined) && used <= 0) {
      used = Math.max(1, request.layout.bodyHeightPx);
    }
    let extent = Math.max(1, used);
    if (request.scrollLastPageIndex >= 0 && pageIndex === request.scrollLastPageIndex) {
      extent += request.scrollEndPaddingPx;
    }
    return extent;
  }

  /**
   * 四页在滚动坐标系里的所有文字行区间（pageStep 用）。
   * 行坐标已含 stackOffset，调用方只需再传正文区的 contentTop / contentBottom。
   */
  scrollLineBoxes(request: ReaderCanvasDrawRequest): ReaderScrollLine[] {
    const window = request.window;
    const lines: ReaderScrollLine[] = [];
    const current = window.current;
    if (current === undefined) {
      return lines;
    }
    const offset = request.scrollOffsetPx;
    const currentExtent = this.pageScrollExtent(current.page, current.pageIndex, request);
    if (window.previous !== undefined) {
      this.pushScrollLineBoxes(lines, window.previous,
        offset - this.pageScrollExtent(window.previous.page, window.previous.pageIndex, request),
        request);
    }
    this.pushScrollLineBoxes(lines, current, offset, request);
    if (window.next !== undefined) {
      const nextOffset = offset + currentExtent;
      this.pushScrollLineBoxes(lines, window.next, nextOffset, request);
      if (window.nextPlus !== undefined) {
        this.pushScrollLineBoxes(lines, window.nextPlus,
          nextOffset + this.pageScrollExtent(window.next.page, window.next.pageIndex, request),
          request);
      }
    }
    return lines;
  }

  private pushScrollLineBoxes(out: ReaderScrollLine[], slot: ReaderCanvasPage,
    stackOffsetY: number, request: ReaderCanvasDrawRequest): void {
    const vp = Math.max(0.0001, request.layout.vpScale);
    let used = 0;
    for (const line of slot.page.lines) {
      const top = stackOffsetY + used + line.verticalSpaceBefore * vp;
      const box = new ReaderScrollLine();
      box.top = top;
      box.bottom = top + Math.max(1, line.height * vp);
      out.push(box);
      used += (line.verticalSpaceBefore + line.height + line.paragraphSpacingAfter) * vp;
    }
  }

  private drawSlot(canvas: drawing.Canvas, slot: ReaderCanvasPage | undefined,
    transform: ReaderPageTransform, request: ReaderCanvasDrawRequest,
    recordGeometry: boolean, drawSelection: boolean): void {
    if (slot === undefined) {
      return;
    }
    const alpha = Math.min(1, Math.max(0, transform.alpha));
    if (alpha <= 0) {
      return;
    }
    canvas.save();
    canvas.translate(transform.translationX, transform.translationY);
    // 每页先铺自己的纸面：转场里两页会重叠，不铺就会互相透出（见 pageSurfaceOpaque 注释）
    if (request.pageSurfaceOpaque) {
      this.fillPageSurface(canvas, request, request.layout.viewportWidthPx,
        request.layout.viewportHeightPx);
    }
    let layerPushed = false;
    if (alpha < 1) {
      const brush = new drawing.Brush();
      brush.setColor(readerCanvasAlphaColor(0xFF000000, alpha));
      canvas.saveLayer(null, brush);
      layerPushed = true;
    }
    this.drawPage(canvas, slot.page, slot.pageIndex, request, recordGeometry, drawSelection);
    if (layerPushed) {
      canvas.restore();
    }
    canvas.restore();
  }

  /**
   * 仿真折页一帧。
   *
   * 逐项照上游 `ReaderCanvasSurface.kt:2200-2320` 的 `Canvas {}`：
   * 1. `PageCurlGeometry.calculate(...)` 取几何；退化（null）时用水平平移兜底，
   *    否则新页会整整一帧不见；
   * 2. 先整页画「翻起的那一页」（basePage）：折页曲线与它内接折线之间有一圈数像素
   *    宽的月牙既不属于 reveal 也不属于 back，Compose 画布没有底页就会露出画布底色；
   * 3. `clip(front) ∩ clip(reveal)` 内画露出的下一页 + 背面阴影；
   * 4. `clip(front) ∩ clip(back)` 内先铺纸背底色，再用镜像矩阵把 basePage 翻过来，
   *    最后压折缝阴影；
   * 5. 正面两道阴影：先在「折页之外」取差集，再各自裁剪成楔形。
   */
  private drawCurl(canvas: drawing.Canvas, request: ReaderCanvasDrawRequest): void {
    const window = request.window;
    const layout = request.layout;
    const width = Math.max(1, layout.viewportWidthPx);
    const height = Math.max(1, layout.viewportHeightPx);
    const isPrevious = request.curlPrevious;
    // 上游：`basePage = if (NEXT) pages.current else pages.previous`、
    //       `revealPage = if (NEXT) pages.next else pages.current`。
    const baseSlot = isPrevious ? window.previous : window.current;
    const revealSlot = isPrevious ? window.current : window.next;
    if (baseSlot === undefined || revealSlot === undefined) {
      // 邻页还没排好：换成水平平移兜底，保持目标页可见（上游 frame == null 的同款处理）
      this.drawSlot(canvas, revealSlot, new ReaderPageTransform(), request, true, true);
      return;
    }
    const touchX = ReaderCurlTouchPolicy.revealX(isPrevious, request.curlTouchX, width,
      request.curlRevealProgress);
    const touchY = Math.min(height - 0.1, Math.max(0.1, request.curlTouchY));
    const frame = PageCurlGeometry.calculate(width, height, touchX, touchY,
      new CurlPoint(width, request.curlCornerY));
    if (frame === undefined) {
      // 折页几何退化（返回 null）时只剩底页，新页会整整一帧不见：用便宜的
      // 水平平移兜底，保持目标页可见，等下一帧有效折页几何再恢复。
      this.fillPageSurface(canvas, request, width, height);
      this.drawPage(canvas, revealSlot.page, revealSlot.pageIndex, request, true, false);
      canvas.save();
      canvas.translate(isPrevious ? -width : 0, 0);
      this.drawPage(canvas, baseSlot.page, baseSlot.pageIndex, request, false, false);
      canvas.restore();
      return;
    }
    const paths = this.curlPaths.update(frame, width, height);
    // 1) 底页整页：月牙区靠它兜底，必须先铺纸面再画字（见 pageSurfaceArgb 注释）
    this.fillPageSurface(canvas, request, width, height);
    this.drawPage(canvas, baseSlot.page, baseSlot.pageIndex, request, true, false);
    // 2) 折页下方露出的下一页 + 背面阴影
    canvas.save();
    canvas.clipPath(paths.front, drawing.ClipOp.INTERSECT, true);
    canvas.clipPath(paths.reveal, drawing.ClipOp.INTERSECT, true);
    this.fillPageSurface(canvas, request, width, height);
    this.drawPage(canvas, revealSlot.page, revealSlot.pageIndex, request, false, false);
    this.drawCurlBackShadow(canvas, frame, width, height);
    canvas.restore();
    // 3) 翻起的纸背（镜像的底页）+ 折缝阴影
    canvas.save();
    canvas.clipPath(paths.front, drawing.ClipOp.INTERSECT, true);
    canvas.clipPath(paths.back, drawing.ClipOp.INTERSECT, true);
    // 纸背底色：对照旧 View `drawColor(背景图平均色)`，遮住下面的当前页，
    // 让翻起的纸片是一张不透明的纸而不是透出正面内容。
    this.fillPageSurface(canvas, request, width, height);
    // 镜像绘制前先在源坐标裁剪：否则变换后会采样到页面外，形成暗楔形。
    canvas.save();
    canvas.clipRect({ left: 0, top: 0, right: width, bottom: height },
      drawing.ClipOp.INTERSECT, true);
    canvas.setMatrix(paths.mirror);
    this.drawPage(canvas, baseSlot.page, baseSlot.pageIndex, request, false, false);
    canvas.restore();
    canvas.resetMatrix();
    this.drawCurlFolderShadow(canvas, frame, width, height);
    canvas.restore();
    // 4) 正面两道阴影
    this.drawCurlFrontShadows(canvas, frame, paths, width, height);
  }

  /** 铺一页的纸面底色（不透明），折页里每次画页面前都要先铺。 */
  private fillPageSurface(canvas: drawing.Canvas, request: ReaderCanvasDrawRequest,
    width: number, height: number): void {
    const brush = new drawing.Brush();
    brush.setColor(readerCanvasColor(request.pageSurfaceArgb));
    canvas.attachBrush(brush);
    canvas.drawRect(0, 0, width, height);
    canvas.detachBrush();
  }

  /** 背面阴影：折页与底页之间的过渡暗带，沿 start1 旋转后画一条水平渐变。 */
  private drawCurlBackShadow(canvas: drawing.Canvas, frame: PageCurlFrame, width: number,
    height: number): void {
    const reverse = ReaderCurlRenderPaths.isReverse(frame, width, height);
    const shadowWidth = frame.touchToCornerDistance / 4;
    const left = reverse ? frame.start1.x : frame.start1.x - shadowWidth;
    const right = reverse ? frame.start1.x + shadowWidth : frame.start1.x;
    if (right <= left) {
      return;
    }
    const diagonal = Math.sqrt(width * width + height * height);
    const colors = reverse
      ? [ReaderCurlVisualPolicy.BACK_SHADOW_DARK_ARGB, 0x00000000]
      : [0x00000000, ReaderCurlVisualPolicy.BACK_SHADOW_DARK_ARGB];
    this.drawGradientRect(canvas, frame.degrees, frame.start1.x, frame.start1.y,
      left, frame.start1.y, right - left, diagonal, colors, true);
  }

  /** 折缝阴影：折页根部一道更深的窄带，让「折起来」有厚度。 */
  private drawCurlFolderShadow(canvas: drawing.Canvas, frame: PageCurlFrame, width: number,
    height: number): void {
    const folderWidth = Math.max(1, Math.min(
      Math.abs((frame.start1.x - frame.control1.x) / 2),
      Math.abs((frame.start2.y - frame.control2.y) / 2)));
    const reverse = ReaderCurlRenderPaths.isReverse(frame, width, height);
    const left = reverse ? frame.start1.x - 1 : frame.start1.x - folderWidth - 1;
    const right = reverse ? frame.start1.x + folderWidth + 1 : frame.start1.x + 1;
    if (right <= left) {
      return;
    }
    const diagonal = Math.sqrt(width * width + height * height);
    const colors = reverse
      ? [0x00000000, ReaderCurlVisualPolicy.FOLDER_SHADOW_DARK_ARGB]
      : [ReaderCurlVisualPolicy.FOLDER_SHADOW_DARK_ARGB, 0x00000000];
    this.drawGradientRect(canvas, frame.degrees, frame.start1.x, frame.start1.y,
      left, frame.start1.y, right - left, diagonal, colors, true);
  }

  /**
   * 正面两道阴影：先在「折页之外」取差集，再各自裁剪成楔形。
   * 上游注释：两条阴影共用同一个裁剪遮罩，别为每条阴影各来一次。
   */
  private drawCurlFrontShadows(canvas: drawing.Canvas, frame: PageCurlFrame,
    paths: ReaderCurlRenderPaths, width: number, height: number): void {
    const reverse = ReaderCurlRenderPaths.isReverse(frame, width, height);
    const diagonal = Math.sqrt(width * width + height * height);
    canvas.save();
    canvas.clipPath(paths.front, drawing.ClipOp.DIFFERENCE, true);
    // 水平楔形
    canvas.save();
    canvas.clipPath(paths.frontShadowHorizontal, drawing.ClipOp.INTERSECT, true);
    const horizontalLeft = reverse ? frame.control1.x : frame.control1.x - 25;
    const horizontalRight = reverse ? frame.control1.x + 25 : frame.control1.x + 1;
    if (horizontalRight > horizontalLeft) {
      const rotation = Math.atan2(frame.touch.x - frame.control1.x,
        frame.control1.y - frame.touch.y) * 180 / Math.PI;
      const colors = reverse
        ? [ReaderCurlVisualPolicy.FRONT_SHADOW_DARK_ARGB, 0x00000000]
        : [0x00000000, ReaderCurlVisualPolicy.FRONT_SHADOW_DARK_ARGB];
      this.drawGradientRect(canvas, rotation, frame.control1.x, frame.control1.y,
        horizontalLeft, frame.control1.y - diagonal, horizontalRight - horizontalLeft,
        diagonal, colors, true);
    }
    canvas.restore();
    // 垂直楔形
    canvas.save();
    canvas.clipPath(paths.frontShadowVertical, drawing.ClipOp.INTERSECT, true);
    const verticalTop = reverse ? frame.control2.y : frame.control2.y - 25;
    const verticalBottom = reverse ? frame.control2.y + 25 : frame.control2.y + 1;
    if (verticalBottom > verticalTop) {
      const rotation = Math.atan2(frame.control2.y - frame.touch.y,
        frame.control2.x - frame.touch.x) * 180 / Math.PI;
      const colors = reverse
        ? [ReaderCurlVisualPolicy.FRONT_SHADOW_DARK_ARGB, 0x00000000]
        : [0x00000000, ReaderCurlVisualPolicy.FRONT_SHADOW_DARK_ARGB];
      this.drawGradientRect(canvas, rotation, frame.control2.x, frame.control2.y,
        0, verticalTop, width, verticalBottom - verticalTop, colors, false);
    }
    canvas.restore();
    canvas.restore();
  }

  /**
   * 在 (rotateX, rotateY) 处旋转 degrees 后画一个线性渐变矩形。
   *
   * `horizontal` 为真时渐变沿 x（左右），否则沿 y（上下）；上游对应
   * `Brush.horizontalGradient` / `Brush.verticalGradient`，色标位置一致。
   */
  private drawGradientRect(canvas: drawing.Canvas, degrees: number, rotateX: number,
    rotateY: number, left: number, top: number, rectWidth: number, rectHeight: number,
    colors: number[], horizontal: boolean): void {
    if (rectWidth <= 0 || rectHeight <= 0) {
      return;
    }
    const startPoint: common2D.Point = horizontal
      ? { x: left, y: top }
      : { x: left, y: top };
    const endPoint: common2D.Point = horizontal
      ? { x: left + rectWidth, y: top }
      : { x: left, y: top + rectHeight };
    canvas.save();
    canvas.rotate(degrees, rotateX, rotateY);
    const brush = new drawing.Brush();
    brush.setShaderEffect(drawing.ShaderEffect.createLinearGradient(startPoint, endPoint,
      colors, drawing.TileMode.CLAMP, null, null));
    canvas.attachBrush(brush);
    canvas.drawRect(left, top, left + rectWidth, top + rectHeight);
    canvas.detachBrush();
    canvas.restore();
  }

  /**
   * 一页：先算版面几何，再逐元素绘制，最后把选区压在最上层。
   * 上游顺序是「先画字，再把选区块压上去」（ReaderCanvasSurface.kt legacySelectionFill 注释）。
   */
  private drawPage(canvas: drawing.Canvas, page: LocalReaderPage, pageIndex: number,
    request: ReaderCanvasDrawRequest, recordGeometry: boolean, drawSelection: boolean): void {
    // Paragraph.paint() 内部会 push 不配对的裁剪层且不恢复：逐框 save/restore 之后
    // 画布栈仍会比进入时多出几层，后面自绘的选区底色/把手就全落在残留 clip 里被裁掉
    // （表现为「drawRect 被调用但一个像素都不落」）。这里记下进入时的栈深，
    // 画选区前统一归位。
    const entrySaveCount = canvas.getSaveCount();
    // 占位页：整屏居中的一行提示，没有正文几何。
    // 对齐上游 centeredReaderMessagePage（ReadBookController.kt:3051-3100）。
    if (page.messageText !== undefined) {
      this.drawMessagePage(canvas, page, request);
      canvas.restoreToCount(entrySaveCount);
      return;
    }
    const geometry = this.layoutPage(page, pageIndex, request);
    // 只有「手指正在操作的那一页」才把几何记成命中测试的依据。
    // 四页窗口是一次绘制里按 z 序画完的，若每页都覆盖 this.geometry，
    // 最后画的邻页会顶掉当前页的坐标，长按选词就会选到邻页的字符区间，
    // 选区也被画到邻页的平移位置上（表现为「选区跑偏到屏幕外」）。
    if (recordGeometry) {
      this.geometry = geometry;
    }
    // 分层绘制，对齐上游 `ReaderCanvasSurface.kt:2767-2869` 的绘制顺序：
    // 第一层文字背景（色带 + 半高高亮）→ 第二层正文与图片 → 第三层选区 →
    // 第四层下划线（标记下划线 + 规则下划线）。上游把下划线放在 `selectedTextBounds`
    // 之后画，所以选区盖不住下划线；本地原先每个文字框「底色→字形→下划线」一口气画完，
    // 选区最后再压上去，会把下划线整条盖掉。
    for (const box of geometry.boxes) {
      if (box.item !== undefined && box.item.kind === 'text') {
        this.drawTextBoxBackground(canvas, box, request);
      }
    }
    // 文字背景图（气泡图）：上游顺序在「色带之后、字形之前」（textBackgroundBands → textBackgrounds → 正文）。
    // 色块画完再铺气泡，气泡画在字形下面，所以必须整页收集合并成 run 后统一画。
    this.drawTextBackgrounds(canvas, geometry, request);
    for (const box of geometry.boxes) {
      if (box.item === undefined) {
        continue;
      }
      if (box.item.kind === 'image') {
        this.drawImageBox(canvas, box, request);
      } else {
        this.drawTextBoxText(canvas, box, request);
      }
    }
    // 整页文字下划线（style.underline）：压住文字下缘。
    if (request.style.underline) {
      for (const lineBox of geometry.lines) {
        if (lineBox.line !== undefined) {
          this.drawLineUnderline(canvas, lineBox, request);
        }
      }
    }
    canvas.restoreToCount(entrySaveCount);
    if (drawSelection) {
      this.drawSelection(canvas, geometry, request);
    }
    // 第四层：所有下划线统一压在选区之上。
    for (const box of geometry.boxes) {
      if (box.item !== undefined && box.item.kind === 'text') {
        this.drawTextBoxUnderlines(canvas, box, request);
      }
    }
  }

  /**
   * 版面：把分页器的行/元素摆成绝对坐标。
   * 这条遍历是绘制与命中测试的唯一来源——不要再另写一套坐标计算，
   * 否则选区高亮会和字形对不上。
   */
  private layoutPage(page: LocalReaderPage, pageIndex: number,
    request: ReaderCanvasDrawRequest): ReaderCanvasPageGeometry {
    const layout = request.layout;
    const columnCount = Math.max(1, layout.columnCount);
    const stride = layout.columnStridePx > 0 ? layout.columnStridePx : layout.bodyWidthPx;
    // 分页器的行高/行距/行内字宽都是 vp，进入绘制统一乘 vpScale 换成 px
    const vp = Math.max(0.0001, layout.vpScale);
    const geometry = new ReaderCanvasPageGeometry();
    geometry.pageIndex = pageIndex;
    const used: number[] = [];
    const lineCount: number[] = [];
    for (let i = 0; i < columnCount; i++) {
      used.push(0);
      lineCount.push(0);
    }
    // 底部对齐：上游 justifyColumnBottom() 是**逐列**独立摊分（两列的行数不同，
    // 剩余高度也不同），所以这里按列取各自的位移，不能用全页一个值。
    const gaps = layout.bottomJustifyGapByColumn;
    // 标题页垂直居中（上游 titlePageCenterVertical，`ReaderPaginator.kt:369-389`）：
    // 页成型后按「整页内容高度」算一次平移量，把元素整体下移半个剩余高度。
    const centerVertical = page.centerVertical === true;
    const centerOffset = centerVertical ? this.pageCenterOffset(page, request) : 0;
    for (let index = 0; index < page.lines.length; index++) {
      const line = page.lines[index];
      const column = page.lineColumns.length > index ? page.lineColumns[index] : 0;
      const safeColumn = Math.min(columnCount - 1, Math.max(0, column));
      const columnGap = gaps.length > safeColumn ? (gaps[safeColumn] ?? 0) : layout.bottomJustifyGapPx;
      const top = layout.originYpx + centerOffset + used[safeColumn] + line.verticalSpaceBefore * vp +
        columnGap * lineCount[safeColumn];
      const left = layout.originXpx + safeColumn * stride;
      const lineBox = new ReaderCanvasLineBox();
      lineBox.line = line;
      lineBox.lineIndex = index;
      lineBox.left = left;
      lineBox.top = top;
      lineBox.heightPx = Math.max(1, line.height * vp);
      geometry.lines.push(lineBox);
      // 标题行水平居中：上游在排版期就把对齐折进 bounds.left
      // （`ReaderPaginator.kt:870`），这里同样在版面阶段算好起点。
      const titleCentered = line.titleAlign === 1;
      let cursor = left;
      for (let itemIndex = 0; itemIndex < line.items.length; itemIndex++) {
        const item = line.items[itemIndex];
        const nextItem: LocalReaderLineItem | undefined =
          itemIndex + 1 < line.items.length ? line.items[itemIndex + 1] : undefined;
        const box = new ReaderCanvasItemBox();
        box.item = item;
        box.lineIndex = index;
        box.itemIndex = itemIndex;
        box.left = cursor;
        box.lineTop = top;
        if (item.kind === 'image') {
          box.widthPx = Math.max(1, item.width * vp);
          box.heightPx = Math.max(1, item.height * vp);
          box.top = top + Math.max(0, (line.height * vp - box.heightPx) / 2);
        } else {
          // 行内拉伸：分页器的 justifyGap 是老 Span 路径「每个字形之后」补的间距
          // （getReaderGlyphGapAfter）。Paragraph 的 letterSpacing 正是逐字形加的，
          // 且最后一个字形之后的间距不计入绘制范围，所以叠进 letterSpacing 与老路径等价。
          const extraSpacingPx = line.justifyGap > 0 && !item.leadingIndent ? line.justifyGap * vp : 0;
          box.extraSpacingPx = extraSpacingPx;
          box.widthPx = Math.max(1, item.width * vp + extraSpacingPx * Math.max(0, item.value.length - 1));
          const built = this.getParagraph(item.value, this.itemTextStyle(request, item), box.widthPx,
            extraSpacingPx, this.itemStyleRanges(request, item));
          const builtHeight = built !== undefined ? built.heightPx : line.height * vp;
          box.top = top + Math.max(0, (line.height * vp - builtHeight) / 2);
          box.heightPx = builtHeight;
          // 标题行水平居中：上游在排版期就把对齐折进 bounds.left（`ReaderPaginator.kt:870`）。
          if (titleCentered) {
            const columnWidthPx = columnCount > 1 ? stride : layout.bodyWidthPx;
            box.left = left + Math.max(0, (columnWidthPx - box.widthPx) / 2);
          }
        }
        geometry.boxes.push(box);
        // 行内推进：leadingIndent 与末项之后不加 justifyGap（对齐 getReaderLineGapAfter）
        const gap = !item.leadingIndent && nextItem !== undefined && !nextItem.leadingIndent
          ? line.justifyGap : 0;
        cursor += (item.width + gap) * vp;
      }
      used[safeColumn] += (line.verticalSpaceBefore + line.height + line.paragraphSpacingAfter) * vp;
      lineCount[safeColumn] = lineCount[safeColumn] + 1;
    }
    return geometry;
  }

  /** 行下划线：underlineExtend 拉到正文宽，否则到该行实际文字宽度。 */
  private drawLineUnderline(canvas: drawing.Canvas, lineBox: ReaderCanvasLineBox,
    request: ReaderCanvasDrawRequest): void {
    const line = lineBox.line;
    if (line === undefined || line.imageOnly) {
      return;
    }
    // 章标题不画正文下划线：上游标题走 titlePaint，没有 pageUnderline。
    if (line.titleLine === true) {
      return;
    }
    const layout = request.layout;
    const vp = Math.max(0.0001, layout.vpScale);
    const lineEnd = request.style.underlineExtend
      ? layout.bodyWidthPx
      : Math.max(0, Math.min(layout.bodyWidthPx, line.contentWidth * vp));
    const underlineY = lineBox.top + lineBox.heightPx + request.style.underlineOffsetPx;
    const pen = new drawing.Pen();
    pen.setColor(readerCanvasColor(request.style.underlineColorArgb));
    pen.setStrokeWidth(Math.max(1, request.style.underlineWidthPx));
    pen.setAntiAlias(true);
    if (request.style.dashIntervals.length >= 2) {
      pen.setPathEffect(drawing.PathEffect.createDashPathEffect(request.style.dashIntervals, 0));
    }
    canvas.attachPen(pen);
    canvas.drawLine(lineBox.left, underlineY, lineBox.left + lineEnd, underlineY);
    canvas.detachPen();
  }

  /**
   * 文字元素的第一层：高亮规则的色带与标记的半高底色，都在字形之下。
   * 上游把这批底色整页铺完再画正文（`textBackgroundBands` → `halfHighlights` → 正文），
   * 逐框画也没问题——它们本来就都落在字形下缘以下。
   */
  private drawTextBoxBackground(canvas: drawing.Canvas, box: ReaderCanvasItemBox,
    request: ReaderCanvasDrawRequest): void {
    const item = box.item;
    if (item === undefined) {
      return;
    }
    const built = this.getParagraph(item.value, this.itemTextStyle(request, item), box.widthPx,
      box.extraSpacingPx, this.itemStyleRanges(request, item));
    if (built === undefined) {
      return;
    }
    this.drawBackgroundBands(canvas, item, built, box.left, box.top, request);
    this.drawMarkingBackgrounds(canvas, item, built, box.left, box.top, request);
  }

  /** 文字元素的第二层：字形本身。 */
  private drawTextBoxText(canvas: drawing.Canvas, box: ReaderCanvasItemBox,
    request: ReaderCanvasDrawRequest): void {
    const item = box.item;
    if (item === undefined) {
      return;
    }
    const built = this.getParagraph(item.value, this.itemTextStyle(request, item), box.widthPx,
      box.extraSpacingPx, this.itemStyleRanges(request, item));
    if (built === undefined) {
      return;
    }
    // Paragraph.paint 会改动 canvas 的画笔/裁剪状态且不恢复，
    // 后面还要用同一块画布画选区，所以这里必须 save/restore 兜住。
    canvas.save();
    built.paragraph.paint(canvas, box.left, box.top);
    canvas.restore();
  }

  /**
   * 文字元素的第四层：标记下划线 + 高亮规则下划线。
   * 上游在选区之后画（`dynamicEmphasisUnderlineRuns` → `contentRules` → `styledUnderlines`），
   * 所以即使整段被选中，下划线仍然清晰可见。
   */
  private drawTextBoxUnderlines(canvas: drawing.Canvas, box: ReaderCanvasItemBox,
    request: ReaderCanvasDrawRequest): void {
    const item = box.item;
    if (item === undefined) {
      return;
    }
    const built = this.getParagraph(item.value, this.itemTextStyle(request, item), box.widthPx,
      box.extraSpacingPx, this.itemStyleRanges(request, item));
    if (built === undefined) {
      return;
    }
    this.drawMarkingUnderlines(canvas, item, built, box.left, box.top, request);
    this.drawStyledUnderlines(canvas, item, built, box.left, box.top, request);
  }

  /**
   * 占位页：把一行提示画在正文区正中。
   *
   * 上游 `centeredReaderMessagePage` 用 `StaticLayout` 单段，`blockTop =
   * contentTop + ((contentBottom - contentTop - layout.height) / 2f).coerceAtLeast(0f)`
   * 且逐行横向居中（`ReadBookController.kt:3080-3095`）。
   */
  private drawMessagePage(canvas: drawing.Canvas, page: LocalReaderPage,
    request: ReaderCanvasDrawRequest): void {
    const text = page.messageText;
    if (text === undefined || text.length === 0) {
      return;
    }
    const layout = request.layout;
    const built = this.getParagraph(text, request.style, layout.bodyWidthPx, 0, []);
    if (built === undefined) {
      return;
    }
    const top = layout.originYpx +
      Math.max(0, (layout.bodyHeightPx - built.heightPx) / 2);
    // 上游逐行 `x = contentLeft + ((contentWidth - lineWidth) / 2f)`，单行时等价于整行横向居中
    const lineWidth = built.paragraph.getLongestLine();
    const left = layout.originXpx + Math.max(0, (layout.bodyWidthPx - lineWidth) / 2);
    canvas.save();
    built.paragraph.paint(canvas, left, top);
    canvas.restore();
  }

  /** 图片元素：解不开时画灰底占位（上游 Color.Gray.copy(alpha = .18f)）。 */
  private drawImageBox(canvas: drawing.Canvas, box: ReaderCanvasItemBox,
    request: ReaderCanvasDrawRequest): void {
    const item = box.item;
    if (item === undefined) {
      return;
    }
    const pixelMap = this.imageCache.get(item.value);
    if (pixelMap === undefined) {
      const brush = new drawing.Brush();
      brush.setColor(readerCanvasColor(request.style.imagePlaceholderArgb));
      canvas.attachBrush(brush);
      canvas.drawRect(box.left, box.top, box.left + box.widthPx, box.top + box.heightPx);
      canvas.detachBrush();
      return;
    }
    const rect: common2D.Rect = {
      left: box.left,
      top: box.top,
      right: box.left + box.widthPx,
      bottom: box.top + box.heightPx
    };
    canvas.drawImageRect(pixelMap, rect);
  }

  /**
   * 文字背景图（气泡图）：整页收集各文字元素里命中背景图规则的矩形，按
   * 「同图 + 同行 + 相邻」合并成 run，再逐 run 按四种 fit 模式绘制。
   * 上游 `ReaderTextBackgroundRun.textBackgroundRuns()`。
   */
  private drawTextBackgrounds(canvas: drawing.Canvas, geometry: ReaderCanvasPageGeometry,
    request: ReaderCanvasDrawRequest): void {
    if (request.highlights.length === 0) {
      return;
    }
    // 收集候选：每个命中区间一段矩形，带图描述；单位都是画布 px。
    const candidates: ReaderTextBackgroundRun[] = [];
    const vpScale = Math.max(0.0001, request.layout.vpScale);
    for (const box of geometry.boxes) {
      if (box.item === undefined || box.item.kind !== 'text') {
        continue;
      }
      const item = box.item;
      const ranges = this.itemStyleRanges(request, item);
      if (ranges.length === 0) {
        continue;
      }
      const built = this.getParagraph(item.value, this.itemTextStyle(request, item), box.widthPx,
        box.extraSpacingPx, ranges);
      if (built === undefined) {
        continue;
      }
      for (const range of ranges) {
        if (range.bgImage.length === 0) {
          continue;
        }
        const boxes = built.paragraph.getRectsForRange(
          { start: range.start, end: range.end },
          text.RectWidthStyle.TIGHT,
          text.RectHeightStyle.TIGHT
        );
        for (const rectBox of boxes) {
          const run = new ReaderTextBackgroundRun();
          run.image.source = range.bgImage;
          run.image.fit = range.bgImageFit;
          run.image.scale = range.bgImageScale;
          run.image.ninePatchLeft = range.npLeft;
          run.image.ninePatchRight = range.npRight;
          run.image.ninePatchTop = range.npTop;
          run.image.ninePatchBottom = range.npBottom;
          // 规则里的左右偏移是 dp，画布层统一 px
          run.image.lengthOffsetLeftPx = range.bgLengthOffsetLeft * vpScale;
          run.image.lengthOffsetRightPx = range.bgLengthOffsetRight * vpScale;
          run.contentLeft = box.left + rectBox.rect.left;
          run.contentTop = box.top + rectBox.rect.top;
          run.contentRight = box.left + rectBox.rect.right;
          run.contentBottom = box.top + rectBox.rect.bottom;
          run.frameLeft = run.contentLeft;
          run.frameTop = run.contentTop;
          run.frameRight = run.contentRight;
          run.frameBottom = run.contentBottom;
          candidates.push(run);
        }
      }
    }
    if (candidates.length === 0) {
      return;
    }
    const runs = ReaderCanvasRenderer.mergeTextBackgroundRuns(candidates);
    for (const run of runs) {
      const pixelMap = this.bgImageCache.get(run.image.source);
      if (pixelMap === undefined) {
        // 还没解出来就异步补一帧，下一帧重绘后再画，避免首帧空气泡
        if (!this.bgImageLoading.has(run.image.source)) {
          this.loadBackgroundImage(run.image.source);
        }
        continue;
      }
      this.drawTextBackground(canvas, pixelMap, run);
    }
  }

  /** 同图背景矩形合并：同图描述 + 同行（top 差 < 0.5）+ 相邻（间隙 < 1px）。 */
  private static mergeTextBackgroundRuns(runs: ReaderTextBackgroundRun[]): ReaderTextBackgroundRun[] {
    const sorted = runs.slice();
    sorted.sort((a: ReaderTextBackgroundRun, b: ReaderTextBackgroundRun): number => {
      if (Math.abs(a.contentTop - b.contentTop) > 0.5) {
        return a.contentTop - b.contentTop;
      }
      return a.contentLeft - b.contentLeft;
    });
    const merged: ReaderTextBackgroundRun[] = [];
    for (const run of sorted) {
      const previous = merged.length > 0 ? merged[merged.length - 1] : undefined;
      if (previous !== undefined && previous.image.source === run.image.source &&
        previous.image.fit === run.image.fit && previous.image.scale === run.image.scale &&
        previous.image.ninePatchLeft === run.image.ninePatchLeft &&
        previous.image.ninePatchRight === run.image.ninePatchRight &&
        previous.image.ninePatchTop === run.image.ninePatchTop &&
        previous.image.ninePatchBottom === run.image.ninePatchBottom &&
        previous.image.lengthOffsetLeftPx === run.image.lengthOffsetLeftPx &&
        previous.image.lengthOffsetRightPx === run.image.lengthOffsetRightPx &&
        Math.abs(previous.contentTop - run.contentTop) < 0.5 &&
        Math.abs(previous.contentBottom - run.contentBottom) < 0.5 &&
        run.contentLeft - previous.contentRight < 1) {
        previous.contentRight = Math.max(previous.contentRight, run.contentRight);
        previous.frameRight = previous.contentRight;
        previous.frameBottom = Math.max(previous.frameBottom, run.frameBottom);
        continue;
      }
      merged.push(run);
    }
    return merged;
  }

  /**
   * 画一条背景图 run。四种 fit 照上游 `ReaderCanvasSurface.kt drawTextBackground`：
   * 1 内缩居中裁剪 / 2 等比填充居中 / 3 九宫格 / else（0）平铺。
   */
  private drawTextBackground(canvas: drawing.Canvas, pixelMap: image.PixelMap,
    run: ReaderTextBackgroundRun): void {
    const info = pixelMap.getImageInfoSync();
    const bitmapWidth = info.size.width;
    const bitmapHeight = info.size.height;
    if (bitmapWidth <= 0 || bitmapHeight <= 0) {
      return;
    }
    // 拿位图尺寸回填四条切线厚度与中间带高（只对九宫格生效）
    const imageDesc = run.image.withBitmapSize(bitmapWidth, bitmapHeight);
    const scale = imageDesc.sizeFactor();
    const lineHeightPx = run.contentHeight();
    const frameTop = run.contentTop - imageDesc.frameTopPx(lineHeightPx);
    const frameBottom = run.contentBottom + imageDesc.frameBottomPx(lineHeightPx);
    const frameLeft = run.contentLeft - imageDesc.frameLeftPx(lineHeightPx);
    const frameRight = run.contentRight + imageDesc.frameRightPx(lineHeightPx);
    const sampling = new drawing.SamplingOptions(drawing.FilterMode.FILTER_MODE_LINEAR);
    const entrySaveCount = canvas.getSaveCount();
    if (imageDesc.fit === 1) {
      // 等比内缩居中裁剪：图不放大，只按 scale 缩放后居中截取覆盖内容区
      const width = (run.contentRight - run.contentLeft) * scale;
      const height = width * bitmapHeight / bitmapWidth;
      const left = run.contentLeft + (run.contentWidth() - width) / 2;
      const top = run.contentTop + (run.contentHeight() - height) / 2;
      const destination: common2D.Rect = {
        left: left,
        top: top,
        right: left + width,
        bottom: top + height
      };
      canvas.save();
      canvas.clipRect(destination);
      canvas.drawImageRect(pixelMap, destination, sampling);
      canvas.restoreToCount(entrySaveCount);
      return;
    }
    if (imageDesc.fit === 2) {
      // 等比填充居中：放大到刚好盖满内容区，超出部分裁掉
      const fitScale = Math.max(
        run.contentWidth() / bitmapWidth,
        run.contentHeight() / bitmapHeight
      ) * scale;
      const width = bitmapWidth * fitScale;
      const height = bitmapHeight * fitScale;
      const left = run.contentLeft + (run.contentWidth() - width) / 2;
      const top = run.contentTop + (run.contentHeight() - height) / 2;
      const destination: common2D.Rect = {
        left: left,
        top: top,
        right: left + width,
        bottom: top + height
      };
      canvas.save();
      canvas.clipRect(destination);
      canvas.drawImageRect(pixelMap, destination, sampling);
      canvas.restoreToCount(entrySaveCount);
      return;
    }
    if (imageDesc.fit === 3) {
      // 九宫格：逐格 clipRect(destination) + drawImageRectWithSrc(painted)
      const cells = ReaderNineSliceLayout.cells(
        bitmapWidth, bitmapHeight,
        run.contentLeft, run.contentTop, run.contentRight, run.contentBottom,
        frameLeft, frameTop, frameRight, frameBottom, imageDesc
      );
      for (const cell of cells) {
        const clip: common2D.Rect = {
          left: cell.destLeft,
          top: cell.destTop,
          right: cell.destRight,
          bottom: cell.destBottom
        };
        const src: common2D.Rect = {
          left: cell.sourceLeft,
          top: cell.sourceTop,
          right: cell.sourceRight,
          bottom: cell.sourceBottom
        };
        const painted: common2D.Rect = {
          left: cell.paintLeft,
          top: cell.paintTop,
          right: cell.paintRight,
          bottom: cell.paintBottom
        };
        const cellSaveCount = canvas.getSaveCount();
        canvas.save();
        canvas.clipRect(clip);
        canvas.drawImageRectWithSrc(pixelMap, src, painted, sampling, drawing.SrcRectConstraint.FAST);
        canvas.restoreToCount(cellSaveCount);
      }
      return;
    }
    // fit 0：平铺。ImageShader(REPEAT) + 缩放 + 平移到内容区左上角。
    const matrix = new drawing.Matrix();
    matrix.setScale(scale, scale, 0, 0);
    matrix.postTranslate(run.contentLeft, run.contentTop);
    const shader = drawing.ShaderEffect.createImageShader(
      pixelMap, drawing.TileMode.REPEAT, drawing.TileMode.REPEAT, sampling, matrix);
    const brush = new drawing.Brush();
    brush.setShaderEffect(shader);
    canvas.attachBrush(brush);
    canvas.drawRect(run.contentLeft, run.contentTop, run.contentRight, run.contentBottom);
    canvas.detachBrush();
    canvas.restoreToCount(entrySaveCount);
  }

  /**
   * 选区：先用 getRectsForRange 拿每个元素内的矩形并合并成条带，再画把手。
   * 上游注释「先画字，再把选区块压上去」，所以这一步必须在所有元素之后。
   */
  private drawSelection(canvas: drawing.Canvas, geometry: ReaderCanvasPageGeometry,
    request: ReaderCanvasDrawRequest): void {
    if (request.selectionStart < 0 || request.selectionEnd <= request.selectionStart) {
      return;
    }
    let firstRect: common2D.Rect | undefined = undefined;
    let lastRect: common2D.Rect | undefined = undefined;
    for (const box of geometry.boxes) {
      const item = box.item;
      if (item === undefined || item.kind !== 'text') {
        continue;
      }
      const start = Math.max(request.selectionStart, item.startPosition);
      const end = Math.min(request.selectionEnd, item.endPosition);
      if (end <= start) {
        continue;
      }
      const built = this.getParagraph(item.value, this.itemTextStyle(request, item), box.widthPx,
        box.extraSpacingPx);
      if (built === undefined) {
        continue;
      }
      const boxes = built.paragraph.getRectsForRange(
        { start: start - item.startPosition, end: end - item.startPosition },
        text.RectWidthStyle.TIGHT,
        text.RectHeightStyle.TIGHT
      );
      for (const textBox of boxes) {
        const rect: common2D.Rect = {
          left: box.left + textBox.rect.left,
          top: box.top + textBox.rect.top,
          right: box.left + textBox.rect.right,
          bottom: box.top + textBox.rect.bottom
        };
        // 每个矩形都新建画笔并立即 detach：Paragraph.paint 会改动 canvas 的画笔状态，
        // 复用同一个 Brush 时后面几段会出现「drawRect 被调用但不落像素」。
        const fill = new drawing.Brush();
        fill.setColor(readerCanvasColor(request.selectionColorArgb));
        canvas.attachBrush(fill);
        canvas.drawRect(rect.left, rect.top, rect.right, rect.bottom);
        canvas.detachBrush();
        if (firstRect === undefined) {
          firstRect = rect;
        }
        lastRect = rect;
      }
    }
    if (firstRect === undefined || lastRect === undefined) {
      return;
    }
    // 把手几何照上游 drawPinHandle：竖线贴矩形左右边从 top 画到 bottom，
    // 圆柄圆心在 bottom + radius（不是矩形竖直中心）。命中判定用的就是这两个圆心。
    const radius = Math.max(0, request.handleRadiusPx);
    request.selectionStartX = firstRect.left;
    request.selectionStartTopY = firstRect.top;
    request.selectionStartY = firstRect.bottom + radius;
    request.selectionEndX = lastRect.right;
    request.selectionEndTopY = lastRect.top;
    request.selectionEndY = lastRect.bottom + radius;
    request.selectionTopY = Math.min(firstRect.top, lastRect.top);
    request.selectionBottomY = Math.max(firstRect.bottom, lastRect.bottom);
    if (radius <= 0) {
      return;
    }
    const strokeWidth = Math.max(1, request.handleStrokeWidthPx);
    // 上游竖线只画到矩形 bottom（`Offset(lineX, lineBottom)`），圆柄另画在
    // bottom + radius 处；画到圆心会让竖线多出一段穿过行间的尾巴。
    this.drawPinHandle(canvas, request.selectionStartX, request.selectionStartTopY,
      request.selectionStartY - radius, request.selectionStartY, radius, strokeWidth,
      request.handleStartAlpha, request.handleFillArgb, request.handleStrokeArgb);
    this.drawPinHandle(canvas, request.selectionEndX, request.selectionEndTopY,
      request.selectionEndY - radius, request.selectionEndY, radius, strokeWidth,
      request.handleEndAlpha, request.handleFillArgb, request.handleStrokeArgb);
  }

  /**
   * 单个把手：竖线 + 圆柄，同一支笔的圆角描边（上游 `StrokeCap.Round`）。
   * 透明度为 0 时整支跳过，避免淡出后还留一道边。
   */
  private drawPinHandle(canvas: drawing.Canvas, x: number, lineTop: number, lineBottom: number,
    centerY: number, radius: number, strokeWidth: number, alpha: number,
    fillArgb: number, strokeArgb: number): void {
    if (alpha <= 0.001) {
      return;
    }
    const stroke = readerCanvasAlphaColor(strokeArgb, alpha);
    // 竖线：从矩形上沿画到圆心，与圆柄拼成一个胶囊
    const pen = new drawing.Pen();
    pen.setColor(stroke);
    pen.setStrokeWidth(strokeWidth);
    pen.setAntiAlias(true);
    pen.setCapStyle(drawing.CapStyle.ROUND_CAP);
    canvas.attachPen(pen);
    canvas.drawLine(x, lineTop, x, lineBottom);
    canvas.detachPen();
    // 圆柄：先填色再描边
    const fill = new drawing.Brush();
    fill.setColor(readerCanvasAlphaColor(fillArgb, alpha));
    fill.setAntiAlias(true);
    canvas.attachBrush(fill);
    canvas.drawCircle(x, centerY, radius);
    canvas.detachBrush();
    const ring = new drawing.Pen();
    ring.setColor(stroke);
    ring.setStrokeWidth(strokeWidth);
    ring.setAntiAlias(true);
    canvas.attachPen(ring);
    canvas.drawCircle(x, centerY, radius);
    canvas.detachPen();
  }

  /** 最近一次绘制产出的版面几何（命中测试用）。 */
  getGeometry(): ReaderCanvasPageGeometry {
    return this.geometry;
  }

  /**
   * 按屏幕点找命中的文字元素盒：先按 y 找最近的一行（超过一行高就算没命中），
   * 再在那一行里按 x 找元素（落在盒内直接命中，否则取水平距离最近的）。
   */
  hitTestTextBox(x: number, y: number): ReaderCanvasItemBox | undefined {
    let bestLine: ReaderCanvasLineBox | undefined = undefined;
    let bestLineDistance = Number.MAX_VALUE;
    for (const lineBox of this.geometry.lines) {
      const center = lineBox.top + lineBox.heightPx / 2;
      const distance = Math.abs(y - center);
      if (distance < bestLineDistance) {
        bestLineDistance = distance;
        bestLine = lineBox;
      }
    }
    if (bestLine === undefined || bestLineDistance > bestLine.heightPx) {
      return undefined;
    }
    {
      const dump: string[] = [];
      for (const lb of this.geometry.lines) {
        const n = this.geometry.boxes.filter((b) => b.lineIndex === lb.lineIndex).length;
        dump.push(`${lb.lineIndex}:${lb.top.toFixed(0)}/${lb.heightPx.toFixed(0)}x${n}`);
      }
    }
    let best: ReaderCanvasItemBox | undefined = undefined;
    let bestDistance = Number.MAX_VALUE;
    for (const box of this.geometry.boxes) {
      const item = box.item;
      if (item === undefined || item.kind !== 'text' || box.lineIndex !== bestLine.lineIndex) {
        continue;
      }
      const right = box.left + box.widthPx;
      if (x >= box.left && x <= right) {
        return box;
      }
      const distance = x < box.left ? box.left - x : x - right;
      if (distance < bestDistance) {
        bestDistance = distance;
        best = box;
      }
    }
    return best;
  }

  /**
   * 按屏幕点找命中的图片元素盒（上游 `ReaderElement.Image` 的命中）。
   *
   * 图片盒在图内直接返回；容差一行高度以内取最近的，避免细图点不中。
   */
  hitTestImageBox(x: number, y: number): ReaderCanvasItemBox | undefined {
    let best: ReaderCanvasItemBox | undefined = undefined;
    let bestDistance = Number.MAX_VALUE;
    for (const box of this.geometry.boxes) {
      const item = box.item;
      if (item === undefined || item.kind !== 'image') {
        continue;
      }
      const right = box.left + box.widthPx;
      const bottom = box.top + box.heightPx;
      if (x >= box.left && x <= right && y >= box.top && y <= bottom) {
        return box;
      }
      const dx = x < box.left ? box.left - x : (x > right ? x - right : 0);
      const dy = y < box.top ? box.top - y : (y > bottom ? y - bottom : 0);
      const distance = dx + dy;
      if (distance < bestDistance) {
        bestDistance = distance;
        best = box;
      }
    }
    // 容差：超过一个行高就算没点中，避免点正文空白处误开图。
    if (best === undefined) {
      return undefined;
    }
    const tolerance = best.heightPx > 0 ? Math.max(best.heightPx, best.widthPx) * 0.5 : 24;
    if (bestDistance > tolerance) {
      return undefined;
    }
    return best;
  }

  /** 盒内字形偏移：屏幕点先换算成段落局部坐标，再问 Paragraph。 */
  /**
   * 把页面坐标换算成章节正文位置（上游 `ReaderSelectionPolicy.start(page, x, y)` 的等价物）。
   *
   * 分页器把一行切成很多小元素（标点、样式变化各起一个），单个元素只有几个字。
   * 若只在命中的那个元素里取字形偏移，拖到元素右边界外就被 clamp 在元素末尾，
   * 选区再也扩不出去 —— 表现为「拖把手不动」。这里在同一行的所有元素间继续推进：
   * 落在某个元素内就取它的字形偏移，超出最后一个元素就取行尾位置。
   */
  positionAt(x: number, y: number, style: ReaderCanvasStyle): number {
    const line = this.nearestLine(y);
    if (line === undefined) {
      return -1;
    }
    let lastEnd = -1;
    let firstStart = -1;
    for (const box of this.geometry.boxes) {
      const item = box.item;
      if (item === undefined || item.kind !== 'text' || box.lineIndex !== line.lineIndex) {
        continue;
      }
      if (firstStart < 0 || item.startPosition < firstStart) {
        firstStart = item.startPosition;
      }
      if (item.endPosition > lastEnd) {
        lastEnd = item.endPosition;
      }
      if (x <= box.left + box.widthPx) {
        if (x <= box.left) {
          return item.startPosition;
        }
        return item.startPosition + this.glyphOffsetAt(box, x, y, style);
      }
    }
    if (lastEnd >= 0) {
      return lastEnd;
    }
    return firstStart;
  }

  /** 找纵向最近的行盒；超出一行高度就返回 undefined（手指离文字太远）。 */
  private nearestLine(y: number): ReaderCanvasLineBox | undefined {
    let best: ReaderCanvasLineBox | undefined = undefined;
    let bestDistance = Number.MAX_VALUE;
    for (const lineBox of this.geometry.lines) {
      const center = lineBox.top + lineBox.heightPx / 2;
      const distance = Math.abs(y - center);
      if (distance < bestDistance) {
        bestDistance = distance;
        best = lineBox;
      }
    }
    if (best === undefined || bestDistance > best.heightPx) {
      return undefined;
    }
    return best;
  }

  glyphOffsetAt(box: ReaderCanvasItemBox, x: number, y: number,
    style: ReaderCanvasStyle): number {
    const item = box.item;
    if (item === undefined) {
      return 0;
    }
    const built = this.getParagraph(item.value, style, box.widthPx, box.extraSpacingPx);
    if (built === undefined) {
      return 0;
    }
    try {
      const position = built.paragraph.getGlyphPositionAtCoordinate(x - box.left, y - box.top);
      return Math.max(0, Math.min(item.value.length, position.position));
    } catch (error) {
      return 0;
    }
  }

  /** 整词边界（长按选词）：局部 index 范围，调用方再加上元素的 startPosition。 */
  wordRangeAt(box: ReaderCanvasItemBox, offset: number,
    style: ReaderCanvasStyle): text.Range | undefined {
    const item = box.item;
    if (item === undefined) {
      return undefined;
    }
    const built = this.getParagraph(item.value, style, box.widthPx, box.extraSpacingPx);
    if (built === undefined) {
      return undefined;
    }
    try {
      const range = built.paragraph.getWordBoundary(Math.max(0, Math.min(item.value.length, offset)));
      return range;
    } catch (error) {
      return undefined;
    }
  }

  private drawMarkingBackgrounds(canvas: drawing.Canvas, item: LocalReaderLineItem,
    built: ReaderCanvasParagraph, left: number, top: number, request: ReaderCanvasDrawRequest): void {
    if (request.markings.length === 0) {
      return;
    }
    const brush = new drawing.Brush();
    for (const marking of request.markings) {
      if (marking.backgroundArgb === 0) {
        continue;
      }
      const start = Math.max(marking.start, item.startPosition);
      const end = Math.min(marking.end, item.endPosition);
      if (end <= start) {
        continue;
      }
      const localStart = start - item.startPosition;
      const localEnd = end - item.startPosition;
      brush.setColor(readerCanvasColor(marking.backgroundArgb));
      canvas.attachBrush(brush);
      const boxes = built.paragraph.getRectsForRange(
        { start: localStart, end: localEnd },
        text.RectWidthStyle.TIGHT,
        text.RectHeightStyle.TIGHT
      );
      for (const box of boxes) {
        canvas.drawRect(left + box.rect.left, top + box.rect.top, left + box.rect.right, top + box.rect.bottom);
      }
      canvas.detachBrush();
    }
  }

  /**
   * 高亮规则的文字底色：收集本元素的底色矩形后按「同行 + 同色 + 间隙容差」合并成色带。
   *
   * 上游 `ReaderBackgroundBounds.mergeBackgroundBounds(minimumLineOverlap = 0.5f)`：
   * 垂直重叠 >= 较矮者高度的 50% 视为同一视觉行；水平间隙 <= 较矮者高度的 50% 视为连续。
   * 不合并的话，排版按样式段切分后每段各铺一次色，字与字之间会看到一格一格的断口。
   */
  private drawBackgroundBands(canvas: drawing.Canvas, item: LocalReaderLineItem,
    built: ReaderCanvasParagraph, left: number, top: number,
    request: ReaderCanvasDrawRequest): void {
    if (request.highlights.length === 0) {
      return;
    }
    const ranges = this.styleRangesForItem(item, request);
    if (ranges.length === 0) {
      return;
    }
    const rects: ReaderCanvasBackgroundRect[] = [];
    for (const range of ranges) {
      if (range.backgroundArgb === 0) {
        continue;
      }
      const boxes = built.paragraph.getRectsForRange(
        { start: range.start, end: range.end },
        text.RectWidthStyle.TIGHT,
        text.RectHeightStyle.TIGHT
      );
      for (const box of boxes) {
        const rect = new ReaderCanvasBackgroundRect();
        rect.left = left + box.rect.left;
        rect.top = top + box.rect.top;
        rect.right = left + box.rect.right;
        rect.bottom = top + box.rect.bottom;
        rect.colorArgb = range.backgroundArgb;
        rects.push(rect);
      }
    }
    if (rects.length === 0) {
      return;
    }
    const bands = ReaderCanvasRenderer.mergeBackgroundBands(rects);
    const brush = new drawing.Brush();
    canvas.attachBrush(brush);
    for (const band of bands) {
      brush.setColor(readerCanvasColor(band.colorArgb));
      canvas.drawRect(band.left, band.top, band.right, band.bottom);
    }
    canvas.detachBrush();
  }

  /** 同色矩形合并：按上游 `mergeBackgroundBounds` 的两条判定（同行重叠 + 间隙容差）。 */
  private static mergeBackgroundBands(rects: ReaderCanvasBackgroundRect[]): ReaderCanvasBackgroundRect[] {
    const sorted = rects.slice();
    // 先按视觉行（top）再按 left 排，保证同一行的块挨在一起
    sorted.sort((a: ReaderCanvasBackgroundRect, b: ReaderCanvasBackgroundRect): number => {
      if (Math.abs(a.top - b.top) > 0.5) {
        return a.top - b.top;
      }
      return a.left - b.left;
    });
    const bands: ReaderCanvasBackgroundRect[] = [];
    for (const rect of sorted) {
      const previous = bands.length > 0 ? bands[bands.length - 1] : undefined;
      if (previous === undefined) {
        bands.push(rect);
        continue;
      }
      const overlap = Math.min(previous.bottom, rect.bottom) - Math.max(previous.top, rect.top);
      const minHeight = Math.min(previous.bottom - previous.top, rect.bottom - rect.top);
      const sameLine = minHeight > 0 && overlap >= minHeight * 0.5;
      const joinGap = minHeight * 0.5;
      const horizontalGap = Math.max(rect.left - previous.right, previous.left - rect.right, 0);
      if (sameLine && previous.colorArgb === rect.colorArgb && horizontalGap <= joinGap) {
        previous.left = Math.min(previous.left, rect.left);
        previous.top = Math.min(previous.top, rect.top);
        previous.right = Math.max(previous.right, rect.right);
        previous.bottom = Math.max(previous.bottom, rect.bottom);
      } else {
        bands.push(rect);
      }
    }
    return bands;
  }

  /**
   * 高亮规则的下划线线型：逐行手绘，不用系统 `TextDecoration`。
   *
   * 上游 `feature/reader/platform/ReaderPageDecorationDrawCache.kt:58-152`
   * 的 `ReaderUnderlineDrawCommand.draw()` 按 mode 分支自己画：1 实线、2 虚线、
   * 3 波浪（振幅 3dp、波长 12dp）、4 双线（间距 3dp + 线宽）、6 删除线（52% 高）、
   * 7 荧光（下半高填充）。系统 `TextDecorationStyle` 只有 WAVY/DOUBLE 两种且参数不可调，
   * 画出来与上游的观感差得远，所以这里照上游手绘。
   */
  private drawStyledUnderlines(canvas: drawing.Canvas, item: LocalReaderLineItem,
    built: ReaderCanvasParagraph, left: number, top: number,
    request: ReaderCanvasDrawRequest): void {
    const ranges = this.styleRangesForItem(item, request);
    if (ranges.length === 0) {
      return;
    }
    const vp = Math.max(0.0001, request.layout.vpScale);
    for (const range of ranges) {
      // 1 实线仍交给系统段落绘制（见 segmentStyle），这里只画系统没有的线型
      if (range.decoration === 0 || range.decoration === 1) {
        continue;
      }
      const boxes = built.paragraph.getRectsForRange(
        { start: range.start, end: range.end },
        text.RectWidthStyle.TIGHT,
        text.RectHeightStyle.TIGHT
      );
      for (const box of boxes) {
        const startX = left + box.rect.left;
        const endX = left + box.rect.right;
        if (endX <= startX) {
          continue;
        }
        this.drawOneStyledUnderline(canvas, range, startX, endX,
          top + box.rect.top, top + box.rect.bottom, vp);
      }
    }
  }

  /** 一条下划线/删除线/荧光底色（区间已按行盒切好）。 */
  private drawOneStyledUnderline(canvas: drawing.Canvas, range: ReaderCanvasStyleRange,
    startX: number, endX: number, boxTop: number, boxBottom: number, vp: number): void {
    const widthPx = Math.max(1,
      range.underlineWidthVp > 0 ? range.underlineWidthVp * vp : 1);
    const offsetPx = range.underlineOffsetVp * vp;
    const y = boxBottom + offsetPx;
    // 7 荧光：把行盒下半截整块填成下划线色（上游 ReaderHalfHighlightDrawCommand）
    if (range.decoration === 7) {
      const brush = new drawing.Brush();
      brush.setColor(readerCanvasColor(range.decorationArgb));
      canvas.attachBrush(brush);
      const halfTop = boxTop + (boxBottom - boxTop) * 0.5;
      canvas.drawRect(startX, halfTop, endX, boxBottom);
      canvas.detachBrush();
      return;
    }
    // 6 删除线：画在行盒 52% 高处（上游 mode 6 分支）
    const lineY = range.decoration === 6 ? boxTop + (boxBottom - boxTop) * 0.52 : y;
    const pen = new drawing.Pen();
    pen.setColor(readerCanvasColor(range.decorationArgb));
    pen.setStrokeWidth(widthPx);
    pen.setAntiAlias(true);
    if (range.decoration === 2) {
      // 2 虚线：上游默认 8dp 实 / 5dp 空（dashOnPx = 8.dpToPx()、dashOffPx = 5.dpToPx()）
      const dashOn = Math.max(0.1, 8 * vp);
      const dashOff = Math.max(0.1, 5 * vp);
      canvas.attachPen(pen);
      let x = startX;
      while (x < endX) {
        canvas.drawLine(x, lineY, Math.min(x + dashOn, endX), lineY);
        x += dashOn + dashOff;
      }
      canvas.detachPen();
      return;
    }
    if (range.decoration === 3) {
      // 3 波浪：振幅 3dp、波长 12dp，用四分之一波长的二次贝塞尔交替上下
      const waveLength = Math.max(0.1, 12 * vp);
      const amplitude = 3 * vp;
      const path = new drawing.Path();
      path.moveTo(startX, lineY);
      let x = startX;
      while (x < endX) {
        const next = Math.min(x + waveLength, endX);
        path.quadTo((x + next) / 2, lineY - amplitude, next, lineY);
        x = next;
        if (x < endX) {
          const nextDown = Math.min(x + waveLength, endX);
          path.quadTo((x + nextDown) / 2, lineY + amplitude, nextDown, lineY);
          x = nextDown;
        }
      }
      canvas.attachPen(pen);
      canvas.drawPath(path);
      canvas.detachPen();
      return;
    }
    if (range.decoration === 4) {
      // 4 双线：第二条在第一条下方「间距 3dp + 线宽」处（上游 doubleLineGapPx = 3.dp）
      const secondY = lineY + 3 * vp + widthPx;
      canvas.attachPen(pen);
      canvas.drawLine(startX, lineY, endX, lineY);
      canvas.drawLine(startX, secondY, endX, secondY);
      canvas.detachPen();
      return;
    }
    // 兜底（含 5 SVG：本地高亮规则没有 SVG 路径字段，按实线画）
    canvas.attachPen(pen);
    canvas.drawLine(startX, lineY, endX, lineY);
    canvas.detachPen();
  }

  private drawMarkingUnderlines(canvas: drawing.Canvas, item: LocalReaderLineItem,
    built: ReaderCanvasParagraph, left: number, top: number, request: ReaderCanvasDrawRequest): void {
    if (request.markings.length === 0) {
      return;
    }
    const pen = new drawing.Pen();
    pen.setStrokeWidth(Math.max(1, request.style.underlineWidthPx));
    pen.setAntiAlias(true);
    for (const marking of request.markings) {
      if (marking.decoration === 0) {
        continue;
      }
      const start = Math.max(marking.start, item.startPosition);
      const end = Math.min(marking.end, item.endPosition);
      if (end <= start) {
        continue;
      }
      pen.setColor(readerCanvasColor(marking.decorationArgb));
      if (marking.decoration === 2 && request.style.dashIntervals.length >= 2) {
        pen.setPathEffect(drawing.PathEffect.createDashPathEffect(request.style.dashIntervals, 0));
      } else {
        pen.setPathEffect(null);
      }
      canvas.attachPen(pen);
      const boxes = built.paragraph.getRectsForRange(
        { start: start - item.startPosition, end: end - item.startPosition },
        text.RectWidthStyle.TIGHT,
        text.RectHeightStyle.TIGHT
      );
      for (const box of boxes) {
        const y = top + box.rect.bottom;
        canvas.drawLine(left + box.rect.left, y, left + box.rect.right, y);
      }
      canvas.detachPen();
    }
  }

  /** 段落缓存：key 必须含全部影响排版与外观的输入，否则样式切换会命中旧段落。 */
  /** 分段样式的缓存签名：任何一栏变化都必须换 key。 */
  private static styleSignature(ranges: ReaderCanvasStyleRange[]): string {
    let out = '';
    for (const range of ranges) {
      out += `${range.start}-${range.end}-${range.textColorArgb}-${range.backgroundArgb}-` +
        `${range.decoration}-${range.decorationArgb}-${range.bgImage}-${range.bgImageFit}-` +
        `${range.bgImageScale}-${range.npLeft}-${range.npRight}-${range.npTop}-${range.npBottom}-` +
        `${range.bgLengthOffsetLeft}-${range.bgLengthOffsetRight}-` +
        `${range.fontFamilies.join(',')}-${range.fontWeightValue}-${range.italicOverride}-` +
        `${range.fontSizeOffsetPx}-${range.letterSpacingBeforePx}-${range.letterSpacingAfterPx};`;
    }
    return out;
  }

  /**
   * 按区间边界把一段文字切成「文本 + 生效样式」的小段。
   * 区间顺序即优先级：后出现的覆盖先出现的（高亮规则在前、用户划线在后）。
   */
  private static splitStyledSegments(value: string,
    ranges: ReaderCanvasStyleRange[]): ReaderCanvasStyledSegment[] {
    if (ranges.length === 0) {
      return [{ text: value, range: undefined }];
    }
    const points: number[] = [0, value.length];
    for (const range of ranges) {
      points.push(Math.max(0, Math.min(value.length, range.start)));
      points.push(Math.max(0, Math.min(value.length, range.end)));
    }
    points.sort((left: number, right: number) => left - right);
    const cuts: number[] = [];
    for (const point of points) {
      if (cuts.length === 0 || cuts[cuts.length - 1] !== point) {
        cuts.push(point);
      }
    }
    const segments: ReaderCanvasStyledSegment[] = [];
    for (let index = 0; index + 1 < cuts.length; index++) {
      const start = cuts[index];
      const end = cuts[index + 1];
      if (start === undefined || end === undefined || end <= start) {
        continue;
      }
      let winner: ReaderCanvasStyleRange | undefined = undefined;
      for (const range of ranges) {
        if (range.start <= start && range.end >= end) {
          winner = range;
        }
      }
      segments.push({ text: value.substring(start, end), range: winner });
    }
    return segments;
  }

  /**
   * 把基础 TextStyle 与一段生效样式合成。
   * 老路径用 `textBackgroundStyle` 铺底色，画布对应 `backgroundRect`；
   * 下划线对应 `decoration`（虚线/波浪/双线由 `decorationStyle` 表达）。
   */
  private static segmentStyle(base: text.TextStyle,
    range: ReaderCanvasStyleRange | undefined): text.TextStyle {
    if (range === undefined) {
      return base;
    }
    // 命中排版：字体族 / 字重 / 斜体 / 字号偏移逐项覆盖，规则里为 0 或空表示不覆盖。
    const baseFontSize: number = typeof base.fontSize === 'number' ? base.fontSize : 0;
    const baseLetterSpacing: number = typeof base.letterSpacing === 'number' ? base.letterSpacing : 0;
    const out: text.TextStyle = {
      fontFamilies: range.fontFamilies.length > 0 ? range.fontFamilies : base.fontFamilies,
      fontSize: range.fontSizeOffsetPx !== 0
        ? Math.max(1, baseFontSize + range.fontSizeOffsetPx) : base.fontSize,
      fontWeight: range.fontWeightValue > 0
        ? readerCanvasFontWeight(range.fontWeightValue) : base.fontWeight,
      fontStyle: range.italicOverride > 0 ? text.FontStyle.ITALIC
        : (range.italicOverride < 0 ? text.FontStyle.NORMAL : base.fontStyle),
      // 命中字距：上游把一次命中拆成首/中/尾三段，只有首字带 before、尾字带 after。
      // 走到这里的每段都只覆盖一个字，所以直接叠进 letterSpacing 就落在该字上。
      letterSpacing: baseLetterSpacing + range.letterSpacingBeforePx + range.letterSpacingAfterPx,
      color: range.textColorArgb !== 0 ? readerCanvasColor(range.textColorArgb) : base.color
    };
    // 底色不交给系统 backgroundRect：那是逐段铺色、相邻段之间会留缝。
    // 底色统一由 drawBackgroundBands 收集后合并成连续色带再画（上游 mergeBackgroundBounds）。
    // 只有 1 实线交给系统段落绘制；其余线型（虚线/波浪/双线/删除线/荧光）
    // 由 drawStyledUnderlines 手绘，口径才对得上上游。
    if (range.decoration === 1) {
      const decoration: text.Decoration = {
        textDecoration: ReaderCanvasRenderer.decorationType(range.decoration),
        color: readerCanvasColor(range.decorationArgb !== 0 ? range.decorationArgb : range.textColorArgb),
        decorationStyle: ReaderCanvasRenderer.decorationLineStyle(range.decoration),
        decorationThicknessScale: 1
      };
      out.decoration = decoration;
    }
    return out;
  }

  private static decorationType(mode: number): text.TextDecorationType {
    if (mode === 6) {
      return text.TextDecorationType.LINE_THROUGH;
    }
    if (mode >= 1 && mode <= 4) {
      return text.TextDecorationType.UNDERLINE;
    }
    return text.TextDecorationType.NONE;
  }

  private static decorationLineStyle(mode: number): text.TextDecorationStyle {
    if (mode === 2) {
      return text.TextDecorationStyle.DASHED;
    }
    if (mode === 3) {
      return text.TextDecorationStyle.WAVY;
    }
    if (mode === 4) {
      return text.TextDecorationStyle.DOUBLE;
    }
    return text.TextDecorationStyle.SOLID;
  }

  /** 取该元素命中的样式区间（换算成元素内局部下标，顺序不变）。 */
  private styleRangesForItem(item: LocalReaderLineItem,
    request: ReaderCanvasDrawRequest): ReaderCanvasStyleRange[] {
    const out: ReaderCanvasStyleRange[] = [];
    if (request.highlights.length === 0) {
      return out;
    }
    for (const range of request.highlights) {
      const start = Math.max(range.start, item.startPosition);
      const end = Math.min(range.end, item.endPosition);
      if (end <= start) {
        continue;
      }
      const local = new ReaderCanvasStyleRange();
      local.start = start - item.startPosition;
      local.end = end - item.startPosition;
      local.textColorArgb = range.textColorArgb;
      local.backgroundArgb = range.backgroundArgb;
      local.decoration = range.decoration;
      local.decorationArgb = range.decorationArgb;
      local.underlineWidthVp = range.underlineWidthVp;
      local.underlineOffsetVp = range.underlineOffsetVp;
      local.bgImage = range.bgImage;
      local.bgImageFit = range.bgImageFit;
      local.bgImageScale = range.bgImageScale;
      local.npLeft = range.npLeft;
      local.npRight = range.npRight;
      local.npTop = range.npTop;
      local.npBottom = range.npBottom;
      local.bgLengthOffsetLeft = range.bgLengthOffsetLeft;
      local.bgLengthOffsetRight = range.bgLengthOffsetRight;
      // 命中排版与字体替换：逐字段抄下来，漏一个就画不出来
      local.fontFamilies = range.fontFamilies;
      local.fontWeightValue = range.fontWeightValue;
      local.italicOverride = range.italicOverride;
      local.fontSizeOffsetPx = range.fontSizeOffsetPx;
      local.letterSpacingBeforePx = range.letterSpacingBeforePx;
      local.letterSpacingAfterPx = range.letterSpacingAfterPx;
      out.push(local);
    }
    return out;
  }

  /**
   * 章标题行用的段落：字号按 `titleFontScale` 缩放，字重/字色取标题样式。
   *
   * 上游标题与正文共用同一套 `StaticLayout` 排版通道，只是喂进去的是 titlePaint
   * （`LegacyReaderPaginationStyleFactory.kt:99-113`、`ReaderChapterBlockMeasurer.kt:259-262`）。
   * 这里同理：折进一个 `ReaderCanvasStyle` 后交给同一个 `getParagraph`，
   * 段落缓存与字形渲染都与正文一致，只是参数不同。
   */
  private titleParagraphStyle(request: ReaderCanvasDrawRequest, fontScale: number): ReaderCanvasStyle {
    const titleStyle = request.titleStyle;
    const scale = fontScale > 0 ? fontScale : 1;
    const style = new ReaderCanvasStyle();
    style.colorArgb = titleStyle.colorArgb;
    style.fontFamilies = titleStyle.fontFamilies;
    style.fontSizePx = Math.max(1, titleStyle.fontSizePx * scale);
    style.fontWeight = titleStyle.fontWeight;
    style.italic = false;
    style.letterSpacingPx = titleStyle.letterSpacingPx;
    // 标题不参与正文的下划线/标记下划线，这里全部关掉。
    style.underline = false;
    style.underlineExtend = false;
    style.dashIntervals = [];
    style.imagePlaceholderArgb = request.style.imagePlaceholderArgb;
    return style;
  }

  /**
   * 元素该用哪套样式：标题元素走 `titleStyle`，其余走正文 `style`。
   * 上游标题与正文是两套 paint，但共用同一条排版通道
   * （`LegacyReaderPaginationStyleFactory.kt:99-113`）。
   */
  private itemTextStyle(request: ReaderCanvasDrawRequest, item: LocalReaderLineItem): ReaderCanvasStyle {
    const scale = item.titleFontScale;
    if (scale === undefined) {
      return request.style;
    }
    return this.titleParagraphStyle(request, scale);
  }

  /**
   * 元素该带哪些命中样式区间：标题不带。
   * 标题字符不在正文坐标里（`startPosition/endPosition` 都是 0），套用正文区间会错位。
   */
  private itemStyleRanges(request: ReaderCanvasDrawRequest, item: LocalReaderLineItem): ReaderCanvasStyleRange[] {
    if (item.titleFontScale !== undefined) {
      return [];
    }
    return this.styleRangesForItem(item, request);
  }

  /**
   * 标题页垂直居中时整页元素要下移多少（px）。
   *
   * 上游 `ReaderPaginator.kt:369-389`：页成型后量出本页元素总高，按
   * `(contentBottom - contentTop - pageHeight) / 2` 平移。这里同样只对
   * `page.centerVertical` 的页生效（上游由 `titlePageCenterVertical` 决定）。
   */
  private pageCenterOffset(page: LocalReaderPage, request: ReaderCanvasDrawRequest): number {
    const layout = request.layout;
    const vp = Math.max(0.0001, layout.vpScale);
    let total = 0;
    for (let index = 0; index < page.lines.length; index++) {
      const line = page.lines[index];
      if (line === undefined) { continue; }
      total += (line.verticalSpaceBefore + line.height + line.paragraphSpacingAfter) * vp;
    }
    return Math.max(0, (layout.bodyHeightPx - total) / 2);
  }

  private getParagraph(value: string, style: ReaderCanvasStyle, widthPx: number,
    extraSpacingPx: number = 0, ranges: ReaderCanvasStyleRange[] = []): ReaderCanvasParagraph | undefined {
    if (value.length === 0) {
      return undefined;
    }
    // extraSpacingPx 是行内拉伸叠进 letterSpacing 的部分，必须进 key，否则拉伸量不同的行会命中同一段落
    const letterSpacingPx = style.letterSpacingPx + extraSpacingPx;
    // 分段样式也要进 key：同一段文字在不同高亮规则下是不同的段落
    const signature = ranges.length === 0 ? '' : ReaderCanvasRenderer.styleSignature(ranges);
    const key = `${style.fontFamilies.join(',')}|${style.fontSizePx}|${style.fontWeight}|${style.italic ? 1 : 0}` +
      `|${letterSpacingPx}|${Math.round(widthPx)}|${signature}|${value}`;
    const cached = this.paragraphCache.get(key);
    if (cached !== undefined) {
      return cached;
    }
    let built: ReaderCanvasParagraph | undefined = undefined;
    try {
      const textStyle: text.TextStyle = {
        fontFamilies: style.fontFamilies.length > 0 ? style.fontFamilies : undefined,
        fontSize: style.fontSizePx,
        fontWeight: readerCanvasFontWeight(style.fontWeight),
        fontStyle: style.italic ? text.FontStyle.ITALIC : text.FontStyle.NORMAL,
        letterSpacing: letterSpacingPx,
        color: readerCanvasColor(style.colorArgb)
      };
      const paragraphStyle: text.ParagraphStyle = {
        textStyle: textStyle,
        align: text.TextAlign.START,
        maxLines: 1
      };
      const builder = new text.ParagraphBuilder(paragraphStyle, text.FontCollection.getGlobalInstance());
      const segments = ReaderCanvasRenderer.splitStyledSegments(value, ranges);
      if (segments.length <= 1 && ranges.length === 0) {
        builder.pushStyle(textStyle);
        builder.addText(value);
      } else {
        // 分段：每段 pushStyle 后再 addText，等价于老路径的逐样式 Span
        for (const segment of segments) {
          builder.pushStyle(ReaderCanvasRenderer.segmentStyle(textStyle, segment.range));
          builder.addText(segment.text);
          builder.popStyle();
        }
      }
      const paragraph = builder.build();
      // 排版宽度要比测量宽度留一点余量：分页器的宽度是「测量结果 + 字间距」算出来的，
      // 与 Paragraph 自己带 letterSpacing 的真实排版可能差零点几 px；若按 item.width 精确排版，
      // 超出的那一点会被 maxLines:1 直接截掉，等于丢字。余量给一个字号，画的时候仍从 left 起画。
      paragraph.layoutSync(Math.max(1, widthPx) + Math.ceil(Math.max(1, style.fontSizePx)));
      built = { paragraph: paragraph, heightPx: paragraph.getHeight() };
    } catch (error) {
      console.warn(`[ReaderCanvas] 段落构建失败: ${error}`);
      return undefined;
    }
    if (this.paragraphCache.size >= ReaderCanvasRenderer.PARAGRAPH_CACHE_LIMIT) {
      this.paragraphCache.clear();
    }
    this.paragraphCache.set(key, built);
    return built;
  }
}
