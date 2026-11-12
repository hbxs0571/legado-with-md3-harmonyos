import { preferences } from '@kit.ArkData';
import { Context } from '@kit.AbilityKit';

/**
 * 下载与缓存设置（:484）。
 * 上游对应 help/config/LocalConfig.kt 的一组缓存偏好；本地原先 6 个滑块与开关只画不存，
 * 本批补一个 preferences 仓储：启动时读进内存、改动即 flush，杀进程重进值仍在。
 * 偏好名 legado_cache_settings，是纯本地运行参数，不参与 Android 兼容 ZIP 备份。
 */
export interface CacheSettings {
  /** HTTP 缓存时长，秒；0 表示不缓存 */
  httpCacheSeconds: number;
  /** 单章正文预读上限，章 */
  preloadChapterCount: number;
  /** 整本正文内存缓存上限，字节；默认 32MB，与 BookRepository 旧常量同值 */
  bookContentCacheBytes: number;
  /** 封面内存缓存上限，字节 */
  coverCacheBytes: number;
  /** 图片缓存上限，字节 */
  imageCacheBytes: number;
  /** 退出阅读时是否清理章节缓存 */
  clearCacheOnExit: boolean;
  /** 页面原有 6 个滑块的当前值（批9 让它们真的能存） */
  updateSearchThreads: number;
  bookDownloadThreads: number;
  preloadBehind: number;
  preloadAhead: number;
  imageDrawCacheMb: number;
  comicKeepCount: number;
  /** 整本正文内存缓存上限，MB（滑块单位；与 bookContentCacheBytes 互为换算） */
  bookContentCacheMb: number;
  /** 用户代理 */
  userAgent: string;
  /** 是否启用 Cronet 网络组件 */
  cronetEnabled: boolean;
}

export const DEFAULT_CACHE_SETTINGS: CacheSettings = {
  httpCacheSeconds: 0,
  preloadChapterCount: 10,
  bookContentCacheBytes: 32 * 1024 * 1024,
  coverCacheBytes: 0,
  imageCacheBytes: 50 * 1024 * 1024,
  clearCacheOnExit: false,
  updateSearchThreads: 16,
  bookDownloadThreads: 8,
  preloadBehind: 10,
  preloadAhead: 0,
  imageDrawCacheMb: 50,
  comicKeepCount: 0,
  bookContentCacheMb: 32,
  userAgent: '',
  cronetEnabled: false
};

/** 值拷贝，避免 @State / 静态缓存之间共享同一对象引用。 */
export function copyCacheSettings(settings: CacheSettings): CacheSettings {
  return {
    httpCacheSeconds: settings.httpCacheSeconds,
    preloadChapterCount: settings.preloadChapterCount,
    bookContentCacheBytes: settings.bookContentCacheBytes,
    coverCacheBytes: settings.coverCacheBytes,
    imageCacheBytes: settings.imageCacheBytes,
    clearCacheOnExit: settings.clearCacheOnExit,
    updateSearchThreads: settings.updateSearchThreads,
    bookDownloadThreads: settings.bookDownloadThreads,
    preloadBehind: settings.preloadBehind,
    preloadAhead: settings.preloadAhead,
    imageDrawCacheMb: settings.imageDrawCacheMb,
    comicKeepCount: settings.comicKeepCount,
    bookContentCacheMb: settings.bookContentCacheMb,
    userAgent: settings.userAgent,
    cronetEnabled: settings.cronetEnabled
  };
}

export class CacheSettingsRepository {
  private static readonly preferenceName: string = 'legado_cache_settings';
  private static cached: CacheSettings = copyCacheSettings(DEFAULT_CACHE_SETTINGS);

  /** 启动时读一次；BookRepository 的正文缓存上限依赖这里的 bookContentCacheBytes。 */
  static async load(context: Context): Promise<CacheSettings> {
    const store = await preferences.getPreferences(context, CacheSettingsRepository.preferenceName);
    const next = copyCacheSettings(DEFAULT_CACHE_SETTINGS);
    next.httpCacheSeconds = await CacheSettingsRepository.readInt(store, 'httpCacheSeconds', next.httpCacheSeconds);
    next.preloadChapterCount = await CacheSettingsRepository.readInt(store, 'preloadChapterCount', next.preloadChapterCount);
    next.coverCacheBytes = await CacheSettingsRepository.readInt(store, 'coverCacheBytes', next.coverCacheBytes);
    next.imageCacheBytes = await CacheSettingsRepository.readInt(store, 'imageCacheBytes', next.imageCacheBytes);
    next.clearCacheOnExit = await CacheSettingsRepository.readBoolean(store, 'clearCacheOnExit', next.clearCacheOnExit);
    next.updateSearchThreads = await CacheSettingsRepository.readInt(store, 'updateSearchThreads', next.updateSearchThreads);
    next.bookDownloadThreads = await CacheSettingsRepository.readInt(store, 'bookDownloadThreads', next.bookDownloadThreads);
    next.preloadBehind = await CacheSettingsRepository.readInt(store, 'preloadBehind', next.preloadBehind);
    next.preloadAhead = await CacheSettingsRepository.readInt(store, 'preloadAhead', next.preloadAhead);
    next.imageDrawCacheMb = await CacheSettingsRepository.readInt(store, 'imageDrawCacheMb', next.imageDrawCacheMb);
    next.comicKeepCount = await CacheSettingsRepository.readInt(store, 'comicKeepCount', next.comicKeepCount);
    next.bookContentCacheMb = await CacheSettingsRepository.readInt(store, 'bookContentCacheMb', next.bookContentCacheMb);
    next.userAgent = await CacheSettingsRepository.readString(store, 'userAgent', next.userAgent);
    next.cronetEnabled = await CacheSettingsRepository.readBoolean(store, 'cronetEnabled', next.cronetEnabled);
    // MB 是唯一权威滑块值，字节数由它换算；避免两个字段各存一份后不一致。
    next.bookContentCacheBytes = next.bookContentCacheMb * 1024 * 1024;
    CacheSettingsRepository.cached = copyCacheSettings(next);
    return copyCacheSettings(next);
  }

  /** 同步读缓存；BookRepository 的正文缓存判零在这里取上限。 */
  static get(): CacheSettings {
    return copyCacheSettings(CacheSettingsRepository.cached);
  }

  static async save(context: Context, settings: CacheSettings): Promise<void> {
    const next = copyCacheSettings(settings);
    next.bookContentCacheBytes = next.bookContentCacheMb * 1024 * 1024;
    const store = await preferences.getPreferences(context, CacheSettingsRepository.preferenceName);
    await store.put('httpCacheSeconds', next.httpCacheSeconds);
    await store.put('preloadChapterCount', next.preloadChapterCount);
    await store.put('coverCacheBytes', next.coverCacheBytes);
    await store.put('imageCacheBytes', next.imageCacheBytes);
    await store.put('clearCacheOnExit', next.clearCacheOnExit);
    await store.put('updateSearchThreads', next.updateSearchThreads);
    await store.put('bookDownloadThreads', next.bookDownloadThreads);
    await store.put('preloadBehind', next.preloadBehind);
    await store.put('preloadAhead', next.preloadAhead);
    await store.put('imageDrawCacheMb', next.imageDrawCacheMb);
    await store.put('comicKeepCount', next.comicKeepCount);
    await store.put('bookContentCacheMb', next.bookContentCacheMb);
    await store.put('userAgent', next.userAgent);
    await store.put('cronetEnabled', next.cronetEnabled);
    await store.flush();
    CacheSettingsRepository.cached = copyCacheSettings(next);
  }

  private static async readInt(store: preferences.Preferences, key: string, fallback: number): Promise<number> {
    const value = await store.get(key, fallback);
    return typeof value === 'number' && Number.isFinite(value) ? value : fallback;
  }

  private static async readBoolean(store: preferences.Preferences, key: string, fallback: boolean): Promise<boolean> {
    const value = await store.get(key, fallback);
    return value === true;
  }

  private static async readString(store: preferences.Preferences, key: string, fallback: string): Promise<string> {
    const value = await store.get(key, fallback);
    return typeof value === 'string' ? value : fallback;
  }
}
