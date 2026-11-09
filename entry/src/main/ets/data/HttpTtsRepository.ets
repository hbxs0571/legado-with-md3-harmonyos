import { relationalStore } from '@kit.ArkData';
import { HttpTts } from '../model/HttpTts';
import { RdbCodec } from './RdbCodec';
import { RdbStore } from './RdbStore';
import { RdbSchema } from './RdbSchema';

/** 批量导入结果，供恢复结果如实反馈新增与覆盖的条数。 */
export interface HttpTtsImportOutcome {
  added: number;
  updated: number;
  skipped: number;
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
    '`synthesisThreadCount`, `lastUpdateTime` ' +
    'FROM `httpTTS` ORDER BY `name` ASC';
  private static readonly insertSql: string =
    'INSERT OR REPLACE INTO `httpTTS` ' +
    '(`id`, `name`, `url`, `contentType`, `concurrentRate`, `loginUrl`, `loginUi`, ' +
    '`header`, `jsLib`, `enabledCookieJar`, `loginCheckJs`, `speed`, ' +
    '`synthesisThreadCount`, `lastUpdateTime`) ' +
    'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)';
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

  /** 导出为与上游同名的 JSON 数组；字段名逐字对齐实体，不含本地扩展字段。 */
  static exportSources(sources: HttpTts[]): string {
    return JSON.stringify(sources, null, 2);
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

  /** 在调用方给定的事务里整表重写；不 commit、不回滚。 */
  private static async replaceAll(store: relationalStore.RdbStore, sources: HttpTts[]): Promise<void> {
    await store.executeSql('DELETE FROM `httpTTS`');
    for (let index = 0; index < sources.length; index++) {
      const source = sources[index];
      if (source === undefined) { continue; }
      await store.executeSql(HttpTtsRepository.insertSql, [
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
        source.lastUpdateTime
      ]);
    }
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
        lastUpdateTime: RdbCodec.integer(resultSet, lastUpdateTimeIndex)
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
      lastUpdateTime: source.lastUpdateTime
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
