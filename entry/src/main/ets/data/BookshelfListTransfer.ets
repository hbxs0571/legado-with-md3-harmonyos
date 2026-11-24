import { fileIo, picker } from '@kit.CoreFileKit';
import { rcp } from '@kit.RemoteCommunicationKit';
import { util } from '@kit.ArkTS';
import { Book } from '../model/Book';
import { PreciseSearchEntry } from '../bookSource/PreciseSearchCoordinator';

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
    const text = BookshelfListTransfer.readPickedText(context, uri);
    return BookshelfListTransfer.parseEntries(text);
  }

  /** 把选择器给的 file uri 读成文本：先落 filesDir 临时文件再 readTextSync。 */
  static readPickedText(context: Context, uri: string): string {
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
    return text;
  }

  /**
   * 判断输入是不是一个绝对地址，对应上游 `text.isAbsUrl()`
   * （`ImportBookshelfUseCase.kt:35`）。上游只认 http/https 两种前缀。
   */
  static isAbsUrl(text: string): boolean {
    const trimmed = text.trim();
    return trimmed.startsWith('http://') || trimmed.startsWith('https://');
  }

  /**
   * 按地址下载书单文本，对应上游 `import(str)` 的第一分支：
   * `okHttpClient.newCallResponseBody { url(text) }.decompressed().text()` 后再递归解析。
   * 本地用 rcp 的 GET，超时与 DirectLinkUpload 同口径。
   */
  static async fetchText(url: string): Promise<string> {
    const session = rcp.createSession({ headers: { 'accept': '*/*' } });
    try {
      const response = await session.fetch(new rcp.Request(url, 'GET', undefined, undefined,
        undefined, undefined, {
          transfer: {
            timeout: { connectMs: 15000, transferMs: 120000 }
          }
        }));
      const body = response.body;
      const text = body === undefined ? '' : new util.TextDecoder('utf-8').decodeToString(new Uint8Array(body));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw new Error(`下载书单失败，HTTP ${response.statusCode}`);
      }
      return text;
    } finally {
      session.close();
    }
  }

  /**
   * 把书单文本解析成条目数组，对应上游 `importByJson` 的入参校验：
   * 不是 JSON 数组就 `throw NoStackTraceException("格式不对")`。
   */
  static parseEntries(text: string): BookshelfListEntry[] {
    const trimmed = text.trim();
    if (trimmed.length === 0) {
      throw new Error('格式不对');
    }
    let parsed: BookshelfListEntry[] = [];
    try {
      parsed = JSON.parse(trimmed) as BookshelfListEntry[];
    } catch (error) {
      throw new Error('格式不对');
    }
    if (!Array.isArray(parsed)) {
      throw new Error('格式不对');
    }
    return parsed;
  }

  /**
   * 把书单文本按上游 `import(str, groupId)` 的三分支统一成条目数组：
   * 绝对地址先下载，其余当 JSON 解析。页面侧两条入口（选文件 / 手动输入）共用它。
   */
  static async entriesOf(context: Context, raw: string): Promise<BookshelfListEntry[]> {
    const text = BookshelfListTransfer.isAbsUrl(raw) ? await BookshelfListTransfer.fetchText(raw.trim()) : raw;
    return BookshelfListTransfer.parseEntries(text);
  }

  /**
   * 把书单条目补全成书架书目。
   *
   * 上游 `importByJson`（`ImportBookshelfUseCase.kt:66-109`）的语义是：条目只是
   * 「书名 + 作者」，必须用**全部启用书源**逐个 `WebBook.preciseSearchAwait` 精确
   * 搜索（name 与 author 严格相等）补全成真正的在线书才入库；一本都搜不到就只提示
   * 「没有搜索到<书名><作者>」，**不入库**。补全逻辑在
   * `bookSource/PreciseSearchCoordinator.ets`，这里只负责把条目转成它的入参。
   *
   * 旧实现（`toBooks`）直接落一条 `isLocal: true` 的「缺正文」记录冒充导入成功，
   * 与上游行为不同，已删除。
   */
  static toSearchEntries(entries: BookshelfListEntry[]): PreciseSearchEntry[] {
    const result: PreciseSearchEntry[] = [];
    for (let index = 0; index < entries.length; index++) {
      const entry = entries[index];
      if (entry === undefined) { continue; }
      const name = (entry.name ?? '').trim();
      if (name.length === 0) { continue; }
      result.push({
        name: name,
        author: (entry.author ?? '').trim(),
        intro: (entry.intro ?? '').trim()
      });
    }
    return result;
  }
}
