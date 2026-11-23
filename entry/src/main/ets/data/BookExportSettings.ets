import { preferences } from '@kit.ArkData';
import { Book } from '../model/Book';

/**
 * 书籍导出设置。字段与上游 `domain/model/settings/BookExportSettings.kt:3-14` 逐项对应（10 个）。
 *
 * 键名照抄上游 `constant/PreferKey.kt`，不用本地自造名：
 * - `bookExportFileName`(`:67`) / `episodeExportFileName`(`:69`) / `exportCharset`(`:148`)
 * - `exportUseReplace`(`:149`) / `webDavCacheBackup`(`:93`，即 exportToWebDav) / `exportNoChapterName`(`:94`)
 * - `enableCustomExport`(`:92`) / `exportType`(`:95`) / `exportPictureFile`(`:96`) / `parallelExportBook`
 *
 * 为什么要照抄键名：Android 备份包里的 config.xml 按这些键存值，键名一致才能互相读。
 * 本地这份设置不参与备份包（上游也不进），但跨端导出的语义要能对上。
 */
export interface BookExportSettings {
  /** 导出文件名模板；空串等价上游的 null（回落默认 `书名 作者：作者.txt`）。 */
  bookExportFileName: string;
  /** 分卷文件名模板；上游这一项交给 JS 脚本求值，本地无脚本引擎，只支持 `{name}/{author}/{epubIndex}` 占位。 */
  episodeExportFileName: string;
  /** 导出字符集。 */
  exportCharset: string;
  /** 是否套用替换净化规则。 */
  exportUseReplace: boolean;
  /** 导出后是否同时上传到 WebDAV 的 books/ 目录。 */
  exportToWebDav: boolean;
  /** 导出正文时是否去掉章节标题。 */
  exportNoChapterName: boolean;
  /** 是否走自定义导出（单本 EPUB 弹范围与分卷设置）。 */
  enableCustomExport: boolean;
  /** 0 = txt，1 = epub（上游 `exportTypes = arrayListOf("txt","epub")`，BookshelfManageScreen.kt:205）。 */
  exportType: number;
  /** 是否把正文里的插图抽成图片文件一起导出。 */
  exportPictureFile: boolean;
  /** 是否并行处理章节（上游 mapAsync(MAX_THREAD)，否则 1 线程）。 */
  parallelExportBook: boolean;
}

/** 上游 `BookExportSettings.kt:3-14` 的默认值逐项照抄。 */
export function defaultBookExportSettings(): BookExportSettings {
  return {
    bookExportFileName: '',
    episodeExportFileName: '',
    exportCharset: 'UTF-8',
    exportUseReplace: true,
    exportToWebDav: false,
    exportNoChapterName: false,
    enableCustomExport: false,
    exportType: 0,
    exportPictureFile: false,
    parallelExportBook: false
  };
}

/** 导出格式的下拉项，与上游 `exportTypes` 同序（下标即 exportType 的值）。 */
export const EXPORT_TYPES: string[] = ['txt', 'epub'];

/** 上游 `commonCharsets`（BookshelfManageScreen.kt:206）逐项照抄。 */
export const COMMON_EXPORT_CHARSETS: string[] = ['UTF-8', 'GBK', 'GB2312', 'GB18030', 'Big5', 'UTF-16'];

/** 上游 `AppPattern.authorRegex`（`constant/AppPattern.kt:36`）：剥掉「作者：」「著」这类前缀后缀。 */
const AUTHOR_PREFIX_SUFFIX: RegExp = new RegExp('^\\s*作\\s*者[:：\\s]+|\\s+著');

/** 上游 `Book.getRealAuthor()`（`data/entities/Book.kt:179`）。 */
export function realAuthorOf(author: string): string {
  return author.replace(AUTHOR_PREFIX_SUFFIX, '');
}

/** 上游 `StringExtensions.normalizeFileName()`（`help/StringExtensions.kt:169`）：非法字符换 `_`。 */
export function normalizeExportFileName(text: string): string {
  return text.replace(new RegExp('[\\\\/:*?"<>|]', 'g'), '_');
}

/**
 * 上游 `Book.getExportFileName(suffix, template)`（`help/book/BookExtensions.kt:634-683`）。
 *
 * 模板里的 `{name}` / `{author}` / `{group}` / `{source}` / `{remark}` 五个占位符按上游顺序替换，
 * 认不出的占位符原样保留里面的文字（上游 `else -> result.append(inside)`），不是整段删掉。
 * 模板为空时回落 `"$name 作者：${getRealAuthor()}.$suffix"`。
 */
export function exportFileNameOf(book: Book, suffix: string, template: string): string {
  const realAuthor: string = realAuthorOf(book.author);
  if (template.trim().length === 0) {
    return `${book.title} 作者：${realAuthor}.${suffix}`;
  }
  const pattern: RegExp = new RegExp('\\{([^}]*)\\}', 'g');
  let result: string = '';
  let lastEnd: number = 0;
  let match: RegExpExecArray | null = pattern.exec(template);
  while (match !== null) {
    result += template.substring(lastEnd, match.index);
    const inside: string = match[1] ?? '';
    const lower: string = inside.toLowerCase();
    let field: string | undefined = undefined;
    if (lower === 'name') {
      field = book.title;
    } else if (lower === 'author') {
      field = realAuthor;
    } else if (lower === 'group') {
      field = (book.groupNames ?? []).join(',');
    } else if (lower === 'source') {
      field = book.originName ?? '';
    } else if (lower === 'remark') {
      field = book.remark ?? '';
    }
    result += field !== undefined ? field : inside;
    lastEnd = match.index + match[0].length;
    match = pattern.exec(template);
  }
  if (lastEnd < template.length) {
    result += template.substring(lastEnd);
  }
  return `${result}.${suffix}`;
}

/**
 * 上游 `Book.getExportFileName(suffix, epubIndex, jsStr)`（`BookExtensions.kt:686-709`）的分卷版。
 *
 * 上游这一支交给 Rhino 脚本引擎求值（用户可写任意 JS），本地没有脚本引擎：
 * 只把 `{name}` / `{author}` / `{epubIndex}` 三个上游绑定变量做文本替换，其余原样保留。
 * 模板为空时用上游的默认规则 `"$name 作者：$realAuthor [$epubIndex].$suffix"`。
 */
export function episodeExportFileNameOf(book: Book, suffix: string, epubIndex: number,
  template: string): string {
  const realAuthor: string = realAuthorOf(book.author);
  const fallback: string = `${book.title} 作者：${realAuthor} [${epubIndex}].${suffix}`;
  if (template.trim().length === 0) {
    return fallback;
  }
  const replaced: string = template
    .replace(new RegExp('\\{name\\}', 'g'), book.title)
    .replace(new RegExp('\\{author\\}', 'g'), realAuthor)
    .replace(new RegExp('\\{epubIndex\\}', 'g'), String(epubIndex));
  return normalizeExportFileName(`${replaced}.${suffix}`);
}

/**
 * 导出设置的存取。形态与 WebDavConfigStore 一致：单键 JSON，字段缺失或类型不对回落默认值，
 * 一条坏记录不能让书架管理页打不开。
 */
export class BookExportSettingsStore {
  private static readonly preferenceName: string = 'legado_book_export_settings';
  private static readonly storeKey: string = 'export';
  private static saveQueue: Promise<void> = Promise.resolve();

  static async load(context: Context): Promise<BookExportSettings> {
    try {
      const store = await preferences.getPreferences(context, BookExportSettingsStore.preferenceName);
      const value = await store.get(BookExportSettingsStore.storeKey, '');
      if (typeof value !== 'string' || value.length === 0) {
        return defaultBookExportSettings();
      }
      return BookExportSettingsStore.normalize(value);
    } catch (error) {
      console.error(`[BookExportSettingsStore] 读取失败，回落默认值: ${
        error instanceof Error ? error.message : String(error)}`);
      return defaultBookExportSettings();
    }
  }

  static save(context: Context, settings: BookExportSettings): Promise<void> {
    const operation = BookExportSettingsStore.saveQueue.then(async (): Promise<void> => {
      const store = await preferences.getPreferences(context, BookExportSettingsStore.preferenceName);
      await store.put(BookExportSettingsStore.storeKey, JSON.stringify(settings));
      await store.flush();
    });
    BookExportSettingsStore.saveQueue =
      operation.then((): void => {}, (_error: Error): void => {});
    return operation;
  }

  /** 返回一个独立副本，供页面改单字段后再存，避免直接改已持有的对象。 */
  static clone(source: BookExportSettings): BookExportSettings {
    return {
      bookExportFileName: source.bookExportFileName,
      episodeExportFileName: source.episodeExportFileName,
      exportCharset: source.exportCharset,
      exportUseReplace: source.exportUseReplace,
      exportToWebDav: source.exportToWebDav,
      exportNoChapterName: source.exportNoChapterName,
      enableCustomExport: source.enableCustomExport,
      exportType: source.exportType,
      exportPictureFile: source.exportPictureFile,
      parallelExportBook: source.parallelExportBook
    };
  }

  private static normalize(raw: string): BookExportSettings {
    const fallback = defaultBookExportSettings();
    let parsed: Record<string, Object>;
    try {
      parsed = JSON.parse(raw) as Record<string, Object>;
    } catch (_) {
      return fallback;
    }
    if (parsed === undefined || parsed === null) {
      return fallback;
    }
    const record = parsed;
    const str = (key: string, def: string): string => {
      const v = record[key];
      return typeof v === 'string' ? v as string : def;
    };
    const bool = (key: string, def: boolean): boolean => {
      const v = record[key];
      return typeof v === 'boolean' ? v as boolean : def;
    };
    const num = (key: string, def: number): number => {
      const v = record[key];
      return typeof v === 'number' && Number.isFinite(v) ? v as number : def;
    };
    return {
      bookExportFileName: str('bookExportFileName', fallback.bookExportFileName),
      episodeExportFileName: str('episodeExportFileName', fallback.episodeExportFileName),
      exportCharset: str('exportCharset', fallback.exportCharset),
      exportUseReplace: bool('exportUseReplace', fallback.exportUseReplace),
      exportToWebDav: bool('exportToWebDav', fallback.exportToWebDav),
      exportNoChapterName: bool('exportNoChapterName', fallback.exportNoChapterName),
      enableCustomExport: bool('enableCustomExport', fallback.enableCustomExport),
      exportType: num('exportType', fallback.exportType),
      exportPictureFile: bool('exportPictureFile', fallback.exportPictureFile),
      parallelExportBook: bool('parallelExportBook', fallback.parallelExportBook)
    };
  }
}
