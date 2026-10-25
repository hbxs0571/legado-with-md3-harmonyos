import { preferences } from '@kit.ArkData';
import { ReaderBookmark } from '../model/ReaderBookmark';

export class ReaderBookmarkRepository {
  private static readonly preferenceName: string = 'legado_reader_bookmarks';
  private static saveQueue: Promise<void> = Promise.resolve();

  static async load(context: Context): Promise<ReaderBookmark[]> {
    try {
      const store = await preferences.getPreferences(context, ReaderBookmarkRepository.preferenceName);
      const value = await store.get('records', 'v1\n');
      if (typeof value !== 'string' || !value.startsWith('v1\n')) { return []; }
      const rows = value.substring(3).split('\n');
      const bookmarks: ReaderBookmark[] = [];
      for (let index = 0; index < rows.length; index++) {
        const row = rows[index];
        if (row === undefined || row.length === 0) { continue; }
        const fields = row.split('|');
        if (fields.length !== 11) { continue; }
        try {
          const chapterIndex = Number(fields[5]);
          const chapterPosition = Number(fields[7]);
          const createdAt = Number(fields[10]);
          if (!Number.isInteger(chapterIndex) || chapterIndex < 0 ||
            !Number.isInteger(chapterPosition) || chapterPosition < 0 ||
            !Number.isFinite(createdAt) || createdAt <= 0) { continue; }
          bookmarks.push({
            id: decodeURIComponent(fields[0]),
            bookId: decodeURIComponent(fields[1]),
            bookName: decodeURIComponent(fields[2]),
            bookAuthor: decodeURIComponent(fields[3]),
            bookUrl: decodeURIComponent(fields[4]),
            chapterIndex: chapterIndex,
            chapterName: decodeURIComponent(fields[6]),
            chapterPosition: chapterPosition,
            bookText: decodeURIComponent(fields[8]),
            content: decodeURIComponent(fields[9]),
            createdAt: createdAt
          });
        } catch (_) {
          continue;
        }
      }
      return bookmarks;
    } catch (_) {
      return [];
    }
  }

  static save(context: Context, bookmarks: ReaderBookmark[]): Promise<void> {
    const operation = ReaderBookmarkRepository.saveQueue.then(async (): Promise<void> => {
      const rows: string[] = ['v1'];
      for (let index = 0; index < bookmarks.length; index++) {
        const bookmark = bookmarks[index];
        if (bookmark === undefined) { continue; }
        rows.push([
          encodeURIComponent(bookmark.id), encodeURIComponent(bookmark.bookId),
          encodeURIComponent(bookmark.bookName), encodeURIComponent(bookmark.bookAuthor),
          encodeURIComponent(bookmark.bookUrl), bookmark.chapterIndex.toString(),
          encodeURIComponent(bookmark.chapterName), bookmark.chapterPosition.toString(),
          encodeURIComponent(bookmark.bookText), encodeURIComponent(bookmark.content),
          bookmark.createdAt.toString()
        ].join('|'));
      }
      const store = await preferences.getPreferences(context, ReaderBookmarkRepository.preferenceName);
      await store.put('records', rows.join('\n'));
      await store.flush();
    });
    ReaderBookmarkRepository.saveQueue = operation.catch(() => {});
    return operation;
  }
}
