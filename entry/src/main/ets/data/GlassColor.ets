/**
 * 玻璃（毛玻璃卡片 / 栏）底色与模糊半径的统一入口。
 *
 * 上游依据：
 *   - `ui/widget/components/GlassDefaults.kt:16-23`：
 *     `glassColor(noBlurColor, blurAlpha) = if (enableBlur) noBlurColor.copy(alpha = blurAlpha) else noBlurColor`
 *     —— 关模糊时不是「alpha 变小」，而是**完全不透明**。
 *   - `ui/theme/HazeStyle.kt:39/75/104`：三个 haze 扩展都是 `if (!enableBlur) return this`，
 *     即关模糊时连模糊层都不挂。
 *
 * 本地原来把 alpha 硬编码在 20 个调用点上、模糊半径也硬编码（12/16/20），
 * 「模糊效果」开关对这些玻璃控件完全没有作用。这里把两件事收成一处，
 * 调用方只需要传「开模糊时的目标值」。
 *
 * `enableBlur` 走 AppStorage 读取：这些玻璃控件分散在朗读面板、播放器、阅读页里，
 * 都不是 `ThemeSettingsPage` 的子树，拿不到 `@Prop`。纯函数里读 AppStorage 是本仓既有做法
 * （见 `data/PrivateAccessRepository.ets:176-193`）。
 */

const ENABLE_BLUR_KEY: string = 'themeEnableBlur';

/** 「模糊效果」开关当前是否打开。 */
export function isGlassBlurEnabled(): boolean {
  return AppStorage.get<boolean>(ENABLE_BLUR_KEY) === true;
}

/**
 * 玻璃底色。
 *
 * 对齐上游 `GlassDefaults.glassColor()`：开模糊时把底色压到 `alpha`，关模糊时原样返回
 * （不是返回透明，也不是返回更淡的色）。`alpha` 只接受 0..1。
 */
export function resolveGlassColor(baseColor: string, alpha: number): string {
  if (!isGlassBlurEnabled()) {
    return baseColor;
  }
  const clamped: number = Math.max(0, Math.min(1, alpha));
  const a: number = Math.round(clamped * 255);
  let hex: string = a.toString(16);
  if (hex.length < 2) {
    hex = '0' + hex;
  }
  hex = hex.toUpperCase();
  if (baseColor.length === 7 && baseColor.charAt(0) === '#') {
    return '#' + hex + baseColor.substring(1);
  }
  // 已是 8 位或不是 #RRGGBB：按上游 `copy(alpha = ...)` 的语义替换 alpha 通道。
  if (baseColor.length === 9 && baseColor.charAt(0) === '#') {
    return '#' + hex + baseColor.substring(3);
  }
  return baseColor;
}

/**
 * 玻璃层的模糊半径。
 *
 * 对齐上游 `HazeStyle.kt` 三个扩展的 `if (!enableBlur) return this`：
 * 关模糊时不挂模糊层，等价于半径 0。
 */
export function resolveGlassBlurRadius(radius: number): number {
  return isGlassBlurEnabled() ? radius : 0;
}

function toHexByte(value: number): string {
  const text = Math.round(value).toString(16).toUpperCase();
  return text.length < 2 ? `0${text}` : text;
}

/** 解析 `#RRGGBB` / `#AARRGGBB`，拿不到时按白色算（与上游 `Color.copy` 的兜底一致）。 */
function parseRgb(color: string): number[] {
  const text = color.trim();
  if (text.length === 7) {
    return [parseInt(text.substring(1, 3), 16), parseInt(text.substring(3, 5), 16), parseInt(text.substring(5, 7), 16)];
  }
  if (text.length === 9) {
    return [parseInt(text.substring(3, 5), 16), parseInt(text.substring(5, 7), 16), parseInt(text.substring(7, 9), 16)];
  }
  return [255, 255, 255];
}

/**
 * 玻璃栏（顶栏 / 底栏）底色：`glassColor()` 之后再叠一层 `opacity`。
 *
 * 上游是两段相乘，不是一段：
 *   1. `GlassDefaults.glassColor(noBlurColor, blurAlpha)` —— 开模糊才把 alpha 压到 `blurAlpha`，
 *      关模糊保持不透明（`ui/widget/components/GlassDefaults.kt:16-23`）；
 *   2. 再乘 `topBarOpacity / 100`（`GlassTopAppBarDefaults.applyTopBarOpacity`，
 *      `ui/widget/components/topbar/GlassMediumFlexibleTopAppBar.kt:268-271`）或
 *      `bottomBarOpacity / 100`（`ui/widget/components/navigation/AppNavigationBar.kt:60`）。
 *
 * 所以开模糊时的有效 alpha 是 `blurAlpha × opacity`，关模糊时是 `opacity`。
 * 结果 `>= 0.999` 时返回空串，表示「保持组件自己的资源色」，调用方据此不覆盖 backgroundColor。
 *
 * 这个方法原本在 `data/TopBottomBarSettings.ets` 里另写了一份（`resolveBarBackgroundColor`），
 * 与这里的 `resolveGlassColor` 是同一条上游规则的两半。批 6 合并到本文件，全仓只剩这一处实现。
 */
export function resolveGlassBarColor(
  baseColor: string,
  opacityPercent: number,
  blurAlphaPercent: number,
  enableBlur: boolean
): string {
  const opacity = Math.max(0, Math.min(1, opacityPercent / 100));
  const blurAlpha = Math.max(0, Math.min(1, blurAlphaPercent / 100));
  const effective = enableBlur ? blurAlpha * opacity : opacity;
  if (effective >= 0.999) {
    return '';
  }
  const channels = parseRgb(baseColor);
  const alpha = Math.round(effective * 255);
  return `#${toHexByte(alpha)}${toHexByte(channels[0])}${toHexByte(channels[1])}${toHexByte(channels[2])}`;
}
