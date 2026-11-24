// 发现分类解析器（P7）：把 exploreUrl 的四种写法解析成统一菜单结构。
// 对齐上游 BookSourceExtensions.kt:52-103 的 exploreKinds()：
//   1. 单 URL                 -> 一条菜单（title 即 URL，UI 单条时以源名呈现）
//   2. 多 URL（换行/&& 分隔）  -> 每行一条
//   3. 分类名::url            -> title=分类名，url=地址
//   4. JSON 数组              -> [{title,url}, ...]
//   @js:/<js> 动态分类求值后再按上面规则解析。
//
// 【整体 @js: 求值必须用受控运行时】上游 exploreKinds() 对整体 @js:/<js> 的 exploreUrl
// 走 `evalJS`，脚本里常用 java.ajax / source.getVariable（如番茄源）。本地纯值的 JsRuntime
// 不支持这些主机能力，求值会原样吐回 JS 源码，被当成伪分类 chip（上机实测）。
// 因此新增 parseWithSource()：走 BookSourceStageWebRuntime（与分类 action/viewName 同一运行时），
// 求值结果再交给 parseRules()。同步 parse() 保留给无需主机能力的场景，求值仍用 JsRuntime。
import {
  BookSource as EngineBookSource,
  BookSourceScriptRunner,
  BookSourceStageWebRuntime,
  JsRuntime,
  StageWebRuntimeRequest,
  SourceRuntimeStage
} from '@legado/sourceengine';

export interface ExploreMenu {
  title: string;
  url: string;
}

export interface ExploreConfig {
  menus: ExploreMenu[];
}

export class ExploreMenuParser {
  /** 同步解析 exploreUrl；整体 @js: 只用纯值 JsRuntime 求值（无主机能力）。 */
  static parse(exploreUrl: string): ExploreConfig {
    const config: ExploreConfig = { menus: [] };
    let ruleStr = exploreUrl === undefined ? '' : exploreUrl.trim();
    if (ruleStr.length === 0) { return config; }

    if (ruleStr.startsWith('@js:') || ruleStr.toLowerCase().startsWith('<js>')) {
      const jsStr = ExploreMenuParser.unwrapJs(ruleStr);
      try {
        const js = new JsRuntime();
        ruleStr = js.evaluate(jsStr.trim()).trim();
      } catch (e) {
        config.menus.push({
          title: 'ERROR:' + (e instanceof Error ? e.message : String(e)),
          url: ''
        });
        return config;
      }
    }
    return ExploreMenuParser.parseRules(ruleStr);
  }

  /**
   * 异步解析某书源的 exploreUrl：整体 @js:/<js> 走受控运行时（支持 java.ajax / source.getVariable）。
   * 对齐上游 exploreKinds() 的 evalJS + aCache 缓存语义中最关键的一步——真能把脚本跑出结果。
   */
  static async parseWithSource(source: EngineBookSource): Promise<ExploreConfig> {
    const config: ExploreConfig = { menus: [] };
    let ruleStr = (source.exploreUrl === undefined ? '' : source.exploreUrl).trim();
    if (ruleStr.length === 0) { return config; }

    if (ruleStr.startsWith('@js:') || ruleStr.toLowerCase().startsWith('<js>')) {
      const jsStr = ExploreMenuParser.unwrapJs(ruleStr);
      const req = new StageWebRuntimeRequest();
      req.source = source;
      req.code = jsStr.trim();
      req.stage = SourceRuntimeStage.EXPLORE;
      req.baseUrl = BookSourceScriptRunner.selectedBaseUrl(source);
      req.ownerId = 'explore-menu:' + source.bookSourceUrl;
      try {
        const runtime = BookSourceStageWebRuntime.get();
        if (!runtime.isAvailable() && !await runtime.waitUntilAvailable(1500)) {
          config.menus.push({ title: 'ERROR:书源脚本运行环境未就绪', url: '' });
          return config;
        }
        const result = await runtime.execute(req);
        if ((result.errorMessage || '').length > 0) {
          config.menus.push({ title: 'ERROR:' + result.errorMessage, url: '' });
          return config;
        }
        ruleStr = (result.value || '').trim();
      } catch (e) {
        config.menus.push({
          title: 'ERROR:' + (e instanceof Error ? e.message : String(e)),
          url: ''
        });
        return config;
      }
      if (ruleStr.length === 0) { return config; }
    }
    return ExploreMenuParser.parseRules(ruleStr);
  }

  /** 把 @js:/<js> 外壳剥成裸 JS。 */
  private static unwrapJs(ruleStr: string): string {
    if (ruleStr.startsWith('@')) {
      return ruleStr.substring(4);
    }
    const end = ruleStr.toLowerCase().lastIndexOf('</js>');
    return end > 4 ? ruleStr.substring(4, end) : ruleStr.substring(4);
  }

  /** 把（已求值的）规则串解析成菜单：JSON 数组 / 换行或 && 分段 / :: 切分。 */
  private static parseRules(ruleStr: string): ExploreConfig {
    const config: ExploreConfig = { menus: [] };
    if (ruleStr.length === 0) { return config; }

    // JSON 数组：上游 GSON.fromJsonArray<ExploreKind>。只取 title/url 两字段。
    if (ruleStr.startsWith('[')) {
      try {
        const arr = JSON.parse(ruleStr) as Object[];
        for (const raw of arr) {
          const item = raw as Record<string, Object>;
          const title = ExploreMenuParser.asText(item['title']);
          const url = ExploreMenuParser.asText(item['url']);
          if (title.length === 0 && url.length === 0) { continue; }
          config.menus.push({ title: title.length > 0 ? title : url, url: url });
        }
        return config;
      } catch (_) {
        // 不是合法 JSON 数组则按文本规则再试一次。
      }
    }

    // 文本规则：按 && 或换行切段，每段按 :: 切出「分类名/地址」。
    // 无 :: 时上游 ExploreKind(title=整串, url=null)，展示时以整串作目标；这里等价填 url=整串。
    // 正则用非捕获组，避免 split 把分隔符 && 本身也当成一段（对齐上游 Kotlin 无捕获组行为）。
    const parts = ruleStr.split(/(?:&&|\n)+/u);
    for (const part of parts) {
      const seg = part.trim();
      if (seg.length === 0) { continue; }
      const kv = seg.split('::');
      const title = kv[0].trim();
      const url = kv.length > 1 ? kv.slice(1).join('::').trim() : title;
      if (url.length === 0) { continue; }
      config.menus.push({ title: title, url: url });
    }
    return config;
  }

  private static asText(value: Object | undefined): string {
    if (value === undefined || value === null) { return ''; }
    return typeof value === 'string' ? value as string : String(value);
  }
}
