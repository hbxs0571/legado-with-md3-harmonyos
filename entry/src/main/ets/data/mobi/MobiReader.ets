import { cryptoFramework } from '@kit.CryptoArchitectureKit';
import { Decompressor, MobiDebugData, MobiInfo } from './MobiEntities';
import { createDecompressor, removeTrailingEntries } from './Decompress';
import { MobiHeader } from './MobiHeader';
import { PdbFile } from './PdbFile';

/** MOBI 总装与世代判定（上游 MobiReader.readMobi）。
 * G2：判据只按文件头 version（readUInt32(36)）>= 8 或 EXTH boundary(121)!=-1，
 * 绝不按后缀——Kindle 生成的 .mobi 里装 KF8 很常见，按后缀分支一定错。
 */
export class MobiReader {
  static readMobi(pdb: PdbFile): MobiInfo {
    const info = MobiHeader.parse(pdb.getRecord(0), pdb);
    info.isKF8 = info.version >= 8 || info.boundary !== -1;
    return info;
  }

  /** 组 debugMobi 产出：record 表 + 头部字段 meta，以及前 8 条 text record 解压字节。
   * 与 Python 参考 b10_pyref.py 逐字段、逐字节对齐，用于拉回 diff。
   */
  static buildDebugData(pdb: PdbFile, info: MobiInfo, stem: string): MobiDebugData {
    const decompressor: Decompressor = createDecompressor(pdb, info);
    const decoded: number[] = [];
    const take = Math.min(8, info.numTextRecords, Math.max(0, info.recordCount - 1));
    for (let k = 0; k < take; k += 1) {
      const ridx = 1 + k;
      if (ridx + 1 > pdb.records.length) { break; }
      const seg = removeTrailingEntries(pdb.getRecord(ridx), info.trailingFlags);
      const out = decompressor.decompress(seg);
      for (let j = 0; j < out.length; j += 1) { decoded.push(out[j] ?? 0); }
    }
    const text = new Uint8Array(decoded);
    return { stem: stem, meta: MobiReader.buildMeta(info, text), text: text };
  }

  private static buildMeta(info: MobiInfo, text: Uint8Array): string {
    const lines: string[] = [];
    lines.push('name=' + info.name);
    lines.push('type=' + info.type);
    lines.push('creator=' + info.creator);
    lines.push('fileSize=' + info.fileSize);
    lines.push('recordCount=' + info.recordCount);
    lines.push('compression=' + info.compression);
    lines.push('encoding=' + info.encoding);
    lines.push('version=' + info.version);
    lines.push('resourceStart=' + info.resourceStart);
    lines.push('huffcdic=' + info.huffcdic);
    lines.push('numHuffcdic=' + info.numHuffcdic);
    lines.push('exthFlag=' + info.exthFlag);
    lines.push('trailingFlags=' + info.trailingFlags);
    lines.push('numTextRecords=' + info.numTextRecords);
    lines.push('recordSize=' + info.recordSize);
    lines.push('textLength=' + info.textLength);
    lines.push('isKF8=' + (info.isKF8 ? '1' : '0'));
    lines.push('boundary=' + info.boundary);
    lines.push('title=' + info.title.split('\n').join(' ').split('\r').join(' '));
    for (let i = 0; i < info.records.length; i += 1) {
      const rec = info.records[i];
      if (rec === undefined) { continue; }
      lines.push('REC ' + i + ' ' + rec.offset + ' ' + rec.length);
    }
    lines.push('DUMP textBytes=' + text.length);
    lines.push('DUMP textSha256=' + MobiReader.sha256Hex(text));
    return lines.join('\n') + '\n';
  }

  private static sha256Hex(bytes: Uint8Array): string {
    const md = cryptoFramework.createMd('SHA256');
    md.updateSync({ data: new Uint8Array(bytes) });
    const digest = md.digestSync();
    let hex = '';
    for (let i = 0; i < digest.data.length; i += 1) {
      hex += (digest.data[i] as number).toString(16).padStart(2, '0');
    }
    return hex;
  }
}
