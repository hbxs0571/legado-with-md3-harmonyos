import { errorManager } from '@kit.AbilityKit';
import { process } from '@kit.ArkTS';
import { AppLog } from './AppLog';
import { CrashLogRepository } from '../data/CrashLogRepository';
import { OtherSettingsRepository } from '../data/OtherSettingsRepository';

/**
 * 全局未捕获异常的落盘与退出，对应上游 `help/CrashHandler.kt`。
 *
 * 上游继承 `Thread.UncaughtExceptionHandler` 并 `Thread.setDefaultUncaughtExceptionHandler(this)`
 * （`CrashHandler.kt:36-38`）。ArkTS 侧对应的入口是 `errorManager.on('globalErrorOccurred')`
 * （`@ohos.app.ability.errorManager.d.ts:293`，`@since 18`），它同样能拿到整个进程任意线程的
 * 未捕获异常。**关键差别**：SDK 文档 `:279-282` 写明观察者捕获异常后「the application will
 * not exit automatically. You are advised to add a synchronous exit operation after the callback
 * function completes.」—— 所以回调里必须自己退出，否则进程会停在异常现场。
 *
 * 因此这里全部走同步路径：`CrashLogRepository.saveCrashInfoSync` 写日志、按开关抓堆转储、
 * 最后 `process.ProcessManager.exit(10)`（对齐上游 `Process.killProcess` + `exitProcess(10)`）。
 * 中间任何一步都不 await，否则退出可能赶在写盘之前。
 */
export class CrashHandler {
  /** 退出码，对齐上游 `CrashHandler.kt:63 exitProcess(10)`。 */
  private static readonly EXIT_CODE: number = 10;
  /** 防止重入：堆转储或写盘再次抛错时不再递归进回调。 */
  private static handling: boolean = false;
  /** 已注册的观察者，供 `off` 使用。 */
  private static observer: ((reason: Error) => void) | undefined = undefined;

  /**
   * 装全局异常观察者。在 `EntryAbility.onCreate` 里调一次即可。
   *
   * 上游的 `shouldAbsorb` 分支（`CrashHandler.kt:41-46`）吸收 `CannotDeliverBroadcastException`
   * 与带 `OBSERVE_GRANT_REVOKE_PERMISSIONS` 的 `SecurityException` —— 那两条都是 Android
   * 框架自身的已知噪声，HarmonyOS 侧没有对应异常类型，所以这里不做吸收。
   */
  static install(context: Context): void {
    if (CrashHandler.observer !== undefined) {
      return;
    }
    const observer = (reason: Error): void => {
      CrashHandler.handle(context, reason);
    };
    try {
      errorManager.on('globalErrorOccurred', observer);
      CrashHandler.observer = observer;
    } catch (error) {
      // 低版本设备没有这个事件：退化成不落盘，但绝不能让启动流程失败。
      AppLog.put('注册全局异常观察者失败', error as Error);
    }
  }

  /** 摘掉观察者（测试与热重载用）。 */
  static uninstall(): void {
    const observer = CrashHandler.observer;
    if (observer === undefined) {
      return;
    }
    try {
      errorManager.off('globalErrorOccurred', observer);
    } catch (error) {
      // 摘不到也不影响后续，进程本来就要退出。
    }
    CrashHandler.observer = undefined;
  }

  /**
   * 异常处理主体，对齐上游 `CrashHandler.handleException`。
   *
   * 上游在 `handleException` 里返回 false 时回落到系统默认处理器（`mDefaultHandler`）；
   * HarmonyOS 侧没有「交回默认处理器」的等价做法，写盘失败也要退出，否则进程卡死。
   */
  private static handle(context: Context, reason: Error): void {
    if (CrashHandler.handling) {
      return;
    }
    CrashHandler.handling = true;
    try {
      const crashFileName = CrashHandler.saveCrashInfo(context, reason);
      // 上游 `CrashHandler.kt:105-107`：OOM 且开关打开时额外抓一份堆转储。
      if (CrashHandler.isOutOfMemory(reason) && OtherSettingsRepository.get().recordHeapDump) {
        CrashHandler.dumpHeapSafely(context);
      }
      AppLog.put(`发生未捕获的异常，已写入 ${crashFileName}`, reason);
    } catch (error) {
      // 落盘本身出错也要继续退出，不能停在异常现场。
    } finally {
      CrashHandler.exitProcess();
    }
  }

  /** 写崩溃日志，失败返回空串。上游 `saveCrashInfo2File` 的调用点。 */
  private static saveCrashInfo(context: Context, reason: Error): string {
    try {
      return CrashLogRepository.saveCrashInfoSync(context, reason);
    } catch (error) {
      return '';
    }
  }

  /**
   * 抓一份堆转储。失败只记日志 —— 上游 `doHeapDump` 同样是同步调用，异常交给外层。
   *
   * 这里用 Promise 的 then 而不是 await：崩溃回调里没有可让位的微任务循环，
   * 抓完就直接退出；`createHeapDump` 内部第一段是同步的清理与快照导出。
   */
  private static dumpHeapSafely(context: Context): void {
    try {
      CrashLogRepository.createHeapDumpSync(context, false);
    } catch (error) {
      // 堆转储失败不影响崩溃日志已经落盘这个事实。
    }
  }

  /** 判断异常链里是否出现 `OutOfMemoryError`，对齐上游 `ex is OutOfMemoryError || ex.cause is OutOfMemoryError`。 */
  private static isOutOfMemory(reason: Error): boolean {
    const name = reason.name;
    if (name === 'OutOfMemoryError') {
      return true;
    }
    const message = reason.message;
    return message !== undefined && message.indexOf('OutOfMemory') >= 0;
  }

  /** 同步退出进程，对齐上游 `Process.killProcess(Process.myPid())` + `exitProcess(10)`。 */
  private static exitProcess(): void {
    try {
      // `exit` 是 `ProcessManager` 的实例方法（`@ohos.process.d.ts:39`/`:113`），不是静态方法。
      new process.ProcessManager().exit(CrashHandler.EXIT_CODE);
    } catch (error) {
      // exit 本身不可用时没有别的兜底手段，只能让它继续往下走。
    }
  }
}
