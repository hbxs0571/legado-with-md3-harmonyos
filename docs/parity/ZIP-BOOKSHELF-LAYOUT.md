# bookshelfLayout（书架布局）对照表

盘点日期 2026-11-05（r327）｜上游基线 `legado-with-MD3` @ `bba5c64`（2026-10-26）｜本地基线 `legado-with-md3-harmonyos` @ `c17a6d3`

## 本表覆盖什么、不覆盖什么

**覆盖**：`bookshelfLayout` 这一个 zip 类别在四个层面上的全部上游构成与本地落点——A 设置面板（`BookshelfConfigSheet.kt` 742 行的每一个可视条目）、B 卡片渲染（`BookItem.kt` 1090 行里由 settings 字段驱动的每一个可视元素）、C 布局矩阵（竖/横 × 书架/文件夹 × 网格/列表 的组合取值）、D 排序与筛选、E 书架主屏的页签栏 / 快速滚动条 / 批量更新 / 空态 / 加载态、F 字段全集与备份链路。

**不覆盖**：搜索框与搜索页（`BookController`、搜索界面）、书籍详情页、书籍管理页（`ui/book/manage/`）、主题配置页（`ThemeConfig.kt`）、RSS 排序页（`ui/rss/article/RssSort*`）——这四处只在与本类别的字段同名字段相交时被本表引用，它们的界面构成归各自类别的表。**卡片渲染与公共管线不属于任何 config.xml 类别，按盘点规约单独立块**，即本表 B 块。

## 「ZIP 类别」列怎么读

判据是「这一行要改代码时会动到哪个类别」，不是「数据落在哪里」。四档取值：

- `bookshelfLayout`：该键在上游 `help/storage/BackupConfig.kt:319-359` 的 `bookshelfPrefKeys`（39 键）内，受「书架布局」这个备份类别开关控制。
- `bookshelfLayout / themeConfig`：该键同时被主题包读写（`data/repository/ThemePackageSettingsRepository.kt`、`domain/model/settings/ThemeExportData.kt`），跨两类，标全。
- `—`：该键**不在** 39 键内，走 `help/storage/BackupConfig.kt:413 keyIsNotIgnore()` 的 `else -> true`——会进备份，但不受任何忽略开关控制。`—` 与 `不备份` 不是一回事。
- `不备份`：本表无此类行。

## 与 BOOKSHELF.md A1/A2 的边界（J3 结论：两边都写并注明，以后以本表为准）

`docs/parity/BOOKSHELF.md` 是**按界面**的全量盘点（A1 书架主屏与卡片 78 行、A2 书架设置面板 47 行），本表是**按类别**的深度盘点。两处关系定死如下：

1. **BOOKSHELF.md A1/A2 保留**，因为删掉对应行会让那两个块不再是「这个界面的完整构成」，违反[盘点规约](../PARITY-RULES.md)第四节第 4 条。本表不重复 A1 的**页面骨架行**（搜索框、更多菜单、返回手势、分页滚动容器本身），A1 也不重复本表的**字段级结论**。
2. **凡 bookshelfLayout 字段驱动的行，状态与验收以本表为准**。A1 里由本表接管的行：`BOOKSHELF.md:110`（紧凑模式副标题）、`:115`（书封阴影）、`:116`（网格封面宽度）、`:117`（列表封面宽度）、`:122`（来源标签）、`:123`（自定义标签行）、`:125`（列表模式简介）、`:126`（简介排版）、`:128`（最新章节）、`:129`（字数统计）、`:131`（书名居中）、`:132`（书名最大行数）、`:133`（书名小字号）、`:134`（列表分割线）、`:135`（列表卡片背景色）、`:136`（列表封面垂直居中）、`:137`（紧凑模式）、`:138`（拖拽重排）、`:139`（快速滚动条）、`:155`（横竖屏分别布局）；A2 里由本表接管的行：`BOOKSHELF.md:178`–`:181`、`:188`、`:190`、`:199`、`:210`、`:211`（九条已接）及其余全部未接行的**状态**。这些行以后不再单独改状态。
3. **A2 仍然算数的部分**：面板控件的**文案与选项数组**（`R.string` 名、`values-zh-rCN` 行号、`entryValues`）以 A2 为准；字段的**接线与落盘**以本表 A 块为准。改文案看 A2，改字段看本表。
4. **本表修正 A2 的三处旧结论**（取证材料标为 r277-r280 迁移前遗留）：
   - `BOOKSHELF.md:191`「紧凑标题字体 本地固定 13fp」与 `:192`「标题居中 本地固定左对齐」与 `:193`「网格封面宽度 本地固定尺寸」——三条均已被本地实现推翻：`entry/src/main/ets/pages/BookshelfPage.ets:468-470` 按 `bookshelfTitleSmallFont` 在 11/13 间取字号、`:753` 按 `bookshelfTitleCenter` 取 `TextAlign.Center/Start`、`:460-465` 按 `bookshelfGridCoverWidth` 夹取封面宽度。本表 B 块对应三行改判 `已接`。
   - `BOOKSHELF.md:163`「本地 `pages/BookshelfPage.ets:503-556`（9 项）、`model/BookshelfLayout.ets`（9 字段）」是旧数字：实为面板 `:573-637`、**12 个逻辑条目**（14 处调用）、**13 字段**（`entry/src/main/ets/model/BookshelfLayout.ets:7-34`）。
   - `BOOKSHELF.md:221` 把「书架更新线程数」的 ZIP 类别写成 `threadCount`：上游 `bookshelfRefreshingLimit` 在 `help/storage/BackupConfig.kt:351` 属 `bookshelfPrefKeys`，类别应为 `bookshelfLayout`。本表 A 块该行已按 39 键标。

---

## A 设置面板（`ui/main/bookshelf/BookshelfConfigSheet.kt` 742 行）

上游构成为 1 个面板标题（`:71`）＋ 5 个分组标题（`:82` 分组、`:103` 排序、`:129` 布局、`:558` 角标与信息、`:614` 其它）＋ 44 个一级条目 ＋ 1 个二级弹层（`BookshelfTagContentDialog` `:695-742`，3 个 `CheckboxItem`）。本地构成为 `entry/src/main/ets/pages/BookshelfPage.ets:573-637` 的 `LayoutSheetContent()`，4 个分区标题（`:584` 分组、`:592` 排序、`:598` 布局、`:625` 外观）＋ 12 个逻辑条目（14 处调用）。

| 上游能力 | 上游位置 | 本地位置 | 状态 | 差异说明 | 验收方式 | 备注 | ZIP 类别 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 分组样式下拉（0 分组 / 1 隐藏 / 2 文件夹） | `BookshelfConfigSheet.kt:84` | `BookshelfPage.ets:585-587` | 未接 | 本地是布尔开关，写值只有 0/1；`model/BookshelfLayout.ets:43-46` 的 `BOOK_GROUP_STYLE_OPTIONS` 只有两项，第 2 档「文件夹」无入口 | 面板里切换该开关，页签栏随之出现或消失；本地无任何入口可切到文件夹样式 | **要接** | — |
| 隐藏没有书籍的分组 | `BookshelfConfigSheet.kt:94` | `BookshelfPage.ets:588-590` | 已接 | 本地默认 `true`（`BookshelfLayout.ets:71`），过滤在 `BookshelfPage.ets:113-114`，计数在 `:118-123` | 建一个空分组后开启该项，页签栏不出现该分组；关闭后出现 | — | — |
| 排序方式下拉 | `BookshelfConfigSheet.kt:105` | `BookshelfPage.ets:593-594` | 已接 | 本地 7 项（`model/BookGroup.ets:39-47`，含 -1「默认」），上游 6 项（`values-zh-rCN/arrays.xml:143-150`）；比较键见 D 块 | 选「按书名」后卡片顺序按拼音重排 | — | bookshelfLayout |
| 排序方向下拉 | `BookshelfConfigSheet.kt:116` | `BookshelfPage.ets:595-596` | 已接 | 上游 `entryValues` `"0"`/`"1"`（`:123`），本地 `BOOKSHELF_SORT_ORDER_OPTIONS`（`BookshelfLayout.ets:55-58`）同为两项 | 切到「降序」后卡片顺序整体反转 | — | bookshelfLayout |
| 文件夹布局模式 | `BookshelfConfigSheet.kt:143` | — | 未接 | 本地无文件夹样式，无 `bookshelfFolderLayoutMode*` 字段（`BookshelfLayout.ets:7-34` 未查到） | 上游开「文件夹」样式后此项出现，切换后文件夹根视图在网格与列表间改变 | **要接** | bookshelfLayout |
| 文件夹·每行列数（网格） | `BookshelfConfigSheet.kt:164` | — | 未接 | 同上，无 `bookshelfFolderLayoutGrid*` | 改为 4 后文件夹卡片每行 4 个 | **要接** | bookshelfLayout |
| 文件夹·每行列数（列表） | `BookshelfConfigSheet.kt:186` | — | 未接 | 同上，无 `bookshelfFolderLayoutList*` | 改为 2 后文件夹列表每行 2 个 | **要接** | bookshelfLayout |
| 列表封面宽度（文件夹区） | `BookshelfConfigSheet.kt:202` | — | 未接 | 与下一处「列表封面宽度（书籍区）」是**同一字段** `bookshelfListCoverWidth` 在两个条件下各显示一次（`:204` 与 `:401` 同读同写），本地合成一条 | 调大后文件夹列表封面变宽 | **不接** | bookshelfLayout |
| 文件夹列表样式（分组 / 紧凑列表 / 横排封面数量） | `BookshelfConfigSheet.kt:220` | — | 未接 | 本地无 `bookshelfGroupListStyle`；上游 `entryValues` `"0"/"1"/"2"`（`:224`） | 选「横排封面数量」后出现下一项滑块，文件夹列表改横排封面 | **要接** | bookshelfLayout |
| 横排封面数量 | `BookshelfConfigSheet.kt:230` | — | 未接 | 本地无 `bookshelfGroupCoverCount`；上游仅当选 `"2"` 时出现（`:229`） | 改为 6 后文件夹列表每行显示 6 个封面 | **要接** | bookshelfLayout |
| 布局模式（网格 / 列表） | `BookshelfConfigSheet.kt:247` | `BookshelfPage.ets:599-607` | 已接 | 本地只有竖屏一套（`BookshelfLayout.ets:17` 一个键），写成 `LayoutMenuRow` 的两段式 if/else（`:599-607` 两分支各一次调用），把「当前值回显」和「选择」合成一条 | 选「列表」后每行只剩 1 个卡片，选「网格」后按列数铺开 | — | bookshelfLayout |
| 网格样式（标准 / 紧凑 / 仅封面） | `BookshelfConfigSheet.kt:273` | — | 未接 | 本地无 `bookshelfGridLayout`；上游仅 `layoutMode == 1` 时出现（`:267`） | 选「仅封面」后网格卡片不再显示书名 | **要接** | bookshelfLayout |
| 每行列数（书籍·网格） | `BookshelfConfigSheet.kt:285` | `BookshelfPage.ets:608-616` | 已接 | 本地步进器 1..6（`:610`），上游滑块；横屏那一支本地无对应键 | 改为 4 后网格每行 4 个封面 | — | bookshelfLayout |
| 标题小字号 | `BookshelfConfigSheet.kt:301` | `BookshelfPage.ets:622-623` | 已接 | 本地 11/13vp 二选一（`BookshelfPage.ets:468-470`） | 开启后卡片书名明显变小 | — | bookshelfLayout |
| 标题居中 | `BookshelfConfigSheet.kt:310` | `BookshelfPage.ets:620-621` | 已接 | 本地默认 `true`（`BookshelfLayout.ets:79`） | 开启后书名居中，关闭后左对齐 | — | bookshelfLayout |
| 网格封面宽度 | `BookshelfConfigSheet.kt:319` | `BookshelfPage.ets:626-628` | 已接 | 本地步长固定 +10、夹在 40..200（`:627-628`），上游滑块连续值 | 调大后网格封面明显变宽，上限受格子宽度约束（`BookshelfPage.ets:460-465`） | — | bookshelfLayout |
| 显示分隔线 | `BookshelfConfigSheet.kt:337` | — | 未接 | 本地无 `bookshelfShowDivider`；上游仅 `layoutMode != 1` 时出现（`:331`） | 列表模式下卡片之间出现横线 | **不接** | bookshelfLayout |
| 日间卡片背景颜色 | `BookshelfConfigSheet.kt:346` | — | 未接 | 本地无 `bookshelfCardColor`，卡片底色取自主题 | 改为米色后亮色模式下卡片底色变米色 | **要接** | bookshelfLayout / themeConfig |
| 夜间卡片背景颜色 | `BookshelfConfigSheet.kt:367` | — | 未接 | 本地无 `bookshelfCardColorDark` | 改为深灰后暗色模式下卡片底色变灰 | **要接** | bookshelfLayout / themeConfig |
| 精简详情（紧凑模式） | `BookshelfConfigSheet.kt:388` | — | 未接 | 本地无 `bookshelfLayoutCompact` | 开启后卡片只留封面与书名 | **要接** | bookshelfLayout |
| 列表封面宽度（书籍区） | `BookshelfConfigSheet.kt:399` | `BookshelfPage.ets:629-631` | 未接 | **面板与持久化已通，卡片渲染未接线**：面板写入 `:630-631`、仓储读写 `BookshelfLayoutRepository.ets:58-59`/`:86`/`:130`/`:150`、备份带出 `BackupRepository.ets:606`/`:1331`，但 `BookshelfPage.ets:745` 传给 `BookCover` 的 `maxWidth` 来自 `bookshelfCoverWidthLimit()`，该函数只用 `bookshelfGridCoverWidth`（`:462`） | 调大该项后书架外观不变 | **要接** | bookshelfLayout |
| 每行列数（书籍·列表） | `BookshelfConfigSheet.kt:409` | `BookshelfPage.ets:608-616` | 已接 | 本地步进器 1..5（`:614`）；与网格列数共用一条面板行、按 `bookshelfLayoutModePortrait` 二选一显示 | 切到「列表」后改为 2，每行 2 个卡片 | — | bookshelfLayout |
| 显示更多信息 | `BookshelfConfigSheet.kt:425` | — | 未接 | 本地无 `showBookIntro`；上游它同时是「封面垂直居中」「显示最新章节」「显示简介」「显示标签」四项的外层条件（`:434`） | 开启后列表卡片出现更多信息区 | **不接** | — |
| 封面垂直居中 | `BookshelfConfigSheet.kt:438` | — | 未接 | 本地无 `bookshelfListCoverCenter` | 开启后列表封面在卡片内垂直居中 | **不接** | bookshelfLayout |
| 显示最新章节 | `BookshelfConfigSheet.kt:447` | — | 未接 | 本地无 `bookshelfShowLatestChapter`；本地卡片唯一副信息是封面上的章节数角标（`components/BookCover.ets:193-200`），不是章节名 | 开启后卡片显示最新章节名 | **要接** | bookshelfLayout |
| 显示简介 | `BookshelfConfigSheet.kt:456` | — | 未接 | 本地无 `bookshelfShowIntro` | 开启后列表卡片显示简介文字 | **要接** | bookshelfLayout |
| 简介显示在封面和信息下方 | `BookshelfConfigSheet.kt:465` | — | 未接 | 本地无 `bookshelfListIntroBelowContent`；上游条件是 `bookshelfShowIntro && layoutMode == 0`（`:464`） | 开启后简介文字排到书名下方 | **不接** | bookshelfLayout |
| 简介行数 | `BookshelfConfigSheet.kt:477` | — | 未接 | 本地无 `bookshelfIntroMaxLines` | 设为 2 后简介两行截断 | **不接** | bookshelfLayout |
| 显示标签 | `BookshelfConfigSheet.kt:488` | — | 未接 | 本地无 `bookshelfShowTag`，卡片上无标签行 | 开启后卡片出现标签行 | **不接** | bookshelfLayout |
| 标签显示内容（二级面板入口） | `BookshelfConfigSheet.kt:510` | — | 未接 | 本地无对应入口，也无二级弹层 | 点击后弹出三个勾选框 | **不接** | bookshelfLayout |
| 自定义标签颜色 | `BookshelfConfigSheet.kt:517` | — | 未接 | 本地无标签体系；上游该开关绑的是 `enableCustomTagColors`（形参 `:56`），不属 BookshelfSettings 51 字段 | 开启后标签颜色可自选 | **不接** | themeConfig |
| 管理标签颜色 | `BookshelfConfigSheet.kt:524` | — | 未接 | 同上，绑的是 `showLabelColorManage`（`:65`） | 打开配色管理页可增删颜色 | **不接** | themeConfig |
| 标题最大行数 | `BookshelfConfigSheet.kt:539` | `BookshelfPage.ets:617-619` | 已接 | 本地步进器 1..5（`:618-619`），写入 `bookshelfTitleMaxLines` 后用于 `:750` | 设为 1 后长书名单行省略号 | — | bookshelfLayout |
| 封面阴影 | `BookshelfConfigSheet.kt:549` | `BookshelfPage.ets:632-633` | 已接 | 本地传给 `BookCover.shadowEnabled`（`BookshelfPage.ets:743`），消费在 `components/BookCover.ets:223-225` | 开启后封面右下出现投影 | — | bookshelfLayout |
| 显示未读标志 | `BookshelfConfigSheet.kt:560` | — | 未接 | 本地无 `showUnread`，也无未读概念 | 开启后封面角上出现未读数字 | **不接** | — |
| 显示新章节更新标志 | `BookshelfConfigSheet.kt:569` | — | 未接 | 本地无 `showUnreadNew` | 有新章节时封面出现红点 | **不接** | — |
| 显示等待更新数量 | `BookshelfConfigSheet.kt:578` | — | 未接 | 本地无 `showWaitUpCount` | 开启后卡片显示等待更新本数 | **不接** | — |
| 显示分组书籍数量 | `BookshelfConfigSheet.kt:587` | — | 未接 | 本地无 `showBookCount`；本地分组卡片不显示本数 | 开启后分组卡片显示「N 本」 | **不接** | — |
| 显示上次更新时间 | `BookshelfConfigSheet.kt:596` | — | 未接 | 本地无 `showLastUpdateTime` | 开启后卡片显示「N 天前更新」 | **不接** | — |
| 显示书籍类型 | `BookshelfConfigSheet.kt:605` | — | 未接 | 本地无 `showTip` | 开启后封面左下出现「音频/漫画/本地」小标 | **不接** | — |
| 搜索按钮优先打开搜索页面 | `BookshelfConfigSheet.kt:616` | — | 未接 | 本地无 `bookshelfSearchActionDirectToSearch`；本地搜索按钮单击即进搜索、无长按分流（`BookshelfPage.ets:756-765` 的卡片手势里未查到搜索分流） | 开启后点搜索按钮直接进搜索页，关闭后先筛选 | **要接** | bookshelfLayout |
| 显示快速滚动条 | `BookshelfConfigSheet.kt:626` | — | 未接 | 本地无 `showBookshelfFastScroller`，书架 `scrollBar(BarState.Off)` 写死（`BookshelfPage.ets:772`） | 开启后书架右侧出现可拖动滚动条 | **要接** | — |
| 显示更多分组按钮 | `BookshelfConfigSheet.kt:635` | — | 未接 | 本地无 `shouldShowExpandButton`，页签栏无右端按钮 | 开启后页签栏右端出现「更多」图标 | **不接** | — |
| 书架更新数量限制 | `BookshelfConfigSheet.kt:644` | — | 未接 | 本地无 `bookshelfRefreshingLimit`，也没有批量更新入口 | 改为 8 后一次批量更新只处理 8 本 | **不接** | bookshelfLayout |
| 二级弹层·用户标签 | `BookshelfConfigSheet.kt:711` | — | 未接 | 本地无二级弹层（`BookshelfTagContentDialog` 在本地 5 个目标文件内未查到对应）；上游写 `bookshelfShowCustomTags`（`:732`） | 勾选后标签行多一项「用户标签」 | **不接** | bookshelfLayout |
| 二级弹层·书源分类 | `BookshelfConfigSheet.kt:716` | — | 未接 | 同上，写 `bookshelfShowSourceTags`（`:733`） | 勾选后标签行多一项「书源分类」 | **不接** | bookshelfLayout |
| 二级弹层·字数 | `BookshelfConfigSheet.kt:721` | — | 未接 | 同上，写 `bookshelfShowWordCount`（`:734`） | 勾选后标签行多一项字数 | **不接** | bookshelfLayout |

**A 块条件出现链**（写实现时按这个顺序判断）：`:140` `bookGroupStyle == 2` 才出现文件夹布局模式 → `:214-216` `bookGroupStyle == 2 && folderLayoutMode == 0` 才出现文件夹列表样式 → `:229` `bookshelfGroupListStyle == 2` 才出现横排封面数量；`:267` `layoutMode == 1` 才出现网格样式；`:331` `layoutMode != 1` 才出现显示分隔线；`:434` `showBookIntro` 是「封面垂直居中/显示最新章节/显示简介/显示标签」四项的外层；`:464` 简介位置需 `bookshelfShowIntro && layoutMode == 0`；`:474` 简介行数需 `bookshelfShowIntro`；`:496` 标签内容与自定义标签颜色需 `bookshelfShowTag`；`:523` 管理标签颜色需 `enableCustomTagColors`。

---

## B 卡片渲染（`ui/main/bookshelf/BookItem.kt` 1090 行）

上游 `BookItem.kt` 直接读 22 个 settings 字段，另有 7 个字段由 `BookshelfScreen.kt` 读出后以参数传入（`gridStyle`/`isCompact`/`titleSmallFont`/`titleCenter`/`titleMaxLines`/`coverShadow`/`layoutMode`）。下图各行按**卡片上的可视元素**列，一行一个元素。

| 上游能力 | 上游位置 | 本地位置 | 状态 | 差异说明 | 验收方式 | 备注 | ZIP 类别 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 网格卡片书名位置（标准=封面下方，紧凑=封面内白字） | `BookItem.kt:110`（`gridStyle == 1`）、`:135`（`gridStyle == 0`） | — | 未接 | 本地没有网格样式分档，书名固定在封面下方（`BookshelfPage.ets:749-754`） | 选「仅封面」后网格卡片封面内出现白字标题 | **要接** | bookshelfLayout |
| 网格封面宽度 | `BookItem.kt:839`（书籍）、`:484`（分组）、`:1025`（锁定书） | `BookshelfPage.ets:460-465` → `:745` → `components/BookCover.ets:238` | 已接 | 本地只有「上限」语义：`Math.min(格子宽度, 配置值)`（`BookshelfPage.ets:464`），上游无此夹取 | 面板调大网格封面宽度，卡片封面变宽到格子宽度为止 | — | bookshelfLayout |
| 列表封面宽度 | `BookItem.kt:965`（书籍）、`:549`（分组）、`:1041`（锁定书） | — | 未接 | 上游只在列表分支读（`:846` 进入 `BookshelfListItem` 后 `:965`）；本地无列表卡片，也无任何渲染代码读该字段 | 切到列表模式后调该项，列表封面宽度随之变化 | **要接** | bookshelfLayout |
| 书名小字号 | `BookItem.kt:113`（labelSmall/labelMedium） | `BookshelfPage.ets:468-470` → `:749` | 已接 | 本地 11vp / 13vp 二值；上游用两个 Material 字号档 | 开启后书名从 13 号变 11 号 | — | bookshelfLayout |
| 书名居中 | `BookItem.kt:117`、`:141` | `BookshelfPage.ets:753` | 已接 | 本地只对书名 `Text` 设 `textAlign` | 开启后书名居中，关闭后靠左 | — | bookshelfLayout |
| 书名最大行数 | `BookItem.kt:139`、`:216` | `BookshelfPage.ets:750` | 已接 | 本地 `maxLines` 直接取字段值 | 设为 1 后长书名单行省略 | — | bookshelfLayout |
| 封面阴影 | `BookItem.kt:274`（`if (coverShadow) Modifier.shadow(4.dp, ...)`） | `BookshelfPage.ets:743` → `components/BookCover.ets:223-225` | 已接 | 本地 `shadow` 参数与半径未与上游逐值核对 | 开启后封面右下出现投影 | — | bookshelfLayout |
| 列表卡片背景色（日/夜二选一） | `BookItem.kt:176`、`:570` | — | 未接 | 本地卡片底色取自主题，无 `bookshelfCardColor` / `bookshelfCardColorDark` | 设为米色后亮色模式卡片底色变米色，暗色模式取夜间色 | **要接** | bookshelfLayout / themeConfig |
| 列表项封面纵向对齐 | `BookItem.kt:194` | — | 未接 | 本地无列表卡片，无该对齐分支 | 关闭后列表封面顶部对齐 | **不接** | bookshelfLayout |
| 列表项底部分隔线 | `BookItem.kt:253`、`:663` | — | 未接 | 本地网格卡片间无分隔线概念 | 列表模式下卡片之间出现 0.5dp 横线 | **不接** | bookshelfLayout |
| 分组封面阴影 | `BookItem.kt:349` | — | 未接 | 本地分组卡片不存在独立封面容器，`bookshelfCoverShadow` 只作用在书籍卡片上 | 分组卡片封面也出现投影 | **不接** | bookshelfLayout |
| 分组列表样式分支（横向封面 / 紧凑 / 普通） | `BookItem.kt:504`（`== 2` → `BookGroupItemHorizontalCovers`）、`:530`（`== 1` → `isCompact = true`） | — | 未接 | 本地无 `bookshelfGroupListStyle`，分组从不在书架网格里以卡片形式出现 | 选「横排封面数量」后分组卡片改横排封面 | **要接** | bookshelfLayout |
| 分组横排封面数量 | `BookItem.kt:627`、`:628`（`previewBooks.take(coverCount)`）、`:657`（不足补 `Spacer`） | — | 未接 | 本地无 `bookshelfGroupCoverCount` | 改为 6 后分组卡片一行 6 个封面 | **要接** | bookshelfLayout |
| 列表详情总开关（`showListDetails = layoutMode == 0 && !isCompact && settings.showBookIntro`） | `BookItem.kt:738` | — | 未接 | 本地无列表分支，也无 `showBookIntro` | 开启后列表卡片出现详情区 | **不接** | — |
| 列表简介文字 | `BookItem.kt:739` | — | 未接 | 本地无 `bookshelfShowIntro`，卡片不渲染简介 | 开启后列表卡片出现简介段落 | **要接** | bookshelfLayout |
| 简介行数 | `BookItem.kt:742`、`:922`、`:936` | — | 未接 | 本地无 `bookshelfIntroMaxLines`；上游 0 表示不限（`:1058`） | 设为 2 后简介两行截断 | **不接** | bookshelfLayout |
| 简介渲染位置（书名下方 / 底部） | `BookItem.kt:750` | — | 未接 | 本地无 `bookshelfListIntroBelowContent` | 开启后简介排到书名下方 | **不接** | bookshelfLayout |
| 未读数字角标 | `BookItem.kt:752` | — | 未接 | 本地封面角标是章节数（`components/BookCover.ets:193-200`），不是未读数 | 开启后封面出现未读数字 | **不接** | — |
| 新章节圆点 | `BookItem.kt:753`（`showUnread && showUnreadNew && book.isNew`） | — | 未接 | 本地无更新检测，红点依赖两个字段相与 | 有新章节时封面出现红点 | **不接** | — |
| 书籍类型标签 | `BookItem.kt:754` | — | 未接 | 本地无 `showTip` | 开启后封面左下出现类型小标 | **不接** | — |
| 标签内容三项（自定义标签/书源分类/字数） | `BookItem.kt:878-885` | — | 未接 | 本地无 `kindList`，无三个 `bookshelfShow*Tags`/`bookshelfShowWordCount` | 勾选后标签行分别多出对应一项 | **不接** | bookshelfLayout |
| 标签行 | `BookItem.kt:888`（`if (settings.bookshelfShowTag && kindList.isNotEmpty())`） | — | 未接 | 本地卡片无标签行 | 开启后卡片出现标签行 | **不接** | bookshelfLayout |
| 最新章节行 | `BookItem.kt:942` | — | 未接 | 本地无 `bookshelfShowLatestChapter` | 开启后卡片显示最新章节名 | **要接** | bookshelfLayout |
| 最后更新时间文字 | `BookItem.kt:944` | — | 未接 | 本地无 `showLastUpdateTime` | 开启后卡片显示「N 天前」 | **不接** | — |
| 紧凑模式（`isCompact`） | `BookItem.kt:230`（`if (!isCompact)` 才渲染 desc）、`:738` | — | 未接 | 本地无 `bookshelfLayoutCompact`，卡片恒为「封面＋书名」紧凑形，无「展开形」可比 | 关闭紧凑后卡片出现作者/简介等副信息 | **要接** | bookshelfLayout |
| 锁定书卡片（网格 / 列表两分支） | `BookItem.kt:1012`（网格 `:1025`）、`:1031`（列表 `:1041`） | — | 未接 | 本地无隐私书架锁定书卡片 | 锁定书封面按对应布局取各自列宽 | **不接** | bookshelfLayout |

---

## C 布局矩阵（竖/横 × 书架/文件夹 × 网格/列表）

上游 12 个布局字段（`BookshelfSettings.kt:27-38`），本地只有 3 个竖屏键（`model/BookshelfLayout.ets:17`、`:19`、`:21`）。取值分支在上游 `BookshelfScreen.kt:1698-1699`（书籍 `isLandscape`）与 `:524-525`（文件夹 `isLandscape`）；本地**没有任何横竖屏判断**：`entry/src/main/module.json5` 里 `orientation` 零命中，`entry/src/main/ets` 全目录 `isLandscape` 零命中，本地唯一在用的方向 API 是阅读页的 `entry/src/main/ets/pages/ReaderPage.ets:1003`、`:1016`（`window.setPreferredOrientation`），书架侧未调用过。

| 上游能力 | 上游位置 | 本地位置 | 状态 | 差异说明 | 验收方式 | 备注 | ZIP 类别 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 书籍·竖屏·布局模式（列表 / 网格） | `BookshelfScreen.kt:1702-1703` → `:1715`、`:1716` | `BookshelfPage.ets:599-607`（写）、`:419-427`（读） | 已接 | `bookshelfLayoutModePortrait == 0` 时本地只把列数换成 `bookshelfLayoutListPortrait`，渲染容器仍是 `Grid`（`:735`）、`GridItem`（`:737`），没有上游那套列表卡片（`BookItem.kt:846` `BookshelfListItem`） | 选「列表」后每行只剩 1 个卡片 | — | bookshelfLayout |
| 书籍·竖屏·网格列数 | `BookshelfScreen.kt:1707-1708` → `:1715` | `BookshelfPage.ets:420-421` → `:769` | 已接 | 本地另有上限 6（`:422-423`），上游无此上限 | 调为 4 后网格每行 4 个封面 | — | bookshelfLayout |
| 书籍·竖屏·列表列数 | `BookshelfScreen.kt:1712-1713` → `:1715` | `BookshelfPage.ets:421` → `:769` | 已接 | 本地取 1..5（`:608-616` 步进器上限 5，`:422` 再夹 5） | 切到列表后调为 2，每行 2 个卡片 | — | bookshelfLayout |
| 书籍·横屏·布局模式 | `BookshelfScreen.kt:1700-1701` → `:1715` | — | 未接 | 本地无 `bookshelfLayoutModeLandscape`，横竖屏不切换取值 | 横屏后书架按横屏设置的模式排版 | **要接** | bookshelfLayout |
| 书籍·横屏·网格列数 | `BookshelfScreen.kt:1705-1706` → `:1715` | — | 未接 | 本地无 `bookshelfLayoutGridLandscape` | 横屏后网格列数变为横屏设置值 | **要接** | bookshelfLayout |
| 书籍·横屏·列表列数 | `BookshelfScreen.kt:1710-1711` → `:1715` | — | 未接 | 本地无 `bookshelfLayoutListLandscape` | 横屏后列表列数变为横屏设置值 | **要接** | bookshelfLayout |
| 文件夹·竖屏·布局模式 | `BookshelfScreen.kt:528-529` → `:985`、`:1023` | — | 未接 | 本地无文件夹视图，`bookGroupStyle` 只能写 0/1 | 开「文件夹」样式后根视图在网格与列表间切换 | **要接** | bookshelfLayout |
| 文件夹·竖屏·网格列数 | `BookshelfScreen.kt:533-534` → `:985`、`:988`（`GridCells.Fixed(folderColumns.coerceAtLeast(1))`） | — | 未接 | 同上，无 `bookshelfFolderLayoutGridPortrait` | 改为 4 后文件夹卡片每行 4 个 | **要接** | bookshelfLayout |
| 文件夹·竖屏·列表列数 | `BookshelfScreen.kt:538-539` → `:985` | — | 未接 | 同上，无 `bookshelfFolderLayoutListPortrait` | 改为 2 后文件夹列表每行 2 个 | **要接** | bookshelfLayout |
| 文件夹·横屏·布局模式 | `BookshelfScreen.kt:526-527` → `:985` | — | 未接 | 同上 | 横屏后文件夹视图模式取横屏值 | **要接** | bookshelfLayout |
| 文件夹·横屏·网格列数 | `BookshelfScreen.kt:531-532` → `:985` | — | 未接 | 同上 | 横屏后文件夹网格列数取横屏值 | **要接** | bookshelfLayout |
| 文件夹·横屏·列表列数 | `BookshelfScreen.kt:536-537` → `:985` | — | 未接 | 同上 | 横屏后文件夹列表列数取横屏值 | **要接** | bookshelfLayout |
| 首屏封面预加载列数 | `ui/main/bookshelf/BookshelfCoverPreloader.kt:261-280`（列表时 1，网格时按横竖屏取 `bookshelfLayoutGrid*`，`:278` 乘预估可见行数并夹在 `MAX_PRELOAD_BOOKS`) | — | 未接 | 本地无封面预加载器；封面图由 `components/BookCover.ets` 各卡片自行加载 | 首屏滚动时封面不出现空窗 | **要接** | — |
| 横竖屏取值的公共入口（`Context.bookshelfLayoutMode` / `Context.bookshelfLayoutGrid`） | `utils/ContextExtensions.kt:470-482` | — | 不适用 | 上游这两个扩展属性**全仓无调用方**——`grep -rn 'bookshelfLayoutMode\b\|bookshelfLayoutGrid\b' --include=*.kt` 除定义处只剩 `BookshelfScreen.kt:1700`/`:1705`/`:1715`/`:1716`/`:1830` 的局部变量同名遮蔽；界面侧在 `:1698-1713` 自己按 `isLandscape` 重算。属「数据层无独立界面」，被 C 块前六行消费，无独立落点 | — | — | — |

---

## D 排序与筛选

上游两处排序实现：界面侧 `data/repository/BookshelfRepository.kt:9-50 sortBooks`（6 档）与 Web 服务出口 `api/controller/BookController.kt:63-70`（4 档，见「已排除」节）。本地 `entry/src/main/ets/data/BookshelfSort.ets:25-35` 是界面侧对照实现。

| 上游能力 | 上游位置 | 本地位置 | 状态 | 差异说明 | 验收方式 | 备注 | ZIP 类别 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 排序方式·按阅读时间（0） | `BookshelfRepository.kt:47-48`（`else -> sortedByDescending { it.durChapterTime }`） | `BookshelfSort.ets:38-56` | 已接 | 本地六档全在 `:38-56` 一个 `switch` 内 | 选「按阅读时间」后最近读过的书排最前 | — | bookshelfLayout |
| 排序方式·按更新时间（1） | `BookshelfRepository.kt:23-24`（`latestChapterTime`） | `BookshelfSort.ets:38-56` | 已接 | 同上 | 选「按更新时间」后最近更新的书排最前 | — | bookshelfLayout |
| 排序方式·按书名（2） | `BookshelfRepository.kt:26-29`（`o1.name.cnCompare(o2.name)`） | `BookshelfSort.ets:38-56`、`:78-84`（`cnCompare`） | 已接 | 本地自己实现 `cnCompare`（`:78-84`），未用平台排序器 | 选「按书名」后按拼音序排列 | — | bookshelfLayout |
| 排序方式·手动排序（3） | `BookshelfRepository.kt:31-32`（`sortedBy { it.order }`） | `BookshelfSort.ets:38-56` | 已接 | 本地按 `order` 升序 | 长按拖动改顺序后该顺序被保留 | — | bookshelfLayout |
| 排序方式·综合排序（4） | `BookshelfRepository.kt:34-40`（`maxOf(latestChapterTime, durChapterTime)`） | `BookshelfSort.ets:38-56`、`:59-63`（`latestOrRead`） | 已接 | 本地 `latestOrRead()` 取两者较大值 | 既更新过又读过的新旧混合排列符合预期 | — | bookshelfLayout |
| 排序方式·按作者（5） | `BookshelfRepository.kt:42-45`（`author.cnCompare`） | `BookshelfSort.ets:38-56` | 已接 | 同上，按作者拼音 | 选「按作者」后同作者的书聚在一起 | — | bookshelfLayout |
| 排序方向（升 / 降） | `BookshelfRepository.kt:20`（`isDescending = sortOrder == 1`）、`:22-48` 每档末尾反转 | `BookshelfSort.ets:27`（`isDescending = sortOrder === 1`） | 已接 | 本地同样在末尾按布尔反转整个列表 | 切「降序」后顺序整体反转 | — | bookshelfLayout |
| 分组自带排序覆盖全局 | `BookshelfRepository.kt:15-19`（`group?.bookSort >= 0` 时用组内值） | `BookshelfSort.ets:26`（`group.bookSort >= 0`） | 已接 | 优先级与上游一致，`BookshelfPage.ets:147` 有同义注释 | 给某组设「按书名」后只有该组按书名排 | — | bookshelfLayout |
| 排序选项文案与档数 | `values-zh-rCN/arrays.xml:143-150`（`bookshelf_px_0..5` 六项）、`values-zh-rCN/strings.xml:328-331`、`:1566-1567` | `model/BookGroup.ets:39-47`（`BOOK_SORT_OPTIONS` 七项） | 已接 | 本地多出「-1 默认」一档（`:40`），上游数组里没有 -1；多出这一档时不改变全局选择，只表示「未覆盖」 | 分组管理面板的排序下拉里能看到 7 项 | — | bookshelfLayout |
| 隐藏没有书籍的分组·过滤时机 | `BookshelfViewModel.kt:234-241`（`hideEmptyGroupsFlow`）、`:248-277`（`:250` `if (!hide) flowOf(emptySet())`）、`:279-291`（`:290` 按 `count == 0` 收 groupId）、`:312`、`:611`（`groups.filter { it.groupId !in hiddenIds }`） | `BookshelfPage.ets:113-114`、`:118-123`（计数）、`:131-134`（选中组被隐藏时回落「全部」） | 已接 | 本地是每次渲染即时过滤，上游走 Flow 缓存；本地另有「选中分组被隐藏时回落」的保护（`:131-134`） | 删光某组的书后页签栏不再出现该组 | — | — |
| 搜索按钮优先打开搜索页面（点击 / 长按分流） | `BookshelfScreen.kt:570`、`:577`（两处手势互换）、`:1343`（`val searchFirst = uiState.settings.bookshelfSearchActionDirectToSearch`） | — | 未接 | 本地无该字段，也无长按分流 | 开启后单击搜索按钮直接进搜索页，关闭后单击先进筛选态 | **要接** | bookshelfLayout |
| 排序值进 UI 状态 | `ui/main/bookshelf/BookshelfUiState.kt:142-144`（`bookGroupStyle`/`bookshelfSort`/`bookshelfSortOrder` 三个 UiState 字段，由 `BookshelfViewModel.kt:673-674`、`:736` 填入） | `BookshelfPage.ets:34`（`@Prop layout`）、`entry/src/main/ets/pages/Index.ets:190`（`@State bookshelfLayout`） | 已接 | 本地不另设 UiState 镜像字段，面板与卡片都直读同一个 `BookshelfLayoutSettings` 对象 | 改布局后面板与卡片同时反映新值 | — | — |

---

## E 书架主屏（页签栏 / 快速滚动条 / 批量更新 / 空态 / 加载态）

上游 `BookshelfScreen.kt` 1872 行里与 bookshelfLayout 相关的可视元素。本块的页面骨架（搜索框、更多菜单、返回手势、滚动容器本体）归 `BOOKSHELF.md` A1，本块只列由本类别字段驱动的元素。

| 上游能力 | 上游位置 | 本地位置 | 状态 | 差异说明 | 验收方式 | 备注 | ZIP 类别 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 分组页签栏（分组样式 = 0） | `BookshelfScreen.kt:784`（`if (bookGroupStyle == 0 && uiState.groups.isNotEmpty())`）、`:797-804`（`AppTabRow`） | `BookshelfPage.ets:719-726`（`bookGroupStyle === 0` 时横排 `ShelfFilter`） | 已接 | 本地页签是自绘横向 `Scroll`，上游是 `AppTabRow`；页签栏本体不直读其它 settings 字段（上游 `:784` 读的是 UiState 的 `bookGroupStyle`） | 书架顶部出现横排分组页签，点切换即换组 | — | — |
| 隐藏页签时的「当前分组 + 切换分组」 | `BookshelfScreen.kt:551`（`uiState.bookGroupStyle != 0`） | `BookshelfPage.ets:728-732` | 已接 | 本地显示「当前分组：X」并给一个跳分组管理面板的入口 | 开启「隐藏分组页签」后页签栏变成一行当前组名 | — | — |
| 文件夹根视图（分组样式 = 2） | `BookshelfScreen.kt:983`（`bookGroupStyle == 2 && isRoot && ...`）、`:1023`（`if (bookshelfFolderLayoutMode == 0)`）、`:512`（`PredictiveBackHandler(enabled = bookGroupStyle == 2 && ...)`） | — | 未接 | 本地 `bookGroupStyle` 只可能为 0/1（`BookshelfPage.ets:587` 写 `hidden ? 1 : 0`），无文件夹根视图、无对应的返回手势处理 | 开「文件夹」样式后书架根层显示分组卡片，点进去看到该组书籍，返回回到根层 | **要接** | — |
| 页签栏右端「更多分组」按钮 | `BookshelfScreen.kt:806`（`val showExpandButton = uiState.settings.shouldShowExpandButton`）、`:807-821` | — | 未接 | 本地无该字段，页签栏右端无按钮 | 开启后页签栏右端出现向下箭头，点开是完整分组列表 | **不接** | — |
| 快速滚动条 | `BookshelfScreen.kt:1723`（`val showFastScroll = uiState.settings.showBookshelfFastScroller`）、`:1774`（传参）、`:1752`/`:987`（`FastScrollLazyVerticalGrid`）、`:1004`（文件夹侧） | `BookshelfPage.ets:772`（`scrollBar(BarState.Off)` 写死） | 未接 | 本地关闭滚动条且无开关；上游是带字母索引的快速滚动条，不是系统滚动条 | 开启后书架右侧出现可拖动并可快速跳转的滚动条 | **要接** | — |
| 分组根目录书籍数量文字 | `BookshelfScreen.kt:1011`（`if (uiState.settings.showBookCount && !groupLocked)`） | — | 未接 | 本地无 `showBookCount`，分组卡片不存在 | 开启后文件夹卡片右上显示「N 本」 | **不接** | — |
| 等待更新数量 | `BookshelfViewModel.kt:1289`（`postUpBooksCount`，`:1293-1295` 关闭时返回 0） | — | 未接 | 本地无 `showWaitUpCount`，无批量更新队列 | 开启后页签栏/卡面显示「待更新 N 本」 | **不接** | — |
| 批量更新数量限制 | `BookshelfViewModel.kt:1114-1115`（`refreshBooks` 的 `take(limit)`）、`:1165-1166`（`upToc` 同型） | — | 未接 | 本地无 `bookshelfRefreshingLimit`，也没有批量更新入口 | 设为 8 后一次批量更新只处理 8 本，其余排队 | **不接** | bookshelfLayout |
| 打开书架时自动刷新目录 | `BookshelfViewModel.kt:786`（init 里 `if (autoRefreshBook) { upAllBookToc() }`） | — | 未接 | 本地无 `autoRefreshBook`（对应上游键是 `auto_refresh`，`constant/PreferKey.kt:146`）；本地无在线书源，目录刷新无对象 | 开启后每次进书架自动拉一遍所有书的目录 | **不接** | — |
| 记住上次所在分组 | `BookshelfViewModel.kt:110`、`:734`、`:763-764`（读 `saveTabPosition`）、`:955`（`changeGroup` 写回） | — | 未接 | 本地无 `saveTabPosition`，进书架恒落「全部」 | 切到某分组后退出再进书架，仍停在该分组 | **要接** | — |
| 加载中对话框 | `BookshelfScreen.kt:1575-1602`（`if (uiState.isLoading)` → `AppCircularProgressIndicator`） | — | 未接 | 本地书架无全屏加载态，导入大文件时无进度对话框 | 导入大文件时出现加载对话框并可取消 | **不接** | — |
| 空态文案与表情切换 | `BookshelfScreen.kt:1670-1693`（`:1684-1693` 空态，`:1680` `bookshelf_empty_global_search` 为搜索无结果态） | `BookshelfPage.ets:788-799` | 已接 | 本地 7 个表情可点换（`:791-794`），三种文案（`:795-796`） | 清空书架后显示表情与提示，点表情可换一个 | — | — |
| 空态里的「全局搜索」按钮 | `BookshelfScreen.kt:1675-1683`（`:1673` `if (uiState.isSearch)`） | `BookshelfPage.ets:795`（只换文案） | 未接 | 本地只把文案换成「没有匹配的书籍」，没有跳全局搜索的按钮 | 搜索无结果时显示按钮，点它跳到全局搜索 | **要接** | — |
| 分页惰性渲染 | `BookshelfScreen.kt:1669`（`!isCurrentPage` 时直接 return） | — | 未接 | 本地整屏一次性 `ForEach` 渲染所有可见书 | 非当前分组的书不参与渲染，滚动不掉帧 | **不接** | — |

---

## F 字段全集与备份链路

| 上游能力 | 上游位置 | 本地位置 | 状态 | 差异说明 | 验收方式 | 备注 | ZIP 类别 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 书架设置字段全集（51 字段） | `domain/model/settings/BookshelfSettings.kt:6-56` | `entry/src/main/ets/model/BookshelfLayout.ets:7-34`（13 字段） | 未接 | 本地 13 个名字在上游 51 名单里全部存在（无本地独有字段）；反过来上游有 38 个名字本地未声明，逐项见下方「字段差集」 | 面板与卡片能读写到上游每一个字段 | **要接** | — |
| 字段名 ↔ 偏好键字符串的对应 | `constant/PreferKey.kt:58`（`bookshelfLayout`）、`:59`（`bookshelfLayoutModePortrait = "bookshelfLayoutPortrait"`）、`:60`（`bookshelfLayoutModeLandscape = "bookshelf_layout_landscape"`）、`:72`（`saveTabPosition`）、`:73`（`bookshelfSelectedGroupId`）、`:146`（`autoRefresh = "auto_refresh"`） | `entry/src/main/ets/data/BookshelfLayoutRepository.ets:42-43`（读）、`:78`（写）、`:114-115`（merge）、`:142`（toAndroidValues） | 已接 | 本地 `bookshelfLayoutModePortrait` 落盘的键名是 `'bookshelfLayoutPortrait'`（无 `Mode`），与上游 `PreferKey.kt:59` 的字符串值一致；本地无 Landscape / `auto_refresh` / `bookshelfSelectedGroupId` 三个键 | 导出备份后 config.xml 里是 `bookshelfLayoutPortrait` 而不是字段名 | — | bookshelfLayout |
| 设置对象 ↔ 偏好读写网关 | `data/repository/BookshelfSettingsRepository.kt:34-89`（`toBookshelfSettings`）、`:91-143`（`toPrefMap`，`:141` `PreferKey.autoRefresh to autoRefreshBook`、`:142` `bookshelfSelectedGroupId to saveTabPosition`） | `entry/src/main/ets/data/BookshelfLayoutRepository.ets:30-66`（`load`）、`:69-93`（`save`，`:74-86` 13 个 `store.put`、`:87` `flush()`）、`:101-133`（`mergeFromAndroidValues`）、`:136-152`（`toAndroidValues`） | 已接 | 本地 13 键全部双向落盘；上游 `saveTabPosition` 实际写的是 `bookshelfSelectedGroupId` 键（`:142`），本地无此键 | 改任一布局项后杀进程重进仍在 | — | bookshelfLayout |
| 上游兼容层（`@Deprecated` 转发） | `ui/config/bookshelfConfig/BookshelfConfig.kt:6`（`@Deprecated`）、`:9-45`（`get()` 逐字段转发到 settings 网关） | — | 不适用 | 上游的历史兼容层，为旧代码保留同名取值；本地新仓库没有需要兼容的历史键，属「数据层无独立界面」，被上方「设置对象 ↔ 偏好读写网关」行消费 | — | — | — |
| 上游兼容取值（AppConfig 的 4 个同名属性） | `help/config/AppConfig.kt:89-92`（`bookshelfLayoutModePortrait`/`ModeLandscape`/`GridPortrait`/`GridLandscape`）、`:98`（`autoRefreshBook = other.autoRefresh`） | — | 不适用 | 同上，是 `AppConfigStore` 上的转发属性，无界面；落点同上 | — | — | — |
| 备份写出：39 键类别清单 | `help/storage/BackupConfig.kt:319-359`（`:320` `bookshelfLayout` 类别键本身，`:321-358` 其余 38 个字段键） | `entry/src/main/ets/data/BackupRepository.ets:596-606`（11 个 `upsertAndroidPreference` 调用） | 已接 | 本地写出 11 键（`bookshelfSort`、`bookshelfSortOrder`、`bookshelfLayoutPortrait`、`bookshelfLayoutGridPortrait`、`bookshelfLayoutListPortrait`、`bookshelfTitleMaxLines`、`bookshelfCoverShadow`、`bookshelfTitleCenter`、`bookshelfTitleSmallFont`、`bookshelfGridCoverWidth`、`bookshelfListCoverWidth`），上游该类别 38 个字段键 | 导出备份，config.xml 里能看到这 11 个键 | — | bookshelfLayout |
| 备份读入：按类别取键 | `help/storage/Backup.kt:258`（`val configMap = AppConfigStore.preferences.asMap()`）、`:262`、`:285`（`saveTabPosition` 相关导出） | `entry/src/main/ets/data/BackupRepository.ets:1321-1347`（`restoreBookshelfLayout`：`:1328-1332` 九个整数键、`:1339` 四个布尔键、`:1346` 落 `BookshelfLayoutRepository.mergeFromAndroidValues`） | 已接 | 本地读入 13 键（9 整数 + 4 布尔），缺 `bookshelfShow*` 系列与 `bookshelfGroup*` 系列 | 把 Android 的 config.xml 恢复进本地，改过的布局项生效 | — | bookshelfLayout |
| 该类别自身可被忽略（`ignoreBookshelfLayout`） | `help/storage/BackupConfig.kt:413`（`keyIsNotIgnore`）、`:420`/`:432`（`bookshelfPrefKeys.contains`）、`:449`（`val ignoreBookshelfLayout: Boolean`）、`:468`（`val backupIgnoreBookshelfLayout: Boolean`） | `entry/src/main/ets/data/BackupRepository.ets:1326`（`if (ignoredCategories.includes('bookshelfLayout'))`）、`:360-375`（忽略键数组） | 已接 | 本地恢复侧按类别名整体跳过；写出侧同样按类别开关跳过 | 勾掉「书架布局」类别后导出，config.xml 里没有这 11 键 | — | bookshelfLayout |
| `bookGroupStyle` / `hideEmptyGroups` 的备份归类 | `constant/PreferKey.kt:13`、`:14`（两个键存在，但**不在** `help/storage/BackupConfig.kt:319-359` 的 39 键内） | `entry/src/main/ets/data/BackupRepository.ets:596`（写出 `bookGroupStyle`）、`:1329`（读入 `bookGroupStyle`）、`:1339`（读入 `hideEmptyGroups`）；`BookshelfLayoutRepository.ets:74-86` 两键都落盘 | 未接 | 按上游口径两键走 `keyIsNotIgnore()` 的 `else -> true`，不受任何类别开关控制，ZIP 类别应为 `—`；本地却把它们放进了 `bookshelfLayout` 类别的写出数组（`:596` 在 `if (!ignoredCategories.includes('bookshelfLayout'))` 块内），**是本地多收** | 导出备份时不受「书架布局」开关影响，两键始终在 config.xml 里 | **要接** | — |

**字段差集（上游 51 − 本地 13 = 38 个名字，按块归属）**

| 缺失字段 | 上游声明行 | 归属块 | 备注 |
| --- | --- | --- | --- |
| `showUnread` | `BookshelfSettings.kt:10` | B | 未读角标 |
| `showUnreadNew` | `:11` | B | 新章节红点 |
| `showTip` | `:12` | B | 书籍类型标签 |
| `showBookCount` | `:13` | E | 分组本数 |
| `showLastUpdateTime` | `:14` | B | 更新时间文字 |
| `showBookIntro` | `:15` | B | 列表详情总开关 |
| `bookshelfShowIntro` | `:16` | B | 简介文字 |
| `bookshelfShowTag` | `:17` | B | 标签行 |
| `bookshelfShowCustomTags` | `:18` | B | 标签内容·用户标签 |
| `bookshelfShowSourceTags` | `:19` | B | 标签内容·书源分类 |
| `bookshelfShowWordCount` | `:20` | B | 标签内容·字数 |
| `bookshelfShowLatestChapter` | `:21` | B | 最新章节行 |
| `bookshelfIntroMaxLines` | `:22` | B | 简介行数 |
| `showWaitUpCount` | `:23` | E | 等待更新数 |
| `showBookshelfFastScroller` | `:24` | E | 快速滚动条 |
| `shouldShowExpandButton` | `:25` | E | 页签栏更多按钮 |
| `bookshelfRefreshingLimit` | `:26` | E | 批量更新限制 |
| `bookshelfLayoutModeLandscape` | `:29` | C | 横屏布局模式 |
| `bookshelfLayoutGridLandscape` | `:30` | C | 横屏网格列数 |
| `bookshelfLayoutListLandscape` | `:32` | C | 横屏列表列数 |
| `bookshelfFolderLayoutModePortrait` | `:33` | C | 文件夹竖屏模式 |
| `bookshelfFolderLayoutGridPortrait` | `:34` | C | 文件夹竖屏网格列数 |
| `bookshelfFolderLayoutModeLandscape` | `:35` | C | 文件夹横屏模式 |
| `bookshelfFolderLayoutGridLandscape` | `:36` | C | 文件夹横屏网格列数 |
| `bookshelfFolderLayoutListPortrait` | `:37` | C | 文件夹竖屏列表列数 |
| `bookshelfFolderLayoutListLandscape` | `:38` | C | 文件夹横屏列表列数 |
| `bookshelfGridLayout` | `:39` | A / B | 网格样式三档 |
| `bookshelfLayoutCompact` | `:40` | B | 紧凑模式 |
| `bookshelfListCoverCenter` | `:41` | B | 列表封面居中 |
| `bookshelfListIntroBelowContent` | `:42` | B | 简介位置 |
| `bookshelfShowDivider` | `:43` | B | 列表分隔线 |
| `bookshelfCardColor` | `:48` | B | 日间卡片底色 |
| `bookshelfCardColorDark` | `:49` | B | 夜间卡片底色 |
| `bookshelfGroupListStyle` | `:50` | B | 分组列表样式 |
| `bookshelfGroupCoverCount` | `:51` | B | 分组横排封面数 |
| `bookshelfSearchActionDirectToSearch` | `:54` | D | 搜索点击分流 |
| `autoRefreshBook` | `:55` | E | 进书架自动刷目录 |
| `saveTabPosition` | `:56` | E | 记住上次分组 |

反向（本地有、上游无）：未查到。本地 13 个字段名在上游 `BookshelfSettings.kt:6-56` 均能按同名找到。

---

## 已排除（接触面内有命中、但不属于本类别界面）

关键词实测命令：`grep -rlE "<关键词>" app/src/main/java --include='*.kt'`（关键词见 `docs/parity/KEYWORDS.md` 的 bookshelfLayout 行），命中 24 个 `.kt`。以下 11 个不映射到本表任何一行，逐条给理由：

| 文件 | 命中内容 | 排除理由 |
| --- | --- | --- |
| `api/controller/BookController.kt` | `:63-70` `when (bookshelfGateway.currentSettings.bookshelfSort)` 四分支（1 更新时间 / 2 书名 / 3 手动 / else 阅读时间） | Web 服务与外部插件的取书架出口，**不是界面**：返回 `ReturnData` 给 HTTP 调用方，屏幕上没有对应的可视元素。界面侧排序见 D 块 `BookshelfRepository.kt:9-50`，本文件只覆盖其中 4 档。属「数据层无独立界面」 |
| `ui/rss/article/RssSortRouteScreen.kt` | `:58`、`:94` `shouldShowExpandButton` | RSS 文章排序页复用同名布尔控制「展开排序菜单」，与书架布局无关；字段同名但语义不是书架页签栏那个按钮。该界面归 RSS 类别的表 |
| `ui/rss/article/RssSortScreen.kt` | `:83`、`:268` `shouldShowExpandButton` | 同上 |
| `ui/rss/article/RssSortViewModel.kt` | `:32-33` `shouldShowExpandButton` | 同上 |
| `ui/book/manage/BookshelfManageScreenViewModel.kt` | `:113-114`、`:455`、`:483` `bookshelfSort` / `bookshelfSortOrder` | 书籍管理页（多选/批量编辑）自己的排序状态，读的是同一对偏好键但界面是管理页；归书籍管理块，不属书架主屏 |
| `ui/config/bookshelfConfig/BookshelfManageScreenConfig.kt` | `:14`、`:18-19` `bookshelfSort` / `bookshelfSortOrder` | 同上，书籍管理页的配置定义 |
| `ui/config/themeConfig/ThemeConfig.kt` | `:50` `autoRefreshBook` | 上游把 `auto_refresh` 键放在主题/其它配置页的键组里读取；界面是配置页，属 `themeConfig` 类别（见 `docs/parity/ZIP-THEME.md`）。书架侧对 `autoRefreshBook` 的消费见 E 块「打开书架时自动刷新目录」 |
| `ui/book/info/BookInfoScreen.kt` | `:1706` 注释里的 `showBookIntro` | 命中位置是**代码注释文字**，无取值、无渲染 |
| `data/repository/ThemePackageSettingsRepository.kt` | `:76-77`、`:219-220` `bookshelfCardColor` / `bookshelfCardColorDark` | 主题包导入导出时搬运这两个颜色键；界面是主题管理页，属 `themeConfig` 类别（见 `docs/parity/ZIP-THEME.md`）。本表 A/B 块已按「`bookshelfLayout / themeConfig`」跨类标注这两键的书架侧消费 |
| `domain/model/settings/ThemeExportData.kt` | `:62-63` `bookshelfCardColor` / `bookshelfCardColorDark` | 同上的数据类承载 |
| `helper/storage/Backup.kt`（`help/storage/Backup.kt`） | `:262`、`:285` `saveTabPosition` | 备份导出侧把「上次所在分组」随 config.xml 一起带走；属 E 备份恢复块的既有覆盖（`docs/BACKUP-RESTORE.md`），无独立界面。书架侧对 `saveTabPosition` 的消费见 E 块「记住上次所在分组」 |

---

## 覆盖证明

命令：

```
bash scripts/upstream-surface.sh --coverage bookshelfLayout docs/parity/ZIP-BOOKSHELF-LAYOUT.md N:/HarmonyProjects/legado-with-MD3
```

跑法与结果（r327 当轮实测）：

```
类别：bookshelfLayout
关键词：bookGroupStyle|hideEmptyGroups|bookshelfSort|showUnread|...|saveTabPosition（38 项，见 KEYWORDS.md 第 67 行）
表格：docs/parity/ZIP-BOOKSHELF-LAYOUT.md
上游接触面：24 个 .kt 文件（其中界面白名单 0 个）

已分配（基名在表格中出现）：24
未分配：0

结论：覆盖证明通过（24 / 24 全部已分配）。
```

24 个文件里 13 个映射到 A–F 某一行（`BookshelfSettings`、`BookshelfConfigSheet`、`BookItem`、`BookshelfScreen`、`BookshelfViewModel`、`BookshelfUiState`、`BookshelfCoverPreloader`、`BookshelfSettingsRepository`、`PreferKey`、`BackupConfig`、`ContextExtensions`、`BookshelfConfig`、`AppConfig`），11 个在本表「已排除」节逐个给理由。两处相加等于 24，与 KEYWORDS.md 记的命中数一致。

关键词从旧三词（10 个文件）换成本表这 38 项前缀名（24 个文件），差集里包含 `ui/main/bookshelf/BookItem.kt`（1090 行，卡片主渲染器）、`ui/main/bookshelf/BookshelfViewModel.kt`（1436 行）、`ui/main/bookshelf/BookshelfUiState.kt`（186 行）—— 旧关键词漏掉整个卡片渲染层与 ViewModel，这是换关键词的直接原因。

## 交叉引用

- 界面全量盘点：[BOOKSHELF.md](BOOKSHELF.md) A1（书架主屏与卡片）、A2（书架设置面板）
- 关键词与命中数：[KEYWORDS.md](KEYWORDS.md) 的 bookshelfLayout 行
- ZIP 总账与兼容度：[STATUS.md](STATUS.md)
- 备份恢复分档：[BACKUP-RESTORE.md](../BACKUP-RESTORE.md)
- 未接行登记与补法：[KNOWN-ISSUES.md](../KNOWN-ISSUES.md) 的「书架布局行登记」
