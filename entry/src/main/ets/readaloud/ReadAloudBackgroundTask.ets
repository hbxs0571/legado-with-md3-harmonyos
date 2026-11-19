import { avSession } from '@kit.AVSessionKit';
import { backgroundTaskManager } from '@kit.BackgroundTasksKit';
import { wantAgent, Want } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { ReadAloudState } from './SystemTtsPlayer';

/**
 * 批7：朗读后台长时任务 + AVSession。
 *
 * 为什么两件事必须一起做：基线 targetSdk 20，@ohos.resourceschedule.backgroundTaskManager.d.ts
 * :1139 明确——API20 起 AUDIO_PLAYBACK 长时任务若未连接 AVSession，会弹一条不受控的系统通知；
 * 连接 AVSession 后通知由 AVSession 发送（带播放控制条）。所以 begin() 先把 AVSession 激活，
 * 再申请长时任务。
 *
 * 平台边界（如实记录，见任务书 7.5）：
 * - 系统 TTS 的 speak 不暴露音频焦点控制，上游 ignoreAudioFocus 开关本地不实现、也不做假焦点。
 * - 上游 keepReadAloudOnExit 字段本地偏好仓库本就没有；鸿蒙没有「退出应用后仍保留功能」的对应位，
 *   行为是「回桌面长时任务继续、从最近任务划掉则结束」，差异写进注释，不发明字段。
 * - AVSession 的 seek 不接：朗读是段落级，没有时间轴 seek 语义。
 */
export interface ReadAloudControlHandlers {
  onPlay: () => void;
  onPause: () => void;
  onNext: () => void;
  onPrevious: () => void;
  onStop: () => void;
}

export class ReadAloudBackgroundTask {
  private static session: avSession.AVSession | null = null;
  private static runningContext: Context | null = null;
  private static bgRunning: boolean = false;
  private static handlers: ReadAloudControlHandlers | null = null;

  /** Index 注册控制回调（AVSession 控制条上的按键接到播放器/面板逻辑）。 */
  static setControlHandlers(handlers: ReadAloudControlHandlers): void {
    ReadAloudBackgroundTask.handlers = handlers;
  }

  /** 开始朗读：先激活 AVSession，再申请 AUDIO_PLAYBACK 长时任务。 */
  static async begin(context: Context): Promise<void> {
    ReadAloudBackgroundTask.runningContext = context;
    try {
      await ReadAloudBackgroundTask.ensureSession(context);
    } catch (error) {
      console.warn(`[ReadAloud] AVSession 激活失败: ${ReadAloudBackgroundTask.errorText(error as BusinessError)}`);
    }
    try {
      await ReadAloudBackgroundTask.startBackground(context);
    } catch (error) {
      console.warn(`[ReadAloud] 长时任务申请失败: ${ReadAloudBackgroundTask.errorText(error as BusinessError)}`);
    }
  }

  /** 停止朗读：结束长时任务并销毁 AVSession（通知条随之消失）。 */
  static async end(): Promise<void> {
    const context = ReadAloudBackgroundTask.runningContext;
    if (ReadAloudBackgroundTask.bgRunning && context !== null) {
      try {
        await backgroundTaskManager.stopBackgroundRunning(context);
      } catch (error) {
        console.warn(`[ReadAloud] 长时任务结束失败: ${ReadAloudBackgroundTask.errorText(error as BusinessError)}`);
      }
      ReadAloudBackgroundTask.bgRunning = false;
    }
    const session = ReadAloudBackgroundTask.session;
    if (session !== null) {
      try {
        await session.destroy();
      } catch (error) {
        console.warn(`[ReadAloud] AVSession 销毁失败: ${ReadAloudBackgroundTask.errorText(error as BusinessError)}`);
      }
      ReadAloudBackgroundTask.session = null;
    }
    ReadAloudBackgroundTask.runningContext = null;
  }

  /** 播放状态同步到 AVSession 控制条：播放/暂停/停止。 */
  static async updateState(state: ReadAloudState): Promise<void> {
    const session = ReadAloudBackgroundTask.session;
    if (session === null) {
      return;
    }
    let playback: avSession.PlaybackState = avSession.PlaybackState.PLAYBACK_STATE_STOP;
    if (state === ReadAloudState.PLAYING) {
      playback = avSession.PlaybackState.PLAYBACK_STATE_PLAY;
    } else if (state === ReadAloudState.PAUSED) {
      playback = avSession.PlaybackState.PLAYBACK_STATE_PAUSE;
    }
    const playbackState: avSession.AVPlaybackState = { state: playback };
    try {
      await session.setAVPlaybackState(playbackState);
    } catch (error) {
      console.warn(`[ReadAloud] AVSession 状态同步失败: ${ReadAloudBackgroundTask.errorText(error as BusinessError)}`);
    }
  }

  /** 元数据：书名放 title、章节名放 artist，并设媒体中心队列项（控制条卡片靠它显示文字）。 */
  static async updateMeta(title: string, chapter: string): Promise<void> {
    const session = ReadAloudBackgroundTask.session;
    if (session === null) {
      return;
    }
    const metadata: avSession.AVMetadata = {
      assetId: 'legado_readaloud',
      title: title,
      artist: chapter
    };
    try {
      await session.setAVMetadata(metadata);
      // 媒体中心/通知栏控制条卡片需要 queueItem 的 description 才显示书名与章节名。
      // 不填 mediaImage：任务书 7.4③ 明确封面上传不在本批范围。
      const description: avSession.AVMediaDescription = {
        assetId: 'legado_readaloud',
        title: title,
        subtitle: chapter
      };
      const queueItem: avSession.AVQueueItem = { itemId: 1, description: description };
      await session.setAVQueueItems([queueItem]);
      await session.setAVQueueTitle(title);
    } catch (error) {
      console.warn(`[ReadAloud] AVSession 元数据同步失败: ${ReadAloudBackgroundTask.errorText(error as BusinessError)}`);
    }
  }

  /** 一个 ability 只能创建一个 AVSession；已存在则复用，销毁后置 null 由本方法重建。 */
  private static async ensureSession(context: Context): Promise<void> {
    if (ReadAloudBackgroundTask.session !== null) {
      return;
    }
    const session = await avSession.createAVSession(context, 'legado_readaloud', 'audio');
    session.on('play', (): void => { ReadAloudBackgroundTask.dispatch('play'); });
    session.on('pause', (): void => { ReadAloudBackgroundTask.dispatch('pause'); });
    session.on('stop', (): void => { ReadAloudBackgroundTask.dispatch('stop'); });
    session.on('playNext', (): void => { ReadAloudBackgroundTask.dispatch('next'); });
    session.on('playPrevious', (): void => { ReadAloudBackgroundTask.dispatch('previous'); });
    // seek 不接：朗读是段落级进度，没有秒级时间轴语义（任务书 7.4②）。
    await session.activate();
    ReadAloudBackgroundTask.session = session;
    console.info('[ReadAloud] AVSession activated');
  }

  private static dispatch(action: 'play' | 'pause' | 'stop' | 'next' | 'previous'): void {
    console.info(`[ReadAloud] AVSession control ${action}`);
    const handlers = ReadAloudBackgroundTask.handlers;
    if (handlers === null) {
      return;
    }
    if (action === 'play') { handlers.onPlay(); }
    else if (action === 'pause') { handlers.onPause(); }
    else if (action === 'stop') { handlers.onStop(); }
    else if (action === 'next') { handlers.onNext(); }
    else { handlers.onPrevious(); }
  }

  /** 造 wantAgent（点通知回到应用），再申请 AUDIO_PLAYBACK 长时任务。 */
  private static async startBackground(context: Context): Promise<void> {
    const want: Want = {
      bundleName: 'io.legado.harmony',
      abilityName: 'EntryAbility'
    };
    const info: wantAgent.WantAgentInfo = {
      wants: [want],
      actionType: wantAgent.OperationType.START_ABILITY,
      requestCode: 0
    };
    const agent = await wantAgent.getWantAgent(info);
    // 让媒体中心控制条点进来回到应用（AVSession 自己的 launch ability）。
    const session = ReadAloudBackgroundTask.session;
    if (session !== null) {
      try {
        await session.setLaunchAbility(agent);
      } catch (error) {
        console.warn(`[ReadAloud] setLaunchAbility 失败: ${ReadAloudBackgroundTask.errorText(error as BusinessError)}`);
      }
    }
    await backgroundTaskManager.startBackgroundRunning(
      context, backgroundTaskManager.BackgroundMode.AUDIO_PLAYBACK, agent);
    ReadAloudBackgroundTask.bgRunning = true;
    console.info('[ReadAloud] 长时任务 AUDIO_PLAYBACK 已开启');
  }

  private static errorText(error: BusinessError): string {
    return error.message ?? String(error);
  }
}
