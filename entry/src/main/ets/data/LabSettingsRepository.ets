import { preferences } from '@kit.ArkData';

/**
 * 实验室页的三个开关（对应上游 domain/model/settings/LabSettings.kt:3-7 的
 * enabled / eInkDisplay / eyeProtection）。本地单独用一个偏好文件承载，
 * 退出页面与重启后都要保留，不再只活在页面内存里。
 */
export interface LabSettings {
  /** 启用实验室；上游默认 false。 */
  enabled: boolean;
  /** 墨水屏显示；上游默认 false。 */
  eInkDisplay: boolean;
  /** 护眼；上游默认 false。本批只落库，界面行留到后续补。 */
  eyeProtection: boolean;
}

export const DEFAULT_LAB_SETTINGS: LabSettings = {
  enabled: false,
  eInkDisplay: false,
  eyeProtection: false
};

export class LabSettingsRepository {
  private static readonly preferenceName: string = 'legado_lab';
  private static readonly keyEnabled: string = 'enabled';
  private static readonly keyEInkDisplay: string = 'eInkDisplay';
  private static readonly keyEyeProtection: string = 'eyeProtection';
  private static cached: LabSettings = {
    enabled: DEFAULT_LAB_SETTINGS.enabled,
    eInkDisplay: DEFAULT_LAB_SETTINGS.eInkDisplay,
    eyeProtection: DEFAULT_LAB_SETTINGS.eyeProtection
  };

  private static publish(settings: LabSettings): void {
    LabSettingsRepository.cached = {
      enabled: settings.enabled,
      eInkDisplay: settings.eInkDisplay,
      eyeProtection: settings.eyeProtection
    };
  }

  /** 同步取当前缓存；未 load 过时给默认值。 */
  static get(): LabSettings {
    return {
      enabled: LabSettingsRepository.cached.enabled,
      eInkDisplay: LabSettingsRepository.cached.eInkDisplay,
      eyeProtection: LabSettingsRepository.cached.eyeProtection
    };
  }

  /** 从偏好读一次并进缓存。 */
  static async load(context: Context): Promise<LabSettings> {
    let enabled = DEFAULT_LAB_SETTINGS.enabled;
    let eInkDisplay = DEFAULT_LAB_SETTINGS.eInkDisplay;
    let eyeProtection = DEFAULT_LAB_SETTINGS.eyeProtection;
    try {
      const store = await preferences.getPreferences(context, LabSettingsRepository.preferenceName);
      enabled = store.getSync(LabSettingsRepository.keyEnabled, enabled) as boolean;
      eInkDisplay = store.getSync(LabSettingsRepository.keyEInkDisplay, eInkDisplay) as boolean;
      eyeProtection = store.getSync(LabSettingsRepository.keyEyeProtection, eyeProtection) as boolean;
    } catch (error) {
      console.error(`实验室设置读取失败：${error instanceof Error ? error.message : String(error)}`);
    }
    const settings: LabSettings = { enabled: enabled, eInkDisplay: eInkDisplay, eyeProtection: eyeProtection };
    LabSettingsRepository.publish(settings);
    return settings;
  }

  /** 写回并刷新缓存。 */
  static async save(context: Context, settings: LabSettings): Promise<void> {
    const store = await preferences.getPreferences(context, LabSettingsRepository.preferenceName);
    await store.put(LabSettingsRepository.keyEnabled, settings.enabled);
    await store.put(LabSettingsRepository.keyEInkDisplay, settings.eInkDisplay);
    await store.put(LabSettingsRepository.keyEyeProtection, settings.eyeProtection);
    await store.flush();
    LabSettingsRepository.publish(settings);
  }
}
