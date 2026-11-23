import { fileIo } from '@kit.CoreFileKit';
import { util } from '@kit.ArkTS';
import { WebDav, WebDavError, WebDavEntry } from './WebDav';
import { BookProgress, bookProgressFileName, legacyBookProgressFileName, parseBookProgress,
  serializeBookProgress } from '../model/BookProgress';
import { Book } from '../model/Book';
import { BookRepository } from '../data/BookRepository';
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

/** 取路径最后一段作为文件名（背景图上传要用它当远端名）。 */
function fileNameOf(path: string): string {
  const normalized: string = path.replace(new RegExp('\\\\', 'g'), '/');
  const index: number = normalized.lastIndexOf('/');
  return index >= 0 ? normalized.substring(index + 1) : normalized;
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

  /**
   * 上传单本正文文件（:278）。与 uploadBackup 同形：正文文件已是磁盘上现成的副本，
   * 直接流式 PUT，不需要像进度那样先落临时文件。
   * 注意这是只读复制 —— localPath 是导入时转出的唯一正文副本，绝不删除或移动它。
   */
  static async uploadBookFile(context: Context, localPath: string, fileName: string): Promise<void> {
    const settings = await WebDavConfigStore.load(context);
    if (!isWebDavConfigured(settings)) {
      throw new WebDavError('账号或密码为空，请先在设置里填写', 0);
    }
    const dav = new WebDav(buildWebDavRootUrl(settings), settings.account, settings.password);
    try {
      await dav.makeAsDir(dav.getRootUrl());
      await dav.upload(localPath, dav.getRootUrl() + fileName);
    } catch (error) {
      throw wrapError(error);
    } finally {
      dav.close();
    }
  }

  /**
   * 导出书籍到 WebDAV 的 books/ 目录（上游 `AppWebDav.exportWebDav`，`help/AppWebDav.kt:341-367`）。
   *
   * 上游两个重载分别是 `(byteArray, fileName)` 与 `(uri, fileName)`，两者都拼
   * `exportsWebDavUrl + fileName` 再 `WebDav(putUrl, it).upload(...)`，MIME 固定 `text/plain`。
   * 本地对应两个入口：内存字节（EPUB 打包结果）与磁盘现成文件（TXT）。
   *
   * 上游 `if (!NetworkUtils.isAvailable()) return` 是静默跳过；本地抛错让界面能提示，
   * 与本地其它 WebDAV 入口一致（失败不吞）。
   */
  static async exportBytesToWebDav(context: Context, data: ArrayBuffer, fileName: string): Promise<void> {
    const settings = await WebDavConfigStore.load(context);
    if (!isWebDavConfigured(settings)) {
      throw new WebDavError('账号或密码为空，请先在设置里填写', 0);
    }
    const root = buildWebDavRootUrl(settings);
    const dir = buildExportsUrl(root);
    const dav = new WebDav(root, settings.account, settings.password);
    try {
      await dav.makeAsDir(dir);
      await dav.uploadBytes(data, dir + fileName, 'text/plain');
    } catch (error) {
      throw wrapError(error);
    } finally {
      dav.close();
    }
  }

  /** 同 `exportBytesToWebDav`，数据源是磁盘上已有的文件（TXT 导出直接复用，不读进内存）。 */
  static async exportFileToWebDav(context: Context, localPath: string, fileName: string): Promise<void> {
    const settings = await WebDavConfigStore.load(context);
    if (!isWebDavConfigured(settings)) {
      throw new WebDavError('账号或密码为空，请先在设置里填写', 0);
    }
    const root = buildWebDavRootUrl(settings);
    const dir = buildExportsUrl(root);
    const dav = new WebDav(root, settings.account, settings.password);
    try {
      await dav.makeAsDir(dir);
      await dav.upload(localPath, dir + fileName, 'text/plain');
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

  /**
   * 上传一本书的阅读进度到 bookProgress/<书名>_<作者>.json（照上游 AppWebDav.uploadBookProgress）。
   * 走 WebDav.uploadBytes 直接 PUT 字节，对应上游 `WebDav(url).upload(json.toByteArray(), "application/json")`，
   * 不再像以前那样先落临时文件（rcp 的 UploadFromFile 只收路径，现已补上字节通道）。
   */
  static async uploadBookProgress(context: Context, progress: BookProgress): Promise<void> {
    const settings = await WebDavConfigStore.load(context);
    if (!isWebDavConfigured(settings)) {
      throw new WebDavError('账号或密码为空，请先在设置里填写', 0);
    }
    const root = buildWebDavRootUrl(settings);
    const dir = buildBookProgressUrl(root);
    const dav = new WebDav(root, settings.account, settings.password);
    try {
      const json = serializeBookProgress(progress);
      await dav.makeAsDir(dir);
      await dav.uploadBytes(new util.TextEncoder().encodeInto(json).buffer as ArrayBuffer,
        dir + bookProgressFileName(progress.name, progress.author), 'application/json');
    } catch (error) {
      throw wrapError(error);
    } finally {
      dav.close();
    }
  }

  /** 拉某本书的远端进度。远端没有这个文件（404）时返回 undefined，不算失败。 */
  static async downloadBookProgress(context: Context, name: string, author: string): Promise<BookProgress | undefined> {
    const settings = await WebDavConfigStore.load(context);
    if (!isWebDavConfigured(settings)) {
      throw new WebDavError('账号或密码为空，请先在设置里填写', 0);
    }
    const root = buildWebDavRootUrl(settings);
    const dir = buildBookProgressUrl(root);
    // 先按上游规则（<书名>_<作者>，replaceReservedChar）找；找不到再回退到旧版
    // <书名>@<作者> 的百分号编码名，保证本轮规则切换前上传的进度文件仍能读到。
    let remoteUrl = dir + bookProgressFileName(name, author);
    const tempPath = `${context.cacheDir}/legado-progress-pull-${Date.now()}.json`;
    const dav = new WebDav(root, settings.account, settings.password);
    try {
      if (!await dav.exists(remoteUrl)) {
        remoteUrl = dir + legacyBookProgressFileName(name, author);
        if (!await dav.exists(remoteUrl)) {
          return undefined;
        }
      }
      await dav.downloadTo(remoteUrl, tempPath);
      return parseBookProgress(fileIo.readTextSync(tempPath));
    } catch (error) {
      throw wrapError(error);
    } finally {
      dav.close();
      try { if (fileIo.accessSync(tempPath)) { fileIo.unlinkSync(tempPath); } } catch (error) {
        console.error(`[WebDavSync] 清理进度临时文件失败: ${error instanceof Error ? error.message : String(error)}`);
      }
    }
  }

  /**
   * 启动时把远端进度批量对齐到本地，对应上游 `AppWebDav.downloadAllBookProgress()`。
   *
   * 逐本比 `syncTime` 与远端文件的 lastModify：远端不比本地记录的新就跳过；
   * 只有「章序号更靠后，或同章但章内位置更靠后」才覆盖本地，覆盖后把 syncTime 记成现在，
   * 避免下次启动重复覆盖。返回真正被改动的书目，调用方负责落库。
   *
   * 与上游的差别只在数据载体：上游直接 `bookDao.update`，这里把改动回传给调用方，
   * 由它走 `BookRepository.saveImportedBooks` 统一落库（本地书目是内存态 + 整批覆盖）。
   */
  static async downloadAllBookProgress(context: Context, books: Book[]): Promise<Book[]> {
    const settings = await WebDavConfigStore.load(context);
    if (!isWebDavConfigured(settings) || !settings.syncBookProgress || books.length === 0) {
      return [];
    }
    const root = buildWebDavRootUrl(settings);
    const dir = buildBookProgressUrl(root);
    const dav = new WebDav(root, settings.account, settings.password);
    const updated: Book[] = [];
    const tempPath = `${context.cacheDir}/legado-progress-align-${Date.now()}.json`;
    try {
      const entries: WebDavEntry[] = await dav.listFiles(dir);
      // 远端文件名 → 最后修改时间。两种命名规则都收，兼容本轮改名之前上传的文件。
      const remoteTimes: Map<string, number> = new Map<string, number>();
      for (let index = 0; index < entries.length; index++) {
        const entry = entries[index];
        if (entry === undefined || entry.isDirectory) { continue; }
        remoteTimes.set(entry.displayName, entry.lastModified);
      }
      for (let index = 0; index < books.length; index++) {
        const book = books[index];
        if (book === undefined || book.title.length === 0) { continue; }
        let fileName = bookProgressFileName(book.title, book.author);
        let lastModify = remoteTimes.get(fileName);
        if (lastModify === undefined) {
          fileName = legacyBookProgressFileName(book.title, book.author);
          lastModify = remoteTimes.get(fileName);
        }
        if (lastModify === undefined) { continue; }
        // 远端不比上次对齐时刻新，说明这本已经同步过，跳过。
        if (lastModify <= (book.syncTime ?? 0)) { continue; }
        try {
          await dav.downloadTo(dir + fileName, tempPath);
        } catch (error) {
          console.error(`[WebDavSync] 下载进度 ${fileName} 失败: ${error instanceof Error ? error.message : String(error)}`);
          continue;
        }
        const progress = parseBookProgress(fileIo.readTextSync(tempPath));
        try { if (fileIo.accessSync(tempPath)) { fileIo.unlinkSync(tempPath); } } catch (error) {
          console.error(`[WebDavSync] 清理进度临时文件失败: ${error instanceof Error ? error.message : String(error)}`);
        }
        if (progress === undefined) { continue; }
        const localIndex = book.chapterIndex ?? 0;
        const localPos = book.chapterProgress ?? 0;
        const remoteNewer = progress.durChapterIndex > localIndex ||
          (progress.durChapterIndex === localIndex && progress.durChapterPos > localPos);
        if (!remoteNewer) { continue; }
        const next: Book = BookRepository.copyBook(book);
        next.chapterIndex = progress.durChapterIndex;
        next.chapterProgress = progress.durChapterPos;
        if (progress.durChapterTitle.length > 0) { next.lastChapter = progress.durChapterTitle; }
        if (progress.durChapterTime > 0) { next.durChapterTime = progress.durChapterTime; }
        next.syncTime = Date.now();
        updated.push(next);
      }
      return updated;
    } catch (error) {
      throw wrapError(error);
    } finally {
      dav.close();
      try { if (fileIo.accessSync(tempPath)) { fileIo.unlinkSync(tempPath); } } catch (error) {
        console.error(`[WebDavSync] 清理进度临时文件失败: ${error instanceof Error ? error.message : String(error)}`);
      }
    }
  }

  /**
   * 远端是否已存在同名文件，对应上游 `AppWebDav.hasBackUp(backUpName)`。
   * 未配置凭据时返回 false（上游同样是 `authorization?.let { ... } ?: false`）。
   */
  static async hasBackup(context: Context, fileName: string): Promise<boolean> {
    const settings = await WebDavConfigStore.load(context);
    if (!isWebDavConfigured(settings)) {
      return false;
    }
    const root = buildWebDavRootUrl(settings);
    const dav = new WebDav(root, settings.account, settings.password);
    try {
      return await dav.exists(root + fileName);
    } catch (error) {
      throw wrapError(error);
    } finally {
      dav.close();
    }
  }

  /**
   * 列出远端 background/ 目录里的文件名集合，对应上游 AppWebDav.getAllBgWebDavFiles()。
   */
  static async listRemoteBackgrounds(context: Context): Promise<string[]> {
    const settings = await WebDavConfigStore.load(context);
    if (!isWebDavConfigured(settings)) {
      throw new WebDavError('账号或密码为空，请先在设置里填写', 0);
    }
    const root = buildWebDavRootUrl(settings);
    const dir = buildBackgroundUrl(root);
    const dav = new WebDav(root, settings.account, settings.password);
    try {
      const entries: WebDavEntry[] = await dav.listFiles(dir);
      const names: string[] = [];
      for (let index = 0; index < entries.length; index++) {
        const entry = entries[index];
        if (entry === undefined || entry.isDirectory) { continue; }
        names.push(entry.displayName);
      }
      return names;
    } catch (error) {
      throw wrapError(error);
    } finally {
      dav.close();
    }
  }

  /**
   * 上传本地背景图到远端 background/，对应上游 AppWebDav.upBgs(files)。
   * 只上传「远端没有且本地文件确实存在」的那些，已经在远端的一律跳过，
   * 所以重复备份不会反复传同一批图。
   */
  static async uploadBackgrounds(context: Context, localPaths: string[]): Promise<number> {
    if (localPaths.length === 0) {
      return 0;
    }
    const settings = await WebDavConfigStore.load(context);
    if (!isWebDavConfigured(settings)) {
      throw new WebDavError('账号或密码为空，请先在设置里填写', 0);
    }
    const root = buildWebDavRootUrl(settings);
    const dir = buildBackgroundUrl(root);
    const dav = new WebDav(root, settings.account, settings.password);
    let uploaded = 0;
    try {
      const entries: WebDavEntry[] = await dav.listFiles(dir);
      const remoteNames: string[] = [];
      for (let index = 0; index < entries.length; index++) {
        const entry = entries[index];
        if (entry === undefined || entry.isDirectory) { continue; }
        remoteNames.push(entry.displayName);
      }
      await dav.makeAsDir(dir);
      for (let index = 0; index < localPaths.length; index++) {
        const localPath = localPaths[index];
        if (localPath === undefined || localPath.length === 0) { continue; }
        const name = fileNameOf(localPath);
        if (name.length === 0 || remoteNames.includes(name)) { continue; }
        try {
          if (!fileIo.accessSync(localPath)) { continue; }
        } catch (error) {
          continue;
        }
        await dav.upload(localPath, dir + name);
        uploaded += 1;
      }
      return uploaded;
    } catch (error) {
      throw wrapError(error);
    } finally {
      dav.close();
    }
  }

  /**
   * 「只保留最新备份」：删掉远端除 keep 之外所有 backup 开头的文件。
   * 名字不带 backup 前缀的一律不碰 —— 用户可能把别的文件放在同一个目录里。
   */
  static async deleteOtherBackups(context: Context, keep: string): Promise<number> {
    const settings = await WebDavConfigStore.load(context);
    if (!isWebDavConfigured(settings)) {
      throw new WebDavError('账号或密码为空，请先在设置里填写', 0);
    }
    const root = buildWebDavRootUrl(settings);
    const dav = new WebDav(root, settings.account, settings.password);
    let removed = 0;
    try {
      const entries: WebDavEntry[] = await dav.listFiles(root);
      for (let index = 0; index < entries.length; index++) {
        const entry = entries[index];
        if (entry === undefined || entry.isDirectory) { continue; }
        if (!entry.displayName.startsWith('backup') || entry.displayName === keep) { continue; }
        await dav.delete(root + entry.displayName);
        removed += 1;
      }
      return removed;
    } catch (error) {
      throw wrapError(error);
    } finally {
      dav.close();
    }
  }
}
