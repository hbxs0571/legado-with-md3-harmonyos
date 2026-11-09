import { relationalStore } from '@kit.ArkData';
import { HomepageCustomSet } from '../model/HomepageCustomSet';
import { RdbCodec } from './RdbCodec';
import { RdbStore } from './RdbStore';
import { RdbSchema } from './RdbSchema';

/** 批量导入结果，供界面如实反馈新增与覆盖的条数。 */
export interface HomepageCustomSetImportOutcome {
  added: number;
  updated: number;
  skipped: number;
}

/**
 * 首页自定义分组仓储，对齐上游 `homepage_custom_sets` 表（Room 实体 HomepageCustomSet.kt）。
 * 首次使用返回空集，不自动生成默认数据；load() 把整表读进缓存，
 * getAll() 同步读缓存，写操作落库后更新缓存。
 * 采用合并导入语义：同主键覆盖、其余新增，本地独有条目保留，
 * 避免「恢复一份旧备份就把新数据删光」。
 */
export class HomepageCustomSetRepository {
  private static readonly selectAll: string =
    'SELECT `id`, `name`, `sortOrder` ' +
    'FROM `homepage_custom_sets` ORDER BY `sortOrder` ASC';
  private static readonly insertSql: string =
    'INSERT OR REPLACE INTO `homepage_custom_sets` ' +
    '(`id`, `name`, `sortOrder`) ' +
    'VALUES (?, ?, ?)';
  private static saveQueue: Promise<void> = Promise.resolve();
  private static cachedRules: HomepageCustomSet[] = [];

  /** 从关系库读全表进缓存；读取失败时留空缓存，不让备份链路崩掉。 */
  static async load(context: Context): Promise<HomepageCustomSet[]> {
    let rules: HomepageCustomSet[] = [];
    try {
      const store = await RdbStore.getStore(context);
      await RdbSchema.ensure(store);
      const resultSet = await store.querySql(HomepageCustomSetRepository.selectAll);
      try {
        rules = HomepageCustomSetRepository.readAll(resultSet);
      } finally {
        resultSet.close();
      }
    } catch (error) {
      console.error(`首页自定义分组读取失败：${error instanceof Error ? error.message : String(error)}`);
      rules = [];
    }
    HomepageCustomSetRepository.cachedRules = HomepageCustomSetRepository.copyRules(rules);
    return HomepageCustomSetRepository.copyRules(HomepageCustomSetRepository.cachedRules);
  }

  /** 取当前缓存快照，供备份与界面同步读取；缓存只在 load() 后非空。 */
  static getAll(): HomepageCustomSet[] {
    return HomepageCustomSetRepository.copyRules(HomepageCustomSetRepository.cachedRules);
  }

  /** 导出为与上游同名的 JSON 数组；字段名逐字对齐实体，不含本地扩展字段。 */
  static exportRules(rules: HomepageCustomSet[]): string {
    return JSON.stringify(rules, null, 2);
  }

  /** 合并导入：同主键覆盖、其余新增，非法主键计 skipped 后跳过。 */
  static async importRules(context: Context, incoming: HomepageCustomSet[]): Promise<HomepageCustomSetImportOutcome> {
    const next: HomepageCustomSet[] = HomepageCustomSetRepository.copyRules(HomepageCustomSetRepository.cachedRules);
    let added = 0;
    let updated = 0;
    let skipped = 0;
    incoming.forEach((rule: HomepageCustomSet) => {
      if (!HomepageCustomSetRepository.isRule(rule)) {
        skipped += 1;
        return;
      }
      const existingIndex = next.findIndex((item: HomepageCustomSet) => item.id === rule.id);
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
    await HomepageCustomSetRepository.save(context, next);
    return { added: added, updated: updated, skipped: skipped };
  }

  /** 整表写回：串行队列内 DELETE + 逐行 INSERT OR REPLACE，整体包在事务里。 */
  static save(context: Context, rules: HomepageCustomSet[]): Promise<HomepageCustomSet[]> {
    const operation = HomepageCustomSetRepository.saveQueue.then(async (): Promise<HomepageCustomSet[]> => {
      const store = await RdbStore.getStore(context);
      await RdbSchema.ensure(store);
      store.beginTransaction();
      try {
        await HomepageCustomSetRepository.replaceAll(store, rules);
        store.commit();
      } catch (error) {
        store.rollBack();
        // ArkTS 限制：catch 到的值类型不确定，不能直接 throw（arkts-limited-throw）。
        throw new Error(`首页自定义分组写入失败：${error instanceof Error ? error.message : String(error)}`);
      }
      HomepageCustomSetRepository.cachedRules = HomepageCustomSetRepository.copyRules(rules);
      return HomepageCustomSetRepository.copyRules(rules);
    });
    HomepageCustomSetRepository.saveQueue = operation.then((): void => {}, (_error: Error): void => {});
    return operation;
  }

  /** 在调用方给定的事务里整表重写；不 commit、不回滚。 */
  private static async replaceAll(store: relationalStore.RdbStore, rules: HomepageCustomSet[]): Promise<void> {
    await store.executeSql('DELETE FROM `homepage_custom_sets`');
    for (let index = 0; index < rules.length; index++) {
      const rule = rules[index];
      if (rule === undefined) { continue; }
      await store.executeSql(HomepageCustomSetRepository.insertSql, [
        rule.id,
        rule.name,
        rule.sortOrder
      ]);
    }
  }

  /** 从结果集读出全部规则；列顺序与 selectAll 一致。 */
  private static readAll(resultSet: relationalStore.ResultSet): HomepageCustomSet[] {
    const idIndex = RdbCodec.column(resultSet, 'id');
    const nameIndex = RdbCodec.column(resultSet, 'name');
    const sortOrderIndex = RdbCodec.column(resultSet, 'sortOrder');
    const rules: HomepageCustomSet[] = [];
    while (resultSet.goToNextRow()) {
      const rule: HomepageCustomSet = {
        id: RdbCodec.text(resultSet, idIndex),
        name: RdbCodec.text(resultSet, nameIndex),
        sortOrder: RdbCodec.integer(resultSet, sortOrderIndex)
      };
      rules.push(rule);
    }
    return rules;
  }

  private static copyRule(rule: HomepageCustomSet): HomepageCustomSet {
    return {
      id: rule.id,
      name: rule.name,
      sortOrder: rule.sortOrder
    };
  }

  private static copyRules(rules: HomepageCustomSet[]): HomepageCustomSet[] {
    return rules.map((rule: HomepageCustomSet) => HomepageCustomSetRepository.copyRule(rule));
  }

  private static isRule(value: HomepageCustomSet): boolean {
    return value !== null && value !== undefined && typeof value === 'object' && typeof value.id === 'string' && value.id.length > 0;
  }
}
