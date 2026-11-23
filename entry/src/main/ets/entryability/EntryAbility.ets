import { UIAbility, ConfigurationConstant, Configuration, AbilityConstant } from '@kit.AbilityKit';
import { EnvironmentCallback } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { RdbMigration } from '../data/RdbMigration';
import { RdbCleanup } from '../data/RdbCleanup';
import { ThemeModeResolver } from '../data/ThemeModeResolver';
import { ThemeSettingsRepository, THEME_MODE_DARK } from '../data/ThemeSettingsRepository';
import { applyStartWindowBackgroundColor, preloadInitialThemeColors } from '../data/StartWindowBackground';
import { PrivateAccessRepository } from '../data/PrivateAccessRepository';
import { BookRepository } from '../data/BookRepository';
import { BookSourceRuntimeStore } from '@legado/sourceengine';
import { BookSourceRuntimePersistenceImpl } from '../bookSource/BookSourceRuntimePersistenceImpl';
import { OnlineBookService } from '../bookSource/OnlineBookService';
import { ChapterDownloadQueue } from '../bookSource/ChapterDownloadQueue';
import { CrashHandler } from '../lib/CrashHandler';

/**
 * 系统栏底色：全屏布局下恒透明。
 *
 * 上游 `base/BaseActivity.kt` 与 `base/BaseComposeActivity.kt` 都调 `enableEdgeToEdge()`，
 * 页面自己画到状态栏底下；本地对应的是 `setWindowLayoutFullScreen(true)`，
 * 打开后系统不再为两条栏铺底色，这里必须给透明，否则会盖出两条实色横条。
 */
const SYSTEM_BAR_TRANSPARENT: string = '#00000000';

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

/**
 * 按深浅色设置状态栏与导航栏。
 *
 * 打开 `setWindowLayoutFullScreen(true)` 之后，两条栏的区域不再由系统涂色、而是透出页面内容
 * （对齐上游 `enableEdgeToEdge()`），所以这里两条栏的底色恒为透明，只保留图标/文字的前景深浅。
 * 若仍按深浅色涂实底，内容向上延展后会在状态栏位置压一条与页面脱节的横条 —— 正是这次要修的现象。
 */
function applySystemBar(context: Context, isDark: boolean): void {
  try {
    window.getLastWindow(context).then((win) => {
      win.setWindowSystemBarProperties({
        statusBarColor: SYSTEM_BAR_TRANSPARENT,
        statusBarContentColor: isDark ? '#E5FFFFFF' : '#E5000000',
        navigationBarColor: SYSTEM_BAR_TRANSPARENT,
        navigationBarContentColor: isDark ? '#E5FFFFFF' : '#E5000000'
      }).catch(() => {});
    }).catch(() => {});
  } catch (_) {
  }
}

export default class EntryAbility extends UIAbility {
  onCreate(): void {
    // 安装书源引擎的运行时持久化：引擎自己不开库，登录态与书源读取都经这里。
    // 仓储缓存此时可能还没 load（首屏才 load），但 getBookSource 走 getAll 是同步快照，
    // 首次调用发生在用户点搜索之后，那时缓存已就绪。
    BookSourceRuntimeStore.install(new BookSourceRuntimePersistenceImpl(this.context));
    // 全局未捕获异常落盘（缺口 39，对齐上游 CrashHandler.kt:36-38 的
    // Thread.setDefaultUncaughtExceptionHandler）。装在这里是因为它必须在任何
    // 业务代码之前生效，且要早于首屏 —— 启动阶段的崩溃也要能留下日志。
    CrashHandler.install(this.context);
    // 在线书内容提供器（P3-E）：缓存优先 + 书源网络兜底，供在线书打开阅读用。
    // 批2（:455）：同一个实例也装进下载队列 —— 队列判「这章缓存在不在」与阅读时读缓存
    // 必须是同一份路径规则，两个实例各建目录名只会互相看不见。
    const onlineBookProvider = new OnlineBookService(this.context);
    BookRepository.installOnlineProvider(onlineBookProvider);
    ChapterDownloadQueue.install(onlineBookProvider);
    // 首帧之前把落盘的主题色同步灌进 AppStorage（批 1，对齐用户「概率性白闪」的反馈）：
    // Index 的 @StorageProp 默认值是浅色，真值要到 restoreOnboarding 的一串 await 之后才广播，
    // 深色主题下首帧就会用浅色画一遍。这里早于窗口创建与 loadContent，是唯一赶得上的位置。
    preloadInitialThemeColors(this.context);
    // 存量搬迁不在这里做：它必须和首屏加载串行，见 onWindowStageCreate。
    // 启动清扫 epub-assets 与 pdf-pages 两个目录下的孤儿目录（批 5 / 批 7）：fire-and-forget，不阻塞首屏；
    // 读不到在架书（搬迁未完）时 clearOrphanLocalAssets 内部空集合会直接返回，不会误删在用的图。
    BookRepository.clearOrphanLocalAssets(this.context).catch(() => {});
  }

  onBackground(): void {
    this.context.eventHub.emit('pauseReadSession');
    // 每日自动备份：上游在 MainActivity.onDestroy 与阅读页 onPause 都调 Backup.autoBack，
    // 退到后台是这两处的公共点。是否真要备份由监听方按「距上次超过 1 天」自行判断。
    this.context.eventHub.emit('autoBackup');
    // 「离开应用前有效」档：grace=0 立即锁、grace>0 记时间戳，回前台按宽限期判定（批5，对齐上游 PrivateUnlockScope.UntilBackground）。
    PrivateAccessRepository.onBackground();
  }

  onForeground(): void {
    this.context.eventHub.emit('resumeReadSession');
    // 回前台检查宽限期是否已过，过了就回锁定态。
    PrivateAccessRepository.onForeground();
  }

  onDestroy(): void {
    // 上游 `MainActivity.kt:1208-1215 onDestroy()` 在退出应用时再调一次 `Backup.autoBack(this)`。
    // 这里同样发一次事件：退到后台时通常已经发过一次，重复触发会被「距上次超过 1 天」的判断挡掉，
    // 但如果用户是直接从后台划掉进程（onBackground 之后没再回前台），这是唯一能补上的一次机会。
    this.context.eventHub.emit('pauseReadSession');
    this.context.eventHub.emit('autoBackup');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    this.context.eventHub.on('exitApplication', () => {
      this.context.terminateSelf().catch(() => {});
    });
    try {
      const mainWindow = windowStage.getMainWindowSync();
      // 边缘到边缘：布局不避让状态栏与导航栏，组件可以画到它们底下。
      // 上游对应 `enableEdgeToEdge()`；不打开的话所有页面顶部都会被系统留白占掉一条。
      mainWindow.setWindowLayoutFullScreen(true).catch(() => {});
      mainWindow.setWindowSystemBarProperties({
        statusBarColor: SYSTEM_BAR_TRANSPARENT,
        statusBarContentColor: '#E5FFFFFF',
        navigationBarColor: SYSTEM_BAR_TRANSPARENT,
        navigationBarContentColor: '#E5FFFFFF'
      }).catch(() => {});
    } catch (_) {
    }
    // 启动窗口底色尽早设：它在应用主题生效前就画完了，只能靠这里写进去的值。
    // 与下面的存量搬迁并行，不进入那条串行链（搬迁可能要几秒）。
    ThemeSettingsRepository.load(this.context)
      .then((snapshot) => {
        applyStartWindowBackgroundColor(
          ThemeModeResolver.isDarkTheme(snapshot.themeMode, ThemeModeResolver.isSystemDark(this.context))
        );
      })
      .catch(() => {});
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
    // 主题切换后启动窗口底色也要跟着改：下次冷启动才不会闪回另一套底色。
    applyStartWindowBackgroundColor(isDark);
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
