import { preferences } from '@kit.ArkData';
import { Context } from '@kit.AbilityKit';
import {
  DEFAULT_COVER_RULE_SEARCH_URL, DEFAULT_COVER_RULE_EXPRESSION
} from './CoverRuleDefaults';

/**
 * 封面规则（coverRule）的运行期模型与存储。
 *
 * 上游 model 见 legado-with-MD3 的 model/BookCover.kt:284-304：
 * CoverRule 共 9 个字段，UI（CoverRuleConfigSheet.kt:25-83）只暴露前 3 个
 * （enable / searchUrl / coverRule），其余 6 个是 BaseSource 的通用字段，
 * 本轮只做存储与取用，不单独在界面上编辑。
 *
 * 上游运行期把规则存进 CacheManager 的 `legadoCoverRuleConfig` 键；
 * 本地没有 caches 表，用独立 preferences 文件 `legado_cover_rule` 承载，
 * 与 CoverSettingsRepository 的落盘方式保持一致。
 * coverRule.json 只在上游备份/恢复时读写，本地不接（KI-COVER2 第二段）。
 */
export interface CoverRule {
  enable: boolean;
  searchUrl: string;
  coverRule: string;
  /** BaseSource 通用字段：并发速率。 */
  concurrentRate: string;
  /** BaseSource 通用字段：登录 URL。 */
  loginUrl: string;
  /** BaseSource 通用字段：登录 UI。 */
  loginUi: string;
  /** BaseSource 通用字段：自定义请求头。 */
  header: string;
  /** BaseSource 通用字段：JS 库。 */
  jsLib: string;
  /** BaseSource 通用字段：是否启用 CookieJar。 */
  enabledCookieJar: boolean;
}

/** 上游 assets/defaultData/coverRule.json 的默认规则，6 个 BaseSource 字段取空/false。 */
export const DEFAULT_COVER_RULE: CoverRule = {
  enable: true,
  searchUrl: DEFAULT_COVER_RULE_SEARCH_URL,
  coverRule: DEFAULT_COVER_RULE_EXPRESSION,
  concurrentRate: '',
  loginUrl: '',
  loginUi: '',
  header: '',
  jsLib: '',
  enabledCookieJar: false
};

/** 复制一份，避免调用方就地改到缓存对象。 */
export function copyCoverRule(rule: CoverRule): CoverRule {
  return {
    enable: rule.enable,
    searchUrl: rule.searchUrl,
    coverRule: rule.coverRule,
    concurrentRate: rule.concurrentRate,
    loginUrl: rule.loginUrl,
    loginUi: rule.loginUi,
    header: rule.header,
    jsLib: rule.jsLib,
    enabledCookieJar: rule.enabledCookieJar
  };
}

/** 上游 CoverConfigViewModel.kt:136 用 `rule == DefaultData.coverRule` 判断是否删缓存；本地比对 3 个 UI 字段。 */
export function isDefaultCoverRule(rule: CoverRule): boolean {
  return rule.enable === DEFAULT_COVER_RULE.enable
    && rule.searchUrl === DEFAULT_COVER_RULE.searchUrl
    && rule.coverRule === DEFAULT_COVER_RULE.coverRule;
}

export class CoverRuleRepository {
  private static readonly preferenceName: string = 'legado_cover_rule';
  private static cached: CoverRule = copyCoverRule(DEFAULT_COVER_RULE);
  private static loaded: boolean = false;
  private static saveQueue: Promise<void> = Promise.resolve();

  /** 读缓存；未 load 过时返回默认规则。 */
  static get(): CoverRule {
    return copyCoverRule(CoverRuleRepository.cached);
  }

  static isLoaded(): boolean {
    return CoverRuleRepository.loaded;
  }

  /** 从 preferences 读取 9 个字段，缺项按默认值补齐。 */
  static async load(context: Context): Promise<CoverRule> {
    const rule = copyCoverRule(DEFAULT_COVER_RULE);
    try {
      const store = await preferences.getPreferences(context, CoverRuleRepository.preferenceName);
      rule.enable = await CoverRuleRepository.readBoolean(store, 'enable', rule.enable);
      rule.searchUrl = await CoverRuleRepository.readString(store, 'searchUrl', rule.searchUrl);
      rule.coverRule = await CoverRuleRepository.readString(store, 'coverRule', rule.coverRule);
      rule.concurrentRate = await CoverRuleRepository.readString(store, 'concurrentRate', rule.concurrentRate);
      rule.loginUrl = await CoverRuleRepository.readString(store, 'loginUrl', rule.loginUrl);
      rule.loginUi = await CoverRuleRepository.readString(store, 'loginUi', rule.loginUi);
      rule.header = await CoverRuleRepository.readString(store, 'header', rule.header);
      rule.jsLib = await CoverRuleRepository.readString(store, 'jsLib', rule.jsLib);
      rule.enabledCookieJar = await CoverRuleRepository.readBoolean(
        store, 'enabledCookieJar', rule.enabledCookieJar);
    } catch (error) {
      // 读失败时回退到默认规则，不让设置页打不开。
      console.error(`[CoverRule] 读取封面规则失败: ${error}`);
    }
    CoverRuleRepository.cached = copyCoverRule(rule);
    CoverRuleRepository.loaded = true;
    return copyCoverRule(rule);
  }

  /** 覆盖保存整份规则，与 CoverSettingsRepository.save 一样串行化避免互相覆盖。 */
  static async save(context: Context, rule: CoverRule): Promise<void> {
    const snapshot = copyCoverRule(rule);
    const operation = CoverRuleRepository.saveQueue.then(async (): Promise<void> => {
      const store = await preferences.getPreferences(context, CoverRuleRepository.preferenceName);
      await store.put('enable', snapshot.enable);
      await store.put('searchUrl', snapshot.searchUrl);
      await store.put('coverRule', snapshot.coverRule);
      await store.put('concurrentRate', snapshot.concurrentRate);
      await store.put('loginUrl', snapshot.loginUrl);
      await store.put('loginUi', snapshot.loginUi);
      await store.put('header', snapshot.header);
      await store.put('jsLib', snapshot.jsLib);
      await store.put('enabledCookieJar', snapshot.enabledCookieJar);
      await store.flush();
      CoverRuleRepository.cached = copyCoverRule(snapshot);
      CoverRuleRepository.loaded = true;
    });
    CoverRuleRepository.saveQueue = operation.then((): void => undefined, (): void => undefined);
    await operation;
  }

  /** 上游 delCoverRule 删掉缓存让 getCoverRule() 回退默认；本地直接写回默认规则等价。 */
  static async del(context: Context): Promise<void> {
    await CoverRuleRepository.save(context, DEFAULT_COVER_RULE);
  }

  private static async readBoolean(
    store: preferences.Preferences, key: string, fallback: boolean
  ): Promise<boolean> {
    const value = await store.get(key, fallback);
    return typeof value === 'boolean' ? value : fallback;
  }

  private static async readString(
    store: preferences.Preferences, key: string, fallback: string
  ): Promise<string> {
    const value = await store.get(key, fallback);
    return typeof value === 'string' ? value : fallback;
  }
}
