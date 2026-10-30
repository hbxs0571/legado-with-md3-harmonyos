import { preferences, relationalStore } from '@kit.ArkData';
import { ReaderHighlightRule } from '../model/ReaderHighlightRule';
import { RdbCodec } from './RdbCodec';
import { RdbStore } from './RdbStore';
import { RdbSchema } from './RdbSchema';

/** 批量导入结果，供界面如实反馈新增与覆盖的条数。 */
export interface ReaderHighlightRuleImportOutcome {
  added: number;
  updated: number;
  skipped: number;
}

/**
 * Android HighlightRule 本地规则仓储；首次使用返回空集，不自动生成默认规则。
 *
 * 存储：highlightRules 表（对齐上游 HighlightRule 实体）。
 * load() 把整表读进 cachedRules，getAll() 同步读缓存，写操作落库后更新缓存。
 * preferences 只作为搬迁来源，搬迁完成后不再写入。
 *
 * 注意：本表有 14 个 REAL 列（下划线宽/偏移、九宫格边距、字距、行距等），
 * 读取必须走 RdbCodec.real()（内部 getDouble）；用 getLong 不报错，
 * 但会把 0.1 静默读成 0，表现是「规则能存能读，样式全丢」。
 */
export class ReaderHighlightRuleRepository {
  private static readonly preferenceName: string = 'legado_reader_highlight_rules';
  private static readonly preferenceKey: string = 'rules_v1';
  private static readonly selectAll: string =
    'SELECT `id`, `name`, `pattern`, `sampleText`, `targetScope`, `enabled`, `position`, `textColor`, ' +
      '`bgColor`, `underlineMode`, `underlineColor`, `underlineWidth`, `underlineOffset`, `underlineSvgPath`, ' +
      '`bgImage`, `bgImageFit`, `bgImageScale`, `configName`, `fontPath`, `fontWeight`, `isItalic`, ' +
      '`fontSizeOffset`, `npLeft`, `npRight`, `npTop`, `npBottom`, `manualNineSlice`, `letterSpacingBefore`, ' +
      '`letterSpacingAfter`, `lineSpacingTop`, `lineSpacingBottom`, `bgLengthOffsetLeft`, `bgLengthOffsetRight` ' +
      'FROM `highlightRules` ORDER BY `position` ASC';
  private static readonly insertSql: string =
    'INSERT OR REPLACE INTO `highlightRules` ' +
      '(`id`, `name`, `pattern`, `sampleText`, `targetScope`, `enabled`, `position`, `textColor`, ' +
      '`bgColor`, `underlineMode`, `underlineColor`, `underlineWidth`, `underlineOffset`, `underlineSvgPath`, ' +
      '`bgImage`, `bgImageFit`, `bgImageScale`, `configName`, `fontPath`, `fontWeight`, `isItalic`, ' +
      '`fontSizeOffset`, `npLeft`, `npRight`, `npTop`, `npBottom`, `manualNineSlice`, `letterSpacingBefore`, ' +
      '`letterSpacingAfter`, `lineSpacingTop`, `lineSpacingBottom`, `bgLengthOffsetLeft`, `bgLengthOffsetRight`) ' +
      'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)';
  private static saveQueue: Promise<void> = Promise.resolve();
  private static cachedRules: ReaderHighlightRule[] = [];

  /**
   * 从 DB 读全表进缓存。
   *
   * 读取路径：DB 有数据就直接用；DB 读失败时回退 preferences 老键 rules_v1，
   * 只读不写（写回由 RdbMigration 统一负责）。
   */
  static async load(context: Context): Promise<ReaderHighlightRule[]> {
    let rules: ReaderHighlightRule[] = [];
    try {
      const store = await RdbStore.getStore(context);
      await RdbSchema.ensure(store);
      const resultSet = await store.querySql(ReaderHighlightRuleRepository.selectAll);
      try {
        rules = ReaderHighlightRuleRepository.readAll(resultSet);
      } finally {
        resultSet.close();
      }
    } catch (_) {
      rules = await ReaderHighlightRuleRepository.loadFromPreferences(context);
    }
    ReaderHighlightRuleRepository.cachedRules =
      rules.map((rule: ReaderHighlightRule, index: number) => ReaderHighlightRuleRepository.normalize(rule, index));
    return ReaderHighlightRuleRepository.copyRules(ReaderHighlightRuleRepository.cachedRules);
  }

  /** 读 preferences 老键；仅供 load 兜底与搬迁使用。 */
  private static async loadFromPreferences(context: Context): Promise<ReaderHighlightRule[]> {
    try {
      const store = await preferences.getPreferences(context, ReaderHighlightRuleRepository.preferenceName);
      const raw = await store.get(ReaderHighlightRuleRepository.preferenceKey, '[]');
      if (typeof raw !== 'string') { return []; }
      const parsed: ReaderHighlightRule[] = JSON.parse(raw);
      return parsed
        .filter((rule: ReaderHighlightRule) => ReaderHighlightRuleRepository.isRule(rule))
        .map((rule: ReaderHighlightRule, index: number) => ReaderHighlightRuleRepository.normalize(rule, index));
    } catch (_) {
      return [];
    }
  }

  /**
   * 把 preferences 老数据搬进 DB，由 RdbMigration 在事务里调用。
   * 不开事务、不写标记：事务与标记都由 RdbMigration 统一管。
   */
  static async migrateFromPreferences(context: Context, store: relationalStore.RdbStore): Promise<void> {
    const legacy = await ReaderHighlightRuleRepository.loadFromPreferences(context);
    if (legacy.length === 0) { return; }
    await ReaderHighlightRuleRepository.replaceAll(store, legacy);
    ReaderHighlightRuleRepository.cachedRules = ReaderHighlightRuleRepository.copyRules(legacy);
  }

  /**
   * 取当前缓存里的规则快照，供备份与界面同步读取。
   * 缓存只在 load() 之后才非空，备份链路必须先 await load()。
   */
  static getAll(): ReaderHighlightRule[] {
    return ReaderHighlightRuleRepository.copyRules(ReaderHighlightRuleRepository.cachedRules);
  }

  /**
   * 导出为与上游 highlightRule.json 一致的 JSON 数组。
   * 字段名逐字对齐 Android HighlightRule 实体，不含本地独有的运行时字段，
   * 因此 Android 端可直接读回；上游多出的 borderColor/borderWidth/borderRadius
   * 三个边框字段本地没有模型，缺失时由 Kotlin 默认值兜底。
   */
  static exportRules(rules: ReaderHighlightRule[]): string {
    const ordered: ReaderHighlightRule[] = rules.map((rule: ReaderHighlightRule, index: number) => {
      const copy = ReaderHighlightRuleRepository.copyRule(rule);
      copy.position = index;
      return copy;
    });
    return JSON.stringify(ordered, null, 2);
  }

  /**
   * 合并导入：同 id 或同 pattern 视为同一条，保留已有 id 与位置，用导入内容覆盖其余字段；
   * 其余新增。与上游 replaceAll 的全量替换不同，本地独有的规则会保留下来，
   * 避免「恢复一份旧备份就把新规则删光」的数据丢失。
   */
  static async importRules(context: Context, incoming: ReaderHighlightRule[]):
    Promise<ReaderHighlightRuleImportOutcome> {
    const next: ReaderHighlightRule[] = ReaderHighlightRuleRepository.copyRules(ReaderHighlightRuleRepository.cachedRules);
    let added = 0;
    let updated = 0;
    let skipped = 0;
    incoming.forEach((rule: ReaderHighlightRule) => {
      if (!ReaderHighlightRuleRepository.isRule(rule)) {
        skipped += 1;
        return;
      }
      const pattern = typeof rule.pattern === 'string' ? rule.pattern.trim() : '';
      // 空正则会命中每个字符位置，等于给整本书刷一层样式，按无效规则跳过。
      if (pattern.length === 0 || !ReaderHighlightRuleRepository.isValidRegex(pattern)) {
        skipped += 1;
        return;
      }
      const existingIndex = next.findIndex((item: ReaderHighlightRule) => item.id === rule.id ||
        (typeof item.pattern === 'string' && item.pattern.trim() === pattern));
      if (existingIndex >= 0) {
        const merged = ReaderHighlightRuleRepository.normalize(rule, next[existingIndex].position);
        merged.id = next[existingIndex].id;
        next[existingIndex] = merged;
        updated += 1;
      } else {
        next.push(ReaderHighlightRuleRepository.normalize(rule, next.length));
        added += 1;
      }
    });
    if (added === 0 && updated === 0) {
      return { added: added, updated: updated, skipped: skipped };
    }
    await ReaderHighlightRuleRepository.save(context, next);
    return { added: added, updated: updated, skipped: skipped };
  }

  /** 正则在本机能否编译；编译失败说明这条规则无法执行，导入时按无效跳过。 */
  private static isValidRegex(pattern: string): boolean {
    try {
      new RegExp(pattern, 'gu');
      return true;
    } catch (_) {
      return false;
    }
  }

  /**
   * 整表写回 DB。
   *
   * 写入顺序：串行队列内先 DELETE 全表、再逐行 INSERT OR REPLACE，
   * 整体包在一个事务里，中途失败回滚，库里保持写入前的状态。
   * 失败态：写库失败时抛错给调用方，cachedRules 不更新（保持旧值）。
   */
  static save(context: Context, rules: ReaderHighlightRule[]): Promise<ReaderHighlightRule[]> {
    const operation = ReaderHighlightRuleRepository.saveQueue.then(async (): Promise<ReaderHighlightRule[]> => {
      const ordered = rules.map((rule: ReaderHighlightRule, index: number) =>
        ReaderHighlightRuleRepository.normalize(rule, index));
      const store = await RdbStore.getStore(context);
      await RdbSchema.ensure(store);
      store.beginTransaction();
      try {
        await ReaderHighlightRuleRepository.replaceAll(store, ordered);
        store.commit();
      } catch (error) {
        store.rollBack();
        // ArkTS 限制：catch 到的值类型不确定，不能直接 throw（arkts-limited-throw）。
        throw new Error(`划线规则写入失败：${error instanceof Error ? error.message : String(error)}`);
      }
      ReaderHighlightRuleRepository.cachedRules = ordered;
      return ReaderHighlightRuleRepository.copyRules(ordered);
    });
    ReaderHighlightRuleRepository.saveQueue = operation.then((): void => {}, (_error: Error): void => {});
    return operation;
  }

  /** 在调用方给定的事务里整表重写；不 commit、不回滚。 */
  private static async replaceAll(store: relationalStore.RdbStore, rules: ReaderHighlightRule[]): Promise<void> {
    await store.executeSql('DELETE FROM `highlightRules`');
    for (let index = 0; index < rules.length; index++) {
      const rule = rules[index];
      if (rule === undefined) { continue; }
      await store.executeSql(ReaderHighlightRuleRepository.insertSql, [
        rule.id,
        rule.name,
        rule.pattern,
        rule.sampleText === undefined ? '' : rule.sampleText,
        rule.targetScope,
        rule.enabled ? 1 : 0,
        rule.position,
        rule.textColor === undefined ? null : rule.textColor,
        rule.bgColor === undefined ? null : rule.bgColor,
        rule.underlineMode,
        rule.underlineColor === undefined ? null : rule.underlineColor,
        // 下面这些 REAL/INTEGER 列是 NOT NULL，模型里是可选字段，
        // 缺省值取上游 HighlightRule 的默认值，与 BackupRepository 导入时的兜底一致。
        rule.underlineWidth === undefined ? 1 : rule.underlineWidth,
        rule.underlineOffset === undefined ? 2 : rule.underlineOffset,
        rule.underlineSvgPath === undefined ? null : rule.underlineSvgPath,
        rule.bgImage === undefined ? null : rule.bgImage,
        rule.bgImageFit === undefined ? 0 : rule.bgImageFit,
        rule.bgImageScale === undefined ? 1 : rule.bgImageScale,
        rule.configName === undefined ? null : rule.configName,
        rule.fontPath === undefined ? null : rule.fontPath,
        rule.fontWeight === undefined ? 400 : rule.fontWeight,
        rule.isItalic === undefined ? 0 : (rule.isItalic ? 1 : 0),
        rule.fontSizeOffset === undefined ? 0 : rule.fontSizeOffset,
        rule.npLeft === undefined ? 0.1 : rule.npLeft,
        rule.npRight === undefined ? 0.1 : rule.npRight,
        rule.npTop === undefined ? 0.1 : rule.npTop,
        rule.npBottom === undefined ? 0.1 : rule.npBottom,
        rule.manualNineSlice === undefined ? 1 : (rule.manualNineSlice ? 1 : 0),
        rule.letterSpacingBefore === undefined ? 0 : rule.letterSpacingBefore,
        rule.letterSpacingAfter === undefined ? 0 : rule.letterSpacingAfter,
        rule.lineSpacingTop === undefined ? 0 : rule.lineSpacingTop,
        rule.lineSpacingBottom === undefined ? 0 : rule.lineSpacingBottom,
        rule.bgLengthOffsetLeft === undefined ? 0 : rule.bgLengthOffsetLeft,
        rule.bgLengthOffsetRight === undefined ? 0 : rule.bgLengthOffsetRight
      ]);
    }
  }

  /** 从结果集读出全部规则。列顺序与 selectAll 一致。 */
  private static readAll(resultSet: relationalStore.ResultSet): ReaderHighlightRule[] {
    const idIndex = RdbCodec.column(resultSet, 'id');
    const nameIndex = RdbCodec.column(resultSet, 'name');
    const patternIndex = RdbCodec.column(resultSet, 'pattern');
    const sampleTextIndex = RdbCodec.column(resultSet, 'sampleText');
    const targetScopeIndex = RdbCodec.column(resultSet, 'targetScope');
    const enabledIndex = RdbCodec.column(resultSet, 'enabled');
    const positionIndex = RdbCodec.column(resultSet, 'position');
    const textColorIndex = RdbCodec.column(resultSet, 'textColor');
    const bgColorIndex = RdbCodec.column(resultSet, 'bgColor');
    const underlineModeIndex = RdbCodec.column(resultSet, 'underlineMode');
    const underlineColorIndex = RdbCodec.column(resultSet, 'underlineColor');
    const underlineWidthIndex = RdbCodec.column(resultSet, 'underlineWidth');
    const underlineOffsetIndex = RdbCodec.column(resultSet, 'underlineOffset');
    const underlineSvgPathIndex = RdbCodec.column(resultSet, 'underlineSvgPath');
    const bgImageIndex = RdbCodec.column(resultSet, 'bgImage');
    const bgImageFitIndex = RdbCodec.column(resultSet, 'bgImageFit');
    const bgImageScaleIndex = RdbCodec.column(resultSet, 'bgImageScale');
    const configNameIndex = RdbCodec.column(resultSet, 'configName');
    const fontPathIndex = RdbCodec.column(resultSet, 'fontPath');
    const fontWeightIndex = RdbCodec.column(resultSet, 'fontWeight');
    const isItalicIndex = RdbCodec.column(resultSet, 'isItalic');
    const fontSizeOffsetIndex = RdbCodec.column(resultSet, 'fontSizeOffset');
    const npLeftIndex = RdbCodec.column(resultSet, 'npLeft');
    const npRightIndex = RdbCodec.column(resultSet, 'npRight');
    const npTopIndex = RdbCodec.column(resultSet, 'npTop');
    const npBottomIndex = RdbCodec.column(resultSet, 'npBottom');
    const manualNineSliceIndex = RdbCodec.column(resultSet, 'manualNineSlice');
    const letterSpacingBeforeIndex = RdbCodec.column(resultSet, 'letterSpacingBefore');
    const letterSpacingAfterIndex = RdbCodec.column(resultSet, 'letterSpacingAfter');
    const lineSpacingTopIndex = RdbCodec.column(resultSet, 'lineSpacingTop');
    const lineSpacingBottomIndex = RdbCodec.column(resultSet, 'lineSpacingBottom');
    const bgLengthOffsetLeftIndex = RdbCodec.column(resultSet, 'bgLengthOffsetLeft');
    const bgLengthOffsetRightIndex = RdbCodec.column(resultSet, 'bgLengthOffsetRight');
    const rules: ReaderHighlightRule[] = [];
    while (resultSet.goToNextRow()) {
      const rule: ReaderHighlightRule = {
        id: RdbCodec.text(resultSet, idIndex),
        name: RdbCodec.text(resultSet, nameIndex),
        pattern: RdbCodec.text(resultSet, patternIndex),
        sampleText: RdbCodec.text(resultSet, sampleTextIndex),
        targetScope: RdbCodec.integer(resultSet, targetScopeIndex),
        enabled: RdbCodec.boolean(resultSet, enabledIndex, true),
        position: RdbCodec.integer(resultSet, positionIndex),
        textColor: RdbCodec.optionalInteger(resultSet, textColorIndex),
        bgColor: RdbCodec.optionalInteger(resultSet, bgColorIndex),
        underlineMode: RdbCodec.integer(resultSet, underlineModeIndex),
        underlineColor: RdbCodec.optionalInteger(resultSet, underlineColorIndex),
        // REAL 列必须走 real()，getLong 会把 0.1 读成 0。
        underlineWidth: RdbCodec.real(resultSet, underlineWidthIndex, 1),
        underlineOffset: RdbCodec.real(resultSet, underlineOffsetIndex, 2),
        underlineSvgPath: RdbCodec.optionalText(resultSet, underlineSvgPathIndex),
        bgImage: RdbCodec.optionalText(resultSet, bgImageIndex),
        bgImageFit: RdbCodec.integer(resultSet, bgImageFitIndex),
        bgImageScale: RdbCodec.real(resultSet, bgImageScaleIndex, 1),
        configName: RdbCodec.optionalText(resultSet, configNameIndex),
        fontPath: RdbCodec.optionalText(resultSet, fontPathIndex),
        fontWeight: RdbCodec.integer(resultSet, fontWeightIndex, 400),
        isItalic: RdbCodec.boolean(resultSet, isItalicIndex),
        fontSizeOffset: RdbCodec.integer(resultSet, fontSizeOffsetIndex),
        npLeft: RdbCodec.real(resultSet, npLeftIndex, 0.1),
        npRight: RdbCodec.real(resultSet, npRightIndex, 0.1),
        npTop: RdbCodec.real(resultSet, npTopIndex, 0.1),
        npBottom: RdbCodec.real(resultSet, npBottomIndex, 0.1),
        manualNineSlice: RdbCodec.boolean(resultSet, manualNineSliceIndex, true),
        letterSpacingBefore: RdbCodec.real(resultSet, letterSpacingBeforeIndex),
        letterSpacingAfter: RdbCodec.real(resultSet, letterSpacingAfterIndex),
        lineSpacingTop: RdbCodec.real(resultSet, lineSpacingTopIndex),
        lineSpacingBottom: RdbCodec.real(resultSet, lineSpacingBottomIndex),
        bgLengthOffsetLeft: RdbCodec.real(resultSet, bgLengthOffsetLeftIndex),
        bgLengthOffsetRight: RdbCodec.real(resultSet, bgLengthOffsetRightIndex)
      };
      rules.push(rule);
    }
    return rules;
  }

  private static copyRule(rule: ReaderHighlightRule): ReaderHighlightRule {
    return {
      id: rule.id,
      name: rule.name,
      pattern: rule.pattern,
      sampleText: rule.sampleText,
      targetScope: rule.targetScope,
      enabled: rule.enabled,
      position: rule.position,
      textColor: rule.textColor,
      bgColor: rule.bgColor,
      underlineMode: rule.underlineMode,
      underlineColor: rule.underlineColor,
      underlineWidth: rule.underlineWidth,
      underlineOffset: rule.underlineOffset,
      underlineSvgPath: rule.underlineSvgPath,
      bgImage: rule.bgImage,
      bgImageFit: rule.bgImageFit,
      bgImageScale: rule.bgImageScale,
      configName: rule.configName,
      fontPath: rule.fontPath,
      fontWeight: rule.fontWeight,
      isItalic: rule.isItalic,
      fontSizeOffset: rule.fontSizeOffset,
      npLeft: rule.npLeft,
      npRight: rule.npRight,
      npTop: rule.npTop,
      npBottom: rule.npBottom,
      manualNineSlice: rule.manualNineSlice,
      letterSpacingBefore: rule.letterSpacingBefore,
      letterSpacingAfter: rule.letterSpacingAfter,
      lineSpacingTop: rule.lineSpacingTop,
      lineSpacingBottom: rule.lineSpacingBottom,
      bgLengthOffsetLeft: rule.bgLengthOffsetLeft,
      bgLengthOffsetRight: rule.bgLengthOffsetRight
    };
  }

  private static copyRules(rules: ReaderHighlightRule[]): ReaderHighlightRule[] {
    return rules.map((rule: ReaderHighlightRule) => ReaderHighlightRuleRepository.copyRule(rule));
  }

  /** 只收敛核心字段，其余 Android 样式字段按原值往返保存。 */
  private static normalize(rule: ReaderHighlightRule, position: number): ReaderHighlightRule {
    const copy = ReaderHighlightRuleRepository.copyRule(rule);
    copy.id = typeof rule.id === 'string' && rule.id.length > 0 ? rule.id : `highlight_${Date.now()}_${position}`;
    copy.name = typeof rule.name === 'string' ? rule.name : '';
    copy.pattern = typeof rule.pattern === 'string' ? rule.pattern : '';
    copy.sampleText = typeof rule.sampleText === 'string' ? rule.sampleText : '';
    copy.targetScope = typeof rule.targetScope === 'number' && [0, 1, 2].includes(rule.targetScope)
      ? rule.targetScope : 0;
    copy.enabled = typeof rule.enabled === 'boolean' ? rule.enabled : true;
    copy.position = position;
    copy.underlineMode = typeof rule.underlineMode === 'number' ? rule.underlineMode : 0;
    return copy;
  }

  private static isRule(value: ReaderHighlightRule): boolean {
    return value !== null && value !== undefined && typeof value === 'object' &&
      typeof value.name === 'string' && typeof value.pattern === 'string';
  }
}
