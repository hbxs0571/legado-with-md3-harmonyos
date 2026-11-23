import { relationalStore } from '@kit.ArkData';
import { SearchKeyword } from '../model/SearchKeyword';
import { RdbCodec } from './RdbCodec';
import { RdbStore } from './RdbStore';
import { RdbSchema } from './RdbSchema';

/**
 * 书源搜索关键词仓储，逐条对齐上游 `data/dao/SearchKeywordDao.kt` 与 `data/entities/SearchKeyword.kt`。
 *
 * 与 `ReaderSearchHistoryRepository` 不是同一张表：那边是「本书内搜索」的记录（search_content_history，
 * 带 bookName/bookAuthor），这里是搜索框的全局关键词（search_keywords，主键就是 word 本身）。
 * 备份 zip 里的 searchHistory.json 收的是这张表，上游 Backup.kt:180-181 写的也是 searchKeywordDao.all。
 *
 * 写操作串行化并包在事务里；读操作一次性读全表，不做缓存——关键词量级很小，
 * 而界面要按 usage / lastUseTime 两种顺序取，缓存反而容易读到过期顺序。
 */
export class SearchKeywordRepository {
  private static readonly selectAll: string =
    'SELECT `word`, `usage`, `lastUseTime` FROM `search_keywords` ORDER BY `lastUseTime` DESC';
  private static readonly insertSql: string =
    'INSERT OR REPLACE INTO `search_keywords` (`word`, `usage`, `lastUseTime`) VALUES (?, ?, ?)';
  private static saveQueue: Promise<void> = Promise.resolve();

  /** 全表读取，按最近使用时间倒序（对齐上游 flowByTime）。 */
  static async loadAll(context: Context): Promise<SearchKeyword[]> {
    try {
      const store = await RdbStore.getStore(context);
      await RdbSchema.ensure(store);
      const resultSet = await store.querySql(SearchKeywordRepository.selectAll);
      try {
        return SearchKeywordRepository.readAll(resultSet);
      } finally {
        resultSet.close();
      }
    } catch (error) {
      console.error(`搜索关键词读取失败：${error instanceof Error ? error.message : String(error)}`);
      return [];
    }
  }

  /** 按使用次数倒序读取（对齐上游 flowByUsage）。 */
  static async loadByUsage(context: Context): Promise<SearchKeyword[]> {
    const all = await SearchKeywordRepository.loadAll(context);
    const sorted = all.slice();
    sorted.sort((left: SearchKeyword, right: SearchKeyword) => right.usage - left.usage);
    return sorted;
  }

  /** 按关键字模糊查（对齐上游 flowSearch 的 `word like '%'||:key||'%'`，同样按 usage 倒序）。 */
  static async search(context: Context, key: string): Promise<SearchKeyword[]> {
    const needle = key.trim().toLowerCase();
    const all = await SearchKeywordRepository.loadAll(context);
    if (needle.length === 0) {
      return all;
    }
    const hits = all.filter((item: SearchKeyword) => item.word.toLowerCase().includes(needle));
    hits.sort((left: SearchKeyword, right: SearchKeyword) => right.usage - left.usage);
    return hits;
  }

  /**
   * 记录一次搜索：已存在则 usage+1 并刷新 lastUseTime，否则插入 usage=1。
   * 逐字对齐上游 `data/repository/SearchRepository.kt:76-93` 的 saveSearchKeyword。
   */
  static async saveKeyword(context: Context, keyword: string): Promise<void> {
    const word = keyword.trim();
    if (word.length === 0) {
      return;
    }
    const all = await SearchKeywordRepository.loadAll(context);
    const existing = all.find((item: SearchKeyword) => item.word === word);
    const next: SearchKeyword = existing === undefined
      ? { word: word, usage: 1, lastUseTime: Date.now() }
      : { word: word, usage: existing.usage + 1, lastUseTime: Date.now() };
    await SearchKeywordRepository.upsertOne(context, next);
  }

  /** 删除单个关键词（对齐上游 deleteSearchKeyword）。 */
  static async deleteKeyword(context: Context, keyword: string): Promise<void> {
    const operation = SearchKeywordRepository.saveQueue.then(async (): Promise<void> => {
      const store = await RdbStore.getStore(context);
      await RdbSchema.ensure(store);
      await store.executeSql('DELETE FROM `search_keywords` WHERE `word` = ?', [keyword]);
    });
    SearchKeywordRepository.saveQueue = operation.then((): void => {}, (_error: Error): void => {});
    return operation;
  }

  /** 清空全部关键词（对齐上游 clearSearchKeywords 的 deleteAll）。 */
  static async clearAll(context: Context): Promise<void> {
    const operation = SearchKeywordRepository.saveQueue.then(async (): Promise<void> => {
      const store = await RdbStore.getStore(context);
      await RdbSchema.ensure(store);
      await store.executeSql('DELETE FROM `search_keywords`');
    });
    SearchKeywordRepository.saveQueue = operation.then((): void => {}, (_error: Error): void => {});
    return operation;
  }

  /**
   * 恢复备份时批量写入。上游 Restore.kt:213-220 用 `insert(onConflict = REPLACE)`
   * 并逐条吞掉 `SQLiteConstraintException`，这里等价处理：整批包一个事务，
   * 单条失败只跳过该条，不影响其余关键词。
   */
  static async importKeywords(context: Context, incoming: SearchKeyword[]): Promise<number> {
    const valid = incoming.filter((item: SearchKeyword) => item.word.trim().length > 0);
    if (valid.length === 0) {
      return 0;
    }
    const operation = SearchKeywordRepository.saveQueue.then(async (): Promise<number> => {
      const store = await RdbStore.getStore(context);
      await RdbSchema.ensure(store);
      store.beginTransaction();
      try {
        for (let index = 0; index < valid.length; index++) {
          const item = valid[index];
          if (item === undefined) { continue; }
          try {
            await store.executeSql(SearchKeywordRepository.insertSql,
              [item.word, item.usage, item.lastUseTime]);
          } catch (error) {
            console.error(`搜索关键词写入跳过 ${item.word}：${error instanceof Error ? error.message : String(error)}`);
          }
        }
        store.commit();
      } catch (error) {
        store.rollBack();
        throw new Error(`搜索关键词导入失败：${error instanceof Error ? error.message : String(error)}`);
      }
      return valid.length;
    });
    SearchKeywordRepository.saveQueue = operation.then((): void => {}, (_error: Error): void => {});
    return operation;
  }

  /** 导出为上游同形的 JSON 数组，供备份写 searchHistory.json。 */
  static exportKeywords(keywords: SearchKeyword[]): string {
    if (keywords.length === 0) {
      return '[]';
    }
    const parts: string[] = keywords.map((item: SearchKeyword) => JSON.stringify(item));
    return `[\n${parts.join(',\n')}\n]`;
  }

  /** 解析备份里的 searchHistory.json；字段缺失按上游默认值补。 */
  static parseKeywords(text: string): SearchKeyword[] {
    const trimmed = text.trim();
    if (trimmed.length === 0) {
      return [];
    }
    let parsed: Object;
    try {
      parsed = JSON.parse(trimmed) as Object;
    } catch (error) {
      console.error(`搜索关键词解析失败：${error instanceof Error ? error.message : String(error)}`);
      return [];
    }
    if (!Array.isArray(parsed)) {
      return [];
    }
    const records: Object[] = parsed as Object[];
    const keywords: SearchKeyword[] = [];
    for (let index = 0; index < records.length; index++) {
      const record = records[index];
      if (record === null || record === undefined || typeof record !== 'object') {
        continue;
      }
      const row = record as Record<string, Object>;
      const wordValue = row['word'];
      const word = typeof wordValue === 'string' ? wordValue : '';
      if (word.trim().length === 0) {
        continue;
      }
      const usageValue = row['usage'];
      const usage = typeof usageValue === 'number' && Number.isFinite(usageValue) ? usageValue : 1;
      const timeValue = row['lastUseTime'];
      const lastUseTime = typeof timeValue === 'number' && Number.isFinite(timeValue) ? timeValue : Date.now();
      keywords.push({ word: word, usage: usage, lastUseTime: lastUseTime });
    }
    return keywords;
  }

  private static async upsertOne(context: Context, keyword: SearchKeyword): Promise<void> {
    const operation = SearchKeywordRepository.saveQueue.then(async (): Promise<void> => {
      const store = await RdbStore.getStore(context);
      await RdbSchema.ensure(store);
      await store.executeSql(SearchKeywordRepository.insertSql,
        [keyword.word, keyword.usage, keyword.lastUseTime]);
    });
    SearchKeywordRepository.saveQueue = operation.then((): void => {}, (_error: Error): void => {});
    return operation;
  }

  private static readAll(resultSet: relationalStore.ResultSet): SearchKeyword[] {
    const wordIndex = RdbCodec.column(resultSet, 'word');
    const usageIndex = RdbCodec.column(resultSet, 'usage');
    const lastUseTimeIndex = RdbCodec.column(resultSet, 'lastUseTime');
    const keywords: SearchKeyword[] = [];
    while (resultSet.goToNextRow()) {
      keywords.push({
        word: RdbCodec.text(resultSet, wordIndex),
        usage: RdbCodec.integer(resultSet, usageIndex),
        lastUseTime: RdbCodec.optionalInteger(resultSet, lastUseTimeIndex) ?? 0
      });
    }
    return keywords;
  }
}
