import { preferences, relationalStore } from '@kit.ArkData';
import { RdbStore } from './RdbStore';
import { RdbSchema } from './RdbSchema';
import { ReaderBookmarkRepository } from './ReaderBookmarkRepository';
import { ReaderMarkingRepository } from './ReaderMarkingRepository';
import { ReaderSearchHistoryRepository } from './ReaderSearchHistoryRepository';
import { BookGroupRepository } from './BookGroupRepository';
import { ReaderHighlightRuleRepository } from './ReaderHighlightRuleRepository';
import { BookContentProcessRepository } from './BookContentProcessRepository';
import { TxtTocRuleRepository } from './TxtTocRuleRepository';
import { ReplaceRuleRepository } from './ReplaceRuleRepository';
import { BookRepository } from './BookRepository';
import { ReadRecordRepository } from './ReadRecordRepository';

/**
 * 存量数据搬迁骨架。
 *
 * 方案 a：首次启动时把 preferences 里的老数据搬进 DB，搬完写标记；
 * 之后每次启动只看标记，不重复搬。搬迁失败不写标记、不阻塞启动，
 * 仓储层会回退读 preferences，界面不会突然变空。
 *
 * 搬迁完成后不删 preferences 老数据（计划要求至少保留一个大版本），
 * 所以这里是「复制」而不是「剪切」。
 *
 * 每一批各自一个事务、各自一个标记：三张表要么全搬成功，要么全回滚。
 * 半搬完的状态比完全没搬更难排查。三批分开是为了让后面批次能独立重试，
 * 不会因为前面的批次已完成就一起被跳过。
 */
export class RdbMigration {
  /** 第一批（书签、划线、搜索历史）的搬迁标记键，值存完成时间戳。 */
  private static readonly markerKeyV1: string = 'rdb_migrated_v1_1';
  /** 第二批（分组、划线规则、正文处理、目录规则、替换规则）的搬迁标记键。 */
  private static readonly markerKeyV2: string = 'rdb_migrated_v1_2';
  /** 第三批（书架与章节、阅读记录）的搬迁标记键。 */
  private static readonly markerKeyV3: string = 'rdb_migrated_v1_3';
  private static readonly preferenceName: string = 'legado_rdb_migration';

  /** 指定批次的搬迁是否已完成。 */
  static async isDone(context: Context, markerKey: string = RdbMigration.markerKeyV1): Promise<boolean> {
    try {
      const store = await preferences.getPreferences(context, RdbMigration.preferenceName);
      const value = await store.get(markerKey, 0);
      return typeof value === 'number' && value > 0;
    } catch (_) {
      return false;
    }
  }

  /**
   * 按需执行三批搬迁；都已完成或都失败时返回 false。
   *
   * 失败时该批事务回滚、不写该批标记，下次启动重试。
   * 这里不抛异常——搬迁是后台动作，不该让启动流程失败。
   */
  static async runIfNeeded(context: Context): Promise<boolean> {
    const migratedV1 = await RdbMigration.migrateFirstBatch(context);
    const migratedV2 = await RdbMigration.migrateSecondBatch(context);
    const migratedV3 = await RdbMigration.migrateThirdBatch(context);
    return migratedV1 || migratedV2 || migratedV3;
  }

  /** 第一批：书签、划线、搜索历史。 */
  private static async migrateFirstBatch(context: Context): Promise<boolean> {
    if (await RdbMigration.isDone(context, RdbMigration.markerKeyV1)) {
      return false;
    }
    try {
      const store = await RdbStore.getStore(context);
      await RdbSchema.ensure(store);
      store.beginTransaction();
      try {
        await ReaderBookmarkRepository.migrateFromPreferences(context, store);
        await ReaderMarkingRepository.migrateFromPreferences(context, store);
        await ReaderSearchHistoryRepository.migrateFromPreferences(context, store);
        store.commit();
      } catch (error) {
        // ArkTS 限制：catch 到的值类型不确定，不能直接 throw（arkts-limited-throw），
        // 统一包成 Error 再抛，外层只关心「失败」这件事
        store.rollBack();
        throw new Error(`搬迁写入失败：${error instanceof Error ? error.message : String(error)}`);
      }
      await RdbMigration.writeMarker(context, RdbMigration.markerKeyV1);
      return true;
    } catch (error) {
      if (error instanceof Error) {
        console.error(`RdbMigration 第一批搬迁失败，保留 preferences 老数据：${error.message}`);
      }
      return false;
    }
  }

  /** 第二批：分组、划线规则、正文处理记录、TXT 目录规则、替换规则。 */
  private static async migrateSecondBatch(context: Context): Promise<boolean> {
    if (await RdbMigration.isDone(context, RdbMigration.markerKeyV2)) {
      return false;
    }
    try {
      const store = await RdbStore.getStore(context);
      await RdbSchema.ensure(store);
      store.beginTransaction();
      try {
        await BookGroupRepository.migrateFromPreferences(context, store);
        await ReaderHighlightRuleRepository.migrateFromPreferences(context, store);
        await BookContentProcessRepository.migrateFromPreferences(context, store);
        await TxtTocRuleRepository.migrateFromPreferences(context, store);
        await ReplaceRuleRepository.migrateFromPreferences(context, store);
        store.commit();
      } catch (error) {
        store.rollBack();
        throw new Error(`搬迁写入失败：${error instanceof Error ? error.message : String(error)}`);
      }
      await RdbMigration.writeMarker(context, RdbMigration.markerKeyV2);
      return true;
    } catch (error) {
      if (error instanceof Error) {
        console.error(`RdbMigration 第二批搬迁失败，保留 preferences 老数据：${error.message}`);
      }
      return false;
    }
  }

  /**
   * 第三批：书架与章节、阅读记录。
   *
   * books 必须写在 chapters 之前：chapters 的外键指向 books。
   * 走一个事务、一个标记，因为章节离开书就没有意义，半搬完的状态最难排查。
   */
  private static async migrateThirdBatch(context: Context): Promise<boolean> {
    if (await RdbMigration.isDone(context, RdbMigration.markerKeyV3)) {
      return false;
    }
    try {
      const store = await RdbStore.getStore(context);
      await RdbSchema.ensure(store);
      store.beginTransaction();
      try {
        await ReadRecordRepository.migrateFromPreferences(context, store);
        await BookRepository.migrateFromPreferences(context, store);
        store.commit();
      } catch (error) {
        store.rollBack();
        throw new Error(`搬迁写入失败：${error instanceof Error ? error.message : String(error)}`);
      }
      await RdbMigration.writeMarker(context, RdbMigration.markerKeyV3);
      return true;
    } catch (error) {
      if (error instanceof Error) {
        console.error(`RdbMigration 第三批搬迁失败，保留 preferences 老数据：${error.message}`);
      }
      return false;
    }
  }

  private static async writeMarker(context: Context, markerKey: string): Promise<void> {
    const store = await preferences.getPreferences(context, RdbMigration.preferenceName);
    await store.put(markerKey, Date.now());
    await store.flush();
  }
}
