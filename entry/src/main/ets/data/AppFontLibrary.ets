/**
 * 应用字体库：扫描、导入、排序、清理。
 *
 * 上游三处源码是本文件的依据：
 * - `help/FontLoader.kt`：`fontFileRegex = Regex("(?i).*\\.[ot]tf")`、`FontFolderRead` 四态
 *   （`NotConfigured` / `Loaded` / `Empty` / `Unreadable`）、`scanFontFiles()` 合并时
 *   「配置的字体文件夹优先、私有目录补缺」、`importFontFiles()` 按扩展名过滤后复制。
 * - `ui/config/themeConfig/ThemeConfigViewModel.kt:555-618`：导入副本以内容摘要命名
 *   （`app_font_$digest.$extension`），`pruneCopiedFonts()` 只删 `app_font` 前缀。
 * - `ui/widget/components/FontSelectGrid.kt:72-83`：`FontSort` 六档，序号即持久值。
 *
 * 与上游的目录差异：上游 `appFontDir()` 是 `File(filesDir, "fonts")`（复数、私有目录），
 * `fontDir()` 是 `getExternalFilesDir(null)/font`（单数、外部目录）。ArkUI 侧只有一个
 * 应用沙箱，两者都落在 `filesDir/fonts`，故本地只保留一个目录。
 */

import { Context } from '@kit.AbilityKit';
import { fileIo } from '@kit.CoreFileKit';
import { cryptoFramework } from '@kit.CryptoArchitectureKit';
import { text } from '@kit.ArkGraphics2D';

/** 应用字体副本目录名（相对 `filesDir`），对齐上游 `appFontDir()`。 */
export const APP_FONT_DIRECTORY: string = 'fonts';

/** 导入副本的文件名前缀，`pruneAppFonts()` 只处理带此前缀的文件（上游 `pruneCopiedFonts`）。 */
export const APP_FONT_PREFIX: string = 'app_font';

/** 单个字体文件上限，与阅读器字体库同一口径。 */
const MAX_FONT_BYTES: number = 64 * 1024 * 1024;

/** 字体排序六档，序号即上游 `FontSort` 的持久值（`FontSelectGrid.kt:72-83`）。 */
export enum AppFontSort {
  NameAsc = 0,
  NameDesc = 1,
  SizeAsc = 2,
  SizeDesc = 3,
  DateAsc = 4,
  DateDesc = 5
}

/** 排序项的界面文案，对齐上游 `sort_name_asc` 等六条字符串。 */
export const APP_FONT_SORT_LABELS: string[] = ['名称升序', '名称降序', '大小升序', '大小降序', '时间升序', '时间降序'];

/** 序号转排序枚举；越界回落到名称升序（上游 `FontSort.fromInt` 的 `getOrElse`）。 */
export function appFontSortFromInt(value: number): AppFontSort {
  if (value === 1) { return AppFontSort.NameDesc; }
  if (value === 2) { return AppFontSort.SizeAsc; }
  if (value === 3) { return AppFontSort.SizeDesc; }
  if (value === 4) { return AppFontSort.DateAsc; }
  if (value === 5) { return AppFontSort.DateDesc; }
  return AppFontSort.NameAsc;
}

/** 排序序号归一，非法值回落 0。 */
export function normalizeAppFontSort(value: number): number {
  if (!Number.isFinite(value)) { return 0; }
  const rounded = Math.round(value);
  if (rounded < 0) { return 0; }
  return rounded > 5 ? 5 : rounded;
}

/** 字体条目：`path` 是沙箱内绝对路径，`name` 是展示用文件名（含扩展名）。 */
export interface AppFontEntry {
  name: string;
  path: string;
  size: number;
  mtime: number;
  /** 条目预览族名（已注册进全局字体集合）；空串表示注册失败，回落默认字体。 */
  family: string;
}

/** 字体文件夹读取结果，四态与上游 `FontFolderRead` 一一对应。 */
export enum AppFontFolderState {
  NotConfigured = 0,
  Loaded = 1,
  Empty = 2,
  Unreadable = 3
}

/** 一次扫描的结果：可用字体列表 + 文件夹读取状态。 */
export interface AppFontScan {
  fonts: AppFontEntry[];
  folder: AppFontFolderState;
}

/** 字体库操作集合；全部静态方法，无实例状态。 */
export class AppFontLibrary {
  /** 已注册过的预览族名，避免同一路径重复 `loadFontSync`。 */
  private static readonly registeredFamilies: Set<string> = new Set<string>();

  /** 字体副本目录绝对路径。 */
  static directory(context: Context): string {
    return `${context.filesDir}/${APP_FONT_DIRECTORY}`;
  }

  /**
   * 目录内所有字体文件。
   *
   * 只收 `.ttf` / `.otf`（上游 `fontFileRegex` 不含 `.ttc`）；读不到的条目静默跳过，
   * 与上游 `listFontFilesInDir` 的容错一致。
   */
  static listFonts(context: Context): AppFontEntry[] {
    const directory = AppFontLibrary.directory(context);
    const fonts: AppFontEntry[] = [];
    let names: string[] = [];
    try {
      if (!fileIo.accessSync(directory)) { return fonts; }
      names = fileIo.listFileSync(directory);
    } catch (_) {
      return fonts;
    }
    for (let index = 0; index < names.length; index++) {
      const name = names[index];
      if (name === undefined || !AppFontLibrary.isFontName(name)) { continue; }
      const path = `${directory}/${name}`;
      try {
        const stat = fileIo.statSync(path);
        if (!stat.isFile()) { continue; }
        fonts.push({
          name: name, path: path, size: stat.size, mtime: stat.mtime * 1000,
          family: AppFontLibrary.registerFamily(path)
        });
      } catch (_) {
        // 已被系统清理或损坏的目录项，跳过。
      }
    }
    return fonts;
  }

  /**
   * 扫描「私有目录 + 用户选的字体文件夹」，合并后按名字去重。
   *
   * 上游 `scanFontFiles()` 的合并顺序：配置的字体文件夹优先（`merged[name] = folderFont`），
   * 私有目录只补缺（`putIfAbsent`）。本地同序。
   */
  static scan(context: Context, folderPath: string): AppFontScan {
    const privateFonts = AppFontLibrary.listFonts(context);
    if (folderPath.length === 0) {
      return { fonts: privateFonts, folder: AppFontFolderState.NotConfigured };
    }
    const read = AppFontLibrary.readFolder(folderPath);
    const merged: Map<string, AppFontEntry> = new Map<string, AppFontEntry>();
    for (let index = 0; index < read.fonts.length; index++) {
      const item = read.fonts[index];
      merged.set(item.name, item);
    }
    for (let index = 0; index < privateFonts.length; index++) {
      const item = privateFonts[index];
      if (!merged.has(item.name)) { merged.set(item.name, item); }
    }
    const fonts: AppFontEntry[] = [];
    merged.forEach((item: AppFontEntry) => { fonts.push(item); });
    return { fonts: fonts, folder: read.folder };
  }

  /** 读一个外部字体目录；三种失败分别落到 Empty / Unreadable，对应上游 `readFontFolder`。 */
  static readFolder(folderPath: string): AppFontScan {
    const fonts: AppFontEntry[] = [];
    let names: string[] = [];
    try {
      const normalized = folderPath.startsWith('file://') ? folderPath.substring('file://'.length) : folderPath;
      if (!fileIo.accessSync(normalized)) {
        return { fonts: fonts, folder: AppFontFolderState.Unreadable };
      }
      if (!fileIo.statSync(normalized).isDirectory()) {
        return { fonts: fonts, folder: AppFontFolderState.Unreadable };
      }
      names = fileIo.listFileSync(normalized);
      for (let index = 0; index < names.length; index++) {
        const name = names[index];
        if (name === undefined || !AppFontLibrary.isFontName(name)) { continue; }
        const path = `${normalized}/${name}`;
        try {
          const stat = fileIo.statSync(path);
          if (!stat.isFile()) { continue; }
          fonts.push({
            name: name, path: path, size: stat.size, mtime: stat.mtime * 1000,
            family: AppFontLibrary.registerFamily(path)
          });
        } catch (_) {
        }
      }
    } catch (_) {
      return { fonts: [], folder: AppFontFolderState.Unreadable };
    }
    // 目录能访问但一个条目都没读出来：部分设备的选择器返回的目录就是这种情况。
    if (names.length === 0) { return { fonts: fonts, folder: AppFontFolderState.Empty }; }
    if (fonts.length === 0) { return { fonts: fonts, folder: AppFontFolderState.Empty }; }
    return { fonts: fonts, folder: AppFontFolderState.Loaded };
  }

  /**
   * 把一个外部字体文件复制进私有目录，返回目标绝对路径。
   *
   * 命名用内容摘要（上游 `ThemeConfigViewModel.kt:566` 的注释：同一字体无论导入多少次都
   * 指向同一路径，不留重复副本）；摘要算不出来时回落到时间戳，不阻断导入。
   */
  static importFile(context: Context, sourcePath: string, displayName: string): string {
    const directory = AppFontLibrary.directory(context);
    AppFontLibrary.ensureDirectory(directory);
    const extension = AppFontLibrary.extensionOf(displayName);
    const digest = AppFontLibrary.md5OfFile(sourcePath);
    const stem = digest.length > 0 ? digest : `${Date.now()}`;
    const target = `${directory}/${APP_FONT_PREFIX}_${stem}.${extension}`;
    if (fileIo.accessSync(target)) { return target; }
    const source = fileIo.openSync(sourcePath, fileIo.OpenMode.READ_ONLY);
    try {
      const stat = fileIo.statSync(source.fd);
      if (stat.size <= 0) { throw new Error('字体文件为空'); }
      if (stat.size > MAX_FONT_BYTES) { throw new Error('字体文件超过 64 MB'); }
      fileIo.copyFileSync(source.fd, target);
      if (fileIo.statSync(target).size !== stat.size) {
        try { fileIo.unlinkSync(target); } catch (_) { }
        throw new Error('字体文件复制不完整');
      }
    } finally {
      fileIo.closeSync(source);
    }
    return target;
  }

  /** 只保留 `keep` 指向的副本，其余 `app_font*` 删除（上游 `pruneCopiedFonts`）。 */
  static prune(context: Context, keep: string): void {
    const directory = AppFontLibrary.directory(context);
    let names: string[] = [];
    try {
      if (!fileIo.accessSync(directory)) { return; }
      names = fileIo.listFileSync(directory);
    } catch (_) {
      return;
    }
    for (let index = 0; index < names.length; index++) {
      const name = names[index];
      if (name === undefined || !name.startsWith(APP_FONT_PREFIX)) { continue; }
      const full = `${directory}/${name}`;
      if (full === keep) { continue; }
      try { fileIo.unlinkSync(full); } catch (_) { }
    }
  }

  /** 按六档排序返回新数组，不改入参。名称比较用中文排序规则（上游 `cnCompare`）。 */
  static sort(fonts: AppFontEntry[], sort: number): AppFontEntry[] {
    const copy: AppFontEntry[] = [];
    for (let index = 0; index < fonts.length; index++) { copy.push(fonts[index]); }
    const mode = appFontSortFromInt(sort);
    copy.sort((left: AppFontEntry, right: AppFontEntry): number => {
      if (mode === AppFontSort.NameAsc) { return left.name.localeCompare(right.name, 'zh-Hans-CN'); }
      if (mode === AppFontSort.NameDesc) { return right.name.localeCompare(left.name, 'zh-Hans-CN'); }
      if (mode === AppFontSort.SizeAsc) { return left.size - right.size; }
      if (mode === AppFontSort.SizeDesc) { return right.size - left.size; }
      if (mode === AppFontSort.DateAsc) { return left.mtime - right.mtime; }
      return right.mtime - left.mtime;
    });
    return copy;
  }

  /** 名称过滤（上游 `filteredItems` 的 `name.contains(query, ignoreCase = true)`）。 */
  static filter(fonts: AppFontEntry[], query: string): AppFontEntry[] {
    const keyword = query.trim().toLowerCase();
    if (keyword.length === 0) { return fonts; }
    const matched: AppFontEntry[] = [];
    for (let index = 0; index < fonts.length; index++) {
      const item = fonts[index];
      if (item.name.toLowerCase().includes(keyword)) { matched.push(item); }
    }
    return matched;
  }

  /** 是否字体文件名，对齐上游 `isFontFileName`（只认 ttf / otf）。 */
  static isFontName(name: string): boolean {
    const lower = name.toLowerCase();
    return lower.endsWith('.ttf') || lower.endsWith('.otf');
  }

  /**
   * 把字体注册进全局字体集合，返回可用于 `Text.fontFamily()` 的族名。
   *
   * 上游 `FontSelectGrid.kt:250-280 rememberItemFontFamily` 用 `Typeface.createFromFile()`
   * 让每个条目的名字用它自己的字体渲染；ArkUI 的等价物是
   * `FontCollection.getGlobalInstance().loadFontSync(family, 'file://' + path)`。
   * 注册失败返回空串，调用方回落到默认字体（上游 `FontFamily?` 为 null 时同理）。
   */
  static registerFamily(path: string): string {
    const family = AppFontLibrary.previewFamily(path);
    try {
      if (!fileIo.accessSync(path)) { return ''; }
      if (AppFontLibrary.registeredFamilies.has(family)) { return family; }
      text.FontCollection.getGlobalInstance().loadFontSync(family, `file://${path}`);
      AppFontLibrary.registeredFamilies.add(family);
      return family;
    } catch (_) {
      return '';
    }
  }

  /** 预览族名：由文件名派生，去掉非字母数字以免族名非法。 */
  static previewFamily(path: string): string {
    const separator = path.lastIndexOf('/');
    const name = separator >= 0 ? path.substring(separator + 1) : path;
    const dot = name.lastIndexOf('.');
    const stem = dot > 0 ? name.substring(0, dot) : name;
    return `LegadoAppFontPreview_${stem.replace(/[^a-zA-Z0-9_-]/g, '_')}`;
  }

  /** 展示名去掉扩展名，供列表与「当前字体」摘要使用。 */
  static displayName(name: string): string {
    const dot = name.lastIndexOf('.');
    return dot > 0 ? name.substring(0, dot) : name;
  }

  private static extensionOf(name: string): string {
    const dot = name.lastIndexOf('.');
    if (dot < 0) { return 'ttf'; }
    const raw = name.substring(dot + 1).toLowerCase();
    // 上游把扩展名限制成 1..8 位字母数字，避免把奇怪后缀写进文件名。
    return /^[a-z0-9]{1,8}$/.test(raw) ? raw : 'ttf';
  }

  private static ensureDirectory(directory: string): void {
    try {
      if (!fileIo.accessSync(directory)) { fileIo.mkdirSync(directory, true); }
    } catch (error) {
      try {
        if (fileIo.statSync(directory).isDirectory()) { return; }
      } catch (_) {
      }
      if (error instanceof Error) { throw error; }
      throw new Error('无法创建应用字体目录');
    }
  }

  /** 文件内容 MD5（十六进制）；失败返回空串，由调用方回落到时间戳命名。 */
  private static md5OfFile(path: string): string {
    let file: fileIo.File | undefined = undefined;
    try {
      const md = cryptoFramework.createMd('MD5');
      file = fileIo.openSync(path, fileIo.OpenMode.READ_ONLY);
      const size = fileIo.statSync(file.fd).size;
      const chunk = new ArrayBuffer(64 * 1024);
      let offset = 0;
      while (offset < size) {
        const want = Math.min(chunk.byteLength, size - offset);
        const read = fileIo.readSync(file.fd, chunk, { offset: offset, length: want });
        if (read <= 0) { break; }
        md.updateSync({ data: new Uint8Array(chunk.slice(0, read)) });
        offset += read;
      }
      const digest = md.digestSync();
      let hex: string = '';
      for (let index = 0; index < digest.data.length; index++) {
        hex += (digest.data[index] as number).toString(16).padStart(2, '0');
      }
      return hex;
    } catch (_) {
      return '';
    } finally {
      if (file !== undefined) {
        try { fileIo.closeSync(file); } catch (_) { }
      }
    }
  }
}
