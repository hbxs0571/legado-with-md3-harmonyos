// 单源网页服务（P2）：searchBook / getBookInfo / getChapterList / getContent 四步。
// 对应上游 model/webBook/WebBook.kt（510 行）。链路范式来自 P0-ter 探针（已上机验证）。
import {
  AnalyzeRule, AnalyzeUrl, BookSource, BookSourceScriptRunner, BookUrlResolver, HttpResponse
} from '@legado/sourceengine';
import { AppLog } from '../lib/AppLog';
import { SourceHttp } from './SourceHttp';
import { RemoteBookDetail, RemoteChapter, SearchBookItem } from './SourceModels';

/** fetch 的返回载体（ArkTS 不允许匿名对象字面量作类型）。 */
interface FetchResult {
  resp: HttpResponse;
  base: string;
}

export class WebBookService {
  /** 发起一个请求并返回响应 + 有效 baseUrl；失败时抛带可读原因的 Error。 */
  private static async fetch(
    source: BookSource, urlTemplate: string, keyword: string, page: number
  ): Promise<FetchResult> {
    const resolved = SourceHttp.evalTemplate(urlTemplate, keyword, page);
    const au = SourceHttp.newAnalyzer(source);
    // 【@js: URL 规则求值】探索分类 URL 常是「@js:...」脚本（读 page/key 拼地址），
    // 引擎 AnalyzeUrl.fetch 会在 parse 前于受控运行时求值；这里把 page/key 传进去（对齐上游 bindings）。
    au.setUrlContext(keyword, page);
    const resp = await au.fetch(resolved);
    if (!resp.success || resp.statusCode === 0 || !resp.body) {
      const reason = `HTTP ${resp.statusCode} ${resp.error || ''}`.trim();
      throw new Error(reason);
    }
    const base = BookUrlResolver.effectiveBase(resp, resolved, source.bookSourceUrl);
    const result: FetchResult = { resp: resp, base: base };
    return result;
  }

  /** 给规则引擎挂公共上下文（key/page）。 */
  private static newRule(body: string, base: string, keyword: string, page: number): AnalyzeRule {
    const rule = new AnalyzeRule(body, base);
    rule.setJsVar('key', keyword);
    rule.setJsVar('page', String(page));
    rule.getContext().put('key', keyword);
    rule.getContext().put('page', String(page));
    return rule;
  }

  /** 第一步：搜索。取 searchUrl → getElements(bookList) → 逐字段 getString。 */
  static async searchBook(
    source: BookSource, keyword: string, page: number
  ): Promise<SearchBookItem[]> {
    const sr = source.searchRule;
    if (!source.searchUrl || !sr.bookList) {
      throw new Error('源缺少 searchUrl 或 ruleSearch.bookList');
    }
    const fetched = await WebBookService.fetch(source, source.searchUrl, keyword, page);
    const resp = fetched.resp;
    const base = fetched.base;
    const rule = WebBookService.newRule(resp.body, base, keyword, page);
    const elements = rule.getElements(sr.bookList);
    if (elements.length === 0) return [];
    // 防止整页被当成一条（规则写错时常见）：单条且几乎等于整页视为规则失败。
    if (elements.length === 1 && resp.body.length > 1000 && elements[0].length >= resp.body.length * 0.9) {
      throw new Error('getElements 把整页当结果');
    }
    const items: SearchBookItem[] = [];
    for (const element of elements) {
      const er = WebBookService.newRule(element, base, keyword, page);
      const item: SearchBookItem = {
        bookUrl: er.getString(sr.bookUrl, true),
        origin: source.bookSourceUrl,
        originName: source.bookSourceName,
        name: er.getString(sr.name),
        author: er.getString(sr.author),
        kind: er.getString(sr.kind),
        coverUrl: er.getString(sr.coverUrl, true),
        intro: er.getString(sr.intro),
        lastChapter: er.getString(sr.lastChapter),
        wordCount: er.getString(sr.wordCount),
        updateTime: er.getString(sr.updateTime),
        tocUrl: ''
      };
      item.bookUrl = BookUrlResolver.resolve(item.bookUrl, base);
      if (item.coverUrl) item.coverUrl = BookUrlResolver.resolve(item.coverUrl, base);
      items.push(item);
    }
    return items;
  }

  /**
   * 发现：取分类 URL → 用 exploreRule 解析书列表（对齐上游 WebBook.exploreBookAwait）。
   * 与 searchBook 规则同形，只是规则取自 exploreRule、无关键词；分页由 {{page}} 承担。
   */
  static async exploreBook(
    source: BookSource, urlTemplate: string, page: number
  ): Promise<SearchBookItem[]> {
    const er = source.exploreRule;
    if (!er.bookList) {
      throw new Error('源缺少 ruleExplore.bookList');
    }
    const fetched = await WebBookService.fetch(source, urlTemplate, '', page);
    const resp = fetched.resp;
    const base = fetched.base;
    const rule = WebBookService.newRule(resp.body, base, '', page);
    const elements = rule.getElements(er.bookList);
    if (elements.length === 0) return [];
    if (elements.length === 1 && resp.body.length > 1000 && elements[0].length >= resp.body.length * 0.9) {
      throw new Error('getElements 把整页当结果');
    }
    const items: SearchBookItem[] = [];
    for (const element of elements) {
      const ir = WebBookService.newRule(element, base, '', page);
      const item: SearchBookItem = {
        bookUrl: ir.getString(er.bookUrl, true),
        origin: source.bookSourceUrl,
        originName: source.bookSourceName,
        name: ir.getString(er.name),
        author: ir.getString(er.author),
        kind: ir.getString(er.kind),
        coverUrl: ir.getString(er.coverUrl, true),
        intro: ir.getString(er.intro),
        lastChapter: ir.getString(er.lastChapter),
        wordCount: ir.getString(er.wordCount),
        updateTime: ir.getString(er.updateTime),
        tocUrl: ''
      };
      item.bookUrl = BookUrlResolver.resolve(item.bookUrl, base);
      if (item.coverUrl) item.coverUrl = BookUrlResolver.resolve(item.coverUrl, base);
      items.push(item);
    }
    return items;
  }

  /**
   * 取网页文件的下载直链（对应上游 `BookInfo.kt:171` 的
   * `analyzeRule.getStringList(infoRule.downloadUrls, isUrl = true)`）。
   *
   * 引擎的 `BookInfoRule` 没有 downloadUrls 字段（`Book.ts:429-441`），
   * 所以这里直接从书源原始 JSON 里读规则串，再交给 AnalyzeRule 求值——
   * 规则语法（含 `@js:`）与其它字段完全一致，无需改引擎。
   */
  private static downloadUrlsOf(source: BookSource, rule: AnalyzeRule, base: string): string[] {
    const pattern = WebBookService.bookInfoDownloadUrlRule(source);
    if (pattern.length === 0) { return []; }
    const urls: string[] = [];
    try {
      const values = rule.getStringList(pattern);
      for (let index = 0; index < values.length; index++) {
        const one = values[index];
        if (one === undefined || one.length === 0) { continue; }
        urls.push(BookUrlResolver.resolve(one, base));
      }
    } catch (_) {
      return [];
    }
    return urls;
  }

  /** 从书源原始 JSON 里取 `ruleBookInfo.downloadUrls` 规则串。 */
  private static bookInfoDownloadUrlRule(source: BookSource): string {
    const raw = source.rawSourceJson;
    if (raw === undefined || raw.length === 0) { return ''; }
    try {
      const parsed = JSON.parse(raw) as Record<string, Object>;
      const ruleBookInfo = parsed['ruleBookInfo'];
      if (ruleBookInfo === null || ruleBookInfo === undefined || typeof ruleBookInfo !== 'object') {
        return '';
      }
      const value = (ruleBookInfo as Record<string, Object>)['downloadUrls'];
      return typeof value === 'string' ? value : '';
    } catch (_) {
      return '';
    }
  }

  /** 第二步：详情。取详情页 → 跑 init → 逐字段取值。 */
  static async getBookInfo(source: BookSource, bookUrl: string): Promise<RemoteBookDetail> {
    const ir = source.bookInfoRule;
    const fetched = await WebBookService.fetch(source, bookUrl, '', 1);
    const resp = fetched.resp;
    const base = fetched.base;
    // init 规则可能触发额外请求/赋值；引擎在 AnalyzeRule 内按 @js: 处理，这里先求值再取字段。
    const initRule = WebBookService.newRule(resp.body, base, '', 1);
    if (ir.init) {
      try { initRule.getString(ir.init); } catch (_) { /* init 失败不阻断其余字段 */ }
    }
    const r = WebBookService.newRule(resp.body, base, '', 1);
    const detail: RemoteBookDetail = {
      bookUrl: bookUrl,
      origin: source.bookSourceUrl,
      originName: source.bookSourceName,
      name: r.getString(ir.name),
      author: r.getString(ir.author),
      kind: r.getString(ir.kind),
      coverUrl: r.getString(ir.coverUrl, true),
      intro: r.getString(ir.intro),
      lastChapter: r.getString(ir.lastChapter),
      wordCount: r.getString(ir.wordCount),
      updateTime: r.getString(ir.updateTime),
      tocUrl: r.getString(ir.tocUrl, true),
      downloadUrls: WebBookService.downloadUrlsOf(source, r, base)
    };
    if (detail.coverUrl) detail.coverUrl = BookUrlResolver.resolve(detail.coverUrl, base);
    // 上游口径：tocUrl 为空时用 bookUrl 本身当目录地址。
    detail.tocUrl = detail.tocUrl
      ? BookUrlResolver.resolve(detail.tocUrl, base)
      : bookUrl;
    return detail;
  }

  /** 第三步：目录。取目录页 → getElements(chapterList) → 逐条取名/链接，处理 nextTocUrl 翻页。 */
  static async getChapterList(
    source: BookSource, tocUrl: string, maxPages: number = 20, runPerJs: boolean = false
  ): Promise<RemoteChapter[]> {
    const tr = source.tocRule;
    if (!tr.chapterList) throw new Error('源缺少 ruleToc.chapterList');
    // 批3（r359）：对齐上游 WebBook.kt:303-330 —— 取目录前可先跑一次源书写的 JS
    // （常见用途是刷新登录态/签名变量）。失败只记日志，不中断取目录。
    // 注意上游 getChapterListAwait(bookSource, book, runPerJs = false) 默认**不跑**，
    // 只有调用方主动传 true 才跑（BookInfoViewModel.kt:1359 那一路），
    // 刷新目录用例自己先跑 preUpdateJs 再调本方法，所以这里必须门控，否则会双跑。
    if (runPerJs && tr.preUpdateJs && tr.preUpdateJs.length > 0) {
      try {
        BookSourceScriptRunner.runRawScript(source, tr.preUpdateJs);
      } catch (e) {
        AppLog.put(`执行preUpdateJs规则失败 书源:${source.bookSourceUrl} ${e instanceof Error ? e.message : String(e)}`);
      }
    }
    const chapters: RemoteChapter[] = [];
    let currentUrl = tocUrl;
    let page = 0;
    while (currentUrl && page < maxPages) {
      const fetched = await WebBookService.fetch(source, currentUrl, '', 1);
      const resp = fetched.resp;
      const base = fetched.base;
      const rule = WebBookService.newRule(resp.body, base, '', 1);
      const elements = rule.getElements(tr.chapterList);
      for (const element of elements) {
        const er = WebBookService.newRule(element, base, '', 1);
        const rawTitle = er.getString(tr.chapterName);
        const url = BookUrlResolver.resolve(er.getString(tr.chapterUrl, true), base);
        // 批3（r359）：卷标题判定（上游 BookChapterList.kt:231-243）。
        // 规则为空时 false；求值结果按上游 String.isTrue() 口径判真假（空串/「null」/false/no/0 为假）。
        let isVolume = false;
        if (tr.isVolume && tr.isVolume.length > 0) {
          try {
            isVolume = WebBookService.ruleIsTrue(er.getString(tr.isVolume));
          } catch (e) {
            isVolume = false;
          }
        }
        // 批3（r359）：逐章格式化标题（上游 BookChapterList.kt:150-160 formatJs）。
        // 环境注入 index（从 1 起）、chapter（本章 url）、title（原标题），失败保留原标题。
        let title = rawTitle;
        if (tr.formatJs && tr.formatJs.length > 0) {
          try {
            const bindings: Record<string, string> = {
              'index': String(chapters.length + 1),
              'chapter': url,
              'title': rawTitle
            };
            const formatted = BookSourceScriptRunner.runRawScript(source, tr.formatJs, bindings);
            if (formatted.length > 0) { title = formatted; }
          } catch (e) {
            AppLog.put(`格式化标题出错 书源:${source.bookSourceUrl} ${e instanceof Error ? e.message : String(e)}`);
          }
        }
        chapters.push({
          url: url,
          title: title,
          isVip: Boolean(er.getString(tr.isVip)),
          isPay: Boolean(er.getString(tr.isPay)),
          isVolume: isVolume
        });
      }
      page += 1;
      if (!tr.nextTocUrl) break;
      const nextRule = WebBookService.newRule(resp.body, base, '', page + 1);
      let next = '';
      try { next = nextRule.getString(tr.nextTocUrl, true); } catch (_) { break; }
      if (!next) break;
      currentUrl = BookUrlResolver.resolve(next, base);
      if (chapters.length > 5000) break; // 防御：坏规则导致无限翻页
    }
    return chapters;
  }

  /**
   * 批3（r359）：按上游 `String.isTrue()`（utils/StringExtensions.kt:75-81）判定规则求值结果的真假。
   * 空串与「null」为假；其余只要不是 false/no/not/0/0.0（不区分大小写）就是真。
   */
  private static ruleIsTrue(value: string): boolean {
    const text = value.trim();
    if (text.length === 0 || text === 'null') { return false; }
    return !/^(?:false|no|not|0|0\.0)$/i.test(text);
  }

  /**
   * 第四步：正文。取章节页 → getStringList(content) → 拼接。
   * replaceRegex 由 AnalyzeRule.getStringList 内的 ## 处理器承担，无需再做一遍。
   * 任务书 6.4 坑 3：ruleContent.webJs / subContent 引擎没有，有这些字段的源返回部分结果。
   */
  static async getContent(source: BookSource, chapterUrl: string): Promise<string> {
    const cr = source.contentRule;
    if (!cr.content) throw new Error('源缺少 ruleContent.content');
    const fetched = await WebBookService.fetch(source, chapterUrl, '', 1);
    const resp = fetched.resp;
    const base = fetched.base;
    const rule = WebBookService.newRule(resp.body, base, '', 1);
    const parts = rule.getStringList(cr.content);
    return parts.join('\n').trim();
  }
}
