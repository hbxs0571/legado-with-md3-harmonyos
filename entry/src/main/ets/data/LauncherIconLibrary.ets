/**
 * 桌面启动图标的切换能力，对齐上游 `help/LauncherIconHelp.kt` + `LauncherIconPickerSheet.kt`。
 *
 * 上游在 Android 侧用的是「多 launcher-activity-alias + PackageManager.setComponentEnabledSetting」
 * （`LauncherIconHelp.kt:26-52`：8 个 ComponentName，选中一个就启用它、禁用其余，并禁用 MainActivity）。
 * 鸿蒙没有 activity-alias 这套机制，等价能力是华为 AppGallery Kit 的「动态图标」：
 * 图标包在 AGC 侧配置好后由系统下发，应用通过 `appInfoManager` 查询与切换。
 * 因此这里不是近似，而是本平台的原生实现路径。
 *
 * 能力声明见 SDK：`sdk/default/hms/ets/api/@hms.core.appgalleryservice.appInfoManager.d.ts`
 * （`queryDynamicIcons(): Promise<DynamicIconInfo[]>` 在 `:65`、`selectDynamicIcon(iconId)` 在 `:80`、
 * `disableDynamicIcon()` 在 `:91`，均 `@since 5.0.3(15)`、`@stagemodelonly`）。
 */
import { appInfoManager } from '@kit.AppGalleryKit';
import { BusinessError } from '@kit.BasicServicesKit';

/** 一个可用的自定义桌面图标，对应上游 `LauncherIconItem`（`LauncherIconPickerSheet.kt:130-135`）。 */
export interface LauncherIconEntry {
  /** 图标 id，切换时传给 `selectDynamicIcon`。 */
  id: string;
  /** 图标图片地址，系统下发，可能为空。 */
  url: string;
  /** 当前是否正在使用。 */
  enabled: boolean;
}

/** 查询结果：可用图标列表 + 失败原因（失败时列表为空、原因为真实错误描述）。 */
export interface LauncherIconQuery {
  icons: LauncherIconEntry[];
  /** 失败原因，成功时为空串。 */
  failure: string;
}

/**
 * 查询当前可切换的桌面图标。
 *
 * 上游等价的入口是 `LauncherIcons.list`（`LauncherIconPickerSheet.kt:139-194`，写死 8 个内置图标）；
 * 鸿蒙这里改为向系统查询，因为图标包由 AGC 下发，应用侧无法写死。
 */
export async function queryLauncherIcons(): Promise<LauncherIconQuery> {
  try {
    const infos = await appInfoManager.queryDynamicIcons();
    const icons: LauncherIconEntry[] = [];
    for (let index = 0; index < infos.length; index++) {
      const info = infos[index];
      icons.push({ id: info.iconId, url: info.iconUrl, enabled: info.enabled });
    }
    return { icons: icons, failure: '' };
  } catch (error) {
    return { icons: [], failure: launcherIconErrorText(error) };
  }
}

/** 切换到指定图标。返回空串表示成功，否则是真实失败原因。 */
export async function selectLauncherIcon(iconId: string): Promise<string> {
  try {
    await appInfoManager.selectDynamicIcon(iconId);
    return '';
  } catch (error) {
    return launcherIconErrorText(error);
  }
}

/** 恢复默认图标。返回空串表示成功，否则是真实失败原因。 */
export async function disableLauncherIcon(): Promise<string> {
  try {
    await appInfoManager.disableDynamicIcon();
    return '';
  } catch (error) {
    return launcherIconErrorText(error);
  }
}

/**
 * 把 `appInfoManager` 的错误码翻成用户能看懂的原因。
 *
 * 错误码取自 SDK 声明里的 `@throws`（`@hms.core.appgalleryservice.appInfoManager.d.ts:58-90`）：
 * 1006800001 服务连接失败、1006800009 系统内部错误、1006800010 无动态图标数据、
 * 1006800011 切换失败、1006800012 恢复默认失败、1006800013 正在使用自定义主题图标。
 * 未列出的码原样带上，便于用户反馈时定位。
 */
export function launcherIconErrorText(error: Object): string {
  const businessError = error as BusinessError;
  const code = businessError.code;
  if (code === 1006800001) {
    return '无法连接应用市场服务，请确认设备已登录华为账号后重试';
  }
  if (code === 1006800009) {
    return '系统内部错误，请稍后重试';
  }
  if (code === 1006800010) {
    return '当前应用还没有可切换的桌面图标';
  }
  if (code === 1006800011) {
    return '切换桌面图标失败，请稍后重试';
  }
  if (code === 1006800012) {
    return '恢复默认图标失败，请稍后重试';
  }
  if (code === 1006800013) {
    return '正在使用自定义主题图标，请先在系统主题里切回默认图标';
  }
  const message = businessError.message;
  if (typeof message === 'string' && message.length > 0) {
    return `切换桌面图标失败（${code}）：${message}`;
  }
  return `切换桌面图标失败（${code}）`;
}
