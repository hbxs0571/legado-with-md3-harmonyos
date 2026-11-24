import { Book } from '../model/Book';
import { BookGroup } from '../model/BookGroup';

/**
 * AI 自动分组的本地引擎（C-14）。
 *
 * 上游 `ui/main/bookshelf/autoGroup/AiAutoGroupContract.kt` 把「分析」交给在线模型，
 * 本仓没有任何 AI 基础设施（`AppAiSettingsPage.ets` 里所有入口都还是「尚未迁移」的占位），
 * 所以这里按上游**契约形状**实现一套本地规则引擎：输入书籍清单 + 现有分组 + 三个开关，
 * 输出与上游同构的方案（分组 / 未处理书单 / 四指标）。
 *
 * 分组依据按可信度依次取：书籍分类（kind/category）→ 自定义标签 → 书名关键词。
 * 这三样都是书架里真实存在的数据，不臆造。方案在用户确认前不写库，与上游
 * 「AI 只生成方案，确认前不会修改书架」一致。
 */

/** 上游 AiAutoGroupPhase 的八种阶段。 */
export type AutoGroupPhase =
  | 'LoadingSource'
  | 'Preflight'
  | 'Analyzing'
  | 'Reviewing'
  | 'Revising'
  | 'Applying'
  | 'Result'
  | 'Error';

/** 上游 AiAutoGroupErrorUi 的六种错误。 */
export type AutoGroupErrorKind =
  | 'EmptyBookshelf'
  | 'MissingModel'
  | 'CapacityTooSmall'
  | 'GroupCapacityExceeded'
  | 'InvalidResponse'
  | 'Unexpected';

/** 方案里的一本书，对应上游 AiAutoGroupBookUi。 */
export interface AutoGroupBookUi {
  bookUrl: string;
  name: string;
  author: string;
  /** 这本书当前已属的公开分组名（上游 currentGroupNames）。 */
  currentGroupNames: string[];
  /** 分到这一组的理由，展示在卡片副文案里。 */
  reason: string;
}

/** 方案里的一个分组，对应上游 AiAutoGroupGroupUi。 */
export interface AutoGroupGroupUi {
  key: string;
  name: string;
  description: string;
  /** true = 命中已有公开分组名，执行时复用而不是新建。 */
  reuseExisting: boolean;
  books: AutoGroupBookUi[];
}

/** 未处理的书，对应上游 AiAutoGroupIgnoredBookUi。 */
export interface AutoGroupIgnoredBookUi {
  bookUrl: string;
  name: string;
  author: string;
  reason: string;
}

/** 执行结果四指标，对应上游 AiAutoGroupApplyResultUi。 */
export interface AutoGroupApplyResultUi {
  createdGroupCount: number;
  reusedGroupCount: number;
  updatedBookCount: number;
  ignoredBookCount: number;
}

/** 分析选项，对应上游预检页上的三个开关与补充要求。 */
export interface AutoGroupOptions {
  incrementalOnly: boolean;
  includeBookIntro: boolean;
  enableDeepThinking: boolean;
  groupingInstruction: string;
}

/** 分析输入。 */
export interface AutoGroupInput {
  books: Book[];
  /** 现有公开分组（私密分组不参与，与上游一致）。 */
  publicGroups: BookGroup[];
  options: AutoGroupOptions;
}

/** 分析输出。 */
export interface AutoGroupPlan {
  groups: AutoGroupGroupUi[];
  ignoredBooks: AutoGroupIgnoredBookUi[];
}

/** 引擎可能抛出的错误，带上游对应的错误种类。 */
export class AutoGroupError extends Error {
  readonly kind: AutoGroupErrorKind;

  constructor(kind: AutoGroupErrorKind, message: string) {
    super(message);
    this.kind = kind;
  }
}

/**
 * 书名关键词兜底表。只用于既没有分类也没有标签的书：
 * 命中关键词才归组，命中不了就进「未分类」，不硬凑。
 */
const TITLE_KEYWORDS: string[] = [
  '玄幻', '仙侠', '修真', '武侠', '都市', '历史', '军事', '科幻', '悬疑', '灵异',
  '言情', '校园', '游戏', '竞技', '轻小说', '同人', '文学', '名著', '传记', '哲学',
  '经济', '管理', '心理', '科普', '技术', '编程'
];

export class AutoGroupEngine {
  /**
   * 生成分组方案。纯函数，不改任何状态。
   * 抛 AutoGroupError('EmptyBookshelf') 表示没有可分析的书。
   */
  static analyze(input: AutoGroupInput): AutoGroupPlan {
    const candidates = AutoGroupEngine.candidateBooks(input);
    if (candidates.length === 0) {
      throw new AutoGroupError('EmptyBookshelf', '书架没有可分析的书籍。');
    }
    const publicNames = input.publicGroups.map((group: BookGroup) => group.groupName);
    const groupMap: Map<string, AutoGroupGroupUi> = new Map<string, AutoGroupGroupUi>();
    const ignored: AutoGroupIgnoredBookUi[] = [];

    candidates.forEach((book: Book) => {
      const decision = AutoGroupEngine.decideGroup(book, publicNames);
      if (decision === undefined) {
        ignored.push({
          bookUrl: book.origin === undefined ? book.id : book.id,
          name: book.title,
          author: book.author,
          reason: AutoGroupEngine.ignoreReasonOf(book)
        });
        return;
      }
      const key = decision.groupName;
      let group = groupMap.get(key);
      if (group === undefined) {
        group = {
          key: key,
          name: key,
          description: decision.description,
          reuseExisting: publicNames.indexOf(key) >= 0,
          books: []
        };
        groupMap.set(key, group);
      }
      group.books.push({
        bookUrl: book.id,
        name: book.title,
        author: book.author,
        currentGroupNames: book.groupNames === undefined ? [] : book.groupNames.slice(),
        reason: decision.reason
      });
    });

    let groups = Array.from(groupMap.values());
    // 补充要求里若写了「分组数量控制在 N 个以内」，按书籍数从多到少截断，
    // 被截掉的分组里的书转入未处理，而不是悄悄丢书。
    const limit = AutoGroupEngine.parseGroupLimit(input.options.groupingInstruction);
    if (limit > 0 && groups.length > limit) {
      groups.sort((left: AutoGroupGroupUi, right: AutoGroupGroupUi) => right.books.length - left.books.length);
      const kept = groups.slice(0, limit);
      const dropped = groups.slice(limit);
      dropped.forEach((group: AutoGroupGroupUi) => {
        group.books.forEach((book: AutoGroupBookUi) => {
          ignored.push({
            bookUrl: book.bookUrl,
            name: book.name,
            author: book.author,
            reason: '分组数量受限'
          });
        });
      });
      groups = kept;
    }
    return { groups: groups, ignoredBooks: ignored };
  }

  /** 待分析的书：排除私密书；增量模式下排除已有公开分组的书。 */
  private static candidateBooks(input: AutoGroupInput): Book[] {
    const privateGroupNames: string[] = input.publicGroups
      .filter((group: BookGroup) => group.isPrivate)
      .map((group: BookGroup) => group.groupName);
    return input.books.filter((book: Book) => {
      if (book.notShelf === true) {
        return false;
      }
      if (book.isPrivate === true) {
        return false;
      }
      const names = book.groupNames === undefined ? [] : book.groupNames;
      // 落在私密分组里的书一律不参与（上游：私密分组中的书籍不会发送）。
      if (names.some((name: string) => privateGroupNames.indexOf(name) >= 0)) {
        return false;
      }
      if (input.options.incrementalOnly && names.length > 0) {
        return false;
      }
      return true;
    });
  }

  /** 决定一本书进哪一组；返回 undefined 表示不处理。 */
  private static decideGroup(book: Book, publicNames: string[]): AutoGroupDecision | undefined {
    const kind = AutoGroupEngine.normalizeKind(book);
    if (kind.length > 0) {
      return {
        groupName: kind,
        description: `按书籍分类「${kind}」归组`,
        reason: '书籍分类'
      };
    }
    const tag = AutoGroupEngine.firstTagOf(book);
    if (tag.length > 0) {
      return {
        groupName: tag,
        description: `按自定义标签「${tag}」归组`,
        reason: '自定义标签'
      };
    }
    const keyword = AutoGroupEngine.titleKeywordOf(book.title);
    if (keyword.length > 0) {
      return {
        groupName: keyword,
        description: `按书名关键词「${keyword}」归组`,
        reason: '书名关键词'
      };
    }
    // 已有公开分组的书在非增量模式下保留原分组名，不重新猜。
    const names = book.groupNames === undefined ? [] : book.groupNames;
    const existing = names.find((name: string) => publicNames.indexOf(name) >= 0);
    if (existing !== undefined) {
      return {
        groupName: existing,
        description: `沿用原分组「${existing}」`,
        reason: '沿用原分组'
      };
    }
    return undefined;
  }

  /** 分类名：优先 kind，其次 category；两者都空返回空串。 */
  private static normalizeKind(book: Book): string {
    const raw = (book.kind !== undefined && book.kind.length > 0) ? book.kind : book.category;
    if (raw === undefined) {
      return '';
    }
    const trimmed = raw.trim();
    // 上游 kind 里常见「玄幻,仙侠」这种逗号串，取第一个作为组名。
    const first = trimmed.split(/[,，\/|]/)[0];
    return first === undefined ? '' : first.trim();
  }

  /** 取第一个自定义标签（上游 customTag 是逗号分隔串）。 */
  private static firstTagOf(book: Book): string {
    if (book.customTag === undefined) {
      return '';
    }
    const parts = book.customTag.split(/[,，]/);
    for (let index = 0; index < parts.length; index++) {
      const value = parts[index].trim();
      if (value.length > 0) {
        return value;
      }
    }
    return '';
  }

  /** 书名里出现的第一个关键词；没有返回空串。 */
  private static titleKeywordOf(title: string): string {
    for (let index = 0; index < TITLE_KEYWORDS.length; index++) {
      const keyword = TITLE_KEYWORDS[index];
      if (title.indexOf(keyword) >= 0) {
        return keyword;
      }
    }
    return '';
  }

  /** 不处理的原因文案。 */
  private static ignoreReasonOf(book: Book): string {
    if (book.kind === undefined && book.category.length === 0 && book.customTag === undefined) {
      return '缺少分类与标签';
    }
    return '无法判定分组';
  }

  /** 从补充要求里解析「分组数量控制在 N 个以内」；解析不到返回 0。 */
  private static parseGroupLimit(instruction: string): number {
    if (instruction.length === 0) {
      return 0;
    }
    const matched = instruction.match(/(\d+)\s*个/);
    if (matched === null) {
      return 0;
    }
    const value = parseInt(matched[1], 10);
    return Number.isNaN(value) ? 0 : value;
  }

  /** 方案里的分组数（新建 + 复用）。 */
  static newGroupCount(groups: AutoGroupGroupUi[]): number {
    return groups.filter((group: AutoGroupGroupUi) => !group.reuseExisting).length;
  }

  /** 方案里分配到的书籍总数。 */
  static assignedBookCount(groups: AutoGroupGroupUi[]): number {
    let total = 0;
    groups.forEach((group: AutoGroupGroupUi) => {
      total += group.books.length;
    });
    return total;
  }
}

interface AutoGroupDecision {
  groupName: string;
  description: string;
  reason: string;
}
