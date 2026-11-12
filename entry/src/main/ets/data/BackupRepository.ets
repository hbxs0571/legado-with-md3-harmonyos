import { fileIo, picker } from '@kit.CoreFileKit';
import {
  THEME_CONFIG_FILE_NAME, ThemeConfigEntry, buildCurrentThemeConfigs, parseThemeConfigs, saveThemeConfigs,
  themeConfigsToJson, upThemeConfig
} from './ThemeConfigStore';
import { CustomThemeSnapshot, defaultCustomThemeSnapshot } from './CustomThemeColors';
import {
  CoverRule, CoverRuleRepository, copyCoverRule, isDefaultCoverRule, DEFAULT_COVER_RULE
} from './CoverRuleRepository';
import { preferences } from '@kit.ArkData';
import zlib from '@ohos.zlib';
import { Book } from '../model/Book';
import { EpubRepository } from './EpubRepository';
import { BookRepository } from './BookRepository';
import { BookGroupRepository } from './BookGroupRepository';
import { BookshelfLayoutRepository } from './BookshelfLayoutRepository';
import { BookshelfLayoutSettings, copyBookshelfLayout } from '../model/BookshelfLayout';
import {
  READER_BACKGROUND_STYLES, ReaderBackgroundStyle, ReaderSettingsRepository, ReaderSettingsSnapshot,
  ReaderBottomActionConfig
} from './ReaderSettingsRepository';
import { ReplaceRuleRepository } from './ReplaceRuleRepository';
import { ReplaceRuleImporter } from './ReplaceRuleImporter';
import { TxtTocRuleRepository } from './TxtTocRuleRepository';
import { TxtTocRuleImporter } from './TxtTocRuleImporter';
import { ReaderHighlightRuleRepository } from './ReaderHighlightRuleRepository';
import { ReaderHighlightRule } from '../model/ReaderHighlightRule';
import { ReaderBookmarkRepository } from './ReaderBookmarkRepository';
import { ReaderMarkingRepository } from './ReaderMarkingRepository';
import { ReaderBookmarkExporter } from './ReaderBookmarkExporter';
import { BookmarkImportOutcome, ReaderBookmarkImporter } from './ReaderBookmarkImporter';
import { ReaderBookmark } from '../model/ReaderBookmark';
import { ReaderMarking } from '../model/ReaderMarking';
import { LocalBookRestorePlanner } from './LocalBookRestorePlanner';
import { ThemeSettingsRepository } from './ThemeSettingsRepository';
import {
  CoverSettings, CoverSettingsRepository, copyCoverSettings,
  coverSettingsToAndroid, applyAndroidCoverPreferences, coverColorToAndroidInt
} from './CoverSettingsRepository';
import { ReadRecordDetail, ReadRecordSession, ReadRecordSummary } from '../model/ReadRecord';
import { ReadRecordRepository } from './ReadRecordRepository';
import { DictRuleRepository } from './DictRuleRepository';
import { DictRuleImporter } from './DictRuleImporter';
import { HomepageModuleRepository } from './HomepageModuleRepository';
import { HomepageModuleImporter } from './HomepageModuleImporter';
import { HomepageCustomSetRepository } from './HomepageCustomSetRepository';
import { HomepageCustomSetImporter } from './HomepageCustomSetImporter';
import { HighlightTagRuleRepository } from './HighlightTagRuleRepository';
import { HighlightTagRuleImporter } from './HighlightTagRuleImporter';
import { TagGroupRuleRepository } from './TagGroupRuleRepository';
import { TagGroupRuleImporter } from './TagGroupRuleImporter';
import { HttpTtsRepository } from './HttpTtsRepository';
import { ReadAloudVoiceRepository } from './ReadAloudVoiceRepository';
import { HttpTtsImporter } from './HttpTtsImporter';
import { BookSourceRepository } from './BookSourceRepository';
import { BookSourceImporter } from './BookSourceImporter';
import { RssSourceRepository } from './RssSourceRepository';
import { RssSourceImporter } from './RssSourceImporter';
import { RssStarRepository } from './RssStarRepository';
import { RssStarImporter } from './RssStarImporter';
import { RuleSubRepository } from './RuleSubRepository';
import { RuleSubImporter } from './RuleSubImporter';
import { aesEcbEncryptToBase64, aesEcbDecryptFromBase64, aesEcKeyFromPassword } from './BackupCrypto';
import { ServerRepository } from './ServerRepository';

/** 上游 readRecordSession.json 的字段：words 对应本地 chapterIndex。 */
interface AndroidReadRecordSessionRecord {
  deviceId: string;
  bookName: string;
  bookAuthor: string;
  bookUrl: string;
  startTime: number;
  endTime: number;
  words: number;
}

/** 解析 highlightRule.json 的结果：可用规则与因形态不符被跳过的条数。 */
interface HighlightRuleParseOutcome {
  rules: ReaderHighlightRule[];
  skipped: number;
}

export interface BackupEntryPreview {
  name: string;
  recordCount: number;
  byteSize: number;
}

export interface BackupPreview {
  entryCount: number;
  bookCount: number;
  localBookCount: number;
  localBooksWithoutBody: number;
  entries: BackupEntryPreview[];
}

export interface BackupSelection {
  stagingDirectory: string;
  preview: BackupPreview;
}

export interface BackupIgnoreLists {
  backup: string[];
  restore: string[];
}

export interface BackupCategoryOption {
  key: string;
  title: string;
  files: string[];
  preferenceKeys?: string[];
}

/** 透传缓存里一条 Android config.xml 首选项：type 为 XML 标签名，value 为原值文本。 */
export interface XmlPreferenceEntry {
  /** XML 标签名，六选一：string / int / long / float / boolean / set。 */
  type: string;
  /** 原值文本，不做 .trim() / 反转义，原样存、原样写，避免 &amp; 之类被双重转义。 */
  value: string;
}

export interface RestoreResult {
  books: Book[];
  settings: ReaderSettingsSnapshot;
  bookshelfLayout: BookshelfLayoutSettings;
  /** 从 config.xml 的 coverConfig 键组恢复出来的封面设置。 */
  coverSettings: CoverSettings;
  /** 恢复出来的全局主题模式（`"0"`/`"1"`/`"2"`）；备份里没有该键时为 undefined。 */
  themeMode: string | undefined;
  /** 从 config.xml 的 showRss 布尔键恢复的订阅入口开关；归档里没有该键或该类被忽略时为 undefined。 */
  showRss: boolean | undefined;
  preservedEntryCount: number;
  updatedLocalBookCount: number;
  createdMissingBodyBookCount: number;
  /** 恢复期按 LocalBookRestorePlanner 判定为重复书目并删除的条数。 */
  deletedDuplicateLocalBookCount: number;
  localBooksWithoutBody: number;
  restoredEntries: BackupEntryPreview[];
  /** 恢复替换净化规则的新增条数；没有 replaceRule.json 时为 0。 */
  replaceRuleAdded: number;
  /** 恢复替换净化规则的覆盖条数（同 id 或同 pattern 视为同一条）。 */
  replaceRuleUpdated: number;
  /** 解析失败或正则非法而被跳过的规则条数。 */
  replaceRuleSkipped: number;
  /** 恢复 TXT 目录规则的新增、覆盖和跳过数量。 */
  txtTocRuleAdded: number;
  txtTocRuleUpdated: number;
  txtTocRuleSkipped: number;
  /** 恢复阅读正文高亮规则的新增、覆盖和跳过数量；采用合并语义，本地独有规则保留。 */
  highlightRuleAdded: number;
  highlightRuleUpdated: number;
  highlightRuleSkipped: number;
  /** 恢复书签、划线与笔记的新增、覆盖和跳过数量；同样采用合并语义。 */
  bookmarkAdded: number;
  bookmarkUpdated: number;
  bookmarkSkipped: number;
  /** 恢复字典规则的新增、覆盖和跳过数量（合并语义，本地独有规则保留）。 */
  dictRuleAdded: number;
  dictRuleUpdated: number;
  dictRuleSkipped: number;
  /** 恢复首页模块的新增、覆盖和跳过数量（合并语义，本地独有规则保留）。 */
  homepageModulesAdded: number;
  homepageModulesUpdated: number;
  homepageModulesSkipped: number;
  /** 恢复首页自定义集的新增、覆盖和跳过数量（合并语义，本地独有规则保留）。 */
  homepageCustomSetsAdded: number;
  homepageCustomSetsUpdated: number;
  homepageCustomSetsSkipped: number;
  /** 恢复标签高亮规则的新增、覆盖和跳过数量（合并语义，本地独有规则保留）。 */
  highlightTagRuleAdded: number;
  highlightTagRuleUpdated: number;
  highlightTagRuleSkipped: number;
  /** 恢复标签分组规则的新增、覆盖和跳过数量（合并语义，本地独有规则保留）。 */
  tagGroupRuleAdded: number;
  tagGroupRuleUpdated: number;
  tagGroupRuleSkipped: number;
  /** 恢复在线朗读源的新增、覆盖和跳过数量（按 id 合并）。 */
  httpTtsSourcesAdded: number;
  httpTtsSourcesUpdated: number;
  httpTtsSourcesSkipped: number;
  /** 恢复 http 音色的落库条数与跳过条数；损坏文件按跳过计且不覆盖本地音色。 */
  httpTtsVoicesRestored: number;
  httpTtsVoicesSkipped: number;
  /** 恢复书源的新增、覆盖和跳过数量（合并语义，本地独有条目保留）。 */
  bookSourceAdded: number;
  bookSourceUpdated: number;
  bookSourceSkipped: number;
  /** 恢复 RSS 订阅源的新增、覆盖和跳过数量（合并语义，本地独有条目保留）。 */
  rssSourceAdded: number;
  rssSourceUpdated: number;
  rssSourceSkipped: number;
  /** 恢复 RSS 收藏的新增、覆盖和跳过数量（合并语义，跨 origin+link 判重）。 */
  rssStarAdded: number;
  rssStarUpdated: number;
  rssStarSkipped: number;
  /** 恢复规则订阅的新增、覆盖和跳过数量（合并语义，按 id 判重）。 */
  sourceSubAdded: number;
  sourceSubUpdated: number;
  sourceSubSkipped: number;
  /** 恢复服务器配置的新增、覆盖和跳过数量（按 id 判重）。 */
  serverAdded: number;
  serverUpdated: number;
  serverSkipped: number;
}

interface AndroidBookBackupRecord {
  bookUrl: string;
  tocUrl: string;
  origin: string;
  originName: string;
  name: string;
  author: string;
  kind: string;
  customTag: string | null;
  coverUrl: string | null | undefined;
  customCoverUrl: string | null;
  intro: string | null;
  customIntro: string | null;
  remark: string | null;
  charset: string | null;
  type: number;
  group: number;
  isPrivate: boolean;
  latestChapterTitle: string;
  latestChapterTime: number;
  lastCheckTime: number;
  lastCheckCount: number;
  totalChapterNum: number;
  durChapterTitle: string;
  durChapterIndex: number;
  durChapterPos: number;
  durChapterTime: number;
  wordCount: string | null;
  canUpdate: boolean;
  disableReadRecord: boolean;
  order: number;
  originOrder: number;
  variable: string | null;
  readConfig: Object | null;
  syncTime: number;
  listIntro: string | null;
}

interface AndroidReadConfigBackupRecord {
  name: string;
  textSize: number;
  letterSpacing: number;
  paragraphSpacing: number;
  lineSpacingExtra: number;
  paragraphIndent: string;
  textBold: number;
  textItalic: boolean;
  textShadow: boolean;
  shadowRadius: number;
  shadowDx: number;
  shadowDy: number;
  shadowColor: string;
  shadowColorN: string;
  underline: boolean;
  underlineHeight: number;
  /** 下划线离字间距；上游 ReadBookConfig.kt:322 的 underlinePadding，默认 10。 */
  underlinePadding: number;
  /** 下划线是否撑满整行；上游 :325 的 underlineExtend。 */
  underlineExtend: boolean;
  /** 虚线段长；上游 :331 的 dottedBase，默认 6f。 */
  dottedBase: number;
  /** 虚线空隙；上游 :334 的 dottedRatio，默认 6f。 */
  dottedRatio: number;
  underlineColor: string;
  underlineColorNight: string;
  dottedLine: boolean;
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
  hideStatusBar: boolean;
  hideNavigationBar: boolean;
  pageAnim: number;
  pageAnimSpeed: number;
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
  bgType: number;
  bgStr: string;
  bgTypeNight: number;
  bgStrNight: string;
  /** 背景透明度百分比 0..100；上游 ReadBookConfig.kt:548 `bgAlpha: Int = 100`。 */
  bgAlpha: number;
  /** 正文颜色；上游 ReadBookConfig.kt:555-556。 */
  textColor: string;
  textColorNight: string;
  /** 强调色；上游 ReadBookConfig.kt:558-559。 */
  textAccentColor: string;
  textAccentColorNight: string;
  /** 状态栏图标深浅；上游 ReadBookConfig.kt:552-553。 */
  darkStatusIcon: boolean;
  darkStatusIconNight: boolean;
  /** 标题排版十四个字段；上游 ReadBookConfig.kt:596-608。 */
  titleMode: number;
  titleSize: number;
  titleSizeRelative: boolean;
  titleTopSpacing: number;
  titleBottomSpacing: number;
  /** 标题颜色，空串表示未设置、沿用正文色（上游默认 0 同义）。 */
  titleColor: string;
  titleColorNight: string;
  titleBold: number;
  titleLineSpacingExtra: number;
  titleLineSpacingSub: number;
  titleSegType: number;
  titleSegScaling: number;
  titleSegDistance: number;
  titleSegFlag: string;
  /**
   * 自定义翻页按键与滚轮翻页；上游存储键是 prevKeyCodes/nextKeyCodes
   * （PreferKey.kt:48-49），字段名才是 prevKeys/nextKeys（ReadSettings.kt:60-61）。
   */
  prevKeyCodes: string;
  nextKeyCodes: string;
  /** 鼠标滚轮翻页；上游 ReadSettings.kt:28 `mouseWheelPage: Boolean = true`。 */
  mouseWheelPage: boolean;
  /** 划词菜单展开；上游 ReadSettings.kt:51 `expandTextMenu: Boolean = false`。 */
  expandTextMenu: boolean;
  /** 划词菜单显示图标；上游 ReadSettings.kt:52 `showSelectMenuIcon: Boolean = true`。 */
  showSelectMenuIcon: boolean;
  /** 划词菜单条目配置 JSON 串；上游 ReadSettings.kt:53 `textSelectMenuConfig: String = ""`。 */
  textSelectMenuConfig: string;
  /** 横屏双页档位 '0'..'3'，上游键名 doubleHorizontalPage（PreferKey.kt:157）。 */
  doubleHorizontalPage: string;
  /** 环境光日夜提醒开关，上游键名 autoSuggestDayNight（PreferKey.kt:120）。 */
  autoSuggestDayNight: boolean;
  /** 禁用返回键，上游键名 disableReturnKey（PreferKey.kt:420）。 */
  disableReturnKey: boolean;
  /** 阅读亮度 1..100，上游键名 brightness（PreferKey.kt:151），随 config.xml 备份。 */
  readBrightness: number;
  /** 亮度条形态，上游键名 readBrightnessMode（PreferKey.kt:112），在阅读配置忽略清单里，不导出。 */
  showBrightnessView: string;
  /** 亮度条位置，上游键名 readBrightnessControlPosition（PreferKey.kt:193），同上不导出。 */
  brightnessVwPos: string;
  /** 亮度是否跟随系统，上游键名 brightnessAuto（PreferKey.kt:194），随 config.xml 备份。 */
  brightnessAuto: boolean;
  /** 正文行高适配；上游 ReadSettings.kt:14，键名同名，不在 readPrefKeys 忽略清单里。 */
  readBodyToLh: boolean;
  /** 自定义中文分行；上游 ReadSettings.kt:19。 */
  useZhLayout: boolean;
  /** 填充刘海区域；上游 ReadSettings.kt:11。 */
  paddingDisplayCutouts: boolean;
  /** 适配特殊样式；上游 ReadSettings.kt:18。 */
  adaptSpecialStyle: boolean;
}

interface JsonStringResult {
  value: string;
  end: number;
}

interface RestoredBookProgress {
  books: Book[];
  updatedCount: number;
  createdMissingBodyCount: number;
  deletedDuplicateCount: number;
}

interface AndroidPreferenceKeyGroups {
  readConfig: string[];
  themeConfig: string[];
  bookshelfLayout: string[];
  mangaConfig: string[];
  coverConfig: string[];
  themeMode: string[];
  showRss: string[];
  threadCount: string[];
}

/** 本地备份沿用 Legado Android 的 ZIP 根目录文件名、JSON/XML 结构和数据类别。 */
export class BackupRepository {
  private static readonly preferenceName: string = 'legado_android_backup_options';
  private static readonly restoredEntrySummaryKey: string = 'restoredEntrySummary';
  private static readonly maximumCompressedBytes: number = 64 * 1024 * 1024;
  private static readonly maximumExpandedBytes: number = 256 * 1024 * 1024;
  private static readonly maximumArchiveEntries: number = 2000;
  private static readonly maximumJsonTextBytes: number = 32 * 1024 * 1024;
  private static readonly legacyDirectoryName: string = 'android-backup-entries';
  private static readonly alwaysIgnoredPreferenceKeys: Set<string> = new Set<string>([
    'defaultCover', 'defaultCoverDark', 'backupUri', 'defaultBookTreeUri', 'webDavDeviceName',
    'launcherIcon', 'bitmapCacheSize', 'webServiceWakeLock', 'readAloudWakeLock', 'audioPlayWakeLock',
    'PASSWORD', 'MIGRATED_TO_SETTINGS', 'PRIVATE_PASSWORD_SALT', 'PRIVATE_PASSWORD_VERIFIER',
    'PRIVATE_BIOMETRIC_ENABLED', 'PRIVATE_BIOMETRIC_ENVELOPE', 'PRIVATE_BIOMETRIC_IV'
  ]);
  /** 透传缓存专用 preferences store，与 ignoreLists 分仓，避免互相污染。 */
  private static readonly passthroughPreferenceName: string = 'legado_backup_passthrough';
  private static readonly passthroughCacheKey: string = 'androidConfigPassthrough';
  /** 透传缓存业务闸门：2000 键 / 1 MB（preferences 单值上限 16 MB，按业务量自设，字符串长度近似字节）。 */
  private static readonly maximumPassthroughKeys: number = 2000;
  private static readonly maximumPassthroughBytes: number = 1024 * 1024;
  /**
   * 已知写出键集 = upsertAndroidPreference 的 91 个 config.xml 字面量键
   * + coverSettingsToAndroid 的 14 个封面键 = 105 键（两集合无交集）。
   * 做成常量数组，不「遍历 XML 看有没有」：那份 XML 是 copyPreservedEntries 带进来的，
   * 会出现「上次写过所以这次跳过」，一旦用户删了某项就永远写不回去。
   */
  private static readonly writtenPreferenceKeys: Set<string> = new Set<string>([
    'adaptSpecialStyle', 'autoSuggestDayNight', 'auto_refresh', 'bookGroupStyle',
    'bookmarkBadgeImage', 'bookmarkBadgeSize', 'bookshelfCardColor', 'bookshelfCardColorDark',
    'bookshelfCoverShadow', 'bookshelfFolderLayoutGridLandscape', 'bookshelfFolderLayoutGridPortrait', 'bookshelfFolderLayoutListLandscape',
    'bookshelfFolderLayoutListPortrait', 'bookshelfFolderLayoutModeLandscape', 'bookshelfFolderLayoutModePortrait', 'bookshelfGridCoverWidth',
    'bookshelfGridLayout', 'bookshelfGroupCoverCount', 'bookshelfGroupListStyle', 'bookshelfIntroMaxLines',
    'bookshelfLayoutCompact', 'bookshelfLayoutGridLandscape', 'bookshelfLayoutGridPortrait', 'bookshelfLayoutListLandscape',
    'bookshelfLayoutListPortrait', 'bookshelfLayoutPortrait', 'bookshelfListCoverCenter', 'bookshelfListCoverWidth',
    'bookshelfListIntroBelowContent', 'bookshelfRefreshingLimit', 'bookshelfSearchActionDirectToSearch', 'bookshelfSelectedGroupId',
    'bookshelfShowDivider', 'bookshelfShowIntro', 'bookshelfShowLatestChapter', 'bookshelfSort',
    'bookshelfSortOrder', 'bookshelfTitleCenter', 'bookshelfTitleMaxLines', 'bookshelfTitleSmallFont',
    'bookshelf_layout_landscape', 'brightness', 'brightnessAuto', 'chineseConverterType',
    'clickImgWay', 'colorTemperature', 'coverDefaultColor', 'coverInfoOrientation',
    'coverRestrictRatio', 'coverShadowColor', 'coverShadowColorN', 'coverShowAuthor',
    'coverShowAuthorN', 'coverShowName', 'coverShowNameN', 'coverShowShadow',
    'coverShowStroke', 'coverTextColor', 'coverTextColorN', 'disableReturnKey',
    'dottedBase', 'dottedRatio', 'doubleHorizontalPage', 'expandTextMenu',
    'explore_filter_state', 'eyeProtectionAutoNight', 'eyeProtectionEnabled', 'eyeProtectionEndTime',
    'eyeProtectionSchedule', 'eyeProtectionStartTime', 'hideEmptyGroups', 'lastMarkingStyle',
    'loadCoverOnlyWifi', 'maxLengthWithNoToc', 'menuAlpha', 'moreActionsConfig',
    'mouseWheelPage', 'nextKeyCodes', 'paddingDisplayCutouts', 'pageTouchSlop',
    'prevKeyCodes', 'progressBarBehavior', 'readBodyToLh', 'read_slider_mode',
    'readingAnchorEnabled', 'selectVibrator', 'showBookIntro', 'showBookshelfFastScroller',
    'showReadTitleAddition', 'showRss', 'showSelectMenuIcon', 'sliderVibrator',
    'swipeToAddBookmark', 'system_typefaces', 'textBottomJustify', 'textFullJustify',
    'textSelectMenuConfig', 'themeMode', 'titleBarCompact', 'tocCountWords',
    'tocUiUseReplace', 'underlineExtend', 'underlinePadding', 'useDefaultCover',
    'useZhLayout', 'customTagColors', 'enableCustomTagColors'
  ]);
  /**
   * 97 个本地有真值、但从不写进 config.xml 的键，对应的上游 XML 标签类型。
   * 类型取自上游声明（PreferKey / domain-model settings 的各 Settings.kt），
   * 不是从样本 config.xml 反推——样本那台设备有 20 个键没设过。
   * 键集口径：四个 settings store 的 store.get/store.put 字面量键 ∩ PreferKey 去重值
   *   ∖ 已知写出 105 键 ∖ alwaysIgnoredPreferenceKeys。
   * 14 个颜色键本地存 "#RRGGBB" 字符串、上游是 int，这里类型标 "color"，
   * 写出前用 coverColorToAndroidInt 转 int（单独标一种，不与 int 混用）。
   * 本地 128 个自有键与 PreferKey 零撞名，故判据只需「在不在本表里」。
   */
  private static readonly missingPreferenceTypes: Map<string, string> = new Map<string, string>([
    ['shareLayout', 'boolean'], ['hideStatusBar', 'boolean'], ['hideNavigationBar', 'boolean'],
    ['readMenuFloatingBottomBar', 'boolean'], ['readMenuBottomBarLiquidGlassButtons', 'boolean'], ['readMenuTopBarTitleCapsule', 'boolean'],
    ['readMenuTopBarLiquidGlassButtons', 'boolean'], ['readMenuTopBarMergeButtons', 'boolean'], ['showTitleBarIcons', 'boolean'],
    ['readMenuFloatingIconLiquidGlass', 'boolean'], ['readBarStyleFollowPage', 'boolean'], ['showMenuIcon', 'boolean'],
    ['volumeKeyPage', 'boolean'], ['keyPageOnLongPress', 'boolean'], ['noAnimScrollPage', 'boolean'],
    ['selectText', 'boolean'], ['bookInfoFollowCoverColor', 'boolean'], ['enableBlur', 'boolean'],
    ['enableProgressiveBlur', 'boolean'], ['useFlexibleTopAppBar', 'boolean'], ['mergeTopBarActions', 'boolean'],
    ['showStatusBar', 'boolean'], ['swipeAnimation', 'boolean'], ['disableSplicedColumnGroupCornerRadius', 'boolean'],
    ['overrideBaseCardCornerRadius', 'boolean'], ['overrideBaseCardBorder', 'boolean'], ['enableItemDivider', 'boolean'],
    ['enableContainerBackgroundImage', 'boolean'], ['showHome', 'boolean'], ['showDiscovery', 'boolean'],
    ['showBottomView', 'boolean'], ['useFloatingBottomBar', 'boolean'], ['useFloatingBottomBarLiquidGlass', 'boolean'],
    ['autoReadSpeed', 'int'], ['readMenuBottomCornerRadius', 'int'], ['readMenuBottomBarBlurMode', 'int'],
    ['readMenuBottomBarBlurStyle', 'int'], ['readMenuBlurAlpha', 'int'], ['titleBarIconStyle', 'int'],
    ['readMenuTopBarBlurMode', 'int'], ['readMenuTopBarBlurStyle', 'int'], ['readBarStyle', 'int'],
    ['readMenuColorMode', 'int'], ['readMenuBgColor', 'color'], ['readMenuBgColorNight', 'color'],
    ['readMenuContainerColor', 'color'], ['readMenuContainerColorNight', 'color'], ['readMenuAccentColor', 'color'],
    ['readMenuAccentColorNight', 'color'], ['readMenuBorderWidth', 'int'], ['readMenuBorderColor', 'color'],
    ['readMenuBorderColorNight', 'color'], ['readMenuBlurRadius', 'int'], ['readMenuTextColor', 'color'],
    ['readMenuTextColorNight', 'color'], ['readMenuBlurColor', 'color'], ['readMenuBlurColorNight', 'color'],
    ['titleBarIconPosition', 'int'], ['containerOpacity', 'int'], ['backgroundImageBlurring', 'int'],
    ['backgroundImageNightBlurring', 'int'], ['topBarBlurRadius', 'int'], ['bottomBarBlurRadius', 'int'],
    ['topBarBlurAlpha', 'int'], ['bottomBarBlurAlpha', 'int'], ['topBarOpacity', 'int'],
    ['bottomBarOpacity', 'int'], ['fontScale', 'int'], ['baseCardBorderColorNight', 'color'],
    ['itemDividerColor', 'color'], ['readMenuLensRadius', 'float'], ['bottomBarLensRadius', 'float'],
    ['baseCardCornerRadius', 'float'], ['baseCardBorderWidth', 'float'], ['itemDividerWidth', 'float'],
    ['itemDividerLength', 'float'], ['titleBarMode', 'string'], ['readMenuPaletteStyle', 'string'],
    ['bookInfoNetworkCoverBackground', 'string'], ['bookInfoDefaultCoverBackground', 'string'], ['topBarButtonStyle', 'string'],
    ['screenOrientation', 'string'], ['largeContainerBackgroundImageLight', 'string'], ['largeContainerBackgroundImageDark', 'string'],
    ['itemBackgroundImageLight', 'string'], ['itemBackgroundImageDark', 'string'], ['defaultHomePage', 'string'],
    ['mainNavigationOrder', 'string'], ['labelVisibilityMode', 'string'], ['appFontPath', 'string'],
    ['readBrightnessMode', 'string'], ['readBrightnessControlPosition', 'string'], ['backgroundImage', 'string'],
    ['backgroundImageNight', 'string'], ['keep_light', 'string'], ['titleBarCustomIcons', 'string'],
    ['readMenuCustomIcons', 'string']
  ]);
  private static readonly preferenceKeysByCategory: AndroidPreferenceKeyGroups = {
    // 与上游 BackupConfig.kt:197-262 的 readPrefKeys 逐键一致（60 个）。
    // 上游 keyIsNotIgnore(:413) 对不在任何类别数组里的键落 else -> true，「取消该类别勾选」
    // 并不影响它们；这类键不能收进本数组，否则本地取消勾选会剔掉上游不剔的键。
    readConfig: [
      'readStyleSelect', 'comicStyleSelect', 'shareLayout', 'hideStatusBar', 'hideNavigationBar',
      'autoReadSpeed',
      'readBrightnessMode',
      'readBrightnessControlPosition', 'clickActionTopLeft',
      'clickActionTopCenter', 'clickActionTopRight', 'clickActionMiddleLeft', 'clickActionMiddleCenter',
      'clickActionMiddleRight', 'clickActionBottomLeft', 'clickActionBottomCenter', 'clickActionBottomRight',
      'readBarStyle', 'readBarStyleFollowPage', 'readMenuBgColor', 'readMenuAccentColor',
      'readMenuContainerColor', 'readMenuBgColorNight', 'readMenuAccentColorNight',
      'readMenuContainerColorNight', 'readMenuTextColor', 'readMenuTextColorNight', 'readMenuColorMode',
      'readMenuIconShowText', 'readMenuIconStyle', 'readMenuIconItemsPerRow', 'readMenuIconRowCount',
      'readMenuBottomCornerRadius', 'readMenuFloatingBottomBar', 'readMenuTopBarBlurMode',
      'readMenuBottomBarBlurMode', 'readMenuTopBarLiquidGlassButtons', 'readMenuTopBarMergeButtons',
      'readMenuTopBarTitleCapsule', 'readMenuBottomBarLiquidGlassButtons', 'readMenuFloatingIconLiquidGlass',
      'readMenuTopBarBlurStyle', 'readMenuBottomBarBlurStyle', 'readMenuBlurRadius', 'readMenuBlurAlpha',
      'readMenuBlurColor', 'readMenuBlurColorNight', 'readMenuPaletteStyle', 'readMenuLensRadius',
      'readMenuBorderWidth', 'readMenuBorderColor', 'readMenuBorderColorNight', 'readMenuCustomIcons',
      'titleBarIconStyle', 'titleBarCustomIcons', 'titleBarIconPosition', 'showTitleBarIcons',
      'showMenuIcon', 'titleBarMode', 'shouldShowExpandButton'
    ],
    themeConfig: [
      'colorPrimary', 'colorPrimaryNight', 'backgroundImage', 'backgroundImageBlurring',
      'backgroundImageNight', 'backgroundImageNightBlurring', 'colorMD3Primary', 'colorMD3Secondary',
      'colorMD3PrimaryNight', 'colorMD3SecondaryNight', 'paletteStyle', 'materialVersion',
      'composeEngine', 'customContrast', 'customMode', 'useMiuixMonet', 'containerOpacity',
      'topBarOpacity', 'bottomBarOpacity', 'enableBlur', 'enableProgressiveBlur', 'topBarBlurRadius',
      'bottomBarBlurRadius', 'topBarBlurAlpha', 'bottomBarBlurAlpha', 'bottomBarLensRadius',
      'useFlexibleTopAppBar', 'topBarButtonStyle', 'mergeTopBarActions', 'bookInfoFollowCoverColor',
      'bookInfoAuthorSearchFallback',
      'bookInfoBackgroundBlur', 'bookInfoNetworkCoverBackground', 'bookInfoDefaultCoverBackground',
      'colorBackground', 'colorBottomBackground', 'colorBackgroundNight', 'colorBottomBackgroundNight',
      'enableDeepPersonalization', 'colorMD3OnSurface', 'colorMD3OnPrimaryContainer', 'colorMD3Background',
      'colorMD3SurfaceContainerLow', 'colorMD3OnSurfaceNight', 'colorMD3OnPrimaryContainerNight',
      'colorMD3BackgroundNight', 'colorMD3SurfaceContainerLowNight', 'eyeProtectionEnabled',
      'colorTemperature', 'eyeProtectionAutoNight', 'eyeProtectionSchedule', 'eyeProtectionStartTime',
      'eyeProtectionEndTime'
    ],
    bookshelfLayout: [
      'bookshelfLayout', 'bookshelfLayoutPortrait', 'bookshelf_layout_landscape', 'bookshelfLayoutCompact',
      'bookshelfListCoverCenter', 'bookshelfListIntroBelowContent', 'bookshelfShowDivider',
      'bookshelfGridLayout', 'bookshelfSort', 'bookshelfSortOrder', 'bookshelfLayoutGridLandscape',
      'bookshelfLayoutGridPortrait', 'bookshelfLayoutListLandscape', 'bookshelfLayoutListPortrait',
      'bookshelfFolderLayoutModePortrait', 'bookshelfFolderLayoutModeLandscape',
      'bookshelfFolderLayoutGridPortrait', 'bookshelfFolderLayoutGridLandscape',
      'bookshelfFolderLayoutListPortrait', 'bookshelfFolderLayoutListLandscape', 'bookshelfTitleSmallFont',
      'bookshelfTitleCenter', 'bookshelfTitleMaxLines', 'bookshelfCoverShadow',
      'bookshelfSearchActionDirectToSearch', 'bookshelfCardColor', 'bookshelfCardColorDark',
      'bookshelfGroupListStyle', 'bookshelfGroupCoverCount', 'bookshelfListCoverWidth',
      'bookshelfGridCoverWidth', 'bookshelfRefreshingLimit', 'bookshelfShowIntro', 'bookshelfShowTag',
      'bookshelfShowCustomTags', 'bookshelfShowSourceTags', 'bookshelfShowWordCount',
      'bookshelfShowLatestChapter', 'bookshelfIntroMaxLines',
      'showUnread', 'showUnreadNew', 'showWaitUpCount', 'showBookCount',
      'showLastUpdateTime', 'showTip', 'bookshelfUpdateLimit', 'customTagColors', 'enableCustomTagColors'
    ],
    mangaConfig: [
      'showMangaUi', 'mangaScrollMode', 'webtoonSidePaddingDp', 'mangaPreDownloadNum',
      'mangaChapterPrefetchCount', 'mangaAutoOfflineCache', 'mangaAutoPageSpeed', 'mangaFooterConfig',
      'disableClickScroll', 'hideMangaTitle', 'mangaColorFilter', 'enableMangaEInk', 'mangaEInkThreshold',
      'enableMangaGray', 'doubleHorizontalPage', 'mouseWheelPage', 'disableMangaScale',
      'disableMangaScrollAnimation', 'disableMangaCrossFade', 'mangaVolumeKeyPage',
      'reverseVolumeKeyPage', 'mangaLongClick', 'mangaBackground', 'mangaClickActionTopLeft',
      'mangaClickActionTopCenter', 'mangaClickActionTopRight', 'mangaClickActionMiddleLeft',
      'mangaClickActionMiddleCenter', 'mangaClickActionMiddleRight', 'mangaClickActionBottomLeft',
      'mangaClickActionBottomCenter', 'mangaClickActionBottomRight'
    ],
    coverConfig: [
      'useDefaultCover', 'loadCoverOnlyWifi', 'coverShowName', 'coverShowAuthor', 'coverShowNameN',
      'coverShowAuthorN', 'coverShowShadow', 'coverShowStroke', 'coverTextColor', 'coverTextColorN',
      'coverShadowColor', 'coverShadowColorN', 'coverDefaultColor', 'coverInfoOrientation'
    ],
    themeMode: ['themeMode'],
    showRss: ['showRss'],
    threadCount: ['threadCount']
  };
  private static readonly fileNames: string[] = [
    'bookshelf.json', 'bookmark.json', 'bookMarking.json', 'bookGroup.json', 'bookSource.json',
    'rssSources.json', 'rssStar.json', 'replaceRule.json', 'readRecord.json',
    'readRecordDetail.json', 'readRecordSession.json', 'searchHistory.json', 'sourceSub.json',
    'txtTocRule.json', 'httpTTS.json', 'httpTtsVoices.json', 'keyboardAssists.json',
    'dictRule.json', 'homepageModules.json', 'homepageCustomSets.json', 'highlightRule.json',
    'highlightTagRule.json', 'tagGroupRule.json', 'servers.json', 'directLinkUploadRule.json',
    'readConfig.json', 'shareReadConfig.json', 'themeConfig.json', 'coverRule.json', 'config.xml'
  ];

  private static readonly categoryOptions: BackupCategoryOption[] = [
    { key: 'localBook', title: '本地书架记录', files: ['bookshelf.json'] },
    { key: 'readConfig', title: '阅读配置', files: ['readConfig.json', 'shareReadConfig.json', 'config.xml'], preferenceKeys: BackupRepository.preferenceKeysByCategory.readConfig },
    { key: 'themeMode', title: '深色模式', files: ['config.xml'], preferenceKeys: BackupRepository.preferenceKeysByCategory.themeMode },
    { key: 'themeConfig', title: '主题配置', files: ['themeConfig.json', 'config.xml'], preferenceKeys: BackupRepository.preferenceKeysByCategory.themeConfig },
    { key: 'coverConfig', title: '封面配置', files: ['coverRule.json', 'config.xml'], preferenceKeys: BackupRepository.preferenceKeysByCategory.coverConfig },
    { key: 'bookshelfLayout', title: '书架布局', files: ['config.xml'], preferenceKeys: BackupRepository.preferenceKeysByCategory.bookshelfLayout },
    { key: 'showRss', title: '显示订阅', files: ['config.xml'], preferenceKeys: BackupRepository.preferenceKeysByCategory.showRss },
    { key: 'threadCount', title: '线程数', files: ['config.xml'], preferenceKeys: BackupRepository.preferenceKeysByCategory.threadCount },
    { key: 'mangaConfig', title: '漫画配置', files: ['config.xml'], preferenceKeys: BackupRepository.preferenceKeysByCategory.mangaConfig },
    { key: 'bookmark', title: '书签、划线与笔记', files: ['bookmark.json', 'bookMarking.json'] },
    { key: 'bookGroup', title: '书架分组', files: ['bookGroup.json'] },
    { key: 'bookSource', title: '书源', files: ['bookSource.json'] },
    { key: 'rssSource', title: 'RSS 订阅源', files: ['rssSources.json'] },
    { key: 'rssStar', title: 'RSS 收藏', files: ['rssStar.json'] },
    { key: 'replaceRule', title: '替换净化规则', files: ['replaceRule.json'] },
    { key: 'readRecord', title: '阅读记录与会话', files: ['readRecord.json', 'readRecordDetail.json', 'readRecordSession.json'] },
    { key: 'searchHistory', title: '搜索历史', files: ['searchHistory.json'] },
    { key: 'sourceSub', title: '规则订阅', files: ['sourceSub.json'] },
    { key: 'txtTocRule', title: 'TXT 目录规则', files: ['txtTocRule.json'] },
    { key: 'httpTTS', title: '在线朗读源与音色', files: ['httpTTS.json', 'httpTtsVoices.json'] },
    { key: 'keyboardAssists', title: '按键映射', files: ['keyboardAssists.json'] },
    { key: 'dictRule', title: '字典规则', files: ['dictRule.json'] },
    { key: 'homepageModules', title: '首页模块', files: ['homepageModules.json'] },
    { key: 'homepageCustomSets', title: '首页自定义分组', files: ['homepageCustomSets.json'] },
    { key: 'highlightRule', title: '高亮规则', files: ['highlightRule.json'] },
    { key: 'highlightTagRule', title: '高亮标签规则', files: ['highlightTagRule.json'] },
    { key: 'tagGroupRule', title: '标签分组规则', files: ['tagGroupRule.json'] },
    { key: 'server', title: '服务器配置', files: ['servers.json'] }
  ];

  static categoryOptionsList(): BackupCategoryOption[] {
    return BackupRepository.categoryOptions;
  }

  static async loadRestoredEntries(context: Context): Promise<BackupEntryPreview[]> {
    try {
      const store = await preferences.getPreferences(context, BackupRepository.preferenceName);
      const value = await store.get(BackupRepository.restoredEntrySummaryKey, '');
      if (typeof value === 'string' && value.length > 0) {
        return BackupRepository.parseEntrySummary(value);
      }
    } catch (error) {
      console.error(`[BackupRepository] 读取恢复摘要失败: ${error}`);
    }
    const directory = `${context.filesDir}/${BackupRepository.legacyDirectoryName}`;
    let names: string[] = [];
    try { names = fileIo.listFileSync(directory); } catch (error) { console.error(`[BackupRepository] 列出旧版备份目录失败: ${error}`); return []; }
    const entries: BackupEntryPreview[] = [];
    for (let index = 0; index < names.length; index++) {
      const name = names[index];
      if (name === undefined || !BackupRepository.isSafeRootEntry(name)) { continue; }
      try {
        const path = `${directory}/${name}`;
        if (fileIo.lstatSync(path).isFile()) {
          entries.push({ name: name, recordCount: -1, byteSize: fileIo.statSync(path).size });
        }
      } catch (error) {
        console.error(`[BackupRepository] 读取旧版备份条目失败: ${error}`);
      }
    }
    return entries;
  }

  /**
   * 把本地 `themeMode` 归一成上游的字符串三值再写进 config.xml。
   *
   * 上游 `AppShellSettings.kt:4` 存的就是字符串 `"0"`/`"1"`/`"2"`，直接原样写；
   * 万一拿到的是旧口径的 number（向导早期版本存过 0/1/2），按同一映射换算，不写出非法值。
   */
  private static normalizeThemeModeForBackup(value: string): string {
    if (value === '1' || value === '2' || value === '0') { return value; }
    const numeric = Number(value);
    if (Number.isFinite(numeric)) { return ThemeSettingsRepository.fromModeNumber(numeric); }
    return ThemeSettingsRepository.fromModeNumber(0);
  }

  /**
   * 从 `config.xml` 读回全局深色模式。
   *
   * 与上游 `BackupConfig.keyIsNotIgnore` 对齐：`themeMode` 属于 `themeMode` 类别，
   * 该类被忽略时整键不恢复（返回 undefined，调用方保留当前值）。
   */
  private static restoreThemeMode(
    directory: string,
    ignoredCategories: string[]
  ): string | undefined {
    if (ignoredCategories.includes('themeMode')) { return undefined; }
    const path = `${directory}/config.xml`;
    const raw = BackupRepository.readXmlString(path, 'themeMode');
    if (raw === undefined) { return undefined; }
    const trimmed = raw.trim();
    if (trimmed === '0' || trimmed === '1' || trimmed === '2') { return trimmed; }
    return undefined;
  }

  /**
   * 从 `config.xml` 读回订阅入口开关，形态与 `restoreThemeMode` 一致。
   *
   * 上游 `BackupConfig.keyIsNotIgnore` 对 `showRss` 是单键门控；本地按类别整组剔键，
   * 勾了忽略（或归档里根本没有该键）就返回 undefined，让调用方保留当前值，不硬造默认值。
   */
  private static restoreShowRss(
    directory: string,
    ignoredCategories: string[]
  ): boolean | undefined {
    if (ignoredCategories.includes('showRss')) { return undefined; }
    return BackupRepository.readXmlBoolean(`${directory}/config.xml`, 'showRss');
  }

  private static preferenceKeysForCategory(key: string): string[] | undefined {
    if (key === 'readConfig') { return BackupRepository.preferenceKeysByCategory.readConfig; }
    if (key === 'themeConfig') { return BackupRepository.preferenceKeysByCategory.themeConfig; }
    if (key === 'bookshelfLayout') { return BackupRepository.preferenceKeysByCategory.bookshelfLayout; }
    if (key === 'mangaConfig') { return BackupRepository.preferenceKeysByCategory.mangaConfig; }
    if (key === 'coverConfig') { return BackupRepository.preferenceKeysByCategory.coverConfig; }
    if (key === 'themeMode') { return BackupRepository.preferenceKeysByCategory.themeMode; }
    if (key === 'showRss') { return BackupRepository.preferenceKeysByCategory.showRss; }
    if (key === 'threadCount') { return BackupRepository.preferenceKeysByCategory.threadCount; }
    return undefined;
  }

  static async loadIgnoreLists(context: Context): Promise<BackupIgnoreLists> {
    const defaults: BackupIgnoreLists = { backup: [], restore: [] };
    try {
      const store = await preferences.getPreferences(context, BackupRepository.preferenceName);
      const backupValue = await store.get('backupIgnore', '');
      const restoreValue = await store.get('restoreIgnore', '');
      return {
        backup: typeof backupValue === 'string' ? BackupRepository.parseIgnoreList(backupValue) : [],
        restore: typeof restoreValue === 'string' ? BackupRepository.parseIgnoreList(restoreValue) : []
      };
    } catch (error) {
      console.error(`[BackupRepository] 读取忽略名单失败: ${error}`);
      return defaults;
    }
  }

  static async saveIgnoreLists(context: Context, value: BackupIgnoreLists): Promise<void> {
    const store = await preferences.getPreferences(context, BackupRepository.preferenceName);
    await store.put('backupIgnore', value.backup.join('\n'));
    await store.put('restoreIgnore', value.restore.join('\n'));
    await store.flush();
  }

  /**
   * 生成本地备份：先生成 ZIP 到缓存，再由系统 picker 拷到用户选的位置。
   * 「生成」与「picker」分离，是为了让 WebDAV 备份复用同一份归档（见 buildBackupArchive）。
   * 用户取消 picker 时返回 false，不抛异常。
   */
  static async createBackup(
    context: Context,
    books: Book[],
    settings: ReaderSettingsSnapshot,
    bookshelfLayout: BookshelfLayoutSettings,
    ignoredCategories: string[],
    themeMode: string,
    paletteIndex: number,
    customTheme: CustomThemeSnapshot
  ): Promise<boolean> {
    const zipPath = await BackupRepository.buildBackupArchive(context, books, settings,
      bookshelfLayout, ignoredCategories, themeMode, paletteIndex, customTheme);
    try {
      const options = new picker.DocumentSaveOptions();
      options.newFileNames = [`backup${BackupRepository.currentDate()}.zip`];
      options.fileSuffixChoices = ['Legado Android 兼容备份|.zip'];
      const uris = await new picker.DocumentViewPicker(context).save(options);
      const uri = uris[0];
      if (uri === undefined) { return false; }
      const input = fileIo.openSync(zipPath, fileIo.OpenMode.READ_ONLY);
      try {
        const output = fileIo.openSync(uri, fileIo.OpenMode.WRITE_ONLY | fileIo.OpenMode.TRUNC);
        try {
          fileIo.copyFileSync(input.fd, output.fd);
        } finally {
          fileIo.closeSync(output);
        }
      } finally {
        fileIo.closeSync(input);
      }
      return true;
    } finally {
      try { fileIo.unlinkSync(zipPath); } catch (error) { console.error(`[BackupRepository] 删除备份临时包失败: ${error}`); }
    }
  }

  /**
   * 生成 Android 兼容备份 ZIP 到缓存目录，返回其路径。
   * 调用方负责删除返回的 zip（本地备份 picker 拷走后删、WebDAV 备份上传后删）；
   * staging 工作目录在本方法内部清理。生成失败时未交出的临时 zip 也在这里兜底删除。
   * 公开（非 private）以便 pages/Index.ets 的 WebDAV 备份路径直接调用。
   */
  static async buildBackupArchive(
    context: Context,
    books: Book[],
    settings: ReaderSettingsSnapshot,
    bookshelfLayout: BookshelfLayoutSettings,
    ignoredCategories: string[],
    themeMode: string,
    paletteIndex: number,
    customTheme: CustomThemeSnapshot
  ): Promise<string> {
    const stagingDirectory = `${context.cacheDir}/legado-android-backup-${Date.now()}`;
    const zipPath = `${context.cacheDir}/legado-android-backup-${Date.now()}.zip`;
    BackupRepository.ensureDirectory(stagingDirectory);
    let handedOff = false;
    try {
      await BookGroupRepository.load(context);
      await BackupRepository.copyPreservedEntries(context, stagingDirectory, ignoredCategories);
      // 与上游 Backup.kt:150-154 一致：bookshelf.json 总是写，忽略 localBook 时只滤掉本地书，
      // 其余书照写；滤完为空才不写（上游 writeListToJson 只在 list.isNotEmpty() 时落盘）。
      const ignoreLocalBook = ignoredCategories.includes('localBook');
      const shelfBooks = books
        .filter((book: Book) => BookRepository.isPersistableBook(book))
        .filter((book: Book) => !(ignoreLocalBook && book.isLocal));
      if (shelfBooks.length > 0) {
        const records = shelfBooks.map((book: Book, index: number) =>
          BackupRepository.toAndroidBookRecord(book, index));
        const generated = JSON.stringify(records);
        const oldPath = `${stagingDirectory}/bookshelf.json`;
        const combined = fileIo.accessSync(oldPath)
          ? BackupRepository.mergeAndroidBookshelf(fileIo.readTextSync(oldPath), generated)
          : generated;
        BackupRepository.writeTextFile(oldPath, combined);
      }

      if (!ignoredCategories.includes('bookGroup')) {
        BackupRepository.writeTextFile(`${stagingDirectory}/bookGroup.json`, BookGroupRepository.exportAndroidGroups());
      }
      // 书源：上游 Backup.kt:163-164 的 writeListToJson 只在 list 非空时建文件，本地照抄。
      if (!ignoredCategories.includes('bookSource')) {
        const rules = await BookSourceRepository.load(context);
        if (rules.length > 0) {
          BackupRepository.writeTextFile(`${stagingDirectory}/bookSource.json`,
            BookSourceRepository.exportRules(rules));
        }
      }
      // RSS 订阅源：同上。
      if (!ignoredCategories.includes('rssSource')) {
        const rules = await RssSourceRepository.load(context);
        if (rules.length > 0) {
          BackupRepository.writeTextFile(`${stagingDirectory}/rssSources.json`,
            RssSourceRepository.exportRules(rules));
        }
      }
      // RSS 收藏：同上。
      if (!ignoredCategories.includes('rssStar')) {
        const rules = await RssStarRepository.load(context);
        if (rules.length > 0) {
          BackupRepository.writeTextFile(`${stagingDirectory}/rssStar.json`,
            RssStarRepository.exportRules(rules));
        }
      }
      // 规则订阅：上游 Backup.kt:183-185 写出 sourceSub.json，内容来自 ruleSubs 表。
      if (!ignoredCategories.includes('sourceSub')) {
        const rules = await RuleSubRepository.load(context);
        if (rules.length > 0) {
          BackupRepository.writeTextFile(`${stagingDirectory}/sourceSub.json`,
            RuleSubRepository.exportRules(rules));
        }
      }

      // 服务器配置：上游 Backup.kt:220-229 是 GSON 序列化后 aes.encryptBase64 写出。
      // 这里同样加密，但加密失败时回退写明文 —— 上游用的是
      // aes.runCatching { encryptBase64(it) }.getOrDefault(it)，语义就是「加密环境坏了也别丢备份」。
      // 注意：copyPreservedEntries 会先把保留目录里的旧 servers.json 拷进 staging，
      // 这里表非空时用 writeTextFile(TRUNC) 覆盖；表空则不写，让旧密文原样带走。
      if (!ignoredCategories.includes('server')) {
        const servers = await ServerRepository.load(context);
        if (servers.length > 0) {
          const plain = ServerRepository.exportServers(servers);
          let payload = plain;
          try {
            payload = aesEcbEncryptToBase64(plain, aesEcKeyFromPassword(''));
          } catch (error) {
            console.error(`[BackupRepository] 服务器配置加密失败，回退明文写出: ${error}`);
          }
          BackupRepository.writeTextFile(`${stagingDirectory}/servers.json`, payload);
        }
      }

      if (!ignoredCategories.includes('readConfig')) {
        const config = BackupRepository.toAndroidReadConfig(settings);
        const readerConfigPath = `${stagingDirectory}/readConfig.json`;
        const sharedConfigPath = `${stagingDirectory}/shareReadConfig.json`;
        if (!fileIo.accessSync(readerConfigPath)) {
          BackupRepository.writeTextFile(readerConfigPath, JSON.stringify([config]));
        }
        if (!fileIo.accessSync(sharedConfigPath)) {
          BackupRepository.writeTextFile(sharedConfigPath, JSON.stringify(config));
        }
      }

      const configPath = `${stagingDirectory}/config.xml`;
      if (!fileIo.accessSync(configPath)) {
        BackupRepository.writeTextFile(configPath,
          "<?xml version='1.0' encoding='utf-8' standalone='yes' ?>\n<map>\n</map>");
      }

      // bookGroupStyle / hideEmptyGroups / showBookIntro 不在上游 bookshelfPrefKeys 39 键内，
      // 走 keyIsNotIgnore 的 else -> true，不受任何类别开关控制（KI-SL-A11 / KI-SL-B1）。
      // coverRestrictRatio / explore_filter_state 同理：不在 14 个 coverPrefKeys 里、也不在
      // alwaysIgnoredPreferenceKeys，所以随 config.xml 无条件导出（ZIP-COVER E2 / E3 判 `—`）。
      const coverSettings = CoverSettingsRepository.get();
      let unconditionalText = fileIo.readTextSync(configPath);
      unconditionalText = BackupRepository.upsertAndroidPreference(unconditionalText, 'int', 'bookGroupStyle', `${bookshelfLayout.bookGroupStyle}`);
      unconditionalText = BackupRepository.upsertAndroidPreference(unconditionalText, 'boolean', 'hideEmptyGroups', `${bookshelfLayout.hideEmptyGroups}`);
      unconditionalText = BackupRepository.upsertAndroidPreference(unconditionalText, 'boolean', 'showBookIntro', `${bookshelfLayout.showBookIntro}`);
      unconditionalText = BackupRepository.upsertAndroidPreference(unconditionalText, 'boolean', 'coverRestrictRatio', `${coverSettings.restrictCoverRatio}`);
      unconditionalText = BackupRepository.upsertAndroidPreference(unconditionalText, 'int', 'explore_filter_state', `${coverSettings.exploreFilterState}`);
      BackupRepository.writeTextFile(configPath, unconditionalText);

      if (!ignoredCategories.includes('bookshelfLayout')) {
        let configText = fileIo.readTextSync(configPath);
        configText = BackupRepository.upsertAndroidPreference(configText, 'int', 'bookshelfSort', `${bookshelfLayout.bookshelfSort}`);
        configText = BackupRepository.upsertAndroidPreference(configText, 'int', 'bookshelfSortOrder', `${bookshelfLayout.bookshelfSortOrder}`);
        configText = BackupRepository.upsertAndroidPreference(configText, 'int', 'bookshelfLayoutPortrait', `${bookshelfLayout.bookshelfLayoutModePortrait}`);
        configText = BackupRepository.upsertAndroidPreference(configText, 'int', 'bookshelfLayoutGridPortrait', `${bookshelfLayout.bookshelfLayoutGridPortrait}`);
        configText = BackupRepository.upsertAndroidPreference(configText, 'int', 'bookshelfLayoutListPortrait', `${bookshelfLayout.bookshelfLayoutListPortrait}`);
        configText = BackupRepository.upsertAndroidPreference(configText, 'int', 'bookshelfTitleMaxLines', `${bookshelfLayout.bookshelfTitleMaxLines}`);
        configText = BackupRepository.upsertAndroidPreference(configText, 'boolean', 'bookshelfCoverShadow', `${bookshelfLayout.bookshelfCoverShadow}`);
        configText = BackupRepository.upsertAndroidPreference(configText, 'boolean', 'bookshelfTitleCenter', `${bookshelfLayout.bookshelfTitleCenter}`);
        configText = BackupRepository.upsertAndroidPreference(configText, 'boolean', 'bookshelfTitleSmallFont', `${bookshelfLayout.bookshelfTitleSmallFont}`);
        configText = BackupRepository.upsertAndroidPreference(configText, 'int', 'bookshelfGridCoverWidth', `${bookshelfLayout.bookshelfGridCoverWidth}`);
        configText = BackupRepository.upsertAndroidPreference(configText, 'int', 'bookshelfListCoverWidth', `${bookshelfLayout.bookshelfListCoverWidth}`);
        configText = BackupRepository.upsertAndroidPreference(configText, 'int', 'bookshelfGridLayout', `${bookshelfLayout.bookshelfGridLayout}`);
        configText = BackupRepository.upsertAndroidPreference(configText, 'boolean', 'bookshelfLayoutCompact', `${bookshelfLayout.bookshelfLayoutCompact}`);
        configText = BackupRepository.upsertAndroidPreference(configText, 'int', 'bookshelfCardColor', `${bookshelfLayout.bookshelfCardColor}`);
        configText = BackupRepository.upsertAndroidPreference(configText, 'int', 'bookshelfCardColorDark', `${bookshelfLayout.bookshelfCardColorDark}`);
        configText = BackupRepository.upsertAndroidPreference(configText, 'boolean', 'bookshelfShowDivider', `${bookshelfLayout.bookshelfShowDivider}`);
        configText = BackupRepository.upsertAndroidPreference(configText, 'boolean', 'bookshelfListCoverCenter', `${bookshelfLayout.bookshelfListCoverCenter}`);
        configText = BackupRepository.upsertAndroidPreference(configText, 'boolean', 'bookshelfListIntroBelowContent', `${bookshelfLayout.bookshelfListIntroBelowContent}`);
        configText = BackupRepository.upsertAndroidPreference(configText, 'boolean', 'bookshelfShowIntro', `${bookshelfLayout.bookshelfShowIntro}`);
        configText = BackupRepository.upsertAndroidPreference(configText, 'boolean', 'bookshelfShowLatestChapter', `${bookshelfLayout.bookshelfShowLatestChapter}`);
        configText = BackupRepository.upsertAndroidPreference(configText, 'int', 'bookshelfIntroMaxLines', `${bookshelfLayout.bookshelfIntroMaxLines}`);
        configText = BackupRepository.upsertAndroidPreference(configText, 'boolean', 'bookshelfSearchActionDirectToSearch', `${bookshelfLayout.bookshelfSearchActionDirectToSearch}`);
        configText = BackupRepository.upsertAndroidPreference(configText, 'boolean', 'showBookshelfFastScroller', `${bookshelfLayout.showBookshelfFastScroller}`);
        configText = BackupRepository.upsertAndroidPreference(configText, 'boolean', 'auto_refresh', `${bookshelfLayout.autoRefreshBook}`);
        configText = BackupRepository.upsertAndroidPreference(configText, 'long', 'bookshelfSelectedGroupId', `${bookshelfLayout.saveTabPosition}`);
        configText = BackupRepository.upsertAndroidPreference(configText, 'int', 'bookshelf_layout_landscape', `${bookshelfLayout.bookshelfLayoutModeLandscape}`);
        configText = BackupRepository.upsertAndroidPreference(configText, 'int', 'bookshelfLayoutGridLandscape', `${bookshelfLayout.bookshelfLayoutGridLandscape}`);
        configText = BackupRepository.upsertAndroidPreference(configText, 'int', 'bookshelfLayoutListLandscape', `${bookshelfLayout.bookshelfLayoutListLandscape}`);
        configText = BackupRepository.upsertAndroidPreference(configText, 'int', 'bookshelfFolderLayoutModePortrait', `${bookshelfLayout.bookshelfFolderLayoutModePortrait}`);
        configText = BackupRepository.upsertAndroidPreference(configText, 'int', 'bookshelfFolderLayoutModeLandscape', `${bookshelfLayout.bookshelfFolderLayoutModeLandscape}`);
        configText = BackupRepository.upsertAndroidPreference(configText, 'int', 'bookshelfFolderLayoutGridPortrait', `${bookshelfLayout.bookshelfFolderLayoutGridPortrait}`);
        configText = BackupRepository.upsertAndroidPreference(configText, 'int', 'bookshelfFolderLayoutGridLandscape', `${bookshelfLayout.bookshelfFolderLayoutGridLandscape}`);
        configText = BackupRepository.upsertAndroidPreference(configText, 'int', 'bookshelfFolderLayoutListPortrait', `${bookshelfLayout.bookshelfFolderLayoutListPortrait}`);
        configText = BackupRepository.upsertAndroidPreference(configText, 'int', 'bookshelfFolderLayoutListLandscape', `${bookshelfLayout.bookshelfFolderLayoutListLandscape}`);
        configText = BackupRepository.upsertAndroidPreference(configText, 'int', 'bookshelfGroupListStyle', `${bookshelfLayout.bookshelfGroupListStyle}`);
        configText = BackupRepository.upsertAndroidPreference(configText, 'int', 'bookshelfGroupCoverCount', `${bookshelfLayout.bookshelfGroupCoverCount}`);
        configText = BackupRepository.upsertAndroidPreference(configText, 'int', 'bookshelfRefreshingLimit', `${bookshelfLayout.bookshelfRefreshingLimit}`);
        configText = BackupRepository.upsertAndroidPreference(configText, 'boolean', 'shouldShowExpandButton', `${bookshelfLayout.showBookshelfTabMenu}`);
        configText = BackupRepository.upsertAndroidPreference(configText, 'boolean', 'bookshelfShowTag', `${bookshelfLayout.bookshelfShowTag}`);
        configText = BackupRepository.upsertAndroidPreference(configText, 'boolean', 'bookshelfShowCustomTags', `${bookshelfLayout.bookshelfShowCustomTags}`);
        configText = BackupRepository.upsertAndroidPreference(configText, 'boolean', 'bookshelfShowSourceTags', `${bookshelfLayout.bookshelfShowSourceTags}`);
        configText = BackupRepository.upsertAndroidPreference(configText, 'boolean', 'bookshelfShowWordCount', `${bookshelfLayout.bookshelfShowWordCount}`);
        configText = BackupRepository.upsertAndroidPreference(configText, 'boolean', 'showUnread', `${bookshelfLayout.showUnread}`);
        configText = BackupRepository.upsertAndroidPreference(configText, 'boolean', 'showUnreadNew', `${bookshelfLayout.showUnreadNew}`);
        configText = BackupRepository.upsertAndroidPreference(configText, 'boolean', 'showWaitUpCount', `${bookshelfLayout.showWaitUpCount}`);
        configText = BackupRepository.upsertAndroidPreference(configText, 'boolean', 'showBookCount', `${bookshelfLayout.showBookCount}`);
        configText = BackupRepository.upsertAndroidPreference(configText, 'boolean', 'showLastUpdateTime', `${bookshelfLayout.showLastUpdateTime}`);
        configText = BackupRepository.upsertAndroidPreference(configText, 'boolean', 'showTip', `${bookshelfLayout.showTip}`);
        configText = BackupRepository.upsertAndroidPreference(configText, 'int', 'bookshelfUpdateLimit', `${bookshelfLayout.bookshelfRefreshingLimit}`);
        configText = BackupRepository.upsertAndroidPreference(configText, 'string', 'customTagColors', bookshelfLayout.customTagColorsJson);
        configText = BackupRepository.upsertAndroidPreference(configText, 'boolean', 'enableCustomTagColors', `${bookshelfLayout.enableCustomTagColors}`);
        BackupRepository.writeTextFile(configPath, configText);
      }

      // 替换净化规则是本地权威数据（存在 preferences 里），归档目录里不会有，
      // 所以未忽略该分类时由这里生成，格式与上游 replaceRule.json 一致，可被 Android 直接读回。
      // 始终写出当前规则快照，包括空数组，避免旧归档残留已删除规则。
      if (!ignoredCategories.includes('replaceRule')) {
        const rules = ReplaceRuleRepository.getAll();
        BackupRepository.writeTextFile(`${stagingDirectory}/replaceRule.json`,
          ReplaceRuleRepository.exportRules(rules));
      }
      if (!ignoredCategories.includes('txtTocRule')) {
        const rules = TxtTocRuleRepository.getAll();
        BackupRepository.writeTextFile(`${stagingDirectory}/txtTocRule.json`,
          TxtTocRuleRepository.exportRules(rules));
      }
      // 高亮规则同样只存在 preferences 里。缓存要先进过阅读页才会填充，
      // 备份前必须 await load()，否则没读过书的用户会导出一份空数组。
      if (!ignoredCategories.includes('highlightRule')) {
        const highlightRules = await ReaderHighlightRuleRepository.load(context);
        BackupRepository.writeTextFile(`${stagingDirectory}/highlightRule.json`,
          ReaderHighlightRuleRepository.exportRules(highlightRules));
      }
      // G2 字典规则：上游 Backup.kt 的 writeListToJson 只在 list 非空时建文件，
      // 本地照抄——空表不写，避免多产一个自己没内容的空文件，也让上次透传件原样带走。
      if (!ignoredCategories.includes('dictRule')) {
        const rules = await DictRuleRepository.load(context);
        if (rules.length > 0) {
          BackupRepository.writeTextFile(`${stagingDirectory}/dictRule.json`,
            DictRuleRepository.exportRules(rules));
        }
      }
      // G2 首页模块：上游 Backup.kt 的 writeListToJson 只在 list 非空时建文件，
      // 本地照抄——空表不写，避免多产一个自己没内容的空文件，也让上次透传件原样带走。
      if (!ignoredCategories.includes('homepageModules')) {
        const rules = await HomepageModuleRepository.load(context);
        if (rules.length > 0) {
          BackupRepository.writeTextFile(`${stagingDirectory}/homepageModules.json`,
            HomepageModuleRepository.exportRules(rules));
        }
      }
      // G2 首页自定义集：上游 Backup.kt 的 writeListToJson 只在 list 非空时建文件，
      // 本地照抄——空表不写，避免多产一个自己没内容的空文件，也让上次透传件原样带走。
      if (!ignoredCategories.includes('homepageCustomSets')) {
        const rules = await HomepageCustomSetRepository.load(context);
        if (rules.length > 0) {
          BackupRepository.writeTextFile(`${stagingDirectory}/homepageCustomSets.json`,
            HomepageCustomSetRepository.exportRules(rules));
        }
      }
      // G2 标签高亮规则：上游 Backup.kt 的 writeListToJson 只在 list 非空时建文件，
      // 本地照抄——空表不写，避免多产一个自己没内容的空文件，也让上次透传件原样带走。
      if (!ignoredCategories.includes('highlightTagRule')) {
        const rules = await HighlightTagRuleRepository.load(context);
        if (rules.length > 0) {
          BackupRepository.writeTextFile(`${stagingDirectory}/highlightTagRule.json`,
            HighlightTagRuleRepository.exportRules(rules));
        }
      }
      // G2 标签分组规则：上游 Backup.kt 的 writeListToJson 只在 list 非空时建文件，
      // 本地照抄——空表不写，避免多产一个自己没内容的空文件，也让上次透传件原样带走。
      if (!ignoredCategories.includes('tagGroupRule')) {
        const rules = await TagGroupRuleRepository.load(context);
        if (rules.length > 0) {
          BackupRepository.writeTextFile(`${stagingDirectory}/tagGroupRule.json`,
            TagGroupRuleRepository.exportRules(rules));
        }
      }
      // 书签与笔记同样只存在 preferences 里。上游 Backup.kt 在 bookmark 分类下
      // 一次写出 bookmark.json 与 bookMarking.json 两份，这里保持同名同结构，
      // 让 Android 版恢复时能直接 insert 进 bookmarks / book_marks 两张表。
      if (!ignoredCategories.includes('bookmark')) {
        const bookmarks = await ReaderBookmarkRepository.load(context);
        const markings = await ReaderMarkingRepository.load(context);
        BackupRepository.writeTextFile(`${stagingDirectory}/bookmark.json`,
          ReaderBookmarkExporter.toAndroidBookmarkArray(bookmarks));
        BackupRepository.writeTextFile(`${stagingDirectory}/bookMarking.json`,
          ReaderBookmarkExporter.toAndroidMarkingArray(markings));
      }

      // 阅读记录三张表：字段名与上游 Room 实体一致，会话的 words 对应本地 chapterIndex。
      // 三个 load* 都是 async，所以这一段要 await；分类被忽略时整段不写。
      if (!ignoredCategories.includes('readRecord')) {
        const snapshot = await ReadRecordRepository.exportForBackup(context);
        BackupRepository.writeTextFile(`${stagingDirectory}/readRecord.json`,
          JSON.stringify(snapshot.summaries));
        BackupRepository.writeTextFile(`${stagingDirectory}/readRecordDetail.json`,
          JSON.stringify(snapshot.details));
        const sessionLines: AndroidReadRecordSessionRecord[] = [];
        for (const item of snapshot.sessions) {
          const row: AndroidReadRecordSessionRecord = {
            deviceId: item.deviceId, bookName: item.bookName, bookAuthor: item.bookAuthor,
            bookUrl: item.bookUrl, startTime: item.startTime, endTime: item.endTime,
            words: item.chapterIndex
          };
          sessionLines.push(row);
        }
        BackupRepository.writeTextFile(`${stagingDirectory}/readRecordSession.json`,
          JSON.stringify(sessionLines));
      }

      if (!ignoredCategories.includes('readConfig')) {
        let configText = fileIo.readTextSync(configPath);
        configText = BackupRepository.upsertAndroidPreference(
          configText, 'int', 'system_typefaces', `${settings.systemTypefaces}`);
        configText = BackupRepository.upsertAndroidPreference(
          configText, 'boolean', 'textFullJustify', `${settings.textFullJustify}`);
        configText = BackupRepository.upsertAndroidPreference(
          configText, 'boolean', 'textBottomJustify', `${settings.textBottomJustify}`);
        // 文字样式（textBold / textItalic / textShadow / shadow* / underline* / dottedLine 共 13 项）
        // 不写进 config.xml：上游这些不是 PreferKey 常量，属 ReadBookConfig 的字段域，
        // 它们的家是上面 readConfig.json 的 toAndroidReadConfig。
        // 恢复侧仍然双读（JSON 优先、config.xml 兜底），删这里不丢能力。
        configText = BackupRepository.upsertAndroidPreference(
          configText, 'int', 'underlinePadding', `${settings.underlinePadding}`);
        configText = BackupRepository.upsertAndroidPreference(
          configText, 'boolean', 'underlineExtend', settings.underlineExtend ? 'true' : 'false');
        // 自定义翻页按键与滚轮翻页：上游这几个键不在 BackupConfig.readPrefKeys
        // 忽略清单里，随 config.xml 无条件备份。存储键用 prevKeyCodes/nextKeyCodes。
        configText = BackupRepository.upsertAndroidPreference(
          configText, 'string', 'prevKeyCodes', settings.prevKeys);
        configText = BackupRepository.upsertAndroidPreference(
          configText, 'string', 'nextKeyCodes', settings.nextKeys);
        configText = BackupRepository.upsertAndroidPreference(
          configText, 'boolean', 'mouseWheelPage', settings.mouseWheelPage ? 'true' : 'false');
        // 划词菜单三项：上游同样不在 BackupConfig.readPrefKeys 忽略清单里，随 config.xml 无条件备份。
        configText = BackupRepository.upsertAndroidPreference(
          configText, 'boolean', 'expandTextMenu', settings.expandTextMenu ? 'true' : 'false');
        configText = BackupRepository.upsertAndroidPreference(
          configText, 'boolean', 'showSelectMenuIcon', settings.showSelectMenuIcon ? 'true' : 'false');
        configText = BackupRepository.upsertAndroidPreference(
          configText, 'string', 'textSelectMenuConfig', settings.textSelectMenuConfig);
        // 横屏双页：上游不在 BackupConfig.readPrefKeys 忽略清单里，随 config.xml 无条件备份。
        configText = BackupRepository.upsertAndroidPreference(
          configText, 'string', 'doubleHorizontalPage', settings.doubleHorizontalPage);
        configText = BackupRepository.upsertAndroidPreference(
          configText, 'boolean', 'autoSuggestDayNight', settings.autoSuggestDayNight ? 'true' : 'false');
        // 禁用返回键：上游不在 BackupConfig.readPrefKeys 忽略清单里，随 config.xml 无条件备份。
        configText = BackupRepository.upsertAndroidPreference(
          configText, 'boolean', 'disableReturnKey', settings.disableReturnKey ? 'true' : 'false');
        // 阅读亮度：亮度与自动亮度不在 BackupConfig.readPrefKeys 忽略清单里，随 config.xml 备份；
        // 亮度条形态与位置在忽略清单里（ReadSettingsRepository 的 readBrightnessMode/readBrightnessControlPosition），不导出。
        configText = BackupRepository.upsertAndroidPreference(
          configText, 'int', 'brightness', `${Math.max(1, Math.min(100, Math.round(settings.readBrightness)))}`);
        configText = BackupRepository.upsertAndroidPreference(
          configText, 'boolean', 'brightnessAuto', settings.brightnessAuto ? 'true' : 'false');
    // 正文渲染适配四项：上游四个键都不在 BackupConfig.readPrefKeys 忽略清单里，随 config.xml 无条件备份。
    configText = BackupRepository.upsertAndroidPreference(
          configText, 'boolean', 'readBodyToLh', settings.readBodyToLh ? 'true' : 'false');
    configText = BackupRepository.upsertAndroidPreference(
          configText, 'boolean', 'useZhLayout', settings.useZhLayout ? 'true' : 'false');
    configText = BackupRepository.upsertAndroidPreference(
          configText, 'boolean', 'paddingDisplayCutouts', settings.paddingDisplayCutouts ? 'true' : 'false');
    configText = BackupRepository.upsertAndroidPreference(
          configText, 'boolean', 'adaptSpecialStyle', settings.adaptSpecialStyle ? 'true' : 'false');
        configText = BackupRepository.upsertAndroidPreference(
          configText, 'float', 'dottedBase', `${settings.dottedBase}`);
        configText = BackupRepository.upsertAndroidPreference(
          configText, 'float', 'dottedRatio', `${settings.dottedRatio}`);
        // underlineColor / underlineColorNight 同属上面 13 项文字样式，家在 readConfig.json，不写进 config.xml。
        // 上游把书签角标的两项存在 AppConfigStore 偏好里，随 config.xml 一起备份。
        configText = BackupRepository.upsertAndroidPreference(
          configText, 'boolean', 'readingAnchorEnabled', `${settings.readingAnchorEnabled}`);
        configText = BackupRepository.upsertAndroidPreference(
          configText, 'boolean', 'swipeToAddBookmark', `${settings.swipeToAddBookmark}`);
        configText = BackupRepository.upsertAndroidPreference(
          configText, 'int', 'bookmarkBadgeSize', `${Math.max(0, Math.min(50, Math.round(settings.bookmarkBadgeSize)))}`);
        configText = BackupRepository.upsertAndroidPreference(
          configText, 'string', 'bookmarkBadgeImage', settings.bookmarkBadgeImage);
        // 上游 PreferKey.read_slider_mode（带下划线）/ pageTouchSlop 不在
        // BackupConfig.readPrefKeys 忽略清单里，属于「无条件随 config.xml 备份」的键，
        // 这里按同样口径导出。本地 preferences 内部字段仍叫 readSliderMode，不改键名。
        configText = BackupRepository.upsertAndroidPreference(
          configText, 'string', 'read_slider_mode', settings.readSliderMode === '1' ? '1' : '0');
        configText = BackupRepository.upsertAndroidPreference(
          configText, 'int', 'pageTouchSlop', `${Math.max(0, Math.min(1000, Math.round(settings.pageTouchSlop)))}`);
        configText = BackupRepository.upsertAndroidPreference(
          configText, 'string', 'lastMarkingStyle', settings.lastMarkingStyle);
        // 两个触感开关同样不在 readPrefKeys 忽略清单里，随 config.xml 无条件导出。
        configText = BackupRepository.upsertAndroidPreference(
          configText, 'boolean', 'sliderVibrator', String(settings.sliderVibrator));
        configText = BackupRepository.upsertAndroidPreference(
          configText, 'boolean', 'selectVibrator', String(settings.selectVibrator));
        // 简繁转换档位同样不在 readPrefKeys 忽略清单里，随 config.xml 无条件导出。
        configText = BackupRepository.upsertAndroidPreference(
          configText, 'int', 'chineseConverterType',
          `${Math.max(0, Math.min(2, Math.round(settings.chineseConverterType)))}`);
        // 标题栏精简：上游 BackupConfig.readPrefKeys（BackupConfig.kt:197-261）没有列 titleBarCompact，
        // 因此它随 config.xml 无条件备份；同组的另外七项都在忽略清单里，不导出。
        configText = BackupRepository.upsertAndroidPreference(
          configText, 'boolean', 'titleBarCompact', settings.titleBarCompact ? 'true' : 'false');
        // 更多操作配置：上游 readPrefKeys 里同样没有 moreActionsConfig，随 config.xml 无条件备份。
        // 值形如 `id,enabled;id,enabled`（上游 ReadButtonConfigDelegate.kt:75-84 saveMoreActions）。
        configText = BackupRepository.upsertAndroidPreference(
          configText, 'string', 'moreActionsConfig', settings.moreActionsConfig);
        // 「展示顶部工具栏附加区域」与「菜单不透明度」：上游 readPrefKeys 同样没有列这两项，
        // 随 config.xml 无条件备份（showMenuIcon 在忽略清单 BackupConfig.kt:258 里，故不导出）。
        configText = BackupRepository.upsertAndroidPreference(
          configText, 'boolean', 'showReadTitleAddition', settings.showReadTitleAddition ? 'true' : 'false');
        configText = BackupRepository.upsertAndroidPreference(
          configText, 'int', 'menuAlpha', `${Math.max(0, Math.min(100, Math.round(settings.menuAlpha)))}`);
        // 补写 5 个 config.xml 键：progressBarBehavior / tocUiUseReplace / tocCountWords /
        // clickImgWay / maxLengthWithNoToc。恢复侧只读这些键，写出侧此前未写。
        configText = BackupRepository.upsertAndroidPreference(
          configText, 'string', 'progressBarBehavior', settings.progressBehavior);
        configText = BackupRepository.upsertAndroidPreference(
          configText, 'boolean', 'tocUiUseReplace', settings.tocUseReplace ? 'true' : 'false');
        configText = BackupRepository.upsertAndroidPreference(
          configText, 'boolean', 'tocCountWords', settings.tocShowWordCount ? 'true' : 'false');
        configText = BackupRepository.upsertAndroidPreference(
          configText, 'string', 'clickImgWay', settings.clickImageBehavior);
        configText = BackupRepository.upsertAndroidPreference(
          configText, 'int', 'maxLengthWithNoToc',
          `${Math.max(3000, Math.min(100000, Math.round(settings.maxLengthWithNoToc)))}`);
        BackupRepository.writeTextFile(configPath, configText);
      }
      // coverConfig 的 14 个 coverPrefKeys 受 coverConfig 忽略开关控制
      // （上游 BackupConfig.kt:419 if (!backupIgnoreCoverConfig)），值按唯一映射表转成上游键名与类型。
      if (!ignoredCategories.includes('coverConfig')) {
        let coverText = fileIo.readTextSync(configPath);
        for (const preference of coverSettingsToAndroid(coverSettings)) {
          coverText = BackupRepository.upsertAndroidPreference(
            coverText, preference.type, preference.key, preference.value);
        }
        BackupRepository.writeTextFile(configPath, coverText);
        // 上游 Backup.kt:251-256 在同一个 `if (!backupIgnoreCoverConfig)` 里写 coverRule.json，
        // 但用 `BookCover.getConfig()?.let` 包着——没改过规则就不出这个文件。
        // 本地等价口径：与默认规则完全一致时不写，避免给上游塞一份它本来不会产出的文件。
        const coverRule: CoverRule = await CoverRuleRepository.load(context);
        if (!isDefaultCoverRule(coverRule)) {
          BackupRepository.writeTextFile(`${stagingDirectory}/coverRule.json`,
            JSON.stringify(coverRule));
        }
      }
      if (!ignoredCategories.includes('themeConfig')) {
        let configText = fileIo.readTextSync(configPath);
        configText = BackupRepository.upsertAndroidPreference(
          configText, 'boolean', 'eyeProtectionEnabled', String(settings.eyeProtectionEnabled));
        configText = BackupRepository.upsertAndroidPreference(
          configText, 'boolean', 'eyeProtectionAutoNight', String(settings.eyeProtectionAutoNight));
        configText = BackupRepository.upsertAndroidPreference(
          configText, 'boolean', 'eyeProtectionSchedule', String(settings.eyeProtectionSchedule));
        configText = BackupRepository.upsertAndroidPreference(
          configText, 'int', 'colorTemperature',
          String(Math.max(0, Math.min(100, Math.round(settings.eyeProtectionIntensity)))));
        configText = BackupRepository.upsertAndroidPreference(
          configText, 'string', 'eyeProtectionStartTime', settings.eyeProtectionStartTime);
        configText = BackupRepository.upsertAndroidPreference(
          configText, 'string', 'eyeProtectionEndTime', settings.eyeProtectionEndTime);
        BackupRepository.writeTextFile(configPath, configText);
      }
      // 全局深色模式：上游 `Backup.kt:257` 把整个 preferences 全量导出成 config.xml，
      // 再由 `BackupConfig.keyIsNotIgnore`（BackupConfig.kt:413-439）按
      // `PreferKey.themeMode == key && backupIgnoreThemeMode` 剔掉。
      // 本地是白名单式逐键写出，所以这里显式补一条，忽略门控与上游同向。
      if (!ignoredCategories.includes('themeMode')) {
        let configText = fileIo.readTextSync(configPath);
        configText = BackupRepository.upsertAndroidPreference(
          configText, 'string', 'themeMode', BackupRepository.normalizeThemeModeForBackup(themeMode));
        BackupRepository.writeTextFile(configPath, configText);
      }
      // 订阅入口开关：上游 `keyIsNotIgnore` 对 `showRss` 单键门控，本地白名单式逐键写出，
      // 所以显式补一条。真值取运行时主题设置而非写死默认值——用户改过开关后写死值会把旧状态带出去。
      if (!ignoredCategories.includes('showRss')) {
        const themeSnapshot = await ThemeSettingsRepository.load(context);
        let configText = fileIo.readTextSync(configPath);
        configText = BackupRepository.upsertAndroidPreference(
          configText, 'boolean', 'showRss', themeSnapshot.showRss ? 'true' : 'false');
        BackupRepository.writeTextFile(configPath, configText);
      }
      // 本地真值补写：97 个本地有真值、但历史白名单从不写出的键，按上游 PreferKey
      // 声明的 XML 类型写进 config.xml。必须排在透传之前——透传缓存里可能存着同一键的旧值，
      // 本地改了设置后本地值必须赢（两处判据已额外排除 missingPreferenceTypes）。
      // 整段 try/catch：读 preferences 失败只记日志，不拖垮整次备份（与 loadIgnoreLists 同姿态）。
      if (!ignoredCategories.includes('readConfig')) {
        try {
          let missingText = fileIo.readTextSync(configPath);
          missingText = await BackupRepository.applyMissingPreferences(context, missingText);
          BackupRepository.writeTextFile(configPath, missingText);
        } catch (error) {
          console.error(`[BackupRepository] 补写 config.xml 本地真值键失败，已跳过: ${error}`);
        }
      }
      // 透传：copyPreservedEntries 带进来的 config.xml 里，凡是本地读不懂的键，
      // 这次原样写回去，避免「从 Android 恢复 → 本地备份 → 上游键全丢」。
      // 判据与上游 keyIsNotIgnore 的 else -> true 对齐：不在已知写出键集、不在忽略键里，就保留。
      // 门控取 readConfig：透传键横跨 readConfig / themeConfig / 无组三类，而 config.xml 在
      // categoryOptions 里首要归属 readConfig；若用户勾选忽略「阅读配置」，整份 config.xml 本来
      // 也不该出现本地写出的键，故透传一并停下。
      // 已知边界：全新安装、从未从 Android 恢复过的设备缓存为空，此处无键可透传；
      // 上游 Backup.kt:266-275 的 3 个旧键回填逻辑（bookshelfSelectedGroupId ← saveTabPosition、
      // readBrightnessMode ← showBrightnessView、readBrightnessControlPosition ← brightnessVwPos）
      // 本地没有对应旧键，不实现。
      if (!ignoredCategories.includes('readConfig')) {
        let passthroughText = fileIo.readTextSync(configPath);
        passthroughText = await BackupRepository.applyPassthroughPreferences(
          context, passthroughText, ignoredCategories);
        BackupRepository.writeTextFile(configPath, passthroughText);
      }
      // 主题配色清单：上游 `Backup.kt:241-246` 在未忽略 themeConfig 时把
      // `ThemeConfigStore.configList` 整份 GSON 写进 `themeConfig.json`。
      // 本地没有内存清单，按当前调色板/自定义配色现算日/夜两套再写，
      // 与 `getDurConfig` 取的是同一批键，所以 Android 读回去能直接生效。
      if (!ignoredCategories.includes('themeConfig')) {
        const generated: ThemeConfigEntry[] = buildCurrentThemeConfigs(paletteIndex, customTheme);
        BackupRepository.writeTextFile(`${stagingDirectory}/${THEME_CONFIG_FILE_NAME}`,
          themeConfigsToJson(generated));
      }
      // 上游 Backup.kt:359 的 writeListToJson 里是 if (list.isNotEmpty())，
      // 源为空时根本不建文件；httpTtsVoices.json 相反，Backup.kt:193 无条件写，
      // 注释原文「空数组也要写出，用来区分旧备份未保存音色与确实没有音色」。
      // 两份条目的空判因此不能合并成一个条件。
      if (!ignoredCategories.includes('httpTTS')) {
        const sources = await HttpTtsRepository.load(context);
        if (sources.length > 0) {
          // 本地真值，要覆盖 copyPreservedEntries 带进来的透传件，所以不加 !accessSync。
          BackupRepository.writeTextFile(`${stagingDirectory}/httpTTS.json`,
            HttpTtsRepository.exportSources(sources));
        }
        const voices = await ReadAloudVoiceRepository.loadHttpVoices(context);
        const voicesPath = `${stagingDirectory}/httpTtsVoices.json`;
        // 这一侧保留 !accessSync：copyPreservedEntries（定义 :2573、调用 :629）刚把上次
        // 从 Android 导进来的真音色拷进来，本地还读不懂它的新版 schema 时覆盖会丢数据。
        // 与上面的 httpTTS.json 不对称是刻意的，不是漏写。
        if (!fileIo.accessSync(voicesPath)) {
          BackupRepository.writeTextFile(voicesPath, ReadAloudVoiceRepository.exportVoices(voices));
        }
      }
      const files = fileIo.listFileSync(stagingDirectory)
        .filter((name: string) => BackupRepository.isSafeRootEntry(name))
        .map((name: string) => `${stagingDirectory}/${name}`);
      if (files.length === 0 || files.length > BackupRepository.maximumArchiveEntries) {
        throw new Error('Android 兼容备份没有可写入条目或条目数量过多');
      }
      await zlib.compressFiles(files, zipPath, {});
      handedOff = true;
      return zipPath;
    } finally {
      await EpubRepository.removeBackupWorkDirectory(stagingDirectory);
      if (!handedOff) {
        try { fileIo.unlinkSync(zipPath); } catch (error) { console.error(`[BackupRepository] 删除备份临时包失败: ${error}`); }
      }
    }
  }

  /** 本地选择：picker 选一个 zip 拷到缓存，再交给 prepareBackupArchive。取消返回 undefined。 */
  static async selectBackup(context: Context, currentBooks: Book[]): Promise<BackupSelection | undefined> {
    const options = new picker.DocumentSelectOptions();
    options.fileSuffixFilters = ['Legado Android 备份|.zip'];
    options.maxSelectNumber = 1;
    const uris = await new picker.DocumentViewPicker(context).select(options);
    const uri = uris[0];
    if (uri === undefined) { return undefined; }

    const zipPath = `${context.cacheDir}/legado-android-restore-${Date.now()}.zip`;
    try {
      // 只负责把 uri 原样拷到缓存 zip；大小校验与校验失败文案统一交给 prepareBackupArchive。
      // 拷贝阶段单独包一层，与原 selectBackup 的错误前缀「Android ZIP 备份校验失败：」对齐；
      // prepareBackupArchive 已自带同前缀的包装，这里不再二次包装它的结果。
      try {
        const source = fileIo.openSync(uri, fileIo.OpenMode.READ_ONLY);
        try {
          fileIo.copyFileSync(source.fd, zipPath);
        } finally {
          fileIo.closeSync(source);
        }
      } catch (error) {
        const detail = error instanceof Error ? error.message : '未知错误';
        throw new Error(`Android ZIP 备份校验失败：${detail}`);
      }
      return await BackupRepository.prepareBackupArchive(context, zipPath, currentBooks);
    } finally {
      try { fileIo.unlinkSync(zipPath); } catch (error) { console.error(`[BackupRepository] 删除备份临时包失败: ${error}`); }
    }
  }

  /**
   * 校验并解压一份已经落到本地的备份 ZIP，返回可供 restore 使用的工作目录与预览。
   * 调用方负责删除传入的 zipPath；staging 由 restore 结束时清理（与原行为一致）。
   */
  static async prepareBackupArchive(
    context: Context,
    zipPath: string,
    currentBooks: Book[]
  ): Promise<BackupSelection> {
    const stagingDirectory = `${context.cacheDir}/legado-android-restore-${Date.now()}`;
    BackupRepository.ensureDirectory(stagingDirectory);
    try {
      const source = fileIo.openSync(zipPath, fileIo.OpenMode.READ_ONLY);
      try {
        const compressedSize = fileIo.statSync(source.fd).size;
        if (compressedSize <= 0 || compressedSize > BackupRepository.maximumCompressedBytes) {
          throw new Error('ZIP 备份为空或超过 64 MB');
        }
      } finally {
        fileIo.closeSync(source);
      }
      EpubRepository.validateBackupArchive(zipPath);
      const expandedSize = await zlib.getOriginalSize(zipPath);
      if (expandedSize <= 0 || expandedSize > BackupRepository.maximumExpandedBytes) {
        throw new Error('ZIP 解压内容超过 256 MB');
      }
      await zlib.decompressFile(zipPath, stagingDirectory);
      const entries = BackupRepository.readEntryPreviews(stagingDirectory);
      if (entries.length === 0 || entries.length > BackupRepository.maximumArchiveEntries) {
        throw new Error('备份 ZIP 中没有可识别的条目或条目数量超过 2000');
      }
      let bookCount: number = 0;
      let localBookCount: number = 0;
      let localBooksWithoutBody: number = 0;
      const currentPaths: Set<string> = new Set<string>();
      for (let index = 0; index < currentBooks.length; index++) {
        const book = currentBooks[index];
        if (book !== undefined && book.contentPath !== undefined) { currentPaths.add(book.contentPath); }
      }
      for (let index = 0; index < entries.length; index++) {
        const entry = entries[index];
        if (entry !== undefined && entry.name === 'bookshelf.json') {
          bookCount = Math.max(0, entry.recordCount);
          const text = fileIo.readTextSync(`${stagingDirectory}/${entry.name}`);
          localBookCount = BackupRepository.countLocalBooks(text);
          const records = BackupRepository.splitJsonArray(text);
          for (let recordIndex = 0; recordIndex < records.length; recordIndex++) {
            const record = records[recordIndex] ?? '';
            if (!BackupRepository.isLocalAndroidBook(record)) { continue; }
            const bookUrl = BackupRepository.readJsonString(record, 'bookUrl') ?? '';
            if (!currentPaths.has(bookUrl)) { localBooksWithoutBody += 1; }
          }
        }
      }
      return {
        stagingDirectory: stagingDirectory,
        preview: {
          entryCount: entries.length,
          bookCount: bookCount,
          localBookCount: localBookCount,
          localBooksWithoutBody: localBooksWithoutBody,
          entries: entries
        }
      };
    } catch (error) {
      await EpubRepository.removeBackupWorkDirectory(stagingDirectory);
      const detail = error instanceof Error ? error.message : '未知错误';
      throw new Error(`Android ZIP 备份校验失败：${detail}`);
    }
  }

  /** WebDAV 选择：zip 已经在缓存目录，直接交给 prepareBackupArchive。 */
  static async selectBackupFromPath(context: Context, zipPath: string, currentBooks: Book[]): Promise<BackupSelection> {
    return await BackupRepository.prepareBackupArchive(context, zipPath, currentBooks);
  }

  static async restore(
    context: Context,
    selection: BackupSelection,
    currentBooks: Book[],
    currentSettings: ReaderSettingsSnapshot,
    currentBookshelfLayout: BookshelfLayoutSettings,
    ignoredCategories: string[]
  ): Promise<RestoreResult> {
    const targetDirectory = `${context.filesDir}/${BackupRepository.legacyDirectoryName}`;
    BackupRepository.ensureDirectory(targetDirectory);
    const entries = selection.preview.entries;
    let preservedEntryCount: number = 0;
    let replaceRuleAdded: number = 0;
    let replaceRuleUpdated: number = 0;
    let replaceRuleSkipped: number = 0;
    let txtTocRuleAdded: number = 0;
    let txtTocRuleUpdated: number = 0;
    let txtTocRuleSkipped: number = 0;
    let highlightRuleAdded: number = 0;
    let highlightRuleUpdated: number = 0;
    let highlightRuleSkipped: number = 0;
    let bookmarkAdded: number = 0;
    let bookmarkUpdated: number = 0;
    let bookmarkSkipped: number = 0;
    let dictRuleAdded: number = 0;
    let dictRuleUpdated: number = 0;
    let dictRuleSkipped: number = 0;
    let homepageModulesAdded: number = 0;
    let homepageModulesUpdated: number = 0;
    let homepageModulesSkipped: number = 0;
    let homepageCustomSetsAdded: number = 0;
    let homepageCustomSetsUpdated: number = 0;
    let homepageCustomSetsSkipped: number = 0;
    let highlightTagRuleAdded: number = 0;
    let highlightTagRuleUpdated: number = 0;
    let highlightTagRuleSkipped: number = 0;
    let tagGroupRuleAdded: number = 0;
    let tagGroupRuleUpdated: number = 0;
    let tagGroupRuleSkipped: number = 0;
    let httpTtsSourcesAdded: number = 0;
    let httpTtsSourcesUpdated: number = 0;
    let httpTtsSourcesSkipped: number = 0;
    let httpTtsVoicesRestored: number = 0;
    let httpTtsVoicesSkipped: number = 0;
    let bookSourceAdded: number = 0;
    let bookSourceUpdated: number = 0;
    let bookSourceSkipped: number = 0;
    let rssSourceAdded: number = 0;
    let rssSourceUpdated: number = 0;
    let rssSourceSkipped: number = 0;
    let rssStarAdded: number = 0;
    let rssStarUpdated: number = 0;
    let rssStarSkipped: number = 0;
    let sourceSubAdded: number = 0;
    let sourceSubUpdated: number = 0;
    let sourceSubSkipped: number = 0;
    let serverAdded: number = 0;
    let serverUpdated: number = 0;
    let serverSkipped: number = 0;
    // bookmark.json 与 bookMarking.json 是两个条目，但要一起合并再统一落盘，
    // 否则先写书签时用的还是旧笔记列表，后写笔记又会把书签覆盖回去。
    let restoredThemeConfigCount: number = 0;
    // 恢复分支里逐份暂存，循环结束后统一写库，对应上游 Restore.kt 的读入分支。
    let pendingSummaries: ReadRecordSummary[] | undefined = undefined;
    let pendingDetails: ReadRecordDetail[] | undefined = undefined;
    let pendingSessions: ReadRecordSession[] | undefined = undefined;
    let pendingBookmarks: ReaderBookmark[] | undefined = undefined;
    let pendingMarkings: ReaderMarking[] | undefined = undefined;
    const bookmarkOutcome: BookmarkImportOutcome = { added: 0, updated: 0, skipped: 0 };
    for (let index = 0; index < entries.length; index++) {
      const entry = entries[index];
      if (entry === undefined || BackupRepository.isIgnored(entry.name, ignoredCategories)) { continue; }
      const sourcePath = `${selection.stagingDirectory}/${entry.name}`;
      const targetPath = `${targetDirectory}/${entry.name}`;
      if (entry.name === 'bookshelf.json') {
        let content = fileIo.readTextSync(sourcePath);
        if (content.length > BackupRepository.maximumJsonTextBytes) {
          throw new Error(`${entry.name} 超过 32 MB，未恢复书架条目`);
        }
        if (ignoredCategories.includes('localBook')) {
          content = BackupRepository.filterLocalBooks(content);
        }
        if (fileIo.accessSync(targetPath)) {
          const existing = fileIo.readTextSync(targetPath);
          if (existing !== content) {
            BackupRepository.writeTextFile(targetPath, BackupRepository.mergeAndroidBookshelf(existing, content));
          }
        } else {
          BackupRepository.writeTextFile(targetPath, content);
        }
        preservedEntryCount += 1;
        continue;
      }
      if (entry.name === 'config.xml') {
        const content = BackupRepository.filterAndroidConfigXml(
          fileIo.readTextSync(sourcePath), ignoredCategories
        );
        if (content.length > BackupRepository.maximumJsonTextBytes) {
          throw new Error(`${entry.name} 超过 32 MB，未恢复该配置`);
        }
        BackupRepository.writeTextFile(targetPath, content);
        // 把 config.xml 里本地不认识的键存进透传缓存，供下次备份原样带出。
        // 新增键数只用于日志，不进 RestoreResult（界面不需要多一个数字）。
        const passthroughAdded = await BackupRepository.savePassthroughFromConfigXml(
          context, content, ignoredCategories);
        console.info(`[BackupRepository] config.xml 透传缓存新增 ${passthroughAdded} 键`);
        preservedEntryCount += 1;
        continue;
      }
      if (entry.name === 'bookGroup.json') {
        const text = fileIo.readTextSync(sourcePath);
        if (text.length > BackupRepository.maximumJsonTextBytes) {
          throw new Error(`${entry.name} 超过 32 MB，未恢复书架分组`);
        }
        await fileIo.copyFile(sourcePath, targetPath);
        await BookGroupRepository.importAndroidFile(context, targetPath);
        preservedEntryCount += 1;
        continue;
      }
      if (entry.name === 'bookSource.json') {
        const text = fileIo.readTextSync(sourcePath);
        if (text.length > BackupRepository.maximumJsonTextBytes) {
          throw new Error(`${entry.name} 超过 32 MB，未恢复书源`);
        }
        const parsed = BookSourceImporter.parse(text);
        // 先从库里读出本地已有条目，importRules 的合并语义才有真实基线；
        // 否则空缓存会让 save() 整表重写时把上一次恢复的数据抹掉。
        await BookSourceRepository.load(context);
        const outcome = await BookSourceRepository.importRules(context, parsed.rules);
        bookSourceAdded += outcome.added;
        bookSourceUpdated += outcome.updated;
        bookSourceSkipped += parsed.skipped + outcome.skipped;
        // 同时归档到保留目录，下次备份时 copyPreservedEntries 会原样带走。
        await fileIo.copyFile(sourcePath, targetPath);
        preservedEntryCount += 1;
        continue;
      }
      if (entry.name === 'rssSources.json') {
        const text = fileIo.readTextSync(sourcePath);
        if (text.length > BackupRepository.maximumJsonTextBytes) {
          throw new Error(`${entry.name} 超过 32 MB，未恢复RSS 订阅源`);
        }
        const parsed = RssSourceImporter.parse(text);
        // 先从库里读出本地已有条目，importRules 的合并语义才有真实基线；
        // 否则空缓存会让 save() 整表重写时把上一次恢复的数据抹掉。
        await RssSourceRepository.load(context);
        const outcome = await RssSourceRepository.importRules(context, parsed.rules);
        rssSourceAdded += outcome.added;
        rssSourceUpdated += outcome.updated;
        rssSourceSkipped += parsed.skipped + outcome.skipped;
        // 同时归档到保留目录，下次备份时 copyPreservedEntries 会原样带走。
        await fileIo.copyFile(sourcePath, targetPath);
        preservedEntryCount += 1;
        continue;
      }
      if (entry.name === 'rssStar.json') {
        const text = fileIo.readTextSync(sourcePath);
        if (text.length > BackupRepository.maximumJsonTextBytes) {
          throw new Error(`${entry.name} 超过 32 MB，未恢复RSS 收藏`);
        }
        const parsed = RssStarImporter.parse(text);
        // 先从库里读出本地已有条目，importRules 的合并语义才有真实基线；
        // 否则空缓存会让 save() 整表重写时把上一次恢复的数据抹掉。
        await RssStarRepository.load(context);
        const outcome = await RssStarRepository.importRules(context, parsed.rules);
        rssStarAdded += outcome.added;
        rssStarUpdated += outcome.updated;
        rssStarSkipped += parsed.skipped + outcome.skipped;
        // 同时归档到保留目录，下次备份时 copyPreservedEntries 会原样带走。
        await fileIo.copyFile(sourcePath, targetPath);
        preservedEntryCount += 1;
        continue;
      }
      if (entry.name === 'sourceSub.json') {
        const text = fileIo.readTextSync(sourcePath);
        if (text.length > BackupRepository.maximumJsonTextBytes) {
          throw new Error(`${entry.name} 超过 32 MB，未恢复规则订阅`);
        }
        const parsed = RuleSubImporter.parse(text);
        // 先从库里读出本地已有条目，importRules 的合并语义才有真实基线；
        // 否则空缓存会让 save() 整表重写时把上一次恢复的数据抹掉。
        await RuleSubRepository.load(context);
        const outcome = await RuleSubRepository.importRules(context, parsed.rules);
        sourceSubAdded += outcome.added;
        sourceSubUpdated += outcome.updated;
        sourceSubSkipped += parsed.skipped + outcome.skipped;
        // 同时归档到保留目录，下次备份时 copyPreservedEntries 会原样带走。
        await fileIo.copyFile(sourcePath, targetPath);
        preservedEntryCount += 1;
        continue;
      }
      if (entry.name === 'servers.json') {
        const text = fileIo.readTextSync(sourcePath).trim();
        if (text.length > BackupRepository.maximumJsonTextBytes) {
          throw new Error(`${entry.name} 超过 32 MB，未恢复服务器配置`);
        }
        // 上游 Restore.kt:301-316 的判据：先看是不是 JSON 数组，不是就当密文解。
        // 顺序不能反 —— 明文数组拿去解密会抛异常，密文拿去 JSON.parse 会失败。
        let plain = text;
        let decryptFailed = false;
        if (!plain.startsWith('[')) {
          try {
            plain = aesEcbDecryptFromBase64(plain, aesEcKeyFromPassword(''));
          } catch (error) {
            decryptFailed = true;
            console.error(`[BackupRepository] servers.json 解密失败（可能是设过备份密码的包）: ${error}`);
          }
        }
        if (decryptFailed) {
          // 解不开不等于文件坏了：样本以外的真实备份常常设了密码。
          // 只归档、不报错、不动库，原文留在 android-backup-entries 里，
          // 下次备份会原样带走，用户回 Android 端仍能读出。
          await fileIo.copyFile(sourcePath, targetPath);
          preservedEntryCount += 1;
          serverSkipped += 1;
          continue;
        }
        const parsed = ServerRepository.parseServers(plain);
        await ServerRepository.load(context);
        const outcome = await ServerRepository.importServers(context, parsed.servers);
        serverAdded += outcome.added;
        serverUpdated += outcome.updated;
        serverSkipped += parsed.skipped + outcome.skipped;
        await fileIo.copyFile(sourcePath, targetPath);
        preservedEntryCount += 1;
        continue;
      }
      if (entry.name === 'replaceRule.json') {
        const text = fileIo.readTextSync(sourcePath);
        if (text.length > BackupRepository.maximumJsonTextBytes) {
          throw new Error(`${entry.name} 超过 32 MB，未恢复替换净化规则`);
        }
        // 逐条解析并导入；非法正则的条目由 ReplaceRuleImporter 计入 skipped 后跳过，
        // 不因为一条坏规则就丢掉整份备份，与上游 Restore 逐条 insert 的语义一致。
        const parsed = ReplaceRuleImporter.parse(text);
        const outcome = await ReplaceRuleRepository.importRules(context, parsed.rules);
        replaceRuleAdded += outcome.added;
        replaceRuleUpdated += outcome.updated;
        replaceRuleSkipped += parsed.skipped;
        // 同时归档到保留目录，下次备份时 copyPreservedEntries 会原样带走。
        await fileIo.copyFile(sourcePath, targetPath);
        preservedEntryCount += 1;
        continue;
      }
      if (entry.name === 'txtTocRule.json') {
        const text = fileIo.readTextSync(sourcePath);
        if (text.length > BackupRepository.maximumJsonTextBytes) {
          throw new Error(`${entry.name} 超过 32 MB，未恢复 TXT 目录规则`);
        }
        const parsed = TxtTocRuleImporter.parse(text);
        const outcome = await TxtTocRuleRepository.importRules(context, parsed.rules);
        txtTocRuleAdded += outcome.added;
        txtTocRuleUpdated += outcome.updated;
        txtTocRuleSkipped += parsed.skipped;
        await fileIo.copyFile(sourcePath, targetPath);
        preservedEntryCount += 1;
        continue;
      }
      if (entry.name === 'highlightRule.json') {
        const text = fileIo.readTextSync(sourcePath);
        if (text.length > BackupRepository.maximumJsonTextBytes) {
          throw new Error(`${entry.name} 超过 32 MB，未恢复高亮规则`);
        }
        const parsed = BackupRepository.parseHighlightRules(text);
        const outcome = await ReaderHighlightRuleRepository.importRules(context, parsed.rules);
        highlightRuleAdded += outcome.added;
        highlightRuleUpdated += outcome.updated;
        highlightRuleSkipped += parsed.skipped + outcome.skipped;
        await fileIo.copyFile(sourcePath, targetPath);
        preservedEntryCount += 1;
        continue;
      }
      if (entry.name === 'dictRule.json') {
        const text = fileIo.readTextSync(sourcePath);
        if (text.length > BackupRepository.maximumJsonTextBytes) {
          throw new Error(`${entry.name} 超过 32 MB，未恢复字典规则`);
        }
        const parsed = DictRuleImporter.parse(text);
        // 先从库里读出本地已有规则，importRules 的合并语义才有真实基线；
        // 否则空缓存会让 save() 整表重写时把上一次恢复的数据抹掉。
        await DictRuleRepository.load(context);
        const outcome = await DictRuleRepository.importRules(context, parsed.rules);
        dictRuleAdded += outcome.added;
        dictRuleUpdated += outcome.updated;
        dictRuleSkipped += parsed.skipped + outcome.skipped;
        // 同时归档到保留目录，下次备份时 copyPreservedEntries 会原样带走。
        await fileIo.copyFile(sourcePath, targetPath);
        preservedEntryCount += 1;
        continue;
      }
      if (entry.name === 'httpTTS.json') {
        const text = fileIo.readTextSync(sourcePath);
        if (text.length > BackupRepository.maximumJsonTextBytes) {
          throw new Error(`${entry.name} 超过 32 MB，未恢复在线朗读源`);
        }
        const parsed = HttpTtsImporter.parseSources(text);
        // 先读出本地已有源，importSources 的合并语义才有真实基线；
        // 否则空缓存会让 save() 整表重写时把上一次恢复的数据抹掉。
        await HttpTtsRepository.load(context);
        const sourceOutcome = await HttpTtsRepository.importSources(context, parsed.sources);
        httpTtsSourcesAdded += sourceOutcome.added;
        httpTtsSourcesUpdated += sourceOutcome.updated;
        httpTtsSourcesSkipped += parsed.skipped + sourceOutcome.skipped;
        // 音色必须在源之后恢复：read_aloud_voices.engineId 指向 httpTTS.id。
        // 单独出现（没有 httpTTS.json）的 httpTtsVoices.json 是孤儿音色，不在这里恢复。
        const voicesPath = `${selection.stagingDirectory}/httpTtsVoices.json`;
        if (fileIo.accessSync(voicesPath)) {
          const voicesText = fileIo.readTextSync(voicesPath);
          const voicesTrimmed = voicesText.trim();
          // 坏 JSON 不能当成旧备份忽略，更不能拿解析出的空数组去 replaceHttpVoices——
          // 那样会静默清掉本地 excluded 状态；先独立验结构，损坏就只计 skipped、不清库。
          let wellFormed = false;
          if (voicesTrimmed.startsWith('[') || voicesTrimmed.startsWith('{')) {
            try {
              const probe: Object = JSON.parse(voicesTrimmed);
              wellFormed = probe !== null;
            } catch (_) {
              wellFormed = false;
            }
          }
          if (wellFormed) {
            const voiceParsed = HttpTtsImporter.parseVoices(voicesText);
            await ReadAloudVoiceRepository.replaceHttpVoices(context, voiceParsed.voices);
            httpTtsVoicesRestored += voiceParsed.voices.length;
            httpTtsVoicesSkipped += voiceParsed.skipped;
          } else {
            httpTtsVoicesSkipped += 1;
            console.error('httpTtsVoices.json 无法解析，保留本地 http 音色未覆盖');
          }
        }
        // 同时归档到保留目录，下次备份时 copyPreservedEntries 会原样带走。
        await fileIo.copyFile(sourcePath, targetPath);
        preservedEntryCount += 1;
        continue;
      }
      if (entry.name === 'homepageModules.json') {
        const text = fileIo.readTextSync(sourcePath);
        if (text.length > BackupRepository.maximumJsonTextBytes) {
          throw new Error(`${entry.name} 超过 32 MB，未恢复首页模块`);
        }
        const parsed = HomepageModuleImporter.parse(text);
        // 先从库里读出本地已有规则，importRules 的合并语义才有真实基线；
        // 否则空缓存会让 save() 整表重写时把上一次恢复的数据抹掉。
        await HomepageModuleRepository.load(context);
        const outcome = await HomepageModuleRepository.importRules(context, parsed.rules);
        homepageModulesAdded += outcome.added;
        homepageModulesUpdated += outcome.updated;
        homepageModulesSkipped += parsed.skipped + outcome.skipped;
        // 同时归档到保留目录，下次备份时 copyPreservedEntries 会原样带走。
        await fileIo.copyFile(sourcePath, targetPath);
        preservedEntryCount += 1;
        continue;
      }
      if (entry.name === 'homepageCustomSets.json') {
        const text = fileIo.readTextSync(sourcePath);
        if (text.length > BackupRepository.maximumJsonTextBytes) {
          throw new Error(`${entry.name} 超过 32 MB，未恢复首页自定义集`);
        }
        const parsed = HomepageCustomSetImporter.parse(text);
        // 先从库里读出本地已有规则，importRules 的合并语义才有真实基线；
        // 否则空缓存会让 save() 整表重写时把上一次恢复的数据抹掉。
        await HomepageCustomSetRepository.load(context);
        const outcome = await HomepageCustomSetRepository.importRules(context, parsed.rules);
        homepageCustomSetsAdded += outcome.added;
        homepageCustomSetsUpdated += outcome.updated;
        homepageCustomSetsSkipped += parsed.skipped + outcome.skipped;
        // 同时归档到保留目录，下次备份时 copyPreservedEntries 会原样带走。
        await fileIo.copyFile(sourcePath, targetPath);
        preservedEntryCount += 1;
        continue;
      }
      if (entry.name === 'highlightTagRule.json') {
        const text = fileIo.readTextSync(sourcePath);
        if (text.length > BackupRepository.maximumJsonTextBytes) {
          throw new Error(`${entry.name} 超过 32 MB，未恢复标签高亮规则`);
        }
        const parsed = HighlightTagRuleImporter.parse(text);
        // 先从库里读出本地已有规则，importRules 的合并语义才有真实基线；
        // 否则空缓存会让 save() 整表重写时把上一次恢复的数据抹掉。
        await HighlightTagRuleRepository.load(context);
        const outcome = await HighlightTagRuleRepository.importRules(context, parsed.rules);
        highlightTagRuleAdded += outcome.added;
        highlightTagRuleUpdated += outcome.updated;
        highlightTagRuleSkipped += parsed.skipped + outcome.skipped;
        // 同时归档到保留目录，下次备份时 copyPreservedEntries 会原样带走。
        await fileIo.copyFile(sourcePath, targetPath);
        preservedEntryCount += 1;
        continue;
      }
      if (entry.name === 'tagGroupRule.json') {
        const text = fileIo.readTextSync(sourcePath);
        if (text.length > BackupRepository.maximumJsonTextBytes) {
          throw new Error(`${entry.name} 超过 32 MB，未恢复标签分组规则`);
        }
        const parsed = TagGroupRuleImporter.parse(text);
        // 先从库里读出本地已有规则，importRules 的合并语义才有真实基线；
        // 否则空缓存会让 save() 整表重写时把上一次恢复的数据抹掉。
        await TagGroupRuleRepository.load(context);
        const outcome = await TagGroupRuleRepository.importRules(context, parsed.rules);
        tagGroupRuleAdded += outcome.added;
        tagGroupRuleUpdated += outcome.updated;
        tagGroupRuleSkipped += parsed.skipped + outcome.skipped;
        // 同时归档到保留目录，下次备份时 copyPreservedEntries 会原样带走。
        await fileIo.copyFile(sourcePath, targetPath);
        preservedEntryCount += 1;
        continue;
      }
      if (entry.name === 'bookmark.json' || entry.name === 'bookMarking.json') {
        const text = fileIo.readTextSync(sourcePath);
        if (text.length > BackupRepository.maximumJsonTextBytes) {
          throw new Error(`${entry.name} 超过 32 MB，未恢复书签与笔记`);
        }
        // 两份文件共用一个 outcome，先把两份都合并完，循环结束后统一落盘。
        if (pendingBookmarks === undefined) {
          pendingBookmarks = await ReaderBookmarkRepository.load(context);
        }
        if (pendingMarkings === undefined) {
          pendingMarkings = await ReaderMarkingRepository.load(context);
        }
        if (entry.name === 'bookmark.json') {
          pendingBookmarks = ReaderBookmarkImporter.mergeBookmarks(
            text, currentBooks, pendingBookmarks, bookmarkOutcome);
        } else {
          pendingMarkings = ReaderBookmarkImporter.mergeMarkings(
            text, currentBooks, pendingMarkings, bookmarkOutcome);
        }
        await fileIo.copyFile(sourcePath, targetPath);
        preservedEntryCount += 1;
        continue;
      }
      if (entry.name === THEME_CONFIG_FILE_NAME) {
        const text = fileIo.readTextSync(sourcePath);
        if (text.length > BackupRepository.maximumJsonTextBytes) {
          throw new Error(`${entry.name} 超过 32 MB，未恢复主题配色清单`);
        }
        // 上游是整份覆盖：归档里的清单先解析成合法条目（坏条目在 parseThemeConfigs
        // 里就被剔除），再写进私有目录；归档目录里同时留一份原样副本供排查。
        const parsed: ThemeConfigEntry[] = parseThemeConfigs(text);
        saveThemeConfigs(context, parsed);
        restoredThemeConfigCount = parsed.length;
        await fileIo.copyFile(sourcePath, targetPath);
        preservedEntryCount += 1;
        continue;
      }
      if (entry.name === 'readRecord.json' || entry.name === 'readRecordDetail.json' ||
        entry.name === 'readRecordSession.json') {
        const text = fileIo.readTextSync(sourcePath);
        if (text.length > BackupRepository.maximumJsonTextBytes) {
          throw new Error(`${entry.name} 超过 32 MB，未恢复阅读记录`);
        }
        // 三个文件逐份暂存，循环结束后统一写库，避免单文件分支互相覆盖。
        const parsed = BackupRepository.parseReadRecordArray(text);
        if (entry.name === 'readRecord.json') {
          pendingSummaries = BackupRepository.toReadRecordSummaries(parsed);
        } else if (entry.name === 'readRecordDetail.json') {
          pendingDetails = BackupRepository.toReadRecordDetails(parsed);
        } else {
          pendingSessions = BackupRepository.toReadRecordSessions(parsed);
        }
        await fileIo.copyFile(sourcePath, targetPath);
        preservedEntryCount += 1;
        continue;
      }
      if (entry.name === 'coverRule.json') {
        const text = fileIo.readTextSync(sourcePath);
        if (text.length > BackupRepository.maximumJsonTextBytes) {
          throw new Error(`${entry.name} 超过 32 MB，未恢复封面规则`);
        }
        // 上游 Restore.kt:337-342 把整段字符串直接塞进 saveCoverRule，不做结构校验；
        // 本地 CoverRuleRepository.save 要结构体，所以这里解析后按 9 个字段补齐默认值，
        // 坏 JSON 不抛错、回退默认（对齐上游 runCatching 的容错姿态）。
        const parsed: CoverRule = BackupRepository.parseCoverRule(text);
        await CoverRuleRepository.save(context, parsed);
        await fileIo.copyFile(sourcePath, targetPath);
        preservedEntryCount += 1;
        continue;
      }
      await fileIo.copyFile(sourcePath, targetPath);
      preservedEntryCount += 1;
    }

    // 三份 JSON 全部收齐之后，按会话重算明细与汇总，再写进关系库。
    if (pendingSummaries !== undefined || pendingDetails !== undefined || pendingSessions !== undefined) {
      await ReadRecordRepository.restoreFromBackup(context,
        pendingSummaries ?? [], pendingDetails ?? [], pendingSessions ?? []);
    }

    // 归档里的 themeConfig.json 已经落进私有目录，这里补一次装载，
    // 对齐上游 `Restore.kt:332` 的 `ThemeConfigStore.upConfig()`。
    if (restoredThemeConfigCount > 0) {
      upThemeConfig(context);
    }

    // 书签与笔记都合并完再各写一次，避免两份文件互相覆盖对方的合并结果。
    // 计数来自同一个 outcome：两份文件的新增/覆盖/跳过合并成一个总数报给用户。
    if (pendingBookmarks !== undefined) {
      await ReaderBookmarkRepository.save(context, pendingBookmarks);
    }
    if (pendingMarkings !== undefined) {
      await ReaderMarkingRepository.save(context, pendingMarkings);
    }
    bookmarkAdded += bookmarkOutcome.added;
    bookmarkUpdated += bookmarkOutcome.updated;
    bookmarkSkipped += bookmarkOutcome.skipped;

    const restoredReadSettings = BackupRepository.restoreReaderSettings(
      selection.stagingDirectory,
      currentSettings,
      ignoredCategories
    );
    const settings = BackupRepository.applyEyeProtection(
      selection.stagingDirectory, restoredReadSettings, ignoredCategories
    );
    await ReaderSettingsRepository.save(context, settings);
    // 全局深色模式与阅读设置分开存（`legado_theme`），所以单独读、单独回传，
    // 由调用方 `Index.ets` 走 `applyThemeMode` 应用，与上游 Restore.kt:326-335 同序。
    const restoredThemeMode = BackupRepository.restoreThemeMode(
      selection.stagingDirectory, ignoredCategories
    );
    // showRss 与 themeMode 同属 config.xml 派生设置：单独读、单独回传，落盘交给 Index.ets
    // 的 saveThemeSettings 整份写，避免与随后 applyThemeMode 的整份写互相覆盖。
    const restoredShowRss = BackupRepository.restoreShowRss(
      selection.stagingDirectory, ignoredCategories
    );
    const bookshelfLayout = BackupRepository.restoreBookshelfLayout(
      selection.stagingDirectory, currentBookshelfLayout, ignoredCategories
    );
    await BookshelfLayoutRepository.save(context, bookshelfLayout);
    // coverConfig 的 14 键 + 2 个无条件键从 config.xml 反向映射回本地封面设置，
    // 与写出侧 coverSettingsToAndroid / 无条件区一一对应。
    const coverSettings = BackupRepository.restoreCoverSettings(
      selection.stagingDirectory, CoverSettingsRepository.get(), ignoredCategories
    );
    await CoverSettingsRepository.save(context, coverSettings);
    const updated = await BackupRepository.restoreMatchingLocalProgress(
      context,
      selection.stagingDirectory,
      currentBooks,
      ignoredCategories
    );
    const localBooks = updated.books.filter((book: Book) => BookRepository.isPersistableBook(book));
    await BookRepository.saveImportedBooks(context, localBooks);
    const restoredEntries = BackupRepository.buildRestoredEntrySummary(selection, ignoredCategories);
    await BackupRepository.saveRestoredEntrySummary(context, restoredEntries);
    return {
      books: updated.books,
      settings: settings,
      bookshelfLayout: bookshelfLayout,
      coverSettings: coverSettings,
      themeMode: restoredThemeMode,
      showRss: restoredShowRss,
      preservedEntryCount: preservedEntryCount,
      updatedLocalBookCount: updated.updatedCount,
      createdMissingBodyBookCount: updated.createdMissingBodyCount,
      deletedDuplicateLocalBookCount: updated.deletedDuplicateCount,
      localBooksWithoutBody: selection.preview.localBooksWithoutBody,
      restoredEntries: restoredEntries,
      replaceRuleAdded: replaceRuleAdded,
      replaceRuleUpdated: replaceRuleUpdated,
      replaceRuleSkipped: replaceRuleSkipped,
      txtTocRuleAdded: txtTocRuleAdded,
      txtTocRuleUpdated: txtTocRuleUpdated,
      txtTocRuleSkipped: txtTocRuleSkipped,
      highlightRuleAdded: highlightRuleAdded,
      highlightRuleUpdated: highlightRuleUpdated,
      highlightRuleSkipped: highlightRuleSkipped,
      bookmarkAdded: bookmarkAdded,
      bookmarkUpdated: bookmarkUpdated,
      bookmarkSkipped: bookmarkSkipped,
      dictRuleAdded: dictRuleAdded,
      dictRuleUpdated: dictRuleUpdated,
      dictRuleSkipped: dictRuleSkipped,
      homepageModulesAdded: homepageModulesAdded,
      homepageModulesUpdated: homepageModulesUpdated,
      homepageModulesSkipped: homepageModulesSkipped,
      homepageCustomSetsAdded: homepageCustomSetsAdded,
      homepageCustomSetsUpdated: homepageCustomSetsUpdated,
      homepageCustomSetsSkipped: homepageCustomSetsSkipped,
      highlightTagRuleAdded: highlightTagRuleAdded,
      highlightTagRuleUpdated: highlightTagRuleUpdated,
      highlightTagRuleSkipped: highlightTagRuleSkipped,
      tagGroupRuleAdded: tagGroupRuleAdded,
      tagGroupRuleUpdated: tagGroupRuleUpdated,
      tagGroupRuleSkipped: tagGroupRuleSkipped,
      httpTtsSourcesAdded: httpTtsSourcesAdded,
      httpTtsSourcesUpdated: httpTtsSourcesUpdated,
      httpTtsSourcesSkipped: httpTtsSourcesSkipped,
      httpTtsVoicesRestored: httpTtsVoicesRestored,
      httpTtsVoicesSkipped: httpTtsVoicesSkipped,
      bookSourceAdded: bookSourceAdded,
      bookSourceUpdated: bookSourceUpdated,
      bookSourceSkipped: bookSourceSkipped,
      rssSourceAdded: rssSourceAdded,
      rssSourceUpdated: rssSourceUpdated,
      rssSourceSkipped: rssSourceSkipped,
      rssStarAdded: rssStarAdded,
      rssStarUpdated: rssStarUpdated,
      rssStarSkipped: rssStarSkipped,
      sourceSubAdded: sourceSubAdded,
      sourceSubUpdated: sourceSubUpdated,
      sourceSubSkipped: sourceSubSkipped,
      serverAdded: serverAdded,
      serverUpdated: serverUpdated,
      serverSkipped: serverSkipped
    };
  }

  static async discardSelection(selection: BackupSelection): Promise<void> {
    await EpubRepository.removeBackupWorkDirectory(selection.stagingDirectory);
  }

  /**
   * 上游 originName 是本地书的文件名（含扩展名），见 LocalBook.kt:273 的 originName = fileName；
   * 目录导入时则是目录名（LocalBook.kt:351）。本地没有独立字段，按 androidOriginalPath 再退 contentPath 取末段。
   */
  private static localBookOriginName(book: Book, androidBookUrl: string): string {
    const source = book.androidOriginalPath ?? androidBookUrl;
    return source.length > 0 ? BookRepository.getFileName(source) : book.title;
  }

  private static toAndroidBookRecord(book: Book, order: number): AndroidBookBackupRecord {
    // 备份导出直接读 books 行的字段，与上游 Backup 一致：不 join chapters 表，
    // 章节数取 totalChapterNum，章内位置取 durChapterPos。
    const savedChapterCount = Number(book.chapterCount ?? '0');
    const totalChapterCount = Number.isInteger(savedChapterCount) && savedChapterCount > 0 ? savedChapterCount : 0;
    const chapterIndex = Math.max(0, book.chapterIndex ?? 0);
    const androidBookUrl = book.androidOriginalPath ?? book.contentPath ?? '';
    return {
      bookUrl: androidBookUrl,
      tocUrl: androidBookUrl,
      origin: 'loc_book',
      // 上游 originName 是文件名（含扩展名，见 LocalBook.kt:273 的 fileName），
      // name 才是去掉扩展名后拆出来的书名，两者不能都取书名。
      originName: BackupRepository.localBookOriginName(book, androidBookUrl),
      name: book.title,
      author: book.author,
      kind: book.category,
      customTag: book.customTag ?? null,
      coverUrl: undefined,
      customCoverUrl: null,
      intro: book.description ?? null,
      customIntro: null,
      remark: book.remark ?? null,
      charset: book.charset ?? null,
      type: BookRepository.bookTypeMask(book),
      group: BookGroupRepository.maskFromNames(book.groupNames ?? []),
      isPrivate: false,
      latestChapterTitle: book.lastChapter,
      latestChapterTime: book.latestChapterTime ?? 0,
      lastCheckTime: 0,
      lastCheckCount: 0,
      totalChapterNum: totalChapterCount,
      durChapterTitle: book.lastChapter,
      durChapterIndex: chapterIndex,
      durChapterPos: book.androidCharacterPosition ?? 0,
      durChapterTime: book.durChapterTime ?? 0,
      wordCount: null,
      canUpdate: false,
      disableReadRecord: false,
      order: book.order ?? order,
      originOrder: 0,
      variable: null,
      readConfig: null,
      syncTime: 0,
      listIntro: null
    };
  }

  private static toAndroidReadConfig(settings: ReaderSettingsSnapshot): AndroidReadConfigBackupRecord {
    // 样式表可增删，下标上界跟着表长度走；表至少会补齐到预设条数，所以不会是空数组。
    const styles = settings.backgroundStyles;
    const lastIndex = Math.max(0, styles.length - 1);
    const dayStyle = styles[Math.max(0, Math.min(lastIndex, settings.dayPaperIndex))] ??
      styles[Math.max(0, Math.min(lastIndex, settings.paperIndex))] ??
      READER_BACKGROUND_STYLES[0];
    const nightStyle = styles[Math.max(0, Math.min(lastIndex, settings.nightPaperIndex))] ?? dayStyle;
    return {
      name: dayStyle.name,
      textSize: Math.max(15, Math.min(30, Math.round(settings.fontSize))),
      letterSpacing: Math.round(Math.max(-0.5, Math.min(0.5, settings.letterSpacing)) * 100) / 100,
      paragraphSpacing: Math.max(0, Math.min(20, Math.round(settings.paragraphSpacing))),
      lineSpacingExtra: Math.max(0, Math.min(20, Math.round(settings.lineSpacing))),
      paragraphIndent: settings.paragraphIndent,
      textBold: settings.textBold,
      textItalic: settings.textItalic,
      textShadow: settings.textShadow,
      shadowRadius: settings.shadowRadius,
      shadowDx: settings.shadowDx,
      shadowDy: settings.shadowDy,
      shadowColor: settings.textShadowColor,
      shadowColorN: settings.textShadowColorN,
      underline: settings.underline,
      underlineHeight: settings.underlineHeight,
      underlinePadding: settings.underlinePadding,
      underlineExtend: settings.underlineExtend,
      prevKeyCodes: settings.prevKeys,
      nextKeyCodes: settings.nextKeys,
      mouseWheelPage: settings.mouseWheelPage,
      expandTextMenu: settings.expandTextMenu,
      showSelectMenuIcon: settings.showSelectMenuIcon,
      textSelectMenuConfig: settings.textSelectMenuConfig,
      doubleHorizontalPage: settings.doubleHorizontalPage,
      autoSuggestDayNight: settings.autoSuggestDayNight,
      disableReturnKey: settings.disableReturnKey,
      readBrightness: Math.max(1, Math.min(100, Math.round(settings.readBrightness))),
      showBrightnessView: settings.showBrightnessView,
      brightnessVwPos: settings.brightnessVwPos,
      brightnessAuto: settings.brightnessAuto,
      readBodyToLh: settings.readBodyToLh,
      useZhLayout: settings.useZhLayout,
      paddingDisplayCutouts: settings.paddingDisplayCutouts,
      adaptSpecialStyle: settings.adaptSpecialStyle,
      dottedBase: settings.dottedBase,
      dottedRatio: settings.dottedRatio,
      underlineColor: settings.underlineColor,
      underlineColorNight: settings.underlineColorNight,
      dottedLine: settings.dottedLine,
      paddingTop: settings.paddingSettings.paddingTop,
      paddingBottom: settings.paddingSettings.paddingBottom,
      paddingLeft: settings.paddingSettings.paddingLeft,
      paddingRight: settings.paddingSettings.paddingRight,
      headerPaddingTop: settings.paddingSettings.headerPaddingTop,
      headerPaddingBottom: settings.paddingSettings.headerPaddingBottom,
      headerPaddingLeft: settings.paddingSettings.headerPaddingLeft,
      headerPaddingRight: settings.paddingSettings.headerPaddingRight,
      footerPaddingTop: settings.paddingSettings.footerPaddingTop,
      footerPaddingBottom: settings.paddingSettings.footerPaddingBottom,
      footerPaddingLeft: settings.paddingSettings.footerPaddingLeft,
      footerPaddingRight: settings.paddingSettings.footerPaddingRight,
      hideStatusBar: settings.hideStatusBar,
      hideNavigationBar: settings.hideNavigationBar,
      pageAnim: Math.max(0, Math.min(5, Math.round(settings.pageAnimation))),
      pageAnimSpeed: Math.max(0, Math.min(3, Math.round(settings.animationSpeed))),
      headerMode: settings.headerMode,
      footerMode: settings.footerMode,
      showHeaderLine: settings.showHeaderLine,
      showFooterLine: settings.showFooterLine,
      tipHeaderLeft: settings.tipHeaderLeft,
      tipHeaderMiddle: settings.tipHeaderMiddle,
      tipHeaderRight: settings.tipHeaderRight,
      tipFooterLeft: settings.tipFooterLeft,
      tipFooterMiddle: settings.tipFooterMiddle,
      tipFooterRight: settings.tipFooterRight,
      customTipHeaderLeft: settings.customTipHeaderLeft,
      customTipHeaderMiddle: settings.customTipHeaderMiddle,
      customTipHeaderRight: settings.customTipHeaderRight,
      customTipFooterLeft: settings.customTipFooterLeft,
      customTipFooterMiddle: settings.customTipFooterMiddle,
      customTipFooterRight: settings.customTipFooterRight,
      headerFont: settings.headerFont,
      footerFont: settings.footerFont,
      headerFontSize: settings.headerFontSize,
      footerFontSize: settings.footerFontSize,
      applyHeaderStyle: settings.applyHeaderStyle,
      tipHeaderColor: settings.tipHeaderColor,
      tipHeaderColorNight: settings.tipHeaderColorNight,
      tipFooterColor: settings.tipFooterColor,
      tipFooterColorNight: settings.tipFooterColorNight,
      tipDividerColor: settings.tipDividerColor,
      // 上游 readConfig.json 里颜色与图片共用 bgStr，由 bgType 区分（ReadBookConfig.kt:549）；
      // 本地没自定义时回落到内置方案色，保持与旧备份的可读性。
      bgType: settings.bgType,
      bgStr: settings.bgStr.length > 0 ? settings.bgStr : dayStyle.dayColor,
      bgTypeNight: settings.bgTypeNight,
      bgStrNight: settings.bgStrNight.length > 0 ? settings.bgStrNight : nightStyle.nightColor,
      bgAlpha: Math.max(0, Math.min(100, Math.round(settings.bgAlpha))),
      textColor: settings.textColor,
      textColorNight: settings.textColorNight,
      textAccentColor: settings.textAccentColor,
      textAccentColorNight: settings.textAccentColorNight,
      darkStatusIcon: settings.darkStatusIcon,
      darkStatusIconNight: settings.darkStatusIconNight,
      titleMode: Math.max(0, Math.min(2, Math.round(settings.titleMode))),
      titleSize: Math.max(0, Math.min(100, Math.round(settings.titleSize))),
      titleSizeRelative: settings.titleSizeRelative,
      titleTopSpacing: Math.max(0, Math.min(100, Math.round(settings.titleTopSpacing))),
      titleBottomSpacing: Math.max(0, Math.min(100, Math.round(settings.titleBottomSpacing))),
      titleColor: settings.titleColor,
      titleColorNight: settings.titleColorNight,
      titleBold: Math.max(0, Math.min(900, Math.round(settings.titleBold))),
      titleLineSpacingExtra: Math.max(0, Math.min(20, Math.round(settings.titleLineSpacingExtra))),
      titleLineSpacingSub: Math.max(0, Math.min(20, Math.round(settings.titleLineSpacingSub))),
      titleSegType: Math.max(0, Math.min(3, Math.round(settings.titleSegType))),
      titleSegScaling: Math.max(1, Math.min(2, settings.titleSegScaling)),
      titleSegDistance: Math.max(0, Math.min(100, Math.round(settings.titleSegDistance))),
      titleSegFlag: settings.titleSegFlag
    };
  }

  private static restoreBookshelfLayout(
    directory: string,
    current: BookshelfLayoutSettings,
    ignoredCategories: string[]
  ): BookshelfLayoutSettings {
    // showBookIntro 不在上游 bookshelfPrefKeys 39 键内，走 keyIsNotIgnore 的 else -> true，
    // 取消 bookshelfLayout 勾选也照样恢复，所以在忽略判断之前单独读（KI-SL-B1）。
    const unconditionalIntro = BackupRepository.readXmlBoolean(`${directory}/config.xml`, 'showBookIntro');
    if (ignoredCategories.includes('bookshelfLayout')) {
      const unchanged = copyBookshelfLayout(current);
      if (unconditionalIntro !== undefined) { unchanged.showBookIntro = unconditionalIntro; }
      return unchanged;
    }
    const values = new Map<string, string>();
    const integerKeys = [
      'bookGroupStyle', 'bookshelfSort', 'bookshelfSortOrder', 'bookshelfLayoutPortrait',
      'bookshelfLayoutGridPortrait', 'bookshelfLayoutListPortrait', 'bookshelfTitleMaxLines',
      'bookshelfGridCoverWidth', 'bookshelfListCoverWidth',
      'bookshelfGridLayout', 'bookshelfCardColor', 'bookshelfCardColorDark', 'bookshelfIntroMaxLines', 'bookshelf_layout_landscape', 'bookshelfLayoutGridLandscape', 'bookshelfLayoutListLandscape', 'bookshelfFolderLayoutModePortrait', 'bookshelfFolderLayoutModeLandscape', 'bookshelfFolderLayoutGridPortrait', 'bookshelfFolderLayoutGridLandscape', 'bookshelfFolderLayoutListPortrait', 'bookshelfFolderLayoutListLandscape', 'bookshelfGroupListStyle', 'bookshelfGroupCoverCount', 'bookshelfRefreshingLimit', 'bookshelfUpdateLimit'
    ];
    for (let index = 0; index < integerKeys.length; index++) {
      const key = integerKeys[index];
      if (key === undefined) { continue; }
      const value = BackupRepository.readXmlInteger(`${directory}/config.xml`, key);
      if (value !== undefined) { values.set(key, value.toString()); }
    }
    const booleanKeys = ['hideEmptyGroups', 'bookshelfCoverShadow', 'bookshelfTitleCenter', 'bookshelfTitleSmallFont',
      'bookshelfLayoutCompact', 'bookshelfShowDivider', 'bookshelfListCoverCenter', 'bookshelfListIntroBelowContent', 'bookshelfShowIntro', 'bookshelfShowLatestChapter', 'bookshelfSearchActionDirectToSearch', 'showBookshelfFastScroller', 'auto_refresh', 'shouldShowExpandButton', 'bookshelfShowTag', 'bookshelfShowCustomTags', 'bookshelfShowSourceTags', 'bookshelfShowWordCount', 'showUnread', 'showUnreadNew', 'showWaitUpCount', 'showBookCount', 'showLastUpdateTime', 'showTip', 'enableCustomTagColors'];
    for (let index = 0; index < booleanKeys.length; index++) {
      const key = booleanKeys[index];
      if (key === undefined) { continue; }
      const value = BackupRepository.readXmlBoolean(`${directory}/config.xml`, key);
      if (value !== undefined) { values.set(key, value.toString()); }
    }
    const saveTabPositionValue = BackupRepository.readXmlLong(`${directory}/config.xml`, 'bookshelfSelectedGroupId');
    if (saveTabPositionValue !== undefined) { values.set('bookshelfSelectedGroupId', saveTabPositionValue); }
    if (unconditionalIntro !== undefined) { values.set('showBookIntro', unconditionalIntro.toString()); }
    const customTagColors = BackupRepository.readXmlString(`${directory}/config.xml`, 'customTagColors');
    if (customTagColors !== undefined) { values.set('customTagColors', customTagColors); }
    return BookshelfLayoutRepository.mergeFromAndroidValues(current, values);
  }

  /**
   * 从 config.xml 反向恢复封面设置。
   *
   * 14 个 coverPrefKeys 受 coverConfig 忽略开关控制；coverRestrictRatio / explore_filter_state
   * 属无条件键，取消 coverConfig 勾选也照样恢复（ZIP-COVER E2 / E3 判 `—`）。
   */
  private static restoreCoverSettings(
    directory: string,
    current: CoverSettings,
    ignoredCategories: string[]
  ): CoverSettings {
    const merged = copyCoverSettings(current);
    const configPath = `${directory}/config.xml`;
    const unconditionalRatio = BackupRepository.readXmlBoolean(configPath, 'coverRestrictRatio');
    const unconditionalFilter = BackupRepository.readXmlInteger(configPath, 'explore_filter_state');
    if (ignoredCategories.includes('coverConfig')) {
      if (unconditionalRatio !== undefined) { merged.restrictCoverRatio = unconditionalRatio; }
      if (unconditionalFilter !== undefined) { merged.exploreFilterState = unconditionalFilter; }
      return merged;
    }
    const values = new Map<string, string>();
    // 键表与写出侧 coverSettingsToAndroid 共用：按 type 选读取函数，值统一转字符串。
    for (const preference of coverSettingsToAndroid(current)) {
      let value: string | undefined;
      if (preference.type === 'boolean') {
        const parsed = BackupRepository.readXmlBoolean(configPath, preference.key);
        value = parsed === undefined ? undefined : `${parsed}`;
      } else if (preference.type === 'int') {
        const parsed = BackupRepository.readXmlInteger(configPath, preference.key);
        value = parsed === undefined ? undefined : `${parsed}`;
      } else {
        value = BackupRepository.readXmlString(configPath, preference.key);
      }
      if (value !== undefined) { values.set(preference.key, value); }
    }
    const restored = applyAndroidCoverPreferences(current, values);
    if (unconditionalRatio !== undefined) { restored.restrictCoverRatio = unconditionalRatio; }
    if (unconditionalFilter !== undefined) { restored.exploreFilterState = unconditionalFilter; }
    return restored;
  }

  private static applyEyeProtection(
    directory: string,
    current: ReaderSettingsSnapshot,
    ignoredCategories: string[]
  ): ReaderSettingsSnapshot {
    if (ignoredCategories.includes('themeConfig')) { return current; }
    const path = directory + '/config.xml';
    if (!fileIo.accessSync(path)) { return current; }
    const updated: ReaderSettingsSnapshot = JSON.parse(JSON.stringify(current));
    updated.eyeProtectionEnabled = BackupRepository.readXmlBoolean(path, 'eyeProtectionEnabled') ??
      current.eyeProtectionEnabled;
    updated.eyeProtectionAutoNight = BackupRepository.readXmlBoolean(path, 'eyeProtectionAutoNight') ??
      current.eyeProtectionAutoNight;
    updated.eyeProtectionSchedule = BackupRepository.readXmlBoolean(path, 'eyeProtectionSchedule') ??
      current.eyeProtectionSchedule;
    updated.eyeProtectionIntensity = Math.max(0, Math.min(100,
      BackupRepository.readXmlInteger(path, 'colorTemperature') ?? current.eyeProtectionIntensity));
    updated.eyeProtectionStartTime = BackupRepository.readXmlString(path, 'eyeProtectionStartTime') ??
      current.eyeProtectionStartTime;
    updated.eyeProtectionEndTime = BackupRepository.readXmlString(path, 'eyeProtectionEndTime') ??
      current.eyeProtectionEndTime;
    return updated;
  }
  private static restoreReaderSettings(
    directory: string,
    current: ReaderSettingsSnapshot,
    ignoredCategories: string[]
  ): ReaderSettingsSnapshot {
    if (ignoredCategories.includes('readConfig')) { return current; }
    const path = `${directory}/readConfig.json`;
    if (!fileIo.accessSync(path)) { return current; }
    const text = fileIo.readTextSync(path);
    const records = BackupRepository.splitJsonArray(text);
    if (records.length === 0) { return current; }
    const index = BackupRepository.readXmlInteger(`${directory}/config.xml`, 'readStyleSelect') ?? 0;
    const selected = records[Math.max(0, Math.min(records.length - 1, index))] ?? records[0] ?? '';
    const fontSizeValue = BackupRepository.readJsonNumber(selected, 'textSize');
    const dayPaperIndex = BackupRepository.paperIndexFromAndroidConfig(
      BackupRepository.readJsonNumber(selected, 'bgType') ?? 0,
      BackupRepository.readJsonString(selected, 'bgStr') ?? '',
      current.backgroundStyles
    );
    const nightPaperIndex = BackupRepository.paperIndexFromAndroidConfig(
      BackupRepository.readJsonNumber(selected, 'bgTypeNight') ?? 0,
      BackupRepository.readJsonString(selected, 'bgStrNight') ?? '',
      current.backgroundStyles
    );
    const shareLayout = BackupRepository.readXmlBoolean(`${directory}/config.xml`, 'shareLayout') ??
      current.shareLayout;
    const paperIndex = current.readerNightMode ? nightPaperIndex : dayPaperIndex;
    return {
      paddingSettings: {
        paddingTop: Math.max(0, Math.min(300, BackupRepository.readJsonNumber(selected, 'paddingTop') ?? current.paddingSettings.paddingTop)),
        paddingBottom: Math.max(0, Math.min(300, BackupRepository.readJsonNumber(selected, 'paddingBottom') ?? current.paddingSettings.paddingBottom)),
        paddingLeft: Math.max(0, Math.min(300, BackupRepository.readJsonNumber(selected, 'paddingLeft') ?? current.paddingSettings.paddingLeft)),
        paddingRight: Math.max(0, Math.min(300, BackupRepository.readJsonNumber(selected, 'paddingRight') ?? current.paddingSettings.paddingRight)),
        headerPaddingTop: Math.max(0, Math.min(300, BackupRepository.readJsonNumber(selected, 'headerPaddingTop') ?? current.paddingSettings.headerPaddingTop)),
        headerPaddingBottom: Math.max(0, Math.min(300, BackupRepository.readJsonNumber(selected, 'headerPaddingBottom') ?? current.paddingSettings.headerPaddingBottom)),
        headerPaddingLeft: Math.max(0, Math.min(300, BackupRepository.readJsonNumber(selected, 'headerPaddingLeft') ?? current.paddingSettings.headerPaddingLeft)),
        headerPaddingRight: Math.max(0, Math.min(300, BackupRepository.readJsonNumber(selected, 'headerPaddingRight') ?? current.paddingSettings.headerPaddingRight)),
        footerPaddingTop: Math.max(0, Math.min(300, BackupRepository.readJsonNumber(selected, 'footerPaddingTop') ?? current.paddingSettings.footerPaddingTop)),
        footerPaddingBottom: Math.max(0, Math.min(300, BackupRepository.readJsonNumber(selected, 'footerPaddingBottom') ?? current.paddingSettings.footerPaddingBottom)),
        footerPaddingLeft: Math.max(0, Math.min(300, BackupRepository.readJsonNumber(selected, 'footerPaddingLeft') ?? current.paddingSettings.footerPaddingLeft)),
        footerPaddingRight: Math.max(0, Math.min(300, BackupRepository.readJsonNumber(selected, 'footerPaddingRight') ?? current.paddingSettings.footerPaddingRight))
      },
      fontSize: fontSizeValue === undefined ? current.fontSize : Math.max(15, Math.min(30, Math.round(fontSizeValue))),
      letterSpacing: Math.round(Math.max(-0.5, Math.min(0.5, BackupRepository.readJsonNumber(selected, 'letterSpacing') ?? current.letterSpacing)) * 100) / 100,
      paragraphIndent: BackupRepository.readJsonString(selected, 'paragraphIndent') ?? current.paragraphIndent,
      paperIndex: paperIndex,
      dayPaperIndex: dayPaperIndex,
      nightPaperIndex: nightPaperIndex,
      // 自定义背景与文字颜色：上游这些字段都在 readConfig.json 里（ReadBookConfig.kt:731-746），
      // 老备份没有这些键时保持当前值。
      bgType: Math.max(0, Math.min(2, Math.round(BackupRepository.readJsonNumber(selected, 'bgType') ?? current.bgType))),
      bgStr: BackupRepository.readJsonString(selected, 'bgStr') ?? current.bgStr,
      bgTypeNight: Math.max(0, Math.min(2, Math.round(BackupRepository.readJsonNumber(selected, 'bgTypeNight') ?? current.bgTypeNight))),
      bgStrNight: BackupRepository.readJsonString(selected, 'bgStrNight') ?? current.bgStrNight,
      bgAlpha: Math.max(0, Math.min(100, Math.round(BackupRepository.readJsonNumber(selected, 'bgAlpha') ?? current.bgAlpha))),
      textColor: BackupRepository.readJsonString(selected, 'textColor') ?? current.textColor,
      textColorNight: BackupRepository.readJsonString(selected, 'textColorNight') ?? current.textColorNight,
      textAccentColor: BackupRepository.readJsonString(selected, 'textAccentColor') ?? current.textAccentColor,
      textAccentColorNight: BackupRepository.readJsonString(selected, 'textAccentColorNight') ?? current.textAccentColorNight,
      darkStatusIcon: BackupRepository.readJsonBoolean(selected, 'darkStatusIcon') ?? current.darkStatusIcon,
      darkStatusIconNight: BackupRepository.readJsonBoolean(selected, 'darkStatusIconNight') ?? current.darkStatusIconNight,
      // 标题排版十四个字段，读 readConfig.json；缺键时保留本机现值。
      titleMode: Math.max(0, Math.min(2,
        Math.round(BackupRepository.readJsonNumber(selected, 'titleMode') ?? current.titleMode))),
      titleSize: Math.max(0, Math.min(100,
        Math.round(BackupRepository.readJsonNumber(selected, 'titleSize') ?? current.titleSize))),
      titleSizeRelative: BackupRepository.readJsonBoolean(selected, 'titleSizeRelative') ?? current.titleSizeRelative,
      titleTopSpacing: Math.max(0, Math.min(100,
        Math.round(BackupRepository.readJsonNumber(selected, 'titleTopSpacing') ?? current.titleTopSpacing))),
      titleBottomSpacing: Math.max(0, Math.min(100,
        Math.round(BackupRepository.readJsonNumber(selected, 'titleBottomSpacing') ?? current.titleBottomSpacing))),
      titleColor: BackupRepository.readJsonString(selected, 'titleColor') ?? current.titleColor,
      titleColorNight: BackupRepository.readJsonString(selected, 'titleColorNight') ?? current.titleColorNight,
      titleBold: Math.max(0, Math.min(900,
        Math.round(BackupRepository.readJsonNumber(selected, 'titleBold') ?? current.titleBold))),
      titleLineSpacingExtra: Math.max(0, Math.min(20,
        Math.round(BackupRepository.readJsonNumber(selected, 'titleLineSpacingExtra') ?? current.titleLineSpacingExtra))),
      titleLineSpacingSub: Math.max(0, Math.min(20,
        Math.round(BackupRepository.readJsonNumber(selected, 'titleLineSpacingSub') ?? current.titleLineSpacingSub))),
      titleSegType: Math.max(0, Math.min(3,
        Math.round(BackupRepository.readJsonNumber(selected, 'titleSegType') ?? current.titleSegType))),
      titleSegScaling: Math.max(1, Math.min(2,
        BackupRepository.readJsonNumber(selected, 'titleSegScaling') ?? current.titleSegScaling)),
      titleSegDistance: Math.max(0, Math.min(100,
        Math.round(BackupRepository.readJsonNumber(selected, 'titleSegDistance') ?? current.titleSegDistance))),
      titleSegFlag: BackupRepository.readJsonString(selected, 'titleSegFlag') ?? current.titleSegFlag,
      readerNightMode: current.readerNightMode,
      shareLayout: shareLayout,
      // Android 备份里 readConfig.json 的每条就是一份样式（上游 ReadStyleState.items），
      // 这里只把「当前选中那一份」的颜色映射回本机下标，样式表本身保留本机现状：
      // 上游导入备份也不覆盖已有样式列表，只改选中项。
      backgroundStyles: current.backgroundStyles,
      systemTypefaces: Math.max(0, Math.min(2,
        BackupRepository.readXmlInteger(`${directory}/config.xml`, 'system_typefaces') ?? current.systemTypefaces)),
      // Android 字体路径属于 Android 私有目录；没有随 ZIP 附带可验证字体文件时保留本机选择。
      textFont: current.textFont,
      titleFont: current.titleFont,
      textFullJustify: BackupRepository.readXmlBoolean(`${directory}/config.xml`, 'textFullJustify') ?? current.textFullJustify,
      textBottomJustify: BackupRepository.readXmlBoolean(`${directory}/config.xml`, 'textBottomJustify') ?? current.textBottomJustify,
      textItalic: BackupRepository.readJsonBoolean(selected, 'textItalic') ??
        BackupRepository.readXmlBoolean(`${directory}/config.xml`, 'textItalic') ?? current.textItalic,
      textBold: BackupRepository.readJsonNumber(selected, 'textBold') ??
        BackupRepository.readXmlInteger(`${directory}/config.xml`, 'textBold') ?? current.textBold,
      textShadow: BackupRepository.readJsonBoolean(selected, 'textShadow') ??
        BackupRepository.readXmlBoolean(`${directory}/config.xml`, 'textShadow') ?? current.textShadow,
      shadowRadius: BackupRepository.readJsonNumber(selected, 'shadowRadius') ??
        BackupRepository.readXmlFloat(`${directory}/config.xml`, 'shadowRadius') ?? current.shadowRadius,
      shadowDx: BackupRepository.readJsonNumber(selected, 'shadowDx') ??
        BackupRepository.readXmlFloat(`${directory}/config.xml`, 'shadowDx') ?? current.shadowDx,
      shadowDy: BackupRepository.readJsonNumber(selected, 'shadowDy') ??
        BackupRepository.readXmlFloat(`${directory}/config.xml`, 'shadowDy') ?? current.shadowDy,
      textShadowColor: BackupRepository.readJsonString(selected, 'shadowColor') ??
        BackupRepository.readXmlString(`${directory}/config.xml`, 'shadowColor') ?? current.textShadowColor,
      textShadowColorN: BackupRepository.readJsonString(selected, 'shadowColorN') ??
        BackupRepository.readXmlString(`${directory}/config.xml`, 'shadowColorN') ?? current.textShadowColorN,
      underline: BackupRepository.readJsonBoolean(selected, 'underline') ??
        BackupRepository.readXmlBoolean(`${directory}/config.xml`, 'underline') ?? current.underline,
      dottedLine: BackupRepository.readJsonBoolean(selected, 'dottedLine') ??
        BackupRepository.readXmlBoolean(`${directory}/config.xml`, 'dottedLine') ?? current.dottedLine,
      underlineHeight: BackupRepository.readJsonNumber(selected, 'underlineHeight') ??
        BackupRepository.readXmlInteger(`${directory}/config.xml`, 'underlineHeight') ?? current.underlineHeight,
      underlinePadding: Math.max(0, Math.min(20, Math.round(
        BackupRepository.readJsonNumber(selected, 'underlinePadding') ??
        BackupRepository.readXmlInteger(`${directory}/config.xml`, 'underlinePadding') ??
        current.underlinePadding))),
      underlineExtend: BackupRepository.readJsonBoolean(selected, 'underlineExtend') ??
        BackupRepository.readXmlBoolean(`${directory}/config.xml`, 'underlineExtend') ?? current.underlineExtend,
      // 上游把这两串存在 prevKeyCodes/nextKeyCodes 里（PreferKey.kt:48-49），
      // 缺键时保留本机现值，避免恢复把已配置的按键清空。
      prevKeys: BackupRepository.readJsonString(selected, 'prevKeyCodes') ??
        BackupRepository.readXmlString(`${directory}/config.xml`, 'prevKeyCodes') ?? current.prevKeys,
      nextKeys: BackupRepository.readJsonString(selected, 'nextKeyCodes') ??
        BackupRepository.readXmlString(`${directory}/config.xml`, 'nextKeyCodes') ?? current.nextKeys,
      mouseWheelPage: BackupRepository.readJsonBoolean(selected, 'mouseWheelPage') ??
        BackupRepository.readXmlBoolean(`${directory}/config.xml`, 'mouseWheelPage') ?? current.mouseWheelPage,
      // 划词菜单三项；配置串缺键时保留本机现值，避免恢复把已排好的顺序清空。
      expandTextMenu: BackupRepository.readJsonBoolean(selected, 'expandTextMenu') ??
        BackupRepository.readXmlBoolean(`${directory}/config.xml`, 'expandTextMenu') ?? current.expandTextMenu,
      showSelectMenuIcon: BackupRepository.readJsonBoolean(selected, 'showSelectMenuIcon') ??
        BackupRepository.readXmlBoolean(`${directory}/config.xml`, 'showSelectMenuIcon') ?? current.showSelectMenuIcon,
      textSelectMenuConfig: BackupRepository.readJsonString(selected, 'textSelectMenuConfig') ??
        BackupRepository.readXmlString(`${directory}/config.xml`, 'textSelectMenuConfig') ?? current.textSelectMenuConfig,
      // 横屏双页档位：缺键或缺省成未知值时保留本机现值（四档以外一律回落 current）。
      doubleHorizontalPage: (() => {
        const mode = BackupRepository.readJsonString(selected, 'doubleHorizontalPage') ??
          BackupRepository.readXmlString(`${directory}/config.xml`, 'doubleHorizontalPage');
        if (mode === undefined || (mode !== '0' && mode !== '1' && mode !== '2' && mode !== '3')) {
          return current.doubleHorizontalPage;
        }
        return mode;
      })(),
      // 环境光日夜提醒开关：缺键时保留本机现值。
      autoSuggestDayNight: BackupRepository.readJsonBoolean(selected, 'autoSuggestDayNight') ??
        BackupRepository.readXmlBoolean(`${directory}/config.xml`, 'autoSuggestDayNight') ?? current.autoSuggestDayNight,
      disableReturnKey: BackupRepository.readJsonBoolean(selected, 'disableReturnKey') ??
        BackupRepository.readXmlBoolean(`${directory}/config.xml`, 'disableReturnKey') ?? current.disableReturnKey,
      readBrightness: Math.max(1, Math.min(100, Math.round(
        BackupRepository.readJsonNumber(selected, 'readBrightness') ??
          BackupRepository.readXmlInteger(`${directory}/config.xml`, 'brightness') ?? current.readBrightness))),
      showBrightnessView: (() => {
        const raw = BackupRepository.readJsonString(selected, 'showBrightnessView');
        if (raw === undefined) { return current.showBrightnessView; }
        return raw === '1' || raw === '2' ? raw : '0';
      })(),
      brightnessVwPos: (() => {
        const raw = BackupRepository.readJsonString(selected, 'brightnessVwPos');
        if (raw === undefined) { return current.brightnessVwPos; }
        return raw === '0' ? '0' : '1';
      })(),
      brightnessAuto: BackupRepository.readJsonBoolean(selected, 'brightnessAuto') ??
        BackupRepository.readXmlBoolean(`${directory}/config.xml`, 'brightnessAuto') ?? current.brightnessAuto,
      readBodyToLh: BackupRepository.readJsonBoolean(selected, 'readBodyToLh') ??
        BackupRepository.readXmlBoolean(`${directory}/config.xml`, 'readBodyToLh') ?? current.readBodyToLh,
      useZhLayout: BackupRepository.readJsonBoolean(selected, 'useZhLayout') ??
        BackupRepository.readXmlBoolean(`${directory}/config.xml`, 'useZhLayout') ?? current.useZhLayout,
      paddingDisplayCutouts: BackupRepository.readJsonBoolean(selected, 'paddingDisplayCutouts') ??
        BackupRepository.readXmlBoolean(`${directory}/config.xml`, 'paddingDisplayCutouts') ?? current.paddingDisplayCutouts,
      adaptSpecialStyle: BackupRepository.readJsonBoolean(selected, 'adaptSpecialStyle') ??
        BackupRepository.readXmlBoolean(`${directory}/config.xml`, 'adaptSpecialStyle') ?? current.adaptSpecialStyle,
      // 底栏外观六项：上游 BackupConfig.readPrefKeys 把 readMenuBottomCornerRadius /
      // readMenuFloatingBottomBar / readMenuBottomBarBlurMode / readMenuBottomBarBlurStyle /
      // readMenuBottomBarLiquidGlassButtons / readMenuBlurAlpha 全部列进忽略清单
      // （BackupConfig.kt:232-244），因此这里刻意不读备份、只用本机现值，
      // 保证恢复备份不会把这些外观项改掉。
      readMenuBottomCornerRadius: current.readMenuBottomCornerRadius,
      readMenuFloatingBottomBar: current.readMenuFloatingBottomBar,
      readMenuBottomBarBlurMode: current.readMenuBottomBarBlurMode,
      readMenuBottomBarBlurStyle: current.readMenuBottomBarBlurStyle,
      readMenuBottomBarLiquidGlassButtons: current.readMenuBottomBarLiquidGlassButtons,
      readMenuBlurAlpha: current.readMenuBlurAlpha,
      // 标题栏形态八项：上游 BackupConfig.readPrefKeys（BackupConfig.kt:234-259）把
      // readMenuTopBarBlurMode / readMenuTopBarLiquidGlassButtons / readMenuTopBarMergeButtons /
      // readMenuTopBarTitleCapsule / readMenuTopBarBlurStyle / titleBarIconStyle / titleBarMode
      // 七项列进忽略清单，只有 titleBarCompact 未列入、会随 config.xml 一起备份，
      // 因此只有它读备份，其余七项一律保留本机现值。
      readMenuTopBarTitleCapsule: current.readMenuTopBarTitleCapsule,
      titleBarMode: current.titleBarMode,
      titleBarCompact: BackupRepository.readXmlBoolean(`${directory}/config.xml`, 'titleBarCompact') ??
        current.titleBarCompact,
      titleBarIconStyle: current.titleBarIconStyle,
      readMenuTopBarBlurMode: current.readMenuTopBarBlurMode,
      readMenuTopBarBlurStyle: current.readMenuTopBarBlurStyle,
      readMenuTopBarLiquidGlassButtons: current.readMenuTopBarLiquidGlassButtons,
      readMenuTopBarMergeButtons: current.readMenuTopBarMergeButtons,
      // 菜单配色九项：上游 BackupConfig.readPrefKeys（BackupConfig.kt:216-247）把
      // readBarStyle / readMenuBgColor(Night) / readMenuAccentColor(Night) /
      // readMenuContainerColor(Night) / readMenuColorMode / readMenuPaletteStyle
      // 全部列进忽略清单，因此恢复备份时一律保留本机现值，不从 config.xml 读取。
      readBarStyle: current.readBarStyle,
      readMenuPaletteStyle: current.readMenuPaletteStyle,
      readMenuColorMode: current.readMenuColorMode,
      readMenuBgColor: current.readMenuBgColor,
      readMenuBgColorNight: current.readMenuBgColorNight,
      readMenuContainerColor: current.readMenuContainerColor,
      readMenuContainerColorNight: current.readMenuContainerColorNight,
      readMenuAccentColor: current.readMenuAccentColor,
      readMenuAccentColorNight: current.readMenuAccentColorNight,
      // 边框与模糊七项（KI-E2）：上游 BackupConfig.kt:225-251 把这批键全部列进
      // readPrefKeys 忽略清单，既不写 config.xml 也不进 readConfig.json，恢复一律保留本机现值。
      readMenuBorderWidth: current.readMenuBorderWidth,
      readMenuBorderColor: current.readMenuBorderColor,
      readMenuBorderColorNight: current.readMenuBorderColorNight,
      readMenuBlurRadius: current.readMenuBlurRadius,
      readMenuTextColor: current.readMenuTextColor,
      readMenuTextColorNight: current.readMenuTextColorNight,
      readMenuBlurColor: current.readMenuBlurColor,
      readMenuBlurColorNight: current.readMenuBlurColorNight,
      // 浮动图标四项的键全在 BackupConfig.readPrefKeys 忽略清单里
      // （BackupConfig.kt:228 readMenuIconShowText、:240 readMenuFloatingIconLiquidGlass、
      // :252 readMenuCustomIcons、:255 titleBarCustomIcons、:256 titleBarIconPosition、
      // :257 showTitleBarIcons），因此只保留本机现值、不从备份读写。
      showTitleBarIcons: current.showTitleBarIcons,
      titleBarIconPosition: current.titleBarIconPosition,
      readMenuFloatingIconLiquidGlass: current.readMenuFloatingIconLiquidGlass,
      floatingIcons: current.floatingIcons.map(
        (item: ReaderBottomActionConfig): ReaderBottomActionConfig => ({ id: item.id, enabled: item.enabled })
      ),
      titleBarCustomIcons: current.titleBarCustomIcons,
      readMenuCustomIcons: current.readMenuCustomIcons,
      // 菜单镜头半径与「阅读栏样式跟随页面」都在 BackupConfig.kt:248 / :217 的忽略清单里，
      // 上游有字段但没有任何设置入口，恢复一律保留本机现值。
      readMenuLensRadius: current.readMenuLensRadius,
      readBarStyleFollowPage: current.readBarStyleFollowPage,
      // moreActionsConfig 不在忽略清单里，优先读 config.xml；读不到（旧备份）就保留本机现值。
      moreActionsConfig: BackupRepository.readXmlString(`${directory}/config.xml`, 'moreActionsConfig') ??
        current.moreActionsConfig,
      // showMenuIcon 在忽略清单（BackupConfig.kt:258）里，恢复一律保留本机现值；
      // 另两项不在清单里，优先取 config.xml 的备份值。
      showMenuIcon: current.showMenuIcon,
      showReadTitleAddition: BackupRepository.readXmlBoolean(`${directory}/config.xml`, 'showReadTitleAddition') ??
        current.showReadTitleAddition,
      menuAlpha: BackupRepository.readXmlInteger(`${directory}/config.xml`, 'menuAlpha') ?? current.menuAlpha,
      dottedBase: Math.max(0, Math.min(20, Math.round(
        BackupRepository.readJsonNumber(selected, 'dottedBase') ??
        BackupRepository.readXmlFloat(`${directory}/config.xml`, 'dottedBase') ?? current.dottedBase))),
      dottedRatio: Math.max(0, Math.min(20, Math.round(
        BackupRepository.readJsonNumber(selected, 'dottedRatio') ??
        BackupRepository.readXmlFloat(`${directory}/config.xml`, 'dottedRatio') ?? current.dottedRatio))),
      underlineColor: BackupRepository.readJsonString(selected, 'underlineColor') ??
        BackupRepository.readXmlString(`${directory}/config.xml`, 'underlineColor') ?? current.underlineColor,
      underlineColorNight: BackupRepository.readJsonString(selected, 'underlineColorNight') ??
        BackupRepository.readXmlString(`${directory}/config.xml`, 'underlineColorNight') ?? current.underlineColorNight,
      showBottomActionText: BackupRepository.readXmlBoolean(`${directory}/config.xml`, 'readMenuIconShowText') ??
        current.showBottomActionText,
      bottomIconStyle: Math.max(0, Math.min(2,
        BackupRepository.readXmlInteger(`${directory}/config.xml`, 'readMenuIconStyle') ?? current.bottomIconStyle)),
      bottomItemsPerRow: Math.max(2, Math.min(8,
        BackupRepository.readXmlInteger(`${directory}/config.xml`, 'readMenuIconItemsPerRow') ?? current.bottomItemsPerRow)),
      bottomRowCount: Math.max(1, Math.min(2,
        BackupRepository.readXmlInteger(`${directory}/config.xml`, 'readMenuIconRowCount') ?? current.bottomRowCount)),
      bottomActions: current.bottomActions,
      topActions: current.topActions,
      progressBehavior: BackupRepository.readXmlString(`${directory}/config.xml`, 'progressBarBehavior') === 'chapter'
        ? 'chapter' : 'page',
      readSliderMode: (() => {
        // 备份里没有这个键就保留当前值，有则按 "1"/"0" 归一
        // readConfig.json 通道字段仍叫 readSliderMode（本地既有口径不动，且
        // toAndroidReadConfig 本就不写该字段）；config.xml 里上游键名是 read_slider_mode。
        const rawMode = BackupRepository.readJsonString(selected, 'readSliderMode') ??
          BackupRepository.readXmlString(`${directory}/config.xml`, 'read_slider_mode');
        if (rawMode === undefined) { return current.readSliderMode; }
        return rawMode === '1' ? '1' : '0';
      })(),
      pageTouchSlop: Math.max(0, Math.min(1000,
        BackupRepository.readJsonNumber(selected, 'pageTouchSlop') ??
        BackupRepository.readXmlInteger(`${directory}/config.xml`, 'pageTouchSlop') ?? current.pageTouchSlop)),
      lastMarkingStyle: BackupRepository.readJsonString(selected, 'lastMarkingStyle') ??
        BackupRepository.readXmlString(`${directory}/config.xml`, 'lastMarkingStyle') ?? current.lastMarkingStyle,
      tocUseReplace: BackupRepository.readXmlBoolean(`${directory}/config.xml`, 'tocUiUseReplace') ??
        current.tocUseReplace,
      tocShowWordCount: BackupRepository.readXmlBoolean(`${directory}/config.xml`, 'tocCountWords') ??
        current.tocShowWordCount,
      clickImageBehavior: BackupRepository.readXmlString(`${directory}/config.xml`, 'clickImgWay') ??
        current.clickImageBehavior,
      clickRegionActions: [
        BackupRepository.androidClickActionLabel(BackupRepository.readXmlInteger(`${directory}/config.xml`, 'clickActionTopLeft'), current.clickRegionActions[0] ?? '上一页'),
        BackupRepository.androidClickActionLabel(BackupRepository.readXmlInteger(`${directory}/config.xml`, 'clickActionTopCenter'), current.clickRegionActions[1] ?? '上一页'),
        BackupRepository.androidClickActionLabel(BackupRepository.readXmlInteger(`${directory}/config.xml`, 'clickActionTopRight'), current.clickRegionActions[2] ?? '下一页'),
        BackupRepository.androidClickActionLabel(BackupRepository.readXmlInteger(`${directory}/config.xml`, 'clickActionMiddleLeft'), current.clickRegionActions[3] ?? '上一页'),
        BackupRepository.androidClickActionLabel(BackupRepository.readXmlInteger(`${directory}/config.xml`, 'clickActionMiddleCenter'), current.clickRegionActions[4] ?? '菜单'),
        BackupRepository.androidClickActionLabel(BackupRepository.readXmlInteger(`${directory}/config.xml`, 'clickActionMiddleRight'), current.clickRegionActions[5] ?? '下一页'),
        BackupRepository.androidClickActionLabel(BackupRepository.readXmlInteger(`${directory}/config.xml`, 'clickActionBottomLeft'), current.clickRegionActions[6] ?? '上一页'),
        BackupRepository.androidClickActionLabel(BackupRepository.readXmlInteger(`${directory}/config.xml`, 'clickActionBottomCenter'), current.clickRegionActions[7] ?? '下一页'),
        BackupRepository.androidClickActionLabel(BackupRepository.readXmlInteger(`${directory}/config.xml`, 'clickActionBottomRight'), current.clickRegionActions[8] ?? '下一页')
      ],
      screenOrientation: current.screenOrientation,
      keepLight: current.keepLight,
      volumeKeyPage: current.volumeKeyPage,
      keyPageOnLongPress: current.keyPageOnLongPress,
      noAnimScrollPage: current.noAnimScrollPage,
      eyeProtectionEnabled: current.eyeProtectionEnabled,
      eyeProtectionAutoNight: current.eyeProtectionAutoNight,
      eyeProtectionSchedule: current.eyeProtectionSchedule,
      eyeProtectionIntensity: current.eyeProtectionIntensity,
      eyeProtectionStartTime: current.eyeProtectionStartTime,
      eyeProtectionEndTime: current.eyeProtectionEndTime,
      readingAnchorEnabled: BackupRepository.readXmlBoolean(`${directory}/config.xml`, 'readingAnchorEnabled') ??
        current.readingAnchorEnabled,
      swipeToAddBookmark: BackupRepository.readXmlBoolean(`${directory}/config.xml`, 'swipeToAddBookmark') ??
        current.swipeToAddBookmark,
      // 上游把角标大小写在 config.xml 的 bookmarkBadgeSize 里，缺失时保留当前值。
      bookmarkBadgeSize: Math.max(0, Math.min(50,
        BackupRepository.readXmlInteger(`${directory}/config.xml`, 'bookmarkBadgeSize') ??
          current.bookmarkBadgeSize)),
      // Android 记录的角标图片路径属 Android 私有目录，恢复过来指向不存在的文件；
      // 只有当那个路径在本机沙箱里确实存在时才采用，否则保留本机选择。
      bookmarkBadgeImage: ((): string => {
        const restoredBadgeImage = BackupRepository.readXmlString(`${directory}/config.xml`, 'bookmarkBadgeImage');
        if (restoredBadgeImage === undefined || restoredBadgeImage.length === 0) { return ''; }
        try {
          return fileIo.accessSync(restoredBadgeImage) ? restoredBadgeImage : current.bookmarkBadgeImage;
        } catch (error) {
          console.error(`[BackupRepository] 检查角标图片是否存在失败: ${error}`);
          return current.bookmarkBadgeImage;
        }
      })(),
      selectText: current.selectText,
      sliderVibrator: BackupRepository.readJsonBoolean(selected, 'sliderVibrator') ??
        BackupRepository.readXmlBoolean(`${directory}/config.xml`, 'sliderVibrator') ?? current.sliderVibrator,
      selectVibrator: BackupRepository.readJsonBoolean(selected, 'selectVibrator') ??
        BackupRepository.readXmlBoolean(`${directory}/config.xml`, 'selectVibrator') ?? current.selectVibrator,
      chineseConverterType: Math.max(0, Math.min(2,
        Math.round(BackupRepository.readJsonNumber(selected, 'chineseConverterType') ??
          BackupRepository.readXmlInteger(`${directory}/config.xml`, 'chineseConverterType') ??
          current.chineseConverterType))),
      paragraphSpacing: Math.max(0, Math.min(20, Math.round(BackupRepository.readJsonNumber(selected, 'paragraphSpacing') ?? BackupRepository.readXmlInteger(`${directory}/config.xml`, 'paragraphSpacing') ?? current.paragraphSpacing))),
      lineSpacing: Math.max(0, Math.min(20, Math.round(BackupRepository.readJsonNumber(selected, 'lineSpacingExtra') ?? BackupRepository.readXmlInteger(`${directory}/config.xml`, 'lineSpacingExtra') ?? current.lineSpacing))),
      maxLengthWithNoToc: Math.max(3000, Math.min(100000,
        BackupRepository.readXmlInteger(`${directory}/config.xml`, 'maxLengthWithNoToc') ??
          current.maxLengthWithNoToc)),
      hideStatusBar: BackupRepository.readXmlBoolean(`${directory}/config.xml`, 'hideStatusBar') ??
        current.hideStatusBar,
      hideNavigationBar: BackupRepository.readXmlBoolean(`${directory}/config.xml`, 'hideNavigationBar') ??
        current.hideNavigationBar,
      showQuickActions: current.showQuickActions,
      autoReadSpeed: current.autoReadSpeed,
      pageAnimation: Math.max(0, Math.min(5,
        BackupRepository.readJsonNumber(selected, 'pageAnim') ?? current.pageAnimation)),
      animationSpeed: Math.max(0, Math.min(3,
        BackupRepository.readJsonNumber(selected, 'pageAnimSpeed') ?? current.animationSpeed)),
      headerMode: Math.max(0, Math.min(2,
        BackupRepository.readJsonNumber(selected, 'headerMode') ?? current.headerMode)),
      footerMode: Math.max(0, Math.min(1,
        BackupRepository.readJsonNumber(selected, 'footerMode') ?? current.footerMode)),
      showHeaderLine: BackupRepository.readJsonBoolean(selected, 'showHeaderLine') ?? current.showHeaderLine,
      showFooterLine: BackupRepository.readJsonBoolean(selected, 'showFooterLine') ?? current.showFooterLine,
      tipHeaderLeft: BackupRepository.readJsonNumber(selected, 'tipHeaderLeft') ?? current.tipHeaderLeft,
      tipHeaderMiddle: BackupRepository.readJsonNumber(selected, 'tipHeaderMiddle') ?? current.tipHeaderMiddle,
      tipHeaderRight: BackupRepository.readJsonNumber(selected, 'tipHeaderRight') ?? current.tipHeaderRight,
      tipFooterLeft: BackupRepository.readJsonNumber(selected, 'tipFooterLeft') ?? current.tipFooterLeft,
      tipFooterMiddle: BackupRepository.readJsonNumber(selected, 'tipFooterMiddle') ?? current.tipFooterMiddle,
      tipFooterRight: BackupRepository.readJsonNumber(selected, 'tipFooterRight') ?? current.tipFooterRight,
      customTipHeaderLeft: BackupRepository.readJsonString(selected, 'customTipHeaderLeft') ?? current.customTipHeaderLeft,
      customTipHeaderMiddle: BackupRepository.readJsonString(selected, 'customTipHeaderMiddle') ?? current.customTipHeaderMiddle,
      customTipHeaderRight: BackupRepository.readJsonString(selected, 'customTipHeaderRight') ?? current.customTipHeaderRight,
      customTipFooterLeft: BackupRepository.readJsonString(selected, 'customTipFooterLeft') ?? current.customTipFooterLeft,
      customTipFooterMiddle: BackupRepository.readJsonString(selected, 'customTipFooterMiddle') ?? current.customTipFooterMiddle,
      customTipFooterRight: BackupRepository.readJsonString(selected, 'customTipFooterRight') ?? current.customTipFooterRight,
      headerFont: BackupRepository.readJsonString(selected, 'headerFont') ?? current.headerFont,
      footerFont: BackupRepository.readJsonString(selected, 'footerFont') ?? current.footerFont,
      headerFontSize: BackupRepository.readJsonNumber(selected, 'headerFontSize') ?? current.headerFontSize,
      footerFontSize: BackupRepository.readJsonNumber(selected, 'footerFontSize') ?? current.footerFontSize,
      applyHeaderStyle: BackupRepository.readJsonBoolean(selected, 'applyHeaderStyle') ?? current.applyHeaderStyle,
      tipHeaderColor: BackupRepository.readJsonNumber(selected, 'tipHeaderColor') ?? current.tipHeaderColor,
      tipHeaderColorNight: BackupRepository.readJsonNumber(selected, 'tipHeaderColorNight') ?? current.tipHeaderColorNight,
      tipFooterColor: BackupRepository.readJsonNumber(selected, 'tipFooterColor') ?? current.tipFooterColor,
      tipFooterColorNight: BackupRepository.readJsonNumber(selected, 'tipFooterColorNight') ?? current.tipFooterColorNight,
      tipDividerColor: BackupRepository.readJsonNumber(selected, 'tipDividerColor') ?? current.tipDividerColor
    };
  }

  private static async restoreMatchingLocalProgress(
    context: Context,
    directory: string,
    currentBooks: Book[],
    ignoredCategories: string[]
  ): Promise<RestoredBookProgress> {
    if (ignoredCategories.includes('localBook')) {
      return { books: currentBooks, updatedCount: 0, createdMissingBodyCount: 0, deletedDuplicateCount: 0 };
    }
    const path = `${directory}/bookshelf.json`;
    if (!fileIo.accessSync(path)) {
      return { books: currentBooks, updatedCount: 0, createdMissingBodyCount: 0, deletedDuplicateCount: 0 };
    }
    const records = BackupRepository.splitJsonArray(fileIo.readTextSync(path));
    let result: Book[] = currentBooks;
    let updatedCount: number = 0;
    let createdMissingBodyCount: number = 0;
    let deletedDuplicateCount: number = 0;
    // ZIP 里读出来的本地书先收集，交给 LocalBookRestorePlanner 做冲突规划。
    // 上游 Restore.kt:130-140 是先 planBookRestore 再一次性 delete/update/insert，
    // 所以规划要提到进度合并之前：重定位的书得先知道落到哪一条路径上。
    const restoredLocalBooks: Book[] = [];
    for (let recordIndex = 0; recordIndex < records.length; recordIndex++) {
      const record = records[recordIndex] ?? '';
      if (!BackupRepository.isLocalAndroidBook(record)) { continue; }
      const originalPath = BackupRepository.readJsonString(record, 'bookUrl') ?? '';
      if (originalPath.length === 0) { continue; }
      restoredLocalBooks.push(BackupRepository.createMissingBodyBook(record, originalPath));
    }
    const plan = LocalBookRestorePlanner.planBookRestore(
      restoredLocalBooks,
      result,
      false,
      LocalBookRestorePlanner.localBookLocationStatus
    );
    for (let bookIndex = 0; bookIndex < currentBooks.length; bookIndex++) {
      const book = currentBooks[bookIndex];
      if (book === undefined || book.contentPath === undefined) { continue; }
      for (let recordIndex = 0; recordIndex < records.length; recordIndex++) {
        const record = records[recordIndex] ?? '';
        const recordUrl = BackupRepository.readJsonString(record, 'bookUrl') ?? '';
        // 重定位的书：备份里的原始路径已被规划到本地另一条路径，按落点匹配才能合并进度。
        const targetUrl = plan.resolvedTargets.get(recordUrl) ?? recordUrl;
        if (targetUrl !== book.contentPath) { continue; }
        const index = BackupRepository.readJsonNumber(record, 'durChapterIndex');
        const position = BackupRepository.readJsonNumber(record, 'durChapterPos');
        const savedCharset = BackupRepository.readJsonString(record, 'charset');
        let bookWithCharset = book;
        if (book.format === 'txt' && savedCharset !== undefined && savedCharset.length > 0 &&
          savedCharset !== book.charset) {
          try {
            // withCharset 会顺带重算目录，这里只要书本身，章节行在保存书目后统一重写。
            bookWithCharset = BookRepository.withCharset(book, savedCharset).book;
          } catch (error) {
            console.error(`[BackupRepository] 按保存的编码重算书目失败: ${error}`);
          }
        }
        const restoredProgress = await BookRepository.restoreAndroidProgress(bookWithCharset,
          index === undefined ? book.chapterIndex ?? 0 : index,
          position === undefined ? 0 : position);
        let updated = BookRepository.withShelfMetadata(restoredProgress,
          restoredProgress.groupNames ?? [], restoredProgress.groupName ?? '', restoredProgress.customTag,
          restoredProgress.title, restoredProgress.author, restoredProgress.category,
          restoredProgress.description, restoredProgress.remark);
        updated.latestChapterTime = Math.max(0, Math.trunc(BackupRepository.readJsonNumber(record, 'latestChapterTime') ?? restoredProgress.latestChapterTime ?? 0));
        updated.durChapterTime = Math.max(0, Math.trunc(BackupRepository.readJsonNumber(record, 'durChapterTime') ?? restoredProgress.durChapterTime ?? 0));
        updated.order = Math.trunc(BackupRepository.readJsonNumber(record, 'order') ?? restoredProgress.order ?? 0);
        if (!ignoredCategories.includes('bookGroup')) {
          const groupMask = BackupRepository.readJsonNumber(record, 'group') ?? 0;
          const groupNames = BookGroupRepository.namesFromMask(groupMask);
          const backupIntro = BackupRepository.readJsonString(record, 'customIntro') ??
            BackupRepository.readJsonString(record, 'intro');
          const groupedBook = BookRepository.withShelfMetadata(
            updated, groupNames, groupNames.length > 0 ? groupNames.join('、') : '本地未分组',
            BackupRepository.readJsonString(record, 'customTag') ?? restoredProgress.customTag,
            BackupRepository.readJsonString(record, 'name') ?? restoredProgress.title,
            BackupRepository.readJsonString(record, 'author') ?? restoredProgress.author,
            BackupRepository.readJsonString(record, 'kind') ?? restoredProgress.category,
            backupIntro ?? restoredProgress.description,
            BackupRepository.readJsonString(record, 'remark') ?? updated.remark
          );
          groupedBook.latestChapterTime = updated.latestChapterTime;
          groupedBook.durChapterTime = updated.durChapterTime;
          groupedBook.order = updated.order;
          updated = groupedBook;
        }
        result = result.map((item: Book) => item.id === updated.id ? updated : item);
        updatedCount += 1;
        break;
      }
    }
    for (let index = 0; index < plan.booksToDelete.length; index++) {
      const duplicate = plan.booksToDelete[index];
      if (duplicate === undefined) { continue; }
      await BookRepository.deleteBook(context, duplicate);
      result = result.filter((book: Book) => book.id !== duplicate.id);
      deletedDuplicateCount += 1;
    }
    for (let index = 0; index < plan.booksToInsert.length; index++) {
      const inserted = plan.booksToInsert[index];
      if (inserted === undefined) { continue; }
      if (result.some((book: Book) =>
        book.contentPath === inserted.androidOriginalPath ||
        book.androidOriginalPath === inserted.androidOriginalPath)) { continue; }
      result = [...result, inserted];
      createdMissingBodyCount += 1;
    }
    return {
      books: result,
      updatedCount: updatedCount,
      createdMissingBodyCount: createdMissingBodyCount,
      deletedDuplicateCount: deletedDuplicateCount
    };
  }

  private static androidClickActionValue(action: string): number {
    if (action === '菜单') { return 0; }
    if (action === '下一页') { return 1; }
    if (action === '上一页') { return 2; }
    if (action === '下一章') { return 3; }
    if (action === '上一章') { return 4; }
    if (action === '朗读上一段') { return 5; }
    if (action === '朗读下一段') { return 6; }
    if (action === '添加书签') { return 7; }
    if (action === '编辑内容') { return 8; }
    if (action === '替换(启用/禁用)') { return 9; }
    if (action === '目录') { return 10; }
    if (action === '全文搜索') { return 11; }
    if (action === '同步阅读进度') { return 12; }
    if (action === '朗读暂停/继续') { return 13; }
    return -1;
  }

  private static androidClickActionLabel(value: number | undefined, fallback: string): string {
    if (value === undefined) { return fallback; }
    if (value === -1) { return '无操作'; }
    const actions: string[] = [
      '菜单', '下一页', '上一页', '下一章', '上一章', '朗读上一段', '朗读下一段', '添加书签',
      '编辑内容', '替换(启用/禁用)', '目录', '全文搜索', '同步阅读进度', '朗读暂停/继续'
    ];
    return actions[value] ?? fallback;
  }

  private static createMissingBodyBook(record: string, originalPath: string): Book {
    const title = BackupRepository.readJsonString(record, 'name') ?? '未命名本地书籍';
    const author = BackupRepository.readJsonString(record, 'author') ?? '';
    const chapterIndexValue = BackupRepository.readJsonNumber(record, 'durChapterIndex') ?? 0;
    const characterPosition = BackupRepository.readJsonNumber(record, 'durChapterPos') ?? 0;
    const totalChapters = Math.max(0, Math.trunc(BackupRepository.readJsonNumber(record, 'totalChapterNum') ?? 0));
    const chapterCount = Math.max(totalChapters, Math.trunc(chapterIndexValue) + 1);
    const chapterIndex = Math.max(0, Math.trunc(chapterIndexValue));
    const progress = chapterCount > 0 ? Math.min(100, chapterIndex / chapterCount * 100) : 0;
    const latestChapter = BackupRepository.readJsonString(record, 'durChapterTitle') ??
      BackupRepository.readJsonString(record, 'latestChapterTitle') ?? '';
    const customIntro = BackupRepository.readJsonString(record, 'customIntro') ?? '';
    const intro = BackupRepository.readJsonString(record, 'intro') ?? '';
    const customTag = BackupRepository.readJsonString(record, 'customTag') ?? '';
    const groupMask = BackupRepository.readJsonNumber(record, 'group') ?? 0;
    const groupNames = BookGroupRepository.namesFromMask(groupMask);
    const placeholder: Book = {
      id: BackupRepository.missingBodyBookId(originalPath),
      title: title,
      author: author,
      category: BackupRepository.readJsonString(record, 'kind') ?? '本地',
      groupName: groupNames.length > 0 ? groupNames.join('、') : '本地未分组',
      groupNames: groupNames,
      chapterIndex: chapterIndex,
      chapterProgress: 0,
      lastChapter: latestChapter,
      latestChapterTime: Math.max(0, Math.trunc(BackupRepository.readJsonNumber(record, 'latestChapterTime') ?? 0)),
      durChapterTime: Math.max(0, Math.trunc(BackupRepository.readJsonNumber(record, 'durChapterTime') ?? 0)),
      order: Math.trunc(BackupRepository.readJsonNumber(record, 'order') ?? 0),
      progress: progress,
      chapterCount: totalChapters.toString(),
      description: customIntro.length > 0 ? customIntro : intro,
      remark: BackupRepository.readJsonString(record, 'remark') ?? undefined,
      customTag: customTag.length > 0 ? customTag : undefined,
      // 缺正文占位书：没有 contentPath，只有原始路径，正文缺失由 BookRepository.isBodyMissing 判定。
      androidOriginalPath: originalPath,
      androidCharacterPosition: Math.max(0, Math.trunc(characterPosition)),
      format: originalPath.toLowerCase().endsWith('.epub') ? 'epub' : 'txt',
      charset: BackupRepository.readJsonString(record, 'charset') ?? undefined,
      isLocal: true
    };
    return placeholder;
  }

  private static missingBodyBookId(originalPath: string): string {
    let hash = 2166136261;
    for (let index = 0; index < originalPath.length; index++) {
      hash ^= originalPath.charCodeAt(index);
      hash = Math.imul(hash, 16777619) >>> 0;
    }
    return `android-missing-${hash.toString(16)}`;
  }

  private static readEntryPreviews(directory: string): BackupEntryPreview[] {
    let names: string[] = [];
    try { names = fileIo.listFileSync(directory); } catch (error) { console.error(`[BackupRepository] 列出备份目录失败: ${error}`); return []; }
    const entries: BackupEntryPreview[] = [];
    for (let index = 0; index < names.length; index++) {
      const name = names[index];
      if (name === undefined || !BackupRepository.isSafeRootEntry(name)) { continue; }
      const path = `${directory}/${name}`;
      try {
        if (!fileIo.lstatSync(path).isFile()) { continue; }
        const size = fileIo.statSync(path).size;
        let count: number = -1;
        if (name.endsWith('.json') && size <= BackupRepository.maximumJsonTextBytes) {
          const content = fileIo.readTextSync(path);
          count = BackupRepository.countJsonRecords(content);
        } else if (name === 'config.xml' && size <= BackupRepository.maximumJsonTextBytes) {
          count = BackupRepository.countXmlEntries(fileIo.readTextSync(path));
        }
        entries.push({ name: name, recordCount: count, byteSize: size });
      } catch (error) {
        console.error(`[BackupRepository] 读取备份条目失败: ${error}`);
      }
    }
    return entries;
  }

  private static buildRestoredEntrySummary(
    selection: BackupSelection,
    ignoredCategories: string[]
  ): BackupEntryPreview[] {
    const entries: BackupEntryPreview[] = [];
    for (let index = 0; index < selection.preview.entries.length; index++) {
      const entry = selection.preview.entries[index];
      if (entry === undefined || BackupRepository.isIgnored(entry.name, ignoredCategories)) { continue; }
      if (entry.name === 'bookshelf.json' && ignoredCategories.includes('localBook')) {
        const source = fileIo.readTextSync(`${selection.stagingDirectory}/${entry.name}`);
        const filtered = BackupRepository.filterLocalBooks(source);
        const count = BackupRepository.countJsonRecords(filtered);
        if (count > 0) { entries.push({ name: entry.name, recordCount: count, byteSize: filtered.length }); }
        continue;
      }
      if (entry.name === 'config.xml') {
        const source = fileIo.readTextSync(`${selection.stagingDirectory}/${entry.name}`);
        const filtered = BackupRepository.filterAndroidConfigXml(source, ignoredCategories);
        entries.push({ name: entry.name, recordCount: BackupRepository.countXmlEntries(filtered), byteSize: filtered.length });
      } else {
        entries.push(entry);
      }
    }
    return entries;
  }

  private static async saveRestoredEntrySummary(context: Context, entries: BackupEntryPreview[]): Promise<void> {
    const store = await preferences.getPreferences(context, BackupRepository.preferenceName);
    const records: string[] = [];
    for (let index = 0; index < entries.length; index++) {
      const entry = entries[index];
      if (entry !== undefined) {
        records.push(`${encodeURIComponent(entry.name)}|${entry.recordCount}|${entry.byteSize}`);
      }
    }
    await store.put(BackupRepository.restoredEntrySummaryKey, records.join('\n'));
    await store.flush();
  }

  private static parseEntrySummary(value: string): BackupEntryPreview[] {
    const entries: BackupEntryPreview[] = [];
    const records = value.split('\n');
    for (let index = 0; index < records.length; index++) {
      const fields = (records[index] ?? '').split('|');
      if (fields.length !== 3) { continue; }
      const count = Number(fields[1]);
      const size = Number(fields[2]);
      if (!Number.isInteger(count) || !Number.isFinite(size) || size < 0) { continue; }
      entries.push({ name: decodeURIComponent(fields[0] ?? ''), recordCount: count, byteSize: size });
    }
    return entries;
  }

  private static countLocalBooks(text: string): number {
    const records = BackupRepository.splitJsonArray(text);
    let count: number = 0;
    for (let index = 0; index < records.length; index++) {
      const record = records[index] ?? '';
      if (BackupRepository.isLocalAndroidBook(record)) { count += 1; }
    }
    return count;
  }

  /** 与上游 BookExtensions.kt:66-73 的 Book.isLocal 同语义：type 为 0（老数据无类型位）时按 origin 前缀判。 */
  private static isLocalAndroidBook(record: string): boolean {
    const origin = BackupRepository.readJsonString(record, 'origin') ?? '';
    const type = Math.trunc(BackupRepository.readJsonNumber(record, 'type') ?? 0);
    if (type === 0) {
      return origin === 'loc_book' || origin.startsWith('webDav::');
    }
    return (type & 256) !== 0;
  }

  private static filterLocalBooks(text: string): string {
    const records = BackupRepository.splitJsonArray(text)
      .filter((record: string) => !BackupRepository.isLocalAndroidBook(record));
    return `[${records.join(',')}]`;
  }

  private static async copyPreservedEntries(context: Context, targetDirectory: string, ignored: string[]): Promise<void> {
    const sourceDirectory = `${context.filesDir}/${BackupRepository.legacyDirectoryName}`;
    let names: string[] = [];
    try { names = fileIo.listFileSync(sourceDirectory); } catch (error) { console.error(`[BackupRepository] 列出待保留条目目录失败: ${error}`); return; }
    for (let index = 0; index < names.length; index++) {
      const name = names[index];
      if (name === undefined || !BackupRepository.isSafeRootEntry(name) ||
        BackupRepository.isIgnored(name, ignored)) { continue; }
      const sourcePath = `${sourceDirectory}/${name}`;
      const targetPath = `${targetDirectory}/${name}`;
      try {
        if (!fileIo.lstatSync(sourcePath).isFile()) { continue; }
        if (name === 'bookshelf.json' && ignored.includes('localBook')) {
          const remaining = BackupRepository.filterLocalBooks(fileIo.readTextSync(sourcePath));
          if (remaining.length > 2) { BackupRepository.writeTextFile(targetPath, remaining); }
        } else if (name === 'config.xml') {
          const content = BackupRepository.filterAndroidConfigXml(fileIo.readTextSync(sourcePath), ignored);
          BackupRepository.writeTextFile(targetPath, content);
        } else {
          await fileIo.copyFile(sourcePath, targetPath);
        }
      } catch (error) {
        const detail = error instanceof Error ? error.message : '未知错误';
        throw new Error(`无法保留 Android 备份条目 ${name}：${detail}`);
      }
    }
  }

  /** 解析阅读记录 JSON 数组：坏文件按空数组处理，不中断整包导入。 */
  private static parseReadRecordArray(text: string): Object[] {
    try {
      const parsed = JSON.parse(text) as Object;
      if (Array.isArray(parsed)) { return parsed as Object[]; }
    } catch (error) {
      console.error(`[BackupRepository] 解析阅读记录失败: ${error}`);
    }
    return [];
  }

  /** 上游 readRecord.json 逐字段转成本地 ReadRecordSummary。 */
  private static toReadRecordSummaries(rows: Object[]): ReadRecordSummary[] {
    const result: ReadRecordSummary[] = [];
    for (const row of rows) {
      const record = row as Record<string, Object>;
      const item: ReadRecordSummary = {
        deviceId: BackupRepository.readString(record, 'deviceId'),
        bookName: BackupRepository.readString(record, 'bookName'),
        bookAuthor: BackupRepository.readString(record, 'bookAuthor'),
        readTime: BackupRepository.readNumber(record, 'readTime', 0),
        lastRead: BackupRepository.readNumber(record, 'lastRead', 0)
      };
      result.push(item);
    }
    return result;
  }

  /** 上游 readRecordDetail.json 逐字段转成本地 ReadRecordDetail。 */
  private static toReadRecordDetails(rows: Object[]): ReadRecordDetail[] {
    const result: ReadRecordDetail[] = [];
    for (const row of rows) {
      const record = row as Record<string, Object>;
      const item: ReadRecordDetail = {
        deviceId: BackupRepository.readString(record, 'deviceId'),
        bookName: BackupRepository.readString(record, 'bookName'),
        bookAuthor: BackupRepository.readString(record, 'bookAuthor'),
        date: BackupRepository.readString(record, 'date'),
        readTime: BackupRepository.readNumber(record, 'readTime', 0),
        readWords: BackupRepository.readNumber(record, 'readWords', 0),
        firstReadTime: BackupRepository.readNumber(record, 'firstReadTime', 0),
        lastReadTime: BackupRepository.readNumber(record, 'lastReadTime', 0)
      };
      result.push(item);
    }
    return result;
  }

  /** 上游 readRecordSession.json 的 words 改名成本地 chapterIndex。 */
  private static toReadRecordSessions(rows: Object[]): ReadRecordSession[] {
    const result: ReadRecordSession[] = [];
    for (const row of rows) {
      const record = row as Record<string, Object>;
      const item: ReadRecordSession = {
        deviceId: BackupRepository.readString(record, 'deviceId'),
        bookName: BackupRepository.readString(record, 'bookName'),
        bookAuthor: BackupRepository.readString(record, 'bookAuthor'),
        bookUrl: BackupRepository.readString(record, 'bookUrl'),
        startTime: BackupRepository.readNumber(record, 'startTime', 0),
        endTime: BackupRepository.readNumber(record, 'endTime', 0),
        chapterIndex: BackupRepository.readNumber(record, 'words', 0)
      };
      result.push(item);
    }
    return result;
  }

  /**
   * 解析归档里的 coverRule.json。
   * 上游恢复是整段字符串直塞，本地要结构体，所以逐字段取、缺项补默认；
   * 坏 JSON 回退默认规则，不抛错（对齐上游 runCatching 的容错姿态）。
   */
  private static parseCoverRule(text: string): CoverRule {
    const rule: CoverRule = copyCoverRule(DEFAULT_COVER_RULE);
    try {
      const raw = JSON.parse(text) as Record<string, Object>;
      if (typeof raw.enable === 'boolean') { rule.enable = raw.enable as boolean; }
      if (typeof raw.searchUrl === 'string') { rule.searchUrl = raw.searchUrl as string; }
      if (typeof raw.coverRule === 'string') { rule.coverRule = raw.coverRule as string; }
      if (typeof raw.concurrentRate === 'string') { rule.concurrentRate = raw.concurrentRate as string; }
      if (typeof raw.loginUrl === 'string') { rule.loginUrl = raw.loginUrl as string; }
      if (typeof raw.loginUi === 'string') { rule.loginUi = raw.loginUi as string; }
      if (typeof raw.header === 'string') { rule.header = raw.header as string; }
      if (typeof raw.jsLib === 'string') { rule.jsLib = raw.jsLib as string; }
      if (typeof raw.enabledCookieJar === 'boolean') {
        rule.enabledCookieJar = raw.enabledCookieJar as boolean;
      }
    } catch (error) {
      console.error(`[BackupRepository] 解析 coverRule.json 失败，回退默认规则: ${error}`);
    }
    return rule;
  }

  private static isIgnored(fileName: string, ignored: string[]): boolean {
    if (fileName === 'bookshelf.json' || fileName === 'config.xml') { return false; }
    for (let index = 0; index < BackupRepository.categoryOptions.length; index++) {
      const option = BackupRepository.categoryOptions[index];
      if (option !== undefined && option.files.includes(fileName) && ignored.includes(option.key)) { return true; }
    }
    return false;
  }

  private static filterAndroidConfigXml(text: string, ignored: string[]): string {
    const excludedKeys: Set<string> = new Set<string>(BackupRepository.alwaysIgnoredPreferenceKeys);
    for (let index = 0; index < ignored.length; index++) {
      const key = ignored[index] ?? '';
      const preferenceKeys = BackupRepository.preferenceKeysForCategory(key);
      if (preferenceKeys !== undefined) {
        for (let keyIndex = 0; keyIndex < preferenceKeys.length; keyIndex++) {
          const preferenceKey = preferenceKeys[keyIndex];
          if (preferenceKey !== undefined) { excludedKeys.add(preferenceKey); }
        }
      }
    }
    const pattern = /<(string|int|long|float|boolean|set)\b[^>]*\bname=["']([^"']+)["'][^>]*(?:\/>|>[\s\S]*?<\/\1>)/gi;
    let result: string = '';
    let cursor: number = 0;
    let match: RegExpExecArray | null = pattern.exec(text);
    while (match !== null) {
      const start = match.index;
      const end = start + match[0].length;
      result += text.substring(cursor, start);
      if (!excludedKeys.has(match[2] ?? '')) { result += match[0]; }
      cursor = end;
      match = pattern.exec(text);
    }
    const filtered = result + text.substring(cursor);
    return filtered.replace(/\r?\n[ \t]*\r?\n/g, '\n');
  }


  /**
   * 解析整份 config.xml，保留标签类型。不认识的标签由正则天然跳过。
   * 正则与 filterAndroidConfigXml 同源（已支持 long / set）：
   * 自闭合标签取 value 属性文本；成对标签取开闭标签之间的原文，不 .trim()、不反转义；
   * set 标签取整段内层 XML，原样存进 value。
   */
  private static parseAndroidConfigXml(text: string): Map<string, XmlPreferenceEntry> {
    const result: Map<string, XmlPreferenceEntry> = new Map<string, XmlPreferenceEntry>();
    const pattern = /<(string|int|long|float|boolean|set)\b[^>]*\bname=["']([^"']+)["'][^>]*(?:\/>|>[\s\S]*?<\/\1>)/gi;
    let match: RegExpExecArray | null = pattern.exec(text);
    while (match !== null) {
      const tag = match[1] ?? '';
      const key = match[2] ?? '';
      const element = match[0];
      let value = '';
      if (element.indexOf('</') < 0) {
        // 自闭合：<int name="x" value="1" />
        const valueMatch = /\bvalue=["']([^"']*)["']/i.exec(element);
        value = valueMatch?.[1] ?? '';
      } else {
        // 成对：<string name="x">v</string> 或 <set name="x">内层 XML</set>
        const openEnd = element.indexOf('>');
        const closeStart = element.lastIndexOf('</');
        if (openEnd >= 0 && closeStart > openEnd) {
          value = element.substring(openEnd + 1, closeStart);
        }
      }
      const entry: XmlPreferenceEntry = { type: tag, value: value };
      result.set(key, entry);
      match = pattern.exec(text);
    }
    return result;
  }

  /**
   * 按缓存里的 XML 标签类型落标签，不走 upsertAndroidPreference（它无 long / set，还会把 & 写坏）。
   * 缩进 4 空格，与上游 Backup.kt:299-306 对齐（本地旧方法 2 空格是历史问题）。
   * 覆盖同名的任意类型标签，避免同键出现两个类型标签让上游按标签名分派时取错。
   */
  private static upsertXmlPreference(xml: string, key: string, entry: XmlPreferenceEntry): string {
    const escapedKey = key.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
    const pattern = new RegExp(
      `<(string|int|long|float|boolean|set)\\b[^>]*\\bname=["']${escapedKey}["'][^>]*(?:\\/>|>[\\s\\S]*?<\\/\\1>)`, 'i');
    let element = '';
    if (entry.type === 'string') {
      element = `<string name="${key}">${entry.value}</string>`;
    } else if (entry.type === 'set') {
      element = `<set name="${key}">${entry.value}</set>`;
    } else {
      element = `<${entry.type} name="${key}" value="${entry.value}" />`;
    }
    // 用函数回调替换，避免 value 里的 $& / $1 被当成替换模式。
    if (pattern.test(xml)) { return xml.replace(pattern, (_matched: string) => element); }
    const mapEnd = xml.indexOf('</map>');
    if (mapEnd < 0) { throw new Error('Android config.xml 缺少 map 根节点'); }
    return `${xml.substring(0, mapEnd)}    ${element}\n${xml.substring(mapEnd)}`;
  }

  /**
   * 从 preferences 读透传缓存。坏 JSON / 非字符串按「空缓存」回退（与 loadIgnoreLists 同姿态）。
   * 已知边界：全新安装、从未从 Android 恢复过的设备缓存为空，此时透传无键可带出。
   */
  private static async loadPassthrough(context: Context): Promise<Map<string, XmlPreferenceEntry>> {
    const empty: Map<string, XmlPreferenceEntry> = new Map<string, XmlPreferenceEntry>();
    try {
      const store = await preferences.getPreferences(context, BackupRepository.passthroughPreferenceName);
      const raw = await store.get(BackupRepository.passthroughCacheKey, '');
      if (typeof raw !== 'string' || raw.length === 0) { return empty; }
      const parsed = JSON.parse(raw) as Record<string, Object>;
      const keys = Object.keys(parsed);
      const result: Map<string, XmlPreferenceEntry> = new Map<string, XmlPreferenceEntry>();
      for (let index = 0; index < keys.length; index++) {
        const key = keys[index];
        const rawItem = parsed[key];
        // 逐项守卫：单个坏条目（null / 非对象）只跳过自己，不让整份缓存作废。
        if (rawItem === null || typeof rawItem !== 'object') { continue; }
        const item = rawItem as Record<string, Object>;
        const type = item['t'];
        const value = item['v'];
        if (typeof type === 'string' && typeof value === 'string') {
          const entry: XmlPreferenceEntry = { type: type, value: value };
          result.set(key, entry);
        }
      }
      return result;
    } catch (error) {
      console.error(`[BackupRepository] 读取 config.xml 透传缓存失败: ${error}`);
      return empty;
    }
  }

  /**
   * 把透传缓存写进 preferences。值是一条 JSON 字符串，形如 {"K":{"t":"int","v":"1"}}。
   * 用字符串拼接 + JSON.stringify(string) 生成（与 replaceJsonString 同款），避开 ArkTS 对
   * 「无明确 interface 类型的对象字面量」的限制。按 2000 键 / 1 MB 截断并 warn，不抛异常。
   */
  private static async savePassthrough(
    context: Context,
    value: Map<string, XmlPreferenceEntry>
  ): Promise<void> {
    const ordered: string[] = [];
    value.forEach((_entry: XmlPreferenceEntry, key: string) => { ordered.push(key); });
    let json = '{';
    let estimated = 2; // 外层大括号
    let kept = 0;
    let dropped = 0;
    for (let index = 0; index < ordered.length; index++) {
      const key = ordered[index];
      if (key === undefined) { continue; }
      const entry = value.get(key);
      if (entry === undefined) { continue; }
      if (kept >= BackupRepository.maximumPassthroughKeys) { dropped += 1; continue; }
      const fragment = `${JSON.stringify(key)}:{"t":${JSON.stringify(entry.type)},"v":${JSON.stringify(entry.value)}}`;
      // 用字符串长度近似字节数（中文按 UTF-16 高估，留足余量，不会让实际值超 16 MB 单值上限）。
      const comma = kept > 0 ? 1 : 0;
      if (estimated + comma + fragment.length > BackupRepository.maximumPassthroughBytes) {
        dropped += 1;
        continue;
      }
      if (comma > 0) { json += ','; }
      json += fragment;
      estimated += comma + fragment.length;
      kept += 1;
    }
    json += '}';
    if (dropped > 0) {
      console.warn(`[BackupRepository] config.xml 透传缓存超出上限，截断丢弃 ${dropped} 键`);
    }
    const store = await preferences.getPreferences(context, BackupRepository.passthroughPreferenceName);
    await store.put(BackupRepository.passthroughCacheKey, json);
    await store.flush();
  }

  /**
   * 备份侧：把缓存里「已知写出键集 / alwaysIgnored / ignoredCategories」之外的全部键 upsert 进 config.xml。
   * 判据与上游 BackupConfig.kt:412 keyIsNotIgnore 的 else -> true 等价；类别展开复用 preferenceKeysForCategory。
   */
  private static async applyPassthroughPreferences(
    context: Context,
    xml: string,
    ignored: string[]
  ): Promise<string> {
    const cached = await BackupRepository.loadPassthrough(context);
    if (cached.size === 0) { return xml; }
    const excludedKeys: Set<string> = new Set<string>(BackupRepository.alwaysIgnoredPreferenceKeys);
    for (let index = 0; index < ignored.length; index++) {
      const preferenceKeys = BackupRepository.preferenceKeysForCategory(ignored[index] ?? '');
      if (preferenceKeys !== undefined) {
        for (let keyIndex = 0; keyIndex < preferenceKeys.length; keyIndex++) {
          const preferenceKey = preferenceKeys[keyIndex];
          if (preferenceKey !== undefined) { excludedKeys.add(preferenceKey); }
        }
      }
    }
    let result = xml;
    cached.forEach((entry: XmlPreferenceEntry, key: string) => {
      // 本地真值键由 applyMissingPreferences（排在透传之前）写出，透传缓存旧值必须让位。
      if (!BackupRepository.writtenPreferenceKeys.has(key) &&
        !BackupRepository.missingPreferenceTypes.has(key) && !excludedKeys.has(key)) {
        result = BackupRepository.upsertXmlPreference(result, key, entry);
      }
    });
    return result;
  }

  /**
   * 恢复侧：把 config.xml 里本地不认识的键存进透传缓存。
   * 105 个已知写出键由既有恢复分支负责，进缓存只会打架；alwaysIgnored / ignoredCategories 剔除的键也不进。
   * 与旧缓存合并而不是覆盖：用户可能连续恢复两个不同来源的包。
   * 返回本次新增键数，只供日志用，不进 RestoreResult（界面不需要多一个数字）。
   */
  private static async savePassthroughFromConfigXml(
    context: Context,
    text: string,
    ignored: string[]
  ): Promise<number> {
    const parsed = BackupRepository.parseAndroidConfigXml(text);
    const excludedKeys: Set<string> = new Set<string>(BackupRepository.alwaysIgnoredPreferenceKeys);
    for (let index = 0; index < ignored.length; index++) {
      const preferenceKeys = BackupRepository.preferenceKeysForCategory(ignored[index] ?? '');
      if (preferenceKeys !== undefined) {
        for (let keyIndex = 0; keyIndex < preferenceKeys.length; keyIndex++) {
          const preferenceKey = preferenceKeys[keyIndex];
          if (preferenceKey !== undefined) { excludedKeys.add(preferenceKey); }
        }
      }
    }
    const existing = await BackupRepository.loadPassthrough(context);
    const merged: Map<string, XmlPreferenceEntry> = new Map<string, XmlPreferenceEntry>(existing);
    let added = 0;
    parsed.forEach((entry: XmlPreferenceEntry, key: string) => {
      // 本地真值键由 applyMissingPreferences（排在透传之前）写出，透传缓存旧值必须让位。
      if (!BackupRepository.writtenPreferenceKeys.has(key) &&
        !BackupRepository.missingPreferenceTypes.has(key) && !excludedKeys.has(key)) {
        if (!existing.has(key)) { added += 1; }
        merged.set(key, entry);
      }
    });
    await BackupRepository.savePassthrough(context, merged);
    return added;
  }

  /**
   * 补写本地有真值、但历史白名单从不写进 config.xml 的 97 个键，按上游 PreferKey 声明的
   * XML 标签类型落标签。用 preferences.getAll() 一次拿四个 store 的全量，判据只有
   * 「这个键在不在 missingPreferenceTypes 里」——本地自有键与 PreferKey 零撞名，天然不在表里。
   * 顺序上排在透传之前：透传缓存里可能存着同一键的旧值，本地改了设置后本地值必须赢。
   */
  private static async applyMissingPreferences(context: Context, xml: string): Promise<string> {
    const storeNames: string[] = [
      'legado_reader_settings', 'legado_theme', 'legado_bookshelf_layout', 'legado_cover_settings'
    ];
    const allValues: Map<string, Object> = new Map<string, Object>();
    for (let index = 0; index < storeNames.length; index++) {
      const store = await preferences.getPreferences(context, storeNames[index]);
      const loaded = await store.getAll();
      const record = loaded as Record<string, Object>;
      const keys = Object.keys(record);
      for (let keyIndex = 0; keyIndex < keys.length; keyIndex++) {
        const key = keys[keyIndex];
        allValues.set(key, record[key]);
      }
    }
    let result = xml;
    BackupRepository.missingPreferenceTypes.forEach((declaredType: string, key: string) => {
      const value = allValues.get(key);
      let textValue: string | undefined = undefined;
      if (typeof value === 'boolean') {
        textValue = value ? 'true' : 'false';
      } else if (typeof value === 'number') {
        // float 保留小数，int/long 取整；颜色键是字符串，不会走到这里。
        textValue = declaredType === 'float' ? String(value) : String(Math.round(value));
      } else if (typeof value === 'string') {
        // 14 个颜色键本地是 '#RRGGBB'、上游是 int，用与封面键相同的转换。
        textValue = declaredType === 'color' ? String(coverColorToAndroidInt(value)) : value;
      }
      // 值缺失或非 string/boolean/number 时跳过（本地没改过就允许不写出）。
      if (textValue !== undefined) {
        const type = declaredType === 'color' ? 'int' : declaredType;
        const entry: XmlPreferenceEntry = { type: type, value: textValue };
        result = BackupRepository.upsertXmlPreference(result, key, entry);
      }
    });
    return result;
  }

  private static mergeAndroidBookshelf(existingJson: string, importedJson: string): string {
    const existingRows = BackupRepository.splitJsonArray(existingJson);
    const importedRows = BackupRepository.splitJsonArray(importedJson);
    if (!existingJson.trim().startsWith('[') || !importedJson.trim().startsWith('[')) {
      return importedJson;
    }
    const mergedRows: string[] = [...existingRows];
    for (let importedIndex = 0; importedIndex < importedRows.length; importedIndex++) {
      const imported = importedRows[importedIndex] ?? '';
      const bookUrl = BackupRepository.readJsonString(imported, 'bookUrl') ?? '';
      let matchedIndex: number = -1;
      if (bookUrl.length > 0) {
        for (let existingIndex = 0; existingIndex < mergedRows.length; existingIndex++) {
          const existing = mergedRows[existingIndex] ?? '';
          if ((BackupRepository.readJsonString(existing, 'bookUrl') ?? '') === bookUrl) {
            matchedIndex = existingIndex;
            break;
          }
        }
      }
      if (matchedIndex < 0) {
        if (!mergedRows.includes(imported)) { mergedRows.push(imported); }
      } else {
        const current = mergedRows[matchedIndex] ?? '';
        mergedRows[matchedIndex] = BackupRepository.updateAndroidBookProgress(current, imported);
      }
    }
    return `[${mergedRows.join(',')}]`;
  }

  private static updateAndroidBookProgress(existing: string, imported: string): string {
    let result: string = existing;
    const chapterIndex = BackupRepository.readJsonNumber(imported, 'durChapterIndex');
    const characterPosition = BackupRepository.readJsonNumber(imported, 'durChapterPos');
    const chapterTitle = BackupRepository.readJsonString(imported, 'durChapterTitle');
    if (chapterIndex !== undefined) {
      result = BackupRepository.replaceJsonNumber(result, 'durChapterIndex', chapterIndex);
    }
    if (characterPosition !== undefined) {
      result = BackupRepository.replaceJsonNumber(result, 'durChapterPos', characterPosition);
    }
    if (chapterTitle !== undefined) {
      result = BackupRepository.replaceJsonString(result, 'durChapterTitle', chapterTitle);
    }
    return result;
  }

  private static replaceJsonNumber(json: string, field: string, value: number): string {
    const key = field.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
    const pattern = new RegExp(`("${key}"\\s*:\\s*)-?(?:0|[1-9]\\d*)(?:\\.\\d+)?`);
    return json.replace(pattern, `$1${Math.trunc(value)}`);
  }

  private static replaceJsonString(json: string, field: string, value: string): string {
    const key = field.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
    const pattern = new RegExp(`("${key}"\\s*:\\s*)"(?:\\\\.|[^"\\\\])*"`);
    return json.replace(pattern, (_matched: string, prefix: string) => `${prefix}${JSON.stringify(value)}`);
  }

  private static splitJsonArray(text: string): string[] {
    const trimmed = text.trim();
    if (!trimmed.startsWith('[')) { return []; }
    const rows: string[] = [];
    let index: number = 1;
    while (index < trimmed.length) {
      while (index < trimmed.length && (trimmed[index] === ' ' || trimmed[index] === '\n' ||
        trimmed[index] === '\r' || trimmed[index] === '\t' || trimmed[index] === ',')) { index += 1; }
      if (trimmed[index] === ']' || index >= trimmed.length) { break; }
      const start = index;
      let objectDepth: number = 0;
      let arrayDepth: number = 0;
      let inString: boolean = false;
      let escaped: boolean = false;
      while (index < trimmed.length) {
        const character = trimmed[index] ?? '';
        if (inString) {
          if (escaped) { escaped = false; }
          else if (character === '\\') { escaped = true; }
          else if (character === '"') { inString = false; }
        } else if (character === '"') { inString = true; }
        else if (character === '{') { objectDepth += 1; }
        else if (character === '}') { objectDepth -= 1; }
        else if (character === '[') { arrayDepth += 1; }
        else if (character === ']') {
          if (arrayDepth === 0 && objectDepth === 0) { break; }
          arrayDepth -= 1;
        } else if (character === ',' && objectDepth === 0 && arrayDepth === 0) { break; }
        index += 1;
      }
      const row = trimmed.substring(start, index).trim();
      if (row.length > 0) { rows.push(row); }
      if (trimmed[index] === ',') { index += 1; }
      else if (trimmed[index] === ']') { break; }
    }
    return rows;
  }

  private static countJsonRecords(text: string): number {
    return text.trim().startsWith('[') ? BackupRepository.splitJsonArray(text).length : -1;
  }

  private static countXmlEntries(text: string): number {
    const matches = text.match(/<(?:string|int|long|float|boolean)\b/g);
    return matches === null ? 0 : matches.length;
  }

  private static readJsonString(json: string, field: string): string | undefined {
    const expression = new RegExp(`"${field}"\\s*:\\s*("(?:\\\\.|[^"\\\\])*")`);
    const match = expression.exec(json);
    const token = match?.[1];
    if (token === undefined) { return undefined; }
    const parsed = BackupRepository.decodeJsonStringToken(token);
    return parsed;
  }

  private static readJsonNumber(json: string, field: string): number | undefined {
    const expression = new RegExp(`"${field}"\\s*:\\s*(-?(?:0|[1-9]\\d*)(?:\\.\\d+)?(?:[eE][+-]?\\d+)?)`);
    const value = expression.exec(json)?.[1];
    if (value === undefined) { return undefined; }
    const number = Number(value);
    return Number.isFinite(number) ? number : undefined;
  }

  private static readJsonBoolean(json: string, field: string): boolean | undefined {
    const value = new RegExp(`"${field}"\\s*:\\s*(true|false)`).exec(json)?.[1];
    if (value === 'true') { return true; }
    if (value === 'false') { return false; }
    return undefined;
  }

  private static decodeJsonStringToken(token: string): string {
    let result: string = '';
    for (let index = 1; index < token.length - 1; index++) {
      const character = token[index] ?? '';
      if (character !== '\\') { result += character; continue; }
      index += 1;
      const escaped = token[index] ?? '';
      if (escaped === '"' || escaped === '\\' || escaped === '/') { result += escaped; }
      else if (escaped === 'b') { result += '\b'; }
      else if (escaped === 'f') { result += '\f'; }
      else if (escaped === 'n') { result += '\n'; }
      else if (escaped === 'r') { result += '\r'; }
      else if (escaped === 't') { result += '\t'; }
      else if (escaped === 'u') {
        const code = Number.parseInt(token.substring(index + 1, index + 5), 16);
        if (Number.isInteger(code)) { result += String.fromCharCode(code); }
        index += 4;
      }
    }
    return result;
  }

  private static readXmlInteger(path: string, key: string): number | undefined {
    if (!fileIo.accessSync(path)) { return undefined; }
    const text = fileIo.readTextSync(path);
    const name = key.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
    const valueMatch = new RegExp(`<int\\b[^>]*name=["']${name}["'][^>]*value=["'](-?\\d+)["']` , 'i').exec(text)?.[1];
    if (valueMatch === undefined) { return undefined; }
    const value = Number(valueMatch);
    return Number.isInteger(value) ? value : undefined;
  }

  private static readXmlFloat(path: string, key: string): number | undefined {
    if (!fileIo.accessSync(path)) { return undefined; }
    const text = fileIo.readTextSync(path);
    const name = key.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
    const valueMatch = new RegExp(`<float\\b[^>]*name=["']${name}["'][^>]*value=["'](-?(?:\\d+\\.?\\d*|\\.\\d+)(?:[eE][+-]?\\d+)?)["']`, 'i')
      .exec(text)?.[1];
    if (valueMatch === undefined) { return undefined; }
    const value = Number(valueMatch);
    return Number.isFinite(value) ? value : undefined;
  }

  private static upsertAndroidPreference(
    xml: string,
    type: 'boolean' | 'int' | 'float' | 'string' | 'long',
    key: string,
    value: string
  ): string {
    const escapedKey = key.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
    const pattern = type === 'string'
      ? new RegExp(`<string\\b[^>]*name=["']${escapedKey}["'][^>]*>[\\s\\S]*?</string>`, 'i')
      : new RegExp(`<${type}\\b[^>]*name=["']${escapedKey}["'][^>]*value=["'][^"']*["'][^>]*/>`, 'i');
    const element = type === 'string'
      ? `<string name="${key}">${value}</string>`
      : `<${type} name="${key}" value="${value}" />`;
    if (pattern.test(xml)) { return xml.replace(pattern, element); }
    const mapEnd = xml.indexOf('</map>');
    if (mapEnd < 0) { throw new Error('Android config.xml 缺少 map 根节点'); }
    return `${xml.substring(0, mapEnd)}  ${element}\n${xml.substring(mapEnd)}`;
  }

  private static readXmlBoolean(path: string, key: string): boolean | undefined {
    if (!fileIo.accessSync(path)) { return undefined; }
    const text = fileIo.readTextSync(path);
    const name = key.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
    const valueMatch = new RegExp(`<boolean\\b[^>]*name=["']${name}["'][^>]*value=["'](true|false)["']`, 'i')
      .exec(text)?.[1];
    if (valueMatch === undefined) { return undefined; }
    return valueMatch.toLowerCase() === 'true';
  }

  /**
   * 读回 <long name="K" value="V" /> 的原始文本，不做数值转换（本地 saveTabPosition 是 string）。
   * 存量备份里若仍是旧的 <string> 标签，这里读不到，值保持本地当前值——重新备份后才有 long。
   */
  private static readXmlLong(path: string, key: string): string | undefined {
    if (!fileIo.accessSync(path)) { return undefined; }
    const text = fileIo.readTextSync(path);
    const name = key.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
    const valueMatch = new RegExp(`<long\\b[^>]*name=["']${name}["'][^>]*value=["']([^"']*)["']`, 'i')
      .exec(text)?.[1];
    return valueMatch;
  }

  private static readXmlString(path: string, key: string): string | undefined {
    if (!fileIo.accessSync(path)) { return undefined; }
    const text = fileIo.readTextSync(path);
    const name = key.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
    const valueMatch = new RegExp(`<string\\b[^>]*name=["']${name}["'][^>]*>([\\s\\S]*?)</string>`, 'i')
      .exec(text)?.[1];
    return valueMatch?.trim();
  }

  /**
   * 从 Android 备份的 `bgType`/`bgStr` 反查本机样式下标。
   * 先在本机现有样式表里按日间色找（用户自建样式可能就是从别的设备导进来的，颜色能对上就直接复用）；
   * 找不到再回落到内置预设的固定颜色别名。
   */
  private static paperIndexFromAndroidConfig(type: number, background: string,
    styles: ReaderBackgroundStyle[]): number {
    if (type !== 0) { return 0; }
    const value = background.toLowerCase();
    const lastIndex = Math.max(0, styles.length - 1);
    const styleIndex = styles.findIndex((style) => style.dayColor.toLowerCase() === value);
    if (styleIndex >= 0) { return Math.max(0, Math.min(lastIndex, styleIndex)); }
    if (value === '#000000' || value === '#000' || value === 'black') { return 0; }
    if (value === '#e5eade' || value === '#e5eafd') { return Math.max(0, Math.min(lastIndex, 3)); }
    if (value === '#f3efe4' || value === '#f2eee2') { return Math.max(0, Math.min(lastIndex, 1)); }
    return 0;
  }

  private static ensureDirectory(path: string): void {
    try { fileIo.mkdirSync(path, true); }
    catch (error) {
      try { if (fileIo.lstatSync(path).isDirectory()) { return; } } catch (probeError) { console.error(`[BackupRepository] 检查目录是否已存在失败: ${probeError}`); }
      if (error instanceof Error) { throw error; }
      throw new Error('无法创建 Android 备份临时目录');
    }
  }

  private static writeTextFile(path: string, content: string): void {
    const file = fileIo.openSync(path,
      fileIo.OpenMode.WRITE_ONLY | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC);
    try {
      const written = fileIo.writeSync(file.fd, content);
      if (written <= 0 && content.length > 0) { throw new Error('备份条目写入失败'); }
    } finally {
      fileIo.closeSync(file);
    }
  }

  /**
   * 解析上游 highlightRule.json。
   * 上游写的就是一个 JSON 数组；容忍单个对象与带 rules 包装两种变体，
   * 其余形态按全部跳过处理，不抛异常——恢复流程里一条坏文件不该中断整包导入。
   */
  private static parseHighlightRules(text: string): HighlightRuleParseOutcome {
    const rules: ReaderHighlightRule[] = [];
    let skipped = 0;
    let parsed: Object;
    try {
      parsed = JSON.parse(text) as Object;
    } catch (error) {
      console.error(`[BackupRepository] 解析高亮规则失败: ${error}`);
      return { rules: rules, skipped: skipped };
    }
    let candidates: Object[] = [];
    if (Array.isArray(parsed)) {
      candidates = parsed as Object[];
    } else if (parsed !== null && typeof parsed === 'object') {
      const wrapped = (parsed as Record<string, Object>)['rules'];
      candidates = Array.isArray(wrapped) ? wrapped as Object[] : [parsed];
    }
    candidates.forEach((candidate: Object) => {
      if (candidate === null || typeof candidate !== 'object') {
        skipped += 1;
        return;
      }
      const rule = BackupRepository.toHighlightRule(candidate as Record<string, Object>);
      if (rule === undefined) {
        skipped += 1;
        return;
      }
      rules.push(rule);
    });
    return { rules: rules, skipped: skipped };
  }

  /**
   * 把一条 JSON 记录按上游字段名转成 ReaderHighlightRule。
   * 只用字段名对应取值，不整体强转，缺字段留空由仓储的 normalize 补默认值。
   * pattern 为空的条目返回 undefined，由调用方计入跳过。
   */
  private static toHighlightRule(record: Record<string, Object>): ReaderHighlightRule | undefined {
    const pattern = record['pattern'];
    if (typeof pattern !== 'string' || pattern.trim().length === 0) { return undefined; }
    const rule: ReaderHighlightRule = {
      id: BackupRepository.readString(record, 'id'),
      name: BackupRepository.readString(record, 'name'),
      pattern: pattern,
      sampleText: BackupRepository.readString(record, 'sampleText'),
      targetScope: BackupRepository.readNumber(record, 'targetScope', 0),
      enabled: BackupRepository.readBoolean(record, 'enabled', true),
      position: BackupRepository.readNumber(record, 'position', 0),
      textColor: BackupRepository.readNullableNumber(record, 'textColor'),
      bgColor: BackupRepository.readNullableNumber(record, 'bgColor'),
      underlineMode: BackupRepository.readNumber(record, 'underlineMode', 0),
      underlineColor: BackupRepository.readNullableNumber(record, 'underlineColor'),
      underlineWidth: BackupRepository.readNumber(record, 'underlineWidth', 1),
      underlineOffset: BackupRepository.readNumber(record, 'underlineOffset', 2),
      underlineSvgPath: BackupRepository.readNullableString(record, 'underlineSvgPath'),
      bgImage: BackupRepository.readNullableString(record, 'bgImage'),
      bgImageFit: BackupRepository.readNumber(record, 'bgImageFit', 0),
      bgImageScale: BackupRepository.readNumber(record, 'bgImageScale', 1),
      configName: BackupRepository.readNullableString(record, 'configName'),
      fontPath: BackupRepository.readNullableString(record, 'fontPath'),
      fontWeight: BackupRepository.readNumber(record, 'fontWeight', 400),
      isItalic: BackupRepository.readBoolean(record, 'isItalic', false),
      fontSizeOffset: BackupRepository.readNumber(record, 'fontSizeOffset', 0),
      npLeft: BackupRepository.readNumber(record, 'npLeft', 0.1),
      npRight: BackupRepository.readNumber(record, 'npRight', 0.1),
      npTop: BackupRepository.readNumber(record, 'npTop', 0.1),
      npBottom: BackupRepository.readNumber(record, 'npBottom', 0.1),
      manualNineSlice: BackupRepository.readBoolean(record, 'manualNineSlice', true),
      letterSpacingBefore: BackupRepository.readNumber(record, 'letterSpacingBefore', 0),
      letterSpacingAfter: BackupRepository.readNumber(record, 'letterSpacingAfter', 0),
      lineSpacingTop: BackupRepository.readNumber(record, 'lineSpacingTop', 0),
      lineSpacingBottom: BackupRepository.readNumber(record, 'lineSpacingBottom', 0),
      bgLengthOffsetLeft: BackupRepository.readNumber(record, 'bgLengthOffsetLeft', 0),
      bgLengthOffsetRight: BackupRepository.readNumber(record, 'bgLengthOffsetRight', 0)
    };
    return rule;
  }

  private static readString(record: Record<string, Object>, key: string): string {
    const value = record[key];
    return typeof value === 'string' ? value : '';
  }

  private static readNullableString(record: Record<string, Object>, key: string): string | null {
    const value = record[key];
    return typeof value === 'string' ? value : null;
  }

  private static readNumber(record: Record<string, Object>, key: string, fallback: number): number {
    const value = record[key];
    return typeof value === 'number' && Number.isFinite(value) ? value : fallback;
  }

  private static readNullableNumber(record: Record<string, Object>, key: string): number | null {
    const value = record[key];
    return typeof value === 'number' && Number.isFinite(value) ? value : null;
  }

  private static readBoolean(record: Record<string, Object>, key: string, fallback: boolean): boolean {
    const value = record[key];
    return typeof value === 'boolean' ? value : fallback;
  }

  private static isSafeRootEntry(name: string): boolean {
    return name.length > 0 && name !== '.' && name !== '..' && !name.includes('/') &&
      !name.includes('\\') && !name.includes('\u0000') &&
      (name.endsWith('.json') || name.endsWith('.xml'));
  }

  private static parseIgnoreList(value: string): string[] {
    const options = BackupRepository.categoryOptions.map((item: BackupCategoryOption) => item.key);
    return value.split('\n').filter((item: string) => options.includes(item));
  }

  static currentDate(): string {
    const date = new Date();
    const month = (date.getMonth() + 1).toString().padStart(2, '0');
    const day = date.getDate().toString().padStart(2, '0');
    return `${date.getFullYear()}-${month}-${day}`;
  }
}
