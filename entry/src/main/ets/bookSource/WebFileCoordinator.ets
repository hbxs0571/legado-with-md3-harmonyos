import { Book } from '../model/Book';
import { BookRepository } from '../data/BookRepository';
import { BookSourceRuntime } from './BookSourceRuntime';
import { RemoteBookDetail } from './SourceModels';

/**
 * 网页书（webFile）的下载文件清单与分类。
 *
 * 上游参照：
 * - `BookInfoViewModel.kt:1382-1403 loadWebFile`：`book.downloadUrls` 逐条 `AnalyzeUrl`
 *   → `UrlUtil.getFileName(analyzeUrl) ?: "${name} 作者：${author}.${type}"`，
 *   得到 `BookInfoWebFile(url, name)`（`BookInfoContract.kt:180-185`）。
 * - `BookInfoViewModel.kt:2157-2164` 三条判据：
 *   `suffix = UrlUtil.getSuffix(name)`、
 *   `isSupported = AppPattern.bookFileRegex.matches(name)`（`AppPattern.kt:46`）、
 *   `isSupportDecompress = AppPattern.archiveFileRegex.matches(name)`（`AppPattern.kt:48`）。
 */
export interface BookInfoWebFile {
  url: string;
  name: string;
}

/** 上游 `AppPattern.kt:46` `bookFileRegex` 的后缀表，逐项对齐。 */
const BOOK_SUFFIXES: string[] = ['.txt', '.epub', '.umd', '.pdf', '.mobi', '.azw3', '.azw'];
/** 上游 `AppPattern.kt:48` `archiveFileRegex` 的后缀表（含 rar / 7z）。 */
const ARCHIVE_SUFFIXES: string[] = ['.zip', '.cbz', '.rar', '.7z'];
/** 平台 zlib 只解 zip 系；rar / 7z 认得出来但解不了，要给出明确提示而不是静默失败。 */
const DECOMPRESSIBLE_SUFFIXES: string[] = ['.zip', '.cbz'];

export class WebFileCoordinator {
  /** 上游 `BookInfoWebFile.isSupported`：是不是可直接导入的电子书文件。 */
  static isSupportedFile(name: string): boolean {
    const lower = name.toLowerCase();
    for (const suffix of BOOK_SUFFIXES) {
      if (lower.endsWith(suffix)) { return true; }
    }
    return false;
  }

  /** 上游 `BookInfoWebFile.isSupportDecompress`：是不是压缩包（zip / cbz / rar / 7z）。 */
  static isArchiveFile(name: string): boolean {
    const lower = name.toLowerCase();
    for (const suffix of ARCHIVE_SUFFIXES) {
      if (lower.endsWith(suffix)) { return true; }
    }
    return false;
  }

  /** 本平台能不能真解开这个包（只有 zip 系）。 */
  static isDecompressible(name: string): boolean {
    const lower = name.toLowerCase();
    for (const suffix of DECOMPRESSIBLE_SUFFIXES) {
      if (lower.endsWith(suffix)) { return true; }
    }
    return false;
  }

  /** 上游 `BookInfoWebFile.suffix`（`UrlUtil.getSuffix`）：取最后一个点之后的扩展名，不含点。 */
  static suffixOf(name: string): string {
    const dot = name.lastIndexOf('.');
    if (dot < 0 || dot === name.length - 1) { return ''; }
    return name.substring(dot + 1);
  }

  /**
   * 上游 `UrlUtil.getFileName(analyzeUrl) ?: "${fileNameNoExtension}.${analyzeUrl.type}"` 的等价：
   * 先从 url 末段取文件名（去查询串），取不到就用「书名 作者：作者」拼后缀兜底。
   */
  static fileNameOf(book: Book, url: string): string {
    const fromUrl = WebFileCoordinator.fileNameFromUrl(url);
    if (fromUrl.length > 0) { return fromUrl; }
    const suffix = WebFileCoordinator.suffixFromUrl(url);
    const stem = book.author.length === 0 ? book.title : `${book.title} 作者：${book.author}`;
    return suffix.length > 0 ? `${stem}.${suffix}` : stem;
  }

  /** 从 url 取末段文件名；带查询串或锚点时先切掉。解不出返回空串。 */
  private static fileNameFromUrl(url: string): string {
    let path = url;
    const query = path.indexOf('?');
    if (query >= 0) { path = path.substring(0, query); }
    const hash = path.indexOf('#');
    if (hash >= 0) { path = path.substring(0, hash); }
    const slash = path.lastIndexOf('/');
    const rawName = slash >= 0 ? path.substring(slash + 1) : path;
    if (rawName.length === 0) { return ''; }
    try {
      return decodeURIComponent(rawName);
    } catch (error) {
      return rawName;
    }
  }

  /** 从 url 的末段推断扩展名（同样先切掉查询串与锚点）。 */
  private static suffixFromUrl(url: string): string {
    let path = url;
    const query = path.indexOf('?');
    if (query >= 0) { path = path.substring(0, query); }
    const hash = path.indexOf('#');
    if (hash >= 0) { path = path.substring(0, hash); }
    return WebFileCoordinator.suffixOf(path);
  }

  /**
   * 上游 `loadWebFile`：拉详情拿 `downloadUrls`，逐条转成 `BookInfoWebFile`。
   * 没有关联书源、没有 bookUrl、或详情里没有下载链接时返回空数组（对应上游 catch 分支的清空）。
   */
  static async loadFiles(book: Book): Promise<BookInfoWebFile[]> {
    const sourceUrl = book.origin ?? '';
    const bookUrl = book.contentPath ?? '';
    if (sourceUrl.length === 0 || bookUrl.length === 0) { return []; }
    const detail: RemoteBookDetail = await BookSourceRuntime.detail(sourceUrl, bookUrl);
    const urls: string[] = detail.downloadUrls ?? [];
    const files: BookInfoWebFile[] = [];
    for (const url of urls) {
      if (url.length === 0) { continue; }
      files.push({ url: url, name: WebFileCoordinator.fileNameOf(book, url) });
    }
    return files;
  }

  /** 下载落盘用的安全文件名：去掉路径分隔符与控制字符，避免写到目录外。 */
  static safeFileName(name: string): string {
    let result = '';
    for (let index = 0; index < name.length; index += 1) {
      const ch = name.charAt(index);
      if (ch === '/' || ch === '\\' || ch === ':' || ch === '*' || ch === '?' ||
        ch === '"' || ch === '<' || ch === '>' || ch === '|') {
        result += '_';
      } else if (ch.charCodeAt(0) < 32) {
        continue;
      } else {
        result += ch;
      }
    }
    const trimmed = result.trim();
    return trimmed.length > 0 ? trimmed : `web-file-${BookRepository.md5Encode16(name)}`;
  }
}
