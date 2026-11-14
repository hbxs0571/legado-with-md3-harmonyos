import { fileIo } from '@kit.CoreFileKit';
import { util } from '@kit.ArkTS';
import zlib from '@ohos.zlib';
import { Book } from '../model/Book';

/**
 * UMD 导入结果：与 EPUB 对称，只交出拼好的正文与章节几何，
 * 章节行统一由 BookRepository.buildChapterRows 生成，不反向依赖。
 */
export interface UmdImportResult {
  book: Book;
  titles: string[];
  /** 拼接后正文里的累积字符偏移（不是 UMD 原始的 UTF-16LE 字节偏移）。 */
  offsets: number[];
  volumes: boolean[];
  content: string;
}

/** 切好的一章：标题 + 已替换段落分隔符的正文。 */
interface UmdChapter {
  title: string;
  text: string;
}

/** 段循环解出的全部素材：头信息、正文块、章名/偏移表、封面原图字节。 */
interface UmdSegments {
  title: string;
  author: string;
  bookType: string;
  /** 正文（UTF-16LE）总字节数，解压结果要截断到这里。 */
  totalContentLen: number;
  /** 各章正文在正文字节流里的起始偏移（UTF-16LE，每字符 2 字节）。 */
  contentOffsets: number[];
  /** 章名（UTF-16LE 解出）。 */
  titles: string[];
  /** 带 zlib 头的 deflate 正文块，逐块 uncompress 后拼成完整正文。 */
  contentBlocks: Uint8Array[];
  /** 封面原图字节（GIF/JPEG/PNG），原样落盘不解码。 */
  cover: Uint8Array;
}

/** 内存字节源：顺序读、推进逻辑位置。UMD 素材最大 1.8MB，一次读入后切片，避免 SDK readSync 的 offset 语义歧义。 */
class UmdByteSource {
  private bytes: Uint8Array;
  private pos: number;
  constructor(bytes: Uint8Array) {
    this.bytes = bytes;
    this.pos = 0;
  }
  get position(): number { return this.pos; }
  get size(): number { return this.bytes.length; }
  remaining(): number { return Math.max(0, this.bytes.length - this.pos); }
  read(length: number): Uint8Array {
    if (length <= 0 || this.remaining() <= 0) { return new Uint8Array(0); }
    const want = Math.min(length, this.remaining());
    const slice = this.bytes.subarray(this.pos, this.pos + want);
    this.pos += want;
    return slice;
  }
  readU8(): number {
    const b = this.read(1);
    return b.length > 0 ? (b[0] ?? 0) : 0;
  }
  readU16(): number {
    const b = this.read(2);
    return (b[0] ?? 0) | ((b[1] ?? 0) << 8);
  }
  readI32(): number {
    const b = this.read(4);
    return (b[0] ?? 0) | ((b[1] ?? 0) << 8) | ((b[2] ?? 0) << 16) | ((b[3] ?? 0) << 24);
  }
}

export class UmdRepository {
  /** 单本 UMD 读入内存的上限，超过直接拒绝，避免几十 MB 的书把内存打满。 */
  private static readonly maximumFileBytes = 64 * 1024 * 1024;
  private static readonly magic = 0xDE9A9B89;

  static async importFromUri(context: Context, uri: string, fileName: string,
    bookId: string): Promise<UmdImportResult> {
    const booksDirectory = `${context.filesDir}/books`;
    const coversDirectory = `${context.filesDir}/covers`;
    const contentPath = `${booksDirectory}/${bookId}.txt`;
    UmdRepository.ensureDirectory(booksDirectory);
    UmdRepository.ensureDirectory(coversDirectory);
    try {
      const bytes = UmdRepository.readAll(uri);
      const segments = UmdRepository.parseSegments(bytes);
      const contentBytes = await UmdRepository.inflateBlocks(segments.contentBlocks,
        segments.totalContentLen);
      const chapters = UmdRepository.buildChapters(segments, contentBytes);

      // 封面原图字节直接落盘（上游 UmdFile.upBookCover 同路，不解码重编码）。
      let coverUri: string | undefined = undefined;
      if (segments.cover.length > 0) {
        const coverPath = `${coversDirectory}/${bookId}.img`;
        const coverFile = fileIo.openSync(coverPath,
          fileIo.OpenMode.WRITE_ONLY | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC);
        try {
          fileIo.writeSync(coverFile.fd, UmdRepository.toArrayBuffer(segments.cover));
        } finally {
          fileIo.closeSync(coverFile);
        }
        coverUri = `file://${coverPath}`;
      }

      // 正文按 EPUB 的同一格式拼接：标题 + 空行 + 正文 + 空行；offsets 是累积字符数。
      const chapterTitles: string[] = [];
      const chapterOffsets: number[] = [];
      const chapterVolumes: boolean[] = [];
      const sections: string[] = [];
      let contentLength = 0;
      for (let index = 0; index < chapters.length; index++) {
        const chapter = chapters[index];
        if (chapter === undefined) { continue; }
        chapterTitles.push(chapter.title);
        chapterOffsets.push(contentLength);
        chapterVolumes.push(false);
        const section = `${chapter.title}\n\n${chapter.text}\n\n`;
        sections.push(section);
        contentLength += section.length;
      }
      const content = sections.join('');
      const contentFile = fileIo.openSync(contentPath,
        fileIo.OpenMode.WRITE_ONLY | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC);
      try {
        fileIo.writeSync(contentFile.fd, content);
      } finally {
        fileIo.closeSync(contentFile);
      }

      const book: Book = {
        id: bookId,
        title: segments.title.length > 0 ? segments.title : UmdRepository.fileTitle(fileName),
        author: segments.author.length > 0 ? segments.author : '本地 UMD',
        category: segments.bookType.length > 0 ? segments.bookType : '本地',
        groupName: '本地未分组',
        groupNames: [],
        chapterIndex: 0,
        chapterProgress: 0,
        lastChapter: chapterTitles[0] ?? '全文',
        progress: 0,
        coverUri: coverUri,
        description: '',
        chapterCount: chapterTitles.length.toString(),
        contentPath: contentPath,
        format: 'umd',
        latestChapterTime: Date.now(),
        isLocal: true
      };
      return {
        book: book,
        titles: chapterTitles,
        offsets: chapterOffsets,
        volumes: chapterVolumes,
        content: content
      };
    } catch (error) {
      try {
        fileIo.unlinkSync(contentPath);
      } catch (_) {
      }
      if (error instanceof Error) { throw error; }
      throw new Error('UMD 文件损坏或格式不受支持');
    }
  }

  /** 一次读入整本 UMD（带上限保护）。未做惰性偏移读：SDK readSync 的 offset 语义存在相对/绝对歧义，正确性优先。 */
  private static readAll(uri: string): Uint8Array {
    const source = fileIo.openSync(uri, fileIo.OpenMode.READ_ONLY);
    try {
      const size = fileIo.statSync(source.fd).size;
      if (size <= 0 || size > UmdRepository.maximumFileBytes) {
        throw new Error('UMD 文件为空或超过 64 MB');
      }
      const buffer = new ArrayBuffer(size);
      const read = fileIo.readSync(source.fd, buffer, { length: size });
      if (read !== size) { throw new Error('UMD 文件读取不完整'); }
      return new Uint8Array(buffer, 0, read);
    } finally {
      fileIo.closeSync(source);
    }
  }

  /** 照上游 UmdReader.java 的段循环逐字移植：'#' 段 + '$' 附加段，0xf1/0x0a 继承上一有效段类型。 */
  private static parseSegments(bytes: Uint8Array): UmdSegments {
    const src = new UmdByteSource(bytes);
    const decoder = util.TextDecoder.create('utf-16le');
    const magic = src.readI32() >>> 0;
    if (magic !== UmdRepository.magic) {
      throw new Error('UMD 文件头 magic 不对');
    }
    const result: UmdSegments = {
      title: '',
      author: '',
      bookType: '',
      totalContentLen: 0,
      contentOffsets: [],
      titles: [],
      contentBlocks: [],
      cover: new Uint8Array(0)
    };
    // _AdditionalCheckNumber：由 0x81/0x83/0x84/0x82 段写入，跨段保留，用来分辨 0x84 的正文块与章名表。
    let check: number | undefined = undefined;
    let num1 = -1;
    let ch = src.readU8();
    let guard = 0;
    while (ch === 0x23 && src.remaining() > 0 && guard < 100000) {
      guard += 1;
      const segType = src.readU16();
      src.readU8();                       // segFlag，解析不用
      const lenByte = src.readU8();
      const segLen = lenByte - 5;
      if (segLen < 0 || src.position + segLen > src.size) { break; }
      const body = src.read(segLen);
      if (segType === 2) {
        result.title = UmdRepository.decodeUtf16(decoder, body);
      } else if (segType === 3) {
        result.author = UmdRepository.decodeUtf16(decoder, body);
      } else if (segType === 7) {
        result.bookType = UmdRepository.decodeUtf16(decoder, body);
      } else if (segType === 0x0b && body.length >= 4) {
        result.totalContentLen = UmdRepository.i32At(body, 0);
      } else if ((segType === 0x81 || segType === 0x83 || segType === 0x84) && body.length >= 4) {
        check = UmdRepository.i32At(body, 0);
      } else if (segType === 0x82 && body.length >= 5) {
        check = UmdRepository.i32At(body, 1);
      }
      // 241(0xf1)/10(0x0a) 继承上一有效段类型：两本真书的段序不同，靠这个归一。
      const effective = (segType === 0xf1 || segType === 0x0a) ? num1 : segType;
      ch = src.readU8();
      while (ch === 0x24 && src.remaining() >= 8) {   // '$' 附加段
        const acn = src.readI32();
        const subLen = src.readI32() - 9;
        if (subLen < 0 || src.position + subLen > src.size) { break; }
        const sub = src.read(subLen);
        if (effective === 0x82) {
          result.cover = sub;
        } else if (effective === 0x83) {
          const count = Math.floor(sub.length / 4);
          const offsets: number[] = [];
          for (let k = 0; k < count; k++) {
            offsets.push(UmdRepository.i32At(sub, k * 4));
          }
          result.contentOffsets = offsets;
        } else if (effective === 0x84) {
          if (check === undefined || check !== acn) {
            // acn 不等 = 本章正文的 deflate 块（带 zlib 头）。
            result.contentBlocks.push(sub);
          } else {
            // acn 相等 = 章名表：每个章名一字节长度前缀 + UTF-16LE 名字。
            result.titles = UmdRepository.parseChapterTitles(decoder, sub,
              result.contentOffsets.length > 0 ? result.contentOffsets.length : 1);
          }
        }
        ch = src.readU8();
      }
      num1 = effective;
    }
    return result;
  }

  /** 章名表：长度前缀 + UTF-16LE 字节，逐条解出章名。 */
  private static parseChapterTitles(decoder: util.TextDecoder, sub: Uint8Array,
    count: number): string[] {
    const titles: string[] = [];
    let p = 0;
    for (let i = 0; i < count; i++) {
      if (p >= sub.length) { break; }
      const titleLen = sub[p] ?? 0;
      p += 1;
      const nameBytes = sub.subarray(p, Math.min(sub.length, p + titleLen));
      p += titleLen;
      titles.push(UmdRepository.decodeUtf16(decoder, nameBytes));
    }
    return titles;
  }

  /** 逐块 uncompress（带 zlib 头）拼成完整正文，再按 TotalContentLen 截断、偶数对齐。 */
  private static async inflateBlocks(blocks: Uint8Array[], totalContentLen: number): Promise<Uint8Array> {
    const zip = zlib.createZipSync();
    const parts: Uint8Array[] = [];
    let total = 0;
    for (let i = 0; i < blocks.length; i++) {
      const block = blocks[i];
      if (block === undefined) { continue; }
      const source = UmdRepository.toArrayBuffer(block);
      let destSize = 128 * 1024;
      let produced = 0;
      let out: Uint8Array = new Uint8Array(0);
      while (true) {
        const dest = new ArrayBuffer(destSize);
        try {
          const info = await zip.uncompress(dest, source, block.length);
          // 数据错/输出缓冲不足会抛 17800005 / 17800007，靠 catch 扩容重试；这里只校验产出长度。
          if (info.destLen <= 0) {
            throw new Error('zlib 解压返回异常');
          }
          // destLen 等于分配大小说明缓冲区可能不够，扩容后重试，避免把尾部补零当正文。
          if (info.destLen >= destSize && destSize < 64 * 1024 * 1024) {
            destSize *= 4;
            continue;
          }
          produced = Math.min(info.destLen, destSize);
          out = new Uint8Array(dest, 0, produced);
          break;
        } catch (_) {
          if (destSize >= 64 * 1024 * 1024) { throw new Error('UMD 正文块解压失败'); }
          destSize *= 4;
        }
      }
      parts.push(out);
      total += produced;
    }
    let capacity = totalContentLen > 0 ? Math.min(total, totalContentLen) : total;
    if (capacity % 2 !== 0) { capacity -= 1; }   // UTF-16LE 每字符 2 字节
    const full = new Uint8Array(Math.max(0, capacity));
    let w = 0;
    for (let i = 0; i < parts.length; i++) {
      const part = parts[i];
      if (part === undefined) { continue; }
      const take = Math.min(part.length, full.length - w);
      if (take <= 0) { break; }
      full.set(part.subarray(0, take), w);
      w += take;
    }
    return full.subarray(0, w);
  }

  /** 按章节字节偏移切 UTF-16LE 正文，(char)0x2029 换换行。 */
  private static buildChapters(segments: UmdSegments, contentBytes: Uint8Array): UmdChapter[] {
    const decoder = util.TextDecoder.create('utf-16le');
    const chapters: UmdChapter[] = [];
    const titles = segments.titles.length > 0 ? segments.titles : [UmdRepository.fileTitle('')];
    for (let i = 0; i < titles.length; i++) {
      const title = titles[i] ?? `第${i + 1}章`;
      const start = i < segments.contentOffsets.length ? (segments.contentOffsets[i] ?? 0) : 0;
      const end = (i + 1) < segments.contentOffsets.length
        ? (segments.contentOffsets[i + 1] ?? contentBytes.length)
        : contentBytes.length;
      const safeStart = Math.min(Math.max(0, start), contentBytes.length);
      const safeEnd = Math.min(Math.max(safeStart, end), contentBytes.length);
      const text = UmdRepository.decodeUtf16(decoder,
        contentBytes.subarray(safeStart, safeEnd)).replace(/\u2029/g, '\n');
      const row: UmdChapter = { title: title, text: text };
      chapters.push(row);
    }
    return chapters;
  }

  /** UTF-16LE 解码：奇数长度截掉末字节，避免 TextDecoder 报截断。 */
  private static decodeUtf16(decoder: util.TextDecoder, bytes: Uint8Array): string {
    if (bytes.length === 0) { return ''; }
    const even = bytes.length % 2 === 0 ? bytes : bytes.subarray(0, bytes.length - 1);
    return decoder.decodeToString(even);
  }

  private static i32At(b: Uint8Array, p: number): number {
    return (b[p] ?? 0) | ((b[p + 1] ?? 0) << 8) | ((b[p + 2] ?? 0) << 16)
      | ((b[p + 3] ?? 0) << 24);
  }

  private static toArrayBuffer(bytes: Uint8Array): ArrayBuffer {
    return bytes.buffer.slice(bytes.byteOffset, bytes.byteOffset + bytes.byteLength) as ArrayBuffer;
  }

  private static fileTitle(fileName: string): string {
    const base = fileName.includes('/') ? fileName.substring(fileName.lastIndexOf('/') + 1) : fileName;
    const dot = base.toLowerCase().lastIndexOf('.umd');
    return dot > 0 ? base.substring(0, dot) : base;
  }

  private static ensureDirectory(path: string): void {
    try {
      fileIo.mkdirSync(path, true);
    } catch (_) {
      // 目录已存在（mkdirSync recursive 幂等），忽略。
    }
  }
}
