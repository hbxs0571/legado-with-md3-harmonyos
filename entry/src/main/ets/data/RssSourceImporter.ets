import { RssSource } from '../model/RssSource';

/** 导入解析结果。skipped 记录无法解析成合法条目的数量，供界面如实反馈。 */
export interface RssSourceImportParse {
  rules: RssSource[];
  skipped: number;
}

/** 单条原始 RSS 订阅源；字段全部可选，兼容不同来源的缺省。 */
interface RawRssSource {
  sourceUrl?: string;
  sourceName?: string;
  sourceIcon?: string;
  sourceGroup?: string;
  sourceComment?: string;
  enabled?: boolean;
  variableComment?: string;
  jsLib?: string;
  enabledCookieJar?: boolean;
  concurrentRate?: string;
  header?: string;
  loginUrl?: string;
  loginUi?: string;
  loginCheckJs?: string;
  coverDecodeJs?: string;
  sortUrl?: string;
  singleUrl?: boolean;
  articleStyle?: number;
  ruleArticles?: string;
  ruleNextPage?: string;
  ruleTitle?: string;
  rulePubDate?: string;
  ruleDescription?: string;
  ruleImage?: string;
  ruleLink?: string;
  ruleContent?: string;
  contentWhitelist?: string;
  contentBlacklist?: string;
  shouldOverrideUrlLoading?: string;
  style?: string;
  enableJs?: boolean;
  loadWithBaseUrl?: boolean;
  injectJs?: string;
  preloadJs?: string;
  startHtml?: string;
  startStyle?: string;
  startJs?: string;
  showWebLog?: boolean;
  lastUpdateTime?: number;
  customOrder?: number;
  type?: number;
  preload?: boolean;
  cacheFirst?: boolean;
  searchUrl?: string;
  redirectPolicy?: string;
}

/**
 * 解析 rssSources.json，与上游 Restore.kt 的 fileToListT<RssSource> 对齐。
 * 只保留数组与单对象两种文本分支：本地没有网络能力，也没有把 URI 传进来的入口。
 * 上游 45 个字段全是标量或 String?，这里只把 5 个排序/筛选标量独立成列，
 * 其余全留在 sourceJson 里原样往返，不做兜底、不回写。
 */
export class RssSourceImporter {
  static parse(text: string): RssSourceImportParse {
    const trimmed = text.trim();
    if (trimmed.length === 0) {
      return { rules: [], skipped: 0 };
    }
    try {
      if (trimmed.startsWith('[')) {
        const items: RawRssSource[] = JSON.parse(trimmed);
        if (!Array.isArray(items)) {
          return { rules: [], skipped: 1 };
        }
        const rules: RssSource[] = [];
        let skipped = 0;
        items.forEach((item: RawRssSource) => {
          const rule = RssSourceImporter.toRule(item);
          if (rule === undefined) {
            skipped += 1;
          } else {
            rules.push(rule);
          }
        });
        return { rules: rules, skipped: skipped };
      }
      if (trimmed.startsWith('{')) {
        const single: RawRssSource = JSON.parse(trimmed);
        const rule = RssSourceImporter.toRule(single);
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

  /** 把一条原始数据转换成 RSS 订阅源；sourceUrl 为空的条目没有落库依据，按无效跳过。 */
  private static toRule(raw: RawRssSource): RssSource | undefined {
    if (raw === undefined || raw === null) {
      return undefined;
    }
    const key = typeof raw.sourceUrl === 'string' ? raw.sourceUrl : '';
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
    const rule: RssSource = {
      sourceUrl: key,
      sourceName: typeof raw.sourceName === 'string' ? raw.sourceName : '',
      sourceGroup: typeof raw.sourceGroup === 'string' ? raw.sourceGroup : undefined,
      enabled: typeof raw.enabled === 'boolean' ? raw.enabled : true,
      customOrder: typeof raw.customOrder === 'number' && Number.isFinite(raw.customOrder) ? raw.customOrder : 0,
      sourceJson: sourceJson
    };
    return rule;
  }
}
