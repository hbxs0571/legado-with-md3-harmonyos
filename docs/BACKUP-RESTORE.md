# Android ZIP 备份兼容

> 本文原公开段落与兼容队列原样保留；r257 当前状态补充见文末，r287 补齐 28 类全量清单。r250 原公开全文另存于 [文档归档](BACKUP-RESTORE-r250.md)。

HarmonyOS 工程读取 Android ZIP 备份时，按归档数据处理，不把导入视为完整 Android 数据库迁移。支持范围须区分原生功能、ZIP 字段映射与仅供兼容保存的数据。兼容继续使用原版的根目录 JSON/XML ZIP 格式，不新增私有容器、manifest 或脚本执行。

## 安全边界

- 预览并检查 ZIP 条目、校验值、路径、格式、大小、资源限制和重复项。
- 未知或未迁移类别只能预览、忽略或安全保留；不执行归档中的脚本或规则。
- 仅映射语义明确且原生功能已存在的字段。
- 无正文的本地书目可以保留元数据与进度并标注缺少正文，不伪造或打包书籍正文。
- Cookie、请求头、令牌、账号与服务器配置视作敏感不可信数据，不公开展示、不尝试解密，也不据此连接外部服务。
- 不宣称支持跨类别事务回滚、跨设备凭据恢复或完整 Android 数据库语义，除非这些范围经过单独实现和验证。

涉及备份格式或恢复映射的修改属于危险修改，修改前须创建源码检查点备份。

## 测试样本

本机有一份真实的 Android 备份，用作 ZIP 往返验收的样本。**文件名与条数公开，样本文件本身不入库、不上传**——它含真实书目与阅读记录，只留本机。

- 压缩包：`测试/backup2026-10-22.zip`（3.0 MB）
- 解压目录：`测试/backup2026-10-22/`（21 个条目，逐条已核对）
- 位置：与仓库根同级目录 `测试/`；`.gitignore` 已含 `*.zip` / `*.epub`，`git ls-files` 查不到任何样本
- 导出时间：2026-10-22；解压时间 2026-10-27
- 同目录另有 3 本测试书（TXT 3.8 MB、EPUB 5.2 MB、TXT 116 KB），可作本地导入测试书；文件名同样不入库

**样本内容与条数**（2026-10-30 逐条统计）：

| ZIP 条目 | 条数 | ZIP 条目 | 条数 |
| --- | --- | --- | --- |
| `bookshelf.json` | 658 | `searchHistory.json` | 737 |
| `bookmark.json` | 344 | `txtTocRule.json` | 40 |
| `bookGroup.json` | 28 | `httpTTS.json` | 1 |
| `bookSource.json` | 904 | `httpTtsVoices.json` | 1 |
| `rssSources.json` | 28 | `keyboardAssists.json` | 32 |
| `replaceRule.json` | 40 | `dictRule.json` | 28 |
| `readRecord.json` | 575 | `homepageCustomSets.json` | 1 |
| `readRecordDetail.json` | 313 | `readConfig.json` | 12 |
| `readRecordSession.json` | 39376 | `shareReadConfig.json` | 96 键（对象） |
| `themeConfig.json` | 8 | `config.xml` | 20132 字节 / 370 个偏好项 |
| `servers.json` | 空文件（非 JSON） | | |

**这个样本缺 9 个条目**：`bookMarking.json`、`rssStar.json`、`sourceSub.json`、`homepageModules.json`、`highlightRule.json`、`highlightTagRule.json`、`tagGroupRule.json`、`coverRule.json`、`directLinkUploadRule.json`。所以凡属这 9 类的「待往返验收」都不能拿本样本当完成依据——要么另找一份带这些条目的备份，要么在设备上先造数据再导出。

`config.xml` 的 370 个偏好项里，本地真正读写的只有一小部分：**写出侧 35 个键**（`upsertAndroidPreference` 去重后），分三段——`bookshelfLayout` 段 9 个（`bookGroupStyle`、`hideEmptyGroups`、`bookshelfSort`、`bookshelfSortOrder`、`bookshelfLayoutPortrait`、`bookshelfLayoutGridPortrait`、`bookshelfLayoutListPortrait`、`bookshelfTitleMaxLines`、`bookshelfCoverShadow`）、`readConfig` 段的阅读外观与菜单键、`themeConfig` 段的护眼 6 键；**读入侧 47 个键**（`readXmlInteger` / `readXmlBoolean` / `readXmlString` 去重），其中 24 个只在读入侧出现、写出侧没有。两者并集 **59 个键**。其余 311 个键既不读也不写，恢复时随 `copyPreservedEntries` 原样归档。这就是「ZIP 里有 370 项、本地只认 59 项」的直接来源，逐类缺口见下文 28 类清单。

阅读配置的 Android `config.xml` 映射包含 `tocUiUseReplace` 与 `tocCountWords` 两个目录偏好键；导入时仅恢复到本地阅读设置，不执行归档中的脚本或规则。该映射尚待实际 ZIP 往返验收。

替换净化规则的 JSON 映射已接入源码：备份类别未被排除时，会输出根级 replaceRule.json；当前规则列表为空时也输出空数组，避免旧归档中保留的同名文件把已删除规则重新带入。恢复时逐条解析；同 ID 或同 pattern 的条目更新本地规则并保留本地 ID 和顺序，非法正则计入跳过，原文件同时留在兼容归档目录。

这说明映射路径已实现，不表示 E 端完成替换净化规则创建、文件流转或 ZIP 全往返；替换净化模块的逐项状态见 [已知问题](KNOWN-ISSUES.md)。

TXT 目录规则使用根级 `txtTocRule.json`，其字段为 `chapterRule`、`volumeRule`、`example`、`serialNumber` 和 `enable`；内置 27 条规则来自上游 GPL-3.0 默认规则文件，逐字节一致。E 端已验证合成 ZIP 中单条规则恢复并冷启动读回，以及规则为空时的应用备份读回。含非空目录规则的应用备份恢复仍待端到端验证；书架更新目录设备测试也未完成。

阅读正文高亮规则使用根级 `highlightRule.json`，字段逐项对齐上游 `HighlightRule` 实体：本地 33 个字段与上游同名同义，上游多出的 `borderColor`、`borderRadius`、`borderWidth` 三个边框字段本地没有模型，导出时自然缺失，Android 读回时由 Kotlin 默认值兜底。备份类别未被排除时写出该文件；规则自 r284 起存 `highlightRules` 表（此前是 Preferences），写出前仍必须 `await ReaderHighlightRuleRepository.load()`——这次不是为了从 Preferences 读数据，而是为了把 `cachedRules` 预载满，否则没进过阅读页的用户会导出一份空数组。**恢复采用合并语义：同 id 或同 pattern 的条目覆盖本地规则并保留本地 id 与顺序，其余新增，本地独有的规则保留。** 这与上游 `Restore.kt:270` 的 `replaceAll`（全量替换）不同，选择合并的理由是 `replaceAll` 会在无提示的情况下删掉用户在 HarmonyOS 上新建的规则，属于数据丢失；而「用备份完全替换本地规则」的场景可以靠先全选删除再恢复达成，反向则不可挽回。空正则与无法编译的正则在导入时计入跳过，不计入新增或覆盖。N 端已在 HOS 模拟器完成备份写出（2 条规则生成 1349 字节 JSON）与恢复导入（新增 1、覆盖 1、跳过 1）双向验证。

书签、划线与笔记分别使用根级 `bookmark.json` 与 `bookMarking.json`，两者都是纯 JSON 数组，字段逐项对齐上游 `Bookmark.kt` 与 `BookMarking.kt`：书签 9 个字段（`time`/`bookName`/`bookAuthor`/`bookUrl`/`chapterIndex`/`chapterPos`/`chapterName`/`bookText`/`content`）；笔记 12 列与上游 `BookMarking.kt` **逐字对齐**（r284 关系型存储迁移后本地 `book_marks` 表就是上游 12 列，`id`/`enabled`/`createdAt`/`updatedAt` 上游本来就有，不再是本地扩展字段），其中 `anchorJson` 与 `styleJson` 保存的是序列化后的字符串（上游同为 `String?`），所以本地划线锚点与样式可以原样往返。备份类别未被排除时写出这两个文件，数据源分别是 `ReaderBookmarkRepository.load()` 与 `ReaderMarkingRepository.load()`，导出函数为 `ReaderBookmarkExporter.toAndroidBookmarkArray()` / `toAndroidMarkingArray()`。**恢复必须先合并再落盘**：两个条目在同一次恢复里先后出现，若先写书签时用旧笔记列表、后写笔记又覆盖回去，就会互相清除，因此 `restore()` 用 `pendingBookmarks` / `pendingMarkings` 暂存两份合并结果，等循环结束后各写一次。合并口径与替换净化规则一致：同 id 或同内容视为同一条，命中时保留本地 id 并覆盖其余字段，其余新增；书签与笔记都要能找到对应书籍才计入新增或覆盖，找不到的计入跳过。N 端已在 HOS 模拟器完成双向验证：备份侧在有 1 条书签与 1 条笔记时导出 `bookmark.json` 1123 字节、`bookMarking.json` 562 字节，UTF-8 中文正常；清空本地笔记后从该 ZIP 恢复，提示「书签与笔记新增 1 条、覆盖 1 条」，冷启动后「所有书签」页显示「1 条书签 · 1 条笔记」。

## 兼容队列

优先核验书架和阅读位置、阅读配置、书签与笔记、通用偏好、主题、阅读记录、规则和搜索历史。随后处理当前没有原生业务的类别；每类分别说明是映射、保留、忽略还是未支持。合并/覆盖、冲突、异常归档、资源限制与重启后状态需要独立验收。

按三个层次推进，每层内一次只处理一种数据类别：

1. **已有原生功能的数据映射**：书架与进度 → 阅读配置 → 书签/划线与笔记 → 通用偏好 → 主题配置 → 阅读记录 → 替换净化规则 → 搜索历史 → TXT 目录规则。仅映射有明确等价语义的字段；无正文的本地书目保持“缺正文”。
2. **当前没有原生业务的安全兼容**：字典规则 → 书源 → RSS 订阅源 → 书架分组 → 首页自定义分组 → 键盘辅助、在线朗读源及服务端配置。每类单独记录预览、忽略或原样保留结果，不把归档数据显示为可用功能。
3. **跨类别收口**：验证合并/覆盖、冲突、异常 ZIP、资源上限、重启后状态和实际往返；受影响的 TXT/EPUB、进度、记录、书签及设置做定向回归。

Android 归档中的 `readRecord.json`、`readRecordDetail.json` 与 `readRecordSession.json` 当前仅按兼容归档保留，不导入原生会话/日明细/按书汇总仓储。**注意区分两件事**：这是「ZIP 导入没接」；而本机旧格式记录（`legado_read_time_records` 的扁平 `records` 键）的搬迁已在 r283 接进 `RdbMigration` 第三批，两者不是同一件事，后者不代表 ZIP 映射已接。

TTS、WebDAV 服务、在线书源抓取、RSS 抓取和查词业务均不随本轮自动启动。WebDAV 服务器凭据需要单独解决解密密钥和跨设备安全；服务端配置条目的存在不表示可迁移服务。

归档中出现书源、RSS、在线朗读源、服务端或键盘规则，不代表相关业务已经接入。细节和当前状态见 [进度摘要](PROGRESS.md) 与 [验证记录](VALIDATION.md)。

仅把原条目保存在本地兼容目录供后续备份使用，不算重构该功能；归档条目存在也不等于该包已完成实际恢复验收。

## 28 类兼容清单

本表对齐 `entry/src/main/ets/data/BackupRepository.ets` 的 `categoryOptions`，**28 类一一对应**，缺一类就是漏一类。核对方法：本表行数与代码里 `categoryOptions` 的项数必须相等，键名逐个相同。

「上游中文名」列取自上游 `app/src/main/res/values-zh-rCN/strings.xml`，即 Android 备份设置界面上勾选项显示的原文，**不是我自拟的译名**。键名是代码里的 `categoryOptions` 键（必须用它对代码），中文名只用于辨认「这条数据到底是什么」。有一处容易认错：`themeMode` 在上游叫**深色模式**，不是「主题模式」——它只是夜间开关，主题配色在 `themeConfig`。

**28 类分两段，看 `ZIP 条目` 列就能分辨**：

- **前 9 类（`localBook` … `mangaConfig`）是配置忽略键**，对应上游 `BackupConfig.ignoreKeys`，作用对象是 `config.xml` 里的偏好键，备份时按类别决定要不要把这些键写进 `config.xml`。
- **后 19 类（`bookmark` … `server`）是数据库忽略键**，对应上游 `BackupConfig.dbIgnoreKeys`，作用对象是各自独立的 JSON 文件。

**一个类别可能对应多个文件**，别以为一类就是一个文件：

| 类别键名 | 对应文件 | 上游依据 |
| --- | --- | --- |
| `bookmark` | `bookmark.json` + `bookMarking.json` | `Backup.kt:152-155`，注释原文「书签与划线/想法笔记（book_marks）视为一体，统一受既有 bookmark 忽略项控制」 |
| `readRecord` | `readRecord.json` + `readRecordDetail.json` + `readRecordSession.json` | 一个类三个文件，所以样本条数是 575 / 313 / 39376 |
| `readConfig` | `readConfig.json` + `shareReadConfig.json` + `config.xml` 中 85 个键 | 三个来源：单书配置、分享方案、全局偏好 |
| `themeConfig` | `themeConfig.json` + `config.xml` 中 52 个键 | 同上 |
| `httpTTS` | `httpTTS.json` + `httpTtsVoices.json` | 朗读源与音色分两个文件 |
| `localBook` | `bookshelf.json` | 该类只对应这一个文件，但上游另有 `backupIgnoreLocalBook`（`BackupConfig.kt:455-475`）单独过滤 `isLocal` 的书 |
| `coverConfig` | `coverRule.json` | 文件名是 `coverRule.json`，不叫 `coverConfig.json`，容易找错 |

核对命令（在仓库根执行，两个数字必须都是 28）：

```bash
grep -cE '^\| [0-9]+ \| `' docs/BACKUP-RESTORE.md
grep -c "{ key: '" entry/src/main/ets/data/BackupRepository.ets
```

「ZIP 接入」判据只有三档，与 [ZIP 兼容总账](parity/STATUS.md) 的三级兼容度一致：

- **已接入**：恢复时有具名分支，数据落到原生仓储/表；且已过设备往返验证，或至少写出侧已实现
- **部分接入**：恢复侧有分支但只映射了该类的一部分键/字段，或只在合成 ZIP 上验过、真实归档未验
- **仅归档**：恢复时由 `copyPreservedEntries` 原样保存，不解析、不落原生功能（这类条目在归档里存在 ≠ 该功能已支持）

恢复侧具名分支实测只有这 9 个 `entry.name ===` 判断：`bookshelf.json`、`config.xml`、`bookGroup.json`、`replaceRule.json`、`txtTocRule.json`、`highlightRule.json`、`bookmark.json`、`bookMarking.json`，其余全部走 `copyPreservedEntries`。

| # | 类别键名 | 上游中文名 | ZIP 条目 | 样本条数 | 本地原生功能 | ZIP 接入 | 队列位置 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | `localBook` | 本地书籍 | `bookshelf.json` | **658** | 书架、TXT/EPUB 阅读、进度保存 | **部分接入**：书目/进度/缺正文标记可映射；不打包正文；复杂冲突待验 | ZIP 映射 1 |
| 2 | `readConfig` | 阅读界面 | `readConfig.json`、`shareReadConfig.json`、`config.xml` | 12 / 96 键 / 370 项 | 阅读配置有原生模型与持久化 | **部分接入**：读入 46 个 `config.xml` 键；`shareReadConfig` 未转多套方案 | ZIP 映射 2 |
| 3 | `themeMode` | 深色模式 | `config.xml` | 370 项内 1 键 | 有主题设置页（`pages/ThemeSettingsPage.ets`，333 行） | **未接入**：`themeMode` 键读写都未接 | 待接 |
| 4 | `themeConfig` | 主题配置 | `themeConfig.json`、`config.xml` | 8 / 370 项内 52 键 | 主题页 + 护眼设置 | **部分接入**：护眼 6 键双向已验；Android 配色/透明度 JSON 未映射 | ZIP 映射 5 |
| 5 | `coverConfig` | 封面设置 | `coverRule.json`、`config.xml` | **样本缺** | 有封面设置页（`pages/AppCoverSettingsPage.ets`，149 行，3 处 `onUnavailableAction`） | **未接入**：14 个键读写均未接 | 待接 |
| 6 | `bookshelfLayout` | 书架布局 | `config.xml` | 370 项内 41 键 | 书架布局有完整仓储（`data/BookshelfLayoutRepository.ets`） | **部分接入**：写出 9 键已接；读入侧未接 | 已盘，见[书架对照表](parity/BOOKSHELF.md) A2 |
| 7 | `showRss` | 显示订阅 | `config.xml` | 370 项内 1 键 | 订阅页 UI 已有 | **未接入**：`showRss` 键读写都未接 | 待接 |
| 8 | `threadCount` | 线程数 | `config.xml` | 370 项内 1 键 | **无对应概念**（HOS 无并发线程数设置） | **未接入**：键读写都未接 | 安全兼容 |
| 9 | `mangaConfig` | 漫画设置 | `config.xml` | 370 项内 32 键 | 仅设置页有漫画相关条目文字，无漫画阅读 | **未接入**：32 个键读写都未接 | 安全兼容；漫画业务候选 |
| 10 | `bookmark` | 书签 | `bookmark.json`、`bookMarking.json` | 344 / **样本缺 `bookMarking`** | 原生书签与标注仓储、阅读入口 | **已接入**：N 端双向验证通过（新增 1、覆盖 1），合并语义 | ZIP 映射 3 |
| 11 | `bookGroup` | 书架分组 | `bookGroup.json` | 28 | 原生分组模型、管理、编辑与筛选 | **已接入**：根级 JSON 可导出导入；外部 ZIP 冲突合并待验 | 已盘，见[书架对照表](parity/BOOKSHELF.md) A3 |
| 12 | `bookSource` | 书源 | `bookSource.json` | 904 | 有页面壳，规则解释与抓取未迁移 | **仅归档**：不执行规则 | 安全兼容 11；抓取业务候选 |
| 13 | `rssSource` | 订阅源 | `rssSources.json` | 28 | 订阅页 UI 已有，抓取未迁移 | **仅归档** | 安全兼容 12；抓取业务候选 |
| 14 | `rssStar` | RSS 收藏 | `rssStar.json` | **样本缺** | **无**（`grep rssStar` 零命中） | **仅归档** | 安全兼容 |
| 15 | `replaceRule` | 替换规则 | `replaceRule.json` | 40 | 规则模型/仓储 + 阅读时替换链路 | **已接入**：写出根级 JSON、恢复逐条导入；非空应用备份往返待验 | ZIP 映射 7 |
| 16 | `readRecord` | 阅读记录 | `readRecord.json`、`readRecordDetail.json`、`readRecordSession.json` | 575 / 313 / **39376** | 原生会话、日明细、按书汇总三层已接通 | **仅归档**：三个条目都不导入原生仓储 | ZIP 映射 6 |
| 17 | `searchHistory` | 搜索历史 | `searchHistory.json` | 737 | 阅读器搜索历史有原生仓储（`search_content_history` 表） | **仅归档**：未导入 | ZIP 映射 8 |
| 18 | `sourceSub` | 书源订阅 | `sourceSub.json` | **样本缺** | 有页面壳 | **仅归档** | 安全兼容 |
| 19 | `txtTocRule` | TXT 目录规则 | `txtTocRule.json` | 40 | 规则仓储、管理页、切章、分卷、书架更新目录 | **已接入**：合成 ZIP 单条恢复与空规则备份有记录；非空应用备份往返待验 | ZIP 映射 9 |
| 20 | `httpTTS` | HTTP TTS | `httpTTS.json`、`httpTtsVoices.json` | 1 / 1 | 朗读设置界面存在，TTS 服务未迁移 | **仅归档**：不调用服务 | 安全兼容；TTS 业务候选 |
| 21 | `keyboardAssists` | 键盘辅助 | `keyboardAssists.json` | 32 | **无**（`grep keyboardAssists` 零命中） | **仅归档** | 安全兼容；键位业务候选 |
| 22 | `dictRule` | 字典规则 | `dictRule.json` | 28 | 列表与编辑 UI 有壳（`pages/ProfileSubPages.ets`），存储与查词未迁移 | **仅归档** | 安全兼容 10；字典业务候选 |
| 23 | `homepageModules` | 首页模块 (JSON) | `homepageModules.json` | **样本缺** | 首页基础组件已实现，模块管理未迁移 | **仅归档** | 安全兼容 |
| 24 | `homepageCustomSets` | 首页自定义 | `homepageCustomSets.json` | 1 | 自定义集合管理未迁移 | **仅归档** | 安全兼容；自定义业务候选 |
| 25 | `highlightRule` | 高亮规则 | `highlightRule.json` | **样本缺** | 规则模型、`highlightRules` 表、正则匹配、分页/滚动两渲染 | **已接入**：N 端双向验证通过；合并语义，与上游 `replaceAll` 不同 | ZIP 映射已验 |
| 26 | `highlightTagRule` | 标签规则 | `highlightTagRule.json` | **样本缺** | 有列表页与编辑页（`pages/ProfileSubPages.ets:2244` 起 207 行），**13 处 `onUnavailableAction`，无仓储** | **仅归档** | 安全兼容 |
| 27 | `tagGroupRule` | 标签分组规则 | `tagGroupRule.json` | **样本缺** | **无**（`grep tagGroup` 零命中） | **仅归档** | 安全兼容 |
| 28 | `server` | 服务器配置 | `servers.json` | 空文件 | WebDAV/服务端同步未迁移 | **仅归档**：数据不透明，不尝试解密或连接 | 安全兼容；WebDAV 业务候选 |

**统计（四档，合计 28）**：

| 档位 | 类数 | 类别 |
| --- | --- | --- |
| 已接入 | **5** | `bookmark`、`bookGroup`、`replaceRule`、`txtTocRule`、`highlightRule` |
| 部分接入 | **4** | `localBook`、`readConfig`、`themeConfig`、`bookshelfLayout` |
| 未接入（本地有页面，ZIP 键读写都没接） | **5** | `themeMode`、`coverConfig`、`showRss`、`threadCount`、`mangaConfig` |
| 仅归档 | **14** | `bookSource`、`rssSource`、`rssStar`、`readRecord`、`searchHistory`、`sourceSub`、`httpTTS`、`keyboardAssists`、`dictRule`、`homepageModules`、`homepageCustomSets`、`highlightTagRule`、`tagGroupRule`、`server` |

「未接入」与「仅归档」的区别只在本地有没有那页 UI：前 5 类本地有设置页可改值，只是那些值既不写进 `config.xml`、也不从 `config.xml` 读回；后 14 类连页面都没有。两者对 Android 用户的实际结果一样——换到 HarmonyOS 后这些设置不生效。

**与 r257 旧版的差异**：旧版 18 行用的全是中文功能名（「书架、书籍元数据与进度」「通用偏好设置」「替换净化规则」），新版改用代码键名。两版的数据没有丢，只是切法变了，对应关系如下：

| 旧版功能名（18 行） | 新版类别（28 行） |
| --- | --- |
| 书架、书籍元数据与进度 | `localBook` 本地书籍 |
| 阅读配置 | `readConfig` 阅读界面 |
| 书签、划线与笔记 | `bookmark` 书签（含 `bookmark.json` 与 `bookMarking.json` 两个文件） |
| **通用偏好设置** | **拆成 6 类**：`themeMode` 深色模式、`coverConfig` 封面设置、`bookshelfLayout` 书架布局、`showRss` 显示订阅、`threadCount` 线程数、`mangaConfig` 漫画设置 |
| 主题配置 | `themeConfig` 主题配置 |
| 书架分组 | `bookGroup` 书架分组 |
| 首页自定义分组 | `homepageCustomSets` 首页自定义 |
| 替换净化规则 | `replaceRule` 替换规则 |
| 完整阅读记录与会话 | `readRecord` 阅读记录（三个文件） |
| 搜索历史 | `searchHistory` 搜索历史 |
| TXT 目录规则 | `txtTocRule` TXT 目录规则 |
| 阅读正文高亮规则 | `highlightRule` 高亮规则 |
| 字典规则 | `dictRule` 字典规则 |
| 书源 | `bookSource` 书源 |
| RSS 订阅源 | `rssSource` 订阅源 |
| 在线朗读源与音色 | `httpTTS` HTTP TTS（两个文件） |
| 键盘辅助映射 | `keyboardAssists` 键盘辅助 |
| 服务端配置 | `server` 服务器配置 |
| （旧版没有） | `rssStar` RSS 收藏、`sourceSub` 书源订阅、`homepageModules` 首页模块、`highlightTagRule` 标签规则、`tagGroupRule` 标签分组规则 |

算术核对：旧版 18 行 −「通用偏好设置」1 行 + 拆出的 6 类 = 23 行，再加旧版没有的 5 类 = **28 行**，与代码 `categoryOptions` 项数一致。

旧版之所以只有 18 行，是因为它把 `config.xml` 里的 6 类偏好合并成了一个「通用偏好设置」；新版拆开，是因为它们在代码里是 6 个独立的 `categoryOptions` 项，**各自可以单独勾选忽略**，合成一行就没法派活。

状态修正：`bookGroup.json` 已列入原生分组映射，而不是“没有原生分组功能”；本地阅读记录三层仓储已接入，但 Android ZIP 历史仍未映射。r255 在 E 端验证 `readConfig × themeConfig` 四种包含/忽略组合；这不代表所有阅读/主题字段或外部 Android ZIP 已完整往返。

## 按清单派活的依据

派活时最多有三份文档会被引用，分工必须说清，否则同一个问题会有三个答案：

| 文档 | 管什么 | 什么时候看 |
| --- | --- | --- |
| **本文** `BACKUP-RESTORE.md` | **28 类 ZIP 条目 ↔ 本地能力**的对齐状态：某类的 JSON/XML 条目恢复时会不会落到原生仓储，落到哪张表 | 派「实现某一类的 ZIP 恢复」时 |
| [ZIP 兼容总账](parity/STATUS.md) | 28 类的**三级兼容度**（读 / 写 / 忽略项）逐类打分，以及「涉及行」——每类在三张对照表里落在哪一块、多少行 | 判断某类「算不算做完了」、该盘哪几块时 |
| [对照关键词](parity/KEYWORDS.md) | 每类的**上游检索词**，用来生成上游接触面文件清单 | 盘点某类时要碰哪些上游文件时 |

三者的键名必须完全一致，都取自 `BackupRepository.ets` 的 `categoryOptions`。

**冲突时以谁为准**：以代码（`categoryOptions`、`entry.name ===` 恢复分支、`preferenceKeysByCategory`）和实测为准，文档落后就改文档。本文 28 类表在 2026-10-30（r287）已与代码逐键对齐；`STATUS.md` 的分数仍来自更早的核实，用它之前先看它顶部的日期。

**派活时的最小信息集**，一份任务书里至少要给：

1. 类别键名（如 `themeMode`）与对应 ZIP 条目（`config.xml` 的 `themeMode` 键）
2. 本文表格里该类的「ZIP 接入」档位与「本地原生功能」现状——决定要不要先补本地页面
3. 该类在 `config.xml` 里的键名清单（`preferenceKeysByCategory` 有的话直接指过去，没有就现列）
4. 验收方式：**必须走真实样本 `测试\backup2026-10-22.zip` 的往返**，不是只看代码。样本缺该类条目时先造数据，别拿「代码写了」当验收

**一个已知的口径陷阱**：`config.xml` 有 370 个偏好项，本地读入 46 个、写出 9 + 阅读外观/护眼两组。**「`config.xml` 已接入」不等于「370 项都接了」**，派活时说清是接哪几个键。各类别的**上游键数**为：`readConfig` 60、`themeConfig` 53、`bookshelfLayout` 39、`mangaConfig` 32、`coverConfig` 14，5 类合计 198 个键（另有 `themeMode`、`showRss`、`threadCount` 三个单键类别，28 类合计 201 个键），本地实际接了不到一半。详见下节。

## 偏好键对齐差异（待移除）

本地 `entry/src/main/ets/data/BackupRepository.ets:233 preferenceKeysByCategory` 与上游 `help/storage/BackupConfig.kt` 的五个类别数组逐键比对（可复跑：拿 `PreferKey.kt` 常量值换算后求差集）：

| 类别 | 上游 | 本地 | 多出 | 缺失 |
| --- | --- | --- | --- | --- |
| `readConfig` | 60 | 85 | **25** | 0 |
| `themeConfig` | 53 | **53** | 0 | 0（r292 已补 `bookInfoAuthorSearchFallback`） |
| `bookshelfLayout` | 39 | 41 | **2** | 0 |
| `mangaConfig` | 32 | 32 | 0 | 0 |
| `coverConfig` | 14 | 14 | 0 | 0 |

`readConfig` 多出的 25 个分两类：

**一、上游有常量、但不在任何类别数组（14 个）——照样参与备份，本地不该把它们收进类别数组**

判定依据：上游 `help/storage/BackupConfig.kt:413 fun keyIsNotIgnore` 里不在任何类别数组的键走 `else -> true`，照样写进 `config.xml`。换句话说，**取消「阅读界面」勾选时上游不会删这 14 个键，本地却会删**——这是与上游的行为不一致。

| 键 | `PreferKey.kt` 行 |
| --- | --- |
| `readingAnchorEnabled` | `:121` |
| `swipeToAddBookmark` | `:204` |
| `bookmarkBadgeImage` | `:205` |
| `bookmarkBadgeSize` | `:206` |
| `maxLengthWithNoToc` | `:446` |
| `progressBarBehavior` | `:170` |
| `tocUiUseReplace` | `:163` |
| `tocCountWords` | `:164` |
| `clickImgWay` | `:202` |
| `textFullJustify` | `:105` |
| `textBottomJustify` | `:106` |
| `bookGroupStyle` | `:13` |
| `hideEmptyGroups` | `:14` |
| `system_typefaces` | `:103`（常量名是 `systemTypefaces`，值是 `system_typefaces`；同时还是 `R.array.system_typefaces` 资源名，**不是偏好键**） |

最后一项 `system_typefaces` 情况特殊：它在 `PreferKey` 里有常量，但全仓无人读写（只被 `R.array.system_typefaces` 资源引用），本地收进 `readConfig` 属误收，应删。

**二、上游全仓不存在（13 个）——误把 JSON 结构字段名当成 `config.xml` 键，必须删**

| 键 | 上游真身 |
| --- | --- |
| `textBold` | `help/config/ReadBookConfig.kt:573 val textBold: Int = 500` 的**字段名**；`:760 "textBold" to textBold` 是 `shareReadConfig` JSON 的键，不是 `config.xml` 键 |
| `underlineColor` | `data/entities/HighlightRule.kt:21 var underlineColor: Int? = null` 的字段名；`ReadBookConfig.kt:800` 里作为 `highlightRules` 内嵌 JSON 的键 |
| `underline` | `ui/widget/components/text/HtmlContent.kt:696 underline = "underline" in value.lowercase()` 的 HTML 样式字面量 |
| `textItalic`、`textShadow`、`shadowRadius`、`shadowDx`、`shadowDy`、`shadowColor`、`shadowColorN`、`underlineHeight`、`underlineColorNight`、`dottedLine` | 全仓字面量命中 0（既非 `PreferKey`、也非 `LocalPreferences`、也非任何 JSON 键） |

**三、`bookshelfLayout` 多出的 2 个**：`bookGroupStyle`（`PreferKey.kt:13`）、`hideEmptyGroups`（`PreferKey.kt:14`）——与上游同样落在 `else -> true` 的无类别分支，本地收进了 `bookshelfLayout` 数组，属上述第一类问题。

**四、`themeConfig` 缺失的 1 个**：`bookInfoAuthorSearchFallback`（`PreferKey.kt:252`，在上游 `themePrefKeys` 内）。本地未收，导致取消「主题配置」勾选时这个键不会被忽略——与上游不一致。**已在 r292 补进 `BackupRepository.ets` 的 `themeConfig` 数组**（现 53 = 上游 53）。

> **现状**：`themeConfig` 已对齐；`readConfig` 多 25、`bookshelfLayout` 多 2 **尚未改动代码**，仅记录。修法：第一类 14 个键从类别数组移除（改为「无类别」处理，即不出现在任何 `keysForCategory` 返回的列表里），第二类 13 个直接删，`bookshelfLayout` 那 2 个同样移除。判断口径见 `docs/parity/BOOKSHELF.md` 表头「ZIP 类别」列的取值说明（`—` = 参与备份但不受任何忽略开关控制）。

