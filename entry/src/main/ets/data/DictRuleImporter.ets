import { DictRule } from '../model/DictRule';

/** 导入解析结果。skipped 记录无法解析成合法条目的数量，供界面如实反馈。 */
export interface DictRuleImportParse {
  rules: DictRule[];
  skipped: number;
}

/** 单条原始规则；字段全部可选，兼容不同来源的缺省。 */
interface RawDictRule {
  name?: string;
  urlRule?: string;
  showRule?: string;
  enabled?: boolean;
  sortNumber?: number;
}

/**
 * 解析 dictRule.json，与上游 Restore.kt:242-245 的 fileToListT<DictRule> 对齐。
 * 只保留数组与单对象两种文本分支：本地没有网络能力，也没有把 URI 传进来的入口。
 */
export class DictRuleImporter {
  static parse(text: string): DictRuleImportParse {
    const trimmed = text.trim();
    if (trimmed.length === 0) {
      return { rules: [], skipped: 0 };
    }
    try {
      if (trimmed.startsWith('[')) {
        const items: RawDictRule[] = JSON.parse(trimmed);
        if (!Array.isArray(items)) {
          return { rules: [], skipped: 1 };
        }
        const rules: DictRule[] = [];
        let skipped = 0;
        items.forEach((item: RawDictRule) => {
          const rule = DictRuleImporter.toRule(item);
          if (rule === undefined) {
            skipped += 1;
          } else {
            rules.push(rule);
          }
        });
        return { rules: rules, skipped: skipped };
      }
      if (trimmed.startsWith('{')) {
        const single: RawDictRule = JSON.parse(trimmed);
        const rule = DictRuleImporter.toRule(single);
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

  /** 把一条原始数据转换成规则；主键为空的条目没有落库依据，按无效跳过。 */
  private static toRule(raw: RawDictRule): DictRule | undefined {
    if (raw === undefined || raw === null) {
      return undefined;
    }
    const name = typeof raw.name === 'string' ? raw.name : '';
    if (name.length === 0) {
      return undefined;
    }
    return {
      name: name,
      urlRule: typeof raw.urlRule === 'string' ? raw.urlRule : '',
      showRule: typeof raw.showRule === 'string' ? raw.showRule : '',
      enabled: typeof raw.enabled === 'boolean' ? raw.enabled : true,
      sortNumber: typeof raw.sortNumber === 'number' ? raw.sortNumber : 0
    };
  }
}
