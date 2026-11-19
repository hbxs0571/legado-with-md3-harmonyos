import { textToSpeech } from '@kit.CoreSpeechKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { SpeechUnit } from './SpeechSegmenter';
import { HttpTtsPlayer } from './HttpTtsPlayer';
import { HttpTts } from '../model/HttpTts';
import { ReadAloudVoice } from '../model/ReadAloudVoice';

/**
 * 正在朗读的正文区间（语义内容坐标，与画布 LocalReaderLineItem.startPosition 同源）。
 * start < 0 表示当前没有朗读段。revision 每次变化触发 ReaderPage 跟随重绘。
 */
export interface ReadAloudSpan {
  start: number;
  end: number;
  revision: number;
}

/** 空区间的共享常量：ArkTS 禁止无类型对象字面量，Index/ReaderPage 都用它初始化。 */
export const EMPTY_READ_ALOUD_SPAN: ReadAloudSpan = { start: -1, end: -1, revision: 0 };

/** 朗读播放状态，与上游 service 的播放/暂停/空闲三态对应。 */
export enum ReadAloudState {
  IDLE = 0,
  PLAYING = 1,
  PAUSED = 2
}

const TTS_MAX_CHARS: number = 10000;
const TTS_ENGINE_BUSY: number = 1002300005;
const TTS_TEXT_INVALID: number = 1002300001;
const ENGINE_SHUTDOWN_DELAY_MS: number = 60000;
const BUSY_RETRY_DELAY_MS: number = 500;

/**
 * 系统 TTS 朗读播放器。
 *
 * 分层对齐上游：本类只做「取段组装后的串行播放调度 + 出声」，切段由 SpeechSegmenter
 * 完成，位置/高亮由 ReaderPage 消费 onUnitAdvance。上游 BaseReadAloudService 的抽象
 * 基类本批不建——抽象的价值在于两个子类共用，目前只有系统 TTS 一个实现，HTTP 那条
 * 到批 8 再看能否真共用，提前抽象等于赌一个还不存在的第二实现。
 *
 * 关键约束（实测，见 readaloud-evidence.md 11.x）：
 * - 引擎全设备最多 3 个，故单例持有，stop 后延迟 60s 才 shutdown，期间 play 复用。
 * - 系统 TTS 无 setSpeechRate / setVolume，故本类不碰语速音量（那是 HTTP 源的事）。
 * - speak 之后必须等 onComplete 才发下一句：onStart 只表示「开始合成」，
 *   onComplete 才表示「念完了」。
 */
export class SystemTtsPlayer {
  private static instance: SystemTtsPlayer | null = null;

  private engine: textToSpeech.TextToSpeechEngine | null = null;
  private engineCreating: Promise<textToSpeech.TextToSpeechEngine> | null = null;
  private units: SpeechUnit[] = [];
  private index: number = 0;
  private stateValue: ReadAloudState = ReadAloudState.IDLE;
  private paragraphInterval: number = 0;
  private requestSeq: number = 0;
  /** 当前 await 的 requestId；onComplete 只认它，避免乱序回调推进两次。 */
  private activeRequestId: string = '';
  private shutdownTimerId: number = -1;
  private busyRetryTimerId: number = -1;
  private generation: number = 0;
  /** 当前正在硬切的句子队列（一段 >10000 字符时拆成多句）。 */
  private chunkQueue: string[] = [];
  private chunkIndex: number = 0;
  /** 当前朗读段区间每次变化递增，交给 ReaderPage 判断是否需要重绘/跟随。 */
  private spanRevision: number = 0;
  /** 系统 TTS 人声 person 值；听书页切换音色时更新并重建引擎（平台只 3 个音色）。 */
  private voicePerson: number = 13;
  /**
   * 批8：HTTP 朗读源与音色。非空时 speak 走 HttpTtsPlayer（AVPlayer 播合成音频），
   * 空时走系统 TTS。统一门面让 Index/高亮/句序/面板状态零改动复用。
   */
  private httpSource: HttpTts | null = null;
  private httpVoice: ReadAloudVoice | null = null;
  private httpContext: Context | null = null;
  private httpRate: number = 5;
  /** HTTP 源 pause 后 play 时标记「恢复当前段」而非重新合成。 */
  private httpResumePending: boolean = false;

  onStateChange: (state: ReadAloudState) => void = (_state: ReadAloudState): void => {};
  onUnitAdvance: (index: number) => void = (_index: number): void => {};
  /** 进入新朗读段时上报语义正文区间（批 4 位置回写 + 高亮消费）。 */
  onSpanChange: (span: ReadAloudSpan) => void = (_span: ReadAloudSpan): void => {};
  onError: (message: string) => void = (_message: string): void => {};
  /** 听书页用：进入新朗读段时上报当前句/下一句原文与句序，与高亮段同源。 */
  onTextChange: (current: string, next: string, index: number) => void =
    (_current: string, _next: string, _index: number): void => {};

  static getInstance(): SystemTtsPlayer {
    if (SystemTtsPlayer.instance === null) {
      SystemTtsPlayer.instance = new SystemTtsPlayer();
    }
    return SystemTtsPlayer.instance;
  }

  /** 准备要念的单元序列；切段在 SpeechSegmenter 完成，这里只接结果。 */
  load(units: SpeechUnit[], startIndex: number): void {
    this.units = units.slice();
    this.index = Math.max(0, Math.min(startIndex, this.units.length));
    console.info(`[ReadAloud] load units=${this.units.length} start=${this.index}`);
  }

  /** 设段落间隔毫秒数（ttsParagraphInterval）。 */
  setParagraphInterval(ms: number): void {
    this.paragraphInterval = Math.max(0, Math.trunc(ms));
  }

  /**
   * 批8：配置 HTTP 合成源。source 为 null 时切回系统 TTS。
   * context 用于合成临时文件（cacheDir），rate 为 ttsSpeechRate(1..10)，HTTP 下真调速。
   */
  configureHttp(context: Context | null, source: HttpTts | null, voice: ReadAloudVoice | null,
    rate: number): void {
    this.httpSource = source;
    this.httpVoice = voice;
    this.httpContext = context;
    this.httpRate = rate;
    console.info(`[ReadAloud] configureHttp source=${source === null ? 'none' : source.name}`);
  }

  /** 当前是否处于 HTTP 合成模式，供界面显示真实能力（调速是否生效）。 */
  isHttpMode(): boolean {
    return this.httpSource !== null;
  }

  /** 开始/恢复朗读。 */
  play(): void {
    if (this.units.length === 0) {
      console.warn('[ReadAloud] play 但无单元，忽略');
      return;
    }
    this.cancelShutdown();
    this.stateValue = ReadAloudState.PLAYING;
    this.emitState();
    if (this.activeRequestId.length === 0 && this.chunkQueue.length === 0) {
      if (this.httpResumePending && this.httpSource !== null) {
        // HTTP 源从 PAUSED 恢复：AVPlayer.resume 继续当前段，不重新合成。
        this.httpResumePending = false;
        HttpTtsPlayer.getInstance().resume();
        return;
      }
      this.generation++;
      this.speakCurrent();
    }
  }

  /** 暂停：停掉引擎当前合成，状态转 PAUSED；不在 onStop 里推进。 */
  pause(): void {
    if (this.stateValue !== ReadAloudState.PLAYING) {
      return;
    }
    this.stateValue = ReadAloudState.PAUSED;
    this.activeRequestId = '';
    this.chunkQueue = [];
    this.chunkIndex = 0;
    this.generation++;
    if (this.httpSource !== null) {
      // HTTP 源：AVPlayer.pause 保留当前段，不删临时文件（resume 需要）。
      this.httpResumePending = true;
      HttpTtsPlayer.getInstance().pause();
      this.emitState();
      return;
    }
    const engine = this.engine;
    if (engine !== null && engine.isBusy()) {
      try {
        engine.stop();
      } catch (error) {
        console.warn(`[ReadAloud] pause stop 失败: ${SystemTtsPlayer.errorText(error as BusinessError)}`);
      }
    }
    this.emitState();
  }

  /** 停止：清状态、停引擎、延迟 shutdown（期间再 play 复用）。 */
  stop(): void {
    this.stateValue = ReadAloudState.IDLE;
    this.activeRequestId = '';
    this.generation++;
    this.chunkQueue = [];
    this.chunkIndex = 0;
    this.httpResumePending = false;
    if (this.httpSource !== null) {
      HttpTtsPlayer.getInstance().stop();
    }
    if (this.busyRetryTimerId >= 0) {
      clearTimeout(this.busyRetryTimerId);
      this.busyRetryTimerId = -1;
    }
    const engine = this.engine;
    if (engine !== null && engine.isBusy()) {
      try {
        engine.stop();
      } catch (error) {
        console.warn(`[ReadAloud] stop stop 失败: ${SystemTtsPlayer.errorText(error as BusinessError)}`);
      }
    }
    this.scheduleShutdown();
    this.clearSpan();
    this.emitState();
  }

  /** 上一句：越界返回 false，由调用方决定换章。 */
  previous(): boolean {
    if (this.index <= 0) {
      return false;
    }
    this.index -= 1;
    this.jumpTo(this.index);
    return true;
  }

  /** 下一句：越界返回 false，由调用方决定换章。 */
  next(): boolean {
    if (this.index >= this.units.length - 1) {
      return false;
    }
    this.index += 1;
    this.jumpTo(this.index);
    return true;
  }

  /** 当前念到第几个单元。界面与高亮都读这个。 */
  currentIndex(): number {
    return this.index;
  }

  /** 当前单元总数，供面板显示「第几句/共几句」。 */
  totalUnits(): number {
    return this.units.length;
  }

  /** 当前状态。 */
  state(): ReadAloudState {
    return this.stateValue;
  }

  /** 听书页取第 index 句原文（未 trim），供当前句/下一句/正文列表显示。 */
  unitText(index: number): string {
    const unit = this.units[index];
    return unit === undefined ? '' : unit.text.trim();
  }

  /** 听书页正文列表：导出全部单元文本（正文页跟随高亮用）。 */
  allUnitTexts(): string[] {
    const texts: string[] = [];
    for (const unit of this.units) {
      texts.push(unit.text.trim());
    }
    return texts;
  }

  /**
   * 跳到第 index 句并从该处续播（听书页进度条/正文点选 seek）。
   * 与 previous/next 的 jumpTo 同一路径：越界钳住，暂停态只挪位置不出声。
   */
  seekTo(index: number): void {
    if (this.units.length === 0) {
      return;
    }
    const target = Math.max(0, Math.min(index, this.units.length - 1));
    this.jumpTo(target);
  }

  /**
   * 切换系统人声（听书页音色选择）。person 为 SDK 音色值，如 13/21/8。
   * 重建引擎：先停当前合成并 shutdown 旧实例，再让 ensureEngine 用新 person 创建。
   * 系统 TTS 全设备最多 3 引擎，重建只持有一个，符合上限。
   */
  setVoicePerson(person: number): void {
    if (person === this.voicePerson) {
      return;
    }
    this.voicePerson = person;
    this.stop();
    const engine = this.engine;
    if (engine !== null) {
      try {
        engine.shutdown();
      } catch (error) {
        console.warn(`[ReadAloud] 切音色 shutdown 失败: ${SystemTtsPlayer.errorText(error as BusinessError)}`);
      }
      this.engine = null;
    }
    this.cancelShutdown();
    console.info(`[ReadAloud] setVoicePerson=${person}`);
  }

  /** 手动上下句：flush 当前、从新位置起播。 */
  private jumpTo(target: number): void {
    this.index = target;
    this.activeRequestId = '';
    this.chunkQueue = [];
    this.chunkIndex = 0;
    this.httpResumePending = false;
    this.generation++;
    if (this.stateValue === ReadAloudState.PAUSED) {
      // 暂停态下跳句只更新位置，不自动出声（与上游手动切段后仍需 play 一致）。
      this.emitProgress();
      return;
    }
    this.stateValue = ReadAloudState.PLAYING;
    this.emitState();
    this.speakCurrent();
  }

  /** 取当前单元文本，按 10000 字上限硬切后逐句 speak。 */
  private speakCurrent(): void {
    if (this.stateValue !== ReadAloudState.PLAYING) {
      return;
    }
    const unit = this.units[this.index];
    if (unit === undefined) {
      // 念完最后一单元：停止，不自动换章（换章由 ReaderPage 的章末推进负责）。
      console.info('[ReadAloud] 全部单元念完');
      this.stop();
      return;
    }
    // 进入新段即上报区间：高亮与翻页跟随都拿它当权威位置。
    this.emitSpan(unit);
    const text = unit.text.trim();
    if (text.length === 0) {
      // 上游 TTSReadAloudService.kt:246-251：全标点段落不进引擎（会静默不回调卡死链）。
      console.info(`[ReadAloud] 空白单元跳过 index=${this.index}`);
      this.advance();
      return;
    }
    if (this.httpSource !== null && this.httpContext !== null) {
      // HTTP 源：AudioPlayer 播合成音频，setSpeed 真调速；播完 completed 走同一 advance 链。
      const source = this.httpSource;
      const voice = this.httpVoice;
      const context = this.httpContext;
      const myGeneration = this.generation;
      console.info(`[ReadAloud] speak via HTTP idx=${this.index}`);
      // 批9 9.1-5：念当前段时预下载下一段（并发默认 3，由 HttpTtsPlayer 内部限流）。
      const nextUnit = this.units[this.index + 1];
      if (nextUnit !== undefined) {
        const nextText = nextUnit.text.trim();
        if (nextText.length > 0) {
          HttpTtsPlayer.getInstance().preload(context, source, voice, nextText, this.httpRate);
        }
      }
      HttpTtsPlayer.getInstance().speak(context, source, voice, text, this.httpRate, {
        onComplete: (): void => {
          if (myGeneration === this.generation && this.stateValue === ReadAloudState.PLAYING) {
            this.advance();
          }
        },
        onError: (message: string): void => {
          if (myGeneration === this.generation) {
            this.onError(message);
            this.stop();
          }
        }
      });
      return;
    }
    this.chunkQueue = SystemTtsPlayer.chunkText(text);
    this.chunkIndex = 0;
    this.speakNextChunk();
  }

  /** 发下一切片；一段超 10000 字时切成多片连续念。 */
  private speakNextChunk(): void {
    if (this.stateValue !== ReadAloudState.PLAYING) {
      return;
    }
    const chunk = this.chunkQueue[this.chunkIndex];
    if (chunk === undefined) {
      this.advance();
      return;
    }
    const myGeneration = this.generation;
    const requestId = `ra-${Date.now()}-${this.requestSeq++}`;
    this.activeRequestId = requestId;
    const doSpeak = (engine: textToSpeech.TextToSpeechEngine): void => {
      if (this.generation !== myGeneration || this.stateValue !== ReadAloudState.PLAYING) {
        return;
      }
      const params: textToSpeech.SpeakParams = { requestId: requestId };
      console.info(`[ReadAloud] speak start idx=${this.index} len=${chunk.length} rid=${requestId}`);
      try {
        engine.speak(chunk, params);
      } catch (error) {
        const failure = error as BusinessError;
        const code = SystemTtsPlayer.errorCode(failure);
        console.error(`[ReadAloud] speak throw code=${code} msg=${SystemTtsPlayer.errorText(failure)}`);
        this.onChunkFailed(code, myGeneration, requestId);
      }
    };
    this.ensureEngine().then(doSpeak).catch((error: BusinessError) => {
      console.error(`[ReadAloud] ensureEngine 失败 code=${error.code} msg=${error.message}`);
      if (error.code === TTS_ENGINE_BUSY && this.generation === myGeneration) {
        // 引擎忙：500ms 后重试一次，仍失败就上报，不无限重试。
        if (this.busyRetryTimerId >= 0) {
          clearTimeout(this.busyRetryTimerId);
        }
        this.busyRetryTimerId = setTimeout((): void => {
          this.busyRetryTimerId = -1;
          if (this.generation === myGeneration && this.stateValue === ReadAloudState.PLAYING) {
            this.ensureEngine().then(doSpeak).catch((): void => {
              this.activeRequestId = '';
              this.onError('朗读引擎繁忙，请稍后重试');
            });
          }
        }, BUSY_RETRY_DELAY_MS);
      } else {
        this.activeRequestId = '';
        this.onError('朗读引擎不可用');
      }
    });
  }

  /** 一个切片失败：文本非法跳过该单元，其余停止上报。 */
  private onChunkFailed(code: number, myGeneration: number, requestId: string): void {
    if (this.generation !== myGeneration || this.activeRequestId !== requestId) {
      return;
    }
    this.activeRequestId = '';
    if (code === TTS_TEXT_INVALID) {
      console.warn('[ReadAloud] 文本超长或为空，跳过该单元');
      this.advance();
    } else {
      this.onError(`朗读出错（${code}）`);
      this.stop();
    }
  }

  /** onComplete：只有当前 requestId 才推进；同一单元还有切片则继续下一片。 */
  private handleComplete(requestId: string): void {
    if (requestId !== this.activeRequestId || this.stateValue !== ReadAloudState.PLAYING) {
      return;
    }
    console.info(`[ReadAloud] speak complete rid=${requestId}`);
    this.activeRequestId = '';
    if (this.chunkIndex < this.chunkQueue.length - 1) {
      this.chunkIndex++;
      this.speakNextChunk();
      return;
    }
    const advance = (): void => {
      if (this.stateValue === ReadAloudState.PLAYING) {
        this.advance();
      }
    };
    if (this.paragraphInterval > 0) {
      setTimeout(advance, this.paragraphInterval);
    } else {
      advance();
    }
  }

  /** 推进到下一单元并发音。 */
  private advance(): void {
    this.onUnitAdvance(this.index);
    this.index += 1;
    const unit = this.units[this.index];
    if (unit === undefined || this.stateValue !== ReadAloudState.PLAYING) {
      this.stop();
      return;
    }
    this.generation++;
    this.speakCurrent();
  }

  private emitState(): void {
    this.onStateChange(this.stateValue);
  }

  /** 上报当前朗读段区间；只读 units，play/stop 的 generation 已保证不串段。 */
  private emitSpan(unit: SpeechUnit): void {
    this.spanRevision++;
    const span: ReadAloudSpan = { start: unit.start, end: unit.end, revision: this.spanRevision };
    console.info(`[ReadAloud] span ${span.start}-${span.end} rev=${span.revision}`);
    this.onSpanChange(span);
    this.onTextChange(this.unitText(this.index), this.unitText(this.index + 1), this.index);
  }

  /** 清空高亮（停止/暂停时）：start<0 由消费方识别为「无朗读段」。 */
  private clearSpan(): void {
    this.spanRevision++;
    const span: ReadAloudSpan = { start: -1, end: -1, revision: this.spanRevision };
    this.onSpanChange(span);
  }

  private emitProgress(): void {
    this.onUnitAdvance(this.index);
    this.onTextChange(this.unitText(this.index), this.unitText(this.index + 1), this.index);
  }

  /** 单例持有引擎；创建中的 Promise 共享，避免并发 createEngine 撞 3 实例上限。 */
  private ensureEngine(): Promise<textToSpeech.TextToSpeechEngine> {
    if (this.engine !== null) {
      return Promise.resolve(this.engine);
    }
    if (this.engineCreating !== null) {
      return this.engineCreating;
    }
    console.info('[ReadAloud] createEngine begin');
    const creating = textToSpeech.createEngine({
      language: 'zh-CN',
      person: this.voicePerson,
      online: 1
    }).then((engine: textToSpeech.TextToSpeechEngine): textToSpeech.TextToSpeechEngine => {
      this.engine = engine;
      this.engineCreating = null;
      engine.setListener({
        onStart: (requestId: string): void => {
          console.info(`[ReadAloud] onStart rid=${requestId}`);
        },
        onComplete: (requestId: string): void => this.handleComplete(requestId),
        onStop: (requestId: string): void => {
          console.info(`[ReadAloud] onStop rid=${requestId}`);
        },
        onError: (requestId: string, errorCode: number, errorMessage: string): void => {
          console.error(`[ReadAloud] onError rid=${requestId} code=${errorCode} msg=${errorMessage}`);
          if (requestId === this.activeRequestId) {
            this.onChunkFailed(errorCode, this.generation, requestId);
          }
        }
      });
      console.info('[ReadAloud] createEngine OK');
      return engine;
    }).catch((error: BusinessError): Promise<textToSpeech.TextToSpeechEngine> => {
      this.engineCreating = null;
      // ArkTS 不允许 throw 任意类型；转成 Error 再抛，调用侧 catch 已按 BusinessError.code 判忙。
      const wrapped = new Error(error.message ?? 'createEngine failed');
      throw wrapped;
    });
    this.engineCreating = creating;
    return creating;
  }

  /** 延迟 60s shutdown，期间 play 可取消复用（对齐上游 help/TTS.kt 的 60000L）。 */
  private scheduleShutdown(): void {
    this.cancelShutdown();
    this.shutdownTimerId = setTimeout((): void => {
      this.shutdownTimerId = -1;
      const engine = this.engine;
      if (engine !== null) {
        console.info('[ReadAloud] shutdown after idle');
        try {
          engine.shutdown();
        } catch (error) {
          console.warn(`[ReadAloud] shutdown 失败: ${SystemTtsPlayer.errorText(error as BusinessError)}`);
        }
        this.engine = null;
      }
    }, ENGINE_SHUTDOWN_DELAY_MS);
  }

  private cancelShutdown(): void {
    if (this.shutdownTimerId >= 0) {
      clearTimeout(this.shutdownTimerId);
      this.shutdownTimerId = -1;
    }
  }

  /** 一段正文按 10000 字上限硬切（speak 超长抛 1002300001）。 */
  private static chunkText(text: string): string[] {
    if (text.length <= TTS_MAX_CHARS) {
      return [text];
    }
    const chunks: string[] = [];
    for (let start = 0; start < text.length; start += TTS_MAX_CHARS) {
      chunks.push(text.substring(start, Math.min(start + TTS_MAX_CHARS, text.length)));
    }
    console.warn(`[ReadAloud] 超长单元切成 ${chunks.length} 片`);
    return chunks;
  }

  private static errorCode(error: BusinessError): number {
    const code = error.code;
    return typeof code === 'number' ? code : -1;
  }

  private static errorText(error: BusinessError): string {
    return error.message ?? String(error);
  }
}
