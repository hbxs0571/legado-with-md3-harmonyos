import { RssStar } from '../model/RssStar';

/** 导入解析结果。skipped 记录无法解析成合法条目的数量，供界面如实反馈。 */
export interface RssStarImportParse {
  rules: RssStar[];
  skipped: number;
}

/** 单条原始 RSS 收藏；字段全部可选，兼容不同来源的缺省。 */
interface RawRssStar {
  origin?: string;
  sort?: string;
  title?: string;
  starTime?: number;
  link?: string;
  pubDate?: string;
  description?: string;
  content?: string;
  image?: string;
  group?: string;
  variable?: string;
  type?: number;
  durPos?: number;
}

/**
 * 解析 rssStar.json，与上游 Restore.kt 的 fileToListT<RssStar> 对齐。
 * 只保留数组与单对象两种文本分支：本地没有网络能力，也没有把 URI 传进来的入口。
 * 上游 group 是 SQL 关键字，本地列名用 groupName，但 JSON 里仍是 group 原名；
 * variableMap 是 @Ignore 派生属性，不落库、不进 JSON，整条条目原样存 sourceJson。
 */
export class RssStarImporter {
  static parse(text: string): RssStarImportParse {
    const trimmed = text.trim();
    if (trimmed.length === 0) {
      return { rules: [], skipped: 0 };
    }
    try {
      if (trimmed.startsWith('[')) {
        const items: RawRssStar[] = JSON.parse(trimmed);
        if (!Array.isArray(items)) {
          return { rules: [], skipped: 1 };
        }
        const rules: RssStar[] = [];
        let skipped = 0;
        items.forEach((item: RawRssStar) => {
          const rule = RssStarImporter.toRule(item);
          if (rule === undefined) {
            skipped += 1;
          } else {
            rules.push(rule);
          }
        });
        return { rules: rules, skipped: skipped };
      }
      if (trimmed.startsWith('{')) {
        const single: RawRssStar = JSON.parse(trimmed);
        const rule = RssStarImporter.toRule(single);
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

  /** 把一条原始数据转换成 RSS 收藏；origin 或 link 为空的条目没有落库依据，按无效跳过。 */
  private static toRule(raw: RawRssStar): RssStar | undefined {
    if (raw === undefined || raw === null) {
      return undefined;
    }
    const origin = typeof raw.origin === 'string' ? raw.origin : '';
    const link = typeof raw.link === 'string' ? raw.link : '';
    if (origin.length === 0 || link.length === 0) {
      return undefined;
    }
    // sourceJson 先序列化校验：坏对象不许入库，否则整个导出数组会语法错误。
    let sourceJson: string = '';
    try {
      sourceJson = JSON.stringify(raw);
    } catch (_) {
      return undefined;
    }
    const rule: RssStar = {
      origin: origin,
      link: link,
      title: typeof raw.title === 'string' ? raw.title : '',
      groupName: typeof raw.group === 'string' ? raw.group : '默认分组',
      sort: typeof raw.sort === 'string' ? raw.sort : '',
      starTime: typeof raw.starTime === 'number' && Number.isFinite(raw.starTime) ? raw.starTime : 0,
      type: typeof raw.type === 'number' && Number.isFinite(raw.type) ? raw.type : 0,
      durPos: typeof raw.durPos === 'number' && Number.isFinite(raw.durPos) ? raw.durPos : 0,
      sourceJson: sourceJson
    };
    return rule;
  }
}
