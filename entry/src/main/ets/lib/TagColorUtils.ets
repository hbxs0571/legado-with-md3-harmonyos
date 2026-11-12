/**
 * 自定义标签配色算法。
 *
 * 对齐上游 ui/config/themeConfig/LabelColorManageSheet.kt 的取色器回调与
 * help/config/TagColorGenerator.kt 的整组生成：颜色以 ARGB int 存储
 * （与上游 TagColorPair 的 textColor / bgColor 同形），渲染时转 #AARRGGBB。
 * ArkTS 没有 Android 的 ColorUtils，这里自己实现 HSL 与 ARGB 互转。
 */
import { TagColorPair } from '../model/BookshelfLayout';

/** ARGB int 转 #AARRGGBB；0 表示「没设」，返回空串由渲染侧回落主题色。 */
export function argbToColorHex(color: number): string {
  if (color === 0) { return ''; }
  const unsigned = color >>> 0;
  const channel = (value: number): string => (value & 0xFF).toString(16).padStart(2, '0');
  return `#${channel(unsigned >>> 24)}${channel(unsigned >>> 16)}${channel(unsigned >>> 8)}${channel(unsigned)}`.toUpperCase();
}

/** 解析 #RRGGBB 或 #AARRGGBB 成 ARGB int；非法返回 0。 */
export function hexToArgb(hex: string): number {
  const bare = hex.trim().replace(/^#/, '');
  if (bare.length === 6) {
    const value = parseInt(`FF${bare}`, 16);
    return Number.isFinite(value) ? (value | 0) : 0;
  }
  if (bare.length === 8) {
    const value = parseInt(bare, 16);
    return Number.isFinite(value) ? (value | 0) : 0;
  }
  return 0;
}

/** ARGB int 转 HSL：返回 [色相 0..360, 饱和度 0..1, 亮度 0..1]。 */
export function argbToHsl(color: number): number[] {
  const unsigned = color >>> 0;
  const red = ((unsigned >>> 16) & 0xFF) / 255;
  const green = ((unsigned >>> 8) & 0xFF) / 255;
  const blue = (unsigned & 0xFF) / 255;
  const max = Math.max(red, green, blue);
  const min = Math.min(red, green, blue);
  const delta = max - min;
  const lightness = (max + min) / 2;
  let hue = 0;
  let saturation = 0;
  if (delta !== 0) {
    saturation = delta / (1 - Math.abs(2 * lightness - 1));
    if (max === red) { hue = ((green - blue) / delta) % 6; }
    else if (max === green) { hue = (blue - red) / delta + 2; }
    else { hue = (red - green) / delta + 4; }
    hue *= 60;
    if (hue < 0) { hue += 360; }
  }
  return [hue, saturation, lightness];
}

/** HSL 转 ARGB int（alpha 固定 0xFF）；色相单位为度，饱和度/亮度取 0..1。 */
export function hslToArgb(hue: number, saturation: number, lightness: number): number {
  const normalizedHue = ((hue % 360) + 360) % 360;
  const chroma = (1 - Math.abs(2 * lightness - 1)) * saturation;
  const second = chroma * (1 - Math.abs(((normalizedHue / 60) % 2) - 1));
  const offset = lightness - chroma / 2;
  let red = 0;
  let green = 0;
  let blue = 0;
  if (normalizedHue < 60) { red = chroma; green = second; }
  else if (normalizedHue < 120) { red = second; green = chroma; }
  else if (normalizedHue < 180) { green = chroma; blue = second; }
  else if (normalizedHue < 240) { green = second; blue = chroma; }
  else if (normalizedHue < 300) { red = second; blue = chroma; }
  else { red = chroma; blue = second; }
  const channel = (value: number): number => {
    const scaled = Math.round((value + offset) * 255);
    return scaled < 0 ? 0 : (scaled > 255 ? 255 : scaled);
  };
  return (0xFF000000 | (channel(red) << 16) | (channel(green) << 8) | channel(blue)) | 0;
}

/**
 * 取色器回调：用户只选文字色，背景色由它按 HSL 推导（同色相、低饱和、高亮度）。
 * 对齐上游 LabelColorManageSheet.kt:142-166：
 *   hsl[1] = (hsl[1] * 0.4f).coerceAtMost(0.35f)；hsl[2] = 0.90f。
 */
export function deriveTagBgColor(textColor: number): number {
  const hsl = argbToHsl(textColor);
  const saturation = Math.min(hsl[1] * 0.4, 0.35);
  return hslToArgb(hsl[0], saturation, 0.90);
}

/** 从主题色 hex 取基准色相（取不到用 220 度的蓝，对齐主题 primary 的近似值）。 */
export function baseHueFromHex(hex: string): number {
  const color = hexToArgb(hex);
  return color === 0 ? 220 : argbToHsl(color)[0];
}

/**
 * 整组生成 8 组配色，对齐上游 TagColorGenerator.kt：
 * 色相偏移 [0,45,90,135,180,225,270,315]；
 * 文字 HSL(hue, 0.75, 0.45)，背景 HSL(hue, 0.35, 0.90)。
 */
export function generateTagColors(baseHue: number): TagColorPair[] {
  const offsets: number[] = [0, 45, 90, 135, 180, 225, 270, 315];
  const result: TagColorPair[] = [];
  for (let index = 0; index < offsets.length; index++) {
    const hue = baseHue + (offsets[index] ?? 0);
    result.push({
      textColor: hslToArgb(hue, 0.75, 0.45),
      bgColor: hslToArgb(hue, 0.35, 0.90)
    });
  }
  return result;
}
