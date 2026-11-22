// 颜色线性插值（Compose `lerp(Color, Color, Float)` 的等价物）。
//
// 上游有多处 `lerp` 调用，其中两处与本模块直接相关：
//   - `ui/widget/components/image/cover/CoverBlurBackdrop.kt:25` `lerp(secondaryContainer, seedColor, 0.42f)`
//   - `ui/book/info/BookInfoScreen.kt:951-955` 同一个 0.42 插值（详情页背景）
//   - `ui/book/info/BookInfoScreen.kt:1196` `lerp(surface, seedColor, 0.08f)`
//
// Compose 的 `lerp` 按 sRGB 分量逐通道线性插值再四舍五入，不经过线性空间。
// 这里照做，保证与上游同色。

/**
 * 两个 `#RRGGBB` 按 t 线性插值，返回 `#RRGGBB`。
 *
 * 任一侧不足 7 位（空串或 `#00000000` 这类）时返回 `to` —— 上游对 Unspecified 色
 * 的处理也是直接取另一侧，不做插值。
 */
export function lerpHexColor(from: string, to: string, t: number): string {
  if (from.length < 7 || to.length < 7) {
    return to;
  }
  const clamp: (value: number) => number = (value: number) =>
    Math.max(0, Math.min(255, Math.round(value)));
  const mix: (offset: number) => number = (offset: number) =>
    clamp(parseInt(from.substring(offset, offset + 2), 16) * (1 - t)
      + parseInt(to.substring(offset, offset + 2), 16) * t);
  const hex: (value: number) => string = (value: number) =>
    value.toString(16).padStart(2, '0').toUpperCase();
  return `#${hex(mix(1))}${hex(mix(3))}${hex(mix(5))}`;
}

/**
 * 给 `#RRGGBB` 拼一个 8 位 alpha 前缀（`#AARRGGBB`）。
 *
 * 上游对应 `color.copy(alpha = ...)`：只换 alpha，RGB 原样保留。
 * 传入的色若已经是 8 位，取后 6 位 RGB 重新拼。
 */
export function withAlphaHex(color: string, alpha: number): string {
  if (color.length < 7) {
    return color;
  }
  const byte: number = Math.max(0, Math.min(255, Math.round(alpha * 255)));
  const hex: string = byte.toString(16).padStart(2, '0').toUpperCase();
  return `#${hex}${color.substring(color.length - 6)}`;
}
