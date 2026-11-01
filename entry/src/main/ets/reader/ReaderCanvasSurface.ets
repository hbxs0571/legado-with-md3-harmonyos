import { text, drawing, common2D } from '@kit.ArkGraphics2D';
import { image } from '@kit.ImageKit';
import { LocalReaderLine, LocalReaderLineItem, LocalReaderPage } from '../pages/LocalReaderPaginator';
import {
  CurlPoint, PageCurlFrame, PageCurlGeometry, ReaderCurlRenderPaths, ReaderCurlTouchPolicy,
  ReaderCurlVisualPolicy
} from './ReaderPageCurl';

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
    movingForward?: boolean, cancelled: boolean = false): ReaderTransitionDecision {
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
      : (transition.progress() >= ReaderPageTransitionPolicy.COMMIT_PROGRESS || velocityCommits);
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
  /** 底部对齐的逐行位移（vp 的对齐值已换算成 px）。 */
  bottomJustifyGapPx: number = 0;
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

/** 一条高亮 / 笔记标记，start/end 是渲染坐标（与 LocalReaderLineItem 同口径）。 */
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
  markings: ReaderCanvasMarking[] = [];
  /** 页面底色（画布先整体铺一层，滚动/翻页时就靠它保证不透明）。 */
  pageBackgroundArgb: number = 0xFFFFFFFF;
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
  /** 绘制后回填：选区首/末矩形与两个把手位置（px），调用方拿来给菜单定位。 */
  selectionStartX: number = 0;
  selectionStartY: number = 0;
  selectionEndX: number = 0;
  selectionEndY: number = 0;
  selectionTopY: number = 0;
  selectionBottomY: number = 0;
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
  /** 折页五条路径与镜像矩阵，逐帧复用（Path.rewind 清形不换对象）。 */
  private curlPaths: ReaderCurlRenderPaths = new ReaderCurlRenderPaths();

  private static readonly PARAGRAPH_CACHE_LIMIT: number = 1024;
  private static readonly IMAGE_CACHE_LIMIT: number = 32;

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

  clear(): void {
    this.paragraphCache.clear();
    for (const pixelMap of this.imageCache.values()) {
      pixelMap.release();
    }
    this.imageCache.clear();
    this.imageLoading.clear();
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
    // z 序严格照上游 ReaderCanvasSurface.kt:1643-1663：
    //   currentOnTop && drawsNext → next
    //   → current
    //   → drawsPrevious → previous
    //   → !currentOnTop && drawsNext → next
    // 不能简单地「按方向前后颠倒」：PREVIOUS 时 currentOnTop=false，
    // previous 必须画在 current 之上（它才是滑进来的那一页）。
    if (transforms.currentOnTop && transforms.drawsNext) {
      this.drawSlot(canvas, window.next, transforms.next, request);
    }
    this.drawSlot(canvas, window.current, transforms.current, request);
    if (transforms.drawsPrevious) {
      this.drawSlot(canvas, window.previous, transforms.previous, request);
    }
    if (!transforms.currentOnTop && transforms.drawsNext) {
      this.drawSlot(canvas, window.next, transforms.next, request);
    }
  }

  private drawSlot(canvas: drawing.Canvas, slot: ReaderCanvasPage | undefined,
    transform: ReaderPageTransform, request: ReaderCanvasDrawRequest): void {
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
    this.drawPage(canvas, slot.page, slot.pageIndex, request);
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
      this.drawSlot(canvas, revealSlot, new ReaderPageTransform(), request);
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
      this.drawPage(canvas, revealSlot.page, revealSlot.pageIndex, request);
      canvas.save();
      canvas.translate(isPrevious ? -width : 0, 0);
      this.drawPage(canvas, baseSlot.page, baseSlot.pageIndex, request);
      canvas.restore();
      return;
    }
    const paths = this.curlPaths.update(frame, width, height);
    // 1) 底页整页：月牙区靠它兜底，必须先铺纸面再画字（见 pageSurfaceArgb 注释）
    this.fillPageSurface(canvas, request, width, height);
    this.drawPage(canvas, baseSlot.page, baseSlot.pageIndex, request);
    // 2) 折页下方露出的下一页 + 背面阴影
    canvas.save();
    canvas.clipPath(paths.front, drawing.ClipOp.INTERSECT, true);
    canvas.clipPath(paths.reveal, drawing.ClipOp.INTERSECT, true);
    this.fillPageSurface(canvas, request, width, height);
    this.drawPage(canvas, revealSlot.page, revealSlot.pageIndex, request);
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
    this.drawPage(canvas, baseSlot.page, baseSlot.pageIndex, request);
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
    request: ReaderCanvasDrawRequest): void {
    const geometry = this.layoutPage(page, pageIndex, request);
    this.geometry = geometry;
    for (const box of geometry.boxes) {
      if (box.item === undefined) {
        continue;
      }
      if (box.item.kind === 'image') {
        this.drawImageBox(canvas, box, request);
      } else {
        this.drawTextBox(canvas, box, request);
      }
    }
    // 行下划线最后画，压住文字下缘（与改造前的绘制顺序一致）
    if (request.style.underline) {
      for (const lineBox of geometry.lines) {
        if (lineBox.line !== undefined) {
          this.drawLineUnderline(canvas, lineBox, request);
        }
      }
    }
    this.drawSelection(canvas, geometry, request);
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
    for (let index = 0; index < page.lines.length; index++) {
      const line = page.lines[index];
      const column = page.lineColumns.length > index ? page.lineColumns[index] : 0;
      const safeColumn = Math.min(columnCount - 1, Math.max(0, column));
      // 底部对齐：按行序号在行 y 坐标上摊分（上游 justifyColumnBottom 是逐行 offsetY 平移，
      // 不改变布局流；画布本来就是绝对坐标，等价于直接加到 y 上）。
      const top = layout.originYpx + used[safeColumn] + line.verticalSpaceBefore * vp +
        layout.bottomJustifyGapPx * lineCount[safeColumn];
      const left = layout.originXpx + safeColumn * stride;
      const lineBox = new ReaderCanvasLineBox();
      lineBox.line = line;
      lineBox.lineIndex = index;
      lineBox.left = left;
      lineBox.top = top;
      lineBox.heightPx = Math.max(1, line.height * vp);
      geometry.lines.push(lineBox);
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
          const built = this.getParagraph(item.value, request.style, box.widthPx, extraSpacingPx);
          const builtHeight = built !== undefined ? built.heightPx : line.height * vp;
          box.top = top + Math.max(0, (line.height * vp - builtHeight) / 2);
          box.heightPx = builtHeight;
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

  /** 文字元素：标记底色 → 字形 → 标记下划线（上游同序）。 */
  private drawTextBox(canvas: drawing.Canvas, box: ReaderCanvasItemBox,
    request: ReaderCanvasDrawRequest): void {
    const item = box.item;
    if (item === undefined) {
      return;
    }
    const built = this.getParagraph(item.value, request.style, box.widthPx, box.extraSpacingPx);
    if (built === undefined) {
      return;
    }
    this.drawMarkingBackgrounds(canvas, item, built, box.left, box.top, request);
    // Paragraph.paint 会改动 canvas 的画笔/裁剪状态且不恢复，
    // 后面还要用同一块画布画选区，所以这里必须 save/restore 兜住。
    canvas.save();
    built.paragraph.paint(canvas, box.left, box.top);
    canvas.restore();
    this.drawMarkingUnderlines(canvas, item, built, box.left, box.top, request);
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
      const built = this.getParagraph(item.value, request.style, box.widthPx, box.extraSpacingPx);
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
    request.selectionStartX = firstRect.left;
    request.selectionStartY = (firstRect.top + firstRect.bottom) / 2;
    request.selectionEndX = lastRect.right;
    request.selectionEndY = (lastRect.top + lastRect.bottom) / 2;
    request.selectionTopY = Math.min(firstRect.top, lastRect.top);
    request.selectionBottomY = Math.max(firstRect.bottom, lastRect.bottom);
    // 把手：上游 SelectionHandleRadius = 7.dp、SelectionHandleStrokeWidth = 2.dp
    const radius = Math.max(0, request.handleRadiusPx);
    if (radius <= 0) {
      return;
    }
    const handleBrush = new drawing.Brush();
    handleBrush.setColor(readerCanvasColor(request.handleFillArgb));
    handleBrush.setAntiAlias(true);
    canvas.attachBrush(handleBrush);
    canvas.drawCircle(request.selectionStartX, request.selectionStartY, radius);
    canvas.drawCircle(request.selectionEndX, request.selectionEndY, radius);
    canvas.detachBrush();
    const strokeWidth = Math.max(1, request.handleStrokeWidthPx);
    const pen = new drawing.Pen();
    pen.setColor(readerCanvasColor(request.handleStrokeArgb));
    pen.setStrokeWidth(strokeWidth);
    pen.setAntiAlias(true);
    canvas.attachPen(pen);
    canvas.drawCircle(request.selectionStartX, request.selectionStartY, radius);
    canvas.drawCircle(request.selectionEndX, request.selectionEndY, radius);
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

  /** 盒内字形偏移：屏幕点先换算成段落局部坐标，再问 Paragraph。 */
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
  private getParagraph(value: string, style: ReaderCanvasStyle, widthPx: number,
    extraSpacingPx: number = 0): ReaderCanvasParagraph | undefined {
    if (value.length === 0) {
      return undefined;
    }
    // extraSpacingPx 是行内拉伸叠进 letterSpacing 的部分，必须进 key，否则拉伸量不同的行会命中同一段落
    const letterSpacingPx = style.letterSpacingPx + extraSpacingPx;
    const key = `${style.fontFamilies.join(',')}|${style.fontSizePx}|${style.fontWeight}|${style.italic ? 1 : 0}` +
      `|${letterSpacingPx}|${Math.round(widthPx)}|${value}`;
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
      builder.pushStyle(textStyle);
      builder.addText(value);
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
