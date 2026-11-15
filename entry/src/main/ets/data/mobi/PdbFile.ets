import { fileIo } from '@kit.CoreFileKit';
import { PdbRecord } from './MobiEntities';

/** PDB 容器（上游 PDBFile.kt）。
 * 上游靠 ParcelFileDescriptor + FileChannel 按记录绝对偏移 seek；
 * 但 ArkTS 的 readSync offset 是「当前 filePointer + offset」的相对量（@ohos.file.fs.d.ts:5691），
 * 按绝对记录偏移跳会错位。沿用批 6 UMD 一次读入、按绝对偏移切片的等价方案，
 * 正确性优先；26MB 样本一次读入也不 OOM（验收 #5）。
 */
export class PdbFile {
  private blob: Uint8Array;
  name: string = '';
  type: string = '';
  creator: string = '';
  fileSize: number = 0;
  recordCount: number = 0;
  records: PdbRecord[] = [];

  constructor(uri: string) {
    const file = fileIo.openSync(uri, fileIo.OpenMode.READ_ONLY);
    let bytes: Uint8Array;
    try {
      const size = fileIo.statSync(file.fd).size;
      const buffer = new ArrayBuffer(size);
      const read = fileIo.readSync(file.fd, buffer, { length: size });
      bytes = new Uint8Array(buffer, 0, Math.max(0, read));
    } finally {
      fileIo.closeSync(file);
    }
    this.blob = bytes;
    this.fileSize = bytes.length;
    this.name = PdbFile.ascii(bytes, 0, 32);
    this.type = PdbFile.ascii(bytes, 60, 4);
    this.creator = PdbFile.ascii(bytes, 64, 4);
    this.recordCount = PdbFile.be16(bytes, 76);
    this.records = [];
    for (let i = 0; i < this.recordCount; i += 1) {
      const offset = PdbFile.be32(bytes, 78 + i * 8);
      const next = i + 1 < this.recordCount ? PdbFile.be32(bytes, 78 + (i + 1) * 8) : this.fileSize;
      this.records.push({ offset: offset, length: Math.max(0, next - offset) });
    }
  }

  /** 某条记录的原始字节；越界抛错，与上游 getRecordData 一致。 */
  getRecord(index: number): Uint8Array {
    const rec = this.records[index];
    if (rec === undefined) { throw new Error('PDB 记录号越界'); }
    return this.blob.slice(rec.offset, rec.offset + rec.length);
  }

  static be16(b: Uint8Array, o: number): number {
    return (((b[o] ?? 0) << 8) | (b[o + 1] ?? 0)) & 0xffff;
  }

  /** 大端 32 位；<<24 会溢出成负数，末尾 >>>0 转回无符号。 */
  static be32(b: Uint8Array, o: number): number {
    return ((((b[o] ?? 0) << 24) | ((b[o + 1] ?? 0) << 16) |
      ((b[o + 2] ?? 0) << 8) | (b[o + 3] ?? 0)) >>> 0);
  }

  /** PDB 名/类型/creator 是定长 latin-1 字段，截断到第一个 NUL；真样本都是 ASCII。 */
  static ascii(b: Uint8Array, o: number, len: number): string {
    let s = '';
    for (let i = 0; i < len; i += 1) {
      const c = b[o + i] ?? 0;
      if (c === 0) { break; }
      s += String.fromCharCode(c);
    }
    return s;
  }
}
