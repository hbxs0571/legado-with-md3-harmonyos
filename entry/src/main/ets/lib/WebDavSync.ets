import { WebDav, WebDavError, WebDavEntry } from './WebDav';
import {
  WebDavConfigStore,
  buildWebDavRootUrl,
  buildBookProgressUrl,
  buildExportsUrl,
  buildBackgroundUrl,
  isWebDavConfigured
} from './WebDavConfig';

/**
 * WebDAV 备份编排层：把 WebDavConfigStore（配置）与 WebDav（协议）拼起来给界面用。
 * 上游 AppWebDav.kt 的 StateFlow / configMutex 不照搬 —— 每次操作新建 session，
 * 本来就不需要「配置变更检测」。
 *
 * 错误一律转成 WebDavError 往上抛（message 面向用户），界面层不解析错误码。
 * 唯一例外是 test()，它返回 {ok, message} 供设置页直接弹提示。
 */
export interface WebDavTestResult {
  ok: boolean;
  message: string;
}

export interface WebDavBackupInfo {
  name: string;
  lastModified: number;
}

/** 把 catch 到的任意错误包装成 WebDavError（不直接 throw error，规避 arkts-limited-throw）。 */
function wrapError(error: ESObject): WebDavError {
  if (error instanceof WebDavError) {
    return new WebDavError(error.message, error.statusCode);
  }
  return new WebDavError(
    `WebDAV 操作失败：${error instanceof Error ? error.message : String(error)}`, 0);
}

export class WebDavSync {
  /** 测试连接：账号密码非空 → check()。成功顺手建四个目录（照上游 upConfig()）。 */
  static async test(context: Context): Promise<WebDavTestResult> {
    const settings = await WebDavConfigStore.load(context);
    if (!isWebDavConfigured(settings)) {
      return { ok: false, message: '账号或密码为空' };
    }
    const root = buildWebDavRootUrl(settings);
    const dav = new WebDav(root, settings.account, settings.password);
    try {
      const reachable = await dav.check();
      if (!reachable) {
        // check() 在 401 与网络异常时都返回 false，用 lastStatus 区分两者。
        if (dav.getLastStatus() === 401) {
          return { ok: false, message: '账号或密码不正确（HTTP 401）' };
        }
        return { ok: false, message: '无法连接 WebDAV 服务器，请检查网络与服务器地址' };
      }
      // 首次配置的用户远端什么都没有，先建好目录，后续上传不会因父目录不存在而 409。
      const dirs: string[] = [
        root,
        buildBookProgressUrl(root),
        buildExportsUrl(root),
        buildBackgroundUrl(root)
      ];
      for (let i = 0; i < dirs.length; i++) {
        const dir = dirs[i];
        if (dir === undefined) { continue; }
        try {
          await dav.makeAsDir(dir);
        } catch (error) {
          // 建目录失败不影响 test 的成功判定，只记日志。
          console.error(`[WebDavSync] 建目录 ${dir} 失败: ${error instanceof Error ? error.message : String(error)}`);
        }
      }
      return { ok: true, message: 'WebDAV 服务可用' };
    } finally {
      dav.close();
    }
  }

  /** 列出远端备份文件名，只收 backup 开头、按名称倒序（日期在名字里，字典序倒排即时间倒排）。 */
  static async listBackups(context: Context): Promise<string[]> {
    const settings = await WebDavConfigStore.load(context);
    if (!isWebDavConfigured(settings)) {
      throw new WebDavError('账号或密码为空，请先在设置里填写', 0);
    }
    const root = buildWebDavRootUrl(settings);
    const dav = new WebDav(root, settings.account, settings.password);
    try {
      const entries: WebDavEntry[] = await dav.listFiles(root);
      const names: string[] = [];
      entries.forEach((entry: WebDavEntry) => {
        if (!entry.isDirectory && entry.displayName.startsWith('backup')) {
          names.push(entry.displayName);
        }
      });
      names.sort();
      names.reverse();
      return names;
    } catch (error) {
      throw wrapError(error);
    } finally {
      dav.close();
    }
  }

  /** 上传本地 zip 到 root + fileName。上传前先 makeAsDir(root)，防用户删过目录。 */
  static async uploadBackup(context: Context, localZipPath: string, fileName: string): Promise<void> {
    const settings = await WebDavConfigStore.load(context);
    if (!isWebDavConfigured(settings)) {
      throw new WebDavError('账号或密码为空，请先在设置里填写', 0);
    }
    const dav = new WebDav(buildWebDavRootUrl(settings), settings.account, settings.password);
    try {
      await dav.makeAsDir(dav.getRootUrl());
      await dav.upload(localZipPath, dav.getRootUrl() + fileName);
    } catch (error) {
      throw wrapError(error);
    } finally {
      dav.close();
    }
  }

  /** 下载远端同名文件到 localZipPath。 */
  static async downloadBackup(context: Context, fileName: string, localZipPath: string): Promise<void> {
    const settings = await WebDavConfigStore.load(context);
    if (!isWebDavConfigured(settings)) {
      throw new WebDavError('账号或密码为空，请先在设置里填写', 0);
    }
    const dav = new WebDav(buildWebDavRootUrl(settings), settings.account, settings.password);
    try {
      await dav.downloadTo(dav.getRootUrl() + fileName, localZipPath);
    } catch (error) {
      throw wrapError(error);
    } finally {
      dav.close();
    }
  }

  /** 取最新一份备份（按 lastModified 最大）。没有则返回 undefined。 */
  static async latestBackup(context: Context): Promise<WebDavBackupInfo | undefined> {
    const settings = await WebDavConfigStore.load(context);
    if (!isWebDavConfigured(settings)) {
      throw new WebDavError('账号或密码为空，请先在设置里填写', 0);
    }
    const root = buildWebDavRootUrl(settings);
    const dav = new WebDav(root, settings.account, settings.password);
    try {
      const entries: WebDavEntry[] = await dav.listFiles(root);
      let bestName = '';
      let bestTime = -1;
      entries.forEach((entry: WebDavEntry) => {
        if (!entry.isDirectory && entry.displayName.startsWith('backup') && entry.lastModified > bestTime) {
          bestTime = entry.lastModified;
          bestName = entry.displayName;
        }
      });
      if (bestName.length === 0) {
        return undefined;
      }
      return { name: bestName, lastModified: bestTime };
    } catch (error) {
      throw wrapError(error);
    } finally {
      dav.close();
    }
  }
}
