import { common, Want } from '@kit.AbilityKit';
import { fileUri } from '@kit.CoreFileKit';

/**
 * 外部应用跳转的唯一入口（批3，r359）。
 *
 * 任务书 :105 要求「批4 先做就先建好封装」，所以把原先散落在
 * `pages/ReaderPage.ets` 里的 startAbility 调用收进来：划词菜单「浏览器」与新加的
 * 「在浏览器打开当前书源页面」都走这里，避免同一个能力写两遍。
 *
 * 上游参照：`ReadBookController.kt:2270-2278` 用 `Intent.ACTION_VIEW` 打开绝对 URL、
 * `Intent.ACTION_WEB_SEARCH` 打开搜索词；`ReadBookViewModel.kt:2541` 的
 * `context.openUrl(...)` 也是 ACTION_VIEW。鸿蒙侧对应 `ohos.want.action.viewData`。
 */
export class WantLauncher {
  /** 只用 http/https 前缀的地址去拉外部浏览器，别的 scheme 一律不认（防止被当成命令 URI）。 */
  static isHttpUrl(value: string): boolean {
    return value.startsWith('http://') || value.startsWith('https://');
  }

  /**
   * 用系统浏览器打开 url。返回 true 表示 startAbility 已经交出去（真正起来由系统决定），
   * false 表示没有可用应用或参数不合法。失败不抛给调用方，调用方自己决定提示什么。
   */
  static async openFile(context: common.UIAbilityContext | undefined, path: string): Promise<boolean> {
    if (context === undefined) {
      return false;
    }
    const target = path.trim();
    if (target.length === 0) {
      return false;
    }
    try {
      const want: Want = {
        action: 'ohos.want.action.viewData',
        entities: ['entity.system.default'],
        uri: fileUri.getUriFromPath(target),
        type: '*/*'
      };
      await context.startAbility(want);
      return true;
    } catch (error) {
      return false;
    }
  }

  static async openUrl(context: common.UIAbilityContext | undefined, url: string): Promise<boolean> {
    if (context === undefined) {
      return false;
    }
    const target = url.trim();
    if (target.length === 0) {
      return false;
    }
    try {
      const want: Want = {
        action: 'ohos.want.action.viewData',
        entities: ['entity.system.browsable'],
        uri: target
      };
      await context.startAbility(want);
      return true;
    } catch (error) {
      return false;
    }
  }
}