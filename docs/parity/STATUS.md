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
| `—` | 不适用，理由必写（通常是[项目队列](../PROJECT.md)的范围之外） |
| `?` | 未盘，尚未逐个文件核对 |

**本表是骨架，不是盘点结论。** 状态依据来自 2026-10-30（r287）对 `entry/src/main/ets/data/BackupRepository.ets` 的代码核实：恢复侧具名分支只有 8 个 `entry.name ===` 判断（`bookshelf.json`、`config.xml`、`bookGroup.json`、`replaceRule.json`、`txtTocRule.json`、`highlightRule.json`、`bookmark.json`、`bookMarking.json`），对应 7 个类别；其余全部走 `copyPreservedEntries` 原样归档。

本次核实把原先 4 个 `?`（`themeMode`、`showRss`、`threadCount`、`mangaConfig`）全部落定为 `✗`：`config.xml` 写出侧只 upsert 三段（`bookshelfLayout` 9 键、`readConfig` 阅读外观、`themeConfig` 护眼 6 键），读入侧 46 键，这 4 类的键既不在写出列表也不在读入列表。**「读」列的 `✗` 表示该类的 ZIP 条目恢复时不进原生功能，但条目本身仍会被原样归档**——归档不等于支持。

逐类的「本地有无原生页面」需要另看 [Android ZIP 备份兼容](../BACKUP-RESTORE.md) 的 28 类清单，那里有样本条数与本地页面状态；本表只管 ZIP 读写通不通。

## 总账

| 类别键名 | 条目 | 读 | 写 | 忽略项 | 涉及行 |
| --- | --- | --- | --- | --- | --- |
| `localBook` | `bookshelf.json` | ✓ | ✓ | — | [书籍总账](BOOKSHELF.md) A1 29 / B 51 / C 4 / D3 13 / E 1 = **98 行**（72 条 `未接` 已在 [已知问题](../KNOWN-ISSUES.md#本地书籍行登记bookshelfmd-的-localbook-未接行) 逐条登记） |
| `bookmark` | `bookmark.json`、`bookMarking.json` | ✓ | ✓ | ? | [书签对照](ZIP-BOOKMARK.md) A–E = **83 行** |
| `bookGroup` | `bookGroup.json` | ✓ | ✓ | ? | [书籍总账](BOOKSHELF.md) A3 18 / A1 11 / D3 6 / B 3 = **38 行** |
| `bookSource` | `bookSource.json` | — | — | — | [书籍总账](BOOKSHELF.md) B 19 / D3 5 = **24 行** |
| `rssSource` | `rssSources.json` | — | — | — | **零行** |
| `rssStar` | `rssStar.json` | — | — | — | **零行** |
| `replaceRule` | `replaceRule.json` | ✓ | ✓ | ? | **零行** |
| `readRecord` | `readRecord.json`、`readRecordDetail.json`、`readRecordSession.json` | ✗ | ✗ | ? | [书籍总账](BOOKSHELF.md) C 23 / B 5 = **28 行**（r334 判断段复核：11 已接 / 16 `未接` / 1 不适用；16 行未接 = B 块 3 行 `:272`/`:280`/`:307` + C 块 13 行） |
| `searchHistory` | `searchHistory.json` | ✗ | ✗ | ? | **零行** |
| `sourceSub` | `sourceSub.json` | — | — | — | **零行** |
| `txtTocRule` | `txtTocRule.json` | ✓ | ✓ | ? | **零行** |
| `httpTTS` | `httpTTS.json`、`httpTtsVoices.json` | — | — | — | **零行** |
| `keyboardAssists` | `keyboardAssists.json` | ✗ | ✗ | ? | **零行** |
| `dictRule` | `dictRule.json` | ✗ | ✗ | ? | **零行** |
| `homepageModules` | `homepageModules.json` | ✗ | ✗ | ? | **零行** |
| `homepageCustomSets` | `homepageCustomSets.json` | ✗ | ✗ | ? | **零行** |
| `highlightRule` | `highlightRule.json` | ✓ | ✓ | ? | **零行** |
| `highlightTagRule` | `highlightTagRule.json` | ✗ | ✗ | ? | [书籍总账](BOOKSHELF.md) B = **1 行** |
| `tagGroupRule` | `tagGroupRule.json` | ✗ | ✗ | ? | [书籍总账](BOOKSHELF.md) A3 = **4 行** |
| `server` | `servers.json` | — | — | — | **零行** |
| `readConfig` | `readConfig.json`、`shareReadConfig.json`、`config.xml` | ✓ | ✓ | ? | [阅读配置总账](READER-CONFIG.md) A–G = **189 行**（176 已接 / 11 `未接` / 2 不适用）；11 条 `未接` 已在 [已知问题](../KNOWN-ISSUES.md#阅读配置行登记reader-configmd-的未接行) 逐条登记；另 [书籍总账](BOOKSHELF.md) A2 1 / D4 1 |
| `themeConfig` | `themeConfig.json`、`config.xml` | ✓ | ✗ | ? | [深色模式总账](ZIP-THEME.md) A 46 / B 12 / D 1 / E 7 / F 6 = **72 行**（已接 64 / `未接` 6 / 不适用 2）。r300–r316 十七批的逐批落地过程与每行改判理由见 [深色模式总账](ZIP-THEME.md) 的「盘面」节，本节只记结果。剩余 6 行均已判「不接」（A3 Miuix 动态取色、A7 主题引擎切换、A18 平板界面、A19 多窗布局、E7 提醒 intent 链路、A23 作者搜索回退），判「不接」不删行不改状态，仍按 `未接` 计。另 [阅读配置总账](READER-CONFIG.md) F = **7 行**（护眼字段，阅读设置页那一套） |
| `coverConfig` | `coverRule.json`、`config.xml` | ✗ | ✗ | ? | [封面设置总账](ZIP-COVER.md) A 18 / B 15 / C 9 / D 18 / E 6 = **66 行**（57 已接 / 7 `未接` / 2 不适用，r330 建表、r334 实现段收口；接触面 83 个 `.kt` 全部已分配）。7 条 `未接` 已在 [已知问题](../KNOWN-ISSUES.md#封面配置行登记zip-covermd-的未接行) 按 KI-COVER1..9 逐行登记。旧关键词 `backupIgnoreCoverConfig\|"coverConfig"` 只命中 3 个文件，本轮换成 14 词组合式后接触面 3 → 83，该类别此前记「零行」正是自证成功的结果 |
| `themeMode` | `config.xml` | ✗ | ✗ | ? | [深色模式总账](ZIP-THEME.md) A 1 / C 5 / D 7 / F 6 = **19 行**（17 已接 / 0 `未接` / 2 不适用，A8 的图标切换按 `themeConfig` 类计不适用；A1/C4/D2/F1/F2/F3/F10 已接，r300 落地；D7 已接，r302 落地；F9、F11 已接，r303 落地；C1 向导第 4 页深色模式点选即写全局并立刻换肤、C2 向导调色板选择落盘 `paletteIndex` 已接，r305 落地；D3 三值派生布尔、D8 阅读菜单日夜配色 r306 复查改判已接）；另 A2/A4 的界面也受 `themeMode` 影响，主类别记在 `themeConfig` |
| `bookshelfLayout` | `config.xml` | ✗ | ✓ | ? | [书架布局总账](ZIP-BOOKSHELF-LAYOUT.md) A 47 / B 26 / C 14 / D 12 / E 14 / F 9 = **122 行**（76 已接 / 43 `未接` / 3 不适用，r327 建表、r331/r332 落地 38 行；接触面 24 个 `.kt` 全部已分配）。43 条 `未接` 按 `**要接**`（2）/ `**不接**`（41）逐行登记进 [KNOWN-ISSUES](../KNOWN-ISSUES.md) 的「书架布局行登记」。BOOKSHELF.md 的 A2 33 / A1 20 里与本表重叠的行，以本表为准 |
| `showRss` | `config.xml` | ✗ | ✗ | ? | **零行** |
| `threadCount` | `config.xml` | ✗ | ✗ | ? | [书籍总账](BOOKSHELF.md) A2 = **1 行** |
| `mangaConfig` | `config.xml` | ✗ | ✗ | ? | **零行** |

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

### 判 `—` 的六类

`bookSource`、`rssSource`、`rssStar`、`sourceSub`、`httpTTS`、`server` 判不适用，理由统一：在线书源抓取、RSS 拉取、TTS 服务、WebDAV 在[项目队列](../PROJECT.md)的「范围之外」，明确写了「不因出现在页面或备份归档中而视为已实现」。这些条目仍会被原样归档（`copyPreservedEntries`），但**归档保留不等于功能兼容**。

### 判 `?` 的四类与一处待补

`themeMode`、`showRss`、`threadCount`、`mangaConfig` 只有 `preferenceKeysByCategory` 的键分组，没有独立的备份或恢复分支，实际效果取决于 `config.xml` 的整体搬运路径，需逐个键核对才能定论。其中 `themeMode` 已在 [深色模式总账](ZIP-THEME.md) F9 逐行核实：`createBackup` 的 `config.xml` 写出清单不含该键，恢复侧 `filterAndroidConfigXml` 只是原样保留，故读写两侧都判 `✗`，界面侧另见该表 C/D/F 三块。

`themeConfig` 的「写」也标 `?`：`createBackup` 里没有为它单独写 `themeConfig.json` 的分支，只有恢复侧 `:1041` 的忽略判断，是否需要补写出要看过上游 `ThemeConfigStore.configFileName` 的语义再定。**这一条已在 [深色模式总账](ZIP-THEME.md) F5 定论**：上游 `help/storage/Backup.kt:241-246` 明确用 `backupIgnoreThemeConfig` 门控写出 `ThemeConfigStore.configFileName`，本地应补写出分支，当前判 `未接`。

### 忽略项一列普遍为 `?`

本地 `isIgnored`（`:1539`）对 `bookshelf.json`、`config.xml` 恒返回 `false`，其余条目按 `categoryOptions.files` 反查类别键名。这个机制存在，但**每个类别的忽略语义是否与上游 `dbIsNotIgnored` 等价，尚未逐类核对**。`—` 只出现在三类：`localBook`（上游由 `backupIgnoreLocalBook` 单独控制，本地走 `localBook` 键过滤本地书）与两类无独立开关的配置项。

### 一处已知的上游差异

`directLinkUploadRule` 上游无独立忽略项（`help/storage/Backup.kt:248` 写该文件时不带任何门控），故本表不设此行，与上游一致。

## 明细表约定

明细表**不按类别拆文件**，而是按界面组织，一张表可承载多个类别：

| 表 | 块 | 承载的类别 |
| --- | --- | --- |
| [书籍总账](BOOKSHELF.md) | A1 / A2 / A3 / B / C / D | `localBook`、`bookshelfLayout`、`bookGroup`、`bookSource`、`readRecord`、`readConfig`、`threadCount`、`highlightTagRule`、`tagGroupRule` |
| [书架布局总账](ZIP-BOOKSHELF-LAYOUT.md) | A–F（r327 新增） | `bookshelfLayout`、`themeConfig`（A 块两个卡片底色行）。A1/A2 里与本表重叠的行以本表为准，A1/A2 其余行不受影响 |
| [书籍总账](BOOKSHELF.md) | E（r295 新增） | 无——备份恢复流程本身不受任何类别的忽略开关控制，12 行全记 `—` |
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
