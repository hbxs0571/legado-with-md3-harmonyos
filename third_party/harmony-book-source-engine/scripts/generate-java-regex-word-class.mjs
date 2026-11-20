// 生成 JavaRegexCompat.ts 里 <generated:word-class> 标记之间的字符表。
// Android 的 java.util.regex 基于 ICU，预定义字符类恒为 Unicode 语义：
//   \w = [\p{Alphabetic}\p{Mark}\p{Decimal_Number}\p{Connector_Punctuation}\u200C\u200D]
//   \d = \p{Decimal_Number}
// JavaScript 不带 u 标志时无法写 \p{…}，所以把基本多文种平面内的范围展开成字面量表。
// 未分配码位不会出现在正文里，两侧同类时直接并入，以减少范围数量。
// 用法：node scripts/generate-java-regex-word-class.mjs
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const unassigned = /\p{Cn}/u;

function build(member) {
  const ranges = [];
  let start = -1;
  let last = -1;
  for (let code = 0; code <= 0x10000; code++) {
    const surrogate = code >= 0xD800 && code <= 0xDFFF;
    const text = String.fromCharCode(code);
    const inside = code <= 0xFFFF && !surrogate && member.test(text);
    const free = code <= 0xFFFF && !surrogate && !inside && unassigned.test(text);
    if (inside) {
      if (start < 0) start = code;
      last = code;
    } else if (!free && start >= 0) {
      ranges.push([start, last]);
      start = -1;
    }
  }
  const complement = [];
  let cursor = 0;
  for (const [from, to] of ranges) {
    if (from > cursor) complement.push([cursor, from - 1]);
    cursor = to + 1;
  }
  if (cursor <= 0xFFFF) complement.push([cursor, 0xFFFF]);
  return [ranges, complement];
}

function escape(code) {
  return '\\u' + code.toString(16).toUpperCase().padStart(4, '0');
}

function serialize(ranges) {
  return ranges.map(([from, to]) =>
    from === to ? escape(from) : to === from + 1 ? escape(from) + escape(to) : `${escape(from)}-${escape(to)}`).join('');
}

function literal(name, value) {
  const lines = value.match(/.{1,96}(?=\\u|$)/g).map((line) => `    '${line.replace(/\\/g, '\\\\')}'`);
  return `  private static readonly ${name}: string =\n${lines.join(' +\n')};\n`;
}

const [wordRanges, nonWordRanges] = build(/[\p{Alphabetic}\p{M}\p{Nd}\p{Pc}\u200c\u200d]/u);
const [digitRanges, nonDigitRanges] = build(/\p{Nd}/u);

const target = path.join(root, 'sourceengine/src/main/ets/core/rule/JavaRegexCompat.ts');
const source = fs.readFileSync(target, 'utf8');
const eol = source.includes('\r\n') ? '\r\n' : '\n';
const open = '  // <generated:word-class>';
const close = '  // </generated:word-class>';
const from = source.indexOf(open);
const to = source.indexOf(close);
if (from < 0 || to < from) throw new Error('JavaRegexCompat.ts 缺少 <generated:word-class> 标记');
const generated = (literal('WORD_CONTENT', serialize(wordRanges)) +
  literal('NON_WORD_CONTENT', serialize(nonWordRanges)) +
  literal('DIGIT_CONTENT', serialize(digitRanges)) +
  literal('NON_DIGIT_CONTENT', serialize(nonDigitRanges))).replace(/\n/g, eol);
fs.writeFileSync(target, source.substring(0, from) + open + eol + generated + source.substring(to));
console.log(`word ranges: ${wordRanges.length}, non-word ranges: ${nonWordRanges.length}, ` +
  `digit ranges: ${digitRanges.length}, non-digit ranges: ${nonDigitRanges.length}`);
