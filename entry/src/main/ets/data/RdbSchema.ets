import { relationalStore } from '@kit.ArkData';

/**
 * 建表 SQL 与版本管理。
 *
 * 表结构逐列对齐上游 Room 实体（Bookmark.kt / BookMarking.kt / SearchContentHistory.kt），
 * 不添加本地扩展列。上游用 KSP 注解生成建表语句，这里只能手写，
 * 所以列名、类型、默认值都必须照着实体一个字一个字核对。
 *
 * 排序规则：列定义带 COLLATE LOCALES。
 * relationalStore 里注册的规则名是 LOCALES（实测 PRAGMA collation_list = LOCALES/RTRIM/NOCASE/BINARY），
 * 不是 SQLite 文档与上游 Room 写的 LOCALIZED —— 写 LOCALIZED 会报 errno 25。
 * 列定义带上之后，查询里即使漏写 COLLATE 也会按拼音序。
 */
export class RdbSchema {
  /** 当前 schema 版本，与 RdbStore.version 比对决定是否建表。ZIP 兼容总账批 3 追加五张 G2 表（dictRules / homepage_modules / homepage_custom_sets / highlight_tag_rules / tag_group_rules）后升到 4；httpTTS 数据层追加 `httpTTS` 与 `read_aloud_voices` 两张表及一个唯一索引后升到 5；老库靠 ensure() 里的 IF NOT EXISTS 补齐；books 表补 format 列后升到 6；第七批（server 类）追加 `servers` 表与排序索引后升到 7；第八批（高亮规则边框）给 highlightRules 补 borderColor / borderWidth / borderRadius 三列后升到 8；朗读批 8 给 httpTTS 补 textParam / speedParam / toneParam 三个本地扩展列后升到 9。v10：知识库批追加 `book_character_profiles` / `book_character_relations` / `book_character_events` / `book_knowledge_entries` / `book_outline_nodes` 五张表与其索引（同批 `keyboardAssists` 表也在这次升级里）。v11：备份功能盘查批追加 `search_keywords` 表与其唯一索引（上游 SearchKeyword.kt 的实体表）。 */
  static readonly version: number = 11;

  /** bookmarks：上游 Bookmark.kt，主键 time，索引 (bookName, bookAuthor)。 */
  static readonly createBookmarks: string =
    'CREATE TABLE IF NOT EXISTS bookmarks (' +
    'time INTEGER PRIMARY KEY, ' +
    "bookName TEXT NOT NULL DEFAULT '' COLLATE LOCALES, " +
    "bookAuthor TEXT NOT NULL DEFAULT '' COLLATE LOCALES, " +
    "bookUrl TEXT NOT NULL DEFAULT '', " +
    'chapterIndex INTEGER NOT NULL DEFAULT 0, ' +
    'chapterPos INTEGER NOT NULL DEFAULT 0, ' +
    "chapterName TEXT NOT NULL DEFAULT '', " +
    "bookText TEXT NOT NULL DEFAULT '', " +
    "content TEXT NOT NULL DEFAULT ''" +
    ')';

  static readonly createBookmarksIndex: string =
    'CREATE INDEX IF NOT EXISTS index_bookmarks_bookName_bookAuthor ' +
    'ON bookmarks (bookName, bookAuthor)';

  /**
   * book_marks：上游 BookMarking.kt，主键 id，索引 (bookUrl, chapterIndex)。
   * chapterIndex 可空（上游 Int? = null），anchorJson 必填，styleJson 可空。
   */
  static readonly createBookMarks: string =
    'CREATE TABLE IF NOT EXISTS book_marks (' +
    'id TEXT PRIMARY KEY, ' +
    'bookUrl TEXT NOT NULL, ' +
    "bookName TEXT NOT NULL DEFAULT '' COLLATE LOCALES, " +
    "bookAuthor TEXT NOT NULL DEFAULT '' COLLATE LOCALES, " +
    'chapterIndex INTEGER, ' +
    'anchorJson TEXT NOT NULL, ' +
    'styleJson TEXT, ' +
    "note TEXT NOT NULL DEFAULT '', " +
    "chapterName TEXT NOT NULL DEFAULT '', " +
    'enabled INTEGER NOT NULL DEFAULT 1, ' +
    'createdAt INTEGER NOT NULL, ' +
    'updatedAt INTEGER NOT NULL' +
    ')';

  static readonly createBookMarksIndex: string =
    'CREATE INDEX IF NOT EXISTS index_book_marks_bookUrl_chapterIndex ' +
    'ON book_marks (bookUrl, chapterIndex)';

  /**
   * search_content_history：上游 SearchContentHistory.kt，
   * 主键 id AUTOINCREMENT，索引 (bookName, bookAuthor, query) UNIQUE。
   */
  static readonly createSearchContentHistory: string =
    'CREATE TABLE IF NOT EXISTS search_content_history (' +
    'id INTEGER PRIMARY KEY AUTOINCREMENT, ' +
    'bookName TEXT COLLATE LOCALES, ' +
    'bookAuthor TEXT COLLATE LOCALES, ' +
    "query TEXT NOT NULL DEFAULT '', " +
    'time INTEGER NOT NULL' +
    ')';

  static readonly createSearchContentHistoryIndex: string =
    'CREATE UNIQUE INDEX IF NOT EXISTS index_search_content_history_bookName_bookAuthor_query ' +
    'ON search_content_history (bookName, bookAuthor, query)';

  /**
   * search_keywords：上游 SearchKeyword.kt（`@Entity(tableName = "search_keywords")`），
   * 主键是关键词本身，另建 word 唯一索引（上游 `indices = [(Index(value = ["word"], unique = true))]`）。
   * 与 search_content_history 不是一回事：后者是阅读页内「本书内搜索」的记录，
   * 这张表是书源搜索框的全局关键词，备份的 searchHistory.json 收的是这张表。
   */
  static readonly createSearchKeywords: string =
    'CREATE TABLE IF NOT EXISTS search_keywords (' +
    "`word` TEXT NOT NULL DEFAULT '', " +
    '`usage` INTEGER NOT NULL DEFAULT 1, ' +
    '`lastUseTime` INTEGER NOT NULL DEFAULT 0, ' +
    'PRIMARY KEY(`word`))';

  static readonly createSearchKeywordsIndex: string =
    'CREATE UNIQUE INDEX IF NOT EXISTS index_search_keywords_word ON search_keywords (`word`)';

  /**
   * book_groups：上游 BookGroup.kt，主键 groupId，无索引。
   * order 是 SQL 关键字，必须带反引号（上游 Room 生成的语句也带）。
   */
  static readonly createBookGroups: string =
    'CREATE TABLE IF NOT EXISTS `book_groups` (' +
    '`groupId` INTEGER NOT NULL, ' +
    '`groupName` TEXT NOT NULL, ' +
    '`cover` TEXT, ' +
    '`order` INTEGER NOT NULL, ' +
    '`enableRefresh` INTEGER NOT NULL DEFAULT 1, ' +
    '`show` INTEGER NOT NULL DEFAULT 1, ' +
    '`bookSort` INTEGER NOT NULL DEFAULT -1, ' +
    '`isPrivate` INTEGER NOT NULL DEFAULT 0, ' +
    'PRIMARY KEY(`groupId`)' +
    ')';

  /**
   * replace_rules：上游 ReplaceRule.kt，主键 id AUTOINCREMENT，索引 (id)。
   * group 是 SQL 关键字，必须带反引号。
   * 上游实体字段名是 order，列名是 sortOrder（@ColumnInfo 改名）。
   */
  static readonly createReplaceRules: string =
    'CREATE TABLE IF NOT EXISTS `replace_rules` (' +
    '`id` INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL, ' +
    "`name` TEXT NOT NULL DEFAULT '', " +
    '`group` TEXT, ' +
    "`pattern` TEXT NOT NULL DEFAULT '', " +
    "`replacement` TEXT NOT NULL DEFAULT '', " +
    '`scope` TEXT, ' +
    '`scopeTitle` INTEGER NOT NULL DEFAULT 0, ' +
    '`scopeContent` INTEGER NOT NULL DEFAULT 1, ' +
    '`excludeScope` TEXT, ' +
    '`isEnabled` INTEGER NOT NULL DEFAULT 1, ' +
    '`isRegex` INTEGER NOT NULL DEFAULT 1, ' +
    '`timeoutMillisecond` INTEGER NOT NULL DEFAULT 3000, ' +
    '`sortOrder` INTEGER NOT NULL DEFAULT 0' +
    ')';

  static readonly createReplaceRulesIndex: string =
    'CREATE INDEX IF NOT EXISTS `index_replace_rules_id` ON `replace_rules` (`id`)';

  /**
   * txtTocRules：上游 TxtTocRule.kt，主键 id，无索引。
   * id 不是自增（内置规则的 id 为负数，见上游 deleteDefault 的 `where id < 0`）。
   */
  static readonly createTxtTocRules: string =
    'CREATE TABLE IF NOT EXISTS `txtTocRules` (' +
    '`id` INTEGER NOT NULL, ' +
    '`name` TEXT NOT NULL, ' +
    '`chapterRule` TEXT NOT NULL, ' +
    '`volumeRule` TEXT NOT NULL, ' +
    '`example` TEXT, ' +
    '`serialNumber` INTEGER NOT NULL, ' +
    '`enable` INTEGER NOT NULL, ' +
    'PRIMARY KEY(`id`)' +
    ')';

  /**
   * highlightRules：上游 HighlightRule.kt，主键 id，无索引。
   * 注意 15 个 REAL 列（含新增的 borderWidth / borderRadius）：读的时候必须用 RdbCodec.real()（内部 getDouble），
   * 用 getLong 会静默截断（实测 0.1 变 0），九宫格边距与字距会全变 0。
   */
  static readonly createHighlightRules: string =
    'CREATE TABLE IF NOT EXISTS `highlightRules` (' +
    '`id` TEXT NOT NULL, ' +
    '`name` TEXT NOT NULL, ' +
    '`pattern` TEXT NOT NULL, ' +
    '`sampleText` TEXT NOT NULL, ' +
    '`targetScope` INTEGER NOT NULL, ' +
    '`enabled` INTEGER NOT NULL, ' +
    '`position` INTEGER NOT NULL, ' +
    '`textColor` INTEGER, ' +
    '`bgColor` INTEGER, ' +
    '`underlineMode` INTEGER NOT NULL, ' +
    '`underlineColor` INTEGER, ' +
    '`underlineWidth` REAL NOT NULL, ' +
    '`underlineOffset` REAL NOT NULL, ' +
    '`underlineSvgPath` TEXT, ' +
    '`bgImage` TEXT, ' +
    '`bgImageFit` INTEGER NOT NULL, ' +
    '`bgImageScale` REAL NOT NULL, ' +
    '`configName` TEXT, ' +
    '`fontPath` TEXT, ' +
    '`fontWeight` INTEGER NOT NULL, ' +
    '`isItalic` INTEGER NOT NULL, ' +
    '`fontSizeOffset` INTEGER NOT NULL, ' +
    '`npLeft` REAL NOT NULL, ' +
    '`npRight` REAL NOT NULL, ' +
    '`npTop` REAL NOT NULL, ' +
    '`npBottom` REAL NOT NULL, ' +
    '`manualNineSlice` INTEGER NOT NULL DEFAULT 1, ' +
    '`letterSpacingBefore` REAL NOT NULL DEFAULT 0, ' +
    '`letterSpacingAfter` REAL NOT NULL DEFAULT 0, ' +
    '`lineSpacingTop` REAL NOT NULL DEFAULT 0, ' +
    '`lineSpacingBottom` REAL NOT NULL DEFAULT 0, ' +
    '`bgLengthOffsetLeft` REAL NOT NULL DEFAULT 0, ' +
    '`bgLengthOffsetRight` REAL NOT NULL DEFAULT 0, ' +
    '`borderColor` INTEGER, ' +
    '`borderWidth` REAL NOT NULL DEFAULT 1, ' +
    '`borderRadius` REAL NOT NULL DEFAULT 4, ' +
    'PRIMARY KEY(`id`)' +
    ')';

  /**
   * book_content_processes：上游 BookContentProcess.kt，主键 id，3 条索引。
   * chapterIndex 可空（上游 Int? = null，null 表示整本生效）。
   */
  static readonly createBookContentProcesses: string =
    'CREATE TABLE IF NOT EXISTS `book_content_processes` (' +
    '`id` TEXT NOT NULL, ' +
    '`bookUrl` TEXT NOT NULL, ' +
    '`chapterIndex` INTEGER, ' +
    '`kind` TEXT NOT NULL, ' +
    '`stage` TEXT NOT NULL, ' +
    '`target` TEXT NOT NULL, ' +
    '`anchorJson` TEXT NOT NULL, ' +
    '`actionJson` TEXT NOT NULL, ' +
    '`styleJson` TEXT, ' +
    '`source` TEXT NOT NULL, ' +
    '`aiArtifactId` TEXT, ' +
    '`sourceContentHash` TEXT, ' +
    '`enabled` INTEGER NOT NULL, ' +
    '`sortOrder` INTEGER NOT NULL, ' +
    '`status` INTEGER NOT NULL, ' +
    '`schemaVersion` INTEGER NOT NULL, ' +
    '`createdAt` INTEGER NOT NULL, ' +
    '`updatedAt` INTEGER NOT NULL, ' +
    'PRIMARY KEY(`id`)' +
    ')';

  static readonly createBookContentProcessesIndex1: string =
    'CREATE INDEX IF NOT EXISTS `index_book_content_processes_bookUrl_chapterIndex_enabled_sortOrder` ' +
    'ON `book_content_processes` (`bookUrl`, `chapterIndex`, `enabled`, `sortOrder`)';

  static readonly createBookContentProcessesIndex2: string =
    'CREATE INDEX IF NOT EXISTS `index_book_content_processes_bookUrl_kind` ' +
    'ON `book_content_processes` (`bookUrl`, `kind`)';

  static readonly createBookContentProcessesIndex3: string =
    'CREATE INDEX IF NOT EXISTS `index_book_content_processes_aiArtifactId` ' +
    'ON `book_content_processes` (`aiArtifactId`)';

  /**
   * books：上游 Book.kt，35 列，主键 bookUrl。
   * 本地书 bookUrl 就是正文文件路径（上游 LocalBook.kt 同样如此）。
   * order 与 group 是 SQL 关键字，整表列名都带反引号（与上游 Room 生成的语句一致）。
   */
  static readonly createBooks: string =
    'CREATE TABLE IF NOT EXISTS `books` (' +
    "`bookUrl` TEXT NOT NULL DEFAULT '', " +
    "`tocUrl` TEXT NOT NULL DEFAULT '', " +
    "`origin` TEXT NOT NULL DEFAULT 'loc_book', " +
    "`originName` TEXT NOT NULL DEFAULT '', " +
    "`name` TEXT NOT NULL DEFAULT '', " +
    "`author` TEXT NOT NULL DEFAULT '', " +
    '`kind` TEXT, ' +
    '`customTag` TEXT, ' +
    '`coverUrl` TEXT, ' +
    '`customCoverUrl` TEXT, ' +
    '`intro` TEXT, ' +
    '`customIntro` TEXT, ' +
    '`remark` TEXT, ' +
    '`charset` TEXT, ' +
    '`type` INTEGER NOT NULL DEFAULT 0, ' +
    '`group` INTEGER NOT NULL DEFAULT 0, ' +
    '`isPrivate` INTEGER NOT NULL DEFAULT 0, ' +
    '`latestChapterTitle` TEXT, ' +
    '`latestChapterTime` INTEGER NOT NULL DEFAULT 0, ' +
    '`lastCheckTime` INTEGER NOT NULL DEFAULT 0, ' +
    '`lastCheckCount` INTEGER NOT NULL DEFAULT 0, ' +
    '`totalChapterNum` INTEGER NOT NULL DEFAULT 0, ' +
    '`durChapterTitle` TEXT, ' +
    '`durChapterIndex` INTEGER NOT NULL DEFAULT 0, ' +
    '`durChapterPos` INTEGER NOT NULL DEFAULT 0, ' +
    '`durChapterTime` INTEGER NOT NULL DEFAULT 0, ' +
    '`wordCount` TEXT, ' +
    '`canUpdate` INTEGER NOT NULL DEFAULT 1, ' +
    '`disableReadRecord` INTEGER NOT NULL DEFAULT 0, ' +
    '`order` INTEGER NOT NULL DEFAULT 0, ' +
    '`originOrder` INTEGER NOT NULL DEFAULT 0, ' +
    '`variable` TEXT, ' +
    '`readConfig` TEXT, ' +
    '`syncTime` INTEGER NOT NULL DEFAULT 0, ' +
    '`listIntro` TEXT, ' +
    "`format` TEXT NOT NULL DEFAULT '', " +
    'PRIMARY KEY(`bookUrl`)' +
    ')';

  static readonly createBooksIndexNameAuthor: string =
    'CREATE INDEX IF NOT EXISTS `index_books_name_author` ON `books` (`name`, `author`)';

  static readonly createBooksIndexDurChapterTime: string =
    'CREATE INDEX IF NOT EXISTS `index_books_durChapterTime` ON `books` (`durChapterTime`)';

  /**
   * chapters：上游 BookChapter.kt，18 列，主键 (url, bookUrl)。
   * index / start / end 都是 SQL 关键字，必须带反引号。
   * start / end 是正文里的**字节**偏移（上游 TextFile.kt 用 toByteArray().size 累加）。
   * 外键声明照抄上游，但实测 relationalStore 默认不开 PRAGMA foreign_keys，
   * CASCADE 不会真的执行 —— 删书必须手动删章节行，不能依赖这里。
   */
  static readonly createChapters: string =
    'CREATE TABLE IF NOT EXISTS `chapters` (' +
    '`url` TEXT NOT NULL, ' +
    '`title` TEXT NOT NULL, ' +
    '`isVolume` INTEGER NOT NULL, ' +
    '`tocLevel` INTEGER NOT NULL DEFAULT 0, ' +
    '`baseUrl` TEXT NOT NULL, ' +
    '`bookUrl` TEXT NOT NULL, ' +
    '`index` INTEGER NOT NULL, ' +
    '`isVip` INTEGER NOT NULL, ' +
    '`isPay` INTEGER NOT NULL, ' +
    '`resourceUrl` TEXT, ' +
    '`tag` TEXT, ' +
    '`wordCount` TEXT, ' +
    '`start` INTEGER, ' +
    '`end` INTEGER, ' +
    '`startFragmentId` TEXT, ' +
    '`endFragmentId` TEXT, ' +
    '`variable` TEXT, ' +
    '`reviewImg` TEXT, ' +
    'PRIMARY KEY(`url`, `bookUrl`), ' +
    'FOREIGN KEY(`bookUrl`) REFERENCES `books`(`bookUrl`) ON UPDATE NO ACTION ON DELETE CASCADE' +
    ')';

  static readonly createChaptersIndexBookUrl: string =
    'CREATE INDEX IF NOT EXISTS `index_chapters_bookUrl` ON `chapters` (`bookUrl`)';

  static readonly createChaptersIndexBookUrlIndex: string =
    'CREATE UNIQUE INDEX IF NOT EXISTS `index_chapters_bookUrl_index` ON `chapters` (`bookUrl`, `index`)';

  /**
   * readRecord：上游 ReadRecord.kt，主键 (deviceId, bookName, bookAuthor)。
   * deviceId 本地恒为空串（上游 Restore.kt 的 LOCAL_READ_RECORD_DEVICE_ID = ""）。
   */
  static readonly createReadRecord: string =
    'CREATE TABLE IF NOT EXISTS `readRecord` (' +
    '`deviceId` TEXT NOT NULL, ' +
    '`bookName` TEXT NOT NULL, ' +
    "`bookAuthor` TEXT NOT NULL DEFAULT '', " +
    '`readTime` INTEGER NOT NULL DEFAULT 0, ' +
    '`lastRead` INTEGER NOT NULL DEFAULT 0, ' +
    'PRIMARY KEY(`deviceId`, `bookName`, `bookAuthor`)' +
    ')';

  /** readRecordDetail：上游 ReadRecordDetail.kt，主键 (deviceId, bookName, bookAuthor, date)。 */
  static readonly createReadRecordDetail: string =
    'CREATE TABLE IF NOT EXISTS `readRecordDetail` (' +
    '`deviceId` TEXT NOT NULL, ' +
    '`bookName` TEXT NOT NULL, ' +
    "`bookAuthor` TEXT NOT NULL DEFAULT '', " +
    '`date` TEXT NOT NULL, ' +
    '`readTime` INTEGER NOT NULL DEFAULT 0, ' +
    '`readWords` INTEGER NOT NULL DEFAULT 0, ' +
    '`firstReadTime` INTEGER NOT NULL DEFAULT 0, ' +
    '`lastReadTime` INTEGER NOT NULL DEFAULT 0, ' +
    'PRIMARY KEY(`deviceId`, `bookName`, `bookAuthor`, `date`)' +
    ')';

  /**
   * readRecordSession：上游 ReadRecordSession.kt，主键 id 自增。
   * words 列名是上游原样：它存的是本次阅读所在的章节序号，不是字数。
   */
  static readonly createReadRecordSession: string =
    'CREATE TABLE IF NOT EXISTS `readRecordSession` (' +
    '`id` INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL, ' +
    '`deviceId` TEXT NOT NULL, ' +
    '`bookName` TEXT NOT NULL, ' +
    "`bookAuthor` TEXT NOT NULL DEFAULT '', " +
    "`bookUrl` TEXT NOT NULL DEFAULT '', " +
    '`startTime` INTEGER NOT NULL, ' +
    '`endTime` INTEGER NOT NULL, ' +
    '`words` INTEGER NOT NULL' +
    ')';

  // 第四批（ZIP 兼容总账批 3）：G2 五类新表。列名逐字对齐上游 Room 实体，
  // 让 Gson 写出的 JSON 能直接互认；不带 COLLATE LOCALES，因为这些表按整数
  // sortOrder/order 列排序、不需要中文拼音序，避开「未设 locale 时 ORDER BY
  // COLLATE LOCALES 静默返回空结果集」的坑。order 是 SQL 关键字，列名一律加反引号。
  static readonly createDictRules: string =
    'CREATE TABLE IF NOT EXISTS `dictRules` (' +
    '`name` TEXT NOT NULL, ' +
    '`urlRule` TEXT NOT NULL, ' +
    '`showRule` TEXT NOT NULL, ' +
    '`enabled` INTEGER NOT NULL DEFAULT 1, ' +
    '`sortNumber` INTEGER NOT NULL DEFAULT 0, ' +
    'PRIMARY KEY(`name`)' +
    ')';

  static readonly createHomepageModules: string =
    'CREATE TABLE IF NOT EXISTS `homepage_modules` (' +
    '`id` TEXT NOT NULL, ' +
    '`sourceUrl` TEXT NOT NULL, ' +
    '`moduleKey` TEXT NOT NULL, ' +
    '`type` TEXT NOT NULL, ' +
    '`title` TEXT NOT NULL, ' +
    '`args` TEXT, ' +
    '`layoutConfig` TEXT, ' +
    '`url` TEXT, ' +
    '`isEnabled` INTEGER NOT NULL DEFAULT 1, ' +
    '`sortOrder` INTEGER NOT NULL DEFAULT 0, ' +
    '`customSetId` TEXT, ' +
    '`isUserCreated` INTEGER NOT NULL DEFAULT 0, ' +
    '`customTitle` TEXT, ' +
    '`customSetTitle` TEXT, ' +
    '`sourceJsonHash` TEXT, ' +
    '`syncedAt` INTEGER NOT NULL DEFAULT 0, ' +
    'PRIMARY KEY(`id`)' +
    ')';

  static readonly createHomepageCustomSets: string =
    'CREATE TABLE IF NOT EXISTS `homepage_custom_sets` (' +
    '`id` TEXT NOT NULL, ' +
    '`name` TEXT NOT NULL, ' +
    '`sortOrder` INTEGER NOT NULL DEFAULT 0, ' +
    'PRIMARY KEY(`id`)' +
    ')';

  static readonly createHighlightTagRules: string =
    'CREATE TABLE IF NOT EXISTS `highlight_tag_rules` (' +
    '`id` INTEGER NOT NULL, ' +
    '`title` TEXT NOT NULL, ' +
    '`pattern` TEXT NOT NULL, ' +
    '`enabled` INTEGER NOT NULL DEFAULT 1, ' +
    '`order` INTEGER NOT NULL DEFAULT 0, ' +
    'PRIMARY KEY(`id`)' +
    ')';

  static readonly createTagGroupRules: string =
    'CREATE TABLE IF NOT EXISTS `tag_group_rules` (' +
    '`id` INTEGER NOT NULL, ' +
    '`pattern` TEXT NOT NULL, ' +
    '`groupName` TEXT NOT NULL, ' +
    '`order` INTEGER NOT NULL DEFAULT 0, ' +
    'PRIMARY KEY(`id`)' +
    ')';

  // 第五批（httpTTS 数据层）：两张表 + 一个唯一索引。列名逐字对齐上游 Room 实体，
  // 让 Gson 写出的 httpTTS.json / httpTtsVoices.json 能直接互认。httpTTS.id 上游
  // 是 Long，用 INTEGER；read_aloud_voices.id 上游是 String，用 TEXT——两处不同，
  // 别抄成一样。唯一索引对齐上游 Index(["engineType","engineId","speakerId"], unique = true)。
  static readonly createHttpTts: string =
    'CREATE TABLE IF NOT EXISTS `httpTTS` (' +
    '`id` INTEGER NOT NULL, ' +
    '`name` TEXT NOT NULL, ' +
    '`url` TEXT NOT NULL, ' +
    '`contentType` TEXT, ' +
    '`concurrentRate` TEXT, ' +
    '`loginUrl` TEXT, ' +
    '`loginUi` TEXT, ' +
    '`header` TEXT, ' +
    '`jsLib` TEXT, ' +
    '`enabledCookieJar` INTEGER NOT NULL DEFAULT 0, ' +
    '`loginCheckJs` TEXT, ' +
    '`speed` INTEGER, ' +
    '`synthesisThreadCount` INTEGER NOT NULL DEFAULT 1, ' +
    '`lastUpdateTime` INTEGER NOT NULL DEFAULT 0, ' +
    // 朗读批 8：三个本地扩展列（参数名映射），上游实体无此三列，不进 JSON 导出。
    '`textParam` TEXT NOT NULL DEFAULT \'text\', ' +
    '`speedParam` TEXT NOT NULL DEFAULT \'speed\', ' +
    '`toneParam` TEXT NOT NULL DEFAULT \'tone\', ' +
    'PRIMARY KEY(`id`)' +
    ')';

  static readonly createReadAloudVoices: string =
    'CREATE TABLE IF NOT EXISTS `read_aloud_voices` (' +
    '`id` TEXT NOT NULL, ' +
    '`engineType` TEXT NOT NULL, ' +
    '`engineId` TEXT NOT NULL DEFAULT \'\', ' +
    '`speakerId` TEXT NOT NULL DEFAULT \'\', ' +
    '`displayName` TEXT NOT NULL, ' +
    '`traitsJson` TEXT NOT NULL DEFAULT \'[]\', ' +
    '`emotionCatalogJson` TEXT NOT NULL DEFAULT \'[]\', ' +
    '`managedBy` TEXT NOT NULL DEFAULT \'user\', ' +
    '`enabled` INTEGER NOT NULL DEFAULT 1, ' +
    '`available` INTEGER NOT NULL DEFAULT 1, ' +
    '`excluded` INTEGER NOT NULL DEFAULT 0, ' +
    '`revision` INTEGER NOT NULL DEFAULT 0, ' +
    '`createdAt` INTEGER NOT NULL DEFAULT 0, ' +
    '`updatedAt` INTEGER NOT NULL DEFAULT 0, ' +
    'PRIMARY KEY(`id`)' +
    ')';

  static readonly createReadAloudVoicesUniqueIndex: string =
    'CREATE UNIQUE INDEX IF NOT EXISTS `index_read_aloud_voices_engine` ' +
    'ON `read_aloud_voices` (`engineType`, `engineId`, `speakerId`)';

  // 第六批（ZIP 总账 A 组四类）：无外键依赖，追加在末尾即可。
  // 四张表都存 sourceJson（整条条目的 JSON 文本）做往返真值，
  // 前面几列是它的派生列，只供 SQL 排序与筛选，不单独写。
  static readonly createBookSources: string =
    'CREATE TABLE IF NOT EXISTS `book_sources` (' +
    '`bookSourceUrl` TEXT NOT NULL, ' +
    '`bookSourceName` TEXT NOT NULL DEFAULT \'\', ' +
    '`bookSourceGroup` TEXT, ' +
    '`bookSourceType` INTEGER NOT NULL DEFAULT 0, ' +
    '`enabled` INTEGER NOT NULL DEFAULT 1, ' +
    '`customOrder` INTEGER NOT NULL DEFAULT 0, ' +
    '`sourceJson` TEXT NOT NULL DEFAULT \'\', ' +
    'PRIMARY KEY(`bookSourceUrl`)' +
    ')';

  static readonly createRssSources: string =
    'CREATE TABLE IF NOT EXISTS `rssSources` (' +
    '`sourceUrl` TEXT NOT NULL, ' +
    '`sourceName` TEXT NOT NULL DEFAULT \'\', ' +
    '`sourceGroup` TEXT, ' +
    '`enabled` INTEGER NOT NULL DEFAULT 1, ' +
    '`customOrder` INTEGER NOT NULL DEFAULT 0, ' +
    '`sourceJson` TEXT NOT NULL DEFAULT \'\', ' +
    'PRIMARY KEY(`sourceUrl`)' +
    ')';

  static readonly createRssStars: string =
    'CREATE TABLE IF NOT EXISTS `rssStars` (' +
    '`origin` TEXT NOT NULL, ' +
    '`link` TEXT NOT NULL, ' +
    '`title` TEXT NOT NULL DEFAULT \'\', ' +
    '`groupName` TEXT NOT NULL DEFAULT \'默认分组\', ' +
    '`sort` TEXT NOT NULL DEFAULT \'\', ' +
    '`starTime` INTEGER NOT NULL DEFAULT 0, ' +
    '`type` INTEGER NOT NULL DEFAULT 0, ' +
    '`durPos` INTEGER NOT NULL DEFAULT 0, ' +
    '`sourceJson` TEXT NOT NULL DEFAULT \'\', ' +
    'PRIMARY KEY(`origin`, `link`)' +
    ')';

  static readonly createRuleSubs: string =
    'CREATE TABLE IF NOT EXISTS `ruleSubs` (' +
    '`id` INTEGER NOT NULL, ' +
    '`name` TEXT NOT NULL DEFAULT \'\', ' +
    '`url` TEXT NOT NULL DEFAULT \'\', ' +
    '`type` INTEGER NOT NULL DEFAULT 0, ' +
    '`customOrder` INTEGER NOT NULL DEFAULT 0, ' +
    '`autoUpdate` INTEGER NOT NULL DEFAULT 0, ' +
    '`sourceJson` TEXT NOT NULL DEFAULT \'\', ' +
    'PRIMARY KEY(`id`)' +
    ')';

  // 第七批（server 类）：servers.json 的 AES 往返需要落库；无外键依赖，追加在末尾即可。
  // id 不加 AUTOINCREMENT：上游由客户端 System.currentTimeMillis() 生成，恢复备份要保留原值，
  // 重新分配会让同一台设备的多条记录互相覆盖。config 不带 NOT NULL：上游是 String?，null 表示尚未配置。
  static readonly createServers: string =
    'CREATE TABLE IF NOT EXISTS `servers` (' +
    '`id` INTEGER NOT NULL, ' +
    "`name` TEXT NOT NULL DEFAULT '', " +
    '`type` INTEGER NOT NULL DEFAULT 0, ' +
    '`config` TEXT, ' +
    '`sortNumber` INTEGER NOT NULL DEFAULT 0, ' +
    "`sourceJson` TEXT NOT NULL DEFAULT '', " +
    'PRIMARY KEY(`id`)' +
    ')';

  static readonly createServersSortIndex: string =
    'CREATE INDEX IF NOT EXISTS `index_servers_sortNumber` ' +
    'ON `servers` (`sortNumber`)';

  // ===== 批8 B 组：知识库五表，逐列照抄上游 BookKnowledge.kt 的 Room 实体 =====
  // 主键 id 是 String（上游 @PrimaryKey val id: String），映射为 TEXT PRIMARY KEY。
  // 可空列（avatarUri / chapterIndex / sourceTextHash / parentId / scope* / start* / end*）不带 NOT NULL。
  // confidence 是 Float → REAL；status / schemaVersion / createdAt / updatedAt 是 Int/Long → INTEGER。
  static readonly createBookCharacterProfiles: string =
    'CREATE TABLE IF NOT EXISTS book_character_profiles (' +
    'id TEXT PRIMARY KEY, ' +
    "bookUrl TEXT NOT NULL DEFAULT '', " +
    "name TEXT NOT NULL DEFAULT '', " +
    "aliasesJson TEXT NOT NULL DEFAULT '[]', " +
    'avatarUri TEXT, ' +
    "tagsJson TEXT NOT NULL DEFAULT '[]', " +
    "role TEXT NOT NULL DEFAULT '', " +
    "voiceGender TEXT NOT NULL DEFAULT 'unknown', " +
    "voiceAgeBand TEXT NOT NULL DEFAULT 'unknown', " +
    "personality TEXT NOT NULL DEFAULT '', " +
    "summary TEXT NOT NULL DEFAULT '', " +
    'status INTEGER NOT NULL DEFAULT 1, ' +
    "source TEXT NOT NULL DEFAULT 'user', " +
    'confidence REAL NOT NULL DEFAULT 1, ' +
    'schemaVersion INTEGER NOT NULL DEFAULT 1, ' +
    'createdAt INTEGER NOT NULL DEFAULT 0, ' +
    'updatedAt INTEGER NOT NULL DEFAULT 0' +
    ')';
  static readonly createBookCharacterProfilesIndex: string =
    'CREATE UNIQUE INDEX IF NOT EXISTS index_book_character_profiles_bookUrl_name ' +
    'ON book_character_profiles (bookUrl, name)';
  static readonly createBookCharacterProfilesUpdatedIndex: string =
    'CREATE INDEX IF NOT EXISTS index_book_character_profiles_bookUrl_updatedAt ' +
    'ON book_character_profiles (bookUrl, updatedAt)';

  static readonly createBookCharacterEvents: string =
    'CREATE TABLE IF NOT EXISTS book_character_events (' +
    'id TEXT PRIMARY KEY, ' +
    "bookUrl TEXT NOT NULL DEFAULT '', " +
    "characterId TEXT NOT NULL DEFAULT '', " +
    'chapterIndex INTEGER, ' +
    "chapterTitle TEXT NOT NULL DEFAULT '', " +
    "eventTimeText TEXT NOT NULL DEFAULT '', " +
    "content TEXT NOT NULL DEFAULT '', " +
    'importance INTEGER NOT NULL DEFAULT 0, ' +
    'sourceTextHash TEXT, ' +
    "evidenceJson TEXT NOT NULL DEFAULT '[]', " +
    "source TEXT NOT NULL DEFAULT 'user', " +
    'confidence REAL NOT NULL DEFAULT 1, ' +
    'schemaVersion INTEGER NOT NULL DEFAULT 1, ' +
    'createdAt INTEGER NOT NULL DEFAULT 0, ' +
    'updatedAt INTEGER NOT NULL DEFAULT 0' +
    ')';
  static readonly createBookCharacterEventsIndex: string =
    'CREATE INDEX IF NOT EXISTS index_book_character_events_bookUrl_characterId_chapterIndex ' +
    'ON book_character_events (bookUrl, characterId, chapterIndex)';
  static readonly createBookCharacterEventsChapterIndex: string =
    'CREATE INDEX IF NOT EXISTS index_book_character_events_bookUrl_chapterIndex ' +
    'ON book_character_events (bookUrl, chapterIndex)';

  static readonly createBookCharacterRelations: string =
    'CREATE TABLE IF NOT EXISTS book_character_relations (' +
    'id TEXT PRIMARY KEY, ' +
    "bookUrl TEXT NOT NULL DEFAULT '', " +
    "fromCharacterId TEXT NOT NULL DEFAULT '', " +
    "toCharacterId TEXT NOT NULL DEFAULT '', " +
    "relationType TEXT NOT NULL DEFAULT '', " +
    "summary TEXT NOT NULL DEFAULT '', " +
    "attitude TEXT NOT NULL DEFAULT '', " +
    "evidenceJson TEXT NOT NULL DEFAULT '[]', " +
    'chapterIndex INTEGER, ' +
    'status INTEGER NOT NULL DEFAULT 1, ' +
    "source TEXT NOT NULL DEFAULT 'user', " +
    'confidence REAL NOT NULL DEFAULT 1, ' +
    'schemaVersion INTEGER NOT NULL DEFAULT 1, ' +
    'createdAt INTEGER NOT NULL DEFAULT 0, ' +
    'updatedAt INTEGER NOT NULL DEFAULT 0' +
    ')';
  static readonly createBookCharacterRelationsIndex: string =
    'CREATE UNIQUE INDEX IF NOT EXISTS index_book_character_relations_bookUrl_from_to ' +
    'ON book_character_relations (bookUrl, fromCharacterId, toCharacterId)';
  static readonly createBookCharacterRelationsFromIndex: string =
    'CREATE INDEX IF NOT EXISTS index_book_character_relations_bookUrl_fromCharacterId ' +
    'ON book_character_relations (bookUrl, fromCharacterId)';
  static readonly createBookCharacterRelationsToIndex: string =
    'CREATE INDEX IF NOT EXISTS index_book_character_relations_bookUrl_toCharacterId ' +
    'ON book_character_relations (bookUrl, toCharacterId)';

  static readonly createBookKnowledgeEntries: string =
    'CREATE TABLE IF NOT EXISTS book_knowledge_entries (' +
    'id TEXT PRIMARY KEY, ' +
    "bookUrl TEXT NOT NULL DEFAULT '', " +
    "type TEXT NOT NULL DEFAULT '', " +
    "title TEXT NOT NULL DEFAULT '', " +
    "keywordsJson TEXT NOT NULL DEFAULT '[]', " +
    "content TEXT NOT NULL DEFAULT '', " +
    'scopeStartChapter INTEGER, ' +
    'scopeEndChapter INTEGER, ' +
    'priority INTEGER NOT NULL DEFAULT 0, ' +
    "source TEXT NOT NULL DEFAULT 'user', " +
    'confidence REAL NOT NULL DEFAULT 1, ' +
    "evidenceJson TEXT NOT NULL DEFAULT '[]', " +
    'schemaVersion INTEGER NOT NULL DEFAULT 1, ' +
    'createdAt INTEGER NOT NULL DEFAULT 0, ' +
    'updatedAt INTEGER NOT NULL DEFAULT 0' +
    ')';
  static readonly createBookKnowledgeEntriesIndex: string =
    'CREATE INDEX IF NOT EXISTS index_book_knowledge_entries_bookUrl_type_priority ' +
    'ON book_knowledge_entries (bookUrl, type, priority)';
  static readonly createBookKnowledgeEntriesTitleIndex: string =
    'CREATE INDEX IF NOT EXISTS index_book_knowledge_entries_bookUrl_title ' +
    'ON book_knowledge_entries (bookUrl, title)';

  static readonly createBookOutlineNodes: string =
    'CREATE TABLE IF NOT EXISTS book_outline_nodes (' +
    'id TEXT PRIMARY KEY, ' +
    "bookUrl TEXT NOT NULL DEFAULT '', " +
    'parentId TEXT, ' +
    "nodeType TEXT NOT NULL DEFAULT '', " +
    "title TEXT NOT NULL DEFAULT '', " +
    "summary TEXT NOT NULL DEFAULT '', " +
    'startChapterIndex INTEGER, ' +
    'endChapterIndex INTEGER, ' +
    '`order` INTEGER NOT NULL DEFAULT 0, ' +
    "source TEXT NOT NULL DEFAULT 'user', " +
    'confidence REAL NOT NULL DEFAULT 1, ' +
    'schemaVersion INTEGER NOT NULL DEFAULT 1, ' +
    'createdAt INTEGER NOT NULL DEFAULT 0, ' +
    'updatedAt INTEGER NOT NULL DEFAULT 0' +
    ')';
  static readonly createBookOutlineNodesIndex: string =
    'CREATE INDEX IF NOT EXISTS index_book_outline_nodes_bookUrl_nodeType_scope ' +
    'ON book_outline_nodes (bookUrl, nodeType, startChapterIndex, endChapterIndex)';
  static readonly createBookOutlineNodesParentIndex: string =
    'CREATE INDEX IF NOT EXISTS index_book_outline_nodes_bookUrl_parent_order ' +
    'ON book_outline_nodes (bookUrl, parentId, `order`)';

  /**
   * 批8 C 组（:922）：书源/文本规则编辑页键盘上方的快捷符号配置。
   * 与上游 KeyboardAssist.kt 一致，主键是复合的 (type, key)——这是全库唯一不用 id 的表，
   * 漏掉复合主键会建出重键表，恢复时同键多行会被 REPLACE 静默覆盖。
   * type：0 = txt 规则，1 = 书源规则；本地默认 32 条 type 均为 0（上游 JSON 无 type 字段，取默认值）。
   */
  static readonly createKeyboardAssists: string =
    'CREATE TABLE IF NOT EXISTS `keyboardAssists` (' +
    '`type` INTEGER NOT NULL DEFAULT 0, ' +
    '`key` TEXT NOT NULL DEFAULT \'\', ' +
    '`value` TEXT NOT NULL DEFAULT \'\', ' +
    '`serialNo` INTEGER NOT NULL DEFAULT 0, ' +
    'PRIMARY KEY(`type`, `key`))';

  /** 全部建表语句，按依赖顺序排列。 */
  private static readonly allStatements: string[] = [
    RdbSchema.createBookmarks,
    RdbSchema.createBookmarksIndex,
    RdbSchema.createBookMarks,
    RdbSchema.createBookMarksIndex,
    RdbSchema.createSearchContentHistory,
    RdbSchema.createSearchContentHistoryIndex,
    RdbSchema.createBookGroups,
    RdbSchema.createReplaceRules,
    RdbSchema.createReplaceRulesIndex,
    RdbSchema.createTxtTocRules,
    RdbSchema.createHighlightRules,
    RdbSchema.createBookContentProcesses,
    RdbSchema.createBookContentProcessesIndex1,
    RdbSchema.createBookContentProcessesIndex2,
    RdbSchema.createBookContentProcessesIndex3,
    // 第三批：books 必须在 chapters 之前，chapters 的外键指向 books
    RdbSchema.createBooks,
    RdbSchema.createBooksIndexNameAuthor,
    RdbSchema.createBooksIndexDurChapterTime,
    RdbSchema.createChapters,
    RdbSchema.createChaptersIndexBookUrl,
    RdbSchema.createChaptersIndexBookUrlIndex,
    RdbSchema.createReadRecord,
    RdbSchema.createReadRecordDetail,
    RdbSchema.createReadRecordSession,
    // 第四批（ZIP 兼容总账批 3）：G2 五类新表，无外键依赖，追加在末尾即可
    RdbSchema.createDictRules,
    RdbSchema.createHomepageModules,
    RdbSchema.createHomepageCustomSets,
    RdbSchema.createHighlightTagRules,
    RdbSchema.createTagGroupRules,
    // 第五批（httpTTS 数据层）：索引必须排在表之后，其余无外键依赖，追加在末尾即可
    RdbSchema.createHttpTts,
    RdbSchema.createReadAloudVoices,
    RdbSchema.createReadAloudVoicesUniqueIndex,
    // 第六批（A 组四类数据层）：无外键依赖，追加在末尾即可
    RdbSchema.createBookSources,
    RdbSchema.createRssSources,
    RdbSchema.createRssStars,
    RdbSchema.createRuleSubs,
    // 第七批（server 类）：无外键依赖，追加在末尾即可
    RdbSchema.createServers,
    RdbSchema.createServersSortIndex,
    // 批8 B 组：知识库五表与其索引；无外键依赖，索引排在表之后
    RdbSchema.createBookCharacterProfiles,
    RdbSchema.createBookCharacterProfilesIndex,
    RdbSchema.createBookCharacterProfilesUpdatedIndex,
    RdbSchema.createBookCharacterEvents,
    RdbSchema.createBookCharacterEventsIndex,
    RdbSchema.createBookCharacterEventsChapterIndex,
    RdbSchema.createBookCharacterRelations,
    RdbSchema.createBookCharacterRelationsIndex,
    RdbSchema.createBookCharacterRelationsFromIndex,
    RdbSchema.createBookCharacterRelationsToIndex,
    RdbSchema.createBookKnowledgeEntries,
    RdbSchema.createBookKnowledgeEntriesIndex,
    RdbSchema.createBookKnowledgeEntriesTitleIndex,
    RdbSchema.createBookOutlineNodes,
    RdbSchema.createBookOutlineNodesIndex,
    RdbSchema.createBookOutlineNodesParentIndex,
    // 批8 C 组：keyboardAssists 复合主键表；与知识库五表同批在 v10 里建出
    RdbSchema.createKeyboardAssists,
    // 备份功能盘查批：search_keywords 表与其唯一索引（v11）；无外键依赖，索引排在表之后
    RdbSchema.createSearchKeywords,
    RdbSchema.createSearchKeywordsIndex
  ];

  /**
   * 建表并更新版本号。
   * 全部语句都是 IF NOT EXISTS，重复执行无副作用，
   * 所以不需要按版本号分支——新增表时往 allStatements 追加即可。
   */
  static async ensure(store: relationalStore.RdbStore): Promise<void> {
    for (let index = 0; index < RdbSchema.allStatements.length; index++) {
      const statement = RdbSchema.allStatements[index];
      if (statement === undefined) { continue; }
      await store.executeSql(statement);
    }
    // books.format 是后加的列：CREATE TABLE IF NOT EXISTS 不会给老库补列，
    // 必须单独 ALTER；ensure() 会被反复调用，所以只能靠吞「duplicate column」做到幂等。
    try {
      await store.executeSql("ALTER TABLE books ADD COLUMN format TEXT NOT NULL DEFAULT ''");
    } catch (_) {
      // 列已存在（duplicate column name）是正常路径，不记错误
    }
    // highlightRules 三个边框列是后加的：CREATE TABLE IF NOT EXISTS 不会给老库补列。
    // 与 books.format 同样靠吞「duplicate column」做到幂等。
    try {
      await store.executeSql("ALTER TABLE highlightRules ADD COLUMN borderColor INTEGER");
    } catch (_) {
      // 列已存在（duplicate column name）是正常路径，不记错误
    }
    try {
      await store.executeSql("ALTER TABLE highlightRules ADD COLUMN borderWidth REAL NOT NULL DEFAULT 1");
    } catch (_) {
    }
    try {
      await store.executeSql("ALTER TABLE highlightRules ADD COLUMN borderRadius REAL NOT NULL DEFAULT 4");
    } catch (_) {
    }
    // 朗读批 8：httpTTS 三个本地扩展列。老库靠吞「duplicate column」做到幂等，
    // 新库 createHttpTts 已含这三列、ALTER 走到 duplicate 分支被吞，两条路径都安全。
    try {
      await store.executeSql("ALTER TABLE httpTTS ADD COLUMN textParam TEXT NOT NULL DEFAULT 'text'");
    } catch (_) {
    }
    try {
      await store.executeSql("ALTER TABLE httpTTS ADD COLUMN speedParam TEXT NOT NULL DEFAULT 'speed'");
    } catch (_) {
    }
    try {
      await store.executeSql("ALTER TABLE httpTTS ADD COLUMN toneParam TEXT NOT NULL DEFAULT 'tone'");
    } catch (_) {
    }
    if (store.version !== RdbSchema.version) {
      store.version = RdbSchema.version;
    }
  }
}
