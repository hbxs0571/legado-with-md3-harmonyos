import { AppRoute, Book, BookChapter, bookCoverColor, bookCoverMark, BookMediaType, ProfileRoute } from '../model/Book';
import { BookGroup, BookGroupDraft } from '../model/BookGroup';
import { HomePage } from './HomePage';
import { BookshelfPage } from './BookshelfPage';
import { DiscoverPage } from './DiscoverPage';
import { SubscriptionPage } from './SubscriptionPage';
import { SubscriptionFavoritesPage, SubscriptionRulesPage, SubscriptionSourceManagePage } from './SubscriptionSubPages';
import { ProfilePage } from './ProfilePage';
import { ReaderPage } from './ReaderPage';
import { CatalogPage } from './CatalogPage';
import { TxtTocRulePreviewPage } from './TxtTocRulePreviewPage';
import { ReaderSettingsPage } from './ReaderSettingsPage';
import { SearchPage } from './SearchPage';
import {
  BookSourceManagePage, ReplaceRulesPage, ReplaceRuleEditPage, TxtTocRulesPage, DictionaryRulesPage,
  DictionaryRuleEditPage, HighlightTagRulesPage, HighlightTagRuleEditPage,
  AllBookmarksPage, ReadRecordsPage, CacheManagementPage,
  AboutAppPage, AiChatPage, AppSettingsHomePage, BookmarkBookSummary, BookmarkEntrySummary, RuleListEntry
} from './ProfileSubPages';
import { ReadRecordOverviewPage } from './ReadRecordOverviewPage';
import { ReaderSearchPage } from './ReaderSearchPage';
import { ReaderAloudSettingsPage } from './ReaderAloudSettingsPage';
import { BookInfoPage } from './BookInfoPage';
import { ThemeSettingsPage } from './ThemeSettingsPage';
import { CustomThemePage } from './CustomThemePage';
import { ThemeManagePage } from './ThemeManagePage';
import { APP_FONT_FAMILY, appFontDisplayName, normalizeAppFontPath } from '../data/AppFontSettings';
import { OtherSettingsPage } from './OtherSettingsPage';
import { AppReadAloudSettingsPage } from './AppReadAloudSettingsPage';
import { AppCoverSettingsPage } from './AppCoverSettingsPage';
import { AppDownloadCacheSettingsPage } from './AppDownloadCacheSettingsPage';
import { BookshelfManagePage } from './BookshelfManagePage';
import { CacheSettingsRepository } from '../data/CacheSettingsRepository';
import { AppAiSettingsPage } from './AppAiSettingsPage';
import { AppTranslationSettingsPage } from './AppTranslationSettingsPage';
import { AppPrivacySettingsPage } from './AppPrivacySettingsPage';
import { AppLabSettingsPage } from './AppLabSettingsPage';
import { AppBackupSettingsPage } from './AppBackupSettingsPage';
import { WebDavSettings, defaultWebDavSettings, WebDavConfigStore, isWebDavConfigured } from '../lib/WebDavConfig';
import { WebDavSync } from '../lib/WebDavSync';
import { PrivacyNoticePage } from './PrivacyNoticePage';
import { OpenSourceLicensePage } from './OpenSourceLicensePage';
import { FileManagerPage } from './FileManagerPage';
import { AppGlyph, AppGlyphName } from '../components/AppGlyph';
import { BookRepository } from '../data/BookRepository';
import { CreatedLocalBook, TocRefreshResult } from '../data/BookRepository';
import { BookGroupRepository } from '../data/BookGroupRepository';
import { BookshelfLayoutRepository } from '../data/BookshelfLayoutRepository';
import { TagGroupRuleRepository } from '../data/TagGroupRuleRepository';
import { PrivateAccessRepository, PRIVATE_STORE_UNLOCKED } from '../data/PrivateAccessRepository';
import { BookInfoSettingsRepository } from '../data/BookInfoSettings';
import { HighlightTagRuleRepository } from '../data/HighlightTagRuleRepository';
import { HighlightTagRule } from '../model/HighlightTagRule';
import { TagGroupRule } from '../model/TagGroupRule';
import { TagGroupRuleSync } from '../data/TagGroupRuleSync';
import { CoverSettings, DEFAULT_COVER_SETTINGS, copyCoverSettings, CoverSettingsRepository } from '../data/CoverSettingsRepository';
import { CoverRuleRepository } from '../data/CoverRuleRepository';
import { CoverAlbumRepository } from '../data/CoverAlbumRepository';
import {
  BookshelfLayoutSettings, DEFAULT_BOOKSHELF_LAYOUT, copyBookshelfLayout
} from '../model/BookshelfLayout';
import {
  HomeDashboardSection, HOME_DASHBOARD_SECTIONS, HomeDashboardSettingsRepository
} from '../data/HomeDashboardSettingsRepository';
import { OnboardingRepository } from '../data/OnboardingRepository';
import { ThemeSettingsRepository, THEME_MODE_DARK, THEME_MODE_LIGHT, normalizeFontScale, normalizeBookInfoBackground, normalizeThemeColor, FONT_SCALE_DEFAULT, normalizeBackgroundBlur } from '../data/ThemeSettingsRepository';
import { applyThemeColors, normalizePaletteIndex, resolvePaletteColors } from '../data/ThemePalette';
import {
  CustomThemeSnapshot, defaultCustomThemeSnapshot, normalizeCustomThemeSnapshot, resolveCustomPaletteColors
} from '../data/CustomThemeColors';
import {
  ASSET_BACKGROUND_DARK, ASSET_BACKGROUND_LIGHT, ASSET_CONTAINER_ITEM_DARK, ASSET_CONTAINER_ITEM_LIGHT,
  ASSET_CONTAINER_LARGE_DARK, ASSET_CONTAINER_LARGE_LIGHT, ASSET_FONT_APP,
  ThemeConfigPatch, ThemePackageSource
} from '../data/ThemePackageRepository';
import {
  BOTTOM_BAR_BLUR_ALPHA_DEFAULT, BOTTOM_BAR_BLUR_RADIUS_DEFAULT, BOTTOM_BAR_LENS_RADIUS_DEFAULT,
  BOTTOM_BAR_OPACITY_DEFAULT, TOP_BAR_BLUR_ALPHA_DEFAULT, TOP_BAR_BLUR_RADIUS_DEFAULT,
  TOP_BAR_BUTTON_STYLE_DEFAULT, TOP_BAR_OPACITY_DEFAULT, TopBottomBarSnapshot, normalizeBarBlurAlpha,
  normalizeBottomBarBlurRadius, normalizeBottomBarLensRadius, normalizeBottomBarOpacity,
  normalizeTopBarBlurRadius, normalizeTopBarButtonStyle, normalizeTopBarOpacity,
  resolveBottomBarBackground, resolveBottomBarCornerRadius, resolveTopBarBackground
} from '../data/TopBottomBarSettings';
import {
  DEFAULT_HOME_PAGE_DEFAULT,
  LABEL_VISIBILITY_DEFAULT,
  MAIN_NAVIGATION_ORDER_DEFAULT,
  joinMainNavigation,
  mainNavigationLabel,
  moveNavigationDown,
  moveNavigationUp,
  normalizeDefaultHomePage,
  orderedMainNavigation,
  visibleMainNavigation
} from '../data/MainNavigationSettings';
import {
  CARD_BORDER_WIDTH_DEFAULT,
  CARD_RADIUS_DEFAULT,
  CONTAINER_OPACITY_DEFAULT,
  DIVIDER_LENGTH_DEFAULT,
  DIVIDER_WIDTH_DEFAULT,
  ThemeCardStyleSnapshot,
  normalizeCardBorderWidth,
  normalizeCardCornerRadius,
  normalizeContainerOpacity,
  normalizeDividerLength,
  normalizeDividerWidth,
  resolveCardBackgroundColor,
  resolveCardBorderColor,
  resolveCardBorderWidth,
  resolveCardCornerRadius,
  resolveDividerColor,
  resolveDividerLength,
  resolveDividerWidth
} from '../data/ThemeCardStyle';
import { ThemeModeResolver } from '../data/ThemeModeResolver';
import { EyeProtection } from '../data/EyeProtection';
import {
  ReaderBottomActionConfig, ReaderSettingsRepository, ReaderSettingsSnapshot, READER_BACKGROUND_STYLES,
  ReaderBackgroundStyle, READER_STYLE_PRESET_COUNT, copyReaderBackgroundStyles,
  READER_STYLE_NEW_DAY_COLOR, READER_STYLE_NEW_NIGHT_COLOR,
  READER_CLICK_REGION_DEFAULTS,
  READER_LOCAL_BOTTOM_ACTION_DEFAULTS, READER_LOCAL_TOP_ACTION_DEFAULTS,
  ReaderInfoSettings, DEFAULT_READER_INFO_SETTINGS, copyReaderInfoSettings, updateReaderInfoSettings,
  ReaderPaddingSettings, DEFAULT_READER_PADDING_SETTINGS, copyReaderPaddingSettings
} from '../data/ReaderSettingsRepository';
import { ReaderMoreActionConfig, ReaderMoreActionsRepository, READER_MORE_ACTION_DEFAULTS } from '../data/ReaderMoreActionsRepository';
import {
  BackupCategoryOption, BackupEntryPreview, BackupIgnoreLists, BackupPreview, BackupRepository, BackupSelection
} from '../data/BackupRepository';
import { OnboardingPage } from './OnboardingPage';
import { ReaderBookmark } from '../model/ReaderBookmark';
import { ReaderSearchNavItem } from '../model/ReaderSearchNav';
import { ReaderBookmarkRepository } from '../data/ReaderBookmarkRepository';
import { ReaderBookmarkExporter } from '../data/ReaderBookmarkExporter';
import { sensor } from '@kit.SensorServiceKit';
import { window } from '@kit.ArkUI';
import { fileIo, picker } from '@kit.CoreFileKit';
import { ReaderBackgroundImageRepository } from '../data/ReaderBackgroundImageRepository';
import { ReaderBookmarkBadgeRepository } from '../data/ReaderBookmarkBadgeRepository';
import { ReaderMarking, ReaderMarkingEffect } from '../model/ReaderMarking';
import { ReaderMarkingRepository } from '../data/ReaderMarkingRepository';
import {
  BookmarkTargetVerdict,
  MarkingRelocateAnchor,
  MarkingRelocateCandidate,
  MarkingRelocateTarget,
  PendingBookmarkTarget,
  ReaderBookmarkTarget
} from '../data/ReaderBookmarkTarget';
import { ReplaceRuleRepository } from '../data/ReplaceRuleRepository';
import { ReplaceRuleImporter } from '../data/ReplaceRuleImporter';
import { TxtTocRuleRepository } from '../data/TxtTocRuleRepository';
import { TxtTocRuleImporter } from '../data/TxtTocRuleImporter';
import { TxtTocRule } from '../model/TxtTocRule';
import { BookContentProcessRepository } from '../data/BookContentProcessRepository';
import { ReplaceRule } from '../model/ReplaceRule';
import { LocalTextSemantics } from '../data/LocalTextSemantics';
import { ReaderBookmarkEditor } from './ReaderBookmarkEditor';
import { ReaderMarkingEditor } from './ReaderMarkingEditor';
import { BookReadRecordDay, BookReadRecordPanel, BookReadRecordSession, ReadRecordDetail, ReadRecordSummary, ReadTimeRecord } from '../model/ReadRecord';
import { ReadRecordRepository } from '../data/ReadRecordRepository';

const EMPTY_BOOK: Book = {
  id: '',
  title: '',
  author: '',
  category: '',
  lastChapter: '',
  progress: 0,
  isLocal: false
};

@Entry
@Component
struct Index {
  @StorageProp('themeColorAccent') themeColorAccent: string = '#3F5BD9';
  @StorageProp('themeColorSurfacePrimary') themeColorSurfacePrimary: string = '#F5F6F8';
  @StorageProp('themeColorSurfaceElevated') themeColorSurfaceElevated: string = '#FFFFFF';
  /** 纯黑是否实际生效（深色 + 用户开启），由 `publishThemeCardStyle` 广播；Index 自身持有开关源状态，故用别名读回。 */
  @StorageProp('themePureBlack') themePureBlackActive: boolean = false;
  @State @Watch('onReaderRouteChanged') route: AppRoute = AppRoute.HOME;
  @State readerReturnRoute: AppRoute = AppRoute.BOOKSHELF;
  @State bookInfoReturnRoute: AppRoute = AppRoute.BOOKSHELF;
  @State catalogReturnRoute: AppRoute = AppRoute.READER;
  @State readerControlsOpenOnReturn: boolean = false;
  @State settingsReturnRoute: AppRoute = AppRoute.READER;
  @State readerSettingsOpenBottomActionConfig: boolean = false;
  @State searchReturnRoute: AppRoute = AppRoute.BOOKSHELF;
  @State searchPageQuery: string = '';
  @State searchPageGroup: string = '全部书籍';
  @State searchPageSourceScope: boolean = false;
  @State searchPageExactMatch: boolean = false;
  @State profileDetailReturnRoute: AppRoute = AppRoute.PROFILE;
  @State profileSubpage: ProfileRoute = ProfileRoute.BOOK_SOURCE_MANAGE;
  @State profileSettingsReturn: ProfileRoute = ProfileRoute.APP_SETTINGS;
  /** 进书架管理页时带上的分组名（:482）；空串表示全部。 */
  @State bookshelfManageGroupName: string = '';
  @State selectedTab: number = 0;
  @State selectedBook: Book = EMPTY_BOOK;
  @State readerStartAtChapterBeginning: boolean = false;
  @State selectedChapter: string = '';
  @State books: Book[] = [];
  /** 正在刷新目录的书主键集合，传给 BookshelfPage 显示更新中状态（:120）。 */
  @State refreshingBookIds: string[] = [];
  @State bookGroups: BookGroup[] = [];
  /** 书架布局设置，与 BookshelfLayoutRepository 的持久化值保持同步。 */
  @State bookshelfLayout: BookshelfLayoutSettings = copyBookshelfLayout(DEFAULT_BOOKSHELF_LAYOUT);
  /** 封面文字设置，与 CoverSettingsRepository 的持久化值保持同步。 */
  @State coverSettings: CoverSettings = copyCoverSettings(DEFAULT_COVER_SETTINGS);
  @State readTimeRecords: ReadTimeRecord[] = [];
  @State readRecordDetails: ReadRecordDetail[] = [];
  @State readRecordSummaries: ReadRecordSummary[] = [];
  @State readerBookmarks: ReaderBookmark[] = [];
  @State readerMarkings: ReaderMarking[] = [];
  @State replaceRules: ReplaceRule[] = [];
  /** TXT 目录规则列表，与仓储缓存同步。 */
  @State txtTocRules: TxtTocRule[] = [];
  /** 高亮标签规则，启动时 load 一次；详情页按 @Prop 拿快照自己算匹配（:299）。 */
  @State highlightTagRules: HighlightTagRule[] = [];
  /** 移出书架是否二次确认（:291），跟 BookInfoSettingsRepository 同步。 */
  @State bookInfoDeleteAlert: boolean = true;
  /** 当前正在编辑的替换规则；为空表示新建。 */
  @State editingReplaceRule: ReplaceRule | undefined = undefined;
  /** 替换规则列表的排序模式，与 Repository 中的持久化值保持同步。 */
  @State replaceRuleSortMode: string = 'asc';
  @State replaceEnableDefault: boolean = true;
  @State readerReplaceEnabled: boolean = true;
  @State readerReplaceUsesDefault: boolean = true;
  @State bookmarkEditor: ReaderBookmark | undefined = undefined;
  @State bookmarkEditorIsNew: boolean = true;
  @State markingEditor: ReaderMarking | undefined = undefined;
  @State markingEditorIsNew: boolean = true;
  @State readerBookmarkTargetPosition: number = -1;
  @State readerBookmarkTargetRevision: number = 0;
  /**
   * 从搜索页跳进正文时带过来的结果集与当前下标。
   * 阅读页用它画两侧箭头与底部结果条（上游 `ReadBookState.searchResultIndex` 同用途）。
   */
  @State readerSearchNavItems: ReaderSearchNavItem[] = [];
  @State readerSearchNavIndex: number = -1;
  /** 跳转校验未通过时挂在这里，弹「仍要跳转吗」确认框。 */
  @State pendingBookmarkTarget: PendingBookmarkTarget | undefined = undefined;
  @State readerContent: string = '';
  /**
   * 邻章预读结果（页层批次 4）：阅读页在章末前先要一章，宿主读完经这一项送回。
   *
   * 编码成 `章号 \u0000 正文` 一次赋值。用两个 `@State` 分开发会让阅读页的
   * `@Watch` 各触发一次，中间帧章号与正文对不上，会按错的章号排错页。
   */
  @State readerAdjacentChapterPayload: string = '';
  /** 正在读盘的邻章章号，-1 表示没有在途请求；同一章重复请求直接忽略。 */
  private readerAdjacentChapterPending: number = -1;
  /** 已经下发过的邻章章号，-1 表示没有；防止同一章反复读盘。 */
  private readerAdjacentChapterDelivered: number = -1;
  // 正文排版初值对齐上游「无数据」层 readConfig.json[0]（设置装载完成前的一帧也用这套值）。
  @State readerFontSize: number = 24;
  @State readerParagraphSpacing: number = 6;
  @State readerLineSpacing: number = 10;
  @State readerLetterSpacing: number = 0;
  @State readerParagraphIndent: string = '　　';
  @State readerTextFont: string = '';
  @State readerTitleFont: string = '';
  @State readerSystemTypefaces: number = 0;
  @State readerTextItalic: boolean = false;
  @State readerTextBold: number = 0;
  @State readerTextShadow: boolean = false;
  @State readerShadowRadius: number = 16;
  @State readerShadowDx: number = 1;
  @State readerShadowDy: number = 1;
  @State readerTextShadowColor: string = '#3E3D3B';
  @State readerTextShadowColorN: string = '#3E3D3B';
  @State readerUnderline: boolean = false;
  @State readerDottedLine: boolean = false;
  @State readerUnderlineColor: string = '#3E3D3B';
  @State readerUnderlineColorNight: string = '#ADADAD';
  @State readerUnderlineHeight: number = 1;
  @State readerUnderlinePadding: number = 10;
  @State readerUnderlineExtend: boolean = false;
  @State readerDottedBase: number = 6;
  @State readerDottedRatio: number = 6;
  @State readerTextFullJustify: boolean = true;
  @State readerTextBottomJustify: boolean = true;
  @State paperIndex: number = 0;
  @State dayPaperIndex: number = 0;
  @State nightPaperIndex: number = 0;
  /**
   * 背景样式表，对应上游 `ReadStyleState.items`。前 `READER_STYLE_PRESET_COUNT` 份是内置预设，
   * 其后是用户自建、可增删排序；上面三个 paperIndex 都是这张表的下标。
   */
  @State backgroundStyles: ReaderBackgroundStyle[] = copyReaderBackgroundStyles(READER_BACKGROUND_STYLES);
  /**
   * 阅读页当前是否夜间。
   *
   * 这里不再让它做独立来源：它的唯一来源是全局 `themeMode`（见 `applyThemeMode`），
   * 只作为投影向下传给 `ReaderPage` / `ReaderSettingsPage`。
   * 上游 `ReadStyleDelegate.kt:455-470` 的日夜按钮同样是写全局 `themeMode`，不是写阅读页私有值。
   */
  @State readerNightMode: boolean = true;
  @State shareReaderStyleLayout: boolean = false;
  @State showReaderBottomActionText: boolean = true;
  @State readerBottomIconStyle: number = 1;
  @State readerBottomItemsPerRow: number = 5;
  @State readerBottomRowCount: number = 1;
  @State readerBottomActions: ReaderBottomActionConfig[] = READER_LOCAL_BOTTOM_ACTION_DEFAULTS.map(
    (item: ReaderBottomActionConfig): ReaderBottomActionConfig => ({ id: item.id, enabled: item.enabled })
  );
  @State readerTopActions: ReaderBottomActionConfig[] = READER_LOCAL_TOP_ACTION_DEFAULTS.map(
    (item: ReaderBottomActionConfig): ReaderBottomActionConfig => ({ id: item.id, enabled: item.enabled })
  );
  @State readerMoreActions: ReaderMoreActionConfig[] = READER_MORE_ACTION_DEFAULTS.map(
    (item: ReaderMoreActionConfig): ReaderMoreActionConfig => ({ id: item.id, enabled: item.enabled })
  );
  /**
   * 菜单镜头半径（上游 `readMenuLensRadius`，ReadSettings.kt:110，默认 24，夹 0–48）。
   * 上游全仓没有该字段的设置入口，只在 API 33+ 液态玻璃材质下生效，ArkUI 无对应材质，
   * 因此本地只落库、不上屏（与 KI-A3 `disableReturnKey` 同一判据）。
   */
  @State readerReadMenuLensRadius: number = 24;
  /**
   * 阅读栏样式是否跟随页面（上游 `readBarStyleFollowPage`，ReadSettings.kt:68，默认 false）。
   * 上游同样没有设置入口；本地 `ReaderPage.readerMenuBaseColor()` 由纸色等 @Prop 响应式重算，
   * 天然等价，故只落库、不加开关。
   */
  @State readerReadBarStyleFollowPage: boolean = false;
  /**
   * 「更多」下拉菜单是否显示每项前置图标，上游 `showMenuIcon`（ReadSettings.kt:119，默认 false）。
   * 上游消费点 `ReadBookMenuBarFloating.kt:174` 的 `OverflowDropdownMenu`。
   */
  @State readerShowMenuIcon: boolean = false;
  /**
   * 顶部工具栏附加区域是否显示，上游 `showReadTitleAddition`（ReadSettings.kt:55，默认 true）。
   * 上游只有字段与设置界面、没有渲染消费点，本地只落库。
   */
  @State readerShowReadTitleAddition: boolean = true;
  /** 菜单不透明度 0-100，上游 `menuAlpha`（ReadSettings.kt:13，默认 100）；上游无渲染消费点，本地只落库。 */
  @State readerMenuAlpha: number = 100;
  @State readerProgressBehavior: string = 'page';
  @State readerReadSliderMode: string = '0';
  @State readerPageTouchSlop: number = 0;
  /** 上一次用过的标记样式（上游 TextProcessStyle 的 JSON），空串表示没有历史。 */
  @State readerLastMarkingStyle: string = '';
  @State readerPaddingSettings: ReaderPaddingSettings = copyReaderPaddingSettings(DEFAULT_READER_PADDING_SETTINGS);
  @State readerScreenOrientation: string = '0';
  @State readerKeepLight: string = '0';
  @State readerVolumeKeyPage: boolean = true;
  @State readerKeyPageOnLongPress: boolean = false;
  @State readerNoAnimScrollPage: boolean = false;
  /** 自定义翻页按键：英文逗号分隔的键值串，对齐上游 prevKeys（存储键 prevKeyCodes）。 */
  @State readerPrevKeys: string = '';
  /** 自定义翻页按键：对齐上游 nextKeys（存储键 nextKeyCodes）。 */
  @State readerNextKeys: string = '';
  /** 鼠标滚轮翻页开关，对齐上游 mouseWheelPage。 */
  @State readerMouseWheelPage: boolean = true;
  /** 划词菜单是否展开成多行，对齐上游 expandTextMenu。 */
  @State readerExpandTextMenu: boolean = false;
  /** 划词菜单是否显示图标，对齐上游 showSelectMenuIcon。 */
  @State readerShowSelectMenuIcon: boolean = true;
  /** 划词菜单条目配置 JSON 串，对齐上游 textSelectMenuConfig；空串表示沿用内置顺序。 */
  @State readerTextSelectMenuConfig: string = '';
  /** 横屏双页档位，对齐上游 doubleHorizontalPage（ReadSettings.kt:26），'0' 全局单页。 */
  @State readerDoubleHorizontalPage: string = '0';
  /** 环境光驱动日夜提醒开关；上游 `autoSuggestDayNight`（`ReadSettings.kt:43`）。 */
  @State @Watch('onReaderAutoSuggestDayNightChanged') readerAutoSuggestDayNight: boolean = false;
  /** 禁用返回键；上游 `disableReturnKey`（`ReadSettings.kt:50`）。上游 UI 侧无消费点，本地只做可配+落库。 */
  @State readerDisableReturnKey: boolean = false;
  /** 阅读亮度 1..100；上游 `readBrightness`（`ReadSettings.kt:22`，默认 100），按 readBrightness/100 设窗口亮度。 */
  @State readerReadBrightness: number = 100;
  /** 阅读菜单里亮度条的形态；上游 `showBrightnessView`（`ReadSettings.kt:20`），"0" 关闭 / "1" 横排 / "2" 竖排。 */
  @State readerShowBrightnessView: string = '0';
  /** 竖排亮度条贴哪一侧；上游 `brightnessVwPos`（`ReadSettings.kt:21`），"0" 左 / "1" 右。 */
  @State readerBrightnessVwPos: string = '1';
  /** 亮度是否跟随系统；上游 `brightnessAuto`（`ReadSettings.kt:23`，默认 true）。 */
  @State readerBrightnessAuto: boolean = true;
  /** 正文行高适配；上游 `readBodyToLh`（`ReadSettings.kt:14`，默认 true），存储键同名。 */
  @State readerReadBodyToLh: boolean = true;
  /** 自定义中文分行；上游 `useZhLayout`（`ReadSettings.kt:19`，默认 false），只参与分页输入签名。 */
  @State readerUseZhLayout: boolean = false;
  /** 正文避让显示缺口；上游 `paddingDisplayCutouts`（`ReadSettings.kt:11`，默认 false）。 */
  @State readerPaddingDisplayCutouts: boolean = false;
  /** 适配书籍自带特殊样式；上游 `adaptSpecialStyle`（`ReadSettings.kt:18`，默认 true）。 */
  @State readerAdaptSpecialStyle: boolean = true;
  /** 底栏圆角（vp）；上游 readMenuBottomCornerRadius 默认 32，存 0-32。 */
  @State readerReadMenuBottomCornerRadius: number = 32;
  /** 底栏是否悬浮；上游 readMenuFloatingBottomBar 默认开。 */
  @State readerReadMenuFloatingBottomBar: boolean = true;
  /** 底栏模糊模式；0 关闭 / 1 液态玻璃 / 2 雾化，上游 readMenuBottomBarBlurMode。 */
  @State readerReadMenuBottomBarBlurMode: number = 0;
  /** 底栏模糊样式；0 填充 / 1 渐变，上游 readMenuBottomBarBlurStyle。 */
  @State readerReadMenuBottomBarBlurStyle: number = 0;
  /** 底栏按钮液态玻璃；上游 readMenuBottomBarLiquidGlassButtons。 */
  @State readerReadMenuBottomBarLiquidGlassButtons: boolean = false;
  /** 菜单不透明度（0-100）；底栏与顶栏共用上游 readMenuBlurAlpha，默认 85。 */
  @State readerReadMenuBlurAlpha: number = 85;
  /** 标题栏胶囊；上游 readMenuTopBarTitleCapsule（ReadSettings.kt:100，默认 false）。 */
  @State readerReadMenuTopBarTitleCapsule: boolean = false;
  /** 标题栏显示方式，四值字符串 "0"-"3"；上游 titleBarMode（ReadSettings.kt:12，默认 "1"）。 */
  @State readerTitleBarMode: string = '1';
  /** 标题栏精简；上游 titleBarCompact（ReadSettings.kt:120，默认 false）。 */
  @State readerTitleBarCompact: boolean = false;
  /** 标题栏图标样式 0/1/2；上游 titleBarIconStyle（ReadSettings.kt:91，默认 0）。 */
  @State readerTitleBarIconStyle: number = 0;
  /** 顶栏模糊模式 0/1/2；上游 readMenuTopBarBlurMode（ReadSettings.kt:96，默认 0）。 */
  @State readerReadMenuTopBarBlurMode: number = 0;
  /** 顶栏模糊样式 0 填充 / 1 渐变；上游 readMenuTopBarBlurStyle（ReadSettings.kt:103，默认 0）。 */
  @State readerReadMenuTopBarBlurStyle: number = 0;
  /** 顶栏按钮液态玻璃；上游 readMenuTopBarLiquidGlassButtons（ReadSettings.kt:98，默认 false）。 */
  @State readerReadMenuTopBarLiquidGlassButtons: boolean = false;
  /** 顶栏按钮合并；上游 readMenuTopBarMergeButtons（ReadSettings.kt:99，默认 false）。 */
  @State readerReadMenuTopBarMergeButtons: boolean = false;
  /** 菜单工具栏样式 0 跟随系统 / 1 跟随阅读背景 / 2 自定义；上游 readBarStyle（ReadSettings.kt:69，默认 1）。 */
  @State readerReadBarStyle: number = 1;
  /** 菜单调色板样式，空串表示跟随系统；上游 readMenuPaletteStyle（ReadSettings.kt:109，默认空串）。 */
  @State readerMenuPaletteStyle: string = '';
  /** 菜单色板来源 0 种子色 / 1 自定义颜色；上游 readMenuColorMode（ReadSettings.kt:88，默认 1）。 */
  @State readerMenuColorMode: number = 1;
  /** 菜单背景色，空串表示未设置；上游 readMenuBgColor（ReadSettings.kt:80，默认 0）。 */
  @State readerMenuBgColor: string = '';
  /** 菜单背景色（夜间）；上游 readMenuBgColorNight（ReadSettings.kt:83，默认 0）。 */
  @State readerMenuBgColorNight: string = '';
  /** 菜单容器色，空串时回落菜单背景色；上游 readMenuContainerColor（ReadSettings.kt:82，默认 0）。 */
  @State readerMenuContainerColor: string = '';
  /** 菜单容器色（夜间）；上游 readMenuContainerColorNight（ReadSettings.kt:85，默认 0）。 */
  @State readerMenuContainerColorNight: string = '';
  /** 菜单强调色，「种子色」项与它共用同一字段；上游 readMenuAccentColor（ReadSettings.kt:81，默认 0）。 */
  @State readerMenuAccentColor: string = '';
  /** 菜单强调色（夜间）；上游 readMenuAccentColorNight（ReadSettings.kt:84，默认 0）。 */
  @State readerMenuAccentColorNight: string = '';
  /** 菜单栏边框宽度（0 表示不显示边框）；上游 readMenuBorderWidth（ReadSettings.kt:111，默认 1）夹 0–4。 */
  @State readerMenuBorderWidth: number = 1;
  /** 菜单栏边框颜色（日间）；上游 readMenuBorderColor（ReadSettings.kt:112，默认 0 未设置）。 */
  @State readerMenuBorderColor: string = '';
  /** 菜单栏边框颜色（夜间）；上游 readMenuBorderColorNight（ReadSettings.kt:113）。 */
  @State readerMenuBorderColorNight: string = '';
  /** 菜单模糊半径；上游 readMenuBlurRadius（ReadSettings.kt:105，默认 24）夹 0–32。 */
  @State readerMenuBlurRadius: number = 24;
  /** 菜单文字与图标颜色（日间）；上游 readMenuTextColor（ReadSettings.kt:86，默认 0 未设置）。 */
  @State readerMenuTextColor: string = '';
  /** 菜单文字与图标颜色（夜间）；上游 readMenuTextColorNight（ReadSettings.kt:87）。 */
  @State readerMenuTextColorNight: string = '';
  /** 菜单模糊层着色（日间）；上游 readMenuBlurColor（ReadSettings.kt:107，默认 0 未设置）。 */
  @State readerMenuBlurColor: string = '';
  /** 菜单模糊层着色（夜间）；上游 readMenuBlurColorNight（ReadSettings.kt:108）。 */
  @State readerMenuBlurColorNight: string = '';
  // 浮动图标四项（KI-E3），对齐上游 ReadSettings.kt:102/114-117。
  @State readerShowTitleBarIcons: boolean = false;
  @State readerTitleBarIconPosition: number = 3;
  @State readerReadMenuFloatingIconLiquidGlass: boolean = false;
  /**
   * 浮动图标行按钮池，与顶栏操作按钮分开保存（上游 `ReadBookMenuBarFloating.kt:411`）。
   * 默认启用项对齐上游 `ReadButtonConfigDelegate.DEFAULT_ENABLED_BUTTON_IDS`
   * （search / auto_page / catalog / read_aloud / setting），与底栏默认一致，故取 BOTTOM 默认池。
   */
  @State readerFloatingIcons: ReaderBottomActionConfig[] = READER_LOCAL_BOTTOM_ACTION_DEFAULTS.map(
    (item: ReaderBottomActionConfig): ReaderBottomActionConfig => ({ id: item.id, enabled: item.enabled })
  );
  @State readerTitleBarCustomIcons: string = '';
  @State readerReadMenuCustomIcons: string = '';
  /** 环境光提醒：本会话已拒绝过「切到深色」的提醒，对齐上游 `hasDismissedDarkReminder`。 */
  @State readerDayNightReminderDismissedDark: boolean = false;
  /** 环境光提醒：本会话已拒绝过「切到浅色」的提醒，对齐上游 `hasDismissedLightReminder`。 */
  @State readerDayNightReminderDismissedLight: boolean = false;
  /** 环境光提醒的可见文案；空串表示没有提醒在显示。上游是 5 秒自动消失的底部胶囊。 */
  @State readerDayNightReminderText: string = '';
  /** 提醒要切到的目标模式；只在 `readerDayNightReminderText` 非空时有意义。 */
  @State readerDayNightReminderTargetNight: boolean = false;
  /** 提醒的请求序号：连续触发时只认最后一次，避免定时器把新提醒提前关掉。 */
  private readerDayNightReminderRequestId: number = 0;
  /** 上次弹出提醒的时间戳，用于上游那 10 分钟冷却（`REMINDER_COOLDOWN_MS`）。 */
  private readerDayNightReminderLastAt: number = 0;
  /** 环境光订阅是否在跑，避免重复 `sensor.on`。 */
  private readerAmbientLightSubscribed: boolean = false;
  @State readerReadingAnchorEnabled: boolean = true;
  @State readerSwipeToAddBookmark: boolean = false;
  /** 阅读页书签角标宽度（dp），0 表示不显示；与上游 bookmarkBadgeSize 对齐。 */
  @State readerBookmarkBadgeSize: number = 10;
  /** 自定义书签角标图片路径，空串表示用默认丝带；与上游 bookmarkBadgeImage 对齐。 */
  @State readerBookmarkBadgeImage: string = '';
  @State readerSelectText: boolean = true;
  /** 滑动进度条时震动；上游 ReadSettings.kt:36 sliderVibrator。上游 UI 无消费点，本地同样只落库。 */
  @State readerSliderVibrator: boolean = false;
  /** 选择正文时震动；上游 ReadSettings.kt:41 selectVibrator，消费点在选区手势。 */
  @State readerSelectVibrator: boolean = false;
  /**
   * 中文简繁体转换档位：0 = 不转换、1 = 繁转简、2 = 简转繁。
   * 上游 ReadSettings.kt:118 chineseConverterType，设置项在排版面板。
   */
  @State readerChineseConverterType: number = 0;
  /** 正文日间/夜间颜色；上游 ReadBookConfig.kt:55-56 textColor / textColorNight，默认取 readConfig.json[0]。 */
  @State readerTextColor: string = '#ff0b0b0b';
  @State readerTextColorNight: string = '#ADADAD';
  /** 正文强调色；上游 ReadBookConfig.kt:62 textAccentColor，用于链接/搜索结果/朗读段落。 */
  @State readerTextAccentColor: string = '#834E00';
  @State readerTextAccentColorNight: string = '#FE4D55';
  /**
   * 自定义背景；上游 ReadBookConfig.kt:537-551。
   * 默认取上游「无数据」层 readConfig.json[0]：bgStr 本身就是颜色值（#ffc0edc6 / #000000），
   * 非空且 bgType=0 时优先于 paperIndex 指向的内置方案。
   */
  @State readerBgStr: string = '#ffc0edc6';
  @State readerBgStrNight: string = '#000000';
  @State readerBgType: number = 0;
  @State readerBgTypeNight: number = 0;
  @State readerBgAlpha: number = 100;
  @State readerDarkStatusIcon: boolean = true;
  @State readerDarkStatusIconNight: boolean = false;
  // 标题排版十四个字段，对齐上游 help/config/ReadBookConfig.kt:596-608。
  @State readerTitleMode: number = 0;
  @State readerTitleSize: number = 4;
  @State readerTitleSizeRelative: boolean = true;
  @State readerTitleTopSpacing: number = 0;
  @State readerTitleBottomSpacing: number = 0;
  @State readerTitleColor: string = '';
  @State readerTitleColorNight: string = '';
  @State readerTitleBold: number = 500;
  @State readerTitleLineSpacingExtra: number = 12;
  @State readerTitleLineSpacingSub: number = 12;
  @State readerTitleSegType: number = 0;
  @State readerTitleSegScaling: number = 1;
  @State readerTitleSegDistance: number = 4;
  @State readerTitleSegFlag: string = '';
  @State readerMaxLengthWithNoToc: number = 3000;
  @State eyeProtectionEnabled: boolean = false;
  @State eyeProtectionAutoNight: boolean = false;
  @State eyeProtectionSchedule: boolean = false;
  @State eyeProtectionIntensity: number = 50;
  @State eyeProtectionStartTime: string = '22:00';
  @State eyeProtectionEndTime: string = '07:00';
  @State eyeProtectionMinute: number = Math.floor(Date.now() / 60000);
  @State readerAnchorOriginBook: Book | undefined = undefined;
  @State readerAnchorOriginChapter: string = '';
  @State readerAnchorJumpCount: number = 0;
  @State readerTocUseReplace: boolean = false;
  @State readerTocShowWordCount: boolean = true;
  @State readerClickImageBehavior: string = '2';
  @State readerClickRegionActions: string[] = [...READER_CLICK_REGION_DEFAULTS];
  @State readerHideStatusBar: boolean = false;
  @State readerHideNavigationBar: boolean = false;
  @State readerImagePreviewOpen: boolean = false;
  @State readerImagePreviewCloseRevision: number = 0;
  @State showReaderQuickActions: boolean = false;
  @State autoReadSpeed: number = 10;
  @State readerPageAnimation: number = 0;
  @State readerAnimationSpeed: number = 2;
  @State readerInfoSettings: ReaderInfoSettings = DEFAULT_READER_INFO_SETTINGS;
  @State backupBusy: boolean = false;
  @State backupStatusMessage: string = '';
  @State backupPreview: BackupPreview | undefined = undefined;
  @State restoredAndroidEntries: BackupEntryPreview[] = [];
  @State backupIgnoreKeys: string[] = [];
  @State restoreIgnoreKeys: string[] = [];
  @State backupCategoryOptions: BackupCategoryOption[] = BackupRepository.categoryOptionsList();
  @State webDavSettings: WebDavSettings = defaultWebDavSettings();
  @State webDavTesting: boolean = false;
  @State webDavBackupNames: string[] = [];
  @State onboardingLoaded: boolean = false;
  @State onboardingComplete: boolean = false;
  /**
   * 全局深色模式开关，上游 `AppShellSettings.themeMode`（`"0"` 跟随系统 / `"1"` 亮色 / `"2"` 暗色）。
   *
   * 这是本地日夜的唯一来源：主题设置页下拉、阅读页日夜按钮、首次启动向导都写它，
   * 界面颜色由 `resources/dark` 资源目录按 `setColorMode` 的结果自动切换。
   */
  @State themeMode: string = '0';
  /** 调色板序号，与 `themeMode` 一同落盘，对齐上游 `theme.paletteStyle`。 */
  @State themePaletteIndex: number = 0;
  /**
   * 全局字体缩放 8..16（10 = 1.0x），对齐上游 `AppShellSettings.kt:5 fontScale`。
   *
   * 上游在 `base/AppContextWrapper.kt:18-25 applyFont()` 里把它写进 `Configuration.fontScale`；
   * ArkUI 的等价机制是 `ApplicationContext.setFontSizeScale`，见 `applyThemeFontScale`。
   */
  @State themeFontScale: number = 10;
  /** 是否显示状态栏，对齐上游 `AppShellSettings.kt:10 showStatusBar`。 */
  @State themeShowStatusBar: boolean = true;
  /**
   * 是否启用滑动时动画，对齐上游 `AppShellSettings.kt:11 swipeAnimation`。
   *
   * 上游这个键**没有任何渲染消费者**（`ThemeConfigScreen.kt:362` 上方还留着
   * 「这个可以不要了」的 TODO），所以本地也只落盘、不造一个上游没有的动画效果。
   */
  @State themeSwipeAnimation: boolean = true;
  /** 书籍详情页界面颜色是否跟随封面取色，对齐上游 `ThemeSettings.bookInfoFollowCoverColor`。 */
  @State bookInfoFollowCoverColor: boolean = true;
  /** 网络封面背景模式 `off`/`on`/`off_for_default`，对齐上游 `bookInfoNetworkCoverBackground`。 */
  @State bookInfoNetworkCoverBackground: string = 'on';
  /** 默认封面背景模式，对齐上游 `bookInfoDefaultCoverBackground`。 */
  @State bookInfoDefaultCoverBackground: string = 'on';
  /** 容器底色不透明度 0..100，对齐上游 `ThemeSettings.kt:24 containerOpacity`（默认 100）。 */
  @State themeContainerOpacity: number = CONTAINER_OPACITY_DEFAULT;
  /** 关闭设置分组圆角，对齐上游 `disableSplicedColumnGroupCornerRadius`（默认 false）。 */
  @State themeDisableGroupCorner: boolean = false;
  /** 覆盖卡片圆角总开关，对齐上游 `overrideBaseCardCornerRadius`（默认 false）。 */
  @State themeOverrideCardCorner: boolean = false;
  /** 卡片圆角数值 0..40，对齐上游 `baseCardCornerRadius`（默认 16）。 */
  @State themeCardCornerRadius: number = CARD_RADIUS_DEFAULT;
  /** 覆盖卡片边框总开关，对齐上游 `overrideBaseCardBorder`（默认 false）。 */
  @State themeOverrideCardBorder: boolean = false;
  /** 边框宽度 0..5，对齐上游 `baseCardBorderWidth`（默认 1）。 */
  @State themeCardBorderWidth: number = CARD_BORDER_WIDTH_DEFAULT;
  /** 日间边框色，空串表示未设置（上游 Int 0）。 */
  @State themeCardBorderColorDay: string = '';
  /** 夜间边框色，空串表示未设置。 */
  @State themeCardBorderColorNight: string = '';
  /** 显示分隔线，对齐上游 `enableItemDivider`（默认 false）。 */
  @State themeEnableItemDivider: boolean = false;
  /** 分隔线宽度 0..5，对齐上游 `itemDividerWidth`（默认 1）。 */
  @State themeItemDividerWidth: number = DIVIDER_WIDTH_DEFAULT;
  /** 分隔线长度 30..100（百分比），对齐上游 `itemDividerLength`（默认 80）。 */
  @State themeItemDividerLength: number = DIVIDER_LENGTH_DEFAULT;
  /** 分隔线颜色，空串表示未设置（上游 Int 0）。 */
  @State themeItemDividerColor: string = '';
  /** 容器背景图总开关，对齐上游 `enableContainerBackgroundImage`（默认 false）。 */
  @State themeEnableContainerBackgroundImage: boolean = false;
  /** 大容器日间背景图本地路径，空串表示未选择。 */
  @State themeLargeContainerBackgroundLight: string = '';
  /** 大容器夜间背景图本地路径。 */
  @State themeLargeContainerBackgroundDark: string = '';
  /** 项目日间背景图本地路径。 */
  @State themeItemBackgroundLight: string = '';
  /** 项目夜间背景图本地路径。 */
  @State themeItemBackgroundDark: string = '';
  /** 纯黑深色模式（AMOLED），对齐上游 `ThemeSettings.kt:6 isPureBlack`。 */
  @State themePureBlack: boolean = false;
  /** 全 App 日间背景图，对齐上游 `PreferKey.kt:281 backgroundImage`。 */
  @State themeBackgroundImage: string = '';
  /** 全 App 夜间背景图，对齐上游 `PreferKey.kt:287 backgroundImageNight`。 */
  @State themeBackgroundImageNight: string = '';
  /** 日间背景图虚化半径，对齐上游 `backgroundImageBlurring`（默认 0）。 */
  @State themeBackgroundBlur: number = 0;
  /** 夜间背景图虚化半径，对齐上游 `backgroundImageNightBlurring`（默认 0）。 */
  @State themeBackgroundNightBlur: number = 0;
  /** 首页是否出现在主导航；上游 `AppShellSettings.kt:6 showHome`。 */
  @State themeShowHome: boolean = true;
  /** 发现是否出现在主导航；上游 `AppShellSettings.kt:7 showDiscovery`。 */
  @State themeShowDiscovery: boolean = true;
  /** 订阅是否出现在主导航；上游 `AppShellSettings.kt:8 showRss`。 */
  @State themeShowRss: boolean = true;
  /** 默认主页面；上游 `AppShellSettings.kt:17 defaultHomePage`。 */
  @State themeDefaultHomePage: string = DEFAULT_HOME_PAGE_DEFAULT;
  /** 主导航顺序；上游 `AppShellSettings.kt:18 mainNavigationOrder`。 */
  @State themeMainNavigationOrder: string = MAIN_NAVIGATION_ORDER_DEFAULT;
  /** 导航标签模式；上游 `AppShellSettings.kt:19 labelVisibilityMode`。 */
  @State themeLabelVisibilityMode: string = LABEL_VISIBILITY_DEFAULT;
  /** 预见性返回手势；上游 `AppShellSettings.kt:9 predictiveBackEnabled`。ArkUI 无等价能力，只落盘。 */
  @State themePredictiveBack: boolean = true;
  /** 阅读界面共享元素动画；上游 `AppShellSettings.kt:10 readerSharedElementEnabled`。 */
  @State themeReaderSharedElement: boolean = true;
  /** 顶栏与底栏的 15 个键，对齐上游 `TopBottomBarSettingsSheet.kt` + `ThemeSettings.kt:35-46`。 */
  @State themeEnableBlur: boolean = false;
  @State themeEnableProgressiveBlur: boolean = false;
  @State themeUseFlexibleTopAppBar: boolean = true;
  @State themeTopBarButtonStyle: string = TOP_BAR_BUTTON_STYLE_DEFAULT;
  @State themeMergeTopBarActions: boolean = false;
  @State themeShowBottomView: boolean = true;
  @State themeUseFloatingBottomBar: boolean = false;
  @State themeUseFloatingBottomBarLiquidGlass: boolean = false;
  @State themeBottomBarLensRadius: number = BOTTOM_BAR_LENS_RADIUS_DEFAULT;
  @State themeTopBarBlurRadius: number = TOP_BAR_BLUR_RADIUS_DEFAULT;
  @State themeBottomBarBlurRadius: number = BOTTOM_BAR_BLUR_RADIUS_DEFAULT;
  @State themeTopBarBlurAlpha: number = TOP_BAR_BLUR_ALPHA_DEFAULT;
  @State themeBottomBarBlurAlpha: number = BOTTOM_BAR_BLUR_ALPHA_DEFAULT;
  @State themeTopBarOpacity: number = TOP_BAR_OPACITY_DEFAULT;
  @State themeBottomBarOpacity: number = BOTTOM_BAR_OPACITY_DEFAULT;
  /** 应用字体在沙箱内的绝对路径；空串表示系统默认字体。对齐上游 `ThemeSettings.appFontPath`。 */
  @State themeAppFontPath: string = '';
  /**
   * 自定义主题配色（上游 `appTheme == "12"` 那套）。
   *
   * 只在调色板序号为 12 且深度个性化开着、且至少设了一个颜色时才真正参与换肤，
   * 判断顺序对齐上游 `ui/theme/AppTheme.kt:105-125`。
   */
  @State themeCustomColors: CustomThemeSnapshot = defaultCustomThemeSnapshot();
  @State homeDashboardSections: HomeDashboardSection[] = [...HOME_DASHBOARD_SECTIONS];
  private pendingBackup: BackupSelection | undefined = undefined;
  private readerBookmarkToggleQueue: Promise<void> = Promise.resolve();
  private readerSettingsLoaded: boolean = false;
  private readerSettingsRevision: number = 0;
  private readerSessionLastSaveTime: number = 0;
  private readerLifecycleEventsRegistered: boolean = false;
  private readerSessionPaused: boolean = false;
  private eyeProtectionTimerId: number = -1;

  aboutToAppear(): void {
    const context = this.getUIContext().getHostContext();
    if (context !== undefined) {
      if (!this.readerLifecycleEventsRegistered) {
        context.eventHub.on('pauseReadSession', () => this.stopReaderSession());
        context.eventHub.on('resumeReadSession', () => {
          if (this.route === AppRoute.READER || this.route === AppRoute.CATALOG || this.route === AppRoute.READ_ALOUD_SETTINGS ||
            (this.route === AppRoute.READER_SETTINGS && this.settingsReturnRoute === AppRoute.READER)) {
            this.startReaderSession();
          }
        });
        this.readerLifecycleEventsRegistered = true;
      }
      this.restoreStartupState(context);
    }
    this.eyeProtectionTimerId = setInterval(() => {
      this.eyeProtectionMinute = Math.floor(Date.now() / 60000);
    }, 60000);
  }

  /**
   * 启动时的一批本地状态恢复。
   *
   * 只有 `restoreReaderSettings` 需要等待：它写的是阅读排版（字号、行距、页边距等），
   * 不等它落盘就开书，会先按默认排版排一次再跳变成用户设置。
   * 其余 restore 各自独立、写的是互不重叠的 @State 字段，不串行等待，
   * 保持原本的并发启动速度（逐个 await 会明显拖慢首帧）。
   */
  private async restoreStartupState(context: Context): Promise<void> {
    this.restoreOnboarding(context);
    this.restoreReadTimeRecords(context);
    this.restoreHomeDashboardSettings(context);
    this.restoreImportedBooks(context);
    this.restoreBookshelfLayout(context);
    this.restoreReaderBookmarks(context);
    this.restoreReaderMarkings(context);
    await this.restoreReaderSettings(context);
    this.restoreReaderMoreActions(context);
    this.restoreReplaceRules(context);
    this.restoreTxtTocRules(context);
    this.restoreBookContentProcesses(context);
    this.restoreBackupIgnoreLists(context);
    this.restoreWebDavSettings(context);
    this.restorePrivateAccess(context);
    this.restoreBookInfoSettings(context);
    this.restoreHighlightTagRules(context);
    this.restoreCacheSettings(context);
    this.loadRestoredAndroidEntries(context);
  }

  aboutToDisappear(): void {
    if (this.eyeProtectionTimerId >= 0) {
      clearInterval(this.eyeProtectionTimerId);
      this.eyeProtectionTimerId = -1;
    }
  }

  private async restoreBookshelfLayout(context: Context): Promise<void> {
    this.bookshelfLayout = await BookshelfLayoutRepository.load(context);
    // 封面文字设置与书架布局一起恢复：书架首帧就要按它决定画书名还是首字
    this.coverSettings = await CoverSettingsRepository.load(context);
    // 封面规则单独一份 preferences，进设置页前先灌进缓存（aboutToAppear 从 get() 读）
    await CoverRuleRepository.load(context);
    // 相册索引与选择态也先灌缓存：设置页 A4 摘要与选择 sheet 首帧读 getAlbums()/getSelection()
    await CoverAlbumRepository.load(context);
    await CoverAlbumRepository.loadSelection(context);
  }

  private async restoreReadTimeRecords(context: Context): Promise<void> {
    // 老格式记录（legado_read_time_records）的搬迁已挪到 RdbMigration 第三批，
    // 必须在 RdbCleanup 删老键之前完成，所以这里只读权威会话层。
    await ReadRecordRepository.loadEnabled(context);
    await this.reloadReadRecordData(context);
  }

  private async reloadReadRecordData(context: Context): Promise<void> {
    const sessions = await ReadRecordRepository.loadSessions(context);
    this.readTimeRecords = ReadRecordRepository.toTimelineRecords(sessions);
    this.readRecordDetails = await ReadRecordRepository.loadDetails(context);
    this.readRecordSummaries = await ReadRecordRepository.loadSummaries(context);
  }

  /** 详情页面板数据：调批 0 两个方法取汇总与按天会话，在 Index 侧格式化好再下发。 */
  private async loadBookReadRecordPanel(book: Book): Promise<BookReadRecordPanel> {
    const empty: BookReadRecordPanel = { totalLabel: '0秒', days: [] };
    const context = this.getUIContext().getHostContext();
    if (context === undefined) { return empty; }
    const summary = await ReadRecordRepository.loadBookSummaries(context, book.title, book.author);
    const groups = await ReadRecordRepository.loadBookTimelineDays(context, book.id, book.title, book.author);
    const days: BookReadRecordDay[] = [];
    for (const group of groups) {
      const rows: BookReadRecordSession[] = [];
      for (const session of group) {
        const end = new Date(session.endTime);
        const clock = `${end.getHours().toString().padStart(2, '0')}:${end.getMinutes().toString().padStart(2, '0')}`;
        const row: BookReadRecordSession = {
          timeLabel: clock,
          durationLabel: ReadRecordRepository.formatDuration(session.endTime - session.startTime),
          chapterLabel: session.chapterIndex > 0 ? `第 ${session.chapterIndex} 章` : ''
        };
        rows.push(row);
      }
      const dateLabel = group.length > 0
        ? ReadRecordRepository.formatFriendlyDate(ReadRecordRepository.toDateKey(group[0].startTime)) : '';
      const day: BookReadRecordDay = { dateLabel: dateLabel, sessions: rows };
      days.push(day);
    }
    const panel: BookReadRecordPanel = {
      totalLabel: ReadRecordRepository.formatDuration(summary.readTime), days: days
    };
    return panel;
  }

  /** 切某本书的禁用标记：写库后同步刷新 books 与 selectedBook，让 @Prop book 更新动作卡文案。 */
  private async toggleBookDisableReadRecord(book: Book, disabled: boolean): Promise<void> {
    const context = this.getUIContext().getHostContext();
    if (context === undefined) {
      this.showUnavailableAction('无法访问本地书架，阅读记录开关未保存');
      return;
    }
    const bookUrl = book.contentPath ?? book.androidOriginalPath ?? '';
    try {
      await BookRepository.setDisableReadRecord(context, bookUrl, disabled);
      const updatedBook: Book = BookRepository.copyBook(book);
      updatedBook.disableReadRecord = disabled;
      this.selectedBook = updatedBook;
      this.books = this.books.map((item: Book) => item.id === updatedBook.id ? updatedBook : item);
    } catch (_) {
      this.showUnavailableAction('阅读记录开关保存失败');
    }
  }

  private getTotalReadTimeMs(): number {
    return this.readTimeRecords.reduce((total: number, record: ReadTimeRecord) => total + record.durationMs, 0);
  }

  private async startReaderSession(): Promise<void> {
    const context = this.getUIContext().getHostContext();
    if (context === undefined || this.selectedBook.id.length === 0) { return; }
    await ReadRecordRepository.start(context, this.selectedBook, this.selectedBook.chapterIndex ?? 0);
    this.readerSessionPaused = false;
    this.readerSessionLastSaveTime = Date.now();
  }

  private async pulseReaderSession(): Promise<void> {
    if (this.readerSessionPaused) { return; }
    const chapterIndex = this.selectedBook.chapterIndex ?? 0;
    ReadRecordRepository.touch(chapterIndex);
    const context = this.getUIContext().getHostContext();
    if (context === undefined ||
      Date.now() - this.readerSessionLastSaveTime < ReadRecordRepository.autoSaveIntervalMs) { return; }
    // 自动保存后立即开始下一段会话，避免计时空窗。
    await ReadRecordRepository.commit(context);
    await ReadRecordRepository.start(context, this.selectedBook, chapterIndex);
    this.readerSessionLastSaveTime = Date.now();
    await this.reloadReadRecordData(context);
  }

  private async stopReaderSession(): Promise<void> {
    this.readerSessionPaused = true;
    ReadRecordRepository.touch(this.selectedBook.chapterIndex ?? 0);
    const context = this.getUIContext().getHostContext();
    if (context === undefined) { return; }
    await ReadRecordRepository.commit(context);
    await this.reloadReadRecordData(context);
  }

  private async restoreReplaceRules(context: Context): Promise<void> {
    this.replaceRules = await ReplaceRuleRepository.load(context);
    this.replaceRuleSortMode = ReplaceRuleRepository.getSortMode();
    this.replaceEnableDefault = ReplaceRuleRepository.getDefaultEnabled();
    this.readerReplaceEnabled = ReplaceRuleRepository.isBookEnabled(this.selectedBook);
    this.readerReplaceUsesDefault = ReplaceRuleRepository.isBookUsingDefault(this.selectedBook);
  }


  private async restoreTxtTocRules(context: Context): Promise<void> {
    this.txtTocRules = await TxtTocRuleRepository.load(context);
  }


  private async restoreBookContentProcesses(context: Context): Promise<void> {
    await BookContentProcessRepository.load(context);
  }

  private async setReaderContentProcessEnabled(id: string, enabled: boolean): Promise<void> {
    const context = this.getUIContext().getHostContext();
    if (context === undefined || this.selectedBook.id.length === 0) { return; }
    try {
      await BookContentProcessRepository.setEnabled(context, id, enabled);
      await this.reloadSelectedChapter();
    } catch (_) {
      this.showUnavailableAction('正文处理记录启用状态保存失败');
    }
  }

  private async deleteReaderContentProcess(id: string): Promise<void> {
    const context = this.getUIContext().getHostContext();
    if (context === undefined || this.selectedBook.id.length === 0) { return; }
    try {
      await BookContentProcessRepository.markDeleted(context, id);
      await this.reloadSelectedChapter();
    } catch (_) {
      this.showUnavailableAction('正文处理记录删除失败');
    }
  }
  private async setReplaceDefaultEnabled(enabled: boolean): Promise<void> {
    const context = this.getUIContext().getHostContext();
    if (context === undefined) { return; }
    try {
      await ReplaceRuleRepository.setDefaultEnabled(context, enabled);
      this.replaceEnableDefault = enabled;
      this.readerReplaceEnabled = ReplaceRuleRepository.isBookEnabled(this.selectedBook);
      this.readerReplaceUsesDefault = ReplaceRuleRepository.isBookUsingDefault(this.selectedBook);
      if (this.route === AppRoute.READER) {
        await this.reloadSelectedChapter();
      }
    } catch (_) {
      this.showUnavailableAction('默认替换净化设置保存失败');
    }
  }

  private async setReaderReplaceEnabled(enabled: boolean): Promise<void> {
    const context = this.getUIContext().getHostContext();
    if (context === undefined || this.selectedBook.id.length === 0) { return; }
    try {
      // 先改内存里的书对象，再整体 upsert 落库：
      // 按书开关存在 books.readConfig.useReplaceRule 里（与上游 Book.config 一致），
      // 而 BookRepository 只有整行 upsert，没有单列更新。
      ReplaceRuleRepository.setBookEnabled(this.selectedBook, enabled);
      await BookRepository.saveImportedBooks(context, this.books);
      this.readerReplaceEnabled = enabled;
      this.readerReplaceUsesDefault = false;
      await this.reloadSelectedChapter();
    } catch (_) {
      this.showUnavailableAction('本书替换净化设置保存失败');
    }
  }

  private async resetReaderReplaceToDefault(): Promise<void> {
    const context = this.getUIContext().getHostContext();
    if (context === undefined || this.selectedBook.id.length === 0) { return; }
    try {
      ReplaceRuleRepository.clearBookEnabledOverride(this.selectedBook);
      await BookRepository.saveImportedBooks(context, this.books);
      this.readerReplaceUsesDefault = true;
      // 图片类与 epub 本地书即使跟随默认也是关闭净化，取值要走同一个判定
      this.readerReplaceEnabled = ReplaceRuleRepository.isBookEnabled(this.selectedBook);
      await this.reloadSelectedChapter();
    } catch (_) {
      this.showUnavailableAction('恢复默认替换净化设置失败');
    }
  }

  /**
   * 简繁转换档位改动后重读当前章节。
   * 与 reloadSelectedChapter 的差别只在路由判断：那个函数要求已经停在阅读页，
   * 而档位是在设置页里改的（route 为 READER_SETTINGS），回到阅读页时正文需要是转换后的。
   */
  private async reloadSelectedChapterForTransform(): Promise<void> {
    if (this.selectedBook.contentPath === undefined) { return; }
    try {
      this.readerContent = await BookRepository.readChapter(this.selectedBook, this.selectedChapter);
      this.replaceRules = ReplaceRuleRepository.getAll();
    } catch (_) {
      this.showUnavailableAction('重新读取本章失败');
    }
  }

  private async reloadSelectedChapter(): Promise<void> {
    if (this.selectedBook.contentPath === undefined || this.route !== AppRoute.READER) { return; }
    try {
      this.readerContent = await BookRepository.readChapter(this.selectedBook, this.selectedChapter);
      this.replaceRules = ReplaceRuleRepository.getAll();
    } catch (_) {
      this.showUnavailableAction('重新读取本章失败');
    }
  }

  private replaceRuleGroups(): string[] {
    return ReplaceRuleRepository.getGroups();
  }

  /** 打开已有规则的编辑页。 */
  private openReplaceRuleEditor(id: number): void {
    const rule = this.replaceRules.find((item: ReplaceRule) => item.id === id);
    if (rule === undefined) {
      this.showUnavailableAction('规则不存在，可能已被删除');
      return;
    }
    this.editingReplaceRule = rule;
    this.profileSubpage = ProfileRoute.REPLACE_RULE_EDIT;
  }

  private async moveReplaceRule(id: number, toTop: boolean): Promise<void> {
    const context = this.getUIContext().getHostContext();
    if (context === undefined) {
      this.showUnavailableAction('无法访问本地规则存储');
      return;
    }
    try {
      if (toTop) {
        await ReplaceRuleRepository.moveToTop(context, id);
      } else {
        await ReplaceRuleRepository.moveToBottom(context, id);
      }
      this.replaceRules = ReplaceRuleRepository.getAll();
      if (this.route === AppRoute.READER) {
        await this.reloadSelectedChapter();
      }
    } catch (_) {
      this.showUnavailableAction('调整规则顺序失败');
    }
  }

  private async renameReplaceRuleGroup(oldName: string, newName: string): Promise<void> {
    const context = this.getUIContext().getHostContext();
    if (context === undefined) {
      this.showUnavailableAction('无法访问本地规则存储');
      return;
    }
    try {
      await ReplaceRuleRepository.renameGroup(context, oldName, newName);
      this.replaceRules = ReplaceRuleRepository.getAll();
    } catch (error) {
      this.showUnavailableAction(error instanceof Error ? error.message : '重命名分组失败');
    }
  }

  private async removeReplaceRuleGroup(name: string): Promise<void> {
    const context = this.getUIContext().getHostContext();
    if (context === undefined) {
      this.showUnavailableAction('无法访问本地规则存储');
      return;
    }
    try {
      await ReplaceRuleRepository.removeGroup(context, name);
      this.replaceRules = ReplaceRuleRepository.getAll();
    } catch (_) {
      this.showUnavailableAction('删除分组失败');
    }
  }

  private async setReplaceRuleSortMode(mode: string): Promise<void> {
    const context = this.getUIContext().getHostContext();
    if (context === undefined) {
      return;
    }
    try {
      await ReplaceRuleRepository.setSortMode(context, mode);
      this.replaceRuleSortMode = ReplaceRuleRepository.getSortMode();
    } catch (_) {
      this.showUnavailableAction('排序方式保存失败');
    }
  }

  private cacheManagementGroups(): string[] {
    const groups: string[] = [];
    this.books.forEach((book: Book) => {
      (book.groupNames ?? []).forEach((name: string) => {
        const group = name.trim();
        if (group.length > 0 && !groups.includes(group)) { groups.push(group); }
      });
    });
    return groups;
  }

  private async saveReplaceRule(rule: ReplaceRule): Promise<void> {
    const context = this.getUIContext().getHostContext();
    if (context === undefined) {
      this.showUnavailableAction('无法访问本地规则存储');
      return;
    }
    try {
      await ReplaceRuleRepository.save(context, rule);
      this.replaceRules = ReplaceRuleRepository.getAll();
      this.profileSubpage = ProfileRoute.REPLACE_RULES;
      this.showUnavailableAction('替换规则已保存');
    } catch (error) {
      this.showUnavailableAction(error instanceof Error ? error.message : '替换规则保存失败');
    }
  }

  /**
   * 按给定的 id 顺序重排替换规则并落库。
   * 与上游 MoveReplaceRule 一致：只有序号真的变了才写库，写完刷新内存副本。
   */
  private async reorderReplaceRules(orderedIds: number[]): Promise<void> {
    const context = this.getUIContext().getHostContext();
    if (context === undefined) {
      return;
    }
    try {
      const applied: boolean = await ReplaceRuleRepository.reorder(context, orderedIds);
      this.replaceRules = ReplaceRuleRepository.getAll();
      if (applied && this.route === AppRoute.READER) {
        await this.reloadSelectedChapter();
      }
    } catch (_) {
      this.showUnavailableAction('替换规则排序保存失败');
    }
  }

  private async setReplaceRuleEnabled(id: number, enabled: boolean): Promise<void> {
    const context = this.getUIContext().getHostContext();
    if (context === undefined) {
      return;
    }
    try {
      await ReplaceRuleRepository.setEnabled(context, id, enabled);
      this.replaceRules = ReplaceRuleRepository.getAll();
      if (this.route === AppRoute.READER) {
        await this.reloadSelectedChapter();
      }
    } catch (_) {
      this.showUnavailableAction('替换规则状态保存失败');
    }
  }

  private async removeReplaceRule(id: number): Promise<void> {
    const context = this.getUIContext().getHostContext();
    if (context === undefined) {
      return;
    }
    try {
      await ReplaceRuleRepository.remove(context, id);
      this.replaceRules = ReplaceRuleRepository.getAll();
    } catch (_) {
      this.showUnavailableAction('替换规则删除失败');
    }
  }

  /** 批量启用/停用；只反馈真正改变的条数，避免把未变化的算作成功。 */
  private async setReplaceRuleEnabledBatch(ids: number[], enabled: boolean): Promise<void> {
    const context = this.getUIContext().getHostContext();
    if (context === undefined) {
      return;
    }
    try {
      const changed = await ReplaceRuleRepository.setEnabledBatch(context, ids, enabled);
      this.replaceRules = ReplaceRuleRepository.getAll();
      this.showUnavailableAction(changed === 0
        ? `所选规则已经是${enabled ? '启用' : '停用'}状态`
        : `已${enabled ? '启用' : '停用'} ${changed} 条规则`);
      if (this.route === AppRoute.READER) {
        await this.reloadSelectedChapter();
      }
    } catch (_) {
      this.showUnavailableAction('批量修改替换规则状态失败');
    }
  }

  /** 批量删除。 */
  private async removeReplaceRuleBatch(ids: number[]): Promise<void> {
    const context = this.getUIContext().getHostContext();
    if (context === undefined) {
      return;
    }
    try {
      const removed = await ReplaceRuleRepository.removeBatch(context, ids);
      this.replaceRules = ReplaceRuleRepository.getAll();
      this.showUnavailableAction(removed === 0 ? '所选规则已不存在' : `已删除 ${removed} 条规则`);
    } catch (_) {
      this.showUnavailableAction('批量删除替换规则失败');
    }
  }

  /** 批量置顶/置底。 */
  private async moveReplaceRuleBatch(ids: number[], toTop: boolean): Promise<void> {
    const context = this.getUIContext().getHostContext();
    if (context === undefined) {
      return;
    }
    try {
      const moved = await ReplaceRuleRepository.moveBatchToEdge(context, ids, toTop);
      this.replaceRules = ReplaceRuleRepository.getAll();
      this.showUnavailableAction(moved === 0 ? '所选规则已不存在' : `已${toTop ? '置顶' : '置底'} ${moved} 条规则`);
    } catch (_) {
      this.showUnavailableAction('批量调整替换规则顺序失败');
    }
  }

  /**
   * 拖拽排序：把一条规则挪到另一条的位置。
   * 失败时只提示不刷新，避免界面与存储不一致。
   */
  private async reorderReplaceRule(fromId: number, toId: number): Promise<void> {
    const context = this.getUIContext().getHostContext();
    if (context === undefined) {
      return;
    }
    try {
      const moved = await ReplaceRuleRepository.moveRule(context, fromId, toId);
      if (!moved) {
        this.showUnavailableAction('规则顺序未变化');
        return;
      }
      this.replaceRules = ReplaceRuleRepository.getAll();
    } catch (_) {
      this.showUnavailableAction('调整替换规则顺序失败');
    }
  }

  /**
   * 保存一条 TXT 目录规则（新建或编辑）。
   * 保存后刷新列表；已导入书籍的目录不受影响，因为切章用的正则已固定在 Book.tocRule 上。
   */
  private async saveTxtTocRule(rule: TxtTocRule): Promise<void> {
    const context = this.getUIContext().getHostContext();
    if (context === undefined) {
      return;
    }
    try {
      await TxtTocRuleRepository.save(context, rule);
      this.txtTocRules = TxtTocRuleRepository.getAll();
      this.showUnavailableAction('规则已保存');
    } catch (_) {
      this.showUnavailableAction('保存目录规则失败');
    }
  }

  /** 启用/停用一条 TXT 目录规则。 */
  private async setTxtTocRuleEnabled(id: number, enabled: boolean): Promise<void> {
    const context = this.getUIContext().getHostContext();
    if (context === undefined) {
      return;
    }
    try {
      await TxtTocRuleRepository.setEnabled(context, id, enabled);
      this.txtTocRules = TxtTocRuleRepository.getAll();
    } catch (_) {
      this.showUnavailableAction('切换目录规则状态失败');
    }
  }

  /** 删除一条 TXT 目录规则。 */
  private async removeTxtTocRule(id: number): Promise<void> {
    const context = this.getUIContext().getHostContext();
    if (context === undefined) {
      return;
    }
    const exists = this.txtTocRules.some((rule: TxtTocRule) => rule.id === id);
    if (!exists) {
      this.showUnavailableAction('该规则已不存在');
      return;
    }
    try {
      await TxtTocRuleRepository.remove(context, id);
      this.txtTocRules = TxtTocRuleRepository.getAll();
      this.showUnavailableAction('规则已删除');
    } catch (_) {
      this.showUnavailableAction('删除目录规则失败');
    }
  }

  /** 批量删除 TXT 目录规则。 */
  private async removeTxtTocRuleBatch(ids: number[]): Promise<void> {
    const context = this.getUIContext().getHostContext();
    if (context === undefined) {
      return;
    }
    try {
      const removed = await TxtTocRuleRepository.removeBatch(context, ids);
      this.txtTocRules = TxtTocRuleRepository.getAll();
      this.showUnavailableAction(removed === 0 ? '所选规则已不存在' : `已删除 ${removed} 条规则`);
    } catch (_) {
      this.showUnavailableAction('批量删除目录规则失败');
    }
  }

  /** 调整一条 TXT 目录规则的顺序；direction 为 -1 上移、1 下移。 */
  private async moveTxtTocRule(id: number, direction: number): Promise<void> {
    const context = this.getUIContext().getHostContext();
    if (context === undefined) {
      return;
    }
    const fromIndex = this.txtTocRules.findIndex((rule: TxtTocRule) => rule.id === id);
    if (fromIndex < 0) {
      this.showUnavailableAction('该规则已不存在');
      return;
    }
    const toIndex = fromIndex + direction;
    if (toIndex < 0 || toIndex >= this.txtTocRules.length) {
      this.showUnavailableAction('已经在最' + (direction < 0 ? '前' : '后') + '面了');
      return;
    }
    try {
      await TxtTocRuleRepository.moveRule(context, id, toIndex);
      this.txtTocRules = TxtTocRuleRepository.getAll();
    } catch (_) {
      this.showUnavailableAction('调整目录规则顺序失败');
    }
  }

  /**
   * 批量启用/停用 TXT 目录规则。
   * 与单条一致走仓储，提示里报出真正改变的条数，避免「本来就是这状态」被算成本次结果。
   */
  private async setTxtTocRuleEnabledBatch(ids: number[], enabled: boolean): Promise<void> {
    const context = this.getUIContext().getHostContext();
    if (context === undefined) {
      return;
    }
    if (ids.length === 0) {
      this.showUnavailableAction('请先选择规则');
      return;
    }
    try {
      const changed = await TxtTocRuleRepository.setEnabledBatch(context, ids, enabled);
      this.txtTocRules = TxtTocRuleRepository.getAll();
      if (changed === 0) {
        this.showUnavailableAction(`所选规则已经是${enabled ? '启用' : '停用'}状态`);
      } else {
        this.showUnavailableAction(`已${enabled ? '启用' : '停用'} ${changed} 条规则`);
      }
    } catch (_) {
      this.showUnavailableAction('批量切换目录规则状态失败');
    }
  }

  /** 把一条 TXT 目录规则移到最前或最后，对应条目菜单的置顶/置底。 */
  private async moveTxtTocRuleToEdge(id: number, toTop: boolean): Promise<void> {
    const context = this.getUIContext().getHostContext();
    if (context === undefined) {
      return;
    }
    try {
      const moved = await TxtTocRuleRepository.moveToEdge(context, id, toTop);
      if (!moved) {
        this.showUnavailableAction('该规则已不存在');
        return;
      }
      this.txtTocRules = TxtTocRuleRepository.getAll();
    } catch (_) {
      this.showUnavailableAction('调整目录规则顺序失败');
    }
  }

  /** 导入内置目录规则库，跳过已存在的同名规则。 */
  private async importBuiltinTxtTocRules(): Promise<void> {
    const context = this.getUIContext().getHostContext();
    if (context === undefined) {
      return;
    }
    try {
      const builtin = TxtTocRuleRepository.loadBuiltinRules(context);
      if (builtin.length === 0) {
        this.showUnavailableAction('内置规则库为空');
        return;
      }
      const outcome = await TxtTocRuleRepository.importRules(context, builtin);
      this.txtTocRules = TxtTocRuleRepository.getAll();
      this.showUnavailableAction(outcome.added === 0 && outcome.updated === 0
        ? '内置规则已全部存在' : `已导入 ${outcome.added} 条、更新 ${outcome.updated} 条内置规则`);
    } catch (_) {
      this.showUnavailableAction('导入内置目录规则失败');
    }
  }

  /**
   * 从用户选择的文件导入 TXT 目录规则。
   * 用户取消选择时不提示，与替换规则的导入口径一致。
   */
  private async importTxtTocRules(): Promise<void> {
    const context = this.getUIContext().getHostContext();
    if (context === undefined) {
      return;
    }
    let content: string;
    try {
      content = await TxtTocRuleRepository.pickImportFile(context);
    } catch (_) {
      this.showUnavailableAction('读取规则文件失败');
      return;
    }
    if (content.length === 0) {
      return;
    }
    const parsed = TxtTocRuleImporter.parse(content);
    if (parsed.rules.length === 0) {
      this.showUnavailableAction(parsed.skipped > 0 ? '规则格式不正确，未导入任何数据' : '没有可导入的规则');
      return;
    }
    try {
      const outcome = await TxtTocRuleRepository.importRules(context, parsed.rules);
      this.txtTocRules = TxtTocRuleRepository.getAll();
      const skipped = parsed.skipped > 0 ? `，跳过 ${parsed.skipped} 条无效规则` : '';
      this.showUnavailableAction(`新增 ${outcome.added} 条，更新 ${outcome.updated} 条${skipped}`);
    } catch (_) {
      this.showUnavailableAction('TXT 目录规则导入失败');
    }
  }

  /** 导出 TXT 目录规则到用户选择的文件。 */
  private async exportTxtTocRules(rules: TxtTocRule[]): Promise<void> {
    const context = this.getUIContext().getHostContext();
    if (context === undefined) {
      return;
    }
    if (rules.length === 0) {
      this.showUnavailableAction('没有可导出的目录规则');
      return;
    }
    try {
      const saved = await TxtTocRuleRepository.saveExportFile(context, TxtTocRuleRepository.exportRules(rules));
      this.showUnavailableAction(saved ? `已导出 ${rules.length} 条目录规则` : '未选择保存位置');
    } catch (_) {
      this.showUnavailableAction('导出目录规则失败');
    }
  }

  /**
   * 导入替换规则。
   * source 为 'file' 时弹出文件选择器读取文本；其余情况直接解析传入的 text。
   * 解析失败与部分跳过都如实反馈，不把未导入的条目算作成功。
   */
  private async importReplaceRules(text: string, source: string): Promise<void> {
    const context = this.getUIContext().getHostContext();
    if (context === undefined) {
      return;
    }
    let content = text;
    if (source === 'file') {
      try {
        content = await ReplaceRuleRepository.pickImportFile(context);
      } catch (_) {
        this.showUnavailableAction('读取规则文件失败');
        return;
      }
      if (content.length === 0) {
        return;
      }
    }
    const parsed = ReplaceRuleImporter.parse(content);
    if (parsed.rules.length === 0) {
      this.showUnavailableAction(parsed.skipped > 0 ? '规则格式不正确，未导入任何数据' : '没有可导入的规则');
      return;
    }
    try {
      const outcome = await ReplaceRuleRepository.importRules(context, parsed.rules);
      this.replaceRules = ReplaceRuleRepository.getAll();
      const skipped = parsed.skipped > 0 ? `，跳过 ${parsed.skipped} 条` : '';
      this.showUnavailableAction(`新增 ${outcome.added} 条，更新 ${outcome.updated} 条${skipped}`);
    } catch (_) {
      this.showUnavailableAction('替换规则导入失败');
    }
  }

  /** 导出替换规则到用户选择的文件。 */
  private async exportReplaceRules(rules: ReplaceRule[]): Promise<void> {
    const context = this.getUIContext().getHostContext();
    if (context === undefined) {
      return;
    }
    if (rules.length === 0) {
      this.showUnavailableAction('没有可导出的替换规则');
      return;
    }
    try {
      const saved = await ReplaceRuleRepository.saveExportFile(context, ReplaceRuleRepository.exportRules(rules));
      this.showUnavailableAction(saved ? `已导出 ${rules.length} 条规则` : '未选择保存位置');
    } catch (_) {
      this.showUnavailableAction('替换规则导出失败');
    }
  }

  /**
   * 导出当前书的书签。
   * 与上游 exportCurrentBookBookmarks 同口径：无书签时明确提示不导出，
   * 用户取消保存对话框时也不谎报成功。
   */
  private async exportReaderBookmarks(isMarkdown: boolean): Promise<void> {
    const context = this.getUIContext().getHostContext();
    if (context === undefined) { return; }
    const bookmarks = this.readerBookmarks.filter((bookmark: ReaderBookmark) =>
      bookmark.bookId === this.selectedBook.id);
    if (bookmarks.length === 0) {
      this.showUnavailableAction('没有可导出的书签');
      return;
    }
    const fileName = ReaderBookmarkExporter.buildFileName(this.selectedBook.title, isMarkdown);
    const content = isMarkdown
      ? ReaderBookmarkExporter.toMarkdown(this.selectedBook.title, this.selectedBook.author, bookmarks)
      : ReaderBookmarkExporter.toJson(bookmarks);
    try {
      const saved = await ReaderBookmarkExporter.saveToFile(context, content, fileName, isMarkdown);
      this.showUnavailableAction(saved ? `已导出 ${bookmarks.length} 条书签` : '未选择保存位置');
    } catch (_) {
      this.showUnavailableAction('书签导出失败');
    }
  }

  /**
   * 从「所有书签」页按 bookKey 导出某一本书的书签与笔记。
   * 上游 AllBookmarkViewModel.exportBook 与阅读页目录导出是两套格式：
   * 这里走 { bookmarks, notes } 双数组与两小节 Markdown，文件名带 -notes- 前缀。
   */
  private async exportBookmarksByKey(bookKey: string, isMarkdown: boolean): Promise<void> {
    const context = this.getUIContext().getHostContext();
    if (context === undefined) { return; }
    const bookmarks = this.readerBookmarks.filter((bookmark: ReaderBookmark) => bookmark.bookId === bookKey);
    const markings = this.readerMarkings.filter((marking: ReaderMarking) => marking.bookId === bookKey);
    if (bookmarks.length === 0 && markings.length === 0) {
      this.showUnavailableAction('没有可导出的书签');
      return;
    }
    const first = bookmarks[0];
    const firstMarking = markings[0];
    const bookName = first !== undefined ? first.bookName : (firstMarking !== undefined ? firstMarking.bookName : '');
    const author = first !== undefined ? first.bookAuthor
      : (firstMarking !== undefined ? firstMarking.bookAuthor : '');
    const fileName = ReaderBookmarkExporter.buildAllBookmarksFileName(bookName, isMarkdown);
    const content = isMarkdown
      ? ReaderBookmarkExporter.toAllBookmarksMarkdown(bookName, author, bookmarks, markings)
      : ReaderBookmarkExporter.toAllBookmarksJson(bookmarks, markings);
    try {
      const saved = await ReaderBookmarkExporter.saveToFile(context, content, fileName, isMarkdown);
      this.showUnavailableAction(saved
        ? `已导出 ${bookmarks.length} 条书签、${markings.length} 条笔记`
        : '未选择保存位置');
    } catch (_) {
      this.showUnavailableAction('书签导出失败');
    }
  }

  private async restoreHomeDashboardSettings(context: Context): Promise<void> {
    this.homeDashboardSections = await HomeDashboardSettingsRepository.load(context);
  }

  private async setHomeDashboardSection(section: HomeDashboardSection, visible: boolean): Promise<void> {
    if (visible && !this.homeDashboardSections.includes(section)) {
      this.homeDashboardSections = [...this.homeDashboardSections, section];
    } else if (!visible) {
      this.homeDashboardSections = this.homeDashboardSections.filter((item: HomeDashboardSection) => item !== section);
    }
    const context = this.getUIContext().getHostContext();
    if (context !== undefined) {
      try {
        await HomeDashboardSettingsRepository.save(context, this.homeDashboardSections);
      } catch (_) {
        this.showUnavailableAction('首页组件设置保存失败');
      }
    }
  }

  private async restoreReaderBookmarks(context: Context): Promise<void> {
    this.readerBookmarks = await ReaderBookmarkRepository.load(context);
  }

  private async restoreReaderMarkings(context: Context): Promise<void> {
    this.readerMarkings = await ReaderMarkingRepository.load(context);
  }

  private requestCreateReaderMarking(chapterPosition: number, endPosition: number, selectedText: string): void {
    if (!this.selectedBook.isLocal || this.selectedBook.contentPath === undefined ||
      BookRepository.isBodyMissing(this.selectedBook)) {
      this.showUnavailableAction('划线与笔记仅支持已有本地正文的书籍');
      return;
    }
    const chapterIndex = Math.max(0, this.selectedBook.chapterIndex ??
      BookRepository.cachedChapterTitles(this.selectedBook).indexOf(this.selectedChapter));
    const semanticContent = LocalTextSemantics.fromRawBody(this.readerContent);
    const start = Math.max(0, Math.min(semanticContent.length, Math.trunc(chapterPosition)));
    const end = Math.max(start, Math.min(semanticContent.length, Math.trunc(endPosition)));
    const text = selectedText.trim();
    if (end <= start || text.length === 0) {
      this.showUnavailableAction('选区为空，无法创建标记');
      return;
    }
    const duplicate = this.readerMarkings.find((marking: ReaderMarking) =>
      marking.bookId === this.selectedBook.id && marking.chapterIndex === chapterIndex &&
      marking.chapterPosition === start && marking.selectedText === text);
    if (duplicate !== undefined) {
      this.markingEditor = duplicate;
      this.markingEditorIsNew = false;
      return;
    }
    const now = Date.now();
    const contextRadius = 36;
    this.markingEditor = {
      id: `${this.selectedBook.id}-mark-${now.toString()}`,
      bookId: this.selectedBook.id,
      bookName: this.selectedBook.title,
      bookAuthor: this.selectedBook.author,
      bookUrl: this.selectedBook.androidOriginalPath ?? this.selectedBook.contentPath ?? this.selectedBook.id,
      chapterIndex: chapterIndex,
      chapterName: this.selectedChapter,
      chapterPosition: start,
      endPosition: end,
      selectedText: text,
      contextBefore: semanticContent.substring(Math.max(0, start - contextRadius), start),
      contextAfter: semanticContent.substring(end, Math.min(semanticContent.length, end + contextRadius)),
      effect: 'solid',
      color: '#63C37D',
      note: '',
      enabled: true,
      createdAt: now,
      updatedAt: now
    };
    this.markingEditorIsNew = true;
  }

  private editReaderMarking(markingId: string): void {
    const record = this.readerMarkings.find((marking: ReaderMarking) => marking.id === markingId);
    if (record === undefined) { return; }
    this.markingEditor = record;
    this.markingEditorIsNew = false;
  }

  private async saveReaderMarking(effect: ReaderMarkingEffect, color: string, note: string): Promise<void> {
    const draft = this.markingEditor;
    if (draft === undefined) { return; }
    const saved: ReaderMarking = {
      id: draft.id,
      bookId: draft.bookId,
      bookName: draft.bookName,
      bookAuthor: draft.bookAuthor,
      bookUrl: draft.bookUrl,
      chapterIndex: draft.chapterIndex,
      chapterName: draft.chapterName,
      chapterPosition: draft.chapterPosition,
      endPosition: draft.endPosition,
      selectedText: draft.selectedText,
      contextBefore: draft.contextBefore,
      contextAfter: draft.contextAfter,
      effect: effect,
      color: color,
      note: note,
      enabled: true,
      createdAt: draft.createdAt > 0 ? draft.createdAt : Date.now(),
      updatedAt: Date.now()
    };
    const next = this.readerMarkings.filter((marking: ReaderMarking) => marking.id !== saved.id);
    next.unshift(saved);
    const context = this.getUIContext().getHostContext();
    if (context === undefined) {
      this.showUnavailableAction('无法访问本地标记存储');
      return;
    }
    try {
      await ReaderMarkingRepository.save(context, next);
      this.readerMarkings = next;
      // 对齐上游 ReadBookViewModel.kt:1519：每次应用样式都把它记成「上次用的样式」，
      // 供下一次新建标记预选。存 TextProcessStyle 的 JSON，与上游同形态。
      this.setReaderLastMarkingStyle(ReaderMarkingRepository.encodeStyle(effect, color));
      this.markingEditor = undefined;
      this.showUnavailableAction('标记已保存');
    } catch (_) {
      this.showUnavailableAction('标记保存失败，请重试');
    }
  }

  private async deleteReaderMarking(): Promise<void> {
    const draft = this.markingEditor;
    if (draft === undefined) { return; }
    const next = this.readerMarkings.filter((marking: ReaderMarking) => marking.id !== draft.id);
    const context = this.getUIContext().getHostContext();
    if (context === undefined) {
      this.showUnavailableAction('无法访问本地标记存储');
      return;
    }
    try {
      await ReaderMarkingRepository.save(context, next);
      this.readerMarkings = next;
      this.markingEditor = undefined;
      this.showUnavailableAction('标记已删除');
    } catch (_) {
      this.showUnavailableAction('标记删除失败，请重试');
    }
  }

  private requestAddReaderBookmark(chapterPosition: number, pageText: string): void {
    const chapterTitles: string[] = BookRepository.cachedChapterTitles(this.selectedBook);
    const chapterIndex = Math.max(0, this.selectedBook.chapterIndex ?? chapterTitles.indexOf(this.selectedChapter));
    const record: ReaderBookmark = {
      id: this.selectedBook.id + '-' + Date.now().toString(),
      bookId: this.selectedBook.id,
      bookName: this.selectedBook.title,
      bookAuthor: this.selectedBook.author,
      bookUrl: this.selectedBook.androidOriginalPath ?? this.selectedBook.contentPath ?? this.selectedBook.id,
      chapterIndex: chapterIndex,
      chapterName: this.selectedChapter,
      chapterPosition: Math.max(0, Math.trunc(chapterPosition)),
      bookText: pageText,
      content: '',
      createdAt: Date.now()
    };
    this.bookmarkEditor = record;
    this.bookmarkEditorIsNew = true;
  }

  /**
   * 目录页多选「加书签」：给每个选中章各加一条章首书签。
   *
   * 对齐上游 `TocIntent.AddBookmarksForSelected`（`ReaderBookSheet.kt:678-740`）。
   */
  private async addReaderBookmarksForChapters(chapterIndexes: number[]): Promise<void> {
    if (chapterIndexes.length === 0) { return; }
    const context = this.getUIContext().getHostContext();
    if (context === undefined) {
      this.showUnavailableAction('无法访问书签存储');
      return;
    }
    const titles: string[] = BookRepository.cachedChapterTitles(this.selectedBook);
    const bookUrl = this.selectedBook.androidOriginalPath ?? this.selectedBook.contentPath ?? this.selectedBook.id;
    const now = Date.now();
    const added: ReaderBookmark[] = [];
    for (let i = 0; i < chapterIndexes.length; i++) {
      const chapterIndex = chapterIndexes[i];
      if (chapterIndex === undefined) { continue; }
      added.push({
        id: `${this.selectedBook.id}-${now + i}`,
        bookId: this.selectedBook.id,
        bookName: this.selectedBook.title,
        bookAuthor: this.selectedBook.author,
        bookUrl: bookUrl,
        chapterIndex: chapterIndex,
        chapterName: titles[chapterIndex] ?? '',
        chapterPosition: 0,
        bookText: '',
        content: '',
        createdAt: now + i
      });
    }
    const nextBookmarks = added.concat(this.readerBookmarks);
    try {
      await ReaderBookmarkRepository.save(context, nextBookmarks);
      this.readerBookmarks = nextBookmarks;
      this.showUnavailableAction(`已为 ${added.length} 章添加书签`);
    } catch (_) {
      this.showUnavailableAction('书签保存失败，请重试');
    }
  }

  private toggleReaderBookmarkForPage(startPosition: number, endPosition: number, pageText: string): Promise<void> {    const operation = this.readerBookmarkToggleQueue.then(async (): Promise<void> => {
      if (!this.selectedBook.isLocal || this.selectedBook.contentPath === undefined) { return; }
      const chapterTitles: string[] = BookRepository.cachedChapterTitles(this.selectedBook);
      const chapterIndex = Math.max(0, this.selectedBook.chapterIndex ??
        chapterTitles.indexOf(this.selectedChapter));
      const rangeEnd = Math.max(startPosition + 1, endPosition);
      const existing: ReaderBookmark[] = this.readerBookmarks.filter((bookmark: ReaderBookmark) =>
        bookmark.bookId === this.selectedBook.id && bookmark.chapterIndex === chapterIndex &&
        bookmark.chapterPosition >= startPosition && bookmark.chapterPosition < rangeEnd);
      let nearest: ReaderBookmark | undefined = undefined;
      for (let index = 0; index < existing.length; index++) {
        const candidate = existing[index];
        if (candidate !== undefined && (nearest === undefined ||
          Math.abs(candidate.chapterPosition - startPosition) <
            Math.abs(nearest.chapterPosition - startPosition))) {
          nearest = candidate;
        }
      }
      let nextBookmarks: ReaderBookmark[];
      let statusMessage: string;
      if (nearest !== undefined) {
        nextBookmarks = this.readerBookmarks.filter((bookmark: ReaderBookmark) => bookmark.id !== nearest?.id);
        statusMessage = '已取消当前页书签';
      } else {
        const now = Date.now();
        const record: ReaderBookmark = {
          id: this.selectedBook.id + '-' + now.toString(),
          bookId: this.selectedBook.id,
          bookName: this.selectedBook.title,
          bookAuthor: this.selectedBook.author,
          bookUrl: this.selectedBook.androidOriginalPath ?? this.selectedBook.contentPath ?? this.selectedBook.id,
          chapterIndex: chapterIndex,
          chapterName: this.selectedChapter,
          chapterPosition: Math.max(0, Math.trunc(startPosition)),
          bookText: pageText,
          content: '',
          createdAt: now
        };
        nextBookmarks = [record, ...this.readerBookmarks];
        statusMessage = '已添加当前页书签';
      }
      const context = this.getUIContext().getHostContext();
      if (context === undefined) {
        this.showUnavailableAction('无法访问书签存储');
        return;
      }
      try {
        await ReaderBookmarkRepository.save(context, nextBookmarks);
        this.readerBookmarks = nextBookmarks;
        this.showUnavailableAction(statusMessage);
      } catch (_) {
        this.showUnavailableAction('书签保存失败，请重试');
      }
    });
    this.readerBookmarkToggleQueue = operation.catch(() => {});
    return operation;
  }
  private editReaderBookmark(bookmarkId: string): void {
    const record = this.readerBookmarks.find((bookmark: ReaderBookmark) => bookmark.id === bookmarkId);
    if (record === undefined) { return; }
    this.bookmarkEditor = record;
    this.bookmarkEditorIsNew = false;
  }

  private async saveReaderBookmarkNote(note: string, bookText: string): Promise<void> {
    const draft = this.bookmarkEditor;
    if (draft === undefined) { return; }
    const saved: ReaderBookmark = {
      id: draft.id,
      bookId: draft.bookId,
      bookName: draft.bookName,
      bookAuthor: draft.bookAuthor,
      bookUrl: draft.bookUrl,
      chapterIndex: draft.chapterIndex,
      chapterName: draft.chapterName,
      chapterPosition: draft.chapterPosition,
      bookText: bookText,
      content: note,
      createdAt: draft.createdAt
    };
    const next = this.readerBookmarks.filter((bookmark: ReaderBookmark) => bookmark.id !== saved.id);
    next.unshift(saved);
    const context = this.getUIContext().getHostContext();
    if (context === undefined) {
      this.showUnavailableAction('无法保存书签');
      return;
    }
    try {
      await ReaderBookmarkRepository.save(context, next);
      this.readerBookmarks = next;
      this.bookmarkEditor = undefined;
    } catch (_) {
      this.showUnavailableAction('书签保存失败，请重试');
    }
  }

  /**
   * 删除书签前先弹二次确认，对齐上游 `BookmarkEditSheet.kt:77-85`：
   * 标题「删除书签？」、正文「确定要删除这条书签吗？」，按钮「取消」/「删除」。
   * 划线/笔记的删除上游没有确认框（`MarkingSheet.kt:129` 直接删除），故不在此列。
   */
  private confirmDeleteReaderBookmark(): void {
    if (this.bookmarkEditor === undefined) { return; }
    this.getUIContext().showAlertDialog({
      title: '删除书签？',
      message: '确定要删除这条书签吗？',
      autoCancel: true,
      primaryButton: {
        value: '取消',
        action: () => {}
      },
      secondaryButton: {
        value: '删除',
        action: () => { this.deleteReaderBookmark(); }
      }
    });
  }

  private async deleteReaderBookmark(): Promise<void> {
    const draft = this.bookmarkEditor;
    if (draft === undefined) { return; }
    const next = this.readerBookmarks.filter((bookmark: ReaderBookmark) => bookmark.id !== draft.id);
    const context = this.getUIContext().getHostContext();
    if (context === undefined) {
      this.showUnavailableAction('无法删除书签');
      return;
    }
    try {
      await ReaderBookmarkRepository.save(context, next);
      this.readerBookmarks = next;
      this.bookmarkEditor = undefined;
    } catch (_) {
      this.showUnavailableAction('书签删除失败，请重试');
    }
  }

  /**
   * 书签/笔记跳转的公共主体：读章节、算位置、落盘阅读进度、切到阅读页。
   * 中途失败已自行提示，返回 false；成功返回 true，由调用方清理各自的编辑态。
   */
  private async jumpToReaderTarget(
    targetBook: Book,
    chapterIndex: number,
    chapterTitle: string,
    chapterPosition: number,
    errorPrefix: string
  ): Promise<boolean> {
    const chapterTitles: string[] = BookRepository.cachedChapterTitles(targetBook);
    let content: string;
    try {
      content = await BookRepository.readChapter(targetBook, chapterTitle, chapterIndex);
      this.replaceRules = ReplaceRuleRepository.getAll();
    } catch (_) {
      this.showUnavailableAction(`无法读取${errorPrefix}对应章节`);
      return false;
    }
    const semanticLength = LocalTextSemantics.fromRawBody(content).length;
    const position = Math.max(0, Math.min(semanticLength, Math.trunc(chapterPosition)));
    const chapterProgress = semanticLength > 0 ? position / semanticLength * 100 : 0;
    const chapterCount = Math.max(1, chapterTitles.length);
    const updatedBook: Book = BookRepository.copyBook(targetBook);
    updatedBook.chapterIndex = chapterIndex;
    updatedBook.chapterProgress = chapterProgress;
    updatedBook.lastChapter = chapterTitle;
    updatedBook.progress = (chapterIndex + chapterProgress / 100) / chapterCount * 100;
    updatedBook.androidCharacterPosition = position;
    const updatedBooks = this.books.map((book: Book) => book.id === updatedBook.id ? updatedBook : book);
    const context = this.getUIContext().getHostContext();
    if (context === undefined) {
      this.showUnavailableAction(`无法访问本地书架，${errorPrefix}位置未保存`);
      return false;
    }
    try {
      await BookRepository.saveImportedBooks(context,
        updatedBooks.filter((book: Book) => BookRepository.isPersistableBook(book)));
    } catch (_) {
      this.showUnavailableAction(`${errorPrefix}位置保存失败，已保留原阅读位置`);
      return false;
    }
    this.selectedBook = updatedBook;
    this.books = updatedBooks;
    this.selectedChapter = chapterTitle;
    this.readerContent = content;
    this.readerBookmarkTargetPosition = position;
    this.readerBookmarkTargetRevision++;
    this.readerStartAtChapterBeginning = false;
    return true;
  }

  /**
   * 当前书的源指纹，与新建书签/标记时写入 `bookUrl` 的口径保持一致。
   */
  private bookmarkTargetFingerprint(book: Book): string {
    return book.androidOriginalPath ?? book.contentPath ?? book.id;
  }

  /**
   * 弹「位置可能已偏移」确认框，返回用户是否仍要跳转。
   * 文案与按钮对齐上游 `bookmark_target_*` 字符串，取消时原地不动。
   */
  private askJumpAnyway(verdict: BookmarkTargetVerdict): Promise<boolean> {
    const message = verdict === 'sourceChanged'
      ? '这条书签/笔记是在其他书源下创建的，位置可能已经偏移。仍要跳转吗？'
      : '目标章节标题已变化，位置可能已经偏移。仍要跳转吗？';
    return new Promise<boolean>((resolve: (value: boolean) => void) => {
      this.getUIContext().showAlertDialog({
        title: '位置可能已偏移',
        message: message,
        autoCancel: false,
        primaryButton: {
          value: '取消',
          action: () => resolve(false)
        },
        secondaryButton: {
          value: '仍跳转',
          action: () => resolve(true)
        }
      });
    });
  }

  /** 跳转成功后收尾：关掉对应编辑面板并切到阅读页。 */
  private finishTargetJump(isMarking: boolean): void {
    if (isMarking) {
      this.markingEditor = undefined;
    } else {
      this.bookmarkEditor = undefined;
    }
    this.route = AppRoute.READER;
  }

  /**
   * 校验没过时按原存储坐标弹框确认，确认后才跳。
   * 与上游 `confirmJump` 一致：用的是创建时的 chapterIndex/chapterPosition，不做猜测。
   */
  private async offerStoredTargetJump(targetBook: Book, target: PendingBookmarkTarget): Promise<void> {
    const kind = target.isMarking ? '笔记' : '书签';
    const chapterTitle = BookRepository.cachedChapterTitles(targetBook)[target.chapterIndex];
    if (chapterTitle === undefined) {
      this.showUnavailableAction(`${kind}章节不在当前目录中`);
      return;
    }
    const confirmed = await this.askJumpAnyway(target.verdict);
    if (!confirmed) { return; }
    const jumped = await this.jumpToReaderTarget(
      targetBook, target.chapterIndex, chapterTitle, target.chapterPosition, kind);
    if (!jumped) { return; }
    this.finishTargetJump(target.isMarking);
  }

  private async openReaderBookmark(bookmarkId: string): Promise<void> {
    const bookmark = this.readerBookmarks.find((record: ReaderBookmark) => record.id === bookmarkId);
    if (bookmark === undefined) { return; }
    const targetBook = this.books.find((book: Book) => book.id === bookmark.bookId);
    if (targetBook === undefined || targetBook.contentPath === undefined) {
      this.showUnavailableAction('这条书签对应的本地正文不可用');
      return;
    }
    // 严格对齐上游 navigateToBookmark：先校验，通过直接跳；不通过一律交给用户确认（书签不做重定位）。
    const verdict = ReaderBookmarkTarget.verify(
      this.bookmarkTargetFingerprint(targetBook),
      BookRepository.cachedChapterTitles(targetBook)[bookmark.chapterIndex],
      bookmark.bookUrl,
      bookmark.chapterName
    );
    const target: PendingBookmarkTarget = {
      bookId: bookmark.bookId,
      chapterIndex: bookmark.chapterIndex,
      chapterPosition: bookmark.chapterPosition,
      verdict: verdict,
      isMarking: false
    };
    if (verdict !== 'match') {
      await this.offerStoredTargetJump(targetBook, target);
      return;
    }
    const chapterTitle = BookRepository.cachedChapterTitles(targetBook)[bookmark.chapterIndex];
    if (chapterTitle === undefined) {
      this.showUnavailableAction('书签章节不在当前目录中');
      return;
    }
    const jumped = await this.jumpToReaderTarget(
      targetBook, bookmark.chapterIndex, chapterTitle, bookmark.chapterPosition, '书签');
    if (!jumped) { return; }
    this.finishTargetJump(false);
  }

  /**
   * 换源/目录重排后在当前目录里按锚点重新找位置，对齐上游 `relocateMarking`。
   * 候选章节是「原索引这一章」和「标题同名的章」，只读本地正文，不联网。
   * 返回 undefined 表示没有唯一最优匹配，交给用户确认。
   */
  private async relocateMarkingTarget(
    targetBook: Book,
    storedChapterName: string,
    anchorChapterIndex: number,
    anchor: MarkingRelocateAnchor
  ): Promise<MarkingRelocateTarget | undefined> {
    const chapterTitles: string[] = BookRepository.cachedChapterTitles(targetBook);
    const candidates: MarkingRelocateCandidate[] = [];
    for (let index = 0; index < chapterTitles.length; index++) {
      const title = chapterTitles[index];
      if (title === undefined) { continue; }
      if (index !== anchorChapterIndex && (storedChapterName.trim().length === 0 || title !== storedChapterName)) {
        continue;
      }
      try {
        const raw = await BookRepository.readChapter(targetBook, title, index);
        candidates.push({ chapterIndex: index, content: LocalTextSemantics.fromRawBody(raw) });
      } catch (_) {
        // 单章读不出来就跳过，不因为候选缺失就放弃整次重定位。
        continue;
      }
    }
    return ReaderBookmarkTarget.locate(anchor, candidates);
  }

  private async openReaderMarking(markingId: string): Promise<void> {
    const marking = this.readerMarkings.find((record: ReaderMarking) => record.id === markingId);
    if (marking === undefined) { return; }
    const targetBook = this.books.find((book: Book) => book.id === marking.bookId);
    if (targetBook === undefined || targetBook.contentPath === undefined ||
      BookRepository.isBodyMissing(targetBook)) {
      this.showUnavailableAction('这条笔记对应的本地正文不可用');
      return;
    }
    const anchor: MarkingRelocateAnchor = {
      selectedText: marking.selectedText,
      contextBefore: marking.contextBefore,
      contextAfter: marking.contextAfter
    };
    // 严格对齐上游 navigateToMarking：校验通过直接跳，不通过先试重定位，再退到确认框。
    const verdict = ReaderBookmarkTarget.verify(
      this.bookmarkTargetFingerprint(targetBook),
      BookRepository.cachedChapterTitles(targetBook)[marking.chapterIndex],
      marking.bookUrl,
      marking.chapterName
    );
    let chapterIndex = marking.chapterIndex;
    let chapterPosition = marking.chapterPosition;
    if (verdict !== 'match') {
      const relocated = await this.relocateMarkingTarget(
        targetBook, marking.chapterName, marking.chapterIndex, anchor);
      if (relocated !== undefined) {
        chapterIndex = relocated.chapterIndex;
        chapterPosition = relocated.chapterPosition;
      } else {
        await this.offerStoredTargetJump(targetBook, {
          bookId: marking.bookId,
          chapterIndex: marking.chapterIndex,
          chapterPosition: marking.chapterPosition,
          verdict: verdict,
          isMarking: true
        });
        return;
      }
    }
    const chapterTitle = BookRepository.cachedChapterTitles(targetBook)[chapterIndex];
    if (chapterTitle === undefined) {
      this.showUnavailableAction('笔记章节不在当前目录中');
      return;
    }
    const jumped = await this.jumpToReaderTarget(
      targetBook, chapterIndex, chapterTitle, chapterPosition, '笔记');
    if (!jumped) { return; }
    this.finishTargetJump(true);
  }

  private async openReaderSearchResult(chapterIndex: number, chapterPosition: number,
    items: ReaderSearchNavItem[], index: number): Promise<void> {
    const targetBook = this.selectedBook;
    // 结果集随跳转一起带进阅读页：搜索页随后会被卸载，正文里的
    // 「上一个/下一个」与底部结果条只能靠这份快照（上游 ReadBookState 常驻）。
    this.readerSearchNavItems = items;
    this.readerSearchNavIndex = index;
    if (targetBook.contentPath === undefined) {
      this.showUnavailableAction('这本书没有可搜索的本地正文');
      return;
    }
    const chapterTitles: string[] = BookRepository.cachedChapterTitles(targetBook);
    const chapterTitle = chapterTitles[chapterIndex];
    if (chapterTitle === undefined) {
      this.showUnavailableAction('搜索结果章节已不在当前目录中');
      return;
    }
    let content: string;
    try {
      content = await BookRepository.readChapter(targetBook, chapterTitle, chapterIndex);
      this.replaceRules = ReplaceRuleRepository.getAll();
    } catch (_) {
      this.showUnavailableAction('无法读取搜索结果对应章节');
      return;
    }
    const semanticDocument = LocalTextSemantics.parse(content, this.readerParagraphIndent);
    const position = Math.max(0, Math.min(semanticDocument.content.length, chapterPosition));
    const androidPosition = LocalTextSemantics.toSourcePosition(semanticDocument, position);
    const chapterProgress = semanticDocument.sourceLength > 0
      ? androidPosition / semanticDocument.sourceLength * 100 : 0;
    const chapterCount = Math.max(1, chapterTitles.length);
    const updatedBook: Book = BookRepository.copyBook(targetBook);
    updatedBook.chapterIndex = chapterIndex;
    updatedBook.chapterProgress = chapterProgress;
    updatedBook.lastChapter = chapterTitle;
    updatedBook.progress = (chapterIndex + chapterProgress / 100) / chapterCount * 100;
    updatedBook.androidCharacterPosition = androidPosition;
    const updatedBooks = this.books.map((book: Book) => book.id === updatedBook.id ? updatedBook : book);
    const context = this.getUIContext().getHostContext();
    if (context === undefined) {
      this.showUnavailableAction('无法访问本地书架，搜索结果位置未保存');
      return;
    }
    try {
      await BookRepository.saveImportedBooks(context,
        updatedBooks.filter((book: Book) => BookRepository.isPersistableBook(book)));
    } catch (_) {
      this.showUnavailableAction('搜索结果位置保存失败，已保留原阅读位置');
      return;
    }
    this.selectedBook = updatedBook;
    this.books = updatedBooks;
    this.selectedChapter = chapterTitle;
    this.readerContent = content;
    this.readerBookmarkTargetPosition = position;
    this.readerBookmarkTargetRevision++;
    this.readerStartAtChapterBeginning = false;
    this.route = AppRoute.READER;
  }

  /**
   * 「所有书签」页的书籍汇总。
   * 上游 AllBookmarkViewModel 的 books 由书签与笔记共同聚合，两侧都计入；
   * 本地按 bookId 归并，因此同一本书的书签数与笔记数分别累计。
   */
  /**
   * 跳到结果集里的另一个结果。上游 `NavigateSearchResultByOffset`：
   * 只换定位点，不换章节时也走同一条定位通路。
   */
  private async openReaderSearchNavItem(index: number): Promise<void> {
    const item = this.readerSearchNavItems[index];
    if (item === undefined) { return; }
    this.readerSearchNavIndex = index;
    const jumped = await this.jumpToReaderTarget(
      this.selectedBook, item.chapterIndex, item.chapterTitle, item.position, '搜索结果');
    if (jumped) {
      this.route = AppRoute.READER;
    }
  }

  /** 收起搜索结果条（上游 `HideSearchMenu`）；结果集留着，下次搜索会整体替换。 */
  private closeReaderSearchNav(): void {
    this.readerSearchNavItems = [];
    this.readerSearchNavIndex = -1;
  }

  private getBookmarkBookSummaries(): BookmarkBookSummary[] {
    const summaries: BookmarkBookSummary[] = [];
    for (let index = 0; index < this.readerBookmarks.length; index++) {
      const bookmark = this.readerBookmarks[index];
      if (bookmark === undefined) { continue; }
      const existingIndex = summaries.findIndex((summary: BookmarkBookSummary) => summary.key === bookmark.bookId);
      if (existingIndex < 0) {
        summaries.push({
          key: bookmark.bookId, title: bookmark.bookName, author: bookmark.bookAuthor,
          bookmarkCount: 1, noteCount: 0, sourceUrl: bookmark.bookUrl,
          coverUri: '', coverColor: '', coverMark: ''
        });
      } else {
        const current = summaries[existingIndex];
        if (current !== undefined) {
          summaries[existingIndex] = {
            key: current.key, title: current.title, author: current.author,
            bookmarkCount: current.bookmarkCount + 1, noteCount: current.noteCount, sourceUrl: current.sourceUrl,
            coverUri: current.coverUri, coverColor: current.coverColor, coverMark: current.coverMark
          };
        }
      }
    }
    for (let index = 0; index < this.readerMarkings.length; index++) {
      const marking = this.readerMarkings[index];
      if (marking === undefined) { continue; }
      const existingIndex = summaries.findIndex((summary: BookmarkBookSummary) => summary.key === marking.bookId);
      if (existingIndex < 0) {
        summaries.push({
          key: marking.bookId, title: marking.bookName, author: marking.bookAuthor,
          bookmarkCount: 0, noteCount: 1, sourceUrl: marking.bookUrl,
          coverUri: '', coverColor: '', coverMark: ''
        });
      } else {
        const current = summaries[existingIndex];
        if (current !== undefined) {
          summaries[existingIndex] = {
            key: current.key, title: current.title, author: current.author,
            bookmarkCount: current.bookmarkCount, noteCount: current.noteCount + 1, sourceUrl: current.sourceUrl,
            coverUri: current.coverUri, coverColor: current.coverColor, coverMark: current.coverMark
          };
        }
      }
    }
    // 上游 BookmarkBookUi.coverPath 取 bookRepository.getBook(key.name, key.author).getDisplayCover()，
    // 本地按 bookId 找回书籍，取自定义封面优先的 coverUri，供卡片渲染 52dp 封面。
    const withCover: BookmarkBookSummary[] = summaries.map((summary: BookmarkBookSummary): BookmarkBookSummary => {
      const book = this.books.find((item: Book) => item.id === summary.key);
      if (book === undefined) { return summary; }
      const cover = book.customCoverUri !== undefined && book.customCoverUri.length > 0
        ? book.customCoverUri : (book.coverUri ?? '');
      return {
        key: summary.key, title: summary.title, author: summary.author,
        bookmarkCount: summary.bookmarkCount, noteCount: summary.noteCount, sourceUrl: summary.sourceUrl,
        coverUri: cover, coverColor: bookCoverColor(book), coverMark: bookCoverMark(book)
      };
    });
    // 上游 AllBookmarkViewModel 对书籍列表按书名排序（sortedBy { it.key.name }），
    // 本地原来按存储里第一次出现的顺序，书名多了会乱。
    return withCover.sort((left: BookmarkBookSummary, right: BookmarkBookSummary) =>
      left.title.localeCompare(right.title));
  }

  /**
   * 「所有书签」页的条目列表。
   * 上游把 SavedBookmark 与 Marking 混在一个 detailItems 里按章节序排列，
   * 本地用 kind 区分；笔记的 excerpt 取 selectedText、note 取用户备注。
   */
  private getBookmarkEntrySummaries(): BookmarkEntrySummary[] {
    const entries: BookmarkEntrySummary[] = this.readerBookmarks.map((bookmark: ReaderBookmark): BookmarkEntrySummary => ({
      id: bookmark.id,
      bookKey: bookmark.bookId,
      chapterName: bookmark.chapterName,
      excerpt: bookmark.bookText,
      note: bookmark.content,
      kind: 'bookmark',
      chapterIndex: bookmark.chapterIndex,
      chapterPosition: bookmark.chapterPosition,
      sourceUrl: bookmark.bookUrl
    }));
    this.readerMarkings.forEach((marking: ReaderMarking) => {
      entries.push({
        id: marking.id,
        bookKey: marking.bookId,
        chapterName: marking.chapterName,
        excerpt: marking.selectedText,
        note: marking.note,
        kind: 'note',
        chapterIndex: marking.chapterIndex,
        chapterPosition: marking.chapterPosition,
        sourceUrl: marking.bookUrl
      });
    });
    return entries;
  }

  /**
   * 主题设置页「深色模式」下拉的回调。
   *
   * 上游 `ThemeConfigScreen.kt:186-198` 的 `DropdownListSettingItem(theme_mode)` 走
   * `SetThemeMode` intent，最终写 `appShellSettingsGateway`；本地等价物就是这一个入口。
   */
  private selectThemeMode(themeMode: string): void {
    const context = this.getUIContext().getHostContext();
    if (context === undefined) {
      this.showUnavailableAction('无法切换主题模式，请重试');
      return;
    }
    this.applyThemeMode(context, themeMode, this.themePaletteIndex, true).then(() => {
      this.paperIndex = this.readerNightMode ? this.nightPaperIndex : this.dayPaperIndex;
    });
  }

  /** 主题设置页调色板回调。上游 `ThemeConfigScreen.kt:231-250` 的 `SelectTheme`。 */
  private selectThemePalette(paletteIndex: number): void {
    const context = this.getUIContext().getHostContext();
    if (context === undefined) {
      this.showUnavailableAction('无法保存调色板，请重试');
      return;
    }
    this.applyThemeMode(context, this.themeMode, paletteIndex, true);
  }

  /**
   * 自定义主题配色页的回调：改一项就写一次，对齐上游 `CustomThemeViewModel`
   * 每次 intent 都直接写 `ThemeSettingsGateway` 的行为。
   *
   * 写完立刻重跑 `applyThemeMode`，否则要等下次换日夜才看得到新颜色。
   */
  private saveCustomTheme(next: CustomThemeSnapshot): void {
    const context = this.getUIContext().getHostContext();
    if (context === undefined) {
      this.showUnavailableAction('无法保存自定义配色，请重试');
      return;
    }
    this.themeCustomColors = normalizeCustomThemeSnapshot(next);
    this.applyThemeMode(context, this.themeMode, this.themePaletteIndex, true);
  }

  /**
   * 应用一份主题包配置（「应用已存主题」与「导入主题包」共用）。
   *
   * 上游 `ThemePackageManager.applyThemeSettings` 把整份 `ThemeExportData` 交给
   * `themePackageSettingsGateway.applyAndAwait(data)`，一次性覆盖所有主题键；
   * 本地按同一口径逐字段覆盖 `@State`，资产路径由 `assets` 回填，最后统一走
   * `applyThemeMode` 重算日夜与配色，再补一次落盘。
   */
  private applyThemePackage(patch: ThemeConfigPatch, assets: Record<string, string>): void {
    const context = this.getUIContext().getHostContext();
    if (context === undefined) {
      this.showUnavailableAction('无法应用主题，请重试');
      return;
    }
    this.themePureBlack = patch.pureBlack;
    this.themeFontScale = normalizeFontScale(patch.fontScale);
    this.themePredictiveBack = patch.predictiveBack;
    this.themeContainerOpacity = patch.containerOpacity;
    this.themeOverrideCardCorner = patch.overrideBaseCardCornerRadius;
    this.themeCardCornerRadius = patch.baseCardCornerRadius;
    this.themeOverrideCardBorder = patch.overrideBaseCardBorder;
    this.themeCardBorderWidth = patch.baseCardBorderWidth;
    this.themeCardBorderColorDay = patch.baseCardBorderColorDay;
    this.themeCardBorderColorNight = patch.baseCardBorderColorNight;
    this.themeDisableGroupCorner = patch.disableSplicedColumnGroupCornerRadius;
    this.themeEnableItemDivider = patch.enableItemDivider;
    this.themeItemDividerWidth = patch.itemDividerWidth;
    this.themeItemDividerLength = patch.itemDividerLength;
    this.themeItemDividerColor = patch.itemDividerColor;
    this.themeEnableBlur = patch.enableBlur;
    this.themeEnableProgressiveBlur = patch.enableProgressiveBlur;
    this.themeTopBarBlurRadius = patch.topBarBlurRadius;
    this.themeBottomBarBlurRadius = patch.bottomBarBlurRadius;
    this.themeTopBarBlurAlpha = patch.topBarBlurAlpha;
    this.themeBottomBarBlurAlpha = patch.bottomBarBlurAlpha;
    this.themeBottomBarLensRadius = patch.bottomBarLensRadius;
    this.themeTopBarOpacity = patch.topBarOpacity;
    this.themeBottomBarOpacity = patch.bottomBarOpacity;
    this.themeShowHome = patch.showHome;
    this.themeShowDiscovery = patch.showDiscovery;
    this.themeShowRss = patch.showRss;
    this.themeShowStatusBar = patch.showStatusBar;
    this.themeSwipeAnimation = patch.swipeAnimation;
    this.themeShowBottomView = patch.showBottomView;
    this.themeUseFloatingBottomBar = patch.useFloatingBottomBar;
    this.themeUseFloatingBottomBarLiquidGlass = patch.useFloatingBottomBarLiquidGlass;
    this.themeLabelVisibilityMode = patch.labelVisibilityMode;
    this.themeDefaultHomePage = patch.defaultHomePage;
    this.themeMainNavigationOrder = patch.mainNavigationOrder;
    this.themeUseFlexibleTopAppBar = patch.useFlexibleTopAppBar;
    this.themeTopBarButtonStyle = patch.topBarButtonStyle;
    this.themeMergeTopBarActions = patch.mergeTopBarActions;
    this.themeEnableContainerBackgroundImage = patch.enableContainerBackgroundImage;
    this.themeBackgroundBlur = patch.backgroundImageBlurring;
    this.themeBackgroundNightBlur = patch.backgroundImageNightBlurring;
    this.bookInfoFollowCoverColor = patch.bookInfoFollowCoverColor;
    this.bookInfoNetworkCoverBackground = patch.bookInfoNetworkCoverBackground;
    this.bookInfoDefaultCoverBackground = patch.bookInfoDefaultCoverBackground;
    this.themeCustomColors = normalizeCustomThemeSnapshot(patch.customTheme);
    // 资产路径只在包里有对应条目时覆盖，避免「导入一个不含背景图的主题」把现有背景图清掉。
    this.applyThemePackageAssets(assets);
    this.applyDefaultHomePage();
    this.applyThemeFontScale(context);
    this.applyThemeStatusBar(context);
    this.publishThemeCardStyle();
    this.publishTopBottomBarStyle();
    this.applyThemeMode(context, patch.themeMode, patch.paletteIndex, true).catch(() => {
      this.showUnavailableAction('主题已应用，但保存失败，请重试');
    });
  }

  /** 把主题包里的资产路径回填到对应状态；空值不覆盖。 */
  private applyThemePackageAssets(assets: Record<string, string>): void {
    const take = (key: string): string => {
      const value = assets[key];
      return typeof value === 'string' ? value : '';
    };
    if (take(ASSET_BACKGROUND_LIGHT).length > 0) { this.themeBackgroundImage = take(ASSET_BACKGROUND_LIGHT); }
    if (take(ASSET_BACKGROUND_DARK).length > 0) { this.themeBackgroundImageNight = take(ASSET_BACKGROUND_DARK); }
    if (take(ASSET_CONTAINER_LARGE_LIGHT).length > 0) {
      this.themeLargeContainerBackgroundLight = take(ASSET_CONTAINER_LARGE_LIGHT);
    }
    if (take(ASSET_CONTAINER_LARGE_DARK).length > 0) {
      this.themeLargeContainerBackgroundDark = take(ASSET_CONTAINER_LARGE_DARK);
    }
    if (take(ASSET_CONTAINER_ITEM_LIGHT).length > 0) {
      this.themeItemBackgroundLight = take(ASSET_CONTAINER_ITEM_LIGHT);
    }
    if (take(ASSET_CONTAINER_ITEM_DARK).length > 0) {
      this.themeItemBackgroundDark = take(ASSET_CONTAINER_ITEM_DARK);
    }
    if (take(ASSET_FONT_APP).length > 0) { this.themeAppFontPath = take(ASSET_FONT_APP); }
  }

  /** 主题包管理页的「当前设置」来源，供保存 / 导出当前主题使用。 */
  private themePackageSource(): ThemePackageSource {
    return {
      snapshot: {
        themeMode: this.themeMode,
        paletteIndex: this.themePaletteIndex,
        fontScale: this.themeFontScale,
        showStatusBar: this.themeShowStatusBar,
        swipeAnimation: this.themeSwipeAnimation,
        bookInfoFollowCoverColor: this.bookInfoFollowCoverColor,
        bookInfoNetworkCoverBackground: this.bookInfoNetworkCoverBackground,
        bookInfoDefaultCoverBackground: this.bookInfoDefaultCoverBackground,
        containerOpacity: this.themeContainerOpacity,
        disableSplicedColumnGroupCornerRadius: this.themeDisableGroupCorner,
        overrideBaseCardCornerRadius: this.themeOverrideCardCorner,
        baseCardCornerRadius: this.themeCardCornerRadius,
        overrideBaseCardBorder: this.themeOverrideCardBorder,
        baseCardBorderWidth: this.themeCardBorderWidth,
        baseCardBorderColorDay: this.themeCardBorderColorDay,
        baseCardBorderColorNight: this.themeCardBorderColorNight,
        enableItemDivider: this.themeEnableItemDivider,
        itemDividerWidth: this.themeItemDividerWidth,
        itemDividerLength: this.themeItemDividerLength,
        itemDividerColor: this.themeItemDividerColor,
        enableContainerBackgroundImage: this.themeEnableContainerBackgroundImage,
        largeContainerBackgroundImageLight: this.themeLargeContainerBackgroundLight,
        largeContainerBackgroundImageDark: this.themeLargeContainerBackgroundDark,
        itemBackgroundImageLight: this.themeItemBackgroundLight,
        itemBackgroundImageDark: this.themeItemBackgroundDark,
        pureBlack: this.themePureBlack,
        backgroundImage: this.themeBackgroundImage,
        backgroundImageNight: this.themeBackgroundImageNight,
        backgroundImageBlurring: this.themeBackgroundBlur,
        backgroundImageNightBlurring: this.themeBackgroundNightBlur,
        showHome: this.themeShowHome,
        showDiscovery: this.themeShowDiscovery,
        showRss: this.themeShowRss,
        defaultHomePage: this.themeDefaultHomePage,
        mainNavigationOrder: this.themeMainNavigationOrder,
        labelVisibilityMode: this.themeLabelVisibilityMode,
        predictiveBack: this.themePredictiveBack,
        readerSharedElement: this.themeReaderSharedElement,
        enableBlur: this.themeEnableBlur,
        enableProgressiveBlur: this.themeEnableProgressiveBlur,
        useFlexibleTopAppBar: this.themeUseFlexibleTopAppBar,
        topBarButtonStyle: this.themeTopBarButtonStyle,
        mergeTopBarActions: this.themeMergeTopBarActions,
        showBottomView: this.themeShowBottomView,
        useFloatingBottomBar: this.themeUseFloatingBottomBar,
        useFloatingBottomBarLiquidGlass: this.themeUseFloatingBottomBarLiquidGlass,
        bottomBarLensRadius: this.themeBottomBarLensRadius,
        topBarBlurRadius: this.themeTopBarBlurRadius,
        bottomBarBlurRadius: this.themeBottomBarBlurRadius,
        topBarBlurAlpha: this.themeTopBarBlurAlpha,
        bottomBarBlurAlpha: this.themeBottomBarBlurAlpha,
        topBarOpacity: this.themeTopBarOpacity,
        bottomBarOpacity: this.themeBottomBarOpacity,
        appFontPath: this.themeAppFontPath,
        customTheme: this.themeCustomColors
      },
      themeMode: this.themeMode
    };
  }

  /**
   * 首次启动向导第 4 页深色模式回调。上游 `OnboardingViewModel.kt:120-123`
   * 的 `SetThemeMode`：点一下就写 `themeMode` 网关 + `ApplyDayNight`，
   * 所以这里立刻走与主题设置页同一条 `applyThemeMode` 写入路径，不等「完成」。
   */
  private selectOnboardingThemeMode(themeMode: number): void {
    const context = this.getUIContext().getHostContext();
    if (context === undefined) {
      return;
    }
    this.applyThemeMode(context, ThemeSettingsRepository.fromModeNumber(themeMode), this.themePaletteIndex, true);
  }

  private async restoreOnboarding(context: Context): Promise<void> {
    const state = await OnboardingRepository.load(context);
    this.onboardingComplete = state.completed;
    this.onboardingLoaded = true;
    // 向导里选的深色模式要接进全局状态，否则「首次启动选了深色」等于没选。
    // 已显式存过全局值时以全局为准：向导只在首启用一次，之后用户在主题设置页的改动不能被它冲掉。
    const theme = await ThemeSettingsRepository.load(context);
    const hasStored = await ThemeSettingsRepository.hasStoredThemeMode(context);
    // 字号与两个布尔开关先落到全局状态，再应用（与 themeMode 同一次启动读取，避免两次读盘）。
    this.themeFontScale = theme.fontScale;
    this.themeShowStatusBar = theme.showStatusBar;
    this.themeSwipeAnimation = theme.swipeAnimation;
    this.bookInfoFollowCoverColor = theme.bookInfoFollowCoverColor;
    this.bookInfoNetworkCoverBackground = theme.bookInfoNetworkCoverBackground;
    this.bookInfoDefaultCoverBackground = theme.bookInfoDefaultCoverBackground;
    this.themeContainerOpacity = theme.containerOpacity;
    this.themeDisableGroupCorner = theme.disableSplicedColumnGroupCornerRadius;
    this.themeOverrideCardCorner = theme.overrideBaseCardCornerRadius;
    this.themeCardCornerRadius = theme.baseCardCornerRadius;
    this.themeOverrideCardBorder = theme.overrideBaseCardBorder;
    this.themeCardBorderWidth = theme.baseCardBorderWidth;
    this.themeCardBorderColorDay = theme.baseCardBorderColorDay;
    this.themeCardBorderColorNight = theme.baseCardBorderColorNight;
    this.themeEnableItemDivider = theme.enableItemDivider;
    this.themeItemDividerWidth = theme.itemDividerWidth;
    this.themeItemDividerLength = theme.itemDividerLength;
    this.themeItemDividerColor = theme.itemDividerColor;
    this.themeEnableContainerBackgroundImage = theme.enableContainerBackgroundImage;
    this.themeLargeContainerBackgroundLight = theme.largeContainerBackgroundImageLight;
    this.themeLargeContainerBackgroundDark = theme.largeContainerBackgroundImageDark;
    this.themeItemBackgroundLight = theme.itemBackgroundImageLight;
    this.themeItemBackgroundDark = theme.itemBackgroundImageDark;
    this.themePureBlack = theme.pureBlack;
    this.themeBackgroundImage = theme.backgroundImage;
    this.themeBackgroundImageNight = theme.backgroundImageNight;
    this.themeBackgroundBlur = theme.backgroundImageBlurring;
    this.themeBackgroundNightBlur = theme.backgroundImageNightBlurring;
    this.themeShowHome = theme.showHome;
    this.themeShowDiscovery = theme.showDiscovery;
    this.themeShowRss = theme.showRss;
    this.themeDefaultHomePage = theme.defaultHomePage;
    this.themeMainNavigationOrder = theme.mainNavigationOrder;
    this.themeLabelVisibilityMode = theme.labelVisibilityMode;
    this.themePredictiveBack = theme.predictiveBack;
    this.themeReaderSharedElement = theme.readerSharedElement;
    this.themeEnableBlur = theme.enableBlur;
    this.themeEnableProgressiveBlur = theme.enableProgressiveBlur;
    this.themeUseFlexibleTopAppBar = theme.useFlexibleTopAppBar;
    this.themeTopBarButtonStyle = theme.topBarButtonStyle;
    this.themeMergeTopBarActions = theme.mergeTopBarActions;
    this.themeShowBottomView = theme.showBottomView;
    this.themeUseFloatingBottomBar = theme.useFloatingBottomBar;
    this.themeUseFloatingBottomBarLiquidGlass = theme.useFloatingBottomBarLiquidGlass;
    this.themeBottomBarLensRadius = theme.bottomBarLensRadius;
    this.themeTopBarBlurRadius = theme.topBarBlurRadius;
    this.themeBottomBarBlurRadius = theme.bottomBarBlurRadius;
    this.themeTopBarBlurAlpha = theme.topBarBlurAlpha;
    this.themeBottomBarBlurAlpha = theme.bottomBarBlurAlpha;
    this.themeTopBarOpacity = theme.topBarOpacity;
    this.themeBottomBarOpacity = theme.bottomBarOpacity;
    this.themeAppFontPath = theme.appFontPath;
    this.themeCustomColors = theme.customTheme;
    this.applyDefaultHomePage();
    this.applyThemeFontScale(context);
    this.applyThemeStatusBar(context);
    this.publishThemeCardStyle();
    this.publishTopBottomBarStyle();
    if (!hasStored && state.completed) {
      const mode = ThemeSettingsRepository.fromModeNumber(state.themeMode);
      await this.applyThemeMode(context, mode, state.paletteIndex, true);
    } else {
      await this.applyThemeMode(context, theme.themeMode, theme.paletteIndex, false);
    }
  }

  /** 主题设置页字体大小回调。上游 `ThemeConfigScreen.kt:309-320` 的 `SetFontScale`。 */
  private selectThemeFontScale(context: Context, fontScale: number): void {
    this.themeFontScale = normalizeFontScale(fontScale);
    this.applyThemeFontScale(context);
    this.saveThemeSettings(context).catch(() => {
      this.showUnavailableAction('字体大小保存失败，请重试');
    });
  }

  /** 主题设置页「显示状态栏」回调。上游 `ThemeConfigScreen.kt:352-360` 的 `SetShowStatusBar`。 */
  private selectThemeShowStatusBar(context: Context, visible: boolean): void {
    this.themeShowStatusBar = visible;
    this.applyThemeStatusBar(context);
    this.saveThemeSettings(context).catch(() => {
      this.showUnavailableAction('状态栏设置保存失败，请重试');
    });
  }

  /**
   * 主题设置页「启用滑动时动画」回调。上游 `ThemeConfigScreen.kt:362-370` 的 `SetSwipeAnimation`。
   *
   * 上游这个键没有渲染消费者（同处留着「这个可以不要了」的 TODO），本地只落盘、不造假效果。
   */
  private selectThemeSwipeAnimation(context: Context, enabled: boolean): void {
    this.themeSwipeAnimation = enabled;
    this.saveThemeSettings(context).catch(() => {
      this.showUnavailableAction('滑动动画设置保存失败，请重试');
    });
  }

  /** 容器背景不透明度回调。上游 `ThemeConfigScreen.kt:585` 的 `container_opacity`。 */
  private selectThemeContainerOpacity(context: Context, value: number): void {
    this.themeContainerOpacity = normalizeContainerOpacity(value);
    this.publishThemeCardStyle();
    this.saveThemeSettings(context).catch(() => {
      this.showUnavailableAction('容器不透明度保存失败，请重试');
    });
  }

  /** 关闭设置分组圆角回调。上游 `ThemeConfigScreen.kt:598`。 */
  private selectThemeDisableGroupCorner(context: Context, value: boolean): void {
    this.themeDisableGroupCorner = value;
    this.publishThemeCardStyle();
    this.saveThemeSettings(context).catch(() => {
      this.showUnavailableAction('设置分组圆角保存失败，请重试');
    });
  }

  /** 覆盖卡片圆角总开关回调。上游 `ThemeConfigScreen.kt:608`。 */
  private selectThemeOverrideCardCorner(context: Context, value: boolean): void {
    this.themeOverrideCardCorner = value;
    this.publishThemeCardStyle();
    this.saveThemeSettings(context).catch(() => {
      this.showUnavailableAction('卡片圆角设置保存失败，请重试');
    });
  }

  /** 卡片圆角数值回调。上游 `ThemeConfigScreen.kt:617` 的 `base_card_corner_radius`（0..40）。 */
  private selectThemeCardCornerRadius(context: Context, value: number): void {
    this.themeCardCornerRadius = normalizeCardCornerRadius(value);
    this.publishThemeCardStyle();
    this.saveThemeSettings(context).catch(() => {
      this.showUnavailableAction('卡片圆角保存失败，请重试');
    });
  }

  /** 覆盖卡片边框总开关回调。上游 `ThemeConfigScreen.kt:630`。 */
  private selectThemeOverrideCardBorder(context: Context, value: boolean): void {
    this.themeOverrideCardBorder = value;
    this.publishThemeCardStyle();
    this.saveThemeSettings(context).catch(() => {
      this.showUnavailableAction('卡片边框设置保存失败，请重试');
    });
  }

  /** 边框宽度回调。上游 `ThemeConfigScreen.kt:640` 的 `border_width`（0..5）。 */
  private selectThemeCardBorderWidth(context: Context, value: number): void {
    this.themeCardBorderWidth = normalizeCardBorderWidth(value);
    this.publishThemeCardStyle();
    this.saveThemeSettings(context).catch(() => {
      this.showUnavailableAction('边框宽度保存失败，请重试');
    });
  }

  /**
   * 边框颜色回调。上游 `ThemeConfigScreen.kt:652`/`:663` 的
   * `BaseCardBorderColorSettingItem`（日间/夜间各一）。
   */
  private selectThemeCardBorderColor(context: Context, isNight: boolean, value: string): void {
    const color = normalizeThemeColor(value);
    if (isNight) {
      this.themeCardBorderColorNight = color;
    } else {
      this.themeCardBorderColorDay = color;
    }
    this.publishThemeCardStyle();
    this.saveThemeSettings(context).catch(() => {
      this.showUnavailableAction('边框颜色保存失败，请重试');
    });
  }

  /**
   * 显示分隔线开关。上游 `ThemeConfigScreen.kt:676` `SwitchSettingItem(show_divider_line)`，
   * 键 `enableItemDivider`。
   */
  private selectThemeEnableItemDivider(context: Context, enabled: boolean): void {
    this.themeEnableItemDivider = enabled;
    this.publishThemeCardStyle();
    this.saveThemeSettings(context).catch(() => {
      this.showUnavailableAction('分隔线设置保存失败，请重试');
    });
  }

  /** 分隔线宽度回调。上游 `ThemeConfigScreen.kt:684` 的 `theme_config_divider_width`（0..5）。 */
  private selectThemeItemDividerWidth(context: Context, value: number): void {
    this.themeItemDividerWidth = normalizeDividerWidth(value);
    this.publishThemeCardStyle();
    this.saveThemeSettings(context).catch(() => {
      this.showUnavailableAction('分隔线宽度保存失败，请重试');
    });
  }

  /** 分隔线长度回调。上游 `ThemeConfigScreen.kt:696` 的 `theme_config_divider_length`（30..100%）。 */
  private selectThemeItemDividerLength(context: Context, value: number): void {
    this.themeItemDividerLength = normalizeDividerLength(value);
    this.publishThemeCardStyle();
    this.saveThemeSettings(context).catch(() => {
      this.showUnavailableAction('分隔线长度保存失败，请重试');
    });
  }

  /** 分隔线颜色回调。上游 `ThemeConfigScreen.kt:707` 的 `tip_divider_color`。 */
  private selectThemeItemDividerColor(context: Context, value: string): void {
    this.themeItemDividerColor = normalizeThemeColor(value);
    this.publishThemeCardStyle();
    this.saveThemeSettings(context).catch(() => {
      this.showUnavailableAction('分隔线颜色保存失败，请重试');
    });
  }

  /**
   * 纯黑深色模式开关，对齐上游 `ThemeEngine.kt:132-146 applyAmoledIfNeeded`。
   *
   * 上游只在 `darkTheme && isAmoled` 时把 surface/background 压成纯黑、
   * surfaceContainerLow 压 `#0A0A0A`、surfaceContainer 压 `#121212`；
   * 本地按同样的条件广播到 `AppStorage`，各页面用 `@StorageProp('themePureBlack')` 取用。
   */
  private selectThemePureBlack(context: Context, enabled: boolean): void {
    this.themePureBlack = enabled;
    this.publishThemeCardStyle();
    this.saveThemeSettings(context).catch(() => {
      this.showUnavailableAction('纯黑模式设置保存失败，请重试');
    });
  }

  /**
   * 主导航的可见项（按配置顺序），对齐上游 `MainDestination.ordered` + 三个 show* 开关。
   * 底栏只渲染这一组，顺序与显隐都由它决定。
   */
  private visibleNavigationRoutes(): string[] {
    return visibleMainNavigation(this.themeMainNavigationOrder,
      this.themeShowHome, this.themeShowDiscovery, this.themeShowRss);
  }

  /** route 对应的 Swiper 绝对页序号（0..4），与 `selectTab` 的口径一致。 */
  private navigationRouteTabIndex(route: string): number {
    if (route === 'home') { return 0; }
    if (route === 'bookshelf') { return 1; }
    if (route === 'explore') { return 2; }
    if (route === 'rss') { return 3; }
    return 4;
  }

  /** 底栏图标名；选中态换实心图标，与改动前一致。 */
  private navigationTabIcon(route: string): AppGlyphName {
    const selected = this.selectedTab === this.navigationRouteTabIndex(route);
    if (route === 'home') { return selected ? 'navHomeFilled' : 'navHomeOutlined'; }
    if (route === 'bookshelf') { return selected ? 'navBookshelfFilled' : 'navBookshelfOutlined'; }
    if (route === 'explore') { return selected ? 'navExploreFilled' : 'navExploreOutlined'; }
    if (route === 'rss') { return 'navRss'; }
    return selected ? 'navProfileFilled' : 'navProfileOutlined';
  }

  /**
   * 该项是否显示文字标签。上游 `labelVisibilityMode` 四档：
   * auto / selected（仅选中项）/ labeled（全部）/ unlabeled（全部隐藏）。
   */
  private navigationLabelVisible(route: string): boolean {
    const selected = this.selectedTab === this.navigationRouteTabIndex(route);
    if (this.themeLabelVisibilityMode === 'labeled') { return true; }
    if (this.themeLabelVisibilityMode === 'unlabeled') { return false; }
    return selected;
  }

  /**
   * 冷启动落到「默认主页面」。上游 `AppShellSettings.kt:17 defaultHomePage`。
   *
   * 不可见的页面按上游 `MainNavigationSettingsSheet.kt:81-84` 回落书架。
   */
  private applyDefaultHomePage(): void {
    const target = normalizeDefaultHomePage(this.themeDefaultHomePage, this.visibleNavigationRoutes());
    this.themeDefaultHomePage = target;
    this.selectTab(this.navigationRouteTabIndex(target));
  }

  /** 逐项显隐回调。上游 `MainNavigationSettingsSheet.kt:63-76` 的 `setVisibilityForRoute`。 */
  private selectThemeNavigationVisibility(context: Context, route: string, visible: boolean): void {
    if (route === 'home') { this.themeShowHome = visible; }
    else if (route === 'explore') { this.themeShowDiscovery = visible; }
    else if (route === 'rss') { this.themeShowRss = visible; }
    else { return; }
    // 关掉当前停留的页面时，按上游口径退回默认主页面。
    if (!visible && this.navigationRouteTabIndex(route) === this.selectedTab) {
      this.applyDefaultHomePage();
    }
    this.saveThemeSettings(context).catch(() => {
      this.showUnavailableAction('导航显隐保存失败，请重试');
    });
  }

  /** 拖动排序：把 route 上移一位。上游 `onMoveItem` 的 `move(from, to)`。 */
  private moveThemeNavigationUp(context: Context, route: string): void {
    const next = moveNavigationUp(orderedMainNavigation(this.themeMainNavigationOrder), route);
    this.themeMainNavigationOrder = joinMainNavigation(next);
    this.saveThemeSettings(context).catch(() => {
      this.showUnavailableAction('导航顺序保存失败，请重试');
    });
  }

  /** 拖动排序：把 route 下移一位。 */
  private moveThemeNavigationDown(context: Context, route: string): void {
    const next = moveNavigationDown(orderedMainNavigation(this.themeMainNavigationOrder), route);
    this.themeMainNavigationOrder = joinMainNavigation(next);
    this.saveThemeSettings(context).catch(() => {
      this.showUnavailableAction('导航顺序保存失败，请重试');
    });
  }

  /** 默认主页面回调。上游 `onSetDefault`。 */
  private selectThemeDefaultHomePage(context: Context, route: string): void {
    this.themeDefaultHomePage = normalizeDefaultHomePage(route, this.visibleNavigationRoutes());
    this.saveThemeSettings(context).catch(() => {
      this.showUnavailableAction('默认主页面保存失败，请重试');
    });
  }

  /** 导航标签模式回调。上游 `onSetLabelVisibilityMode`。 */
  private selectThemeLabelVisibilityMode(context: Context, value: string): void {
    this.themeLabelVisibilityMode = value;
    this.saveThemeSettings(context).catch(() => {
      this.showUnavailableAction('导航标签模式保存失败，请重试');
    });
  }

  /**
   * 预见性返回手势开关。
   *
   * 上游 `AppShellSettings.kt:9 predictiveBackEnabled` 驱动 `BaseActivity.kt:111` 的
   * `registerOnBackInvokedCallback`；ArkUI 的 SDK 里没有对应能力（`predictiveBack` 零命中），
   * 所以本地只落盘，不造假效果。
   */
  private selectThemePredictiveBack(context: Context, enabled: boolean): void {
    this.themePredictiveBack = enabled;
    this.saveThemeSettings(context).catch(() => {
      this.showUnavailableAction('预见性返回设置保存失败，请重试');
    });
  }

  /** 顶栏底色；空串表示保持组件自己的资源色。对齐上游 `GlassDefaults.glassColor()`。 */
  private topBarBackgroundColor(): string {
    const context = this.getUIContext().getHostContext();
    const isDark = context === undefined ? false
      : ThemeModeResolver.isDarkTheme(this.themeMode, ThemeModeResolver.isSystemDark(context));
    return resolveTopBarBackground(this.topBottomBarSnapshot(), isDark);
  }

  /** 底栏底色；空串表示保持 `theme_surface_elevated`。 */
  private bottomBarBackgroundColor(): string {
    const context = this.getUIContext().getHostContext();
    const isDark = context === undefined ? false
      : ThemeModeResolver.isDarkTheme(this.themeMode, ThemeModeResolver.isSystemDark(context));
    return resolveBottomBarBackground(this.topBottomBarSnapshot(), isDark);
  }

  /** 底栏圆角：悬浮胶囊模式用 `bottomBarLensRadius`，否则 0。 */
  private bottomBarCornerRadius(): number {
    return resolveBottomBarCornerRadius(this.topBottomBarSnapshot());
  }

  /** 顶栏与底栏设置快照，字段顺序对齐上游 `TopBottomBarSettingsSheet.kt`。 */
  private topBottomBarSnapshot(): TopBottomBarSnapshot {
    return {
      enableBlur: this.themeEnableBlur,
      enableProgressiveBlur: this.themeEnableProgressiveBlur,
      useFlexibleTopAppBar: this.themeUseFlexibleTopAppBar,
      topBarButtonStyle: this.themeTopBarButtonStyle,
      mergeTopBarActions: this.themeMergeTopBarActions,
      showBottomView: this.themeShowBottomView,
      useFloatingBottomBar: this.themeUseFloatingBottomBar,
      useFloatingBottomBarLiquidGlass: this.themeUseFloatingBottomBarLiquidGlass,
      bottomBarLensRadius: this.themeBottomBarLensRadius,
      topBarBlurRadius: this.themeTopBarBlurRadius,
      bottomBarBlurRadius: this.themeBottomBarBlurRadius,
      topBarBlurAlpha: this.themeTopBarBlurAlpha,
      bottomBarBlurAlpha: this.themeBottomBarBlurAlpha,
      topBarOpacity: this.themeTopBarOpacity,
      bottomBarOpacity: this.themeBottomBarOpacity
    };
  }

  /** 把顶栏/底栏的解析结果广播出去，供 `CollapsingSettingsHeader` 等独立组件读取。 */
  private publishTopBottomBarStyle(): void {
    const snapshot = this.topBottomBarSnapshot();
    const context = this.getUIContext().getHostContext();
    const isDark = context === undefined ? false
      : ThemeModeResolver.isDarkTheme(this.themeMode, ThemeModeResolver.isSystemDark(context));
    AppStorage.setOrCreate('themeTopBarBackground', resolveTopBarBackground(snapshot, isDark));
    AppStorage.setOrCreate('themeBottomBarBackground', resolveBottomBarBackground(snapshot, isDark));
    AppStorage.setOrCreate('themeTopBarBlurRadius', this.themeEnableBlur ? this.themeTopBarBlurRadius : 0);
    AppStorage.setOrCreate('themeBottomBarBlurRadius', this.themeEnableBlur ? this.themeBottomBarBlurRadius : 0);
    AppStorage.setOrCreate('themeBottomBarRadius', resolveBottomBarCornerRadius(snapshot));
  }

  private selectThemeEnableBlur(context: Context, enabled: boolean): void {
    this.themeEnableBlur = enabled;
    this.publishTopBottomBarStyle();
    this.saveThemeSettings(context).catch(() => {
      this.showUnavailableAction('模糊效果设置保存失败，请重试');
    });
  }

  private selectThemeEnableProgressiveBlur(context: Context, enabled: boolean): void {
    this.themeEnableProgressiveBlur = enabled;
    this.publishTopBottomBarStyle();
    this.saveThemeSettings(context).catch(() => {
      this.showUnavailableAction('渐变模糊设置保存失败，请重试');
    });
  }

  private selectThemeUseFlexibleTopAppBar(context: Context, enabled: boolean): void {
    this.themeUseFlexibleTopAppBar = enabled;
    this.saveThemeSettings(context).catch(() => {
      this.showUnavailableAction('折叠应用栏设置保存失败，请重试');
    });
  }

  private selectThemeTopBarButtonStyle(context: Context, value: string): void {
    this.themeTopBarButtonStyle = normalizeTopBarButtonStyle(value);
    this.saveThemeSettings(context).catch(() => {
      this.showUnavailableAction('顶栏按钮样式保存失败，请重试');
    });
  }

  private selectThemeMergeTopBarActions(context: Context, enabled: boolean): void {
    this.themeMergeTopBarActions = enabled;
    this.saveThemeSettings(context).catch(() => {
      this.showUnavailableAction('合并顶栏按钮设置保存失败，请重试');
    });
  }

  private selectThemeShowBottomView(context: Context, enabled: boolean): void {
    this.themeShowBottomView = enabled;
    this.saveThemeSettings(context).catch(() => {
      this.showUnavailableAction('显示导航栏设置保存失败，请重试');
    });
  }

  private selectThemeUseFloatingBottomBar(context: Context, enabled: boolean): void {
    this.themeUseFloatingBottomBar = enabled;
    this.publishTopBottomBarStyle();
    this.saveThemeSettings(context).catch(() => {
      this.showUnavailableAction('悬浮底栏设置保存失败，请重试');
    });
  }

  private selectThemeUseFloatingBottomBarLiquidGlass(context: Context, enabled: boolean): void {
    this.themeUseFloatingBottomBarLiquidGlass = enabled;
    this.saveThemeSettings(context).catch(() => {
      this.showUnavailableAction('液态玻璃设置保存失败，请重试');
    });
  }

  private selectThemeBottomBarLensRadius(context: Context, value: number): void {
    this.themeBottomBarLensRadius = normalizeBottomBarLensRadius(value);
    this.publishTopBottomBarStyle();
    this.saveThemeSettings(context).catch(() => {
      this.showUnavailableAction('底栏模糊强度保存失败，请重试');
    });
  }

  private selectThemeTopBarBlurRadius(context: Context, value: number): void {
    this.themeTopBarBlurRadius = normalizeTopBarBlurRadius(value);
    this.publishTopBottomBarStyle();
    this.saveThemeSettings(context).catch(() => {
      this.showUnavailableAction('顶栏模糊半径保存失败，请重试');
    });
  }

  private selectThemeBottomBarBlurRadius(context: Context, value: number): void {
    this.themeBottomBarBlurRadius = normalizeBottomBarBlurRadius(value);
    this.publishTopBottomBarStyle();
    this.saveThemeSettings(context).catch(() => {
      this.showUnavailableAction('底栏模糊半径保存失败，请重试');
    });
  }

  private selectThemeTopBarBlurAlpha(context: Context, value: number): void {
    this.themeTopBarBlurAlpha = normalizeBarBlurAlpha(value, TOP_BAR_BLUR_ALPHA_DEFAULT);
    this.publishTopBottomBarStyle();
    this.saveThemeSettings(context).catch(() => {
      this.showUnavailableAction('顶栏模糊透明度保存失败，请重试');
    });
  }

  private selectThemeBottomBarBlurAlpha(context: Context, value: number): void {
    this.themeBottomBarBlurAlpha = normalizeBarBlurAlpha(value, BOTTOM_BAR_BLUR_ALPHA_DEFAULT);
    this.publishTopBottomBarStyle();
    this.saveThemeSettings(context).catch(() => {
      this.showUnavailableAction('底栏模糊透明度保存失败，请重试');
    });
  }

  private selectThemeTopBarOpacity(context: Context, value: number): void {
    this.themeTopBarOpacity = normalizeTopBarOpacity(value);
    this.publishTopBottomBarStyle();
    this.saveThemeSettings(context).catch(() => {
      this.showUnavailableAction('顶栏不透明度保存失败，请重试');
    });
  }

  private selectThemeBottomBarOpacity(context: Context, value: number): void {
    this.themeBottomBarOpacity = normalizeBottomBarOpacity(value);
    this.publishTopBottomBarStyle();
    this.saveThemeSettings(context).catch(() => {
      this.showUnavailableAction('底栏不透明度保存失败，请重试');
    });
  }

  /**
   * 进阅读页的转场。
   *
   * 上游 `readerSharedElementEnabled` 打开时走共享元素（书封展开），关闭时走渐变；
   * ArkUI 的 `geometryTransition` 要求源与目标组件同时在场，本地是整页 if/else 切换，
   * 做不到真正的共享元素，所以打开时用「缩小淡入 + 放大淡出」近似，关闭时只做淡入淡出。
   */
  private readerRouteTransition(): TransitionEffect {
    const fade = TransitionEffect.OPACITY.animation({ duration: 220 });
    if (!this.themeReaderSharedElement) { return fade; }
    return fade.combine(TransitionEffect.scale({ x: 0.92, y: 0.92 }).animation({ duration: 220 }));
  }

  /** 阅读界面共享元素动画开关。上游 `AppShellSettings.kt:10 readerSharedElementEnabled`。 */
  private selectThemeReaderSharedElement(context: Context, enabled: boolean): void {
    this.themeReaderSharedElement = enabled;
    this.saveThemeSettings(context).catch(() => {
      this.showUnavailableAction('共享元素动画设置保存失败，请重试');
    });
  }

  /**
   * 容器背景图总开关。上游 `ThemeConfigScreen.kt:533` 的 `enableContainerBackgroundImage`。
   *
   * 打开后 `AnimatedVisibility` 放出「大容器背景图片」「项目背景图片」两行（A33/A34）。
   */
  private selectThemeEnableContainerBackgroundImage(context: Context, enabled: boolean): void {
    this.themeEnableContainerBackgroundImage = enabled;
    this.publishThemeCardStyle();
    this.saveThemeSettings(context).catch(() => {
      this.showUnavailableAction('容器背景图设置保存失败，请重试');
    });
  }

  /** 当前生效的全 App 背景图路径（按日夜选），对齐上游 `ThemeSettings.hasBackgroundImage`。 */
  private appBackgroundSource(): string {
    const context = this.getUIContext().getHostContext();
    const isDark = context === undefined ? false
      : ThemeModeResolver.isDarkTheme(this.themeMode, ThemeModeResolver.isSystemDark(context));
    return isDark ? this.themeBackgroundImageNight : this.themeBackgroundImage;
  }

  /** 当前生效的背景图虚化半径，对齐上游 `backgroundImageBlurring`/`backgroundImageNightBlurring`。 */
  private appBackgroundBlur(): number {
    const context = this.getUIContext().getHostContext();
    const isDark = context === undefined ? false
      : ThemeModeResolver.isDarkTheme(this.themeMode, ThemeModeResolver.isSystemDark(context));
    return isDark ? this.themeBackgroundNightBlur : this.themeBackgroundBlur;
  }

  /**
   * 选一张全 App 背景图并复制进应用沙箱。
   *
   * 上游 `ui/theme/AppBackground.kt:17-48` 按 `backgroundImageDark`/`backgroundImageLight`
   * 选路径、按 `backgroundImageDarkBlurring`/`Blurring` 选模糊度，铺在内容层之下、
   * `ContentScale.Crop` 填满。本地沿用容器背景图那套「选图 → 复制进 `files/theme-backgrounds/` → 存路径」流程。
   */
  private async pickThemeBackgroundImage(isNight: boolean): Promise<void> {
    const context = this.getUIContext().getHostContext();
    if (context === undefined) {
      this.showUnavailableAction('无法访问本地文件，未选择背景图');
      return;
    }
    try {
      const options = new picker.DocumentSelectOptions();
      options.fileSuffixFilters = ['图片|.png', '图片|.jpg', '图片|.jpeg', '图片|.webp'];
      options.maxSelectNumber = 1;
      const uris = await new picker.DocumentViewPicker(context).select(options);
      const uri = uris[0];
      if (uri === undefined) { return; }
      const directory = `${context.filesDir}/theme-backgrounds`;
      if (!fileIo.accessSync(directory)) { fileIo.mkdirSync(directory, true); }
      const suffix = uri.substring(uri.lastIndexOf('.') === -1 ? uri.length : uri.lastIndexOf('.')).toLowerCase();
      const extension = suffix.length > 1 && suffix.length <= 6 ? suffix : '.png';
      const target = `${directory}/app-${isNight ? 'night' : 'day'}-${Date.now()}${extension}`;
      const source = fileIo.openSync(uri, fileIo.OpenMode.READ_ONLY);
      try {
        fileIo.copyFileSync(source.fd, target);
        if (fileIo.statSync(target).size <= 0) { throw new Error('所选背景图文件为空'); }
      } finally {
        fileIo.closeSync(source);
      }
      if (isNight) { this.themeBackgroundImageNight = target; } else { this.themeBackgroundImage = target; }
      this.publishThemeCardStyle();
      await this.saveThemeSettings(context);
    } catch (error) {
      this.showUnavailableAction(error instanceof Error ? error.message : '选择背景图失败');
    }
  }

  /** 背景图虚化半径滑块回调，对齐上游 `backgroundImageBlurring`/`backgroundImageNightBlurring`。 */
  private selectThemeBackgroundBlur(context: Context, isNight: boolean, blur: number): void {
    const value = normalizeBackgroundBlur(blur);
    if (isNight) { this.themeBackgroundNightBlur = value; } else { this.themeBackgroundBlur = value; }
    this.publishThemeCardStyle();
    this.saveThemeSettings(context).catch(() => {
      this.showUnavailableAction('背景图虚化设置保存失败，请重试');
    });
  }

  /** 清空背景图（对应上游 `BackgroundImageManageSheet` 的「移除」）。 */
  private clearThemeBackgroundImage(context: Context, isNight: boolean): void {
    if (isNight) { this.themeBackgroundImageNight = ''; } else { this.themeBackgroundImage = ''; }
    this.publishThemeCardStyle();
    this.saveThemeSettings(context).catch(() => {
      this.showUnavailableAction('清空背景图失败，请重试');
    });
  }

  /**
   * 选一张背景图并复制进应用沙箱。
   *
   * 上游用 `BackgroundImageManageSheet`（`ThemeConfigScreen.kt:828-880`）分别给大容器/项目
   * 选日间与夜间两张图，路径存在 `largeContainerBackgroundImage*` / `itemBackgroundImage*`。
   * 本地用 `DocumentViewPicker` 选图，复制到 `filesDir/theme-backgrounds/` 后存路径，
   * 与上游「先存文件再存路径」的顺序一致——这样备份/清理时能按目录统一处理。
   */
  private async pickThemeContainerBackground(isLarge: boolean, isNight: boolean): Promise<void> {
    const context = this.getUIContext().getHostContext();
    if (context === undefined) {
      this.showUnavailableAction('无法访问本地文件，未选择背景图');
      return;
    }
    try {
      const options = new picker.DocumentSelectOptions();
      options.fileSuffixFilters = ['图片|.png', '图片|.jpg', '图片|.jpeg', '图片|.webp'];
      options.maxSelectNumber = 1;
      const uris = await new picker.DocumentViewPicker(context).select(options);
      const uri = uris[0];
      if (uri === undefined) { return; }
      const directory = `${context.filesDir}/theme-backgrounds`;
      if (!fileIo.accessSync(directory)) { fileIo.mkdirSync(directory, true); }
      // 保留原扩展名：`Image()` 按扩展名判解码器，存成 `.img` 会解不出来。
      const suffix = uri.substring(uri.lastIndexOf('.') === -1 ? uri.length : uri.lastIndexOf('.')).toLowerCase();
      const extension = suffix.length > 1 && suffix.length <= 6 ? suffix : '.png';
      const target = `${directory}/${isLarge ? 'large' : 'item'}-${isNight ? 'night' : 'day'}-${Date.now()}${extension}`;
      const source = fileIo.openSync(uri, fileIo.OpenMode.READ_ONLY);
      try {
        fileIo.copyFileSync(source.fd, target);
        if (fileIo.statSync(target).size <= 0) { throw new Error('所选背景图文件为空'); }
      } finally {
        fileIo.closeSync(source);
      }
      if (isLarge) {
        if (isNight) { this.themeLargeContainerBackgroundDark = target; } else { this.themeLargeContainerBackgroundLight = target; }
      } else {
        if (isNight) { this.themeItemBackgroundDark = target; } else { this.themeItemBackgroundLight = target; }
      }
      this.publishThemeCardStyle();
      await this.saveThemeSettings(context);
    } catch (error) {
      this.showUnavailableAction(error instanceof Error ? error.message : '选择背景图失败');
    }
  }

  /**
   * 恢复默认主题配置。上游 `ThemeConfigViewModel.kt:205-240 resetDefaults()`。
   *
   * 上游重置的是整份 `AppShellSettings` + `CoverSettings` + `ThemeSettings`，
   * 并删掉背景图/导航图标/应用字体文件；本地这三类里已落地的只有主题设置这几项，
   * 所以只重置它们——不碰书架、阅读设置与护眼（上游的 `ThemeSettings()` 也把
   * `eyeProtection*` 归零，但那属于阅读配置，本地按 READER-CONFIG 的既有口径保留）。
   */
  private resetThemeDefaults(): void {
    const context = this.getUIContext().getHostContext();
    if (context === undefined) {
      this.showUnavailableAction('恢复默认配置失败，请重试');
      return;
    }
    this.themeContainerOpacity = CONTAINER_OPACITY_DEFAULT;
    this.themeDisableGroupCorner = false;
    this.themeOverrideCardCorner = false;
    this.themeCardCornerRadius = CARD_RADIUS_DEFAULT;
    this.themeOverrideCardBorder = false;
    this.themeCardBorderWidth = CARD_BORDER_WIDTH_DEFAULT;
    this.themeCardBorderColorDay = '';
    this.themeCardBorderColorNight = '';
    this.themeEnableItemDivider = false;
    this.themeItemDividerWidth = DIVIDER_WIDTH_DEFAULT;
    this.themeItemDividerLength = DIVIDER_LENGTH_DEFAULT;
    this.themeItemDividerColor = '';
    this.themeEnableContainerBackgroundImage = false;
    this.themeLargeContainerBackgroundLight = '';
    this.themeLargeContainerBackgroundDark = '';
    this.themeItemBackgroundLight = '';
    this.themeItemBackgroundDark = '';
    this.themeFontScale = FONT_SCALE_DEFAULT;
    this.themeShowStatusBar = true;
    this.themeSwipeAnimation = true;
    this.bookInfoFollowCoverColor = true;
    this.bookInfoNetworkCoverBackground = 'on';
    this.bookInfoDefaultCoverBackground = 'on';
    this.themePureBlack = false;
    this.themeBackgroundImage = '';
    this.themeBackgroundImageNight = '';
    this.themeBackgroundBlur = 0;
    this.themeBackgroundNightBlur = 0;
    this.themeShowHome = true;
    this.themeShowDiscovery = true;
    this.themeShowRss = true;
    this.themeDefaultHomePage = DEFAULT_HOME_PAGE_DEFAULT;
    this.themeMainNavigationOrder = MAIN_NAVIGATION_ORDER_DEFAULT;
    this.themeLabelVisibilityMode = LABEL_VISIBILITY_DEFAULT;
    this.themePredictiveBack = true;
    this.themeReaderSharedElement = true;
    this.themeEnableBlur = false;
    this.themeEnableProgressiveBlur = false;
    this.themeUseFlexibleTopAppBar = true;
    this.themeTopBarButtonStyle = TOP_BAR_BUTTON_STYLE_DEFAULT;
    this.themeMergeTopBarActions = false;
    this.themeShowBottomView = true;
    this.themeUseFloatingBottomBar = false;
    this.themeUseFloatingBottomBarLiquidGlass = false;
    this.themeBottomBarLensRadius = BOTTOM_BAR_LENS_RADIUS_DEFAULT;
    this.themeTopBarBlurRadius = TOP_BAR_BLUR_RADIUS_DEFAULT;
    this.themeBottomBarBlurRadius = BOTTOM_BAR_BLUR_RADIUS_DEFAULT;
    this.themeTopBarBlurAlpha = TOP_BAR_BLUR_ALPHA_DEFAULT;
    this.themeBottomBarBlurAlpha = BOTTOM_BAR_BLUR_ALPHA_DEFAULT;
    this.themeTopBarOpacity = TOP_BAR_OPACITY_DEFAULT;
    this.themeBottomBarOpacity = BOTTOM_BAR_OPACITY_DEFAULT;
    this.themeAppFontPath = '';
    this.themeCustomColors = defaultCustomThemeSnapshot();
    this.applyThemeFontScale(context);
    this.applyThemeStatusBar(context);
    this.publishThemeCardStyle();
    this.saveThemeSettings(context).then(() => {
      this.showUnavailableAction('已恢复默认主题配置');
    }).catch(() => {
      this.showUnavailableAction('恢复默认配置失败，请重试');
    });
  }

  /**
   * 应用主题模式：写全局状态 + 落盘 + 通知系统换资源目录。
   *
   * 对齐上游 `App.kt:194-203` 的注释——`themeMode` 是日夜的唯一来源，
   * 主题设置页、阅读页快捷按钮、首次启动向导三处都走这一个入口。
   */
  private async applyThemeMode(context: Context, themeMode: string, paletteIndex: number, persist: boolean): Promise<void> {
    this.themeMode = themeMode;
    this.themePaletteIndex = paletteIndex;
    this.readerNightMode = ThemeModeResolver.isDarkTheme(themeMode, ThemeModeResolver.isSystemDark(context));
    ThemeModeResolver.apply(context, themeMode);
    // 配色跟着日夜走：同一套调色板的日间/夜间色值不同，所以放在 `ThemeModeResolver.apply` 之后广播。
    // 对齐上游 `ThemeEngine.getColorScheme(context, mode, darkTheme, ...)` 每次换肤都现算一套。
    // 调色板序号为 12（自定义）时改用用户手选的 6 个颜色，判断顺序见 `resolveCustomPaletteColors`。
    const normalizedIndex = normalizePaletteIndex(paletteIndex);
    const isDarkNow = this.readerNightMode;
    const customColors = normalizedIndex === 12
      ? resolveCustomPaletteColors(this.themeCustomColors, isDarkNow,
        resolvePaletteColors(normalizedIndex, isDarkNow))
      : undefined;
    applyThemeColors(context, normalizedIndex, themeMode, customColors);
    // 日夜一变，卡片边框色就要按 baseCardBorderColor(Night) 重选，所以顺带刷新一次。
    this.publishThemeCardStyle();
    this.publishTopBottomBarStyle();
    if (!persist) {
      return;
    }
    try {
      await this.saveThemeSettings(context);
    } catch (_) {
      this.showUnavailableAction('主题设置保存失败，请重试');
    }
  }

  /**
   * 把当前主题状态整份落盘。
   *
   * 上游 `AppShellSettings` 是一个整体对象、一次写全（`FeatureSettingsRepositories.kt:321-327`
   * 的 `toPrefMap()`），所以这里也整份写，避免「只写 themeMode、字号与两个开关丢」。
   */
  private async saveThemeSettings(context: Context): Promise<void> {
    await ThemeSettingsRepository.save(context, {
      themeMode: this.themeMode,
      paletteIndex: this.themePaletteIndex,
      fontScale: this.themeFontScale,
      showStatusBar: this.themeShowStatusBar,
      swipeAnimation: this.themeSwipeAnimation,
      bookInfoFollowCoverColor: this.bookInfoFollowCoverColor,
      bookInfoNetworkCoverBackground: this.bookInfoNetworkCoverBackground,
      bookInfoDefaultCoverBackground: this.bookInfoDefaultCoverBackground,
      containerOpacity: this.themeContainerOpacity,
      disableSplicedColumnGroupCornerRadius: this.themeDisableGroupCorner,
      overrideBaseCardCornerRadius: this.themeOverrideCardCorner,
      baseCardCornerRadius: this.themeCardCornerRadius,
      overrideBaseCardBorder: this.themeOverrideCardBorder,
      baseCardBorderWidth: this.themeCardBorderWidth,
      baseCardBorderColorDay: this.themeCardBorderColorDay,
      baseCardBorderColorNight: this.themeCardBorderColorNight,
      enableItemDivider: this.themeEnableItemDivider,
      itemDividerWidth: this.themeItemDividerWidth,
      itemDividerLength: this.themeItemDividerLength,
      itemDividerColor: this.themeItemDividerColor,
      enableContainerBackgroundImage: this.themeEnableContainerBackgroundImage,
      largeContainerBackgroundImageLight: this.themeLargeContainerBackgroundLight,
      largeContainerBackgroundImageDark: this.themeLargeContainerBackgroundDark,
      itemBackgroundImageLight: this.themeItemBackgroundLight,
      itemBackgroundImageDark: this.themeItemBackgroundDark,
      pureBlack: this.themePureBlack,
      backgroundImage: this.themeBackgroundImage,
      backgroundImageNight: this.themeBackgroundImageNight,
      backgroundImageBlurring: this.themeBackgroundBlur,
      backgroundImageNightBlurring: this.themeBackgroundNightBlur,
      showHome: this.themeShowHome,
      showDiscovery: this.themeShowDiscovery,
      showRss: this.themeShowRss,
      defaultHomePage: this.themeDefaultHomePage,
      mainNavigationOrder: this.themeMainNavigationOrder,
      labelVisibilityMode: this.themeLabelVisibilityMode,
      predictiveBack: this.themePredictiveBack,
      readerSharedElement: this.themeReaderSharedElement,
      enableBlur: this.themeEnableBlur,
      enableProgressiveBlur: this.themeEnableProgressiveBlur,
      useFlexibleTopAppBar: this.themeUseFlexibleTopAppBar,
      topBarButtonStyle: this.themeTopBarButtonStyle,
      mergeTopBarActions: this.themeMergeTopBarActions,
      showBottomView: this.themeShowBottomView,
      useFloatingBottomBar: this.themeUseFloatingBottomBar,
      useFloatingBottomBarLiquidGlass: this.themeUseFloatingBottomBarLiquidGlass,
      bottomBarLensRadius: this.themeBottomBarLensRadius,
      topBarBlurRadius: this.themeTopBarBlurRadius,
      bottomBarBlurRadius: this.themeBottomBarBlurRadius,
      topBarBlurAlpha: this.themeTopBarBlurAlpha,
      bottomBarBlurAlpha: this.themeBottomBarBlurAlpha,
      topBarOpacity: this.themeTopBarOpacity,
      bottomBarOpacity: this.themeBottomBarOpacity,
      appFontPath: this.themeAppFontPath,
      customTheme: this.themeCustomColors
    });
  }

  /** 当前卡片外观快照，供 `ThemeCardStyle` 的解析函数使用。 */
  private themeCardStyleSnapshot(): ThemeCardStyleSnapshot {
    return {
      containerOpacity: this.themeContainerOpacity,
      disableSplicedColumnGroupCornerRadius: this.themeDisableGroupCorner,
      overrideBaseCardCornerRadius: this.themeOverrideCardCorner,
      baseCardCornerRadius: this.themeCardCornerRadius,
      overrideBaseCardBorder: this.themeOverrideCardBorder,
      baseCardBorderWidth: this.themeCardBorderWidth,
      baseCardBorderColorDay: this.themeCardBorderColorDay,
      baseCardBorderColorNight: this.themeCardBorderColorNight,
      enableItemDivider: this.themeEnableItemDivider,
      itemDividerWidth: this.themeItemDividerWidth,
      itemDividerLength: this.themeItemDividerLength,
      itemDividerColor: this.themeItemDividerColor
    };
  }

  /** 容器背景图的当前值，供 `publishThemeCardStyle` 写进 AppStorage。 */
  private themeContainerBackgroundSource(): string {
    if (!this.themeEnableContainerBackgroundImage) { return ''; }
    const isDark = this.themeMode === THEME_MODE_DARK;
    return isDark ? this.themeLargeContainerBackgroundDark : this.themeLargeContainerBackgroundLight;
  }

  /** 项目背景图的当前值（日夜各一套），供 `publishThemeCardStyle` 写进 AppStorage。 */
  private themeItemBackgroundSource(): string {
    if (!this.themeEnableContainerBackgroundImage) { return ''; }
    const isDark = this.themeMode === THEME_MODE_DARK;
    return isDark ? this.themeItemBackgroundDark : this.themeItemBackgroundLight;
  }

  /**
   * 把解析后的卡片外观写进 `AppStorage`，供二十多个设置卡片组件用 `@StorageProp` 读取。
   *
   * 上游是 CompositionLocal（`LocalAppUiConfiguration.current.theme`）随处可取；
   * ArkUI 没有等价物，`AppStorage` 是最接近的全局可观察通道，且改动会触发所有
   * `@StorageProp` 组件重渲染——这正是「调滑块，全 App 卡片立刻变」需要的行为。
   */
  private publishThemeCardStyle(): void {
    const snapshot = this.themeCardStyleSnapshot();
    const context = this.getUIContext().getHostContext();
    const isDark = context === undefined ? false
      : ThemeModeResolver.isDarkTheme(this.themeMode, ThemeModeResolver.isSystemDark(context));
    AppStorage.setOrCreate('themeCardRadius', resolveCardCornerRadius(snapshot));
    AppStorage.setOrCreate('themeCardBorderWidth', resolveCardBorderWidth(snapshot));
    AppStorage.setOrCreate('themeCardBorderColor', resolveCardBorderColor(snapshot, isDark));
    AppStorage.setOrCreate('themeCardBackground', resolveCardBackgroundColor(snapshot, isDark));
    AppStorage.setOrCreate('themeDividerWidth', resolveDividerWidth(snapshot));
    AppStorage.setOrCreate('themeDividerLength', resolveDividerLength(snapshot));
    AppStorage.setOrCreate('themeDividerColor', resolveDividerColor(snapshot));
    AppStorage.setOrCreate('themeContainerBackground', this.themeContainerBackgroundSource());
    AppStorage.setOrCreate('themeItemBackground', this.themeItemBackgroundSource());
    // 纯黑只在深色下生效，对齐上游 `ThemeEngine.kt:132-146 applyAmoledIfNeeded` 的 `darkTheme && isAmoled`。
    AppStorage.setOrCreate('themePureBlack', isDark && this.themePureBlack);
    // 全 App 背景图：页面底色要让位给根 Stack 里的背景图，否则各页自己的不透明底色会把图盖住。
    AppStorage.setOrCreate('themeAppBackground', this.appBackgroundSource());
  }

  /** 主题设置页「界面颜色跟随封面取色」回调。上游 `ThemeConfigScreen.kt:399` 的 `BookInfoFollowCoverColor`。 */
  private selectBookInfoFollowCoverColor(context: Context, enabled: boolean): void {
    this.bookInfoFollowCoverColor = enabled;
    this.saveThemeSettings(context).catch(() => {
      this.showUnavailableAction('封面取色设置保存失败，请重试');
    });
  }

  /**
   * 主题设置页「网络封面背景设置 / 默认封面背景设置」回调。
   *
   * 上游 `ThemeConfigScreen.kt:407` 与 `:416` 是同一组下拉（`off`/`on`/`off_for_default`），
   * `isDefaultCover` 区分写哪个键。
   */
  private selectBookInfoCoverBackground(context: Context, isDefaultCover: boolean, value: string): void {
    const normalized = normalizeBookInfoBackground(value);
    if (isDefaultCover) {
      this.bookInfoDefaultCoverBackground = normalized;
    } else {
      this.bookInfoNetworkCoverBackground = normalized;
    }
    this.saveThemeSettings(context).catch(() => {
      this.showUnavailableAction('封面背景设置保存失败，请重试');
    });
  }

  /**
   * 应用全局字体缩放。
   *
   * 上游口径 `ui/theme/AppDensity.kt:13-14 resolveAppFontScale`：把 8..16 的整数设置除以 10
   * 得到 0.8..1.6 的比例，越界时回落到系统字体缩放。这里只做前半段——本地滑块本身就夹在
   * 8..16，所以直接除以 10；`setFontSizeScale` 由系统负责与用户系统字号上限取小。
   */
  /**
   * 选择应用字体文件。
   *
   * 上游 `ThemeConfigViewModel.kt:555-582` 选完文件后复制到 `filesDir/fonts/app_font*`，
   * 再把路径写进 `ThemeSettings.appFontPath`；本地同样复制进 `filesDir/fonts/`，
   * 避免文档选择器的 URI 授权过期后字体失效。
   */
  private async pickThemeAppFont(context: Context): Promise<void> {
    try {
      const options = new picker.DocumentSelectOptions();
      options.fileSuffixFilters = ['字体|.ttf', '字体|.otf', '字体|.ttc'];
      options.maxSelectNumber = 1;
      const uris = await new picker.DocumentViewPicker(context).select(options);
      const uri = uris[0];
      if (uri === undefined) { return; }
      const directory = `${context.filesDir}/fonts`;
      if (!fileIo.accessSync(directory)) { fileIo.mkdirSync(directory, true); }
      const suffix = uri.substring(uri.lastIndexOf('.') === -1 ? uri.length : uri.lastIndexOf('.')).toLowerCase();
      const extension = suffix.length > 1 && suffix.length <= 5 ? suffix : '.ttf';
      const target = `${directory}/app_font_${Date.now()}${extension}`;
      const source = fileIo.openSync(uri, fileIo.OpenMode.READ_ONLY);
      try {
        fileIo.copyFileSync(source.fd, target);
        if (fileIo.statSync(target).size <= 0) { throw new Error('所选字体文件为空'); }
      } finally {
        fileIo.closeSync(source);
      }
      this.themeAppFontPath = normalizeAppFontPath(target);
      this.pruneThemeAppFonts(directory, target);
      this.applyThemeAppFont();
      await this.saveThemeSettings(context);
    } catch (error) {
      this.showUnavailableAction(error instanceof Error ? error.message : '选择字体失败');
    }
  }

  /** 清空自定义字体，回落到系统默认字体。 */
  private clearThemeAppFont(context: Context): void {
    this.themeAppFontPath = '';
    // 对齐上游 `ThemeConfigViewModel.kt:589 clearAppFont()`：清空路径后一并清掉私有目录里的字体副本。
    this.pruneThemeAppFonts(`${context.filesDir}/fonts`, '');
    this.applyThemeAppFont();
    this.saveThemeSettings(context).catch(() => {
      this.showUnavailableAction('清除字体失败，请重试');
    });
  }

  /** 只保留当前字体副本，对齐上游 `pruneCopiedFonts()`（只删 `app_font` 前缀）。 */
  private pruneThemeAppFonts(directory: string, keep: string): void {
    try {
      const names = fileIo.listFileSync(directory);
      for (let index = 0; index < names.length; index++) {
        const name = names[index];
        if (!name.startsWith('app_font')) { continue; }
        const full = `${directory}/${name}`;
        if (full === keep) { continue; }
        try { fileIo.unlinkSync(full); } catch (_) { }
      }
    } catch (_) {
    }
  }

  private applyThemeFontScale(context: Context): void {
    try {
      const scale = this.themeFontScale / 10;
      context.getApplicationContext().setFontSizeScale(scale);
    } catch (_) {
    }
    this.applyThemeAppFont();
  }

  /**
   * 应用自定义字体族。
   *
   * 上游把 `appFontPath` 交给 `base/AppContextWrapper.kt` 的 `applyFont()` 改写 `Configuration`；
   * ArkUI 的等价链路是 `UIContext.getFont().registerFont({ familyName, familySrc })` 注册，
   * 再 `ApplicationContext.setFont(familyName)` 让全局默认字体换成它。
   * 清空字体时把族名设回空串，系统回落到默认字体。
   */
  private applyThemeAppFont(): void {
    const path = this.themeAppFontPath;
    if (path.length === 0) {
      try {
        const context = this.getUIContext().getHostContext();
        if (context !== undefined) {
          context.getApplicationContext().setFont('');
        }
      } catch (_) {
      }
      return;
    }
    try {
      this.getUIContext().getFont().registerFont({
        familyName: APP_FONT_FAMILY,
        familySrc: `file://${path}`
      });
      const context = this.getUIContext().getHostContext();
      if (context !== undefined) {
        context.getApplicationContext().setFont(APP_FONT_FAMILY);
      }
    } catch (_) {
    }
  }

  /**
   * 应用状态栏显隐。
   *
   * 上游 `base/BaseComposeActivity.kt:151` 调 `utils/ActivityExtensions.kt:153 toggleSystemBar(show)`，
   * 内部是 `WindowInsetsControllerCompat.show/hide(systemBars())`。ArkUI 的等价物是
   * `window.Window.setWindowSystemBarEnable(['status'])` / `setWindowSystemBarEnable([])`。
   */
  private applyThemeStatusBar(context: Context): void {
    try {
      window.getLastWindow(context).then((win) => {
        win.setSpecificSystemBarEnabled('status', this.themeShowStatusBar, false).catch(() => {});
      }).catch(() => {});
    } catch (_) {
    }
  }

  private async finishOnboarding(themeMode: number, paletteIndex: number): Promise<void> {
    const context = this.getUIContext().getHostContext();
    if (context === undefined) {
      this.showUnavailableAction('无法保存首次启动设置，请重试');
      return;
    }
    try {
      await OnboardingRepository.complete(context, themeMode, paletteIndex);
      this.onboardingComplete = true;
      // 向导里选的深色模式要立刻生效并接进全局状态（上游 OnboardingViewModel.kt:120-123
      // 的 SetThemeMode 也是当场写 appShellSettingsGateway，不是只记下来）。
      await this.applyThemeMode(context, ThemeSettingsRepository.fromModeNumber(themeMode), paletteIndex, true);
    } catch (_) {
      this.showUnavailableAction('设置保存失败，请重试完成向导');
    }
  }

  private async loadRestoredAndroidEntries(context: Context): Promise<void> {
    this.restoredAndroidEntries = await BackupRepository.loadRestoredEntries(context);
  }

  private async restoreReaderSettings(context: Context): Promise<void> {
    const initialRevision = this.readerSettingsRevision;
    const settings = await ReaderSettingsRepository.load(context);
    const infoSettings = this.getReaderInfoSettingsFromSnapshot(settings);
    if (initialRevision === this.readerSettingsRevision) {
      this.readerFontSize = settings.fontSize;
      this.readerParagraphSpacing = settings.paragraphSpacing;
      this.readerLineSpacing = settings.lineSpacing;
      this.readerLetterSpacing = settings.letterSpacing;
      this.readerParagraphIndent = settings.paragraphIndent;
      this.readerTextFont = settings.textFont;
      this.readerTitleFont = settings.titleFont;
      this.readerSystemTypefaces = settings.systemTypefaces;
      this.readerTextItalic = settings.textItalic;
      this.readerTextBold = settings.textBold;
      this.readerTextShadow = settings.textShadow;
      this.readerShadowRadius = settings.shadowRadius;
      this.readerShadowDx = settings.shadowDx;
      this.readerShadowDy = settings.shadowDy;
      this.readerTextShadowColor = settings.textShadowColor;
      this.readerTextShadowColorN = settings.textShadowColorN;
      this.readerUnderline = settings.underline;
      this.readerDottedLine = settings.dottedLine;
      this.readerUnderlineColor = settings.underlineColor;
      this.readerUnderlineColorNight = settings.underlineColorNight;
      this.readerUnderlineHeight = settings.underlineHeight;
      this.readerUnderlinePadding = settings.underlinePadding;
      this.readerUnderlineExtend = settings.underlineExtend;
      this.readerDottedBase = settings.dottedBase;
      this.readerDottedRatio = settings.dottedRatio;
      this.readerTextFullJustify = settings.textFullJustify;
      this.readerTextBottomJustify = settings.textBottomJustify;
      this.paperIndex = settings.paperIndex;
      this.dayPaperIndex = settings.dayPaperIndex;
      this.nightPaperIndex = settings.nightPaperIndex;
      this.backgroundStyles = copyReaderBackgroundStyles(settings.backgroundStyles);
      // readerNightMode 不再从阅读设置里读：它的唯一来源是全局 themeMode（见 applyThemeMode），
      // 这里只按全局值补一次投影，并据此选定当前纸色。
      this.readerNightMode = ThemeModeResolver.isDarkTheme(this.themeMode,
        ThemeModeResolver.isSystemDark(context));
      this.paperIndex = this.readerNightMode ? this.nightPaperIndex : this.dayPaperIndex;
      this.shareReaderStyleLayout = settings.shareLayout;
      this.showReaderBottomActionText = settings.showBottomActionText;
      this.readerBottomIconStyle = settings.bottomIconStyle;
      this.readerBottomItemsPerRow = settings.bottomItemsPerRow;
      this.readerBottomRowCount = settings.bottomRowCount;
      this.readerBottomActions = settings.bottomActions;
      this.readerTopActions = settings.topActions;
      this.readerProgressBehavior = settings.progressBehavior;
      this.readerReadSliderMode = settings.readSliderMode;
      this.readerPageTouchSlop = settings.pageTouchSlop;
      this.readerLastMarkingStyle = settings.lastMarkingStyle;
      this.readerPaddingSettings = copyReaderPaddingSettings(settings.paddingSettings);
      this.readerScreenOrientation = settings.screenOrientation;
      this.readerKeepLight = settings.keepLight;
      this.readerVolumeKeyPage = settings.volumeKeyPage;
      this.readerKeyPageOnLongPress = settings.keyPageOnLongPress;
      this.readerNoAnimScrollPage = settings.noAnimScrollPage;
      this.readerPrevKeys = settings.prevKeys;
      this.readerNextKeys = settings.nextKeys;
      this.readerMouseWheelPage = settings.mouseWheelPage;
      this.readerExpandTextMenu = settings.expandTextMenu;
      this.readerShowSelectMenuIcon = settings.showSelectMenuIcon;
      this.readerTextSelectMenuConfig = settings.textSelectMenuConfig;
    this.readerDoubleHorizontalPage = settings.doubleHorizontalPage;
    this.readerAutoSuggestDayNight = settings.autoSuggestDayNight;
    this.readerDisableReturnKey = settings.disableReturnKey;
    this.readerReadBrightness = settings.readBrightness;
    this.readerShowBrightnessView = settings.showBrightnessView;
    this.readerBrightnessVwPos = settings.brightnessVwPos;
    this.readerBrightnessAuto = settings.brightnessAuto;
    this.readerReadBodyToLh = settings.readBodyToLh;
    this.readerUseZhLayout = settings.useZhLayout;
    this.readerPaddingDisplayCutouts = settings.paddingDisplayCutouts;
    this.readerAdaptSpecialStyle = settings.adaptSpecialStyle;
    this.readerReadMenuBottomCornerRadius = settings.readMenuBottomCornerRadius;
    this.readerReadMenuFloatingBottomBar = settings.readMenuFloatingBottomBar;
    this.readerReadMenuBottomBarBlurMode = settings.readMenuBottomBarBlurMode;
    this.readerReadMenuBottomBarBlurStyle = settings.readMenuBottomBarBlurStyle;
    this.readerReadMenuBottomBarLiquidGlassButtons = settings.readMenuBottomBarLiquidGlassButtons;
    this.readerReadMenuBlurAlpha = settings.readMenuBlurAlpha;
    this.readerReadMenuTopBarTitleCapsule = settings.readMenuTopBarTitleCapsule;
    this.readerTitleBarMode = settings.titleBarMode;
    this.readerTitleBarCompact = settings.titleBarCompact;
    this.readerTitleBarIconStyle = settings.titleBarIconStyle;
    this.readerReadMenuTopBarBlurMode = settings.readMenuTopBarBlurMode;
    this.readerReadMenuTopBarBlurStyle = settings.readMenuTopBarBlurStyle;
    this.readerReadMenuTopBarLiquidGlassButtons = settings.readMenuTopBarLiquidGlassButtons;
    this.readerReadMenuTopBarMergeButtons = settings.readMenuTopBarMergeButtons;
    this.readerReadBarStyle = settings.readBarStyle;
    this.readerMenuPaletteStyle = settings.readMenuPaletteStyle;
    this.readerMenuColorMode = settings.readMenuColorMode;
    this.readerMenuBgColor = settings.readMenuBgColor;
    this.readerMenuBgColorNight = settings.readMenuBgColorNight;
    this.readerMenuContainerColor = settings.readMenuContainerColor;
    this.readerMenuContainerColorNight = settings.readMenuContainerColorNight;
    this.readerMenuAccentColor = settings.readMenuAccentColor;
    this.readerMenuAccentColorNight = settings.readMenuAccentColorNight;
    this.readerMenuBorderWidth = settings.readMenuBorderWidth;
    this.readerMenuBorderColor = settings.readMenuBorderColor;
    this.readerMenuBorderColorNight = settings.readMenuBorderColorNight;
    this.readerMenuBlurRadius = settings.readMenuBlurRadius;
    this.readerMenuTextColor = settings.readMenuTextColor;
    this.readerMenuTextColorNight = settings.readMenuTextColorNight;
    this.readerMenuBlurColor = settings.readMenuBlurColor;
    this.readerMenuBlurColorNight = settings.readMenuBlurColorNight;
    this.readerShowTitleBarIcons = settings.showTitleBarIcons;
    this.readerTitleBarIconPosition = settings.titleBarIconPosition;
    this.readerReadMenuFloatingIconLiquidGlass = settings.readMenuFloatingIconLiquidGlass;
    this.readerFloatingIcons = settings.floatingIcons.map(
      (item: ReaderBottomActionConfig): ReaderBottomActionConfig => ({ id: item.id, enabled: item.enabled })
    );
    this.readerTitleBarCustomIcons = settings.titleBarCustomIcons;
    this.readerReadMenuCustomIcons = settings.readMenuCustomIcons;
    this.readerReadMenuLensRadius = settings.readMenuLensRadius;
    this.readerReadBarStyleFollowPage = settings.readBarStyleFollowPage;
    this.readerShowMenuIcon = settings.showMenuIcon;
    this.readerShowReadTitleAddition = settings.showReadTitleAddition;
    this.readerMenuAlpha = settings.menuAlpha;
      this.readerReadingAnchorEnabled = settings.readingAnchorEnabled;
      this.readerSwipeToAddBookmark = settings.swipeToAddBookmark;
      this.readerBookmarkBadgeSize = settings.bookmarkBadgeSize;
      this.readerBookmarkBadgeImage = settings.bookmarkBadgeImage;
      this.readerSelectText = settings.selectText;
      this.readerSliderVibrator = settings.sliderVibrator;
      this.readerSelectVibrator = settings.selectVibrator;
      this.readerChineseConverterType = settings.chineseConverterType;
      this.readerTextColor = settings.textColor;
      this.readerTextColorNight = settings.textColorNight;
      this.readerTextAccentColor = settings.textAccentColor;
      this.readerTextAccentColorNight = settings.textAccentColorNight;
      this.readerBgStr = settings.bgStr;
      this.readerBgStrNight = settings.bgStrNight;
      this.readerBgType = settings.bgType;
      this.readerBgTypeNight = settings.bgTypeNight;
      this.readerBgAlpha = settings.bgAlpha;
      this.readerDarkStatusIcon = settings.darkStatusIcon;
      this.readerDarkStatusIconNight = settings.darkStatusIconNight;
      this.readerTitleMode = settings.titleMode;
      this.readerTitleSize = settings.titleSize;
      this.readerTitleSizeRelative = settings.titleSizeRelative;
      this.readerTitleTopSpacing = settings.titleTopSpacing;
      this.readerTitleBottomSpacing = settings.titleBottomSpacing;
      this.readerTitleColor = settings.titleColor;
      this.readerTitleColorNight = settings.titleColorNight;
      this.readerTitleBold = settings.titleBold;
      this.readerTitleLineSpacingExtra = settings.titleLineSpacingExtra;
      this.readerTitleLineSpacingSub = settings.titleLineSpacingSub;
      this.readerTitleSegType = settings.titleSegType;
      this.readerTitleSegScaling = settings.titleSegScaling;
      this.readerTitleSegDistance = settings.titleSegDistance;
      this.readerTitleSegFlag = settings.titleSegFlag;
      BookRepository.setChineseConverterType(settings.chineseConverterType);
      ReplaceRuleRepository.setChineseConverterType(settings.chineseConverterType);
      this.readerMaxLengthWithNoToc = settings.maxLengthWithNoToc;
      this.eyeProtectionEnabled = settings.eyeProtectionEnabled;
      this.eyeProtectionAutoNight = settings.eyeProtectionAutoNight;
      this.eyeProtectionSchedule = settings.eyeProtectionSchedule;
      this.eyeProtectionIntensity = settings.eyeProtectionIntensity;
      this.eyeProtectionStartTime = settings.eyeProtectionStartTime;
      this.eyeProtectionEndTime = settings.eyeProtectionEndTime;
      this.readerTocUseReplace = settings.tocUseReplace;
      this.readerTocShowWordCount = settings.tocShowWordCount;
      this.readerClickImageBehavior = settings.clickImageBehavior;
      this.readerClickRegionActions = settings.clickRegionActions;
      this.readerHideStatusBar = settings.hideStatusBar;
      this.readerHideNavigationBar = settings.hideNavigationBar;
      this.showReaderQuickActions = settings.showQuickActions;
      this.autoReadSpeed = settings.autoReadSpeed;
      this.readerPageAnimation = settings.pageAnimation;
      this.readerAnimationSpeed = settings.animationSpeed;
      this.readerInfoSettings = infoSettings;
    }
    this.readerSettingsLoaded = true;
    if (initialRevision !== this.readerSettingsRevision) {
      this.persistReaderSettings();
    }
  }

  private async restoreReaderMoreActions(context: Context): Promise<void> {
    this.readerMoreActions = await ReaderMoreActionsRepository.load(context);
  }

  private async setReaderMoreActions(actions: ReaderMoreActionConfig[]): Promise<void> {
    this.readerMoreActions = actions.map((item: ReaderMoreActionConfig): ReaderMoreActionConfig => ({
      id: item.id,
      enabled: item.enabled
    }));
    const context = this.getUIContext().getHostContext();
    if (context === undefined) { return; }
    try {
      await ReaderMoreActionsRepository.save(context, this.readerMoreActions);
      // 「更多」面板条目在快照里以 moreActionsConfig 的形式参与备份（上游 ReadSettings.kt:121），
      // 仓储写完要立刻回写一次阅读设置，否则 config.xml 导出拿到的还是上一次的旧串。
      await this.persistReaderSettings();
    } catch (_) {
      this.showUnavailableAction('更多操作配置保存失败');
    }
  }

  private async restoreBackupIgnoreLists(context: Context): Promise<void> {
    const options = await BackupRepository.loadIgnoreLists(context);
    this.backupIgnoreKeys = options.backup;
    this.restoreIgnoreKeys = options.restore;
  }

  /** WebDAV 设置随启动恢复，与备份忽略列表一样是独立 fire-and-forget 的 preferences 读取。 */
  private async restoreWebDavSettings(context: Context): Promise<void> {
    this.webDavSettings = await WebDavConfigStore.load(context);
  }

  private async persistReaderSettings(): Promise<void> {
    const context = this.getUIContext().getHostContext();
    if (context === undefined) { return; }
    try {
      await ReaderSettingsRepository.save(context, this.getCurrentReaderSettingsSnapshot());
    } catch (_) {
      this.showUnavailableAction('阅读设置保存失败');
    }
  }

  private getCurrentReaderSettingsSnapshot(): ReaderSettingsSnapshot {
    // 横屏双页档位也进快照，否则 save() 会因为缺字段编译不过、运行时也会丢档位。
    return {
        doubleHorizontalPage: this.readerDoubleHorizontalPage,
        autoSuggestDayNight: this.readerAutoSuggestDayNight,
        disableReturnKey: this.readerDisableReturnKey,
        readBrightness: this.readerReadBrightness,
        showBrightnessView: this.readerShowBrightnessView,
        brightnessVwPos: this.readerBrightnessVwPos,
        brightnessAuto: this.readerBrightnessAuto,
        readBodyToLh: this.readerReadBodyToLh,
        useZhLayout: this.readerUseZhLayout,
        paddingDisplayCutouts: this.readerPaddingDisplayCutouts,
        readMenuBottomCornerRadius: this.readerReadMenuBottomCornerRadius,
        readMenuFloatingBottomBar: this.readerReadMenuFloatingBottomBar,
        readMenuBottomBarBlurMode: this.readerReadMenuBottomBarBlurMode,
        readMenuBottomBarBlurStyle: this.readerReadMenuBottomBarBlurStyle,
        readMenuBottomBarLiquidGlassButtons: this.readerReadMenuBottomBarLiquidGlassButtons,
        readMenuBlurAlpha: this.readerReadMenuBlurAlpha,
        readMenuTopBarTitleCapsule: this.readerReadMenuTopBarTitleCapsule,
        titleBarMode: this.readerTitleBarMode,
        titleBarCompact: this.readerTitleBarCompact,
        titleBarIconStyle: this.readerTitleBarIconStyle,
        readMenuTopBarBlurMode: this.readerReadMenuTopBarBlurMode,
        readMenuTopBarBlurStyle: this.readerReadMenuTopBarBlurStyle,
        readMenuTopBarLiquidGlassButtons: this.readerReadMenuTopBarLiquidGlassButtons,
        readMenuTopBarMergeButtons: this.readerReadMenuTopBarMergeButtons,
        readBarStyle: this.readerReadBarStyle,
        readMenuPaletteStyle: this.readerMenuPaletteStyle,
        readMenuColorMode: this.readerMenuColorMode,
        readMenuBgColor: this.readerMenuBgColor,
        readMenuBgColorNight: this.readerMenuBgColorNight,
        readMenuContainerColor: this.readerMenuContainerColor,
        readMenuContainerColorNight: this.readerMenuContainerColorNight,
        readMenuAccentColor: this.readerMenuAccentColor,
        readMenuAccentColorNight: this.readerMenuAccentColorNight,
        readMenuBorderWidth: this.readerMenuBorderWidth,
        readMenuBorderColor: this.readerMenuBorderColor,
        readMenuBorderColorNight: this.readerMenuBorderColorNight,
        readMenuBlurRadius: this.readerMenuBlurRadius,
        readMenuTextColor: this.readerMenuTextColor,
        readMenuTextColorNight: this.readerMenuTextColorNight,
        readMenuBlurColor: this.readerMenuBlurColor,
        readMenuBlurColorNight: this.readerMenuBlurColorNight,
        showTitleBarIcons: this.readerShowTitleBarIcons,
        titleBarIconPosition: this.readerTitleBarIconPosition,
        readMenuFloatingIconLiquidGlass: this.readerReadMenuFloatingIconLiquidGlass,
        floatingIcons: this.readerFloatingIcons,
        titleBarCustomIcons: this.readerTitleBarCustomIcons,
        readMenuCustomIcons: this.readerReadMenuCustomIcons,
        readMenuLensRadius: this.readerReadMenuLensRadius,
        readBarStyleFollowPage: this.readerReadBarStyleFollowPage,
        showMenuIcon: this.readerShowMenuIcon,
        showReadTitleAddition: this.readerShowReadTitleAddition,
        menuAlpha: this.readerMenuAlpha,
        // 「更多」面板条目的备份投影：运行时真源是 ReaderMoreActionsRepository，
        // 这里按上游 moreActionsConfig 的 `id,enabled;` 格式编码进快照，供 config.xml 导出。
        moreActionsConfig: ReaderSettingsRepository.encodeMoreActions(this.readerMoreActions),
        adaptSpecialStyle: this.readerAdaptSpecialStyle,
        fontSize: this.readerFontSize,
        paragraphSpacing: this.readerParagraphSpacing,
        lineSpacing: this.readerLineSpacing,
        letterSpacing: this.readerLetterSpacing,
        paragraphIndent: this.readerParagraphIndent,
        textFont: this.readerTextFont,
        titleFont: this.readerTitleFont,
        systemTypefaces: this.readerSystemTypefaces,
        textItalic: this.readerTextItalic,
        textBold: this.readerTextBold,
        textShadow: this.readerTextShadow,
        shadowRadius: this.readerShadowRadius,
        shadowDx: this.readerShadowDx,
        shadowDy: this.readerShadowDy,
        textShadowColor: this.readerTextShadowColor,
        textShadowColorN: this.readerTextShadowColorN,
        underline: this.readerUnderline,
        dottedLine: this.readerDottedLine,
        underlineColor: this.readerUnderlineColor,
        underlineColorNight: this.readerUnderlineColorNight,
        underlineHeight: this.readerUnderlineHeight,
        underlinePadding: this.readerUnderlinePadding,
        underlineExtend: this.readerUnderlineExtend,
        dottedBase: this.readerDottedBase,
        dottedRatio: this.readerDottedRatio,
        textFullJustify: this.readerTextFullJustify,
        textBottomJustify: this.readerTextBottomJustify,
        paperIndex: this.paperIndex,
        dayPaperIndex: this.dayPaperIndex,
        nightPaperIndex: this.nightPaperIndex,
        backgroundStyles: copyReaderBackgroundStyles(this.backgroundStyles),
        readerNightMode: this.readerNightMode,
        shareLayout: this.shareReaderStyleLayout,
        showBottomActionText: this.showReaderBottomActionText,
        bottomIconStyle: this.readerBottomIconStyle,
        bottomItemsPerRow: this.readerBottomItemsPerRow,
        bottomRowCount: this.readerBottomRowCount,
        bottomActions: this.readerBottomActions,
        topActions: this.readerTopActions,
        progressBehavior: this.readerProgressBehavior,
        readSliderMode: this.readerReadSliderMode,
        pageTouchSlop: this.readerPageTouchSlop,
        lastMarkingStyle: this.readerLastMarkingStyle,
        paddingSettings: this.readerPaddingSettings,
        screenOrientation: this.readerScreenOrientation,
        keepLight: this.readerKeepLight,
        volumeKeyPage: this.readerVolumeKeyPage,
        keyPageOnLongPress: this.readerKeyPageOnLongPress,
        noAnimScrollPage: this.readerNoAnimScrollPage,
        prevKeys: this.readerPrevKeys,
        nextKeys: this.readerNextKeys,
        mouseWheelPage: this.readerMouseWheelPage,
        expandTextMenu: this.readerExpandTextMenu,
        showSelectMenuIcon: this.readerShowSelectMenuIcon,
        textSelectMenuConfig: this.readerTextSelectMenuConfig,
        readingAnchorEnabled: this.readerReadingAnchorEnabled,
        swipeToAddBookmark: this.readerSwipeToAddBookmark,
        bookmarkBadgeSize: this.readerBookmarkBadgeSize,
        bookmarkBadgeImage: this.readerBookmarkBadgeImage,
        selectText: this.readerSelectText,
        sliderVibrator: this.readerSliderVibrator,
        selectVibrator: this.readerSelectVibrator,
        chineseConverterType: this.readerChineseConverterType,
        textColor: this.readerTextColor,
        textColorNight: this.readerTextColorNight,
        textAccentColor: this.readerTextAccentColor,
        textAccentColorNight: this.readerTextAccentColorNight,
        bgStr: this.readerBgStr,
        bgStrNight: this.readerBgStrNight,
        bgType: this.readerBgType,
        bgTypeNight: this.readerBgTypeNight,
        bgAlpha: this.readerBgAlpha,
        darkStatusIcon: this.readerDarkStatusIcon,
        darkStatusIconNight: this.readerDarkStatusIconNight,
        titleMode: this.readerTitleMode,
        titleSize: this.readerTitleSize,
        titleSizeRelative: this.readerTitleSizeRelative,
        titleTopSpacing: this.readerTitleTopSpacing,
        titleBottomSpacing: this.readerTitleBottomSpacing,
        titleColor: this.readerTitleColor,
        titleColorNight: this.readerTitleColorNight,
        titleBold: this.readerTitleBold,
        titleLineSpacingExtra: this.readerTitleLineSpacingExtra,
        titleLineSpacingSub: this.readerTitleLineSpacingSub,
        titleSegType: this.readerTitleSegType,
        titleSegScaling: this.readerTitleSegScaling,
        titleSegDistance: this.readerTitleSegDistance,
        titleSegFlag: this.readerTitleSegFlag,
        maxLengthWithNoToc: this.readerMaxLengthWithNoToc,
        eyeProtectionEnabled: this.eyeProtectionEnabled,
        eyeProtectionAutoNight: this.eyeProtectionAutoNight,
        eyeProtectionSchedule: this.eyeProtectionSchedule,
        eyeProtectionIntensity: this.eyeProtectionIntensity,
        eyeProtectionStartTime: this.eyeProtectionStartTime,
        eyeProtectionEndTime: this.eyeProtectionEndTime,
        tocUseReplace: this.readerTocUseReplace,
        tocShowWordCount: this.readerTocShowWordCount,
        clickImageBehavior: this.readerClickImageBehavior,
        clickRegionActions: this.readerClickRegionActions,
        hideStatusBar: this.readerHideStatusBar,
        hideNavigationBar: this.readerHideNavigationBar,
        showQuickActions: this.showReaderQuickActions,
        autoReadSpeed: this.autoReadSpeed,
        pageAnimation: this.readerPageAnimation,
        animationSpeed: this.readerAnimationSpeed,
        headerMode: this.readerInfoSettings.headerMode,
        footerMode: this.readerInfoSettings.footerMode,
        showHeaderLine: this.readerInfoSettings.showHeaderLine,
        showFooterLine: this.readerInfoSettings.showFooterLine,
        tipHeaderLeft: this.readerInfoSettings.tipHeaderLeft,
        tipHeaderMiddle: this.readerInfoSettings.tipHeaderMiddle,
        tipHeaderRight: this.readerInfoSettings.tipHeaderRight,
        tipFooterLeft: this.readerInfoSettings.tipFooterLeft,
        tipFooterMiddle: this.readerInfoSettings.tipFooterMiddle,
        tipFooterRight: this.readerInfoSettings.tipFooterRight,
        customTipHeaderLeft: this.readerInfoSettings.customTipHeaderLeft,
        customTipHeaderMiddle: this.readerInfoSettings.customTipHeaderMiddle,
        customTipHeaderRight: this.readerInfoSettings.customTipHeaderRight,
        customTipFooterLeft: this.readerInfoSettings.customTipFooterLeft,
        customTipFooterMiddle: this.readerInfoSettings.customTipFooterMiddle,
        customTipFooterRight: this.readerInfoSettings.customTipFooterRight,
        headerFont: this.readerInfoSettings.headerFont,
        footerFont: this.readerInfoSettings.footerFont,
        headerFontSize: this.readerInfoSettings.headerFontSize,
        footerFontSize: this.readerInfoSettings.footerFontSize,
        applyHeaderStyle: this.readerInfoSettings.applyHeaderStyle,
        tipHeaderColor: this.readerInfoSettings.tipHeaderColor,
        tipHeaderColorNight: this.readerInfoSettings.tipHeaderColorNight,
        tipFooterColor: this.readerInfoSettings.tipFooterColor,
        tipFooterColorNight: this.readerInfoSettings.tipFooterColorNight,
        tipDividerColor: this.readerInfoSettings.tipDividerColor
    };
  }

  private setReaderFontSize(fontSize: number): void {
    this.readerFontSize = Math.max(5, Math.min(50, Math.round(fontSize)));
    this.readerSettingsRevision += 1;
    if (this.readerSettingsLoaded) { this.persistReaderSettings(); }
  }

  private setReaderParagraphSpacing(value: number): void {
    this.readerParagraphSpacing = Math.max(0, Math.min(20, Math.round(value)));
    this.readerSettingsRevision += 1;
    if (this.readerSettingsLoaded) { this.persistReaderSettings(); }
  }

  private setReaderLineSpacing(value: number): void {
    this.readerLineSpacing = Math.max(0, Math.min(20, Math.round(value)));
    this.readerSettingsRevision += 1;
    if (this.readerSettingsLoaded) { this.persistReaderSettings(); }
  }

  private setReaderLetterSpacing(value: number): void {
    this.readerLetterSpacing = Math.round(Math.max(-0.5, Math.min(0.5, value)) * 100) / 100;
    this.readerSettingsRevision += 1;
    if (this.readerSettingsLoaded) { this.persistReaderSettings(); }
  }

  private setReaderParagraphIndentCount(count: number): void {
    const indentCount = Math.max(0, Math.min(4, Math.round(count)));
    this.readerParagraphIndent = '　'.repeat(indentCount);
    this.readerSettingsRevision += 1;
    if (this.readerSettingsLoaded) { this.persistReaderSettings(); }
  }

  private setReaderTextFont(path: string): void {
    this.readerTextFont = path;
    this.readerSettingsRevision += 1;
    if (this.readerSettingsLoaded) { this.persistReaderSettings(); }
  }

  private setReaderTitleFont(path: string): void {
    this.readerTitleFont = path;
    this.readerSettingsRevision += 1;
    if (this.readerSettingsLoaded) { this.persistReaderSettings(); }
  }

  private setReaderSystemTypefaces(index: number): void {
    this.readerSystemTypefaces = Math.max(0, Math.min(2, Math.round(index)));
    this.readerSettingsRevision += 1;
    if (this.readerSettingsLoaded) { this.persistReaderSettings(); }
  }

  private setReaderTextFullJustify(enabled: boolean): void {
    this.readerTextFullJustify = enabled;
    this.readerSettingsRevision += 1;
    if (this.readerSettingsLoaded) { this.persistReaderSettings(); }
  }

  private setReaderTextBottomJustify(enabled: boolean): void {
    this.readerTextBottomJustify = enabled;
    this.readerSettingsRevision += 1;
    if (this.readerSettingsLoaded) { this.persistReaderSettings(); }
  }

  private saveReaderBodyEffect(): void {
    this.readerSettingsRevision += 1;
    if (this.readerSettingsLoaded) { this.persistReaderSettings(); }
  }

  private setReaderTextItalic(enabled: boolean): void {
    this.readerTextItalic = enabled;
    this.saveReaderBodyEffect();
  }

  private setReaderTextBold(weight: number): void {
    this.readerTextBold = Math.max(300, Math.min(900, Math.round(weight / 100) * 100));
    this.saveReaderBodyEffect();
  }

  private setReaderTextShadow(enabled: boolean): void {
    this.readerTextShadow = enabled;
    this.saveReaderBodyEffect();
  }

  private setReaderShadowRadius(value: number): void {
    this.readerShadowRadius = Math.max(0, Math.min(100, Math.round(value)));
    this.saveReaderBodyEffect();
  }

  private setReaderShadowDx(value: number): void {
    this.readerShadowDx = Math.max(-50, Math.min(50, Math.round(value)));
    this.saveReaderBodyEffect();
  }

  private setReaderShadowDy(value: number): void {
    this.readerShadowDy = Math.max(-50, Math.min(50, Math.round(value)));
    this.saveReaderBodyEffect();
  }

  private setReaderTextShadowColor(value: string, night: boolean): void {
    if (night) { this.readerTextShadowColorN = value; }
    else { this.readerTextShadowColor = value; }
    this.saveReaderBodyEffect();
  }

  private setReaderUnderline(enabled: boolean): void {
    this.readerUnderline = enabled;
    if (!enabled) { this.readerDottedLine = false; }
    this.saveReaderBodyEffect();
  }

  private setReaderDottedLine(enabled: boolean): void {
    this.readerDottedLine = enabled && this.readerUnderline;
    this.saveReaderBodyEffect();
  }

  private setReaderUnderlineColor(value: string, night: boolean): void {
    if (night) { this.readerUnderlineColorNight = value; }
    else { this.readerUnderlineColor = value; }
    this.saveReaderBodyEffect();
  }

  private setReaderUnderlineHeight(value: number): void {
    this.readerUnderlineHeight = Math.max(0, Math.min(10, Math.round(value)));
    this.saveReaderBodyEffect();
  }

  private setReaderUnderlinePadding(value: number): void {
    this.readerUnderlinePadding = Math.max(0, Math.min(20, Math.round(value)));
    this.saveReaderBodyEffect();
  }

  private setReaderUnderlineExtend(enabled: boolean): void {
    this.readerUnderlineExtend = enabled;
    this.saveReaderBodyEffect();
  }

  private setReaderDottedBase(value: number): void {
    this.readerDottedBase = Math.max(0, Math.min(20, Math.round(value)));
    this.saveReaderBodyEffect();
  }

  private setReaderDottedRatio(value: number): void {
    this.readerDottedRatio = Math.max(0, Math.min(20, Math.round(value)));
    this.saveReaderBodyEffect();
  }

  private setAutoReadSpeed(seconds: number): void {
    this.autoReadSpeed = Math.max(1, Math.min(120, Math.round(seconds)));
    this.readerSettingsRevision += 1;
    if (this.readerSettingsLoaded) { this.persistReaderSettings(); }
  }

  private setReaderPageAnimation(animation: number): void {
    this.readerPageAnimation = Math.max(0, Math.min(5, Math.round(animation)));
    this.readerSettingsRevision += 1;
    if (this.readerSettingsLoaded) { this.persistReaderSettings(); }
  }

  private setReaderAnimationSpeed(speed: number): void {
    this.readerAnimationSpeed = Math.max(0, Math.min(3, Math.round(speed)));
    this.readerSettingsRevision += 1;
    if (this.readerSettingsLoaded) { this.persistReaderSettings(); }
  }

  private getReaderInfoSettingsFromSnapshot(settings: ReaderSettingsSnapshot): ReaderInfoSettings {
    return copyReaderInfoSettings(settings);
  }

  private setReaderInfoSettings(settings: ReaderInfoSettings): void {
    this.readerInfoSettings = copyReaderInfoSettings(settings);
    this.readerSettingsRevision += 1;
    if (this.readerSettingsLoaded) { this.persistReaderSettings(); }
  }

  private setReaderPaperIndex(paperIndex: number): void {
    this.paperIndex = Math.max(0, Math.min(this.backgroundStyles.length - 1, paperIndex));
    if (this.readerNightMode) {
      this.nightPaperIndex = this.paperIndex;
      if (this.shareReaderStyleLayout) { this.dayPaperIndex = this.paperIndex; }
    } else {
      this.dayPaperIndex = this.paperIndex;
      if (this.shareReaderStyleLayout) { this.nightPaperIndex = this.paperIndex; }
    }
    this.readerSettingsRevision += 1;
    if (this.readerSettingsLoaded) { this.persistReaderSettings(); }
  }

  /**
   * 新增一个背景样式，返回它在表里的下标。
   *
   * 对齐上游 `ReadBookConfig.asNewStyle()`（`ReadBookConfig.kt:967-987`）：新样式的**背景整组
   * 清回默认**（`Config()` 的 `bgStr = "#EEEEEE"`、`bgStrNight = "#000000"`），名字也清空
   * 留给用户起（空名字在卡片上显示成「背景样式」，见上游 `StyleCard` 的 `ifBlank`）。
   * 本地样式条目只有名字与日/夜背景色两项，其余排版仍是全局单份，所以这里只重置这两色。
   */
  private addReaderBackgroundStyle(): number {
    const styles: ReaderBackgroundStyle[] = copyReaderBackgroundStyles(this.backgroundStyles);
    const nextIndex = styles.length;
    styles.push({
      // 用时间戳做 id：本机不需要跨设备同步，只要在本进程与重启后都稳定唯一即可。
      id: `style-${Date.now()}-${nextIndex}`,
      name: '',
      dayColor: READER_STYLE_NEW_DAY_COLOR,
      nightColor: READER_STYLE_NEW_NIGHT_COLOR
    });
    this.backgroundStyles = styles;
    this.setReaderPaperIndex(nextIndex);
    return nextIndex;
  }

  /** 改一个样式的名字与日/夜背景色。预设那几份允许改，与上游一致（上游只锁增删排序）。 */
  private updateReaderBackgroundStyle(index: number, name: string,
    dayColor: string, nightColor: string): void {
    if (index < 0 || index >= this.backgroundStyles.length) { return; }
    const styles: ReaderBackgroundStyle[] = copyReaderBackgroundStyles(this.backgroundStyles);
    const current = styles[index];
    styles[index] = {
      id: current.id,
      name: name.length > 0 ? name : current.name,
      dayColor: dayColor.length > 0 ? dayColor : current.dayColor,
      nightColor: nightColor.length > 0 ? nightColor : current.nightColor
    };
    this.backgroundStyles = styles;
    this.readerSettingsRevision += 1;
    if (this.readerSettingsLoaded) { this.persistReaderSettings(); }
  }

  /**
   * 删掉一个自建样式。预设那 `READER_STYLE_PRESET_COUNT` 份不能删（上游 `deleteConfigAt`
   * 同样要求 `size > READ_STYLE_PRESET_COUNT`），否则 `paperIndex` 的预设下标语义就断了。
   */
  private removeReaderBackgroundStyle(index: number): void {
    if (index < READER_STYLE_PRESET_COUNT || index >= this.backgroundStyles.length) { return; }
    const styles: ReaderBackgroundStyle[] = copyReaderBackgroundStyles(this.backgroundStyles);
    styles.splice(index, 1);
    this.backgroundStyles = styles;
    // 删掉的那份之前的下标不变；之后的下标整体左移一位。
    const shift = (value: number): number => {
      if (value === index) { return Math.max(0, index - 1); }
      return value > index ? value - 1 : value;
    };
    this.paperIndex = Math.max(0, Math.min(styles.length - 1, shift(this.paperIndex)));
    this.dayPaperIndex = Math.max(0, Math.min(styles.length - 1, shift(this.dayPaperIndex)));
    this.nightPaperIndex = Math.max(0, Math.min(styles.length - 1, shift(this.nightPaperIndex)));
    this.readerSettingsRevision += 1;
    if (this.readerSettingsLoaded) { this.persistReaderSettings(); }
  }

  /**
   * 把自建样式从 from 拖到 to。只在自建区（下标 >= `READER_STYLE_PRESET_COUNT`）内生效，
   * 与上游 `ReadStyleConfigStore.moveStyle()` 的 `isCustomIndex` 判定一致。
   */
  private moveReaderBackgroundStyle(from: number, to: number): void {
    const count = this.backgroundStyles.length;
    if (from < READER_STYLE_PRESET_COUNT || to < READER_STYLE_PRESET_COUNT) { return; }
    if (from >= count || to >= count || from === to) { return; }
    const styles: ReaderBackgroundStyle[] = copyReaderBackgroundStyles(this.backgroundStyles);
    const moved = styles.splice(from, 1)[0];
    styles.splice(to, 0, moved);
    this.backgroundStyles = styles;
    // 与上游 shiftIndexAfterMove 同语义：index==from→to；from<index<=to→index-1；to<=index<from→index+1。
    const shift = (value: number): number => {
      if (value === from) { return to; }
      if (from < value && value <= to) { return value - 1; }
      if (to <= value && value < from) { return value + 1; }
      return value;
    };
    this.paperIndex = shift(this.paperIndex);
    this.dayPaperIndex = shift(this.dayPaperIndex);
    this.nightPaperIndex = shift(this.nightPaperIndex);
    this.readerSettingsRevision += 1;
    if (this.readerSettingsLoaded) { this.persistReaderSettings(); }
  }

  private setReaderShareLayout(shareLayout: boolean): void {
    this.shareReaderStyleLayout = shareLayout;
    if (shareLayout) {
      if (this.readerNightMode) { this.dayPaperIndex = this.nightPaperIndex; }
      else { this.nightPaperIndex = this.dayPaperIndex; }
    }
    this.readerSettingsRevision += 1;
    if (this.readerSettingsLoaded) { this.persistReaderSettings(); }
  }

  /**
   * 阅读页日夜快捷按钮。
   *
   * 上游 `ReadStyleDelegate.kt:455-470`：
   * `val nextIsNight = !(ReadSessionState.isDarkThemeOverride ?: host.isNightTheme)`
   * `val nextMode = if (nextIsNight) "2" else "1"` → 写 appShellSettingsGateway，
   * 即**直接改全局 themeMode**，退出阅读页后书架等页面也是新色。
   * 本地照此实现：不再只翻阅读页私有布尔。
   */
  private toggleReaderNightMode(): void {
    const context = this.getUIContext().getHostContext();
    if (context === undefined) {
      this.showUnavailableAction('无法切换日夜模式，请重试');
      return;
    }
    // 上游 toggleDayNight()（ReadStyleDelegate.kt:451-482）切日夜时顺手做三件事：
    // 刷新冷却起点、复位「已忽略提醒」标记、清掉待弹的 DayNight 提醒。
    // 不清的话，用户刚手动切完日夜还会被问「要不要切日夜」。
    this.readerDayNightReminderLastAt = Date.now();
    this.readerDayNightReminderDismissedDark = false;
    this.readerDayNightReminderDismissedLight = false;
    this.readerDayNightReminderRequestId += 1;
    this.readerDayNightReminderText = '';
    const nextMode = this.readerNightMode ? THEME_MODE_LIGHT : THEME_MODE_DARK;
    this.applyThemeMode(context, nextMode, this.themePaletteIndex, true).then(() => {
      this.paperIndex = this.readerNightMode ? this.nightPaperIndex : this.dayPaperIndex;
      this.readerSettingsRevision += 1;
      if (this.readerSettingsLoaded) { this.persistReaderSettings(); }
    });
  }

  /** 上游 `DARK_LUX_THRESHOLD`（`ReadStyleDelegate.kt:633`）：非夜间模式下 lux 低于它才提示切深色。 */
  private static readonly READER_DARK_LUX_THRESHOLD: number = 8;
  /** 上游 `BRIGHT_LUX_THRESHOLD`（`ReadStyleDelegate.kt:634`）：夜间模式下 lux 高于它才提示切浅色。 */
  private static readonly READER_BRIGHT_LUX_THRESHOLD: number = 100;
  /** 上游 `LIGHT_LUMINANCE_THRESHOLD`（`ReadStyleDelegate.kt:635`）：判断当前背景算不算浅色。 */
  private static readonly READER_LIGHT_LUMINANCE_THRESHOLD: number = 0.35;
  /** 上游 `REMINDER_COOLDOWN_MS`（`ReadStyleDelegate.kt:636`）：两次提醒之间至少隔 10 分钟。 */
  private static readonly READER_REMINDER_COOLDOWN_MS: number = 10 * 60 * 1000;
  /** 提醒胶囊的存活时间，对齐上游 `ThemeReminderCapsule` 的 `delay(5.seconds)`。 */
  private static readonly READER_REMINDER_VISIBLE_MS: number = 5000;

  /**
   * 把 `#RRGGBB`/`#AARRGGBB` 换算成 0..1 的相对亮度，口径对齐 Android 的
   * `ColorUtils.calculateLuminance`（先线性化再按 0.2126/0.7152/0.0722 加权）。
   * 无法解析时返回 -1，调用方按「无法判断」处理。
   */
  private computeReaderColorLuminance(color: string): number {
    const hex = color.startsWith('#') ? color.slice(1) : color;
    if (hex.length !== 6 && hex.length !== 8) { return -1; }
    const rgbText = hex.length === 8 ? hex.slice(2) : hex;
    const value = Number.parseInt(rgbText, 16);
    if (Number.isNaN(value)) { return -1; }
    const channel = (shift: number): number => {
      const srgb = ((value >> shift) & 0xFF) / 255;
      return srgb <= 0.03928 ? srgb / 12.92 : Math.pow((srgb + 0.055) / 1.055, 2.4);
    };
    return 0.2126 * channel(16) + 0.7152 * channel(8) + 0.0722 * channel(0);
  }

  /** 当前背景算不算浅色；颜色解析不出来时按上游口径回落「算浅色」。 */
  private isReaderBackgroundLight(): boolean {
    const luminance = this.computeReaderColorLuminance(this.getPaperColor());
    if (luminance < 0) { return true; }
    return luminance >= Index.READER_LIGHT_LUMINANCE_THRESHOLD;
  }

  private isReaderDayNightReminderCoolingDown(): boolean {
    return Date.now() - this.readerDayNightReminderLastAt < Index.READER_REMINDER_COOLDOWN_MS;
  }

  /**
   * 环境光变化时判断要不要提示切换日夜，逐条照上游 `ReadStyleDelegate.checkSwitchDayNight()`：
   * 只在「当前背景确实与目标模式相反」时提示——深色模式配浅色背景时不该劝用户切回去。
   */
  private checkReaderDayNightReminder(lux: number): void {
    if (!this.readerAutoSuggestDayNight || this.isReaderDayNightReminderCoolingDown()) { return; }
    const isNight = this.readerNightMode;
    if (!isNight && lux <= Index.READER_DARK_LUX_THRESHOLD) {
      if (this.readerDayNightReminderDismissedDark) { return; }
      if (!this.isReaderBackgroundLight()) { return; }
      this.showReaderDayNightReminder(true);
    } else if (isNight && lux >= Index.READER_BRIGHT_LUX_THRESHOLD) {
      if (this.readerDayNightReminderDismissedLight) { return; }
      if (this.isReaderBackgroundLight()) { return; }
      this.showReaderDayNightReminder(false);
    }
  }

  private showReaderDayNightReminder(targetNight: boolean): void {
    this.readerDayNightReminderLastAt = Date.now();
    this.readerDayNightReminderText = targetNight
      ? '当前环境光较暗，是否切换至深色模式？'
      : '当前环境光较亮，是否切换至浅色模式？';
    this.readerDayNightReminderTargetNight = targetNight;
    this.readerDayNightReminderRequestId += 1;
    const requestId = this.readerDayNightReminderRequestId;
    // 对齐上游 ThemeReminderCapsule 的 5 秒自动消失。
    setTimeout(() => {
      if (this.readerDayNightReminderRequestId !== requestId) { return; }
      this.readerDayNightReminderText = '';
    }, Index.READER_REMINDER_VISIBLE_MS);
  }

  /** 点「切换到深色/浅色模式」：先关提醒，再切换；切换本身会重置冷却与两个拒绝标记。 */
  private acceptReaderDayNightReminder(): void {
    const targetNight = this.readerDayNightReminderTargetNight;
    this.readerDayNightReminderText = '';
    if (this.readerNightMode !== targetNight) {
      this.toggleReaderNightMode();
    }
  }

  /** 点「关闭」：记住这一类提醒本次会话不再出现，对齐上游 `dismissReminder()` 的两个标记。 */
  private dismissReaderDayNightReminder(): void {
    if (this.readerDayNightReminderTargetNight) {
      this.readerDayNightReminderDismissedDark = true;
    } else {
      this.readerDayNightReminderDismissedLight = true;
    }
    this.readerDayNightReminderText = '';
  }

  /** 进出阅读页时开关环境光订阅；上游是 repeatOnLifecycle(RESUMED) 里起、离开即停。 */
  private onReaderRouteChanged(): void {
    if (this.route === AppRoute.READER) {
      this.startReaderAmbientLightWatch();
    } else {
      this.stopReaderAmbientLightWatch();
      this.readerDayNightReminderText = '';
    }
  }

  private onReaderAutoSuggestDayNightChanged(): void {
    if (this.readerAutoSuggestDayNight && this.route === AppRoute.READER) {
      this.startReaderAmbientLightWatch();
    } else {
      this.stopReaderAmbientLightWatch();
      this.readerDayNightReminderText = '';
    }
  }

  private startReaderAmbientLightWatch(): void {
    if (this.readerAmbientLightSubscribed || !this.readerAutoSuggestDayNight) { return; }
    try {
      sensor.on(sensor.SensorId.AMBIENT_LIGHT, (data: sensor.LightResponse) => {
        this.checkReaderDayNightReminder(data.intensity);
      }, { interval: 1000000000 });
      this.readerAmbientLightSubscribed = true;
    } catch (_) {
      // 设备没有环境光传感器或订阅被拒时静默跳过，不影响阅读。
      this.readerAmbientLightSubscribed = false;
    }
  }

  private stopReaderAmbientLightWatch(): void {
    if (!this.readerAmbientLightSubscribed) { return; }
    try {
      sensor.off(sensor.SensorId.AMBIENT_LIGHT);
    } catch (_) {
    }
    this.readerAmbientLightSubscribed = false;
  }

  private isEyeProtectionActive(): boolean {
    return EyeProtection.isActiveAt(
      this.eyeProtectionEnabled,
      this.eyeProtectionAutoNight,
      this.readerNightMode,
      this.eyeProtectionSchedule,
      this.eyeProtectionStartTime,
      this.eyeProtectionEndTime,
      this.eyeProtectionMinuteOfDay()
    );
  }

  /** 当天已过的本地分钟数；`eyeProtectionMinute` 是 epoch 分钟，这里按本地时区折算。 */
  private eyeProtectionMinuteOfDay(): number {
    const now = new Date(this.eyeProtectionMinute * 60000);
    return now.getHours() * 60 + now.getMinutes();
  }

  /** 护眼覆盖层颜色；空串表示当前不需要覆盖，对齐上游强度 <= 0 时不加滤镜。 */
  private eyeProtectionOverlayColor(): string {
    if (!this.isEyeProtectionActive()) { return ''; }
    return EyeProtection.overlayColorForIntensity(this.eyeProtectionIntensity);
  }

  private parseEyeProtectionMinutes(value: string): number {
    return EyeProtection.parseTime(value);
  }

  private commitEyeProtectionChange(): void {
    this.readerSettingsRevision += 1;
    if (this.readerSettingsLoaded) { this.persistReaderSettings(); }
  }

  private setEyeProtectionEnabled(enabled: boolean): void {
    this.eyeProtectionEnabled = enabled;
    this.commitEyeProtectionChange();
  }

  private setEyeProtectionAutoNight(enabled: boolean): void {
    this.eyeProtectionAutoNight = enabled;
    this.commitEyeProtectionChange();
  }

  private setEyeProtectionSchedule(enabled: boolean): void {
    this.eyeProtectionSchedule = enabled;
    this.commitEyeProtectionChange();
  }

  private setEyeProtectionIntensity(intensity: number): void {
    this.eyeProtectionIntensity = Math.max(0, Math.min(100, Math.round(intensity)));
    this.commitEyeProtectionChange();
  }

  private setEyeProtectionStartTime(time: string): void {
    this.eyeProtectionStartTime = time;
    this.commitEyeProtectionChange();
  }

  private setEyeProtectionEndTime(time: string): void {
    this.eyeProtectionEndTime = time;
    this.commitEyeProtectionChange();
  }

  private toggleEyeProtection(): void {
    if (this.eyeProtectionEnabled || this.eyeProtectionAutoNight) {
      this.setEyeProtectionEnabled(false);
      this.setEyeProtectionAutoNight(false);
    } else {
      this.setEyeProtectionEnabled(true);
    }
  }

  private setReaderBottomActionText(enabled: boolean): void {
    this.showReaderBottomActionText = enabled;
    this.readerSettingsRevision += 1;
    if (this.readerSettingsLoaded) { this.persistReaderSettings(); }
  }

  private setReaderBottomIconStyle(style: number): void {
    this.readerBottomIconStyle = Math.max(0, Math.min(2, Math.round(style)));
    this.readerSettingsRevision += 1;
    if (this.readerSettingsLoaded) { this.persistReaderSettings(); }
  }

  private setReaderBottomItemsPerRow(count: number): void {
    this.readerBottomItemsPerRow = Math.max(2, Math.min(8, Math.round(count)));
    this.readerSettingsRevision += 1;
    if (this.readerSettingsLoaded) { this.persistReaderSettings(); }
  }

  private setReaderBottomRowCount(count: number): void {
    this.readerBottomRowCount = Math.max(1, Math.min(2, Math.round(count)));
    this.readerSettingsRevision += 1;
    if (this.readerSettingsLoaded) { this.persistReaderSettings(); }
  }

  private setReaderBottomActions(actions: ReaderBottomActionConfig[]): void {
    this.readerBottomActions = actions.map((item: ReaderBottomActionConfig): ReaderBottomActionConfig => ({
      id: item.id,
      enabled: item.enabled
    }));
    this.readerSettingsRevision += 1;
    if (this.readerSettingsLoaded) { this.persistReaderSettings(); }
  }

  private setReaderTopActions(actions: ReaderBottomActionConfig[]): void {
    this.readerTopActions = actions.map((item: ReaderBottomActionConfig): ReaderBottomActionConfig => ({
      id: item.id,
      enabled: item.enabled
    }));
    this.readerSettingsRevision += 1;
    if (this.readerSettingsLoaded) { this.persistReaderSettings(); }
  }

  private setReaderProgressBehavior(value: string): void {
    this.readerProgressBehavior = value === 'chapter' ? 'chapter' : 'page';
    this.readerSettingsRevision += 1;
    if (this.readerSettingsLoaded) { this.persistReaderSettings(); }
  }

  private setReaderReadSliderMode(value: string): void {
    this.readerReadSliderMode = value === '1' ? '1' : '0';
    this.readerSettingsRevision += 1;
    if (this.readerSettingsLoaded) { this.persistReaderSettings(); }
  }

  private setReaderPageTouchSlop(value: number): void {
    this.readerPageTouchSlop = Math.max(0, Math.min(1000, Math.round(value)));
    this.readerSettingsRevision += 1;
    if (this.readerSettingsLoaded) { this.persistReaderSettings(); }
  }

  private setReaderLastMarkingStyle(value: string): void {
    this.readerLastMarkingStyle = value;
    this.readerSettingsRevision += 1;
    if (this.readerSettingsLoaded) { this.persistReaderSettings(); }
  }

  private setReaderPaddingSettings(settings: ReaderPaddingSettings): void {
    this.readerPaddingSettings = copyReaderPaddingSettings(settings);
    this.readerSettingsRevision += 1;
    if (this.readerSettingsLoaded) { this.persistReaderSettings(); }
  }

  private setReaderScreenOrientation(orientation: string): void {
    this.readerScreenOrientation = ['0', '1', '2', '3', '4', '5'].includes(orientation) ? orientation : '0';
    this.readerSettingsRevision += 1;
    if (this.readerSettingsLoaded) { this.persistReaderSettings(); }
  }

  private setReaderKeepLight(value: string): void {
    this.readerKeepLight = ['0', '60', '300', '600', '-1'].includes(value) ? value : '0';
    this.readerSettingsRevision += 1;
    if (this.readerSettingsLoaded) { this.persistReaderSettings(); }
  }

  private setReaderVolumeKeyPage(enabled: boolean): void {
    this.readerVolumeKeyPage = enabled;
    this.readerSettingsRevision += 1;
    if (this.readerSettingsLoaded) { this.persistReaderSettings(); }
  }

  private setReaderKeyPageOnLongPress(enabled: boolean): void {
    this.readerKeyPageOnLongPress = enabled;
    this.readerSettingsRevision += 1;
    if (this.readerSettingsLoaded) { this.persistReaderSettings(); }
  }

  private setReaderNoAnimScrollPage(enabled: boolean): void {
    this.readerNoAnimScrollPage = enabled;
    this.readerSettingsRevision += 1;
    if (this.readerSettingsLoaded) { this.persistReaderSettings(); }
  }

  private setReaderPrevKeys(value: string): void {
    this.readerPrevKeys = value;
    this.readerSettingsRevision += 1;
    if (this.readerSettingsLoaded) { this.persistReaderSettings(); }
  }

  private setReaderNextKeys(value: string): void {
    this.readerNextKeys = value;
    this.readerSettingsRevision += 1;
    if (this.readerSettingsLoaded) { this.persistReaderSettings(); }
  }

  private setReaderMouseWheelPage(enabled: boolean): void {
    this.readerMouseWheelPage = enabled;
    this.readerSettingsRevision += 1;
    if (this.readerSettingsLoaded) { this.persistReaderSettings(); }
  }

  private setReaderExpandTextMenu(enabled: boolean): void {
    this.readerExpandTextMenu = enabled;
    this.readerSettingsRevision += 1;
    if (this.readerSettingsLoaded) { this.persistReaderSettings(); }
  }

  private setReaderShowSelectMenuIcon(enabled: boolean): void {
    this.readerShowSelectMenuIcon = enabled;
    this.readerSettingsRevision += 1;
    if (this.readerSettingsLoaded) { this.persistReaderSettings(); }
  }

  private setReaderTextSelectMenuConfig(value: string): void {
    this.readerTextSelectMenuConfig = value;
    this.readerSettingsRevision += 1;
    if (this.readerSettingsLoaded) { this.persistReaderSettings(); }
  }

  /** 横屏双页档位：只认上游那四档，其余一律回到全局单页。 */
  private setReaderDoubleHorizontalPage(value: string): void {
    this.readerDoubleHorizontalPage = value === '1' || value === '2' || value === '3' ? value : '0';
    this.readerSettingsRevision += 1;
    if (this.readerSettingsLoaded) {
      this.persistReaderSettings();
    }
  }

  /** 打开环境光提醒时复位「本会话已关闭提醒」的两个标记，对齐上游 `resetDayNightReminderDismissal()`。 */
  private setReaderAutoSuggestDayNight(enabled: boolean): void {
    this.readerAutoSuggestDayNight = enabled === true;
    if (enabled) {
      this.readerDayNightReminderDismissedDark = false;
      this.readerDayNightReminderDismissedLight = false;
    }
    this.readerSettingsRevision += 1;
    if (this.readerSettingsLoaded) {
      this.persistReaderSettings();
    }
  }

  /** 禁用返回键；上游 UI 侧无消费点，本地只做可配 + 落库 + 随备份（见 KNOWN-ISSUES KI-A3）。 */
  private setReaderDisableReturnKey(enabled: boolean): void {
    this.readerDisableReturnKey = enabled === true;
    this.readerSettingsRevision += 1;
    if (this.readerSettingsLoaded) {
      this.persistReaderSettings();
    }
  }

  /** 阅读亮度：夹 1..100（上游按 readBrightness/100 设窗口亮度，0 会全黑）。 */
  private setReaderReadBrightness(value: number): void {
    this.readerReadBrightness = Math.max(1, Math.min(100, Math.round(value)));
    this.readerSettingsRevision += 1;
    if (this.readerSettingsLoaded) {
      this.persistReaderSettings();
    }
  }

  private setReaderShowBrightnessView(value: string): void {
    this.readerShowBrightnessView = value === '1' || value === '2' ? value : '0';
    this.readerSettingsRevision += 1;
    if (this.readerSettingsLoaded) {
      this.persistReaderSettings();
    }
  }

  private setReaderBrightnessVwPos(value: string): void {
    this.readerBrightnessVwPos = value === '0' ? '0' : '1';
    this.readerSettingsRevision += 1;
    if (this.readerSettingsLoaded) {
      this.persistReaderSettings();
    }
  }

  /** 亮度跟随系统开关；上游 `ReadBookIntent.ToggleBrightnessAuto`（`ReadBookViewModel.kt:1007`）。 */
  private setReaderBrightnessAuto(enabled: boolean): void {
    this.readerBrightnessAuto = enabled !== false;
    this.readerSettingsRevision += 1;
    if (this.readerSettingsLoaded) {
      this.persistReaderSettings();
    }
  }

  /** 正文行高适配开关；上游 `ConfigUpdate.ReadBodyToLh`（`ReadBookContract.kt:1958`）。 */
  private setReaderReadBodyToLh(enabled: boolean): void {
    this.readerReadBodyToLh = enabled !== false;
    this.readerSettingsRevision += 1;
    if (this.readerSettingsLoaded) {
      this.persistReaderSettings();
    }
  }

  /** 自定义中文分行开关；上游 `ConfigUpdate.UseZhLayout`（`ReadBookContract.kt:1973`）。只改分页输入，不重读章节。 */
  private setReaderUseZhLayout(enabled: boolean): void {
    this.readerUseZhLayout = enabled === true;
    this.readerSettingsRevision += 1;
    if (this.readerSettingsLoaded) {
      this.persistReaderSettings();
    }
  }

  /** 正文避让显示缺口；上游 `ReadConfigIntent.PaddingDisplayCutoutsChanged`（`ReadConfigViewModel.kt:111`）。 */
  private setReaderPaddingDisplayCutouts(enabled: boolean): void {
    this.readerPaddingDisplayCutouts = enabled === true;
    this.readerSettingsRevision += 1;
    if (this.readerSettingsLoaded) {
      this.persistReaderSettings();
    }
  }

  /** 适配特殊样式；上游 `ConfigUpdate.AdaptSpecialStyle`，改动会改变 `[newpage]`/`<usehtml>` 的解释方式，需重读章节。 */
  private setReaderAdaptSpecialStyle(enabled: boolean): void {
    this.readerAdaptSpecialStyle = enabled !== false;
    this.readerSettingsRevision += 1;
    if (this.readerSettingsLoaded) {
      this.persistReaderSettings();
    }
    this.reloadSelectedChapterForTransform();
  }

  private setReaderReadMenuBottomCornerRadius(value: number): void {
    this.readerReadMenuBottomCornerRadius = Math.max(0, Math.min(32, Math.round(value)));
    this.readerSettingsRevision += 1;
    if (this.readerSettingsLoaded) {
      this.persistReaderSettings();
    }
  }

  private setReaderReadMenuFloatingBottomBar(enabled: boolean): void {
    this.readerReadMenuFloatingBottomBar = enabled;
    this.readerSettingsRevision += 1;
    if (this.readerSettingsLoaded) {
      this.persistReaderSettings();
    }
  }

  private setReaderReadMenuBottomBarBlurMode(value: number): void {
    this.readerReadMenuBottomBarBlurMode = Math.max(0, Math.min(2, Math.round(value)));
    this.readerSettingsRevision += 1;
    if (this.readerSettingsLoaded) {
      this.persistReaderSettings();
    }
  }

  private setReaderReadMenuBottomBarBlurStyle(value: number): void {
    this.readerReadMenuBottomBarBlurStyle = value === 1 ? 1 : 0;
    this.readerSettingsRevision += 1;
    if (this.readerSettingsLoaded) {
      this.persistReaderSettings();
    }
  }

  private setReaderReadMenuBottomBarLiquidGlassButtons(enabled: boolean): void {
    this.readerReadMenuBottomBarLiquidGlassButtons = enabled;
    this.readerSettingsRevision += 1;
    if (this.readerSettingsLoaded) {
      this.persistReaderSettings();
    }
  }

  private setReaderReadMenuBlurAlpha(value: number): void {
    this.readerReadMenuBlurAlpha = Math.max(0, Math.min(100, Math.round(value)));
    this.readerSettingsRevision += 1;
    if (this.readerSettingsLoaded) {
      this.persistReaderSettings();
    }
  }

  private setReaderReadMenuTopBarTitleCapsule(enabled: boolean): void {
    this.readerReadMenuTopBarTitleCapsule = enabled;
    this.readerSettingsRevision += 1;
    if (this.readerSettingsLoaded) {
      this.persistReaderSettings();
    }
  }

  /** 标题栏显示方式只接受上游四值 "0"-"3"，其余回默认 "1"。 */
  private setReaderTitleBarMode(value: string): void {
    this.readerTitleBarMode = ['0', '1', '2', '3'].includes(value) ? value : '1';
    this.readerSettingsRevision += 1;
    if (this.readerSettingsLoaded) {
      this.persistReaderSettings();
    }
  }

  private setReaderTitleBarCompact(enabled: boolean): void {
    this.readerTitleBarCompact = enabled;
    this.readerSettingsRevision += 1;
    if (this.readerSettingsLoaded) {
      this.persistReaderSettings();
    }
  }

  private setReaderTitleBarIconStyle(value: number): void {
    this.readerTitleBarIconStyle = Math.max(0, Math.min(2, Math.round(value)));
    this.readerSettingsRevision += 1;
    if (this.readerSettingsLoaded) {
      this.persistReaderSettings();
    }
  }

  private setReaderReadMenuTopBarBlurMode(value: number): void {
    this.readerReadMenuTopBarBlurMode = Math.max(0, Math.min(2, Math.round(value)));
    this.readerSettingsRevision += 1;
    if (this.readerSettingsLoaded) {
      this.persistReaderSettings();
    }
  }

  private setReaderReadMenuTopBarBlurStyle(value: number): void {
    this.readerReadMenuTopBarBlurStyle = value === 1 ? 1 : 0;
    this.readerSettingsRevision += 1;
    if (this.readerSettingsLoaded) {
      this.persistReaderSettings();
    }
  }

  private setReaderReadMenuTopBarLiquidGlassButtons(enabled: boolean): void {
    this.readerReadMenuTopBarLiquidGlassButtons = enabled;
    this.readerSettingsRevision += 1;
    if (this.readerSettingsLoaded) {
      this.persistReaderSettings();
    }
  }

  private setReaderReadMenuTopBarMergeButtons(enabled: boolean): void {
    this.readerReadMenuTopBarMergeButtons = enabled;
    this.readerSettingsRevision += 1;
    if (this.readerSettingsLoaded) {
      this.persistReaderSettings();
    }
  }

  private setReaderReadBarStyle(value: number): void {
    this.readerReadBarStyle = Math.max(0, Math.min(2, Math.round(value)));
    this.readerSettingsRevision += 1;
    if (this.readerSettingsLoaded) {
      this.persistReaderSettings();
    }
  }

  private setReaderShowMenuIcon(enabled: boolean): void {
    this.readerShowMenuIcon = enabled === true;
    this.readerSettingsRevision += 1;
    if (this.readerSettingsLoaded) {
      this.persistReaderSettings();
    }
  }

  private setReaderShowReadTitleAddition(enabled: boolean): void {
    this.readerShowReadTitleAddition = enabled === true;
    this.readerSettingsRevision += 1;
    if (this.readerSettingsLoaded) {
      this.persistReaderSettings();
    }
  }

  /** 菜单不透明度夹 0-100，对齐上游 `ReadSettings.kt:13` 的默认值 100。 */
  private setReaderMenuAlpha(value: number): void {
    this.readerMenuAlpha = Math.max(0, Math.min(100, Math.round(value)));
    this.readerSettingsRevision += 1;
    if (this.readerSettingsLoaded) {
      this.persistReaderSettings();
    }
  }

  private setReaderReadMenuPaletteStyle(value: string): void {
    // 空串（跟随系统）是合法值，其余交给数据层白名单过滤。
    this.readerMenuPaletteStyle = value;
    this.readerSettingsRevision += 1;
    if (this.readerSettingsLoaded) {
      this.persistReaderSettings();
    }
  }

  private setReaderReadMenuColorMode(value: number): void {
    this.readerMenuColorMode = Math.max(0, Math.min(1, Math.round(value)));
    this.readerSettingsRevision += 1;
    if (this.readerSettingsLoaded) {
      this.persistReaderSettings();
    }
  }

  private setReaderReadMenuBgColor(value: string): void {
    // 空串表示未设置，颜色交给数据层 normalizeOptionalHexColor 过滤。
    this.readerMenuBgColor = value;
    this.readerSettingsRevision += 1;
    if (this.readerSettingsLoaded) {
      this.persistReaderSettings();
    }
  }

  private setReaderReadMenuBgColorNight(value: string): void {
    // 空串表示未设置，颜色交给数据层 normalizeOptionalHexColor 过滤。
    this.readerMenuBgColorNight = value;
    this.readerSettingsRevision += 1;
    if (this.readerSettingsLoaded) {
      this.persistReaderSettings();
    }
  }

  private setReaderReadMenuContainerColor(value: string): void {
    // 空串表示未设置，颜色交给数据层 normalizeOptionalHexColor 过滤。
    this.readerMenuContainerColor = value;
    this.readerSettingsRevision += 1;
    if (this.readerSettingsLoaded) {
      this.persistReaderSettings();
    }
  }

  private setReaderReadMenuContainerColorNight(value: string): void {
    // 空串表示未设置，颜色交给数据层 normalizeOptionalHexColor 过滤。
    this.readerMenuContainerColorNight = value;
    this.readerSettingsRevision += 1;
    if (this.readerSettingsLoaded) {
      this.persistReaderSettings();
    }
  }

  private setReaderReadMenuAccentColor(value: string): void {
    // 空串表示未设置，颜色交给数据层 normalizeOptionalHexColor 过滤。
    this.readerMenuAccentColor = value;
    this.readerSettingsRevision += 1;
    if (this.readerSettingsLoaded) {
      this.persistReaderSettings();
    }
  }

  private setReaderReadMenuAccentColorNight(value: string): void {
    // 空串表示未设置，颜色交给数据层 normalizeOptionalHexColor 过滤。
    this.readerMenuAccentColorNight = value;
    this.readerSettingsRevision += 1;
    if (this.readerSettingsLoaded) {
      this.persistReaderSettings();
    }
  }

  private setReaderShowTitleBarIcons(value: boolean): void {
    this.readerShowTitleBarIcons = value === true;
    this.readerSettingsRevision += 1;
    if (this.readerSettingsLoaded) {
      this.persistReaderSettings();
    }
  }

  /** 浮动图标位置夹在 0-3（上游 `ReadBookConfig.kt:116` 的 coerceIn(0, 3)）。 */
  private setReaderTitleBarIconPosition(value: number): void {
    this.readerTitleBarIconPosition = Number.isFinite(value)
      ? Math.max(0, Math.min(3, Math.round(value))) : 3;
    this.readerSettingsRevision += 1;
    if (this.readerSettingsLoaded) {
      this.persistReaderSettings();
    }
  }

  private setReaderReadMenuFloatingIconLiquidGlass(value: boolean): void {
    this.readerReadMenuFloatingIconLiquidGlass = value === true;
    this.readerSettingsRevision += 1;
    if (this.readerSettingsLoaded) {
      this.persistReaderSettings();
    }
  }

  /** 浮动图标行按钮池整体替换（与顶栏操作按钮同构）。 */
  private setReaderFloatingIcons(value: ReaderBottomActionConfig[]): void {
    this.readerFloatingIcons = value.map(
      (item: ReaderBottomActionConfig): ReaderBottomActionConfig => ({ id: item.id, enabled: item.enabled })
    );
    this.readerSettingsRevision += 1;
    if (this.readerSettingsLoaded) {
      this.persistReaderSettings();
    }
  }

  private setReaderTitleBarCustomIcons(value: string): void {
    this.readerTitleBarCustomIcons = value;
    this.readerSettingsRevision += 1;
    if (this.readerSettingsLoaded) {
      this.persistReaderSettings();
    }
  }

  private setReaderReadMenuCustomIcons(value: string): void {
    this.readerReadMenuCustomIcons = value;
    this.readerSettingsRevision += 1;
    if (this.readerSettingsLoaded) {
      this.persistReaderSettings();
    }
  }

  private setReaderReadMenuBorderWidth(value: number): void {
    if (!Number.isFinite(value)) {
      return;
    }
    this.readerMenuBorderWidth = Math.max(0, Math.min(4, Math.round(value)));
    this.readerSettingsRevision += 1;
    if (this.readerSettingsLoaded) {
      this.persistReaderSettings();
    }
  }

  private setReaderReadMenuBorderColor(value: string): void {
    this.readerMenuBorderColor = typeof value === 'string' ? value : '';
    this.readerSettingsRevision += 1;
    if (this.readerSettingsLoaded) {
      this.persistReaderSettings();
    }
  }

  private setReaderReadMenuBorderColorNight(value: string): void {
    this.readerMenuBorderColorNight = typeof value === 'string' ? value : '';
    this.readerSettingsRevision += 1;
    if (this.readerSettingsLoaded) {
      this.persistReaderSettings();
    }
  }

  private setReaderReadMenuBlurRadius(value: number): void {
    if (!Number.isFinite(value)) {
      return;
    }
    this.readerMenuBlurRadius = Math.max(0, Math.min(32, Math.round(value)));
    this.readerSettingsRevision += 1;
    if (this.readerSettingsLoaded) {
      this.persistReaderSettings();
    }
  }

  private setReaderReadMenuTextColor(value: string): void {
    this.readerMenuTextColor = typeof value === 'string' ? value : '';
    this.readerSettingsRevision += 1;
    if (this.readerSettingsLoaded) {
      this.persistReaderSettings();
    }
  }

  private setReaderReadMenuTextColorNight(value: string): void {
    this.readerMenuTextColorNight = typeof value === 'string' ? value : '';
    this.readerSettingsRevision += 1;
    if (this.readerSettingsLoaded) {
      this.persistReaderSettings();
    }
  }

  private setReaderReadMenuBlurColor(value: string): void {
    this.readerMenuBlurColor = typeof value === 'string' ? value : '';
    this.readerSettingsRevision += 1;
    if (this.readerSettingsLoaded) {
      this.persistReaderSettings();
    }
  }

  private setReaderReadMenuBlurColorNight(value: string): void {
    this.readerMenuBlurColorNight = typeof value === 'string' ? value : '';
    this.readerSettingsRevision += 1;
    if (this.readerSettingsLoaded) {
      this.persistReaderSettings();
    }
  }

  private setReaderReadingAnchorEnabled(enabled: boolean): void {
    this.readerReadingAnchorEnabled = enabled;
    this.readerSettingsRevision += 1;
    if (this.readerSettingsLoaded) { this.persistReaderSettings(); }
  }

  private setReaderSwipeToAddBookmark(enabled: boolean): void {
    this.readerSwipeToAddBookmark = enabled;
    this.readerSettingsRevision += 1;
    if (this.readerSettingsLoaded) { this.persistReaderSettings(); }
  }
  /** 调整阅读页书签角标宽度；0 表示不显示角标（与上游一致）。 */
  private setReaderBookmarkBadgeSize(value: number): void {
    this.readerBookmarkBadgeSize = Math.max(0, Math.min(50, Math.round(value)));
    this.readerSettingsRevision += 1;
    if (this.readerSettingsLoaded) { this.persistReaderSettings(); }
  }
  /**
   * 选一张本地图片作为阅读页书签角标。
   * 图片先复制进应用私有目录（系统选择器的授权是临时的），再把路径写进设置；
   * 旧图片在切换成功后删除，避免私有目录累积。
   */
  private async pickReaderBookmarkBadgeImage(): Promise<void> {
    const context = this.getUIContext().getHostContext();
    if (context === undefined) { return; }
    let picked: string | undefined = undefined;
    try {
      picked = await ReaderBookmarkBadgeRepository.chooseImage(context);
    } catch (error) {
      const message = error instanceof Error ? error.message : '选择书签角标图片失败';
      this.showUnavailableAction(message);
      return;
    }
    if (picked === undefined) { return; }
    const previous = this.readerBookmarkBadgeImage;
    this.readerBookmarkBadgeImage = picked;
    this.readerSettingsRevision += 1;
    if (this.readerSettingsLoaded) { this.persistReaderSettings(); }
    if (previous.length > 0 && previous !== picked) {
      ReaderBookmarkBadgeRepository.removeImage(previous);
    }
  }
  /** 选择日间/夜间背景图片；换图时删掉上一张副本。 */
  private async pickReaderBackgroundImage(night: boolean): Promise<void> {
    const context = this.getUIContext().getHostContext();
    if (context === undefined) { return; }
    let picked: string | undefined = undefined;
    try {
      picked = await ReaderBackgroundImageRepository.chooseImage(context);
    } catch (error) {
      const message = error instanceof Error ? error.message : '选择背景图片失败';
      this.showUnavailableAction(message);
      return;
    }
    if (picked === undefined) { return; }
    const previous = night ? this.readerBgStrNight : this.readerBgStr;
    const previousType = night ? this.readerBgTypeNight : this.readerBgType;
    this.setReaderBackgroundImage(picked, night);
    // 只有上一张也是本仓储的图片副本时才删；如果上一张是纯色就没什么可删。
    if (previousType !== 0 && previous.length > 0 && previous !== picked) {
      ReaderBackgroundImageRepository.removeImage(previous);
    }
  }
  /** 恢复默认书签角标：清空设置并删掉私有目录里的图片副本。 */
  private resetReaderBookmarkBadgeImage(): void {
    const previous = this.readerBookmarkBadgeImage;
    this.readerBookmarkBadgeImage = '';
    this.readerSettingsRevision += 1;
    if (this.readerSettingsLoaded) { this.persistReaderSettings(); }
    if (previous.length > 0) { ReaderBookmarkBadgeRepository.removeImage(previous); }
  }
  private setReaderSelectText(enabled: boolean): void {
    this.readerSelectText = enabled;
    this.readerSettingsRevision += 1;
    if (this.readerSettingsLoaded) { this.persistReaderSettings(); }
  }
  private setReaderSliderVibrator(enabled: boolean): void {
    this.readerSliderVibrator = enabled;
    this.readerSettingsRevision += 1;
    if (this.readerSettingsLoaded) { this.persistReaderSettings(); }
  }
  private setReaderSelectVibrator(enabled: boolean): void {
    this.readerSelectVibrator = enabled;
    this.readerSettingsRevision += 1;
    if (this.readerSettingsLoaded) { this.persistReaderSettings(); }
  }
  private setReaderChineseConverterType(value: number): void {
    this.readerChineseConverterType = value === 1 ? 1 : (value === 2 ? 2 : 0);
    // 正文管线是静态方法，注入后需要重读当前章节才会体现，由调用方负责刷新。
    BookRepository.setChineseConverterType(this.readerChineseConverterType);
    ReplaceRuleRepository.setChineseConverterType(this.readerChineseConverterType);
    this.readerSettingsRevision += 1;
    if (this.readerSettingsLoaded) { this.persistReaderSettings(); }
    // 正文是按已转换结果缓存的，档位变了必须重读，否则要等下次翻页才生效。
    this.reloadSelectedChapterForTransform();
  }
  /** 颜色类设置统一走这里：只改显示，不重读正文，因此不必触发章节重载。 */
  private setReaderTextColor(value: string, night: boolean): void {
    if (night) { this.readerTextColorNight = value; } else { this.readerTextColor = value; }
    this.readerSettingsRevision += 1;
    if (this.readerSettingsLoaded) { this.persistReaderSettings(); }
  }
  private setReaderTextAccentColor(value: string, night: boolean): void {
    if (night) { this.readerTextAccentColorNight = value; } else { this.readerTextAccentColor = value; }
    this.readerSettingsRevision += 1;
    if (this.readerSettingsLoaded) { this.persistReaderSettings(); }
  }
  /**
   * 自定义背景色。传空串表示清除自定义、回落到 paperIndex 的六个内置方案，
   * 因此不能像其他颜色那样在空串时回落默认色。
   */
  private setReaderBackgroundColor(value: string, night: boolean): void {
    if (night) { this.readerBgStrNight = value; } else { this.readerBgStr = value; }
    this.readerSettingsRevision += 1;
    if (this.readerSettingsLoaded) { this.persistReaderSettings(); }
  }
  /** 自定义背景图片：设置时同时把 bgType 置 2，清除时回到 0 并清空路径。 */
  private setReaderBackgroundImage(path: string, night: boolean): void {
    if (night) {
      this.readerBgStrNight = path;
      this.readerBgTypeNight = path.length > 0 ? 2 : 0;
    } else {
      this.readerBgStr = path;
      this.readerBgType = path.length > 0 ? 2 : 0;
    }
    this.readerSettingsRevision += 1;
    if (this.readerSettingsLoaded) { this.persistReaderSettings(); }
  }
  private setReaderBgAlpha(value: number): void {
    this.readerBgAlpha = Math.max(0, Math.min(100, Math.round(value)));
    this.readerSettingsRevision += 1;
    if (this.readerSettingsLoaded) { this.persistReaderSettings(); }
  }
  private setReaderDarkStatusIcon(enabled: boolean, night: boolean): void {
    if (night) { this.readerDarkStatusIconNight = enabled; } else { this.readerDarkStatusIcon = enabled; }
    this.readerSettingsRevision += 1;
    if (this.readerSettingsLoaded) { this.persistReaderSettings(); }
  }
  // 标题排版：改样式只影响排版与绘制，不需要重读章节内容。
  private setReaderTitleMode(value: number): void {
    this.readerTitleMode = Math.max(0, Math.min(2, Math.round(value)));
    this.readerSettingsRevision += 1;
    if (this.readerSettingsLoaded) { this.persistReaderSettings(); }
  }
  private setReaderTitleSize(value: number): void {
    this.readerTitleSize = Math.max(0, Math.min(100, Math.round(value)));
    this.readerSettingsRevision += 1;
    if (this.readerSettingsLoaded) { this.persistReaderSettings(); }
  }
  private setReaderTitleSizeRelative(relative: boolean): void {
    this.readerTitleSizeRelative = relative;
    this.readerSettingsRevision += 1;
    if (this.readerSettingsLoaded) { this.persistReaderSettings(); }
  }
  private setReaderTitleSpacing(top: number, bottom: number): void {
    this.readerTitleTopSpacing = Math.max(0, Math.min(100, Math.round(top)));
    this.readerTitleBottomSpacing = Math.max(0, Math.min(100, Math.round(bottom)));
    this.readerSettingsRevision += 1;
    if (this.readerSettingsLoaded) { this.persistReaderSettings(); }
  }
  private setReaderTitleColor(value: string, night: boolean): void {
    if (night) { this.readerTitleColorNight = value; } else { this.readerTitleColor = value; }
    this.readerSettingsRevision += 1;
    if (this.readerSettingsLoaded) { this.persistReaderSettings(); }
  }
  private setReaderTitleBold(value: number): void {
    this.readerTitleBold = Math.max(0, Math.min(900, Math.round(value)));
    this.readerSettingsRevision += 1;
    if (this.readerSettingsLoaded) { this.persistReaderSettings(); }
  }
  private setReaderTitleLineSpacing(extra: number, sub: number): void {
    this.readerTitleLineSpacingExtra = Math.max(0, Math.min(20, Math.round(extra)));
    this.readerTitleLineSpacingSub = Math.max(0, Math.min(20, Math.round(sub)));
    this.readerSettingsRevision += 1;
    if (this.readerSettingsLoaded) { this.persistReaderSettings(); }
  }
  private setReaderTitleSegScaling(value: number): void {
    // 上游 titleSegScaling 负值非法回落 1、上限 2（ReadBookConfig.kt:283-286）。
    this.readerTitleSegScaling = value < 0 ? 1 : Math.max(1, Math.min(2, value));
    this.readerSettingsRevision += 1;
    if (this.readerSettingsLoaded) { this.persistReaderSettings(); }
  }
  private setReaderTitleSegType(value: number): void {
    this.readerTitleSegType = Math.max(0, Math.min(3, Math.round(value)));
    this.readerSettingsRevision += 1;
    if (this.readerSettingsLoaded) { this.persistReaderSettings(); }
  }
  private setReaderTitleSegDistance(value: number): void {
    this.readerTitleSegDistance = Math.max(0, Math.min(100, Math.round(value)));
    this.readerSettingsRevision += 1;
    if (this.readerSettingsLoaded) { this.persistReaderSettings(); }
  }
  private setReaderTitleSegFlag(value: string): void {
    this.readerTitleSegFlag = value;
    this.readerSettingsRevision += 1;
    if (this.readerSettingsLoaded) { this.persistReaderSettings(); }
  }
  private setReaderMaxLengthWithNoToc(value: number): void {
    this.readerMaxLengthWithNoToc = Math.max(3000, Math.min(100000, Math.round(value)));
    this.readerSettingsRevision += 1;
    if (this.readerSettingsLoaded) { this.persistReaderSettings(); }
  }
  private setReaderTocUseReplace(enabled: boolean): void {
    this.readerTocUseReplace = enabled;
    this.readerSettingsRevision += 1;
    if (this.readerSettingsLoaded) { this.persistReaderSettings(); }
  }

  private setReaderTocShowWordCount(enabled: boolean): void {
    this.readerTocShowWordCount = enabled;
    this.readerSettingsRevision += 1;
    if (this.readerSettingsLoaded) { this.persistReaderSettings(); }
  }

  private setReaderClickImageBehavior(value: string): void {
    this.readerClickImageBehavior = ['0', '1', '2', '3', '4'].includes(value) ? value : '2';
    this.readerSettingsRevision += 1;
    if (this.readerSettingsLoaded) { this.persistReaderSettings(); }
  }

  private setReaderClickRegionActions(actions: string[]): void {
    this.readerClickRegionActions = actions.slice(0, 9);
    this.readerSettingsRevision += 1;
    if (this.readerSettingsLoaded) { this.persistReaderSettings(); }
  }

  private setReaderHideStatusBar(enabled: boolean): void {
    this.readerHideStatusBar = enabled;
    this.readerSettingsRevision += 1;
    if (this.readerSettingsLoaded) { this.persistReaderSettings(); }
  }

  private setReaderHideNavigationBar(enabled: boolean): void {
    this.readerHideNavigationBar = enabled;
    this.readerSettingsRevision += 1;
    if (this.readerSettingsLoaded) { this.persistReaderSettings(); }
  }

  private closeReaderImagePreview(): void {
    this.readerImagePreviewOpen = false;
  }

  private setReaderQuickActions(enabled: boolean): void {
    this.showReaderQuickActions = enabled;
    this.readerSettingsRevision += 1;
    if (this.readerSettingsLoaded) { this.persistReaderSettings(); }
  }

  private async restoreImportedBooks(context: Context): Promise<void> {
    this.bookGroups = await BookGroupRepository.load(context);
    const importedBooks = await BookRepository.loadImportedBooks(context);
    let needsMigration = false;
    const groupNames = this.bookGroups.filter((group: BookGroup) => group.groupId > 0)
      .map((group: BookGroup) => group.groupName);
    const migratedBooks = importedBooks.map((book: Book): Book => {
      if (book.groupNames !== undefined) { return book; }
      needsMigration = true;
      const legacyName = book.groupName?.trim() ?? '';
      const matched = groupNames.includes(legacyName) ? [legacyName] : [];
      // v12 曾把 Android customTag 放在 groupName；未知名称迁回独立自定义标签。
      const customTag = matched.length > 0 || legacyName.length === 0 || legacyName === '本地未分组'
        ? book.customTag : (book.customTag?.trim().length ? book.customTag : legacyName);
      return BookRepository.withShelfMetadata(book, matched,
        matched.length > 0 ? matched.join('、') : '本地未分组', customTag);
    });
    this.books = migratedBooks;
    if (needsMigration) {
      try {
        await BookRepository.saveImportedBooks(context, migratedBooks.filter((book: Book) => BookRepository.isPersistableBook(book)));
      } catch (_) {
        this.showUnavailableAction('书架分组兼容字段迁移失败；现有书目仍已加载');
      }
    }
  }

  private async createLocalBackup(): Promise<void> {
    const context = this.getUIContext().getHostContext();
    if (context === undefined || this.backupBusy) { return; }
    this.backupBusy = true;
    this.backupStatusMessage = '';
    let zipPath = '';
    let savedLocally = false;
    try {
      const localBooks = this.books.filter((book: Book) => BookRepository.isPersistableBook(book));
      const settings = await ReaderSettingsRepository.load(context);
      const bookshelfLayout = await BookshelfLayoutRepository.load(context);
      zipPath = await BackupRepository.buildBackupArchive(context, localBooks, settings,
        bookshelfLayout, this.backupIgnoreKeys, this.themeMode, this.themePaletteIndex, this.themeCustomColors);
      const options = new picker.DocumentSaveOptions();
      options.newFileNames = [`backup${BackupRepository.currentDate()}.zip`];
      options.fileSuffixChoices = ['Legado Android 兼容备份|.zip'];
      const uris = await new picker.DocumentViewPicker(context).save(options);
      const uri = uris[0];
      if (uri !== undefined) {
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
        savedLocally = true;
        this.backupStatusMessage = 'Android 兼容 ZIP 已保存到你选择的位置。';
      }
    } catch (error) {
      this.backupStatusMessage = error instanceof Error ? `创建备份失败：${error.message}` : '创建备份失败';
    } finally {
      if (zipPath.length > 0) {
        // 先本地后 WebDAV：本地 picker 可能被取消，反过来先传远端会留下「远端有、本地没有」的备份。
        // 同步模式 both 且已配置凭据时，本地成功后顺手上传同一份 zip；未配置则静默跳过，
        // 避免每次本地备份都弹一条「账号或密码为空」的失败提示。
        if (savedLocally && this.webDavSettings.backupSyncMode === 'both' &&
          isWebDavConfigured(this.webDavSettings)) {
          try {
            await WebDavSync.uploadBackup(context, zipPath, `backup${BackupRepository.currentDate()}.zip`);
          } catch (error) {
            // 上游 Backup.kt:322 的 both 分支同样只记日志、不外抛：本地成功不该被 WebDAV 失败判为失败。
            console.error(`[Index] WebDAV 上传失败: ${error}`);
            this.backupStatusMessage = `${this.backupStatusMessage} WebDAV 上传失败：${error instanceof Error ? error.message : String(error)}`;
          }
        }
        try { fileIo.unlinkSync(zipPath); } catch (error) { console.error(`[Index] 清理临时 zip 失败: ${error}`); }
      }
      this.backupBusy = false;
    }
  }

  private async saveWebDavSettings(next: WebDavSettings): Promise<void> {
    this.webDavSettings = next;
    const context = this.getUIContext().getHostContext();
    if (context === undefined) { return; }
    try {
      await WebDavConfigStore.save(context, next);
    } catch (error) {
      this.showUnavailableAction(`WebDAV 设置保存失败：${error instanceof Error ? error.message : String(error)}`);
    }
  }

  private async testWebDav(): Promise<void> {
    const context = this.getUIContext().getHostContext();
    if (context === undefined || this.webDavTesting) { return; }
    this.webDavTesting = true;
    try {
      const result = await WebDavSync.test(context);
      this.showUnavailableAction(result.message);
      if (result.ok) {
        this.webDavBackupNames = await WebDavSync.listBackups(context);
      }
    } catch (error) {
      this.showUnavailableAction(`WebDAV 测试失败：${error instanceof Error ? error.message : String(error)}`);
    } finally {
      this.webDavTesting = false;
    }
  }

  private async backupToWebDav(): Promise<void> {
    const context = this.getUIContext().getHostContext();
    if (context === undefined || this.backupBusy) { return; }
    this.backupBusy = true;
    this.backupStatusMessage = '';
    let zipPath = '';
    try {
      const localBooks = this.books.filter((book: Book) => BookRepository.isPersistableBook(book));
      const settings = await ReaderSettingsRepository.load(context);
      const bookshelfLayout = await BookshelfLayoutRepository.load(context);
      zipPath = await BackupRepository.buildBackupArchive(context, localBooks, settings,
        bookshelfLayout, this.backupIgnoreKeys, this.themeMode, this.themePaletteIndex, this.themeCustomColors);
      const fileName = `backup${BackupRepository.currentDate()}.zip`;
      await WebDavSync.uploadBackup(context, zipPath, fileName);
      this.backupStatusMessage = `已上传 ${fileName} 到 WebDAV。`;
    } catch (error) {
      this.backupStatusMessage = error instanceof Error ? `上传 WebDAV 失败：${error.message}` : '上传 WebDAV 失败';
    } finally {
      if (zipPath.length > 0) {
        try { fileIo.unlinkSync(zipPath); } catch (error) { console.error(`[Index] 清理临时 zip 失败: ${error}`); }
      }
      this.backupBusy = false;
    }
  }

  private async restoreFromWebDav(): Promise<void> {
    const context = this.getUIContext().getHostContext();
    if (context === undefined || this.backupBusy) { return; }
    this.backupBusy = true;
    this.backupStatusMessage = '';
    this.backupPreview = undefined;
    this.pendingBackup = undefined;
    let zipPath = '';
    try {
      const latest = await WebDavSync.latestBackup(context);
      if (latest === undefined) {
        this.backupStatusMessage = 'WebDAV 上没有找到备份文件。';
        return;
      }
      zipPath = `${context.cacheDir}/legado-webdav-restore-${Date.now()}.zip`;
      await WebDavSync.downloadBackup(context, latest.name, zipPath);
      const localBooks = this.books.filter((book: Book) => BookRepository.isPersistableBook(book));
      const selection = await BackupRepository.selectBackupFromPath(context, zipPath, localBooks);
      this.pendingBackup = selection;
      // 预览卡渲染依赖 backupPreview（:151），必须和 selectLocalBackup 一样同时设。
      this.backupPreview = selection.preview;
      this.backupStatusMessage = `已下载 ${latest.name}，请确认预览后导入。`;
    } catch (error) {
      this.backupStatusMessage = error instanceof Error ? `从 WebDAV 恢复失败：${error.message}` : '从 WebDAV 恢复失败';
    } finally {
      if (zipPath.length > 0) {
        try { fileIo.unlinkSync(zipPath); } catch (error) { console.error(`[Index] 清理临时 zip 失败: ${error}`); }
      }
      this.backupBusy = false;
    }
  }

  private async selectLocalBackup(): Promise<void> {
    const context = this.getUIContext().getHostContext();
    if (context === undefined || this.backupBusy) { return; }
    this.backupBusy = true;
    this.backupStatusMessage = '';
    this.backupPreview = undefined;
    this.pendingBackup = undefined;
    try {
      const localBooks = this.books.filter((book: Book) => BookRepository.isPersistableBook(book));
      const selection = await BackupRepository.selectBackup(context, localBooks);
      if (selection !== undefined) {
        this.pendingBackup = selection;
        this.backupPreview = selection.preview;
      }
    } catch (error) {
      this.backupStatusMessage = error instanceof Error ? `读取备份失败：${error.message}` : '读取备份失败';
    } finally {
      this.backupBusy = false;
    }
  }

  private async restoreLocalBackup(): Promise<void> {
    const context = this.getUIContext().getHostContext();
    const selection = this.pendingBackup;
    if (context === undefined || selection === undefined || this.backupBusy) { return; }
    this.backupBusy = true;
    this.backupStatusMessage = '';
    try {
      const localBooks = this.books.filter((book: Book) => BookRepository.isPersistableBook(book));
      const currentSettings = this.getCurrentReaderSettingsSnapshot();
      const currentBookshelfLayout = await BookshelfLayoutRepository.load(context);
      const result = await BackupRepository.restore(
        context, selection, localBooks, currentSettings, currentBookshelfLayout, this.restoreIgnoreKeys
      );
      this.books = result.books;
      this.bookGroups = BookGroupRepository.getAll();
      this.bookshelfLayout = copyBookshelfLayout(result.bookshelfLayout);
      // 封面设置随 config.xml 的 coverConfig 键组恢复，刷回 @State 后下发各页。
      this.coverSettings = copyCoverSettings(result.coverSettings);
      // 订阅入口开关先刷回 @State：紧随的 applyThemeMode 会整份写主题设置，
      // 若这里不更新内存值，saveThemeSettings 会用旧 showRss 把刚恢复的值盖回。
      let showRssChanged = false;
      if (result.showRss !== undefined && result.showRss !== this.themeShowRss) {
        this.themeShowRss = result.showRss;
        showRssChanged = true;
      }
      // 全局深色模式：归档里没有该键（或该类被忽略）时保留当前值，不硬覆盖。
      if (result.themeMode !== undefined && result.themeMode !== this.themeMode) {
        await this.applyThemeMode(context, result.themeMode, this.themePaletteIndex, true);
      } else if (showRssChanged) {
        // themeMode 没变时 applyThemeMode 不会被调用，单独整份落盘一次把 showRss 写回。
        await this.saveThemeSettings(context);
      }
      this.readerFontSize = result.settings.fontSize;
      this.readerParagraphSpacing = result.settings.paragraphSpacing;
      this.readerLineSpacing = result.settings.lineSpacing;
      this.readerLetterSpacing = result.settings.letterSpacing;
      this.readerParagraphIndent = result.settings.paragraphIndent;
      this.readerTextItalic = result.settings.textItalic;
      this.readerTextBold = result.settings.textBold;
      this.readerTextShadow = result.settings.textShadow;
      this.readerShadowRadius = result.settings.shadowRadius;
      this.readerShadowDx = result.settings.shadowDx;
      this.readerShadowDy = result.settings.shadowDy;
      this.readerTextShadowColor = result.settings.textShadowColor;
      this.readerTextShadowColorN = result.settings.textShadowColorN;
      this.readerUnderline = result.settings.underline;
      this.readerDottedLine = result.settings.dottedLine;
      this.readerUnderlineColor = result.settings.underlineColor;
      this.readerUnderlineColorNight = result.settings.underlineColorNight;
      this.readerUnderlineHeight = result.settings.underlineHeight;
      this.readerUnderlinePadding = result.settings.underlinePadding;
      this.readerUnderlineExtend = result.settings.underlineExtend;
      this.readerDottedBase = result.settings.dottedBase;
      this.readerDottedRatio = result.settings.dottedRatio;
      this.paperIndex = result.settings.paperIndex;
      this.dayPaperIndex = result.settings.dayPaperIndex;
      this.nightPaperIndex = result.settings.nightPaperIndex;
      this.backgroundStyles = copyReaderBackgroundStyles(result.settings.backgroundStyles);
      // 与 `loadReaderSettings`（:1999-2003）同一口径：readerNightMode 不再是独立来源，
      // 恢复时也按全局 themeMode 重新投影，否则备份里的旧布尔会把刚恢复的模式冲掉。
      this.readerNightMode = ThemeModeResolver.isDarkTheme(this.themeMode,
        ThemeModeResolver.isSystemDark(context));
      this.eyeProtectionEnabled = result.settings.eyeProtectionEnabled;
      this.eyeProtectionAutoNight = result.settings.eyeProtectionAutoNight;
      this.eyeProtectionSchedule = result.settings.eyeProtectionSchedule;
      this.eyeProtectionIntensity = result.settings.eyeProtectionIntensity;
      this.eyeProtectionStartTime = result.settings.eyeProtectionStartTime;
      this.eyeProtectionEndTime = result.settings.eyeProtectionEndTime;
      this.shareReaderStyleLayout = result.settings.shareLayout;
      this.showReaderBottomActionText = result.settings.showBottomActionText;
      this.readerBottomIconStyle = result.settings.bottomIconStyle;
      this.readerBottomItemsPerRow = result.settings.bottomItemsPerRow;
      this.readerBottomRowCount = result.settings.bottomRowCount;
      this.readerBottomActions = result.settings.bottomActions;
      this.readerTopActions = result.settings.topActions;
      this.readerProgressBehavior = result.settings.progressBehavior;
      this.readerReadSliderMode = result.settings.readSliderMode;
      this.readerSliderVibrator = result.settings.sliderVibrator;
      this.readerSelectVibrator = result.settings.selectVibrator;
      this.readerChineseConverterType = result.settings.chineseConverterType;
      this.readerTextColor = result.settings.textColor;
      this.readerTextColorNight = result.settings.textColorNight;
      this.readerTextAccentColor = result.settings.textAccentColor;
      this.readerTextAccentColorNight = result.settings.textAccentColorNight;
      this.readerBgStr = result.settings.bgStr;
      this.readerBgStrNight = result.settings.bgStrNight;
      this.readerBgType = result.settings.bgType;
      this.readerBgTypeNight = result.settings.bgTypeNight;
      this.readerBgAlpha = result.settings.bgAlpha;
      this.readerDarkStatusIcon = result.settings.darkStatusIcon;
      this.readerDarkStatusIconNight = result.settings.darkStatusIconNight;
      this.readerTitleMode = result.settings.titleMode;
      this.readerTitleSize = result.settings.titleSize;
      this.readerTitleSizeRelative = result.settings.titleSizeRelative;
      this.readerTitleTopSpacing = result.settings.titleTopSpacing;
      this.readerTitleBottomSpacing = result.settings.titleBottomSpacing;
      this.readerTitleColor = result.settings.titleColor;
      this.readerTitleColorNight = result.settings.titleColorNight;
      this.readerTitleBold = result.settings.titleBold;
      this.readerTitleLineSpacingExtra = result.settings.titleLineSpacingExtra;
      this.readerTitleLineSpacingSub = result.settings.titleLineSpacingSub;
      this.readerTitleSegType = result.settings.titleSegType;
      this.readerTitleSegScaling = result.settings.titleSegScaling;
      this.readerTitleSegDistance = result.settings.titleSegDistance;
      this.readerTitleSegFlag = result.settings.titleSegFlag;
      BookRepository.setChineseConverterType(result.settings.chineseConverterType);
      ReplaceRuleRepository.setChineseConverterType(result.settings.chineseConverterType);
      this.readerPageTouchSlop = result.settings.pageTouchSlop;
      this.readerLastMarkingStyle = result.settings.lastMarkingStyle;
      this.readerPrevKeys = result.settings.prevKeys;
      this.readerNextKeys = result.settings.nextKeys;
      this.readerMouseWheelPage = result.settings.mouseWheelPage;
      this.readerExpandTextMenu = result.settings.expandTextMenu;
      this.readerShowSelectMenuIcon = result.settings.showSelectMenuIcon;
      this.readerTextSelectMenuConfig = result.settings.textSelectMenuConfig;
    this.readerDoubleHorizontalPage = result.settings.doubleHorizontalPage;
    this.readerAutoSuggestDayNight = result.settings.autoSuggestDayNight;
    this.readerDisableReturnKey = result.settings.disableReturnKey;
    this.readerReadBrightness = result.settings.readBrightness;
    this.readerShowBrightnessView = result.settings.showBrightnessView;
    this.readerBrightnessVwPos = result.settings.brightnessVwPos;
    this.readerBrightnessAuto = result.settings.brightnessAuto;
    this.readerReadBodyToLh = result.settings.readBodyToLh;
    this.readerUseZhLayout = result.settings.useZhLayout;
    this.readerPaddingDisplayCutouts = result.settings.paddingDisplayCutouts;
    this.readerAdaptSpecialStyle = result.settings.adaptSpecialStyle;
    this.readerReadMenuBottomCornerRadius = result.settings.readMenuBottomCornerRadius;
    this.readerReadMenuFloatingBottomBar = result.settings.readMenuFloatingBottomBar;
    this.readerReadMenuBottomBarBlurMode = result.settings.readMenuBottomBarBlurMode;
    this.readerReadMenuBottomBarBlurStyle = result.settings.readMenuBottomBarBlurStyle;
    this.readerReadMenuBottomBarLiquidGlassButtons = result.settings.readMenuBottomBarLiquidGlassButtons;
    this.readerReadMenuBlurAlpha = result.settings.readMenuBlurAlpha;
    this.readerReadMenuTopBarTitleCapsule = result.settings.readMenuTopBarTitleCapsule;
    this.readerTitleBarMode = result.settings.titleBarMode;
    this.readerTitleBarCompact = result.settings.titleBarCompact;
    this.readerTitleBarIconStyle = result.settings.titleBarIconStyle;
    this.readerReadMenuTopBarBlurMode = result.settings.readMenuTopBarBlurMode;
    this.readerReadMenuTopBarBlurStyle = result.settings.readMenuTopBarBlurStyle;
    this.readerReadMenuTopBarLiquidGlassButtons = result.settings.readMenuTopBarLiquidGlassButtons;
    this.readerReadMenuTopBarMergeButtons = result.settings.readMenuTopBarMergeButtons;
    this.readerReadBarStyle = result.settings.readBarStyle;
    this.readerMenuPaletteStyle = result.settings.readMenuPaletteStyle;
    this.readerMenuColorMode = result.settings.readMenuColorMode;
    this.readerMenuBgColor = result.settings.readMenuBgColor;
    this.readerMenuBgColorNight = result.settings.readMenuBgColorNight;
    this.readerMenuContainerColor = result.settings.readMenuContainerColor;
    this.readerMenuContainerColorNight = result.settings.readMenuContainerColorNight;
    this.readerMenuAccentColor = result.settings.readMenuAccentColor;
    this.readerMenuAccentColorNight = result.settings.readMenuAccentColorNight;
    this.readerMenuBorderWidth = result.settings.readMenuBorderWidth;
    this.readerMenuBorderColor = result.settings.readMenuBorderColor;
    this.readerMenuBorderColorNight = result.settings.readMenuBorderColorNight;
    this.readerMenuBlurRadius = result.settings.readMenuBlurRadius;
    this.readerMenuTextColor = result.settings.readMenuTextColor;
    this.readerMenuTextColorNight = result.settings.readMenuTextColorNight;
    this.readerMenuBlurColor = result.settings.readMenuBlurColor;
    this.readerMenuBlurColorNight = result.settings.readMenuBlurColorNight;
    this.readerShowTitleBarIcons = result.settings.showTitleBarIcons;
    this.readerTitleBarIconPosition = result.settings.titleBarIconPosition;
    this.readerReadMenuFloatingIconLiquidGlass = result.settings.readMenuFloatingIconLiquidGlass;
    this.readerFloatingIcons = result.settings.floatingIcons.map(
      (item: ReaderBottomActionConfig): ReaderBottomActionConfig => ({ id: item.id, enabled: item.enabled })
    );
    this.readerTitleBarCustomIcons = result.settings.titleBarCustomIcons;
    this.readerReadMenuCustomIcons = result.settings.readMenuCustomIcons;
    this.readerReadMenuLensRadius = result.settings.readMenuLensRadius;
    this.readerReadBarStyleFollowPage = result.settings.readBarStyleFollowPage;
    this.readerShowMenuIcon = result.settings.showMenuIcon;
    this.readerShowReadTitleAddition = result.settings.showReadTitleAddition;
    this.readerMenuAlpha = result.settings.menuAlpha;
      this.showReaderQuickActions = result.settings.showQuickActions;
      this.autoReadSpeed = result.settings.autoReadSpeed;
      this.readerPageAnimation = result.settings.pageAnimation;
      this.readerAnimationSpeed = result.settings.animationSpeed;
      this.readerInfoSettings = this.getReaderInfoSettingsFromSnapshot(result.settings);
      // 「更多」面板条目的运行时真源是 ReaderMoreActionsRepository（独立 prefs），
      // 快照里的 moreActionsConfig 只是它的备份投影；恢复时把串解码回仓储并落盘，
      // 否则备份里改过的「更多」条目在重启后会被旧仓储值覆盖回去。
      this.readerMoreActions = ReaderSettingsRepository.decodeMoreActions(result.settings.moreActionsConfig);
      await ReaderMoreActionsRepository.save(context, this.readerMoreActions);
      this.readerSettingsLoaded = true;
      this.readerSettingsRevision += 1;
      // 恢复可能写入了替换净化规则，重新读一次让规则页和阅读页都看到最新结果。
      this.replaceRules = ReplaceRuleRepository.getAll();
      this.txtTocRules = TxtTocRuleRepository.getAll();
      // 恢复可能写入了书签与笔记，重新读一次让「所有书签」页与阅读页看到最新结果。
      this.readerBookmarks = await ReaderBookmarkRepository.load(context);
      this.readerMarkings = await ReaderMarkingRepository.load(context);
      const restoreSummary = `导入完成：保留 ${result.preservedEntryCount} 个 Android 条目；更新 ${result.updatedLocalBookCount} 本已有正文书籍的进度，并创建 ${result.createdMissingBodyBookCount} 本缺正文书目；清理 ${result.deletedDuplicateLocalBookCount} 本重复书目`;
      const details: string[] = [];
      const replaceRuleSummary = this.describeReplaceRuleRestore(
        result.replaceRuleAdded, result.replaceRuleUpdated, result.replaceRuleSkipped
      );
      if (replaceRuleSummary.length > 0) { details.push(replaceRuleSummary); }
      const tocRuleSummary = this.describeTxtTocRuleRestore(
        result.txtTocRuleAdded, result.txtTocRuleUpdated, result.txtTocRuleSkipped
      );
      if (tocRuleSummary.length > 0) { details.push(tocRuleSummary); }
      const highlightRuleSummary = this.describeHighlightRuleRestore(
        result.highlightRuleAdded, result.highlightRuleUpdated, result.highlightRuleSkipped
      );
      if (highlightRuleSummary.length > 0) { details.push(highlightRuleSummary); }
      const bookmarkSummary = this.describeBookmarkRestore(
        result.bookmarkAdded, result.bookmarkUpdated, result.bookmarkSkipped
      );
      if (bookmarkSummary.length > 0) { details.push(bookmarkSummary); }
      const g2DictRule = this.describeG2RuleRestore('字典规则', result.dictRuleAdded, result.dictRuleUpdated, result.dictRuleSkipped);
      if (g2DictRule.length > 0) { details.push(g2DictRule); }
      const g2HomepageModule = this.describeG2RuleRestore('首页模块', result.homepageModulesAdded, result.homepageModulesUpdated, result.homepageModulesSkipped);
      if (g2HomepageModule.length > 0) { details.push(g2HomepageModule); }
      const g2HomepageCustomSet = this.describeG2RuleRestore('首页自定义集', result.homepageCustomSetsAdded, result.homepageCustomSetsUpdated, result.homepageCustomSetsSkipped);
      if (g2HomepageCustomSet.length > 0) { details.push(g2HomepageCustomSet); }
      const g2HighlightTagRule = this.describeG2RuleRestore('标签高亮规则', result.highlightTagRuleAdded, result.highlightTagRuleUpdated, result.highlightTagRuleSkipped);
      if (g2HighlightTagRule.length > 0) { details.push(g2HighlightTagRule); }
      const g2TagGroupRule = this.describeG2RuleRestore('标签分组规则', result.tagGroupRuleAdded, result.tagGroupRuleUpdated, result.tagGroupRuleSkipped);
      if (g2TagGroupRule.length > 0) { details.push(g2TagGroupRule); }
      const aGroupBookSource = this.describeG2RuleRestore('书源', result.bookSourceAdded, result.bookSourceUpdated, result.bookSourceSkipped);
      if (aGroupBookSource.length > 0) { details.push(aGroupBookSource); }
      const aGroupRssSource = this.describeG2RuleRestore('RSS 订阅源', result.rssSourceAdded, result.rssSourceUpdated, result.rssSourceSkipped);
      if (aGroupRssSource.length > 0) { details.push(aGroupRssSource); }
      const aGroupRssStar = this.describeG2RuleRestore('RSS 收藏', result.rssStarAdded, result.rssStarUpdated, result.rssStarSkipped);
      if (aGroupRssStar.length > 0) { details.push(aGroupRssStar); }
      const aGroupSourceSub = this.describeG2RuleRestore('规则订阅', result.sourceSubAdded, result.sourceSubUpdated, result.sourceSubSkipped);
      if (aGroupSourceSub.length > 0) { details.push(aGroupSourceSub); }
      const serverSummary = this.describeG2RuleRestore(
        '服务器配置', result.serverAdded, result.serverUpdated, result.serverSkipped);
      if (serverSummary.length > 0) {
        details.push(serverSummary);
      }
      this.backupStatusMessage = details.length > 0
        ? `${restoreSummary}；${details.join('')}` : `${restoreSummary}。`;
      this.restoredAndroidEntries = result.restoredEntries;
      await BackupRepository.discardSelection(selection);
      this.pendingBackup = undefined;
      this.backupPreview = undefined;
    } catch (error) {
      this.backupStatusMessage = error instanceof Error ? `恢复失败：${error.message}` : '恢复失败';
    } finally {
      this.backupBusy = false;
    }
  }

  /**
   * 生成替换净化规则的恢复结果说明。
   * 三项都为 0 时返回空串，表示这份备份里没有 replaceRule.json，
   * 不在提示里加一句没有信息量的话；返回值不带句号，由调用方决定句尾。
   */
  private describeReplaceRuleRestore(added: number, updated: number, skipped: number): string {
    if (added === 0 && updated === 0 && skipped === 0) { return ''; }
    const parts: string[] = [];
    if (added > 0) { parts.push(`新增 ${added} 条`); }
    if (updated > 0) { parts.push(`覆盖 ${updated} 条`); }
    if (skipped > 0) { parts.push(`跳过 ${skipped} 条无效规则`); }
    return `替换净化规则${parts.join('、')}。`;
  }

  /** 三类数量都为 0 表示备份中没有 TXT 目录规则文件。 */
  private describeTxtTocRuleRestore(added: number, updated: number, skipped: number): string {
    if (added === 0 && updated === 0 && skipped === 0) { return ''; }
    const parts: string[] = [];
    if (added > 0) { parts.push(`新增 ${added} 条`); }
    if (updated > 0) { parts.push(`覆盖 ${updated} 条`); }
    if (skipped > 0) { parts.push(`跳过 ${skipped} 条无效规则`); }
    return `TXT 目录规则${parts.join('、')}。`;
  }

  /**
   * 生成阅读正文高亮规则的恢复结果说明。
   * 恢复采用合并语义：本地独有的规则保留，同 id 或同 pattern 的才覆盖。
   */
  private describeHighlightRuleRestore(added: number, updated: number, skipped: number): string {
    if (added === 0 && updated === 0 && skipped === 0) { return ''; }
    const parts: string[] = [];
    if (added > 0) { parts.push(`新增 ${added} 条`); }
    if (updated > 0) { parts.push(`覆盖 ${updated} 条`); }
    if (skipped > 0) { parts.push(`跳过 ${skipped} 条无效规则`); }
    return `高亮规则${parts.join('、')}。`;
  }

  /**
   * 生成书签、划线与笔记的恢复结果说明。
   * 两份文件（bookmark.json / bookMarking.json）的计数合并成一个总数，
   * 用户关心的是「书签笔记恢复了多少」，不需要知道内部拆成了两个文件。
   */
  private describeBookmarkRestore(added: number, updated: number, skipped: number): string {
    if (added === 0 && updated === 0 && skipped === 0) { return ''; }
    const parts: string[] = [];
    if (added > 0) { parts.push(`新增 ${added} 条`); }
    if (updated > 0) { parts.push(`覆盖 ${updated} 条`); }
    if (skipped > 0) { parts.push(`跳过 ${skipped} 条无对应书籍或无效`); }
    return `书签与笔记${parts.join('、')}。`;
  }

  /**
   * G2 五类规则（字典／首页模块／首页自定义集／标签高亮／标签分组）共用一份计数说明。
   * 恢复走合并语义，三项都为 0 时返回空串，不在提示里加没有信息量的一句话。
   */
  private describeG2RuleRestore(label: string, added: number, updated: number, skipped: number): string {
    if (added === 0 && updated === 0 && skipped === 0) { return ''; }
    const parts: string[] = [];
    if (added > 0) { parts.push(`新增 ${added} 条`); }
    if (updated > 0) { parts.push(`覆盖 ${updated} 条`); }
    if (skipped > 0) { parts.push(`跳过 ${skipped} 条无效规则`); }
    return `${label}${parts.join('、')}。`;
  }

  private cancelLocalBackupRestore(): void {
    if (this.pendingBackup !== undefined) {
      const selection = this.pendingBackup;
      BackupRepository.discardSelection(selection).catch(() => {
        this.backupStatusMessage = '已取消恢复；临时预览文件稍后清理';
      });
    }
    this.pendingBackup = undefined;
    this.backupPreview = undefined;
    this.backupStatusMessage = '已取消恢复，当前书架和设置未修改。';
  }

  private async toggleBackupIgnore(key: string, ignored: boolean): Promise<void> {
    this.backupIgnoreKeys = this.updateIgnoredKeys(this.backupIgnoreKeys, key, ignored);
    await this.saveBackupIgnoreLists();
  }

  private async toggleRestoreIgnore(key: string, ignored: boolean): Promise<void> {
    this.restoreIgnoreKeys = this.updateIgnoredKeys(this.restoreIgnoreKeys, key, ignored);
    await this.saveBackupIgnoreLists();
  }

  private updateIgnoredKeys(current: string[], key: string, ignored: boolean): string[] {
    if (ignored) {
      return current.includes(key) ? current : [...current, key];
    }
    return current.filter((item: string) => item !== key);
  }

  private async saveBackupIgnoreLists(): Promise<void> {
    const context = this.getUIContext().getHostContext();
    if (context === undefined) { return; }
    try {
      const lists: BackupIgnoreLists = {
        backup: this.backupIgnoreKeys,
        restore: this.restoreIgnoreKeys
      };
      await BackupRepository.saveIgnoreLists(context, lists);
    } catch (_) {
      this.backupStatusMessage = '排除项保存失败';
    }
  }

  private async importLocalBook(): Promise<Book | undefined> {
    const context = this.getUIContext().getHostContext();
    if (context === undefined) {
      return undefined;
    }
    let created: CreatedLocalBook | undefined;
    try {
      created = await BookRepository.importLocalBook(context, this.readerMaxLengthWithNoToc);
    } catch (error) {
      this.showUnavailableAction(error instanceof Error ? `导入失败：${error.message}` : '导入失败：文件格式不受支持');
      return undefined;
    }
    if (created === undefined) {
      return undefined;
    }
    const importedBook = created.book;
    const importedChapters = created.chapters;
    const importedBooks = await BookRepository.loadImportedBooks(context);
    const importedBookUrl = importedBook.contentPath ?? '';
    // 判重键是 bookUrl（本地书就是正文文件路径），对应上游 LocalBook.kt:259
    // `appDb.bookDao.getBook(bookUrl)`。上游同一 bookUrl 再导入走的是「更新」分支
    // （LocalBook.kt:280-288）：删旧目录、重置 latestChapterTime、更新这条记录，
    // **不新增第二条**。原来这里按 `format + title + author` 判重并直接拒绝导入，
    // 结果是「同名同作者的另一本书加不进书架」——正是 KI-REL4。
    const existing = importedBookUrl.length > 0
      ? [...this.books, ...importedBooks].find((item: Book) =>
        BookRepository.isPersistableBook(item) && (item.contentPath ?? '') === importedBookUrl)
      : undefined;
    if (existing !== undefined) {
      // 书目行沿用原记录（id、分组、阅读进度、书签归属都不动），只把目录换成这次解析的结果。
      const updatedBook: Book = BookRepository.copyBook(existing);
      updatedBook.chapterCount = importedBook.chapterCount;
      updatedBook.lastChapter = importedBook.lastChapter;
      updatedBook.tocRule = importedBook.tocRule;
      // 与上游一致：latestChapterTime 归零触发「本地文件已更新」，正文重新分页。
      updatedBook.latestChapterTime = 0;
      const booksToSave = this.books
        .map((item: Book) => (item.contentPath ?? '') === importedBookUrl ? updatedBook : item)
        .filter((item: Book) => BookRepository.isPersistableBook(item));
      try {
        await BookRepository.saveImportedBooks(context, booksToSave);
        // 同一 bookUrl 的旧章节行整本重建（上游 `delByBook` + 重新解析）。
        await BookRepository.saveChapters(context, importedBookUrl, importedChapters);
      } catch (error) {
        this.showUnavailableAction(error instanceof Error ? error.message : '更新书目失败');
        return undefined;
      }
      this.books = this.books.map((item: Book) =>
        (item.contentPath ?? '') === importedBookUrl ? updatedBook : item);
      this.showUnavailableAction(`这本书之前导入过，已更新《${updatedBook.title}》的目录`);
      return updatedBook;
    }
    const booksToSave = [...this.books, importedBook]
      .filter((item: Book) => BookRepository.isPersistableBook(item));
    try {
      await BookRepository.saveImportedBooks(context, booksToSave);
      // 书目落库后单独写章节行：books 与 chapters 是两张表，导入时一起写。
      await BookRepository.saveChapters(context, importedBook.contentPath ?? '', importedChapters);
    } catch (error) {
      try {
        BookRepository.discardImportedCopy(importedBook);
      } catch (_) {
        this.showUnavailableAction('书架数据保存失败，且无法清理本次导入副本');
        return undefined;
      }
      this.showUnavailableAction(error instanceof Error ? error.message : '书架数据保存失败，已取消导入');
      return undefined;
    }
    this.books = [...this.books, importedBook];
    return importedBook;
  }

  /**
   * 导入书单：BookshelfListTransfer 解析出的「缺正文」书目合并落库并刷新书架。
   * 与 importLocalBook 的区别是这些条目没有正文文件，只落一条书目记录。
   */
  private async importBookList(books: Book[]): Promise<void> {
    const context = this.getUIContext().getHostContext();
    if (context === undefined) { return; }
    const booksToSave = [...this.books, ...books]
      .filter((item: Book) => BookRepository.isPersistableBook(item));
    try {
      await BookRepository.saveImportedBooks(context, booksToSave);
    } catch (error) {
      this.showUnavailableAction(error instanceof Error ? error.message : '书单落库失败');
      return;
    }
    this.books = [...this.books, ...books];
  }

  /**
   * 重新识别书架里所有本地 TXT 的目录，对应上游书架的「更新目录」。
   *
   * 导入时选中的章节正则会固定在 Book.tocRule 上，规则调整后已有书的目录不会变，
   * 这里给用户一个主动重算的入口：清掉缓存规则、重新匹配、按字符偏移迁移阅读位置。
   * 与上游一致，书签与划线/笔记按原章节号保留，不随新目录重映射。
   */
  private async refreshAllToc(): Promise<void> {
    const context = this.getUIContext().getHostContext();
    if (context === undefined) {
      this.showUnavailableAction('无法访问本地书架，未更新目录');
      return;
    }
    const localBooks = this.books.filter((book: Book) =>
      book.isLocal && book.format === 'txt' && book.contentPath !== undefined);
    if (localBooks.length === 0) {
      this.showUnavailableAction('书架里没有可更新目录的本地 TXT');
      return;
    }
    let updatedCount = 0;
    let failedCount = 0;
    const updatedBooks: Book[] = [];
    for (let index = 0; index < this.books.length; index++) {
      const book = this.books[index];
      if (book === undefined) { continue; }
      if (!book.isLocal || book.format !== 'txt' || book.contentPath === undefined) {
        updatedBooks.push(book);
        continue;
      }
      const refreshingKey = book.contentPath ?? book.androidOriginalPath ?? '';
      this.refreshingBookIds = [...this.refreshingBookIds, refreshingKey];
      try {
        const result = BookRepository.refreshToc(book, this.readerMaxLengthWithNoToc);
        if (result.changed) {
          // 目录重算会重建整份章节行；books 行本来就在，先把 chapters 表覆盖掉。
          await BookRepository.saveChapters(context, result.book.contentPath ?? '', result.chapters);
          updatedBooks.push(result.book);
          updatedCount += 1;
          if (this.selectedBook.id === result.book.id) {
            this.selectedBook = result.book;
          }
        } else {
          updatedBooks.push(book);
        }
      } catch (_) {
        // 单本书读不出来不该让整批失败，其余书照常更新。
        failedCount += 1;
        updatedBooks.push(book);
      } finally {
        this.refreshingBookIds = this.refreshingBookIds.filter((key: string) => key !== refreshingKey);
      }
    }
    if (updatedCount === 0 && failedCount === 0) {
      this.showUnavailableAction('所有本地 TXT 的目录都没有变化');
      return;
    }
    try {
      await BookRepository.saveImportedBooks(context,
        updatedBooks.filter((book: Book) => BookRepository.isPersistableBook(book)));
    } catch (_) {
      this.showUnavailableAction('目录已更新，但保存失败，重新打开后可能回到旧目录');
      return;
    }
    this.books = updatedBooks;
    const parts: string[] = [];
    if (updatedCount > 0) { parts.push(`已更新 ${updatedCount} 本`); }
    if (failedCount > 0) { parts.push(`${failedCount} 本读取失败已跳过`); }
    this.showUnavailableAction(`更新目录完成：${parts.join('，')}`);
  }

  /**
   * 当前纸色。优先取用户自定义的背景色（上游 `bgStr`/`bgStrNight`），
   * 没有自定义时回落到 `paperIndex` 指向的内置方案——`READER_BACKGROUND_STYLES`
   * 因此从「唯一来源」降级为「预设」。
   * `bgType` 为 2 时 `bgStr` 存的是图片路径，纸色仍取内置方案，图片由 ReaderPage 叠在上面。
   */
  private getPaperColor(): string {
    const custom = this.readerNightMode ? this.readerBgStrNight : this.readerBgStr;
    const customType = this.readerNightMode ? this.readerBgTypeNight : this.readerBgType;
    if (customType === 0 && custom.length > 0) { return custom; }
    const style = this.backgroundStyles[Math.max(0, Math.min(this.backgroundStyles.length - 1, this.paperIndex))];
    return style === undefined ? '#000000' : (this.readerNightMode ? style.nightColor : style.dayColor);
  }
  /** 当前生效的正文颜色；上游 `textColor`/`textColorNight`。 */
  private getReadingTextColorSetting(): string {
    return this.readerNightMode ? this.readerTextColorNight : this.readerTextColor;
  }
  /** 当前生效的强调色；上游 `textAccentColor`/`textAccentColorNight`。 */
  private getTextAccentColorSetting(): string {
    return this.readerNightMode ? this.readerTextAccentColorNight : this.readerTextAccentColor;
  }
  /** 当前生效的状态栏图标深浅；上游 `darkStatusIcon`/`darkStatusIconNight`。 */
  private getDarkStatusIconSetting(): boolean {
    return this.readerNightMode ? this.readerDarkStatusIconNight : this.readerDarkStatusIcon;
  }
  /** 当前生效的背景图片路径；空串表示没有自定义图片。 */
  private getReaderBackgroundImage(): string {
    const custom = this.readerNightMode ? this.readerBgStrNight : this.readerBgStr;
    const customType = this.readerNightMode ? this.readerBgTypeNight : this.readerBgType;
    return customType !== 0 ? custom : '';
  }

  /**
   * 重新识别当前这本书的目录，对应上游目录页「更新目录」菜单项。
   *
   * 与书架级批量更新共用 BookRepository.refreshToc，差别只在范围是一本书。
   * 与上游一致，书签与划线/笔记按原章节号保留，不随新目录重映射。
   */
  private async refreshCurrentToc(): Promise<void> {
    await this.refreshBookInfo(this.selectedBook);
  }

  /**
   * 刷新书籍信息（批 7 的 `:280`）：重扫正文重切目录。
   *
   * 与「更新目录」是同一条链路，只是能指定书；返回是否真的换了目录。
   * 三条提示文案与更新目录保持一致，不另起措辞。
   */
  private async refreshBookInfo(book: Book): Promise<boolean> {
    if (!book.isLocal || book.format !== 'txt' || book.contentPath === undefined) {
      this.showUnavailableAction('仅本地 TXT 书籍支持更新目录');
      return false;
    }
    const context = this.getUIContext().getHostContext();
    if (context === undefined) {
      this.showUnavailableAction('无法访问本地书架，未更新目录');
      return false;
    }
    let result: TocRefreshResult;
    try {
      result = BookRepository.refreshToc(book, this.readerMaxLengthWithNoToc);
    } catch (_) {
      this.showUnavailableAction('读取正文失败，目录未更新');
      return false;
    }
    if (!result.changed) {
      this.showUnavailableAction('目录没有变化');
      return false;
    }
    const nextBook = result.book;
    const updatedBooks = this.books.map((item: Book) => item.id === nextBook.id ? nextBook : item);
    try {
      await BookRepository.saveImportedBooks(context,
        updatedBooks.filter((item: Book) => BookRepository.isPersistableBook(item)));
      // 目录重算会重建整份章节行；books 行本来就在，先把 chapters 表覆盖掉。
      await BookRepository.saveChapters(context, nextBook.contentPath ?? '', result.chapters);
    } catch (_) {
      this.showUnavailableAction('目录已更新，但保存失败，重新打开后可能回到旧目录');
      return false;
    }
    this.books = updatedBooks;
    this.selectedBook = nextBook;
    const chapterCount = result.chapters.length;
    this.showUnavailableAction(`更新目录完成：共 ${chapterCount} 章`);
    return true;
  }

  /** 置顶（批 7 的 `:284`）：order 落到最小值的更前一位。 */
  private async topSelectedBook(book: Book): Promise<void> {
    const context = this.getUIContext().getHostContext();
    if (context === undefined) {
      this.showUnavailableAction('无法访问本地书架');
      return;
    }
    try {
      await BookRepository.topBook(context, book);
    } catch (error) {
      this.showUnavailableAction(error instanceof Error ? error.message : '置顶失败');
      return;
    }
    const reloaded = await BookRepository.loadImportedBooks(context);
    this.books = reloaded.filter((item: Book) => BookRepository.isPersistableBook(item));
    const updated = this.books.find((item: Book) => item.id === book.id);
    if (updated !== undefined) { this.selectedBook = updated; }
    this.showUnavailableAction('已置顶');
  }

  /** 翻转「删除前先确认」（批 7 的 `:291`）。 */
  private async toggleBookInfoDeleteAlert(): Promise<void> {
    const context = this.getUIContext().getHostContext();
    if (context === undefined) { return; }
    const next: boolean = !this.bookInfoDeleteAlert;
    try {
      await BookInfoSettingsRepository.save(context, { deleteAlert: next });
    } catch (_) {
      this.showUnavailableAction('删除确认设置保存失败');
      return;
    }
    this.bookInfoDeleteAlert = next;
    this.showUnavailableAction(next ? '移出书架前会先确认' : '移出书架不再确认');
  }

  /** 详情页书名/作者点击：预填关键词并进搜索页（批 7 的 `:296` `:297`）。 */
  private openSearchWithKeyword(keyword: string): void {
    this.searchPageQuery = keyword;
    this.openSearch();
  }

  /**
   * 应用「目录规则预览页」选中的规则：写回 Book.tocRule 并按这条规则重切目录。
   *
   * 对齐上游 `TocViewModel.saveTocRegex`（`ui/book/toc/TocViewModel.kt:802-814`）：
   * 上游写 `book.tocUrl = newRegex` 后调 `replaceChaptersAndUpdateBook` 重算章节。
   * 本地对应 `BookRepository.refreshToc(..., forcedRule)`，它会把新规则写进 `Book.tocRule`。
   *
   * 与「更新目录」的区别只在规则来源：这里用用户挑定的那条，不再按规则库自动选。
   */
  private async applyTocRule(chapterRule: string, ruleName: string): Promise<void> {
    const book = this.selectedBook;
    if (!book.isLocal || book.format !== 'txt' || book.contentPath === undefined) {
      this.showUnavailableAction('仅本地 TXT 书籍支持应用目录规则');
      return;
    }
    const context = this.getUIContext().getHostContext();
    if (context === undefined) {
      this.showUnavailableAction('无法访问本地书架，规则未应用');
      return;
    }
    let result: TocRefreshResult;
    try {
      result = BookRepository.refreshToc(book, this.readerMaxLengthWithNoToc, [], chapterRule);
    } catch (_) {
      this.showUnavailableAction('读取正文失败，规则未应用');
      return;
    }
    const nextBook = result.book;
    const updatedBooks = this.books.map((item: Book) => item.id === nextBook.id ? nextBook : item);
    try {
      await BookRepository.saveImportedBooks(context,
        updatedBooks.filter((item: Book) => BookRepository.isPersistableBook(item)));
      if (result.changed) {
        await BookRepository.saveChapters(context, nextBook.contentPath ?? '', result.chapters);
      }
    } catch (_) {
      this.showUnavailableAction('规则已应用，但保存失败，重新打开后可能回到旧目录');
      return;
    }
    this.books = updatedBooks;
    this.selectedBook = nextBook;
    if (!result.changed) {
      // 规则没变或切出来的目录完全一致：上游同样会提示 success（它只区分失败），
      // 这里给更具体的一句话，免得用户以为没生效。
      this.showUnavailableAction(`已应用「${ruleName}」，目录无变化`);
      return;
    }
    this.showUnavailableAction(`已应用「${ruleName}」：共 ${result.chapters.length} 章`);
  }
  /**
   * 打开书籍前检查「同书名 + 作者为空」的旧阅读记录归属。
   * 决定持久化在 readRecordAliasDecisions；同名多副本时不沿用旧决定，重新确认。
   * 对应上游 ReadRecordAliasDelegate.check / resolve，弹窗在独立协程里进行，不阻塞开书。
   */
  private checkReadRecordAlias(book: Book): void {
    const context = this.getUIContext().getHostContext();
    if (context === undefined || book.author.trim().length === 0) { return; }
    ReadRecordRepository.loadUnknownAuthorRecords(context, book.title).then(
      async (sources: ReadRecordSummary[]): Promise<void> => {
        if (sources.length === 0) { return; }
        const key = ReadRecordRepository.aliasKey(book.title, book.author);
        const decision = await ReadRecordRepository.loadAliasDecision(context, key);
        const shelfCopies = this.books.filter((item: Book) =>
          item.title === book.title && item.author === book.author).length;
        const ambiguous = shelfCopies > 1;
        if (!ambiguous && decision === 'KEEP') { return; }
        if (!ambiguous && decision === 'MERGE') {
          const target: ReadRecordSummary = {
            deviceId: '', bookName: book.title, bookAuthor: book.author,
            readTime: 0, lastRead: 0
          };
          await ReadRecordRepository.mergeReadRecords(context, target, sources);
          await this.reloadReadRecordData(context);
          return;
        }
        const totalMs = sources.reduce((total: number, item: ReadRecordSummary) => total + item.readTime, 0);
        const merge = await this.askReadRecordAlias(book.title, ReadRecordRepository.formatDuration(totalMs));
        await ReadRecordRepository.saveAliasDecision(context, key, merge);
        if (merge) {
          const target: ReadRecordSummary = {
            deviceId: '', bookName: book.title, bookAuthor: book.author,
            readTime: 0, lastRead: 0
          };
          await ReadRecordRepository.mergeReadRecords(context, target, sources);
          await this.reloadReadRecordData(context);
        }
      });
  }

  /** 「合并还是保留」弹窗；选完由 checkReadRecordAlias 记住决定。 */
  private askReadRecordAlias(bookTitle: string, totalLabel: string): Promise<boolean> {
    return new Promise<boolean>((resolve: (value: boolean) => void) => {
      this.getUIContext().showAlertDialog({
        title: '合并还是保留',
        message: `《${bookTitle}》存在作者为空的旧阅读记录（累计 ${totalLabel}）。是否合并到当前作者？`,
        autoCancel: false,
        primaryButton: { value: '保留', action: () => resolve(false) },
        secondaryButton: { value: '合并', action: () => resolve(true) }
      });
    });
  }

  private async openBook(book: Book): Promise<void> {
    this.checkReadRecordAlias(book);
    if (book.contentPath === undefined) {
      this.showUnavailableAction(BookRepository.isBodyMissing(book)
        ? '已恢复书目和阅读位置；备份不含正文，请重新选择原书文件后阅读'
        : '此书暂时没有可用正文');
      return;
    }
    let openedBook: Book = book;
    let content: string = '';
    try {
      const noTocRefresh = BookRepository.refreshNoTocBook(book, this.readerMaxLengthWithNoToc);
      openedBook = noTocRefresh.book;
      // 先把章节行读进缓存再取正文：readChapter 拿不到章节行时会退化成「整本重切一遍」，
      // 几 MB 的书要两秒以上，主线程会被 watchdog 判成 THREAD_BLOCK_6S。
      const chapterContext = this.getUIContext().getHostContext();
      if (chapterContext !== undefined) {
        await BookRepository.loadChapters(chapterContext, openedBook);
      }
      content = await BookRepository.readChapter(openedBook, openedBook.lastChapter,
        openedBook.chapterIndex, noTocRefresh.content.length > 0 ? noTocRefresh.content : undefined);
      this.replaceRules = ReplaceRuleRepository.getAll();
      if (noTocRefresh.changed) {
        const context = this.getUIContext().getHostContext();
        if (context === undefined) {
          this.showUnavailableAction('无法访问本地书架，未应用新的无目录分段设置');
          return;
        }
        const updatedBooks = this.books.map((item: Book) =>
          item.id === openedBook.id ? openedBook : item);
        try {
          await BookRepository.saveImportedBooks(context,
            updatedBooks.filter((item: Book) => BookRepository.isPersistableBook(item)));
          // 无目录分段会重排章节行，跟着一起覆盖。
          if (noTocRefresh.chapters.length > 0) {
            await BookRepository.saveChapters(context, openedBook.contentPath ?? '',
              noTocRefresh.chapters);
          }
        } catch (error) {
          this.showUnavailableAction(error instanceof Error
            ? '无目录分段设置保存失败：' + error.message : '无目录分段设置保存失败');
          return;
        }
        this.books = updatedBooks;
      }
    } catch (error) {
      this.showUnavailableAction(error instanceof Error ? '打开失败：' + error.message : '本地书籍文件无法读取');
      return;
    }
    // 打开书即清零 lastCheckCount，让「有更新」红点消失（上游 ReadBook.kt:1879）。
    if ((openedBook.lastCheckCount ?? 0) > 0) {
      const clearContext = this.getUIContext().getHostContext();
      if (clearContext !== undefined) {
        const cleared: Book = BookRepository.copyBook(openedBook);
        cleared.lastCheckCount = 0;
        openedBook = cleared;
        try {
          await BookRepository.saveImportedBooks(clearContext,
            this.books.map((item: Book) => item.id === cleared.id ? cleared : item)
              .filter((item: Book) => BookRepository.isPersistableBook(item)));
          this.books = this.books.map((item: Book) => item.id === cleared.id ? cleared : item);
        } catch (_) {
          // 清零落库失败不妨碍阅读，红点下次刷新会重新计算。
        }
      }
    }
    this.readerReturnRoute = this.route;
    this.discardReaderAnchor();
    // 普通开书不强制回到章首：startAtChapterBeginning 的语义是「用户主动要求从本章开头重读」，
    // 只有书签跳转/选章那几处才置 false 以外的分支。这里曾经置 true，导致每次开书都停在第 1 页，
    // 完全忽略 book.androidCharacterPosition 里存的阅读位置。
    this.readerStartAtChapterBeginning = false;
    this.selectedBook = openedBook;
    this.readerReplaceEnabled = ReplaceRuleRepository.isBookEnabled(openedBook);
    this.readerReplaceUsesDefault = ReplaceRuleRepository.isBookUsingDefault(openedBook);
    this.selectedChapter = openedBook.lastChapter;
    this.readerContent = content;
    this.route = AppRoute.READER;
  }  private openBookInfo(book: Book): void {
    this.bookInfoReturnRoute = this.route;
    this.selectedBook = book;
    this.route = AppRoute.BOOK_INFO;
  }

  private async addBookshelfGroup(name: string): Promise<void> {
    const context = this.getUIContext().getHostContext();
    if (context === undefined) { this.showUnavailableAction('无法访问书架分组存储'); return; }
    try {
      await BookGroupRepository.add(context, name);
      this.bookGroups = BookGroupRepository.getAll();
    } catch (error) {
      this.showUnavailableAction(error instanceof Error ? error.message : '新增分组失败');
    }
  }

  private async renameBookshelfGroup(groupId: number, newName: string): Promise<void> {
    const context = this.getUIContext().getHostContext();
    const group = this.bookGroups.find((item: BookGroup) => item.groupId === groupId);
    if (context === undefined || group === undefined) { return; }
    const oldName = group.groupName;
    const nextName = newName.trim();
    if (nextName === oldName) { return; }
    const nextBooks = this.books.map((book: Book): Book => {
      const names = book.groupNames ?? [];
      if (!names.includes(oldName)) { return book; }
      const updatedNames = names.map((name: string) => name === oldName ? nextName : name);
      return BookRepository.withShelfMetadata(book, updatedNames, updatedNames.join('、'), book.customTag);
    });
    try {
      await BookRepository.saveImportedBooks(context, nextBooks.filter((book: Book) => BookRepository.isPersistableBook(book)));
      await BookGroupRepository.rename(context, groupId, nextName);
      this.books = nextBooks;
      this.bookGroups = BookGroupRepository.getAll();
    } catch (error) {
      this.showUnavailableAction(error instanceof Error ? error.message : '重命名分组失败');
    }
  }

  private async setBookshelfGroupVisible(groupId: number, visible: boolean): Promise<void> {
    const context = this.getUIContext().getHostContext();
    if (context === undefined) { return; }
    try {
      await BookGroupRepository.setVisible(context, groupId, visible);
      this.bookGroups = BookGroupRepository.getAll();
    } catch (_) {
      this.showUnavailableAction('分组显示状态保存失败');
    }
  }

  /** 启动时读私密设置（批6）。解锁态本来就不落盘，load 出来恒为锁定。 */
  private async restoreBookInfoSettings(context: Context): Promise<void> {
    this.bookInfoDeleteAlert = (await BookInfoSettingsRepository.load(context)).deleteAlert;
  }

  private async restoreHighlightTagRules(context: Context): Promise<void> {
    this.highlightTagRules = await HighlightTagRuleRepository.load(context);
  }

  private async restorePrivateAccess(context: Context): Promise<void> {
    await PrivateAccessRepository.load(context);
  }

  /** 单本私密标记（:294）：窄 UPDATE 只动 isPrivate 一列，写完重读整行。 */
  private async setBookPrivate(book: Book, isPrivate: boolean): Promise<void> {
    const context = this.getUIContext().getHostContext();
    if (context === undefined) {
      this.showUnavailableAction('无法访问本地书架');
      return;
    }
    const bookUrl = book.contentPath ?? book.androidOriginalPath ?? '';
    if (bookUrl.length === 0) { return; }
    // 没设过本地密码就标私密，这本书会立刻被锁住又没有解锁入口（上游的私密按钮
    // 同样只在 hasPassword 时出现）。这里挡在前面给提示，不留一个锁死的书。
    if (isPrivate && PrivateAccessRepository.get().hasPassword !== true) {
      this.showUnavailableAction('请先到「我的 → 设置 → 隐私设置」设置本地密码');
      return;
    }
    try {
      await BookRepository.setBooksPrivate(context, [bookUrl], isPrivate);
      const updated = BookRepository.copyBook(book);
      updated.isPrivate = isPrivate;
      this.books = this.books.map((item: Book) => item.id === book.id ? updated : item);
      if (this.selectedBook.id === book.id) { this.selectedBook = updated; }
      this.showUnavailableAction(isPrivate ? '已设为私密' : '已取消私密');
    } catch (error) {
      this.showUnavailableAction(error instanceof Error ? error.message : '私密标记保存失败');
    }
  }

  /** 批量私密标记（:147）。 */
  private async setBooksPrivateByKeys(bookKeys: string[], isPrivate: boolean): Promise<void> {
    const context = this.getUIContext().getHostContext();
    if (context === undefined) {
      this.showUnavailableAction('无法访问本地书架');
      return;
    }
    if (bookKeys.length === 0) { return; }
    if (isPrivate && PrivateAccessRepository.get().hasPassword !== true) {
      this.showUnavailableAction('请先到「我的 → 设置 → 隐私设置」设置本地密码');
      return;
    }
    try {
      await BookRepository.setBooksPrivate(context, bookKeys, isPrivate);
      const reloaded = await BookRepository.loadImportedBooks(context);
      this.books = reloaded.filter((book: Book) => BookRepository.isPersistableBook(book));
      this.showUnavailableAction(isPrivate ? `已把 ${bookKeys.length} 本设为私密` : `已取消 ${bookKeys.length} 本的私密标记`);
    } catch (error) {
      this.showUnavailableAction(error instanceof Error ? error.message : '私密标记保存失败');
    }
  }

  /** 全量应用标签匹配规则（:241）：规则表 load 一次，算出被改动的书落库并刷新书架。 */
  private async applyTagGroupRules(): Promise<void> {
    const context = this.getUIContext().getHostContext();
    if (context === undefined) { return; }
    try {
      const rules = await TagGroupRuleRepository.load(context);
      const changed = await TagGroupRuleSync.apply(this.books, rules);
      if (changed.length > 0) {
        await BookRepository.saveImportedBooks(context, changed);
        this.books = this.books.map((book: Book): Book => {
          const key = book.contentPath ?? book.androidOriginalPath ?? '';
          const hit = changed.find((item: Book) =>
            (item.contentPath ?? item.androidOriginalPath ?? '') === key);
          return hit !== undefined ? hit : book;
        });
      }
      this.showUnavailableAction('同步完成');
    } catch (error) {
      this.showUnavailableAction(error instanceof Error ? error.message : '标签分组同步失败');
    }
  }

  /** 把若干本书挪到指定分组（批 5 的 :146）；走替换语义，空 groupName 表示移回未分组。 */
  private async setBooksGroupByKeys(bookKeys: string[], groupName: string): Promise<void> {
    const context = this.getUIContext().getHostContext();
    if (context === undefined) {
      this.showUnavailableAction('无法访问本地书架');
      return;
    }
    try {
      await BookRepository.setBooksGroup(context, bookKeys, groupName);
      const reloaded = await BookRepository.loadImportedBooks(context);
      this.books = reloaded.filter((book: Book) => BookRepository.isPersistableBook(book));
    } catch (error) {
      this.showUnavailableAction(error instanceof Error ? error.message : '移动分组失败');
    }
  }

  /** 批量删书（批 5 的 :148 / :149）。deleteSource 只清应用内导入副本，原始文件不动。 */
  private async deleteBooksFromShelf(books: Book[], deleteSource: boolean): Promise<void> {
    const context = this.getUIContext().getHostContext();
    if (context === undefined) {
      this.showUnavailableAction('无法访问本地书架');
      return;
    }
    if (books.length === 0) { return; }
    try {
      await BookRepository.deleteBooks(context, books, deleteSource);
      const removed: Set<string> = new Set<string>();
      books.forEach((book: Book) => { removed.add(book.contentPath ?? book.androidOriginalPath ?? ''); });
      this.books = this.books.filter((book: Book) =>
        !removed.has(book.contentPath ?? book.androidOriginalPath ?? ''));
    } catch (error) {
      this.showUnavailableAction(error instanceof Error ? error.message : '批量删除失败');
    }
  }

  /**
   * 拖拽重排后落库（批 5 的 :138）。
   * 只有「手动」排序（bookSort === 3）会读 order 列，其它排序下拖完屏幕不会有变化，
   * 这是上游行为；order 仍然落库，切回手动排序才看得出顺序。
   */
  private async moveBooksInShelf(ordered: Book[]): Promise<void> {
    const context = this.getUIContext().getHostContext();
    if (context === undefined) {
      this.showUnavailableAction('无法访问本地书架');
      return;
    }
    try {
      const descending = this.bookshelfLayout.bookshelfSortOrder === 1;
      await BookRepository.saveBookOrder(context, ordered, descending);
      const reloaded = await BookRepository.loadImportedBooks(context);
      this.books = reloaded.filter((book: Book) => BookRepository.isPersistableBook(book));
    } catch (error) {
      this.showUnavailableAction(error instanceof Error ? error.message : '保存排序失败');
    }
  }

  private async removeBookshelfGroup(groupId: number): Promise<void> {
    const context = this.getUIContext().getHostContext();
    const group = this.bookGroups.find((item: BookGroup) => item.groupId === groupId);
    if (context === undefined || group === undefined) { return; }
    const nextBooks = this.books.map((book: Book): Book => {
      const names = (book.groupNames ?? []).filter((name: string) => name !== group.groupName);
      return names.length === (book.groupNames ?? []).length ? book
        : BookRepository.withShelfMetadata(book, names, names.join('、') || '本地未分组', book.customTag);
    });
    try {
      await BookRepository.saveImportedBooks(context, nextBooks.filter((book: Book) => BookRepository.isPersistableBook(book)));
      await BookGroupRepository.remove(context, groupId);
      // 删分组时把绑定该分组名的规则一并删掉（上游 BookGroupMutationRepository:85-91）。
      try {
        const rules = await TagGroupRuleRepository.load(context);
        const kept = rules.filter((rule: TagGroupRule) => rule.groupName !== group.groupName);
        if (kept.length !== rules.length) { await TagGroupRuleRepository.save(context, kept); }
      } catch (ruleError) {
        console.error(`[Index] 删除分组同步标签规则失败: ${ruleError}`);
      }
      this.books = nextBooks;
      this.bookGroups = BookGroupRepository.getAll();
    } catch (error) {
      this.showUnavailableAction(error instanceof Error ? error.message : '删除分组失败');
    }
  }

  /** 保存封面文字设置。 */
  private async saveCoverSettings(settings: CoverSettings): Promise<void> {
    const context = this.getUIContext().getHostContext();
    if (context === undefined) {
      this.showUnavailableAction('封面设置保存失败');
      return;
    }
    try {
      await CoverSettingsRepository.save(context, settings);
      this.coverSettings = copyCoverSettings(settings);
    } catch (error) {
      console.error(`[Index] 保存封面设置失败: ${error}`);
      this.showUnavailableAction('封面设置保存失败，当前值未更改');
    }
  }

  /** 保存书架布局设置。 */
  private async saveBookshelfLayout(settings: BookshelfLayoutSettings): Promise<void> {
    const context = this.getUIContext().getHostContext();
    if (context === undefined) {
      this.showUnavailableAction('书架布局设置保存失败');
      return;
    }
    try {
      await BookshelfLayoutRepository.save(context, settings);
      this.bookshelfLayout = copyBookshelfLayout(settings);
    } catch (_) {
      this.showUnavailableAction('书架布局设置保存失败，当前值未更改');
    }
  }

  /** 按完整草稿新建分组，供分组编辑面板提交。 */
  private async addBookshelfGroupDraft(draft: BookGroupDraft): Promise<void> {
    const context = this.getUIContext().getHostContext();
    if (context === undefined) { this.showUnavailableAction('无法访问书架分组存储'); return; }
    try {
      await BookGroupRepository.addWithDraft(context, draft);
      this.bookGroups = BookGroupRepository.getAll();
    } catch (error) {
      this.showUnavailableAction(error instanceof Error ? error.message : '新增分组失败');
    }
  }

  /** 保存分组编辑面板的属性；名称变更需要同步改写书籍上的分组名。 */
  private async updateBookshelfGroup(groupId: number, draft: BookGroupDraft): Promise<void> {
    const context = this.getUIContext().getHostContext();
    const group = this.bookGroups.find((item: BookGroup) => item.groupId === groupId);
    if (context === undefined || group === undefined) { return; }
    const oldName = group.groupName;
    const nextName = draft.groupName.trim();
    if (nextName !== oldName) {
      const nextBooks = this.books.map((book: Book): Book => {
        const names = book.groupNames ?? [];
        if (!names.includes(oldName)) { return book; }
        const updatedNames = names.map((name: string) => name === oldName ? nextName : name);
        return BookRepository.withShelfMetadata(book, updatedNames, updatedNames.join('、'), book.customTag);
      });
      try {
        await BookRepository.saveImportedBooks(context,
          nextBooks.filter((book: Book) => BookRepository.isPersistableBook(book)));
        this.books = nextBooks;
      } catch (error) {
        this.showUnavailableAction(error instanceof Error ? error.message : '重命名分组失败');
        return;
      }
    }
    // 规则按分组名关联：分组改名时把绑定旧名的规则一并改成新名（4d 硬约束，
    // 上游 BookGroupMutationRepository.saveGroup / deleteGroup 同款联动）。
    if (nextName !== oldName) {
      try {
        const rules = await TagGroupRuleRepository.load(context);
        let renamed = false;
        const nextRules = rules.map((rule: TagGroupRule): TagGroupRule => {
          if (rule.groupName !== oldName) { return rule; }
          renamed = true;
          return { id: rule.id, pattern: rule.pattern, groupName: nextName, order: rule.order };
        });
        if (renamed) { await TagGroupRuleRepository.save(context, nextRules); }
      } catch (ruleError) {
        console.error(`[Index] 分组改名同步标签规则失败: ${ruleError}`);
      }
    }
    try {
      await BookGroupRepository.updateSettings(context, groupId, draft);
      this.bookGroups = BookGroupRepository.getAll();
    } catch (error) {
      this.showUnavailableAction(error instanceof Error ? error.message : '保存分组设置失败');
    }
  }

  /** 选择分组封面，返回新的封面路径；用户取消或失败时返回空串。 */
  private async chooseBookshelfGroupCover(groupId: number): Promise<string> {
    const context = this.getUIContext().getHostContext();
    if (context === undefined) { return ''; }
    try {
      const group = await BookGroupRepository.chooseCover(context, groupId);
      this.bookGroups = BookGroupRepository.getAll();
      return group?.cover ?? '';
    } catch (error) {
      this.showUnavailableAction(error instanceof Error ? error.message : '设置分组封面失败');
      return '';
    }
  }

  /** 清除分组封面。 */
  private async clearBookshelfGroupCover(groupId: number): Promise<void> {
    const context = this.getUIContext().getHostContext();
    if (context === undefined) { return; }
    try {
      await BookGroupRepository.clearCover(context, groupId);
      this.bookGroups = BookGroupRepository.getAll();
    } catch (_) {
      this.showUnavailableAction('清除分组封面失败');
    }
  }

  /** 拖拽后重排分组顺序。 */
  private async moveBookshelfGroup(fromId: number, toId: number): Promise<void> {
    const context = this.getUIContext().getHostContext();
    if (context === undefined) { return; }
    try {
      await BookGroupRepository.move(context, fromId, toId);
      this.bookGroups = BookGroupRepository.getAll();
    } catch (_) {
      this.showUnavailableAction('分组排序保存失败');
    }
  }

  private async saveBookMetadata(title: string, author: string, category: string,
    description: string, remark: string, customTag: string, groupNames: string[],
    bookType: BookMediaType, fixedType: boolean): Promise<boolean> {
    const currentBook = this.books.find((book: Book) => book.id === this.selectedBook.id);
    if (currentBook === undefined || !currentBook.isLocal) {
      this.showUnavailableAction('当前书籍不在本地书架，未保存书籍信息');
      return false;
    }
    const updatedBook: Book = BookRepository.copyBook(currentBook);
    updatedBook.title = title;
    updatedBook.author = author;
    updatedBook.category = category;
    updatedBook.groupName = groupNames.length > 0 ? groupNames.join('、') : '本地未分组';
    updatedBook.groupNames = groupNames;
    updatedBook.bookType = bookType;
    updatedBook.fixedType = fixedType;
    updatedBook.description = description;
    updatedBook.remark = remark;
    updatedBook.customTag = customTag;
    const updatedBooks = this.books.map((book: Book) => book.id === updatedBook.id ? updatedBook : book);
    const context = this.getUIContext().getHostContext();
    if (context === undefined) {
      this.showUnavailableAction('无法访问本地书架，书籍信息未保存');
      return false;
    }
    try {
      await BookRepository.saveImportedBooks(context,
        updatedBooks.filter((book: Book) => BookRepository.isPersistableBook(book)));
      this.books = updatedBooks;
      this.selectedBook = updatedBook;
      return true;
    } catch (_) {
      this.showUnavailableAction('书籍信息保存失败，未更改原有信息');
      return false;
    }
  }

  private async persistCoverUpdate(updatedBook: Book, oldCoverPath: string | undefined): Promise<void> {
    const context = this.getUIContext().getHostContext();
    if (context === undefined) {
      BookRepository.removeCustomCover(updatedBook.customCoverUri);
      this.showUnavailableAction('无法访问本地书架，封面未保存');
      return;
    }
    const updatedBooks = this.books.map((book: Book) => book.id === updatedBook.id ? updatedBook : book);
    try {
      await BookRepository.saveImportedBooks(context,
        updatedBooks.filter((book: Book) => BookRepository.isPersistableBook(book)));
      this.books = updatedBooks;
      this.selectedBook = updatedBook;
      if (oldCoverPath !== updatedBook.customCoverUri) {
        BookRepository.removeCustomCover(oldCoverPath);
      }
    } catch (error) {
      if (oldCoverPath !== updatedBook.customCoverUri) {
        BookRepository.removeCustomCover(updatedBook.customCoverUri);
      }
      this.showUnavailableAction(error instanceof Error ? error.message : '封面保存失败，原封面已保留');
    }
  }

  private async chooseBookCover(): Promise<void> {
    const context = this.getUIContext().getHostContext();
    if (context === undefined) {
      this.showUnavailableAction('无法访问本地文件，未更换封面');
      return;
    }
    const oldCoverPath = this.selectedBook.customCoverUri;
    try {
      const updatedBook = await BookRepository.chooseCustomCover(context, this.selectedBook);
      if (updatedBook !== undefined) {
        await this.persistCoverUpdate(updatedBook, oldCoverPath);
      }
    } catch (error) {
      this.showUnavailableAction(error instanceof Error ? error.message : '选择封面失败');
    }
  }

  private async restoreBookCover(): Promise<void> {
    const context = this.getUIContext().getHostContext();
    if (context === undefined) {
      this.showUnavailableAction('无法访问本地书架，未还原封面');
      return;
    }
    const oldCoverPath = this.selectedBook.customCoverUri;
    const updatedBook = BookRepository.restoreEmbeddedCover(context, this.selectedBook);
    await this.persistCoverUpdate(updatedBook, oldCoverPath);
  }

  private async removeLocalBookFromShelf(book: Book, deleteSource: boolean = true): Promise<void> {
    if (book.contentPath === undefined && !BookRepository.isBodyMissing(book)) {
      this.showUnavailableAction('这本书没有可清理的本地导入副本');
      return;
    }
    const context = this.getUIContext().getHostContext();
    if (context === undefined) {
      this.showUnavailableAction('无法访问本地书架');
      return;
    }
    const remainingBooks = this.books.filter((item: Book) => item.id !== book.id);
    const booksToSave = remainingBooks.filter((item: Book) => BookRepository.isPersistableBook(item));
    try {
      // saveImportedBooks 只做 upsert，不会清掉缺席的书：照上游显式删章节行与 books 行。
      await BookRepository.deleteBook(context, book);
      await BookRepository.saveImportedBooks(context, booksToSave);
    } catch (error) {
      this.showUnavailableAction(error instanceof Error ? error.message : '移出书架失败，原书籍仍保留');
      return;
    }
    this.books = remainingBooks;
    this.route = this.bookInfoReturnRoute;
    // deleteSource 未勾选时保留应用内副本（批 7 的 `:339`）；原始文件两种情况都不动。
    if (deleteSource && book.contentPath !== undefined) {
      try {
        BookRepository.discardImportedCopy(book);
      } catch (_) {
        this.showUnavailableAction('已从书架移除，但应用内副本清理失败');
      }
    }
  }

  private async openCatalogFromBookInfo(): Promise<void> {
    const chapters = BookRepository.cachedChapterTitles(this.selectedBook);
    if (this.selectedBook.contentPath === undefined || chapters.length === 0) {
      this.showUnavailableAction(BookRepository.isBodyMissing(this.selectedBook)
        ? 'Android 备份不含章节目录或正文，请重新导入原书文件后查看'
        : '这本书暂时没有可查看的本地目录');
      return;
    }
    const chapterIndex = Math.max(0, Math.min(chapters.length - 1, this.selectedBook.chapterIndex ?? 0));
    const chapterTitle = chapters[chapterIndex];
    if (chapterTitle === undefined) {
      this.showUnavailableAction('目录信息暂不可用');
      return;
    }
    try {
      this.readerContent = await BookRepository.readChapter(this.selectedBook, chapterTitle);
      this.replaceRules = ReplaceRuleRepository.getAll();
    } catch (error) {
      this.showUnavailableAction(error instanceof Error ? `读取章节失败：${error.message}` : '章节文件无法读取');
      return;
    }
    this.selectedChapter = chapterTitle;
    this.readerReturnRoute = AppRoute.BOOK_INFO;
    this.catalogReturnRoute = AppRoute.BOOK_INFO;
    this.route = AppRoute.CATALOG;
  }
  private openReaderSettings(openBottomActionConfig: boolean = false): void {
    this.settingsReturnRoute = this.route;
    this.readerSettingsOpenBottomActionConfig = openBottomActionConfig;
    this.route = AppRoute.READER_SETTINGS;
  }
  private openSearch(): void {
    this.searchReturnRoute = this.route;
    this.route = AppRoute.SEARCH;
  }
  private openReaderSearch(): void {
    this.route = AppRoute.READER_SEARCH;
  }

  private returnToReaderMenu(): void {
    this.readerControlsOpenOnReturn = true;
    this.route = AppRoute.READER;
  }

  private openReadAloudSettings(): void {
    this.route = AppRoute.READ_ALOUD_SETTINGS;
  }
  private async updateReadingProgress(
    chapterProgress: number,
    chapterPosition: number,
    androidCoordinate: boolean = false
  ): Promise<void> {
    const chapterTitles = BookRepository.cachedChapterTitles(this.selectedBook);
    const effectiveTitles = chapterTitles.length > 0 ? chapterTitles : [this.selectedChapter];
    const chapterIndex = Math.max(0, Math.min(effectiveTitles.length - 1,
      this.selectedBook.chapterIndex ?? effectiveTitles.indexOf(this.selectedChapter)));
    const chapterCount = Math.max(1, effectiveTitles.length);
    const safeChapterProgress = Math.max(0, Math.min(100, chapterProgress));
    const updatedBook: Book = BookRepository.copyBook(this.selectedBook);
    updatedBook.chapterIndex = chapterIndex;
    updatedBook.chapterProgress = safeChapterProgress;
    updatedBook.lastChapter = this.selectedChapter;
    updatedBook.progress = (chapterIndex + safeChapterProgress / 100) / chapterCount * 100;
    // 阅读位置只有一套语义：durChapterPos 一律存字符坐标，渲染前才换算。
    // 旧的 readerPositionVersion 已随迁移删除，位置类型不再区分。
    updatedBook.androidCharacterPosition = Math.max(0, Math.trunc(chapterPosition));
    // 保存阅读进度就是「刚读过」，用来驱动书架的按最近列表 / 综合排序。
    updatedBook.durChapterTime = Date.now();
    this.selectedBook = updatedBook;
    this.books = this.books.map((book: Book) => book.id === updatedBook.id ? updatedBook : book);
    if (this.selectedBook.contentPath === undefined) {
      return;
    }
    const context = this.getUIContext().getHostContext();
    if (context !== undefined) {
      const importedBooks = this.books.filter((book: Book) => BookRepository.isPersistableBook(book));
      try {
        await BookRepository.saveImportedBooks(context, importedBooks);
      } catch (_) {
        this.showUnavailableAction('阅读进度保存失败，重新打开后可能回到上次位置');
      }
    }
  }
  private async setReaderImageStyle(imageStyle: string): Promise<void> {
    const allowedStyles: string[] = ['DEFAULT', 'FULL', 'TEXT', 'SINGLE'];
    if (!allowedStyles.includes(imageStyle) || this.selectedBook.imageStyle === imageStyle) { return; }
    const updatedBook: Book = BookRepository.copyBook(this.selectedBook);
    updatedBook.imageStyle = imageStyle;
    this.selectedBook = updatedBook;
    this.books = this.books.map((book: Book) => book.id === updatedBook.id ? updatedBook : book);
    const context = this.getUIContext().getHostContext();
    if (context === undefined || !BookRepository.isPersistableBook(updatedBook)) { return; }
    try {
      await BookRepository.saveImportedBooks(context,
        this.books.filter((book: Book) => BookRepository.isPersistableBook(book)));
    } catch (_) {
      this.showUnavailableAction('图片样式保存失败，重新打开后可能恢复默认样式');
    }
  }

  private async setReaderReSegment(enabled: boolean): Promise<void> {
    if (this.selectedBook.reSegment === enabled || this.selectedBook.contentPath === undefined) { return; }
    const context = this.getUIContext().getHostContext();
    if (context === undefined) {
      this.showUnavailableAction('无法保存重分段设置');
      return;
    }
    const updatedBook = BookRepository.withReSegment(this.selectedBook, enabled);
    const chapterTitles = BookRepository.cachedChapterTitles(updatedBook);
    const chapterIndex = Math.max(0, Math.min(Math.max(0, chapterTitles.length - 1),
      updatedBook.chapterIndex ?? chapterTitles.indexOf(this.selectedChapter)));
    const chapterTitle = chapterTitles[chapterIndex] ?? this.selectedChapter;
    let updatedContent: string;
    try {
      updatedContent = await BookRepository.readChapter(updatedBook, chapterTitle, chapterIndex);
      this.replaceRules = ReplaceRuleRepository.getAll();
    } catch (error) {
      this.showUnavailableAction(error instanceof Error ? `重新分段失败：${error.message}` : '重新分段失败');
      return;
    }
    const updatedBooks = this.books.map((book: Book) => book.id === updatedBook.id ? updatedBook : book);
    try {
      await BookRepository.saveImportedBooks(context,
        updatedBooks.filter((book: Book) => BookRepository.isPersistableBook(book)));
    } catch (error) {
      this.showUnavailableAction(error instanceof Error ? error.message : '重分段设置保存失败');
      return;
    }
    this.selectedBook = updatedBook;
    this.books = updatedBooks;
    this.selectedChapter = chapterTitle;
    this.readerContent = updatedContent;
    this.showUnavailableAction(enabled ? '已开启重新分段' : '已关闭重新分段');
  }

  private async setReaderCharset(charset: string): Promise<void> {
    if (this.selectedBook.contentPath === undefined) {
      this.showUnavailableAction('备份只恢复了书目，缺少正文文件，无法设置字符集');
      return;
    }
    let updatedBook: Book;
    let updatedChapters: BookChapter[];
    let content: string;
    let chapterTitle: string;
    try {
      const converted = BookRepository.withCharset(this.selectedBook, charset, this.readerMaxLengthWithNoToc);
      updatedBook = converted.book;
      updatedChapters = converted.chapters;
      const titles = BookRepository.cachedChapterTitles(updatedBook);
      const chapterIndex = Math.max(0, Math.min(Math.max(0, titles.length - 1), updatedBook.chapterIndex ?? 0));
      chapterTitle = titles[chapterIndex] ?? updatedBook.lastChapter;
      content = await BookRepository.readChapter(updatedBook, chapterTitle);
      this.replaceRules = ReplaceRuleRepository.getAll();
    } catch (error) {
      this.showUnavailableAction(error instanceof Error ? `字符集读取失败：${error.message}` : '无法使用该字符集读取本书');
      return;
    }
    const updatedBooks = this.books.map((book: Book) => book.id === updatedBook.id ? updatedBook : book);
    const context = this.getUIContext().getHostContext();
    if (context === undefined) {
      this.showUnavailableAction('无法保存字符集设置');
      return;
    }
    try {
      await BookRepository.saveImportedBooks(context,
        updatedBooks.filter((book: Book) => BookRepository.isPersistableBook(book)));
      // 换字符集会重算章节字节偏移，章节行必须跟着覆盖。
      if (updatedChapters.length > 0) {
        await BookRepository.saveChapters(context, updatedBook.contentPath ?? '', updatedChapters);
      }
    } catch (error) {
      this.showUnavailableAction(error instanceof Error ? error.message : '字符集设置保存失败');
      return;
    }
    this.selectedBook = updatedBook;
    this.books = updatedBooks;
    this.selectedChapter = chapterTitle;
    this.readerContent = content;
  }

  private saveReaderAnchorBeforeChapterJump(targetChapterIndex: number): void {
    if (!this.readerReadingAnchorEnabled || !this.selectedBook.isLocal || this.selectedBook.contentPath === undefined) {
      return;
    }
    const chapterTitles = BookRepository.cachedChapterTitles(this.selectedBook);
    const effectiveTitles = chapterTitles.length > 0 ? chapterTitles : [this.selectedChapter];
    const currentChapterIndex = this.selectedBook.chapterIndex ?? effectiveTitles.indexOf(this.selectedChapter);
    if (targetChapterIndex === currentChapterIndex) { return; }
    if (this.readerAnchorOriginBook === undefined) {
      this.readerAnchorOriginBook = this.selectedBook;
      this.readerAnchorOriginChapter = this.selectedChapter;
      this.readerAnchorJumpCount = 0;
    }
    this.readerAnchorJumpCount = Math.min(2, this.readerAnchorJumpCount + 1);
  }

  private discardReaderAnchor(): void {
    this.readerAnchorOriginBook = undefined;
    this.readerAnchorOriginChapter = '';
    this.readerAnchorJumpCount = 0;
  }

  private async restoreReaderAnchor(): Promise<void> {
    const originBook = this.readerAnchorOriginBook;
    if (originBook === undefined) { return; }
    const chapterTitles = BookRepository.cachedChapterTitles(originBook);
    const chapterIndex = Math.max(0, originBook.chapterIndex ??
      chapterTitles.indexOf(this.readerAnchorOriginChapter));
    const chapterTitle = chapterTitles[chapterIndex] ?? this.readerAnchorOriginChapter ?? originBook.lastChapter;
    let content: string = '';
    try {
      content = await BookRepository.readChapter(originBook, chapterTitle, chapterIndex);
    } catch (error) {
      this.showUnavailableAction(error instanceof Error ? '恢复阅读位置失败：' + error.message : '无法恢复原阅读位置');
      return;
    }
    const restoredBook: Book = originBook;
    const updatedBooks = this.books.map((book: Book) =>
      book.id === restoredBook.id ? restoredBook : book);
    const context = this.getUIContext().getHostContext();
    if (context === undefined) {
      this.showUnavailableAction('无法访问本地书架，未恢复原阅读位置');
      return;
    }
    try {
      await BookRepository.saveImportedBooks(context,
        updatedBooks.filter((book: Book) => BookRepository.isPersistableBook(book)));
    } catch (_) {
      this.showUnavailableAction('原阅读位置保存失败，请重试');
      return;
    }
    this.selectedBook = restoredBook;
    this.selectedChapter = chapterTitle;
    this.readerContent = content;
    this.books = updatedBooks;
    this.discardReaderAnchor();
    this.route = AppRoute.READER;
  }
  private async selectChapter(title: string, requestedIndex?: number, initialProgress: number = 0): Promise<void> {
    const selectStartedAt = Date.now();
    const cachedTitles = BookRepository.cachedChapterTitles(this.selectedBook);
    const chapterTitles = cachedTitles.length > 0 ? cachedTitles : [title];
    const titleIndex = chapterTitles.indexOf(title);
    const chapterIndex = requestedIndex !== undefined && requestedIndex >= 0 && requestedIndex < chapterTitles.length
      ? requestedIndex : Math.max(0, titleIndex);
    const currentChapterIndex = this.selectedBook.chapterIndex ?? chapterTitles.indexOf(this.selectedChapter);
    if (title === this.selectedChapter && chapterIndex === currentChapterIndex) {
      this.route = AppRoute.READER;
      return;
    }
    this.readerStartAtChapterBeginning = false;
    this.saveReaderAnchorBeforeChapterJump(chapterIndex);
    const chapterCount = Math.max(1, chapterTitles.length);
    const updatedBook: Book = BookRepository.copyBook(this.selectedBook);
    updatedBook.chapterIndex = chapterIndex;
    updatedBook.chapterProgress = Math.max(0, Math.min(100, initialProgress));
    updatedBook.lastChapter = title;
    updatedBook.progress =
      (chapterIndex + Math.max(0, Math.min(100, initialProgress)) / 100) / chapterCount * 100;
    updatedBook.androidCharacterPosition = 0;
    let content: string = '';
    const readStartedAt = Date.now();
    try {
      content = await BookRepository.readChapter(updatedBook, title);
      this.replaceRules = ReplaceRuleRepository.getAll();
    } catch (error) {
      this.showUnavailableAction(error instanceof Error ? `读取章节失败：${error.message}` : '章节文件无法读取');
      return;
    }
    const updatedBooks = this.books.map((book: Book) => book.id === updatedBook.id ? updatedBook : book);
    if (updatedBook.contentPath !== undefined) {
      const context = this.getUIContext().getHostContext();
      if (context === undefined) {
        this.showUnavailableAction('无法访问本地书架，章节位置未保存');
        return;
      }
      try {
        await BookRepository.saveImportedBooks(context,
          updatedBooks.filter((book: Book) => BookRepository.isPersistableBook(book)));
      } catch (_) {
        this.showUnavailableAction('章节进度保存失败，已保留原阅读位置');
        return;
      }
    }
    this.selectedBook = updatedBook;
    this.selectedChapter = title;
    this.books = updatedBooks;
    this.readerContent = content;
    this.route = AppRoute.READER;
    console.info(`[ReaderBench] selectChapter readMs=${Date.now() - readStartedAt} ` +
      `totalMs=${Date.now() - selectStartedAt} title=${title}`);
  }
  /**
   * 阅读页要邻章正文时调用（页层批次 4，滚动模式邻章预排）。
   *
   * `readChapter` 不依赖 UIContext，任意上下文可调；它会走
   * `applyChapterContentAsync`（含一次 taskpool 往返替换规则），单章几十到几百毫秒。
   * 三道去重：同一章在途、已是当前章、已经下发过，直接返回，避免每次重排都读一遍盘。
   *
   * 期间用户可能已经手动换章过去：读盘回来要重新核对章号，
   * 过期结果直接丢，不写 `readerAdjacentChapterPayload`。
   */
  private async requestAdjacentChapter(chapterIndex: number): Promise<void> {
    if (chapterIndex < 0 || chapterIndex === this.selectedBook.chapterIndex) { return; }
    if (this.readerAdjacentChapterPending === chapterIndex) { return; }
    if (this.readerAdjacentChapterDelivered === chapterIndex) { return; }
    const chapters = BookRepository.cachedChapterTitles(this.selectedBook);
    const title = chapters[chapterIndex];
    if (title === undefined) { return; }
    this.readerAdjacentChapterPending = chapterIndex;
    const startedAt = Date.now();
    let content = '';
    try {
      content = await BookRepository.readChapter(this.selectedBook, title, chapterIndex);
    } catch (_) {
      // 邻章读不到不影响本章阅读，静默放弃；下次重排会再试。
      this.readerAdjacentChapterPending = -1;
      return;
    }
    this.readerAdjacentChapterPending = -1;
    // 读盘期间已经换过去了：这一章现在就是正文章，不能再当邻章下发。
    if (chapterIndex === this.selectedBook.chapterIndex) { return; }
    // 章号与正文编在一份载荷里一次赋值，阅读页不会看到「新章号 + 旧正文」的中间帧。
    this.readerAdjacentChapterPayload = `${chapterIndex}\u0000${content}`;
    this.readerAdjacentChapterDelivered = chapterIndex;
    console.info(`[ReaderBench] adjacentRead chapter=${chapterIndex} ms=${Date.now() - startedAt} ` +
      `length=${content.length}`);
  }

  private async saveReaderChapterContent(chapterIndex: number, title: string, body: string): Promise<void> {
    const context = this.getUIContext().getHostContext();
    if (context === undefined) {
      this.showUnavailableAction('无法访问本地书籍');
      return;
    }
    try {
      const replaced = await BookRepository.replaceLocalChapter(this.selectedBook, chapterIndex, title, body,
        BookRepository.cachedChapters(this.selectedBook));
      const updatedBook = replaced.book;
      const updatedBooks = this.books.map((book: Book) => book.id === updatedBook.id ? updatedBook : book);
      await BookRepository.saveImportedBooks(context,
        updatedBooks.filter((book: Book) => BookRepository.isPersistableBook(book)));
      // 改章节正文会重排后续章节的字节偏移，章节行跟着覆盖。
      await BookRepository.saveChapters(context, updatedBook.contentPath ?? '', replaced.chapters);
      const chapterTitle = BookRepository.cachedChapterTitles(updatedBook)[chapterIndex] ?? title;
      const updatedContent = await BookRepository.readChapter(updatedBook, chapterTitle, chapterIndex);
      this.replaceRules = ReplaceRuleRepository.getAll();
      this.selectedBook = updatedBook;
      this.books = updatedBooks;
      this.selectedChapter = chapterTitle;
      this.readerContent = updatedContent;
      this.showUnavailableAction('章节内容已保存');
    } catch (error) {
      this.showUnavailableAction(error instanceof Error ? `保存失败：${error.message}` : '章节内容保存失败');
    }
  }

  private getAppFilesDirectory(): string {
    const context = this.getUIContext().getHostContext();
    return context === undefined ? '' : context.filesDir;
  }
  private getAppFileManagerRootDirectory(): string {
    const filesDirectory = this.getAppFilesDirectory();
    const parentIndex = filesDirectory.lastIndexOf('/');
    return parentIndex > 0 ? filesDirectory.substring(0, parentIndex) : filesDirectory;
  }
  /** 书架管理页入口（:482）：带上当前分组名，空串表示全部。 */
  private openBookshelfManage(groupName: string): void {
    this.bookshelfManageGroupName = groupName;
    this.profileDetailReturnRoute = this.route;
    this.profileSubpage = ProfileRoute.BOOKSHELF_MANAGE;
    this.route = AppRoute.PROFILE_SUBPAGE;
  }

  /** 书架管理页批量改动后重载书架（:463 移入分组、:465/:475 删除都走这里）。 */
  private async reloadLibraryAfterBulkChange(): Promise<void> {
    const context = this.getUIContext().getHostContext();
    if (context === undefined) { this.showUnavailableAction('无法访问本地书架'); return; }
    const reloaded = await BookRepository.loadImportedBooks(context);
    this.books = reloaded.filter((book: Book) => BookRepository.isPersistableBook(book));
  }

  /** 下载与缓存设置（:484）：启动时把偏好读进内存，供 BookRepository 的正文缓存上限取值。 */
  private async restoreCacheSettings(context: Context): Promise<void> {
    await CacheSettingsRepository.load(context);
  }

  private openProfileDetail(destination: ProfileRoute): void {
    this.profileDetailReturnRoute = this.route;
    this.profileSubpage = destination;
    this.route = AppRoute.PROFILE_SUBPAGE;
  }
  private openSettingsCategory(destination: ProfileRoute): void {
    this.profileSettingsReturn = this.profileSubpage;
    this.profileSubpage = destination;
    this.route = AppRoute.PROFILE_SUBPAGE;
  }
  private exitApplication(): void {
    const context = this.getUIContext().getHostContext();
    if (context !== undefined) {
      context.eventHub.emit('exitApplication');
    }
  }
  private showUnavailableAction(message: string): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message: message });
    } catch (_) {
    }
  }
  private selectTab(index: number): void {
    this.selectedTab = index;
    if (index === 0) { this.route = AppRoute.HOME; }
    else if (index === 1) { this.route = AppRoute.BOOKSHELF; }
    else if (index === 2) { this.route = AppRoute.DISCOVER; }
    else if (index === 3) { this.route = AppRoute.SUBSCRIPTIONS; }
    else { this.route = AppRoute.PROFILE; }
  }

  private isPrimaryTabRoute(): boolean {
    return this.route === AppRoute.HOME || this.route === AppRoute.BOOKSHELF ||
      this.route === AppRoute.DISCOVER || this.route === AppRoute.SUBSCRIPTIONS ||
      this.route === AppRoute.PROFILE;
  }

  private isProfileSettingsPage(destination: ProfileRoute): boolean {
    return destination === ProfileRoute.APP_THEME_SETTINGS || destination === ProfileRoute.APP_CUSTOM_THEME ||
      destination === ProfileRoute.APP_THEME_MANAGE ||
      destination === ProfileRoute.APP_OTHER_SETTINGS ||
      destination === ProfileRoute.APP_READ_SETTINGS || destination === ProfileRoute.APP_ALOUD_SETTINGS ||
      destination === ProfileRoute.APP_COVER_SETTINGS || destination === ProfileRoute.APP_DOWNLOAD_CACHE_SETTINGS ||
      destination === ProfileRoute.APP_BACKUP_SETTINGS || destination === ProfileRoute.APP_AI_SETTINGS ||
      destination === ProfileRoute.APP_PRIVACY_SETTINGS || destination === ProfileRoute.APP_LAB_SETTINGS;
  }

  private handleSystemBack(): boolean {
    if (this.readerImagePreviewOpen) {
      this.readerImagePreviewOpen = false;
      this.readerImagePreviewCloseRevision++;
      return true;
    }
    if (this.route === AppRoute.BOOK_INFO) {
      this.route = this.bookInfoReturnRoute;
      return true;
    }
    if (this.route === AppRoute.SUBSCRIPTION_RULES || this.route === AppRoute.SUBSCRIPTION_FAVORITES ||
      this.route === AppRoute.SUBSCRIPTION_SOURCE_MANAGE) {
      this.route = AppRoute.SUBSCRIPTIONS;
      return true;
    }
    if (this.route === AppRoute.PROFILE_SUBPAGE) {
      if (this.profileSubpage === ProfileRoute.REPLACE_RULE_EDIT) {
        this.profileSubpage = ProfileRoute.REPLACE_RULES;
      } else if (this.profileSubpage === ProfileRoute.DICTIONARY_RULE_EDIT) {
        this.profileSubpage = ProfileRoute.DICTIONARY_RULES;
      } else if (this.profileSubpage === ProfileRoute.HIGHLIGHT_TAG_RULE_EDIT) {
        this.profileSubpage = ProfileRoute.HIGHLIGHT_TAG_RULES;
      } else if (this.profileSubpage === ProfileRoute.APP_SETTINGS) {
        this.route = this.profileDetailReturnRoute;
      } else if (this.profileSubpage === ProfileRoute.APP_TRANSLATION_SETTINGS) {
        this.profileSubpage = ProfileRoute.APP_SETTINGS;
      } else if (this.profileSubpage === ProfileRoute.PRIVACY_NOTICE) {
        this.profileSubpage = ProfileRoute.ABOUT;
      } else if (this.isProfileSettingsPage(this.profileSubpage)) {
        this.profileSubpage = this.profileSettingsReturn;
      } else {
        this.route = this.profileDetailReturnRoute;
      }
      return true;
    }
    if (this.route === AppRoute.CATALOG) {
      this.route = this.catalogReturnRoute;
      return true;
    }
    if (this.route === AppRoute.READ_ALOUD_SETTINGS) {
      this.returnToReaderMenu();
      return true;
    }
    if (this.route === AppRoute.READER_SEARCH) {
      this.route = AppRoute.READER;
      return true;
    }
    if (this.route === AppRoute.READER_SETTINGS) {
      this.route = this.settingsReturnRoute;
      return true;
    }
    if (this.route === AppRoute.SEARCH) {
      this.route = this.searchReturnRoute;
      return true;
    }
    if (this.route === AppRoute.READER) {
      this.route = this.readerReturnRoute;
      return true;
    }
    return false;
  }

  onBackPress(): boolean {
    return this.handleSystemBack();
  }

  private acceptReaderProgress(bookId: string, chapterIndex: number, chapterProgress: number,
    chapterPosition: number, androidCoordinate: boolean): void {
    const currentChapterIndex = this.selectedBook.chapterIndex ??
      BookRepository.cachedChapterTitles(this.selectedBook).indexOf(this.selectedChapter);
    if (this.selectedBook.id !== bookId || currentChapterIndex !== chapterIndex) { return; }
    this.updateReadingProgress(chapterProgress, chapterPosition, androidCoordinate);
  }

  build() {
    Stack() {
    // 全 App 背景图：上游 `ui/theme/AppBackground.kt:17-48` 把背景图铺在内容层之下、按日夜选路径与虚化度。
    // 本地放在根 Stack 的首个子节点，`ImageFit.Cover` 填满；`.blur()` 接受动态半径。
    if (this.appBackgroundSource().length > 0) {
      Image(`file://${this.appBackgroundSource()}`)
        .width('100%').height('100%')
        .objectFit(ImageFit.Cover)
        .blur(this.appBackgroundBlur())
        .hitTestBehavior(HitTestMode.None)
    }
    Column() {
      if (!this.onboardingLoaded) {
        Column() {
          LoadingProgress().width(28).height(28).color(this.themeColorAccent)
        }.width('100%').height('100%').justifyContent(FlexAlign.Center)
      } else if (!this.onboardingComplete) {
        OnboardingPage({
          localBooksPath: `${this.getAppFilesDirectory()}/books`,
          readerNightMode: this.readerNightMode,
          onThemeModeChange: (themeMode: number) => this.selectOnboardingThemeMode(themeMode),
          onPaletteChange: (paletteIndex: number) => this.selectThemePalette(paletteIndex),
          onComplete: (themeMode: number, paletteIndex: number) => this.finishOnboarding(themeMode, paletteIndex)
        })
      } else {
      Stack() {
        if (this.isPrimaryTabRoute()) {
        Swiper() {
        HomePage({
          books: this.books,
          totalReadTimeMs: this.getTotalReadTimeMs(),
          visibleSections: this.homeDashboardSections,
          onSectionVisibilityChange: (section: HomeDashboardSection, visible: boolean) => this.setHomeDashboardSection(section, visible),
          onOpenBook: (book: Book) => this.openBook(book),
          onOpenBookInfo: (book: Book) => this.openBookInfo(book),
          onOpenBookshelf: () => this.selectTab(1),
          onOpenReadRecords: () => this.openProfileDetail(ProfileRoute.READ_RECORDS),
          onOpenBackup: () => this.openProfileDetail(ProfileRoute.APP_BACKUP_SETTINGS),
          onUnavailableAction: (message: string) => this.showUnavailableAction(message)
        })
        BookshelfPage({
          books: this.books,
          groups: this.bookGroups,
          layout: this.bookshelfLayout,
          coverSettings: this.coverSettings,
          readerNightMode: this.readerNightMode,
          refreshingBookIds: this.refreshingBookIds,
          onSaveLayout: (settings: BookshelfLayoutSettings) => this.saveBookshelfLayout(settings),
          onAddGroup: (name: string) => this.addBookshelfGroup(name),
          onRenameGroup: (id: number, name: string) => this.renameBookshelfGroup(id, name),
          onSetGroupVisible: (id: number, visible: boolean) => this.setBookshelfGroupVisible(id, visible),
          onRemoveGroup: (id: number) => this.removeBookshelfGroup(id),
          onAddGroupDraft: (draft: BookGroupDraft) => this.addBookshelfGroupDraft(draft),
          onUpdateGroup: (id: number, draft: BookGroupDraft) => this.updateBookshelfGroup(id, draft),
          onChooseGroupCover: (id: number) => this.chooseBookshelfGroupCover(id),
          onClearGroupCover: (id: number) => this.clearBookshelfGroupCover(id),
          onMoveGroup: (fromId: number, toId: number) => this.moveBookshelfGroup(fromId, toId),
          onOpenBook: (book: Book) => this.openBook(book),
          onOpenBookInfo: (book: Book) => this.openBookInfo(book),
          onSearch: () => this.openSearch(),
          onImportBook: () => this.importLocalBook(),
          onImportBookList: (books: Book[]) => this.importBookList(books),
          onRefreshToc: () => this.refreshAllToc(),
          onApplyTagGroupRules: () => this.applyTagGroupRules(),
          onSetBooksGroup: (bookKeys: string[], groupName: string) => this.setBooksGroupByKeys(bookKeys, groupName),
          onDeleteBooks: (books: Book[], deleteSource: boolean) => this.deleteBooksFromShelf(books, deleteSource),
          onMoveBooks: (ordered: Book[]) => this.moveBooksInShelf(ordered),
          onSetBooksPrivate: (bookKeys: string[], isPrivate: boolean) => this.setBooksPrivateByKeys(bookKeys, isPrivate),
          onOpenBookshelfManage: (groupName: string) => this.openBookshelfManage(groupName),
          onUnavailableAction: (message: string) => this.showUnavailableAction(message)
        })
        DiscoverPage({ onUnavailableAction: (message: string) => this.showUnavailableAction(message) })
        SubscriptionPage({
          onUnavailableAction: (message: string) => this.showUnavailableAction(message),
          onOpenRules: () => this.route = AppRoute.SUBSCRIPTION_RULES,
          onOpenFavorites: () => this.route = AppRoute.SUBSCRIPTION_FAVORITES,
          onOpenSourceManage: () => this.route = AppRoute.SUBSCRIPTION_SOURCE_MANAGE
        })
        ProfilePage({
          onOpenDetail: (destination: ProfileRoute) => this.openProfileDetail(destination),
          onExit: () => this.exitApplication(),
          onUnavailableAction: (message: string) => this.showUnavailableAction(message)
        })
        }.width('100%').height('100%').index(this.selectedTab).loop(false).indicator(false)
          .onChange((index: number) => this.selectTab(index))
        } else if (this.route === AppRoute.BOOK_INFO) {
        BookInfoPage({
          book: this.selectedBook,
          groups: this.bookGroups,
          books: this.books,
          highlightTagRules: this.highlightTagRules,
          deleteAlertEnabled: this.bookInfoDeleteAlert,
          followCoverColor: this.bookInfoFollowCoverColor,
          networkCoverBackground: this.bookInfoNetworkCoverBackground,
          defaultCoverBackground: this.bookInfoDefaultCoverBackground,
          coverSettings: this.coverSettings,
          onBack: () => this.route = this.bookInfoReturnRoute,
          onRead: () => this.openBook(this.selectedBook),
          onOpenCatalog: () => this.openCatalogFromBookInfo(),
          onOpenReadRecords: () => this.openProfileDetail(ProfileRoute.READ_RECORDS),
          onLoadBookReadRecord: (book: Book) => this.loadBookReadRecordPanel(book),
          onToggleDisableReadRecord: (book: Book, disabled: boolean) => this.toggleBookDisableReadRecord(book, disabled),
          onRemoveFromShelf: (deleteSource: boolean) => this.removeLocalBookFromShelf(this.selectedBook, deleteSource),
          onTopBook: () => this.topSelectedBook(this.selectedBook),
          onRefreshBookInfo: (book: Book) => this.refreshBookInfo(book),
          onToggleDeleteAlert: () => this.toggleBookInfoDeleteAlert(),
          onSearchKeyword: (keyword: string) => this.openSearchWithKeyword(keyword),
          onSetPrivate: (book: Book, isPrivate: boolean) => this.setBookPrivate(book, isPrivate),
          onChooseCover: () => this.chooseBookCover(),
          onRestoreCover: () => this.restoreBookCover(),
          onSaveMetadata: (title: string, author: string, category: string, description: string,
            remark: string, customTag: string, groupNames: string[], bookType: BookMediaType, fixedType: boolean) =>
            this.saveBookMetadata(title, author, category, description, remark, customTag, groupNames, bookType, fixedType),
          onUnavailableAction: (message: string) => this.showUnavailableAction(message)
        })
        } else if (this.route === AppRoute.SUBSCRIPTION_RULES) {
        SubscriptionRulesPage({
          onBack: () => this.route = AppRoute.SUBSCRIPTIONS,
          onUnavailableAction: (message: string) => this.showUnavailableAction(message)
        })
        } else if (this.route === AppRoute.SUBSCRIPTION_FAVORITES) {
        SubscriptionFavoritesPage({
          onBack: () => this.route = AppRoute.SUBSCRIPTIONS,
          onUnavailableAction: (message: string) => this.showUnavailableAction(message)
        })
        } else if (this.route === AppRoute.SUBSCRIPTION_SOURCE_MANAGE) {
        SubscriptionSourceManagePage({
          onBack: () => this.route = AppRoute.SUBSCRIPTIONS,
          onUnavailableAction: (message: string) => this.showUnavailableAction(message)
        })
        } else if (this.route === AppRoute.READER || this.route === AppRoute.CATALOG ||
        (this.route === AppRoute.READER_SETTINGS && this.settingsReturnRoute === AppRoute.READER) ||
        this.route === AppRoute.READ_ALOUD_SETTINGS) {
        Stack() {
          // 阅读设置是异步载入的（restoreReaderSettings 不能 await，aboutToAppear 是同步生命周期），
          // 设置没到位就开门会让阅读页先用默认值排一遍版，数值到达后再整页跳一次。
          // 上游 ReadBookActivity 也是把配置装好再起 UI，这里同样先给占位。
          if (this.readerSettingsLoaded || this.route !== AppRoute.READER) {
          ReaderPage({
            startAtChapterBeginning: this.readerStartAtChapterBeginning,
            book: this.selectedBook,
            bookmarks: this.readerBookmarks,
            markings: this.readerMarkings.filter((marking: ReaderMarking) =>
              marking.bookId === this.selectedBook.id && marking.chapterIndex ===
                Math.max(0, this.selectedBook.chapterIndex ??
                  BookRepository.cachedChapterTitles(this.selectedBook).indexOf(this.selectedChapter))),
            chapterTitle: this.selectedChapter,
            replaceRules: this.replaceRules,
            content: this.readerContent,
            fontSize: this.readerFontSize,
        paragraphSpacing: this.readerParagraphSpacing,
        lineSpacing: this.readerLineSpacing,
        letterSpacing: this.readerLetterSpacing,
        paragraphIndent: this.readerParagraphIndent,
            textFontPath: this.readerTextFont,
            titleFontPath: this.readerTitleFont,
            systemTypefaces: this.readerSystemTypefaces,
              textItalic: this.readerTextItalic,
              textBold: this.readerTextBold,
              textShadow: this.readerTextShadow,
              shadowRadius: this.readerShadowRadius,
              shadowDx: this.readerShadowDx,
              shadowDy: this.readerShadowDy,
              underline: this.readerUnderline,
              dottedLine: this.readerDottedLine,
              textShadowColor: this.readerTextShadowColor,
              textShadowColorN: this.readerTextShadowColorN,
              underlineColor: this.readerUnderlineColor,
              underlineColorNight: this.readerUnderlineColorNight,
              underlineHeight: this.readerUnderlineHeight,
              underlinePadding: this.readerUnderlinePadding,
              underlineExtend: this.readerUnderlineExtend,
              dottedBase: this.readerDottedBase,
              dottedRatio: this.readerDottedRatio,
        textFullJustify: this.readerTextFullJustify,
        textBottomJustify: this.readerTextBottomJustify,
            imageStyle: this.selectedBook.imageStyle ?? 'DEFAULT',
            paperColor: this.getPaperColor(),
            readingTextColor: this.getReadingTextColorSetting(),
            textAccentColor: this.getTextAccentColorSetting(),
            readerBackgroundImage: this.getReaderBackgroundImage(),
            backgroundAlpha: this.readerBgAlpha,
            // 标题排版十四个字段（上游 ReadBookConfig.kt:596-608）。
            titleMode: this.readerTitleMode,
            titleSize: this.readerTitleSize,
            titleSizeRelative: this.readerTitleSizeRelative,
            titleTopSpacing: this.readerTitleTopSpacing,
            titleBottomSpacing: this.readerTitleBottomSpacing,
            titleColor: this.readerTitleColor,
            titleColorNight: this.readerTitleColorNight,
            titleBold: this.readerTitleBold,
            titleLineSpacingExtra: this.readerTitleLineSpacingExtra,
            titleLineSpacingSub: this.readerTitleLineSpacingSub,
            titleSegType: this.readerTitleSegType,
            titleSegScaling: this.readerTitleSegScaling,
            titleSegDistance: this.readerTitleSegDistance,
            titleSegFlag: this.readerTitleSegFlag,
            darkStatusIcon: this.getDarkStatusIconSetting(),
            readerNightMode: this.readerNightMode,
            eyeProtectionActive: this.isEyeProtectionActive(),
            showQuickActions: this.showReaderQuickActions,
            showControlsOnAppear: this.readerControlsOpenOnReturn,
            onControlsShown: (): void => { this.readerControlsOpenOnReturn = false; },
            showBottomActionText: this.showReaderBottomActionText,
            bottomIconStyle: this.readerBottomIconStyle,
            bottomItemsPerRow: this.readerBottomItemsPerRow,
            bottomRowCount: this.readerBottomRowCount,
            bottomActions: this.readerBottomActions,
            topActions: this.readerTopActions,
            moreActions: this.readerMoreActions,
            progressBehavior: this.readerProgressBehavior,
            readSliderMode: this.readerReadSliderMode,
            pageTouchSlop: this.readerPageTouchSlop,
            paddingSettings: this.readerPaddingSettings,
            screenOrientation: this.readerScreenOrientation,
            keepLight: this.readerKeepLight,
            volumeKeyPage: this.readerVolumeKeyPage,
            keyPageOnLongPress: this.readerKeyPageOnLongPress,
            noAnimScrollPage: this.readerNoAnimScrollPage,
            prevKeys: this.readerPrevKeys,
            nextKeys: this.readerNextKeys,
            mouseWheelPage: this.readerMouseWheelPage,
            expandTextMenu: this.readerExpandTextMenu,
            showSelectMenuIcon: this.readerShowSelectMenuIcon,
            textSelectMenuConfig: this.readerTextSelectMenuConfig,
            doubleHorizontalPage: this.readerDoubleHorizontalPage,
            dayNightReminderText: this.readerDayNightReminderText,
            onAcceptDayNightReminder: () => this.acceptReaderDayNightReminder(),
            onDismissDayNightReminder: () => this.dismissReaderDayNightReminder(),
            readBrightness: this.readerReadBrightness,
            onReadBrightnessChange: (value: number) => this.setReaderReadBrightness(value),
            showBrightnessView: this.readerShowBrightnessView,
            brightnessVwPos: this.readerBrightnessVwPos,
            brightnessAuto: this.readerBrightnessAuto,
            readBodyToLh: this.readerReadBodyToLh,
            useZhLayout: this.readerUseZhLayout,
            paddingDisplayCutouts: this.readerPaddingDisplayCutouts,
            readMenuBottomCornerRadius: this.readerReadMenuBottomCornerRadius,
            readMenuFloatingBottomBar: this.readerReadMenuFloatingBottomBar,
            readMenuBottomBarBlurMode: this.readerReadMenuBottomBarBlurMode,
            readMenuBottomBarBlurStyle: this.readerReadMenuBottomBarBlurStyle,
            readMenuBottomBarLiquidGlassButtons: this.readerReadMenuBottomBarLiquidGlassButtons,
            readMenuBlurAlpha: this.readerReadMenuBlurAlpha,
            readMenuTopBarTitleCapsule: this.readerReadMenuTopBarTitleCapsule,
            titleBarMode: this.readerTitleBarMode,
            titleBarCompact: this.readerTitleBarCompact,
            titleBarIconStyle: this.readerTitleBarIconStyle,
            readMenuTopBarBlurMode: this.readerReadMenuTopBarBlurMode,
            readMenuTopBarBlurStyle: this.readerReadMenuTopBarBlurStyle,
            readMenuTopBarLiquidGlassButtons: this.readerReadMenuTopBarLiquidGlassButtons,
            readMenuTopBarMergeButtons: this.readerReadMenuTopBarMergeButtons,
            readBarStyle: this.readerReadBarStyle,
            readMenuPaletteStyle: this.readerMenuPaletteStyle,
            readMenuColorMode: this.readerMenuColorMode,
            readMenuBgColor: this.readerMenuBgColor,
            readMenuBgColorNight: this.readerMenuBgColorNight,
            readMenuContainerColor: this.readerMenuContainerColor,
            readMenuContainerColorNight: this.readerMenuContainerColorNight,
            readMenuAccentColor: this.readerMenuAccentColor,
            readMenuAccentColorNight: this.readerMenuAccentColorNight,
            readMenuBorderWidth: this.readerMenuBorderWidth,
            readMenuBorderColor: this.readerMenuBorderColor,
            readMenuBorderColorNight: this.readerMenuBorderColorNight,
            readMenuBlurRadius: this.readerMenuBlurRadius,
            readMenuTextColor: this.readerMenuTextColor,
            readMenuTextColorNight: this.readerMenuTextColorNight,
            readMenuBlurColor: this.readerMenuBlurColor,
            readMenuBlurColorNight: this.readerMenuBlurColorNight,
            showTitleBarIcons: this.readerShowTitleBarIcons,
            titleBarIconPosition: this.readerTitleBarIconPosition,
            readMenuFloatingIconLiquidGlass: this.readerReadMenuFloatingIconLiquidGlass,
            floatingIcons: this.readerFloatingIcons,
            titleBarCustomIcons: this.readerTitleBarCustomIcons,
            readMenuCustomIcons: this.readerReadMenuCustomIcons,
            showMenuIcon: this.readerShowMenuIcon,
            showReadTitleAddition: this.readerShowReadTitleAddition,
            menuAlpha: this.readerMenuAlpha,
            readingAnchorAvailable: this.readerReadingAnchorEnabled && this.readerAnchorJumpCount >= 2,
            readingAnchorEnabled: this.readerReadingAnchorEnabled,
        swipeToAddBookmark: this.readerSwipeToAddBookmark,
        bookmarkBadgeSize: this.readerBookmarkBadgeSize,
        bookmarkBadgeImage: this.readerBookmarkBadgeImage,
        selectText: this.readerSelectText,
        selectVibrator: this.readerSelectVibrator,
            clickImageBehavior: this.readerClickImageBehavior,
            clickRegionActions: this.readerClickRegionActions,
            hideStatusBar: this.readerHideStatusBar,
            hideNavigationBar: this.readerHideNavigationBar,
            imagePreviewCloseRevision: this.readerImagePreviewCloseRevision,
            onOpenImagePreview: (_uri: string): void => { this.readerImagePreviewOpen = true; },
            onCloseImagePreview: (): void => this.closeReaderImagePreview(),
            pageAnimation: this.readerPageAnimation,
            animationSpeed: this.readerAnimationSpeed,
            infoSettings: this.readerInfoSettings,
            autoReadSpeedSeconds: this.autoReadSpeed,
            onAutoReadSpeedChange: (seconds: number) => this.setAutoReadSpeed(seconds),
            onReadSessionStart: () => this.startReaderSession(),
            onReadSessionPulse: () => this.pulseReaderSession(),
            onReadSessionStop: () => this.stopReaderSession(),
            onStartAtChapterBeginningResolved: () => this.readerStartAtChapterBeginning = false,
            onBack: () => this.route = this.readerReturnRoute,
            onRestoreReadingAnchor: () => this.restoreReaderAnchor(),
            onKeepReadingAnchor: () => this.discardReaderAnchor(),
            onOpenCatalog: () => {
              this.catalogReturnRoute = AppRoute.READER;
              this.route = AppRoute.CATALOG;
            },
            onOpenBookInfo: () => this.openBookInfo(this.selectedBook),
            onBrightnessAutoChange: (auto: boolean) => this.setReaderBrightnessAuto(auto),
            onBrightnessVwPosChange: (position: string) => this.setReaderBrightnessVwPos(position),
            onImageStyleChange: (imageStyle: string) => this.setReaderImageStyle(imageStyle),
            onPageAnimationChange: (animation: number) => this.setReaderPageAnimation(animation),
            onOpenSettings: () => this.openReaderSettings(),
            onOpenBottomActionConfig: () => this.openReaderSettings(true),
            onCharsetChange: (charset: string) => this.setReaderCharset(charset),
            onOpenSearchContent: () => this.openReaderSearch(),
            searchNavItems: this.readerSearchNavItems,
            searchNavIndex: this.readerSearchNavIndex,
            onOpenSearchNavItem: (index: number) => this.openReaderSearchNavItem(index),
            onCloseSearchResult: () => this.closeReaderSearchNav(),
            onOpenReadAloud: () => this.openReadAloudSettings(),
            onOpenTocRule: () => this.openProfileDetail(ProfileRoute.TXT_TOC_RULE_PREVIEW),
            onToggleNightMode: () => this.toggleReaderNightMode(),
            onToggleEyeProtection: () => this.toggleEyeProtection(),
            onMoreActionsChange: (actions: ReaderMoreActionConfig[]) => this.setReaderMoreActions(actions),
            onUnavailableAction: (message: string) => this.showUnavailableAction(message),
            onProgressChange: (bookId: string, chapterIndex: number, progress: number,
              position: number, androidCoordinate: boolean) =>
              this.acceptReaderProgress(bookId, chapterIndex, progress, position, androidCoordinate),
            onAddBookmark: (position: number, pageText: string) => this.requestAddReaderBookmark(position, pageText),
            onOpenMarking: (markingId: string) => { this.editReaderMarking(markingId); },
            onCreateMarking: (position: number, endPosition: number, text: string) =>
              this.requestCreateReaderMarking(position, endPosition, text),
            onToggleCurrentPageBookmark: (start: number, end: number, pageText: string) =>
              this.toggleReaderBookmarkForPage(start, end, pageText),

            onSaveChapterContent: (chapterIndex: number, title: string, body: string) => {
              this.saveReaderChapterContent(chapterIndex, title, body);
            },
            onToggleReSegment: (enabled: boolean) => this.setReaderReSegment(enabled),
            onOpenReplaceRules: () => this.openProfileDetail(ProfileRoute.REPLACE_RULES),
            onReplaceRulesRefresh: () => this.replaceRules = ReplaceRuleRepository.getAll(),
            replaceEnabled: this.readerReplaceEnabled,
            replaceUsesDefault: this.readerReplaceUsesDefault,
            onReplaceEnabledChange: (enabled: boolean) => this.setReaderReplaceEnabled(enabled),
            onReplaceResetToDefault: () => this.resetReaderReplaceToDefault(),
            onRuleEnabledChange: (id: number, enabled: boolean) => this.setReplaceRuleEnabled(id, enabled),
            onRuleReorder: (orderedIds: number[]) => this.reorderReplaceRules(orderedIds),
            onContentProcessToggle: (id: string, enabled: boolean) => this.setReaderContentProcessEnabled(id, enabled),
            onContentProcessDelete: (id: string) => this.deleteReaderContentProcess(id),
            bookmarkTargetPosition: this.readerBookmarkTargetPosition,
            bookmarkTargetRevision: this.readerBookmarkTargetRevision,
            onBookmarkTargetConsumed: () => this.readerBookmarkTargetPosition = -1,
            onSelectChapterIndex: (chapterIndex: number) => {
              const chapters = BookRepository.cachedChapterTitles(this.selectedBook);
              const title = chapters[chapterIndex];
              if (title !== undefined) {
                this.selectChapter(title, chapterIndex);
              } else {
                const currentIndex = this.selectedBook.chapterIndex ?? chapters.indexOf(this.selectedChapter);
                this.showUnavailableAction(chapterIndex < currentIndex ? '没有上一页' : '没有下一页');
              }
            },
            onTurnChapterBoundary: (delta: number) => {
              const chapters = BookRepository.cachedChapterTitles(this.selectedBook);
              const currentIndex = this.selectedBook.chapterIndex ?? chapters.indexOf(this.selectedChapter);
              const targetIndex = currentIndex + delta;
              const targetTitle = chapters[targetIndex];
              if (targetTitle !== undefined) {
                this.selectChapter(targetTitle, targetIndex, delta < 0 ? 100 : 0);
              } else {
                this.showUnavailableAction(delta < 0 ? '没有上一页' : '没有下一页');
              }
            },
            // 页层批次 4：滚动模式邻章预排。阅读页在章末之前先要一章，
            // 宿主读完经 adjacentChapterPayload（章号 \u0000 正文）一次送回。
            adjacentChapterPayload: this.readerAdjacentChapterPayload,
            onRequestAdjacentChapter: (chapterIndex: number) => {
              this.requestAdjacentChapter(chapterIndex);
            }
          })
          } else {
            // 设置还没载入完：给一张与阅读页同色的空白占位，不闪别的排版。
            Column()
              .width('100%')
              .height('100%')
              .backgroundColor(this.getPaperColor())
              .justifyContent(FlexAlign.Center)
              .alignItems(HorizontalAlign.Center)
            LoadingProgress()
              .width(28)
              .height(28)
              .color(this.themeColorAccent)
          }
          if (this.route === AppRoute.CATALOG) {
            CatalogPage({
              book: this.selectedBook,
              selectedChapter: this.selectedChapter,
              bookmarks: this.readerBookmarks.filter((bookmark: ReaderBookmark) => bookmark.bookId === this.selectedBook.id),
              markings: this.readerMarkings.filter((marking: ReaderMarking) => marking.bookId === this.selectedBook.id),
              useTitleReplacement: this.readerTocUseReplace,
              showWordCount: this.readerTocShowWordCount,
              onBack: () => this.route = this.catalogReturnRoute,
              onOpenBookmark: (bookmarkId: string) => this.openReaderBookmark(bookmarkId),
              onEditBookmark: (bookmarkId: string) => this.editReaderBookmark(bookmarkId),
              onOpenMarking: (markingId: string) => this.openReaderMarking(markingId),
              onEditMarking: (markingId: string) => this.editReaderMarking(markingId),
              onTitleReplacementChange: (enabled: boolean) => this.setReaderTocUseReplace(enabled),
              onShowWordCountChange: (enabled: boolean) => this.setReaderTocShowWordCount(enabled),
              onExportBookmarks: (isMarkdown: boolean) => this.exportReaderBookmarks(isMarkdown),
              onRefreshToc: (): void => { this.refreshCurrentToc(); },
              onOpenReplaceRules: (): void => this.openProfileDetail(ProfileRoute.REPLACE_RULES),
              onOpenTxtTocRules: (): void => this.openProfileDetail(ProfileRoute.TXT_TOC_RULE_PREVIEW),
              onUnavailableAction: (message: string) => this.showUnavailableAction(message),
              onAddBookmarksForChapters: (indexes: number[]) => this.addReaderBookmarksForChapters(indexes),
              onSelectChapter: (chapterIndex: number) => {
              const chapterTitle = BookRepository.cachedChapterTitles(this.selectedBook)[chapterIndex];
              if (chapterTitle !== undefined) {
                this.selectChapter(chapterTitle, chapterIndex);
              }
            }
            })
          }
          if (this.markingEditor !== undefined) {
            ReaderMarkingEditor({
              marking: this.markingEditor,
              isNew: this.markingEditorIsNew,
              lastMarkingStyle: this.readerLastMarkingStyle,
              onSave: (effect: ReaderMarkingEffect, color: string, note: string) =>
                this.saveReaderMarking(effect, color, note),
              onDelete: () => this.deleteReaderMarking(),
              onClose: () => this.markingEditor = undefined
            })
          }
          if (this.route === AppRoute.READER_SETTINGS) {
            ReaderSettingsPage({
              fontSize: this.readerFontSize,
        paragraphSpacing: this.readerParagraphSpacing,
        lineSpacing: this.readerLineSpacing,
        letterSpacing: this.readerLetterSpacing,
        paragraphIndent: this.readerParagraphIndent,
              textFont: this.readerTextFont,
              titleFont: this.readerTitleFont,
              systemTypefaces: this.readerSystemTypefaces,
              textItalic: this.readerTextItalic,
              textBold: this.readerTextBold,
              textShadow: this.readerTextShadow,
              shadowRadius: this.readerShadowRadius,
              shadowDx: this.readerShadowDx,
              shadowDy: this.readerShadowDy,
              underline: this.readerUnderline,
              dottedLine: this.readerDottedLine,
              textShadowColor: this.readerTextShadowColor,
              textShadowColorN: this.readerTextShadowColorN,
              underlineColor: this.readerUnderlineColor,
              underlineColorNight: this.readerUnderlineColorNight,
              underlineHeight: this.readerUnderlineHeight,
              underlinePadding: this.readerUnderlinePadding,
              underlineExtend: this.readerUnderlineExtend,
              dottedBase: this.readerDottedBase,
              dottedRatio: this.readerDottedRatio,
        textFullJustify: this.readerTextFullJustify,
        textBottomJustify: this.readerTextBottomJustify,
              paperIndex: this.paperIndex,
              backgroundStyles: this.backgroundStyles,
              shareLayout: this.shareReaderStyleLayout,
              readerNightMode: this.readerNightMode,
              eyeProtectionActive: this.isEyeProtectionActive(),
              eyeProtectionEnabled: this.eyeProtectionEnabled,
              eyeProtectionAutoNight: this.eyeProtectionAutoNight,
              eyeProtectionSchedule: this.eyeProtectionSchedule,
              eyeProtectionIntensity: this.eyeProtectionIntensity,
              eyeProtectionStartTime: this.eyeProtectionStartTime,
              eyeProtectionEndTime: this.eyeProtectionEndTime,
              showBottomActionText: this.showReaderBottomActionText,
              bottomIconStyle: this.readerBottomIconStyle,
              bottomItemsPerRow: this.readerBottomItemsPerRow,
              bottomRowCount: this.readerBottomRowCount,
              bottomActions: this.readerBottomActions,
              topActions: this.readerTopActions,
              progressBehavior: this.readerProgressBehavior,
              paddingSettings: this.readerPaddingSettings,
              onPaddingSettingsChange: (settings: ReaderPaddingSettings) => this.setReaderPaddingSettings(settings),
              screenOrientation: this.readerScreenOrientation,
              onScreenOrientationChange: (orientation: string) => this.setReaderScreenOrientation(orientation),
              keepLight: this.readerKeepLight,
              onKeepLightChange: (value: string) => this.setReaderKeepLight(value),
              volumeKeyPage: this.readerVolumeKeyPage,
              onVolumeKeyPageChange: (enabled: boolean) => this.setReaderVolumeKeyPage(enabled),
              keyPageOnLongPress: this.readerKeyPageOnLongPress,
              onKeyPageOnLongPressChange: (enabled: boolean) => this.setReaderKeyPageOnLongPress(enabled),
              noAnimScrollPage: this.readerNoAnimScrollPage,
              prevKeys: this.readerPrevKeys,
              nextKeys: this.readerNextKeys,
              mouseWheelPage: this.readerMouseWheelPage,
              expandTextMenu: this.readerExpandTextMenu,
              showSelectMenuIcon: this.readerShowSelectMenuIcon,
              textSelectMenuConfig: this.readerTextSelectMenuConfig,
              doubleHorizontalPage: this.readerDoubleHorizontalPage,
              autoSuggestDayNight: this.readerAutoSuggestDayNight,
              disableReturnKey: this.readerDisableReturnKey,
              readingAnchorEnabled: this.readerReadingAnchorEnabled,
        swipeToAddBookmark: this.readerSwipeToAddBookmark,
        bookmarkBadgeSize: this.readerBookmarkBadgeSize,
        bookmarkBadgeImage: this.readerBookmarkBadgeImage,
        selectText: this.readerSelectText,
        sliderVibrator: this.readerSliderVibrator,
        selectVibrator: this.readerSelectVibrator,
        chineseConverterType: this.readerChineseConverterType,
        maxLengthWithNoToc: this.readerMaxLengthWithNoToc,
              onNoAnimScrollPageChange: (enabled: boolean) => this.setReaderNoAnimScrollPage(enabled),
              onPrevKeysChange: (value: string) => this.setReaderPrevKeys(value),
              onNextKeysChange: (value: string) => this.setReaderNextKeys(value),
              onMouseWheelPageChange: (enabled: boolean) => this.setReaderMouseWheelPage(enabled),
              onExpandTextMenuChange: (enabled: boolean) => this.setReaderExpandTextMenu(enabled),
              onShowSelectMenuIconChange: (enabled: boolean) => this.setReaderShowSelectMenuIcon(enabled),
              onDoubleHorizontalPageChange: (value: string) => this.setReaderDoubleHorizontalPage(value),
              onAutoSuggestDayNightChange: (enabled: boolean) => this.setReaderAutoSuggestDayNight(enabled),
              onDisableReturnKeyChange: (enabled: boolean) => this.setReaderDisableReturnKey(enabled),
              readBrightness: this.readerReadBrightness,
              onReadBrightnessChange: (value: number) => this.setReaderReadBrightness(value),
              showBrightnessView: this.readerShowBrightnessView,
              onShowBrightnessViewChange: (value: string) => this.setReaderShowBrightnessView(value),
              brightnessVwPos: this.readerBrightnessVwPos,
              onBrightnessVwPosChange: (value: string) => this.setReaderBrightnessVwPos(value),
              brightnessAuto: this.readerBrightnessAuto,
              readBodyToLh: this.readerReadBodyToLh,
              useZhLayout: this.readerUseZhLayout,
              paddingDisplayCutouts: this.readerPaddingDisplayCutouts,
              readMenuBottomCornerRadius: this.readerReadMenuBottomCornerRadius,
              readMenuFloatingBottomBar: this.readerReadMenuFloatingBottomBar,
              readMenuBottomBarBlurMode: this.readerReadMenuBottomBarBlurMode,
              readMenuBottomBarBlurStyle: this.readerReadMenuBottomBarBlurStyle,
              readMenuBottomBarLiquidGlassButtons: this.readerReadMenuBottomBarLiquidGlassButtons,
              readMenuBlurAlpha: this.readerReadMenuBlurAlpha,
              readMenuTopBarTitleCapsule: this.readerReadMenuTopBarTitleCapsule,
              titleBarMode: this.readerTitleBarMode,
              titleBarCompact: this.readerTitleBarCompact,
              titleBarIconStyle: this.readerTitleBarIconStyle,
              readMenuTopBarBlurMode: this.readerReadMenuTopBarBlurMode,
              readMenuTopBarBlurStyle: this.readerReadMenuTopBarBlurStyle,
              readMenuTopBarLiquidGlassButtons: this.readerReadMenuTopBarLiquidGlassButtons,
              readMenuTopBarMergeButtons: this.readerReadMenuTopBarMergeButtons,
              readBarStyle: this.readerReadBarStyle,
              readMenuPaletteStyle: this.readerMenuPaletteStyle,
              readMenuColorMode: this.readerMenuColorMode,
              readMenuBgColor: this.readerMenuBgColor,
              readMenuBgColorNight: this.readerMenuBgColorNight,
              readMenuContainerColor: this.readerMenuContainerColor,
              readMenuContainerColorNight: this.readerMenuContainerColorNight,
              readMenuAccentColor: this.readerMenuAccentColor,
              readMenuAccentColorNight: this.readerMenuAccentColorNight,
              readMenuBorderWidth: this.readerMenuBorderWidth,
              readMenuBorderColor: this.readerMenuBorderColor,
              readMenuBorderColorNight: this.readerMenuBorderColorNight,
              readMenuBlurRadius: this.readerMenuBlurRadius,
              readMenuTextColor: this.readerMenuTextColor,
              readMenuTextColorNight: this.readerMenuTextColorNight,
              readMenuBlurColor: this.readerMenuBlurColor,
              readMenuBlurColorNight: this.readerMenuBlurColorNight,
              showTitleBarIcons: this.readerShowTitleBarIcons,
              titleBarIconPosition: this.readerTitleBarIconPosition,
              readMenuFloatingIconLiquidGlass: this.readerReadMenuFloatingIconLiquidGlass,
              floatingIcons: this.readerFloatingIcons,
              titleBarCustomIcons: this.readerTitleBarCustomIcons,
              readMenuCustomIcons: this.readerReadMenuCustomIcons,
              showMenuIcon: this.readerShowMenuIcon,
              showReadTitleAddition: this.readerShowReadTitleAddition,
              menuAlpha: this.readerMenuAlpha,
              adaptSpecialStyle: this.readerAdaptSpecialStyle,
              onBrightnessAutoChange: (enabled: boolean) => this.setReaderBrightnessAuto(enabled),
              onReadBodyToLhChange: (enabled: boolean) => this.setReaderReadBodyToLh(enabled),
              onUseZhLayoutChange: (enabled: boolean) => this.setReaderUseZhLayout(enabled),
              onPaddingDisplayCutoutsChange: (enabled: boolean) => this.setReaderPaddingDisplayCutouts(enabled),
              onAdaptSpecialStyleChange: (enabled: boolean) => this.setReaderAdaptSpecialStyle(enabled),
              onReadMenuBottomCornerRadiusChange: (value: number) => this.setReaderReadMenuBottomCornerRadius(value),
              onReadMenuFloatingBottomBarChange: (enabled: boolean) => this.setReaderReadMenuFloatingBottomBar(enabled),
              onReadMenuBottomBarBlurModeChange: (value: number) => this.setReaderReadMenuBottomBarBlurMode(value),
              onReadMenuBottomBarBlurStyleChange: (value: number) => this.setReaderReadMenuBottomBarBlurStyle(value),
              onReadMenuBottomBarLiquidGlassButtonsChange: (enabled: boolean) => this.setReaderReadMenuBottomBarLiquidGlassButtons(enabled),
              onReadMenuBlurAlphaChange: (value: number) => this.setReaderReadMenuBlurAlpha(value),
              onReadMenuTopBarTitleCapsuleChange: (enabled: boolean) => this.setReaderReadMenuTopBarTitleCapsule(enabled),
              onTitleBarModeChange: (value: string) => this.setReaderTitleBarMode(value),
              onTitleBarCompactChange: (enabled: boolean) => this.setReaderTitleBarCompact(enabled),
              onTitleBarIconStyleChange: (value: number) => this.setReaderTitleBarIconStyle(value),
              onReadMenuTopBarBlurModeChange: (value: number) => this.setReaderReadMenuTopBarBlurMode(value),
              onReadMenuTopBarBlurStyleChange: (value: number) => this.setReaderReadMenuTopBarBlurStyle(value),
              onReadMenuTopBarLiquidGlassButtonsChange: (enabled: boolean) => this.setReaderReadMenuTopBarLiquidGlassButtons(enabled),
              onReadMenuTopBarMergeButtonsChange: (enabled: boolean) => this.setReaderReadMenuTopBarMergeButtons(enabled),
              onReadBarStyleChange: (value: number) => this.setReaderReadBarStyle(value),
              onReadMenuPaletteStyleChange: (value: string) => this.setReaderReadMenuPaletteStyle(value),
              onReadMenuColorModeChange: (value: number) => this.setReaderReadMenuColorMode(value),
              onReadMenuBgColorChange: (value: string) => this.setReaderReadMenuBgColor(value),
              onReadMenuBgColorNightChange: (value: string) => this.setReaderReadMenuBgColorNight(value),
              onReadMenuContainerColorChange: (value: string) => this.setReaderReadMenuContainerColor(value),
              onReadMenuContainerColorNightChange: (value: string) => this.setReaderReadMenuContainerColorNight(value),
              onReadMenuAccentColorChange: (value: string) => this.setReaderReadMenuAccentColor(value),
              onReadMenuAccentColorNightChange: (value: string) => this.setReaderReadMenuAccentColorNight(value),
              onReadMenuBorderWidthChange: (value: number) => this.setReaderReadMenuBorderWidth(value),
              onReadMenuBorderColorChange: (value: string) => this.setReaderReadMenuBorderColor(value),
              onReadMenuBorderColorNightChange: (value: string) => this.setReaderReadMenuBorderColorNight(value),
              onReadMenuBlurRadiusChange: (value: number) => this.setReaderReadMenuBlurRadius(value),
              onReadMenuTextColorChange: (value: string) => this.setReaderReadMenuTextColor(value),
              onReadMenuTextColorNightChange: (value: string) => this.setReaderReadMenuTextColorNight(value),
              onReadMenuBlurColorChange: (value: string) => this.setReaderReadMenuBlurColor(value),
              onReadMenuBlurColorNightChange: (value: string) => this.setReaderReadMenuBlurColorNight(value),
              onShowTitleBarIconsChange: (value: boolean) => this.setReaderShowTitleBarIcons(value),
              onTitleBarIconPositionChange: (value: number) => this.setReaderTitleBarIconPosition(value),
              onReadMenuFloatingIconLiquidGlassChange: (value: boolean) => this.setReaderReadMenuFloatingIconLiquidGlass(value),
              onFloatingIconsChange: (value: ReaderBottomActionConfig[]) => this.setReaderFloatingIcons(value),
              onTitleBarCustomIconsChange: (value: string) => this.setReaderTitleBarCustomIcons(value),
              onReadMenuCustomIconsChange: (value: string) => this.setReaderReadMenuCustomIcons(value),
              onShowMenuIconChange: (enabled: boolean) => this.setReaderShowMenuIcon(enabled),
              onShowReadTitleAdditionChange: (enabled: boolean) => this.setReaderShowReadTitleAddition(enabled),
              onMenuAlphaChange: (value: number) => this.setReaderMenuAlpha(value),
              onTextSelectMenuConfigChange: (value: string) => this.setReaderTextSelectMenuConfig(value),
              onReadingAnchorEnabledChange: (enabled: boolean) => this.setReaderReadingAnchorEnabled(enabled),
              onSwipeToAddBookmarkChange: (enabled: boolean) => this.setReaderSwipeToAddBookmark(enabled),
              onBookmarkBadgeSizeChange: (value: number) => this.setReaderBookmarkBadgeSize(value),
              onPickBookmarkBadgeImage: (): void => { this.pickReaderBookmarkBadgeImage(); },
              onResetBookmarkBadgeImage: (): void => this.resetReaderBookmarkBadgeImage(),
              onSelectTextChange: (enabled: boolean) => this.setReaderSelectText(enabled),
              onSliderVibratorChange: (enabled: boolean) => this.setReaderSliderVibrator(enabled),
              onSelectVibratorChange: (enabled: boolean) => this.setReaderSelectVibrator(enabled),
              onChineseConverterTypeChange: (value: number) => this.setReaderChineseConverterType(value),
              textColor: this.readerTextColor,
              textColorNight: this.readerTextColorNight,
              textAccentColor: this.readerTextAccentColor,
              textAccentColorNight: this.readerTextAccentColorNight,
              bgStr: this.readerBgStr,
              bgStrNight: this.readerBgStrNight,
              bgType: this.readerBgType,
              bgTypeNight: this.readerBgTypeNight,
              bgAlpha: this.readerBgAlpha,
              darkStatusIcon: this.readerDarkStatusIcon,
              darkStatusIconNight: this.readerDarkStatusIconNight,
              titleMode: this.readerTitleMode,
              titleSize: this.readerTitleSize,
              titleSizeRelative: this.readerTitleSizeRelative,
              titleTopSpacing: this.readerTitleTopSpacing,
              titleBottomSpacing: this.readerTitleBottomSpacing,
              titleColor: this.readerTitleColor,
              titleColorNight: this.readerTitleColorNight,
              titleBold: this.readerTitleBold,
              titleLineSpacingExtra: this.readerTitleLineSpacingExtra,
              titleLineSpacingSub: this.readerTitleLineSpacingSub,
              titleSegType: this.readerTitleSegType,
              titleSegScaling: this.readerTitleSegScaling,
              titleSegDistance: this.readerTitleSegDistance,
              titleSegFlag: this.readerTitleSegFlag,
              onTextColorChange: (value: string, night: boolean) => this.setReaderTextColor(value, night),
              onTextAccentColorChange: (value: string, night: boolean) => this.setReaderTextAccentColor(value, night),
              onBackgroundColorChange: (value: string, night: boolean) => this.setReaderBackgroundColor(value, night),
              onBackgroundImageChange: (path: string, night: boolean) => this.setReaderBackgroundImage(path, night),
              onBgAlphaChange: (value: number) => this.setReaderBgAlpha(value),
              onDarkStatusIconChange: (enabled: boolean, night: boolean) => this.setReaderDarkStatusIcon(enabled, night),
              onPickBackgroundImage: (night: boolean): void => { this.pickReaderBackgroundImage(night); },
              onTitleModeChange: (value: number) => this.setReaderTitleMode(value),
              onTitleSizeChange: (value: number) => this.setReaderTitleSize(value),
              onTitleSizeRelativeChange: (relative: boolean) => this.setReaderTitleSizeRelative(relative),
              onTitleSpacingChange: (top: number, bottom: number) => this.setReaderTitleSpacing(top, bottom),
              onTitleColorChange: (value: string, night: boolean) => this.setReaderTitleColor(value, night),
              onTitleBoldChange: (value: number) => this.setReaderTitleBold(value),
              onTitleLineSpacingChange: (extra: number, sub: number) => this.setReaderTitleLineSpacing(extra, sub),
              onTitleSegTypeChange: (value: number) => this.setReaderTitleSegType(value),
              onTitleSegScalingChange: (value: number) => this.setReaderTitleSegScaling(value),
              onTitleSegDistanceChange: (value: number) => this.setReaderTitleSegDistance(value),
              onTitleSegFlagChange: (value: string) => this.setReaderTitleSegFlag(value),
              onMaxLengthWithNoTocChange: (value: number) => this.setReaderMaxLengthWithNoToc(value),
              clickRegionActions: this.readerClickRegionActions,
              onClickRegionActionsChange: (actions: string[]) => this.setReaderClickRegionActions(actions),
              clickImageBehavior: this.readerClickImageBehavior,
              onClickImageBehaviorChange: (value: string) => this.setReaderClickImageBehavior(value),
              hideStatusBar: this.readerHideStatusBar,
              hideNavigationBar: this.readerHideNavigationBar,
              onHideStatusBarChange: (enabled: boolean) => this.setReaderHideStatusBar(enabled),
              onHideNavigationBarChange: (enabled: boolean) => this.setReaderHideNavigationBar(enabled),
              infoSettings: this.readerInfoSettings,
              onInfoSettingsChange: (settings: ReaderInfoSettings) => this.setReaderInfoSettings(settings),
              pageAnimationIndex: this.readerPageAnimation,
              animationSpeedIndex: this.readerAnimationSpeed,
              onBottomIconStyleChange: (style: number) => this.setReaderBottomIconStyle(style),
              onBottomItemsPerRowChange: (count: number) => this.setReaderBottomItemsPerRow(count),
              onBottomRowCountChange: (count: number) => this.setReaderBottomRowCount(count),
              onBottomActionsChange: (actions: ReaderBottomActionConfig[]) => this.setReaderBottomActions(actions),
              onTopActionsChange: (actions: ReaderBottomActionConfig[]) => this.setReaderTopActions(actions),
              onProgressBehaviorChange: (value: string) => this.setReaderProgressBehavior(value),
              readSliderMode: this.readerReadSliderMode,
              onReadSliderModeChange: (value: string) => this.setReaderReadSliderMode(value),
              pageTouchSlop: this.readerPageTouchSlop,
              onPageTouchSlopChange: (value: number) => this.setReaderPageTouchSlop(value),
              onPageAnimationChange: (animation: number) => this.setReaderPageAnimation(animation),
              onAnimationSpeedChange: (speed: number) => this.setReaderAnimationSpeed(speed),
              onBottomActionTextChange: (enabled: boolean) => this.setReaderBottomActionText(enabled),
              onShareLayoutChange: (enabled: boolean) => this.setReaderShareLayout(enabled),
              onToggleNightMode: () => this.toggleReaderNightMode(),
              onEyeProtectionToggle: () => this.toggleEyeProtection(),
              onEyeProtectionEnabledChange: (enabled: boolean) => this.setEyeProtectionEnabled(enabled),
              onEyeProtectionAutoNightChange: (enabled: boolean) => this.setEyeProtectionAutoNight(enabled),
              onEyeProtectionScheduleChange: (enabled: boolean) => this.setEyeProtectionSchedule(enabled),
              onEyeProtectionIntensityChange: (value: number) => this.setEyeProtectionIntensity(value),
              onEyeProtectionStartTimeChange: (value: string) => this.setEyeProtectionStartTime(value),
              onEyeProtectionEndTimeChange: (value: string) => this.setEyeProtectionEndTime(value),
              onUnavailableAction: (message: string) => this.showUnavailableAction(message),
              showQuickActions: this.showReaderQuickActions,
              asSheet: true,
              openBottomActionConfigOnAppear: this.readerSettingsOpenBottomActionConfig,
              onBack: () => {
                this.readerSettingsOpenBottomActionConfig = false;
                this.route = this.settingsReturnRoute;
              },
              onFontSizeChange: (fontSize: number) => this.setReaderFontSize(fontSize),
              onTextItalicChange: (enabled: boolean) => this.setReaderTextItalic(enabled),
              onTextBoldChange: (weight: number) => this.setReaderTextBold(weight),
              onTextShadowChange: (enabled: boolean) => this.setReaderTextShadow(enabled),
              onShadowRadiusChange: (value: number) => this.setReaderShadowRadius(value),
              onShadowDxChange: (value: number) => this.setReaderShadowDx(value),
              onShadowDyChange: (value: number) => this.setReaderShadowDy(value),
              onUnderlineChange: (enabled: boolean) => this.setReaderUnderline(enabled),
              onDottedLineChange: (enabled: boolean) => this.setReaderDottedLine(enabled),
              onTextShadowColorChange: (value: string, night: boolean) => this.setReaderTextShadowColor(value, night),
              onUnderlineColorChange: (value: string, night: boolean) => this.setReaderUnderlineColor(value, night),
              onUnderlineHeightChange: (value: number) => this.setReaderUnderlineHeight(value),
              onUnderlinePaddingChange: (value: number) => this.setReaderUnderlinePadding(value),
              onUnderlineExtendChange: (enabled: boolean) => this.setReaderUnderlineExtend(enabled),
              onDottedBaseChange: (value: number) => this.setReaderDottedBase(value),
              onDottedRatioChange: (value: number) => this.setReaderDottedRatio(value),
              onTextFontChange: (fontPath: string) => this.setReaderTextFont(fontPath),
              onTitleFontChange: (fontPath: string) => this.setReaderTitleFont(fontPath),
              onSystemTypefacesChange: (index: number) => this.setReaderSystemTypefaces(index),
              onTextFullJustifyChange: (enabled: boolean) => this.setReaderTextFullJustify(enabled),
              onTextBottomJustifyChange: (enabled: boolean) => this.setReaderTextBottomJustify(enabled),
              onParagraphSpacingChange: (value: number) => this.setReaderParagraphSpacing(value),
              onLineSpacingChange: (value: number) => this.setReaderLineSpacing(value),
              onLetterSpacingChange: (value: number) => this.setReaderLetterSpacing(value),
              onParagraphIndentCountChange: (count: number) => this.setReaderParagraphIndentCount(count),
              onPaperChange: (paperIndex: number) => this.setReaderPaperIndex(paperIndex),
              onAddBackgroundStyle: (): number => this.addReaderBackgroundStyle(),
              onUpdateBackgroundStyle: (index: number, name: string, dayColor: string, nightColor: string): void =>
                this.updateReaderBackgroundStyle(index, name, dayColor, nightColor),
              onRemoveBackgroundStyle: (index: number): void => this.removeReaderBackgroundStyle(index),
              onMoveBackgroundStyle: (from: number, to: number): void => this.moveReaderBackgroundStyle(from, to),
              onQuickActionsChange: (enabled: boolean) => this.setReaderQuickActions(enabled)
            })
          } else if (this.route === AppRoute.READ_ALOUD_SETTINGS) {
            ReaderAloudSettingsPage({
              onBack: () => this.returnToReaderMenu(),
              onOpenMainMenu: () => this.returnToReaderMenu(),
              onOpenCatalog: () => {
                this.catalogReturnRoute = AppRoute.READER;
                this.route = AppRoute.CATALOG;
              },
              onUnavailableAction: (message: string) => this.showUnavailableAction(message)
            })
          }
        }.width('100%').height('100%')
          .transition(this.readerRouteTransition())
        } else if (this.route === AppRoute.READER_SEARCH) {
        ReaderSearchPage({
          book: this.selectedBook,
          bookTitle: this.selectedBook.title,
          onReplaceRulesChanged: () => this.replaceRules = ReplaceRuleRepository.getAll(),
          onBack: () => this.route = AppRoute.READER,
          onOpenResult: (chapterIndex: number, position: number,
            items: ReaderSearchNavItem[], index: number) =>
            this.openReaderSearchResult(chapterIndex, position, items, index),
          onUnavailableAction: (message: string) => this.showUnavailableAction(message)
        })
        } else if (this.route === AppRoute.SEARCH) {
        SearchPage({
          books: this.books,
          groups: this.bookGroups,
          query: this.searchPageQuery,
          selectedGroup: this.searchPageGroup,
          sourceScope: this.searchPageSourceScope,
          exactMatch: this.searchPageExactMatch,
          coverSettings: this.coverSettings,
          onBack: () => this.route = this.searchReturnRoute,
          onOpenBook: (book: Book) => this.openBook(book),
          onOpenSourceManage: () => this.openProfileDetail(ProfileRoute.BOOK_SOURCE_MANAGE),
          onUnavailableAction: (message: string) => this.showUnavailableAction(message),
          onQueryChange: (query: string) => this.searchPageQuery = query,
          onGroupChange: (group: string) => this.searchPageGroup = group,
          onSourceScopeChange: (enabled: boolean) => this.searchPageSourceScope = enabled,
          onExactMatchChange: (enabled: boolean) => this.searchPageExactMatch = enabled
        })
        } else if (this.route === AppRoute.PROFILE_SUBPAGE) {
        if (this.profileSubpage === ProfileRoute.BOOK_SOURCE_MANAGE) {
          BookSourceManagePage({ onBack: () => this.route = this.profileDetailReturnRoute, onUnavailableAction: (message: string) => this.showUnavailableAction(message) })
        } else if (this.profileSubpage === ProfileRoute.REPLACE_RULES) {
          ReplaceRulesPage({
            onBack: () => this.route = this.profileDetailReturnRoute,
            onOpenEditor: () => {
              this.editingReplaceRule = undefined;
              this.profileSubpage = ProfileRoute.REPLACE_RULE_EDIT;
            },
            rules: this.replaceRules,
            groups: this.replaceRuleGroups(),
            sortMode: this.replaceRuleSortMode,
            onToggleRule: (id: number, enabled: boolean) => this.setReplaceRuleEnabled(id, enabled),
            onRemoveRule: (id: number) => this.removeReplaceRule(id),
            onEditRule: (id: number) => this.openReplaceRuleEditor(id),
            onMoveRule: (id: number, toTop: boolean) => this.moveReplaceRule(id, toTop),
            onRenameGroup: (oldName: string, newName: string) => this.renameReplaceRuleGroup(oldName, newName),
            onRemoveGroup: (name: string) => this.removeReplaceRuleGroup(name),
            onSortModeChange: (mode: string) => this.setReplaceRuleSortMode(mode),
            onImportRules: (text: string, source: string) => this.importReplaceRules(text, source),
            onExportRules: (rules: ReplaceRule[]) => this.exportReplaceRules(rules),
            onSetEnabledBatch: (ids: number[], enabled: boolean) => this.setReplaceRuleEnabledBatch(ids, enabled),
            onRemoveBatch: (ids: number[]) => this.removeReplaceRuleBatch(ids),
            onMoveBatch: (ids: number[], toTop: boolean) => this.moveReplaceRuleBatch(ids, toTop),
            onReorderRule: (fromId: number, toId: number) => this.reorderReplaceRule(fromId, toId),
            onUnavailableAction: (message: string) => this.showUnavailableAction(message)
          })
        } else if (this.profileSubpage === ProfileRoute.REPLACE_RULE_EDIT) {
          ReplaceRuleEditPage({
            onBack: () => {
              this.editingReplaceRule = undefined;
              this.profileSubpage = ProfileRoute.REPLACE_RULES;
            },
            onSaveRule: (rule: ReplaceRule) => this.saveReplaceRule(rule),
            editingRule: this.editingReplaceRule,
            groups: this.replaceRuleGroups(),
            onRenameGroup: (oldName: string, newName: string) => this.renameReplaceRuleGroup(oldName, newName),
            onRemoveGroup: (name: string) => this.removeReplaceRuleGroup(name),
            onUnavailableAction: (message: string) => this.showUnavailableAction(message)
          })
        } else if (this.profileSubpage === ProfileRoute.TXT_TOC_RULE_PREVIEW) {
          TxtTocRulePreviewPage({
            book: this.selectedBook,
            onBack: () => this.route = this.profileDetailReturnRoute,
            onApplyRule: (chapterRule: string, ruleName: string) => this.applyTocRule(chapterRule, ruleName),
            onOpenManagePage: () => this.profileSubpage = ProfileRoute.TXT_TOC_RULES,
            onUnavailableAction: (message: string) => this.showUnavailableAction(message)
          })
        } else if (this.profileSubpage === ProfileRoute.TXT_TOC_RULES) {
          TxtTocRulesPage({
            onBack: () => this.route = this.profileDetailReturnRoute,
            onUnavailableAction: (message: string) => this.showUnavailableAction(message),
            rules: this.txtTocRules.map((rule: TxtTocRule): RuleListEntry => ({
              id: `${rule.id}`, title: rule.name, detail: rule.chapterRule, enabled: rule.enable
            })),
            sourceRules: this.txtTocRules,
            onSaveRule: (rule: TxtTocRule) => this.saveTxtTocRule(rule),
            onRemoveRule: (id: number) => this.removeTxtTocRule(id),
            onRemoveBatch: (ids: number[]) => this.removeTxtTocRuleBatch(ids),
            onToggleRule: (id: number, enabled: boolean) => this.setTxtTocRuleEnabled(id, enabled),
            onMoveRule: (id: number, direction: number) => this.moveTxtTocRule(id, direction),
            onMoveRuleToEdge: (id: number, toTop: boolean) => this.moveTxtTocRuleToEdge(id, toTop),
            onSetEnabledBatch: (ids: number[], enabled: boolean) => this.setTxtTocRuleEnabledBatch(ids, enabled),
            onImportBuiltin: () => this.importBuiltinTxtTocRules(),
            onImportRules: () => this.importTxtTocRules(),
            onExportRules: (rules: TxtTocRule[]) => this.exportTxtTocRules(rules)
          })
        } else if (this.profileSubpage === ProfileRoute.DICTIONARY_RULES) {
          DictionaryRulesPage({
            onBack: () => this.route = this.profileDetailReturnRoute,
            onOpenEditor: () => this.profileSubpage = ProfileRoute.DICTIONARY_RULE_EDIT,
            onUnavailableAction: (message: string) => this.showUnavailableAction(message)
          })
        } else if (this.profileSubpage === ProfileRoute.DICTIONARY_RULE_EDIT) {
          DictionaryRuleEditPage({
            onBack: () => this.profileSubpage = ProfileRoute.DICTIONARY_RULES,
            onUnavailableAction: (message: string) => this.showUnavailableAction(message)
          })
        } else if (this.profileSubpage === ProfileRoute.HIGHLIGHT_TAG_RULES) {
          HighlightTagRulesPage({
            onBack: () => this.route = this.profileDetailReturnRoute,
            onOpenEditor: () => this.profileSubpage = ProfileRoute.HIGHLIGHT_TAG_RULE_EDIT,
            onUnavailableAction: (message: string) => this.showUnavailableAction(message)
          })
        } else if (this.profileSubpage === ProfileRoute.HIGHLIGHT_TAG_RULE_EDIT) {
          HighlightTagRuleEditPage({
            onBack: () => this.profileSubpage = ProfileRoute.HIGHLIGHT_TAG_RULES,
            onUnavailableAction: (message: string) => this.showUnavailableAction(message)
          })
        } else if (this.profileSubpage === ProfileRoute.ALL_BOOKMARKS) {
          AllBookmarksPage({ books: this.getBookmarkBookSummaries(), entries: this.getBookmarkEntrySummaries(), onBack: () => this.route = this.profileDetailReturnRoute, onUnavailableAction: (message: string) => this.showUnavailableAction(message), onOpenBookmark: (bookmarkId: string) => this.openReaderBookmark(bookmarkId), onEditBookmark: (bookmarkId: string) => this.editReaderBookmark(bookmarkId), onOpenMarking: (markingId: string) => this.openReaderMarking(markingId), onExportBookmarks: (bookKey: string, isMarkdown: boolean) => this.exportBookmarksByKey(bookKey, isMarkdown) })
        } else if (this.profileSubpage === ProfileRoute.READ_RECORDS) {
          ReadRecordsPage({
            records: this.readTimeRecords,
            details: this.readRecordDetails,
            summaries: this.readRecordSummaries,
            onBack: () => this.route = this.profileDetailReturnRoute,
            onUnavailableAction: (message: string) => this.showUnavailableAction(message),
            onOpenOverview: () => this.openProfileDetail(ProfileRoute.READ_RECORD_OVERVIEW),
            onRecordsChanged: async () => {
              const context = this.getUIContext().getHostContext();
              if (context !== undefined) { await this.reloadReadRecordData(context); }
            }
          })
        } else if (this.profileSubpage === ProfileRoute.READ_RECORD_OVERVIEW) {
          ReadRecordOverviewPage({
            details: this.readRecordDetails,
            summaries: this.readRecordSummaries,
            books: this.books,
            onBack: () => this.route = this.profileDetailReturnRoute,
            onOpenBook: (name: string, author: string) => {
              const hit = this.books.find((item: Book) => item.title === name && item.author === author);
              if (hit !== undefined) { this.openBook(hit); }
            }
          })
        } else if (this.profileSubpage === ProfileRoute.CACHE_MANAGEMENT) {
          CacheManagementPage({
            groups: this.cacheManagementGroups(),
            books: this.books,
            onBack: () => this.route = this.profileDetailReturnRoute,
            onUnavailableAction: (message: string) => this.showUnavailableAction(message)
          })
        } else if (this.profileSubpage === ProfileRoute.BOOKSHELF_MANAGE) {
          BookshelfManagePage({
            books: this.books,
            groups: this.bookGroups,
            initialGroupName: this.bookshelfManageGroupName,
            onBack: () => this.route = this.profileDetailReturnRoute,
            onOpenBookInfo: (book: Book) => this.openBookInfo(book),
            onLibraryChanged: () => this.reloadLibraryAfterBulkChange(),
            onUnavailableAction: (message: string) => this.showUnavailableAction(message)
          })
        } else if (this.profileSubpage === ProfileRoute.FILE_MANAGER) {
          FileManagerPage({
            rootPath: this.getAppFileManagerRootDirectory(),
            books: this.books,
            onBack: () => this.route = this.profileDetailReturnRoute,
            onOpenBook: (book: Book) => this.openBook(book),
            onUnavailableAction: (message: string) => this.showUnavailableAction(message)
          })
        } else if (this.profileSubpage === ProfileRoute.PRIVACY_NOTICE) {
          PrivacyNoticePage({ onBack: () => this.profileSubpage = ProfileRoute.ABOUT })
        } else if (this.profileSubpage === ProfileRoute.OPEN_SOURCE_LICENSE) {
          OpenSourceLicensePage({ onBack: () => this.profileSubpage = ProfileRoute.ABOUT })
        } else if (this.profileSubpage === ProfileRoute.ABOUT) {
          AboutAppPage({
            onBack: () => this.route = this.profileDetailReturnRoute,
            onOpenPrivacyNotice: () => this.profileSubpage = ProfileRoute.PRIVACY_NOTICE,
            onOpenLicense: () => this.profileSubpage = ProfileRoute.OPEN_SOURCE_LICENSE,
            onUnavailableAction: (message: string) => this.showUnavailableAction(message)
          })
        } else if (this.profileSubpage === ProfileRoute.AI_CHAT) {
          AiChatPage({ onBack: () => this.route = this.profileDetailReturnRoute, onUnavailableAction: (message: string) => this.showUnavailableAction(message) })
        } else if (this.profileSubpage === ProfileRoute.APP_SETTINGS) {
          AppSettingsHomePage({
            onBack: () => this.route = this.profileDetailReturnRoute,
            onOpenCategory: (destination: ProfileRoute) => this.openSettingsCategory(destination),
            onUnavailableAction: (message: string) => this.showUnavailableAction(message)
          })
        } else if (this.profileSubpage === ProfileRoute.APP_THEME_SETTINGS) {
          ThemeSettingsPage({
            onBack: () => this.profileSubpage = this.profileSettingsReturn,
            onUnavailableAction: (message: string) => this.showUnavailableAction(message),
            themeMode: this.themeMode,
            paletteIndex: this.themePaletteIndex,
            readerNightMode: this.readerNightMode,
            fontScale: this.themeFontScale,
            showStatusBarVisible: this.themeShowStatusBar,
            swipeAnimationEnabled: this.themeSwipeAnimation,
            onThemeModeChange: (themeMode: string) => this.selectThemeMode(themeMode),
            onPaletteChange: (paletteIndex: number) => this.selectThemePalette(paletteIndex),
            onFontScaleChange: (fontScale: number) => {
              const themeContext = this.getUIContext().getHostContext();
              if (themeContext !== undefined) { this.selectThemeFontScale(themeContext, fontScale); }
            },
            onShowStatusBarChange: (visible: boolean) => {
              const themeContext = this.getUIContext().getHostContext();
              if (themeContext !== undefined) { this.selectThemeShowStatusBar(themeContext, visible); }
            },
            onSwipeAnimationChange: (enabled: boolean) => {
              const themeContext = this.getUIContext().getHostContext();
              if (themeContext !== undefined) { this.selectThemeSwipeAnimation(themeContext, enabled); }
            },
            bookInfoFollowCoverColor: this.bookInfoFollowCoverColor,
            bookInfoNetworkCoverBackground: this.bookInfoNetworkCoverBackground,
            bookInfoDefaultCoverBackground: this.bookInfoDefaultCoverBackground,
            onBookInfoFollowCoverColorChange: (enabled: boolean) => {
              const themeContext = this.getUIContext().getHostContext();
              if (themeContext !== undefined) { this.selectBookInfoFollowCoverColor(themeContext, enabled); }
            },
            onBookInfoCoverBackgroundChange: (isDefaultCover: boolean, value: string) => {
              const themeContext = this.getUIContext().getHostContext();
              if (themeContext !== undefined) { this.selectBookInfoCoverBackground(themeContext, isDefaultCover, value); }
            },
            containerOpacity: this.themeContainerOpacity,
            disableGroupCorner: this.themeDisableGroupCorner,
            overrideCardCorner: this.themeOverrideCardCorner,
            cardCornerRadius: this.themeCardCornerRadius,
            overrideCardBorder: this.themeOverrideCardBorder,
            cardBorderWidth: this.themeCardBorderWidth,
            cardBorderColorDay: this.themeCardBorderColorDay,
            cardBorderColorNight: this.themeCardBorderColorNight,
            enableItemDivider: this.themeEnableItemDivider,
            dividerWidth: this.themeItemDividerWidth,
            dividerLength: this.themeItemDividerLength,
            dividerColor: this.themeItemDividerColor,
            enableContainerBackgroundImage: this.themeEnableContainerBackgroundImage,
            largeContainerBackgroundLight: this.themeLargeContainerBackgroundLight,
            largeContainerBackgroundDark: this.themeLargeContainerBackgroundDark,
            itemBackgroundLight: this.themeItemBackgroundLight,
            itemBackgroundDark: this.themeItemBackgroundDark,
            onContainerOpacityChange: (value: number) => {
              const themeContext = this.getUIContext().getHostContext();
              if (themeContext !== undefined) { this.selectThemeContainerOpacity(themeContext, value); }
            },
            onDisableGroupCornerChange: (value: boolean) => {
              const themeContext = this.getUIContext().getHostContext();
              if (themeContext !== undefined) { this.selectThemeDisableGroupCorner(themeContext, value); }
            },
            onOverrideCardCornerChange: (value: boolean) => {
              const themeContext = this.getUIContext().getHostContext();
              if (themeContext !== undefined) { this.selectThemeOverrideCardCorner(themeContext, value); }
            },
            onCardCornerRadiusChange: (value: number) => {
              const themeContext = this.getUIContext().getHostContext();
              if (themeContext !== undefined) { this.selectThemeCardCornerRadius(themeContext, value); }
            },
            onOverrideCardBorderChange: (value: boolean) => {
              const themeContext = this.getUIContext().getHostContext();
              if (themeContext !== undefined) { this.selectThemeOverrideCardBorder(themeContext, value); }
            },
            onCardBorderWidthChange: (value: number) => {
              const themeContext = this.getUIContext().getHostContext();
              if (themeContext !== undefined) { this.selectThemeCardBorderWidth(themeContext, value); }
            },
            onCardBorderColorChange: (isNight: boolean, value: string) => {
              const themeContext = this.getUIContext().getHostContext();
              if (themeContext !== undefined) { this.selectThemeCardBorderColor(themeContext, isNight, value); }
            },
            onResetDefaults: () => this.resetThemeDefaults(),
            onEnableItemDividerChange: (enabled: boolean) => {
              const themeContext = this.getUIContext().getHostContext();
              if (themeContext !== undefined) { this.selectThemeEnableItemDivider(themeContext, enabled); }
            },
            onDividerWidthChange: (value: number) => {
              const themeContext = this.getUIContext().getHostContext();
              if (themeContext !== undefined) { this.selectThemeItemDividerWidth(themeContext, value); }
            },
            onDividerLengthChange: (value: number) => {
              const themeContext = this.getUIContext().getHostContext();
              if (themeContext !== undefined) { this.selectThemeItemDividerLength(themeContext, value); }
            },
            onDividerColorChange: (value: string) => {
              const themeContext = this.getUIContext().getHostContext();
              if (themeContext !== undefined) { this.selectThemeItemDividerColor(themeContext, value); }
            },
            onEnableContainerBackgroundImageChange: (enabled: boolean) => {
              const themeContext = this.getUIContext().getHostContext();
              if (themeContext !== undefined) { this.selectThemeEnableContainerBackgroundImage(themeContext, enabled); }
            },
            onPickContainerBackground: (isLarge: boolean, isNight: boolean) => this.pickThemeContainerBackground(isLarge, isNight),
            appFontPath: this.themeAppFontPath,
            onPickAppFont: () => {
              const themeContext = this.getUIContext().getHostContext();
              if (themeContext !== undefined) { this.pickThemeAppFont(themeContext); }
            },
            onClearAppFont: () => {
              const themeContext = this.getUIContext().getHostContext();
              if (themeContext !== undefined) { this.clearThemeAppFont(themeContext); }
            },
            pureBlack: this.themePureBlack,
            onPureBlackChange: (enabled: boolean) => {
              const themeContext = this.getUIContext().getHostContext();
              if (themeContext !== undefined) { this.selectThemePureBlack(themeContext, enabled); }
            },
            predictiveBack: this.themePredictiveBack,
            onPredictiveBackChange: (enabled: boolean) => {
              const themeContext = this.getUIContext().getHostContext();
              if (themeContext !== undefined) { this.selectThemePredictiveBack(themeContext, enabled); }
            },
            readerSharedElement: this.themeReaderSharedElement,
            onReaderSharedElementChange: (enabled: boolean) => {
              const themeContext = this.getUIContext().getHostContext();
              if (themeContext !== undefined) { this.selectThemeReaderSharedElement(themeContext, enabled); }
            },
            enableBlur: this.themeEnableBlur,
            onEnableBlurChange: (enabled: boolean) => {
              const themeContext = this.getUIContext().getHostContext();
              if (themeContext !== undefined) { this.selectThemeEnableBlur(themeContext, enabled); }
            },
            enableProgressiveBlur: this.themeEnableProgressiveBlur,
            onEnableProgressiveBlurChange: (enabled: boolean) => {
              const themeContext = this.getUIContext().getHostContext();
              if (themeContext !== undefined) { this.selectThemeEnableProgressiveBlur(themeContext, enabled); }
            },
            useFlexibleTopAppBar: this.themeUseFlexibleTopAppBar,
            onUseFlexibleTopAppBarChange: (enabled: boolean) => {
              const themeContext = this.getUIContext().getHostContext();
              if (themeContext !== undefined) { this.selectThemeUseFlexibleTopAppBar(themeContext, enabled); }
            },
            topBarButtonStyle: this.themeTopBarButtonStyle,
            onTopBarButtonStyleChange: (value: string) => {
              const themeContext = this.getUIContext().getHostContext();
              if (themeContext !== undefined) { this.selectThemeTopBarButtonStyle(themeContext, value); }
            },
            mergeTopBarActions: this.themeMergeTopBarActions,
            onMergeTopBarActionsChange: (enabled: boolean) => {
              const themeContext = this.getUIContext().getHostContext();
              if (themeContext !== undefined) { this.selectThemeMergeTopBarActions(themeContext, enabled); }
            },
            showBottomView: this.themeShowBottomView,
            onShowBottomViewChange: (enabled: boolean) => {
              const themeContext = this.getUIContext().getHostContext();
              if (themeContext !== undefined) { this.selectThemeShowBottomView(themeContext, enabled); }
            },
            useFloatingBottomBar: this.themeUseFloatingBottomBar,
            onUseFloatingBottomBarChange: (enabled: boolean) => {
              const themeContext = this.getUIContext().getHostContext();
              if (themeContext !== undefined) { this.selectThemeUseFloatingBottomBar(themeContext, enabled); }
            },
            useFloatingBottomBarLiquidGlass: this.themeUseFloatingBottomBarLiquidGlass,
            onUseFloatingBottomBarLiquidGlassChange: (enabled: boolean) => {
              const themeContext = this.getUIContext().getHostContext();
              if (themeContext !== undefined) { this.selectThemeUseFloatingBottomBarLiquidGlass(themeContext, enabled); }
            },
            bottomBarLensRadius: this.themeBottomBarLensRadius,
            onBottomBarLensRadiusChange: (value: number) => {
              const themeContext = this.getUIContext().getHostContext();
              if (themeContext !== undefined) { this.selectThemeBottomBarLensRadius(themeContext, value); }
            },
            topBarBlurRadius: this.themeTopBarBlurRadius,
            onTopBarBlurRadiusChange: (value: number) => {
              const themeContext = this.getUIContext().getHostContext();
              if (themeContext !== undefined) { this.selectThemeTopBarBlurRadius(themeContext, value); }
            },
            bottomBarBlurRadius: this.themeBottomBarBlurRadius,
            onBottomBarBlurRadiusChange: (value: number) => {
              const themeContext = this.getUIContext().getHostContext();
              if (themeContext !== undefined) { this.selectThemeBottomBarBlurRadius(themeContext, value); }
            },
            topBarBlurAlpha: this.themeTopBarBlurAlpha,
            onTopBarBlurAlphaChange: (value: number) => {
              const themeContext = this.getUIContext().getHostContext();
              if (themeContext !== undefined) { this.selectThemeTopBarBlurAlpha(themeContext, value); }
            },
            bottomBarBlurAlpha: this.themeBottomBarBlurAlpha,
            onBottomBarBlurAlphaChange: (value: number) => {
              const themeContext = this.getUIContext().getHostContext();
              if (themeContext !== undefined) { this.selectThemeBottomBarBlurAlpha(themeContext, value); }
            },
            topBarOpacity: this.themeTopBarOpacity,
            onTopBarOpacityChange: (value: number) => {
              const themeContext = this.getUIContext().getHostContext();
              if (themeContext !== undefined) { this.selectThemeTopBarOpacity(themeContext, value); }
            },
            bottomBarOpacity: this.themeBottomBarOpacity,
            onBottomBarOpacityChange: (value: number) => {
              const themeContext = this.getUIContext().getHostContext();
              if (themeContext !== undefined) { this.selectThemeBottomBarOpacity(themeContext, value); }
            },
            showHome: this.themeShowHome,
            showDiscovery: this.themeShowDiscovery,
            showRss: this.themeShowRss,
            defaultHomePage: this.themeDefaultHomePage,
            mainNavigationOrder: this.themeMainNavigationOrder,
            labelVisibilityMode: this.themeLabelVisibilityMode,
            onNavigationVisibilityChange: (route: string, visible: boolean) => {
              const themeContext = this.getUIContext().getHostContext();
              if (themeContext !== undefined) { this.selectThemeNavigationVisibility(themeContext, route, visible); }
            },
            onNavigationMove: (route: string, up: boolean) => {
              const themeContext = this.getUIContext().getHostContext();
              if (themeContext === undefined) { return; }
              if (up) { this.moveThemeNavigationUp(themeContext, route); }
              else { this.moveThemeNavigationDown(themeContext, route); }
            },
            onDefaultHomePageChange: (route: string) => {
              const themeContext = this.getUIContext().getHostContext();
              if (themeContext !== undefined) { this.selectThemeDefaultHomePage(themeContext, route); }
            },
            onLabelVisibilityModeChange: (value: string) => {
              const themeContext = this.getUIContext().getHostContext();
              if (themeContext !== undefined) { this.selectThemeLabelVisibilityMode(themeContext, value); }
            },
            appBackgroundImage: this.themeBackgroundImage,
            appBackgroundImageNight: this.themeBackgroundImageNight,
            appBackgroundBlur: this.themeBackgroundBlur,
            appBackgroundNightBlur: this.themeBackgroundNightBlur,
            onPickBackgroundImage: (isNight: boolean) => this.pickThemeBackgroundImage(isNight),
            onBackgroundBlurChange: (isNight: boolean, blur: number) => {
              const themeContext = this.getUIContext().getHostContext();
              if (themeContext !== undefined) { this.selectThemeBackgroundBlur(themeContext, isNight, blur); }
            },
            onClearBackgroundImage: (isNight: boolean) => {
              const themeContext = this.getUIContext().getHostContext();
              if (themeContext !== undefined) { this.clearThemeBackgroundImage(themeContext, isNight); }
            },
            eyeProtectionEnabled: this.eyeProtectionEnabled,
            eyeProtectionAutoNight: this.eyeProtectionAutoNight,
            eyeProtectionSchedule: this.eyeProtectionSchedule,
            eyeProtectionIntensity: this.eyeProtectionIntensity,
            eyeProtectionStartTime: this.eyeProtectionStartTime,
            eyeProtectionEndTime: this.eyeProtectionEndTime,
            eyeProtectionActive: this.isEyeProtectionActive(),
            onEyeProtectionEnabledChange: (enabled: boolean) => this.setEyeProtectionEnabled(enabled),
            onEyeProtectionAutoNightChange: (enabled: boolean) => this.setEyeProtectionAutoNight(enabled),
            onEyeProtectionScheduleChange: (enabled: boolean) => this.setEyeProtectionSchedule(enabled),
            onEyeProtectionIntensityChange: (intensity: number) => this.setEyeProtectionIntensity(intensity),
            onEyeProtectionStartTimeChange: (time: string) => this.setEyeProtectionStartTime(time),
            onEyeProtectionEndTimeChange: (time: string) => this.setEyeProtectionEndTime(time),
            customTheme: this.themeCustomColors,
            onOpenCustomTheme: () => this.openSettingsCategory(ProfileRoute.APP_CUSTOM_THEME),
            onOpenThemeManage: () => this.openSettingsCategory(ProfileRoute.APP_THEME_MANAGE)
          })
        } else if (this.profileSubpage === ProfileRoute.APP_CUSTOM_THEME) {
          CustomThemePage({
            onBack: () => this.profileSubpage = ProfileRoute.APP_THEME_SETTINGS,
            onUnavailableAction: (message: string) => this.showUnavailableAction(message),
            customTheme: this.themeCustomColors,
            onChange: (snapshot: CustomThemeSnapshot) => this.saveCustomTheme(snapshot)
          })
        } else if (this.profileSubpage === ProfileRoute.APP_THEME_MANAGE) {
          ThemeManagePage({
            onBack: () => this.profileSubpage = ProfileRoute.APP_THEME_SETTINGS,
            onUnavailableAction: (message: string) => this.showUnavailableAction(message),
            provideSource: () => this.themePackageSource(),
            onApplyTheme: (patch: ThemeConfigPatch, assets: Record<string, string>) =>
              this.applyThemePackage(patch, assets)
          })
        } else if (this.profileSubpage === ProfileRoute.APP_OTHER_SETTINGS) {
          OtherSettingsPage({
            onBack: () => this.profileSubpage = this.profileSettingsReturn,
            replaceEnableDefault: this.replaceEnableDefault,
            onReplaceEnableDefaultChange: (enabled: boolean) => this.setReplaceDefaultEnabled(enabled),
            onUnavailableAction: (message: string) => this.showUnavailableAction(message)
          })
        } else if (this.profileSubpage === ProfileRoute.APP_READ_SETTINGS) {
          ReaderSettingsPage({
            fontSize: this.readerFontSize,
        paragraphSpacing: this.readerParagraphSpacing,
        lineSpacing: this.readerLineSpacing,
        letterSpacing: this.readerLetterSpacing,
        paragraphIndent: this.readerParagraphIndent,
              textFont: this.readerTextFont,
              titleFont: this.readerTitleFont,
              systemTypefaces: this.readerSystemTypefaces,
              textItalic: this.readerTextItalic,
              textBold: this.readerTextBold,
              textShadow: this.readerTextShadow,
              shadowRadius: this.readerShadowRadius,
              shadowDx: this.readerShadowDx,
              shadowDy: this.readerShadowDy,
              underline: this.readerUnderline,
              dottedLine: this.readerDottedLine,
              textShadowColor: this.readerTextShadowColor,
              textShadowColorN: this.readerTextShadowColorN,
              underlineColor: this.readerUnderlineColor,
              underlineColorNight: this.readerUnderlineColorNight,
              underlineHeight: this.readerUnderlineHeight,
              underlinePadding: this.readerUnderlinePadding,
              underlineExtend: this.readerUnderlineExtend,
              dottedBase: this.readerDottedBase,
              dottedRatio: this.readerDottedRatio,
        textFullJustify: this.readerTextFullJustify,
        textBottomJustify: this.readerTextBottomJustify,
            paperIndex: this.paperIndex,
            backgroundStyles: this.backgroundStyles,
            shareLayout: this.shareReaderStyleLayout,
            readerNightMode: this.readerNightMode,
            eyeProtectionActive: this.isEyeProtectionActive(),
            eyeProtectionEnabled: this.eyeProtectionEnabled,
            eyeProtectionAutoNight: this.eyeProtectionAutoNight,
            eyeProtectionSchedule: this.eyeProtectionSchedule,
            eyeProtectionIntensity: this.eyeProtectionIntensity,
            eyeProtectionStartTime: this.eyeProtectionStartTime,
            eyeProtectionEndTime: this.eyeProtectionEndTime,
            showBottomActionText: this.showReaderBottomActionText,
            bottomIconStyle: this.readerBottomIconStyle,
            bottomItemsPerRow: this.readerBottomItemsPerRow,
            bottomRowCount: this.readerBottomRowCount,
            bottomActions: this.readerBottomActions,
            topActions: this.readerTopActions,
            progressBehavior: this.readerProgressBehavior,
            paddingSettings: this.readerPaddingSettings,
            onPaddingSettingsChange: (settings: ReaderPaddingSettings) => this.setReaderPaddingSettings(settings),
            screenOrientation: this.readerScreenOrientation,
            onScreenOrientationChange: (orientation: string) => this.setReaderScreenOrientation(orientation),
            keepLight: this.readerKeepLight,
            onKeepLightChange: (value: string) => this.setReaderKeepLight(value),
            volumeKeyPage: this.readerVolumeKeyPage,
            onVolumeKeyPageChange: (enabled: boolean) => this.setReaderVolumeKeyPage(enabled),
            keyPageOnLongPress: this.readerKeyPageOnLongPress,
            onKeyPageOnLongPressChange: (enabled: boolean) => this.setReaderKeyPageOnLongPress(enabled),
            noAnimScrollPage: this.readerNoAnimScrollPage,
            prevKeys: this.readerPrevKeys,
            nextKeys: this.readerNextKeys,
            mouseWheelPage: this.readerMouseWheelPage,
            expandTextMenu: this.readerExpandTextMenu,
            showSelectMenuIcon: this.readerShowSelectMenuIcon,
            textSelectMenuConfig: this.readerTextSelectMenuConfig,
            doubleHorizontalPage: this.readerDoubleHorizontalPage,
            autoSuggestDayNight: this.readerAutoSuggestDayNight,
            disableReturnKey: this.readerDisableReturnKey,
            readingAnchorEnabled: this.readerReadingAnchorEnabled,
        swipeToAddBookmark: this.readerSwipeToAddBookmark,
        bookmarkBadgeSize: this.readerBookmarkBadgeSize,
        bookmarkBadgeImage: this.readerBookmarkBadgeImage,
        selectText: this.readerSelectText,
        sliderVibrator: this.readerSliderVibrator,
        selectVibrator: this.readerSelectVibrator,
        chineseConverterType: this.readerChineseConverterType,
        maxLengthWithNoToc: this.readerMaxLengthWithNoToc,
            onNoAnimScrollPageChange: (enabled: boolean) => this.setReaderNoAnimScrollPage(enabled),
            onPrevKeysChange: (value: string) => this.setReaderPrevKeys(value),
            onNextKeysChange: (value: string) => this.setReaderNextKeys(value),
            onMouseWheelPageChange: (enabled: boolean) => this.setReaderMouseWheelPage(enabled),
            onExpandTextMenuChange: (enabled: boolean) => this.setReaderExpandTextMenu(enabled),
            onShowSelectMenuIconChange: (enabled: boolean) => this.setReaderShowSelectMenuIcon(enabled),
            onDoubleHorizontalPageChange: (value: string) => this.setReaderDoubleHorizontalPage(value),
            onAutoSuggestDayNightChange: (enabled: boolean) => this.setReaderAutoSuggestDayNight(enabled),
            onDisableReturnKeyChange: (enabled: boolean) => this.setReaderDisableReturnKey(enabled),
            readBrightness: this.readerReadBrightness,
            onReadBrightnessChange: (value: number) => this.setReaderReadBrightness(value),
            showBrightnessView: this.readerShowBrightnessView,
            onShowBrightnessViewChange: (value: string) => this.setReaderShowBrightnessView(value),
            brightnessVwPos: this.readerBrightnessVwPos,
            onBrightnessVwPosChange: (value: string) => this.setReaderBrightnessVwPos(value),
            brightnessAuto: this.readerBrightnessAuto,
            readBodyToLh: this.readerReadBodyToLh,
            useZhLayout: this.readerUseZhLayout,
            paddingDisplayCutouts: this.readerPaddingDisplayCutouts,
            readMenuBottomCornerRadius: this.readerReadMenuBottomCornerRadius,
            readMenuFloatingBottomBar: this.readerReadMenuFloatingBottomBar,
            readMenuBottomBarBlurMode: this.readerReadMenuBottomBarBlurMode,
            readMenuBottomBarBlurStyle: this.readerReadMenuBottomBarBlurStyle,
            readMenuBottomBarLiquidGlassButtons: this.readerReadMenuBottomBarLiquidGlassButtons,
            readMenuBlurAlpha: this.readerReadMenuBlurAlpha,
            readMenuTopBarTitleCapsule: this.readerReadMenuTopBarTitleCapsule,
            titleBarMode: this.readerTitleBarMode,
            titleBarCompact: this.readerTitleBarCompact,
            titleBarIconStyle: this.readerTitleBarIconStyle,
            readMenuTopBarBlurMode: this.readerReadMenuTopBarBlurMode,
            readMenuTopBarBlurStyle: this.readerReadMenuTopBarBlurStyle,
            readMenuTopBarLiquidGlassButtons: this.readerReadMenuTopBarLiquidGlassButtons,
            readMenuTopBarMergeButtons: this.readerReadMenuTopBarMergeButtons,
            readBarStyle: this.readerReadBarStyle,
            readMenuPaletteStyle: this.readerMenuPaletteStyle,
            readMenuColorMode: this.readerMenuColorMode,
            readMenuBgColor: this.readerMenuBgColor,
            readMenuBgColorNight: this.readerMenuBgColorNight,
            readMenuContainerColor: this.readerMenuContainerColor,
            readMenuContainerColorNight: this.readerMenuContainerColorNight,
            readMenuAccentColor: this.readerMenuAccentColor,
            readMenuAccentColorNight: this.readerMenuAccentColorNight,
            readMenuBorderWidth: this.readerMenuBorderWidth,
            readMenuBorderColor: this.readerMenuBorderColor,
            readMenuBorderColorNight: this.readerMenuBorderColorNight,
            readMenuBlurRadius: this.readerMenuBlurRadius,
            readMenuTextColor: this.readerMenuTextColor,
            readMenuTextColorNight: this.readerMenuTextColorNight,
            readMenuBlurColor: this.readerMenuBlurColor,
            readMenuBlurColorNight: this.readerMenuBlurColorNight,
            showTitleBarIcons: this.readerShowTitleBarIcons,
            titleBarIconPosition: this.readerTitleBarIconPosition,
            readMenuFloatingIconLiquidGlass: this.readerReadMenuFloatingIconLiquidGlass,
            floatingIcons: this.readerFloatingIcons,
            titleBarCustomIcons: this.readerTitleBarCustomIcons,
            readMenuCustomIcons: this.readerReadMenuCustomIcons,
            showMenuIcon: this.readerShowMenuIcon,
            showReadTitleAddition: this.readerShowReadTitleAddition,
            menuAlpha: this.readerMenuAlpha,
            adaptSpecialStyle: this.readerAdaptSpecialStyle,
            onBrightnessAutoChange: (enabled: boolean) => this.setReaderBrightnessAuto(enabled),
            onReadBodyToLhChange: (enabled: boolean) => this.setReaderReadBodyToLh(enabled),
            onUseZhLayoutChange: (enabled: boolean) => this.setReaderUseZhLayout(enabled),
            onPaddingDisplayCutoutsChange: (enabled: boolean) => this.setReaderPaddingDisplayCutouts(enabled),
            onAdaptSpecialStyleChange: (enabled: boolean) => this.setReaderAdaptSpecialStyle(enabled),
            onReadMenuBottomCornerRadiusChange: (value: number) => this.setReaderReadMenuBottomCornerRadius(value),
            onReadMenuFloatingBottomBarChange: (enabled: boolean) => this.setReaderReadMenuFloatingBottomBar(enabled),
            onReadMenuBottomBarBlurModeChange: (value: number) => this.setReaderReadMenuBottomBarBlurMode(value),
            onReadMenuBottomBarBlurStyleChange: (value: number) => this.setReaderReadMenuBottomBarBlurStyle(value),
            onReadMenuBottomBarLiquidGlassButtonsChange: (enabled: boolean) => this.setReaderReadMenuBottomBarLiquidGlassButtons(enabled),
            onReadMenuBlurAlphaChange: (value: number) => this.setReaderReadMenuBlurAlpha(value),
            onReadMenuTopBarTitleCapsuleChange: (enabled: boolean) => this.setReaderReadMenuTopBarTitleCapsule(enabled),
            onTitleBarModeChange: (value: string) => this.setReaderTitleBarMode(value),
            onTitleBarCompactChange: (enabled: boolean) => this.setReaderTitleBarCompact(enabled),
            onTitleBarIconStyleChange: (value: number) => this.setReaderTitleBarIconStyle(value),
            onReadMenuTopBarBlurModeChange: (value: number) => this.setReaderReadMenuTopBarBlurMode(value),
            onReadMenuTopBarBlurStyleChange: (value: number) => this.setReaderReadMenuTopBarBlurStyle(value),
            onReadMenuTopBarLiquidGlassButtonsChange: (enabled: boolean) => this.setReaderReadMenuTopBarLiquidGlassButtons(enabled),
            onReadMenuTopBarMergeButtonsChange: (enabled: boolean) => this.setReaderReadMenuTopBarMergeButtons(enabled),
            onReadBarStyleChange: (value: number) => this.setReaderReadBarStyle(value),
            onReadMenuPaletteStyleChange: (value: string) => this.setReaderReadMenuPaletteStyle(value),
            onReadMenuColorModeChange: (value: number) => this.setReaderReadMenuColorMode(value),
            onReadMenuBgColorChange: (value: string) => this.setReaderReadMenuBgColor(value),
            onReadMenuBgColorNightChange: (value: string) => this.setReaderReadMenuBgColorNight(value),
            onReadMenuContainerColorChange: (value: string) => this.setReaderReadMenuContainerColor(value),
            onReadMenuContainerColorNightChange: (value: string) => this.setReaderReadMenuContainerColorNight(value),
            onReadMenuAccentColorChange: (value: string) => this.setReaderReadMenuAccentColor(value),
            onReadMenuAccentColorNightChange: (value: string) => this.setReaderReadMenuAccentColorNight(value),
            onReadMenuBorderWidthChange: (value: number) => this.setReaderReadMenuBorderWidth(value),
            onReadMenuBorderColorChange: (value: string) => this.setReaderReadMenuBorderColor(value),
            onReadMenuBorderColorNightChange: (value: string) => this.setReaderReadMenuBorderColorNight(value),
            onReadMenuBlurRadiusChange: (value: number) => this.setReaderReadMenuBlurRadius(value),
            onReadMenuTextColorChange: (value: string) => this.setReaderReadMenuTextColor(value),
            onReadMenuTextColorNightChange: (value: string) => this.setReaderReadMenuTextColorNight(value),
            onReadMenuBlurColorChange: (value: string) => this.setReaderReadMenuBlurColor(value),
            onReadMenuBlurColorNightChange: (value: string) => this.setReaderReadMenuBlurColorNight(value),
            onShowTitleBarIconsChange: (value: boolean) => this.setReaderShowTitleBarIcons(value),
            onTitleBarIconPositionChange: (value: number) => this.setReaderTitleBarIconPosition(value),
            onReadMenuFloatingIconLiquidGlassChange: (value: boolean) => this.setReaderReadMenuFloatingIconLiquidGlass(value),
            onFloatingIconsChange: (value: ReaderBottomActionConfig[]) => this.setReaderFloatingIcons(value),
            onTitleBarCustomIconsChange: (value: string) => this.setReaderTitleBarCustomIcons(value),
            onReadMenuCustomIconsChange: (value: string) => this.setReaderReadMenuCustomIcons(value),
            onShowMenuIconChange: (enabled: boolean) => this.setReaderShowMenuIcon(enabled),
            onShowReadTitleAdditionChange: (enabled: boolean) => this.setReaderShowReadTitleAddition(enabled),
            onMenuAlphaChange: (value: number) => this.setReaderMenuAlpha(value),
            onTextSelectMenuConfigChange: (value: string) => this.setReaderTextSelectMenuConfig(value),
            onReadingAnchorEnabledChange: (enabled: boolean) => this.setReaderReadingAnchorEnabled(enabled),
              onSwipeToAddBookmarkChange: (enabled: boolean) => this.setReaderSwipeToAddBookmark(enabled),
              onBookmarkBadgeSizeChange: (value: number) => this.setReaderBookmarkBadgeSize(value),
              onPickBookmarkBadgeImage: (): void => { this.pickReaderBookmarkBadgeImage(); },
              onResetBookmarkBadgeImage: (): void => this.resetReaderBookmarkBadgeImage(),
              onSelectTextChange: (enabled: boolean) => this.setReaderSelectText(enabled),
              onSliderVibratorChange: (enabled: boolean) => this.setReaderSliderVibrator(enabled),
              onSelectVibratorChange: (enabled: boolean) => this.setReaderSelectVibrator(enabled),
              onChineseConverterTypeChange: (value: number) => this.setReaderChineseConverterType(value),
              textColor: this.readerTextColor,
              textColorNight: this.readerTextColorNight,
              textAccentColor: this.readerTextAccentColor,
              textAccentColorNight: this.readerTextAccentColorNight,
              bgStr: this.readerBgStr,
              bgStrNight: this.readerBgStrNight,
              bgType: this.readerBgType,
              bgTypeNight: this.readerBgTypeNight,
              bgAlpha: this.readerBgAlpha,
              darkStatusIcon: this.readerDarkStatusIcon,
              darkStatusIconNight: this.readerDarkStatusIconNight,
              titleMode: this.readerTitleMode,
              titleSize: this.readerTitleSize,
              titleSizeRelative: this.readerTitleSizeRelative,
              titleTopSpacing: this.readerTitleTopSpacing,
              titleBottomSpacing: this.readerTitleBottomSpacing,
              titleColor: this.readerTitleColor,
              titleColorNight: this.readerTitleColorNight,
              titleBold: this.readerTitleBold,
              titleLineSpacingExtra: this.readerTitleLineSpacingExtra,
              titleLineSpacingSub: this.readerTitleLineSpacingSub,
              titleSegType: this.readerTitleSegType,
              titleSegScaling: this.readerTitleSegScaling,
              titleSegDistance: this.readerTitleSegDistance,
              titleSegFlag: this.readerTitleSegFlag,
              onTextColorChange: (value: string, night: boolean) => this.setReaderTextColor(value, night),
              onTextAccentColorChange: (value: string, night: boolean) => this.setReaderTextAccentColor(value, night),
              onBackgroundColorChange: (value: string, night: boolean) => this.setReaderBackgroundColor(value, night),
              onBackgroundImageChange: (path: string, night: boolean) => this.setReaderBackgroundImage(path, night),
              onBgAlphaChange: (value: number) => this.setReaderBgAlpha(value),
              onDarkStatusIconChange: (enabled: boolean, night: boolean) => this.setReaderDarkStatusIcon(enabled, night),
              onPickBackgroundImage: (night: boolean): void => { this.pickReaderBackgroundImage(night); },
              onTitleModeChange: (value: number) => this.setReaderTitleMode(value),
              onTitleSizeChange: (value: number) => this.setReaderTitleSize(value),
              onTitleSizeRelativeChange: (relative: boolean) => this.setReaderTitleSizeRelative(relative),
              onTitleSpacingChange: (top: number, bottom: number) => this.setReaderTitleSpacing(top, bottom),
              onTitleColorChange: (value: string, night: boolean) => this.setReaderTitleColor(value, night),
              onTitleBoldChange: (value: number) => this.setReaderTitleBold(value),
              onTitleLineSpacingChange: (extra: number, sub: number) => this.setReaderTitleLineSpacing(extra, sub),
              onTitleSegTypeChange: (value: number) => this.setReaderTitleSegType(value),
              onTitleSegScalingChange: (value: number) => this.setReaderTitleSegScaling(value),
              onTitleSegDistanceChange: (value: number) => this.setReaderTitleSegDistance(value),
              onTitleSegFlagChange: (value: string) => this.setReaderTitleSegFlag(value),
              onMaxLengthWithNoTocChange: (value: number) => this.setReaderMaxLengthWithNoToc(value),
            clickRegionActions: this.readerClickRegionActions,
            onClickRegionActionsChange: (actions: string[]) => this.setReaderClickRegionActions(actions),
            clickImageBehavior: this.readerClickImageBehavior,
            onClickImageBehaviorChange: (value: string) => this.setReaderClickImageBehavior(value),
            hideStatusBar: this.readerHideStatusBar,
            hideNavigationBar: this.readerHideNavigationBar,
            onHideStatusBarChange: (enabled: boolean) => this.setReaderHideStatusBar(enabled),
            onHideNavigationBarChange: (enabled: boolean) => this.setReaderHideNavigationBar(enabled),
            infoSettings: this.readerInfoSettings,
            onInfoSettingsChange: (settings: ReaderInfoSettings) => this.setReaderInfoSettings(settings),
            pageAnimationIndex: this.readerPageAnimation,
            animationSpeedIndex: this.readerAnimationSpeed,
            onBottomIconStyleChange: (style: number) => this.setReaderBottomIconStyle(style),
            onBottomItemsPerRowChange: (count: number) => this.setReaderBottomItemsPerRow(count),
            onBottomRowCountChange: (count: number) => this.setReaderBottomRowCount(count),
            onBottomActionsChange: (actions: ReaderBottomActionConfig[]) => this.setReaderBottomActions(actions),
            onTopActionsChange: (actions: ReaderBottomActionConfig[]) => this.setReaderTopActions(actions),
            onProgressBehaviorChange: (value: string) => this.setReaderProgressBehavior(value),
            readSliderMode: this.readerReadSliderMode,
            onReadSliderModeChange: (value: string) => this.setReaderReadSliderMode(value),
            pageTouchSlop: this.readerPageTouchSlop,
            onPageTouchSlopChange: (value: number) => this.setReaderPageTouchSlop(value),
            onPageAnimationChange: (animation: number) => this.setReaderPageAnimation(animation),
            onAnimationSpeedChange: (speed: number) => this.setReaderAnimationSpeed(speed),
            onBottomActionTextChange: (enabled: boolean) => this.setReaderBottomActionText(enabled),
            onShareLayoutChange: (enabled: boolean) => this.setReaderShareLayout(enabled),
            onToggleNightMode: () => this.toggleReaderNightMode(),
            onEyeProtectionToggle: () => this.toggleEyeProtection(),
            onEyeProtectionEnabledChange: (enabled: boolean) => this.setEyeProtectionEnabled(enabled),
            onEyeProtectionAutoNightChange: (enabled: boolean) => this.setEyeProtectionAutoNight(enabled),
            onEyeProtectionScheduleChange: (enabled: boolean) => this.setEyeProtectionSchedule(enabled),
            onEyeProtectionIntensityChange: (value: number) => this.setEyeProtectionIntensity(value),
            onEyeProtectionStartTimeChange: (value: string) => this.setEyeProtectionStartTime(value),
            onEyeProtectionEndTimeChange: (value: string) => this.setEyeProtectionEndTime(value),
            onUnavailableAction: (message: string) => this.showUnavailableAction(message),
            showQuickActions: this.showReaderQuickActions,
            asSheet: false,
            onBack: () => this.profileSubpage = this.profileSettingsReturn,
            onFontSizeChange: (fontSize: number) => this.setReaderFontSize(fontSize),
              onTextItalicChange: (enabled: boolean) => this.setReaderTextItalic(enabled),
              onTextBoldChange: (weight: number) => this.setReaderTextBold(weight),
              onTextShadowChange: (enabled: boolean) => this.setReaderTextShadow(enabled),
              onShadowRadiusChange: (value: number) => this.setReaderShadowRadius(value),
              onShadowDxChange: (value: number) => this.setReaderShadowDx(value),
              onShadowDyChange: (value: number) => this.setReaderShadowDy(value),
              onUnderlineChange: (enabled: boolean) => this.setReaderUnderline(enabled),
              onDottedLineChange: (enabled: boolean) => this.setReaderDottedLine(enabled),
              onTextShadowColorChange: (value: string, night: boolean) => this.setReaderTextShadowColor(value, night),
              onUnderlineColorChange: (value: string, night: boolean) => this.setReaderUnderlineColor(value, night),
              onUnderlineHeightChange: (value: number) => this.setReaderUnderlineHeight(value),
              onUnderlinePaddingChange: (value: number) => this.setReaderUnderlinePadding(value),
              onUnderlineExtendChange: (enabled: boolean) => this.setReaderUnderlineExtend(enabled),
              onDottedBaseChange: (value: number) => this.setReaderDottedBase(value),
              onDottedRatioChange: (value: number) => this.setReaderDottedRatio(value),
              onTextFontChange: (fontPath: string) => this.setReaderTextFont(fontPath),
              onTitleFontChange: (fontPath: string) => this.setReaderTitleFont(fontPath),
              onSystemTypefacesChange: (index: number) => this.setReaderSystemTypefaces(index),
              onTextFullJustifyChange: (enabled: boolean) => this.setReaderTextFullJustify(enabled),
              onTextBottomJustifyChange: (enabled: boolean) => this.setReaderTextBottomJustify(enabled),
            onParagraphSpacingChange: (value: number) => this.setReaderParagraphSpacing(value),
            onLineSpacingChange: (value: number) => this.setReaderLineSpacing(value),
            onLetterSpacingChange: (value: number) => this.setReaderLetterSpacing(value),
            onParagraphIndentCountChange: (count: number) => this.setReaderParagraphIndentCount(count),
            onPaperChange: (paperIndex: number) => this.setReaderPaperIndex(paperIndex),
            onAddBackgroundStyle: (): number => this.addReaderBackgroundStyle(),
            onUpdateBackgroundStyle: (index: number, name: string, dayColor: string, nightColor: string): void =>
              this.updateReaderBackgroundStyle(index, name, dayColor, nightColor),
            onRemoveBackgroundStyle: (index: number): void => this.removeReaderBackgroundStyle(index),
            onMoveBackgroundStyle: (from: number, to: number): void => this.moveReaderBackgroundStyle(from, to),
            onQuickActionsChange: (enabled: boolean) => this.setReaderQuickActions(enabled)
          })
        } else if (this.profileSubpage === ProfileRoute.APP_ALOUD_SETTINGS) {
          AppReadAloudSettingsPage({
            onBack: () => this.profileSubpage = this.profileSettingsReturn,
            onUnavailableAction: (message: string) => this.showUnavailableAction(message)
          })
        } else if (this.profileSubpage === ProfileRoute.APP_COVER_SETTINGS) {
          AppCoverSettingsPage({
            onBack: () => this.profileSubpage = this.profileSettingsReturn,
            onChange: (settings: CoverSettings) => {
              // 页面改一项就通知一次：书架与封面设置页同步，返回时无需再读盘
              this.coverSettings = settings;
              this.saveCoverSettings(settings);
            },
            onUnavailableAction: (message: string) => this.showUnavailableAction(message)
          })
        } else if (this.profileSubpage === ProfileRoute.APP_DOWNLOAD_CACHE_SETTINGS) {
          AppDownloadCacheSettingsPage({
            books: this.books,
            onBack: () => this.profileSubpage = this.profileSettingsReturn,
            onUnavailableAction: (message: string) => this.showUnavailableAction(message)
          })
        } else if (this.profileSubpage === ProfileRoute.APP_AI_SETTINGS) {
          AppAiSettingsPage({
            onBack: () => this.profileSubpage = this.profileSettingsReturn,
            onUnavailableAction: (message: string) => this.showUnavailableAction(message)
          })
        } else if (this.profileSubpage === ProfileRoute.APP_TRANSLATION_SETTINGS) {
          AppTranslationSettingsPage({
            onBack: () => this.profileSubpage = ProfileRoute.APP_SETTINGS,
            onOpenAiSettings: () => this.openSettingsCategory(ProfileRoute.APP_AI_SETTINGS)
          })
        } else if (this.profileSubpage === ProfileRoute.APP_PRIVACY_SETTINGS) {
          AppPrivacySettingsPage({
            onBack: () => this.profileSubpage = this.profileSettingsReturn,
            onUnavailableAction: (message: string) => this.showUnavailableAction(message)
          })
        } else if (this.profileSubpage === ProfileRoute.APP_BACKUP_SETTINGS) {
          AppBackupSettingsPage({
            onBack: () => this.profileSubpage = this.profileSettingsReturn,
            localBookCount: this.books.filter((book: Book) => BookRepository.isPersistableBook(book)).length,
            backupPreview: this.backupPreview,
            restoredEntries: this.restoredAndroidEntries,
            categoryOptions: this.backupCategoryOptions,
            backupIgnoreKeys: this.backupIgnoreKeys,
            restoreIgnoreKeys: this.restoreIgnoreKeys,
            statusMessage: this.backupStatusMessage,
            busy: this.backupBusy,
            webDavSettings: this.webDavSettings,
            webDavTesting: this.webDavTesting,
            webDavConfigured: isWebDavConfigured(this.webDavSettings),
            webDavBackupNames: this.webDavBackupNames,
            onCreateBackup: () => this.createLocalBackup(),
            onSelectRestore: () => this.selectLocalBackup(),
            onApplyRestore: () => this.restoreLocalBackup(),
            onCancelRestore: () => this.cancelLocalBackupRestore(),
            onToggleBackupIgnore: (key: string, ignored: boolean) => this.toggleBackupIgnore(key, ignored),
            onToggleRestoreIgnore: (key: string, ignored: boolean) => this.toggleRestoreIgnore(key, ignored),
            onUnavailableAction: (message: string) => this.showUnavailableAction(message),
            onWebDavSettingsChange: (settings: WebDavSettings) => this.saveWebDavSettings(settings),
            onTestWebDav: () => this.testWebDav(),
            onBackupToWebDav: () => this.backupToWebDav(),
            onRestoreFromWebDav: () => this.restoreFromWebDav()
          })
        } else if (this.profileSubpage === ProfileRoute.APP_LAB_SETTINGS) {
          AppLabSettingsPage({
            onBack: () => this.profileSubpage = this.profileSettingsReturn,
            onUnavailableAction: (message: string) => this.showUnavailableAction(message)
          })
        } else {
          ReaderSettingsPage({
            fontSize: this.readerFontSize,
        paragraphSpacing: this.readerParagraphSpacing,
        lineSpacing: this.readerLineSpacing,
        letterSpacing: this.readerLetterSpacing,
        paragraphIndent: this.readerParagraphIndent,
              textFont: this.readerTextFont,
              titleFont: this.readerTitleFont,
              systemTypefaces: this.readerSystemTypefaces,
              textItalic: this.readerTextItalic,
              textBold: this.readerTextBold,
              textShadow: this.readerTextShadow,
              shadowRadius: this.readerShadowRadius,
              shadowDx: this.readerShadowDx,
              shadowDy: this.readerShadowDy,
              underline: this.readerUnderline,
              dottedLine: this.readerDottedLine,
              textShadowColor: this.readerTextShadowColor,
              textShadowColorN: this.readerTextShadowColorN,
              underlineColor: this.readerUnderlineColor,
              underlineColorNight: this.readerUnderlineColorNight,
              underlineHeight: this.readerUnderlineHeight,
              underlinePadding: this.readerUnderlinePadding,
              underlineExtend: this.readerUnderlineExtend,
              dottedBase: this.readerDottedBase,
              dottedRatio: this.readerDottedRatio,
        textFullJustify: this.readerTextFullJustify,
        textBottomJustify: this.readerTextBottomJustify,
            paperIndex: this.paperIndex,
            backgroundStyles: this.backgroundStyles,
            shareLayout: this.shareReaderStyleLayout,
            readerNightMode: this.readerNightMode,
            eyeProtectionActive: this.isEyeProtectionActive(),
            eyeProtectionEnabled: this.eyeProtectionEnabled,
            eyeProtectionAutoNight: this.eyeProtectionAutoNight,
            eyeProtectionSchedule: this.eyeProtectionSchedule,
            eyeProtectionIntensity: this.eyeProtectionIntensity,
            eyeProtectionStartTime: this.eyeProtectionStartTime,
            eyeProtectionEndTime: this.eyeProtectionEndTime,
            showBottomActionText: this.showReaderBottomActionText,
            progressBehavior: this.readerProgressBehavior,
            paddingSettings: this.readerPaddingSettings,
            onPaddingSettingsChange: (settings: ReaderPaddingSettings) => this.setReaderPaddingSettings(settings),
            screenOrientation: this.readerScreenOrientation,
            onScreenOrientationChange: (orientation: string) => this.setReaderScreenOrientation(orientation),
            keepLight: this.readerKeepLight,
            onKeepLightChange: (value: string) => this.setReaderKeepLight(value),
            volumeKeyPage: this.readerVolumeKeyPage,
            onVolumeKeyPageChange: (enabled: boolean) => this.setReaderVolumeKeyPage(enabled),
            keyPageOnLongPress: this.readerKeyPageOnLongPress,
            onKeyPageOnLongPressChange: (enabled: boolean) => this.setReaderKeyPageOnLongPress(enabled),
            noAnimScrollPage: this.readerNoAnimScrollPage,
            prevKeys: this.readerPrevKeys,
            nextKeys: this.readerNextKeys,
            mouseWheelPage: this.readerMouseWheelPage,
            expandTextMenu: this.readerExpandTextMenu,
            showSelectMenuIcon: this.readerShowSelectMenuIcon,
            textSelectMenuConfig: this.readerTextSelectMenuConfig,
            doubleHorizontalPage: this.readerDoubleHorizontalPage,
            autoSuggestDayNight: this.readerAutoSuggestDayNight,
            disableReturnKey: this.readerDisableReturnKey,
            readingAnchorEnabled: this.readerReadingAnchorEnabled,
        swipeToAddBookmark: this.readerSwipeToAddBookmark,
        bookmarkBadgeSize: this.readerBookmarkBadgeSize,
        bookmarkBadgeImage: this.readerBookmarkBadgeImage,
        selectText: this.readerSelectText,
        sliderVibrator: this.readerSliderVibrator,
        selectVibrator: this.readerSelectVibrator,
        chineseConverterType: this.readerChineseConverterType,
        maxLengthWithNoToc: this.readerMaxLengthWithNoToc,
            onNoAnimScrollPageChange: (enabled: boolean) => this.setReaderNoAnimScrollPage(enabled),
            onPrevKeysChange: (value: string) => this.setReaderPrevKeys(value),
            onNextKeysChange: (value: string) => this.setReaderNextKeys(value),
            onMouseWheelPageChange: (enabled: boolean) => this.setReaderMouseWheelPage(enabled),
            onExpandTextMenuChange: (enabled: boolean) => this.setReaderExpandTextMenu(enabled),
            onShowSelectMenuIconChange: (enabled: boolean) => this.setReaderShowSelectMenuIcon(enabled),
            onDoubleHorizontalPageChange: (value: string) => this.setReaderDoubleHorizontalPage(value),
            onAutoSuggestDayNightChange: (enabled: boolean) => this.setReaderAutoSuggestDayNight(enabled),
            onDisableReturnKeyChange: (enabled: boolean) => this.setReaderDisableReturnKey(enabled),
            readBrightness: this.readerReadBrightness,
            onReadBrightnessChange: (value: number) => this.setReaderReadBrightness(value),
            showBrightnessView: this.readerShowBrightnessView,
            onShowBrightnessViewChange: (value: string) => this.setReaderShowBrightnessView(value),
            brightnessVwPos: this.readerBrightnessVwPos,
            onBrightnessVwPosChange: (value: string) => this.setReaderBrightnessVwPos(value),
            brightnessAuto: this.readerBrightnessAuto,
            readBodyToLh: this.readerReadBodyToLh,
            useZhLayout: this.readerUseZhLayout,
            paddingDisplayCutouts: this.readerPaddingDisplayCutouts,
            readMenuBottomCornerRadius: this.readerReadMenuBottomCornerRadius,
            readMenuFloatingBottomBar: this.readerReadMenuFloatingBottomBar,
            readMenuBottomBarBlurMode: this.readerReadMenuBottomBarBlurMode,
            readMenuBottomBarBlurStyle: this.readerReadMenuBottomBarBlurStyle,
            readMenuBottomBarLiquidGlassButtons: this.readerReadMenuBottomBarLiquidGlassButtons,
            readMenuBlurAlpha: this.readerReadMenuBlurAlpha,
            readMenuTopBarTitleCapsule: this.readerReadMenuTopBarTitleCapsule,
            titleBarMode: this.readerTitleBarMode,
            titleBarCompact: this.readerTitleBarCompact,
            titleBarIconStyle: this.readerTitleBarIconStyle,
            readMenuTopBarBlurMode: this.readerReadMenuTopBarBlurMode,
            readMenuTopBarBlurStyle: this.readerReadMenuTopBarBlurStyle,
            readMenuTopBarLiquidGlassButtons: this.readerReadMenuTopBarLiquidGlassButtons,
            readMenuTopBarMergeButtons: this.readerReadMenuTopBarMergeButtons,
            readBarStyle: this.readerReadBarStyle,
            readMenuPaletteStyle: this.readerMenuPaletteStyle,
            readMenuColorMode: this.readerMenuColorMode,
            readMenuBgColor: this.readerMenuBgColor,
            readMenuBgColorNight: this.readerMenuBgColorNight,
            readMenuContainerColor: this.readerMenuContainerColor,
            readMenuContainerColorNight: this.readerMenuContainerColorNight,
            readMenuAccentColor: this.readerMenuAccentColor,
            readMenuAccentColorNight: this.readerMenuAccentColorNight,
            readMenuBorderWidth: this.readerMenuBorderWidth,
            readMenuBorderColor: this.readerMenuBorderColor,
            readMenuBorderColorNight: this.readerMenuBorderColorNight,
            readMenuBlurRadius: this.readerMenuBlurRadius,
            readMenuTextColor: this.readerMenuTextColor,
            readMenuTextColorNight: this.readerMenuTextColorNight,
            readMenuBlurColor: this.readerMenuBlurColor,
            readMenuBlurColorNight: this.readerMenuBlurColorNight,
            showTitleBarIcons: this.readerShowTitleBarIcons,
            titleBarIconPosition: this.readerTitleBarIconPosition,
            readMenuFloatingIconLiquidGlass: this.readerReadMenuFloatingIconLiquidGlass,
            floatingIcons: this.readerFloatingIcons,
            titleBarCustomIcons: this.readerTitleBarCustomIcons,
            readMenuCustomIcons: this.readerReadMenuCustomIcons,
            showMenuIcon: this.readerShowMenuIcon,
            showReadTitleAddition: this.readerShowReadTitleAddition,
            menuAlpha: this.readerMenuAlpha,
            adaptSpecialStyle: this.readerAdaptSpecialStyle,
            onBrightnessAutoChange: (enabled: boolean) => this.setReaderBrightnessAuto(enabled),
            onReadBodyToLhChange: (enabled: boolean) => this.setReaderReadBodyToLh(enabled),
            onUseZhLayoutChange: (enabled: boolean) => this.setReaderUseZhLayout(enabled),
            onPaddingDisplayCutoutsChange: (enabled: boolean) => this.setReaderPaddingDisplayCutouts(enabled),
            onAdaptSpecialStyleChange: (enabled: boolean) => this.setReaderAdaptSpecialStyle(enabled),
            onReadMenuBottomCornerRadiusChange: (value: number) => this.setReaderReadMenuBottomCornerRadius(value),
            onReadMenuFloatingBottomBarChange: (enabled: boolean) => this.setReaderReadMenuFloatingBottomBar(enabled),
            onReadMenuBottomBarBlurModeChange: (value: number) => this.setReaderReadMenuBottomBarBlurMode(value),
            onReadMenuBottomBarBlurStyleChange: (value: number) => this.setReaderReadMenuBottomBarBlurStyle(value),
            onReadMenuBottomBarLiquidGlassButtonsChange: (enabled: boolean) => this.setReaderReadMenuBottomBarLiquidGlassButtons(enabled),
            onReadMenuBlurAlphaChange: (value: number) => this.setReaderReadMenuBlurAlpha(value),
            onReadMenuTopBarTitleCapsuleChange: (enabled: boolean) => this.setReaderReadMenuTopBarTitleCapsule(enabled),
            onTitleBarModeChange: (value: string) => this.setReaderTitleBarMode(value),
            onTitleBarCompactChange: (enabled: boolean) => this.setReaderTitleBarCompact(enabled),
            onTitleBarIconStyleChange: (value: number) => this.setReaderTitleBarIconStyle(value),
            onReadMenuTopBarBlurModeChange: (value: number) => this.setReaderReadMenuTopBarBlurMode(value),
            onReadMenuTopBarBlurStyleChange: (value: number) => this.setReaderReadMenuTopBarBlurStyle(value),
            onReadMenuTopBarLiquidGlassButtonsChange: (enabled: boolean) => this.setReaderReadMenuTopBarLiquidGlassButtons(enabled),
            onReadMenuTopBarMergeButtonsChange: (enabled: boolean) => this.setReaderReadMenuTopBarMergeButtons(enabled),
            onReadBarStyleChange: (value: number) => this.setReaderReadBarStyle(value),
            onReadMenuPaletteStyleChange: (value: string) => this.setReaderReadMenuPaletteStyle(value),
            onReadMenuColorModeChange: (value: number) => this.setReaderReadMenuColorMode(value),
            onReadMenuBgColorChange: (value: string) => this.setReaderReadMenuBgColor(value),
            onReadMenuBgColorNightChange: (value: string) => this.setReaderReadMenuBgColorNight(value),
            onReadMenuContainerColorChange: (value: string) => this.setReaderReadMenuContainerColor(value),
            onReadMenuContainerColorNightChange: (value: string) => this.setReaderReadMenuContainerColorNight(value),
            onReadMenuAccentColorChange: (value: string) => this.setReaderReadMenuAccentColor(value),
            onReadMenuAccentColorNightChange: (value: string) => this.setReaderReadMenuAccentColorNight(value),
            onReadMenuBorderWidthChange: (value: number) => this.setReaderReadMenuBorderWidth(value),
            onReadMenuBorderColorChange: (value: string) => this.setReaderReadMenuBorderColor(value),
            onReadMenuBorderColorNightChange: (value: string) => this.setReaderReadMenuBorderColorNight(value),
            onReadMenuBlurRadiusChange: (value: number) => this.setReaderReadMenuBlurRadius(value),
            onReadMenuTextColorChange: (value: string) => this.setReaderReadMenuTextColor(value),
            onReadMenuTextColorNightChange: (value: string) => this.setReaderReadMenuTextColorNight(value),
            onReadMenuBlurColorChange: (value: string) => this.setReaderReadMenuBlurColor(value),
            onReadMenuBlurColorNightChange: (value: string) => this.setReaderReadMenuBlurColorNight(value),
            onShowTitleBarIconsChange: (value: boolean) => this.setReaderShowTitleBarIcons(value),
            onTitleBarIconPositionChange: (value: number) => this.setReaderTitleBarIconPosition(value),
            onReadMenuFloatingIconLiquidGlassChange: (value: boolean) => this.setReaderReadMenuFloatingIconLiquidGlass(value),
            onFloatingIconsChange: (value: ReaderBottomActionConfig[]) => this.setReaderFloatingIcons(value),
            onTitleBarCustomIconsChange: (value: string) => this.setReaderTitleBarCustomIcons(value),
            onReadMenuCustomIconsChange: (value: string) => this.setReaderReadMenuCustomIcons(value),
            onShowMenuIconChange: (enabled: boolean) => this.setReaderShowMenuIcon(enabled),
            onShowReadTitleAdditionChange: (enabled: boolean) => this.setReaderShowReadTitleAddition(enabled),
            onMenuAlphaChange: (value: number) => this.setReaderMenuAlpha(value),
            onTextSelectMenuConfigChange: (value: string) => this.setReaderTextSelectMenuConfig(value),
            onReadingAnchorEnabledChange: (enabled: boolean) => this.setReaderReadingAnchorEnabled(enabled),
              onSwipeToAddBookmarkChange: (enabled: boolean) => this.setReaderSwipeToAddBookmark(enabled),
              onBookmarkBadgeSizeChange: (value: number) => this.setReaderBookmarkBadgeSize(value),
              onPickBookmarkBadgeImage: (): void => { this.pickReaderBookmarkBadgeImage(); },
              onResetBookmarkBadgeImage: (): void => this.resetReaderBookmarkBadgeImage(),
              onSelectTextChange: (enabled: boolean) => this.setReaderSelectText(enabled),
              onSliderVibratorChange: (enabled: boolean) => this.setReaderSliderVibrator(enabled),
              onSelectVibratorChange: (enabled: boolean) => this.setReaderSelectVibrator(enabled),
              onChineseConverterTypeChange: (value: number) => this.setReaderChineseConverterType(value),
              textColor: this.readerTextColor,
              textColorNight: this.readerTextColorNight,
              textAccentColor: this.readerTextAccentColor,
              textAccentColorNight: this.readerTextAccentColorNight,
              bgStr: this.readerBgStr,
              bgStrNight: this.readerBgStrNight,
              bgType: this.readerBgType,
              bgTypeNight: this.readerBgTypeNight,
              bgAlpha: this.readerBgAlpha,
              darkStatusIcon: this.readerDarkStatusIcon,
              darkStatusIconNight: this.readerDarkStatusIconNight,
              titleMode: this.readerTitleMode,
              titleSize: this.readerTitleSize,
              titleSizeRelative: this.readerTitleSizeRelative,
              titleTopSpacing: this.readerTitleTopSpacing,
              titleBottomSpacing: this.readerTitleBottomSpacing,
              titleColor: this.readerTitleColor,
              titleColorNight: this.readerTitleColorNight,
              titleBold: this.readerTitleBold,
              titleLineSpacingExtra: this.readerTitleLineSpacingExtra,
              titleLineSpacingSub: this.readerTitleLineSpacingSub,
              titleSegType: this.readerTitleSegType,
              titleSegScaling: this.readerTitleSegScaling,
              titleSegDistance: this.readerTitleSegDistance,
              titleSegFlag: this.readerTitleSegFlag,
              onTextColorChange: (value: string, night: boolean) => this.setReaderTextColor(value, night),
              onTextAccentColorChange: (value: string, night: boolean) => this.setReaderTextAccentColor(value, night),
              onBackgroundColorChange: (value: string, night: boolean) => this.setReaderBackgroundColor(value, night),
              onBackgroundImageChange: (path: string, night: boolean) => this.setReaderBackgroundImage(path, night),
              onBgAlphaChange: (value: number) => this.setReaderBgAlpha(value),
              onDarkStatusIconChange: (enabled: boolean, night: boolean) => this.setReaderDarkStatusIcon(enabled, night),
              onPickBackgroundImage: (night: boolean): void => { this.pickReaderBackgroundImage(night); },
              onTitleModeChange: (value: number) => this.setReaderTitleMode(value),
              onTitleSizeChange: (value: number) => this.setReaderTitleSize(value),
              onTitleSizeRelativeChange: (relative: boolean) => this.setReaderTitleSizeRelative(relative),
              onTitleSpacingChange: (top: number, bottom: number) => this.setReaderTitleSpacing(top, bottom),
              onTitleColorChange: (value: string, night: boolean) => this.setReaderTitleColor(value, night),
              onTitleBoldChange: (value: number) => this.setReaderTitleBold(value),
              onTitleLineSpacingChange: (extra: number, sub: number) => this.setReaderTitleLineSpacing(extra, sub),
              onTitleSegTypeChange: (value: number) => this.setReaderTitleSegType(value),
              onTitleSegScalingChange: (value: number) => this.setReaderTitleSegScaling(value),
              onTitleSegDistanceChange: (value: number) => this.setReaderTitleSegDistance(value),
              onTitleSegFlagChange: (value: string) => this.setReaderTitleSegFlag(value),
              onMaxLengthWithNoTocChange: (value: number) => this.setReaderMaxLengthWithNoToc(value),
            clickRegionActions: this.readerClickRegionActions,
            onClickRegionActionsChange: (actions: string[]) => this.setReaderClickRegionActions(actions),
            clickImageBehavior: this.readerClickImageBehavior,
            onClickImageBehaviorChange: (value: string) => this.setReaderClickImageBehavior(value),
            infoSettings: this.readerInfoSettings,
            hideStatusBar: this.readerHideStatusBar,
            hideNavigationBar: this.readerHideNavigationBar,
            onHideStatusBarChange: (enabled: boolean) => this.setReaderHideStatusBar(enabled),
            onHideNavigationBarChange: (enabled: boolean) => this.setReaderHideNavigationBar(enabled),
            onInfoSettingsChange: (settings: ReaderInfoSettings) => this.setReaderInfoSettings(settings),
            pageAnimationIndex: this.readerPageAnimation,
            animationSpeedIndex: this.readerAnimationSpeed,
            onProgressBehaviorChange: (value: string) => this.setReaderProgressBehavior(value),
            readSliderMode: this.readerReadSliderMode,
            onReadSliderModeChange: (value: string) => this.setReaderReadSliderMode(value),
            pageTouchSlop: this.readerPageTouchSlop,
            onPageTouchSlopChange: (value: number) => this.setReaderPageTouchSlop(value),
            onPageAnimationChange: (animation: number) => this.setReaderPageAnimation(animation),
            onAnimationSpeedChange: (speed: number) => this.setReaderAnimationSpeed(speed),
            onBottomActionTextChange: (enabled: boolean) => this.setReaderBottomActionText(enabled),
            onShareLayoutChange: (enabled: boolean) => this.setReaderShareLayout(enabled),
            onToggleNightMode: () => this.toggleReaderNightMode(),
            onEyeProtectionToggle: () => this.toggleEyeProtection(),
            onEyeProtectionEnabledChange: (enabled: boolean) => this.setEyeProtectionEnabled(enabled),
            onEyeProtectionAutoNightChange: (enabled: boolean) => this.setEyeProtectionAutoNight(enabled),
            onEyeProtectionScheduleChange: (enabled: boolean) => this.setEyeProtectionSchedule(enabled),
            onEyeProtectionIntensityChange: (value: number) => this.setEyeProtectionIntensity(value),
            onEyeProtectionStartTimeChange: (value: string) => this.setEyeProtectionStartTime(value),
            onEyeProtectionEndTimeChange: (value: string) => this.setEyeProtectionEndTime(value),
            onUnavailableAction: (message: string) => this.showUnavailableAction(message),
            showQuickActions: this.showReaderQuickActions,
            asSheet: false,
            onBack: () => this.route = this.profileDetailReturnRoute,
            onFontSizeChange: (fontSize: number) => this.setReaderFontSize(fontSize),
              onTextItalicChange: (enabled: boolean) => this.setReaderTextItalic(enabled),
              onTextBoldChange: (weight: number) => this.setReaderTextBold(weight),
              onTextShadowChange: (enabled: boolean) => this.setReaderTextShadow(enabled),
              onShadowRadiusChange: (value: number) => this.setReaderShadowRadius(value),
              onShadowDxChange: (value: number) => this.setReaderShadowDx(value),
              onShadowDyChange: (value: number) => this.setReaderShadowDy(value),
              onUnderlineChange: (enabled: boolean) => this.setReaderUnderline(enabled),
              onDottedLineChange: (enabled: boolean) => this.setReaderDottedLine(enabled),
              onTextShadowColorChange: (value: string, night: boolean) => this.setReaderTextShadowColor(value, night),
              onUnderlineColorChange: (value: string, night: boolean) => this.setReaderUnderlineColor(value, night),
              onUnderlineHeightChange: (value: number) => this.setReaderUnderlineHeight(value),
              onUnderlinePaddingChange: (value: number) => this.setReaderUnderlinePadding(value),
              onUnderlineExtendChange: (enabled: boolean) => this.setReaderUnderlineExtend(enabled),
              onDottedBaseChange: (value: number) => this.setReaderDottedBase(value),
              onDottedRatioChange: (value: number) => this.setReaderDottedRatio(value),
              onTextFontChange: (fontPath: string) => this.setReaderTextFont(fontPath),
              onTitleFontChange: (fontPath: string) => this.setReaderTitleFont(fontPath),
              onSystemTypefacesChange: (index: number) => this.setReaderSystemTypefaces(index),
              onTextFullJustifyChange: (enabled: boolean) => this.setReaderTextFullJustify(enabled),
              onTextBottomJustifyChange: (enabled: boolean) => this.setReaderTextBottomJustify(enabled),
            onParagraphSpacingChange: (value: number) => this.setReaderParagraphSpacing(value),
            onLineSpacingChange: (value: number) => this.setReaderLineSpacing(value),
            onLetterSpacingChange: (value: number) => this.setReaderLetterSpacing(value),
            onParagraphIndentCountChange: (count: number) => this.setReaderParagraphIndentCount(count),
            onPaperChange: (paperIndex: number) => this.setReaderPaperIndex(paperIndex),
            onAddBackgroundStyle: (): number => this.addReaderBackgroundStyle(),
            onUpdateBackgroundStyle: (index: number, name: string, dayColor: string, nightColor: string): void =>
              this.updateReaderBackgroundStyle(index, name, dayColor, nightColor),
            onRemoveBackgroundStyle: (index: number): void => this.removeReaderBackgroundStyle(index),
            onMoveBackgroundStyle: (from: number, to: number): void => this.moveReaderBackgroundStyle(from, to),
            onQuickActionsChange: (enabled: boolean) => this.setReaderQuickActions(enabled)
          })
        }
        } else {
        ReaderSettingsPage({
          fontSize: this.readerFontSize,
        paragraphSpacing: this.readerParagraphSpacing,
        lineSpacing: this.readerLineSpacing,
        letterSpacing: this.readerLetterSpacing,
        paragraphIndent: this.readerParagraphIndent,
              textFont: this.readerTextFont,
              titleFont: this.readerTitleFont,
              systemTypefaces: this.readerSystemTypefaces,
              textItalic: this.readerTextItalic,
              textBold: this.readerTextBold,
              textShadow: this.readerTextShadow,
              shadowRadius: this.readerShadowRadius,
              shadowDx: this.readerShadowDx,
              shadowDy: this.readerShadowDy,
              underline: this.readerUnderline,
              dottedLine: this.readerDottedLine,
              textShadowColor: this.readerTextShadowColor,
              textShadowColorN: this.readerTextShadowColorN,
              underlineColor: this.readerUnderlineColor,
              underlineColorNight: this.readerUnderlineColorNight,
              underlineHeight: this.readerUnderlineHeight,
              underlinePadding: this.readerUnderlinePadding,
              underlineExtend: this.readerUnderlineExtend,
              dottedBase: this.readerDottedBase,
              dottedRatio: this.readerDottedRatio,
        textFullJustify: this.readerTextFullJustify,
        textBottomJustify: this.readerTextBottomJustify,
          paperIndex: this.paperIndex,
          backgroundStyles: this.backgroundStyles,
          shareLayout: this.shareReaderStyleLayout,
          readerNightMode: this.readerNightMode,
          eyeProtectionActive: this.isEyeProtectionActive(),
          eyeProtectionEnabled: this.eyeProtectionEnabled,
          eyeProtectionAutoNight: this.eyeProtectionAutoNight,
          eyeProtectionSchedule: this.eyeProtectionSchedule,
          eyeProtectionIntensity: this.eyeProtectionIntensity,
          eyeProtectionStartTime: this.eyeProtectionStartTime,
          eyeProtectionEndTime: this.eyeProtectionEndTime,
          showBottomActionText: this.showReaderBottomActionText,
          progressBehavior: this.readerProgressBehavior,
          paddingSettings: this.readerPaddingSettings,
          onPaddingSettingsChange: (settings: ReaderPaddingSettings) => this.setReaderPaddingSettings(settings),
          screenOrientation: this.readerScreenOrientation,
          onScreenOrientationChange: (orientation: string) => this.setReaderScreenOrientation(orientation),
          keepLight: this.readerKeepLight,
          onKeepLightChange: (value: string) => this.setReaderKeepLight(value),
          volumeKeyPage: this.readerVolumeKeyPage,
          onVolumeKeyPageChange: (enabled: boolean) => this.setReaderVolumeKeyPage(enabled),
          keyPageOnLongPress: this.readerKeyPageOnLongPress,
          onKeyPageOnLongPressChange: (enabled: boolean) => this.setReaderKeyPageOnLongPress(enabled),
          noAnimScrollPage: this.readerNoAnimScrollPage,
          prevKeys: this.readerPrevKeys,
          nextKeys: this.readerNextKeys,
          mouseWheelPage: this.readerMouseWheelPage,
          expandTextMenu: this.readerExpandTextMenu,
          showSelectMenuIcon: this.readerShowSelectMenuIcon,
          textSelectMenuConfig: this.readerTextSelectMenuConfig,
          doubleHorizontalPage: this.readerDoubleHorizontalPage,
          autoSuggestDayNight: this.readerAutoSuggestDayNight,
          disableReturnKey: this.readerDisableReturnKey,
          readingAnchorEnabled: this.readerReadingAnchorEnabled,
        swipeToAddBookmark: this.readerSwipeToAddBookmark,
        bookmarkBadgeSize: this.readerBookmarkBadgeSize,
        bookmarkBadgeImage: this.readerBookmarkBadgeImage,
        selectText: this.readerSelectText,
        sliderVibrator: this.readerSliderVibrator,
        selectVibrator: this.readerSelectVibrator,
        chineseConverterType: this.readerChineseConverterType,
        maxLengthWithNoToc: this.readerMaxLengthWithNoToc,
          onNoAnimScrollPageChange: (enabled: boolean) => this.setReaderNoAnimScrollPage(enabled),
          onPrevKeysChange: (value: string) => this.setReaderPrevKeys(value),
          onNextKeysChange: (value: string) => this.setReaderNextKeys(value),
          onMouseWheelPageChange: (enabled: boolean) => this.setReaderMouseWheelPage(enabled),
          onExpandTextMenuChange: (enabled: boolean) => this.setReaderExpandTextMenu(enabled),
          onShowSelectMenuIconChange: (enabled: boolean) => this.setReaderShowSelectMenuIcon(enabled),
          onDoubleHorizontalPageChange: (value: string) => this.setReaderDoubleHorizontalPage(value),
          onAutoSuggestDayNightChange: (enabled: boolean) => this.setReaderAutoSuggestDayNight(enabled),
          onDisableReturnKeyChange: (enabled: boolean) => this.setReaderDisableReturnKey(enabled),
          readBrightness: this.readerReadBrightness,
          onReadBrightnessChange: (value: number) => this.setReaderReadBrightness(value),
          showBrightnessView: this.readerShowBrightnessView,
          onShowBrightnessViewChange: (value: string) => this.setReaderShowBrightnessView(value),
          brightnessVwPos: this.readerBrightnessVwPos,
          onBrightnessVwPosChange: (value: string) => this.setReaderBrightnessVwPos(value),
          brightnessAuto: this.readerBrightnessAuto,
          readBodyToLh: this.readerReadBodyToLh,
          useZhLayout: this.readerUseZhLayout,
          paddingDisplayCutouts: this.readerPaddingDisplayCutouts,
          readMenuBottomCornerRadius: this.readerReadMenuBottomCornerRadius,
          readMenuFloatingBottomBar: this.readerReadMenuFloatingBottomBar,
          readMenuBottomBarBlurMode: this.readerReadMenuBottomBarBlurMode,
          readMenuBottomBarBlurStyle: this.readerReadMenuBottomBarBlurStyle,
          readMenuBottomBarLiquidGlassButtons: this.readerReadMenuBottomBarLiquidGlassButtons,
          readMenuBlurAlpha: this.readerReadMenuBlurAlpha,
          readMenuTopBarTitleCapsule: this.readerReadMenuTopBarTitleCapsule,
          titleBarMode: this.readerTitleBarMode,
          titleBarCompact: this.readerTitleBarCompact,
          titleBarIconStyle: this.readerTitleBarIconStyle,
          readMenuTopBarBlurMode: this.readerReadMenuTopBarBlurMode,
          readMenuTopBarBlurStyle: this.readerReadMenuTopBarBlurStyle,
          readMenuTopBarLiquidGlassButtons: this.readerReadMenuTopBarLiquidGlassButtons,
          readMenuTopBarMergeButtons: this.readerReadMenuTopBarMergeButtons,
          readBarStyle: this.readerReadBarStyle,
          readMenuPaletteStyle: this.readerMenuPaletteStyle,
          readMenuColorMode: this.readerMenuColorMode,
          readMenuBgColor: this.readerMenuBgColor,
          readMenuBgColorNight: this.readerMenuBgColorNight,
          readMenuContainerColor: this.readerMenuContainerColor,
          readMenuContainerColorNight: this.readerMenuContainerColorNight,
          readMenuAccentColor: this.readerMenuAccentColor,
          readMenuAccentColorNight: this.readerMenuAccentColorNight,
          readMenuBorderWidth: this.readerMenuBorderWidth,
          readMenuBorderColor: this.readerMenuBorderColor,
          readMenuBorderColorNight: this.readerMenuBorderColorNight,
          readMenuBlurRadius: this.readerMenuBlurRadius,
          readMenuTextColor: this.readerMenuTextColor,
          readMenuTextColorNight: this.readerMenuTextColorNight,
          readMenuBlurColor: this.readerMenuBlurColor,
          readMenuBlurColorNight: this.readerMenuBlurColorNight,
          showTitleBarIcons: this.readerShowTitleBarIcons,
          titleBarIconPosition: this.readerTitleBarIconPosition,
          readMenuFloatingIconLiquidGlass: this.readerReadMenuFloatingIconLiquidGlass,
          floatingIcons: this.readerFloatingIcons,
          titleBarCustomIcons: this.readerTitleBarCustomIcons,
          readMenuCustomIcons: this.readerReadMenuCustomIcons,
          showMenuIcon: this.readerShowMenuIcon,
          showReadTitleAddition: this.readerShowReadTitleAddition,
          menuAlpha: this.readerMenuAlpha,
          adaptSpecialStyle: this.readerAdaptSpecialStyle,
          onBrightnessAutoChange: (enabled: boolean) => this.setReaderBrightnessAuto(enabled),
          onReadBodyToLhChange: (enabled: boolean) => this.setReaderReadBodyToLh(enabled),
          onUseZhLayoutChange: (enabled: boolean) => this.setReaderUseZhLayout(enabled),
          onPaddingDisplayCutoutsChange: (enabled: boolean) => this.setReaderPaddingDisplayCutouts(enabled),
          onAdaptSpecialStyleChange: (enabled: boolean) => this.setReaderAdaptSpecialStyle(enabled),
          onReadMenuBottomCornerRadiusChange: (value: number) => this.setReaderReadMenuBottomCornerRadius(value),
          onReadMenuFloatingBottomBarChange: (enabled: boolean) => this.setReaderReadMenuFloatingBottomBar(enabled),
          onReadMenuBottomBarBlurModeChange: (value: number) => this.setReaderReadMenuBottomBarBlurMode(value),
          onReadMenuBottomBarBlurStyleChange: (value: number) => this.setReaderReadMenuBottomBarBlurStyle(value),
          onReadMenuBottomBarLiquidGlassButtonsChange: (enabled: boolean) => this.setReaderReadMenuBottomBarLiquidGlassButtons(enabled),
          onReadMenuBlurAlphaChange: (value: number) => this.setReaderReadMenuBlurAlpha(value),
          onReadMenuTopBarTitleCapsuleChange: (enabled: boolean) => this.setReaderReadMenuTopBarTitleCapsule(enabled),
          onTitleBarModeChange: (value: string) => this.setReaderTitleBarMode(value),
          onTitleBarCompactChange: (enabled: boolean) => this.setReaderTitleBarCompact(enabled),
          onTitleBarIconStyleChange: (value: number) => this.setReaderTitleBarIconStyle(value),
          onReadMenuTopBarBlurModeChange: (value: number) => this.setReaderReadMenuTopBarBlurMode(value),
          onReadMenuTopBarBlurStyleChange: (value: number) => this.setReaderReadMenuTopBarBlurStyle(value),
          onReadMenuTopBarLiquidGlassButtonsChange: (enabled: boolean) => this.setReaderReadMenuTopBarLiquidGlassButtons(enabled),
          onReadMenuTopBarMergeButtonsChange: (enabled: boolean) => this.setReaderReadMenuTopBarMergeButtons(enabled),
          onReadBarStyleChange: (value: number) => this.setReaderReadBarStyle(value),
          onReadMenuPaletteStyleChange: (value: string) => this.setReaderReadMenuPaletteStyle(value),
          onReadMenuColorModeChange: (value: number) => this.setReaderReadMenuColorMode(value),
          onReadMenuBgColorChange: (value: string) => this.setReaderReadMenuBgColor(value),
          onReadMenuBgColorNightChange: (value: string) => this.setReaderReadMenuBgColorNight(value),
          onReadMenuContainerColorChange: (value: string) => this.setReaderReadMenuContainerColor(value),
          onReadMenuContainerColorNightChange: (value: string) => this.setReaderReadMenuContainerColorNight(value),
          onReadMenuAccentColorChange: (value: string) => this.setReaderReadMenuAccentColor(value),
          onReadMenuAccentColorNightChange: (value: string) => this.setReaderReadMenuAccentColorNight(value),
          onReadMenuBorderWidthChange: (value: number) => this.setReaderReadMenuBorderWidth(value),
          onReadMenuBorderColorChange: (value: string) => this.setReaderReadMenuBorderColor(value),
          onReadMenuBorderColorNightChange: (value: string) => this.setReaderReadMenuBorderColorNight(value),
          onReadMenuBlurRadiusChange: (value: number) => this.setReaderReadMenuBlurRadius(value),
          onReadMenuTextColorChange: (value: string) => this.setReaderReadMenuTextColor(value),
          onReadMenuTextColorNightChange: (value: string) => this.setReaderReadMenuTextColorNight(value),
          onReadMenuBlurColorChange: (value: string) => this.setReaderReadMenuBlurColor(value),
          onReadMenuBlurColorNightChange: (value: string) => this.setReaderReadMenuBlurColorNight(value),
          onShowTitleBarIconsChange: (value: boolean) => this.setReaderShowTitleBarIcons(value),
          onTitleBarIconPositionChange: (value: number) => this.setReaderTitleBarIconPosition(value),
          onReadMenuFloatingIconLiquidGlassChange: (value: boolean) => this.setReaderReadMenuFloatingIconLiquidGlass(value),
          onFloatingIconsChange: (value: ReaderBottomActionConfig[]) => this.setReaderFloatingIcons(value),
          onTitleBarCustomIconsChange: (value: string) => this.setReaderTitleBarCustomIcons(value),
          onReadMenuCustomIconsChange: (value: string) => this.setReaderReadMenuCustomIcons(value),
          onShowMenuIconChange: (enabled: boolean) => this.setReaderShowMenuIcon(enabled),
          onShowReadTitleAdditionChange: (enabled: boolean) => this.setReaderShowReadTitleAddition(enabled),
          onMenuAlphaChange: (value: number) => this.setReaderMenuAlpha(value),
          onTextSelectMenuConfigChange: (value: string) => this.setReaderTextSelectMenuConfig(value),
          onReadingAnchorEnabledChange: (enabled: boolean) => this.setReaderReadingAnchorEnabled(enabled),
              onSwipeToAddBookmarkChange: (enabled: boolean) => this.setReaderSwipeToAddBookmark(enabled),
              onBookmarkBadgeSizeChange: (value: number) => this.setReaderBookmarkBadgeSize(value),
              onPickBookmarkBadgeImage: (): void => { this.pickReaderBookmarkBadgeImage(); },
              onResetBookmarkBadgeImage: (): void => this.resetReaderBookmarkBadgeImage(),
              onSelectTextChange: (enabled: boolean) => this.setReaderSelectText(enabled),
              onSliderVibratorChange: (enabled: boolean) => this.setReaderSliderVibrator(enabled),
              onSelectVibratorChange: (enabled: boolean) => this.setReaderSelectVibrator(enabled),
              onChineseConverterTypeChange: (value: number) => this.setReaderChineseConverterType(value),
              textColor: this.readerTextColor,
              textColorNight: this.readerTextColorNight,
              textAccentColor: this.readerTextAccentColor,
              textAccentColorNight: this.readerTextAccentColorNight,
              bgStr: this.readerBgStr,
              bgStrNight: this.readerBgStrNight,
              bgType: this.readerBgType,
              bgTypeNight: this.readerBgTypeNight,
              bgAlpha: this.readerBgAlpha,
              darkStatusIcon: this.readerDarkStatusIcon,
              darkStatusIconNight: this.readerDarkStatusIconNight,
              titleMode: this.readerTitleMode,
              titleSize: this.readerTitleSize,
              titleSizeRelative: this.readerTitleSizeRelative,
              titleTopSpacing: this.readerTitleTopSpacing,
              titleBottomSpacing: this.readerTitleBottomSpacing,
              titleColor: this.readerTitleColor,
              titleColorNight: this.readerTitleColorNight,
              titleBold: this.readerTitleBold,
              titleLineSpacingExtra: this.readerTitleLineSpacingExtra,
              titleLineSpacingSub: this.readerTitleLineSpacingSub,
              titleSegType: this.readerTitleSegType,
              titleSegScaling: this.readerTitleSegScaling,
              titleSegDistance: this.readerTitleSegDistance,
              titleSegFlag: this.readerTitleSegFlag,
              onTextColorChange: (value: string, night: boolean) => this.setReaderTextColor(value, night),
              onTextAccentColorChange: (value: string, night: boolean) => this.setReaderTextAccentColor(value, night),
              onBackgroundColorChange: (value: string, night: boolean) => this.setReaderBackgroundColor(value, night),
              onBackgroundImageChange: (path: string, night: boolean) => this.setReaderBackgroundImage(path, night),
              onBgAlphaChange: (value: number) => this.setReaderBgAlpha(value),
              onDarkStatusIconChange: (enabled: boolean, night: boolean) => this.setReaderDarkStatusIcon(enabled, night),
              onPickBackgroundImage: (night: boolean): void => { this.pickReaderBackgroundImage(night); },
              onTitleModeChange: (value: number) => this.setReaderTitleMode(value),
              onTitleSizeChange: (value: number) => this.setReaderTitleSize(value),
              onTitleSizeRelativeChange: (relative: boolean) => this.setReaderTitleSizeRelative(relative),
              onTitleSpacingChange: (top: number, bottom: number) => this.setReaderTitleSpacing(top, bottom),
              onTitleColorChange: (value: string, night: boolean) => this.setReaderTitleColor(value, night),
              onTitleBoldChange: (value: number) => this.setReaderTitleBold(value),
              onTitleLineSpacingChange: (extra: number, sub: number) => this.setReaderTitleLineSpacing(extra, sub),
              onTitleSegTypeChange: (value: number) => this.setReaderTitleSegType(value),
              onTitleSegScalingChange: (value: number) => this.setReaderTitleSegScaling(value),
              onTitleSegDistanceChange: (value: number) => this.setReaderTitleSegDistance(value),
              onTitleSegFlagChange: (value: string) => this.setReaderTitleSegFlag(value),
              onMaxLengthWithNoTocChange: (value: number) => this.setReaderMaxLengthWithNoToc(value),
          clickRegionActions: this.readerClickRegionActions,
          onClickRegionActionsChange: (actions: string[]) => this.setReaderClickRegionActions(actions),
          clickImageBehavior: this.readerClickImageBehavior,
          onClickImageBehaviorChange: (value: string) => this.setReaderClickImageBehavior(value),
          hideStatusBar: this.readerHideStatusBar,
          hideNavigationBar: this.readerHideNavigationBar,
          onHideStatusBarChange: (enabled: boolean) => this.setReaderHideStatusBar(enabled),
          onHideNavigationBarChange: (enabled: boolean) => this.setReaderHideNavigationBar(enabled),
          infoSettings: this.readerInfoSettings,
          onInfoSettingsChange: (settings: ReaderInfoSettings) => this.setReaderInfoSettings(settings),
          onProgressBehaviorChange: (value: string) => this.setReaderProgressBehavior(value),
          readSliderMode: this.readerReadSliderMode,
          onReadSliderModeChange: (value: string) => this.setReaderReadSliderMode(value),
          pageTouchSlop: this.readerPageTouchSlop,
          onPageTouchSlopChange: (value: number) => this.setReaderPageTouchSlop(value),
          onBottomActionTextChange: (enabled: boolean) => this.setReaderBottomActionText(enabled),
          onShareLayoutChange: (enabled: boolean) => this.setReaderShareLayout(enabled),
          onToggleNightMode: () => this.toggleReaderNightMode(),
          onEyeProtectionToggle: () => this.toggleEyeProtection(),
          onEyeProtectionEnabledChange: (enabled: boolean) => this.setEyeProtectionEnabled(enabled),
          onEyeProtectionAutoNightChange: (enabled: boolean) => this.setEyeProtectionAutoNight(enabled),
          onEyeProtectionScheduleChange: (enabled: boolean) => this.setEyeProtectionSchedule(enabled),
          onEyeProtectionIntensityChange: (value: number) => this.setEyeProtectionIntensity(value),
          onEyeProtectionStartTimeChange: (value: string) => this.setEyeProtectionStartTime(value),
          onEyeProtectionEndTimeChange: (value: string) => this.setEyeProtectionEndTime(value),
          onUnavailableAction: (message: string) => this.showUnavailableAction(message),
          showQuickActions: this.showReaderQuickActions,
          asSheet: false,
          onBack: () => this.route = this.settingsReturnRoute,
          onFontSizeChange: (fontSize: number) => this.setReaderFontSize(fontSize),
              onTextItalicChange: (enabled: boolean) => this.setReaderTextItalic(enabled),
              onTextBoldChange: (weight: number) => this.setReaderTextBold(weight),
              onTextShadowChange: (enabled: boolean) => this.setReaderTextShadow(enabled),
              onShadowRadiusChange: (value: number) => this.setReaderShadowRadius(value),
              onShadowDxChange: (value: number) => this.setReaderShadowDx(value),
              onShadowDyChange: (value: number) => this.setReaderShadowDy(value),
              onUnderlineChange: (enabled: boolean) => this.setReaderUnderline(enabled),
              onDottedLineChange: (enabled: boolean) => this.setReaderDottedLine(enabled),
              onTextShadowColorChange: (value: string, night: boolean) => this.setReaderTextShadowColor(value, night),
              onUnderlineColorChange: (value: string, night: boolean) => this.setReaderUnderlineColor(value, night),
              onUnderlineHeightChange: (value: number) => this.setReaderUnderlineHeight(value),
              onUnderlinePaddingChange: (value: number) => this.setReaderUnderlinePadding(value),
              onUnderlineExtendChange: (enabled: boolean) => this.setReaderUnderlineExtend(enabled),
              onDottedBaseChange: (value: number) => this.setReaderDottedBase(value),
              onDottedRatioChange: (value: number) => this.setReaderDottedRatio(value),
              onTextFontChange: (fontPath: string) => this.setReaderTextFont(fontPath),
              onTitleFontChange: (fontPath: string) => this.setReaderTitleFont(fontPath),
              onSystemTypefacesChange: (index: number) => this.setReaderSystemTypefaces(index),
              onTextFullJustifyChange: (enabled: boolean) => this.setReaderTextFullJustify(enabled),
              onTextBottomJustifyChange: (enabled: boolean) => this.setReaderTextBottomJustify(enabled),
          onParagraphSpacingChange: (value: number) => this.setReaderParagraphSpacing(value),
          onLineSpacingChange: (value: number) => this.setReaderLineSpacing(value),
          onLetterSpacingChange: (value: number) => this.setReaderLetterSpacing(value),
          onParagraphIndentCountChange: (count: number) => this.setReaderParagraphIndentCount(count),
          onPaperChange: (paperIndex: number) => this.setReaderPaperIndex(paperIndex),
          onAddBackgroundStyle: (): number => this.addReaderBackgroundStyle(),
          onUpdateBackgroundStyle: (index: number, name: string, dayColor: string, nightColor: string): void =>
            this.updateReaderBackgroundStyle(index, name, dayColor, nightColor),
          onRemoveBackgroundStyle: (index: number): void => this.removeReaderBackgroundStyle(index),
          onMoveBackgroundStyle: (from: number, to: number): void => this.moveReaderBackgroundStyle(from, to),
          onQuickActionsChange: (enabled: boolean) => this.setReaderQuickActions(enabled)
        })
        }
        // 书签编辑面板挂在外层 Stack，阅读页与「所有书签」页都能唤起
        if (this.bookmarkEditor !== undefined) {
          ReaderBookmarkEditor({
            bookmark: this.bookmarkEditor,
            isNew: this.bookmarkEditorIsNew,
            onSave: (note: string, bookText: string) => this.saveReaderBookmarkNote(note, bookText),
            onDelete: () => this.confirmDeleteReaderBookmark(),
            onClose: () => this.bookmarkEditor = undefined
          })
        }
      }.width('100%').layoutWeight(1)
      if (this.themeShowBottomView &&
        (this.route === AppRoute.HOME || this.route === AppRoute.BOOKSHELF || this.route === AppRoute.DISCOVER ||
          this.route === AppRoute.SUBSCRIPTIONS || this.route === AppRoute.PROFILE)) {
        Row() {
          // 底栏项、顺序与显隐都来自「首页与导航」设置，对齐上游 `MainDestination.ordered` +
          // `showHome`/`showDiscovery`/`showRss`；标签显隐由 labelVisibilityMode 决定。
          ForEach(this.visibleNavigationRoutes(), (navRoute: string) => {
            TabItem({
              icon: this.navigationTabIcon(navRoute),
              label: mainNavigationLabel(navRoute),
              selected: this.selectedTab === this.navigationRouteTabIndex(navRoute),
              showLabel: this.navigationLabelVisible(navRoute)
            }).layoutWeight(1).onClick(() => this.selectTab(this.navigationRouteTabIndex(navRoute)))
          }, (navRoute: string) => navRoute)
        }.width(this.themeUseFloatingBottomBar ? 'calc(100% - 32vp)' : '100%')
          .padding({ top: 7, bottom: 6 })
          .margin(this.themeUseFloatingBottomBar ? { left: 16, right: 16, bottom: 8 } : 0)
          .borderRadius(this.bottomBarCornerRadius())
          .backgroundColor(this.bottomBarBackgroundColor().length > 0 ? this.bottomBarBackgroundColor()
            : (this.themePureBlackActive ? '#121212' : this.themeColorSurfaceElevated))
          .backdropBlur(this.themeEnableBlur ? this.themeBottomBarBlurRadius : 0)
          .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM])
      }
      }
    }.width('100%').height('100%').backgroundColor(this.appBackgroundSource().length > 0 ? Color.Transparent : (this.themePureBlackActive ? '#000000' : this.themeColorSurfacePrimary))
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM])
    // 护眼覆盖层：上游用 ColorFilter.colorMatrix 给全屏套对角色矩阵，这里用同尺寸纯色层
    // 配 MULTIPLY 混合，混合公式 result = 内容 × 覆盖色，与对角矩阵逐通道相乘等价。
    if (this.eyeProtectionOverlayColor().length > 0) {
      Column()
        .width('100%').height('100%')
        .backgroundColor(this.eyeProtectionOverlayColor())
        .blendMode(BlendMode.MULTIPLY)
        .hitTestBehavior(HitTestMode.None)
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
    }
    }.width('100%').height('100%')
  }
}

@Component
struct TabItem {
  @Prop icon: AppGlyphName = 'home';
  @Prop label: string = '';
  @Prop selected: boolean = false;
  /** 是否显示文字标签；由 labelVisibilityMode 决定，对齐上游 `labelVisibilityMode`。 */
  @Prop showLabel: boolean = true;
  build() {
    Column() {
      Stack({ alignContent: Alignment.Center }) {
        AppGlyph({ name: this.icon, tint: '#C5C7D0', glyphSize: 20 })
      }.width(50).height(32).backgroundColor(this.selected ? '#3A4054' : Color.Transparent).borderRadius(18)
      if (this.selected && this.showLabel) { Text(this.label).fontSize(10).fontColor('#D7DFFB').margin({ top: 2 }) }
    }.width('100%').alignItems(HorizontalAlign.Center).padding({ top: 1, bottom: 1 })
  }
}














