# 关系型存储迁移计划（preferences → relationalStore）

## 目标与边界

把本地 10 个业务数据仓储从 `preferences`（整个列表序列化成一个大字符串）迁到 `@kit.ArkData` 的 `relationalStore`（SQLite 内核），使数据模型与上游 Room 对齐：书籍与章节拆成两张表、书签与划线各归各表、阅读记录恢复三层结构。

**已定调（2026-10-30）**：分三批推进；章节拆独立 `chapters` 表；存量数据首次启动自动搬迁一次（方案 a）。

**不在本计划内**：设置类仓储（上游也是键值对）、文件类仓储（存的是文件不是表）、网络书源与 RSS（本地未迁移该功能）、AI 相关表（本地未迁移）。

**本轮只出计划，不改任何 `.ets` 代码。**

## 上游 Room 现状

| 指标 | 数量 | 位置 |
| --- | --- | --- |
| 实体文件 | 58 | `app/src/main/java/io/legado/app/data/entities/` |
| 表 | 65 | 见 `@Entity(tableName = ...)` |
| DAO 接口 | 48 | `app/src/main/java/io/legado/app/data/dao/` |
| 数据库版本 | 132 | `AppDatabase.kt:139` |

注意 `BgmPoolEntities.kt`（4 张）、`BookKnowledge.kt`（5 张）、`ReadAloudSpeech.kt`（4 张）、`VoicePoolEntities.kt`（3 张）各含多张表，所以表数（65）大于实体文件数（58）。

**数字口径**（2026-10-30 实测）：`@Entity` 注解共 65 处，去重后的 `tableName` 也是 65 个，两种算法一致，全部带显式 `tableName`，无靠类名兜底的实体。DAO 接口 48 个与 `data/dao/` 下文件数 48 相等。数据库版本取自 `AppDatabase.kt:139` 的 `version = 132,`。

**上游并非全部数据都在 Room**：设置类走 DataStore Preferences（`help/config/AppConfigStore.kt:53`），与鸿蒙 `preferences` 同构，本地这块已经对齐，不迁。

## 本地现状

`entry/src/main/ets/data/` 共 30 个文件，分四类：

| 类别 | 数量 | 行数 | 处理 |
| --- | --- | --- | --- |
| 业务数据仓储 | 10 | 4587 | **要迁** |
| 设置项仓储 | 5 | — | 不迁（上游也是键值对） |
| 文件读写仓储 | 4 | — | 不迁（存文件不存表） |
| 引擎 / 排序 / 导入器 / 备份 | 11 | 3737 | 不迁（不持有自己的表），但**备份是迁移的耦合点** |

设置类：`ReaderSettingsRepository`（107 次 `store.put`）、`BookshelfLayoutRepository`（9 次）、`HomeDashboardSettingsRepository`（1 次）、`OnboardingRepository`（3 次）、`ReaderMoreActionsRepository`（1 次）。

文件类：`EpubRepository`、`ReaderFontRepository`、`ReaderBookmarkBadgeRepository`、`ReaderBookmarkExporter`。

第四类此前被漏在分类之外，逐个列明：

| 文件 | 行数 | 说明 |
| --- | --- | --- |
| `BackupRepository.ets` | 1943 | 备份导出与恢复。**`data/` 目录第二大的文件，引用 10 个待迁仓储中的 7 个**，见下节 |
| `LocalTextReSegmenter.ets` | 430 | 本地书重新分章 |
| `ReaderBookmarkImporter.ets` | 252 | 书签导入解析（不写仓储） |
| `BookContentProcessEngine.ets` | 192 | 正文处理规则执行 |
| `ReaderHighlightRulePresets.ets` | 170 | 高亮规则预设 |
| `ReplaceRuleImporter.ets` | 167 | 替换规则导入解析 |
| `TxtTocRuleImporter.ets` | 131 | TXT 目录规则导入解析 |
| `LocalTextSemantics.ets` | 129 | 本地书文本语义 |
| `ReaderHighlightRuleEngine.ets` | 124 | 高亮规则执行 |
| `ReaderBookmarkTarget.ets` | 114 | 书签跳转目标解析 |
| `BookshelfSort.ets` | 85 | 书架排序 |

### 要迁的 10 个仓储

| 本地仓储 | 行数 | preferences 名 | 键 | 上游表 |
| --- | --- | --- | --- | --- |
| `BookRepository.ets` | 1602 | `legado_local_books` | `books` | `books` + `chapters` |
| `ReplaceRuleRepository.ets` | 769 | `legado_replace_rules` | `rules_v1` | `replace_rules` |
| `ReadRecordRepository.ets` | 669 | `legado_read_records` | `sessions_v1` / `details_v1` / `summaries_v1` / `enabled` | `readRecord` + `readRecordDetail` + `readRecordSession` |
| `TxtTocRuleRepository.ets` | 568 | `legado_txt_toc_rules` | `rules_v1` | `txtTocRules` |
| `BookGroupRepository.ets` | 400 | `book_group_store` | — | `book_groups` |
| `ReaderHighlightRuleRepository.ets` | 184 | `legado_reader_highlight_rules` | `rules_v1` | `highlightRules` |
| `BookContentProcessRepository.ets` | 149 | `legado_book_content_processes` | `records_v1` | `book_content_processes` |
| `ReaderMarkingRepository.ets` | 91 | `legado_reader_markings` | — | `book_marks` |
| `ReaderSearchHistoryRepository.ets` | 83 | `legado_reader_search_history` | `records_v1` | `search_content_history` |
| `ReaderBookmarkRepository.ets` | 72 | `legado_reader_bookmarks` | — | `bookmarks` |

外部引用实测（2026-10-30，`entry/src/main/ets` 下 `data/` 之外）：

| 仓储 | 外部引用文件数 | 外部表达式数 |
| --- | --- | --- |
| `BookRepository` | 4 | 82 |
| `ReplaceRuleRepository` | 4 | 62 |
| `TxtTocRuleRepository` | 2 | 26 |
| `ReadRecordRepository` | 3 | 22 |
| `BookGroupRepository` | 1 | 20 |
| `BookContentProcessRepository` | 2 | 6 |
| `ReaderBookmarkRepository` | 1 | 5 |
| `ReaderMarkingRepository` | 1 | 4 |
| `ReaderSearchHistoryRepository` | 1 | 4 |
| `ReaderHighlightRuleRepository` | 2 | 3 |
| **合计** | **21** | **234** |

**「调用点」的口径**：本文此前写作 35 处，用两种口径都无法复现——按文件数是 21，按 `仓储名.方法` 表达式是 234。上文统一取「外部引用表达式数」，因为接口签名变化时被牵连的是表达式而不是文件。

### 本地序列化格式（搬迁时必须复用现有解析）

`BookRepository` 用版本化文本协议：`v15\n` 开头，每行一本书，字段用 `|` 分隔，每字段 `encodeURIComponent`，章节标题用 `;` 连接。已积累 v1–v15 共 15 个兼容分支（`BookRepository.ets:307-345`）。

**搬迁解析必须调用现有解析逻辑，不能重写。** 15 个历史版本分支是线上真实数据，重写等于把兼容层再写一遍。

## 鸿蒙 relationalStore 能力核实

SDK：`D:\Program Files\Huawei\DevEco Studio\sdk\default\openharmony\ets\api\@ohos.data.relationalStore.d.ts`（apiVersion 26 / 26.0.0.105）。
项目 `compatibleSdkVersion` / `targetSdkVersion` 均为 `5.0.0(12)`。

| 能力 | 接口 | @since | 可用 |
| --- | --- | --- | --- |
| 打开库 | `getRdbStore(context, config)` | 9 | ✅ |
| SQL 执行 | `executeSql(sql, bindArgs?)` / `execute(sql, args?)` | 9 | ✅ |
| SQL 查询 | `querySql(sql, bindArgs?)` | 9 | ✅ |
| 增删改 | `insert(table, values)` / `update` / `delete` | 9 | ✅ |
| 事务（老式） | `beginTransaction()` / `commit()` / `rollBack()` | 9 | ✅ |
| 事务（新式并发） | `createTransaction(options?)` | **12** | ✅ |
| 结果集 | `goToNextRow()` / `getString(idx)` / `getLong(idx)` / `getColumnIndex(name)` / `rowCount` / `close()` | 9 | ✅ |
| 版本号 | `RdbStore.version` | 9 | ✅ |
| 安全等级 | `SecurityLevel.S1/S2/...` | 9 | ✅ |

**结论：平台能力完全够，无阻塞。** 缺的只是 Room 那种注解代码生成（KSP），须手写建表 SQL 与结果集解析——这正是本计划的主要风险来源。

项目目前**零处**使用 `relationalStore`。`data/` 下共 19 个 `*Repository.ets`，其中 **16 个使用 `preferences`**（10 个待迁业务仓储 + 5 个设置仓储 + `BackupRepository`），另 3 个（`EpubRepository`、`ReaderFontRepository`、`ReaderBookmarkBadgeRepository`）只做文件读写。

## 目标表结构

共 13 张表。字段名、类型、主键、索引、外键全部对齐上游；本地自有字段单独标注为「本地扩展」。

### 1. `books`

主键 `bookUrl`。索引：`(name, author)`、`(durChapterTime)`。

| 列 | 类型 | 默认 | 来源 |
| --- | --- | --- | --- |
| `bookUrl` | TEXT PK | `''` | `Book.id`（本地书是文件路径） |
| `tocUrl` | TEXT | `''` | 本地无，写 `''` |
| `origin` | TEXT | `BookType.localTag` | `Book.isLocal` → 本地书 |
| `originName` | TEXT | `''` | 本地书文件名 |
| `name` | TEXT | `''` | `Book.title` |
| `author` | TEXT | `''` | `Book.author` |
| `kind` | TEXT? | — | `Book.category` |
| `customTag` | TEXT? | — | `Book.customTag` |
| `coverUrl` | TEXT? | — | `Book.coverUri` |
| `customCoverUrl` | TEXT? | — | `Book.customCoverUri` |
| `intro` | TEXT? | — | `Book.description` |
| `customIntro` | TEXT? | — | 本地无 |
| `remark` | TEXT? | — | `Book.remark` |
| `charset` | TEXT? | — | `Book.charset` |
| `type` | INTEGER | `0` | `Book.format`（txt/epub） |
| `group` | INTEGER | `0` | `Book.groupName` 解析出的 groupId |
| `isPrivate` | INTEGER | `0` | 本地无，写 `0` |
| `latestChapterTitle` | TEXT? | — | 本地无 |
| `latestChapterTime` | INTEGER | `0` | `Book.latestChapterTime` |
| `lastCheckTime` | INTEGER | `0` | 本地无 |
| `lastCheckCount` | INTEGER | `0` | 本地无 |
| `totalChapterNum` | INTEGER | `0` | `chapters` 表行数 |
| `durChapterTitle` | TEXT? | — | `Book.lastChapter` |
| `durChapterIndex` | INTEGER | `0` | `Book.chapterIndex` |
| `durChapterPos` | INTEGER | `0` | `Book.chapterProgress` |
| `durChapterTime` | INTEGER | `0` | `Book.durChapterTime` |
| `wordCount` | TEXT? | — | 本地无 |
| `canUpdate` | INTEGER | `1` | 本地无，写 `0` |
| `disableReadRecord` | INTEGER | `0` | 本地无，写 `0` |
| `order` | INTEGER | `0` | `Book.order` |
| `originOrder` | INTEGER | `0` | 本地无 |
| `variable` | TEXT? | — | 本地无 |
| `readConfig` | TEXT? | — | 本地无 |
| `syncTime` | INTEGER | `0` | 本地无 |
| `listIntro` | TEXT? | — | 本地无 |
| **`coverColor`** | TEXT? | — | **本地扩展** `Book.coverColor` |
| **`coverMark`** | TEXT? | — | **本地扩展** `Book.coverMark` |
| **`imageStyle`** | TEXT? | — | **本地扩展** `Book.imageStyle` |
| **`reSegment`** | INTEGER? | — | **本地扩展** `Book.reSegment` |
| **`bodyMissing`** | INTEGER? | — | **本地扩展** `Book.bodyMissing` |
| **`androidOriginalPath`** | TEXT? | — | **本地扩展** `Book.androidOriginalPath` |
| **`androidCharacterPosition`** | INTEGER? | — | **本地扩展** `Book.androidCharacterPosition` |
| **`readerPositionVersion`** | INTEGER? | — | **本地扩展** `Book.readerPositionVersion` |
| **`tocRule`** | TEXT? | — | **本地扩展** `Book.tocRule`（上游存在 `book_sources`） |
| **`fileSizeBytes`** | INTEGER? | — | **本地扩展** `Book.fileSizeBytes` |
| **`fixedType`** | TEXT? | — | **本地扩展** `Book.fixedType` |

本地扩展字段保留在 `books` 表内，不另建表。理由：它们与书一一对应、无独立查询需求，拆表只会增加 JOIN。

### 2. `chapters`

主键 `(url, bookUrl)`。索引：`(bookUrl)`、`(bookUrl, index)` UNIQUE。外键 `bookUrl → books.bookUrl ON DELETE CASCADE`。

| 列 | 类型 | 来源 |
| --- | --- | --- |
| `url` | TEXT | 本地无，写 `''`（本地书无章节 URL） |
| `title` | TEXT | `Book.chapterTitles[i]` |
| `isVolume` | INTEGER | `Book.chapterVolumes[i]` |
| `tocLevel` | INTEGER | `0` |
| `baseUrl` | TEXT | `''` |
| `bookUrl` | TEXT | `Book.id` |
| `index` | INTEGER | 数组下标 `i` |
| `isVip` | INTEGER | `0` |
| `isPay` | INTEGER | `0` |
| `resourceUrl` | TEXT? | — |
| `tag` | TEXT? | — |
| `wordCount` | TEXT? | — |
| `start` | INTEGER? | `Book.chapterOffsets[i]` |
| `end` | INTEGER? | 下一章 `start` |
| `startFragmentId` | TEXT? | — |
| `endFragmentId` | TEXT? | — |
| `variable` | TEXT? | — |
| `reviewImg` | TEXT? | — |

**注意**：本地 `url` 恒为空串，而上游 `url` 是主键组成部分。空串作主键的一部分会让 `(url, bookUrl)` 退化成 `bookUrl`，同一本书的多个章节全部冲突。**迁移时必须给 `url` 赋一个稳定合成值**，例如 `local://<bookUrl>#<index>`。这一点在实施时最容易踩。

### 3. `bookmarks`

主键 `time`。索引：`(bookName, bookAuthor)`。

| 列 | 类型 | 来源 |
| --- | --- | --- |
| `time` | INTEGER PK | `ReaderBookmark.createdAt` |
| `bookName` | TEXT | `ReaderBookmark.bookName` |
| `bookAuthor` | TEXT | `ReaderBookmark.bookAuthor` |
| `bookUrl` | TEXT | `ReaderBookmark.bookUrl` |
| `chapterIndex` | INTEGER | `ReaderBookmark.chapterIndex` |
| `chapterPos` | INTEGER | `ReaderBookmark.chapterPosition` |
| `chapterName` | TEXT | `ReaderBookmark.chapterName` |
| `bookText` | TEXT | `ReaderBookmark.bookText` |
| `content` | TEXT | `ReaderBookmark.content` |

**主键冲突风险**：本地 `id` 是字符串，上游主键是 `createdAt` 时间戳。同毫秒创建的两条书签会冲突。实施时须在搬迁阶段检测重复 `createdAt` 并递增消解。

### 4. `book_marks`

主键 `id`。索引：`(bookUrl, chapterIndex)`。

| 列 | 类型 | 来源 |
| --- | --- | --- |
| `id` | TEXT PK | `ReaderMarking.id` |
| `bookUrl` | TEXT | `ReaderMarking.bookUrl` |
| `bookName` | TEXT | `ReaderMarking.bookName` |
| `bookAuthor` | TEXT | `ReaderMarking.bookAuthor` |
| `chapterIndex` | INTEGER? | `ReaderMarking.chapterIndex` |
| `anchorJson` | TEXT | 由 `chapterPosition`/`endPosition`/`selectedText`/`contextBefore`/`contextAfter` 合成 |
| `styleJson` | TEXT? | 由 `effect`/`color` 合成 |
| `note` | TEXT | `ReaderMarking.note` |
| `chapterName` | TEXT | `ReaderMarking.chapterName` |
| `enabled` | INTEGER | `ReaderMarking.enabled` |
| `createdAt` | INTEGER | `ReaderMarking.createdAt` |
| `updatedAt` | INTEGER | `ReaderMarking.updatedAt` |

**这是唯一需要「结构转换」而不是「字段搬运」的表**。本地把锚点拆成 5 个平铺列、把样式拆成 2 个平铺列；上游把两者都塞进 JSON 字符串。`anchorJson` 的结构必须与上游 `TextProcessAnchor` 一致（本地已有同名接口在 `model/BookContentProcess.ets:23`，可复用序列化逻辑）。

### 5. `book_groups`

主键 `groupId`。字段与本地 `BookGroup` 一一对应，无需转换。

### 6. `replace_rules`

主键 `id`。字段与本地 `ReplaceRule` 一一对应。**唯一差异**：本地 `group`/`scope`/`excludeScope` 是 `string`（空串表示无），上游是 `String?`（null 表示无）。搬迁时把空串转 null。

另注意上游 `order` 字段的**列名是 `sortOrder`**（`@ColumnInfo(name = "sortOrder")`），建表时不能写成 `order`（SQL 关键字）。

### 7. `txtTocRules`

主键 `id`。字段与本地 `TxtTocRule` 一一对应，无转换。

### 8. `readRecord`

主键 `(deviceId, bookName, bookAuthor)`。本地 `ReadRecordSummary` 直接对应，无转换。

### 9. `readRecordDetail`

主键 `(deviceId, bookName, bookAuthor, date)`。本地 `ReadRecordDetail` 直接对应，无转换。

### 10. `readRecordSession`

主键 `id` AUTOINCREMENT。

| 列 | 类型 | 来源 |
| --- | --- | --- |
| `id` | INTEGER PK AUTOINCREMENT | 本地无此字段，由 DB 生成 |
| `deviceId` | TEXT | `ReadRecordSession.deviceId` |
| `bookName` | TEXT | `ReadRecordSession.bookName` |
| `bookAuthor` | TEXT | `ReadRecordSession.bookAuthor` |
| `bookUrl` | TEXT | `ReadRecordSession.bookUrl` |
| `startTime` | INTEGER | `ReadRecordSession.startTime` |
| `endTime` | INTEGER | `ReadRecordSession.endTime` |
| `words` | INTEGER | `ReadRecordSession.chapterIndex` |

**列名陷阱**：本地字段叫 `chapterIndex`（语义是章节序号），上游列名叫 `words`（上游注释也自认「不是字数」）。搬迁时按上游列名 `words` 建表，否则与上游备份文件对不上。

### 11. `book_content_processes`

主键 `id`。索引：`(bookUrl, chapterIndex, enabled, sortOrder)`、`(bookUrl, kind)`、`(aiArtifactId)`。字段与本地 `BookContentProcess` 完全一一对应（本地模型本就是照上游写的），无转换。

### 12. `highlightRules`

主键 `id`。字段与本地 `ReaderHighlightRule` 一一对应。本地已有 35 个字段，含 `bgLengthOffsetLeft`/`bgLengthOffsetRight` 两个扩展。

**注意**：上游该实体字段远超本地 35 个（`HighlightRule.kt` 有九宫格、字距、行距等大量样式列）。建表时**只建本地已有的 35 列**，其余上游列不建——本地无对应能力，建了也是空列。

### 13. `search_content_history`

主键 `id` AUTOINCREMENT。索引：`(bookName, bookAuthor, query)` UNIQUE。

| 列 | 类型 | 来源 |
| --- | --- | --- |
| `id` | INTEGER PK AUTOINCREMENT | 本地 `id` 是 string，须转为自增 |
| `bookName` | TEXT? | `ReaderSearchHistoryEntry.bookName` |
| `bookAuthor` | TEXT? | `ReaderSearchHistoryEntry.bookAuthor` |
| `query` | TEXT | `ReaderSearchHistoryEntry.query` |
| `time` | INTEGER | `ReaderSearchHistoryEntry.updatedAt` |

## 分批顺序

### 第一批：小仓储 + 基础设施（246 行，3 个仓储，13 处外部引用）

`ReaderBookmarkRepository`（72）、`ReaderMarkingRepository`（91）、`ReaderSearchHistoryRepository`（83）。

同时落地所有后续批次复用的基础设施：

1. `data/RdbStore.ets`：单例打开库（`getRdbStore`，`SecurityLevel.S2`，库名 `legado.db`），暴露 `getStore(): Promise<RdbStore>`。
2. `data/RdbSchema.ets`：建表 SQL 常量 + `CREATE TABLE IF NOT EXISTS` 执行器 + `RdbStore.version` 版本管理（本次 `version = 1`）。
3. `data/RdbMigration.ets`：存量搬迁骨架（见下节）。
4. `data/RdbCodec.ets`：结果集 → 模型的通用读取辅助（`getColumnIndex` + 类型转换），避免每个仓储重复写。

选这三个的理由：数据量最小、字段最简单（`bookmarks` 只有 9 列、`book_marks` 除两个 JSON 外都是平铺列）、外部引用只有 13 处。第一批的目的是**验证整条链路**——建库、建表、读写、搬迁、冷启动读回——而不是解决业务问题。

验收：书签新增/编辑/删除/跳转、划线新增/编辑/删除/呈现、搜索历史记录/删除/清空，全部走 DB；强停冷启后数据仍在；`preferences` 老数据仍在（未删）。

### 第二批：中等仓储（2070 行，5 个仓储，117 处外部引用）

`BookContentProcessRepository`（149）、`ReaderHighlightRuleRepository`（184）、`BookGroupRepository`（400）、`TxtTocRuleRepository`（568）、`ReplaceRuleRepository`（769）。

这批的共同点是**字段一一对应、无结构转换**，只是把「整表序列化成一个字符串」换成「逐行读写」。风险在于调用点密集（`ReplaceRuleRepository` 7 处、`TxtTocRuleRepository` 5 处），改接口签名会牵连多个页面。

验收：替换规则增删改查/分组/试跑/导入导出、TXT 目录规则增删改查/试跑、分组增删改/排序/私密、高亮规则增删改/排序、正文处理记录增删改/启用禁用。

### 第三批：大仓储 + 章节拆表（2271 行，2 个仓储，104 处外部引用）

`ReadRecordRepository`（669）、`BookRepository`（1602）。

`ReadRecordRepository` 先做：三层结构（summary/detail/session）本地已拆好，只是换个存储，风险中等。

`BookRepository` 最后做，且是**唯一需要改数据模型**的一批：`chapterTitles`/`chapterOffsets`/`chapterVolumes` 三个平行数组要拆进 `chapters` 表。

影响面：`chapterTitles` 在全仓 9 个文件被引用——`BackupRepository.ets`、`BookRepository.ets`、`EpubRepository.ets`、`model/Book.ets`、`pages/BookInfoPage.ets`、`pages/CatalogPage.ets`、`pages/Index.ets`、`pages/ReaderPage.ets`、`pages/ReaderSearchPage.ets`。

**章节数组彻底删除（推翻本节早先的「保留内存形态」）**：`Book` 模型里的 `chapterTitles` / `chapterOffsets` / `chapterVolumes` 三个数组**直接删掉**，章节一律走 `BookRepository.getChapterList(bookUrl)` 查 `chapters` 表，不做内存投影。早先那条「不删、改成只读投影」被推翻，理由三条：① 上游 `Book.kt` 实体零章节字段，章节读取全部是 `appDb.bookChapterDao.getChapterList(bookUrl)`，保留投影等于在本地再造一份上游没有的缓存，与「表结构与上游完全一致」冲突；② 投影要在每次 `loadImportedBooks` 时同步刷新，而 `chapters` 表又被 `saveImportedBooks` 整表重建，两份数据必然漂移；③ 三个数组加起来占 `Book` 对象绝大部分体积，书架五本书就有上千字符串常驻内存。代价是 9 个文件 79 处要改，但改动形态单一——「同步读数组」换成「`aboutToAppear` 里 `await` 查表存 `@State`」，属机械替换。

验收：书架加载/排序/分组/搜索、书籍详情、目录页章节列表、阅读页翻章/进度恢复、TXT 与 EPUB 各一本完整走查、备份导出/导入、强停冷启。

#### 第三批阶段 2 改动清单（按 `docs/CODE-CONVENTIONS.md` 第四节一次盘完）

**A. `Book` 模型删字段（`entry/src/main/ets/model/Book.ets`）**

删 8 个字段：`coverColor`、`coverMark`、`bodyMissing`、`fileSizeBytes`、`readerPositionVersion`、`chapterTitles`、`chapterOffsets`、`chapterVolumes`；`progress` 保留字段但不再落库（读取时由 `BookRepository.readProgress(book)` 派生）。

引用实测（`ops_grep` 全 `entry/src/main/ets`）：

| 字段 | 处数 | 分布 |
| --- | --- | --- |
| `coverColor`/`coverMark`/`bodyMissing`/`fileSizeBytes`/`readerPositionVersion` 合计 | 161 | `BookRepository` 64、`Index.ets` 46、`BookInfoPage` 9、`BackupRepository` 6、`BookCover` 5、`ProfileSubPages` 5、`EpubRepository` 4、`HomePage` 4、`ReaderPage` 4、`model/Book.ets` 5、其余 6 文件各 1–2 |
| `chapterTitles`/`chapterOffsets`/`chapterVolumes` 合计 | 244 | `BookRepository` 150、`Index.ets` 64、`EpubRepository` 8、`ReaderPage` 7、`model/Book.ets` 4、`ReaderSearchPage` 4、`BackupRepository` 3、`CatalogPage` 3、`BookInfoPage` 1 |
| `.progress` | 18 | `BookRepository` 9、`BookInfoPage` 3、`Index.ets` 2、`BookCard`/`HomePage`/`ReaderPage`/`SearchPage` 各 1 |

逐处处置：

- **`coverColor` → 运行时派生**。上游 `BookCoverModel.getRandomDefaultPath(seed = name ?: author)` 从内置图挑；本地无内置图，改为「书名哈希 → 调色板取色」，函数放 `components/BookCover.ets` 内部（`private static coverColorOf(book: Book): string`）。改 5 处渲染点：`components/BookCover.ets:79` `.backgroundColor(...)`、`pages/BookInfoPage.ets:274`、`pages/ProfileSubPages.ets:2870`（构造 `BookmarkBookSummary` 用的临时 Book 对象，`BookmarkBookSummary.coverColor` 这个 interface 字段本身保留，值改调派生函数）。占位 Book 字面量里的 `coverColor:` 全部删掉：`components/BookCard.ets:8`、`components/BookCover.ets:8`、`pages/HomePage.ets:64`、`pages/SearchPage.ets:223`、`pages/ReaderTextProcessingSheet.ets:13`、`pages/BookInfoPage.ets:11`、`pages/CatalogPage.ets:20`、`pages/ReaderPage.ets:127`、`pages/ReaderSearchPage.ets:30`、`pages/Index.ets:93`。
- **`coverMark` → 运行时派生**。取书名首字，函数 `private static coverMarkOf(book: Book): string` 与 `coverColorOf` 同处。改 `components/BookCover.ets:54` `Text(...)`、`pages/ProfileSubPages.ets:2870`。`pages/BookshelfPage.ets:65` 的 `bookCardKey` 里 `${book.coverMark ?? ''}` 换成派生调用结果。
- **`bodyMissing` → 运行时判定**。`BookRepository.isBodyMissing(book): boolean` = `book.contentPath === undefined || !fileIo.accessSync(book.contentPath)`。改 12 处判断：`components/BookCover.ets:35/:37`、`pages/BookshelfPage.ets:669`、`pages/HomePage.ets:47/:75/:146`、`pages/SearchPage.ets:28`、`pages/BookInfoPage.ets:88/:164/:192/:220/:280`、`pages/Index.ets:984/:1470/:2644/:2654/:2790/:3117/:3148`、`pages/CatalogPage.ets:264`、`pages/ReaderPage.ets:1988`。`pages/BookshelfPage.ets:65` 的 key 里 `${book.bodyMissing === true ? 1 : 0}` 换成派生结果。
- **`fileSizeBytes` → 删，不派生**。上游无此列、详情页也不显示。`pages/BookInfoPage.ets:46-47` 改为只走 `fileIo.statSync(book.contentPath).size` 分支（`:50-55` 已有该兜底，删掉前面那段即可）；`pages/BookInfoPage.ets:11` 占位字面量删掉该键。`BookRepository` 内部 10 处 `fileSizeBytes:` 拷贝全部删掉。
- **`readerPositionVersion` → 删**。搬迁时统一把存量位置换算进 `durChapterPos`（见下）。改 6 处判断：`pages/ReaderPage.ets:867/:869`、`BookRepository.ets:999/:1219/:1299`。`BookRepository.readPositionVersion`（`:1106`）随 v15 老协议一起删。
- **`progress` → 不落库，`BookRepository.readProgress(book): number` 派生**，公式照抄现 `BookRepository.ets:1241`：`chapterCount > 0 ? (chapterIndex + chapterProgress / 100) / chapterCount * 100 : 0`。18 处 `.progress` 全部改成调用该函数。

**B. 章节数组删除后各消费点改法**

- `data/EpubRepository.ets:111-154`：不再往 Book 里塞 `chapterTitles`/`chapterOffsets`，改为 `return { book: Book, chapters: EpubChapterSeed[] }`（`EpubChapterSeed = { title, startByte, endByte }`），由 `BookRepository` 在写库时转成 `chapters` 行。`EpubRepository` 内部仍按字符偏移累加，写库前用 `util.TextEncoder` 转字节。
- `pages/CatalogPage.ets:69-94`：`getAllChapters()` 删掉，改 `@State chapterRows: BookChapter[] = []`，`aboutToAppear` 里 `this.chapterRows = await BookRepository.getChapterList(this.book.contentPath ?? this.book.id)`；`getChapters()` 的 `volumeFlags` 改用 `chapterRows[index].isVolume`，`isInVolume` 用 `tocLevel > 0`。
- `pages/ReaderPage.ets:1167`、`:1180`、`:1645`、`:1676-1677`：同 CatalogPage，改查表存 `@State chapterRows`。`:1535-1536` 的 `getFullBookPaginationLayoutKey` 里 `chapterKey` 改用 `this.chapterRows.map(r => [r.url, r.title, r.start, r.end])` 的 JSON。
- `pages/ReaderSearchPage.ets:167/:183/:188/:335`：同上，`chapterCount` 用 `chapterRows.length`，`chapterTitle` 用 `chapterRows[chapterIndex].title`。
- `pages/BookInfoPage.ets:77`：`getChapterTotal()` 的兜底 `this.book.chapterTitles?.length` 改为 `@State chapterTotal`，`aboutToAppear` 里 `await BookRepository.getChapterCount(...)`（新增，`SELECT COUNT(*) FROM chapters WHERE bookUrl = ?`）。
- `pages/Index.ets` 46 处：6 处构造 Book 的字面量（`:1278`、`:1543`、`:3009`、`:3203`、`:3263`、`:3455`）删掉三个数组字段与 `progress`；`requestCreateReaderMarking`（`:982`）、`requestAddReaderBookmark`（`:1097`）、`toggleReaderBookmarkForPage`（`:1117`）改 `async` 并在内部 `await BookRepository.getChapterList(...)`，调用点 `:3866`、`:3868` 的 lambda 改 `async` 后 `await`。
- `data/BackupRepository.ets:887-893` 的 `toAndroidBookRecord`：`chapterTitles` 来源改 `await BookRepository.getChapterList(...)`（该函数已 `async`），`totalChapterCount` 用查表结果长度；`bodyMissing` 改调 `BookRepository.isBodyMissing(book)`；`:1386-1395` 构造缺正文书的字面量删掉 `coverColor`/`coverMark`/`bodyMissing`/`readerPositionVersion` 四个键。

**C. `BookRepository` 内部改造（150 处引用，但只涉及 14 个函数）**

| 函数 | 现位置 | 改法 |
| --- | --- | --- |
| `readChapter` | `:731` | 改 `async`，内部先 `await BookRepository.getChapterList(bookUrl)`，按 `chapterIndex` 取行的 `start`/`end`（字节）→ `byteRangeToCharRange(content, start, end)` 转字符偏移再 `substring` |
| `forEachChapter` | `:792` | 同上，行来自查表；无章节行时回退 `splitChapters` |
| `readAllChapters` | `:782` | 只改内部调用，签名不变 |
| `getChapterTextRange` | `:1073` | 改 `async`，入参多带 `rows: BookChapter[]`（调用方已查过表，避免重复查询） |
| `getChapterSemanticLength` | `:1093` | 改 `async`，同上 |
| `applyChapterContentAsync` | `:1116` | `book.chapterTitles?.indexOf` 改为在传入的 `rows` 上找 |
| `refreshToc` | `:1176` | 改 `async`，产出 `chapters` 行数组而非三个平行数组；`changed` 判断改为比对旧行的 `(url,title,start,end,isVolume)` |
| `refreshNoTocBook` | `:1260` | 同上 |
| `withCharset` | `:581` | 同上 |
| `replaceLocalChapter` | `:866` | 改 `async`，读旧行 → 重写正文 → 重算全部行的 `start`/`end` |
| `buildNoTocChapterLayout` | `:1136` | 保持返回 `{titles, offsets}`（字符偏移），由调用方转字节 |
| `estimateAndroidChapterPosition` | `:991` | 改 `async`；`readerPositionVersion === 2` 分支删掉，直接用 `androidCharacterPosition`（已折进 `durChapterPos`） |
| `restoreAndroidProgress` | `:1009` | 改 `async` |
| `createLocalBook` | `:1375` | 改为返回 `{ book, chapters }`，由 `saveImportedBooks` 落库 |
| `splitChapters` | `:1583` | 不动（纯函数，仍按字符偏移产出） |

新增：`getChapterList(bookUrl)`、`getChapterCount(bookUrl)`、`readProgress(book)`、`isBodyMissing(book)`、`byteRangeToCharRange(content, startByte, endByte)`、`charRangeToByteRange(content, startChar, endChar)`、`md5Encode16(value)`（照抄上游 `MD5Utils.md5Encode16`）、`wordCountFormat(words)`（照抄上游 `StringUtils.wordCountFormat`，严格 `> 10000` 才用万字）。

**D. `ReadRecordRepository`（669 行，22 处外部引用 / 3 文件）**

对外签名零改动。内部三层从「三个 preferences 键整表序列化」改为「三张表逐行读写」：

- `loadSessions` / `loadDetails` / `loadSummaries` → `SELECT * FROM readRecordSession / readRecordDetail / readRecord`，仍返回同样的数组、同样的排序。
- `saveSession` → `INSERT OR REPLACE INTO readRecordSession`，随后 `rebuildDetailsAndSummaries` 改为**一条 SQL 聚合**：`readRecordDetail` 用 `GROUP BY bookName, bookAuthor, date` 求 `SUM(readTime)`、`SUM(words)`、`MIN(NULLIF(firstReadTime,0))`、`MAX(lastReadTime)`；`readRecord` 用 `GROUP BY bookName, bookAuthor` 求 `SUM(readTime)`、`MAX(endTime)`。**跨午夜切段仍在内存里做**（`splitByDate`/`boundsOnDate` 保留），因为按本地时区切分要逐段算，SQL 表达不了。
- `clearAll` / `removeBook` → 三张表各自 `DELETE`（`removeBook` 按 `bookName AND bookAuthor`）。
- `scanIssues` / `repair` → `deleteDuplicateSessions` 的 SQL 照抄上游 `ReadRecordDao.kt`：`DELETE FROM readRecordSession WHERE id NOT IN (SELECT MIN(id) FROM readRecordSession GROUP BY bookName, bookAuthor, bookUrl, startTime, endTime, words)`。
- `migrateLegacy` 不动（读的是另一套 `legado_read_time_records`，与三张表无关）。
- `deviceId` 恒为空串 `''`；`ReadRecordSession.chapterIndex` 写进 `words` 列。

**E. 五张表 + 搬迁**

- `data/RdbSchema.ets`：`version` 2 → 3，追加 `books` / `chapters` / `readRecord` / `readRecordDetail` / `readRecordSession` 五条 DDL 与四条索引（`books` 两条、`chapters` 两条），DDL 逐字照抄 `132.json`。
- `data/RdbMigration.ets`：新增 `markerKeyV3 = 'rdb_migrated_v1_3'` 与 `migrateThirdBatch`。**顺序固定：先 `ReadRecordRepository` 三表，再 `BookRepository`（`books` 行 → `chapters` 行）**，一个事务一个标记，因为 `chapters` 行依赖 `books` 行。
- **外键 CASCADE 实测不生效**（设备探针：删书后章节仍剩 2 行）。DDL 仍照抄上游带 `ON DELETE CASCADE`，但删书必须在代码里手动删章节行：`BookRepository.discardImportedCopy`（`:122`）与 `pages/Index.ets:3138` 的删书流程各补一次 `DELETE FROM chapters WHERE bookUrl = ?`。

**F. 阶段 2 之外仍需一并处理的三处**

1. `data/BookGroupRepository.ets`：书架分组掩码读写依赖 `Book.groupNames`，字段保留，只确认 `withShelfMetadata` 的 13 字段拷贝同步删掉已删字段。
2. `pages/ProfileSubPages.ets:2570-2582` 的 `BookmarkBookSummary` interface 有 `coverColor`/`coverMark` 两个字段——**这是书签页自己的展示态 interface，不是 `Book`**，保留，只是构造时改调派生函数。
3. `entry/src/main/ets/pages/FileManagerPage.ets`、`ReaderBookmarkEditor.ets`、`ReaderMarkingEditor.ets`、`ReaderBookmarkTarget.ets`、`ReaderBookmarkImporter.ets`、`ReaderBookmarkExporter.ets`、`ReaderMarkingRepository.ets`、`ReaderSearchHistoryRepository.ets`、`ReplaceRuleRepository.ets` 里各有 1–12 处 `bookId` 引用——**这些是书签/划线/搜索历史自己的 `bookId` 字段，与 `Book.id` 无关**，不动。

## 存量搬迁流程（方案 a）

### 触发

首次启动时 `RdbMigration.runIfNeeded(context)`：

1. 打开 DB，执行建表 SQL，设 `version = 1`。
2. 读 `preferences` 里的标记键 `rdb_migrated_v1`（存搬迁完成时间戳）。
3. 标记不存在 → 执行搬迁；存在 → 跳过。

### 搬迁步骤

对每一批（按批次独立标记，`rdb_migrated_v1_1` / `_2` / `_3`）：

1. 用**现有仓储的 load 方法**读出老数据（复用 v1–v15 全部兼容分支）。
2. `beginTransaction()`。
3. 逐条 `insert`（`ConflictResolution.ON_CONFLICT_REPLACE`）。
4. 校验：`SELECT COUNT(*)` 与内存条数比对，不一致则 `rollBack()` 并抛错。
5. `commit()`。
6. 写标记键。

### 失败处理

- 任一步抛错 → `rollBack()`，**不写标记**，老 `preferences` 数据原样保留。
- 下次启动重新尝试（标记不存在）。
- 连续失败不阻塞应用启动：仓储读 DB 失败时记日志并返回空表（上游 DAO 读不到也是空表），界面不崩。

### 老数据清理（第 5 阶段）

搬迁本身**只复制不剪切**，老数据由单独的清理步骤在三批标记全部写齐之后统一删掉。

**上游依据**：上游 `SettingsRepository.kt:34-37` 用 `SharedPreferencesMigration(context, "${context.packageName}_preferences")`，其 `cleanUp()` 默认实现**删除源 SharedPreferences 文件**；只有 `LocalUiStatusMigration`（`SettingsRepository.kt:56`）显式写了 `override suspend fun cleanUp() = Unit` 才保留。所以「和上游保持一致」= 删掉已迁走的键，保留未迁的键。

**实现**（`entry/src/main/ets/data/RdbCleanup.ets`）：

- 标记键 `rdb_cleanup_v1_1`（preferenceName `legado_rdb_cleanup`），删完写标记，只删一次。**r290 起为 `rdb_cleanup_v1_2`**（r284 漏删两个键，升标记让已跑过的设备重跑一次，见本节末尾）。
- 前置检查：三个搬迁标记 `rdb_migrated_v1_1` / `v1_2` / `v1_3` 必须全部为真，否则直接返回，**不会误删未搬的数据**。
- 失败只吞异常（`console.error`），不写标记、不阻塞启动，下个版本重试。

删除清单：

| 处理方式 | preferences 文件 | 说明 |
| --- | --- | --- |
| 整文件删 | `legado_reader_bookmarks` | → `bookmarks` |
| 整文件删 | `legado_reader_markings` | → `book_marks` |
| 整文件删 | `legado_reader_search_history` | → `search_content_history` |
| 整文件删 | `legado_txt_toc_rules` | → `txtTocRules` |
| 整文件删 | `book_group_store` | → `book_groups` |
| 整文件删 | `legado_reader_highlight_rules` | → `highlightRules` |
| 整文件删 | `legado_book_content_processes` | → `book_content_processes` |
| 整文件删 | `legado_local_books` | → `books` + `chapters` |
| 整文件删 | `legado_read_time_records` | → `readRecordSession`（更老的扁平格式） |
| 按键删 | `legado_read_records` → 删 `sessions_v1`、`details_v1`、`summaries_v1` | 保留 `enabled`：上游 `ReadRecordRepository.kt:78-80` 也把它放偏好。`details_v1` / `summaries_v1` 是第三批之前的老格式按日明细与书籍汇总，第三批起改存 `readRecordDetail` / `readRecord`，代码里已无读取点 |
| 按键删 | `legado_replace_rules` → 删 `rules_v1`、`book_overrides_v1` | 保留 `default_enabled_v1`、`sort_mode_v1`：上游 `PreferKey.replaceEnableDefault` / `replaceSortMode` 都在偏好里 |

不删的：`legado_rdb_migration`（搬迁标记）、`legado_rdb_cleanup`（清理标记）、`legado_android_backup_options`（备份选项）、以及「不迁的部分」表里那 6 个仓储自己的偏好文件。

**已知遗漏（r284 遗留，r290 已修）**：r284 上线时 `RdbCleanup.ets` 实际只删了 `sessions_v1`，`details_v1` 与 `summaries_v1` 没有删，设备实测这两个键仍在。r290 修法两处同时做——删除清单补上这两个键（现在就是上表 `:474` 的样子），并把 `markerKey` 由 `rdb_cleanup_v1_1` 提到 `rdb_cleanup_v1_2`（标记已写的设备才会重跑）。详见 [VALIDATION.md](VALIDATION.md) 的「r290 修补」。

**连带改动**：

1. `ReadRecordRepository.migrateLegacy` 由「`pages/Index.ets` 首屏调用」改为 `RdbMigration.migrateThirdBatch` 内的 `migrateLegacyInto(context, store)`——否则清理先跑就会把这批老格式记录连根删掉。它现在不开事务、不写标记、不清老键，全部交给 RdbMigration 与 RdbCleanup。
2. `migrateThirdBatch` 内顺序固定为 `ReadRecordRepository.migrateFromPreferences` → `ReadRecordRepository.migrateLegacyInto` → `BookRepository.migrateFromPreferences`。**整表覆盖必须先于追加**：`BookRepository.migrateFromPreferences` 走的是整表重建，放后面会连带清掉前面的结果（实际影响是 books/chapters 与 readRecord 无关，但顺序写死以免将来改坏）。
3. 八个仓储的 `load()` 删除「DB 失败回退 preferences」分支，改为记日志 + 返回空表。`loadFromPreferences` / `loadLegacy` 方法本身保留，搬迁路径还要用。
4. `book_overrides_v1` 搬进 `books.readConfig.useReplaceRule`（上游存 `Book.config.useReplaceRule`，`Book.kt:482`）。`ReplaceRuleRepository.isBookEnabled(book)` 改为纯函数，照抄上游 `Book.getUseReplaceRule(defaultReplaceEnabled)`（`Book.kt:250-262`）：有显式值用它，没有则图片类与 epub 本地书返 false，其余跟随全局默认。写入口 `setBookEnabled` / `clearBookEnabledOverride` 只改内存对象，落库由调用方 `BookRepository.saveImportedBooks` 负责——`ReplaceRuleRepository` 不能 import `BookRepository`（后者已 import 前者，会循环）。

### 批次独立性

三批各自独立标记、独立搬迁。第二批搬迁时若第一批已完成，互不影响。第三批（章节拆表）单独一个标记，因为它要额外处理 `BookRepository` 的 15 个版本分支。

## 不迁的部分

| 仓储 | 理由 |
| --- | --- |
| `ReaderSettingsRepository` | 上游 `ReadBookConfig` 走 DataStore，同为键值对，`preferences` 已对齐 |
| `BookshelfLayoutRepository` | 上游书架布局设置也在 DataStore |
| `HomeDashboardSettingsRepository` | 同上 |
| `OnboardingRepository` | 本地独有，上游无对应 |
| `ReaderMoreActionsRepository` | 本地独有 |
| `EpubRepository` | 存的是解压后的 EPUB 资源文件，不是表 |
| `ReaderFontRepository` | 存的是字体文件 |
| `ReaderBookmarkBadgeRepository` | 存的是角标图片文件 |
| `ReaderBookmarkExporter` | 导出逻辑，不持有数据 |

## 风险与代价

### 手写 SQL 的出错面

Room 靠 KSP 在编译期校验「SQL 里的字段名与实体是否对得上」。`relationalStore` 没有这层，字段名写错只会在运行时报 `no such column`，且**只有走到那条查询才报**——可能上线很久才被发现。

缓解：建表 SQL 与查询 SQL 集中放在 `RdbSchema.ets`，查询统一走 `RdbCodec.ets` 的按列名取值，避免每处手写下标。第一批验收时把每张表的每一列都读一遍，确认列名无拼写错误。

### 中文排序

上游 `BookmarkDao` 用了 `collate localized`。SQLite 的 `COLLATE LOCALIZED` 在鸿蒙实现中是否支持中文拼音序，**未验证**。若不支持，书签/书籍按标题排序的中文顺序会与上游不同。

这是本计划唯一无法从文档确认的点，须在第一批实施时写一个最小验证：建一张表插「张」「李」「王」，`ORDER BY name COLLATE LOCALIZED` 看结果。若不支持，退回 `ORDER BY name` 并在 `KNOWN-ISSUES.md` 登记差异。

> **r281 实测结论（2026-10-30，已定案）**：relationalStore 的排序规则名是 **`LOCALES`**，不是 `LOCALIZED`。写 `COLLATE LOCALIZED` 报 `errno 25 no such collation sequence: LOCALIZED`，DDL 报 `code=14800021`；写 `COLLATE LOCALES` 且**先调用 `store.setLocale('zh')`** 才得到拼音序（默认 BINARY 得 `A|b|安|张|李|王|赵|陈`，设 locale 后得 `安|陈|李|王|张|赵|A|b`）。
> **必须 `setLocale` 是最危险的一点**：未设 locale 时 `COLLATE LOCALES` 不报错，而是静默返回空结果集——界面会显示「没有书签」，比报错更难排查。`setLocale` 是实例级设置，已写进 `data/RdbStore.ets` 的 `getStore()` 打开流程，每次开库后、任何查询前调用。
> 因此本计划的排序方案不变（仍按上游用语言排序），只是规则名与前置调用不同；不退回码点序，也无需登记 `KNOWN-ISSUES.md`。表 DDL 的列定义也带 `COLLATE LOCALES`，实测建表与建索引均接受。

### 主键语义变化

三张表的主键语义与本地不同，是搬迁的真实风险点：

| 表 | 本地主键 | 上游主键 | 风险 |
| --- | --- | --- | --- |
| `bookmarks` | `id`（string） | `time`（毫秒） | 同毫秒冲突 |
| `chapters` | 无（数组下标） | `(url, bookUrl)` | `url` 须合成 |
| `search_content_history` | `id`（string） | `id`（自增） | 本地 id 丢失 |

搬迁时须逐表检测冲突并消解，不能假定无冲突。

### 调用点回归

234 处外部引用分布在多个页面。仓储对外接口签名若变化（比如 `load(context)` 变成 `load()`），所有引用处都要改。

缓解：**对外接口签名保持不变**，只换内部实现。`load(context: Context)` 继续接受 `context`（内部忽略或用于取 RdbStore），返回值类型不变。这样 234 处外部引用零改动。这是把风险锁在 `data/` 目录内的关键。

### 构建与验收成本

三批 = 三次构建 + 三次设备验收。按历史经验，每次构建约 3–5 分钟，设备走查约 15–30 分钟。

## 实施顺序总表

| 阶段 | 内容 | 构建验收 |
| --- | --- | --- |
| 0 | 本计划文档 | — |
| 1 | 基础设施 + 第一批 3 个仓储 | ✅（已完成，r281） |
| 2 | 第二批 5 个仓储 | ✅（已完成，r282） |
| 3 | `ReadRecordRepository` | ✅（已完成，r283） |
| 4 | `BookRepository` + 章节拆表 | ✅（已完成，r283） |
| 5 | 清理 `preferences` 老数据 | ✅（已完成，r284） |

> 「构建验收」列的 ✅ 表示该阶段需要构建 + 设备验收；第 1–5 行已注明完成状态与轮次。第 5 行的清理逻辑与清单见「老数据清理（第 5 阶段）」节。

## 待验证清单

实施前须先跑通的最小验证，逐条记录结果：

1. `getRdbStore` 在模拟器与真机各能正常打开，库文件落在 `context.databaseDir`。
2. `CREATE TABLE` 带复合主键、UNIQUE 索引、外键 CASCADE 全部生效。
3. `COLLATE LOCALIZED` 中文排序是否可用。
4. `beginTransaction` / `rollBack` 在批量 insert 中途抛错时能正确回滚。
5. `querySql` 返回的 `ResultSet` 在 `rowCount` 为 0 时的行为。
6. `insert` 返回的 rowId 在 `AUTOINCREMENT` 表上的取值。
7. 库文件大小与 `preferences` 文本大小的对比（1000 本书的章节数据量）。

> **r281 第一批实测结果（2026-10-30，模拟器 API 26）**：① 模拟器可打开，库落在 `/data/app/el2/100/database/io.legado.harmony/entry/rdb/legado.db`，**真机仍未验**；② 复合主键（`chapters` 未建）、UNIQUE 索引（`search_content_history`）、自增主键全部生效，外键 CASCADE 随第二批验证；③ 见「中文排序」节的结论——规则名是 `LOCALES` 且须先 `setLocale('zh')`；④ 通过（`before=4 after=4`，中途抛错后数据完好）；⑤ 正常返回空结果集，`rowCount` 为 0，遍历零次；⑥ 返回自增 rowId，读出转 string 后与旧 `id` 语义一致；⑦ 三表 40960 字节，远小于原 preferences 文本（后者含 `v1\n` 头与逐字段 `encodeURIComponent` 冗余）。

> **r282 第二批补充（2026-10-30，模拟器 API 26）**：⑧ **外键 CASCADE 本批仍未验**——第二批五张表里没有任何外键（上游 `132.json` 也未定义），`chapters` 表尚未建，第 ② 条的外键部分要留到第三批。⑨ **REAL 列必须用 `getDouble`**：`highlightRules` 的 14 个 REAL 列（下划线宽/偏移、九宫格四边距、字距、行距等）若用 `getLong` 读，`0.1` 会被静默截成 `0`，界面表现为边距归零、下划线消失；`RdbCodec.real` / `optionalReal` 已固定走 `getDouble`。⑩ **`INSERT OR REPLACE` 是整行覆盖**，第二批五个仓储的 upsert 均按上游 `@Insert(onConflict = REPLACE)` 语义写全字段，不做部分更新。⑪ 8 张业务表在设备上的行数与 preferences 逐表比对一致（`replace_rules` 3、`txtTocRules` 27、`highlightRules` 9、`bookmarks` 3、`book_marks` 1，其余 0），两个迁移标记 `rdb_migrated_v1_1` / `rdb_migrated_v1_2` 均写入。
> **r283 第三批补充（2026-10-30，模拟器 API 26）**：⑫ **外键 `ON DELETE CASCADE` 在 relationalStore 上不生效**——前置验证时建 `books` / `chapters` 两表并插 2 行章节，删掉父行后章节行仍在（`left=2`），`PRAGMA foreign_keys` 即使打开也无效。因此**删书必须手动删章节行**：`BookRepository.deleteBook` 在同一事务里先 `DELETE FROM chapters WHERE bookUrl = ?` 再 `DELETE FROM books WHERE bookUrl = ?`，与上游 `DeleteBooksUseCase.kt:13-26` 的顺序一致（上游靠 Room 的外键，这里靠显式两条 SQL）。⑬ **`chapters.start` / `end` 是字节偏移，不是字符偏移**，且不能靠换算得到——实测 `第一章 相遇`（6 字符）占 16 字节、`今晚就出发。`（6 字符）占 18 字节、`😀`（2 字符）占 4 字节、ASCII 占 1 字节；中文 1 字 3 字节的假设只在纯中文段成立。搬迁时 `charOffsetsToByteOffsets` 逐字符累加，读取时按字节切片再解码（对应上游 `TextFile.kt` 的 `RandomAccessFile.seek`）。设备实测末尾 `end` 等于源文件字节数 21736，中文渲染无乱码。⑭ **`saveImportedBooks` 语义已由「整表重写」改为「纯 upsert」**（`INSERT OR REPLACE` 逐本写行），新增书目 / 改字段走它，删除走 `BookRepository.deleteBook`。这一改动把「书架整体覆盖」的原子性从「表级」降到「行级」：批量保存书目与保存章节现在是两个事务，中途失败可能出现「书目在、章节缺」的中间态，靠后续重算目录（`refreshToc` → `saveChapters`）自愈，与上游逐条 `@Update` / `@Insert` 的粒度一致。⑮ 五张新表在设备上的搬迁结果：`books` 1、`chapters` 6、`readRecordSession` 4、`readRecord` 1、`readRecordDetail` 1，三个标记 `rdb_migrated_v1_1` / `v1_2` / `v1_3` 全部写入；连续两次冷启动后 `v1_3` 不变，`legado_local_books` 与 `legado_read_records` 两个 preferences 文件的 mtime 停止更新——**存储对齐判据达成**。

## 与既有文档的关系

- 本计划不改动 `docs/parity/` 下任何对照表的内容——那些表盘的是「功能是否与上游对齐」，本计划盘的是「存储层是否与上游对齐」。**注意：这条被下面「与 parity 对照表的冲突」一节推翻了**，storage 迁移确实会让部分对照表条目作废。
- 迁移过程中若发现新的功能缺口，登记到 `docs/KNOWN-ISSUES.md`，不在本计划内展开。
- 每批完成后的验收结果写入 `docs/VALIDATION.md`。

## 与 parity 对照表的冲突（本节推翻上一节的「正交」说法）

上一节写「两者正交」，**这是错的**。`book_marks` 表的设计（见上文第 4 节）要把本地 7 个平铺列合并成 2 个 JSON 列：

| 本地现列 | 迁移后 | `ZIP-BOOKMARK.md` 中的引用次数 |
| --- | --- | --- |
| `chapterPosition` | 并入 `anchorJson` | 3 |
| `endPosition` | 并入 `anchorJson` | 1 |
| `selectedText` | 并入 `anchorJson` | 2 |
| `contextBefore` | 并入 `anchorJson` | 0 |
| `contextAfter` | 并入 `anchorJson` | 0 |
| `effect` | 并入 `styleJson` | 4 |
| `color` | 并入 `styleJson` | 2 |

**迁移一旦实施，书签对照表里描述这些字段的 12 处引用即告作废**，同时 `anchorJson`（现引用 2 次）、`styleJson`（现引用 4 次）的语义会变。两条流水线在同一张表上直接冲突。

**已定处置（2026-10-30）**：storage 迁移先做，parity 三张表**冻结**到迁移完成后重盘。理由：迁移有明确终点（7 条待验证清单 + 三批验收），是两条线里唯一可验收的；盘点没有终点，先做它等于先做那件不会结束的事。迁移做完字段结构就定了，那时盘一遍就是最后一版。

**后续（2026-10-30，r284）**：五个阶段全部完工，四份对照表已**解冻**——但只解除了「禁止编辑」，内容尚未重盘，`ZIP-BOOKMARK.md` 引用旧列名的 12 处现已知确定型但仍待更新。解冻声明见 `docs/parity/STATUS.md` 顶部。

## BackupRepository：迁移的耦合点

`BackupRepository.ets`（1943 行）不在 10 个待迁仓储内，也不在设置类或文件类里——它此前被漏在分类之外。它不持有自己的表，但它**直接读写待迁仓储**：

- 引用 10 个待迁仓储中的 7 个：`BookGroupRepository`、`BookRepository`、`ReaderBookmarkRepository`、`ReaderHighlightRuleRepository`、`ReaderMarkingRepository`、`ReplaceRuleRepository`、`TxtTocRuleRepository`
- 导出时读：`BookGroupRepository.load`、`ReaderHighlightRuleRepository.load`、`ReaderBookmarkRepository.load`、`ReaderMarkingRepository.load`（`:426`、`:494`、`:502-503`）
- **恢复时写**：`ReaderBookmarkRepository.save(context, pendingBookmarks)`（`:827`）、`ReaderMarkingRepository.save(context, pendingMarkings)`（`:830`）

**第一批迁移就要改 `ReaderBookmarkRepository`，而 `BackupRepository` 是它最大的外部消费者。** 这个耦合在计划原先的版本里没有出现。

**处置**：`BackupRepository` 不改（它不持有数据，只做搬运），但**每一批验收都必须走一遍完整的备份导出 / 导入**，并确认导入后书签与划线数据完整。理由：它坏起来是静默的——备份导入失败不会立刻报错，要等用户换机才发现。

## 完成判据：三合一

本计划引入第三条完成标准，与既有两条合并。**一个能力算完成，必须同时满足三项**：

1. **功能对齐**：`docs/parity/` 对照表中该能力的行全部为「已接」
2. **存储对齐**：该能力的数据落在本计划规定的表结构上，不再走 `preferences` 整表序列化
3. **验收记录**：构建通过 + 设备走查结果写入 `docs/VALIDATION.md`

任何一项缺失都算未完成。这条判据的作用是终结「盘完功能发现存储没对齐、盘完存储发现功能又变了」的循环——因为完成一个能力时，它的字段结构、页面行为、验收记录是同一时刻一起定下来的。

术语定义见 `docs/GLOSSARY.md` 的 **完成（三合一）**。
