import { relationalStore } from '@kit.ArkData';
import { BookSource } from '../model/BookSource';
import { RdbCodec } from './RdbCodec';
import { RdbStore } from './RdbStore';
import { RdbSchema } from './RdbSchema';

/** 批量导入结果，供界面如实反馈新增与覆盖的条数。 */
export interface BookSourceImportOutcome {
  added: number;
  updated: number;
  skipped: number;
}

/**
 * 书源仓储，对齐上游 `book_sources` 表（Room 实体 BookSource.kt）。
 * 首次使用返回空集，不自动生成默认数据；load() 把整表读进缓存，
 * getAll() 同步读缓存，写操作落库后更新缓存。
 * 采用合并导入语义：同主键覆盖、其余新增，本地独有条目保留，
 * 避免「恢复一份旧备份就把新数据删光」。
 */
export class BookSourceRepository {
  private static readonly selectAll: string =
    'SELECT `bookSourceUrl`, `bookSourceName`, `bookSourceGroup`, `bookSourceType`, `enabled`, `customOrder`, `sourceJson` ' +
    'FROM `book_sources` ORDER BY `customOrder` ASC';
  private static readonly insertSql: string =
    'INSERT OR REPLACE INTO `book_sources` ' +
    '(`bookSourceUrl`, `bookSourceName`, `bookSourceGroup`, `bookSourceType`, `enabled`, `customOrder`, `sourceJson`) ' +
    'VALUES (?, ?, ?, ?, ?, ?, ?)';
  private static saveQueue: Promise<void> = Promise.resolve();
  private static cachedRules: BookSource[] = [];

  /** 从关系库读全表进缓存；读取失败时留空缓存，不让备份链路崩掉。 */
  static async load(context: Context): Promise<BookSource[]> {
    let rules: BookSource[] = [];
    try {
      const store = await RdbStore.getStore(context);
      await RdbSchema.ensure(store);
      const resultSet = await store.querySql(BookSourceRepository.selectAll);
      try {
        rules = BookSourceRepository.readAll(resultSet);
      } finally {
        resultSet.close();
      }
    } catch (error) {
      console.error(`书源读取失败：${error instanceof Error ? error.message : String(error)}`);
      rules = [];
    }
    BookSourceRepository.cachedRules = BookSourceRepository.copyRules(rules);
    return BookSourceRepository.copyRules(BookSourceRepository.cachedRules);
  }

  /** 取当前缓存快照，供备份与界面同步读取；缓存只在 load() 后非空。 */
  static getAll(): BookSource[] {
    return BookSourceRepository.copyRules(BookSourceRepository.cachedRules);
  }

  /**
   * 导出为与上游同形的 JSON 数组。
   * 直接把每行的 sourceJson 拼起来，不重新 parse：sourceJson 入库前已序列化校验过，
   * 二次 stringify 会改动字段序、并可能补出上游没有的 null。
   */
  static exportRules(rules: BookSource[]): string {
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
  static async importRules(context: Context, incoming: BookSource[]): Promise<BookSourceImportOutcome> {
    const next: BookSource[] = BookSourceRepository.copyRules(BookSourceRepository.cachedRules);
    let added = 0;
    let updated = 0;
    let skipped = 0;
    incoming.forEach((rule: BookSource) => {
      if (!BookSourceRepository.isRule(rule)) {
        skipped += 1;
        return;
      }
      const existingIndex = next.findIndex((item: BookSource) => item.bookSourceUrl === rule.bookSourceUrl);
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
    await BookSourceRepository.save(context, next);
    return { added: added, updated: updated, skipped: skipped };
  }

  /** 整表写回：串行队列内 DELETE + 逐行 INSERT OR REPLACE，整体包在事务里。 */
  static save(context: Context, rules: BookSource[]): Promise<BookSource[]> {
    const operation = BookSourceRepository.saveQueue.then(async (): Promise<BookSource[]> => {
      const store = await RdbStore.getStore(context);
      await RdbSchema.ensure(store);
      store.beginTransaction();
      try {
        await BookSourceRepository.replaceAll(store, rules);
        store.commit();
      } catch (error) {
        store.rollBack();
        // ArkTS 限制：catch 到的值类型不确定，不能直接 throw（arkts-limited-throw）。
        throw new Error(`书源写入失败：${error instanceof Error ? error.message : String(error)}`);
      }
      BookSourceRepository.cachedRules = BookSourceRepository.copyRules(rules);
      return BookSourceRepository.copyRules(rules);
    });
    BookSourceRepository.saveQueue = operation.then((): void => {}, (_error: Error): void => {});
    return operation;
  }

  /** 在调用方给定的事务里整表重写；不 commit、不回滚。 */
  private static async replaceAll(store: relationalStore.RdbStore, rules: BookSource[]): Promise<void> {
    await store.executeSql('DELETE FROM `book_sources`');
    for (let index = 0; index < rules.length; index++) {
      const rule = rules[index];
      if (rule === undefined) { continue; }
      await store.executeSql(BookSourceRepository.insertSql, [
        rule.bookSourceUrl,
        rule.bookSourceName,
        rule.bookSourceGroup === undefined ? null : rule.bookSourceGroup,
        rule.bookSourceType,
        rule.enabled ? 1 : 0,
        rule.customOrder,
        rule.sourceJson
      ]);
    }
  }

  /** 从结果集读出全部规则；列顺序与 selectAll 一致。 */
  private static readAll(resultSet: relationalStore.ResultSet): BookSource[] {
    const bookSourceUrlIndex = RdbCodec.column(resultSet, 'bookSourceUrl');
    const bookSourceNameIndex = RdbCodec.column(resultSet, 'bookSourceName');
    const bookSourceGroupIndex = RdbCodec.column(resultSet, 'bookSourceGroup');
    const bookSourceTypeIndex = RdbCodec.column(resultSet, 'bookSourceType');
    const enabledIndex = RdbCodec.column(resultSet, 'enabled');
    const customOrderIndex = RdbCodec.column(resultSet, 'customOrder');
    const sourceJsonIndex = RdbCodec.column(resultSet, 'sourceJson');
    const rules: BookSource[] = [];
    while (resultSet.goToNextRow()) {
      const rule: BookSource = {
        bookSourceUrl: RdbCodec.text(resultSet, bookSourceUrlIndex),
        bookSourceName: RdbCodec.text(resultSet, bookSourceNameIndex),
        bookSourceGroup: RdbCodec.optionalText(resultSet, bookSourceGroupIndex),
        bookSourceType: RdbCodec.integer(resultSet, bookSourceTypeIndex),
        enabled: RdbCodec.boolean(resultSet, enabledIndex, true),
        customOrder: RdbCodec.integer(resultSet, customOrderIndex),
        sourceJson: RdbCodec.text(resultSet, sourceJsonIndex)
      };
      rules.push(rule);
    }
    return rules;
  }

  private static copyRule(rule: BookSource): BookSource {
    return {
      bookSourceUrl: rule.bookSourceUrl,
      bookSourceName: rule.bookSourceName,
      bookSourceGroup: rule.bookSourceGroup,
      bookSourceType: rule.bookSourceType,
      enabled: rule.enabled,
      customOrder: rule.customOrder,
      sourceJson: rule.sourceJson
    };
  }

  private static copyRules(rules: BookSource[]): BookSource[] {
    return rules.map((rule: BookSource) => BookSourceRepository.copyRule(rule));
  }

  private static isRule(value: BookSource): boolean {
    return value !== null && value !== undefined && typeof value === 'object' && typeof value.bookSourceUrl === 'string' && value.bookSourceUrl.length > 0;
  }
}
