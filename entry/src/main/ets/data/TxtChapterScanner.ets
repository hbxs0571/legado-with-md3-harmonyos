import { fileIo } from '@kit.CoreFileKit';
import { util } from '@kit.ArkTS';

/**
 * TXT 目录流式扫描器。
 *
 * 目标：与 `BookRepository.splitChapters` 的输出**逐项相等**（titles / offsets / volumes / intro），
 * 但不再要求整本正文常驻内存。做法对齐上游
 * `app/src/main/java/io/legado/app/model/localBook/TextFile.kt` 的 `analyze(pattern, volumePattern)`（:160-353）：
 *
 * - `bufferSize = 512000`（:63），一次只持有一块字节；
 * - 块读满时从后往前找最后一个 `0x0a`（:186-193），把 `end` 退到那里，
 *   被切断的尾巴 `copyInto` 到缓冲头部留给下一轮 —— 保证一次只解码完整的行，
 *   也就顺带保证了不会把多字节字符从中间切开；
 * - 只在完整行上跑标题正则，行起点累加成字符偏移；
 * - 超长章二次拆分走「无目录切分」（上游 :217 / :342 调的是 `analyze(fileStart, fileEnd)`，
 *   即 :358 那个不带 pattern 的重载），阈值与断行规则与
 *   `BookRepository.buildNoTocChapterLayout` 逐行一致。
 *
 * 偏移口径：`offsets` 是**字符**偏移（与 `ChapterSplit.offsets` 同口径，调用方的
 * `buildChapterRows` 会再按 `charOffsetsToByteOffsets` 折算），`byteOffsets` 是同一位置在
 * 真实编码下的字节偏移（**不含 BOM**，与 `readChapterByByteRange` 的入参口径一致）。
 */

/** 按偏移读字节的最小接口。生产实现见 FileByteRangeSource，测试可注入内存桩。 */
export interface ByteRangeSource {
  size(): number;
  read(offset: number, length: number): Uint8Array;
}

/** 标题判定：入参是一行原文（已去掉行尾 `\r`，**未 trim**），返回是否命中。 */
export type TitleMatcher = (line: string) => boolean;

/** 一次流式扫描的结果。 */
export interface ChapterScanResult {
  /** 章节标题（长章已二次拆分，子章标题是 `原章名(N)`）。 */
  titles: string[];
  /** 每章的字符偏移，与 titles 一一对应。 */
  offsets: number[];
  /** 每章的字节偏移（真实编码，不含 BOM），与 titles 一一对应。 */
  byteOffsets: number[];
  /** 卷标记，与 titles 一一对应。 */
  volumes: boolean[];
  /** 第一个标题之前的正文（≤500 字符）；没有或全空白则 undefined。 */
  intro: string | undefined;
  /** 全书字符数（不含 BOM）。 */
  charCount: number;
  /** 全书字节数（真实编码，不含 BOM）。 */
  byteCount: number;
  /** 去掉全书首尾空白后的字符数，等价于 `content.trim().length`（totalWordCount 用）。 */
  trimmedCharCount: number;
}

/** 与上游 TextFile.kt:63 的 bufferSize 同值。 */
export const TXT_BLOCK_BYTES: number = 512000;
/** 与上游 TextFile.kt:66 的 maxLengthWithToc 同值。 */
export const TXT_MAX_LENGTH_WITH_TOC: number = 102400;
/** 长章二次拆分用的无目录阈值，与 BookRepository.appendChapterRange 传的 3000 同值。 */
export const TXT_NO_TOC_MAX_CHARS: number = 3000;
/** 无目录分段单段允许的最大字节数，与 buildNoTocChapterLayout 的 512000 同值。 */
export const TXT_NO_TOC_HARD_CAP: number = 512000;

/** 编码名归一化：与 BookRepository.normalizeEncoding 同口径。 */
function normalizeEncoding(encoding: string): string {
  const lower = encoding.trim().toLowerCase();
  if (lower.length === 0) { return 'utf-8'; }
  if (lower === 'gbk' || lower === 'gb2312' || lower === 'gb18030') { return 'gb18030'; }
  if (lower === 'unicode' || lower === 'utf-16') { return 'utf-16le'; }
  return lower;
}

/**
 * 单个字符在指定编码下占几个字节。
 * 必须与 `BookRepository.charByteWidth` 逐字一致，否则报出去的字节偏移会和
 * `charOffsetsToByteOffsets` 算出来的对不上，章节正文就会切歪。
 */
function charByteWidth(code: number, isHighSurrogateWithNext: boolean, encoding: string): number {
  if (encoding === 'utf-16le' || encoding === 'utf-16be') {
    return isHighSurrogateWithNext ? 4 : 2;
  }
  if (encoding === 'gb18030' || encoding === 'gbk' || encoding === 'big5') {
    if (code < 0x80) { return 1; }
    return isHighSurrogateWithNext ? 4 : 2;
  }
  if (code < 0x80) { return 1; }
  if (code < 0x800) { return 2; }
  return isHighSurrogateWithNext ? 4 : 3;
}

/**
 * `buildNoTocChapterLayout`（BookRepository.ets:2887-2924）用的宽度口径：
 * 代理对必须成对（高位 D800-DBFF + 低位 DC00-DFFF）才算 4 字节。
 * 这里单独写一份，因为长章拆分的阈值判定必须和它**完全相同**。
 */
function layoutWidth(text: string, index: number): number {
  const code = text.charCodeAt(index);
  const next = index + 1 < text.length ? text.charCodeAt(index + 1) : 0;
  const surrogatePair = code >= 0xD800 && code <= 0xDBFF && next >= 0xDC00 && next <= 0xDFFF;
  return surrogatePair ? 4 : code < 0x80 ? 1 : code < 0x800 ? 2 : 3;
}

/** 空白判定：与正则 `\s` 同一套字符集（String.prototype.trim 的判定等价）。 */
function isWhitespace(ch: string): boolean {
  return /\s/.test(ch);
}

/** 文本片段在指定编码下的字节数。 */
function byteWidthOf(text: string, encoding: string): number {
  let bytes = 0;
  let index = 0;
  while (index < text.length) {
    const code = text.charCodeAt(index);
    const pair = code >= 0xD800 && code <= 0xDBFF && index + 1 < text.length;
    const width = charByteWidth(code, pair, encoding);
    bytes += width;
    index += pair ? 2 : 1;
  }
  return bytes;
}

/** 换行字节序列；UTF-16 是两字节且必须按 2 字节对齐找。 */
function newlineBytes(encoding: string): number[] {
  if (encoding === 'utf-16le') { return [0x0A, 0x00]; }
  if (encoding === 'utf-16be') { return [0x00, 0x0A]; }
  return [0x0A];
}

/** 从字节序列尾部往前找最后一个换行，返回其起始下标；找不到返回 -1。 */
function lastNewlineIndex(bytes: Uint8Array, length: number, nl: number[]): number {
  if (nl.length === 1) {
    for (let i = length - 1; i >= 0; i--) {
      if (bytes[i] === nl[0]) { return i; }
    }
    return -1;
  }
  for (let i = length - 2; i >= 0; i--) {
    if (i % 2 !== 0) { continue; }
    if (bytes[i] === nl[0] && bytes[i + 1] === nl[1]) { return i; }
  }
  return -1;
}

/** 按 BOM 判正文起点；0 表示没有 BOM。 */
function bomLength(head: Uint8Array, encoding: string): number {
  if (encoding === 'utf-8') {
    if (head.length >= 3 && head[0] === 0xEF && head[1] === 0xBB && head[2] === 0xBF) { return 3; }
    return 0;
  }
  if (encoding === 'utf-16le') {
    if (head.length >= 2 && head[0] === 0xFF && head[1] === 0xFE) { return 2; }
    return 0;
  }
  if (encoding === 'utf-16be') {
    if (head.length >= 2 && head[0] === 0xFE && head[1] === 0xFF) { return 2; }
    return 0;
  }
  return 0;
}

/** 解码一块字节。块边界永远落在换行处，所以不会切在多字节字符中间。 */
function decodeBlock(bytes: Uint8Array, encoding: string): string {
  try {
    const decoder = util.TextDecoder.create(encoding, { fatal: true, ignoreBOM: true });
    return decoder.decodeToString(bytes);
  } catch (error) {
    throw new Error(`TXT 正文按 ${encoding} 解码失败：${error}`);
  }
}

/** 用 fileIo 实现的字节源。每次 read 单独开关文件，避免长期持有 fd。 */
export class FileByteRangeSource implements ByteRangeSource {
  private readonly path: string;
  private readonly fileSize: number;

  constructor(path: string, fileSize: number) {
    this.path = path;
    this.fileSize = fileSize;
  }

  size(): number {
    return this.fileSize;
  }

  read(offset: number, length: number): Uint8Array {
    if (length <= 0) { return new Uint8Array(0); }
    const sourceFile = fileIo.openSync(this.path, fileIo.OpenMode.READ_ONLY);
    try {
      const buffer = new ArrayBuffer(length);
      const bytesRead = fileIo.readSync(sourceFile.fd, buffer, { offset: offset, length: length });
      if (bytesRead <= 0) { return new Uint8Array(0); }
      return new Uint8Array(buffer, 0, bytesRead);
    } finally {
      fileIo.closeSync(sourceFile);
    }
  }
}

/** 内存字节源：离线验证用，生产不走这里。 */
export class MemoryByteRangeSource implements ByteRangeSource {
  private readonly bytes: Uint8Array;

  constructor(bytes: Uint8Array) {
    this.bytes = bytes;
  }

  size(): number {
    return this.bytes.length;
  }

  read(offset: number, length: number): Uint8Array {
    if (offset >= this.bytes.length || length <= 0) { return new Uint8Array(0); }
    const end = Math.min(this.bytes.length, offset + length);
    return this.bytes.subarray(offset, end);
  }
}

export class TxtChapterScanner {
  /**
   * 扫出全书章节。返回结果与 `BookRepository.splitChapters` 逐项相等。
   *
   * @param source 字节源
   * @param encoding 已探测好的正文编码
   * @param matchesTitle 标题判定函数（入参是去 `\r` 后的原始行，未 trim）
   * @param splitLongChapter 是否对超长章二次拆分（上游 `book.getSplitLongChapter()`）
   * @param markVolumes 按最终标题标卷；不传则全部 false
   * @param stopAfterFirstHit 只要「有没有标题」时传 true：命中第一个标题就停，不再读后面的块
   */
  static scan(source: ByteRangeSource, encoding: string, matchesTitle: TitleMatcher,
    splitLongChapter: boolean, markVolumes?: (titles: string[]) => boolean[],
    stopAfterFirstHit: boolean = false,
    maxLengthWithToc: number = TXT_MAX_LENGTH_WITH_TOC): ChapterScanResult {
    const normalized = normalizeEncoding(encoding);
    const size = source.size();
    const head = source.read(0, Math.min(size, 3));
    const dataStart = bomLength(head, normalized);
    const nl = newlineBytes(normalized);

    const starts: number[] = [];       // 标题行的字符偏移
    const startBytes: number[] = [];   // 同上位置的字节偏移（真实编码，不含 BOM）
    const startUtf8: number[] = [];    // 同上位置的 UTF-8 字节偏移（长章阈值用）
    const titles: string[] = [];

    let charCursor = 0;
    let byteCursor = 0;
    let utf8Cursor = 0;
    // 第一个标题之前的正文：只留前 500 字符做 intro，但「是否全空白」要覆盖整段。
    let headText = '';
    let headHasBody = false;
    // 全书首/末个非空白字符的字符下标（trimmedCharCount 用，等价 content.trim().length）。
    let firstBodyChar = -1;
    let lastBodyChar = -1;

    const buffer = new Uint8Array(TXT_BLOCK_BYTES);
    let carried = 0;
    let filePos = dataStart;
    let stopped = false;

    while (!stopped) {
      const want = TXT_BLOCK_BYTES - carried;
      const available = size - filePos;
      const take = Math.min(want, available);
      let written = 0;
      if (take > 0) {
        const chunk = source.read(filePos, take);
        if (chunk.length > 0) {
          buffer.set(chunk, carried);
          written = chunk.length;
          filePos += chunk.length;
        }
      }
      const filled = carried + written;
      const atEof = filePos >= size;
      if (filled <= 0) { break; }

      // 决定本轮能安全解码到哪里：非 EOF 时退到最后一个换行（整行边界），
      // EOF 时整块都解码（最后一行可能没有换行符）。
      let end = filled;
      if (!atEof) {
        const nlIndex = lastNewlineIndex(buffer, filled, nl);
        if (nlIndex < 0) {
          // 一整块里没有换行：极端长行。继续往下读会把 buffer 撑爆，
          // 按上游行为这时 `end` 会退到 0、把整块搬到下一轮，但那会死循环；
          // 这里直接整块解码（行被切断，标题正则只作用于完整行，故不会误判）。
          end = filled;
        } else {
          end = nlIndex + nl.length;
        }
      }

      const text = decodeBlock(new Uint8Array(buffer.buffer, 0, end), normalized);
      let lineStart = 0;
      while (lineStart < text.length || (lineStart === 0 && text.length === 0)) {
        if (text.length === 0) { break; }
        const nlIndex = text.indexOf('\n', lineStart);
        const hasNewline = nlIndex >= 0;
        const rawEnd = hasNewline ? nlIndex : text.length;
        const raw = text.substring(lineStart, rawEnd);
        const line = raw.length > 0 && raw.charCodeAt(raw.length - 1) === 13
          ? raw.substring(0, raw.length - 1) : raw;
        const lineChars = rawEnd - lineStart;

        // 记录全书首/末个非空白字符的绝对字符下标：等价 content.trim() 的范围。
        if (raw.trim().length > 0) {
          let lead = 0;
          while (lead < raw.length && isWhitespace(raw.charAt(lead))) { lead++; }
          let trail = raw.length - 1;
          while (trail >= 0 && isWhitespace(raw.charAt(trail))) { trail--; }
          if (firstBodyChar < 0) { firstBodyChar = charCursor + lead; }
          lastBodyChar = charCursor + trail;
        }

        const isTitle = line.trim().length > 0 && matchesTitle(line);

        // 前言只累积「第一个标题之前」的内容，且必须带上换行符，
        // 否则 intro 与 splitChapters 的 content.substring(0, starts[0]) 不一致。
        if (starts.length === 0 && !isTitle) {
          const consumedForHead = raw + (hasNewline ? '\n' : '');
          if (headText.length < 500) {
            const room = 500 - headText.length;
            headText += consumedForHead.length <= room
              ? consumedForHead : consumedForHead.substring(0, room);
          }
          if (!headHasBody && raw.trim().length > 0) { headHasBody = true; }
        }

        if (isTitle) {
          starts.push(charCursor);
          startBytes.push(byteCursor);
          startUtf8.push(utf8Cursor);
          titles.push(line.trim().substring(0, 80));
          if (stopAfterFirstHit) { stopped = true; break; }
        }

        // 推进游标：按原始行 + 换行符（若存在）计字符与字节。
        const consumed = raw + (hasNewline ? '\n' : '');
        charCursor += lineChars + (hasNewline ? 1 : 0);
        byteCursor += byteWidthOf(consumed, normalized);
        utf8Cursor += byteWidthOf(consumed, 'utf-8');
        if (!hasNewline) { break; }
        lineStart = nlIndex + 1;
      }

      // 未消费的字节（跨块残行）搬到缓冲头部。
      const tail = filled - end;
      if (tail > 0) { buffer.copyWithin(0, end, filled); }
      carried = tail;
      if (atEof) { break; }
      if (stopped) { break; }
    }

    const totalChars = charCursor;
    const totalBytes = byteCursor;
    // content.trim().length：首尾空白都去掉后的字符数。
    const trimmedCharCount = firstBodyChar >= 0 && lastBodyChar >= firstBodyChar
      ? lastBodyChar - firstBodyChar + 1 : 0;

    if (starts.length === 0) {
      return {
        titles: [], offsets: [], byteOffsets: [], volumes: [],
        intro: undefined, charCount: totalChars, byteCount: totalBytes,
        trimmedCharCount: trimmedCharCount
      };
    }

    // 组装章节：第一个标题之前有正文则先插「前言」（对齐 splitChapters:3622-3630）。
    let finalTitles: string[] = [];
    let finalOffsets: number[] = [];
    let finalBytes: number[] = [];
    let intro: string | undefined = undefined;
    if (starts[0] > 0 && headHasBody) {
      finalTitles.push('前言');
      finalOffsets.push(0);
      finalBytes.push(0);
      intro = headText.length <= 500 ? headText : headText.substring(0, 500);
    }
    for (let index = 0; index < starts.length; index++) {
      finalTitles.push(titles[index]);
      finalOffsets.push(starts[index]);
      finalBytes.push(startBytes[index]);
    }

    // 长章二次拆分（对齐 appendChapterRange:3657-3685）。
    if (splitLongChapter) {
      const splitTitles: string[] = [];
      const splitOffsets: number[] = [];
      const splitBytes: number[] = [];
      for (let index = 0; index < finalTitles.length; index++) {
        const title = finalTitles[index];
        const charStart = finalOffsets[index];
        const byteStart = finalBytes[index];
        const charEnd = index + 1 < finalOffsets.length ? finalOffsets[index + 1] : totalChars;
        const byteEnd = index + 1 < finalBytes.length ? finalBytes[index + 1] : totalBytes;
        // 「前言」章没有对应的 startUtf8 条目，但它不可能超长（≤500 字符），
        // 这里统一用 byteEnd - byteStart 在 UTF-8 下的近似——前言是纯 ASCII 以外的文本，
        // 用它自己的字符数判定更稳妥：字符数 ≤ 500 必然 ≤ 102400 字节。
        const isIntro = title === '前言' && charStart === 0 && index === 0 && intro !== undefined;
        let utf8Length: number;
        if (isIntro) {
          utf8Length = 0;
        } else {
          const startIndex = starts.indexOf(charStart);
          const utf8Start = startIndex >= 0 ? startUtf8[startIndex] : 0;
          const nextStartIndex = startIndex >= 0 ? startIndex + 1 : -1;
          const utf8End = nextStartIndex >= 0 && nextStartIndex < startUtf8.length
            ? startUtf8[nextStartIndex] : utf8Cursor;
          utf8Length = utf8End - utf8Start;
        }
        if (utf8Length <= maxLengthWithToc || charEnd <= charStart) {
          splitTitles.push(title);
          splitOffsets.push(charStart);
          splitBytes.push(byteStart);
          continue;
        }
        const parts = TxtChapterScanner.splitNoTocRange(source, normalized, byteStart, byteEnd,
          TXT_NO_TOC_MAX_CHARS);
        if (parts.length === 0) {
          splitTitles.push(title);
          splitOffsets.push(charStart);
          splitBytes.push(byteStart);
          continue;
        }
        for (let part = 0; part < parts.length; part++) {
          splitTitles.push(`${title}(${part + 1})`);
          splitOffsets.push(charStart + parts[part].charOffset);
          splitBytes.push(byteStart + parts[part].byteOffset);
        }
      }
      finalTitles = splitTitles;
      finalOffsets = splitOffsets;
      finalBytes = splitBytes;
    }

    const volumes = markVolumes !== undefined
      ? markVolumes(finalTitles) : TxtChapterScanner.noVolumes(finalTitles);
    return {
      titles: finalTitles, offsets: finalOffsets, byteOffsets: finalBytes, volumes: volumes,
      intro: intro, charCount: totalChars, byteCount: totalBytes,
      trimmedCharCount: trimmedCharCount
    };
  }

  private static noVolumes(titles: string[]): boolean[] {
    const flags: boolean[] = [];
    for (let index = 0; index < titles.length; index++) { flags.push(false); }
    return flags;
  }

  /**
   * 无目录分段。逐行对齐 `BookRepository.buildNoTocChapterLayout`（:2887-2924）：
   *
   * - `thresholdBytes = max(3000, min(100000, round(maxLengthWithNoToc))) * 3`（UTF-8 宽度）；
   * - 逐字符累加 UTF-8 宽度，`scannedBytes + width > 512000` 就在本字符前断开；
   * - `scannedBytes >= thresholdBytes` 且当前字符是 `\n` 时在换行处断开（换行归下一段）；
   * - 每段起点依次入列，返回的偏移**相对 `startByte`**。
   *
   * 之所以流式而不是先把整章读成字符串：一章可能上百 MB，整本读入就失去这次改造的意义。
   */
  static splitNoTocRange(source: ByteRangeSource, encoding: string,
    startByte: number, endByte: number, maxLengthWithNoToc: number): NoTocPart[] {
    const parts: NoTocPart[] = [];
    const from = Math.max(0, Math.min(startByte, endByte));
    const to = Math.max(from, endByte);
    if (to <= from) { return parts; }
    const normalized = normalizeEncoding(encoding);
    const nl = newlineBytes(normalized);
    const threshold = Math.max(3000, Math.min(100000, Math.round(maxLengthWithNoToc))) * 3;

    let charCursor = 0;
    let byteCursor = 0;
    let scannedBytes = 0;
    let partStartChar = 0;
    let partStartByte = 0;
    parts.push({ charOffset: 0, byteOffset: 0 });

    const buffer = new Uint8Array(TXT_BLOCK_BYTES);
    let carried = 0;
    let filePos = from;
    let ended = false;

    while (!ended) {
      const want = TXT_BLOCK_BYTES - carried;
      const available = to - filePos;
      const take = Math.min(want, available);
      let written = 0;
      if (take > 0) {
        const chunk = source.read(filePos, take);
        if (chunk.length > 0) {
          buffer.set(chunk, carried);
          written = chunk.length;
          filePos += chunk.length;
        }
      }
      const filled = carried + written;
      const atEof = filePos >= to;
      if (filled <= 0) { break; }

      let end = filled;
      if (!atEof) {
        const nlIndex = lastNewlineIndex(buffer, filled, nl);
        if (nlIndex >= 0) { end = nlIndex + nl.length; }
      }

      const text = decodeBlock(new Uint8Array(buffer.buffer, 0, end), normalized);
      let index = 0;
      while (index < text.length) {
        const code = text.charCodeAt(index);
        const next = index + 1 < text.length ? text.charCodeAt(index + 1) : 0;
        const pair = code >= 0xD800 && code <= 0xDBFF && next >= 0xDC00 && next <= 0xDFFF;
        const width = layoutWidth(text, index);
        const chars = pair ? 2 : 1;
        if (scannedBytes + width > TXT_NO_TOC_HARD_CAP) {
          // 硬上限：在本字符前断开，本字符成为下一段起点。
          parts.push({ charOffset: charCursor, byteOffset: byteCursor });
          partStartChar = charCursor;
          partStartByte = byteCursor;
          scannedBytes = 0;
          continue;
        }
        if (scannedBytes >= threshold && code === 10) {
          // 阈值达成且当前字符是换行：对齐 buildNoTocChapterLayout 的 `end = cursor; break;`
          // —— 断点在换行符「之前」，换行符归下一段。此处不能先消费换行再记偏移，
          // 否则每个断点都比整本口径晚一个字符。
          parts.push({ charOffset: charCursor, byteOffset: byteCursor });
          partStartChar = charCursor;
          partStartByte = byteCursor;
          scannedBytes = 0;
          continue;
        }
        scannedBytes += width;
        charCursor += chars;
        byteCursor += charByteWidth(code, pair, normalized);
        index += chars;
      }

      const tail = filled - end;
      if (tail > 0) { buffer.copyWithin(0, end, filled); }
      carried = tail;
      if (atEof) { break; }
    }

    // 与 buildNoTocChapterLayout 一致：最后一段若不足一段也保留（它的起点已入列），
    // 只有当整段内容为空时才没有任何偏移。
    const deduped: NoTocPart[] = [];
    for (let index = 0; index < parts.length; index++) {
      const item = parts[index];
      if (item.charOffset >= charCursor && index > 0) { continue; }
      deduped.push(item);
    }
    return deduped;
  }
}

/** 无目录分段的一段：偏移相对所在章起点。 */
export interface NoTocPart {
  charOffset: number;
  byteOffset: number;
}
