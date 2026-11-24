/**
 * 内容质量检测，逐项对齐上游 `domain/usecase/CheckBookContentQualityUseCase.kt`（188 行）。
 *
 * 四段流水线（上游 `ContentQualityStage`）：
 *   ChapterCount → ContentCleaning → KeywordMatching → Excluding → Completed
 *
 * 判据（上游 `checkBook`）：
 *   1. `chapterSpec` 里的最大章节号 > 目录长度 → 排除，原因「章节数不足」
 *   2. `chapterSpec` 解析不出任何有效章节 → 排除，原因「没有可检测的章节」
 *   3. 逐章取正文（单章失败只跳过该章，不误杀整本源）
 *   4. `excluded = sampledChapterCount > 0 && keywordHits == 0`
 *   5. 整本检测失败（目录拉取异常等）→ **不算排除**，只记 errorMessage
 */
import { BookSourceRuntime } from './BookSourceRuntime';
import { RemoteChapter, SearchBookItem } from './SourceModels';
import { ContentQualityResultUi, ContentQualityStage } from './SearchContract';

/** 上游 `ContentQualityConfig`。 */
export interface ContentQualityConfig {
  chapterSpec: string;
  keywords: string[];
  skipHeadChars: number;
}

/** 上游 `ContentQualityProgress`。 */
export interface ContentQualityProgress {
  stage: ContentQualityStage;
  processedBooks: number;
  totalBooks: number;
  currentBookName: string;
}

/** 是否已被取消（对应上游 `coroutineContext.ensureActive()`）。 */
export type ContentQualityCancelCheck = () => boolean;

export class ContentQualityChecker {
  /** 上游 `qualityKey() = "$origin:$bookUrl"`。 */
  static qualityKey(book: SearchBookItem): string {
    return `${book.origin}:${book.bookUrl}`;
  }

  /**
   * 上游 `execute(books, config, onProgress)`：
   * 逐本检测，每本开始前发 ChapterCount 进度，全部结束后发 Completed。
   * `onResult` 是本地新增的逐本回调：上游把结果直接写进 `state.contentQuality.results` 映射，
   * 本地页面需要一个「每算完一本就能点亮遮罩」的入口，故额外给一个可选回调。
   */
  static async execute(
    books: SearchBookItem[],
    config: ContentQualityConfig,
    onProgress: (progress: ContentQualityProgress) => void,
    shouldCancel: ContentQualityCancelCheck,
    onResult?: (result: ContentQualityResultUi, key: string) => void
  ): Promise<ContentQualityResultUi[]> {
    const results: ContentQualityResultUi[] = [];
    for (let index = 0; index < books.length; index++) {
      if (shouldCancel()) { return results; }
      const book = books[index];
      onProgress({
        stage: ContentQualityStage.ChapterCount,
        processedBooks: index,
        totalBooks: books.length,
        currentBookName: book.name
      });
      const result = await ContentQualityChecker.checkBook(
        book, config, index, books.length, onProgress, shouldCancel
      );
      results.push(result);
      if (onResult !== undefined) {
        onResult(result, ContentQualityChecker.qualityKey(book));
      }
    }
    onProgress({
      stage: ContentQualityStage.Completed,
      processedBooks: books.length,
      totalBooks: books.length,
      currentBookName: ''
    });
    return results;
  }

  /** 上游 `checkBook`：单本检测，任何异常都吞成 errorMessage 且 excluded=false。 */
  private static async checkBook(
    book: SearchBookItem,
    config: ContentQualityConfig,
    processedBooks: number,
    totalBooks: number,
    onProgress: (progress: ContentQualityProgress) => void,
    shouldCancel: ContentQualityCancelCheck
  ): Promise<ContentQualityResultUi> {
    const bookKey = ContentQualityChecker.qualityKey(book);
    const sourceName = book.originName.trim().length > 0 ? book.originName : book.origin;
    const excludedResult = (reason: string): ContentQualityResultUi => {
      return {
        sourceName: sourceName,
        sampledChapterCount: 0,
        matchedChapterCount: 0,
        keywordHits: 0,
        excluded: true,
        errorMessage: reason
      };
    };
    try {
      // 上游 `chapterContentUseCase.getToc(book.toBook())` 取目录
      const toc: RemoteChapter[] = await BookSourceRuntime.toc(book.origin, book.bookUrl, book.tocUrl);
      // 上游 `requestedMaximum = Regex("\\d+").findAll(chapterSpec).maxOrNull()`
      let requestedMaximum = -1;
      for (const match of config.chapterSpec.match(/\d+/g) ?? []) {
        const value = Number.parseInt(match, 10);
        if (!Number.isNaN(value) && value > requestedMaximum) { requestedMaximum = value; }
      }
      if (requestedMaximum >= 0 && requestedMaximum > toc.length) {
        return excludedResult('章节数不足');
      }
      const chapterIndices = ContentQualityChecker.parseChapterIndices(config.chapterSpec, toc.length);
      if (chapterIndices.length === 0) {
        return excludedResult('没有可检测的章节');
      }

      let sampledChapterCount = 0;
      let matchedChapterCount = 0;
      let keywordHits = 0;
      for (const chapterIndex of chapterIndices) {
        if (shouldCancel()) { break; }
        onProgress({
          stage: ContentQualityStage.ContentCleaning,
          processedBooks: processedBooks,
          totalBooks: totalBooks,
          currentBookName: book.name
        });
        const chapter = toc[chapterIndex - 1];
        // 单章失败（网络抖动等瞬时错误）只跳过该章，不把整个书源判为排除
        let content = '';
        try {
          content = await BookSourceRuntime.content(book.origin, chapter.url);
        } catch (error) {
          continue;
        }
        sampledChapterCount += 1;
        const cleaned = ContentQualityChecker.cleanContent(content, config.skipHeadChars);
        onProgress({
          stage: ContentQualityStage.KeywordMatching,
          processedBooks: processedBooks,
          totalBooks: totalBooks,
          currentBookName: book.name
        });
        let chapterHits = 0;
        for (const keyword of config.keywords) {
          chapterHits += ContentQualityChecker.countOccurrences(cleaned, keyword);
        }
        keywordHits += chapterHits;
        if (chapterHits > 0) { matchedChapterCount += 1; }
      }

      const excluded = sampledChapterCount > 0 && keywordHits === 0;
      onProgress({
        stage: ContentQualityStage.Excluding,
        processedBooks: processedBooks,
        totalBooks: totalBooks,
        currentBookName: book.name
      });
      return {
        sourceName: sourceName,
        sampledChapterCount: sampledChapterCount,
        matchedChapterCount: matchedChapterCount,
        keywordHits: keywordHits,
        excluded: excluded,
        errorMessage: ''
      };
    } catch (error) {
      // 整本检测失败：不算排除，只记录原因，避免瞬时错误误杀书源
      const message = error instanceof Error ? error.message : String(error);
      return {
        sourceName: sourceName,
        sampledChapterCount: 0,
        matchedChapterCount: 0,
        keywordHits: 0,
        excluded: false,
        errorMessage: message.length > 0 ? message : '检测失败'
      };
    }
  }

  /**
   * 上游 `parseChapterIndices(spec, totalChapterCount)`：
   * 支持 `1,3,5` 与 `1-5`、`1~5`、`1至5`、`1到5`；越界剔除、去重、保持出现顺序。
   */
  static parseChapterIndices(spec: string, totalChapterCount: number): number[] {
    if (totalChapterCount <= 0) { return []; }
    const result: number[] = [];
    const pattern = /\d+(?:\s*[-~至到]\s*\d+)?/g;
    const matches = spec.match(pattern) ?? [];
    for (const match of matches) {
      const parts = match.split(/\s*[-~至到]\s*/);
      const start = Number.parseInt(parts[0], 10);
      if (Number.isNaN(start)) { continue; }
      const endRaw = parts.length > 1 ? Number.parseInt(parts[1], 10) : start;
      const end = Number.isNaN(endRaw) ? start : endRaw;
      const low = Math.min(start, end);
      const high = Math.max(start, end);
      for (let value = low; value <= high; value++) {
        if (value < 1 || value > totalChapterCount) { continue; }
        if (result.includes(value)) { continue; }
        result.push(value);
      }
    }
    return result;
  }

  /** 上游 `cleanContent(content, skipHeadChars)`：去标签 → 压空白 → trim → 丢弃头部 N 字。 */
  static cleanContent(content: string, skipHeadChars: number): string {
    const stripped = content.replace(/<[^>]*>/g, ' ').replace(/\s+/g, ' ').trim();
    const skip = skipHeadChars > 0 ? skipHeadChars : 0;
    return skip >= stripped.length ? '' : stripped.substring(skip);
  }

  /** 上游 `countOccurrences(content, keyword)`：大小写不敏感、不重叠计数。 */
  static countOccurrences(content: string, keyword: string): number {
    if (keyword.trim().length === 0) { return 0; }
    const haystack = content.toLowerCase();
    const needle = keyword.toLowerCase();
    let count = 0;
    let start = 0;
    while (start < haystack.length) {
      const index = haystack.indexOf(needle, start);
      if (index < 0) { break; }
      count += 1;
      start = index + Math.max(needle.length, 1);
    }
    return count;
  }
}
