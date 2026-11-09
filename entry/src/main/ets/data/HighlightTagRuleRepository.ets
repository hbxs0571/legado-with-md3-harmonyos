import { relationalStore } from '@kit.ArkData';
import { HighlightTagRule } from '../model/HighlightTagRule';
import { RdbCodec } from './RdbCodec';
import { RdbStore } from './RdbStore';
import { RdbSchema } from './RdbSchema';

/** 批量导入结果，供界面如实反馈新增与覆盖的条数。 */
export interface HighlightTagRuleImportOutcome {
  added: number;
  updated: number;
  skipped: number;
}

/**
 * 高亮标签规则仓储，对齐上游 `highlight_tag_rules` 表（Room 实体 HighlightTagRule.kt）。
 * 首次使用返回空集，不自动生成默认数据；load() 把整表读进缓存，
 * getAll() 同步读缓存，写操作落库后更新缓存。
 * 采用合并导入语义：同主键覆盖、其余新增，本地独有条目保留，
 * 避免「恢复一份旧备份就把新数据删光」。
 */
export class HighlightTagRuleRepository {
  private static readonly selectAll: string =
    'SELECT `id`, `title`, `pattern`, `enabled`, `order` ' +
    'FROM `highlight_tag_rules` ORDER BY `order` ASC';
  private static readonly insertSql: string =
    'INSERT OR REPLACE INTO `highlight_tag_rules` ' +
    '(`id`, `title`, `pattern`, `enabled`, `order`) ' +
    'VALUES (?, ?, ?, ?, ?)';
  private static saveQueue: Promise<void> = Promise.resolve();
  private static cachedRules: HighlightTagRule[] = [];

  /** 从关系库读全表进缓存；读取失败时留空缓存，不让备份链路崩掉。 */
  static async load(context: Context): Promise<HighlightTagRule[]> {
    let rules: HighlightTagRule[] = [];
    try {
      const store = await RdbStore.getStore(context);
      await RdbSchema.ensure(store);
      const resultSet = await store.querySql(HighlightTagRuleRepository.selectAll);
      try {
        rules = HighlightTagRuleRepository.readAll(resultSet);
      } finally {
        resultSet.close();
      }
    } catch (error) {
      console.error(`高亮标签规则读取失败：${error instanceof Error ? error.message : String(error)}`);
      rules = [];
    }
    HighlightTagRuleRepository.cachedRules = HighlightTagRuleRepository.copyRules(rules);
    return HighlightTagRuleRepository.copyRules(HighlightTagRuleRepository.cachedRules);
  }

  /** 取当前缓存快照，供备份与界面同步读取；缓存只在 load() 后非空。 */
  static getAll(): HighlightTagRule[] {
    return HighlightTagRuleRepository.copyRules(HighlightTagRuleRepository.cachedRules);
  }

  /** 导出为与上游同名的 JSON 数组；字段名逐字对齐实体，不含本地扩展字段。 */
  static exportRules(rules: HighlightTagRule[]): string {
    return JSON.stringify(rules, null, 2);
  }

  /** 合并导入：同主键覆盖、其余新增，非法主键计 skipped 后跳过。 */
  static async importRules(context: Context, incoming: HighlightTagRule[]): Promise<HighlightTagRuleImportOutcome> {
    const next: HighlightTagRule[] = HighlightTagRuleRepository.copyRules(HighlightTagRuleRepository.cachedRules);
    let added = 0;
    let updated = 0;
    let skipped = 0;
    incoming.forEach((rule: HighlightTagRule) => {
      if (!HighlightTagRuleRepository.isRule(rule)) {
        skipped += 1;
        return;
      }
      const existingIndex = next.findIndex((item: HighlightTagRule) => item.id === rule.id);
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
    await HighlightTagRuleRepository.save(context, next);
    return { added: added, updated: updated, skipped: skipped };
  }

  /** 整表写回：串行队列内 DELETE + 逐行 INSERT OR REPLACE，整体包在事务里。 */
  static save(context: Context, rules: HighlightTagRule[]): Promise<HighlightTagRule[]> {
    const operation = HighlightTagRuleRepository.saveQueue.then(async (): Promise<HighlightTagRule[]> => {
      const store = await RdbStore.getStore(context);
      await RdbSchema.ensure(store);
      store.beginTransaction();
      try {
        await HighlightTagRuleRepository.replaceAll(store, rules);
        store.commit();
      } catch (error) {
        store.rollBack();
        // ArkTS 限制：catch 到的值类型不确定，不能直接 throw（arkts-limited-throw）。
        throw new Error(`高亮标签规则写入失败：${error instanceof Error ? error.message : String(error)}`);
      }
      HighlightTagRuleRepository.cachedRules = HighlightTagRuleRepository.copyRules(rules);
      return HighlightTagRuleRepository.copyRules(rules);
    });
    HighlightTagRuleRepository.saveQueue = operation.then((): void => {}, (_error: Error): void => {});
    return operation;
  }

  /** 在调用方给定的事务里整表重写；不 commit、不回滚。 */
  private static async replaceAll(store: relationalStore.RdbStore, rules: HighlightTagRule[]): Promise<void> {
    await store.executeSql('DELETE FROM `highlight_tag_rules`');
    for (let index = 0; index < rules.length; index++) {
      const rule = rules[index];
      if (rule === undefined) { continue; }
      await store.executeSql(HighlightTagRuleRepository.insertSql, [
        rule.id,
        rule.title,
        rule.pattern,
        rule.enabled ? 1 : 0,
        rule.order
      ]);
    }
  }

  /** 从结果集读出全部规则；列顺序与 selectAll 一致。 */
  private static readAll(resultSet: relationalStore.ResultSet): HighlightTagRule[] {
    const idIndex = RdbCodec.column(resultSet, 'id');
    const titleIndex = RdbCodec.column(resultSet, 'title');
    const patternIndex = RdbCodec.column(resultSet, 'pattern');
    const enabledIndex = RdbCodec.column(resultSet, 'enabled');
    const orderIndex = RdbCodec.column(resultSet, 'order');
    const rules: HighlightTagRule[] = [];
    while (resultSet.goToNextRow()) {
      const rule: HighlightTagRule = {
        id: RdbCodec.integer(resultSet, idIndex),
        title: RdbCodec.text(resultSet, titleIndex),
        pattern: RdbCodec.text(resultSet, patternIndex),
        enabled: RdbCodec.boolean(resultSet, enabledIndex, true),
        order: RdbCodec.integer(resultSet, orderIndex)
      };
      rules.push(rule);
    }
    return rules;
  }

  private static copyRule(rule: HighlightTagRule): HighlightTagRule {
    return {
      id: rule.id,
      title: rule.title,
      pattern: rule.pattern,
      enabled: rule.enabled,
      order: rule.order
    };
  }

  private static copyRules(rules: HighlightTagRule[]): HighlightTagRule[] {
    return rules.map((rule: HighlightTagRule) => HighlightTagRuleRepository.copyRule(rule));
  }

  private static isRule(value: HighlightTagRule): boolean {
    return value !== null && value !== undefined && typeof value === 'object' && typeof value.id === 'number' && value.id > 0;
  }
}
