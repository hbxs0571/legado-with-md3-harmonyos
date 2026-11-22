/**
 * 移植自 material-color-utilities 的 quantize/QuantizerWsmeans.java
 * （Weighted Square Means，即带若干优化的 K-Means；M. Emre Celebi 2011）。
 *
 * 逐行对齐上游的迭代过程：初始簇来自 Wu 量化的结果、点用 L*a*b* 坐标、
 * 距离矩阵按行就地排序并配合三角不等式剪枝、MAX_ITERATIONS = 10、
 * 只有位移超过 MIN_MOVEMENT_DISTANCE = 3.0 才真正换簇。
 *
 * 上游用 `new Random(0x42688)` 保证结果可复现。Java 的 Random 是 48 位线性同余发生器，
 * 这里用两个 24 位半字做模 2^48 乘法来精确复现它（double 在 2^53 内整数精确，
 * 中间量最大 2^49，不会丢精度），从而与上游给出同一串初始簇下标。
 */
import { PixelCounts } from './PixelCounts.ets';
import * as pointProvider from './PointProviderLab.ets';

const MAX_ITERATIONS: number = 10;
const MIN_MOVEMENT_DISTANCE: number = 3.0;

const MASK_24: number = 0x1000000;
const MASK_48: number = 0x1000000000000;
const MULTIPLIER_HI: number = Math.floor(0x5deece66d / MASK_24);
const MULTIPLIER_LO: number = 0x5deece66d % MASK_24;

/** Java java.util.Random 的等价实现（仅本文件用到的 nextInt 路径）。 */
class JavaRandom {
  private seed: number;

  constructor(initialSeed: number) {
    // Java: (initialSeed ^ 0x5DEECE66D) & ((1 << 48) - 1)。
    // ArkTS/JS 的 ^ 会先把操作数截成 int32，0x5DEECE66D 超过 32 位会被截断，
    // 所以按 24 位半字分别异或——两半的位区间不重叠，异或对半字是可分配的。
    const hi = Math.floor(initialSeed / MASK_24) % MASK_24;
    const lo = initialSeed % MASK_24;
    this.seed = ((hi ^ MULTIPLIER_HI) % MASK_24) * MASK_24 + ((lo ^ MULTIPLIER_LO) % MASK_24);
  }

  /**
   * Java Random.nextInt(bound)，bound > 0。
   *
   * 上游 JDK 有两条路径，不能只写取模：
   * - bound 是 2 的幂时走 `(int)((bound * (long)r) >> 31)`，等价于取 r 的高位；
   * - 否则走拒绝采样 `for (int u = r; u - (r = u % bound) + m < 0; u = next(31));`，
   *   那个 `< 0` 判的是 int 溢出（r 逼近 2^31 时才会发生），这里等价写成「超过 int 上限」。
   *
   * 本算法里 clusterCount 常是 8/16/64 这类 2 的幂，第一条路径是主路径——写成取模会让
   * 初始簇下标整体不同，量化结果随之分叉。
   */
  nextInt(bound: number): number {
    if (bound <= 0) {
      throw new Error('bound must be positive');
    }
    let r = this.next(31);
    const m = bound - 1;
    if ((bound & m) === 0) {
      // bound 是 2 的幂：bound * r 最大 2^6 * 2^31 = 2^37，double 精确。
      return Math.floor((bound * r) / 2147483648);
    }
    const intMax = 2147483647;
    while (true) {
      const value = r % bound;
      if (r - value + m <= intMax) {
        return value;
      }
      r = this.next(31);
    }
  }

  private next(bits: number): number {
    // seed = (seed * 0x5DEECE66D + 0xB) & ((1 << 48) - 1)，用 24 位半字精确计算：
    // lo*lo 最大 2^48、cross*2^24 最大 2^48，和 < 2^49 < 2^53，double 表示整数精确。
    const hi = Math.floor(this.seed / MASK_24);
    const lo = this.seed % MASK_24;
    const cross = (hi * MULTIPLIER_LO + lo * MULTIPLIER_HI) % MASK_24;
    let next = (lo * MULTIPLIER_LO + cross * MASK_24 + 0xb) % MASK_48;
    if (next < 0) {
      next += MASK_48;
    }
    this.seed = next;
    return Math.floor(next / Math.pow(2, 48 - bits));
  }
}

/**
 * 量化入口。
 * @param inputPixels ARGB 像素
 * @param startingClusters 初始簇（ARGB），通常传 Wu 量化的结果
 * @param maxColors 目标颜色数
 * @return 颜色 → 该颜色覆盖的像素数（上游语义）
 */
export function quantizeWsmeans(
  inputPixels: number[],
  startingClusters: number[],
  maxColors: number
): Map<number, number> {
  const random = new JavaRandom(0x42688);

  const pixelCounts = new PixelCounts(inputPixels);
  const pointCount = pixelCounts.size();
  const pixels = pixelCounts.colors;
  const counts = pixelCounts.counts;

  const points = new Array<number>(pointCount * 3).fill(0);
  for (let i = 0; i < pointCount; i++) {
    pointProvider.labFromArgb(pixels[i], points, i * 3);
  }

  let clusterCount = Math.min(maxColors, pointCount);
  if (startingClusters.length !== 0) {
    clusterCount = Math.min(clusterCount, startingClusters.length);
  }

  const pixelCountSums = new Array<number>(clusterCount).fill(0);
  const clusters = new Array<number>(clusterCount * 3).fill(0);

  for (let i = 0; i < startingClusters.length; i++) {
    pointProvider.labFromArgb(startingClusters[i], clusters, i * 3);
  }
  if (startingClusters.length === 0 && clusterCount > 0) {
    throw new Error('QuantizerWsmeans needs starting clusters');
  }

  const clusterIndices = new Array<number>(pointCount).fill(0);
  for (let i = 0; i < pointCount; i++) {
    clusterIndices[i] = random.nextInt(clusterCount);
  }

  // 第 i 行保存簇 i 到其它簇的距离并按升序排序。每轮就地更新并按位置重新排序，
  // 第 i 格从不被更新、保留上一次排序留在那里的值；下面的扫描把第 j 小的距离与簇 j 配对。
  // 这两处细节都会影响结果，所以照搬。
  const distanceMatrix: number[][] = [];
  for (let i = 0; i < clusterCount; i++) {
    distanceMatrix.push(new Array<number>(clusterCount).fill(-1.0));
  }

  const componentASums = new Array<number>(clusterCount).fill(0);
  const componentBSums = new Array<number>(clusterCount).fill(0);
  const componentCSums = new Array<number>(clusterCount).fill(0);

  for (let iteration = 0; iteration < MAX_ITERATIONS; iteration++) {
    for (let i = 0; i < clusterCount; i++) {
      const row = distanceMatrix[i];
      const iL = clusters[i * 3];
      const iA = clusters[i * 3 + 1];
      const iB = clusters[i * 3 + 2];
      for (let j = i + 1; j < clusterCount; j++) {
        const dL = iL - clusters[j * 3];
        const dA = iA - clusters[j * 3 + 1];
        const dB = iB - clusters[j * 3 + 2];
        const distance = dL * dL + dA * dA + dB * dB;
        distanceMatrix[j][i] = distance;
        row[j] = distance;
      }
      row.sort((a: number, b: number) => a - b);
    }

    let pointsMoved = 0;
    for (let i = 0; i < pointCount; i++) {
      const pointL = points[i * 3];
      const pointA = points[i * 3 + 1];
      const pointB = points[i * 3 + 2];

      const previousClusterIndex = clusterIndices[i];
      const previousL = pointL - clusters[previousClusterIndex * 3];
      const previousA = pointA - clusters[previousClusterIndex * 3 + 1];
      const previousB = pointB - clusters[previousClusterIndex * 3 + 2];
      const previousDistance = previousL * previousL + previousA * previousA + previousB * previousB;

      let minimumDistance = previousDistance;
      let newClusterIndex = -1;
      const sortedDistances = distanceMatrix[previousClusterIndex];
      const maximumDistance = 4 * previousDistance;
      for (let j = 0; j < clusterCount; j++) {
        // 距离已排序，一旦有一个达到上限，后面的都达到。
        if (sortedDistances[j] >= maximumDistance) {
          break;
        }
        const dL = pointL - clusters[j * 3];
        const dA = pointA - clusters[j * 3 + 1];
        const dB = pointB - clusters[j * 3 + 2];
        const distance = dL * dL + dA * dA + dB * dB;
        if (distance < minimumDistance) {
          minimumDistance = distance;
          newClusterIndex = j;
        }
      }

      if (newClusterIndex !== -1) {
        const distanceChange = Math.abs(Math.sqrt(minimumDistance) - Math.sqrt(previousDistance));
        if (distanceChange > MIN_MOVEMENT_DISTANCE) {
          pointsMoved++;
          clusterIndices[i] = newClusterIndex;
        }
      }
    }

    if (pointsMoved === 0 && iteration !== 0) {
      break;
    }

    componentASums.fill(0.0);
    componentBSums.fill(0.0);
    componentCSums.fill(0.0);
    pixelCountSums.fill(0);
    for (let i = 0; i < pointCount; i++) {
      const clusterIndex = clusterIndices[i];
      const count = counts[i];
      pixelCountSums[clusterIndex] += count;
      componentASums[clusterIndex] += points[i * 3] * count;
      componentBSums[clusterIndex] += points[i * 3 + 1] * count;
      componentCSums[clusterIndex] += points[i * 3 + 2] * count;
    }

    for (let i = 0; i < clusterCount; i++) {
      const count = pixelCountSums[i];
      if (count === 0) {
        clusters[i * 3] = 0.0;
        clusters[i * 3 + 1] = 0.0;
        clusters[i * 3 + 2] = 0.0;
        continue;
      }
      clusters[i * 3] = componentASums[i] / count;
      clusters[i * 3 + 1] = componentBSums[i] / count;
      clusters[i * 3 + 2] = componentCSums[i] / count;
    }
  }

  const argbToPopulation: Map<number, number> = new Map<number, number>();
  for (let i = 0; i < clusterCount; i++) {
    const count = pixelCountSums[i];
    if (count === 0) {
      continue;
    }
    const possibleNewCluster = pointProvider.argbFromLab(clusters[i * 3], clusters[i * 3 + 1], clusters[i * 3 + 2]);
    if (argbToPopulation.has(possibleNewCluster)) {
      continue;
    }
    argbToPopulation.set(possibleNewCluster, count);
  }
  return argbToPopulation;
}
