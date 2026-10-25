import { preferences } from '@kit.ArkData';

export interface ReaderMoreActionConfig {
  id: string;
  enabled: boolean;
}

// 与 Android MoreActionIds 同序，所有原版动作默认启用，运行时再按书籍类型过滤。
export const READER_MORE_ACTION_DEFAULTS: ReaderMoreActionConfig[] = [
  { id: 'source_custom_button', enabled: true },
  { id: 'change_source', enabled: true },
  { id: 'refresh', enabled: true },
  { id: 'download', enabled: true },
  { id: 'audio_download', enabled: true },
  { id: 'edit_content', enabled: true },
  { id: 'add_bookmark', enabled: true },
  { id: 'text_processing', enabled: true },
  { id: 'reverse_content', enabled: true },
  { id: 're_segment', enabled: true },
  { id: 'del_ruby', enabled: true },
  { id: 'del_h', enabled: true },
  { id: 'toc_rule', enabled: true },
  { id: 'charset', enabled: true },
  { id: 'image_style', enabled: true },
  { id: 'page_anim', enabled: true },
  { id: 'simulated_reading', enabled: true },
  { id: 'get_progress', enabled: true },
  { id: 'cover_progress', enabled: true },
  { id: 'highlight_rule', enabled: true },
  { id: 'read_style', enabled: true },
  { id: 'bottom_button_config', enabled: true },
  { id: 'log', enabled: true }
];

export class ReaderMoreActionsRepository {
  private static readonly preferenceName: string = 'legado_reader_more_actions';
  private static saveQueue: Promise<void> = Promise.resolve();

  static async load(context: Context): Promise<ReaderMoreActionConfig[]> {
    try {
      const store = await preferences.getPreferences(context, ReaderMoreActionsRepository.preferenceName);
      const value = await store.get('actions', ReaderMoreActionsRepository.encode(READER_MORE_ACTION_DEFAULTS));
      return ReaderMoreActionsRepository.normalize(typeof value === 'string' ? value : '');
    } catch (_) {
      return READER_MORE_ACTION_DEFAULTS.map((item: ReaderMoreActionConfig): ReaderMoreActionConfig => ({
        id: item.id, enabled: item.enabled
      }));
    }
  }

  static save(context: Context, items: ReaderMoreActionConfig[]): Promise<void> {
    const operation = ReaderMoreActionsRepository.saveQueue.then(async (): Promise<void> => {
      const store = await preferences.getPreferences(context, ReaderMoreActionsRepository.preferenceName);
      await store.put('actions', ReaderMoreActionsRepository.encode(items));
      await store.flush();
    });
    ReaderMoreActionsRepository.saveQueue = operation.then((): void => {}, (_error: Error): void => {});
    return operation;
  }

  private static encode(items: ReaderMoreActionConfig[]): string {
    return items.map((item: ReaderMoreActionConfig) => `${item.id},${item.enabled}`).join(';');
  }

  private static normalize(value: string): ReaderMoreActionConfig[] {
    const result: ReaderMoreActionConfig[] = [];
    const seen: string[] = [];
    const allowed = READER_MORE_ACTION_DEFAULTS.map((item: ReaderMoreActionConfig) => item.id);
    value.split(';').forEach((entry: string) => {
      const parts = entry.split(',');
      const id = parts[0] ?? '';
      if (allowed.includes(id) && !seen.includes(id)) {
        result.push({ id: id, enabled: parts[1] === 'true' });
        seen.push(id);
      }
    });
    READER_MORE_ACTION_DEFAULTS.forEach((item: ReaderMoreActionConfig) => {
      if (!seen.includes(item.id)) {
        result.push({ id: item.id, enabled: item.enabled });
      }
    });
    return result;
  }
}
