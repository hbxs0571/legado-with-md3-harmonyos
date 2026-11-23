import { relationalStore } from '@kit.ArkData';
import { HttpTts } from '../model/HttpTts';
import { ReadAloudVoice, READ_ALOUD_VOICE_ENGINE_HTTP } from '../model/ReadAloudVoice';
import { RdbCodec } from './RdbCodec';
import { RdbStore } from './RdbStore';
import { RdbSchema } from './RdbSchema';
import { HttpTtsCatalogDraft } from './HttpTtsImporter';
import { HttpTtsCatalogSync } from './HttpTtsCatalogSync';
import { ReadAloudVoiceRepository } from './ReadAloudVoiceRepository';

/** 批量导入结果，供恢复结果如实反馈新增与覆盖的条数。 */
export interface HttpTtsImportOutcome {
  added: number;
  updated: number;
  skipped: number;
}

/** 恢复时的一条「源 + 它自带的目录草稿」，对应上游 `Pair<HttpTTS, HttpTtsCatalogDraft>`。 */
export interface HttpTtsCatalogEntry {
  source: HttpTts;
  draft: HttpTtsCatalogDraft;
}

/**
 * 在线朗读源仓储，对齐上游 `httpTTS` 表（Room 实体 HttpTTS.kt）。
 * 首次使用返回空集，不自动生成内置默认源；load() 把整表读进缓存，
 * getAll() 同步读缓存，写操作落库后更新缓存。
 * 采用合并导入语义：同 id 覆盖、其余新增，本地独有条目保留，
 * 避免「恢复一份旧备份就把新数据删光」。
 */
export class HttpTtsRepository {
  private static readonly selectAll: string =
    'SELECT `id`, `name`, `url`, `contentType`, `concurrentRate`, `loginUrl`, `loginUi`, ' +
    '`header`, `jsLib`, `enabledCookieJar`, `loginCheckJs`, `speed`, ' +
    '`synthesisThreadCount`, `lastUpdateTime`, `textParam`, `speedParam`, `toneParam` ' +
    'FROM `httpTTS` ORDER BY `name` ASC';
  private static readonly insertSql: string =
    'INSERT OR REPLACE INTO `httpTTS` ' +
    '(`id`, `name`, `url`, `contentType`, `concurrentRate`, `loginUrl`, `loginUi`, ' +
    '`header`, `jsLib`, `enabledCookieJar`, `loginCheckJs`, `speed`, ' +
    '`synthesisThreadCount`, `lastUpdateTime`, `textParam`, `speedParam`, `toneParam`) ' +
    'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)';
  private static saveQueue: Promise<void> = Promise.resolve();
  private static cachedSources: HttpTts[] = [];

  /** 从关系库读全表进缓存；读取失败时留空缓存，不让备份链路崩掉。 */
  static async load(context: Context): Promise<HttpTts[]> {
    let sources: HttpTts[] = [];
    try {
      const store = await RdbStore.getStore(context);
      await RdbSchema.ensure(store);
      const resultSet = await store.querySql(HttpTtsRepository.selectAll);
      try {
        sources = HttpTtsRepository.readAll(resultSet);
      } finally {
        resultSet.close();
      }
    } catch (error) {
      console.error(`在线朗读源读取失败：${error instanceof Error ? error.message : String(error)}`);
      sources = [];
    }
    HttpTtsRepository.cachedSources = HttpTtsRepository.copySources(sources);
    return HttpTtsRepository.copySources(HttpTtsRepository.cachedSources);
  }

  /** 取当前缓存快照，供备份与界面同步读取；缓存只在 load() 后非空。 */
  static getAll(): HttpTts[] {
    return HttpTtsRepository.copySources(HttpTtsRepository.cachedSources);
  }

  /**
   * 导出为与上游同名的 JSON 数组；字段名逐字对齐实体，不含本地扩展字段。
   * textParam/speedParam/toneParam 是本地扩展列，上游实体没有，绝不写进 httpTTS.json
   * （否则上游读到未知字段可能报错）；用显式字段构造，可选扩展字段不赋值，
   * JSON.stringify 会跳过 undefined 值。
   */
  static exportSources(sources: HttpTts[]): string {
    const exported: HttpTts[] = sources.map((source: HttpTts): HttpTts => ({
      id: source.id,
      name: source.name,
      url: source.url,
      contentType: source.contentType,
      concurrentRate: source.concurrentRate,
      loginUrl: source.loginUrl,
      loginUi: source.loginUi,
      header: source.header,
      jsLib: source.jsLib,
      enabledCookieJar: source.enabledCookieJar,
      loginCheckJs: source.loginCheckJs,
      speed: source.speed,
      synthesisThreadCount: source.synthesisThreadCount,
      lastUpdateTime: source.lastUpdateTime
    }));
    return JSON.stringify(exported, null, 2);
  }

  /** 合并导入：同 id 覆盖、其余新增，非法主键计 skipped 后跳过。 */
  static async importSources(context: Context, incoming: HttpTts[]): Promise<HttpTtsImportOutcome> {
    const next: HttpTts[] = HttpTtsRepository.copySources(HttpTtsRepository.cachedSources);
    let added = 0;
    let updated = 0;
    let skipped = 0;
    incoming.forEach((source: HttpTts) => {
      if (!HttpTtsRepository.isSource(source)) {
        skipped += 1;
        return;
      }
      const existingIndex = next.findIndex((item: HttpTts) => item.id === source.id);
      if (existingIndex >= 0) {
        next[existingIndex] = source;
        updated += 1;
      } else {
        next.push(source);
        added += 1;
      }
    });
    if (added === 0 && updated === 0) {
      return { added: added, updated: updated, skipped: skipped };
    }
    await HttpTtsRepository.save(context, next);
    return { added: added, updated: updated, skipped: skipped };
  }

  /** 整表写回：串行队列内 DELETE + 逐行 INSERT OR REPLACE，整体包在事务里。 */
  static save(context: Context, sources: HttpTts[]): Promise<HttpTts[]> {
    const operation = HttpTtsRepository.saveQueue.then(async (): Promise<HttpTts[]> => {
      const store = await RdbStore.getStore(context);
      await RdbSchema.ensure(store);
      store.beginTransaction();
      try {
        await HttpTtsRepository.replaceAll(store, sources);
        store.commit();
      } catch (error) {
        store.rollBack();
        // ArkTS 限制：catch 到的值类型不确定，不能直接 throw（arkts-limited-throw）。
        throw new Error(`在线朗读源写入失败：${error instanceof Error ? error.message : String(error)}`);
      }
      HttpTtsRepository.cachedSources = HttpTtsRepository.copySources(sources);
      return HttpTtsRepository.copySources(sources);
    });
    HttpTtsRepository.saveQueue = operation.then((): void => {}, (_error: Error): void => {});
    return operation;
  }

  /**
   * 恢复 httpTTS：源与它自带的目录在同一个事务里落库，音色快照随后覆盖，最后清孤儿。
   *
   * 对应上游 `HttpTtsRepository.kt:79-94 restore`：
   *  - `importWithCatalogs` 逐条写源并同步目录（`SyncHttpTtsCatalogUseCase`）；
   *  - `voices` 非 null 时，先把这些引擎下的音色整批删掉再写备份里的行（备份是本机状态的权威副本）；
   *  - 末尾 `deleteOrphanedHttpVoices` 清掉 engineId 已不在 httpTTS 表里的孤儿。
   *
   * `voices` 传 undefined 表示「旧备份没保存音色」：此时不动音色表，只靠目录同步结果
   * （上游 `Restore.kt:583-586` 用 `voicesFile.exists()` 区分这两种情况）。
   */
  static restoreWithCatalogs(context: Context, entries: HttpTtsCatalogEntry[],
    voices: ReadAloudVoice[] | undefined): Promise<HttpTts[]> {
    const operation = HttpTtsRepository.saveQueue.then(async (): Promise<HttpTts[]> => {
      const store = await RdbStore.getStore(context);
      await RdbSchema.ensure(store);
      const merged: HttpTts[] = HttpTtsRepository.copySources(HttpTtsRepository.cachedSources);
      store.beginTransaction();
      try {
        for (let index = 0; index < entries.length; index++) {
          const entry = entries[index];
          if (entry === undefined) { continue; }
          const source = entry.source;
          if (!HttpTtsRepository.isSource(source)) { continue; }
          await store.executeSql(HttpTtsRepository.insertSql, HttpTtsRepository.sourceArgs(source));
          // 目录与源同一事务：中途失败整体回滚，不会留下「源在、目录半截」的状态
          await HttpTtsCatalogSync.syncCatalog(store, String(source.id), entry.draft, source.lastUpdateTime);
          let replaced = false;
          for (let cursor = 0; cursor < merged.length; cursor++) {
            if (merged[cursor].id === source.id) {
              merged[cursor] = source;
              replaced = true;
              break;
            }
          }
          if (!replaced) {
            merged.push(source);
          }
        }
        if (voices !== undefined) {
          for (let index = 0; index < entries.length; index++) {
            const entry = entries[index];
            if (entry === undefined) { continue; }
            await store.executeSql(ReadAloudVoiceRepository.deleteHttpVoicesSql, [String(entry.source.id)]);
          }
          for (let index = 0; index < voices.length; index++) {
            const voice = voices[index];
            if (voice === undefined) { continue; }
            if (voice.engineType !== READ_ALOUD_VOICE_ENGINE_HTTP) { continue; }
            await ReadAloudVoiceRepository.insertVoice(store, voice);
          }
        }
        await store.executeSql(ReadAloudVoiceRepository.deleteOrphanedHttp);
        store.commit();
      } catch (error) {
        store.rollBack();
        // ArkTS 限制：catch 到的值类型不确定，不能直接 throw（arkts-limited-throw）。
        throw new Error(`在线朗读源恢复失败：${error instanceof Error ? error.message : String(error)}`);
      }
      HttpTtsRepository.cachedSources = HttpTtsRepository.copySources(merged);
      return HttpTtsRepository.copySources(merged);
    });
    HttpTtsRepository.saveQueue = operation.then((): void => {}, (_error: Error): void => {});
    return operation;
  }

  /** 在调用方给定的事务里整表重写；不 commit、不回滚。 */
  private static async replaceAll(store: relationalStore.RdbStore, sources: HttpTts[]): Promise<void> {
    await store.executeSql('DELETE FROM `httpTTS`');
    for (let index = 0; index < sources.length; index++) {
      const source = sources[index];
      if (source === undefined) { continue; }
      await store.executeSql(HttpTtsRepository.insertSql, HttpTtsRepository.sourceArgs(source));
    }
  }

  /** insertSql 的 17 个绑定值；整表重写与单条写入共用，避免两处列顺序漂移。 */
  private static sourceArgs(source: HttpTts): relationalStore.ValueType[] {
    return [
      source.id,
      source.name,
      source.url,
      source.contentType === undefined ? null : source.contentType,
      source.concurrentRate === undefined ? null : source.concurrentRate,
      source.loginUrl === undefined ? null : source.loginUrl,
      source.loginUi === undefined ? null : source.loginUi,
      source.header === undefined ? null : source.header,
      source.jsLib === undefined ? null : source.jsLib,
      // 上游 enabledCookieJar 是 Boolean?，本地列 NOT NULL DEFAULT 0，
      // 所以缺省写 0 而不是 null，读回得到 false。
      source.enabledCookieJar === undefined ? 0 : (source.enabledCookieJar ? 1 : 0),
      source.loginCheckJs === undefined ? null : source.loginCheckJs,
      source.speed === undefined ? null : source.speed,
      source.synthesisThreadCount,
      source.lastUpdateTime,
      source.textParam === undefined ? 'text' : source.textParam,
      source.speedParam === undefined ? 'speed' : source.speedParam,
      source.toneParam === undefined ? 'tone' : source.toneParam
    ];
  }

  /** 从结果集读出全部源；列顺序与 selectAll 一致。 */
  private static readAll(resultSet: relationalStore.ResultSet): HttpTts[] {
    const idIndex = RdbCodec.column(resultSet, 'id');
    const nameIndex = RdbCodec.column(resultSet, 'name');
    const urlIndex = RdbCodec.column(resultSet, 'url');
    const contentTypeIndex = RdbCodec.column(resultSet, 'contentType');
    const concurrentRateIndex = RdbCodec.column(resultSet, 'concurrentRate');
    const loginUrlIndex = RdbCodec.column(resultSet, 'loginUrl');
    const loginUiIndex = RdbCodec.column(resultSet, 'loginUi');
    const headerIndex = RdbCodec.column(resultSet, 'header');
    const jsLibIndex = RdbCodec.column(resultSet, 'jsLib');
    const enabledCookieJarIndex = RdbCodec.column(resultSet, 'enabledCookieJar');
    const loginCheckJsIndex = RdbCodec.column(resultSet, 'loginCheckJs');
    const speedIndex = RdbCodec.column(resultSet, 'speed');
    const synthesisThreadCountIndex = RdbCodec.column(resultSet, 'synthesisThreadCount');
    const lastUpdateTimeIndex = RdbCodec.column(resultSet, 'lastUpdateTime');
    const textParamIndex = RdbCodec.column(resultSet, 'textParam');
    const speedParamIndex = RdbCodec.column(resultSet, 'speedParam');
    const toneParamIndex = RdbCodec.column(resultSet, 'toneParam');
    const sources: HttpTts[] = [];
    while (resultSet.goToNextRow()) {
      const source: HttpTts = {
        id: RdbCodec.integer(resultSet, idIndex),
        name: RdbCodec.text(resultSet, nameIndex),
        url: RdbCodec.text(resultSet, urlIndex),
        contentType: RdbCodec.optionalText(resultSet, contentTypeIndex),
        concurrentRate: RdbCodec.optionalText(resultSet, concurrentRateIndex),
        loginUrl: RdbCodec.optionalText(resultSet, loginUrlIndex),
        loginUi: RdbCodec.optionalText(resultSet, loginUiIndex),
        header: RdbCodec.optionalText(resultSet, headerIndex),
        jsLib: RdbCodec.optionalText(resultSet, jsLibIndex),
        enabledCookieJar: RdbCodec.boolean(resultSet, enabledCookieJarIndex, false),
        loginCheckJs: RdbCodec.optionalText(resultSet, loginCheckJsIndex),
        speed: RdbCodec.optionalInteger(resultSet, speedIndex),
        synthesisThreadCount: RdbCodec.integer(resultSet, synthesisThreadCountIndex, 1),
        lastUpdateTime: RdbCodec.integer(resultSet, lastUpdateTimeIndex),
        textParam: RdbCodec.text(resultSet, textParamIndex, 'text'),
        speedParam: RdbCodec.text(resultSet, speedParamIndex, 'speed'),
        toneParam: RdbCodec.text(resultSet, toneParamIndex, 'tone')
      };
      sources.push(source);
    }
    return sources;
  }

  private static copySource(source: HttpTts): HttpTts {
    return {
      id: source.id,
      name: source.name,
      url: source.url,
      contentType: source.contentType,
      concurrentRate: source.concurrentRate,
      loginUrl: source.loginUrl,
      loginUi: source.loginUi,
      header: source.header,
      jsLib: source.jsLib,
      enabledCookieJar: source.enabledCookieJar,
      loginCheckJs: source.loginCheckJs,
      speed: source.speed,
      synthesisThreadCount: source.synthesisThreadCount,
      lastUpdateTime: source.lastUpdateTime,
      textParam: source.textParam,
      speedParam: source.speedParam,
      toneParam: source.toneParam
    };
  }

  private static copySources(sources: HttpTts[]): HttpTts[] {
    return sources.map((source: HttpTts) => HttpTtsRepository.copySource(source));
  }

  private static isSource(value: HttpTts): boolean {
    return value !== null && value !== undefined && typeof value === 'object' &&
      typeof value.id === 'number' && value.id !== 0 &&
      typeof value.name === 'string' && value.name.length > 0;
  }
}
