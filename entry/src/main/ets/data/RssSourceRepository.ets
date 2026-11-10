import { relationalStore } from '@kit.ArkData';
import { RssSource } from '../model/RssSource';
import { RdbCodec } from './RdbCodec';
import { RdbStore } from './RdbStore';
import { RdbSchema } from './RdbSchema';

/** 批量导入结果，供界面如实反馈新增与覆盖的条数。 */
export interface RssSourceImportOutcome {
  added: number;
  updated: number;
  skipped: number;
}

/**
 * RSS 订阅源仓储，对齐上游 `rssSources` 表（Room 实体 RssSource.kt）。
 * 首次使用返回空集，不自动生成默认数据；load() 把整表读进缓存，
 * getAll() 同步读缓存，写操作落库后更新缓存。
 * 采用合并导入语义：同主键覆盖、其余新增，本地独有条目保留，
 * 避免「恢复一份旧备份就把新数据删光」。
 */
export class RssSourceRepository {
  private static readonly selectAll: string =
    'SELECT `sourceUrl`, `sourceName`, `sourceGroup`, `enabled`, `customOrder`, `sourceJson` ' +
    'FROM `rssSources` ORDER BY `customOrder` ASC';
  private static readonly insertSql: string =
    'INSERT OR REPLACE INTO `rssSources` ' +
    '(`sourceUrl`, `sourceName`, `sourceGroup`, `enabled`, `customOrder`, `sourceJson`) ' +
    'VALUES (?, ?, ?, ?, ?, ?)';
  private static saveQueue: Promise<void> = Promise.resolve();
  private static cachedRules: RssSource[] = [];

  /** 从关系库读全表进缓存；读取失败时留空缓存，不让备份链路崩掉。 */
  static async load(context: Context): Promise<RssSource[]> {
    let rules: RssSource[] = [];
    try {
      const store = await RdbStore.getStore(context);
      await RdbSchema.ensure(store);
      const resultSet = await store.querySql(RssSourceRepository.selectAll);
      try {
        rules = RssSourceRepository.readAll(resultSet);
      } finally {
        resultSet.close();
      }
    } catch (error) {
      console.error(`RSS 订阅源读取失败：${error instanceof Error ? error.message : String(error)}`);
      rules = [];
    }
    RssSourceRepository.cachedRules = RssSourceRepository.copyRules(rules);
    return RssSourceRepository.copyRules(RssSourceRepository.cachedRules);
  }

  /** 取当前缓存快照，供备份与界面同步读取；缓存只在 load() 后非空。 */
  static getAll(): RssSource[] {
    return RssSourceRepository.copyRules(RssSourceRepository.cachedRules);
  }

  /**
   * 导出为与上游同形的 JSON 数组。
   * 直接把每行的 sourceJson 拼起来，不重新 parse：sourceJson 入库前已序列化校验过，
   * 二次 stringify 会改动字段序、并可能补出上游没有的 null。
   */
  static exportRules(rules: RssSource[]): string {
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
  static async importRules(context: Context, incoming: RssSource[]): Promise<RssSourceImportOutcome> {
    const next: RssSource[] = RssSourceRepository.copyRules(RssSourceRepository.cachedRules);
    let added = 0;
    let updated = 0;
    let skipped = 0;
    incoming.forEach((rule: RssSource) => {
      if (!RssSourceRepository.isRule(rule)) {
        skipped += 1;
        return;
      }
      const existingIndex = next.findIndex((item: RssSource) => item.sourceUrl === rule.sourceUrl);
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
    await RssSourceRepository.save(context, next);
    return { added: added, updated: updated, skipped: skipped };
  }

  /** 整表写回：串行队列内 DELETE + 逐行 INSERT OR REPLACE，整体包在事务里。 */
  static save(context: Context, rules: RssSource[]): Promise<RssSource[]> {
    const operation = RssSourceRepository.saveQueue.then(async (): Promise<RssSource[]> => {
      const store = await RdbStore.getStore(context);
      await RdbSchema.ensure(store);
      store.beginTransaction();
      try {
        await RssSourceRepository.replaceAll(store, rules);
        store.commit();
      } catch (error) {
        store.rollBack();
        // ArkTS 限制：catch 到的值类型不确定，不能直接 throw（arkts-limited-throw）。
        throw new Error(`RSS 订阅源写入失败：${error instanceof Error ? error.message : String(error)}`);
      }
      RssSourceRepository.cachedRules = RssSourceRepository.copyRules(rules);
      return RssSourceRepository.copyRules(rules);
    });
    RssSourceRepository.saveQueue = operation.then((): void => {}, (_error: Error): void => {});
    return operation;
  }

  /** 在调用方给定的事务里整表重写；不 commit、不回滚。 */
  private static async replaceAll(store: relationalStore.RdbStore, rules: RssSource[]): Promise<void> {
    await store.executeSql('DELETE FROM `rssSources`');
    for (let index = 0; index < rules.length; index++) {
      const rule = rules[index];
      if (rule === undefined) { continue; }
      await store.executeSql(RssSourceRepository.insertSql, [
        rule.sourceUrl,
        rule.sourceName,
        rule.sourceGroup === undefined ? null : rule.sourceGroup,
        rule.enabled ? 1 : 0,
        rule.customOrder,
        rule.sourceJson
      ]);
    }
  }

  /** 从结果集读出全部规则；列顺序与 selectAll 一致。 */
  private static readAll(resultSet: relationalStore.ResultSet): RssSource[] {
    const sourceUrlIndex = RdbCodec.column(resultSet, 'sourceUrl');
    const sourceNameIndex = RdbCodec.column(resultSet, 'sourceName');
    const sourceGroupIndex = RdbCodec.column(resultSet, 'sourceGroup');
    const enabledIndex = RdbCodec.column(resultSet, 'enabled');
    const customOrderIndex = RdbCodec.column(resultSet, 'customOrder');
    const sourceJsonIndex = RdbCodec.column(resultSet, 'sourceJson');
    const rules: RssSource[] = [];
    while (resultSet.goToNextRow()) {
      const rule: RssSource = {
        sourceUrl: RdbCodec.text(resultSet, sourceUrlIndex),
        sourceName: RdbCodec.text(resultSet, sourceNameIndex),
        sourceGroup: RdbCodec.optionalText(resultSet, sourceGroupIndex),
        enabled: RdbCodec.boolean(resultSet, enabledIndex, true),
        customOrder: RdbCodec.integer(resultSet, customOrderIndex),
        sourceJson: RdbCodec.text(resultSet, sourceJsonIndex)
      };
      rules.push(rule);
    }
    return rules;
  }

  private static copyRule(rule: RssSource): RssSource {
    return {
      sourceUrl: rule.sourceUrl,
      sourceName: rule.sourceName,
      sourceGroup: rule.sourceGroup,
      enabled: rule.enabled,
      customOrder: rule.customOrder,
      sourceJson: rule.sourceJson
    };
  }

  private static copyRules(rules: RssSource[]): RssSource[] {
    return rules.map((rule: RssSource) => RssSourceRepository.copyRule(rule));
  }

  private static isRule(value: RssSource): boolean {
    return value !== null && value !== undefined && typeof value === 'object' && typeof value.sourceUrl === 'string' && value.sourceUrl.length > 0;
  }
}
