/**
 * 标题分段模型，对齐上游 feature/reader/core/source/ReaderTitleSegmentation.kt。
 *
 * 上游把章节标题按配置切成多个块，第一块用正常字号、后续块按 subtitleScale 缩放，
 * 分页时每个块都算一个独立的排版单元。本地原先标题是单个 Text，没有分段概念，
 * 因此这个文件只负责「同一套切分规则」，具体渲染由 ReaderPage 消费。
 */

/** 切分出来的一段标题。 */
export interface ReaderTitleSegment {
  /** 这一段标题的文字。 */
  text: string;
  /** 这一段在标题里的首个字符位置，对齐上游 chapterPosition。 */
  offset: number;
  /** 是否为首段（首段不缩放，其余段按 subtitleScale 缩放）。 */
  isSubtitle: boolean;
  /** 这一段的字号倍率：首段 1，其余段为 subtitleScale。 */
  fontSizeScale: number;
}

/** 构造分段配置时用到的四个上游字段。 */
export interface ReaderTitleSegmentationOptions {
  /** 0 = 不分段、1 = 按字数、2 = 按分隔符、3 = 按正则。 */
  type: number;
  /** 按字数分段时的第几个字符处断开。 */
  distance: number;
  /** 按分隔符/按正则分段时的匹配串。 */
  delimiter: string;
  /** 第二段起相对首段的字号比例。 */
  subtitleScale: number;
}

/** 默认配置，与上游 ReaderTitleSegmentation 的默认值一致（0 / 4 / "" / 1f）。 */
export const READER_TITLE_SEGMENTATION_DEFAULT: ReaderTitleSegmentationOptions = {
  type: 0,
  distance: 4,
  delimiter: '',
  subtitleScale: 1
};

/**
 * 按配置把标题切成分段。规则逐条对齐上游 ReaderTitleSegmentation.blocks/split：
 * 先按换行切行并 trim，非空行再各自 split，位置按「文字长度 + 1」累加。
 */
export function segmentReaderTitle(title: string, options: ReaderTitleSegmentationOptions): ReaderTitleSegment[] {
  const lines: string[] = title.split('\n').map((line: string): string => line.trim())
    .filter((line: string): boolean => line.length > 0);
  const result: ReaderTitleSegment[] = [];
  let position = 0;
  for (let lineIndex = 0; lineIndex < lines.length; lineIndex++) {
    const line = lines[lineIndex] as string;
    const pieces = splitTitleLine(line, options);
    for (let index = 0; index < pieces.length; index++) {
      const text = pieces[index] as string;
      result.push({
        text: text,
        offset: position,
        isSubtitle: index > 0,
        fontSizeScale: index === 0 ? 1 : options.subtitleScale
      });
      position += text.length + 1;
    }
  }
  return result;
}

/** 单行切分，对齐上游 split 的四个分支。 */
function splitTitleLine(line: string, options: ReaderTitleSegmentationOptions): string[] {
  if (options.type === 1) {
    // 字数分段：只有 distance 落在 (0, 长度) 区间内才切，否则整行返回。
    if (options.distance > 0 && options.distance < line.length) {
      return [line.substring(0, options.distance), line.substring(options.distance)];
    }
    return [line];
  }
  if (options.type === 2 || options.type === 3) {
    let source = '';
    if (options.type === 3) {
      source = options.delimiter;
    } else {
      // 分隔符模式：上游把逗号分隔的多个词各自转义后用 | 拼成正则。
      const parts: string[] = options.delimiter.split(',')
        .map((value: string): string => value.trim())
        .filter((value: string): boolean => value.length > 0)
        .map((value: string): string => escapeRegExp(value));
      source = parts.length === 0 ? '' : parts.join('|');
    }
    if (source.length === 0) { return [line]; }
    let regex: RegExp | undefined = undefined;
    try {
      regex = new RegExp(`(?<=${source})`, 'u');
    } catch (error) {
      // 非法表达式不能让章节变成不可读，回落到整行（上游 runCatching 同理）。
      console.warn(`[ReaderTitleSegmentation] 分段表达式非法，按整行处理：${source}`);
      regex = undefined;
    }
    if (regex === undefined) { return [line]; }
    const pieces = line.split(regex)
      .map((value: string): string => value.trim())
      .filter((value: string): boolean => value.length > 0);
    return pieces.length === 0 ? [line] : pieces;
  }
  return [line];
}

/** 正则转义，等价 Kotlin 的 Regex.escape。 */
function escapeRegExp(value: string): string {
  return value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}
