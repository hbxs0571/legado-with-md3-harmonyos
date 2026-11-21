import { fileIo, picker } from '@kit.CoreFileKit';
import image from '@ohos.multimedia.image';
import { util } from '@kit.ArkTS';
import { Book, BookChapter } from '../model/Book';
import { BookRepository } from './BookRepository';
import { EpubWriter, EpubZipEntry } from './EpubWriter';
import { AppLog } from '../lib/AppLog';

/** 导出时一张图在包里的最终形态。 */
interface ExportImage {
  fileName: string;
  data: Uint8Array;
  mediaType: string;
}

/** 按字节头认出来的图片格式。 */
interface SniffedFormat {
  ext: string;
  mediaType: string;
}

/**
 * 导出为 EPUB 3。
 *
 * 正文来源是 BookRepository.readChapter：它返回的就是阅读器屏幕上那一份（去重章名、
 * 重新分段、替换规则、图片标记都在里面），所以导出的内容与用户看到的一致；
 * 反过来如果直接切 chapterBody，导出结果会缺了阅读侧的净化。
 *
 * 局限（如实记进回报）：只做「纯文本重排版」，段落样式、内嵌字体、ruby 都不保留——
 * 本地数据层在导入时就已经把正文转成纯文本了，没有那些信息可还原。
 */
export class EpubExporter {
  /** 正文图片标记，与 LocalTextSemantics.ets:58 同一形态。 */
  private static readonly IMAGE_PATTERN: RegExp = /\[\[EPUB_IMAGE:([^;\]\r\n]+)(?:;[^\]\r\n]*)?\]\]/g;

  /** 导出成功后返回 true；用户在保存对话框里取消返回 false。 */
  static async exportBook(context: Context, book: Book): Promise<boolean> {
    const chapters = await EpubExporter.loadExportableChapters(context, book);
    if (chapters.length === 0) {
      throw new Error('这本书没有章节，无法导出');
    }
    const archive = await EpubExporter.packVolume(book, chapters, chapters);
    return await EpubExporter.saveToFile(context, archive, EpubExporter.buildFileName(book.title));
  }

  /**
   * 批2（:471）：按章节范围导出，并按每卷章数拆成多个 EPUB。
   * 上游入口在 BookshelfManageScreen.kt:298（只在单选一本书时出现），弹窗收范围表达式与每卷章数
   * （:1345-1365），范围解析在 ExportBookService.kt:988-1008，分卷切片在 :855-858。
   * 返回实际写出的卷数；用户在保存对话框取消返回 0。
   *
   * 如实记两处差异：
   * 1. 上游还收「分卷文件名模板」（customEpisodeExportNameInput），本地只做 书名.epub / 书名-2.epub，
   *    模板变量不接，已记进 KNOWN-ISSUES。
   * 2. 上游在后台写缓存再逐个落盘；本地一次弹保存对话框、把所有卷名一起交出去（同名目录下多文件）。
   */
  static async exportBookSegmented(context: Context, book: Book, scopeSpec: string,
    chaptersPerVolume: number): Promise<number> {
    const chapters = await EpubExporter.loadExportableChapters(context, book);
    if (chapters.length === 0) {
      throw new Error('这本书没有章节，无法导出');
    }
    const picked = EpubExporter.parseScope(scopeSpec, chapters);
    if (picked.length === 0) {
      throw new Error('范围里没有章节，无法导出');
    }
    // 上游 ExportBookService.kt:1345 对每卷章数做 toIntOrNull()?.coerceAtLeast(1) ?: 1。
    const size = Math.floor(chaptersPerVolume) >= 1 ? Math.floor(chaptersPerVolume) : 1;
    const volumes: BookChapter[][] = [];
    for (let start = 0; start < picked.length; start += size) {
      volumes.push(picked.slice(start, Math.min(picked.length, start + size)));
    }
    const archives: ArrayBuffer[] = [];
    for (let index = 0; index < volumes.length; index++) {
      const volume = volumes[index];
      if (volume === undefined) { continue; }
      // 每卷独立打包：nav / opf / 图片表都重来一遍，spine 也按卷重置。
      archives.push(await EpubExporter.packVolume(book, volume, chapters));
      AppLog.put(`导出分卷：第 ${index + 1}/${volumes.length} 卷，${volume.length} 章`);
    }
    const names: string[] = [];
    for (let index = 0; index < archives.length; index++) {
      names.push(EpubExporter.volumeFileBase(book.title, index + 1));
    }
    return await EpubExporter.saveManyToFiles(context, archives, names);
  }

  /** 导出前的公共检查：正文文件在盘上、章节表读得出来。 */
  private static async loadExportableChapters(context: Context, book: Book): Promise<BookChapter[]> {
    const bookUrl = book.contentPath ?? '';
    if (bookUrl.length === 0) {
      throw new Error('本地正文缺失，无法导出');
    }
    // 从 Android 备份恢复回来的书只有书目与章节行、正文文件并不在盘上。
    // 不探这一步，readChapter 会把 fileIo 的 ENOENT 原样抛到界面上，用户看到的是一串星号路径。
    let bodyExists = false;
    try {
      bodyExists = fileIo.accessSync(bookUrl);
    } catch (error) {
      bodyExists = false;
    }
    if (!bodyExists) {
      throw new Error('本地正文文件不在了，无法导出；重新导入原书文件后再试');
    }
    return await BookRepository.getChapterList(context, bookUrl);
  }

  /**
   * 批2（:471）：范围表达式 → 章节列表。
   * 语义照 ExportBookService.kt:988-1008：逗号分段，每段可写 a 或 a-b，用户输入是 1 起，
   * 越界静默剔除（:788），left > right 的段整段跳过并记日志。
   */
  private static parseScope(spec: string, chapters: BookChapter[]): BookChapter[] {
    const picked: BookChapter[] = [];
    const seen: Set<number> = new Set<number>();
    const segments = spec.split(',');
    for (let index = 0; index < segments.length; index++) {
      const segment = (segments[index] ?? '').trim();
      if (segment.length === 0) { continue; }
      const bounds = segment.split('-');
      const leftText = (bounds[0] ?? '').trim();
      const rightText = bounds.length > 1 ? (bounds[1] ?? '').trim() : '';
      const left = Number(leftText);
      if (leftText.length === 0 || !Number.isFinite(left)) { continue; }
      const right = rightText.length === 0 ? left : Number(rightText);
      if (!Number.isFinite(right)) { continue; }
      if (left > right) {
        AppLog.put(`范围表达式无效 : ${segment}; left > right`);
        continue;
      }
      for (let one = left; one <= right; one++) {
        const position = Math.floor(one) - 1;
        if (position < 0 || position >= chapters.length) { continue; }
        if (seen.has(position)) { continue; }
        seen.add(position);
        const chapter = chapters[position];
        if (chapter !== undefined) { picked.push(chapter); }
      }
    }
    return picked;
  }

  /** 批2（:471）：第一卷沿用「书名.epub」，第二卷起「书名-2.epub」，与上游 getExportFileName 同形。 */
  private static volumeFileBase(title: string, volumeIndex: number): string {
    const base = EpubExporter.buildFileName(title).replace(/\.epub$/, '');
    return volumeIndex <= 1 ? `${base}.epub` : `${base}-${volumeIndex}.epub`;
  }

  /**
   * 把给定的一批章节打成一个 EPUB。exportBook 传「全部章节」，分卷导出传「一卷的章节」，
   * 两者共用这一份打包逻辑，避免两条路各写一遍（ZIP 结构、nav、opf 只要有一处不同就会分裂）。
   */
  private static async packVolume(book: Book, volumeChapters: BookChapter[],
    allChapters: BookChapter[]): Promise<ArrayBuffer> {
    // uri → 包内文件名；同一张图被多章引用时只转一次、只写一份。
    const images: Map<string, string> = new Map<string, string>();
    const exportImages: ExportImage[] = [];
    const chapterEntries: EpubZipEntry[] = [];
    const spineIds: string[] = [];
    const navLines: string[] = [];
    let chapterFileIndex = 0;
    for (let index = 0; index < volumeChapters.length; index++) {
      const chapter = volumeChapters[index];
      if (chapter === undefined) { continue; }
      // 分卷行没有正文文件（上游 isVolume 行在目录里只是一行标题），只在 nav 里留一行文字。
      if (chapter.isVolume) {
        navLines.push(`      <li><span>${EpubExporter.escapeXml(chapter.title)}</span></li>`);
        continue;
      }
      const body = await BookRepository.readChapter(book, chapter.title, chapter.index, undefined, allChapters);
      chapterFileIndex += 1;
      const fileName = `text/chapter-${chapterFileIndex}.xhtml`;
      chapterEntries.push({
        name: `OEBPS/${fileName}`,
        data: EpubExporter.utf8(await EpubExporter.buildChapterXhtml(chapter.title, body, images, exportImages))
      });
      spineIds.push(`ch${chapterFileIndex}`);
      navLines.push(`      <li><a href="${fileName}">${EpubExporter.escapeXml(chapter.title)}</a></li>`);
    }
    if (chapterEntries.length === 0) {
      throw new Error('这本书只有分卷标题，没有可导出的正文');
    }
    const entries: EpubZipEntry[] = [];
    // mimetype 必须是第一条且不压缩：EpubWriter 按条目名把它固定成 STORED。
    entries.push({ name: 'mimetype', data: EpubExporter.utf8('application/epub+zip') });
    entries.push({ name: 'META-INF/container.xml', data: EpubExporter.utf8(EpubExporter.buildContainerXml()) });
    entries.push({ name: 'OEBPS/toc.xhtml', data: EpubExporter.utf8(EpubExporter.buildNavXhtml(navLines)) });
    for (let index = 0; index < chapterEntries.length; index++) {
      const entry = chapterEntries[index];
      if (entry === undefined) { continue; }
      entries.push(entry);
    }
    for (let index = 0; index < exportImages.length; index++) {
      const one = exportImages[index];
      if (one === undefined) { continue; }
      entries.push({ name: `OEBPS/images/${one.fileName}`, data: one.data });
    }
    entries.push({
      name: 'OEBPS/content.opf',
      data: EpubExporter.utf8(EpubExporter.buildOpf(book, spineIds, chapterEntries.length, exportImages))
    });
    const archive = await EpubWriter.build(entries);
    if (EpubWriter.lastFallbackReason.length > 0) {
      console.info(`[EpubExport] deflate 不可用，已整包 STORED：${EpubWriter.lastFallbackReason}`);
    }
    return archive;
  }

  /** 一章一个 xhtml；图片在这里转码进 images/ 并返回可复用的文件名。 */
  private static async buildChapterXhtml(title: string, body: string, images: Map<string, string>,
    exportImages: ExportImage[]): Promise<string> {
    const paragraphs: string[] = [];
    const lines = body.split(/\r\n|\n|\r/);
    for (let index = 0; index < lines.length; index++) {
      const line = lines[index];
      if (line === undefined) { continue; }
      const trimmed = line.trim();
      if (trimmed.length === 0) { continue; }
      const markup = await EpubExporter.withImages(trimmed, images, exportImages);
      if (markup.length === 0) { continue; }
      paragraphs.push(`    <p>${markup}</p>`);
    }
    const heading = EpubExporter.escapeXml(title);
    return [
      '<?xml version="1.0" encoding="UTF-8"?>',
      '<!DOCTYPE html>',
      '<html xmlns="http://www.w3.org/1999/xhtml">',
      '  <head>',
      '    <meta charset="utf-8"/>',
      `    <title>${heading}</title>`,
      '  </head>',
      '  <body>',
      `    <h1>${heading}</h1>`,
      paragraphs.join('\n'),
      '  </body>',
      '</html>',
      ''
    ].join('\n');
  }

  /** 把正文里的图片标记换成 <img src="../images/…"/>；转不出来的图直接跳过，不留破链接。 */
  private static async withImages(text: string, images: Map<string, string>,
    exportImages: ExportImage[]): Promise<string> {
    let result = '';
    let cursor = 0;
    EpubExporter.IMAGE_PATTERN.lastIndex = 0;
    let match = EpubExporter.IMAGE_PATTERN.exec(text);
    while (match !== null) {
      const before = text.substring(cursor, match.index);
      if (before.length > 0) {
        result += EpubExporter.escapeXml(before);
      }
      const uri = match[1] ?? '';
      const fileName = await EpubExporter.imageNameOf(uri, images, exportImages);
      if (fileName.length > 0) {
        result += `<img src="../images/${fileName}" alt=""/>`;
      }
      cursor = match.index + match[0].length;
      match = EpubExporter.IMAGE_PATTERN.exec(text);
    }
    const tail = text.substring(cursor);
    if (tail.length > 0) {
      result += EpubExporter.escapeXml(tail);
    }
    return result;
  }

  /** 同一张图只处理一次：按 uri 记名，重复引用复用同一个文件。 */
  private static async imageNameOf(uri: string, images: Map<string, string>,
    exportImages: ExportImage[]): Promise<string> {
    if (uri.length === 0) { return ''; }
    const known = images.get(uri);
    if (known !== undefined) { return known; }
    const bytes = EpubExporter.readFileBytes(uri);
    if (bytes === undefined) { return ''; }
    // 优先统一转 JPEG（一页一图的书里 PNG 落盘会大 3–5 倍）；
    // 转不出来就按文件头认定的原格式原样写入，扩展名与 media-type 跟着字节走，不留错扩展名的图。
    const jpeg = await EpubExporter.packAsJpeg(uri);
    const ordinal = exportImages.length + 1;
    if (jpeg !== undefined) {
      const name = `img-${ordinal}.jpg`;
      exportImages.push({ fileName: name, data: jpeg, mediaType: 'image/jpeg' });
      images.set(uri, name);
      return name;
    }
    const sniffed = EpubExporter.sniffImage(bytes);
    if (sniffed === undefined) {
      // 认不出格式的字节写进包里只会是破图，直接跳过。
      return '';
    }
    const name = `img-${ordinal}.${sniffed.ext}`;
    exportImages.push({ fileName: name, data: bytes, mediaType: sniffed.mediaType });
    images.set(uri, name);
    return name;
  }

  /** 用 ImagePacker 把图转成 JPEG 字节；解码或编码失败返回 undefined。 */
  private static async packAsJpeg(uri: string): Promise<Uint8Array | undefined> {
    let source: image.ImageSource | undefined;
    let pixelMap: image.PixelMap | undefined;
    let packer: image.ImagePacker | undefined;
    try {
      source = image.createImageSource(uri);
      if (source === undefined) { return undefined; }
      pixelMap = source.createPixelMapSync();
      if (pixelMap === undefined) { return undefined; }
      packer = image.createImagePacker();
      const options: image.PackingOption = { format: 'image/jpeg', quality: 85 };
      // packToData 返回 ArrayBuffer（packing 已废弃），直接就能塞进手写 zip，不必先落临时文件。
      const packed = await packer.packToData(pixelMap, options);
      if (packed === undefined) { return undefined; }
      return new Uint8Array(packed);
    } catch (_) {
      return undefined;
    } finally {
      if (packer !== undefined) { await packer.release(); }
      if (pixelMap !== undefined) { pixelMap.release(); }
      if (source !== undefined) { source.release(); }
    }
  }

  /** 按字节头认图片格式，给扩展名与 media-type。 */
  private static sniffImage(bytes: Uint8Array): SniffedFormat | undefined {
    if (bytes.length >= 3 && (bytes[0] ?? 0) === 0xFF && (bytes[1] ?? 0) === 0xD8 && (bytes[2] ?? 0) === 0xFF) {
      return { ext: 'jpg', mediaType: 'image/jpeg' };
    }
    if (bytes.length >= 8 && (bytes[0] ?? 0) === 0x89 && (bytes[1] ?? 0) === 0x50
      && (bytes[2] ?? 0) === 0x4E && (bytes[3] ?? 0) === 0x47) {
      return { ext: 'png', mediaType: 'image/png' };
    }
    if (bytes.length >= 4 && (bytes[0] ?? 0) === 0x47 && (bytes[1] ?? 0) === 0x49
      && (bytes[2] ?? 0) === 0x46) {
      return { ext: 'gif', mediaType: 'image/gif' };
    }
    if (bytes.length >= 12 && (bytes[0] ?? 0) === 0x52 && (bytes[1] ?? 0) === 0x49
      && (bytes[8] ?? 0) === 0x57 && (bytes[9] ?? 0) === 0x45) {
      return { ext: 'webp', mediaType: 'image/webp' };
    }
    if (bytes.length >= 2 && (bytes[0] ?? 0) === 0x42 && (bytes[1] ?? 0) === 0x4D) {
      return { ext: 'bmp', mediaType: 'image/bmp' };
    }
    return undefined;
  }

  private static readFileBytes(uri: string): Uint8Array | undefined {
    const path = uri.startsWith('file://') ? uri.substring(7) : uri;
    try {
      const file = fileIo.openSync(path, fileIo.OpenMode.READ_ONLY);
      try {
        const size = fileIo.statSync(file.fd).size;
        if (size <= 0) { return undefined; }
        const buffer = new ArrayBuffer(size);
        const read = fileIo.readSync(file.fd, buffer, { length: size });
        return new Uint8Array(buffer, 0, read > 0 ? read : size);
      } finally {
        fileIo.closeSync(file);
      }
    } catch (_) {
      return undefined;
    }
  }

  private static buildContainerXml(): string {
    return [
      '<?xml version="1.0" encoding="UTF-8"?>',
      '<container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">',
      '  <rootfiles>',
      '    <rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/>',
      '  </rootfiles>',
      '</container>',
      ''
    ].join('\n');
  }

  private static buildNavXhtml(navLines: string[]): string {
    return [
      '<?xml version="1.0" encoding="UTF-8"?>',
      '<!DOCTYPE html>',
      '<html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops">',
      '  <head>',
      '    <meta charset="utf-8"/>',
      '    <title>目录</title>',
      '  </head>',
      '  <body>',
      '    <nav epub:type="toc" id="toc">',
      '      <h1>目录</h1>',
      '      <ol>',
      navLines.join('\n'),
      '      </ol>',
      '    </nav>',
      '  </body>',
      '</html>',
      ''
    ].join('\n');
  }

  private static buildOpf(book: Book, spineIds: string[], chapterCount: number,
    exportImages: ExportImage[]): string {
    const manifest: string[] = [
      '    <item id="nav" href="toc.xhtml" media-type="application/xhtml+xml" properties="nav"/>'
    ];
    for (let index = 0; index < chapterCount; index++) {
      manifest.push(`    <item id="ch${index + 1}" href="text/chapter-${index + 1}.xhtml" media-type="application/xhtml+xml"/>`);
    }
    for (let index = 0; index < exportImages.length; index++) {
      const one = exportImages[index];
      if (one === undefined) { continue; }
      manifest.push(`    <item id="img${index + 1}" href="images/${one.fileName}" media-type="${one.mediaType}"/>`);
    }
    const spine: string[] = [];
    for (let index = 0; index < spineIds.length; index++) {
      spine.push(`    <itemref idref="${spineIds[index] ?? ''}"/>`);
    }
    const lines: string[] = [
      '<?xml version="1.0" encoding="UTF-8"?>',
      '<package xmlns="http://www.idpf.org/2007/opf" version="3.0" unique-identifier="bookid">',
      '  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">',
      `    <dc:identifier id="bookid">urn:legado:${EpubExporter.escapeXml(book.id)}</dc:identifier>`,
      `    <dc:title>${EpubExporter.escapeXml(book.title)}</dc:title>`,
      '    <dc:language>zh</dc:language>'
    ];
    if (book.author.length > 0) {
      lines.push(`    <dc:creator>${EpubExporter.escapeXml(book.author)}</dc:creator>`);
    }
    lines.push(`    <meta property="dcterms:modified">${EpubExporter.timestamp()}</meta>`);
    lines.push('  </metadata>');
    lines.push('  <manifest>');
    for (let index = 0; index < manifest.length; index++) {
      lines.push(manifest[index] ?? '');
    }
    lines.push('  </manifest>');
    lines.push('  <spine>');
    for (let index = 0; index < spine.length; index++) {
      lines.push(spine[index] ?? '');
    }
    lines.push('  </spine>');
    lines.push('</package>');
    lines.push('');
    return lines.join('\n');
  }

  /** dcterms:modified 要的是 CCYY-MM-DDThh:mm:ssZ，不能带毫秒。 */
  private static timestamp(): string {
    return `${new Date().toISOString().substring(0, 19)}Z`;
  }

  /** 书名直接当文件名：去掉路径分隔符与常见非法字符，避免保存对话框报错。 */
  private static buildFileName(title: string): string {
    const cleaned = title.replace(/[\\/:*?"<>|]/g, '_').trim();
    const base = cleaned.length > 0 ? cleaned : 'book';
    return `${base}.epub`;
  }

  private static escapeXml(text: string): string {
    return text.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
  }

  private static utf8(text: string): Uint8Array {
    return new Uint8Array(new util.TextEncoder().encodeInto(text));
  }

  /** 走系统保存对话框写二进制；用户取消返回 false。 */
  private static async saveToFile(context: Context, archive: ArrayBuffer, fileName: string): Promise<boolean> {
    const options = new picker.DocumentSaveOptions();
    options.newFileNames = [fileName];
    options.fileSuffixChoices = ['EPUB 电子书|.epub'];
    const uris = await new picker.DocumentViewPicker(context).save(options);
    const uri = uris[0];
    if (uri === undefined) {
      return false;
    }
    const target = fileIo.openSync(uri, fileIo.OpenMode.WRITE_ONLY | fileIo.OpenMode.TRUNC);
    try {
      // 直接写 ArrayBuffer：先转 Uint8Array 再写在这台模拟器上报 13900020（EINVAL）。
      fileIo.writeSync(target.fd, archive);
    } finally {
      fileIo.closeSync(target);
    }
    return true;
  }

  /**
   * 批2（:471）：多卷一次落盘。把全部卷名一起交给保存对话框，用户在同一个目录里拿到多个文件；
   * 返回真正写成功的卷数（用户取消返回 0）。
   */
  private static async saveManyToFiles(context: Context, archives: ArrayBuffer[],
    fileNames: string[]): Promise<number> {
    if (archives.length === 0 || archives.length !== fileNames.length) {
      return 0;
    }
    const options = new picker.DocumentSaveOptions();
    options.newFileNames = fileNames;
    options.fileSuffixChoices = ['EPUB 电子书|.epub'];
    const uris = await new picker.DocumentViewPicker(context).save(options);
    if (uris.length === 0) {
      return 0;
    }
    let written = 0;
    for (let index = 0; index < archives.length; index++) {
      const archive = archives[index];
      const uri = uris[index];
      if (archive === undefined || uri === undefined) { continue; }
      const target = fileIo.openSync(uri, fileIo.OpenMode.WRITE_ONLY | fileIo.OpenMode.TRUNC);
      try {
        fileIo.writeSync(target.fd, archive);
        written += 1;
      } catch (error) {
        AppLog.put(`分卷写入失败：${fileNames[index]} ${(error as Error).message}`);
      } finally {
        fileIo.closeSync(target);
      }
    }
    return written;
  }
}
