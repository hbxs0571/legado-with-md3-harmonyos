// 多源搜索结果合并器（P3）：照上游 SearchBooksUseCase.SearchResultMerger 的四桶口径。
// 同 key（书名+作者）的来源并进 origins；桶内按 origins.size 降序 —— 多源命中排前面。
import { SearchBookItem } from './SourceModels';

/** 合并后的条目：原始条目 + 命中的全部书源 URL。 */
export interface MergedBook {
  book: SearchBookItem;
  origins: string[];
  /** 展示用的来源数（UI 卡片角标）。 */
  originCount: number;
}

/** 单桶：JS Map 保持插入顺序，等价于上游 LinkedHashMap。 */
type Bucket = Map<string, MergedBook>;

export class SearchResultMerger {
  private keyword: string;
  private exactMatch: boolean;
  private equalBooks: Bucket = new Map<string, MergedBook>();
  private tagsBooks: Bucket = new Map<string, MergedBook>();
  private containsBooks: Bucket = new Map<string, MergedBook>();
  private otherBooks: Bucket = new Map<string, MergedBook>();
  /** bookUrl → 所在桶的 key，处理同 URL 跨源重复。 */
  private urlIndex: Map<string, string> = new Map<string, string>();
  private static readonly MAX_RESULTS: number = 1000;

  constructor(keyword: string, exactMatch: boolean) {
    this.keyword = keyword.trim().toLocaleLowerCase();
    this.exactMatch = exactMatch;
  }

  /** 四桶归类（对齐上游 classifyBucket :300-315）。返回 null 表示该条被过滤掉。 */
  private classify(book: SearchBookItem): Bucket | null {
    const name = book.name.toLocaleLowerCase();
    const author = book.author.toLocaleLowerCase();
    if (name === this.keyword || author === this.keyword) { return this.equalBooks; }
    const kind = (book.kind ?? '').toLocaleLowerCase();
    if (kind.includes(this.keyword)) { return this.exactMatch ? null : this.tagsBooks; }
    if (name.includes(this.keyword) || author.includes(this.keyword)) {
      return this.exactMatch ? null : this.containsBooks;
    }
    return this.exactMatch ? null : this.otherBooks;
  }

  private static makeKey(book: SearchBookItem): string {
    return book.name + '\u0000' + book.author;
  }

  private static findBucket(buckets: Bucket[], key: string): Bucket | null {
    for (const bucket of buckets) {
      if (bucket.has(key)) { return bucket; }
    }
    return null;
  }

  private allBuckets(): Bucket[] {
    return [this.equalBooks, this.tagsBooks, this.containsBooks, this.otherBooks];
  }

  /** 合并一条结果：同 URL 或同 key 时并进已有条目的 origins。 */
  merge(book: SearchBookItem): void {
    if (book.name.length === 0 && book.bookUrl.length === 0) { return; }
    const buckets = this.allBuckets();
    const existingKey = this.urlIndex.get(book.bookUrl);
    if (existingKey !== undefined) {
      const bucket = SearchResultMerger.findBucket(buckets, existingKey);
      const existing = bucket?.get(existingKey);
      if (bucket !== null && existing !== undefined) {
        SearchResultMerger.addOrigin(existing, book.origin);
        return;
      }
    }
    const target = this.classify(book);
    if (target === null) { return; }
    const key = SearchResultMerger.makeKey(book);
    const current = target.get(key);
    if (current !== undefined) {
      SearchResultMerger.addOrigin(current, book.origin);
      return;
    }
    const merged: MergedBook = { book: book, origins: [book.origin], originCount: 1 };
    target.set(key, merged);
    this.urlIndex.set(book.bookUrl, key);
    this.trimIfNeeded();
  }

  private static addOrigin(target: MergedBook, origin: string): void {
    if (origin.length > 0 && !target.origins.includes(origin)) {
      target.origins.push(origin);
      target.originCount = target.origins.length;
    }
  }

  /** 超过上限时从最低优先级桶的末尾删一条（对齐上游 trimSearchBooks 的简化版）。 */
  private trimIfNeeded(): void {
    if (this.count() <= SearchResultMerger.MAX_RESULTS) { return; }
    const buckets = [this.otherBooks, this.containsBooks, this.tagsBooks, this.equalBooks];
    for (const bucket of buckets) {
      if (bucket.size === 0) { continue; }
      const firstKey = bucket.keys().next().value as string;
      const removed = bucket.get(firstKey);
      bucket.delete(firstKey);
      if (removed !== undefined) { this.urlIndex.delete(removed.book.bookUrl); }
      return;
    }
  }

  count(): number {
    let total = 0;
    for (const bucket of this.allBuckets()) { total += bucket.size; }
    return total;
  }

  /** 桶内按来源数降序重排，桶间按 equal→tags→contains→other 拼接。 */
  getSortedList(): MergedBook[] {
    const result: MergedBook[] = [];
    for (const bucket of this.allBuckets()) {
      const items = Array.from(bucket.values());
      items.sort((a: MergedBook, b: MergedBook) => b.originCount - a.originCount);
      for (const item of items) { result.push(item); }
    }
    return result;
  }
}
