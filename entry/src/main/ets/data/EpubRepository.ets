import { fileIo } from '@kit.CoreFileKit';
import zlib from '@ohos.zlib';
import { Book } from '../model/Book';

/**
 * EPUB 导入结果。
 *
 * 章节行由 BookRepository 统一生成（url 的 md5 规则、字节偏移换算都在那边），
 * 所以这里只把「标题 + 字符偏移 + 拼好的正文」交出去，不自己造章节对象。
 */
export interface EpubImportResult {
  book: Book;
  titles: string[];
  offsets: number[];
  content: string;
  /** 每章是否为卷标题，供 buildChapterRows 写入 chapters.isVolume。 */
  volumes: boolean[];
  /** 目录树的递归深度，供 buildChapterRows 写入 chapters.tocLevel（任意层级）。 */
  tocLevels: number[];
  /** 每章的片段/nextUrl 几何信息，供 buildChapterRows 写入 chapters 对应列（批 3 E3/E4）。 */
  chapterMeta: EpubChapterMeta[];
}

/** 目录项的章节几何信息，写入 chapters.resourceUrl / startFragmentId / endFragmentId / variable。 */
export interface EpubChapterMeta {
  /** 本章对应的资源路径（相对 OPF 解压根），纯目录项为空串。 */
  resourceUrl: string;
  /** 本章正文的起始片段 id；无片段时为 undefined。 */
  startFragmentId?: string;
  /** 本章正文的结束片段 id（下一章的起始片段）；无则为 undefined。 */
  endFragmentId?: string;
  /** 下一章的 url（相对 OPF，含 #片段）；最后一章为 undefined。 */
  nextUrl?: string;
}

interface EpubManifestItem {
  id: string;
  href: string;
  mediaType: string;
}

/** 目录树节点：NCX 的 navPoint 或 nav.xhtml 的 li，children 为空表示普通章节。 */
interface EpubTocEntry {
  title: string;
  /** 相对 OPF 的 href，含 #片段；纯目录项（无资源）为空串。 */
  href: string;
  /** 递归深度，从 0 开始。 */
  level: number;
  children: EpubTocEntry[];
}

/** spine 中一个 XHTML 资源及其转好的纯文本，按目录建章与退回平铺共用。 */
interface EpubSpineResource {
  href: string;
  relativePath: string;
  fullPath: string;
  /** 现有逻辑推断的章名（封面 / h1 / 文件名 / 第N章）。 */
  title: string;
  /** markup 里的 <title>/h1/h2，卷首页优先用它。 */
  heading: string;
  text: string;
  /** 图片已替换成 EPUB_IMAGE 标记、但仍保留标签与 id 的中间态 markup，供按 #片段 切片。 */
  markup: string;
  isCoverPage: boolean;
}

interface EpubChapterText {
  title: string;
  text: string;
  /** 本章对应的资源路径（相对 OPF 解压根），纯目录项为空串。 */
  resourceHref: string;
  /** 是否为卷标题（有子项，或纯目录项）。 */
  isVolume: boolean;
  /** 递归深度。 */
  tocLevel: number;
  /** 本章正文的起始片段 id；无片段时为 undefined。 */
  startFragmentId?: string;
  /** 本章正文的结束片段 id；无则为 undefined。 */
  endFragmentId?: string;
  /** 下一章的 url；最后一章为 undefined。 */
  nextUrl?: string;
}

interface EpubMarkupConversion {
  text: string;
  imageCount: number;
  /** 图片替换后、htmlToText 之前的中间态 markup，保留 id 供片段切片。 */
  markup: string;
}

/** nav.xhtml 解析时的栈帧：一个 <ol> 的条目列表与层级。 */
interface EpubNavFrame {
  list: EpubTocEntry[];
  level: number;
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

  static async importFromUri(context: Context, uri: string, fileName: string,
    bookId: string): Promise<EpubImportResult> {
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
      const chapterVolumes: boolean[] = [];
      const chapterTocLevels: number[] = [];
      const chapterMeta: EpubChapterMeta[] = [];
      const contentSegments: string[] = [];
      let contentLength = 0;
      for (let index = 0; index < chapters.length; index++) {
        const chapter = chapters[index];
        if (chapter === undefined) { continue; }
        chapterTitles.push(chapter.title);
        chapterOffsets.push(contentLength);
        chapterVolumes.push(chapter.isVolume);
        chapterTocLevels.push(chapter.tocLevel);
        chapterMeta.push({
          resourceUrl: chapter.resourceHref,
          startFragmentId: chapter.startFragmentId,
          endFragmentId: chapter.endFragmentId,
          nextUrl: chapter.nextUrl
        });
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

      const book: Book = {
        id: bookId,
        title: title,
        author: author,
        category: '本地',
        groupName: '本地未分组',
        groupNames: [],
        chapterIndex: 0,
        chapterProgress: 0,
        lastChapter: chapterTitles[0] ?? '全文',
        progress: 0,
        coverUri: coverUri,
        description: EpubRepository.readTagValue(packageText, 'description'),
        chapterCount: chapterTitles.length.toString(),
        contentPath: contentPath,
        format: 'epub',
        latestChapterTime: Date.now(),
        isLocal: true
      };
      return {
        book: book,
        titles: chapterTitles,
        offsets: chapterOffsets,
        content: contentSegments.join(''),
        volumes: chapterVolumes,
        tocLevels: chapterTocLevels,
        chapterMeta: chapterMeta
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
  /** 按 spine 顺序收集 XHTML 资源并转成纯文本，作为目录建章与退回平铺共用的正文来源。 */
  private static buildSpineResources(packageText: string, packageDirectory: string,
    extractedDirectory: string, context: Context, bookId: string,
    coverResourcePath: string, coverUri: string | undefined): EpubSpineResource[] {
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
    const resources: EpubSpineResource[] = [];
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
          const coverMarkup = `[[EPUB_IMAGE:${coverUri}]]`;
          conversion = { text: coverMarkup, imageCount: 0, markup: coverMarkup };
        } else {
          conversion = EpubRepository.htmlToReaderText(markup, chapterDirectory, extractedDirectory, context, bookId, coverResourcePath, coverUri, imageIndex);
        }
        imageIndex += conversion.imageCount;
        const text = conversion.text;
        if (text.length > 0) {
          const nameFromMarkup = EpubRepository.readHeading(markup);
          const pathName = EpubRepository.fileTitle(item.href);
          const chapterTitle = pathName.toLowerCase() === 'cover' ? '封面' : nameFromMarkup || pathName || `第${resources.length + 1}章`;
          const chapterBody = EpubRepository.removeDuplicateHeading(text, chapterTitle);
          totalTextCharacters += chapterBody.length;
          if (totalTextCharacters > EpubRepository.maximumTextCharacters) {
            throw new Error('EPUB 正文过大，超过本地阅读处理上限');
          }
          if (resources.length >= EpubRepository.maximumChapters) {
            throw new Error('EPUB 章节数超过支持上限');
          }
          resources.push({
            href: item.href,
            relativePath: chapterRelativePath,
            fullPath: chapterPath,
            title: chapterTitle,
            heading: nameFromMarkup,
            text: chapterBody,
            markup: conversion.markup,
            isCoverPage: isCoverPage
          });
        }
      }
      spineMatch = spinePattern.exec(spineText);
    }
    return resources;
  }

  /** 目录优先：NCX/nav 解析成功就按树建章，失败才退回 spine 平铺。 */
  private static readChapters(packageText: string, packageDirectory: string,
    extractedDirectory: string, context: Context, bookId: string,
    coverResourcePath: string, coverUri: string | undefined): EpubChapterText[] {
    const resources = EpubRepository.buildSpineResources(packageText, packageDirectory,
      extractedDirectory, context, bookId, coverResourcePath, coverUri);
    const toc = EpubRepository.parseTocEntries(packageText, packageDirectory, extractedDirectory);
    return toc.length > 0
      ? EpubRepository.chaptersFromToc(toc, resources, packageDirectory, extractedDirectory)
      : EpubRepository.chaptersFromSpine(resources);
  }

  /** spine 平铺：无目录（或目录解析失败）时，每个 XHTML 资源一章，无卷、层级全 0。 */
  private static chaptersFromSpine(resources: EpubSpineResource[]): EpubChapterText[] {
    const chapters: EpubChapterText[] = [];
    for (const resource of resources) {
      chapters.push({
        title: resource.title,
        text: resource.text,
        resourceHref: resource.relativePath,
        isVolume: false,
        tocLevel: 0
      });
    }
    return chapters;
  }

  /** 取 href 的 # 之后部分（片段 id）；无片段返回空串。 */
  private static fragmentOf(href: string): string {
    const hash = href.indexOf('#');
    return hash < 0 ? '' : href.substring(hash + 1);
  }

  /** 找 id 为 targetId 的元素在 markup 里的起始下标；找不到返回 -1。属性顺序不固定，按 id 属性匹配。 */
  private static findElementStartByFragment(html: string, targetId: string): number {
    if (targetId.length === 0) { return -1; }
    const pattern: RegExp = /<([a-zA-Z][a-zA-Z0-9]*)\b[^>]*?\bid\s*=\s*["']([^"']*)["'][^>]*>/g;
    let match: RegExpExecArray | null = pattern.exec(html);
    while (match !== null) {
      if ((match[2] ?? '') === targetId) { return match.index; }
      match = pattern.exec(html);
    }
    return -1;
  }

  /** 同一 markup 被多章引用时按 #片段 顺序切片；首章可无片段（从文件头 0 开始），任一定位失败返回空数组，由调用方退回整篇。 */
  private static sliceMarkupByFragments(markup: string, fragments: string[]): string[] {
    const positions: number[] = [];
    for (let i = 0; i < fragments.length; i++) {
      const fragment = fragments[i] ?? '';
      if (i === 0 && fragment.length === 0) {
        // 上游 getBody 首章 startFragmentId 为 null：正文从文件头开始
        positions.push(0);
        continue;
      }
      const pos = EpubRepository.findElementStartByFragment(markup, fragment);
      if (pos < 0) { return []; }
      positions.push(pos);
    }
    for (let i = 1; i < positions.length; i++) {
      if ((positions[i] ?? 0) <= (positions[i - 1] ?? 0)) { return []; }
    }
    const slices: string[] = [];
    for (let i = 0; i < positions.length; i++) {
      const start = positions[i] ?? 0;
      const end = i + 1 < positions.length ? (positions[i + 1] ?? markup.length) : markup.length;
      slices.push(markup.substring(start, end));
    }
    return slices;
  }

  /** 按目录树建章：卷首页 + 目录项，带 isVolume / tocLevel / 片段几何信息。 */
  private static chaptersFromToc(toc: EpubTocEntry[], resources: EpubSpineResource[],
    packageDirectory: string, extractedDirectory: string): EpubChapterText[] {
    const flat: EpubTocEntry[] = [];
    EpubRepository.flattenToc(toc, flat);
    const byPath: Map<string, EpubSpineResource> = new Map<string, EpubSpineResource>();
    for (const resource of resources) {
      byPath.set(resource.fullPath, resource);
    }
    const matched: (EpubSpineResource | undefined)[] = [];
    const tocResourcePaths: Set<string> = new Set<string>();
    for (const entry of flat) {
      const resource = EpubRepository.matchTocResource(entry.href, packageDirectory,
        extractedDirectory, byPath, resources);
      matched.push(resource);
      if (resource !== undefined) { tocResourcePaths.add(resource.fullPath); }
    }
    // 目录项一个都匹配不到 spine 资源时，按目录建章只会得到一堆空章，退回平铺更稳。
    if (tocResourcePaths.size === 0) {
      return EpubRepository.chaptersFromSpine(resources);
    }
    let firstTocIndex = -1;
    for (let index = 0; index < resources.length; index++) {
      const resource = resources[index];
      if (resource !== undefined && tocResourcePaths.has(resource.fullPath)) {
        firstTocIndex = index;
        break;
      }
    }

    // 老式 EPUB2 把整卷塞进一个 XHTML、章节只是文件里的 #锚点：同一资源被多个
    // 目录项引用时，在保留 id 的 markup 上按各章片段切片，每章只拿自己那一段，
    // 不再整本重复拼进 .txt（情形 A：导入阶段切好，chapterBody 仍按字节偏移取）。
    const slicedText: Map<number, string> = new Map<number, string>();
    const groupKeys: string[] = [];
    const groupIndices: number[][] = [];
    for (let index = 0; index < flat.length; index++) {
      const resource = matched[index];
      if (resource === undefined) { continue; }
      let gi = groupKeys.indexOf(resource.fullPath);
      if (gi < 0) {
        groupKeys.push(resource.fullPath);
        groupIndices.push([]);
        gi = groupKeys.length - 1;
      }
      const group = groupIndices[gi];
      if (group !== undefined) { group.push(index); }
    }
    for (let gi = 0; gi < groupKeys.length; gi++) {
      const indices = groupIndices[gi] ?? [];
      const fullPath = groupKeys[gi] ?? '';
      if (indices.length < 2) { continue; }
      const resource = byPath.get(fullPath);
      if (resource === undefined) { continue; }
      const fragments: string[] = [];
      for (const idx of indices) {
        fragments.push(EpubRepository.fragmentOf(flat[idx]?.href ?? ''));
      }
      const slices = EpubRepository.sliceMarkupByFragments(resource.markup, fragments);
      // 任一片段定位失败就退回整篇：上游 getElementById 拿到 null 也是退化处理，不抛异常。
      if (slices.length !== indices.length) { continue; }
      for (let k = 0; k < indices.length; k++) {
        const idx = indices[k];
        const entry = flat[idx];
        const title = entry !== undefined && entry.title.length > 0 ? entry.title : resource.title;
        const text = EpubRepository.removeDuplicateHeading(
          EpubRepository.htmlToText(slices[k] ?? ''), title);
        slicedText.set(idx, text);
      }
    }

    const chapters: EpubChapterText[] = [];
    const claimed: Set<string> = new Set<string>();
    // 目录第一项之前、且不在目录里的资源，按顺序补成卷首页；封面页仍优先判「封面」。
    const prefixEnd = firstTocIndex < 0 ? 0 : firstTocIndex;
    const firstHref = flat[0]?.href ?? '';
    for (let index = 0; index < prefixEnd; index++) {
      const resource = resources[index];
      if (resource === undefined || tocResourcePaths.has(resource.fullPath)) { continue; }
      const volumeTitle = resource.isCoverPage ? '封面'
        : (resource.heading.length > 0 ? resource.heading : '--卷首--');
      chapters.push({
        title: volumeTitle,
        text: resource.text,
        resourceHref: resource.relativePath,
        isVolume: false,
        tocLevel: 0,
        nextUrl: firstHref.length > 0 ? firstHref : undefined
      });
      claimed.add(resource.fullPath);
    }
    for (let index = 0; index < flat.length; index++) {
      const entry = flat[index];
      const resource = matched[index];
      if (entry === undefined) { continue; }
      const isVolume = entry.children.length > 0 || entry.href.length === 0;
      const title = entry.title.length > 0 ? entry.title
        : (resource !== undefined ? resource.title : '目录');
      const startFragment = EpubRepository.fragmentOf(entry.href);
      const startFragmentId = startFragment.length > 0 ? startFragment : undefined;
      const nextEntry = flat[index + 1];
      const nextHref = nextEntry?.href ?? '';
      const nextFragment = EpubRepository.fragmentOf(nextHref);
      const endFragmentId = nextFragment.length > 0 ? nextFragment : undefined;
      const nextUrl = nextHref.length > 0 ? nextHref : undefined;
      let text = '';
      let resourceHref = '';
      const sliced = slicedText.get(index);
      if (sliced !== undefined) {
        text = sliced;
        resourceHref = resource !== undefined ? resource.relativePath : '';
      } else if (resource !== undefined && !claimed.has(resource.fullPath)) {
        text = EpubRepository.removeDuplicateHeading(resource.text, title);
        resourceHref = resource.relativePath;
        claimed.add(resource.fullPath);
      }
      chapters.push({
        title: title,
        text: text,
        resourceHref: resourceHref,
        isVolume: isVolume,
        tocLevel: entry.level,
        startFragmentId: startFragmentId,
        endFragmentId: endFragmentId,
        nextUrl: nextUrl
      });
    }
    return chapters;
  }

  /** 目录树深度优先展开，卷标题节点也保留成章。 */
  private static flattenToc(entries: EpubTocEntry[], out: EpubTocEntry[]): void {
    for (const entry of entries) {
      out.push(entry);
      if (entry.children.length > 0) {
        EpubRepository.flattenToc(entry.children, out);
      }
    }
  }

  /** 目录 href -> spine 资源：先按 OPF 相对路径精确匹配，再按文件名兜底。 */
  private static matchTocResource(href: string, packageDirectory: string,
    extractedDirectory: string, byPath: Map<string, EpubSpineResource>,
    resources: EpubSpineResource[]): EpubSpineResource | undefined {
    if (href.length === 0) { return undefined; }
    const clean = href.split('#')[0] ?? href;
    try {
      const full = EpubRepository.resolveEpubPath(extractedDirectory,
        EpubRepository.joinRelative(packageDirectory, clean));
      const exact = byPath.get(full);
      if (exact !== undefined) { return exact; }
    } catch (_) {
    }
    const base = clean.substring(clean.lastIndexOf('/') + 1).toLowerCase();
    for (const resource of resources) {
      const resourceBase = resource.relativePath
        .substring(resource.relativePath.lastIndexOf('/') + 1).toLowerCase();
      if (resourceBase === base) { return resource; }
    }
    return undefined;
  }

  /** 解析 NCX / nav.xhtml 成目录树；任何异常都返回空数组，交由调用方退回 spine 平铺。 */
  private static parseTocEntries(packageText: string, packageDirectory: string,
    extractedDirectory: string): EpubTocEntry[] {
    try {
      const itemPattern: RegExp = /<item\b([^>]*?)\/?\s*>/gi;
      let navHref = '';
      let ncxHref = '';
      const tocId = EpubRepository.readAttributeValue(packageText, 'spine', 'toc');
      let itemMatch: RegExpExecArray | null = itemPattern.exec(packageText);
      while (itemMatch !== null) {
        const attributes = itemMatch[1] ?? '';
        const id = EpubRepository.readAttribute(attributes, 'id');
        const href = EpubRepository.readAttribute(attributes, 'href');
        const mediaType = EpubRepository.readAttribute(attributes, 'media-type');
        const properties = EpubRepository.readAttribute(attributes, 'properties');
        if (properties.split(/\s+/).indexOf('nav') >= 0 && navHref.length === 0) {
          navHref = href;
        }
        if (id.length > 0 && id === tocId && href.length > 0 && ncxHref.length === 0) {
          ncxHref = href;
        }
        if (mediaType === 'application/x-dtbncx+xml' && ncxHref.length === 0) {
          ncxHref = href;
        }
        itemMatch = itemPattern.exec(packageText);
      }
      // EPUB3 的 nav.xhtml 优先；属性取值一律走 readAttribute，不假设顺序。
      if (navHref.length > 0) {
        const navPath = EpubRepository.resolveEpubPath(extractedDirectory,
          EpubRepository.joinRelative(packageDirectory, navHref));
        const navEntries = EpubRepository.parseNav(fileIo.readTextSync(navPath));
        if (navEntries.length > 0) { return navEntries; }
      }
      if (ncxHref.length > 0) {
        const ncxPath = EpubRepository.resolveEpubPath(extractedDirectory,
          EpubRepository.joinRelative(packageDirectory, ncxHref));
        const ncxEntries = EpubRepository.parseNcx(fileIo.readTextSync(ncxPath));
        if (ncxEntries.length > 0) { return ncxEntries; }
      }
    } catch (_) {
    }
    return [];
  }

  /** EPUB2 NCX：扫描 navPoint 开闭标签用栈维护层级，navLabel 取标题、content 取 src。 */
  private static parseNcx(ncxText: string): EpubTocEntry[] {
    const root: EpubTocEntry[] = [];
    const stack: EpubTocEntry[] = [];
    const tokenPattern: RegExp = /<navPoint\b[^>]*>|<\/navPoint\s*>|<navLabel\b[^>]*>([\s\S]*?)<\/navLabel\s*>|<content\b([^>]*?)\/?\s*>/gi;
    let match: RegExpExecArray | null = tokenPattern.exec(ncxText);
    while (match !== null) {
      const token = match[0].toLowerCase();
      if (token.startsWith('<navpoint')) {
        const entry: EpubTocEntry = { title: '', href: '', level: stack.length, children: [] };
        const parent = stack[stack.length - 1];
        if (parent !== undefined) { parent.children.push(entry); } else { root.push(entry); }
        // 自闭 <navPoint .../> 不入栈；其余等 </navPoint> 出栈。
        if (!/\/\s*>$/.test(match[0])) { stack.push(entry); }
      } else if (token.startsWith('</navpoint')) {
        stack.pop();
      } else if (token.startsWith('<navlabel')) {
        const current = stack[stack.length - 1];
        if (current !== undefined) {
          current.title = EpubRepository.htmlToText(match[1] ?? '').replace(/\s+/g, ' ').trim();
        }
      } else if (token.startsWith('<content')) {
        const current = stack[stack.length - 1];
        if (current !== undefined) {
          current.href = EpubRepository.readAttribute(match[2] ?? '', 'src');
        }
      }
      match = tokenPattern.exec(ncxText);
    }
    return root;
  }

  /** EPUB3 nav.xhtml：取 <nav epub:type="toc">，按 <ol>/<li> 栈维护层级，<a> 取标题与 href。 */
  private static parseNav(navText: string): EpubTocEntry[] {
    let inner = '';
    const navPattern: RegExp = /<nav\b([^>]*)>([\s\S]*?)<\/nav\s*>/gi;
    let navMatch: RegExpExecArray | null = navPattern.exec(navText);
    while (navMatch !== null) {
      if (inner.length === 0) { inner = navMatch[2] ?? ''; }
      const attributes = navMatch[1] ?? '';
      if (EpubRepository.readAttribute(attributes, 'type').toLowerCase() === 'toc' ||
        EpubRepository.readAttribute(attributes, 'epub:type').toLowerCase() === 'toc') {
        inner = navMatch[2] ?? '';
        break;
      }
      navMatch = navPattern.exec(navText);
    }
    if (inner.length === 0) { return []; }
    const root: EpubTocEntry[] = [];
    const stack: EpubNavFrame[] = [];
    let currentLi: EpubTocEntry | undefined = undefined;
    const tokenPattern: RegExp = /<ol\b[^>]*>|<\/ol\s*>|<li\b[^>]*>|<\/li\s*>|<a\b([^>]*)>([\s\S]*?)<\/a\s*>/gi;
    let match: RegExpExecArray | null = tokenPattern.exec(inner);
    while (match !== null) {
      const token = match[0].toLowerCase();
      if (token.startsWith('<ol') && !token.startsWith('</')) {
        let list: EpubTocEntry[] = root;
        let level: number = 0;
        if (stack.length === 0) {
          list = root;
          level = 0;
        } else {
          const parentFrame = stack[stack.length - 1];
          list = currentLi !== undefined ? currentLi.children : root;
          level = parentFrame !== undefined ? parentFrame.level + 1 : 1;
        }
        const frame: EpubNavFrame = { list: list, level: level };
        stack.push(frame);
      } else if (token.startsWith('</ol')) {
        stack.pop();
      } else if (token.startsWith('<li') && !token.startsWith('</')) {
        const frame = stack[stack.length - 1];
        if (frame !== undefined) {
          const entry: EpubTocEntry = { title: '', href: '', level: frame.level, children: [] };
          frame.list.push(entry);
          currentLi = entry;
        }
      } else if (token.startsWith('</li')) {
        currentLi = undefined;
      } else if (token.startsWith('<a')) {
        if (currentLi !== undefined) {
          currentLi.href = EpubRepository.readAttribute(match[1] ?? '', 'href');
          currentLi.title = EpubRepository.htmlToText(match[2] ?? '').replace(/\s+/g, ' ').trim();
        }
      }
      match = tokenPattern.exec(inner);
    }
    return root;
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

  static removeDuplicateHeading(text: string, title: string, maxLines: number = 3): string {
    const body = text.trim();
    const normalizedTitle = title.replace(/\s+/g, '');
    if (normalizedTitle.length === 0) { return body; }
    const lines = body.split('\n');
    let heading = '';
    // EPUB 标题可能由 h2 内的 br 拆成两行，须按完整标题去重。
    // 默认扫前 3 行（导入期）；批 4 的 h 标签开关传 10，放宽到跨空行的多层标题。
    for (let index = 0; index < Math.min(maxLines, lines.length); index++) {
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
    // E9：Calibre 旧书用 <svg><image xlink:href="..."/></svg> 包图，本地只认 <img>。
    // 先把每个 <image> 改写成等价的 <img src="...">，直接复用下面的既有 <img> 循环，不另起一套逻辑。
    const svgPattern: RegExp = /<image\b([^>]*?)\/?\s*>/gi;
    let normalized = '';
    let svgCursor = 0;
    let svgMatch: RegExpExecArray | null = svgPattern.exec(markup);
    while (svgMatch !== null) {
      normalized += markup.substring(svgCursor, svgMatch.index);
      const href = EpubRepository.readAttribute(svgMatch[1] ?? '', 'xlink:href');
      normalized += href.length > 0 ? `<img src="${href}"/>` : ' ';
      svgCursor = svgMatch.index + svgMatch[0].length;
      svgMatch = svgPattern.exec(markup);
    }
    normalized += markup.substring(svgCursor);
    const imagePattern: RegExp = /<img\b([^>]*?)\/?\s*>/gi;
    let match: RegExpExecArray | null = imagePattern.exec(normalized);
    let cursor = 0;
    let imageIndex = startImageIndex;
    let convertedMarkup = '';
    // E5：cover.jpeg 在正文里可能重复出现，只保留第一次，后续整张跳过（上游 img[src=cover.jpeg] 从第二个起删）。
    let seenCover = false;
    while (match !== null) {
      convertedMarkup += normalized.substring(cursor, match.index);
      const attributes = match[1] ?? '';
      const source = EpubRepository.readAttribute(attributes, 'src');
      if (source.length > 0) {
        if (source.toLowerCase().includes('cover.jpeg')) {
          if (seenCover) {
            cursor = match.index + match[0].length;
            match = imagePattern.exec(normalized);
            continue;
          }
          seenCover = true;
        }
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
      match = imagePattern.exec(normalized);
    }
    convertedMarkup += normalized.substring(cursor);
    return {
      text: EpubRepository.htmlToText(convertedMarkup),
      imageCount: imageIndex - startImageIndex,
      markup: convertedMarkup
    };
  }

  private static htmlToText(markup: string): string {
    const bodyMatch = markup.match(/<body\b[^>]*>([\s\S]*?)<\/body\s*>/i);
    const body = bodyMatch === null ? markup : bodyMatch[1] ?? '';
    return EpubRepository.decodeXml(body
      .replace(/<!--[\s\S]*?-->/g, ' ')
      .replace(/<(script|style)\b[^>]*>[\s\S]*?<\/\1\s*>/gi, ' ')
      // E5：删 <title> 元素与 display:none 块。后者是有意近似：只认「开标签带 style 属性、
      // 有对应闭标签」的最常见形态，嵌套 / 自闭合 / 属性里换行都认不全，与上游 Jsoup 同量级。
      .replace(/<title\b[^>]*>[\s\S]*?<\/title\s*>/gi, ' ')
      .replace(/<[a-zA-Z][a-zA-Z0-9]*\b[^>]*style\s*=\s*["'][^"']*display\s*:\s*none[^"']*["'][^>]*>[\s\S]*?<\/[a-zA-Z][a-zA-Z0-9]*\s*>/gi, ' ')
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
