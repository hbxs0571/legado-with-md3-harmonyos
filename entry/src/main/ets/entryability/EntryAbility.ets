import { UIAbility } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';

export default class EntryAbility extends UIAbility {
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
    try {
      windowStage.loadContent('pages/Index');
    } catch (_) {
    }
  }
}
