// Legado → 引擎书源模型映射层（P1）。
//
// 引擎不提供这一层：`NativeSourceSpec.fromObject` 会抛「不是原生书源：缺少 sourceFormat: native」，
// 而 ruleSearch/ruleExplore/ruleBookInfo/ruleToc/ruleContent/ruleReview 六个 Legado 键名在引擎里 0 命中。
// 本文件按任务书 5.2/5.3 的对照表逐字段投影。
//
// 四条硬约束：
// 1. sourceJson 字符串是唯一真值，映射是只读投影，绝不回写（备份必须保持 Legado 原格式）。
// 2. 引擎没有的字段（checkKeyWord / canReName / subContent / ruleReview 等）静默跳过，不打警告：
//    904 条里带这些字段的很多，逐条报警会刷爆日志。
// 3. 不缓存：sourceJson 会被编辑页改，缓存会读到旧值。
// 4. Legado 可空、引擎非空默认：所有 string | null 统一 ?? ''。
import { BookSource as EngineBookSource } from '@legado/sourceengine';
import { BookSource as LocalBookSource } from '../model/BookSource';

export class LegadoSourceMapper {
  /** 从整条 sourceJson 映射到引擎 BookSource。核心入口。 */
  static fromSourceJson(sourceJson: string): EngineBookSource {
    let raw: Record<string, Object> = {};
    if (sourceJson.length > 0) {
      try {
        const parsed: Object = JSON.parse(sourceJson);
        if (parsed !== null && typeof parsed === 'object' && !Array.isArray(parsed)) {
          raw = parsed as Record<string, Object>;
        }
      } catch (_) {
        // 坏 JSON 交给上层按空源处理；映射层不抛异常，不让一条脏源拖垮整批。
      }
    }
    const src = new EngineBookSource();

    // ---- 顶层字段（任务书 5.2 表，键名同名直接搬） ----
    src.bookSourceUrl = LegadoSourceMapper.str(raw, 'bookSourceUrl');
    src.bookSourceName = LegadoSourceMapper.str(raw, 'bookSourceName');
    src.bookSourceGroup = LegadoSourceMapper.str(raw, 'bookSourceGroup');
    src.bookSourceType = LegadoSourceMapper.num(raw, 'bookSourceType', 0);
    src.bookUrlPattern = LegadoSourceMapper.str(raw, 'bookUrlPattern');
    src.customOrder = LegadoSourceMapper.num(raw, 'customOrder', 0);
    src.enabled = LegadoSourceMapper.bool(raw, 'enabled', true);
    src.enabledExplore = LegadoSourceMapper.bool(raw, 'enabledExplore', true);
    src.enabledCookieJar = LegadoSourceMapper.bool(raw, 'enabledCookieJar', true);
    src.jsLib = LegadoSourceMapper.str(raw, 'jsLib');
    src.searchUrl = LegadoSourceMapper.str(raw, 'searchUrl');
    src.exploreUrl = LegadoSourceMapper.str(raw, 'exploreUrl');
    src.header = LegadoSourceMapper.str(raw, 'header');
    src.loginUrl = LegadoSourceMapper.str(raw, 'loginUrl');
    src.loginUi = LegadoSourceMapper.str(raw, 'loginUi');
    src.loginCheckJs = LegadoSourceMapper.str(raw, 'loginCheckJs');
    src.bookSourceComment = LegadoSourceMapper.str(raw, 'bookSourceComment');
    src.variableComment = LegadoSourceMapper.str(raw, 'variableComment');
    src.lastUpdateTime = LegadoSourceMapper.num(raw, 'lastUpdateTime', 0);
    src.respondTime = LegadoSourceMapper.num(raw, 'respondTime', 180000);
    src.weight = LegadoSourceMapper.num(raw, 'weight', 0);
    src.concurrentRate = LegadoSourceMapper.str(raw, 'concurrentRate');
    src.eventListener = LegadoSourceMapper.bool(raw, 'eventListener', false);
    src.customButton = LegadoSourceMapper.bool(raw, 'customButton', false);

    // 运行时三载体：Legado 实体里没有这三个键，但 sourceJson 里可能已被运行时写入。
    // 有就带过去，没有留引擎默认空串（引擎字段是非空默认）。
    src.loginHeader = LegadoSourceMapper.str(raw, 'loginHeader');
    src.loginInfo = LegadoSourceMapper.str(raw, 'loginInfo');
    src.variable = LegadoSourceMapper.str(raw, 'variable');

    // 原始 JSON 无损保留：未知/未来字段不丢，备份链路仍走本地 sourceJson 原样拼回。
    src.rawSourceJson = sourceJson;
    // sourceFormat 强制留空：本工程只走兼容书源路径，原生书源（'native'）不碰。
    // 即使 sourceJson 里误带了这个键也不读，避免把兼容源错送进 NativeSourceRunner。

    // ---- 六个 rule 对象逐字段投影（任务书 5.3；丢失字段静默跳过） ----
    const rs = LegadoSourceMapper.obj(raw, 'ruleSearch');
    LegadoSourceMapper.copyRule(src.searchRule, rs,
      ['bookList', 'name', 'author', 'intro', 'kind', 'lastChapter', 'updateTime', 'bookUrl', 'coverUrl', 'wordCount']);
    // checkKeyWord 引擎无，静默跳过。

    const re = LegadoSourceMapper.obj(raw, 'ruleExplore');
    LegadoSourceMapper.copyRule(src.exploreRule, re,
      ['bookList', 'name', 'author', 'intro', 'kind', 'lastChapter', 'updateTime', 'bookUrl', 'coverUrl', 'wordCount']);

    const ri = LegadoSourceMapper.obj(raw, 'ruleBookInfo');
    LegadoSourceMapper.copyRule(src.bookInfoRule, ri,
      ['init', 'name', 'author', 'intro', 'kind', 'lastChapter', 'updateTime', 'coverUrl', 'tocUrl', 'wordCount']);
    // canReName / downloadUrls / relatedBooks 引擎无，静默跳过。

    const rt = LegadoSourceMapper.obj(raw, 'ruleToc');
    LegadoSourceMapper.copyRule(src.tocRule, rt,
      ['chapterList', 'chapterName', 'chapterUrl', 'nextTocUrl', 'isVip', 'isPay', 'updateTime',
        // 批3（r359）：引擎 TocRule 补齐这三个字段后，投影不再静默丢规则。
        'preUpdateJs', 'formatJs', 'isVolume']);

    const rc = LegadoSourceMapper.obj(raw, 'ruleContent');
    LegadoSourceMapper.copyRule(src.contentRule, rc,
      ['content', 'title', 'sourceRegex', 'replaceRegex', 'imageDecode', 'imageStyle', 'payAction', 'nextContentUrl']);
    // subContent / webJs / callBackJs 引擎无，静默跳过。

    // ruleReview：引擎没有 ReviewRule 类，整块跳过。
    // coverDecodeJs / exploreScreen / homepageModules：引擎无对应字段，跳过。
    return src;
  }

  /** 便捷入口：从本地仓储条目映射（取它的 sourceJson）。 */
  static fromLocal(local: LocalBookSource): EngineBookSource {
    return LegadoSourceMapper.fromSourceJson(local.sourceJson);
  }

  /** 通用 rule 字段拷贝：按给定键名逐字段搬（键名来自任务书对照表，目标类均已声明）。 */
  private static copyRule(target: Object, raw: Record<string, Object>, keys: string[]): void {
    const t = target as Record<string, Object>;
    for (const k of keys) {
      t[k] = LegadoSourceMapper.str(raw, k);
    }
  }

  private static str(obj: Record<string, Object>, key: string): string {
    const v = obj[key];
    return typeof v === 'string' ? v : '';
  }

  private static num(obj: Record<string, Object>, key: string, def: number): number {
    const v = obj[key];
    return typeof v === 'number' && Number.isFinite(v) ? v : def;
  }

  private static bool(obj: Record<string, Object>, key: string, def: boolean): boolean {
    const v = obj[key];
    return typeof v === 'boolean' ? v : def;
  }

  private static obj(obj: Record<string, Object>, key: string): Record<string, Object> {
    const v = obj[key];
    if (v !== null && v !== undefined && typeof v === 'object' && !Array.isArray(v)) {
      return v as Record<string, Object>;
    }
    return {};
  }
}
