# ZIP 兼容总账

> **本目录已解冻（2026-10-30，r284），三张表已完成结构性重盘（r286）**
>
> `STATUS.md`、`BOOKSHELF.md`、`ZIP-BOOKMARK.md`、`READER-CONFIG.md` 四份对照表可编辑。
>
> **解冻依据**：[关系型存储迁移计划](../RELATIONAL-STORE-MIGRATION.md) 五个阶段全部完工（基础设施与前三批仓储 r281–r283，preferences 清理 r284），字段结构已定稿。原先的冲突——`book_marks` 的 7 个平铺列（`chapterPosition`、`endPosition`、`selectedText`、`contextBefore`、`contextAfter`、`effect`、`color`）要被合并成 `anchorJson` 与 `styleJson`——已经落地。
>
> **重盘范围与边界（r286，2026-10-30）**：三张表做的是**结构性重盘**，不是逐行重核。已做四件事：
>
> 1. **盘点单位改为「整个界面」**：只要涉及某界面就把它完整列进表，未迁移的显式标 `未接`。`ZIP-BOOKMARK.md` 因此新增 F 块（长按选词菜单 34 行），`BOOKSHELF.md` 因此新增 D 块（缓存管理页 + 书架管理页 53 行）。
> 2. **修正迁移后失效的字段引用**：`progress` 改派生、`readerPositionVersion` / `androidCharacterPosition` / `bookId` / `endPosition` 已删、`styleJson` 不再拍平、`double` 已删除、`preferences` → SQLite 两张表。
> 3. **三张表各补「覆盖证明」节**，逐个分配上游接触面文件，未分配为 0：`bookmark` 63/63、`readConfig` 76/76、`localBook` 27/27、`bookGroup` 40/40、`readRecord` 63/63、`bookshelfLayout` 10/10。
> 4. **`KEYWORDS.md` 的 `readConfig` 关键词修正**：`backupIgnoreReadConfig` 只命中 2 个文件（等于自证成功），改为 `ReadBookConfig|ReadSettings`（76 个）。
>
> **未做的部分，读表时注意**：`BOOKSHELF.md` A1–C 的 263 行、`READER-CONFIG.md` A–G 的 189 行、`ZIP-BOOKMARK.md` A–E 的 83 行，都是 r277–r280 写下的**迁移前证据，未逐行复核**。表头已逐份写明这一边界。要当当前事实用，需按上游目录分派逐块重核——那时按 `scripts/upstream-surface.sh --coverage` 的未分配清单验收，不靠「表里没有 `待定`」结案。
>
> 解冻不影响 `KEYWORDS.md`（检索词表）——它是生成接触面清单的依据，改关键词等于改口径，改前先看该文件末尾的说明。

本表按 ZIP 数据类别记录 Android 备份兼容度，共 28 类，键名与[备份恢复](../BACKUP-RESTORE.md)的忽略项一致，检索词见[对照关键词](KEYWORDS.md)。

类别是兼容度的计量单位：做完一类就是前进一格，可以数得清。术语见[术语表](../GLOSSARY.md)的 **ZIP 类别**、**上游接触面**、**盘点**、**覆盖证明**。盘点方法见[编码规约](../CODE-CONVENTIONS.md)第四节。

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

| 类别键名 | 条目 | 读 | 写 | 忽略项 | 明细表 |
| --- | --- | --- | --- | --- | --- |
| `localBook` | `bookshelf.json` | ✓ | ✓ | — | [书籍总账](BOOKSHELF.md) |
| `bookmark` | `bookmark.json`、`bookMarking.json` | ✓ | ✓ | ? | [书签/划线/笔记对照](ZIP-BOOKMARK.md) |
| `bookGroup` | `bookGroup.json` | ✓ | ✓ | ? | [书架对照表](BOOKSHELF.md) A3 |
| `bookSource` | `bookSource.json` | — | — | — | 待建 |
| `rssSource` | `rssSources.json` | — | — | — | 待建 |
| `rssStar` | `rssStar.json` | — | — | — | 待建 |
| `replaceRule` | `replaceRule.json` | ✓ | ✓ | ? | 待建 |
| `readRecord` | `readRecord.json`、`readRecordDetail.json`、`readRecordSession.json` | ✗ | ✗ | ? | [书架对照表](BOOKSHELF.md) C |
| `searchHistory` | `searchHistory.json` | ✗ | ✗ | ? | 待建 |
| `sourceSub` | `sourceSub.json` | — | — | — | 待建 |
| `txtTocRule` | `txtTocRule.json` | ✓ | ✓ | ? | 待建 |
| `httpTTS` | `httpTTS.json`、`httpTtsVoices.json` | — | — | — | 待建 |
| `keyboardAssists` | `keyboardAssists.json` | ✗ | ✗ | ? | 待建 |
| `dictRule` | `dictRule.json` | ✗ | ✗ | ? | 待建 |
| `homepageModules` | `homepageModules.json` | ✗ | ✗ | ? | 待建 |
| `homepageCustomSets` | `homepageCustomSets.json` | ✗ | ✗ | ? | 待建 |
| `highlightRule` | `highlightRule.json` | ✓ | ✓ | ? | 待建 |
| `highlightTagRule` | `highlightTagRule.json` | ✗ | ✗ | ? | 待建 |
| `tagGroupRule` | `tagGroupRule.json` | ✗ | ✗ | ? | 待建 |
| `server` | `servers.json` | — | — | — | 待建 |
| `readConfig` | `readConfig.json`、`shareReadConfig.json`、`config.xml` | ✓ | ✓ | ? | [阅读配置总账](READER-CONFIG.md) |
| `themeConfig` | `themeConfig.json`、`config.xml` | ✓ | ✗ | ? | 待建 |
| `coverConfig` | `coverRule.json`、`config.xml` | ✗ | ✗ | ? | 待建 |
| `themeMode` | `config.xml` | ✗ | ✗ | ? | 待建 |
| `bookshelfLayout` | `config.xml` | ✗ | ✓ | ? | [书架对照表](BOOKSHELF.md) A2 |
| `showRss` | `config.xml` | ✗ | ✗ | ? | 待建 |
| `threadCount` | `config.xml` | ✗ | ✗ | ? | 待建 |
| `mangaConfig` | `config.xml` | ✗ | ✗ | ? | 待建 |

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

其余条目走 `:822` 的兜底 `fileIo.copyFile`，只进保留目录，不落原生仓储。因此 `readRecord`、`searchHistory`、`keyboardAssists`、`dictRule`、`homepageModules`、`homepageCustomSets`、`highlightTagRule`、`tagGroupRule`、`coverConfig` 判 `✗`，不是「没查」，而是「查过、确认未接」。

### 判 `—` 的六类

`bookSource`、`rssSource`、`rssStar`、`sourceSub`、`httpTTS`、`server` 判不适用，理由统一：在线书源抓取、RSS 拉取、TTS 服务、WebDAV 在[项目队列](../PROJECT.md)的「范围之外」，明确写了「不因出现在页面或备份归档中而视为已实现」。这些条目仍会被原样归档（`copyPreservedEntries`），但**归档保留不等于功能兼容**。

### 判 `?` 的四类与一处待补

`themeMode`、`showRss`、`threadCount`、`mangaConfig` 只有 `preferenceKeysByCategory` 的键分组，没有独立的备份或恢复分支，实际效果取决于 `config.xml` 的整体搬运路径，需逐个键核对才能定论。

`themeConfig` 的「写」也标 `?`：`createBackup` 里没有为它单独写 `themeConfig.json` 的分支，只有恢复侧 `:1041` 的忽略判断，是否需要补写出要看过上游 `ThemeConfigStore.configFileName` 的语义再定。

### 忽略项一列普遍为 `?`

本地 `isIgnored`（`:1539`）对 `bookshelf.json`、`config.xml` 恒返回 `false`，其余条目按 `categoryOptions.files` 反查类别键名。这个机制存在，但**每个类别的忽略语义是否与上游 `dbIsNotIgnored` 等价，尚未逐类核对**。`—` 只出现在三类：`localBook`（上游由 `backupIgnoreLocalBook` 单独控制，本地走 `localBook` 键过滤本地书）与两类无独立开关的配置项。

### 一处已知的上游差异

`directLinkUploadRule` 上游无独立忽略项（`help/storage/Backup.kt:248` 写该文件时不带任何门控），故本表不设此行，与上游一致。

## 明细表约定

每类一张 `docs/parity/ZIP-<大写键名>.md`，例如 `ZIP-BOOKMARK.md`。**本轮不建空表**，因为空表会被误认为已盘点。

明细表每行以一次用户可感知的操作为粒度，七列：

`上游能力 | 上游位置(文件:行) | 本地位置(文件:行) | 状态 | 差异说明 | 验收方式 | 备注`

状态只允许 `已接` / `未接` / `不适用` / `待定` 四值。`不适用` 必须写理由，`待定` 必须写阻塞项，**盘点结束时不得残留 `待定`**。

## 维护

改本表时同步改[对照关键词](KEYWORDS.md)与 `BackupRepository.ets` 的 `categoryOptions`，三者用同一套键名。检索接触面用 `scripts/upstream-surface.sh <类别键名>`，它只打印清单，不生成表格。

**盘点单位是界面，不是按钮**：盘某个功能时，只要涉及某个界面（进了这个页、开了这个弹层、这个界面被改动），就要把该界面的完整构成列进表，未迁移的显式标 `未接`，不只列与本功能相关的按钮。定义与反例见[术语表](../GLOSSARY.md)的 **界面清单**、[编码规约](../CODE-CONVENTIONS.md)第四节。

**每轮盘点结束必须当轮落盘，并重跑覆盖证明**：明细表写完就跑 `scripts/upstream-surface.sh --coverage <类别> <表格路径>`，未分配不为 0 就是没盘完；「表里没有 `待定`」只证明表格自洽，不证明上游被覆盖。
