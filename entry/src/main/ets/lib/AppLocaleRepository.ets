import { preferences } from '@kit.ArkData';
import { i18n } from '@kit.LocalizationKit';
import { Context } from '@kit.AbilityKit';

/**
 * 应用语言（对应上游 `data/repository/AppLocaleRepository.kt` 与 `constant/PreferKey.kt:5 language`）。
 *
 * 上游语义：
 * - 取值只有四档 `auto` / `zh` / `tw` / `en`，`normalizeLanguage` 把任何其它值（含 null）折成 `auto`
 *   （`AppLocaleRepository.kt:83-86`）；
 * - `setLanguage` 先把归一化结果持久化到偏好键 `language`，再交给平台切换 locale
 *   （`AppLocaleRepository.kt:49-56`：`publish` 写偏好 + `platform.setApplicationLocales`）；
 * - 平台那一层是 `AppCompatDelegate.setApplicationLocales`，作用是让系统按 locale 加载对应
 *   `values-*` 资源目录（上游有 `values`（英文）/`values-zh-rCN`/`values-zh-rHK`/`values-zh-rTW`）；
 * - 恢复备份收尾要重放一次（`help/storage/Restore.kt:392`），因为备份里的 config.xml 带着 `language`。
 *
 * 本地对应：平台 API 是 `i18n.System.setAppPreferredLanguage(language)`
 * （`@ohos.i18n.d.ts:314`，`@since 11`）。该接口的文档语义是「应用启动时按偏好语言加载资源」，
 * 传 `default` 表示跟随系统语言（同文件 `:300-302`），并注明「设置要在应用冷启动后生效」。
 * 所以本地这一层做两件事：① 把归一化后的语言持久化，启动时（`applyPersisted`）重放一次；
 * ② 调平台接口，让系统在下一次冷启动按新语言加载资源。
 */
export const APP_LANGUAGE_AUTO: string = 'auto';
export const APP_LANGUAGE_ZH: string = 'zh';
export const APP_LANGUAGE_TW: string = 'tw';
export const APP_LANGUAGE_EN: string = 'en';

/** 语言档位，顺序与上游 `res/values/array_values.xml:87-92 language_value` 一致。 */
export const APP_LANGUAGE_VALUES: string[] = [APP_LANGUAGE_AUTO, APP_LANGUAGE_ZH, APP_LANGUAGE_TW, APP_LANGUAGE_EN];

/** 档位→界面文案，顺序与上游 `res/values/arrays.xml:215-220 language` 一致。 */
export const APP_LANGUAGE_LABELS: string[] = ['跟随系统', '简体中文', '繁体中文', '英文'];

/**
 * 归一化：只认四档，其余一律 `auto`。
 * 对齐 `AppLocaleRepository.kt:83-86` 的 `normalizeLanguage`。
 */
export function normalizeAppLanguage(language: string | undefined): string {
  if (language === APP_LANGUAGE_ZH || language === APP_LANGUAGE_TW || language === APP_LANGUAGE_EN) {
    return language;
  }
  return APP_LANGUAGE_AUTO;
}

/** 档位→界面文案；认不出的值原样返回，避免下拉里出现空行。 */
export function appLanguageLabel(language: string): string {
  const index = APP_LANGUAGE_VALUES.indexOf(normalizeAppLanguage(language));
  return index >= 0 ? APP_LANGUAGE_LABELS[index] : language;
}

/**
 * 档位→平台语言标签。
 * `auto` 用 `default`（`@ohos.i18n.d.ts:300-302`：preferred language 设为 default 时跟随系统语言）。
 * 简繁中文按脚本区分（`zh-Hans` / `zh-Hant`），与上游 `Locale.SIMPLIFIED_CHINESE` /
 * `Locale.TRADITIONAL_CHINESE`（`AppLocaleRepository.kt:88-94`）同义。
 */
export function platformLanguageOf(language: string): string {
  switch (normalizeAppLanguage(language)) {
    case APP_LANGUAGE_ZH:
      return 'zh-Hans';
    case APP_LANGUAGE_TW:
      return 'zh-Hant';
    case APP_LANGUAGE_EN:
      return 'en';
    default:
      return 'default';
  }
}

export class AppLocaleRepository {
  private static readonly preferenceName: string = 'legado_app_locale';
  /** 与上游 `PreferKey.language` 同名，便于对照。 */
  private static readonly keyLanguage: string = 'language';
  private static cachedLanguage: string = APP_LANGUAGE_AUTO;

  /** 当前生效档位（未 load 过时给 `auto`）。 */
  static get(): string {
    return AppLocaleRepository.cachedLanguage;
  }

  /** 从偏好读一次并进缓存；读不到给 `auto`。 */
  static async load(context: Context): Promise<string> {
    let language = APP_LANGUAGE_AUTO;
    try {
      const store = await preferences.getPreferences(context, AppLocaleRepository.preferenceName);
      const raw = store.getSync(AppLocaleRepository.keyLanguage, APP_LANGUAGE_AUTO) as string;
      language = normalizeAppLanguage(raw);
    } catch (error) {
      console.error(`[AppLocale] 读取语言偏好失败：${error instanceof Error ? error.message : String(error)}`);
    }
    AppLocaleRepository.cachedLanguage = language;
    return language;
  }

  /**
   * 设置语言：归一化 → 写偏好 → 调平台接口。
   * 对齐 `AppLocaleRepository.kt:49-56`（`publish` 只在值变化时落盘，这里同样先比再写）。
   */
  static async setLanguage(context: Context, language: string): Promise<string> {
    const normalized = normalizeAppLanguage(language);
    const changed = normalized !== AppLocaleRepository.cachedLanguage;
    AppLocaleRepository.cachedLanguage = normalized;
    if (changed) {
      try {
        const store = await preferences.getPreferences(context, AppLocaleRepository.preferenceName);
        await store.put(AppLocaleRepository.keyLanguage, normalized);
        await store.flush();
      } catch (error) {
        console.error(`[AppLocale] 写入语言偏好失败：${error instanceof Error ? error.message : String(error)}`);
      }
    }
    AppLocaleRepository.applyToPlatform(normalized);
    return normalized;
  }

  /**
   * 启动时把已持久化的语言重放给平台，让系统在本次启动就按该语言加载资源。
   * 对应上游 `AppLocaleRepository` 初始化时用 `platform.getApplicationLocales()` 对齐状态
   * （`AppLocaleRepository.kt:37-44`）。
   */
  static async applyPersisted(context: Context): Promise<string> {
    const language = await AppLocaleRepository.load(context);
    AppLocaleRepository.applyToPlatform(language);
    return language;
  }

  /**
   * 调平台接口。失败只记日志：语言切换属增强项，不应让调用方（含恢复流程）中断。
   * `setAppPreferredLanguage` 的 `@throws 401` / `@throws 890001` 见 `@ohos.i18n.d.ts:306-308`。
   */
  private static applyToPlatform(language: string): void {
    try {
      i18n.System.setAppPreferredLanguage(platformLanguageOf(language));
    } catch (error) {
      console.error(`[AppLocale] 设置应用语言失败：${error instanceof Error ? error.message : String(error)}`);
    }
  }
}
