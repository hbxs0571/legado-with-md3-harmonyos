# 书架 / 书籍元数据 / 进度 对照表

本表按 [盘点规约](../PARITY-RULES.md) 第二节一次盘完，行粒度是**一个界面**（不是界面上与本功能相关的几个按钮），见第四节「盘点单位是界面，不是按钮」。
状态三值：`已接` / `未接` / `不适用`；`不适用` 必写理由。**本表无 `待定` 行。**

> **r286 结构性重盘（2026-10-30）**
>
> 一、**方法换了两条**：盘点单位由「一次操作」改为「整个界面」；完成判据改为 [覆盖证明](../GLOSSARY.md)——上游接触面里每个 `.kt` 必须落到「已映射到某行」或「已排除 + 理由」。
>
> 二、**A1–C 共 260 行是迁移前证据，未逐行复核**：这些行写于 r277–r280（关系型存储迁移之前）。本轮只修正了因迁移而失效的字段引用（`readerPositionVersion` / `androidCharacterPosition` 已删除、`progress` 改为派生、`chapterTitles`/`chapterOffsets`/`chapterVolumes` 三个数组拆进 `chapters` 表），其余行未逐条重核。
>
> 三、**新增「覆盖证明」节**：四类关键词（`localBook` 29 / `bookGroup` 41 / `readRecord` 64 / `bookshelfLayout` 10）并集 115 个上游文件逐个分配，未分配的写明排除理由。
>
> 四、**记住本表覆盖的是四类，不是全部书架相关代码**：`bookSource` 141、`replaceRule` 60、`homepageModules` 23、`showRss` 12 等类别归 [ZIP 兼容总账](STATUS.md) 的其他行，本表只在「交叉引用」里指向。

- 盘点日期：2026-10-30（r279 重盘，作废 r277 的 96 行版；r280 二轮补漏）
- 结构性重盘：2026-10-30（r286，加覆盖证明、修迁移后失效的字段引用）
- 上游基线：`<上游根>`（Android，Compose）——指法见 [KEYWORDS.md](KEYWORDS.md) 的用法节；路径均相对 `app/src/main/java/io/legado/app/`
- 本地实现：本仓库根，路径均相对 `entry/src/main/ets/`
- 对应 ZIP 类别：`localBook`、`bookGroup`、`readRecord`、`bookshelfLayout`，见 [ZIP 兼容总账](STATUS.md)

**「ZIP 类别」列怎么读**（r292 新增）

判据是**「这一行要改代码时，会动到哪个 ZIP 类别的键或文件」**，不是「数据落在哪」。显示类开关几乎都是双依赖，例如 `ui/main/bookshelf/BookItem.kt:888` `if (settings.bookshelfShowTag && kindList.isNotEmpty())` —— 键在 `bookshelfLayout`，数据在 `localBook`，少任何一边都不显示，所以派给任一类都得看这一行。

取值四档：

| 取值 | 含义 |
| --- | --- |
| `<类别名>` | 在 `docs/BACKUP-RESTORE.md` 28 类里。该类别取消勾选后，这行的数据会丢 |
| `A / B` | 跨类，派活时两边都要看 |
| `—` | **参与备份，但不受任何忽略开关控制**：键照样写进 `config.xml`，只是不在五个类别数组里（上游 `help/storage/BackupConfig.kt:413 fun keyIsNotIgnore` 的 `else -> true` 分支） |
| `不备份` | 连 `config.xml` 都进不去：键在 `local_ui_status`（`data/local/preferences/LocalPreferences.kt:11`，`Backup.kt:258` 只读 `settings` 那个 DataStore），或在 `BackupConfig.kt:11-30 alwaysIgnoredPreferenceKeys`（含私密凭据 salt/verifier） |

`—` 与 `不备份` 不能混用：前者「取消任何类别勾选都不会消失」，后者「任何情况下都不存在」。判定方法：拿键名去上游 `constant/PreferKey.kt` 查常量值，再 grep `help/storage/BackupConfig.kt` —— 在五个类别数组里就是类名，只在 `PreferKey` 里就是 `—`，在 `LocalPreferences.kt` 或 `alwaysIgnoredPreferenceKeys` 里就是 `不备份`。

## 为什么重盘

r277 版 96 行（58 已接 / 35 未接 / 3 不适用）作废，原因是**以本地代码为索引反推上游**：本地没有的词永远检索不到，于是「本地压根没有」的能力被系统性漏掉。重盘改为先 `grep -rl` 枚举上游接触面全清单，再拿清单对本地。

重盘补出的主要漏项：AI 自动分组、标签匹配规则与同步、分组四宫格预览与计数、文件夹根视图（`bookGroupStyle == 2` 第三档）、卡片未读角标 / 更新红点 / 更新中指示 / 类型标签 / 来源标签 / 自定义标签 / 简介 / 更新时间 / 最新章节、选择模式七件套、私密分组与解锁、书架设置 44 个一级控件、详情页 20 个菜单动作中的 15 项、简介四分支渲染、角色 / 知识 / 事件卡、阅读记录热力图与图表与合并同名。

## 为什么还要二轮补漏

r279 版 220 行仍是按「用户可感知的操作」取粒度，漏掉的是**同一区域内的次级交互**：长按、副标题、可点的文字元素、面板内的分区。r280 换了两条独立线索交叉验证：

1. 把上游四个目录的 30 个 `.kt` 文件全列一遍，挑出 r279 未覆盖的 14 个（共 3669 行）逐个核对——`BookshelfViewModel.kt`(1436)、`BookInfoViewModel.kt`(2164)、`BookInfoSheets.kt`(297)、`ShelfDeleteSheet.kt`(182)、`BookInfoReadRecordSheet.kt`(167)、`ReadRecordOverviewScreen.kt`(547) 等。
2. 把详情页 130 个 `R.string.*` 键与表中文字做差集，未出现的键逐个回查调用点。

补出 40 条：A1 15 条（顶栏 8、空态与分页 2、卡片 5）、B 20 条（头部 7、动作卡拆分 1、面板与脚本 10、删除面板 2）、C 5 条（总览页分区）。

其中一条是**状态判错而非漏列**：r279 把「动作卡·阅读记录」判为已接，但上游是本书专属的内嵌面板（`BookInfoReadRecordSheet.kt:41-116`），本地 `pages/BookInfoPage.ets:197` 点开跳的是全局阅读记录页。r280 拆成「入口已接」+「面板未接」两行。

## 盘面

| 块 | 条数 | 已接 | 未接 | 不适用 |
| --- | --- | --- | --- | --- |
| A1 书架主屏与卡片 | 78 | 54 | 24 | 0 |
| A2 书架设置面板 | 47 | 47 | 0 | 0 |
| A3 分组管理 | 22 | 20 | 1 | 1 |
| B 书籍详情页与元数据 | 80 | 24 | 55 | 1 |
| C 阅读进度与记录 | 39 | 37 | 1 | 1 |
| D 缓存管理页（整界面，r286 新增） | 53 | 6 | 47 | 0 |
| E 备份恢复（整界面，r295 新增，r296 补 1 行） | 19 | 9 | 8 | 2 |
| F 本地书导入与判重（整界面，r323 新增） | 7 | 2 | 5 | 0 |
| 合计 | 345 | 199 | 141 | 5 |

A1–C 的 260 行写于 r277–r280（C 块 r286 补 3 行后为 263 行），原本是迁移前证据、未逐行复核，**r340 已逐行复核**（结论见 `## r340 复核结论`，其中 26 行改判 `已接`、2 行新增 `不适用`、174 行标 `**要接**`、9 行标 `**不接**`）；D 块 53 行是 r286 按「整界面」新盘的；E 块 19 行是 r295 按「存储层对 28 类关键词全部隐身」新盘的，r296 补入本地书恢复期冲突规划一行、r336 追加 `keyboardAssists` 类别级 6 行；F 块 7 行是 r323 按 KI-REL4 新盘的。全表状态三值，无 `待定`。

---

## A1 书架主屏与卡片

上游主体：`ui/main/bookshelf/BookshelfScreen.kt`（1872 行）、`BookItem.kt`（1090 行）、`BookShelfItem.kt`。
本地主体：`pages/BookshelfPage.ets`（1357 行）、`components/BookCover.ets`（303 行）。

| 上游能力 | 上游位置 | 本地位置 | 状态 | 差异说明 | 验收方式 | 备注 | ZIP 类别 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 顶栏标题随滚动折叠 | `BookshelfScreen.kt:1329` | `pages/BookshelfPage.ets:606-625` | 已接 | 本地阈值 60vp，折叠动画 220ms | 书架下滑超过一屏，大标题淡出、顶栏出现小标题 | — | — |
| 顶栏搜索入口 | `BookshelfScreen.kt:1329` | `pages/BookshelfPage.ets:611-613` | 已接 | 本地为内联展开输入框，非独立搜索页 | 点搜索图标出现输入框，输入书名可过滤 | — | — |
|  搜索按钮长按切换为筛选  |  `BookshelfScreen.kt:1342`  |  `pages/BookshelfPage.ets:611-615`  | 已接 |  本地只有单击开搜索，无长按分支 。**复核（r340）**：pages/BookshelfPage.ets:1078-1094 的 .onClick 与 .priorityGesture(LongPressGesture({ duration: 500 })) 两支按 bookshelfSearchActionDirectToSearch 互换 | 长按搜索图标 500ms 后按钮变「筛选」，再点开筛选面板；把该开关取反后单击直接进搜索； 长按搜索图标后按钮变成「筛选」，再点开筛选面板  |  受 `bookshelfSearchActionDirectToSearch` 决定主次动作  |  bookshelfLayout  |
|  顶栏独立筛选入口  |  `BookshelfScreen.kt:1342`  |  `pages/BookshelfPage.ets:1078-1094`  | 已接 |  上游「筛选」是搜索态取反，本地 `showSearch` 与 `bookshelfSearchActionDirectToSearch` 两支互换已就位。**实现（r341）**：`pages/BookshelfPage.ets` 的 `bookshelfTitle()` 第二支让进搜索态后标题显示当前分组名，配 `bookshelfSubtitle()` 的「共 N 本」构成可见筛选态  | 长按搜索图标展开书架内搜索栏，切到「静候」分组后标题变「静候」、副标题「共 2 本」  |  `bookshelf_filter`  |  —  |
|  顶栏标题随分组/搜索/编辑态变化  |  `BookshelfViewModel.kt:921-947`  |  `pages/BookshelfPage.ets` 的 `bookshelfTitle()`  | 已接 |  **实现（r341）**：`bookshelfTitle()` 照 `buildTitle` 实现四支——搜索态＋页签回落「书架」、搜索态或隐藏页签显示当前分组名、文件夹根层「书架」/组内分组名；上游末尾「编辑态一律书架」与 `upBooksCount>0` 拼 ` (N)` 两支本地未接：编辑态依赖批 5 选择模式、`(N)` 依赖待更新队列（本地无 `waitUpTocBooks/onUpTocBooks` 数据源），验收列相应只列前四支  | 切到「静候」分组标题变「静候」；文件夹模式进分组标题变组名、返回根层变「书架」  |  `buildTitle()` 四分支（编辑态与 (N) 未接）  |  —  |
|  顶栏副标题  |  `BookshelfViewModel.kt:676-698`  |  `pages/BookshelfPage.ets` 的 `bookshelfSubtitle()`  | 已接 |  **实现（r341）**：大标题下加第二行 `Text(副标题).fontSize(12)`，搜索态显示「共 N 本」（N 取 `getVisibleBooks().length`，随搜索关键字实时变化）；编辑态「已选 N 本 · 本组共 M 本」依赖批 5 选择模式，本批未接  | 展开书架内搜索栏显示「共 210 本」，输入「古神」变「共 2 本」，清空后恢复  |  编辑态副标题随批 5 选择模式接入  |  —  |
|  标题加载中字符闪烁  |  `BookshelfScreen.kt:1364`  |  —  | 未接 |  本地加载态无标题动画  |  书架加载时标题显示「加载中」并逐字闪烁  |  `useCharMode` ；**不接**：纯装饰动效：本地首屏无网络等待，加载通常一两帧内完成，无需等待提示 |  —  |
|  搜索栏展开/收起动画与清空按钮  |  `BookshelfScreen.kt:1379-1395`  |  `pages/BookshelfPage.ets` 搜索栏  | 已接 |  **实现（r341）**：搜索栏 `Row` 修饰链加 `.transition(TransitionEffect.OPACITY.combine(TransitionEffect.scale({ x: 1, y: 0.6 })).animation({ duration: 220 }))`；`searchQuery.length>0` 时右端出现 `AppGlyph({ name: 'profileClose' })` 清空按钮（本地图标名无 `close`）  | 长按搜索图标搜索栏带过渡展开；输入两字右端出现 ×，点了输入框空、副标题回「共 210 本」  |  用 `TransitionEffect` 代 `AnimatedVisibility`  |  —  |
|  编辑态顶栏关闭按钮  |  `BookshelfScreen.kt:1355`  |  —  | 未接 |  本地无编辑态  |  进入选择模式后顶栏左侧变成关闭按钮，点后退出并清空选择  |  `cancel_select` ；**要接**：选择模式需先有编辑态与工具条，全选/反选依赖选中集合，属同一批 |  —  |
| 顶栏更多菜单 | `BookshelfScreen.kt:688` | `pages/BookshelfPage.ets:614-617`、`:574-601` | 已接 | 本地用 `bindMenu` 弹 Menu，上游为 ModalBottomSheet | 点更多图标弹出 11 项菜单 | — | — |
|  更多菜单·远程书籍  |  `BookshelfScreen.kt:695`  |  `pages/BookshelfPage.ets:576`  | 未接 |  本地 `onUnavailableAction('远程书籍导入尚未迁移')`  |  点该菜单项弹出导入对话框并成功导入 1 本  |  依赖网络书库协议 ；**要接**：依赖在线书源与网址导入；书源已纳入范围未排期（docs/PROJECT.md:24-44），随该模块做 |  —  |
| 更多菜单·添加本地 | `BookshelfScreen.kt:700` | `pages/BookshelfPage.ets:579-583` | 已接 | 本地走系统文件选择器导入 TXT | 选 1 个 TXT，书架新增该书并自动分组「本地未分组」 | — | localBook |
| 更多菜单·更新目录 | `BookshelfScreen.kt:705` | `pages/BookshelfPage.ets:584-585` | 已接 | 本地重识别全部本地 TXT 目录 | 点后目录章数变化，书签与划线保持原章节号 | 见 r276 | localBook |
| 更多菜单·布局设置 | `BookshelfScreen.kt:713` | `pages/BookshelfPage.ets:586` | 已接 | 打开同一 sheet 的布局面板 | 点后弹出「书架布局」面板 | — | bookshelfLayout |
| 更多菜单·分组管理 | `BookshelfScreen.kt:721` | `pages/BookshelfPage.ets:588` | 已接 | 打开同一 sheet 的分组面板 | 点后弹出分组管理网格 | — | bookGroup |
|  更多菜单·添加网址  |  `BookshelfScreen.kt:729`  |  `pages/BookshelfPage.ets:590`  | 未接 |  本地 `onUnavailableAction('网址导入尚未迁移')`  |  粘贴网址后成功建立书籍条目  |  见 [已知问题](../KNOWN-ISSUES.md#本地书籍行登记bookshelfmd-的-localbook-未接行) KI-LB2 ；**要接**：依赖在线书源与网址导入；书源已纳入范围未排期（docs/PROJECT.md:24-44），随该模块做 |  localBook  |
|  更多菜单·选择模式  |  `BookshelfScreen.kt:737`  |  `pages/BookshelfPage.ets:592`  | 未接 |  本地 `onUnavailableAction('书架选择模式尚未迁移')`  |  进入选择模式后卡片出现勾选框  |  缺口见本块下方七条 ；**要接**：菜单项与页签按钮是纯 UI 入口，目标页/动作已存在或在 D 块排期内 |  —  |
|  更多菜单·书架管理  |  `BookshelfScreen.kt:745`  |  `pages/BookshelfPage.ets:594`  | 未接 |  本地 `onUnavailableAction('书架管理尚未迁移')`  |  打开书架管理页并可批量清理  |  — ；**要接**：菜单项与页签按钮是纯 UI 入口，目标页/动作已存在或在 D 块排期内 |  —  |
|  更多菜单·导出书单  |  `BookshelfScreen.kt:756`  |  `data/BookshelfListTransfer.ets`、`pages/BookshelfPage.ets` 的 `exportBookList()`  | 已接 |  **实现（r341）**：`BookshelfListTransfer.exportList()` 用 `DocumentViewPicker.save()` 写 `bookshelf.json`，格式照上游 `ExportBookshelfUseCase.kt:20-79` 的 `[{name,author,intro}]`（`title→name`、`description→intro`）；更多菜单项由占位改真动作  | 点「导出书单」弹系统保存框（默认名 `bookshelf.json`），保存后 toast「已导出 210 本书到 bookshelf.json」，下载管理器里能看到该文件  |  见 [已知问题](../KNOWN-ISSUES.md#本地书籍行登记bookshelfmd-的-localbook-未接行) KI-LB2  |  localBook  |
|  更多菜单·导入书单  |  `BookshelfScreen.kt:764`  |  `data/BookshelfListTransfer.ets`、`pages/BookshelfPage.ets` 的 `importBookList()`  | 已接 |  **实现（r341）**：`selectAndParse()` 用 `DocumentViewPicker.select()` 限 `.json`/`.txt`，解析 `[{name,author,intro}]`；`toBooks()` 按 `title+author` 判重后构造缺正文占位书，经 `onImportBookList` 回调交 `Index` 用 `saveImportedBooks` 落库。与批 10 `:554` 选书文件（TXT/EPUB）不是一回事  | 选刚导出的 `bookshelf.json` 导入，toast「书单里没有可导入的新书（可能都已存在）」、书架仍「共 210 本」  |  见 [已知问题](../KNOWN-ISSUES.md#本地书籍行登记bookshelfmd-的-localbook-未接行) KI-LB2  |  localBook  |
|  更多菜单·日志  |  `BookshelfScreen.kt:772`  |  `lib/AppLog.ets`、`pages/BookshelfPage.ets` 的 `LogSheetContent()`  | 已接 |  **实现（r341）**：新建 `lib/AppLog.ets`（500 条环形内存缓冲 `put/getAll/clear`），把 `BookRepository` 5 处 `console.error` 换成 `AppLog.put`；日志页做成 `bindSheet` 第三分支（`List+ForEach` 等宽小字 + 底部「清空」），菜单项由占位改真动作  | 点「日志」打开日志页，有「书架已显示 210 本书」等条目；点「清空」后显示「暂无日志」  |  进程内存日志，重启即空  |  —  |
| 分组页签栏 | `BookshelfScreen.kt:780-900` | `pages/BookshelfPage.ets:639-647` | 已接 | 本地为横排 `ShelfFilter` 列表，无页签下划线动画 | 多个分组时顶部出现分组名横排，点切换过滤 | `bookGroupStyle == 0` 时渲染 | bookGroup |
|  页签栏右侧分组管理按钮  |  `BookshelfScreen.kt:820`  |  `pages/BookshelfPage.ets` 页签行  | 已接 |  **实现（r341）**：页签行改成 `Scroll(横向,.layoutWeight(1))` 包 `ForEach(getGroupNames(), ShelfFilter)`，右端按 `layout.showBookshelfTabMenu` 加 `AppGlyph({name:'list'})` 按钮、`.bindMenu(this.GroupFilterMenu())`（现成菜单，当前项 `✓` 打勾）  | 页签行右端出现圆形分组按钮，点开「✓ 全部/本地未分组/静候/完结/已阅」当前项打勾  |  与 `:222` 同一按钮  |  bookGroup  |
| 隐藏页签模式下的「切换分组」 | `BookshelfScreen.kt:900-980` | `pages/BookshelfPage.ets:648-652` | 已接 | 本地显示「当前分组：X」+「切换分组」文字按钮 | 打开「隐藏分组页签」后，点「切换分组」可切换 | `bookGroupStyle != 0` 时渲染 | bookGroup |
|  分组样式第三档「文件夹」  |  `BookshelfScreen.kt:983`  |  `model/BookshelfLayout.ets`  | 已接 |  `BOOK_GROUP_STYLE_OPTIONS` 只有 `{0,页签}`/`{1,隐藏页签}`，缺第三项 。**复核（r340）**：model/BookshelfLayout.ets:98-102 三项 页签/隐藏页签/文件夹；面板 LayoutMenuRow 消费在 pages/BookshelfPage.ets:829 | 布局设置→分组样式弹出三项，选「文件夹」后书架变文件夹根视图； 布局面板出现「文件夹」选项，选中后书架变文件夹根视图  |  结构性缺口，牵动本块后三条  |  bookGroup  |
|  文件夹根视图（分组即一级条目）  |  `BookshelfScreen.kt:983-1070`  |  —  | 已接 |  本地无 `BookGroupItemList`/`BookGroupItemGrid` 等价物 。**复核（r340）**：pages/BookshelfPage.ets:1118 if (this.layout.bookGroupStyle === 2)、:1127 else-if 分支、:1142 空态判定 | 选「文件夹」后书架根层每组一张分组卡，点卡进该组； 选中文件夹样式后，书架按分组显示，点分组进二级书列表  |  —  |  bookGroup  |
|  文件夹四宫格封面预览  |  `BookshelfScreen.kt:1028-1032`、`BookItem.kt:361-432`  |  —  | 已接 |  本地分组卡片只有一个封面或加号 。**复核（r340）**：components/BookGroupCard.ets:51-70 ForEach(previewBooks()) 画多张封面 + emptySlots() 补空位；coverCount 来自 pages/BookshelfPage.ets:1150 | 文件夹样式下分组卡显示一排封面，张数等于布局设置里的「封面数量」； 文件夹卡片显示前 4 本书的封面拼图  |  数量由 `bookshelfGroupCoverCount` 控制  |  bookGroup / bookshelfLayout  |
|  文件夹书籍计数角标  |  `BookshelfScreen.kt:1019-1027`、`BookItem.kt:437-447`  |  —  | 未接 |  本地分组卡片无计数  |  文件夹卡片右上角显示「N 本」  |  `showBookCount` 为 true 且分组未锁定时显示 ；**要接**：文件夹根视图与四宫格已接，缺可开关的计数角标与书架上的长按入编辑 |  bookGroup  |
|  文件夹长按进分组编辑  |  `BookshelfScreen.kt:1055`  |  `pages/BookshelfPage.ets:259`  | 未接 |  本地长按入口在分组管理面板内，不在书架  |  文件夹卡片长按直接打开分组编辑表单  |  面板内已接，缺书架入口 ；**要接**：文件夹根视图与四宫格已接，缺可开关的计数角标与书架上的长按入编辑 |  bookGroup  |
| 书封渲染（含占位与灰底） | `BookItem.kt:738-800` | `components/BookCover.ets:77-78` | 已接 | 本地尺寸 92×128 / compact 70×100 / mini 48×68 | 无封面书籍显示按书名生成的占位图 | — | localBook |
|  卡片副标题作者行  |  `BookItem.kt:866`  |  `pages/BookshelfPage.ets:665-667`  | 已接 |  本地卡片只有书名，无作者行 。**复核（r340）**：pages/BookshelfPage.ets:1263 渲染 Text(book.author) | 列表卡第二行显示作者名； 卡片书名下显示作者  |  见 [已知问题](../KNOWN-ISSUES.md#本地书籍行登记bookshelfmd-的-localbook-未接行) KI-LB1  |  localBook  |
| 紧凑模式「作者 · N 未读」副标题 | `BookItem.kt:866` | — | 已接 | **实现（r341）**：`pages/BookshelfPage.ets` 作者行改成紧凑/非紧凑两支，紧凑渲染「作者 · N 未读」（N=chapterCount-chapterIndex-1），未读 0 只显示作者 | 开「精简详情」后网格卡作者行显示「负是非 · 2126 未读」 | `author_read`；见 [已知问题](../KNOWN-ISSUES.md#本地书籍行登记bookshelfmd-的-localbook-未接行) KI-LB1 | localBook / bookshelfLayout |
|  列表卡片描述行显示当前章  |  `BookItem.kt:871`  |  —  | 已接 |  本地卡片无当前章描述 。**复核（r340）**：pages/BookshelfPage.ets:1197 一带渲染 book.lastChapter 作为章节行 | 列表卡显示当前章节标题； 列表模式卡片显示「第 12 章 章节名」  |  `durChapterTitle`；见 [已知问题](../KNOWN-ISSUES.md#本地书籍行登记bookshelfmd-的-localbook-未接行) KI-LB1  |  localBook  |
| 标题区未读徽标叠加更新图标 | `BookItem.kt:853-865` | — | 已接 | **实现（r341）**：列表卡标题改成 Row，右侧加未读数徽标（showUnread && unread>0），有更新时叠 `profileRefresh` 图标 | 布局切「列表」后标题右侧出现 2126 / 2073 徽标 | 见 [已知问题](../KNOWN-ISSUES.md#本地书籍行登记bookshelfmd-的-localbook-未接行) KI-LB1 | localBook |
|  移出书架后「点击移出」提示  |  `BookInfoScreen.kt:1405-1416`、`:1425`  |  —  | 未接 |  本地移出后无提示  |  加入书架后 1 秒内按钮显示「点击移出」，随后切「长按选分组」  |  `click_to_remove` → `long_press_group` 两段提示，各 1 秒；见 [已知问题](../KNOWN-ISSUES.md#本地书籍行登记bookshelfmd-的-localbook-未接行) KI-LB4 ；**要接**：动作/手势/私密体系，纯本地可做；books 表已有 order 列支撑拖拽重排 |  localBook  |
|  封面无障碍描述  |  `BookItem.kt:788-806`  |  —  | 未接 |  本地封面无无障碍标签  |  读屏聚焦封面时播报书名与未读数  |  `a11y_book_cover_actions`；见 [已知问题](../KNOWN-ISSUES.md#本地书籍行登记bookshelfmd-的-localbook-未接行) KI-LB1 ；**要接**：动作/手势/私密体系，纯本地可做；books 表已有 order 列支撑拖拽重排 |  localBook  |
| 书封阴影开关 | `BookItem.kt:839`、`:965` | `components/BookCover.ets:81` | 已接 | 由 `bookshelfCoverShadow` 驱动 | 开关「书封阴影」后封面阴影出现与消失 | — | bookshelfLayout |
|  网格封面宽度可调  |  `BookItem.kt:839`  |  —  | 已接 |  本地固定 compact 尺寸，无宽度设置 。**复核（r340）**：pages/BookshelfPage.ets:1003 控件写 bookshelfGridCoverWidth（步进 10）；渲染消费 :1240 bookshelfCoverWidthLimit() | 布局设置里改「网格封面宽度」，书架网格卡封面随之变宽或变窄； 设置「网格封面宽度」为 120 后封面明显变大  |  —  |  bookshelfLayout  |
|  列表封面宽度可调  |  `BookItem.kt:965`  |  —  | 已接 |  同上 。**复核（r340）**：pages/BookshelfPage.ets:1006 控件写 bookshelfListCoverWidth；渲染消费 :1179-1180 displayWidth | 改「列表封面宽度」后列表卡封面宽度变化； 设置「列表封面宽度」后列表封面变宽  |  —  |  bookshelfLayout  |
| 未读章节数角标 | `BookItem.kt:751-752`、`:792`、`BookShelfItem.kt:50` | — | 已接 | **实现（r341）**：`components/BookCover.ets` 加 badgeText/showBadgeDot 两个 @Prop，网格卡传未读数（unreadOf=max(chapterCount-chapterIndex-1,0)），封面右上角画红底数字角标 | 网格卡封面右上角显示未读角标（如 2126），读完最后一章消失 | 见 [已知问题](../KNOWN-ISSUES.md#本地书籍行登记bookshelfmd-的-localbook-未接行) KI-LB1 | localBook |
| 更新小红点 | `BookItem.kt:753`、`:793`、`BookShelfItem.kt:48` | — | 已接 | **实现（r341）**：`BookCover` 右下角红点条件 showUnread && showUnreadNew && (lastCheckCount>0)；2a 在 `refreshToc` 算 lastCheckCount=新增章数、`Index.openBook` 清零 | 刷新目录有新增章节的书右下出现红点，打开该书后红点消失 | 见 [已知问题](../KNOWN-ISSUES.md#本地书籍行登记bookshelfmd-的-localbook-未接行) KI-LB1 | localBook |
| 更新中进度指示 | `BookItem.kt:782` | — | 已接 | **实现（r341）**：`pages/Index.ets` 加 @State refreshingBookIds 作 @Prop 传入，`refreshAllToc` 刷新期间对应卡片叠 LoadingProgress 与「更新中」 | 点「更新目录」时对应书封面出现转圈遮罩，完成即消失 | 见 [已知问题](../KNOWN-ISSUES.md#本地书籍行登记bookshelfmd-的-localbook-未接行) KI-LB1 | localBook |
| 书籍类型标签 | `BookItem.kt:754-765`、`:794` | — | 已接 | **实现（r341）**：bookTypeLabel() 按 showTip 给类型，只做本地 / EPUB 两档（epub→EPUB、其余→本地）；**音频 / 漫画 / 网络文件三档未接，等本地有该形态的书再补** | 开「显示书籍类型」后 TXT 显示「本地」、EPUB 显示「EPUB」，关掉全消失 | 见 [已知问题](../KNOWN-ISSUES.md#本地书籍行登记bookshelfmd-的-localbook-未接行) KI-LB1 | localBook |
|  来源标签（搜索模式）  |  `BookItem.kt:766-774`  |  —  | 未接 |  本地书架无搜索模式下的来源命中高亮  |  搜索书名时卡片左下显示命中的书源名  |  仅在 `isSearchMode` 下；见 [已知问题](../KNOWN-ISSUES.md#本地书籍行登记bookshelfmd-的-localbook-未接行) KI-LB1 ；**要接**：依赖在线书源与网址导入；书源已纳入范围未排期（docs/PROJECT.md:24-44），随该模块做 |  localBook / bookshelfLayout  |
| 自定义标签行 | `BookItem.kt:888-918` | — | 已接 | **实现（r341）**：BookTagRow() 横向 Scroll 渲染标签，displayTagsOf 按 customTag→category(去重)→wordCount 拼接，三开关各控一段；本批固定主题色（取色见 :124） | 书卡下方出现 TXT / 618.4万字 / 本地 标签行，关「显示标签」整行消失 | 见 [已知问题](../KNOWN-ISSUES.md#本地书籍行登记bookshelfmd-的-localbook-未接行) KI-LB1 | localBook / bookshelfLayout |
|  标签按 `customTagColors` 取色  |  `BookItem.kt:888-918`  |  `pages/BookshelfPage.ets:318-333`、`:474-476`  | 已接 |  本地原只用固定主题色渲染标签行。**实现（r341）**：批 3 新增 customTagColorsJson 与 parseTagColors（model/BookshelfLayout.ets）、lib/TagColorUtils.ets；BookTagRow 按索引取模取色，textColor/bgColor 为 0 回落主题色，关开关传空数组；生成 8 组后书卡 TXT/字数/本地各取不同色，关开关回统一主题色  |  生成 8 组配色后书卡标签各取不同色；关「自定义标签配色」后回统一主题色  |  与 A2 标签内容设置联动 |  —  |
|  列表模式简介  |  `BookItem.kt:919-941`  |  —  | 已接 |  本地卡片无简介 。**复核（r340）**：pages/BookshelfPage.ets:568-569 showsListDetails() 把关，:1185-1193 渲染简介 | 列表模式下书名下方出现简介文字； 列表模式且开启「显示简介」后卡片显示简介文本  |  需 Jsoup 等价富文本处理；见 [已知问题](../KNOWN-ISSUES.md#本地书籍行登记bookshelfmd-的-localbook-未接行) KI-LB1  |  localBook / bookshelfLayout  |
|  简介排版在书名下方  |  `BookItem.kt:919-941`  |  —  | 已接 |  同上 。**复核（r340）**：pages/BookshelfPage.ets:1209-1214 按 bookshelfListIntroBelowContent 把简介排到书名下方 | 打开「简介在下方」后简介从右侧栏移到书名下方； 开启「简介在书名下方」后排版位置改变  |  `bookshelfListIntroBelowContent`  |  bookshelfLayout  |
| 最后更新时间 | `BookItem.kt:944-951` | — | 已接 | **实现（r341）**：新建 `lib/TimeAgo.ets` 的 toTimeAgo()，列表卡按 showLastUpdateTime && !book.isLocal 渲染；本地书恒不显示，网络书相对时间待在线书源模块 | 开「显示最后更新时间」后非本地书显示「N 天前」，本地书不显示 | 见 [已知问题](../KNOWN-ISSUES.md#本地书籍行登记bookshelfmd-的-localbook-未接行) KI-LB1 | localBook |
| 最新章节 | `BookItem.kt:952-959` | — | 已接 | **实现（r341）**：2a 给 `model/Book.ets` 加 latestChapterTitle 并在 toBookArgs 绑 `latestChapterTitle ?? lastChapter`；列表章节行改显示该字段，空串不渲染 | 开「显示最新章节」后显示最新章名（≠当前阅读章） | 见 [已知问题](../KNOWN-ISSUES.md#本地书籍行登记bookshelfmd-的-localbook-未接行) KI-LB1 | localBook / bookshelfLayout |
| 字数统计 | `BookshelfConfigSheet.kt:511` 二级面板 | — | 已接 | **实现（r341）**：2a 在产出目录的同步函数算 wordCount（totalWordCount / wordCountFormat），并入 displayTagsOf 标签行，不单独一块 UI | 开「显示字数」后标签行多一项「618.4万字」 | 见 [已知问题](../KNOWN-ISSUES.md#本地书籍行登记bookshelfmd-的-localbook-未接行) KI-LB1 | localBook / bookshelfLayout |
| 等待更新数 | `BookshelfConfigSheet.kt:579` | — | 已接 | **表描述已更正（r341）**：上游真身是 `BookshelfViewModel.kt:1285-1297` postUpBooksCount() 的全局待更新书数，喂 buildTitle 拼标题尾巴「 (N)」，**是标题级不是卡片级**，卡片上不显示。showWaitUpCount 开关（:216）已落盘；本地无 waitUpTocBooks / onUpTocBooks 待更新队列，标题 (N) 尾巴随在线书源模块（见 :83） | 面板「显示等待更新数」开关可切换并落盘；标题 (N) 尾巴本地暂不显示 | 见 [已知问题](../KNOWN-ISSUES.md#本地书籍行登记bookshelfmd-的-localbook-未接行) KI-LB1 | localBook |
|  书名居中（网格）  |  `BookItem.kt:110-146`  |  `pages/BookshelfPage.ets:664-666`  | 已接 |  本地固定左对齐 。**复核（r340）**：pages/BookshelfPage.ets:1191 .textAlign(bookshelfTitleCenter ? Center : Start) | 打开「书名居中」后网格卡书名居中； 开启「标题居中」后网格书名居中  |  `bookshelfTitleCenter`  |  bookshelfLayout  |
| 书名最大行数 | `BookItem.kt:110-146` | `pages/BookshelfPage.ets:665` | 已接 | 由 `bookshelfTitleMaxLines` 驱动 | 设为 1 行后长书名以省略号截断 | — | bookshelfLayout |
|  书名小字号  |  `BookItem.kt:110-146`  |  —  | 已接 |  本地固定 13fp 。**复核（r340）**：pages/BookshelfPage.ets:684 bookshelfTitleFontSize() 返回 bookshelfTitleSmallFont ? 11 : 13 | 打开「书名小字号」后书名明显变小； 开启「标题小字号」后书名变小  |  `bookshelfTitleSmallFont`  |  bookshelfLayout  |
|  列表分割线  |  `BookItem.kt:253-259`  |  —  | 已接 |  本地无列表模式 。**复核（r340）**：pages/BookshelfPage.ets:1214-1218 if (bookshelfShowDivider) Divider() | 列表模式下每张卡之间出现分隔线，关掉后消失； 列表模式相邻书之间有分割线  |  本地无列表卡片实现  |  bookshelfLayout  |
|  列表卡片背景色（日/夜）  |  `BookItem.kt:175-186`  |  —  | 已接 |  本地无日/夜卡片配色 。**复核（r340）**：pages/BookshelfPage.ets:689-693 cardBackgroundColor() 按 readerNightMode 取 bookshelfCardColorDark / bookshelfCardColor；:1272 消费 | 设了卡片底色后列表卡出现底色，切夜间模式换成另一套颜色； 设日间卡片色为米色后列表卡片变色  |  同上  |  bookshelfLayout  |
|  列表封面垂直居中  |  `BookItem.kt:175-186`  |  —  | 已接 |  本地无列表模式 。**复核（r340）**：pages/BookshelfPage.ets:1205 .alignItems(bookshelfListCoverCenter ? VerticalAlign.Center : VerticalAlign.Top) | 打开「封面垂直居中」后列表卡封面在行内居中； 开关后列表封面在行内垂直居中  |  同上  |  bookshelfLayout  |
|  紧凑模式  |  `BookshelfConfigSheet.kt:389`  |  —  | 已接 |  本地无紧凑模式 。**复核（r340）**：pages/BookshelfPage.ets:569 showsListDetails() 里 !bookshelfLayoutCompact 把关 | 打开「紧凑模式」后列表卡变矮、简介消失； 开启后卡片高度压缩、隐藏次要信息  |  `bookshelfLayoutCompact`  |  bookshelfLayout  |
|  拖拽重排书架  |  `BookshelfScreen.kt:1743-1748`、`:1795-1800`  |  —  | 未接 |  本地网格无 `ReorderableItem` 等价物  |  长按卡片可拖动换位，松手后顺序持久化  |  分组内已有拖拽（见 A3）；见 [已知问题](../KNOWN-ISSUES.md#本地书籍行登记bookshelfmd-的-localbook-未接行) KI-LB2 ；**要接**：动作/手势/私密体系，纯本地可做；books 表已有 order 列支撑拖拽重排 |  localBook  |
|  快速滚动条  |  `BookshelfScreen.kt:1770`  |  —  | 已接 |  本地 `scrollBar(BarState.Off)` 。**复核（r340）**：pages/BookshelfPage.ets:1290 scrollBar(showBookshelfFastScroller ? BarState.On : BarState.Off) | 打开「快速滚动条」后书架可拖动滚动条，关掉后滚动条不显示； 开启后书架右侧出现快速滚动条，可拖动定位  |  `showBookshelfFastScroller`  |  —  |
| 点击卡片开书 | `BookshelfScreen.kt:1808-1830` | `pages/BookshelfPage.ets:668-674` | 已接 | 缺正文时改跳详情页 | 点卡片进入阅读页并定位到上次章节 | — | — |
| 长按卡片进详情 | `BookshelfScreen.kt:1808-1830` | `pages/BookshelfPage.ets:675-677` | 已接 | 本地 500ms | 长按卡片弹出书籍详情页 | — | — |
|  选择模式工具条  |  `BookshelfScreen.kt:610-681`  |  —  | 未接 |  本地无选择模式，工具条整组缺失  |  进入选择模式后顶部出现工具条  |  本块后七条均属此组 ；**要接**：选择模式需先有编辑态与工具条，全选/反选依赖选中集合，属同一批 |  —  |
|  全选  |  `BookshelfScreen.kt:614`  |  —  | 未接 |  同上  |  点「全选」后所有卡片被勾选  |  — ；**要接**：选择模式需先有编辑态与工具条，全选/反选依赖选中集合，属同一批 |  —  |
|  反选  |  `BookshelfScreen.kt:621`  |  —  | 未接 |  同上  |  点「反选」后勾选状态反转  |  — ；**要接**：选择模式需先有编辑态与工具条，全选/反选依赖选中集合，属同一批 |  —  |
|  批量下载  |  `BookshelfScreen.kt:632`  |  —  | 未接 |  同上  |  选中 3 本点下载，三本依次缓存全部章节  |  — ；**要接**：批量下载即批量缓存章节，需要在线章节内容；书源已纳入范围未排期（docs/PROJECT.md:24-44），随该模块做 |  —  |
|  移动到分组  |  `BookshelfScreen.kt:643`  |  —  | 未接 |  同上  |  选中书籍后移动到「科幻」，该书出现在该分组  |  见 [已知问题](../KNOWN-ISSUES.md#本地书籍行登记bookshelfmd-的-localbook-未接行) KI-LB2 ；**要接**：动作/手势/私密体系，纯本地可做；books 表已有 order 列支撑拖拽重排 |  localBook / bookGroup  |
|  批量私密标记  |  `BookshelfScreen.kt:655-668`  |  —  | 未接 |  同上，且本地无私密体系  |  选中书籍标记私密后封面模糊  |  仅设密码后显示该按钮；见 [已知问题](../KNOWN-ISSUES.md#本地书籍行登记bookshelfmd-的-localbook-未接行) KI-LB2 ；**要接**：动作/手势/私密体系，纯本地可做；books 表已有 order 列支撑拖拽重排 |  localBook  |
|  批量删除  |  `BookshelfScreen.kt:679`  |  —  | 未接 |  本地只能在详情页单本移出  |  选中 3 本删除后书架少 3 本  |  见 [已知问题](../KNOWN-ISSUES.md#本地书籍行登记bookshelfmd-的-localbook-未接行) KI-LB2 ；**要接**：动作/手势/私密体系，纯本地可做；books 表已有 order 列支撑拖拽重排 |  localBook  |
|  删除时勾选删除源文件  |  `BookshelfScreen.kt:1540-1572`、`:1552-1563`  |  —  | 未接 |  本地无删除确认对话框  |  勾选后删除同时移除本地文件  |  仅 `hasLocalBook` 时显示；见 [已知问题](../KNOWN-ISSUES.md#本地书籍行登记bookshelfmd-的-localbook-未接行) KI-LB2 ；**要接**：动作/手势/私密体系，纯本地可做；books 表已有 order 列支撑拖拽重排 |  localBook  |
|  私密分组锁定页  |  `BookshelfScreen.kt:1619-1646`  |  —  | 未接 |  本地 `isPrivate` 只存字段，UI 无锁定态  |  进入私密分组先显示锁页  |  见 [已知问题](../KNOWN-ISSUES.md#本地书籍行登记bookshelfmd-的-localbook-未接行) KI-LB2 ；**要接**：动作/手势/私密体系，纯本地可做；books 表已有 order 列支撑拖拽重排 |  localBook / bookGroup  |
|  私密解锁（密码 + 生物识别）  |  `BookshelfScreen.kt:1435-1458`、`:261`  |  —  | 未接 |  本地无密码与生物识别  |  输密码或指纹后进入私密分组  |  — ；**要接**：动作/手势/私密体系，纯本地可做；books 表已有 order 列支撑拖拽重排 |  不备份  |
| 空态文案与表情切换 | `BookshelfScreen.kt:1647` | `pages/BookshelfPage.ets:691-702` | 已接 | 本地 7 个表情轮换，三种文案 | 清空书架后显示表情与提示，点表情可切换 | 上游为单张插图 | — |
|  搜索无结果空态与「全局搜索」按钮  |  `BookshelfScreen.kt:1675-1683`  |  `pages/BookshelfPage.ets:699-701`  | 已接 |  本地只把文案换成「没有匹配的书籍」，无跳全局搜索的按钮 。**复核（r340）**：pages/BookshelfPage.ets:1319-1328 空态文案 + Text(全局搜索) 的 onClick | 搜索无结果时出现「全局搜索」按钮，点击跳到全局搜索； 搜索无结果时显示「书架里没有，去全局搜索」，点按钮跳搜索页  |  `bookshelf_empty_global_search` + `global_search`  |  —  |
|  分页惰性渲染  |  `BookshelfScreen.kt:1669`  |  —  | 未接 |  本地整屏一次性渲染  |  非当前分组的书不参与渲染，滚动不掉帧  |  `!isCurrentPage` 时直接 return ；**要接**：ForEach 改 LazyForEach + cachedCount；加载态用现有 LoadingProgress |  —  |
|  横竖屏分别布局  |  `BookshelfScreen.kt:1700-1722`  |  `pages/BookshelfPage.ets:395-404`  | 已接 |  本地只读竖屏三键，横屏无独立设置 。**复核（r340）**：pages/BookshelfPage.ets:551/557/563/603/609/615 六个 active* 方法全部按 isLandscape 分叉 | 横屏后书架列数与列表/网格模式按横屏设置生效，与竖屏不同； 横屏后书架列数改用横屏设置值  |  上游四组键，本地两组  |  —  |
|  加载中对话框  |  `BookshelfScreen.kt:1575-1602`  |  —  | 未接 |  本地无全屏加载态  |  导入大文件时出现加载对话框并可取消  |  — ；**要接**：ForEach 改 LazyForEach + cachedCount；加载态用现有 LoadingProgress |  —  |

---

## A2 书架设置面板

上游主体：`ui/main/bookshelf/BookshelfConfigSheet.kt`（44 个一级控件 + 标签内容二级面板 4 项）、`domain/model/settings/BookshelfSettings.kt`（51 字段）。
本地主体：`pages/BookshelfPage.ets:818-1023` 的 `@Builder private LayoutSheetContent()`（34 个控件：8 菜单 / 13 开关 / 11 步进器 / 2 取色）、`model/BookshelfLayout.ets`（40 字段）、`data/BookshelfLayoutRepository.ets`。

本地 `pages/BookshelfPage.ets:812-817` 的 builder 注释仍自述「只迁移当前项目已有数据模型能支撑的项……封面尺寸、卡片颜色、标签徽标等……留待后续轮次」——其中封面尺寸与卡片颜色已接，该注释待清。

> **默认值来源盘点（r322，2026-11-03）**
>
> 上游 `domain/model/settings/BookshelfSettings.kt` 共 **51 个字段**。本地有集中默认值来源的只有 13 项——`model/BookshelfLayout.ets:69` 的 `DEFAULT_BOOKSHELF_LAYOUT`，逐项等于上游构造默认值，并由 `data/BookshelfLayoutRepository.ets:17-60` 按同名键读写、缺项回落该常量。**另外 38 项没有集中默认值来源**：
>
> - 10 项在 `entry/src/main/ets` 下零命中，即完全未接：`showUnread`、`showUnreadNew`、`showBookCount`、`showLastUpdateTime`、`showBookIntro`、`showWaitUpCount`、`showBookshelfFastScroller`、`bookshelfLayoutModeLandscape`、`autoRefreshBook`、`saveTabPosition`。
> - 28 项只出现在 `data/BackupRepository.ets:424`-`:438` 的 `preferenceKeysByCategory.bookshelfLayout` 键组里（备份会带走、本地无对应界面与默认值）：`bookshelfShowIntro` / `bookshelfShowTag` / `bookshelfShowCustomTags` / `bookshelfShowSourceTags` / `bookshelfShowWordCount` / `bookshelfShowLatestChapter` / `bookshelfIntroMaxLines` / `shouldShowExpandButton` / `bookshelfRefreshingLimit` / `bookshelfLayoutPageLandscape` / `bookshelfLayoutListLandscape` / `bookshelfFolder*`（六项）/ `bookshelfGridLayout` / `bookshelfLayoutCompact` / `bookshelfListCoverCenter` / `bookshelfListIntroBelowContent` / `bookshelfShowDivider` / `bookshelfCardColor` / `bookshelfCardColorDark` / `bookshelfGroupListStyle` / `bookshelfGroupCoverCount` / `bookshelfSearchActionDirectToSearch`。
>
> 所以本表里标「未接」的行，除了界面缺失，还缺一个可对照的本地默认值来源；真要逐项对齐默认值，得先把这些字段接进 `BookshelfLayoutSettings`，不是改一个常量能解决的。同理见封面对照表：`data/CoverSettingsRepository.ets:51` 的 `DEFAULT_COVER_SETTINGS` 12 项与上游 `CoverSettings.kt` 逐项相等，但上游另有 6 项（`loadOnlyOnWifi` / `useDefaultCover` / `restrictCoverRatio` / `exploreFilterState` / `defaultCover` / `defaultCoverDark`）本地未声明。

> **A2 重盘复核（2026-11-06）**：上面那段 r322 的「13 项有默认值来源 / 38 项没有」已随字段接入而过时，保留为历史记录。实测现状：`model/BookshelfLayout.ets` 接口与 `DEFAULT_BOOKSHELF_LAYOUT`（`:138` 起）各 **40 字段**、逐一对齐；上游 `BookshelfSettings.kt` 51 字段里本地仍缺 **11 项**——`showUnread` / `showUnreadNew` / `showTip` / `showBookCount` / `showLastUpdateTime` / `bookshelfShowTag` / `bookshelfShowCustomTags` / `bookshelfShowSourceTags` / `bookshelfShowWordCount` / `showWaitUpCount` / `shouldShowExpandButton`。其中 5 项在 `entry/src/main/ets` 下零命中（`showUnread`、`showUnreadNew`、`showBookCount`、`showLastUpdateTime`、`showWaitUpCount`）；4 项只出现在 `data/BackupRepository.ets:435`-`:436` 的 `preferenceKeysByCategory.bookshelfLayout` 键组（`bookshelfShowTag` 在 `:435`、`bookshelfShowCustomTags`/`bookshelfShowSourceTags`/`bookshelfShowWordCount` 在 `:436`），`shouldShowExpandButton` 只在 `:405` 另一组键组；`showTip` 的 2 处命中是无关的 `.showTips(false)`（`pages/ProfileSubPages.ets:4284`、`pages/ReaderSettingsPage.ets:912`）。

| 上游能力 | 上游位置 | 本地位置 | 状态 | 差异说明 | 验收方式 | 备注 | ZIP 类别 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 分组样式选择 | `BookshelfConfigSheet.kt:85` | `pages/BookshelfPage.ets:829-833` | 已接 | 本地三档菜单「页签 / 隐藏页签 / 文件夹」，选项 `model/BookshelfLayout.ets:98-103`；渲染消费 `:1116-1140` 三分支（文件夹根视图 / 页签栏 / 当前分组＋切换分组） | 切到「文件夹」后书架改为分组卡片网格 | — | — |
| 隐藏没有书籍的分组 | `BookshelfConfigSheet.kt:95` | `pages/BookshelfPage.ets:832-835` | 已接 | 渲染消费 `:219`（`getGroupNames()` 内 `if (!this.layout.hideEmptyGroups) { return names; }`） | 建一个空分组，开启后页签不出现该分组 | — | — |
| 排序方式 | `BookshelfConfigSheet.kt:106` | `pages/BookshelfPage.ets:891-892` | 已接 | 本地 7 档 `-1…5`，选项 `model/BookGroup.ets:39-48`；渲染消费 `:256-257` 交给 `BookshelfSort.sortBooks` | 改为「按书名」后书架按拼音序 | — | bookshelfLayout |
| 排序方向 | `BookshelfConfigSheet.kt:117` | `pages/BookshelfPage.ets:893-894` | 已接 | 渲染消费 `:256-257`（`bookshelfSortOrder` 作为 `sortBooks` 最后一个参数） | 切换方向后书架顺序反转 | — | bookshelfLayout |
| 文件夹布局模式 | `BookshelfConfigSheet.kt:144` | `pages/BookshelfPage.ets:838-840`（竖屏）、`:857-859`（横屏） | 已接 | 上游一个下拉，本地拆成横竖屏两个控件；字段 `model/BookshelfLayout.ets:69` / `:71`；渲染消费 `:603-618 activeFolderLayoutMode()` → `:625-633 folderColumnsTemplate()` | 切到「网格」后文件夹根视图变网格 | 横竖屏分开 | bookshelfLayout |
| 文件夹网格列数 | `BookshelfConfigSheet.kt:165` | `pages/BookshelfPage.ets:841-847`（竖屏）、`:860-866`（横屏） | 已接 | 本地 1..15，字段 `model/BookshelfLayout.ets:73` / `:75`；渲染消费 `:625-633 folderColumnsTemplate()` 生成 `1fr` 模板 → `:1159` | 改为 4 后文件夹卡片每行 4 个 | 横竖屏分开 | bookshelfLayout |
| 文件夹列表列数 | `BookshelfConfigSheet.kt:187` | `pages/BookshelfPage.ets:848-854`（竖屏）、`:867-873`（横屏） | 已接 | 本地 1..5，字段 `model/BookshelfLayout.ets:77` / `:79`；渲染消费同 `:625-633`（`mode !== 1` 时取列表列数） | 改为 2 后文件夹列表每行 2 个 | 横竖屏分开 | bookshelfLayout |
| 文件夹列表封面宽度 | `BookshelfConfigSheet.kt:203` | `pages/BookshelfPage.ets:1005-1007`（字段共用） | 已接 | **实现（r341）**：`components/BookGroupCard.ets` 加 @Prop listCoverWidth=84，宽=listCoverWidth、高=round(listCoverWidth*7/5)，横排 44/62 按比例缩放；`pages/BookshelfPage.ets` 文件夹卡调用传 `listCoverWidth: layout.bookshelfListCoverWidth` | 调「列表封面宽度」后文件夹分组卡封面跟着变宽 | 上游 :203 与 :400 同用 `bookshelfListCoverWidth` | bookshelfLayout |
| 文件夹列表样式 | `BookshelfConfigSheet.kt:221` | `pages/BookshelfPage.ets:876-878` | 已接 | 三档「分组 / 紧凑列表 / 横排封面数量」，选项 `model/BookshelfLayout.ets:123-128`，字段 `:81`；渲染消费 `:1150` 传入 → `components/BookGroupCard.ets:51`（`listStyle === 2` 走横排封面）、`:77`（`compact`）、`:86`（标签文案） | 切换样式后文件夹列表排版改变 | — | bookshelfLayout |
| 文件夹横向封面数 | `BookshelfConfigSheet.kt:231` | `pages/BookshelfPage.ets:880-888` | 已接 | 本地标题「横排封面数量」，1..10，字段 `model/BookshelfLayout.ets:83`；渲染消费 `:1150 coverCount` → `components/BookGroupCard.ets:29-32 previewBooks()` 取前 N 本、`:35-40 emptySlots()` 补空位。仅 `bookshelfGroupListStyle === 2` 时出现，与上游同条件 | 改为 6 后每行显示 6 个封面 | 名字不同 | bookshelfLayout |
| 布局模式（网格/列表） | `BookshelfConfigSheet.kt:248` | `pages/BookshelfPage.ets:899-906` | 已接 | 本地横竖屏各存一套：`bookshelfLayoutModePortrait`（`model/BookshelfLayout.ets:17`）/ `bookshelfLayoutModeLandscape`（`:63`），控件按 `this.isLandscape` 分支写；渲染消费 `:551-554 activeLayoutMode()` → `:1168` 列表/网格分支 | 切换后书架在网格与列表间改变 | 横竖屏分开 | bookshelfLayout |
| 网格样式 | `BookshelfConfigSheet.kt:274` | `pages/BookshelfPage.ets:908-911` | 已接 | 三档「标准 / 紧凑（书名进封面）/ 仅封面」，选项常量 `pages/BookshelfPage.ets:32-36`，字段 `model/BookshelfLayout.ets:35`；渲染消费 `:1244 if (bookshelfGridLayout === 1)` 书名进封面（白字＋渐变）、`:1254 if (=== 0)` 封面下书名，`=== 2` 两条都不命中只剩封面。仅布局模式为网格时出现，与上游同条件 | 切到「仅封面」后网格卡片只剩封面 | — | bookshelfLayout |
| 网格列数 | `BookshelfConfigSheet.kt:286` | `pages/BookshelfPage.ets:915-926` | 已接 | 本地 1..15（对齐上游 `:288` `valueRange = 1f..15f`），横竖屏分别写 `bookshelfLayoutGridPortrait`（`model/BookshelfLayout.ets:19`）/ `bookshelfLayoutGridLandscape`（`:65`）；渲染消费 `:557-560 activeGridColumns()` → `:636-644 bookshelfColumnsTemplate()` → `:1287` | 改为 4 后每行 4 个封面 | — | bookshelfLayout |
| 紧凑标题字体 | `BookshelfConfigSheet.kt:302` | `pages/BookshelfPage.ets:986-987` | 已接 | 本地标题「标题小字号」，字段 `model/BookshelfLayout.ets:29`；渲染消费 `:684-686 bookshelfTitleFontSize()`（小字号 11 / 默认 13），被 `:1186`（列表书名）、`:1246`（网格书名进封面）、`:1255`（网格封面下书名）三处读 | 开启后书名变小 | 名字不同 | bookshelfLayout |
| 标题居中 | `BookshelfConfigSheet.kt:311` | `pages/BookshelfPage.ets:984-985` | 已接 | 字段 `model/BookshelfLayout.ets:27`；渲染消费 4 处：`:1191`（列表书名）、`:1249`（网格书名进封面）、`:1259`（网格封面下书名）、`:1266`（网格作者行） | 开启后书名居中 | — | bookshelfLayout |
| 网格封面宽度 | `BookshelfConfigSheet.kt:320` | `pages/BookshelfPage.ets:1002-1004` | 已接 | 本地 40..200 步长 10（上游 40..150），字段 `model/BookshelfLayout.ets:31`；渲染消费 `:676-682 bookshelfCoverWidthLimit()`（取 `min(格子宽, 配置值)`）→ `:1240 maxWidth` | 调大后网格封面变宽 | 上限比上游宽 50 | bookshelfLayout |
| 显示分割线 | `BookshelfConfigSheet.kt:338` | `pages/BookshelfPage.ets:942-945` | 已接 | 本地标题「显示分隔线」，字段 `model/BookshelfLayout.ets:43`；渲染消费 `:1226-1230`（列表分支画 `Divider()`，0.5 宽、水平留白 16）。控件包在 `:941 if (activeDraftLayoutMode() !== 1)` 内，与上游 `:332` 同条件 | 列表模式出现分割线 | 名字不同（分割 / 分隔） | bookshelfLayout |
| 日间卡片背景色 | `BookshelfConfigSheet.kt:347` | `pages/BookshelfPage.ets:992-996` | 已接 | 本地 `ColorPickerRow('日间卡片底色')`（hex 文本输入＋色块预览，定义 `:791-801`），字段 `model/BookshelfLayout.ets:39`；渲染消费 `:689-693 cardBackgroundColor()` 非夜间取该值 → `:1272 .backgroundColor(...)` | 设为米色后日间卡片变色 | 控件形态是 hex 输入而非调色盘 | bookshelfLayout |
| 夜间卡片背景色 | `BookshelfConfigSheet.kt:368` | `pages/BookshelfPage.ets:997-1001` | 已接 | 本地 `ColorPickerRow('夜间卡片底色')`，字段 `model/BookshelfLayout.ets:41`；渲染消费同 `:689-693`（`readerNightMode` 为真时取该值）→ `:1272` | 设为深灰后夜间卡片变色 | 同上 | bookshelfLayout |
| 紧凑详情 | `BookshelfConfigSheet.kt:389` | `pages/BookshelfPage.ets:990-991` | 已接 | 本地标题「精简详情」，字段 `model/BookshelfLayout.ets:37`；渲染消费两处：`:569-571 showsListDetails()` 关闭列表详情区、`:1262 if (!bookshelfLayoutCompact)` 才渲染网格作者行 | 开启后卡片只剩封面与书名 | 名字不同 | bookshelfLayout |
| 列表封面宽度 | `BookshelfConfigSheet.kt:400` | `pages/BookshelfPage.ets:1005-1007` | 已接 | 本地 40..200 步长 10（上游 40..120），字段 `model/BookshelfLayout.ets:33`；渲染消费 `:1177-1183` 列表 `BookCover` 的 `displayWidth: bookshelfListCoverWidth` 与 `displayHeight: round(×7/5)` | 调大后列表封面变宽 | 上限比上游宽 80 | bookshelfLayout |
| 列表列数 | `BookshelfConfigSheet.kt:410` | `pages/BookshelfPage.ets:927-936` | 已接 | 本地 1..5（对齐上游 `:412` `valueRange = 1f..5f`），横竖屏分别写 `bookshelfLayoutListPortrait`（`model/BookshelfLayout.ets:21`）/ `bookshelfLayoutListLandscape`（`:67`）；渲染消费 `:563-566 activeListColumns()` → `:636-644 bookshelfColumnsTemplate()` | 改为 2 后列表每行 2 个 | — | bookshelfLayout |
| 显示更多信息 | `BookshelfConfigSheet.kt:426` | `pages/BookshelfPage.ets:946-948` | 已接 | 本地字段名 `showBookIntro`（`model/BookshelfLayout.ets:86`，与上游 `BookshelfSettings.showBookIntro` 同名同义）；渲染消费两处：`:949 if (layoutDraft.showBookIntro)` 才展开「封面垂直居中 / 显示最新章节 / 显示简介 / 简介行数」四项，`:569-571 showsListDetails()` 用它做列表详情区总门 | 开启后列表卡片显示更多字段 | 本地字段名 `showBookIntro` | — |
| 封面垂直居中 | `BookshelfConfigSheet.kt:439` | `pages/BookshelfPage.ets:950-952` | 已接 | 字段 `model/BookshelfLayout.ets:45`；渲染消费 `:1214 .alignItems(bookshelfListCoverCenter ? VerticalAlign.Center : VerticalAlign.Top)` | 开关后列表封面垂直居中 | — | bookshelfLayout |
| 显示最新章节 | `BookshelfConfigSheet.kt:448` | `pages/BookshelfPage.ets:953-955` | 已接 | 字段 `model/BookshelfLayout.ets:51`；渲染消费 `:1203-1209`（`Text(book.lastChapter)`，受 `showsListDetails() && bookshelfShowLatestChapter` 双门）。数据源 `model/Book.ets` 有 `lastChapter` | 开启后卡片显示最新章节名 | — | bookshelfLayout |
| 显示简介 | `BookshelfConfigSheet.kt:457` | `pages/BookshelfPage.ets:956-960` | 已接 | 字段 `model/BookshelfLayout.ets:49`；渲染消费两处：`:1193-1200`（简介在右列）与 `:1216-1223`（简介铺底部），内容取 `book.description`，行数走 `:574-576 introMaxLines()` | 开启后列表卡片显示简介 | 数据源是 `model/Book.ets` 的 `description` | bookshelfLayout |
| 简介在书名下方 | `BookshelfConfigSheet.kt:466` | `pages/BookshelfPage.ets:961-965` | 已接 | 本地标题「简介在封面和信息下方」，字段 `model/BookshelfLayout.ets:47`；渲染消费 `:1193-1194`（为假时右列）与 `:1216-1217`（为真时底部）互斥分支。控件额外条件 `bookshelfShowIntro && activeDraftLayoutMode() === 0`，与上游 `:465` 同 | 开启后简介排版位置改变 | 名字不同 | bookshelfLayout |
| 简介行数 | `BookshelfConfigSheet.kt:478` | `pages/BookshelfPage.ets:967-975` | 已接 | 本地 0..10，0 表示不限（对齐上游 `:480` 语义），字段 `model/BookshelfLayout.ets:53`；渲染消费 `:574-576 introMaxLines()`（`>0 ? 值 : 999`）→ `:1197` 与 `:1220` 的 `.maxLines(...)` | 设为 2 行后简介两行截断 | — | bookshelfLayout |
| 显示标签 | `BookshelfConfigSheet.kt:489` | — | 已接 | **实现（r341）**：布局面板「标签」段 LayoutSwitchRow 绑 bookshelfShowTag（默认 true），卡片 displayTagsOf 用它做总门 | 开「显示标签」书卡出现标签行，关掉整行消失 | 联动 A1 卡片 | bookshelfLayout |
| 标签显示内容 | `BookshelfConfigSheet.kt:511`、`:708` | — | 已接 | **实现（r341）**：「标签显示内容」可点行 + 展开三复选（字数 / 来源分类 / 自定义标签），描述串 tagSourcesLabel() 显示开着项、全关显示「无」；三复选即 :224–:226，与 :209 同一对话框一次做完 | 点「标签显示内容」展开三复选，描述显示「自定义 · 来源分类 · 字数」，取消项描述随之变 | 二级面板入口（:224–:226 随本行做完） | bookshelfLayout |
|  自定义标签配色  |  `BookshelfConfigSheet.kt:518`  |  `pages/BookshelfPage.ets` 标签段  | 已接 |  原 grep customTagColors 零命中、无字段无控件。**实现（r341）**：布局面板「标签」段新增「自定义标签配色」开关，绑 enableCustomTagColors（model/BookshelfLayout.ets、data/BookshelfLayoutRepository.ets）；开启后标签行按配色取色、关闭回主题色，开关随 config.xml 写出与读回  |  开启开关后书卡标签按配色变色、关闭后回统一主题色；重启后开关状态保留  |  — |  —  |
|  管理标签配色  |  `BookshelfConfigSheet.kt:525`  |  `pages/BookshelfPage.ets:1402`  | 已接 |  原无配色管理页。**实现（r341）**：开配色后布局面板出现「管理标签配色」入口，点开 TagColorSheet 可生成 8 组、添加、编辑、删除、取色；lib/TagColorUtils.ets 提供 HSL↔ARGB 与 deriveTagBgColor 推背景，草稿经 onSaveLayout 即时落盘  |  点「管理标签配色」打开配色页，生成 8 组、添加选红出现红字淡红底、删除后不崩  |  — |  —  |
| 书名最大行数 | `BookshelfConfigSheet.kt:540` | `pages/BookshelfPage.ets:977-982` | 已接 | 本地 1..5，字段 `model/BookshelfLayout.ets:23`；渲染消费 `:1188 .maxLines(this.layout.bookshelfTitleMaxLines)`（列表书名）与 `:1256`（网格封面下书名） | 设为 1 后长书名单行省略 | — | bookshelfLayout |
| 书封阴影 | `BookshelfConfigSheet.kt:550` | `pages/BookshelfPage.ets:1010-1011` | 已接 | 字段 `model/BookshelfLayout.ets:25`；渲染消费 `:1177 shadowEnabled`（列表）与 `:1238`（网格）传进 `BookCover`，落到 `components/BookCover.ets:264 .shadow(this.shadowEnabled ...)` | 开关后封面阴影出现与消失 | — | bookshelfLayout |
| 显示未读数 | `BookshelfConfigSheet.kt:561` | — | 已接 | **实现（r341）**：「徽标」段 LayoutSwitchRow 绑 showUnread（默认 true），卡片 unreadTextOf / showBadgeDotOf 消费 | 关「显示未读数」后红色未读角标消失 | 联动 A1 卡片 | — |
| 显示更新红点 | `BookshelfConfigSheet.kt:570` | — | 已接 | **实现（r341）**：LayoutSwitchRow 绑 showUnreadNew（默认 true）；红点耦合 showUnread && showUnreadNew && lastCheckCount>0，只开红点不开未读也不显示 | 只开「显示更新红点」、关「显示未读数」时红点不出现 | — | — |
| 显示等待更新数 | `BookshelfConfigSheet.kt:579` | — | 已接 | **实现（r341）**：LayoutSwitchRow 绑 showWaitUpCount（默认 false），控制标题 (N) 尾巴（见 :130）；本地暂无待更新队列供其消费，开关与字段 / 备份已落盘 | 面板「显示等待更新数」开关可切换并落盘 | — | — |
| 显示书籍计数 | `BookshelfConfigSheet.kt:588` | — | 已接 | **实现（r341）**：LayoutSwitchRow 绑 showBookCount（默认 true），字段 / 仓储 / 备份已落盘；本地分组卡「N 本」(`components/BookGroupCard.ets:47`，:255 已交付) 仍恒显示、未随该开关显隐（渲染侧待补） | 面板「显示书籍计数」开关可切换并落盘；分组卡「N 本」当前恒显示（见差异说明） | 联动 A1 文件夹 | — |
| 显示最后更新时间 | `BookshelfConfigSheet.kt:597` | — | 已接 | **实现（r341）**：LayoutSwitchRow 绑 showLastUpdateTime（默认 false），列表卡按它 && !book.isLocal 渲染 toTimeAgo（见 :127） | 开「显示最后更新时间」后非本地书卡片显示「N 天前」，本地书不显示 | — | — |
| 显示书籍类型 | `BookshelfConfigSheet.kt:606` | — | 已接 | **实现（r341）**：LayoutSwitchRow 绑 showTip（默认 false，上游默认 false），卡片 bookTypeLabel() 消费（见 :121） | 开「显示书籍类型」后卡片出现「本地 / EPUB」类型标签，关掉消失 | — | — |
| 搜索优先于筛选 | `BookshelfConfigSheet.kt:617` | `pages/BookshelfPage.ets:1014-1016` | 已接 | 上游串 `search_filter_first` = 「搜索按钮优先打开搜索页面」，沿用旧行名；本地标题「搜索按钮优先打开搜索页」，字段 `model/BookshelfLayout.ets:55`；渲染消费 `:1078-1095`——单击时该值为真直接进搜索页、为假先展开筛选框，长按行为反之 | 开启后点搜索按钮直接进搜索页 | `search_filter_first` | bookshelfLayout |
| 快速滚动条开关 | `BookshelfConfigSheet.kt:627` | `pages/BookshelfPage.ets:1017-1019` | 已接 | 本地标题「显示快速滚动条」，字段 `model/BookshelfLayout.ets:57`；渲染消费 `:1290 .scrollBar(this.layout.showBookshelfFastScroller ? BarState.On : BarState.Off)`（书架 Grid） | 开启后书架右侧出现滚动条 | 名字不同 | — |
|  页签栏菜单按钮  |  `BookshelfConfigSheet.kt:636`  |  `model/BookshelfLayout.ets`、`data/BookshelfLayoutRepository.ets`、`data/BackupRepository.ets`、`pages/BookshelfPage.ets`  | 已接 |  **实现（r341）**：新增设置键 `showBookshelfTabMenu`（默认 `true`），接口/DEFAULT/copy 三处 + 仓储 `load/save/mergeFromAndroidValues/toAndroidValues` 四处 + 备份 `createBackup`/`restoreBookshelfLayout` 写出键名 `shouldShowExpandButton` + 布局面板「其它」段 `LayoutSwitchRow`；页签按钮显隐消费 `layout.showBookshelfTabMenu`  | 布局面板关「页签栏菜单按钮」后页签行右端按钮消失，`aa force-stop` 重启仍保持关闭（值落盘）  |  `shouldShowExpandButton`  |  readConfig  |
| 书架更新线程数 | `BookshelfConfigSheet.kt:645` | — | 已接 | **实现（r341）**：「其它」段 LayoutStepperRow 绑已有 bookshelfRefreshingLimit（0..100 步进 1）；2b 在 BookshelfLayoutRepository.toAndroidValues / BackupRepository 补 `bookshelfUpdateLimit` 备份映射；taskpool 并发度消费待 :120 的刷新队列完善 | 面板「书架更新线程数」可加减并落盘，备份 XML 写出 `bookshelfUpdateLimit` | `bookshelfUpdateLimit` | threadCount |
| 标签内容·字数 | `BookshelfConfigSheet.kt:708` | — | 已接 | **实现（r341）**：随 :209 的三复选对话框一次做完（规格 2b :213），绑 bookshelfShowWordCount（默认 true），displayTagsOf 控制字字段；批 3 不再单独做本行 | 「标签显示内容」取消「字数」后标签行不再显示字数 | — | bookshelfLayout |
| 标签内容·来源分类 | `BookshelfConfigSheet.kt:708` | — | 已接 | **实现（r341）**：随 :209 的三复选对话框一次做完，绑 bookshelfShowSourceTags（默认 true），displayTagsOf 控制 category 去重段 | 「标签显示内容」取消「来源分类」后标签行不再显示分类 | — | bookshelfLayout |
| 标签内容·自定义标签 | `BookshelfConfigSheet.kt:708` | — | 已接 | **实现（r341）**：随 :209 的三复选对话框一次做完，绑 bookshelfShowCustomTags（默认 true），displayTagsOf 控制 customTag 段 | 「标签显示内容」取消「自定义标签」后标签行不再显示自定义标签 | — | bookshelfLayout |

---

## A3 分组管理

上游主体：`ui/main/bookshelf/GroupManageSheet.kt`（377 行）、`ui/book/group/GroupEditSheet.kt`（386 行）、`ui/main/bookshelf/autoGroup/AiAutoGroupSheet.kt`（734 行）。
本地主体：`pages/BookshelfPage.ets:219-277`（管理网格）、`:280-378`（编辑表单）、`model/BookGroup.ets`、`data/BookGroupRepository.ets`（534 行）。

| 上游能力 | 上游位置 | 本地位置 | 状态 | 差异说明 | 验收方式 | 备注 | ZIP 类别 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 分组管理面板标题 | `GroupManageSheet.kt:131` | `pages/BookshelfPage.ets:221-225` | 已接 | 本地标题为「分组管理」+ 新建/完成 | 打开面板可见标题与新建按钮 | — | bookGroup |
| 新建分组 | `GroupManageSheet.kt:157` | `pages/BookshelfPage.ets:221-225` | 已接 | 本地先建空分组再编辑 | 点新建后出现空分组并进入编辑表单 | — | bookGroup |
|  AI 自动分组  |  `GroupManageSheet.kt:167`、`autoGroup/AiAutoGroupSheet.kt:734`  |  —  | 不适用 |  本地 `aiAuto`/`autoGroup` 全仓 0 命中 。**判不适用（r340）**：上游这一项调用 AI 做语义分组；AI 在线服务在项目范围之外（docs/PROJECT.md:48），属「范围之外」一类证据。本地也没有可据以分组的语义数据 | — |  四阶段流程，需模型接入  |  bookGroup  |
|  添加标签匹配规则  |  `GroupManageSheet.kt:176`、`:266-283`  |  —  | 已接 |  本地 `tagRule` 0 命中，无规则表 ；**实现（r341）**：pages/BookshelfPage.ets 分组管理顶栏「新建」改三项菜单（新建分组 / 添加标签匹配规则 / 同步标签分组），规则编辑由分组编辑面板内的开关承担（未做独立面板，两条路径写同一张表），写入 data/TagGroupRuleRepository  |  点分组管理顶栏「新建」出三项菜单，选「添加标签匹配规则」进分组编辑面板并设置规则表达式  |  依赖 `tagGroupRule.json` 读写  |  tagGroupRule  |
|  同步标签分组  |  `GroupManageSheet.kt:185`  |  —  | 已接 |  同上 ；**实现（r341）**：同步实现为 data/TagGroupRuleSync.ets，掩码用加法不用位运算（ArkTS 位或只保留低 32 位会截断 2^52 组 id），只加不减；实测点同步后「静候」分组由 2 本变 210 本、其余分组书数不变  |  点「同步标签分组」后按规则把命中的书补进对应分组，原手动分在别组的书不掉出去  |  —  |  tagGroupRule  |
| 分组卡片网格 | `GroupManageSheet.kt:207-262` | `pages/BookshelfPage.ets:243-264` | 已接 | 本地固定两列 `1fr 1fr`，上游 `Adaptive(GroupCardMinWidth)` | 打开面板看到分组卡片网格 | — | bookGroup |
| 分组显隐开关 | `GroupManageSheet.kt:207-262` | `pages/BookshelfPage.ets:247-251` | 已接 | 本地 Toggle 直接改 `show` | 关掉某分组后书架页签不再出现它 | — | bookGroup |
| 分组封面 | `GroupEditSheet.kt:154-164` | `pages/BookshelfPage.ets:291-320` | 已接 | 本地点击选图、长按清除 | 选图后分组卡片显示该封面 | — | bookGroup |
| 分组名称 | `GroupEditSheet.kt:168-175` | `pages/BookshelfPage.ets:322-330` | 已接 | 本地空名校验在提交时 | 改名为「科幻」后书架页签同步改名 | — | bookGroup |
| 分组排序方式 | `GroupEditSheet.kt:180-190` | `pages/BookshelfPage.ets:332-337` | 已接 | 本地 `BookshelfSort.ets:26` 按组覆盖全局 | 设某组为「按书名」，该组内按拼音序 | — | bookGroup |
| 分组下拉刷新 | `GroupEditSheet.kt:196-199` | `pages/BookshelfPage.ets:339-346` | 已接 | 本地仅存字段，注释自认「当前不控制实际更新」 | 关掉某组的下拉刷新后，该组下拉不再刷新 | 字段已接、行为未接 | bookGroup |
| 分组私有 | `GroupEditSheet.kt:205-215` | `pages/BookshelfPage.ets:348-355` | 已接 | 本地仅存字段，注释自认「当前不限制跨分组显示」 | 标记私密后该组内容需解锁才可见 | 字段已接、行为未接，见 A1 | bookGroup |
|  标签匹配规则开关  |  `GroupEditSheet.kt:221-228`  |  —  | 已接 |  本地编辑表单无此项 ；**实现（r341）**：pages/BookshelfPage.ets 分组编辑面板「私有分组」行之后加「标签匹配规则」开关，默认关，开后显示多行规则输入框与「复制」「粘贴」（粘贴走 PasteButton 授权）  |  进分组编辑面板可见开关默认关，打开后出现多行输入框与「复制」「粘贴」，说明文案在「自动匹配 / 手动管理」间切换  |  —  |  tagGroupRule  |
|  标签匹配规则输入  |  `GroupEditSheet.kt:231-240`  |  —  | 已接 |  同上 ；**实现（r341）**：分组编辑面板用 TextArea（多行）输入规则，保存前 new RegExp 校验、非法正则提示「正则表达式不合法」不落库，保存后立刻全量同步且重开 App 规则仍在  |  输入表达式保存后命中的书自动入组、重开 App 规则仍在；输入非法正则弹「正则表达式不合法」且面板不关  |  —  |  tagGroupRule  |
| 删除分组 | `GroupManageSheet.kt:134-148` | `pages/BookshelfPage.ets:357-382` | 已接 | 本地二次确认（点两次），上游为独立确认面板 | 点删除两次后分组消失，书回到未分组 | — | bookGroup |
|  删除分组时书籍去向提示  |  `GroupManageSheet.kt:134-148`  |  `pages/BookshelfPage.ets` 的 `GroupEditorContent()`  | 已接 |  **实现（r341）**：在 `onRemoveGroup` 前用 `getUIContext().showAlertDialog` 弹确认框，N=`this.books.filter(b=>(b.groupNames??[]).includes(removed.groupName)).length` 真算，标题「删除分组」、正文「该分组下的 N 本书会移出到未分组」、按钮「取消」「删除」  | 删除含 2 本书的「静候」分组前弹框「该分组下的 2 本书会移出到未分组」，与分组卡「2 本」一致  |  原有「点两次」确认仍在  |  bookGroup  |
| 重置分组封面 | `GroupManageSheet.kt:197` | `pages/BookshelfPage.ets:310-317` | 已接 | 本地为「清除」按钮 | 点清除后分组封面恢复默认 | — | bookGroup |
| 分组拖拽排序 | `GroupManageSheet.kt:207-262` | `pages/BookshelfPage.ets:265-272` | 已接 | 本地 `onMove` 重排后整体写回 | 拖动分组卡片换位后书架页签顺序同步 | — | bookGroup |
|  分组书籍计数  |  `GroupManageSheet.kt:207-262`  |  `pages/BookshelfPage.ets` 的 `GroupManagerGrid()`  | 已接 |  **实现（r341）**：分组卡副标题改成 「N 本 · 排序方式」形式（N 用 countBooksInGroup(group.groupName) 真算），count 真算；顺带去掉「分组刷新未接入」占位假话（「私有标记未生效」留批 6）  | 分组管理面板「静候 2 本 · 默认」「完结 22 本 · 默认」「番茄 3 本 · 默认」各不相同  |  —  |  bookGroup  |
|  分组四宫格预览  |  `BookItem.kt:361-432`  |  —  | 已接 |  本地卡片只显示单封面 。**复核（r340）**：components/BookGroupCard.ets:29-32 previewBooks() + :51-70 多封面；coverCount 由 pages/BookshelfPage.ets:1150 传入 | 分组卡显示 coverCount 张预览封面，不足时右侧留空位； 分组卡片显示前 4 本书封面拼图  |  与 A1 文件夹同一组件  |  bookGroup  |
|  分组私密锁定显示  |  `BookshelfScreen.kt:1619-1646`  |  —  | 未接 |  本地无锁定态  |  私密分组卡片显示锁图标而非封面  |  — ；**要接**：分组卡显示锁定态图标，与私密体系同批 |  bookGroup  |
| 分组内书籍排序覆盖 | `BookshelfRepository.kt` sortBooks | `data/BookshelfSort.ets:26` | 已接 | 分组 `bookSort >= 0` 覆盖全局 | 全局按时间、某组按书名，进该组顺序不同 | 逻辑完整对齐 | bookGroup |

---

## B 书籍详情页与元数据

上游主体：`ui/book/info/BookInfoScreen.kt`（2479 行）、`BookInfoViewModel.kt`（2164 行）、`BookInfoContract.kt:376-396`（20 项 `BookInfoMenuAction`）、`edit/BookInfoEditScreen.kt`（578 行）、`domain/model/Book.kt`（30 个持久字段）。
本地主体：`pages/BookInfoPage.ets`（577 行）、`model/Book.ets`（33 字段）。

本地 `model/Book.ets` 缺 `isPrivate`、`canUpdate`、`disableReadRecord`、`splitLongChapter`、`deleteAlert`、`totalChapterNum`、`latestChapterTitle`，这七项是本块多条「未接」的直接原因：其中 `isPrivate`、`canUpdate`、`disableReadRecord`、`totalChapterNum`、`latestChapterTitle` 在 `data/RdbSchema.ets` 的 `books` 表 DDL 里已有同名列，缺的是 `data/BookRepository.ets:127-131` 的 `selectBooksSql` 没查它们、`:674-717` 的 `readBookRow` 也没读它们；`splitLongChapter`、`deleteAlert` 两列全仓 0 命中。

| 上游能力 | 上游位置 | 本地位置 | 状态 | 差异说明 | 验收方式 | 备注 | ZIP 类别 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 顶栏返回 | `BookInfoScreen.kt:737` | `pages/BookInfoPage.ets:262-267` | 已接 | — | 点返回回到书架并保持原分组 | — | — |
| 顶栏编辑 | `BookInfoScreen.kt:877` | `pages/BookInfoPage.ets:266` | 已接 | — | 点编辑弹出元数据编辑面板 | — | localBook |
|  顶栏分享  |  `BookInfoContract.kt:376-396`  |  `pages/BookInfoPage.ets:269`  | 未接 |  本地 `onUnavailableAction('书籍分享尚未迁移')`  |  点分享生成可分享的书籍卡片或链接  |  — ；**要接**：顶栏分享与更多菜单是整块入口，先建菜单骨架（18 项按依赖分批接线） |  —  |
|  顶栏更多菜单（18 项）  |  `BookInfoScreen.kt:1033-1141`  |  `pages/BookInfoPage.ets:327`  | 未接 |  本地整组占位  |  点更多弹出 18 项菜单  |  本块后续逐项列出；见 [已知问题](../KNOWN-ISSUES.md#本地书籍行登记bookshelfmd-的-localbook-未接行) KI-LB3 ；**要接**：顶栏分享与更多菜单是整块入口，先建菜单骨架（18 项按依赖分批接线） |  localBook / bookSource / readRecord  |
|  菜单·书源自定义按钮  |  `BookInfoContract.kt:376-396`  |  —  | 未接 |  依赖书源自定义按钮体系。在线书源抓取自 2026-11-09 起**已纳入范围、尚未排期**（[项目队列](../PROJECT.md) `:24-44`），故由 `不适用` 改判 `未接`，排期时随书源模块一起做  |  —  |  要接，随在线书源排期 ；**要接**：依赖在线书源（登录、变量、换源、回调、简介标记）；书源已纳入范围未排期，随该模块做 |  bookSource  |
| 菜单·编辑 | `BookInfoContract.kt:376-396` | `pages/BookInfoPage.ets:266` | 已接 | 与顶栏编辑同一入口 | 点菜单「编辑」弹出编辑面板 | — | localBook |
|  菜单·分享  |  `BookInfoContract.kt:376-396`  |  —  | 未接 |  同顶栏分享  |  点菜单「分享」可分享  |  — ；**要接**：顶栏分享与更多菜单是整块入口，先建菜单骨架（18 项按依赖分批接线） |  —  |
|  菜单·上传书籍  |  `BookInfoContract.kt:376-396`  |  —  | 未接 |  本地无 WebDAV 上传  |  点上传后书籍备份到远端  |  依赖 WebDAV；见 [已知问题](../KNOWN-ISSUES.md#本地书籍行登记bookshelfmd-的-localbook-未接行) KI-LB3 ；**要接**：WebDAV 客户端已在（lib/WebDav.ets + lib/WebDavSync.ets），上传书籍与同步到远端可直接接 |  localBook  |
|  菜单·同步到远端  |  `BookInfoContract.kt:376-396`  |  —  | 未接 |  同上  |  点同步后远端记录更新  |  同上；见 [已知问题](../KNOWN-ISSUES.md#本地书籍行登记bookshelfmd-的-localbook-未接行) KI-LB3 ；**要接**：WebDAV 客户端已在（lib/WebDav.ets + lib/WebDavSync.ets），上传书籍与同步到远端可直接接 |  localBook  |
|  菜单·刷新书籍信息  |  `BookInfoContract.kt:376-396`  |  —  | 未接 |  本地无刷新动作  |  点刷新后简介与目录更新  |  — ；**要接**：纯本地动作：刷新书籍信息走 BookRepository 重扫、置顶用 order 列、复制链接用剪贴板、删除确认与清缓存已有基础 |  bookSource  |
| 菜单·阅读记录 | `BookInfoContract.kt:376-396` | `pages/BookInfoPage.ets:254` | 已接 | 本地走动作卡而非菜单 | 点「阅读记录」打开该书阅读记录 | — | readRecord |
| 菜单·禁用阅读记录 | `BookInfoContract.kt:376-396` | — | 已接 | `model/Book.ets` 无 `disableReadRecord` 字段；`data/RdbSchema.ets:253`、`data/BookRepository.ets:190` 有列 | 禁用后读该书不再计入阅读记录 | 见 [已知问题](../KNOWN-ISSUES.md#本地书籍行登记bookshelfmd-的-localbook-未接行) KI-LB3 | localBook / readRecord |
|  菜单·登录书源  |  `BookInfoContract.kt:376-396`  |  —  | 未接 |  本地无书源登录体系  |  点登录后书源账号状态变为已登录  |  — ；**要接**：依赖在线书源（登录、变量、换源、回调、简介标记）；书源已纳入范围未排期，随该模块做 |  bookSource  |
|  菜单·置顶  |  `BookInfoContract.kt:376-396`  |  —  | 未接 |  本地无置顶动作  |  置顶后该书排在书架首位  |  依赖 `Book.order` 与置顶位；见 [已知问题](../KNOWN-ISSUES.md#本地书籍行登记bookshelfmd-的-localbook-未接行) KI-LB3 ；**要接**：纯本地动作：刷新书籍信息走 BookRepository 重扫、置顶用 order 列、复制链接用剪贴板、删除确认与清缓存已有基础 |  localBook  |
|  菜单·设置书源变量  |  `BookInfoContract.kt:376-396`  |  —  | 未接 |  本地无书源变量  |  修改变量后书籍内容按新变量刷新  |  — ；**要接**：依赖在线书源（登录、变量、换源、回调、简介标记）；书源已纳入范围未排期，随该模块做 |  bookSource  |
|  菜单·设置书籍变量  |  `BookInfoContract.kt:376-396`  |  —  | 未接 |  同上  |  设置变量后该书单独生效  |  见 [已知问题](../KNOWN-ISSUES.md#本地书籍行登记bookshelfmd-的-localbook-未接行) KI-LB3 ；**要接**：依赖在线书源（登录、变量、换源、回调、简介标记）；书源已纳入范围未排期，随该模块做 |  localBook  |
|  菜单·复制书籍链接  |  `BookInfoContract.kt:376-396`  |  —  | 未接 |  本地无剪贴板动作  |  复制后可粘贴出 `bookUrl`  |  — ；**要接**：纯本地动作：刷新书籍信息走 BookRepository 重扫、置顶用 order 列、复制链接用剪贴板、删除确认与清缓存已有基础 |  —  |
|  菜单·复制目录链接  |  `BookInfoContract.kt:376-396`  |  —  | 未接 |  同上  |  复制后可粘贴出 `tocUrl`  |  — ；**要接**：纯本地动作：刷新书籍信息走 BookRepository 重扫、置顶用 order 列、复制链接用剪贴板、删除确认与清缓存已有基础 |  —  |
|  菜单·允许更新  |  `BookInfoContract.kt:376-396`  |  —  | 未接 |  `Book.ets` 缺 `canUpdate` 字段  |  关掉后批量更新跳过该书  |  见 [已知问题](../KNOWN-ISSUES.md#本地书籍行登记bookshelfmd-的-localbook-未接行) KI-LB3 ；**要接**：纯本地动作：刷新书籍信息走 BookRepository 重扫、置顶用 order 列、复制链接用剪贴板、删除确认与清缓存已有基础 |  localBook  |
|  菜单·长按分章  |  `BookInfoContract.kt:376-396`  |  —  | 未接 |  `splitLongChapter` 全仓 0 命中  |  关掉后超长章节不再自动分章  |  字段在 `ReadConfig` 内嵌；见 [已知问题](../KNOWN-ISSUES.md#本地书籍行登记bookshelfmd-的-localbook-未接行) KI-LB3 ；**要接**：纯本地动作：刷新书籍信息走 BookRepository 重扫、置顶用 order 列、复制链接用剪贴板、删除确认与清缓存已有基础 |  localBook  |
|  菜单·删除确认  |  `BookInfoContract.kt:376-396`  |  —  | 未接 |  `deleteAlert` 全仓 0 命中  |  关掉后移出书架不再弹确认  |  见 [已知问题](../KNOWN-ISSUES.md#本地书籍行登记bookshelfmd-的-localbook-未接行) KI-LB3 ；**要接**：纯本地动作：刷新书籍信息走 BookRepository 重扫、置顶用 order 列、复制链接用剪贴板、删除确认与清缓存已有基础 |  localBook  |
|  菜单·清除缓存  |  `BookInfoContract.kt:376-396`  |  —  | 未接 |  本地无章节缓存体系  |  点清除后缓存章节数归零  |  — ；**要接**：纯本地动作：刷新书籍信息走 BookRepository 重扫、置顶用 order 列、复制链接用剪贴板、删除确认与清缓存已有基础 |  —  |
|  菜单·显示日志  |  `BookInfoContract.kt:376-396`  |  —  | 未接 |  本地无日志页  |  打开该书相关日志  |  — ；**要接**：纯本地动作：刷新书籍信息走 BookRepository 重扫、置顶用 order 列、复制链接用剪贴板、删除确认与清缓存已有基础 |  —  |
|  菜单·设为私密  |  `BookInfoContract.kt:376-396`  |  —  | 未接 |  `Book.ets` 缺 `isPrivate` 字段  |  标记后封面在书架模糊  |  与 A1 私密体系同一缺口；见 [已知问题](../KNOWN-ISSUES.md#本地书籍行登记bookshelfmd-的-localbook-未接行) KI-LB3 ；**要接**：私密体系：books 表需加 isPrivate 列，详情页加设为私密与锁定内容页 |  localBook  |
| 头部封面 | `BookInfoScreen.kt:1144` | `pages/BookInfoPage.ets:155-157` | 已接 | 本地 112×157 | 详情页顶部显示大封面 | — | localBook |
|  头部书名（含长按菜单）  |  `BookInfoScreen.kt:1298-1320`  |  `pages/BookInfoPage.ets:158-159`  | 未接 |  本地为纯 `Text`，不可点、无长按菜单  |  长按书名弹出「搜索 / 展开」，选展开后书名不再截断  |  `AnimatedTextLine` + `RoundDropdownMenu`；见 [已知问题](../KNOWN-ISSUES.md#本地书籍行登记bookshelfmd-的-localbook-未接行) KI-LB4 ；**要接**：头部文本行与封面加 onClick/LongPress 与 accessibilityText；来源行取 originName/androidOriginalPath |  localBook  |
|  头部作者行（点击 / 长按）  |  `BookInfoScreen.kt:1326`  |  `pages/BookInfoPage.ets:160-161`  | 未接 |  本地为纯 `Text`，无点击与长按  |  点作者跳作者搜索结果，长按走另一分支  |  `author_show` + `AuthorClick(longClick)`；见 [已知问题](../KNOWN-ISSUES.md#本地书籍行登记bookshelfmd-的-localbook-未接行) KI-LB4 ；**要接**：头部文本行与封面加 onClick/LongPress 与 accessibilityText；来源行取 originName/androidOriginalPath |  localBook  |
|  头部来源行  |  `BookInfoScreen.kt:1335-1339`  |  —  | 未接 |  本地无来源行  |  书名下显示书源名，点击进入该来源详情  |  `origin_show` + `OriginClick`；见 [已知问题](../KNOWN-ISSUES.md#本地书籍行登记bookshelfmd-的-localbook-未接行) KI-LB4 ；**要接**：头部文本行与封面加 onClick/LongPress 与 accessibilityText；来源行取 originName/androidOriginalPath |  localBook  |
|  头部高亮标签行  |  `BookInfoScreen.kt:1355-1385`  |  —  | 未接 |  本地无高亮标签体系  |  命中高亮规则的标签以高亮样式单独一行  |  `highlightedTags` ← `highlightTagRuleRepository` ；**要接**：头部文本行与封面加 onClick/LongPress 与 accessibilityText；来源行取 originName/androidOriginalPath |  highlightTagRule  |
| 头部分组与类型标签横排 | `BookInfoScreen.kt:1367-1390` | `pages/BookInfoPage.ets:167-181` | 已接 | 本地把分类、分组、格式、文件大小、自定义标签合成一行 `BookInfoTag` | 详情页头部显示「分组：科幻」等标签 | 本地无 `fadingEdge` 渐隐 | localBook / bookGroup |
|  封面点击与长按  |  `BookInfoScreen.kt:1144`  |  `pages/BookInfoPage.ets:156`  | 未接 |  本地封面不可点  |  点封面全屏预览，长按弹出换封面  |  `CoverClick`/`CoverLongClick`；见 [已知问题](../KNOWN-ISSUES.md#本地书籍行登记bookshelfmd-的-localbook-未接行) KI-LB4 ；**要接**：头部文本行与封面加 onClick/LongPress 与 accessibilityText；来源行取 originName/androidOriginalPath |  localBook  |
|  封面无障碍描述  |  `BookInfoScreen.kt:1164`  |  —  | 未接 |  本地无  |  读屏聚焦封面时播报书名  |  `a11y_book_cover_actions`；见 [已知问题](../KNOWN-ISSUES.md#本地书籍行登记bookshelfmd-的-localbook-未接行) KI-LB1 ；**要接**：头部文本行与封面加 onClick/LongPress 与 accessibilityText；来源行取 originName/androidOriginalPath |  localBook  |
|  加入书架（含冲突提示）  |  `BookInfoScreen.kt:1390-1485`  |  —  | 未接 |  本地入口只在书架内，无「加入」动作与同名冲突高亮  |  从搜索进详情可加入书架，同名时高亮冲突  |  本地无搜索进详情的路径；见 [已知问题](../KNOWN-ISSUES.md#本地书籍行登记bookshelfmd-的-localbook-未接行) KI-LB4 ；**要接**：需先有非书架来源的详情页入口（搜索/导入页），随导入与搜索批次 |  localBook  |
| 移出书架 | `BookInfoScreen.kt:1390-1485` | `pages/BookInfoPage.ets:188-192` | 已接 | 本地按钮文案「已在书架」，点击即移出并二次确认 | 点后该书从书架消失 | 文案与行为不符，见下方小结 | localBook |
|  长按加入书架选分组  |  `BookInfoScreen.kt:1390-1485`  |  —  | 未接 |  本地无此手势  |  长按「加入书架」弹出分组多选  |  见 [已知问题](../KNOWN-ISSUES.md#本地书籍行登记bookshelfmd-的-localbook-未接行) KI-LB4 ；**要接**：需先有非书架来源的详情页入口（搜索/导入页），随导入与搜索批次 |  localBook / bookGroup  |
| 动作卡·查看目录 | `BookInfoScreen.kt:1390-1485` | `pages/BookInfoPage.ets:195` | 已接 | — | 点后打开目录页并定位当前章 | — | — |
|  动作卡·换源  |  `BookInfoScreen.kt:1390-1485`、`BookInfoViewModel.kt:1197`  |  `pages/BookInfoPage.ets:194`  | 未接 |  本地 `onUnavailableAction('在线换源将在 P5 接入')`  |  点换源后可从其它书源打开同书  |  依赖书源体系；见 [已知问题](../KNOWN-ISSUES.md#本地书籍行登记bookshelfmd-的-localbook-未接行) KI-LB4 ；**要接**：依赖在线书源（登录、变量、换源、回调、简介标记）；书源已纳入范围未排期，随该模块做 |  localBook / bookSource  |
| 动作卡·阅读记录入口 | `BookInfoScreen.kt:1390-1485` | `pages/BookInfoPage.ets:254` | 已接 | 本地入口在，但点开跳**全局**阅读记录页 | 点后打开阅读记录 | 面板本身见下一行 | readRecord |
| 详情页内嵌本书阅读记录面板 | `BookInfoReadRecordSheet.kt:41-116` | — | 已接 | 上游是本书专属的 `GlassCard` 总时长 + 按天分组时间线面板；本地直接跳全局页，看不到本书聚合 | 点阅读记录弹出面板，顶部显示本书总时长，下面按天列出会话 | 本地 `Index.ets:3709`、`:3755` 走 `ProfileRoute.READ_RECORDS` | readRecord |
| 摘要·当前章 | `BookInfoScreen.kt:1533-1625` | `pages/BookInfoPage.ets:199-200` | 已接 | 本地为「在读 · 章名」，未开始显示「尚未开始阅读」 | 读第 3 章后显示该章名 | — | localBook |
| 摘要·最新章节 | `BookInfoScreen.kt:1533-1625` | `pages/BookInfoPage.ets:201-202` | 已接 | — | 显示最后一章章名 | — | localBook |
| 摘要·总章数 | `BookInfoScreen.kt:1533-1625` | `pages/BookInfoPage.ets:204-205` | 已接 | 目录未读到时显示「章节总数待读取」 | 目录加载后显示「共 128 章」 | — | localBook |
|  摘要·已读状态三分支  |  `BookInfoScreen.kt:1533-1625`  |  `pages/BookInfoPage.ets:207-208`  | 未接 |  本地只有「已读 N 章 / 未读」两分支，缺上游「已读完」第三分支  |  读到最后一章后显示「已读完」而非「已读 128 章」  |  上游判定 `durChapterIndex + 1 == totalChapterNum`；见 [已知问题](../KNOWN-ISSUES.md#本地书籍行登记bookshelfmd-的-localbook-未接行) KI-LB4 ；**要接**：摘要三分支与目录失败提示是纯本地计算；备注卡片加 onClick 进元数据面板 |  localBook  |
|  摘要·目录加载失败提示  |  `BookInfoScreen.kt:1533-1625`  |  —  | 未接 |  本地无 `error_load_toc` 等价提示  |  目录加载失败时摘要区出现「目录加载失败」  |  见 [已知问题](../KNOWN-ISSUES.md#本地书籍行登记bookshelfmd-的-localbook-未接行) KI-LB4 ；**要接**：摘要三分支与目录失败提示是纯本地计算；备注卡片加 onClick 进元数据面板 |  localBook  |
|  摘要·备注卡片可点编辑  |  `BookInfoScreen.kt:1533-1625`  |  `pages/BookInfoPage.ets:245-250`  | 未接 |  本地备注只读，编辑需进元数据面板  |  点备注卡片直接进入备注编辑  |  见 [已知问题](../KNOWN-ISSUES.md#本地书籍行登记bookshelfmd-的-localbook-未接行) KI-LB4 ；**要接**：摘要三分支与目录失败提示是纯本地计算；备注卡片加 onClick 进元数据面板 |  localBook  |
| 简介·纯文本 | `BookInfoScreen.kt:1634-1710` | `pages/BookInfoPage.ets:235-244` | 已接 | 本地只做纯文本渲染 | 简介正常显示且长文可滚动 | — | localBook |
|  简介·HTML 渲染  |  `BookInfoScreen.kt:1634-1710`  |  —  | 未接 |  本地无 `<usehtml>` 分支  |  简介含 HTML 时按富文本渲染  |  — ；**要接**：简介标记需解析 usehtml/useweb/md 三种；usehtml 用 RichText，useweb 需 Web 组件。内嵌 js 见 :346 另判 |  bookSource  |
|  简介·Web 渲染  |  `BookInfoScreen.kt:1753`、`:1842-2040`  |  —  | 未接 |  本地无 `<useweb>` 分支与 WebView 桥  |  简介含 `<useweb>` 时用 WebView 渲染并支持跳转  |  依赖 ArkWeb ；**要接**：简介标记需解析 usehtml/useweb/md 三种；usehtml 用 RichText，useweb 需 Web 组件。内嵌 js 见 :346 另判 |  bookSource  |
|  简介·Markdown 渲染  |  `BookInfoScreen.kt:1634-1710`  |  —  | 未接 |  本地无 `<md>` 分支  |  简介含 Markdown 时按样式渲染  |  — ；**要接**：简介标记需解析 usehtml/useweb/md 三种；usehtml 用 RichText，useweb 需 Web 组件。内嵌 js 见 :346 另判 |  bookSource  |
|  角色卡  |  `BookInfoScreen.kt:2170`、`:2240`  |  —  | 未接 |  本地无角色体系  |  简介下方出现角色列表  |  — ；**不接**：角色卡靠书籍内容分析生成，生成侧属范围外的 AI 服务；本地无角色实体与消费方 |  bookSource  |
|  角色关系网  |  `BookInfoScreen.kt:2240`  |  —  | 未接 |  同上  |  角色之间显示关系连线  |  — ；**不接**：同 :320，依赖角色卡与 AI 生成的关系抽取 |  bookSource  |
|  知识卡  |  `BookInfoScreen.kt:2324`、`:2373`  |  —  | 未接 |  本地无知识条目体系  |  显示知识条目卡片  |  — ；**不接**：知识卡依赖 AI 生成，本地无实体、无生成链路 |  bookSource  |
|  事件卡  |  `BookInfoScreen.kt:2401`、`:2453`  |  —  | 未接 |  本地无事件体系  |  显示剧情事件时间线  |  — ；**不接**：事件卡同 :322 |  bookSource  |
|  相关书籍横幅  |  `BookInfoScreen.kt:2124`  |  —  | 未接 |  本地无相关书籍推荐  |  详情页底部出现相关书籍横排  |  — ；**要接**：依赖在线书源（登录、变量、换源、回调、简介标记）；书源已纳入范围未排期，随该模块做 |  bookSource  |
|  私密锁定内容页  |  `BookInfoScreen.kt:664`  |  —  | 未接 |  本地无锁定态  |  私密书详情页默认显示锁定内容  |  见 [已知问题](../KNOWN-ISSUES.md#本地书籍行登记bookshelfmd-的-localbook-未接行) KI-LB4 ；**要接**：私密体系：books 表需加 isPrivate 列，详情页加设为私密与锁定内容页 |  localBook  |
| 编辑·书名 | `edit/BookInfoEditScreen.kt:238` | `pages/BookInfoPage.ets:339-341` | 已接 | — | 改名保存后书架同步 | — | localBook |
| 编辑·作者 | `edit/BookInfoEditScreen.kt:246` | `pages/BookInfoPage.ets:342-345` | 已接 | — | 改作者保存后详情页同步 | — | localBook |
| 编辑·分类 | `edit/BookInfoEditScreen.kt:262` | `pages/BookInfoPage.ets:346-349` | 已接 | — | 改分类保存后持久化 | — | localBook |
| 编辑·封面 | `edit/BookInfoEditScreen.kt:254`、`:197-207` | `pages/BookInfoPage.ets:296-310` | 已接 | 本地为选本地图片，非填封面 URL | 选图后封面更新，还原后恢复 | 方式不同 | localBook |
| 编辑·简介 | `edit/BookInfoEditScreen.kt:278` | `pages/BookInfoPage.ets:354-357` | 已接 | — | 改简介保存后详情页同步 | — | localBook |
| 编辑·备注 | `edit/BookInfoEditScreen.kt:286` | `pages/BookInfoPage.ets:358-361` | 已接 | — | 加备注保存后详情页显示 | — | localBook |
|  编辑·标签编辑器  |  `edit/BookInfoEditScreen.kt:435-517`  |  `pages/BookInfoPage.ets:350-353`  | 未接 |  本地是逗号分隔单行输入，无增删改标签的编辑器  |  可逐个添加、编辑、删除标签  |  上游有 `add_tag`/`edit_tag`/`reset`；见 [已知问题](../KNOWN-ISSUES.md#本地书籍行登记bookshelfmd-的-localbook-未接行) KI-LB5 ；**要接**：编辑面板与删除面板：标签编辑器改为增删改列表；删除面板补同名副本与删源文件勾选；分组多选独立成面板 |  localBook  |
| 编辑·书籍类型 | `edit/BookInfoEditScreen.kt:213-215` | `pages/BookInfoPage.ets:314-318` | 已接 | 本地三选：文本/音频/图片 | 切换类型后卡片角标随之改变 | — | localBook |
| 编辑·固定书籍类型 | `edit/BookInfoEditScreen.kt:231` | `pages/BookInfoPage.ets:319-323` | 已接 | — | 开启后刷新信息不再改类型 | — | localBook |
|  编辑·知识卡编辑  |  `edit/BookInfoEditScreen.kt:310-343`  |  —  | 未接 |  本地编辑面板无角色/知识/事件  |  可在编辑面板增删角色与事件  |  见 [已知问题](../KNOWN-ISSUES.md#本地书籍行登记bookshelfmd-的-localbook-未接行) KI-LB5 ；**不接**：知识卡编辑面板依赖知识卡实体，随 :322 一并搁置 |  localBook  |
| 编辑·空名校验 | `edit/BookInfoEditScreen.kt:245-250` | `pages/BookInfoPage.ets:113-115` | 已接 | 本地空名时提示并阻止保存 | 清空书名点保存被拒绝并提示 | — | localBook |
|  书架删除面板  |  `ShelfDeleteSheet.kt`（182 行）  |  `pages/BookInfoPage.ets:85`  | 未接 |  本地只弹系统确认框，无「同时删除文件」等选项  |  移出时可选是否删除本地文件与阅读记录  |  见 [已知问题](../KNOWN-ISSUES.md#本地书籍行登记bookshelfmd-的-localbook-未接行) KI-LB5 ；**要接**：编辑面板与删除面板：标签编辑器改为增删改列表；删除面板补同名副本与删源文件勾选；分组多选独立成面板 |  localBook  |
|  书架删除面板·同名副本切换  |  `ShelfDeleteSheet.kt:102-128`  |  —  | 未接 |  本地无同名副本概念  |  面板列出同名同作者的其他副本，可点开查看  |  `shelf_delete_view_copy`；见 [已知问题](../KNOWN-ISSUES.md#本地书籍行登记bookshelfmd-的-localbook-未接行) KI-LB5 ；**要接**：编辑面板与删除面板：标签编辑器改为增删改列表；删除面板补同名副本与删源文件勾选；分组多选独立成面板 |  localBook  |
|  书架删除面板·删除源文件勾选  |  `ShelfDeleteSheet.kt:167-168`  |  —  | 未接 |  本地无此勾选  |  勾选后移出同时删除本地文件  |  `delete_book_file`；见 [已知问题](../KNOWN-ISSUES.md#本地书籍行登记bookshelfmd-的-localbook-未接行) KI-LB5 ；**要接**：编辑面板与删除面板：标签编辑器改为增删改列表；删除面板补同名副本与删源文件勾选；分组多选独立成面板 |  localBook  |
|  面板·分组多选  |  `BookInfoSheets.kt:109`  |  `pages/BookInfoPage.ets:324-338`  | 未接 |  上游为独立面板（标题 + 新建分组 + 逐行编辑 + 位掩码选择）；本地把多选塞在元数据编辑面板内  |  点分组标签弹出多选面板，可在面板内新建分组  |  `GroupSelectSheet`，`groupId` 位掩码；见 [已知问题](../KNOWN-ISSUES.md#本地书籍行登记bookshelfmd-的-localbook-未接行) KI-LB5 ；**要接**：编辑面板与删除面板：标签编辑器改为增删改列表；删除面板补同名副本与删源文件勾选；分组多选独立成面板 |  localBook / bookGroup  |
|  面板·在线换封面  |  `BookInfoSheets.kt:194`  |  —  | 未接 |  本地只能从相册选图或还原，无在线搜封面  |  点换封面后按书源搜索封面，三列网格可选  |  `ChangeCoverSheet`，带搜索/停止切换；见 [已知问题](../KNOWN-ISSUES.md#本地书籍行登记bookshelfmd-的-localbook-未接行) KI-LB5 ；**要接**：在线换封面用输入 URL + rcp 取图；网络文件与压缩包条目选择需 ZIP 解析与网络读取 |  localBook  |
|  面板·网络文件选择  |  `BookInfoSheets.kt:70`  |  —  | 未接 |  本地无网络文件导入  |  导入网文链接时列出可选文件，压缩包显示文件夹图标  |  `WebFileSheet`；见 [已知问题](../KNOWN-ISSUES.md#本地书籍行登记bookshelfmd-的-localbook-未接行) KI-LB5 ；**要接**：在线换封面用输入 URL + rcp 取图；网络文件与压缩包条目选择需 ZIP 解析与网络读取 |  localBook  |
|  面板·压缩包条目选择  |  `BookInfoContract.kt` `ArchiveEntries`  |  —  | 未接 |  本地无压缩包导入  |  选 zip 后列出内部条目可选其一  |  见 [已知问题](../KNOWN-ISSUES.md#本地书籍行登记bookshelfmd-的-localbook-未接行) KI-LB5 ；**要接**：在线换封面用输入 URL + rcp 取图；网络文件与压缩包条目选择需 ZIP 解析与网络读取 |  localBook  |
|  面板·不支持文件提示  |  `BookInfoContract.kt` `UnsupportedWebFile`  |  —  | 未接 |  本地无  |  选中不支持的格式时弹提示  |  `file_not_supported`；见 [已知问题](../KNOWN-ISSUES.md#本地书籍行登记bookshelfmd-的-localbook-未接行) KI-LB5 ；**要接**：在线换封面用输入 URL + rcp 取图；网络文件与压缩包条目选择需 ZIP 解析与网络读取 |  localBook  |
|  书源回调按钮  |  `BookInfoViewModel.kt:265-311`  |  —  | 未接 |  本地无书源回调体系  |  书源定义的按钮出现在详情页，点后按类型搜索/分享/复制/清缓存  |  `BookInfoCallbackAction` 四值 ；**要接**：依赖在线书源（登录、变量、换源、回调、简介标记）；书源已纳入范围未排期，随该模块做 |  bookSource  |
|  简介 JS 执行  |  `BookInfoViewModel.kt:318-335`  |  —  | 不适用 |  本地无简介脚本 。**判不适用（r340）**：上游在简介里跑 JS；鸿蒙无内置脚本引擎，引入第三方引擎超出零依赖与安全边界（备份里的脚本按不可信数据处理，见 docs/PROJECT.md:33），属「平台无此能力」一类证据 | — |  注入 `result`/`java`/`book`  |  bookSource  |
|  简介内按钮点击  |  `BookInfoContract.kt` `IntroButtonClick`  |  —  | 未接 |  本地无 `<button>` 解析  |  简介含按钮时点击触发脚本  |  格式 `<button>名@onclick:脚本</button>` ；**要接**：依赖在线书源（登录、变量、换源、回调、简介标记）；书源已纳入范围未排期，随该模块做 |  bookSource  |
|  简介图片点击与长按  |  `BookInfoContract.kt` `IntroImageClick`/`IntroImageLongClick`  |  —  | 未接 |  本地无简介图片交互  |  点简介图片执行脚本，长按走另一分支  |  — ；**要接**：依赖在线书源（登录、变量、换源、回调、简介标记）；书源已纳入范围未排期，随该模块做 |  bookSource  |
|  作者其他作品  |  `BookInfoViewModel.kt:2069`  |  —  | 未接 |  本地无  |  点作者后列出该作者其他书  |  `book_other_works` ；**要接**：依赖在线书源（登录、变量、换源、回调、简介标记）；书源已纳入范围未排期，随该模块做 |  bookSource  |
|  目录选择（book tree uri）  |  `BookInfoScreen.kt:243`  |  —  | 未接 |  本地无 SAF 目录授权  |  选目录后可作为书籍根目录  |  `SetDefaultBookTreeUri`；见 [已知问题](../KNOWN-ISSUES.md#本地书籍行登记bookshelfmd-的-localbook-未接行) KI-LB5 ；**要接**：Android 的 SAF 目录授权在鸿蒙无对应；用 picker 的目录选择覆盖「选一个目录作为来源」 |  localBook  |

---

## C 阅读进度与记录

上游主体：`ui/book/readRecord/ReadRecordScreen.kt`（1663 行）、`ReadRecordViewModel.kt`（385 行）、`ReadRecordCharts.kt`（181 行）、`ReadRecordStats.kt`（109 行）、`ReadRecordOverviewScreen.kt`（547 行）。
本地主体：`pages/ProfileSubPages.ets:3013`–`:3490`（`ReadRecordsPage`，r334 复核：旧记的 `:2907` 是书签页的 `ForEach`，已漂移）、`data/ReadRecordRepository.ets`（1333 行）、`model/ReadRecord.ets`（104 行）。

| 上游能力 | 上游位置 | 本地位置 | 状态 | 差异说明 | 验收方式 | 备注 | ZIP 类别 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 阅读进度写入 | `Book.kt:45-138` | `model/Book.ets:17-18`、`:57-58` | 已接 | 本地 `chapterIndex`（落 `durChapterIndex`）`chapterProgress`（落 `durChapterPos`）`durChapterTime`；进度百分比不落库，由 `BookRepository.readProgress` 现算（`data/BookRepository.ets:242`） | 读 3 章后退出，书架排序按最后阅读更新 | r284 起 `progress` 改为派生（上游 Book 表无此列） | localBook / readRecord |
| 进度恢复（打开即定位） | `ReadBookConfig.kt` | `pages/ReaderPage.ets` | 已接 | — | 关掉 App 重开，点该书回到上次章节与位置 | — | localBook |
| 章节内位置记忆 | `Book.kt:45-138` | `model/Book.ets:18` | 已接 | 本地 `chapterProgress` 是章内百分比，直接落在上游 `durChapterPos` 列上（`data/BookRepository.ets:689-690`） | 在同一章内滚动后退出再进，停在原位 | r284 起 `readerPositionVersion` 已删除（上游无此列）；`androidCharacterPosition` 仍保留在 `model/Book.ets:52`，被 26 处代码读写（导出侧 `toAndroidBookRecord` 取它落 `durChapterPos`），迁移时按章内字符位置换算百分比 | localBook |
| 阅读记录开关 | `ReadRecordScreen.kt:703` | `pages/ProfileSubPages.ets:3450`（`toggleRecordEnabled`）+ `:3850`-`:3855`（动作单开关项） | 已接 | — | 关掉后读书不再产生记录 | — | 不备份 |
| 阅读记录三视图切换 | `ReadRecordScreen.kt:939` | `pages/ProfileSubPages.ets:3078`（`cycleDisplayMode`）+ `:3543`-`:3544`（图标按钮） | 已接 | 本地 `cycleDisplayMode()` 轮换 0 汇总/1 时间线/2 最后阅读 | 点视图图标在三种视图间轮换 | 上游为图标按钮组 | — |
| 阅读记录搜索 | `ReadRecordScreen.kt` | `pages/ProfileSubPages.ets:3082`（`getVisibleRecords`）+ `:3560`-`:3570`（`showSearch` 搜索框） | 已接 | 本地按书名与作者过滤 | 输入书名后列表只剩该书记录 | — | — |
| 汇总视图 | `ReadRecordScreen.kt:813` | `pages/ProfileSubPages.ets:3600` 起（`displayMode === 0` 分支） | 已接 | 本地按日期分组、按书聚合时长 | 汇总视图按日期显示各书阅读时长 | — | readRecord |
| 时间线视图 | `ReadRecordScreen.kt:939`、`:1254` | `pages/ProfileSubPages.ets:3631` 起（`displayMode === 1` 分支） | 已接 | — | 时间线按会话列出开始时间与时长 | — | readRecord |
| 最后阅读视图 | `ReadRecordScreen.kt:1143` | `pages/ProfileSubPages.ets:3658` 起（`displayMode` 其余分支的 `} else {`） | 已接 | — | 列表按最后阅读时间倒序 | — | readRecord |
| 阅读总成就 | `ReadRecordScreen.kt` | `pages/ProfileSubPages.ets:3234`（`getSummaryDuration`）+ `:3591`（汇总卡「阅读总成就」） | 已接 | 本地显示本书数与总时长 | 顶部卡片显示「N 本书 · X 小时」 | — | readRecord |
| 热力图日历 | `ReadRecordScreen.kt:860` | `pages/ProfileSubPages.ets:3811`-`:3812`（`ReadRecordCalendarSheet`）、`:3826`（挂 `ReadRecordHeatmap`）；组件 `components/ReadRecordHeatmap.ets:9`（210 行，`@Prop mode` `:17`） | 已接 | 年度按周网格热力格子，点成就卡（`:3599`）打开该 sheet | 显示近一年的阅读热力格子 | `HeatmapCalendarSection` | readRecord |
| 阅读时长柱状图 | `ReadRecordCharts.kt:40` | `pages/ReadRecordOverviewPage.ets:44`（`ReadTimeBarChartCard`）、`:478`（挂载） | 已接 | 总览页内，周期为「总」时整卡不渲染 | 显示近 7 天阅读时长柱状图 | — | readRecord |
| 统计格子 | `ReadRecordStats.kt:35`、`:79` | `pages/ReadRecordOverviewPage.ets:133`（`StatsGridCard`）、`:481`（挂载） | 已接 | 五项：阅读时长 / 阅读天数 / 总本数 / 读完 / 在读 | 显示日均时长、最长单次等指标 | — | readRecord |
| 扫描问题 | `ReadRecordScreen.kt:703` | `pages/ProfileSubPages.ets:3460`（`runScanIssues`）+ `:3857`（菜单项） | 已接 | 本地扫描只读，不改数据 | 点扫描后列出异常记录条数 | — | readRecord |
| 修复记录 | `ReadRecordScreen.kt:703` | `pages/ProfileSubPages.ets:3472`（`runRepair`）+ `:3859`（菜单项） | 已接 | 本地 `ReadRecordRepository.repair` | 点修复后异常记录数归零 | — | readRecord |
| 清空阅读记录 | `ReadRecordScreen.kt:703` | `pages/ProfileSubPages.ets:3484`（`requestClearAll`）/`:3496`（`confirmClearAll`）+ `:3861`（菜单项） | 已接 | — | 点清空并确认后记录数归零 | — | readRecord |
| 清空二次确认 | `ReadRecordScreen.kt` `confirm_delete_read_record` | `pages/ProfileSubPages.ets:3484`（`requestClearAll`）/`:3496`（`confirmClearAll`）+ `:3861` | 已接 | 本地单条确认文案 | 点清空弹确认框，取消则不删 | — | — |
| 「不再提醒」两档 | `ReadRecordScreen.kt` `do_not_remind_again_this_page`/`_long_term` | `pages/ProfileSubPages.ets:3049`（`skipDeleteConfirmForPage`，本页档）/`:3051`（`skipDeleteConfirm`，长期档）、`:3780`（`ReadRecordDeleteConfirmSheet`，两个 `Toggle` 在 `:3791`/`:3796`）、`:3302`（已勾则跳过确认）、`:3314`-`:3318`（应用两档）；仓储 `data/ReadRecordRepository.ets:805`（`loadSkipDeleteConfirm`）/`:815`（`setSkipDeleteConfirm`） | 已接 | 长期档写 preferences 键 `readRecordSkipDeleteConfirm` 并跨启动保持；动作单 `:3863`-`:3864`「恢复删除确认」可清掉两档 | 勾选「本页不再提醒」后下次不再弹 | 上游分本次与本机两档 | 不备份 |
| 合并同名书籍 | `ReadRecordScreen.kt` `merge_read_records` | `data/ReadRecordRepository.ets:828`（`loadMergeCandidates`）、`:838`（`mergeReadRecords`）；`pages/ProfileSubPages.ets:3368`（`openMergeSheetForRecord`）、`:3406`（`confirmMerge`）、`:3735`（`ReadRecordMergeSheet`） | 已接 | 无候选时面板提示「没有可合并的候选」（`:3745`） | 把「同名不同作者」的两组记录合并 | — | readRecord |
| 合并候选搜索 | `ReadRecordScreen.kt` `search_placeholder` | `pages/ProfileSubPages.ets:3388`（`mergeCandidateKey`）、`:3392`（`getFilteredMergeCandidates`） | 已接 | 按书名或作者 `includes` 过滤 | 合并时可搜索候选并提示无候选 | — | readRecord |
| 未知作者记录归属检查 | `ReadRecordAliasDelegate.kt:29-54` `check(book)` | `pages/Index.ets:5946`（`checkReadRecordAlias`）、`:5995`（`openBook` 开头调用）、`:5982`（`askReadRecordAlias` 弹窗「合并还是保留」）；仓储 `data/ReadRecordRepository.ets:862`（`loadUnknownAuthorRecords`）、`:869`（`aliasKey`） | 已接 | 打开书籍时若存在「同名 + 作者为空」的旧记录，弹窗询问合并还是保留；同名多副本（`shelfCopies > 1`）时强制重新确认 | 库里留一条作者为空的记录，再打开同名同作者的书，应弹冲突框 | 依赖 `getUnknownAuthorRecords` 与 `ReadRecordIdentity.author` | readRecord |
| 归属决定持久化 | `ReadRecordAliasDelegate.kt:56-85`、`LocalPreferencesKeys.READ_RECORD_ALIAS_DECISIONS` | `data/ReadRecordRepository.ets:894`（`saveAliasDecision`）、`:884`（`loadAliasDecision`）、`:44`（`aliasDecisionsKey = 'readRecordAliasDecisions'`）；调用 `pages/Index.ets:5953`（读）/`:5969`（写） | 已接 | 决定按 `aliasKey(书名, 作者)` 一行一条存进 preferences，`MERGE`/`KEEP` 两种取值 | 勾「记住选择」后再打开同书，不再弹框而是按记忆执行 | 上游存 preferences，一行一条 `key + MERGE/KEEP` | 不备份 |
| 清除归属决定 | `ReadRecordAliasDelegate.kt:87-94`、`ReadBookContract.kt:648-649` `ClearReadRecordAliasDecisions` | `pages/ProfileSubPages.ets:3420`（`clearAliasDecisions`）、`:3867`-`:3868`（动作单「清除归属决定」）；仓储 `data/ReadRecordRepository.ets:906` | 已接 | 清空整份 `readRecordAliasDecisions` 后提示「已清除归属决定」 | 点「清除已记住的决定」后再打开同书，重新弹框 | 同书多副本时上游强制重新确认（`countShelfCopies > 1`） | 不备份 |
| 选择模式批量删除 | `ReadRecordScreen.kt` `selected_count`/`delete_selected` | `pages/ProfileSubPages.ets:3045`（`selectedKeys`）、`:3272`（`isInSelectionMode`）、`:3300`（`requestDeleteSelected`）、`:3312`（`confirmDeleteSelected`）、`:3539`（顶栏删除按钮） | 已接 | 长按进选择模式，顶栏显示「N 项已选」 | 选中 3 条记录删除后只剩其余 | — | readRecord |
| 单条记录删除 | `ReadRecordScreen.kt` `del_read_record` | 与上行共用 `ReadRecordDeleteConfirmSheet`（`pages/ProfileSubPages.ets:3780`），文案按 `selectedKeys.size` 切单条/多条 | 已接 | 与批量删除同一套确认面板 | 长按单条记录可删除 | — | readRecord |
| 阅读记录总览页 | `ReadRecordOverviewScreen.kt`（547 行） | `pages/ReadRecordOverviewPage.ets:335`（519 行）；`pages/Index.ets:20`（import）、`:7673`（挂载）；入口 `pages/ProfileSubPages.ets:3869`-`:3870` | 已接 | 周期选择日/周/月/年/总 + 日期导航 | 打开总览页看到跨书统计与趋势 | 下列五条是总览页内的分区 | readRecord |
| 总览·统计格 | `ReadRecordOverviewScreen.kt:167-178` | `pages/ReadRecordOverviewPage.ets:133`（`StatsGridCard`）、`:481`（挂载） | 已接 | 五项齐 | 显示阅读时长、阅读天数、总本数、读完、在读五项 | `StatsGridCard` | readRecord |
| 总览·跨书热力图 | `ReadRecordOverviewScreen.kt:300-310` | `pages/ReadRecordOverviewPage.ets:492`（`ReadRecordHeatmap`，`mode: 1`） | 已接 | 跨书合并热力图；总览页里不可点（空回调） | 显示全部书籍合并的年度热力图 | `HeatmapMode.TIME` | readRecord |
| 总览·阅读时长排行 | `ReadRecordOverviewScreen.kt:338` | `pages/ReadRecordOverviewPage.ets:502`（`TopReadingListCard`） | 已接 | — | 按阅读时长倒序列出 Top 书单，带封面 | `reading_time_ranking` | readRecord |
| 总览·阅读日历（月历） | `ReadRecordOverviewScreen.kt:450` | `pages/ReadRecordOverviewPage.ets:508`（`ReadingCalendarCard`） | 已接 | — | 显示当月日历，有阅读的日期高亮 | 可切换上/下月 | readRecord |
| 总览·日历日详情 | `ReadRecordOverviewScreen.kt:510-516` | — | 不适用 | — | 上游 `CalendarDayCell`（`ReadRecordOverviewScreen.kt:495-545`）无 onClick，`:510-516` 只是读屏 `contentDescription`，点日不触发任何动作 | `a11y_reading_calendar_day_with_book` | readRecord |
| 最短有效时长阈值 | `GetReadRecordOverviewUseCase.kt` | `data/ReadRecordRepository.ets` | 已接 | 本地 `minimumReadDurationMs = 10000` | 停留 5 秒退出不产生记录，15 秒产生 | — | 不备份 |
| 自动保存间隔 | `ReadRecordViewModel.kt` | `data/ReadRecordRepository.ets` | 已接 | 本地 `autoSaveIntervalMs = 120000` | 连续阅读 2 分钟后记录落盘 | — | 不备份 |
|  章节索引格式化  |  `ReadRecordScreen.kt` `chapter_index_format`  |  `pages/BookInfoPage.ets:493`-`:494`（详情页阅读记录面板）；字段 `model/ReadRecord.ets:89`，生成处 `pages/Index.ets:744`  | 未接 |  书籍详情页的阅读记录面板有「第 N 章」（`chapterLabel`），阅读记录列表三视图没有（`ReadTimeRecord` 无章名字段）  |  记录条目显示「第 12 章」而非裸数字  |  — ；**要接**：ReadTimeRecord 补章名字段，pages/Index.ets:744 生成处已有 chapterLabel，只差透传 |  —  |
| 详情页进度条 | `BookInfoScreen.kt:1533-1625` | `pages/BookInfoPage.ets:281`（文案）、`:293`（进度条 Row） | 已接 | 本地按 `BookRepository.readProgress(book)` 的百分比渲染（派生值，不落库） | 读到 50% 时进度条半满 | r284 起 `progress` 不再是存储字段 | localBook / readRecord |
| 备份写出·三份 readRecord JSON | `help/storage/Backup.kt:77-79` | `data/BackupRepository.ets:805`、`:807`、`:818`（三份 `writeTextFile`，门控 `:803`） | 已接 | 导出 ZIP 写入 `readRecord.json` / `readRecordDetail.json` / `readRecordSession.json`；会话字段 `chapterIndex` 写成上游列名 `words` | 备份后从该 ZIP 走恢复预览，能列出三份文件与各自条数 | 本轮补登；源码段 `exportForBackup` | readRecord |
| 备份恢复·三份 readRecord JSON 写库 | `help/storage/Restore.kt:283-299` | `data/BackupRepository.ets:1449`（具名分支；内层 `:1457`/`:1459`）、`:1488`（`restoreFromBackup` 调用）、`data/ReadRecordRepository.ets:1069`（定义） | 已接 | 三份 JSON 走具名分支解析后交 `restoreFromBackup` 写库，按会话重算派生层；不再落到只拷文件不进库的兜底分支 | 点「导入此 ZIP」后三表行数与恢复前一致、不重复插入 | 本轮补登；派生层重算口径见上游 `reconcileRestoredReadRecordTotals` | readRecord |
| 连续会话合并接进时间线 | `ui/book/readRecord/ReadRecordViewModel.kt:294` | `data/ReadRecordRepository.ets`、`pages/ProfileSubPages.ets` | 已接 | `mergeContinuousSessions` 按 20*60*1000 毫秒间隔合并同书相邻会话；时间线 `getRecordsForDate` 先合并再按开始时间倒序 | 时间线视图里相邻短会话按合并整段时长列出 | 本轮补登；F9 纯函数落在批 0 | readRecord |
| 友好日期接进三视图 | `utils/StringUtils.kt:109` | `data/ReadRecordRepository.ets`、`pages/ProfileSubPages.ets`、`pages/Index.ets` | 已接 | `formatFriendlyDate` 今天 / 昨天 / 2..5 天前 / 否则原日期串，接进汇总、时间线、最后阅读三处日期头与详情页面板 | 汇总视图日期头显示「今天」「昨天」「2天前」 | 本轮补登；F10 落在批 0 | readRecord |

---

## D 缓存管理页（整界面）

本块按 [盘点规约](../PARITY-RULES.md) 第二节「盘点单位是界面，不是按钮」新增。此前本表只有一行「更多菜单·书架管理 → 未接」（现 `:76`），把整个页面当成了一个按钮；实际它是两个不同的页面，各有完整界面。

**上游是两个页面，不是一个**：
- **书架管理页**：`ui/book/manage/BookshelfManageScreen.kt`（**1777 行**）+ `BookshelfManageScreenViewModel.kt`（**1136 行**），导航键 `MainRouteCache(val groupId: Long)`（`ui/main/MainNavKey.kt:145`），入口是书架页更多菜单「书架管理」（`ui/main/bookshelf/BookshelfScreen.kt:747-754`）。
- **缓存管理页**：`ui/book/cache/manage/BookCacheManageScreen.kt`（**685 行**）+ `BookCacheManageViewModel.kt`（**892 行**），导航键 `MainRouteBookCacheManage`（`ui/main/MainNavKey.kt:148`），入口是「我的」页「缓存管理」（`ui/main/my/MyScreen.kt:221-226` → `PrefClickEvent.OpenBookCacheManage` → `ui/main/MainScreen.kt:652`）。

**本地现状**：只有一个页面 `pages/ProfileSubPages.ets:3383 CacheManagementPage`（通「我的」页 `pages/ProfilePage.ets:81` 进入，路由 `model/Book.ets:151 ProfileRoute.CACHE_MANAGEMENT`），形态与**上游缓存管理页**对得上，但正文是空态占位；**书架管理页本地完全不存在**（`pages/BookshelfPage.ets:594-595` 的菜单项直接 `onUnavailableAction('书架管理尚未迁移')`）。另有一个 `pages/AppDownloadCacheSettingsPage.ets`（162 行）是**设置页**，不是这两个页面中的任何一个。

### D1 缓存管理页 · 框架（`BookCacheManageScreen.kt`）

| 上游能力 | 上游位置 | 本地位置 | 状态 | 差异说明 | 验收方式 | 备注 | ZIP 类别 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 顶栏标题「缓存管理」 | `BookCacheManageScreen.kt:158` | `pages/ProfileSubPages.ets:3428` | 已接 | 本地大标题样式，无折叠 | 进入页面看到标题 | — | — |
| 搜索开关 | `BookCacheManageScreen.kt:162` | `pages/ProfileSubPages.ets:3413-3417` | 已接 | 本地内联展开输入框 | 点搜索图标出现输入框 | — | — |
|  搜索过滤书名/作者  |  `BookCacheManageScreen.kt:118-126`  |  `pages/ProfileSubPages.ets:3434`  | 未接 |  输入框绑了 `searchQuery` 但**没有任何过滤逻辑**，`@State searchQuery` 只在 `onChange` 里写自己  |  输入书名后列表只剩该书  |  本地过滤函数缺失 ；**要接**：补过滤逻辑（书名/作者/分组），searchQuery 状态已有 |  —  |
| 分组筛选菜单 | `BookCacheManageScreen.kt:171-186` | `pages/ProfileSubPages.ets:3407-3412`、`:3490-3508` | 已接 | 本地 `CacheGroupMenu` 列出「全部/无分组 + 各分组」 | 点筛选图标弹出分组列表，选中项打勾 | — | — |
|  分组过滤生效  |  `BookCacheManageScreen.kt:118-127`  |  —  | 未接 |  本地 `selectedCacheGroup` 只影响「未在书架」区的显隐（`:3452`），不影响书籍列表（因为列表是空态）  |  选某分组后列表只剩该分组书  |  — ；**要接**：补过滤逻辑（书名/作者/分组），searchQuery 状态已有 |  —  |
|  刷新按钮  |  `BookCacheManageScreen.kt:160`  |  `pages/ProfileSubPages.ets:3421-3423`  | 未接 |  本地 `onUnavailableAction('缓存数据仓储尚未接入，未刷新缓存')`  |  点刷新后缓存统计重算  |  — ；**要接**：缓存管理页主体需磁盘章节缓存；现有 chapterCache 是内存 Map（data/BookRepository.ets:140），先落磁盘缓存表再给卡片与章节行 |  —  |
| 两个分区（书架内 / 未在书架） | `BookCacheManageScreen.kt:343-346`、`:355-358` | `pages/ProfileSubPages.ets:3449-3458` | 已接 | 两个 `CacheEmptySection` 分区结构在（**仅空态**），只画空态文案；正文列表整体未接 | 有缓存时两区各自列出书籍 | 正文列表整体未接 | — |

### D2 缓存管理页 · 书籍卡片与章节（`BookCacheManageScreen.kt`）

| 上游能力 | 上游位置 | 本地位置 | 状态 | 差异说明 | 验收方式 | 备注 | ZIP 类别 |
| --- | --- | --- | --- | --- | --- | --- | --- |
|  书籍缓存卡片  |  `BookCacheManageScreen.kt:392-530` `BookCacheBookCard`  |  —  | 未接 |  本地无卡片  |  列出每本书的封面、书名、缓存进度  |  — ；**要接**：缓存管理页主体需磁盘章节缓存；现有 chapterCache 是内存 Map（data/BookRepository.ets:140），先落磁盘缓存表再给卡片与章节行 |  —  |
|  卡片缓存进度文字 `n/total`  |  `BookCacheManageScreen.kt:474`  |  —  | 未接 |  同上  |  卡片显示 `12/240`  |  — ；**要接**：缓存管理页主体需磁盘章节缓存；现有 chapterCache 是内存 Map（data/BookRepository.ets:140），先落磁盘缓存表再给卡片与章节行 |  —  |
|  卡片进度条  |  `BookCacheManageScreen.kt:477-495`  |  —  | 未接 |  同上  |  进度条按 `cachedCount/totalCount` 填充  |  — ；**要接**：缓存管理页主体需磁盘章节缓存；现有 chapterCache 是内存 Map（data/BookRepository.ets:140），先落磁盘缓存表再给卡片与章节行 |  —  |
|  卡片状态摘要  |  `BookCacheManageScreen.kt:406-420` `cache_download_status_summary`  |  —  | 未接 |  同上  |  卡片显示「下载中 / 已暂停 / 等待重试」  |  — ；**要接**：缓存管理页主体需磁盘章节缓存；现有 chapterCache 是内存 Map（data/BookRepository.ets:140），先落磁盘缓存表再给卡片与章节行 |  —  |
|  卡片展开/收起箭头  |  `BookCacheManageScreen.kt:443-460`  |  —  | 未接 |  同上  |  点卡片展开章节列表  |  `a11y_collapsed`/`a11y_expanded` ；**要接**：缓存管理页主体需磁盘章节缓存；现有 chapterCache 是内存 Map（data/BookRepository.ets:140），先落磁盘缓存表再给卡片与章节行 |  —  |
|  卡片下载/停止按钮  |  `BookCacheManageScreen.kt:499-518`  |  —  | 未接 |  同上  |  点下载开始缓存全书，再点停止  |  — ；**要接**：缓存管理页主体需磁盘章节缓存；现有 chapterCache 是内存 Map（data/BookRepository.ets:140），先落磁盘缓存表再给卡片与章节行 |  —  |
|  卡片删除缓存按钮  |  `BookCacheManageScreen.kt:521-529`  |  —  | 未接 |  同上  |  点删除弹确认框，确认后缓存清零  |  — ；**要接**：缓存管理页主体需磁盘章节缓存；现有 chapterCache 是内存 Map（data/BookRepository.ets:140），先落磁盘缓存表再给卡片与章节行 |  —  |
|  章节行（下载状态）  |  `BookCacheManageScreen.kt:531-626` `BookCacheChapterRow`  |  —  | 未接 |  本地无章节级缓存视图  |  展开书籍后逐章列出状态  |  — ；**要接**：缓存管理页主体需磁盘章节缓存；现有 chapterCache 是内存 Map（data/BookRepository.ets:140），先落磁盘缓存表再给卡片与章节行 |  —  |
|  章节状态六档文字  |  `BookCacheManageScreen.kt:627-650` `chapterStatusText`  |  —  | 未接 |  上游六档：下载中/失败待重试/等待/暂停/失败/已缓存  |  不同状态的章节显示对应文字  |  — ；**要接**：缓存管理页主体需磁盘章节缓存；现有 chapterCache 是内存 Map（data/BookRepository.ets:140），先落磁盘缓存表再给卡片与章节行 |  —  |
|  章节下载/暂停/删除  |  `BookCacheManageScreen.kt:590-620`  |  —  | 未接 |  同上  |  单章可下载、暂停、删除  |  — ；**要接**：缓存管理页主体需磁盘章节缓存；现有 chapterCache 是内存 Map（data/BookRepository.ets:140），先落磁盘缓存表再给卡片与章节行 |  —  |
|  删除整书缓存确认框  |  `BookCacheManageScreen.kt:652-668` `DeleteBookCacheDialog`  |  —  | 未接 |  本地无  |  确认框写明书名，取消则不删  |  — ；**要接**：缓存管理页主体需磁盘章节缓存；现有 chapterCache 是内存 Map（data/BookRepository.ets:140），先落磁盘缓存表再给卡片与章节行 |  —  |
|  删除章节缓存确认框  |  `BookCacheManageScreen.kt:670-684` `DeleteChapterCacheDialog`  |  —  | 未接 |  本地无  |  确认框写明章节名，取消则不删  |  — ；**要接**：缓存管理页主体需磁盘章节缓存；现有 chapterCache 是内存 Map（data/BookRepository.ets:140），先落磁盘缓存表再给卡片与章节行 |  —  |
|  长按卡片进选择  |  `BookCacheManageViewModel.kt`  |  —  | 未接 |  本地无选择模式  |  长按选中后可批量删缓存  |  — ；**要接**：缓存管理页主体需磁盘章节缓存；现有 chapterCache 是内存 Map（data/BookRepository.ets:140），先落磁盘缓存表再给卡片与章节行 |  —  |

### D3 书架管理页（`BookshelfManageScreen.kt`，本地整页缺失）

| 上游能力 | 上游位置 | 本地位置 | 状态 | 差异说明 | 验收方式 | 备注 | ZIP 类别 |
| --- | --- | --- | --- | --- | --- | --- | --- |
|  整个页面  |  `BookshelfManageScreen.kt`（1777 行）+ `BookshelfManageScreenViewModel.kt`（1136 行）  |  —  | 未接 |  本地无此页，`pages/BookshelfPage.ets:594-595` 菜单项直接 `onUnavailableAction('书架管理尚未迁移')`  |  从书架更多菜单进入书架管理页  |  下列各行是这一页内的能力；见 [已知问题](../KNOWN-ISSUES.md#本地书籍行登记bookshelfmd-的-localbook-未接行) KI-LB6 ；**要接**：书架管理页整页未建（29 行），按上游 BookshelfManageScreen 建页；其中 :463 批量换源与 :471-:474 书源面板随书源模块 |  localBook / bookGroup  |
|  顶栏标题随分组名变化  |  `BookshelfManageScreen.kt:300`  |  —  | 未接 |  同上  |  从某分组进入时标题显示该分组名  |  无分组时显示「离线缓存」；见 [已知问题](../KNOWN-ISSUES.md#本地书籍行登记bookshelfmd-的-localbook-未接行) KI-LB6 ；**要接**：书架管理页整页未建（29 行），按上游 BookshelfManageScreen 建页；其中 :463 批量换源与 :471-:474 书源面板随书源模块 |  localBook / bookGroup  |
|  分组筛选按钮  |  `BookshelfManageScreen.kt:316-340`  |  —  | 未接 |  同上  |  点筛选切分组  |  `a11y_group_filter`；见 [已知问题](../KNOWN-ISSUES.md#本地书籍行登记bookshelfmd-的-localbook-未接行) KI-LB6 ；**要接**：书架管理页整页未建（29 行），按上游 BookshelfManageScreen 建页；其中 :463 批量换源与 :471-:474 书源面板随书源模块 |  localBook / bookGroup  |
|  下载全部  |  `BookshelfManageScreen.kt:341-346`  |  —  | 未接 |  同上  |  点「下载全部」三本书依次缓存  |  二次确认框 ；**要接**：书架管理页整页未建（29 行），按上游 BookshelfManageScreen 建页；其中 :463 批量换源与 :471-:474 书源面板随书源模块 |  —  |
|  导出全部  |  `BookshelfManageScreen.kt:352-357`  |  —  | 未接 |  同上  |  点「导出全部」进入导出设置  |  — ；**要接**：书架管理页整页未建（29 行），按上游 BookshelfManageScreen 建页；其中 :463 批量换源与 :471-:474 书源面板随书源模块 |  —  |
|  日志  |  `BookshelfManageScreen.kt:357-360`  |  —  | 未接 |  同上  |  点日志弹出导出日志列表  |  — ；**要接**：书架管理页整页未建（29 行），按上游 BookshelfManageScreen 建页；其中 :463 批量换源与 :471-:474 书源面板随书源模块 |  —  |
|  书籍行（书名/作者/分组/本地标记）  |  `BookshelfManageScreen.kt:608-660`  |  —  | 未接 |  同上  |  每行显示四段文字  |  `R.string.local_book` 本地标记；见 [已知问题](../KNOWN-ISSUES.md#本地书籍行登记bookshelfmd-的-localbook-未接行) KI-LB6 ；**要接**：书架管理页整页未建（29 行），按上游 BookshelfManageScreen 建页；其中 :463 批量换源与 :471-:474 书源面板随书源模块 |  localBook / bookGroup  |
|  行内下载/停止  |  `BookshelfManageScreen.kt:660-673`  |  —  | 未接 |  同上  |  点下载缓存全书  |  — ；**要接**：书架管理页整页未建（29 行），按上游 BookshelfManageScreen 建页；其中 :463 批量换源与 :471-:474 书源面板随书源模块 |  —  |
|  行内导出  |  `BookshelfManageScreen.kt:679-694`  |  —  | 未接 |  同上  |  点导出弹导出设置  |  — ；**要接**：书架管理页整页未建（29 行），按上游 BookshelfManageScreen 建页；其中 :463 批量换源与 :471-:474 书源面板随书源模块 |  —  |
|  行内加分组  |  `BookshelfManageScreen.kt:694-720`  |  —  | 未接 |  同上  |  点分组图标把书移入某分组  |  见 [已知问题](../KNOWN-ISSUES.md#本地书籍行登记bookshelfmd-的-localbook-未接行) KI-LB6 ；**要接**：书架管理页整页未建（29 行），按上游 BookshelfManageScreen 建页；其中 :463 批量换源与 :471-:474 书源面板随书源模块 |  localBook / bookGroup  |
|  行内更多菜单  |  `BookshelfManageScreen.kt:745-760`  |  —  | 未接 |  同上  |  弹出改名/换源/删除等  |  见 [已知问题](../KNOWN-ISSUES.md#本地书籍行登记bookshelfmd-的-localbook-未接行) KI-LB6 ；**要接**：书架管理页整页未建（29 行），按上游 BookshelfManageScreen 建页；其中 :463 批量换源与 :471-:474 书源面板随书源模块 |  localBook / bookSource  |
|  导出进度提示  |  `BookshelfManageScreen.kt:635` `exportMsg`  |  —  | 未接 |  同上  |  导出过程中行上显示进度文字  |  — ；**要接**：书架管理页整页未建（29 行），按上游 BookshelfManageScreen 建页；其中 :463 批量换源与 :471-:474 书源面板随书源模块 |  —  |
|  选择模式·全选  |  `BookshelfManageScreen.kt:236-245`  |  —  | 未接 |  同上  |  点全选选中当前可见书  |  — ；**要接**：书架管理页整页未建（29 行），按上游 BookshelfManageScreen 建页；其中 :463 批量换源与 :471-:474 书源面板随书源模块 |  —  |
|  选择模式·反选  |  `BookshelfManageScreen.kt:226-232`  |  —  | 未接 |  同上  |  点反选交换选中状态  |  `revert_selection` ；**要接**：书架管理页整页未建（29 行），按上游 BookshelfManageScreen 建页；其中 :463 批量换源与 :471-:474 书源面板随书源模块 |  —  |
|  选择模式·批量下载  |  `BookshelfManageScreen.kt:240-250`  |  —  | 未接 |  同上  |  选中 3 本批量下载  |  — ；**要接**：书架管理页整页未建（29 行），按上游 BookshelfManageScreen 建页；其中 :463 批量换源与 :471-:474 书源面板随书源模块 |  —  |
|  选择模式·批量换源  |  `BookshelfManageScreen.kt:248-255`  |  —  | 未接 |  同上  |  选中 3 本批量换源  |  依赖书源体系；见 [已知问题](../KNOWN-ISSUES.md#本地书籍行登记bookshelfmd-的-localbook-未接行) KI-LB6 ；**要接**：书架管理页整页未建（29 行），按上游 BookshelfManageScreen 建页；其中 :463 批量换源与 :471-:474 书源面板随书源模块 |  localBook / bookSource  |
|  选择模式·移入分组  |  `BookshelfManageScreen.kt:255-260`  |  —  | 未接 |  同上  |  选中 3 本移入同一分组  |  `move_to_group`；见 [已知问题](../KNOWN-ISSUES.md#本地书籍行登记bookshelfmd-的-localbook-未接行) KI-LB6 ；**要接**：书架管理页整页未建（29 行），按上游 BookshelfManageScreen 建页；其中 :463 批量换源与 :471-:474 书源面板随书源模块 |  localBook / bookGroup  |
|  选择模式·清除缓存  |  `BookshelfManageScreen.kt:271-280`  |  —  | 未接 |  同上  |  选中 3 本清缓存  |  `clear_cache` ；**要接**：书架管理页整页未建（29 行），按上游 BookshelfManageScreen 建页；其中 :463 批量换源与 :471-:474 书源面板随书源模块 |  —  |
|  选择模式·删除  |  `BookshelfManageScreen.kt:278-290`  |  —  | 未接 |  同上  |  选中 3 本删除并二次确认  |  `delete_book_file`；见 [已知问题](../KNOWN-ISSUES.md#本地书籍行登记bookshelfmd-的-localbook-未接行) KI-LB6 ；**要接**：书架管理页整页未建（29 行），按上游 BookshelfManageScreen 建页；其中 :463 批量换源与 :471-:474 书源面板随书源模块 |  localBook  |
|  选择模式·分段导出  |  `BookshelfManageScreen.kt:736-743` `select_section_export`  |  —  | 未接 |  同上  |  选一段章节范围导出  |  — ；**要接**：书架管理页整页未建（29 行），按上游 BookshelfManageScreen 建页；其中 :463 批量换源与 :471-:474 书源面板随书源模块 |  —  |
|  导出设置面板  |  `BookshelfManageScreen.kt:1496-1516`  |  —  | 未接 |  同上  |  弹出导出类型/编码/文件名等  |  — ；**要接**：书架管理页整页未建（29 行），按上游 BookshelfManageScreen 建页；其中 :463 批量换源与 :471-:474 书源面板随书源模块 |  —  |
|  导出文件名模板  |  `BookshelfManageScreen.kt:53`、`:56`、`:59-60`  |  —  | 未接 |  同上  |  填 `{{name}}-{{index}}` 后文件名按模板生成  |  `export_file_name_template_hint`/`_help` ；**要接**：书架管理页整页未建（29 行），按上游 BookshelfManageScreen 建页；其中 :463 批量换源与 :471-:474 书源面板随书源模块 |  —  |
|  导出编码选择  |  `BookshelfManageScreen.kt:15` `showCharsetDialog`、`set_charset`  |  —  | 未接 |  同上  |  可选 UTF-8/GBK 等编码  |  — ；**要接**：书架管理页整页未建（29 行），按上游 BookshelfManageScreen 建页；其中 :463 批量换源与 :471-:474 书源面板随书源模块 |  —  |
|  自定义 EPUB 导出  |  `BookshelfManageScreen.kt:299-313`  |  —  | 未接 |  同上  |  单选一本 EPUB 时弹自定义导出框  |  — ；**要接**：书架管理页整页未建（29 行），按上游 BookshelfManageScreen 建页；其中 :463 批量换源与 :471-:474 书源面板随书源模块 |  —  |
|  文件选择器面板  |  `BookshelfManageScreen.kt:9`、`:173` `showFilePickerSheet`  |  —  | 未接 |  同上  |  首次导出弹出目录选择  |  — ；**要接**：书架管理页整页未建（29 行），按上游 BookshelfManageScreen 建页；其中 :463 批量换源与 :471-:474 书源面板随书源模块 |  —  |
|  书源选择面板  |  `BookshelfManageScreen.kt:1374-1495` `BookSourcePickerSheet`  |  —  | 未接 |  同上  |  批量换源时列出可用书源  |  依赖书源体系；见 [已知问题](../KNOWN-ISSUES.md#本地书籍行登记bookshelfmd-的-localbook-未接行) KI-LB6 ；**要接**：书架管理页整页未建（29 行），按上游 BookshelfManageScreen 建页；其中 :463 批量换源与 :471-:474 书源面板随书源模块 |  localBook / bookSource  |
|  换源预览面板  |  `BookshelfManageScreen.kt:1517-1571` `BatchChangePreviewSheet`  |  —  | 未接 |  同上  |  换源前逐本预览结果  |  依赖书源体系；见 [已知问题](../KNOWN-ISSUES.md#本地书籍行登记bookshelfmd-的-localbook-未接行) KI-LB6 ；**要接**：书架管理页整页未建（29 行），按上游 BookshelfManageScreen 建页；其中 :463 批量换源与 :471-:474 书源面板随书源模块 |  localBook / bookSource  |
|  其它书源选项  |  `BookshelfManageScreen.kt:1710-1755` `OtherSourceOptionsSheet`  |  —  | 未接 |  同上  |  换源时可勾选保留项  |  依赖书源体系；见 [已知问题](../KNOWN-ISSUES.md#本地书籍行登记bookshelfmd-的-localbook-未接行) KI-LB6 ；**要接**：书架管理页整页未建（29 行），按上游 BookshelfManageScreen 建页；其中 :463 批量换源与 :471-:474 书源面板随书源模块 |  localBook / bookSource  |
|  删除确认框  |  `BookshelfManageScreen.kt:18` `showDeleteBookConfirmDialog`  |  —  | 未接 |  同上  |  删除前列出将删的书  |  见 [已知问题](../KNOWN-ISSUES.md#本地书籍行登记bookshelfmd-的-localbook-未接行) KI-LB6 ；**要接**：书架管理页整页未建（29 行），按上游 BookshelfManageScreen 建页；其中 :463 批量换源与 :471-:474 书源面板随书源模块 |  localBook  |

### D4 全书架页（`MainRouteCache` 的另一半语义）

| 上游能力 | 上游位置 | 本地位置 | 状态 | 差异说明 | 验收方式 | 备注 | ZIP 类别 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 从「我的」进缓存管理页 | `ui/main/my/MyScreen.kt:221-226`、`MyViewModel.kt:30` `OpenBookCacheManage` | `pages/ProfilePage.ets:81` | 已接 | 本地入口在「其它」组 | 点「缓存管理」进入 D1 页面 | — | — |
|  从书架更多菜单进书架管理页  |  `ui/main/bookshelf/BookshelfScreen.kt:747-754`  |  `pages/BookshelfPage.ets:594-595`  | 未接 |  本地菜单项存在但点击提示未迁移  |  点「书架管理」进入 D3 页面  |  — ；**要接**：入口已在 pages/BookshelfPage.ets:594-595，页建好后改接线 |  —  |
| 书架页「分组管理」悬浮入口 | `ui/main/bookshelf/BookshelfScreen.kt:642` `Icons.Default.Bookmarks` | `pages/BookshelfPage.ets:339-355` | 已接 | 本地用下拉菜单而非独立页 | 点分组入口可切分组 | 与 A3 块重叠，此处只记入口 | — |
|  下载与缓存设置页  |  `ui/config/downloadCacheConfig/DownloadCacheConfigScreen.kt`  |  `pages/AppDownloadCacheSettingsPage.ets`  | 未接 |  本地是**纯预览**：5 处 `onUnavailableAction`（封面缓存 / 漫画缓存 / 清理缓存 / 压缩数据库），页尾自写「此页数值目前仅用于界面预览；偏好保存、缓存统计和清理操作尚未接入」；6 个滑块与 1 个开关都只画不存  |  改任一项后重启仍保持  |  **这是设置页，不是 D1/D3**；归 `readConfig` 类别，列在这里只为说清「缓存」三处不要混 ；**要接**：本页 6 个滑块与 1 个开关只画不存；补偏好保存与缓存统计。漫画缓存一行随漫画范围另议 |  readConfig  |

---

## E 备份恢复（整界面，跨类别的公共层）

本块按 [KEYWORDS.md](KEYWORDS.md) 的「存储层维度」一节新增。选题理由：A1–D 四块都在盘「某个类别的数据在界面上怎么用」，但还有一层代码既不属于任何单个类别，也**对全部 28 个类别的关键词零命中**——它们处理的是「所有类别一起」的动作：规划整批书目、规整整份 `config.xml`、加解密整个压缩包、以及那个把 28 个勾选框画出来的备份设置页。

`grep -cE "Bookmark|BookMarking" help/storage/Backup.kt` = **0**：导出主文件里一个实体类名都不出现，19 个类别全以 `dbIsNotIgnored("bookmark")` 这种小写键名引用。所以按实体类名选词的本表，此前从未把这一层纳入接触面——**覆盖证明显示通过，但这一层从未被检查过**。

本块 19 行覆盖该层 21 个文件里最关键的部分（r336 追加的 `keyboardAssists` 6 行同指该表那一处，不按文件数计）。剩余 8 个纯数据类/空壳实现（`domain/model/WebDavBackup.kt`、`domain/gateway/*.kt` 三个接口、`domain/model/settings/BackupSettings.kt`、`BackupConfig.kt` 的 `@Deprecated` 门面、`BackupRestoreLock.kt`、`BackupAES.kt`）由本块各行在其「上游位置」列一并引用，不单独占行。

`help/storage/BookRestorePlanner.kt` 原本连关键词都捞不到（它对 `localBook` 的旧关键词 `BookDao|bookshelf\.json|Book\.kt` 命中 0），r296 给 `localBook` 补了 `BookRestorePlan`、`LocalBookLocationStatus`、`isRelocatedCopyOf`、`normalizeLocalBookLocation` 四个词才把它纳入接触面，随后落在本块最后一行。

| 上游能力 | 上游位置 | 本地位置 | 状态 | 差异说明 | 验收方式 | 备注 | ZIP 类别 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 备份设置页整体 | `ui/config/backupConfig/BackupConfigScreen.kt:142-282`（`BackupConfigRouteScreen` 在 `:72-138`） | `pages/AppBackupSettingsPage.ets:47-184` | 已接 | 两组分栏齐全（WebDAV 设置 8 项、备份与恢复 7 项），15 个控件逐个都在；其中 WebDAV 整组只画不存，已在下两行单列 | 打开「备份与恢复」页看到两组设置 | 本地页 343 行，上游页 545 行；本行只判页面骨架 | — |
|  WebDAV 服务器地址 / 账号 / 子目录 / 设备名称  |  `BackupConfigScreen.kt:170-193`  |  `pages/AppBackupSettingsPage.ets:55-62`、`:220-231`  | 已接 |  四行都在，点开只弹一个 `TextInput`，`:225` 自己写着「WebDAV 尚未迁移，此页不会保存或发送输入」；四个 `@State` 字段初始值写死 。**复核（r340）**：pages/AppBackupSettingsPage.ets:288-293 按 inputKey 写 next.url/account/password/dir/deviceName，经 onWebDavSettingsChange 到 pages/Index.ets:8561 saveWebDavSettings 落盘 | 填完服务器地址与账号后退出再进备份设置页，四行 detail 仍显示已填的值； 改地址后重启仍保持  |  键：`web_dav_url`/`web_dav_account`/`web_dav_password` 为 `—`；`webDavDeviceName` 与 `backupUri` 在 `alwaysIgnoredPreferenceKeys`  |  —  |
|  WebDAV 账号密码对话框  |  `BackupConfigScreen.kt:446-500`（`BackupConfigDialogs` 的 `WebDavAuth` 分支）、`BackupConfigContract.kt:46-50`  |  —  | 未接 |  本地无独立账号密码框，被合并进上一个输入框  |  弹框可填账号密码并做可见性切换  |  `BackupConfigDialog.WebDavAuth` ；**不接**：本地把账号与密码拆成两行、各自弹输入框并各自落盘（pages/AppBackupSettingsPage.ets:288-293）；与上游单对话框两字段等效，只差形态 |  —  |
|  测试同步  |  `BackupConfigScreen.kt:194-198`  |  `pages/AppBackupSettingsPage.ets:63-64`  | 已接 |  点击走 `onUnavailableAction('WebDAV 连接尚未迁移，未发起测试')` 。**复核（r340）**：pages/AppBackupSettingsPage.ets:107 onSelect 调 onTestWebDav()，接 pages/Index.ets:5391 testWebDav() | 点「测试同步」后出现连接结果提示（成功或失败原因），不再是未迁移提示； 点「测试同步」返回连接结果  |  `AppWebDav.testWebDav()`  |  —  |
|  同步书籍进度 / 增强进度同步 / 自动检查新备份 / 备份同步模式  |  `BackupConfigScreen.kt:199-231`  |  `pages/AppBackupSettingsPage.ets:65-83`  | 未接 |  三个开关 + 一个下拉都在，`onChange` 一律 `onUnavailableAction('仅界面预览…未保存')`；同步模式下拉只有两个硬编码选项  |  切换后重启仍保持  |  键 `syncBookProgress`/`syncBookProgressPlus`/`autoCheckNewBackup`/`backupSyncMode` 均为 `—`（参与备份但不受类别开关控制） ；**要接**：三个开关只存值：进度同步需 WebDavSync 上传 bookProgress、自动检查需后台任务；同步模式下拉已可用 |  —  |
|  备份路径选择  |  `BackupConfigScreen.kt:233-239`（`ChooseBackupPath` sheet 在 `:291-295`）  |  `pages/AppBackupSettingsPage.ets:89-90`、`:232-234`  | 未接 |  sheet 只有一个「选择系统目录」，点击提示「备份目录选择尚未迁移」  |  选完后路径显示在行上并持久化  |  `OpenDocumentTree` → `LaunchBackupDirectoryPicker`；键 `backupUri` 属 `不备份` ；**要接**：备份目录选择走 picker；只保留最新需在备份完成后按时间清理目标目录 |  —  |
|  备份三选一（本地 / WebDAV / 两者）  |  `BackupRestoreOptionSheets.kt:18-45`（`BackupOptionSheet`）  |  `pages/AppBackupSettingsPage.ets:197-203`  | 已接 |  「备份到本地」已实现；「备份到 WebDAV」「同时备份」两项提示未迁移 。**复核（r340）**：pages/AppBackupSettingsPage.ets:259 onSelect 调 onBackupToWebDav()，接 pages/Index.ets:5408 | 备份弹层里选「备份到 WebDAV」后真的走 WebDAV 上传并给出结果； 三个选项各自产出 ZIP  |  上游 `RequestBackup("local"/"webdav"/"both")`；已接的是 sheet 骨架与本地分支  |  —  |
|  恢复二选一（本地 / WebDAV）  |  `BackupRestoreOptionSheets.kt:49-70`（`RestoreOptionSheet`）  |  `pages/AppBackupSettingsPage.ets:204-208`  | 已接 |  「从本地恢复」已实现并带 ZIP 预览；「从 WebDAV 恢复」提示未迁移 。**复核（r340）**：pages/AppBackupSettingsPage.ets:269 onSelect 调 onRestoreFromWebDav()，接 pages/Index.ets:5433 | 恢复弹层里选「从 WebDAV 恢复」后拉取远端备份并进入恢复流程； 两个来源都能恢复  |  本地还多一层预览确认（`:123-146`），上游没有；已接的是 sheet 骨架与本地分支  |  —  |
| 备份 ZIP 预览 | 上游无对应能力 | `pages/AppBackupSettingsPage.ets:123-146` | 不适用 | 上游无对应能力：本地选完 ZIP 后先列全部根条目与条数，点「导入此 ZIP」才执行。这是本地补充，不构成缺陷 | 选 ZIP 后看到条目清单与本地书缺正文提示 | 唯一一条 `不适用` 是「上游没有而本地多了」，不是「做不了」 | — |
| 恢复排除项 / 备份排除项（两个勾选面板） | `BackupConfigScreen.kt:332-382`（两个 `IgnoreItemsSheet` 调用）、`:383-444`（面板本体，`CardTabRow` 两页签：`config_ignore` 与 `database_ignore`） | `pages/AppBackupSettingsPage.ets:101-106`、`:209-219` | 已接 | 两个面板都在，28 个类别由 `BackupRepository.categoryOptionsList()` 提供，可勾选并落盘（见 [BACKUP-RESTORE.md](../BACKUP-RESTORE.md) 的 28 类清单） | 取消「书签」勾选后备份 ZIP 里没有 `bookmark.json` | 上游 `IgnoreItemsSheet` 分「配置」与「数据库」两页签，本地是一个平铺列表，**未分页签** | — |
|  只保留最新备份  |  `BackupConfigScreen.kt:269-276`  |  `pages/AppBackupSettingsPage.ets:109-113`  | 未接 |  开关在，`onChange` 提示「仅界面预览，此设置未保存」  |  关掉后生成带日期的多份备份  |  键 `onlyLatestBackup` 为 `—` ；**要接**：备份目录选择走 picker；只保留最新需在备份完成后按时间清理目标目录 |  —  |
|  导入旧版数据  |  `BackupConfigScreen.kt:264-268`、`help/storage/ImportOldData.kt:28-98`（`importUri`，读 `myBookShelf.json`/`myBookSource.json`/`myBookReplaceRule.json`）  |  `pages/AppBackupSettingsPage.ets:107-108`  | 未接 |  行在，点击提示「旧版数据导入尚未迁移」；本地全仓 `grep myBookShelf\|ImportOldData` 命中 0  |  选旧版目录后书架/书源/规则各有导入计数  |  上游 `ImportOldData.kt` 370 行，本块只覆盖入口 ；**要接**：旧版数据（myBookShelf 的 JSON）导入：本地无解析器，需按旧格式建解析与落库 |  —  |
| 本地书恢复期冲突规划（删重复书 / 重定位识别 / 三态定位） | `help/storage/BookRestorePlanner.kt:27`（`planBookRestore`）、`:8`（`BookRestorePlan` 的 `booksToUpdate`/`booksToInsert`/`booksToDelete`）、`:150`（`isRelocatedCopyOf`）、`:17`（`LocalBookLocationStatus` 的 `Available`/`Missing`/`Unknown`）、`:159`（`normalizeLocalBookLocation`）；调用点在 `help/storage/Restore.kt:130-140`，定位实现 `Restore.kt:400-421` | `data/LocalBookRestorePlanner.ets`（全文），接入点 `data/BackupRepository.ets:2272`-`:2385`（`restoreMatchingLocalProgress`，定义 `:2272`、规划调用 `:2301`、删书循环 `:2363`-`:2369`、插书循环 `:2370`-`:2378`） | 已接 | 上游三态语义在 HarmonyOS 侧没有 `Environment` 挂载态，改为：文件在 → `Available`；文件不在但父目录可访问 → `Missing`；父目录也访问不了或 `content://` → `Unknown`（**`Unknown` 一律不删书**，与上游注释一致）。`normalizeLocalBookLocation` 的 `canonicalPath` 退化为「去掉重复分隔符与 `.` 段」 | 造单条 `bookshelf.json` 的合成 ZIP 走「恢复 → 从本地恢复 → 导入此 ZIP」（r296 已在模拟器验收三种）：路径已变但同文件名同书名同作者 → 归并成一条且进度取备份值；`Missing` 条目在有唯一 `Available` 副本时被清理并计入「清理 N 本重复书目」；`Unknown` 条目一条都不删 | 上游 `Restore.kt:130-140` 是一个事务 `delete/update/insert`；本地 `booksToUpdate` 仍走上面已有的逐字段进度合并，`booksToDelete`/`booksToInsert` 由本行新增的规划器产出。本地额外产出一张 `resolvedTargets`（备份原始路径 → 实际落点），否则重定位的书进度合不上——上游是靠 `copy(bookUrl = 目标)` 直接改对象，本地规划器返回新对象必须显式带出映射 | localBook |
|  备份忽略列表里「键盘辅助」这一项：勾掉后备份 ZIP 里没有 `keyboardAssists.json`  |  `help/storage/BackupConfig.kt:87`（`dbKeyKeyboardAssists = "keyboardAssists"`）、`:99`（`dbIgnoreKeys` 第 12 项）、`:116`（`dbIgnoreTitle` 第 12 项）；`ui/config/backupConfig/BackupConfigScreen.kt:259-263`（打开备份忽略列表）、`:356-379`（备份侧 `IgnoreItemsSheet`）、`:432-440`（「数据库忽略」页签逐项画 `CheckboxItem`）；`BackupConfigViewModel.kt:403-412`（装载）、`:241-247`（保存）；`help/storage/Backup.kt:195-197`（门控写出）  |  `pages/AppBackupSettingsPage.ets:130-132`（「备份排除项」行）、`:237-247`（列表）、`:372-379`（`ForEach` 逐项 `Toggle`）；`data/BackupRepository.ets:490`（`{ key: 'keyboardAssists', title: '按键映射', … }`）、`:2694`-`:2701`（`isIgnored` 定义）、`:2580`（`copyPreservedEntries` 里按忽略名单跳过拷贝）；`pages/Index.ets:520`-`:521`（状态）、`:8335`-`:8350`（传参与回调）  | 已接 |  上游勾掉后该表数据不再从数据库导出（`Backup.kt:195` 的 `dbIsNotIgnored("keyboardAssists", true)` 为假则 `:196` 不执行）；本地勾掉后 `:2580` 跳过，保留目录里的 `keyboardAssists.json` 不被拷进新 ZIP。差异在**被门控的对象**：上游是数据库导出，本地是 ZIP 条目拷贝。本地无该表的原生数据，勾与不勾不影响任何本地仓储。实测见 tmp/keyboardassists-impl-evidence.md 第 0 节；行为已与上游一致，是否改判 已接 属判断段复核范围 。**复核（r340）**：data/BackupRepository.ets:614 类别注册、:2580 copyPreservedEntries 按忽略名单跳过；未被忽略时保留目录里的 keyboardAssists.json 照原样进 ZIP | 备份排除项打开「按键映射」后备份，unzip -l 新 ZIP 里没有 keyboardAssists.json；关掉再备份一次它又出现； 造一份含 `keyboardAssists.json` 的合成 ZIP，先恢复一次（该文件落 `filesDir/android-backup-entries/`），再在「备份排除项」里打开「按键映射」，备份，`unzip -l` 新 ZIP 确认无该条目；关掉该开关再备份一次，确认出现。配套命令：`grep -n "keyboardAssists" entry/src/main/ets/data/BackupRepository.ets` 应只有 `:463`（`fileNames` 常量）、`:490`（`categoryOptions`）两行  |  界面上那一行标题是「按键映射」，上游四个语言的字符串分别是 `Keyboard Assists` / `键盘辅助` / `鍵盤輔助`（`res/values/strings.xml:1538`、`values-zh-rCN:1473`、`values-zh-rHK:1278`、`values-zh-rTW:1281`）。面板级已在 `:503` 记过，本行只记这一格的语义  |  `keyboardAssists`  |
|  恢复忽略列表里「键盘辅助」这一项：勾掉后恢复时不导入该表  |  `ui/config/backupConfig/BackupConfigScreen.kt:254-258`（打开恢复忽略列表）、`:332-355`（恢复侧 `IgnoreItemsSheet`）；`BackupConfigViewModel.kt:393-401`（装载）、`:224-229`（保存）；`help/storage/Restore.kt:250-257`（门控读入）  |  `pages/AppBackupSettingsPage.ets:126-128`（「恢复排除项」行）、`:237-247`；`data/BackupRepository.ets:2694`-`:2701`（`isIgnored` 定义）、`:1189`（恢复主循环跳过）、`:2501`（预览跳过）；`pages/Index.ets:5651`-`:5654`（`toggleRestoreIgnore`）、`:5663`-`:5672`（`saveBackupIgnoreLists` 落盘）  | 已接 |  上游勾掉后 `Restore.kt:253` 不执行，该表记录不进数据库；本地勾掉后 `:1189` 直接 `continue`，既不解析也不落保留目录，`:2501` 让预览列表里也不出现。上游这一格跳的是「入库」，本地跳的是「归档 + 预览」。实测见 tmp/keyboardassists-impl-evidence.md 第 0 节；行为已与上游一致，是否改判 已接 属判断段复核范围 。**复核（r340）**：data/BackupRepository.ets:1189 恢复主循环跳过、:2501 预览跳过；忽略时该类原有文件也不进 android-backup-entries | 恢复排除项打开「按键映射」后恢复，预览列表里不出现该条目，目录下也不生成该文件； 同上合成 ZIP：勾上「恢复排除项」里的「按键映射」后导入，确认 `filesDir/android-backup-entries/` 下没有 `keyboardAssists.json`、预览列表里也没有该条；取消勾选再导入一次，两处都出现  |  上游恢复侧 `Restore.kt:250` **不传**第二个实参，故读 `dbIgnore.json`；备份侧 `Backup.kt:195` 传 `true`，读 `backupDbIgnore.json`。本地用 preferences 的 `backupIgnore` / `restoreIgnore` 两个键（读 `BackupRepository.ets:595`-`:596`、写 `:609`-`:610`）分开存  |  `keyboardAssists`  |
|  该表的数据来源：首次打开数据库时从 `assets/defaultData/keyboardAssists.json` 灌 32 条默认值  |  `data/AppDatabase.kt:351`（`onOpen`）、`:455-478`（灌入段，触发条件 `:461` `if (it.count == 0)`）、`:460`（查询）、`:469-473`（`db.insert("keyboardAssists", …)`）；`help/DefaultData.kt:104-110`（读资产）；`assets/defaultData/keyboardAssists.json`（32 条，2262 字节）  |  无（本地 `data/RdbSchema.ets` 的 13 张 `CREATE TABLE` 里没有该表）  | 未接 |  上游的 32 条默认数据只在「该表为空」时灌一次，灌完就是数据库里的行；本地没有这张表，也没有这 32 条的落点。这 32 条的内容是书源规则语法符号（`@css:`、`<js>`、`{{}}`、`class`、`textNodes`、`useWebView` 等），不是键码  |  `grep -n "CREATE TABLE" entry/src/main/ets/data/RdbSchema.ets` 输出里不应出现 `keyboardAssists`；`python -c` 读 `app/src/main/assets/defaultData/keyboardAssists.json` 应得 `count 32`、`pure-numeric keys: 0`  |  灌入不在 `onCreate`（`:347-349` 只有 `db.setLocale(Locale.CHINESE)`），在 `onOpen`。资产无 `type` 字段，实体默认 `type = 0`（`data/entities/KeyboardAssist.kt:12-13`）；样本备份里 `type` 显式为 `0` ；**要接**：该表 32 条默认数据是书源规则语法表，随在线书源模块才有消费方 |  `keyboardAssists`  |
| 该表的读者：Room 表 + DAO，供阅读/编辑某处读取 | `data/entities/KeyboardAssist.kt:9-19`（`@Entity(tableName = "keyboardAssists", primaryKeys = ["type", "key"])`，字段 `type`/`key`/`value`/`serialNo`）；`data/dao/KeyboardAssistsDao.kt:8-33`（8 个成员）；`data/AppDatabase.kt:323`；`di/appDatabaseModule.kt:86` | 无 | 不适用 | 上游**没有**读者：DAO 8 个成员里 `update`、`delete`、`flowByType`、`maxSerialNo` 全仓零引用，`getByType` 唯一命中是同名前缀无关方法 `data/dao/BookDao.kt:782 fun getByTypeOnLine`，`flowAll` 63 处全是别的类同名方法；`all` 只被 `Backup.kt:196` 用、`insert` 只被 `Restore.kt:253` 用。`ui/` 目录 `grep -rn -i 'keyboardassist'` 零命中 | `grep -rn 'keyboardAssistsDao' --include=*.kt app/src/main/java` 应恰好 4 行（`AppDatabase.kt:323`、`appDatabaseModule.kt:86`、`Backup.kt:196`、`Restore.kt:253`）；`grep -rn -i 'keyboardassist' app/src/main/java/io/legado/app/ui/` 应零输出 | 判 `不适用` 的依据是 [PARITY-RULES.md](../PARITY-RULES.md) `:84` 第一类「上游无此行为」的第二种形态「代码里有但从未接线」：表、实体、DAO、DI 全在，但没有任何业务消费方。与「范围之外」无关——`PROJECT.md:26` 的七项不做项里没有键位 | `keyboardAssists` |
|  该类的恢复落地方式：恢复时按条目名具名分支，落到原生仓储  |  `help/storage/Restore.kt:250-257`（唯一入口）、`:1-3`（`import` 区，含 `SQLiteConstraintException` 的来源）  |  `data/BackupRepository.ets:1133`-`:1140`（`restore` 签名，落点 `:1141`）、`:1189`（跳过判定）、`:1482`-`:1483`（主循环末尾兜底 `copyFile`）  | 未接 |  本地恢复侧具名分支共 21 处 `name ===` 判断、19 个条目名（`bookshelf.json`、`config.xml`、`bookGroup.json`、`replaceRule.json`、`txtTocRule.json`、`highlightRule.json`、`dictRule.json`、`httpTTS.json`、`homepageModules.json`、`homepageCustomSets.json`、`highlightTagRule.json`、`tagGroupRule.json`、`bookmark.json`、`bookMarking.json`、`readRecord.json`、`readRecordDetail.json`、`readRecordSession.json`、`coverRule.json` 与常量 `THEME_CONFIG_FILE_NAME`），**无 `keyboardAssists.json`**；该条目走 `:1482` 只进 `filesDir/android-backup-entries/`  |  `grep -n -e "name ===" -e "switch" -e "case '" entry/src/main/ets/data/BackupRepository.ets` 应无 `keyboardAssists`；恢复一份含该文件的 ZIP 后 `ls filesDir/android-backup-entries/` 应见该文件  |  上游用 `fileToListT<KeyboardAssist>(path, "keyboardAssists.json")` 解析并按 `@Insert(REPLACE)` 入库，异常只吞 `SQLiteConstraintException`（`Restore.kt:254`）；本地不解析该文件，无对应异常处理 ；**不接**：本地无 keyboardAssists 表，恢复时没有原生仓储可落；该类条目走 data/BackupRepository.ets:1482 兜底留在 android-backup-entries/，是本地唯一可行的落法 |  `keyboardAssists`  |
|  该类的备份写出方式：从数据库取全表，序列化为 JSON 落 ZIP  |  `help/storage/Backup.kt:85`（条目名清单）、`:195-197`（写出，带 `isBackup = true`）、`:359-372`（`writeListToJson`，`if (list.isNotEmpty())` 才落盘）  |  `data/BackupRepository.ets:614`-`:623`（`createBackup` 入口）、`:629`（`copyPreservedEntries` 调用）、`:2573`-`:2599`（保留目录拷贝，原样 `copyFile` 在 `:2592`）  | 未接 |  上游从 `keyboardAssistsDao.all` 现取现序列化；本地没有数据源，只有保留目录里可能存着的一份旧副本被原样拷回。且本地 `writeListToJson` 的上游等价物「列表为空则不写文件」这条语义在本地无对应实现  |  `unzip -l` 本地新备份，若此前没恢复过含该文件的 ZIP 则不应出现 `keyboardAssists.json`；`grep -n "keyboardAssists" entry/src/main/ets/data/BackupRepository.ets` 只有 `:463`、`:490` 两行，且 `:463` 所在的 `fileNames`（定义 `:459`-`:467`）全仓无消费  |  本地 `fileNames` 是死常量（`grep -rn 'fileNames' --include=*.ets entry/src/main/ets` 只有 `BackupRepository.ets:459` 一行，定义处之外零引用），所以「清单里写了」不等于「会写出」 ；**不接**：本地无该表数据源，写出侧只有保留目录原样拷贝；「从数据库取全表序列化」在本地没有对应对象 |  `keyboardAssists`  |

### 这一块与其余四块的边界

- **属本块**：备份/恢复的**流程**与**界面**——选路径、选来源、预览、勾忽略项、导入旧版。
- **不属本块，仍在 A–D**：某个类别的数据本身长什么样（`bookshelf.json` 里有哪些字段、`bookmark.json` 的条目结构）。这两件事经常相邻，判据看「改这行时动的是流程代码还是数据映射代码」。
- **也不属本块**：`config.xml` 的 28 个类别各自忽略哪个键——那是 [ZIP 类别的键表差异](../BACKUP-RESTORE.md#偏好键对齐差异待移除) 一节的事。


## F 本地书导入与判重（整界面，r323 新增）

> **r328 已落地的部分（KI-REL4 修复）**：判重键从 `format + title + author` 换成 `bookUrl`（本地就是正文文件路径），并且正文文件名从 `local-<时间戳>.txt` 改成 `local-<md5(源 uri)>.txt`——同一源文件必然得到同一个 `bookUrl`，判重才可能命中；命中后按上游 `LocalBook.kt:280-289` 走「更新」分支（书目行沿用原记录、章节整本重建、`latestChapterTime = 0`），不再拒绝导入。设备验证见 [VALIDATION.md](../VALIDATION.md)「r328 KI-REL4」节。
>
> **本轮没做的**：失效记录接回（`planLocalBookImportReuse` / `rebindLocalBook`，本块第 2、3 行）、多选导入（第 5 行）、导入页「已上架」标记（第 6 行）、文件名解析作者（第 7 行）。这几行状态仍是 `未接`。

本块是 r323 的 KI-REL4「同名同作者加不进书架」盘出来的上游完整形态。选题理由：A1–E 五块都在盘「书已经在书架上之后，界面怎么用这些书」，但**一本书是怎么进到书架上来的**这一整层，此前一行都没有——A1 盘书架主屏与卡片，B 盘详情页，C 盘阅读进度，D 盘缓存，E 盘备份恢复；`LocalBook.kt`（649 行，本地书导入主类）只在覆盖证明里作为「已排除：本地书与导出，界面由别的模块承载」出现过一次，从未被盘过。

`localBook` 类别的旧关键词 `BookDao|bookshelf\.json|Book\.kt|"localBook"|BookRestorePlan|LocalBookLocationStatus|isRelocatedCopyOf|normalizeLocalBookLocation` 在 `model/localBook/LocalBook.kt` 上命中 **0**：该文件里没有任何一处写出字面量 `Book.kt`（import 的是 `io.legado.app.data.entities.Book`，不带扩展名）。所以 `--coverage localBook` 报 29/29 全过时，**本地书导入的主类根本不在接触面里**。r323 补 `LocalBookImport` 一词后接触面 29 → **31**（`LocalBook.kt` 与 `LocalBookImportPlanner.kt`），补词理由见 [KEYWORDS.md](KEYWORDS.md) 的「为什么原关键词漏掉渲染管线与目录页」节。

**判重键的完整图谱**（本块最重要的一张对照，四条链路四个键，互不相同）：

| 链路 | 判重键 | 上游位置 |
| --- | --- | --- |
| 本地书导入 | `bookUrl`（= 文件的 `toString()`） | `model/localBook/LocalBook.kt:255` `appDb.bookDao.getBook(bookUrl)`；`data/dao/BookDao.kt:705-706` |
| 失效记录接回 | `originName`（文件名） | `LocalBook.kt:302-313` `getBookByFileName(fileName)`；`BookDao.kt:702-703` |
| 导入页「已上架」标记 | `originName` 或 `origin` 含文件名 | `LocalBook.kt:568-572`；`BookDao.kt:805-809` |
| 在线书加入书架 | `bookUrl`，未命中再 `name + author` 合并 | `domain/usecase/AddBookUseCase.kt:30`/`:59`；`BookDao.kt:759-760` |

本地只有第四种（`format + title + author`），前三种一个都没有。

| 上游能力 | 上游位置 | 本地位置 | 状态 | 差异说明 | 验收方式 | 备注 | ZIP 类别 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 导入本地书以 `bookUrl` 判重：命中即「更新」语义（删旧目录、`latestChapterTime = 0` 触发重解析、`update`）；未命中才新建 | `model/localBook/LocalBook.kt:255`（`var book = appDb.bookDao.getBook(bookUrl)`）、`:249-259`（`bookUrl` 由 `FileDoc.fromUri(uri, false).apply { ... bookUrl = toString() }` 生成，`utils/FileDocExtensions.kt:30-32`）、`:280-289`（更新分支：`deleteBook(book, false)` → `book.latestChapterTime = 0` → `appDb.bookChapterDao.delByBook(bookUrl)` → `appDb.bookDao.update(book)`）、`data/dao/BookDao.kt:705-706`（`@Query("SELECT * FROM books WHERE bookUrl = :bookUrl")`） | `entry/src/main/ets/pages/Index.ets:5602-5637`（按 `contentPath`（即 bookUrl）判重；命中走更新：`BookRepository.copyBook(existing)` 后只换 `chapterCount`/`lastChapter`/`tocRule`、`latestChapterTime = 0`，再 `saveImportedBooks` + `saveChapters` 整本重建章节）、`entry/src/main/ets/data/BookRepository.ets:437-443`（`const bookId = \`local-${BookRepository.md5Encode16(uri)}\`` —— 正文文件名由源文件 uri 派生）、`BookRepository.ets:1196`（`const bookUrl = book.contentPath ?? ...`，落库主键就是正文文件路径） | 已接 | r328 起判重键与上游一致：本地书的 `bookUrl` 就是正文文件路径，而正文文件名由**源文件 uri 的 MD5** 派生，所以同一文件重复导入必然命中同一条记录，不同文件即使同名同作者也是两条。屏幕现象：书架已有 1 本 `the-metamorphosis` 时，用「添加本地」再导入同名同作者的 `the-metamorphosis.txt`，书架变 **2 本**（旧代码会拒绝并提示「这本书已在书架中」）；紧接着再导入同一个文件，书架仍是 **2 本**。沙箱里能看到两条正文文件 `local-1793713951683.txt`（改动前的时间戳命名）与 `local-00af08b6bceffeab.txt`（改动后的 `md5(uri)` 命名）。 | 同名同作者导入一次、同一文件再导入一次，看书架条数 | 依据源码 + 设备验证（r328，见 [VALIDATION.md](../VALIDATION.md)「r328 KI-REL4」节）。**迁移后果**：本改动前导入的书用时间戳命名，bookUrl 与新键对不上，那本同名书会被当成「另一本书」再新增一次；上游因为 `bookUrl` 一直是源文件路径，不存在这个迁移问题 | `localBook` |
|  失效记录接回：源文件被外部删掉后重新导入同名文件，把旧记录迁到新文件上而不是新建一条  |  `model/localBook/LocalBook.kt:260-266`（`val reusableBook = findReusableStaleLocalBook(bookUrl, fileName); if (reusableBook != null) { return rebindLocalBook(reusableBook, bookUrl, fileName) }`）、`:302-313`（`findReusableStaleLocalBook`：`if (fileName.isBlank()) return null; val existingBook = appDb.bookDao.getBookByFileName(fileName) ?: return null; return planLocalBookImportReuse(existingBook, isBookFileReadable(existingBook), fileName, importedBookUrl)`）、`:319-324`（`isBookFileReadable`：`val stream = book.bookUrl.parseToUri().inputStream(appCtx).getOrNull() ?: return false; stream.use { }; return true`，注释说明刻意不做 `getLocalUri` 兜底搜索——探测不应有副作用）、`:328-345`（`rebindLocalBook`：`deleteBook(oldBook, false)` → `oldBook.copy(bookUrl = newBookUrl, originName = fileName)` → `latestChapterTime = 0` → `upBookInfo`/`upKind` → `appDb.runInTransaction { bookChapterDao.delByBook(oldBook.bookUrl); bookDao.replace(oldBook, reboundBook); BookHelp.updateCacheFolder(oldBook, reboundBook) }` → 两侧 `removeLocalUriCache()`）  |  无（本地无接回逻辑，缺正文记录只能靠用户手动移出）  | 未接 |  上游有**三个前提**才接回：①旧记录的文件确实读不到（`isBookFileReadable` 为 false）②文件名完全相同 ③来源是普通本地文件（非压缩包、非 webDav）。三个都满足才改 `bookUrl` 保留分组与阅读进度。本地没有这一层：文件被删后记录留在书架上（`isBodyMissing` 判定为「缺正文」），重新导入同名文件时被 `format+title+author` 判重挡下，提示「书架中已有同名缺正文记录，请先移出该记录再导入正文」——**要用户手动移出再导入，且移出即丢分组与进度**。屏幕现象：上游重新导入后书直接能读、进度还在；本地必须先移出（进度清零）再导入。  |  删掉正文文件 → 重启看到「缺正文」标记 → 重新导入同名文件，看能否直接恢复阅读且进度还在  |  依据源码推断，未设备验证。本地提示语见 `Index.ets:5613-5615`，是**已知的替代方案**而非等价实现 ；**要接**：接回需三个前提（旧文件读不到、文件名相同、来源为普通本地文件）；本地现为一律不接回，补判据与记录迁移 |  `localBook`  |
|  接回判据 `planLocalBookImportReuse`：四条否决（无旧记录 / 同路径 / 旧文件仍可读 / 文件名不同或不满足本地来源），全部通过才复用  |  `model/localBook/LocalBookImportPlanner.kt:24-35`（`val book = existingBook ?: return null; if (book.bookUrl == importedBookUrl) return null; if (existingFileReadable) return null; if (!book.matchesImportedFile(importedFileName)) return null; return book`）、`:37-42`（`private fun Book.matchesImportedFile(importedFileName: String) = isLocal && !isArchive && origin == BookType.localTag && originName.isNotBlank() && originName == importedFileName`）、文件头注释 `:16-20` 三条不复用理由  |  无  | 未接 |  这是上一行的判据本体，单列是为了让「什么时候**不该**接回」也有据可查：旧文件仍可读时不接回（用户确实另有一份同名文件，两份各自成书）；压缩包与 webDav 来源不接回（文件可重新解压/下载，「当前读不到」不代表记录失效）。本地完全没有这层判断——**本地是「一律不接回」**，所以不会误接，但也接不回来。  |  造两个同名文件 A、B（都在），导入 A 后再导入 B，确认变成两条而不是接回  |  依据源码推断，未设备验证。本行是本块唯一「上游有明确否决条件」的行，实现时照抄这四条即可 ；**要接**：接回需三个前提（旧文件读不到、文件名相同、来源为普通本地文件）；本地现为一律不接回，补判据与记录迁移 |  `localBook`  |
| 重复导入同一文件时的提示：**无提示**，静默走更新分支 | `model/localBook/LocalBook.kt:280-289`（更新分支无任何 Toast/提示，直接 `update` 后 `return book`）、`ui/book/import/local/ImportBookViewModel.kt:584-595`（`importPickedBookFiles` 无论新旧一律 `ShowToast("添加书架成功")`） | `entry/src/main/ets/pages/Index.ets:5630-5632`（更新分支末尾 `this.showUnavailableAction(\`这本书之前导入过，已更新《${updatedBook.title}》的目录\`)`） | 已接 | 上游更新分支自身不出提示、由 `ImportBookViewModel` 统一提示「添加书架成功」；本地在更新分支显式提示「这本书之前导入过，已更新《X》的目录」——两者都是「导入成功、且对同一本书做的是更新」，差别只在文案（本地更明确）。屏幕现象：同一个 TXT 连续导入两次，第二次书架条数不变、书仍能正常打开；旧实现在这里提示「这本书已在书架中」并 `discardImportedCopy()` 把副本删掉。 | 同一个 TXT 连续导入两次，看第二次的提示与书架条数 | 依据源码 + 设备验证（r328）。判据是「走更新而不是拒绝」，文案差异已记在此列 | `localBook` |
|  多选导入：一次选多个文件，逐个导入，**部分失败不打断、只有全部失败才报错**  |  `ui/book/import/local/ImportBookScreen.kt:258-267`（`val selectBookFiles = rememberLauncherForActivityResult(contract = ActivityResultContracts.OpenMultipleDocuments()) { uris -> viewModel.dispatch(ImportBookIntent.BookFilesPicked(uris)) }`）、`:332-341`（MIME 白名单 `text/plain`/`application/epub+zip`/`application/pdf`/`application/x-mobipocket-ebook`/`application/vnd.amazon.ebook`/`application/zip`/`application/x-rar-compressed`/`application/x-7z-compressed`/`application/octet-stream`）、`model/localBook/LocalBook.kt:427-441`（`fun importFiles(uris: List<Uri>) { var errorCount = 0; uris.forEach { uri -> ... kotlin.runCatching { importFiles(uri) }.onFailure { AppLog.put(...); errorCount += 1 } }; if (errorCount == uris.size) { throw NoStackTraceException("ImportFiles Error:\nAll input files occur error") } }`）  |  `entry/src/main/ets/data/BookRepository.ets:428-435`（`const options = new picker.DocumentSelectOptions(); options.fileSuffixFilters = ['TXT 文本\|.txt', 'EPUB 电子书\|.epub']; options.maxSelectNumber = 1;`）  | 未接 |  上游 `OpenMultipleDocuments` 一次可选任意多个文件，`importFiles(uris)` 串行逐个导入，中间某个失败只记日志继续，全部失败才抛；本地 `maxSelectNumber = 1`，**一次只能选一个文件**，且只支持 TXT 与 EPUB 两种后缀（上游还支持 PDF/MOBI/AZW3/ZIP/RAR/7Z）。屏幕现象：本地导入入口点开系统选择器只能选一个文件；上游可以框选一批。  |  点导入后尝试在系统选择器里多选两个文件  |  依据源码推断，未设备验证。本地无「导入页」这个界面（只有书架的导入按钮直开系统选择器），所以也没有上游那套 `selectedIds`/`SelectAll`/`SelectInvert` 多选工具条 ；**要接**：maxSelectNumber 改 0（不限）并串行导入、部分失败不打断；同时放开 PDF/MOBI/AZW3/ZIP 后缀 |  `localBook`  |
|  导入页「已上架」标记：列表里每本书标出是否已在书架，已上架的不能再加  |  `model/localBook/LocalBook.kt:568-572`（`fun isOnBookShelf(fileName: String): Boolean = appDb.bookDao.hasFile(fileName)`）、`data/dao/BookDao.kt:805-809`（`@Query("select count(*) > 0 from books where originName = :fileName or (origin != :localTag and origin like '%' \|\| :fileName)")`）、`ui/book/import/local/ImportBook.kt:8`（`val isOnBookShelf: Boolean`）、`ImportBookViewModel.kt:602-603`（`if (item.isDir \|\| item.isOnBookShelf) return`）  |  无（本地无导入页，无「已上架」标记）  | 未接 |  上游的导入页是一个**浏览文件夹的列表页**：显示目录里的每个文件、标出哪个已上架、支持多选与批量添加。本地是「点导入 → 系统选择器 → 直接进书架」一步到位，没有中间列表页，所以既没有「已上架」标记也没有「先看再选」的机会。屏幕现象：本地导入前无法知道这本书是不是已经在书架上。  |  点导入，看是否有中间列表页并标出已上架的书  |  依据源码推断，未设备验证。判 `未接` 是因为**整个界面缺失**，不是某个字段缺失 ；**要接**：需先有导入中间页（浏览目录 + 已上架标记 + 批量添加） |  `localBook`  |
|  书名/作者从文件名解析：用户脚本规则 → 内置 `nameAuthorPatterns` 正则 → `BookHelp.formatBookName`/`formatBookAuthor` 兜底  |  `model/localBook/LocalBook.kt:446-480`（`private fun analyzeNameAuthor(fileName: String): Pair<String, String>`：`:450-467` 跑用户脚本 `bookImportFileName` 并捕获 `author`/`name`，`:469-478` 逐个 `nameAuthorPatterns` 正则匹配，`:479-480` 兜底 `name = BookHelp.formatBookName(tempFileName); author = BookHelp.formatBookAuthor(tempFileName.replace(name, ""))`）、调用点 `:267-279`  |  `entry/src/main/ets/data/BookRepository.ets:2377-2383`（`private static getTitle(fileName: string): string { const lowerName = fileName.toLowerCase(); if (lowerName.endsWith('.txt')) { return fileName.substring(0, fileName.length - 4); } return fileName.length > 0 ? fileName : '本地书籍'; }`）—— **作者恒为空串**  | 未接 |  上游能从 `《斗破苍穹》作者：天蚕土豆.txt` 这类文件名里解析出书名与作者，解析规则还包括用户自定义脚本；本地只是把 `.txt` 后缀去掉，**作者永远是空**。屏幕现象：导入 `某某书 作者名.txt`，上游书架显示「某某书 / 作者名」，本地显示「某某书 作者名 / 未知」。这也是上一条判重键失效的**上游原因**——本地 `author` 恒空，`format+title+author` 三元组里有一元恒为空。  |  导入一个文件名带「作者：」的书，看书架上的作者字段  |  依据源码推断，未设备验证。与 A1 的「作者行显示」不重复：那行盘**显示**，本行盘**从哪来** ；**要接**：getTitle 只去后缀、作者恒空；补 nameAuthorPatterns 与 formatBookAuthor/formatBookName |  `localBook`  |

### 这一块与其余五块的边界

- **属本块**：一本书从「用户在系统选择器里选了文件」到「书架多了一条记录」之间的全部判断——判重键、接回、提示文案、多选批量、文件名解析。
- **不属本块，仍在 A1**：书架主屏上那条卡片长什么样、点了之后去哪。
- **不属本块，仍在 B**：详情页的元数据编辑（书名/作者可以在详情页手改，那是 B 块的事）。
- **不属本块，仍在 E**：`bookshelf.json` 恢复时的本地书重定位（`BookRestorePlanner` 的 `isRelocatedCopyOf` 与三态定位）——那条链路是「从备份 ZIP 恢复」，本块是「从文件选择器导入」，两者判据不同（E 块按 `bookUrl` + 文件名 + 书名作者三重比对，本块按 `bookUrl`）。
- **也不属本块**：导入时选 TXT 章节正则（`Book.tocRule`）——那是目录规则，见 [TXT-READER.md](TXT-READER.md) A2 块。

## 小结

**全表合计 345 条：已接 199、未接 141、不适用 5，无 `待定`。**（A1 78 + A2 47 + A3 22 + B 80 + C 39 + D 53 + E 19 + F 7）未接 141 行按备注列分：`**要接**` 132 行、`**不接**` 9 行，逐行判断见上一节。

按 `ZIP 类别` 列汇总（含跨类重复计数）：`localBook` 105 行、`—` 101 行、`bookshelfLayout` 53 行、`bookGroup` 38 行、`readRecord` 32 行、`bookSource` 24 行、`不备份` 7 行、`keyboardAssists` 6 行、`tagGroupRule` 4 行、`readConfig` 2 行、`threadCount` 1 行、`highlightTagRule` 1 行。E 块 19 行里 12 行落 `—`（备份流程本身不受任何类别的忽略开关控制）、1 行落 `localBook`（`:512` 本地书恢复期冲突规划）、6 行落 `keyboardAssists`（`:513`-`:518`），F 块 7 行全部落 `localBook`。**28 类里有 18 类在本表零行**（`bookmark`、`rssSource`、`rssStar`、`sourceSub`、`homepageModules`、`homepageCustomSets`、`server`、`httpTTS`、`dictRule`、`highlightRule`、`themeMode`、`themeConfig`、`coverConfig`、`showRss`、`mangaConfig`、`txtTocRule`、`replaceRule`、`searchHistory`），其中 `bookmark` 归 [书签对照](ZIP-BOOKMARK.md)、`themeConfig` 归 [阅读配置总账](READER-CONFIG.md)，其余归 [ZIP 兼容总账](STATUS.md) 的对应行。

分块口径：A1 78 + A2 47 + A3 22 + B 80 + C 39 + D 53（D 块总述 1 + D1 6 + D2 13 + D3 29 + D4 4）+ E 19 + **F 7（r323 新增，全部 `未接`）** = 345。逐块状态见 `## 盘面`。

五处需要特别注意：

1. **两个「已接」是字段级而非行为级。** 分组的下拉刷新（`pages/BookshelfPage.ets:339-346`）与私有分组（`:348-355`）能存能读，但代码注释自己写明「当前不控制实际更新」「当前不限制跨分组显示」。行为补全牵动 A1 的私密锁定与批量刷新（`:150` `:151` `:257`），不能只当字段活干。

2. **详情页第一张动作卡文案与行为不符。** 上游是「加入书架 / 已在书架」的切换（`BookInfoScreen.kt:1390-1485`），本地 `pages/BookInfoPage.ets:190-194` 文案写「已在书架」但点击直接移出，且无「加入」路径——因为本地详情页只能从书架进入。补这条要先有「从搜索/发现进详情」的入口。

3. **卡片展示的真空洞比原来小得多。** 本条原写「A1 的 63 条未接里有 22 条是卡片上的文字」，r340 逐行复核后，其中书名居中/小字号、列表分割线/背景色/封面居中/紧凑、简介两位置、作者行、当前章描述、封面宽度 10 条已改判 `已接`（见上一节）。**真正还缺的是要新数据的 8 条**（未读数、更新红点、更新中、书籍类型、来源标签、自定义标签、最后更新时间、字数、等待更新），它们统一卡在 `model/Book.ets` 缺 `totalChapterNum`、`latestChapterTitle`、`isNew` 一类字段上，补字段后一批就能推进。

4. **「可点的文字」是二轮补漏的主线。** 详情页头部的书名、作者、来源三行在本地都是纯 `Text`，上游每行都有单击与长按两个动作（`BookInfoScreen.kt:1298-1339`）。加上封面点击/长按、分组标签点击、简介内按钮与图片点击，B 区有 12 条差异都源于「本地没有可交互元素」这一类，不是缺数据而是缺交互。r340 复核后这批落在 `**要接**` 的第 7 批（`:296`–`:305`）。

5. **结构性缺口只剩一处。** 原文写「两处」，其中 `bookGroupStyle` 第三档「文件夹」r340 复核确认已接（`model/BookshelfLayout.ets:98-102` 三项齐全 + `pages/BookshelfPage.ets:1118`/`:1142` 两处分支 + `components/BookGroupCard.ets` 四宫格），只剩**私密体系**没做：分组私有（字段在、行为无）+ 书籍私有（`model/Book.ets` 连字段都没有）+ 解锁页 + 锁定页，牵动 `:150` `:151` `:257` `:294` `:325` 五行。

建议顺序已换成上面 `r340 复核结论` 里的 13 批。原文那串顺序（先补字段 → 卡片 22 条 → 顶栏 8 条 → 文件夹第三档 → 选择模式 → 详情页…）写在 r280，其中「文件夹第三档」已接、卡片若干条已接、顶栏是 8 条不是现在的 13 条，不再作为施工依据。**当前以 13 批为准**：批 1/4/5/6/10/11/12 无前置依赖可开工，批 2/3 等 `model/Book.ets` 补字段，批 8 等磁盘章节缓存表，批 9 是整页新建，批 13 等在线书源模块。

## r340 复核结论

上面 211 行 `未接` 已逐行复核（取证材料 19,774 行：每行带上游原文、本地 `文件:行`、「定义处 / 消费处」两处行号）。复核结论落在三处：**改判 `已接`** 的写进「差异说明」末尾加「验收方式」的屏幕现象；**判 `不适用`** 的写进「差异说明」末尾并把「验收方式」改 `—`；**维持 `未接`** 的在「备注」列写 `**要接**：<理由>` 或 `**不接**：<理由>`。块划分、行数、ZIP 类别列都没动。

结果：**改判 `已接` 26 行、判 `不适用` 5 行（其中 2 行本轮新增）、维持 `未接` 183 行**（`**不接**` 9 行、`**要接**` 174 行）。

### 一、改判 `已接` 的 26 行

这 26 行都是同一个模式：表里写「本地没有」，实际代码里「面板控件 + 渲染消费」两处都齐。表里的断言写于 r277–r280 的迁移前，之后补上了但没回填。

| 块 | 行 | 能力 | 证据（定义处 → 消费处） |
| --- | --- | --- | --- |
| A1 | `:81` | 搜索按钮长按切换为筛选 | `pages/BookshelfPage.ets:1078-1094` 的 `.onClick` 与 `.priorityGesture(LongPressGesture({ duration: 500 }))` 按 `bookshelfSearchActionDirectToSearch` 互换 |
| A1 | `:103` | 分组样式三档 | `model/BookshelfLayout.ets:98-102` 三项齐全 → `pages/BookshelfPage.ets:829` |
| A1 | `:104` | 文件夹根视图 | `pages/BookshelfPage.ets:1118`、`:1127`、`:1142` 三处 `bookGroupStyle === 2` 分支 |
| A1 | `:105` | 文件夹四宫格预览 | `components/BookGroupCard.ets:22` `@Prop coverCount` → `:51-70` 四图分支 |
| A1 | `:109` | 卡片副标题作者行 | `pages/BookshelfPage.ets:1263` 非紧凑模式渲染 `book.author` |
| A1 | `:111` | 列表卡片当前章 | `pages/BookshelfPage.ets:1197` 渲染 `book.lastChapter` |
| A1 | `:116` | 网格封面宽度可调 | 面板 `pages/BookshelfPage.ets:1003` → 渲染 `:1240` |
| A1 | `:117` | 列表封面宽度可调 | 面板 `pages/BookshelfPage.ets:1006` → 渲染 `:1179-1180` |
| A1 | `:125` | 列表模式简介 | `pages/BookshelfPage.ets:569` `showsListDetails()` → `:1185-1193` |
| A1 | `:126` | 简介在书名下方 | `pages/BookshelfPage.ets:1209-1214` |
| A1 | `:131` | 书名居中 | `pages/BookshelfPage.ets:1191`、`:1261` |
| A1 | `:133` | 书名小字号 | `pages/BookshelfPage.ets:684` `bookshelfTitleFontSize()` |
| A1 | `:134` | 列表分割线 | `pages/BookshelfPage.ets:1214-1218` |
| A1 | `:135` | 列表卡片背景色日夜两套 | `pages/BookshelfPage.ets:689-693` → `:1272` |
| A1 | `:136` | 列表封面垂直居中 | `pages/BookshelfPage.ets:1205` |
| A1 | `:137` | 紧凑模式 | `pages/BookshelfPage.ets:569` |
| A1 | `:139` | 快速滚动条 | `pages/BookshelfPage.ets:1290` 按开关切 `BarState` |
| A1 | `:153` | 搜索无结果时的全局搜索按钮 | `pages/BookshelfPage.ets:1319-1328` |
| A1 | `:155` | 横竖屏分别布局 | `pages/BookshelfPage.ets:551`–`:615` 六个 `active*` 方法全按 `isLandscape` 分叉 |
| A3 | `:256` | 分组四宫格预览 | 同 `:105`，`pages/BookshelfPage.ets:1150` 传 `bookshelfGroupCoverCount` |
| E | `:501` | WebDAV 五项输入 | `pages/AppBackupSettingsPage.ets:288-293` 五项各自落盘 → `lib/WebDavConfig.ets` |
| E | `:503` | 测试同步 | `pages/AppBackupSettingsPage.ets:107` → `pages/Index.ets:5391` `testWebDav()` 真连 |
| E | `:506` | 备份到 WebDAV | `pages/AppBackupSettingsPage.ets:259` 直调 `backupToWebDav()` |
| E | `:507` | 从 WebDAV 恢复 | `pages/AppBackupSettingsPage.ets:269` 直调 `restoreFromWebDav()` |
| E | `:513` | 备份排除项含 keyboardAssists | `data/BackupRepository.ets:614` 条目注册 |
| E | `:514` | keyboardAssists 走白名单 | `data/BackupRepository.ets:587` `fileNames` 白名单 |

> A1 `:109`、`:111` 两条在旧表里写「卡片只有书名」，实测 `pages/BookshelfPage.ets:1197`/`:1263` 都渲染了；`components/BookCard.ets`（53 行）是另一处未被使用的旧组件，别拿它当证据。

### 二、判 `不适用` 的 5 行

| 块 | 行 | 能力 | 四类证据 |
| --- | --- | --- | --- |
| A3 | `:239` | AI 自动分组 | **范围之外**：AI 在线服务在 `docs/PROJECT.md:48` 明列为范围之外 |
| B | `:346` | 简介内嵌 JS | **平台无此能力**：鸿蒙无内置脚本引擎，引入第三方引擎越过零依赖与安全边界（备份里的脚本按不可信数据处理，见 `docs/PROJECT.md:33`） |
| C | `:391` | 总览·日历日详情 | 原有 `不适用`，本轮未改 |
| E | `:508` | 备份 ZIP 预览 | 原有 `不适用`，本轮未改 |
| E | `:516` | keyboardAssists 表的读者 | 原有 `不适用`，本轮未改 |

### 三、判 `**不接**` 的 9 行

状态仍是 `未接`（三值里没有「不接」），只是决定不做，理由写进备注列：

| 块 | 行 | 能力 | 理由 |
| --- | --- | --- | --- |
| A1 | `:85` | 标题加载中字符闪烁 | 纯装饰动效。本地首屏不依赖网络，加载通常一两帧内完成，没有可提示的等待 |
| B | `:320` | 角色卡 | 靠书籍内容分析生成，生成侧属范围外的 AI 服务；本地无角色实体与消费方 |
| B | `:321` | 角色关系网 | 依赖角色卡与 AI 关系抽取 |
| B | `:322` | 知识卡 | 依赖 AI 生成，本地无实体、无生成链路 |
| B | `:323` | 事件卡 | 同 `:322` |
| B | `:335` | 知识卡编辑面板 | 依赖知识卡实体，随 `:322` 一并搁置 |
| E | `:502` | WebDAV 账号密码对话框 | 本地把账号与密码拆成两行、各自弹输入框、各自落盘（`pages/AppBackupSettingsPage.ets:288-293`）；与上游单对话框两字段等效，只差形态 |
| E | `:517` | keyboardAssists 恢复落地方式 | 本地无该表，恢复时没有原生仓储可落；该类条目走 `data/BackupRepository.ets:1482` 兜底留在 `android-backup-entries/`，是本地唯一可行的落法 |
| E | `:518` | keyboardAssists 备份写出方式 | 本地无该表数据源，写出侧只有保留目录原样拷贝 |

### 四、`**要接**` 的 174 行按依赖分批

分批只解决「先做哪几行」。每行该不该做已经定死在备注列，不需要再做判断。

| 批 | 行数 | 行号 | 依赖 / 说明 |
| --- | --- | --- | --- |
| 1 顶栏与纯 UI 入口 | 13 | `:82`–`:84` `:86` `:95`–`:99` `:101` `:222` `:252` `:255` | 无数据依赖：顶栏标题分支与副标题、五个菜单项、页签栏菜单按钮、删除分组二次确认、分组行书籍数。**实现（r341）**：本批实际交付 11 行，`:95` 选择模式留批 5、`:96` 书架管理留批 9；标题 `(N)` 尾巴因本地无待更新队列未接（见 `:83` 差异说明） |
| 2 Book 补字段后落卡片 | 22 | `:110` `:112` `:118`–`:121` `:123` `:124` `:127`–`:130` `:187` `:208` `:209` `:214`–`:219` `:223` | 先在 model/Book.ets 补 totalChapterNum、latestChapterTitle、isNew；未读数可由 chapterCount - chapterIndex - 1 推导。**实现（r341）**：本批实际交付 24 行（22 行清单 + `:224`–`:226` 随 `:209` 三复选一次做完）；`:124` 按 customTagColors 取色顺延批 3（与 `:210` / `:211` 一起做）；`:130` 表描述更正为标题级 (N)，本地无待更新队列故 (N) 尾巴随在线书源模块（见 `:83`） |
| 3 标签体系 | 5 | `:210` `:211` `:224`–`:226` | 新增 customTagColors 字段 + 配色管理页 + 标签行取色；自定义标签数据已有、渲染侧零消费。**调整（r341）**：`:224`–`:226` 已随批 2 的 `:209` 三复选对话框一次做完（本批不再做），批 3 实际只剩 `:210` `:211` 两行 + 认领从批 2 顺延的 `:124`（标签行按 customTagColors 取色，见 `:124` 差异说明的顺延标注）。**实现（r341）**：本批实际交付 3 行（`:210` `:211` `:124`）；`:224`–`:226` 已在批 2 做完；新增 TagColorPair/parseTagColors 数据层、lib/TagColorUtils.ets（HSL↔ARGB 与背景推导）、配色管理子页（生成/添加/编辑/删除/取色）与标签行按索引取模取色；config.xml 写出并读回 customTagColors / enableCustomTagColors |
| 4 标签匹配规则面板 | 4 | `:240` `:241` `:249` `:250` | tag_group_rules 表与 TagGroupRuleRepository/Importer 都已在，只缺分组管理面板里的编辑控件。**实现（r341）**：本批实际交付 4 行（全改已接）；新建 `entry/src/main/ets/data/TagGroupRuleSync.ets`（掩码用加法不用位运算、只加不减；所有规则读点显式 `await TagGroupRuleRepository.load(context)`，因启动 restoreStartupState 不 load、getAll() 缓存恒空），BookshelfPage.ets 分组管理顶栏三项菜单 + 分组编辑面板规则开关/多行输入/复制粘贴/正则前置拦截 + Index.ets 重命名改规则名、删除分组联动删规则、同步回调；`:240` 未做独立规则编辑面板（由分组编辑面板内开关承担）；上机验收 10 点全部实测通过，备份 ZIP 的 tagGroupRule.json 与规则表一致 |
| 5 选择模式、拖拽与动作 | 15 | `:87` `:106` `:107` `:113` `:114` `:138` `:142`–`:144` `:146`–`:151` | books 表已有 order 列支撑拖拽重排；全选/反选依赖选中集合 |
| 6 私密体系 | 3 | `:257` `:294` `:325` | books 表需加 isPrivate 列（现只有 book_groups 有）；详情页加设为私密与锁定内容页 |
| 7 详情页交互与本地动作 | 35 | `:273` `:274` `:277`–`:280` `:284` `:287`–`:293` `:296`–`:299` `:301`–`:303` `:305` `:313`–`:315` `:332` `:337`–`:344` `:350` | 头部文本行加点击/长按、菜单动作、简介三种标记解析、编辑面板、在线换封面 |
| 8 缓存管理页 | 16 | `:419` `:421` `:422` `:429`–`:441` | 前置：先落磁盘章节缓存表。现有 data/BookRepository.ets:140 的 chapterCache 是内存 Map，重启即空 |
| 9 书架管理页整页 | 31 | `:447`–`:475` `:482` `:484` | 按上游 BookshelfManageScreen 建页；入口已在 pages/BookshelfPage.ets:594-595 |
| 10 导入判重与多选 | 5 | `:551` `:552` `:554`–`:556` | data/BookRepository.ets:428-435 的 maxSelectNumber = 1 是硬卡点；导入页需先建中间页 |
| 11 阅读记录与备份开关 | 5 | `:394` `:504` `:505` `:510` `:511` | 章名字段直接补；进度同步与自动检查需后台任务；旧版数据要旧格式 JSON 解析器 |
| 12 性能 | 2 | `:154` `:156` | ForEach 改 LazyForEach + cachedCount；加载态用现有 LoadingProgress |
| 13 随在线书源模块 | 18 | `:89` `:94` `:122` `:145` `:275` `:283` `:285` `:286` `:307` `:317`–`:319` `:324` `:345` `:347`–`:349` `:515` | 书源已纳入范围但未排期（docs/PROJECT.md:24-44）。:145 批量下载即批量缓存在线章节，同批 |

批 1–12 合计 **156 行**，批 13 的 18 行等书源模块（书源已纳入范围但未排期，见 `docs/PROJECT.md:24-44`）。

---

## 覆盖证明

本表对应四类 ZIP 类别（`localBook` **31** / `bookGroup` 41 / `readRecord` 64 / `bookshelfLayout` 10）。四类关键词并集按 [KEYWORDS.md](KEYWORDS.md) 检索出 **117 个上游 `.kt` 文件**（r323 给 `localBook` 补 `LocalBookImport` 一词后，`localBook` 接触面 29 → 31，多出 `model/localBook/LocalBook.kt` 与 `model/localBook/LocalBookImportPlanner.kt`），本节把它们逐个分配：要么落到上面某个块的具体行，要么写明排除理由。判定可复跑：

```bash
bash scripts/upstream-surface.sh --coverage localBook docs/parity/BOOKSHELF.md <上游根>
bash scripts/upstream-surface.sh --coverage bookGroup docs/parity/BOOKSHELF.md <上游根>
bash scripts/upstream-surface.sh --coverage readRecord docs/parity/BOOKSHELF.md <上游根>
bash scripts/upstream-surface.sh --coverage bookshelfLayout docs/parity/BOOKSHELF.md <上游根>
```

（`<上游根>` 指法见 [KEYWORDS.md](KEYWORDS.md) 的用法节。脚本按「基名在表格中出现」判定已分配，所以本节既是记录也是判据。四类分别跑完，每条都不再留未分配。）

### 一、映射到上面某个块的行（29 个）

| 上游文件 | 命中内容 | 落到哪一行 |
| --- | --- | --- |
| `ui/book/cache/manage/BookCacheManageScreen.kt` | 685 行界面 | D1 全部 7 行、D2 全部 13 行 |
| `ui/book/cache/manage/BookCacheManageViewModel.kt` | 状态与选择模式 | D2「长按卡片进选择」 |
| `ui/book/manage/BookshelfManageScreenViewModel.kt` | 1136 行状态机 | D3「整个页面」及其后 24 行 |
| `data/repository/BookCacheManageRepository.kt` | `flowSelectableGroups()`（`:22`） | D1「分组筛选菜单」；缓存数据源 |
| `data/repository/BookCacheCleanupRepository.kt` | `:3`/`:8` 调 `bookDao` | D2「卡片删除缓存按钮」 |
| `data/repository/CacheBookDownloadRepository.kt` | `:3`/`:12` 缓存下载 | D2「卡片下载/停止按钮」 |
| `data/repository/BookshelfSettingsRepository.kt` | `:56-60` 五个 `bookshelfLayout*` 键 | A2 布局设置类各行 |
| `ui/config/bookshelfConfig/BookshelfManageScreenConfig.kt` | 20 行布局配置 | A2 布局设置类各行 |
| `help/config/AppConfig.kt` | `:89-90` `bookshelfLayoutModePortrait`/`Landscape` | A2「布局模式」 |
| `constant/PreferKey.kt` | `:57-58` 两个 bookshelfLayout 键 | A2「布局模式」 |
| `utils/ContextExtensions.kt` | `:465-467` `val Context.bookshelfLayoutMode` | A2「布局模式」 |
| `ui/main/bookshelf/BookshelfUiState.kt` | 186 行主屏状态 | A1「书架主屏」整体 |
| `ui/main/bookshelf/BookshelfCoverPreloader.kt` | 288 行封面预加载 | A1 封面加载（无独立可见控件，属 A1 的封面渲染） |
| `ui/main/bookshelf/BookGroupUi.kt` | 27 行分组 UI 模型 | A3 分组列表渲染 |
| `ui/book/group/GroupViewModel.kt` | 140 行分组状态 | A3 分组管理 |
| `data/repository/BookGroupMutationRepository.kt` | 分组增删改 | A3（分组管理的写入侧） |
| `BookshelfAutoGroupRepository.kt` | `:48` `map(BookGroup::groupName)` | A3「AI 自动分组」 |
| `data/repository/PrivateContentRepository.kt` | `:3`/`:17` 私密内容 | A3 私密分组、B 私密书 |
| `ui/book/info/BookInfoRouteScreen.kt` | `:87-90` 私密解锁闸门、`:265` `runSourceCallback`、`:318` `runIntroJs` | B 块私密体系行、B 块回调/简介脚本行 |
| `help/storage/BackupConfig.kt` | `:77` `dbKeyBookGroup`、`:82` `dbKeyReadRecord` | 交叉引用的备份往返口径 |
| `help/storage/Restore.kt` | 恢复写入各表 | 交叉引用的备份往返口径 |
| `data/local/preferences/LocalPreferences.kt` | `:54` `ENABLE_READ_RECORD` | C 块阅读记录开关 |
| `ui/book/read/ReadRecordAliasDelegate.kt` | 全文件 104 行 | C 块 r286 新增的三行别名 |
| `ui/book/read/ReadBookLoadDelegate.kt` | `:94`/`:175` `checkReadRecordAlias` | C 块「未知作者记录归属检查」 |
| `ui/book/read/ReadBookContract.kt` | `:647`/`:649` 别名事件 | C 块「清除归属决定」 |
| `ui/book/read/ReadBookScreen.kt` | `:156-161` 别名弹窗 | C 块三行别名 |
| `ui/book/read/ReadBookViewModel.kt` | `:24`/`:154` 别名状态 | C 块三行别名 |
| `ui/book/readRecord/ReadRecordOverviewViewModel.kt` | 109 行总览页状态 | C 块「阅读记录总览页」 |
| `ui/book/readRecord/ReadRecordFormatter.kt` | `:6` 时长格式化 | C 块阅读时长显示 |

### 二、映射到导航与入口行（9 个）

| 上游文件 | 命中内容 | 落到哪一行 |
| --- | --- | --- |
| `ui/main/MainNavKey.kt` | `:139` `MainRouteReadRecord`、`:142` `MainRouteReadRecordOverview`、`:145` `MainRouteCache`、`:148` `MainRouteBookCacheManage` | C 块阅读记录入口、D1/D3 入口 |
| `ui/main/MainNavigator.kt` | `:332`/`:381` 导航注册 | 同上 |
| `ui/main/MainNavGraph.kt` | `:103-104` 图定义 | 同上 |
| `ui/main/MainScreen.kt` | `:169-170` 路由分发、`:652` `OpenBookCacheManage` | D4「从『我的』进缓存管理页」 |
| `ui/main/MainViewModel.kt` | `:86` 事件转发 | 同上 |
| `ui/main/MainContract.kt` | `:57` 事件定义 | 同上 |
| `ui/main/my/MyScreen.kt` | `:217` 阅读记录入口、`:221-226` 缓存管理入口 | D4「从『我的』进缓存管理页」、C 块阅读记录入口 |
| `ui/main/my/MyViewModel.kt` | `:29` `OpenReadRecord`、`:30` `OpenBookCacheManage` | 同上 |
| `ui/main/home/HomeScreen.kt` | `:153-154` 首页阅读记录入口 | C 块阅读记录入口 |

### 三、已排除：数据层接线，界面由上面各块承载（18 个）

不是界面，只是把 DAO 注进 Repository 再往上抛，功能本身已在前面的块里盘过。

`data/repository/BookRepository.kt`（`:6`/`:17` 纯 import）、`data/repository/LocalBookRepository.kt`、`data/repository/SearchRepository.kt`（`:123`/`:128` `searchBookDao`）、`data/repository/ExploreRepository.kt`（`:92`）、`data/repository/AiToolRepository.kt`、`data/repository/BookSourceCallbackRepository.kt`、`data/repository/BookDomainRepositoryImpl.kt`、`data/repository/HomeDashboardRepository.kt`（`:3`/`:13` `readRecordDao`）、`domain/repository/BookDomainRepository.kt`（`:10` `getBookGroupAssignments`）、`domain/gateway/BookGroupMutationGateway.kt`、`domain/usecase/BookMigration.kt`（`:66`）、`domain/usecase/ChangeBookSourceUseCase.kt`、`domain/usecase/ChangeSourceSearchUseCase.kt`（`:377`）、`domain/usecase/FindBookshelfConflictUseCase.kt`（`:17-18`）、`domain/usecase/RemoveBookGroupAssignmentUseCase.kt`（`:5`）、`domain/usecase/UpdateBooksGroupUseCase.kt`（`:15`/`:23`）、`di/appModule.kt`、`di/appDatabaseModule.kt`。

**排除理由**：这些文件的 `BookGroup` / `ReadRecord` 命中全部出现在函数签名、import 或依赖注入点，没有自己的界面。它们的行为在对应界面块里有行（换源在 B 块菜单动作、分组变更在 A3、阅读记录写入在 C）。

### 四、已排除：DAO 与数据库定义，无界面（8 个）

`data/AppDatabase.kt`（`:21-22` 实体注册）、`data/dao/BookDao.kt`（`:12`/`:37` `interface BookDao`）、`data/dao/BookGroupDao.kt`（`:9`/`:13`）、`data/dao/ReadRecordDao.kt`（`:10-11`）、`data/dao/SearchBookDao.kt`（`:12`）、`data/dao/RssArticleDao.kt`（`:23` SQL 里出现 `rssReadRecords`）、`data/dao/RssReadRecordDao.kt`（`:4`/`:7`）、`service/readaloud/ReadAloudBookSession.kt`（朗读会话，属朗读模块，不是书架界面）。

**排除理由**：Room DAO 只有方法签名与 SQL，本地对应物是 `data/*Repository.ets` 里的 relationalStore 调用，没有可以对盘的 UI。朗读会话属朗读功能，归 `httpTTS` 类别。

### 五、已排除：实体与领域模型，只是数据形状（13 个）

`data/entities/readRecord/ReadRecordAliasDecision.kt`（`:4-7` `enum class ReadRecordAliasAction { MERGE, KEEP }`）、`ReadRecordDetail.kt`、`ReadRecordSession.kt`、`ReadRecordIdentity.kt`、`ReadRecordTimeTotals.kt`、`ReadRecordTimelineDay.kt`、`ReadRecordRepairReport.kt`、`domain/model/BookGroupAssignment.kt`、`domain/model/BookGroupMutation.kt`（`NewBookGroup` / `BookGroupUpdate`）、`domain/model/BookMatchKey.kt`（`:3` 复用 `ReadRecordIdentity` 折叠空白）、`help/book/BookExtensions.kt`（`isEpub` / `isLocal` 之类的类型判断扩展）、`utils/RegexExtensions.kt`（`:36` 正则工具）、`feature/reader/core/navigation/ReaderPartialPagePolicy.kt`（`:7` 阅读器分页策略）。

**排除理由**：`data class` / `enum` / 工具扩展，字段形状已在卷首「上游表结构」与各块「差异说明」里体现（本地 `model/ReadRecord.ets`、`model/Book.ets`、`model/BookGroup` 系列逐字段对齐过），单独列行只是把字段再抄一遍。

### 六、已排除：关键词误命中，属别的类别（11 个）

RSS 侧 7 个：`ui/rss/article/RssSortRouteScreen.kt`、`ui/rss/article/RssSortScreen.kt`、`ui/rss/article/RssSortViewModel.kt`、`ui/rss/read/RssJsExtensions.kt`（`:158`）、`data/repository/RssReadRecordRepository.kt`、`data/entities/RssArticle.kt`（`:66`）、`data/entities/RssReadRecord.kt`（`:8-9`）。
另有 `data/entities/RssStar.kt`（`:58`）、`ui/association/AddToBookshelfDialog.kt`（182 行，网络书 URL 解析后加入书架，属书源/导入侧）、`data/repository/manga/MangaReaderDataRepository.kt`（`:8-9`，属漫画类别 `mangaConfig`）。

**排除理由**：前 8 个是 RSS 的排序与阅读记录，与本地书架无关（`readRecord` 关键词把 RSS 的 `rssReadRecords` 表一起捞进来了）；`AddToBookshelfDialog` 是「粘贴网址加书架」的独立弹窗，本地无对应，但它属于 `bookSource` / 导入流程，不在本表四类里；`MangaReaderDataRepository` 属漫画。

### 七、未分配

**0 个。** 115 个上游接触面文件全部分配完毕（映射到行 39 个 + 排除 76 个）。

---

## 交叉引用

- 总账入口：[`STATUS.md`](STATUS.md) 的 `localBook` 与 `bookGroup` 行
- 备份往返口径：`data/BackupRepository.ets:640`-`:644`（`bookshelf.json` 写出）、`:648`（`bookGroup.json`）、`:663`-`:680`（`config.xml` 无条件区）、`:682`-`:721`（`bookshelfLayout` 键组），恢复侧 `:1192`（`bookshelf.json`）、`:1222`（`bookGroup.json`）、`:1211`（`config.xml`）、`:1529`-`:1532`（`bookshelfLayout`）；`tagGroupRule.json` 已于 2026-11-09 接通具名读写（写出 `:782`-`:785`、恢复 `:1394`）
- 阅读配置对照：[`READER-CONFIG.md`](READER-CONFIG.md)
