import { media } from '@kit.MediaKit';
import { rcp } from '@kit.RemoteCommunicationKit';
import { fileIo as fs } from '@kit.CoreFileKit';
import { util } from '@kit.ArkTS';
import { BusinessError } from '@kit.BasicServicesKit';
import { HttpTts } from '../model/HttpTts';
import { ReadAloudVoice } from '../model/ReadAloudVoice';
import { md5Hex32 } from '../data/BackupCrypto';

/**
 * 批8：HTTP 朗读源的合成与播放（对齐上游 HttpTtsAudioSynthesizer + AVPlayer）。
 *
 * 与系统 TTS 的关键差异：
 * - 系统 TTS 的 speak 只能吃文本、且无调速；HTTP 源返回的是音频字节，
 *   本类把每段的音频下载到 cacheDir 临时文件，用 AVPlayer(fdSrc) 播放。
 * - 只有这里 setSpeed 真生效：ttsSpeechRate(1..10) 映射到 AVPlayer 的 10 档 PlaybackSpeed，
 *   这是批5「系统朗读不支持调速，此设置用于 HTTP 朗读源」那句话的落点。
 *
 * 平台边界（如实记录，任务书 8.4）：
 * - 上游 AnalyzeUrl 的 {{...}} 模板与 JS、loginCheckJs、jsLib 都依赖 Rhino；
 *   鸿蒙无 JS 引擎，这些字段只保留不执行。用户源必须是纯 URL 源。
 * - 本地 URL 拼接固定为：{url}?{textParam}={编码正文}&{speedParam}={speakSpeed}&{toneParam}={speakerId}；
 *   参数名为空串时不发该项；url 已含 ? 时用 & 追加。
 */
export interface HttpTtsSpeakCallbacks {
  onComplete: () => void;
  onError: (message: string) => void;
}

/** 音色目录条目（{url}?catalog=1 解析结果）。 */
export interface CatalogVoice {
  speakerId: string;
  displayName: string;
}

export class HttpTtsPlayer {
  private static instance: HttpTtsPlayer | null = null;
  private player: media.AVPlayer | null = null;
  private session: rcp.Session | null = null;
  private tempFile: string = '';
  private tempIsCache: boolean = false;
  private currentFd: number = -1;
  private generation: number = 0;
  private callbacks: HttpTtsSpeakCallbacks | null = null;
  private paused: boolean = false;
  // 批9 9.1-2：并发限流 Map<sourceId, active> + 等待队列，上限 coerceIn(1,8)。
  private activeBySource: Map<number, number> = new Map();
  private waitQueue: Array<() => void> = [];
  // 批9 9.1-3：预合成——当前段播放时预下载下一段音频到缓存，键含源/语速/正文三要素。
  private audioCache: Map<string, string> = new Map();
  private preloadPending: string = '';

  static getInstance(): HttpTtsPlayer {
    if (HttpTtsPlayer.instance === null) {
      HttpTtsPlayer.instance = new HttpTtsPlayer();
    }
    return HttpTtsPlayer.instance;
  }

  /** 批9 9.1-1：缓存 key = md5(sourceKey-|-(speed)-|-(content))，三要素缺一不可（对齐上游 HttpReadAloudService.kt:1571）。 */
  static cacheKey(source: HttpTts, rate: number, text: string): string {
    const sourceKey = `${source.id}-${source.url}`;
    const speechRate = HttpTtsPlayer.speakSpeed(source) + rate;
    return md5Hex32(`${sourceKey}-|-${speechRate}-|-${text}`);
  }

  /** 并发上限：source.synthesisThreadCount 夹到 1..8（对齐上游 coerceIn(1,8)）。 */
  private static limitOf(source: HttpTts): number {
    const raw = source.synthesisThreadCount === undefined ? 1 : source.synthesisThreadCount;
    return Math.max(1, Math.min(8, raw));
  }

  /** 申请一个并发槽；满时入队等待，释放后 FIFO 放行。 */
  private acquire(source: HttpTts): Promise<void> {
    return new Promise<void>((resolve: () => void): void => {
      const id = source.id;
      const active = this.activeBySource.get(id) ?? 0;
      if (active < HttpTtsPlayer.limitOf(source)) {
        this.activeBySource.set(id, active + 1);
        resolve();
      } else {
        this.waitQueue.push((): void => {
          this.activeBySource.set(id, (this.activeBySource.get(id) ?? 0) + 1);
          resolve();
        });
      }
    });
  }

  /** 释放并发槽并唤醒队首（每段只调用一次，配合 generation 防重复释放）。 */
  private release(source: HttpTts): void {
    const id = source.id;
    const active = this.activeBySource.get(id) ?? 0;
    this.activeBySource.set(id, Math.max(0, active - 1));
    const next = this.waitQueue.shift();
    if (next !== undefined) {
      next();
    }
  }

  /** 批9 9.1-5：预合成下一段——后台下载并按三要素 key 缓存，念到时直接命中。 */
  preload(context: Context, source: HttpTts, voice: ReadAloudVoice | null,
    text: string, rate: number): void {
    const key = HttpTtsPlayer.cacheKey(source, rate, text);
    if (this.audioCache.has(key) || key === this.preloadPending) {
      return;
    }
    this.preloadPending = key;
    const url = HttpTtsPlayer.buildUrl(source, text, voice);
    const session = HttpTtsPlayer.ensureSharedSession();
    const file = `${context.cacheDir}/legado_preload_${key}.audio`;
    session.downloadToFile(url, { kind: 'file', file: file }).then((response: rcp.Response): void => {
      if (response.statusCode >= 200 && response.statusCode < 300) {
        try {
          if (fs.statSync(file).size > 0) {
            this.audioCache.set(key, file);
          } else {
            HttpTtsPlayer.safeUnlink(file);
          }
        } catch (_) {
          HttpTtsPlayer.safeUnlink(file);
        }
      } else {
        HttpTtsPlayer.safeUnlink(file);
      }
    }).catch((): void => {
      HttpTtsPlayer.safeUnlink(file);
    }).finally((): void => {
      if (this.preloadPending === key) {
        this.preloadPending = '';
      }
    });
  }

  /** ttsSpeechRate(1..10) → AVPlayer 10 档；1 对应 0.75x，5 对应 1.00x（正常速）。 */
  static speedEnum(rate: number): media.PlaybackSpeed {
    const speeds: media.PlaybackSpeed[] = [
      media.PlaybackSpeed.SPEED_FORWARD_0_75_X,
      media.PlaybackSpeed.SPEED_FORWARD_1_00_X,
      media.PlaybackSpeed.SPEED_FORWARD_1_25_X,
      media.PlaybackSpeed.SPEED_FORWARD_1_75_X,
      media.PlaybackSpeed.SPEED_FORWARD_2_00_X,
      media.PlaybackSpeed.SPEED_FORWARD_0_50_X,
      media.PlaybackSpeed.SPEED_FORWARD_1_50_X,
      media.PlaybackSpeed.SPEED_FORWARD_3_00_X,
      media.PlaybackSpeed.SPEED_FORWARD_0_25_X,
      media.PlaybackSpeed.SPEED_FORWARD_0_125_X
    ];
    const idx = Math.max(0, Math.min(9, Math.round(rate) - 1));
    const chosen = speeds[idx];
    return chosen === undefined ? media.PlaybackSpeed.SPEED_FORWARD_1_00_X : chosen;
  }

  /** 上游：speakSpeed = (source.speed ?: 5) + 5。 */
  static speakSpeed(source: HttpTts): number {
    return (source.speed === undefined ? 5 : source.speed) + 5;
  }

  /** 固定规则拼接合成 URL；catalogUrl 非空时走 {url}?catalog=1。 */
  static buildUrl(source: HttpTts, text: string, voice: ReadAloudVoice | null,
    catalogUrl?: string): string {
    const base = source.url.trim();
    if (catalogUrl !== undefined && catalogUrl.length > 0) {
      return HttpTtsPlayer.appendQuery(base, 'catalog=1');
    }
    const parts: string[] = [];
    const textParam = (source.textParam === undefined || source.textParam.length === 0)
      ? 'text' : source.textParam;
    parts.push(`${textParam}=${encodeURIComponent(text)}`);
    const speedParam = source.speedParam === undefined ? 'speed' : source.speedParam;
    if (speedParam.length > 0) {
      parts.push(`${speedParam}=${HttpTtsPlayer.speakSpeed(source)}`);
    }
    const toneParam = source.toneParam === undefined ? 'tone' : source.toneParam;
    if (toneParam.length > 0 && voice !== null) {
      parts.push(`${toneParam}=${encodeURIComponent(voice.speakerId)}`);
    }
    return HttpTtsPlayer.appendQuery(base, parts.join('&'));
  }

  private static appendQuery(base: string, query: string): string {
    return base + (base.includes('?') ? '&' : '?') + query;
  }

  /** 拉音色目录：{url}?catalog=1 → [{speakerId, displayName}]。 */
  static async fetchCatalog(context: Context, source: HttpTts,
    catalogUrl?: string): Promise<CatalogVoice[]> {
    const url = HttpTtsPlayer.buildUrl(source, '', null, catalogUrl ?? source.url);
    const session = HttpTtsPlayer.ensureSharedSession();
    const file = `${context.cacheDir}/legado_catalog_${Date.now()}.json`;
    try {
      const destination: rcp.DownloadToFile = { kind: 'file', file: file };
      const response = await session.downloadToFile(url, destination);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw new Error(`拉取音色失败（HTTP ${response.statusCode}）`);
      }
      const text = HttpTtsPlayer.readText(file);
      const parsed = JSON.parse(text) as Object[];
      const voices: CatalogVoice[] = [];
      parsed.forEach((item: Object): void => {
        const record = item as Record<string, Object>;
        const speakerId = record['speakerId'];
        const displayName = record['displayName'];
        if (typeof speakerId === 'string' && speakerId.length > 0 &&
          typeof displayName === 'string' && displayName.length > 0) {
          voices.push({ speakerId: speakerId, displayName: displayName });
        }
      });
      return voices;
    } finally {
      HttpTtsPlayer.safeUnlink(file);
    }
  }

  /**
   * 合成并播放一段。下载→AVPlayer(completed) 全流程成功后回调 onComplete。
   * generation 版本号防止 stop/切段后旧回调回来误推进。
   */
  async speak(context: Context, source: HttpTts, voice: ReadAloudVoice | null,
    text: string, rate: number, callbacks: HttpTtsSpeakCallbacks): Promise<void> {
    this.stop();
    const generation = ++this.generation;
    this.callbacks = callbacks;
    this.paused = false;
    const url = HttpTtsPlayer.buildUrl(source, text, voice);
    const session = HttpTtsPlayer.ensureSharedSession();
    const cacheKey = HttpTtsPlayer.cacheKey(source, rate, text);
    let file = this.audioCache.get(cacheKey) ?? '';
    const cached = file.length > 0;
    if (!cached) {
      file = `${context.cacheDir}/legado_tts_${Date.now()}_${generation}.audio`;
    }
    this.tempFile = file;
    this.tempIsCache = cached;
    console.info(`[HttpTts] speak gen=${generation} cache=${cached} url=${url}`);
    // 批9 9.1-2：并发限流——拿到槽才下载，任何提前返回都 release 一次。
    await this.acquire(source);
    let released = false;
    const releaseOnce = (): void => {
      if (!released) { released = true; this.release(source); }
    };
    try {
      if (!cached) {
        const destination: rcp.DownloadToFile = { kind: 'file', file: file };
        const response = await session.downloadToFile(url, destination);
        if (generation !== this.generation) { releaseOnce(); return; }
        if (response.statusCode < 200 || response.statusCode >= 300) {
          this.failOne(generation, `合成失败（HTTP ${response.statusCode}）`);
          return;
        }
        // 上游 8.3⑤：JSON / text 响应视为「TTS 服务器返回错误」，不是音频。
        const contentType = String(response.headers['content-type'] ?? '').toLowerCase();
        if (contentType.includes('application/json') || contentType.includes('text/')) {
          this.failOne(generation, 'TTS 服务器返回错误（非音频响应）');
          return;
        }
      }
      const stat = fs.statSync(file);
      if (stat.size <= 0) {
        this.failOne(generation, '合成失败（空音频文件）');
        return;
      }
      // 下载完成即可释放配额，播放阶段不占合成并发。
      releaseOnce();
      await this.playFile(generation, file, stat.size, rate);
    } catch (error) {
      console.warn(`[HttpTts] 合成异常: ${error instanceof Error ? error.message : String(error)}`);
      this.failOne(generation, '合成异常');
    } finally {
      releaseOnce();
    }
  }

  private async playFile(generation: number, file: string, size: number,
    rate: number): Promise<void> {
    const player = await media.createAVPlayer();
    if (generation !== this.generation) {
      await player.release();
      return;
    }
    this.player = player;
    const fd = fs.openSync(file, fs.OpenMode.READ_ONLY);
    this.currentFd = fd.fd;
    player.on('stateChange', (state: string): void => {
      if (generation !== this.generation) { return; }
      if (state === 'initialized') {
        player.prepare();
      } else if (state === 'prepared') {
        try {
          player.setSpeed(HttpTtsPlayer.speedEnum(rate));
        } catch (error) {
          console.warn(`[HttpTts] setSpeed 失败: ${(error as BusinessError).message}`);
        }
        player.play();
      } else if (state === 'completed') {
        this.finishOne(generation, true, '');
      } else if (state === 'error') {
        this.finishOne(generation, false, '播放失败');
      }
    });
    player.on('error', (): void => { this.finishOne(generation, false, '播放错误'); });
    player.fdSrc = { fd: fd.fd, offset: 0, length: size };
    console.info(`[HttpTts] AVPlayer prepared, speed=${rate}`);
  }

  /** 暂停：AVPlayer.pause；与系统 TTS 的 pause 同语义（保留当前段高亮）。 */
  pause(): void {
    if (this.player !== null && !this.paused) {
      try {
        this.player.pause();
        this.paused = true;
      } catch (error) {
        console.warn(`[HttpTts] pause 失败: ${(error as BusinessError).message}`);
      }
    }
  }

  /** HTTP 模式下拖动语速滑杆即时生效：对正在播放的 AVPlayer 调 setSpeed。 */
  applyRate(rate: number): void {
    if (this.player !== null) {
      try {
        this.player.setSpeed(HttpTtsPlayer.speedEnum(rate));
        console.info(`[HttpTts] applyRate=${rate}`);
      } catch (error) {
        console.warn(`[HttpTts] applyRate 失败: ${(error as BusinessError).message}`);
      }
    }
  }

  /** 暂停后恢复：AVPlayer.play。 */
  resume(): void {
    if (this.player !== null && this.paused) {
      try {
        this.player.play();
        this.paused = false;
      } catch (error) {
        console.warn(`[HttpTts] resume 失败: ${(error as BusinessError).message}`);
      }
    }
  }

  /** 停止：作废旧 generation、释放 player、关 fd、删临时文件。 */
  stop(): void {
    this.generation++;
    this.callbacks = null;
    this.paused = false;
    const player = this.player;
    this.player = null;
    if (player !== null) {
      try {
        player.release();
      } catch (error) {
        console.warn(`[HttpTts] release 失败: ${(error as BusinessError).message}`);
      }
    }
    if (this.currentFd >= 0) {
      try {
        fs.closeSync(this.currentFd);
      } catch (_) {
        // fd 可能已被 AVPlayer 关闭，忽略
      }
      this.currentFd = -1;
    }
    // 缓存文件要复用，不能播一次就删；只有临时下载文件才清理。
    if (!this.tempIsCache) {
      HttpTtsPlayer.safeUnlink(this.tempFile);
    }
    this.tempFile = '';
    this.tempIsCache = false;
  }

  private finishOne(generation: number, ok: boolean, message: string): void {
    if (generation !== this.generation) { return; }
    const callbacks = this.callbacks;
    this.stop();
    if (callbacks !== null) {
      if (ok) {
        callbacks.onComplete();
      } else {
        callbacks.onError(message);
      }
    }
  }

  private failOne(generation: number, message: string): void {
    this.finishOne(generation, false, message);
  }

  /** 退出朗读清整个缓存目录里的合成临时文件。 */
  clearCache(context: Context): void {
    try {
      const names = fs.listFileSync(context.cacheDir);
      names.forEach((name: string): void => {
        if (name.startsWith('legado_tts_') || name.startsWith('legado_catalog_') ||
          name.startsWith('legado_preload_')) {
          HttpTtsPlayer.safeUnlink(`${context.cacheDir}/${name}`);
        }
        this.audioCache.clear();
      });
    } catch (_) {
      // 缓存目录不可读时忽略
    }
  }

  private static ensureSharedSession(): rcp.Session {
    const inst = HttpTtsPlayer.getInstance();
    if (inst.session === null) {
      // SessionConfiguration 只接受 headers 等已知键；会话级 transfer 超时不是它的字段，
      // 用默认配置即可（合成请求走 downloadToFile，默认传输超时已足够）。
      inst.session = rcp.createSession({});
    }
    return inst.session;
  }

  private static readText(path: string): string {
    const file = fs.openSync(path, fs.OpenMode.READ_ONLY);
    try {
      const stat = fs.statSync(file.fd);
      const buf = new ArrayBuffer(stat.size);
      const len = fs.readSync(file.fd, buf);
      const decoder = new util.TextDecoder('utf-8');
      return decoder.decode(new Uint8Array(buf.slice(0, len)));
    } finally {
      fs.closeSync(file);
    }
  }

  private static safeUnlink(path: string): void {
    if (path.length === 0) { return; }
    try {
      if (fs.accessSync(path)) {
        fs.unlinkSync(path);
      }
    } catch (_) {
      // 文件可能已被删，忽略
    }
  }
}
