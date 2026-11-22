// 发现分类的运行时支撑：infoMap 持久 + 按钮 action 执行 + viewName 求值。
//
// 对齐上游三处：
// 1. `help/source/BookSourceExtensions.kt:32-46` 的 `getExploreInfoMap(sourceUrl)` ——
//    按书源缓存一个 `InfoMap`，供 `<js>` 动态分类脚本与 toggle/select/text 的取值读写；
//    上游存在 `aCache`（内存 + 磁盘），`saveNow()` 立刻落盘。
// 2. `domain/usecase/ExploreKindUiUseCase.kt:73-95 executeAction` ——
//    用 `source.evalJS(action) { put("java", java); put("infoMap", infoMap) }` 跑分类按钮脚本，
//    `java` 是 `SourceLoginJsExtensions`（提供 `reUiView(deltaUp)` 让脚本要求刷新分类）。
// 3. `ExploreKindUiUseCase.kt:33-51 resolveDisplayName` ——
//    `viewName` 是纯字面量（`'xxx'`，长度 3..19）时直接去掉引号返回，
//    否则 `evalUiJs(viewName)` 求值，空结果回落 `"null"`，异常回落 `"err"`。
//
// 本地引擎的 `BookSourceStageWebRuntime` 会把 `request.variables` 的每个键直接挂到
// `globalThis`（`BookSourceStageWebRuntime.ts:1379`），所以 infoMap 的条目就以
// `variables` 的形式注入，脚本里 `infoMap.get(k)` 由引擎内建对象（`:1150-1153`）承载，
// 初值从 `globalThis[k]` 取不到 —— 引擎的 infoMap 是空对象起步的，所以这里同时把
// 条目挂成全局变量，脚本里既可以用 `infoMap.get(...)`，也可以直接读同名全局。
import { preferences } from '@kit.ArkData';
import {
  BookSource as EngineBookSource,
  BookSourceScriptRunner,
  BookSourceStageWebRuntime,
  StageWebRuntimeRequest,
  SourceRuntimeStage
} from '@legado/sourceengine';
import { BookSourceRepository } from '../data/BookSourceRepository';
import { BookSource } from '../model/BookSource';
import { AppLog } from '../lib/AppLog';
import { LegadoSourceMapper } from './LegadoSourceMapper';

/** 分类按钮 action 的执行结果。 */
export interface ExploreKindActionOutcome {
  /** 脚本要求刷新分类列表（`java.reUiView()` / `source.refreshExplore()`）。 */
  refreshRequested: boolean;
  /** 脚本的返回值或错误信息；空串表示没有输出。 */
  message: string;
  /** 是否执行成功（脚本没有抛错）。 */
  ok: boolean;
}

/** infoMap 的持久化偏好名；一个书源一个键，值是 `{分类标题: 取值}` 的 JSON。 */
const INFO_PREFERENCE_NAME: string = 'legado_explore_info';
/** 单源 infoMap 的内存缓存，避免每次取值都读盘。 */
const infoCache: Map<string, Record<string, string>> = new Map<string, Record<string, string>>();

export class ExploreKindAction {
  /**
   * 取某书源的 infoMap 快照（`Record<string, string>`）。
   * 上游 `getExploreInfoMap` 会 new 一个空 InfoMap 塞进缓存，这里同样「取不到就给空对象」。
   */
  static async infoMapOf(context: Context, sourceUrl: string): Promise<Record<string, string>> {
    const cached = infoCache.get(sourceUrl);
    if (cached !== undefined) { return cached; }
    const empty: Record<string, string> = {};
    if (sourceUrl.length === 0) { return empty; }
    try {
      const store = await preferences.getPreferences(context, INFO_PREFERENCE_NAME);
      const raw = store.getSync(sourceUrl, '') as string;
      if (raw.length === 0) {
        infoCache.set(sourceUrl, empty);
        return empty;
      }
      const parsed = JSON.parse(raw) as Record<string, Object>;
      const map: Record<string, string> = {};
      for (const key of Object.keys(parsed)) {
        const value = parsed[key];
        if (typeof value === 'string') { map[key] = value as string; }
      }
      infoCache.set(sourceUrl, map);
      return map;
    } catch (error) {
      AppLog.put(`读取发现分类 infoMap 失败 ${error instanceof Error ? error.message : String(error)}`);
      infoCache.set(sourceUrl, empty);
      return empty;
    }
  }

  /** 写入一项并落盘，对齐上游 `InfoMap[k] = v` + `saveNow()`。 */
  static async putValue(context: Context, sourceUrl: string, title: string, value: string): Promise<void> {
    const map = await ExploreKindAction.infoMapOf(context, sourceUrl);
    map[title] = value;
    infoCache.set(sourceUrl, map);
    if (sourceUrl.length === 0) { return; }
    try {
      const store = await preferences.getPreferences(context, INFO_PREFERENCE_NAME);
      store.putSync(sourceUrl, JSON.stringify(map));
      await store.flush();
    } catch (error) {
      AppLog.put(`保存发现分类 infoMap 失败 ${error instanceof Error ? error.message : String(error)}`);
    }
  }

  /**
   * 执行分类按钮的 action 脚本，对齐上游 `evalButtonClick`。
   *
   * `action` 三种写法与书源其它 JS 规则一致：`@js:` / `<js>…</js>` / 裸 JS。
   * 上游拼的是 `source.evalJS(jsStr)`（`evalJS` 内部会剥 `@js:` 与 `<js>`），
   * 本地对应 `BookSourceScriptRunner` 的同名剥离逻辑，所以这里先剥再送进引擎。
   */
  static async runAction(context: Context, sourceUrl: string, action: string,
    infoMap: Record<string, string>): Promise<ExploreKindActionOutcome> {
    const code = ExploreKindAction.stripJsWrapper(action);
    if (code.length === 0) {
      return { refreshRequested: false, message: '', ok: true };
    }
    const local = ExploreKindAction.findLocal(sourceUrl);
    if (local === undefined) {
      return { refreshRequested: false, message: '书源不存在', ok: false };
    }
    const engine: EngineBookSource = LegadoSourceMapper.fromLocal(local);
    const req = new StageWebRuntimeRequest();
    req.source = engine;
    req.code = code;
    req.stage = SourceRuntimeStage.EXPLORE;
    req.baseUrl = BookSourceScriptRunner.selectedBaseUrl(engine);
    req.ownerId = 'explore-action:' + sourceUrl;
    req.variables = ExploreKindAction.variablesOf(infoMap);
    try {
      const result = await BookSourceStageWebRuntime.get().execute(req);
      const message = (result.errorMessage || '').length > 0
        ? result.errorMessage
        : (result.toastMessage || result.value || '');
      return {
        refreshRequested: result.refreshExploreRequested === 'true',
        message: message,
        ok: (result.errorMessage || '').length === 0
      };
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      AppLog.put(`发现分类按钮脚本失败 ${message}`, error instanceof Error ? error : undefined);
      return { refreshRequested: false, message: message, ok: false };
    }
  }

  /**
   * 求值 `viewName` 得到显示名，对齐上游 `resolveDisplayName`。
   * 返回空串表示「没有 viewName，调用方用 kind.title」。
   */
  static async resolveDisplayName(sourceUrl: string, viewName: string,
    infoMap: Record<string, string>): Promise<string> {
    const raw = viewName.trim();
    if (raw.length === 0) { return ''; }
    // 上游 `parseLiteralViewName`：长度 3..19 且首尾都是单引号 → 去掉引号当字面量。
    if (raw.length >= 3 && raw.length <= 19 && raw.startsWith('\'') && raw.endsWith('\'')) {
      return raw.substring(1, raw.length - 1);
    }
    if (sourceUrl.length === 0) { return ''; }
    const local = ExploreKindAction.findLocal(sourceUrl);
    if (local === undefined) { return ''; }
    const engine: EngineBookSource = LegadoSourceMapper.fromLocal(local);
    const req = new StageWebRuntimeRequest();
    req.source = engine;
    req.code = ExploreKindAction.stripJsWrapper(raw);
    req.stage = SourceRuntimeStage.EXPLORE;
    req.baseUrl = BookSourceScriptRunner.selectedBaseUrl(engine);
    req.ownerId = 'explore-viewname:' + sourceUrl;
    req.variables = ExploreKindAction.variablesOf(infoMap);
    try {
      const result = await BookSourceStageWebRuntime.get().execute(req);
      if ((result.errorMessage || '').length > 0) {
        AppLog.put(`${sourceUrl} 分类 viewName 求值失败：${result.errorMessage}`);
        return 'err';
      }
      const value = result.value || '';
      // 上游 `takeUnless { it.isNullOrEmpty() } ?: "null"`。
      return value.length > 0 ? value : 'null';
    } catch (error) {
      AppLog.put(`${sourceUrl} 分类 viewName 求值失败：${error instanceof Error ? error.message : String(error)}`,
        error instanceof Error ? error : undefined);
      return 'err';
    }
  }

  /** infoMap 条目转成引擎的全局变量表。 */
  private static variablesOf(infoMap: Record<string, string>): Record<string, string> {
    const vars: Record<string, string> = {};
    for (const key of Object.keys(infoMap)) {
      vars[key] = infoMap[key];
    }
    return vars;
  }

  private static findLocal(sourceUrl: string): BookSource | undefined {
    const all: BookSource[] = BookSourceRepository.getAll();
    return all.find((row: BookSource): boolean => row.bookSourceUrl === sourceUrl);
  }

  /** `@js:xxx` / `<js>xxx</js>` / 裸 JS 三种写法统一剥成裸 JS。 */
  private static stripJsWrapper(raw: string): string {
    const text = raw.trim();
    if (/^\s*@?js:/i.test(text)) {
      return text.replace(/^\s*@?js:\s*/i, '');
    }
    if (/^\s*<js>/i.test(text)) {
      return text.replace(/^\s*<js>|<\/js>\s*$/gi, '');
    }
    return text;
  }
}
