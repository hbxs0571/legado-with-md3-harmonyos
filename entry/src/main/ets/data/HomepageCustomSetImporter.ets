import { HomepageCustomSet } from '../model/HomepageCustomSet';

/** 导入解析结果。skipped 记录无法解析成合法条目的数量，供界面如实反馈。 */
export interface HomepageCustomSetImportParse {
  rules: HomepageCustomSet[];
  skipped: number;
}

/** 单条原始分组；字段全部可选，兼容不同来源的缺省。 */
interface RawHomepageCustomSet {
  id?: string;
  name?: string;
  sortOrder?: number;
}

/**
 * 解析 homepageCustomSets.json，与上游 Restore.kt:263-265 的
 * fileToListT<HomepageCustomSet> + replaceAll 对齐。
 */
export class HomepageCustomSetImporter {
  static parse(text: string): HomepageCustomSetImportParse {
    const trimmed = text.trim();
    if (trimmed.length === 0) {
      return { rules: [], skipped: 0 };
    }
    try {
      if (trimmed.startsWith('[')) {
        const items: RawHomepageCustomSet[] = JSON.parse(trimmed);
        if (!Array.isArray(items)) {
          return { rules: [], skipped: 1 };
        }
        const rules: HomepageCustomSet[] = [];
        let skipped = 0;
        items.forEach((item: RawHomepageCustomSet) => {
          const rule = HomepageCustomSetImporter.toRule(item);
          if (rule === undefined) {
            skipped += 1;
          } else {
            rules.push(rule);
          }
        });
        return { rules: rules, skipped: skipped };
      }
      if (trimmed.startsWith('{')) {
        const single: RawHomepageCustomSet = JSON.parse(trimmed);
        const rule = HomepageCustomSetImporter.toRule(single);
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

  /** 把一条原始数据转换成分组；主键为空的条目没有落库依据，按无效跳过。 */
  private static toRule(raw: RawHomepageCustomSet): HomepageCustomSet | undefined {
    if (raw === undefined || raw === null) {
      return undefined;
    }
    const id = typeof raw.id === 'string' ? raw.id : '';
    if (id.length === 0) {
      return undefined;
    }
    return {
      id: id,
      name: typeof raw.name === 'string' ? raw.name : '',
      sortOrder: typeof raw.sortOrder === 'number' ? raw.sortOrder : 0
    };
  }
}
