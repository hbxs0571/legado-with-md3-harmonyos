import { relationalStore } from '@kit.ArkData';
import { util } from '@kit.ArkTS';
import { RdbCodec } from './RdbCodec';
import { RdbSchema } from './RdbSchema';
import { RdbStore } from './RdbStore';

/**
 * 书源/文本规则编辑页键盘快捷符号配置。
 *
 * 对齐上游 `io.legado.app.data.entities.KeyboardAssist`：主键是复合的 (type, key)，
 * 32 条默认数据是「书源规则语法符号的快捷插入串」（@css: / <js> / {{}} / ## …），
 * 不是键盘键码。灌库时机照 AppDatabase.kt:460-470：首次打开且表为空才灌，
 * 用 INSERT OR REPLACE，之后用户删空也不会再灌回来（与上游一致）。
 */
export interface KeyboardAssist {
  type: number;
  key: string;
  value: string;
  serialNo: number;
}

export class KeyboardAssistRepository {
  private static readonly selectAll: string =
    'SELECT `type`, `key`, `value`, `serialNo` FROM `keyboardAssists` ORDER BY `serialNo` ASC';
  private static readonly countAll: string = 'SELECT count(*) FROM `keyboardAssists`';
  private static readonly insertSql: string =
    'INSERT OR REPLACE INTO `keyboardAssists` (`type`, `key`, `value`, `serialNo`) VALUES (?, ?, ?, ?)';
  private static readonly clearSql: string = 'DELETE FROM `keyboardAssists`';
  /** 与 rawfile 读法一致（照 TxtTocRuleRepository.loadBuiltinRules）。 */
  private static readonly builtinPath: string = 'keyboardassist/builtin-assists.json';

  /**
   * 表为空时灌入内置 32 条默认符号；非空时一字不动。
   * 读 rawfile 或解析失败时只记日志、不阻断启动（上游 getOrThrow 在本地要降级，
   * 否则一份损坏的内置 JSON 会让整个 app 起不来）。
   */
  static async ensureDefaults(context: Context): Promise<void> {
    try {
      const store = await RdbStore.getStore(context);
      await RdbSchema.ensure(store);
      const resultSet = await store.querySql(KeyboardAssistRepository.countAll);
      let count: number = 0;
      try {
        if (resultSet.goToNextRow()) {
          count = RdbCodec.integer(resultSet, 0, 0);
        }
      } finally {
        resultSet.close();
      }
      if (count > 0) { return; }
      const builtin = KeyboardAssistRepository.loadBuiltin(context);
      if (builtin.length === 0) { return; }
      store.beginTransaction();
      try {
        for (let index = 0; index < builtin.length; index++) {
          const item = builtin[index];
          await store.executeSql(KeyboardAssistRepository.insertSql,
            [item.type, item.key, item.value, item.serialNo]);
        }
        store.commit();
      } catch (error) {
        store.rollBack();
        console.error(`快捷键映射默认数据灌入失败：${error instanceof Error ? error.message : String(error)}`);
      }
    } catch (error) {
      console.error(`快捷键映射默认数据检查失败：${error instanceof Error ? error.message : String(error)}`);
    }
  }

  /** 读打包在 rawfile 里的 32 条默认符号；上游 JSON 无 type 字段，这里补默认 0。 */
  static loadBuiltin(context: Context): KeyboardAssist[] {
    try {
      const bytes = context.resourceManager.getRawFileContentSync(KeyboardAssistRepository.builtinPath);
      const text = new util.TextDecoder('utf-8').decodeToString(bytes);
      const raw: RawKeyboardAssist[] = JSON.parse(text);
      const result: KeyboardAssist[] = [];
      for (let index = 0; index < raw.length; index++) {
        const item = raw[index];
        if (item === undefined || typeof item.key !== 'string' || typeof item.value !== 'string') { continue; }
        result.push({
          type: typeof item.type === 'number' ? item.type : 0,
          key: item.key,
          value: item.value,
          serialNo: typeof item.serialNo === 'number' ? item.serialNo : index
        });
      }
      return result;
    } catch (_) {
      return [];
    }
  }

  /** 按 serialNo 升序读全表；读取失败时返回空数组，不让备份/界面链路崩掉。 */
  static async loadAll(context: Context): Promise<KeyboardAssist[]> {
    try {
      const store = await RdbStore.getStore(context);
      await RdbSchema.ensure(store);
      const resultSet = await store.querySql(KeyboardAssistRepository.selectAll);
      const result: KeyboardAssist[] = [];
      try {
        const typeIndex = RdbCodec.column(resultSet, 'type');
        const keyIndex = RdbCodec.column(resultSet, 'key');
        const valueIndex = RdbCodec.column(resultSet, 'value');
        const serialIndex = RdbCodec.column(resultSet, 'serialNo');
        while (resultSet.goToNextRow()) {
          result.push({
            type: RdbCodec.integer(resultSet, typeIndex, 0),
            key: RdbCodec.text(resultSet, keyIndex),
            value: RdbCodec.text(resultSet, valueIndex),
            serialNo: RdbCodec.integer(resultSet, serialIndex, 0)
          });
        }
      } finally {
        resultSet.close();
      }
      return result;
    } catch (error) {
      console.error(`快捷键映射读取失败：${error instanceof Error ? error.message : String(error)}`);
      return [];
    }
  }

  /** 清表后逐条 upsert（:382 恢复语义，对齐主键 (type,key)）。 */
  static async replaceAll(context: Context, items: KeyboardAssist[]): Promise<number> {
    const store = await RdbStore.getStore(context);
    await RdbSchema.ensure(store);
    store.beginTransaction();
    try {
      await store.executeSql(KeyboardAssistRepository.clearSql);
      for (let index = 0; index < items.length; index++) {
        const item = items[index];
        await store.executeSql(KeyboardAssistRepository.insertSql,
          [item.type, item.key, item.value, item.serialNo]);
      }
      store.commit();
      return items.length;
    } catch (error) {
      store.rollBack();
      throw new Error(`快捷键映射恢复失败：${error instanceof Error ? error.message : String(error)}`);
    }
  }
}

interface RawKeyboardAssist {
  type?: number;
  key?: string;
  value?: string;
  serialNo?: number;
}
