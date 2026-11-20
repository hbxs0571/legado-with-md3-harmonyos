// 发现分类解析器（P7）：把 exploreUrl 的四种写法解析成统一菜单结构。
// 对齐上游 BookSourceExtensions.kt:52-103 的 exploreKinds()：
//   1. 单 URL                 -> 一条菜单（title 即 URL，UI 单条时以源名呈现）
//   2. 多 URL（换行/&& 分隔）  -> 每行一条
//   3. 分类名::url            -> title=分类名，url=地址
//   4. JSON 数组              -> [{title,url}, ...]
//   @js:/<js> 动态分类尝试用引擎 JsRuntime 求值后再按上面规则解析。
import { JsRuntime } from '@legado/sourceengine';

export interface ExploreMenu {
  title: string;
  url: string;
}

export interface ExploreConfig {
  menus: ExploreMenu[];
}

export class ExploreMenuParser {
  /** 解析 exploreUrl；空输入返回空菜单。 */
  static parse(exploreUrl: string): ExploreConfig {
    const config: ExploreConfig = { menus: [] };
    let ruleStr = exploreUrl === undefined ? '' : exploreUrl.trim();
    if (ruleStr.length === 0) { return config; }

    // 动态分类：上游 evalJS 后缓存结果。本地求值失败时返回 ERROR 菜单，如实反馈。
    if (ruleStr.startsWith('@js:') || ruleStr.toLowerCase().startsWith('<js>')) {
      let jsStr = '';
      if (ruleStr.startsWith('@')) {
        jsStr = ruleStr.substring(4);
      } else {
        const end = ruleStr.toLowerCase().lastIndexOf('</js>');
        jsStr = end > 4 ? ruleStr.substring(4, end) : ruleStr.substring(4);
      }
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
      if (ruleStr.length === 0) { return config; }
    }

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
