import { HomepageModule } from '../model/HomepageModule';

/** 导入解析结果。skipped 记录无法解析成合法条目的数量，供界面如实反馈。 */
export interface HomepageModuleImportParse {
  rules: HomepageModule[];
  skipped: number;
}

/** 单条原始模块；字段全部可选，兼容不同来源的缺省。 */
interface RawHomepageModule {
  id?: string;
  sourceUrl?: string;
  moduleKey?: string;
  type?: string;
  title?: string;
  args?: string | null;
  layoutConfig?: string | null;
  url?: string | null;
  isEnabled?: boolean;
  sortOrder?: number;
  customSetId?: string | null;
  isUserCreated?: boolean;
  customTitle?: string | null;
  customSetTitle?: string | null;
  sourceJsonHash?: string | null;
  syncedAt?: number;
}

/**
 * 解析 homepageModules.json，与上游 Restore.kt:258-260 的
 * fileToListT<HomepageModule> + replaceAll 对齐。
 * 7 个可空字符串保持 undefined/null 语义，不折叠成空串。
 */
export class HomepageModuleImporter {
  static parse(text: string): HomepageModuleImportParse {
    const trimmed = text.trim();
    if (trimmed.length === 0) {
      return { rules: [], skipped: 0 };
    }
    try {
      if (trimmed.startsWith('[')) {
        const items: RawHomepageModule[] = JSON.parse(trimmed);
        if (!Array.isArray(items)) {
          return { rules: [], skipped: 1 };
        }
        const rules: HomepageModule[] = [];
        let skipped = 0;
        items.forEach((item: RawHomepageModule) => {
          const rule = HomepageModuleImporter.toRule(item);
          if (rule === undefined) {
            skipped += 1;
          } else {
            rules.push(rule);
          }
        });
        return { rules: rules, skipped: skipped };
      }
      if (trimmed.startsWith('{')) {
        const single: RawHomepageModule = JSON.parse(trimmed);
        const rule = HomepageModuleImporter.toRule(single);
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

  /** 把一条原始数据转换成模块；主键为空的条目没有落库依据，按无效跳过。 */
  private static toRule(raw: RawHomepageModule): HomepageModule | undefined {
    if (raw === undefined || raw === null) {
      return undefined;
    }
    const id = typeof raw.id === 'string' ? raw.id : '';
    if (id.length === 0) {
      return undefined;
    }
    return {
      id: id,
      sourceUrl: typeof raw.sourceUrl === 'string' ? raw.sourceUrl : '',
      moduleKey: typeof raw.moduleKey === 'string' ? raw.moduleKey : '',
      type: typeof raw.type === 'string' ? raw.type : '',
      title: typeof raw.title === 'string' ? raw.title : '',
      args: typeof raw.args === 'string' ? raw.args : undefined,
      layoutConfig: typeof raw.layoutConfig === 'string' ? raw.layoutConfig : undefined,
      url: typeof raw.url === 'string' ? raw.url : undefined,
      isEnabled: typeof raw.isEnabled === 'boolean' ? raw.isEnabled : true,
      sortOrder: typeof raw.sortOrder === 'number' ? raw.sortOrder : 0,
      customSetId: typeof raw.customSetId === 'string' ? raw.customSetId : undefined,
      isUserCreated: typeof raw.isUserCreated === 'boolean' ? raw.isUserCreated : false,
      customTitle: typeof raw.customTitle === 'string' ? raw.customTitle : undefined,
      customSetTitle: typeof raw.customSetTitle === 'string' ? raw.customSetTitle : undefined,
      sourceJsonHash: typeof raw.sourceJsonHash === 'string' ? raw.sourceJsonHash : undefined,
      syncedAt: typeof raw.syncedAt === 'number' ? raw.syncedAt : 0
    };
  }
}
