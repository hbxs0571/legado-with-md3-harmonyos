export type BookMediaType = 'text' | 'audio' | 'image';

/** 本地书籍的正文形态。与上游 BookExtensions.kt:74-89 的五个谓词一一对应。 */
export type LocalBookFormat = 'txt' | 'epub' | 'pdf' | 'mobi' | 'umd';

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
  format?: LocalBookFormat;
  chapterCount?: string;
  /** 与 Android Book.imageStyle 同值：DEFAULT / FULL / TEXT / SINGLE。 */
  imageStyle?: string;
  /** 与 Android Book.config.pageAnim 同值：0..5，-1 = 默认（跟随全局）。缺省 = 跟随全局。 */
  pageAnim?: number;
  /** 与 Android Book.config.readSimulating 同值。缺省 false。 */
  readSimulating?: boolean;
  /** 与 Android Book.config.startDate 同值，ISO 日期串 yyyy-MM-dd。 */
  startDate?: string;
  /** 与 Android Book.config.startChapter 同值。 */
  startChapter?: number;
  /** 与 Android Book.config.dailyChapters 同值，上游默认 3。 */
  dailyChapters?: number;
  /** 与 Android Book.config.reSegment 对应，按书启用正文重分段。 */
  reSegment?: boolean;
  /** 上游 Book.delTag 位掩码：hTag=2、rubyTag=4，按书启用 EPUB 正文净化开关。 */
  delTag?: number;
  /**
   * 与 Android Book.config.useReplaceRule 对应，按书覆盖正文净化开关。
   * 不在 readConfig 里存这个字段即为「跟随全局默认」（上游存 null 同理）。
   */
  useReplaceRule?: boolean;
  /** 本地 TXT 当前使用的字符集；为空时按文件 BOM/内容自动识别。 */
  charset?: string;
  description?: string;
  /** 用户为书目添加的备注。 */
  remark?: string;
  /** 用户自定义标签，沿用 Android 逗号分隔存储。 */
  customTag?: string;
  androidOriginalPath?: string;
  androidCharacterPosition?: number;
  /**
   * 导入时的源文件名（含扩展名）。上游本地书的 originName 就是它，详情页来源行直接显示；
   * 本地 originName 列被当作 androidOriginalPath 读，所以另存一份，避免动那条语义。
   */
  originFileName?: string;
  /**
   * 导入时源文件的字节大小。上游 upKind() 用 FileDoc.fromFile(bookUrl).size 取它，
   * 本地 bookUrl 指向转出的正文副本，取不到源大小，只能在导入时记下来。
   */
  sourceSize?: number;
  /** 导入时选中的 TXT 章节正则；留空表示沿用旧版默认识别。 */
  tocRule?: string;
  /** 最近一次更新目录的时间戳，对应上游 Book.latestChapterTime。 */
  latestChapterTime?: number;
  /** 最新章节标题，对应上游 Book.latestChapterTitle。 */
  latestChapterTitle?: string;
  /** 刷新目录发现的新章数，对应上游 Book.lastCheckCount。 */
  lastCheckCount?: number;
  /**
   * 单本私密标记，对应上游 Book.isPrivate（books 表 isPrivate 列，:294）。
   * 分组级私密标记在 BookGroup 上，两者取并集判定，见 PrivateAccessRepository.isPrivateBook。
   */
  isPrivate?: boolean;
  /** 全书字数（格式化字符串），对应上游 Book.wordCount。 */
  wordCount?: string;
  /** 最后阅读这本书的时间戳，对应上游 Book.durChapterTime。 */
  durChapterTime?: number;
  /** 手动排序序号，对应上游 Book.order；按「手动排序」时使用。 */
  order?: number;
  /** 单独为这本书关闭阅读记录，对应上游 Book.disableReadRecord。 */
  disableReadRecord?: boolean;
  /**
   * 是否本地书。上游 Book 没有这个数据字段，它是 BookExtensions.isLocal 计算属性
   * （origin == 'loc_book' 或 type & 256）。本仓保留该字段仓储层按 origin 回填，
   * 语义与上游计算属性一致：本地书 true、在线书 false。
   */
  isLocal: boolean;
  /** 书源 URL。本地书固定 'loc_book'，在线书为书源 bookSourceUrl（对齐上游 Book.origin）。 */
  origin?: string;
  /** 书源名称（对齐上游 Book.originName）。 */
  originName?: string;
  /** 在线书的目录 URL（对齐上游 Book.tocUrl）。本地书该列存章节正则，见 tocRule。 */
  tocUrl?: string;
  /** 分类（对齐上游 Book.kind，与 books 表 kind 列同列）。 */
  kind?: string;
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
  /** 本章对应的资源路径（相对解压根），纯目录项为空串；写入 chapters.resourceUrl。 */
  resourceUrl?: string;
  /** 本章正文在资源里的起始片段 id（url 的 # 之后部分）；undefined 表示从文件头开始。 */
  startFragmentId?: string;
  /** 本章正文的结束片段 id，由下一章的 startFragmentId 反向写入。 */
  endFragmentId?: string;
  /** 下一章的 url（上游 putVariable("nextUrl", …)）；最后一章为 undefined。 */
  nextUrl?: string;
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
  /** 书籍信息编辑独立成页，从详情页顶栏的编辑按钮进入。 */
  BOOK_INFO_EDIT = 'bookInfoEdit',
  READ_ALOUD_SETTINGS = 'readAloudSettings',
  SEARCH = 'search',
  /** 本地书多选后的导入确认页（批 10 的 :555）。 */
  LOCAL_BOOK_IMPORT = 'localBookImport',
  PROFILE_SUBPAGE = 'profileSubpage'
}

export enum ProfileRoute {
  BOOK_SOURCE_MANAGE = 'bookSourceManage',
  REPLACE_RULES = 'replaceRules',
  REPLACE_RULE_EDIT = 'replaceRuleEdit',
  DICTIONARY_RULE_EDIT = 'dictionaryRuleEdit',
  TXT_TOC_RULES = 'txtTocRules',
  /** 目录规则预览页：挑一条规则看它能切出多少章，选中后直接应用到当前书。 */
  TXT_TOC_RULE_PREVIEW = 'txtTocRulePreview',
  DICTIONARY_RULES = 'dictionaryRules',
  HIGHLIGHT_TAG_RULE_EDIT = 'highlightTagRuleEdit',
  HIGHLIGHT_TAG_RULES = 'highlightTagRules',
  AI_CHAT = 'aiChat',
  APP_SETTINGS = 'appSettings',
  APP_THEME_SETTINGS = 'appThemeSettings',
  APP_CUSTOM_THEME = 'appCustomTheme',
  APP_THEME_MANAGE = 'appThemeManage',
  APP_OTHER_SETTINGS = 'appOtherSettings',
  APP_READ_SETTINGS = 'appReadSettings',
  APP_ALOUD_SETTINGS = 'appAloudSettings',
  /** 批8：朗读引擎与音色页（HTTP TTS 源与音色目录管理）。 */
  ALOUD_ENGINE = 'aloudEngine',
  APP_COVER_SETTINGS = 'appCoverSettings',
  APP_DOWNLOAD_CACHE_SETTINGS = 'appDownloadCacheSettings',
  APP_BACKUP_SETTINGS = 'appBackupSettings',
  APP_AI_SETTINGS = 'appAiSettings',
  APP_TRANSLATION_SETTINGS = 'appTranslationSettings',
  APP_PRIVACY_SETTINGS = 'appPrivacySettings',
  APP_LAB_SETTINGS = 'appLabSettings',
  ALL_BOOKMARKS = 'allBookmarks',
  READ_RECORDS = 'readRecords',
  /** 阅读记录总览页：跨书统计、排行、热力图、读书日历。 */
  READ_RECORD_OVERVIEW = 'readRecordOverview',
  CACHE_MANAGEMENT = 'cacheManagement',
  BOOKSHELF_MANAGE = 'bookshelfManage',
  FILE_MANAGER = 'fileManager',
  PRIVACY_NOTICE = 'privacyNotice',
  OPEN_SOURCE_LICENSE = 'openSourceLicense',
  ABOUT = 'about'
}
