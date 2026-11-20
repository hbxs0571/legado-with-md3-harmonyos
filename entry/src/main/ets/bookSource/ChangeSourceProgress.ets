// 换源进度迁移（P8）：逐行移植上游 BookHelp.getDurChapter（help/book/BookHelp.kt:998-1052）。
// 三档规则：① Jaccard 字符相似度 >0.96 → ② 章节号相等 → ③ 旧索引钳到新目录末章。
// 搜索窗由比例折算 oldIndex*oldTotal/newTotal 推出，上下各 ±10。

/** 移植上游 org.apache.commons.text.similarity.JaccardSimilarity：字符集合交集/并集。 */
function jaccard(a: string, b: string): number {
  if (a.length === 0 && b.length === 0) { return 1; }
  const setA = new Set<string>();
  for (let i = 0; i < a.length; i++) { setA.add(a[i]); }
  const setB = new Set<string>();
  for (let i = 0; i < b.length; i++) { setB.add(b[i]); }
  let inter = 0;
  for (const ch of setA) { if (setB.has(ch)) { inter++; } }
  const union = setA.size + setB.size - inter;
  return union === 0 ? 0 : inter / union;
}

/** 全角转半角（对应 StringUtils.fullToHalf）。 */
function fullToHalf(text: string): string {
  let out = '';
  for (let i = 0; i < text.length; i++) {
    const code = text.charCodeAt(i);
    if (code >= 0xFF01 && code <= 0xFF5E) {
      out += String.fromCharCode(code - 0xFEE0);
    } else if (code === 0x3000) {
      out += ' ';
    } else {
      out += text[i];
    }
  }
  return out;
}

const CN_DIGITS: Record<string, number> = {
  '零': 0, '〇': 0, '一': 1, '二': 2, '两': 2, '三': 3, '四': 4, '五': 5,
  '六': 6, '七': 7, '八': 8, '九': 9,
  '壹': 1, '贰': 2, '叁': 3, '肆': 4, '伍': 5, '陆': 6, '柒': 7, '捌': 8, '玖': 9
};
const CN_UNITS: Record<string, number> = {
  '十': 10, '拾': 10, '百': 100, '佰': 100, '千': 1000, '仟': 1000
};
const NUM_CHARS: string = '0123456789零〇一二两三四五六七八九十百千万壹贰叁肆伍陆柒捌玖拾佰仟';

/** 中文数字串转整数（覆盖上游 stringToInt 的中文数字分支，如「一百二十三」→123）。 */
function cnToInt(text: string): number {
  if (/^\d+$/u.test(text)) { return Number.parseInt(text, 10); }
  if (text.length === 0) { return -1; }
  // 纯中文数字（万以内）：按位累加。
  let total = 0;
  let section = 0;
  let number = 0;
  for (let i = 0; i < text.length; i++) {
    const ch = text[i];
    if (CN_DIGITS[ch] !== undefined) {
      number = CN_DIGITS[ch];
    } else if (CN_UNITS[ch] !== undefined) {
      const unit = CN_UNITS[ch];
      section += (number === 0 ? 1 : number) * unit;
      number = 0;
    } else if (ch === '万') {
      section += number;
      total += section * 10000;
      section = 0;
      number = 0;
    } else {
      return -1;
    }
  }
  return total + section + number;
}

/** 对应上游 getChapterNum：抽取「第X章/回/集...」或「X,」的数字。 */
function getChapterNum(chapterName: string | undefined): number {
  if (chapterName === undefined || chapterName === null) { return -1; }
  const normalized = fullToHalf(chapterName).replace(/\s/gu, '');
  // 第([数字]+)[章节篇回集话]
  const p1 = new RegExp(`第([${NUM_CHARS}]+)[章节篇回集话]`).exec(normalized);
  if (p1 !== null && p1[1] !== undefined) { return cnToInt(p1[1]); }
  // ^([数字]+[,:、])*([数字]+)(?:[,:、]|\.[^\d])
  const p2 = new RegExp(`^(?:[${NUM_CHARS}]+[,:、])*([${NUM_CHARS}]+)(?:[,:、]|\\.[^\\d])`).exec(normalized);
  if (p2 !== null && p2[1] !== undefined) { return cnToInt(p2[1]); }
  return -1;
}

/** 对应上游 getPureChapterName：去空白 + 去章节号 + 去括号 + 去非中日韩字母数字。 */
function pureChapterName(chapterName: string | undefined): string {
  if (chapterName === undefined || chapterName === null) { return ''; }
  let s = fullToHalf(chapterName).replace(/\s/gu, '');
  // regexB：章节号（排除结尾）
  s = s.replace(new RegExp(`^.*?第(?:[${NUM_CHARS}]+)[章节篇回集话](?!$)|^(?:[${NUM_CHARS}]+[,:、])*(?:[${NUM_CHARS}]+)(?:[,:、](?!$)|\\.(?=[^\\d]))`, 'gu'), '');
  // regexC：前后括号附件
  s = s.replace(/(?!^)(?:[〖【《〔\[{(][^〖【《〔\[{()〕》》】〗\]}]+)?[)〕》》】〗\]}]$|^[〖【《〔\[{(](?:[^〖【《〔\[{()〕》》】〗\]}]+[〕》》】〗\]})])?(?!$)/gu, '');
  // regexOther：保留 \w 与 CJK，其余去掉
  s = s.replace(/[^\w\u4E00-\u9FEF〇\u3400-\u4DBF\u20000-\u2A6DF\u2A700-\u2EBEF]/gu, '');
  return s;
}

export interface ChapterLike {
  title: string;
}

/**
 * 换源后定位当前阅读章节在新目录的索引。
 * @param oldIndex 原阅读章节索引（0 基）
 * @param oldTitle 原章节标题
 * @param newChapters 新目录
 * @param oldChapterCount 原书总章节数（用于比例折算，0 表示未知）
 * @returns 新目录中的章节索引
 */
export function getDurChapter(
  oldIndex: number, oldTitle: string | undefined,
  newChapters: ChapterLike[], oldChapterCount: number
): number {
  if (oldIndex <= 0) { return 0; }
  if (newChapters.length === 0) { return oldIndex; }
  const oldNum = getChapterNum(oldTitle);
  const oldName = pureChapterName(oldTitle);
  const newSize = newChapters.length;
  const durIndex = oldChapterCount === 0
    ? oldIndex
    : Math.trunc(oldIndex * oldChapterCount / newSize);
  const min = Math.max(0, Math.min(oldIndex, durIndex) - 10);
  const max = Math.min(newSize - 1, Math.max(oldIndex, durIndex) + 10);

  let nameSim = 0;
  let newIndex = 0;
  let newNum = 0;
  if (oldName.length > 0) {
    for (let i = min; i <= max; i++) {
      const temp = jaccard(oldName, pureChapterName(newChapters[i].title));
      if (temp > nameSim) { nameSim = temp; newIndex = i; }
    }
  }
  if (nameSim < 0.96 && oldNum > 0) {
    for (let i = min; i <= max; i++) {
      const temp = getChapterNum(newChapters[i].title);
      if (temp === oldNum) { newNum = temp; newIndex = i; break; }
      else if (Math.abs(temp - oldNum) < Math.abs(newNum - oldNum)) { newNum = temp; newIndex = i; }
    }
  }
  if (nameSim > 0.96 || Math.abs(newNum - oldNum) < 1) { return newIndex; }
  return Math.min(Math.max(0, newSize - 1), oldIndex);
}
