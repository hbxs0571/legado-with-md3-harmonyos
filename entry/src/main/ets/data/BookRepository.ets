import { fileIo, picker } from '@kit.CoreFileKit';
import { preferences, relationalStore } from '@kit.ArkData';
import { util } from '@kit.ArkTS';
import { cryptoFramework } from '@kit.CryptoArchitectureKit';
import { Book, BookChapter, BookMediaType, bookCoverColor, bookCoverMark } from '../model/Book';
import { AppLog } from '../lib/AppLog';
import { EpubRepository } from './EpubRepository';
import { LocalTextSemantics } from './LocalTextSemantics';
import { LocalTextReSegmenter } from './LocalTextReSegmenter';
import { ReplaceRuleRepository } from './ReplaceRuleRepository';
import { BookContentProcessRepository } from './BookContentProcessRepository';
import { BookContentProcessEngine } from './BookContentProcessEngine';
import { ChineseTextConverter } from './ChineseTextConverter';
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
  /** 对应上游 Book.config.useReplaceRule；缺省表示跟随全局默认。 */
  useReplaceRule?: boolean;
  /**
   * 章内百分比（0-100），对应 Book.chapterProgress。
   *
   * durChapterPos 只有一列，现在存的是**章内字符位置**（androidCharacterPosition），
   * 百分比没有列可放，所以随阅读配置一起塞进 readConfig。
   * 两者语义不同，不能共用一个数：百分比要乘章长才是字符位置，反过来除章长才是百分比，
   * 而 readBookRow 是同步函数，拿不到章长，只能靠存两份。
   */
  chapterProgress?: number;
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
  /** 第一个标题前的正文（上游「前言」章的正文），没有则 undefined。 */
  intro?: string;
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

/**
 * 单条目录规则的预览结果。
 * `chapterTitles` 只是前 500 条样本（够用户在预览页看出这条规则切出的章名长什么样），
 * `totalCount` 是全书命中总数，预览卡片上的「N 章」徽章用它。
 */
export interface TocRulePreviewResult {
  chapterTitles: string[];
  totalCount: number;
}

/** 目录规则预览的分片扫描结果：本次扫到哪一行、命中几条；`aborted` 表示规则坏了不用再扫。 */
export interface TocRulePreviewChunk {
  matched: number;
  nextIndex: number;
  aborted: boolean;
}

export class BookRepository {
  /**
   * 简繁转换档位，由 Index 在装载/变更阅读设置时注入（对齐上游 ReadSettings.chineseConverterType）。
   * 正文处理管线是静态方法，拿不到 Context，因此用注入而不是每次读偏好。
   */
  private static chineseConverterType: number = 0;

  /** 由页面注入当前的简繁转换档位；0 = 不转换。 */
  static setChineseConverterType(type: number): void {
    BookRepository.chineseConverterType = ChineseTextConverter.normalizeType(type);
  }

  /** 当前注入的简繁转换档位。 */
  static getChineseConverterType(): number {
    return BookRepository.chineseConverterType;
  }

  private static readonly preferenceName: string = 'legado_local_books';
  private static effectiveRuleIdsByChapter: Map<string, number[]> = new Map<string, number[]>();
  private static effectiveRuleCacheOrder: string[] = [];
  private static saveQueue: Promise<void> = Promise.resolve();
  /** 章节行缓存：bookUrl → 章节行，供页面上的同步访问器读取。 */
  private static chapterCache: Map<string, BookChapter[]> = new Map<string, BookChapter[]>();
  /** 当前书正文缓存：换章整本重读解码太慢，只留当前这一本，key = contentPath|编码。 */
  private static cachedBookContentKey: string = '';
  private static cachedBookContent: string = '';
  /** 正文缓存体积上限（按解码后 UTF-16 占用估算）：超过就不缓存。 */
  private static readonly bookContentCacheLimitBytes: number = 32 * 1024 * 1024;
  /** 规则匹配只扫描文件开头，与 Android 只读首个缓冲区识别目录的行为一致。 */
  private static readonly tocSampleSize: number = 65536;
  /** 单章允许的最大字节数，超过就二次拆分；与上游 TextFile.kt:66 的 maxLengthWithToc 同值。 */
  private static readonly maxLengthWithToc: number = 102400;
  /** 目录规则预览最多列出这么多章标题，超出只计数不再收集；与上游 preview 同值。 */
  static readonly previewChapterLimit: number = 500;
  /** 编码识别只看文件头这么多字节：16K 足够判断 GBK/UTF-8/Big5，又不至于让打开大书时卡首帧。 */
  private static readonly encodingSampleSize: number = 16384;

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
    '`durChapterTime`, `order`, `disableReadRecord`, `format`, `latestChapterTitle`, `lastCheckCount`, `wordCount` FROM `books` ORDER BY `durChapterTime` DESC';

  /** 写入或覆盖一行书目。36 列全部给值，主键冲突时整行覆盖。 */
  private static readonly upsertBookSql: string =
    'INSERT OR REPLACE INTO `books` (`bookUrl`, `tocUrl`, `origin`, `originName`, `name`, `author`, ' +
    '`kind`, `customTag`, `coverUrl`, `customCoverUrl`, `intro`, `customIntro`, `remark`, `charset`, ' +
    '`type`, `group`, `isPrivate`, `latestChapterTitle`, `latestChapterTime`, `lastCheckTime`, ' +
    '`lastCheckCount`, `totalChapterNum`, `durChapterTitle`, `durChapterIndex`, `durChapterPos`, ' +
    '`durChapterTime`, `wordCount`, `canUpdate`, `disableReadRecord`, `order`, `originOrder`, ' +
    '`variable`, `readConfig`, `syncTime`, `listIntro`, `format`) ' +
    'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)';

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
    } catch (error) {
      AppLog.put(`[BookRepository] 检查正文文件是否存在失败: ${error}`);
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
    } catch (error) {
      AppLog.put(`[BookRepository] 计算内容摘要失败: ${error}`);
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

  /** 全书字数：以正文字符数估算，复用 wordCountFormat 格式化成「12.3万字」这类字符串。 */
  private static totalWordCount(content: string): string {
    return BookRepository.wordCountFormat(content.trim().length);
  }

  /** 书架卡「未读章节数」：总章数 - 当前章序号 - 1，不小于 0（上游 BookShelfItem 同款算法）。 */
  static unreadOf(book: Book): number {
    const total = Number(book.chapterCount ?? '0');
    const index = book.chapterIndex ?? 0;
    return Math.max(total - index - 1, 0);
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
      disableReadRecord: book.disableReadRecord,
      latestChapterTitle: book.latestChapterTitle,
      lastCheckCount: book.lastCheckCount,
      wordCount: book.wordCount,
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
    // 正文文件名由**源文件 uri** 派生，不取当前时间：上游 LocalBook.kt:252-259 里
    // `bookUrl = FileDoc.fromUri(uri).toString()`，即本地书的 bookUrl 就是源文件路径，
    // 同一文件重复导入得到同一个 bookUrl，判重才可能命中（见 LocalBook.kt:259）。
    // 旧实现用 `local-${Date.now()}`，每次导入都是一个新主键，任何按文件路径的判重都会失效。
    const bookId = `local-${BookRepository.md5Encode16(uri)}`;
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
      // 同一源文件重复导入会落到同一个 contentPath 上：先把上一份删掉再拷，
      // 否则 copyFileSync 在目标已存在时会失败。上游不存副本（直接读源 uri），没有这一步。
      if (fileIo.accessSync(contentPath)) { fileIo.unlinkSync(contentPath); }
      // 同名文件重新导入仍是同一个 contentPath，缓存 key 不变；不清掉会一直读旧正文。
      BookRepository.invalidateBookContent(contentPath);
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
      } catch (error) {
        AppLog.put(`[BookRepository] 删除损坏的正文文件失败: ${error}`);
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
    } catch (error) {
      AppLog.put(`[BookRepository] 解析分组名失败: ${error}`);
      return [];
    }
  }

private static isGroupNamesField(value: string | undefined): boolean {
    try {
      const parsed: string[] = JSON.parse(decodeURIComponent(value ?? ''));
      return Array.isArray(parsed) && parsed.every((name: string) => typeof name === 'string');
    } catch (error) {
      AppLog.put(`[BookRepository] 判断分组名字段失败: ${error}`);
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
    } catch (error) {
      console.error(`[BookRepository] 读取旧版正文文件失败: ${error}`);
      // 正文文件已不在：章节标题仍然保留，偏移按 0 处理。
      content = '';
    }
    const offsets = hasOffsets ? legacy.offsets : [];
    return BookRepository.buildChapterRows(legacy.bookUrl, legacy.titles, offsets,
      legacy.volumes, content, charset);
  }

  /**
   * 读取书架。上游用 Room，`bookDao.flowAll` 直接查 books 表；
   * 这里同样只以库为准——老 preferences 数据已由 RdbCleanup 清掉，
   * 回退只会读到空表，所以失败时记日志并返回空书架。
   * 章节不再随书返回，页面需要时调 getChapterList 查 chapters 表。
   */
  static async loadImportedBooks(context: Context): Promise<Book[]> {
    try {
      return await BookRepository.loadBooksFromDb(context);
    } catch (error) {
      console.error(`书架读取失败：${error instanceof Error ? error.message : String(error)}`);
      return [];
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
      // durChapterPos 现在存章内**字符位置**（与 Index.updateReadingProgress 的写入侧一致），
      // 上游 ReaderPage 也按字符位置定位，不是百分比。这里过去整段漏了回填，
      // 导致开书时 androidCharacterPosition 恒为 undefined、每次都停在第 1 页。
      //
      // 兼容存量：readConfig 里有 chapterProgress 才是新格式（两者同时写）；
      // 没有这个键的是旧行，durChapterPos 那时存的是百分比，不能当字符位置用，
      // 否则会把 2% 读成「第 2 个字符」。旧行留 undefined，渲染侧仍按百分比定位。
      androidCharacterPosition: config.chapterProgress === undefined
        ? undefined : RdbCodec.integer(resultSet, 6, 0),
      chapterProgress: config.chapterProgress ?? RdbCodec.integer(resultSet, 6, 0),
      lastChapter: RdbCodec.text(resultSet, 7),
      chapterCount: RdbCodec.integer(resultSet, 8, 0).toString(),
      progress: 0,
      coverUri: RdbCodec.optionalText(resultSet, 15),
      customCoverUri: RdbCodec.optionalText(resultSet, 16),
      bookType: bookTypeValue === 64 ? 'image' : bookTypeValue === 32 ? 'audio' : 'text',
      fixedType: config.fixedType === true,
      contentPath: bookUrl.length > 0 ? bookUrl : undefined,
      format: BookRepository.normalizeFormat(RdbCodec.optionalText(resultSet, 23), bookUrl),
      imageStyle: config.imageStyle,
      reSegment: config.reSegment === true,
      useReplaceRule: config.useReplaceRule,
      charset: RdbCodec.optionalText(resultSet, 14),
      description: RdbCodec.optionalText(resultSet, 11),
      remark: RdbCodec.optionalText(resultSet, 12),
      customTag: RdbCodec.optionalText(resultSet, 13),
      androidOriginalPath: RdbCodec.optionalText(resultSet, 10),
      tocRule: RdbCodec.optionalText(resultSet, 9),
      latestChapterTime: RdbCodec.optionalInteger(resultSet, 19),
      durChapterTime: RdbCodec.optionalInteger(resultSet, 20),
      order: RdbCodec.optionalInteger(resultSet, 21),
      disableReadRecord: RdbCodec.boolean(resultSet, 22, false),
      latestChapterTitle: RdbCodec.optionalText(resultSet, 24),
      lastCheckCount: RdbCodec.integer(resultSet, 25, 0),
      wordCount: RdbCodec.optionalText(resultSet, 26),
      isLocal: true
    };
    book.progress = BookRepository.readProgress(book);
    return book;
  }

  /**
   * 归一化书的格式。
   * 优先信库里的 format 列；老库该列为空串时退回按路径后缀判，
   * 与 format 列落地之前的行为保持一致，避免存量书目全变 txt。
   */
  private static normalizeFormat(stored: string | undefined, bookUrl: string): 'txt' | 'epub' {
    if (stored === 'epub' || stored === 'txt') {
      return stored;
    }
    return bookUrl.toLowerCase().endsWith('.epub') ? 'epub' : 'txt';
  }

  /** 解析 readConfig JSON，只关心本地有对应字段的三项。 */
  private static parseReadConfig(text: string | undefined): StoredReadConfig {
    if (text === undefined || text.length === 0) { return {}; }
    try {
      return JSON.parse(text) as StoredReadConfig;
    } catch (error) {
      console.error(`[BookRepository] 解析阅读配置失败: ${error}`);
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
    } catch (error) {
      console.error(`[BookRepository] 扫描本地书目失败: ${error}`);
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

  /** 单独为某本书开/关阅读记录，对应上游 BookDao.setReadRecordDisabled。 */
  static async setDisableReadRecord(context: Context, bookUrl: string, disabled: boolean): Promise<void> {
    if (bookUrl.length === 0) { return; }
    const store = await RdbStore.getStore(context);
    await RdbSchema.ensure(store);
    const args: relationalStore.ValueType[] = [disabled ? 1 : 0, bookUrl];
    await store.executeSql('UPDATE `books` SET `disableReadRecord` = ? WHERE `bookUrl` = ?', args);
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

  /** 把一本书摊成 books 表的 36 个绑定值，顺序必须与 upsertBookSql 一致。 */
  private static toBookArgs(book: Book): relationalStore.ValueType[] {
    const bookUrl = book.contentPath ?? book.androidOriginalPath ?? '';
    const originName = book.androidOriginalPath ?? BookRepository.getFileName(bookUrl);
    const groupNames = book.groupNames ?? ((book.groupName ?? '').length > 0 ? [book.groupName as string] : []);
    // useReplaceRule 为 undefined 时 JSON.stringify 会丢掉该键，
    // 正好对应上游「ReadConfig.useReplaceRule = null 表示跟随全局默认」的语义
    const readConfig: StoredReadConfig = {
      imageStyle: book.imageStyle,
      reSegment: book.reSegment === true,
      fixedType: book.fixedType === true,
      useReplaceRule: book.useReplaceRule,
      // 章内百分比没有独立列，与阅读配置一起存；读回时 readBookRow 从同一处取。
      chapterProgress: Math.max(0, Math.min(100, book.chapterProgress ?? 0))
    };
    const totalChapterNum = Number(book.chapterCount ?? '0');
    const lastChapter = book.lastChapter.length > 0 ? book.lastChapter : null;
    const latestChapterTitle = book.latestChapterTitle ?? lastChapter;
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
      latestChapterTitle,
      book.latestChapterTime ?? 0,
      0,
      book.lastCheckCount ?? 0,
      Number.isFinite(totalChapterNum) ? Math.max(0, Math.trunc(totalChapterNum)) : 0,
      lastChapter,
      Math.max(0, Math.trunc(book.chapterIndex ?? 0)),
      // durChapterPos 只有一列，存章内字符位置（上游 ReaderPage 按字符位置定位）；
      // 章内百分比在 readConfig 里，见上面的 StoredReadConfig.chapterProgress。
      Math.max(0, Math.trunc(book.androidCharacterPosition ?? 0)),
      book.durChapterTime ?? 0,
      book.wordCount ?? null,
      1,
      book.disableReadRecord === true ? 1 : 0,
      Math.trunc(book.order ?? 0),
      0,
      null,
      JSON.stringify(readConfig),
      0,
      null,
      book.format ?? ''
    ];
  }

  /** 上游 BookType 位掩码：text=8、audio=32、image=64，本地书再加 local=256。 */
  static bookTypeMask(book: Book): number {
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
    nextBook.wordCount = BookRepository.totalWordCount(content);
    nextBook.latestChapterTitle = chapterTitles.length > 0 ? chapterTitles[chapterTitles.length - 1] : undefined;
    return { book: nextBook, chapters: nextChapters };
  }

  static withReSegment(book: Book, enabled: boolean): Book {
    const next = BookRepository.copyBook(book);
    next.reSegment = enabled;
    return next;
  }

  /** 读整本正文，命中当前书缓存就复用；key 含编码，换书/换编码自然失效。 */
  private static readBookContent(path: string, encoding: string | undefined): string {
    const key = `${path}|${encoding ?? ''}`;
    if (BookRepository.cachedBookContentKey === key && BookRepository.cachedBookContent.length > 0) {
      return BookRepository.cachedBookContent;
    }
    const content = BookRepository.readTextFile(path, encoding);
    // 按解码后字符串的 UTF-16 占用估算（每单元 2 字节）：超过 32MB 就不缓存，
    // 免得把几十 MB 的解码结果常驻在低内存设备上。大文件直接读、直接扔。
    if (content.length * 2 <= BookRepository.bookContentCacheLimitBytes) {
      BookRepository.cachedBookContentKey = key;
      BookRepository.cachedBookContent = content;
    } else {
      BookRepository.cachedBookContentKey = '';
      BookRepository.cachedBookContent = '';
    }
    return content;
  }

  /** 文件被改写后让正文缓存失效：下次 readChapter 必须重新读盘。 */
  private static invalidateBookContent(path: string | undefined): void {
    if (path !== undefined && BookRepository.cachedBookContentKey.startsWith(`${path}|`)) {
      BookRepository.cachedBookContentKey = '';
      BookRepository.cachedBookContent = '';
    }
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
    // 换章会反复进来，正文缓存把整本读盘+解码从「每章一次」压成「每本一次」；
    // contentOverride 是调用方现算好的正文（重新分段/换字符集），不查也不写缓存。
    const contentStartedAt = Date.now();
    const content = contentOverride ?? BookRepository.readBookContent(book.contentPath, encoding);
    // 性能观测打点：验收要对比同书连读里取正文那段耗时，缓存命中后应显著下降。
    if (contentOverride === undefined) {
      console.info(`[ReaderBench] readChapter contentMs=${Date.now() - contentStartedAt} title=${chapterTitle}`);
    }
    // 章节行已经是落库的权威数据，能用就用：deriveChapters 要把整本正文重切一遍
    // 并逐章折算字节长度，几 MB 的书在主线程上要两秒以上（会触发 THREAD_BLOCK_6S）。
    let rows = chapters;
    if (rows.length === 0) {
      rows = BookRepository.cachedChapters(book);
    }
    if (rows.length === 0) {
      rows = BookRepository.deriveChapters(book, content);
    }
    if (rows.length === 0) {
      const applyStartedAt = Date.now();
      const fallbackContent = await BookRepository.applyChapterContentAsync(book, chapterTitle,
        content.substring(0, 50000), book.chapterIndex ?? 0);
      console.info(`[ReaderBench] readChapter applyMs=${Date.now() - applyStartedAt} fallback=true title=${chapterTitle}`);
      return fallbackContent;
    }
    const selectedIndex = BookRepository.resolveChapterIndex(rows, chapterTitle, requestedChapterIndex, book);
    const chapter = rows[selectedIndex];
    const body = BookRepository.chapterBody(book, content, chapter, encoding);
    const applyStartedAt = Date.now();
    const applied = await BookRepository.applyChapterContentAsync(book, chapter.title, body, chapter.index);
    console.info(`[ReaderBench] readChapter applyMs=${Date.now() - applyStartedAt} fallback=false title=${chapter.title}`);
    return applied;
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
   * 一次顺序扫描把一组「递增的」字节偏移换算成字符下标。
   *
   * 逐章调用 byteOffsetToCharIndex 时每章都要从全书开头重扫一遍，1378 章的书
   * 是 O(N²)（十几亿次字符迭代），目录页的字数统计会把界面线程卡到 ANR。
   * 章节行的 start/end 本身按正文顺序递增，扫一遍就能全部换算完。
   */
  private static byteOffsetsToCharIndices(content: string, byteOffsets: number[],
    encoding: string | undefined): number[] {
    const result: number[] = [];
    if (byteOffsets.length === 0) { return result; }
    const normalized = BookRepository.normalizeEncoding(encoding);
    let targetIndex = 0;
    let charIndex = 0;
    let byteCount = 0;
    while (targetIndex < byteOffsets.length && byteOffsets[targetIndex] <= 0) {
      result.push(0);
      targetIndex++;
    }
    while (charIndex < content.length && targetIndex < byteOffsets.length) {
      const width = BookRepository.charByteWidth(content, charIndex, normalized);
      charIndex += width === 4 ? 2 : 1;
      byteCount += width;
      while (targetIndex < byteOffsets.length && byteOffsets[targetIndex] <= byteCount) {
        result.push(charIndex);
        targetIndex++;
      }
    }
    while (result.length < byteOffsets.length) {
      result.push(content.length);
    }
    return result;
  }

  /**
   * 预先算出每一章的字符区间；只要有一行缺 start/end 就返回 undefined，
   * 调用方退回逐章换算（增量导入等少数路径）。
   */
  private static sequentialChapterRanges(content: string, rows: BookChapter[],
    encoding: string | undefined): ChapterTextRange[] | undefined {
    const starts: number[] = [];
    const ends: number[] = [];
    for (let index = 0; index < rows.length; index++) {
      const row = rows[index];
      if (row === undefined || row.start === undefined || row.end === undefined) { return undefined; }
      starts.push(row.start);
      ends.push(row.end);
    }
    const startChars = BookRepository.byteOffsetsToCharIndices(content, starts, encoding);
    const endChars = BookRepository.byteOffsetsToCharIndices(content, ends, encoding);
    const ranges: ChapterTextRange[] = [];
    for (let index = 0; index < rows.length; index++) {
      ranges.push({ start: startChars[index] ?? 0, end: endChars[index] ?? content.length });
    }
    return ranges;
  }

  /**
   * 取一章的正文（已去掉标题行）。
   * start/end 是字节偏移，先换算成字符下标再切字符串，与上游按字节 seek 等价。
   * charRange 是调用方已经算好的字符区间，批量路径传它以避免逐章重扫全书。
   */
  private static chapterBody(book: Book, content: string, chapter: BookChapter,
    encoding: string | undefined, charRange?: ChapterTextRange): string {
    const startChar = charRange !== undefined ? charRange.start
      : chapter.start === undefined ? 0 : BookRepository.byteOffsetToCharIndex(content, chapter.start, encoding);
    const endChar = charRange !== undefined ? charRange.end
      : chapter.end === undefined ? content.length : BookRepository.byteOffsetToCharIndex(content, chapter.end, encoding);
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
    // 章节行的 start/end 按正文顺序递增，一次性换算完字符区间；
    // 逐章调用 byteOffsetToCharIndex 是 O(N²)，大目录（上千章）会卡死界面线程。
    const sequentialRanges = BookRepository.sequentialChapterRanges(content, rows, encoding);
    for (let index = 0; index < rows.length; index++) {
      const row = rows[index];
      const body = BookRepository.chapterBody(book, content, row, encoding,
        sequentialRanges !== undefined ? sequentialRanges[index] : undefined);
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
      // 正文文件已被改写，紧接着 saveReaderChapterContent 会再 readChapter；清缓存才不会读回旧正文。
      BookRepository.invalidateBookContent(book.contentPath);
      try {
        fileIo.unlinkSync(backupPath);
      } catch (error) {
        console.error(`[BookRepository] 删除正文备份失败: ${error}`);
      }
    } catch (error) {
      try {
        if (!fileIo.accessSync(book.contentPath) && fileIo.accessSync(backupPath)) {
          fileIo.renameSync(backupPath, book.contentPath);
        }
      } catch (error) {
        console.error(`[BookRepository] 回滚正文备份失败: ${error}`);
      }
      try {
        if (fileIo.accessSync(temporaryPath)) { fileIo.unlinkSync(temporaryPath); }
      } catch (error) {
        console.error(`[BookRepository] 删除临时正文失败: ${error}`);
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
    nextBook.wordCount = BookRepository.totalWordCount(updatedContent);
    nextBook.latestChapterTitle = titles.length > 0 ? titles[titles.length - 1] : undefined;
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
    } catch (error) {
      console.error(`[BookRepository] 计算章内字符位置失败: ${error}`);
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
      } catch (error) {
        console.error(`[BookRepository] 推导章节目录失败: ${error}`);
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
      } catch (error) {
        console.error(`[BookRepository] 计算章内进度失败: ${error}`);
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
    // ① 去重复标题：正文首行如果又抄了一遍章节名（常见于 TXT 转码工具），先剥掉，
    //    否则正文第一段会和页眉/标题重复出现。对齐上游 ContentProcessor.kt:126-155。
    const deduped = BookRepository.removeDuplicateChapterTitle(book, chapterTitle, body);
    // ② 重新分段（按书开关）。
    const segmented = BookRepository.applyChapterReSegment(book, chapterTitle, deduped);
    // ③ 简繁转换：上游 ContentProcessor.kt:161-171 把它放在 reSegment 之后、HTML 占位之前，
    //    所以替换规则匹配的是转换后的字形（用户写「后」的规则也能命中「後」）。
    const converted = ChineseTextConverter.convert(segmented, BookRepository.chineseConverterType);
    // ④ 特殊样式占位：`<usehtml>…</usehtml>` 在跑替换规则之前先换成占位符，
    //    避免用户写的 `。`→``、`<`→`` 这类规则把富文本标签拆坏；⑥ 之后再原样还原。
    //    对齐上游 ContentProcessor.kt:157-166（AppPattern.useHtmlRegex + useHtmlMap）。
    const htmlMap: Map<string, string> = new Map<string, string>();
    const protectedText = BookRepository.maskSpecialStyle(converted, htmlMap);
    // ⑤ 替换净化：正则规则进 worker 计时，单条超时自动停用（上游 RegexTimeoutException 口径）。
    const ruleResult = useReplaceRules
      ? await ReplaceRuleRepository.applyContentWithResultAsync(book, chapterTitle, protectedText)
      : undefined;
    // ⑥ 还原特殊样式。
    const restored = BookRepository.unmaskSpecialStyle(ruleResult?.text ?? protectedText, htmlMap);
    // 章节下标由调用方给出（它已经从 chapters 行拿到了 index），不再靠标题反查
    const chapterIndex = requestedChapterIndex ?? book.chapterIndex ?? 0;
    if (ruleResult !== undefined) {
      BookRepository.rememberEffectiveReplaceRules(book.id, chapterIndex, ruleResult.effectiveRuleIds);
    }
    await BookContentProcessRepository.waitUntilLoaded();
    const records = BookContentProcessRepository.getForChapter(book.id, chapterIndex);
    // ⑦ 书内净化与用户标记；⑩ 逐行 trim 去空行（对齐上游 ContentProcessor.kt:247-259）。
    const processed = BookContentProcessEngine.apply(restored, records).text;
    const trimmed = BookRepository.trimChapterParagraphs(processed);
    // ⑧ 拼回标题由渲染层负责（本地章节标题单独排版，不再塞回正文），
    //    这与上游 `includeTitle` 的口径差异已在 TXT-READER 表 A3 记录。
    // ⑨ `\u00A0` → 空格只在 Android 8 上做（上游 `isAndroid8`），HarmonyOS 无此步骤。
    return trimmed;
  }

  /**
   * 剥掉正文开头重复出现的章节标题。
   *
   * 上游 `ContentProcessor.kt:131-153` 的正则是
   * `^(\s|\p{P}|书名)*标题(\s)*`，即允许标题前有空白、标点、书名；标题内部的空格
   * 按 `\s*` 放宽。这里用等价写法：把标题按空白拆开逐段拼进正则，容忍任意空白。
   */
  private static removeDuplicateChapterTitle(book: Book, chapterTitle: string, body: string): string {
    const title = chapterTitle.trim();
    if (title.length === 0 || body.length === 0) { return body; }
    const titlePattern = title.replace(/[.*+?^${}()|[\]\\]/g, '\\$&').replace(/\s+/g, '\\s*');
    const bookPattern = book.title.trim().length > 0
      ? book.title.trim().replace(/[.*+?^${}()|[\]\\]/g, '\\$&') : '';
    const prefix = bookPattern.length > 0
      ? `^([\\s\\u3000\\p{P}]|${bookPattern})*${titlePattern}[\\s\\u3000]*`
      : `^[\\s\\u3000\\p{P}]*${titlePattern}[\\s\\u3000]*`;
    try {
      const match = new RegExp(prefix, 'u').exec(body);
      if (match !== null && match[0].length > 0) {
        return body.substring(match[0].length);
      }
    } catch (_) {
      // 书名/标题里有正则不接受的字符时放弃去重，正文原样返回。
    }
    return body;
  }

  /**
   * 把 `<usehtml>…</usehtml>` 换成不会撞上替换规则的字面占位符。
   *
   * 占位符刻意不含标点、字母和汉字，只由私用区字符和序号组成，
   * 用户的净化规则（大多是标点/字母类）几乎不可能命中它。
   */
  private static maskSpecialStyle(text: string, map: Map<string, string>): string {
    if (!text.includes('<usehtml>')) { return text; }
    let counter = 0;
    return text.replace(/<usehtml>[\s\S]*?<\/usehtml>/g, (matched: string) => {
      const placeholder = `\uE000${counter}\uE001`;
      map.set(placeholder, matched);
      counter++;
      return placeholder;
    });
  }

  /** 把占位符换回真正的富文本块；占位符在替换规则里被改坏时保持原样，不丢内容。 */
  private static unmaskSpecialStyle(text: string, map: Map<string, string>): string {
    if (map.size === 0) { return text; }
    let result = text;
    map.forEach((original: string, placeholder: string) => {
      result = result.split(placeholder).join(original);
    });
    return result;
  }

  /**
   * 逐行 trim 后丢弃空行，用 `\n` 重新拼段。
   *
   * 对齐上游 `ContentProcessor.kt:247-259`：`str.trim { it.code <= 0x20 || it == '　' }`，
   * 空行不进入正文。首行不加缩进的事由渲染层按「段首是否为首段」处理。
   */
  private static trimChapterParagraphs(text: string): string {
    const paragraphs: string[] = [];
    const lines = text.split('\n');
    for (let index = 0; index < lines.length; index++) {
      const line = lines[index];
      let start = 0;
      let end = line.length;
      while (start < end && ((line.charCodeAt(start) <= 0x20) || line[start] === '　')) {
        start++;
      }
      while (end > start && ((line.charCodeAt(end - 1) <= 0x20) || line[end - 1] === '　')) {
        end--;
      }
      if (end > start) {
        paragraphs.push(line.substring(start, end));
      }
    }
    return paragraphs.join('\n');
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
    chapters: BookChapter[] = [], forcedRule: string = ''): TocRefreshResult {
    if (book.contentPath === undefined || book.format !== 'txt' || !book.isLocal) {
      return { book: book, chapters: [], content: '', changed: false, oldBodyOffsets: [], newBodyOffsets: [] };
    }
    const content = BookRepository.readTextFile(book.contentPath, book.charset);
    // forcedRule 来自「目录规则预览页」：用户已经挑定一条规则，这里不再自动选。
    // 传空串时退回旧行为（按规则库重新挑一次），也就是目录页「更新目录」的语义。
    const chapterRule = forcedRule.trim().length > 0
      ? forcedRule.trim() : BookRepository.resolveChapterRule(undefined, content);
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
    // 上游 BookShelfItem.isNew = lastCheckCount > 0，无 isLocal 门；本地书刷新目录有新增章节也要亮红点。
    refreshedBook.lastCheckCount = Math.max(chapterTitles.length - oldTitles.length, 0);
    refreshedBook.wordCount = BookRepository.totalWordCount(content);
    refreshedBook.latestChapterTitle = chapterTitles.length > 0 ? chapterTitles[chapterTitles.length - 1] : undefined;
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
    refreshedBook.wordCount = BookRepository.totalWordCount(content);
    refreshedBook.latestChapterTitle = layout.titles.length > 0 ? layout.titles[layout.titles.length - 1] : undefined;
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
    } catch (error) {
      console.error(`[BookRepository] 读取导入正文失败: ${error}`);
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
      isLocal: true,
      wordCount: BookRepository.totalWordCount(content),
      latestChapterTitle: chapterTitles.length > 0 ? chapterTitles[chapterTitles.length - 1] : undefined,
      lastCheckCount: 0
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
    // 没有 BOM：按文件头统计打分选编码，而不是「第一个能解通的编码」。
    const detected = BookRepository.detectTextEncoding(bytes);
    const decoded = BookRepository.tryDecodeWithEncoding(bytes, detected);
    if (decoded !== undefined) { return decoded; }
    // 统计判定出来的编码仍然解不通（样本区恰好含坏字节），退回 UTF-8，
    // 对齐上游 EncodingDetect 失败兜底 "UTF-8" 的行为：书能打开，用户可手动改编码。
    return BookRepository.decodeWithEncoding(bytes, 'utf-8');
  }

  /**
   * 按文件头统计判定编码，对齐上游 `utils/EncodingDetect.kt:55-58` 的
   * `CharsetDetector().setText(bytes).detect()?.name ?: "UTF-8"`：
   * 只看文件头一小段（UTF-8 快路径 + 候选打分），按「像不像正文」取最高分，
   * 而不是「第一个能解通的编码」——GB18030 几乎是任意字节序列的超集，
   * 先试 GB 会让 Big5 的繁体书整本解成生僻字。
   *
   * 打分口径：CJK 汉字、CJK 标点、全角符号、ASCII 可打印字符算正分；
   * 私用区、替换符、控制字符、生僻扩展区算负分。全部候选都解不通时回落 UTF-8，
   * 与上游一样不抛错——书能打开，用户再手动指定编码。
   */
  private static detectTextEncoding(bytes: Uint8Array): string {
    const sampleLength = Math.min(bytes.length, BookRepository.encodingSampleSize);
    // UTF-8 快路径：严格解码能整段通过，且解出来没有替换符，就认定是 UTF-8。
    // 绝大多数 TXT 都是 UTF-8，走这条能省掉 GB18030 / Big5 两次全量解码，
    // 也避免探测阶段往日志里刷满「解码失败」（刷日志本身会拖住主线程）。
    const utf8Sample = BookRepository.tryDecodeSample(bytes, sampleLength, 'utf-8', true);
    if (utf8Sample !== undefined && utf8Sample.indexOf('\uFFFD') < 0 &&
      BookRepository.scoreDecodedText(utf8Sample) > 0) {
      return 'utf-8';
    }
    let bestEncoding = 'utf-8';
    let bestScore = Number.NEGATIVE_INFINITY;
    const candidates: string[] = ['utf-8', 'gb18030', 'big5'];
    for (let index = 0; index < candidates.length; index++) {
      const encoding = candidates[index];
      const decoded = BookRepository.tryDecodeSample(bytes, sampleLength, encoding, true);
      if (decoded === undefined) { continue; }
      const score = BookRepository.scoreDecodedText(decoded);
      // 同分时保留先试的编码（utf-8 优先），与上游按 ICU 置信度取首个最高的口径一致。
      if (score > bestScore) {
        bestScore = score;
        bestEncoding = encoding;
      }
    }
    return bestEncoding;
  }

  /**
   * 解码样本区；样本边界可能把一个多字节字符切开，导致 fatal 解码整段失败，
   * 所以按 0~3 字节回退重试，最多四次。
   */
  private static tryDecodeSample(bytes: Uint8Array, sampleLength: number,
    encoding: string, quiet: boolean = false): string | undefined {
    for (let trim = 0; trim <= 3; trim++) {
      const length = sampleLength - trim;
      if (length <= 0) { return undefined; }
      const decoded = BookRepository.tryDecodeWithEncoding(bytes.subarray(0, length), encoding, quiet);
      if (decoded !== undefined) { return decoded; }
    }
    return undefined;
  }

  /** 给一段解码结果打「像不像中文正文」的分，用于在多个候选编码之间择优。 */
  private static scoreDecodedText(text: string): number {
    if (text.length === 0) { return 0; }
    let positive = 0;
    let negative = 0;
    for (let index = 0; index < text.length; index++) {
      const code = text.charCodeAt(index);
      if (code === 0xFFFD) {
        negative += 4;
      } else if (code < 0x20 && code !== 0x0A && code !== 0x0D && code !== 0x09) {
        negative += 3;
      } else if (code >= 0xE000 && code <= 0xF8FF) {
        negative += 2;
      } else if (code >= 0x3400 && code <= 0x4DBF) {
        negative += 1;
      } else if ((code >= 0x4E00 && code <= 0x9FFF) ||
        (code >= 0x3000 && code <= 0x303F) ||
        (code >= 0xFF00 && code <= 0xFFEF) ||
        (code >= 0x0A && code <= 0x0D)) {
        positive += 2;
      } else if (code >= 0x20 && code <= 0x7E) {
        positive += 1;
      }
    }
    return (positive - negative) / text.length;
  }

private static decodeWithEncoding(bytes: Uint8Array, encoding: string): string {
    const text = BookRepository.tryDecodeWithEncoding(bytes, encoding);
    if (text === undefined) {
      throw new Error(`TXT 文件不是有效的 ${encoding} 文本`);
    }
    return text;
  }

private static tryDecodeWithEncoding(bytes: Uint8Array, encoding: string,
    quiet: boolean = false): string | undefined {
    try {
      const decoder = util.TextDecoder.create(encoding, { fatal: true, ignoreBOM: true });
      return decoder.decodeToString(bytes);
    } catch (error) {
      // 编码探测阶段会故意试错多种候选编码，这些失败是正常的，不能打日志：
      // 打印本身要写 hilog socket，书籍打开时可能一次刷出十几条，主线程会被拖住。
      if (!quiet) {
        console.error(`[BookRepository] 按编码解码失败: ${error}`);
      }
      return undefined;
    }
  }

/** 取路径末段并解码，与上游 FileDoc 的 fileName 语义一致（含扩展名）。 */
  static getFileName(uri: string): string {
    const separator = uri.lastIndexOf('/');
    const rawName = separator >= 0 ? uri.substring(separator + 1) : uri;
    try {
      return decodeURIComponent(rawName);
    } catch (error) {
      console.error(`[BookRepository] 解析文件名失败: ${error}`);
      return rawName;
    }
  }

private static ensureDirectory(path: string): void {
    try {
      fileIo.mkdirSync(path, true);
    } catch (error) {
      try {
        if (fileIo.lstatSync(path).isDirectory()) { return; }
      } catch (error) {
        console.error(`[BookRepository] 创建目录后读取属性失败: ${error}`);
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

  /**
   * 读整本正文，供目录规则预览页按规则扫标题。
   *
   * 预览是一次性动作（用户挑规则时才点开），不做窗口缓存；
   * 读不到或不是本地 TXT 时返回空串，由预览页展示 0 章。
   */
  static readBookContentForPreview(book: Book): string {
    if (book.contentPath === undefined || book.format !== 'txt' || !book.isLocal) {
      return '';
    }
    try {
      return BookRepository.readTextFile(book.contentPath, book.charset);
    } catch (_) {
      return '';
    }
  }

  /**
   * 用一条章节正则扫整本正文，返回命中行样本与命中总数。
   *
   * 供「目录规则预览页」使用：用户挑规则时先看到「这条规则能切出几章、前几百章长什么样」，
   * 不用先保存再回目录页试。口径对齐上游 `TxtTocRulePreviewViewModel.analyzeWithPattern`：
   * 只收前 `previewChapterLimit`（500）条标题，`totalCount` 全量计数。
   *
   * 与上游的差别只有一处：上游边读边扫 512KB 字节块，本地整本已在内存里，直接按行扫。
   */
  static previewTocMatches(content: string, chapterRule: string): TocRulePreviewResult {
    const lines = BookRepository.splitPreviewLines(content);
    const titles: string[] = [];
    let totalCount = 0;
    let index = 0;
    // 同步版给「只算一条」的场景用；预览页几十条规则要整体挪到 worker 里跑，
    // 走 `TocRulePreviewEngine.countAll`，不在主线程扫。
    while (index < lines.length) {
      const chunk = BookRepository.scanTocMatchesPreview(lines, chapterRule, index, titles);
      if (chunk.aborted) {
        return { chapterTitles: [], totalCount: 0 };
      }
      totalCount += chunk.matched;
      index = chunk.nextIndex;
    }
    return { chapterTitles: titles, totalCount: totalCount };
  }

  /** 预览扫描按行切片：一次扫这么多行就让出一帧，避免几十条规则把主线程占满。 */
  static readonly previewScanChunkLines: number = 4000;

  /** 把整本正文按行切开：预览页几十条规则共用一份行数组，不必每条规则都 split 一遍。 */
  static splitPreviewLines(content: string): string[] {
    return content.split('\n');
  }

  /**
   * 从 `fromIndex` 起最多扫 `previewScanChunkLines` 行，命中标题追加进 `chapterTitles`。
   *
   * 预览页有几十条规则、每条都要扫全书，一次性算完会让主线程被 watchdog 判成
   * THREAD_BLOCK_6S，所以调用方按帧推进：每次只扫一片，再 `setTimeout` 接着扫。
   */
  static scanTocMatchesPreview(lines: string[], chapterRule: string, fromIndex: number,
    chapterTitles: string[]): TocRulePreviewChunk {
    const pattern = chapterRule.trim();
    if (pattern.length === 0) {
      return { matched: 0, nextIndex: lines.length, aborted: true };
    }
    let regex: RegExp;
    try {
      regex = TxtTocRuleRepository.compileRegex(pattern, 'm');
    } catch (_) {
      // 正则写坏时不抛，预览页显示 0 章（上游 PatternSyntaxException 同样只给 totalCount = 0）。
      return { matched: 0, nextIndex: lines.length, aborted: true };
    }
    const end = Math.min(lines.length, fromIndex + BookRepository.previewScanChunkLines);
    let matched = 0;
    for (let index = fromIndex; index < end; index++) {
      const line = (lines[index] ?? '').replace(/\r$/, '');
      if (line.trim().length === 0) {
        continue;
      }
      regex.lastIndex = 0;
      if (!regex.test(line)) {
        continue;
      }
      matched += 1;
      if (chapterTitles.length < BookRepository.previewChapterLimit) {
        chapterTitles.push(line.trim());
      }
    }
    return { matched: matched, nextIndex: end, aborted: false };
  }

  /** 选择 TXT 章节规则；无用户规则命中时保留旧版默认识别，避免升级后旧书突然变成整本一章。 */
  private static resolveChapterRule(cachedRule: string | undefined, content: string): string {
    if (cachedRule !== undefined && cachedRule.length > 0) { return cachedRule; }
    const sample = content.length > BookRepository.tocSampleSize
      ? content.substring(0, BookRepository.tocSampleSize) : content;
    const selected = TxtTocRuleRepository.selectForSample(sample).rule;
    // 兜底正则对齐上游内置首位默认规则的章节部分：带 `节(?!课)`、`集(?![合和])`、`正文(?!完|结)`
    // 三处前瞻排除，避免「第1节课」「第3集合」「正文完」被当成章节标题。
    return selected?.chapterRule ?? BookRepository.fallbackChapterRule;
  }

  /**
   * 没有任何规则达到命中门槛时的兜底切章正则。
   * 形制取自内置规则「目录」（serialNumber 1）：允许行首 0~4 个空格或全角空格，
   * 标题以 `.{0,30}$` 收尾，逐行匹配时等价于「整行就是标题」。
   */
  private static readonly fallbackChapterRule: string =
    '^[ 　\\t]{0,4}(?:序章|楔子|正文(?!完|结)|终章|后记|尾声|番外|' +
      '第\\s{0,4}[\\d〇零一二两三四五六七八九十百千万壹贰叁肆伍陆柒捌玖拾佰仟]+?\\s{0,4}' +
      '(?:章|节(?!课)|卷|集(?![合和]))).{0,30}$';

  /** 标题、起点与卷标记来自同一次匹配，确保阅读偏移和目录显示对齐。 */
  private static splitChapters(content: string, chapterRule: string): ChapterSplit {
    const resolvedRule = chapterRule.trim().length > 0
      ? chapterRule : BookRepository.resolveChapterRule(undefined, content);
    const starts = TxtTocRuleRepository.splitChapterStarts(content, resolvedRule);
    const volumeRule = TxtTocRuleRepository.resolveVolumeRule(resolvedRule);
    const titles: string[] = [];
    const offsets: number[] = [];
    const volumes: boolean[] = [];
    // 第一个标题之前的正文单独成「前言」章，对齐上游 TextFile.kt:237-252：
    // 书名页、内容简介、作者的话都写在第 1 章之前，不单独成章就永远读不到。
    let intro: string | undefined = undefined;
    if (starts.length > 0 && starts[0] > 0) {
      const head = content.substring(0, starts[0]);
      if (head.trim().length > 0) {
        titles.push('前言');
        offsets.push(0);
        volumes.push(false);
        intro = head.length <= 500 ? head : head.substring(0, 500);
      }
    }
    for (let index = 0; index < starts.length; index++) {
      const start = starts[index];
      const end = index + 1 < starts.length ? starts[index + 1] : content.length;
      const lineEnd = content.indexOf('\n', start);
      const rawLine = lineEnd >= 0 ? content.substring(start, lineEnd) : content.substring(start);
      const title = rawLine.replace(/\r$/, '').trim().substring(0, 80);
      BookRepository.appendChapterRange(content, start, end, title, resolvedRule,
        titles, offsets, volumes);
    }
    // 卷标记按最终标题重新判定：长章拆出的子章标题带 `(1)` 后缀，仍应沿用原章的卷归属。
    const flags = TxtTocRuleRepository.markVolumeTitles(titles, volumeRule);
    return { titles: titles, offsets: offsets, volumes: flags, intro: intro };
  }

  /**
   * 追加一章；单章超过 maxLengthWithToc 时按上游 TextFile.kt:66、`:208-226` 二次拆分。
   *
   * 拆出的子章标题是 `原章名(1)`、`原章名(2)`：上游把整段（含标题行）交给子章，
   * 并把原章从目录里去掉，避免留下读不出正文的零长度空壳章。
   */
  private static appendChapterRange(content: string, start: number, end: number, title: string,
    chapterRule: string, titles: string[], offsets: number[], volumes: boolean[]): void {
    const safeTitle = title.length > 0 ? title : '无标题章节';
    const byteLength = BookRepository.sliceByteLength(content, start, end, undefined);
    if (byteLength <= BookRepository.maxLengthWithToc || end <= start) {
      titles.push(safeTitle);
      offsets.push(start);
      volumes.push(false);
      return;
    }
    const slice = content.substring(start, end);
    const subStarts = TxtTocRuleRepository.splitChapterStarts(slice, chapterRule);
    if (subStarts.length === 0) {
      // 段内再没有标题：按无目录分章的长度阈值切开，标题仍用原章名加序号。
      const layout = BookRepository.buildNoTocChapterLayout(slice, 3000, undefined);
      for (let index = 0; index < layout.offsets.length; index++) {
        titles.push(`${safeTitle}(${index + 1})`);
        offsets.push(start + (layout.offsets[index] ?? 0));
        volumes.push(false);
      }
      return;
    }
    for (let index = 0; index < subStarts.length; index++) {
      titles.push(`${safeTitle}(${index + 1})`);
      offsets.push(start + (subStarts[index] ?? 0));
      volumes.push(false);
    }
  }

  /** 字符区间按指定编码折算成字节数；用于判断单章是否超过 maxLengthWithToc。 */
  private static sliceByteLength(content: string, start: number, end: number,
    encoding: string | undefined): number {
    const normalized = BookRepository.normalizeEncoding(encoding);
    const safeEnd = Math.min(content.length, Math.max(start, end));
    let bytes = 0;
    let index = start;
    while (index < safeEnd) {
      const width = BookRepository.charByteWidth(content, index, normalized);
      bytes += width;
      index += width === 4 ? 2 : 1;
    }
    return bytes;
  }

}

