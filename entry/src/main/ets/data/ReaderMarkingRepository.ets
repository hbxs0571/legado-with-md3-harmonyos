import { preferences } from '@kit.ArkData';
import { ReaderMarking, ReaderMarkingEffect } from '../model/ReaderMarking';

/** 本地划线/高亮/笔记仓储，独立于普通书签与 AI 正文处理记录。 */
export class ReaderMarkingRepository {
  private static readonly preferenceName: string = 'legado_reader_markings';
  private static saveQueue: Promise<void> = Promise.resolve();
  private static readonly effects: ReaderMarkingEffect[] = [
    'solid', 'double', 'dashed', 'wave', 'strike', 'highlight', 'background', 'text'
  ];

  static async load(context: Context): Promise<ReaderMarking[]> {
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
          const effect = decodeURIComponent(fields[12]) as ReaderMarkingEffect;
          if (!Number.isInteger(chapterIndex) || chapterIndex < 0 ||
            !Number.isInteger(chapterPosition) || chapterPosition < 0 ||
            !Number.isInteger(endPosition) || endPosition <= chapterPosition ||
            !Number.isFinite(createdAt) || createdAt <= 0 || !Number.isFinite(updatedAt) ||
            !ReaderMarkingRepository.effects.includes(effect)) { continue; }
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

  static save(context: Context, records: ReaderMarking[]): Promise<void> {
    const operation = ReaderMarkingRepository.saveQueue.then(async (): Promise<void> => {
      const rows: string[] = ['v1'];
      for (let index = 0; index < records.length; index++) {
        const record = records[index];
        if (record === undefined) { continue; }
        rows.push([
          encodeURIComponent(record.id), encodeURIComponent(record.bookId),
          encodeURIComponent(record.bookName), encodeURIComponent(record.bookAuthor),
          encodeURIComponent(record.bookUrl), record.chapterIndex.toString(),
          encodeURIComponent(record.chapterName), record.chapterPosition.toString(),
          record.endPosition.toString(), encodeURIComponent(record.selectedText),
          encodeURIComponent(record.contextBefore), encodeURIComponent(record.contextAfter),
          encodeURIComponent(record.effect), encodeURIComponent(record.color),
          encodeURIComponent(record.note), record.enabled ? '1' : '0',
          record.createdAt.toString(), record.updatedAt.toString()
        ].join('|'));
      }
      const store = await preferences.getPreferences(context, ReaderMarkingRepository.preferenceName);
      await store.put('records', rows.join('\n'));
      await store.flush();
    });
    ReaderMarkingRepository.saveQueue = operation.catch(() => {});
    return operation;
  }
}
