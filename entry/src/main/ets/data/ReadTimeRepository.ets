import { preferences } from '@kit.ArkData';
import { Book } from '../model/Book';

export interface ReadTimeRecord {
  id: string;
  bookId: string;
  bookName: string;
  bookAuthor: string;
  startTime: number;
  endTime: number;
  durationMs: number;
}

export class ReadTimeRepository {
  private static readonly preferenceName: string = 'legado_read_time_records';
  private static saveQueue: Promise<void> = Promise.resolve();
  private static activeBookId: string = '';
  private static activeBookName: string = '';
  private static activeBookAuthor: string = '';
  private static activeStartTime: number = 0;
  private static activeEndTime: number = 0;

  static async load(context: Context): Promise<ReadTimeRecord[]> {
    try {
      const store = await preferences.getPreferences(context, ReadTimeRepository.preferenceName);
      const value = await store.get('records', 'v1\n');
      if (typeof value !== 'string' || !value.startsWith('v1\n')) { return []; }
      const rows = value.substring(3).split('\n');
      const records: ReadTimeRecord[] = [];
      for (let index = 0; index < rows.length; index++) {
        const row = rows[index];
        if (row === undefined || row.length === 0) { continue; }
        const fields = row.split('|');
        if (fields.length !== 7) { continue; }
        try {
          const startTime = Number(fields[4]);
          const endTime = Number(fields[5]);
          const durationMs = Number(fields[6]);
          if (!Number.isFinite(startTime) || !Number.isFinite(endTime) || !Number.isFinite(durationMs) || durationMs <= 0) { continue; }
          records.push({
            id: decodeURIComponent(fields[0]), bookId: decodeURIComponent(fields[1]),
            bookName: decodeURIComponent(fields[2]), bookAuthor: decodeURIComponent(fields[3]),
            startTime: startTime, endTime: endTime, durationMs: durationMs
          });
        } catch (_) {
          continue;
        }
      }
      return records.sort((left: ReadTimeRecord, right: ReadTimeRecord) => right.endTime - left.endTime);
    } catch (_) {
      return [];
    }
  }

  static async start(context: Context, book: Book): Promise<void> {
    if (ReadTimeRepository.activeBookId.length > 0 && ReadTimeRepository.activeBookId !== book.id) {
      await ReadTimeRepository.commit(context);
    }
    if (ReadTimeRepository.activeBookId === book.id && ReadTimeRepository.activeStartTime > 0) { return; }
    const now = Date.now();
    ReadTimeRepository.activeBookId = book.id;
    ReadTimeRepository.activeBookName = book.title;
    ReadTimeRepository.activeBookAuthor = book.author;
    ReadTimeRepository.activeStartTime = now;
    ReadTimeRepository.activeEndTime = now;
  }

  static touch(): void {
    if (ReadTimeRepository.activeStartTime > 0) { ReadTimeRepository.activeEndTime = Date.now(); }
  }

  static async commit(context: Context): Promise<void> {
    const startTime = ReadTimeRepository.activeStartTime;
    const endTime = ReadTimeRepository.activeEndTime;
    const bookId = ReadTimeRepository.activeBookId;
    const bookName = ReadTimeRepository.activeBookName;
    const bookAuthor = ReadTimeRepository.activeBookAuthor;
    if (startTime <= 0) { return; }
    ReadTimeRepository.activeBookId = '';
    ReadTimeRepository.activeBookName = '';
    ReadTimeRepository.activeBookAuthor = '';
    ReadTimeRepository.activeStartTime = 0;
    ReadTimeRepository.activeEndTime = 0;
    if (endTime - startTime < 10000) { return; }
    const record: ReadTimeRecord = {
      id: `${startTime}-${endTime}`,
      bookId: bookId,
      bookName: bookName,
      bookAuthor: bookAuthor,
      startTime: startTime,
      endTime: endTime,
      durationMs: endTime - startTime
    };
    await ReadTimeRepository.persist(context, record);
  }

  private static persist(context: Context, record: ReadTimeRecord): Promise<void> {
    const operation = ReadTimeRepository.saveQueue.then(async (): Promise<void> => {
      const records = await ReadTimeRepository.load(context);
      records.push(record);
      const rows: string[] = ['v1'];
      const start = Math.max(0, records.length - 5000);
      for (let index = start; index < records.length; index++) {
        const item = records[index];
        if (item === undefined) { continue; }
        rows.push([
          encodeURIComponent(item.id), encodeURIComponent(item.bookId), encodeURIComponent(item.bookName),
          encodeURIComponent(item.bookAuthor), item.startTime.toString(), item.endTime.toString(), item.durationMs.toString()
        ].join('|'));
      }
      const store = await preferences.getPreferences(context, ReadTimeRepository.preferenceName);
      await store.put('records', rows.join('\n'));
      await store.flush();
    });
    ReadTimeRepository.saveQueue = operation.catch(() => {});
    return operation;
  }
}
