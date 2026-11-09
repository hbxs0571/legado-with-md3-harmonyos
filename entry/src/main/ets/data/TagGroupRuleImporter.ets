import { TagGroupRule } from '../model/TagGroupRule';

/** 导入解析结果。skipped 记录无法解析成合法条目的数量，供界面如实反馈。 */
export interface TagGroupRuleImportParse {
  rules: TagGroupRule[];
  skipped: number;
}

/** 单条原始规则；字段全部可选，兼容不同来源的缺省。 */
interface RawTagGroupRule {
  id?: number;
  pattern?: string;
  groupName?: string;
  order?: number;
}

/**
 * 解析 tagGroupRule.json，与上游 Restore.kt:278-280 的
 * fileToListT<TagGroupRule> + replaceAll 对齐。
 * 上游 id 默认当前毫秒，缺 id 时这里同样用 Date.now() 生成。
 */
export class TagGroupRuleImporter {
  static parse(text: string): TagGroupRuleImportParse {
    const trimmed = text.trim();
    if (trimmed.length === 0) {
      return { rules: [], skipped: 0 };
    }
    try {
      if (trimmed.startsWith('[')) {
        const items: RawTagGroupRule[] = JSON.parse(trimmed);
        if (!Array.isArray(items)) {
          return { rules: [], skipped: 1 };
        }
        const rules: TagGroupRule[] = [];
        const assignedIds: number[] = [];
        let skipped = 0;
        items.forEach((item: RawTagGroupRule) => {
          const rule = TagGroupRuleImporter.toRule(item, assignedIds);
          if (rule === undefined) {
            skipped += 1;
          } else {
            rules.push(rule);
          }
        });
        return { rules: rules, skipped: skipped };
      }
      if (trimmed.startsWith('{')) {
        const single: RawTagGroupRule = JSON.parse(trimmed);
        const rule = TagGroupRuleImporter.toRule(single, []);
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

  /** 把一条原始数据转换成规则；pattern 为空的条目按无效跳过。 */
  private static toRule(raw: RawTagGroupRule, assignedIds: number[]): TagGroupRule | undefined {
    if (raw === undefined || raw === null) {
      return undefined;
    }
    const pattern = typeof raw.pattern === 'string' ? raw.pattern : '';
    if (pattern.length === 0) {
      return undefined;
    }
    let id = typeof raw.id === 'number' && raw.id > 0 ? raw.id : Date.now();
    while (assignedIds.includes(id)) {
      id += 1;
    }
    assignedIds.push(id);
    return {
      id: id,
      pattern: pattern,
      groupName: typeof raw.groupName === 'string' ? raw.groupName : '',
      order: typeof raw.order === 'number' ? raw.order : 0
    };
  }
}
