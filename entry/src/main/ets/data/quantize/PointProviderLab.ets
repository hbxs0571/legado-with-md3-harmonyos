/**
 * 移植自 material-color-utilities 的 quantize/PointProviderLab.java。
 *
 * 只保留上游用到的三个能力：ARGB → L*a*b*（写入既有数组的指定偏移，避免每个颜色分配一个数组）、
 * L*a*b* → ARGB、以及不含开方的距离（上游注释说明：量化只需比较相对大小，省掉开方不改变排序）。
 *
 * 上游那份实现额外维护了一张 256 项 linearized 查找表，纯粹是为了少算 pow()；
 * 这里直接调 utils/color_utils.ets 的 linearized()，运算顺序与上游注释承诺的「同一批运算、同一顺序」一致。
 */
import * as colorUtils from '../../reader/m3/utils/color_utils.ets';

const LAB_F_E: number = 216.0 / 24389.0;
const LAB_F_KAPPA: number = 24389.0 / 27.0;

/** 与 color_utils.ets 里的 labF 同式；上游 PointProviderLab 自带一份私有副本，这里同样自带。 */
function labF(t: number): number {
  if (t > LAB_F_E) {
    return Math.pow(t, 1.0 / 3.0);
  }
  return (LAB_F_KAPPA * t + 16) / 116;
}

/** 把 ARGB 的 L*a*b* 坐标写入 out 的 offset 起始三格。 */
export function labFromArgb(argb: number, out: number[], offset: number): void {
  const linearR = colorUtils.linearized(colorUtils.redFromArgb(argb));
  const linearG = colorUtils.linearized(colorUtils.greenFromArgb(argb));
  const linearB = colorUtils.linearized(colorUtils.blueFromArgb(argb));
  // 与上游同样的 SRGB→XYZ 矩阵与 D65 白点常数。
  const x = 0.41233895 * linearR + 0.35762064 * linearG + 0.18051042 * linearB;
  const y = 0.2126 * linearR + 0.7152 * linearG + 0.0722 * linearB;
  const z = 0.01932141 * linearR + 0.11916382 * linearG + 0.95034478 * linearB;
  const fx = labF(x / 95.047);
  const fy = labF(y / 100.0);
  const fz = labF(z / 108.883);
  out[offset] = 116.0 * fy - 16;
  out[offset + 1] = 500.0 * (fx - fy);
  out[offset + 2] = 200.0 * (fy - fz);
}

/** L*a*b* → ARGB。 */
export function argbFromLab(l: number, a: number, b: number): number {
  return colorUtils.argbFromLab(l, a, b);
}

/** 两点距离的平方（CIE 1976 delta E 去掉开方，排序等价）。 */
export function labDistance(one: number[], oneOffset: number, two: number[], twoOffset: number): number {
  const dL = one[oneOffset] - two[twoOffset];
  const dA = one[oneOffset + 1] - two[twoOffset + 1];
  const dB = one[oneOffset + 2] - two[twoOffset + 2];
  return dL * dL + dA * dA + dB * dB;
}
