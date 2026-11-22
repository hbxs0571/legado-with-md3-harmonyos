import { taskpool, util } from '@kit.ArkTS';
import { fileIo } from '@kit.CoreFileKit';

/**
 * TXT 目录流式扫描器（worker 版）。
 *
 * ## 为什么要有这个文件
 *
 * 上游 `app/src/main/java/io/legado/app/model/localBook/TextFile.kt` 的 `analyze()`
 * 是**同步**函数，但它永远跑在 `BaseViewModel.execute {}` 里 ——
 * `app/src/main/java/io/legado/app/base/BaseViewModel.kt:21-30` 的 `execute` 默认
 * `context: CoroutineContext = Dispatchers.IO`，所以整条「读文件 → 解码 → 逐行匹配 →
 * 二次拆分 → 建章节行」的链路从头到尾都不在主线程。
 *
 * 本地没有协程调度器，对应手段是 taskpool：把整段扫描丢进 worker 线程，
 * 主线程只递文件路径、编码与正则源码，不参与逐行匹配。这条路径的先例与约束见
 * `entry/src/main/ets/data/TocRulePreviewEngine.ets:5` 与 `:22-23`：
 *
 * > 放主线程上必被 watchdog 判成 THREAD_BLOCK_6S。所以整段扫描丢进 taskpool。
 * > `@Concurrent` 只能引用 import 进来的变量或函数内的局部变量。
 *
 * 实测依据（E-028）：51.4MB / 18018492 字符 / 300 章的样本，`scan` 在设备主线程上
 * 即使做过热循环优化仍要 3856ms，加上读文件 500ms、规则解析 129ms 已经越过 6 秒
 * watchdog，进程被 `THREAD_BLOCK_6S` 杀掉（faultlog
 * `appfreeze-io.legado.harmony-...`）。所以「微优化主线程」这条路走不通，
 * 必须换线程 —— 这也正是上游的做法。
 *
 * ## 与整本口径的等价性
 *
 * 输出必须与 `BookRepository.splitChapters`（整本字符串版）**逐项相等**：
 * titles / offsets / volumes / intro / trimmedCharCount 全部一致。
 * 算法逐行对齐上游 `TextFile.kt:160-353` 的 `analyze(pattern, volumePattern)`：
 *
 * - `bufferSize = 512000`（上游 :63），一次只持有一块字节；
 * - 块读满时从后往前找最后一个 `0x0a`（上游 :186-193），`end` 退到那里，
 *   被切断的尾巴 `copyInto` 到缓冲头部留给下一轮 —— 保证只解码完整的行，
 *   顺带保证不会把多字节字符从中间切开；
 * - 标题正则只在完整行上跑，行起点累加成字符偏移；
 * - 超长章二次拆分走「无目录切分」（上游 :217 / :342 调的是 `analyze(fileStart, fileEnd)`，
 *   即 :358 那个不带 pattern 的重载），阈值与断行规则与
 *   `BookRepository.buildNoTocChapterLayout` 逐行一致。
 *
 * ## 偏移口径
 *
 * `offsets` 是**字符**偏移（与 `ChapterSplit.offsets` 同口径，调用方 `buildChapterRows`
 * 会再按 `charOffsetsToByteOffsets` 折算）；`byteOffsets` 是同一位置在真实编码下的
 * 字节偏移（**不含 BOM**，与 `readChapterByByteRange` 的入参口径一致）。
 */

/** 一次扫描的入参。跨线程传递，只带标量与字符串，不带整本正文。 */
export interface TxtScanRequest {
  /** 正文文件绝对路径。 */
  path: string;
  /** 已探测好的正文编码；空串按 utf-8。 */
  encoding: string;
  /** 章节规则（Java 风格正则，可带 `(?i)(?m)` 内联前缀）；空串表示不切章。 */
  chapterRule: string;
  /** 卷名规则；空串表示不标卷。 */
  volumeRule: string;
  /** 是否对超长章二次拆分（对应上游 `book.getSplitLongChapter()`）。 */
  splitLongChapter: boolean;
  /** 只要「有没有标题」时传 true：命中第一个标题就停，不再读后面的块。 */
  stopAfterFirstHit: boolean;
  /** 长章阈值（UTF-8 字节数），对应上游 `maxLengthWithToc = 102400`。 */
  maxLengthWithToc: number;
}

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
  /** 第一个标题之前的正文（≤500 字符）；没有或全空白时是空串。 */
  intro: string;
  /** 全书字符数（不含 BOM）。 */
  charCount: number;
  /** 全书字节数（真实编码，不含 BOM）。 */
  byteCount: number;
  /** 去掉全书首尾空白后的字符数，等价于 `content.trim().length`（totalWordCount 用）。 */
  trimmedCharCount: number;
}

/**
 * 在 worker 线程里扫出全书章节。
 *
 * 注意：本函数内**不能**引用本文件的模块级常量或模块级函数 ——
 * `@Concurrent` 只保证 import 进来的绑定与函数内局部变量可用。
 * 因此全部常量写成字面量（带注释标明与哪个常量同值），全部辅助函数写成局部箭头函数。
 * 这份算法与 `BookRepository.splitChapters` 是同一套规则的两种执行形态，
 * 任何一处改动都必须两边同步，并由 `tmp/b9-1007-verify.js` 一类的对跑脚本证明等价。
 */
@Concurrent
export function scanTextChaptersInWorker(request: TxtScanRequest): ChapterScanResult {
  // ---- 常量（与 TxtChapterScanner 导出的同名常量同值，此处必须写字面量）----
  // 上游 TextFile.kt:63 bufferSize
  const blockBytes: number = 512000;
  // 长章二次拆分阈值，与 BookRepository.appendChapterRange 传的 3000 同值
  const noTocMaxChars: number = 3000;
  // 无目录分段单段允许的最大字节数，与 buildNoTocChapterLayout 的 512000 同值
  const noTocHardCap: number = 512000;

  /** 编码名归一化：与 BookRepository.normalizeEncoding 同口径。 */
  const normalizeEncoding = (encoding: string): string => {
    const lower = encoding.trim().toLowerCase();
    if (lower.length === 0) { return 'utf-8'; }
    if (lower === 'gbk' || lower === 'gb2312' || lower === 'gb18030') { return 'gb18030'; }
    if (lower === 'unicode' || lower === 'utf-16') { return 'utf-16le'; }
    return lower;
  };

  /**
   * 单个字符在指定编码下占几个字节。
   * 必须与 `BookRepository.charByteWidth` 逐字一致，否则报出去的字节偏移会和
   * `charOffsetsToByteOffsets` 算出来的对不上，章节正文就会切歪。
   */
  const charByteWidth = (code: number, isHighSurrogateWithNext: boolean,
    encoding: string): number => {
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
  };

  /**
   * `buildNoTocChapterLayout`（BookRepository.ets:2887-2924）用的宽度口径：
   * 代理对必须成对（高位 D800-DBFF + 低位 DC00-DFFF）才算 4 字节。
   * 长章拆分的阈值判定必须与它**完全相同**，所以这里单独写一份。
   */
  const layoutWidth = (text: string, index: number): number => {
    const code = text.charCodeAt(index);
    const next = index + 1 < text.length ? text.charCodeAt(index + 1) : 0;
    const surrogatePair = code >= 0xD800 && code <= 0xDBFF && next >= 0xDC00 && next <= 0xDFFF;
    return surrogatePair ? 4 : code < 0x80 ? 1 : code < 0x800 ? 2 : 3;
  };

  /**
   * 空白判定：与 `String.prototype.trim` 同一套字符集。
   * 用码点判断而不是 `/\s/.test(ch)`：后者每次都要建一个单字符字符串，
   * 整本 1800 万字符扫下来光这一项就吃掉几百毫秒（E-028 实测项）。
   */
  const isWhitespaceCode = (code: number): boolean => {
    if (code === 32 || code === 9 || code === 10 || code === 13 || code === 11 || code === 12) {
      return true;
    }
    if (code < 0xA0) { return false; }
    if (code === 0xA0 || code === 0x1680) { return true; }
    if (code >= 0x2000 && code <= 0x200A) { return true; }
    if (code === 0x2028 || code === 0x2029 || code === 0x202F || code === 0x205F
      || code === 0x3000 || code === 0xFEFF) {
      return true;
    }
    return false;
  };

  /** 文本片段在指定编码下的字节数（逐字符调 charByteWidth）。 */
  const byteWidthOf = (text: string, encoding: string): number => {
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
  };

  /**
   * 文本片段在指定编码下的字节数（UTF-8 单次遍历内联宽度算式）。
   * 与 byteWidthOf 结果逐字相同，只是省掉每字符一次函数调用 ——
   * 整本 1800 万字符下这一项能省下几百毫秒。
   */
  const lineByteWidth = (text: string, encoding: string): number => {
    if (encoding === 'utf-8') {
      let bytes = 0;
      let index = 0;
      const length = text.length;
      while (index < length) {
        const code = text.charCodeAt(index);
        if (code < 0x80) {
          bytes += 1;
          index += 1;
        } else if (code < 0x800) {
          bytes += 2;
          index += 1;
        } else if (code >= 0xD800 && code <= 0xDBFF && index + 1 < length
          && text.charCodeAt(index + 1) >= 0xDC00 && text.charCodeAt(index + 1) <= 0xDFFF) {
          bytes += 4;
          index += 2;
        } else {
          bytes += 3;
          index += 1;
        }
      }
      return bytes;
    }
    return byteWidthOf(text, encoding);
  };

  /** 换行字节序列；UTF-16 是两字节且必须按 2 字节对齐找。 */
  const newlineBytes = (encoding: string): number[] => {
    if (encoding === 'utf-16le') { return [0x0A, 0x00]; }
    if (encoding === 'utf-16be') { return [0x00, 0x0A]; }
    return [0x0A];
  };

  /** 从字节序列尾部往前找最后一个换行，返回其起始下标；找不到返回 -1。 */
  const lastNewlineIndex = (bytes: Uint8Array, length: number, nl: number[]): number => {
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
  };

  /** 按 BOM 判正文起点；0 表示没有 BOM。 */
  const bomLength = (head: Uint8Array, encoding: string): number => {
    if (encoding === 'utf-8') {
      if (head.length >= 3 && head[0] === 0xEF && head[1] === 0xBB && head[2] === 0xBF) {
        return 3;
      }
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
  };

  /** 解码一块字节。块边界永远落在换行处，所以不会切在多字节字符中间。 */
  const decodeBlock = (bytes: Uint8Array, encoding: string): string => {
    try {
      const decoder = util.TextDecoder.create(encoding, { fatal: true, ignoreBOM: true });
      return decoder.decodeToString(bytes);
    } catch (error) {
      throw new Error(`TXT 正文按 ${encoding} 解码失败：${error}`);
    }
  };

  /**
   * 把 Java/Android 风格的正则（可带 `(?i)(?m)(?im)` 内联前缀）编译成 JS 正则。
   * 与 `TxtTocRuleRepository.compileRegex` 同口径；不合法返回 undefined。
   */
  const compileRuleRegex = (pattern: string): RegExp | undefined => {
    const trimmed = pattern.trim();
    if (trimmed.length === 0) { return undefined; }
    const inline = /^\(\?([ims]+)\)/.exec(trimmed);
    let source = trimmed;
    let flags = 'm';
    if (inline !== null) {
      const requested = inline[1] ?? '';
      source = trimmed.substring(inline[0].length);
      for (let index = 0; index < requested.length; index++) {
        const flag = requested.charAt(index);
        if (!flags.includes(flag)) { flags += flag; }
      }
    }
    try {
      return new RegExp(source, flags);
    } catch (error) {
      return undefined;
    }
  };

  const normalized = normalizeEncoding(request.encoding);
  const file = fileIo.openSync(request.path, fileIo.OpenMode.READ_ONLY);
  try {
    const size = fileIo.statSync(request.path).size;

    // 复用同一个 fd，并缓存最近读到的那一块（512KB 对齐）：
    // 长章二次拆分会对同一段反复读，早前每次 read 都 open/read/close，
    // 6000 章的书要做上万次文件开关，设备上慢到触发 6 秒 watchdog（E-028 实测项）。
    let cacheStart = -1;
    let cache: Uint8Array = new Uint8Array(0);
    // fileIo.readSync 的第二个参数必须是 ArrayBuffer，不能传 Uint8Array 视图
    // （设备实测会报 `Error: Invalid argument. Read failed. Invalid arraybuffer or options.`）。
    const readBytes = (offset: number, length: number): Uint8Array => {
      if (length <= 0) { return new Uint8Array(0); }
      const alignedStart = Math.floor(offset / blockBytes) * blockBytes;
      if (cacheStart !== alignedStart) {
        const want = Math.min(blockBytes, size - alignedStart);
        if (want > 0) {
          const raw = new ArrayBuffer(want);
          const read = fileIo.readSync(file.fd, raw, { offset: alignedStart, length: want });
          cache = read > 0 ? new Uint8Array(raw, 0, read) : new Uint8Array(0);
        } else {
          cache = new Uint8Array(0);
        }
        cacheStart = alignedStart;
      }
      if (offset + length <= cacheStart + cache.length) {
        return cache.subarray(offset - cacheStart, offset - cacheStart + length);
      }
      // 请求跨出缓存块：直接按区间读，避免静默截断。
      const directRaw = new ArrayBuffer(length);
      const got = fileIo.readSync(file.fd, directRaw, { offset: offset, length: length });
      return got > 0 ? new Uint8Array(directRaw, 0, got) : new Uint8Array(0);
    };

    const head = readBytes(0, Math.min(size, 3));
    const dataStart = bomLength(head, normalized);
    const nl = newlineBytes(normalized);
    const newlineByteWidth = charByteWidth(0x0A, false, normalized);
    const titleRegex = compileRuleRegex(request.chapterRule);
    const volumeRegex = compileRuleRegex(request.volumeRule);

    const starts: number[] = [];       // 标题行的字符偏移
    const startBytes: number[] = [];   // 同一位置的字节偏移（真实编码，不含 BOM）
    const startUtf8: number[] = [];    // 同一位置的 UTF-8 字节偏移（长章阈值用）
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

    const buffer = new Uint8Array(blockBytes);
    let carried = 0;
    let filePos = dataStart;
    let stopped = false;

    while (!stopped) {
      const want = blockBytes - carried;
      const available = size - filePos;
      const take = Math.min(want, available);
      let written = 0;
      if (take > 0) {
        const chunk = readBytes(filePos, take);
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
        if (nlIndex >= 0) {
          end = nlIndex + nl.length;
        }
        // 一整块里没有换行 = 极端长行。按上游行为这时 end 会退到 0、整块搬到下一轮，
        // 但那会死循环；这里直接整块解码（行被切断，标题正则只作用于完整行，不会误判）。
      }

      const text = decodeBlock(new Uint8Array(buffer.buffer, 0, end), normalized);
      let lineStart = 0;
      while (lineStart < text.length) {
        const nlIndex = text.indexOf('\n', lineStart);
        const hasNewline = nlIndex >= 0;
        const rawEnd = hasNewline ? nlIndex : text.length;
        const raw = text.substring(lineStart, rawEnd);
        const line = raw.length > 0 && raw.charCodeAt(raw.length - 1) === 13
          ? raw.substring(0, raw.length - 1) : raw;
        const lineChars = rawEnd - lineStart;

        // 记录全书首/末个非空白字符的绝对字符下标：等价 content.trim() 的范围。
        // 只扫首尾，不 trim 出中间串。
        let lead = 0;
        while (lead < raw.length && isWhitespaceCode(raw.charCodeAt(lead))) { lead++; }
        if (lead < raw.length) {
          let trail = raw.length - 1;
          while (trail >= 0 && isWhitespaceCode(raw.charCodeAt(trail))) { trail--; }
          if (firstBodyChar < 0) { firstBodyChar = charCursor + lead; }
          lastBodyChar = charCursor + trail;
        }

        let isTitle = false;
        if (titleRegex !== undefined && line.trim().length > 0) {
          titleRegex.lastIndex = 0;
          isTitle = titleRegex.test(line);
        }

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
          if (request.stopAfterFirstHit) {
            stopped = true;
            break;
          }
        }

        // 推进游标：按原始行 + 换行符（若存在）计字符与字节。
        // 早前每行拼一个 `raw + '\n'` 临时串、并分两次调 byteWidthOf 算两种编码宽度，
        // 整本 1800 万字符下扫描要 7 秒，直接超过 6 秒 watchdog（E-028）。
        charCursor += lineChars + (hasNewline ? 1 : 0);
        byteCursor += lineByteWidth(raw, normalized);
        utf8Cursor += lineByteWidth(raw, 'utf-8');
        if (hasNewline) {
          byteCursor += newlineByteWidth;
          utf8Cursor += 1;
        }
        if (!hasNewline) { break; }
        lineStart = nlIndex + 1;
      }

      // 未消费的字节（跨块残行）搬到缓冲头部。
      const tail = filled - end;
      if (tail > 0) { buffer.copyWithin(0, end, filled); }
      carried = tail;
      if (atEof) { break; }
    }

    const totalChars = charCursor;
    const totalBytes = byteCursor;
    // content.trim().length：首尾空白都去掉后的字符数。
    const trimmedCharCount = firstBodyChar >= 0 && lastBodyChar >= firstBodyChar
      ? lastBodyChar - firstBodyChar + 1 : 0;

    if (starts.length === 0) {
      return {
        titles: [], offsets: [], byteOffsets: [], volumes: [], intro: '',
        charCount: totalChars, byteCount: totalBytes, trimmedCharCount: trimmedCharCount
      };
    }

    // 组装章节：第一个标题之前有正文则先插「前言」（对齐 splitChapters:3622-3630）。
    const finalTitles: string[] = [];
    const finalOffsets: number[] = [];
    const finalBytes: number[] = [];
    let intro = '';
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

    /**
     * 无目录分段。逐行对齐 `BookRepository.buildNoTocChapterLayout`（:2887-2924）：
     * - `thresholdBytes = max(3000, min(100000, round(maxLengthWithNoToc))) * 3`（UTF-8 宽度）；
     * - 逐字符累加 UTF-8 宽度，`scannedBytes + width > 512000` 就在本字符前断开；
     * - `scannedBytes >= thresholdBytes` 且当前字符是 `\n` 时在换行处断开（换行归下一段）。
     */
    const splitNoTocRange = (startByte: number, endByte: number): number[] => {
      // 返回值用扁平数组 [charOffset0, byteOffset0, charOffset1, byteOffset1, ...]，
      // 因为 ArkTS 不允许在 @Concurrent 里构造未声明类型的对象字面量。
      const flat: number[] = [];
      const from = Math.max(0, Math.min(startByte, endByte));
      const to = Math.max(from, endByte);
      if (to <= from) { return flat; }
      const threshold = Math.max(3000, Math.min(100000, noTocMaxChars)) * 3;

      let charCursorInner = 0;
      let byteCursorInner = 0;
      let scannedBytes = 0;
      flat.push(0);
      flat.push(0);

      // 缓冲按「这一段实际有多长」分配，不要每段都开 512KB：
      // 6000 章各拆 20 段时，512KB × 6000 次分配会把堆压到 GC 抖动（E-028 实测项）。
      const bufferBytes = Math.min(blockBytes, to - from);
      const block = new Uint8Array(bufferBytes);
      let tailBytes = 0;
      let pos = from;

      while (true) {
        const wantBytes = bufferBytes - tailBytes;
        const left = to - pos;
        const takeBytes = Math.min(wantBytes, left);
        let got = 0;
        if (takeBytes > 0) {
          const chunk = readBytes(pos, takeBytes);
          if (chunk.length > 0) {
            block.set(chunk, tailBytes);
            got = chunk.length;
            pos += chunk.length;
          }
        }
        const filledInner = tailBytes + got;
        const atEnd = pos >= to;
        if (filledInner <= 0) { break; }

        let endInner = filledInner;
        if (!atEnd) {
          const nlIndex = lastNewlineIndex(block, filledInner, nl);
          if (nlIndex >= 0) { endInner = nlIndex + nl.length; }
        }

        const text = decodeBlock(new Uint8Array(block.buffer, 0, endInner), normalized);
        let index = 0;
        while (index < text.length) {
          const code = text.charCodeAt(index);
          const next = index + 1 < text.length ? text.charCodeAt(index + 1) : 0;
          const pair = code >= 0xD800 && code <= 0xDBFF && next >= 0xDC00 && next <= 0xDFFF;
          const width = layoutWidth(text, index);
          const chars = pair ? 2 : 1;
          if (scannedBytes + width > noTocHardCap) {
            // 硬上限：在本字符前断开，本字符成为下一段起点。
            flat.push(charCursorInner);
            flat.push(byteCursorInner);
            scannedBytes = 0;
            continue;
          }
          if (scannedBytes >= threshold && code === 10) {
            // 阈值达成且当前字符是换行：对齐 buildNoTocChapterLayout 的 `end = cursor; break;`
            // —— 断点在换行符「之前」，换行符归下一段。此处不能先消费换行再记偏移，
            // 否则每个断点都比整本口径晚一个字符（这个 bug 曾让验证脚本报 10 处 FAIL）。
            flat.push(charCursorInner);
            flat.push(byteCursorInner);
            scannedBytes = 0;
            continue;
          }
          scannedBytes += width;
          charCursorInner += chars;
          byteCursorInner += charByteWidth(code, pair, normalized);
          index += chars;
        }

        const rest = filledInner - endInner;
        if (rest > 0) { block.copyWithin(0, endInner, filledInner); }
        tailBytes = rest;
        if (atEnd) { break; }
      }

      // 与 buildNoTocChapterLayout 一致：末段若不足一段也保留（起点已入列），
      // 只有当偏移落到段尾之后才剔除。
      const deduped: number[] = [];
      for (let index = 0; index < flat.length; index += 2) {
        const charOffset = flat[index];
        if (charOffset >= charCursorInner && index > 0) { continue; }
        deduped.push(charOffset);
        deduped.push(flat[index + 1]);
      }
      return deduped;
    };

    // 长章二次拆分（对齐 appendChapterRange:3657-3685）。
    if (request.splitLongChapter) {
      const splitTitles: string[] = [];
      const splitOffsets: number[] = [];
      const splitBytes: number[] = [];
      // finalTitles 的前缀可能是「前言」，其后与 starts 逐项对应，
      // 所以下标可以直接对齐，不必对每个标题做 starts.indexOf：
      // 6000 章的书那样会退化成 O(n²) 的线性查找，设备上直接卡到 watchdog（E-028 实测项）。
      const headOffset = (starts[0] > 0 && headHasBody) ? 1 : 0;
      for (let index = 0; index < finalTitles.length; index++) {
        const title = finalTitles[index];
        const charStart = finalOffsets[index];
        const byteStart = finalBytes[index];
        const charEnd = index + 1 < finalOffsets.length ? finalOffsets[index + 1] : totalChars;
        const byteEnd = index + 1 < finalBytes.length ? finalBytes[index + 1] : totalBytes;
        // 「前言」章没有对应的 startUtf8 条目，但它不可能超长（≤500 字符）。
        const isIntro = headOffset === 1 && index === 0;
        let utf8Length = 0;
        if (!isIntro) {
          const startIndex = index - headOffset;
          const utf8Start = startIndex >= 0 && startIndex < startUtf8.length
            ? startUtf8[startIndex] : 0;
          const nextStartIndex = startIndex + 1;
          const utf8End = nextStartIndex >= 0 && nextStartIndex < startUtf8.length
            ? startUtf8[nextStartIndex] : utf8Cursor;
          utf8Length = utf8End - utf8Start;
        }
        if (utf8Length <= request.maxLengthWithToc || charEnd <= charStart) {
          splitTitles.push(title);
          splitOffsets.push(charStart);
          splitBytes.push(byteStart);
          continue;
        }
        const parts = splitNoTocRange(byteStart, byteEnd);
        if (parts.length === 0) {
          splitTitles.push(title);
          splitOffsets.push(charStart);
          splitBytes.push(byteStart);
          continue;
        }
        for (let part = 0; part < parts.length; part += 2) {
          splitTitles.push(`${title}(${part / 2 + 1})`);
          splitOffsets.push(charStart + parts[part]);
          splitBytes.push(byteStart + parts[part + 1]);
        }
      }
      finalTitles.length = 0;
      finalOffsets.length = 0;
      finalBytes.length = 0;
      for (let index = 0; index < splitTitles.length; index++) {
        finalTitles.push(splitTitles[index]);
        finalOffsets.push(splitOffsets[index]);
        finalBytes.push(splitBytes[index]);
      }
    }

    const volumes: boolean[] = [];
    for (let index = 0; index < finalTitles.length; index++) {
      const title = finalTitles[index] ?? '';
      let isVolume = false;
      if (volumeRegex !== undefined) {
        volumeRegex.lastIndex = 0;
        isVolume = volumeRegex.test(title);
      }
      volumes.push(isVolume);
    }

    return {
      titles: finalTitles, offsets: finalOffsets, byteOffsets: finalBytes, volumes: volumes,
      intro: intro, charCount: totalChars, byteCount: totalBytes,
      trimmedCharCount: trimmedCharCount
    };
  } finally {
    fileIo.closeSync(file);
  }
}

/**
 * 流式目录扫描的对外入口。
 *
 * 主线程只做参数打包与结果接收，真正的读文件、解码、逐行匹配全部在 worker 里完成。
 * 对应上游把 `TextFile.analyze()` 放在 `BaseViewModel.execute {}`（默认 `Dispatchers.IO`）
 * 里跑的做法，见文件头注释。
 */
export class TxtChapterScanner {
  /**
   * 扫出全书章节。结果与 `BookRepository.splitChapters` 逐项相等。
   *
   * @param request 扫描参数（路径、编码、正则源码、阈值），不含正文本身。
   */
  static async scan(request: TxtScanRequest): Promise<ChapterScanResult> {
    const task = new taskpool.Task(scanTextChaptersInWorker, request);
    const value = await taskpool.execute(task);
    return value as ChapterScanResult;
  }
}
