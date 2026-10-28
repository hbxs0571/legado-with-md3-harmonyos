export type BookMediaType = 'text' | 'audio' | 'image';

export interface Book {
  id: string;
  title: string;
  author: string;
  category: string;
  /** 旧版单分组名称，用于兼容 v1-v12 书架记录。 */
  groupName?: string;
  /** Android Book.group 的位掩码值对应的分组名称集合。 */
  groupNames?: string[];
  chapterTitles?: string[];
  chapterOffsets?: number[];
  /** 每一章是否为分卷标题，与 chapterTitles 一一对应。 */
  chapterVolumes?: boolean[];
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
  /** 导入时选中的 TXT 章节正则；留空表示沿用旧版默认识别。 */
  tocRule?: string;
  /** 最近一次更新目录的时间戳，对应上游 Book.latestChapterTime。 */
  latestChapterTime?: number;
  /** 最后阅读这本书的时间戳，对应上游 Book.durChapterTime。 */
  durChapterTime?: number;
  /** 手动排序序号，对应上游 Book.order；按「手动排序」时使用。 */
  order?: number;
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
