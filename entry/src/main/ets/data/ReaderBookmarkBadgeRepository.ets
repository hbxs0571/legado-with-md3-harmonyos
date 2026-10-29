import { Context } from '@kit.AbilityKit';
import { fileIo, picker } from '@kit.CoreFileKit';

/**
 * 阅读页书签角标的自定义图片。
 *
 * 对齐上游 `BookmarkBadgeDelegate`：选中的图片先复制进应用私有目录
 * （`filesDir/bookmark-badge/`），设置里只存这份副本的路径。系统选择器给的 URI
 * 只是临时授权，应用重启后通常失效，与字体、分组封面的做法保持一致。
 */
export class ReaderBookmarkBadgeRepository {
  private static readonly folderName: string = 'bookmark-badge';
  /** 角标最大只有 50dp 宽、100dp 高，超过 8 MB 的图基本是用户误选。 */
  private static readonly maximumBytes: number = 8 * 1024 * 1024;
  private static readonly supportedSuffixes: string[] = ['.png', '.jpg', '.jpeg', '.webp', '.bmp', '.svg'];

  static folderPath(context: Context): string {
    return `${context.filesDir}/${ReaderBookmarkBadgeRepository.folderName}`;
  }

  /** 该路径是否落在本仓储的私有目录内；用于拒绝偏好里被写入的任意外部路径。 */
  static isOwnedPath(context: Context, path: string): boolean {
    if (path.length === 0) { return false; }
    const prefix = `${ReaderBookmarkBadgeRepository.folderPath(context)}/`;
    if (!path.startsWith(prefix)) { return false; }
    return fileIo.accessSync(path);
  }

  /**
   * 弹出系统文件选择器挑一张图片，复制进私有目录后返回副本路径。
   * 用户取消时返回 `undefined`；文件不合规时抛错，由调用方提示。
   */
  static async chooseImage(context: Context): Promise<string | undefined> {
    const options = new picker.DocumentSelectOptions();
    options.fileSuffixFilters = ['图片|.png,.jpg,.jpeg,.webp,.bmp,.svg'];
    options.maxSelectNumber = 1;
    const uris = await new picker.DocumentViewPicker(context).select(options);
    const uri = uris[0];
    if (uri === undefined || uri.length === 0) { return undefined; }
    const extension = ReaderBookmarkBadgeRepository.extensionOf(uri);
    if (!ReaderBookmarkBadgeRepository.supportedSuffixes.includes(extension)) {
      throw new Error('只支持 PNG、JPG、WebP、BMP 或 SVG 图片');
    }
    const directory = ReaderBookmarkBadgeRepository.folderPath(context);
    ReaderBookmarkBadgeRepository.ensureDirectory(directory);
    // 每次都换新文件名：阅读页按路径字符串与修改时间判断是否需要重新解码，
    // 覆盖同名文件会让缓存拿到旧图。
    const targetPath = `${directory}/badge-${Date.now()}-${Math.floor(Math.random() * 1000)}${extension}`;
    const source = fileIo.openSync(uri, fileIo.OpenMode.READ_ONLY);
    try {
      const stat = fileIo.statSync(source.fd);
      if (stat.size <= 0) { throw new Error('所选图片文件为空'); }
      if (stat.size > ReaderBookmarkBadgeRepository.maximumBytes) { throw new Error('所选图片超过 8 MB'); }
      fileIo.copyFileSync(source.fd, targetPath);
      const copied = fileIo.statSync(targetPath);
      if (copied.size !== stat.size) { throw new Error('图片复制不完整'); }
    } catch (error) {
      ReaderBookmarkBadgeRepository.deleteQuietly(targetPath);
      if (error instanceof Error) { throw error; }
      throw new Error('保存书签角标图片失败');
    } finally {
      fileIo.closeSync(source);
    }
    return targetPath;
  }

  /** 切换角标图片后删掉上一张副本，避免私有目录无限增长。 */
  static removeImage(path: string): void {
    ReaderBookmarkBadgeRepository.deleteQuietly(path);
  }

  private static deleteQuietly(path: string): void {
    if (path.length === 0) { return; }
    try {
      if (fileIo.accessSync(path)) { fileIo.unlinkSync(path); }
    } catch (_) {
      // 删除失败不影响主流程：文件留在私有目录里也不会再被引用。
    }
  }

  private static ensureDirectory(directory: string): void {
    if (!fileIo.accessSync(directory)) { fileIo.mkdirSync(directory, true); }
  }

  /** 从选择器返回的 URI 尾部取小写扩展名；取不到扩展名时返回空串。 */
  private static extensionOf(uri: string): string {
    const queryIndex = uri.indexOf('?');
    const path = queryIndex >= 0 ? uri.substring(0, queryIndex) : uri;
    const slashIndex = path.lastIndexOf('/');
    const name = slashIndex >= 0 ? path.substring(slashIndex + 1) : path;
    const dotIndex = name.lastIndexOf('.');
    if (dotIndex < 0) { return ''; }
    return name.substring(dotIndex).toLowerCase();
  }
}
