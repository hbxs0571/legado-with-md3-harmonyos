import { relationalStore } from '@kit.ArkData';
import { RssStar } from '../model/RssStar';
import { RdbCodec } from './RdbCodec';
import { RdbStore } from './RdbStore';
import { RdbSchema } from './RdbSchema';

/** 批量导入结果，供界面如实反馈新增与覆盖的条数。 */
export interface RssStarImportOutcome {
  added: number;
  updated: number;
  skipped: number;
}

/**
 * RSS 收藏仓储，对齐上游 `rssStars` 表（Room 实体 RssStar.kt）。
 * 首次使用返回空集，不自动生成默认数据；load() 把整表读进缓存，
 * getAll() 同步读缓存，写操作落库后更新缓存。
 * 采用合并导入语义：同主键覆盖、其余新增，本地独有条目保留，
 * 避免「恢复一份旧备份就把新数据删光」。
 */
export class RssStarRepository {
  private static readonly selectAll: string =
    'SELECT `origin`, `link`, `title`, `groupName`, `sort`, `starTime`, `type`, `durPos`, `sourceJson` ' +
    'FROM `rssStars` ORDER BY `starTime` DESC, `link` ASC';
  private static readonly insertSql: string =
    'INSERT OR REPLACE INTO `rssStars` ' +
    '(`origin`, `link`, `title`, `groupName`, `sort`, `starTime`, `type`, `durPos`, `sourceJson`) ' +
    'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)';
  private static saveQueue: Promise<void> = Promise.resolve();
  private static cachedRules: RssStar[] = [];

  /** 从关系库读全表进缓存；读取失败时留空缓存，不让备份链路崩掉。 */
  static async load(context: Context): Promise<RssStar[]> {
    let rules: RssStar[] = [];
    try {
      const store = await RdbStore.getStore(context);
      await RdbSchema.ensure(store);
      const resultSet = await store.querySql(RssStarRepository.selectAll);
      try {
        rules = RssStarRepository.readAll(resultSet);
      } finally {
        resultSet.close();
      }
    } catch (error) {
      console.error(`RSS 收藏读取失败：${error instanceof Error ? error.message : String(error)}`);
      rules = [];
    }
    RssStarRepository.cachedRules = RssStarRepository.copyRules(rules);
    return RssStarRepository.copyRules(RssStarRepository.cachedRules);
  }

  /** 取当前缓存快照，供备份与界面同步读取；缓存只在 load() 后非空。 */
  static getAll(): RssStar[] {
    return RssStarRepository.copyRules(RssStarRepository.cachedRules);
  }

  /**
   * 导出为与上游同形的 JSON 数组。
   * 直接把每行的 sourceJson 拼起来，不重新 parse：sourceJson 入库前已序列化校验过，
   * 二次 stringify 会改动字段序、并可能补出上游没有的 null。
   */
  static exportRules(rules: RssStar[]): string {
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
  static async importRules(context: Context, incoming: RssStar[]): Promise<RssStarImportOutcome> {
    const next: RssStar[] = RssStarRepository.copyRules(RssStarRepository.cachedRules);
    let added = 0;
    let updated = 0;
    let skipped = 0;
    incoming.forEach((rule: RssStar) => {
      if (!RssStarRepository.isRule(rule)) {
        skipped += 1;
        return;
      }
      const existingIndex = next.findIndex((item: RssStar) => item.origin === rule.origin && item.link === rule.link);
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
    await RssStarRepository.save(context, next);
    return { added: added, updated: updated, skipped: skipped };
  }

  /** 整表写回：串行队列内 DELETE + 逐行 INSERT OR REPLACE，整体包在事务里。 */
  static save(context: Context, rules: RssStar[]): Promise<RssStar[]> {
    const operation = RssStarRepository.saveQueue.then(async (): Promise<RssStar[]> => {
      const store = await RdbStore.getStore(context);
      await RdbSchema.ensure(store);
      store.beginTransaction();
      try {
        await RssStarRepository.replaceAll(store, rules);
        store.commit();
      } catch (error) {
        store.rollBack();
        // ArkTS 限制：catch 到的值类型不确定，不能直接 throw（arkts-limited-throw）。
        throw new Error(`RSS 收藏写入失败：${error instanceof Error ? error.message : String(error)}`);
      }
      RssStarRepository.cachedRules = RssStarRepository.copyRules(rules);
      return RssStarRepository.copyRules(rules);
    });
    RssStarRepository.saveQueue = operation.then((): void => {}, (_error: Error): void => {});
    return operation;
  }

  /** 在调用方给定的事务里整表重写；不 commit、不回滚。 */
  private static async replaceAll(store: relationalStore.RdbStore, rules: RssStar[]): Promise<void> {
    await store.executeSql('DELETE FROM `rssStars`');
    for (let index = 0; index < rules.length; index++) {
      const rule = rules[index];
      if (rule === undefined) { continue; }
      await store.executeSql(RssStarRepository.insertSql, [
        rule.origin,
        rule.link,
        rule.title,
        rule.groupName,
        rule.sort,
        rule.starTime,
        rule.type,
        rule.durPos,
        rule.sourceJson
      ]);
    }
  }

  /** 从结果集读出全部规则；列顺序与 selectAll 一致。 */
  private static readAll(resultSet: relationalStore.ResultSet): RssStar[] {
    const originIndex = RdbCodec.column(resultSet, 'origin');
    const linkIndex = RdbCodec.column(resultSet, 'link');
    const titleIndex = RdbCodec.column(resultSet, 'title');
    const groupNameIndex = RdbCodec.column(resultSet, 'groupName');
    const sortIndex = RdbCodec.column(resultSet, 'sort');
    const starTimeIndex = RdbCodec.column(resultSet, 'starTime');
    const typeIndex = RdbCodec.column(resultSet, 'type');
    const durPosIndex = RdbCodec.column(resultSet, 'durPos');
    const sourceJsonIndex = RdbCodec.column(resultSet, 'sourceJson');
    const rules: RssStar[] = [];
    while (resultSet.goToNextRow()) {
      const rule: RssStar = {
        origin: RdbCodec.text(resultSet, originIndex),
        link: RdbCodec.text(resultSet, linkIndex),
        title: RdbCodec.text(resultSet, titleIndex),
        groupName: RdbCodec.text(resultSet, groupNameIndex),
        sort: RdbCodec.text(resultSet, sortIndex),
        starTime: RdbCodec.integer(resultSet, starTimeIndex),
        type: RdbCodec.integer(resultSet, typeIndex),
        durPos: RdbCodec.integer(resultSet, durPosIndex),
        sourceJson: RdbCodec.text(resultSet, sourceJsonIndex)
      };
      rules.push(rule);
    }
    return rules;
  }

  private static copyRule(rule: RssStar): RssStar {
    return {
      origin: rule.origin,
      link: rule.link,
      title: rule.title,
      groupName: rule.groupName,
      sort: rule.sort,
      starTime: rule.starTime,
      type: rule.type,
      durPos: rule.durPos,
      sourceJson: rule.sourceJson
    };
  }

  private static copyRules(rules: RssStar[]): RssStar[] {
    return rules.map((rule: RssStar) => RssStarRepository.copyRule(rule));
  }

  private static isRule(value: RssStar): boolean {
    return value !== null && value !== undefined && typeof value === 'object' && typeof value.origin === 'string' && value.origin.length > 0 && typeof value.link === 'string' && value.link.length > 0;
  }
}
