/**
 * 移植自 material-color-utilities 的 score/Score.java。
 *
 * 输入是一大批量化后的候选色及其像素数，输出是「适合做 UI 主题色」的排序结果。
 * 上游注释说明它的意义：让量化可以用很高的簇数（颜色不被搅浑），
 * 再由 Score 从这批高簇数里挑出少数几个真正适合的。
 *
 * 全部常数照搬：TARGET_CHROMA = 48、WEIGHT_PROPORTION = 0.7、WEIGHT_CHROMA_ABOVE = 0.3、
 * WEIGHT_CHROMA_BELOW = 0.1、CUTOFF_CHROMA = 5、CUTOFF_EXCITED_PROPORTION = 0.01。
 */
import { Hct } from '../../reader/m3/hct/hct.ets';
import * as mathUtils from '../../reader/m3/utils/math_utils.ets';

const TARGET_CHROMA: number = 48.0;
const WEIGHT_PROPORTION: number = 0.7;
const WEIGHT_CHROMA_ABOVE: number = 0.3;
const WEIGHT_CHROMA_BELOW: number = 0.1;
const CUTOFF_CHROMA: number = 5.0;
const CUTOFF_EXCITED_PROPORTION: number = 0.01;

/** 一个候选色及其得分。 */
class ScoredHct {
  hct: Hct;
  score: number;

  constructor(hct: Hct, score: number) {
    this.hct = hct;
    this.score = score;
  }
}

/**
 * 对颜色按「适合作主题色」的程度排序。
 * @param colorsToPopulation 颜色 → 出现次数
 * @param desired 最多返回几个
 * @param fallbackColorArgb 一个都挑不出时返回的颜色
 * @param filter 是否过滤掉不合适的（色度太低、占比太低）
 * @return 按合适度降序；至少一个元素
 */
export function scoreColors(
  colorsToPopulation: Map<number, number>,
  desired: number,
  fallbackColorArgb: number,
  filter: boolean
): number[] {
  const colorsHct: Hct[] = [];
  const huePopulation = new Array<number>(360).fill(0);
  let populationSum = 0.0;
  colorsToPopulation.forEach((population: number, argb: number) => {
    const hct = Hct.fromInt(argb);
    colorsHct.push(hct);
    const hue = Math.floor(hct.hue);
    huePopulation[hue] += population;
    populationSum += population;
  });

  // 邻域 30 度内用色越多的色相，得分越高。
  const hueExcitedProportions = new Array<number>(360).fill(0.0);
  for (let hue = 0; hue < 360; hue++) {
    const proportion = huePopulation[hue] / populationSum;
    for (let i = hue - 14; i < hue + 16; i++) {
      const neighborHue = mathUtils.sanitizeDegreesInt(i);
      hueExcitedProportions[neighborHue] += proportion;
    }
  }

  const scoredHcts: ScoredHct[] = [];
  for (let index = 0; index < colorsHct.length; index++) {
    const hct = colorsHct[index];
    const hue = mathUtils.sanitizeDegreesInt(Math.round(hct.hue));
    const proportion = hueExcitedProportions[hue];
    if (filter && (hct.chroma < CUTOFF_CHROMA || proportion <= CUTOFF_EXCITED_PROPORTION)) {
      continue;
    }

    const proportionScore = proportion * 100.0 * WEIGHT_PROPORTION;
    const chromaWeight = hct.chroma < TARGET_CHROMA ? WEIGHT_CHROMA_BELOW : WEIGHT_CHROMA_ABOVE;
    const chromaScore = (hct.chroma - TARGET_CHROMA) * chromaWeight;
    scoredHcts.push(new ScoredHct(hct, proportionScore + chromaScore));
  }
  // 高分在前。
  scoredHcts.sort((a: ScoredHct, b: ScoredHct) => b.score - a.score);

  // 从 90 度（4 色时的最大间隔）逐级降到 15 度，尽量挑出色相分布最开的若干个。
  const chosenColors: Hct[] = [];
  for (let differenceDegrees = 90; differenceDegrees >= 15; differenceDegrees--) {
    chosenColors.length = 0;
    for (let index = 0; index < scoredHcts.length; index++) {
      const hct = scoredHcts[index].hct;
      let hasDuplicateHue = false;
      for (let chosenIndex = 0; chosenIndex < chosenColors.length; chosenIndex++) {
        if (mathUtils.differenceDegrees(hct.hue, chosenColors[chosenIndex].hue) < differenceDegrees) {
          hasDuplicateHue = true;
          break;
        }
      }
      if (!hasDuplicateHue) {
        chosenColors.push(hct);
      }
      if (chosenColors.length >= desired) {
        break;
      }
    }
    if (chosenColors.length >= desired) {
      break;
    }
  }

  const colors: number[] = [];
  if (chosenColors.length === 0) {
    colors.push(fallbackColorArgb);
  }
  for (let index = 0; index < chosenColors.length; index++) {
    colors.push(chosenColors[index].toInt());
  }
  return colors;
}
