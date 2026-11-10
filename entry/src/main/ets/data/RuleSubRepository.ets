import { relationalStore } from '@kit.ArkData';
import { RuleSub } from '../model/RuleSub';
import { RdbCodec } from './RdbCodec';
import { RdbStore } from './RdbStore';
import { RdbSchema } from './RdbSchema';

/** 批量导入结果，供界面如实反馈新增与覆盖的条数。 */
export interface RuleSubImportOutcome {
  added: number;
  updated: number;
  skipped: number;
}

/**
 * 规则订阅仓储，对齐上游 `ruleSubs` 表（Room 实体 RuleSub.kt）。
 * 首次使用返回空集，不自动生成默认数据；load() 把整表读进缓存，
 * getAll() 同步读缓存，写操作落库后更新缓存。
 * 采用合并导入语义：同主键覆盖、其余新增，本地独有条目保留，
 * 避免「恢复一份旧备份就把新数据删光」。
 */
export class RuleSubRepository {
  private static readonly selectAll: string =
    'SELECT `id`, `name`, `url`, `type`, `customOrder`, `autoUpdate`, `sourceJson` ' +
    'FROM `ruleSubs` ORDER BY `customOrder` ASC';
  private static readonly insertSql: string =
    'INSERT OR REPLACE INTO `ruleSubs` ' +
    '(`id`, `name`, `url`, `type`, `customOrder`, `autoUpdate`, `sourceJson`) ' +
    'VALUES (?, ?, ?, ?, ?, ?, ?)';
  private static saveQueue: Promise<void> = Promise.resolve();
  private static cachedRules: RuleSub[] = [];

  /** 从关系库读全表进缓存；读取失败时留空缓存，不让备份链路崩掉。 */
  static async load(context: Context): Promise<RuleSub[]> {
    let rules: RuleSub[] = [];
    try {
      const store = await RdbStore.getStore(context);
      await RdbSchema.ensure(store);
      const resultSet = await store.querySql(RuleSubRepository.selectAll);
      try {
        rules = RuleSubRepository.readAll(resultSet);
      } finally {
        resultSet.close();
      }
    } catch (error) {
      console.error(`规则订阅读取失败：${error instanceof Error ? error.message : String(error)}`);
      rules = [];
    }
    RuleSubRepository.cachedRules = RuleSubRepository.copyRules(rules);
    return RuleSubRepository.copyRules(RuleSubRepository.cachedRules);
  }

  /** 取当前缓存快照，供备份与界面同步读取；缓存只在 load() 后非空。 */
  static getAll(): RuleSub[] {
    return RuleSubRepository.copyRules(RuleSubRepository.cachedRules);
  }

  /**
   * 导出为与上游同形的 JSON 数组。
   * 直接把每行的 sourceJson 拼起来，不重新 parse：sourceJson 入库前已序列化校验过，
   * 二次 stringify 会改动字段序、并可能补出上游没有的 null。
   */
  static exportRules(rules: RuleSub[]): string {
    if (rules.length === 0) { return '[]'; }
    const parts: string[] = [];
    for (let index = 0; index < rules.length; index++) {
      const rule = rules[index];
      if (rule === undefined) { continue; }
      const text = rule.sourceJson.trim();
      if (text.length === 0) { continue; }
      parts.push(text);
    }
    if (parts.length === 0) { return '[]'; }
    return `[\n${parts.join(',\n')}\n]`;
  }

  /** 合并导入：同主键覆盖、其余新增，非法主键计 skipped 后跳过。 */
  static async importRules(context: Context, incoming: RuleSub[]): Promise<RuleSubImportOutcome> {
    const next: RuleSub[] = RuleSubRepository.copyRules(RuleSubRepository.cachedRules);
    let added = 0;
    let updated = 0;
    let skipped = 0;
    incoming.forEach((rule: RuleSub) => {
      if (!RuleSubRepository.isRule(rule)) {
        skipped += 1;
        return;
      }
      const existingIndex = next.findIndex((item: RuleSub) => item.id === rule.id);
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
    await RuleSubRepository.save(context, next);
    return { added: added, updated: updated, skipped: skipped };
  }

  /** 整表写回：串行队列内 DELETE + 逐行 INSERT OR REPLACE，整体包在事务里。 */
  static save(context: Context, rules: RuleSub[]): Promise<RuleSub[]> {
    const operation = RuleSubRepository.saveQueue.then(async (): Promise<RuleSub[]> => {
      const store = await RdbStore.getStore(context);
      await RdbSchema.ensure(store);
      store.beginTransaction();
      try {
        await RuleSubRepository.replaceAll(store, rules);
        store.commit();
      } catch (error) {
        store.rollBack();
        // ArkTS 限制：catch 到的值类型不确定，不能直接 throw（arkts-limited-throw）。
        throw new Error(`规则订阅写入失败：${error instanceof Error ? error.message : String(error)}`);
      }
      RuleSubRepository.cachedRules = RuleSubRepository.copyRules(rules);
      return RuleSubRepository.copyRules(rules);
    });
    RuleSubRepository.saveQueue = operation.then((): void => {}, (_error: Error): void => {});
    return operation;
  }

  /** 在调用方给定的事务里整表重写；不 commit、不回滚。 */
  private static async replaceAll(store: relationalStore.RdbStore, rules: RuleSub[]): Promise<void> {
    await store.executeSql('DELETE FROM `ruleSubs`');
    for (let index = 0; index < rules.length; index++) {
      const rule = rules[index];
      if (rule === undefined) { continue; }
      await store.executeSql(RuleSubRepository.insertSql, [
        rule.id,
        rule.name,
        rule.url,
        rule.type,
        rule.customOrder,
        rule.autoUpdate ? 1 : 0,
        rule.sourceJson
      ]);
    }
  }

  /** 从结果集读出全部规则；列顺序与 selectAll 一致。 */
  private static readAll(resultSet: relationalStore.ResultSet): RuleSub[] {
    const idIndex = RdbCodec.column(resultSet, 'id');
    const nameIndex = RdbCodec.column(resultSet, 'name');
    const urlIndex = RdbCodec.column(resultSet, 'url');
    const typeIndex = RdbCodec.column(resultSet, 'type');
    const customOrderIndex = RdbCodec.column(resultSet, 'customOrder');
    const autoUpdateIndex = RdbCodec.column(resultSet, 'autoUpdate');
    const sourceJsonIndex = RdbCodec.column(resultSet, 'sourceJson');
    const rules: RuleSub[] = [];
    while (resultSet.goToNextRow()) {
      const rule: RuleSub = {
        id: RdbCodec.integer(resultSet, idIndex),
        name: RdbCodec.text(resultSet, nameIndex),
        url: RdbCodec.text(resultSet, urlIndex),
        type: RdbCodec.integer(resultSet, typeIndex),
        customOrder: RdbCodec.integer(resultSet, customOrderIndex),
        autoUpdate: RdbCodec.boolean(resultSet, autoUpdateIndex, false),
        sourceJson: RdbCodec.text(resultSet, sourceJsonIndex)
      };
      rules.push(rule);
    }
    return rules;
  }

  private static copyRule(rule: RuleSub): RuleSub {
    return {
      id: rule.id,
      name: rule.name,
      url: rule.url,
      type: rule.type,
      customOrder: rule.customOrder,
      autoUpdate: rule.autoUpdate,
      sourceJson: rule.sourceJson
    };
  }

  private static copyRules(rules: RuleSub[]): RuleSub[] {
    return rules.map((rule: RuleSub) => RuleSubRepository.copyRule(rule));
  }

  private static isRule(value: RuleSub): boolean {
    return value !== null && value !== undefined && typeof value === 'object' && typeof value.id === 'number' && Number.isFinite(value.id);
  }
}
