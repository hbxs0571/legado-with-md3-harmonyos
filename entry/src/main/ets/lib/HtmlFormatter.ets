import { decodeEntities, HtmlNode, innerHtml, parseBodyFragment, removeByTagNames } from './HtmlDom';

/**
 * 把书源给的富文本简介洗成纯文本，对齐上游
 * `app/src/main/java/io/legado/app/utils/HtmlFormatter.kt`（`formatDisplayText` / `formatIntroText` /
 * `formatSummaryText` 三个入口）。
 *
 * 上游这三层是套在一起的：
 *   formatDisplayText(html)  去 script/style/noscript、去标签、按段缩进、丢掉「书名/作者/状态」
 *                            这类与书籍信息重复的整行、去掉简介自身的标题词。
 *   formatIntroText(html)    在 display 之上再丢掉书源排版进简介的状态面板（「📡 当前服务：xxx」）
 *                            与纯符号分隔行 —— 书架/列表用这一层，详情页不用（那里状态面板有用）。
 *   formatSummaryText(html)  在 intro 之上压成单行（列表卡片只显示一两行并 ellipsis，
 *                            保留换行会让首段之后的内容被直接截断）。
 *
 * 解析层用 `lib/HtmlDom.ets`（`parseBodyFragment` + `innerHtml` + `decodeEntities`），
 * 对齐上游 Jsoup 的两条关键语义：① 未闭合标签自动补齐；② 序列化时文本节点的 `&` `<` `>`
 * 重新转义成实体，因此末尾要反转义一次。这两条正是正则实现做不到的部分。
 */

/** 上游 `nbspRegex`。 */
const NBSP_REGEX: RegExp = /(&nbsp;)+/g;
/** 上游 `espRegex`。 */
const ESP_REGEX: RegExp = /(&ensp;|&emsp;)/g;
/** 上游 `noPrintRegex`。 */
const NO_PRINT_REGEX: RegExp = /(&thinsp;|&zwnj;|&zwj;|\u2009|\u200C|\u200D)/g;
/** 上游 `wrapHtmlRegex`：块级标签换成换行。 */
const WRAP_HTML_REGEX: RegExp = /<\/?(?:div|p|br|hr|h\d|article|dd|dl)[^>]*>/g;
/** 上游 `commentRegex`。 */
const COMMENT_REGEX: RegExp = /<!--[^>]*-->/g;
/** 上游 `otherHtmlRegex`：`</?[a-zA-Z]+(?=[ >])[^<>]*>`，只删后接空格或 `>` 的标签名。 */
const OTHER_HTML_REGEX: RegExp = /<\/?[a-zA-Z]+(?=[ >])[^<>]*>/g;
/** 上游 `indent1Regex`。 */
const INDENT1_REGEX: RegExp = /\s*\n+\s*/g;
/** 上游 `indent2Regex`。 */
const INDENT2_REGEX: RegExp = /^[\n\s]+/;
/** 上游 `lastRegex`。 */
const LAST_REGEX: RegExp = /[\n\s]+$/;
/** 上游 `mediaBlockRegex`：容器型媒体标签连内容一起删（base64 / SVG 数据都藏在标签内）。 */
const MEDIA_BLOCK_REGEX: RegExp =
  /<(script|style|svg|math|video|audio|canvas|picture|iframe|object|embed|figure|template)\b[^>]*>[\s\S]*?<\/\1\s*>/gi;
/** 上游 `unclosedSvgRegex`：未闭合的 `<svg>` 删到结尾。 */
const UNCLOSED_SVG_REGEX: RegExp = /<svg\b[^>]*>[\s\S]*$/gi;
/** 上游 `voidMediaRegex`：自闭合/空元素标签（`img` 的 `src` 里就是整段 base64）。 */
const VOID_MEDIA_REGEX: RegExp =
  /<(?:img|br|hr|input|source|track|area|col|link|meta)\b[^>]*\/?>/gi;
/** 上游 `dataUriRegex`：散落在属性之外的 data: URI。 */
const DATA_URI_REGEX: RegExp =
  /['"(]?data:[a-z0-9.+-]+\/[a-z0-9.+,-]+(?:;[a-z0-9.+-]+)?(?:;base64)?[^\s'"<>)]*['")]?/gi;
/** 上游 `xmlDeclRegex`。 */
const XML_DECL_REGEX: RegExp = /<\?[\s\S]*?\?>|<!doctype[^>]*>/gi;
/** 上游 `markdownMediaRegex`。 */
const MARKDOWN_MEDIA_REGEX: RegExp = /!\[[^\]]*\]\([^)]*\)/g;
/** 上游 `introPrefixRegex`。 */
const INTRO_PREFIX_REGEX: RegExp = /^<(usehtml|useweb|md)>/i;
/** 上游 `onClickSuffixRegex`。 */
const ON_CLICK_SUFFIX_REGEX: RegExp = /@onclick:[^<\n]*/gi;

/** 上游 `formatDisplayText` 里 `body.select("script, style, noscript").remove()` 的三个标签。 */
const DROP_TAGS: string[] = ['script', 'style', 'noscript'];

/** 上游 `PARAGRAPH_INDENT`：两个全角空格。 */
const PARAGRAPH_INDENT: string = '　　';

/**
 * 上游 `blankChars`：半角空格由 indent 正则处理，这里去掉全角及特殊宽度空格。
 * 含 ' '、'\t'、'\u00a0'、'\u2002'、'\u2003'、'\u2009'、'\u3000'。
 */
const BLANK_CHARS: string[] = [' ', '\t', '\u00a0', '\u2002', '\u2003', '\u2009', '\u3000'];

/** 上游 `metaLabels`：简介里与书籍信息重复的字段名。 */
const META_LABELS: string =
  '书名|名称|书籍名称|作者|译者|分类|类别|类型|题材|状态|连载状态|字数|标签|关键字|来源|首发|' +
  '更新时间|最后更新|最近更新|最新章节|最新更新';

/** 上游 `introLabels`：简介自身的标题，只去标题保留正文。 */
const INTRO_LABELS: string = '内容简介|作品简介|小说简介|内容介绍|简介|文案|摘要';

/** 上游 `metaLineRegex`：整行是「【书名】xxx」或「作者：xxx」（值不超过 40 字）。 */
const META_LINE_REGEX: RegExp =
  new RegExp(`^(?:[【\\[(（](?:${META_LABELS})[】\\])）]|(?:${META_LABELS})\\s*[：:])\\s*.{0,40}$`);

/** 上游 `introLabelRegex`：行首的简介标题。 */
const INTRO_LABEL_REGEX: RegExp =
  new RegExp(`^(?:[【\\[(（](?:${INTRO_LABELS})[】\\])）]|(?:${INTRO_LABELS})\\s*[：:])\\s*`);

/**
 * 上游 `iconMetaLineRegex`：聚合类书源把服务/登录状态排版进简介，
 * 统一是「图标 + 短标签：值」的整行，标签词无法穷举。
 */
const ICON_META_LINE_REGEX: RegExp =
  new RegExp('^(?:\\p{So}[\\uFE0F\\u200D\\s\\u200E]*)+[^：:\\s]{1,8}\\s*[：:]\\s*.{0,40}$', 'u');

/** 上游 `decorationLineRegex`：只有符号没有文字的分隔行/占位行。 */
const DECORATION_LINE_REGEX: RegExp = new RegExp('^[^\\p{L}\\p{N}]+$', 'u');

/** 按 `BLANK_CHARS` 去首尾空白，等价 Kotlin 的 `trim(*blankChars)`。 */
function trimBlank(text: string): string {
  let start = 0;
  let end = text.length;
  while (start < end && BLANK_CHARS.indexOf(text.charAt(start)) >= 0) { start += 1; }
  while (end > start && BLANK_CHARS.indexOf(text.charAt(end - 1)) >= 0) { end -= 1; }
  return text.substring(start, end);
}

/** 按行切开并 trim；空串不进结果（等价 Kotlin 的 `lineSequence().map{trim}.filterNot{isEmpty}`）。 */
function nonEmptyLines(text: string): string[] {
  const result: string[] = [];
  for (const raw of text.split('\n')) {
    const line = trimBlank(raw);
    if (line.length > 0) { result.push(line); }
  }
  return result;
}

/** 把若干行按上游的段首缩进规则拼回去。 */
function indentLines(lines: string[]): string {
  return lines.map((line: string) => PARAGRAPH_INDENT + line).join('\n');
}

/**
 * 上游 `format(html, otherRegex, paragraphIndent)` 的主体：
 * 实体替换 → 块级标签换行 → 去注释 → 去其余标签 → 统一段首缩进 → 去尾部空白。
 */
function format(html: string, otherRegex: RegExp, paragraphIndent: string): string {
  // 上游的 `lineSequence()` 同时认 \r\n 与单独的 \r；这里先把两种换行统一成 \n，
  // 否则 CRLF 书源会把 \r 留在行尾，trim 掉之后行数与上游一致但缩进正则匹配不上。
  const text = html
    .replace(/\r\n/g, '\n')
    .replace(/\r/g, '\n')
    .replace(NBSP_REGEX, ' ')
    .replace(ESP_REGEX, ' ')
    .replace(NO_PRINT_REGEX, '')
    .replace(WRAP_HTML_REGEX, '\n')
    .replace(COMMENT_REGEX, '')
    .replace(otherRegex, '')
    .replace(INDENT1_REGEX, `\n${paragraphIndent}`)
    .replace(INDENT2_REGEX, paragraphIndent)
    .replace(LAST_REGEX, '');
  return text;
}

/**
 * 上游 `parseBodyFragment(html)` + `outputSettings().prettyPrint(false)` +
 * `body.select("script, style, noscript").remove()` + 取 `body.html()`。
 * 单独抽出来，`formatDisplayText` 与 `formatReadableText` 共用。
 */
function bodyHtmlOf(html: string): string {
  const body: HtmlNode = parseBodyFragment(html);
  removeByTagNames(body, DROP_TAGS);
  return innerHtml(body);
}

/**
 * 上游 `formatDisplayText`：给纯文本 UI 面用的清洗。
 * script/style 必须连内容一起删掉，否则脚本源码会被当成正文。
 */
export function formatDisplayText(html: string): string {
  if (html === undefined || html === null || html.trim().length === 0) { return ''; }
  const flattened = format(bodyHtmlOf(html), OTHER_HTML_REGEX, '');
  const lines: string[] = [];
  for (const line of nonEmptyLines(flattened)) {
    if (META_LINE_REGEX.test(line)) { continue; }
    const withoutLabel = trimBlank(line.replace(INTRO_LABEL_REGEX, ''));
    if (withoutLabel.length > 0) { lines.push(withoutLabel); }
  }
  // 上游这一步的 `unescapeHtml4` 是为了还原 `body.html()` 序列化时对文本节点的再转义；
  // 本地 `innerHtml` 同样做了转义（见 lib/HtmlDom.ets 的 escapeText），所以这里必须还原。
  return decodeEntities(indentLines(lines));
}

/**
 * 上游 `formatIntroText`：书架/列表用的简介。
 * 在 display 之上再丢掉书源排版进简介的状态面板与纯符号分隔行。
 */
export function formatIntroText(html: string): string {
  const lines: string[] = [];
  for (const line of nonEmptyLines(formatDisplayText(html))) {
    if (DECORATION_LINE_REGEX.test(line)) { continue; }
    if (ICON_META_LINE_REGEX.test(line)) { continue; }
    lines.push(line);
  }
  return indentLines(lines);
}

/**
 * 上游 `formatSummaryText`：与 intro 同样清洗，但压成单行。
 * 列表/卡片只显示一两行并 ellipsis，保留换行会让首段之后的内容被直接截断。
 */
export function formatSummaryText(html: string): string {
  return nonEmptyLines(formatIntroText(html)).join(' ');
}

/**
 * 上游 `formatReadableText`（`HtmlFormatter.kt:198-216`）：只读卡片用的纯文本。
 * 先剥 `<usehtml>/<useweb>/<md>` 前缀与按钮里的 `@onclick:` 片段，再走同一套 DOM 清洗，
 * 但**不补段首缩进**（上游明确：只读卡片里每行缩进会显得奇怪）。
 */
export function formatReadableText(html: string): string {
  if (html === undefined || html === null || html.trim().length === 0) { return ''; }
  let body: string = html.trim();
  const prefixMatch: RegExpMatchArray | null = body.match(INTRO_PREFIX_REGEX);
  if (prefixMatch !== null && prefixMatch.index !== undefined) {
    const lastLt = body.lastIndexOf('<');
    const prefixEnd = prefixMatch.index + prefixMatch[0].length;
    body = lastLt > prefixEnd ? body.substring(prefixEnd, lastLt) : body.substring(prefixEnd);
  }
  body = body.replace(ON_CLICK_SUFFIX_REGEX, '');
  return decodeEntities(format(bodyHtmlOf(body), OTHER_HTML_REGEX, ''));
}

/**
 * 上游 `stripIntroDecorations`：`formatReadableText` 的两步前缀剥离单独拿出来，
 * 供详情页简介的纯文本回退直接复用。
 */
export function stripIntroDecorations(text: string): string {
  return text.replace(INTRO_PREFIX_REGEX, '').replace(ON_CLICK_SUFFIX_REGEX, '');
}

/**
 * 上游 `HtmlFormatter.format(html: String?, otherRegex: Regex = otherHtmlRegex)`（`utils/HtmlFormatter.kt:74-75`）：
 * 带默认参数的单参版本，内部 `format(html, otherRegex, "　　")`。
 *
 * 与 `formatDisplayText` 的区别就是上游那一条：它不做 script/style 删除、不过滤「书名/作者」行、
 * 不还原实体，只把标签换行、按段缩进。导出书籍的抬头行（`ExportBookService.kt:373` 的
 * `HtmlFormatter.format(book.getDisplayIntro())`）用的正是这一支。
 */
export function formatHtml(html: string): string {
  if (html === undefined || html === null || html.length === 0) { return ''; }
  return format(html, OTHER_HTML_REGEX, PARAGRAPH_INDENT);
}

/**
 * 上游 `countReadableTextLength`（`HtmlFormatter.kt:225-236`）：统计正文真实可读字数。
 * 先剔除媒体标签及其内容、残留 data: URI 与 Markdown 图片语法，再按纯文本计数。
 */
export function countReadableTextLength(content: string): number {
  if (content === undefined || content === null || content.length === 0) { return 0; }
  let text: string = content
    .replace(MEDIA_BLOCK_REGEX, '')
    .replace(UNCLOSED_SVG_REGEX, '')
    .replace(VOID_MEDIA_REGEX, '')
    .replace(MARKDOWN_MEDIA_REGEX, '')
    .replace(XML_DECL_REGEX, '')
    .replace(DATA_URI_REGEX, '');
  // 上游用 `Jsoup.parse(text).text()` 解出纯文本（含实体解码与去标签）
  const body: HtmlNode = parseBodyFragment(text);
  text = textOf(body);
  let count = 0;
  for (let i = 0; i < text.length; i++) {
    const c = text.charAt(i);
    if (c !== ' ' && c !== '\t' && c !== '\n' && c !== '\r' && c !== '\f' &&
      c !== '\u00a0' && c !== '\u3000') {
      count += 1;
    }
  }
  return count;
}

/** 递归取节点下所有文本（等价 Jsoup `Element.text()`：块间补空格、压缩连续空白）。 */
function textOf(node: HtmlNode): string {
  const parts: string[] = [];
  collectText(node, parts);
  return parts.join('').replace(/\s+/g, ' ').trim();
}

function collectText(node: HtmlNode, parts: string[]): void {
  if (node.tagName === '#text') {
    parts.push(node.text);
    return;
  }
  for (const child of node.children) { collectText(child, parts); }
}
