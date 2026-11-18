/**
 * 朗读正文切段器，对齐上游 `ReadAloudContentSplit.kt` 的 `ReadAloudContentSplitter`。
 *
 * 四档语义（上游 `ContentSplitPolicies.forMode` 才是运行时真值，不是枚举的
 * allowsRoleSplits 属性）：
 * - default：被 forMode 映射成 paragraph，按换行切出的行段落，不按标点切。
 * - paragraph：行段落即单元。
 * - page：调用方提供已切好的页，本文件透明返回——本地返回空数组，由调用方按页切。
 * - symbols：按选中标点切，空集回退四个句末标点；连续标点视为一个整体。
 *
 * 不实现角色拆分：上游 RuleBasedSpeechSegmenter 的引号配对/冒号分角色是为多角色朗读
 * 服务的，而多角色依赖 AI 分配（范围之外）。本地 allowRoleSplits 不出现，
 * 避免留一个永假的分支。
 */

/** 上游 ReadAloudSplitSymbol 的 14 个合法标点，用于把用户输入过滤成合法集合。 */
const SPLIT_SYMBOLS: string = '。！？…；，、：.!?;,:';
/** sentenceEnds：未另行选择时的四个句末标点（上游 :148）。 */
const SENTENCE_ENDS: string = '。！？…';

export interface SpeechUnit {
  /** 单元首字符在整章 body 中的下标（含）。 */
  start: number;
  /** 单元末字符在整章 body 中的下标（不含），满足 body.substring(start, end) === text。 */
  end: number;
  /** 单元文本，不含换行符。 */
  text: string;
}

export class SpeechSegmenter {
  /**
   * 四档切段。mode 取 'default' | 'paragraph' | 'page' | 'symbols'。
   *
   * page 档返回空数组：上游这一档是「调用方提供已切好的页、本文件透明返回」，
   * 本地调用方（批 3）手里有 localReaderPages，每页带 startPosition/endPosition，
   * 由它自己按页切。这是唯一一档不自己切的。
   */
  static segment(body: string, mode: string, symbols: string): SpeechUnit[] {
    if (mode === 'page') {
      return [];
    }
    const paragraphs = SpeechSegmenter.lineParagraphs(body);
    if (mode === 'symbols') {
      const set = SpeechSegmenter.resolveSymbols(symbols);
      const units: SpeechUnit[] = [];
      for (let index = 0; index < paragraphs.length; index++) {
        const paragraph = paragraphs[index];
        if (paragraph !== undefined) {
          SpeechSegmenter.splitAtSymbols(paragraph, set, units);
        }
      }
      return units;
    }
    // default / paragraph：按行段落原样返回。未知档位也按此兜底（不丢正文）。
    return paragraphs;
  }

  /**
   * 按换行切段，空行丢弃；被丢掉的换行符计入下一段的 start（start = 上一段 end + 1）。
   * 与上游 lineParagraphs（:212 附近）逐字等价，额外记录每个单元的字符区间。
   */
  private static lineParagraphs(body: string): SpeechUnit[] {
    const units: SpeechUnit[] = [];
    let start = 0;
    for (let index = 0; index < body.length; index++) {
      if (body[index] === '\n') {
        if (index > start) {
          units.push({ start: start, end: index, text: body.substring(start, index) });
        }
        start = index + 1;
      }
    }
    if (start < body.length) {
      units.push({ start: start, end: body.length, text: body.substring(start) });
    }
    return units;
  }

  /**
   * 把存储值（逗号分隔的标点串）过滤成合法标点集合；空集回退四个句末标点。
   * 对齐上游 resolveSymbols（:212 附近）的「filter in bySymbol + ifEmpty sentenceEnds」。
   */
  private static resolveSymbols(stored: string): string {
    if (stored.trim().length === 0) {
      return SENTENCE_ENDS;
    }
    let resolved = '';
    const parts = stored.split(',');
    for (let index = 0; index < parts.length; index++) {
      const part = parts[index];
      if (part === undefined || part.length === 0) {
        continue;
      }
      const ch = part.charAt(0);
      if (SPLIT_SYMBOLS.indexOf(ch) >= 0 && resolved.indexOf(ch) < 0) {
        resolved += ch;
      }
    }
    return resolved.length > 0 ? resolved : SENTENCE_ENDS;
  }

  /**
   * 在单个行段落内按标点切：扫到标点时把「到该标点为止（含连续标点）」作为一段；
   * 连续标点合并进同一单元末尾。对齐上游 splitAtSymbols。
   */
  private static splitAtSymbols(paragraph: SpeechUnit, symbols: string, out: SpeechUnit[]): void {
    const text = paragraph.text;
    if (text.length === 0) {
      return;
    }
    let start = 0;
    let index = 0;
    while (index < text.length) {
      if (symbols.indexOf(text.charAt(index)) < 0) {
        index++;
        continue;
      }
      let end = index + 1;
      while (end < text.length && symbols.indexOf(text.charAt(end)) >= 0) {
        end++;
      }
      out.push({
        start: paragraph.start + start,
        end: paragraph.start + end,
        text: text.substring(start, end)
      });
      start = end;
      index = end;
    }
    if (start < text.length) {
      out.push({
        start: paragraph.start + start,
        end: paragraph.start + text.length,
        text: text.substring(start)
      });
    }
  }
}
