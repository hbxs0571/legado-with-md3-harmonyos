import { fileIo } from '@kit.CoreFileKit';
import { util } from '@kit.ArkTS';
import { Book } from '../../model/Book';
import { MobiInfo, MobiImportResult } from './MobiEntities';
import { PdbFile } from './PdbFile';
import { createDecompressor, removeTrailingEntries } from './Decompress';

/** INDX 里的一条 TAGX 控制标签（上游 TagxTag），与 KF6 同结构、本代独立实现。 */
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

/** getIndexData 的产出：表项 + CNCX 字符串表。 */
interface IndexTable {
  table: IndexEntry[];
  cncx: Map<number, string>;
}

/** 7-bit varint 的读取结果（值 + 新位置）。 */
interface VarintResult {
  value: number;
  next: number;
}

/** record0 的 KF8 专属头（上游 readKF8Header，偏移为 record0 绝对）。 */
interface Kf8Header {
  fdst: number;
  numFdst: number;
  frag: number;
  skel: number;
  guide: number;
}

/** 骨架表项（上游 Skeleton）。 */
interface Skeleton {
  index: number;
  name: string;
  numFrag: number;
  offset: number;
  length: number;
}

/** 片段表项（上游 Fragment）：insertOffset 指向全文里的插入位置，index 是 fid。 */
interface Fragment {
  insertOffset: number;
  selector: string;
  index: number;
  offset: number;
  length: number;
}

/** 一个可渲染 section（上游 KF8Section，linear = frags 非空）。 */
interface Kf8Section {
  index: number;
  skel: Skeleton;
  frags: Fragment[];
  fragEnd: number;
  length: number;
  href: string;
}

/** NCX 目录项（KF8 用 tag6 的 pos 数组定位 kindle:pos）。 */
interface NcxItem {
  index: number;
  label: string;
  headingLevel: number;
  parent: number;
  firstChild: number;
  pos: number[];
  children: NcxItem[] | undefined;
}

/** 扁平化后的一章：href 是 kindle:pos:fid:XXXX:off:YYYYYYYYYY。 */
interface Kf8Chapter {
  label: string;
  href: string;
  isVolume: boolean;
}

/** parsePosURI 的结果。 */
interface Kf8Pos {
  fid: number;
  off: number;
}

/**
 * KF8（.azw3 / 装 KF8 的 .mobi）正文/目录/图片/封面全流程，1:1 照上游
 * KF8Book.kt / MobiBook.getNCX·getIndexData / MobiFile.getChapterListKF8·getContentKF8。
 * 三表初始化顺序固定 FDST→SKEL→FRAG→processSections→NCX（上游 init :180-187，错一个全乱）。
 * 本代与 KF6 的 INDEX 解析独立实现，避免改动批 11 已提交代码。
 */
export class Kf8Book {
  /** Kotlin Int.toString(32).uppercase() 的字母表：0-9 + A-V（32 个字符）。 */
  private static readonly DIGITS: string = '0123456789ABCDEFGHIJKLMNOPQRSTUV';

  /** 本批入口：解析 KF8 MOBI 并落盘 .txt / 图片 / 封面，返回交给 buildChapterRows 的五元组。 */
  static importFromUri(context: Context, fileName: string, bookId: string,
    pdb: PdbFile, info: MobiInfo): MobiImportResult {
    // windows-1252（1252）若 SDK 不支持就明确报错，不静默按 UTF-8 解出一堆问号。
    if (info.encoding === 1252) {
      try {
        util.TextDecoder.create('windows-1252').decodeToString(new Uint8Array(0));
      } catch (_) {
        throw new Error('这台设备不支持 windows-1252 编码，无法按原编码解读这本 MOBI');
      }
    }
    const cs = Kf8Book.charsetName(info.encoding);
    const kf8 = Kf8Book.readKf8Header(pdb.getRecord(0));
    // 三表顺序 1/2/3：FDST（只解析校验，本地 getRaw 用全局 text record 字节流）、SKEL、FRAG。
    Kf8Book.readFdst(pdb, kf8.fdst);
    const skels = Kf8Book.readSkelTable(pdb, kf8, cs);
    const frags = Kf8Book.readFragTable(pdb, kf8, cs);
    // 4 processSections；5 processNCX；6 processSectionsMap 隐含在 getIndexByFid（按 fid 找 section）。
    const sections = Kf8Book.processSections(skels, frags);
    const full = Kf8Book.buildFullText(pdb, info);
    let chapters = Kf8Book.flattenToc(Kf8Book.getNcx(pdb, info, cs));
    if (chapters.length === 0) {
      // NCX 读不出：退回每个 linear section 一章（linear = 有 frags，无 frag 的 section 是资源不是章）。
      chapters = Kf8Book.fallbackSections(sections);
    }
    if (chapters.length === 0) {
      throw new Error('KF8 里没有可识别的章节');
    }

    const imageDir = `${context.filesDir}/book-images/${bookId}`;
    const coversDir = `${context.filesDir}/covers`;
    const booksDirectory = `${context.filesDir}/books`;
    Kf8Book.ensureDirectory(imageDir);
    Kf8Book.ensureDirectory(coversDir);
    Kf8Book.ensureDirectory(booksDirectory);
    const contentPath = `${booksDirectory}/${bookId}.txt`;
    // 最后一章没有 nextUrl，给一个任何 section 都命中不了的 fid 哨兵：getTextByHref 里
    // index != nextIndex → endFid = MAX → 取本节全部 frag（等价于上游「无下一目录 section」路径）。
    const sentinel = Kf8Book.makePosURI(0x7FFFFFFF, 0);
    const titles: string[] = [];
    const offsets: number[] = [];
    const volumes: boolean[] = [];
    const pieces: string[] = [];
    let contentLength = 0;
    for (let i = 0; i < chapters.length; i += 1) {
      const ch = chapters[i];
      if (ch === undefined) { continue; }
      const next = chapters[i + 1];
      const nextHref = next !== undefined ? next.href : sentinel;
      let html = Kf8Book.getTextByHref(full, sections, ch.href, nextHref, cs);
      if (html.length === 0) {
        // fid 未命中任何 section（或拼装异常）：退回该 section 全量拼装，保证正文不空。
        const pos = Kf8Book.parsePosURI(ch.href);
        const si = pos !== undefined ? Kf8Book.getIndexByFid(sections, pos.fid) : -1;
        const sec = si >= 0 ? sections[si] : undefined;
        html = sec !== undefined ? Kf8Book.getSectionText(full, sec, cs) : '';
      }
      const formatted = Kf8Book.formatChapterText(html, pdb, info, imageDir);
      const section = `${ch.label}\n\n${formatted}\n\n`;
      titles.push(ch.label);
      offsets.push(contentLength);
      volumes.push(ch.isVolume);
      pieces.push(section);
      contentLength += section.length;
    }
    const content = pieces.join('');
    const contentFile = fileIo.openSync(contentPath,
      fileIo.OpenMode.WRITE_ONLY | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC);
    try {
      fileIo.writeSync(contentFile.fd, content);
    } finally {
      fileIo.closeSync(contentFile);
    }

    // G12 封面（EXTH 201 coverOffset / 202 thumbnailOffset → resourceStart + 相对索引）。
    const coverUri = Kf8Book.writeCover(pdb, info, coversDir, bookId);
    const author = Kf8Book.exthString(info, 100);
    const book: Book = {
      id: bookId,
      title: info.title.length > 0 ? info.title : Kf8Book.fileTitle(fileName),
      author: author.length > 0 ? author : '本地 MOBI',
      category: '本地',
      groupName: '本地未分组',
      groupNames: [],
      chapterIndex: 0,
      chapterProgress: 0,
      lastChapter: titles[0] ?? '全文',
      progress: 0,
      coverUri: coverUri,
      description: Kf8Book.exthString(info, 103),
      chapterCount: titles.length.toString(),
      contentPath: contentPath,
      format: 'mobi',
      latestChapterTime: Date.now(),
      isLocal: true
    };
    return {
      book: book,
      titles: titles,
      offsets: offsets,
      volumes: volumes,
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

  /** KF8 专属头（上游 readKF8Header:1016-1024），偏移为 record0 绝对。 */
  private static readKf8Header(r0: Uint8Array): Kf8Header {
    return {
      fdst: PdbFile.be32(r0, 192),
      numFdst: PdbFile.be32(r0, 196),
      frag: PdbFile.be32(r0, 248),
      skel: PdbFile.be32(r0, 252),
      guide: PdbFile.be32(r0, 260)
    };
  }

  /** FDST 流表（上游 readFdstTable:387-401 / readFdstHeader:403-408）。
   * 上游 getRaw 直接按 skel.offset 从全局 text record 字节流取，FDST 仅解析校验、不参与拼装；
   * 按 init 顺序第一个读，越界即停、不抛。
   */
  private static readFdst(pdb: PdbFile, fdstIdx: number): number {
    let r: Uint8Array;
    try {
      r = pdb.getRecord(fdstIdx);
    } catch (_) {
      return 0;
    }
    if (PdbFile.ascii(r, 0, 4) !== 'FDST') { return 0; }
    const n = PdbFile.be32(r, 8);
    let count = 0;
    for (let i = 0; i < n; i += 1) {
      const o = 12 + i * 8;
      if (o + 8 > r.length) { break; }
      const start = PdbFile.be32(r, o);
      const end = PdbFile.be32(r, o + 4);
      if (end < start) { break; }
      count += 1;
    }
    return count;
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
        const v = Kf8Book.readVarint(r, pos);
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
        if (Kf8Book.countOneBits(tag.bitmask) > 1) {
          const v = Kf8Book.readVarint(ib, pos);
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
          const vv = Kf8Book.readVarint(ib, pos);
          values.push(vv.value);
          pos = vv.next;
        }
      } else {
        let consumed = 0;
        while (consumed < valueBytes && pos < ib.length) {
          const before = pos;
          const vv = Kf8Book.readVarint(ib, pos);
          values.push(vv.value);
          pos = vv.next;
          // 上游按 varint 字节累加 count（readIndexEntry :750-762），不是按值个数。
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

  /** 通用 getIndexData（上游 MobiBook.getIndexData:663-686）：SKEL/FRAG/NCX 各一份 INDX 索引。 */
  private static readIndexTable(pdb: PdbFile, indxIndex: number, cs: string): IndexTable {
    const table: IndexEntry[] = [];
    const empty: IndexTable = { table: table, cncx: new Map<number, string>() };
    let main: Uint8Array;
    try {
      main = pdb.getRecord(indxIndex);
    } catch (_) {
      return empty;
    }
    const ih = Kf8Book.readIndxHeader(main);
    if (ih === undefined) { return empty; }
    const tagx = Kf8Book.readTagx(main, ih.length);
    if (tagx === undefined) { return empty; }
    const cncx = Kf8Book.readCncx(pdb, indxIndex, ih.numRecords, ih.numCncx, cs);
    for (let i = 0; i < ih.numRecords; i += 1) {
      let ib: Uint8Array;
      try {
        ib = pdb.getRecord(indxIndex + 1 + i);
      } catch (_) {
        break;
      }
      const bih = Kf8Book.readIndxHeader(ib);
      if (bih === undefined) { continue; }
      const idxtStart = bih.idxt + 4;
      for (let j = 0; j < bih.numRecords; j += 1) {
        const idxtOffset = PdbFile.be16(ib, idxtStart + j * 2);
        table.push(Kf8Book.readIndexEntry(ib, tagx.tags, tagx.numControl, idxtOffset, cs));
      }
    }
    return { table: table, cncx: cncx };
  }

  /** SKEL 骨架表（上游 readSkelTable:374-385）：tag1=numFrag、tag6=[offset,length]。 */
  private static readSkelTable(pdb: PdbFile, kf8: Kf8Header, cs: string): Skeleton[] {
    const idx = Kf8Book.readIndexTable(pdb, kf8.skel, cs);
    const skels: Skeleton[] = [];
    for (let i = 0; i < idx.table.length; i += 1) {
      const e = idx.table[i];
      if (e === undefined) { continue; }
      const n1 = Kf8Book.firstOf(e.tagMap, 1);
      const a6 = e.tagMap.get(6);
      skels.push({
        index: skels.length,
        name: e.label,
        numFrag: n1 >= 0 ? n1 : 0,
        offset: a6 !== undefined ? (a6[0] ?? 0) : 0,
        length: a6 !== undefined ? (a6[1] ?? 0) : 0
      });
    }
    return skels;
  }

  /** FRAG 片段表（上游 readFragTable:360-372）：label=insertOffset、tag2=selector(cncx)、
   * tag4=index(fid)、tag6=[offset,length]。
   */
  private static readFragTable(pdb: PdbFile, kf8: Kf8Header, cs: string): Fragment[] {
    const idx = Kf8Book.readIndexTable(pdb, kf8.frag, cs);
    const frags: Fragment[] = [];
    for (let i = 0; i < idx.table.length; i += 1) {
      const e = idx.table[i];
      if (e === undefined) { continue; }
      const t2 = Kf8Book.firstOf(e.tagMap, 2);
      const t4 = Kf8Book.firstOf(e.tagMap, 4);
      const a6 = e.tagMap.get(6);
      const trimmed = e.label.trim();
      const insertOffset = /^[0-9]+$/.test(trimmed) ? Number.parseInt(trimmed, 10) : 0;
      frags.push({
        insertOffset: Number.isFinite(insertOffset) ? insertOffset : 0,
        selector: idx.cncx.get(t2) ?? '',
        index: t4 >= 0 ? t4 : 0,
        offset: a6 !== undefined ? (a6[0] ?? 0) : 0,
        length: a6 !== undefined ? (a6[1] ?? 0) : 0
      });
    }
    return frags;
  }

  /** processSections（上游 :343-358）：把 SKEL + 它的若干 FRAG 组装成 section。 */
  private static processSections(skels: Skeleton[], frags: Fragment[]): Kf8Section[] {
    const sections: Kf8Section[] = [];
    let fragStart = 0;
    for (let i = 0; i < skels.length; i += 1) {
      const skel = skels[i];
      if (skel === undefined) { continue; }
      const fragEnd = fragStart + skel.numFrag;
      const myFrags: Fragment[] = [];
      let length = skel.length;
      for (let f = fragStart; f < fragEnd && f < frags.length; f += 1) {
        const fr = frags[f];
        if (fr === undefined) { continue; }
        myFrags.push(fr);
        length += fr.length;
      }
      const first = myFrags[0];
      const href = first !== undefined ? Kf8Book.makePosURI(first.index, 0) : '';
      sections.push({
        index: sections.length,
        skel: skel,
        frags: myFrags,
        fragEnd: fragEnd,
        length: length,
        href: href
      });
      fragStart = fragEnd;
    }
    return sections;
  }

  /** base32（Kotlin Int.toString(32).uppercase()），fid 4 位、off 10 位补零。 */
  private static toBase32(n: number, width: number): string {
    let v = Math.max(0, Math.floor(n));
    let s = v === 0 ? '0' : '';
    while (v > 0) {
      s = Kf8Book.DIGITS.charAt(v & 31) + s;
      v = Math.floor(v / 32);
    }
    while (s.length < width) { s = '0' + s; }
    return s;
  }

  private static fromBase32(s: string): number {
    let n = 0;
    const up = s.toUpperCase();
    for (let i = 0; i < up.length; i += 1) {
      const idx = Kf8Book.DIGITS.indexOf(up.charAt(i));
      if (idx < 0) { return n; }
      n = n * 32 + idx;
    }
    return n;
  }

  /** KF8Book.makePosURI:337-341。 */
  private static makePosURI(fid: number, off: number): string {
    return `kindle:pos:fid:${Kf8Book.toBase32(fid, 4)}:off:${Kf8Book.toBase32(off, 10)}`;
  }

  /** KF8Book.parsePosURI:207-212（正则 find，容忍 "5:" 一类前缀）。 */
  private static parsePosURI(href: string): Kf8Pos | undefined {
    const pattern = /kindle:pos:fid:(\w+):off:(\w+)/;
    const m = pattern.exec(href);
    if (m === null) { return undefined; }
    return {
      fid: Kf8Book.fromBase32(m[1] ?? ''),
      off: Kf8Book.fromBase32(m[2] ?? '')
    };
  }

  /** getIndexByFID（上游 :238-244）：找含该 fid 的 section 索引。 */
  private static getIndexByFid(sections: Kf8Section[], fid: number): number {
    for (let i = 0; i < sections.length; i += 1) {
      const s = sections[i];
      if (s === undefined) { continue; }
      for (let j = 0; j < s.frags.length; j += 1) {
        const f = s.frags[j];
        if (f !== undefined && f.index === fid) { return i; }
      }
    }
    return -1;
  }

  /** NCX 目录树（KF8 版 MobiBook.getNCX + KF8Book.processNCX）：tag6 的 pos 数组定位。 */
  private static getNcx(pdb: PdbFile, info: MobiInfo, cs: string): NcxItem[] {
    const indxIndex = info.indx;
    if (indxIndex === 0xFFFFFFFF || indxIndex >= info.recordCount) { return []; }
    const idx = Kf8Book.readIndexTable(pdb, indxIndex, cs);
    const items: NcxItem[] = [];
    for (let i = 0; i < idx.table.length; i += 1) {
      const e = idx.table[i];
      if (e === undefined) { continue; }
      const cncxIdx = Kf8Book.firstOf(e.tagMap, 3);
      let label = e.label;
      if (cncxIdx >= 0) {
        const fromCncx = idx.cncx.get(cncxIdx);
        if (fromCncx !== undefined) { label = fromCncx; }
      }
      items.push({
        index: items.length,
        label: label,
        headingLevel: Kf8Book.firstOf(e.tagMap, 4),
        parent: Kf8Book.firstOf(e.tagMap, 21),
        firstChild: Kf8Book.firstOf(e.tagMap, 22),
        pos: e.tagMap.get(6) ?? [],
        children: undefined
      });
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
      Kf8Book.attachChildren(it, parentMap);
      roots.push(it);
    }
    return roots;
  }

  /** 上游 getChildren:639-643：有 firstChild 但无实际子项时 children 保持 null（isVolume=false），
   * 不塞空数组，否则卷层会误判（与批 11 KF6 的 G8 语义修正同口径）。
   */
  private static attachChildren(it: NcxItem, parentMap: Map<number, NcxItem[]>): void {
    if (it.firstChild < 0) { return; }
    const kids = parentMap.get(it.index);
    if (kids === undefined) { return; }
    it.children = kids;
    for (let m = 0; m < kids.length; m += 1) {
      const kid = kids[m];
      if (kid !== undefined) { Kf8Book.attachChildren(kid, parentMap); }
    }
  }

  /** 深度优先摊平目录（上游 getChapterListKF8 的 append），href 用 kindle:pos。 */
  private static flattenToc(roots: NcxItem[]): Kf8Chapter[] {
    const flat: Kf8Chapter[] = [];
    for (let k = 0; k < roots.length; k += 1) {
      const r = roots[k];
      if (r !== undefined) { Kf8Book.appendToc(r, flat); }
    }
    return flat;
  }

  private static appendToc(ref: NcxItem, flat: Kf8Chapter[]): void {
    const pos = ref.pos;
    const fid = pos.length >= 2 ? (pos[0] ?? 0) : 0;
    const off = pos.length >= 2 ? (pos[1] ?? 0) : 0;
    flat.push({
      label: ref.label,
      href: Kf8Book.makePosURI(fid, off),
      isVolume: ref.children !== undefined
    });
    if (ref.children === undefined) { return; }
    for (let m = 0; m < ref.children.length; m += 1) {
      const c = ref.children[m];
      if (c !== undefined) { Kf8Book.appendToc(c, flat); }
    }
  }

  /** NCX 缺失时的退化：每个 linear section（有 frag）一章。 */
  private static fallbackSections(sections: Kf8Section[]): Kf8Chapter[] {
    const flat: Kf8Chapter[] = [];
    for (let i = 0; i < sections.length; i += 1) {
      const s = sections[i];
      if (s === undefined || s.href.length === 0) { continue; }
      flat.push({ label: `分段_${flat.length + 1}`, href: s.href, isVolume: false });
    }
    return flat;
  }

  /** getTextByHref（上游 KF8Book.getTextByHref:246-293，本批技术核心）：
   * 按 fid/off 截取 + 逐 frag 把片段插回骨架的 insertPosition。用 slice 出源段再 set 回，
   * 避免同源 overlap；与上游 ByteArray.copyInto 的 memmove 语义等价。
   */
  private static getTextByHref(full: Uint8Array, sections: Kf8Section[],
    href: string, nextHref: string, cs: string): string {
    const pos = Kf8Book.parsePosURI(href);
    const nextPos = Kf8Book.parsePosURI(nextHref);
    if (pos === undefined || nextPos === undefined) { return ''; }
    const index = Kf8Book.getIndexByFid(sections, pos.fid);
    const nextIndex = Kf8Book.getIndexByFid(sections, nextPos.fid);
    if (index < 0 || index >= sections.length) { return ''; }
    const section = sections[index];
    if (section === undefined) { return ''; }
    const startFid = pos.fid;
    // 下一章在本 section 内 → 截到它的 fid；否则取本节全部 frag。
    const endFid = index === nextIndex ? nextPos.fid : 0x7FFFFFFF;
    const skel = section.skel;
    const dropped = section.frags.filter((f: Fragment): boolean => f.index < startFid);
    let droppedLen = 0;
    for (let d = 0; d < dropped.length; d += 1) { droppedLen += dropped[d]?.length ?? 0; }
    const frags = section.frags.filter(
      (f: Fragment): boolean => f.index >= startFid && f.index <= endFid);
    if (frags.length === 0) { return ''; }
    let length = skel.length;
    for (let f = 0; f < frags.length; f += 1) { length += frags[f]?.length ?? 0; }
    const raw = full.slice(skel.offset, skel.offset + section.length);
    const lastFrag = frags[frags.length - 1];
    const lastDropped = (index === nextIndex && lastFrag !== undefined)
      ? lastFrag.length - nextPos.off : 0;
    const size = length - pos.off - lastDropped;
    if (size <= 0) { return ''; }
    const skeleton = new Uint8Array(size);
    const headLen = Math.min(skel.length, size);
    skeleton.set(raw.slice(0, headLen), 0);
    let leftBytes = size - skel.length;
    for (let i = 0; i < frags.length; i += 1) {
      const frag = frags[i];
      if (frag === undefined) { continue; }
      const isFirst = i === 0;
      const isLast = i === frags.length - 1;
      const insertOffset = frag.insertOffset - skel.offset - droppedLen;
      const offset = skel.length + frag.offset;
      const dstOff = insertOffset + frag.length - (isFirst ? pos.off : 0) - (isLast ? lastDropped : 0);
      const srcEnd = size - leftBytes;
      // 先把骨架里 insertOffset 之后的尾段挪开，给 frag 内容腾位置。
      if (insertOffset >= 0 && srcEnd > insertOffset && dstOff >= 0) {
        const seg = skeleton.slice(insertOffset, Math.min(srcEnd, size));
        const n = Math.min(seg.length, size - dstOff);
        if (n > 0) { skeleton.set(seg.subarray(0, n), dstOff); }
      }
      // 再把 frag 原文从 raw 插到 insertOffset。
      const rStart = offset + (isFirst ? pos.off : 0);
      const rEnd = offset + frag.length - (isLast ? lastDropped : 0);
      if (insertOffset >= 0 && rEnd > rStart) {
        const chunk = raw.slice(rStart, rEnd);
        const n = Math.min(chunk.length, size - insertOffset);
        if (n > 0) { skeleton.set(chunk.subarray(0, n), insertOffset); }
      }
      leftBytes -= frag.length - (isFirst ? pos.off : 0) -
        (isLast && index === nextIndex ? nextPos.off : 0);
      if (isFirst) { droppedLen += pos.off; }
    }
    return util.TextDecoder.create(cs).decodeToString(skeleton);
  }

  /** getSectionText（上游 :295-317）：整节全量拼装（骨架 + 全部 frag），无 fid/off 截取。
   * 仅在 getTextByHref 拿不到时兜底。
   */
  private static getSectionText(full: Uint8Array, section: Kf8Section, cs: string): string {
    const skel = section.skel;
    const frags = section.frags;
    const raw = full.slice(skel.offset, skel.offset + section.length);
    const skeleton = new Uint8Array(raw.length);
    const headLen = Math.min(skel.length, skeleton.length);
    skeleton.set(raw.slice(0, headLen), 0);
    let leftBytes = skeleton.length - skel.length;
    for (let i = 0; i < frags.length; i += 1) {
      const frag = frags[i];
      if (frag === undefined) { continue; }
      const insertOffset = frag.insertOffset - skel.offset;
      const offset = skel.length + frag.offset;
      const srcEnd = skeleton.length - leftBytes;
      if (insertOffset >= 0 && srcEnd > insertOffset) {
        const seg = skeleton.slice(insertOffset, srcEnd);
        const dst = insertOffset + frag.length;
        const n = Math.min(seg.length, skeleton.length - dst);
        if (dst >= 0 && n > 0) { skeleton.set(seg.subarray(0, n), dst); }
      }
      if (insertOffset >= 0) {
        const chunk = raw.slice(offset, offset + frag.length);
        const n = Math.min(chunk.length, skeleton.length - insertOffset);
        if (n > 0) { skeleton.set(chunk.subarray(0, n), insertOffset); }
      }
      leftBytes -= frag.length;
    }
    return util.TextDecoder.create(cs).decodeToString(skeleton);
  }

  /** 正文净化（上游 formatKeepImg 的字符级近似）+ kindle:embed 图片落盘（G9）。
   * 先把 <img ...kindle:embed:XXXX...> 换成 [[EPUB_IMAGE:file://...]] 标记并复制图片字节，
   * 再删其余标签；kindle:flow 是 CSS 不是图，随标签一起删掉、不留图标记。
   */
  private static formatChapterText(html: string, pdb: PdbFile, info: MobiInfo,
    imageDir: string): string {
    const copied = new Set<number>();
    const withImages = html.replace(/<img\b[^>]*\bkindle:embed:([0-9A-Za-z]+)[^>]*>/gi,
      (match: string, code: string): string => {
        const id = Kf8Book.fromBase32(code);
        if (id < 1) { return ''; }
        if (!copied.has(id)) {
          copied.add(id);
          try {
            const bytes = pdb.getRecord(info.resourceStart + id - 1);
            Kf8Book.writeImage(`${imageDir}/${id}.img`, bytes);
          } catch (_) {
            // 单张图取不到不影响正文（上游 getImage 也允许返回 null）。
          }
        }
        return `[[EPUB_IMAGE:file://${imageDir}/${id}.img]]`;
      });
    return Kf8Book.decodeXml(withImages
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
        if (value === 'apos') { return "'"; }
        if (value === 'nbsp') { return ' '; }
        const number = value.startsWith('#x')
          ? Number.parseInt(value.substring(2), 16) : Number.parseInt(value.substring(1), 10);
        return Number.isFinite(number) && number >= 0 && number <= 0xFFFF
          ? String.fromCharCode(number) : '';
      });
  }

  /** 封面（G12）：EXTH 201 coverOffset 优先、202 thumbnailOffset 兜底，值是资源相对索引，
   * getResource 内部加 resourceStart。原样落盘（内嵌图不压缩、直接是 JPEG/PNG）。
   */
  private static writeCover(pdb: PdbFile, info: MobiInfo, coversDir: string,
    bookId: string): string | undefined {
    const types: number[] = [201, 202];
    for (let t = 0; t < types.length; t += 1) {
      const type = types[t] ?? 0;
      const v = info.exth.get(type);
      if (typeof v !== 'number') { continue; }
      let bytes: Uint8Array;
      try {
        bytes = pdb.getRecord(info.resourceStart + v);
      } catch (_) {
        continue;
      }
      if (bytes.length < 8) { continue; }
      const path = `${coversDir}/${bookId}.img`;
      try {
        Kf8Book.writeImage(path, bytes);
        return `file://${path}`;
      } catch (_) {
        continue;
      }
    }
    return undefined;
  }

  /** 图片字节原样落盘（上游内嵌图不压缩）。 */
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

  /** EXTH 容错读取（G13）：只认字符串型元数据，uint 型（201/202）由 writeCover 处理。 */
  private static exthString(info: MobiInfo, type: number): string {
    const v = info.exth.get(type);
    return typeof v === 'string' ? v : '';
  }
}
