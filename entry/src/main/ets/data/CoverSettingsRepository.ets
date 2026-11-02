import { preferences } from '@kit.ArkData';
import { Context } from '@kit.AbilityKit';

/**
 * 封面文字设置。
 *
 * 字段名与 Android PreferKey 保持一致，备份写 config.xml 时可直接同名读写。
 * 上游 model 见 legado-with-MD3 的 domain/model/settings/CoverSettings.kt，
 * 这里只取无封面文字绘制需要的那部分，其余（网络封面、相册、规则引擎）不在本轮范围。
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
  infoOrientation: '0'
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
    infoOrientation: settings.infoOrientation
  };
}

/** 封面设置仓储，preferences 名与上游 PreferKey 一致，便于备份按同名键读写。 */
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
}
