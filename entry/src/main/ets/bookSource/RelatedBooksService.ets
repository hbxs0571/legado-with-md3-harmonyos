// 关联书籍：对齐上游 `model/webBook/RelatedBooks.kt` 与 `BookInfoViewModel.kt:1990-2076`。
//
// 两条来源：
// ①书源在 `ruleBookInfo.relatedBooks` 里配了模块（JSON 数组，每项 { key, title, url }），
//   逐个 url 走一次「发现」拿到书单；单个模块失败不影响其他模块。
// ②一条模块都没有、且 `bookInfoAuthorSearchFallback` 开着时，用当前书源按作者名搜第一页，
//   过滤出作者一致、非当前书的条目，作为「作者其它作品」模块。
//
// 本地引擎的 `BookInfoRule`（third_party/harmony-book-source-engine/sourceengine/src/main/ets/model/data/Book.ts:429-442）
// 没有 `relatedBooks` 字段，但本地书源把整条原始 JSON 存在 `BookSource.sourceJson` 里，
// 所以这里直接从原始 JSON 取 `ruleBookInfo.relatedBooks`，不需要引擎改动。
import { BookSource as LocalBookSource } from '../model/BookSource';
import { BookSourceRepository } from '../data/BookSourceRepository';
import { BookSourceRuntime } from './BookSourceRuntime';
import { SearchBookItem } from './SourceModels';
import { WebBookService } from './WebBookService';
import { AppLog } from '../lib/AppLog';

/** 一个关联书籍模块，对齐上游 `RelatedBooks.Module`。 */
export interface RelatedBooksModule {
  key: string;
  title: string;
  /** 书源里配的分类地址模板（可能含 {{page}}），用于展示与调试。 */
  url: string;
  /** 展开后实际请求的地址；空串表示「没有更多页可看」，对应上游 `showMore = resolvedUrl.isNotBlank()`。 */
  resolvedUrl: string;
  books: SearchBookItem[];
}

/** 书源里 relatedBooks 的一项，对齐上游 `RelatedBooks.Definition`。 */
interface RelatedBooksDefinition {
  key: string;
  title: string;
  url: string;
}

/** 上游 `AUTHOR_OTHER_WORKS_KEY = "author-other-works"`（BookInfoViewModel.kt:2135）。 */
export const AUTHOR_OTHER_WORKS_KEY: string = 'author-other-works';

/** 上游 `R.string.book_other_works`（values-zh-rCN/strings.xml:1750）。 */
export const AUTHOR_OTHER_WORKS_TITLE: string = '作者其它作品';

/**
 * 上游 `AppPattern.authorRegex = Regex("^\\s*作\\s*者[:：\\s]+|\\s+著")`（constant/AppPattern.kt:36）。
 * 作者字段里常见的「作者：」「著」这类前后缀要先去掉再比对，否则同一作者会被判成两个人。
 */
const AUTHOR_PREFIX_REGEX: RegExp = /^\s*作\s*者[:：\s]+/;
const AUTHOR_SUFFIX_REGEX: RegExp = /\s+著/;

/** 上游 `normalizeAuthorName`（BookInfoViewModel.kt:2040-2042）。 */
export function normalizeAuthorName(author: string): string {
  return author.replace(AUTHOR_PREFIX_REGEX, '').replace(AUTHOR_SUFFIX_REGEX, '').trim();
}

export class RelatedBooksService {
  /**
   * 从本地书源原始 JSON 里读 `ruleBookInfo.relatedBooks`。
   * 上游 `RelatedBooks.load` 传的就是 `source.ruleBookInfo?.relatedBooks`；
   * 本地引擎投影会丢掉这个字段，所以改从 sourceJson 现取。
   */
  static relatedBooksJson(sourceUrl: string): string {
    const all: LocalBookSource[] = BookSourceRepository.getAll();
    for (const local of all) {
      if (local.bookSourceUrl !== sourceUrl) {
        continue;
      }
      try {
        const root = JSON.parse(local.sourceJson) as Record<string, Object>;
        const ruleBookInfo = root['ruleBookInfo'];
        if (ruleBookInfo === undefined || ruleBookInfo === null) {
          return '';
        }
        const value = (ruleBookInfo as Record<string, Object>)['relatedBooks'];
        return typeof value === 'string' ? value : '';
      } catch (error) {
        AppLog.put(`解析书源 relatedBooks 失败 书源:${local.bookSourceName} ${error instanceof Error ? error.message : String(error)}`);
        return '';
      }
    }
    return '';
  }

  /** 解析 relatedBooks 的 JSON 数组；结构不合法时返回空数组（对齐上游 `GSON.fromJsonArray` 失败即空）。 */
  static parseDefinitions(modulesJson: string): RelatedBooksDefinition[] {
    const trimmed = modulesJson.trim();
    if (trimmed.length === 0) {
      return [];
    }
    let parsed: Object;
    try {
      parsed = JSON.parse(trimmed) as Object;
    } catch (error) {
      AppLog.put(`关联书籍 relatedBooks 配置解析失败 ${error instanceof Error ? error.message : String(error)}`);
      return [];
    }
    if (!Array.isArray(parsed)) {
      return [];
    }
    const definitions: RelatedBooksDefinition[] = [];
    for (const raw of parsed as Object[]) {
      if (raw === null || typeof raw !== 'object') {
        continue;
      }
      const item = raw as Record<string, Object>;
      const key = typeof item['key'] === 'string' ? item['key'] as string : '';
      const title = typeof item['title'] === 'string' ? item['title'] as string : '';
      const url = typeof item['url'] === 'string' ? item['url'] as string : '';
      definitions.push({ key: key, title: title, url: url });
    }
    return definitions;
  }

  /**
   * 主入口：对齐上游 `scheduleRelatedBooksLoad`（BookInfoViewModel.kt:1990-2031）。
   * @param bookUrl 当前书的地址，用于过滤掉自己
   * @param bookName 当前书名，作者兜底时同样要排除同名书
   * @param bookAuthor 当前书作者，作者兜底时按它搜索
   * @param sourceUrl 当前书源 URL
   * @param authorSearchFallback 开关值，对应 `bookInfoAuthorSearchFallback`
   */
  static async load(
    bookUrl: string,
    bookName: string,
    bookAuthor: string,
    sourceUrl: string,
    authorSearchFallback: boolean
  ): Promise<RelatedBooksModule[]> {
    const modulesJson = RelatedBooksService.relatedBooksJson(sourceUrl);
    const modules = await RelatedBooksService.loadModules(sourceUrl, bookUrl, modulesJson);
    // 上游条件：一个模块都没有 && 开关开着 && 书源确实没配 relatedBooks 规则。
    if (modules.length === 0 && authorSearchFallback && modulesJson.trim().length === 0) {
      const fallback = await RelatedBooksService.loadAuthorOtherWorks(bookUrl, bookName, bookAuthor, sourceUrl);
      if (fallback !== null) {
        return [fallback];
      }
    }
    return modules;
  }

  /** 逐个 definition 请求发现页；单个失败只记日志（对齐上游 `awaitAll().filterNotNull()`）。 */
  private static async loadModules(sourceUrl: string, bookUrl: string, modulesJson: string): Promise<RelatedBooksModule[]> {
    const definitions = RelatedBooksService.parseDefinitions(modulesJson);
    if (definitions.length === 0) {
      return [];
    }
    const modules: RelatedBooksModule[] = [];
    for (let index = 0; index < definitions.length; index++) {
      const definition = definitions[index];
      // 上游只去掉首尾空白：JS 字符串与关键字之间的空格不能删。
      const url = definition.url.trim();
      if (url.length === 0) {
        continue;
      }
      try {
        const books = await RelatedBooksService.exploreModule(sourceUrl, url, bookUrl);
        if (books.length === 0) {
          continue;
        }
        modules.push({
          key: definition.key.length > 0 ? definition.key : definition.title,
          title: definition.title,
          url: url,
          resolvedUrl: url,
          books: books
        });
      } catch (error) {
        AppLog.put(`关联书籍 relatedBooks[${index + 1}] ${definition.title} 请求或解析失败 ${error instanceof Error ? error.message : String(error)}`);
      }
    }
    return modules;
  }

  /**
   * 走一次发现页取书单，并过滤掉当前书。
   * 上游用 `WebBook.exploreBookWithResolvedUrl(source, url, 1, book)` 拿 `(resolvedUrl, books)`；
   * 本地 `WebBookService.exploreBook` 只返回书单，不返回解析后地址，所以这里直接把模板当作 resolvedUrl
   * —— 模板里若含 `{{page}}`，点「更多」时由调用方换页继续请求。
   */
  private static async exploreModule(sourceUrl: string, url: string, bookUrl: string): Promise<SearchBookItem[]> {
    const source = BookSourceRuntime.resolve(sourceUrl);
    if (source === null) {
      return [];
    }
    const books = await WebBookService.exploreBook(source, url, 1);
    return books.filter((item: SearchBookItem) => item.bookUrl !== bookUrl);
  }

  /**
   * 作者其它作品兜底：对齐上游 `loadAuthorOtherWorks`（BookInfoViewModel.kt:2048-2076）。
   * 用当前书源按归一化后的作者名搜第一页，保留作者一致、排除当前书的条目。
   */
  private static async loadAuthorOtherWorks(
    bookUrl: string,
    bookName: string,
    bookAuthor: string,
    sourceUrl: string
  ): Promise<RelatedBooksModule | null> {
    const author = normalizeAuthorName(bookAuthor);
    if (author.length === 0) {
      return null;
    }
    const result = await BookSourceRuntime.searchOne(sourceUrl, author, 1);
    if (result.error.length > 0) {
      AppLog.put(`作者其它作品搜索失败 书源:${result.sourceName} ${result.error}`);
      return null;
    }
    const currentName = bookName.trim();
    const filtered: SearchBookItem[] = [];
    const seen: Set<string> = new Set<string>();
    for (const item of result.books) {
      if (normalizeAuthorName(item.author) !== author) {
        continue;
      }
      if (item.bookUrl === bookUrl) {
        continue;
      }
      if (item.name.trim() === currentName) {
        continue;
      }
      // 上游 distinctBy { bookUrl.ifBlank { "name-author-origin" } }。
      const dedupeKey = item.bookUrl.length > 0 ? item.bookUrl : `${item.name}-${item.author}-${item.origin}`;
      if (seen.has(dedupeKey)) {
        continue;
      }
      seen.add(dedupeKey);
      filtered.push(item);
    }
    if (filtered.length === 0) {
      return null;
    }
    return {
      key: AUTHOR_OTHER_WORKS_KEY,
      title: AUTHOR_OTHER_WORKS_TITLE,
      url: '',
      resolvedUrl: '',
      books: filtered
    };
  }
}
