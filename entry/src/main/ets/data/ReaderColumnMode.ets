/**
 * 分页列数判定，严格对齐上游 `feature/reader/core/layout/ReaderColumnMode.kt`（全文 22 行）。
 *
 * 上游是四值枚举 + 一个 `columnCount(widthPx, heightPx, isTablet, isScroll) -> Int`：
 *   SINGLE            -> 1
 *   DOUBLE            -> 2（显式双页对滚动模式也生效，与 View 版一致）
 *   LANDSCAPE         -> width > height && !isScroll ? 2 : 1
 *   LANDSCAPE_OR_TABLET -> (width > height || isTablet) && !isScroll ? 2 : 1
 * 偏好字符串映射在 `fromPreference`：`"1"` -> DOUBLE、`"2"` -> LANDSCAPE、
 * `"3"` -> LANDSCAPE_OR_TABLET、其他 -> SINGLE。
 *
 * 本地平板判定没有系统 API 直读，按「短边 ≥ 600vp」近似（Android 侧 sw600dp），
 * 这条差异写在 KNOWN-ISSUES 的 KI-D4 里。
 */
export const READER_COLUMN_MODE_SINGLE: string = '0';
export const READER_COLUMN_MODE_DOUBLE: string = '1';
export const READER_COLUMN_MODE_LANDSCAPE: string = '2';
export const READER_COLUMN_MODE_LANDSCAPE_OR_TABLET: string = '3';

/** 平板近似阈值：与 Android 的 sw600dp 同口径。 */
export const READER_TABLET_MIN_SHORT_SIDE: number = 600;

/** 双页模式四档的中文标题，顺序与上游 `double_page_title` 数组一致（`values-zh-rCN/arrays.xml:42`）。 */
export const READER_COLUMN_MODE_TITLES: string[] = [
  '全局单页', '全局双页', '横屏双页', '平板/横屏双页'
];

/** 把偏好字符串收敛到四档，非四档一律按全局单页（对齐 `fromPreference` 的 else 分支）。 */
export function normalizeReaderColumnMode(value: string): string {
  return value === READER_COLUMN_MODE_DOUBLE ||
    value === READER_COLUMN_MODE_LANDSCAPE ||
    value === READER_COLUMN_MODE_LANDSCAPE_OR_TABLET
    ? value : READER_COLUMN_MODE_SINGLE;
}

/** 双页模式在设置面板里的副标题。 */
export function readerColumnModeTitle(value: string): string {
  const mode = normalizeReaderColumnMode(value);
  const index = mode === READER_COLUMN_MODE_DOUBLE ? 1
    : mode === READER_COLUMN_MODE_LANDSCAPE ? 2
      : mode === READER_COLUMN_MODE_LANDSCAPE_OR_TABLET ? 3 : 0;
  return READER_COLUMN_MODE_TITLES[index] ?? READER_COLUMN_MODE_TITLES[0] ?? '全局单页';
}

/** 是否视为平板：短边达到 600vp。 */
export function isReaderTablet(widthVp: number, heightVp: number): boolean {
  return Math.min(Math.max(0, widthVp), Math.max(0, heightVp)) >= READER_TABLET_MIN_SHORT_SIDE;
}

/**
 * 当前应使用几列，对齐 `ReaderColumnMode.columnCount`。
 * `widthVp`/`heightVp` 是正文视口尺寸，`isScroll` 是滚动模式（本地 `pageAnimation === 3`）。
 */
export function readerColumnCount(mode: string, widthVp: number, heightVp: number, isScroll: boolean): number {
  const normalized = normalizeReaderColumnMode(mode);
  const landscape = widthVp > heightVp;
  if (normalized === READER_COLUMN_MODE_DOUBLE) {
    // 上游注释：显式双页模式对滚动模式也生效（"as in the View reader"）。
    return 2;
  }
  if (normalized === READER_COLUMN_MODE_LANDSCAPE) {
    return landscape && !isScroll ? 2 : 1;
  }
  if (normalized === READER_COLUMN_MODE_LANDSCAPE_OR_TABLET) {
    return (landscape || isReaderTablet(widthVp, heightVp)) && !isScroll ? 2 : 1;
  }
  return 1;
}
