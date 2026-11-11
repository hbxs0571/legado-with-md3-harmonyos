import { fileIo, picker } from '@kit.CoreFileKit';
import { Book } from '../model/Book';

/**
 * 上游「书单」导入/导出的条目格式，对应 ExportBookshelfUseCase.kt:20-79。
 * GSON 序列化出来是 [{ name, author, intro }] 的数组，字段名逐字一致才能互通。
 */
export interface BookshelfListEntry {
  name?: string;
  author?: string;
  intro?: string;
}

/**
 * 书架「导出书单 / 导入书单」的文件读写，对应上游 BookshelfScreen.kt:1493-1519。
 *
 * 与批 10 的「导入书文件（TXT/EPUB）」不是一回事：这里选的是书单 JSON，
 * 每条只有书名 / 作者 / 简介，没有正文文件。本地没有在线书源，导入后只能落成
 * 「缺正文」的书目记录（androidOriginalPath 做持久化键），等用户后续补正文。
 */
export class BookshelfListTransfer {
  /** 把书架导出成上游格式的 JSON 字符串。数据源就是书架当前书目。 */
  static toJson(books: Book[]): string {
    const entries: BookshelfListEntry[] = [];
    for (let index = 0; index < books.length; index++) {
      const book = books[index];
      if (book === undefined) { continue; }
      const entry: BookshelfListEntry = {
        name: book.title,
        author: book.author,
        intro: book.description ?? ''
      };
      entries.push(entry);
    }
    return JSON.stringify(entries, null, 2);
  }

  /** 弹系统保存框写 bookshelf.json；用户取消返回 false。 */
  static async exportList(context: Context, books: Book[]): Promise<boolean> {
    const content = BookshelfListTransfer.toJson(books);
    const options = new picker.DocumentSaveOptions();
    options.newFileNames = ['bookshelf.json'];
    options.fileSuffixChoices = ['JSON 文档|.json'];
    const uris = await new picker.DocumentViewPicker(context).save(options);
    const uri = uris[0];
    if (uri === undefined) { return false; }
    // 内容直接传字符串，由底层按 UTF-8 编码写入（见 ReaderBookmarkExporter.saveToFile）。
    const target = fileIo.openSync(uri, fileIo.OpenMode.WRITE_ONLY | fileIo.OpenMode.TRUNC);
    try {
      fileIo.writeSync(target.fd, content);
    } finally {
      fileIo.closeSync(target);
    }
    return true;
  }

  /**
   * 选一份书单文件（.json/.txt）并解析成条目数组；用户取消返回 undefined。
   * 选择器返回的是 file uri，readTextSync 只认沙箱路径，先落到 filesDir 再读。
   */
  static async selectAndParse(context: Context): Promise<BookshelfListEntry[] | undefined> {
    const options = new picker.DocumentSelectOptions();
    options.fileSuffixFilters = ['书单 JSON|.json', '文本文件|.txt'];
    options.maxSelectNumber = 1;
    const uris = await new picker.DocumentViewPicker(context).select(options);
    const uri = uris[0];
    if (uri === undefined) { return undefined; }
    const tempPath = `${context.filesDir}/booklist-${Date.now()}.json`;
    let text = '';
    try {
      const input = fileIo.openSync(uri, fileIo.OpenMode.READ_ONLY);
      try {
        fileIo.copyFileSync(input.fd, tempPath);
      } finally {
        fileIo.closeSync(input);
      }
      const stat = fileIo.statSync(tempPath);
      if (stat.size <= 0 || stat.size > 16 * 1024 * 1024) {
        throw new Error('书单文件为空或超过 16 MB');
      }
      text = fileIo.readTextSync(tempPath);
    } finally {
      if (fileIo.accessSync(tempPath)) { fileIo.unlinkSync(tempPath); }
    }
    const parsed = JSON.parse(text) as BookshelfListEntry[];
    if (!Array.isArray(parsed)) { return []; }
    return parsed;
  }

  /**
   * 把书单条目转成本地 Book。按书名+作者判重（已在书架或本批已加的都跳过），
   * 没有正文文件，androidOriginalPath 用稳定的合成键保证能落库且 isBodyMissing 为真。
   */
  static toBooks(entries: BookshelfListEntry[], existing: Book[]): Book[] {
    const added: Book[] = [];
    for (let index = 0; index < entries.length; index++) {
      const entry = entries[index];
      if (entry === undefined) { continue; }
      const name = (entry.name ?? '').trim();
      const author = (entry.author ?? '').trim();
      if (name.length === 0) { continue; }
      const duplicate = existing.some((book: Book) => book.title === name && book.author === author)
        || added.some((book: Book) => book.title === name && book.author === author);
      if (duplicate) { continue; }
      const hash = BookshelfListTransfer.fnv(`${name} ${author}`);
      const book: Book = {
        id: `booklist-${hash}`,
        title: name,
        author: author,
        category: '本地',
        groupName: '本地未分组',
        groupNames: [],
        chapterIndex: 0,
        chapterProgress: 0,
        lastChapter: '',
        progress: 0,
        description: (entry.intro ?? '').trim(),
        androidOriginalPath: `bookshelf-import://${hash}`,
        format: 'txt',
        isLocal: true
      };
      added.push(book);
    }
    return added;
  }

  private static fnv(text: string): string {
    let hash = 2166136261;
    for (let index = 0; index < text.length; index++) {
      hash ^= text.charCodeAt(index);
      hash = Math.imul(hash, 16777619);
    }
    return (hash >>> 0).toString(16);
  }
}
