import { fileIo, picker } from '@kit.CoreFileKit';
import { preferences } from '@kit.ArkData';
import zlib from '@ohos.zlib';
import { Book } from '../model/Book';
import { EpubRepository } from './EpubRepository';
import { BookRepository } from './BookRepository';
import { BookGroupRepository } from './BookGroupRepository';
import { BookshelfLayoutRepository } from './BookshelfLayoutRepository';
import { BookshelfLayoutSettings, copyBookshelfLayout } from '../model/BookshelfLayout';
import { READER_BACKGROUND_STYLES, ReaderSettingsRepository, ReaderSettingsSnapshot } from './ReaderSettingsRepository';
import { ReplaceRuleRepository } from './ReplaceRuleRepository';
import { ReplaceRuleImporter } from './ReplaceRuleImporter';
import { TxtTocRuleRepository } from './TxtTocRuleRepository';
import { TxtTocRuleImporter } from './TxtTocRuleImporter';

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

export interface RestoreResult {
  books: Book[];
  settings: ReaderSettingsSnapshot;
  bookshelfLayout: BookshelfLayoutSettings;
  preservedEntryCount: number;
  updatedLocalBookCount: number;
  createdMissingBodyBookCount: number;
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
}

interface JsonStringResult {
  value: string;
  end: number;
}

interface RestoredBookProgress {
  books: Book[];
  updatedCount: number;
  createdMissingBodyCount: number;
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
  private static readonly preferenceKeysByCategory: AndroidPreferenceKeyGroups = {
    readConfig: [
      'readStyleSelect', 'comicStyleSelect', 'shareLayout', 'hideStatusBar', 'hideNavigationBar', 'readingAnchorEnabled', 'swipeToAddBookmark', 'maxLengthWithNoToc',
      'autoReadSpeed', 'progressBarBehavior', 'tocUiUseReplace', 'tocCountWords', 'clickImgWay',
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
      'bookInfoBackgroundBlur', 'bookInfoNetworkCoverBackground', 'bookInfoDefaultCoverBackground',
      'colorBackground', 'colorBottomBackground', 'colorBackgroundNight', 'colorBottomBackgroundNight',
      'enableDeepPersonalization', 'colorMD3OnSurface', 'colorMD3OnPrimaryContainer', 'colorMD3Background',
      'colorMD3SurfaceContainerLow', 'colorMD3OnSurfaceNight', 'colorMD3OnPrimaryContainerNight',
      'colorMD3BackgroundNight', 'colorMD3SurfaceContainerLowNight', 'eyeProtectionEnabled',
      'colorTemperature', 'eyeProtectionAutoNight', 'eyeProtectionSchedule', 'eyeProtectionStartTime',
      'eyeProtectionEndTime'
    ],
    bookshelfLayout: [
      'bookGroupStyle', 'hideEmptyGroups',
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
      'bookshelfShowLatestChapter', 'bookshelfIntroMaxLines'
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
    { key: 'themeMode', title: '主题模式', files: ['config.xml'], preferenceKeys: BackupRepository.preferenceKeysByCategory.themeMode },
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
    } catch (_) {
    }
    const directory = `${context.filesDir}/${BackupRepository.legacyDirectoryName}`;
    let names: string[] = [];
    try { names = fileIo.listFileSync(directory); } catch (_) { return []; }
    const entries: BackupEntryPreview[] = [];
    for (let index = 0; index < names.length; index++) {
      const name = names[index];
      if (name === undefined || !BackupRepository.isSafeRootEntry(name)) { continue; }
      try {
        const path = `${directory}/${name}`;
        if (fileIo.lstatSync(path).isFile()) {
          entries.push({ name: name, recordCount: -1, byteSize: fileIo.statSync(path).size });
        }
      } catch (_) {
      }
    }
    return entries;
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
    } catch (_) {
      return defaults;
    }
  }

  static async saveIgnoreLists(context: Context, value: BackupIgnoreLists): Promise<void> {
    const store = await preferences.getPreferences(context, BackupRepository.preferenceName);
    await store.put('backupIgnore', value.backup.join('\n'));
    await store.put('restoreIgnore', value.restore.join('\n'));
    await store.flush();
  }

  static async createBackup(
    context: Context,
    books: Book[],
    settings: ReaderSettingsSnapshot,
    bookshelfLayout: BookshelfLayoutSettings,
    ignoredCategories: string[]
  ): Promise<boolean> {
    const stagingDirectory = `${context.cacheDir}/legado-android-backup-${Date.now()}`;
    const zipPath = `${context.cacheDir}/legado-android-backup-${Date.now()}.zip`;
    BackupRepository.ensureDirectory(stagingDirectory);
    try {
      await BookGroupRepository.load(context);
      await BackupRepository.copyPreservedEntries(context, stagingDirectory, ignoredCategories);
      if (!ignoredCategories.includes('localBook')) {
        const localBooks = books.filter((book: Book) => BookRepository.isPersistableBook(book));
        if (localBooks.length > 0) {
          const records = localBooks.map((book: Book, index: number) =>
            BackupRepository.toAndroidBookRecord(book, index));
          const generated = JSON.stringify(records);
          const oldPath = `${stagingDirectory}/bookshelf.json`;
          const combined = fileIo.accessSync(oldPath)
            ? BackupRepository.mergeAndroidBookshelf(fileIo.readTextSync(oldPath), generated)
            : generated;
          BackupRepository.writeTextFile(oldPath, combined);
        }
      }

      if (!ignoredCategories.includes('bookGroup')) {
        BackupRepository.writeTextFile(`${stagingDirectory}/bookGroup.json`, BookGroupRepository.exportAndroidGroups());
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

      const configPath = `${stagingDirectory}/config.xml`;
      if (!fileIo.accessSync(configPath)) {
        // config.xml 骨架必须总是写出（后面的书架布局与主题配置要往同一文件 upsert），
        // 但阅读配置键受 readConfig 门控：排除阅读配置时不应写入这些键。
        // 此前这里无条件写入，导致「排除阅读配置」在归档目录没有 config.xml 时完全失效。
        let baseXml = `<?xml version='1.0' encoding='utf-8' standalone='yes' ?>\n<map>\n`;
        if (!ignoredCategories.includes('readConfig')) {
          baseXml +=
          `  <int name="readStyleSelect" value="0" />\n` +
          `  <boolean name="shareLayout" value="${settings.shareLayout}" />\n` +
          `  <boolean name="hideStatusBar" value="${settings.hideStatusBar}" />\n` +
          `  <boolean name="hideNavigationBar" value="${settings.hideNavigationBar}" />\n` +
          `  <boolean name="readingAnchorEnabled" value="${settings.readingAnchorEnabled}" />\n` +
          `  <boolean name="swipeToAddBookmark" value="${settings.swipeToAddBookmark}" />\n` +
          `  <int name="maxLengthWithNoToc" value="${settings.maxLengthWithNoToc}" />\n` +
          `  <boolean name="readMenuIconShowText" value="${settings.showBottomActionText}" />\n` +
          `  <int name="readMenuIconStyle" value="${settings.bottomIconStyle}" />\n` +
          `  <int name="readMenuIconItemsPerRow" value="${settings.bottomItemsPerRow}" />\n` +
          `  <int name="readMenuIconRowCount" value="${settings.bottomRowCount}" />\n` +
          `  <string name="progressBarBehavior">${settings.progressBehavior}</string>\n` +
          `  <boolean name="tocUiUseReplace" value="${settings.tocUseReplace}" />\n` +
          `  <boolean name="tocCountWords" value="${settings.tocShowWordCount}" />\n` +
          `  <string name="clickImgWay">${settings.clickImageBehavior}</string>\n` +
          `  <int name="clickActionTopLeft" value="${BackupRepository.androidClickActionValue(settings.clickRegionActions[0] ?? '')}" />\n` +
          `  <int name="clickActionTopCenter" value="${BackupRepository.androidClickActionValue(settings.clickRegionActions[1] ?? '')}" />\n` +
          `  <int name="clickActionTopRight" value="${BackupRepository.androidClickActionValue(settings.clickRegionActions[2] ?? '')}" />\n` +
          `  <int name="clickActionMiddleLeft" value="${BackupRepository.androidClickActionValue(settings.clickRegionActions[3] ?? '')}" />\n` +
          `  <int name="clickActionMiddleCenter" value="${BackupRepository.androidClickActionValue(settings.clickRegionActions[4] ?? '')}" />\n` +
          `  <int name="clickActionMiddleRight" value="${BackupRepository.androidClickActionValue(settings.clickRegionActions[5] ?? '')}" />\n` +
          `  <int name="clickActionBottomLeft" value="${BackupRepository.androidClickActionValue(settings.clickRegionActions[6] ?? '')}" />\n` +
          `  <int name="clickActionBottomCenter" value="${BackupRepository.androidClickActionValue(settings.clickRegionActions[7] ?? '')}" />\n` +
          `  <int name="clickActionBottomRight" value="${BackupRepository.androidClickActionValue(settings.clickRegionActions[8] ?? '')}" />\n`;
        }
        baseXml += `</map>`;
        BackupRepository.writeTextFile(configPath, baseXml);
      }

      if (!ignoredCategories.includes('bookshelfLayout')) {
        let configText = fileIo.readTextSync(configPath);
        configText = BackupRepository.upsertAndroidPreference(configText, 'int', 'bookGroupStyle', `${bookshelfLayout.bookGroupStyle}`);
        configText = BackupRepository.upsertAndroidPreference(configText, 'boolean', 'hideEmptyGroups', `${bookshelfLayout.hideEmptyGroups}`);
        configText = BackupRepository.upsertAndroidPreference(configText, 'int', 'bookshelfSort', `${bookshelfLayout.bookshelfSort}`);
        configText = BackupRepository.upsertAndroidPreference(configText, 'int', 'bookshelfSortOrder', `${bookshelfLayout.bookshelfSortOrder}`);
        configText = BackupRepository.upsertAndroidPreference(configText, 'int', 'bookshelfLayoutPortrait', `${bookshelfLayout.bookshelfLayoutModePortrait}`);
        configText = BackupRepository.upsertAndroidPreference(configText, 'int', 'bookshelfLayoutGridPortrait', `${bookshelfLayout.bookshelfLayoutGridPortrait}`);
        configText = BackupRepository.upsertAndroidPreference(configText, 'int', 'bookshelfLayoutListPortrait', `${bookshelfLayout.bookshelfLayoutListPortrait}`);
        configText = BackupRepository.upsertAndroidPreference(configText, 'int', 'bookshelfTitleMaxLines', `${bookshelfLayout.bookshelfTitleMaxLines}`);
        configText = BackupRepository.upsertAndroidPreference(configText, 'boolean', 'bookshelfCoverShadow', `${bookshelfLayout.bookshelfCoverShadow}`);
        BackupRepository.writeTextFile(configPath, configText);
      }
      // 护眼六键在 preferenceKeysByCategory 里归 themeConfig，写入门控必须与分类归属保持一致：
      // 否则「排除主题配置」对护眼设置不生效，「排除阅读配置」反而会连带丢掉护眼设置。
      if (!ignoredCategories.includes('themeConfig')) {
        let configText = fileIo.readTextSync(configPath);
        configText = BackupRepository.upsertAndroidPreference(
          configText, 'boolean', 'eyeProtectionEnabled', `${settings.eyeProtectionEnabled}`);
        configText = BackupRepository.upsertAndroidPreference(
          configText, 'boolean', 'eyeProtectionAutoNight', `${settings.eyeProtectionAutoNight}`);
        configText = BackupRepository.upsertAndroidPreference(
          configText, 'boolean', 'eyeProtectionSchedule', `${settings.eyeProtectionSchedule}`);
        configText = BackupRepository.upsertAndroidPreference(
          configText, 'int', 'colorTemperature', `${Math.max(0, Math.min(100, Math.round(settings.eyeProtectionIntensity)))}`);
        configText = BackupRepository.upsertAndroidPreference(
          configText, 'string', 'eyeProtectionStartTime', settings.eyeProtectionStartTime);
        configText = BackupRepository.upsertAndroidPreference(
          configText, 'string', 'eyeProtectionEndTime', settings.eyeProtectionEndTime);
        BackupRepository.writeTextFile(configPath, configText);
      }
      const files = fileIo.listFileSync(stagingDirectory)
        .filter((name: string) => BackupRepository.isSafeRootEntry(name))
        .map((name: string) => `${stagingDirectory}/${name}`);
      if (files.length === 0 || files.length > BackupRepository.maximumArchiveEntries) {
        throw new Error('Android 兼容备份没有可写入条目或条目数量过多');
      }
      await zlib.compressFiles(files, zipPath, {});

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
      await EpubRepository.removeBackupWorkDirectory(stagingDirectory);
      try { fileIo.unlinkSync(zipPath); } catch (_) { }
    }
  }

  static async selectBackup(context: Context, currentBooks: Book[]): Promise<BackupSelection | undefined> {
    const options = new picker.DocumentSelectOptions();
    options.fileSuffixFilters = ['Legado Android 备份|.zip'];
    options.maxSelectNumber = 1;
    const uris = await new picker.DocumentViewPicker(context).select(options);
    const uri = uris[0];
    if (uri === undefined) { return undefined; }

    const stagingDirectory = `${context.cacheDir}/legado-android-restore-${Date.now()}`;
    const zipPath = `${context.cacheDir}/legado-android-restore-${Date.now()}.zip`;
    BackupRepository.ensureDirectory(stagingDirectory);
    try {
      const source = fileIo.openSync(uri, fileIo.OpenMode.READ_ONLY);
      try {
        const compressedSize = fileIo.statSync(source.fd).size;
        if (compressedSize <= 0 || compressedSize > BackupRepository.maximumCompressedBytes) {
          throw new Error('ZIP 备份为空或超过 64 MB');
        }
        fileIo.copyFileSync(source.fd, zipPath);
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
    } finally {
      try { fileIo.unlinkSync(zipPath); } catch (_) { }
    }
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
      await fileIo.copyFile(sourcePath, targetPath);
      preservedEntryCount += 1;
    }

    const settings = BackupRepository.applyEyeProtection(
      selection.stagingDirectory,
      BackupRepository.restoreReaderSettings(
        selection.stagingDirectory,
        currentSettings,
        ignoredCategories
      ),
      ignoredCategories
    );
    await ReaderSettingsRepository.save(context, settings);
    const bookshelfLayout = BackupRepository.restoreBookshelfLayout(
      selection.stagingDirectory, currentBookshelfLayout, ignoredCategories
    );
    await BookshelfLayoutRepository.save(context, bookshelfLayout);
    const updated = BackupRepository.restoreMatchingLocalProgress(
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
      preservedEntryCount: preservedEntryCount,
      updatedLocalBookCount: updated.updatedCount,
      createdMissingBodyBookCount: updated.createdMissingBodyCount,
      localBooksWithoutBody: selection.preview.localBooksWithoutBody,
      restoredEntries: restoredEntries,
      replaceRuleAdded: replaceRuleAdded,
      replaceRuleUpdated: replaceRuleUpdated,
      replaceRuleSkipped: replaceRuleSkipped,
      txtTocRuleAdded: txtTocRuleAdded,
      txtTocRuleUpdated: txtTocRuleUpdated,
      txtTocRuleSkipped: txtTocRuleSkipped
    };
  }

  static async discardSelection(selection: BackupSelection): Promise<void> {
    await EpubRepository.removeBackupWorkDirectory(selection.stagingDirectory);
  }

  private static toAndroidBookRecord(book: Book, order: number): AndroidBookBackupRecord {
    const chapterTitles = book.chapterTitles ?? [];
    const chapterCount = Number(book.chapterCount ?? '0');
    const chapterIndex = book.bodyMissing === true
      ? Math.max(0, book.chapterIndex ?? 0)
      : Math.max(0, Math.min(Math.max(0, chapterTitles.length - 1), book.chapterIndex ?? 0));
    const totalChapterCount = book.bodyMissing === true && Number.isInteger(chapterCount) && chapterCount > 0
      ? chapterCount : chapterTitles.length;
    const androidBookUrl = book.androidOriginalPath ?? book.contentPath ?? '';
    return {
      bookUrl: androidBookUrl,
      tocUrl: androidBookUrl,
      origin: 'loc_book',
      originName: book.title,
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
      type: 264,
      group: BookGroupRepository.maskFromNames(book.groupNames ?? []),
      isPrivate: false,
      latestChapterTitle: book.lastChapter,
      latestChapterTime: book.latestChapterTime ?? 0,
      lastCheckTime: 0,
      lastCheckCount: 0,
      totalChapterNum: totalChapterCount,
      durChapterTitle: book.lastChapter,
      durChapterIndex: chapterIndex,
      durChapterPos: book.contentPath !== undefined
        ? BookRepository.estimateAndroidChapterPosition(book) : book.androidCharacterPosition ?? 0,
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
    const dayStyle = READER_BACKGROUND_STYLES[Math.max(0, Math.min(5, settings.dayPaperIndex))] ??
      READER_BACKGROUND_STYLES[Math.max(0, Math.min(5, settings.paperIndex))] ??
      READER_BACKGROUND_STYLES[0];
    const nightStyle = READER_BACKGROUND_STYLES[Math.max(0, Math.min(5, settings.nightPaperIndex))] ?? dayStyle;
    return {
      name: dayStyle.name,
      textSize: Math.max(15, Math.min(30, Math.round(settings.fontSize))),
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
      bgType: 0,
      bgStr: dayStyle.dayColor,
      bgTypeNight: 0,
      bgStrNight: nightStyle.nightColor
    };
  }

  private static restoreBookshelfLayout(
    directory: string,
    current: BookshelfLayoutSettings,
    ignoredCategories: string[]
  ): BookshelfLayoutSettings {
    if (ignoredCategories.includes('bookshelfLayout')) { return copyBookshelfLayout(current); }
    const values = new Map<string, string>();
    const integerKeys = [
      'bookGroupStyle', 'bookshelfSort', 'bookshelfSortOrder', 'bookshelfLayoutPortrait',
      'bookshelfLayoutGridPortrait', 'bookshelfLayoutListPortrait', 'bookshelfTitleMaxLines'
    ];
    for (let index = 0; index < integerKeys.length; index++) {
      const key = integerKeys[index];
      if (key === undefined) { continue; }
      const value = BackupRepository.readXmlInteger(`${directory}/config.xml`, key);
      if (value !== undefined) { values.set(key, value.toString()); }
    }
    const booleanKeys = ['hideEmptyGroups', 'bookshelfCoverShadow'];
    for (let index = 0; index < booleanKeys.length; index++) {
      const key = booleanKeys[index];
      if (key === undefined) { continue; }
      const value = BackupRepository.readXmlBoolean(`${directory}/config.xml`, key);
      if (value !== undefined) { values.set(key, value.toString()); }
    }
    return BookshelfLayoutRepository.mergeFromAndroidValues(current, values);
  }

  // 护眼六键独立于阅读配置恢复：它们归 themeConfig 分类，
  // 只有「排除主题配置」才跳过，且不受 restoreReaderSettings 的 readConfig 早退影响。
  private static applyEyeProtection(
    directory: string,
    settings: ReaderSettingsSnapshot,
    ignoredCategories: string[]
  ): ReaderSettingsSnapshot {
    if (ignoredCategories.includes('themeConfig')) { return settings; }
    const configPath = `${directory}/config.xml`;
    const enabled = BackupRepository.readXmlBoolean(configPath, 'eyeProtectionEnabled');
    if (enabled !== undefined) { settings.eyeProtectionEnabled = enabled; }
    const autoNight = BackupRepository.readXmlBoolean(configPath, 'eyeProtectionAutoNight');
    if (autoNight !== undefined) { settings.eyeProtectionAutoNight = autoNight; }
    const schedule = BackupRepository.readXmlBoolean(configPath, 'eyeProtectionSchedule');
    if (schedule !== undefined) { settings.eyeProtectionSchedule = schedule; }
    const intensity = BackupRepository.readXmlInteger(configPath, 'colorTemperature');
    if (intensity !== undefined) {
      settings.eyeProtectionIntensity = Math.max(0, Math.min(100, intensity));
    }
    const startTime = BackupRepository.readXmlString(configPath, 'eyeProtectionStartTime');
    if (startTime !== undefined) { settings.eyeProtectionStartTime = startTime; }
    const endTime = BackupRepository.readXmlString(configPath, 'eyeProtectionEndTime');
    if (endTime !== undefined) { settings.eyeProtectionEndTime = endTime; }
    return settings;
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
      BackupRepository.readJsonString(selected, 'bgStr') ?? ''
    );
    const nightPaperIndex = BackupRepository.paperIndexFromAndroidConfig(
      BackupRepository.readJsonNumber(selected, 'bgTypeNight') ?? 0,
      BackupRepository.readJsonString(selected, 'bgStrNight') ?? ''
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
      paperIndex: paperIndex,
      dayPaperIndex: dayPaperIndex,
      nightPaperIndex: nightPaperIndex,
      readerNightMode: current.readerNightMode,
      shareLayout: shareLayout,
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
      // 护眼六键属于 themeConfig 分类，由 applyEyeProtection() 独立恢复：
      // 这里只透传当前值，避免被 readConfig 的早退挡住或被重复读取覆盖。
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
      selectText: current.selectText,
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

  private static restoreMatchingLocalProgress(
    directory: string,
    currentBooks: Book[],
    ignoredCategories: string[]
  ): RestoredBookProgress {
    if (ignoredCategories.includes('localBook')) {
      return { books: currentBooks, updatedCount: 0, createdMissingBodyCount: 0 };
    }
    const path = `${directory}/bookshelf.json`;
    if (!fileIo.accessSync(path)) { return { books: currentBooks, updatedCount: 0, createdMissingBodyCount: 0 }; }
    const records = BackupRepository.splitJsonArray(fileIo.readTextSync(path));
    let result: Book[] = currentBooks;
    let updatedCount: number = 0;
    let createdMissingBodyCount: number = 0;
    for (let bookIndex = 0; bookIndex < currentBooks.length; bookIndex++) {
      const book = currentBooks[bookIndex];
      if (book === undefined || book.contentPath === undefined) { continue; }
      for (let recordIndex = 0; recordIndex < records.length; recordIndex++) {
        const record = records[recordIndex] ?? '';
        if (BackupRepository.readJsonString(record, 'bookUrl') !== book.contentPath) { continue; }
        const index = BackupRepository.readJsonNumber(record, 'durChapterIndex');
        const position = BackupRepository.readJsonNumber(record, 'durChapterPos');
        const savedCharset = BackupRepository.readJsonString(record, 'charset');
        let bookWithCharset = book;
        if (book.format === 'txt' && savedCharset !== undefined && savedCharset.length > 0 &&
          savedCharset !== book.charset) {
          try {
            bookWithCharset = BookRepository.withCharset(book, savedCharset);
          } catch (_) {
          }
        }
        const restoredProgress = BookRepository.restoreAndroidProgress(bookWithCharset,
          index === undefined ? book.chapterIndex ?? 0 : index,
          position === undefined ? 0 : position);
        let updated = BookRepository.withShelfMetadata(restoredProgress,
          restoredProgress.groupNames ?? [], restoredProgress.groupName ?? '', restoredProgress.customTag,
          restoredProgress.title, restoredProgress.author, restoredProgress.category,
          restoredProgress.description, restoredProgress.remark);
        updated.latestChapterTime = Math.max(0, Math.trunc(
          BackupRepository.readJsonNumber(record, 'latestChapterTime') ?? restoredProgress.latestChapterTime ?? 0));
        updated.durChapterTime = Math.max(0, Math.trunc(
          BackupRepository.readJsonNumber(record, 'durChapterTime') ?? restoredProgress.durChapterTime ?? 0));
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
    for (let recordIndex = 0; recordIndex < records.length; recordIndex++) {
      const record = records[recordIndex] ?? '';
      if (!BackupRepository.isLocalAndroidBook(record)) { continue; }
      const originalPath = BackupRepository.readJsonString(record, 'bookUrl') ?? '';
      if (originalPath.length === 0 || result.some((book: Book) =>
        book.contentPath === originalPath || book.androidOriginalPath === originalPath)) { continue; }
      const placeholder = BackupRepository.createMissingBodyBook(record, originalPath);
      result = [...result, placeholder];
      createdMissingBodyCount += 1;
    }
    return {
      books: result,
      updatedCount: updatedCount,
      createdMissingBodyCount: createdMissingBodyCount
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
    return {
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
      coverColor: '#39424B',
      coverMark: title.substring(0, 1) || '书',
      chapterCount: totalChapters.toString(),
      description: customIntro.length > 0 ? customIntro : intro,
      remark: BackupRepository.readJsonString(record, 'remark') ?? undefined,
      customTag: customTag.length > 0 ? customTag : undefined,
      bodyMissing: true,
      androidOriginalPath: originalPath,
      androidCharacterPosition: Math.max(0, Math.trunc(characterPosition)),
      readerPositionVersion: 2,
      format: originalPath.toLowerCase().endsWith('.epub') ? 'epub' : 'txt',
      charset: BackupRepository.readJsonString(record, 'charset') ?? undefined,
      isLocal: true
    };
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
    try { names = fileIo.listFileSync(directory); } catch (_) { return []; }
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
      } catch (_) {
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

  private static isLocalAndroidBook(record: string): boolean {
    const origin = BackupRepository.readJsonString(record, 'origin') ?? '';
    const type = BackupRepository.readJsonNumber(record, 'type') ?? 0;
    return origin.startsWith('loc_book') || (Math.trunc(type) & 256) !== 0;
  }

  private static filterLocalBooks(text: string): string {
    const records = BackupRepository.splitJsonArray(text)
      .filter((record: string) => !BackupRepository.isLocalAndroidBook(record));
    return `[${records.join(',')}]`;
  }

  private static async copyPreservedEntries(context: Context, targetDirectory: string, ignored: string[]): Promise<void> {
    const sourceDirectory = `${context.filesDir}/${BackupRepository.legacyDirectoryName}`;
    let names: string[] = [];
    try { names = fileIo.listFileSync(sourceDirectory); } catch (_) { return; }
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
    return result + text.substring(cursor);
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

  private static upsertAndroidPreference(
    xml: string,
    type: 'boolean' | 'int' | 'string',
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

  private static readXmlString(path: string, key: string): string | undefined {
    if (!fileIo.accessSync(path)) { return undefined; }
    const text = fileIo.readTextSync(path);
    const name = key.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
    const valueMatch = new RegExp(`<string\\b[^>]*name=["']${name}["'][^>]*>([\\s\\S]*?)</string>`, 'i')
      .exec(text)?.[1];
    return valueMatch?.trim();
  }

  private static paperIndexFromAndroidConfig(type: number, background: string): number {
    if (type !== 0) { return 0; }
    const value = background.toLowerCase();
    const styleIndex = READER_BACKGROUND_STYLES.findIndex((style) => style.dayColor.toLowerCase() === value);
    if (styleIndex >= 0) { return styleIndex; }
    if (value === '#000000' || value === '#000' || value === 'black') { return 0; }
    if (value === '#e5eade' || value === '#e5eafd') { return 3; }
    if (value === '#f3efe4' || value === '#f2eee2') { return 1; }
    return 0;
  }

  private static ensureDirectory(path: string): void {
    try { fileIo.mkdirSync(path, true); }
    catch (error) {
      try { if (fileIo.lstatSync(path).isDirectory()) { return; } } catch (_) { }
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

  private static isSafeRootEntry(name: string): boolean {
    return name.length > 0 && name !== '.' && name !== '..' && !name.includes('/') &&
      !name.includes('\\') && !name.includes('\u0000') &&
      (name.endsWith('.json') || name.endsWith('.xml'));
  }

  private static parseIgnoreList(value: string): string[] {
    const options = BackupRepository.categoryOptions.map((item: BackupCategoryOption) => item.key);
    return value.split('\n').filter((item: string) => options.includes(item));
  }

  private static currentDate(): string {
    const date = new Date();
    const month = (date.getMonth() + 1).toString().padStart(2, '0');
    const day = date.getDate().toString().padStart(2, '0');
    return `${date.getFullYear()}-${month}-${day}`;
  }
}
