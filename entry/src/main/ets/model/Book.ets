export type BookMediaType = 'text' | 'audio' | 'image';

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
  /** 用户自定义封面的应用内副本路径。 */
  customCoverUri?: string;
  /** 对齐 Android 的文本、音频、图片书籍类型。 */
  bookType?: BookMediaType;
  /** 对齐 Android 固定书籍类型设置。 */
  fixedType?: boolean;
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
  /** 用户为书目添加的备注。 */
  remark?: string;
  /** 用户自定义标签，沿用 Android 逗号分隔存储。 */
  customTag?: string;
  bodyMissing?: boolean;
  androidOriginalPath?: string;
  androidCharacterPosition?: number;
  /** 0 按百分比恢复，1 为旧版 HOS 渲染坐标，2 为 Android 正文章内字符坐标。 */
  readerPositionVersion?: number;
  /**
   * 这本书识别目录时采用的正则，对应上游 Book.tocUrl。
   * 导入或刷新时确定一次并固定下来，之后启用/停用规则不会改动已有书籍的目录；
   * 为空表示该书没有匹配到规则，按字数分章。
   */
  tocRule?: string;
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
