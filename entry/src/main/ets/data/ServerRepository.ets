import { relationalStore } from '@kit.ArkData';
import { Server } from '../model/Server';
import { RdbCodec } from './RdbCodec';
import { RdbStore } from './RdbStore';
import { RdbSchema } from './RdbSchema';

/** 批量导入结果，供界面如实反馈新增、覆盖与跳过的条数。 */
export interface ServerImportOutcome {
  added: number;
  updated: number;
  skipped: number;
}

/** parseServers 的解析结果；skipped 记录无法解析成合法条目的数量。 */
export interface ServerParseOutcome {
  servers: Server[];
  skipped: number;
}

/** 单条原始服务器配置；字段全部可选，兼容不同来源的缺省。config 为 null 时不写入该字段。 */
interface RawServer {
  id?: number;
  name?: string;
  type?: number;
  config?: string;
  sortNumber?: number;
}

/**
 * 服务器配置仓储，对齐上游 `servers` 表（Room 实体 Server.kt）。
 * 整份照 BookSourceRepository 范式：sourceJson 存整条 JSON 原文做往返真值，
 * 前面几列是派生列，只供 SQL 排序与筛选。
 * 采用合并导入语义：同主键（id）覆盖、其余新增，本地独有条目保留。
 *
 * 注意：本仓储只服务备份包里 servers.json 的读写，WebDAV 客户端的账号密码
 * 存于 WebDavConfigStore（preferences），读路径不经过本仓储。
 */
export class ServerRepository {
  private static readonly selectAll: string =
    'SELECT `id`, `name`, `type`, `config`, `sortNumber`, `sourceJson` ' +
    'FROM `servers` ORDER BY `sortNumber` ASC, `id` ASC';
  private static readonly insertSql: string =
    'INSERT OR REPLACE INTO `servers` ' +
    '(`id`, `name`, `type`, `config`, `sortNumber`, `sourceJson`) ' +
    'VALUES (?, ?, ?, ?, ?, ?)';
  private static saveQueue: Promise<void> = Promise.resolve();
  private static cachedServers: Server[] = [];

  /** 从关系库读全表进缓存；读取失败时留空缓存，不让备份链路崩掉。 */
  static async load(context: Context): Promise<Server[]> {
    let servers: Server[] = [];
    try {
      const store = await RdbStore.getStore(context);
      await RdbSchema.ensure(store);
      const resultSet = await store.querySql(ServerRepository.selectAll);
      try {
        servers = ServerRepository.readAll(resultSet);
      } finally {
        resultSet.close();
      }
    } catch (error) {
      console.error(`服务器配置读取失败：${error instanceof Error ? error.message : String(error)}`);
      servers = [];
    }
    ServerRepository.cachedServers = ServerRepository.copyServers(servers);
    return ServerRepository.copyServers(ServerRepository.cachedServers);
  }

  /** 取当前缓存快照，供备份与界面同步读取；缓存只在 load() 后非空。 */
  static getAll(): Server[] {
    return ServerRepository.copyServers(ServerRepository.cachedServers);
  }

  /**
   * 导出为与上游同形的 JSON 数组，直接把每行的 sourceJson 拼起来，绝不二次 stringify。
   * 与 BookSourceRepository.exportRules 的差异：这里导出前对每行做一次 JSON.parse 校验，
   * 历史上出现过手工改库/旧版本写入的脏数据，跳过坏行比把坏 JSON 拼进备份包、
   * 让 Android 端整份解析失败要好。
   */
  static exportServers(servers: Server[]): string {
    if (servers.length === 0) { return '[]'; }
    const parts: string[] = [];
    for (let index = 0; index < servers.length; index++) {
      const server = servers[index];
      if (server === undefined) { continue; }
      const text = server.sourceJson.trim();
      if (text.length === 0) { continue; }
      try {
        JSON.parse(text);
      } catch (_) {
        continue;
      }
      parts.push(text);
    }
    if (parts.length === 0) { return '[]'; }
    return `[\n${parts.join(',\n')}\n]`;
  }

  /**
   * 解析 servers.json 的明文（可能是 JSON 数组或单个对象）。
   * 与 RuleSubImporter 同构，但 id 缺失时不能只取 Date.now()：同一毫秒内多条
   * 会撞主键、被 INSERT OR REPLACE 顶掉，故用 assignedIds 保证同批不重。
   */
  static parseServers(text: string): ServerParseOutcome {
    const trimmed = text.trim();
    if (trimmed.length === 0) {
      return { servers: [], skipped: 1 };
    }
    try {
      if (trimmed.startsWith('[')) {
        const items: RawServer[] = JSON.parse(trimmed);
        if (!Array.isArray(items)) {
          return { servers: [], skipped: 1 };
        }
        const servers: Server[] = [];
        const assignedIds: number[] = [];
        let skipped = 0;
        items.forEach((item: RawServer) => {
          const server = ServerRepository.toServer(item, assignedIds);
          if (server === undefined) {
            skipped += 1;
          } else {
            servers.push(server);
          }
        });
        return { servers: servers, skipped: skipped };
      }
      if (trimmed.startsWith('{')) {
        const single: RawServer = JSON.parse(trimmed);
        const server = ServerRepository.toServer(single, []);
        if (server === undefined) {
          return { servers: [], skipped: 1 };
        }
        return { servers: [server], skipped: 0 };
      }
    } catch (_) {
      // 落到下面统一按「格式不可识别」处理。
    }
    return { servers: [], skipped: 1 };
  }

  /** 把一条原始数据转换成服务器配置；不可序列化或形态不符时返回 undefined。 */
  private static toServer(raw: RawServer, assignedIds: number[]): Server | undefined {
    if (raw === undefined || raw === null || typeof raw !== 'object') {
      return undefined;
    }
    let sourceJson: string = '';
    try {
      sourceJson = JSON.stringify(raw);
    } catch (_) {
      return undefined;
    }
    let id = typeof raw.id === 'number' && Number.isFinite(raw.id) && raw.id > 0 ? raw.id : Date.now();
    while (assignedIds.includes(id)) {
      id += 1;
    }
    assignedIds.push(id);
    const server: Server = {
      id: id,
      name: typeof raw.name === 'string' ? raw.name : '',
      type: typeof raw.type === 'number' && Number.isFinite(raw.type) ? raw.type : 0,
      // config 是上游 String?，缺省必须是 undefined（入库写 null），不能给 ''。
      config: typeof raw.config === 'string' ? raw.config : undefined,
      sortNumber: typeof raw.sortNumber === 'number' && Number.isFinite(raw.sortNumber) ? raw.sortNumber : 0,
      sourceJson: sourceJson
    };
    return server;
  }

  /** 合并导入：同主键（id）覆盖、其余新增，非法主键计 skipped 后跳过。 */
  static async importServers(context: Context, incoming: Server[]): Promise<ServerImportOutcome> {
    const next: Server[] = ServerRepository.copyServers(ServerRepository.cachedServers);
    let added = 0;
    let updated = 0;
    let skipped = 0;
    incoming.forEach((server: Server) => {
      if (!ServerRepository.isServer(server)) {
        skipped += 1;
        return;
      }
      const existingIndex = next.findIndex((item: Server) => item.id === server.id);
      if (existingIndex >= 0) {
        next[existingIndex] = server;
        updated += 1;
      } else {
        next.push(server);
        added += 1;
      }
    });
    if (added === 0 && updated === 0) {
      return { added: added, updated: updated, skipped: skipped };
    }
    await ServerRepository.save(context, next);
    return { added: added, updated: updated, skipped: skipped };
  }

  /** 整表写回：串行队列内 DELETE + 逐行 INSERT OR REPLACE，整体包在事务里。 */
  static save(context: Context, servers: Server[]): Promise<Server[]> {
    const operation = ServerRepository.saveQueue.then(async (): Promise<Server[]> => {
      const store = await RdbStore.getStore(context);
      await RdbSchema.ensure(store);
      store.beginTransaction();
      try {
        await ServerRepository.replaceAll(store, servers);
        store.commit();
      } catch (error) {
        store.rollBack();
        // ArkTS 限制：catch 到的值类型不确定，不能直接 throw（arkts-limited-throw）。
        throw new Error(`服务器配置写入失败：${error instanceof Error ? error.message : String(error)}`);
      }
      ServerRepository.cachedServers = ServerRepository.copyServers(servers);
      return ServerRepository.copyServers(servers);
    });
    ServerRepository.saveQueue = operation.then((): void => {}, (_error: Error): void => {});
    return operation;
  }

  /** 在调用方给定的事务里整表重写；不 commit、不回滚。 */
  private static async replaceAll(store: relationalStore.RdbStore, servers: Server[]): Promise<void> {
    await store.executeSql('DELETE FROM `servers`');
    for (let index = 0; index < servers.length; index++) {
      const server = servers[index];
      if (server === undefined) { continue; }
      await store.executeSql(ServerRepository.insertSql, [
        server.id,
        server.name,
        server.type,
        server.config === undefined ? null : server.config,
        server.sortNumber,
        server.sourceJson
      ]);
    }
  }

  /** 从结果集读出全部配置；列顺序与 selectAll 一致。 */
  private static readAll(resultSet: relationalStore.ResultSet): Server[] {
    const idIndex = RdbCodec.column(resultSet, 'id');
    const nameIndex = RdbCodec.column(resultSet, 'name');
    const typeIndex = RdbCodec.column(resultSet, 'type');
    const configIndex = RdbCodec.column(resultSet, 'config');
    const sortNumberIndex = RdbCodec.column(resultSet, 'sortNumber');
    const sourceJsonIndex = RdbCodec.column(resultSet, 'sourceJson');
    const servers: Server[] = [];
    while (resultSet.goToNextRow()) {
      const server: Server = {
        id: RdbCodec.integer(resultSet, idIndex),
        name: RdbCodec.text(resultSet, nameIndex),
        type: RdbCodec.integer(resultSet, typeIndex),
        config: RdbCodec.optionalText(resultSet, configIndex),
        sortNumber: RdbCodec.integer(resultSet, sortNumberIndex),
        sourceJson: RdbCodec.text(resultSet, sourceJsonIndex)
      };
      servers.push(server);
    }
    return servers;
  }

  private static copyServer(server: Server): Server {
    return {
      id: server.id,
      name: server.name,
      type: server.type,
      config: server.config,
      sortNumber: server.sortNumber,
      sourceJson: server.sourceJson
    };
  }

  private static copyServers(servers: Server[]): Server[] {
    return servers.map((server: Server) => ServerRepository.copyServer(server));
  }

  private static isServer(value: Server): boolean {
    return value !== null && value !== undefined && typeof value === 'object' &&
      typeof value.id === 'number' && Number.isFinite(value.id) && value.id > 0;
  }
}
