import { preferences, relationalStore } from '@kit.ArkData';
import { cryptoFramework } from '@kit.CryptoArchitectureKit';
import { util } from '@kit.ArkTS';
import { ReaderMarking, ReaderMarkingEffect } from '../model/ReaderMarking';
import { RdbStore } from './RdbStore';
import { RdbCodec } from './RdbCodec';

/** 上游 TextProcessAnchor，存进 anchorJson 做章节内定位。 */
interface MarkingAnchor {
  chapterIndex: number;
  chapterPosition: number;
  selectedText: string;
  contextBefore: string;
  contextAfter: string;
  normalizedTextHash: string;
}

/** 上游 TextProcessStyle，存进 styleJson。字段可选，未设置的不会出现在 JSON 里。 */
interface MarkingStyle {
  textColor?: number;
  bgColor?: number;
  underlineMode?: number;
  underlineColor?: number;
}

/** 上游 MarkingEffect.DEFAULT_COLOR = 0xFF63C37D。 */
const DEFAULT_COLOR: number = 0xFF63C37D;

/**
 * 划线/高亮仓储。
 *
 * 表结构对齐上游 BookMarking.kt。这是第一批里唯一需要「结构转换」的表：
 * 本地把锚点拆成 5 个平铺列、样式拆成 effect + color 两列；
 * 上游把锚点塞进 anchorJson、样式塞进 styleJson。
 * 转换逻辑与 ReaderBookmarkExporter 的导出逻辑同口径，保证两边 JSON 形态一致。
 *
 * endPosition 不存（上游 anchorJson 里也没有这个字段），
 * 读出时用 chapterPosition + selectedText.length 推导。
 */
export class ReaderMarkingRepository {
  private static readonly preferenceName: string = 'legado_reader_markings';
  private static saveQueue: Promise<void> = Promise.resolve();
  /** 上游 MarkingEffect 的取值，本地已删除 double（上游没有对应枚举）。 */
  private static readonly effects: ReaderMarkingEffect[] = [
    'solid', 'dashed', 'wave', 'strike', 'highlight', 'background', 'text'
  ];

  /** 上游 BookMarkingDao.all 的排序：书名、作者按拼音，再按章节与创建时间。 */
  private static readonly selectAll: string =
    'SELECT id, bookUrl, bookName, bookAuthor, chapterIndex, anchorJson, styleJson, ' +
    'note, chapterName, enabled, createdAt, updatedAt FROM book_marks ' +
    'ORDER BY bookName COLLATE LOCALES, bookAuthor COLLATE LOCALES, chapterIndex, createdAt';

  static async load(context: Context): Promise<ReaderMarking[]> {
    try {
      const store = await RdbStore.getStore(context);
      const resultSet = await store.querySql(ReaderMarkingRepository.selectAll);
      try {
        return ReaderMarkingRepository.readAll(resultSet);
      } finally {
        resultSet.close();
      }
    } catch (error) {
      // 不再回退读 preferences：老数据已由 RdbCleanup 清掉，回退只会读到空
      console.error(`划线读取失败：${error instanceof Error ? error.message : String(error)}`);
      return [];
    }
  }

  static save(context: Context, records: ReaderMarking[]): Promise<void> {
    const operation = ReaderMarkingRepository.saveQueue.then(async (): Promise<void> => {
      const store = await RdbStore.getStore(context);
      store.beginTransaction();
      try {
        await ReaderMarkingRepository.replaceAll(store, records);
        store.commit();
      } catch (error) {
        store.rollBack();
        throw error as Error;
      }
    });
    ReaderMarkingRepository.saveQueue = operation.catch(() => {});
    return operation;
  }

  /** 搬迁：由 RdbMigration 在它自己的事务里调用，所以这里不再开事务。 */
  static async migrateFromPreferences(context: Context, store: relationalStore.RdbStore): Promise<void> {
    const records = await ReaderMarkingRepository.loadFromPreferences(context);
    await ReaderMarkingRepository.replaceAll(store, records);
  }

  private static async replaceAll(
    store: relationalStore.RdbStore,
    records: ReaderMarking[]
  ): Promise<void> {
    await store.executeSql('DELETE FROM book_marks');
    for (let index = 0; index < records.length; index++) {
      const record = records[index];
      if (record === undefined) { continue; }
      const values: relationalStore.ValuesBucket = {
        'id': record.id,
        'bookUrl': record.bookUrl,
        'bookName': record.bookName,
        'bookAuthor': record.bookAuthor,
        'chapterIndex': record.chapterIndex,
        'anchorJson': ReaderMarkingRepository.toAnchorJson(record),
        'styleJson': ReaderMarkingRepository.toStyleJson(record.effect, record.color),
        'note': record.note,
        'chapterName': record.chapterName,
        'enabled': record.enabled ? 1 : 0,
        'createdAt': record.createdAt,
        'updatedAt': record.updatedAt
      };
      await store.insert('book_marks', values, relationalStore.ConflictResolution.ON_CONFLICT_REPLACE);
    }
  }

  /** 模型 → anchorJson，结构与上游 TextProcessAnchor 一致。 */
  private static toAnchorJson(record: ReaderMarking): string {
    const anchor: MarkingAnchor = {
      chapterIndex: record.chapterIndex,
      chapterPosition: record.chapterPosition,
      selectedText: record.selectedText,
      contextBefore: record.contextBefore,
      contextAfter: record.contextAfter,
      normalizedTextHash: ReaderMarkingRepository.md5Hex(
        ReaderMarkingRepository.normalizeProcessText(record.selectedText))
    };
    return JSON.stringify(anchor);
  }

  /**
   * 本地 effect + color → styleJson，逐条对齐上游 MarkingEffect.toStyle。
   * 本地已删除 'double'（上游没有该枚举值），存量 'double' 在搬迁时按 solid 处理。
   */
  private static toStyleJson(effect: ReaderMarkingEffect, color: string): string {
    const colorInt = ReaderMarkingRepository.colorToInt(color);
    let style: MarkingStyle;
    if (effect === 'wave') {
      style = { underlineMode: 3, underlineColor: colorInt };
    } else if (effect === 'dashed') {
      style = { underlineMode: 2, underlineColor: colorInt };
    } else if (effect === 'strike') {
      style = { underlineMode: 6, underlineColor: colorInt };
    } else if (effect === 'highlight') {
      style = { underlineMode: 7, underlineColor: colorInt };
    } else if (effect === 'background') {
      // 与上游一致：背景色固定 0x33 alpha，避免不透明背景盖住正文
      style = { bgColor: ((colorInt & 0x00FFFFFF) | 0x33000000) };
    } else if (effect === 'text') {
      style = { textColor: colorInt };
    } else {
      // solid（含存量 double 降级）
      style = { underlineMode: 1, underlineColor: colorInt };
    }
    return JSON.stringify(style);
  }

  /** styleJson → 本地 effect + color，是 toStyleJson 的逆运算。 */
  private static fromStyleJson(styleJson: string): StyleResult {
    let style: MarkingStyle = {};
    try {
      style = JSON.parse(styleJson) as MarkingStyle;
    } catch (_) {
      return { effect: 'solid', color: ReaderMarkingRepository.intToColor(DEFAULT_COLOR) };
    }
    // 与上游 fromStyle 同序判断：字体色优先，其次背景色，最后按下划线模式
    if (style.textColor !== undefined) {
      return { effect: 'text', color: ReaderMarkingRepository.intToColor(style.textColor) };
    }
    if (style.bgColor !== undefined) {
      return { effect: 'background', color: ReaderMarkingRepository.intToColor(style.bgColor | 0xFF000000) };
    }
    const color = style.underlineColor !== undefined
      ? ReaderMarkingRepository.intToColor(style.underlineColor)
      : ReaderMarkingRepository.intToColor(DEFAULT_COLOR);
    const mode = style.underlineMode ?? 1;
    if (mode === 3) { return { effect: 'wave', color: color }; }
    if (mode === 2) { return { effect: 'dashed', color: color }; }
    if (mode === 6) { return { effect: 'strike', color: color }; }
    if (mode === 7) { return { effect: 'highlight', color: color }; }
    return { effect: 'solid', color: color };
  }

  /** anchorJson → 锚点字段；解析失败返回空锚点，由调用方按无效记录跳过。 */
  private static fromAnchorJson(anchorJson: string): MarkingAnchor | undefined {
    try {
      const anchor = JSON.parse(anchorJson) as MarkingAnchor;
      if (typeof anchor.chapterIndex !== 'number' || typeof anchor.selectedText !== 'string') {
        return undefined;
      }
      return anchor;
    } catch (_) {
      return undefined;
    }
  }

  private static readAll(resultSet: relationalStore.ResultSet): ReaderMarking[] {
    const idIndex = RdbCodec.column(resultSet, 'id');
    const bookUrlIndex = RdbCodec.column(resultSet, 'bookUrl');
    const bookNameIndex = RdbCodec.column(resultSet, 'bookName');
    const bookAuthorIndex = RdbCodec.column(resultSet, 'bookAuthor');
    const chapterIndexIndex = RdbCodec.column(resultSet, 'chapterIndex');
    const anchorJsonIndex = RdbCodec.column(resultSet, 'anchorJson');
    const styleJsonIndex = RdbCodec.column(resultSet, 'styleJson');
    const noteIndex = RdbCodec.column(resultSet, 'note');
    const chapterNameIndex = RdbCodec.column(resultSet, 'chapterName');
    const enabledIndex = RdbCodec.column(resultSet, 'enabled');
    const createdAtIndex = RdbCodec.column(resultSet, 'createdAt');
    const updatedAtIndex = RdbCodec.column(resultSet, 'updatedAt');
    const records: ReaderMarking[] = [];
    while (resultSet.goToNextRow()) {
      const anchor = ReaderMarkingRepository.fromAnchorJson(RdbCodec.text(resultSet, anchorJsonIndex));
      if (anchor === undefined) { continue; }
      const styleJson = RdbCodec.optionalText(resultSet, styleJsonIndex);
      const style = ReaderMarkingRepository.fromStyleJson(styleJson ?? '');
      const chapterPosition = anchor.chapterPosition ?? 0;
      const bookUrl = RdbCodec.text(resultSet, bookUrlIndex);
      records.push({
        id: RdbCodec.text(resultSet, idIndex),
        bookId: ReaderMarkingRepository.bookIdFromBookUrl(bookUrl),
        bookName: RdbCodec.text(resultSet, bookNameIndex),
        bookAuthor: RdbCodec.text(resultSet, bookAuthorIndex),
        bookUrl: bookUrl,
        chapterIndex: RdbCodec.integer(resultSet, chapterIndexIndex, anchor.chapterIndex),
        chapterName: RdbCodec.text(resultSet, chapterNameIndex),
        chapterPosition: chapterPosition,
        // 上游不存 endPosition，用起点 + 选中文字长度推导
        endPosition: chapterPosition + anchor.selectedText.length,
        selectedText: anchor.selectedText,
        contextBefore: anchor.contextBefore ?? '',
        contextAfter: anchor.contextAfter ?? '',
        effect: style.effect,
        color: style.color,
        note: RdbCodec.text(resultSet, noteIndex),
        enabled: RdbCodec.boolean(resultSet, enabledIndex, true),
        createdAt: RdbCodec.integer(resultSet, createdAtIndex),
        updatedAt: RdbCodec.integer(resultSet, updatedAtIndex)
      });
    }
    return records;
  }

  private static bookIdFromBookUrl(bookUrl: string): string {
    if (bookUrl.length === 0) { return ''; }
    const slash = bookUrl.lastIndexOf('/');
    const fileName = slash >= 0 ? bookUrl.substring(slash + 1) : bookUrl;
    return fileName.endsWith('.txt') ? fileName.substring(0, fileName.length - 4) : fileName;
  }

  /** `#RRGGBB` / `#AARRGGBB` 转 ARGB 整数；解析失败回退默认绿色。 */
  private static colorToInt(color: string): number {
    const hex = color.startsWith('#') ? color.substring(1) : color;
    if (hex.length === 6) {
      const parsed = Number.parseInt(hex, 16);
      return Number.isNaN(parsed) ? DEFAULT_COLOR : ((0xFF000000 | parsed) | 0);
    }
    if (hex.length === 8) {
      const parsed = Number.parseInt(hex, 16);
      return Number.isNaN(parsed) ? DEFAULT_COLOR : (parsed | 0);
    }
    return DEFAULT_COLOR;
  }

  /** ARGB 整数转 `#RRGGBB`（丢弃 alpha，与本地 color 的存储形态一致）。 */
  private static intToColor(value: number): string {
    const rgb = (value & 0x00FFFFFF) >>> 0;
    return `#${rgb.toString(16).padStart(6, '0').toUpperCase()}`;
  }

  /** 与上游 normalizeProcessText 同口径：逐行去首尾空白（含全角空格）后用 \n 连接。 */
  private static normalizeProcessText(text: string): string {
    return text.split('\n')
      .map((line: string) => line.replace(/^[\s\u3000]+|[\s\u3000]+$/g, ''))
      .join('\n')
      .trim();
  }

  /** 上游 normalizedTextHash 用 MD5；匹配不依赖它，但字段需有值。 */
  private static md5Hex(text: string): string {
    try {
      const md = cryptoFramework.createMd('MD5');
      md.updateSync({ data: new Uint8Array(new util.TextEncoder().encodeInto(text)) });
      const digest = md.digestSync();
      let hex: string = '';
      for (let index = 0; index < digest.data.length; index++) {
        hex += (digest.data[index] as number).toString(16).padStart(2, '0');
      }
      return hex;
    } catch (_) {
      return '';
    }
  }

  /**
   * 旧 preferences 解析：每行 18 字段，字段序见迁移前实现。
   * 搬迁与 DB 回退共用；effect 不在白名单的（如已删除的 double）按 solid 收下，
   * 否则老数据会整条丢失。
   */
  private static async loadFromPreferences(context: Context): Promise<ReaderMarking[]> {
    try {
      const store = await preferences.getPreferences(context, ReaderMarkingRepository.preferenceName);
      const value = await store.get('records', 'v1\n');
      if (typeof value !== 'string' || !value.startsWith('v1\n')) { return []; }
      const records: ReaderMarking[] = [];
      const rows = value.substring(3).split('\n');
      for (let index = 0; index < rows.length; index++) {
        const row = rows[index];
        if (row === undefined || row.length === 0) { continue; }
        const fields = row.split('|');
        if (fields.length !== 18) { continue; }
        try {
          const chapterIndex = Number(fields[5]);
          const chapterPosition = Number(fields[7]);
          const endPosition = Number(fields[8]);
          const createdAt = Number(fields[16]);
          const updatedAt = Number(fields[17]);
          const rawEffect = decodeURIComponent(fields[12]);
          if (!Number.isInteger(chapterIndex) || chapterIndex < 0 ||
            !Number.isInteger(chapterPosition) || chapterPosition < 0 ||
            !Number.isInteger(endPosition) || endPosition <= chapterPosition ||
            !Number.isFinite(createdAt) || createdAt <= 0 || !Number.isFinite(updatedAt)) { continue; }
          // 已删除的 'double' 按 solid 收下，避免老数据丢失
          const effect: ReaderMarkingEffect = ReaderMarkingRepository.effects.includes(
            rawEffect as ReaderMarkingEffect) ? rawEffect as ReaderMarkingEffect : 'solid';
          records.push({
            id: decodeURIComponent(fields[0]),
            bookId: decodeURIComponent(fields[1]),
            bookName: decodeURIComponent(fields[2]),
            bookAuthor: decodeURIComponent(fields[3]),
            bookUrl: decodeURIComponent(fields[4]),
            chapterIndex: chapterIndex,
            chapterName: decodeURIComponent(fields[6]),
            chapterPosition: chapterPosition,
            endPosition: endPosition,
            selectedText: decodeURIComponent(fields[9]),
            contextBefore: decodeURIComponent(fields[10]),
            contextAfter: decodeURIComponent(fields[11]),
            effect: effect,
            color: decodeURIComponent(fields[13]),
            note: decodeURIComponent(fields[14]),
            enabled: fields[15] === '1',
            createdAt: createdAt,
            updatedAt: updatedAt
          });
        } catch (_) {
          continue;
        }
      }
      return records;
    } catch (_) {
      return [];
    }
  }
}

/** fromStyleJson 的返回值：本地 effect + color。 */
interface StyleResult {
  effect: ReaderMarkingEffect;
  color: string;
}
