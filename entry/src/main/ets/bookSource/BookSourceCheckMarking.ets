// 书源校验标记（对齐上游 BookSource.kt 的 addGroup / removeGroup / getInvalidGroupNames 等）。
//
// 上游在 BookSource 实体上就地改三个字段，然后 BookSourceCheckRepository.kt:133
// `bookSourceRepository.updateSources(source)` 落库：
//   · bookSourceGroup   —— BookSource.kt:186-193 addGroup / :195-201 removeGroup /
//                          :210-212 removeInvalidGroups / :240-244 getInvalidGroupNames
//   · bookSourceComment —— BookSource.kt:214-220 removeErrorComment / :222-226 addErrorComment
//   · respondTime       —— BookSource.kt:79 默认 180000，校验成功由
//                          BookSourceCheckRepository.kt:120-121 改写、失败由 :131 改写
//   · checkKeyWord      —— BookSource.kt:228-238 getCheckKeyword
// 本地这三者分居两处：bookSourceGroup 是 book_sources 的表列，bookSourceComment 与 respondTime
// 在 sourceJson 里。所以这里同时握住表列 group 与 sourceJson 的解析副本，每个方法只改内存，
// 由 BookSourceCheckCoordinator 在校验结束后整批写回。
//
// 与上游的两处有意差异（都写进报告，不藏）：
// ①分组顺序：上游 `TextUtils.join(",", toHashSet())` 的顺序不可预期；本地保持插入序。
//   否则同一批校验每次跑完分组顺序都可能变，用户在分组筛选里看得见。
// ②上游每条源校验完立刻 updateSources 一次；本地攒到整批结束一次性 save。
//   理由是本地 BookSourceRepository.save 是整表 DELETE + 逐行 INSERT（904 行），
//   逐源调用会把校验拖成分钟级。代价是校验中途杀进程会丢本批标记。
import { BookSource } from '../model/BookSource';

/** 上游 AppPattern.kt:39 `val splitGroupRegex = Regex("[,;，；]")`（含全角逗号/分号）。 */
const GROUP_SEPARATOR: RegExp = new RegExp('[,;，；]');

/** 上游 BookSource.kt:79 `var respondTime: Long = 180000L`。 */
export const DEFAULT_RESPOND_TIME: number = 180000;

export class BookSourceCheckMarking {
  readonly bookSourceUrl: string;
  /** 当前分组串（上游 bookSourceGroup，逗号分隔）。 */
  private group: string = '';
  /** sourceJson 的解析副本，bookSourceComment / respondTime 都写在里面。 */
  private raw: Record<string, Object> = {};
  /** sourceJson 是否可解析；坏 JSON 时不动它，避免把一条脏源的源文洗掉。 */
  private jsonValid: boolean = true;

  constructor(local: BookSource) {
    this.bookSourceUrl = local.bookSourceUrl;
    try {
      const parsed: Object = JSON.parse(local.sourceJson);
      if (parsed !== null && typeof parsed === 'object' && !Array.isArray(parsed)) {
        this.raw = parsed as Record<string, Object>;
      } else {
        this.jsonValid = false;
      }
    } catch (_) {
      this.jsonValid = false;
    }
    // 表列优先：列表页的分组筛选读的是表列，sourceJson 里的同名字段只是导出用的副本。
    const column: string = local.bookSourceGroup === undefined ? '' : local.bookSourceGroup;
    this.group = column.length > 0 ? column : BookSourceCheckMarking.text(this.raw, 'bookSourceGroup');
  }

  /** 当前分组串（调试与断言用）。 */
  currentGroup(): string {
    return this.group;
  }

  /** 当前错误注释（调试与断言用）。 */
  currentComment(): string {
    return this.jsonValid ? BookSourceCheckMarking.text(this.raw, 'bookSourceComment') : '';
  }

  /** 上游 :186-193 addGroup：并进现有分组；原本为空时直接取传入串（不切分、不去重）。 */
  addGroup(groups: string): void {
    if (this.group.length > 0) {
      const merged: string[] = BookSourceCheckMarking.splitNotBlank(this.group);
      for (const item of BookSourceCheckMarking.splitNotBlank(groups)) {
        if (merged.indexOf(item) < 0) {
          merged.push(item);
        }
      }
      this.group = merged.join(',');
    }
    if (this.group.length === 0) {
      this.group = groups;
    }
  }

  /** 上游 :195-201 removeGroup：从现有分组里摘掉给定项；原本为空时什么都不做。 */
  removeGroup(groups: string): void {
    if (this.group.length === 0) {
      return;
    }
    const drop: string[] = BookSourceCheckMarking.splitNotBlank(groups);
    const kept: string[] = [];
    for (const item of BookSourceCheckMarking.splitNotBlank(this.group)) {
      if (drop.indexOf(item) < 0) {
        kept.push(item);
      }
    }
    this.group = kept.join(',');
  }

  /** 上游 :203-208 hasGroup。 */
  hasGroup(group: string): boolean {
    return BookSourceCheckMarking.splitNotBlank(this.group).indexOf(group) >= 0;
  }

  /** 上游 :210-212 removeInvalidGroups：清掉上一轮留下的失效分组。 */
  removeInvalidGroups(): void {
    this.removeGroup(this.getInvalidGroupNames());
  }

  /** 上游 :240-244 getInvalidGroupNames：名字里带「失效」或正好是「校验超时」的项。 */
  getInvalidGroupNames(): string {
    const invalid: string[] = [];
    for (const item of BookSourceCheckMarking.splitNotBlank(this.group)) {
      if (item.indexOf('失效') >= 0 || item === '校验超时') {
        invalid.push(item);
      }
    }
    return invalid.join(', ');
  }

  /** 上游 :214-220 removeErrorComment：按空行分段，丢掉以 `// Error: ` 开头的段。 */
  removeErrorComment(): void {
    if (!this.jsonValid) {
      return;
    }
    const comment: string = BookSourceCheckMarking.text(this.raw, 'bookSourceComment');
    if (comment.length === 0) {
      return;
    }
    const kept: string[] = [];
    for (const block of comment.split('\n\n')) {
      if (!block.startsWith('// Error: ')) {
        kept.push(block);
      }
    }
    this.raw['bookSourceComment'] = kept.join('\n');
  }

  /** 上游 :222-226 addErrorComment：新错误注释插到最前，用空行与旧注释隔开。 */
  addErrorComment(message: string): void {
    if (!this.jsonValid) {
      return;
    }
    const comment: string = BookSourceCheckMarking.text(this.raw, 'bookSourceComment');
    const head: string = '// Error: ' + message;
    this.raw['bookSourceComment'] = comment.length === 0 ? head : head + '\n\n' + comment;
  }

  /** 上游 :79 + BookSourceCheckRepository.kt:120-121 / :131 的 respondTime 改写。 */
  setRespondTime(milliseconds: number): void {
    if (!this.jsonValid) {
      return;
    }
    this.raw['respondTime'] = milliseconds < 0 ? 0 : milliseconds;
  }

  /**
   * 上游 :228-238 getCheckKeyword：规则里自带 checkKeyWord 且不含 http / :: / ++ / -- 时优先用它。
   * 带这些标记说明那条 checkKeyWord 其实是 URL 或表达式，直接拿去搜会错。
   */
  getCheckKeyword(defaultWord: string): string {
    if (!this.jsonValid) {
      return defaultWord;
    }
    const ruleSearch = this.raw['ruleSearch'];
    if (ruleSearch === null || ruleSearch === undefined || typeof ruleSearch !== 'object' || Array.isArray(ruleSearch)) {
      return defaultWord;
    }
    const word: string = BookSourceCheckMarking.text(ruleSearch as Record<string, Object>, 'checkKeyWord');
    if (word.trim().length === 0) {
      return defaultWord;
    }
    if (word.indexOf('http') >= 0 || word.indexOf('::') >= 0 || word.indexOf('++') >= 0 || word.indexOf('--') >= 0) {
      return defaultWord;
    }
    return word;
  }

  /** 把内存里的标记落回一条书源（表列 group + sourceJson 的 group/comment/respondTime）。 */
  applyTo(local: BookSource): BookSource {
    const next: BookSource = {
      bookSourceUrl: local.bookSourceUrl,
      // 分组清空时写 undefined（落库成 NULL），与上游 bookSourceGroup 为 null 等价；
      // ArkTS 不支持 delete 运算符（arkts-no-delete），所以不能从 raw 里摘键。
      bookSourceGroup: this.group.length > 0 ? this.group : undefined,
      bookSourceName: local.bookSourceName,
      bookSourceType: local.bookSourceType,
      enabled: local.enabled,
      customOrder: local.customOrder,
      sourceJson: local.sourceJson
    };
    if (this.jsonValid) {
      // 表列与 sourceJson 必须同步：列表页分组筛选读表列，引擎读 sourceJson（LegadoSourceMapper:35）。
      this.raw['bookSourceGroup'] = this.group;
      next.sourceJson = JSON.stringify(this.raw);
    }
    return next;
  }

  /** 上游 StringExtensions.kt:93-95 `splitNotBlank(regex)`：切分 → 去空白 → 丢空项。 */
  private static splitNotBlank(value: string): string[] {
    const out: string[] = [];
    for (const piece of value.split(GROUP_SEPARATOR)) {
      const trimmed: string = piece.trim();
      if (trimmed.length > 0) {
        out.push(trimmed);
      }
    }
    return out;
  }

  private static text(obj: Record<string, Object>, key: string): string {
    const value = obj[key];
    return typeof value === 'string' ? value : '';
  }
}
