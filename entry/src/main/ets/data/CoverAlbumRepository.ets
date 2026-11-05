import { fileIo, picker } from '@kit.CoreFileKit';
import { Context } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { cryptoFramework } from '@kit.CryptoArchitectureKit';

/**
 * 默认封面相册的数据层。
 *
 * 上游主体见 legado-with-MD3 的 data/repository/CoverAlbumRepository.kt（508 行）：
 * 根目录 `<externalFilesDir>/cover_albums`（:49-53），索引文件 `albums.json`（:45），
 * formatVersion = 2（:42），图片落在 `<albumId>/<sha256>.<ext>`（:303-342）。
 * 本地没有 getExternalFilesDir，统一用 `context.filesDir/cover_albums`，
 * 这个目录在应用私有目录里，不在备份的 stagingDirectory 下——按 ZIP-COVER 表头
 * 第 6 档「不进备份」，归档收集只收根层 .json/.xml 文件，目录天然进不了 ZIP，
 * 因此这里不写任何额外的备份排除代码。
 *
 * albums.json 里只存文件名（上游 :357-358），读回时再拼绝对路径并过滤掉
 * 已经不存在的图片（:457-466）。上游写入是「先写 albums.json.tmp 再
 * Files.move(ATOMIC_MOVE, REPLACE_EXISTING)」（:349-380）；本地没有 ATOMIC_MOVE，
 * 用「写 tmp → 删旧索引 → renameSync」近似，注释里保留这处差异。
 *
 * 选择键对齐上游 LocalPreferences.kt:61-63 的三个键，读取时按
 * `selected_cover_album_id ?: selected_light_cover_album_id ?: selected_dark_cover_album_id`
 * 的优先链（CoverAlbumRepository.kt:75-81）；新版本只写第一键（:286-292），
 * 另两键只作为旧数据读入。本地用独立 preferences 文件承载，杀进程重进仍保持。
 */
export interface CoverAlbumImageItem {
  /** 文件名，也是 removeImage 用的 id。 */
  id: string;
  /** 存进 albums.json 的名字，与 id 相同。 */
  fileName: string;
  /** 可直接交给 Image() 的 file:// 绝对路径。 */
  path: string;
}

/** UI 用的相册项，对齐上游 CoverAlbumContract.kt:8-13 的 CoverAlbumItemUi。 */
export interface CoverAlbumItem {
  id: string;
  name: string;
  lightImages: CoverAlbumImageItem[];
  darkImages: CoverAlbumImageItem[];
}

/** albums.json 里的单个相册，字段与上游 StoredCoverAlbum（:495-507）一致。 */
interface StoredCoverAlbum {
  id: string;
  name: string;
  lightImages: string[];
  darkImages: string[];
  /** v1 遗留的单列表字段，读回时并入 lightImages。 */
  images?: string[];
}

/** albums.json 的顶层结构，对齐上游 StoredCoverAlbumIndex（:487-493）。 */
interface StoredCoverAlbumIndex {
  formatVersion: number;
  albums: StoredCoverAlbum[];
}

export class CoverAlbumRepository {
  private static readonly directoryName: string = 'cover_albums';
  private static readonly indexFileName: string = 'albums.json';
  private static readonly selectionPreferenceName: string = 'legado_cover_album_selection';
  private static readonly formatVersion: number = 2;
  private static cachedAlbums: CoverAlbumItem[] = [];
  private static cachedSelection: string = '';
  private static sequence: number = 0;

  /** 同步读缓存：设置页 aboutToAppear 用，避免异步未回来时空白。 */
  static getAlbums(): CoverAlbumItem[] {
    return CoverAlbumRepository.cachedAlbums;
  }

  static getSelection(): string {
    return CoverAlbumRepository.cachedSelection;
  }

  /** 选择 sheet / 管理页卡片的预览图：白天优先，白天没有才用夜间（上游 :75-76、:240-241）。 */
  static previewPath(album: CoverAlbumItem): string {
    if (album.lightImages.length > 0) { return album.lightImages[0].path; }
    if (album.darkImages.length > 0) { return album.darkImages[0].path; }
    return '';
  }

  private static rootDir(context: Context): string {
    return `${context.filesDir}/${CoverAlbumRepository.directoryName}`;
  }

  private static ensureDir(path: string): void {
    try { fileIo.mkdirSync(path, true); }
    catch (error) {
      try { if (fileIo.lstatSync(path).isDirectory()) { return; } } catch (_) {}
      if (error instanceof Error) { throw error; }
      throw new Error('无法创建封面相册目录');
    }
  }

  /** 读原始 JSON 并补齐缺字段；文件不存在或损坏都返回空列表，不让设置页打不开。 */
  private static readStored(context: Context): StoredCoverAlbum[] {
    const index = `${CoverAlbumRepository.rootDir(context)}/${CoverAlbumRepository.indexFileName}`;
    if (!fileIo.accessSync(index)) { return []; }
    try {
      const parsed = JSON.parse(fileIo.readTextSync(index)) as StoredCoverAlbumIndex;
      const raw: StoredCoverAlbum[] = Array.isArray(parsed.albums) ? parsed.albums : [];
      return raw.map((album: StoredCoverAlbum): StoredCoverAlbum => ({
        id: typeof album.id === 'string' ? album.id : '',
        name: typeof album.name === 'string' ? album.name : '',
        lightImages: Array.isArray(album.lightImages) ? album.lightImages : [],
        darkImages: Array.isArray(album.darkImages) ? album.darkImages : [],
        images: Array.isArray(album.images) ? album.images : undefined
      }));
    } catch (error) {
      console.error(`[CoverAlbumRepository] 读取 albums.json 失败: ${error}`);
      return [];
    }
  }

  /** 写索引：tmp + renameSync 近似上游的 ATOMIC_MOVE，崩溃窗口内可能丢索引但图片文件仍在。 */
  private static persist(context: Context, albums: StoredCoverAlbum[]): void {
    const root = CoverAlbumRepository.rootDir(context);
    CoverAlbumRepository.ensureDir(root);
    const index = `${root}/${CoverAlbumRepository.indexFileName}`;
    const tmp = `${root}/${CoverAlbumRepository.indexFileName}.tmp`;
    const payload = JSON.stringify({
      formatVersion: CoverAlbumRepository.formatVersion,
      albums: albums
    } as StoredCoverAlbumIndex);
    const file = fileIo.openSync(tmp,
      fileIo.OpenMode.WRITE_ONLY | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC);
    try {
      fileIo.writeSync(file.fd, payload);
    } finally {
      fileIo.closeSync(file);
    }
    if (fileIo.accessSync(index)) { fileIo.unlinkSync(index); }
    fileIo.renameSync(tmp, index);
  }

  /** 把存的文件名拼成带 path 的 UI 项，并过滤掉磁盘上已不存在的图片。 */
  private static toItem(context: Context, album: StoredCoverAlbum): CoverAlbumItem {
    const dir = `${CoverAlbumRepository.rootDir(context)}/${album.id}`;
    const legacy: string[] = Array.isArray(album.images) ? album.images : [];
    const lightNames: string[] = album.lightImages.concat(legacy);
    const toImages = (names: string[]): CoverAlbumImageItem[] => {
      const items: CoverAlbumImageItem[] = [];
      for (const name of names) {
        const absolute = `${dir}/${name}`;
        if (!fileIo.accessSync(absolute)) { continue; }
        if (items.some((item: CoverAlbumImageItem) => item.id === name)) { continue; }
        items.push({ id: name, fileName: name, path: `file://${absolute}` });
      }
      return items;
    };
    return {
      id: album.id,
      name: album.name,
      lightImages: toImages(lightNames),
      darkImages: toImages(album.darkImages)
    };
  }

  /** 从磁盘重建缓存；每个 CRUD 之后都调一次，保证 UI 拿到的是整份新数组。 */
  static async load(context: Context): Promise<CoverAlbumItem[]> {
    const stored = CoverAlbumRepository.readStored(context);
    const items: CoverAlbumItem[] = [];
    for (const album of stored) {
      items.push(CoverAlbumRepository.toItem(context, album));
    }
    CoverAlbumRepository.cachedAlbums = items;
    return items;
  }

  /** 三键优先链；本地 preferences 用空串表示「未选择」，对应上游 selectAlbum(null)。 */
  static async loadSelection(context: Context): Promise<string> {
    let selected = '';
    try {
      const store = await preferences.getPreferences(
        context, CoverAlbumRepository.selectionPreferenceName);
      const primary = await store.get('selected_cover_album_id', '');
      const light = await store.get('selected_light_cover_album_id', '');
      const dark = await store.get('selected_dark_cover_album_id', '');
      const p = typeof primary === 'string' ? primary : '';
      const l = typeof light === 'string' ? light : '';
      const d = typeof dark === 'string' ? dark : '';
      selected = p.length > 0 ? p : (l.length > 0 ? l : d);
    } catch (error) {
      console.error(`[CoverAlbumRepository] 读取相册选择失败: ${error}`);
    }
    CoverAlbumRepository.cachedSelection = selected;
    return selected;
  }

  /** 只写第一键（上游 persistSelection :286-292）；空串等于上游的 null。 */
  static async setSelection(context: Context, albumId: string): Promise<void> {
    const store = await preferences.getPreferences(
      context, CoverAlbumRepository.selectionPreferenceName);
    await store.put('selected_cover_album_id', albumId);
    await store.flush();
    CoverAlbumRepository.cachedSelection = albumId;
  }

  /** 新建相册（上游 createAlbum :98 用 UUID；本地无 UUID 能力，用时间戳+序号，F9）。 */
  static async createAlbum(context: Context, name: string): Promise<string> {
    const albums = CoverAlbumRepository.readStored(context);
    const id = `album-${Date.now()}-${CoverAlbumRepository.sequence++}`;
    albums.push({ id: id, name: name, lightImages: [], darkImages: [] });
    CoverAlbumRepository.persist(context, albums);
    CoverAlbumRepository.ensureDir(`${CoverAlbumRepository.rootDir(context)}/${id}`);
    await CoverAlbumRepository.load(context);
    return id;
  }

  /** 改名（上游 renameAlbum :135）；与新建共用同一个名字输入框的保存动作。 */
  static async renameAlbum(context: Context, albumId: string, name: string): Promise<void> {
    const albums = CoverAlbumRepository.readStored(context);
    const album = albums.find((item: StoredCoverAlbum) => item.id === albumId);
    if (album === undefined) { return; }
    album.name = name;
    CoverAlbumRepository.persist(context, albums);
    await CoverAlbumRepository.load(context);
  }

  /** 删相册（上游 deleteAlbum :148）：删目录、删图片，若它是当前选中则清空选择。 */
  static async deleteAlbum(context: Context, albumId: string): Promise<void> {
    const albums = CoverAlbumRepository.readStored(context)
      .filter((item: StoredCoverAlbum) => item.id !== albumId);
    CoverAlbumRepository.persist(context, albums);
    const dir = `${CoverAlbumRepository.rootDir(context)}/${albumId}`;
    if (fileIo.accessSync(dir)) {
      for (const name of fileIo.listFileSync(dir)) {
        const path = `${dir}/${name}`;
        if (fileIo.accessSync(path)) { fileIo.unlinkSync(path); }
      }
      fileIo.rmdirSync(dir);
    }
    if (CoverAlbumRepository.cachedSelection === albumId) {
      await CoverAlbumRepository.setSelection(context, '');
    }
    await CoverAlbumRepository.load(context);
  }

  /** 图片扩展名：取 URI 最后一段，非法字符回落 img（上游 :303-342 的正则口径）。 */
  private static extensionOf(uri: string): string {
    const clean = uri.split('?')[0];
    const dot = clean.lastIndexOf('.');
    if (dot < 0) { return 'img'; }
    const ext = clean.substring(dot + 1).toLowerCase();
    return /^[a-z0-9]{1,8}$/.test(ext) ? ext : 'img';
  }

  /** 内容哈希作文件名：与上游 SHA-256 hex（:303-342）一致，同图加两次只留一份。 */
  private static hashFile(path: string): string {
    const file = fileIo.openSync(path, fileIo.OpenMode.READ_ONLY);
    try {
      const size = fileIo.statSync(path).size;
      const buffer = new ArrayBuffer(size);
      if (size > 0) { fileIo.readSync(file.fd, buffer); }
      const md = cryptoFramework.createMd('SHA256');
      md.updateSync({ data: new Uint8Array(buffer) });
      const digest = md.digestSync();
      let hex = '';
      for (let index = 0; index < digest.data.length; index++) {
        hex += (digest.data[index] as number).toString(16).padStart(2, '0');
      }
      return hex;
    } catch (error) {
      // 该设备不支持 SHA256 时退回唯一串，避免整个添加流程崩掉；此时幂等性不成立，但文件名仍唯一。
      console.error(`[CoverAlbumRepository] 计算图片摘要失败: ${error}`);
      return `file-${Date.now()}-${CoverAlbumRepository.sequence++}`;
    } finally {
      fileIo.closeSync(file);
    }
  }

  /**
   * 添加图片（上游 addImages :160）：picker 多选 → 复制进 `<albumId>/` → 内容哈希命名
   * → 追加到当前页签那一套（isDark 决定）。返回实际新增的文件数。
   */
  static async addImages(context: Context, albumId: string, isDark: boolean): Promise<number> {
    const options = new picker.DocumentSelectOptions();
    options.fileSuffixFilters = ['图片|.png', '图片|.jpg', '图片|.jpeg', '图片|.webp', '图片|.bmp'];
    options.maxSelectNumber = 9;
    const uris = await new picker.DocumentViewPicker(context).select(options);
    if (uris.length === 0) { return 0; }

    const dir = `${CoverAlbumRepository.rootDir(context)}/${albumId}`;
    CoverAlbumRepository.ensureDir(dir);
    const names: string[] = [];
    for (const uri of uris) {
      const source = fileIo.openSync(uri, fileIo.OpenMode.READ_ONLY);
      try {
        const ext = CoverAlbumRepository.extensionOf(uri);
        const tmp = `${dir}/.${Date.now()}-${CoverAlbumRepository.sequence++}.tmp`;
        fileIo.copyFileSync(source.fd, tmp);
        const fileName = `${CoverAlbumRepository.hashFile(tmp)}.${ext}`;
        const target = `${dir}/${fileName}`;
        if (fileIo.accessSync(target)) {
          fileIo.unlinkSync(tmp);
        } else {
          fileIo.renameSync(tmp, target);
        }
        if (!names.includes(fileName)) { names.push(fileName); }
      } finally {
        fileIo.closeSync(source);
      }
    }

    const albums = CoverAlbumRepository.readStored(context);
    const album = albums.find((item: StoredCoverAlbum) => item.id === albumId);
    if (album === undefined) { return 0; }
    const target = isDark ? album.darkImages : album.lightImages;
    let added = 0;
    for (const name of names) {
      if (!target.includes(name)) { target.push(name); added++; }
    }
    CoverAlbumRepository.persist(context, albums);
    await CoverAlbumRepository.load(context);
    return added;
  }

  /** 删除单图（上游 removeImage :189）：不弹确认，直接删索引里的项与磁盘文件。 */
  static async removeImage(
    context: Context, albumId: string, isDark: boolean, imageId: string
  ): Promise<void> {
    const albums = CoverAlbumRepository.readStored(context);
    const album = albums.find((item: StoredCoverAlbum) => item.id === albumId);
    if (album === undefined) { return; }
    if (isDark) {
      album.darkImages = album.darkImages.filter((name: string) => name !== imageId);
    } else {
      album.lightImages = album.lightImages.filter((name: string) => name !== imageId);
    }
    CoverAlbumRepository.persist(context, albums);
    const path = `${CoverAlbumRepository.rootDir(context)}/${albumId}/${imageId}`;
    if (fileIo.accessSync(path)) { fileIo.unlinkSync(path); }
    await CoverAlbumRepository.load(context);
  }
}
