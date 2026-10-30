# ZIP 类别对照关键词

本表是[编码规约](../CODE-CONVENTIONS.md)第四节「模块对照必须一次盘完」的配套检索词表。盘点某个 ZIP 类别时，先用本表的关键词在上游源码里划出接触面，再出对照表。

单位说明见[术语表](../GLOSSARY.md)的 **ZIP 类别**与 **上游接触面**。类别键名与[备份恢复](../BACKUP-RESTORE.md)的忽略项一致。

## 用法

在上游仓库根目录执行（`legado-with-MD3` 为 Android 源码根）：

```
grep -rlE "<关键词>" app/src/main/java --include=*.kt
```

也可以直接用 [upstream-surface.sh](../../scripts/upstream-surface.sh)，它接受类别键名并输出文件集。

命中数是盘点的**起点**，不是终点：把文件集逐个打开确认引用方式（写入、读取、渲染、导航、配置），填进[兼容总账](STATUS.md)。

**不得用文件名枚举代替。** 按 `find -name` 只能拿到同名的那一批；书签类别按文件名 30 个、按内容引用 63 个。

## 类别与关键词

| 类别键名 | 上游检索关键词（ERE） | 命中数 | 上游代表文件 |
| --- | --- | --- | --- |
| `localBook` | `BookDao\|bookshelf\.json\|Book\.kt` | 27 | `data/entities/Book.kt`、`data/dao/BookDao.kt` |
| `bookmark` | `Bookmark\|BookMarking` | 63 | `data/entities/Bookmark.kt`、`data/entities/BookMarking.kt` |
| `bookGroup` | `BookGroup` | 40 | `data/entities/BookGroup.kt`、`ui/book/bookshelf/` |
| `bookSource` | `BookSource\|BookSourcePart` | 141 | `data/entities/BookSource.kt`、`ui/book/source/` |
| `rssSource` | `RssSource` | 58 | `data/entities/RssSource.kt`、`ui/rss/` |
| `rssStar` | `RssStar` | 14 | `data/entities/RssStar.kt` |
| `replaceRule` | `ReplaceRule` | 60 | `data/entities/ReplaceRule.kt`、`ui/book/replace/` |
| `readRecord` | `ReadRecord\|ReadRecordDao` | 63 | `data/entities/readRecord/` |
| `searchHistory` | `SearchKeyword\|searchHistory` | 13 | `data/entities/SearchKeyword.kt` |
| `sourceSub` | `RuleSub\|sourceSub` | 18 | `data/entities/RuleSub.kt` |
| `txtTocRule` | `TxtTocRule` | 29 | `data/entities/TxtTocRule.kt` |
| `httpTTS` | `HttpTTS\|httpTtsVoices` | 24 | `data/entities/HttpTTS.kt` |
| `keyboardAssists` | `KeyboardAssist` | 7 | `data/entities/KeyboardAssist.kt` |
| `dictRule` | `DictRule` | 26 | `data/entities/DictRule.kt` |
| `homepageModules` | `HomepageModule` | 23 | `data/entities/HomepageModule.kt` |
| `homepageCustomSets` | `HomepageCustomSet` | 7 | `data/entities/HomepageCustomSet.kt` |
| `highlightRule` | `HighlightRule\|HighlightRuleDao` | 40 | `data/entities/HighlightRule.kt` |
| `highlightTagRule` | `HighlightTagRule` | 22 | `data/entities/HighlightTagRule.kt` |
| `tagGroupRule` | `TagGroupRule` | 22 | `data/entities/TagGroupRule.kt` |
| `server` | `Server\.kt\|serverDao\|servers\.json` | 6 | `data/entities/Server.kt` |

## 只由 `config.xml` 承载的类别

下列类别没有独立 JSON 文件，全部是靠 `config.xml` 里的偏好键落地，因此关键词是**键名**而不是实体类名。键清单见 `entry/src/main/ets/data/BackupRepository.ets` 的 `preferenceKeysByCategory`；上游对应项见 `help/storage/BackupConfig.kt`。

| 类别键名 | 上游检索关键词（ERE） | 命中数 | 上游开关 | 本地键组 |
| --- | --- | --- | --- | --- |
| `readConfig` | `ReadBookConfig\|ReadSettings` | 76 | `backupIgnoreReadConfig` | `readConfig`（约 85 键） |
| `themeConfig` | `backupIgnoreThemeConfig` | — | `backupIgnoreThemeConfig` | `themeConfig` |
| `coverConfig` | `backupIgnoreCoverConfig` | — | `backupIgnoreCoverConfig` | `coverConfig` |
| `themeMode` | `themeMode` | 32 | 无独立开关 | `themeMode` |
| `bookshelfLayout` | `bookshelfLayout\|BookshelfLayout` | 10 | 无独立开关 | `bookshelfLayout` |
| `showRss` | `showRss` | 12 | 无独立开关 | `showRss` |
| `threadCount` | `threadCount` | 23 | 无独立开关 | `threadCount` |
| `mangaConfig` | `mangaConfig\|comicStyleSelect` | 6 | 无独立开关 | `mangaConfig` |

**`readConfig` 的关键词不能用开关名**。上游的 `backupIgnoreReadConfig` 只命中 2 个 `.kt`（含 `help/storage/BackupConfig.kt`），拿它当接触面等于「2 个文件全过」，覆盖证明永远自证成功。该类真正的接触面是两份配置声明：`help/config/ReadBookConfig.kt`（单本书可覆盖）与 `domain/model/settings/ReadSettings.kt`（全书统一设置，114 字段），合计声明 267 个名字，`ReadBookConfig|ReadSettings` 命中 76 个文件。`backupIgnoreReadConfig` 仍作为**忽略项开关**记录在「上游开关」列，与检索关键词不是一回事。

盘这八类时，把 `BackupConfig.kt` 与 `AppConfigStore` 的键定义当作接触面入口。前三个类别的上游开关是布尔项，关键词本身就是开关名；后五个没有独立开关，关键词是偏好键名。

## 已知上游无独立忽略项的条目

- `directLinkUploadRule`：`help/storage/Backup.kt:248` 写 `DirectLinkUpload.ruleFileName` 时不带任何 `dbIsNotIgnored` 门控，也不受三个 `backupIgnore*` 开关控制。本地备份选项表不含此项，与上游一致，不是缺口。

## 维护

新增类别时同步改三处：本表、[兼容总账](STATUS.md)、`BackupRepository.ets` 的 `categoryOptions`。三者用同一套键名。
