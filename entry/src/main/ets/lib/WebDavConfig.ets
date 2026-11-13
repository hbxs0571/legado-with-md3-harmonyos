import { preferences } from '@kit.ArkData';

/**
 * WebDAV 备份设置。
 *
 * 与上游领域模型 `domain/model/settings/BackupSettings.kt` 里 WebDAV 相关的字段对齐。
 * 本仓没有「备份密码」入口，密码明文存 preferences（见 docs/BACKUP-RESTORE.md 已知问题）：
 * 没有生物识别与硬件密钥封装，硬做一层加密只会多一个密钥管理问题。
 *
 * 注意：这里与 `servers` 表是两条独立的读路径。servers.json（ServerRepository）
 * 是备份包里的数据，WebDAV 客户端只用本文件里用户手填的账号密码，不读那张表。
 */
export interface WebDavSettings {
  url: string;          // 空串表示用默认地址
  account: string;
  password: string;
  dir: string;          // 默认 'legado'
  deviceName: string;
  syncBookProgress: boolean;      // 默认 true（照上游 BackupSettings）
  syncBookProgressPlus: boolean;  // 默认 false
  autoCheckNewBackup: boolean;    // 默认 true
  onlyLatestBackup: boolean;      // 默认 true
  backupSyncMode: string;         // 'both' | 'local' | 'webdav'
  backupPath: string;            // 本地备份目录（空串=每次弹系统 picker）
  lastBackupTime: number;        // 最近一次成功备份的时间戳，供启动时比对远端
}

/** 上游 AppWebDav.kt 的默认坚果云地址。 */
export const WEBDAV_DEFAULT_URL: string = 'https://dav.jianguoyun.com/dav/';

/** 字段全部取上游 BackupSettings 的默认值，页面与宿主共用这一份，避免默认值分叉。 */
export function defaultWebDavSettings(): WebDavSettings {
  return {
    url: '',
    account: '',
    password: '',
    dir: 'legado',
    deviceName: '',
    syncBookProgress: true,
    syncBookProgressPlus: false,
    autoCheckNewBackup: true,
    onlyLatestBackup: true,
    backupSyncMode: 'both',
    backupPath: '',
    lastBackupTime: 0
  };
}

/** 返回一个独立副本，供页面 clone 后改单字段再回调宿主，避免直接改 @Prop。 */
export function cloneWebDavSettings(source: WebDavSettings): WebDavSettings {
  return {
    url: source.url,
    account: source.account,
    password: source.password,
    dir: source.dir,
    deviceName: source.deviceName,
    syncBookProgress: source.syncBookProgress,
    syncBookProgressPlus: source.syncBookProgressPlus,
    autoCheckNewBackup: source.autoCheckNewBackup,
    onlyLatestBackup: source.onlyLatestBackup,
    backupSyncMode: source.backupSyncMode,
    backupPath: source.backupPath,
    lastBackupTime: source.lastBackupTime
  };
}

/** 补尾斜杠，空串原样返回。 */
export function ensureTrailingSlash(value: string): string {
  if (value.length === 0) {
    return value;
  }
  return value.endsWith('/') ? value : value + '/';
}

/**
 * 根地址推导（照上游 AppWebDav.kt:112）：
 * base = url（空则默认，补尾斜杠），dir 非空则拼接后也补尾斜杠。
 * 例：url 空、dir 'legado' → https://dav.jianguoyun.com/dav/legado/
 */
export function buildWebDavRootUrl(settings: WebDavSettings): string {
  let base = settings.url.trim();
  if (base.length === 0) {
    base = WEBDAV_DEFAULT_URL;
  }
  // 上游 httpUrl 把 davs://→https://、dav://→http://，这里一并兼容。
  if (base.startsWith('davs://')) {
    base = 'https://' + base.substring('davs://'.length);
  } else if (base.startsWith('dav://')) {
    base = 'http://' + base.substring('dav://'.length);
  }
  base = ensureTrailingSlash(base);
  const dir = settings.dir.trim();
  if (dir.length === 0) {
    return base;
  }
  return ensureTrailingSlash(base + dir);
}

/** 三个派生目录（照上游 AppWebDav.kt:71-73）。本批只用到根地址，这三个供 test() 顺手建目录。 */
export function buildBookProgressUrl(root: string): string { return root + 'bookProgress/'; }
export function buildExportsUrl(root: string): string { return root + 'books/'; }
export function buildBackgroundUrl(root: string): string { return root + 'background/'; }

/** 账号与密码都非空才算配置好（上游 AppWebDav.kt:100 的 isConfigured）。 */
export function isWebDavConfigured(settings: WebDavSettings): boolean {
  return settings.account.trim().length > 0 && settings.password.length > 0;
}

/** 存储形态：单键 JSON 字符串。字段缺失或类型不对一律回落默认值，不让设置页打不开。 */
export class WebDavConfigStore {
  private static readonly preferenceName: string = 'legado_webdav_settings';
  private static readonly storeKey: string = 'webdav';
  private static saveQueue: Promise<void> = Promise.resolve();

  static async load(context: Context): Promise<WebDavSettings> {
    try {
      const store = await preferences.getPreferences(context, WebDavConfigStore.preferenceName);
      const value = await store.get(WebDavConfigStore.storeKey, '');
      if (typeof value !== 'string' || value.length === 0) {
        return defaultWebDavSettings();
      }
      return WebDavConfigStore.normalize(value);
    } catch (error) {
      // 一条坏记录不能让整个设置页打不开。
      console.error(`[WebDavConfigStore] 读取失败，回落默认值: ${error instanceof Error ? error.message : String(error)}`);
      return defaultWebDavSettings();
    }
  }

  static save(context: Context, settings: WebDavSettings): Promise<void> {
    const operation = WebDavConfigStore.saveQueue.then(async (): Promise<void> => {
      const store = await preferences.getPreferences(context, WebDavConfigStore.preferenceName);
      await store.put(WebDavConfigStore.storeKey, JSON.stringify(settings));
      await store.flush();
    });
    WebDavConfigStore.saveQueue = operation.then((): void => {}, (_error: Error): void => {});
    return operation;
  }

  /** 逐字段做 typeof 校验，任何一项缺失/类型不对就回落到该字段的默认值。 */
  private static normalize(raw: string): WebDavSettings {
    const fallback = defaultWebDavSettings();
    let parsed: Record<string, Object>;
    try {
      parsed = JSON.parse(raw) as Record<string, Object>;
    } catch (_) {
      return fallback;
    }
    if (parsed === undefined || parsed === null) {
      return fallback;
    }
    const record = parsed;
    const str = (key: string, def: string): string => {
      const v = record[key];
      return typeof v === 'string' ? v as string : def;
    };
    const bool = (key: string, def: boolean): boolean => {
      const v = record[key];
      return typeof v === 'boolean' ? v as boolean : def;
    };
    const num = (key: string, def: number): number => {
      const v = record[key];
      return typeof v === 'number' && Number.isFinite(v) ? v as number : def;
    };
    return {
      url: str('url', fallback.url),
      account: str('account', fallback.account),
      password: str('password', fallback.password),
      dir: str('dir', fallback.dir),
      deviceName: str('deviceName', fallback.deviceName),
      syncBookProgress: bool('syncBookProgress', fallback.syncBookProgress),
      syncBookProgressPlus: bool('syncBookProgressPlus', fallback.syncBookProgressPlus),
      autoCheckNewBackup: bool('autoCheckNewBackup', fallback.autoCheckNewBackup),
      onlyLatestBackup: bool('onlyLatestBackup', fallback.onlyLatestBackup),
      backupSyncMode: str('backupSyncMode', fallback.backupSyncMode),
      backupPath: str('backupPath', fallback.backupPath),
      lastBackupTime: num('lastBackupTime', fallback.lastBackupTime)
    };
  }
}
