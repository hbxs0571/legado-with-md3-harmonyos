/**
 * Kotlin `Random(seed)` 的逐位复刻。
 *
 * 用途：上游 `model/BookCover.kt:80-88 getRandomDefaultPath` 用
 * `Random(seed.hashCode()).nextInt(paths.size)` 从默认封面相册里挑一张，
 * 同一本书（同一 seed）每次都要落到同一张图。要让本地的默认封面与上游选中的是同一张，
 * 就必须复刻同一套伪随机序列，不能换成 `Math.random()` 或取模散列。
 *
 * 上游算法来自 kotlin-stdlib 的 `kotlin.random.XorWowRandom`
 * （`libraries/stdlib/src/kotlin/random/XorWowRandom.kt`，Marsaglia xorwow）：
 * `Random(seed: Int) = XorWowRandom(seed, seed.shr(31))`，构造后先丢弃 64 个 `nextInt()`。
 *
 * 全部状态按 int32 语义运算（Java/Kotlin 的 Int 是 32 位补码）。
 * ArkTS 的 `^ << >> >>>` 本身就是 int32 语义，但 `+` 是 double，
 * 所以每处加法都要 `| 0` 截回 int32，否则会算出数学正确值而与上游分叉。
 */
export class KotlinRandom {
  private x: number;
  private y: number;
  private z: number;
  private w: number;
  private v: number;
  private addend: number;

  /**
   * 对应 `XorWowRandom(seed1, seed2)`：
   * `this(seed1, seed2, 0, 0, seed1.inv(), (seed1 shl 10) xor (seed2 ushr 4))`。
   * 构造末尾丢弃 64 个 `nextInt()`——注释原文「some trivial seeds can produce several
   * values with zeroes in upper bits, so we discard first 64」。
   */
  constructor(seed1: number, seed2: number) {
    const s1 = seed1 | 0;
    const s2 = seed2 | 0;
    this.x = s1;
    this.y = s2;
    this.z = 0;
    this.w = 0;
    this.v = ~s1;
    this.addend = ((s1 << 10) ^ (s2 >>> 4)) | 0;
    for (let index = 0; index < 64; index++) {
      this.nextInt();
    }
  }

  /**
   * 对应 `Random(seed: Int) = XorWowRandom(seed, seed.shr(31))`。
   * `shr` 是算术右移，`>> 31` 在 JS 里同为算术右移。
   */
  static fromIntSeed(seed: number): KotlinRandom {
    const value = seed | 0;
    return new KotlinRandom(value, value >> 31);
  }

  /** 对应 `Random(seed.hashCode())`；seed 为空串时 hashCode 为 0，与 Kotlin 一致。 */
  static forSeed(seed: string): KotlinRandom {
    return KotlinRandom.fromIntSeed(KotlinRandom.stringHashCode(seed));
  }

  /**
   * `String.hashCode()`：`s[0]*31^(n-1) + ... + s[n-1]`，按 int32 溢出。
   * 注意 `charCodeAt` 返回的是 UTF-16 码元，与 Java 的 `char` 同口径。
   */
  static stringHashCode(value: string): number {
    let hash = 0;
    for (let index = 0; index < value.length; index++) {
      hash = (hash * 31 + value.charCodeAt(index)) | 0;
    }
    return hash;
  }

  /** 对应 `XorWowRandom.nextInt()`：xorwow 一轮推进，返回 int32。 */
  nextInt(): number {
    let t = this.x;
    t = (t ^ (t >>> 2)) | 0;
    this.x = this.y;
    this.y = this.z;
    this.z = this.w;
    const v0 = this.v;
    this.w = v0;
    t = ((t ^ (t << 1)) ^ v0 ^ (v0 << 4)) | 0;
    this.v = t;
    this.addend = (this.addend + 362437) | 0;
    return (t + this.addend) | 0;
  }

  /**
   * 对应 `Int.takeUpperBits(bitCount) = ushr(32 - bitCount) and (-bitCount).shr(31)`。
   * `bitCount = 0` 时 Kotlin 返回 0（`-0 shr 31` 是 0，按位与后清零），这里同样特判，
   * 因为 JS 的 `>>> 32` 实际是 `>>> 0`，会把负数变成无符号大数。
   */
  nextBits(bitCount: number): number {
    const value = this.nextInt();
    if (bitCount <= 0) { return 0; }
    if (bitCount >= 32) { return value; }
    return ((value >>> (32 - bitCount)) & ((-bitCount) >> 31)) | 0;
  }

  /**
   * 对应 `Random.nextInt(until) = nextInt(0, until)`，两条路径都要照搬：
   * - `until` 是 2 的幂时走 `nextBits(fastLog2(until))`；
   * - 否则走拒绝采样 `do { bits = nextInt().ushr(1); v = bits % n } while (bits - v + (n-1) < 0)`。
   *
   * 那条 `while` 判的是 int32 溢出（`bits - v + (n-1)` 逼近 2^31 时变负），
   * 所以这里也要 `| 0` 后再比较，否则会少走拒绝分支、拿到偏斜的分布。
   */
  nextIntUntil(until: number): number {
    if (until <= 0) {
      throw new Error('Random range is empty');
    }
    const n = until;
    if ((n & -n) === n) {
      // fastLog2(n) = 31 - countLeadingZeroBits(n)，对应 Math.clz32。
      return this.nextBits(31 - Math.clz32(n));
    }
    let value = 0;
    while (true) {
      const bits = this.nextInt() >>> 1;
      value = bits % n;
      if (((bits - value + (n - 1)) | 0) >= 0) {
        return value;
      }
    }
  }
}
