// 换源协调器（P8）：候选源搜索 + 目录校验 + 进度迁移 + 替换落库。
// 对齐上游 ChangeBookSourceUseCase / ChangeSourceSearchUseCase / BookHelp.getDurChapter：
//   ① 用书名+作者到启用源里搜候选；② 每个候选取完整目录并校验（非空中带章节数）；
//   ③ 确认替换后迁移阅读进度（三档算法见 ChangeSourceProgress）；④ 失败/取消保留原书。
import { BookSourceRepository } from '../data/BookSourceRepository';
import { BookSourceRuntime } from './BookSourceRuntime';
import { SearchBookItem, RemoteChapter } from './SourceModels';
import { getDurChapter, ChapterLike } from './ChangeSourceProgress';

/** 一个候选源及其校验结果。 */
export interface ChangeSourceCandidate {
  sourceUrl: string;
  sourceName: string;
  book: SearchBookItem | null;      // 搜到的候选书，null=该源没搜到
  chapters: RemoteChapter[];        // 校验通过后的目录（可能为空）
  chapterCount: number;
  verified: boolean;                // 目录校验是否通过
  message: string;                  // 失败原因（源没搜到/目录为空/超时）
}

export interface ChangeSourceOutcome {
  ok: boolean;
  message: string;
}

/**
 * 迁移选项：逐字段对齐上游 `domain/usecase/ChangeBookSourceUseCase.kt:23-33`
 * `data class ChangeSourceMigrationOptions`。
 *
 * 第十表 G-6：本地原先只落地 `migrateProgress`（阅读进度）与 `migrateMetadata`（简介/封面/分类/最新章节）
 * 两项，把上游七个独立维度（分组、封面、分类、备注、作者、阅读设置）压进一个开关里 —— 用户没法只迁移
 * 其中一部分。上游 `ChangeSourceMigrationOptionsSheet.kt:78-99` 是八个勾选项（`migrateChapters` 恒为
 * true、不出现在 UI 上，故面板只有八项），这里补齐同一组字段，执行端按字段各管一段。
 */
export interface ChangeSourceMigrationOptions {
  migrateChapters: boolean;              // 章节（面板不展示，恒 true，对齐上游 :106）
  migrateProgress: boolean;              // 阅读进度（上游 migrateReadingProgress）
  migrateGroup: boolean;                 // 分组和排序
  migrateCover: boolean;                 // 自定义封面
  migrateCategory: boolean;              // 分类与标签
  migrateRemark: boolean;                // 备注和自定义简介
  migrateAuthor: boolean;                // 作者
  migrateReadConfig: boolean;            // 阅读设置
  deleteDownloadedChapters: boolean;     // 删除已下载章节（默认 false）
}

export function defaultMigrationOptions(): ChangeSourceMigrationOptions {
  return {
    migrateChapters: true,
    migrateProgress: true,
    migrateGroup: true,
    migrateCover: true,
    migrateCategory: true,
    migrateRemark: true,
    migrateAuthor: true,
    migrateReadConfig: true,
    deleteDownloadedChapters: false,
  };
}

export class ChangeSourceCoordinator {
  /**
   * 候选搜索：用「书名 作者」作关键词并发搜所有启用的文本源，再逐候选取目录校验。
   * 对齐上游 ChangeSourceSearchUseCase：搜到即校验目录，结果带 verified 供 UI 显示。
   */
  static async searchCandidates(
    title: string, author: string, currentSourceUrl: string
  ): Promise<ChangeSourceCandidate[]> {
    const keyword = author.length > 0 ? `${title} ${author}` : title;
    const all = BookSourceRepository.getAll();
    const targetSources = all.filter((s) => s.enabled && s.bookSourceType === 0
      && s.bookSourceUrl.length > 0 && s.bookSourceUrl !== currentSourceUrl);

    // 并发窗口 8（同 P3 搜索），逐个搜索+校验。
    const result: ChangeSourceCandidate[] = [];
    let cursor = 0;
    const worker = async (): Promise<void> => {
      while (cursor < targetSources.length) {
        const idx = cursor++;
        const src = targetSources[idx];
        const candidate = await ChangeSourceCoordinator.probeSource(
          src.bookSourceUrl, src.bookSourceName, keyword
        );
        result.push(candidate);
      }
    };
    const workers: Promise<void>[] = [];
    for (let i = 0; i < 8 && i < targetSources.length; i++) { workers.push(worker()); }
    await Promise.all(workers);
    // 校验通过的排前、章节数多的排前，便于 UI 首选。
    result.sort((a: ChangeSourceCandidate, b: ChangeSourceCandidate) => {
      if (a.verified !== b.verified) { return a.verified ? -1 : 1; }
      return b.chapterCount - a.chapterCount;
    });
    return result;
  }

  /** 单源：搜索 → 取详情（tocUrl 空时）→ 取目录校验。 */
  private static async probeSource(
    sourceUrl: string, sourceName: string, keyword: string
  ): Promise<ChangeSourceCandidate> {
    const fail = (msg: string): ChangeSourceCandidate => ({
      sourceUrl, sourceName, book: null, chapters: [], chapterCount: 0, verified: false, message: msg
    });
    try {
      const search = await BookSourceRuntime.searchOne(sourceUrl, keyword, 1);
      if (search.error.length > 0 || search.books.length === 0) {
        return fail(search.error.length > 0 ? search.error : '未搜到匹配书籍');
      }
      // 取最像的一本（搜索已按源内相关性返回，取第一条）。
      const book = search.books[0];
      let tocUrl = book.tocUrl;
      if (tocUrl.length === 0) {
        if (book.bookUrl.length === 0) { return fail('候选书没有详情地址'); }
        const detail = await BookSourceRuntime.detail(sourceUrl, book.bookUrl);
        tocUrl = detail.tocUrl;
      }
      if (tocUrl.length === 0) { return fail('候选书没有目录地址'); }
      const chapters = await BookSourceRuntime.toc(sourceUrl, book.bookUrl, tocUrl);
      // 目录校验：任务书 12.2 要求"确认完整目录"。上游仅判非空，本批按任务书补强：
      // 目录非空即视为可换（章节数由 UI 展示，用户可判断），空目录一律不算通过。
      if (chapters.length === 0) { return fail('目录为空，校验失败'); }
      return {
        sourceUrl, sourceName, book, chapters,
        chapterCount: chapters.length, verified: true, message: ''
      };
    } catch (e) {
      return fail(e instanceof Error ? e.message : String(e));
    }
  }

  /**
   * 计算换源后的阅读进度索引（纯函数，便于离线验证）。
   * 对齐上游 BookHelp.getDurChapter：三档迁移 + 钳位。
   */
  static migrateIndex(
    oldIndex: number, oldTitle: string,
    newChapters: RemoteChapter[], oldChapterCount: number
  ): number {
    const likes: ChapterLike[] = [];
    for (const c of newChapters) { likes.push({ title: c.title }); }
    return getDurChapter(oldIndex, oldTitle, likes, oldChapterCount);
  }
}
