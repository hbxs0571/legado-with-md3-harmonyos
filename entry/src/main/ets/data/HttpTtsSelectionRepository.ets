import { preferences } from '@kit.ArkData';

/**
 * 批8：当前选中的 HTTP 朗读源 / 音色。
 * 单独一个偏好文件，不并入 legado_read_aloud_settings 的 14 键——那 14 键逐字对齐上游
 * 且参与备份互通，加键会破坏互通目标；选中源是本地播放状态，不需要进备份。
 */
export interface HttpTtsSelection {
  sourceId: number;
  speakerId: string;
}

export const EMPTY_HTTP_TTS_SELECTION: HttpTtsSelection = { sourceId: 0, speakerId: '' };

export class HttpTtsSelectionRepository {
  private static readonly preferenceName: string = 'legado_http_tts_selection';

  static async load(context: Context): Promise<HttpTtsSelection> {
    const selection: HttpTtsSelection = { sourceId: 0, speakerId: '' };
    try {
      const store = await preferences.getPreferences(context, HttpTtsSelectionRepository.preferenceName);
      selection.sourceId = await store.get('sourceId', 0) as number;
      selection.speakerId = await store.get('speakerId', '') as string;
    } catch (error) {
      console.error(`HTTP 朗读源选中态读取失败：${error instanceof Error ? error.message : String(error)}`);
    }
    return selection;
  }

  static async save(context: Context, selection: HttpTtsSelection): Promise<void> {
    try {
      const store = await preferences.getPreferences(context, HttpTtsSelectionRepository.preferenceName);
      await store.put('sourceId', selection.sourceId);
      await store.put('speakerId', selection.speakerId);
      await store.flush();
    } catch (error) {
      console.error(`HTTP 朗读源选中态写入失败：${error instanceof Error ? error.message : String(error)}`);
    }
  }
}
