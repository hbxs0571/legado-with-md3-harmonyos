import { Book } from '../model/Book';
import { BookGroup } from '../model/BookGroup';
import { TagGroupRule } from '../model/TagGroupRule';
import { BookGroupRepository } from './BookGroupRepository';
import { BookRepository } from './BookRepository';

interface CompiledTagRule {
  groupName: string;
  regex: RegExp;
}

/**
 * 按标签匹配规则给书补分组，对应上游 help/book/BookExtensions.kt:444-504 的
 * applyTagGroupRules。
 *
 * 本地把「算」与「写」拆开：本方法只返回被改过的书（未改的不返回），落库由调用方
 * BookRepository.saveImportedBooks 完成，所以不像上游那样需要 context / groupDao /
 * bookDao，签名里也不带 context。
 *
 * 与上游唯一的实质差异：上游 finalGroup 用位或把分组掩码并起来；本地分组 id 是
 * 2 的幂、用「逐位左移」分配（BookGroupRepository.addWithDraft），几十个分组后
 * id 会到 2^52 量级，而 ArkTS 的位运算只保留低 32 位，会把高分组截掉。因此本地
 * 一律用「分组名数组」表达归属，落库时由 maskFromNames 用加法（mask += groupId）
 * 合成掩码，绝不做位或。
 *
 * 另一点：上游对每条规则的 groupName 查不到分组时会 getUnusedId() 自动建组；
 * 本地的规则只能在分组编辑面板里为「已存在的分组」创建（不做独立规则面板），
 * 所以这里只认 BookGroupRepository 里已有的分组名，找不到的规则整条跳过。
 */
export class TagGroupRuleSync {
  static async apply(books: Book[], rules: TagGroupRule[]): Promise<Book[]> {
    if (rules.length === 0) { return []; }
    const known = BookGroupRepository.getAll();
    const compiled: CompiledTagRule[] = [];
    for (const rule of rules) {
      if (!known.some((group: BookGroup) => group.groupName === rule.groupName)) { continue; }
      // 空表达式会匹配一切，等价上游不会产生的脏规则，直接跳过。
      if (rule.pattern.length === 0) { continue; }
      try {
        compiled.push({ groupName: rule.groupName, regex: new RegExp(rule.pattern) });
      } catch (error) {
        // 正则不合法的规则整条跳过，与上游 mapNotNull 丢弃编译失败项一致。
      }
    }
    if (compiled.length === 0) { return []; }
    const changed: Book[] = [];
    for (const book of books) {
      const labels = TagGroupRuleSync.displayTags(book);
      const current = book.groupNames ?? [];
      const added: string[] = [];
      for (const item of compiled) {
        if (labels.some((label: string) => item.regex.test(label))
          && !current.includes(item.groupName) && !added.includes(item.groupName)) {
          added.push(item.groupName);
        }
      }
      if (added.length === 0) { continue; }
      // 只加不减：保留手动分组，只把命中的分组追加进去。上游同款注释：
      // "Tag rules only add matching groups; manually assigned groups are preserved."
      const nextNames = current.concat(added);
      const next = BookRepository.copyBook(book);
      next.groupNames = nextNames;
      next.groupName = nextNames.join('、');
      changed.push(next);
    }
    return changed;
  }

  /** 上游 getDisplayTagList()：customTag 切分 + kind(category) 切分，去空去重。
   *  本地 category 来自 readBookRow 索引 3 的 kind 列。 */
  private static displayTags(book: Book): string[] {
    const result: string[] = [];
    for (const raw of [book.customTag ?? '', book.category ?? '']) {
      for (const part of raw.split(/[,\n]/)) {
        const tag = part.trim();
        if (tag.length > 0 && !result.includes(tag)) { result.push(tag); }
      }
    }
    return result;
  }
}
