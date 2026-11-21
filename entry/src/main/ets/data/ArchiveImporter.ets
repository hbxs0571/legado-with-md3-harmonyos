import { fileIo } from '@kit.CoreFileKit';
import zlib from '@ohos.zlib';
import { Book } from '../model/Book';
import { BookRepository, CreatedLocalBook } from './BookRepository';
import { EpubRepository } from './EpubRepository';

/** 压缩包展开结果：可逐本落库的书 + 解析失败的书文件数。 */
export interface ArchiveImportResult {
  books: CreatedLocalBook[];
  failedCount: number;
}

/** 上游 AppPattern.kt:46 bookFileRegex 的等价后缀表；rar/7z 不在内（平台 zlib 无该能力）。 */
const BOOK_SUFFIXES: string[] = ['.txt', '.epub', '.umd', '.pdf', '.mobi', '.azw3', '.azw'];
/** 上游 LocalBook.kt:407-416 判漫画包用的图片后缀集合。 */
const IMAGE_SUFFIXES: string[] = ['.jpg', '.jpeg', '.png', '.webp', '.gif', '.avif', '.bmp'];
const MAX_ARCHIVE_BYTES: number = 128 * 1024 * 1024;
const MAX_EXPANDED_BYTES: number = 256 * 1024 * 1024;

/** 展开后的分类结果：书文件与图片文件都是绝对路径。 */
export interface ExtractedArchive {
  archiveName: string;
  extractedDirectory: string;
  bookFiles: string[];
  imageFiles: string[];
}

export class ArchiveImporter {
  /** 与 fileSuffixFilters / formatFromFileName 同口径：只认 zip / cbz。 */
  static isArchiveUri(uri: string): boolean {
    const lower = uri.toLowerCase();
    return lower.endsWith('.zip') || lower.endsWith('.cbz');
  }

  /**
   * 展开一个压缩包并按后缀分类。解压目录按包名 md5 复用（表格 I6 判据），
   * 同包二次导入不重新 decompressFile —— listBookEntries 与两个导入入口共用这一份，
   * 不许各自复制一套解压逻辑。
   */
  private static async extract(context: Context, uri: string): Promise<ExtractedArchive> {
    const archiveName = BookRepository.getFileName(uri);
    const workDirectory = `${context.cacheDir}/archive-import/${BookRepository.archiveCacheKey(archiveName)}`;
    const zipPath = `${workDirectory}/${archiveName}`;
    const extractedDirectory = `${workDirectory}/content`;
    const result: ExtractedArchive = {
      archiveName: archiveName, extractedDirectory: extractedDirectory, bookFiles: [], imageFiles: []
    };

    let alreadyExtracted = false;
    try {
      alreadyExtracted = fileIo.accessSync(extractedDirectory)
        && fileIo.lstatSync(extractedDirectory).isDirectory();
    } catch (_) {
      alreadyExtracted = false;
    }
    if (!alreadyExtracted) {
      ArchiveImporter.ensureDirectory(workDirectory);
      const source = fileIo.openSync(uri, fileIo.OpenMode.READ_ONLY);
      try {
        const compressedBytes = fileIo.statSync(source.fd).size;
        if (compressedBytes <= 0 || compressedBytes > MAX_ARCHIVE_BYTES) {
          throw new Error('压缩包为空或超过 128 MB');
        }
        fileIo.copyFileSync(source.fd, zipPath);
      } finally {
        fileIo.closeSync(source);
      }
      // 复用 EPUB 的 ZIP 防护：条目数 / 中央目录 / 解压后大小 / 路径穿越，错误文案沿用「EPUB ZIP」措辞。
      EpubRepository.validateBackupArchive(zipPath);
      const expandedBytes = await zlib.getOriginalSize(zipPath);
      if (expandedBytes <= 0 || expandedBytes > MAX_EXPANDED_BYTES) {
        throw new Error('压缩包解压后超过 256 MB，已停止导入');
      }
      fileIo.mkdirSync(extractedDirectory, true);
      await zlib.decompressFile(zipPath, extractedDirectory);
    }

    const files: string[] = [];
    ArchiveImporter.listFiles(extractedDirectory, files);
    for (let index = 0; index < files.length; index += 1) {
      const filePath = files[index];
      if (filePath === undefined) {
        continue;
      }
      const lower = filePath.toLowerCase();
      let matchedImage = false;
      for (let s = 0; s < IMAGE_SUFFIXES.length; s += 1) {
        const suffix = IMAGE_SUFFIXES[s];
        if (suffix !== undefined && lower.endsWith(suffix)) {
          matchedImage = true;
          break;
        }
      }
      if (matchedImage) {
        result.imageFiles.push(filePath);
        continue;
      }
      for (let s = 0; s < BOOK_SUFFIXES.length; s += 1) {
        const suffix = BOOK_SUFFIXES[s];
        if (suffix !== undefined && lower.endsWith(suffix)) {
          result.bookFiles.push(filePath);
          break;
        }
      }
    }
    result.bookFiles.sort();
    return result;
  }

  /** 条目在压缩包内的相对路径（列表展示与勾选都用它，绝对路径只在内部分配）。 */
  private static entryNameOf(extractedDirectory: string, filePath: string): string {
    const prefix = `${extractedDirectory}/`;
    return filePath.startsWith(prefix) ? filePath.substring(prefix.length) : BookRepository.getFileName(filePath);
  }

  /**
   * 批7（:1162，上游 `BookInfoViewModel.kt:1501-1541`）：列出压缩包里的书文件。
   *
   * 只列 BOOK_SUFFIXES 命中的条目；**包里有图时返回空数组** —— 上游 `LocalBook.kt:407-416`
   * 是 any：任一张图就整包当漫画，那种情况没有「按条目选书」的语义。
   */
  static async listBookEntries(context: Context, uri: string): Promise<string[]> {
    const extracted = await ArchiveImporter.extract(context, uri);
    if (extracted.imageFiles.length > 0) {
      return [];
    }
    const names: string[] = [];
    for (let index = 0; index < extracted.bookFiles.length; index += 1) {
      const filePath = extracted.bookFiles[index];
      if (filePath === undefined) {
        continue;
      }
      names.push(ArchiveImporter.entryNameOf(extracted.extractedDirectory, filePath));
    }
    return names;
  }

  /** 展开一个压缩包（全部条目）：漫画包整册成一本书，普通包逐本走 importSingleUri。 */
  static async importFromUri(context: Context, uri: string): Promise<ArchiveImportResult> {
    return ArchiveImporter.importFromUriEntries(context, uri, []);
  }

  /**
   * 只导入指定的条目；`entryNames` 为空 = 全部（等价旧行为）。
   *
   * 语义两处不许动：
   * - 包内有图 → 整包成一本漫画并直接返回（上游 any 语义，条目选择对漫画包不生效）；
   * - 包里一个书文件都没有 → 抛「压缩包里没有可导入的书籍或图片」，
   *   而「用户勾了 0 项」是在界面层挡住的（按钮禁用），不靠这里抛错。
   */
  static async importFromUriEntries(context: Context, uri: string,
    entryNames: string[]): Promise<ArchiveImportResult> {
    const extracted = await ArchiveImporter.extract(context, uri);
    const result: ArchiveImportResult = { books: [], failedCount: 0 };
    if (extracted.imageFiles.length > 0) {
      const comic = await ArchiveImporter.importComicArchive(context, uri, extracted.archiveName,
        extracted.imageFiles);
      result.books.push(comic);
      return result;
    }
    if (extracted.bookFiles.length === 0) {
      throw new Error('压缩包里没有可导入的书籍或图片');
    }
    const selected: string[] = [];
    for (let index = 0; index < extracted.bookFiles.length; index += 1) {
      const filePath = extracted.bookFiles[index];
      if (filePath === undefined) {
        continue;
      }
      if (entryNames.length === 0) {
        selected.push(filePath);
        continue;
      }
      const entryName = ArchiveImporter.entryNameOf(extracted.extractedDirectory, filePath);
      if (entryNames.includes(entryName)) {
        selected.push(filePath);
      }
    }
    if (selected.length === 0) {
      throw new Error('没有选中压缩包里的任何书文件');
    }
    for (let index = 0; index < selected.length; index += 1) {
      const bookFile = selected[index];
      if (bookFile === undefined) {
        continue;
      }
      try {
        const created = await BookRepository.importSingleUri(context, bookFile);
        result.books.push(created);
      } catch (_) {
        result.failedCount += 1;
      }
    }
    return result;
  }

  /** 漫画包：每张图一章，图复制进 filesDir/book-images（不能引用会被系统清掉的 cacheDir）。 */
  private static async importComicArchive(context: Context, uri: string,
    archiveName: string, imageFiles: string[]): Promise<CreatedLocalBook> {
    imageFiles.sort();
    const bookId = `local-${BookRepository.archiveCacheKey(uri)}`;
    let title = archiveName;
    const dot = title.lastIndexOf('.');
    if (dot > 0) {
      title = title.substring(0, dot);
    }
    const booksDirectory = `${context.filesDir}/books`;
    const imagesDirectory = `${context.filesDir}/book-images/${bookId}`;
    ArchiveImporter.ensureDirectory(booksDirectory);
    // 重导入先清旧图目录，避免 copyFileSync 目标已存在失败，也避免旧图残留。
    await EpubRepository.removeBackupWorkDirectory(imagesDirectory);
    ArchiveImporter.ensureDirectory(imagesDirectory);

    const titles: string[] = [];
    const offsets: number[] = [];
    const volumes: boolean[] = [];
    const contentSegments: string[] = [];
    let contentLength = 0;
    for (let index = 0; index < imageFiles.length; index += 1) {
      const imageFile = imageFiles[index];
      if (imageFile === undefined) {
        continue;
      }
      const imageTarget = `${imagesDirectory}/${index}.img`;
      const source = fileIo.openSync(imageFile, fileIo.OpenMode.READ_ONLY);
      try {
        fileIo.copyFileSync(source.fd, imageTarget);
      } finally {
        fileIo.closeSync(source);
      }
      const baseName = BookRepository.getFileName(imageFile);
      const nameDot = baseName.lastIndexOf('.');
      const chapterTitle = nameDot > 0 ? baseName.substring(0, nameDot) : baseName;
      const section = `${chapterTitle}\n\n[[EPUB_IMAGE:file://${imageTarget}]]\n\n`;
      titles.push(chapterTitle);
      offsets.push(contentLength);
      volumes.push(false);
      contentSegments.push(section);
      contentLength += section.length;
    }
    const content = contentSegments.join('');
    const contentPath = `${booksDirectory}/${bookId}.txt`;
    const contentFile = fileIo.openSync(contentPath,
      fileIo.OpenMode.WRITE_ONLY | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC);
    try {
      fileIo.writeSync(contentFile.fd, content);
    } finally {
      fileIo.closeSync(contentFile);
    }
    const chapters = BookRepository.buildChaptersForImport(contentPath, titles, offsets,
      volumes, content, undefined);
    const lastTitle = titles.length > 0 ? (titles[titles.length - 1] ?? '全文') : '全文';
    const book: Book = {
      id: bookId,
      title: title,
      author: '',
      // 上游本地书导入时 kind 是空的，标签由 `upKind()` 现算（格式名 + 文件大小 + 字数）。
      // 本地原来把 kind 写死成「本地」，详情页标签行就多出一个上游没有的「本地」。
      category: '',
      groupName: '本地未分组',
      groupNames: [],
      chapterIndex: 0,
      chapterProgress: 0,
      lastChapter: lastTitle,
      progress: 0,
      coverUri: `file://${imagesDirectory}/0.img`,
      description: '',
      chapterCount: titles.length.toString(),
      contentPath: contentPath,
      format: 'txt',
      bookType: 'image',
      latestChapterTime: Date.now(),
      isLocal: true
    };
    const created: CreatedLocalBook = { book: book, chapters: chapters, fileName: archiveName };
    return created;
  }

  /** 递归列出解压目录下所有文件的绝对路径（子目录结构、中文名原样保留）。 */
  private static listFiles(directory: string, out: string[]): void {
    let names: string[] = [];
    try {
      names = fileIo.listFileSync(directory);
    } catch (_) {
      return;
    }
    for (let index = 0; index < names.length; index += 1) {
      const raw = names[index];
      if (raw === undefined) {
        continue;
      }
      const name = raw.startsWith('/') ? raw.substring(1) : raw;
      const full = `${directory}/${name}`;
      let isDirectory = false;
      try {
        isDirectory = fileIo.lstatSync(full).isDirectory();
      } catch (_) {
        continue;
      }
      if (isDirectory) {
        ArchiveImporter.listFiles(full, out);
      } else {
        out.push(full);
      }
    }
  }

  private static ensureDirectory(path: string): void {
    try {
      fileIo.mkdirSync(path, true);
    } catch (_) {
      // 目录已存在时忽略，与 EpubRepository.ensureDirectory 同口径。
    }
  }
}
