import { preferences } from '@kit.ArkData';
import { normalizeAppFontSort } from './AppFontLibrary';

/**
 * 「其它设置」页三个真落盘的偏好（批 9）。
 *
 * 键名照抄上游 PreferKey.kt：defaultBookTreeUri / sourceEditMaxLine / webPort，
 * 与 BackupConfig.kt 的备份白名单口径一致（defaultBookTreeUri 已在
 * BackupRepository 的 alwaysIgnored 集合里，备份时不写回，避免把本机目录带restore）。
 */
export interface OtherSettings {
  /** 书籍保存位置（目录 URI）。上游 OtherSettings.defaultBookTreeUri 为 nullable，空串表示未设置。 */
  defaultBookTreeUri: string;
  /** 源编辑框最大行数，上游默认 Int.MAX_VALUE。 */
  sourceEditMaxLine: number;
  /** Web 服务端口，上游默认 1122。 */
  webPort: number;
  /**
   * 记录调试日志开关。上游 OtherSettings.kt:22 `val recordLog: Boolean = false`，
   * 落盘键 PreferKey.kt:70 `recordLog`；AppLog.putDebug 用它门控（AppLog.kt:66-70）。
   */
  recordLog: boolean;
  /**
   * 字体列表排序档位。上游 `OtherSettings.kt:28 val fontSort: Int = 0`，
   * 落盘键 `PreferKey.kt:78 fontSort`，0..5 依次对应
   * `FontSelectGrid.kt:72-83 FontSort` 的名称升序/名称降序/大小升序/大小降序/时间升序/时间降序。
   */
  fontSort: number;
}

export const DEFAULT_OTHER_SETTINGS: OtherSettings = {
  defaultBookTreeUri: '',
  sourceEditMaxLine: 2147483647,
  webPort: 1122,
  recordLog: false,
  fontSort: 0
};

export class OtherSettingsRepository {
  private static readonly preferenceName: string = 'legado_other_settings';
  private static readonly keyDefaultBookTreeUri: string = 'defaultBookTreeUri';
  private static readonly keySourceEditMaxLine: string = 'sourceEditMaxLine';
  private static readonly keyWebPort: string = 'webPort';
  private static readonly keyRecordLog: string = 'recordLog';
  private static readonly keyFontSort: string = 'fontSort';
  private static cached: OtherSettings = {
    defaultBookTreeUri: '',
    sourceEditMaxLine: 2147483647,
    webPort: 1122,
    recordLog: false,
    fontSort: 0
  };

  private static publish(settings: OtherSettings): void {
    OtherSettingsRepository.cached = {
      defaultBookTreeUri: settings.defaultBookTreeUri,
      sourceEditMaxLine: settings.sourceEditMaxLine,
      webPort: settings.webPort,
      recordLog: settings.recordLog,
      fontSort: settings.fontSort
    };
  }

  /** 同步取当前缓存；未 load 过时给默认值。 */
  static get(): OtherSettings {
    return {
      defaultBookTreeUri: OtherSettingsRepository.cached.defaultBookTreeUri,
      sourceEditMaxLine: OtherSettingsRepository.cached.sourceEditMaxLine,
      webPort: OtherSettingsRepository.cached.webPort,
      recordLog: OtherSettingsRepository.cached.recordLog,
      fontSort: OtherSettingsRepository.cached.fontSort
    };
  }

  /** 从偏好读一次并进缓存。 */
  static async load(context: Context): Promise<OtherSettings> {
    let defaultBookTreeUri = DEFAULT_OTHER_SETTINGS.defaultBookTreeUri;
    let sourceEditMaxLine = DEFAULT_OTHER_SETTINGS.sourceEditMaxLine;
    let webPort = DEFAULT_OTHER_SETTINGS.webPort;
    let recordLog = DEFAULT_OTHER_SETTINGS.recordLog;
    let fontSort = DEFAULT_OTHER_SETTINGS.fontSort;
    try {
      const store = await preferences.getPreferences(context, OtherSettingsRepository.preferenceName);
      defaultBookTreeUri = store.getSync(OtherSettingsRepository.keyDefaultBookTreeUri, defaultBookTreeUri) as string;
      sourceEditMaxLine = store.getSync(OtherSettingsRepository.keySourceEditMaxLine, sourceEditMaxLine) as number;
      webPort = store.getSync(OtherSettingsRepository.keyWebPort, webPort) as number;
      recordLog = store.getSync(OtherSettingsRepository.keyRecordLog, recordLog) as boolean;
      fontSort = store.getSync(OtherSettingsRepository.keyFontSort, fontSort) as number;
    } catch (error) {
      console.error(`其它设置读取失败：${error instanceof Error ? error.message : String(error)}`);
    }
    const settings: OtherSettings = {
      defaultBookTreeUri: defaultBookTreeUri,
      sourceEditMaxLine: sourceEditMaxLine,
      webPort: webPort,
      recordLog: recordLog,
      fontSort: normalizeAppFontSort(fontSort)
    };
    OtherSettingsRepository.publish(settings);
    return settings;
  }

  /** 写回并刷新缓存。 */
  static async save(context: Context, settings: OtherSettings): Promise<void> {
    const store = await preferences.getPreferences(context, OtherSettingsRepository.preferenceName);
    await store.put(OtherSettingsRepository.keyDefaultBookTreeUri, settings.defaultBookTreeUri);
    await store.put(OtherSettingsRepository.keySourceEditMaxLine, settings.sourceEditMaxLine);
    await store.put(OtherSettingsRepository.keyWebPort, settings.webPort);
    await store.put(OtherSettingsRepository.keyRecordLog, settings.recordLog);
    await store.put(OtherSettingsRepository.keyFontSort, normalizeAppFontSort(settings.fontSort));
    await store.flush();
    OtherSettingsRepository.publish(settings);
  }
}
