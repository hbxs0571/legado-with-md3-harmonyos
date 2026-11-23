/**
 * 崩溃日志与堆转储的落盘，对应上游 `help/CrashHandler.kt` 的 `saveCrashInfo2File` /
 * `readCrashLog` / `doHeapDump`，以及 `ui/about/AboutViewModel.kt` 的
 * `loadCrashLogFiles` / `clearCrashLogs` / `saveLog` / `createHeapDump`。
 *
 * 落盘位置与上游一一对应：
 * - 崩溃日志写两份：`backupPath/crash/<fileName>`（用户可见、随备份目录带走）与
 *   `cacheDir/crash/<fileName>`（应用私有，读列表与导出都以它为准）。
 * - 上游用 `externalCacheDir`，本地用 `context.cacheDir`：HarmonyOS 的
 *   `externalCacheDir` 等价物是 `context.cacheDir`（应用沙箱内的缓存目录），
 *   两者语义都是「可被系统回收的临时目录」。
 * - 堆转储上游用 `Debug.dumpHprofData` 产出 `.hprof`；本地用
 *   `hidebug.dumpJsHeapData` 产出 `.heapsnapshot`（SDK 没有 hprof 导出，
 *   `dumpHeapData` 在 API 9 起已废弃，`@useinstead hidebug.dumpJsHeapData`）。
 */
import { fileIo } from '@kit.CoreFileKit';
import { hidebug } from '@kit.PerformanceAnalysisKit';
import { bundleManager } from '@kit.AbilityKit';
import { deviceInfo } from '@kit.BasicServicesKit';
import { preferences } from '@kit.ArkData';
import { util } from '@kit.ArkTS';
import zlib from '@ohos.zlib';
import { AppLog } from '../lib/AppLog';

/** 崩溃日志文件名的固定前缀，与上游 `"crash-$time-$timestamp.log"` 一致。 */
const CRASH_FILE_PREFIX: string = 'crash-';
/** 崩溃日志保留天数，上游 `CrashHandler.kt:141` 的 `TimeUnit.DAYS.toMillis(7)`。 */
const CRASH_RETENTION_MS: number = 7 * 24 * 60 * 60 * 1000;
/** 崩溃日志所在子目录名，上游 `createFileIfNotExist(fileName, "crash")`。 */
const CRASH_FOLDER: string = 'crash';
/** 堆转储所在子目录名，上游 `externalCache.getFile("heapDump")`。 */
const HEAP_DUMP_FOLDER: string = 'heapDump';
/** 日志导出包名，上游 `copyLogs` 里的 `"logs.zip"`。 */
const LOG_ARCHIVE_NAME: string = 'logs.zip';
/** 备份设置所在的 preferences 实例名，与 `WebDavConfigStore.preferenceName` 同一份。 */
const CRASH_CONFIG_STORE_NAME: string = 'legado_webdav_settings';
/** 备份设置在这个实例里的键，与 `WebDavConfigStore.storeKey` 同一份。 */
const CRASH_CONFIG_STORE_KEY: string = 'webdav';
/** 备份设置 JSON 里备份目录的字段名，与 `WebDavSettings.backupPath` 同名。 */
const CRASH_CONFIG_BACKUP_PATH_KEY: string = 'backupPath';

/** 一条崩溃日志的元信息，供列表展示与读取。 */
export interface CrashLogFile {
  /** 文件名，如 `crash-2026-11-24-01-30-00-1732400000000.log`。 */
  name: string;
  /** 文件字节数。 */
  size: number;
  /** 最后修改时刻（毫秒）。 */
  lastModified: number;
  /** 是否为备份目录里的那份（备份目录为空时不会有这类条目）。 */
  inBackupFolder: boolean;
}

/**
 * 崩溃日志 / 日志导出 / 堆转储的读写入口。
 *
 * 所有方法都接受 `Context`，不持有全局状态：调用点分布在崩溃回调
 * （`CrashCapture`）、关于页（`AboutAppPage`）两处。
 */
export class CrashLogRepository {
  /**
   * 写出一次崩溃信息，返回文件名。
   *
   * 对齐上游 `CrashHandler.saveCrashInfo2File(ex)`：
   * 1. 头部逐行写 `key=value`（机型、系统版本、包名、版本号、堆上限）；
   * 2. 正文写异常栈，并把 cause 链逐层展开；
   * 3. 写 `backupPath/crash/<fileName>`（备份目录未配置时跳过，不抛错）；
   * 4. 写 `cacheDir/crash/<fileName>`，顺手删掉 7 天前的旧文件。
   */
  static async saveCrashInfo(context: Context, error: Error): Promise<string> {
    return CrashLogRepository.saveCrashInfoSync(context, error);
  }

  /**
   * `saveCrashInfo` 的同步版本。
   *
   * 崩溃回调里不能用 await：`errorManager.on('globalErrorOccurred')` 的观察者
   * 拿到的进程不会再自动退出，回调必须在写完日志后立刻同步退出，中间不能有
   * 微任务让位（SDK 文档 `:279-282` 明确要求「add a synchronous exit operation
   * after the callback function completes」）。落盘全部走 fileIo 的同步 API。
   */
  static saveCrashInfoSync(context: Context, error: Error): string {
    const now = Date.now();
    const fileName = `${CRASH_FILE_PREFIX}${CrashLogRepository.formatFileTime(now)}-${now}.log`;
    const content = CrashLogRepository.buildCrashLog(context, error);
    // 备份目录那份失败不影响主流程：上游同样把这段包在 try/catch 里吞掉。
    const backupPath = CrashLogRepository.backupFolderSync(context);
    if (backupPath.length > 0) {
      try {
        const folder = CrashLogRepository.childPath(backupPath, CRASH_FOLDER);
        CrashLogRepository.ensureDirectory(folder);
        CrashLogRepository.writeText(CrashLogRepository.childPath(folder, fileName), content);
      } catch (writeError) {
        AppLog.put(`写崩溃日志到备份目录失败\n${CrashLogRepository.describe(writeError)}`);
      }
    }
    try {
      const folder = CrashLogRepository.childPath(context.cacheDir, CRASH_FOLDER);
      CrashLogRepository.ensureDirectory(folder);
      CrashLogRepository.purgeExpired(folder, now);
      CrashLogRepository.writeText(CrashLogRepository.childPath(folder, fileName), content);
    } catch (writeError) {
      AppLog.put(`写崩溃日志到缓存目录失败\n${CrashLogRepository.describe(writeError)}`);
    }
    return fileName;
  }

  /**
   * 列出全部崩溃日志，按文件名倒序（新在前），同名去重。
   * 对齐上游 `AboutViewModel.loadCrashLogFiles()`：缓存目录 + 备份目录合并。
   */
  static async listCrashLogs(context: Context): Promise<CrashLogFile[]> {
    const collected: CrashLogFile[] = [];
    const cacheFolder = CrashLogRepository.childPath(context.cacheDir, CRASH_FOLDER);
    collected.push(...CrashLogRepository.listFolder(cacheFolder, false));
    const backupPath = await CrashLogRepository.backupFolder(context);
    if (backupPath.length > 0) {
      collected.push(...CrashLogRepository.listFolder(CrashLogRepository.childPath(backupPath, CRASH_FOLDER), true));
    }
    // 上游 `sortedByDescending { it.name }.distinctBy { it.name }`：先按名字倒序，再按名字去重（保留第一个）。
    collected.sort((left: CrashLogFile, right: CrashLogFile): number => {
      if (left.name === right.name) {
        return 0;
      }
      return left.name < right.name ? 1 : -1;
    });
    const seen: Set<string> = new Set<string>();
    const result: CrashLogFile[] = [];
    for (const item of collected) {
      if (seen.has(item.name)) {
        continue;
      }
      seen.add(item.name);
      result.push(item);
    }
    return result;
  }

  /**
   * 读一份崩溃日志正文；`name` 为空时取最新一份。
   * 对齐上游 `CrashHandler.readCrashLog(fileName)`：只读缓存目录那一份。
   */
  static async readCrashLog(context: Context, name: string): Promise<string> {
    const folder = CrashLogRepository.childPath(context.cacheDir, CRASH_FOLDER);
    let target = '';
    if (name.length > 0) {
      const candidate = CrashLogRepository.childPath(folder, name);
      if (fileIo.accessSync(candidate)) {
        target = candidate;
      }
    }
    if (target.length === 0) {
      const files = CrashLogRepository.listFolder(folder, false);
      if (files.length > 0) {
        // listFolder 已按名字倒序，第一条就是最新一份。
        target = CrashLogRepository.childPath(folder, files[0].name);
      }
    }
    if (target.length === 0) {
      return '';
    }
    try {
      return CrashLogRepository.readText(target);
    } catch (error) {
      AppLog.put(`读崩溃日志失败\n${CrashLogRepository.describe(error)}`);
      return '';
    }
  }

  /**
   * 清空全部崩溃日志：缓存目录与备份目录的 `crash` 子目录整体删除。
   * 对齐上游 `AboutViewModel.clearCrashLogs()`。
   */
  static async clearCrashLogs(context: Context): Promise<void> {
    CrashLogRepository.removeTree(CrashLogRepository.childPath(context.cacheDir, CRASH_FOLDER));
    const backupPath = await CrashLogRepository.backupFolder(context);
    if (backupPath.length > 0) {
      CrashLogRepository.removeTree(CrashLogRepository.childPath(backupPath, CRASH_FOLDER));
    }
  }

  /**
   * 把日志、崩溃日志与堆转储打包成 `logs.zip` 放进备份目录。
   * 对齐上游 `AboutViewModel.copyLogs(doc)` + `saveLog()`。
   *
   * 上游另会把 `logcat -d` 的输出写进 `logcat.txt` 一起打包；HarmonyOS 没有
   * 应用内执行 `logcat` 的通道（`hdc` 才有），所以这一份用 `AppLog` 的内存
   * 缓冲代替 —— 它同样是运行期日志的全文快照，语义对齐、来源不同。
   */
  static async exportLogs(context: Context): Promise<boolean> {
    const backupPath = await CrashLogRepository.backupFolder(context);
    if (backupPath.length === 0) {
      return false;
    }
    CrashLogRepository.ensureDirectory(backupPath);
    const cacheFolder = context.cacheDir;
    const logsFolder = CrashLogRepository.childPath(cacheFolder, 'logs');
    const crashFolder = CrashLogRepository.childPath(cacheFolder, CRASH_FOLDER);
    const memoryLogFile = CrashLogRepository.childPath(cacheFolder, 'logcat.txt');
    CrashLogRepository.writeText(memoryLogFile, CrashLogRepository.dumpMemoryLog());
    const zipPath = CrashLogRepository.childPath(cacheFolder, LOG_ARCHIVE_NAME);
    // 上游 zip 的是三个目录/文件；这里同样把 logs、crash 两个目录与 logcat.txt 收进同一个包。
    const sources: string[] = [];
    if (fileIo.accessSync(logsFolder)) {
      sources.push(logsFolder);
    }
    if (fileIo.accessSync(crashFolder)) {
      sources.push(crashFolder);
    }
    if (fileIo.accessSync(memoryLogFile)) {
      sources.push(memoryLogFile);
    }
    if (sources.length === 0) {
      return false;
    }
    try {
      CrashLogRepository.removeFile(zipPath);
      await zlib.compressFiles(sources, zipPath, {});
      const target = CrashLogRepository.childPath(backupPath, LOG_ARCHIVE_NAME);
      CrashLogRepository.removeFile(target);
      CrashLogRepository.copyFile(zipPath, target);
      CrashLogRepository.removeFile(zipPath);
      return true;
    } catch (error) {
      AppLog.put(`打包日志失败\n${CrashLogRepository.describe(error)}`);
      return false;
    }
  }

  /**
   * 抓一份堆转储到缓存目录，返回落盘路径；失败返回空串。
   * 对齐上游 `CrashHandler.doHeapDump(manually)`：先清空目录再抓。
   */
  static async createHeapDump(context: Context, manually: boolean): Promise<string> {
    return CrashLogRepository.createHeapDumpSync(context, manually);
  }

  /**
   * `createHeapDump` 的同步版本。
   *
   * 崩溃回调里不能用 await（见 `CrashHandler` 顶部注释），而这段逻辑本身全是
   * fileIo 同步调用 + `hidebug.dumpJsHeapData` 同步调用，本来就没有异步点，
   * 拆出同步入口只是为了在崩溃路径上不经过 Promise。
   */
  static createHeapDumpSync(context: Context, manually: boolean): string {
    const folder = CrashLogRepository.childPath(context.cacheDir, HEAP_DUMP_FOLDER);
    try {
      CrashLogRepository.removeTree(folder);
      CrashLogRepository.ensureDirectory(folder);
    } catch (error) {
      AppLog.put(`准备堆转储目录失败\n${CrashLogRepository.describe(error)}`);
      return '';
    }
    const fileName = manually
      ? `heap-dump-manually-${Date.now()}`
      : `heap-dump-${Date.now()}`;
    try {
      // `dumpJsHeapData` 把 `<fileName>.heapsnapshot` 写在应用 files 目录。
      hidebug.dumpJsHeapData(fileName);
    } catch (error) {
      AppLog.put(`抓堆转储失败\n${CrashLogRepository.describe(error)}`);
      return '';
    }
    const produced = CrashLogRepository.childPath(context.filesDir, `${fileName}.heapsnapshot`);
    if (!fileIo.accessSync(produced)) {
      return '';
    }
    const target = CrashLogRepository.childPath(folder, `${fileName}.heapsnapshot`);
    try {
      CrashLogRepository.copyFile(produced, target);
      CrashLogRepository.removeFile(produced);
    } catch (error) {
      AppLog.put(`搬运堆转储失败\n${CrashLogRepository.describe(error)}`);
      return '';
    }
    return target;
  }

  /**
   * 把缓存目录里的堆转储拷进备份目录的 `heapDump/` 子目录，返回是否成功。
   * 对齐上游 `AboutViewModel.copyHeapDump(doc)`：先删旧目录再重建。
   */
  static async copyHeapDumpToBackup(context: Context): Promise<boolean> {
    const backupPath = await CrashLogRepository.backupFolder(context);
    if (backupPath.length === 0) {
      return false;
    }
    const sourceFolder = CrashLogRepository.childPath(context.cacheDir, HEAP_DUMP_FOLDER);
    const files = CrashLogRepository.listFolder(sourceFolder, false);
    if (files.length === 0) {
      return false;
    }
    const targetFolder = CrashLogRepository.childPath(backupPath, HEAP_DUMP_FOLDER);
    try {
      CrashLogRepository.removeTree(targetFolder);
      CrashLogRepository.ensureDirectory(targetFolder);
      CrashLogRepository.copyFile(CrashLogRepository.childPath(sourceFolder, files[0].name),
        CrashLogRepository.childPath(targetFolder, files[0].name));
      return true;
    } catch (error) {
      AppLog.put(`复制堆转储失败\n${CrashLogRepository.describe(error)}`);
      return false;
    }
  }

  /** 当前备份目录；未配置返回空串（对齐上游 `backupPath ?: return` 的判据）。 */
  static async backupFolder(context: Context): Promise<string> {
    return CrashLogRepository.backupFolderSync(context);
  }

  /**
   * `backupFolder` 的同步版本：崩溃回调里不能用 await。
   *
   * 直接读 `WebDavConfigStore` 的同一个 preferences 实例（`legado_webdav_settings`
   * 的 `webdav` 键），用 `getPreferencesSync` + `getSync`，键名与存储形态都与
   * `WebDavConfigStore.load` 保持一致，所以两条路径读到的是同一份值。
   */
  static backupFolderSync(context: Context): string {
    try {
      const options: preferences.Options = { name: CRASH_CONFIG_STORE_NAME };
      const store = preferences.getPreferencesSync(context, options);
      const value = store.getSync(CRASH_CONFIG_STORE_KEY, '');
      if (typeof value !== 'string' || value.length === 0) {
        return '';
      }
      const parsed = JSON.parse(value) as Record<string, Object>;
      const raw = parsed[CRASH_CONFIG_BACKUP_PATH_KEY];
      return typeof raw === 'string' ? (raw as string).trim() : '';
    } catch (error) {
      return '';
    }
  }

  /** 崩溃日志正文：头部 `key=value` + 异常栈 + cause 链。对齐上游 `saveCrashInfo2File`。 */
  private static buildCrashLog(context: Context, error: Error): string {
    const lines: string[] = [];
    lines.push(`packageName=${context.applicationInfo.name}`);
    lines.push(`versionName=${CrashLogRepository.versionName(context)}`);
    lines.push(`MODEL=${CrashLogRepository.deviceModel()}`);
    lines.push(`SDK_INT=${CrashLogRepository.sdkInt()}`);
    lines.push(`timestamp=${Date.now()}`);
    let body = '';
    if (error.stack !== undefined && error.stack.length > 0) {
      body = error.stack;
    } else {
      body = `${error.name}: ${error.message}`;
    }
    // 上游把 cause 链逐层 printStackTrace；ArkTS 的 Error 没有标准 cause，
    // 只有 `Error` 自带的 stack 已包含完整调用栈，这里补一行消息避免空正文。
    if (body.length === 0) {
      body = error.message;
    }
    return `${lines.join('\n')}\n\n${body}\n`;
  }

  /** 内存日志全文，替代上游 `logcat -d` 的产物。 */
  private static dumpMemoryLog(): string {
    const entries = AppLog.getAll();
    const lines: string[] = [];
    for (const entry of entries) {
      lines.push(`${AppLog.formatTime(entry.timestamp)} ${entry.content()}`);
    }
    return lines.join('\n');
  }

  /** 文件名里的时间部分，格式对齐上游 `SimpleDateFormat("yyyy-MM-dd-HH-mm-ss")`。 */
  private static formatFileTime(timestamp: number): string {
    const date = new Date(timestamp);
    const pad = (value: number, width: number): string => value.toString().padStart(width, '0');
    const year = pad(date.getFullYear(), 4);
    const month = pad(date.getMonth() + 1, 2);
    const day = pad(date.getDate(), 2);
    const hour = pad(date.getHours(), 2);
    const minute = pad(date.getMinutes(), 2);
    const second = pad(date.getSeconds(), 2);
    return `${year}-${month}-${day}-${hour}-${minute}-${second}`;
  }

  /** 删掉目录里超过保留期的文件，对齐上游 `it.lastModified() < exceedTimeMillis`。 */
  private static purgeExpired(folder: string, now: number): void {
    const deadline = now - CRASH_RETENTION_MS;
    let names: string[] = [];
    try {
      names = fileIo.listFileSync(folder);
    } catch (error) {
      return;
    }
    for (const name of names) {
      const path = CrashLogRepository.childPath(folder, name);
      try {
        const stat = fileIo.statSync(path);
        if (stat.mtime * 1000 < deadline) {
          fileIo.unlinkSync(path);
        }
      } catch (error) {
        // 单个文件删不掉不影响其它文件。
      }
    }
  }

  /** 列目录下的普通文件，按名字倒序（新在前）。目录不存在返回空数组。 */
  private static listFolder(folder: string, inBackupFolder: boolean): CrashLogFile[] {
    const result: CrashLogFile[] = [];
    if (!fileIo.accessSync(folder)) {
      return result;
    }
    let names: string[] = [];
    try {
      names = fileIo.listFileSync(folder);
    } catch (error) {
      return result;
    }
    for (const name of names) {
      const path = CrashLogRepository.childPath(folder, name);
      try {
        const stat = fileIo.statSync(path);
        if (stat.isDirectory()) {
          continue;
        }
        result.push({ name: name, size: stat.size, lastModified: stat.mtime * 1000,
          inBackupFolder: inBackupFolder });
      } catch (error) {
        // 拿不到 stat 的条目直接跳过。
      }
    }
    result.sort((left: CrashLogFile, right: CrashLogFile): number => {
      if (left.name === right.name) {
        return 0;
      }
      return left.name < right.name ? 1 : -1;
    });
    return result;
  }

  private static childPath(parent: string, name: string): string {
    if (parent.endsWith('/')) {
      return `${parent}${name}`;
    }
    return `${parent}/${name}`;
  }

  private static ensureDirectory(path: string): void {
    if (!fileIo.accessSync(path)) {
      fileIo.mkdirSync(path, true);
    }
  }

  private static writeText(path: string, content: string): void {
    const file = fileIo.openSync(path, fileIo.OpenMode.WRITE_ONLY | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC);
    try {
      fileIo.writeSync(file.fd, content);
    } finally {
      fileIo.closeSync(file);
    }
  }

  private static readText(path: string): string {
    const stat = fileIo.statSync(path);
    if (stat.size <= 0) {
      return '';
    }
    const buffer = new ArrayBuffer(stat.size);
    const file = fileIo.openSync(path, fileIo.OpenMode.READ_ONLY);
    try {
      fileIo.readSync(file.fd, buffer);
    } finally {
      fileIo.closeSync(file);
    }
    return new util.TextDecoder().decodeToString(new Uint8Array(buffer));
  }

  private static copyFile(source: string, target: string): void {
    const input = fileIo.openSync(source, fileIo.OpenMode.READ_ONLY);
    try {
      const output = fileIo.openSync(target,
        fileIo.OpenMode.WRITE_ONLY | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC);
      try {
        fileIo.copyFileSync(input.fd, output.fd);
      } finally {
        fileIo.closeSync(output);
      }
    } finally {
      fileIo.closeSync(input);
    }
  }

  private static removeFile(path: string): void {
    if (fileIo.accessSync(path)) {
      fileIo.unlinkSync(path);
    }
  }

  private static removeTree(path: string): void {
    if (!fileIo.accessSync(path)) {
      return;
    }
    try {
      fileIo.rmdirSync(path);
    } catch (error) {
      // 目录不存在或已被删掉，忽略。
    }
  }

  private static versionName(context: Context): string {
    try {
      // 崩溃路径上不能 await，所以用同步版（`@ohos.bundle.bundleManager.d.ts:1041`）。
      const info = bundleManager.getBundleInfoForSelfSync(bundleManager.BundleFlag.GET_BUNDLE_INFO_WITH_APPLICATION);
      return info.versionName;
    } catch (error) {
      return '';
    }
  }

  private static deviceModel(): string {
    try {
      return deviceInfo.productModel;
    } catch (error) {
      return '';
    }
  }

  private static sdkInt(): number {
    try {
      return deviceInfo.sdkApiVersion;
    } catch (error) {
      return 0;
    }
  }

  private static describe(error: Object): string {
    if (error instanceof Error) {
      return `${error.name}: ${error.message}`;
    }
    return String(error);
  }
}
