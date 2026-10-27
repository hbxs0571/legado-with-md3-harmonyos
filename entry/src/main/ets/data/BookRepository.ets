import { fileIo, picker } from '@kit.CoreFileKit';
import { preferences } from '@kit.ArkData';
import { util } from '@kit.ArkTS';
import { Book, BookMediaType } from '../model/Book';
import { EpubRepository } from './EpubRepository';
import { LocalTextSemantics } from './LocalTextSemantics';
import { LocalTextReSegmenter } from './LocalTextReSegmenter';
import { ReplaceRuleRepository } from './ReplaceRuleRepository';
import { TxtTocRuleRepository } from './TxtTocRuleRepository';
import { BookContentProcessRepository } from './BookContentProcessRepository';
import { BookContentProcessEngine } from './BookContentProcessEngine';

interface ChapterTextRange {
  start: number;
  end: number;
}

interface NoTocChapterLayout {
  titles: string[];
  offsets: number[];
}

/** 按目录规则切出的章节标题与行首偏移，两者长度必然一致。 */
interface ChapterSplit {
  titles: string[];
  offsets: number[];
  /** 每一章是否为分卷标题，与 titles 等长；对应上游 BookChapter.isVolume。 */
  volumes: boolean[];
}

export interface NoTocBookRefreshResult {
  book: Book;
  content: string;
  changed: boolean;
  oldBodyOffsets: number[];
  newBodyOffsets: number[];
}

/** 重新识别目录的结果；oldBodyOffsets/newBodyOffsets 供调用方重映射书签。 */
export interface TocRefreshResult {
  book: Book;
  content: string;
  changed: boolean;
  oldBodyOffsets: number[];
  newBodyOffsets: number[];
}

export class BookRepository {
  private static readonly preferenceName: string = 'legado_local_books';
  /**
   * 识别目录规则时读取的正文样本长度。
   * 与上游 TextFile 只读首个 buffer（64 KB）做识别保持一致：样本太长没有收益，
   * 反而让每次打开书都多扫一遍全文。
   */
  private static readonly tocSampleSize: number = 65536;
  private static effectiveRuleIdsByChapter: Map<string, number[]> = new Map<string, number[]>();
  private static effectiveRuleCacheOrder: string[] = [];
  private static saveQueue: Promise<void> = Promise.resolve();

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
  static async importLocalBook(context: Context, maxLengthWithNoToc: number = 3000): Promise<Book | undefined> {
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
      return await EpubRepository.importFromUri(context, uri, fileName, bookId);
    }

    return await BookRepository.importTxtFromUri(context, uri, fileName, bookId, maxLengthWithNoToc);
  }

  static async importTxtFromUri(context: Context, uri: string, fileName: string, bookId: string, maxLengthWithNoToc: number = 3000): Promise<Book> {
    const title = BookRepository.getTitle(fileName);
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

  private static parseBookType(value: string): BookMediaType {
    if (value === 'audio' || value === 'image') { return value; }
    return 'text';
  }

  /** 把分卷标记序列化成 0/1 串；全为 false 时返回空串，避免无分卷书籍多存冗余字节。 */
  private static encodeVolumeFlags(volumes: boolean[] | undefined, count: number): string {
    if (volumes === undefined || volumes.length !== count || count === 0) {
      return '';
    }
    let hasVolume = false;
    for (let index = 0; index < volumes.length; index++) {
      if (volumes[index] === true) { hasVolume = true; break; }
    }
    if (!hasVolume) {
      return '';
    }
    let encoded = '';
    for (let index = 0; index < volumes.length; index++) {
      encoded += volumes[index] === true ? '1' : '0';
    }
    return encoded;
  }

  /**
   * 还原分卷标记。长度与章节数对不上时整体丢弃，
   * 宁可当这本书没有分卷，也不能让目录页按错位的标记缩进。
   */
  private static decodeVolumeFlags(value: string | undefined, count: number): boolean[] | undefined {
    const text = value ?? '';
    if (text.length === 0 || text.length !== count || count === 0) {
      return undefined;
    }
    const volumes: boolean[] = [];
    for (let index = 0; index < text.length; index++) {
      const flag = text.charAt(index);
      if (flag !== '0' && flag !== '1') {
        return undefined;
      }
      volumes.push(flag === '1');
    }
    return volumes;
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
    return {
      id: book.id,
      title: book.title,
      author: book.author,
      category: book.category,
      groupName: book.groupName,
      chapterTitles: book.chapterTitles,
      chapterOffsets: book.chapterOffsets,
      chapterVolumes: book.chapterVolumes,
      chapterIndex: book.chapterIndex,
      chapterProgress: book.chapterProgress,
      lastChapter: book.lastChapter,
      progress: book.progress,
      coverColor: book.coverColor,
      coverMark: book.coverMark,
      coverUri: coverUri,
      customCoverUri: customCoverUri,
      bookType: book.bookType,
      fixedType: book.fixedType,
      contentPath: book.contentPath,
      format: book.format,
      chapterCount: book.chapterCount,
      fileSizeBytes: book.fileSizeBytes,
      imageStyle: book.imageStyle,
      reSegment: book.reSegment,
      charset: book.charset,
      description: book.description,
      remark: book.remark,
      customTag: book.customTag,
      bodyMissing: book.bodyMissing,
      androidOriginalPath: book.androidOriginalPath,
      androidCharacterPosition: book.androidCharacterPosition,
      readerPositionVersion: book.readerPositionVersion,
      tocRule: book.tocRule,
      isLocal: book.isLocal
    };
  }

  static isPersistableBook(book: Book): boolean {
    return book.contentPath !== undefined || book.bodyMissing === true;
  }

  static async loadImportedBooks(context: Context): Promise<Book[]> {
    try {
      const store = await preferences.getPreferences(context, BookRepository.preferenceName);
      const value = await store.get('books', '');
      if (typeof value !== 'string' || (!value.startsWith('v1\n') && !value.startsWith('v2\n') && !value.startsWith('v3\n') && !value.startsWith('v4\n') && !value.startsWith('v5\n') && !value.startsWith('v6\n') && !value.startsWith('v7\n') && !value.startsWith('v8\n') && !value.startsWith('v9\n') && !value.startsWith('v10\n') && !value.startsWith('v11\n') && !value.startsWith('v12\n') && !value.startsWith('v13\n') && !value.startsWith('v14\n'))) {
        return [];
      }
      const isVersion14 = value.startsWith('v14\n');
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
        const maximumFields = isVersion14 ? 29 : isVersion13 ? 28 : isVersion12 ? 27 : isVersion11 ? 25 : isVersion10 ? 24 : isVersion9 ? 22 : isVersion8 ? 21 : isVersion7 ? 20 : isVersion6 ? 19 : isVersion5 ? 18 : isVersion4 ? 9 : isVersion3 ? 8 : isVersion2 ? 4 : 3;
        if (fields.length < 2 || fields.length > maximumFields) {
          continue;
        }
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
          books.push({
            id: id,
            title: title,
            author: decodeURIComponent(fields[5] ?? '未知作者'),
            category: savedCategory,
            groupName: savedGroupName,
            chapterIndex: Number.isInteger(savedIndex) && savedIndex >= 0 ? savedIndex : 0,
            chapterProgress: chapterProgress,
            lastChapter: savedLastChapter,
            progress: Number.isFinite(savedProgress) ? Math.max(0, Math.min(100, savedProgress)) : 0,
            coverColor: '#39424B',
            coverMark: title.substring(0, 1) || '书',
            coverUri: BookRepository.resolveCoverUri(context, id, isVersion11 ? decodeURIComponent(fields[24] ?? '') : ''),
            customCoverUri: isVersion11 ? decodeURIComponent(fields[24] ?? '') || undefined : undefined,
            bookType: isVersion12 ? BookRepository.parseBookType(decodeURIComponent(fields[25] ?? 'text')) : 'text',
            fixedType: isVersion12 && fields[26] === '1',
            chapterCount: savedChapterCount,
            description: decodeURIComponent(fields[12] ?? ''),
            remark: isVersion10 ? decodeURIComponent(fields[22] ?? '') : undefined,
            customTag: isVersion10 ? decodeURIComponent(fields[23] ?? '') : undefined,
            bodyMissing: true,
            androidOriginalPath: originalPath,
            androidCharacterPosition: Number.isInteger(savedPosition) && savedPosition >= 0 ? savedPosition : 0,
            readerPositionVersion: isVersion9 ? BookRepository.readPositionVersion(fields[21]) : 2,
            tocRule: isVersion13 ? (decodeURIComponent(fields[27] ?? '') || undefined) : undefined,
            // 缺正文的书书目来自备份，分卷标记随字段一起保留；没有章节标题时对齐不上，直接忽略。
            chapterVolumes: isVersion14 ? BookRepository.decodeVolumeFlags(fields[28], savedChapterCount.length > 0 ? Number(savedChapterCount) : 0) : undefined,
            format: fields[4] === 'epub' ? 'epub' : 'txt',
            imageStyle: isVersion6 ? decodeURIComponent(fields[18] ?? 'DEFAULT') : undefined,
            charset: isVersion7 ? decodeURIComponent(fields[19] ?? '') || undefined : undefined,
            reSegment: isVersion8 && fields[20] === '1',
            isLocal: true
          });
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
              chapterTitles: chapterTitles,
              chapterOffsets: chapterOffsets,
              chapterIndex: safeIndex,
              chapterProgress: safeProgress,
              lastChapter: chapterTitles[safeIndex] ?? (savedLastChapter.length > 0 ? savedLastChapter : '全文'),
              progress: isVersion5 && Number.isFinite(savedWholeProgress)
                ? Math.max(0, Math.min(100, savedWholeProgress))
                : chapterTitles.length > 0 ? (safeIndex + safeProgress / 100) / chapterTitles.length * 100 : 0,
              coverColor: '#39424B',
              coverMark: title.substring(0, 1) || '书',
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
              readerPositionVersion: isVersion9 ? BookRepository.readPositionVersion(fields[21]) : 0,
              fileSizeBytes: savedSize > 0 ? savedSize : undefined,
              tocRule: isVersion13 ? (decodeURIComponent(fields[27] ?? '') || undefined) : undefined,
              chapterVolumes: isVersion14 ? BookRepository.decodeVolumeFlags(fields[28], chapterTitles.length) : undefined,
              isLocal: true
            });
          } else {
            const savedCharset = isVersion7 ? decodeURIComponent(fields[19] ?? '') : '';
            const savedTitles = (fields[6] ?? '').split(';')
              .filter((item: string) => item.length > 0)
              .map((item: string) => decodeURIComponent(item));
            const savedOffsets = (fields[7] ?? '').split(',')
              .map((item: string) => Number(item))
              .filter((item: number) => Number.isInteger(item) && item >= 0);
            const localBook = BookRepository.createLocalBook(id, title, path, chapterIndex, chapterProgress,
              undefined, savedCharset.length > 0 ? savedCharset : undefined);
            localBook.customCoverUri = isVersion11 ? decodeURIComponent(fields[24] ?? '') || undefined : undefined;
            localBook.bookType = isVersion12 ? BookRepository.parseBookType(decodeURIComponent(fields[25] ?? 'text')) : 'text';
            localBook.fixedType = isVersion12 && fields[26] === '1';
            localBook.coverUri = BookRepository.resolveCoverUri(context, id, localBook.customCoverUri ?? '');
            localBook.readerPositionVersion = isVersion9 ? BookRepository.readPositionVersion(fields[21]) : 0;
            if (isVersion13) {
              const savedTocRule = decodeURIComponent(fields[27] ?? '');
              if (savedTocRule.length > 0) { localBook.tocRule = savedTocRule; }
            }
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
              localBook.chapterTitles = savedTitles;
              localBook.chapterOffsets = savedOffsets;
              // 分卷标记必须先还原 chapterTitles 再对齐，长度对不上时 decodeVolumeFlags 会返回 undefined。
              localBook.chapterVolumes = isVersion14
                ? BookRepository.decodeVolumeFlags(fields[28], savedTitles.length) : undefined;
              localBook.chapterIndex = safeIndex;
              localBook.lastChapter = savedTitles[safeIndex] ?? localBook.lastChapter;
              localBook.chapterCount = savedTitles.length.toString();
            }
            const savedSize = Number(fields[8] ?? '0');
            if (savedSize > 0) { localBook.fileSizeBytes = savedSize; }
            if (isVersion6) { localBook.imageStyle = decodeURIComponent(fields[18] ?? 'DEFAULT'); }
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
        const store = await preferences.getPreferences(context, BookRepository.preferenceName);
        const records: string[] = ['v14'];
        for (let index = 0; index < books.length; index++) {
          const book = books[index];
          if (!BookRepository.isPersistableBook(book)) { continue; }
          const chapterTitles = (book.chapterTitles ?? [])
            .map((chapterTitle: string) => encodeURIComponent(chapterTitle)).join(';');
          const chapterOffsets = (book.chapterOffsets ?? []).join(',');
          records.push([
            encodeURIComponent(book.id), encodeURIComponent(book.title), (book.chapterIndex ?? 0).toString(),
            (book.chapterProgress ?? 0).toString(), book.format ?? 'txt', encodeURIComponent(book.author),
            chapterTitles, chapterOffsets, (book.fileSizeBytes ?? 0).toString(), book.bodyMissing === true ? '1' : '0',
            encodeURIComponent(book.androidOriginalPath ?? ''), (book.androidCharacterPosition ?? 0).toString(),
            encodeURIComponent(book.description ?? ''), encodeURIComponent(book.chapterCount ?? '0'),
            encodeURIComponent(book.category), encodeURIComponent(book.groupName ?? ''),
            encodeURIComponent(book.lastChapter), (book.progress ?? 0).toString(),
            encodeURIComponent(book.imageStyle ?? 'DEFAULT'), encodeURIComponent(book.charset ?? ''),
            book.reSegment === true ? '1' : '0',
            (book.readerPositionVersion === 2 ? '2' : book.readerPositionVersion === 0 ? '0' : '1'),
            encodeURIComponent(book.remark ?? ''), encodeURIComponent(book.customTag ?? ''),
            encodeURIComponent(book.customCoverUri ?? ''), encodeURIComponent(book.bookType ?? 'text'),
            book.fixedType === true ? '1' : '0',
            encodeURIComponent(book.tocRule ?? ''),
            // 分卷标记按位存成 0/1 串，与 chapterTitles 一一对应。
            // 全为 false 时存空串，省掉绝大多数无分卷书籍的冗余字节。
            BookRepository.encodeVolumeFlags(book.chapterVolumes, (book.chapterTitles ?? []).length)
          ].join('|'));
        }
        await store.put('books', records.join('\n'));
        await store.flush();
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
   * 清掉缓存的目录规则后重新识别目录，对应上游书架的「更新目录」。
   *
   * 上游是 `TextFile.getChapterList()` 里 `book.tocUrl.isBlank()` 时重新跑
   * `getTocRule(blockContent)`，再由 `TocViewModel.updateToc()` 写回章节列表。
   * 本地导入时选中的规则会固定在 `book.tocRule` 上（规则调整不该打乱已有书的目录），
   * 所以这个入口是用户唯一能让已导入的书用上新规则的方式。
   *
   * 阅读位置按章内字符偏移跨章节迁移，与 `refreshNoTocBook()` 的换算方式一致；
   * 目录没变化时直接返回 changed=false，不写库。
   */
  static refreshToc(book: Book, maxLengthWithNoToc: number = 3000): TocRefreshResult {
    if (book.contentPath === undefined || book.format !== 'txt' || !book.isLocal) {
      return { book: book, content: '', changed: false, oldBodyOffsets: [], newBodyOffsets: [] };
    }
    const content = BookRepository.readTextFile(book.contentPath, book.charset);
    // 传 undefined 让 resolveChapterRule 走一次规则库匹配，而不是沿用缓存。
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
    const currentTitles = book.chapterTitles ?? [];
    const currentVolumes = book.chapterVolumes ?? [];
    const nextRule = chapterRule.length > 0 ? chapterRule : undefined;
    let changed = nextRule !== book.tocRule || currentTitles.length !== chapterTitles.length;
    for (let index = 0; !changed && index < chapterTitles.length; index++) {
      if (currentTitles[index] !== chapterTitles[index] ||
        (book.chapterOffsets?.[index] ?? -1) !== (chapterOffsets[index] ?? -2) ||
        (currentVolumes[index] === true) !== (chapterVolumes[index] === true)) {
        changed = true;
      }
    }
    if (!changed) {
      return { book: book, content: content, changed: false, oldBodyOffsets: [], newBodyOffsets: [] };
    }
    const oldOffsets = book.chapterOffsets ?? [0];
    const oldBodyOffsets = BookRepository.getNoTocBodyOffsets(content, oldOffsets, currentTitles.length);
    const newBodyOffsets = BookRepository.getNoTocBodyOffsets(content, chapterOffsets, chapterTitles.length);
    const oldIndex = Math.max(0, Math.min(currentTitles.length - 1, book.chapterIndex ?? 0));
    const oldStart = oldBodyOffsets[oldIndex] ?? 0;
    const oldEnd = oldOffsets[oldIndex + 1] ?? content.length;
    const oldBodyLength = Math.max(0, oldEnd - oldStart);
    const savedPosition = Math.max(0, Math.trunc(book.androidCharacterPosition ?? 0));
    const localPosition = book.readerPositionVersion === 2 || book.readerPositionVersion === 1
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
    const refreshedBook: Book = {
      id: book.id,
      title: book.title,
      author: book.author,
      category: book.category,
      groupName: book.groupName,
      chapterTitles: chapterTitles,
      chapterOffsets: chapterOffsets,
      chapterVolumes: chapterVolumes,
      chapterIndex: chapterIndex,
      chapterProgress: chapterProgress,
      lastChapter: chapterTitles[chapterIndex] ?? book.lastChapter,
      progress: (chapterIndex + chapterProgress / 100) / chapterCount * 100,
      coverColor: book.coverColor,
      coverMark: book.coverMark,
      coverUri: book.coverUri,
      customCoverUri: book.customCoverUri,
      bookType: book.bookType,
      fixedType: book.fixedType,
      contentPath: book.contentPath,
      format: book.format,
      chapterCount: chapterTitles.length.toString(),
      fileSizeBytes: book.fileSizeBytes,
      imageStyle: book.imageStyle,
      reSegment: book.reSegment,
      charset: book.charset,
      description: book.description,
      remark: book.remark,
      customTag: book.customTag,
      bodyMissing: book.bodyMissing,
      androidOriginalPath: book.androidOriginalPath,
      androidCharacterPosition: chapterPosition,
      readerPositionVersion: 2,
      tocRule: nextRule,
      isLocal: book.isLocal
    };
    return {
      book: refreshedBook,
      content: content,
      changed: true,
      oldBodyOffsets: oldBodyOffsets,
      newBodyOffsets: newBodyOffsets
    };
  }

  static withCharset(book: Book, charset: string, maxLengthWithNoToc: number = 3000): Book {
    const normalizedCharset = charset.trim();
    if (book.contentPath === undefined || book.format !== 'txt') {
      return {
        id: book.id,
        title: book.title,
        author: book.author,
        category: book.category,
        groupName: book.groupName,
        chapterTitles: book.chapterTitles,
        chapterOffsets: book.chapterOffsets,
        chapterVolumes: book.chapterVolumes,
        chapterIndex: book.chapterIndex,
        chapterProgress: book.chapterProgress,
        lastChapter: book.lastChapter,
        progress: book.progress,
        coverColor: book.coverColor,
        coverMark: book.coverMark,
        coverUri: book.coverUri,
        customCoverUri: book.customCoverUri,
        bookType: book.bookType,
        fixedType: book.fixedType,
        contentPath: book.contentPath,
        format: book.format,
        chapterCount: book.chapterCount,
        fileSizeBytes: book.fileSizeBytes,
        imageStyle: book.imageStyle,
        reSegment: book.reSegment,
        charset: normalizedCharset.length > 0 ? normalizedCharset : undefined,
        description: book.description,
        remark: book.remark,
        customTag: book.customTag,
        bodyMissing: book.bodyMissing,
        androidOriginalPath: book.androidOriginalPath,
        androidCharacterPosition: book.androidCharacterPosition,
        readerPositionVersion: book.readerPositionVersion,
        tocRule: book.tocRule,
        isLocal: book.isLocal
      };
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
      // 没有任何规则命中，或规则一条都没切出来，退回按字数分章，正文照样能读。
      const layout = BookRepository.buildNoTocChapterLayout(content, maxLengthWithNoToc, normalizedCharset.length > 0 ? normalizedCharset : undefined);
      chapterTitles = layout.titles;
      chapterOffsets = layout.offsets;
      chapterVolumes = [];
    }
    const chapterIndex = Math.max(0, Math.min(Math.max(0, chapterTitles.length - 1), book.chapterIndex ?? 0));
    const chapterProgress = Math.max(0, Math.min(100, book.chapterProgress ?? 0));
    const chapterCount = Math.max(1, chapterTitles.length);
    return {
      id: book.id,
      title: book.title,
      author: book.author,
      category: book.category,
      groupName: book.groupName,
      chapterTitles: chapterTitles,
      chapterOffsets: chapterOffsets,
      chapterVolumes: chapterVolumes,
      chapterIndex: chapterIndex,
      chapterProgress: chapterProgress,
      lastChapter: chapterTitles[chapterIndex] ?? book.lastChapter,
      progress: chapterTitles.length > 0
        ? (chapterIndex + chapterProgress / 100) / chapterCount * 100 : book.progress,
      coverColor: book.coverColor,
      coverMark: book.coverMark,
      coverUri: book.coverUri,
      customCoverUri: book.customCoverUri,
      bookType: book.bookType,
      fixedType: book.fixedType,
      contentPath: book.contentPath,
      format: book.format,
      chapterCount: chapterTitles.length.toString(),
      fileSizeBytes: book.fileSizeBytes,
      imageStyle: book.imageStyle,
      reSegment: book.reSegment,
      charset: normalizedCharset.length > 0 ? normalizedCharset : undefined,
      description: book.description,
      remark: book.remark,
      customTag: book.customTag,
      bodyMissing: book.bodyMissing,
      androidOriginalPath: book.androidOriginalPath,
      androidCharacterPosition: 0,
      readerPositionVersion: 1,
      tocRule: chapterRule.length > 0 ? chapterRule : undefined,
      isLocal: book.isLocal
    };
  }

  static withReSegment(book: Book, enabled: boolean): Book {
    return {
      id: book.id,
      title: book.title,
      author: book.author,
      category: book.category,
      groupName: book.groupName,
      chapterTitles: book.chapterTitles,
      chapterOffsets: book.chapterOffsets,
      chapterVolumes: book.chapterVolumes,
      chapterIndex: book.chapterIndex,
      chapterProgress: book.chapterProgress,
      lastChapter: book.lastChapter,
      progress: book.progress,
      coverColor: book.coverColor,
      coverMark: book.coverMark,
      coverUri: book.coverUri,
      customCoverUri: book.customCoverUri,
      bookType: book.bookType,
      fixedType: book.fixedType,
      contentPath: book.contentPath,
      format: book.format,
      chapterCount: book.chapterCount,
      fileSizeBytes: book.fileSizeBytes,
      imageStyle: book.imageStyle,
      reSegment: enabled,
      charset: book.charset,
      description: book.description,
      remark: book.remark,
      customTag: book.customTag,
      bodyMissing: book.bodyMissing,
      androidOriginalPath: book.androidOriginalPath,
      androidCharacterPosition: book.androidCharacterPosition,
      readerPositionVersion: book.readerPositionVersion,
      tocRule: book.tocRule,
      isLocal: book.isLocal
    };
  }

  static async readChapter(book: Book, chapterTitle: string, requestedChapterIndex?: number, contentOverride?: string): Promise<string> {
    if (book.contentPath === undefined) {
      throw new Error('本地书籍路径无效');
    }
    const content = contentOverride ?? BookRepository.readTextFile(book.contentPath, book.format === 'txt' ? book.charset : undefined);
    if (book.chapterOffsets !== undefined && book.chapterOffsets.length > 0) {
      const storedIndex = book.chapterIndex;
      const titleIndex = book.chapterTitles?.indexOf(chapterTitle) ?? -1;
      const selectedIndex = requestedChapterIndex ?? (storedIndex !== undefined &&
        book.chapterTitles?.[storedIndex] === chapterTitle ? storedIndex : titleIndex >= 0 ? titleIndex : storedIndex ?? 0);
      const chapterIndex = Math.max(0, Math.min(book.chapterOffsets.length - 1, selectedIndex));
      const start = book.chapterOffsets[chapterIndex] ?? 0;
      const nextStart = book.chapterOffsets[chapterIndex + 1] ?? content.length;
      const section = content.substring(start, nextStart);
      const title = book.chapterTitles?.[chapterIndex] ?? chapterTitle;
      const bodyStart = BookRepository.chapterBodyStart(section, title);
      const body = section.substring(bodyStart).trim();
      const displayBody = book.format === 'epub' ? EpubRepository.removeDuplicateHeading(body, title) : body;
      return await BookRepository.applyChapterContentAsync(book, title, displayBody, chapterIndex);
    }
    if (book.chapterTitles === undefined || book.chapterTitles.length === 0) {
      return await BookRepository.applyChapterContentAsync(book, chapterTitle, content.substring(0, 50000), book.chapterIndex ?? 0);
    }
    const chapterStarts = BookRepository.splitChapters(content, book.tocRule ?? '').offsets;
    const storedIndex = book.chapterIndex;
    const titleIndex = book.chapterTitles.indexOf(chapterTitle);
    const requestedIndex = requestedChapterIndex ?? (storedIndex !== undefined &&
      book.chapterTitles[storedIndex] === chapterTitle ? storedIndex : titleIndex >= 0 ? titleIndex : storedIndex ?? 0);
    const chapterIndex = Math.max(0, Math.min(book.chapterTitles.length - 1, requestedIndex));
    if (chapterStarts.length !== book.chapterTitles.length) {
      const chapterStart = content.indexOf(chapterTitle);
      if (chapterStart < 0) {
        return await BookRepository.applyChapterContentAsync(book, chapterTitle, content.substring(0, 50000), chapterIndex);
      }
      const titleLineEnd = content.indexOf('\n', chapterStart);
      const displayStart = titleLineEnd >= 0 && content.substring(chapterStart, titleLineEnd).trim() === chapterTitle.trim()
        ? titleLineEnd + 1 : chapterStart;
      const nextTitle = book.chapterTitles[chapterIndex + 1];
      const nextStart = nextTitle === undefined ? -1 : content.indexOf(nextTitle, chapterStart + chapterTitle.length);
      const displayEnd = nextStart >= 0 ? Math.min(nextStart, displayStart + 50000) : displayStart + 50000;
      const body = content.substring(displayStart, displayEnd);
      return await BookRepository.applyChapterContentAsync(book, chapterTitle, body, chapterIndex);
    }
    const chapterStart = chapterStarts[chapterIndex] ?? 0;
    const lineEnd = content.indexOf('\n', chapterStart);
    const displayStart = lineEnd >= 0 ? lineEnd + 1 : chapterStart;
    const nextStart = chapterStarts[chapterIndex + 1] ?? content.length;
    const body = content.substring(displayStart, Math.min(nextStart, displayStart + 50000));
    return await BookRepository.applyChapterContentAsync(book, chapterTitle, body, chapterIndex);
  }

  static async readAllChapters(book: Book, useReplaceRules: boolean = true): Promise<string[]> {
    const chapters: string[] = [];
    await BookRepository.forEachChapter(book, (chapterContent: string, _chapterIndex: number): Promise<boolean> => {
      chapters.push(chapterContent);
      return Promise.resolve(true);
    }, useReplaceRules);
    return chapters;
  }

  /** 逐章处理本地正文，交付一章后让出事件循环，避免整本书占住界面线程。 */
  static async forEachChapter(
    book: Book,
    onChapter: (chapterContent: string, chapterIndex: number) => Promise<boolean>,
    useReplaceRules: boolean = true
  ): Promise<void> {
    if (book.contentPath === undefined) {
      throw new Error('本地书籍路径无效');
    }
    const content = await BookRepository.readTextFileAsync(
      book.contentPath, book.format === 'txt' ? book.charset : undefined
    );
    const titles = book.chapterTitles ?? [];
    if (titles.length === 0) {
      const chapter = await BookRepository.applyChapterContentAsync(
        book, book.lastChapter, content.substring(0, 50000), book.chapterIndex ?? 0, useReplaceRules
      );
      await onChapter(chapter, book.chapterIndex ?? 0);
      return;
    }
    const yieldAfterChapter = async (): Promise<void> => {
      await new Promise<void>((resolve: () => void) => setTimeout(resolve, 0));
    };
    if (book.chapterOffsets !== undefined && book.chapterOffsets.length > 0) {
      for (let index = 0; index < titles.length; index++) {
        const start = book.chapterOffsets[index] ?? 0;
        const nextStart = book.chapterOffsets[index + 1] ?? content.length;
        const section = content.substring(start, nextStart);
        const chapterTitle = titles[index] ?? '';
        const bodyStart = BookRepository.chapterBodyStart(section, chapterTitle);
        const body = section.substring(bodyStart).trim();
        const displayBody = book.format === 'epub' ? EpubRepository.removeDuplicateHeading(body, chapterTitle) : body;
        const chapter = await BookRepository.applyChapterContentAsync(book, chapterTitle, displayBody, index, useReplaceRules);
        if (!(await onChapter(chapter, index))) { return; }
        await yieldAfterChapter();
      }
      return;
    }
    const starts = BookRepository.splitChapters(content, book.tocRule ?? '').offsets;
    if (starts.length === titles.length) {
      for (let index = 0; index < titles.length; index++) {
        const chapterStart = starts[index] ?? 0;
        const lineEnd = content.indexOf('\n', chapterStart);
        const displayStart = lineEnd >= 0 ? lineEnd + 1 : chapterStart;
        const nextStart = starts[index + 1] ?? content.length;
        const title = titles[index] ?? '';
        const body = content.substring(displayStart, Math.min(nextStart, displayStart + 50000));
        const chapter = await BookRepository.applyChapterContentAsync(book, title, body, index, useReplaceRules);
        if (!(await onChapter(chapter, index))) { return; }
        await yieldAfterChapter();
      }
      return;
    }
    for (let index = 0; index < titles.length; index++) {
      const title = titles[index] ?? '';
      const chapterStart = content.indexOf(title);
      if (chapterStart < 0) {
        if (!(await onChapter('', index))) { return; }
        await yieldAfterChapter();
        continue;
      }
      const titleLineEnd = content.indexOf('\n', chapterStart);
      const displayStart = titleLineEnd >= 0 && content.substring(chapterStart, titleLineEnd).trim() === title.trim()
        ? titleLineEnd + 1 : chapterStart;
      const nextTitle = titles[index + 1];
      const nextStart = nextTitle === undefined ? -1 : content.indexOf(nextTitle, chapterStart + title.length);
      const displayEnd = nextStart >= 0 ? Math.min(nextStart, displayStart + 50000) : displayStart + 50000;
      const body = content.substring(displayStart, displayEnd);
      const chapter = await BookRepository.applyChapterContentAsync(book, title, body, index, useReplaceRules);
      if (!(await onChapter(chapter, index))) { return; }
      await yieldAfterChapter();
    }
  }

  /** 将章节编辑保存到应用导入副本，并同步更新章节索引；不会写回用户选择的原文件。 */
  static replaceLocalChapter(book: Book, chapterIndex: number, chapterTitle: string, chapterBody: string): Book {
    if (book.contentPath === undefined || book.chapterTitles === undefined || book.chapterTitles.length === 0) {
      throw new Error('当前书籍没有可编辑的本地章节');
    }
    const safeIndex = Math.max(0, Math.min(book.chapterTitles.length - 1, Math.trunc(chapterIndex)));
    const content = BookRepository.readTextFile(book.contentPath, book.format === 'txt' ? book.charset : undefined);
    let updatedContent: string = '';
    let chapterTitles: string[] = [];
    for (let index = 0; index < book.chapterTitles.length; index++) {
      chapterTitles.push(book.chapterTitles[index] ?? '');
    }
    let chapterOffsets: number[] | undefined = undefined;
    const title = chapterTitle.trim() || book.chapterTitles[safeIndex] || '';
    const body = chapterBody;
    chapterTitles[safeIndex] = title;

    if (book.chapterOffsets !== undefined && book.chapterOffsets.length > 0) {
      const sections: string[] = [];
      chapterOffsets = [];
      let offset = 0;
      for (let index = 0; index < book.chapterTitles.length; index++) {
        chapterOffsets.push(offset);
        const section = index === safeIndex
          ? `${title}\n\n${body}\n\n`
          : content.substring(book.chapterOffsets[index] ?? 0,
            book.chapterOffsets[index + 1] ?? content.length);
        sections.push(section);
        offset += section.length;
      }
      updatedContent = sections.join('');
    } else {
      const starts = book.chapterOffsets !== undefined && book.chapterOffsets.length === book.chapterTitles.length
        ? book.chapterOffsets : BookRepository.splitChapters(content, book.tocRule ?? '').offsets;
      if (starts.length !== book.chapterTitles.length) {
        throw new Error('无法准确定位当前章节，未保存任何修改');
      }
      const start = starts[safeIndex] ?? 0;
      const end = starts[safeIndex + 1] ?? content.length;
      const lineEnd = content.indexOf('\n', start);
      const line = `${title}\n`;
      updatedContent = content.substring(0, start) + line + body + '\n\n' + content.substring(end);
      const lengthDelta = line.length + body.length + 2 - (end - start);
      const recalculatedStarts: number[] = [];
      for (let index = 0; index < book.chapterTitles.length; index++) {
        recalculatedStarts.push((starts[index] ?? 0) + (index > safeIndex ? lengthDelta : 0));
      }
      chapterOffsets = recalculatedStarts;
    }

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

    const nextBook: Book = {
      id: book.id,
      title: book.title,
      author: book.author,
      category: book.category,
      groupName: book.groupName,
      chapterTitles: chapterTitles,
      chapterOffsets: chapterOffsets,
      chapterIndex: book.chapterIndex,
      chapterProgress: book.chapterProgress,
      chapterCount: chapterTitles.length.toString(),
      lastChapter: chapterTitles[safeIndex] ?? title,
      progress: book.progress,
      coverColor: book.coverColor,
      coverMark: book.coverMark,
      coverUri: book.coverUri,
      customCoverUri: book.customCoverUri,
      bookType: book.bookType,
      fixedType: book.fixedType,
      contentPath: book.contentPath,
      format: book.format,
      charset: book.format === 'txt' ? 'UTF-8' : book.charset,
      fileSizeBytes: book.fileSizeBytes,
      imageStyle: book.imageStyle,
      reSegment: book.reSegment,
      description: book.description,
      remark: book.remark,
      customTag: book.customTag,
      bodyMissing: book.bodyMissing,
      androidOriginalPath: book.androidOriginalPath,
      androidCharacterPosition: 0,
      readerPositionVersion: 1,
      tocRule: book.tocRule,
      isLocal: book.isLocal
    };
    return nextBook;
  }

  /** 把本地阅读进度转换成 Android 备份使用的章内字符位置。 */
  static estimateAndroidChapterPosition(book: Book): number {
    if (book.contentPath === undefined) { return 0; }
    try {
      const content = BookRepository.readTextFile(book.contentPath, book.format === 'txt' ? book.charset : undefined);
      const titleCount = book.chapterTitles?.length ?? 0;
      const chapterIndex = Math.max(0, Math.min(Math.max(0, titleCount - 1), book.chapterIndex ?? 0));
      const progress = Math.max(0, Math.min(100, book.chapterProgress ?? 0));
      const chapterLength = BookRepository.getChapterSemanticLength(book, content, chapterIndex);
      if (book.readerPositionVersion === 2 && book.androidCharacterPosition !== undefined) {
        return Math.max(0, Math.min(chapterLength, Math.trunc(book.androidCharacterPosition)));
      }
      return Math.round(chapterLength * progress / 100);
    } catch (_) {
      return 0;
    }
  }

  /** 把 Android 备份中的章内字符位置转换成本地阅读百分比。 */
  static restoreAndroidProgress(book: Book, requestedIndex: number, characterPosition: number): Book {
    const titles = book.chapterTitles ?? [];
    const chapterIndex = Math.max(0,
      Math.min(Math.max(0, titles.length - 1), Math.trunc(requestedIndex)));
    let chapterProgress: number = 0;
    if (book.contentPath !== undefined) {
      try {
        const content = BookRepository.readTextFile(book.contentPath, book.format === 'txt' ? book.charset : undefined);
        const chapterLength = BookRepository.getChapterSemanticLength(book, content, chapterIndex);
        if (chapterLength > 0) {
          chapterProgress = Math.max(0, Math.min(100, characterPosition / chapterLength * 100));
        }
      } catch (_) {
      }
    }
    const chapterCount = Math.max(1, titles.length);
    return {
      id: book.id,
      title: book.title,
      author: book.author,
      category: book.category,
      groupName: book.groupName,
      chapterTitles: book.chapterTitles,
      chapterOffsets: book.chapterOffsets,
      chapterVolumes: book.chapterVolumes,
      chapterIndex: chapterIndex,
      chapterProgress: chapterProgress,
      lastChapter: titles[chapterIndex] ?? book.lastChapter,
      progress: titles.length > 0
        ? (chapterIndex + chapterProgress / 100) / chapterCount * 100 : 0,
      coverColor: book.coverColor,
      coverMark: book.coverMark,
      coverUri: book.coverUri,
      customCoverUri: book.customCoverUri,
      bookType: book.bookType,
      fixedType: book.fixedType,
      contentPath: book.contentPath,
      format: book.format,
      chapterCount: book.chapterCount,
      fileSizeBytes: book.fileSizeBytes,
      charset: book.charset,
      description: book.description,
      remark: book.remark,
      customTag: book.customTag,
      reSegment: book.reSegment,
      bodyMissing: book.bodyMissing,
      androidOriginalPath: book.androidOriginalPath,
      androidCharacterPosition: Math.max(0, Math.trunc(characterPosition)),
      readerPositionVersion: 2,
      tocRule: book.tocRule,
      isLocal: book.isLocal
    };
  }

  private static chapterBodyStart(section: string, title: string): number {
    const titleEnd = section.indexOf('\n');
    if (titleEnd < 0 || title.trim().length === 0) { return 0; }
    const actualTitle = section.substring(0, titleEnd).replace(/\r$/, '').trim();
    return actualTitle.startsWith(title.trim()) ? titleEnd + 1 : 0;
  }
  private static getChapterTextRange(book: Book, content: string, chapterIndex: number): ChapterTextRange {
    if (book.chapterOffsets !== undefined && book.chapterOffsets.length > 0) {
      const chapterStart = book.chapterOffsets[chapterIndex] ?? 0;
      const chapterEnd = book.chapterOffsets[chapterIndex + 1] ?? content.length;
      const section = content.substring(chapterStart, chapterEnd);
      const bodyStart = BookRepository.chapterBodyStart(section, book.chapterTitles?.[chapterIndex] ?? '');
      return { start: chapterStart + bodyStart, end: chapterEnd };
    }
    const titles = book.chapterTitles ?? [];
    const starts = BookRepository.splitChapters(content, book.tocRule ?? '').offsets;
    if (starts.length === titles.length && starts.length > 0) {
      const chapterStart = starts[chapterIndex] ?? 0;
      const chapterEnd = starts[chapterIndex + 1] ?? content.length;
      const section = content.substring(chapterStart, chapterEnd);
      const bodyStart = BookRepository.chapterBodyStart(section, titles[chapterIndex] ?? '');
      return { start: chapterStart + bodyStart, end: chapterEnd };
    }
    return { start: 0, end: content.length };
  }

  private static getChapterSemanticLength(book: Book, content: string, chapterIndex: number): number {
    const range = BookRepository.getChapterTextRange(book, content, chapterIndex);
    const rawBody = content.substring(range.start, range.end).trim();
    const title = book.chapterTitles?.[chapterIndex] ?? '';
    const body = book.format === 'epub'
      ? EpubRepository.removeDuplicateHeading(rawBody, title) : rawBody;
    const segmented = BookRepository.applyChapterReSegment(book, title, body);
    const replaced = ReplaceRuleRepository.applyContentForLength(book, segmented);
    const records = BookContentProcessRepository.getForChapter(book.id, chapterIndex);
    const processed = BookContentProcessEngine.apply(replaced, records).text;
    return LocalTextSemantics.parse(processed).sourceLength;
  }

  private static readPositionVersion(value: string | undefined): number {
    const version = Number(value ?? '1');
    if (version === 2) { return 2; }
    return version === 0 ? 0 : 1;
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
    const titleIndex = book.chapterTitles?.indexOf(chapterTitle) ?? -1;
    const chapterIndex = requestedChapterIndex ?? (titleIndex >= 0 ? titleIndex : book.chapterIndex ?? 0);
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

  static refreshNoTocBook(book: Book, maxLengthWithNoToc: number): NoTocBookRefreshResult {
    if (book.contentPath === undefined || book.format !== 'txt' || !book.isLocal) {
      return { book: book, content: '', changed: false, oldBodyOffsets: [], newBodyOffsets: [] };
    }
    const currentTitles = book.chapterTitles ?? [];
    const isLegacyNoToc = currentTitles.length === 1 && currentTitles[0] === '全文';
    let isGeneratedNoToc = currentTitles.length > 0;
    for (let index = 0; index < currentTitles.length; index++) {
      if (!/^第\d+章\(1\)$/.test(currentTitles[index] ?? '')) {
        isGeneratedNoToc = false;
        break;
      }
    }
    if (!isLegacyNoToc && !isGeneratedNoToc) {
      return { book: book, content: '', changed: false, oldBodyOffsets: [], newBodyOffsets: [] };
    }
    const content = BookRepository.readTextFile(book.contentPath, book.charset);
    if (BookRepository.splitChapters(content, book.tocRule ?? '').offsets.length > 0) {
      return { book: book, content: content, changed: false, oldBodyOffsets: [], newBodyOffsets: [] };
    }
    const layout = BookRepository.buildNoTocChapterLayout(content, maxLengthWithNoToc, book.charset);
    let layoutChanged = currentTitles.length !== layout.titles.length;
    for (let index = 0; !layoutChanged && index < layout.titles.length; index++) {
      if (currentTitles[index] !== layout.titles[index] ||
        (book.chapterOffsets?.[index] ?? -1) !== (layout.offsets[index] ?? -2)) {
        layoutChanged = true;
      }
    }
    if (!layoutChanged) {
      return { book: book, content: content, changed: false, oldBodyOffsets: [], newBodyOffsets: [] };
    }
    const oldOffsets = book.chapterOffsets ?? [0];
    const oldBodyOffsets = BookRepository.getNoTocBodyOffsets(content, oldOffsets, currentTitles.length);
    const newBodyOffsets = BookRepository.getNoTocBodyOffsets(content, layout.offsets, layout.titles.length);
    const oldIndex = Math.max(0, Math.min(currentTitles.length - 1, book.chapterIndex ?? 0));
    const oldStart = oldBodyOffsets[oldIndex] ?? 0;
    const oldEnd = oldOffsets[oldIndex + 1] ?? content.length;
    const oldBodyLength = Math.max(0, oldEnd - oldStart);
    const savedPosition = Math.max(0, Math.trunc(book.androidCharacterPosition ?? 0));
    const localPosition = book.readerPositionVersion === 2 || book.readerPositionVersion === 1
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
    const refreshedBook: Book = {
      id: book.id,
      title: book.title,
      author: book.author,
      category: book.category,
      groupName: book.groupName,
      chapterTitles: layout.titles,
      chapterOffsets: layout.offsets,
      // 按字数分章生成的是伪目录，没有分卷概念，显式清空避免残留旧标记。
      chapterVolumes: undefined,
      chapterIndex: chapterIndex,
      chapterProgress: chapterProgress,
      lastChapter: layout.titles[chapterIndex] ?? book.lastChapter,
      progress: (chapterIndex + chapterProgress / 100) / chapterCount * 100,
      coverColor: book.coverColor,
      coverMark: book.coverMark,
      coverUri: book.coverUri,
      customCoverUri: book.customCoverUri,
      bookType: book.bookType,
      fixedType: book.fixedType,
      contentPath: book.contentPath,
      format: book.format,
      chapterCount: layout.titles.length.toString(),
      fileSizeBytes: book.fileSizeBytes,
      imageStyle: book.imageStyle,
      reSegment: book.reSegment,
      charset: book.charset,
      description: book.description,
      remark: book.remark,
      customTag: book.customTag,
      bodyMissing: book.bodyMissing,
      androidOriginalPath: book.androidOriginalPath,
      androidCharacterPosition: chapterPosition,
      readerPositionVersion: 2,
      tocRule: book.tocRule,
      isLocal: book.isLocal
    };
    return {
      book: refreshedBook,
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
  ): Book {
    let content: string = '';
    try {
      content = importedContent ?? BookRepository.readTextFile(contentPath, charset);
    } catch (_) {
    }
    let chapterTitles: string[] = [];
    let chapterOffsets: number[] = [];
    let chapterVolumes: boolean[] = [];
    // 导入时对正文做一次规则识别，选中的正则写进 book.tocRule 固定下来。
    const chapterRule = BookRepository.resolveChapterRule(undefined, content);
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
    }
    const safeChapterIndex = Math.max(0, Math.min(chapterTitles.length - 1, chapterIndex));
    const safeChapterProgress = Math.max(0, Math.min(100, chapterProgress));
    const overallProgress = chapterTitles.length > 0
      ? (safeChapterIndex + safeChapterProgress / 100) / chapterTitles.length * 100
      : 0;
    let fileSizeBytes: number | undefined = undefined;
    try {
      fileSizeBytes = fileIo.statSync(contentPath).size;
    } catch (_) {
    }
    return {
      id: id,
      title: title,
      author: '本地 TXT',
      category: '本地',
      groupName: '本地未分组',
      chapterTitles: chapterTitles,
      chapterOffsets: chapterOffsets.length === chapterTitles.length ? chapterOffsets : undefined,
      chapterVolumes: chapterVolumes.length === chapterTitles.length ? chapterVolumes : undefined,
      lastChapter: chapterTitles[safeChapterIndex],
      chapterIndex: safeChapterIndex,
      chapterProgress: safeChapterProgress,
      progress: overallProgress,
      coverColor: '#39424B',
      coverMark: title.length > 0 ? title.substring(0, 1) : '书',
      chapterCount: chapterTitles.length.toString(),
      contentPath: contentPath,
      format: 'txt',
      fileSizeBytes: fileSizeBytes,
      charset: charset,
      reSegment: false,
      tocRule: chapterRule.length > 0 ? chapterRule : undefined,
      isLocal: true
    };
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

  /**
   * 确定这段正文该用哪条章节正则。
   *
   * @param cachedRule 书里已缓存的正则（对应上游 book.tocUrl）。非空时直接沿用：
   *   识别成功后就固定下来，用户后续启用/停用规则不会让已导入的书目录凭空变化。
   *   为空时按当前启用规则对正文样本做一次选择。
   * @returns 空串表示没有任何规则命中，调用方退回按字数分章。
   */
  private static resolveChapterRule(cachedRule: string | undefined, content: string): string {
    if (cachedRule !== undefined && cachedRule.length > 0) {
      return cachedRule;
    }
    // 样本取正文开头，与上游 TextFile 只读首个 buffer 做识别的做法一致。
    const sample = content.length > BookRepository.tocSampleSize
      ? content.substring(0, BookRepository.tocSampleSize) : content;
    const selection = TxtTocRuleRepository.selectForSample(sample);
    return selection.rule?.chapterRule ?? '';
  }

  /**
   * 按章节正则切出标题与行首偏移。
   *
   * titles 与 starts 必须来自同一次匹配：阅读链路里多处用
   * `chapterStarts.length !== book.chapterTitles.length` 判定能否按偏移取正文，
   * 两边规则不一致会直接抛「无法准确定位当前章节」。
   */
  private static splitChapters(content: string, chapterRule: string): ChapterSplit {
    const starts = TxtTocRuleRepository.splitChapterStarts(content, chapterRule);
    const titles: string[] = [];
    starts.forEach((start: number) => {
      const lineEnd = content.indexOf('\n', start);
      const rawLine = lineEnd >= 0 ? content.substring(start, lineEnd) : content.substring(start);
      titles.push(rawLine.replace(/\r$/, '').trim().substring(0, 80));
    });
    // 分卷正则跟着章节正则走（上游 getVolumePattern 的同一逻辑），书里只缓存章节正则。
    const volumeRule = TxtTocRuleRepository.resolveVolumeRule(chapterRule);
    return {
      titles: titles,
      offsets: starts,
      volumes: TxtTocRuleRepository.markVolumeTitles(titles, volumeRule)
    };
  }
}


