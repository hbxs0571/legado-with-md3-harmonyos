export interface Book {
  id: string;
  title: string;
  author: string;
  category: string;
  groupName?: string;
  chapterTitles?: string[];
  chapterOffsets?: number[];
  chapterIndex?: number;
  chapterProgress?: number;
  lastChapter: string;
  /** 全书阅读进度，百分比范围 0–100。 */
  progress: number;
  coverColor: string;
  coverMark: string;
  coverUri?: string;
  contentPath?: string;
  format?: 'txt' | 'epub';
  chapterCount?: string;
  fileSizeBytes?: number;
  /** 与 Android Book.imageStyle 同值：DEFAULT / FULL / TEXT / SINGLE。 */
  imageStyle?: string;
  /** 与 Android Book.config.reSegment 对应，按书启用正文重分段。 */
  reSegment?: boolean;
  /** 本地 TXT 当前使用的字符集；为空时按文件 BOM/内容自动识别。 */
  charset?: string;
  description?: string;
  bodyMissing?: boolean;
  androidOriginalPath?: string;
  androidCharacterPosition?: number;
  isLocal: boolean;
}

export enum AppRoute {
  HOME = 'home',
  BOOKSHELF = 'bookshelf',
  DISCOVER = 'discover',
  SUBSCRIPTIONS = 'subscriptions',
  SUBSCRIPTION_RULES = 'subscriptionRules',
  SUBSCRIPTION_FAVORITES = 'subscriptionFavorites',
  SUBSCRIPTION_SOURCE_MANAGE = 'subscriptionSourceManage',
  PROFILE = 'profile',
  READER = 'reader',
  CATALOG = 'catalog',
  READER_SETTINGS = 'readerSettings',
  READER_SEARCH = 'readerSearch',
  BOOK_INFO = 'bookInfo',
  READ_ALOUD_SETTINGS = 'readAloudSettings',
  SEARCH = 'search',
  PROFILE_SUBPAGE = 'profileSubpage'
}

export enum ProfileRoute {
  BOOK_SOURCE_MANAGE = 'bookSourceManage',
  REPLACE_RULES = 'replaceRules',
  REPLACE_RULE_EDIT = 'replaceRuleEdit',
  DICTIONARY_RULE_EDIT = 'dictionaryRuleEdit',
  TXT_TOC_RULES = 'txtTocRules',
  DICTIONARY_RULES = 'dictionaryRules',
  HIGHLIGHT_TAG_RULE_EDIT = 'highlightTagRuleEdit',
  HIGHLIGHT_TAG_RULES = 'highlightTagRules',
  AI_CHAT = 'aiChat',
  APP_SETTINGS = 'appSettings',
  APP_THEME_SETTINGS = 'appThemeSettings',
  APP_OTHER_SETTINGS = 'appOtherSettings',
  APP_READ_SETTINGS = 'appReadSettings',
  APP_ALOUD_SETTINGS = 'appAloudSettings',
  APP_COVER_SETTINGS = 'appCoverSettings',
  APP_DOWNLOAD_CACHE_SETTINGS = 'appDownloadCacheSettings',
  APP_BACKUP_SETTINGS = 'appBackupSettings',
  APP_AI_SETTINGS = 'appAiSettings',
  APP_TRANSLATION_SETTINGS = 'appTranslationSettings',
  APP_PRIVACY_SETTINGS = 'appPrivacySettings',
  APP_LAB_SETTINGS = 'appLabSettings',
  ALL_BOOKMARKS = 'allBookmarks',
  READ_RECORDS = 'readRecords',
  CACHE_MANAGEMENT = 'cacheManagement',
  FILE_MANAGER = 'fileManager',
  PRIVACY_NOTICE = 'privacyNotice',
  OPEN_SOURCE_LICENSE = 'openSourceLicense',
  ABOUT = 'about'
}
