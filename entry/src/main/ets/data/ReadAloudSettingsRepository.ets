import { preferences } from '@kit.ArkData';

/**
 * 朗读（TTS）偏好仓库。
 *
 * 对应上游 36 字段 ReadAloudSettings 里本地能消费的 14 个子集，键名逐字对齐上游
 * PreferKey（见 readaloud-evidence.md 9.1 第四列）：
 * capsuleOffsetX/Y 没有 PreferKey 常量，上游走 floatPreferencesKey，键名是
 * read_aloud_capsule_offset_x / read_aloud_capsule_offset_y，本地照抄这两个字符串。
 *
 * 偏好名与 ReaderSettingsRepository 同范式，独立成一个 store，避免阅读设置的
 * 键空间被朗读键污染；备份写出/恢复靠 toAndroidValues / mergeAndroidValues 做桥接。
 */
export interface ReadAloudSettingsSnapshot {
  /** 语速档 0..80；系统 TTS 不支持调速，仅 HTTP 朗读源消费（批 8）。 */
  ttsSpeechRate: number;
  /** HTTP 源是否跟随系统语速（true 用 1.0 倍）；系统 TTS 不消费。 */
  ttsFollowSys: boolean;
  /** 段间停顿毫秒数；系统 TTS 在 onComplete 后延时下一段（批 3）。 */
  ttsParagraphInterval: number;
  /** 切段模式：default | paragraph | page | symbols（批 2）。 */
  contentSplitMode: string;
  /** symbols 档的标点集，逗号分隔；空串回退 。！？…（批 2）。 */
  contentSplitSymbols: string;
  /** 是否启用多Speaker切分；本地只切段不做角色分配，字段保留作备份互通。 */
  useMultiSpeaker: boolean;
  /** 朗读胶囊显隐（批 6）。 */
  showReadAloudCapsule: boolean;
  /** 胶囊自动收起（批 6）。 */
  capsuleAutoCollapse: boolean;
  /** 胶囊水平偏移，对应上游 read_aloud_capsule_offset_x（批 6）。 */
  capsuleOffsetX: number;
  /** 胶囊垂直偏移，对应上游 read_aloud_capsule_offset_y（批 6）。 */
  capsuleOffsetY: number;
  /** 定时分钟数，0 表示关闭（批 5）。 */
  ttsTimer: number;
  /** 定时模式：minute | chapter（批 5）。 */
  timerMode: string;
  /** 按章节定时时的章节数（批 5）。 */
  timerChapters: number;
  /** 朗读界面档位：classic | player（从设置面板选择默认进入哪一档）。 */
  defaultInterface: string;
  /** 预合成并发数 1..8，默认 3（上游 ttsPreSynthesisConcurrency，经 HTTP 源消费）。 */
  preSynthesisConcurrency: number;
  /** 音频缓存定时清理分钟数 0..10080，默认 10（上游 audioCacheCleanTime）。 */
  audioCacheCleanTime: number;
  /** 播放器背景模式 0..3（上游 readAloudPlayerBgMode，对应 Blur 等四档）。 */
  playerBgMode: number;
}

/** 17 字段默认值，全部照上游 ReadAloudSettings.kt 的 data class 默认值。 */
export const DEFAULT_READ_ALOUD_SETTINGS: ReadAloudSettingsSnapshot = {
  ttsSpeechRate: 5,
  ttsFollowSys: true,
  ttsParagraphInterval: 0,
  contentSplitMode: 'default',
  contentSplitSymbols: '',
  useMultiSpeaker: true,
  showReadAloudCapsule: true,
  capsuleAutoCollapse: true,
  capsuleOffsetX: 0,
  capsuleOffsetY: 0,
  ttsTimer: 0,
  timerMode: 'minute',
  timerChapters: 0,
  defaultInterface: 'classic',
  preSynthesisConcurrency: 3,
  audioCacheCleanTime: 10,
  playerBgMode: 1
};

/**
 * 17 个键写进 Android config.xml 时的标签类型，键名即偏好键名（上游 PreferKey）。
 * 供 BackupRepository 逐个 upsert 时选标签用；contentSplitSymbols 上游是 Set<String>，
 * 本地按任务书用逗号串存，写出用 string 标签（本地扩展，读回仍是同一个串）。
 */
export const READ_ALOUD_SETTINGS_ANDROID_TYPES: Map<string, string> = new Map<string, string>([
  ['ttsSpeechRate', 'int'],
  ['ttsFollowSys', 'boolean'],
  ['ttsParagraphInterval', 'int'],
  ['readAloudContentSplitMode', 'string'],
  ['readAloudContentSplitSymbols', 'string'],
  ['useMultiSpeaker', 'boolean'],
  ['showReadAloudCapsule', 'boolean'],
  ['capsuleAutoCollapse', 'boolean'],
  ['read_aloud_capsule_offset_x', 'float'],
  ['read_aloud_capsule_offset_y', 'float'],
  ['ttsTimer', 'int'],
  ['readAloudTimerMode', 'string'],
  ['readAloudTimerChapters', 'int'],
  ['defaultReadAloudInterface', 'string'],
  ['ttsPreSynthesisConcurrency', 'int'],
  ['audioCacheCleanTime', 'int'],
  ['readAloudPlayerBgMode', 'int']
]);

export function copyReadAloudSettings(settings: ReadAloudSettingsSnapshot): ReadAloudSettingsSnapshot {
  return {
    ttsSpeechRate: settings.ttsSpeechRate,
    ttsFollowSys: settings.ttsFollowSys,
    ttsParagraphInterval: settings.ttsParagraphInterval,
    contentSplitMode: settings.contentSplitMode,
    contentSplitSymbols: settings.contentSplitSymbols,
    useMultiSpeaker: settings.useMultiSpeaker,
    showReadAloudCapsule: settings.showReadAloudCapsule,
    capsuleAutoCollapse: settings.capsuleAutoCollapse,
    capsuleOffsetX: settings.capsuleOffsetX,
    capsuleOffsetY: settings.capsuleOffsetY,
    ttsTimer: settings.ttsTimer,
    timerMode: settings.timerMode,
    timerChapters: settings.timerChapters,
    defaultInterface: settings.defaultInterface,
    preSynthesisConcurrency: settings.preSynthesisConcurrency,
    audioCacheCleanTime: settings.audioCacheCleanTime,
    playerBgMode: settings.playerBgMode
  };
}

export class ReadAloudSettingsRepository {
  private static readonly preferenceName: string = 'legado_read_aloud_settings';
  private static saveQueue: Promise<void> = Promise.resolve();

  /** 从偏好 store 读 17 键；任一读取异常都不覆盖已经读到的值，返回当前快照。 */
  static async load(context: Context): Promise<ReadAloudSettingsSnapshot> {
    const settings: ReadAloudSettingsSnapshot = copyReadAloudSettings(DEFAULT_READ_ALOUD_SETTINGS);
    try {
      const store = await preferences.getPreferences(context, ReadAloudSettingsRepository.preferenceName);
      settings.ttsSpeechRate = await store.get('ttsSpeechRate', DEFAULT_READ_ALOUD_SETTINGS.ttsSpeechRate) as number;
      settings.ttsFollowSys = await store.get('ttsFollowSys', DEFAULT_READ_ALOUD_SETTINGS.ttsFollowSys) as boolean;
      settings.ttsParagraphInterval = await store.get('ttsParagraphInterval', DEFAULT_READ_ALOUD_SETTINGS.ttsParagraphInterval) as number;
      settings.contentSplitMode = await store.get('readAloudContentSplitMode', DEFAULT_READ_ALOUD_SETTINGS.contentSplitMode) as string;
      settings.contentSplitSymbols = await store.get('readAloudContentSplitSymbols', DEFAULT_READ_ALOUD_SETTINGS.contentSplitSymbols) as string;
      settings.useMultiSpeaker = await store.get('useMultiSpeaker', DEFAULT_READ_ALOUD_SETTINGS.useMultiSpeaker) as boolean;
      settings.showReadAloudCapsule = await store.get('showReadAloudCapsule', DEFAULT_READ_ALOUD_SETTINGS.showReadAloudCapsule) as boolean;
      settings.capsuleAutoCollapse = await store.get('capsuleAutoCollapse', DEFAULT_READ_ALOUD_SETTINGS.capsuleAutoCollapse) as boolean;
      settings.capsuleOffsetX = await store.get('read_aloud_capsule_offset_x', DEFAULT_READ_ALOUD_SETTINGS.capsuleOffsetX) as number;
      settings.capsuleOffsetY = await store.get('read_aloud_capsule_offset_y', DEFAULT_READ_ALOUD_SETTINGS.capsuleOffsetY) as number;
      settings.ttsTimer = await store.get('ttsTimer', DEFAULT_READ_ALOUD_SETTINGS.ttsTimer) as number;
      settings.timerMode = await store.get('readAloudTimerMode', DEFAULT_READ_ALOUD_SETTINGS.timerMode) as string;
      settings.timerChapters = await store.get('readAloudTimerChapters', DEFAULT_READ_ALOUD_SETTINGS.timerChapters) as number;
      settings.defaultInterface = await store.get('defaultReadAloudInterface', DEFAULT_READ_ALOUD_SETTINGS.defaultInterface) as string;
      settings.preSynthesisConcurrency = await store.get('ttsPreSynthesisConcurrency', DEFAULT_READ_ALOUD_SETTINGS.preSynthesisConcurrency) as number;
      settings.audioCacheCleanTime = await store.get('audioCacheCleanTime', DEFAULT_READ_ALOUD_SETTINGS.audioCacheCleanTime) as number;
      settings.playerBgMode = await store.get('readAloudPlayerBgMode', DEFAULT_READ_ALOUD_SETTINGS.playerBgMode) as number;
    } catch (error) {
      console.error(`朗读偏好读取失败：${error instanceof Error ? error.message : String(error)}`);
    }
    return settings;
  }

  /** 写 17 键，串行队列 + flush，范式与 ReaderSettingsRepository.save 一致。 */
  static save(context: Context, settings: ReadAloudSettingsSnapshot): Promise<void> {
    const operation = ReadAloudSettingsRepository.saveQueue.then(async (): Promise<void> => {
      const store = await preferences.getPreferences(context, ReadAloudSettingsRepository.preferenceName);
      await store.put('ttsSpeechRate', settings.ttsSpeechRate);
      await store.put('ttsFollowSys', settings.ttsFollowSys);
      await store.put('ttsParagraphInterval', settings.ttsParagraphInterval);
      await store.put('readAloudContentSplitMode', settings.contentSplitMode);
      await store.put('readAloudContentSplitSymbols', settings.contentSplitSymbols);
      await store.put('useMultiSpeaker', settings.useMultiSpeaker);
      await store.put('showReadAloudCapsule', settings.showReadAloudCapsule);
      await store.put('capsuleAutoCollapse', settings.capsuleAutoCollapse);
      await store.put('read_aloud_capsule_offset_x', settings.capsuleOffsetX);
      await store.put('read_aloud_capsule_offset_y', settings.capsuleOffsetY);
      await store.put('ttsTimer', settings.ttsTimer);
      await store.put('readAloudTimerMode', settings.timerMode);
      await store.put('readAloudTimerChapters', settings.timerChapters);
      await store.put('defaultReadAloudInterface', settings.defaultInterface);
      await store.put('ttsPreSynthesisConcurrency', settings.preSynthesisConcurrency);
      await store.put('audioCacheCleanTime', settings.audioCacheCleanTime);
      await store.put('readAloudPlayerBgMode', settings.playerBgMode);
      await store.flush();
    });
    ReadAloudSettingsRepository.saveQueue = operation.then((): void => {}, (_error: Error): void => {});
    return operation;
  }

  /** 备份写出：转成 config.xml 键值对，键名即上游 PreferKey。 */
  static toAndroidValues(settings: ReadAloudSettingsSnapshot): Map<string, string> {
    const values = new Map<string, string>();
    values.set('ttsSpeechRate', `${settings.ttsSpeechRate}`);
    values.set('ttsFollowSys', `${settings.ttsFollowSys}`);
    values.set('ttsParagraphInterval', `${settings.ttsParagraphInterval}`);
    values.set('readAloudContentSplitMode', settings.contentSplitMode);
    values.set('readAloudContentSplitSymbols', settings.contentSplitSymbols);
    values.set('useMultiSpeaker', `${settings.useMultiSpeaker}`);
    values.set('showReadAloudCapsule', `${settings.showReadAloudCapsule}`);
    values.set('capsuleAutoCollapse', `${settings.capsuleAutoCollapse}`);
    values.set('read_aloud_capsule_offset_x', `${settings.capsuleOffsetX}`);
    values.set('read_aloud_capsule_offset_y', `${settings.capsuleOffsetY}`);
    values.set('ttsTimer', `${settings.ttsTimer}`);
    values.set('readAloudTimerMode', settings.timerMode);
    values.set('readAloudTimerChapters', `${settings.timerChapters}`);
    values.set('defaultReadAloudInterface', settings.defaultInterface);
    values.set('ttsPreSynthesisConcurrency', `${settings.preSynthesisConcurrency}`);
    values.set('audioCacheCleanTime', `${settings.audioCacheCleanTime}`);
    values.set('readAloudPlayerBgMode', `${settings.playerBgMode}`);
    return values;
  }

  /**
   * 备份恢复：只覆盖 values 里确实存在的键，缺失的保持当前值，
   * 与上游恢复时逐项 readPreference 的语义、BookshelfLayoutRepository 范式一致。
   */
  static mergeAndroidValues(
    current: ReadAloudSettingsSnapshot,
    values: Map<string, string>
  ): ReadAloudSettingsSnapshot {
    const merged = copyReadAloudSettings(current);
    const rate = ReadAloudSettingsRepository.parseAndroidInt(values.get('ttsSpeechRate'));
    if (rate !== undefined) { merged.ttsSpeechRate = rate; }
    const followSys = ReadAloudSettingsRepository.parseAndroidBoolean(values.get('ttsFollowSys'));
    if (followSys !== undefined) { merged.ttsFollowSys = followSys; }
    const interval = ReadAloudSettingsRepository.parseAndroidInt(values.get('ttsParagraphInterval'));
    if (interval !== undefined) { merged.ttsParagraphInterval = interval; }
    const splitMode = values.get('readAloudContentSplitMode');
    if (splitMode !== undefined) { merged.contentSplitMode = splitMode; }
    const splitSymbols = values.get('readAloudContentSplitSymbols');
    if (splitSymbols !== undefined) { merged.contentSplitSymbols = splitSymbols; }
    const multiSpeaker = ReadAloudSettingsRepository.parseAndroidBoolean(values.get('useMultiSpeaker'));
    if (multiSpeaker !== undefined) { merged.useMultiSpeaker = multiSpeaker; }
    const capsule = ReadAloudSettingsRepository.parseAndroidBoolean(values.get('showReadAloudCapsule'));
    if (capsule !== undefined) { merged.showReadAloudCapsule = capsule; }
    const autoCollapse = ReadAloudSettingsRepository.parseAndroidBoolean(values.get('capsuleAutoCollapse'));
    if (autoCollapse !== undefined) { merged.capsuleAutoCollapse = autoCollapse; }
    const offsetX = ReadAloudSettingsRepository.parseAndroidFloat(values.get('read_aloud_capsule_offset_x'));
    if (offsetX !== undefined) { merged.capsuleOffsetX = offsetX; }
    const offsetY = ReadAloudSettingsRepository.parseAndroidFloat(values.get('read_aloud_capsule_offset_y'));
    if (offsetY !== undefined) { merged.capsuleOffsetY = offsetY; }
    const timer = ReadAloudSettingsRepository.parseAndroidInt(values.get('ttsTimer'));
    if (timer !== undefined) { merged.ttsTimer = timer; }
    const timerMode = values.get('readAloudTimerMode');
    if (timerMode !== undefined) { merged.timerMode = timerMode; }
    const timerChapters = ReadAloudSettingsRepository.parseAndroidInt(values.get('readAloudTimerChapters'));
    if (timerChapters !== undefined) { merged.timerChapters = timerChapters; }
    const defaultInterface = values.get('defaultReadAloudInterface');
    if (defaultInterface !== undefined) { merged.defaultInterface = defaultInterface; }
    const concurrency = ReadAloudSettingsRepository.parseAndroidInt(values.get('ttsPreSynthesisConcurrency'));
    if (concurrency !== undefined) { merged.preSynthesisConcurrency = concurrency; }
    const cleanTime = ReadAloudSettingsRepository.parseAndroidInt(values.get('audioCacheCleanTime'));
    if (cleanTime !== undefined) { merged.audioCacheCleanTime = cleanTime; }
    const bgMode = ReadAloudSettingsRepository.parseAndroidInt(values.get('readAloudPlayerBgMode'));
    if (bgMode !== undefined) { merged.playerBgMode = bgMode; }
    return merged;
  }

  private static parseAndroidInt(raw: string | undefined): number | undefined {
    if (raw === undefined) { return undefined; }
    const value = Number.parseInt(raw, 10);
    return Number.isNaN(value) ? undefined : value;
  }

  private static parseAndroidFloat(raw: string | undefined): number | undefined {
    if (raw === undefined) { return undefined; }
    const value = Number.parseFloat(raw);
    return Number.isNaN(value) ? undefined : value;
  }

  private static parseAndroidBoolean(raw: string | undefined): boolean | undefined {
    if (raw === undefined) { return undefined; }
    if (raw === 'true') { return true; }
    if (raw === 'false') { return false; }
    return undefined;
  }
}
