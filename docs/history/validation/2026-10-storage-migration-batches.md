# 2026-10-storage-migration-batches

> 本文件是[验证记录](../../VALIDATION.md)的历史归档，关系型存储迁移第一批至第五批（r281–r284）。
> 内容原样搬运，未压缩、未改写设备实测数值（按《盘点规约》的沉淀约定）。
> 主文件只保留验证等级口径、设备操作规范与最近 8 轮记录；按功能分组找历史见主文件的索引表。

## 既有构建记录（历史，不表示本次重跑）

- DevEco Studio 26.0.0.851 / SDK 26；历史 `assembleHap` 构建成功。
- 历史模拟器记录不代表当前功能验收；任何 N 端 API 26 结果均不作为 E 端或 API 12 兼容证据。
- 配置的 compatible/target SDK 是 HarmonyOS `5.0.0(12)`。API 26 模拟器运行不能证明 API 12 真机兼容。
- 旧的全量工程内含未签名 HAP 构建产物，本仓库导出已排除所有构建输出。本次未将这些历史产物作为发布包。
- 以上设备记录来自原工程的历史工作；不代表 API 12 真机兼容，也不代表新功能全部回归。

## 2026-10-30 关系型存储迁移第五批 preferences 清理（设备验收部分完成）

- 构建：`assembleHap` 通过（`BUILD SUCCESSFUL in 31 s 260 ms`，33 项任务 17 执行 / 16 最新），无编译错误；WARN 全部是既有的「Function may throw exceptions」与弃用 API 提示。
- 设备：HOS 模拟器 `127.0.0.1:5555`（API 26），包名 `io.legado.harmony`。**清理与结构两项已设备确认，书签/划线两项未验**（原因见本节末尾），故本节整体不写「通过」。
- **范围**：`docs/RELATIONAL-STORE-MIGRATION.md` 第 5 阶段。搬迁此前只复制不剪切，老 `preferences` 全留；本批照上游 `SharedPreferencesMigration` 默认删源文件的语义把已迁走的键删掉。
- **上游依据**：上游 `SettingsRepository.kt:34-37` 用 `SharedPreferencesMigration(context, "${context.packageName}_preferences")`，其 `cleanUp()` 默认实现删掉源 SharedPreferences 文件；只有 `LocalUiStatusMigration`（`SettingsRepository.kt:56`）显式写 `override suspend fun cleanUp() = Unit` 才保留。本地此前「13 个键全留 + 8 处兜底读 preferences」对应的正是那个特例写法。
- **新增 `data/RdbCleanup.ets`**：标记键 `rdb_cleanup_v1_1`（preferenceName `legado_rdb_cleanup`），只删一次。**r290 修掉漏删后已提到 `rdb_cleanup_v1_2`**，见本节末尾「r290 修补」。前置检查要求三个搬迁标记 `rdb_migrated_v1_1` / `v1_2` / `v1_3` 全部为真，否则直接返回——**不会误删未搬的数据**。失败只 `console.error` 吞掉，不写标记、不阻塞启动，下个版本重试。
- **删除清单**：整文件删 9 个（`legado_reader_bookmarks`、`legado_reader_markings`、`legado_reader_search_history`、`legado_txt_toc_rules`、`book_group_store`、`legado_reader_highlight_rules`、`legado_book_content_processes`、`legado_local_books`、`legado_read_time_records`）；按键删 2 组（`legado_read_records` 删 `sessions_v1` 保留 `enabled`、`legado_replace_rules` 删 `rules_v1` 与 `book_overrides_v1` 保留 `default_enabled_v1` 与 `sort_mode_v1`）。保留下来的三项都有上游依据：`ReadRecordRepository.kt:78-80` 的 `readRecordEnabled`、`PreferKey.replaceEnableDefault`、`PreferKey.replaceSortMode` 在上游也都放偏好而非表。
- **连带改动一：老扁平记录搬迁挪位**。`ReadRecordRepository.migrateLegacy`（原先由 `pages/Index.ets` 的 `restoreReadTimeRecords` 在首屏调用）整体换成 `migrateLegacyInto(context, store)`，由 `RdbMigration.migrateThirdBatch` 调用。原因：清理会删掉 `legado_read_time_records`，搬迁必须排在清理之前。新版不开事务、不写标记、不清老键（这些原本也由 RdbMigration 与 RdbCleanup 统一管），并抽出 `rewriteDerived(store, sessions)` 供 `rebuildDetailsAndSummaries`、`migrateFromPreferences`、`migrateLegacyInto` 三处共用。
- **连带改动二：八个仓储删「回退 preferences」兜底**。`ReaderBookmarkRepository`、`ReaderMarkingRepository`、`ReaderSearchHistoryRepository`、`TxtTocRuleRepository`、`BookGroupRepository`、`ReaderHighlightRuleRepository`、`BookContentProcessRepository`、`BookRepository` 的 `load()` 在 DB 读失败时不再回读 preferences，改为记日志 + 返回空表/空数组。理由：上游 DAO 读不到就是空表，抛异常会让界面崩。`loadFromPreferences` / `loadLegacy` 方法本身保留，搬迁路径仍要读老数据。
- **连带改动三：`book_overrides_v1` 搬进 `books.readConfig.useReplaceRule`**（上游存 `Book.config.useReplaceRule`，`Book.kt:482`）。`Book` 模型加 `useReplaceRule?: boolean`，`StoredReadConfig` 加同名字段并在 `toBookArgs` / `readBookRow` 双向读写（`undefined` 被 `JSON.stringify` 丢掉，正好对应上游 `null` = 跟随默认）。`ReplaceRuleRepository.isBookEnabled(book)` 改为纯函数，照抄上游 `Book.getUseReplaceRule(defaultReplaceEnabled)`（`Book.kt:250-262`）：有显式值用它，没有则图片类与 epub 本地书返 false，其余跟随全局默认。`setBookEnabled` / `clearBookEnabledOverride` 去掉了 `context` 与 `async`，只改内存对象，落库交给 `BookRepository.saveImportedBooks` —— `ReplaceRuleRepository` 不能 import `BookRepository`（反向已存在，会循环依赖）。`pages/Index.ets` 两个入口同步改为「改对象 + 整表 upsert」，`resetReaderReplaceToDefault` 的取值由 `getDefaultEnabled()` 改为 `isBookEnabled(this.selectedBook)`，因为图片类与 epub 即使跟随默认也是关闭净化。
- **设备实测：清理生效**。启动后读取设备 preferences 目录，文件数由 16 降到 7，与删除清单完全吻合。9 个整文件删除全部生效（`legado_reader_bookmarks`、`legado_reader_markings`、`legado_reader_search_history`、`legado_txt_toc_rules`、`book_group_store`、`legado_reader_highlight_rules`、`legado_book_content_processes`、`legado_local_books`、`legado_read_time_records` 均已消失）；按键删除同样正确——改动替换规则排序方式后 `legado_replace_rules` 重新出现，但只带回 `sort_mode_v1`，`rules_v1` 与 `book_overrides_v1` 没有被写回。`legado_rdb_cleanup` 里已写入标记 `rdb_cleanup_v1_1`（值 `1793354547247`），`legado_rdb_migration` 的三个搬迁标记 `v1_1` / `v1_2` / `v1_3` 也都在。
- **设备实测：需要保留的键都留着**。留下的 7 个文件是 `legado_android_backup_options`、`legado_bookshelf_layout`、`legado_first_run`、`legado_rdb_cleanup`、`legado_rdb_migration`、`legado_read_records`、`legado_reader_settings`，与「不删的」清单一致。
- **设备实测：库结构完好**。`legado.db` 拉回本地用 Python 注册 `LOCALES` collation 后查得 14 张表全部建出：`books` 2 行、`chapters` 6 行（`url` 为 16 位 MD5，`start` / `end` 为字节偏移 `0→3628→7256→10852→14480→18108→21736`，`wordCount` 全为 `1211字`）、`readRecord` 1 行、`readRecordDetail` 1 行、`readRecordSession` 10 行，其余业务表为 0。`books.readConfig` 内容为 `{"reSegment":false,"fixedType":false}`，**没有 `useReplaceRule` 键**——两本书都没设过按书开关，符合「`undefined` 被 `JSON.stringify` 丢掉 = 跟随全局默认」的设计。
- **发现的写入遗漏**：`legado_read_records` 里仍留有 `details_v1` 与 `summaries_v1` 两个键（`RdbCleanup.ets:101` 只删了 `sessions_v1`）。这两个键存的是第三批之前的老格式按日明细与书籍汇总，第三批起已改存 `readRecordDetail` / `readRecord` 两表，全仓 `.ets` 已无任何读取点。**已于 r290 修掉**（见本节末尾）。
- **未验项**：① **书签与划线的写入未验**——`bookmarks` 与 `book_marks` 至今 0 行，无法确认这两张表在新代码下的写入路径；原因是模拟器上长按选词手势不可触发（详见下条），不是应用缺陷。② 按书净化开关「关掉一本书 → 冷启 → 仍关闭」的闭环未上机走。③ 老扁平记录改成搬迁阶段写入后，`readRecordSession` 是否与旧路径逐行一致未做新旧比对（本轮只读到 10 行，未与旧版 HAP 的数据对照）。④ 真机 `getRdbStore` 仍是第一批遗留未验项。
- **模拟器限制（影响走查手法，非应用缺陷）**：阅读页正文的长按选词在模拟器上不可触发。本轮唯一一次成功弹出选词菜单（复制 / 书签 / 划线·笔记）后，点「书签」也弹出了「添加书签」面板，但保存按钮点击落在面板外导致未入库；此后 12 次循环探测、5 个不同纵坐标、重启、双击、慢速拖拽、`uinput -T` 触摸轨迹、菜单开合状态下长按全部无法复现。`uitest uiInput longClick` 稳定返回 `No Error`，但**返回码不能当作手势被识别的证据**，必须 dump 层级或截图确认。这与第一批记录（`docs/VALIDATION.md` 的 r281 节）的结论一致：该页正文走滚动模式，长按划词在模拟器上一直不可靠。后续验书签/划线应改走「数据层直接构造 + 渲染像素比对」（r281 已用此法验证划线渲染），或改在真机上走 UI 闭环。
- 本记录只代表模拟器结果，不替代真机结论。

### r290 修补：补删两个残留键

批次验收时发现的写入遗漏已修掉，未做设备验收（纯删除清单变更，构建通过即可）。

- `entry/src/main/ets/data/RdbCleanup.ets` 的删除清单由 `['sessions_v1']` 改为 `['sessions_v1', 'details_v1', 'summaries_v1']`，并加注释说明后两个是第三批之前的老格式、代码里已无读取点。
- `markerKey` 由 `rdb_cleanup_v1_1` 提到 **`rdb_cleanup_v1_2`**。这一步不可省：v1_1 标记已经写在设备上，只改删除清单的话设备会直接跳过清理，那两个键永远留着。
- 构建：`assembleHap` 通过（`BUILD SUCCESSFUL in 8 s 809 ms`，33 项任务 17 执行 / 16 最新）。
- 预期效果：升级后首次启动应把 `legado_read_records` 里的 `details_v1` / `summaries_v1` 删掉，`enabled` 保留，`legado_rdb_cleanup` 的标记值改为新时间戳。**该项未上机复验**。

## 2026-10-30 关系型存储迁移第三批（通过）

- 设备：HOS 模拟器 `127.0.0.1:5555`（API 26），包名 `io.legado.harmony`。`assembleHap` 通过（`BUILD SUCCESSFUL in 26 s 511 ms`，33 项任务 17 执行 / 16 最新），HAP 覆盖安装成功。
- **范围**：`docs/RELATIONAL-STORE-MIGRATION.md:330` 的第三批两个仓储 `ReadRecordRepository`（669 行）、`BookRepository`（1602 行）由 preferences 整表序列化改为 relationalStore。`RdbSchema.version` 由 2 升到 3，追加五张表 DDL（`books` 35 列 PK `bookUrl`、`chapters` 18 列 PK `(url, bookUrl)`、`readRecord` 5 列、`readRecordDetail` 8 列、`readRecordSession` 8 列自增主键，逐列对齐上游 `132.json`）与 4 条索引（`books` 2 条、`chapters` 2 条）。`Book` 模型删除 8 个字段：`coverColor` / `coverMark`（改为 `bookCoverColor(book)` / `bookCoverMark(book)` 运行时派生）、`bodyMissing`（改 `BookRepository.isBodyMissing`）、`fileSizeBytes`、`readerPositionVersion`，以及 `chapterTitles` / `chapterOffsets` / `chapterVolumes`（章节彻底拆进 `chapters` 表）。
- **章节拆表后的同步访问器靠缓存**：上游用 Room，`BookChapterDao.getChapterList` 同步返回；relationalStore 只能异步读。为此 `BookRepository` 增加 `chapterCache`（`bookUrl → BookChapter[]`），`saveChapters` / `deleteChapters` / `loadChapters` 负责维护，页面侧改用 `cachedChapterTitles` / `cachedChapterOffsets` / `cachedChapterVolumes` / `cachedChapters` 四个同步访问器；`CatalogPage` / `ReaderSearchPage` / `ReaderPage` 各自在 `aboutToAppear` 里 `loadChapters` 预载一次。这是本批唯一一处「不等价于上游」的实现，其余全部照上游语义。
- **字节偏移必须实测，不能换算**：`chapters.start` / `end` 存**字节**偏移（上游 `TextFile.kt` 用 `RandomAccessFile.seek(start)`）。中文 1 字 3 字节、emoji 4 字节、ASCII 1 字节，任何乘除换算都会错。搬迁时 `buildLegacyChapterRows` 用 `charOffsetsToByteOffsets` 逐字符累加，读取时 `readChapter` 按字节切片再解码。设备实测 `chapters` 6 行的 `start` / `end` 为 0/3628、3628/7256、7256/10852、10852/14480、14480/18108、18108/21736，末值等于源文件字节数 21736，**核对通过**；正文渲染中文与 `Hello World，你好世界。` 均正常，说明切片的编码边界没有跨字符。
- **存量搬迁（第一轮，破坏性验证）**：先用 git worktree 构建的**旧版 HAP**（HEAD `d31920a`）卸载重装并造出真实数据（导入 `test-book.txt`、读若干段、产生 2 条阅读会话），再覆盖安装新版触发搬迁。搬迁后拉库比对：`books` 1 行（`type=264` 即 text 8 + local 256、`group=0`、`totalChapterNum=6`、`latestChapterTitle='第一章 出发'`、`readConfig='{"imageStyle":"DEFAULT","reSegment":false,"fixedType":false}'`、`origin='loc_book'`、`canUpdate=1`）、`chapters` 6 行、`readRecordSession` 4 行、`readRecord` 1 行、`readRecordDetail` 1 行。三个标记 `rdb_migrated_v1_1` / `v1_2` / `v1_3` 全部写入（`v1_3=1793349136731`）。实际会话数比 preferences 基线多 2 条，原因是老版本在卸载前又读了两段（时间戳 1793348880251 早于搬迁标记），属正确行为。
- **只搬会话，派生层重算**：`ReadRecordRepository.migrateFromPreferences` 只读 `sessions_v1`，`details_v1` / `summaries_v1` 不搬，改由 `computeDerived` 用同一份算法重算后再写两张派生表。`enabled` 开关留 preferences，与上游一致。
- **`saveImportedBooks` 语义变更**：第二批起改成纯 upsert（`INSERT OR REPLACE` 逐本写 `books` 行），不再整表重写。因此**删除必须显式删行**——`BookRepository.deleteBook` 在一个事务里先 `DELETE FROM chapters WHERE bookUrl = ?` 再 `DELETE FROM books WHERE bookUrl = ?`（**外键 `ON DELETE CASCADE` 在 relationalStore 上实测不生效**，前置验证阶段删书后章节行仍在、`left=2`，故必须手动删），末尾清 `chapterCache`。`Index.ets` 的 `removeLocalBookFromShelf` 先调 `deleteBook` 再 `saveImportedBooks`。
- **本轮修掉的缺陷**：`removeLocalBookFromShelf` 原先只调 `saveImportedBooks`（纯 upsert），从书架移除的书在 `books` / `chapters` 表里残留，重启后由 `loadBooksFromDb` 读全表又回弹。照上游 `DeleteBooksUseCase.kt:13-26`（先 `deleteChaptersByBook` 再 `deleteBooks`）补 `BookRepository.deleteBook`。设备实测：删前 `books=1 / chapters=6`，删后 `books=0 / chapters=0`，重启后书架仍为空不回弹；重新导入同一本书 `books=1 / chapters=6`，导入链路未受影响。
- **UI 走查（第二轮，全部通过）**：
  - **阅读记录**：汇总视图「1 本书 / 9 分钟」，按日「2026-10-30 / 9 分钟」，按书「test-book / 本地 TXT / 9 分钟」，与 DB 的 `readTime=568065` 毫秒（≈9.5 分钟）吻合。
  - **正文与目录**：打开书正文中文渲染正常；点目录按钮打开章节列表，点「第二章 相遇」正确跳转，页码与进度联动。
  - **删除书籍**：长按书架卡片进详情页 → 点「移出书架」→ 二次确认 → DB 两表归零。
  - **备份导出**：我的 → 设置 → 备份与恢复 → 备份 → 备份到本地，导出 `backup2026-10-30.zip`（2951 字节，落在 `/storage/media/100/local/files/Docs/Documents/`）。ZIP 内 10 个根条目，`bookshelf.json` 含 `totalChapterNum:6`、`durChapterIndex:2`、`durChapterPos`、`type:264` —— **导出读的是 `books` 表新字段，未回退 preferences**。
  - **备份恢复（实际执行，非仅预览）**：同页 → 恢复 → 从本地恢复 → 选中该 ZIP → 预览页显示「识别 10 个根条目；书架 1 本，其中本地书籍 1 本 / ZIP 不含 TXT/EPUB 正文」→ 点「导入此 ZIP」→ 显示「导入完成：保留 10 个 Android 条目；更新 0 本已有正文书目的进度，并创建 1 本缺正文书目」。书架上出现「缺正文」标记的占位书，进入详情页正确显示「已恢复书目与阅读位置，缺少正文文件」「Android 原路径：local-1793348394426.txt」并给出「移出缺正文…」「查看目录」「换源」「阅读记录」四个操作；DB 里该书 `bookUrl='local-1793348394426.txt'`（原始路径而非正文路径），`durChapterIndex=2`，`chapters` 表无它的行 —— 与「缺正文」语义一致。
- **冷启动幂等与停写 preferences（决定性验证）**：连续两次 `aa force-stop` + `aa start` 后 `rdb_migrated_v1_3` 的值不变（仍 1793349136731），不重复搬迁。`/data/app/el2/100/base/io.legado.harmony/haps/entry/preferences/` 下 `legado_local_books`（16:19）与 `legado_read_records`（16:30）的 mtime 停留在搬迁完成时刻，经过两次冷启动加一次备份导入后**均未再变化**，说明新版本确实不再写这两个 preferences 文件，**存储对齐判据达成**。
- **模拟器环境与操作坑（非应用缺陷，供后续参考）**：`uitest uiInput click X Y` 传物理像素，坐标须用 `uitest dumpLayout` 读 `attributes.bounds` 定位而非目测截图；`uitest uiInput keyEvent Back` 在页面内可能直接退出应用，改用点返回箭头；`snapshot_display` 两次截图 sha256 相同即表示点击未生效；文件选择器里点文件名会直接关闭选择器，须在预览面板出现后**向下滚动**才能看到「导入此 ZIP」按钮。
- **未验项**：① 真机上 `getRdbStore` 仍未验（第一批遗留，本批未变）；② 真机上的备份导出 / 导入未验（本轮全部为模拟器结果）。
- 本记录只代表模拟器结果，不替代真机结论。

## 2026-10-30 关系型存储迁移第二批（通过）

- 设备：HOS 模拟器 `127.0.0.1:5555`（API 26），包名 `io.legado.harmony`，书籍 `vol-test2`（本地 TXT，6 章）、`test-toc`。`assembleHap` 通过（`BUILD SUCCESSFUL in 30 s 13 ms`，33 项任务 17 执行 / 16 最新），HAP 覆盖安装成功。
- **范围**：`docs/RELATIONAL-STORE-MIGRATION.md:322` 的第二批五个仓储 `BookGroupRepository`、`ReaderHighlightRuleRepository`、`BookContentProcessRepository`、`TxtTocRuleRepository`、`ReplaceRuleRepository` 由 preferences 整表序列化改为 relationalStore。`RdbSchema.version` 由 1 升到 2，追加五张表 DDL（逐字照抄上游 `132.json`）与 6 条索引（`replace_rules.id`、`book_content_processes` 三条）。`RdbCodec` 新增 `real` / `optionalReal`。
- **REAL 列必须走 `getDouble`**：`highlightRules` 有 14 个 REAL 列（下划线宽/偏移、九宫格边距、字距、行距等），用 `getLong` 读会把 `0.1` 静默变成 `0`，界面表现为边距归零、下划线消失。设备实测前 5 条规则 `underlineWidth=1.0 underlineOffset=2.0 npLeft=0.1 npTop=0.1`，无退化。
- **存量搬迁**：`RdbMigration` 拆成两批，各一个事务、各一个标记（`rdb_migrated_v1_1` / `rdb_migrated_v1_2`）。第二批在 `migrateSecondBatch` 里依次调五个仓储的 `migrateFromPreferences`，失败 rollBack 且不写标记。设备上标记文件 `/data/app/el2/100/base/io.legado.harmony/haps/entry/preferences/legado_rdb_migration` 内容为两个 `<double>` 键，**两批都写入了**。搬迁后老 preferences 保留未删。
- **迁移前后行数逐表比对（全部一致）**：`bookmarks` 3、`book_marks` 1、`highlightRules` 9、`replace_rules` 3、`txtTocRules` 27、`book_groups` 0、`book_content_processes` 0、`search_content_history` 0。对照 preferences：`legado_replace_rules` 的 `rules_v1` 3 条（id=1 abc/order=0、id=2 测试规则/order=1、id=8001 E端恢复验证/order=2，group 全 `默认`）、`legado_txt_toc_rules` 的 `rules_v1` 27 条、`legado_reader_highlight_rules` 的 `rules_v1` 9 条、`book_group_store` 的 `android_groups_v1` 0 条。`replace_rules.sortOrder` 落成 0/1/2，说明搬迁时按数组下标重排生效。`groups_v1`（`["GrpXZ"]`）与 `sort_mode_v1`（`asc`）按设计留在 preferences：分组改为从规则派生后 `groups_v1` 已废弃不再读，`sort_mode_v1` 是设置项不随迁移回填。
- **UI 走查（截图证据在 `.tmp-dbcheck/`，未入库）**：

| 页面 | 结果 |
| --- | --- |
| 替换净化列表 | 页签为「全部」「默认」各一个；3 条规则齐全，启用状态开/关/开与 DB 的 `isEnabled` 1/0/1 一致 |
| 替换净化分组筛选 | 点「默认」后 3 条仍全显示，`groupContains` 的拆分包含判断正确 |
| 编辑替换面板 | 规则名称 abc、分组 默认、匹配规则 abc、替换为 XYZ、内容勾选、正则勾选、超时 3000，逐字段与 DB 一致 |
| 分组管理面板 | 自定义分组为空（3 条都属「默认」，上游同样过滤「默认」），符合预期 |
| 更多菜单 | 导入 / 导出 / 分组管理 / 选择模式 / 旧的在前 / 新的在前 / 名称升序 / 名称降序 |
| TXT 目录规则 | 27 条，顺序与 `serialNumber` 一致（目录(去空白)、目录、目录(匹配简介)、目录(古典、轻小说备用)…） |
| 所有书签 | 3 个分组：test-toc「1 个书签 · 0 个笔记」、vol-test2「1 个书签 · 1 个笔记」、vol-test2「1 个书签 · 0 个笔记」，与 `bookmarks` 3 行、`book_marks` 1 行吻合 |
| 书签/笔记双 tab | test-toc 书签 1 / 笔记 0，条目「第1章(1) · 章节」；vol-test2 书签 1 / 笔记 1，笔记条目「第二章 旧名 · 这一段是占位正文 · 歧义笔记」 |
| 划线渲染 | 阅读页第二章正文「今晚就出发。」「(像是忽然想起了什么)」「《百年孤独》」三处按 `highlightRules` 渲染出黄褐底色，9 条规则从 DB 读取后生效 |

- **本轮修掉的两个缺陷**：
  1. **替换净化页显示「暂无替换净化规则」**。根因是竞态：`EntryAbility.onCreate` 里的 `RdbMigration.runIfNeeded` 故意不 await，而 `Index.ets` 的 `aboutToAppear` 同时调 `restoreReplaceRules`，首次启动时表刚建好、搬迁还没写完，`load()` 读到 0 条；搬迁随后完成但界面不刷新。修法照上游时序：把 `runIfNeeded` 移到 `onWindowStageCreate`，`loadContent('pages/Index')` 排到搬迁之后（上游用 Room，建表与迁移在打开库时同步完成，本不存在这个中间态）。`catch` 兜住搬迁失败，仓储层读 DB 失败会自动回退 preferences，界面不会打不开。
  2. **页签出现两个「默认」**。根因是 `getGroups()` 先以 `['默认']` 打底、又从规则里收集到 `默认` 再 push，未去重。修法照上游 `ReplaceRuleDao.dealGroups`：只返回从规则拆出来的分组，不前置「默认」，由各界面自己拼（列表页拼「全部」、编辑页拼「默认」）。
- **三处分组语义按上游改写**：`addGroup` 从「维护分组清单」改为「把无分组规则批量归入该组」（`WHERE group IS NULL OR group = ''` 的 UPDATE）；`renameGroup` / `removeGroup` 用 `WHERE group LIKE '%' || ? || '%'` 捞候选、按 `,` 拆分改写（上游 `upGroup`/`delGroup` 只用逗号，不用 `[,;，；]`）；`getGroups()` 改从规则派生。据此删掉 `explicitGroups` / `persistGroups` / `parseGroups` / `groupsKey` / `persist`（整表 JSON 重写）。
- **`moveToTop`/`moveToBottom` 改上游 min/max 算术**：不再数组重排，而是 `targetOrder = 置顶 ? minOrder - 1 : maxOrder + 1`，其他规则的 order 不动。`sortMode` 默认值由 `'asc'` 改为 `'desc'`（与上游 `PreferKey.replaceSortMode` 默认一致）。
- **未验项**：① 真机上 `getRdbStore` 仍未验（第一批遗留，本批未变）；② 「编辑替换 → 改名 → 保存」这条路径在模拟器上没走通（输入框点击后未聚焦成功，改名未落库），`save` 的单行 upsert 逻辑与第一批已在别处验证过，但该面板的改名保存本身仍属未验。
- 本记录只代表模拟器结果，不替代真机结论。

## 2026-10-30 关系型存储迁移第一批（通过）

- 设备：HOS 模拟器 `127.0.0.1:5555`（API 26），包名 `io.legado.harmony`，书籍 `vol-test2`（本地 TXT，6 章）。`assembleHap` 通过，HAP 覆盖安装成功。
- **范围**：`docs/RELATIONAL-STORE-MIGRATION.md:307` 的第一批三个仓储 `ReaderBookmarkRepository`、`ReaderMarkingRepository`、`ReaderSearchHistoryRepository` 由 preferences 整表序列化改为 relationalStore；同时落地 `data/RdbStore.ets`、`data/RdbSchema.ets`、`data/RdbMigration.ets`、`data/RdbCodec.ets`。
- **建表**：库 `legado.db`（`SecurityLevel.S2`），落在 `/data/app/el2/100/database/io.legado.harmony/entry/rdb/`。`bookmarks`（主键 `time`，索引 `(bookName, bookAuthor)`）、`book_marks`（主键 `id`，索引 `(bookUrl, chapterIndex)`）、`search_content_history`（自增主键 `id`，唯一索引 `(bookName, bookAuthor, query)`）三表按上游实体建出，`RdbStore.version` 置 1。
- **COLLATE LOCALIZED 验证（开工前置，结论与上游写法不同）**：relationalStore 的排序规则名是 **`LOCALES`**，不是 SQLite 文档与上游 Room 写的 `LOCALIZED`——写 `COLLATE LOCALIZED` 报 `errno 25 no such collation sequence`（DDL 报 `code=14800021`）。且必须**先 `store.setLocale('zh')`**，否则 `COLLATE LOCALES` 不报错但静默返回空结果集（界面会显示「没有书签」，比报错更危险）。实测拼音序：默认 BINARY 得 `A|b|安|张|李|王|赵|陈`，设 locale 后 `COLLATE LOCALES` 得 `安|陈|李|王|张|赵|A|b`。`setLocale` 是实例级设置，已写进 `RdbStore.getStore()` 的打开流程。**因此不退回码点序，也无需登记排序差异。**
- **存量搬迁**：`EntryAbility.onCreate` 调 `RdbMigration.runIfNeeded`（故意不 await，不阻塞启动）。标记键 `rdb_migrated_v1_1`，事务包裹「读老 preferences → 逐条 insert → 计数校验 → commit」，失败 rollBack 且不写标记。搬迁成功后老 preferences 保留未删。冷启动复查三表数据完好。
- **待验证清单 7 条（`RELATIONAL-STORE-MIGRATION.md:440`）**：① getRdbStore 在模拟器可打开、库落在 `context.databaseDir` ✔；② 复合主键 / UNIQUE 索引 / 自增主键全部生效 ✔；③ 中文排序见上条 ✔；④ `beginTransaction` + 中途抛错 + `rollBack` 后数据完好（before=4 after=4）✔；⑤ `querySql` 在 rowCount 为 0 时正常返回空集 ✔；⑥ `insert` 在 AUTOINCREMENT 表上返回自增 rowId，读出后转 string 与旧 `id` 语义一致 ✔；⑦ 库文件 40960 字节，远小于 preferences 文本 ✔。真机一项仍未验。
- **结构转换（book_marks 是唯一需要转换的表）**：`anchorJson` 由 `chapterIndex/chapterPosition/selectedText/contextBefore/contextAfter/normalizedTextHash` 合成，结构与上游 `TextProcessAnchor` 一致（实测 `{"chapterIndex":2,"chapterPosition":500,"selectedText":"这一段是占位正文","contextBefore":"","contextAfter":"","normalizedTextHash":"fd185bd2f87259a89f35b8fd002a3d4a"}`）；`styleJson` 由 `effect/color` 合成，highlight 映射到 `{"underlineMode":7,"underlineColor":-13312}`。7 种效果 `solid/dashed/wave/strike/highlight/background/text` 经「写库 → 读回」完整往返。`endPosition` 不落库，由 `chapterPosition + selectedText.length` 推导（500 + 8 = 508 已核）。
- **double 效果删除**：`ReaderMarkingEffect` 去掉 `'double'`，`ReaderMarkingEditor.ets` 效果列表同步为 7 项、`effectFromUnderlineMode` 删掉 `mode === 4` 分支、`ReaderPage.ets` 删掉 `TextDecorationStyle.DOUBLE` 分支。老数据里的 double 在搬迁时按 solid 收下（`ReaderMarkingRepository.loadFromPreferences` 白名单外降级），`ReaderBookmarkExporter.ets:257` 的 double 判断**保留**以兼容读老备份。
- **书签界面走查**：「我的」→「书签」→ 分组 → 条目 → 编辑面板改备注并保存，DB 内容随之更新；点删除 → 二次确认 → DB 行数减少、列表实时刷新。增删改全部落到 DB。
- **搜索历史界面走查**：搜索页输入关键词后**必须回车**才写库（`ReaderSearchPage.ets:309-310`，`.onChange` 只搜索、`.onSubmit` 才调 `saveQuery`），回车后 DB 出现对应行；「清除搜索历史」后该表归零且不影响 `bookmarks`。
- **划线渲染界面走查（决定性验证）**：先确认 highlight 以半透明背景渲染（`#44` + 颜色，`getMarkingBackground`）。为排除「读到的是 preferences fallback」这一可能，把 DB 里 `book_marks.styleJson` 的 `underlineColor` 由 `-13312`（#FFCC00）改成 `-65536`（#FF0000）回写设备，重启后正文同一位置的高亮**由黄变红**（黄色像素 12136 → 红色像素 10577，裁剪图确认是「间的距离，使得每」8 个字），再改回 #FFCC00。→ 渲染确实取自 DB。
- **两处已知差异（按既定决策保留，不修）**：
  1. **书签分组可能被拆开**：`bookmarks` 表无 `bookId` 列（与上游一致），仓储层从 `bookUrl` 末段去 `.txt` 反推 `bookId`，而 `pages/Index.ets:1621-1643` 的 `getBookmarkBookSummaries()` 按 `bookId` 归并。当书签的 `bookUrl` 不是本地书路径（换源、网络书，如 `https://other-source.example/x.txt`）时反推出的 `bookId` 与原值不同，同一本书的书签会被分成两组。上游 `Bookmark.kt` 注释明确 `bookUrl` 是「创建时的源指纹」，书签仍按书名+作者关联，故属预期行为。
  2. **搜索历史按书名+作者归属**：表无 `bookId` 列，`clear(context, bookName, bookAuthor, onlyThisBook)` 与 `visibleHistory()` 均改按书名+作者匹配。`ReaderSearchHistoryRepository.clear` 签名由 `(context, bookId, onlyThisBook)` 改为四参，全项目仅 `ReaderSearchPage.ets:116` 一处调用。这是「表结构对齐上游」的直接代价，计划中「外部引用零改动」在此处不成立。
- **模拟器环境限制（影响走查手法，非应用缺陷）**：该页正文走滚动模式（`ReaderPageTextJoined`），点击左右区域翻页不生效；`uitest uiInput longClick` 与同点长时 swipe 都无法触发长按划词，故划线走查改用「滚动定位 + 像素统计」完成。另：设备自带 `sqlite3` 无法读带 `COLLATE LOCALES` 的表（`no such collation sequence: LOCALES`），排查 DB 须把 `legado.db` 与 `legado.db-wal` 一起拉到本地，用 Python 注册同名 collation 后再查。
- 本记录只代表模拟器结果，不替代真机结论；`docs/RELATIONAL-STORE-MIGRATION.md:440` 的「真机各能打开」一项仍为未验。

## 当前快照状态

- bundleName：`io.legado.harmony`；versionName：`0.1.0`；versionCode：`1000000`。
- `signingConfigs` 未配置；仓库不含签名材料。
- 模块配置未声明 INTERNET 权限；源码没有应用网络客户端/请求代码的初步检索记录。若新版本加入在线服务，须重新审核权限与隐私说明。
- UI 与导航中，阅读器整页及逐项视觉验收未完成；五个阅读相关路由仍为实现中，10 月 26 日增量有模拟器记录但需要继续验收。
- 资源当前 133 SVG / 4 PNG。路径比对报告为 50 个 SVG 与 Android drawable 精确一致；39 个 SVG 有 AndroidX Material / Apache-2.0 来源记录；此前待核的 10 个 SVG 已完成来源映射，其中 2 个箭头是 GPL-3.0 近似 UI 映射，详见 RESOURCE-LICENSES.md。

## 2026-10-28 r245/r243 源码同步后公开副本 clean 构建

- 使用 DevEco Studio 26.0.0.851 附带的 Hvigor 入口，在同步后的公开副本先执行 Entry clean，再执行 `assembleHap`；33 项任务中 32 项执行、1 项为最新，`BUILD SUCCESSFUL`。
- ArkTS 编译有既有异常处理、弃用 API 与剪贴板授权警告；本次未出现编译错误。Hvigor 提示 `No signingConfig found for product default`。
- 构建产生的 HAP 仅作本地编译验证，受 Git 忽略，未作为安装包提交或发行。构建成功不代表 API 12 真机兼容或上述 E 端未验项已通过。
