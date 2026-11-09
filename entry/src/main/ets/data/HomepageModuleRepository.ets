import { relationalStore } from '@kit.ArkData';
import { HomepageModule } from '../model/HomepageModule';
import { RdbCodec } from './RdbCodec';
import { RdbStore } from './RdbStore';
import { RdbSchema } from './RdbSchema';

/** 批量导入结果，供界面如实反馈新增与覆盖的条数。 */
export interface HomepageModuleImportOutcome {
  added: number;
  updated: number;
  skipped: number;
}

/**
 * 首页模块仓储，对齐上游 `homepage_modules` 表（Room 实体 HomepageModule.kt）。
 * 首次使用返回空集，不自动生成默认数据；load() 把整表读进缓存，
 * getAll() 同步读缓存，写操作落库后更新缓存。
 * 采用合并导入语义：同主键覆盖、其余新增，本地独有条目保留，
 * 避免「恢复一份旧备份就把新数据删光」。
 */
export class HomepageModuleRepository {
  private static readonly selectAll: string =
    'SELECT `id`, `sourceUrl`, `moduleKey`, `type`, `title`, `args`, `layoutConfig`, `url`, `isEnabled`, `sortOrder`, `customSetId`, `isUserCreated`, `customTitle`, `customSetTitle`, `sourceJsonHash`, `syncedAt` ' +
    'FROM `homepage_modules` ORDER BY `sortOrder` ASC';
  private static readonly insertSql: string =
    'INSERT OR REPLACE INTO `homepage_modules` ' +
    '(`id`, `sourceUrl`, `moduleKey`, `type`, `title`, `args`, `layoutConfig`, `url`, `isEnabled`, `sortOrder`, `customSetId`, `isUserCreated`, `customTitle`, `customSetTitle`, `sourceJsonHash`, `syncedAt`) ' +
    'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)';
  private static saveQueue: Promise<void> = Promise.resolve();
  private static cachedRules: HomepageModule[] = [];

  /** 从关系库读全表进缓存；读取失败时留空缓存，不让备份链路崩掉。 */
  static async load(context: Context): Promise<HomepageModule[]> {
    let rules: HomepageModule[] = [];
    try {
      const store = await RdbStore.getStore(context);
      await RdbSchema.ensure(store);
      const resultSet = await store.querySql(HomepageModuleRepository.selectAll);
      try {
        rules = HomepageModuleRepository.readAll(resultSet);
      } finally {
        resultSet.close();
      }
    } catch (error) {
      console.error(`首页模块读取失败：${error instanceof Error ? error.message : String(error)}`);
      rules = [];
    }
    HomepageModuleRepository.cachedRules = HomepageModuleRepository.copyRules(rules);
    return HomepageModuleRepository.copyRules(HomepageModuleRepository.cachedRules);
  }

  /** 取当前缓存快照，供备份与界面同步读取；缓存只在 load() 后非空。 */
  static getAll(): HomepageModule[] {
    return HomepageModuleRepository.copyRules(HomepageModuleRepository.cachedRules);
  }

  /** 导出为与上游同名的 JSON 数组；字段名逐字对齐实体，不含本地扩展字段。 */
  static exportRules(rules: HomepageModule[]): string {
    return JSON.stringify(rules, null, 2);
  }

  /** 合并导入：同主键覆盖、其余新增，非法主键计 skipped 后跳过。 */
  static async importRules(context: Context, incoming: HomepageModule[]): Promise<HomepageModuleImportOutcome> {
    const next: HomepageModule[] = HomepageModuleRepository.copyRules(HomepageModuleRepository.cachedRules);
    let added = 0;
    let updated = 0;
    let skipped = 0;
    incoming.forEach((rule: HomepageModule) => {
      if (!HomepageModuleRepository.isRule(rule)) {
        skipped += 1;
        return;
      }
      const existingIndex = next.findIndex((item: HomepageModule) => item.id === rule.id);
      if (existingIndex >= 0) {
        next[existingIndex] = rule;
        updated += 1;
      } else {
        next.push(rule);
        added += 1;
      }
    });
    if (added === 0 && updated === 0) {
      return { added: added, updated: updated, skipped: skipped };
    }
    await HomepageModuleRepository.save(context, next);
    return { added: added, updated: updated, skipped: skipped };
  }

  /** 整表写回：串行队列内 DELETE + 逐行 INSERT OR REPLACE，整体包在事务里。 */
  static save(context: Context, rules: HomepageModule[]): Promise<HomepageModule[]> {
    const operation = HomepageModuleRepository.saveQueue.then(async (): Promise<HomepageModule[]> => {
      const store = await RdbStore.getStore(context);
      await RdbSchema.ensure(store);
      store.beginTransaction();
      try {
        await HomepageModuleRepository.replaceAll(store, rules);
        store.commit();
      } catch (error) {
        store.rollBack();
        // ArkTS 限制：catch 到的值类型不确定，不能直接 throw（arkts-limited-throw）。
        throw new Error(`首页模块写入失败：${error instanceof Error ? error.message : String(error)}`);
      }
      HomepageModuleRepository.cachedRules = HomepageModuleRepository.copyRules(rules);
      return HomepageModuleRepository.copyRules(rules);
    });
    HomepageModuleRepository.saveQueue = operation.then((): void => {}, (_error: Error): void => {});
    return operation;
  }

  /** 在调用方给定的事务里整表重写；不 commit、不回滚。 */
  private static async replaceAll(store: relationalStore.RdbStore, rules: HomepageModule[]): Promise<void> {
    await store.executeSql('DELETE FROM `homepage_modules`');
    for (let index = 0; index < rules.length; index++) {
      const rule = rules[index];
      if (rule === undefined) { continue; }
      await store.executeSql(HomepageModuleRepository.insertSql, [
        rule.id,
        rule.sourceUrl,
        rule.moduleKey,
        rule.type,
        rule.title,
        rule.args === undefined ? null : rule.args,
        rule.layoutConfig === undefined ? null : rule.layoutConfig,
        rule.url === undefined ? null : rule.url,
        rule.isEnabled ? 1 : 0,
        rule.sortOrder,
        rule.customSetId === undefined ? null : rule.customSetId,
        rule.isUserCreated ? 1 : 0,
        rule.customTitle === undefined ? null : rule.customTitle,
        rule.customSetTitle === undefined ? null : rule.customSetTitle,
        rule.sourceJsonHash === undefined ? null : rule.sourceJsonHash,
        rule.syncedAt
      ]);
    }
  }

  /** 从结果集读出全部规则；列顺序与 selectAll 一致。 */
  private static readAll(resultSet: relationalStore.ResultSet): HomepageModule[] {
    const idIndex = RdbCodec.column(resultSet, 'id');
    const sourceUrlIndex = RdbCodec.column(resultSet, 'sourceUrl');
    const moduleKeyIndex = RdbCodec.column(resultSet, 'moduleKey');
    const typeIndex = RdbCodec.column(resultSet, 'type');
    const titleIndex = RdbCodec.column(resultSet, 'title');
    const argsIndex = RdbCodec.column(resultSet, 'args');
    const layoutConfigIndex = RdbCodec.column(resultSet, 'layoutConfig');
    const urlIndex = RdbCodec.column(resultSet, 'url');
    const isEnabledIndex = RdbCodec.column(resultSet, 'isEnabled');
    const sortOrderIndex = RdbCodec.column(resultSet, 'sortOrder');
    const customSetIdIndex = RdbCodec.column(resultSet, 'customSetId');
    const isUserCreatedIndex = RdbCodec.column(resultSet, 'isUserCreated');
    const customTitleIndex = RdbCodec.column(resultSet, 'customTitle');
    const customSetTitleIndex = RdbCodec.column(resultSet, 'customSetTitle');
    const sourceJsonHashIndex = RdbCodec.column(resultSet, 'sourceJsonHash');
    const syncedAtIndex = RdbCodec.column(resultSet, 'syncedAt');
    const rules: HomepageModule[] = [];
    while (resultSet.goToNextRow()) {
      const rule: HomepageModule = {
        id: RdbCodec.text(resultSet, idIndex),
        sourceUrl: RdbCodec.text(resultSet, sourceUrlIndex),
        moduleKey: RdbCodec.text(resultSet, moduleKeyIndex),
        type: RdbCodec.text(resultSet, typeIndex),
        title: RdbCodec.text(resultSet, titleIndex),
        args: RdbCodec.optionalText(resultSet, argsIndex),
        layoutConfig: RdbCodec.optionalText(resultSet, layoutConfigIndex),
        url: RdbCodec.optionalText(resultSet, urlIndex),
        isEnabled: RdbCodec.boolean(resultSet, isEnabledIndex, true),
        sortOrder: RdbCodec.integer(resultSet, sortOrderIndex),
        customSetId: RdbCodec.optionalText(resultSet, customSetIdIndex),
        isUserCreated: RdbCodec.boolean(resultSet, isUserCreatedIndex, false),
        customTitle: RdbCodec.optionalText(resultSet, customTitleIndex),
        customSetTitle: RdbCodec.optionalText(resultSet, customSetTitleIndex),
        sourceJsonHash: RdbCodec.optionalText(resultSet, sourceJsonHashIndex),
        syncedAt: RdbCodec.integer(resultSet, syncedAtIndex)
      };
      rules.push(rule);
    }
    return rules;
  }

  private static copyRule(rule: HomepageModule): HomepageModule {
    return {
      id: rule.id,
      sourceUrl: rule.sourceUrl,
      moduleKey: rule.moduleKey,
      type: rule.type,
      title: rule.title,
      args: rule.args,
      layoutConfig: rule.layoutConfig,
      url: rule.url,
      isEnabled: rule.isEnabled,
      sortOrder: rule.sortOrder,
      customSetId: rule.customSetId,
      isUserCreated: rule.isUserCreated,
      customTitle: rule.customTitle,
      customSetTitle: rule.customSetTitle,
      sourceJsonHash: rule.sourceJsonHash,
      syncedAt: rule.syncedAt
    };
  }

  private static copyRules(rules: HomepageModule[]): HomepageModule[] {
    return rules.map((rule: HomepageModule) => HomepageModuleRepository.copyRule(rule));
  }

  private static isRule(value: HomepageModule): boolean {
    return value !== null && value !== undefined && typeof value === 'object' && typeof value.id === 'string' && value.id.length > 0;
  }
}
