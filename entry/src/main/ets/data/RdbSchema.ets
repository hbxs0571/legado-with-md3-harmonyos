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
  /** 当前 schema 版本，与 RdbStore.version 比对决定是否建表。第二批追加五张表后升到 2。 */
  static readonly version: number = 2;

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
   * 注意 14 个 REAL 列：读的时候必须用 RdbCodec.real()（内部 getDouble），
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
    RdbSchema.createBookContentProcessesIndex3
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
    if (store.version !== RdbSchema.version) {
      store.version = RdbSchema.version;
    }
  }
}
