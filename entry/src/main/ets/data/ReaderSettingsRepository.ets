import { preferences } from '@kit.ArkData';

export interface ReaderSettingsSnapshot {
  fontSize: number;
  paperIndex: number;
  dayPaperIndex: number;
  nightPaperIndex: number;
  readerNightMode: boolean;
  shareLayout: boolean;
  showBottomActionText: boolean;
  bottomIconStyle: number;
  bottomItemsPerRow: number;
  bottomRowCount: number;
  bottomActions: ReaderBottomActionConfig[];
  topActions: ReaderBottomActionConfig[];
  progressBehavior: string;
  showQuickActions: boolean;
  autoReadSpeed: number;
}

export interface ReaderBottomActionConfig {
  id: string;
  enabled: boolean;
}

export type ReaderControlKind = 'download' | 'refresh' | 'change_source' | 'audio_download' |
  'source_custom_button' | 'toc_rule' | 'charset' | 'ai_summary' | 'ai_rewrite' | 'more_actions' |
  'search' | 'autoPage' | 'catalog' | 'voice' | 'eye_protection' | 'settings' | 'addBookmark' |
  'theme' | 'prev_chapter' | 'next_chapter' | 'replace' | 'replace_badge' | 'translate' |
  'refresh_current' | 'multi_role_read' | 'multi_role_cast' | 'cast_table' | 'ai_cast';

export interface ReaderActionOption {
  id: ReaderControlKind;
  label: string;
  scopeLabel: string;
  migrated: boolean;
}

// 按 Android ReadMenuActionIds 顺序保留完整配置池；执行状态由 ReaderPage 如实处理。
export const READER_ACTION_OPTIONS: ReaderActionOption[] = [
  { id: 'download', label: '离线缓存', scopeLabel: '仅网络书', migrated: false },
  { id: 'refresh', label: '刷新', scopeLabel: '仅网络书', migrated: false },
  { id: 'change_source', label: '换源', scopeLabel: '仅网络书', migrated: false },
  { id: 'audio_download', label: '听书下载', scopeLabel: '', migrated: false },
  { id: 'source_custom_button', label: '书源自定义按钮', scopeLabel: '仅支持该按钮的网络书', migrated: false },
  { id: 'toc_rule', label: 'TXT目录规则', scopeLabel: '仅本地TXT', migrated: false },
  { id: 'charset', label: '设置编码', scopeLabel: '仅本地书', migrated: true },
  { id: 'ai_summary', label: '章节总结', scopeLabel: '', migrated: false },
  { id: 'ai_rewrite', label: '文本改写', scopeLabel: '', migrated: false },
  { id: 'more_actions', label: '更多操作', scopeLabel: '', migrated: true },
  { id: 'search', label: '全文搜索', scopeLabel: '', migrated: true },
  { id: 'autoPage', label: '自动翻页', scopeLabel: '', migrated: true },
  { id: 'catalog', label: '目录', scopeLabel: '', migrated: true },
  { id: 'voice', label: '朗读', scopeLabel: '', migrated: false },
  { id: 'eye_protection', label: '护眼模式', scopeLabel: '', migrated: false },
  { id: 'settings', label: '设置', scopeLabel: '', migrated: true },
  { id: 'addBookmark', label: '添加书签', scopeLabel: '', migrated: true },
  { id: 'theme', label: '日夜切换', scopeLabel: '', migrated: true },
  { id: 'prev_chapter', label: '上一章', scopeLabel: '', migrated: true },
  { id: 'next_chapter', label: '下一章', scopeLabel: '', migrated: true },
  { id: 'replace', label: '文本处理', scopeLabel: '', migrated: true },
  { id: 'replace_badge', label: '文本处理标记', scopeLabel: '', migrated: false },
  { id: 'translate', label: '翻译', scopeLabel: '', migrated: false },
  { id: 'refresh_current', label: '刷新当前章节', scopeLabel: '', migrated: false },
  { id: 'multi_role_read', label: '多人朗读', scopeLabel: '', migrated: false },
  { id: 'multi_role_cast', label: '多人配音', scopeLabel: '', migrated: false },
  { id: 'cast_table', label: '配音表', scopeLabel: '', migrated: false },
  { id: 'ai_cast', label: 'AI角色配音', scopeLabel: '', migrated: false }
];

const DEFAULT_ENABLED_READER_ACTIONS: string[] = ['search', 'autoPage', 'catalog', 'voice', 'settings'];

export const READER_LOCAL_BOTTOM_ACTION_DEFAULTS: ReaderBottomActionConfig[] = READER_ACTION_OPTIONS.map(
  (option: ReaderActionOption): ReaderBottomActionConfig => ({
    id: option.id,
    enabled: DEFAULT_ENABLED_READER_ACTIONS.includes(option.id)
  })
);

const DEFAULT_ENABLED_READER_TOP_ACTIONS: string[] = [
  'download', 'refresh', 'change_source', 'toc_rule', 'charset', 'more_actions'
];

export function isReaderActionApplicable(id: ReaderControlKind, isLocalBook: boolean, format?: string): boolean {
  if (id === 'source_custom_button') { return false; }
  if (id === 'change_source' || id === 'refresh' || id === 'download') {
    return !isLocalBook;
  }
  if (id === 'toc_rule') { return isLocalBook && format === 'txt'; }
  if (id === 'charset') { return isLocalBook; }
  return true;
}

export function getReaderActionScopeLabel(id: ReaderControlKind): string {
  const option = READER_ACTION_OPTIONS.find((item: ReaderActionOption) => item.id === id);
  return option?.scopeLabel ?? '';
}

export function isReaderActionMigrated(id: ReaderControlKind): boolean {
  const option = READER_ACTION_OPTIONS.find((item: ReaderActionOption) => item.id === id);
  return option?.migrated ?? false;
}

export const READER_LOCAL_TOP_ACTION_DEFAULTS: ReaderBottomActionConfig[] = READER_ACTION_OPTIONS.map(
  (option: ReaderActionOption): ReaderBottomActionConfig => ({
    id: option.id,
    enabled: DEFAULT_ENABLED_READER_TOP_ACTIONS.includes(option.id)
  })
);

export interface ReaderBackgroundStyle {
  name: string;
  dayColor: string;
  nightColor: string;
}

// 来源于 Android 原项目 assets/defaultData/readConfig.json 的六个默认阅读样式。
export const READER_BACKGROUND_STYLES: ReaderBackgroundStyle[] = [
  { name: '微信读书', dayColor: '#FFC0EDC6', nightColor: '#000000' },
  { name: '预设1', dayColor: '#FFFFFF', nightColor: '#000000' },
  { name: '预设2', dayColor: '#DDC090', nightColor: '#3C3F43' },
  { name: '预设3', dayColor: '#C2D8AA', nightColor: '#3C3F43' },
  { name: '预设4', dayColor: '#DBB8E2', nightColor: '#3C3F43' },
  { name: '预设5', dayColor: '#ABCEE0', nightColor: '#3C3F43' }
];

export class ReaderSettingsRepository {
  private static readonly preferenceName: string = 'legado_reader_settings';
  private static saveQueue: Promise<void> = Promise.resolve();

  static async load(context: Context): Promise<ReaderSettingsSnapshot> {
    const defaults: ReaderSettingsSnapshot = {
      fontSize: 20,
      paperIndex: 2,
      dayPaperIndex: 0,
      nightPaperIndex: 0,
      readerNightMode: true,
      shareLayout: false,
      showBottomActionText: false,
      bottomIconStyle: 0,
      bottomItemsPerRow: 5,
      bottomRowCount: 1,
      bottomActions: READER_LOCAL_BOTTOM_ACTION_DEFAULTS.map(
        (item: ReaderBottomActionConfig): ReaderBottomActionConfig => ({ id: item.id, enabled: item.enabled })
      ),
      topActions: READER_LOCAL_TOP_ACTION_DEFAULTS.map(
        (item: ReaderBottomActionConfig): ReaderBottomActionConfig => ({ id: item.id, enabled: item.enabled })
      ),
      progressBehavior: 'page',
      showQuickActions: false,
      autoReadSpeed: 10
    };
    try {
      const store = await preferences.getPreferences(context, ReaderSettingsRepository.preferenceName);
      const fontSizeValue = await store.get('fontSize', defaults.fontSize);
      const paperIndexValue = await store.get('paperIndex', defaults.paperIndex);
      const styleVersionValue = await store.get('paperStyleVersion', 0);
      const dayPaperIndexValue = await store.get('dayPaperIndex', paperIndexValue);
      const nightPaperIndexValue = await store.get('nightPaperIndex', paperIndexValue);
      const nightModeValue = await store.get('readerNightMode', defaults.readerNightMode);
      const shareLayoutValue = await store.get('shareLayout', defaults.shareLayout);
      const bottomActionTextValue = await store.get('showBottomActionText', defaults.showBottomActionText);
      const bottomIconStyleValue = await store.get('bottomIconStyle', defaults.bottomIconStyle);
      const bottomItemsPerRowValue = await store.get('bottomItemsPerRow', defaults.bottomItemsPerRow);
      const bottomRowCountValue = await store.get('bottomRowCount', defaults.bottomRowCount);
      const bottomActionsValue = await store.get('bottomActions', ReaderSettingsRepository.encodeBottomActions(defaults.bottomActions));
      const topActionsValue = await store.get('topActions', ReaderSettingsRepository.encodeTopActions(defaults.topActions));
      const progressBehaviorValue = await store.get('progressBehavior', defaults.progressBehavior);
      const quickActionsValue = await store.get('showQuickActions', defaults.showQuickActions);
      const autoReadSpeedValue = await store.get('autoReadSpeed', defaults.autoReadSpeed);
      const fontSize = typeof fontSizeValue === 'number' && Number.isInteger(fontSizeValue)
        ? Math.max(15, Math.min(30, fontSizeValue)) : defaults.fontSize;
      const storedPaperIndex = typeof paperIndexValue === 'number' && Number.isInteger(paperIndexValue)
        ? Math.max(0, Math.min(5, paperIndexValue)) : defaults.paperIndex;
      const styleVersion = typeof styleVersionValue === 'number' ? styleVersionValue : 0;
      const initialPaperIndex = styleVersion >= 1
        ? storedPaperIndex : ReaderSettingsRepository.migrateLegacyPaperIndex(storedPaperIndex);
      const dayPaperIndex = styleVersion >= 1 && typeof dayPaperIndexValue === 'number' &&
        Number.isInteger(dayPaperIndexValue)
        ? ReaderSettingsRepository.clampStyleIndex(dayPaperIndexValue, initialPaperIndex) : initialPaperIndex;
      const nightPaperIndex = styleVersion >= 1 && typeof nightPaperIndexValue === 'number' &&
        Number.isInteger(nightPaperIndexValue)
        ? ReaderSettingsRepository.clampStyleIndex(nightPaperIndexValue, initialPaperIndex) : initialPaperIndex;
      const readerNightMode = typeof nightModeValue === 'boolean' ? nightModeValue : defaults.readerNightMode;
      const shareLayout = typeof shareLayoutValue === 'boolean' ? shareLayoutValue : defaults.shareLayout;
      const paperIndex = readerNightMode ? nightPaperIndex : dayPaperIndex;
      if (styleVersion < 1) {
        await store.put('paperIndex', paperIndex);
        await store.put('dayPaperIndex', dayPaperIndex);
        await store.put('nightPaperIndex', nightPaperIndex);
        await store.put('readerNightMode', readerNightMode);
        await store.put('shareLayout', shareLayout);
        await store.put('paperStyleVersion', 1);
        await store.flush();
      }
      return {
        fontSize: fontSize,
        paperIndex: paperIndex,
        dayPaperIndex: dayPaperIndex,
        nightPaperIndex: nightPaperIndex,
        readerNightMode: readerNightMode,
        shareLayout: shareLayout,
        showBottomActionText: typeof bottomActionTextValue === 'boolean'
          ? bottomActionTextValue : defaults.showBottomActionText,
        bottomIconStyle: typeof bottomIconStyleValue === 'number'
          ? Math.max(0, Math.min(2, Math.round(bottomIconStyleValue))) : defaults.bottomIconStyle,
        bottomItemsPerRow: typeof bottomItemsPerRowValue === 'number'
          ? Math.max(2, Math.min(8, Math.round(bottomItemsPerRowValue))) : defaults.bottomItemsPerRow,
        bottomRowCount: typeof bottomRowCountValue === 'number'
          ? Math.max(1, Math.min(2, Math.round(bottomRowCountValue))) : defaults.bottomRowCount,
        bottomActions: ReaderSettingsRepository.normalizeBottomActions(
          typeof bottomActionsValue === 'string' ? bottomActionsValue : ''
        ),
        topActions: ReaderSettingsRepository.normalizeTopActions(
          typeof topActionsValue === 'string' ? topActionsValue : ''
        ),
        progressBehavior: progressBehaviorValue === 'chapter' ? 'chapter' : 'page',
        showQuickActions: typeof quickActionsValue === 'boolean' ? quickActionsValue : defaults.showQuickActions,
        autoReadSpeed: typeof autoReadSpeedValue === 'number' && Number.isInteger(autoReadSpeedValue)
          ? Math.max(1, Math.min(120, autoReadSpeedValue)) : defaults.autoReadSpeed
      };
    } catch (_) {
      return defaults;
    }
  }

  static save(context: Context, settings: ReaderSettingsSnapshot): Promise<void> {
    const operation = ReaderSettingsRepository.saveQueue.then(async (): Promise<void> => {
      const store = await preferences.getPreferences(context, ReaderSettingsRepository.preferenceName);
      await store.put('fontSize', Math.max(15, Math.min(30, Math.round(settings.fontSize))));
      await store.put('paperIndex', Math.max(0, Math.min(5, Math.round(settings.paperIndex))));
      await store.put('dayPaperIndex', Math.max(0, Math.min(5, Math.round(settings.dayPaperIndex))));
      await store.put('nightPaperIndex', Math.max(0, Math.min(5, Math.round(settings.nightPaperIndex))));
      await store.put('readerNightMode', settings.readerNightMode);
      await store.put('shareLayout', settings.shareLayout);
      await store.put('showBottomActionText', settings.showBottomActionText);
      await store.put('bottomIconStyle', Math.max(0, Math.min(2, Math.round(settings.bottomIconStyle))));
      await store.put('bottomItemsPerRow', Math.max(2, Math.min(8, Math.round(settings.bottomItemsPerRow))));
      await store.put('bottomRowCount', Math.max(1, Math.min(2, Math.round(settings.bottomRowCount))));
      await store.put('bottomActions', ReaderSettingsRepository.encodeBottomActions(settings.bottomActions));
      await store.put('topActions', ReaderSettingsRepository.encodeTopActions(settings.topActions));
      await store.put('progressBehavior', settings.progressBehavior === 'chapter' ? 'chapter' : 'page');
      await store.put('paperStyleVersion', 1);
      await store.put('showQuickActions', settings.showQuickActions);
      await store.put('autoReadSpeed', Math.max(1, Math.min(120, Math.round(settings.autoReadSpeed))));
      await store.flush();
    });
    ReaderSettingsRepository.saveQueue = operation.then((): void => {}, (_error: Error): void => {});
    return operation;
  }

  private static migrateLegacyPaperIndex(index: number): number {
    if (index === 0) { return 1; }
    if (index === 1) { return 3; }
    if (index === 2) { return 0; }
    return 2;
  }

  private static clampStyleIndex(value: number, fallback: number): number {
    return typeof value === 'number' && Number.isInteger(value) ? Math.max(0, Math.min(5, value)) : fallback;
  }

  private static encodeBottomActions(items: ReaderBottomActionConfig[]): string {
    return ReaderSettingsRepository.encodeActions(items);
  }

  private static encodeTopActions(items: ReaderBottomActionConfig[]): string {
    return ReaderSettingsRepository.encodeActions(items);
  }

  private static encodeActions(items: ReaderBottomActionConfig[]): string {
    return items.map((item: ReaderBottomActionConfig) => `${item.id},${item.enabled}`).join(';');
  }

  private static normalizeBottomActions(value: string): ReaderBottomActionConfig[] {
    return ReaderSettingsRepository.normalizeActions(value, READER_LOCAL_BOTTOM_ACTION_DEFAULTS);
  }

  private static normalizeTopActions(value: string): ReaderBottomActionConfig[] {
    return ReaderSettingsRepository.normalizeActions(value, READER_LOCAL_TOP_ACTION_DEFAULTS);
  }

  private static normalizeActions(value: string, defaults: ReaderBottomActionConfig[]): ReaderBottomActionConfig[] {
    const allowed = defaults.map((item: ReaderBottomActionConfig) => item.id);
    const result: ReaderBottomActionConfig[] = [];
    value.split(';').forEach((entry: string) => {
      const parts = entry.split(',');
      const storedId = parts[0] ?? '';
      const id = storedId === 'moreActions' ? 'more_actions' : storedId;
      if (allowed.includes(id) && !result.some((saved: ReaderBottomActionConfig) => saved.id === id)) {
        result.push({ id: id, enabled: parts[1] === 'true' });
      }
    });
    defaults.forEach((item: ReaderBottomActionConfig) => {
      if (!result.some((saved: ReaderBottomActionConfig) => saved.id === item.id)) {
        result.push({ id: item.id, enabled: item.enabled });
      }
    });
    return result;
  }
}
