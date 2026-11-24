// 在线书内容提供器实现（P3-E）。对齐上游 BookHelp.getContent 的缓存优先 + 网络兜底：
// 1) 先读沙箱里的章节缓存文件（对应 .nb 缓存），命中直接返回；
// 2) 未命中走 BookSourceRuntime 按书源网络抓取，成功后落缓存；
// 3) 目录从书源抓取后适配成 BookChapter（在线章靠 url + index，无字节偏移）。

import { fileIo } from '@kit.CoreFileKit';
import { util } from '@kit.ArkTS';
import { cryptoFramework } from '@kit.CryptoArchitectureKit';
import { Book, BookChapter } from '../model/Book';
import { OnlineBookProvider } from '../data/OnlineBookProvider';
import { BookSourceRuntime } from './BookSourceRuntime';
import { RemoteChapter } from './SourceModels';

/** 章节正文缓存根目录（对应上游 book_cache/）。 */
const CACHE_DIR: string = 'online_book_cache';

export class OnlineBookService implements OnlineBookProvider {
  private readonly context: Context;

  constructor(context: Context) {
    this.context = context;
  }

  /** md5 十六进制（缓存文件名用完整 32 位，与上游标题 MD5 同口径）。 */
  private static md5(text: string): string {
    try {
      const md = cryptoFramework.createMd('MD5');
      md.updateSync({ data: new Uint8Array(new util.TextEncoder().encodeInto(text)) });
      const digest = md.digestSync();
      let hex: string = '';
      for (let index = 0; index < digest.data.length; index++) {
        hex += (digest.data[index] as number).toString(16).padStart(2, '0');
      }
      return hex;
    } catch (_) {
      let hash: number = 0;
      for (let i = 0; i < text.length; i++) {
        hash = (hash * 31 + text.charCodeAt(i)) | 0;
      }
      return (hash >>> 0).toString(16).padStart(8, '0');
    }
  }

  /** 缓存目录名：书名前 9 字（去非法字符）+ bookUrl md5，对齐上游 getFolderNameNoCache。 */
  private static folderNameOf(book: Book): string {
    return book.title.replace(/[\\/:*?"<>|\s]/g, '').slice(0, 9) + OnlineBookService.md5(book.contentPath ?? '');
  }

  /** 缓存文件目录：book_cache/<书名9字+bookUrl md5>/，对齐上游 getFolderNameNoCache。 */
  private bookDir(book: Book): string {
    const folder = OnlineBookService.folderNameOf(book);
    const dir = `${this.context.filesDir}/${CACHE_DIR}/${folder}`;
    try {
      if (!fileIo.accessSync(dir)) {
        fileIo.mkdirSync(dir, true);
      }
    } catch (_) {
    }
    return dir;
  }

  /**
   * 第九表 J-10：书籍改名后把章节缓存目录搬到新名字下。
   *
   * 对齐上游 `help/book/BookHelp.kt:135-157 updateCacheFolder(oldBook, newBook)`：
   * 目录名由书名派生，改名后旧目录会变成孤儿；这里在改名那一刻把旧目录整体 rename 到新目录。
   * 上游用 `if (oldFolderName == newFolderName) return` 短路，本地同样先比目录名。
   * 目标目录已存在时合并：逐个搬文件，同名文件以新目录已有的为准（与上游 move 失败留待清理同口径）。
   */
  static moveCacheFolder(context: Context, oldBook: Book, newBook: Book): void {
    const oldName = OnlineBookService.folderNameOf(oldBook);
    const newName = OnlineBookService.folderNameOf(newBook);
    if (oldName === newName) {
      return;
    }
    const root = `${context.filesDir}/${CACHE_DIR}`;
    const oldDir = `${root}/${oldName}`;
    const newDir = `${root}/${newName}`;
    try {
      if (!fileIo.accessSync(oldDir)) {
        return;
      }
      if (!fileIo.accessSync(newDir)) {
        fileIo.renameSync(oldDir, newDir);
        return;
      }
      // 新目录已存在：逐文件合并，搬完清空旧目录。
      const names: string[] = fileIo.listFileSync(oldDir);
      for (const name of names) {
        const source = `${oldDir}/${name}`;
        const target = `${newDir}/${name}`;
        if (!fileIo.accessSync(target)) {
          fileIo.renameSync(source, target);
        }
      }
      fileIo.rmdirSync(oldDir);
    } catch (_) {
      // 搬目录失败不影响保存本身：缓存丢了只是下次重新抓取，不能因此让书籍信息保存失败。
    }
  }

  /** 章节缓存文件：%05d-标题md5.nb，对齐上游 BookChapter.getFileName。 */
  private chapterFile(book: Book, chapter: BookChapter): string {
    const name = `${chapter.index.toString().padStart(5, '0')}-${OnlineBookService.md5(chapter.title)}.nb`;
    return `${this.bookDir(book)}/${name}`;
  }

  async getChapterList(book: Book): Promise<BookChapter[]> {
    const origin = book.origin ?? '';
    if (origin.length === 0) {
      throw new Error('在线书缺少书源标识');
    }
    const tocUrl = book.tocUrl ?? (book.contentPath ?? '');
    const remote: RemoteChapter[] = await BookSourceRuntime.toc(origin, book.contentPath ?? '', tocUrl);
    const rows: BookChapter[] = [];
    for (let index = 0; index < remote.length; index++) {
      const chapter = remote[index];
      // 批3（r359）：卷标题行要按 ruleToc.isVolume 的求值结果落库，
      // 否则在线书的目录永远折不出卷（CatalogPage 靠 isVolume 折叠，见 :188/:190）。
      const volume = chapter.isVolume === true;
      rows.push({
        url: chapter.url,
        title: chapter.title,
        isVolume: volume,
        // 卷标题是第 0 级，卷内章节是第 1 级，对齐上游 tocLevel 口径（CatalogPage 缩进用）。
        tocLevel: volume ? 0 : 1,
        bookUrl: book.contentPath ?? '',
        index: index,
        // 在线章节靠 url + index 标识，start/end 是本地 TXT 字节偏移，这里不设。
      });
    }
    return rows;
  }

  /**
   * 批2（:442）：缓存文件在不在，就是「已下载」这一档的真值。
   * 不读内容，只 access，够快，列表里逐章判也不卡。
   */
  isChapterCached(book: Book, chapter: BookChapter): boolean {
    try {
      return fileIo.accessSync(this.chapterFile(book, chapter));
    } catch (_) {
      return false;
    }
  }

  /** 批2（:443）：删除单章缓存文件；删不掉（不存在/被占用）静默。 */
  deleteChapterCache(book: Book, chapter: BookChapter): void {
    try {
      const file = this.chapterFile(book, chapter);
      if (fileIo.accessSync(file)) {
        fileIo.unlinkSync(file);
      }
    } catch (_) {
    }
  }

  /**
   * 批2（:469）：清整本书的章节缓存。只删 bookDir 下的 .nb，不删目录本身，
   * 也不碰本地书的 contentPath —— 调用方（Index.deleteSelectedBookCaches）已经按 isLocal 分过流，
   * 这里的入参只应是在线书。
   */
  clearBookCache(book: Book): void {
    try {
      const dir = this.bookDir(book);
      if (!fileIo.accessSync(dir)) {
        return;
      }
      const names = fileIo.listFileSync(dir);
      for (let index = 0; index < names.length; index++) {
        const name = names[index];
        if (!name.endsWith('.nb')) {
          continue;
        }
        try {
          fileIo.unlinkSync(`${dir}/${name}`);
        } catch (_) {
        }
      }
    } catch (_) {
    }
  }

  async getContent(book: Book, chapter: BookChapter, allowCache: boolean = true): Promise<string> {
    const file = this.chapterFile(book, chapter);
    // ① 缓存优先：对应上游 BookHelp.getContent 先读 cachedChapterContentFile。
    try {
      if (fileIo.accessSync(file)) {
        const cached = fileIo.readTextSync(file);
        if (cached.length > 0) {
          return cached;
        }
      }
    } catch (_) {
    }
    // ② 网络兜底：对应上游 CacheBook → WebBook.getContentAwait。
    const origin = book.origin ?? '';
    if (origin.length === 0) {
      throw new Error('在线书缺少书源标识');
    }
    const raw = await BookSourceRuntime.content(origin, chapter.url);
    if (raw.length === 0) {
      throw new Error('在线正文为空');
    }
    // ③ 落缓存：对应上游 BookHelp.saveContent/saveText。
    // 批2（:455）：队列被停止后不许再写缓存文件，所以这一句要看 allowCache。
    if (!allowCache) {
      return raw;
    }
    try {
      const f = fileIo.openSync(file, fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC);
      try {
        fileIo.writeSync(f.fd, raw);
      } finally {
        fileIo.closeSync(f);
      }
    } catch (_) {
    }
    return raw;
  }
}
