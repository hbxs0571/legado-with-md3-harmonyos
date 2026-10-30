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
| 表 | 68 | 见 `@Entity(tableName = ...)` |
| DAO 接口 | 48 | `app/src/main/java/io/legado/app/data/dao/` |
| 数据库版本 | 133 | `AppDatabase.kt:139` |

注意 `BgmPoolEntities.kt`、`BookKnowledge.kt`、`ReadAloudSpeech.kt`、`VoicePoolEntities.kt` 各含多张表，所以表数（68）大于实体文件数（58）。

**上游并非全部数据都在 Room**：设置类走 DataStore Preferences（`help/config/AppConfigStore.kt:53`），与鸿蒙 `preferences` 同构，本地这块已经对齐，不迁。

## 本地现状

`entry/src/main/ets/data/` 共 30 个文件，分三类：

| 类别 | 数量 | 处理 |
| --- | --- | --- |
| 业务数据 | 10 个，4587 行 | **要迁** |
| 设置项 | 5 个 | 不迁（上游也是键值对） |
| 文件读写 | 4 个 | 不迁（存文件不存表） |

设置类：`ReaderSettingsRepository`（107 次 `store.put`）、`BookshelfLayoutRepository`（9 次）、`HomeDashboardSettingsRepository`（1 次）、`OnboardingRepository`（3 次）、`ReaderMoreActionsRepository`（1 次）。

文件类：`EpubRepository`、`ReaderFontRepository`、`ReaderBookmarkBadgeRepository`、`ReaderBookmarkExporter`。

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

调用点合计 35 处：`ReplaceRuleRepository` 7、`BookRepository` 6、`TxtTocRuleRepository` 5、`BookGroupRepository` 3、`ReadRecordRepository` 3、`BookContentProcessRepository` 3、`ReaderHighlightRuleRepository` 3、`ReaderBookmarkRepository` 2、`ReaderMarkingRepository` 2、`ReaderSearchHistoryRepository` 1。

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

项目目前**零处**使用 `relationalStore`，全部 16 个仓储都用 `preferences`。

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

### 第一批：小仓储 + 基础设施（246 行，3 个仓储，5 个调用点）

`ReaderBookmarkRepository`（72）、`ReaderMarkingRepository`（91）、`ReaderSearchHistoryRepository`（83）。

同时落地所有后续批次复用的基础设施：

1. `data/RdbStore.ets`：单例打开库（`getRdbStore`，`SecurityLevel.S2`，库名 `legado.db`），暴露 `getStore(): Promise<RdbStore>`。
2. `data/RdbSchema.ets`：建表 SQL 常量 + `CREATE TABLE IF NOT EXISTS` 执行器 + `RdbStore.version` 版本管理（本次 `version = 1`）。
3. `data/RdbMigration.ets`：存量搬迁骨架（见下节）。
4. `data/RdbCodec.ets`：结果集 → 模型的通用读取辅助（`getColumnIndex` + 类型转换），避免每个仓储重复写。

选这三个的理由：数据量最小、字段最简单（`bookmarks` 只有 9 列、`book_marks` 除两个 JSON 外都是平铺列）、调用点只有 5 处。第一批的目的是**验证整条链路**——建库、建表、读写、搬迁、冷启动读回——而不是解决业务问题。

验收：书签新增/编辑/删除/跳转、划线新增/编辑/删除/呈现、搜索历史记录/删除/清空，全部走 DB；强停冷启后数据仍在；`preferences` 老数据仍在（未删）。

### 第二批：中等仓储（2070 行，5 个仓储，21 个调用点）

`BookContentProcessRepository`（149）、`ReaderHighlightRuleRepository`（184）、`BookGroupRepository`（400）、`TxtTocRuleRepository`（568）、`ReplaceRuleRepository`（769）。

这批的共同点是**字段一一对应、无结构转换**，只是把「整表序列化成一个字符串」换成「逐行读写」。风险在于调用点密集（`ReplaceRuleRepository` 7 处、`TxtTocRuleRepository` 5 处），改接口签名会牵连多个页面。

验收：替换规则增删改查/分组/试跑/导入导出、TXT 目录规则增删改查/试跑、分组增删改/排序/私密、高亮规则增删改/排序、正文处理记录增删改/启用禁用。

### 第三批：大仓储 + 章节拆表（2271 行，2 个仓储，9 个调用点）

`ReadRecordRepository`（669）、`BookRepository`（1602）。

`ReadRecordRepository` 先做：三层结构（summary/detail/session）本地已拆好，只是换个存储，风险中等。

`BookRepository` 最后做，且是**唯一需要改数据模型**的一批：`chapterTitles`/`chapterOffsets`/`chapterVolumes` 三个平行数组要拆进 `chapters` 表。

影响面：`chapterTitles` 在全仓 9 个文件被引用——`BackupRepository.ets`、`BookRepository.ets`、`EpubRepository.ets`、`model/Book.ets`、`pages/BookInfoPage.ets`、`pages/CatalogPage.ets`、`pages/Index.ets`、`pages/ReaderPage.ets`、`pages/ReaderSearchPage.ets`。

**保留内存形态**：`Book` 模型里的三个数组字段**不删**，改成由 `BookRepository` 加载时从 `chapters` 表填充的只读投影。这样 9 个消费文件一行不用改，改动全部收敛在 `BookRepository` 内部。这是本批次最关键的决策——否则 1602 行的仓储要改成全仓 9 个页面联动改造。

验收：书架加载/排序/分组/搜索、书籍详情、目录页章节列表、阅读页翻章/进度恢复、TXT 与 EPUB 各一本完整走查、备份导出/导入、强停冷启。

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
- 连续失败不阻塞应用启动：搬迁失败时仓储回退到读 `preferences`，界面提示一次「数据迁移未完成」。

### 老数据不删

搬迁成功后**不删** `preferences` 里的老数据，保留至少一个大版本作为回滚保险。清理时机另议，不在本计划内。

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

### 主键语义变化

三张表的主键语义与本地不同，是搬迁的真实风险点：

| 表 | 本地主键 | 上游主键 | 风险 |
| --- | --- | --- | --- |
| `bookmarks` | `id`（string） | `time`（毫秒） | 同毫秒冲突 |
| `chapters` | 无（数组下标） | `(url, bookUrl)` | `url` 须合成 |
| `search_content_history` | `id`（string） | `id`（自增） | 本地 id 丢失 |

搬迁时须逐表检测冲突并消解，不能假定无冲突。

### 调用点回归

35 个调用点分布在多个页面。仓储对外接口签名若变化（比如 `load(context)` 变成 `load()`），所有调用点都要改。

缓解：**对外接口签名保持不变**，只换内部实现。`load(context: Context)` 继续接受 `context`（内部忽略或用于取 RdbStore），返回值类型不变。这样 35 个调用点零改动。这是把风险锁在 `data/` 目录内的关键。

### 构建与验收成本

三批 = 三次构建 + 三次设备验收。按历史经验，每次构建约 3–5 分钟，设备走查约 15–30 分钟。

## 实施顺序总表

| 阶段 | 内容 | 构建验收 |
| --- | --- | --- |
| 0 | 本计划文档 | — |
| 1 | 基础设施 + 第一批 3 个仓储 | ✅ |
| 2 | 第二批 5 个仓储 | ✅ |
| 3 | `ReadRecordRepository` | ✅ |
| 4 | `BookRepository` + 章节拆表 | ✅ |
| 5 | 清理 `preferences` 老数据（另议） | — |

## 待验证清单

实施前须先跑通的最小验证，逐条记录结果：

1. `getRdbStore` 在模拟器与真机各能正常打开，库文件落在 `context.databaseDir`。
2. `CREATE TABLE` 带复合主键、UNIQUE 索引、外键 CASCADE 全部生效。
3. `COLLATE LOCALIZED` 中文排序是否可用。
4. `beginTransaction` / `rollBack` 在批量 insert 中途抛错时能正确回滚。
5. `querySql` 返回的 `ResultSet` 在 `rowCount` 为 0 时的行为。
6. `insert` 返回的 rowId 在 `AUTOINCREMENT` 表上的取值。
7. 库文件大小与 `preferences` 文本大小的对比（1000 本书的章节数据量）。

## 与既有文档的关系

- 本计划不改动 `docs/parity/` 下任何对照表——那些表盘的是「功能是否与上游对齐」，本计划盘的是「存储层是否与上游对齐」，两者正交。
- 迁移过程中若发现新的功能缺口，登记到 `docs/KNOWN-ISSUES.md`，不在本计划内展开。
- 每批完成后的验收结果写入 `docs/VALIDATION.md`。
