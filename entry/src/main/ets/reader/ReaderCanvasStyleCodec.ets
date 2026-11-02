import { ReaderMarking } from '../model/ReaderMarking';

/**
 * 画布样式的纯函数编解码：颜色串转 ARGB、标记效果转画布 decoration 口径、
 * 把手命中距离、长度量归一。
 *
 * 这些函数不碰任何页面状态，从 ReaderPage 里抽出来单放，目的是让「画布渲染」
 * 这块知识只在一个文件里，ReaderPage 只管把状态拼成请求。
 */

/** `#RGB` / `#RRGGBB` / `#AARRGGBB` / `'transparent'` → 0xAARRGGBB。解析失败用 fallback。 */
export function readerCanvasArgb(value: string, fallback: number): number {
  if (value.length === 0) {
    return fallback;
  }
  if (value === 'transparent') {
    return 0x00000000;
  }
  if (value.startsWith('#')) {
    const hex = value.substring(1);
    if (hex.length === 3) {
      const r = Number.parseInt(`${hex[0]}${hex[0]}`, 16);
      const g = Number.parseInt(`${hex[1]}${hex[1]}`, 16);
      const b = Number.parseInt(`${hex[2]}${hex[2]}`, 16);
      if (!Number.isNaN(r) && !Number.isNaN(g) && !Number.isNaN(b)) {
        return (0xFF << 24) | (r << 16) | (g << 8) | b;
      }
    } else if (hex.length === 6) {
      const parsed = Number.parseInt(hex, 16);
      if (!Number.isNaN(parsed)) {
        return (0xFF000000 | parsed) >>> 0;
      }
    } else if (hex.length === 8) {
      const parsed = Number.parseInt(hex, 16);
      if (!Number.isNaN(parsed)) {
        return parsed >>> 0;
      }
    }
  }
  return fallback;
}

/**
 * `ReaderHighlightRule.underlineMode` → 画布 decoration 口径。
 *
 * 6 = 删除线，1..4 = 下划线（线型由 `readerCanvasDecorationLineStyle` 决定），0 = 无。
 */
export function readerCanvasHighlightDecoration(mode: number): number {
  if (mode === 6) {
    return 6;
  }
  if (mode >= 1 && mode <= 4) {
    return mode;
  }
  return 0;
}

/** 标记的底色：#44RRGGBB（与老 Span 路径的 `getMarkingBackground` 同口径）。 */
export function readerCanvasMarkingBackgroundArgb(marking: ReaderMarking): number {
  if (marking.effect !== 'highlight' && marking.effect !== 'background') {
    return 0;
  }
  const base = readerCanvasArgb(marking.color, 0x00000000);
  const alpha = (base >>> 24) & 0xFF;
  if (alpha !== 0) {
    return base;
  }
  return 0x44000000 | (base & 0x00FFFFFF);
}

/** 标记的线型：1 实线、2 虚线、3 波浪、0 无。 */
export function readerCanvasMarkingDecoration(marking: ReaderMarking): number {
  if (marking.effect === 'solid') {
    return 1;
  }
  if (marking.effect === 'dashed') {
    return 2;
  }
  if (marking.effect === 'wave') {
    return 3;
  }
  return 0;
}

/**
 * 手指到「竖线顶端—圆心」这条中轴线的最短距离。
 *
 * 上游 `ReaderCanvasSurface.kt:1028` 的把手命中就是把竖线与圆柄当成一根胶囊来算，
 * 只用圆心算距离会让竖线中段的点击漏判。
 */
export function readerCanvasHandleDistance(xpx: number, ypx: number, lineX: number, lineTopY: number,
  centerY: number): number {
  const nearestY = Math.min(Math.max(ypx, lineTopY), centerY);
  const dx = xpx - lineX;
  const dy = ypx - nearestY;
  return Math.sqrt(dx * dx + dy * dy);
}

/**
 * `Length` → 数值。注意 `Area` 的 width/height 本来就是 vp，走这里取到的是 vp 原值，
 * 调用方不能再 px2vp 一次。
 */
export function readerLengthToNumber(value: Length): number {
  if (typeof value === 'number') {
    return value;
  }
  if (typeof value === 'string') {
    const parsed = Number.parseFloat(value);
    return Number.isNaN(parsed) ? 0 : parsed;
  }
  return 0;
}

/** 按 codePoint 数字形：代理对算一个字形，字间距是按字形数摊的。 */
export function readerTextGlyphCount(value: string): number {
  let count = 0;
  let cursor = 0;
  while (cursor < value.length) {
    const codePoint = value.codePointAt(cursor);
    cursor += codePoint !== undefined && codePoint > 0xFFFF ? 2 : 1;
    count++;
  }
  return count;
}
