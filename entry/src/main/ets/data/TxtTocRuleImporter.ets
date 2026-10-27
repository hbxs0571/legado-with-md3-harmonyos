import { TxtTocRule } from '../model/TxtTocRule';

/** 导入解析结果。skipped 记录无法解析或不合法的条目数，供界面如实反馈。 */
export interface TxtTocRuleImportParse {
  rules: TxtTocRule[];
  skipped: number;
}

/** 单条原始规则；字段全部可选，兼容不同来源的缺省。 */
interface RawTxtTocRule {
  id?: number;
  name?: string;
  chapterRule?: string;
  /** 上游 @SerializedName 的 alternate，旧版订阅只写 rule 字段。 */
  rule?: string;
  volumeRule?: string;
  example?: string | null;
  serialNumber?: number;
  enable?: boolean;
}

/**
 * 解析 TXT 目录规则文本。
 *
 * 与上游 ImportTxtTocRuleViewModel.importSourceAwait 的可解析分支对齐：
 * 那个方法依次接受 JSON 对象、JSON 数组、在线 URL 与 content URI。
 * 本地没有网络能力，也没有把 URI 传进来的入口，因此只保留两种文本分支：
 * 1. JSON 数组，字段与本项目 TxtTocRule 一致；
 * 2. 单个规则对象，来源同上；
 * 两种都兼容旧版订阅格式（章节正则写在 rule 字段）。
 *
 * 无法解析或正则非法的条目计入 skipped 后跳过，不影响其余条目，
 * 与上游逐条解析、单条出错不连累整批的语义一致。
 */
export class TxtTocRuleImporter {
  /** 解析入口；格式完全无法识别时返回空结果并把整段计入 skipped。 */
  static parse(text: string): TxtTocRuleImportParse {
    const trimmed = text.trim();
    if (trimmed.length === 0) {
      return { rules: [], skipped: 0 };
    }
    try {
      if (trimmed.startsWith('[')) {
        const items: RawTxtTocRule[] = JSON.parse(trimmed);
        if (!Array.isArray(items)) {
          return { rules: [], skipped: 1 };
        }
        const reservedIds: number[] = [];
        items.forEach((item: RawTxtTocRule) => {
          if (item !== null && item !== undefined && typeof item.id === 'number' &&
            item.id > 0 && !reservedIds.includes(item.id)) {
            reservedIds.push(item.id);
          }
        });
        const assignedIds: number[] = [];
        const rules: TxtTocRule[] = [];
        let skipped: number = 0;
        items.forEach((item: RawTxtTocRule) => {
          const rule = TxtTocRuleImporter.toRule(item, reservedIds, assignedIds);
          if (rule === undefined) {
            skipped += 1;
          } else {
            rules.push(rule);
          }
        });
        return { rules: rules, skipped: skipped };
      }
      if (trimmed.startsWith('{')) {
        const single: RawTxtTocRule = JSON.parse(trimmed);
        const reservedIds: number[] = typeof single.id === 'number' && single.id > 0 ? [single.id] : [];
        const rule = TxtTocRuleImporter.toRule(single, reservedIds, []);
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

  /** 把一条原始数据转换成规则；章节正则为空或无法编译时返回 undefined。 */
  private static toRule(raw: RawTxtTocRule, reservedIds: number[], assignedIds: number[]): TxtTocRule | undefined {
    if (raw === undefined || raw === null) {
      return undefined;
    }
    // chapterRule 与 rule 二选一：上游用 @SerializedName alternate 做同一件事。
    const chapterRule = TxtTocRuleImporter.pickString(raw.chapterRule, raw.rule).trim();
    if (chapterRule.length === 0) {
      return undefined;
    }
    // 用与运行链路一致的 gm 模式校验，避免「能存进去但匹配时抛错」。
    try {
      new RegExp(chapterRule, 'gm');
    } catch (_) {
      return undefined;
    }
    const sourceId = typeof raw.id === 'number' && raw.id > 0 ? raw.id : 0;
    const id = sourceId > 0 && !assignedIds.includes(sourceId)
      ? sourceId : TxtTocRuleImporter.nextUniqueId(reservedIds, assignedIds);
    assignedIds.push(id);
    return {
      id: id,
      name: TxtTocRuleImporter.pickString(raw.name, ''),
      chapterRule: chapterRule,
      volumeRule: TxtTocRuleImporter.pickString(raw.volumeRule, ''),
      example: typeof raw.example === 'string' ? raw.example : undefined,
      serialNumber: typeof raw.serialNumber === 'number' ? raw.serialNumber : -1,
      enable: typeof raw.enable === 'boolean' ? raw.enable : true
    };
  }

  /** 生成当前批次内不重复且不覆盖输入中显式 ID 的新标识。 */
  private static nextUniqueId(reservedIds: number[], assignedIds: number[]): number {
    let id = Date.now();
    while (reservedIds.includes(id) || assignedIds.includes(id)) {
      id += 1;
    }
    return id;
  }

  /** 取第一个非空字符串，用于主字段与旧版字段的二选一。 */
  private static pickString(primary: string | undefined, fallback: string | undefined): string {
    if (typeof primary === 'string' && primary.length > 0) {
      return primary;
    }
    return typeof fallback === 'string' ? fallback : '';
  }
}
