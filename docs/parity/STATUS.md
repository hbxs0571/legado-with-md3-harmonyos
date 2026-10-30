# ZIP 兼容总账

本表按 ZIP 数据类别记录 Android 备份兼容度，共 28 类，键名与[备份恢复](../BACKUP-RESTORE.md)的忽略项一致，检索词见[对照关键词](KEYWORDS.md)。

类别是兼容度的计量单位：做完一类就是前进一格，可以数得清。术语见[术语表](../GLOSSARY.md)的 **ZIP 类别**、**上游接触面**、**盘点**。盘点方法见[编码规约](../CODE-CONVENTIONS.md)第四节。

## 兼容度三级

三级都过才算这一类兼容。

1. **读**：上游写出的 ZIP 条目能被本地恢复，数据落到原生仓储（不是只原样归档）。
2. **写**：本地能写出同条目，上游读回不报错、数据不丢字段。
3. **忽略项**：上游该类的 `dbIsNotIgnored` 开关在本地有对应语义，至少在恢复时能跳过。

## 取值

| 记号 | 含义 |
| --- | --- |
| `✓` | 已达，且已核实到具体代码位置 |
| `✗` | 未达，差距写在明细表 |
| `—` | 不适用，理由必写（通常是[项目队列](../PROJECT.md)的范围之外） |
| `?` | 未盘，尚未逐个文件核对 |

**本表当前是骨架，不是盘点结论。** 下方状态依据「实测」一栏来自 2026-10-29 对 `entry/src/main/ets/data/BackupRepository.ets` 的代码核实（具名恢复分支只有 7 个类别：`bookshelf.json`、`config.xml`、`bookGroup.json`、`replaceRule.json`、`txtTocRule.json`、`highlightRule.json`、`bookmark.json`/`bookMarking.json`；其余条目仅由 `copyPreservedEntries` 原样归档）。**逐类盘点尚未开始，`?` 是真实状态，不得当作已接。**

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
| `themeConfig` | `themeConfig.json`、`config.xml` | ✓ | ? | ? | 待建 |
| `coverConfig` | `coverRule.json`、`config.xml` | ✗ | ✗ | ? | 待建 |
| `themeMode` | `config.xml` | ? | ? | — | 待建 |
| `bookshelfLayout` | `config.xml` | ✓ | ✓ | ? | [书架对照表](BOOKSHELF.md) A2 |
| `showRss` | `config.xml` | ? | ? | — | 待建 |
| `threadCount` | `config.xml` | ? | ? | — | 待建 |
| `mangaConfig` | `config.xml` | ? | ? | — | 待建 |

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
