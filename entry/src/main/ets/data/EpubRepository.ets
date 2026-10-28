import { fileIo } from '@kit.CoreFileKit';
import zlib from '@ohos.zlib';
import { Book } from '../model/Book';

interface EpubManifestItem {
  id: string;
  href: string;
  mediaType: string;
}

interface EpubChapterText {
  title: string;
  text: string;
}

interface EpubMarkupConversion {
  text: string;
  imageCount: number;
}


/** EPUB 本地解析器：抽取 spine 顺序中的 XHTML 章节，转成原生阅读器可用的纯文本。 */
export class EpubRepository {
  private static readonly maximumCompressedBytes: number = 128 * 1024 * 1024;
  private static readonly maximumExpandedBytes: number = 256 * 1024 * 1024;
  private static readonly maximumTextCharacters: number = 12000000;
  private static readonly maximumChapters: number = 10000;
  private static readonly maximumArchiveEntries: number = 20000;
  private static readonly maximumCentralDirectoryBytes: number = 32 * 1024 * 1024;

  /** 校验兼容备份 ZIP 后再调用系统解压，复用 EPUB 导入的路径与大小防护。 */
  static validateBackupArchive(zipPath: string): void {
    EpubRepository.validateZipEntries(zipPath);
  }

  /** 清理备份导入、导出使用的应用沙箱临时目录。 */
  static async removeBackupWorkDirectory(path: string): Promise<void> {
    await EpubRepository.removeTreeAsync(path);
  }

  static async importFromUri(context: Context, uri: string, fileName: string, bookId: string): Promise<Book> {
    const stagingDirectory = `${context.filesDir}/epub-import/${bookId}`;
    const zipPath = `${stagingDirectory}/${bookId}.zip`;
    const extractedDirectory = `${stagingDirectory}/content`;
    const booksDirectory = `${context.filesDir}/books`;
    const contentPath = `${booksDirectory}/${bookId}.txt`;
    let compressedBytes: number = 0;
    let coverResourcePath: string = '';

    try {
      EpubRepository.ensureDirectory(stagingDirectory);
      EpubRepository.ensureDirectory(booksDirectory);
      const source = fileIo.openSync(uri, fileIo.OpenMode.READ_ONLY);
      try {
        compressedBytes = fileIo.statSync(source.fd).size;
        if (compressedBytes <= 0 || compressedBytes > EpubRepository.maximumCompressedBytes) {
          throw new Error('EPUB 文件为空或超过 128 MB');
        }
        fileIo.copyFileSync(source.fd, zipPath);
      } finally {
        fileIo.closeSync(source);
      }

      EpubRepository.validateZipEntries(zipPath);
      const expandedBytes = await zlib.getOriginalSize(zipPath);
      if (expandedBytes <= 0 || expandedBytes > EpubRepository.maximumExpandedBytes) {
        throw new Error('EPUB 解压后超过 256 MB，已停止导入');
      }

      fileIo.mkdirSync(extractedDirectory, true);
      await zlib.decompressFile(zipPath, extractedDirectory);

      const containerPath = `${extractedDirectory}/META-INF/container.xml`;
      const containerText = fileIo.readTextSync(containerPath);
      const packageRelativePath = EpubRepository.readAttributeValue(containerText, 'rootfile', 'full-path');
      if (packageRelativePath.length === 0) {
        throw new Error('EPUB 缺少 package 文件路径');
      }
      const packagePath = EpubRepository.resolveEpubPath(extractedDirectory, packageRelativePath);
      const packageText = fileIo.readTextSync(packagePath);
      const packageDirectory = EpubRepository.dirname(packageRelativePath);
      const title = EpubRepository.readTagValue(packageText, 'title') || EpubRepository.fileTitle(fileName);
      const author = EpubRepository.readTagValue(packageText, 'creator') || '本地 EPUB';
      let coverUri: string | undefined = undefined;
      try {
        const coverResource = EpubRepository.findCoverResource(packageText, packageDirectory, extractedDirectory);
        coverResourcePath = coverResource;
        if (coverResource.length > 0) {
          const coversDirectory = `${context.filesDir}/covers`;
          EpubRepository.ensureDirectory(coversDirectory);
          const coverPath = `${coversDirectory}/${bookId}.img`;
          const coverFile = fileIo.openSync(coverResource, fileIo.OpenMode.READ_ONLY);
          try {
            fileIo.copyFileSync(coverFile.fd, coverPath);
            coverUri = `file://${coverPath}`;
          } finally {
            fileIo.closeSync(coverFile);
          }
        }
      } catch (_) {
        coverUri = undefined;
      }
      const chapters = EpubRepository.readChapters(packageText, packageDirectory, extractedDirectory, context, bookId, coverResourcePath, coverUri);
      if (chapters.length === 0) {
        throw new Error('EPUB 中没有可阅读的 XHTML 章节');
      }
      if (chapters.length > EpubRepository.maximumChapters) {
        throw new Error('EPUB 章节数超过支持上限');
      }

      const chapterTitles: string[] = [];
      const chapterOffsets: number[] = [];
      const contentSegments: string[] = [];
      let contentLength = 0;
      for (let index = 0; index < chapters.length; index++) {
        const chapter = chapters[index];
        if (chapter === undefined) { continue; }
        chapterTitles.push(chapter.title);
        chapterOffsets.push(contentLength);
        const section = `${chapter.title}\n\n${chapter.text}\n\n`;
        contentSegments.push(section);
        contentLength += section.length;
      }

      const contentFile = fileIo.openSync(contentPath,
        fileIo.OpenMode.WRITE_ONLY | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC);
      try {
        fileIo.writeSync(contentFile.fd, contentSegments.join(''));
      } finally {
        fileIo.closeSync(contentFile);
      }

      return {
        id: bookId,
        title: title,
        author: author,
        category: '本地',
        groupName: '本地未分组',
      groupNames: [],
        chapterTitles: chapterTitles,
        chapterOffsets: chapterOffsets,
        chapterIndex: 0,
        chapterProgress: 0,
        lastChapter: chapterTitles[0] ?? '全文',
        progress: 0,
        coverColor: '#39424B',
        coverMark: title.substring(0, 1) || '书',
        coverUri: coverUri,
        description: EpubRepository.readTagValue(packageText, 'description'),
        chapterCount: chapterTitles.length.toString(),
        contentPath: contentPath,
        format: 'epub',
        fileSizeBytes: compressedBytes,
        readerPositionVersion: 1,
        latestChapterTime: Date.now(),
        isLocal: true
      };
    } catch (error) {
      try {
        fileIo.unlinkSync(contentPath);
      } catch (_) {
      }
      if (error instanceof Error) {
        throw error;
      }
      throw new Error('EPUB 文件损坏或格式不受支持');
    } finally {
      EpubRepository.removeTree(stagingDirectory);
    }
  }

  private static findCoverResource(packageText: string, packageDirectory: string, extractedDirectory: string): string {
    const coverMeta = packageText.match(/<meta\b(?=[^>]*\bname=["']cover["'])([^>]*)\/?\s*>/i);
    const coverId = coverMeta === null ? '' : EpubRepository.readAttribute(coverMeta[1] ?? '', 'content');
    const itemPattern: RegExp = /<item\b([^>]*?)\/?\s*>/gi;
    let itemMatch: RegExpExecArray | null = itemPattern.exec(packageText);
    while (itemMatch !== null) {
      const attributes = itemMatch[1] ?? '';
      const id = EpubRepository.readAttribute(attributes, 'id');
      const properties = EpubRepository.readAttribute(attributes, 'properties');
      const mediaType = EpubRepository.readAttribute(attributes, 'media-type').toLowerCase();
      const isCover = (coverId.length > 0 && id === coverId) || properties.split(/\s+/).includes('cover-image');
      if (isCover && mediaType.startsWith('image/')) {
        const href = EpubRepository.readAttribute(attributes, 'href');
        if (href.length > 0) {
          return EpubRepository.resolveEpubPath(extractedDirectory,
            EpubRepository.joinRelative(packageDirectory, href));
        }
      }
      itemMatch = itemPattern.exec(packageText);
    }
    return '';
  }
  private static readChapters(packageText: string, packageDirectory: string, extractedDirectory: string, context: Context, bookId: string, coverResourcePath: string, coverUri: string | undefined): EpubChapterText[] {
    const manifest: Map<string, EpubManifestItem> = new Map<string, EpubManifestItem>();
    const itemPattern: RegExp = /<item\b([^>]*?)\/?\s*>/gi;
    let itemMatch: RegExpExecArray | null = itemPattern.exec(packageText);
    while (itemMatch !== null) {
      const attributes = itemMatch[1] ?? '';
      const id = EpubRepository.readAttribute(attributes, 'id');
      const href = EpubRepository.readAttribute(attributes, 'href');
      const mediaType = EpubRepository.readAttribute(attributes, 'media-type');
      if (id.length > 0 && href.length > 0) {
        manifest.set(id, { id: id, href: href, mediaType: mediaType });
      }
      itemMatch = itemPattern.exec(packageText);
    }

    const spineStart = packageText.match(/<spine\b[^>]*>/i)?.index ?? -1;
    const spineEnd = spineStart >= 0 ? packageText.indexOf('</spine>', spineStart) : -1;
    if (spineStart < 0 || spineEnd < 0) {
      throw new Error('EPUB 缺少 spine 阅读顺序');
    }
    const spineText = packageText.substring(spineStart, spineEnd);
    const spinePattern: RegExp = /<itemref\b([^>]*?)\/?\s*>/gi;
    let spineMatch: RegExpExecArray | null = spinePattern.exec(spineText);
    const chapters: EpubChapterText[] = [];
    let totalTextCharacters = 0;
    let imageIndex = 0;
    while (spineMatch !== null) {
      const attributes = spineMatch[1] ?? '';
      const idRef = EpubRepository.readAttribute(attributes, 'idref');
      const linear = EpubRepository.readAttribute(attributes, 'linear');
      const item = manifest.get(idRef);
      if (idRef.length === 0 || item === undefined) {
        throw new Error('EPUB spine 引用了不存在的 manifest 章节');
      }
      if (linear.toLowerCase() !== 'no' &&
        (item.mediaType === 'application/xhtml+xml' || item.mediaType === 'text/html')) {
        const chapterRelativePath = EpubRepository.joinRelative(packageDirectory, item.href);
        const chapterPath = EpubRepository.resolveEpubPath(extractedDirectory, chapterRelativePath);
        const chapterDirectory = EpubRepository.dirname(chapterRelativePath);
        let markup: string;
        try {
          markup = fileIo.readTextSync(chapterPath);
        } catch (error) {
          throw new Error(`EPUB 章节资源无法读取：${item.href}`);
        }
        const normalizedHref = item.href.toLowerCase();
        const isCoverPage = normalizedHref.includes('cover') || normalizedHref.includes('titlepage.xhtml');
        let conversion: EpubMarkupConversion;
        if (isCoverPage && coverUri !== undefined) {
          conversion = { text: `[[EPUB_IMAGE:${coverUri}]]`, imageCount: 0 };
        } else {
          conversion = EpubRepository.htmlToReaderText(markup, chapterDirectory, extractedDirectory, context, bookId, coverResourcePath, coverUri, imageIndex);
        }
        imageIndex += conversion.imageCount;
        const text = conversion.text;
        if (text.length > 0) {
          const nameFromMarkup = EpubRepository.readHeading(markup);
          const pathName = EpubRepository.fileTitle(item.href);
          const chapterTitle = pathName.toLowerCase() === 'cover' ? '封面' : nameFromMarkup || pathName || `第${chapters.length + 1}章`;
          const chapterBody = EpubRepository.removeDuplicateHeading(text, chapterTitle);
          totalTextCharacters += chapterBody.length;
          if (totalTextCharacters > EpubRepository.maximumTextCharacters) {
            throw new Error('EPUB 正文过大，超过本地阅读处理上限');
          }
          if (chapters.length >= EpubRepository.maximumChapters) {
            throw new Error('EPUB 章节数超过支持上限');
          }
          chapters.push({ title: chapterTitle, text: chapterBody });
        }
      }
      spineMatch = spinePattern.exec(spineText);
    }
    return chapters;
  }

  private static readAttribute(attributes: string, name: string): string {
    const escapedName = name.replace(/[-]/g, '\\-');
    const pattern = new RegExp(`(?:^|\\s)${escapedName}\\s*=\\s*["']([^"']*)["']`, 'i');
    const match = attributes.match(pattern);
    return match === null ? '' : EpubRepository.decodeXml(match[1] ?? '').trim();
  }

  private static readAttributeValue(xml: string, tagName: string, attributeName: string): string {
    const tagPattern = new RegExp(`<${tagName}\\b([^>]*?)\\/?\\s*>`, 'i');
    const match = xml.match(tagPattern);
    return match === null ? '' : EpubRepository.readAttribute(match[1] ?? '', attributeName);
  }

  private static readTagValue(xml: string, localName: string): string {
    const tagPattern = new RegExp(`<(?:[A-Za-z0-9_-]+:)?${localName}\\b[^>]*>([\\s\\S]*?)<\\/(?:[A-Za-z0-9_-]+:)?${localName}\\s*>`, 'i');
    const match = xml.match(tagPattern);
    return match === null ? '' : EpubRepository.decodeXml(match[1] ?? '').trim();
  }

  private static readHeading(markup: string): string {
    for (const tagName of ['h1', 'h2', 'title']) {
      const heading = markup.match(new RegExp(`<${tagName}\\b[^>]*>([\\s\\S]*?)<\\/${tagName}\\s*>`, 'i'));
      if (heading !== null) {
        const title = EpubRepository.htmlToText(heading[1] ?? '').replace(/\s+/g, ' ').trim();
        if (title.length > 0) { return title; }
      }
    }
    return '';
  }

  static removeDuplicateHeading(text: string, title: string): string {
    const body = text.trim();
    const normalizedTitle = title.replace(/\s+/g, '');
    if (normalizedTitle.length === 0) { return body; }
    const lines = body.split('\n');
    let heading = '';
    // EPUB 标题可能由 h2 内的 br 拆成两行，须按完整标题去重。
    for (let index = 0; index < Math.min(3, lines.length); index++) {
      const line = (lines[index] ?? '').trim();
      if (line.length === 0) { continue; }
      if (line.includes('[[EPUB_IMAGE:')) { break; }
      heading += line.replace(/\s+/g, '');
      if (heading === normalizedTitle) {
        return lines.slice(index + 1).join('\n').trim();
      }
      if (!normalizedTitle.startsWith(heading)) { break; }
    }
    return body;
  }

  private static htmlToReaderText(markup: string, chapterDirectory: string, extractedDirectory: string, context: Context, bookId: string, coverResourcePath: string, coverUri: string | undefined, startImageIndex: number): EpubMarkupConversion {
    const imagePattern: RegExp = /<img\b([^>]*?)\/?\s*>/gi;
    let match: RegExpExecArray | null = imagePattern.exec(markup);
    let cursor = 0;
    let imageIndex = startImageIndex;
    let convertedMarkup = '';
    while (match !== null) {
      convertedMarkup += markup.substring(cursor, match.index);
      const attributes = match[1] ?? '';
      const source = EpubRepository.readAttribute(attributes, 'src');
      if (source.length > 0) {
        try {
          const sourcePath = EpubRepository.resolveEpubPath(extractedDirectory,
            EpubRepository.joinRelative(chapterDirectory, source));
          let imageUri = sourcePath === coverResourcePath ? (coverUri ?? '') : '';
          if (imageUri.length === 0) {
            const imageDirectory = `${context.filesDir}/epub-assets/${bookId}`;
            EpubRepository.ensureDirectory(imageDirectory);
            const imagePath = `${imageDirectory}/${imageIndex}.img`;
            const imageFile = fileIo.openSync(sourcePath, fileIo.OpenMode.READ_ONLY);
            try {
              fileIo.copyFileSync(imageFile.fd, imagePath);
              imageUri = `file://${imagePath}`;
            } finally {
              fileIo.closeSync(imageFile);
            }
          }
          convertedMarkup += `[[EPUB_IMAGE:${imageUri}]]`;
          imageIndex++;
        } catch (_) {
          convertedMarkup += ' ';
        }
      }
      cursor = match.index + match[0].length;
      match = imagePattern.exec(markup);
    }
    convertedMarkup += markup.substring(cursor);
    return { text: EpubRepository.htmlToText(convertedMarkup), imageCount: imageIndex - startImageIndex };
  }

  private static htmlToText(markup: string): string {
    const bodyMatch = markup.match(/<body\b[^>]*>([\s\S]*?)<\/body\s*>/i);
    const body = bodyMatch === null ? markup : bodyMatch[1] ?? '';
    return EpubRepository.decodeXml(body
      .replace(/<!--[\s\S]*?-->/g, ' ')
      .replace(/<(script|style)\b[^>]*>[\s\S]*?<\/\1\s*>/gi, ' ')
      .replace(/&(nbsp|ensp|emsp);/gi, ' ')
      .replace(/&(thinsp|zwnj|zwj);/gi, '')
      .replace(/<br\b[^>]*\/?\s*>/gi, '\n')
      .replace(/<\/?(?:div|p|hr|h[1-6]|article|dd|dl|li)\b[^>]*>/gi, '\n')
      .replace(/<\/?(?:section|blockquote|tr)\b[^>]*>/gi, '\n')
      .replace(/<[^>]+>/g, ''))
      .replace(/[\t\u00A0 ]+/g, ' ')
      .replace(/ *\n */g, '\n')
      .replace(/\n{3,}/g, '\n\n')
      .trim();
  }

  private static decodeXml(text: string): string {
    return text.replace(/&(#x[0-9a-fA-F]+|#\d+|amp|lt|gt|quot|apos|nbsp);/g, (entity: string, value: string) => {
      if (value === 'amp') { return '&'; }
      if (value === 'lt') { return '<'; }
      if (value === 'gt') { return '>'; }
      if (value === 'quot') { return '"'; }
      if (value === 'apos') { return '\''; }
      if (value === 'nbsp') { return ' '; }
      const number = value.startsWith('#x') ? Number.parseInt(value.substring(2), 16) : Number.parseInt(value.substring(1), 10);
      return Number.isFinite(number) && number >= 0 && number <= 0xFFFF ? String.fromCharCode(number) : '';
    });
  }

  private static resolveEpubPath(rootDirectory: string, relativePath: string): string {
    const clean = decodeURIComponent(relativePath.split('#')[0]?.split('?')[0] ?? '').replace(/\\/g, '/');
    if (clean.startsWith('/') || /^[A-Za-z]:/.test(clean)) {
      throw new Error('EPUB 包含不安全的绝对路径');
    }
    const segments: string[] = [];
    for (const segment of clean.split('/')) {
      if (segment.length === 0 || segment === '.') { continue; }
      if (segment === '..') {
        if (segments.length === 0) { throw new Error('EPUB 路径越界'); }
        segments.pop();
      } else {
        segments.push(segment);
      }
    }
    return `${rootDirectory}/${segments.join('/')}`;
  }

  private static joinRelative(directory: string, fileName: string): string {
    return directory.length === 0 ? fileName : `${directory}/${fileName}`;
  }

  private static dirname(path: string): string {
    const slash = path.lastIndexOf('/');
    return slash < 0 ? '' : path.substring(0, slash);
  }

  private static fileTitle(path: string): string {
    const name = path.substring(path.lastIndexOf('/') + 1);
    const dot = name.lastIndexOf('.');
    return dot > 0 ? name.substring(0, dot) : name;
  }

  private static removeTree(path: string): void {
    try {
      const info = fileIo.lstatSync(path);
      if (info.isDirectory()) {
        for (const name of fileIo.listFileSync(path)) {
          const childName = name.startsWith('/') ? name.substring(1) : name;
          EpubRepository.removeTree(`${path}/${childName}`);
        }
        fileIo.rmdirSync(path);
      } else {
        fileIo.unlinkSync(path);
      }
    } catch (_) {
    }
  }

  private static async removeTreeAsync(path: string): Promise<void> {
    try {
      const info = fileIo.lstatSync(path);
      if (info.isDirectory()) {
        const names = fileIo.listFileSync(path);
        for (let index = 0; index < names.length; index++) {
          const name = names[index];
          if (name !== undefined) {
            const childName = name.startsWith('/') ? name.substring(1) : name;
            await EpubRepository.removeTreeAsync(`${path}/${childName}`);
          }
        }
        await fileIo.rmdir(path);
      } else {
        await fileIo.unlink(path);
      }
    } catch (_) {
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
      throw new Error('无法创建 EPUB 工作目录');
    }
  }

  private static validateZipEntries(zipPath: string): void {
    const archive = fileIo.openSync(zipPath, fileIo.OpenMode.READ_ONLY);
    try {
      const archiveSize = fileIo.statSync(archive.fd).size;
      const tailLength = Math.min(archiveSize, 22 + 65535);
      if (tailLength < 22) {
        throw new Error('EPUB ZIP 目录不完整');
      }
      const tail = new ArrayBuffer(tailLength);
      const tailBytes = new DataView(tail);
      const tailPosition = archiveSize - tailLength;
      const tailRead = fileIo.readSync(archive.fd, tail, { offset: tailPosition });
      if (tailRead !== tailLength) {
        throw new Error('无法读取 EPUB ZIP 目录');
      }

      let endRecordOffset = -1;
      for (let offset = tailLength - 22; offset >= 0; offset--) {
        if (tailBytes.getUint32(offset, true) === 0x06054B50) {
          const candidateCommentLength = tailBytes.getUint16(offset + 20, true);
          if (offset + 22 + candidateCommentLength === tailLength) {
            endRecordOffset = offset;
            break;
          }
        }
      }
      if (endRecordOffset < 0) {
        throw new Error('EPUB 缺少 ZIP 结束目录');
      }

      const diskNumber = tailBytes.getUint16(endRecordOffset + 4, true);
      const directoryDisk = tailBytes.getUint16(endRecordOffset + 6, true);
      const diskEntries = tailBytes.getUint16(endRecordOffset + 8, true);
      const entryCount = tailBytes.getUint16(endRecordOffset + 10, true);
      const directorySize = tailBytes.getUint32(endRecordOffset + 12, true);
      const directoryOffset = tailBytes.getUint32(endRecordOffset + 16, true);
      const commentLength = tailBytes.getUint16(endRecordOffset + 20, true);
      const endRecordPosition = tailPosition + endRecordOffset;

      if (endRecordOffset + 22 + commentLength !== tailLength ||
        diskNumber !== 0 || directoryDisk !== 0 || diskEntries !== entryCount) {
        throw new Error('EPUB ZIP 分卷格式或结束目录无效');
      }
      if (entryCount === 0xFFFF || directorySize === 0xFFFFFFFF || directoryOffset === 0xFFFFFFFF) {
        throw new Error('暂不支持 ZIP64 EPUB');
      }
      if (entryCount === 0 || entryCount > EpubRepository.maximumArchiveEntries ||
        directorySize > EpubRepository.maximumCentralDirectoryBytes ||
        directoryOffset + directorySize > endRecordPosition) {
        throw new Error('EPUB ZIP 条目数量或目录大小超出支持范围');
      }

      const fixedHeader = new ArrayBuffer(46);
      const headerView = new DataView(fixedHeader);
      let entryOffset = directoryOffset;
      const directoryEnd = directoryOffset + directorySize;
      let expandedTotal = 0;
      for (let index = 0; index < entryCount; index++) {
        if (entryOffset + 46 > directoryEnd ||
          fileIo.readSync(archive.fd, fixedHeader, { offset: entryOffset }) !== 46 ||
          headerView.getUint32(0, true) !== 0x02014B50) {
          throw new Error('EPUB ZIP 中央目录条目损坏');
        }

        const flags = headerView.getUint16(8, true);
        const compressedSize = headerView.getUint32(20, true);
        const expandedSize = headerView.getUint32(24, true);
        const nameLength = headerView.getUint16(28, true);
        const extraLength = headerView.getUint16(30, true);
        const entryCommentLength = headerView.getUint16(32, true);
        const externalAttributes = headerView.getUint32(38, true);
        const recordLength = 46 + nameLength + extraLength + entryCommentLength;
        if (nameLength === 0 || entryOffset + recordLength > directoryEnd) {
          throw new Error('EPUB ZIP 文件名或条目长度无效');
        }
        if ((flags & 0x0001) !== 0 || compressedSize === 0xFFFFFFFF || expandedSize === 0xFFFFFFFF) {
          throw new Error('EPUB ZIP 加密条目或 ZIP64 条目暂不支持');
        }
        const unixFileType = (externalAttributes >>> 16) & 0xF000;
        if (unixFileType === 0xA000) {
          throw new Error('EPUB ZIP 不允许包含符号链接');
        }

        const nameBuffer = new ArrayBuffer(nameLength);
        if (fileIo.readSync(archive.fd, nameBuffer, { offset: entryOffset + 46 }) !== nameLength) {
          throw new Error('无法读取 EPUB ZIP 文件名');
        }
        let entryName = '';
        const nameBytes = new Uint8Array(nameBuffer);
        for (let byteIndex = 0; byteIndex < nameBytes.length; byteIndex++) {
          entryName += String.fromCharCode(nameBytes[byteIndex] ?? 0);
        }
        EpubRepository.validateArchivePath(entryName);

        expandedTotal += expandedSize;
        if (expandedTotal > EpubRepository.maximumExpandedBytes) {
          throw new Error('EPUB 解压后超过 256 MB，已停止导入');
        }
        entryOffset += recordLength;
      }
      if (entryOffset !== directoryEnd) {
        throw new Error('EPUB ZIP 中央目录长度不匹配');
      }
    } finally {
      fileIo.closeSync(archive);
    }
  }

  private static validateArchivePath(entryName: string): void {
    const normalized = entryName.replace(/\\/g, '/');
    if (normalized.length === 0 || normalized.includes('\u0000') || normalized.startsWith('/') ||
      /^[A-Za-z]:/.test(normalized)) {
      throw new Error('EPUB ZIP 包含不安全的绝对路径');
    }
    for (const segment of normalized.split('/')) {
      if (segment === '..') {
        throw new Error('EPUB ZIP 包含路径穿越条目');
      }
    }
  }
}
