import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { BudgetedRegexReplace } from '../sourceengine/src/main/ets/core/rule/BudgetedRegexReplace.ts';
import { JavaRegexCompat } from '../sourceengine/src/main/ets/core/rule/JavaRegexCompat.ts';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');

let assertions = 0;

function assert(condition, message) {
  assertions++;
  if (!condition) {
    throw new Error(message);
  }
}

const FAR = Date.now() + 600000;

function paragraph(seed, length) {
  const words = ['他', '看着', '远处', '的', '山', '，', '小说', '章节', '。', '“', '”', ' ', 'abc', '123',
    '最新', '网址', 'www.', '求推荐票', '\u{1F600}', '　'];
  let text = '';
  let state = seed;
  while (text.length < length) {
    state = (state * 1103515245 + 12345) & 0x7fffffff;
    text += words[state % words.length];
  }
  return text;
}

// 一章正文：短段落为主，夹一段超过原生分块上限的长段落，逼出逐起点路径。
const chapter = Array.from({ length: 40 }, (_, i) => paragraph(i + 1, i === 7 ? 1500 : 30 + i * 5)).join('\n');

// 1. 逐起点替换必须与原生全局 replace 逐字一致（显式跨行的规则整段执行）。
const exactCases = [
  ['\\s+', ''],
  ['\\n\\s*\\n', '\n'],
  ['^[\\s\\S]{0,5}', '<$&>'],
  ['[\\s\\S]*?。', '[$&]'],
  ['(?s)“.*?”', '«$0»'],
  ['\\s*$', ''],
  ['(?<num>\\d+)\\s', '${num}|$<num>|$$'],
  ['(?=\\n)', '¶'],
  ['\\p{L}\\s', '_'],
];
for (const [pattern, replacement] of exactCases) {
  const conversion = JavaRegexCompat.convert(pattern, 'g');
  const jsReplacement = JavaRegexCompat.convertReplacement(replacement);
  const replacer = new BudgetedRegexReplace(conversion.source, conversion.flags, false);
  assert(replacer.acrossLines, `显式跨行的规则被判成了按行执行：${pattern}`);
  const expected = chapter.replace(new RegExp(conversion.source, conversion.flags), jsReplacement);
  assert(replacer.replace(chapter, jsReplacement, FAR) === expected, `整段逐起点替换与原生结果不一致：${pattern}`);
}

// 2. 不跨行的规则按行执行，结果与“逐行原生 replace”一致；长行走逐起点路径。
const lineCases = [
  ['小说|章节', ''],
  ['(https?://)?www\\.\\S*', ''],
  ['([\\u3400-\\u9fff])[ \\t\\u00a0]+([\\u3400-\\u9fff])', '$1$2'],
  ['\\W*求.{1,2}票\\W*', ''],
  ['[^。]*最新[^。]*。', '<$&>'],
  ['x*', '-'],
  ['(?m)^\\W+', ''],
  ['(?m)^(.)(.)', '$2$1'],
  ['[^\\r\\n]*网址[^\\r\\n]*', ''],
];
for (const [pattern, replacement] of lineCases) {
  const conversion = JavaRegexCompat.convert(pattern, 'g');
  const replacer = new BudgetedRegexReplace(conversion.source, conversion.flags, false);
  assert(!replacer.acrossLines, `不依赖换行的规则被判成了整段执行：${pattern}`);
  const expected = chapter.split('\n')
    .map((line) => line.replace(new RegExp(conversion.source, conversion.flags), replacement)).join('\n');
  assert(replacer.replace(chapter, replacement, FAR) === expected, `按行替换与逐行原生结果不一致：${pattern}`);
}

// 3. `\r\n` 只在文本真的含 \r 时才算跨行。
const crlfRule = JavaRegexCompat.convert('广告.*(\\r\\n)?.*下载', 'g');
assert(!BudgetedRegexReplace.canMatchAcrossLines(crlfRule.source, crlfRule.flags, false),
  '文本没有 \\r 时，\\r\\n 不应把规则判成跨行');
assert(BudgetedRegexReplace.canMatchAcrossLines(crlfRule.source, crlfRule.flags, true),
  '文本含 \\r 时，\\r\\n 必须按跨行处理');
assert(BudgetedRegexReplace.canMatchAcrossLines('a\\r?\\n', 'g', false), '\\r?\\n 仍然能匹配换行');
assert(BudgetedRegexReplace.canMatchAcrossLines('\\$\\^\\[\\n]', 'g', false),
  '转义后的 \\n 字面量必须算跨行');
assert(!BudgetedRegexReplace.canMatchAcrossLines('价格\\$\\d+|\\^_\\^', 'g', false), '转义的 $ ^ 不是锚点');

// 4. 超时预算：整章回溯的规则必须在预算附近放弃并返回 null，而不是跑完。
const hostile = new BudgetedRegexReplace('(\\B\\W*)?(天才|小说).*[\\s\\S]*(复制|下载)\\W*', 'g', false);
const pureChinese = Array.from({ length: 4000 },() => '他看着远处的山，沉默了很久，才慢慢开口说话。').join('\n');
const startedAt = Date.now();
const hostileResult = hostile.replace(pureChinese, '', startedAt + 200);
const elapsed = Date.now() - startedAt;
assert(hostileResult === null, '超出预算的规则必须返回 null 让调用方保留原文');
assert(elapsed < 1500, `超时后没有及时放弃，耗时 ${elapsed}ms`);
assert(new BudgetedRegexReplace('山', 'g', false).replace(pureChinese, '川', Date.now() - 1) === null,
  '进入时预算已耗尽也必须返回 null');

console.log(`Budgeted regex replace check passed: ${assertions} assertions.`);
