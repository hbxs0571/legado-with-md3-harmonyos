// 批3（r359）：单本刷新目录。
// 照上游 legado-with-MD3/.../domain/usecase/RefreshTocUseCase.kt:18-63 的步骤顺序搬：
//   ① 从库里取最新一行（getBook(bookUrl) ?: throw "Book not found"）
//   ② 书源必须还在（getBookSource(book.origin)，null 时打 updateError 位再抛 "Source not found"）
//   ③ oldBook = book.copy()（sync 的兜底快照）
//   ④ tocUrl 为空 → 先取详情；否则不取详情
//   ⑤ 跑一次 preUpdateJs（上游 getBookInfoAwait 内部会跑，RefreshTocUseCase 自己也会跑，
//      净效果都是「取目录前跑一次」，本地在两种分支之后统一跑一次）
//   ⑥ 取目录（getChapterListAwait）
//   ⑦ 写回五个计数（BookChapterList.kt:166-172）
//   ⑧ book.sync(oldBook) 五条保护（进度、章节标题、canUpdate、阅读配置）
//   ⑨ 清 updateError 位
//   ⑩ 标签分组规则（缺组自动建组，上游 applyTagGroupRulesForBook）
//   ⑪ 写回书行 ⑫ 删旧章 ⑬ 写新章
// 失败时对齐上游 onFailure：书还在就打 updateError 位。
import { Book, BookChapter } from '../model/Book';
import { AppLog } from '../lib/AppLog';
import { BookSourceRuntime } from '../bookSource/BookSourceRuntime';
import { RemoteChapter } from '../bookSource/SourceModels';
import { BookGroup } from '../model/BookGroup';
import { TagGroupRule } from '../model/TagGroupRule';
import { BookGroupRepository } from './BookGroupRepository';
import { BookRepository } from './BookRepository';
import { TagGroupRuleRepository } from './TagGroupRuleRepository';
import { TagGroupRuleSync } from './TagGroupRuleSync';

/** 一次刷新的结果。book 为 undefined 表示书已被删除，没写回。 */
export interface TocRefreshOutcome {
  book?: Book;
  chapters: BookChapter[];
}

export class TocRefreshUseCase {
  /** 上游 ReadBook.kt:1813-1819：同一本书 10 分钟内不重复查目录。 */
  static readonly MIN_CHECK_INTERVAL_MS: number = 600000;

  /**
   * 上游 ReadBook.upToc 的两道门 + 书架候选集（BookDao.getHasUpdateBooks：
   * `type & 256 = 0 and canUpdate = 1`）：非本地书、允许更新、且距上次检查超过 10 分钟。
   */
  static needsCheck(book: Book): boolean {
    if (book.isLocal) { return false; }
    if (book.canUpdate === false) { return false; }
    const last = book.lastCheckTime ?? 0;
    return Date.now() - last >= TocRefreshUseCase.MIN_CHECK_INTERVAL_MS;
  }

  /** 按 bookUrl 刷新一本书的目录并落库。失败会打 updateError 位然后抛出。 */
  static async execute(context: Context, bookUrl: string): Promise<TocRefreshOutcome> {
    const current = await BookRepository.getBookByUrl(context, bookUrl);
    if (current === undefined) {
      throw new Error('Book not found');
    }
    const sourceUrl = current.origin ?? '';
    const sourceExists = sourceUrl.length > 0 && BookSourceRuntime.resolve(sourceUrl) !== null;
    if (!sourceExists) {
      // 上游：`if (!book.isUpError) { book.addType(updateError); repo.update(book) }`
      if (current.upError !== true) {
        await TocRefreshUseCase.writeUpError(context, current, true);
      }
      throw new Error('Source not found');
    }
    // ③ 刷新前的快照，给 ⑧ 的 sync 当兜底（库里那一行才是权威）。
    const oldBook = BookRepository.copyBook(current);
    let next = BookRepository.copyBook(current);
    try {
      // ④ 目录地址为空时先取详情（上游 WebBook.getBookInfoAwait）。
      if ((next.tocUrl ?? '').length === 0) {
        const detail = await BookSourceRuntime.detail(sourceUrl, bookUrl);
        const detailTocUrl = detail.tocUrl ?? '';
        if (detailTocUrl.length > 0) {
          next.tocUrl = detailTocUrl;
        }
      }
      // ⑤ preUpdateJs 只跑一次：上游两个分支各跑一次，净效果相同。
      BookSourceRuntime.runPreUpdateJs(sourceUrl);
      // ⑥ 取目录。
      const remote: RemoteChapter[] = await BookSourceRuntime.toc(sourceUrl, bookUrl, next.tocUrl ?? bookUrl);
      const rows = TocRefreshUseCase.toChapterRows(next, remote);
      // ⑦ 写回五个计数（上游 BookChapterList.kt:166-172）：
      //    lastCheckCount 只在新章出现时写；latestChapterTime 同理；
      //    lastCheckTime 无条件写；chapterCount（totalChapterNum）无条件写；最新章节标题取最后一章。
      const previousTotal = Number(next.chapterCount ?? '0');
      if (previousTotal < rows.length) {
        next.lastCheckCount = rows.length - previousTotal;
        next.latestChapterTime = Date.now();
      }
      next.lastCheckTime = Date.now();
      next.chapterCount = String(rows.length);
      if (rows.length > 0) {
        next.latestChapterTitle = rows[rows.length - 1].title;
      }
      // ⑧ sync 五条保护：进度、章节标题、canUpdate、阅读配置一律以库里那一行为准，
      //    否则刷新会把手写进库的阅读进度/开关覆盖成刷新前内存里的旧值。
      next = TocRefreshUseCase.syncWithDatabaseRow(next, oldBook, rows);
      // ⑨ 刷新成功清 updateError 位（上游 book.removeType(updateError)）。
      next.upError = false;
      // ⑩ 标签分组规则：本地 TagGroupRuleSync 只在分组已存在时生效，
      //    而上游对缺组会 getUnusedId 自动建组，所以先把缺的组补出来再 apply。
      await TocRefreshUseCase.ensureRuleGroups(context);
      const ruleApplied = await TagGroupRuleSync.apply([next], TagGroupRuleRepository.getAll());
      if (ruleApplied.length > 0 && ruleApplied[0] !== undefined) {
        next = ruleApplied[0];
      }
      // ⑪ 写回书行（上游 repo.update；本地 bookUrl 不会变，没有 replace 分支）。
      if (BookRepository.isPersistableBook(next)) {
        await BookRepository.saveImportedBooks(context, [next]);
      }
      // ⑫⑬ 先删旧章再写新章（上游 deleteChaptersByBook → insertChapters）。
      await BookRepository.deleteChapters(context, bookUrl);
      await BookRepository.saveChapters(context, bookUrl, rows);
      return { book: next, chapters: rows };
    } catch (e) {
      const message = e instanceof Error ? e.message : String(e);
      // 上游 onFailure：书还在就打 updateError 位，然后向上抛（由调用方记日志）。
      const stillThere = await BookRepository.getBookByUrl(context, bookUrl);
      if (stillThere !== undefined && stillThere.upError !== true) {
        await TocRefreshUseCase.writeUpError(context, stillThere, true);
      }
      AppLog.put(`刷新目录失败：${bookUrl} ${message}`);
      throw new Error(message);
    }
  }

  /** 远程章节 → 本地章节行，口径与 OnlineBookService.getChapterList 完全一致。 */
  private static toChapterRows(book: Book, remote: RemoteChapter[]): BookChapter[] {
    const bookKey = book.contentPath ?? '';
    const rows: BookChapter[] = [];
    for (let index = 0; index < remote.length; index++) {
      const chapter = remote[index];
      const volume = chapter.isVolume === true;
      rows.push({
        url: chapter.url,
        title: chapter.title,
        isVolume: volume,
        tocLevel: volume ? 0 : 1,
        bookUrl: bookKey,
        index: index
      });
    }
    return rows;
  }

  /**
   * 上游 BookExtensions.kt:549-566 Book.sync：curBook = 库里那一行，
   * durChapterTime/durChapterPos 取库里；durChapterIndex 变了才重算 durChapterTitle；
   * canUpdate 取库里；readConfig 取库里。
   * 本地没有 durChapterTitle 单列（books 第 7 列就是它，读出来落在 lastChapter 上），
   * 阅读配置是拆成多个字段存的，所以这里逐项搬。
   */
  private static syncWithDatabaseRow(next: Book, fallback: Book, rows: BookChapter[]): Book {
    const source = fallback;
    const merged = BookRepository.copyBook(next);
    merged.durChapterTime = source.durChapterTime;
    merged.androidCharacterPosition = source.androidCharacterPosition;
    merged.chapterProgress = source.chapterProgress;
    if (next.chapterIndex !== source.chapterIndex) {
      const index = source.chapterIndex ?? 0;
      merged.chapterIndex = index;
      if (rows.length > 0) {
        const target = rows[index] ?? rows[rows.length - 1];
        merged.lastChapter = target.title;
      }
    }
    merged.canUpdate = source.canUpdate;
    merged.imageStyle = source.imageStyle;
    merged.pageAnim = source.pageAnim;
    merged.readSimulating = source.readSimulating;
    merged.startDate = source.startDate;
    merged.startChapter = source.startChapter;
    merged.dailyChapters = source.dailyChapters;
    merged.reSegment = source.reSegment;
    merged.delTag = source.delTag;
    merged.useReplaceRule = source.useReplaceRule;
    merged.fixedType = source.fixedType;
    return merged;
  }

  /** 上游 getUnusedId 自动建组：规则里的分组名本地不存在就先建出来。 */
  private static async ensureRuleGroups(context: Context): Promise<void> {
    const rules: TagGroupRule[] = TagGroupRuleRepository.getAll();
    if (rules.length === 0) { return; }
    const known: BookGroup[] = BookGroupRepository.getAll();
    const missing: string[] = [];
    for (const rule of rules) {
      const name = rule.groupName.trim();
      if (name.length === 0 || missing.includes(name)) { continue; }
      if (known.some((group: BookGroup) => group.groupName === name)) { continue; }
      missing.push(name);
    }
    for (const name of missing) {
      try {
        await BookGroupRepository.add(context, name);
      } catch (e) {
        // 并发下可能已被别的书建过，忽略即可（上游同样只关心最终存在）。
        AppLog.put(`自动建分组失败：${name} ${e instanceof Error ? e.message : String(e)}`);
      }
    }
  }

  /** 打/清 updateError 位。入参必须是刚从库里读出的那一行（整行 upsert，别拿旧对象冲掉别人的列）。 */
  private static async writeUpError(context: Context, book: Book, upError: boolean): Promise<void> {
    try {
      const updated = BookRepository.copyBook(book);
      updated.upError = upError;
      if (BookRepository.isPersistableBook(updated)) {
        await BookRepository.saveImportedBooks(context, [updated]);
      }
    } catch (e) {
      AppLog.put(`写入更新出错标记失败：${e instanceof Error ? e.message : String(e)}`);
    }
  }
}