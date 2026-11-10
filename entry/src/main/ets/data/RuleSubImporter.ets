import { RuleSub } from '../model/RuleSub';

/** 导入解析结果。skipped 记录无法解析成合法条目的数量，供界面如实反馈。 */
export interface RuleSubImportParse {
  rules: RuleSub[];
  skipped: number;
}

/** 单条原始规则订阅；字段全部可选，兼容不同来源的缺省。 */
interface RawRuleSub {
  id?: number;
  name?: string;
  url?: string;
  type?: number;
  customOrder?: number;
  autoUpdate?: boolean;
  update?: number;
}

/**
 * 解析 sourceSub.json，与上游 Restore.kt 的 fileToListT<RuleSub> 对齐。
 * 只保留数组与单对象两种文本分支：本地没有网络能力，也没有把 URI 传进来的入口。
 * 上游 update 是 SQL 关键字、本地无消费方，只留在 sourceJson 里；
 * type 的四值本地不做 import 分流，四种一视同仁存下来。
 */
export class RuleSubImporter {
  static parse(text: string): RuleSubImportParse {
    const trimmed = text.trim();
    if (trimmed.length === 0) {
      return { rules: [], skipped: 0 };
    }
    try {
      if (trimmed.startsWith('[')) {
        const items: RawRuleSub[] = JSON.parse(trimmed);
        if (!Array.isArray(items)) {
          return { rules: [], skipped: 1 };
        }
        const rules: RuleSub[] = [];
        const assignedIds: number[] = [];
        let skipped = 0;
        items.forEach((item: RawRuleSub) => {
          const rule = RuleSubImporter.toRule(item, assignedIds);
          if (rule === undefined) {
            skipped += 1;
          } else {
            rules.push(rule);
          }
        });
        return { rules: rules, skipped: skipped };
      }
      if (trimmed.startsWith('{')) {
        const single: RawRuleSub = JSON.parse(trimmed);
        const rule = RuleSubImporter.toRule(single, []);
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

  /** 把一条原始数据转换成规则订阅；缺 id 时按上游默认用当前毫秒生成，且同批不撞。 */
  private static toRule(raw: RawRuleSub, assignedIds: number[]): RuleSub | undefined {
    if (raw === undefined || raw === null) {
      return undefined;
    }
    // sourceJson 先序列化校验：坏对象不许入库，否则整个导出数组会语法错误。
    let sourceJson: string = '';
    try {
      sourceJson = JSON.stringify(raw);
    } catch (_) {
      return undefined;
    }
    let id = typeof raw.id === 'number' && Number.isFinite(raw.id) && raw.id > 0 ? raw.id : Date.now();
    while (assignedIds.includes(id)) {
      id += 1;
    }
    assignedIds.push(id);
    const rule: RuleSub = {
      id: id,
      name: typeof raw.name === 'string' ? raw.name : '',
      url: typeof raw.url === 'string' ? raw.url : '',
      type: typeof raw.type === 'number' && Number.isFinite(raw.type) ? raw.type : 0,
      customOrder: typeof raw.customOrder === 'number' && Number.isFinite(raw.customOrder) ? raw.customOrder : 0,
      autoUpdate: typeof raw.autoUpdate === 'boolean' ? raw.autoUpdate : false,
      sourceJson: sourceJson
    };
    return rule;
  }
}
