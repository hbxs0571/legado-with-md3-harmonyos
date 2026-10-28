/** 与 Android HighlightRule 对齐的阅读正文样式规则；命中区间只在阅读时即时计算。 */
export interface ReaderHighlightRule {
  id: string;
  name: string;
  pattern: string;
  sampleText?: string;
  targetScope: number;
  enabled: boolean;
  position: number;
  textColor?: number | null;
  bgColor?: number | null;
  underlineMode: number;
  underlineColor?: number | null;
  underlineWidth?: number;
  underlineOffset?: number;
  underlineSvgPath?: string | null;
  bgImage?: string | null;
  bgImageFit?: number;
  bgImageScale?: number;
  configName?: string | null;
  fontPath?: string | null;
  fontWeight?: number;
  isItalic?: boolean;
  fontSizeOffset?: number;
  npLeft?: number;
  npRight?: number;
  npTop?: number;
  npBottom?: number;
  manualNineSlice?: boolean;
  letterSpacingBefore?: number;
  letterSpacingAfter?: number;
  lineSpacingTop?: number;
  lineSpacingBottom?: number;
  bgLengthOffsetLeft?: number;
  bgLengthOffsetRight?: number;
}

/** 正文正则命中的 UTF-16 半开区间；坐标与当前 LocalTextSemantics 渲染文本一致。 */
export interface ReaderHighlightRange {
  start: number;
  endExclusive: number;
  priority: number;
  rule: ReaderHighlightRule;
}

export interface ReaderHighlightStyle {
  textColor?: number | null;
  bgColor?: number | null;
  underlineMode: number;
  underlineColor?: number | null;
}