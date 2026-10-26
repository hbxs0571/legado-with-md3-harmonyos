import { preferences } from '@kit.ArkData';
import { Book } from '../model/Book';
import { ReaderSearchHistoryEntry } from '../model/ReaderSearchHistory';

export class ReaderSearchHistoryRepository {
  private static readonly preferenceName: string = 'legado_reader_search_history';
  private static readonly preferenceKey: string = 'records_v1';

  static async load(context: Context): Promise<ReaderSearchHistoryEntry[]> {
    try {
      const store = await preferences.getPreferences(context, ReaderSearchHistoryRepository.preferenceName);
      const saved = await store.get(ReaderSearchHistoryRepository.preferenceKey, '[]');
      if (typeof saved !== 'string') { return []; }
      const parsed: ReaderSearchHistoryEntry[] = JSON.parse(saved);
      const valid = parsed.filter((entry: ReaderSearchHistoryEntry) =>
        typeof entry.id === 'string' &&
        typeof entry.bookId === 'string' &&
        typeof entry.bookName === 'string' &&
        typeof entry.bookAuthor === 'string' &&
        typeof entry.query === 'string' &&
        entry.query.trim().length > 0 &&
        Number.isFinite(entry.updatedAt));
      return valid
        .map((entry: ReaderSearchHistoryEntry): ReaderSearchHistoryEntry => ({
          id: entry.id,
          bookId: entry.bookId,
          bookName: entry.bookName,
          bookAuthor: entry.bookAuthor,
          query: entry.query,
          updatedAt: entry.updatedAt
        }))
        .sort((left: ReaderSearchHistoryEntry, right: ReaderSearchHistoryEntry) =>
          right.updatedAt - left.updatedAt);
    } catch (_) {
      return [];
    }
  }

  static async saveQuery(context: Context, book: Book, query: string): Promise<ReaderSearchHistoryEntry[]> {
    const normalized = query.trim();
    if (normalized.length === 0) { return ReaderSearchHistoryRepository.load(context); }
    const current = await ReaderSearchHistoryRepository.load(context);
    const id = encodeURIComponent(book.id) + '|' + encodeURIComponent(normalized);
    const next = current.filter((entry: ReaderSearchHistoryEntry) => entry.id !== id);
    next.push({
      id: id,
      bookId: book.id,
      bookName: book.title,
      bookAuthor: book.author,
      query: normalized,
      updatedAt: Date.now()
    });
    await ReaderSearchHistoryRepository.store(context, next);
    return next.sort((left: ReaderSearchHistoryEntry, right: ReaderSearchHistoryEntry) =>
      right.updatedAt - left.updatedAt);
  }

  static async delete(context: Context, id: string): Promise<ReaderSearchHistoryEntry[]> {
    const current = await ReaderSearchHistoryRepository.load(context);
    const next = current.filter((entry: ReaderSearchHistoryEntry) => entry.id !== id);
    await ReaderSearchHistoryRepository.store(context, next);
    return next;
  }

  static async clear(
    context: Context,
    bookId: string,
    onlyThisBook: boolean
  ): Promise<ReaderSearchHistoryEntry[]> {
    const current = await ReaderSearchHistoryRepository.load(context);
    const next = onlyThisBook
      ? current.filter((entry: ReaderSearchHistoryEntry) => entry.bookId !== bookId)
      : [];
    await ReaderSearchHistoryRepository.store(context, next);
    return next;
  }

  private static async store(context: Context, entries: ReaderSearchHistoryEntry[]): Promise<void> {
    const store = await preferences.getPreferences(context, ReaderSearchHistoryRepository.preferenceName);
    await store.put(ReaderSearchHistoryRepository.preferenceKey, JSON.stringify(entries));
    await store.flush();
  }
}
