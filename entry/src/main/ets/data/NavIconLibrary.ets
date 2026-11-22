/**
 * 主导航自定义图标的落盘与清理，对齐上游三处：
 * - `ThemeConfigRouteScreen.kt:59-86`：`File(context.filesDir, "nav_icons")` + 内容摘要命名
 *   `"$digest.png"`，同一张图重复选择命中同一路径。
 * - `ThemeConfigViewModel.kt:334-415`：十个槽位（五个页面 × 未选中/选中），换图时只有
 *   `navIconFileUsage(oldPath) <= 1` 才删旧文件，避免误删被别的槽位共享的同一张图。
 * - `domain/model/settings/AppShellSettings.kt:20-29`：十个 `navIconXxx` 字段名。
 *
 * 本地存的是绝对路径，与字体（`data/AppFontLibrary.ets`）同一种做法。
 */

import { Context } from '@kit.AbilityKit';
import { fileIo } from '@kit.CoreFileKit';
import { cryptoFramework } from '@kit.CryptoArchitectureKit';
import { AppGlyphName } from '../components/AppGlyph';

/** 图标目录名（相对 `filesDir`），对齐上游 `ThemeConfigRouteScreen.kt:60`。 */
export const NAV_ICON_DIRECTORY: string = 'nav_icons';

/** 单个图标大小上限，超过直接拒绝，避免把整张壁纸当图标复制进沙箱。 */
const MAX_ICON_BYTES: number = 8 * 1024 * 1024;

/** 十个槽位的键，顺序与上游 `NavIconManageSheet.kt` 的目标顺序一致。 */
export const NAV_ICON_SLOTS: string[] = [
  'home', 'bookshelf', 'explore', 'rss', 'my',
  'homeSelected', 'bookshelfSelected', 'exploreSelected', 'rssSelected', 'mySelected'
];

/**
 * 一个槽位的描述。
 * - `slot` 是偏好键后缀（`navIconHome` 里的 `Home` 小写化），也是 `ThemeConfigViewModel.kt:334-415`
 *   `navIconPath(destination)` 的映射键；
 * - `route` 是主导航 route，`route + ':selected'` 才是上游的选中槽位键；
 * - `label` 取上游 `R.string.home/bookshelf/discovery/rss/my` 的中文原文；
 * - `fallbackIcon` 是本地内置矢量图标，槽位为空时用它。
 */
export interface NavIconSlotInfo {
  slot: string;
  route: string;
  label: string;
  fallbackIcon: AppGlyphName;
  fallbackSelectedIcon: AppGlyphName;
}

/** 五个页面的槽位描述，`fallbackIcon` 取 `pages/Index.ets` 里 `navigationTabIcon()` 的原返回值。 */
export const NAV_ICON_SLOT_INFOS: NavIconSlotInfo[] = [
  {
    slot: 'home', route: 'home', label: '首页',
    fallbackIcon: 'navHomeOutlined', fallbackSelectedIcon: 'navHomeFilled'
  },
  {
    slot: 'bookshelf', route: 'bookshelf', label: '书架',
    fallbackIcon: 'navBookshelfOutlined', fallbackSelectedIcon: 'navBookshelfFilled'
  },
  {
    slot: 'explore', route: 'explore', label: '发现',
    fallbackIcon: 'navExploreOutlined', fallbackSelectedIcon: 'navExploreFilled'
  },
  {
    slot: 'rss', route: 'rss', label: '订阅',
    fallbackIcon: 'navRss', fallbackSelectedIcon: 'navRss'
  },
  {
    slot: 'my', route: 'my', label: '我的',
    fallbackIcon: 'navProfileOutlined', fallbackSelectedIcon: 'navProfileFilled'
  }
];

/** 一个槽位当前配置的路径对（未选中 / 选中）。 */
export interface NavIconPair {
  slot: string;
  normal: string;
  selected: string;
}

/**
 * 主导航图标仓库。
 *
 * 所有方法都是静态的：图标没有跨页面共享的运行时状态，路径由 `ThemeSnapshot` 持有。
 */
export class NavIconLibrary {
  /** 槽位名在 `NAV_ICON_SLOTS` 里的序号；未知槽位返回 -1。 */
  static slotIndex(slot: string): number {
    return NAV_ICON_SLOTS.indexOf(slot);
  }

  /** 图标目录绝对路径，不存在则创建。 */
  static directory(context: Context): string {
    const directory = `${context.filesDir}/${NAV_ICON_DIRECTORY}`;
    try {
      if (!fileIo.accessSync(directory)) {
        fileIo.mkdirSync(directory, true);
      }
    } catch (_) {
      // 目录建不出来时后续复制会抛真实错误，这里不吞掉信息
    }
    return directory;
  }

  /**
   * 把一个已选图片复制进图标目录，返回落盘后的绝对路径。
   *
   * 命名口径同上游 `ThemeConfigRouteScreen.kt:64-70`：按内容摘要命名，同一张图重复选择
   * 命中同一路径，不同图片路径不同。上游注释说明这是为了避免固定文件名导致图片缓存
   * 命中旧图、换图后不即时生效。
   */
  static importIcon(context: Context, sourcePath: string): string {
    const directory = NavIconLibrary.directory(context);
    const size = NavIconLibrary.fileSize(sourcePath);
    if (size <= 0) {
      throw new Error('所选图片为空');
    }
    if (size > MAX_ICON_BYTES) {
      throw new Error('图片超过 8 MB');
    }
    const digest = NavIconLibrary.md5OfFile(sourcePath);
    if (digest.length === 0) {
      throw new Error('无法读取所选图片');
    }
    const target = `${directory}/${digest}.png`;
    if (fileIo.accessSync(target)) {
      return target;
    }
    const source = fileIo.openSync(sourcePath, fileIo.OpenMode.READ_ONLY);
    try {
      fileIo.copyFileSync(source.fd, target);
    } finally {
      fileIo.closeSync(source);
    }
    return target;
  }

  /** 统计某个路径被多少个槽位引用，对齐上游 `navIconFileUsage(path)`。 */
  static usage(paths: string[], path: string): number {
    if (path.length === 0) {
      return 0;
    }
    let count = 0;
    for (const item of paths) {
      if (item === path) {
        count++;
      }
    }
    return count;
  }

  /**
   * 换图后清理旧文件，对齐上游 `ThemeConfigViewModel.kt:352-360`：
   * 旧路径非空、与新路径不同、且不再被任何槽位引用时才删。
   */
  static pruneReplaced(context: Context, allPaths: string[], oldPath: string, newPath: string): void {
    if (oldPath.length === 0 || oldPath === newPath) {
      return;
    }
    if (NavIconLibrary.usage(allPaths, oldPath) > 0) {
      return;
    }
    const directory = `${context.filesDir}/${NAV_ICON_DIRECTORY}`;
    if (!oldPath.startsWith(`${directory}/`)) {
      // 只删自己目录下的文件，防止偏好被外部改写后误删别处文件
      return;
    }
    try {
      if (fileIo.accessSync(oldPath)) {
        fileIo.unlinkSync(oldPath);
      }
    } catch (_) {
      // 删不掉不影响功能，下次换图会再试
    }
  }

  /** 清空所有槽位后清理整个目录里不再被引用的图标。 */
  static pruneAll(context: Context, allPaths: string[]): void {
    const directory = `${context.filesDir}/${NAV_ICON_DIRECTORY}`;
    let names: string[] = [];
    try {
      if (!fileIo.accessSync(directory)) {
        return;
      }
      names = fileIo.listFileSync(directory);
    } catch (_) {
      return;
    }
    for (const name of names) {
      const full = `${directory}/${name}`;
      if (NavIconLibrary.usage(allPaths, full) > 0) {
        continue;
      }
      try {
        fileIo.unlinkSync(full);
      } catch (_) {
        // 同上，删不掉不影响功能
      }
    }
  }

  /** 路径是否是一个真实存在的图标文件，渲染端用它决定画图片还是内置矢量图。 */
  static exists(path: string): boolean {
    if (path.length === 0) {
      return false;
    }
    try {
      return fileIo.accessSync(path);
    } catch (_) {
      return false;
    }
  }

  /** 取文件大小，取不到返回 0。 */
  private static fileSize(path: string): number {
    try {
      return fileIo.statSync(path).size;
    } catch (_) {
      return 0;
    }
  }

  /**
   * 分块算文件内容摘要。
   *
   * 与 `data/AppFontLibrary.ets` 的 `md5OfFile` 同一写法：64 KB 一块喂 `cryptoFramework`，
   * 避免整图读进内存。
   */
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
        if (read <= 0) {
          break;
        }
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
        try {
          fileIo.closeSync(file);
        } catch (_) {
          // 关不掉不影响返回值
        }
      }
    }
  }
}
