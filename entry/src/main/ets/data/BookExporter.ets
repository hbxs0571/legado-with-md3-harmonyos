import { fileIo, picker } from '@kit.CoreFileKit';
import { preferences } from '@kit.ArkData';
import { util } from '@kit.ArkTS';
import { Context } from '@kit.AbilityKit';
import { Book, BookChapter } from '../model/Book';
import { BookRepository } from './BookRepository';
import { ReplaceRuleRepository } from './ReplaceRuleRepository';
import { EpubExporter } from './EpubExporter';
import { WebDavSync } from '../lib/WebDavSync';
import { formatHtml } from '../lib/HtmlFormatter';
import {
  BookExportSettings,
  BookExportSettingsStore,
  EXPORT_TYPES,
  episodeExportFileNameOf,
  exportFileNameOf,
  normalizeExportFileName,
  realAuthorOf
} from './BookExportSettings';

/**
 * 书籍导出执行层，对齐上游 `ExportBookService`（`service/ExportBookService.kt`）。
 *
 * 为什么单独一个文件：上游的导出服务被三处调用（书架管理页导出、书籍详情页导出 EPUB、
 * 书架管理页分段导出），三处读的是同一份 `currentExportSettings` 与同一个导出目录。
 * 本地原先把执行逻辑写在书架管理页里，另两处走 `EpubExporter` 的默认路径（弹保存框、
 * 不读设置、不上传 WebDAV）。抽到这里之后三条入口共用一套行为，不会各自分叉。
 */

/** 上游 `ReadBookConfig.paragraphIndent`（`help/config/ReadBookConfig.kt:599`）：两个全角空格。 */
const PARAGRAPH_INDENT: string = '　　';

/** 上游 `strings.xml:351` / `:352`：导出抬头里的简介行。 */
const INTRO_SHOW: string = 'Description:%s';
const INTRO_SHOW_NULL: string = 'Description: no introduction';

/**
 * 本地正文里的图片标记（`data/ArchiveImporter.ets:197-249` 写入的形态）。
 * 上游用 `AppPattern.imgPattern` 扫 `<img src="…">`，本地正文的图是 `[[EPUB_IMAGE:uri;…]]`，
 * 所以导出插图要按这个标记扫。
 */
const IMAGE_MARKER: RegExp = new RegExp('\\[\\[EPUB_IMAGE:([^;\\]\\r\\n]+)(?:;[^\\]\\r\\n]*)?\\]\\]', 'g');

/** 一章里扫到的一张待落盘插图。 */
interface TxtImageRef {
  chapterTitle: string;
  /** 图在章节正文里的行号（0 起），与上游 `SrcData.index` 同义，进文件名。 */
  lineIndex: number;
  uri: string;
}

/** 拼 TXT 的中间结果：正文与待落盘的插图。 */
interface TxtExportResult {
  text: string;
  images: TxtImageRef[];
}

/** 导出一次需要的外部状态：设置 + 目录。 */
export interface ExportTarget {
  settings: BookExportSettings;
  /** 已记住的导出目录；空串表示没有，改走系统保存框。 */
  folderPath: string;
  /** 该目录最近一次的可写探测结果。 */
  folderWritable: boolean;
}

export class BookExporter {

  /** 上游把导出目录存在 ACache 的 `exportBookPath` 键下（`BookshelfManageScreen.kt:1043`），本地用 preferences 同名键。 */
  static readonly exportFolderKey: string = 'exportBookPath';
  private static readonly exportFolderStore: string = 'legado_export_settings';

  /** 读出导出目录；读不到返回空串（等同「未选择」）。 */
  static async loadFolder(context: Context): Promise<string> {
    try {
      const store = await preferences.getPreferences(context, BookExporter.exportFolderStore);
      const value = await store.get(BookExporter.exportFolderKey, '');
      return typeof value === 'string' ? value : '';
    } catch (error) {
      console.error(`[BookExport] 读取导出目录失败: ${error}`);
      return '';
    }
  }

  static async saveFolder(context: Context, path: string): Promise<void> {
    const store = await preferences.getPreferences(context, BookExporter.exportFolderStore);
    await store.put(BookExporter.exportFolderKey, path);
    await store.flush();
  }

  /**
   * 读出一次导出需要的全部外部状态。
   * 三条入口（书架管理页 / 详情页 / 分段导出）都从这里取，保证读的是同一份设置与同一个目录。
   */
  static async loadTarget(context: Context): Promise<ExportTarget> {
    const settings = await BookExportSettingsStore.load(context);
    const folderPath = await BookExporter.loadFolder(context);
    // 目录为空时不做探测（没有目录就没有「不可写」这回事，走系统保存框）。
    const folderWritable = folderPath.length === 0 ? true : BookExporter.canWriteInto(folderPath);
    return { settings: settings, folderPath: folderPath, folderWritable: folderWritable };
  }

  /**
   * 导出一本书，返回给界面看的提示文字。
   *
   * 上游按 `exportType` 分派到两条支路（`BookshelfManageScreen.kt:1764-1777`：
   * `val exportType = if (exportTypeIndex == 1) "epub" else "txt"`），这里同构：
   * EPUB 走 `EpubExporter`，TXT 在本类逐章拼。
   */
  static async exportOne(context: Context, book: Book, target: ExportTarget): Promise<string> {
    const type = EXPORT_TYPES[target.settings.exportType] ?? 'txt';
    const fileName = BookExporter.fileNameOf(book, type, target.settings);
    const hasFolder = target.folderPath.length > 0 && target.folderWritable;
    if (type === 'epub') {
      if (!hasFolder) {
        // 没有可用目录时仍走系统保存框（EpubExporter 自带），保证总有一条能出文件的路。
        const saved = await EpubExporter.exportBook(context, book);
        return saved ? '已导出' : '已取消';
      }
      await EpubExporter.exportBookToDir(context, book, target.folderPath, fileName);
      if (target.settings.exportToWebDav) {
        await WebDavSync.exportFileToWebDav(context,
          `${BookExporter.trimSlash(target.folderPath)}/${fileName}`, fileName);
      }
      return '已导出';
    }
    const result = await BookExporter.buildTxtContent(context, book, target.settings);
    if (result.text.length === 0) {
      return '没有可导出的纯文本正文';
    }
    const charset = BookExporter.charsetOf(target.settings);
    let written = '';
    if (hasFolder) {
      written = BookExporter.writeTextToDir(target.folderPath, fileName, result.text, charset);
      // 上游插图只落在目录导出这条路上（`ExportBookService.kt:311-321`），系统保存框没有目录可依。
      if (result.images.length > 0) {
        const saved = await BookExporter.writeImages(target.folderPath, book, result.images);
        if (saved < result.images.length) {
          return `已导出（插图 ${saved}/${result.images.length} 张）`;
        }
      }
    } else {
      const saved = await BookExporter.saveWithPicker(context, fileName, result.text, charset);
      if (!saved) { return '已取消'; }
    }
    if (target.settings.exportToWebDav && written.length > 0) {
      await WebDavSync.exportFileToWebDav(context, written, fileName);
    }
    return '已导出';
  }

  /**
   * 分段导出：按范围挑章、每卷 N 章拆成多个 EPUB。
   *
   * 上游入口在 `BookshelfManageScreen.kt:298`（只在单选一本书时出现），弹窗收范围表达式与每卷章数
   * （`:1345-1365`），范围解析在 `ExportBookService.kt:988-1008`，分卷切片在 `:855-858`。
   * 返回实际写出的卷数；用户在保存对话框取消返回 0。
   *
   * 与上游的两处差别（如实记）：
   * 1. 上游分卷文件名走 `getExportFileName("epub", epubIndex, jsStr)` 的脚本模板，本地没有脚本引擎，
   *    只做 `{name}/{author}/{epubIndex}` 文本替换（`episodeExportFileNameOf`）。
   * 2. 上游在后台写缓存再逐个落盘；本地没有目录时一次弹保存对话框、把所有卷名一起交出去。
   */
  static async exportSegmented(context: Context, book: Book, scopeSpec: string,
    chaptersPerVolume: number, target: ExportTarget): Promise<number> {
    const hasFolder = target.folderPath.length > 0 && target.folderWritable;
    if (!hasFolder) {
      return await EpubExporter.exportBookSegmented(context, book, scopeSpec, chaptersPerVolume);
    }
    const nameOf = (volumeIndex: number): string =>
      episodeExportFileNameOf(book, 'epub', volumeIndex, target.settings.episodeExportFileName);
    const written = await EpubExporter.exportBookSegmentedToDir(context, book, scopeSpec, chaptersPerVolume,
      target.folderPath, nameOf);
    if (target.settings.exportToWebDav) {
      for (let index = 1; index <= written; index++) {
        const name = nameOf(index);
        await WebDavSync.exportFileToWebDav(context,
          `${BookExporter.trimSlash(target.folderPath)}/${name}`, name);
      }
    }
    return written;
  }

  /** 上游 `book.getExportFileName(suffix, currentExportSettings.bookExportFileName)`。 */
  static fileNameOf(book: Book, suffix: string, settings: BookExportSettings): string {
    return exportFileNameOf(book, suffix, settings.bookExportFileName);
  }

  static charsetOf(settings: BookExportSettings): string {
    const charset = settings.exportCharset.trim();
    return charset.length > 0 ? charset : 'UTF-8';
  }

  /**
   * 上游 `Book.getUseReplaceRule(defaultReplaceEnabled)` 在导出时的取值：
   * `useReplace = currentExportSettings.exportUseReplace && book.getUseReplaceRule(default)`。
   */
  static useReplaceRulesFor(book: Book, settings: BookExportSettings): boolean {
    if (!settings.exportUseReplace) { return false; }
    return ReplaceRuleRepository.isBookEnabled(book);
  }

  /**
   * 上游 `getAllContents` 的抬头（`ExportBookService.kt:369-380`）：
   * 书名 / 作者 / `Description:` + `HtmlFormatter.format(intro)`。
   */
  static headerOf(book: Book): string {
    const intro = (book.description ?? '').trim();
    const introLine = intro.length > 0
      ? INTRO_SHOW.replace('%s', `\n${formatHtml(intro)}`)
      : INTRO_SHOW_NULL;
    return `${book.title}\n${realAuthorOf(book.author)}\n${introLine}`;
  }

  /**
   * 拼出一本书的 TXT 正文，对齐上游 `getAllContents`（`ExportBookService.kt:362-396`）：
   * 抬头一段 + 逐章 `"\n\n" + 处理过的正文`，章节标题按 `exportNoChapterName` 取舍。
   *
   * 与上游的一处能力差别（如实记）：上游用 `mapAsync(MAX_THREAD)` 并行取章，本地
   * `BookRepository.forEachChapter` 是顺序的（它内部要按顺序复用同一份正文与区间表，
   * 并行会把整本书读进内存多份）。`parallelExportBook` 开关因此只影响上游那一侧，
   * 本地保留设置项与语义，不假装并行。
   */
  private static async buildTxtContent(context: Context, book: Book,
    settings: BookExportSettings): Promise<TxtExportResult> {
    const empty: TxtExportResult = { text: '', images: [] };
    if (book.contentPath === undefined || !book.isLocal) {
      return empty;
    }
    const pieces: string[] = [BookExporter.headerOf(book)];
    const includeTitle = !settings.exportNoChapterName;
    const wantImages = settings.exportPictureFile;
    const images: TxtImageRef[] = [];
    const chapters = await BookRepository.getChapterList(context, book.contentPath);
    const titles: string[] = chapters.map((chapter: BookChapter) => chapter.title);
    let index = 0;
    await BookRepository.forEachChapter(book, async (chapterContent: string, _chapterIndex: number): Promise<boolean> => {
      const title = titles[index] ?? '';
      index += 1;
      if (wantImages) {
        // 上游按「行号 + 图片地址」记 SrcData（`ExportBookService.kt:426-437`），这里同口径。
        const lines = chapterContent.split('\n');
        for (let line = 0; line < lines.length; line++) {
          const text = lines[line] ?? '';
          IMAGE_MARKER.lastIndex = 0;
          let match = IMAGE_MARKER.exec(text);
          while (match !== null) {
            const uri = (match[1] ?? '').trim();
            if (uri.length > 0) {
              images.push({ chapterTitle: title, lineIndex: line, uri: uri });
            }
            match = IMAGE_MARKER.exec(text);
          }
        }
      }
      const body = BookExporter.indentParagraphs(chapterContent, includeTitle && title.length > 0);
      const heading = includeTitle && title.length > 0 ? `${title}\n` : '';
      pieces.push(`\n\n${heading}${body}`);
      return Promise.resolve(true);
    }, BookExporter.useReplaceRulesFor(book, settings), chapters);
    return { text: pieces.join(''), images: images };
  }

  /**
   * 上游 `ContentProcessor.getContent` 的段落缩进（`ContentProcessor.kt:236-260`）：
   * 逐段 trim 空白，**带标题时首段不加缩进**，其余段加 `paragraphIndent`。
   *
   * `BookRepository.forEachChapter` 交来的正文已经被 `trimChapterParagraphs` 去过空行但不加缩进，
   * 所以这里只补缩进与首段特例，不重复做清洗。
   */
  private static indentParagraphs(body: string, firstIsTitle: boolean): string {
    const lines: string[] = [];
    for (const raw of body.split('\n')) {
      const paragraph = raw.trim();
      if (paragraph.length === 0) { continue; }
      if (lines.length === 0 && firstIsTitle) {
        lines.push(paragraph);
      } else {
        lines.push(`${PARAGRAPH_INDENT}${paragraph}`);
      }
    }
    return lines.join('\n');
  }

  /**
   * 把扫到的插图按上游的目录结构落盘：
   * `"${book.name}_${book.author}"/images/${chapter.title}/${index}-${md5Encode16(src)}.jpg`
   * （`ExportBookService.kt:299-334`）。读图失败时跳过，不阻断正文导出。
   *
   * 与上游的差别（如实记）：上游走 `BookHelp.getImage` 从缓存目录取图（网络图已缓存过），
   * 本地正文的图是导入时落在 `filesDir/book-images/` 下的 `[[EPUB_IMAGE:file://…]]`，
   * 直接读原文件字节落盘，不做 JPEG 转码 —— 转码只发生在 EPUB 打包那条路上。
   */
  private static async writeImages(dir: string, book: Book, images: TxtImageRef[]): Promise<number> {
    if (images.length === 0) { return 0; }
    const author = realAuthorOf(book.author);
    let saved = 0;
    for (const one of images) {
      const folder = `${BookExporter.trimSlash(dir)}/${normalizeExportFileName(`${book.title}_${author}`)}` +
        `/images/${normalizeExportFileName(one.chapterTitle)}`;
      try {
        fileIo.mkdirSync(folder, true);
      } catch (error) {
        console.error(`[BookExport] 建插图目录失败 ${folder}: ${error}`);
        continue;
      }
      let bytes: ArrayBuffer | undefined = undefined;
      try {
        const file = fileIo.openSync(one.uri, fileIo.OpenMode.READ_ONLY);
        try {
          const size = fileIo.statSync(file.fd).size;
          const buffer = new ArrayBuffer(size);
          fileIo.readSync(file.fd, buffer);
          bytes = buffer;
        } finally {
          fileIo.closeSync(file);
        }
      } catch (error) {
        console.error(`[BookExport] 读插图失败 ${one.uri}: ${error}`);
        continue;
      }
      if (bytes === undefined) { continue; }
      const target = `${folder}/${one.lineIndex}-${BookRepository.md5Encode16(one.uri)}.jpg`;
      try {
        if (fileIo.accessSync(target)) { fileIo.unlinkSync(target); }
      } catch (_) {
        // 删不掉就让后面的 openSync 报出真正原因，不吞掉。
      }
      try {
        const out = fileIo.openSync(target,
          fileIo.OpenMode.WRITE_ONLY | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC);
        try {
          fileIo.writeSync(out.fd, bytes);
        } finally {
          fileIo.closeSync(out);
        }
        saved += 1;
      } catch (error) {
        console.error(`[BookExport] 写插图失败 ${target}: ${error}`);
      }
    }
    return saved;
  }

  /**
   * 按指定字符集把一段文本编成可写入的字节；UTF-8 直接给字符串（全仓既有写法）。
   * SDK 的 `TextEncoder.create(charset)` 只认它支持的字符集，编不出来就回落字符串直写。
   */
  private static encodeForCharset(content: string, charset: string): string | ArrayBuffer {
    const normalized = charset.trim().toLowerCase();
    if (normalized.length === 0 || normalized === 'utf-8' || normalized === 'utf8') {
      return content;
    }
    try {
      const encoded: Uint8Array = util.TextEncoder.create(charset.trim()).encodeInto(content);
      return encoded.buffer as ArrayBuffer;
    } catch (error) {
      return content;
    }
  }

  /** 写文件到已打开的 fd（保存对话框与目录两条路共用）。 */
  private static writeToFd(fd: number, content: string, charset: string): void {
    const payload = BookExporter.encodeForCharset(content, charset);
    fileIo.writeSync(fd, payload);
  }

  /**
   * 弹系统保存对话框写一份文本。返回 false 表示用户取消。
   * 只在「没有设置导出文件夹」时使用，与上游 `startExportForBooks`（`BookshelfManageScreen.kt:325-345`）
   * 的「路径为空或不可写才弹选择器」同义。
   */
  private static async saveWithPicker(context: Context, fileName: string, content: string,
    charset: string): Promise<boolean> {
    const options = new picker.DocumentSaveOptions();
    options.newFileNames = [fileName];
    options.fileSuffixChoices = ['TXT 文本|.txt'];
    const uris = await new picker.DocumentViewPicker(context).save(options);
    const uri = uris[0];
    if (uri === undefined) { return false; }
    const target = fileIo.openSync(uri, fileIo.OpenMode.WRITE_ONLY | fileIo.OpenMode.TRUNC);
    try {
      BookExporter.writeToFd(target.fd, content, charset);
    } finally {
      fileIo.closeSync(target);
    }
    return true;
  }

  /** 写到已记住的导出目录；同名文件先删再写，对齐上游 `fileDoc.find(filename)?.delete()`。 */
  private static writeTextToDir(dir: string, fileName: string, content: string, charset: string): string {
    const target = `${BookExporter.trimSlash(dir)}/${fileName}`;
    try {
      if (fileIo.accessSync(target)) { fileIo.unlinkSync(target); }
    } catch (_) {
      // 同上：让 openSync 报真正原因。
    }
    const file = fileIo.openSync(target,
      fileIo.OpenMode.WRITE_ONLY | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC);
    try {
      BookExporter.writeToFd(file.fd, content, charset);
    } finally {
      fileIo.closeSync(file);
    }
    return target;
  }

  static trimSlash(dir: string): string {
    return dir.endsWith('/') ? dir.substring(0, dir.length - 1) : dir;
  }

  /**
   * 目录实际能不能被应用写入：在目录下开一个探针文件再删掉。
   * 与 `pages/Index.ets:6867-6884` 同法，理由也相同：系统目录选择器给的是 docs uri，
   * fileIo 只有部分 uri 能直接打开，不能凭「picker 返回了 uri」当依据。
   */
  static canWriteInto(dir: string): boolean {
    if (dir.length === 0) { return false; }
    const probePath = `${BookExporter.trimSlash(dir)}/legado-probe-${Date.now()}.txt`;
    try {
      const probe = fileIo.openSync(probePath,
        fileIo.OpenMode.WRITE_ONLY | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC);
      try {
        fileIo.writeSync(probe.fd, 'probe');
      } finally {
        fileIo.closeSync(probe);
      }
      fileIo.unlinkSync(probePath);
      return true;
    } catch (error) {
      console.error(`[BookExport] 目录不可写 ${dir}: ${error}`);
      return false;
    }
  }
}
