/**
 * 导出书籍的后台长时任务。
 *
 * 对齐上游 `service/ExportBookService.kt`（1010 行）：上游是 Android 前台 Service，
 * `startService<ExportBookService> { action = start; putExtra("bookUrl" / "exportType" / "exportPath") }`
 * 之后导出在 Service 里跑，用户切走应用也继续，完成才 `stopSelf()`。
 * 鸿蒙没有「常驻 Service」，对应能力是 `backgroundTaskManager` 的 **DATA_TRANSFER 长时任务**
 * （`@ohos.resourceschedule.backgroundTaskManager.d.ts:1133 DATA_TRANSFER = 1`），
 * 申请期间应用退到后台仍可继续跑 I/O——这正是导出需要的。
 *
 * 系统约束（SDK 注释实测）：
 * - `:1124` DATA_TRANSFER 任务若「长时间不更新进度」会被系统取消
 *   （`SYSTEM_CANCEL_DATA_TRANSFER_NOT_UPDATE = 12`，`:1657`），
 *   所以每导完一本都调 `updateProgress()` 刷新一次通知与进度。
 * - `:1511` 传输速率过低也会被取消（`SYSTEM_CANCEL_DATA_TRANSFER_LOW_SPEED = 4`），
 *   这条由导出的实际耗时决定，代码里无法规避，申请失败时静默降级为前台导出。
 *
 * 与朗读长时任务（`readaloud/ReadAloudBackgroundTask.ets`）的分工：
 * 那个绑 AUDIO_PLAYBACK + AVSession，这个绑 DATA_TRANSFER + 进度通知，互不复用。
 */
import { backgroundTaskManager } from '@kit.BackgroundTasksKit';
import { wantAgent, Want } from '@kit.AbilityKit';
import { notificationManager } from '@kit.NotificationKit';
import { BusinessError } from '@kit.BasicServicesKit';

/** 导出通知的固定 id（上游 `NotificationId.ExportBook` / `NotificationId.ExportBookService`）。 */
const EXPORT_NOTIFICATION_ID: number = 0x1003;

export class ExportBackgroundTask {
  private static runningContext: Context | null = null;
  private static running: boolean = false;
  /** 申请失败（无权限 / 系统拒绝）后本次会话不再重试，避免每本书都弹一次失败日志。 */
  private static unavailable: boolean = false;

  /** 开始导出：申请 DATA_TRANSFER 长时任务。失败不抛，调用方按前台导出继续。 */
  static async begin(context: Context): Promise<void> {
    if (ExportBackgroundTask.running || ExportBackgroundTask.unavailable) {
      return;
    }
    ExportBackgroundTask.runningContext = context;
    try {
      const want: Want = { bundleName: 'io.legado.harmony', abilityName: 'EntryAbility' };
      const info: wantAgent.WantAgentInfo = {
        wants: [want],
        actionType: wantAgent.OperationType.START_ABILITY,
        requestCode: 0
      };
      const agent = await wantAgent.getWantAgent(info);
      await backgroundTaskManager.startBackgroundRunning(
        context, backgroundTaskManager.BackgroundMode.DATA_TRANSFER, agent);
      ExportBackgroundTask.running = true;
      console.info('[Export] 长时任务 DATA_TRANSFER 已开启');
    } catch (error) {
      // 长时任务申请不到就退回前台导出：行为与改造前一致，只是切后台可能被挂起。
      ExportBackgroundTask.unavailable = true;
      console.warn(`[Export] 长时任务申请失败，退回前台导出: ${ExportBackgroundTask.errorText(error as BusinessError)}`);
    }
  }

  /** 结束导出：撤通知 + 结束长时任务。 */
  static async end(): Promise<void> {
    await ExportBackgroundTask.cancelNotification();
    const context = ExportBackgroundTask.runningContext;
    if (ExportBackgroundTask.running && context !== null) {
      try {
        await backgroundTaskManager.stopBackgroundRunning(context);
      } catch (error) {
        console.warn(`[Export] 长时任务结束失败: ${ExportBackgroundTask.errorText(error as BusinessError)}`);
      }
    }
    ExportBackgroundTask.running = false;
    ExportBackgroundTask.runningContext = null;
  }

  /**
   * 刷新进度通知。
   *
   * 两个作用：① 用户切后台时能在通知栏看到「正在导出第 N / 共 M 本」；
   * ② 满足系统对 DATA_TRANSFER 任务「必须持续更新」的要求，否则会被判超时取消。
   * 通知发不出去（用户关了通知权限）不影响导出本身，只记 warn。
   */
  static async updateProgress(bookName: string, index: number, total: number): Promise<void> {
    const request: notificationManager.NotificationRequest = {
      id: EXPORT_NOTIFICATION_ID,
      content: {
        notificationContentType: notificationManager.ContentType.NOTIFICATION_CONTENT_BASIC_TEXT,
        normal: {
          title: '正在导出书籍',
          text: `《${bookName}》 第 ${index} / 共 ${total} 本`
        }
      }
    };
    try {
      await notificationManager.publish(request);
    } catch (error) {
      console.warn(`[Export] 进度通知发布失败: ${ExportBackgroundTask.errorText(error as BusinessError)}`);
    }
  }

  /** 导出全部完成：撤掉进度通知（上游 `onDestroy` 里 `notificationManager.cancel(NotificationId.ExportBook)`）。 */
  static async cancelNotification(): Promise<void> {
    try {
      await notificationManager.cancel(EXPORT_NOTIFICATION_ID);
    } catch (error) {
      // 通知本来就不存在时也会抛，属于正常路径，只记 debug。
      console.info(`[Export] 撤销进度通知: ${ExportBackgroundTask.errorText(error as BusinessError)}`);
    }
  }

  private static errorText(error: BusinessError): string {
    return error.message ?? String(error);
  }
}
