/**
 * 书架「日志」页的进程内内存日志缓冲，对应上游 constant/AppLog.kt。
 * 只存内存、不落盘：进程重启即清空，不做超时。
 * put / getAll / clear 三个静态方法，500 条上限（超出丢最旧的一条）。
 */
export class AppLog {
  private static readonly limit: number = 500;
  private static entries: string[] = [];

  /** 追加一条日志；超过上限时丢掉最早的一条（环形缓冲语义）。 */
  static put(message: string): void {
    AppLog.entries.push(`[${AppLog.timeLabel()}] ${message}`);
    if (AppLog.entries.length > AppLog.limit) {
      AppLog.entries.splice(0, AppLog.entries.length - AppLog.limit);
    }
  }

  /** 返回全部日志，最新的一条在最前（与上游日志页一致）。 */
  static getAll(): string[] {
    return [...AppLog.entries].reverse();
  }

  static clear(): void {
    AppLog.entries = [];
  }

  private static timeLabel(): string {
    const now = new Date();
    const pad = (value: number): string => value.toString().padStart(2, '0');
    return `${pad(now.getHours())}:${pad(now.getMinutes())}:${pad(now.getSeconds())}`;
  }
}
