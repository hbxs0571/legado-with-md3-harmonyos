import { preferences } from '@kit.ArkData';

export interface ReaderInfoSettings {
  headerMode: number;
  footerMode: number;
  showHeaderLine: boolean;
  showFooterLine: boolean;
  tipHeaderLeft: number;
  tipHeaderMiddle: number;
  tipHeaderRight: number;
  tipFooterLeft: number;
  tipFooterMiddle: number;
  tipFooterRight: number;
  customTipHeaderLeft: string;
  customTipHeaderMiddle: string;
  customTipHeaderRight: string;
  customTipFooterLeft: string;
  customTipFooterMiddle: string;
  customTipFooterRight: string;
  headerFont: string;
  footerFont: string;
  headerFontSize: number;
  footerFontSize: number;
  applyHeaderStyle: boolean;
  tipHeaderColor: number;
  tipHeaderColorNight: number;
  tipFooterColor: number;
  tipFooterColorNight: number;
  tipDividerColor: number;
}

export interface ReaderInfoSettingsUpdate {
  headerMode?: number;
  footerMode?: number;
  showHeaderLine?: boolean;
  showFooterLine?: boolean;
  tipHeaderLeft?: number;
  tipHeaderMiddle?: number;
  tipHeaderRight?: number;
  tipFooterLeft?: number;
  tipFooterMiddle?: number;
  tipFooterRight?: number;
  customTipHeaderLeft?: string;
  customTipHeaderMiddle?: string;
  customTipHeaderRight?: string;
  customTipFooterLeft?: string;
  customTipFooterMiddle?: string;
  customTipFooterRight?: string;
  headerFont?: string;
  footerFont?: string;
  headerFontSize?: number;
  footerFontSize?: number;
  applyHeaderStyle?: boolean;
  tipHeaderColor?: number;
  tipHeaderColorNight?: number;
  tipFooterColor?: number;
  tipFooterColorNight?: number;
  tipDividerColor?: number;
}

export function updateReaderInfoSettings(
  current: ReaderInfoSettings,
  update: ReaderInfoSettingsUpdate
): ReaderInfoSettings {
  return {
    headerMode: update.headerMode ?? current.headerMode,
    footerMode: update.footerMode ?? current.footerMode,
    showHeaderLine: update.showHeaderLine ?? current.showHeaderLine,
    showFooterLine: update.showFooterLine ?? current.showFooterLine,
    tipHeaderLeft: update.tipHeaderLeft ?? current.tipHeaderLeft,
    tipHeaderMiddle: update.tipHeaderMiddle ?? current.tipHeaderMiddle,
    tipHeaderRight: update.tipHeaderRight ?? current.tipHeaderRight,
    tipFooterLeft: update.tipFooterLeft ?? current.tipFooterLeft,
    tipFooterMiddle: update.tipFooterMiddle ?? current.tipFooterMiddle,
    tipFooterRight: update.tipFooterRight ?? current.tipFooterRight,
    customTipHeaderLeft: update.customTipHeaderLeft ?? current.customTipHeaderLeft,
    customTipHeaderMiddle: update.customTipHeaderMiddle ?? current.customTipHeaderMiddle,
    customTipHeaderRight: update.customTipHeaderRight ?? current.customTipHeaderRight,
    customTipFooterLeft: update.customTipFooterLeft ?? current.customTipFooterLeft,
    customTipFooterMiddle: update.customTipFooterMiddle ?? current.customTipFooterMiddle,
    customTipFooterRight: update.customTipFooterRight ?? current.customTipFooterRight,
    headerFont: update.headerFont ?? current.headerFont,
    footerFont: update.footerFont ?? current.footerFont,
    headerFontSize: update.headerFontSize ?? current.headerFontSize,
    footerFontSize: update.footerFontSize ?? current.footerFontSize,
    applyHeaderStyle: update.applyHeaderStyle ?? current.applyHeaderStyle,
    tipHeaderColor: update.tipHeaderColor ?? current.tipHeaderColor,
    tipHeaderColorNight: update.tipHeaderColorNight ?? current.tipHeaderColorNight,
    tipFooterColor: update.tipFooterColor ?? current.tipFooterColor,
    tipFooterColorNight: update.tipFooterColorNight ?? current.tipFooterColorNight,
    tipDividerColor: update.tipDividerColor ?? current.tipDividerColor
  };
}

export function copyReaderInfoSettings(current: ReaderInfoSettings): ReaderInfoSettings {
  return updateReaderInfoSettings(current, {});
}

export interface ReaderSettingsSnapshot extends ReaderInfoSettings {
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
  tocUseReplace: boolean;
  tocShowWordCount: boolean;
  clickImageBehavior: string;
  showQuickActions: boolean;
  autoReadSpeed: number;
  pageAnimation: number;
  animationSpeed: number;
}

export interface ReaderBottomActionConfig {
  id: string;
  enabled: boolean;
}

export const DEFAULT_READER_INFO_SETTINGS: ReaderInfoSettings = {
  headerMode: 0,
  footerMode: 0,
  showHeaderLine: false,
  showFooterLine: true,
  tipHeaderLeft: 2,
  tipHeaderMiddle: 0,
  tipHeaderRight: 3,
  tipFooterLeft: 1,
  tipFooterMiddle: 0,
  tipFooterRight: 6,
  customTipHeaderLeft: '',
  customTipHeaderMiddle: '',
  customTipHeaderRight: '',
  customTipFooterLeft: '',
  customTipFooterMiddle: '',
  customTipFooterRight: '',
  headerFont: '',
  footerFont: '',
  headerFontSize: 12,
  footerFontSize: 12,
  applyHeaderStyle: true,
  tipHeaderColor: 0,
  tipHeaderColorNight: 0,
  tipFooterColor: 0,
  tipFooterColorNight: 0,
  tipDividerColor: -1
};

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
      headerMode: DEFAULT_READER_INFO_SETTINGS.headerMode,
      footerMode: DEFAULT_READER_INFO_SETTINGS.footerMode,
      showHeaderLine: DEFAULT_READER_INFO_SETTINGS.showHeaderLine,
      showFooterLine: DEFAULT_READER_INFO_SETTINGS.showFooterLine,
      tipHeaderLeft: DEFAULT_READER_INFO_SETTINGS.tipHeaderLeft,
      tipHeaderMiddle: DEFAULT_READER_INFO_SETTINGS.tipHeaderMiddle,
      tipHeaderRight: DEFAULT_READER_INFO_SETTINGS.tipHeaderRight,
      tipFooterLeft: DEFAULT_READER_INFO_SETTINGS.tipFooterLeft,
      tipFooterMiddle: DEFAULT_READER_INFO_SETTINGS.tipFooterMiddle,
      tipFooterRight: DEFAULT_READER_INFO_SETTINGS.tipFooterRight,
      customTipHeaderLeft: DEFAULT_READER_INFO_SETTINGS.customTipHeaderLeft,
      customTipHeaderMiddle: DEFAULT_READER_INFO_SETTINGS.customTipHeaderMiddle,
      customTipHeaderRight: DEFAULT_READER_INFO_SETTINGS.customTipHeaderRight,
      customTipFooterLeft: DEFAULT_READER_INFO_SETTINGS.customTipFooterLeft,
      customTipFooterMiddle: DEFAULT_READER_INFO_SETTINGS.customTipFooterMiddle,
      customTipFooterRight: DEFAULT_READER_INFO_SETTINGS.customTipFooterRight,
      headerFont: DEFAULT_READER_INFO_SETTINGS.headerFont,
      footerFont: DEFAULT_READER_INFO_SETTINGS.footerFont,
      headerFontSize: DEFAULT_READER_INFO_SETTINGS.headerFontSize,
      footerFontSize: DEFAULT_READER_INFO_SETTINGS.footerFontSize,
      applyHeaderStyle: DEFAULT_READER_INFO_SETTINGS.applyHeaderStyle,
      tipHeaderColor: DEFAULT_READER_INFO_SETTINGS.tipHeaderColor,
      tipHeaderColorNight: DEFAULT_READER_INFO_SETTINGS.tipHeaderColorNight,
      tipFooterColor: DEFAULT_READER_INFO_SETTINGS.tipFooterColor,
      tipFooterColorNight: DEFAULT_READER_INFO_SETTINGS.tipFooterColorNight,
      tipDividerColor: DEFAULT_READER_INFO_SETTINGS.tipDividerColor,
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
      tocUseReplace: false,
      tocShowWordCount: true,
      clickImageBehavior: '2',
      showQuickActions: false,
      autoReadSpeed: 10,
      pageAnimation: 0,
      animationSpeed: 2
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
      const tocUseReplaceValue = await store.get('tocUiUseReplace', defaults.tocUseReplace);
      const tocShowWordCountValue = await store.get('tocCountWords', defaults.tocShowWordCount);
      const clickImageBehaviorValue = await store.get('clickImgWay', defaults.clickImageBehavior);
      const quickActionsValue = await store.get('showQuickActions', defaults.showQuickActions);
      const autoReadSpeedValue = await store.get('autoReadSpeed', defaults.autoReadSpeed);
      const pageAnimationValue = await store.get('pageAnimation', defaults.pageAnimation);
      const animationSpeedValue = await store.get('animationSpeed', defaults.animationSpeed);
      const headerModeValue = await store.get('headerMode', defaults.headerMode);
      const footerModeValue = await store.get('footerMode', defaults.footerMode);
      const showHeaderLineValue = await store.get('showHeaderLine', defaults.showHeaderLine);
      const showFooterLineValue = await store.get('showFooterLine', defaults.showFooterLine);
      const tipHeaderLeftValue = await store.get('tipHeaderLeft', defaults.tipHeaderLeft);
      const tipHeaderMiddleValue = await store.get('tipHeaderMiddle', defaults.tipHeaderMiddle);
      const tipHeaderRightValue = await store.get('tipHeaderRight', defaults.tipHeaderRight);
      const tipFooterLeftValue = await store.get('tipFooterLeft', defaults.tipFooterLeft);
      const tipFooterMiddleValue = await store.get('tipFooterMiddle', defaults.tipFooterMiddle);
      const tipFooterRightValue = await store.get('tipFooterRight', defaults.tipFooterRight);
      const customTipHeaderLeftValue = await store.get('customTipHeaderLeft', defaults.customTipHeaderLeft);
      const customTipHeaderMiddleValue = await store.get('customTipHeaderMiddle', defaults.customTipHeaderMiddle);
      const customTipHeaderRightValue = await store.get('customTipHeaderRight', defaults.customTipHeaderRight);
      const customTipFooterLeftValue = await store.get('customTipFooterLeft', defaults.customTipFooterLeft);
      const customTipFooterMiddleValue = await store.get('customTipFooterMiddle', defaults.customTipFooterMiddle);
      const customTipFooterRightValue = await store.get('customTipFooterRight', defaults.customTipFooterRight);
      const headerFontValue = await store.get('headerFont', defaults.headerFont);
      const footerFontValue = await store.get('footerFont', defaults.footerFont);
      const headerFontSizeValue = await store.get('headerFontSize', defaults.headerFontSize);
      const footerFontSizeValue = await store.get('footerFontSize', defaults.footerFontSize);
      const applyHeaderStyleValue = await store.get('applyHeaderStyle', defaults.applyHeaderStyle);
      const tipHeaderColorValue = await store.get('tipHeaderColor', defaults.tipHeaderColor);
      const tipHeaderColorNightValue = await store.get('tipHeaderColorNight', defaults.tipHeaderColorNight);
      const tipFooterColorValue = await store.get('tipFooterColor', defaults.tipFooterColor);
      const tipFooterColorNightValue = await store.get('tipFooterColorNight', defaults.tipFooterColorNight);
      const tipDividerColorValue = await store.get('tipDividerColor', defaults.tipDividerColor);
      const fontSize = typeof fontSizeValue === 'number' && Number.isInteger(fontSizeValue)
        ? Math.max(5, Math.min(50, fontSizeValue)) : defaults.fontSize;
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
        headerMode: typeof headerModeValue === 'number' && Number.isInteger(headerModeValue)
          ? Math.max(0, Math.min(2, headerModeValue)) : defaults.headerMode,
        footerMode: typeof footerModeValue === 'number' && Number.isInteger(footerModeValue)
          ? Math.max(0, Math.min(1, footerModeValue)) : defaults.footerMode,
        showHeaderLine: typeof showHeaderLineValue === 'boolean' ? showHeaderLineValue : defaults.showHeaderLine,
        showFooterLine: typeof showFooterLineValue === 'boolean' ? showFooterLineValue : defaults.showFooterLine,
        tipHeaderLeft: ReaderSettingsRepository.normalizeTipValue(tipHeaderLeftValue, defaults.tipHeaderLeft),
        tipHeaderMiddle: ReaderSettingsRepository.normalizeTipValue(tipHeaderMiddleValue, defaults.tipHeaderMiddle),
        tipHeaderRight: ReaderSettingsRepository.normalizeTipValue(tipHeaderRightValue, defaults.tipHeaderRight),
        tipFooterLeft: ReaderSettingsRepository.normalizeTipValue(tipFooterLeftValue, defaults.tipFooterLeft),
        tipFooterMiddle: ReaderSettingsRepository.normalizeTipValue(tipFooterMiddleValue, defaults.tipFooterMiddle),
        tipFooterRight: ReaderSettingsRepository.normalizeTipValue(tipFooterRightValue, defaults.tipFooterRight),
        customTipHeaderLeft: typeof customTipHeaderLeftValue === 'string' ? customTipHeaderLeftValue : defaults.customTipHeaderLeft,
        customTipHeaderMiddle: typeof customTipHeaderMiddleValue === 'string' ? customTipHeaderMiddleValue : defaults.customTipHeaderMiddle,
        customTipHeaderRight: typeof customTipHeaderRightValue === 'string' ? customTipHeaderRightValue : defaults.customTipHeaderRight,
        customTipFooterLeft: typeof customTipFooterLeftValue === 'string' ? customTipFooterLeftValue : defaults.customTipFooterLeft,
        customTipFooterMiddle: typeof customTipFooterMiddleValue === 'string' ? customTipFooterMiddleValue : defaults.customTipFooterMiddle,
        customTipFooterRight: typeof customTipFooterRightValue === 'string' ? customTipFooterRightValue : defaults.customTipFooterRight,
        headerFont: typeof headerFontValue === 'string' ? headerFontValue : defaults.headerFont,
        footerFont: typeof footerFontValue === 'string' ? footerFontValue : defaults.footerFont,
        headerFontSize: ReaderSettingsRepository.normalizeInteger(headerFontSizeValue, 0, 100, defaults.headerFontSize),
        footerFontSize: ReaderSettingsRepository.normalizeInteger(footerFontSizeValue, 0, 100, defaults.footerFontSize),
        applyHeaderStyle: typeof applyHeaderStyleValue === 'boolean' ? applyHeaderStyleValue : defaults.applyHeaderStyle,
        tipHeaderColor: ReaderSettingsRepository.normalizeColor(tipHeaderColorValue, defaults.tipHeaderColor),
        tipHeaderColorNight: ReaderSettingsRepository.normalizeColor(tipHeaderColorNightValue, defaults.tipHeaderColorNight),
        tipFooterColor: ReaderSettingsRepository.normalizeColor(tipFooterColorValue, defaults.tipFooterColor),
        tipFooterColorNight: ReaderSettingsRepository.normalizeColor(tipFooterColorNightValue, defaults.tipFooterColorNight),
        tipDividerColor: ReaderSettingsRepository.normalizeColor(tipDividerColorValue, defaults.tipDividerColor),
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
        tocUseReplace: typeof tocUseReplaceValue === 'boolean' ? tocUseReplaceValue : defaults.tocUseReplace,
        tocShowWordCount: typeof tocShowWordCountValue === 'boolean'
          ? tocShowWordCountValue : defaults.tocShowWordCount,
        clickImageBehavior: typeof clickImageBehaviorValue === 'string' &&
          ['0', '1', '2', '3', '4'].includes(clickImageBehaviorValue)
          ? clickImageBehaviorValue : defaults.clickImageBehavior,
        showQuickActions: typeof quickActionsValue === 'boolean' ? quickActionsValue : defaults.showQuickActions,
        autoReadSpeed: typeof autoReadSpeedValue === 'number' && Number.isInteger(autoReadSpeedValue)
          ? Math.max(1, Math.min(120, autoReadSpeedValue)) : defaults.autoReadSpeed,
        pageAnimation: typeof pageAnimationValue === 'number' && Number.isInteger(pageAnimationValue)
          ? Math.max(0, Math.min(5, pageAnimationValue)) : defaults.pageAnimation,
        animationSpeed: typeof animationSpeedValue === 'number' && Number.isInteger(animationSpeedValue)
          ? Math.max(0, Math.min(3, animationSpeedValue)) : defaults.animationSpeed
      };
    } catch (_) {
      return defaults;
    }
  }

  static save(context: Context, settings: ReaderSettingsSnapshot): Promise<void> {
    const operation = ReaderSettingsRepository.saveQueue.then(async (): Promise<void> => {
      const store = await preferences.getPreferences(context, ReaderSettingsRepository.preferenceName);
      await store.put('fontSize', Math.max(5, Math.min(50, Math.round(settings.fontSize))));
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
      await store.put('tocUiUseReplace', settings.tocUseReplace);
      await store.put('tocCountWords', settings.tocShowWordCount);
      await store.put('clickImgWay', ['0', '1', '2', '3', '4'].includes(settings.clickImageBehavior)
        ? settings.clickImageBehavior : '2');
      await store.put('paperStyleVersion', 1);
      await store.put('showQuickActions', settings.showQuickActions);
      await store.put('autoReadSpeed', Math.max(1, Math.min(120, Math.round(settings.autoReadSpeed))));
      await store.put('pageAnimation', Math.max(0, Math.min(5, Math.round(settings.pageAnimation))));
      await store.put('animationSpeed', Math.max(0, Math.min(3, Math.round(settings.animationSpeed))));
      await store.put('headerMode', Math.max(0, Math.min(2, Math.round(settings.headerMode))));
      await store.put('footerMode', Math.max(0, Math.min(1, Math.round(settings.footerMode))));
      await store.put('showHeaderLine', settings.showHeaderLine);
      await store.put('showFooterLine', settings.showFooterLine);
      await store.put('tipHeaderLeft', settings.tipHeaderLeft);
      await store.put('tipHeaderMiddle', settings.tipHeaderMiddle);
      await store.put('tipHeaderRight', settings.tipHeaderRight);
      await store.put('tipFooterLeft', settings.tipFooterLeft);
      await store.put('tipFooterMiddle', settings.tipFooterMiddle);
      await store.put('tipFooterRight', settings.tipFooterRight);
      await store.put('customTipHeaderLeft', settings.customTipHeaderLeft);
      await store.put('customTipHeaderMiddle', settings.customTipHeaderMiddle);
      await store.put('customTipHeaderRight', settings.customTipHeaderRight);
      await store.put('customTipFooterLeft', settings.customTipFooterLeft);
      await store.put('customTipFooterMiddle', settings.customTipFooterMiddle);
      await store.put('customTipFooterRight', settings.customTipFooterRight);
      await store.put('headerFont', settings.headerFont);
      await store.put('footerFont', settings.footerFont);
      await store.put('headerFontSize', Math.max(0, Math.min(100, Math.round(settings.headerFontSize))));
      await store.put('footerFontSize', Math.max(0, Math.min(100, Math.round(settings.footerFontSize))));
      await store.put('applyHeaderStyle', settings.applyHeaderStyle);
      await store.put('tipHeaderColor', settings.tipHeaderColor);
      await store.put('tipHeaderColorNight', settings.tipHeaderColorNight);
      await store.put('tipFooterColor', settings.tipFooterColor);
      await store.put('tipFooterColorNight', settings.tipFooterColorNight);
      await store.put('tipDividerColor', settings.tipDividerColor);
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

  private static normalizeTipValue(value: number | boolean | string | bigint | Uint8Array | object, fallback: number): number {
    return typeof value === 'number' && Number.isInteger(value) ? Math.max(0, Math.min(20, value)) : fallback;
  }

  private static normalizeInteger(value: number | boolean | string | bigint | Uint8Array | object, minimum: number, maximum: number, fallback: number): number {
    return typeof value === 'number' && Number.isInteger(value)
      ? Math.max(minimum, Math.min(maximum, value)) : fallback;
  }

  private static normalizeColor(value: number | boolean | string | bigint | Uint8Array | object, fallback: number): number {
    return typeof value === 'number' && Number.isInteger(value) ? value : fallback;
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
