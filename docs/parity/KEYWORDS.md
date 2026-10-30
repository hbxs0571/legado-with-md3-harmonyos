# ZIP 类别对照关键词

本表是[编码规约](../CODE-CONVENTIONS.md)第四节「模块对照必须一次盘完」的配套检索词表。盘点某个 ZIP 类别时，先用本表的关键词在上游源码里划出接触面，再出对照表。

单位说明见[术语表](../GLOSSARY.md)的 **ZIP 类别**与 **上游接触面**。类别键名与[备份恢复](../BACKUP-RESTORE.md)的忽略项一致。

## 用法

**`<上游根>` 的定义**（下文与本目录三张对照表的复现命令都用这个占位符）：本地 Android 源码根，即包含 `app/src/main/java` 的那一级目录，目录名 `legado-with-MD3`，**不含 `app/`**。

```
<上游根>/app/src/main/java      ← 检索起点
```

本机现有两份同源代码，任选其一，结果一致（2026-10-30 实测六类关键词命中数与命中行数完全相同）：

- `legado-with-MD3`：本地 Git 仓库，HEAD `bba5c64`，比 r258 移交点（`67970a1`）新 26 个提交
- `legado-n-transfer-2026-10-28-r258/unpacked/src01/legado-with-MD3`：r258 移交包里的工作树快照，不含 `.git`

在 `<上游根>` 下执行：

```
grep -rlE "<关键词>" app/src/main/java --include=*.kt
```

也可以直接用 [upstream-surface.sh](../../scripts/upstream-surface.sh)，它接受类别键名并输出文件集。

命中数是盘点的**起点**，不是终点：把文件集逐个打开确认引用方式（写入、读取、渲染、导航、配置），填进[兼容总账](STATUS.md)。

**不得用文件名枚举代替。** 按 `find -name` 只能拿到同名的那一批；书签类别按文件名 30 个、按内容引用 63 个。

## 类别与关键词

| 类别键名 | 上游检索关键词（ERE） | 命中数 | 上游代表文件 |
| --- | --- | --- | --- |
| `localBook` | `BookDao\|bookshelf\.json\|Book\.kt\|"localBook"` | 28 | `data/entities/Book.kt`、`data/dao/BookDao.kt` |
| `bookmark` | `Bookmark\|BookMarking\|"bookmark"` | 64 | `data/entities/Bookmark.kt`、`data/entities/BookMarking.kt` |
| `bookGroup` | `BookGroup\|"bookGroup"` | 41 | `data/entities/BookGroup.kt`、`ui/book/bookshelf/` |
| `bookSource` | `BookSource\|BookSourcePart\|"bookSource"` | 146 | `data/entities/BookSource.kt`、`ui/book/source/` |
| `rssSource` | `RssSource\|"rssSource"` | 60 | `data/entities/RssSource.kt`、`ui/rss/` |
| `rssStar` | `RssStar\|"rssStar"` | 15 | `data/entities/RssStar.kt` |
| `replaceRule` | `ReplaceRule\|"replaceRule"` | 62 | `data/entities/ReplaceRule.kt`、`ui/book/replace/` |
| `readRecord` | `ReadRecord\|ReadRecordDao\|"readRecord"` | 64 | `data/entities/readRecord/` |
| `searchHistory` | `SearchKeyword\|searchHistory\|"searchHistory"` | 13 | `data/entities/SearchKeyword.kt` |
| `sourceSub` | `RuleSub\|sourceSub\|"sourceSub"` | 18 | `data/entities/RuleSub.kt` |
| `txtTocRule` | `TxtTocRule\|"txtTocRule"` | 30 | `data/entities/TxtTocRule.kt` |
| `httpTTS` | `HttpTTS\|httpTtsVoices\|"httpTTS"` | 27 | `data/entities/HttpTTS.kt` |
| `keyboardAssists` | `KeyboardAssist\|"keyboardAssists"` | 8 | `data/entities/KeyboardAssist.kt` |
| `dictRule` | `DictRule\|"dictRule"` | 28 | `data/entities/DictRule.kt` |
| `homepageModules` | `HomepageModule\|"homepageModules"` | 25 | `data/entities/HomepageModule.kt` |
| `homepageCustomSets` | `HomepageCustomSet\|"homepageCustomSets"` | 8 | `data/entities/HomepageCustomSet.kt` |
| `highlightRule` | `HighlightRule\|HighlightRuleDao\|"highlightRule"` | 41 | `data/entities/HighlightRule.kt` |
| `highlightTagRule` | `HighlightTagRule\|"highlightTagRule"` | 23 | `data/entities/HighlightTagRule.kt` |
| `tagGroupRule` | `TagGroupRule\|"tagGroupRule"` | 23 | `data/entities/TagGroupRule.kt` |
| `server` | `Server\.kt\|serverDao\|servers\.json\|"server"` | 7 | `data/entities/Server.kt` |

## 只由 `config.xml` 承载的类别

下列类别没有独立 JSON 文件，全部是靠 `config.xml` 里的偏好键落地，因此关键词是**键名**而不是实体类名。键清单见 `entry/src/main/ets/data/BackupRepository.ets` 的 `preferenceKeysByCategory`；上游对应项见 `help/storage/BackupConfig.kt`。

| 类别键名 | 上游检索关键词（ERE） | 命中数 | 上游开关 | 本地键组 |
| --- | --- | --- | --- | --- |
| `readConfig` | `ReadBookConfig\|ReadSettings\|"readConfig"` | 78 | `backupIgnoreReadConfig` | `readConfig`（约 85 键） |
| `themeConfig` | `backupIgnoreThemeConfig\|"themeConfig"` | 3 | `backupIgnoreThemeConfig` | `themeConfig` |
| `coverConfig` | `backupIgnoreCoverConfig\|"coverConfig"` | 3 | `backupIgnoreCoverConfig` | `coverConfig` |
| `themeMode` | `themeMode\|"themeMode"` | 32 | 无独立开关 | `themeMode` |
| `bookshelfLayout` | `bookshelfLayout\|BookshelfLayout\|"bookshelfLayout"` | 10 | 无独立开关 | `bookshelfLayout` |
| `showRss` | `showRss\|"showRss"` | 12 | 无独立开关 | `showRss` |
| `threadCount` | `threadCount\|"threadCount"` | 23 | 无独立开关 | `threadCount` |
| `mangaConfig` | `mangaConfig\|comicStyleSelect\|"mangaConfig"` | 6 | 无独立开关 | `mangaConfig` |

**`readConfig` 的关键词不能用开关名**。上游的 `backupIgnoreReadConfig` 只命中 2 个 `.kt`（含 `help/storage/BackupConfig.kt`），拿它当接触面等于「2 个文件全过」，覆盖证明永远自证成功。该类真正的接触面是两份配置声明：`help/config/ReadBookConfig.kt`（单本书可覆盖）与 `domain/model/settings/ReadSettings.kt`（全书统一设置，114 字段），合计声明 267 个名字，`ReadBookConfig|ReadSettings|"readConfig"` 命中 78 个文件。`backupIgnoreReadConfig` 仍作为**忽略项开关**记录在「上游开关」列，与检索关键词不是一回事。

盘这八类时，把 `BackupConfig.kt` 与 `AppConfigStore` 的键定义当作接触面入口。前三个类别的上游开关是布尔项，关键词本身就是开关名；后五个没有独立开关，关键词是偏好键名。

## 存储层维度：为什么每个类别都要带上键名字面量

上表 28 个类别的关键词里，除了实体类名（`Bookmark`、`BookGroup`…）之外，**每个都还带了一段小写的键名字面量**，例如 `bookmark` 类别是 `Bookmark\|BookMarking\|"bookmark"`。这一段不是冗余，它对应上游的第二个维度：

上游把「类别」同时用作两种东西——**实体类名**（`data/entities/` 里的 Kotlin 类）和**忽略项键名字符串**（`help/storage/BackupConfig.kt:76-95` 的 `dbKeyBookmark = "bookmark"`、`dbKeyBookGroup = "bookGroup"` 等，共 19 个 `dbKey*` 常量；另有 `readConfigKey`、`themeConfigKey`、`coverConfigKey`、`localBookKey`、`mangaKey` 五个配置类键）。导出与恢复主文件只认后者：

```kotlin
// help/storage/Backup.kt:157
if (BackupConfig.dbIsNotIgnored("bookmark")) writeListToJson(appDb.bookmarkDao.all, "bookmark.json", backupPath)
```

`Backup.kt` 与 `Restore.kt` 里**一个实体类名都不出现**，19 个类别全以小写字符串引用。因此只按实体类名选词时，这两个文件对 15 个类别是隐身的——`bookmark` 类别旧关键词在 `Backup.kt` 命中 0 行，而它恰恰是该类别导出逻辑的唯一所在地。

**这是一个已经在项目里发作过的失效模式**，与 `readConfig` 那次是同一类错误的不同方向：

| 曾经的问题 | 关键词选法 | 后果 |
| --- | --- | --- |
| `readConfig` 用开关名 `backupIgnoreReadConfig` | 只命中 2 个 `.kt` | 「2 个文件全过」，覆盖证明永远自证成功 |
| 20 个数据类别的关键词只有实体类名 | `Backup.kt` / `Restore.kt` 不在接触面内 | 导出/恢复逻辑永远盘不到，而表格会显示覆盖证明通过 |

补上键名字面量后，各类别接触面的实测变化（全上游 1771 个 `.kt`）：

| 类别 | 补前 | 补后 | 类别 | 补前 | 补后 |
| --- | --- | --- | --- | --- | --- |
| `localBook` | 27 | 28 | `readRecord` | 63 | 64 |
| `bookmark` | 63 | 64 | `searchHistory` | 13 | 13 |
| `bookGroup` | 40 | 41 | `sourceSub` | 18 | 18 |
| `bookSource` | 141 | 146 | `txtTocRule` | 29 | 30 |
| `rssSource` | 58 | 60 | `httpTTS` | 24 | 27 |
| `rssStar` | 14 | 15 | `keyboardAssists` | 7 | 8 |
| `replaceRule` | 60 | 62 | `dictRule` | 26 | 28 |
| `homepageModules` | 23 | 25 | `highlightRule` | 40 | 41 |
| `homepageCustomSets` | 7 | 8 | `highlightTagRule` | 22 | 23 |
| `tagGroupRule` | 22 | 23 | `server` | 6 | 7 |
| `readConfig` | 76 | 78 | `themeConfig` / `coverConfig` | 2 | 3 |

（`bookshelfLayout`、`themeMode`、`showRss`、`threadCount`、`mangaConfig` 五类的原关键词本身已含小写键名，补后不变。）

补完后六类覆盖证明的实际变化：`bookmark` 63→64、`bookGroup` 40→41、`localBook` 27→28、`readRecord` 63→64 全部仍通过（新纳入的 `Backup.kt` / `BackupConfig.kt` 已在表格里被其他行提到）；`readConfig` 76→78 暴露 1 个未分配（`ui/config/ConfigTag.kt`，其 `READ_CONFIG = "readConfig"` 只是页面路由标签，不是备份逻辑，已写进该表的「已排除」节）；`bookshelfLayout` 10→10 不变。

`bookSource` 不在六类覆盖证明之内（旧关键词 141 个接触面、新 146 个，其中 105 个未分配），本轮不因关键词改动而新增结论。

## 存储层里仍然隐身的那一批（关键词治不了，必须单独开块）

补了键名字面量之后，备份恢复层 22 个文件里仍有 **18 个对全部 28 类零命中**，且这些零命中不是关键词选法问题——它们的代码里根本没有类别概念：

| 文件 | 行数 | 承载什么 |
| --- | --- | --- |
| `help/storage/BookRestorePlanner.kt` | 172 | `BookRestorePlan(booksToUpdate, booksToInsert, booksToDelete)`、`isRelocatedCopyOf`、`LocalBookLocationStatus` 三态、`normalizeLocalBookLocation` —— **恢复期语义全在这里** |
| `help/storage/RestoreConfigNormalizer.kt` | 59 | `config.xml` 原始键值的规整（AES 解密、Double→Float、旧键拆补写、过滤忽略键） |
| `help/storage/ImportOldData.kt` | 370 | 旧版 `myBookShelf.json` / `myBookSource.json` / `myBookReplaceRule.json` 导入 |
| `help/storage/BackupAES.kt` / `BackupRestoreLock.kt` | 11 / 16 | 压缩包加解密、并发互斥 |
| `ui/config/backupConfig/` 5 个文件 | 545 + 415 + 98 + 71 + 21 | 备份设置界面、忽略项页签、WebDAV 选项面板 |
| `data/repository/BackupRestoreRepository.kt`、`WebDavBackupRepository.kt` | 25 / 57 | 本地与 WebDAV 的备份落盘 |
| `domain/` 下的 7 个 gateway / model / usecase | 7–42 | 备份恢复的接口与模型 |

这批文件的共同点是**它们处理的是「所有类别一起」的动作**（规划整批书目、规整整份配置、加解密整个压缩包），所以任何单个类别名都不会出现在里面。按类别派活永远覆盖不到它们。

处置方式：不再往关键词表里硬塞，而是在界面级对照表里**单独开一个「备份恢复」块**，整块承载这 18 个文件。`BookRestorePlanner.kt` 这类恢复期语义正是靠这个块才第一次进入盘点视野。

已落地：`BOOKSHELF.md` 的 **E 备份恢复**块（r295 新增 12 行）。该块用 12 行覆盖 21 个文件里最关键的部分，其余纯数据类/空壳由各行「上游位置」列一并引用。

## 已知上游无独立忽略项的条目

- `directLinkUploadRule`：`help/storage/Backup.kt:248` 写 `DirectLinkUpload.ruleFileName` 时不带任何 `dbIsNotIgnored` 门控，也不受三个 `backupIgnore*` 开关控制。本地备份选项表不含此项，与上游一致，不是缺口。

## 维护

新增类别时同步改三处：本表、[兼容总账](STATUS.md)、`BackupRepository.ets` 的 `categoryOptions`。三者用同一套键名。
