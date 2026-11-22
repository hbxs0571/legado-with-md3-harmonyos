// 单源 HTTP 封装（P2）：HttpClient 单例 + AnalyzeUrl 工厂 + {{key}}/{{page}} 模板替换。
//
// 坑 1（任务书 6.4）：引擎 AnalyzeUrl 里 {{key}}/{{page}} 零命中，模板替换在 JsRuntime.evalTemplate。
// 但 evalTemplate 会对 {{...}} 里的表达式求值（如 {{key}} → 变量值），我们这里只需要替换
// 几个已知变量。对纯 {{key}}/{{page}} 用直接字符串替换，避免 eval 带来的脚本依赖。
// 复杂的 {{java.*}} 等表达式交给 AnalyzeUrl.parse 内的引擎逻辑处理。
import { AnalyzeUrl, HttpClient, JsRuntime } from '@legado/sourceengine';
import { BookSource } from '@legado/sourceengine';

export class SourceHttp {
  private static client: HttpClient | null = null;
  /** 全局取消标记：一次搜索的取消对它在途的所有源请求生效。 */
  private static cancelCheck: () => boolean = () => false;
  /**
   * 按书源登记的取消钩子：校验一类的场景里每路源各有自己的超时闸门，
   * 全局 cancelCheck 只能表达「全体取消」，表达不了「这一路超时了」。
   * key 是 bookSourceUrl，值是该源当前请求的取消判定。
   */
  private static sourceChecks: Map<string, () => boolean> = new Map<string, () => boolean>();

  /** 全局单例客户端：复用连接池与 cookie 会话，避免每条源 new 一个。 */
  static getClient(): HttpClient {
    if (SourceHttp.client === null) {
      SourceHttp.client = new HttpClient(15000);
    }
    return SourceHttp.client;
  }

  /** 搜索开始时挂取消钩子（对齐任务书 7.2 的 AnalyzeUrl.setCancelCheck）。 */
  static setCancelCheck(check: () => boolean): void {
    SourceHttp.cancelCheck = check;
  }

  /** 搜索结束时清掉钩子，避免影响后续单源请求。 */
  static clearCancelCheck(): void {
    SourceHttp.cancelCheck = () => false;
  }

  /**
   * 给单个书源挂取消钩子（校验超时用）：命中后该源在途的 HTTP 传输会被掐断，
   * 对齐上游 BookSourceCheckRepository.kt:116 `withTimeout(...)` 的取消语义。
   */
  static setSourceCancelCheck(sourceUrl: string, check: () => boolean): void {
    SourceHttp.sourceChecks.set(sourceUrl, check);
  }

  /** 撤销单源钩子；必须在请求收尾时调用，否则下次同源请求会带着过期闸门。 */
  static clearSourceCancelCheck(sourceUrl: string): void {
    SourceHttp.sourceChecks.delete(sourceUrl);
  }

  /** 合并全局取消与单源取消；没有单源钩子时直接用全局那个，避免每次多一层闭包。 */
  private static mergedCancelCheck(source: BookSource): () => boolean {
    const sourceCheck = SourceHttp.sourceChecks.get(source.bookSourceUrl);
    if (sourceCheck === undefined) {
      return SourceHttp.cancelCheck;
    }
    return (): boolean => SourceHttp.cancelCheck() || sourceCheck();
  }

  /** 建一个绑定书源的 AnalyzeUrl，带限流与取消钩子。 */
  static newAnalyzer(source: BookSource, timeoutMs: number = 15000): AnalyzeUrl {
    const au = new AnalyzeUrl(source, SourceHttp.getClient());
    au.setRequestTimeout(timeoutMs);
    au.setCancelCheck(SourceHttp.mergedCancelCheck(source));
    return au;
  }

  /**
   * 替换 URL 模板里的 {{key}} / {{searchKey}} / {{keyword}} / {{page}}。
   * 只替换这几个纯变量，其余 {{...}} 表达式原样留给引擎。
   */
  static substituteVariables(template: string, keyword: string, page: number): string {
    let out = template;
    out = out.replace(/\{\{\s*key\s*\}\}/gi, keyword);
    out = out.replace(/\{\{\s*searchKey\s*\}\}/gi, keyword);
    out = out.replace(/\{\{\s*keyword\s*\}\}/gi, keyword);
    out = out.replace(/\{\{\s*page\s*\}\}/gi, String(page));
    return out;
  }

  /** 用 JsRuntime 求值剩余模板（如 {{key}} 之外的简单表达式），失败时返回原文。 */
  static evalTemplate(template: string, keyword: string, page: number): string {
    const js = new JsRuntime();
    js.setVar('key', keyword);
    js.setVar('searchKey', keyword);
    js.setVar('keyword', keyword);
    js.setVar('page', String(page));
    js.setVar('pageIndex', String(page - 1));
    try {
      return js.evalTemplate(template);
    } catch (_) {
      return SourceHttp.substituteVariables(template, keyword, page);
    }
  }
}
