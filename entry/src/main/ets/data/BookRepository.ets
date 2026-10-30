import { fileIo, picker } from '@kit.CoreFileKit';
import { preferences, relationalStore } from '@kit.ArkData';
import { util } from '@kit.ArkTS';
import { cryptoFramework } from '@kit.CryptoArchitectureKit';
import { Book, BookChapter, BookMediaType, bookCoverColor, bookCoverMark } from '../model/Book';
import { EpubRepository } from './EpubRepository';
import { LocalTextSemantics } from './LocalTextSemantics';
import { LocalTextReSegmenter } from './LocalTextReSegmenter';
import { ReplaceRuleRepository } from './ReplaceRuleRepository';
import { BookContentProcessRepository } from './BookContentProcessRepository';
import { BookContentProcessEngine } from './BookContentProcessEngine';
import { RdbCodec } from './RdbCodec';
import { RdbSchema } from './RdbSchema';
import { RdbStore } from './RdbStore';
import { BookGroupRepository } from './BookGroupRepository';
import { TxtTocRuleRepository } from './TxtTocRuleRepository';

/** books.readConfig 里本地用得上的几项，其余上游字段不解析。 */
interface StoredReadConfig {
  imageStyle?: string;
  reSegment?: boolean;
  fixedType?: boolean;
}

interface ChapterTextRange {
  start: number;
  end: number;
}

interface NoTocChapterLayout {
  titles: string[];
  offsets: number[];
}

/** 按目录规则切出的章节标题、偏移与卷标记。 */
interface ChapterSplit {
  titles: string[];
  offsets: number[];
  volumes: boolean[];
}

/** 新导入一本书的结果：书目与它的章节行必须一起落库。 */
export interface CreatedLocalBook {
  book: Book;
  chapters: BookChapter[];
}

/** 改写某一章正文的结果：正文变了，全书章节的字节偏移都要重算。 */
export interface ChapterReplaceResult {
  book: Book;
  chapters: BookChapter[];
}

/** preferences 老数据里一本书的章节三元组，只在存量搬迁时使用。 */
interface LegacyBookChapters {
  bookUrl: string;
  titles: string[];
  offsets: number[];
  volumes: boolean[];
}

/** 存量搬迁的读取结果：书目 + 各自从 preferences 里解析出的章节数据。 */
interface LegacyBooksResult {
  books: Book[];
  chapters: LegacyBookChapters[];
}

export interface NoTocBookRefreshResult {
  book: Book;
  chapters: BookChapter[];
  content: string;
  changed: boolean;
  oldBodyOffsets: number[];
  newBodyOffsets: number[];
}

/** 目录重算结果，偏移用于把书签映射到新的章节列表。 */
export interface TocRefreshResult {
  book: Book;
  chapters: BookChapter[];
  content: string;
  changed: boolean;
  oldBodyOffsets: number[];
  newBodyOffsets: number[];
}

export class BookRepository {
  private static readonly preferenceName: string = 'legado_local_books';
  private static effectiveRuleIdsByChapter: Map<string, number[]> = new Map<string, number[]>();
  private static effectiveRuleCacheOrder: string[] = [];
  private static saveQueue: Promise<void> = Promise.resolve();
  /** 章节行缓存：bookUrl → 章节行，供页面上的同步访问器读取。 */
  private static chapterCache: Map<string, BookChapter[]> = new Map<string, BookChapter[]>();
  /** 规则匹配只扫描文件开头，与 Android 只读首个缓冲区识别目录的行为一致。 */
  private static readonly tocSampleSize: number = 65536;

  /** 按 index 升序读一本书的全部章节；start/end 是字节偏移。 */
  private static readonly selectChaptersByBookUrl: string =
    'SELECT `url`, `title`, `isVolume`, `tocLevel`, `bookUrl`, `index`, `wordCount`, `start`, `end` ' +
    'FROM `chapters` WHERE `bookUrl` = ? ORDER BY `index` ASC';

  /** 查某本书的章节行数，用于判断目录是否需要重建。 */
  private static readonly countChaptersByBookUrl: string =
    'SELECT COUNT(*) FROM `chapters` WHERE `bookUrl` = ?';

  /** 章节整表按书重建：先删该书的全部行，再逐行插入。 */
  private static readonly deleteChaptersByBookUrl: string =
    'DELETE FROM `chapters` WHERE `bookUrl` = ?';

  /** 删除一本书的书目行，删书时与章节行一起在一个事务里做。 */
  private static readonly deleteBookSql: string =
    'DELETE FROM `books` WHERE `bookUrl` = ?';

  /** 章节插入语句，18 列全部给值。 */
  private static readonly insertChapterSql: string =
    'INSERT OR REPLACE INTO `chapters` (`url`, `title`, `isVolume`, `tocLevel`, `baseUrl`, `bookUrl`, ' +
    '`index`, `isVip`, `isPay`, `resourceUrl`, `tag`, `wordCount`, `start`, `end`, ' +
    '`startFragmentId`, `endFragmentId`, `variable`, `reviewImg`) ' +
    'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)';

  /**
   * 读全部书目。列顺序必须与 readBookRow 的索引一一对应，改动这里就要同步改那边。
   * 只取本地用得上的列，上游独有的列（lastCheckTime / syncTime 等）不读。
   */
  private static readonly selectBooksSql: string =
    'SELECT `bookUrl`, `name`, `author`, `kind`, `group`, `durChapterIndex`, `durChapterPos`, ' +
    '`durChapterTitle`, `totalChapterNum`, `tocUrl`, `originName`, `intro`, `remark`, `customTag`, ' +
    '`charset`, `coverUrl`, `customCoverUrl`, `type`, `readConfig`, `latestChapterTime`, ' +
    '`durChapterTime`, `order` FROM `books` ORDER BY `durChapterTime` DESC';

  /** 写入或覆盖一行书目。35 列全部给值，主键冲突时整行覆盖。 */
  private static readonly upsertBookSql: string =
    'INSERT OR REPLACE INTO `books` (`bookUrl`, `tocUrl`, `origin`, `originName`, `name`, `author`, ' +
    '`kind`, `customTag`, `coverUrl`, `customCoverUrl`, `intro`, `customIntro`, `remark`, `charset`, ' +
    '`type`, `group`, `isPrivate`, `latestChapterTitle`, `latestChapterTime`, `lastCheckTime`, ' +
    '`lastCheckCount`, `totalChapterNum`, `durChapterTitle`, `durChapterIndex`, `durChapterPos`, ' +
    '`durChapterTime`, `wordCount`, `canUpdate`, `disableReadRecord`, `order`, `originOrder`, ' +
    '`variable`, `readConfig`, `syncTime`, `listIntro`) ' +
    'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)';

  /**
   * 读一本书的章节列表。章节已从 Book 里拆出来，页面在 aboutToAppear 时调这里查表。
   */
  static async getChapterList(context: Context, bookUrl: string): Promise<BookChapter[]> {
    if (bookUrl.length === 0) { return []; }
    const store = await RdbStore.getStore(context);
    await RdbSchema.ensure(store);
    const resultSet = await store.querySql(BookRepository.selectChaptersByBookUrl, [bookUrl]);
    const chapters: BookChapter[] = [];
    try {
      while (resultSet.goToNextRow()) {
        const chapter: BookChapter = {
          url: RdbCodec.text(resultSet, RdbCodec.column(resultSet, 'url')),
          title: RdbCodec.text(resultSet, RdbCodec.column(resultSet, 'title')),
          isVolume: RdbCodec.boolean(resultSet, RdbCodec.column(resultSet, 'isVolume'), false),
          tocLevel: RdbCodec.integer(resultSet, RdbCodec.column(resultSet, 'tocLevel'), 0),
          bookUrl: RdbCodec.text(resultSet, RdbCodec.column(resultSet, 'bookUrl')),
          index: RdbCodec.integer(resultSet, RdbCodec.column(resultSet, 'index'), 0),
          wordCount: RdbCodec.optionalText(resultSet, RdbCodec.column(resultSet, 'wordCount')),
          start: RdbCodec.optionalInteger(resultSet, RdbCodec.column(resultSet, 'start')),
          end: RdbCodec.optionalInteger(resultSet, RdbCodec.column(resultSet, 'end'))
        };
        chapters.push(chapter);
      }
    } finally {
      resultSet.close();
    }
    return chapters;
  }

  /** 读一本书的章节数；没导入过章节时返回 0。 */
  static async getChapterCount(context: Context, bookUrl: string): Promise<number> {
    if (bookUrl.length === 0) { return 0; }
    const store = await RdbStore.getStore(context);
    await RdbSchema.ensure(store);
    const resultSet = await store.querySql(BookRepository.countChaptersByBookUrl, [bookUrl]);
    try {
      if (!resultSet.goToNextRow()) { return 0; }
      return RdbCodec.integer(resultSet, 0, 0);
    } finally {
      resultSet.close();
    }
  }

  /**
   * 全书阅读进度，百分比 0–100。
   * 派生值不落库：上游 Book 表没有这一列，进度由章序与章内进度算出。
   */
  static readProgress(book: Book): number {
    const chapterCount = Math.max(1, Number(book.chapterCount ?? '0') || 1);
    const chapterIndex = Math.max(0, book.chapterIndex ?? 0);
    const chapterProgress = Math.max(0, Math.min(100, book.chapterProgress ?? 0));
    return (chapterIndex + chapterProgress / 100) / chapterCount * 100;
  }

  /**
   * 正文是否缺失。派生值不落库：上游没有这一列，本地按文件是否存在判定。
   */
  static isBodyMissing(book: Book): boolean {
    if (book.contentPath === undefined || book.contentPath.length === 0) { return true; }
    try {
      return !fileIo.accessSync(book.contentPath);
    } catch (_) {
      return true;
    }
  }

  /**
   * 字符按指定编码占几个字节，用于字符偏移与字节偏移互转。
   * 上游 TextFile.kt 用 toByteArray(charset).size 累加，这里按码点宽度等价计算，
   * 避免为了拿偏移把整本书重新编码一遍。
   */
  private static charByteWidth(content: string, charIndex: number, encoding: string): number {
    const code = content.charCodeAt(charIndex);
    const isSurrogatePair = code >= 0xD800 && code <= 0xDBFF && charIndex + 1 < content.length;
    if (encoding === 'utf-16le' || encoding === 'utf-16be') {
      return isSurrogatePair ? 4 : 2;
    }
    if (encoding === 'gb18030' || encoding === 'gbk' || encoding === 'big5') {
      if (code < 0x80) { return 1; }
      return isSurrogatePair ? 4 : 2;
    }
    // 默认按 UTF-8：1 / 2 / 3 / 4 字节
    if (code < 0x80) { return 1; }
    if (code < 0x800) { return 2; }
    return isSurrogatePair ? 4 : 3;
  }

  /** 编码名归一化：空值当 utf-8，其余转小写并统一 gbk 家族。 */
  private static normalizeEncoding(encoding: string | undefined): string {
    if (encoding === undefined || encoding.length === 0) { return 'utf-8'; }
    const lower = encoding.toLowerCase();
    if (lower === 'gbk' || lower === 'gb2312' || lower === 'gb18030') { return 'gb18030'; }
    if (lower === 'unicode' || lower === 'utf-16') { return 'utf-16le'; }
    return lower;
  }

  /**
   * 把字符偏移数组转成字节偏移数组，一次正向扫描完成。
   * offsets 必须升序（splitChapters 与 buildNoTocChapterLayout 产出的都是升序）。
   */
  private static charOffsetsToByteOffsets(content: string, offsets: number[],
    encoding: string | undefined): number[] {
    const result: number[] = [];
    if (offsets.length === 0) { return result; }
    const normalized = BookRepository.normalizeEncoding(encoding);
    let targetIndex = 0;
    let charIndex = 0;
    let byteCount = 0;
    while (targetIndex < offsets.length && offsets[targetIndex] <= 0) {
      result.push(0);
      targetIndex++;
    }
    while (charIndex < content.length && targetIndex < offsets.length) {
      const width = BookRepository.charByteWidth(content, charIndex, normalized);
      charIndex += width === 4 ? 2 : 1;
      byteCount += width;
      while (targetIndex < offsets.length && offsets[targetIndex] <= charIndex) {
        result.push(byteCount);
        targetIndex++;
      }
    }
    while (result.length < offsets.length) {
      result.push(byteCount);
    }
    return result;
  }

  /** 把字节偏移换算成字符下标；超出范围时夹到字符串末尾。 */
  private static byteOffsetToCharIndex(content: string, byteOffset: number,
    encoding: string | undefined): number {
    if (byteOffset <= 0) { return 0; }
    const normalized = BookRepository.normalizeEncoding(encoding);
    let charIndex = 0;
    let byteCount = 0;
    while (charIndex < content.length) {
      const width = BookRepository.charByteWidth(content, charIndex, normalized);
      if (byteCount + width > byteOffset) { return charIndex; }
      byteCount += width;
      charIndex += width === 4 ? 2 : 1;
    }
    return content.length;
  }

  /** 上游 MD5Utils.md5Encode16：取 MD5 十六进制串的第 8–24 个字符。 */
  private static md5Encode16(text: string): string {
    try {
      const md = cryptoFramework.createMd('MD5');
      md.updateSync({ data: new Uint8Array(new util.TextEncoder().encodeInto(text)) });
      const digest = md.digestSync();
      let hex: string = '';
      for (let index = 0; index < digest.data.length; index++) {
        hex += (digest.data[index] as number).toString(16).padStart(2, '0');
      }
      if (hex.length < 24) { return hex; }
      return hex.substring(8, 24);
    } catch (_) {
      return '';
    }
  }

  /**
   * 上游 StringUtils.wordCountFormat：大于 10000 才用「万字」，
   * 等于 10000 仍显示「10000字」（上游用的是严格大于）。
   */
  private static wordCountFormat(words: number): string {
    if (words <= 0) { return ''; }
    if (words > 10000) {
      return `${(words / 10000).toFixed(1)}万字`;
    }
    return `${words}字`;
  }

  /**
   * 整份复制 Book，供调用方在副本上改字段。
   * ArkTS 不支持对象展开（...book），字段又只剩三十个，所以统一收在这里，
   * 各处「改一个字段」的逻辑复制后改，避免每个函数重复列一遍全部字段。
   */
  static copyBook(book: Book): Book {
    return {
      id: book.id,
      title: book.title,
      author: book.author,
      category: book.category,
      groupName: book.groupName,
      groupNames: book.groupNames,
      chapterIndex: book.chapterIndex,
      chapterProgress: book.chapterProgress,
      lastChapter: book.lastChapter,
      progress: book.progress,
      coverUri: book.coverUri,
      customCoverUri: book.customCoverUri,
      bookType: book.bookType,
      fixedType: book.fixedType,
      contentPath: book.contentPath,
      format: book.format,
      chapterCount: book.chapterCount,
      imageStyle: book.imageStyle,
      reSegment: book.reSegment,
      charset: book.charset,
      description: book.description,
      remark: book.remark,
      customTag: book.customTag,
      androidOriginalPath: book.androidOriginalPath,
      androidCharacterPosition: book.androidCharacterPosition,
      tocRule: book.tocRule,
      latestChapterTime: book.latestChapterTime,
      durChapterTime: book.durChapterTime,
      order: book.order,
      isLocal: book.isLocal
    };
  }

static getEffectiveReplaceRuleIds(bookId: string, chapterIndex: number): number[] {
    const key = `${bookId}|${chapterIndex}`;
    const ids = BookRepository.effectiveRuleIdsByChapter.get(key);
    return ids === undefined ? [] : ids.slice();
  }

private static rememberEffectiveReplaceRules(bookId: string, chapterIndex: number, ids: number[]): void {
    const key = `${bookId}|${chapterIndex}`;
    if (!BookRepository.effectiveRuleIdsByChapter.has(key)) {
      BookRepository.effectiveRuleCacheOrder.push(key);
    }
    BookRepository.effectiveRuleIdsByChapter.set(key, ids.slice());
    if (BookRepository.effectiveRuleCacheOrder.length > 4096) {
      const oldest = BookRepository.effectiveRuleCacheOrder.shift();
      if (oldest !== undefined) {
        BookRepository.effectiveRuleIdsByChapter.delete(oldest);
      }
    }
  }
  static async importLocalBook(context: Context,
    maxLengthWithNoToc: number = 3000): Promise<CreatedLocalBook | undefined> {
    const options = new picker.DocumentSelectOptions();
    options.fileSuffixFilters = ['TXT 文本|.txt', 'EPUB 电子书|.epub'];
    options.maxSelectNumber = 1;
    const documentPicker = new picker.DocumentViewPicker(context);
    const uris = await documentPicker.select(options);
    if (uris.length === 0) { return undefined; }

const uri = uris[0];
    if (uri === undefined) { return undefined; }
    const fileName = BookRepository.getFileName(uri);
    const bookId = `local-${Date.now()}`;
    if (fileName.toLowerCase().endsWith('.epub')) {
      const imported = await EpubRepository.importFromUri(context, uri, fileName, bookId);
      // EPUB 写出的正文是 UTF-8，章节偏移按字符给，这里统一转成字节偏移的章节行。
      const chapters = BookRepository.buildChapterRows(imported.book.contentPath ?? '',
        imported.titles, imported.offsets, [], imported.content, undefined);
      return { book: imported.book, chapters: chapters };
    }

return await BookRepository.importTxtFromUri(context, uri, fileName, bookId, maxLengthWithNoToc);
  }

  static async importTxtFromUri(context: Context, uri: string, fileName: string, bookId: string,
    maxLengthWithNoToc: number = 3000): Promise<CreatedLocalBook> {
    const title = BookRepository.getTitle(fileName);
    await TxtTocRuleRepository.load(context);
    const booksDirectory = `${context.filesDir}/books`;
    const contentPath = `${booksDirectory}/${bookId}.txt`;
    let content: string = '';
    try {
      BookRepository.ensureDirectory(booksDirectory);
      const sourceFile = fileIo.openSync(uri, fileIo.OpenMode.READ_ONLY);
      try {
        fileIo.copyFileSync(sourceFile.fd, contentPath);
      } finally {
        fileIo.closeSync(sourceFile);
      }
      if (fileIo.statSync(contentPath).size === 0) {
        throw new Error('TXT 文件内容为空');
      }
      content = BookRepository.readTextFile(contentPath);
    } catch (error) {
      try {
        fileIo.unlinkSync(contentPath);
      } catch (_) {
      }
      if (error instanceof Error) { throw error; }
      throw new Error('读取 TXT 文件失败');
    }
    return BookRepository.createLocalBook(bookId, title, contentPath, 0, 0, content, undefined, maxLengthWithNoToc);
  }

static discardImportedCopy(book: Book): void {
    if (book.contentPath !== undefined && fileIo.accessSync(book.contentPath)) {
      fileIo.unlinkSync(book.contentPath);
    }
  }

private static parseGroupNames(value: string): string[] {
    try {
      const parsed: string[] = JSON.parse(value);
      return parsed.filter((name: string) => typeof name === 'string' && name.trim().length > 0)
        .map((name: string) => name.trim());
    } catch (_) {
      return [];
    }
  }

private static isGroupNamesField(value: string | undefined): boolean {
    try {
      const parsed: string[] = JSON.parse(decodeURIComponent(value ?? ''));
      return Array.isArray(parsed) && parsed.every((name: string) => typeof name === 'string');
    } catch (_) {
      return false;
    }
  }

/** 把分卷标记按位写入书目字段，全部为 false 时不写冗余数据。 */
  private static encodeVolumeFlags(volumes: boolean[] | undefined, count: number): string {
    if (volumes === undefined || volumes.length !== count || count === 0 ||
      !volumes.some((value: boolean) => value === true)) {
      return '';
    }
    return volumes.map((value: boolean) => value ? '1' : '0').join('');
  }

/** 分卷标记数量错位时整体丢弃，避免目录缩进错章。 */
  private static decodeVolumeFlags(value: string | undefined, count: number): boolean[] | undefined {
    const text = value ?? '';
    if (text.length === 0 || text.length !== count || count === 0) {
      return undefined;
    }
    const result: boolean[] = [];
    for (let index = 0; index < text.length; index++) {
      const flag = text.charAt(index);
      if (flag !== '0' && flag !== '1') { return undefined; }
      result.push(flag === '1');
    }
    return result;
  }

private static parseBookType(value: string): BookMediaType {
    if (value === 'audio' || value === 'image') { return value; }
    return 'text';
  }

  /** 解析书架排序用的时间戳字段；非正数或非整数一律视为未记录。 */
  private static parseTimestampField(value: string | undefined): number | undefined {
    const parsed = Number(value ?? '0');
    return Number.isSafeInteger(parsed) && parsed > 0 ? parsed : undefined;
  }

  /** 解析手动排序序号；0 是合法值（排第一），所以只排除非整数。 */
  private static parseOrderField(value: string | undefined): number | undefined {
    const parsed = Number(value ?? '');
    return Number.isSafeInteger(parsed) ? parsed : undefined;
  }

private static resolveCoverUri(context: Context, bookId: string, customCoverPath: string): string | undefined {
    if (customCoverPath.length > 0 && fileIo.accessSync(customCoverPath)) {
      return `file://${customCoverPath}`;
    }
    const embeddedCoverPath = `${context.filesDir}/covers/${bookId}.img`;
    return fileIo.accessSync(embeddedCoverPath) ? `file://${embeddedCoverPath}` : undefined;
  }

static async chooseCustomCover(context: Context, book: Book): Promise<Book | undefined> {
    const options = new picker.DocumentSelectOptions();
    options.fileSuffixFilters = ['图片|.png', '图片|.jpg', '图片|.jpeg', '图片|.webp', '图片|.bmp'];
    options.maxSelectNumber = 1;
    const uris = await new picker.DocumentViewPicker(context).select(options);
    const uri = uris[0];
    if (uri === undefined) { return undefined; }

const coversDirectory = `${context.filesDir}/covers`;
    BookRepository.ensureDirectory(coversDirectory);
    const customPath = `${coversDirectory}/custom-${book.id}-${Date.now()}.img`;
    const source = fileIo.openSync(uri, fileIo.OpenMode.READ_ONLY);
    try {
      fileIo.copyFileSync(source.fd, customPath);
      if (fileIo.statSync(customPath).size <= 0) {
        throw new Error('所选封面文件为空');
      }
    } catch (error) {
      if (fileIo.accessSync(customPath)) { fileIo.unlinkSync(customPath); }
      if (error instanceof Error) { throw error; }
      throw new Error('保存封面副本失败');
    } finally {
      fileIo.closeSync(source);
    }
    return BookRepository.copyWithCover(book, `file://${customPath}`, customPath);
  }

static restoreEmbeddedCover(context: Context, book: Book): Book {
    const embeddedPath = `${context.filesDir}/covers/${book.id}.img`;
    const embeddedUri = fileIo.accessSync(embeddedPath) ? `file://${embeddedPath}` : undefined;
    return BookRepository.copyWithCover(book, embeddedUri, undefined);
  }

static removeCustomCover(path: string | undefined): void {
    if (path !== undefined && path.length > 0 && fileIo.accessSync(path)) {
      fileIo.unlinkSync(path);
    }
  }

private static copyWithCover(book: Book, coverUri: string | undefined, customCoverUri: string | undefined): Book {
    const next = BookRepository.copyBook(book);
    next.coverUri = coverUri;
    next.customCoverUri = customCoverUri;
    return next;
  }

/** 复制书目并更新分组/用户元数据，避免 UI 写回时丢失进度和封面字段。 */
  static withShelfMetadata(book: Book, groupNames: string[], groupName: string, customTag: string | undefined,
    title: string = book.title, author: string = book.author, category: string = book.category,
    description: string | undefined = book.description, remark: string | undefined = book.remark): Book {
    const next = BookRepository.copyBook(book);
    next.title = title;
    next.author = author;
    next.category = category;
    next.groupName = groupName;
    next.groupNames = groupNames;
    next.description = description;
    next.remark = remark;
    next.customTag = customTag;
    return next;
  }

  /**
   * 是否需要在书架上保留。
   * 上游以 bookUrl 为准（本地书就是文件路径），缺正文的 Android 备份书目靠
   * androidOriginalPath 记住原始路径，因此这两者有其一即保留。
   */
  static isPersistableBook(book: Book): boolean {
    return book.contentPath !== undefined || book.androidOriginalPath !== undefined;
  }

  /**
   * 把 preferences 里的书架与老目录搬进 books / chapters 两张表。
   *
   * 书名、分组、进度这些字段由 loadFromPreferences 直接解析成 Book；
   * 章节标题与字符偏移由它放进 collected 带出来，这里换算成字节偏移再写 chapters 表。
   * 字节偏移必须重新读一遍正文才能算（中文一个字 3 字节，不能按字符数乘除），
   * 所以正文文件还在的书要读一次；文件已被删的书退化成「只有标题、偏移全 0」，
   * 与缺正文书的处理一致，不会让整次搬迁失败。
   *
   * 不开事务、不写标记：事务与标记都由 RdbMigration 统一管。
   */
  static async migrateFromPreferences(context: Context, store: relationalStore.RdbStore): Promise<void> {
    const collected: LegacyBookChapters[] = [];
    const books = await BookRepository.loadFromPreferences(context, collected);
    if (books.length === 0 && collected.length === 0) { return; }
    const persisted: Book[] = [];
    for (let index = 0; index < books.length; index++) {
      const book = books[index];
      if (!BookRepository.isPersistableBook(book)) { continue; }
      await store.executeSql(BookRepository.upsertBookSql, BookRepository.toBookArgs(book));
      persisted.push(book);
    }
    for (let index = 0; index < collected.length; index++) {
      const legacy = collected[index];
      if (legacy === undefined || legacy.bookUrl.length === 0) { continue; }
      const rows = await BookRepository.buildLegacyChapterRows(legacy, persisted);
      // 老格式里章节标题为空的书不写章节行，否则会插进一堆空标题。
      if (rows.length === 0) { continue; }
      await store.executeSql(BookRepository.deleteChaptersByBookUrl, [legacy.bookUrl]);
      for (const row of rows) {
        await store.executeSql(BookRepository.insertChapterSql,
          BookRepository.toChapterArgs(legacy.bookUrl, row));
      }
      BookRepository.chapterCache.set(legacy.bookUrl, rows);
    }
  }

  /**
   * 把老格式的章节三元组换算成 chapters 行。
   *
   * 偏移在老格式里是字符下标，而 chapters 表存的是字节偏移；
   * 只有读到正文才算得出字节数，读不到就当作整本书没有偏移。
   */
  private static async buildLegacyChapterRows(legacy: LegacyBookChapters, books: Book[]): Promise<BookChapter[]> {
    if (legacy.titles.length === 0) { return []; }
    let charset: string | undefined = undefined;
    for (let index = 0; index < books.length; index++) {
      const book = books[index];
      if (book.contentPath === legacy.bookUrl) {
        charset = book.charset;
        break;
      }
    }
    let content = '';
    // 老格式里缺正文的书不带偏移；偏移与标题数量对不上也当作没偏移，
    // 否则每章都会退化成「起止都覆盖全文」，字数统计会失真。
    const hasOffsets = legacy.offsets.length === legacy.titles.length;
    try {
      content = await BookRepository.readTextFileAsync(legacy.bookUrl, charset);
    } catch (_) {
      // 正文文件已不在：章节标题仍然保留，偏移按 0 处理。
      content = '';
    }
    const offsets = hasOffsets ? legacy.offsets : [];
    return BookRepository.buildChapterRows(legacy.bookUrl, legacy.titles, offsets,
      legacy.volumes, content, charset);
  }

  /**
   * 读取书架。上游用 Room，`bookDao.flowAll` 直接查 books 表；
   * 这里同样以库为准，只有读库失败（首次启动表还没建好、或老版本刚升级上来）才回退 preferences。
   * 章节不再随书返回，页面需要时调 getChapterList 查 chapters 表。
   */
  static async loadImportedBooks(context: Context): Promise<Book[]> {
    try {
      return await BookRepository.loadBooksFromDb(context);
    } catch (_) {
      return await BookRepository.loadFromPreferences(context, []);
    }
  }

  /** 从 books 表读出全部书籍，按 `order` 升序（与上游 BookDao.flowAll 一致）。 */
  private static async loadBooksFromDb(context: Context): Promise<Book[]> {
    const store = await RdbStore.getStore(context);
    await RdbSchema.ensure(store);
    const resultSet = await store.querySql(BookRepository.selectBooksSql);
    const books: Book[] = [];
    try {
      while (resultSet.goToNextRow()) {
        books.push(BookRepository.readBookRow(resultSet));
      }
    } finally {
      resultSet.close();
    }
    return books;
  }

  /** 解析一行 books 记录。列顺序必须与 selectBooksSql 保持一致。 */
  private static readBookRow(resultSet: relationalStore.ResultSet): Book {
    const bookUrl = RdbCodec.text(resultSet, 0);
    const config = BookRepository.parseReadConfig(RdbCodec.optionalText(resultSet, 18));
    const bookTypeValue = RdbCodec.integer(resultSet, 17, 0);
    const groupMask = RdbCodec.integer(resultSet, 4, 0);
    const groupNames = BookGroupRepository.namesFromMask(groupMask);
    const book: Book = {
      // 上游本地书的 bookUrl 就是文件路径，id 由文件名派生，不再单独存一列。
      id: BookRepository.bookIdFromUrl(bookUrl),
      title: RdbCodec.text(resultSet, 1),
      author: RdbCodec.text(resultSet, 2),
      category: RdbCodec.text(resultSet, 3),
      groupNames: groupNames,
      groupName: groupNames.length > 0 ? groupNames[0] : '',
      chapterIndex: RdbCodec.integer(resultSet, 5, 0),
      // 本地 chapterProgress 是章内百分比，直接落在 durChapterPos 上（已定决策）。
      chapterProgress: RdbCodec.integer(resultSet, 6, 0),
      lastChapter: RdbCodec.text(resultSet, 7),
      chapterCount: RdbCodec.integer(resultSet, 8, 0).toString(),
      progress: 0,
      coverUri: RdbCodec.optionalText(resultSet, 15),
      customCoverUri: RdbCodec.optionalText(resultSet, 16),
      bookType: bookTypeValue === 64 ? 'image' : bookTypeValue === 32 ? 'audio' : 'text',
      fixedType: config.fixedType === true,
      contentPath: bookUrl.length > 0 ? bookUrl : undefined,
      format: bookUrl.toLowerCase().endsWith('.epub') ? 'epub' : 'txt',
      imageStyle: config.imageStyle,
      reSegment: config.reSegment === true,
      charset: RdbCodec.optionalText(resultSet, 14),
      description: RdbCodec.optionalText(resultSet, 11),
      remark: RdbCodec.optionalText(resultSet, 12),
      customTag: RdbCodec.optionalText(resultSet, 13),
      androidOriginalPath: RdbCodec.optionalText(resultSet, 10),
      tocRule: RdbCodec.optionalText(resultSet, 9),
      latestChapterTime: RdbCodec.optionalInteger(resultSet, 19),
      durChapterTime: RdbCodec.optionalInteger(resultSet, 20),
      order: RdbCodec.optionalInteger(resultSet, 21),
      isLocal: true
    };
    book.progress = BookRepository.readProgress(book);
    return book;
  }

  /** 解析 readConfig JSON，只关心本地有对应字段的三项。 */
  private static parseReadConfig(text: string | undefined): StoredReadConfig {
    if (text === undefined || text.length === 0) { return {}; }
    try {
      return JSON.parse(text) as StoredReadConfig;
    } catch (_) {
      return {};
    }
  }

  /** 由 bookUrl（本地书就是文件路径）派生书籍 id：取文件名去掉扩展名。 */
  private static bookIdFromUrl(bookUrl: string): string {
    const fileName = BookRepository.getFileName(bookUrl);
    const dotIndex = fileName.lastIndexOf('.');
    return dotIndex > 0 ? fileName.substring(0, dotIndex) : fileName;
  }

  /**
   * 从老 preferences 解析书架（v1–v15 全部格式），仅供首次搬迁与读库失败兜底使用。
   * collected 用于带出老格式里的章节三元组，搬迁时写 chapters 表；日常加载传空数组即可。
   */
  private static async loadFromPreferences(context: Context, collected: LegacyBookChapters[]): Promise<Book[]> {
    try {
      const store = await preferences.getPreferences(context, BookRepository.preferenceName);
      await TxtTocRuleRepository.load(context);
      const value = await store.get('books', '');
      if (typeof value !== 'string' || (!value.startsWith('v1\n') && !value.startsWith('v2\n') && !value.startsWith('v3\n') && !value.startsWith('v4\n') && !value.startsWith('v5\n') && !value.startsWith('v6\n') && !value.startsWith('v7\n') && !value.startsWith('v8\n') && !value.startsWith('v9\n') && !value.startsWith('v10\n') && !value.startsWith('v11\n') && !value.startsWith('v12\n') && !value.startsWith('v13\n') && !value.startsWith('v14\n') && !value.startsWith('v15\n'))) {
        return [];
      }
      const isVersion15 = value.startsWith('v15\n');
      const isVersion14 = isVersion15 || value.startsWith('v14\n');
      const isVersion13 = isVersion14 || value.startsWith('v13\n');
      const isVersion12 = isVersion13 || value.startsWith('v12\n');
      const isVersion11 = isVersion12 || value.startsWith('v11\n');
      const isVersion10 = isVersion11 || value.startsWith('v10\n');
      const isVersion9 = isVersion10 || value.startsWith('v9\n');
      const isVersion8 = isVersion9 || value.startsWith('v8\n');
      const isVersion7 = isVersion8 || value.startsWith('v7\n');
      const isVersion6 = isVersion7 || value.startsWith('v6\n');
      const isVersion5 = isVersion6 || value.startsWith('v5\n');
      const isVersion4 = isVersion5 || value.startsWith('v4\n');
      const isVersion3 = isVersion4 || value.startsWith('v3\n');
      const isVersion2 = value.startsWith('v2\n');
      const books: Book[] = [];
      const records = value.substring(3).split('\n');
      for (let index = 0; index < records.length; index++) {
        const fields = records[index].split('|');
        const maximumFields = isVersion15 ? 33 : isVersion14 ? 30 : isVersion13 ? 28 : isVersion12 ? 27 : isVersion11 ? 25 : isVersion10 ? 24 : isVersion9 ? 22 : isVersion8 ? 21 : isVersion7 ? 20 : isVersion6 ? 19 : isVersion5 ? 18 : isVersion4 ? 9 : isVersion3 ? 8 : isVersion2 ? 4 : 3;
        if (fields.length < 2 || fields.length > maximumFields) {
          continue;
        }
        const field27IsGroupNames = isVersion13 && BookRepository.isGroupNamesField(fields[27]);
        const savedGroupNames = field27IsGroupNames
          ? BookRepository.parseGroupNames(decodeURIComponent(fields[27] ?? '[]')) : undefined;
        // 兼容 N 版旧 v13/v14（27 位为规则）与 E 版 v13/v14（27 位为分组）。
        const savedTocRule = fields.length >= 30 ? decodeURIComponent(fields[29] ?? '')
          : isVersion14 && !field27IsGroupNames ? decodeURIComponent(fields[27] ?? '')
          : isVersion13 && !field27IsGroupNames ? decodeURIComponent(fields[27] ?? '') : '';
        const id = decodeURIComponent(fields[0]);
        const title = decodeURIComponent(fields[1]);
        let chapterIndex: number = 0;
        let chapterProgress: number = 0;
        if ((isVersion2 || isVersion3) && fields.length >= 4) {
          const parsedIndex = Number(fields[2]);
          const parsedProgress = Number(fields[3]);
          if (Number.isInteger(parsedIndex) && parsedIndex >= 0) {
            chapterIndex = parsedIndex;
          }
          if (Number.isFinite(parsedProgress)) {
            chapterProgress = Math.max(0, Math.min(100, parsedProgress));
          }
        } else if (!isVersion2 && !isVersion3 && fields.length === 3) {
          const legacyProgress = Number(fields[2]);
          if (Number.isFinite(legacyProgress)) {
            chapterProgress = Math.max(0, Math.min(100, legacyProgress));
          }
        }
        const path = `${context.filesDir}/books/${id}.txt`;
        if (isVersion5 && fields[9] === '1') {
          const savedIndex = Number(fields[2] ?? '0');
          const savedPosition = Number(fields[11] ?? '0');
          const savedProgress = Number(fields[17] ?? '0');
          const originalPath = decodeURIComponent(fields[10] ?? '');
          const savedChapterCount = decodeURIComponent(fields[13] ?? '0');
          const savedCategory = decodeURIComponent(fields[14] ?? '本地');
          const savedGroupName = decodeURIComponent(fields[15] ?? '本地未分组');
          const savedLastChapter = decodeURIComponent(fields[16] ?? '');
          const savedTitles = (fields[6] ?? '').split(';').filter((item: string) => item.length > 0)
            .map((item: string) => decodeURIComponent(item));
          const savedOffsets = (fields[7] ?? '').split(',').map((item: string) => Number(item))
            .filter((item: number) => Number.isInteger(item) && item >= 0);
          books.push({
            id: id,
            title: title,
            author: decodeURIComponent(fields[5] ?? '未知作者'),
            category: savedCategory,
            groupName: savedGroupName,
            groupNames: savedGroupNames,
            tocRule: savedTocRule.length > 0 ? savedTocRule : undefined,
            chapterIndex: Number.isInteger(savedIndex) && savedIndex >= 0 ? savedIndex : 0,
            chapterProgress: chapterProgress,
            lastChapter: savedLastChapter,
            progress: Number.isFinite(savedProgress) ? Math.max(0, Math.min(100, savedProgress)) : 0,
            coverUri: BookRepository.resolveCoverUri(context, id, isVersion11 ? decodeURIComponent(fields[24] ?? '') : ''),
            customCoverUri: isVersion11 ? decodeURIComponent(fields[24] ?? '') || undefined : undefined,
            bookType: isVersion12 ? BookRepository.parseBookType(decodeURIComponent(fields[25] ?? 'text')) : 'text',
            fixedType: isVersion12 && fields[26] === '1',
            chapterCount: savedChapterCount,
            description: decodeURIComponent(fields[12] ?? ''),
            remark: isVersion10 ? decodeURIComponent(fields[22] ?? '') : undefined,
            customTag: isVersion10 ? decodeURIComponent(fields[23] ?? '') : undefined,
            androidOriginalPath: originalPath,
            androidCharacterPosition: Number.isInteger(savedPosition) && savedPosition >= 0 ? savedPosition : 0,
            format: fields[4] === 'epub' ? 'epub' : 'txt',
            imageStyle: isVersion6 ? decodeURIComponent(fields[18] ?? 'DEFAULT') : undefined,
            charset: isVersion7 ? decodeURIComponent(fields[19] ?? '') || undefined : undefined,
            reSegment: isVersion8 && fields[20] === '1',
            latestChapterTime: isVersion15 ? BookRepository.parseTimestampField(fields[30]) : undefined,
            durChapterTime: isVersion15 ? BookRepository.parseTimestampField(fields[31]) : undefined,
            order: isVersion15 ? BookRepository.parseOrderField(fields[32]) : undefined,
            isLocal: true
          });
          // 缺正文的书没有正文文件，章节只能带出标题；字节偏移算不出来，搬迁时留 NULL。
          if (savedTitles.length > 0) {
            collected.push({
              bookUrl: originalPath,
              titles: savedTitles,
              offsets: [],
              volumes: isVersion14
                ? (BookRepository.decodeVolumeFlags(fields[28], savedTitles.length) ?? []) : []
            });
          }
          continue;
        }
        if (fileIo.accessSync(path)) {
          if (isVersion3 && fields[4] === 'epub') {
            const chapterTitles = (fields[6] ?? '').split(';')
              .filter((item: string) => item.length > 0)
              .map((item: string) => decodeURIComponent(item));
            const chapterOffsets = (fields[7] ?? '').split(',')
              .map((item: string) => Number(item))
              .filter((item: number) => Number.isInteger(item) && item >= 0);
            const safeIndex = Math.max(0, Math.min(Math.max(0, chapterTitles.length - 1), chapterIndex));
            const safeProgress = Math.max(0, Math.min(100, chapterProgress));
            const savedSize = Number(fields[8] ?? '0');
            const savedPosition = Number(fields[11] ?? '0');
            const savedWholeProgress = Number(fields[17] ?? '0');
            const savedCategory = isVersion5 ? decodeURIComponent(fields[14] ?? '本地') : '本地';
            const savedGroupName = isVersion5 ? decodeURIComponent(fields[15] ?? '本地未分组') : '本地未分组';
              const savedLastChapter = isVersion5 ? decodeURIComponent(fields[16] ?? '') : '';
            books.push({
              id: id,
              title: title,
              author: decodeURIComponent(fields[5] ?? '本地 EPUB'),
              category: savedCategory,
              groupName: savedGroupName,
              groupNames: savedGroupNames,
              tocRule: savedTocRule.length > 0 ? savedTocRule : undefined,
              chapterIndex: safeIndex,
              chapterProgress: safeProgress,
              lastChapter: chapterTitles[safeIndex] ?? (savedLastChapter.length > 0 ? savedLastChapter : '全文'),
              progress: isVersion5 && Number.isFinite(savedWholeProgress)
                ? Math.max(0, Math.min(100, savedWholeProgress))
                : chapterTitles.length > 0 ? (safeIndex + safeProgress / 100) / chapterTitles.length * 100 : 0,
              coverUri: BookRepository.resolveCoverUri(context, id, isVersion11 ? decodeURIComponent(fields[24] ?? '') : ''),
              customCoverUri: isVersion11 ? decodeURIComponent(fields[24] ?? '') || undefined : undefined,
              bookType: isVersion12 ? BookRepository.parseBookType(decodeURIComponent(fields[25] ?? 'text')) : 'text',
              fixedType: isVersion12 && fields[26] === '1',
              description: decodeURIComponent(fields[12] ?? ''),
              remark: isVersion10 ? decodeURIComponent(fields[22] ?? '') : undefined,
              customTag: isVersion10 ? decodeURIComponent(fields[23] ?? '') : undefined,
              chapterCount: chapterTitles.length.toString(),
              contentPath: path,
              format: 'epub',
              imageStyle: isVersion6 ? decodeURIComponent(fields[18] ?? 'DEFAULT') : undefined,
              charset: isVersion7 ? decodeURIComponent(fields[19] ?? '') || undefined : undefined,
              reSegment: isVersion8 && fields[20] === '1',
              androidCharacterPosition: isVersion5 && Number.isInteger(savedPosition) && savedPosition >= 0
                ? savedPosition : 0,
              latestChapterTime: isVersion15 ? BookRepository.parseTimestampField(fields[30]) : undefined,
              durChapterTime: isVersion15 ? BookRepository.parseTimestampField(fields[31]) : undefined,
              order: isVersion15 ? BookRepository.parseOrderField(fields[32]) : undefined,
              isLocal: true
            });
            // 老格式里的章节标题与字符偏移带出去，搬迁时换算成字节偏移写 chapters 表。
            if (chapterTitles.length > 0) {
              collected.push({
                bookUrl: path,
                titles: chapterTitles,
                offsets: chapterOffsets.length === chapterTitles.length ? chapterOffsets : [],
                volumes: isVersion14
                  ? (BookRepository.decodeVolumeFlags(fields[28], chapterTitles.length) ?? []) : []
              });
            }
          } else {
            const savedCharset = isVersion7 ? decodeURIComponent(fields[19] ?? '') : '';
            const savedTitles = (fields[6] ?? '').split(';')
              .filter((item: string) => item.length > 0)
              .map((item: string) => decodeURIComponent(item));
            const savedOffsets = (fields[7] ?? '').split(',')
              .map((item: string) => Number(item))
              .filter((item: number) => Number.isInteger(item) && item >= 0);
            const created = BookRepository.createLocalBook(id, title, path, chapterIndex, chapterProgress,
              undefined, savedCharset.length > 0 ? savedCharset : undefined);
            const localBook = created.book;
            // 从 v5 起恢复 TXT 书目的作者、分类、分组和简介，避免冷启动回到导入默认值。
            if (fields.length > 5) {
              localBook.author = decodeURIComponent(fields[5] ?? localBook.author);
            }
            if (isVersion5) {
              localBook.category = decodeURIComponent(fields[14] ?? '本地');
              localBook.groupName = decodeURIComponent(fields[15] ?? '本地未分组');
              localBook.description = decodeURIComponent(fields[12] ?? '');
            }
            localBook.customCoverUri = isVersion11 ? decodeURIComponent(fields[24] ?? '') || undefined : undefined;
            localBook.groupNames = savedGroupNames;
            localBook.tocRule = savedTocRule.length > 0 ? savedTocRule : undefined;
            localBook.bookType = isVersion12 ? BookRepository.parseBookType(decodeURIComponent(fields[25] ?? 'text')) : 'text';
            localBook.fixedType = isVersion12 && fields[26] === '1';
            localBook.coverUri = BookRepository.resolveCoverUri(context, id, localBook.customCoverUri ?? '');
            const savedPosition = Number(fields[11] ?? '0');
            localBook.androidCharacterPosition = isVersion5 && Number.isInteger(savedPosition) && savedPosition >= 0
              ? savedPosition : 0;
            const savedWholeProgress = Number(fields[17] ?? '0');
            if (isVersion5 && Number.isFinite(savedWholeProgress)) {
              localBook.progress = Math.max(0, Math.min(100, savedWholeProgress));
            }
            localBook.reSegment = isVersion8 && fields[20] === '1';
            localBook.remark = isVersion10 ? decodeURIComponent(fields[22] ?? '') : undefined;
            localBook.customTag = isVersion10 ? decodeURIComponent(fields[23] ?? '') : undefined;
            if (savedTitles.length > 0 && savedOffsets.length === savedTitles.length) {
              const safeIndex = Math.max(0, Math.min(savedTitles.length - 1, chapterIndex));
              // 章节标题与字符偏移交给 collected，搬迁时换算成字节偏移写 chapters 表。
              localBook.chapterIndex = safeIndex;
              localBook.lastChapter = savedTitles[safeIndex] ?? localBook.lastChapter;
              localBook.chapterCount = savedTitles.length.toString();
              collected.push({
                bookUrl: path,
                titles: savedTitles,
                offsets: savedOffsets,
                volumes: isVersion14
                  ? (BookRepository.decodeVolumeFlags(fields[28], savedTitles.length) ?? []) : []
              });
            }
            if (isVersion6) { localBook.imageStyle = decodeURIComponent(fields[18] ?? 'DEFAULT'); }
            if (isVersion15) {
              localBook.latestChapterTime = BookRepository.parseTimestampField(fields[30]);
              localBook.durChapterTime = BookRepository.parseTimestampField(fields[31]);
              localBook.order = BookRepository.parseOrderField(fields[32]);
            }
            books.push(localBook);
          }
        }
      }
      return books;
    } catch (_) {
      return [];
    }
  }

static saveImportedBooks(context: Context, books: Book[]): Promise<void> {
    const operation = BookRepository.saveQueue.then(async (): Promise<void> => {
      try {
        const store = await RdbStore.getStore(context);
        await RdbSchema.ensure(store);
        // 整批书目一个事务：书架是一次整体覆盖，中途失败就一条都不落。
        await store.beginTransaction();
        try {
          for (let index = 0; index < books.length; index++) {
            const book = books[index];
            if (!BookRepository.isPersistableBook(book)) { continue; }
            await store.executeSql(BookRepository.upsertBookSql, BookRepository.toBookArgs(book));
          }
          await store.commit();
        } catch (error) {
          await store.rollBack();
          if (error instanceof Error) { throw error; }
          throw new Error('本地书架数据保存失败');
        }
      } catch (error) {
        if (error instanceof Error) {
          throw new Error(`本地书架数据保存失败：${error.message}`);
        }
        throw new Error('本地书架数据保存失败');
      }
    });
    BookRepository.saveQueue = operation.then((): void => {}, (_error: Error): void => {});
    return operation;
  }

  /**
   * 整本重建一本书的章节行：先删该书的全部行，再逐行插入。
   *
   * 与上游 BookChapterDao 的 delByBook + insert 一致，章节只要变了就整本重来，不做行级 diff。
   * 章节已从 Book 里拆出来，所以由产出章节的调用方（导入、换编码、改正文、重算目录）显式调这里。
   */
  static async saveChapters(context: Context, bookUrl: string, chapters: BookChapter[]): Promise<void> {
    if (bookUrl.length === 0) { return; }
    const store = await RdbStore.getStore(context);
    await RdbSchema.ensure(store);
    await store.beginTransaction();
    try {
      await store.executeSql(BookRepository.deleteChaptersByBookUrl, [bookUrl]);
      for (let index = 0; index < chapters.length; index++) {
        await store.executeSql(BookRepository.insertChapterSql,
          BookRepository.toChapterArgs(bookUrl, chapters[index]));
      }
      await store.commit();
    } catch (error) {
      await store.rollBack();
      if (error instanceof Error) {
        throw new Error(`章节数据保存失败：${error.message}`);
      }
      throw new Error('章节数据保存失败');
    }
    // 写完顺手刷新缓存，页面随后同步取章节就是新目录。
    BookRepository.chapterCache.set(bookUrl, chapters);
  }

  /** 删一本书的全部章节行。外键 CASCADE 在 relationalStore 里实测不生效，删书必须手动调这里。 */
  static async deleteChapters(context: Context, bookUrl: string): Promise<void> {
    if (bookUrl.length === 0) { return; }
    const store = await RdbStore.getStore(context);
    await RdbSchema.ensure(store);
    await store.executeSql(BookRepository.deleteChaptersByBookUrl, [bookUrl]);
    BookRepository.chapterCache.delete(bookUrl);
  }

  /**
   * 删除一本书：先删章节行，再删 books 行。
   *
   * 照上游 DeleteBooksUseCase：外键 CASCADE 在 relationalStore 里实测不生效，
   * 章节行必须手动删；顺序与上游一致（先章节、后 books），
   * 中途失败时事务回滚，不会留下没有书主的章节行。
   * 注意 saveImportedBooks 只做 upsert，不会清理缺席的书——删书一律走这里。
   */
  static async deleteBook(context: Context, book: Book): Promise<void> {
    const bookUrl = book.contentPath ?? book.androidOriginalPath ?? '';
    if (bookUrl.length === 0) { return; }
    const store = await RdbStore.getStore(context);
    await RdbSchema.ensure(store);
    await store.beginTransaction();
    try {
      await store.executeSql(BookRepository.deleteChaptersByBookUrl, [bookUrl]);
      await store.executeSql(BookRepository.deleteBookSql, [bookUrl]);
      await store.commit();
    } catch (error) {
      await store.rollBack();
      if (error instanceof Error) {
        throw new Error(`删除书籍失败：${error.message}`);
      }
      throw new Error('删除书籍失败');
    }
    BookRepository.chapterCache.delete(bookUrl);
  }

  /**
   * 把一本书的章节行读进内存缓存，供页面上的同步访问器使用。
   *
   * 上游页面读目录是同步的（Room DAO 直接返回 List<BookChapter>），
   * relationalStore 的查询必然异步，所以这里在页面 aboutToAppear 时先读一次，
   * 之后 cachedChapterTitles 之类的同步函数就能直接用，页面代码不必逐个改 await。
   * 数据来源始终是 chapters 表，缓存只是异步存储对同步 DAO 的等价物。
   */
  static async loadChapters(context: Context, book: Book): Promise<BookChapter[]> {
    const bookUrl = book.contentPath ?? book.androidOriginalPath ?? '';
    if (bookUrl.length === 0) { return []; }
    const chapters = await BookRepository.getChapterList(context, bookUrl);
    BookRepository.chapterCache.set(bookUrl, chapters);
    return chapters;
  }

  /** 同步取缓存里的章节行；没加载过就是空数组，与上游没有目录时的行为一致。 */
  static cachedChapters(book: Book): BookChapter[] {
    const bookUrl = book.contentPath ?? book.androidOriginalPath ?? '';
    if (bookUrl.length === 0) { return []; }
    return BookRepository.chapterCache.get(bookUrl) ?? [];
  }

  /** 同步取章节标题列表，等价于上游 BookChapter 列表的 title 投影。 */
  static cachedChapterTitles(book: Book): string[] {
    const rows = BookRepository.cachedChapters(book);
    const titles: string[] = [];
    rows.forEach((row: BookChapter) => {
      titles.push(row.title);
    });
    return titles;
  }

  /** 同步取章节结束偏移（字符外的字节偏移），等价于旧的 chapterOffsets。 */
  static cachedChapterOffsets(book: Book): number[] {
    const rows = BookRepository.cachedChapters(book);
    const offsets: number[] = [0];
    rows.forEach((row: BookChapter) => {
      offsets.push(row.end ?? 0);
    });
    return offsets;
  }

  /** 同步取分卷标记列表，等价于旧的 chapterVolumes。 */
  static cachedChapterVolumes(book: Book): boolean[] {
    const rows = BookRepository.cachedChapters(book);
    const volumes: boolean[] = [];
    rows.forEach((row: BookChapter) => {
      volumes.push(row.isVolume);
    });
    return volumes;
  }

  /** 把一本书摊成 books 表的 35 个绑定值，顺序必须与 upsertBookSql 一致。 */
  private static toBookArgs(book: Book): relationalStore.ValueType[] {
    const bookUrl = book.contentPath ?? book.androidOriginalPath ?? '';
    const originName = book.androidOriginalPath ?? BookRepository.getFileName(bookUrl);
    const groupNames = book.groupNames ?? ((book.groupName ?? '').length > 0 ? [book.groupName as string] : []);
    const readConfig: StoredReadConfig = {
      imageStyle: book.imageStyle,
      reSegment: book.reSegment === true,
      fixedType: book.fixedType === true
    };
    const totalChapterNum = Number(book.chapterCount ?? '0');
    const lastChapter = book.lastChapter.length > 0 ? book.lastChapter : null;
    return [
      bookUrl,
      book.tocRule ?? '',
      'loc_book',
      originName,
      book.title,
      book.author,
      book.category.length > 0 ? book.category : null,
      book.customTag === undefined ? null : book.customTag,
      book.coverUri === undefined ? null : book.coverUri,
      book.customCoverUri === undefined ? null : book.customCoverUri,
      book.description === undefined ? null : book.description,
      null,
      book.remark === undefined ? null : book.remark,
      book.charset === undefined ? null : book.charset,
      BookRepository.bookTypeMask(book),
      BookGroupRepository.maskFromNames(groupNames),
      0,
      lastChapter,
      book.latestChapterTime ?? 0,
      0,
      0,
      Number.isFinite(totalChapterNum) ? Math.max(0, Math.trunc(totalChapterNum)) : 0,
      lastChapter,
      Math.max(0, Math.trunc(book.chapterIndex ?? 0)),
      Math.max(0, Math.trunc(book.chapterProgress ?? 0)),
      book.durChapterTime ?? 0,
      null,
      1,
      0,
      Math.trunc(book.order ?? 0),
      0,
      null,
      JSON.stringify(readConfig),
      0,
      null
    ];
  }

  /** 上游 BookType 位掩码：text=8、audio=32、image=64，本地书再加 local=256。 */
  private static bookTypeMask(book: Book): number {
    const media = book.bookType === 'image' ? 64 : book.bookType === 'audio' ? 32 : 8;
    return book.isLocal ? media | 256 : media;
  }

  /** 章节行 18 个绑定值，顺序必须与 insertChapterSql 一致。 */
  private static toChapterArgs(bookUrl: string, chapter: BookChapter): relationalStore.ValueType[] {
    return [
      chapter.url,
      chapter.title,
      chapter.isVolume ? 1 : 0,
      chapter.tocLevel,
      '',
      bookUrl,
      chapter.index,
      0,
      0,
      null,
      null,
      chapter.wordCount === undefined ? null : chapter.wordCount,
      chapter.start === undefined ? null : chapter.start,
      chapter.end === undefined ? null : chapter.end,
      null,
      null,
      null,
      null
    ];
  }

  /**
   * 换一种编码重新切章。
   *
   * 换编码意味着整本书的字符边界和字节边界都可能变，所以章节行要一起重算，
   * 由调用方把返回的 chapters 落库。
   */
  static withCharset(book: Book, charset: string, maxLengthWithNoToc: number = 3000): CreatedLocalBook {
    const normalizedCharset = charset.trim();
    if (book.contentPath === undefined || book.format !== 'txt') {
      const unchanged = BookRepository.copyBook(book);
      unchanged.charset = normalizedCharset.length > 0 ? normalizedCharset : undefined;
      return { book: unchanged, chapters: [] };
    }
    const content = BookRepository.readTextFile(book.contentPath, normalizedCharset.length > 0 ? normalizedCharset : undefined);
    const chapterRule = BookRepository.resolveChapterRule(book.tocRule, content);
    let chapterTitles: string[] = [];
    let chapterOffsets: number[] = [];
    let chapterVolumes: boolean[] = [];
    if (chapterRule.length > 0) {
      const split = BookRepository.splitChapters(content, chapterRule);
      chapterTitles = split.titles;
      chapterOffsets = split.offsets;
      chapterVolumes = split.volumes;
    }
    if (chapterOffsets.length === 0 && content.length > 0) {
      const layout = BookRepository.buildNoTocChapterLayout(content, maxLengthWithNoToc, normalizedCharset.length > 0 ? normalizedCharset : undefined);
      chapterTitles = layout.titles;
      chapterOffsets = layout.offsets;
      chapterVolumes = [];
    }
    const chapterIndex = Math.max(0, Math.min(Math.max(0, chapterTitles.length - 1), book.chapterIndex ?? 0));
    const chapterProgress = Math.max(0, Math.min(100, book.chapterProgress ?? 0));
    const nextBook = BookRepository.copyBook(book);
    nextBook.chapterIndex = chapterIndex;
    nextBook.chapterProgress = chapterProgress;
    nextBook.lastChapter = chapterTitles[chapterIndex] ?? book.lastChapter;
    nextBook.progress = BookRepository.readProgress(nextBook);
    nextBook.chapterCount = chapterTitles.length.toString();
    nextBook.charset = normalizedCharset.length > 0 ? normalizedCharset : undefined;
    nextBook.androidCharacterPosition = 0;
    nextBook.tocRule = chapterRule.length > 0 ? chapterRule : undefined;
    const nextChapters = BookRepository.buildChapterRows(book.contentPath, chapterTitles, chapterOffsets,
      chapterVolumes, content, nextBook.charset);
    return { book: nextBook, chapters: nextChapters };
  }

  static withReSegment(book: Book, enabled: boolean): Book {
    const next = BookRepository.copyBook(book);
    next.reSegment = enabled;
    return next;
  }

  /**
   * 读一章正文。
   *
   * 章节行优先用调用方传入的 chapters（页面在 aboutToAppear 里查表得到）；
   * 没传时按目录规则从正文现算一份，对应「目录规则刚改完、章节行还没落库」的瞬间。
   * 上游 TextFile.getChapterText 同样是拿着 chapter 对象按 start/end 读。
   */
  static async readChapter(book: Book, chapterTitle: string, requestedChapterIndex?: number,
    contentOverride?: string, chapters: BookChapter[] = []): Promise<string> {
    if (book.contentPath === undefined) {
      throw new Error('本地书籍路径无效');
    }
    const encoding = book.format === 'txt' ? book.charset : undefined;
    const content = contentOverride ?? BookRepository.readTextFile(book.contentPath, encoding);
    const rows = chapters.length > 0 ? chapters : BookRepository.deriveChapters(book, content);
    if (rows.length === 0) {
      return await BookRepository.applyChapterContentAsync(book, chapterTitle,
        content.substring(0, 50000), book.chapterIndex ?? 0);
    }
    const selectedIndex = BookRepository.resolveChapterIndex(rows, chapterTitle, requestedChapterIndex, book);
    const chapter = rows[selectedIndex];
    const body = BookRepository.chapterBody(book, content, chapter, encoding);
    return await BookRepository.applyChapterContentAsync(book, chapter.title, body, chapter.index);
  }

  /**
   * 定位要读的章节下标。
   * 顺序照抄原实现：显式下标 → 当前进度章的标题恰好对得上 → 按标题找 → 当前进度章。
   */
  private static resolveChapterIndex(rows: BookChapter[], chapterTitle: string,
    requestedChapterIndex: number | undefined, book: Book): number {
    const storedIndex = book.chapterIndex;
    let selected = requestedChapterIndex ?? storedIndex ?? 0;
    if (requestedChapterIndex === undefined) {
      const storedTitle = storedIndex === undefined ? undefined : rows[storedIndex]?.title;
      if (storedIndex !== undefined && storedTitle === chapterTitle) {
        selected = storedIndex;
      } else {
        for (let index = 0; index < rows.length; index++) {
          if (rows[index].title === chapterTitle) {
            selected = index;
            break;
          }
        }
      }
    }
    return Math.max(0, Math.min(rows.length - 1, selected));
  }

  /**
   * 取一章的正文（已去掉标题行）。
   * start/end 是字节偏移，先换算成字符下标再切字符串，与上游按字节 seek 等价。
   */
  private static chapterBody(book: Book, content: string, chapter: BookChapter,
    encoding: string | undefined): string {
    const startChar = chapter.start === undefined
      ? 0 : BookRepository.byteOffsetToCharIndex(content, chapter.start, encoding);
    const endChar = chapter.end === undefined
      ? content.length : BookRepository.byteOffsetToCharIndex(content, chapter.end, encoding);
    const section = content.substring(startChar, Math.max(startChar, endChar));
    const bodyStart = BookRepository.chapterBodyStart(section, chapter.title);
    const body = section.substring(bodyStart).trim();
    return book.format === 'epub' ? EpubRepository.removeDuplicateHeading(body, chapter.title) : body;
  }

  /** 没拿到章节行时，按目录规则现算一份（不落库）。 */
  private static deriveChapters(book: Book, content: string): BookChapter[] {
    const bookUrl = book.contentPath ?? '';
    const encoding = book.format === 'txt' ? book.charset : undefined;
    const chapterRule = BookRepository.resolveChapterRule(book.tocRule, content);
    let titles: string[] = [];
    let offsets: number[] = [];
    let volumes: boolean[] = [];
    if (chapterRule.length > 0) {
      const split = BookRepository.splitChapters(content, chapterRule);
      titles = split.titles;
      offsets = split.offsets;
      volumes = split.volumes;
    }
    if (offsets.length === 0 && content.length > 0) {
      const layout = BookRepository.buildNoTocChapterLayout(content, 3000, book.charset);
      titles = layout.titles;
      offsets = layout.offsets;
      volumes = [];
    }
    return BookRepository.buildChapterRows(bookUrl, titles, offsets, volumes, content, encoding);
  }

  /**
   * 把「标题 + 字符偏移 + 卷标记」三元组转成章节行。
   *
   * url 照抄上游 TextFile.kt：md5Encode16(originName + index + title)；
   * start/end 是字节偏移（上游 chapters.start/end 存的就是字节）；
   * tocLevel 照抄上游：卷标题自己为 0，卷内章节为 1。
   */
  private static buildChapterRows(bookUrl: string, titles: string[], offsets: number[],
    volumes: boolean[], content: string, encoding: string | undefined): BookChapter[] {
    const rows: BookChapter[] = [];
    if (titles.length === 0) { return rows; }
    const byteOffsets = BookRepository.charOffsetsToByteOffsets(content, offsets, encoding);
    const totalBytes = BookRepository.charOffsetsToByteOffsets(content, [content.length], encoding)[0] ?? 0;
    const originName = BookRepository.getFileName(bookUrl);
    let tocLevel = 0;
    for (let index = 0; index < titles.length; index++) {
      const title = titles[index] ?? '';
      const isVolume = volumes[index] === true;
      if (isVolume) { tocLevel = 0; }
      const charStart = offsets[index] ?? 0;
      const charEnd = offsets[index + 1] ?? content.length;
      const words = content.substring(charStart, charEnd).trim().length;
      const row: BookChapter = {
        url: BookRepository.md5Encode16(`${originName}${index}${title}`),
        title: title,
        isVolume: isVolume,
        tocLevel: tocLevel,
        bookUrl: bookUrl,
        index: index,
        wordCount: BookRepository.wordCountFormat(words),
        start: byteOffsets[index] ?? 0,
        end: byteOffsets[index + 1] ?? totalBytes
      };
      rows.push(row);
      if (isVolume) { tocLevel = 1; }
    }
    return rows;
  }

  static async readAllChapters(book: Book, useReplaceRules: boolean = true,
    chapters: BookChapter[] = []): Promise<string[]> {
    const chapterContents: string[] = [];
    await BookRepository.forEachChapter(book, (chapterContent: string, _chapterIndex: number): Promise<boolean> => {
      chapterContents.push(chapterContent);
      return Promise.resolve(true);
    }, useReplaceRules, chapters);
    return chapterContents;
  }

  /** 逐章处理本地正文，交付一章后让出事件循环，避免整本书占住界面线程。 */
  static async forEachChapter(
    book: Book,
    onChapter: (chapterContent: string, chapterIndex: number) => Promise<boolean>,
    useReplaceRules: boolean = true,
    chapters: BookChapter[] = []
  ): Promise<void> {
    if (book.contentPath === undefined) {
      throw new Error('本地书籍路径无效');
    }
    const encoding = book.format === 'txt' ? book.charset : undefined;
    const content = await BookRepository.readTextFileAsync(book.contentPath, encoding);
    const rows = chapters.length > 0 ? chapters : BookRepository.deriveChapters(book, content);
    if (rows.length === 0) {
      const chapter = await BookRepository.applyChapterContentAsync(
        book, book.lastChapter, content.substring(0, 50000), book.chapterIndex ?? 0, useReplaceRules
      );
      await onChapter(chapter, book.chapterIndex ?? 0);
      return;
    }
    const yieldAfterChapter = async (): Promise<void> => {
      await new Promise<void>((resolve: () => void) => setTimeout(resolve, 0));
    };
    for (let index = 0; index < rows.length; index++) {
      const row = rows[index];
      const body = BookRepository.chapterBody(book, content, row, encoding);
      const chapter = await BookRepository.applyChapterContentAsync(book, row.title, body, row.index, useReplaceRules);
      if (!(await onChapter(chapter, row.index))) { return; }
      await yieldAfterChapter();
    }
  }

  /**
   * 将章节编辑保存到应用导入副本，并同步重算章节行；不会写回用户选择的原文件。
   *
   * 正文重写后全书的字节偏移都会变，所以这里按新正文重算每一行的 start/end，
   * 与上游「改完章节再 update 章节表」等价。返回结果由调用方落库。
   */
  static async replaceLocalChapter(book: Book, chapterIndex: number, chapterTitle: string,
    chapterBody: string, chapters: BookChapter[]): Promise<ChapterReplaceResult> {
    if (book.contentPath === undefined || chapters.length === 0) {
      throw new Error('当前书籍没有可编辑的本地章节');
    }
    const encoding = book.format === 'txt' ? book.charset : undefined;
    const content = BookRepository.readTextFile(book.contentPath, encoding);
    const safeIndex = Math.max(0, Math.min(chapters.length - 1, Math.trunc(chapterIndex)));
    const title = chapterTitle.trim() || chapters[safeIndex].title || '';
    const body = chapterBody;
    const titles: string[] = [];
    const volumes: boolean[] = [];
    const offsets: number[] = [];
    const sections: string[] = [];
    let offset = 0;
    for (let index = 0; index < chapters.length; index++) {
      const row = chapters[index];
      const section = index === safeIndex
        ? `${title}\n\n${body}\n\n`
        : content.substring(
          BookRepository.byteOffsetToCharIndex(content, row.start ?? 0, encoding),
          BookRepository.byteOffsetToCharIndex(content, row.end ?? 0, encoding));
      titles.push(index === safeIndex ? title : row.title);
      volumes.push(row.isVolume);
      offsets.push(offset);
      sections.push(section);
      offset += section.length;
    }
    const updatedContent = sections.join('');

    const temporaryPath = `${book.contentPath}.edit-tmp`;
    const temporaryFile = fileIo.openSync(temporaryPath,
      fileIo.OpenMode.WRITE_ONLY | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC);
    try {
      fileIo.writeSync(temporaryFile.fd, updatedContent);
    } finally {
      fileIo.closeSync(temporaryFile);
    }
    const backupPath = `${book.contentPath}.edit-bak`;
    try {
      if (fileIo.accessSync(backupPath)) { fileIo.unlinkSync(backupPath); }
      fileIo.renameSync(book.contentPath, backupPath);
      fileIo.renameSync(temporaryPath, book.contentPath);
      try {
        fileIo.unlinkSync(backupPath);
      } catch (_) {
      }
    } catch (error) {
      try {
        if (!fileIo.accessSync(book.contentPath) && fileIo.accessSync(backupPath)) {
          fileIo.renameSync(backupPath, book.contentPath);
        }
      } catch (_) {
      }
      try {
        if (fileIo.accessSync(temporaryPath)) { fileIo.unlinkSync(temporaryPath); }
      } catch (_) {
      }
      if (error instanceof Error) { throw error; }
      throw new Error('章节内容保存失败');
    }

    const nextCharset = book.format === 'txt' ? 'UTF-8' : book.charset;
    const nextBook = BookRepository.copyBook(book);
    nextBook.lastChapter = title;
    nextBook.chapterCount = titles.length.toString();
    nextBook.charset = nextCharset;
    nextBook.androidCharacterPosition = 0;
    // 正文长度变了，全书的字节偏移都得重算，所以整批章节行重新生成后交给调用方落库。
    const nextChapters = BookRepository.buildChapterRows(book.contentPath, titles, offsets, volumes,
      updatedContent, nextCharset);
    return { book: nextBook, chapters: nextChapters };
  }

  /**
   * 把本地阅读进度转换成 Android 备份使用的章内字符位置。
   * 上游 Book.getReadProgress 没有对应实现，这里按「章内已读比例 × 该章正文长度」折算，
   * 章节行由调用方传入（页面已从 chapters 表查到），避免仓储内部再读一次库。
   */
  static async estimateAndroidChapterPosition(book: Book, chapters: BookChapter[] = []): Promise<number> {
    if (book.contentPath === undefined) { return 0; }
    try {
      const encoding = book.format === 'txt' ? book.charset : undefined;
      const content = BookRepository.readTextFile(book.contentPath, encoding);
      const rows = chapters.length > 0 ? chapters : BookRepository.deriveChapters(book, content);
      const chapterIndex = Math.max(0, Math.min(Math.max(0, rows.length - 1), book.chapterIndex ?? 0));
      const progress = Math.max(0, Math.min(100, book.chapterProgress ?? 0));
      const chapterLength = BookRepository.getChapterSemanticLength(book, content, rows, chapterIndex, encoding);
      // 有过 Android 章内位置的直接沿用（readerPositionVersion 已删除，有值即认为是字符位置）。
      if (book.androidCharacterPosition !== undefined) {
        return Math.max(0, Math.min(chapterLength, Math.trunc(book.androidCharacterPosition)));
      }
      return Math.round(chapterLength * progress / 100);
    } catch (_) {
      return 0;
    }
  }

  /** 把 Android 备份中的章内字符位置转换成本地阅读百分比。 */
  static async restoreAndroidProgress(book: Book, requestedIndex: number,
    characterPosition: number, chapters: BookChapter[] = []): Promise<Book> {
    let rows = chapters;
    if (rows.length === 0 && book.contentPath !== undefined) {
      try {
        const encoding = book.format === 'txt' ? book.charset : undefined;
        rows = BookRepository.deriveChapters(book, BookRepository.readTextFile(book.contentPath, encoding));
      } catch (_) {
        rows = [];
      }
    }
    const chapterIndex = Math.max(0,
      Math.min(Math.max(0, rows.length - 1), Math.trunc(requestedIndex)));
    let chapterProgress: number = 0;
    if (book.contentPath !== undefined) {
      try {
        const encoding = book.format === 'txt' ? book.charset : undefined;
        const content = BookRepository.readTextFile(book.contentPath, encoding);
        const chapterLength = BookRepository.getChapterSemanticLength(book, content, rows, chapterIndex, encoding);
        if (chapterLength > 0) {
          chapterProgress = Math.max(0, Math.min(100, characterPosition / chapterLength * 100));
        }
      } catch (_) {
      }
    }
    const next = BookRepository.copyBook(book);
    next.chapterIndex = chapterIndex;
    next.chapterProgress = chapterProgress;
    next.lastChapter = rows.length > 0 ? rows[chapterIndex].title : book.lastChapter;
    next.androidCharacterPosition = Math.max(0, Math.trunc(characterPosition));
    next.progress = BookRepository.readProgress(next);
    return next;
  }

private static chapterBodyStart(section: string, title: string): number {
    const titleEnd = section.indexOf('\n');
    if (titleEnd < 0 || title.trim().length === 0) { return 0; }
    const actualTitle = section.substring(0, titleEnd).replace(/\r$/, '').trim();
    return actualTitle.startsWith(title.trim()) ? titleEnd + 1 : 0;
  }
  /**
   * 取某一章正文在整本书字符串里的字符区间。
   *
   * 章节行存的是字节偏移（与上游 chapters.start/end 一致），这里按编码换算回字符下标；
   * 换算逐次线性扫描，只在需要章节语义长度的少数路径上调用，不在翻页热路径上。
   */
  private static getChapterTextRange(content: string, rows: BookChapter[], chapterIndex: number,
    encoding: string | undefined): ChapterTextRange {
    if (rows.length === 0) { return { start: 0, end: content.length }; }
    const index = Math.max(0, Math.min(rows.length - 1, chapterIndex));
    const row = rows[index];
    const chapterStart = BookRepository.byteOffsetToCharIndex(content, row.start ?? 0, encoding);
    const chapterEnd = BookRepository.byteOffsetToCharIndex(content, row.end ?? 0, encoding);
    const section = content.substring(chapterStart, chapterEnd);
    const bodyStart = BookRepository.chapterBodyStart(section, row.title);
    return { start: chapterStart + bodyStart, end: chapterEnd };
  }

  private static getChapterSemanticLength(book: Book, content: string, rows: BookChapter[],
    chapterIndex: number, encoding: string | undefined): number {
    const range = BookRepository.getChapterTextRange(content, rows, chapterIndex, encoding);
    const rawBody = content.substring(range.start, range.end).trim();
    const index = Math.max(0, Math.min(Math.max(0, rows.length - 1), chapterIndex));
    const title = rows.length > 0 ? rows[index].title : '';
    const body = book.format === 'epub'
      ? EpubRepository.removeDuplicateHeading(rawBody, title) : rawBody;
    const segmented = BookRepository.applyChapterReSegment(book, title, body);
    const replaced = ReplaceRuleRepository.applyContentForLength(book, segmented);
    const records = BookContentProcessRepository.getForChapter(book.id, index);
    const processed = BookContentProcessEngine.apply(replaced, records).text;
    return LocalTextSemantics.parse(processed).sourceLength;
  }

  private static applyChapterReSegment(book: Book, chapterTitle: string, body: string): string {
    return book.reSegment === true ? LocalTextReSegmenter.reSegment(body, chapterTitle) : body;
  }

private static async applyChapterContentAsync(
    book: Book,
    chapterTitle: string,
    body: string,
    requestedChapterIndex?: number,
    useReplaceRules: boolean = true
  ): Promise<string> {
    const segmented = BookRepository.applyChapterReSegment(book, chapterTitle, body);
    const ruleResult = useReplaceRules
      ? ReplaceRuleRepository.applyContentWithResult(book, chapterTitle, segmented)
      : undefined;
    // 章节下标由调用方给出（它已经从 chapters 行拿到了 index），不再靠标题反查
    const chapterIndex = requestedChapterIndex ?? book.chapterIndex ?? 0;
    if (ruleResult !== undefined) {
      BookRepository.rememberEffectiveReplaceRules(book.id, chapterIndex, ruleResult.effectiveRuleIds);
    }
    await BookContentProcessRepository.waitUntilLoaded();
    const records = BookContentProcessRepository.getForChapter(book.id, chapterIndex);
    return BookContentProcessEngine.apply(ruleResult?.text ?? segmented, records).text;
  }
  private static buildNoTocChapterLayout(
    content: string, maxLengthWithNoToc: number, charset?: string
  ): NoTocChapterLayout {
    const titles: string[] = [];
    const offsets: number[] = [];
    if (content.length === 0) { return { titles: ['全文'], offsets: [] }; }
    const maxLength = Math.max(3000, Math.min(100000, Math.round(maxLengthWithNoToc)));
    const normalizedCharset = (charset ?? 'UTF-8').toUpperCase();
    const utf8 = normalizedCharset.includes('UTF-8');
    const gb = normalizedCharset.startsWith('GB');
    const utf16 = normalizedCharset.includes('UTF-16');
    const thresholdBytes = maxLength * (utf8 ? 3 : gb || utf16 ? 2 : 1);
    let start = 0;
    let part = 1;
    while (start < content.length) {
      offsets.push(start);
      titles.push('第' + part.toString() + '章(1)');
      let end = content.length;
      let cursor = start;
      let scannedBytes = 0;
      while (cursor < content.length) {
        const code = content.charCodeAt(cursor);
        const next = cursor + 1 < content.length ? content.charCodeAt(cursor + 1) : 0;
        const surrogatePair = code >= 0xD800 && code <= 0xDBFF && next >= 0xDC00 && next <= 0xDFFF;
        const width = utf8 ? (surrogatePair ? 4 : code < 0x80 ? 1 : code < 0x800 ? 2 : 3)
          : gb ? (surrogatePair ? 4 : code < 0x80 ? 1 : 2) : utf16 ? 2 : 1;
        if (scannedBytes + width > 512000) { end = cursor; break; }
        if (scannedBytes >= thresholdBytes && code === 10) { end = cursor; break; }
        scannedBytes += width;
        cursor += surrogatePair ? 2 : 1;
      }
      if (end <= start) { end = Math.min(content.length, start + 1); }
      if (end >= content.length) { break; }
      start = end;
      part += 1;
    }
    return { titles: titles, offsets: offsets };
  }

  /** 重新匹配当前启用的 TXT 目录规则，并把阅读位置映射到新章节。 */
  static refreshToc(book: Book, maxLengthWithNoToc: number = 3000,
    chapters: BookChapter[] = []): TocRefreshResult {
    if (book.contentPath === undefined || book.format !== 'txt' || !book.isLocal) {
      return { book: book, chapters: [], content: '', changed: false, oldBodyOffsets: [], newBodyOffsets: [] };
    }
    const content = BookRepository.readTextFile(book.contentPath, book.charset);
    const chapterRule = BookRepository.resolveChapterRule(undefined, content);
    let chapterTitles: string[] = [];
    let chapterOffsets: number[] = [];
    let chapterVolumes: boolean[] = [];
    if (chapterRule.length > 0) {
      const split = BookRepository.splitChapters(content, chapterRule);
      chapterTitles = split.titles;
      chapterOffsets = split.offsets;
      chapterVolumes = split.volumes;
    }
    if (chapterOffsets.length === 0 && content.length > 0) {
      const layout = BookRepository.buildNoTocChapterLayout(content, maxLengthWithNoToc, book.charset);
      chapterTitles = layout.titles;
      chapterOffsets = layout.offsets;
      chapterVolumes = [];
    }
    // 旧目录从 chapters 行来；没传就说明这本书当前没有目录行。
    const oldTitles: string[] = [];
    const oldOffsets: number[] = [0];
    chapters.forEach((row: BookChapter) => {
      oldTitles.push(row.title);
      oldOffsets.push(row.end ?? 0);
    });
    let changed = (chapterRule.length > 0 ? chapterRule : undefined) !== book.tocRule ||
      oldTitles.length !== chapterTitles.length;
    for (let index = 0; !changed && index < chapterTitles.length; index++) {
      if (oldTitles[index] !== chapterTitles[index] ||
        (oldOffsets[index] ?? -1) !== (chapterOffsets[index] ?? -2) ||
        (chapters[index]?.isVolume === true) !== (chapterVolumes[index] === true)) {
        changed = true;
      }
    }
    if (!changed) {
      return { book: book, chapters: [], content: content, changed: false,
        oldBodyOffsets: [], newBodyOffsets: [] };
    }
    const oldBodyOffsets = BookRepository.getNoTocBodyOffsets(content, oldOffsets, oldTitles.length);
    const newBodyOffsets = BookRepository.getNoTocBodyOffsets(content, chapterOffsets, chapterTitles.length);
    const oldIndex = oldTitles.length > 0
      ? Math.max(0, Math.min(oldTitles.length - 1, book.chapterIndex ?? 0)) : 0;
    const oldStart = oldBodyOffsets[oldIndex] ?? 0;
    const oldEnd = oldOffsets[oldIndex + 1] ?? content.length;
    const oldBodyLength = Math.max(0, oldEnd - oldStart);
    const savedPosition = Math.max(0, Math.trunc(book.androidCharacterPosition ?? 0));
    // readerPositionVersion 已删除：有 androidCharacterPosition 就认为它是章内字符位置。
    const localPosition = book.androidCharacterPosition !== undefined
      ? savedPosition
      : Math.round(oldBodyLength * Math.max(0, Math.min(100, book.chapterProgress ?? 0)) / 100);
    const absolutePosition = Math.max(0, Math.min(content.length, oldStart + localPosition));
    let chapterIndex = 0;
    for (let index = 0; index < newBodyOffsets.length; index++) {
      if ((newBodyOffsets[index] ?? 0) > absolutePosition) { break; }
      chapterIndex = index;
    }
    chapterIndex = Math.min(chapterIndex, Math.max(0, chapterTitles.length - 1));
    const chapterStart = newBodyOffsets[chapterIndex] ?? 0;
    const chapterEnd = chapterOffsets[chapterIndex + 1] ?? content.length;
    const chapterPosition = Math.max(0, Math.min(chapterEnd - chapterStart, absolutePosition - chapterStart));
    const chapterProgress = chapterEnd > chapterStart ? chapterPosition / (chapterEnd - chapterStart) * 100 : 0;
    const chapterCount = Math.max(1, chapterTitles.length);
    const refreshedBook = BookRepository.copyBook(book);
    refreshedBook.chapterIndex = chapterIndex;
    refreshedBook.chapterProgress = chapterProgress;
    refreshedBook.lastChapter = chapterTitles[chapterIndex] ?? book.lastChapter;
    refreshedBook.progress = chapterTitles.length > 0
      ? (chapterIndex + chapterProgress / 100) / chapterCount * 100 : book.progress;
    refreshedBook.chapterCount = chapterTitles.length.toString();
    refreshedBook.androidCharacterPosition = chapterPosition;
    refreshedBook.tocRule = chapterRule.length > 0 ? chapterRule : undefined;
    // 更新目录会刷新 latestChapterTime，但阅读时间与手动序号由 copyBook 原样带回。
    refreshedBook.latestChapterTime = Date.now();
    const refreshedChapters = BookRepository.buildChapterRows(book.contentPath, chapterTitles,
      chapterOffsets, chapterVolumes, content, book.charset);
    return { book: refreshedBook, chapters: refreshedChapters, content: content, changed: true,
      oldBodyOffsets: oldBodyOffsets, newBodyOffsets: newBodyOffsets };
  }

static refreshNoTocBook(book: Book, maxLengthWithNoToc: number,
    chapters: BookChapter[] = []): NoTocBookRefreshResult {
    if (book.contentPath === undefined || book.format !== 'txt' || !book.isLocal) {
      return { book: book, chapters: [], content: '', changed: false, oldBodyOffsets: [], newBodyOffsets: [] };
    }
    // 当前目录来自 chapters 行，章节标题不再是 Book 的字段。
    const currentTitles: string[] = [];
    const currentOffsets: number[] = [0];
    chapters.forEach((row: BookChapter) => {
      currentTitles.push(row.title);
      currentOffsets.push(row.end ?? 0);
    });
    const isLegacyNoToc = currentTitles.length === 1 && currentTitles[0] === '全文';
    let isGeneratedNoToc = currentTitles.length > 0;
    for (let index = 0; index < currentTitles.length; index++) {
      if (!/^第\d+章\(1\)$/.test(currentTitles[index] ?? '')) {
        isGeneratedNoToc = false;
        break;
      }
    }
    if (!isLegacyNoToc && !isGeneratedNoToc) {
      return { book: book, chapters: [], content: '', changed: false, oldBodyOffsets: [], newBodyOffsets: [] };
    }
    const content = BookRepository.readTextFile(book.contentPath, book.charset);
    if (BookRepository.splitChapters(content, BookRepository.resolveChapterRule(undefined, content)).offsets.length > 0) {
      return { book: book, chapters: [], content: content, changed: false,
        oldBodyOffsets: [], newBodyOffsets: [] };
    }
    const layout = BookRepository.buildNoTocChapterLayout(content, maxLengthWithNoToc, book.charset);
    let layoutChanged = currentTitles.length !== layout.titles.length;
    for (let index = 0; !layoutChanged && index < layout.titles.length; index++) {
      if (currentTitles[index] !== layout.titles[index] ||
        (currentOffsets[index] ?? -1) !== (layout.offsets[index] ?? -2)) {
        layoutChanged = true;
      }
    }
    if (!layoutChanged) {
      return { book: book, chapters: [], content: content, changed: false,
        oldBodyOffsets: [], newBodyOffsets: [] };
    }
    const oldOffsets = currentOffsets;
    const oldBodyOffsets = BookRepository.getNoTocBodyOffsets(content, oldOffsets, currentTitles.length);
    const newBodyOffsets = BookRepository.getNoTocBodyOffsets(content, layout.offsets, layout.titles.length);
    const oldIndex = Math.max(0, Math.min(currentTitles.length - 1, book.chapterIndex ?? 0));
    const oldStart = oldBodyOffsets[oldIndex] ?? 0;
    const oldEnd = oldOffsets[oldIndex + 1] ?? content.length;
    const oldBodyLength = Math.max(0, oldEnd - oldStart);
    const savedPosition = Math.max(0, Math.trunc(book.androidCharacterPosition ?? 0));
    // readerPositionVersion 已删除：有 androidCharacterPosition 就认为它是章内字符位置。
    const localPosition = book.androidCharacterPosition !== undefined
      ? savedPosition
      : Math.round(oldBodyLength * Math.max(0, Math.min(100, book.chapterProgress ?? 0)) / 100);
    const absolutePosition = Math.max(0, Math.min(content.length, oldStart + localPosition));
    let chapterIndex = 0;
    for (let index = 0; index < newBodyOffsets.length; index++) {
      if ((newBodyOffsets[index] ?? 0) > absolutePosition) { break; }
      chapterIndex = index;
    }
    chapterIndex = Math.min(chapterIndex, Math.max(0, layout.titles.length - 1));
    const chapterStart = newBodyOffsets[chapterIndex] ?? 0;
    const chapterEnd = layout.offsets[chapterIndex + 1] ?? content.length;
    const chapterPosition = Math.max(0, Math.min(chapterEnd - chapterStart, absolutePosition - chapterStart));
    const chapterProgress = chapterEnd > chapterStart ? chapterPosition / (chapterEnd - chapterStart) * 100 : 0;
    const chapterCount = Math.max(1, layout.titles.length);
    const refreshedBook = BookRepository.copyBook(book);
    refreshedBook.chapterIndex = chapterIndex;
    refreshedBook.chapterProgress = chapterProgress;
    refreshedBook.lastChapter = layout.titles[chapterIndex] ?? book.lastChapter;
    refreshedBook.progress = (chapterIndex + chapterProgress / 100) / chapterCount * 100;
    refreshedBook.chapterCount = layout.titles.length.toString();
    refreshedBook.androidCharacterPosition = chapterPosition;
    const refreshedChapters = BookRepository.buildChapterRows(book.contentPath, layout.titles,
      layout.offsets, [], content, book.charset);
    return {
      book: refreshedBook,
      chapters: refreshedChapters,
      content: content,
      changed: true,
      oldBodyOffsets: oldBodyOffsets,
      newBodyOffsets: newBodyOffsets
    };
  }

private static getNoTocBodyOffsets(content: string, starts: number[], count: number): number[] {
    const offsets: number[] = [];
    for (let index = 0; index < count; index++) {
      const start = starts[index] ?? 0;
      const end = starts[index + 1] ?? content.length;
      const section = content.substring(start, end);
      let trimCount = 0;
      while (trimCount < section.length && /\s/.test(section.charAt(trimCount))) { trimCount++; }
      offsets.push(start + trimCount);
    }
    return offsets;
  }
  private static createLocalBook(
    id: string,
    title: string,
    contentPath: string,
    chapterIndex: number,
    chapterProgress: number,
    importedContent?: string,
    charset?: string,
    maxLengthWithNoToc: number = 3000
  ): CreatedLocalBook {
    let content: string = '';
    try {
      content = importedContent ?? BookRepository.readTextFile(contentPath, charset);
    } catch (_) {
    }
    const chapterRule = BookRepository.resolveChapterRule(undefined, content);
    let chapterTitles: string[] = [];
    let chapterOffsets: number[] = [];
    let chapterVolumes: boolean[] = [];
    if (chapterRule.length > 0) {
      const split = BookRepository.splitChapters(content, chapterRule);
      chapterTitles = split.titles;
      chapterOffsets = split.offsets;
      chapterVolumes = split.volumes;
    }
    if (chapterOffsets.length === 0 && content.length > 0) {
      const layout = BookRepository.buildNoTocChapterLayout(content, maxLengthWithNoToc, charset);
      chapterTitles = layout.titles;
      chapterOffsets = layout.offsets;
      chapterVolumes = [];
    }
    const safeChapterIndex = Math.max(0, Math.min(chapterTitles.length - 1, chapterIndex));
    const safeChapterProgress = Math.max(0, Math.min(100, chapterProgress));
    const overallProgress = chapterTitles.length > 0
      ? (safeChapterIndex + safeChapterProgress / 100) / chapterTitles.length * 100
      : 0;
    const book: Book = {
      id: id,
      title: title,
      author: '本地 TXT',
      category: '本地',
      groupName: '本地未分组',
      groupNames: [],
      tocRule: chapterRule.length > 0 ? chapterRule : undefined,
      // 新导入的书以导入时刻作为「最近更新」，未读过所以没有阅读时间。
      latestChapterTime: Date.now(),
      lastChapter: chapterTitles[safeChapterIndex],
      chapterIndex: safeChapterIndex,
      chapterProgress: safeChapterProgress,
      progress: overallProgress,
      chapterCount: chapterTitles.length.toString(),
      contentPath: contentPath,
      format: 'txt',
      charset: charset,
      reSegment: false,
      isLocal: true
    };
    // 章节行随书一起返回，调用方写库时两表一起落。
    const chapters = BookRepository.buildChapterRows(contentPath, chapterTitles, chapterOffsets,
      chapterVolumes, content, charset);
    return { book: book, chapters: chapters };
  }

private static readTextFile(path: string, encoding?: string): string {
    const sourceFile = fileIo.openSync(path, fileIo.OpenMode.READ_ONLY);
    try {
      const fileSize = fileIo.statSync(sourceFile.fd).size;
      if (fileSize <= 0) { return ''; }
      const buffer = new ArrayBuffer(fileSize);
      const bytesRead = fileIo.readSync(sourceFile.fd, buffer, { length: fileSize });
      if (bytesRead <= 0 || bytesRead !== fileSize) { throw new Error('TXT 文件读取不完整'); }
      const bytes = new Uint8Array(buffer, 0, bytesRead);
      const decoded = BookRepository.decodeTextBytes(bytes, encoding);
      return decoded.replace(/^\uFEFF/, '');
    } finally {
      fileIo.closeSync(sourceFile);
    }
  }

private static async readTextFileAsync(path: string, encoding?: string): Promise<string> {
    const sourceFile = await fileIo.open(path, fileIo.OpenMode.READ_ONLY);
    try {
      const fileSize = (await fileIo.stat(path)).size;
      if (fileSize <= 0) { return ''; }
      const chunks: Uint8Array[] = [];
      let offset = 0;
      const chunkSize = 512 * 1024;
      while (offset < fileSize) {
        const length = Math.min(chunkSize, fileSize - offset);
        const chunkBuffer = new ArrayBuffer(length);
        const bytesRead = await fileIo.read(sourceFile.fd, chunkBuffer, { length: length });
        if (bytesRead <= 0) { break; }
        chunks.push(new Uint8Array(chunkBuffer, 0, bytesRead));
        offset += bytesRead;
      }
      if (offset !== fileSize) { throw new Error('本地书籍文件读取不完整'); }
      const bytes = new Uint8Array(offset);
      let cursor = 0;
      for (let index = 0; index < chunks.length; index++) {
        const chunk = chunks[index];
        if (chunk === undefined) { continue; }
        bytes.set(chunk, cursor);
        cursor += chunk.length;
      }
      return BookRepository.decodeTextBytes(bytes, encoding).replace(/^\uFEFF/, '');
    } finally {
      await fileIo.close(sourceFile);
    }
  }

private static decodeTextBytes(bytes: Uint8Array, encoding?: string): string {
    if (encoding !== undefined && encoding.trim().length > 0) {
      const normalizedEncoding = encoding.trim().toLowerCase();
      if (normalizedEncoding === 'unicode' || normalizedEncoding === 'utf-16') {
        if (bytes.length >= 2 && bytes[0] === 0xFE && bytes[1] === 0xFF) {
          return BookRepository.decodeWithEncoding(bytes.slice(2), 'utf-16be');
        }
        if (bytes.length >= 2 && bytes[0] === 0xFF && bytes[1] === 0xFE) {
          return BookRepository.decodeWithEncoding(bytes.slice(2), 'utf-16le');
        }
        return BookRepository.decodeWithEncoding(bytes, 'utf-16le');
      }
      const requestedEncoding = encoding.trim();
      return BookRepository.decodeWithEncoding(bytes, requestedEncoding);
    }
    if (bytes.length >= 3 && bytes[0] === 0xEF && bytes[1] === 0xBB && bytes[2] === 0xBF) {
      return BookRepository.decodeWithEncoding(bytes.slice(3), 'utf-8');
    }
    if (bytes.length >= 2 && bytes[0] === 0xFF && bytes[1] === 0xFE) {
      return BookRepository.decodeWithEncoding(bytes.slice(2), 'utf-16le');
    }
    if (bytes.length >= 2 && bytes[0] === 0xFE && bytes[1] === 0xFF) {
      return BookRepository.decodeWithEncoding(bytes.slice(2), 'utf-16be');
    }
    const utf8 = BookRepository.tryDecodeWithEncoding(bytes, 'utf-8');
    if (utf8 !== undefined) { return utf8; }
    const gb18030 = BookRepository.tryDecodeWithEncoding(bytes, 'gb18030');
    if (gb18030 !== undefined) { return gb18030; }
    const big5 = BookRepository.tryDecodeWithEncoding(bytes, 'big5');
    if (big5 !== undefined) { return big5; }
    throw new Error('TXT 编码无法识别，请使用 UTF-8、GBK/GB18030 或 Big5 格式');
  }

private static decodeWithEncoding(bytes: Uint8Array, encoding: string): string {
    const text = BookRepository.tryDecodeWithEncoding(bytes, encoding);
    if (text === undefined) {
      throw new Error(`TXT 文件不是有效的 ${encoding} 文本`);
    }
    return text;
  }

private static tryDecodeWithEncoding(bytes: Uint8Array, encoding: string): string | undefined {
    try {
      const decoder = util.TextDecoder.create(encoding, { fatal: true, ignoreBOM: true });
      return decoder.decodeToString(bytes);
    } catch (_) {
      return undefined;
    }
  }

private static getFileName(uri: string): string {
    const separator = uri.lastIndexOf('/');
    const rawName = separator >= 0 ? uri.substring(separator + 1) : uri;
    try {
      return decodeURIComponent(rawName);
    } catch (_) {
      return rawName;
    }
  }

private static ensureDirectory(path: string): void {
    try {
      fileIo.mkdirSync(path, true);
    } catch (error) {
      try {
        if (fileIo.lstatSync(path).isDirectory()) { return; }
      } catch (_) {
      }
      if (error instanceof Error) { throw error; }
      throw new Error('无法创建本地书籍目录');
    }
  }

private static getTitle(fileName: string): string {
    const lowerName = fileName.toLowerCase();
    if (lowerName.endsWith('.txt')) {
      return fileName.substring(0, fileName.length - 4);
    }
    return fileName.length > 0 ? fileName : '本地书籍';
  }

/** 选择 TXT 章节规则；无用户规则命中时保留旧版默认识别，避免升级后旧书突然变成整本一章。 */
  private static resolveChapterRule(cachedRule: string | undefined, content: string): string {
    if (cachedRule !== undefined && cachedRule.length > 0) { return cachedRule; }
    const sample = content.length > BookRepository.tocSampleSize
      ? content.substring(0, BookRepository.tocSampleSize) : content;
    const selected = TxtTocRuleRepository.selectForSample(sample).rule;
    return selected?.chapterRule ?? '^(第.{1,18}[章节回卷篇]|序章|楔子|番外)';
  }

  /** 标题、起点与卷标记来自同一次匹配，确保阅读偏移和目录显示对齐。 */
  private static splitChapters(content: string, chapterRule: string): ChapterSplit {
    const resolvedRule = chapterRule.trim().length > 0
      ? chapterRule : BookRepository.resolveChapterRule(undefined, content);
    const starts = TxtTocRuleRepository.splitChapterStarts(content, resolvedRule);
    const titles: string[] = [];
    starts.forEach((start: number) => {
      const lineEnd = content.indexOf('\n', start);
      const rawLine = lineEnd >= 0 ? content.substring(start, lineEnd) : content.substring(start);
      titles.push(rawLine.replace(/\r$/, '').trim().substring(0, 80));
    });
    const volumeRule = TxtTocRuleRepository.resolveVolumeRule(resolvedRule);
    return {
      titles: titles,
      offsets: starts,
      volumes: TxtTocRuleRepository.markVolumeTitles(titles, volumeRule)
    };
  }

}

