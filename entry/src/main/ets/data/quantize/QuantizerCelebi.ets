/**
 * 移植自 material-color-utilities 的 quantize/QuantizerCelebi.java。
 *
 * 上游做法：先用 Wu 量化得到初始簇，再把这些簇喂给 Wsmeans（加权 K-Means）做精修。
 * 这样既避开随机初始化的不稳定，又比纯 K-Means 快（Celebi 2011 的结论）。
 */
import { QuantizerWu } from './QuantizerWu.ets';
import { quantizeWsmeans } from './QuantizerWsmeans.ets';

/**
 * 把输入像素压缩到至多 maxColors 种颜色。
 * @param pixels ARGB 像素
 * @param maxColors 目标颜色数（可能返回更少）
 * @return 颜色 → 该颜色在原图中对应的像素数
 */
export function quantizeCelebi(pixels: number[], maxColors: number): Map<number, number> {
  const wu = new QuantizerWu();
  const wuClusters = wu.quantize(pixels, maxColors);
  return quantizeWsmeans(pixels, wuClusters, maxColors);
}
