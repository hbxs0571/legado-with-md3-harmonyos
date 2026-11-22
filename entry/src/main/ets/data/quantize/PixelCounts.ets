/**
 * 移植自 material-color-utilities 的 quantize/PixelCounts.java。
 *
 * 上游那份实现用开放寻址哈希表替代 LinkedHashMap，只是为了避免「每个颜色一个对象」的开销；
 * 它自己的类注释写明语义等价于「用 LinkedHashMap 计数」：颜色按首次出现顺序排列，counts 与之一一对应。
 * ArkTS 的 Map 本身就保证插入顺序，且这里最多只处理 64×64 = 4096 个像素，
 * 所以直接用 Map 承接同一语义，不引入哈希表细节（细节是上游的性能手段，不是行为）。
 */
export class PixelCounts {
  /** 去重后的颜色（ARGB），按首次出现顺序。 */
  readonly colors: number[] = [];
  /** 与 colors 一一对应的出现次数。 */
  readonly counts: number[] = [];

  constructor(pixels: number[]) {
    const indexOf: Map<number, number> = new Map<number, number>();
    for (let i = 0; i < pixels.length; i++) {
      const pixel = pixels[i];
      const existing = indexOf.get(pixel);
      if (existing === undefined) {
        indexOf.set(pixel, this.colors.length);
        this.colors.push(pixel);
        this.counts.push(1);
      } else {
        this.counts[existing] = this.counts[existing] + 1;
      }
    }
  }

  /** 不同颜色的个数。 */
  size(): number {
    return this.colors.length;
  }
}
