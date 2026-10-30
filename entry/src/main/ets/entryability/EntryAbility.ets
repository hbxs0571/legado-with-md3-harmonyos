import { UIAbility } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { RdbMigration } from '../data/RdbMigration';
import { RdbCleanup } from '../data/RdbCleanup';

export default class EntryAbility extends UIAbility {
  onCreate(): void {
    // 存量搬迁不在这里做：它必须和首屏加载串行，见 onWindowStageCreate。
  }

  onBackground(): void {
    this.context.eventHub.emit('pauseReadSession');
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
        statusBarColor: '#111217',
        statusBarContentColor: '#E5FFFFFF',
        navigationBarColor: '#111217',
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
      });
  }
}
