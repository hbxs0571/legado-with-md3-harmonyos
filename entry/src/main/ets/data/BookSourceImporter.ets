import { BookSource } from '../model/BookSource';

/** 导入解析结果。skipped 记录无法解析成合法条目的数量，供界面如实反馈。 */
export interface BookSourceImportParse {
  rules: BookSource[];
  skipped: number;
}

/** 单条原始书源；字段全部可选，兼容不同来源的缺省。嵌套 rule 字段用 Record 承接。 */
interface RawBookSource {
  bookSourceUrl?: string;
  bookSourceName?: string;
  bookSourceGroup?: string;
  bookSourceType?: number;
  bookUrlPattern?: string;
  customOrder?: number;
  enabled?: boolean;
  enabledExplore?: boolean;
  jsLib?: string;
  enabledCookieJar?: boolean;
  concurrentRate?: string;
  header?: string;
  loginUrl?: string;
  loginUi?: string;
  loginCheckJs?: string;
  coverDecodeJs?: string;
  bookSourceComment?: string;
  variableComment?: string;
  lastUpdateTime?: number;
  respondTime?: number;
  weight?: number;
  exploreUrl?: string;
  exploreScreen?: string;
  ruleExplore?: Record<string, Object>;
  searchUrl?: string;
  ruleSearch?: Record<string, Object>;
  ruleBookInfo?: Record<string, Object>;
  ruleToc?: Record<string, Object>;
  ruleContent?: Record<string, Object>;
  ruleReview?: Record<string, Object>;
  eventListener?: boolean;
  customButton?: boolean;
  homepageModules?: string;
}

/**
 * 解析 bookSource.json，与上游 Restore.kt 的 fileToListT<BookSource> 对齐。
 * 只保留数组与单对象两种文本分支：本地没有网络能力，也没有把 URI 传进来的入口。
 * 整条条目原样存 sourceJson；enabledExplore / enabledCookieJar 等仅在 JSON 里的字段
 * 不做兜底、不回写，原样随 sourceJson 往返（GSON 省略 null 的语义）。
 */
export class BookSourceImporter {
  static parse(text: string): BookSourceImportParse {
    const trimmed = text.trim();
    if (trimmed.length === 0) {
      return { rules: [], skipped: 0 };
    }
    try {
      if (trimmed.startsWith('[')) {
        const items: RawBookSource[] = JSON.parse(trimmed);
        if (!Array.isArray(items)) {
          return { rules: [], skipped: 1 };
        }
        const rules: BookSource[] = [];
        let skipped = 0;
        items.forEach((item: RawBookSource) => {
          const rule = BookSourceImporter.toRule(item);
          if (rule === undefined) {
            skipped += 1;
          } else {
            rules.push(rule);
          }
        });
        return { rules: rules, skipped: skipped };
      }
      if (trimmed.startsWith('{')) {
        const single: RawBookSource = JSON.parse(trimmed);
        const rule = BookSourceImporter.toRule(single);
        if (rule === undefined) {
          return { rules: [], skipped: 1 };
        }
        return { rules: [rule], skipped: 0 };
      }
    } catch (_) {
      // 落到下面统一按「格式不可识别」处理。
    }
    return { rules: [], skipped: 1 };
  }

  /** 把一条原始数据转换成书源；bookSourceUrl 为空的条目没有落库依据，按无效跳过。 */
  private static toRule(raw: RawBookSource): BookSource | undefined {
    if (raw === undefined || raw === null) {
      return undefined;
    }
    const key = typeof raw.bookSourceUrl === 'string' ? raw.bookSourceUrl : '';
    if (key.length === 0) {
      return undefined;
    }
    // sourceJson 先序列化校验：坏对象不许入库，否则整个导出数组会语法错误。
    let sourceJson: string = '';
    try {
      sourceJson = JSON.stringify(raw);
    } catch (_) {
      return undefined;
    }
    const rule: BookSource = {
      bookSourceUrl: key,
      bookSourceName: typeof raw.bookSourceName === 'string' ? raw.bookSourceName : '',
      bookSourceGroup: typeof raw.bookSourceGroup === 'string' ? raw.bookSourceGroup : undefined,
      bookSourceType: typeof raw.bookSourceType === 'number' && Number.isFinite(raw.bookSourceType) ? raw.bookSourceType : 0,
      enabled: typeof raw.enabled === 'boolean' ? raw.enabled : true,
      customOrder: typeof raw.customOrder === 'number' && Number.isFinite(raw.customOrder) ? raw.customOrder : 0,
      sourceJson: sourceJson
    };
    return rule;
  }
}
