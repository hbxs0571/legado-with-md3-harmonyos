/**
 * 多栏布局的纯函数层，逐条对齐上游 `ui/main/MainAdaptiveLayout.kt`（186 行）与
 * `ui/widget/components/navigation/AppAdaptiveNavigation.kt:56-85`。
 *
 * 上游把「能不能并排两栏」拆成三层：
 *   1. `MainAdaptiveLayoutEnvironment.paneLayout(isContainer)` 算窗格矩形（含折叠屏铰链）；
 *   2. `shouldUseListDetail(mode, windowSizeClass, windowSize)` 判用户档位与窗口断点；
 *   3. `MainActivity.kt:505-577` 把两者串起来，决定用双栏场景还是单栏场景。
 * 本地没有 Navigation 3 的场景策略，`pages/Index.ets` 用 `@State route` 手工分派页面，
 * 所以这一层只保留纯计算，由页面自己去摆放两个窗格。
 *
 * 常量取上游同名值（`MainAdaptiveLayout.kt:29-31`）：左栏最低 360vp、窗格最低高 320vp、
 * 两栏之间 24vp 沟槽。断点取 `WindowSizeClass` 的规范值（`AppAdaptiveNavigation.kt:71-85`）：
 * 自动与横屏档用 840（`WIDTH_DP_EXPANDED_LOWER_BOUND`），始终开启档用 744。
 */

/** 左栏最低宽度（vp），对齐上游 `MainAdaptiveLayout.kt:29 MainPaneMinWidth = 360f`。 */
export const MAIN_PANE_MIN_WIDTH: number = 360;

/** 每个窗格的最低高度（vp），对齐上游 `MainAdaptiveLayout.kt:30 MainPaneMinHeight = 320f`。 */
export const MAIN_PANE_MIN_HEIGHT: number = 320;

/** 两栏之间的沟槽（vp），对齐上游 `MainAdaptiveLayout.kt:31 MainPaneGap = 24f`。 */
export const MAIN_PANE_GAP: number = 24;

/** 左栏是普通列表时的首选宽度（vp），对齐 `ListDetailSceneStrategy.kt:47 ListPaneWidth = 360.dp`。 */
export const LIST_PANE_WIDTH: number = 360;

/** 左栏是首页这类容器时的首选宽度（vp），对齐 `ListDetailSceneStrategy.kt:44 ContainerPaneWidth = 420.dp`。 */
export const CONTAINER_PANE_WIDTH: number = 420;

/** 自动 / 横屏档的宽度断点（vp），对齐 `WindowSizeClass.WIDTH_DP_EXPANDED_LOWER_BOUND`（840）。 */
export const EXPANDED_WIDTH_BREAKPOINT: number = 840;

/** 「始终开启」档的宽度断点（vp），对齐 `AppAdaptiveNavigation.kt:83` 的 `isWidthAtLeastBreakpoint(744)`。 */
export const ALWAYS_WIDTH_BREAKPOINT: number = 744;

/** 多栏布局档位，对齐上游 `MultiPaneMode`（`AppAdaptiveNavigation.kt:56-63`）。 */
export const MULTI_PANE_VALUES: string[] = ['auto', 'landscape', 'always', 'off'];

/** 默认档位，对齐上游 `AppShellSettings.kt:18 multiPaneMode = "auto"`。 */
export const MULTI_PANE_DEFAULT: string = 'auto';

/** 未知取值回落 `auto`（上游 `MultiPaneMode.parse` 的 `?: Auto`）。 */
export function normalizeMultiPaneMode(value: string): string {
  return MULTI_PANE_VALUES.includes(value) ? value : MULTI_PANE_DEFAULT;
}

/** 档位显示名，文案取上游 `values-zh-rCN/multi_pane.xml:4-7`。 */
export function multiPaneModeLabel(value: string): string {
  if (value === 'landscape') { return '横屏开启（宽窗口）'; }
  if (value === 'always') { return '始终开启（空间足够时）'; }
  if (value === 'off') { return '关闭'; }
  return '自动（宽窗口）';
}

/**
 * 是否用双栏，逐条对齐上游 `AppAdaptiveNavigation.kt:71-85` 的 `shouldUseListDetail`：
 * auto → 宽度 ≥ 840；landscape → 横屏且宽度 ≥ 840；always → 宽度 ≥ 744；off → 恒假。
 */
export function shouldUseListDetail(multiPaneMode: string, widthVp: number, heightVp: number): boolean {
  const mode = normalizeMultiPaneMode(multiPaneMode);
  if (mode === 'off') { return false; }
  if (mode === 'always') { return widthVp >= ALWAYS_WIDTH_BREAKPOINT; }
  if (mode === 'landscape') { return widthVp > heightVp && widthVp >= EXPANDED_WIDTH_BREAKPOINT; }
  return widthVp >= EXPANDED_WIDTH_BREAKPOINT;
}

/** 一个窗格的矩形（vp），对齐上游 `MainPaneLayout` 里的 `Rect`。 */
export interface MainPaneBounds {
  left: number;
  top: number;
  width: number;
  height: number;
}

/** 双栏结果，对齐上游 `MainPaneLayout(listBounds, detailBounds, usesHinge)`。 */
export interface MainPaneLayout {
  listBounds: MainPaneBounds;
  detailBounds: MainPaneBounds;
  /** 是否由折叠屏铰链分区得出（上游 `usesHinge`）。 */
  usesHinge: boolean;
}

/**
 * 算双栏的两个窗格；返回 `null` 表示应当单栏。
 *
 * 逐条对齐上游 `MainAdaptiveLayout.kt:154-186 paneLayout(isContainer)`：
 * 1. `off` 档直接返回 null；
 * 2. `landscape` 档在竖屏返回 null；
 * 3. 左栏最低宽度要加上导航侧栏宽度（`listMinWidth = MainPaneMinWidth + navigationRailWidth`）；
 * 4. 总宽不够 `listMinWidth + 24 + 360` 或高度不够 320 时返回 null；
 * 5. `shouldUseListDetail` 不通过时返回 null；
 * 6. 左栏首选宽度：容器 420、普通列表 360，且不超过 `总宽 - 24 - 360`。
 *
 * **不含铰链分支**：上游 `safeRegions()` 处理折叠屏 separating/occluding 铰链，本地 ArkUI 拿不到
 * 铰链几何（SDK 里没有 hinge 相关 API），所以 `usesHinge` 恒为 false。这一条要在报告里记账。
 */
export function paneLayout(
  multiPaneMode: string,
  widthVp: number,
  heightVp: number,
  navigationRailWidthVp: number,
  isContainer: boolean
): MainPaneLayout | null {
  const mode = normalizeMultiPaneMode(multiPaneMode);
  if (mode === 'off') { return null; }
  if (mode === 'landscape' && widthVp <= heightVp) { return null; }
  const railWidth = Math.max(0, navigationRailWidthVp);
  const listMinWidth = MAIN_PANE_MIN_WIDTH + railWidth;
  const minimumWidth = listMinWidth + MAIN_PANE_GAP + MAIN_PANE_MIN_WIDTH;
  if (widthVp < minimumWidth || heightVp < MAIN_PANE_MIN_HEIGHT) { return null; }
  if (!shouldUseListDetail(mode, widthVp, heightVp)) { return null; }
  const preferred = isContainer ? Math.max(CONTAINER_PANE_WIDTH, listMinWidth) : listMinWidth;
  const listWidth = Math.min(preferred, widthVp - MAIN_PANE_GAP - MAIN_PANE_MIN_WIDTH);
  return {
    listBounds: { left: 0, top: 0, width: listWidth, height: heightVp },
    detailBounds: {
      left: listWidth + MAIN_PANE_GAP,
      top: 0,
      width: widthVp - listWidth - MAIN_PANE_GAP,
      height: heightVp
    },
    usesHinge: false
  };
}

/**
 * 左栏宽度，对齐上游 `ListDetailSceneStrategy.kt:240-245 listPaneWidthOf`：
 * 容器 420、普通列表 360，上限是 `总宽 - 24 - 360`（且不低于 360）。
 */
export function listPaneWidthOf(totalWidthVp: number, isContainer: boolean): number {
  const preferred = isContainer ? CONTAINER_PANE_WIDTH : LIST_PANE_WIDTH;
  const upperBound = Math.max(totalWidthVp - MAIN_PANE_GAP - MAIN_PANE_MIN_WIDTH, LIST_PANE_WIDTH);
  return Math.min(preferred, upperBound);
}

/** 双栏相对上一次栈顶形态的到达方式，对齐上游 `PaneArrival`（`ListDetailSceneStrategy.kt:252-270`）。 */
export enum PaneArrival {
  /** 从单栏进来：左栏从占满窗口收到窗格宽度，右栏从右侧滑入。 */
  Expand = 'expand',
  /** 左栏没变、只换了右栏。 */
  Swap = 'swap',
  /** 上一层的右栏成了这一层的左栏（下钻二级页面）。 */
  Promote = 'promote',
  /** 组合与上一次无关：直接落到目标形态，不做形变。 */
  Replace = 'replace',
  /** 与上一次是同一组合：维持现状，不重播动画。 */
  Settled = 'settled'
}

/** 纯函数版到达方式判定，对齐上游 `ListDetailSceneStrategy.kt:275-284 paneArrival`。 */
export function paneArrival(previous: string[] | null, next: string[]): PaneArrival {
  if (previous === null) { return PaneArrival.Expand; }
  if (previous.length === next.length && previous.every((key: string, index: number) => key === next[index])) {
    return PaneArrival.Settled;
  }
  if (previous.length === 2 && next.length === 2) {
    if (previous[0] === next[0]) { return PaneArrival.Swap; }
    if (previous[1] === next[0]) { return PaneArrival.Promote; }
  }
  return PaneArrival.Replace;
}
