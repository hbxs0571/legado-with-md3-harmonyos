import { Book } from '../model/Book';
import { BookRepository } from './BookRepository';

/**
 * 导入本地文件时，判断能否复用书架里那条同名、但文件已经读不到的记录。
 *
 * 源文件被外部删掉时，书架里那条记录仍在：只剩分组与阅读进度，contentPath 指向的文件已经失效。
 * 此时重新导入同名文件若直接新增，会再裂出一条同名书——旧记录读不了、新记录没有进度。
 * 正确做法是把旧记录迁到这次导入的文件上（接回）。
 *
 * 只在能确认旧文件读不到时复用：
 * * 旧文件仍可读：用户确实另有一份同名文件，两份各自成书；
 * * 文件名不同：不是同一本书。
 *
 * 与上游 LocalBookImportPlanner.kt 的两处差异（本地没有对应概念）：
 * * 上游按 originName 比对文件名；本地 originName 落的是 local-<md5>.txt，
 *   改用 title —— 导入时写库的书名由 parseNameAuthor 解析得到（会剥掉「作者：X」这类片段），
 *   所以这里也必须用 parseNameAuthor().title 才算同一口径。
 *   副作用：用户手动改过书名的书接不回，只能手动移出再导入。
 * * 上游还有 isArchive / webDav 两条否决；本地没有压缩包与远端书籍来源，两条不适用。
 *
 * @return 可复用的旧记录；undefined 表示应当新建。
 */
export function planLocalBookImportReuse(
  existingBook: Book | undefined,
  existingFileReadable: boolean,
  importedFileName: string,
  importedBookUrl: string): Book | undefined {
  const book = existingBook;
  if (book === undefined) {
    return undefined;
  }
  // 同路径：走「更新」分支，不是接回。
  if (BookRepository.bookUrlOf(book) === importedBookUrl) {
    return undefined;
  }
  // 旧文件还能读：用户另有一份同名书，两份各自成书。
  if (existingFileReadable) {
    return undefined;
  }
  // 比对用 parseNameAuthor：写库时 title 就是它解析出来的，用只去后缀的
  // localTitleFromFileName 会让「某某书 作者：某某人.txt」这类书名永远对不上。
  const importedTitle = BookRepository.parseNameAuthor(importedFileName).title;
  if (book.title !== importedTitle) {
    return undefined;
  }
  return book;
}
