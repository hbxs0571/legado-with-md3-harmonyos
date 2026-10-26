import { AppRoute, Book, ProfileRoute } from '../model/Book';
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
  AboutAppPage, AiChatPage, AppSettingsHomePage, BookmarkBookSummary, BookmarkEntrySummary
} from './ProfileSubPages';
import { ReaderSearchPage } from './ReaderSearchPage';
import { ReaderAloudSettingsPage } from './ReaderAloudSettingsPage';
import { BookInfoPage } from './BookInfoPage';
import { ThemeSettingsPage } from './ThemeSettingsPage';
import { OtherSettingsPage } from './OtherSettingsPage';
import { AppReadSettingsPage } from './AppReadSettingsPage';
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
import {
  HomeDashboardSection, HOME_DASHBOARD_SECTIONS, HomeDashboardSettingsRepository
} from '../data/HomeDashboardSettingsRepository';
import { OnboardingRepository } from '../data/OnboardingRepository';
import {
  ReaderBottomActionConfig, ReaderSettingsRepository, ReaderSettingsSnapshot, READER_BACKGROUND_STYLES,
  READER_LOCAL_BOTTOM_ACTION_DEFAULTS, READER_LOCAL_TOP_ACTION_DEFAULTS,
  ReaderInfoSettings, DEFAULT_READER_INFO_SETTINGS, copyReaderInfoSettings, updateReaderInfoSettings
} from '../data/ReaderSettingsRepository';
import { ReaderMoreActionConfig, ReaderMoreActionsRepository, READER_MORE_ACTION_DEFAULTS } from '../data/ReaderMoreActionsRepository';
import {
  BackupCategoryOption, BackupEntryPreview, BackupIgnoreLists, BackupPreview, BackupRepository, BackupSelection
} from '../data/BackupRepository';
import { OnboardingPage } from './OnboardingPage';
import { ReaderBookmark } from '../model/ReaderBookmark';
import { ReaderBookmarkRepository } from '../data/ReaderBookmarkRepository';
import { ReplaceRuleRepository } from '../data/ReplaceRuleRepository';
import { BookContentProcessRepository } from '../data/BookContentProcessRepository';
import { ReplaceRule } from '../model/ReplaceRule';
import { LocalTextSemantics } from '../data/LocalTextSemantics';
import { ReaderBookmarkEditor } from './ReaderBookmarkEditor';
import { ReadTimeRecord, ReadTimeRepository } from '../data/ReadTimeRepository';

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
  @State selectedChapter: string = '';
  @State books: Book[] = [];
  @State readTimeRecords: ReadTimeRecord[] = [];
  @State readerBookmarks: ReaderBookmark[] = [];
  @State replaceRules: ReplaceRule[] = [];
  @State replaceEnableDefault: boolean = true;
  @State readerReplaceEnabled: boolean = true;
  @State readerReplaceUsesDefault: boolean = true;
  @State bookmarkEditor: ReaderBookmark | undefined = undefined;
  @State bookmarkEditorIsNew: boolean = true;
  @State readerBookmarkTargetPosition: number = -1;
  @State readerBookmarkTargetRevision: number = 0;
  @State readerContent: string = '';
  @State readerFontSize: number = 20;
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
  @State readerTocUseReplace: boolean = false;
  @State readerTocShowWordCount: boolean = true;
  @State readerClickImageBehavior: string = '2';
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
  private readerSettingsLoaded: boolean = false;
  private readerSettingsRevision: number = 0;
  private readerSessionLastSaveTime: number = 0;
  private readerLifecycleEventsRegistered: boolean = false;
  private readerSessionPaused: boolean = false;

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
      this.restoreReaderBookmarks(context);
      this.restoreReaderSettings(context);
      this.restoreReaderMoreActions(context);
      this.restoreReplaceRules(context);
      this.restoreBookContentProcesses(context);
      this.restoreBackupIgnoreLists(context);
      this.loadRestoredAndroidEntries(context);
    }
  }

  private async restoreReadTimeRecords(context: Context): Promise<void> {
    this.readTimeRecords = await ReadTimeRepository.load(context);
  }

  private getTotalReadTimeMs(): number {
    return this.readTimeRecords.reduce((total: number, record: ReadTimeRecord) => total + record.durationMs, 0);
  }

  private async startReaderSession(): Promise<void> {
    const context = this.getUIContext().getHostContext();
    if (context === undefined || this.selectedBook.id.length === 0) { return; }
    ReadTimeRepository.touch();
    await ReadTimeRepository.start(context, this.selectedBook);
    this.readerSessionPaused = false;
    this.readerSessionLastSaveTime = Date.now();
  }

  private async pulseReaderSession(): Promise<void> {
    if (this.readerSessionPaused) { return; }
    ReadTimeRepository.touch();
    const context = this.getUIContext().getHostContext();
    if (context === undefined || Date.now() - this.readerSessionLastSaveTime < 120000) { return; }
    await ReadTimeRepository.commit(context);
    await ReadTimeRepository.start(context, this.selectedBook);
    this.readerSessionLastSaveTime = Date.now();
    this.readTimeRecords = await ReadTimeRepository.load(context);
  }

  private async stopReaderSession(): Promise<void> {
    this.readerSessionPaused = true;
    ReadTimeRepository.touch();
    const context = this.getUIContext().getHostContext();
    if (context === undefined) { return; }
    await ReadTimeRepository.commit(context);
    this.readTimeRecords = await ReadTimeRepository.load(context);
  }

  private async restoreReplaceRules(context: Context): Promise<void> {
    this.replaceRules = await ReplaceRuleRepository.load(context);
    this.replaceEnableDefault = ReplaceRuleRepository.getDefaultEnabled();
    this.readerReplaceEnabled = ReplaceRuleRepository.isBookEnabled(this.selectedBook);
    this.readerReplaceUsesDefault = ReplaceRuleRepository.isBookUsingDefault(this.selectedBook);
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
    const groups: string[] = ['默认'];
    this.replaceRules.forEach((rule: ReplaceRule) => {
      const group = rule.group.trim();
      if (group.length > 0 && group !== '默认' && !groups.includes(group)) { groups.push(group); }
    });
    return groups;
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

  private editReaderBookmark(bookmarkId: string): void {
    const record = this.readerBookmarks.find((bookmark: ReaderBookmark) => bookmark.id === bookmarkId);
    if (record === undefined) { return; }
    this.bookmarkEditor = record;
    this.bookmarkEditorIsNew = false;
  }

  private async saveReaderBookmarkNote(note: string): Promise<void> {
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
      bookText: draft.bookText,
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
      chapterTitles: targetBook.chapterTitles,
      chapterOffsets: targetBook.chapterOffsets,
      chapterIndex: chapterIndex,
      chapterProgress: chapterProgress,
      lastChapter: chapterTitle,
      progress: (chapterIndex + chapterProgress / 100) / chapterCount * 100,
      coverColor: targetBook.coverColor,
      coverMark: targetBook.coverMark,
      coverUri: targetBook.coverUri,
      contentPath: targetBook.contentPath,
      format: targetBook.format,
      chapterCount: targetBook.chapterCount,
      fileSizeBytes: targetBook.fileSizeBytes,
      imageStyle: targetBook.imageStyle,
      reSegment: targetBook.reSegment,
      charset: targetBook.charset,
      description: targetBook.description,
      bodyMissing: targetBook.bodyMissing,
      androidOriginalPath: targetBook.androidOriginalPath,
      androidCharacterPosition: position,
      readerPositionVersion: 1,
      isLocal: targetBook.isLocal
    };
    this.selectedBook = updatedBook;
    this.books = this.books.map((book: Book) => book.id === updatedBook.id ? updatedBook : book);
    this.selectedChapter = chapterTitle;
    this.readerContent = content;
    this.readerBookmarkTargetPosition = position;
    this.readerBookmarkTargetRevision++;
    this.bookmarkEditor = undefined;
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
    const semanticLength = LocalTextSemantics.fromRawBody(content).length;
    const position = Math.max(0, Math.min(semanticLength, chapterPosition));
    const chapterProgress = semanticLength > 0 ? position / semanticLength * 100 : 0;
    const chapterCount = Math.max(1, chapterTitles.length);
    const updatedBook: Book = {
      id: targetBook.id,
      title: targetBook.title,
      author: targetBook.author,
      category: targetBook.category,
      groupName: targetBook.groupName,
      chapterTitles: targetBook.chapterTitles,
      chapterOffsets: targetBook.chapterOffsets,
      chapterIndex: chapterIndex,
      chapterProgress: chapterProgress,
      lastChapter: chapterTitle,
      progress: (chapterIndex + chapterProgress / 100) / chapterCount * 100,
      coverColor: targetBook.coverColor,
      coverMark: targetBook.coverMark,
      coverUri: targetBook.coverUri,
      contentPath: targetBook.contentPath,
      format: targetBook.format,
      chapterCount: targetBook.chapterCount,
      fileSizeBytes: targetBook.fileSizeBytes,
      imageStyle: targetBook.imageStyle,
      reSegment: targetBook.reSegment,
      charset: targetBook.charset,
      description: targetBook.description,
      bodyMissing: targetBook.bodyMissing,
      androidOriginalPath: targetBook.androidOriginalPath,
      androidCharacterPosition: position,
      readerPositionVersion: 1,
      isLocal: targetBook.isLocal
    };
    this.selectedBook = updatedBook;
    this.books = this.books.map((book: Book) => book.id === updatedBook.id ? updatedBook : book);
    this.selectedChapter = chapterTitle;
    this.readerContent = content;
    this.readerBookmarkTargetPosition = position;
    this.readerBookmarkTargetRevision++;
    this.route = AppRoute.READER;
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
          bookmarkCount: 1, noteCount: 0
        });
      } else {
        const current = summaries[existingIndex];
        if (current !== undefined) {
          summaries[existingIndex] = {
            key: current.key, title: current.title, author: current.author,
            bookmarkCount: current.bookmarkCount + 1, noteCount: 0
          };
        }
      }
    }
    return summaries;
  }

  private getBookmarkEntrySummaries(): BookmarkEntrySummary[] {
    return this.readerBookmarks.map((bookmark: ReaderBookmark): BookmarkEntrySummary => ({
      id: bookmark.id,
      bookKey: bookmark.bookId,
      chapterName: bookmark.chapterName,
      excerpt: bookmark.bookText,
      note: bookmark.content,
      kind: 'bookmark'
    }));
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
      this.readerTocUseReplace = settings.tocUseReplace;
      this.readerTocShowWordCount = settings.tocShowWordCount;
      this.readerClickImageBehavior = settings.clickImageBehavior;
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
        tocUseReplace: this.readerTocUseReplace,
        tocShowWordCount: this.readerTocShowWordCount,
        clickImageBehavior: this.readerClickImageBehavior,
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

  private closeReaderImagePreview(): void {
    this.readerImagePreviewOpen = false;
  }

  private setReaderQuickActions(enabled: boolean): void {
    this.showReaderQuickActions = enabled;
    this.readerSettingsRevision += 1;
    if (this.readerSettingsLoaded) { this.persistReaderSettings(); }
  }

  private async restoreImportedBooks(context: Context): Promise<void> {
    const importedBooks = await BookRepository.loadImportedBooks(context);
    this.books = importedBooks;
  }

  private async createLocalBackup(): Promise<void> {
    const context = this.getUIContext().getHostContext();
    if (context === undefined || this.backupBusy) { return; }
    this.backupBusy = true;
    this.backupStatusMessage = '';
    try {
      const localBooks = this.books.filter((book: Book) => BookRepository.isPersistableBook(book));
      const settings = await ReaderSettingsRepository.load(context);
      const created = await BackupRepository.createBackup(context, localBooks, settings, this.backupIgnoreKeys);
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
      const result = await BackupRepository.restore(
        context, selection, localBooks, currentSettings, this.restoreIgnoreKeys
      );
      this.books = result.books;
      this.readerFontSize = result.settings.fontSize;
      this.paperIndex = result.settings.paperIndex;
      this.dayPaperIndex = result.settings.dayPaperIndex;
      this.nightPaperIndex = result.settings.nightPaperIndex;
      this.readerNightMode = result.settings.readerNightMode;
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
      this.backupStatusMessage = `导入完成：保留 ${result.preservedEntryCount} 个 Android 条目；更新 ${result.updatedLocalBookCount} 本已有正文书籍的进度，并创建 ${result.createdMissingBodyBookCount} 本缺正文书目。`;
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
      book = await BookRepository.importLocalBook(context);
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

  private getPaperColor(): string {
    const style = READER_BACKGROUND_STYLES[Math.max(0, Math.min(5, this.paperIndex))];
    return style === undefined ? '#000000' : (this.readerNightMode ? style.nightColor : style.dayColor);
  }
  private async openBook(book: Book): Promise<void> {
    if (book.contentPath === undefined) {
      this.showUnavailableAction(book.bodyMissing === true
        ? '已恢复书目和阅读位置；备份不含正文，请重新选择原书文件后阅读'
        : '此书暂时没有可用正文');
      return;
    }
    let content: string = '';
    try {
      content = await BookRepository.readChapter(book, book.lastChapter);
      this.replaceRules = ReplaceRuleRepository.getAll();
    } catch (error) {
      this.showUnavailableAction(error instanceof Error ? `打开失败：${error.message}` : '本地书籍文件无法读取');
      return;
    }
    this.readerReturnRoute = this.route;
    this.selectedBook = book;
    this.readerReplaceEnabled = ReplaceRuleRepository.isBookEnabled(book);
    this.readerReplaceUsesDefault = ReplaceRuleRepository.isBookUsingDefault(book);
    this.selectedChapter = book.lastChapter;
    this.readerContent = content;
    this.route = AppRoute.READER;
  }

  private openBookInfo(book: Book): void {
    this.bookInfoReturnRoute = this.route;
    this.selectedBook = book;
    this.route = AppRoute.BOOK_INFO;
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
      chapterTitles: this.selectedBook.chapterTitles,
      chapterOffsets: this.selectedBook.chapterOffsets,
      chapterIndex: chapterIndex,
      chapterProgress: safeChapterProgress,
      lastChapter: this.selectedChapter,
      progress: (chapterIndex + safeChapterProgress / 100) / chapterCount * 100,
      coverColor: this.selectedBook.coverColor,
      coverMark: this.selectedBook.coverMark,
      coverUri: this.selectedBook.coverUri,
      contentPath: this.selectedBook.contentPath,
      format: this.selectedBook.format,
      chapterCount: this.selectedBook.chapterCount,
      fileSizeBytes: this.selectedBook.fileSizeBytes,
      imageStyle: this.selectedBook.imageStyle,
      reSegment: this.selectedBook.reSegment,
      charset: this.selectedBook.charset,
      description: this.selectedBook.description,
      bodyMissing: this.selectedBook.bodyMissing,
      androidOriginalPath: this.selectedBook.androidOriginalPath,
      androidCharacterPosition: Math.max(0, Math.trunc(chapterPosition)),
      readerPositionVersion: this.selectedBook.isLocal && (this.selectedBook.format === 'txt' ||
        this.selectedBook.format === 'epub') ? (androidCoordinate ? 2 : 0) : this.selectedBook.readerPositionVersion,
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
      chapterTitles: this.selectedBook.chapterTitles,
      chapterOffsets: this.selectedBook.chapterOffsets,
      chapterIndex: this.selectedBook.chapterIndex,
      chapterProgress: this.selectedBook.chapterProgress,
      lastChapter: this.selectedBook.lastChapter,
      progress: this.selectedBook.progress,
      coverColor: this.selectedBook.coverColor,
      coverMark: this.selectedBook.coverMark,
      coverUri: this.selectedBook.coverUri,
      contentPath: this.selectedBook.contentPath,
      format: this.selectedBook.format,
      chapterCount: this.selectedBook.chapterCount,
      fileSizeBytes: this.selectedBook.fileSizeBytes,
      imageStyle: imageStyle,
      reSegment: this.selectedBook.reSegment,
      charset: this.selectedBook.charset,
      description: this.selectedBook.description,
      bodyMissing: this.selectedBook.bodyMissing,
      androidOriginalPath: this.selectedBook.androidOriginalPath,
      androidCharacterPosition: this.selectedBook.androidCharacterPosition,
      readerPositionVersion: this.selectedBook.readerPositionVersion,
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
      updatedBook = BookRepository.withCharset(this.selectedBook, charset);
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
    const chapterCount = Math.max(1, chapterTitles.length);
    const updatedBook: Book = {
      id: this.selectedBook.id,
      title: this.selectedBook.title,
      author: this.selectedBook.author,
      category: this.selectedBook.category,
      groupName: this.selectedBook.groupName,
      chapterTitles: this.selectedBook.chapterTitles,
      chapterOffsets: this.selectedBook.chapterOffsets,
      chapterIndex: chapterIndex,
      chapterProgress: Math.max(0, Math.min(100, initialProgress)),
      lastChapter: title,
      progress: (chapterIndex + Math.max(0, Math.min(100, initialProgress)) / 100) / chapterCount * 100,
      coverColor: this.selectedBook.coverColor,
      coverMark: this.selectedBook.coverMark,
      coverUri: this.selectedBook.coverUri,
      contentPath: this.selectedBook.contentPath,
      format: this.selectedBook.format,
      chapterCount: this.selectedBook.chapterCount,
      fileSizeBytes: this.selectedBook.fileSizeBytes,
      imageStyle: this.selectedBook.imageStyle,
      reSegment: this.selectedBook.reSegment,
      charset: this.selectedBook.charset,
      description: this.selectedBook.description,
      bodyMissing: this.selectedBook.bodyMissing,
      androidOriginalPath: this.selectedBook.androidOriginalPath,
      androidCharacterPosition: 0,
      readerPositionVersion: 1,
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
    this.selectedBook = updatedBook;
    this.selectedChapter = title;
    this.books = this.books.map((book: Book) => book.id === updatedBook.id ? updatedBook : book);
    this.readerContent = content;
    if (updatedBook.contentPath !== undefined) {
      const context = this.getUIContext().getHostContext();
      if (context !== undefined) {
        const importedBooks = this.books.filter((book: Book) => BookRepository.isPersistableBook(book));
        BookRepository.saveImportedBooks(context, importedBooks).catch(() => {
          this.showUnavailableAction('章节进度保存失败，重新打开后可能回到上次位置');
        });
      }
    }
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

  private createReaderProgressCallback(): (
    chapterProgress: number, chapterPosition: number, androidCoordinate: boolean
  ) => void {
    const renderedChapterTitle = this.selectedChapter;
    const renderedChapterIndex = this.selectedBook.chapterIndex ??
      (this.selectedBook.chapterTitles ?? []).indexOf(this.selectedChapter);
    return (chapterProgress: number, chapterPosition: number, androidCoordinate: boolean): void => {
      const currentChapterIndex = this.selectedBook.chapterIndex ??
        (this.selectedBook.chapterTitles ?? []).indexOf(this.selectedChapter);
      if (this.selectedChapter !== renderedChapterTitle || currentChapterIndex !== renderedChapterIndex) { return; }
      this.updateReadingProgress(chapterProgress, chapterPosition, androidCoordinate);
    };
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
          onOpenBook: (book: Book) => this.openBook(book),
          onOpenBookInfo: (book: Book) => this.openBookInfo(book),
          onSearch: () => this.openSearch(),
          onImportBook: () => this.importLocalBook(),
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
          onBack: () => this.route = this.bookInfoReturnRoute,
          onRead: () => this.openBook(this.selectedBook),
          onOpenCatalog: () => this.openCatalogFromBookInfo(),
          onOpenReadRecords: () => this.openProfileDetail(ProfileRoute.READ_RECORDS),
          onRemoveFromShelf: () => this.removeLocalBookFromShelf(this.selectedBook),
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
            book: this.selectedBook,
            chapterTitle: this.selectedChapter,
            replaceRules: this.replaceRules,
            content: this.readerContent,
            fontSize: this.readerFontSize,
            imageStyle: this.selectedBook.imageStyle ?? 'DEFAULT',
            paperColor: this.getPaperColor(),
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
            clickImageBehavior: this.readerClickImageBehavior,
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
            onBack: () => this.route = this.readerReturnRoute,
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
            onMoreActionsChange: (actions: ReaderMoreActionConfig[]) => this.setReaderMoreActions(actions),
            onOpenHighlightRules: () => this.openProfileDetail(ProfileRoute.HIGHLIGHT_TAG_RULES),
            onUnavailableAction: (message: string) => this.showUnavailableAction(message),
            onProgressChange: this.createReaderProgressCallback(),
            onAddBookmark: (position: number, pageText: string) => this.requestAddReaderBookmark(position, pageText),
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
              useTitleReplacement: this.readerTocUseReplace,
              showWordCount: this.readerTocShowWordCount,
              onBack: () => this.route = this.catalogReturnRoute,
              onOpenBookmark: (bookmarkId: string) => this.openReaderBookmark(bookmarkId),
              onEditBookmark: (bookmarkId: string) => this.editReaderBookmark(bookmarkId),
              onTitleReplacementChange: (enabled: boolean) => this.setReaderTocUseReplace(enabled),
              onShowWordCountChange: (enabled: boolean) => this.setReaderTocShowWordCount(enabled),
              onUnavailableAction: (message: string) => this.showUnavailableAction(message),
              onSelectChapter: (chapterIndex: number) => {
              const chapterTitle = this.selectedBook.chapterTitles?.[chapterIndex];
              if (chapterTitle !== undefined) {
                this.selectChapter(chapterTitle, chapterIndex);
              }
            }
            })
          }
          if (this.bookmarkEditor !== undefined) {
            ReaderBookmarkEditor({
              bookmark: this.bookmarkEditor,
              isNew: this.bookmarkEditorIsNew,
              onSave: (note: string) => this.saveReaderBookmarkNote(note),
              onDelete: () => this.deleteReaderBookmark(),
              onClose: () => this.bookmarkEditor = undefined
            })
          }
          if (this.route === AppRoute.READER_SETTINGS) {
            ReaderSettingsPage({
              fontSize: this.readerFontSize,
              paperIndex: this.paperIndex,
              shareLayout: this.shareReaderStyleLayout,
              readerNightMode: this.readerNightMode,
              showBottomActionText: this.showReaderBottomActionText,
              bottomIconStyle: this.readerBottomIconStyle,
              bottomItemsPerRow: this.readerBottomItemsPerRow,
              bottomRowCount: this.readerBottomRowCount,
              bottomActions: this.readerBottomActions,
              topActions: this.readerTopActions,
              progressBehavior: this.readerProgressBehavior,
              clickImageBehavior: this.readerClickImageBehavior,
              onClickImageBehaviorChange: (value: string) => this.setReaderClickImageBehavior(value),
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
              onUnavailableAction: (message: string) => this.showUnavailableAction(message),
              showQuickActions: this.showReaderQuickActions,
              asSheet: true,
              openBottomActionConfigOnAppear: this.readerSettingsOpenBottomActionConfig,
              onBack: () => {
                this.readerSettingsOpenBottomActionConfig = false;
                this.route = this.settingsReturnRoute;
              },
              onFontSizeChange: (fontSize: number) => this.setReaderFontSize(fontSize),
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
            onOpenEditor: () => this.profileSubpage = ProfileRoute.REPLACE_RULE_EDIT,
            rules: this.replaceRules,
            groups: this.replaceRuleGroups(),
            onToggleRule: (id: number, enabled: boolean) => this.setReplaceRuleEnabled(id, enabled),
            onRemoveRule: (id: number) => this.removeReplaceRule(id),
            onUnavailableAction: (message: string) => this.showUnavailableAction(message)
          })
        } else if (this.profileSubpage === ProfileRoute.REPLACE_RULE_EDIT) {
          ReplaceRuleEditPage({
            onBack: () => this.profileSubpage = ProfileRoute.REPLACE_RULES,
            onSaveRule: (rule: ReplaceRule) => this.saveReplaceRule(rule),
            groups: this.replaceRuleGroups(),
            onUnavailableAction: (message: string) => this.showUnavailableAction(message)
          })
        } else if (this.profileSubpage === ProfileRoute.TXT_TOC_RULES) {
          TxtTocRulesPage({ onBack: () => this.route = this.profileDetailReturnRoute, onUnavailableAction: (message: string) => this.showUnavailableAction(message) })
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
          AllBookmarksPage({ books: this.getBookmarkBookSummaries(), entries: this.getBookmarkEntrySummaries(), onBack: () => this.route = this.profileDetailReturnRoute, onUnavailableAction: (message: string) => this.showUnavailableAction(message), onOpenBookmark: (bookmarkId: string) => this.openReaderBookmark(bookmarkId) })
        } else if (this.profileSubpage === ProfileRoute.READ_RECORDS) {
          ReadRecordsPage({ records: this.readTimeRecords, onBack: () => this.route = this.profileDetailReturnRoute, onUnavailableAction: (message: string) => this.showUnavailableAction(message) })
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
          AppReadSettingsPage({
            onBack: () => this.profileSubpage = this.profileSettingsReturn,
            onUnavailableAction: (message: string) => this.showUnavailableAction(message)
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
            paperIndex: this.paperIndex,
            shareLayout: this.shareReaderStyleLayout,
            readerNightMode: this.readerNightMode,
            showBottomActionText: this.showReaderBottomActionText,
            progressBehavior: this.readerProgressBehavior,
            infoSettings: this.readerInfoSettings,
            onInfoSettingsChange: (settings: ReaderInfoSettings) => this.setReaderInfoSettings(settings),
            pageAnimationIndex: this.readerPageAnimation,
            animationSpeedIndex: this.readerAnimationSpeed,
            onProgressBehaviorChange: (value: string) => this.setReaderProgressBehavior(value),
            onPageAnimationChange: (animation: number) => this.setReaderPageAnimation(animation),
            onAnimationSpeedChange: (speed: number) => this.setReaderAnimationSpeed(speed),
            onBottomActionTextChange: (enabled: boolean) => this.setReaderBottomActionText(enabled),
            onShareLayoutChange: (enabled: boolean) => this.setReaderShareLayout(enabled),
            onToggleNightMode: () => this.toggleReaderNightMode(),
            onUnavailableAction: (message: string) => this.showUnavailableAction(message),
            showQuickActions: this.showReaderQuickActions,
            asSheet: false,
            onBack: () => this.route = this.profileDetailReturnRoute,
            onFontSizeChange: (fontSize: number) => this.setReaderFontSize(fontSize),
            onPaperChange: (paperIndex: number) => this.setReaderPaperIndex(paperIndex),
            onQuickActionsChange: (enabled: boolean) => this.setReaderQuickActions(enabled)
          })
        }
        } else {
        ReaderSettingsPage({
          fontSize: this.readerFontSize,
          paperIndex: this.paperIndex,
          shareLayout: this.shareReaderStyleLayout,
          readerNightMode: this.readerNightMode,
          showBottomActionText: this.showReaderBottomActionText,
          progressBehavior: this.readerProgressBehavior,
          clickImageBehavior: this.readerClickImageBehavior,
          onClickImageBehaviorChange: (value: string) => this.setReaderClickImageBehavior(value),
          infoSettings: this.readerInfoSettings,
          onInfoSettingsChange: (settings: ReaderInfoSettings) => this.setReaderInfoSettings(settings),
          onProgressBehaviorChange: (value: string) => this.setReaderProgressBehavior(value),
          onBottomActionTextChange: (enabled: boolean) => this.setReaderBottomActionText(enabled),
          onShareLayoutChange: (enabled: boolean) => this.setReaderShareLayout(enabled),
          onToggleNightMode: () => this.toggleReaderNightMode(),
          onUnavailableAction: (message: string) => this.showUnavailableAction(message),
          showQuickActions: this.showReaderQuickActions,
          asSheet: false,
          onBack: () => this.route = this.settingsReturnRoute,
          onFontSizeChange: (fontSize: number) => this.setReaderFontSize(fontSize),
          onPaperChange: (paperIndex: number) => this.setReaderPaperIndex(paperIndex),
          onQuickActionsChange: (enabled: boolean) => this.setReaderQuickActions(enabled)
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














