import { Book } from '../model/Book';
import { BookGroup } from '../model/BookGroup';

/**
 * 书架排序。
 *
 * 逐档对齐上游 app/src/main/java/io/legado/app/data/repository/BookshelfRepository.kt 的 sortBooks()：
 * 分组的 bookSort 只要 >= 0 就覆盖书架全局排序，否则跟随全局。
 * 时间戳缺失（旧数据或从未读过）按 0 处理，与上游 Kotlin Long 默认值一致。
 */
export class BookshelfSort {
  /** 书架全局排序方式，对应上游 PreferKey.bookshelfSort 的默认值 0（按最近列表）。 */
  static readonly defaultSort: number = 0;
  /** 书架全局排序方向，对应上游 PreferKey.bookshelfSortOrder 的默认值 1（倒序）。 */
  static readonly defaultSortOrder: number = 1;

  /**
   * 排序入口。
   *
   * @param books 待排序书籍
   * @param group 当前筛选的分组；「全部」等内置分组传 undefined
   * @param sort 书架全局排序方式
   * @param sortOrder 书架全局排序方向，1 为倒序
   */
  static sortBooks(books: Book[], group: BookGroup | undefined, sort: number, sortOrder: number): Book[] {
    const bookSort = group !== undefined && group.bookSort >= 0 ? group.bookSort : sort;
    const isDescending = sortOrder === 1;
    const result: Book[] = books.slice();
    // 用 Array.prototype.sort 而不是各档单独 sortedBy，排序稳定，避免同值书籍来回跳。
    result.sort((left: Book, right: Book): number => {
      const compared = BookshelfSort.compareBySort(left, right, bookSort);
      return isDescending ? -compared : compared;
    });
    return result;
  }

  /** 单档比较；只处理升序，方向由调用方统一取反。 */
  private static compareBySort(left: Book, right: Book, bookSort: number): number {
    if (bookSort === 1) {
      return BookshelfSort.compareNumber(left.latestChapterTime, right.latestChapterTime);
    }
    if (bookSort === 2) {
      return BookshelfSort.cnCompare(left.title, right.title);
    }
    if (bookSort === 3) {
      return BookshelfSort.compareNumber(left.order, right.order);
    }
    if (bookSort === 4) {
      return BookshelfSort.compareNumber(BookshelfSort.latestOrRead(left), BookshelfSort.latestOrRead(right));
    }
    if (bookSort === 5) {
      return BookshelfSort.cnCompare(left.author, right.author);
    }
    // 其余（含 0 按最近列表）都按最后阅读时间。
    return BookshelfSort.compareNumber(left.durChapterTime, right.durChapterTime);
  }

  /** 综合排序取「最近更新」与「最后阅读」中较大的那个。 */
  private static latestOrRead(book: Book): number | undefined {
    const latest = book.latestChapterTime ?? 0;
    const read = book.durChapterTime ?? 0;
    return latest > read ? latest : read;
  }

  private static compareNumber(left: number | undefined, right: number | undefined): number {
    const leftValue = left ?? 0;
    const rightValue = right ?? 0;
    if (leftValue === rightValue) { return 0; }
    return leftValue < rightValue ? -1 : 1;
  }

  /**
   * 中文按拼音比较，对应上游 String.cnCompare（Collator.getInstance(SIMPLIFIED_CHINESE)）。
   *
   * 这里用 localeCompare 指定简体中文；若运行环境不支持该 locale 就退回默认比较，
   * 最坏情况只是中文顺序退化为码位顺序，不会抛错中断排序。
   */
  private static cnCompare(left: string, right: string): number {
    try {
      return left.localeCompare(right, 'zh-Hans-CN');
    } catch (_) {
      return left < right ? -1 : left > right ? 1 : 0;
    }
  }
}
