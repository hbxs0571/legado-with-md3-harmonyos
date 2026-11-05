import { preferences } from '@kit.ArkData';
import { Context } from '@kit.AbilityKit';

/**
 * 封面设置。
 *
 * 本地 preferences 用裸字段名（showName、textColor…）；与上游 Android
 * PreferKey 的双向映射集中在文件末尾的 coverSettingsToAndroid /
 * applyAndroidCoverPreferences 两处，只有备份写 config.xml、从 config.xml
 * 恢复时才做键名与颜色类型转换。上游 model 见 legado-with-MD3 的
 * domain/model/settings/CoverSettings.kt（18 个字段），本地字段与之一一对应。
 */
export interface CoverSettings {
  /** 显示书名。对应 PreferKey.showName，上游默认 true。 */
  showName: boolean;
  /** 显示作者。对应 PreferKey.showAuthor，上游默认 true。 */
  showAuthor: boolean;
  /** 夜间是否显示书名。对应 PreferKey.showNameDark，上游默认 true。 */
  showNameDark: boolean;
  /** 夜间是否显示作者。对应 PreferKey.showAuthorDark，上游默认 true。 */
  showAuthorDark: boolean;
  /** 使用主题默认文字色。对应 PreferKey.useDefaultColor，上游默认 true。 */
  useDefaultColor: boolean;
  /** 日间文字色。对应 PreferKey.textColor，上游默认黑色。 */
  textColor: string;
  /** 夜间文字色。对应 PreferKey.textColorDark，上游默认白色。 */
  textColorDark: string;
  /** 显示描边。对应 PreferKey.showStroke，上游默认 true。 */
  showStroke: boolean;
  /** 显示阴影。对应 PreferKey.showShadow，上游默认 false。 */
  showShadow: boolean;
  /** 文字阴影色。对应 PreferKey.shadowColor。 */
  shadowColor: string;
  /** 夜间文字阴影色。对应 PreferKey.shadowColorDark。 */
  shadowColorDark: string;
  /**
   * 封面信息方向。
   *
   * 对应 PreferKey.infoOrientation：'0' 竖排（上游默认）、'1' 横排。
   * 书名含拉丁字母时上游强制横排，这条规则在绘制时判断，不落这里。
   */
  infoOrientation: string;
  /** 仅 WiFi 下载网络封面。对应 PreferKey.loadCoverOnlyWifi，上游默认 false。 */
  loadOnlyOnWifi: boolean;
  /** 使用默认封面（忽略书籍自带封面）。对应 PreferKey.useDefaultCover，上游默认 false。 */
  useDefaultCover: boolean;
  /** 限制封面比例（开启时固定 5:7，关闭后按原图宽高比）。上游默认 true。 */
  restrictCoverRatio: boolean;
  /** 发现页书籍过滤档位 0..3。对应 PreferKey.explore_filter_state，上游默认 0。 */
  exploreFilterState: number;
  /** 默认封面（日间）遗留路径串。上游默认空串。 */
  defaultCover: string;
  /** 默认封面（夜间）遗留路径串。上游默认空串。 */
  defaultCoverDark: string;
}

/**
 * 默认值。
 *
 * 逐项对齐上游 CoverSettings.kt 的构造默认值：
 * showShadow=false、showStroke=true、useDefaultColor=true、
 * textColor=-16777216（#000000）、textColorDark=-1（#FFFFFF）、
 * shadowColor 同为黑、shadowColorDark 同为白、infoOrientation='0'。
 */
export const DEFAULT_COVER_SETTINGS: CoverSettings = {
  showName: true,
  showAuthor: true,
  showNameDark: true,
  showAuthorDark: true,
  useDefaultColor: true,
  textColor: '#000000',
  textColorDark: '#FFFFFF',
  showStroke: true,
  showShadow: false,
  shadowColor: '#000000',
  shadowColorDark: '#FFFFFF',
  infoOrientation: '0',
  loadOnlyOnWifi: false,
  useDefaultCover: false,
  restrictCoverRatio: true,
  exploreFilterState: 0,
  defaultCover: '',
  defaultCoverDark: ''
};

/** 复制一份，避免 @State 直接持有常量对象被就地修改。 */
export function copyCoverSettings(settings: CoverSettings): CoverSettings {
  return {
    showName: settings.showName,
    showAuthor: settings.showAuthor,
    showNameDark: settings.showNameDark,
    showAuthorDark: settings.showAuthorDark,
    useDefaultColor: settings.useDefaultColor,
    textColor: settings.textColor,
    textColorDark: settings.textColorDark,
    showStroke: settings.showStroke,
    showShadow: settings.showShadow,
    shadowColor: settings.shadowColor,
    shadowColorDark: settings.shadowColorDark,
    infoOrientation: settings.infoOrientation,
    loadOnlyOnWifi: settings.loadOnlyOnWifi,
    useDefaultCover: settings.useDefaultCover,
    restrictCoverRatio: settings.restrictCoverRatio,
    exploreFilterState: settings.exploreFilterState,
    defaultCover: settings.defaultCover,
    defaultCoverDark: settings.defaultCoverDark
  };
}

/** 封面设置仓储，preferences 名与本地裸字段名对应。 */
export class CoverSettingsRepository {
  private static readonly preferenceName: string = 'legado_cover_settings';
  private static cached: CoverSettings = copyCoverSettings(DEFAULT_COVER_SETTINGS);
  private static loaded: boolean = false;
  private static saveQueue: Promise<void> = Promise.resolve();

  /** 读缓存；未 load 过时返回默认值。 */
  static get(): CoverSettings {
    return copyCoverSettings(CoverSettingsRepository.cached);
  }

  static isLoaded(): boolean {
    return CoverSettingsRepository.loaded;
  }

  /** 从 preferences 读取全部字段，缺项按默认值补齐。 */
  static async load(context: Context): Promise<CoverSettings> {
    const settings = copyCoverSettings(DEFAULT_COVER_SETTINGS);
    try {
      const store = await preferences.getPreferences(context, CoverSettingsRepository.preferenceName);
      settings.showName = await CoverSettingsRepository.readBoolean(store, 'showName', settings.showName);
      settings.showAuthor = await CoverSettingsRepository.readBoolean(store, 'showAuthor', settings.showAuthor);
      settings.showNameDark = await CoverSettingsRepository.readBoolean(store, 'showNameDark', settings.showNameDark);
      settings.showAuthorDark = await CoverSettingsRepository.readBoolean(store, 'showAuthorDark', settings.showAuthorDark);
      settings.useDefaultColor = await CoverSettingsRepository.readBoolean(
        store, 'useDefaultColor', settings.useDefaultColor);
      settings.showStroke = await CoverSettingsRepository.readBoolean(store, 'showStroke', settings.showStroke);
      settings.showShadow = await CoverSettingsRepository.readBoolean(store, 'showShadow', settings.showShadow);
      settings.textColor = await CoverSettingsRepository.readColor(store, 'textColor', settings.textColor);
      settings.textColorDark = await CoverSettingsRepository.readColor(store, 'textColorDark', settings.textColorDark);
      settings.shadowColor = await CoverSettingsRepository.readColor(store, 'shadowColor', settings.shadowColor);
      settings.shadowColorDark = await CoverSettingsRepository.readColor(
        store, 'shadowColorDark', settings.shadowColorDark);
      const orientation = await store.get('infoOrientation', settings.infoOrientation);
      settings.infoOrientation = typeof orientation === 'string' && orientation.length > 0
        ? orientation : settings.infoOrientation;
      settings.loadOnlyOnWifi = await CoverSettingsRepository.readBoolean(
        store, 'loadOnlyOnWifi', settings.loadOnlyOnWifi);
      settings.useDefaultCover = await CoverSettingsRepository.readBoolean(
        store, 'useDefaultCover', settings.useDefaultCover);
      settings.restrictCoverRatio = await CoverSettingsRepository.readBoolean(
        store, 'restrictCoverRatio', settings.restrictCoverRatio);
      settings.exploreFilterState = await CoverSettingsRepository.readInt(
        store, 'exploreFilterState', settings.exploreFilterState);
      settings.defaultCover = await CoverSettingsRepository.readString(store, 'defaultCover', settings.defaultCover);
      settings.defaultCoverDark = await CoverSettingsRepository.readString(
        store, 'defaultCoverDark', settings.defaultCoverDark);
    } catch (error) {
      // 读失败时保持默认值：封面画得朴素一点比启动中断更重要。
      console.error(`[CoverSettings] 读取封面设置失败: ${error}`);
    }
    CoverSettingsRepository.cached = copyCoverSettings(settings);
    CoverSettingsRepository.loaded = true;
    return copyCoverSettings(settings);
  }

  /** 覆盖保存整份设置，并按字段写回 preferences。 */
  static async save(context: Context, settings: CoverSettings): Promise<void> {
    const snapshot = copyCoverSettings(settings);
    const operation = CoverSettingsRepository.saveQueue.then(async (): Promise<void> => {
      const store = await preferences.getPreferences(context, CoverSettingsRepository.preferenceName);
      await store.put('showName', snapshot.showName);
      await store.put('showAuthor', snapshot.showAuthor);
      await store.put('showNameDark', snapshot.showNameDark);
      await store.put('showAuthorDark', snapshot.showAuthorDark);
      await store.put('useDefaultColor', snapshot.useDefaultColor);
      await store.put('showStroke', snapshot.showStroke);
      await store.put('showShadow', snapshot.showShadow);
      await store.put('textColor', snapshot.textColor);
      await store.put('textColorDark', snapshot.textColorDark);
      await store.put('shadowColor', snapshot.shadowColor);
      await store.put('shadowColorDark', snapshot.shadowColorDark);
      await store.put('infoOrientation', snapshot.infoOrientation);
      await store.put('loadOnlyOnWifi', snapshot.loadOnlyOnWifi);
      await store.put('useDefaultCover', snapshot.useDefaultCover);
      await store.put('restrictCoverRatio', snapshot.restrictCoverRatio);
      await store.put('exploreFilterState', snapshot.exploreFilterState);
      await store.put('defaultCover', snapshot.defaultCover);
      await store.put('defaultCoverDark', snapshot.defaultCoverDark);
      await store.flush();
      CoverSettingsRepository.cached = copyCoverSettings(snapshot);
      CoverSettingsRepository.loaded = true;
    });
    CoverSettingsRepository.saveQueue = operation.then((): void => undefined, (): void => undefined);
    await operation;
  }

  private static async readBoolean(
    store: preferences.Preferences, key: string, fallback: boolean
  ): Promise<boolean> {
    const value = await store.get(key, fallback);
    return typeof value === 'boolean' ? value : fallback;
  }

  private static async readColor(
    store: preferences.Preferences, key: string, fallback: string
  ): Promise<string> {
    const value = await store.get(key, fallback);
    return typeof value === 'string' && value.length > 0 ? value : fallback;
  }

  private static async readString(
    store: preferences.Preferences, key: string, fallback: string
  ): Promise<string> {
    const value = await store.get(key, fallback);
    return typeof value === 'string' ? value : fallback;
  }

  private static async readInt(
    store: preferences.Preferences, key: string, fallback: number
  ): Promise<number> {
    const value = await store.get(key, fallback);
    return typeof value === 'number' ? value : fallback;
  }
}

/** '#RRGGBB' → Android argb Int（0xFFRRGGBB 的 32 位有符号形式）。 */
export function coverColorToAndroidInt(color: string): number {
  const hex = color.startsWith('#') ? color.slice(1) : color;
  if (hex.length !== 6) {
    return -16777216;
  }
  const rgb = parseInt(hex, 16);
  if (isNaN(rgb)) {
    return -16777216;
  }
  return 0xFF000000 | rgb;
}

/** Android argb Int → '#RRGGBB'（忽略 alpha 通道）。 */
export function androidIntToCoverColor(value: number): string {
  const rgb = value & 0x00FFFFFF;
  return `#${rgb.toString(16).padStart(6, '0')}`;
}

/** 一条封面偏好在 Android config.xml 里的形态。 */
export interface AndroidCoverPreference {
  /** 上游 PreferKey 名。 */
  key: string;
  /** config.xml 里的元素类型。 */
  type: 'boolean' | 'int' | 'string';
  /** 已转成 XML 可取值的字符串。 */
  value: string;
}

/**
 * 本地字段名 ↔ 上游 PreferKey 名的唯一映射表。
 *
 * 14 个键与 help/storage/BackupConfig.kt:396-411 的 coverPrefKeys 逐键相同；
 * 颜色字段在此完成 '#RRGGBB' ↔ Int 的转换，调用方不需要知道本地字段名。
 */
export function coverSettingsToAndroid(settings: CoverSettings): AndroidCoverPreference[] {
  return [
    { key: 'coverShowName', type: 'boolean', value: String(settings.showName) },
    { key: 'coverShowNameN', type: 'boolean', value: String(settings.showNameDark) },
    { key: 'coverShowAuthor', type: 'boolean', value: String(settings.showAuthor) },
    { key: 'coverShowAuthorN', type: 'boolean', value: String(settings.showAuthorDark) },
    { key: 'coverShowShadow', type: 'boolean', value: String(settings.showShadow) },
    { key: 'coverShowStroke', type: 'boolean', value: String(settings.showStroke) },
    { key: 'coverTextColor', type: 'int', value: String(coverColorToAndroidInt(settings.textColor)) },
    { key: 'coverTextColorN', type: 'int', value: String(coverColorToAndroidInt(settings.textColorDark)) },
    { key: 'coverShadowColor', type: 'int', value: String(coverColorToAndroidInt(settings.shadowColor)) },
    { key: 'coverShadowColorN', type: 'int', value: String(coverColorToAndroidInt(settings.shadowColorDark)) },
    { key: 'coverDefaultColor', type: 'boolean', value: String(settings.useDefaultColor) },
    { key: 'coverInfoOrientation', type: 'string', value: settings.infoOrientation },
    { key: 'useDefaultCover', type: 'boolean', value: String(settings.useDefaultCover) },
    { key: 'loadCoverOnlyWifi', type: 'boolean', value: String(settings.loadOnlyOnWifi) }
  ];
}

/**
 * 反向映射：把 Android config.xml 读到的 14 个键回填进本地设置。
 *
 * 与 coverSettingsToAndroid 共用同一张键表，恢复侧不需要再写一遍字段名。
 */
export function applyAndroidCoverPreferences(
  current: CoverSettings, values: Map<string, string>
): CoverSettings {
  const merged = copyCoverSettings(current);
  const showName = values.get('coverShowName');
  if (showName !== undefined) {
    merged.showName = showName === 'true';
  }
  const showNameDark = values.get('coverShowNameN');
  if (showNameDark !== undefined) {
    merged.showNameDark = showNameDark === 'true';
  }
  const showAuthor = values.get('coverShowAuthor');
  if (showAuthor !== undefined) {
    merged.showAuthor = showAuthor === 'true';
  }
  const showAuthorDark = values.get('coverShowAuthorN');
  if (showAuthorDark !== undefined) {
    merged.showAuthorDark = showAuthorDark === 'true';
  }
  const showShadow = values.get('coverShowShadow');
  if (showShadow !== undefined) {
    merged.showShadow = showShadow === 'true';
  }
  const showStroke = values.get('coverShowStroke');
  if (showStroke !== undefined) {
    merged.showStroke = showStroke === 'true';
  }
  const textColor = values.get('coverTextColor');
  if (textColor !== undefined) {
    const parsed = parseInt(textColor, 10);
    if (!isNaN(parsed)) {
      merged.textColor = androidIntToCoverColor(parsed);
    }
  }
  const textColorDark = values.get('coverTextColorN');
  if (textColorDark !== undefined) {
    const parsed = parseInt(textColorDark, 10);
    if (!isNaN(parsed)) {
      merged.textColorDark = androidIntToCoverColor(parsed);
    }
  }
  const shadowColor = values.get('coverShadowColor');
  if (shadowColor !== undefined) {
    const parsed = parseInt(shadowColor, 10);
    if (!isNaN(parsed)) {
      merged.shadowColor = androidIntToCoverColor(parsed);
    }
  }
  const shadowColorDark = values.get('coverShadowColorN');
  if (shadowColorDark !== undefined) {
    const parsed = parseInt(shadowColorDark, 10);
    if (!isNaN(parsed)) {
      merged.shadowColorDark = androidIntToCoverColor(parsed);
    }
  }
  const useDefaultColor = values.get('coverDefaultColor');
  if (useDefaultColor !== undefined) {
    merged.useDefaultColor = useDefaultColor === 'true';
  }
  const infoOrientation = values.get('coverInfoOrientation');
  if (infoOrientation !== undefined) {
    merged.infoOrientation = infoOrientation;
  }
  const useDefaultCover = values.get('useDefaultCover');
  if (useDefaultCover !== undefined) {
    merged.useDefaultCover = useDefaultCover === 'true';
  }
  const loadOnlyOnWifi = values.get('loadCoverOnlyWifi');
  if (loadOnlyOnWifi !== undefined) {
    merged.loadOnlyOnWifi = loadOnlyOnWifi === 'true';
  }
  return merged;
}
