import { preferences } from '@kit.ArkData';

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
}

export const DEFAULT_OTHER_SETTINGS: OtherSettings = {
  defaultBookTreeUri: '',
  sourceEditMaxLine: 2147483647,
  webPort: 1122
};

export class OtherSettingsRepository {
  private static readonly preferenceName: string = 'legado_other_settings';
  private static readonly keyDefaultBookTreeUri: string = 'defaultBookTreeUri';
  private static readonly keySourceEditMaxLine: string = 'sourceEditMaxLine';
  private static readonly keyWebPort: string = 'webPort';
  private static cached: OtherSettings = {
    defaultBookTreeUri: '',
    sourceEditMaxLine: 2147483647,
    webPort: 1122
  };

  private static publish(settings: OtherSettings): void {
    OtherSettingsRepository.cached = {
      defaultBookTreeUri: settings.defaultBookTreeUri,
      sourceEditMaxLine: settings.sourceEditMaxLine,
      webPort: settings.webPort
    };
  }

  /** 同步取当前缓存；未 load 过时给默认值。 */
  static get(): OtherSettings {
    return {
      defaultBookTreeUri: OtherSettingsRepository.cached.defaultBookTreeUri,
      sourceEditMaxLine: OtherSettingsRepository.cached.sourceEditMaxLine,
      webPort: OtherSettingsRepository.cached.webPort
    };
  }

  /** 从偏好读一次并进缓存。 */
  static async load(context: Context): Promise<OtherSettings> {
    let defaultBookTreeUri = DEFAULT_OTHER_SETTINGS.defaultBookTreeUri;
    let sourceEditMaxLine = DEFAULT_OTHER_SETTINGS.sourceEditMaxLine;
    let webPort = DEFAULT_OTHER_SETTINGS.webPort;
    try {
      const store = await preferences.getPreferences(context, OtherSettingsRepository.preferenceName);
      defaultBookTreeUri = store.getSync(OtherSettingsRepository.keyDefaultBookTreeUri, defaultBookTreeUri) as string;
      sourceEditMaxLine = store.getSync(OtherSettingsRepository.keySourceEditMaxLine, sourceEditMaxLine) as number;
      webPort = store.getSync(OtherSettingsRepository.keyWebPort, webPort) as number;
    } catch (error) {
      console.error(`其它设置读取失败：${error instanceof Error ? error.message : String(error)}`);
    }
    const settings: OtherSettings = {
      defaultBookTreeUri: defaultBookTreeUri,
      sourceEditMaxLine: sourceEditMaxLine,
      webPort: webPort
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
    await store.flush();
    OtherSettingsRepository.publish(settings);
  }
}
