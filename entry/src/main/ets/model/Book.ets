export type BookMediaType = 'text' | 'audio' | 'image';

/**
 * 书籍。字段与上游 Book 实体对齐，章节已拆到 chapters 表，
 * 因此这里不再有 chapterTitles / chapterOffsets / chapterVolumes 三个数组。
 */
export interface Book {
  /** 由 bookUrl（本地书就是文件路径）派生：取文件名去掉扩展名。 */
  id: string;
  title: string;
  author: string;
  category: string;
  /** 旧版单分组名称，用于兼容 v1-v12 书架记录。 */
  groupName?: string;
  /** Android Book.group 的位掩码值对应的分组名称集合。 */
  groupNames?: string[];
  chapterIndex?: number;
  chapterProgress?: number;
  lastChapter: string;
  /**
   * 全书阅读进度，百分比范围 0–100。
   * 派生值，不落库：由 BookRepository.readProgress 按章序与章内进度算出。
   */
  progress: number;
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
  androidOriginalPath?: string;
  androidCharacterPosition?: number;
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

/**
 * 章节。对应上游 BookChapter 实体与 chapters 表，
 * 章节不再是 Book 的字段，读取时按 bookUrl 从表里查。
 */
export interface BookChapter {
  /** 章节唯一标识，由 originName + index + title 的 MD5 前 16 位合成。 */
  url: string;
  title: string;
  /** 是否为分卷标题；分卷行本身也是目录里的一行。 */
  isVolume: boolean;
  /** 卷层级：卷标题为 0，卷内章节为 1。 */
  tocLevel: number;
  bookUrl: string;
  index: number;
  /** 章节在整本书原始文件里的起始字节偏移；无目录时为 undefined。 */
  start?: number;
  /** 章节结束字节偏移（开区间）。 */
  end?: number;
  /** 格式化后的字数，如「1.2万字」「850字」。 */
  wordCount?: string;
}

/**
 * 封面底色。上游 BookCoverModel 从内置封面图里按书名挑一张，
 * 本地没有内置图，改为按书名哈希固定映射到一组底色，保证同一本书每次颜色一致。
 */
export function bookCoverColor(book: Book): string {
  const palette: string[] = [
    '#39424B', '#4A3B52', '#2F4A46', '#4B3B2F', '#3A3F5C',
    '#523B3B', '#37474F', '#4C4A33', '#3D4B3A', '#4A3A4E'
  ];
  const seed = book.title.length > 0 ? book.title : (book.author.length > 0 ? book.author : '书');
  let hash = 0;
  for (let index = 0; index < seed.length; index++) {
    hash = (hash * 31 + seed.charCodeAt(index)) % 100000007;
  }
  return palette[hash % palette.length];
}

/** 封面上的占位文字，取书名首字；上游 BookCoverModel 同样以书名首字作兜底。 */
export function bookCoverMark(book: Book): string {
  return book.title.length > 0 ? book.title.substring(0, 1) : '书';
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
