import { BookSource } from '../model/BookSource';
import { ReplaceRule } from '../model/ReplaceRule';

/**
 * 旧版数据导入（十年前的 Legado 备份格式）。
 *
 * 上游：app/src/main/java/io/legado/app/help/storage/ImportOldData.kt
 * 三份文件：`myBookShelf.json`（书架）、`myBookSource.json`（书源）、
 * `myBookReplaceRule.json`（替换规则）。书架的解析在 `OldBookShelfImporter`，
 * 这里补书源与替换规则两条，以及三份文件共用的旧字段 → 新字段转换。
 *
 * 旧格式与新格式的核心差别（上游 `toNewRule`/`toNewUrl` 的存在理由）：
 * 旧版规则用单个 `#` 分隔「正则#替换」，新版用 `##`；旧版 URL 规则用 `|` 分字符集、
 * `@` 分 POST body、`@Header:{...}` 内联请求头、`{{...}}` 内联 js、`searchKey`/`searchPage`
 * 占位。这些都要在导入时翻译成新语法，否则规则会被当成纯文本选择器。
 */

/** 旧版书源一条的原始字段；全部可选，缺字段比完整记录更常见。 */
interface RawOldSource {
  bookSourceUrl?: string;
  bookSourceName?: string;
  bookSourceGroup?: string;
  bookSourceType?: string;
  bookSourceComment?: string;
  loginUrl?: string;
  loginUi?: string;
  loginCheckJs?: string;
  coverDecodeJs?: string;
  ruleBookUrlPattern?: string;
  serialNumber?: number;
  httpUserAgent?: string;
  ruleSearchUrl?: string;
  ruleFindUrl?: string;
  enable?: boolean;
  ruleSearchList?: string;
  ruleSearchName?: string;
  ruleSearchAuthor?: string;
  ruleSearchIntroduce?: string;
  ruleSearchKind?: string;
  ruleSearchNoteUrl?: string;
  ruleSearchCoverUrl?: string;
  ruleSearchLastChapter?: string;
  ruleFindList?: string;
  ruleFindName?: string;
  ruleFindAuthor?: string;
  ruleFindIntroduce?: string;
  ruleFindKind?: string;
  ruleFindNoteUrl?: string;
  ruleFindCoverUrl?: string;
  ruleFindLastChapter?: string;
  ruleBookInfoInit?: string;
  ruleBookName?: string;
  ruleBookAuthor?: string;
  ruleIntroduce?: string;
  ruleBookKind?: string;
  ruleCoverUrl?: string;
  ruleBookLastChapter?: string;
  ruleChapterUrl?: string;
  ruleChapterList?: string;
  ruleChapterName?: string;
  ruleContentUrl?: string;
  ruleChapterUrlNext?: string;
  ruleBookContent?: string;
  ruleBookContentReplace?: string;
  ruleContentUrlNext?: string;
}

/** 旧版替换规则一条的原始字段（上游 `ReplaceAnalyzer.jsonToReplaceRule` 的旧字段分支）。 */
interface RawOldReplaceRule {
  id?: number;
  regex?: string;
  replaceSummary?: string;
  replacement?: string;
  isRegex?: boolean;
  useTo?: string;
  enable?: boolean;
  serialNumber?: number;
}

/** 旧版书源解析结果；`skipped` 是被跳过的条数，供界面如实反馈。 */
export interface OldSourceParse {
  sources: BookSource[];
  skipped: number;
}

/** 旧版替换规则解析结果。 */
export interface OldReplaceRuleParse {
  rules: ReplaceRule[];
  skipped: number;
}

/** 一次旧数据导入的三类计数。 */
export interface OldDataImportOutcome {
  books: number;
  bookSkipped: number;
  sources: number;
  sourceSkipped: number;
  rules: number;
  ruleSkipped: number;
  /** 三份文件里一个都没找到时为 true。 */
  nothingFound: boolean;
}

const HEADER_PATTERN: RegExp = new RegExp('@Header:\\{.+?\\}', 'i');
const JS_PATTERN: RegExp = new RegExp('\\{\\{.+?\\}\\}', 'i');
/** 上游 `AppConst.kt:25 const val UA_NAME = "User-Agent"`。 */
const UA_HEADER_NAME: string = 'User-Agent';

export class OldDataImporter {
  /**
   * 旧字段 → 新字段（上游 `ImportOldData.kt:249-301 toNewRule`）。
   *
   * 三条改写：
   * - `#正则#替换` → `##正则##替换`（新版以 `##` 分隔）
   * - `|` → `||`（只改第一段，`##` 之后的部分不动）
   * - `&` → `&&`（含 `http` 或以 `/` 开头的不改，避免破坏 URL 与路径）
   *
   * 已经带新语法的规则（`@CSS:` / `@XPath:` / `//` / `##` / `:` / `@js:` / `<js>`）原样返回。
   * 前缀 `-`（反转）与 `+`（allinone）先剥下、改写完再拼回。
   *
   * 注意 `#` 那一步上游写的是 `oldRule.replace(...)` 而不是 `newRule`，会把刚剥下的
   * `-`/`+` 前缀一起带回来；这是上游既有行为，跨端要一致，照抄。
   */
  static toNewRule(oldRule?: string): string | undefined {
    if (oldRule === undefined || oldRule.trim().length === 0) { return undefined; }
    let newRule: string = oldRule;
    let reverse: boolean = false;
    let allinone: boolean = false;
    if (oldRule.startsWith('-')) {
      reverse = true;
      newRule = oldRule.substring(1);
    }
    if (newRule.startsWith('+')) {
      allinone = true;
      newRule = newRule.substring(1);
    }
    const lower = newRule.toLowerCase();
    if (!lower.startsWith('@css:') &&
      !lower.startsWith('@xpath:') &&
      !newRule.startsWith('//') &&
      !newRule.startsWith('##') &&
      !newRule.startsWith(':') &&
      !lower.includes('@js:') &&
      !lower.includes('<js>')) {
      if (newRule.includes('#') && !newRule.includes('##')) {
        newRule = OldDataImporter.replaceAll(oldRule, '#', '##');
      }
      if (newRule.includes('|') && !newRule.includes('||')) {
        if (newRule.includes('##')) {
          const list: string[] = newRule.split('##');
          const head = list[0] ?? '';
          if (head.includes('|')) {
            let rebuilt: string = OldDataImporter.replaceAll(head, '|', '||');
            for (let index = 1; index < list.length; index++) {
              rebuilt += `##${list[index] ?? ''}`;
            }
            newRule = rebuilt;
          }
        } else {
          newRule = OldDataImporter.replaceAll(newRule, '|', '||');
        }
      }
      if (newRule.includes('&') && !newRule.includes('&&') &&
        !newRule.includes('http') && !newRule.startsWith('/')) {
        newRule = OldDataImporter.replaceAll(newRule, '&', '&&');
      }
    }
    if (allinone) { newRule = `+${newRule}`; }
    if (reverse) { newRule = `-${newRule}`; }
    return newRule;
  }

  /**
   * 旧版「发现」URL 可能是多行或 `&&` 连接的多个地址（上游 `:303-315 toNewUrls`）。
   * js 形态（`@js:` / `<js>` 开头）原样返回；单个地址直接走 `toNewUrl`。
   */
  static toNewUrls(oldUrls?: string): string | undefined {
    if (oldUrls === undefined || oldUrls.trim().length === 0) { return undefined; }
    if (oldUrls.startsWith('@js:') || oldUrls.startsWith('<js>')) { return oldUrls; }
    if (!oldUrls.includes('\n') && !oldUrls.includes('&&')) {
      return OldDataImporter.toNewUrl(oldUrls);
    }
    const parts: string[] = oldUrls.split(new RegExp('(&&|\\r?\\n)+'));
    const mapped: string[] = [];
    for (let index = 0; index < parts.length; index++) {
      const piece = parts[index];
      if (piece === undefined) { continue; }
      const converted = OldDataImporter.toNewUrl(piece);
      if (converted === undefined) { continue; }
      mapped.push(OldDataImporter.replaceAll(converted, new RegExp('\\n\\s*', 'g'), ''));
    }
    return mapped.join('\n');
  }

  /**
   * 旧版搜索 URL → 新版（上游 `:317-362 toNewUrl`）。
   *
   * 依次拆出：`@Header:{...}` 内联头、`|` 后的字符集、`{{...}}` 内联 js、`@` 后的 POST body。
   * 拆完把 `{`/`}` 换成 `<>`（新版 URL 里 `<>` 是「可选」语法，旧版 `{}` 也是），
   * `searchKey` → `{{key}}`、`searchPage` → `{{page}}`（含 `+1`/`-1` 偏移）。
   * 拆出来的东西按新版的「URL,{json 选项}」拼回去。
   */
  static toNewUrl(oldUrl?: string): string | undefined {
    if (oldUrl === undefined || oldUrl.trim().length === 0) { return undefined; }
    let url: string = oldUrl;
    if (url.toLowerCase().startsWith('<js>')) {
      return OldDataImporter.replaceAll(
        OldDataImporter.replaceAll(url, '=searchKey', '={{key}}'), '=searchPage', '={{page}}');
    }
    const options: Record<string, string> = {};
    let optionCount: number = 0;
    const headerMatch = HEADER_PATTERN.exec(url);
    if (headerMatch !== null) {
      const header = headerMatch[0];
      url = OldDataImporter.replaceAll(url, header, '');
      options['headers'] = header.substring('@Header:'.length);
      optionCount += 1;
    }
    let segments: string[] = url.split('|');
    url = segments[0] ?? '';
    if (segments.length > 1) {
      const charsetPart = segments[1] ?? '';
      const equals = charsetPart.split('=');
      if (equals.length > 1) {
        options['charset'] = equals[1] ?? '';
        optionCount += 1;
      }
    }
    const jsList: string[] = [];
    let jsMatch = JS_PATTERN.exec(url);
    while (jsMatch !== null) {
      const matched = jsMatch[0];
      jsList.push(matched);
      url = OldDataImporter.replaceAll(url, matched, `$${jsList.length - 1}`);
      jsMatch = JS_PATTERN.exec(url);
    }
    url = OldDataImporter.replaceAll(OldDataImporter.replaceAll(url, '{', '<'), '}', '>');
    url = OldDataImporter.replaceAll(url, 'searchKey', '{{key}}');
    url = url.replace(new RegExp('<searchPage([-+]1)>', 'g'), '{{page$1}}');
    url = url.replace(new RegExp('searchPage([-+]1)', 'g'), '{{page$1}}');
    url = OldDataImporter.replaceAll(url, 'searchPage', '{{page}}');
    for (let index = 0; index < jsList.length; index++) {
      const item = jsList[index] ?? '';
      const restored = OldDataImporter.replaceAll(
        OldDataImporter.replaceAll(item, 'searchKey', 'key'), 'searchPage', 'page');
      url = OldDataImporter.replaceAll(url, `$${index}`, restored);
    }
    segments = url.split('@');
    url = segments[0] ?? '';
    if (segments.length > 1) {
      options['method'] = 'POST';
      options['body'] = segments[1] ?? '';
      optionCount += 2;
    }
    if (optionCount > 0) {
      url += `,${JSON.stringify(options)}`;
    }
    return url;
  }

  /** 旧版单独的 UA 字段 → 新版 header JSON（上游 `:364-368 uaToHeader`）。 */
  static uaToHeader(ua?: string): string | undefined {
    if (ua === undefined || ua.length === 0) { return undefined; }
    const map: Record<string, string> = {};
    map[UA_HEADER_NAME] = ua;
    return JSON.stringify(map);
  }

  /**
   * 解析 `myBookSource.json`（上游 `:162-242 fromOldBookSources`/`fromOldBookSource`）。
   *
   * 与上游一致：`bookSourceUrl` 缺失视为整份格式不对，直接抛错，不做「跳过这一条」——
   * 上游 `fromOldBookSource` 那里是 `?: throw NoStackTraceException(wrong_format)`，
   * 异常一路冒到 `importUri` 的 `runCatching`，整份导入失败。
   */
  static parseOldSources(text: string): OldSourceParse {
    const trimmed = text.trim();
    if (trimmed.length === 0) { return { sources: [], skipped: 0 }; }
    let items: RawOldSource[] = [];
    try {
      const parsed: RawOldSource[] = JSON.parse(trimmed) as RawOldSource[];
      if (!Array.isArray(parsed)) { return { sources: [], skipped: 1 }; }
      items = parsed;
    } catch (_) {
      return { sources: [], skipped: 1 };
    }
    const sources: BookSource[] = [];
    for (let index = 0; index < items.length; index++) {
      const item = items[index];
      if (item === undefined || item === null) { continue; }
      sources.push(OldDataImporter.fromOldSource(item));
    }
    return { sources: sources, skipped: 0 };
  }

  /** 单条旧书源 → 本地 `BookSource`（派生列 + 完整 sourceJson）。 */
  private static fromOldSource(raw: RawOldSource): BookSource {
    const url = typeof raw.bookSourceUrl === 'string' ? raw.bookSourceUrl.trim() : '';
    if (url.length === 0) {
      throw new Error('旧版书源缺少 bookSourceUrl，格式不对');
    }
    const name = typeof raw.bookSourceName === 'string' ? raw.bookSourceName : '';
    const group = typeof raw.bookSourceGroup === 'string' ? raw.bookSourceGroup : undefined;
    const isAudio = raw.bookSourceType === 'AUDIO';
    const enabled = raw.enable === undefined ? true : raw.enable === true;
    const exploreUrl = OldDataImporter.toNewUrls(raw.ruleFindUrl);
    const customOrder = Math.trunc(Number(raw.serialNumber ?? 0));
    const sourceType = isAudio ? 1 : 0;
    const header = OldDataImporter.uaToHeader(raw.httpUserAgent);
    const searchUrl = OldDataImporter.toNewUrl(raw.ruleSearchUrl);

    const obj: Record<string, Object> = {};
    obj['bookSourceUrl'] = url;
    obj['bookSourceName'] = name;
    if (group !== undefined) { obj['bookSourceGroup'] = group; }
    if (typeof raw.loginUrl === 'string') { obj['loginUrl'] = raw.loginUrl; }
    if (typeof raw.loginUi === 'string') { obj['loginUi'] = raw.loginUi; }
    if (typeof raw.loginCheckJs === 'string') { obj['loginCheckJs'] = raw.loginCheckJs; }
    if (typeof raw.coverDecodeJs === 'string') { obj['coverDecodeJs'] = raw.coverDecodeJs; }
    if (typeof raw.bookSourceComment === 'string') { obj['bookSourceComment'] = raw.bookSourceComment; }
    if (typeof raw.ruleBookUrlPattern === 'string') { obj['bookUrlPattern'] = raw.ruleBookUrlPattern; }
    obj['bookSourceType'] = sourceType;
    obj['customOrder'] = customOrder;
    obj['enabled'] = enabled;
    // 上游：发现地址为空时关掉「启用发现」（`:193-195`）。
    obj['enabledExplore'] = exploreUrl === undefined || exploreUrl.trim().length === 0 ? false : true;
    if (header !== undefined) { obj['header'] = header; }
    if (searchUrl !== undefined) { obj['searchUrl'] = searchUrl; }
    if (exploreUrl !== undefined) { obj['exploreUrl'] = exploreUrl; }

    const ruleSearch: Record<string, Object> = {};
    OldDataImporter.putRule(ruleSearch, 'bookList', OldDataImporter.toNewRule(raw.ruleSearchList));
    OldDataImporter.putRule(ruleSearch, 'name', OldDataImporter.toNewRule(raw.ruleSearchName));
    OldDataImporter.putRule(ruleSearch, 'author', OldDataImporter.toNewRule(raw.ruleSearchAuthor));
    OldDataImporter.putRule(ruleSearch, 'intro', OldDataImporter.toNewRule(raw.ruleSearchIntroduce));
    OldDataImporter.putRule(ruleSearch, 'kind', OldDataImporter.toNewRule(raw.ruleSearchKind));
    OldDataImporter.putRule(ruleSearch, 'bookUrl', OldDataImporter.toNewRule(raw.ruleSearchNoteUrl));
    OldDataImporter.putRule(ruleSearch, 'coverUrl', OldDataImporter.toNewRule(raw.ruleSearchCoverUrl));
    OldDataImporter.putRule(ruleSearch, 'lastChapter', OldDataImporter.toNewRule(raw.ruleSearchLastChapter));
    obj['ruleSearch'] = ruleSearch;

    const ruleExplore: Record<string, Object> = {};
    OldDataImporter.putRule(ruleExplore, 'bookList', OldDataImporter.toNewRule(raw.ruleFindList));
    OldDataImporter.putRule(ruleExplore, 'name', OldDataImporter.toNewRule(raw.ruleFindName));
    OldDataImporter.putRule(ruleExplore, 'author', OldDataImporter.toNewRule(raw.ruleFindAuthor));
    OldDataImporter.putRule(ruleExplore, 'intro', OldDataImporter.toNewRule(raw.ruleFindIntroduce));
    OldDataImporter.putRule(ruleExplore, 'kind', OldDataImporter.toNewRule(raw.ruleFindKind));
    OldDataImporter.putRule(ruleExplore, 'bookUrl', OldDataImporter.toNewRule(raw.ruleFindNoteUrl));
    OldDataImporter.putRule(ruleExplore, 'coverUrl', OldDataImporter.toNewRule(raw.ruleFindCoverUrl));
    OldDataImporter.putRule(ruleExplore, 'lastChapter', OldDataImporter.toNewRule(raw.ruleFindLastChapter));
    obj['ruleExplore'] = ruleExplore;

    const ruleBookInfo: Record<string, Object> = {};
    OldDataImporter.putRule(ruleBookInfo, 'init', OldDataImporter.toNewRule(raw.ruleBookInfoInit));
    OldDataImporter.putRule(ruleBookInfo, 'name', OldDataImporter.toNewRule(raw.ruleBookName));
    OldDataImporter.putRule(ruleBookInfo, 'author', OldDataImporter.toNewRule(raw.ruleBookAuthor));
    OldDataImporter.putRule(ruleBookInfo, 'intro', OldDataImporter.toNewRule(raw.ruleIntroduce));
    OldDataImporter.putRule(ruleBookInfo, 'kind', OldDataImporter.toNewRule(raw.ruleBookKind));
    OldDataImporter.putRule(ruleBookInfo, 'coverUrl', OldDataImporter.toNewRule(raw.ruleCoverUrl));
    OldDataImporter.putRule(ruleBookInfo, 'lastChapter', OldDataImporter.toNewRule(raw.ruleBookLastChapter));
    OldDataImporter.putRule(ruleBookInfo, 'tocUrl', OldDataImporter.toNewRule(raw.ruleChapterUrl));
    obj['ruleBookInfo'] = ruleBookInfo;

    const ruleToc: Record<string, Object> = {};
    OldDataImporter.putRule(ruleToc, 'chapterList', OldDataImporter.toNewRule(raw.ruleChapterList));
    OldDataImporter.putRule(ruleToc, 'chapterName', OldDataImporter.toNewRule(raw.ruleChapterName));
    OldDataImporter.putRule(ruleToc, 'chapterUrl', OldDataImporter.toNewRule(raw.ruleContentUrl));
    OldDataImporter.putRule(ruleToc, 'nextTocUrl', OldDataImporter.toNewRule(raw.ruleChapterUrlNext));
    obj['ruleToc'] = ruleToc;

    // 上游 `:232-240`：正文规则若以 `$` 开头但不到 `$.`，去掉这个 `$`
    // （旧版 JSONPath 与新版 `@json:` 语法的历史差异）。
    let content: string = OldDataImporter.toNewRule(raw.ruleBookContent) ?? '';
    if (content.startsWith('$') && !content.startsWith('$.')) {
      content = content.substring(1);
    }
    const ruleContent: Record<string, Object> = {};
    ruleContent['content'] = content;
    OldDataImporter.putRule(ruleContent, 'replaceRegex', OldDataImporter.toNewRule(raw.ruleBookContentReplace));
    OldDataImporter.putRule(ruleContent, 'nextContentUrl', OldDataImporter.toNewRule(raw.ruleContentUrlNext));
    obj['ruleContent'] = ruleContent;

    return {
      bookSourceUrl: url,
      bookSourceName: name,
      bookSourceGroup: group,
      bookSourceType: sourceType,
      enabled: enabled,
      customOrder: customOrder,
      sourceJson: JSON.stringify(obj)
    };
  }

  /**
   * 解析 `myBookReplaceRule.json`（上游 `ImportOldData.kt:112-119` 走
   * `ReplaceAnalyzer.jsonToReplaceRules`，单条再由 `jsonToReplaceRule` 的旧字段分支转换）。
   *
   * 旧字段：`regex`（正则）、`replaceSummary`（名称）、`replacement`（替换内容）、
   * `isRegex`、`useTo`（作用域）、`enable`、`serialNumber`、`id`。
   * 新版字段是 `pattern`/`name`/`replacement`/`isRegex`/`scope`/`isEnabled`/`order`。
   */
  static parseOldReplaceRules(text: string): OldReplaceRuleParse {
    const trimmed = text.trim();
    if (trimmed.length === 0) { return { rules: [], skipped: 0 }; }
    let items: RawOldReplaceRule[] = [];
    try {
      const parsed: RawOldReplaceRule[] = JSON.parse(trimmed) as RawOldReplaceRule[];
      if (!Array.isArray(parsed)) { return { rules: [], skipped: 1 }; }
      items = parsed;
    } catch (_) {
      return { rules: [], skipped: 1 };
    }
    const rules: ReplaceRule[] = [];
    let skipped: number = 0;
    for (let index = 0; index < items.length; index++) {
      const item = items[index];
      if (item === undefined || item === null) { skipped += 1; continue; }
      const rule = OldDataImporter.fromOldReplaceRule(item, rules.length);
      if (rule === undefined) { skipped += 1; } else { rules.push(rule); }
    }
    return { rules: rules, skipped: skipped };
  }

  /** 单条旧替换规则 → 本地 `ReplaceRule`；`regex` 为空视为格式不对（上游抛 `格式不对`）。 */
  private static fromOldReplaceRule(raw: RawOldReplaceRule, fallbackOrder: number): ReplaceRule | undefined {
    const pattern = typeof raw.regex === 'string' ? raw.regex : '';
    if (pattern.length === 0) { return undefined; }
    const scope = typeof raw.useTo === 'string' ? raw.useTo : '';
    const id = raw.id === undefined ? Date.now() + fallbackOrder : Math.trunc(Number(raw.id));
    return {
      id: id,
      name: typeof raw.replaceSummary === 'string' ? raw.replaceSummary : '',
      group: '',
      pattern: pattern,
      replacement: typeof raw.replacement === 'string' ? raw.replacement : '',
      scope: scope,
      // 旧版 `useTo` 是逗号分隔的作用域串，与新版 scope 语义相同；标题/正文两个布尔由它派生。
      scopeTitle: scope.includes('title'),
      scopeContent: scope.includes('content'),
      excludeScope: '',
      isEnabled: raw.enable === true,
      isRegex: raw.isRegex === true,
      timeoutMillisecond: 0,
      order: raw.serialNumber === undefined ? fallbackOrder : Math.trunc(Number(raw.serialNumber))
    };
  }

  /** 只在值非空时写入，保持与上游 GSON 省略 null 的 JSON 形状一致。 */
  private static putRule(target: Record<string, Object>, key: string, value?: string): void {
    if (value === undefined || value.length === 0) { return; }
    target[key] = value;
  }

  /** JS 的 `String.replace(string, string)` 只替换第一处，这里要全替换（对齐 Kotlin 的 `replace`）。 */
  private static replaceAll(source: string, from: string | RegExp, to: string): string {
    if (typeof from === 'string') {
      return source.split(from).join(to);
    }
    return source.replace(from, to);
  }
}
