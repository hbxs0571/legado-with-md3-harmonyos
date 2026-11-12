import { preferences } from '@kit.ArkData';

/**
 * 书籍详情页的全局开关（批 7 的 `:291`）。
 *
 * 上游把这些放在 `help/config/LocalConfig.kt:144-147`（bookInfoDeleteAlert），
 * 本地单独用一个偏好文件承载：它们不属于书架布局（那份 39 键会进
 * bookshelfLayout.json 备份项），也挂在单本书上。
 */
export interface BookInfoSettings {
  /** 移出书架前是否二次确认；上游默认 true。 */
  deleteAlert: boolean;
}

export const DEFAULT_BOOK_INFO_SETTINGS: BookInfoSettings = {
  deleteAlert: true
};

export class BookInfoSettingsRepository {
  private static readonly preferenceName: string = 'legado_book_info';
  private static readonly keyDeleteAlert: string = 'bookInfoDeleteAlert';
  private static cached: BookInfoSettings = { deleteAlert: true };

  private static publish(settings: BookInfoSettings): void {
    BookInfoSettingsRepository.cached = { deleteAlert: settings.deleteAlert };
  }

  /** 同步取当前缓存；未 load 过时给默认值。 */
  static get(): BookInfoSettings {
    return { deleteAlert: BookInfoSettingsRepository.cached.deleteAlert };
  }

  /** 从偏好读一次并进缓存。 */
  static async load(context: Context): Promise<BookInfoSettings> {
    let deleteAlert = DEFAULT_BOOK_INFO_SETTINGS.deleteAlert;
    try {
      const store = await preferences.getPreferences(context, BookInfoSettingsRepository.preferenceName);
      deleteAlert = store.getSync(BookInfoSettingsRepository.keyDeleteAlert, deleteAlert) as boolean;
    } catch (error) {
      console.error(`书籍详情设置读取失败：${error instanceof Error ? error.message : String(error)}`);
    }
    const settings: BookInfoSettings = { deleteAlert: deleteAlert };
    BookInfoSettingsRepository.publish(settings);
    return settings;
  }

  /** 写回并刷新缓存。 */
  static async save(context: Context, settings: BookInfoSettings): Promise<void> {
    const store = await preferences.getPreferences(context, BookInfoSettingsRepository.preferenceName);
    await store.put(BookInfoSettingsRepository.keyDeleteAlert, settings.deleteAlert);
    await store.flush();
    BookInfoSettingsRepository.publish(settings);
  }
}
