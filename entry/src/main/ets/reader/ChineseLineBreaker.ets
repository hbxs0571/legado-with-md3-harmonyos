/**
 * 中文断行避头尾，对齐上游 `feature/reader/core/layout/ChineseLineBreaker.kt`。
 *
 * 上游把整段切成 cluster 后一次性断行（`ReaderPaginator.kt:559` 无条件调用，
 * 不受 `useZhLayout` 控制）；本地分页器是逐字符累加的，所以这里只抽「断点合不合法」
 * 这一条判据：溢出发生时，本行末尾需要回搬几个字符到下一行，才能保证
 *   1. 下一行行首不是收尾标点（`，。！？》）` 等）；
 *   2. 本行行尾不是开引号/开括号（`“（《` 等）；
 *   3. 例外：同一个收尾标点连打（`！！！`）之间允许断行，行首出现该标点合法。
 *
 * 上游另有 HANG 模式（标点悬挂在本行右边界之外）。本地画布按 Paragraph 绘制、
 * 段落宽度已由分页器给定，无法让字形越界绘制，故本模块只做回搬。
 */

/** 收尾标点：不允许出现在行首（连打例外除外）。与上游 `closing` 集合逐项对应。 */
const CLOSING_MARKS: string[] = [
  '！', '，', '。', '、', '；', '：', '？', '”', '’', '）', '］', '｝', '》',
  '〉', '〕', '】', '〗', '」', '』', '﹂', '﹄', '…', '—', '～', '·',
  '!', ',', '.', ':', ';', '?', ')', ']', '}', '>'
];

/** 开标点：不允许出现在行尾。与上游 `opening` 集合逐项对应。 */
const OPENING_MARKS: string[] = [
  '“', '‘', '（', '［', '｛', '《', '〈', '〔', '【', '〖', '『', '「', '﹁', '﹃',
  '(', '[', '{', '<'
];

const CLOSING_SET: Set<string> = new Set<string>(CLOSING_MARKS);
const OPENING_SET: Set<string> = new Set<string>(OPENING_MARKS);

export class ChineseLineBreaker {
  static isClosing(cluster: string): boolean {
    return CLOSING_SET.has(cluster);
  }

  static isOpening(cluster: string): boolean {
    return OPENING_SET.has(cluster);
  }

  /** 词间空格（含不换行空格、全角空格）：断行时只能留在行尾，不能出现在行首。 */
  static isWordSpace(cluster: string): boolean {
    if (cluster.length === 0) {
      return false;
    }
    for (let index = 0; index < cluster.length; index++) {
      const code = cluster.charCodeAt(index);
      const isSpace = (code >= 0x09 && code <= 0x0D) || code === 0x20 || code === 0xA0 ||
        code === 0x1680 || code === 0x2028 || code === 0x2029 || code === 0x202F ||
        code === 0x205F || code === 0x3000 || code === 0xFEFF;
      if (!isSpace) {
        return false;
      }
    }
    return true;
  }

  /**
   * 断点是否非法：下一行行首是收尾标点（且不是连打），或本行行尾是开标点。
   * 与上游 `isForbiddenBreak(previous, next)` 同口径。
   */
  static isForbiddenBreak(previous: string, next: string): boolean {
    return (ChineseLineBreaker.isClosing(next) && previous !== next) ||
      ChineseLineBreaker.isOpening(previous);
  }

  /**
   * 溢出时本行末尾需要搬到下一行的 cluster 数。
   *
   * [lineClusters] 是本行已有的 cluster 序列，[next] 是放不下的那个字符。
   * 返回 0 表示直接在 [next] 前断行；返回 n>0 表示连本行末尾 n 个一起搬走。
   *
   * 从末尾往前找第一个合法断点：k 个被搬走时，断点落在
   * `lineClusters[total-k-1]` 与 `lineClusters[total-k]` 之间。
   * 找不到合法断点（整行都是标点）就退回「只留行首一个字符」的折中。
   */
  static resolve(lineClusters: string[], next: string): number {
    const total = lineClusters.length;
    if (total === 0) {
      return 0;
    }
    const last = lineClusters[total - 1] ?? '';
    if (!ChineseLineBreaker.isForbiddenBreak(last, next)) {
      return 0;
    }
    for (let carried = 1; carried < total; carried++) {
      const breakBefore = lineClusters[total - carried - 1] ?? '';
      const breakAfter = lineClusters[total - carried] ?? '';
      if (!ChineseLineBreaker.isForbiddenBreak(breakBefore, breakAfter)) {
        return carried;
      }
    }
    // 整行全是标点（或只剩首字符）：留一个字符在本行，其余全部下移
    return Math.max(0, total - 1);
  }

  /**
   * 把一行文本按 codePoint 从尾部切掉 [count] 个 cluster。
   * 返回 [head] 留在本行、[tail] 下移到下一行；count 超出范围时 tail 为空串。
   */
  static splitTail(text: string, count: number): string[] {
    if (count <= 0 || text.length === 0) {
      return [text, ''];
    }
    let cursor = text.length;
    let remaining = count;
    while (cursor > 0 && remaining > 0) {
      cursor -= 1;
      const code = text.charCodeAt(cursor);
      // 落在代理对的后半：再往前退一格，保证整对一起搬走
      if (code >= 0xDC00 && code <= 0xDFFF && cursor > 0) {
        cursor -= 1;
      }
      remaining--;
    }
    return [text.substring(0, cursor), text.substring(cursor)];
  }
}
