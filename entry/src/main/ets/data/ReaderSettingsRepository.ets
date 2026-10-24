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

export const READER_LOCAL_BOTTOM_ACTION_DEFAULTS: ReaderBottomActionConfig[] = [
  { id: 'search', enabled: true },
  { id: 'autoPage', enabled: true },
  { id: 'catalog', enabled: true },
  { id: 'voice', enabled: true },
  { id: 'settings', enabled: true }
];

export const READER_LOCAL_TOP_ACTION_DEFAULTS: ReaderBottomActionConfig[] = [
  { id: 'charset', enabled: true },
  { id: 'moreActions', enabled: true }
];

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
      const id = parts[0] ?? '';
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
