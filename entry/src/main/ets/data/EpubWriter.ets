import zlib from '@ohos.zlib';
import { util } from '@kit.ArkTS';

/**
 * 一个待写入 zip 的条目。写入顺序就是数组顺序。
 */
export interface EpubZipEntry {
  name: string;
  /** 未压缩的原始字节。 */
  data: Uint8Array;
}

/**
 * 手写 ZIP 序列化。
 *
 * 为什么不用 @ohos.zlib 的 compressFile：它只能整目录打包，既不能保证 mimetype 是第一条，
 * 也不能保证 mimetype 以 STORED 存放，而这两点是 EPUB（OCF）规范的硬要求；SDK 的
 * Options.level 只有整包统一档位，没有逐条目分项控制。上游 EpubWriter.java:167-175 同样是
 * 显式把 mimetype 建成 ZipEntry.STORED 并 setSize/setCrc。
 *
 * 只写三种结构：本地文件头 0x04034b50 / 中央目录 0x02014b50 / EOCD 0x06054b50。
 * 条目数远小于 65535、单文件远小于 4GB，因此不生成 zip64 扩展。
 */
export class EpubWriter {
  /** 规范要求保持 STORED 的条目名。 */
  private static readonly STORED_ONLY_NAME: string = 'mimetype';
  /** 上一次 build 是否走了「整包 STORED」兜底；为空表示走的是首选档。 */
  static lastFallbackReason: string = '';

  /**
   * 打包成 zip 字节流。
   * 首选 mimetype STORED + 其余条目 raw deflate；deflate 不可用时整包降级 STORED。
   */
  static async build(entries: EpubZipEntry[]): Promise<ArrayBuffer> {
    EpubWriter.lastFallbackReason = '';
    try {
      return await EpubWriter.buildWith(entries, true);
    } catch (error) {
      // 降级只有这一档：整包 STORED。绝不让 mimetype 被压缩——那是不合规，不是降级。
      EpubWriter.lastFallbackReason = error instanceof Error ? error.message : '未知错误';
      return await EpubWriter.buildWith(entries, false);
    }
  }

  private static async buildWith(entries: EpubZipEntry[], compress: boolean): Promise<ArrayBuffer> {
    const checksum = zlib.createChecksumSync();
    const output: number[] = [];
    const central: number[] = [];
    let offset = 0;
    for (let index = 0; index < entries.length; index++) {
      const entry = entries[index];
      if (entry === undefined) { continue; }
      const raw = entry.data;
      const crc = (await checksum.crc32(0, EpubWriter.arrayBufferOf(raw))) >>> 0;
      let method = 0;
      let payload = raw;
      // mimetype 永远 STORED：flags 的 bit3 保持 0、本地头里直接写死大小与 CRC。
      if (compress && entry.name !== EpubWriter.STORED_ONLY_NAME) {
        payload = await EpubWriter.deflateRaw(raw);
        method = 8;
      }
      const nameBytes = EpubWriter.utf8(entry.name);
      const local: number[] = [];
      EpubWriter.pushU32(local, 0x04034B50);
      EpubWriter.pushU16(local, 20);            // version needed to extract (2.0)
      EpubWriter.pushU16(local, 0);             // general purpose flags：bit3 = 0，不用数据描述符
      EpubWriter.pushU16(local, method);
      EpubWriter.pushU16(local, 0);             // mod time
      EpubWriter.pushU16(local, 0x0021);        // mod date：1980-01-01，仅占位
      EpubWriter.pushU32(local, crc);
      EpubWriter.pushU32(local, payload.length);
      EpubWriter.pushU32(local, raw.length);
      EpubWriter.pushU16(local, nameBytes.length);
      EpubWriter.pushU16(local, 0);             // extra field length
      EpubWriter.pushBytes(local, nameBytes);
      EpubWriter.pushBytes(local, payload);
      EpubWriter.pushBytes(output, EpubWriter.toBytes(local));

      EpubWriter.pushU32(central, 0x02014B50);
      EpubWriter.pushU16(central, 20);          // version made by
      EpubWriter.pushU16(central, 20);          // version needed to extract
      EpubWriter.pushU16(central, 0);
      EpubWriter.pushU16(central, method);
      EpubWriter.pushU16(central, 0);
      EpubWriter.pushU16(central, 0x0021);
      EpubWriter.pushU32(central, crc);
      EpubWriter.pushU32(central, payload.length);
      EpubWriter.pushU32(central, raw.length);
      EpubWriter.pushU16(central, nameBytes.length);
      EpubWriter.pushU16(central, 0);           // extra field length
      EpubWriter.pushU16(central, 0);           // file comment length
      EpubWriter.pushU16(central, 0);           // disk number start
      EpubWriter.pushU16(central, 0);           // internal file attributes
      EpubWriter.pushU32(central, 0);           // external file attributes
      EpubWriter.pushU32(central, offset);      // 本地文件头相对偏移
      EpubWriter.pushBytes(central, nameBytes);
      offset += local.length;
    }
    const centralOffset = offset;
    EpubWriter.pushBytes(output, EpubWriter.toBytes(central));
    const end: number[] = [];
    EpubWriter.pushU32(end, 0x06054B50);
    EpubWriter.pushU16(end, 0);                 // 当前磁盘号
    EpubWriter.pushU16(end, 0);                 // 中央目录起始磁盘号
    EpubWriter.pushU16(end, entries.length);    // 本磁盘条目数
    EpubWriter.pushU16(end, entries.length);    // 条目总数
    EpubWriter.pushU32(end, central.length);
    EpubWriter.pushU32(end, centralOffset);
    EpubWriter.pushU16(end, 0);                 // 注释长度
    EpubWriter.pushBytes(output, EpubWriter.toBytes(end));
    return EpubWriter.toBytes(output).buffer as ArrayBuffer;
  }

  /**
   * 裸 deflate（ZIP 条目要的是不带 zlib 头的裸流）。
   *
   * 先试流式 deflateInit2(windowBits=-15)；这条路在模拟器上 deflate 返回后 totalOut/availableOut
   * 都不回填，量不出产出长度，因此再试 compress2 生成的 zlib 流，剥掉 2 字节头与 4 字节 adler32。
   * 两条都失败才抛给上层整包降级 STORED。
   */
  private static async deflateRaw(source: Uint8Array): Promise<Uint8Array> {
    try {
      return await EpubWriter.deflateStreaming(source);
    } catch (_) {
      return await EpubWriter.deflateViaZlibStream(source);
    }
  }

  /** zlib 流去掉头尾就是裸 deflate：2 字节头 + 裸 deflate + 4 字节 adler32。 */
  private static async deflateViaZlibStream(source: Uint8Array): Promise<Uint8Array> {
    const zip = zlib.createZipSync();
    const input = EpubWriter.arrayBufferOf(source);
    const bound = await zip.compressBound(source.length);
    const dest = new ArrayBuffer(bound + 16);
    const info = await zip.compress2(dest, input,
      zlib.CompressLevel.COMPRESS_LEVEL_DEFAULT_COMPRESSION, source.length);
    const produced = info.destLen;
    if (produced <= 8 || produced > dest.byteLength) {
      throw new Error(`compress2 产出长度异常：${produced}`);
    }
    const zlibStream = new Uint8Array(dest, 0, produced);
    // 掐掉 2 字节 zlib 头与 4 字节 adler32，中间就是裸 deflate。
    return zlibStream.slice(2, produced - 4);
  }

  /** 流式裸 deflate（windowBits = -15）。 */
  private static async deflateStreaming(source: Uint8Array): Promise<Uint8Array> {
    const zip = zlib.createZipSync();
    const input = EpubWriter.arrayBufferOf(source);
    const bound = await zip.compressBound(source.length);
    const capacity = bound > 64 ? bound : source.length + 64;
    const output = new ArrayBuffer(capacity);
    const strm: zlib.ZStream = {
      nextIn: input,
      availableIn: source.length,
      nextOut: output,
      availableOut: capacity
    };
    const started = await zip.deflateInit2(strm, zlib.CompressLevel.COMPRESS_LEVEL_DEFAULT_COMPRESSION,
      zlib.CompressMethod.DEFLATED, -15, zlib.MemLevel.MEM_LEVEL_DEFAULT,
      zlib.CompressStrategy.COMPRESS_STRATEGY_DEFAULT_STRATEGY);
    if (started !== zlib.ReturnStatus.OK) {
      throw new Error(`deflateInit2 返回 ${started}`);
    }
    let status = await zip.deflate(strm, zlib.CompressFlushMode.FINISH);
    // 个别实现第一次只返回 OK（还没 flush 完），再补一次 FINISH；仍不是 STREAM_END 就交给兜底。
    let guard = 0;
    while (status === zlib.ReturnStatus.OK && guard < 4) {
      status = await zip.deflate(strm, zlib.CompressFlushMode.FINISH);
      guard += 1;
    }
    await zip.deflateEnd(strm);
    if (status !== zlib.ReturnStatus.STREAM_END) {
      throw new Error(`deflate 返回 ${status}`);
    }
    const produced = EpubWriter.producedBytes(strm, capacity);
    if (produced <= 0 || produced > capacity) {
      throw new Error('deflate 产出长度异常');
    }
    return new Uint8Array(output, 0, produced);
  }

  /** 量流式 deflate 的产出长度：totalOut 优先，其次看 availableOut 消耗，两者都为 0 视为失败。 */
  private static producedBytes(strm: zlib.ZStream, capacity: number): number {
    const total = strm.totalOut ?? 0;
    if (total > 0) { return total; }
    const available = strm.availableOut;
    if (available === undefined) { return 0; }
    const consumed = capacity - available;
    return consumed >= 0 ? consumed : 0;
  }

  private static utf8(text: string): Uint8Array {
    return new Uint8Array(new util.TextEncoder().encodeInto(text));
  }

  private static arrayBufferOf(bytes: Uint8Array): ArrayBuffer {
    if (bytes.byteOffset === 0 && bytes.byteLength === bytes.buffer.byteLength) {
      return bytes.buffer as ArrayBuffer;
    }
    return bytes.buffer.slice(bytes.byteOffset, bytes.byteOffset + bytes.byteLength) as ArrayBuffer;
  }

  private static toBytes(values: number[]): Uint8Array {
    const out = new Uint8Array(values.length);
    for (let index = 0; index < values.length; index++) {
      out[index] = values[index] ?? 0;
    }
    return out;
  }

  private static pushU16(target: number[], value: number): void {
    target.push(value & 0xFF, (value >>> 8) & 0xFF);
  }

  private static pushU32(target: number[], value: number): void {
    target.push(value & 0xFF, (value >>> 8) & 0xFF, (value >>> 16) & 0xFF, (value >>> 24) & 0xFF);
  }

  private static pushBytes(target: number[], bytes: Uint8Array): void {
    for (let index = 0; index < bytes.length; index++) {
      target.push(bytes[index] ?? 0);
    }
  }
}
