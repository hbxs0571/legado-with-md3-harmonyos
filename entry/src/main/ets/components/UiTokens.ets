/**
 * UI 度量令牌：字号、间距、圆角的唯一来源。
 *
 * 取值依据是上游 M3 语义阶梯（上游 app/src/main/java/io/legado/app/ui/theme/Typography.kt
 * 的 miuixStylesToM3Typography()），不是历代页面里手写出来的数字。
 *
 * 改这个文件等于改全仓视觉，务必单独构建 + 上机看过再提交。
 */

// ── 字号 ──────────────────────────────────────────────


// ── 间距 ──────────────────────────────────────────────

export const SPACE_2: number = 2;
export const SPACE_4: number = 4;
export const SPACE_8: number = 8;
export const SPACE_12: number = 12;
export const SPACE_16: number = 16;
export const SPACE_20: number = 20;
export const SPACE_24: number = 24;

// ── 设置页布局 ────────────────────────────────────────

/** 设置行左右内边距（上游 M3 adaptiveHorizontalPadding = 16dp） */
export const ROW_PADDING_H: number = 16;
/** 设置行上下内边距（16 号字行高 + 上下 14 ≈ M3 列表项 56vp） */
export const ROW_PADDING_V: number = 14;
/** 区块标题与卡片之间的间距 */
export const SECTION_TITLE_TOP: number = 14;
export const SECTION_TITLE_BOTTOM: number = 8;
/** 区块卡片之间的间距 */
export const SECTION_GAP: number = 8;
/** 行内展开区（文本框 + 默认/确定）的内边距 */
export const EXPAND_PADDING_BOTTOM: number = 12;
export const EXPAND_BUTTONS_TOP: number = 12;
export const EXPAND_BUTTONS_BOTTOM: number = 8;

// ── 圆角 ──────────────────────────────────────────────

// 卡片圆角**不在这里**：它由主题系统拥有（themeCardRadius，
// 归一化函数在 data/ThemeCardStyle.ets 的 normalizeCardCornerRadius）。
// 这里只定义卡片内部的固定圆角。

/** 行内输入框、菜单弹层的圆角 */
export const RADIUS_INNER: number = 8;

// ── 动效 ──────────────────────────────────────────────

// 注意：弹簧曲线（curves.springMotion 等）不能配 duration，
// 物理时长由参数与前次速度决定，也拿不到 interpolate 归一化。
// 所以有 duration 的常量只给「不适用弹簧」的场景——主要是淡入淡出。

/** 淡入淡出时长（全仓 33 处淡入淡出用它，是绝对主流值） */
export const DURATION_FADE: number = 220;
/** 页面切换的缩放过渡时长 */
export const DURATION_PAGE_SWITCH: number = 300;
/** 头部折叠的滚动阈值：向下滚超过这个就折叠 */
export const HEADER_COLLAPSE_THRESHOLD: number = 70;
/** 头部展开的滚动阈值：向上滚低于这个就展开（与上一条之间的区间用于防抖） */
export const HEADER_EXPAND_THRESHOLD: number = 24;
