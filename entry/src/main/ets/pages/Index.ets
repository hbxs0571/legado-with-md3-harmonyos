import { AppRoute, Book, BookMediaType, ProfileRoute } from '../model/Book';
import { BookGroup, BookGroupDraft } from '../model/BookGroup';
import { HomePage } from './HomePage';
import { BookshelfPage } from './BookshelfPage';
import { DiscoverPage } from './DiscoverPage';
import { SubscriptionPage } from './SubscriptionPage';
import { SubscriptionFavoritesPage, SubscriptionRulesPage, SubscriptionSourceManagePage } from './SubscriptionSubPages';
import { ProfilePage } from './ProfilePage';
import { ReaderPage } from './ReaderPage';
import { CatalogPage } from './CatalogPage';
import { ReaderSettingsPage } from './ReaderSettingsPage';
import { SearchPage } from './SearchPage';
import {
  BookSourceManagePage, ReplaceRulesPage, ReplaceRuleEditPage, TxtTocRulesPage, DictionaryRulesPage,
  DictionaryRuleEditPage, HighlightTagRulesPage, HighlightTagRuleEditPage,
  AllBookmarksPage, ReadRecordsPage, CacheManagementPage,
  AboutAppPage, AiChatPage, AppSettingsHomePage, BookmarkBookSummary, BookmarkEntrySummary, RuleListEntry
} from './ProfileSubPages';
import { ReaderSearchPage } from './ReaderSearchPage';
import { ReaderAloudSettingsPage } from './ReaderAloudSettingsPage';
import { BookInfoPage } from './BookInfoPage';
import { ThemeSettingsPage } from './ThemeSettingsPage';
import { OtherSettingsPage } from './OtherSettingsPage';
import { AppReadAloudSettingsPage } from './AppReadAloudSettingsPage';
import { AppCoverSettingsPage } from './AppCoverSettingsPage';
import { AppDownloadCacheSettingsPage } from './AppDownloadCacheSettingsPage';
import { AppAiSettingsPage } from './AppAiSettingsPage';
import { AppTranslationSettingsPage } from './AppTranslationSettingsPage';
import { AppPrivacySettingsPage } from './AppPrivacySettingsPage';
import { AppLabSettingsPage } from './AppLabSettingsPage';
import { AppBackupSettingsPage } from './AppBackupSettingsPage';
import { PrivacyNoticePage } from './PrivacyNoticePage';
import { OpenSourceLicensePage } from './OpenSourceLicensePage';
import { FileManagerPage } from './FileManagerPage';
import { AppGlyph, AppGlyphName } from '../components/AppGlyph';
import { BookRepository } from '../data/BookRepository';
import { TocRefreshResult } from '../data/BookRepository';
import { BookGroupRepository } from '../data/BookGroupRepository';
import { BookshelfLayoutRepository } from '../data/BookshelfLayoutRepository';
import {
  BookshelfLayoutSettings, DEFAULT_BOOKSHELF_LAYOUT, copyBookshelfLayout
} from '../model/BookshelfLayout';
import {
  HomeDashboardSection, HOME_DASHBOARD_SECTIONS, HomeDashboardSettingsRepository
} from '../data/HomeDashboardSettingsRepository';
import { OnboardingRepository } from '../data/OnboardingRepository';
import {
  ReaderBottomActionConfig, ReaderSettingsRepository, ReaderSettingsSnapshot, READER_BACKGROUND_STYLES,
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
import { ReaderBookmarkRepository } from '../data/ReaderBookmarkRepository';
import { ReaderBookmarkExporter } from '../data/ReaderBookmarkExporter';
import { ReaderBookmarkBadgeRepository } from '../data/ReaderBookmarkBadgeRepository';
import { ReaderMarking, ReaderMarkingEffect } from '../model/ReaderMarking';
import { ReaderMarkingRepository } from '../data/ReaderMarkingRepository';
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
import { ReadRecordDetail, ReadRecordSummary, ReadTimeRecord } from '../model/ReadRecord';
import { ReadRecordRepository } from '../data/ReadRecordRepository';

const EMPTY_BOOK: Book = {
  id: '',
  title: '',
  author: '',
  category: '',
  lastChapter: '',
  progress: 0,
  coverColor: '#1C1D23',
  coverMark: '',
  isLocal: false
};

@Entry
@Component
struct Index {
  @State route: AppRoute = AppRoute.HOME;
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
  @State selectedTab: number = 0;
  @State selectedBook: Book = EMPTY_BOOK;
  @State readerStartAtChapterBeginning: boolean = false;
  @State selectedChapter: string = '';
  @State books: Book[] = [];
  @State bookGroups: BookGroup[] = [];
  /** 书架布局设置，与 BookshelfLayoutRepository 的持久化值保持同步。 */
  @State bookshelfLayout: BookshelfLayoutSettings = copyBookshelfLayout(DEFAULT_BOOKSHELF_LAYOUT);
  @State readTimeRecords: ReadTimeRecord[] = [];
  @State readRecordDetails: ReadRecordDetail[] = [];
  @State readRecordSummaries: ReadRecordSummary[] = [];
  @State readerBookmarks: ReaderBookmark[] = [];
  @State readerMarkings: ReaderMarking[] = [];
  @State replaceRules: ReplaceRule[] = [];
  /** TXT 目录规则列表，与仓储缓存同步。 */
  @State txtTocRules: TxtTocRule[] = [];
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
  @State readerContent: string = '';
  @State readerFontSize: number = 20;
  @State readerParagraphSpacing: number = 2;
  @State readerLineSpacing: number = 12;
  @State readerLetterSpacing: number = 0.1;
  @State readerParagraphIndent: string = '　　';
  @State readerTextFont: string = '';
  @State readerTitleFont: string = '';
  @State readerSystemTypefaces: number = 0;
  @State readerTextItalic: boolean = false;
  @State readerTextBold: number = 500;
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
  @State readerTextFullJustify: boolean = true;
  @State readerTextBottomJustify: boolean = true;
  @State paperIndex: number = 0;
  @State dayPaperIndex: number = 0;
  @State nightPaperIndex: number = 0;
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
  @State readerProgressBehavior: string = 'page';
  @State readerPaddingSettings: ReaderPaddingSettings = copyReaderPaddingSettings(DEFAULT_READER_PADDING_SETTINGS);
  @State readerScreenOrientation: string = '0';
  @State readerKeepLight: string = '0';
  @State readerVolumeKeyPage: boolean = true;
  @State readerKeyPageOnLongPress: boolean = false;
  @State readerNoAnimScrollPage: boolean = false;
  @State readerReadingAnchorEnabled: boolean = true;
  @State readerSwipeToAddBookmark: boolean = false;
  /** 阅读页书签角标宽度（dp），0 表示不显示；与上游 bookmarkBadgeSize 对齐。 */
  @State readerBookmarkBadgeSize: number = 10;
  /** 自定义书签角标图片路径，空串表示用默认丝带；与上游 bookmarkBadgeImage 对齐。 */
  @State readerBookmarkBadgeImage: string = '';
  @State readerSelectText: boolean = true;
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
  @State onboardingLoaded: boolean = false;
  @State onboardingComplete: boolean = false;
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
      this.restoreOnboarding(context);
      this.restoreReadTimeRecords(context);
      this.restoreHomeDashboardSettings(context);
      this.restoreImportedBooks(context);
      this.restoreBookshelfLayout(context);
      this.restoreReaderBookmarks(context);
      this.restoreReaderMarkings(context);
      this.restoreReaderSettings(context);
      this.restoreReaderMoreActions(context);
      this.restoreReplaceRules(context);
      this.restoreTxtTocRules(context);
      this.restoreBookContentProcesses(context);
      this.restoreBackupIgnoreLists(context);
      this.loadRestoredAndroidEntries(context);
    }
    this.eyeProtectionTimerId = setInterval(() => {
      this.eyeProtectionMinute = Math.floor(Date.now() / 60000);
    }, 60000);
  }

  aboutToDisappear(): void {
    if (this.eyeProtectionTimerId >= 0) {
      clearInterval(this.eyeProtectionTimerId);
      this.eyeProtectionTimerId = -1;
    }
  }

  private async restoreBookshelfLayout(context: Context): Promise<void> {
    this.bookshelfLayout = await BookshelfLayoutRepository.load(context);
  }

  private async restoreReadTimeRecords(context: Context): Promise<void> {
    // 先迁移旧扁平数据，再从权威会话层构建时间线。
    await ReadRecordRepository.migrateLegacy(context);
    await ReadRecordRepository.loadEnabled(context);
    await this.reloadReadRecordData(context);
  }

  private async reloadReadRecordData(context: Context): Promise<void> {
    const sessions = await ReadRecordRepository.loadSessions(context);
    this.readTimeRecords = ReadRecordRepository.toTimelineRecords(sessions);
    this.readRecordDetails = await ReadRecordRepository.loadDetails(context);
    this.readRecordSummaries = await ReadRecordRepository.loadSummaries(context);
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
      await ReplaceRuleRepository.setBookEnabled(context, this.selectedBook, enabled);
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
      await ReplaceRuleRepository.clearBookEnabledOverride(context, this.selectedBook);
      this.readerReplaceUsesDefault = true;
      this.readerReplaceEnabled = ReplaceRuleRepository.getDefaultEnabled();
      await this.reloadSelectedChapter();
    } catch (_) {
      this.showUnavailableAction('恢复默认替换净化设置失败');
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

  private async addReplaceRuleGroup(name: string): Promise<void> {
    const context = this.getUIContext().getHostContext();
    if (context === undefined) {
      this.showUnavailableAction('无法访问本地规则存储');
      return;
    }
    try {
      await ReplaceRuleRepository.addGroup(context, name);
      this.replaceRules = ReplaceRuleRepository.getAll();
    } catch (_) {
      this.showUnavailableAction('新增分组失败');
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
    this.books.filter((book: Book) => !book.isLocal).forEach((book: Book) => {
      const group = book.groupName?.trim() ?? '';
      if (group.length > 0 && !groups.includes(group)) { groups.push(group); }
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
      this.selectedBook.bodyMissing === true) {
      this.showUnavailableAction('划线与笔记仅支持已有本地正文的书籍');
      return;
    }
    const chapterIndex = Math.max(0, this.selectedBook.chapterIndex ??
      (this.selectedBook.chapterTitles ?? []).indexOf(this.selectedChapter));
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
    const chapterTitles = this.selectedBook.chapterTitles ?? [];
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

  private toggleReaderBookmarkForPage(startPosition: number, endPosition: number, pageText: string): Promise<void> {
    const operation = this.readerBookmarkToggleQueue.then(async (): Promise<void> => {
      if (!this.selectedBook.isLocal || this.selectedBook.contentPath === undefined) { return; }
      const chapterTitles = this.selectedBook.chapterTitles ?? [];
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

  private async openReaderBookmark(bookmarkId: string): Promise<void> {
    const bookmark = this.readerBookmarks.find((record: ReaderBookmark) => record.id === bookmarkId);
    if (bookmark === undefined) { return; }
    const targetBook = this.books.find((book: Book) => book.id === bookmark.bookId);
    if (targetBook === undefined || targetBook.contentPath === undefined) {
      this.showUnavailableAction('这条书签对应的本地正文不可用');
      return;
    }
    const chapterTitles = targetBook.chapterTitles ?? [];
    let chapterIndex = bookmark.chapterIndex;
    if (chapterTitles[chapterIndex] !== bookmark.chapterName) {
      const matchingIndex = chapterTitles.indexOf(bookmark.chapterName);
      if (matchingIndex < 0) {
        this.showUnavailableAction('书签章节与当前目录不匹配，已取消跳转');
        return;
      }
      chapterIndex = matchingIndex;
    }
    const chapterTitle = chapterTitles[chapterIndex];
    if (chapterTitle === undefined) {
      this.showUnavailableAction('书签章节不在当前目录中');
      return;
    }
    let content: string;
    try {
      content = await BookRepository.readChapter(targetBook, chapterTitle, chapterIndex);
      this.replaceRules = ReplaceRuleRepository.getAll();
    } catch (_) {
      this.showUnavailableAction('无法读取书签对应章节');
      return;
    }
    const semanticLength = LocalTextSemantics.fromRawBody(content).length;
    const position = Math.max(0, Math.min(semanticLength, bookmark.chapterPosition));
    const chapterProgress = semanticLength > 0 ? position / semanticLength * 100 : 0;
    const chapterCount = Math.max(1, chapterTitles.length);
    const updatedBook: Book = {
      id: targetBook.id,
      title: targetBook.title,
      author: targetBook.author,
      category: targetBook.category,
      groupName: targetBook.groupName,
      groupNames: targetBook.groupNames,
      chapterTitles: targetBook.chapterTitles,
      chapterOffsets: targetBook.chapterOffsets,
      chapterVolumes: targetBook.chapterVolumes,
      chapterIndex: chapterIndex,
      chapterProgress: chapterProgress,
      lastChapter: chapterTitle,
      progress: (chapterIndex + chapterProgress / 100) / chapterCount * 100,
      coverColor: targetBook.coverColor,
      coverMark: targetBook.coverMark,
      coverUri: targetBook.coverUri,
      customCoverUri: targetBook.customCoverUri,
      bookType: targetBook.bookType,
      fixedType: targetBook.fixedType,
      contentPath: targetBook.contentPath,
      format: targetBook.format,
      chapterCount: targetBook.chapterCount,
      fileSizeBytes: targetBook.fileSizeBytes,
      imageStyle: targetBook.imageStyle,
      reSegment: targetBook.reSegment,
      charset: targetBook.charset,
      description: targetBook.description,
      remark: targetBook.remark,
      customTag: targetBook.customTag,
      bodyMissing: targetBook.bodyMissing,
      androidOriginalPath: targetBook.androidOriginalPath,
      androidCharacterPosition: position,
      readerPositionVersion: 1,
      tocRule: targetBook.tocRule,
      isLocal: targetBook.isLocal
    };
    const updatedBooks = this.books.map((book: Book) => book.id === updatedBook.id ? updatedBook : book);
    const context = this.getUIContext().getHostContext();
    if (context === undefined) {
      this.showUnavailableAction('无法访问本地书架，书签位置未保存');
      return;
    }
    try {
      await BookRepository.saveImportedBooks(context,
        updatedBooks.filter((book: Book) => BookRepository.isPersistableBook(book)));
    } catch (_) {
      this.showUnavailableAction('书签位置保存失败，已保留原阅读位置');
      return;
    }
    this.selectedBook = updatedBook;
    this.books = updatedBooks;
    this.selectedChapter = chapterTitle;
    this.readerContent = content;
    this.readerBookmarkTargetPosition = position;
    this.readerBookmarkTargetRevision++;
    this.readerStartAtChapterBeginning = false;
    this.bookmarkEditor = undefined;
    this.route = AppRoute.READER;
  }

  private async openReaderMarking(markingId: string): Promise<void> {
    const marking = this.readerMarkings.find((record: ReaderMarking) => record.id === markingId);
    if (marking === undefined) { return; }
    const targetBook = this.books.find((book: Book) => book.id === marking.bookId);
    if (targetBook === undefined || targetBook.contentPath === undefined || targetBook.bodyMissing === true) {
      this.showUnavailableAction('这条笔记对应的本地正文不可用');
      return;
    }
    const chapterTitles = targetBook.chapterTitles ?? [];
    let chapterIndex = marking.chapterIndex;
    if (chapterTitles[chapterIndex] !== marking.chapterName) {
      const matchingIndex = chapterTitles.indexOf(marking.chapterName);
      if (matchingIndex < 0) {
        this.showUnavailableAction('笔记章节与当前目录不匹配，已取消跳转');
        return;
      }
      chapterIndex = matchingIndex;
    }
    const chapterTitle = chapterTitles[chapterIndex];
    if (chapterTitle === undefined) {
      this.showUnavailableAction('笔记章节不在当前目录中');
      return;
    }
    let content: string;
    try {
      content = await BookRepository.readChapter(targetBook, chapterTitle, chapterIndex);
      this.replaceRules = ReplaceRuleRepository.getAll();
    } catch (_) {
      this.showUnavailableAction('无法读取笔记对应章节');
      return;
    }
    const semanticContent = LocalTextSemantics.fromRawBody(content);
    const position = Math.max(0, Math.min(semanticContent.length, marking.chapterPosition));
    const chapterProgress = semanticContent.length > 0 ? position / semanticContent.length * 100 : 0;
    const chapterCount = Math.max(1, chapterTitles.length);
    const updatedBook: Book = {
      id: targetBook.id,
      title: targetBook.title,
      author: targetBook.author,
      category: targetBook.category,
      groupName: targetBook.groupName,
      groupNames: targetBook.groupNames,
      chapterTitles: targetBook.chapterTitles,
      chapterOffsets: targetBook.chapterOffsets,
      chapterVolumes: targetBook.chapterVolumes,
      chapterIndex: chapterIndex,
      chapterProgress: chapterProgress,
      lastChapter: chapterTitle,
      progress: (chapterIndex + chapterProgress / 100) / chapterCount * 100,
      coverColor: targetBook.coverColor,
      coverMark: targetBook.coverMark,
      coverUri: targetBook.coverUri,
      customCoverUri: targetBook.customCoverUri,
      bookType: targetBook.bookType,
      fixedType: targetBook.fixedType,
      contentPath: targetBook.contentPath,
      format: targetBook.format,
      chapterCount: targetBook.chapterCount,
      fileSizeBytes: targetBook.fileSizeBytes,
      imageStyle: targetBook.imageStyle,
      reSegment: targetBook.reSegment,
      charset: targetBook.charset,
      description: targetBook.description,
      remark: targetBook.remark,
      customTag: targetBook.customTag,
      bodyMissing: targetBook.bodyMissing,
      androidOriginalPath: targetBook.androidOriginalPath,
      androidCharacterPosition: position,
      readerPositionVersion: 1,
      tocRule: targetBook.tocRule,
      isLocal: targetBook.isLocal
    };
    const updatedBooks = this.books.map((book: Book) => book.id === updatedBook.id ? updatedBook : book);
    const context = this.getUIContext().getHostContext();
    if (context === undefined) {
      this.showUnavailableAction('无法访问本地书架，笔记位置未保存');
      return;
    }
    try {
      await BookRepository.saveImportedBooks(context,
        updatedBooks.filter((book: Book) => BookRepository.isPersistableBook(book)));
    } catch (_) {
      this.showUnavailableAction('笔记位置保存失败，已保留原阅读位置');
      return;
    }
    this.selectedBook = updatedBook;
    this.books = updatedBooks;
    this.selectedChapter = chapterTitle;
    this.readerContent = content;
    this.readerBookmarkTargetPosition = position;
    this.readerBookmarkTargetRevision++;
    this.readerStartAtChapterBeginning = false;
    this.markingEditor = undefined;
    this.route = AppRoute.READER;
  }

  private async openReaderSearchResult(chapterIndex: number, chapterPosition: number): Promise<void> {
    const targetBook = this.selectedBook;
    if (targetBook.contentPath === undefined) {
      this.showUnavailableAction('这本书没有可搜索的本地正文');
      return;
    }
    const chapterTitles = targetBook.chapterTitles ?? [];
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
    const updatedBook: Book = {
      id: targetBook.id,
      title: targetBook.title,
      author: targetBook.author,
      category: targetBook.category,
      groupName: targetBook.groupName,
      groupNames: targetBook.groupNames,
      chapterTitles: targetBook.chapterTitles,
      chapterOffsets: targetBook.chapterOffsets,
      chapterVolumes: targetBook.chapterVolumes,
      chapterIndex: chapterIndex,
      chapterProgress: chapterProgress,
      lastChapter: chapterTitle,
      progress: (chapterIndex + chapterProgress / 100) / chapterCount * 100,
      coverColor: targetBook.coverColor,
      coverMark: targetBook.coverMark,
      coverUri: targetBook.coverUri,
      customCoverUri: targetBook.customCoverUri,
      bookType: targetBook.bookType,
      fixedType: targetBook.fixedType,
      contentPath: targetBook.contentPath,
      format: targetBook.format,
      chapterCount: targetBook.chapterCount,
      fileSizeBytes: targetBook.fileSizeBytes,
      imageStyle: targetBook.imageStyle,
      reSegment: targetBook.reSegment,
      charset: targetBook.charset,
      description: targetBook.description,
      remark: targetBook.remark,
      customTag: targetBook.customTag,
      bodyMissing: targetBook.bodyMissing,
      androidOriginalPath: targetBook.androidOriginalPath,
      androidCharacterPosition: androidPosition,
      readerPositionVersion: 2,
      tocRule: targetBook.tocRule,
      isLocal: targetBook.isLocal
    };
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
  private getBookmarkBookSummaries(): BookmarkBookSummary[] {
    const summaries: BookmarkBookSummary[] = [];
    for (let index = 0; index < this.readerBookmarks.length; index++) {
      const bookmark = this.readerBookmarks[index];
      if (bookmark === undefined) { continue; }
      const existingIndex = summaries.findIndex((summary: BookmarkBookSummary) => summary.key === bookmark.bookId);
      if (existingIndex < 0) {
        summaries.push({
          key: bookmark.bookId, title: bookmark.bookName, author: bookmark.bookAuthor,
          bookmarkCount: 1, noteCount: 0, sourceUrl: bookmark.bookUrl
        });
      } else {
        const current = summaries[existingIndex];
        if (current !== undefined) {
          summaries[existingIndex] = {
            key: current.key, title: current.title, author: current.author,
            bookmarkCount: current.bookmarkCount + 1, noteCount: current.noteCount, sourceUrl: current.sourceUrl
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
          bookmarkCount: 0, noteCount: 1, sourceUrl: marking.bookUrl
        });
      } else {
        const current = summaries[existingIndex];
        if (current !== undefined) {
          summaries[existingIndex] = {
            key: current.key, title: current.title, author: current.author,
            bookmarkCount: current.bookmarkCount, noteCount: current.noteCount + 1, sourceUrl: current.sourceUrl
          };
        }
      }
    }
    // 上游 AllBookmarkViewModel 对书籍列表按书名排序（sortedBy { it.key.name }），
    // 本地原来按存储里第一次出现的顺序，书名多了会乱。
    return summaries.sort((left: BookmarkBookSummary, right: BookmarkBookSummary) =>
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

  private async restoreOnboarding(context: Context): Promise<void> {
    const state = await OnboardingRepository.load(context);
    this.onboardingComplete = state.completed;
    this.onboardingLoaded = true;
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
      this.readerTextFullJustify = settings.textFullJustify;
      this.readerTextBottomJustify = settings.textBottomJustify;
      this.paperIndex = settings.paperIndex;
      this.dayPaperIndex = settings.dayPaperIndex;
      this.nightPaperIndex = settings.nightPaperIndex;
      this.readerNightMode = settings.readerNightMode;
      this.shareReaderStyleLayout = settings.shareLayout;
      this.showReaderBottomActionText = settings.showBottomActionText;
      this.readerBottomIconStyle = settings.bottomIconStyle;
      this.readerBottomItemsPerRow = settings.bottomItemsPerRow;
      this.readerBottomRowCount = settings.bottomRowCount;
      this.readerBottomActions = settings.bottomActions;
      this.readerTopActions = settings.topActions;
      this.readerProgressBehavior = settings.progressBehavior;
      this.readerPaddingSettings = copyReaderPaddingSettings(settings.paddingSettings);
      this.readerScreenOrientation = settings.screenOrientation;
      this.readerKeepLight = settings.keepLight;
      this.readerVolumeKeyPage = settings.volumeKeyPage;
      this.readerKeyPageOnLongPress = settings.keyPageOnLongPress;
      this.readerNoAnimScrollPage = settings.noAnimScrollPage;
      this.readerReadingAnchorEnabled = settings.readingAnchorEnabled;
      this.readerSwipeToAddBookmark = settings.swipeToAddBookmark;
      this.readerBookmarkBadgeSize = settings.bookmarkBadgeSize;
      this.readerBookmarkBadgeImage = settings.bookmarkBadgeImage;
      this.readerSelectText = settings.selectText;
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
    } catch (_) {
      this.showUnavailableAction('更多操作配置保存失败');
    }
  }

  private async restoreBackupIgnoreLists(context: Context): Promise<void> {
    const options = await BackupRepository.loadIgnoreLists(context);
    this.backupIgnoreKeys = options.backup;
    this.restoreIgnoreKeys = options.restore;
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
    return {
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
        textFullJustify: this.readerTextFullJustify,
        textBottomJustify: this.readerTextBottomJustify,
        paperIndex: this.paperIndex,
        dayPaperIndex: this.dayPaperIndex,
        nightPaperIndex: this.nightPaperIndex,
        readerNightMode: this.readerNightMode,
        shareLayout: this.shareReaderStyleLayout,
        showBottomActionText: this.showReaderBottomActionText,
        bottomIconStyle: this.readerBottomIconStyle,
        bottomItemsPerRow: this.readerBottomItemsPerRow,
        bottomRowCount: this.readerBottomRowCount,
        bottomActions: this.readerBottomActions,
        topActions: this.readerTopActions,
        progressBehavior: this.readerProgressBehavior,
        paddingSettings: this.readerPaddingSettings,
        screenOrientation: this.readerScreenOrientation,
        keepLight: this.readerKeepLight,
        volumeKeyPage: this.readerVolumeKeyPage,
        keyPageOnLongPress: this.readerKeyPageOnLongPress,
        noAnimScrollPage: this.readerNoAnimScrollPage,
        readingAnchorEnabled: this.readerReadingAnchorEnabled,
        swipeToAddBookmark: this.readerSwipeToAddBookmark,
        bookmarkBadgeSize: this.readerBookmarkBadgeSize,
        bookmarkBadgeImage: this.readerBookmarkBadgeImage,
        selectText: this.readerSelectText,
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
    this.paperIndex = Math.max(0, Math.min(5, paperIndex));
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

  private setReaderShareLayout(shareLayout: boolean): void {
    this.shareReaderStyleLayout = shareLayout;
    if (shareLayout) {
      if (this.readerNightMode) { this.dayPaperIndex = this.nightPaperIndex; }
      else { this.nightPaperIndex = this.dayPaperIndex; }
    }
    this.readerSettingsRevision += 1;
    if (this.readerSettingsLoaded) { this.persistReaderSettings(); }
  }

  private toggleReaderNightMode(): void {
    this.readerNightMode = !this.readerNightMode;
    this.paperIndex = this.readerNightMode ? this.nightPaperIndex : this.dayPaperIndex;
    this.readerSettingsRevision += 1;
    if (this.readerSettingsLoaded) { this.persistReaderSettings(); }
  }

  private isEyeProtectionActive(): boolean {
    if (!(this.eyeProtectionEnabled || (this.eyeProtectionAutoNight && this.readerNightMode))) { return false; }
    if (!this.eyeProtectionSchedule) { return true; }
    const start = this.parseEyeProtectionMinutes(this.eyeProtectionStartTime);
    const end = this.parseEyeProtectionMinutes(this.eyeProtectionEndTime);
    if (start < 0 || end < 0) { return true; }
    if (start === end) { return true; }
    const now = new Date(this.eyeProtectionMinute * 60000);
    const current = now.getHours() * 60 + now.getMinutes();
    return start < end ? current >= start && current < end : current >= start || current < end;
  }

  private parseEyeProtectionMinutes(value: string): number {
    const parts = value.trim().split(':');
    if (parts.length !== 2) { return -1; }
    const hour = Number(parts[0]);
    const minute = Number(parts[1]);
    if (!Number.isInteger(hour) || !Number.isInteger(minute) || hour < 0 || hour >= 24 || minute < 0 || minute >= 60) {
      return -1;
    }
    return hour * 60 + minute;
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
    try {
      const localBooks = this.books.filter((book: Book) => BookRepository.isPersistableBook(book));
      const settings = await ReaderSettingsRepository.load(context);
      const bookshelfLayout = await BookshelfLayoutRepository.load(context);
      const created = await BackupRepository.createBackup(context, localBooks, settings, bookshelfLayout, this.backupIgnoreKeys);
      this.backupStatusMessage = created ? 'Android 兼容 ZIP 已保存到你选择的位置。' : '';
    } catch (error) {
      this.backupStatusMessage = error instanceof Error ? `创建备份失败：${error.message}` : '创建备份失败';
    } finally {
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
      this.paperIndex = result.settings.paperIndex;
      this.dayPaperIndex = result.settings.dayPaperIndex;
      this.nightPaperIndex = result.settings.nightPaperIndex;
      this.readerNightMode = result.settings.readerNightMode;
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
      this.showReaderQuickActions = result.settings.showQuickActions;
      this.autoReadSpeed = result.settings.autoReadSpeed;
      this.readerPageAnimation = result.settings.pageAnimation;
      this.readerAnimationSpeed = result.settings.animationSpeed;
      this.readerInfoSettings = this.getReaderInfoSettingsFromSnapshot(result.settings);
      this.readerSettingsLoaded = true;
      this.readerSettingsRevision += 1;
      // 恢复可能写入了替换净化规则，重新读一次让规则页和阅读页都看到最新结果。
      this.replaceRules = ReplaceRuleRepository.getAll();
      this.txtTocRules = TxtTocRuleRepository.getAll();
      // 恢复可能写入了书签与笔记，重新读一次让「所有书签」页与阅读页看到最新结果。
      this.readerBookmarks = await ReaderBookmarkRepository.load(context);
      this.readerMarkings = await ReaderMarkingRepository.load(context);
      const restoreSummary = `导入完成：保留 ${result.preservedEntryCount} 个 Android 条目；更新 ${result.updatedLocalBookCount} 本已有正文书籍的进度，并创建 ${result.createdMissingBodyBookCount} 本缺正文书目`;
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
    let book: Book | undefined;
    try {
      book = await BookRepository.importLocalBook(context, this.readerMaxLengthWithNoToc);
    } catch (error) {
      this.showUnavailableAction(error instanceof Error ? `导入失败：${error.message}` : '导入失败：文件格式不受支持');
      return undefined;
    }
    if (book === undefined) {
      return undefined;
    }
    const importedBook = book;
    const importedBooks = await BookRepository.loadImportedBooks(context);
    const duplicate = [...this.books, ...importedBooks].find((item: Book) =>
      (item.contentPath !== undefined || item.bodyMissing === true) && item.format === importedBook.format &&
      item.title === importedBook.title && item.author === importedBook.author
    );
    if (duplicate !== undefined) {
      try {
        BookRepository.discardImportedCopy(importedBook);
      } catch (_) {
        this.showUnavailableAction('书籍已在书架中，重复副本清理失败');
        return undefined;
      }
      this.showUnavailableAction(duplicate.bodyMissing === true
        ? '书架中已有同名缺正文记录，请先移出该记录再导入正文'
        : '这本书已在书架中');
      return undefined;
    }
    const booksToSave = [...this.books, importedBook]
      .filter((item: Book) => BookRepository.isPersistableBook(item));
    try {
      await BookRepository.saveImportedBooks(context, booksToSave);
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
   * 重新识别书架里所有本地 TXT 的目录，对应上游书架的「更新目录」。
   *
   * 导入时选中的章节正则会固定在 Book.tocRule 上，规则调整后已有书的目录不会变，
   * 这里给用户一个主动重算的入口：清掉缓存规则、重新匹配、按字符偏移迁移阅读位置，
   * 同时重映射这本书的书签，避免书签落到别的章节。
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
    let nextBookmarks = this.readerBookmarks;
    let nextMarkings = this.readerMarkings;
    const updatedBooks: Book[] = [];
    for (let index = 0; index < this.books.length; index++) {
      const book = this.books[index];
      if (book === undefined) { continue; }
      if (!book.isLocal || book.format !== 'txt' || book.contentPath === undefined) {
        updatedBooks.push(book);
        continue;
      }
      try {
        const result = BookRepository.refreshToc(book, this.readerMaxLengthWithNoToc);
        if (!result.changed) {
          updatedBooks.push(book);
          continue;
        }
        updatedBooks.push(result.book);
        updatedCount += 1;
        nextBookmarks = this.remapNoTocBookmarks(book, result.book,
          result.oldBodyOffsets, result.newBodyOffsets, result.content.length);
        // 划线/笔记与书签共用同一套章内偏移，目录重算后必须一起迁移。
        nextMarkings = this.remapNoTocMarkings(book, result.book,
          result.oldBodyOffsets, result.newBodyOffsets, result.content.length);
        if (this.selectedBook.id === result.book.id) {
          this.selectedBook = result.book;
        }
      } catch (_) {
        // 单本书读不出来不该让整批失败，其余书照常更新。
        failedCount += 1;
        updatedBooks.push(book);
      }
    }
    if (updatedCount === 0 && failedCount === 0) {
      this.showUnavailableAction('所有本地 TXT 的目录都没有变化');
      return;
    }
    try {
      await BookRepository.saveImportedBooks(context,
        updatedBooks.filter((book: Book) => BookRepository.isPersistableBook(book)));
      if (nextBookmarks !== this.readerBookmarks) {
        await ReaderBookmarkRepository.save(context, nextBookmarks);
      }
      if (nextMarkings !== this.readerMarkings) {
        await ReaderMarkingRepository.save(context, nextMarkings);
      }
    } catch (_) {
      this.showUnavailableAction('目录已更新，但保存失败，重新打开后可能回到旧目录');
      return;
    }
    this.books = updatedBooks;
    this.readerBookmarks = nextBookmarks;
    this.readerMarkings = nextMarkings;
    const parts: string[] = [];
    if (updatedCount > 0) { parts.push(`已更新 ${updatedCount} 本`); }
    if (failedCount > 0) { parts.push(`${failedCount} 本读取失败已跳过`); }
    this.showUnavailableAction(`更新目录完成：${parts.join('，')}`);
  }

  private getPaperColor(): string {
    const style = READER_BACKGROUND_STYLES[Math.max(0, Math.min(5, this.paperIndex))];
    return style === undefined ? '#000000' : (this.readerNightMode ? style.nightColor : style.dayColor);
  }
  private remapNoTocBookmarks(book: Book, nextBook: Book, oldBodyOffsets: number[],
    newBodyOffsets: number[], contentLength: number): ReaderBookmark[] {
    let changed = false;
    const nextBookmarks: ReaderBookmark[] = [];
    for (let index = 0; index < this.readerBookmarks.length; index++) {
      const bookmark = this.readerBookmarks[index];
      if (bookmark === undefined || bookmark.bookId !== book.id) {
        if (bookmark !== undefined) { nextBookmarks.push(bookmark); }
        continue;
      }
      const oldIndex = Math.max(0, Math.min(oldBodyOffsets.length - 1, bookmark.chapterIndex));
      const absolutePosition = Math.max(0, Math.min(contentLength,
        (oldBodyOffsets[oldIndex] ?? 0) + bookmark.chapterPosition));
      let chapterIndex = 0;
      for (let chapter = 0; chapter < newBodyOffsets.length; chapter++) {
        if ((newBodyOffsets[chapter] ?? 0) > absolutePosition) { break; }
        chapterIndex = chapter;
      }
      chapterIndex = Math.min(chapterIndex, Math.max(0, (nextBook.chapterTitles?.length ?? 1) - 1));
      const chapterStart = newBodyOffsets[chapterIndex] ?? 0;
      const chapterEnd = newBodyOffsets[chapterIndex + 1] ?? contentLength;
      const chapterPosition = Math.max(0,
        Math.min(chapterEnd - chapterStart, absolutePosition - chapterStart));
      const chapterName = nextBook.chapterTitles?.[chapterIndex] ?? bookmark.chapterName;
      if (chapterIndex === bookmark.chapterIndex && chapterPosition === bookmark.chapterPosition &&
        chapterName === bookmark.chapterName) {
        nextBookmarks.push(bookmark);
        continue;
      }
      changed = true;
      nextBookmarks.push({
        id: bookmark.id,
        bookId: bookmark.bookId,
        bookName: bookmark.bookName,
        bookAuthor: bookmark.bookAuthor,
        bookUrl: bookmark.bookUrl,
        chapterIndex: chapterIndex,
        chapterName: chapterName,
        chapterPosition: chapterPosition,
        bookText: bookmark.bookText,
        content: bookmark.content,
        createdAt: bookmark.createdAt
      });
    }
    return changed ? nextBookmarks : this.readerBookmarks;
  }

  /**
   * 目录重算后把划线/笔记迁移到新的章节结构上。
   *
   * 划线记录的是章节内 UTF-16 起止偏移（chapterPosition/endPosition），
   * 只重映射书签会让划线整体错位到别的章节或别的句子，所以这里按同一套
   * 「章节起点 + 章内偏移 = 绝对位置」的算法把起止两点分别换算过去。
   */
  private remapNoTocMarkings(book: Book, nextBook: Book, oldBodyOffsets: number[],
    newBodyOffsets: number[], contentLength: number): ReaderMarking[] {
    let changed = false;
    const nextMarkings: ReaderMarking[] = [];
    /** 把绝对偏移换算成新的章号与章内偏移。 */
    const relocate = (absolutePosition: number): number[] => {
      let chapterIndex = 0;
      for (let chapter = 0; chapter < newBodyOffsets.length; chapter++) {
        if ((newBodyOffsets[chapter] ?? 0) > absolutePosition) { break; }
        chapterIndex = chapter;
      }
      chapterIndex = Math.min(chapterIndex, Math.max(0, (nextBook.chapterTitles?.length ?? 1) - 1));
      const chapterStart = newBodyOffsets[chapterIndex] ?? 0;
      const chapterEnd = newBodyOffsets[chapterIndex + 1] ?? contentLength;
      const offset = Math.max(0, Math.min(chapterEnd - chapterStart, absolutePosition - chapterStart));
      return [chapterIndex, offset];
    };
    for (let index = 0; index < this.readerMarkings.length; index++) {
      const marking = this.readerMarkings[index];
      if (marking === undefined || marking.bookId !== book.id) {
        if (marking !== undefined) { nextMarkings.push(marking); }
        continue;
      }
      const oldIndex = Math.max(0, Math.min(oldBodyOffsets.length - 1, marking.chapterIndex));
      const oldChapterStart = oldBodyOffsets[oldIndex] ?? 0;
      const startAbsolute = Math.max(0, Math.min(contentLength, oldChapterStart + marking.chapterPosition));
      const endAbsolute = Math.max(startAbsolute, Math.min(contentLength, oldChapterStart + marking.endPosition));
      // 起止可能被新目录切到不同章节，此时以起点所在章节为准，把终点夹在该章末尾，
      // 避免产生 endPosition 小于 chapterPosition 的非法记录。
      const startPair = relocate(startAbsolute);
      const chapterIndex = startPair[0] ?? 0;
      const chapterPosition = startPair[1] ?? 0;
      const chapterStart = newBodyOffsets[chapterIndex] ?? 0;
      const chapterEnd = newBodyOffsets[chapterIndex + 1] ?? contentLength;
      const endPosition = Math.max(chapterPosition,
        Math.min(chapterEnd - chapterStart, endAbsolute - chapterStart));
      const chapterName = nextBook.chapterTitles?.[chapterIndex] ?? marking.chapterName;
      if (chapterIndex === marking.chapterIndex && chapterPosition === marking.chapterPosition &&
        endPosition === marking.endPosition && chapterName === marking.chapterName) {
        nextMarkings.push(marking);
        continue;
      }
      changed = true;
      nextMarkings.push({
        id: marking.id,
        bookId: marking.bookId,
        bookName: marking.bookName,
        bookAuthor: marking.bookAuthor,
        bookUrl: marking.bookUrl,
        chapterIndex: chapterIndex,
        chapterName: chapterName,
        chapterPosition: chapterPosition,
        endPosition: endPosition,
        selectedText: marking.selectedText,
        contextBefore: marking.contextBefore,
        contextAfter: marking.contextAfter,
        effect: marking.effect,
        color: marking.color,
        note: marking.note,
        enabled: marking.enabled,
        createdAt: marking.createdAt,
        updatedAt: marking.updatedAt
      });
    }
    return changed ? nextMarkings : this.readerMarkings;
  }

  /**
   * 重新识别当前这本书的目录，对应上游目录页「更新目录」菜单项。
   *
   * 与书架级批量更新共用 BookRepository.refreshToc，差别只在范围是一本书，
   * 且同时重映射书签与划线/笔记。
   */
  private async refreshCurrentToc(): Promise<void> {
    const book = this.selectedBook;
    if (!book.isLocal || book.format !== 'txt' || book.contentPath === undefined) {
      this.showUnavailableAction('仅本地 TXT 书籍支持更新目录');
      return;
    }
    const context = this.getUIContext().getHostContext();
    if (context === undefined) {
      this.showUnavailableAction('无法访问本地书架，未更新目录');
      return;
    }
    let result: TocRefreshResult;
    try {
      result = BookRepository.refreshToc(book, this.readerMaxLengthWithNoToc);
    } catch (_) {
      this.showUnavailableAction('读取正文失败，目录未更新');
      return;
    }
    if (!result.changed) {
      this.showUnavailableAction('目录没有变化');
      return;
    }
    const nextBook = result.book;
    const nextBookmarks = this.remapNoTocBookmarks(book, nextBook,
      result.oldBodyOffsets, result.newBodyOffsets, result.content.length);
    const nextMarkings = this.remapNoTocMarkings(book, nextBook,
      result.oldBodyOffsets, result.newBodyOffsets, result.content.length);
    const updatedBooks = this.books.map((item: Book) => item.id === nextBook.id ? nextBook : item);
    let bookmarksSaved = false;
    let markingsSaved = false;
    try {
      if (nextBookmarks !== this.readerBookmarks) {
        await ReaderBookmarkRepository.save(context, nextBookmarks);
        bookmarksSaved = true;
      }
      if (nextMarkings !== this.readerMarkings) {
        await ReaderMarkingRepository.save(context, nextMarkings);
        markingsSaved = true;
      }
      await BookRepository.saveImportedBooks(context,
        updatedBooks.filter((item: Book) => BookRepository.isPersistableBook(item)));
    } catch (_) {
      // 中途失败时把已写入的部分回滚，避免书签/划线落在新旧两套目录上。
      if (bookmarksSaved) {
        try { await ReaderBookmarkRepository.save(context, this.readerBookmarks); } catch (_) {}
      }
      if (markingsSaved) {
        try { await ReaderMarkingRepository.save(context, this.readerMarkings); } catch (_) {}
      }
      this.showUnavailableAction('目录已更新，但保存失败，重新打开后可能回到旧目录');
      return;
    }
    this.books = updatedBooks;
    this.readerBookmarks = nextBookmarks;
    this.readerMarkings = nextMarkings;
    this.selectedBook = nextBook;
    const chapterCount = nextBook.chapterTitles?.length ?? 0;
    this.showUnavailableAction(`更新目录完成：共 ${chapterCount} 章`);
  }
  private async openBook(book: Book): Promise<void> {
    if (book.contentPath === undefined) {
      this.showUnavailableAction(book.bodyMissing === true
        ? '已恢复书目和阅读位置；备份不含正文，请重新选择原书文件后阅读'
        : '此书暂时没有可用正文');
      return;
    }
    let openedBook: Book = book;
    let content: string = '';
    try {
      const noTocRefresh = BookRepository.refreshNoTocBook(book, this.readerMaxLengthWithNoToc);
      openedBook = noTocRefresh.book;
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
        const updatedBookmarks = this.remapNoTocBookmarks(book, openedBook,
          noTocRefresh.oldBodyOffsets, noTocRefresh.newBodyOffsets, noTocRefresh.content.length);
        const updatedMarkings = this.remapNoTocMarkings(book, openedBook,
          noTocRefresh.oldBodyOffsets, noTocRefresh.newBodyOffsets, noTocRefresh.content.length);
        let bookmarksSaved = false;
        let markingsSaved = false;
        try {
          if (updatedBookmarks !== this.readerBookmarks) {
            await ReaderBookmarkRepository.save(context, updatedBookmarks);
            bookmarksSaved = true;
          }
          if (updatedMarkings !== this.readerMarkings) {
            await ReaderMarkingRepository.save(context, updatedMarkings);
            markingsSaved = true;
          }
          await BookRepository.saveImportedBooks(context,
            updatedBooks.filter((item: Book) => BookRepository.isPersistableBook(item)));
        } catch (error) {
          if (bookmarksSaved) {
            try { await ReaderBookmarkRepository.save(context, this.readerBookmarks); } catch (_) {}
          }
          if (markingsSaved) {
            try { await ReaderMarkingRepository.save(context, this.readerMarkings); } catch (_) {}
          }
          this.showUnavailableAction(error instanceof Error
            ? '无目录分段设置保存失败：' + error.message : '无目录分段设置保存失败');
          return;
        }
        this.books = updatedBooks;
        this.readerBookmarks = updatedBookmarks;
        this.readerMarkings = updatedMarkings;
      }
    } catch (error) {
      this.showUnavailableAction(error instanceof Error ? '打开失败：' + error.message : '本地书籍文件无法读取');
      return;
    }
    this.readerReturnRoute = this.route;
    this.discardReaderAnchor();
    this.readerStartAtChapterBeginning = true;
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
      this.books = nextBooks;
      this.bookGroups = BookGroupRepository.getAll();
    } catch (error) {
      this.showUnavailableAction(error instanceof Error ? error.message : '删除分组失败');
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
    const updatedBook: Book = {
      id: currentBook.id,
      title: title,
      author: author,
      category: category,
      groupName: groupNames.length > 0 ? groupNames.join('、') : '本地未分组',
      groupNames: groupNames,
      chapterTitles: currentBook.chapterTitles,
      chapterOffsets: currentBook.chapterOffsets,
      chapterVolumes: currentBook.chapterVolumes,
      chapterIndex: currentBook.chapterIndex,
      chapterProgress: currentBook.chapterProgress,
      lastChapter: currentBook.lastChapter,
      progress: currentBook.progress,
      coverColor: currentBook.coverColor,
      coverMark: currentBook.coverUri === undefined || currentBook.coverUri.length === 0
        ? (title.substring(0, 1) || '书') : currentBook.coverMark,
      coverUri: currentBook.coverUri,
      customCoverUri: currentBook.customCoverUri,
      bookType: bookType,
      fixedType: fixedType,
      contentPath: currentBook.contentPath,
      format: currentBook.format,
      chapterCount: currentBook.chapterCount,
      fileSizeBytes: currentBook.fileSizeBytes,
      imageStyle: currentBook.imageStyle,
      reSegment: currentBook.reSegment,
      charset: currentBook.charset,
      description: description,
      remark: remark,
      customTag: customTag,
      bodyMissing: currentBook.bodyMissing,
      androidOriginalPath: currentBook.androidOriginalPath,
      androidCharacterPosition: currentBook.androidCharacterPosition,
      readerPositionVersion: currentBook.readerPositionVersion,
      tocRule: currentBook.tocRule,
      isLocal: currentBook.isLocal
    };
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

  private async removeLocalBookFromShelf(book: Book): Promise<void> {
    if (book.contentPath === undefined && book.bodyMissing !== true) {
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
      await BookRepository.saveImportedBooks(context, booksToSave);
    } catch (error) {
      this.showUnavailableAction(error instanceof Error ? error.message : '移出书架失败，原书籍仍保留');
      return;
    }
    this.books = remainingBooks;
    this.route = this.bookInfoReturnRoute;
    if (book.contentPath !== undefined) {
      try {
        BookRepository.discardImportedCopy(book);
      } catch (_) {
        this.showUnavailableAction('已从书架移除，但应用内副本清理失败');
      }
    }
  }

  private async openCatalogFromBookInfo(): Promise<void> {
    const chapters = this.selectedBook.chapterTitles ?? [];
    if (this.selectedBook.contentPath === undefined || chapters.length === 0) {
      this.showUnavailableAction(this.selectedBook.bodyMissing === true
        ? 'Android 备份不含章节目录或正文，请重新导入原书文件后查看'
        : '这本书暂时没有可查看的本地目录');
      return;
    }
    const chapterIndex = Math.max(0, Math.min(chapters.length - 1, this.selectedBook.chapterIndex ?? 0));
    const chapterTitle = this.selectedBook.chapterTitles?.[chapterIndex];
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
    const chapterTitles = this.selectedBook.chapterTitles ?? [this.selectedChapter];
    const chapterIndex = Math.max(0, Math.min(chapterTitles.length - 1,
      this.selectedBook.chapterIndex ?? chapterTitles.indexOf(this.selectedChapter)));
    const chapterCount = Math.max(1, chapterTitles.length);
    const safeChapterProgress = Math.max(0, Math.min(100, chapterProgress));
    const updatedBook: Book = {
      id: this.selectedBook.id,
      title: this.selectedBook.title,
      author: this.selectedBook.author,
      category: this.selectedBook.category,
      groupName: this.selectedBook.groupName,
      groupNames: this.selectedBook.groupNames,
      chapterTitles: this.selectedBook.chapterTitles,
      chapterOffsets: this.selectedBook.chapterOffsets,
      chapterVolumes: this.selectedBook.chapterVolumes,
      chapterIndex: chapterIndex,
      chapterProgress: safeChapterProgress,
      lastChapter: this.selectedChapter,
      progress: (chapterIndex + safeChapterProgress / 100) / chapterCount * 100,
      coverColor: this.selectedBook.coverColor,
      coverMark: this.selectedBook.coverMark,
      coverUri: this.selectedBook.coverUri,
      customCoverUri: this.selectedBook.customCoverUri,
      bookType: this.selectedBook.bookType,
      fixedType: this.selectedBook.fixedType,
      contentPath: this.selectedBook.contentPath,
      format: this.selectedBook.format,
      chapterCount: this.selectedBook.chapterCount,
      fileSizeBytes: this.selectedBook.fileSizeBytes,
      imageStyle: this.selectedBook.imageStyle,
      reSegment: this.selectedBook.reSegment,
      charset: this.selectedBook.charset,
      description: this.selectedBook.description,
      remark: this.selectedBook.remark,
      customTag: this.selectedBook.customTag,
      bodyMissing: this.selectedBook.bodyMissing,
      androidOriginalPath: this.selectedBook.androidOriginalPath,
      androidCharacterPosition: Math.max(0, Math.trunc(chapterPosition)),
      readerPositionVersion: this.selectedBook.isLocal && (this.selectedBook.format === 'txt' ||
        this.selectedBook.format === 'epub') ? (androidCoordinate ? 2 : 0) : this.selectedBook.readerPositionVersion,
      tocRule: this.selectedBook.tocRule,
      latestChapterTime: this.selectedBook.latestChapterTime,
      // 保存阅读进度就是「刚读过」，用来驱动书架的按最近列表 / 综合排序。
      durChapterTime: Date.now(),
      order: this.selectedBook.order,
      isLocal: this.selectedBook.isLocal
    };
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
    const updatedBook: Book = {
      id: this.selectedBook.id,
      title: this.selectedBook.title,
      author: this.selectedBook.author,
      category: this.selectedBook.category,
      groupName: this.selectedBook.groupName,
      groupNames: this.selectedBook.groupNames,
      chapterTitles: this.selectedBook.chapterTitles,
      chapterOffsets: this.selectedBook.chapterOffsets,
      chapterVolumes: this.selectedBook.chapterVolumes,
      chapterIndex: this.selectedBook.chapterIndex,
      chapterProgress: this.selectedBook.chapterProgress,
      lastChapter: this.selectedBook.lastChapter,
      progress: this.selectedBook.progress,
      coverColor: this.selectedBook.coverColor,
      coverMark: this.selectedBook.coverMark,
      coverUri: this.selectedBook.coverUri,
      customCoverUri: this.selectedBook.customCoverUri,
      bookType: this.selectedBook.bookType,
      fixedType: this.selectedBook.fixedType,
      contentPath: this.selectedBook.contentPath,
      format: this.selectedBook.format,
      chapterCount: this.selectedBook.chapterCount,
      fileSizeBytes: this.selectedBook.fileSizeBytes,
      imageStyle: imageStyle,
      reSegment: this.selectedBook.reSegment,
      charset: this.selectedBook.charset,
      description: this.selectedBook.description,
      remark: this.selectedBook.remark,
      customTag: this.selectedBook.customTag,
      bodyMissing: this.selectedBook.bodyMissing,
      androidOriginalPath: this.selectedBook.androidOriginalPath,
      androidCharacterPosition: this.selectedBook.androidCharacterPosition,
      readerPositionVersion: this.selectedBook.readerPositionVersion,
      tocRule: this.selectedBook.tocRule,
      isLocal: this.selectedBook.isLocal
    };
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
    const chapterTitles = updatedBook.chapterTitles ?? [];
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
    let content: string;
    let chapterTitle: string;
    try {
      updatedBook = BookRepository.withCharset(this.selectedBook, charset, this.readerMaxLengthWithNoToc);
      const titles = updatedBook.chapterTitles ?? [];
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
    const chapterTitles = this.selectedBook.chapterTitles ?? [this.selectedChapter];
    const currentChapterIndex = this.selectedBook.chapterIndex ?? chapterTitles.indexOf(this.selectedChapter);
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
    const chapterTitles = originBook.chapterTitles ?? [];
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
    const chapterTitles = this.selectedBook.chapterTitles ?? [title];
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
    const updatedBook: Book = {
      id: this.selectedBook.id,
      title: this.selectedBook.title,
      author: this.selectedBook.author,
      category: this.selectedBook.category,
      groupName: this.selectedBook.groupName,
      groupNames: this.selectedBook.groupNames,
      chapterTitles: this.selectedBook.chapterTitles,
      chapterOffsets: this.selectedBook.chapterOffsets,
      chapterVolumes: this.selectedBook.chapterVolumes,
      chapterIndex: chapterIndex,
      chapterProgress: Math.max(0, Math.min(100, initialProgress)),
      lastChapter: title,
      progress: (chapterIndex + Math.max(0, Math.min(100, initialProgress)) / 100) / chapterCount * 100,
      coverColor: this.selectedBook.coverColor,
      coverMark: this.selectedBook.coverMark,
      coverUri: this.selectedBook.coverUri,
      customCoverUri: this.selectedBook.customCoverUri,
      bookType: this.selectedBook.bookType,
      fixedType: this.selectedBook.fixedType,
      contentPath: this.selectedBook.contentPath,
      format: this.selectedBook.format,
      chapterCount: this.selectedBook.chapterCount,
      fileSizeBytes: this.selectedBook.fileSizeBytes,
      imageStyle: this.selectedBook.imageStyle,
      reSegment: this.selectedBook.reSegment,
      charset: this.selectedBook.charset,
      description: this.selectedBook.description,
      remark: this.selectedBook.remark,
      customTag: this.selectedBook.customTag,
      bodyMissing: this.selectedBook.bodyMissing,
      androidOriginalPath: this.selectedBook.androidOriginalPath,
      androidCharacterPosition: 0,
      readerPositionVersion: 1,
      tocRule: this.selectedBook.tocRule,
      isLocal: this.selectedBook.isLocal
    };
    let content: string = '';
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
  }
  private async saveReaderChapterContent(chapterIndex: number, title: string, body: string): Promise<void> {
    const context = this.getUIContext().getHostContext();
    if (context === undefined) {
      this.showUnavailableAction('无法访问本地书籍');
      return;
    }
    try {
      const updatedBook = BookRepository.replaceLocalChapter(this.selectedBook, chapterIndex, title, body);
      const updatedBooks = this.books.map((book: Book) => book.id === updatedBook.id ? updatedBook : book);
      await BookRepository.saveImportedBooks(context,
        updatedBooks.filter((book: Book) => BookRepository.isPersistableBook(book)));
      const chapterTitle = updatedBook.chapterTitles?.[chapterIndex] ?? title;
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
    return destination === ProfileRoute.APP_THEME_SETTINGS || destination === ProfileRoute.APP_OTHER_SETTINGS ||
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
      (this.selectedBook.chapterTitles ?? []).indexOf(this.selectedChapter);
    if (this.selectedBook.id !== bookId || currentChapterIndex !== chapterIndex) { return; }
    this.updateReadingProgress(chapterProgress, chapterPosition, androidCoordinate);
  }

  build() {
    Column() {
      if (!this.onboardingLoaded) {
        Column() {
          LoadingProgress().width(28).height(28).color('#AFC2FF')
        }.width('100%').height('100%').justifyContent(FlexAlign.Center)
      } else if (!this.onboardingComplete) {
        OnboardingPage({
          localBooksPath: `${this.getAppFilesDirectory()}/books`,
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
          onRefreshToc: () => this.refreshAllToc(),
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
          onBack: () => this.route = this.bookInfoReturnRoute,
          onRead: () => this.openBook(this.selectedBook),
          onOpenCatalog: () => this.openCatalogFromBookInfo(),
          onOpenReadRecords: () => this.openProfileDetail(ProfileRoute.READ_RECORDS),
          onRemoveFromShelf: () => this.removeLocalBookFromShelf(this.selectedBook),
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
          ReaderPage({
            startAtChapterBeginning: this.readerStartAtChapterBeginning,
            book: this.selectedBook,
            bookmarks: this.readerBookmarks,
            markings: this.readerMarkings.filter((marking: ReaderMarking) =>
              marking.bookId === this.selectedBook.id && marking.chapterIndex ===
                Math.max(0, this.selectedBook.chapterIndex ?? (this.selectedBook.chapterTitles ?? []).indexOf(this.selectedChapter))),
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
        textFullJustify: this.readerTextFullJustify,
        textBottomJustify: this.readerTextBottomJustify,
            imageStyle: this.selectedBook.imageStyle ?? 'DEFAULT',
            paperColor: this.getPaperColor(),
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
            paddingSettings: this.readerPaddingSettings,
            screenOrientation: this.readerScreenOrientation,
            keepLight: this.readerKeepLight,
            volumeKeyPage: this.readerVolumeKeyPage,
            keyPageOnLongPress: this.readerKeyPageOnLongPress,
            noAnimScrollPage: this.readerNoAnimScrollPage,
            readingAnchorAvailable: this.readerReadingAnchorEnabled && this.readerAnchorJumpCount >= 2,
            readingAnchorEnabled: this.readerReadingAnchorEnabled,
        swipeToAddBookmark: this.readerSwipeToAddBookmark,
        bookmarkBadgeSize: this.readerBookmarkBadgeSize,
        bookmarkBadgeImage: this.readerBookmarkBadgeImage,
        selectText: this.readerSelectText,
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
            onImageStyleChange: (imageStyle: string) => this.setReaderImageStyle(imageStyle),
            onOpenSettings: () => this.openReaderSettings(),
            onOpenBottomActionConfig: () => this.openReaderSettings(true),
            onCharsetChange: (charset: string) => this.setReaderCharset(charset),
            onOpenSearchContent: () => this.openReaderSearch(),
            onOpenReadAloud: () => this.openReadAloudSettings(),
            onOpenTocRule: () => this.openProfileDetail(ProfileRoute.TXT_TOC_RULES),
            onToggleNightMode: () => this.toggleReaderNightMode(),
            onToggleEyeProtection: () => this.toggleEyeProtection(),
            onMoreActionsChange: (actions: ReaderMoreActionConfig[]) => this.setReaderMoreActions(actions),
            onUnavailableAction: (message: string) => this.showUnavailableAction(message),
            onProgressChange: (bookId: string, chapterIndex: number, progress: number,
              position: number, androidCoordinate: boolean) =>
              this.acceptReaderProgress(bookId, chapterIndex, progress, position, androidCoordinate),
            onAddBookmark: (position: number, pageText: string) => this.requestAddReaderBookmark(position, pageText),
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
            onContentProcessToggle: (id: string, enabled: boolean) => this.setReaderContentProcessEnabled(id, enabled),
            onContentProcessDelete: (id: string) => this.deleteReaderContentProcess(id),
            bookmarkTargetPosition: this.readerBookmarkTargetPosition,
            bookmarkTargetRevision: this.readerBookmarkTargetRevision,
            onBookmarkTargetConsumed: () => this.readerBookmarkTargetPosition = -1,
            onSelectChapterIndex: (chapterIndex: number) => {
              const chapters = this.selectedBook.chapterTitles ?? [];
              const title = chapters[chapterIndex];
              if (title !== undefined) {
                this.selectChapter(title, chapterIndex);
              } else {
                const currentIndex = this.selectedBook.chapterIndex ?? chapters.indexOf(this.selectedChapter);
                this.showUnavailableAction(chapterIndex < currentIndex ? '没有上一页' : '没有下一页');
              }
            },
            onTurnChapterBoundary: (delta: number) => {
              const chapters = this.selectedBook.chapterTitles ?? [];
              const currentIndex = this.selectedBook.chapterIndex ?? chapters.indexOf(this.selectedChapter);
              const targetIndex = currentIndex + delta;
              const targetTitle = chapters[targetIndex];
              if (targetTitle !== undefined) {
                this.selectChapter(targetTitle, targetIndex, delta < 0 ? 100 : 0);
              } else {
                this.showUnavailableAction(delta < 0 ? '没有上一页' : '没有下一页');
              }
            }
          })
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
              onOpenTxtTocRules: (): void => this.openProfileDetail(ProfileRoute.TXT_TOC_RULES),
              onUnavailableAction: (message: string) => this.showUnavailableAction(message),
              onSelectChapter: (chapterIndex: number) => {
              const chapterTitle = this.selectedBook.chapterTitles?.[chapterIndex];
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
        textFullJustify: this.readerTextFullJustify,
        textBottomJustify: this.readerTextBottomJustify,
              paperIndex: this.paperIndex,
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
              readingAnchorEnabled: this.readerReadingAnchorEnabled,
        swipeToAddBookmark: this.readerSwipeToAddBookmark,
        bookmarkBadgeSize: this.readerBookmarkBadgeSize,
        bookmarkBadgeImage: this.readerBookmarkBadgeImage,
        selectText: this.readerSelectText,
        maxLengthWithNoToc: this.readerMaxLengthWithNoToc,
              onNoAnimScrollPageChange: (enabled: boolean) => this.setReaderNoAnimScrollPage(enabled),
              onReadingAnchorEnabledChange: (enabled: boolean) => this.setReaderReadingAnchorEnabled(enabled),
              onSwipeToAddBookmarkChange: (enabled: boolean) => this.setReaderSwipeToAddBookmark(enabled),
              onBookmarkBadgeSizeChange: (value: number) => this.setReaderBookmarkBadgeSize(value),
              onPickBookmarkBadgeImage: (): void => { this.pickReaderBookmarkBadgeImage(); },
              onResetBookmarkBadgeImage: (): void => this.resetReaderBookmarkBadgeImage(),
              onSelectTextChange: (enabled: boolean) => this.setReaderSelectText(enabled),
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
        } else if (this.route === AppRoute.READER_SEARCH) {
        ReaderSearchPage({
          book: this.selectedBook,
          bookTitle: this.selectedBook.title,
          onReplaceRulesChanged: () => this.replaceRules = ReplaceRuleRepository.getAll(),
          onBack: () => this.route = AppRoute.READER,
          onOpenResult: (chapterIndex: number, position: number) =>
            this.openReaderSearchResult(chapterIndex, position),
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
            onAddGroup: (name: string) => this.addReplaceRuleGroup(name),
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
            onAddGroup: (name: string) => this.addReplaceRuleGroup(name),
            onRenameGroup: (oldName: string, newName: string) => this.renameReplaceRuleGroup(oldName, newName),
            onRemoveGroup: (name: string) => this.removeReplaceRuleGroup(name),
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
            onRecordsChanged: async () => {
              const context = this.getUIContext().getHostContext();
              if (context !== undefined) { await this.reloadReadRecordData(context); }
            }
          })
        } else if (this.profileSubpage === ProfileRoute.CACHE_MANAGEMENT) {
          CacheManagementPage({
            groups: this.cacheManagementGroups(),
            onBack: () => this.route = this.profileDetailReturnRoute,
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
            onUnavailableAction: (message: string) => this.showUnavailableAction(message)
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
        textFullJustify: this.readerTextFullJustify,
        textBottomJustify: this.readerTextBottomJustify,
            paperIndex: this.paperIndex,
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
            readingAnchorEnabled: this.readerReadingAnchorEnabled,
        swipeToAddBookmark: this.readerSwipeToAddBookmark,
        bookmarkBadgeSize: this.readerBookmarkBadgeSize,
        bookmarkBadgeImage: this.readerBookmarkBadgeImage,
        selectText: this.readerSelectText,
        maxLengthWithNoToc: this.readerMaxLengthWithNoToc,
            onNoAnimScrollPageChange: (enabled: boolean) => this.setReaderNoAnimScrollPage(enabled),
            onReadingAnchorEnabledChange: (enabled: boolean) => this.setReaderReadingAnchorEnabled(enabled),
              onSwipeToAddBookmarkChange: (enabled: boolean) => this.setReaderSwipeToAddBookmark(enabled),
              onBookmarkBadgeSizeChange: (value: number) => this.setReaderBookmarkBadgeSize(value),
              onPickBookmarkBadgeImage: (): void => { this.pickReaderBookmarkBadgeImage(); },
              onResetBookmarkBadgeImage: (): void => this.resetReaderBookmarkBadgeImage(),
              onSelectTextChange: (enabled: boolean) => this.setReaderSelectText(enabled),
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
            onUnavailableAction: (message: string) => this.showUnavailableAction(message)
          })
        } else if (this.profileSubpage === ProfileRoute.APP_DOWNLOAD_CACHE_SETTINGS) {
          AppDownloadCacheSettingsPage({
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
            onCreateBackup: () => this.createLocalBackup(),
            onSelectRestore: () => this.selectLocalBackup(),
            onApplyRestore: () => this.restoreLocalBackup(),
            onCancelRestore: () => this.cancelLocalBackupRestore(),
            onToggleBackupIgnore: (key: string, ignored: boolean) => this.toggleBackupIgnore(key, ignored),
            onToggleRestoreIgnore: (key: string, ignored: boolean) => this.toggleRestoreIgnore(key, ignored),
            onUnavailableAction: (message: string) => this.showUnavailableAction(message)
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
        textFullJustify: this.readerTextFullJustify,
        textBottomJustify: this.readerTextBottomJustify,
            paperIndex: this.paperIndex,
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
            readingAnchorEnabled: this.readerReadingAnchorEnabled,
        swipeToAddBookmark: this.readerSwipeToAddBookmark,
        bookmarkBadgeSize: this.readerBookmarkBadgeSize,
        bookmarkBadgeImage: this.readerBookmarkBadgeImage,
        selectText: this.readerSelectText,
        maxLengthWithNoToc: this.readerMaxLengthWithNoToc,
            onNoAnimScrollPageChange: (enabled: boolean) => this.setReaderNoAnimScrollPage(enabled),
            onReadingAnchorEnabledChange: (enabled: boolean) => this.setReaderReadingAnchorEnabled(enabled),
              onSwipeToAddBookmarkChange: (enabled: boolean) => this.setReaderSwipeToAddBookmark(enabled),
              onBookmarkBadgeSizeChange: (value: number) => this.setReaderBookmarkBadgeSize(value),
              onPickBookmarkBadgeImage: (): void => { this.pickReaderBookmarkBadgeImage(); },
              onResetBookmarkBadgeImage: (): void => this.resetReaderBookmarkBadgeImage(),
              onSelectTextChange: (enabled: boolean) => this.setReaderSelectText(enabled),
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
        textFullJustify: this.readerTextFullJustify,
        textBottomJustify: this.readerTextBottomJustify,
          paperIndex: this.paperIndex,
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
          readingAnchorEnabled: this.readerReadingAnchorEnabled,
        swipeToAddBookmark: this.readerSwipeToAddBookmark,
        bookmarkBadgeSize: this.readerBookmarkBadgeSize,
        bookmarkBadgeImage: this.readerBookmarkBadgeImage,
        selectText: this.readerSelectText,
        maxLengthWithNoToc: this.readerMaxLengthWithNoToc,
          onNoAnimScrollPageChange: (enabled: boolean) => this.setReaderNoAnimScrollPage(enabled),
          onReadingAnchorEnabledChange: (enabled: boolean) => this.setReaderReadingAnchorEnabled(enabled),
              onSwipeToAddBookmarkChange: (enabled: boolean) => this.setReaderSwipeToAddBookmark(enabled),
              onBookmarkBadgeSizeChange: (value: number) => this.setReaderBookmarkBadgeSize(value),
              onPickBookmarkBadgeImage: (): void => { this.pickReaderBookmarkBadgeImage(); },
              onResetBookmarkBadgeImage: (): void => this.resetReaderBookmarkBadgeImage(),
              onSelectTextChange: (enabled: boolean) => this.setReaderSelectText(enabled),
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
          onQuickActionsChange: (enabled: boolean) => this.setReaderQuickActions(enabled)
        })
        }
        // 书签编辑面板挂在外层 Stack，阅读页与「所有书签」页都能唤起
        if (this.bookmarkEditor !== undefined) {
          ReaderBookmarkEditor({
            bookmark: this.bookmarkEditor,
            isNew: this.bookmarkEditorIsNew,
            onSave: (note: string, bookText: string) => this.saveReaderBookmarkNote(note, bookText),
            onDelete: () => this.deleteReaderBookmark(),
            onClose: () => this.bookmarkEditor = undefined
          })
        }
      }.width('100%').layoutWeight(1)
      if (this.route === AppRoute.HOME || this.route === AppRoute.BOOKSHELF || this.route === AppRoute.DISCOVER || this.route === AppRoute.SUBSCRIPTIONS || this.route === AppRoute.PROFILE) {
        Row() {
          TabItem({ icon: this.selectedTab === 0 ? 'navHomeFilled' : 'navHomeOutlined', label: '首页', selected: this.selectedTab === 0 }).width('20%').onClick(() => this.selectTab(0))
          TabItem({ icon: this.selectedTab === 1 ? 'navBookshelfFilled' : 'navBookshelfOutlined', label: '书架', selected: this.selectedTab === 1 }).width('20%').onClick(() => this.selectTab(1))
          TabItem({ icon: this.selectedTab === 2 ? 'navExploreFilled' : 'navExploreOutlined', label: '发现', selected: this.selectedTab === 2 }).width('20%').onClick(() => this.selectTab(2))
          TabItem({ icon: 'navRss', label: '订阅', selected: this.selectedTab === 3 }).width('20%').onClick(() => this.selectTab(3))
          TabItem({ icon: this.selectedTab === 4 ? 'navProfileFilled' : 'navProfileOutlined', label: '我的', selected: this.selectedTab === 4 }).width('20%').onClick(() => this.selectTab(4))
        }.width('100%').padding({ top: 7, bottom: 6 }).backgroundColor('#1C1D23')
          .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM])
      }
      }
    }.width('100%').height('100%').backgroundColor('#111217')
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM])
      .sepia(this.isEyeProtectionActive() ? this.eyeProtectionIntensity / 100 : 0)
  }
}

@Component
struct TabItem {
  @Prop icon: AppGlyphName = 'home';
  @Prop label: string = '';
  @Prop selected: boolean = false;
  build() {
    Column() {
      Stack({ alignContent: Alignment.Center }) {
        AppGlyph({ name: this.icon, tint: '#C5C7D0', glyphSize: 20 })
      }.width(50).height(32).backgroundColor(this.selected ? '#3A4054' : Color.Transparent).borderRadius(18)
      if (this.selected) { Text(this.label).fontSize(10).fontColor('#D7DFFB').margin({ top: 2 }) }
    }.width('100%').alignItems(HorizontalAlign.Center).padding({ top: 1, bottom: 1 })
  }
}














