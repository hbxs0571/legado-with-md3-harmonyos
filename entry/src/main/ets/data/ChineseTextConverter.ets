import { i18n } from '@kit.LocalizationKit';

/**
 * 简繁转换，对齐上游 `help/book/ContentProcessor.kt:161-171` 的 `chineseConverterType` 三档：
 * 0 = 不转换、1 = 繁体转简体（t2s）、2 = 简体转繁体（s2t）。
 *
 * 上游用第三方库 `com.github.liuyueyi.quick-chinese-transfer:quick-transfer-core` 自带字表；
 * HOS 侧不自带字表，改用系统 ICU 的音译器（`@ohos.i18n` 的 `Transliterator`，@since 9）。
 * ICU 的 `Traditional-Simplified` / `Simplified-Traditional` 转换 ID 属核心转换数据，
 * 由系统 icu 数据提供。取不到 ID 时本类降级为「不转换」并只告警一次，不抛异常影响阅读。
 */

/** 上游 arrays.xml 的 chinese_mode 三档取值（`TypographyTabs.kt:312` 的 entryValues = 0/1/2）。 */
export const CHINESE_CONVERT_OFF: number = 0;
export const CHINESE_CONVERT_T2S: number = 1;
export const CHINESE_CONVERT_S2T: number = 2;

const TRANSLITERATOR_T2S: string = 'Traditional-Simplified';
const TRANSLITERATOR_S2T: string = 'Simplified-Traditional';

export class ChineseTextConverter {
  /** 已解析出的转换器缓存；键为档位，值为 undefined 表示该系统不支持该档。 */
  private static t2sConverter: i18n.Transliterator | undefined = undefined;
  private static s2tConverter: i18n.Transliterator | undefined = undefined;
  private static t2sResolved: boolean = false;
  private static s2tResolved: boolean = false;
  private static warned: boolean = false;

  /** 把外部传入的值归一成 0/1/2，与上游 `when (chineseConverterType)` 的三档一致。 */
  static normalizeType(value: number): number {
    if (value === CHINESE_CONVERT_T2S) {
      return CHINESE_CONVERT_T2S;
    }
    if (value === CHINESE_CONVERT_S2T) {
      return CHINESE_CONVERT_S2T;
    }
    return CHINESE_CONVERT_OFF;
  }

  /**
   * 按档位转换文本。档位 0 或转换器不可用时原样返回，调用方不需要再判断。
   */
  static convert(text: string, type: number): string {
    const normalized = ChineseTextConverter.normalizeType(type);
    if (normalized === CHINESE_CONVERT_OFF || text.length === 0) {
      return text;
    }
    const converter = ChineseTextConverter.resolve(normalized);
    if (converter === undefined) {
      return text;
    }
    try {
      return converter.transform(text);
    } catch (error) {
      if (!ChineseTextConverter.warned) {
        ChineseTextConverter.warned = true;
        console.warn(`ChineseTextConverter: 简繁转换失败，已跳过本次转换 ${error}`);
      }
      return text;
    }
  }

  /** 当前系统是否具备该档位的转换能力；设置面板据此决定是否灰掉选项。 */
  static isSupported(type: number): boolean {
    const normalized = ChineseTextConverter.normalizeType(type);
    if (normalized === CHINESE_CONVERT_OFF) {
      return true;
    }
    return ChineseTextConverter.resolve(normalized) !== undefined;
  }

  private static resolve(type: number): i18n.Transliterator | undefined {
    if (type === CHINESE_CONVERT_T2S) {
      if (!ChineseTextConverter.t2sResolved) {
        ChineseTextConverter.t2sResolved = true;
        ChineseTextConverter.t2sConverter = ChineseTextConverter.create(TRANSLITERATOR_T2S);
      }
      return ChineseTextConverter.t2sConverter;
    }
    if (!ChineseTextConverter.s2tResolved) {
      ChineseTextConverter.s2tResolved = true;
      ChineseTextConverter.s2tConverter = ChineseTextConverter.create(TRANSLITERATOR_S2T);
    }
    return ChineseTextConverter.s2tConverter;
  }

  private static create(id: string): i18n.Transliterator | undefined {
    try {
      const available: string[] = i18n.Transliterator.getAvailableIDs();
      if (!available.includes(id)) {
        if (!ChineseTextConverter.warned) {
          ChineseTextConverter.warned = true;
          console.warn(`ChineseTextConverter: 系统未提供 ${id} 转换器，简繁转换将不生效`);
        }
        return undefined;
      }
      return i18n.Transliterator.getInstance(id);
    } catch (error) {
      if (!ChineseTextConverter.warned) {
        ChineseTextConverter.warned = true;
        console.warn(`ChineseTextConverter: 获取 ${id} 转换器失败 ${error}`);
      }
      return undefined;
    }
  }
}
