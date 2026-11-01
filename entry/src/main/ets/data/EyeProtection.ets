/**
 * 护眼模式算法与生效判定，逐句对齐上游 `ui/book/read/EyeProtection.kt`。
 *
 * 上游用 `ColorFilter.colorMatrix(...)` 给全屏套一层 4×5 色矩阵；ArkUI 的通用组件没有
 * `graphicsLayer { colorFilter = ... }` 等价物，但有 `.blendMode(BlendMode.MULTIPLY)`：
 * 混合公式 result = src * dst 逐通道相乘，恰好等于上游那个**对角矩阵**的效果
 * （上游矩阵除对角线外全为 0，见 `matrixValuesForIntensity`），因此这里把矩阵的对角线
 * 取出来当作一层纯色覆盖层，数学上与上游等价，不是近似。
 */

/** 上游 `EyeProtection.MIN_INTENSITY` / `MAX_INTENSITY`。 */
export const EYE_PROTECTION_MIN_INTENSITY: number = 0;
export const EYE_PROTECTION_MAX_INTENSITY: number = 100;
/** 上游 `MIN_FILTER_TEMPERATURE` / `MAX_FILTER_TEMPERATURE`，单位 K。 */
export const MIN_FILTER_TEMPERATURE: number = 2596;
export const MAX_FILTER_TEMPERATURE: number = 5500;

/** 上游 `EyeProtection.coefficients`，色温到 RGB 增益的二次拟合系数。 */
const COEFFICIENTS: number[] = [
  0, 0, 1,
  -9.623533E-9, 1.5304548E-4, 0.39078277,
  -1.8935904E-8, 3.024122E-4, -0.1986509
];

export class EyeProtection {
  /** 强度换算色温，对齐上游 `temperatureForIntensity`。 */
  static temperatureForIntensity(intensity: number): number {
    const clamped = Math.max(EYE_PROTECTION_MIN_INTENSITY, Math.min(EYE_PROTECTION_MAX_INTENSITY, intensity));
    return Math.trunc(MAX_FILTER_TEMPERATURE - (MAX_FILTER_TEMPERATURE - MIN_FILTER_TEMPERATURE) * clamped / 100);
  }

  /**
   * 强度换算 4×5 色矩阵，对齐上游 `matrixValuesForIntensity`。
   * 强度 <= 0 时返回单位矩阵（即不改变颜色）。
   */
  static matrixValuesForIntensity(intensity: number): number[] {
    if (intensity <= EYE_PROTECTION_MIN_INTENSITY) {
      return [
        1, 0, 0, 0, 0,
        0, 1, 0, 0, 0,
        0, 0, 1, 0, 0,
        0, 0, 0, 1, 0
      ];
    }
    const cct = EyeProtection.temperatureForIntensity(intensity);
    const red = cct * cct * COEFFICIENTS[0] + cct * COEFFICIENTS[1] + COEFFICIENTS[2];
    const green = cct * cct * COEFFICIENTS[3] + cct * COEFFICIENTS[4] + COEFFICIENTS[5];
    const blue = cct * cct * COEFFICIENTS[6] + cct * COEFFICIENTS[7] + COEFFICIENTS[8];
    return [
      red, 0, 0, 0, 0,
      0, green, 0, 0, 0,
      0, 0, blue, 0, 0,
      0, 0, 0, 1, 0
    ];
  }

  /**
   * 对角增益换算成覆盖层颜色，供 `.blendMode(BlendMode.MULTIPLY)` 使用。
   * 强度 <= 0 时返回空串，调用方据此不挂覆盖层。
   */
  static overlayColorForIntensity(intensity: number): string {
    if (intensity <= EYE_PROTECTION_MIN_INTENSITY) { return ''; }
    const matrix = EyeProtection.matrixValuesForIntensity(intensity);
    const red = EyeProtection.toChannel(matrix[0]);
    const green = EyeProtection.toChannel(matrix[6]);
    const blue = EyeProtection.toChannel(matrix[12]);
    return `#${red}${green}${blue}`;
  }

  /** 0..1 的增益转两位十六进制通道值。 */
  private static toChannel(gain: number): string {
    const scaled = Math.round(Math.max(0, Math.min(1, gain)) * 255);
    const text = scaled.toString(16).toUpperCase();
    return text.length === 1 ? `0${text}` : text;
  }

  /** 解析 `HH:mm` 为分钟数，对齐上游 `parseTime`；非法返回 -1。 */
  static parseTime(value: string): number {
    const parts = value.trim().split(':');
    if (parts.length !== 2) { return -1; }
    const hour = Number(parts[0]);
    const minute = Number(parts[1]);
    if (!Number.isInteger(hour) || !Number.isInteger(minute) ||
      hour < 0 || hour >= 24 || minute < 0 || minute >= 60) {
      return -1;
    }
    return hour * 60 + minute;
  }

  /**
   * 当前是否应当生效，对齐上游 `isActiveAt`。
   * `minuteOfDay` 是当天已过的分钟数，由调用方按分钟刷新。
   */
  static isActiveAt(enabled: boolean, autoNight: boolean, isDark: boolean, schedule: boolean,
    startTime: string, endTime: string, minuteOfDay: number): boolean {
    if (!(enabled || (autoNight && isDark))) { return false; }
    if (!schedule) { return true; }
    const start = EyeProtection.parseTime(startTime);
    const end = EyeProtection.parseTime(endTime);
    // 起止时间解析失败时按「全天生效」处理，与上游 `?: return true` 一致。
    if (start < 0 || end < 0) { return true; }
    if (start === end) { return true; }
    return start < end ? (minuteOfDay >= start && minuteOfDay < end)
      : (minuteOfDay >= start || minuteOfDay < end);
  }
}
