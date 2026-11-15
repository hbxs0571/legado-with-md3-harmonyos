import { fileIo } from '@kit.CoreFileKit';
import { util } from '@kit.ArkTS';
import { Book } from '../../model/Book';
import { MobiInfo, MobiImportResult } from './MobiEntities';
import { PdbFile } from './PdbFile';
import { MobiReader } from './MobiReader';
import { createDecompressor, removeTrailingEntries } from './Decompress';

/** INDX 里的一条 TAGX 控制标签（上游 TagxTag）。 */
interface TagxTag {
  tag: number;
  numValues: number;
  bitmask: number;
  controlByte: number;
}

interface TagxInfo {
  numControl: number;
  tags: TagxTag[];
}

/** INDX 头里要用到的四个字段（上游 IndxHeader）。 */
interface IndxHeader {
  length: number;
  idxt: number;
  numRecords: number;
  numCncx: number;
}

/** 一条 INDX 表项解出的标签值（上游 IndexEntry）。 */
interface IndexEntry {
  label: string;
  tagMap: Map<number, number[]>;
}

/** NCX 目录项（上游 NCX；带 children 表示卷层级，G8）。 */
interface NcxItem {
  index: number;
  offset: number;
  label: string;
  headingLevel: number;
  parent: number;
  firstChild: number;
  children: NcxItem[] | undefined;
}

/** 扁平化后的一章：filepos 是解压全文里的字节偏移。 */
interface Kf6Chapter {
  label: string;
  filepos: number;
  isVolume: boolean;
}

/** 7-bit varint 的读取结果（值 + 新位置）。 */
interface VarintResult {
  value: number;
  next: number;
}

/**
 * KF6（老 .mobi）正文/目录/图片全流程，1:1 照上游
 * KF6Book.kt / MobiBook.getNCX / MobiFile.getChapterListKF6 / getContentKF6。
 * 上游用 Jsoup + ISO_8859_1 字节流；ArkTS 无 Jsoup/NetworkUtils，正文净化用正则链做字符级近似
 * （与批 4 的 EPUB 净化同口径），这一取舍写进 G5 的差异说明。
 */
export class Kf6Book {
  /** 本批入口：解析 KF6 MOBI 并落盘 .txt / 图片，返回交给 buildChapterRows 的五元组。 */
  static importFromUri(context: Context, uri: string, fileName: string, bookId: string): MobiImportResult {
    const pdb = new PdbFile(uri);
    const info = MobiReader.readMobi(pdb);
    if (info.isKF8) {
      throw new Error('KF8 / AZW3 的正文在批 12 接入，暂时无法导入');
    }
    // windows-1252（1252）若 SDK 不支持就明确报错，不静默按 UTF-8 解出一堆问号。
    if (info.encoding === 1252) {
      try {
        util.TextDecoder.create('windows-1252').decodeToString(new Uint8Array(0));
      } catch (_) {
        throw new Error('这台设备不支持 windows-1252 编码，无法按原编码解读这本 MOBI');
      }
    }
    const cs = Kf6Book.charsetName(info.encoding);
    const full = Kf6Book.buildFullText(pdb, info);
    const imageDir = `${context.filesDir}/book-images/${bookId}`;
    Kf6Book.ensureDirectory(imageDir);
    const booksDirectory = `${context.filesDir}/books`;
    Kf6Book.ensureDirectory(booksDirectory);
    const contentPath = `${booksDirectory}/${bookId}.txt`;

    let chapters = Kf6Book.flattenToc(Kf6Book.getNcx(pdb, info, cs));
    if (chapters.length === 0) {
      // NCX 读不出（无 INDX 或写坏）：退回按 pagebreak 字节切段，每段一章。
      chapters = Kf6Book.fallbackSections(full);
    }
    if (chapters.length === 0) {
      throw new Error('MOBI 里没有可识别的章节');
    }

    const chapterTitles: string[] = [];
    const chapterOffsets: number[] = [];
    const chapterVolumes: boolean[] = [];
    const sections: string[] = [];
    const decoder = util.TextDecoder.create(cs);
    let contentLength = 0;
    for (let i = 0; i < chapters.length; i += 1) {
      const ch = chapters[i];
      if (ch === undefined) { continue; }
      // 首章从全文头开始（含卷首，format 会清掉标签）；其余按目录锚点字节偏移切。
      const start = i === 0 ? 0 : Math.max(0, Math.min(ch.filepos, full.length));
      const next = chapters[i + 1];
      let end = next === undefined ? full.length : Math.max(start, Math.min(next.filepos, full.length));
      if (end < start) { end = start; }
      let text = '';
      try {
        text = decoder.decodeToString(full.slice(start, end));
      } catch (_) {
        text = '';
      }
      const formatted = Kf6Book.formatChapterText(text, pdb, info, imageDir);
      const section = `${ch.label}\n\n${formatted}\n\n`;
      chapterTitles.push(ch.label);
      chapterOffsets.push(contentLength);
      chapterVolumes.push(ch.isVolume);
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

    const author = Kf6Book.exthString(info, 100);
    const book: Book = {
      id: bookId,
      title: info.title.length > 0 ? info.title : Kf6Book.fileTitle(fileName),
      author: author.length > 0 ? author : '本地 MOBI',
      category: '本地',
      groupName: '本地未分组',
      groupNames: [],
      chapterIndex: 0,
      chapterProgress: 0,
      lastChapter: chapterTitles[0] ?? '全文',
      progress: 0,
      coverUri: undefined,
      description: Kf6Book.exthString(info, 103),
      chapterCount: chapterTitles.length.toString(),
      contentPath: contentPath,
      format: 'mobi',
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
  }

  /** 全部 text record 解压后按序拼成一条字节流（上游 getTextRecordInputStream）。 */
  private static buildFullText(pdb: PdbFile, info: MobiInfo): Uint8Array {
    const decomp = createDecompressor(pdb, info);
    const parts: Uint8Array[] = [];
    let total = 0;
    for (let i = 0; i < info.numTextRecords; i += 1) {
      let seg: Uint8Array;
      try {
        seg = pdb.getRecord(i + 1);
      } catch (_) {
        break;
      }
      const decoded = decomp.decompress(removeTrailingEntries(seg, info.trailingFlags));
      parts.push(decoded);
      total += decoded.length;
    }
    const full = new Uint8Array(total);
    let off = 0;
    for (let k = 0; k < parts.length; k += 1) {
      const p = parts[k];
      if (p === undefined) { continue; }
      full.set(p, off);
      off += p.length;
    }
    return full;
  }

  private static charsetName(encoding: number): string {
    return encoding === 1252 ? 'windows-1252' : 'utf-8';
  }

  /** INDX 头（上游 readIndxHeader），只取本流程用到的四个字段。 */
  private static readIndxHeader(r: Uint8Array): IndxHeader | undefined {
    if (PdbFile.ascii(r, 0, 4) !== 'INDX') { return undefined; }
    return {
      length: PdbFile.be32(r, 4),
      idxt: PdbFile.be32(r, 20),
      numRecords: PdbFile.be32(r, 24),
      numCncx: PdbFile.be32(r, 52)
    };
  }

  /** TAGX 控制表（上游 readTagxHeader / readTagxTags）。 */
  private static readTagx(main: Uint8Array, indxLength: number): TagxInfo | undefined {
    const t = main.slice(indxLength);
    if (PdbFile.ascii(t, 0, 4) !== 'TAGX') { return undefined; }
    const length = PdbFile.be32(t, 4);
    const numControl = PdbFile.be32(t, 8);
    const numTags = Math.max(0, Math.floor((length - 12) / 4));
    const tags: TagxTag[] = [];
    for (let i = 0; i < numTags; i += 1) {
      const o = 12 + i * 4;
      tags.push({
        tag: t[o] ?? 0,
        numValues: t[o + 1] ?? 0,
        bitmask: t[o + 2] ?? 0,
        controlByte: t[o + 3] ?? 0
      });
    }
    return { numControl: numControl, tags: tags };
  }

  /** 7-bit 大端 varint（上游 MobiBook.readIndexEntry 内的循环）。 */
  private static readVarint(ba: Uint8Array, pos: number): VarintResult {
    let value = 0;
    let p = pos;
    for (let i = 0; i < 4; i += 1) {
      if (p >= ba.length) { break; }
      const byte = ba[p] ?? 0;
      value = (value << 7) | (byte & 0x7f);
      p += 1;
      if ((byte & 0x80) !== 0) { break; }
    }
    return { value: value, next: p };
  }

  private static countOneBits(x: number): number {
    let v = x >>> 0;
    let count = 0;
    while (v !== 0) { count += v & 1; v = v >>> 1; }
    return count;
  }

  /** CNCX 字符串表（上游 readCncx）：varint 长度 + 内容，跨 record 每段 base 加 0x10000。 */
  private static readCncx(pdb: PdbFile, indxIndex: number, numRecords: number,
    numCncx: number, cs: string): Map<number, string> {
    const cncx = new Map<number, string>();
    const decoder = util.TextDecoder.create(cs);
    let base = 0;
    for (let i = 0; i < numCncx; i += 1) {
      let r: Uint8Array;
      try {
        r = pdb.getRecord(indxIndex + numRecords + i + 1);
      } catch (_) {
        break;
      }
      let pos = 0;
      while (pos < r.length) {
        const index = pos;
        const v = Kf6Book.readVarint(r, pos);
        pos = v.next;
        const seg = r.slice(pos, pos + v.value);
        cncx.set(base + index, decoder.decodeToString(seg));
        pos += v.value;
      }
      base += 0x10000;
    }
    return cncx;
  }

  /** 一条 INDX 表项（上游 readIndexEntry）：标签值按 TAGX 控制字节解出。 */
  private static readIndexEntry(ib: Uint8Array, tags: TagxTag[], numControl: number,
    idxtOffset: number, cs: string): IndexEntry {
    const ln = ib[idxtOffset] ?? 0;
    const decoder = util.TextDecoder.create(cs);
    const label = decoder.decodeToString(ib.slice(idxtOffset + 1, idxtOffset + 1 + ln));
    const start = idxtOffset + 1 + ln;
    let controlByteIndex = 0;
    let pos = start + numControl;
    const tagMap = new Map<number, number[]>();
    for (let k = 0; k < tags.length; k += 1) {
      const tag = tags[k];
      if (tag === undefined) { continue; }
      if (tag.controlByte === 1) { controlByteIndex += 1; continue; }
      const off = start + controlByteIndex;
      const value = (ib[off] ?? 0) & tag.bitmask;
      let valueCount = 0;
      let useBytes = false;
      let valueBytes = 0;
      if (value === tag.bitmask) {
        if (Kf6Book.countOneBits(tag.bitmask) > 1) {
          const v = Kf6Book.readVarint(ib, pos);
          valueBytes = v.value;
          pos = v.next;
          useBytes = true;
        } else {
          valueCount = 1;
        }
      } else {
        let mask = tag.bitmask;
        let v = value;
        while (mask > 0 && (mask & 1) === 0) {
          mask = mask >>> 1;
          v = v >>> 1;
        }
        valueCount = v;
      }
      const values: number[] = [];
      if (!useBytes) {
        const total = valueCount * tag.numValues;
        for (let j = 0; j < total; j += 1) {
          const vv = Kf6Book.readVarint(ib, pos);
          values.push(vv.value);
          pos = vv.next;
        }
      } else {
        let consumed = 0;
        while (consumed < valueBytes && pos < ib.length) {
          const before = pos;
          const vv = Kf6Book.readVarint(ib, pos);
          values.push(vv.value);
          pos = vv.next;
          consumed += Math.max(1, pos - before);
        }
      }
      tagMap.set(tag.tag, values);
    }
    return { label: label, tagMap: tagMap };
  }

  private static firstOf(tm: Map<number, number[]>, tag: number): number {
    const arr = tm.get(tag);
    if (arr === undefined || arr.length === 0) { return -1; }
    return arr[0] ?? 0;
  }

  /** NCX 目录树（上游 MobiBook.getNCX）：INDX→表项→按 parent 组层级。 */
  private static getNcx(pdb: PdbFile, info: MobiInfo, cs: string): NcxItem[] {
    const indxIndex = info.indx;
    if (indxIndex === 0xFFFFFFFF || indxIndex >= info.recordCount) { return []; }
    let mainRecord: Uint8Array;
    try {
      mainRecord = pdb.getRecord(indxIndex);
    } catch (_) {
      return [];
    }
    const main = Kf6Book.readIndxHeader(mainRecord);
    if (main === undefined) { return []; }
    const tagx = Kf6Book.readTagx(mainRecord, main.length);
    if (tagx === undefined) { return []; }
    const cncx = Kf6Book.readCncx(pdb, indxIndex, main.numRecords, main.numCncx, cs);
    const items: NcxItem[] = [];
    for (let i = 0; i < main.numRecords; i += 1) {
      let ib: Uint8Array;
      try {
        ib = pdb.getRecord(indxIndex + 1 + i);
      } catch (_) {
        break;
      }
      const ih = Kf6Book.readIndxHeader(ib);
      if (ih === undefined) { continue; }
      const idxtStart = ih.idxt + 4;
      for (let j = 0; j < ih.numRecords; j += 1) {
        const idxtOffset = PdbFile.be16(ib, idxtStart + j * 2);
        const entry = Kf6Book.readIndexEntry(ib, tagx.tags, tagx.numControl, idxtOffset, cs);
        const cncxIdx = Kf6Book.firstOf(entry.tagMap, 3);
        let label = entry.label;
        if (cncxIdx >= 0) {
          const fromCncx = cncx.get(cncxIdx);
          if (fromCncx !== undefined) { label = fromCncx; }
        }
        items.push({
          index: items.length,
          offset: Kf6Book.firstOf(entry.tagMap, 1),
          label: label,
          headingLevel: Kf6Book.firstOf(entry.tagMap, 4),
          parent: Kf6Book.firstOf(entry.tagMap, 21),
          firstChild: Kf6Book.firstOf(entry.tagMap, 22),
          children: undefined
        });
      }
    }
    const parentMap = new Map<number, NcxItem[]>();
    for (let k = 0; k < items.length; k += 1) {
      const it = items[k];
      if (it === undefined || it.parent < 0) { continue; }
      const arr = parentMap.get(it.parent);
      if (arr === undefined) { parentMap.set(it.parent, [it]); }
      else { arr.push(it); }
    }
    const roots: NcxItem[] = [];
    for (let k = 0; k < items.length; k += 1) {
      const it = items[k];
      if (it === undefined || it.headingLevel !== 0) { continue; }
      Kf6Book.attachChildren(it, parentMap);
      roots.push(it);
    }
    return roots;
  }

  private static attachChildren(it: NcxItem, parentMap: Map<number, NcxItem[]>): void {
    if (it.firstChild < 0) { return; }
    // 上游 getChildren：有 firstChild 但无实际子项时 children 保持 null（isVolume=false），不能塞空数组。
    const kids = parentMap.get(it.index);
    if (kids === undefined) { return; }
    it.children = kids;
    for (let m = 0; m < kids.length; m += 1) {
      const kid = kids[m];
      if (kid !== undefined) { Kf6Book.attachChildren(kid, parentMap); }
    }
  }

  /** 深度优先摊平目录（上游 getChapterListKF6 的 append），isVolume 来自有无子项（G8）。 */
  private static flattenToc(roots: NcxItem[]): Kf6Chapter[] {
    const flat: Kf6Chapter[] = [];
    for (let k = 0; k < roots.length; k += 1) {
      const r = roots[k];
      if (r !== undefined) { Kf6Book.appendToc(r, flat); }
    }
    return flat;
  }

  private static appendToc(ref: NcxItem, flat: Kf6Chapter[]): void {
    flat.push({
      label: ref.label,
      filepos: ref.offset >= 0 ? ref.offset : 0,
      isVolume: ref.children !== undefined
    });
    if (ref.children === undefined) { return; }
    for (let m = 0; m < ref.children.length; m += 1) {
      const c = ref.children[m];
      if (c !== undefined) { Kf6Book.appendToc(c, flat); }
    }
  }

  /** NCX 缺失时的退化：按 pagebreak 标签的字节位置切段（上游 processSections 的字面语义）。 */
  private static fallbackSections(full: Uint8Array): Kf6Chapter[] {
    const result: Kf6Chapter[] = [];
    let latin = '';
    for (let i = 0; i < full.length; i += 1) { latin += String.fromCharCode(full[i] ?? 0); }
    const pattern = /<\s*(?:mbp:)?pagebreak[^>]*>/gi;
    let start = 0;
    let match = pattern.exec(latin);
    while (match !== null) {
      result.push({ label: `分段_${result.length + 1}`, filepos: start, isVolume: false });
      start = match.index + (match[0] ?? '').length;
      match = pattern.exec(latin);
    }
    if (start < full.length) {
      result.push({ label: `分段_${result.length + 1}`, filepos: start, isVolume: false });
    }
    return result;
  }

  /** 正文净化（上游 formatKeepImg 的字符级近似）+ recindex 图片落盘（G6）。
   * 先把 <img recindex="N"> 换成 [[EPUB_IMAGE:file://...]] 标记并复制图片字节，再删其余标签。
   */
  private static formatChapterText(html: string, pdb: PdbFile, info: MobiInfo,
    imageDir: string): string {
    const copied = new Set<number>();
    const withImages = html.replace(/<img\b[^>]*\brecindex\s*=\s*["'](\d+)["'][^>]*>/gi,
      (match: string, n: string): string => {
        const index = Number.parseInt(n, 10);
        if (!Number.isFinite(index) || index < 1) { return ''; }
        if (!copied.has(index)) {
          copied.add(index);
          try {
            const bytes = pdb.getRecord(info.resourceStart + index - 1);
            Kf6Book.writeImage(`${imageDir}/${index}.img`, bytes);
          } catch (_) {
            // 单张图取不到不影响正文（上游 getImage 也允许返回 null）。
          }
        }
        return `[[EPUB_IMAGE:file://${imageDir}/${index}.img]]`;
      });
    return Kf6Book.decodeXml(withImages
      .replace(/<!--[\s\S]*?-->/g, ' ')
      .replace(/<(script|style)\b[^>]*>[\s\S]*?<\/\1\s*>/gi, ' ')
      .replace(/<title\b[^>]*>[\s\S]*?<\/title\s*>/gi, ' ')
      .replace(/<[a-zA-Z][a-zA-Z0-9]*\b[^>]*style\s*=\s*["'][^"']*display\s*:\s*none[^"']*["'][^>]*>[\s\S]*?<\/[a-zA-Z][a-zA-Z0-9]*\s*>/gi, ' ')
      .replace(/&(nbsp|ensp|emsp);/gi, ' ')
      .replace(/&(thinsp|zwnj|zwj);/gi, '')
      .replace(/<br\b[^>]*\/?\s*>/gi, '\n')
      .replace(/<\/?(?:div|p|hr|h[1-6]|article|dd|dl|li|mbp:pagebreak|pagebreak)\b[^>]*>/gi, '\n')
      .replace(/<\/?(?:section|blockquote|tr)\b[^>]*>/gi, '\n')
      .replace(/<[^>]+>/g, ''))
      .replace(/[\t\u00A0 ]+/g, ' ')
      .replace(/ *\n */g, '\n')
      .replace(/\n{3,}/g, '\n\n')
      .trim();
  }

  private static decodeXml(text: string): string {
    return text.replace(/&(#x[0-9a-fA-F]+|#\d+|amp|lt|gt|quot|apos|nbsp);/g,
      (entity: string, value: string): string => {
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

  /** 图片字节原样落盘（上游内嵌图不压缩，直接是 JPEG/GIF/PNG）。 */
  private static writeImage(path: string, bytes: Uint8Array): void {
    const file = fileIo.openSync(path,
      fileIo.OpenMode.WRITE_ONLY | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC);
    try {
      const buf = bytes.buffer.slice(bytes.byteOffset, bytes.byteOffset + bytes.byteLength) as ArrayBuffer;
      fileIo.writeSync(file.fd, buf);
    } finally {
      fileIo.closeSync(file);
    }
  }

  private static ensureDirectory(path: string): void {
    try {
      fileIo.mkdirSync(path, true);
    } catch (_) {
      // 已存在时忽略。
    }
  }

  private static fileTitle(fileName: string): string {
    return fileName.replace(/\.[^.]+$/, '');
  }

  private static exthString(info: MobiInfo, type: number): string {
    const v = info.exth.get(type);
    return typeof v === 'string' ? v : '';
  }
}
