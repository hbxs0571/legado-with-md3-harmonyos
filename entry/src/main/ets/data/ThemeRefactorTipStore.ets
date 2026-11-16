import { preferences } from '@kit.ArkData';

/**
 * 「外观页预览卡提示条」的关闭状态持久化。
 *
 * 上游 `ThemeConfigScreen.kt:169` 的提示条受 `theme.showRefactorTip` 控制，
 * 该值由 `FeatureSettingsRepositories.kt:427-429` 读写 `LocalPreferencesKeys.SHOW_THEME_REFACTOR_TIP`，
 * 关闭一次后永久生效（`ThemeConfigViewModel.kt:185-186` 置 false 并落盘）。
 * 本地原先只用 `@State`，退出页面再进来提示条又出现，与上游行为不一致。
 *
 * 存储沿用外观页已有的 `legado_theme` 偏好库（`ThemeSettingsRepository.preferenceName`），
 * 单独一个键，不塞进 `ThemeSnapshot`，避免为一条提示改动主题快照的读写链路。
 */
export class ThemeRefactorTipStore {
  private static readonly preferenceName: string = 'legado_theme';
  private static readonly key: string = 'showThemeRefactorTip';

  /** 读取是否仍显示提示条；首次启动与读取失败都返回 true（对齐上游默认值）。 */
  static async load(context: Context): Promise<boolean> {
    try {
      const store = await preferences.getPreferences(context, ThemeRefactorTipStore.preferenceName);
      const value = await store.get(ThemeRefactorTipStore.key, true);
      return value as boolean;
    } catch (_) {
      return true;
    }
  }

  /** 关闭提示条时写盘。失败不影响界面，下次进来顶多再显示一次。 */
  static async saveHidden(context: Context): Promise<void> {
    try {
      const store = await preferences.getPreferences(context, ThemeRefactorTipStore.preferenceName);
      await store.put(ThemeRefactorTipStore.key, false);
      await store.flush();
    } catch (_) {
    }
  }
}
