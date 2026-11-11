# Android ZIP 备份兼容

> 本文原公开段落与兼容队列原样保留；r257 当前状态补充见文末，r287 补齐 28 类全量清单。r250 原公开全文已归档至 `docs/history/`，不随公开仓库发布。

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

`config.xml` 的 370 个偏好项里，本地真正读写的只有一部分。**写出侧 105 个去重键**（`upsertAndroidPreference` 共 92 处调用：91 处字面量键 + `:1092` 一处 `coverSettingsToAndroid` 循环覆盖 14 键），分段如下：无条件区 5 键（`BackupRepository.ets:825`-`:829`，`bookGroupStyle`、`hideEmptyGroups`、`showBookIntro`、`coverRestrictRatio`、`explore_filter_state`）、`bookshelfLayout` 段 37 键（门控 `:832`，`:834`-`:870`）、`readConfig` 段 41 键（门控 `:972`，`:974`-`:1082`）、`coverConfig` 段 14 键（门控 `:1089`，`coverSettingsToAndroid` 循环 `:1092`）、`themeConfig` 护眼 6 键（`:1107`-`:1118`）、`themeMode` 1 键（`:1128`）、`showRss` 1 键（`:1137`）。**读入侧 137 个去重键**（`readXmlInteger` / `readXmlBoolean` / `readXmlString` / `readXmlFloat` 字面量键 85 个 + `bookshelfLayout` 键组 39 键（25 整型 + 13 布尔 + 1 长整型）+ `coverConfig` 键组 14 键），其中 32 键只在读入侧出现（`readStyleSelect`、`shareLayout`、`readMenuIcon*`、`progressBarBehavior`、`tocUiUseReplace`、`tocCountWords`、`clickImgWay`、9 个 `clickAction*`、`paragraphSpacing`、`lineSpacingExtra`、`hideStatusBar`、`hideNavigationBar`，另加 `textBold`/`textItalic`/`textShadow`/`shadow*`/`underline*`/`dottedLine` 等写进 readConfig.json 的字段），写出侧 105 键**全部**在读入侧有对应读取（不存在单向键）；`shadowRadius`、`shadowDx`、`shadowDy`、`dottedBase`、`dottedRatio` 五个 float 键走「先 `readJsonNumber`（readConfig.json）后 `readXmlFloat`（config.xml）兜底」的双路读法（`:2261`-`:2266`、`:2408`-`:2413`）。读写并集 **137 键**。其余键既不读也不写，恢复时随 `copyPreservedEntries` 原样归档。这就是「ZIP 里有 370 项、本地只认其中一部分」的直接来源，逐类缺口见下文 28 类清单。（2026-11-09 复核：原文先记「写出侧 69 键、`bookshelfLayout` 段 13 键、读入侧 75 键」，后改记「读入侧 132 键、另有 5 键只在写出侧」，两版都与代码不符。2026-11-11 按工作区 3640 行版本重测：`upsertAndroidPreference` 共 92 处调用（91 处字面量键 + `:1092` 一处循环覆盖 14 键），加 `coverSettingsToAndroid` 的 14 键去重后**写出 105 键**；`readXml*` 共 90 处调用（85 处字面量键 + `:2075`/`:2083`/`:2117`/`:2120`/`:2123` 五处变量键），加 `bookshelfLayout` 键组 39 键（`:2066`-`:2072` 的 25 整型 + `:2078`-`:2080` 的 13 布尔 + `:2086` 的 `bookshelfSelectedGroupId`）与 `coverConfig` 键组 14 键去重后**读入 137 键**；只在读入侧的 32 键已在上文列全，只在写出侧的 0 键。）

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

Android 归档中的 `readRecord.json`、`readRecordDetail.json` 与 `readRecordSession.json` **已映射进原生三层仓储**：恢复侧 `entry/src/main/ets/data/BackupRepository.ets:1710`/`:1711`/`:1718`/`:1720` 具名解析出三份 pending 数据，主循环末尾 `:1748`-`:1749` 交给 `ReadRecordRepository.restoreFromBackup(context, …)`，函数体在 `entry/src/main/ets/data/ReadRecordRepository.ets:1069`，在 `store.beginTransaction()` 内按「取较长时间、较晚时间」合并写库。**注意区分两件事**：以上是「ZIP 导入」；本机旧格式记录（`legado_read_time_records` 的扁平 `records` 键）的搬迁是另一条路，已在 r283 接进 `RdbMigration` 第三批，两者不是同一件事。

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
| `readConfig` | `readConfig.json` + `shareReadConfig.json` + `config.xml` 中 105 个键 | 三个来源：单书配置、分享方案、全局偏好 |
| `themeConfig` | `themeConfig.json` + `config.xml` 中 53 个键 | 同上 |
| `httpTTS` | `httpTTS.json` + `httpTtsVoices.json` | 朗读源与音色分两个文件 |
| `localBook` | `bookshelf.json` | 该类只对应这一个文件，但上游另有 `backupIgnoreLocalBook`（`BackupConfig.kt:455-475`）单独过滤 `isLocal` 的书 |
| `coverConfig` | `coverRule.json` | 文件名是 `coverRule.json`，不叫 `coverConfig.json`，容易找错 |

核对命令（在仓库根执行，两个数字必须都是 28）：

```bash
grep -cE '^\| [0-9]+ \| `' docs/BACKUP-RESTORE.md
grep -c "{ key: '" entry/src/main/ets/data/BackupRepository.ets
```

> 上游 `backupFileNames`（`Backup.kt:69`-`:98`）实为 30 条，比本表 28 行多两条：`directLinkUploadRule.json`（上游走 ACache，不落 Room 表）与 `bookMarking.json`（本表并入 `bookmark` 一行）。本地 `fileNames` 白名单（`BackupRepository.ets:577` 起 30 条）与之逐条对应；`categoryOptions` 28 项与本表 28 行一致，故上面的 `grep -c "{ key: '"` 应等于 28 而不是 30。

「ZIP 接入」按五档判定，与 [ZIP 兼容总账](parity/STATUS.md) 的三级取值对应（`✓` 覆盖「已接入」与「部分接入」两个档，`✗` 覆盖「未接入」与「仅归档」，`—` 对应「不适用」）：

- **已接入**：恢复时有具名分支，数据落到原生仓储/表；且已过设备往返验证，或至少写出侧已实现
- **部分接入**：恢复侧有分支但只映射了该类的一部分键/字段，或只在合成 ZIP 上验过、真实归档未验
- **仅归档**：恢复时由 `copyPreservedEntries` 原样保存，不解析、不落原生功能（这类条目在归档里存在 ≠ 该功能已支持）
- **未接入**：本地有对应界面或概念，但 ZIP 条目既不写出、也不读回，键值完全没接
- **不适用**：上游有此行为、本地按 [盘点规约](./PARITY-RULES.md) 第三节判无对应依据（理由必写在表格备注或[已知问题](./KNOWN-ISSUES.md)里）

（2026-11-10 批 1 补记）**「透传」不是第六档**，而是 `config.xml` 未知键在「未接入」档内的补充口径：从 Android 恢复进来的 `config.xml` 里本地读不懂的键，按 XML 原标签（含 `long` / `set`）原值存进 `legado_backup_passthrough` preferences（键 `androidConfigPassthrough`，2000 键 / 1 MB 上限），下次备份由 `applyPassthroughPreferences` 原样写回 `config.xml`，判据与上游 `keyIsNotIgnore` 的 `else -> true` 对齐（排除已知写出 105 键、本地真值 97 键、alwaysIgnored 17 键、被忽略类别）。`threadCount` / `mangaConfig` 等无本地消费方的键走这条链路原样往返，故 [ZIP 兼容总账](parity/STATUS.md) 的读写列可按「备份往返等价」记，但**本地仍不落原生功能、档位维持「未接入」**，值仅供上游读回。透传缓存只覆盖「从 Android 恢复过」的设备，全新安装首次备份无透传数据。

恢复侧具名分支实测为 **主循环内 26 处 `entry.name ===` 判断、23 个条目名**（`entry/src/main/ets/data/BackupRepository.ets`，2026-11-11 工作区 3640 行、A 组四类接通后；测量口径为恢复主循环 `:1371`-`:1745` 区间内 `entry.name ===` 的出现次数）。四种计数口径：主循环内出现 **26**、全文出现（`grep -o "entry.name ===" … | wc -l`）**29**、全文命中行（`grep -c "entry.name ===" …`）**27**、条目名去重 **23**。清单（行号按当前工作区实测）：`bookshelf.json` `:1376`、`config.xml` `:1395`、`bookGroup.json` `:1411`、`bookSource.json` `:1421`、`rssSources.json` `:1439`、`rssStar.json` `:1457`、`sourceSub.json` `:1475`（以上四类为 A 组新增，顺序照上游 `Restore.kt:171`-`:198`）、`replaceRule.json` `:1493`、`txtTocRule.json` `:1510`、`highlightRule.json` `:1524`、`dictRule.json` `:1538`、`httpTTS.json` `:1556`、`homepageModules.json` `:1601`、`homepageCustomSets.json` `:1619`、`highlightTagRule.json` `:1637`、`tagGroupRule.json` `:1655`、`bookmark.json` 与 `bookMarking.json` `:1673`/`:1685`、`themeConfig.json`（常量 `THEME_CONFIG_FILE_NAME`）`:1696`、`readRecord.json`/`readRecordDetail.json`/`readRecordSession.json` `:1710`/`:1711`/`:1718`/`:1720`、`coverRule.json` `:1729`。其余条目走主循环末尾 `:1743`-`:1744` 的兜底 `fileIo.copyFile` + `preservedEntryCount += 1`，只进保留目录。另有 3 处 `entry.name ===` 不在恢复主循环：`:1273` 的 bookshelf 计数段（`entry !== undefined && entry.name === 'bookshelf.json'`）、`:2777` 与 `:2784`（都在 `buildRestoredEntrySummary` 里，不是「忽略项段」）。

| # | 类别键名 | 上游中文名 | ZIP 条目 | 样本条数 | 本地原生功能 | ZIP 接入 | 队列位置 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | `localBook` | 本地书籍 | `bookshelf.json` | **658** | 书架、TXT/EPUB 阅读、进度保存 | **部分接入**：书目/进度/缺正文标记可映射；恢复期冲突处理已接（`data/LocalBookRestorePlanner.ets` 移植上游 `BookRestorePlanner.kt` 的删重复书 / 重定位识别 / 三态定位）；不打包正文 | ZIP 映射 1 |
| 2 | `readConfig` | 阅读界面 | `readConfig.json`、`shareReadConfig.json`、`config.xml` | 12 / 96 键 / 370 项 | 阅读配置有原生模型与持久化 | **部分接入**：读入 46 个 `config.xml` 键；`shareReadConfig` 未转多套方案 | ZIP 映射 2 |
| 3 | `themeMode` | 深色模式 | `config.xml` | 370 项内 1 键 | 有主题设置页（`pages/ThemeSettingsPage.ets`）与全局主题网关（`data/ThemeSettingsRepository.ets` / `data/ThemeModeResolver.ets`） | **已接入（r303）**：备份时把全局 `themeMode` 写进 `config.xml`（值域归一成 `"0"/"1"/"2"`，写出 `BackupRepository.ets:1126`-`:1130`，恢复 `restoreThemeMode` 定义 `:670`、读键 `:676`），恢复时读回并 `applyThemeMode` 真正改全 App 配色（回传 `:1815`）；备份/恢复两侧的忽略开关都接上真实效果 | ZIP 映射 4 |
| 4 | `themeConfig` | 主题配置 | `themeConfig.json`、`config.xml` | 8 / 370 项内 52 键 | 主题设置页（`pages/ThemeSettingsPage.ets`，1070 行）+ 主题管理页（`pages/ThemeManagePage.ets`，441 行，`Index.ets:7979` 挂载）+ 护眼设置 | **部分接入**：护眼 6 键双向已验且 r301 起有真实渲染（色温覆盖层）；`themeConfig.json` 已双向接通 —— 写出在 `BackupRepository.ets:1176`（门控 `:1174`、`buildCurrentThemeConfigs` `:1175` 现算日夜两套 → `themeConfigsToJson` → `writeTextFile`），恢复在 `:1696`-`:1708`（`parseThemeConfigs` `:1703` → `saveThemeConfigs` `:1704` 整份覆盖），恢复后另补一次 `upThemeConfig` 装载。仍未映射的是 Android 配色/透明度 JSON 的逐项字段。界面侧只剩 4 处 `onUnavailableAction`（`ThemeSettingsPage.ets:548` 主题风格、`:550` 切换图标、`:724` 导航布局、`:726` 多窗布局），主题包管理已不是缺口。该类别在界面级表里是 91 行（81 已接 / 7 未接 / 3 不适用），逐行见[深色模式对照表](parity/ZIP-THEME.md) A/B/C/D/E/F | ZIP 映射 5 |
| 5 | `coverConfig` | 封面设置 | `coverRule.json`、`config.xml` | **样本缺** | 有封面设置页（`pages/AppCoverSettingsPage.ets`，729 行，14 条设置项，2 处 `onUnavailableAction`） | **部分接入（r334 实现段收口）**：14 个封面键已双向接进 `config.xml`（写出 `data/BackupRepository.ets:1089`-`:1095`（`coverSettingsToAndroid` 循环 `:1092` 覆盖 14 键），恢复 `restoreCoverSettings` 定义 `:2098`（`:2098`-`:2131`），调用点 `:1796`），键名与上游 PreferKey 一致；本类别 66 行里 58 行已接、6 行未接、2 行不适用，逐行见[封面设置总账](parity/ZIP-COVER.md)。6 行未接分别是 A1 仅 WiFi（`:86`）、A10 网络书籍角标（`:95`）、B15 旧版默认封面迁移（`:131`）、C6 规则求值（`:146`）、C9 备份开关（`:149`）、D18 预加载（`:180`）——A1、A10 受本机无网络图片加载限制，B15 缺迁移对象（`CoverSettings.defaultCover` 全仓无人写值），C6、C9、D18 随规则引擎与预加载；`coverRule.json` 的 ZIP 读写由批 1 / 批 2 接上：写出在 `data/BackupRepository.ets` 的 coverConfig 段（`CoverRuleRepository.load` 后按 `isDefaultCoverRule` 判断，改过规则才写，沿用上游 `BookCover.getConfig()?.let` 的口径），恢复在 restore 的 `coverRule.json` 分支（`parseCoverRule` 逐字段补齐 9 字段后 `CoverRuleRepository.save` 落私有存储）；C8 这一行已于 2026-11-09 在 `parity/ZIP-COVER.md` 一并改判 `已接` | 待接；相册目录另计 `不进备份` |
| 6 | `bookshelfLayout` | 书架布局 | `config.xml` | 370 项内 41 键 | 书架布局有完整仓储（`data/BookshelfLayoutRepository.ets`），界面面板 12 条目（`pages/BookshelfPage.ets:573-637`） | **部分接入（r327 重核）**：写出 37 键（`data/BackupRepository.ets:832` 门控、`:834`-`:870`，原记 9 键与 13 键都远少于实际），读入 39 键（`entry/src/main/ets/data/BackupRepository.ets:2066`-`:2072` 25 整型 + `:2078`-`:2080` 13 布尔 + `:2086` 的 `bookshelfSelectedGroupId`）；界面级 122 行里 76 已接 / 43 未接 / 3 不适用（r331/r332 落地 38 行后），逐行见[书架布局总账](parity/ZIP-BOOKSHELF-LAYOUT.md) | ZIP 映射 6 |
| 7 | `showRss` | 显示订阅 | `config.xml` | 370 项内 1 键 | 订阅页 UI 已有 | **已接入（批 2）**：写出 `BackupRepository.ets:1134`-`:1139` 按运行时真值 upsert 布尔键、恢复 `restoreShowRss` 定义 `:689`、读键 `:694` `readXmlBoolean`、回传 `:1816`，设备真包往返已验；界面侧接线待排期 | 待接界面侧 |
| 8 | `threadCount` | 线程数 | `config.xml` | 370 项内 1 键 | **无对应概念**（HOS 无并发线程数设置） | **未接入**（批 1 起走透传原样往返）：键值随 `config.xml` 原标签原值备份往返、仍不落原生功能，值仅供上游读回 | 安全兼容 |
| 9 | `mangaConfig` | 漫画设置 | `config.xml` | 370 项内 32 键 | 仅设置页有漫画相关条目文字，无漫画阅读 | **未接入**（批 1 起走透传原样往返）：32 个键随 `config.xml` 原标签原值备份往返、仍不落原生功能，值仅供上游读回 | 安全兼容；漫画业务候选 |
| 10 | `bookmark` | 书签 | `bookmark.json`、`bookMarking.json` | 344 / **样本缺 `bookMarking`** | 原生书签与标注仓储、阅读入口 | **已接入**：N 端双向验证通过（新增 1、覆盖 1），合并语义 | ZIP 映射 3 |
| 11 | `bookGroup` | 书架分组 | `bookGroup.json` | 28 | 原生分组模型、管理、编辑与筛选 | **已接入**：根级 JSON 可导出导入；外部 ZIP 冲突合并待验 | 已盘，见[书架对照表](parity/BOOKSHELF.md) A3 |
| 12 | `bookSource` | 书源 | `bookSource.json` | 904 | 数据层有 `book_sources` 表（`RdbSchema.ets:462`）与 `BookSourceRepository`；规则解释与抓取未迁移 | **已接入（数据层）**：恢复 `:1421` → `BookSourceImporter.parse` → `BookSourceRepository.importRules`（合并语义）；写出 `:772`。不执行规则、不联网 | 安全兼容 11；抓取业务候选 |
| 13 | `rssSource` | 订阅源 | `rssSources.json` | 28 | 数据层有 `rssSources` 表（`RdbSchema.ets:474`）与 `RssSourceRepository`；订阅页 UI 已有，抓取未迁移 | **已接入（数据层）**：恢复 `:1439` → `RssSourceImporter.parse` → `RssSourceRepository.importRules`（合并语义）；写出 `:780`。不执行规则、不联网 | 安全兼容 12；抓取业务候选 |
| 14 | `rssStar` | RSS 收藏 | `rssStar.json` | **样本缺** | 数据层有 `rssStars` 表（`RdbSchema.ets:485`）与 `RssStarRepository`；无界面 | **已接入（数据层）**：恢复 `:1457` → `RssStarImporter.parse` → `RssStarRepository.importRules`（合并语义，跨 origin+link 判重）；写出 `:788`。不联网 | 安全兼容 |
| 15 | `replaceRule` | 替换规则 | `replaceRule.json` | 40 | 规则模型/仓储 + 阅读时替换链路 | **已接入**：写出根级 JSON、恢复逐条导入；非空应用备份往返待验 | ZIP 映射 7 |
| 16 | `readRecord` | 阅读记录 | `readRecord.json`、`readRecordDetail.json`、`readRecordSession.json` | 575 / 313 / **39376** | 原生会话、日明细、按书汇总三层已接通 | **已接入**：三条链路 `:1710`/`:1711`/`:1718`/`:1720` 具名解析，末尾 `:1748`-`:1749` 交 `ReadRecordRepository.restoreFromBackup`，事务内合并写库（定义 `data/ReadRecordRepository.ets:1069`） | ZIP 映射 6 |
| 17 | `searchHistory` | 搜索历史 | `searchHistory.json` | 737 | 阅读器搜索历史有原生仓储（`search_content_history` 表），但那是**书内搜索**，与上游此条目的全局关键词池不是同一件事 | **不适用**：上游 `searchHistory.json` 装 `SearchKeyword`（全局搜索关键词池，表 `search_keywords`），本地无此入口、无此表；判据见 [ZIP 兼容总账](parity/STATUS.md) 批 4 节 | ZIP 映射 8；语义错配，待上游口径 |
| 18 | `sourceSub` | 书源订阅 | `sourceSub.json` | **样本缺** | 数据层有 `ruleSubs` 表（`RdbSchema.ets:499`）与 `RuleSubRepository`；有页面壳 | **已接入（数据层）**：恢复 `:1475` → `RuleSubImporter.parse` → `RuleSubRepository.importRules`（合并语义，按 id 判重）；写出 `:796`。不联网、不做 import 分流 | 安全兼容 |
| 19 | `txtTocRule` | TXT 目录规则 | `txtTocRule.json` | 40 | 规则仓储、管理页、切章、分卷、书架更新目录 | **已接入**：合成 ZIP 单条恢复与空规则备份有记录；非空应用备份往返待验 | ZIP 映射 9 |
| 20 | `httpTTS` | HTTP TTS | `httpTTS.json`、`httpTtsVoices.json` | 1 / 1 | 朗读设置界面存在，TTS 服务与播放未迁移；数据层已有 `httpTTS` / `read_aloud_voices` 两张表与仓储 | **已接入（数据层）**：恢复 `:1556` `HttpTtsImporter.parseSources` → `HttpTtsRepository.importSources`，随后读同目录 `httpTtsVoices.json` → `ReadAloudVoiceRepository.replaceHttpVoices`（坏 JSON 只计 skipped、不清库）；写出 `:1187`/`:1196`。不连服务、不播放 | 安全兼容；TTS 业务候选 |
| 21 | `keyboardAssists` | 键盘辅助 | `keyboardAssists.json` | 32 | **无**（`grep keyboardAssists` 零命中） | **不适用**：上游只有存储无业务（`keyboardAssistsDao` 8 个方法里 6 个零引用、`ui/` 零命中），本地无对应能力可接；判据见 [ZIP 兼容总账](parity/STATUS.md) 批 3 节 | 安全兼容；键位业务候选 |
| 22 | `dictRule` | 字典规则 | `dictRule.json` | 28 | 列表页与编辑页有壳（`pages/ProfileSubPages.ets:1928` `DictionaryRulesPage`、`:2167` `DictionaryRuleEditPage`），界面未接线；数据层有 `dictRules` 表与 `DictRuleRepository` | **已接入（数据层，批 3）**：恢复 `:1538` → `DictRuleRepository.importRules`，写出 `:899` | 安全兼容 10；字典业务候选 |
| 23 | `homepageModules` | 首页模块 (JSON) | `homepageModules.json` | **样本缺** | 首页基础组件已实现，模块管理界面未迁移；数据层有 `homepage_modules` 表与 `HomepageModuleRepository` | **已接入（数据层，批 3）**：恢复 `:1601` → `HomepageModuleRepository.importRules`，写出 `:908` | 安全兼容 |
| 24 | `homepageCustomSets` | 首页自定义 | `homepageCustomSets.json` | 1 | 自定义集合管理界面未迁移；数据层有 `homepage_custom_sets` 表与 `HomepageCustomSetRepository` | **已接入（数据层，批 3）**：恢复 `:1619` → `HomepageCustomSetRepository.importRules`，写出 `:917` | 安全兼容；自定义业务候选 |
| 25 | `highlightRule` | 高亮规则 | `highlightRule.json` | **样本缺** | 规则模型、`highlightRules` 表、正则匹配、分页/滚动两渲染 | **已接入**：N 端双向验证通过；合并语义，与上游 `replaceAll` 不同 | ZIP 映射已验 |
| 26 | `highlightTagRule` | 标签规则 | `highlightTagRule.json` | **样本缺** | 列表页与编辑页有壳（`pages/ProfileSubPages.ets:2309` `HighlightTagRulesPage`、`:2533` `HighlightTagRuleEditPage`），界面未接线；数据层有 `highlight_tag_rules` 表与 `HighlightTagRuleRepository` | **已接入（数据层，批 3）**：恢复 `:1637` → `HighlightTagRuleRepository.importRules`，写出 `:926` | 安全兼容 |
| 27 | `tagGroupRule` | 标签分组规则 | `tagGroupRule.json` | **样本缺** | 无独立界面；数据层有 `tag_group_rules` 表与 `TagGroupRuleRepository` | **已接入（数据层，批 3）**：恢复 `:1655` → `TagGroupRuleRepository.importRules`，写出 `:935` | 安全兼容 |
| 28 | `server` | 服务器配置 | `servers.json` | 空文件 | WebDAV/服务端同步未迁移 | **仅归档**：数据不透明，不尝试解密或连接 | 安全兼容；WebDAV 业务候选 |

**统计（五档，合计 28）**：

| 档位 | 类数 | 类别 |
| --- | --- | --- |
| 已接入 | **18** | `themeMode`、`bookmark`、`bookGroup`、`replaceRule`、`txtTocRule`、`highlightRule`、`showRss`、`readRecord`、`httpTTS`、`dictRule`、`homepageModules`、`homepageCustomSets`、`highlightTagRule`、`tagGroupRule`、`bookSource`、`rssSource`、`rssStar`、`sourceSub` |
| 部分接入 | **5** | `localBook`、`readConfig`、`themeConfig`、`coverConfig`、`bookshelfLayout` |
| 未接入（本地有页面或概念，ZIP 键读写都没接） | **2** | `threadCount`、`mangaConfig` |
| 不适用（上游有、本地按规约判无对应依据） | **2** | `searchHistory`、`keyboardAssists` |
| 仅归档 | **1** | `server` |

「未接入」与「仅归档」的区别：前者本地有页面或概念、只是键值没接；后者连本地功能都没有，条目仅原样归档。两者对 Android 用户的实际结果一样 —— 换到 HarmonyOS 后这些设置不生效。`不适用` 是第三件事：不是「没做」，而是按 [盘点规约](./PARITY-RULES.md) 第三节判过、上游行为在本地没有对应依据。

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

状态修正：`bookGroup.json` 已列入原生分组映射，而不是“没有原生分组功能”；本地阅读记录三层仓储已接入，Android ZIP 历史也已在 `BackupRepository.ets:1748`-`:1749` 映射进这三层（见 28 类表第 16 行）。r255 在 E 端验证 `readConfig × themeConfig` 四种包含/忽略组合；这不代表所有阅读/主题字段或外部 Android ZIP 已完整往返。

## 按清单派活的依据

派活时最多有三份文档会被引用，分工必须说清，否则同一个问题会有三个答案：

| 文档 | 管什么 | 什么时候看 |
| --- | --- | --- |
| **本文** `BACKUP-RESTORE.md` | **28 类 ZIP 条目 ↔ 本地能力**的对齐状态：某类的 JSON/XML 条目恢复时会不会落到原生仓储，落到哪张表 | 派「实现某一类的 ZIP 恢复」时 |
| [ZIP 兼容总账](parity/STATUS.md) | 28 类的**三级兼容度**（读 / 写 / 忽略项）逐类打分，以及「涉及行」——每类在各对照表里落在哪一块、多少行 | 判断某类「算不算做完了」、该盘哪几块时 |
| [对照关键词](parity/KEYWORDS.md) | 每类的**上游检索词**，用来生成上游接触面文件清单 | 盘点某类时要碰哪些上游文件时 |

三者的键名必须完全一致，都取自 `BackupRepository.ets` 的 `categoryOptions`。

**冲突时以谁为准**：以代码（`categoryOptions`、`entry.name ===` 恢复分支、`preferenceKeysByCategory`）和实测为准，文档落后就改文档。本文 28 类表在 2026-10-30（r287）已与代码逐键对齐；`STATUS.md` 的分数仍来自更早的核实，用它之前先看它顶部的日期。

**派活时的最小信息集**，一份任务书里至少要给：

1. 类别键名（如 `themeMode`）与对应 ZIP 条目（`config.xml` 的 `themeMode` 键）
2. 本文表格里该类的「ZIP 接入」档位与「本地原生功能」现状——决定要不要先补本地页面
3. 该类在 `config.xml` 里的键名清单（`preferenceKeysByCategory` 有的话直接指过去，没有就现列）
4. 验收方式：**必须走真实样本 `测试\backup2026-10-22.zip` 的往返**，不是只看代码。样本缺该类条目时先造数据，别拿「代码写了」当验收

**一个已知的口径陷阱**：样本 `config.xml` 有 370 个偏好项，本地写出 105 个去重键、读入 137 个去重键（口径与分段见上文「写出侧 / 读入侧」两段）。按样本逐键比对，本地写出的 105 键里 **88 个**在样本中存在、**17 个**不在；读入的 137 键里 **105 个**在样本中存在、**32 个**不在。那 17/32 个不在样本 `config.xml` 里的键分两种：17 个（`textBold`、`textItalic`、`textShadow`、`underline*`、`shadow*`、`dotted*`）在上游是 `ReadBookConfig` 的字段、走 `readConfig.json` 而不是 `config.xml` 存（`help/config/ReadBookConfig.kt:760` 的 `"textBold" to textBold` 序列化段），本地为了少一份文件把它们也写进了 `config.xml`；另 13 个（`bookmarkBadgeImage`、`moreActionsConfig`、`titleBarCompact`、`swipeToAddBookmark` 等）是上游 `PreferKey` 有定义、但该设备的 `config.xml` 里还没被写过默认值。**「`config.xml` 已接入」不等于「370 项都接了」**，派活时说清是接哪几个键。各类别的**上游键数**为：`readConfig` 60、`themeConfig` 53、`bookshelfLayout` 39、`mangaConfig` 32、`coverConfig` 14，5 类合计 198 个键（另有 `themeMode`、`showRss`、`threadCount` 三个单键类别，28 类合计 201 个键），本地实际接了不到一半。详见下节。

### 对照表的「ZIP 类别」列怎么读

按类别派活时必然要查的几张表（[书籍总账](parity/BOOKSHELF.md)、[书签对照](parity/ZIP-BOOKMARK.md)、[阅读配置总账](parity/READER-CONFIG.md)、[TXT 阅读总账](parity/TXT-READER.md)、[书架布局总账](parity/ZIP-BOOKSHELF-LAYOUT.md)、[封面设置总账](parity/ZIP-COVER.md)、[深色模式总账](parity/ZIP-THEME.md)）都标了 `ZIP 类别`。任务书里引用这些行之前，先把下面五条读清，否则会从错误的基数起步。

**一、判据是「会动到哪个类别」，不是「数据落在哪」。**

`ZIP 类别` 回答的问题是：**这一行要改代码时，会动到哪个 ZIP 类别的键或文件**。它不回答「这行的数据存在哪个文件」。

两者差得很远。典型例子是书架卡片上的标签（[书籍总账](parity/BOOKSHELF.md) A1）：

```kotlin
// ui/main/bookshelf/BookItem.kt:888
if (settings.bookshelfShowTag && kindList.isNotEmpty())
```

`bookshelfShowTag` 属 `bookshelfLayout` 类（在 `BackupConfig.kt:319-357 bookshelfPrefKeys` 内），`kindList` 来自 `Book.kind` 属 `localBook` 类（落 `bookshelf.json`）。少任何一边标签都不显示，所以派给任一类都得看这一行——标成 `localBook / bookshelfLayout`。

按「数据落在哪」判会把这类跨类项严重低估：同一批行换判据，跨类从 3 行涨到 13 行。

**二、五档取值，`—`、`不备份`、`不进备份` 三者互不相同。**

| 取值 | 含义 | 派活影响 |
| --- | --- | --- |
| `<类别名>` | 该类别取消勾选后，这行的数据会丢 | 归该类别任务 |
| `A / B` | 跨类，改得动两边 | 派活时两边都要看，别只派一边 |
| `—` | **参与备份，但不受任何忽略开关控制** | 不属任何 28 类，按类别名派活**永远覆盖不到**，必须单独派 |
| `不备份` | 连 `config.xml` 都进不去 | 同上，且与备份兼容无关，属本地私有状态 |
| `不进备份` | **连 ZIP 都进不去**（r330 新增） | 数据既不是数据库表、也不在任何打包文件清单里，备份/恢复两侧都无对应物；与「备份兼容」无关，接它等于新做一套存储 |

`—` 的判定依据是上游 `help/storage/BackupConfig.kt:413 fun keyIsNotIgnore(key: String, isBackup: Boolean = false)` 的 `else -> true` 分支：不在五个类别数组里的键照样写进 `config.xml`，只是取消任何类别勾选都不会删掉它。真正永不备份的是 `alwaysIgnoredPreferenceKeys`（`BackupConfig.kt:11-30`，24 项，含 `PRIVATE_PASSWORD_SALT`/`PRIVATE_PASSWORD_VERIFIER` 等私密凭据）。

`不备份` 的判定依据是本地两个 DataStore 不相通：`data/local/preferences/LocalPreferences.kt:11` 的 `local_ui_status` 里的键，`help/storage/Backup.kt:258 val configMap = AppConfigStore.preferences.asMap()` 根本读不到（它只读 `settings`）。

**新增 `不进备份` 的理由**：`不备份`（`LocalPreferences.kt:11` 那套）说的是「键在 `local_ui_status` 里，`config.xml` 读不到」，它仍然是**一个键**的问题。而封面相册走的是 `getExternalFilesDir()/cover_albums/` 整个目录（`data/repository/CoverAlbumRepository.kt:49-53`）：不在 `help/storage/Backup.kt:156-220` 的任何 `dbIsNotIgnored` 分支里、`cover_albums` 不在 `BackupConfig.kt:96-102` 的 19 类 `dbIgnoreKeys` 里、`Backup.kt:85-98` 的 `backupFileNames` 里也没有 `albums.json`——**整个目录连 ZIP 都不进**。这两类的验收方式完全不同：前者验「`config.xml` 里有没有这个键」，后者验「解压 ZIP 后有没有这个目录」。混成一档会出现「以为相册跟着备份走了」这种误判。

**把这两档混为一谈是本项目返工最多的地方**：写成同一档会导致「以为某个设置跟着备份走了」或「以为某个设置需要兼容上游」。典型是选词菜单整个 F 块（[书签对照](parity/ZIP-BOOKMARK.md) 34 行）——`textSelectMenuConfig`、`expandTextMenu`、`showSelectMenuIcon` 三键在 `BackupConfig.kt` 全文零命中，属 `—`，按「实现书签」派活一行都覆盖不到。

**三、「零行」是「还没盘」，不是「已完成」，也不是「本地没有这个功能」。**

[ZIP 兼容总账](parity/STATUS.md) 的「涉及行」列有 11 类标为**零行**，分两种：**整个界面级盘点零行** 3 类（`server`、`highlightRule`、`mangaConfig`）；**读写已接通、只是界面明细尚未盘点** 8 类（`httpTTS`、`dictRule`、`homepageModules`、`homepageCustomSets`、`showRss`、`rssSource`、`rssStar`、`sourceSub`，单元格里写的是「明细仍零行」）。`bookmark`、`themeConfig`、`coverConfig` 各自归 [书签对照](parity/ZIP-BOOKMARK.md) A–E（83 行）、[阅读配置总账](parity/READER-CONFIG.md) F、[封面设置总账](parity/ZIP-COVER.md)（66 行）盘点，不计入本清单；`replaceRule`（6 行）、`txtTocRule`（5 行）、`themeMode`（19 行）已随总账逐轮复核补出行数，同样不在本清单里。（2026-11-09 复核：此前记的是「16 类零行」，把上述三类与 `searchHistory`、`keyboardAssists`（现判不适用、理由已写）一并算了进去。） （2026-11-10 批 1 补记：`threadCount` / `mangaConfig` 现经 `config.xml` 未知键透传原样往返，属备份链路等价、不新增界面明细，故 `mangaConfig` 仍留在「整个界面级盘点零行」3 类内、不出列，`threadCount` 仍归 [书籍总账](parity/BOOKSHELF.md) A2 的 1 行、本就不在本清单。）

派这类活时，正确做法是先用 `bash scripts/upstream-surface.sh <类别键名> <上游根>` 取出上游接触面清单，按「盘点单位是界面」（[盘点规约](PARITY-RULES.md)第二节）新开块，**不要**让执行方拿「表里没有这一行」当成「本地没有这个功能」或「已兼容」。

**四、未复核边界：老行是迁移前证据。**

当时的三张表里 `r277`–`r280` 写下的行——[书籍总账](parity/BOOKSHELF.md) A1–C 259 行、[阅读配置总账](parity/READER-CONFIG.md) A–G 189 行、[书签对照](parity/ZIP-BOOKMARK.md) A–E 83 行——是**迁移前证据，未逐行复核**（表头逐份写明）。重盘这些块要按块重新核对，不要在旧行上直接改状态，否则等于在未验数据上盖新章。

**五、有一整块 12 行全是 `—`，那不代表可以不管。**

[书籍总账](parity/BOOKSHELF.md) 的 **E 备份恢复块**（r295 新增，12 行）`ZIP 类别` 列全是 `—`：备份/恢复的流程本身不属于任何一个类别，取消任何勾选都不会让「备份按钮」消失。但它是 21 个存储层文件的唯一载体——这些文件**对 28 类关键词全部零命中**（`grep -cE "Bookmark|BookMarking" help/storage/Backup.kt` = 0，19 个类别在导出主文件里全以小写键名 `dbIsNotIgnored("bookmark")` 引用）。

按类别名派活永远覆盖不到这一层，`BookRestorePlanner.kt` 的 `booksToDelete` / `isRelocatedCopyOf` / `Available-Missing-Unknown` 三态就是这样长期漏在表外的。要动备份兼容，这一块必须单独派。

## 偏好键对齐差异（待移除）

本地 `entry/src/main/ets/data/BackupRepository.ets:501` 的 `preferenceKeysByCategory` 与上游 `help/storage/BackupConfig.kt` 的五个类别数组逐键比对（可复跑：拿 `PreferKey.kt` 常量值换算后求差集）。下表是批 1–3 改完后的实测值，不再是改前的盘点数：

| 类别 | 上游 | 本地 | 多出 | 缺失 |
| --- | --- | --- | --- | --- |
| `readConfig` | 60 | 60 | 0 | 0 |
| `themeConfig` | 53 | 53 | 0 | 0（r292 已补 `bookInfoAuthorSearchFallback`） |
| `bookshelfLayout` | 39 | 39 | 0 | 0 |
| `mangaConfig` | 32 | 32 | 0 | 0 |
| `coverConfig` | 14 | 14 | 0 | 0 |

`coverConfig` 这一行的 0/0 只说明**类别清单本身**对齐了（`data/BackupRepository.ets:568`-`:572` 的 14 个常量与 `BackupConfig.kt:396-411` 逐键相同），不代表这些键真的被读写。r330 核实：这份清单在本地**只用于过滤**（`data/BackupRepository.ets:2978` 的 `filterAndroidConfigXml` 把 14 个键当排除项）。**2026-11-09 复核后此段已被代码推翻**：`config.xml` 的写出已改为逐键 `upsertAndroidPreference`（`data/BackupRepository.ets:972`-`:1084` 为 `readConfig` 段、`:1089`-`:1095` 为封面段），封面 14 键现在**确实在写出列表里**；恢复侧 `restoreCoverSettings` 定义在 `data/BackupRepository.ets:2098` 并复用 `coverSettingsToAndroid`（`:2114`）、调用点 `:1796`。另有一层不一致：本地落盘用的是裸字段名（`showName`/`textColor`/`infoOrientation`…，见 `data/CoverSettingsRepository.ets:135-146`），与这份常量里的 `coverShowName`/`coverTextColor`/`coverInfoOrientation` 不同名——所以即便将来把 14 键加进白名单，也要先解决键名映射。逐行结论见[封面设置总账](parity/ZIP-COVER.md) E 块。

`readConfig` 原先多出的 25 个键已从类别数组移除（批 1，85 → 60），按性质分两类：

**一、上游有 `PreferKey` 常量、但不在任何类别数组（12 个）**

判定依据：上游 `help/storage/BackupConfig.kt:413 fun keyIsNotIgnore` 里不在任何类别数组的键走 `else -> true`，照样写进 `config.xml`。换句话说，取消「阅读界面」勾选时上游不会剔除这 12 个键，本地却因收进类别数组而剔除——与上游行为相反。这 12 个是：

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
| `system_typefaces` | `:103`（常量名 `systemTypefaces`，值 `system_typefaces`） |

其中 `system_typefaces` 旧文记「全仓无人读写（只被 `R.array.system_typefaces` 资源引用）」是错的：`app/src/main/java/io/legado/app/data/repository/ReadSettingsRepository.kt:176` 有 `settingsRepository.putInt(PreferKey.systemTypefaces, value)`、`:546` 有 `intPreferencesKey(PreferKey.systemTypefaces)`、`:680` 有 `PreferKey.systemTypefaces to systemTypefaces`；消费者还有 `LegacyReaderPageDecorationFactory.kt`、`LegacyReaderPaginationStyleFactory.kt`、`ReadBookScreen.kt`、`ReadStyleDelegate.kt`、`TypographyTabs.kt` 等。它是真在用的偏好键。

**二、不是 `PreferKey` 常量（13 个）**

`textItalic`、`textBold`、`textShadow`、`shadowRadius`、`shadowDx`、`shadowDy`、`shadowColor`、`shadowColorN`、`underline`、`underlineHeight`、`underlineColor`、`underlineColorNight`、`dottedLine`。判据是「**不是 `PreferKey` 常量**」，不是「全仓零命中」——实测 `textBold`、`underline`、`underlineColor` 在上游各有 1 处带引号字面量命中（分别见 `ReadBookConfig.kt`、`HtmlContent.kt`、`HighlightRule.kt` 的字段/样式名），其余 10 个 0；但它们没有一个在 `PreferKey.kt` 里被声明为 `const val … = "…"`。它们真正的家是 `readConfig.json`（上游 `ReadBookConfig.kt` 的 `Config` 数据类字段域），本地 `toAndroidReadConfig` 已经写对；恢复侧对这 13 个键保持 JSON 优先、`config.xml` 兜底的双读。批 2 删掉的是本地往 `config.xml` 多写的 13 行，不动 JSON 支路与双读结构。

**三、`bookshelfLayout` 39 = 39、多 0，无需改动**

`bookGroupStyle`（`PreferKey.kt:13`）与 `hideEmptyGroups`（`PreferKey.kt:14`）不在本地 `bookshelfLayout` 数组里，也不在上游 `bookshelfPrefKeys` 里；它们写在 `entry/src/main/ets/data/BackupRepository.ets:825`/`:826` 的无条件区（在 `bookshelfLayout` 门控之前），走的是上游 `else -> true` 的同一语义。实测本地 39 键与上游 39 键逐键完全一致，旧文「多 2 个」是错误断言，代码一行未动。界面侧见[书架布局总账](parity/ZIP-BOOKSHELF-LAYOUT.md) 的 F 块。

**四、`themeConfig` 缺失的 1 个**：`bookInfoAuthorSearchFallback`（`PreferKey.kt:252`，在上游 `themePrefKeys` 内）。r292 已补进 `BackupRepository.ets` 的 `themeConfig` 数组（现 53 = 上游 53），本任务未再动。

> **现状**（2026-11-10 批 1–3 后）：`themeConfig` 53=53；`readConfig` 已按批 1 从 85 删到 60，与上游 `readPrefKeys` 映射后逐键一致；`config.xml` 写出已删 13 个非 `PreferKey` 文字样式键（批 2）、补了 5 个漏写的 `PreferKey`（`progressBarBehavior` / `tocUiUseReplace` / `tocCountWords` / `clickImgWay` / `maxLengthWithNoToc`，批 3）；`bookshelfLayout` 39=39、代码未改。`underlinePadding` / `underlineExtend` / `dottedBase` / `dottedRatio` 四个键**仍未判定**：本地仍往 `config.xml` 写出（真包里 `grep -c` 各 1）、上游 `PreferKey` 无此常量、真 Android 样本 `config.xml` 里 `grep -c` 全 0；本任务按范围未扩大到它们，明确留待另开一轮。判断口径见 `docs/parity/BOOKSHELF.md` 表头「ZIP 类别」列的取值说明（`—` = 参与备份但不受任何忽略开关控制）。

