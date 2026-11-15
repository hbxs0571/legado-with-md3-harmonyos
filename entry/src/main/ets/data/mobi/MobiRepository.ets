import { fileIo } from '@kit.CoreFileKit';
import { MobiReader } from './MobiReader';
import { PdbFile } from './PdbFile';
import { Kf6Book } from './Kf6Book';
import { MobiImportResult } from './MobiEntities';

/** 批 10 调试入口的落盘实作：产 <stem>.meta.txt / <stem>.text.bin 到应用 filesDir，
 * 供 hdc 拉回与 Python 参考逐字节比对。本批不接阅读界面。
 */
export class MobiRepository {
  /** KF6 正文/目录/图片导入（批 11）；KF8 由 Kf6Book 抛可读错误，留到批 12。 */
  static async importFromUri(context: Context, uri: string, fileName: string,
    bookId: string): Promise<MobiImportResult> {
    return Kf6Book.importFromUri(context, uri, fileName, bookId);
  }

  static async debugMobi(context: Context, uri: string, stem: string): Promise<string> {
    const pdb = new PdbFile(uri);
    const info = MobiReader.readMobi(pdb);
    const data = MobiReader.buildDebugData(pdb, info, stem);
    const dir = `${context.filesDir}/mobi-debug`;
    MobiRepository.ensureDirectory(dir);
    MobiRepository.writeText(`${dir}/${stem}.meta.txt`, data.meta);
    MobiRepository.writeBytes(`${dir}/${stem}.text.bin`, data.text);
    return dir;
  }

  private static writeText(path: string, text: string): void {
    const file = fileIo.openSync(path,
      fileIo.OpenMode.WRITE_ONLY | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC);
    try {
      fileIo.writeSync(file.fd, text);
    } finally {
      fileIo.closeSync(file);
    }
  }

  private static writeBytes(path: string, bytes: Uint8Array): void {
    const file = fileIo.openSync(path,
      fileIo.OpenMode.WRITE_ONLY | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC);
    try {
      // writeSync 收 ArrayBuffer，Uint8Array 要先转成精确切片的 ArrayBuffer。
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
}
