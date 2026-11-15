import { Decompressor, MobiInfo } from './MobiEntities';
import { PdbFile } from './PdbFile';

/** 去尾条目（上游 MobiBook.removeTrailingEntries:582-604）。
 * trailingFlags 的每个置位（除 bit0）对应一个 7-bit varint 尾部条目，累加出要截掉的长度。
 */
export function removeTrailingEntries(bytes: Uint8Array, trailingFlags: number): Uint8Array {
  if (trailingFlags === 0) { return bytes; }
  const multibyte = (trailingFlags & 1) !== 0;
  const num = countOneBits(trailingFlags >>> 1);
  const lastIndex = bytes.length - 1;
  let extraSize = 0;
  for (let k = 0; k < num; k += 1) {
    let value = 0;
    const lo = Math.max(0, lastIndex - 4 - extraSize);
    const hi = Math.max(0, lastIndex - extraSize);
    for (let j = lo; j <= hi; j += 1) {
      const byte = bytes[j] ?? 0;
      if ((byte & 0x80) !== 0) { value = 0; }
      value = (value << 7) | (byte & 0x7f);
    }
    extraSize += value;
  }
  if (multibyte) {
    const byte = bytes[lastIndex - extraSize] ?? 0;
    extraSize += (byte & 0b11) + 1;
  }
  const cut = Math.max(0, bytes.length - extraSize);
  return bytes.slice(0, cut);
}

function countOneBits(x: number): number {
  let v = x >>> 0;
  let count = 0;
  while (v !== 0) { count += v & 1; v = v >>> 1; }
  return count;
}

/** comp=1 无压缩。 */
class PlainDecompressor implements Decompressor {
  decompress(data: Uint8Array): Uint8Array { return data; }
}

/** PalmDOC LZ77（上游 Lz77Decompressor.kt:1303-1352，1:1）。
 * 上游把 SynchronizedPool 当 ByteArray 池用，这里换动态数组，不需要预分配 textRecordSize。
 */
class Lz77Decompressor implements Decompressor {
  private textRecordSize: number;
  constructor(textRecordSize: number) { this.textRecordSize = textRecordSize; }

  decompress(data: Uint8Array): Uint8Array {
    const out: number[] = [];
    let i = 0;
    const n = data.length;
    while (i < n) {
      const c = data[i] ?? 0;
      i += 1;
      if (c >= 1 && c <= 8) {
        for (let j = 0; j < c && i < n; j += 1) { out.push(data[i] ?? 0); i += 1; }
      } else if (c <= 0x7f) {
        out.push(c);
      } else if (c >= 0xc0) {
        out.push(0x20);
        out.push(c ^ 0x80);
      } else {
        if (i < n) {
          const c2 = data[i] ?? 0;
          i += 1;
          const di = (c << 8) | c2;
          const length = (di & 7) + 3;
          const location = (di >> 3) & 0x7ff;
          if (location >= 1 && location <= out.length) {
            for (let j = 0; j < length; j += 1) {
              out.push(out[out.length - location] ?? 0);
            }
          }
        }
      }
    }
    return new Uint8Array(out);
  }
}

interface CdicEntry {
  data: Uint8Array;
  decompressed: boolean;
}

/** Huff/CDIC 解压（上游 HuffcdicDecompressor.kt:1182-1301，1:1）。
 * 上游用 Kotlin Long 做 64 位位移；ArkTS 用 bigint 忠实表示，避免 Number 在 2^53 以上丢精度。
 * 盘上四本真书全是 compression=2，没有 comp=17480 样本，此实现只能靠源码依据，未设备验证。
 */
class HuffcdicDecompressor implements Decompressor {
  private table1: number[] = [];
  private mincodeTable: bigint[] = [];
  private maxcodeTable: bigint[] = [];
  private dictionary: CdicEntry[] = [];

  constructor(pdb: PdbFile, mobi: MobiInfo) {
    const huff = pdb.getRecord(mobi.huffcdic);
    if (PdbFile.ascii(huff, 0, 4) !== 'HUFF') { throw new Error('HUFF 记录 magic 不对'); }
    const offset1 = PdbFile.be32(huff, 8);
    const offset2 = PdbFile.be32(huff, 12);
    for (let i = 0; i < 256; i += 1) { this.table1.push(PdbFile.be32(huff, offset1 + i * 4)); }
    let pos = offset2;
    this.mincodeTable = new Array<bigint>(33).fill(0n);
    this.maxcodeTable = new Array<bigint>(33).fill(0n);
    for (let i = 1; i <= 32; i += 1) {
      const mincode = BigInt(PdbFile.be32(huff, pos));
      const maxcode = BigInt(PdbFile.be32(huff, pos + 4));
      pos += 8;
      const shift = BigInt(32 - i);
      this.mincodeTable[i] = mincode << shift;
      this.maxcodeTable[i] = ((maxcode + 1n) << shift) - 1n;
    }
    for (let i = 1; i < mobi.numHuffcdic; i += 1) {
      const record = pdb.getRecord(mobi.huffcdic + i);
      if (PdbFile.ascii(record, 0, 4) !== 'CDIC') { throw new Error('CDIC 记录 magic 不对'); }
      const length = PdbFile.be32(record, 4);
      const numEntries = PdbFile.be32(record, 8);
      const codeLength = PdbFile.be32(record, 12);
      const want = Math.min(Math.pow(2, codeLength), numEntries - this.dictionary.length);
      for (let j = 0; j < want; j += 1) {
        const off = PdbFile.be16(record, length + j * 2);
        const x = PdbFile.be16(record, length + off);
        const len = x & 0x7fff;
        const decompressed = (x & 0x8000) !== 0;
        const data = record.slice(length + off + 2, length + off + 2 + len);
        this.dictionary.push({ data: data, decompressed: decompressed });
      }
    }
  }

  decompress(data: Uint8Array): Uint8Array {
    let bitsleft = data.length * 8;
    let pos = 0;
    let x = HuffcdicDecompressor.readUIntX(data, pos, 8);
    let bitcount = 32;
    const out: number[] = [];
    while (true) {
      if (bitcount <= 0) {
        pos += 4;
        x = HuffcdicDecompressor.readUIntX(data, pos, 8);
        bitcount += 32;
      }
      const code = (x >> BigInt(bitcount)) & 0xffffffffn;
      const t1 = this.table1[Number((code >> 24n) & 0xffn)] ?? 0;
      let codelen = t1 & 0x1f;
      let maxcode = ((BigInt(t1 >>> 8) + 1n) << BigInt(32 - codelen)) - 1n;
      if ((t1 & 0x80) === 0) {
        while (code < (this.mincodeTable[codelen] ?? 0n)) { codelen += 1; }
        maxcode = this.maxcodeTable[codelen] ?? 0n;
      }
      bitcount -= codelen;
      bitsleft -= codelen;
      if (bitsleft < 0) { break; }
      const index = Number((maxcode - code) >> BigInt(32 - codelen));
      const entry = this.dictionary[index];
      if (entry === undefined) { break; }
      let bytes = entry.data;
      if (!entry.decompressed) {
        bytes = this.decompress(bytes);
        entry.data = bytes;
        entry.decompressed = true;
      }
      for (let k = 0; k < bytes.length; k += 1) { out.push(bytes[k] ?? 0); }
    }
    return new Uint8Array(out);
  }

  /** 上游 readUIntX：从 offset 起最多 8 字节大端拼成 Long（bigint）。 */
  private static readUIntX(data: Uint8Array, offset: number, maxlen: number): bigint {
    let value = 0n;
    let i = maxlen;
    let bytesLeft = data.length - offset;
    let p = offset;
    while (i > 0 && bytesLeft > 0) {
      i -= 1;
      bytesLeft -= 1;
      value = value | (BigInt(data[p] ?? 0) << BigInt(i * 8));
      p += 1;
    }
    return value;
  }
}

/** 按 PalmDOC compression 分派（MobiBook.kt:468-473）。 */
export function createDecompressor(pdb: PdbFile, mobi: MobiInfo): Decompressor {
  if (mobi.compression === 1) { return new PlainDecompressor(); }
  if (mobi.compression === 2) { return new Lz77Decompressor(Math.max(4096, mobi.recordSize)); }
  if (mobi.compression === 17480) { return new HuffcdicDecompressor(pdb, mobi); }
  throw new Error('不支持的 MOBI 压缩方式：' + mobi.compression);
}
