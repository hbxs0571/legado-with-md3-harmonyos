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

export interface ReaderPaddingSettings {
  paddingTop: number;
  paddingBottom: number;
  paddingLeft: number;
  paddingRight: number;
  headerPaddingTop: number;
  headerPaddingBottom: number;
  headerPaddingLeft: number;
  headerPaddingRight: number;
  footerPaddingTop: number;
  footerPaddingBottom: number;
  footerPaddingLeft: number;
  footerPaddingRight: number;
}

export const DEFAULT_READER_PADDING_SETTINGS: ReaderPaddingSettings = {
  paddingTop: 6, paddingBottom: 6, paddingLeft: 16, paddingRight: 16,
  headerPaddingTop: 0, headerPaddingBottom: 0, headerPaddingLeft: 16, headerPaddingRight: 16,
  footerPaddingTop: 6, footerPaddingBottom: 6, footerPaddingLeft: 16, footerPaddingRight: 16
};

export function copyReaderPaddingSettings(settings: ReaderPaddingSettings): ReaderPaddingSettings {
  return {
    paddingTop: settings.paddingTop,
    paddingBottom: settings.paddingBottom,
    paddingLeft: settings.paddingLeft,
    paddingRight: settings.paddingRight,
    headerPaddingTop: settings.headerPaddingTop,
    headerPaddingBottom: settings.headerPaddingBottom,
    headerPaddingLeft: settings.headerPaddingLeft,
    headerPaddingRight: settings.headerPaddingRight,
    footerPaddingTop: settings.footerPaddingTop,
    footerPaddingBottom: settings.footerPaddingBottom,
    footerPaddingLeft: settings.footerPaddingLeft,
    footerPaddingRight: settings.footerPaddingRight
  };
}

export interface ReaderSettingsSnapshot extends ReaderInfoSettings {
  paddingSettings: ReaderPaddingSettings;
  fontSize: number;
  paragraphSpacing: number;
  lineSpacing: number;
  letterSpacing: number;
  paragraphIndent: string;
  textFont: string;
  titleFont: string;
  systemTypefaces: number;
  textItalic: boolean;
  textBold: number;
  textShadow: boolean;
  shadowRadius: number;
  shadowDx: number;
  shadowDy: number;
  textShadowColor: string;
  textShadowColorN: string;
  underline: boolean;
  dottedLine: boolean;
  underlineColor: string;
  underlineColorNight: string;
  underlineHeight: number;
  textFullJustify: boolean;
  textBottomJustify: boolean;
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
  clickRegionActions: string[];
  hideStatusBar: boolean;
  hideNavigationBar: boolean;
  showQuickActions: boolean;
  autoReadSpeed: number;
  pageAnimation: number;
  animationSpeed: number;
  screenOrientation: string;
  keepLight: string;
  volumeKeyPage: boolean;
  keyPageOnLongPress: boolean;
  noAnimScrollPage: boolean;
  readingAnchorEnabled: boolean;
  swipeToAddBookmark: boolean;
  /** 阅读页书签角标宽度（dp）；0 表示不显示角标，对齐上游 `bookmarkBadgeSize`。 */
  bookmarkBadgeSize: number;
  /** 自定义书签角标图片在应用私有目录的路径；空串表示用默认黄色丝带，对齐上游 `bookmarkBadgeImage`。 */
  bookmarkBadgeImage: string;
  selectText: boolean;
  maxLengthWithNoToc: number;
  eyeProtectionEnabled: boolean;
  eyeProtectionAutoNight: boolean;
  eyeProtectionSchedule: boolean;
  eyeProtectionIntensity: number;
  eyeProtectionStartTime: string;
  eyeProtectionEndTime: string;
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

export const READER_CLICK_REGION_ACTIONS: string[] = [
  '无操作', '菜单', '下一页', '上一页', '下一章', '上一章', '朗读上一段', '朗读下一段',
  '添加书签', '编辑内容', '替换(启用/禁用)', '目录', '全文搜索', '同步阅读进度', '朗读暂停/继续'
];
export const READER_CLICK_REGION_DEFAULTS: string[] = [
  '上一页', '上一页', '下一页', '上一页', '菜单', '下一页', '上一页', '下一页', '下一页'
];

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
      paddingSettings: copyReaderPaddingSettings(DEFAULT_READER_PADDING_SETTINGS),
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
      paragraphSpacing: 2,
      lineSpacing: 12,
      letterSpacing: 0.1,
      paragraphIndent: '　　',
      textFont: '',
      titleFont: '',
      systemTypefaces: 0,
      textItalic: false,
      textBold: 500,
      textShadow: false,
      shadowRadius: 16,
      shadowDx: 1,
      shadowDy: 1,
      textShadowColor: '#3E3D3B',
      textShadowColorN: '#3E3D3B',
      underline: false,
      dottedLine: false,
      underlineColor: '#3E3D3B',
      underlineColorNight: '#ADADAD',
      underlineHeight: 1,
      textFullJustify: true,
      textBottomJustify: true,
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
      clickRegionActions: [...READER_CLICK_REGION_DEFAULTS],
      hideStatusBar: false,
      hideNavigationBar: false,
      showQuickActions: false,
      autoReadSpeed: 10,
      pageAnimation: 0,
      animationSpeed: 2,
      screenOrientation: '0',
      keepLight: '0',
      volumeKeyPage: true,
      keyPageOnLongPress: false,
      noAnimScrollPage: false,
      readingAnchorEnabled: true,
      swipeToAddBookmark: false,
      // 与上游 ReadSettings.bookmarkBadgeSize 默认值一致（10dp）。
      bookmarkBadgeSize: 10,
      // 上游 ReadSettings.bookmarkBadgeImage 默认空串，即使用默认丝带。
      bookmarkBadgeImage: '',
      selectText: true,
      maxLengthWithNoToc: 3000,
      eyeProtectionEnabled: false,
      eyeProtectionAutoNight: false,
      eyeProtectionSchedule: false,
      eyeProtectionIntensity: 50,
      eyeProtectionStartTime: '22:00',
      eyeProtectionEndTime: '07:00'
    };
    try {
      const store = await preferences.getPreferences(context, ReaderSettingsRepository.preferenceName);
      const fontSizeValue = await store.get('fontSize', defaults.fontSize);
      const paragraphSpacingValue = await store.get('paragraphSpacing', defaults.paragraphSpacing);
      const lineSpacingValue = await store.get('lineSpacingExtra', defaults.lineSpacing);
      const letterSpacingValue = await store.get('letterSpacing', defaults.letterSpacing);
      const paragraphIndentValue = await store.get('paragraphIndent', defaults.paragraphIndent);
      const textFontValue = await store.get('textFont', defaults.textFont);
      const titleFontValue = await store.get('titleFont', defaults.titleFont);
      const systemTypefacesValue = await store.get('system_typefaces', defaults.systemTypefaces);
      const textItalicValue = await store.get('textItalic', defaults.textItalic);
      const textBoldValue = await store.get('textBold', defaults.textBold);
      const textShadowValue = await store.get('textShadow', defaults.textShadow);
      const shadowRadiusValue = await store.get('shadowRadius', defaults.shadowRadius);
      const shadowDxValue = await store.get('shadowDx', defaults.shadowDx);
      const shadowDyValue = await store.get('shadowDy', defaults.shadowDy);
      const textShadowColorValue = await store.get('shadowColor', defaults.textShadowColor);
      const textShadowColorNightValue = await store.get('shadowColorN', defaults.textShadowColorN);
      const underlineValue = await store.get('underline', defaults.underline);
      const dottedLineValue = await store.get('dottedLine', defaults.dottedLine);
      const underlineColorValue = await store.get('underlineColor', defaults.underlineColor);
      const underlineColorNightValue = await store.get('underlineColorNight', defaults.underlineColorNight);
      const underlineHeightValue = await store.get('underlineHeight', defaults.underlineHeight);
      const textFullJustifyValue = await store.get('textFullJustify', defaults.textFullJustify);
      const textBottomJustifyValue = await store.get('textBottomJustify', defaults.textBottomJustify);
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
      const clickRegionActionsValue = await store.get('clickRegionActions', JSON.stringify(defaults.clickRegionActions));
      const hideStatusBarValue = await store.get('hideStatusBar', defaults.hideStatusBar);
      const hideNavigationBarValue = await store.get('hideNavigationBar', defaults.hideNavigationBar);
      const quickActionsValue = await store.get('showQuickActions', defaults.showQuickActions);
      const autoReadSpeedValue = await store.get('autoReadSpeed', defaults.autoReadSpeed);
      const pageAnimationValue = await store.get('pageAnimation', defaults.pageAnimation);
      const animationSpeedValue = await store.get('animationSpeed', defaults.animationSpeed);
      const screenOrientationValue = await store.get('screenOrientation', defaults.screenOrientation);
      const keepLightValue = await store.get('keep_light', defaults.keepLight);
      const volumeKeyPageValue = await store.get('volumeKeyPage', defaults.volumeKeyPage);
      const keyPageOnLongPressValue = await store.get('keyPageOnLongPress', defaults.keyPageOnLongPress);
      const noAnimScrollPageValue = await store.get('noAnimScrollPage', defaults.noAnimScrollPage);
      const readingAnchorEnabledValue = await store.get('readingAnchorEnabled', defaults.readingAnchorEnabled);
      const swipeToAddBookmarkValue = await store.get('swipeToAddBookmark', defaults.swipeToAddBookmark);
      const bookmarkBadgeSizeValue = await store.get('bookmarkBadgeSize', defaults.bookmarkBadgeSize);
      const bookmarkBadgeImageValue = await store.get('bookmarkBadgeImage', defaults.bookmarkBadgeImage);
      const selectTextValue = await store.get('selectText', defaults.selectText);
      const maxLengthWithNoTocValue = await store.get('maxLengthWithNoToc', defaults.maxLengthWithNoToc);
      const eyeProtectionEnabledValue = await store.get('eyeProtectionEnabled', defaults.eyeProtectionEnabled);
      const eyeProtectionAutoNightValue = await store.get('eyeProtectionAutoNight', defaults.eyeProtectionAutoNight);
      const eyeProtectionScheduleValue = await store.get('eyeProtectionSchedule', defaults.eyeProtectionSchedule);
      const eyeProtectionIntensityValue = await store.get('eyeProtectionIntensity', defaults.eyeProtectionIntensity);
      const eyeProtectionStartTimeValue = await store.get('eyeProtectionStartTime', defaults.eyeProtectionStartTime);
      const eyeProtectionEndTimeValue = await store.get('eyeProtectionEndTime', defaults.eyeProtectionEndTime);
      const paddingTopValue = await store.get('paddingTop', defaults.paddingSettings.paddingTop);
      const paddingBottomValue = await store.get('paddingBottom', defaults.paddingSettings.paddingBottom);
      const paddingLeftValue = await store.get('paddingLeft', defaults.paddingSettings.paddingLeft);
      const paddingRightValue = await store.get('paddingRight', defaults.paddingSettings.paddingRight);
      const headerPaddingTopValue = await store.get('headerPaddingTop', defaults.paddingSettings.headerPaddingTop);
      const headerPaddingBottomValue = await store.get('headerPaddingBottom', defaults.paddingSettings.headerPaddingBottom);
      const headerPaddingLeftValue = await store.get('headerPaddingLeft', defaults.paddingSettings.headerPaddingLeft);
      const headerPaddingRightValue = await store.get('headerPaddingRight', defaults.paddingSettings.headerPaddingRight);
      const footerPaddingTopValue = await store.get('footerPaddingTop', defaults.paddingSettings.footerPaddingTop);
      const footerPaddingBottomValue = await store.get('footerPaddingBottom', defaults.paddingSettings.footerPaddingBottom);
      const footerPaddingLeftValue = await store.get('footerPaddingLeft', defaults.paddingSettings.footerPaddingLeft);
      const footerPaddingRightValue = await store.get('footerPaddingRight', defaults.paddingSettings.footerPaddingRight);
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
      const paragraphSpacing = typeof paragraphSpacingValue === 'number' && Number.isInteger(paragraphSpacingValue) ? Math.max(0, Math.min(20, paragraphSpacingValue)) : defaults.paragraphSpacing;
      const lineSpacing = typeof lineSpacingValue === 'number' && Number.isInteger(lineSpacingValue) ? Math.max(0, Math.min(20, lineSpacingValue)) : defaults.lineSpacing;
      const letterSpacing = typeof letterSpacingValue === 'number' && Number.isFinite(letterSpacingValue)
        ? Math.round(Math.max(-0.5, Math.min(0.5, letterSpacingValue)) * 100) / 100 : defaults.letterSpacing;
      const paragraphIndent = typeof paragraphIndentValue === 'string' ? paragraphIndentValue : defaults.paragraphIndent;
      const textFont = typeof textFontValue === 'string' ? textFontValue : defaults.textFont;
      const titleFont = typeof titleFontValue === 'string' ? titleFontValue : defaults.titleFont;
      const systemTypefaces = ReaderSettingsRepository.normalizeInteger(
        systemTypefacesValue, 0, 2, defaults.systemTypefaces);
      const textItalic = typeof textItalicValue === 'boolean' ? textItalicValue : defaults.textItalic;
      const textBold = ReaderSettingsRepository.normalizeInteger(textBoldValue, 0, 1000, defaults.textBold);
      const textShadow = typeof textShadowValue === 'boolean' ? textShadowValue : defaults.textShadow;
      const shadowRadius = typeof shadowRadiusValue === 'number' && Number.isFinite(shadowRadiusValue)
        ? Math.max(0, Math.min(100, shadowRadiusValue)) : defaults.shadowRadius;
      const shadowDx = typeof shadowDxValue === 'number' && Number.isFinite(shadowDxValue)
        ? Math.max(-50, Math.min(50, shadowDxValue)) : defaults.shadowDx;
      const shadowDy = typeof shadowDyValue === 'number' && Number.isFinite(shadowDyValue)
        ? Math.max(-50, Math.min(50, shadowDyValue)) : defaults.shadowDy;
      const textShadowColor = ReaderSettingsRepository.normalizeHexColor(
        textShadowColorValue, defaults.textShadowColor);
      const textShadowColorN = ReaderSettingsRepository.normalizeHexColor(
        textShadowColorNightValue, defaults.textShadowColorN);
      const underline = typeof underlineValue === 'boolean' ? underlineValue : defaults.underline;
      const dottedLine = typeof dottedLineValue === 'boolean' ? dottedLineValue : defaults.dottedLine;
      const underlineColor = ReaderSettingsRepository.normalizeHexColor(
        underlineColorValue, defaults.underlineColor);
      const underlineColorNight = ReaderSettingsRepository.normalizeHexColor(
        underlineColorNightValue, defaults.underlineColorNight);
      const underlineHeight = ReaderSettingsRepository.normalizeInteger(
        underlineHeightValue, 0, 10, defaults.underlineHeight);
      const textFullJustify = typeof textFullJustifyValue === 'boolean'
        ? textFullJustifyValue : defaults.textFullJustify;
      const textBottomJustify = typeof textBottomJustifyValue === 'boolean'
        ? textBottomJustifyValue : defaults.textBottomJustify;
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
        paddingSettings: {
          paddingTop: ReaderSettingsRepository.normalizeInteger(paddingTopValue, 0, 300, defaults.paddingSettings.paddingTop),
          paddingBottom: ReaderSettingsRepository.normalizeInteger(paddingBottomValue, 0, 300, defaults.paddingSettings.paddingBottom),
          paddingLeft: ReaderSettingsRepository.normalizeInteger(paddingLeftValue, 0, 300, defaults.paddingSettings.paddingLeft),
          paddingRight: ReaderSettingsRepository.normalizeInteger(paddingRightValue, 0, 300, defaults.paddingSettings.paddingRight),
          headerPaddingTop: ReaderSettingsRepository.normalizeInteger(headerPaddingTopValue, 0, 300, defaults.paddingSettings.headerPaddingTop),
          headerPaddingBottom: ReaderSettingsRepository.normalizeInteger(headerPaddingBottomValue, 0, 300, defaults.paddingSettings.headerPaddingBottom),
          headerPaddingLeft: ReaderSettingsRepository.normalizeInteger(headerPaddingLeftValue, 0, 300, defaults.paddingSettings.headerPaddingLeft),
          headerPaddingRight: ReaderSettingsRepository.normalizeInteger(headerPaddingRightValue, 0, 300, defaults.paddingSettings.headerPaddingRight),
          footerPaddingTop: ReaderSettingsRepository.normalizeInteger(footerPaddingTopValue, 0, 300, defaults.paddingSettings.footerPaddingTop),
          footerPaddingBottom: ReaderSettingsRepository.normalizeInteger(footerPaddingBottomValue, 0, 300, defaults.paddingSettings.footerPaddingBottom),
          footerPaddingLeft: ReaderSettingsRepository.normalizeInteger(footerPaddingLeftValue, 0, 300, defaults.paddingSettings.footerPaddingLeft),
          footerPaddingRight: ReaderSettingsRepository.normalizeInteger(footerPaddingRightValue, 0, 300, defaults.paddingSettings.footerPaddingRight)
        },
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
        paragraphSpacing: paragraphSpacing,
        lineSpacing: lineSpacing,
        letterSpacing: letterSpacing,
        paragraphIndent: paragraphIndent,
        textFont: textFont,
        titleFont: titleFont,
        systemTypefaces: systemTypefaces,
        textItalic: textItalic,
        textBold: textBold,
        textShadow: textShadow,
        shadowRadius: shadowRadius,
        shadowDx: shadowDx,
        shadowDy: shadowDy,
        textShadowColor: textShadowColor,
        textShadowColorN: textShadowColorN,
        underline: underline,
        dottedLine: underline && dottedLine,
        underlineColor: underlineColor,
        underlineColorNight: underlineColorNight,
        underlineHeight: underlineHeight,
        textFullJustify: textFullJustify,
        textBottomJustify: textBottomJustify,
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
        clickRegionActions: ReaderSettingsRepository.normalizeClickRegionActions(clickRegionActionsValue),
        hideStatusBar: typeof hideStatusBarValue === 'boolean' ? hideStatusBarValue : defaults.hideStatusBar,
        hideNavigationBar: typeof hideNavigationBarValue === 'boolean'
          ? hideNavigationBarValue : defaults.hideNavigationBar,
        showQuickActions: typeof quickActionsValue === 'boolean' ? quickActionsValue : defaults.showQuickActions,
        autoReadSpeed: typeof autoReadSpeedValue === 'number' && Number.isInteger(autoReadSpeedValue)
          ? Math.max(1, Math.min(120, autoReadSpeedValue)) : defaults.autoReadSpeed,
        pageAnimation: typeof pageAnimationValue === 'number' && Number.isInteger(pageAnimationValue)
          ? Math.max(0, Math.min(5, pageAnimationValue)) : defaults.pageAnimation,
        animationSpeed: typeof animationSpeedValue === 'number' && Number.isInteger(animationSpeedValue)
          ? Math.max(0, Math.min(3, animationSpeedValue)) : defaults.animationSpeed,
        screenOrientation: typeof screenOrientationValue === 'string' && ['0', '1', '2', '3', '4', '5'].includes(screenOrientationValue)
          ? screenOrientationValue : defaults.screenOrientation,
        keepLight: typeof keepLightValue === 'string' && ['0', '60', '300', '600', '-1'].includes(keepLightValue)
          ? keepLightValue : defaults.keepLight,
        volumeKeyPage: typeof volumeKeyPageValue === 'boolean' ? volumeKeyPageValue : defaults.volumeKeyPage,
        keyPageOnLongPress: typeof keyPageOnLongPressValue === 'boolean'
          ? keyPageOnLongPressValue : defaults.keyPageOnLongPress,
        noAnimScrollPage: typeof noAnimScrollPageValue === 'boolean'
          ? noAnimScrollPageValue : defaults.noAnimScrollPage,
          readingAnchorEnabled: typeof readingAnchorEnabledValue === 'boolean'
            ? readingAnchorEnabledValue : defaults.readingAnchorEnabled,
            swipeToAddBookmark: typeof swipeToAddBookmarkValue === 'boolean'
              ? swipeToAddBookmarkValue : defaults.swipeToAddBookmark,
            bookmarkBadgeSize: typeof bookmarkBadgeSizeValue === 'number' && Number.isInteger(bookmarkBadgeSizeValue)
              ? Math.max(0, Math.min(50, bookmarkBadgeSizeValue)) : defaults.bookmarkBadgeSize,
            bookmarkBadgeImage: typeof bookmarkBadgeImageValue === 'string'
              ? bookmarkBadgeImageValue : defaults.bookmarkBadgeImage,
            selectText: typeof selectTextValue === 'boolean' ? selectTextValue : defaults.selectText,
          maxLengthWithNoToc: typeof maxLengthWithNoTocValue === 'number' && Number.isInteger(maxLengthWithNoTocValue)
            ? Math.max(3000, Math.min(100000, maxLengthWithNoTocValue)) : defaults.maxLengthWithNoToc,
          eyeProtectionEnabled: typeof eyeProtectionEnabledValue === 'boolean'
            ? eyeProtectionEnabledValue : defaults.eyeProtectionEnabled,
          eyeProtectionAutoNight: typeof eyeProtectionAutoNightValue === 'boolean'
            ? eyeProtectionAutoNightValue : defaults.eyeProtectionAutoNight,
          eyeProtectionSchedule: typeof eyeProtectionScheduleValue === 'boolean'
            ? eyeProtectionScheduleValue : defaults.eyeProtectionSchedule,
          eyeProtectionIntensity: ReaderSettingsRepository.normalizeInteger(
            eyeProtectionIntensityValue, 0, 100, defaults.eyeProtectionIntensity),
          eyeProtectionStartTime: ReaderSettingsRepository.normalizeTime(
            eyeProtectionStartTimeValue, defaults.eyeProtectionStartTime),
          eyeProtectionEndTime: ReaderSettingsRepository.normalizeTime(
            eyeProtectionEndTimeValue, defaults.eyeProtectionEndTime)
      };
    } catch (_) {
      return defaults;
    }
  }

  static save(context: Context, settings: ReaderSettingsSnapshot): Promise<void> {
    const operation = ReaderSettingsRepository.saveQueue.then(async (): Promise<void> => {
      const store = await preferences.getPreferences(context, ReaderSettingsRepository.preferenceName);
      await store.put('fontSize', Math.max(5, Math.min(50, Math.round(settings.fontSize))));
      await store.put('paragraphSpacing', Math.max(0, Math.min(20, Math.round(settings.paragraphSpacing))));
      await store.put('lineSpacingExtra', Math.max(0, Math.min(20, Math.round(settings.lineSpacing))));
      await store.put('letterSpacing', Math.round(Math.max(-0.5, Math.min(0.5, settings.letterSpacing)) * 100) / 100);
      await store.put('paragraphIndent', settings.paragraphIndent);
      await store.put('textFont', settings.textFont);
      await store.put('titleFont', settings.titleFont);
      await store.put('system_typefaces', Math.max(0, Math.min(2, Math.round(settings.systemTypefaces))));
      await store.put('textItalic', settings.textItalic);
      await store.put('textBold', ReaderSettingsRepository.normalizeInteger(settings.textBold, 0, 1000, 500));
      await store.put('textShadow', settings.textShadow);
      await store.put('shadowRadius', Math.max(0, Math.min(100, settings.shadowRadius)));
      await store.put('shadowDx', Math.max(-50, Math.min(50, settings.shadowDx)));
      await store.put('shadowDy', Math.max(-50, Math.min(50, settings.shadowDy)));
      await store.put('shadowColor', ReaderSettingsRepository.normalizeHexColor(
        settings.textShadowColor, '#3E3D3B'));
      await store.put('shadowColorN', ReaderSettingsRepository.normalizeHexColor(
        settings.textShadowColorN, '#3E3D3B'));
      await store.put('underline', settings.underline);
      await store.put('dottedLine', settings.underline && settings.dottedLine);
      await store.put('underlineColor', ReaderSettingsRepository.normalizeHexColor(
        settings.underlineColor, '#3E3D3B'));
      await store.put('underlineColorNight', ReaderSettingsRepository.normalizeHexColor(
        settings.underlineColorNight, '#ADADAD'));
      await store.put('underlineHeight', Math.max(0, Math.min(10, Math.round(settings.underlineHeight))));
      await store.put('textFullJustify', settings.textFullJustify);
      await store.put('textBottomJustify', settings.textBottomJustify);
      await store.put('paddingTop', Math.max(0, Math.min(300, Math.round(settings.paddingSettings.paddingTop))));
      await store.put('paddingBottom', Math.max(0, Math.min(300, Math.round(settings.paddingSettings.paddingBottom))));
      await store.put('paddingLeft', Math.max(0, Math.min(300, Math.round(settings.paddingSettings.paddingLeft))));
      await store.put('paddingRight', Math.max(0, Math.min(300, Math.round(settings.paddingSettings.paddingRight))));
      await store.put('headerPaddingTop', Math.max(0, Math.min(300, Math.round(settings.paddingSettings.headerPaddingTop))));
      await store.put('headerPaddingBottom', Math.max(0, Math.min(300, Math.round(settings.paddingSettings.headerPaddingBottom))));
      await store.put('headerPaddingLeft', Math.max(0, Math.min(300, Math.round(settings.paddingSettings.headerPaddingLeft))));
      await store.put('headerPaddingRight', Math.max(0, Math.min(300, Math.round(settings.paddingSettings.headerPaddingRight))));
      await store.put('footerPaddingTop', Math.max(0, Math.min(300, Math.round(settings.paddingSettings.footerPaddingTop))));
      await store.put('footerPaddingBottom', Math.max(0, Math.min(300, Math.round(settings.paddingSettings.footerPaddingBottom))));
      await store.put('footerPaddingLeft', Math.max(0, Math.min(300, Math.round(settings.paddingSettings.footerPaddingLeft))));
      await store.put('footerPaddingRight', Math.max(0, Math.min(300, Math.round(settings.paddingSettings.footerPaddingRight))));
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
      await store.put('clickRegionActions', JSON.stringify(
        ReaderSettingsRepository.normalizeClickRegionActions(JSON.stringify(settings.clickRegionActions))));
      await store.put('hideStatusBar', settings.hideStatusBar);
      await store.put('hideNavigationBar', settings.hideNavigationBar);
      await store.put('paperStyleVersion', 1);
      await store.put('showQuickActions', settings.showQuickActions);
      await store.put('autoReadSpeed', Math.max(1, Math.min(120, Math.round(settings.autoReadSpeed))));
      await store.put('pageAnimation', Math.max(0, Math.min(5, Math.round(settings.pageAnimation))));
      await store.put('animationSpeed', Math.max(0, Math.min(3, Math.round(settings.animationSpeed))));
      await store.put('screenOrientation', ['0', '1', '2', '3', '4', '5'].includes(settings.screenOrientation)
        ? settings.screenOrientation : '0');
      await store.put('keep_light', ['0', '60', '300', '600', '-1'].includes(settings.keepLight)
        ? settings.keepLight : '0');
      await store.put('volumeKeyPage', settings.volumeKeyPage);
      await store.put('keyPageOnLongPress', settings.keyPageOnLongPress);
      await store.put('noAnimScrollPage', settings.noAnimScrollPage);
      await store.put('readingAnchorEnabled', settings.readingAnchorEnabled);
      await store.put('swipeToAddBookmark', settings.swipeToAddBookmark);
      await store.put('bookmarkBadgeSize', Math.max(0, Math.min(50, Math.round(settings.bookmarkBadgeSize))));
      await store.put('bookmarkBadgeImage', settings.bookmarkBadgeImage);
      await store.put('selectText', settings.selectText);
      await store.put('maxLengthWithNoToc', Math.max(3000, Math.min(100000, Math.round(settings.maxLengthWithNoToc))));
      await store.put('eyeProtectionEnabled', settings.eyeProtectionEnabled);
      await store.put('eyeProtectionAutoNight', settings.eyeProtectionAutoNight);
      await store.put('eyeProtectionSchedule', settings.eyeProtectionSchedule);
      await store.put('eyeProtectionIntensity', Math.max(0, Math.min(100, Math.round(settings.eyeProtectionIntensity))));
      await store.put('eyeProtectionStartTime', ReaderSettingsRepository.normalizeTime(
        settings.eyeProtectionStartTime, '22:00'));
      await store.put('eyeProtectionEndTime', ReaderSettingsRepository.normalizeTime(
        settings.eyeProtectionEndTime, '07:00'));
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

  private static normalizeClickRegionActions(value: number | boolean | string | bigint | Uint8Array | object): string[] {
    let parsed: string[] = [];
    if (typeof value === 'string') {
      try {
        const result: string[] = JSON.parse(value);
        if (Array.isArray(result)) { parsed = result; }
      } catch (_) {
        parsed = [];
      }
    }
    return READER_CLICK_REGION_DEFAULTS.map((fallback: string, index: number): string => {
      const action = parsed[index];
      return typeof action === 'string' && READER_CLICK_REGION_ACTIONS.includes(action) ? action : fallback;
    });
  }

  private static normalizeInteger(value: number | boolean | string | bigint | Uint8Array | object, minimum: number, maximum: number, fallback: number): number {
    return typeof value === 'number' && Number.isInteger(value)
      ? Math.max(minimum, Math.min(maximum, value)) : fallback;
  }

  private static normalizeTime(value: number | boolean | string | bigint | Uint8Array | object, fallback: string): string {
    if (typeof value !== 'string' || !/^\d{2}:\d{2}$/.test(value)) { return fallback; }
    const parts: string[] = value.split(':');
    const hour: number = Number(parts[0]);
    const minute: number = Number(parts[1]);
    return hour >= 0 && hour < 24 && minute >= 0 && minute < 60 ? value : fallback;
  }

  private static normalizeColor(value: number | boolean | string | bigint | Uint8Array | object, fallback: number): number {
    return typeof value === 'number' && Number.isInteger(value) ? value : fallback;
  }

  private static normalizeHexColor(value: number | boolean | string | bigint | Uint8Array | object, fallback: string): string {
    if (typeof value !== 'string') { return fallback; }
    const normalized = value.trim().toUpperCase();
    return /^#[0-9A-F]{6}$/.test(normalized) || /^#[0-9A-F]{8}$/.test(normalized)
      ? normalized : fallback;
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
