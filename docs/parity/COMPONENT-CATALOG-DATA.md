# 本地后端清单（数据层 / 阅读引擎 / 书源引擎 / 平台库）

> 用途：写 `data/`、`reader/`、`bookSource/` 的代码之前，先在这里找一遍，别重造。
> 基线：`<workspace>/legado-with-md3-harmonyos` 工作区。
> **来源与保鲜期**：2026-11-23 从本机临时清单转入仓库（原文件在工作区 `tmp/`，不入库）；文件数与行数是当日 02:26 的快照，当日下午复算已变成 `data/` 136 文件 41,311 行、`bookSource/` 24 文件 4,493 行、合计 209 文件 59,173 行——下一节表里的 135 / 23 / 207 是快照值，不是当前值。行号同样会漂，用前 `grep -n` 复核。
> 前端组件见另一份 [本地前端组件清单](COMPONENT-CATALOG-UI.md)。

## 〇、三条读法

1. **先看域，再看类。** 后端 207 个文件 / 58,566 行分四个子域（下一节）。找东西先定位子域，再在子域里 `grep`。
2. **类名不等于职责。** `BackupRepository` 3,789 行不只是备份、`EpubRepository` 1,283 行不只是 epub——大文件里往往是整个域的堆积。用之前 `grep -n 'struct \|class \|async \|^  [a-zA-Z]'` 看它到底有哪些方法。
3. **「上游等价物」写 `未查到` 的，是我没做对照，不是上游没有。** 判它有没有要读上游那个域的源码。

---

## 一、四个子域与体量（实测）

| 子域 | 文件 | 行数 | 里面是什么 | 什么时候会去 |
| --- | --- | --- | --- | --- |
| `data/` | 135 | 40,904 | 持久化与领域数据：书、分组、章节、各类设置、备份恢复、封面、阅读记录、知识卡、主题包、EPUB | 几乎任何「数据存哪 / 从哪读」的问题 |
| `reader/` | 40 | 11,916 | 阅读渲染引擎：分章、排版几何、Canvas 绘制、页面缓存。最大一份 `ReaderCanvasSurface.ets`(3,572) | 正文渲染、翻页、行距字距、章末留白 |
| `bookSource/` | 23 | 4,293 | 在线书源引擎 P1–P11 + 脚本运行时桥接（JS 解释器在 `third_party/harmony-book-source-engine/quickjs/`） | 书源规则解析、搜索/详情/目录/正文、调试 |
| `lib/` | 9 | 1,453 | 平台基础设施：日志、WebDAV、通用工具 | 日志、云备份、跨域小工具 |

`data/` 里超过 900 行的六份（改之前先有心理准备）：`BookRepository.ets` 3,897 · `BackupRepository.ets` 3,789 · `ReaderSettingsRepository.ets` 2,141 · `ReadRecordRepository.ets` 1,373 · `EpubRepository.ets` 1,283 · `ThemePackageRepository.ets` 1,221。

**`reader/` 是纯渲染侧，`data/` 是纯数据侧，两者不互相 import 对方的页面逻辑**——改渲染别去动 `data/`，反之亦然。

---

## 二、数据层（本地这一层基本是齐的，动手前先读）

| 类 | 定义 | 上游等价物 | 用于 |
| --- | --- | --- | --- |
| `BookRepository` | `data/BookRepository.ets:186`（3,897 行） | `BookshelfViewModel.kt:1436`（30 个 public fun）+ `BookViewModel.kt`（**未逐条对照**） | 书的增删改、章节、进度、排序持久化。`saveBookOrder` 在 `:1794`（`:1789` 注释写「与上游 `BookshelfViewModel.saveBookOrder` 一致：倒序 `maxOrder - index`，正序 `index + 1`」） |
| `BookGroupRepository` | `data/BookGroupRepository.ets:27`（562 行） | `BookshelfViewModel.kt` 分组部分（**未逐条对照**） | 18 个对外方法：`getAll` / `getVisibleUserGroups` / `load` / `migrateFromPreferences` / `importAndroidFile` / `add` / `addWithDraft` / `updateSettings` / `setCover` / `chooseCover` / `clearCover` / `move` / `rename` / `setVisible` / `remove` / `namesFromMask` / `maskFromNames` / `loadLegacy` |
| `BookshelfSort` | `data/BookshelfSort.ets:11`（85 行） | `BookshelfViewModel.kt` 排序部分（未对照） | 书架排序规则 |
| `BookshelfLayoutRepository` | `data/BookshelfLayoutRepository.ets:14`（433 行） | `BookshelfConfigSheet.kt:52`（配置项的持久化侧） | 显示模式、列数、封面样式等布局键 |
| `BookshelfListTransfer` | `data/BookshelfListTransfer.ets:21`（137 行） | `BookshelfViewModel.kt` 导入导出 | `toJson` / `exportList` / `selectAndParse` / `toBooks` |
| `ReadRecordRepository` | `data/ReadRecordRepository.ets:35`（1,373 行） | **未查到** | 阅读记录、热力图数据源（`dailyReadCounts` / `dailyReadTimes` 由它供） |
| `ReaderSettingsRepository` | `data/ReaderSettingsRepository.ets:807` | `ReadSettings.kt:40`（含 `themeGridColumns` 等键） | 阅读设置快照（`ReaderSettingsSnapshot:149`）、内边距、底部动作、背景样式 |
| `ReaderSelectionMenu` | `data/ReaderSelectionMenu.ets:13` | **未查到** | 划词菜单项接口（`ReaderSelectionMenuItem`）。配置项与上游的对应见 `tmp/un90-impl-prompt.md` 批 1 |
| `CoverSettingsRepository` | `data/CoverSettingsRepository.ets:111` | `CoverSettings.kt`（`BookCover.ets:77` 注释引 `:6-10`） | 封面显示参数（`CoverSettings:13`）、Android 封面偏好导入（`AndroidCoverPreference:247`） |
| `CoverRuleRepository` | `data/CoverRuleRepository.ets:75` | **未查到** | 封面规则（`CoverRule:22`） |
| `CoverAlbumRepository` | `data/CoverAlbumRepository.ets:71` | **未查到** | 更换封面的图集（`CoverAlbumItem:48` / `CoverAlbumImageItem:38`） |
| `BookInfoSettingsRepository` | `data/BookInfoSettings.ets:19` | **未查到** | 详情页自身的设置（`BookInfoSettings:10`） |
| `BookInfoBackdropStyle` | `data/BookInfoBackdropStyle.ets:12` | `BookInfoBackdropStyle.kt`（同名，**未逐条对照**） | 详情页背景样式 |
| `BookKnowledgeRepository` | `data/BookKnowledgeRepository.ets:178` | **未查到** | 角色卡 / 关系网 / 知识卡 / 事件卡 / 大纲（5 个接口 + 4 个 `New*` 写入） |
| `BackupRepository` | `data/BackupRepository.ets:438` | **未查到** | 备份与恢复（`BackupSelection:92` / `RestoreResult:117` / `BackupArchiveEntry`） |
| `BookmarkListSettingsRepository` | `data/BookmarkListSettings.ets:16` | **未查到** | 书签列表设置 |
| `CacheSettingsRepository` / `CacheStatsRepository` | `data/CacheSettingsRepository.ets:77` / `data/CacheStatsRepository.ets:21` | **未查到** | 缓存设置与统计（`BookCacheStat:14`） |
| `BookSourceRepository` / `BookSourceImporter` | `data/BookSourceRepository.ets:31` / `data/BookSourceImporter.ets:52` | `BookSourceViewModel.kt` | 书源存取与导入（`BookSourceImportOutcome:8` / `BookSourceImportKeep:18`） |
| `AppFontLibrary` | `data/AppFontLibrary.ets:87` | `FontSelectGrid.kt` | 应用字体扫描与排序（`AppFontEntry:63` / `AppFontScan:81`） |
| `ArchiveImporter` | `data/ArchiveImporter.ets:28` | **未查到** | 压缩包导入（`ExtractedArchive:21`） |
| `BookContentProcessEngine` / `BookContentProcessRepository` | `data/BookContentProcessEngine.ets:23` / `data/BookContentProcessRepository.ets:14` | **未查到** | 正文处理规则执行与存储 |

---

## 三、平台与基础设施库

| 类 | 定义 | 用途 |
| --- | --- | --- |
| `AppLog` | `lib/AppLog.ets:40` | 环形日志缓冲（`AppLogEntry:18`）。`BookshelfPage` 的 `LogSheet` 读它 |
| `WebDav` | `lib/WebDav.ets:67` | WebDAV 客户端（`WebDavEntry:18` / `WebDavError:35`） |
| `WebDavConfigStore` | `lib/WebDavConfig.ets:110` | WebDAV 配置存取（`WebDavSettings:13`） |
| `WebDavSync` | `lib/WebDavSync.ets:40` | 备份同步（`WebDavTestResult:21` / `WebDavBackupInfo:26`） |

---

## 四、按功能查（先看这张，别从文件名猜）

| 想做的事 | 去哪 | 依据 |
| --- | --- | --- |
| 书架排序公式 | `data/BookshelfSort.ets:11`，以及 `data/BookRepository.ets:1794` `saveBookOrder`（`:1789` 注释写「与上游 `BookshelfViewModel.saveBookOrder` 一致：倒序 `maxOrder - index`，正序 `index + 1`」） | 实测存在；调用方 `pages/Index.ets:8576` |
| 分组增删改、mask 往返 | `data/BookGroupRepository.ets:27`（18 个对外方法，含 `namesFromMask` / `maskFromNames`） | 实测 |
| 书的增删、章节、进度 | `data/BookRepository.ets:186`（3,897 行）；正文分章在 `reader/` | 实测。**注意**：`BookRepository` 也管排序与刷新，不只有增删 |
| 阅读记录 / 热力图数据 | `data/ReadRecordRepository.ets:35`（1,373 行） | 实测。前端 `ReadRecordHeatmap` 的 `dailyReadCounts` / `dailyReadTimes` 由它供 |
| 缓存统计与设置 | `data/CacheStatsRepository.ets:21` / `data/CacheSettingsRepository.ets:77` | 实测 |
| 封面显示参数 / 规则 / 图集 | `data/CoverSettingsRepository.ets:111` / `data/CoverRuleRepository.ets:75` / `data/CoverAlbumRepository.ets:71` | 实测。上游对应 `CoverSettings.kt`（`BookCover.ets:77` 注释引 `:6-10`） |
| 备份与恢复 | `data/BackupRepository.ets:438`（3,789 行）；云同步 `lib/WebDavSync.ets:40` / `lib/WebDav.ets:67` | 实测 |
| 主题包 / 卡片样式 | `data/ThemePackageRepository.ets`(1,221) / `data/ThemeCardStyle.ets:17` | 实测。分组圆角的计算在 `ThemeCardStyle.ets:136` `resolveGroupCornerRadius()` |
| 应用字体 | `data/AppFontLibrary.ets:87`（`AppFontEntry:63` / `AppFontScan:81`） | 实测 |
| 知识卡 / 角色卡 / 关系网 | `data/BookKnowledgeRepository.ets:178`（5 个接口 + 4 个 `New*` 写入） | 实测 |
| 正文处理规则 | `data/BookContentProcessEngine.ets:23` / `data/BookContentProcessRepository.ets:14` | 实测 |
| EPUB 解析 / 写出 | `data/EpubRepository.ets`(1,283)；写出侧另有 `data/EpubWriter.ets` / `data/EpubExporter.ets` | 实测（写出侧见历史记录，未在本轮复核行号） |
| 在线书源规则 / 搜索 / 正文 | `bookSource/`（23 文件）+ `data/BookSourceRepository.ets:31` + `data/BookSourceImporter.ets:52` | 实测 |
| 书源脚本执行 | `bookSource/` 的运行时桥接 + `third_party/harmony-book-source-engine/quickjs/`（`JSContext.ts:72 evaluateScript`，`libs/arm64-v8a/libquickjs.a` 1,644,138 B） | 实测（quickjs 已在仓库，不是要另引） |
| 日志 | `lib/AppLog.ets:40`（环形缓冲，`AppLogEntry:18`） | 实测 |
| 压缩包导入 | `data/ArchiveImporter.ets:28`（`ExtractedArchive:21`） | 实测 |

**这张表是按「我知道在哪」写的，不是全量索引。** `data/` 135 个文件里我只核过 20 个类。表里没有的功能，先 `grep -rn '<关键词>' entry/src/main/ets/data entry/src/main/ets/lib`，再按类名读定义行。

---

## 五、五条后端专属坑

1. **0 命中不等于没有。** 实测反例：`saveBookOrder` 我最初只在 `BookshelfPage.ets` 里 grep，得 0；实际在 `data/BookRepository.ets:1794`，由 `pages/Index.ets:8576` 调用。查一个动作要试三个同义关键词（如 `saveOrder` / `saveBookOrder` / `updateOrder`）再判「没有」。
2. **改方法签名必须全仓核调用方，否则 HEAD 编译不过。** 实测事故：`data/BackupRepository.ets` 把 `selectBackup(context, currentBooks)` 改成 `selectBackup(context)`、`prepareBackupArchive(context, zipPath, currentBooks)` 改成 `prepareBackupArchive(context, zipPath)`，同时删掉了 `BackupPreview` 接口与 `loadRestoredEntries`；而 HEAD 版 `pages/Index.ets` 仍按旧签名调用（`selectBackupFromPath(context, zipPath, localBooks)` 等 5 处）。**那个改动只能与调用方同批提交**，单独提交会让整仓编译不过。
3. **「已修」必须有断言输出，三种任选。** A 静态公式对照（无设备，读代码算）；B prefs（`hdc shell 'cat /data/app/el1/bundle/public/io.legado.harmony/preferences/<文件名>'`）；C 数据库（`hdc file recv .../databases/legado.db` 后 `python -c` 用 sqlite3 查 ``select bookUrl, `order` from books order by `order` ``）。只写「改好了」不贴输出，不算修完。
4. **偏好键存在不等于消费者存在。** `data/ReaderSettingsRepository.ets` 有 2,141 行、几百个键，其中一部分只做到「能备份、界面能拨、读回显示」——全仓没有任何分支因它而改变行为。判定一个键是否真接上，要数「写入点 N 处 / 读回给界面 N 处 / **业务消费** N 处」，**业务消费的定义是：某个分支/计算/API 调用因读此值而改变行为；只赋给 `@State` 再显示不算**。
5. **`data/` 的 135 个文件里有一半名字看不出职责。** 例如 `BookInfoSettings.ets` 里装的是 `BookInfoSettingsRepository`，`CacheStatsRepository` 与 `CacheSettingsRepository` 是两个不同文件。找东西靠 `grep` 不靠猜文件名。

---

## 六、这份清单怎么来的、什么时候会失效

- **生成方式**：`tmp/_cc_dom.py`（四个子域的文件数与行数）、`tmp/_cmp_data.py`（`export class/interface/enum/type` 全量索引，180 个）、`tmp/_cmp_up.py`（组件注释里的上游映射）。
- **会失效的部分**：行号。`BookRepository` / `BackupRepository` / `ReaderSettingsRepository` 这三个 3 千行上下的大文件被并发会话改得很频繁。用前 `grep -n` 复核。
- **不会失效的部分**：文件划分、类名、四个子域的职责边界。

**未做的事**：

- 我只核过 `data/` 135 个文件里的 20 个类，其余 115 个没读。表里没有的功能不是不存在。
- `reader/` 40 个文件、`bookSource/` 23 个文件我一类一类没展开，只给了子域体量与最大文件。
- 上游对照几乎全是 `未查到`——这一轮没做后端逐类对照。
- 没有上机验证任何数据行为（prefs / db 断言一条没跑）。
