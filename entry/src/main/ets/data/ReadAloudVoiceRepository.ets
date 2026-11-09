import { relationalStore } from '@kit.ArkData';
import { ReadAloudVoice } from '../model/ReadAloudVoice';
import { RdbCodec } from './RdbCodec';
import { RdbStore } from './RdbStore';
import { RdbSchema } from './RdbSchema';

/** 批量导入结果，供恢复结果如实反馈新增与覆盖的条数。 */
export interface ReadAloudVoiceImportOutcome {
  added: number;
  updated: number;
  skipped: number;
}

/**
 * 朗读音色仓储，对齐上游 `read_aloud_voices` 表（Room 实体 ReadAloudSpeech.kt）。
 * 表按 engineType 区分引擎，'http' 即 model 里导出的 READ_ALOUD_VOICE_ENGINE_HTTP。
 * 库里可能已有别的引擎音色，所以恢复只重写 http 行，绝不 DELETE 全表。
 * 首次使用返回空集，不自动生成默认数据。
 */
export class ReadAloudVoiceRepository {
  private static readonly columns: string =
    '`id`, `engineType`, `engineId`, `speakerId`, `displayName`, `traitsJson`, ' +
    '`emotionCatalogJson`, `managedBy`, `enabled`, `available`, `excluded`, ' +
    '`revision`, `createdAt`, `updatedAt`';
  private static readonly selectAll: string =
    'SELECT ' + ReadAloudVoiceRepository.columns +
    ' FROM `read_aloud_voices` ORDER BY `displayName` COLLATE NOCASE ASC';
  /** 备份写出用：只取 http 行；孤儿音色（engineId 对不上现存源）不进新包。 */
  private static readonly selectHttp: string =
    'SELECT ' + ReadAloudVoiceRepository.columns +
    ' FROM `read_aloud_voices`' +
    ' WHERE `engineType` = \'http\'' +
    ' AND `engineId` IN (SELECT CAST(`id` AS TEXT) FROM `httpTTS`)' +
    ' ORDER BY `displayName` COLLATE NOCASE ASC';
  /** 合并恢复用：读全部 http 行（含孤儿），才能认出本地 excluded=1 的行。 */
  private static readonly selectHttpAll: string =
    'SELECT ' + ReadAloudVoiceRepository.columns +
    ' FROM `read_aloud_voices` WHERE `engineType` = \'http\'';
  private static readonly selectSourceIds: string = 'SELECT `id` FROM `httpTTS`';
  private static readonly insertSql: string =
    'INSERT OR REPLACE INTO `read_aloud_voices` (' + ReadAloudVoiceRepository.columns + ') ' +
    'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)';
  private static saveQueue: Promise<void> = Promise.resolve();
  private static cachedVoices: ReadAloudVoice[] = [];

  /** 从关系库读全表进缓存；读取失败时留空缓存，不让备份链路崩掉。 */
  static async load(context: Context): Promise<ReadAloudVoice[]> {
    let voices: ReadAloudVoice[] = [];
    try {
      const store = await RdbStore.getStore(context);
      await RdbSchema.ensure(store);
      voices = await ReadAloudVoiceRepository.readRows(store, ReadAloudVoiceRepository.selectAll);
    } catch (error) {
      console.error(`朗读音色读取失败：${error instanceof Error ? error.message : String(error)}`);
      voices = [];
    }
    ReadAloudVoiceRepository.cachedVoices = ReadAloudVoiceRepository.copyVoices(voices);
    return ReadAloudVoiceRepository.copyVoices(ReadAloudVoiceRepository.cachedVoices);
  }

  /** 取当前缓存快照；缓存只在 load() 后非空。 */
  static getAll(): ReadAloudVoice[] {
    return ReadAloudVoiceRepository.copyVoices(ReadAloudVoiceRepository.cachedVoices);
  }

  /**
   * 备份写出用：只取 engineType='http' 的行，按 displayName 不区分大小写排序。
   * excluded=1 的行必须读出来（导出要带上），这里不按 excluded 过滤；
   * 孤儿音色由 selectHttp 的子查询排除，避免新包里永远带着死源音色。
   */
  static async loadHttpVoices(context: Context): Promise<ReadAloudVoice[]> {
    let voices: ReadAloudVoice[] = [];
    try {
      const store = await RdbStore.getStore(context);
      await RdbSchema.ensure(store);
      voices = await ReadAloudVoiceRepository.readRows(store, ReadAloudVoiceRepository.selectHttp);
    } catch (error) {
      console.error(`http 音色读取失败：${error instanceof Error ? error.message : String(error)}`);
      voices = [];
    }
    ReadAloudVoiceRepository.cachedVoices = ReadAloudVoiceRepository.copyVoices(voices);
    return ReadAloudVoiceRepository.copyVoices(voices);
  }

  /** 导出为与上游同名的 JSON 数组；字段名逐字对齐实体，不含本地扩展字段。 */
  static exportVoices(voices: ReadAloudVoice[]): string {
    return JSON.stringify(voices, null, 2);
  }

  /** 合并导入：同 id 覆盖、其余新增，非法主键计 skipped 后跳过。 */
  static async importVoices(context: Context, incoming: ReadAloudVoice[]): Promise<ReadAloudVoiceImportOutcome> {
    const next: ReadAloudVoice[] = ReadAloudVoiceRepository.copyVoices(ReadAloudVoiceRepository.cachedVoices);
    let added = 0;
    let updated = 0;
    let skipped = 0;
    incoming.forEach((voice: ReadAloudVoice) => {
      if (!ReadAloudVoiceRepository.isVoice(voice)) {
        skipped += 1;
        return;
      }
      const existingIndex = next.findIndex((item: ReadAloudVoice) => item.id === voice.id);
      if (existingIndex >= 0) {
        next[existingIndex] = voice;
        updated += 1;
      } else {
        next.push(voice);
        added += 1;
      }
    });
    if (added === 0 && updated === 0) {
      return { added: added, updated: updated, skipped: skipped };
    }
    await ReadAloudVoiceRepository.save(context, next);
    return { added: added, updated: updated, skipped: skipped };
  }

  /** 整表写回：串行队列内 DELETE + 逐行 INSERT OR REPLACE，整体包在事务里。 */
  static save(context: Context, voices: ReadAloudVoice[]): Promise<ReadAloudVoice[]> {
    const operation = ReadAloudVoiceRepository.saveQueue.then(async (): Promise<ReadAloudVoice[]> => {
      const store = await RdbStore.getStore(context);
      await RdbSchema.ensure(store);
      store.beginTransaction();
      try {
        await ReadAloudVoiceRepository.replaceAll(store, voices);
        store.commit();
      } catch (error) {
        store.rollBack();
        // ArkTS 限制：catch 到的值类型不确定，不能直接 throw（arkts-limited-throw）。
        throw new Error(`朗读音色写入失败：${error instanceof Error ? error.message : String(error)}`);
      }
      ReadAloudVoiceRepository.cachedVoices = ReadAloudVoiceRepository.copyVoices(voices);
      return ReadAloudVoiceRepository.copyVoices(voices);
    });
    ReadAloudVoiceRepository.saveQueue = operation.then((): void => {}, (_error: Error): void => {});
    return operation;
  }

  /**
   * 恢复用：在事务里只重写 engineType='http' 的行。
   * 不能 DELETE 全表——库里可能已有别的引擎音色（系统 TTS / 云 TTS），全清会连带删掉。
   * 三条语义按上游 Restore.kt 与 ReadAloudVoiceEntity.excluded 注释：
   * ① 备份里有的音色覆盖；② 备份里缺席但本地 excluded=1 的行必须留着（不是删除，
   *    行必须留着，否则下次导入同一个源会把它当成新音色重新插回来）；
   * ③ engineId 已不在 httpTTS 表里的孤儿行不再写回，避免导出永远带着死源音色。
   */
  static replaceHttpVoices(context: Context, voices: ReadAloudVoice[]): Promise<void> {
    const operation = ReadAloudVoiceRepository.saveQueue.then(async (): Promise<void> => {
      const store = await RdbStore.getStore(context);
      await RdbSchema.ensure(store);
      store.beginTransaction();
      try {
        const existing = await ReadAloudVoiceRepository.readRows(store, ReadAloudVoiceRepository.selectHttpAll);
        const sourceIds = await ReadAloudVoiceRepository.readSourceIds(store);
        const incomingIds: string[] = [];
        const merged: ReadAloudVoice[] = [];
        voices.forEach((voice: ReadAloudVoice) => {
          if (!ReadAloudVoiceRepository.isVoice(voice)) { return; }
          if (incomingIds.indexOf(voice.id) >= 0) { return; }
          incomingIds.push(voice.id);
          merged.push(voice);
        });
        existing.forEach((local: ReadAloudVoice) => {
          if (local.excluded && incomingIds.indexOf(local.id) < 0) {
            merged.push(local);
          }
        });
        const finalRows = merged.filter((voice: ReadAloudVoice) => sourceIds.indexOf(voice.engineId) >= 0);
        await store.executeSql('DELETE FROM `read_aloud_voices` WHERE `engineType` = \'http\'');
        for (let index = 0; index < finalRows.length; index++) {
          const voice = finalRows[index];
          if (voice === undefined) { continue; }
          await store.executeSql(ReadAloudVoiceRepository.insertSql, [
            voice.id, voice.engineType, voice.engineId, voice.speakerId,
            voice.displayName, voice.traitsJson, voice.emotionCatalogJson,
            voice.managedBy, voice.enabled ? 1 : 0, voice.available ? 1 : 0,
            voice.excluded ? 1 : 0, voice.revision, voice.createdAt, voice.updatedAt
          ]);
        }
        store.commit();
      } catch (error) {
        store.rollBack();
        throw new Error(`http 音色写入失败：${error instanceof Error ? error.message : String(error)}`);
      }
      ReadAloudVoiceRepository.cachedVoices = [];
    });
    ReadAloudVoiceRepository.saveQueue = operation.then((): void => {}, (_error: Error): void => {});
    return operation;
  }

  /** 在调用方给定的事务里整表重写；不 commit、不回滚。仅供 save() 内部使用。 */
  private static async replaceAll(store: relationalStore.RdbStore, voices: ReadAloudVoice[]): Promise<void> {
    await store.executeSql('DELETE FROM `read_aloud_voices`');
    for (let index = 0; index < voices.length; index++) {
      const voice = voices[index];
      if (voice === undefined) { continue; }
      await store.executeSql(ReadAloudVoiceRepository.insertSql, [
        voice.id, voice.engineType, voice.engineId, voice.speakerId,
        voice.displayName, voice.traitsJson, voice.emotionCatalogJson,
        voice.managedBy, voice.enabled ? 1 : 0, voice.available ? 1 : 0,
        voice.excluded ? 1 : 0, voice.revision, voice.createdAt, voice.updatedAt
      ]);
    }
  }

  private static async readRows(store: relationalStore.RdbStore, sql: string): Promise<ReadAloudVoice[]> {
    const resultSet = await store.querySql(sql);
    try {
      return ReadAloudVoiceRepository.readAll(resultSet);
    } finally {
      resultSet.close();
    }
  }

  /** 读 httpTTS 的 id 集合，转成字符串后与 read_aloud_voices.engineId（TEXT）比较。 */
  private static async readSourceIds(store: relationalStore.RdbStore): Promise<string[]> {
    const resultSet = await store.querySql(ReadAloudVoiceRepository.selectSourceIds);
    const ids: string[] = [];
    try {
      const idIndex = RdbCodec.column(resultSet, 'id');
      while (resultSet.goToNextRow()) {
        ids.push(String(RdbCodec.integer(resultSet, idIndex)));
      }
    } finally {
      resultSet.close();
    }
    return ids;
  }

  /** 从结果集读出全部音色；列顺序与 columns 一致。 */
  private static readAll(resultSet: relationalStore.ResultSet): ReadAloudVoice[] {
    const idIndex = RdbCodec.column(resultSet, 'id');
    const engineTypeIndex = RdbCodec.column(resultSet, 'engineType');
    const engineIdIndex = RdbCodec.column(resultSet, 'engineId');
    const speakerIdIndex = RdbCodec.column(resultSet, 'speakerId');
    const displayNameIndex = RdbCodec.column(resultSet, 'displayName');
    const traitsJsonIndex = RdbCodec.column(resultSet, 'traitsJson');
    const emotionCatalogJsonIndex = RdbCodec.column(resultSet, 'emotionCatalogJson');
    const managedByIndex = RdbCodec.column(resultSet, 'managedBy');
    const enabledIndex = RdbCodec.column(resultSet, 'enabled');
    const availableIndex = RdbCodec.column(resultSet, 'available');
    const excludedIndex = RdbCodec.column(resultSet, 'excluded');
    const revisionIndex = RdbCodec.column(resultSet, 'revision');
    const createdAtIndex = RdbCodec.column(resultSet, 'createdAt');
    const updatedAtIndex = RdbCodec.column(resultSet, 'updatedAt');
    const voices: ReadAloudVoice[] = [];
    while (resultSet.goToNextRow()) {
      const voice: ReadAloudVoice = {
        id: RdbCodec.text(resultSet, idIndex),
        engineType: RdbCodec.text(resultSet, engineTypeIndex),
        engineId: RdbCodec.text(resultSet, engineIdIndex),
        speakerId: RdbCodec.text(resultSet, speakerIdIndex),
        displayName: RdbCodec.text(resultSet, displayNameIndex),
        traitsJson: RdbCodec.text(resultSet, traitsJsonIndex),
        emotionCatalogJson: RdbCodec.text(resultSet, emotionCatalogJsonIndex),
        managedBy: RdbCodec.text(resultSet, managedByIndex),
        enabled: RdbCodec.boolean(resultSet, enabledIndex, true),
        available: RdbCodec.boolean(resultSet, availableIndex, true),
        excluded: RdbCodec.boolean(resultSet, excludedIndex, false),
        revision: RdbCodec.integer(resultSet, revisionIndex),
        createdAt: RdbCodec.integer(resultSet, createdAtIndex),
        updatedAt: RdbCodec.integer(resultSet, updatedAtIndex)
      };
      voices.push(voice);
    }
    return voices;
  }

  private static copyVoice(voice: ReadAloudVoice): ReadAloudVoice {
    return {
      id: voice.id,
      engineType: voice.engineType,
      engineId: voice.engineId,
      speakerId: voice.speakerId,
      displayName: voice.displayName,
      traitsJson: voice.traitsJson,
      emotionCatalogJson: voice.emotionCatalogJson,
      managedBy: voice.managedBy,
      enabled: voice.enabled,
      available: voice.available,
      excluded: voice.excluded,
      revision: voice.revision,
      createdAt: voice.createdAt,
      updatedAt: voice.updatedAt
    };
  }

  private static copyVoices(voices: ReadAloudVoice[]): ReadAloudVoice[] {
    return voices.map((voice: ReadAloudVoice) => ReadAloudVoiceRepository.copyVoice(voice));
  }

  private static isVoice(value: ReadAloudVoice): boolean {
    return value !== null && value !== undefined && typeof value === 'object' &&
      typeof value.id === 'string' && value.id.length > 0 &&
      typeof value.engineType === 'string' && value.engineType.length > 0;
  }
}
