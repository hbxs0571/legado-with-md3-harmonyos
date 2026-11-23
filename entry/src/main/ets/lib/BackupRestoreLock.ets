/**
 * 备份与恢复的互斥锁，对应上游 `help/storage/BackupRestoreLock.kt`。
 *
 * 上游是 kotlinx.coroutines 的 `Mutex`（`BackupRestoreLock.kt:6-14`：
 * `private val mutex = Mutex()` + `suspend fun <T> withLock(action: suspend () -> T)`），
 * 作用是让「自动备份 / 手动备份 / 本地恢复 / 远端恢复」这四类操作在同一进程内串行，
 * 避免两个操作同时删改同一个解压目录（`Backup.kt:121`/`:138`、`Restore.kt:92`/`:119`、
 * `AppWebDav.kt:220` 五处调用点）。
 *
 * 名字里的 cross-process 是上游沿用的历史命名，实现上并不跨进程。
 * 本地 ArkTS 是单线程事件循环，但 `await` 之间会交错：备份在 `await buildBackupArchive`
 * 时让出，恢复可能已经把同一个 staging 目录删掉。这里用一条 Promise 队列实现同样的串行语义：
 * 每个操作把自己挂到队尾，前一个结束（无论成功失败）才轮到下一个。
 */
export class BackupRestoreLock {
  /** 队尾：始终指向「最后一个已排队的操作完成时」的 Promise，初始为已完成的 Promise。 */
  private static tail: Promise<void> = Promise.resolve();
  /** 当前是否有操作在跑，供界面判断忙碌态。 */
  private static running: boolean = false;

  /** 是否有备份/恢复操作正在执行。 */
  static isRunning(): boolean {
    return BackupRestoreLock.running;
  }

  /**
   * 排队执行：前一个操作结束后才执行 action，action 的返回值原样返回。
   * action 抛出的异常会传给调用方，同时不影响队列继续往下走。
   */
  static async withLock<T>(action: () => Promise<T>): Promise<T> {
    // 先把「我这一环」接到队尾，previous 是前一个操作的完成信号。
    const previous: Promise<void> = BackupRestoreLock.tail;
    let release: () => void = () => {};
    BackupRestoreLock.tail = new Promise<void>((resolve: () => void): void => {
      release = resolve;
    });
    await previous;
    BackupRestoreLock.running = true;
    try {
      return await action();
    } finally {
      BackupRestoreLock.running = false;
      // 无论成功还是抛异常都要放行下一个，否则队列会永久卡住。
      release();
    }
  }
}
