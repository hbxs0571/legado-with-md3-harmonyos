/**
 * 移植自 material-color-utilities 的 quantize/QuantizerWu.java（Xiaolin Wu, Graphics Gems II, 1991）。
 *
 * 逐行对齐上游：直方图按 5 bit/通道压到 33×33×33 的立方体、三重前缀和、按方差递归切箱、
 * 每箱取加权均值还原 ARGB。所有整数除法都保持上游的 int 语义（用 Math.trunc），
 * 方差那一处上游写的是 double 除法，同样照做。
 *
 * 上游的 Direction 枚举与 switch 表达式在 ArkTS 里改成方向常量 + if 链，
 * 运算分支与顺序一一对应（RED → GREEN → BLUE）。
 */
import { PixelCounts } from './PixelCounts.ets';
import * as colorUtils from '../../reader/m3/utils/color_utils.ets';

const INDEX_BITS: number = 5;
/** ((1 << INDEX_BITS) + 1) */
const INDEX_COUNT: number = 33;
/** INDEX_COUNT^3 */
const TOTAL_SIZE: number = 35937;

const DIRECTION_RED: number = 0;
const DIRECTION_GREEN: number = 1;
const DIRECTION_BLUE: number = 2;

/** 一个颜色立方体区间。上游 Box 的字段全部默认 0。 */
export class QuantizerBox {
  r0: number = 0;
  r1: number = 0;
  g0: number = 0;
  g1: number = 0;
  b0: number = 0;
  b1: number = 0;
  vol: number = 0;
}

/** 切分点的搜索结果：cutLocation < 0 表示不可切。 */
class MaximizeResult {
  cutLocation: number;
  maximum: number;

  constructor(cutLocation: number, maximum: number) {
    this.cutLocation = cutLocation;
    this.maximum = maximum;
  }
}

/** createBoxes 的结果：请求数与实际生成数。 */
class CreateBoxesResult {
  requestedCount: number;
  resultCount: number;

  constructor(requestedCount: number, resultCount: number) {
    this.requestedCount = requestedCount;
    this.resultCount = resultCount;
  }
}

export class QuantizerWu {
  private weights: number[] = [];
  private momentsR: number[] = [];
  private momentsG: number[] = [];
  private momentsB: number[] = [];
  private moments: number[] = [];
  private cubes: QuantizerBox[] = [];

  /**
   * 把输入像素量化成至多 colorCount 种颜色。
   * 返回值按上游 QuantizerResult 的语义：颜色 → 0（上游这张表的 value 全是 0，只用 key 集合）。
   */
  quantize(pixels: number[], colorCount: number): number[] {
    this.constructHistogram(new PixelCounts(pixels));
    this.createMoments();
    const createBoxesResult = this.createBoxes(colorCount);
    return this.createResult(createBoxesResult.resultCount);
  }

  private static getIndex(r: number, g: number, b: number): number {
    return (r << (INDEX_BITS * 2)) + (r << (INDEX_BITS + 1)) + r + (g << INDEX_BITS) + g + b;
  }

  private constructHistogram(pixelCounts: PixelCounts): void {
    this.weights = new Array<number>(TOTAL_SIZE).fill(0);
    this.momentsR = new Array<number>(TOTAL_SIZE).fill(0);
    this.momentsG = new Array<number>(TOTAL_SIZE).fill(0);
    this.momentsB = new Array<number>(TOTAL_SIZE).fill(0);
    this.moments = new Array<number>(TOTAL_SIZE).fill(0);

    const colors = pixelCounts.colors;
    const counts = pixelCounts.counts;
    for (let i = 0; i < pixelCounts.size(); i++) {
      const pixel = colors[i];
      const count = counts[i];
      const red = colorUtils.redFromArgb(pixel);
      const green = colorUtils.greenFromArgb(pixel);
      const blue = colorUtils.blueFromArgb(pixel);
      const bitsToRemove = 8 - INDEX_BITS;
      const iR = (red >> bitsToRemove) + 1;
      const iG = (green >> bitsToRemove) + 1;
      const iB = (blue >> bitsToRemove) + 1;
      const index = QuantizerWu.getIndex(iR, iG, iB);
      this.weights[index] += count;
      this.momentsR[index] += red * count;
      this.momentsG[index] += green * count;
      this.momentsB[index] += blue * count;
      this.moments[index] += count * ((red * red) + (green * green) + (blue * blue));
    }
  }

  private createMoments(): void {
    for (let r = 1; r < INDEX_COUNT; ++r) {
      const area = new Array<number>(INDEX_COUNT).fill(0);
      const areaR = new Array<number>(INDEX_COUNT).fill(0);
      const areaG = new Array<number>(INDEX_COUNT).fill(0);
      const areaB = new Array<number>(INDEX_COUNT).fill(0);
      const area2 = new Array<number>(INDEX_COUNT).fill(0);

      for (let g = 1; g < INDEX_COUNT; ++g) {
        let line = 0;
        let lineR = 0;
        let lineG = 0;
        let lineB = 0;
        let line2 = 0.0;
        for (let b = 1; b < INDEX_COUNT; ++b) {
          const index = QuantizerWu.getIndex(r, g, b);
          line += this.weights[index];
          lineR += this.momentsR[index];
          lineG += this.momentsG[index];
          lineB += this.momentsB[index];
          line2 += this.moments[index];

          area[b] += line;
          areaR[b] += lineR;
          areaG[b] += lineG;
          areaB[b] += lineB;
          area2[b] += line2;

          const previousIndex = QuantizerWu.getIndex(r - 1, g, b);
          this.weights[index] = this.weights[previousIndex] + area[b];
          this.momentsR[index] = this.momentsR[previousIndex] + areaR[b];
          this.momentsG[index] = this.momentsG[previousIndex] + areaG[b];
          this.momentsB[index] = this.momentsB[previousIndex] + areaB[b];
          this.moments[index] = this.moments[previousIndex] + area2[b];
        }
      }
    }
  }

  private createBoxes(maxColorCount: number): CreateBoxesResult {
    this.cubes = [];
    for (let i = 0; i < maxColorCount; i++) {
      this.cubes.push(new QuantizerBox());
    }
    const volumeVariance = new Array<number>(maxColorCount).fill(0.0);
    const firstBox = this.cubes[0];
    firstBox.r1 = INDEX_COUNT - 1;
    firstBox.g1 = INDEX_COUNT - 1;
    firstBox.b1 = INDEX_COUNT - 1;

    let generatedColorCount = maxColorCount;
    let next = 0;
    for (let i = 1; i < maxColorCount; i++) {
      if (this.cut(this.cubes[next], this.cubes[i])) {
        volumeVariance[next] = this.cubes[next].vol > 1 ? this.variance(this.cubes[next]) : 0.0;
        volumeVariance[i] = this.cubes[i].vol > 1 ? this.variance(this.cubes[i]) : 0.0;
      } else {
        volumeVariance[next] = 0.0;
        i--;
      }

      next = 0;

      let temp = volumeVariance[0];
      for (let j = 1; j <= i; j++) {
        if (volumeVariance[j] > temp) {
          temp = volumeVariance[j];
          next = j;
        }
      }
      if (temp <= 0.0) {
        generatedColorCount = i + 1;
        break;
      }
    }

    return new CreateBoxesResult(maxColorCount, generatedColorCount);
  }

  private createResult(colorCount: number): number[] {
    const colors: number[] = [];
    for (let i = 0; i < colorCount; ++i) {
      const cube = this.cubes[i];
      const weight = QuantizerWu.volume(cube, this.weights);
      if (weight > 0) {
        // 上游是 int / int 的整除。
        const r = Math.trunc(QuantizerWu.volume(cube, this.momentsR) / weight);
        const g = Math.trunc(QuantizerWu.volume(cube, this.momentsG) / weight);
        const b = Math.trunc(QuantizerWu.volume(cube, this.momentsB) / weight);
        const color = (255 << 24) | ((r & 0x0ff) << 16) | ((g & 0x0ff) << 8) | (b & 0x0ff);
        colors.push(color);
      }
    }
    return colors;
  }

  private variance(cube: QuantizerBox): number {
    const dr = QuantizerWu.volume(cube, this.momentsR);
    const dg = QuantizerWu.volume(cube, this.momentsG);
    const db = QuantizerWu.volume(cube, this.momentsB);
    const xx = this.moments[QuantizerWu.getIndex(cube.r1, cube.g1, cube.b1)]
      - this.moments[QuantizerWu.getIndex(cube.r1, cube.g1, cube.b0)]
      - this.moments[QuantizerWu.getIndex(cube.r1, cube.g0, cube.b1)]
      + this.moments[QuantizerWu.getIndex(cube.r1, cube.g0, cube.b0)]
      - this.moments[QuantizerWu.getIndex(cube.r0, cube.g1, cube.b1)]
      + this.moments[QuantizerWu.getIndex(cube.r0, cube.g1, cube.b0)]
      + this.moments[QuantizerWu.getIndex(cube.r0, cube.g0, cube.b1)]
      - this.moments[QuantizerWu.getIndex(cube.r0, cube.g0, cube.b0)];

    const hypotenuse = QuantizerWu.intSum(
      QuantizerWu.intMul(dr, dr),
      QuantizerWu.intMul(dg, dg),
      QuantizerWu.intMul(db, db)
    );
    const cubeVolume = QuantizerWu.volume(cube, this.weights);
    return xx - hypotenuse / cubeVolume;
  }

  /**
   * 模拟 Java 的 int 乘法（32 位有符号回绕）。
   *
   * 上游 `int hypotenuse = dr * dr + dg * dg + db * db` 与 `maximize` 里的
   * `double tempNumerator = halfR * halfR + ...` 都是先做 int 乘法再做 int 加法，
   * 结果超过 2^31 时按补码回绕，然后才拓宽成 double。
   * 直方图稠密时 halfR 能到百万量级，平方必然溢出——这正是逐位一致的关键，
   * 不能换成浮点乘法（那样得到的是数学正确值，与上游不同）。
   */
  private static intMul(a: number, b: number): number {
    return Math.imul(a, b);
  }

  /** 模拟 Java 的 int 加法（32 位有符号回绕）。 */
  private static intSum(a: number, b: number, c: number): number {
    return ((a + b) | 0) + c | 0;
  }

  private cut(one: QuantizerBox, two: QuantizerBox): boolean {
    const wholeR = QuantizerWu.volume(one, this.momentsR);
    const wholeG = QuantizerWu.volume(one, this.momentsG);
    const wholeB = QuantizerWu.volume(one, this.momentsB);
    const wholeW = QuantizerWu.volume(one, this.weights);

    const maxRResult =
      this.maximize(one, DIRECTION_RED, one.r0 + 1, one.r1, wholeR, wholeG, wholeB, wholeW);
    const maxGResult =
      this.maximize(one, DIRECTION_GREEN, one.g0 + 1, one.g1, wholeR, wholeG, wholeB, wholeW);
    const maxBResult =
      this.maximize(one, DIRECTION_BLUE, one.b0 + 1, one.b1, wholeR, wholeG, wholeB, wholeW);

    let cutDirection = DIRECTION_BLUE;
    const maxR = maxRResult.maximum;
    const maxG = maxGResult.maximum;
    const maxB = maxBResult.maximum;
    if (maxR >= maxG && maxR >= maxB) {
      if (maxRResult.cutLocation < 0) {
        return false;
      }
      cutDirection = DIRECTION_RED;
    } else if (maxG >= maxR && maxG >= maxB) {
      cutDirection = DIRECTION_GREEN;
    } else {
      cutDirection = DIRECTION_BLUE;
    }

    two.r1 = one.r1;
    two.g1 = one.g1;
    two.b1 = one.b1;

    if (cutDirection === DIRECTION_RED) {
      one.r1 = maxRResult.cutLocation;
      two.r0 = one.r1;
      two.g0 = one.g0;
      two.b0 = one.b0;
    } else if (cutDirection === DIRECTION_GREEN) {
      one.g1 = maxGResult.cutLocation;
      two.r0 = one.r0;
      two.g0 = one.g1;
      two.b0 = one.b0;
    } else {
      one.b1 = maxBResult.cutLocation;
      two.r0 = one.r0;
      two.g0 = one.g0;
      two.b0 = one.b1;
    }

    one.vol = (one.r1 - one.r0) * (one.g1 - one.g0) * (one.b1 - one.b0);
    two.vol = (two.r1 - two.r0) * (two.g1 - two.g0) * (two.b1 - two.b0);

    return true;
  }

  private maximize(
    cube: QuantizerBox,
    direction: number,
    first: number,
    last: number,
    wholeR: number,
    wholeG: number,
    wholeB: number,
    wholeW: number
  ): MaximizeResult {
    const bottomR = QuantizerWu.bottom(cube, direction, this.momentsR);
    const bottomG = QuantizerWu.bottom(cube, direction, this.momentsG);
    const bottomB = QuantizerWu.bottom(cube, direction, this.momentsB);
    const bottomW = QuantizerWu.bottom(cube, direction, this.weights);

    let max = 0.0;
    let cut = -1;

    let halfR = 0;
    let halfG = 0;
    let halfB = 0;
    let halfW = 0;
    for (let i = first; i < last; i++) {
      halfR = bottomR + QuantizerWu.top(cube, direction, i, this.momentsR);
      halfG = bottomG + QuantizerWu.top(cube, direction, i, this.momentsG);
      halfB = bottomB + QuantizerWu.top(cube, direction, i, this.momentsB);
      halfW = bottomW + QuantizerWu.top(cube, direction, i, this.weights);
      if (halfW === 0) {
        continue;
      }

      // 上游两处分子都是 `halfR * halfR + halfG * halfG + halfB * halfB`，且 halfR 声明为 int：
      // 先做 int 乘、int 加（溢出按 32 位回绕），再赋给 double。
      let tempNumerator = QuantizerWu.intSum(
        QuantizerWu.intMul(halfR, halfR),
        QuantizerWu.intMul(halfG, halfG),
        QuantizerWu.intMul(halfB, halfB)
      );
      let tempDenominator = halfW;
      let temp = tempNumerator / tempDenominator;

      halfR = wholeR - halfR;
      halfG = wholeG - halfG;
      halfB = wholeB - halfB;
      halfW = wholeW - halfW;
      if (halfW === 0) {
        continue;
      }

      tempNumerator = QuantizerWu.intSum(
        QuantizerWu.intMul(halfR, halfR),
        QuantizerWu.intMul(halfG, halfG),
        QuantizerWu.intMul(halfB, halfB)
      );
      tempDenominator = halfW;
      temp += tempNumerator / tempDenominator;

      if (temp > max) {
        max = temp;
        cut = i;
      }
    }
    return new MaximizeResult(cut, max);
  }

  private static volume(cube: QuantizerBox, moment: number[]): number {
    return moment[QuantizerWu.getIndex(cube.r1, cube.g1, cube.b1)]
      - moment[QuantizerWu.getIndex(cube.r1, cube.g1, cube.b0)]
      - moment[QuantizerWu.getIndex(cube.r1, cube.g0, cube.b1)]
      + moment[QuantizerWu.getIndex(cube.r1, cube.g0, cube.b0)]
      - moment[QuantizerWu.getIndex(cube.r0, cube.g1, cube.b1)]
      + moment[QuantizerWu.getIndex(cube.r0, cube.g1, cube.b0)]
      + moment[QuantizerWu.getIndex(cube.r0, cube.g0, cube.b1)]
      - moment[QuantizerWu.getIndex(cube.r0, cube.g0, cube.b0)];
  }

  private static bottom(cube: QuantizerBox, direction: number, moment: number[]): number {
    if (direction === DIRECTION_RED) {
      return -moment[QuantizerWu.getIndex(cube.r0, cube.g1, cube.b1)]
        + moment[QuantizerWu.getIndex(cube.r0, cube.g1, cube.b0)]
        + moment[QuantizerWu.getIndex(cube.r0, cube.g0, cube.b1)]
        - moment[QuantizerWu.getIndex(cube.r0, cube.g0, cube.b0)];
    }
    if (direction === DIRECTION_GREEN) {
      return -moment[QuantizerWu.getIndex(cube.r1, cube.g0, cube.b1)]
        + moment[QuantizerWu.getIndex(cube.r1, cube.g0, cube.b0)]
        + moment[QuantizerWu.getIndex(cube.r0, cube.g0, cube.b1)]
        - moment[QuantizerWu.getIndex(cube.r0, cube.g0, cube.b0)];
    }
    return -moment[QuantizerWu.getIndex(cube.r1, cube.g1, cube.b0)]
      + moment[QuantizerWu.getIndex(cube.r1, cube.g0, cube.b0)]
      + moment[QuantizerWu.getIndex(cube.r0, cube.g1, cube.b0)]
      - moment[QuantizerWu.getIndex(cube.r0, cube.g0, cube.b0)];
  }

  private static top(cube: QuantizerBox, direction: number, position: number, moment: number[]): number {
    if (direction === DIRECTION_RED) {
      return moment[QuantizerWu.getIndex(position, cube.g1, cube.b1)]
        - moment[QuantizerWu.getIndex(position, cube.g1, cube.b0)]
        - moment[QuantizerWu.getIndex(position, cube.g0, cube.b1)]
        + moment[QuantizerWu.getIndex(position, cube.g0, cube.b0)];
    }
    if (direction === DIRECTION_GREEN) {
      return moment[QuantizerWu.getIndex(cube.r1, position, cube.b1)]
        - moment[QuantizerWu.getIndex(cube.r1, position, cube.b0)]
        - moment[QuantizerWu.getIndex(cube.r0, position, cube.b1)]
        + moment[QuantizerWu.getIndex(cube.r0, position, cube.b0)];
    }
    return moment[QuantizerWu.getIndex(cube.r1, cube.g1, position)]
      - moment[QuantizerWu.getIndex(cube.r1, cube.g0, position)]
      - moment[QuantizerWu.getIndex(cube.r0, cube.g1, position)]
      + moment[QuantizerWu.getIndex(cube.r0, cube.g0, position)];
  }
}
