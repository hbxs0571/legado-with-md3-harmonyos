import { fileIo } from '@kit.CoreFileKit';
import { pdfService } from '@kit.PDFKit';
import image from '@ohos.multimedia.image';
import { Book } from '../model/Book';

/** PDF 导入结果，与 EPUB / UMD 对称：正文标记串已写进 books/<bookId>.txt。 */
export interface PdfImportResult {
  book: Book;
  titles: string[];
  offsets: number[];
  volumes: boolean[];
  content: string;
}

export class PdfRepository {
  /** 与上游 PdfFile.kt:31 的 PAGE_SIZE=10 同值：每 10 页切一段。 */
  private static readonly PAGE_SIZE: number = 10;

  static async importFromUri(context: Context, uri: string, fileName: string,
    bookId: string, title: string): Promise<PdfImportResult> {
    // P1：这台模拟器没有 PDFKit 能力，进 PDF 分支前先判能力。
    // 缺能力时立刻抛可读错误，交给导入流程既有的失败分支，绝不走到 new PdfDocument() 的 TypeError。
    if (!canIUse('SystemCapability.OfficeService.PDFService.Core')) {
      throw new Error('这台设备不支持 PDF 渲染（缺少 PDFKit 能力），暂时打不开 PDF');
    }
    const stagingDirectory = `${context.filesDir}/pdf-import/${bookId}`;
    const pdfPath = `${stagingDirectory}/${bookId}.pdf`;
    const booksDirectory = `${context.filesDir}/books`;
    const contentPath = `${booksDirectory}/${bookId}.txt`;
    const pagesDirectory = `${context.filesDir}/pdf-pages/${bookId}`;
    const coversDirectory = `${context.filesDir}/covers`;
    const coverPath = `${coversDirectory}/${bookId}.img`;

    try {
      // 重复导入先清掉上一轮落盘的页图，避免 pdf-pages/<bookId> 逐次叠加（与 E15 同口径）。
      PdfRepository.clearAssets(context, bookId);
      PdfRepository.ensureDirectory(stagingDirectory);
      PdfRepository.ensureDirectory(booksDirectory);
      PdfRepository.ensureDirectory(coversDirectory);
      PdfRepository.ensureDirectory(pagesDirectory);
      const source = fileIo.openSync(uri, fileIo.OpenMode.READ_ONLY);
      try {
        fileIo.copyFileSync(source.fd, pdfPath);
      } finally {
        fileIo.closeSync(source);
      }

      const pageCount = await PdfRepository.renderPages(pdfPath, pagesDirectory, coverPath);

      const chapterCount = Math.ceil(pageCount / PdfRepository.PAGE_SIZE);
      const titles: string[] = [];
      const offsets: number[] = [];
      const volumes: boolean[] = [];
      const contentSegments: string[] = [];
      let contentLength = 0;
      for (let chapterIndex = 0; chapterIndex < chapterCount; chapterIndex++) {
        const startPage = chapterIndex * PdfRepository.PAGE_SIZE;
        const endPage = Math.min(pageCount, startPage + PdfRepository.PAGE_SIZE);
        const lines: string[] = [];
        for (let page = startPage; page < endPage; page++) {
          // 复用现有 [[EPUB_IMAGE:uri]] 标记，阅读排版层把它塞进图片流（见 LocalTextSemantics.ets:58）。
          lines.push(`[[EPUB_IMAGE:file://${pagesDirectory}/${page}.img]]`);
        }
        const chapterTitle = `分段_${chapterIndex + 1}`;
        titles.push(chapterTitle);
        offsets.push(contentLength);
        volumes.push(false);
        const section = `${chapterTitle}\n\n${lines.join('\n')}\n\n`;
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
        author: '',
        // 上游本地书导入时 kind 是空的，标签由 `upKind()` 现算（格式名 + 文件大小 + 字数）。
      // 本地原来把 kind 写死成「本地」，详情页标签行就多出一个上游没有的「本地」。
      category: '',
        groupName: '本地未分组',
        groupNames: [],
        chapterIndex: 0,
        chapterProgress: 0,
        lastChapter: titles[0] ?? '全文',
        progress: 0,
        coverUri: `file://${coverPath}`,
        description: '',
        chapterCount: chapterCount.toString(),
        contentPath: contentPath,
        format: 'pdf',
        bookType: 'image',
        latestChapterTime: Date.now(),
        isLocal: true
      };
      return {
        book: book,
        titles: titles,
        offsets: offsets,
        content: contentSegments.join(''),
        volumes: volumes
      };
    } catch (error) {
      try {
        fileIo.unlinkSync(contentPath);
      } catch (_) {
      }
      if (error instanceof Error) {
        throw error;
      }
      throw new Error('PDF 文件损坏或格式不受支持');
    } finally {
      PdfRepository.removeTree(stagingDirectory);
    }
  }

  /** 渲完所有页并落盘；返回页数。loadDocument 只调一次，releaseDocument 放 finally。 */
  private static async renderPages(pdfPath: string, pagesDirectory: string,
    coverPath: string): Promise<number> {
    const doc = new pdfService.PdfDocument();
    try {
      const parsed = doc.loadDocument(pdfPath);
      if (parsed === pdfService.ParseResult.PARSE_ERROR_PASSWORD) {
        // 与上游同路：加密就失败，不弹密码框。
        throw new Error('这本 PDF 有打开密码，暂不支持');
      }
      if (parsed !== pdfService.ParseResult.PARSE_SUCCESS) {
        throw new Error('PDF 文件损坏或格式不受支持');
      }
      const pageCount = doc.getPageCount();
      if (pageCount <= 0) {
        throw new Error('这本 PDF 没有可阅读的页面');
      }
      for (let index = 0; index < pageCount; index++) {
        const page = doc.getPage(index);
        // 落盘保留页面原始渲染分辨率：铺满屏宽由阅读排版层负责，这里不再缩放以免损失小字清晰度。
        const pixelMap = page.getPagePixelMap();
        const pagePath = `${pagesDirectory}/${index}.img`;
        try {
          await PdfRepository.writePageImage(pixelMap, pagePath);
          if (index === 0) {
            // 封面用第 0 页，同一 PixelMap 再编码一份，避免依赖 copyFileSync 的路径重载。
            await PdfRepository.writePageImage(pixelMap, coverPath);
          }
        } finally {
          // 一页渲完就丢掉 PixelMap 与 PdfPage 句柄，100 页全攒住会 OOM。
          try {
            await pixelMap.release();
          } catch (_) {
          }
          page.release();
        }
      }
      return pageCount;
    } finally {
      doc.releaseDocument();
    }
  }

  /** 用 createImagePacker 把页图编码成 JPEG 质量 85 落盘（PNG 会大 3-5 倍）。 */
  private static async writePageImage(pixelMap: image.PixelMap, targetPath: string): Promise<void> {
    const packer = image.createImagePacker();
    const target = fileIo.openSync(targetPath,
      fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC);
    try {
      await packer.packToFile(pixelMap, target.fd, { format: 'image/jpeg', quality: 85 });
    } finally {
      fileIo.closeSync(target);
      await packer.release();
    }
  }

  /** 清掉一本书落盘的页图。删书、重导入两个时机调用；目录不存在时静默返回。 */
  static clearAssets(context: Context, bookId: string): void {
    PdfRepository.removeTree(`${context.filesDir}/pdf-pages/${bookId}`);
  }

  /** 启动清扫 pdf-pages 下不属于任何在架书 id 的孤儿目录；空集合不删，防误删在用图。 */
  static async clearOrphanAssets(context: Context, liveBookIds: string[]): Promise<void> {
    if (liveBookIds.length === 0) { return; }
    const pagesRoot = `${context.filesDir}/pdf-pages`;
    let names: string[] = [];
    try {
      names = fileIo.listFileSync(pagesRoot);
    } catch (_) {
      return;
    }
    const live: Set<string> = new Set<string>();
    for (const id of liveBookIds) {
      live.add(id);
    }
    for (const name of names) {
      const dirName = name.startsWith('/') ? name.substring(1) : name;
      if (dirName.length === 0 || live.has(dirName)) { continue; }
      await PdfRepository.removeTreeAsync(`${pagesRoot}/${dirName}`);
    }
  }

  private static removeTree(path: string): void {
    try {
      const info = fileIo.lstatSync(path);
      if (info.isDirectory()) {
        for (const name of fileIo.listFileSync(path)) {
          const childName = name.startsWith('/') ? name.substring(1) : name;
          PdfRepository.removeTree(`${path}/${childName}`);
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
            await PdfRepository.removeTreeAsync(`${path}/${childName}`);
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
      throw new Error('无法创建 PDF 工作目录');
    }
  }
}
