import { relationalStore } from '@kit.ArkData';
import { DictRule } from '../model/DictRule';
import { RdbCodec } from './RdbCodec';
import { RdbStore } from './RdbStore';
import { RdbSchema } from './RdbSchema';

/** 批量导入结果，供界面如实反馈新增与覆盖的条数。 */
export interface DictRuleImportOutcome {
  added: number;
  updated: number;
  skipped: number;
}

/**
 * 字典规则仓储，对齐上游 `dictRules` 表（Room 实体 DictRule.kt）。
 * 首次使用返回空集，不自动生成默认数据；load() 把整表读进缓存，
 * getAll() 同步读缓存，写操作落库后更新缓存。
 * 采用合并导入语义：同主键覆盖、其余新增，本地独有条目保留，
 * 避免「恢复一份旧备份就把新数据删光」。
 */
export class DictRuleRepository {
  private static readonly selectAll: string =
    'SELECT `name`, `urlRule`, `showRule`, `enabled`, `sortNumber` ' +
    'FROM `dictRules` ORDER BY `sortNumber` ASC';
  private static readonly insertSql: string =
    'INSERT OR REPLACE INTO `dictRules` ' +
    '(`name`, `urlRule`, `showRule`, `enabled`, `sortNumber`) ' +
    'VALUES (?, ?, ?, ?, ?)';
  private static saveQueue: Promise<void> = Promise.resolve();
  private static cachedRules: DictRule[] = [];

  /** 从关系库读全表进缓存；读取失败时留空缓存，不让备份链路崩掉。 */
  static async load(context: Context): Promise<DictRule[]> {
    let rules: DictRule[] = [];
    try {
      const store = await RdbStore.getStore(context);
      await RdbSchema.ensure(store);
      const resultSet = await store.querySql(DictRuleRepository.selectAll);
      try {
        rules = DictRuleRepository.readAll(resultSet);
      } finally {
        resultSet.close();
      }
    } catch (error) {
      console.error(`字典规则读取失败：${error instanceof Error ? error.message : String(error)}`);
      rules = [];
    }
    DictRuleRepository.cachedRules = DictRuleRepository.copyRules(rules);
    return DictRuleRepository.copyRules(DictRuleRepository.cachedRules);
  }

  /** 取当前缓存快照，供备份与界面同步读取；缓存只在 load() 后非空。 */
  static getAll(): DictRule[] {
    return DictRuleRepository.copyRules(DictRuleRepository.cachedRules);
  }

  /** 导出为与上游同名的 JSON 数组；字段名逐字对齐实体，不含本地扩展字段。 */
  static exportRules(rules: DictRule[]): string {
    return JSON.stringify(rules, null, 2);
  }

  /** 合并导入：同主键覆盖、其余新增，非法主键计 skipped 后跳过。 */
  static async importRules(context: Context, incoming: DictRule[]): Promise<DictRuleImportOutcome> {
    const next: DictRule[] = DictRuleRepository.copyRules(DictRuleRepository.cachedRules);
    let added = 0;
    let updated = 0;
    let skipped = 0;
    incoming.forEach((rule: DictRule) => {
      if (!DictRuleRepository.isRule(rule)) {
        skipped += 1;
        return;
      }
      const existingIndex = next.findIndex((item: DictRule) => item.name === rule.name);
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
    await DictRuleRepository.save(context, next);
    return { added: added, updated: updated, skipped: skipped };
  }

  /** 整表写回：串行队列内 DELETE + 逐行 INSERT OR REPLACE，整体包在事务里。 */
  static save(context: Context, rules: DictRule[]): Promise<DictRule[]> {
    const operation = DictRuleRepository.saveQueue.then(async (): Promise<DictRule[]> => {
      const store = await RdbStore.getStore(context);
      await RdbSchema.ensure(store);
      store.beginTransaction();
      try {
        await DictRuleRepository.replaceAll(store, rules);
        store.commit();
      } catch (error) {
        store.rollBack();
        // ArkTS 限制：catch 到的值类型不确定，不能直接 throw（arkts-limited-throw）。
        throw new Error(`字典规则写入失败：${error instanceof Error ? error.message : String(error)}`);
      }
      DictRuleRepository.cachedRules = DictRuleRepository.copyRules(rules);
      return DictRuleRepository.copyRules(rules);
    });
    DictRuleRepository.saveQueue = operation.then((): void => {}, (_error: Error): void => {});
    return operation;
  }

  /** 在调用方给定的事务里整表重写；不 commit、不回滚。 */
  private static async replaceAll(store: relationalStore.RdbStore, rules: DictRule[]): Promise<void> {
    await store.executeSql('DELETE FROM `dictRules`');
    for (let index = 0; index < rules.length; index++) {
      const rule = rules[index];
      if (rule === undefined) { continue; }
      await store.executeSql(DictRuleRepository.insertSql, [
        rule.name,
        rule.urlRule,
        rule.showRule,
        rule.enabled ? 1 : 0,
        rule.sortNumber
      ]);
    }
  }

  /** 从结果集读出全部规则；列顺序与 selectAll 一致。 */
  private static readAll(resultSet: relationalStore.ResultSet): DictRule[] {
    const nameIndex = RdbCodec.column(resultSet, 'name');
    const urlRuleIndex = RdbCodec.column(resultSet, 'urlRule');
    const showRuleIndex = RdbCodec.column(resultSet, 'showRule');
    const enabledIndex = RdbCodec.column(resultSet, 'enabled');
    const sortNumberIndex = RdbCodec.column(resultSet, 'sortNumber');
    const rules: DictRule[] = [];
    while (resultSet.goToNextRow()) {
      const rule: DictRule = {
        name: RdbCodec.text(resultSet, nameIndex),
        urlRule: RdbCodec.text(resultSet, urlRuleIndex),
        showRule: RdbCodec.text(resultSet, showRuleIndex),
        enabled: RdbCodec.boolean(resultSet, enabledIndex, true),
        sortNumber: RdbCodec.integer(resultSet, sortNumberIndex)
      };
      rules.push(rule);
    }
    return rules;
  }

  private static copyRule(rule: DictRule): DictRule {
    return {
      name: rule.name,
      urlRule: rule.urlRule,
      showRule: rule.showRule,
      enabled: rule.enabled,
      sortNumber: rule.sortNumber
    };
  }

  private static copyRules(rules: DictRule[]): DictRule[] {
    return rules.map((rule: DictRule) => DictRuleRepository.copyRule(rule));
  }

  private static isRule(value: DictRule): boolean {
    return value !== null && value !== undefined && typeof value === 'object' && typeof value.name === 'string' && value.name.length > 0;
  }
}
