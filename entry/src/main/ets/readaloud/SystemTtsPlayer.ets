import { textToSpeech } from '@kit.CoreSpeechKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { SpeechUnit } from './SpeechSegmenter';

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

  onStateChange: (state: ReadAloudState) => void = (_state: ReadAloudState): void => {};
  onUnitAdvance: (index: number) => void = (_index: number): void => {};
  /** 进入新朗读段时上报语义正文区间（批 4 位置回写 + 高亮消费）。 */
  onSpanChange: (span: ReadAloudSpan) => void = (_span: ReadAloudSpan): void => {};
  onError: (message: string) => void = (_message: string): void => {};

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

  /** 手动上下句：flush 当前、从新位置起播。 */
  private jumpTo(target: number): void {
    this.index = target;
    this.activeRequestId = '';
    this.chunkQueue = [];
    this.chunkIndex = 0;
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
  }

  /** 清空高亮（停止/暂停时）：start<0 由消费方识别为「无朗读段」。 */
  private clearSpan(): void {
    this.spanRevision++;
    const span: ReadAloudSpan = { start: -1, end: -1, revision: this.spanRevision };
    this.onSpanChange(span);
  }

  private emitProgress(): void {
    this.onUnitAdvance(this.index);
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
      person: 13,
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
