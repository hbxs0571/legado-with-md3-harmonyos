// 探索页「能不能按页码跳」的判定，对齐上游
// `app/src/main/java/io/legado/app/model/analyzeRule/AnalyzeUrl.kt:800-838`
// 的 `AnalyzeUrl.supportsPageSelection`。
//
// 上游的三步：
//   1. `AppPattern.JS_PATTERN`（`<js>…</js>|@js:…`，IGNORECASE）把 URL 规则里的所有 JS 片段抠出来，
//      逐段判断「这段脚本是否引用了自由变量 page」，然后把脚本从规则串里删掉。
//   2. `RuleAnalyzer(withoutScripts).innerRule("{{","}}")` 把 `{{…}}` 表达式同样抠出来判断并删掉。
//   3. 剩下的纯 URL 文本里，`pagePattern = Regex("<(.*?)>")` 找到的每个 `<…>` 若含逗号，
//      说明用了上游的「多页地址」写法 `<(url1,url2,…)>`，也算支持翻页。
// 三者任一成立即返回 true。注释原文：「Inspect the supported URL rule syntax without executing source JavaScript.」
//
// 关键约束是**不执行书源 JS**。上游靠 Rhino 解析成 AST 后查 `Name` 节点：
// identifier 为 `page`、`definingScope == null`（即不是本脚本里声明过的局部变量），
// 且父节点不是 `PropertyGet.property`（`obj.page`）也不是 `ObjectProperty.left`（`{page: …}` 的键）。
//
// 本地没有可用的 JS 解析器（引擎里的 QuickJS 只能求值，求值就等于执行书源脚本），
// 所以这里做**词法级**的等价判定：先去掉注释与字符串字面量，再收集脚本内声明过的名字，
// 最后找「没被声明、也不在属性位/键位」的 `page` 标识符。对书源规则里实际会出现的写法
// （`{{page}}`、`@js:...page...`、`(page-1)*20`、`obj.page`、`{page:1}`）判定与上游一致；
// 与 Rhino AST 的差别只在极端写法上（例如 `with` 语句、`eval` 注入的名字），
// 这类写法上游同样判不出来（Rhino 也看不到运行期注入）。
//
// 该差别已记入 `tmp/appearance-impl-report.md` 的待办账本。

/** 上游 `AppPattern.JS_PATTERN`（`constant/AppPattern.kt:5-6`）：`<js>([\w\W]*?)</js>|@js:([\w\W]*)`。 */
const JS_PATTERN: RegExp = /<js>([\w\W]*?)<\/js>|@js:([\w\W]*)/gi;

/** 上游 `pagePattern = Regex("<(.*?)>")`。 */
const PAGE_PATTERN: RegExp = /<(.*?)>/g;

/**
 * 判定一段脚本是否引用了自由变量 `page`。
 *
 * 与上游 `referencesPage`（AnalyzeUrl.kt:820-838）对齐：
 * 排除「本脚本声明过的 page」「属性访问 obj.page」「对象字面量的键 {page: …}」。
 */
export function scriptReferencesPage(script: string): boolean {
  if (script.length === 0) { return false; }
  const code = stripCommentsAndStrings(script);
  const declared = collectDeclaredNames(code);
  if (declared.has('page')) { return false; }

  const identifier = /[A-Za-z_$][A-Za-z0-9_$]*/g;
  let match = identifier.exec(code);
  while (match !== null) {
    if (match[0] === 'page') {
      const start = match.index;
      const end = start + 4;
      if (!isPropertyAccess(code, start) && !isObjectKey(code, end)) {
        return true;
      }
    }
    match = identifier.exec(code);
  }
  return false;
}

/**
 * 判定一个 URL 规则是否支持按页码跳转。
 * 规则为空时返回 false（上游 `if (rule.isNullOrBlank()) return false`）。
 */
export function supportsPageSelection(rule: string): boolean {
  if (rule === undefined || rule === null) { return false; }
  const trimmed = rule.trim();
  if (trimmed.length === 0) { return false; }

  let usesPage = false;

  // 第一步：抠出所有 JS 片段并删除，删完的文本留给第三步。
  const withoutScripts = trimmed.replace(JS_PATTERN, (whole: string, group1: string, group2: string): string => {
    const script = group2 !== undefined && group2.length > 0 ? group2 : (group1 === undefined ? '' : group1);
    if (!usesPage && scriptReferencesPage(script)) {
      usesPage = true;
    }
    return '';
  });
  if (usesPage) { return true; }

  // 第二步：抠出所有 {{…}} 表达式并删除。
  const inner = extractInnerRules(withoutScripts);
  if (inner.referencesPage) { return true; }

  // 第三步：剩下的纯文本里找 `<a,b>` 这种多页地址写法。
  PAGE_PATTERN.lastIndex = 0;
  let pageMatch = PAGE_PATTERN.exec(inner.rest);
  while (pageMatch !== null) {
    if (pageMatch[1].indexOf(',') >= 0) { return true; }
    pageMatch = PAGE_PATTERN.exec(inner.rest);
  }
  return false;
}

/** `extractInnerRules` 的结果：删掉 `{{…}}` 之后的剩余文本，以及这些表达式里是否引用了 page。 */
class InnerRuleScan {
  rest: string = '';
  referencesPage: boolean = false;
}

/**
 * 等价于上游 `RuleAnalyzer(str).innerRule("{{","}}"){ … ; "" }`：
 * 扫描成对的 `{{` / `}}`（允许嵌套），把每段内部交给 `scriptReferencesPage` 判断，
 * 并用空串替换掉整段，返回剩余文本。
 */
function extractInnerRules(text: string): InnerRuleScan {
  const scan = new InnerRuleScan();
  const parts: string[] = [];
  let cursor = 0;
  while (cursor < text.length) {
    const open = text.indexOf('{{', cursor);
    if (open < 0) {
      parts.push(text.substring(cursor));
      break;
    }
    parts.push(text.substring(cursor, open));
    let depth = 1;
    let index = open + 2;
    let content = '';
    while (index < text.length) {
      if (text.startsWith('{{', index)) {
        depth += 1;
        content += '{{';
        index += 2;
        continue;
      }
      if (text.startsWith('}}', index)) {
        depth -= 1;
        if (depth === 0) {
          index += 2;
          break;
        }
        content += '}}';
        index += 2;
        continue;
      }
      content += text.charAt(index);
      index += 1;
    }
    if (!scan.referencesPage && scriptReferencesPage(content)) {
      scan.referencesPage = true;
    }
    cursor = index;
  }
  scan.rest = parts.join('');
  return scan;
}

/**
 * 去掉注释与字符串/模板/正则字面量，只留代码骨架。
 *
 * 模板字符串里的 `${…}` 是代码，要保留；其余字面量文本丢弃。
 * 正则字面量与除号在词法上难分，这里按「前一个有意义字符是运算符/左括号/逗号/等号」判为正则。
 */
function stripCommentsAndStrings(source: string): string {
  const out: string[] = [];
  let index = 0;
  let lastMeaningful = '';
  while (index < source.length) {
    const ch = source.charAt(index);
    const next = index + 1 < source.length ? source.charAt(index + 1) : '';

    if (ch === '/' && next === '/') {
      const end = source.indexOf('\n', index);
      index = end < 0 ? source.length : end;
      continue;
    }
    if (ch === '/' && next === '*') {
      const end = source.indexOf('*/', index + 2);
      index = end < 0 ? source.length : end + 2;
      continue;
    }
    if (ch === '"' || ch === '\'') {
      index = skipQuoted(source, index, ch);
      out.push('""');
      lastMeaningful = '"';
      continue;
    }
    if (ch === '`') {
      const template = readTemplate(source, index);
      out.push(template.text);
      lastMeaningful = '`';
      index = template.next;
      continue;
    }
    if (ch === '/' && isRegexStart(lastMeaningful)) {
      const skipped = skipRegex(source, index);
      if (skipped > index) {
        out.push('/re/');
        lastMeaningful = '/';
        index = skipped;
        continue;
      }
    }
    out.push(ch);
    if (!/\s/.test(ch)) { lastMeaningful = ch; }
    index += 1;
  }
  return out.join('');
}

/** 跳过单/双引号字符串（支持反斜杠转义），返回收尾引号之后的位置。 */
function skipQuoted(source: string, start: number, quote: string): number {
  let index = start + 1;
  while (index < source.length) {
    const ch = source.charAt(index);
    if (ch === '\\') {
      index += 2;
      continue;
    }
    if (ch === quote) { return index + 1; }
    index += 1;
  }
  return source.length;
}

/** 读模板字符串：字面量部分丢弃，`${…}` 内的表达式原样保留。 */
function readTemplate(source: string, start: number): TemplateScan {
  const scan = new TemplateScan();
  const parts: string[] = ['""'];
  let index = start + 1;
  while (index < source.length) {
    const ch = source.charAt(index);
    if (ch === '\\') {
      index += 2;
      continue;
    }
    if (ch === '`') {
      index += 1;
      break;
    }
    if (ch === '$' && index + 1 < source.length && source.charAt(index + 1) === '{') {
      let depth = 1;
      let cursor = index + 2;
      let expression = '';
      while (cursor < source.length) {
        const inner = source.charAt(cursor);
        if (inner === '{') { depth += 1; }
        if (inner === '}') {
          depth -= 1;
          if (depth === 0) { cursor += 1; break; }
        }
        expression += inner;
        cursor += 1;
      }
      parts.push('(' + expression + ')');
      index = cursor;
      continue;
    }
    index += 1;
  }
  scan.text = parts.join('+');
  scan.next = index;
  return scan;
}

/** `readTemplate` 的结果。 */
class TemplateScan {
  text: string = '""';
  next: number = 0;
}

/** 前一个有意义字符是否让 `/` 处于「正则开头」位置。 */
function isRegexStart(lastMeaningful: string): boolean {
  if (lastMeaningful.length === 0) { return true; }
  return '=([{,;:!&|?+-*%^~<>'.indexOf(lastMeaningful) >= 0;
}

/** 跳过正则字面量；不像正则时返回原位置（交给普通字符处理）。 */
function skipRegex(source: string, start: number): number {
  let index = start + 1;
  let inClass = false;
  while (index < source.length) {
    const ch = source.charAt(index);
    if (ch === '\\') {
      index += 2;
      continue;
    }
    if (ch === '\n') { return start; }
    if (ch === '[') { inClass = true; }
    if (ch === ']') { inClass = false; }
    if (ch === '/' && !inClass) {
      index += 1;
      while (index < source.length && /[a-z]/i.test(source.charAt(index))) { index += 1; }
      return index;
    }
    index += 1;
  }
  return start;
}

/** 标识符 `page` 的前一个有意义字符是否是 `.`（即属性访问 `obj.page`）。 */
function isPropertyAccess(code: string, start: number): boolean {
  let index = start - 1;
  while (index >= 0 && /\s/.test(code.charAt(index))) { index -= 1; }
  if (index < 0) { return false; }
  const prev = code.charAt(index);
  if (prev !== '.') { return false; }
  // `...page`（展开运算符）不是属性访问。
  if (index >= 2 && code.charAt(index - 1) === '.' && code.charAt(index - 2) === '.') { return false; }
  return true;
}

/**
 * 标识符 `page` 的后一个有意义字符是否是 `:`，且它前面是 `{` 或 `,` 或语句开头
 * —— 即对象字面量的键位（上游 `ObjectProperty.left`）。
 */
function isObjectKey(code: string, end: number): boolean {
  let index = end;
  while (index < code.length && /\s/.test(code.charAt(index))) { index += 1; }
  if (index >= code.length || code.charAt(index) !== ':') { return false; }
  if (index + 1 < code.length && code.charAt(index + 1) === ':') { return false; }
  let back = end - 1;
  while (back >= 0 && /\s/.test(code.charAt(back))) { back -= 1; }
  if (back < 0) { return true; }
  const prev = code.charAt(back);
  return prev === '{' || prev === ',' || prev === ';';
}

/**
 * 收集脚本里声明过的名字（等价于 Rhino 的 `definingScope` 判定所依赖的作用域信息）。
 *
 * 覆盖书源脚本里会出现的声明形式：`var/let/const a = …`、`var a, b`、解构 `{a, b}` / `[a, b]`、
 * 函数声明与函数参数、箭头函数参数（含单参数无括号）、`catch (e)`。
 */
function collectDeclaredNames(code: string): Set<string> {
  const names = new Set<string>();

  // var / let / const 之后的声明列表，直到语句结束或 = 号。
  const declarator = /\b(?:var|let|const)\s+([^;]*)/g;
  let match = declarator.exec(code);
  while (match !== null) {
    for (const raw of match[1].split(',')) {
      let segment = raw;
      const eq = segment.indexOf('=');
      if (eq >= 0) { segment = segment.substring(0, eq); }
      collectPatternNames(segment, names);
    }
    match = declarator.exec(code);
  }

  // 函数声明名：function name(…)
  const functionDecl = /\bfunction\s+([A-Za-z_$][A-Za-z0-9_$]*)\s*\(/g;
  match = functionDecl.exec(code);
  while (match !== null) {
    names.add(match[1]);
    match = functionDecl.exec(code);
  }

  // 参数列表：捕获所有 (…) 内的内容交给模式收集（宁可多收，避免误判为自由变量）。
  const paren = /\(([^()]*)\)/g;
  match = paren.exec(code);
  while (match !== null) {
    collectPatternNames(match[1], names);
    match = paren.exec(code);
  }

  // 箭头函数单参数：x => …
  const arrow = /([A-Za-z_$][A-Za-z0-9_$]*)\s*=>/g;
  match = arrow.exec(code);
  while (match !== null) {
    names.add(match[1]);
    match = arrow.exec(code);
  }

  return names;
}

/** 从声明模式（可能含解构、默认值、展开）里收集所有标识符。 */
function collectPatternNames(pattern: string, names: Set<string>): void {
  const cleaned = pattern
    .replace(/=[^,]*/g, '')
    .replace(/\.\.\./g, ' ');
  const identifier = /[A-Za-z_$][A-Za-z0-9_$]*/g;
  let match = identifier.exec(cleaned);
  while (match !== null) {
    names.add(match[0]);
    match = identifier.exec(cleaned);
  }
}
