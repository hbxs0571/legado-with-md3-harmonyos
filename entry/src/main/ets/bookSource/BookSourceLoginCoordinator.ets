// 书源登录协调器（P9，任务书 13.2/13.3）。
// 对齐上游 SourceLoginViewModel：入口只看 loginUrl 非空，Form/Web 分流看 loginUi 是否为空。
// 引擎没有统一 login() 入口，legacy 手动链路：
//   loginItems 解析表单 → 表单值写入 source.loginInfo → 拼 loginJs + login() 调用
//   → StageWebRuntime.execute(stage='login') → 从 req.source 读回三载体。
// 关键：execute() 开头用持久化值覆盖 request.source 三载体，所以表单值必须先落库；
// execute() 内部已调 BookSourceRuntimePersistenceImpl.updateBookSourceLoginRuntime 回写，调用方不必再写。
import {
  BookSource as EngineBookSource,
  BookSourceScriptRunner,
  BookSourceLoginItem,
  BookSourceStageWebRuntime,
  StageWebRuntimeRequest,
  SourceRuntimeStage,
  CookieStore
} from '@legado/sourceengine';
import { BookSourceRepository } from '../data/BookSourceRepository';
import { BookSource } from '../model/BookSource';
import { LegadoSourceMapper } from './LegadoSourceMapper';

/** 登录准备结果：决定 UI 走表单还是 WebView。 */
export interface LoginPrepare {
  mode: string;              // 'form' | 'web' | 'error'
  items: BookSourceLoginItem[];
  entryUrl: string;
  sourceName: string;
  message: string;
}

/** 登录提交结果。 */
export interface LoginSubmitResult {
  ok: boolean;
  message: string;
  loginHeader: string;
  loginInfo: string;
  variable: string;
  cookie: string;
}

/** 登录态检查结果（具名接口，ArkTS 禁内联对象类型）。 */
export interface LoginCheckResult {
  ok: boolean;
  message: string;
}

export class BookSourceLoginCoordinator {
  /** 该源是否有登录能力（loginUrl 非空，与上游 hasLoginUrl 一致）。 */
  static hasLogin(sourceUrl: string): boolean {
    const local = BookSourceLoginCoordinator.findLocal(sourceUrl);
    if (local === undefined) { return false; }
    const engine = LegadoSourceMapper.fromLocal(local);
    return (engine.loginUrl || '').trim().length > 0;
  }

  /** 准备登录界面：解析表单项 + 决定模式 + 算入口 URL。 */
  static prepare(sourceUrl: string): LoginPrepare {
    const local = BookSourceLoginCoordinator.findLocal(sourceUrl);
    if (local === undefined) {
      return { mode: 'error', items: [], entryUrl: '', sourceName: '', message: '书源不存在' };
    }
    const engine = LegadoSourceMapper.fromLocal(local);
    let items: BookSourceLoginItem[] = [];
    try {
      items = BookSourceScriptRunner.loginItems(engine);
    } catch (_) {
      items = [];
    }
    // 分流以「能否解析出控件」为准：loginUi=webView 标记或解析不出控件时走 Web 模式，
    // 避免用户看到一个空表单（真实 904 库里东滩小说就是 loginUi='webView'）。
    const mode = items.length > 0 ? 'form' : 'web';
    let entryUrl = '';
    try {
      entryUrl = BookSourceScriptRunner.loginEntryUrl(engine);
    } catch (_) {
      entryUrl = (engine.loginUrl || '').trim();
    }
    return { mode: mode, items: items, entryUrl: entryUrl, sourceName: engine.bookSourceName, message: '' };
  }

  /**
   * 提交表单登录。表单值先写进 sourceJson.loginInfo 并落库（execute 会用持久化覆盖 request.source），
   * 再执行 loginJs + login()，最后从 request.source 读回三载体。
   */
  static async submit(context: Context, sourceUrl: string,
    formValues: Record<string, string>): Promise<LoginSubmitResult> {
    const local = BookSourceLoginCoordinator.findLocal(sourceUrl);
    if (local === undefined) {
      return BookSourceLoginCoordinator.fail('书源不存在');
    }
    let engine = LegadoSourceMapper.fromLocal(local);
    if ((engine.loginUrl || '').trim().length === 0) {
      return BookSourceLoginCoordinator.fail('书源未配置登录');
    }

    // 1) 合并表单值到 loginInfo（保留运行时已有的 __legadoHarmonyRuntime 等键）。
    const loginInfoJson = BookSourceLoginCoordinator.mergeLoginInfo(engine.loginInfo, formValues);
    try {
      await BookSourceLoginCoordinator.persistLoginInfo(context, sourceUrl, loginInfoJson);
    } catch (error) {
      return BookSourceLoginCoordinator.fail('保存表单失败：' +
        (error instanceof Error ? error.message : String(error)));
    }
    // 2) 用落库后的快照重建引擎源，保证 loginInfo 进入脚本上下文。
    const refreshed = BookSourceLoginCoordinator.findLocal(sourceUrl);
    engine = refreshed !== undefined ? LegadoSourceMapper.fromLocal(refreshed) : engine;
    engine.loginInfo = loginInfoJson;

    // 3) loginJs 取自 loginUrl（@js:/<js>/裸 JS 三种写法），拼 login() 调用。
    const loginJs = BookSourceLoginCoordinator.loginJsOf(engine);
    const code = `${loginJs}\nif(typeof login=='function'){login.apply(this)}`;
    const req = new StageWebRuntimeRequest();
    req.source = engine;
    req.code = code;
    req.stage = SourceRuntimeStage.LOGIN;
    req.baseUrl = BookSourceScriptRunner.selectedBaseUrl(engine);
    req.ownerId = 'login:' + sourceUrl;

    let resultValue = '';
    let errorMessage = '';
    try {
      const result = await BookSourceStageWebRuntime.get().execute(req);
      resultValue = result.value || '';
      errorMessage = result.errorMessage || '';
    } catch (error) {
      return BookSourceLoginCoordinator.fail('登录脚本执行失败：' +
        (error instanceof Error ? error.message : String(error)));
    }

    // 4) 三载体从 request.source 读回（execute 内部已持久化）。
    const cookie = CookieStore.forSource(sourceUrl).getCookie(req.baseUrl || engine.loginUrl);
    const message = errorMessage.length > 0 ? errorMessage :
      (resultValue.length > 0 ? resultValue : '登录请求已提交');
    return {
      ok: errorMessage.length === 0,
      message: message,
      loginHeader: req.source.loginHeader || '',
      loginInfo: req.source.loginInfo || '',
      variable: req.source.variable || '',
      cookie: cookie
    };
  }

  /** 执行表单项的按钮 action（发验证码/切换方式等），与上游 runRowAction 对齐。 */
  static async runAction(sourceUrl: string, action: string): Promise<string> {
    const local = BookSourceLoginCoordinator.findLocal(sourceUrl);
    if (local === undefined) { return '书源不存在'; }
    const engine = LegadoSourceMapper.fromLocal(local);
    if (/^https?:\/\//i.test(action.trim())) { return '外部链接：' + action.trim(); }
    const loginJs = BookSourceLoginCoordinator.loginJsOf(engine);
    const req = new StageWebRuntimeRequest();
    req.source = engine;
    req.code = `${loginJs}\n${action}`;
    req.stage = SourceRuntimeStage.LOGIN;
    req.baseUrl = BookSourceScriptRunner.selectedBaseUrl(engine);
    req.ownerId = 'login-action:' + sourceUrl;
    try {
      const result = await BookSourceStageWebRuntime.get().execute(req);
      return result.errorMessage || result.value || result.toastMessage || '操作已执行';
    } catch (error) {
      return error instanceof Error ? error.message : String(error);
    }
  }

  /** 执行登录检查脚本 loginCheckJs，返回真值即已登录。 */
  static async checkLogin(sourceUrl: string): Promise<LoginCheckResult> {
    const local = BookSourceLoginCoordinator.findLocal(sourceUrl);
    if (local === undefined) { return BookSourceLoginCoordinator.checkFail('书源不存在'); }
    const engine = LegadoSourceMapper.fromLocal(local);
    const checkJs = (engine.loginCheckJs || '').trim();
    if (checkJs.length === 0) { return BookSourceLoginCoordinator.checkFail('源未配置 loginCheckJs'); }
    const req = new StageWebRuntimeRequest();
    req.source = engine;
    req.code = BookSourceLoginCoordinator.stripJsWrapper(checkJs);
    req.stage = SourceRuntimeStage.LOGIN;
    req.baseUrl = BookSourceScriptRunner.selectedBaseUrl(engine);
    try {
      const result = await BookSourceStageWebRuntime.get().execute(req);
      const truthy = result.value === 'true' || result.value === '1';
      const checkResult: LoginCheckResult = {
        ok: truthy, message: result.value || result.errorMessage || ''
      };
      return checkResult;
    } catch (error) {
      return BookSourceLoginCoordinator.checkFail(error instanceof Error ? error.message : String(error));
    }
  }

  private static checkFail(message: string): LoginCheckResult {
    const result: LoginCheckResult = { ok: false, message: message };
    return result;
  }

  /** 清除该源的三载体：cookie + loginHeader/loginInfo/variable。 */
  static async clearLogin(context: Context, sourceUrl: string): Promise<string> {
    const local = BookSourceLoginCoordinator.findLocal(sourceUrl);
    if (local === undefined) { return '书源不存在'; }
    CookieStore.forSource(sourceUrl).removeCookie('');
    try {
      await BookSourceLoginCoordinator.persistLoginInfo(context, sourceUrl, '');
      const all = BookSourceRepository.getAll();
      const idx = all.findIndex((r: BookSource): boolean => r.bookSourceUrl === sourceUrl);
      if (idx >= 0) {
        const cleared: Record<string, string> = {};
        cleared['loginHeader'] = '';
        cleared['loginInfo'] = '';
        cleared['variable'] = '';
        BookSourceLoginCoordinator.writeJsonKeys(all[idx], cleared);
        await BookSourceRepository.save(context, all);
      }
    } catch (error) {
      return '清除失败：' + (error instanceof Error ? error.message : String(error));
    }
    return '已清除 Cookie 与登录态';
  }

  /**
   * 删除登录头：对齐上游 BaseSource.kt:158-161 `removeLoginHeader()`——
   * `CacheManager.delete("loginHeader_${getKey()}")` + `CookieStore.removeCookie(getKey())`。
   * 本地没有 CacheManager，loginHeader 存在 sourceJson 的 loginHeader 键里，所以清该键 + 清 Cookie。
   */
  static async removeLoginHeader(context: Context, sourceUrl: string): Promise<string> {
    const all = BookSourceRepository.getAll();
    const idx = all.findIndex((r: BookSource): boolean => r.bookSourceUrl === sourceUrl);
    if (idx < 0) { return '书源不存在'; }
    const patch: Record<string, string> = {};
    patch['loginHeader'] = '';
    BookSourceLoginCoordinator.writeJsonKeys(all[idx], patch);
    try {
      await BookSourceRepository.save(context, all);
    } catch (error) {
      return '删除失败：' + (error instanceof Error ? error.message : String(error));
    }
    // 上游同时清 Cookie（登录头与 Cookie 是同一套登录态的两半）。
    CookieStore.forSource(sourceUrl).removeCookie('');
    return '已删除登录头与 Cookie';
  }

  // ---- 私有辅助 ----

  private static findLocal(sourceUrl: string): BookSource | undefined {
    const all = BookSourceRepository.getAll();
    return all.find((r: BookSource): boolean => r.bookSourceUrl === sourceUrl);
  }

  private static fail(message: string): LoginSubmitResult {
    return { ok: false, message: message, loginHeader: '', loginInfo: '', variable: '', cookie: '' };
  }

  /** loginUrl 的三种写法：@js:xxx / <js>xxx</js> / 裸 JS；普通 URL 原样返回。 */
  private static loginJsOf(engine: EngineBookSource): string {
    const raw = (engine.loginUrl || '').trim();
    if (/^\s*@?js:/i.test(raw)) { return raw.replace(/^\s*@?js:\s*/i, ''); }
    if (/^\s*<js>/i.test(raw)) { return raw.replace(/^\s*<js>|<\/js>\s*$/gi, ''); }
    return raw;
  }

  private static stripJsWrapper(raw: string): string {
    if (/^\s*@?js:/i.test(raw)) { return raw.replace(/^\s*@?js:\s*/i, ''); }
    if (/^\s*<js>/i.test(raw)) { return raw.replace(/^\s*<js>|<\/js>\s*$/gi, ''); }
    return raw;
  }

  /** 把已有 loginInfo JSON 与表单值合并（表单值覆盖同名键）。 */
  private static mergeLoginInfo(existing: string, formValues: Record<string, string>): string {
    let obj: Record<string, Object> = {};
    if (existing.trim().length > 0) {
      try {
        const parsed: Object = JSON.parse(existing);
        if (parsed !== null && typeof parsed === 'object' && !Array.isArray(parsed)) {
          obj = parsed as Record<string, Object>;
        }
      } catch (_) { /* 坏 JSON 当空对象重建 */ }
    }
    for (const key of Object.keys(formValues)) {
      obj[key] = formValues[key];
    }
    return JSON.stringify(obj);
  }

  /** 把 loginInfo 写进 sourceJson 并落库。 */
  private static async persistLoginInfo(context: Context, sourceUrl: string, loginInfoJson: string): Promise<void> {
    const all = BookSourceRepository.getAll();
    const idx = all.findIndex((r: BookSource): boolean => r.bookSourceUrl === sourceUrl);
    if (idx < 0) { return; }
    const patch: Record<string, string> = {};
    patch['loginInfo'] = loginInfoJson;
    BookSourceLoginCoordinator.writeJsonKeys(all[idx], patch);
    await BookSourceRepository.save(context, all);
  }

  /** 按给定键值改写 sourceJson（ArkTS 禁 spread，显式逐键赋值）。 */
  private static writeJsonKeys(target: BookSource, keys: Record<string, string>): void {
    let raw: Record<string, Object> = {};
    try {
      const parsed: Object = JSON.parse(target.sourceJson);
      if (parsed !== null && typeof parsed === 'object' && !Array.isArray(parsed)) {
        raw = parsed as Record<string, Object>;
      }
    } catch (_) { /* 坏 JSON 不覆盖，保留原样 */ return; }
    for (const key of Object.keys(keys)) {
      raw[key] = keys[key];
    }
    target.sourceJson = JSON.stringify(raw);
  }
}
