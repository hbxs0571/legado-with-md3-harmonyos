# ZIP 兼容总账

> **本目录已解冻（2026-10-30，r284），三张表已完成结构性重盘（r286）**
>
> `STATUS.md`、`BOOKSHELF.md`、`ZIP-BOOKMARK.md`、`READER-CONFIG.md` 四份对照表可编辑。
>
> **解冻依据**：关系型存储迁移计划（原 `docs/RELATIONAL-STORE-MIGRATION.md`，r281–r284 五个阶段全部完工并已归档至 `docs/history/`，不随公开仓库发布）的基础设施与前三批仓储 r281–r283、preferences 清理 r284 均已落地，字段结构已定稿。原先的冲突——`book_marks` 的 7 个平铺列（`chapterPosition`、`endPosition`、`selectedText`、`contextBefore`、`contextAfter`、`effect`、`color`）要被合并成 `anchorJson` 与 `styleJson`——已经落地。
>
> **重盘范围与边界（r286，2026-10-30）**：三张表做的是**结构性重盘**，不是逐行重核。已做四件事：
>
> 1. **盘点单位改为「整个界面」**：只要涉及某界面就把它完整列进表，未迁移的显式标 `未接`。`ZIP-BOOKMARK.md` 因此新增 F 块（长按选词菜单 34 行），`BOOKSHELF.md` 因此新增 D 块（缓存管理页 + 书架管理页 53 行）。
> 2. **修正迁移后失效的字段引用**：`progress` 改派生、`readerPositionVersion` / `androidCharacterPosition` / `bookId` / `endPosition` 已删、`styleJson` 不再拍平、`double` 已删除、`preferences` → SQLite 两张表。
> 3. **三张表各补「覆盖证明」节**，逐个分配上游接触面文件，未分配为 0：`bookmark` 63/63、`readConfig` 76/76、`localBook` 27/27、`bookGroup` 40/40、`readRecord` 63/63、`bookshelfLayout` 10/10。（r294 补上类别键名字面量后复算：`bookmark` 64/64、`readConfig` 78/78、`localBook` 28/28、`bookGroup` 41/41、`readRecord` 64/64、`bookshelfLayout` 10/10，仍全部为 0 未分配。r296 再给 `localBook` 补 `BookRestorePlan`/`LocalBookLocationStatus`/`isRelocatedCopyOf`/`normalizeLocalBookLocation` 四个词把 `BookRestorePlanner.kt` 纳入接触面，复算为 `localBook` 29/29；同时把界面白名单改为按类别门控。r297 给 `readConfig` 分五轮补关键词 `ReadMenuConfig`/`menuConfig`/`ReadPreferences`/`ReadBookStyleConfig`/`ReadSheetConfigUiState`/`expandTextMenu`/`showSelectMenuIcon`/`lastMarkingStyle`，接触面 78 → 105，再按精确文件名点名 2 个无配置引用的渲染端，复算为 `readConfig` **107/107**，增量清单见 [READER-CONFIG.md](READER-CONFIG.md) 的「接触面是怎么从 78 涨到 107 的」节。**r327 换掉 `bookshelfLayout` 的旧三关键词：旧词 `bookshelfLayout|BookshelfLayout|"bookshelfLayout"` 命中 10 个，但漏掉 `ui/main/bookshelf/BookItem.kt`（1090 行，卡片主渲染器）、`BookshelfViewModel.kt`（1436 行）、`BookshelfUiState.kt`（186 行）；换成 38 项字段前缀名后接触面 10 → 24，复算 `bookshelfLayout` **24/24**，见 [书架布局总账](ZIP-BOOKSHELF-LAYOUT.md)。**）
> 4. **`KEYWORDS.md` 的 `readConfig` 关键词修正**：`backupIgnoreReadConfig` 只命中 2 个文件（等于自证成功），改为 `ReadBookConfig|ReadSettings`（76 个）。（r294 又补上键名字面量 `"readConfig"`，复算为 78/78，见 `KEYWORDS.md` 的「存储层维度」一节。r297 补到 11 个词后为 105 个，逐词增量与漏检形态见 `KEYWORDS.md` 的「`readConfig` 行的关键词」节。）
>
> **未做的部分，读表时注意**：`BOOKSHELF.md` A1–C 的 263 行、`READER-CONFIG.md` A–G 的 189 行、`ZIP-BOOKMARK.md` A–E 的 83 行，都是 r277–r280 写下的**迁移前证据，未逐行复核**。表头已逐份写明这一边界。要当当前事实用，需按上游目录分派逐块重核——那时按 `scripts/upstream-surface.sh --coverage` 的未分配清单验收，不靠「表里没有 `待定`」结案。（r297 已对 `READER-CONFIG.md` 做完这一步：189 行逐块重核，97 条 `未接` 逐行登记进 `KNOWN-ISSUES.md`；r300–r316 逐批落地后现为 176 已接 / 11 `未接` / 2 不适用；其余两份表仍待重核。）
>
> 解冻不影响 `KEYWORDS.md`（检索词表）——它是生成接触面清单的依据，改关键词等于改口径，改前先看该文件末尾的说明。

本表按 ZIP 数据类别记录 Android 备份兼容度，共 28 类，键名与[备份恢复](../BACKUP-RESTORE.md)的忽略项一致，检索词见[对照关键词](KEYWORDS.md)。

类别是兼容度的计量单位：做完一类就是前进一格，可以数得清。术语见[术语表](../GLOSSARY.md)的 **ZIP 类别**、**上游接触面**、**盘点**、**覆盖证明**。盘点方法与验收等级见[盘点规约](../PARITY-RULES.md)。

## 兼容度三级

三级都过才算这一类兼容。

1. **读**：上游写出的 ZIP 条目能被本地恢复，数据落到原生仓储（不是只原样归档）。
2. **写**：本地能写出同条目，上游读回不报错、数据不丢字段。
3. **忽略项**：上游该类的 `dbIsNotIgnored` 开关在本地有对应语义，至少在恢复时能跳过。

## 取值

| 记号 | 含义 |
| --- | --- |
| `✓` | 该类**有具名映射链路**，数据落原生功能；不表示该类全部键/字段都接了，键级明细看 [Android ZIP 备份兼容](../BACKUP-RESTORE.md) 的 28 类清单 |
| `✗` | 该类**完全没有映射**，ZIP 条目仅由 `copyPreservedEntries` 原样归档，不进原生功能 |
| `—` | 不适用，理由必写（`docs/PARITY-RULES.md` 第三节四类依据之一：上游无此行为、平台无此能力、[项目队列](../PROJECT.md)的范围之外、数据层无独立界面） |
| `?` | 未盘，尚未逐个文件核对（本表总账 2026-11-09 起不再用它作单元格值，改按下节判据逐类落文字） |

### 忽略项列的等价判据（2026-11-09 逐类核对）

「忽略项」列判的不是「读写通不通」，而是「上游该类的忽略开关在本地有没有对应语义」。上游与本地名字像、机制不同，逐类判据如下：

- **上游是「全局永不备份 X」**：`BackupConfig.kt:129`–`:132` 的 `dbIsNotIgnored(key, isBackup)` 读 `backupDbIgnoreConfig`（备份侧）/ `dbIgnoreConfig`（恢复侧）两份**独立、默认都空**的持久 JSON，`return config[key] != true`；用户在备份配置页勾一次，此后每次备份/恢复都跳过该类。`dbIgnoreKeys`（`:96`–`:102`）19 个、`backupIgnoreKeys`（`:171`–`:181`）9 个是这两类开关的键全集。另 `keyIsNotIgnore`（`:417`–`:424`）写 config.xml 时做**逐键**门控：`alwaysIgnoredPreferenceKeys` 逐键排除、按 `readPrefKeys`/`themePrefKeys`/`coverPrefKeys`/`bookshelfPrefKeys`/`mangaPrefKeys` 分组门控，以及 `themeMode`/`showRss`/`threadCount` 三个单键开关。
- **本地是「这次备份不勾 X」**：`BackupRepository.ets` 的 `ignoredCategories` 来自本次备份/恢复的勾选、不持久；`isIgnored`（定义 `:2694`；旧文先记 `:1539`、后记 `:2264`，均已漂）对 `bookshelf.json`/`config.xml` 恒 `false`，其余按 `categoryOptions.files` 反查类别键名再查 `ignored.includes(key)`；config.xml 派生类别由 `filterAndroidConfigXml` 按 `preferenceKeysForCategory(key)` **整组剔键**，用户不能只勾「忽略某一个键」。
- **等价点**：两者都能让「某一类不出现在备份包里」，恢复时也都能跳过该类的 ZIP 条目 —— 在「用户能不能让某一类不出现在包里」这一点上等价。
- **不等价点**：① 作用域：上游全局持久、单次配置长期生效；本地每次备份重新勾选、不持久。② 粒度：上游有键级门控（含 `alwaysIgnoredPreferenceKeys` 逐键），本地 `filterAndroidConfigXml` 只能按类别整组剔键。故 config.xml 派生的 8 类记「类别级等价，键级不等价」，括号里列出该类别 `preferenceKeysByCategory` 登记的键数 —— 这些键本地只能整类开关，不能逐键。
- **三档取值**：`等价（类别级）` = 本地有该类的 `categoryOptions` 开关且恢复时 `isIgnored` 能跳过对应独立 JSON 文件；`类别级等价，键级不等价（N 键）` = 类别开关有、但上游可逐键而本地只能整组剔 N 个键；`未接` = `categoryOptions` 虽登记了类别键名，但该类读写两侧都走 `copyPreservedEntries`、没有原生仓储可落，勾了忽略也只是不进保留目录，语义上无从等价（G2 五类原属此档，批 3 接通后已回填为 `等价（类别级）`，见下方「批 3」节）。忽略项列只判门控语义，**与读/写列是否接通无关** —— 读写 `✗` 的类只要门控能跳过条目，忽略项仍可判等价。`—`/`✓` 为既有判定，不属本次 20 个 `?` 的范围。

**本表是骨架，不是盘点结论。** 状态依据来自 2026-10-30（r287）对 `entry/src/main/ets/data/BackupRepository.ets` 的代码核实：恢复侧具名分支当时只有 8 个 `entry.name ===` 判断（`bookshelf.json`、`config.xml`、`bookGroup.json`、`replaceRule.json`、`txtTocRule.json`、`highlightRule.json`、`bookmark.json`、`bookMarking.json`），对应 7 个类别；其余全部走 `copyPreservedEntries` 原样归档。**2026-11-09 复核：现为 21 处判断、19 个条目名**（清单与行号见下方「恢复侧具名分支实测」一节，本节不再重复维护计数）。

批 1 把原先 4 个 `?`（`themeMode`、`showRss`、`threadCount`、`mangaConfig`）落定为 `✗`：当时 `config.xml` 写出侧只 upsert 三段（`bookshelfLayout` 9 键、`readConfig` 阅读外观、`themeConfig` 护眼 6 键），读入侧 46 键，这 4 类的键既不在写出列表也不在读入列表。**「读」列的 `✗` 表示该类的 ZIP 条目恢复时不进原生功能，但条目本身仍会被原样归档**——归档不等于支持。批 2（2026-11-09）复核后 `showRss` 已补写出与恢复链路、读写列改 `✓`（见下方「批 2」节），`threadCount`／`mangaConfig` 因无数据源判未接，`themeMode` 的代码链路确认存在但该行状态列属既有判定、本批未动。

逐类的「本地有无原生页面」需要另看 [Android ZIP 备份兼容](../BACKUP-RESTORE.md) 的 28 类清单，那里有样本条数与本地页面状态；本表只管 ZIP 读写通不通。

## 总账

| 类别键名 | 条目 | 读 | 写 | 忽略项 | 涉及行 |
| --- | --- | --- | --- | --- | --- |
| `localBook` | `bookshelf.json` | ✓ | ✓ | — | [书籍总账](BOOKSHELF.md) A1 29 / B 51 / C 4 / D3 13 / E 1 = **98 行**（72 条 `未接` 已在 [已知问题](../KNOWN-ISSUES.md#本地书籍行登记bookshelfmd-的-localbook-未接行) 逐条登记） |
| `bookmark` | `bookmark.json`、`bookMarking.json` | ✓ | ✓ | 等价（类别级） | [书签对照](ZIP-BOOKMARK.md) A–E = **83 行** |
| `bookGroup` | `bookGroup.json` | ✓ | ✓ | 等价（类别级） | [书籍总账](BOOKSHELF.md) A3 18 / A1 11 / D3 6 / B 3 = **38 行** |
| `bookSource` | `bookSource.json` | ✗ | ✗ | 未接 | [书籍总账](BOOKSHELF.md) B 19 / D3 5 = **24 行** |
| `rssSource` | `rssSources.json` | ✗ | ✗ | 未接 | **零行** |
| `rssStar` | `rssStar.json` | ✗ | ✗ | 未接 | **零行** |
| `replaceRule` | `replaceRule.json` | ✓ | ✓ | 等价（类别级） | [TXT 阅读总账](TXT-READER.md) = **6 行**（`:104`、`:105`、`:106`、`:381`、`:382`、`:383`）；`grep -c replaceRule` 实测 7，多的 1 行是 `:965` 的「ZIP 类别取值」表头说明同时列了两词，非数据行 |
| `readRecord` | `readRecord.json`、`readRecordDetail.json`、`readRecordSession.json` | ✓ | ✓ | 等价（类别级） | [书籍总账](BOOKSHELF.md) **28 行**（`ZIP 类别` 列精确等于 `readRecord` 的 28 行，实跑：**27 已接 / 1 不适用**；不适用为 C 块 `:391` 总览·日历日详情（上游 `CalendarDayCell` 无点击））。读写链路：恢复 `entry/src/main/ets/data/BackupRepository.ets:1449`/`:1450` 具名解析三份 JSON，末尾 `:1487`-`:1490` 交 `ReadRecordRepository.restoreFromBackup`（定义 `data/ReadRecordRepository.ets:1069`，事务内合并）；写出 `:805`/`:807`/`:818` |
| `searchHistory` | `searchHistory.json` | — | — | — | 批 4 按任务 4.1 推荐判 **不适用**：上游 `Backup.kt:180`–`:181` / `Restore.kt:213`–`:216` 的 `searchHistory.json` 装 `SearchKeyword`（全局搜索关键词池，表 `search_keywords`），本地无此入口、无此表、无 `SearchKeyword` 实体；本地 `search_content_history` 对齐上游 `SearchContentHistory`，而该表在上游 `Backup.kt` / `Restore.kt` 零命中、根本不备份。故这一类别在本地没有可落地的读写对象，不新建 `search_keywords` 表与全局搜索关键词池功能；`searchHistory.json` 仍只由 `copyPreservedEntries` 原样归档。详见下方「批 4」节 |
| `sourceSub` | `sourceSub.json` | ✗ | ✗ | 未接 | **零行** |
| `txtTocRule` | `txtTocRule.json` | ✓ | ✓ | 等价（类别级） | [TXT 阅读总账](TXT-READER.md) = **5 行**（`:84`、`:85`、`:86`、`:93`、`:95`）；`grep -c txtTocRule` 实测 6，多的 1 行是 `:965` 的「ZIP 类别取值」表头说明同时列了两词，非数据行 |
| `httpTTS` | `httpTTS.json`、`httpTtsVoices.json` | ✓ | ✓ | 等价（类别级） | 源 + 音色双向（批 1 建表、批 2 仓储、批 3 备份桥）：写出 `BackupRepository.ets:1015`/`:1019`，恢复 `:1295` → `HttpTtsRepository.importSources`，随后同目录 `httpTtsVoices.json` → `ReadAloudVoiceRepository.replaceHttpVoices`（坏 JSON 只计 skipped、不清库）。界面明细仍**零行**未盘 |
| `keyboardAssists` | `keyboardAssists.json` | — | — | — | 批 3 判 **不适用**：上游 `ui/` 零命中、`keyboardAssistsDao.` 仅 `Backup.kt:196` / `Restore.kt:253` 两处消费（DAO 8 方法多数零引用），本地 `grep -rn keyboardAssists entry/src/main/ets --include=*.ets` 仅 2 行白名单 / `categoryOptions`、无仓储无界面；依据 [盘点规约](../PARITY-RULES.md) 第三节「代码里有但从未接线 / 数据层无独立界面」，[书籍总账](BOOKSHELF.md) E `:516` 已同样判不适用。详见下方「批 3」节，不假接空表 |
| `dictRule` | `dictRule.json` | ✓ | ✓ | 等价（类别级） | 批 3 接通：建表 `RdbSchema.ets:354`、写出 `BackupRepository.ets:749`、恢复具名分支 `:1277`、`RestoreResult` 计数 `:140`；真包往返见下方「批 3」节（明细表仍**零行**未盘，读写以本节代码与往返证据为准） |
| `homepageModules` | `homepageModules.json` | ✓ | ✓ | 等价（类别级） | 批 3 接通：建表 `RdbSchema.ets:364`（16 列、7 个可空 TEXT）、写出 `BackupRepository.ets:758`、恢复具名分支 `:1340`、`RestoreResult` 计数 `:144`；真包往返见下方「批 3」节（明细表仍**零行**未盘） |
| `homepageCustomSets` | `homepageCustomSets.json` | ✓ | ✓ | 等价（类别级） | 批 3 接通：建表 `RdbSchema.ets:385`、写出 `BackupRepository.ets:767`、恢复具名分支 `:1358`、`RestoreResult` 计数 `:148`；真包往返见下方「批 3」节（明细表仍**零行**未盘） |
| `highlightRule` | `highlightRule.json` | ✓ | ✓ | 等价（类别级） | **零行** |
| `highlightTagRule` | `highlightTagRule.json` | ✓ | ✓ | 等价（类别级） | 批 3 接通：建表 `RdbSchema.ets:393`、写出 `BackupRepository.ets:776`、恢复具名分支 `:1376`、`RestoreResult` 计数 `:152`；真包往返见下方「批 3」节（原 [书籍总账](BOOKSHELF.md) B = **1 行** 仍是界面盘点，读写以本节代码与往返证据为准） |
| `tagGroupRule` | `tagGroupRule.json` | ✓ | ✓ | 等价（类别级） | 批 3 接通：建表 `RdbSchema.ets:403`、写出 `BackupRepository.ets:785`、恢复具名分支 `:1394`、`RestoreResult` 计数 `:156`；真包往返见下方「批 3」节（原 [书籍总账](BOOKSHELF.md) A3 = **4 行** 仍是界面盘点，读写以本节代码与往返证据为准） |
| `server` | `servers.json` | ✗ | ✗ | 未接 | **零行** |
| `readConfig` | `readConfig.json`、`shareReadConfig.json`、`config.xml` | ✓ | ✓ | 类别级等价，键级不等价（60 键） | [阅读配置总账](READER-CONFIG.md) A–G = **189 行**（176 已接 / 11 `未接` / 2 不适用）；11 条 `未接` 已在 [已知问题](../KNOWN-ISSUES.md#阅读配置行登记reader-configmd-的未接行) 逐条登记；另 [书籍总账](BOOKSHELF.md) A2 1 / D4 1 |
| `themeConfig` | `themeConfig.json`、`config.xml` | ✓ | ✓ | 类别级等价，键级不等价（53 键） | [深色模式总账](ZIP-THEME.md) A 46 / B 12 / D 1 / E 7 / F 6 = **72 行**（已接 64 / `未接` 6 / 不适用 2）。r300–r316 十七批的逐批落地过程与每行改判理由见 [深色模式总账](ZIP-THEME.md) 的「盘面」节，本节只记结果。剩余 6 行均已判「不接」（A3 Miuix 动态取色、A7 主题引擎切换、A18 平板界面、A19 多窗布局、E7 提醒 intent 链路、A23 作者搜索回退），判「不接」不删行不改状态，仍按 `未接` 计。另 [阅读配置总账](READER-CONFIG.md) F = **7 行**（护眼字段，阅读设置页那一套） |
| `coverConfig` | `coverRule.json`、`config.xml` | ✓ | ✓ | 类别级等价，键级不等价（14 键） | [封面设置总账](ZIP-COVER.md) A 18 / B 15 / C 9 / D 18 / E 6 = **66 行**（58 已接 / 6 `未接` / 2 不适用，r330 建表、r334 实现段收口、C8 于 2026-11-09 改判 `已接`；接触面 83 个 `.kt` 全部已分配）。6 条 `未接` 已在 [已知问题](../KNOWN-ISSUES.md#封面配置行登记zip-covermd-的未接行) 按 KI-COVER1..9 逐行登记。旧关键词 `backupIgnoreCoverConfig\|"coverConfig"` 只命中 3 个文件，本轮换成 14 词组合式后接触面 3 → 83，该类别此前记「零行」正是自证成功的结果 |
| `themeMode` | `config.xml` | ✓ | ✓ | 类别级等价，键级不等价（1 键） | [深色模式总账](ZIP-THEME.md) A 1 / C 5 / D 7 / F 6 = **19 行**（17 已接 / 1 `未接` / 1 不适用，A8 的图标切换按 `themeConfig` 类计不适用；D4 主题列表页的日夜切换按钮 2026-11-09 由 `不适用` 改判 `未接`，本地无主题列表页；A1/C4/D2/F1/F2/F3/F10 已接，r300 落地；D7 已接，r302 落地；F9、F11 已接，r303 落地；C1 向导第 4 页深色模式点选即写全局并立刻换肤、C2 向导调色板选择落盘 `paletteIndex` 已接，r305 落地；D3 三值派生布尔、D8 阅读菜单日夜配色 r306 复查改判已接）；另 A2/A4 的界面也受 `themeMode` 影响，主类别记在 `themeConfig` |
| `bookshelfLayout` | `config.xml` | ✓ | ✓ | 类别级等价，键级不等价（39 键） | [书架布局总账](ZIP-BOOKSHELF-LAYOUT.md) A 47 / B 26 / C 14 / D 12 / E 14 / F 9 = **122 行**（76 已接 / 43 `未接` / 3 不适用，r327 建表、r331/r332 落地 38 行；接触面 24 个 `.kt` 全部已分配）。43 条 `未接` 按 `**要接**`（2）/ `**不接**`（41）逐行登记进 [KNOWN-ISSUES](../KNOWN-ISSUES.md) 的「书架布局行登记」。BOOKSHELF.md 的 A2 33 / A1 20 里与本表重叠的行，以本表为准 |
| `showRss` | `config.xml` | ✓ | ✓ | 类别级等价，键级不等价（1 键） | 批 2 接通：写出 `BackupRepository.ets:991`–`:996` 按运行时 `ThemeSettingsRepository.load`（`:992`）真值 upsert `showRss` 布尔键（`:994`–`:995`），恢复 `restoreShowRss` 定义 `:571`（读键 `:576`）经 `RestoreResult.showRss`（`:113`）落 `Index.ets:5360` 起的 `ThemeSettingsRepository.save`；真包往返见下方「批 2」节（备份 `grep -c showRss` = 1、恢复后 `legado_theme` 的 `showRss` 由 true 变 false、底部 RSS tab 由 5 变 4）。明细表仍**零行**未盘，读写以本节代码与往返证据为准 |
| `threadCount` | `config.xml` | ✗ | ✗ | 类别级等价，键级不等价（1 键） | [书籍总账](BOOKSHELF.md) A2 = **1 行**；批 2 判**未接**：`grep -rn threadCount entry/src/main/ets --include=*.ets` 除 `BackupRepository.ets` 键分组表外零命中，本地无并发消费方（上游默认 16 用于书源检测／换源／导入并发），按硬约束不硬造默认值、整条跳过 |
| `mangaConfig` | `config.xml` | ✗ | ✗ | 类别级等价，键级不等价（32 键） | **零行**；批 2 判**未接**：`grep -rn mangaConfig entry/src/main/ets --include=*.ets` 除 `BackupRepository.ets` 键分组表外零命中，本地无漫画功能与 32 键消费方，按硬约束不硬造 32 个假值、整条跳过 |

## 状态依据

### 已核实的具名分支（21 处判断、19 个条目名）

`entry/src/main/ets/data/BackupRepository.ets` 的恢复主循环里，`entry.name` 具名分支实测 **21 处判断、19 个条目名**（2026-11-09 HEAD 版，`BackupRepository.ets` 3106 行、与工作区一致）：

| 行 | 条目 | 落地方式 |
| --- | --- | --- |
| `:1192` | `bookshelf.json` | `mergeAndroidBookshelf` 合并后落 `android-backup-entries/`，再经 `restoreMatchingLocalProgress` 更新本地书籍进度 |
| `:1211` | `config.xml` | `filterAndroidConfigXml` 按忽略项剔键后归档，键值经 `restoreReaderSettings`、`restoreBookshelfLayout`、`restoreShowRss`、`restoreThemeMode` 落到各仓储 |
| `:1222` | `bookGroup.json` | `BookGroupRepository.importAndroidFile` |
| `:1232` | `replaceRule.json` | `ReplaceRuleImporter.parse` → `ReplaceRuleRepository.importRules` |
| `:1249` | `txtTocRule.json` | `TxtTocRuleImporter` → `TxtTocRuleRepository` |
| `:1263` | `highlightRule.json` | `ReaderHighlightRuleRepository`（合并语义，见[备份恢复](../BACKUP-RESTORE.md)） |
| `:1277` | `dictRule.json` | `DictRuleImporter.parse` → `DictRuleRepository.importRules` |
| `:1295` | `httpTTS.json` | `HttpTtsImporter.parseSources` → `HttpTtsRepository.importSources`；随后同目录 `httpTtsVoices.json` → `ReadAloudVoiceRepository.replaceHttpVoices` |
| `:1340` | `homepageModules.json` | `HomepageModuleImporter.parse` → `HomepageModuleRepository.importRules` |
| `:1358` | `homepageCustomSets.json` | `HomepageCustomSetImporter.parse` → `HomepageCustomSetRepository.importRules` |
| `:1376` | `highlightTagRule.json` | `HighlightTagRuleImporter.parse` → `HighlightTagRuleRepository.importRules` |
| `:1394` | `tagGroupRule.json` | `TagGroupRuleImporter.parse` → `TagGroupRuleRepository.importRules` |
| `:1412`/`:1424` | `bookmark.json`、`bookMarking.json` | 两份共用一个 outcome，`ReaderBookmarkImporter.mergeBookmarks` / `mergeMarkings` 合并完再统一落盘 |
| `:1435` | `themeConfig.json`（常量 `THEME_CONFIG_FILE_NAME`） | `parseThemeConfigs` → `saveThemeConfigs` 整份覆盖，恢复后另补 `upThemeConfig` 装载 |
| `:1449`/`:1450` | `readRecord.json`、`readRecordDetail.json`、`readRecordSession.json` | 三份先收进 pending，末尾 `:1487`-`:1490` 交 `ReadRecordRepository.restoreFromBackup` 事务内合并 |
| `:1468` | `coverRule.json` | `parseCoverRule` 补齐 9 字段 → `CoverRuleRepository.save` |

其余条目走主循环末尾 `:1482`–`:1483` 的兜底 `fileIo.copyFile` + `preservedEntryCount += 1`，只进保留目录，不落原生仓储。因此 `readRecord` 原判 `✗`，不是「没查」，而是「当时查过、确认未接」；2026-11-09 恢复侧补齐具名分支（`:1449`/`:1450` 收三份 JSON，`:1487`-`:1490` 交 `ReadRecordRepository.restoreFromBackup` 事务内合并），读写两列随之改判 `✓`；`searchHistory` 批 4 复核后改判 `—`（上游 `searchHistory.json` 装的是本地没有的 `SearchKeyword` 全局关键词池，本地 `search_content_history` 对应的 `SearchContentHistory` 上游本就不备份，见下方「批 4」节），已不属于「确认未接」一组；`keyboardAssists` 批 3 复核为 `—`（上游仅存储无界面）。`dictRule`、`homepageModules`、`homepageCustomSets`、`highlightTagRule`、`tagGroupRule` 原也在此清单里，批 3 已为它们补出 5 张新表、5 套仓储／导入器与恢复侧具名分支并接通写出侧，读写两列改判 `✓`（见下方「批 3」节），不再走兜底。（`coverConfig` 原先也在这条清单里，r334 实现段已把 14 个封面键双向接通、66 行里 57 行已接，因此它现在是「部分接入」，不再属于「确认未接」一组。）。

### 原判 `—`、现改判 `✗` 的五类（2026-11-09 范围调整；`httpTTS` 已接通，见下）

`bookSource`、`rssSource`、`rssStar`、`sourceSub`、`httpTTS`、`server` 六类此前判 `—`，依据是[项目队列](../PROJECT.md)的「范围之外」。**2026-11-09 起，在线书源抓取、RSS 拉取、TTS 服务、WebDAV 已移出「范围之外」**，改列入 `PROJECT.md` 的「在线服务（已纳入范围，尚未排期）」一节，因此六类都不再具备判 `—` 的依据，按 `docs/PARITY-RULES.md` 第三节「一条依据都写不出，就不能判不适用——降级为未接」降级为 `✗`。其中 **`httpTTS` 随后已在批 1–3 接通数据层读写**（写出 `BackupRepository.ets:1015`/`:1019`，恢复 `:1295` → `HttpTtsRepository.importSources` + `ReadAloudVoiceRepository.replaceHttpVoices`），两列已改判 `✓`，故本节只覆盖剩下五类：

- **读 / 写**：两侧都 `✗`，条目只经 `copyPreservedEntries` 原样归档，本地没有对应原生仓储可落。
- **忽略项**：判 `未接`。`categoryOptions` 里虽然登记了这五类的类别键名（勾选后确实能把条目挡在保留目录之外），但该类没有原生功能可落，门控「跳过的是什么」无从等价——按上节「三档取值」的口径，这类只能记 `未接`，等读写接通后回填。
- **涉及行**：`bookSource` 在 [书籍总账](BOOKSHELF.md) B 19 / D3 5 = 24 行；其余四类仍零行（`rssSource`、`rssStar`、`sourceSub`、`server`）。**零行不等于不做**：这五类的界面块要等排期后按 `docs/PARITY-RULES.md` 的盘点单位（整个界面）重新建块，届时行数会从 0 涨起来。
- **`httpTTS` 已不在此列**：批 1–3 之前它只写 `httpTtsVoices.json` 的空数组 `[]`（`!accessSync` 才写，避免覆盖透传的真音色），那只是占位；批 1–3 补出源与音色两个方向的真实解析与仓储写入后，两列已改判 `✓`，不再是「归档保留」。

**归档保留不等于功能兼容**：这五类的条目仍会随备份往返，但本地既不解析也不应用，恢复后用户看不到任何效果。

### 判 `?` 的四类与 `themeConfig` 写的复核

`themeMode`、`showRss`、`threadCount`、`mangaConfig` 只有 `preferenceKeysByCategory` 的键分组，没有独立的恢复分支，实际效果取决于 `config.xml` 的整体搬运路径。逐键复核结果：**`themeMode` 与 `showRss` 已在批 2 接通**——`themeMode` 写出 `entry/src/main/ets/data/BackupRepository.ets:983`-`:987`（`normalizeThemeModeForBackup` 定义 `:539`，归一到上游字符串三值 `"0"/"1"/"2"`）、恢复 `restoreThemeMode` 定义 `:552`（读键 `:558`）、回传 `:1554`；`showRss` 写出 `:991`-`:996`、恢复 `restoreShowRss` 定义 `:571`（读键 `:576`）、回传 `:1555`；两行状态列均已改 `✓ | ✓`。**`threadCount`、`mangaConfig` 仍是 `✗`**：本地既无写出也无读回，且无消费方（详见 [备份恢复](../BACKUP-RESTORE.md) 的两行说明）。

`themeConfig` 的「写」列 2026-11-09 复核为**已实现**，总账表由 `✗` 改 `✓`：当前工作区的 `createBackup` 在 config.xml 段之后有 `!ignoredCategories.includes('themeConfig')` 门控分支（`entry/src/main/ets/data/BackupRepository.ets:1004`，实测 `grep -n buildCurrentThemeConfigs`），内调 `buildCurrentThemeConfigs(paletteIndex, customTheme)` → `themeConfigsToJson` → `writeTextFile` 写出 `themeConfig.json`；恢复侧 `:1435`-`:1443` 有 `if (entry.name === THEME_CONFIG_FILE_NAME)` 具名分支走 `parseThemeConfigs` + `saveThemeConfigs`，恢复后另补 `upThemeConfig` 装载。[深色模式总账](ZIP-THEME.md) F5 原记「应补写出、当前判未接」，是补写前的判断段，现已被上述代码落地覆盖，结论以本节与总账表为准。

`bookshelfLayout` 的「读」列 2026-11-09 复核为**已恢复**，总账表由 `✗` 改 `✓`：当前工作区 `:1529`–`:1532` 在恢复主循环之后调用 `BackupRepository.restoreBookshelfLayout(selection.stagingDirectory, currentBookshelfLayout, ignoredCategories)` 并 `await BookshelfLayoutRepository.save(context, bookshelfLayout)`，函数定义在 `:1779`，数据落 `BookshelfLayoutRepository` 原生仓储，符合本表「读」的定义。

`replaceRule` / `txtTocRule` 的「涉及行」原记「零行」，实测 [TXT 阅读总账](TXT-READER.md) 各有 6 / 5 行数据行，出处行号已回填总账表。`grep -c` 实测 7 / 6，各比数据行多 1，多出的是 `:965` 的「ZIP 类别取值」表头说明行同时列举了这两个词、不是数据行；`grep -c highlightRule docs/parity/TXT-READER.md` 实测 `0`，只有 `highlightRule` 是真「零行」。

行号口径说明：任务文案里更早出现过的 `:858`–`:862` / `:1123` / `:1187`–`:1190` 与「HEAD 2676 行、工作区 2806 行」都已是历史值。实测 2026-11-09（httpTTS 四批全部进 HEAD 之后）：`entry/src/main/ets/data/BackupRepository.ets` **HEAD 与工作区一致，均为 3106 行、`git diff --numstat` 为空**。**本表行号一律按该文件实测填写**，不存在需自行换算的差量。

### 批 2（2026-11-09）G1 六类读写补齐的结论

任务批 2 只做 G1 六类，结论由代码事实与真包往返决定，状态列不随主观意愿改：

- **`themeConfig` / `bookshelfLayout`**：批 1 已按事实 A 把写 / 读列由 `✗` 改 `✓`，本批只确认、不改。**行号已按 2026-11-09 现状重核**：`themeConfig` 写出 `BackupRepository.ets:1004`–`:1005`（门控 `:1002`）、恢复 `:1435`–`:1444`；`bookshelfLayout` 写出 `:682`–`:721`、恢复 `restoreBookshelfLayout` 定义 `:1779`、调用 `:1529`–`:1532`。
- **`themeMode`**：任务批 2 第 2 点要求「确认即可」。代码写出 `:983`–`:987`（`!ignoredCategories.includes('themeMode')` 门控）与恢复 `restoreThemeMode` 定义 `:552`（→ `RestoreResult.themeMode` `:111` → `Index.ets:5360` 起的 `applyThemeMode`）链路确实存在；该行读写列在后续轮次已改判 `✓`，本批遗留待核项**已收口**。
- **`showRss`**：本批唯一补齐的写出侧真活。写出 `:991`–`:996` 照 `themeMode` 范式补 `boolean` 键 `showRss`（`:994`–`:995` 的 upsert），真值取 `ThemeSettingsRepository.load(context).showRss`（`:992`，运行时设置、非写死默认值）；恢复侧新增 `restoreShowRss`（定义 `:571`，`readXmlBoolean` 读键 `:576`），`RestoreResult` 加 `showRss: boolean | undefined`（`:113`），`Index.ets:5360` 起先刷 `@State themeShowRss` 再经 `saveThemeSettings` 整份落盘，避免 `applyThemeMode` 触发的整份写用旧内存值盖回。总账表读写列 `✗` → `✓`。
- **`threadCount` / `mangaConfig`**：`grep -rn -E "threadCount|mangaConfig" entry/src/main/ets --include=*.ets` 排除 `BackupRepository.ets` 后零命中，本地既无并发／漫画消费方也无真值来源。按硬约束「不许硬造默认值」整条跳过、不写任何 `config.xml` 键，判**未接**；备份包 `config.xml` 实测 `grep -c threadCount` = 0、`manga` 相关键 0。读写列保持 `✗`。

真包往返（`showRss`，设备 `127.0.0.1:5555`，HAP 构建 `BUILD SUCCESSFUL` / 0 ERROR 后 `bm install`）：备份 `backup2026-11-09.zip` → `unzip -l` 含 `config.xml`（6153 bytes）、`unzip -p config.xml | grep -c showRss` = **1**、键为 `<boolean name="showRss" value="true" />`；造 `showRss=false` 对照包 `b2_restore_false.zip` 推到设备走「从本地恢复」→「导入此 ZIP」，恢复后 `legado_theme` 的 `showRss` 由 `true` 变 `false`，主界面底部导航由 5 个 tab 变 4 个（RSS 入口消失）。完整原始命令行输出见证据包 `N:\HarmonyProjects\tmp\zip-ledger-io-evidence.md` 第五节。注意 `scripts/build-hap.sh` 直接 `exec hvigorw`，构建尾部**没有**任务文案写的 `COMPILE RESULT: SUCCESSFUL`／`ERROR 0` 字样，实测等价事实为 `BUILD SUCCESSFUL in 53 s 188 ms`、`ArkTS:WARN` 545 行、`error:`/`ERROR`/`BUILD FAILED` 0 行。

### 批 3（2026-11-09）G2 五类新开表 + 读写桥的结论

任务批 3 标题写「七类新开表」、正文写「剩下 6 类」，但 3.2 节点名的模型文件只有 5 个（`DictRule.ets`、`HomepageModule.ets`、`HomepageCustomSet.ets`、`HighlightTagRule.ets`、`TagGroupRule.ets`），`SearchKeyword` 明说归批 4，且上游 `Backup.kt` 可写的 G2 JSON 也正好 5 个（`dictRule.json`、`homepageModules.json`、`homepageCustomSets.json`、`highlightTagRule.json`、`tagGroupRule.json`）。另 `keyboardAssists` 按本节末复核判 `不适用`。**故批 3 实际接通 5 类**，数量口径差异如实登记。

- **建表**：`entry/src/main/ets/data/RdbSchema.ets:17` `static readonly version: number = 4;`（批 3 时为 4，httpTTS 批 1 又抬到 **5**，现文件实测为 `version: number = 5;`）；`:354`–`:413` 追加 5 段 `static readonly createXxx`、`:486`–`:494` 追加进 `allStatements`。列名逐字对齐上游 Room 实体（`app/src/main/java/io/legado/app/data/entities/` 下 5 个 `.kt`），让 Gson 写出的 JSON 能直接互认；`order` 是 SQL 关键字、列名加反引号；7 个可空 TEXT 列不带 NOT NULL。设备侧 `sqlite3 ...legado.db '.tables'` 实测 5 张表建成、`.schema` 与建表语句一致。
- **模型 / 导入器 / 仓储**：5 个 `entry/src/main/ets/model/*Rule.ets`（CRLF）、5 个 `entry/src/main/ets/data/*Importer.ets`（CRLF，照 `TxtTocRuleImporter.ets`，单条坏不连累整批）、5 个 `entry/src/main/ets/data/*Repository.ets`（LF，照 `ReaderHighlightRuleRepository.ets`，`INSERT OR REPLACE` + 事务 + `RdbCodec`）。`HomepageModule` 的 7 个可空字符串列读写走 `RdbCodec.optionalText()`，不把 `null` 变 `''`。
- **写出侧**：`BackupRepository.ets:744`–`:788` 按类别门控补 5 段（`writeTextFile` 实际落在 `:749`/`:758`/`:767`/`:776`/`:785`），照上游 `Backup.kt:359` `writeListToJson` 的「list 非空才建文件」语义，空表不写、不覆盖上次透传件 —— 与现有 `replaceRule` 的「始终写空数组」不同，差异如实登记。
- **恢复侧**：`:1277`–`:1394` 补 5 个 `entry.name ===` 具名分支，照 `replaceRule` 形态，每个分支在 `importRules` 前先 `await XxxRepository.load(context)`（避免空缓存被整表重写抹掉），末尾照抄 `copyFile` + `preservedEntryCount += 1` 两行。本表 `:52` 记的「2026-11-06 复核现为 10 组具名分支」是历史时点结论，批 3 之后另加这 5 组。
- **`RestoreResult` / 界面显示**：`BackupRepository.ets:140`–`:156` 为每类加 `xxxAdded` 等计数，返回对象 `:1574`–`:1586` 同步；`Index.ets:5547`–`:5556` 与 `:5625` 新增 `describeG2RuleRestore` 把计数拼进「导入完成」提示。
- **真包往返**（设备 `127.0.0.1:5555`，`BUILD SUCCESSFUL` / 0 ERROR 后 `bm install`）：造 `b3_g2_seed.zip`（21 根条目，5 份 G2 JSON 带 `b3-verify-*` 标记）走「从本地恢复」→「导入此 ZIP」，恢复前 5 张表 `count(*)` 全 0、恢复后 `dictRules|2`、`homepage_modules|1`、`homepage_custom_sets|1`、`highlight_tag_rules|1`、`tag_group_rules|1`，且 `homepage_modules` 的 3 个 `null` 可空列 `typeof` 仍为 `null`（`optionalText` 语义保持）；提示串显示「字典规则新增 2 条。首页模块新增 1 条。首页自定义集新增 1 条。标签高亮规则新增 1 条。标签分组规则新增 1 条。」写出侧先 `rm -f` 保留目录里 5 个透传源再备份，`b3_roundtrip.zip`（21 根条目 / 250231 bytes）仍含 5 个 G2 JSON 且内容来自仓储（带 `b3-verify-*` 标记），证明非空写出分支真执行。完整原始命令行输出见证据包 `N:\HarmonyProjects\tmp\zip-ledger-io-evidence.md` 第五节。
- **`keyboardAssists` 判 `不适用`**：依据 [盘点规约](../PARITY-RULES.md) 第三节「上游无此行为 / 代码里有但从未接线」与「数据层无独立界面」：上游 `ui/` 目录 `grep -rln -i keyboardAssist ... | wc -l` = 0，`keyboardAssistsDao.` 全仓仅 `Backup.kt:196`（`all`）与 `Restore.kt:253`（`insert`）两处消费，DAO 8 个方法里 `update`/`delete`/`flowByType`/`maxSerialNo` 零引用；本地 `grep -rn keyboardAssists entry/src/main/ets --include=*.ets` 仅 2 行（`BackupRepository.ets:463` 白名单、`:490` `categoryOptions`），无仓储、无界面。[书籍总账](BOOKSHELF.md) E `:516` 已按同一依据判 `不适用`。本地无按键映射功能，不假接空表；总账表该行读 / 写 / 忽略项三列由 `✗` / `✗` / `✓` 改 `—`。
- **界面接线不在本批**：`ProfileSubPages.ets` 的 `DictionaryRulesPage`（`:1928`）/ `DictionaryRuleEditPage`（`:2167`）保存按钮 `:2062` / `:2268` 与 `HighlightTagRulesPage`（`:2309`）/ `HighlightTagRuleEditPage`（`:2533`）的 `:2448` / `:2599` 仍走 `onUnavailableAction`（「字典规则／标签规则存储尚未接入，规则未保存」）。**存储侧与备份桥已可用，界面仍会提示未接入** —— 接线要动 `Index.ets` 路由，留到下一批，避免下一个人误以为做完了。
- **覆盖证明**：`scripts/upstream-surface.sh --coverage <类别> <表格路径> N:/HarmonyProjects/legado-with-MD3` 对 5 类 × 8 张表实测「未分配」均不为 0（逐组数字见证据包第六节）—— 判据是上游每个 `.kt` 基名是否出现在表格里，而 G2 五类的上游接触面（`DictRuleScreen.kt`、`HomepageModule*.kt` 等）从未在七张明细表里逐文件盘过。按 [盘点规约](../PARITY-RULES.md) 第二节，逐文件收口属明细表盘点工作、且本批明确不接界面，**不为凑「未分配 0」去改明细表**，如实留到批 4 收口。
- 构建尾部同样**没有**任务文案写的 `COMPILE RESULT: SUCCESSFUL`／`ERROR 0` 字面串，实测等价事实为 `BUILD SUCCESSFUL in 1 min 16 s 786 ms`、`ArkTS:WARN` 570 行、`error:`/`ERROR`/`BUILD FAILED` 0 行（全量干净重建 1763 行日志）。

### 批 4（2026-11-09）`searchHistory` 语义重判 + 账实收口

任务 4.1 给 `searchHistory` 三条路：① 新建 `search_keywords` 表 + 仓储 + 全局搜索关键词池功能；② 判 `不适用`；③ 保留 `未接` 并登记进 `KNOWN-ISSUES.md`。**本批选 ②**（任务标注为推荐），理由与证据如下；选 ② 则 `RdbSchema` 里那张 `search_keywords` 表也不建。

- **语义错配的两条事实**（上游 `N:/HarmonyProjects/legado-with-MD3`，HEAD `bba5c64`）：① `help/storage/Backup.kt:180`–`:181` `if (BackupConfig.dbIsNotIgnored("searchHistory", true)) { writeListToJson(appDb.searchKeywordDao.all, "searchHistory.json", backupPath) }`，`help/storage/Restore.kt:213`–`:216` `fileToListT<SearchKeyword>` + `appDb.searchKeywordDao.insert(...)` —— 上游 `searchHistory.json` 装的是 `SearchKeyword`（全局搜索关键词池，表 `search_keywords`）。② `SearchContentHistory` 全仓命中 6 个文件（`AppDatabase.kt`、`dao/SearchContentHistoryDao.kt`、`entities/SearchContentHistory.kt`、`repository/SearchContentRepository.kt`、`ui/book/searchContent/SearchContentScreen.kt`、`SearchContentViewModel.kt`），**`Backup.kt` / `Restore.kt` 都不命中** —— 上游不备份书内搜索历史。
- **本地对照**：`entry/src/main/ets/data/RdbSchema.ets:62`–`:76` 的 `search_content_history` 表（含 `index_search_content_history_bookName_bookAuthor_query` 唯一索引）与 `entry/src/main/ets/data/ReaderSearchHistoryRepository.ets:1`–`:20` 顶部注释明确对齐上游 `SearchContentHistory.kt`；`grep -rn "search_keywords|SearchKeyword|SearchContentHistory" entry/src/main/ets --include=*.ets` 的命中全在 `RdbSchema.ets` / `ReaderSearchHistoryRepository.ets` / `model/ReaderSearchHistory.ets` / `pages/ReaderSearchPage.ets`，**本地没有 `search_keywords` 表、没有 `SearchKeyword` 实体、没有全局搜索关键词池入口**。本地那套书内搜索历史上游本就不备份，无需接读写桥。
- **判 `不适用` 的证据形态**：按 [盘点规约](../PARITY-RULES.md) 第三节「一条都写不出，就不能判 `不适用`」的反面 —— 这里能写出「上游文件:行号」（`Backup.kt` / `Restore.kt` 的写入与恢复语句）与「检索命令 + 零命中输出」（上游 `SearchContentHistory` 对 `Backup` / `Restore` 零命中、本地对 `search_keywords` / `SearchKeyword` 零命中）两类证据。**如实标注**：这个判定不完全落在第三节的单一四类标签里，它由「上游该类别的实体本地没有对应功能 + 本地已有的同类表上游不备份」两条事实共同支撑，不是「不想做」的出口。故总账表该行读 / 写 / 忽略项三列由 `✗` / `✗` / `未接（语义错配，待批 4 重判）` 改 `—`，`search_keywords` 表不建、`searchHistory.json` 仍只由 `copyPreservedEntries` 原样归档（不进原生功能）。
- **七表盘面重算**（任务 4.2 原命令 `PYTHONIOENCODING=utf-8 python scripts/parity-rows.py --file $t.md | tail -1`，本批不动七张明细表，数字与改前一致）：`BOOKSHELF` 345 行 {已接 131 / 未接 211 / 不适用 3}（C 块四行于 2026-11-09 改判后）；`READER-CONFIG` 189 行 {176 / 11 / 2}；`TXT-READER` 242 行 {210 已接 / 7 不适用 / 25 未接}；`ZIP-BOOKMARK` 117 行 {83 / 30 / 4}；`ZIP-BOOKSHELF-LAYOUT` 122 行 {76 / 43 / 3}；`ZIP-COVER` 66 行 {58 已接 / 6 未接 / 2 不适用}（C8 于 2026-11-09 改判后）；`ZIP-THEME` 91 行 {81 / 7 / 3}。
- **覆盖证明（完成态第 5 条未达成，如实登记）**：`scripts/upstream-surface.sh --coverage <类别> <表格路径> [上游仓库根目录]` 的第三参数在本机**必须**显式传 `N:/HarmonyProjects/legado-with-MD3`（脚本 `SRC_DIR="$REPO_ROOT/app/src/main/java"`，默认值 `.` 会报 `错误：找不到上游源码目录 ./app/src/main/java`）；任务 4.2 示例命令没带这个参数，本机直接跑会失败。判据是「上游每个 `.kt` 基名是否 `grep -qF` 出现在表格文件里」；[盘点规约](../PARITY-RULES.md) 第二节明确逐文件映射的载体是七张明细表，`STATUS.md` 只是 28 行总账表。本批跑了 22 类 × 8 张表 = 176 组矩阵（`N:/HarmonyProjects/tmp/b4_matrix.txt`）：以 `STATUS.md` 作载体 **22 类全部未分配**（去重 495 个上游 `.kt` 基名，逐类清单见 `N:/HarmonyProjects/tmp/b4_unassigned.txt`）；以七张明细表作载体 176 组里 **14 组「未分配 0」通过**（`themeConfig` / `themeMode` / `showRss` → `ZIP-THEME.md`，`bookshelfLayout` → `ZIP-BOOKSHELF-LAYOUT.md`，`mangaConfig` → `READER-CONFIG.md` 与 `TXT-READER.md`，`keyboardAssists` / `localBook` / `bookGroup` / `readRecord` → `BOOKSHELF.md`，`bookmark` → `ZIP-BOOKMARK.md`，`readConfig` → `READER-CONFIG.md` 与 `TXT-READER.md`，`coverConfig` → `ZIP-COVER.md`），其余 10 类最小未分配数不为 0（`threadCount` 11、G2 五类 3–15、`searchHistory` 7、`replaceRule` 27、`txtTocRule` 14、`highlightRule` 9）。按本批用户选择「如实收口，不凑数」：**不改总账表塞 495 个基名、不为凑 0 批量编「已排除」理由**；逐文件收口要核实数百个上游 `.kt` 的本地归属，属明细表盘点工作、另开一轮。完成态第 5 条据此登记为未达成，卡点写进证据包第七节。
- **两条校验**：`PYTHONIOENCODING=utf-8 python scripts/parity-rows.py --file STATUS.md` → `STATUS.md：0 行（口径筛空了）` EXIT=0（脚本只认 `## A`–`## G` 正文块下八列明细表，总账表不在其口径内）；`PYTHONIOENCODING=utf-8 python scripts/doc-links.py docs` → `OK 所有 md 链接可解析（扫了 221 份）` EXIT=0。
- **本批是纯文档**：只改 `docs/parity/STATUS.md`，不碰任何 `.ets`，未构建、未装包、未做真包往返（无代码可验），如实登记。界面接线（`ProfileSubPages.ets` 的字典／标签规则编辑器仍走 `onUnavailableAction`）与 `themeMode` 状态列遗留待核均不在本批范围。

### `httpTTS` 覆盖证明收口（2026-11-09，只收口这一类）

`:174` 批 4 段记的是「22 类 × 8 张表矩阵、不为凑 0 批量编已排除理由、完成态第 5 条未达成」。本轮不推翻那 22 类的结论，只把 `httpTTS` 这一个类别的上游接触面逐文件收口：按 [盘点规约](../PARITY-RULES.md) 第二节「完成判据是覆盖证明」，把 `scripts/upstream-surface.sh --coverage httpTTS` 列出的每个 `.kt` 基名显式分配到「已映射到总账行文」或「已排除 + 理由」二者之一。判据可复跑：

```bash
bash scripts/upstream-surface.sh --coverage httpTTS docs/parity/STATUS.md N:/HarmonyProjects/legado-with-MD3
```

脚本对每个上游 `.kt` 取基名（去掉 `.kt`）后在表格里 `grep -qF`：出现在映射行算「已映射」，出现在「已排除」节算「已排除并给了理由」，两者都没有才算「未分配」。关键词取自 [对照关键词](KEYWORDS.md) 中 `httpTTS` 类别那一行，上游接触面 **27 个 `.kt`**（界面白名单 0 个）。收口后复跑结果为「已分配 27 / 未分配 0，结论：覆盖证明通过（27 / 27 全部已分配）」。

**边界声明**：这里的「已分配」只证明 `httpTTS` 一类的盘点闭环，不证明朗读功能接通。总账 `:72` 记的读写 `✓` 依据是本轮数据层与备份条目互通（`BackupRepository.ets` 写出 `:1015` / `:1019`、恢复 `:1295`），界面明细仍**零行**未盘；网络层三条零命中复核不变。在线服务按 `PROJECT.md:24-44`「已纳入范围、尚未排期」，界面建块与播放链路另开一轮，不在本轮补。

#### 一、已在总账行文出现、脚本判为「已分配」（7 个）

脚本判据是「基名作为**子串** `grep -qF` 出现在表格里」，因此这 7 个并非都精确映射到 `httpTTS` 行，有的是本表别段的交叉引用、甚至宽泛子串命中。如实逐一点名：

- `data/repository/HttpTtsRepository.kt`、`model/ReadAloud.kt`：由 `:72` 总账行、`:105` 恢复侧具名分支表、`:119` 范围调整段的 `HttpTtsRepository.importSources` / `ReadAloudVoiceRepository.replaceHttpVoices` 真正承载，本地同名仓储 `entry/src/main/ets/data/HttpTtsRepository.ets` 与 `model/ReadAloudVoice.ets` 是落点。
- `help/storage/Backup.kt`、`help/storage/BackupConfig.kt`、`help/storage/Restore.kt`：`:45`、`:69`、`:170`、`:192` 等处引用其写入与恢复语句，是备份侧「空表不写 / 空数组也写」语义的依据（`Backup` / `Restore` 作为子串命中面较宽）。
- `App.kt`、`AppDatabase.kt`：`:170` 的 `AppDatabase.kt` 交叉引用（`App` 作为子串在本表更宽泛命中，如 `AppConfig`、`AppUi` 等）；本地对应物是 `RdbSchema.ets` 两张表。

这些是**已存在**的行文，本轮没有为此改动任何一段；下面二～五节才需要新增基名，把原先 20 个「未分配」逐个收口。

#### 二、已排除：数据层定义与接线，形状已落两张表（5 个）

`data/dao/HttpTTSDao.kt`、`data/entities/HttpTTS.kt`、`data/repository/HttpTtsEngineRepository.kt`、`di/appDatabaseModule.kt`、`domain/model/readaloud/HttpTtsCatalogDraft.kt`。

**排除理由**：这些是 Room 实体、DAO 签名、DI 接线与目录草稿形状，本身不产生用户可感知的界面。字段形状已由本地 `model/HttpTts.ets`（14 字段）/ `model/ReadAloudVoice.ets`（14 字段）逐列对齐、由 `RdbSchema.ets` 的 `httpTTS` 与 `read_aloud_voices` 两张表落库；`HttpTTSDao.kt` 的 `order by name` 由本地 `HttpTtsRepository.selectAll` 的 name 升序负责；`HttpTtsCatalogDraft.kt` 的草稿形状由 `HttpTtsImporter` 三分支解析负责。效果（两张表能读写、真包往返）由证据包第五节六条验收承载，不是一句「架构差异」带过。

#### 三、已排除：内置默认源与触发开关（2 个）

`help/DefaultData.kt`、`help/config/LocalConfig.kt`。

**排除理由**：`DefaultData.kt:26-27` 的 `needUpHttpTTS` / `importDefaultHttpTTS()` 与 `LocalConfig.kt:98` 的开关，服务的是「何时把上游内置 `httpTTS.json` 里 `id=-100` 百度 / `id=-29` 阿里云两个源导进库」。本轮按任务书硬约束 6 不搬内置默认引擎：本地 `entry/src/main/resources/rawfile/` 下只有 `licenses` / `txttoc` 两个目录、无 `defaultData/`；「何时导入」的触发点属界面/初始化，不在数据层与备份互通范围（证据包 6.3）。按 [盘点规约](../PARITY-RULES.md) 第三节给出本地零命中证据，不硬套四类标签，如实登记为本轮任务边界外，不作为「本地已有功能」。

#### 四、已排除：目录解析 / 导出 / 合成器 / 缓存工具（4 个）

`help/readaloud/playback/HttpTtsAudioSynthesizer.kt`、`help/readaloud/speech/HttpTtsCatalogExporter.kt`、`help/readaloud/speech/HttpTtsCatalogParser.kt`、`utils/TTSCacheUtils.kt`。

**排除理由**：这 4 个都不读写 `httpTTS.json` / `httpTtsVoices.json` 两份备份条目。`HttpTtsCatalogParser.kt` 的 `coerceIn(1, 8)` 钳制语义已由本地 `HttpTtsImporter.toSource` 的 `Math.min(8, Math.max(1, ...))` 承接（批 2，导入器读的是备份条目而非上游目录草稿）；`HttpTtsCatalogExporter.kt` 是上游目录导出，本轮写出侧直接读本地两张表；`HttpTtsAudioSynthesizer.kt` / `TTSCacheUtils.kt` 属 HTTP 合成与音频缓存，需要网络层与播放器，本轮不加网络、不碰播放。效果（钳制、写出真值）由导入器 / 仓储与真包往返负责。

#### 五、已排除：播放服务与朗读界面（本轮范围外，逐字登记）（9 个）

`service/HttpReadAloudService.kt`、`ui/association/ImportHttpTtsDialog.kt`、`ui/association/ImportHttpTtsViewModel.kt`、`ui/book/read/ReadAloudDelegate.kt`、`ui/book/readaloud/cache/TtsCacheViewModel.kt`、`ui/book/readaloud/cloudtts/CloudTtsContract.kt`、`ui/book/readaloud/cloudtts/CloudTtsScreen.kt`、`ui/book/readaloud/cloudtts/CloudTtsViewModel.kt`、`ui/login/SourceLoginJsExtensions.kt`。

**排除理由**：这些是「朗读能出声」链路与「朗读引擎与音色」界面（上游 `HttpReadAloudService.kt` 2149 行、`ui/book/readaloud/` 46 文件 15823 行）。本轮按任务书只做数据层与备份互通，不碰播放、界面与网络层；两设置页占位与 `ReaderPage.ets` 两处 `onUnavailableAction`「朗读播放尚未迁移」保持原样。它们不是被当作「不存在」抹掉，而是如实登记为界面明细**零行**未盘、`PROJECT.md:24-44` 在线服务已纳入范围但尚未排期、需另开一轮按界面逐文件建块。按 [盘点规约](../PARITY-RULES.md) 第三节，这里给的是「被哪个块承载」的落点（待界面块建立），不套「范围之外」标签、不作「架构差异」单独排除。

#### 六、未分配

**0 个。** 27 个上游 `.kt` 全部分配完毕（映射到行文 7 个 + 已排除并给理由 20 个）。本轮只收口 `httpTTS` 一类，`:174` 批 4 段对其余 21 类的结论不变。

### 忽略项列逐类核对结论（2026-11-09）

上节判据逐类落到总账表后，忽略项列 20 个 `?` 全部落文字（状态由代码事实决定，不随读/写列改动）：

- `等价（类别级）` 6 类：`bookmark`、`bookGroup`、`replaceRule`、`readRecord`、`txtTocRule`、`highlightRule` —— 都有独立 JSON 文件 + 恢复侧具名分支，`isIgnored` 反查 `categoryOptions.files` 生效。
- `类别级等价，键级不等价（N 键）` 8 类：`readConfig`（60）、`themeConfig`（53）、`bookshelfLayout`（39）、`mangaConfig`（32）、`coverConfig`（14）、`themeMode`（1）、`showRss`（1）、`threadCount`（1）—— 键数取自 `BackupRepository.ets:383` 的 `preferenceKeysByCategory`，这 8 类正是 `preferenceKeysForCategory`（定义 `:579`）if 链覆盖的全部类别。其中 `showRss` 读/写列批 2 已改判 `✓`（写出侧补了 upsert，见下方「批 2」节），`threadCount`／`mangaConfig` 仍为 `✗` 且批 2 判未接；但忽略项列只判门控语义、不随读写列改动。
- `等价（类别级）` 5 类（G2，批 3 回填）：`dictRule`、`homepageModules`、`homepageCustomSets`、`highlightTagRule`、`tagGroupRule` —— 批 3 接出独立 JSON 文件 + `categoryOptions` 开关 + `isIgnored` 跳过 + 恢复侧具名分支，判据与第一档一致，见下方「批 3」节。
- `—`（不适用）1 类：`searchHistory` —— 批 4 按任务 4.1 推荐的路 2 重判：上游 `searchHistory.json` 装 `SearchKeyword`（全局搜索关键词池，本地无此入口与表），本地 `search_content_history` 对应上游 `SearchContentHistory` 而上游不备份该表，故这一类别在本地没有可落地的读写对象；不新建 `search_keywords` 表与全局搜索关键词池功能，其余 19 类忽略项判定不变。理由与证据见下方「批 4」节。
- 既有判定：`localBook` = `—`（上游由 `backupIgnoreLocalBook` 单独控制，本地走 `localBook` 键过滤本地书）；`keyboardAssists` 原 `✓` 是「`isIgnored` 能跳过该文件」的判定，批 3 已按「上游仅存储无界面」复核为 `—`（见下方「批 3」节）。任务文案说「22 个 `?`」，实测总账表忽略项列为 `?` 的恰是上述 20 个，另两类本就不是 `?`。

机制核实修正（2026-11-09 HEAD 实测）：旧文记 `isIgnored` 在 `:1539`、后又记作 `:2264`，现实测定义在 `entry/src/main/ets/data/BackupRepository.ets:2694`；对 `bookshelf.json`/`config.xml` 恒 `false` 的行为不变。config.xml 派生类别的门控落在紧随其后的 `filterAndroidConfigXml`，按 `preferenceKeysForCategory(key)` 整组把键从 XML 剔除。

### 一处已知的上游差异

`directLinkUploadRule` 上游无独立忽略项（`help/storage/Backup.kt:248` 写该文件时不带任何门控），故本表不设此行，与上游一致。

## 明细表约定

明细表**不按类别拆文件**，而是按界面组织，一张表可承载多个类别：

| 表 | 块 | 承载的类别 |
| --- | --- | --- |
| [书籍总账](BOOKSHELF.md) | A1 / A2 / A3 / B / C / D | `localBook`、`bookshelfLayout`、`bookGroup`、`bookSource`、`readRecord`、`readConfig`、`threadCount`、`highlightTagRule`、`tagGroupRule` |
| [书架布局总账](ZIP-BOOKSHELF-LAYOUT.md) | A–F（r327 新增） | `bookshelfLayout`、`themeConfig`（A 块两个卡片底色行）。A1/A2 里与本表重叠的行以本表为准，A1/A2 其余行不受影响 |
| [书籍总账](BOOKSHELF.md) | E（r295 新增） | `localBook`（`:510`）、`keyboardAssists`（r336 追加 6 行）；其余 12 行记 `—` |
| [书签对照](ZIP-BOOKMARK.md) | A–E | `bookmark` |
| [阅读配置总账](READER-CONFIG.md) | A–G | `readConfig`、`themeConfig` |
| [TXT 阅读总账](TXT-READER.md) | A–D（217 个上游文件的主体） | `readConfig`、`localBook`、`themeConfig` 里与 TXT 阅读链路相关的行 |
| [深色模式总账](ZIP-THEME.md) | A–F（r298 新增，r300 阶段一落地） | `themeMode`、`themeConfig` |
| [封面设置总账](ZIP-COVER.md) | A–E（r330 新增） | `coverConfig`。A 块是设置页 18 条，B 块是默认封面相册，C 块是封面规则，D 块是封面渲染（跨全部用到封面组件的界面），E 块是备份归属。该表表头另加第五档 `不进备份`，用于相册目录这类连 ZIP 都进不去的数据 |

上表「涉及行」列给出每类在这几张表里落在哪一块、多少行。**「零行」表示该类目前没有任何界面级盘点**——不是已完成，而是还没盘。这一类要动之前先按[对照关键词](KEYWORDS.md)取出上游接触面、新开块，不要拿「表里没这一行」当「本地没有这个功能」。

E 块是个例外：它承载的是**对 28 类关键词全部隐身**的那 21 个存储层文件（`help/storage/BookRestorePlanner.kt`、`ui/config/backupConfig/BackupConfigScreen.kt` 等），不属于任何一个类别，所以它在总账表 28 行里没有对应行。之所以专门开块，是因为按类别名派活永远覆盖不到它——`BookRestorePlanner.kt` 的 `booksToDelete` / `isRelocatedCopyOf` / `Available-Missing-Unknown` 三态就是靠这个块才第一次进入盘点视野。

明细表每行以一次用户可感知的操作为粒度，八列：

`上游能力 | 上游位置(文件:行) | 本地位置(文件:行) | 状态 | 差异说明 | 验收方式 | 备注 | ZIP 类别`

最后一列是 2026-10-30（r292）新增的，判据、取值与「怎么读」见各表表头的说明。

状态只允许 `已接` / `未接` / `不适用` 三值，不设「部分接」「基本完成」，也不设 `待定`——`不适用` 必须写理由，盘点结束前必须判完。口径与[盘点规约](../PARITY-RULES.md)第二节一致。

## 维护

改本表时同步改[对照关键词](KEYWORDS.md)与 `BackupRepository.ets` 的 `categoryOptions`，三者用同一套键名。检索接触面用 `scripts/upstream-surface.sh <类别键名>`，它只打印清单，不生成表格。

**盘点单位是界面，不是按钮**：盘某个功能时，只要涉及某个界面（进了这个页、开了这个弹层、这个界面被改动），就要把该界面的完整构成列进表，未迁移的显式标 `未接`，不只列与本功能相关的按钮。定义与反例见[术语表](../GLOSSARY.md)的 **界面清单**、[盘点规约](../PARITY-RULES.md)第二节。

**每轮盘点结束必须当轮落盘，并重跑覆盖证明**：明细表写完就跑 `scripts/upstream-surface.sh --coverage <类别> <表格路径>`，未分配不为 0 就是没盘完；「表里没有 `待定`」只证明表格自洽，不证明上游被覆盖。
