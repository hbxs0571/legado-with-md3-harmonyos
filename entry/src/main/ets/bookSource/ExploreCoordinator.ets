// 发现协调器（P7）：exploreUrl 四写法解析 + 分类发现结果抓取。
// 对齐上游 WebBook.exploreBookAwait（WebBook.kt:107-145）与 BookSourceExtensions.exploreKinds。
import { BookSource } from '@legado/sourceengine';
import { BookSourceRepository } from '../data/BookSourceRepository';
import { LegadoSourceMapper } from './LegadoSourceMapper';
import { WebBookService } from './WebBookService';
import { ExploreMenuParser, ExploreMenu } from './ExploreMenuParser';
import { SearchBookItem } from './SourceModels';

export interface ExploreOutcome {
  sourceUrl: string;
  books: SearchBookItem[];
  error: string;        // 空串表示成功
}

export class ExploreCoordinator {
  /** 有发现能力的源：启用发现 + exploreUrl 非空（上游 enabledExplore && exploreUrl）。 */
  static getExploreSources(): BookSource[] {
    const result: BookSource[] = [];
    const all = BookSourceRepository.getAll();
    for (const local of all) {
      if (!ExploreCoordinator.isExploreEnabled(local.sourceJson)) { continue; }
      const src = LegadoSourceMapper.fromLocal(local);
      if (src.exploreUrl.length === 0) { continue; }
      result.push(src);
    }
    return result;
  }

  /**
   * 读 sourceJson 里的 enabledExplore。上游默认 true（@ColumnInfo(defaultValue="1")），
   * 只有显式 false 才视为关闭；书源 JSON 里常缺省。
   */
  private static isExploreEnabled(sourceJson: string): boolean {
    try {
      const obj = JSON.parse(sourceJson) as Record<string, Object>;
      const value = obj['enabledExplore'];
      if (value === undefined || value === null) { return true; }
      return value !== false && value !== 'false';
    } catch (_) {
      return true;
    }
  }

  /** 解析某源的发现分类（四种 exploreUrl 写法统一成菜单）。 */
  static parseMenus(source: BookSource): ExploreMenu[] {
    return ExploreMenuParser.parse(source.exploreUrl).menus;
  }

  /** 抓某分类第 page 页的书列表；失败返回 error 非空的结果（不抛异常）。 */
  static async explore(
    source: BookSource, categoryUrl: string, page: number
  ): Promise<ExploreOutcome> {
    try {
      const books = await WebBookService.exploreBook(source, categoryUrl, page);
      return { sourceUrl: source.bookSourceUrl, books: books, error: '' };
    } catch (e) {
      return {
        sourceUrl: source.bookSourceUrl, books: [],
        error: e instanceof Error ? e.message : String(e)
      };
    }
  }
}
