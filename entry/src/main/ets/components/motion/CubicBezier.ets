/**
 * 三次贝塞尔缓动求值。
 *
 * 存在理由：上游 M3 顶栏的收起行标题透明度不是线性插值，而是
 * `TopTitleAlphaEasing = CubicBezierEasing(.8f, 0f, .8f, .15f)`
 * （androidx compose/material3 AppBar.kt:3609，本机副本见
 *  N:/HarmonyProjects/tmp/booksource-uicheck/AppBar.kt:3609）。
 * ArkUI 的 `curves.cubicBezierCurve()` 只能作为动画曲线交给 animateTo，拿不到
 * 「给定 fraction 求输出值」的能力；顶栏折叠是随滚动连续驱动的，没有动画可挂，
 * 所以必须自己算。
 *
 * 数学定义：控制点 P1=(a,b)、P2=(c,d)，端点 P0=(0,0)、P3=(1,1)。
 *   x(t) = 3(1-t)²t·a + 3(1-t)t²·c + t³
 *   y(t) = 3(1-t)²t·b + 3(1-t)t²·d + t³
 * 求值 = 先解 x(t) = fraction 得到 t，再算 y(t)。x(t) 在 [0,1] 上单调
 * （a、c 都在 [0,1] 内时），所以用牛顿迭代求根，导数接近 0 时退化为二分。
 */

/** 单轴三次贝塞尔：P0=0, P1=p1, P2=p2, P3=1。 */
function bezierAxis(p1: number, p2: number, t: number): number {
  const mt = 1 - t;
  return 3 * mt * mt * t * p1 + 3 * mt * t * t * p2 + t * t * t;
}

/** 单轴导数，牛顿迭代用。 */
function bezierAxisDerivative(p1: number, p2: number, t: number): number {
  const mt = 1 - t;
  return 3 * mt * mt * p1 + 6 * mt * t * (p2 - p1) + 3 * t * t * (1 - p2);
}

/**
 * 求 x(t) = x 的 t。
 * 牛顿迭代最多 8 次；导数绝对值小于 1e-6 时改用二分，保证收敛。
 */
function solveTForX(a: number, c: number, x: number): number {
  let t = x;
  for (let i = 0; i < 8; i++) {
    const currentX = bezierAxis(a, c, t);
    const error = currentX - x;
    if (Math.abs(error) < 1e-6) {
      return t;
    }
    const derivative = bezierAxisDerivative(a, c, t);
    if (Math.abs(derivative) < 1e-6) {
      break;
    }
    t -= error / derivative;
  }
  // 牛顿没收敛或导数退化：二分兜底。x(t) 单调，区间必然收缩到解。
  let low = 0;
  let high = 1;
  t = x;
  for (let i = 0; i < 20; i++) {
    const currentX = bezierAxis(a, c, t);
    if (Math.abs(currentX - x) < 1e-6) {
      return t;
    }
    if (currentX < x) {
      low = t;
    } else {
      high = t;
    }
    t = (low + high) / 2;
  }
  return t;
}

/**
 * 给定两个控制点坐标，返回缓动函数。
 * 用法与 androidx 的 `CubicBezierEasing(a, b, c, d)` 一致：入参是 P1 与 P2 的 x/y。
 */
export function cubicBezierEasing(a: number, b: number, c: number, d: number): (fraction: number) => number {
  return (fraction: number): number => {
    // 端点直接返回，省去迭代（也是 androidx 的行为）。
    if (fraction <= 0) {
      return 0;
    }
    if (fraction >= 1) {
      return 1;
    }
    const t = solveTForX(a, c, fraction);
    return bezierAxis(b, d, t);
  };
}
