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
- **本地是「这次备份不勾 X」**：`BackupRepository.ets` 的 `ignoredCategories` 来自本次备份/恢复的勾选、不持久；`isIgnored`（HEAD 版 `:2264`，旧文记 `:1539` 已漂）对 `bookshelf.json`/`config.xml` 恒 `false`，其余按 `categoryOptions.files` 反查类别键名再查 `ignored.includes(key)`；config.xml 派生类别由 `filterAndroidConfigXml` 按 `preferenceKeysForCategory(key)` **整组剔键**，用户不能只勾「忽略某一个键」。
- **等价点**：两者都能让「某一类不出现在备份包里」，恢复时也都能跳过该类的 ZIP 条目 —— 在「用户能不能让某一类不出现在包里」这一点上等价。
- **不等价点**：① 作用域：上游全局持久、单次配置长期生效；本地每次备份重新勾选、不持久。② 粒度：上游有键级门控（含 `alwaysIgnoredPreferenceKeys` 逐键），本地 `filterAndroidConfigXml` 只能按类别整组剔键。故 config.xml 派生的 8 类记「类别级等价，键级不等价」，括号里列出该类别 `preferenceKeysByCategory` 登记的键数 —— 这些键本地只能整类开关，不能逐键。
- **三档取值**：`等价（类别级）` = 本地有该类的 `categoryOptions` 开关且恢复时 `isIgnored` 能跳过对应独立 JSON 文件；`类别级等价，键级不等价（N 键）` = 类别开关有、但上游可逐键而本地只能整组剔 N 个键；`未接` = `categoryOptions` 虽登记了类别键名，但该类读写两侧都走 `copyPreservedEntries`、没有原生仓储可落，勾了忽略也只是不进保留目录，语义上无从等价（G2，批 3 接通后回填）。忽略项列只判门控语义，**与读/写列是否接通无关** —— 读写 `✗` 的类只要门控能跳过条目，忽略项仍可判等价。`—`/`✓` 为既有判定，不属本次 20 个 `?` 的范围。

**本表是骨架，不是盘点结论。** 状态依据来自 2026-10-30（r287）对 `entry/src/main/ets/data/BackupRepository.ets` 的代码核实：恢复侧具名分支当时只有 8 个 `entry.name ===` 判断（`bookshelf.json`、`config.xml`、`bookGroup.json`、`replaceRule.json`、`txtTocRule.json`、`highlightRule.json`、`bookmark.json`、`bookMarking.json`），对应 7 个类别；其余全部走 `copyPreservedEntries` 原样归档。**2026-11-06 复核：现为 10 组具名分支**（新增 `themeConfig.json`、readRecord 三份、`coverRule.json`）。

本次核实把原先 4 个 `?`（`themeMode`、`showRss`、`threadCount`、`mangaConfig`）全部落定为 `✗`：`config.xml` 写出侧只 upsert 三段（`bookshelfLayout` 9 键、`readConfig` 阅读外观、`themeConfig` 护眼 6 键），读入侧 46 键，这 4 类的键既不在写出列表也不在读入列表。**「读」列的 `✗` 表示该类的 ZIP 条目恢复时不进原生功能，但条目本身仍会被原样归档**——归档不等于支持。

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
| `readRecord` | `readRecord.json`、`readRecordDetail.json`、`readRecordSession.json` | ✗ | ✗ | 等价（类别级） | [书籍总账](BOOKSHELF.md) C 23 / B 5 = **28 行**（r334 判断段复核：11 已接 / 16 `未接` / 1 不适用；16 行未接 = B 块 3 行 `:272`/`:280`/`:307` + C 块 13 行） |
| `searchHistory` | `searchHistory.json` | ✗ | ✗ | 未接（语义错配，待批 4 重判） | **零行**；语义错配：上游 `searchHistory.json` 装的是 `SearchKeyword`（全局搜索关键词池，表 `search_keywords`），本地 `ReaderSearchHistoryRepository` 对应的是上游 `SearchContentHistory`（书内搜索，表 `search_content_history`），而上游不备份后者——本地与上游的 `searchHistory` 是两个东西 |
| `sourceSub` | `sourceSub.json` | ✗ | ✗ | 未接 | **零行** |
| `txtTocRule` | `txtTocRule.json` | ✓ | ✓ | 等价（类别级） | [TXT 阅读总账](TXT-READER.md) = **5 行**（`:84`、`:85`、`:86`、`:93`、`:95`）；`grep -c txtTocRule` 实测 6，多的 1 行是 `:965` 的「ZIP 类别取值」表头说明同时列了两词，非数据行 |
| `httpTTS` | `httpTTS.json`、`httpTtsVoices.json` | ✗ | ✗ | 未接 | **零行**；`httpTtsVoices.json` 写空数组 `[]`，`httpTTS.json` 不写（批 3：`[]` 承载上游「确实没有音色」语义，透传件存在时不覆盖） |
| `keyboardAssists` | `keyboardAssists.json` | ✗ | ✗ | ✓ | [书籍总账](BOOKSHELF.md) E = **6 行**（r336 判断段建行，E 块由 13 行增至 19 行；面板级见 E `:507`，类别级见 E 新增 6 行） |
| `dictRule` | `dictRule.json` | ✗ | ✗ | 未接（批 3 之后回填） | **零行** |
| `homepageModules` | `homepageModules.json` | ✗ | ✗ | 未接（批 3 之后回填） | **零行** |
| `homepageCustomSets` | `homepageCustomSets.json` | ✗ | ✗ | 未接（批 3 之后回填） | **零行** |
| `highlightRule` | `highlightRule.json` | ✓ | ✓ | 等价（类别级） | **零行** |
| `highlightTagRule` | `highlightTagRule.json` | ✗ | ✗ | 未接（批 3 之后回填） | [书籍总账](BOOKSHELF.md) B = **1 行** |
| `tagGroupRule` | `tagGroupRule.json` | ✗ | ✗ | 未接（批 3 之后回填） | [书籍总账](BOOKSHELF.md) A3 = **4 行** |
| `server` | `servers.json` | ✗ | ✗ | 未接 | **零行** |
| `readConfig` | `readConfig.json`、`shareReadConfig.json`、`config.xml` | ✓ | ✓ | 类别级等价，键级不等价（83 键） | [阅读配置总账](READER-CONFIG.md) A–G = **189 行**（176 已接 / 11 `未接` / 2 不适用）；11 条 `未接` 已在 [已知问题](../KNOWN-ISSUES.md#阅读配置行登记reader-configmd-的未接行) 逐条登记；另 [书籍总账](BOOKSHELF.md) A2 1 / D4 1 |
| `themeConfig` | `themeConfig.json`、`config.xml` | ✓ | ✓ | 类别级等价，键级不等价（54 键） | [深色模式总账](ZIP-THEME.md) A 46 / B 12 / D 1 / E 7 / F 6 = **72 行**（已接 64 / `未接` 6 / 不适用 2）。r300–r316 十七批的逐批落地过程与每行改判理由见 [深色模式总账](ZIP-THEME.md) 的「盘面」节，本节只记结果。剩余 6 行均已判「不接」（A3 Miuix 动态取色、A7 主题引擎切换、A18 平板界面、A19 多窗布局、E7 提醒 intent 链路、A23 作者搜索回退），判「不接」不删行不改状态，仍按 `未接` 计。另 [阅读配置总账](READER-CONFIG.md) F = **7 行**（护眼字段，阅读设置页那一套） |
| `coverConfig` | `coverRule.json`、`config.xml` | ✓ | ✓ | 类别级等价，键级不等价（14 键） | [封面设置总账](ZIP-COVER.md) A 18 / B 15 / C 9 / D 18 / E 6 = **66 行**（57 已接 / 7 `未接` / 2 不适用，r330 建表、r334 实现段收口；接触面 83 个 `.kt` 全部已分配）。7 条 `未接` 已在 [已知问题](../KNOWN-ISSUES.md#封面配置行登记zip-covermd-的未接行) 按 KI-COVER1..9 逐行登记。旧关键词 `backupIgnoreCoverConfig\|"coverConfig"` 只命中 3 个文件，本轮换成 14 词组合式后接触面 3 → 83，该类别此前记「零行」正是自证成功的结果 |
| `themeMode` | `config.xml` | ✗ | ✗ | 类别级等价，键级不等价（1 键） | [深色模式总账](ZIP-THEME.md) A 1 / C 5 / D 7 / F 6 = **19 行**（17 已接 / 1 `未接` / 1 不适用，A8 的图标切换按 `themeConfig` 类计不适用；D4 主题列表页的日夜切换按钮 2026-11-09 由 `不适用` 改判 `未接`，本地无主题列表页；A1/C4/D2/F1/F2/F3/F10 已接，r300 落地；D7 已接，r302 落地；F9、F11 已接，r303 落地；C1 向导第 4 页深色模式点选即写全局并立刻换肤、C2 向导调色板选择落盘 `paletteIndex` 已接，r305 落地；D3 三值派生布尔、D8 阅读菜单日夜配色 r306 复查改判已接）；另 A2/A4 的界面也受 `themeMode` 影响，主类别记在 `themeConfig` |
| `bookshelfLayout` | `config.xml` | ✓ | ✓ | 类别级等价，键级不等价（39 键） | [书架布局总账](ZIP-BOOKSHELF-LAYOUT.md) A 47 / B 26 / C 14 / D 12 / E 14 / F 9 = **122 行**（76 已接 / 43 `未接` / 3 不适用，r327 建表、r331/r332 落地 38 行；接触面 24 个 `.kt` 全部已分配）。43 条 `未接` 按 `**要接**`（2）/ `**不接**`（41）逐行登记进 [KNOWN-ISSUES](../KNOWN-ISSUES.md) 的「书架布局行登记」。BOOKSHELF.md 的 A2 33 / A1 20 里与本表重叠的行，以本表为准 |
| `showRss` | `config.xml` | ✗ | ✗ | 类别级等价，键级不等价（1 键） | **零行** |
| `threadCount` | `config.xml` | ✗ | ✗ | 类别级等价，键级不等价（1 键） | [书籍总账](BOOKSHELF.md) A2 = **1 行** |
| `mangaConfig` | `config.xml` | ✗ | ✗ | 类别级等价，键级不等价（32 键） | **零行** |

## 状态依据

### 已核实的七类具名处理

`entry/src/main/ets/data/BackupRepository.ets` 的恢复循环里，`entry.name` 具名分支只有七处：

| 行 | 条目 | 落地方式 |
| --- | --- | --- |
| `:712` | `bookshelf.json` | `mergeAndroidBookshelf` 合并后落 `android-backup-entries/`，再经 `restoreMatchingLocalProgress` 更新本地书籍进度 |
| `:731` | `config.xml` | `filterAndroidConfigXml` 按忽略项剔键后归档，键值经 `restoreReaderSettings`、`restoreBookshelfLayout` 落到 `ReaderSettingsRepository`、`BookshelfLayoutRepository` |
| `:742` | `bookGroup.json` | `BookGroupRepository.importAndroidFile` |
| `:752` | `replaceRule.json` | `ReplaceRuleImporter.parse` → `ReplaceRuleRepository.importRules` |
| `:769` | `txtTocRule.json` | `TxtTocRuleImporter` → `TxtTocRuleRepository` |
| `:783` | `highlightRule.json` | `ReaderHighlightRuleRepository`（合并语义，见[备份恢复](../BACKUP-RESTORE.md)） |
| `:797` | `bookmark.json`、`bookMarking.json` | `ReaderBookmarkImporter.mergeBookmarks` / `mergeMarkings`，两份合并完再统一落盘 |

其余条目走 `:822` 的兜底 `fileIo.copyFile`，只进保留目录，不落原生仓储。因此 `readRecord`、`searchHistory`、`keyboardAssists`、`dictRule`、`homepageModules`、`homepageCustomSets`、`highlightTagRule`、`tagGroupRule` 判 `✗`，不是「没查」，而是「查过、确认未接」。（`coverConfig` 原先也在这条清单里，r334 实现段已把 14 个封面键双向接通、66 行里 57 行已接，因此它现在是「部分接入」，不再属于「确认未接」一组。）。

### 原判 `—`、现改判 `✗` 的六类（2026-11-09 范围调整）

`bookSource`、`rssSource`、`rssStar`、`sourceSub`、`httpTTS`、`server` 六类此前判 `—`，依据是[项目队列](../PROJECT.md)的「范围之外」。**2026-11-09 起，在线书源抓取、RSS 拉取、TTS 服务、WebDAV 已移出「范围之外」**，改列入 `PROJECT.md` 的「在线服务（已纳入范围，尚未排期）」一节，因此这六类不再具备判 `—` 的依据，按 `docs/PARITY-RULES.md` 第三节「一条依据都写不出，就不能判不适用——降级为未接」降级为 `✗`：

- **读 / 写**：两侧都 `✗`，条目只经 `copyPreservedEntries` 原样归档，本地没有对应原生仓储可落。
- **忽略项**：判 `未接`。`categoryOptions` 里虽然登记了这六类的类别键名（勾选后确实能把条目挡在保留目录之外），但该类没有原生功能可落，门控「跳过的是什么」无从等价——按上节「三档取值」的口径，这类只能记 `未接`，等读写接通后回填。
- **涉及行**：`bookSource` 在 [书籍总账](BOOKSHELF.md) B 19 / D3 5 = 24 行；其余五类仍零行（`rssSource`、`rssStar`、`sourceSub`、`httpTTS`、`server`）。**零行不等于不做**：这六类的界面块要等排期后按 `docs/PARITY-RULES.md` 的盘点单位（整个界面）重新建块，届时行数会从 0 涨起来。
- **`httpTTS` 的例外**：本地写出侧确实会写 `httpTtsVoices.json` 的空数组 `[]`（`!accessSync` 才写，避免覆盖透传的真音色），但这是「承载上游『确实没有音色』语义」的占位，不是 TTS 功能本身，故读写仍判 `✗`。

**归档保留不等于功能兼容**：这六类的条目仍会随备份往返，但本地既不解析也不应用，恢复后用户看不到任何效果。

### 判 `?` 的四类与 `themeConfig` 写的复核

`themeMode`、`showRss`、`threadCount`、`mangaConfig` 只有 `preferenceKeysByCategory` 的键分组，没有独立的备份或恢复分支，实际效果取决于 `config.xml` 的整体搬运路径，需逐个键核对才能定论。其中 `themeMode` 已在 [深色模式总账](ZIP-THEME.md) F9 逐行核实：`createBackup` 的 `config.xml` 写出清单不含该键，恢复侧 `filterAndroidConfigXml` 只是原样保留，故读写两侧都判 `✗`，界面侧另见该表 C/D/F 三块。

`themeConfig` 的「写」列 2026-11-09 复核为**已实现**，总账表由 `✗` 改 `✓`：当前 HEAD（`60bbba2`）的 `createBackup` 在 config.xml 段之后有 `!ignoredCategories.includes('themeConfig')` 门控分支（`entry/src/main/ets/data/BackupRepository.ets:892`–`:895`，实测 `git show HEAD:... | grep -n buildCurrentThemeConfigs`），内调 `buildCurrentThemeConfigs(paletteIndex, customTheme)` → `themeConfigsToJson` → `writeTextFile` 写出 `themeConfig.json`；恢复侧 `:1161` 有 `if (entry.name === THEME_CONFIG_FILE_NAME)` 具名分支走 `parseThemeConfigs` + `saveThemeConfigs`。[深色模式总账](ZIP-THEME.md) F5 原记「应补写出、当前判未接」，是补写前的判断段，现已被上述代码落地覆盖，结论以本节与总账表为准。

`bookshelfLayout` 的「读」列 2026-11-09 复核为**已恢复**，总账表由 `✗` 改 `✓`：当前 HEAD `:1245`–`:1253` 在恢复主循环之后调用 `BackupRepository.restoreBookshelfLayout(selection.stagingDirectory, currentBookshelfLayout, ignoredCategories)` 并 `await BookshelfLayoutRepository.save(context, bookshelfLayout)`，函数定义在 `:1479`，数据落 `BookshelfLayoutRepository` 原生仓储，符合本表「读」的定义。

`replaceRule` / `txtTocRule` 的「涉及行」原记「零行」，实测 [TXT 阅读总账](TXT-READER.md) 各有 6 / 5 行数据行，出处行号已回填总账表。`grep -c` 实测 7 / 6，各比数据行多 1，多出的是 `:965` 的「ZIP 类别取值」表头说明行同时列举了这两个词、不是数据行；`grep -c highlightRule docs/parity/TXT-READER.md` 实测 `0`，只有 `highlightRule` 是真「零行」。

行号口径说明：任务文案引用的 `:858`–`:862` / `:1123` / `:1187`–`:1190` 以及「HEAD 2676 行、工作区 2806 行（多 130 行 readRecord）」是更早状态；实测当前 HEAD 与工作区均为 2806 行、两者 `git diff --numstat` 为空，readRecord 三份已在 HEAD 内。本表行号一律按 `git show HEAD:entry/src/main/ets/data/BackupRepository.ets` 实测填写。

### 忽略项列逐类核对结论（2026-11-09）

上节判据逐类落到总账表后，忽略项列 20 个 `?` 全部落文字（状态由代码事实决定，不随读/写列改动）：

- `等价（类别级）` 6 类：`bookmark`、`bookGroup`、`replaceRule`、`readRecord`、`txtTocRule`、`highlightRule` —— 都有独立 JSON 文件 + 恢复侧具名分支，`isIgnored` 反查 `categoryOptions.files` 生效。
- `类别级等价，键级不等价（N 键）` 8 类：`readConfig`（83）、`themeConfig`（54）、`bookshelfLayout`（39）、`mangaConfig`（32）、`coverConfig`（14）、`themeMode`（1）、`showRss`（1）、`threadCount`（1）—— 键数取自 `BackupRepository.ets:328` 的 `preferenceKeysByCategory`，这 8 类正是 `preferenceKeysForCategory`（`:510`）if 链覆盖的全部类别。其中 `showRss`/`threadCount`/`mangaConfig` 读/写列仍为 `✗`（写出侧未 upsert，见批 2），但忽略项列只判门控语义。
- `未接` 5 类（G2，批 3 之后回填）：`dictRule`、`homepageModules`、`homepageCustomSets`、`highlightTagRule`、`tagGroupRule` —— 本地零原生存储，忽略开关无原生功能可落。
- `未接（语义错配，待批 4 重判）` 1 类：`searchHistory` —— 上游装 `SearchKeyword`（全局搜索关键词池），本地 `search_content_history` 对应上游 `SearchContentHistory`（书内搜索，上游不备份），两者不是同一件事，见批 4。
- 既有判定不动：`localBook` = `—`（上游由 `backupIgnoreLocalBook` 单独控制，本地走 `localBook` 键过滤本地书）；`keyboardAssists` = `✓` 是「`isIgnored` 能跳过该文件」的既有判定，批 3 将按「上游仅存储无界面」复核为 `不适用`，本批不改。任务文案说「22 个 `?`」，实测总账表忽略项列为 `?` 的恰是上述 20 个，另两类本就不是 `?`。

机制核实修正（当前 HEAD `60bbba2` 实测）：旧文记 `isIgnored` 在 `:1539`，HEAD 版实为 `entry/src/main/ets/data/BackupRepository.ets:2264`；对 `bookshelf.json`/`config.xml` 恒 `false` 的行为不变。config.xml 派生类别的门控落在紧随其后的 `filterAndroidConfigXml`，按 `preferenceKeysForCategory(key)` 整组把键从 XML 剔除。

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
