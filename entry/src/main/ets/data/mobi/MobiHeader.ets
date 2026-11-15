import { util } from '@kit.ArkTS';
import { MobiInfo } from './MobiEntities';
import { PdbFile } from './PdbFile';

/** record0 解包（上游 MobiReader.readMobiEntryHeaders / readPalmDocHeader / readMobiHeader / readExth）。
 * 全部偏移是 record0 内的绝对位置、大端，与 MobiReader.kt:968-1014 一致。
 */
export class MobiHeader {
  static parse(record0: Uint8Array, pdb: PdbFile): MobiInfo {
    const decoder = util.TextDecoder.create('utf-8');
    const info: MobiInfo = {
      name: pdb.name, type: pdb.type, creator: pdb.creator,
      fileSize: pdb.fileSize, recordCount: pdb.recordCount, records: pdb.records,
      compression: PdbFile.be16(record0, 0), textLength: PdbFile.be32(record0, 4),
      numTextRecords: PdbFile.be16(record0, 8), recordSize: PdbFile.be16(record0, 10),
      encoding: PdbFile.be32(record0, 28), version: PdbFile.be32(record0, 36),
      resourceStart: PdbFile.be32(record0, 108), huffcdic: PdbFile.be32(record0, 112),
      numHuffcdic: PdbFile.be32(record0, 116), exthFlag: PdbFile.be32(record0, 128),
      trailingFlags: PdbFile.be32(record0, 240), title: '',
      exth: new Map<number, string | number>(), boundary: -1, isKF8: false,
      indx: record0.length >= 248 ? PdbFile.be32(record0, 244) : 0xFFFFFFFF,
    };
    const hdrLen = PdbFile.be32(record0, 20);
    const titleOffset = PdbFile.be32(record0, 84);
    const titleLength = PdbFile.be32(record0, 88);
    if (titleLength > 0) {
      info.title = decoder.decodeToString(record0.slice(titleOffset, titleOffset + titleLength));
    }
    // EXTH 起点 = record0 + (hdrLen + 16)，见 MobiReader.readMobiEntryHeaders:922。
    info.exth = MobiHeader.readExth(record0, hdrLen + 16, info.exthFlag);
    const b = info.exth.get(121);
    info.boundary = typeof b === 'number' ? b : -1;
    const t = info.exth.get(503);
    if (typeof t === 'string' && t.length > 0) { info.title = t; }
    return info;
  }

  /** EXTH 记录串：类型号 + 长度 + 内容；uint 型（121/125/201/202/204）取 be32，其余按 UTF-8 解。 */
  private static readExth(r0: Uint8Array, start: number, exthFlag: number): Map<number, string | number> {
    const map: Map<number, string | number> = new Map<number, string | number>();
    const decoder = util.TextDecoder.create('utf-8');
    if ((exthFlag & 0x40) === 0) { return map; }
    if (start + 12 > r0.length || PdbFile.ascii(r0, start, 4) !== 'EXTH') { return map; }
    const count = PdbFile.be32(r0, start + 8);
    let off = start + 12;
    for (let n = 0; n < count; n += 1) {
      if (off + 8 > r0.length) { break; }
      const rtype = PdbFile.be32(r0, off);
      const rlen = PdbFile.be32(r0, off + 4);
      if (rlen < 8 || off + rlen > r0.length) { break; }
      const payload = r0.slice(off + 8, off + rlen);
      const isUint = rtype === 121 || rtype === 125 || rtype === 201 || rtype === 202 || rtype === 204;
      if (isUint && payload.length >= 4) {
        map.set(rtype, PdbFile.be32(payload, 0));
      } else {
        map.set(rtype, decoder.decodeToString(payload));
      }
      off += rlen;
    }
    return map;
  }
}
