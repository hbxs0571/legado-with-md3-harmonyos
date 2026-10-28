import { Context } from '@kit.AbilityKit';
import { UIContext } from '@kit.ArkUI';
import { fileIo, picker } from '@kit.CoreFileKit';
import { text } from '@kit.ArkGraphics2D';

export interface ReaderFontEntry {
  displayName: string;
  path: string;
  familyName: string;
}

/** 阅读器本地字体：复制到应用沙箱，冷启动时可重新注册。 */
export class ReaderFontRepository {
  private static readonly folderName: string = 'reader-fonts';
  private static readonly maxFontBytes: number = 64 * 1024 * 1024;
  private static readonly maxWidthCacheEntries: number = 4096;
  private static readonly registeredPaths: Set<string> = new Set<string>();
  private static readonly widthCache: Map<string, number> = new Map<string, number>();

  static systemTypefaceFamily(index: number): string {
    if (index === 1) { return 'serif'; }
    if (index === 2) { return 'monospace'; }
    return 'HarmonyOS Sans';
  }

  static folderPath(context: Context): string {
    return `${context.filesDir}/${ReaderFontRepository.folderName}`;
  }

  static listFonts(context: Context): ReaderFontEntry[] {
    const directory = ReaderFontRepository.folderPath(context);
    try {
      if (!fileIo.accessSync(directory)) { return []; }
      const entries = fileIo.listFileSync(directory);
      const fonts: ReaderFontEntry[] = [];
      for (let index = 0; index < entries.length; index++) {
        const name = entries[index];
        if (name === undefined || !ReaderFontRepository.isFontName(name)) { continue; }
        const path = `${directory}/${name}`;
        try {
          if (!fileIo.statSync(path).isFile()) { continue; }
          fonts.push({
            displayName: ReaderFontRepository.displayName(name),
            path: path,
            familyName: ReaderFontRepository.familyName(path)
          });
        } catch (_) {
          // 忽略已被系统清理或损坏的目录项。
        }
      }
      return fonts.sort((left: ReaderFontEntry, right: ReaderFontEntry) =>
        left.displayName.localeCompare(right.displayName, 'zh-Hans-CN'));
    } catch (_) {
      return [];
    }
  }

  /** 导入单个 TTF/OTF 文件；选择器授权只用于复制，之后仅读应用私有副本。 */
  static async importFont(context: Context): Promise<ReaderFontEntry | undefined> {
    const options = new picker.DocumentSelectOptions();
    options.fileSuffixFilters = ['字体文件|.ttf,.otf'];
    options.maxSelectNumber = 1;
    const uris = await new picker.DocumentViewPicker(context).select(options);
    const uri = uris[0];
    if (uri === undefined) { return undefined; }
    const rawName = ReaderFontRepository.fileNameFromUri(uri);
    if (!ReaderFontRepository.isFontName(rawName)) { throw new Error('只支持 TTF 或 OTF 字体文件'); }
    ReaderFontRepository.ensureFontDirectory(context);
    const stamp = Date.now().toString(36);
    const extension = rawName.substring(rawName.lastIndexOf('.') + 1).toLowerCase();
    const safeStem = rawName.substring(0, rawName.lastIndexOf('.'))
      .replace(/[^a-zA-Z0-9_-]/g, '_').substring(0, 40) || 'font';
    const targetPath = `${ReaderFontRepository.folderPath(context)}/font-${stamp}-${safeStem}.${extension}`;
    const source = fileIo.openSync(uri, fileIo.OpenMode.READ_ONLY);
    try {
      const stat = fileIo.statSync(source.fd);
      if (stat.size <= 0 || stat.size > ReaderFontRepository.maxFontBytes) {
        throw new Error('字体文件为空或超过 64 MB');
      }
      fileIo.copyFileSync(source.fd, targetPath);
      const copied = fileIo.statSync(targetPath);
      if (copied.size <= 0 || copied.size !== stat.size) { throw new Error('字体文件复制不完整'); }
    } catch (error) {
      try { if (fileIo.accessSync(targetPath)) { fileIo.unlinkSync(targetPath); } } catch (_) {}
      if (error instanceof Error) { throw error; }
      throw new Error('导入字体失败');
    } finally {
      fileIo.closeSync(source);
    }
    return {
      displayName: rawName,
      path: targetPath,
      familyName: ReaderFontRepository.familyName(targetPath)
    };
  }

  /** 注册应用沙箱中的字体；不接受备份中或偏好中传入的任意外部路径。 */
  static resolveFamily(context: Context, path: string, systemTypeface: number): string {
    const fallback = ReaderFontRepository.systemTypefaceFamily(systemTypeface);
    if (path.length === 0 || !path.startsWith(`${ReaderFontRepository.folderPath(context)}/`)) { return fallback; }
    const family = ReaderFontRepository.familyName(path);
    try {
      if (!fileIo.accessSync(path)) { return fallback; }
      if (!ReaderFontRepository.registeredPaths.has(path)) {
        text.FontCollection.getGlobalInstance().loadFontSync(family, `file://${path}`);
        ReaderFontRepository.registeredPaths.add(path);
      }
      return family;
    } catch (_) {
      return fallback;
    }
  }

  /** 目录选择能力受设备限制；支持时把目录内字体复制到应用私有目录。 */
  static async importFontFolder(context: Context): Promise<number> {
    const options = new picker.DocumentSelectOptions();
    options.selectMode = picker.DocumentSelectMode.FOLDER;
    options.maxSelectNumber = 1;
    const uris = await new picker.DocumentViewPicker(context).select(options);
    const uri = uris[0];
    if (uri === undefined) { return 0; }
    const folderPath = uri.startsWith('file://') ? uri.substring('file://'.length) : uri;
    const names = fileIo.listFileSync(folderPath);
    ReaderFontRepository.ensureFontDirectory(context);
    let imported = 0;
    for (let index = 0; index < names.length; index++) {
      const name = names[index];
      if (name === undefined || !ReaderFontRepository.isFontName(name)) { continue; }
      const stamp = `${Date.now().toString(36)}_${index}`;
      const extension = name.substring(name.lastIndexOf('.') + 1).toLowerCase();
      const safeStem = name.substring(0, name.lastIndexOf('.')).replace(/[^a-zA-Z0-9_-]/g, '_').substring(0, 40) || 'font';
      const sourcePath = `${folderPath}/${name}`;
      const targetPath = `${ReaderFontRepository.folderPath(context)}/font-${stamp}-${safeStem}.${extension}`;
      let source: fileIo.File | undefined = undefined;
      try {
        source = fileIo.openSync(sourcePath, fileIo.OpenMode.READ_ONLY);
        const stat = fileIo.statSync(source.fd);
        if (stat.size <= 0 || stat.size > ReaderFontRepository.maxFontBytes) { continue; }
        fileIo.copyFileSync(source.fd, targetPath);
        if (fileIo.statSync(targetPath).size === stat.size) { imported++; }
        else if (fileIo.accessSync(targetPath)) { fileIo.unlinkSync(targetPath); }
      } catch (_) {
        try { if (fileIo.accessSync(targetPath)) { fileIo.unlinkSync(targetPath); } } catch (_) {}
      } finally {
        if (source !== undefined) { try { fileIo.closeSync(source); } catch (_) {} }
      }
    }
    return imported;
  }

  /** 分页阶段按字形缓存宽度，避免逐字符同步排版整段文本。 */
  static measureTextWidthForPagination(context: UIContext, value: string, family: string, fontSizeFp: number): number {
    let totalWidth = 0;
    let cursor = 0;
    while (cursor < value.length) {
      const codePoint = value.codePointAt(cursor);
      const nextCursor = cursor + (codePoint !== undefined && codePoint > 0xFFFF ? 2 : 1);
      const glyph = value.substring(cursor, nextCursor);
      const cacheKey = `${family}|${fontSizeFp}|${glyph}`;
      let glyphWidth = ReaderFontRepository.widthCache.get(cacheKey);
      if (glyphWidth === undefined) {
        glyphWidth = ReaderFontRepository.measureTextWidth(context, glyph, family, fontSizeFp);
        if (ReaderFontRepository.widthCache.size >= ReaderFontRepository.maxWidthCacheEntries) {
          ReaderFontRepository.widthCache.clear();
        }
        ReaderFontRepository.widthCache.set(cacheKey, glyphWidth);
      }
      totalWidth += glyphWidth;
      cursor = nextCursor;
    }
    return totalWidth;
  }
  /** 用与阅读器相同的字体引擎测量一行宽度，覆盖自定义字体和衬线/等宽系统族。 */
  static measureTextWidth(context: UIContext, value: string, family: string, fontSizeFp: number): number {
    if (value.length === 0) { return 0; }
    // MeasureUtils 的系统默认字体测量路径更轻；只把非默认字体交给 ParagraphBuilder。
    if (family === 'HarmonyOS Sans') {
      const metrics = context.getMeasureUtils().measureTextSize({ textContent: value, fontSize: fontSizeFp });
      const rawWidth = metrics.width ?? 0;
      let widthPx = 0;
      if (typeof rawWidth === 'number') { widthPx = rawWidth; }
      else if (typeof rawWidth === 'string') { widthPx = Number.parseFloat(rawWidth); }
      return context.px2vp(Number.isFinite(widthPx) ? widthPx : 0);
    }
    const cacheKey = `${family}|${fontSizeFp}|${value}`;
    const cached = ReaderFontRepository.widthCache.get(cacheKey);
    if (cached !== undefined) { return cached; }
    const builder = new text.ParagraphBuilder({
      textStyle: { fontFamilies: [family], fontSize: context.fp2px(fontSizeFp) }
    }, text.FontCollection.getGlobalInstance());
    builder.addText(value);
    const paragraph = builder.build();
    paragraph.layoutSync(1000000);
    const width = context.px2vp(paragraph.getLongestLine());
    if (ReaderFontRepository.widthCache.size >= ReaderFontRepository.maxWidthCacheEntries) {
      ReaderFontRepository.widthCache.clear();
    }
    ReaderFontRepository.widthCache.set(cacheKey, width);
    return width;
  }

  /** 取真实字形的单行高度，供分页行高和章节标题预留空间使用。 */
  static measureLineHeight(context: UIContext, family: string, fontSizeFp: number): number {
    if (family === 'HarmonyOS Sans') {
      const metrics = context.getMeasureUtils().measureTextSize({ textContent: '国Mg', fontSize: fontSizeFp });
      const rawHeight = metrics.height ?? 0;
      let heightPx = 0;
      if (typeof rawHeight === 'number') { heightPx = rawHeight; }
      else if (typeof rawHeight === 'string') { heightPx = Number.parseFloat(rawHeight); }
      const height = context.px2vp(Number.isFinite(heightPx) ? heightPx : 0);
      return Number.isFinite(height) && height > 0 ? height : fontSizeFp * 1.25;
    }
    const builder = new text.ParagraphBuilder({
      textStyle: { fontFamilies: [family], fontSize: context.fp2px(fontSizeFp) }
    }, text.FontCollection.getGlobalInstance());
    builder.addText('国Mg');
    const paragraph = builder.build();
    paragraph.layoutSync(1000000);
    const height = context.px2vp(paragraph.getHeight());
    return Number.isFinite(height) && height > 0 ? height : fontSizeFp * 1.25;
  }

  static displayName(path: string): string {
    const separator = path.lastIndexOf('/');
    const name = separator >= 0 ? path.substring(separator + 1) : path;
    const dot = name.lastIndexOf('.');
    return dot > 0 ? name.substring(0, dot) : name;
  }

  static familyName(path: string): string {
    const separator = path.lastIndexOf('/');
    const name = separator >= 0 ? path.substring(separator + 1) : path;
    const dot = name.lastIndexOf('.');
    const stem = dot > 0 ? name.substring(0, dot) : name;
    return `LegadoReader_${stem.replace(/[^a-zA-Z0-9_-]/g, '_')}`;
  }

  private static fileNameFromUri(uri: string): string {
    const withoutQuery = uri.split('?')[0] ?? uri;
    const separator = withoutQuery.lastIndexOf('/');
    const rawName = separator >= 0 ? withoutQuery.substring(separator + 1) : withoutQuery;
    try { return decodeURIComponent(rawName); } catch (_) { return rawName; }
  }

  private static isFontName(name: string): boolean {
    const normalized = name.toLowerCase();
    return normalized.endsWith('.ttf') || normalized.endsWith('.otf');
  }

  private static ensureFontDirectory(context: Context): void {
    const directory = ReaderFontRepository.folderPath(context);
    try {
      if (!fileIo.accessSync(directory)) { fileIo.mkdirSync(directory, true); }
    } catch (error) {
      try { if (fileIo.statSync(directory).isDirectory()) { return; } } catch (_) {}
      if (error instanceof Error) { throw error; }
      throw new Error('无法创建阅读器字体目录');
    }
  }
}
