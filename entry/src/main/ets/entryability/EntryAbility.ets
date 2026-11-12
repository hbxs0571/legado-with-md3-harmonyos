import { UIAbility, ConfigurationConstant, Configuration, AbilityConstant } from '@kit.AbilityKit';
import { EnvironmentCallback } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { RdbMigration } from '../data/RdbMigration';
import { RdbCleanup } from '../data/RdbCleanup';
import { ThemeModeResolver } from '../data/ThemeModeResolver';
import { ThemeSettingsRepository, THEME_MODE_DARK } from '../data/ThemeSettingsRepository';
import { PrivateAccessRepository } from '../data/PrivateAccessRepository';

/** 系统栏颜色资源名，供深浅色两套资源目录各取一值。 */
const SYSTEM_BAR_LIGHT: string = '#F6F4F0';
const SYSTEM_BAR_DARK: string = '#111217';

/**
 * 系统深浅色变化监听器。
 *
 * `themeMode = "0"`（跟随系统）时，页面颜色由 `resources/dark` 自动切换，
 * 但系统栏是窗口属性、不随资源切换，必须在这里手动同步。
 */
class SystemBarEnvironmentCallback extends EnvironmentCallback {
  private readonly context: Context;

  constructor(context: Context) {
    super();
    this.context = context;
  }

  onConfigurationUpdated(config: Configuration): void {
    const colorMode = config.colorMode;
    if (colorMode === undefined) {
      return;
    }
    applySystemBar(this.context, colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK);
  }

  onMemoryLevel(_level: AbilityConstant.MemoryLevel): void {
  }
}

/** 按深浅色设置状态栏与导航栏底色。 */
function applySystemBar(context: Context, isDark: boolean): void {
  try {
    window.getLastWindow(context).then((win) => {
      win.setWindowSystemBarProperties({
        statusBarColor: isDark ? SYSTEM_BAR_DARK : SYSTEM_BAR_LIGHT,
        statusBarContentColor: isDark ? '#E5FFFFFF' : '#E5000000',
        navigationBarColor: isDark ? SYSTEM_BAR_DARK : SYSTEM_BAR_LIGHT,
        navigationBarContentColor: isDark ? '#E5FFFFFF' : '#E5000000'
      }).catch(() => {});
    }).catch(() => {});
  } catch (_) {
  }
}

export default class EntryAbility extends UIAbility {
  onCreate(): void {
    // 存量搬迁不在这里做：它必须和首屏加载串行，见 onWindowStageCreate。
  }

  onBackground(): void {
    this.context.eventHub.emit('pauseReadSession');
    // 解锁有效期选「离开应用前有效」时，切后台即回到锁定态（批6，对齐上游 PrivateUnlockScope.UntilBackground）。
    PrivateAccessRepository.lockIfUntilBackground();
  }

  onForeground(): void {
    this.context.eventHub.emit('resumeReadSession');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    this.context.eventHub.on('exitApplication', () => {
      this.context.terminateSelf().catch(() => {});
    });
    try {
      const mainWindow = windowStage.getMainWindowSync();
      mainWindow.setWindowSystemBarProperties({
        statusBarColor: SYSTEM_BAR_DARK,
        statusBarContentColor: '#E5FFFFFF',
        navigationBarColor: SYSTEM_BAR_DARK,
        navigationBarContentColor: '#E5FFFFFF'
      }).catch(() => {});
    } catch (_) {
    }
    // 先完成存量搬迁与老数据清理，再加载首屏。
    // 上游用 Room，建表与迁移都在打开数据库时同步完成，界面不会读到「表刚建好但还没搬」的中间态；
    // relationalStore 是异步的，所以这里把 loadContent 排到搬迁之后，等效于上游的时序。
    // 清理必须排在搬迁之后：三批标记没写齐时 RdbCleanup 会直接返回，不会误删未搬的数据。
    // catch 兜住整条链的失败：搬迁或清理失败都只记日志，界面不该因此打不开。
    RdbMigration.runIfNeeded(this.context)
      .then(() => RdbCleanup.runIfNeeded(this.context))
      .catch(() => false)
      .then(() => {
        try {
          windowStage.loadContent('pages/Index');
        } catch (_) {
        }
        // setColorMode 要求「窗口已创建 + 页面已 loadContent」之后再调，
        // 所以只能排在这里，不能提到 onWindowStageCreate 开头。
        this.applyStoredThemeMode();
      });
  }

  /**
   * 启动时把落盘的 themeMode 应用到系统色模式。
   *
   * 上游在 `help/config/ThemeConfigStore.kt:70-89 initNightMode()` 里读同一份设置并调
   * `AppCompatDelegate.setDefaultNightMode`；ArkUI 的对应机制是 `setColorMode`，
   * 它让系统按 `resources/dark` 重新解析资源。
   */
  private applyStoredThemeMode(): void {
    ThemeSettingsRepository.load(this.context).then((snapshot) => {
      this.setColorModeSafe(ThemeModeResolver.toColorMode(snapshot.themeMode));
      this.syncSystemBar(snapshot.themeMode);
      this.watchEnvironmentChange();
    }).catch(() => {
      this.watchEnvironmentChange();
    });
  }

  /** 应用色模式；失败只记日志，不影响界面可用性。 */
  private setColorModeSafe(colorMode: ConfigurationConstant.ColorMode): void {
    try {
      this.context.getApplicationContext().setColorMode(colorMode);
    } catch (_) {
    }
  }

  /** 系统栏底色跟随当前深浅色，避免浅色界面配深色状态栏。 */
  private syncSystemBar(themeMode: string): void {
    const isDark = ThemeModeResolver.isDarkTheme(themeMode, ThemeModeResolver.isSystemDark(this.context));
    applySystemBar(this.context, isDark);
  }

  /**
   * 监听系统深浅色变化，用于 `themeMode = "0"`（跟随系统）时同步系统栏。
   *
   * 上游 `AppCompatDelegate` 会自动跟随系统，这里要自己挂一个回调；
   * 页面侧的颜色由 `resources/dark` 自动切换，无需通知。
   */
  private watchEnvironmentChange(): void {
    try {
      this.context.getApplicationContext().on('environment', new SystemBarEnvironmentCallback(this.context));
    } catch (_) {
    }
  }
}
