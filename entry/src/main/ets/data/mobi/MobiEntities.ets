/** MOBI 底盘的数据结构与解压器接口（批 10）。
 * 上游 android.util.SparseArray 在三处只是 int→对象 映射（G14），
 * 这里 EXTH 直接用 Map<number, T>，不需要稀疏语义或 keyAt 遍历顺序。
 */
export interface PdbRecord {
  offset: number;
  length: number;
}

/** record0 解出的全部头字段 + 世代判定结果。 */
export interface MobiInfo {
  name: string;
  type: string;
  creator: string;
  fileSize: number;
  recordCount: number;
  records: PdbRecord[];
  compression: number;
  textLength: number;
  numTextRecords: number;
  recordSize: number;
  encoding: number;
  version: number;
  resourceStart: number;
  huffcdic: number;
  numHuffcdic: number;
  exthFlag: number;
  trailingFlags: number;
  title: string;
  exth: Map<number, string | number>;
  boundary: number;
  isKF8: boolean;
}

/** 解压器统一接口，对应上游 Decompressor。 */
export interface Decompressor {
  decompress(data: Uint8Array): Uint8Array;
}

/** debugMobi 的产出：meta 文本 + 解压字节，落盘后与 Python 参考逐字节比。 */
export interface MobiDebugData {
  stem: string;
  meta: string;
  text: Uint8Array;
}
