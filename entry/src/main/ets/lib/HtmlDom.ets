/**
 * 轻量 HTML DOM：对齐上游 `org.jsoup.Jsoup.parseBodyFragment` 用到的语义子集。
 *
 * 上游 `HtmlFormatter.kt` 的三个入口（`formatDisplayText` / `formatIntroText` / `formatSummaryText`）
 * 都先建 DOM 再取 `body.html()`，靠解析器拿到两件正则做不到的事：
 *   ① 未闭合标签被自动补齐（`<div><p>a` 补成 `<div><p>a</p></div>`）；
 *   ② 文本节点里的 `&` `<` `>` 被重新转义成实体，所以末尾要 `unescapeHtml4` 一次。
 * 本文件只实现这三步所需的最小能力：建树、按标签名删节点、序列化内部 HTML、实体编解码。
 * 不做 CSS 选择器、不做属性查询、不做文档修复（`<html>`/`<head>` 补全）——上游这条链路也不用。
 *
 * 与 Jsoup 仍有的差异（已记入 `tmp/appearance-impl-report.md` 待办账本）：
 *   - 不实现「活动内容」限制（`<form>` 嵌套等）与 `<table>` 的隐式 `<tbody>` 插入；
 *   - 不实现字符集探测与 `<meta charset>` 重解码（输入已是 JS 字符串）。
 * 这两类输入在书源简介里不存在，且它们都不影响「去标签 + 补全 + 转义」的结果。
 */

/** 自闭合/空元素：不产生子节点，序列化时也不输出结束标签。 */
const VOID_TAGS: string[] = [
  'area', 'base', 'br', 'col', 'embed', 'hr', 'img', 'input',
  'link', 'meta', 'param', 'source', 'track', 'wbr'
];

/** 内容按原文保留、内部不再当标签解析的元素（对齐 HTML 规范的 raw text elements）。 */
const RAW_TEXT_TAGS: string[] = ['script', 'style', 'textarea', 'title'];

/** 文本节点的伪标签名。 */
export const TEXT_NODE: string = '#text';

/** 解析结果的节点。`tagName === TEXT_NODE` 时只看 `text`，其余字段无意义。 */
export class HtmlNode {
  tagName: string = TEXT_NODE;
  text: string = '';
  attributes: Map<string, string> = new Map<string, string>();
  children: HtmlNode[] = [];
}

/** 一个开始标签的解析结果。 */
interface ParsedTag {
  name: string;
  attributes: Map<string, string>;
  selfClosing: boolean;
}

/** HTML4 命名实体表：覆盖 `StringEscapeUtils.unescapeHtml4` 的常用项。 */
const NAMED_ENTITIES: Map<string, string> = new Map<string, string>([
  ['amp', '&'], ['lt', '<'], ['gt', '>'], ['quot', '"'], ['apos', '\''],
  ['nbsp', '\u00a0'], ['ensp', '\u2002'], ['emsp', '\u2003'], ['thinsp', '\u2009'],
  ['copy', '\u00a9'], ['reg', '\u00ae'], ['trade', '\u2122'], ['hellip', '\u2026'],
  ['mdash', '\u2014'], ['ndash', '\u2013'], ['lsquo', '\u2018'], ['rsquo', '\u2019'],
  ['ldquo', '\u201c'], ['rdquo', '\u201d'], ['middot', '\u00b7'], ['bull', '\u2022'],
  ['times', '\u00d7'], ['divide', '\u00f7'], ['laquo', '\u00ab'], ['raquo', '\u00bb'],
  ['sect', '\u00a7'], ['deg', '\u00b0'], ['plusmn', '\u00b1'], ['frac12', '\u00bd'],
  ['sup2', '\u00b2'], ['sup3', '\u00b3'], ['micro', '\u00b5'], ['para', '\u00b6'],
  ['dagger', '\u2020'], ['Dagger', '\u2021'], ['permil', '\u2030'], ['prime', '\u2032'],
  ['Prime', '\u2033'], ['oline', '\u203e'], ['frasl', '\u2044'], ['euro', '\u20ac'],
  ['pound', '\u00a3'], ['yen', '\u00a5'], ['cent', '\u00a2'], ['curren', '\u00a4'],
  ['brvbar', '\u00a6'], ['uml', '\u00a8'], ['ordf', '\u00aa'], ['not', '\u00ac'],
  ['shy', '\u00ad'], ['macr', '\u00af'], ['acute', '\u00b4'], ['cedil', '\u00b8'],
  ['ordm', '\u00ba'], ['iquest', '\u00bf'], ['excl', '!'], ['num', '#'], ['dollar', '$'],
  ['percnt', '%'], ['lpar', '('], ['rpar', ')'], ['ast', '*'], ['plus', '+'],
  ['comma', ','], ['period', '.'], ['sol', '/'], ['colon', ':'], ['semi', ';'],
  ['equals', '='], ['quest', '?'], ['commat', '@'], ['lsqb', '['], ['bsol', '\\'],
  ['rsqb', ']'], ['Hat', '^'], ['lowbar', '_'], ['grave', '`'], ['lcub', '{'],
  ['verbar', '|'], ['rcub', '}'], ['tilde', '~']
]);

/** 实体正则：命名实体或数字实体（十进制/十六进制）。 */
const ENTITY_REGEX: RegExp = /&(#x?[0-9a-fA-F]+|[a-zA-Z][a-zA-Z0-9]*);/g;

/** 判断是否 HTML 空白（对齐 Jsoup 的 `isWhitespace`，不含全角空格）。 */
function isSpace(c: string): boolean {
  return c === ' ' || c === '\t' || c === '\n' || c === '\r' || c === '\f';
}

/**
 * 解 HTML 实体，等价上游 `StringEscapeUtils.unescapeHtml4`。
 * 无法识别的实体原样保留（上游同样保留）。
 */
export function decodeEntities(text: string): string {
  if (text.indexOf('&') < 0) { return text; }
  return text.replace(ENTITY_REGEX, (whole: string, body: string): string => {
    if (body.charAt(0) === '#') {
      const isHex = body.charAt(1) === 'x' || body.charAt(1) === 'X';
      const digits = isHex ? body.substring(2) : body.substring(1);
      const code = parseInt(digits, isHex ? 16 : 10);
      if (Number.isNaN(code) || code <= 0 || code > 0x10ffff) { return whole; }
      return String.fromCodePoint(code);
    }
    const mapped = NAMED_ENTITIES.get(body);
    if (mapped !== undefined) { return mapped; }
    const lower = NAMED_ENTITIES.get(body.toLowerCase());
    return lower === undefined ? whole : lower;
  });
}

/**
 * 文本节点的输出转义，对齐 Jsoup 序列化：`&` `<` `>` 与不换行空格。
 * 上游正是靠这一步把 `&` 变成 `&amp;`，所以 `formatDisplayText` 末尾才要反转义一次。
 */
function escapeText(text: string): string {
  let out = '';
  for (let i = 0; i < text.length; i++) {
    const c = text.charAt(i);
    if (c === '&') { out += '&amp;'; }
    else if (c === '<') { out += '&lt;'; }
    else if (c === '>') { out += '&gt;'; }
    else if (c === '\u00a0') { out += '&nbsp;'; }
    else { out += c; }
  }
  return out;
}

/** 属性值的输出转义，对齐 Jsoup 序列化。 */
function escapeAttribute(value: string): string {
  let out = '';
  for (let i = 0; i < value.length; i++) {
    const c = value.charAt(i);
    if (c === '&') { out += '&amp;'; }
    else if (c === '"') { out += '&quot;'; }
    else if (c === '\u00a0') { out += '&nbsp;'; }
    else { out += c; }
  }
  return out;
}

/** 从 `start` 处的 `<` 往后找本标签的 `>`，跳过引号内的内容（属性值里可能有 `>`）。 */
function findTagEnd(html: string, start: number): number {
  let i = start + 1;
  let quote = '';
  while (i < html.length) {
    const c = html.charAt(i);
    if (quote.length > 0) {
      if (c === quote) { quote = ''; }
    } else if (c === '"' || c === '\'') {
      quote = c;
    } else if (c === '>') {
      return i;
    }
    i++;
  }
  return -1;
}

/** 解析 `<a href="x" disabled>` 里 `a href="x" disabled` 这一段。 */
function parseStartTag(raw: string): ParsedTag {
  const n = raw.length;
  let i = 0;
  while (i < n && isSpace(raw.charAt(i))) { i++; }
  const nameStart = i;
  while (i < n && !isSpace(raw.charAt(i)) && raw.charAt(i) !== '/') { i++; }
  const name = raw.substring(nameStart, i).toLowerCase();
  const attributes: Map<string, string> = new Map<string, string>();
  let selfClosing = false;
  while (i < n) {
    while (i < n && isSpace(raw.charAt(i))) { i++; }
    if (i >= n) { break; }
    if (raw.charAt(i) === '/') { selfClosing = true; i++; continue; }
    const attrStart = i;
    while (i < n && !isSpace(raw.charAt(i)) && raw.charAt(i) !== '=' && raw.charAt(i) !== '/') { i++; }
    const attrName = raw.substring(attrStart, i).toLowerCase();
    if (attrName.length === 0) { i++; continue; }
    while (i < n && isSpace(raw.charAt(i))) { i++; }
    let attrValue = '';
    if (i < n && raw.charAt(i) === '=') {
      i++;
      while (i < n && isSpace(raw.charAt(i))) { i++; }
      const quote = i < n ? raw.charAt(i) : '';
      if (quote === '"' || quote === '\'') {
        i++;
        const valueStart = i;
        while (i < n && raw.charAt(i) !== quote) { i++; }
        attrValue = raw.substring(valueStart, i);
        if (i < n) { i++; }
      } else {
        const valueStart = i;
        while (i < n && !isSpace(raw.charAt(i))) { i++; }
        attrValue = raw.substring(valueStart, i);
      }
    }
    attributes.set(attrName, decodeEntities(attrValue));
  }
  const parsed: ParsedTag = { name: name, attributes: attributes, selfClosing: selfClosing };
  return parsed;
}

/** 结束标签：弹栈到最近的同名开放元素（找不到就忽略，对齐浏览器的容错）。 */
function closeTag(stack: HtmlNode[], tagName: string): void {
  if (tagName.length === 0) { return; }
  for (let i = stack.length - 1; i >= 1; i--) {
    if (stack[i].tagName === tagName) {
      while (stack.length > i) { stack.pop(); }
      return;
    }
  }
}

/** 往当前开放元素下挂一个文本节点。 */
function appendText(stack: HtmlNode[], raw: string): void {
  if (raw.length === 0) { return; }
  const parent = stack[stack.length - 1];
  const node = new HtmlNode();
  node.tagName = TEXT_NODE;
  node.text = decodeEntities(raw);
  parent.children.push(node);
}

/**
 * 建 body 树，等价上游 `Jsoup.parseBodyFragment(html).body()`。
 *
 * 扫描方式：逐字符找 `<`，判断它是注释/声明/结束标签/开始标签/普通文本；
 * 开始标签压栈、结束标签弹栈，未闭合的留在栈里直到函数返回（即被自动补齐）。
 * `script`/`style` 这类 raw text 元素的内容整段跳过，不当标签解析。
 */
export function parseBodyFragment(html: string): HtmlNode {
  const body = new HtmlNode();
  body.tagName = 'body';
  const stack: HtmlNode[] = [body];
  const lowerHtml = html.toLowerCase();
  const n = html.length;
  let i = 0;
  let textStart = 0;

  while (i < n) {
    if (html.charAt(i) !== '<') { i++; continue; }
    const next = i + 1 < n ? html.charAt(i + 1) : '';
    const isTagLike = (next >= 'a' && next <= 'z') || (next >= 'A' && next <= 'Z') ||
      next === '/' || next === '!' || next === '?';
    if (!isTagLike) {
      // 孤立的 `<`（如 `a < b`）当普通文本，留在 textStart 段里
      i++;
      continue;
    }

    if (i > textStart) { appendText(stack, html.substring(textStart, i)); }

    // 注释：整段丢弃（对齐 Jsoup 默认不保留注释节点）
    if (html.startsWith('<!--', i)) {
      const commentEnd = html.indexOf('-->', i + 4);
      i = commentEnd < 0 ? n : commentEnd + 3;
      textStart = i;
      continue;
    }
    // doctype / XML 声明 / CDATA：整段丢弃
    if (next === '!' || next === '?') {
      const declEnd = html.indexOf('>', i);
      i = declEnd < 0 ? n : declEnd + 1;
      textStart = i;
      continue;
    }
    // 结束标签
    if (next === '/') {
      const endClose = html.indexOf('>', i);
      if (endClose < 0) { i = n; textStart = i; continue; }
      const closeName = html.substring(i + 2, endClose).trim().toLowerCase();
      closeTag(stack, closeName);
      i = endClose + 1;
      textStart = i;
      continue;
    }

    // 开始标签
    const tagEnd = findTagEnd(html, i);
    if (tagEnd < 0) { i = n; textStart = i; continue; }
    const parsed = parseStartTag(html.substring(i + 1, tagEnd));
    i = tagEnd + 1;
    textStart = i;
    if (parsed.name.length === 0) { continue; }

    const parent = stack[stack.length - 1];
    const element = new HtmlNode();
    element.tagName = parsed.name;
    element.attributes = parsed.attributes;
    parent.children.push(element);

    // raw text 元素：内容整段读掉，不进标签解析
    if (RAW_TEXT_TAGS.indexOf(parsed.name) >= 0) {
      const closeSeq = '</' + parsed.name;
      let closeAt = lowerHtml.indexOf(closeSeq, i);
      if (closeAt < 0) { closeAt = n; }
      const content = html.substring(i, closeAt);
      if (content.length > 0) {
        const textNode = new HtmlNode();
        textNode.tagName = TEXT_NODE;
        textNode.text = content;
        element.children.push(textNode);
      }
      if (closeAt >= n) {
        i = n;
      } else {
        const closeEnd = html.indexOf('>', closeAt);
        i = closeEnd < 0 ? n : closeEnd + 1;
      }
      textStart = i;
      continue;
    }

    if (parsed.selfClosing || VOID_TAGS.indexOf(parsed.name) >= 0) { continue; }
    stack.push(element);
  }

  if (textStart < n) { appendText(stack, html.substring(textStart)); }
  return body;
}

/** 递归删掉指定标签名的后代（含其内容），等价上游 `body.select(...).remove()`。 */
export function removeByTagNames(node: HtmlNode, tagNames: string[]): void {
  const kept: HtmlNode[] = [];
  for (const child of node.children) {
    if (child.tagName !== TEXT_NODE && tagNames.indexOf(child.tagName) >= 0) { continue; }
    if (child.tagName !== TEXT_NODE) { removeByTagNames(child, tagNames); }
    kept.push(child);
  }
  node.children = kept;
}

/** 写一个节点（含自身标签）到输出缓冲。 */
function writeNode(node: HtmlNode, out: string[]): void {
  if (node.tagName === TEXT_NODE) {
    out.push(escapeText(node.text));
    return;
  }
  out.push('<');
  out.push(node.tagName);
  node.attributes.forEach((value: string, key: string) => {
    out.push(' ');
    out.push(key);
    out.push('="');
    out.push(escapeAttribute(value));
    out.push('"');
  });
  out.push('>');
  if (VOID_TAGS.indexOf(node.tagName) >= 0) { return; }
  for (const child of node.children) { writeNode(child, out); }
  out.push('</');
  out.push(node.tagName);
  out.push('>');
}

/**
 * 序列化节点的**内部** HTML，等价上游 `body.html()`（不含 body 自身标签）。
 * 输出里文本节点的 `&` `<` `>` 已被转义成实体，所以调用方拿到后需要 `decodeEntities` 还原。
 */
export function innerHtml(node: HtmlNode): string {
  const out: string[] = [];
  for (const child of node.children) { writeNode(child, out); }
  return out.join('');
}

/** 序列化节点自身（含标签），便于调试与单测；上游没有对应入口。 */
export function outerHtml(node: HtmlNode): string {
  const out: string[] = [];
  writeNode(node, out);
  return out.join('');
}
