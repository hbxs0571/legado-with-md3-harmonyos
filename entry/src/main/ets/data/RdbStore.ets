import { relationalStore } from '@kit.ArkData';
import { RdbSchema } from './RdbSchema';

/**
 * 关系型数据库单例入口。
 *
 * 全工程只从这里取 RdbStore，避免多处 getRdbStore 打开同一个库
 * （SDK 注释明确 getRdbStore 不支持多线程并发打开）。
 *
 * 打开流程里必须做 setLocale('zh')：
 * relationalStore 的中文排序规则名是 LOCALES（不是 SQLite 文档写的 LOCALIZED），
 * 且未设 locale 时 `ORDER BY x COLLATE LOCALES` 不报错但返回空结果集。
 * 那种静默失败会让界面显示「没有数据」，用户以为数据丢了，比报错更难查。
 */
export class RdbStore {
  /** 库文件名，落在 context.databaseDir 下。 */
  private static readonly storeName: string = 'legado.db';
  /** 打开中的 Promise，并发调用共享同一个，避免重复开库。 */
  private static opening: Promise<relationalStore.RdbStore> | null = null;
  /** 已打开的实例。 */
  private static opened: relationalStore.RdbStore | null = null;

  /** 取库实例；首次调用时打开、设 locale、建表。 */
  static getStore(context: Context): Promise<relationalStore.RdbStore> {
    if (RdbStore.opened !== null) {
      return Promise.resolve(RdbStore.opened);
    }
    if (RdbStore.opening !== null) {
      return RdbStore.opening;
    }
    const opening = RdbStore.open(context);
    RdbStore.opening = opening;
    return opening;
  }

  private static async open(context: Context): Promise<relationalStore.RdbStore> {
    try {
      const store = await relationalStore.getRdbStore(context, {
        name: RdbStore.storeName,
        securityLevel: relationalStore.SecurityLevel.S2
      });
      // 必须先设 locale，否则 COLLATE LOCALES 会静默返回空结果集
      await store.setLocale('zh');
      await RdbSchema.ensure(store);
      RdbStore.opened = store;
      return store;
    } finally {
      // 无论成败都清掉 opening，失败后允许重试
      RdbStore.opening = null;
    }
  }
}
