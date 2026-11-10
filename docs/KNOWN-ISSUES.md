# 已知问题与验收边界

更新：2026-11-10。以下仅列出公开源码和 E 端记录能够支持的状态，不包含测试书名、个人文件名、设备地址、日志或截图。

## 发布版五条已知问题（r323，前四条已修、第五条未修）

0.1.0 开发预览发布时用户报了五条体验问题。发布当时代码一行未改；此后 KI-REL1 已在 r325、KI-REL2 在 r326、KI-REL3 在 r327、KI-REL4 在 r328 修复，**只剩 KI-REL5 未修**。派活时按编号引用，根因已在下面各条末尾给出行号，不要重新定位。

**KI-REL1 滚动阅读跳章闪烁** —— 换章时整章重新分页，重排期间画布空着。入口 `entry/src/main/ets/pages/ReaderPage.ets:1531 onReaderContentChanged()`（清 `localReaderPages` + `scrollOffset = 0` 后 `rebuildReaderPages()`），`:5706-5712` 注释说明照上游 `ReaderCanvasSurface.kt:254` 不用滚动兜底。补法：跨章增量追加，或重排期保留上一章尾页作过渡帧；**不要**改两套排版兜底。
> 已盘点，见 [TXT-READER.md](parity/TXT-READER.md) B8「跨章换页与页窗口拼接」第 222 行起（11 行，222–232；根因行 222）。上游那一层共 11 个能力，本地只接住 2 个（页窗口同步换装、四页纵向堆叠绘制）。
> **r325 已修（现象层）**：换章不再清空页表（`chapterHandoffPending` 保留上一章页作过渡帧）、向上翻章落章末（`chapterHandoffUpward`）、拖动到章末即换章（`PanGesture.onActionUpdate` 改用 `applyReaderScrollDelta` 的返回值 + `scrollDragBoundaryTurned` 防连跳）、换书作废交接标记（`chapterHandoffBookId`）、提示页只在真没有当前页时顶上（`appendBoundaryPlaceholders`）。设备验收见 [VALIDATION.md](VALIDATION.md)「r325 KI-REL1」节：分页模式第 2 章末换第 3 章无空窗，滚动模式两向换章均正常。**仍未做**：跨章滚动偏移延续（上游延续余量，本地归零）与「占位页装进页窗口」，故 B8 第 227/229 行状态仍为 `未接`。
> **页层批次 3（结构第一步，不改上面任何状态）**：上游跨章页表的根是 `ReaderPageId(chapterIndex, pageIndex)` 这个页身份，`ReaderPageNavigator.kt:32-33` 注释「Page-table insertions, removals and same-id replacements must not reuse an old index.」。本地 `LocalReaderPage`（`entry/src/main/ets/pages/LocalReaderPaginator.ets:82`）此前无显式身份、`currentPageIndex` 是纯数组下标。本批给它补两个可选字段 `chapterIndex` / `pageIndex`，`paginate()` 加可选末参 `chapterIndex = 0`（不动已有形参顺序）给每页填章内页号；新建 `entry/src/main/ets/reader/ReaderPageIdentity.ets` 只放纯函数 `rebasePageIndex(pages, prevChapterIndex, prevPageIndex): number`——按身份在新页表里重查下标，找不到返回 `-1`（对应上游 `.takeIf { it >= 0 }`）。本批页表仍单章、行为零变化；页表跨章、定位函数抽取留到页层批次 4。

**KI-REL2 标题与正文分离** —— 标题画在正文之外的独立 ArkUI 组件里，不是画布画的。`ReaderPage.ets:5712-5733` 的 `else if (currentPageIndex === 0)` 分支，`Canvas` 在其下；`ReaderCanvasSurface.ets` 全文只有 `:1129` 用到 `titleOnly`（算页高）。上游把标题当正文块流里的 `isTitle` 块（`ReaderChapterBlockMeasurer.kt:260-320`）。补法：标题作首行块交给画布，删画布外的标题分支与 `measureTitleReservedLines()`。

> **r326 已修**：标题已进排版流。`LocalReaderPaginator` 新增 `LocalReaderTitleBlock` / `LocalReaderTitleSegment`，`paginate()` 与 `countPagesIncrementally()` 各加第 15 参 `titleBlock`，`addTitleBlock()` 把标题段逐 cluster 折成带 `titleLine` / `titleAlign` / `titleFontScale` 的真实 `LocalReaderLine`，与正文共用 `appendLine`/`advanceColumn`/`flushPage`；`ReaderCanvasSurface.layoutPage()` 按 `titleAlign` 居中、按 `itemTextStyle()` 换标题样式、按 `page.centerVertical` 整页下移。三个派生条件逐条对齐上游：`centered = titleMode === 1 || isVolume || !hasBody || singleImage`、`pageBreakAfter = singleImage && hasBody`、`centerVertical = !hasBody || singleImage`（`LegacyReaderChapterPaginator.kt:291`、`:326`、`:321-325`）。画布外 `ReaderTitleSegments` 分支与 `measureTitleReservedLines()` 预留行数已从绘制路径摘除。设备验收见 [VALIDATION.md](VALIDATION.md)「r326 KI-REL2」节：分页模式标题与正文首行同屏连排、滚动模式标题随正文一起被裁、单图模式第 1 页纯标题页水平+垂直居中（18 页 = 1 标题页 + 17 正文页）。**仍未做**：标题折行仍是逐 cluster 硬切、不按词断行，故 B9 第 252 行仍为 `未接`（其余 9 行已改判 `已接`）。
> 已盘点，见 [TXT-READER.md](parity/TXT-READER.md) B9「标题块在排版流里」第 242 行起（10 行，242–251；结构根因行 242，行为偏差行 247）。`titlePageBreakAfter`/`titlePageCenterVertical` 不是用户开关，取值由「本章正文是否为空」×「是否单图模式」四种组合派生；本地只实现其中 D 一档（第 249 行）。

**KI-REL3 目录打开慢、滑动卡** —— 慢：`pages/CatalogPage.ets:85-92` 在 `showWordCount`（默认 true）时先 `loadChapterWordCounts()`（`:361-385`）整本逐章算字数。卡：`:578` 用 `ForEach` 而非 `LazyForEach`，`getChapters()`（`:127-159`）每帧全量重算。补法：关字数时不触发算字数、字数惰性/缓存、列表换 `LazyForEach`。

> **r327 已修**：三条一起改。①字数改读预存字段——`chapter.wordCount`（`BookRepository.buildChapterRows()` 在切章时由 `content.substring(charStart, charEnd).trim().length` + `wordCountFormat()` 写入，与上游 `TextFile.kt:317-325` 同口径），`loadChapterWordCounts()` / `wordCountsLoading` / `wordCountGeneration` / `formatWordCount()` 整块删除，「正在统计章节字数」中间态不再存在；②列表换 `LazyForEach` + 新增 `class CatalogChapterDataSource implements IDataSource`（`totalCount` / `getData` / 注册注销监听 / `setItems` 整批 `onDataReloaded()`），屏幕外的章节行不建子树；③派生结果缓存进 `@State chapterView`，由 `@Watch('onChapterViewInputChanged')` 挂在 `query` / `ascending` / `useTitleReplacement` / `collapsedVolumes` 上重算一次，`build()` 不再调 `getChapters()`。顺带把反序从「整个扁平数组翻转」改成按卷分组反转（`reverseTocHierarchy()`，卷标题仍排在子章之前）。设备验收见 [VALIDATION.md](VALIDATION.md)「r327 KI-REL3」节：进目录列表与字数同帧出现、状态行只有「正序/倒序」，滚动到第 11/12 章无白块，搜索「3」只剩「第3章(1)」。**仍未做**：多选次级菜单缺上游的「从最后起选」；反序的「卷名在子章之前」因测试书无分卷，缺屏幕证据，C5 对应行维持 `未接`。
> 已盘点，见 [TXT-READER.md](parity/TXT-READER.md) C5「目录页」第 326 行起（6 行，326–331）+ A4 第 119 行。上游字数是 `BookChapter.wordCount` 预存字段、目录页永不读正文（第 326 行）；列表 `FastScrollLazyColumn` 惰性 + 数据源 `flowOn(Dispatchers.Default)` 不逐帧重算（327/328 行）；反序在数据源层一次反转，本地在渲染期倒序复制导致卷名跑到子章后面（329 行，本轮唯一确定行为偏差）；多选缺「从最后起选」（330 行）。

**KI-REL4 同名同作者的第二本书加不进书架** —— `pages/Index.ets:5602-5617` 按 `format` + `title` + `author` 判重，上游 `model/localBook/LocalBook.kt:249 importFile(uri)` 按 `bookUrl` 判重（`:260-266` 另有失效记录接回）。补法：判重键改 `bookUrl`，再补接回分支。

> **r328 已修（判重键）**：把判重键换成 `bookUrl`，并让 `bookUrl` 真正由文件路径派生——`BookRepository.importLocalBook` 的正文文件名从 `local-${Date.now()}.txt` 改成 `local-${md5Encode16(uri)}.txt`（对齐上游 `LocalBook.kt:252-259` 的 `bookUrl = FileDoc.fromUri(uri).toString()`）。`Index.ets` 的判重整段重写：命中同一个 `contentPath` 时按上游 `:280-288` 走「更新」分支（书目行沿用原记录，只换 `chapterCount`/`lastChapter`/`tocRule`，`latestChapterTime = 0` 触发重新分页，`saveChapters` 整本重建目录），不再 `discardImportedCopy` + 拒绝；未命中才新增。设备验收见 [VALIDATION.md](VALIDATION.md)「r328 KI-REL4」节：书架 1 本 `the-metamorphosis` 时导入同名同作者的第二个 `the-metamorphosis.txt` → 变 2 本；紧接着再导入同一个文件 → 仍 2 本。**仍未做**：失效记录接回（`planLocalBookImportReuse` / `rebindLocalBook`，对照表 F 块第 2、3 行仍 `未接`）、多选导入、导入页「已上架」标记、从文件名解析作者。**迁移后果**：本改动前导入的书用时间戳命名，`bookUrl` 与新键对不上，那本同名书会被当成另一本书再新增一次。
> 已盘点，见 [BOOKSHELF.md](parity/BOOKSHELF.md) F「本地书导入与判重」第 533 行起（7 行，533–539；根因行 533）。上游四条链路四个判重键（`bookUrl` / `originName` / `hasFile` / `bookUrl`+`name+author`），本地只有第四种；另缺失效接回（534 行）、接回判据（535 行）、多选导入与「已上架」标记（537/538 行）、文件名解析书名作者（539 行——本地 `author` 恒空，是判重键失效的上游原因）。

**KI-REL5 浅色模式适配差** —— 深色模式的适配明显好于浅色，浅色模式配色未打磨。根因：r300–r317 的深色模式改造集中在夜间配色与主题包，日间配色基本沿用改造前的旧值，`entry/src/main/resources/base/element/color.json` 里的 `theme_*` 日间色没重新对齐上游浅色方案。补法：按上游 `ThemeConfigScreen.kt` 的浅色档逐项对齐日间色，与深色同一套 token。

## 书架与分组

- r250 的全局排序档位和分组 `bookSort` 覆盖逻辑已接入；E 端尚未使用多本书和多组分组逐档核对真实列表顺序。
- 书架布局九字段的 Android ZIP 差异值往返、外部 Android ZIP 分组导入导出尚未完成 E 端设备验收。
- r256 已验证隐藏页签后从分组管理切换到“本地未分组”并在冷启动后保留；没有自定义分组的设备场景未覆盖自定义筛选项。
- 分组卡片的拖拽排序、封面实际选择/冷启动读回仍未验。
- `isPrivate` 只保存兼容标记，不提供访问保护；`enableRefresh` 不控制分组更新。r257 已将这两项 UI 文案明确为未生效/未接入。

## Android ZIP 兼容

- r255 已在 E 端 HOS 模拟器验证 `readConfig × themeConfig` 两类别各自包含或忽略的四种组合，阅读设置与护眼六键按相应类别恢复或保留。
- `bookGroup.json` 的备份导出和恢复导入代码路径已接入；仍需验证外部 Android ZIP、冲突合并和完整设备往返。
- 书架布局类别已有九字段写入/恢复路径，但没有用九个不同哨兵值逐项验证。真实 Android ZIP 的完整兼容范围尚未验收。
- 阅读记录会话、按日明细和按书汇总已由原生本地仓储承载；Android ZIP 中的 `readRecord.json`、`readRecordDetail.json`、`readRecordSession.json` 仍仅作兼容归档保留，不导入原生阅读记录。
- ZIP 兼容不代表完整 Android 数据库迁移、跨类别事务回滚、凭据恢复或正文打包。
- `keyboardAssists`：本地无该表（`data/RdbSchema.ets` 20 张 `CREATE TABLE` 无此项，`allStatements` 亦未追加），恢复时该条目只进保留目录（主循环兜底 `data/BackupRepository.ets:1482`-`:1483`），备份时仅当保留目录存有副本才原样拷出（`copyPreservedEntries` `:2573`-`:2599`）。上游该表的业务消费方为零（`grep -rn 'keyboardAssistsDao' --include=*.kt app/src/main/java` 恰 4 行，全在备份/恢复与建表/DI）。忽略项一侧本地有效，但跳的是 ZIP 条目而非数据库行。

### 本地书籍行登记（BOOKSHELF.md 的 localBook 未接行）

本节登记 [书籍总账](parity/BOOKSHELF.md) 里 `localBook` 名下 **72 行 `未接`** 的「为什么不修」。编号 `KI-LB<n>` 与对照表「备注」列的标记一一对应。判定口径按 [PROJECT.md](PROJECT.md)：只有上游存在、且属于本地书籍这条链路的能力才补；依赖尚未迁移的体系或纯视觉差异的，登记不修。**2026-11-09 起 WebDAV 与在线书源已纳入范围（`PROJECT.md:24-44`，尚未排期）**，依赖它们的两类不再按「范围之外」处理，改为「要接，待排期」；仍在[范围之外](PROJECT.md)（`PROJECT.md:46-48`）的是 AI 在线服务、云同步与额外设备形态。

**KI-LB1 书架卡片信息行（16 行，属 bookshelfLayout 视觉差异，本轮不修）** —— 覆盖卡片副标题作者行、紧凑模式「作者 · N 未读」副标题、列表卡片描述行显示当前章、标题区未读徽标叠加更新图标、封面无障碍描述、未读章节数角标、更新小红点、更新中进度指示、书籍类型标签、来源标签（搜索模式）、自定义标签行、列表模式简介、最后更新时间、最新章节、字数统计、等待更新数。
上游 `ui/main/bookshelf/BookItem.kt:865`（`subTitle`）、`:870`（`desc`）、`:855-864`（`TextCard` 未读徽标）、`:754-765`（`bookTypeLabel`）、`:765-773`（`matchedSourceLabel`）、`:888`（`bookshelfShowTag`）、`:919`（`BookItemIntro`）、`:944-951`（最后更新时间）、`:952-959`（最新章节）、`:814`/`:838`（`accessibilityLabel`）；计数来源 `BookShelfItem.kt:48`（`isNew` = `lastCheckCount > 0`）、`:50`（`getUnreadChapterNum` = `max(totalChapterNum - durChapterIndex - 1, 0)`）；开关 `BookshelfConfigSheet.kt:511`（标签内容二级面板）、`:579`（等待更新数）、`:703`/`:734`（`bookshelfShowWordCount`）。
本地：`pages/BookshelfPage.ets:655-675` 的卡片只有 `BookCover` + 书名 `Text`，没有任何副标题/描述/徽标；`components/BookCover.ets:43-50` 的角标显示的是**总章数**，不是未读数。
为什么不修：这些全是书架卡片的**排版层**，改这一行动的是 `bookshelfLayout` 类别的键与视觉，不是 `localBook` 的数据映射，按本轮范围（不含 A1/A2 里属于 bookshelfLayout 的视觉差异）排除。另外 `unread`、`isNew`、`showTip`、`bookshelfShowWordCount`、`bookshelfShowTag` 在本地全仓命中为 0 或只有无关同名，要先补整套计数与开关才有显示对象，属于 `bookshelfLayout` 的独立排期。
补法：先补 `lastCheckCount` / `totalChapterNum` 的读出（见 KI-LB1 附注），再按 `bookshelfLayout` 单独立项做卡片信息行。

**KI-LB2 书架菜单与批量操作（9 行）** —— 覆盖更多菜单·添加网址、导出书单、导入书单、拖拽重排书架、移动到分组、批量私密标记、批量删除、删除时勾选删除源文件、私密分组锁定页。
上游：`ui/main/bookshelf/BookshelfScreen.kt:729`（添加网址）、`:756`（导出书单）、`:764`（导入书单）、`:1743-1748`/`:1795-1800`（`rememberReorderableLazyGridState` 拖拽）、`:643`（移动到分组）、`:655-668`（批量私密）、`:679`（批量删除）、`:1540-1572`/`:1552-1563`（删除时勾选删源文件）、`:1619-1646`（私密分组锁定页）。
本地：`pages/BookshelfPage.ets:590-599` 四个 `MenuItem` 全部走 `onUnavailableAction`（「网址导入尚未迁移」「书单导出尚未迁移」「书单导入尚未迁移」）；`批量` 全仓 0 命中；拖拽只实现在分组管理面板（`pages/BookshelfPage.ets:266` `.onMove`、`:274` `.editMode(true)`），书架网格没有 `onMove`。
为什么不修：网址导入与书单导入导出是**独立能力**（要解析 `bookshelf.json` 之外的书单格式），不是 `localBook` 备份链路的缺口；批量操作与私密体系都依赖 `Book.isPrivate`（本地只有分组级 `BookGroup.isPrivate`，语义不同，`pages/BookshelfPage.ets:257` 的文案已注明「私有标记未生效」）。
补法：书单导入导出与网址导入各自单独立项；私密体系要先把书级 `isPrivate` 从 `books` 表读出来（`data/BookRepository.ets:127-131` 的 `selectBooksSql` 目前不 SELECT 该列）。

**KI-LB3 详情页顶栏与更多菜单（10 行）** —— 覆盖顶栏更多菜单（18 项）及其中的上传书籍、同步到远端、禁用阅读记录、置顶、设置书籍变量、允许更新、长按分章、删除确认、设为私密。
上游：`ui/book/info/BookInfoScreen.kt:1033-1141`（更多菜单）、`ui/book/info/BookInfoContract.kt:376-396`（菜单项定义）。
本地：`pages/BookInfoPage.ets:268` 的 more 按钮直接 `onUnavailableAction('书籍更多操作尚未迁移')`，整组 18 项没有入口。
为什么不修：其中「上传书籍」「同步到远端」依赖 WebDAV（本表 E 块已登记 WebDAV 四行未接）；「禁用阅读记录」「允许更新」「设为私密」需要 `books` 表的 `disableReadRecord`/`canUpdate`/`isPrivate` 三列——DDL 里有（`data/RdbSchema.ets:253`、`:252`、`:91`），但 `data/BookRepository.ets:127-131` 的 `selectBooksSql` 只 SELECT 22 列、`:674-717` 的 `readBookRow` 也没读它们，属于「列在库里但读不出来」；「长按分章」需要 `splitLongChapter`，本地全仓 0 命中。
补法：先把上述三列加进 `selectBooksSql` 与 `readBookRow`，再逐项接菜单；`splitLongChapter` 要单独设计存储（上游内嵌在 `ReadConfig`）。

**KI-LB4 详情页头部与摘要（13 行）** —— 覆盖移出书架后「点击移出」提示、头部书名（含长按菜单）、头部作者行（点击/长按）、头部来源行、封面点击与长按、封面无障碍描述、加入书架（含冲突提示）、长按加入书架选分组、动作卡·换源、摘要·已读状态三分支、摘要·目录加载失败提示、摘要·备注卡片可点编辑、私密锁定内容页。
上游：`ui/book/info/BookInfoScreen.kt:1405-1416`/`:1425`（`click_to_remove`/`long_press_group` 两段轮播提示）、`:1298-1320`（书名 `AnimatedTextLine` + `combinedClickable`）、`:1326`（作者）、`:1335-1339`（来源行）、`:1144`（封面点击/长按）、`:1164`（封面无障碍）、`:1390-1485`（加入书架与冲突提示）、`:1533-1625`（摘要）、`:664`（私密锁定内容页）。
本地：`pages/BookInfoPage.ets:158-163` 书名/作者/来源全是纯 `Text`，无点击与长按；`:156` 封面不可点；`:188-192` 的动作卡是「移出书架」而非「加入书架」（本地只有书架内路径）；`:207-208` 只有「已读 N 章 / 未读」两分支，缺上游「已读完」第三分支（判定 `durChapterIndex + 1 == totalChapterNum`，需要 `totalChapterNum` 读出）；`:245-250` 备注只读无 `onClick`。
为什么不修：「加入书架/长按选分组」依赖搜索进详情的路径（本地还没有在线书源搜索）；「动作卡·换源」依赖书源体系；「私密锁定内容页」依赖 KI-LB2 的私密体系；其余是交互与无障碍细节，属独立排期。
补法：「已读三分支」可随 `totalChapterNum` 读出一起补；备注可点编辑可复用已有的元数据编辑面板。

**KI-LB5 详情页编辑与各类面板（11 行）** —— 覆盖编辑·标签编辑器、编辑·知识卡编辑、书架删除面板、书架删除面板·同名副本切换、书架删除面板·删除源文件勾选、面板·分组多选、面板·在线换封面、面板·网络文件选择、面板·压缩包条目选择、面板·不支持文件提示、目录选择（book tree uri）。
上游：`edit/BookInfoEditScreen.kt:435-517`（标签编辑器 `add_tag`/`edit_tag`/`reset`）、`:310-343`（知识卡）、`ShelfDeleteSheet.kt`（182 行，`:102-128` 同名副本切换、`:167-168` 删除源文件）、`BookInfoSheets.kt:109`（`GroupSelectSheet`）、`:194`（`ChangeCoverSheet`）、`:70`（`WebFileSheet`）、`BookInfoContract.kt` 的 `ArchiveEntries`/`UnsupportedWebFile`、`BookInfoScreen.kt:243`（`SetDefaultBookTreeUri`）。
本地：`pages/BookInfoPage.ets:350-353` 的自定义标签是逗号分隔单行 `TextInput`；`:324-338` 的分组多选塞在元数据编辑面板内（不是独立 `GroupSelectSheet`）；`:84-85` 移出书架只弹系统确认框，没有「同时删除文件」与同名副本切换；封面只能选本地图片（`:304-307`），没有在线换封面/网络文件/压缩包条目。
为什么不修：删除源文件与同名副本切换依赖书级 `isPrivate`/本地文件删除语义（`BookRepository.deleteBook` 只删书目与章节，不删 `filesDir/books` 下的正文）；在线换封面、网络文件、压缩包条目都依赖在线书源与 WebDAV；知识卡是独立模块。
补法：删除面板三项可先补（不依赖在线能力），但需要先定「删源文件」在 HarmonyOS 沙箱里的等价物。

**KI-LB6 书架管理页（13 行，整页未迁移）** —— 覆盖整个页面（`BookshelfManageScreen.kt` 1777 行 + `BookshelfManageScreenViewModel.kt` 1136 行）及其顶栏标题随分组名变化、分组筛选按钮、书籍行、行内加分组、行内更多菜单、选择模式·批量换源、选择模式·移入分组、选择模式·删除、书源选择面板、换源预览面板、其它书源选项、删除确认框。
上游：`ui/book/manage/BookshelfManageScreen.kt`（全文件）与同名 ViewModel。
本地：无此页；`pages/BookshelfPage.ets:594-595` 的「书架管理」菜单项直接 `onUnavailableAction('书架管理尚未迁移')`。
为什么不修：这是**整页未迁移**，不是 `localBook` 备份链路的缺口。它盘的是「书架管理」这个界面，其中 5 行（批量换源、书源选择面板、换源预览面板、其它书源选项）还依赖书源体系。
补法：整页单独立项，先做不依赖书源的 8 行（标题、分组筛选、书籍行、行内加分组、行内更多菜单、移入分组、删除、删除确认框）。

**附注：`localBook` 五个「列在库里但读不出来」的字段**
`data/RdbSchema.ets` 的 `books` 表 DDL 已有 `isPrivate`（`:91`）、`latestChapterTitle`（`:242`）、`canUpdate`（`:252`）、`disableReadRecord`（`:253`）、`totalChapterNum`（`:246`）、`lastCheckCount`（`:245`）六列，但 `data/BookRepository.ets:127-131` 的 `selectBooksSql` 只 SELECT 22 列，`:674-717` 的 `readBookRow` 也没读它们，`model/Book.ets` 里也就没有对应字段。上面 KI-LB1/LB3/LB4 多条「未接」的直接原因都是这一处，而不是能力本身做不了。`splitLongChapter`、`deleteAlert` 两列全仓 0 命中，是真的没有。

## 阅读与规则

- **本地 EPUB 重开被当 TXT（已补 `books.format` 列；存量书需重新导入）** —— `books` 表原先没有 format 列，落库时只存了 EPUB 抽出的 `.txt` 副本路径（`contentPath`），回读时按 `bookUrl` 后缀猜格式、恒判 `txt`，于是杀进程重开后顶栏多出「目录规则」等只对该类书有意义的动作、正文分章与替换规则走错分支。`fd4e56c` 给 `books` 表补 `format TEXT NOT NULL DEFAULT ''` 并在 `RdbSchema.ensure()` 里加幂等 ALTER，`be096c4` 把 `format` 接进 `selectBooksSql`/`upsertBookSql`/`toBookArgs`/`readBookRow`（新增 `normalizeFormat`）。**已知限制**：补列前已导入的存量 EPUB，其 `format` 列是建列时的默认空串，`normalizeFormat` 对空串退回按路径后缀判（仍是 `.txt` 副本 → `txt`），所以存量 EPUB 不会自动修好；**怎么修：删掉重导**——重新导入会走 `upsertBookSql`，`format` 从内存 `Book` 对象带进去。
- 阅读设置尚未逐控件完成回归。系统字体选择已检查；自定义 TTF/OTF 实际导入、CJK fallback、EPUB 字体和多设备排版仍待验证。
- r258 阅读正文高亮规则已在 N 端 HOS 模拟器完成面板可达、创建、命中、停用、冷启读回、滚动模式与删除七项闭环；E 端交接时面板打不开的问题在 N 端未复现。HOS `RegExp` 只覆盖 Android Java Pattern 的安全兼容子集，规则长度、章正文长度和规则条数分别限 256/150000/64，且没有执行超时保证。
- 高亮规则还差三样：**按排版 `configName` 绑定**（`data/ReaderHighlightRuleEngine.ets:54` 对 `configName` 非空的规则直接跳过）、**标题规则不执行**（同处只接受 `targetScope` 0 与 2，`targetTitle=1` 跳过）、**SVG 线型画不出来**（模型与库表有 `underlineSvgPath`、面板 `pages/ReaderHighlightRuleSheet.ets:269` 连 `.svg` 都能选，但没有任何入口填 path，ArkUI 也无 SVG path 解析器，这一档按实线兜底）。图片背景、九宫格切线、字体替换、字距行距**已经接通**（`pages/ReaderPage.ets:5273`/`:5291`-`:5293`、`reader/ReaderCanvasSurface.ets:3062`/`:2171`-`:2187`），详见下一条。`highlightRule.json` 的备份写出与 ZIP 恢复已接入并在 N 端设备双向验证，恢复采用合并语义（本地独有规则保留），与上游 `replaceAll` 全量替换不同。Android 默认规则预设导入已在 r260 接入，但与上游有 3 处已注明的差异：`bracket_note_default` 补转义、`date_time_default` 由 314 裁到 179 字符、`title_emphasis_default` 只导入不执行。
- 阅读页书签角标与「书签标记大小」已在 r264 接通：角标显示在正文区右上角，宽度取 `bookmarkBadgeSize`（默认 10dp，0 不显示，上限 50），仅在分页模式与本地书籍显示，翻页与下拉偏移一并作用，`config.xml` 恢复时读回。**自定义角标图片已在 r265 接通**（选择、保存到应用私有目录、渲染、恢复默认，`config.xml` 双向映射）；书签导出于 r263 接通（「所有书签」页按书导出 JSON/Markdown），「书签标记」样式入口的 `migrated` 也已转正。上游没有跨章批量删除/移动书签的能力，本地同样不提供，此项不算缺口。
- 划线/笔记的颜色预设已在 r266 从 6 色扩到上游 `MarkingPresetColors` 的 15 色，并加了内联自定义取色器（8×12 色板 + 手输 `#RRGGBB`/`#AARRGGBB`）。与上游仍有两处差异：上游取色器是独立 `ColorPickerSheet`，本地改成同一面板内展开；上游色板是横向滚动的单行色带，本地改成换行排列（外层遮罩会吃掉横向手势）。取色面板展开时正文区可滚动、按钮行固定在底部，这个溢出缺陷已在 r266 一并修掉。
- 「所有书签」页的书签条目点击=编辑、长按=跳转正文（r263 对齐上游）；笔记条目仍只有点击跳转，没有编辑入口，笔记编辑需在阅读页划线处进入。这与上游一致——`AllBookmarkScreen.kt` 的 `BookmarkDetailItemUi.Marking` 分支只渲染选中文本与备注，本就没有点击行为。
- 「所有书签」页的排序与跨书源提示已在 r268 对齐上游：条目按 `(chapterIndex, chapterPosition)` 排序（上游 `AllBookmarkViewModel.kt:214`），书籍列表按书名排序（上游 `:186` `.sortedBy { it.key.name }`），来源书源与当前书不同的条目在章名右侧标红显示「其他书源」（上游 `marks_other_source`）。排序只在渲染层做，preferences 里的存储顺序不变。
- 目录页搜索栏右侧「更多」菜单已在 r267 接通三项（更新目录 / 替换规则 / 本地 TXT 目录规则），不再是占位。上游 `TocScreen.kt:427-535` 里还有两项未做：「新建替换规则并预填本书作用域」（本地 `openReplaceRuleEditor(id)` 只接受已有规则 id，没有草稿通道）与「拆分超长章节」（`Book` 模型没有 `splitLongChapter` 字段，全仓零命中）。
- 更新目录（单书与书架级 `refreshAllToc`）**不再重映射**书签与划线/笔记（r276 起对齐上游）：上游 `BookmarkRepository`/`BookMarkingRepository` 更新目录时完全不碰这两张表，r267 曾按新旧正文偏移重算（`remapNoTocBookmarks`/`remapNoTocMarkings`），会把用户锚点悄悄挪到别的章节，已整段删除。书签与划线一律按原章节号保留，位置是否需要提醒交给 r270 的跳转前校验（`titleMismatch` 弹「位置可能已偏移」）。N 端实测：把 2 章伪造成 12 章再更新回真实 6 章，书签 4 条与划线 1 条逐字段完全未变，长按第 2 章书签仍能跳转并弹出偏移提示。
- 书签/笔记跳转前的定位校验已在 r270 接入（`data/ReaderBookmarkTarget.ets`）：源指纹不一致报 `sourceChanged`、章节标题不一致报 `titleMismatch`，两种都弹确认框由用户决定是否仍跳。笔记额外先按「选中文本 + 前后文」重定位，同分即歧义并退回确认框。**已知边界**：源指纹取 `androidOriginalPath ?? contentPath ?? id`，书籍换源后若这两者恰好都没变则判为 `match`，不会提示；重定位候选只覆盖 `chapterIndex` 指向的那章与标题同名章，目录大改后可能找不到锚点而退回确认框。
- 标记编辑器的「样式来源」下拉已在 r269 接入，可复用已有高亮规则的样式。**这是有损映射**：只把规则换算成标记的 `effect + color` 两个字段落盘，规则里的下划线粗细/偏移/自定义 SVG 路径、背景图（拉伸/裁剪/九宫格）、字体类字段本地渲染层不支持，换算时丢弃；因此规则日后调整不会回溯改变已有标记。上游 `MarkingSheet` 同样是当场取值、不建立引用，此处与上游一致。
- 阅读记录真实跨午夜持久化、损坏数据扫描/修复提示、阅读字数采集仍未完成或未验。书籍别名归属已接通（`pages/Index.ets:5946` 的 `checkReadRecordAlias` 在 `:5995` 的 `openBook` 开头调用，合并走 `data/ReadRecordRepository.ets:862`/`:884`/`:894`/`:906`）。
- TXT 目录规则完整 CRUD/批量组合和含非空规则的应用备份恢复仍需补测。
- **替换规则正则已加 3000ms 预算并支持超时自动停用**（TXT-READER 批次 4）：`data/ReplaceRuleEngine.ets` 在 taskpool worker 里逐条计时（`DEFAULT_REPLACE_TIMEOUT_MILLIS = 3000`，规则自带 `timeoutMillisecond > 0` 时用它），超预算的规则 id 回传后由 `ReplaceRuleRepository.disableTimedOutRules` 落库停用，该章正文换成「规则名 + 该规则执行超过 3000 毫秒，已自动停用」。**边界**：`ReplaceRuleRepository.applyContentWithResult`（同步入口，供 `applyContentForLength` 与规则预览使用）仍未限时，只有阅读链路的 `applyContentWithResultAsync` 有预算；异步并发保存覆盖风险、完整恢复提示仍待验证。
- **TXT 规则层已按上游补齐七项**（TXT-READER 批次 4）：①编码识别改成「utf-8 / gb18030 / big5 三候选各解前 16384 字节打分」（`BookRepository.ets:2259 detectTextEncoding`、`:2302 scoreDecodedText`），探测阶段不再往 hilog 刷失败日志；②规则库空表自愈（`TxtTocRuleRepository.ets:130 seedBuiltinRules`）；③单章超 102400 字节二次拆成 `原章名(1)`（`BookRepository.ets:2537 appendChapterRange`）；④第一个标题前插「前言」章并取前 500 字作 `intro`（`:2497`）；⑤空标题补「无标题章节」；⑥净化管线补齐十步（去重复标题 / 特殊样式占位与还原 / 逐行 trim 去空行，`:1761 applyChapterContentAsync`）；⑦内容编辑面板加「仅正文」折叠（`reader/ReaderBodyOnlyFilter.ets`）。
- **目录规则预览页已接通**（TXT-READER 批次 4）：目录页「更多 → 本地 TXT 目录规则」进 `pages/TxtTocRulePreviewPage.ets`，双列网格逐条显示「N 章」徽章（`totalCount < 0` 时转圈），点卡片弹章节清单（最多 500 章 + 「仅预览前 500 章」），底部「应用」直接重切全书目录（`Index.ets:5765 applyTocRule` → `BookRepository.refreshToc(..., forcedRule)`）。**扫描必须在 taskpool 里跑**（`data/TocRulePreviewEngine.ets:26`）：主线程逐条同步扫会 `THREAD_BLOCK_6S`，主线程分帧 + `setTimeout` 同样会卡在 `libtimer.z.so SetTimeoutInnerCore` 的 hilog 写 socket 上被杀。3.9MB 书、26 条规则实测约 20 秒，界面全程可操作。
- **打开本地大书会 `THREAD_BLOCK_6S` 的根因已修**（2026-11-03）：`BookRepository.readChapter` 在拿不到章节行时退化成 `deriveChapters`（把整本正文按规则重切 + 逐章折算字节偏移），几 MB 的书在主线程要 2.2 秒，叠加渲染触发 6 秒看门狗、正文空白然后被系统杀掉。现在改成三级取章节行（传入 → `cachedChapters` → `deriveChapters`），并由 `Index.ets` 的 `openBook` 在取正文前先 `await BookRepository.loadChapters` 预热缓存。修复后同一本 8MB 书首屏正文亮像素比例从 0.0134 升到 0.1517，无新 appfreeze。
- **画布绘制与选词菜单第二批已对齐上游**（TXT-READER 批次 6 第二轮）：①文字背景色带合并（`reader/ReaderCanvasSurface.ets` 的 `drawBackgroundBands` + `mergeBackgroundBands`，对齐上游 `ReaderBackgroundBounds.kt` 的 `minimumLineOverlap = 0.5f`）；②划词菜单进出场动画（`pages/ReaderPage.ets` 的 `animateCanvasSelectionMenu`，出现 400ms 淡入 + 0.94→1，收起 320ms 淡出 + →0.96，时长同 `SelectionMenuMotion.kt`）；③正中格状态优先级（`shouldUseCenterPriorityTap`：自动翻页中先开自动翻页面板）；④点划线文字打开该条笔记（`handleMarkingTap`，对齐上游 `markingId` 分支）；⑤图片点击四档（`handleImageTap` + `ReaderCanvasSurface.hitTestImageBox`，按 `clickImgWay` 走）；⑥折叠态一行横向滚动快捷条（首项左距 16、其余 10、右端 1dp 分隔线 + 三点钮）；⑦「更多」二级弹层（主卡 0.96/α0.82，二级卡含返回箭头、240dp 可滚列表与「编辑菜单项」）。
  仍在缺（第七批之后）：滚动整页 PixelMap 缓存、图片双尺寸缓存、选区跨下两页（页层批次 2 已落地代码路径与预检，完成态待验收方判定，此处不删「仍缺」措辞）。分层绘制、文字背景图与九宫格、每格动作、顶栏/标题栏/浮动图标三处配置面板、高亮规则的命中排版与字体替换与文字背景图均已落地，见下一条。
- **高亮规则已能改命中排版、换字体、挂气泡背景图**（TXT-READER 批次 6 第三/四轮）：①编辑面板新增三块（`pages/ReaderHighlightRuleSheet.ets:682-780`）——命中排版四个步进（字前距/字后距/行上距/行下距，0~40 dp 步 0.5）、字体替换（选沙箱字体 + 字重 + 斜体 + 字号偏移 -10~10 sp）、文字背景图（选图 + 四种填充方式 + 0.1~5 倍缩放 + 左右伸出 + 九宫格四条切线 + 手动切图开关）；②画布按上游 `LegacyReaderStyleRangeMapper.kt:270-330` 把一次命中拆成「首字带前距 / 段内不带 / 末字带后距」三段，字体与字号偏移在 `segmentStyle` 里逐段覆盖；③分页器新增 `LocalReaderSizeOffset`，只有字号偏移改行高、行上下距改行间留白（对齐 `ReaderChapterBlockMeasurer.kt:376-392` 的「高亮只改绘制，除字号偏移外不改行高」）；④文字背景图按上游顺序插在色带与字形之间，`.9.png` 原尺寸解码、其余按 density 降采样，排版期预取。**未设备验证的部分**：气泡图实际渲染与命中排版的实际行高变化——设备沙箱与应用数据库对 `shell` 用户均不可写，造不出带 `bgImage` / 字号偏移的规则；编辑器三块本身已在模拟器上逐项看到（1280×2832）。
- **TXT 目录解析仍是整本读入**（TXT-READER 批次 4 未接的两行）：`BookRepository.readTextFile` 一次性 `new ArrayBuffer(fileSize)`，`readTextFileAsync` 虽按 512KB 分块但仍拼成一个整串；切章、`deriveChapters`、`forEachChapter` 全部基于整本字符串。上游 `TextFile.kt` 是 512000 字节/块扫标题 + 正文 8MB 窗口缓存。50MB 以上 TXT 本地会先卡住再出目录，低内存设备长时间阅读有被系统杀后台的风险。
- **全文搜索的正则模式已加 500ms 单章预算**（TXT-READER 批次 3）：`data/ReaderSearchRegex.ets` 用 `taskpool.Task` + `Promise.race` 做截止时间，超时 `taskpool.cancel` 后跳过该章并计入 `timedOutChapterCount`（`pages/ReaderSearchPage.ets:224-226`）。这是**搜索链路**，与上面这条「替换规则同步正则未限时」是两条不同的正则，后者仍未限时。
- **章边界占位页已接通**（TXT-READER 批次 3）：分页模式在章末再翻一页会整屏居中显示「加载数据中…」，滚动模式给「继续滑动以加载下一章…」，新章正文到达后自动撤（`pages/ReaderPage.ets:4186-4203`、`reader/ReaderCanvasSurface.ets:1394-1417`）。设备用 hilog 验过绘制与撤销时序；该中间态只有约 690ms，`snapshot_display` 抓不到截图。
- 在线 URL 规则导入、在线书源抓取、RSS、TTS、WebDAV 未接入，但**自 2026-11-09 起已纳入项目范围、尚未排期**（[PROJECT.md](PROJECT.md) `:24-44`）；AI 在线服务、云同步与额外设备形态适配仍未接入且**仍在[范围之外](PROJECT.md)**（`PROJECT.md:46-48`）。
- **画布绘制细节已按上游补齐一批**（TXT-READER 批次 6，七行）：①高亮规则的下划线线型改成逐行手绘（`reader/ReaderCanvasSurface.ets:2845 drawStyledUnderlines`、`:2876 drawOneStyledUnderline`）：虚线 8vp 实 5vp 空、波浪振幅 3vp 波长 12vp、双线第二条在线下 3vp+线宽、删除线画在行盒 52% 高、荧光填行盒下半截，1 实线仍交给系统段落；**SVG 档（mode 5）本地没有路径解析器，按实线兜底**。②自动翻页从「到点整页跳」改成逐帧揭示（`pages/ReaderPage.ets:1353 startAutoPageTurn` 用 `createAnimator`；`reader/ReaderCanvasSurface.ets:906 drawAutoPageReveal` 按 `clipRect(bottom=reveal)` 贴下一页并在揭示线下沿画 1px 指示线），滚动模式匀速推进 `scrollOffset` 且到书末不自动关闭；**墨水屏 DISCRETE 分支不做**（ArkUI 侧无 e-ink 检测）。③滚动模式（`pageAnimation === 3`）不画书签角标（`pages/ReaderPage.ets:1937`）。④覆盖转场补 36dp 尾部渐变阴影（`reader/ReaderCanvasSurface.ets:912 drawCoverShadow`、`pages/ReaderPage.ets:4301-4313` 算起点）。⑤淡入转场松手阈值降到 10% 且不看速度（`reader/ReaderCanvasSurface.ets:137 FADE_COMMIT_PROGRESS`、`:219 release()` 新增 `commitProgress` 参数）。⑥「文字背景透明度 0~100」这一行此前判为未接是**误判**：上游 `ReaderBackgroundAlpha.kt` 唯一调用点（`ReadBookRouteScreen.kt:692`/`:712`）传的是 `styleConfig.bgAlpha`，管的是整页背景图透明度，本地 `pages/ReaderPage.ets:4995 backgroundImageAlpha` + `:5220 .opacity(...)` 早已等价，已按上游实际语义改判 `已接`。⑦「同位置多条高亮规则」复核后改判 `已接`：画布按区间边界切段时 `winner` 覆盖赋值（`reader/ReaderCanvasSurface.ets:1952 splitStyledSegments`），同一段字只保留最后命中的那一套样式，不会出现「字色 + 下划线 + 底色」叠加。**第七批补齐**：分层绘制（`drawPage` 拆成底色层 / 背景图层 / 字形层 / 选区层 / 下划线层，选区不再压住下划线）、文字背景图与九宫格切图、相邻同色背景合并成色带、无障碍选区快照。**仍缺**：滚动整页 PixelMap 缓存、图片双尺寸缓存、选区跨下两页（页层批次 2 已落地代码路径，见 KI-EXP3；此处历史清单不删，完成态待验收方判定）。
- **各二级面板已按上游补齐形态**（TXT-READER 批次 5，十四行）：①菜单系统页改成三页签 + `Swiper` 横滑（`pages/ReaderSettingsPage.ets:851`、`MenuSettingsTabPage()` `:869`），「每行图标数」「图标行数」换成「− 数值 ＋」步进器行、点整行才展开滑杆（对齐上游 `TinySliderSettingItem`）；②字号滑杆右侧 56×56 排版方卡（`:718`，图标 24×24 `#B7B8C1`、无文字）；③更多操作面板改成 4 列正方形 + 每页 8 格 `Swiper` + 底部圆点（`pages/ReaderPage.ets:5690-5740`），换源 / 刷新 / 自定义按钮三格带向下箭头；④`image_style` 与 `page_anim` 点一下直接展开单选（翻页动画六档：覆盖 / 滑动 / 仿真 / 滚动 / 淡入淡出 / 无动画）；⑤排版页拆出「正文 / 标题 / 页眉 / 页脚」四个子页签 + 右侧边距方卡（`ReaderSettingsPage.ets:2327`）；⑥页眉页脚补图形型 tip（电池外框、框内电池、纯图标、胶囊五种，用基础形状画）与「同一 tip 只显示首个位置」去重（`ReaderPage.ets:5085 ReaderInfoBattery`、`:5119 ReaderInfoSlot`）；⑦页眉页脚字体从「未迁移」提示改成真正打开字体选择器（`ReaderSettingsPage.ets:1441 openInfoFontSelection`）；⑧高亮规则编辑改成「规则信息 / 样式设置 / 预览效果」三分区 + 作用范围按钮 + 启用开关 + 实时预览卡，下划线档位扩到 7 档；⑨划线面板预设色补到 16 个（含纯黑 `#111111`）、色格改 32dp 圆 + 2dp 描边；⑩主题列表改成网格（2..6 列可切）+ 管理态（全选 / 反选 / 删除 / 置顶 / 置底 / 导出，前 5 份内置带锁不可选）；⑪下划线细调搬进独立「文字下划线」面板、线段高度上限从 10 提到 20；⑫文本处理面板搜索匹配 `group`、行标题显示「名称 (分组)」、规则行加拖拽把手并能真拖动落库（`data/ReplaceRuleRepository.ets:749 reorder`）；⑬底栏按钮配置的拖拽把手从装饰改成真拖动（`ReaderSettingsPage.ets:3196-3252`）。**第七批补齐**：顶栏图标与标题栏动作按钮两处配置面板（连底栏共三处，行内都有自定义图标、眼睛开关、拖拽把手，启用项自动排前）；高亮规则的命中排版 / 字体替换 / 文字背景图（含九宫格切线与手动切图）三块。**仍缺**：高亮规则的「应用排版 chip」——本地没有「命名排版方案」这个实体（`READER_BACKGROUND_STYLES` 只有日夜两色，无完整排版参数），chip 无数据源可列。


### 书签与标注（r268–r276 盘点遗留）

本节由 2026-10-29 的 [ZIP-BOOKMARK 对照表](parity/ZIP-BOOKMARK.md) 盘点得出，2026-10-30 第二轮独立复核后扩为 85 条（已接 72 / 未接 9 / 不适用 4）。9 条 `未接` 全部是用户可感知的能力缺口，逐条登记如下；4 条 `不适用` 是上游内部形态（无 Room 数据库、无 AI 助手、移出书架本就不清书签、Android 独有的 `ACTION_PROCESS_TEXT`），理由写在对照表 B/E 块。

1. **划线/笔记渲染不校验锚点文本**（已设备取证）。上游 `app/src/main/java/io/legado/app/domain/model/BookContentProcessEngine.kt:25-46` 在渲染前对每条 `KIND_USER_UNDERLINE`/`KIND_USER_HIGHLIGHT` 解析 `anchorJson`，`findTargetRange`（`:101-131`）按「选中文本 → 去空白文本 → 全空白归一化」三级退让在离近似位置最近处重定位，解析不到就不计入 `effectiveProcesses`、直接不渲染。本地 `entry/src/main/ets/pages/ReaderPage.ets:1999 getMarkingForTextRange` 只判 `chapterPosition < end && endPosition > start` 的区间相交，**完全不看 `selectedText`**，正文一变高亮就落在错误位置；三处调用点 `ReaderPage.ets:2148`（切段）、`:2326`、`:2431`（逐字 Span）都走这个判断。等价能力 `entry/src/main/ets/data/BookContentProcessEngine.ets:93 findTargetRange` 已存在但只服务高亮规则与正文处理，没接到标记渲染。设备取证：手工构造 `chapterPosition=0`、`selectedText="这一段是占位正文"`（真实位置约 480）的失效标记，本地仍在第 0-10 字渲染高亮。

2. **划词菜单缺「行内快速标记」模式**。上游按 `MarkingUiState.inlineMode` 在 `MarkingSelectionMenu`（行内预览、当场应用上次样式）与 `TextActionSelectionMenu`（完整动作条）之间切换，对应意图 `ReadBookContract.kt:870 OpenQuickMarking`、`:871 OpenQuickMarkingEdit`、`:872 ApplyQuickMarking`、`:875 DismissQuickMarking`，行内态还带 `previewStyle`/`inlineDirty` 两个状态位。本地 `entry/src/main/ets/pages/ReaderPage.ets` 的选区菜单只有 sheet 一条路径（r273 已补「复制」「书签」两项），没有行内预览态。

3. **目录页书签/笔记缺多选与批量操作**。上游 `app/src/main/java/io/legado/app/ui/book/toc/TocScreen.kt:325 selectionSecondaryActions` 提供反选、选中后续、批量加书签、批量去分组、批量删音频；本地 `entry/src/main/ets/pages/CatalogPage.ets` 的书签条目与笔记条目只有单击与长按。**章节行的多选已在 TXT-READER 批次 3 接通**（长按进多选、勾选圈、工具条「已选 N 章 / 操作 / 完成」、菜单全选/反选/加书签/取消选择，`CatalogPage.ets:430-500`），本项现在只剩书签与笔记两个列表没有多选。

4. **目录页缺反序**。上游 `TocScreen.kt:447 reverse_toc` 提供章节与书签列表的倒序开关；本地无排序方向开关，恒按 `chapterIndex` 升序（`CatalogPage.ets:185-200`）。

5. **书签无障碍播报未接**。上游 `feature/reader/core/accessibility/ReaderAccessibilityPolicy.kt:19` 用 `isBookmarked` 把「已加书签」状态提供给读屏软件；本地阅读页没有无障碍策略层，`entry/src/main/ets` 全仓只有一处 `accessibilityText`（`pages/ProfileSubPages.ets:3579`，与阅读无关），读屏用户拿不到「已加书签」状态。

6. **划词菜单「替换」缺预填规则入口**。上游 `ui/book/read/ReadBookController.kt:2065-2068` 在划词菜单选「替换」时发 `ReadBookIntent.TextActionReplace`，`ReadBookRouteScreen.kt:426-433` 接住后把选中文本按行 `trim` 拼成 `pattern`、把 `bookName`/`bookSourceUrl` 拼成 `scope`，直接打开新建替换规则页。本地 `entry/src/main/ets/pages/ProfileSubPages.ets:660-700` 的 `ReplaceRuleEditor` 本身完整（正则、作用域、排除作用域、试跑、分组都在），但只接受 `editingRule: ReplaceRule` 整条回填（`:706 applyEditingRule`），**没有「只预填 pattern」的草稿通道**，`Index.ets` 也只暴露 `openReplaceRuleEditor(id)`。补法：给编辑器加一个可选的 `initialPattern`/`initialScope` 入参，`applyEditingRule` 在无 `editingRule` 时用它回填。

7. **划词菜单「搜索内容」缺预填关键词入口**。上游 `ReadBookController.kt:2096-2099` → `ReadBookViewModel.kt:1564-1569`（`searchContentQuery` 落状态 + `ReadBookEffect.OpenSearch(text, bookUrl)` 打开搜索页）。本地 `entry/src/main/ets/pages/ReaderSearchPage.ets` 全书搜索页完整（历史、正则、替换开关、进度都有），但 `aboutToAppear`（`:52`）只加载历史，**没有 `initialQuery` 入参**，`Index.ets:4104-4112` 打开时也未传关键词。补法：加 `@Prop initialQuery: string`，`aboutToAppear` 里非空则直接触发一次搜索。

8. **划词菜单另外 8 项本地无对应能力**。上游 `ReadBookController.kt:2159-2183` 共 14 项，除已接的复制/书签/划线笔记、上面两条、以及不适用的第三方文本扩展外，还有：分享（`:2269` `activity.share`）、浏览器（`:2270-2286` `ACTION_VIEW`/`ACTION_WEB_SEARCH`）、朗读（`:2036-2044`）、词典（`:2101-2104`）、正文编辑（`:2060-2063`）、AI 清洗（`:2070-2082`）、AI 改写（`:2084-2096`）、插入 BGM 前后（`:2106-2108`）。本地全仓：分享零 `systemShare`（`pages/BookInfoPage.ets:269` 自己也是「书籍分享尚未迁移」）、浏览器零 `startAbility` 且 `module.json5` 无 browser skill、朗读 `pages/ReaderPage.ets:1265` 明确「朗读播放尚未迁移」、词典/正文编辑/AI/BGM 零命中。**这些不是「补个菜单项」就能解决的**，各自依赖一整个未迁移的子系统，应按子系统推进，补齐后再在 `ReaderPage.ets:2067-2073` 挂入口。按项目约定不塞占位。

9. **目录页信息 tab 缺「备注」行**。上游 `ui/book/read/sheet/ReaderBookSheet.kt:531-533` 在信息页渲染 `book_remark`（`remark.takeIf { it.isNotBlank() }` 条件显示，排在书源与简介之间）。本地 `entry/src/main/ets/pages/CatalogPage.ets:330-346` 只有作者（`:334`）、书源（`:335`）、简介（`:336-338`）三行，**没有备注行**；但本地 `model/Book.ets:46` 的 `remark?: string` 字段是存在的，属「字段有、界面没渲染」。补法：在书源行后插一条 `if ((this.book.remark ?? '').trim().length > 0) { CatalogInformationRow({ label: '备注', value: this.book.remark ?? '' }) }`。

另：目录页**拆分超长章节**未接入，属目录能力而非本模块（上游 `TocScreen.kt:496 split_long_chapters` + `model/localBook/TextFile.kt:328-351` 按 `book.getSplitLongChapter() && chapter.end - chapter.start > maxLengthWithToc` 拆分子章、命名 `"$lastTitle(${index+1})"`，提示文案 `split_long_chapters_enabled`/`_disabled` 在 `TocViewModel.kt:825-826`）。本地 `entry/src/main/ets/model/Book.ets` 没有 `splitLongChapter` 字段、全仓零命中，开关无处落地；连带 r271 为目录页补的「章名为空回退第 N 章」在超长章节场景下会与上游子章命名不一致。

以上 9 项与「拆分超长章节」均为**只登记未实施**，本轮不改 `.ets` 代码。

### 2026-10-30 复核：核实「不是缺口」的三项

第二轮独立复核（用户要求重新确认书签/划线/笔记是否还有缺口）推翻了三条曾疑似缺口的判断，记录在此避免后人重复排查：

- **上游 `TocScreen.kt` / `TocRouteScreen` 全仓无调用点**（grep 只命中自身），那套 3-tab 目录页是未接线代码。上游真正在用的是 `ReaderBookSheet.kt:275` 的 4 tab。因此「本地目录页 4 tab vs 上游 3 tab」**不是缺口**，本地是自有设计。
- **目录页笔记条目点按进编辑 / 长按跳转**与上游阅读面板 `ReaderBookSheet.kt:1300-1304` 同口径（该处注释明写「与书签一致，点按进入编辑，长按跳转到标记位置」），不是缺口。
- **书签列表自动滚动**本地 `CatalogPage.ets:206-224` 用 `chapterIndex <= 当前章节` 取最后一个，与上游 `ReaderBookSheet.kt:1187-1194` 的 `indexOfLast { it.chapterIndex <= currentChapterIndex }` 完全一致，只是本地多了「只自动定位一次」的保护，不是缺口。

注意：③多选（`TocScreen.kt:325`）与④反序（`TocScreen.kt:447`）仍按缺口登记，理由是它们属「上游真实写过但未接线」的设计，补不补由用户定调；这与「tab 数差异不算缺口」并不矛盾。

## 阅读体验：翻页空白与开书排版跳变

本节登记两个用户可感知的阅读体验缺陷，**2026-11-02 已随「正文改画布逐行绘制」一起消除**。二者的根因都不是「某个开关没接」，而是渲染架构与上游不同——上游正文是画布逐行绘制（`feature/reader/ReaderCanvasSurface.kt`，3747 行 Compose `Canvas`，`:2049` `native.drawText(...)`），本地原本是 ArkUI 组件树逐字 `Span`。本地现已同构：`entry/src/main/ets/reader/ReaderCanvasSurface.ets` 用 `text.Paragraph` + `drawing.Canvas` 逐行绘制。

**状态口径（只有三值）**：KI-EXP1 **已接**、KI-EXP2 **已接**、KI-EXP3 **已接**。

### KI-EXP1 翻页出现整页空白（用户原话「差不多一页的空白才翻到另一页」）—— 已接

**原根因（历史记录）**：`ReaderPage.ets` 的 `turnReaderPage(delta)` 是「半程出、半程进」的整页替换，且只有一层内容在同一时刻存在。

```typescript
// 历史实现：前半程旧页滑出到 offset = horizontalTravel
animateTo({ duration: duration / 2, curve: Curve.EaseIn }, () => {
  this.pageTurnOffsetX = direction * horizontalTravel;
});
// 历史实现：中点切页 → 新页从反方向屏外滑入
this.pageTurnTimer = setTimeout(() => {
  this.currentPageIndex = nextPageIndex;
  this.pageTurnOffsetX = reverseDirection * horizontalTravel;
  animateTo({ duration: duration / 2, curve: Curve.EaseOut }, () => { this.pageTurnOffsetX = 0; });
}, duration / 2);
```

- 默认 `pageAnimation = 0`（cover）、`animationSpeed = 2` → `durationBySpeed[2] = 360`，即 180ms 出 + 180ms 进；`pageAnimation === 0` 时 `horizontalTravel = pageWidth`，旧页整页移出、新页整页自屏外移入，中间那一瞬两层都不在可视区。
- 切页必然整树重建（`ForEach` key 含 `currentPageIndex`），新页布局+字体测量耗时正好落在空白窗口里。
- `pageTurnAnimating` 只在 setTimeout 末尾复位，快速连点被吞。

**上游语义**：`feature/reader/core/transition/ReaderPageTransition.kt` 的 `transforms(mode)` 对 `COVER` 返回 `current = ReaderPageTransform(translationX = offsetPx)` + **`next = ReaderPageTransform()`（位移 0，就在原位）+ `currentOnTop = true`** —— 新页是静止的底页，旧页盖在上面滑走，屏幕全程有内容。

**已由上游实机视频佐证（2026-11-02）**：E 端在 Android 模拟器上采集的基准包（`N:\HarmonyProjects\project-resources\legado-with-MD3\screenshots\android\reader-baseline-2026-11-02\`，仓库外不入库）里，`android-reader-animation-cover-frame-during.png`（翻页中间帧 1.55s）实测为**左右两页同屏**：左为旧页（页码 `1/11 27.3%`）正滑出，右为新页（页码 `2/11 29.5%`）已停在最终位置，画面无空白。同一批里 `android-reader-animation-slide-frame-during.png`（1.40s）则是**两页都在位移**——证实 COVER 与 SLIDE 是两套不同动作，本地曾把两者实现成同一套。采集基线与边界见 [VALIDATION](VALIDATION.md) 的「2026-11-02 Android 阅读界面基准包核对」节（`appDebug` / API 37 模拟器，不是 release 证据也不是 API 12 设备证据）。

**本地现状（已接）**：
- 翻页不再改节点树，而是改画布内部的 `turnTransition.offsetPx`：`ReaderPage.ets` 的 `turnReaderPage()` 用 `getUIContext().createAnimator(...)` 的 `onFrame(progress)` 逐帧调 `paintReaderCanvas()`，**`onFinish` 才改 `currentPageIndex`**。
- 位移全部由 `ReaderCanvasSurface.ets` 的 `ReaderPageTransitionPolicy.transforms(mode, transition, pageWidthPx)` 给出，与上游逐分支同式：COVER（`current.translationX = offsetPx` + `currentOnTop = true`）、SLIDE（另给 `next.translationX = width + offsetPx`）、FADE（`next.alpha = progress`）、折页（`ReaderPageCurl.ets` 的 `PageCurlGeometry`）、SCROLL（`ReaderScrollPolicy` 的 `pageStep` / `stepDurationMillis` / `apply` 逐项照 `ReaderScrollState.kt`，四页按 `scrollExtentPx` 堆叠后整体平移，画布内滚动）。
- 绘制前先按 `pageBackgroundArgb` 铺满整块画布，每个 slot 再各自 `fillPageSurface()` 铺纸面，**任何一帧都不会露出空白**。
- 时长一律经 `ReaderPageTransitionPolicy.settleDurationMillis()`（FADE 用整段基准、其余按剩余距离缩放），基准值来自 `animationSpeed` 索引 `[240, 300, 360, 540]`，与上游 `ReaderPageTurnSpeed.kt` 的四档一致。

**验收**：模拟器 `127.0.0.1:5555`（API 26）上五种转场（COVER / SLIDE / FADE / 折页 / 滚动）各连翻 20 页，每帧都有完整正文、无整页空白；滚动模式另验跨章 12 次翻页。详见 [VALIDATION](VALIDATION.md) 的「2026-11-02 N 端正文改画布逐行绘制」。

### KI-EXP2 开书时排版先乱 1-2 秒（用户原话「排版总是会先乱一秒两秒」）—— 已接

**原根因（历史记录）**：分页未就绪时走的是**另一套排版**，不是同一套排版的中间态。`ReaderPage.ets` 的分支 `if ((format === 'txt' || 'epub') && this.localReaderPages.length > 0 && pageAnimation !== 3) { 分页 } else { Scroll 整章连续铺开 }` —— 首帧 `readerContentWidth` / `viewportHeight` 初值都是 0，`rebuildReaderPages()` 一进来就清空分页返回，于是先渲染整章滚动，等尺寸到位再切分页。

**放大因素（历史记录）**：① 约 40 个 `@Prop` 共用 `onPaginationInputsChanged`，设置分几次到达就重建几次；② `Index.ets` 的 `restoreReaderSettings(context)` 是 async 且未 await；③ 尺寸三条到达路径都调 `rebuildReaderPages()`；④ 每次重建跑全章解析与高亮匹配；⑤ 带图章节缺图片尺寸就清空整章分页，走两轮「滚动 → 分页」切换。

**本地现状（已接，五条逐个消除）**：
1. 分页判据去掉 `localReaderPages.length > 0`，现在只要 `format === 'txt' || 'epub'` 就**一律进画布**（连续滚动模式也是同一张画布，不再有第二套 ArkUI 排版）。没有排好页时画布什么都不画（`ReaderCanvasRenderer.draw()` 开头 `window.current === undefined` 直接 return，注释点名上游 `ReaderCanvasSurface.kt:254` 的 `val current = pages.current ?: return`），**绝不换一套排版兜底**。else 分支的 `Scroll` 整章滚动已删除。
2. 约 40 个 `@Watch('onPaginationInputsChanged')` 现在只调 `scheduleReaderPaginationRebuild()`：`refreshReaderFontFamilies()` 立即执行，重建合并到 16ms 防抖窗口内只跑一次（`PAGINATION_DEBOUNCE_MILLIS = 16`）。
3. `Index.ets` 的 `ReaderPage` 外层加了渲染门控 `if (this.readerSettingsLoaded || this.route !== AppRoute.READER)`，设置没载入完时显示与阅读页同色的空白占位 + `LoadingProgress`，不再按初值先排一次错的。
4. 图片尺寸未就绪不再清空整章分页：`rebuildReaderPages()` 里用 `paginationImageSizes.set(part.value, { width: placeholderExtent, height: placeholderExtent })`（`placeholderExtent = max(1, lineHeight)`，对齐上游 `ReaderChapterBlockMeasurer.kt:457-462` 的占位口径），并置 `paginationUsesImagePlaceholder`；尺寸异步到达后只重排一次。
5. 画布侧新增 `syncReaderCanvasBodyHeight()`：`Canvas.onAreaChange` 把实测正文高写进 `readerCanvasBodyHeightVp`，分页时 `pageHeight = min(公式值, 实测值)`，保证「分页算得下」与「画布画得下」同源。

**验收**：冷启动 → `aa start` → 点书架进书，连续 6 次 `uitest dumpLayout` 每次都只有 `Canvas=1 Scroll=0`，**开书全程从未出现整章滚动分支**；详见 [VALIDATION](VALIDATION.md) 同节。

### KI-EXP3 改画布会连带失效的选区能力 —— 已接

**原风险（历史记录）**：本地选区完全依赖 ArkUI `Text` 的原生能力（`.copyOption(CopyOptions.InApp)`、`.onTextSelectionChange(...)`、`.bindSelectionMenu(TextSpanType.TEXT, this.readerMarkingSelectionMenu(), TextResponseType.LONG_PRESS, {...})`），正文改自绘后这些全部失效，阅读页会掉「长按选词、拖把手、标笔记」三项。

**本地现状（已接，按上游 `feature/reader/core/selection/` 六文件 503 行自绘）**：
- 几何：`ReaderCanvasRenderer` 把绘制拆成「先 `layoutPage()` 算几何、再逐元素画」，`ReaderCanvasPageGeometry` 记录每个 item 的 `left/top/widthPx/heightPx`，命中测试与绘制共用同一套坐标，不会漂移。
- 命中与选词：`hitTestTextBox(x, y)` → `glyphOffsetAt(box, x, y, style)`（`Paragraph.getGlyphPositionAtCoordinate`）→ `wordRangeAt(box, offset, style)`（`Paragraph.getWordBoundary` 取整词，空词退化成单字）。**偏移已贴到元素末尾时起点要回退一格**：否则 `start === end` 得到零长选区，`getRectsForRange` 拿不到矩形、两个把手也无处可放，表现为「长按有菜单但看不见选区、也抓不到把手」（`startCanvasSelectionAt` 里已处理）。
- 绘制：`drawSelection()` 用 `Paragraph.getRectsForRange(range, TIGHT, TIGHT)` 拿条带矩形，`drawing.Brush` 填 `0x63858585`（上游 `legacySelectionFill`），再用 `drawing.Brush` + `drawing.Pen` 各画一次 `drawCircle` 作两个把手（半径 7vp、描边 2vp，对齐上游 `SelectionHandleRadius`/`SelectionHandleStrokeWidth`）。
- 交互：`ReaderPage.ets` 的 `Stack` 挂 `LongPressGesture({ duration: 600 })` 起选（对齐上游 `LONG_PRESS_TIMEOUT_MILLIS = 600L`），横向 `PanGesture` 先 `canvasHandleHit()` 判把手命中，命中则拖 `dragCanvasSelectionTo()` 不翻页；`canvasSuppressTap` 标记吞掉长按抬手的那次 tap（对齐上游 `suppressTap`）。
- 坐标口径（三处，缺一就会「选区跑到屏幕外」或「抓不到把手」）：
  1. `drawPage` 只对**当前页**记几何（`recordGeometry`）和画选区（`drawSelection`），四页窗口里邻页一律不记——否则最后画的邻页会顶掉当前页坐标。（页层批次 2 后另有一份 `scrollWindowGeometry` 登记 current+next+nextPlus 供跨页命中，见本节末条；`this.geometry` 与把手端点仍只由 current 写，邻页只画条带不回填，本条口径不变。）
  2. 手指坐标换算 `canvasViewportY()`：`finger.localY` 相对外层 `Stack`，画布顶边用 `getComponentUtils().getRectangleById(CANVAS_ID).windowOffset.y` 与 `STACK_ID` 的同名值相减求得（两者同口径，状态栏自动抵消）；**不要**直接减 `Area.position.y`，它会漏掉父容器的页眉占位。
  3. 滚动模式下再减 `scrollOffset`：`canvasContentY()` = 视口 y − `vp2px(scrollOffset)`（`drawScrollSlot` 里是 `translate(0, scrollOffsetPx)`）。
- 把手几何与命中照上游 `drawPinHandle` / `handleHitRadius`：圆心在矩形 `bottom + radius`，竖线只画到矩形 `bottom`（不画到圆心），命中热区 28vp 且按「竖线顶端—圆心」胶囊中轴线求最短距离；拖动时端点跟**把手**走而不是跟手指走（记 `canvasHandleGrabOffsetX/Y`），再减 `radius` 回到行底做 `positionAt()`。
- 跨元素/跨行扩展：拖动取位用 `ReaderCanvasRenderer.positionAt(x, y, style)`，它在一行的**所有**元素间推进、超出最后一个元素就返回该行 `endPosition`；不能沿用单元素的 `glyphOffsetAt`（分页器会把一行按标点/样式切成多个小元素，单元素会被行末 clamp 住，选区再也扩不出去）。
- 把手淡入淡出：`animateCanvasHandleTo()` 用 `UIContext.createAnimator` 做真补间，淡出 90ms、淡入 140ms（对齐上游 `SelectionHandleFadeOutMillis` / `SelectionHandleFadeInMillis`），拖动时另一侧把手同时淡出。
- 菜单：菜单浮层 `Column(){ readerMarkingSelectionMenu() }.position(...)`，锚点由 `refreshCanvasSelectionMenuAnchor()` 按选区条带的 `selectionStartX/Y`、`selectionEndX/Y`、`selectionTopY/BottomY` 回填；沿用既有 `runSelectionMenuAction()`（复制 / 书签 / 划线 — 笔记）与 `createMarkingFromCurrentSelection()`。
- 清理：程序化翻页的 `animator.onFinish` 调 `resetCanvasSelectionState()`（对齐上游 `ReaderSelectionLifecyclePolicy.shouldClearForPageChange`）。
- 滚动模式跨页选区（页层批次 2 落地，完成态待验收方判定）：上游滚动模式 `ReaderSelection.kt` 的 `last = 2` 允许选区扩到 current+next+nextPlus，翻页模式 `last = 0` 只当前页。本地 `drawScroll` 在 `selectionStart >= 0` 期间按 `pageIndex` 把三页几何登记进 `scrollWindowGeometry`（复用 draw 期已算好的 `layoutPage()` 结果，不再排版），每帧覆盖登记以跟住自动滚动换 current；`positionAtScrollWindow(x, y, style)` 按内容坐标落在哪页的 `scrollContentTopPx..+scrollExtentPx` 区间选该页几何再做 `positionAtGeometry`，返回值仍是章内全局 `startPosition`，使 `[start,end]` 跨页连续。邻页 `drawScrollSlot` 传 `drawSelection=selectionActive` 让高亮条带跨过页交界，但 `reportHandles=recordGeometry=false`（只有 current 为真）——邻页 canvas 已 `translate(0, stackOffsetY)`，若回填 `selectionStartX/Y` 等端点会顶掉 current 的坐标，让菜单锚点与把手 hit-test 跑偏。`ReaderPage.ets` 的 `dragCanvasSelectionTo` 在 `usesCanvasScroll()` 时改走四页命中，翻页模式与「点划线」的 `handleMarkingTap` 仍走单页 `positionAt`。转场五档一行未动（预检 `git diff | grep -c "drawPageCurl|drawSlide|drawFade|drawCover"` = 0）。

**验收**：模拟器上长按出选区带 + 两个把手 + 浮动菜单；拖起始把手把选区从单字扩到两行、拖结束把手跨行；点「划线 — 笔记」面板回显完整选中文本并可保存，保存后正文出现绿色下划线；详见 [VALIDATION](VALIDATION.md) 同节。

### 顺带补回：高亮规则（正则命中的字色/底色/下划线）—— 已接

画布化时先只搬了「用户划线/笔记」（`markings`），`ReaderHighlightRule` 的正则命中样式一度完全没画——这是 Span 分支删除后的真实功能退化，2026-11-02 已补齐。

- 上游口径：`legacy/LegacyReaderStyleRangeMapper.kt` 的 `map()` 把启用规则按 `position` 升序展开成区间，`priority = index`；用户划线走 `priority = 10_000 + index` 压在高亮规则之上。
- 本地实现：`ReaderPage.ets` 的 `buildReaderCanvasHighlights()` 把 `readerHighlightRanges` 转成 `ReaderCanvasStyleRange`（`textColorArgb` / `backgroundArgb` / `decoration` / `decorationArgb`），再把 `markings` 里 `effect === 'text'` 的字色区间追加在数组末尾；`ReaderCanvasSurface.ets` 的 `splitStyledSegments()` 按区间端点切段、每段取「完全覆盖它的最后一个 range」，`getParagraph()` 用 `ParagraphBuilder.pushStyle / addText / popStyle` 逐段套样式。
- `underlineMode` 映射：`6 → LINE_THROUGH`、`1..4 → UNDERLINE`、否则 NONE；线型 `2 → DASHED`、`3 → WAVY`、`4 → DOUBLE`、否则 SOLID。
- 验收：设备上原本无高亮规则数据，用 UI 造了一条「文字颜色」划线（`uitest uiInput longClick 400 1000` → 菜单「划线 / 笔记」→ 样式「文字颜色」→ 保存），第 2 次翻页后屏幕上出现绿色字形像素（738 个，bbox `(392,2374)-(540,2440)`），确认分段样式确实下到了 `Paragraph` 并画出。**通过。**

### 已删除：默认参数把所有人推到最慢的渲染分支

原记录点名的 `ReaderPage.ets` 分支 `if (this.currentPageContainsImages() || this.readerBottomJustifyGap > 0) { ReaderPageTextLines } else { ReaderPageTextJoined }` 与 `textBottomJustify` 默认 true 导致每页新建 400-900 个 Span 节点的代价，**已随 Span 渲染分支整体删除而消失**：现在一页的绘制成本与行数线性相关，与默认值无关。`textBottomJustify` 的语义仍保留（画布下表现为 `ReaderCanvasLayout.bottomJustifyGapPx` 按行 y 摊分）。

### 滚动模式跨章换页顿挫：先量再削（2026-11-10 计时与取舍）

用户报 `pageAnimation = 3` 下滚到章末继续下滑进下一章时会顿一下。本轮先补 `[ReaderBench]` 计时（提交 `75ee736`），再按测量结果决定两处削减（提交 `8cde93c`、`ccad0cc`），逐场景耗时与原始 hilog 见仓库外 `N:/HarmonyProjects/tmp/reader-handoff-evidence.md`。

**时间花在哪**：三个场景（首次进下一章 / 同一章末第二次 / 往回上一章末页定位）各测 3 轮取中位数，真 `LocalReaderPaginator.paginate`（日志字段 `paginatorMs`）为 57 / 60 / 48 ms，分别占 `contentChanged totalMs` 77 / 79 / 57 的约 75%；`contentMs`（整本正文缓存读盘）= 0、`applyMs`（替换规则 taskpool 往返）= 0~1、`semanticsMs`（语义解析 + 高亮扫描）= 0~1、`renderMs`（定位 + 钳位 + 预解图 + 重绘）= 7~16。任务给的日志模板里 `paginateMs` 实为语义段（1~2 ms），`positionMs` 才是含真 paginate 的大头，故另补 `paginatorMs` / `renderMs` 两个字段判定——按模板字面 `paginateMs` 不是最大项，按「整章同步排版是大头」的意图成立。

**批 2（滚动模式不启动全书分页）**：默认配置下 `needsFullBookPageData()` 恒 false（`DEFAULT_READER_INFO_SETTINGS` 六个页眉页脚值 1,0,2,7,0,6 都不是 19/20/18，设备 prefs 无覆盖），全书分页本就不启动，该改动对默认配置是 no-op。注入 `<double key="tipFooterRight" value="20.000000"/>` 构造触发配置后：滚动模式 `fullBookPagination skipScroll=1 needs=1` 且无 `started`；分页模式 `skipScroll=0 needs=1` 且出现 `started gen=...`，底部 `17/41 33.3%`，进度条数值未坏。三场景 `contentChanged totalMs` 由批 1 的 77 / 79 / 57 到批 2 的 70 / 72 / 51，差在冷启动与调度抖动范围内，不构成可测下降。

**批 3（换章不重复排版）—— 判定「不需要做」，理由**：任务假设「`loadContentImageSizes()` 回来触发 `rebuildReaderPages(true, true)`，含图章整章排两遍」。实测不成立：`primeContentImageSizesSync()`（`ReaderPage.ets:1604`）在首次排版前已用 `getImageInfoSync()` 同步量好本章图片尺寸，注释 `:4792-4802` 明写「排版期就用真实尺寸，不再有二次重排」；`loadContentImageSizes()` 只在有未量到尺寸的新图片段时 `changed=true` 才走 100ms 防抖重排，纯文字书与含图书实测都是 `imageSizesReloaded rebuildAgain=false`。含图书（`爱情潮湿`，含 2 个 `[[EPUB_IMAGE:...]]` 段、1 章）与纯文字书（`yushen`）各测一次，结论一致：不存在由图片尺寸触发的 `onlyImageSizesChanged=true` 二次重排，故按任务 3.2「若没有触发，这一批直接标不需要做」不做等待 150ms 的改动。

**与任务断言不符处（如实登记，不是「未做」）**：换章确有 2 次全量 `rebuildReaderPages()`（两次都 `onlyImages=false reuseSemantic=false`），但来源不是图片尺寸路径——实测 `imageSizesReloaded rebuildAgain=false`、无 `canvasHeightRebuild`、无 `debouncedRebuild`，且 `titleChangedRebuild` 恰好紧跟在第 2 次 rebuild 之前。链路是 `Index.selectChapter` 一次性赋多个 `@Prop`：`content` 的 `@Watch` 触发 `onReaderContentChanged()` 首排（第 1 次），`chapterTitle` 的 `@Watch` 经 `refreshDisplayChapterTitle()` 异步定稿后赋 `displayChapterTitle`，其 `@Watch` `onDisplayChapterTitleChanged()` 无条件再排一次（第 2 次）。`onChapterTitleChanged():1496-1498` 的注释已点明「两处都排就是同一章排两遍」。消除它要改标题块定稿与页表一致性，风险超出本批「图片尺寸等待」的授权范围，本批未改；真 paginate 与这 2 次 rebuild 都仍在。

**主观判断（三档之一）**：设备上做 5 次换章观测，每次 `contentChanged totalMs` 为 70 / 68 / 69 / 73 / 101 ms，每次仍是 2 次全量 rebuild。**改善不明显**——换章那一帧的真 paginate（约 48~60 ms）与第 2 次 rebuild 都未被削掉。实测手数：5 次换章。

**测量手法偏离**：任务要求用「滚到章末继续下滑」的手势触发。`uinput -T -g 640 2400 640 200 600 9000`（press=600）触发 `LongPressGesture` 选区菜单；改 press=500 与 `uitest uiInput swipe` 都进不了 ArkUI `PanGesture.onActionUpdate` 逐帧通道，滚不到章末。改用向 prefs 注入 `bottomActions` 打开 `prev_chapter` / `next_chapter` 按钮，点按钮走 `onTurnChapterBoundary(±1)` → `selectChapter(..., delta < 0 ? 100 : 0)`，与滚过章末是同一条 `selectChapter → onReaderContentChanged → rebuildReaderPages` 同步链路，且能覆盖场景 3 的 `initialProgress = 100` 末页定位分支。运行时确认是滚动模式（prefs `pageAnimation=3.000000`、设置面板「滚动」高亮、底部 `33.3%` 符合 `getWholeBookProgress()` 滚动分支）。

**文档改判结论**：`grep -rn "顿挫\|换章\|跨章" docs/parity/TXT-READER.md docs/KNOWN-ISSUES.md` 命中的行讲的是 KI-REL1 空窗/闪烁、B8 增量分页能力、跨章边界占位页与跨章定位，没有描述「换章那一帧排版耗时」且状态因本轮改变的行；B8「增量分页 / 正文三槽 / 邻章页直接发布」等行判 `未接`，本轮未实现这些能力，状态一律不改判。按任务 4.3「没有相关行就不要硬加」不动 TXT-READER.md 表格状态列（避免破坏 parity-pipes / parity-rows），只在本文件追加本条如实记录。

## 阅读进度与章首定位

本节登记 2026-11-02 修复的四个阅读缺陷：**阅读进度不落库（开书回章首）**、**目录跳章自激循环**、**带图章节图片尺寸到达后整章重排 N 次**、**折页阴影偏移疑点**。前三项已改并设备验收（见各条「验收」），第四项经比对上游源码判定**不是缺陷、不改**。

### KI-PROG1 每次开书都回到章首，读到的页数不记录 —— 已修

两处叠加，缺一不可：

1. **`Index.ets` 的 `openBook()` 无条件把「从本章开头读」置真**。该标志 `readerStartAtChapterBeginning` 的语义应是「用户主动要求从本章开头重读」，`Index.ets` 里书签跳转（`:1718`、`:1952`）与 `selectChapter`（`:6163`）都赋 `false`，只有 `openBook()` 赋了 `true`，于是每次进书都强制丢掉章内进度。改为 `false`。
2. **`BookRepository.ets` 的 `readBookRow()` 漏读 `androidCharacterPosition`**。`books` 表第 7 列（索引 6，`durChapterPos`）存的是章内字符位置，`readBookRow()` 却把它读进 `chapterProgress`，导致 `ReaderPage.ets:1602` 的 `const savedPosition = Math.max(0, this.book.androidCharacterPosition ?? 0);` 恒为 0。写入侧 `Index.ets:5980` 的 `updateReadingProgress` 一直是好的，坏在 `toBookArgs()` 第 25 列写的是 `chapterProgress`（章内百分比 0-100），把两个语义不同的量塞进了同一列。

修法：`StoredReadConfig` 加 `chapterProgress?: number`，百分比随 `readConfig` JSON 一起存（`durChapterPos` 只有一列，`readBookRow` 是同步函数拿不到章长、算不出百分比）；`durChapterPos` 回归字符位置。**兼容存量**：`readConfig` 里有 `chapterProgress` 键的才是新格式，没有的是旧行（那时 `durChapterPos` 存的是百分比，当字符位置用会把 2% 读成「第 2 个字符」），旧行留 `undefined`、渲染侧仍按百分比定位。

- 验收：设备 the-metamorphosis 翻到 `5/17 2.3%` → 退出 → 重开仍是 `5/17 2.3%`（修前是 `1/9 0.1%`）；zh-book 翻到 `3/10 2.7%` → `aa force-stop` 杀进程 → 冷启动 → 仍是 `3/10 2.7%` 标题「第15章 对练」。**通过**（三级口径第 3 级）。

### KI-PROG2 从目录跳章自激循环 —— 已修

完整链路（`@Watch` 互相触发，`titleGeneration` 只挡 `displayChapterTitle` 赋值，挡不住 `onReplaceRulesRefresh` 本身）：

```
onChapterTitleChanged()
  → refreshDisplayChapterTitle()
    → onReplaceRulesRefresh()
      → Index.ets:6674  this.replaceRules = ReplaceRuleRepository.getAll()
        → ReplaceRuleRepository.ets:97-99  cachedRules.map(copyRule)   // 每次都是新数组引用
          → @Prop @Watch('onReplaceRulesChanged') replaceRules（ReaderPage.ets:156）
            → onReplaceRulesChanged()
              → refreshDisplayChapterTitle()   // 回到起点
```

修法两处：`refreshDisplayChapterTitle()` 里删掉 `this.onReplaceRulesRefresh();`；`onChapterTitleChanged()` 里删掉 `this.rebuildReaderPages();`（末尾 `refreshDisplayChapterTitle()` 赋值 `displayChapterTitle` 会触发 `onDisplayChapterTitleChanged()` 再排一次，两处都排就是同一章排两遍）。

- 验收：13 章的 the-metamorphosis 连续从目录跳第 8–13 章，每次标题正确、`pidof` 恒为同一进程未变。**通过**（三级口径第 3 级）。
- **边界**：`replace_rules` 表 0 条时 `getAll()` 返回空数组、`applyTitle` 是 `async` 会让出事件循环，所以这个自激循环在当前数据下不会真卡死 —— A/B 对照（stash 改动后重新构建装机）在 13 章书上跳章同样正常。改动去掉的是确定存在的自激回路，**「跳章卡死」这个现象本身在本机复现不出来**。
- **另有一处既有缺陷不算在本条**：zh-book 有 572 章，打开目录页必 ANR（`/data/log/faultlog/faultlogger/` 里 `appfreeze-...` 全部 `Reason:THREAD_BLOCK_6S`，主线程栈只有 `BCStub_HandleLdaV8StwCopy` / `BCStub_HandleMovV4V4StwCopy`）。基线（stash 改动）同样 ANR，根因是 `CatalogPage.ets:281 loadChapterWordCounts()` → `BookRepository.forEachChapter()`（`BookRepository.ets:1447`，逐章 `applyChapterContentAsync` 全文处理）在 572 章上的全量遍历。**该缺陷已在 KI-PROG5 修复**。

### KI-PROG5 大目录（上千章）打开目录页必 ANR —— 已修

两处叠加，都在 `CatalogPage` 打开时同步占用界面线程：

1. **`loadChapterWordCounts()` 没把 `chapterRows` 传给 `forEachChapter()`**。`BookRepository.forEachChapter(book, cb, useReplaceRules, chapters = [])` 的 `chapters` 默认是空数组，不传时 `BookRepository.ets:1458` 走 `chapters.length > 0 ? chapters : deriveChapters(book, content)` —— 即对 8.4MB 全书正文**再跑一遍目录规则正则**（`splitChapters` → `TxtTocRuleRepository.splitChapterStarts`），只为拿回一份调用方手里早就有的章节行。
2. **`chapterBody()` 逐章调用 `byteOffsetToCharIndex()`**。这个函数每次从全书开头逐字符累加字节宽度直到命中目标偏移，`forEachChapter` 的循环里每章都要调两次（start、end），1378 章就是 **O(N²)**：平均每章扫半本书约 42 万个字符，合计约 **11.6 亿次字符迭代**，全部在界面线程上同步执行。

对照实验（决定性证据）：把 preferences 里 `tocCountWords` 改成 `false` 关掉字数统计后，1378 章的目录**立刻正常渲染**（`共 1378 章`，进程存活）；改回 `true` 就必被杀。说明卡死来自字数统计这条路径，不是目录本身渲染。

修法两处：

- `CatalogPage.ets` 的 `aboutToAppear()` 改为在需要统计字数时走新增的 `loadChapterWordCountsAfterRows()`：先 `await this.loadChapterRows()`，确认 `chapterRows.length > 0` 后再 `await this.loadChapterWordCounts()`；`loadChapterWordCounts()` 里的 `forEachChapter` 补传第四个参数 `this.chapterRows`。**两处缺一不可** —— 只补传参不串行等待，`chapterRows` 那时还是空数组，仍然会退回 `deriveChapters()`。
- `BookRepository.ets` 新增 `byteOffsetsToCharIndices(content, byteOffsets, encoding)`（一次顺序扫描换算一组递增的字节偏移，写法与既有的 `charOffsetsToByteOffsets` 同构）与 `sequentialChapterRanges(content, rows, encoding)`（预先算出每章字符区间，任一行缺 `start`/`end` 就返回 `undefined` 让调用方退回逐章换算）；`chapterBody()` 增加可选参数 `charRange`，`forEachChapter()` 在循环前算一次区间表再逐章传进去。`chapterBody()` 的原有逐章换算路径保留，增量导入等只处理少数章节的调用方行为不变。

- 验收（三级口径第 3 级，**通过**）：
  - 1378 章的 `古神？这分明是白发兽耳小萝莉`：点目录到 `共 1378 章` 渲染完成 **6461 ms**（修复前必被杀），章节标题与右侧字数（`2179字` / `2108字` …）全部正常显示，目录滚动流畅，`pidof` 全程 13273 未变。
  - 连续 5 轮从目录跳章：目标章节与实际落地章节逐轮一致（第19章 / 第24章 / 第29章），进程始终存活。
  - 572 章的 zh-book（修复前必 ANR）：目录 **2522 ms** 打开，跳第 21 章成功，`pidof` 14043 未变。
  - `/data/log/faultlog/faultlogger/` 最新一条 `appfreeze-...` 停在 **14:56**（修复前那一轮），之后整轮验收（15:00 起）**没有再产生任何新的 appfreeze 日志**。

### KI-PROG3 带图章节图片尺寸到达后整章重排 N 次 —— 已修

`loadContentImageSizes()` 原本每读到一张图的尺寸就调一次 `rebuildReaderPages()`，而 `rebuildReaderPages()` 每次都做 `LocalTextSemantics.parse(全章)` + `ReaderHighlightRuleEngine.findBodyRanges(全章)` + 全量分页。带 N 张图的章节就是 N 次全章解析 + N 次全量分页。

修法：`rebuildReaderPages(forceProgressCommit = false, onlyImageSizesChanged = false)`，第二个参数为真时复用 `this.localSemanticDocument`、跳过语义解析与高亮区间重算，只重排；`loadContentImageSizes()` 改为走新增的 `scheduleImageSizesPaginationRebuild()`（100ms 防抖，复用 `scheduleReaderPaginationRebuild()` 的定时器，`paginationRebuildDelayMillis` 用后复位成 16ms），一批尺寸一起到达只重排一次。

- 验收：带图 EPUB（`古神？这分明是白发兽耳小萝莉`，1378 章）开书到可读时间，改后 3645 / 4046 / 3981 ms，基线 3982 / 4131 / 4029 ms，**在测量噪声内、无可测退化**。**通过**（三级口径第 3 级，口径是「不退化」而非「变快」——这本 EPUB 全书只有 1 张图，N=1 的路径本来就只重排一次，收益体现在多图章节，本机没有可用样本）。

### KI-PROG4 折页阴影 `25 * 1.414` 疑点 —— 经比对上游源码，不是缺陷，不改

`entry/src/main/ets/reader/ReaderPageCurl.ets:340-341`：

```typescript
const shadowX = frame.touch.x + 25 * 1.414 * Math.cos(angle);
const shadowY = frame.touch.y + (reverse ? 1 : -1) * 25 * 1.414 * Math.sin(angle);
```

**上游逐字原值**，不是本地自拟：`N:\HarmonyProjects\legado-with-MD3\app\src\main\java\io\legado\app\feature\reader\ReaderCanvasSurface.kt:2583-2585` 写的就是

```kotlin
val shadowX = (frame.touch.x + 25f * 1.414f * cos(angle)).toFloat()
val shadowY = (frame.touch.y + (if (reverse) 1 else -1) * 25f * 1.414f * sin(angle)).toFloat()
```

同一类里其余也逐行一致：`reverse` 判据、`angle` 的 `PI/4 - atan2(...)`、`front` / `reveal` / `back` 三个路径的顶点序列、`mirror` 的 scaleX/skewX/skewY/scaleY/translateX/translateY 公式、`frontShadowHorizontal` / `frontShadowVertical` 的楔形顶点。阴影色也一致（上游 `PageCurlGeometry.kt:47-49` 的 `0x99111111` / `0x4D111111` / `0x73333333` ↔ 本地 `ReaderPageCurl.ets:68-70` 的 `BACK_SHADOW_DARK_ARGB` / `FRONT_SHADOW_DARK_ARGB` / `FOLDER_SHADOW_DARK_ARGB`）。**结论：不改。**

- 观感差异仅在于宿主绘制 API 不同（上游 Compose `drawRect(Brush.horizontalGradient(...))`，本地 `drawing.Brush.setShaderEffect(drawing.ShaderEffect.createLinearGradient(...))` + `canvas.rotate()`），`drawCurlBackShadow` / `drawCurlFolderShadow` / `drawCurlFrontShadows` 三个函数的几何参数已与上游同构。基准包 `android-reader-animation-simulation-frame-during.png`（1080×2400）里折页是右上角一条细暗带，与本机抓到的折页中间帧方向、位置一致。

### KI-SCROLL1 滚动模式拖拽方向相反、量纲错、跨页收口未实现 —— 已修

连续滚动模式（`pageAnimation === 3`）下手指向上滑，内容跟着向上走但只走一点点就停；换页永远不触发。三个错误叠在同一条路径上：

1. **方向符号反了**。`dragReaderScrollBy()` 里 `const next = Math.max(0, Math.min(total, this.scrollDragStartOffset - offsetYVp));` 的减号是错的。`offsetPx = 0` 表示当前页顶边对齐视口顶边，`deltaPx` 为负才是内容上移（往后读）；ArkUI `PanGesture` 的 `offsetY` 手指向下为正，与上游 `ReaderCanvasSurface.kt:1333-1342` 直接拿 `moveDelta.y` 当 delta 同口径，不该取负。
2. **钳制量纲错**。`scrollOffset` 的正常值域是 `[-currentExtent, 0]`，而 `total` 来自 `readerScrollTotalHeight()`（整章内容高减一屏），不是同一量纲。只改符号不修夹取，位移会被 `Math.max(0, …)` 钳成 0，表现为「手指向上滑完全没反应」。
3. **跨页收口从未实现**。`onActionEnd` 只有 `this.updateProgress();`，注释却写着「跨页要等抬手后的 applyReaderScrollDelta 收口」——那条调用根本不存在。

修法：删掉 `dragReaderScrollBy()` 与字段 `scrollDragStartOffset`，换成 `scrollDragLastY`；纵向 `PanGesture` 的 `onActionUpdate` 把 ArkUI 的累计 `offsetY` 换算成逐帧 delta 后直接调 `applyReaderScrollDelta(vp2px(delta))`（它内部负责换页、`refreshReaderBottomJustifyGap()` 与重绘），`onActionEnd` 保持只 `updateProgress()`。

- 验收：纯观测（不点击）下手指上滑 200 px，正文条带位移 `-198 px`、`residual=0.05`，正文文本顺序同步前进；连续 8 次上滑可正常跨页；退出重进保持 `17/17`；分页模式横向翻页与滚动模式长按选词均不受影响。**通过**（三级口径第 3 级）。

**抬手惯性 fling —— 已接**（2026-11-02 第二批）。上游 `ReaderCanvasSurface.kt:1414-1452` 用 `animateDecay(velocity, scrollDecay)` 做松手后的减速滑行，本地补了同形状的指数衰减：`ReaderPage.ets:2122` 的 `startReaderScrollFling(velocityYVpPerSecond)` 配 `ReaderCanvasSurface.ets` 的 `ReaderScrollDecay`（`DECAY_RATE_PER_SECOND = 3.3`、`DURATION_MILLIS = 1200`，位移 `v0/λ·(1-e^(-λt))`），撞章边界立即停。滚动 PanGesture 的 `onActionEnd` 现在是 `this.updateProgress(); this.startReaderScrollFling(event.velocityY ?? 0);`。

- 验收：滚动模式下快速上滑一次松手，页码从 `14/17` 自动滑到 `12/17`（抬手后继续滑过 2 页）✔。

### KI-SHELF1 书架网格与无封面文字封面与上游的差异 —— 已对齐

书架原先有两组与上游不一致的地方，本轮全部对齐。上游基准：`ui/main/bookshelf/BookItem.kt`（网格项与封面容器）与 `ui/widget/components/image/cover/CoilBookCover.kt`（无封面时的文字封面）。

**A 部分：书架网格**

| # | 差异 | 修法 |
|---|---|---|
| 1 | 封面是固定 70×100 的小块，不填满格子 | `BookCover` 新增 `fillWidth` / `maxWidth`：宽取格子可用宽，高按 **5:7** 算，对齐上游 `BookItem.kt:271` 的 `aspectRatio(5f / 7f)` |
| 2 | 卡片左对齐、标题也左对齐 | 卡片 `alignItems(HorizontalAlign.Center)`；标题 `width('100%')` + `textAlign` 由新字段 `bookshelfTitleCenter` 决定（默认 true，对齐上游 `BookshelfGridItem` 的 `titleCenter = true`） |
| 3 | 网格间距写死 `rowsGap(16)` / `columnsGap(10)` / 左右 padding 14 | 统一成常量 `BOOKSHELF_GRID_GAP = 8` / `BOOKSHELF_GRID_PADDING = 8`，对齐上游 `BookshelfScreen.kt:1748-1772` 的 `spacedBy(8.dp)` + `horizontal = 8.dp` |
| 4 | 标题没有内边距、字号写死 13 | 标题 `padding({ left: 4, right: 4, bottom: 4 })`（上游 `padding(start = 4.dp, end = 4.dp, bottom = 4.dp)`）；字号由新字段 `bookshelfTitleSmallFont` 在 11（`labelSmall`）与 13（`labelMedium`）之间切 |
| 5 | 没有封面宽度设置 | 新增 `bookshelfGridCoverWidth`（默认 120）/ `bookshelfListCoverWidth`（默认 84），对齐上游 `BookshelfSettingsRepository.kt:82-83`；布局面板补「网格封面宽度」「列表封面宽度」两个步进器 |

**B 部分：无封面书的文字封面**

| # | 差异 | 修法 |
|---|---|---|
| 1 | 无封面时只显示一个书名首字 | 改成 `Canvas` 逐字绘制完整书名与作者，排版规则复刻上游 `CoilBookCover.kt`：书名 `w/8` 粗体、作者 `w/12`；竖排起点 `w*0.16 / h*0.16`、作者列 `w*0.84`；横排书名 3 行、作者居中 `h*0.75`；拉丁文占比 > 0.3 时强制横排（`CoilBookCover.kt:505-509`） |
| 2 | 没有居中书本图标 | 无封面时居中叠 `AppGlyph('book')`，占封面 35%，对齐上游 `CoilBookCover.kt:210-218` 的 `fillMaxSize(0.35f)` |
| 3 | 竖排/横排不可选 | 新增 `infoOrientation`（`'0'` 竖向 / `'1'` 横向），封面设置页可切 |
| 4 | 没有文字颜色、描边、阴影设置 | 新建 `data/CoverSettingsRepository.ets`，12 个字段与上游 `CoverSettings.kt` 逐项对齐（`showShadow` 默认 false、`showStroke` 默认 true、`useDefaultColor` 默认 true、日/夜两套文字色与阴影色、显示书名/作者开关） |
| 5 | 封面设置页是静态占位，改了不生效 | `AppCoverSettingsPage` 整体重写为受控页面，改动经 `Index.saveCoverSettings` 落 `legado_cover_settings` preferences 并即时回传书架 |

**模型裁剪（有意为之）**：本地没有 EInk 形态，上游 `ReadStyleItem` / `CoverSettings` 里与墨水屏相关的字段不引入；`CoverSettings` 只保留实际会参与绘制的那 12 项。

**踩到的坑（已修，留作记录）**：

- **`Canvas` 文字量纲**：`CanvasRenderingContext2D` 的 `context.width/height` 与绘制坐标同为 vp，但 `context.font` 字符串里的 `px` 是**物理像素**。一开始把 `onAreaChange` 拿到的 vp 宽度直接当像素算字号，字号小了 density 倍（本机 3.47），文字缩成一条条细线。正确写法是排版用 vp、写 `font` 时经 `vp2px()` 换算，`lineWidth` 保持 vp 量纲（换算成像素会粗一个 density 倍，字糊成一团）。
- **竖排基线**：第一字的 y 就是起点本身，不要再加一个字号（加了整体下移一格）。
- **日/夜文字色**：深色主题下生效的是 `*Dark` 那套，改日间颜色看不到变化，容易误判成「设置无效」。

**验收（第 3 级）**：A 部分 ①封面填满 5:7（3 列时 361 px 宽）②卡片与标题居中 ③间距 8/8/8 ④标题 padding 与 11/13 字号切换 ⑤封面宽度 50/200 生效且 200 时居中不撑满（694 px = 200vp × 3.47）✔；B 部分 ⑥无封面书显示图标 + 竖排书名/作者 ⑦竖向/横向切换 ⑧显示书名/作者开关（关书名时作者同隐）⑨文字颜色与阴影生效且冷启动保持 ✔。

### KI-STYLE1 背景样式区与上游的五处差异 —— 已对齐（含样式可增删）

全局设置页「背景」样式卡行原先与上游 `GlobalThemePage.kt` 的背景样式区有 5 处差异，本轮全部对齐：

| # | 差异 | 修法 |
|---|---|---|
| 1 | 选中态是卡片下方的小勾图标 | 改成**底部满宽横带 + 勾**（`ReaderSettingsPage.ets` 的 `BackgroundOption`：外层 `Column` 内分两段，下半段 `height(12).backgroundColor('#C6D3FF')` 里放 10×10 的勾），对齐上游 `StyleCard` 的 `Box(align BottomCenter, fillMaxWidth, height 12.dp)` |
| 2 | 没有「+」新增样式卡 | `ForEach` 之后追加 `BackgroundStyleActionCard($r('app.media.app_add'))` → `onAddBackgroundStyle()` |
| 3 | 没有最右侧主题列表入口卡 | 追加 `BackgroundStyleActionCard($r('app.media.reader_arrow_forward'))` → `openDetailSheet('主题列表', ...)`（本仓没有 chevron_right 图标，用等价的右箭头） |
| 4 | 样式卡只有 `onClick` | 加 `LongPressGesture({ duration: 500 })` → 选中该份 + `openDetailSheet('编辑背景样式', ...)`，对齐上游 `StyleCard.onLongClick → onOpenBgTextConfig` |
| 5 | `READER_BACKGROUND_STYLES` 是硬编码 6 条常量，不可增删 | 改成持久化的样式表（见下） |

**样式表模型**：`ReaderSettingsSnapshot` 新增 `backgroundStyles: ReaderBackgroundStyle[]`，随 `legado_reader_settings` 一起存（键 `backgroundStyles`，值是 JSON 字符串）。`ReaderBackgroundStyle` 在原有 `name`/`dayColor`/`nightColor` 之外补了 `id`。

- 上游 `ReadStyleItem` 还带 `bgType` / `textColor` / 三个 `*EInk` 字段，本地**故意不搬**：本地背景类型（`bgType`/`bgTypeNight`）与文字颜色是全局单份，不随样式独立，搬过来会让同一份状态有两个来源。
- `READER_STYLE_PRESET_COUNT = 5`（对齐上游 `ReadStyleState.kt:41`）。默认表仍是 6 条（上游 `readConfig.json` 就是 6 条），所以第 6 份「预设5」与上游一致地算**自建、可删可移**。
- `paperIndex` / `dayPaperIndex` / `nightPaperIndex` 的语义从「6 个内置方案的下标」扩成「样式表下标」，原来写死 `Math.min(5, ...)` 的四处（`ReaderSettingsRepository.save()` 三处、`clampStyleIndex`、`Index.setReaderPaperIndex`、`Index.getPaperColor`）都改成按 `backgroundStyles.length - 1` 夹取。
- 新增样式的背景**整组回默认纯色**（日间 `#EEEEEE`、夜间 `#000000`，即上游 `ReadBookConfig.Config()` 的构造默认值）、名字留空，对齐上游 `ReadBookConfig.asNewStyle()` 的「复刻排版但不继承背景图」；空名字在卡片上回落显示「背景样式」（上游 `StyleCard` 的 `ifBlank`）。
- 增删排序语义全部照上游：`removeReaderBackgroundStyle` 只允许 `index >= READER_STYLE_PRESET_COUNT`，删后 `paperIndex` 按「删的那份取前一份、之后的左移一位」修正；`moveReaderBackgroundStyle` 只在自建区内生效，下标按上游 `shiftIndexAfterMove` 的 `index==from→to; from<index<=to→index-1; to<=index<from→index+1` 修正。

**踩到的两个坑（已修，留作记录）**：

- `ForEach` 的 key 一开始用 `style.id`，于是**改名/改色后卡片不刷新**（id 没变，ArkUI 认为子项未变，界面一直显示旧名字，要重启才更新）。改成 `${style.id}|${style.name}|${style.dayColor}|${style.nightColor}` 后即时生效。
- 主题列表行里把 `.layoutWeight(1)` 写在名字 `Text` 上，会把 `Column` 撑高、名字与「预设/自建」标签被拉开一大截。`layoutWeight(1)` 要放在 `Column` 上并配 `justifyContent(FlexAlign.Center)`。

**验收（第 3 级）**：①选中态横带+勾 ✔（截图 crop `(100,2150,1280,2400)`）②「+」卡 ✔ ③「>」卡 ✔ ④长按开「编辑背景样式」✔ ⑤新增样式（卡片显示「背景样式」）✔ 删除自建样式 ✔ 上移排序 ✔ 改名后卡片即时更新 ✔ 冷启动后样式表与选中项保持（preferences 里 `backgroundStyles` 7 条、`paperIndex` 指向自建那份）✔。

## 关系型存储迁移第五批（r284）遗留

本节登记 2026-10-30 第五批（preferences 老数据清理）设备验收后仍待处理的三项。**第 1 项已于 r290 修掉，保留记录备查；第 2、3 项仍未处理。**

1. ~~**`RdbCleanup` 漏删两个键**~~ —— **已于 r290 修掉**。`legado_read_records` 里的 `details_v1` 与 `summaries_v1` 在 r284 清理时未被删除（当时只删了 `sessions_v1`），这两个键存的是第三批之前的老格式「按日明细」与「书籍汇总」，第三批起已改存 `readRecordDetail` / `readRecord` 两表，全仓 `.ets` 已无读取点（`grep -rn "details_v1\|summaries_v1" --include=*.ets` 零命中）。r290 的修法两处同时做：`entry/src/main/ets/data/RdbCleanup.ets` 的删除清单改为 `['sessions_v1', 'details_v1', 'summaries_v1']`；同文件 `markerKey` 由 `rdb_cleanup_v1_1` 提到 `rdb_cleanup_v1_2`——**只改第一处无效**，因为标记已写的设备不会重跑清理。详见[验证记录](VALIDATION.md)的「r290 修补」。

2. **书签与划线的设备验收在模拟器上走不通**。`bookmarks` 与 `book_marks` 在第五批验收中始终为 0 行，新代码下的写入路径未经验证。已验证可行的入口是：进阅读页 → 长按正文 → 选词菜单（复制 / 书签 / 划线·笔记，y 366–493）→ 点「书签」→「添加书签」面板 → 保存。但该手势在模拟器上极不稳定：本轮只在首次成功一次，之后 12 次循环探测、5 个不同纵坐标（900/1200/1500/1800/2100）、重启、双击、慢速拖拽、`uinput -T` 触摸轨迹、菜单开合状态下长按均无法复现；且**首次成功那一轮点「保存」落在了面板外**（面板关闭但未入库），保存按钮的准确 bounds 从未 dump 到。注意 `uitest uiInput longClick` 稳定返回 `No Error` 却不保证手势被应用识别，返回码不能当成功依据。这与 r281 节的既有结论一致（正文走滚动模式，长按划词在模拟器上一直不可靠），**不是本次改动引入的问题**。后续两条替代路径：① 数据层直接构造标记行 + 渲染像素比对（r281 验证划线渲染用的就是此法，做过「改 DB 颜色 → 界面由黄变红」的决定性验证）；② 改在真机上走完整 UI 闭环。另注意底栏默认只启用 `['search','autoPage','catalog','voice','settings']`（`entry/src/main/ets/data/ReaderSettingsRepository.ets:292`），`addBookmark` 不在其中，所以底栏没有书签按钮，长按选词是唯一入口。

3. **按书净化开关的冷启闭环未验**。`book_overrides_v1` 已搬进 `books.readConfig.useReplaceRule`，读写路径已构建通过（设备实测两本书的 `readConfig` 为 `{"reSegment":false,"fixedType":false}`，无 `useReplaceRule` 键，符合「未设置 = 跟随全局默认」），但「关掉某一本书的净化 → 冷启 → 仍关闭」这条闭环没有上机走。验收要点：关闭后 `books.readConfig` 应出现 `"useReplaceRule":false`，重启后阅读该书的替换仍不生效，重置后该键应重新消失。

## 阅读配置行登记（READER-CONFIG.md 的未接行）

本节登记 [READER-CONFIG 对照表](parity/READER-CONFIG.md) A–G 块里 **11 行 `未接`** 的「为什么不修」。编号 `KI-<块><组>` 与对照表「备注」列的标记一一对应，组内逐行列出覆盖的对照表行。**本节只登记不实施，本轮不改 `.ets` 代码。**

> 数字沿革：本节最初写于 r297，当时是 97 行 `未接`；r300–r316 深色模式与阅读配置各批落地后，实测已降到 **11 行**（189 行 = 176 已接 / 11 未接 / 2 不适用，用 `python scripts/reader-config-pending.py` 复算）。
>
> **2026-11-05 拆分**：本节原来把 30 个 KI 组全放在这里（含 22 个已实现组，516 行），占掉了整份文件的三分之一。现在只留 8 个仍未接的组（A4/A5/A8/A10/A11/A12/C6/D3），22 个已实现组的全文移到了 [阅读配置 KI 组落地记录](history/known-issues/reader-config-landed.md)（本机归档，不随公开仓库发布）。组的编号、标题、正文一字未改；对照表「备注」列的 `KI-xx` 标记仍指向本节——组标题不是标题级元素，从来没有独立锚点，所以搬迁不影响任何链接。

判定口径按[项目范围](PROJECT.md)：**在线书源抓取、RSS、TTS 朗读、WebDAV 自 2026-11-09 起已纳入范围、尚未排期**（见 `PROJECT.md:24-44` 的「在线服务」节），依赖它们的上游行为记「**要接，待排期**」而不记「不接」；仍在[范围之外](PROJECT.md)（`PROJECT.md:46-48`）的是 AI 在线服务、云同步与额外设备形态，这些不因开关已上屏而算已实现，记「不接」。上游没有的行为一律不补。凡上游行为在本地已有等价实现、或上游分支在本平台根本不存在，直接记「不接」；其余记「要接，待排期」并写补法。

与字段口径的关系：本节按 **A–G 明细表的行**登记（现 11 行）。对照表 §一 1.5 按**上游声明名**判定的 112 项里，另有 9 项判「不接」但不对应任何 KI 组，理由直接写在 1.5 表内，不在此重复——`menuBgColor`、`menuBgColorNight`、`menuAcColor`、`menuAcColorNight`、`menuBottomCornerRadius`、`menuBottomHorizontalMargin`、`menuBottomBottomMargin`（都是上游 `Config` 里 `@Transient` 的主题包承载字段，上游没有用户设置入口）、`readStyleSelect`、`comicStyleSelect`（图片书/漫画，本地无该内容形态，明细表 A 块已判 `不适用`）。两个口径不可相加。

### A 阅读界面基础

**KI-A4 优化正文渲染（不接）** —— 覆盖 A-07（`optimizeRender`，`ReadSettings.kt:49`）。

上游这条只在 `feature/reader/legacy/LegacyReaderPaginationStyleFactory.kt:49` 的 `Build.VERSION.SDK_INT <= Q`（Android 10 及以下）分支里生效，是给老设备减少渲染开销的兼容路径。HOS 没有对应的老渲染管线，接了也没有可切换的实现。**不补**；设置页该条保留占位文案，不假装生效。

**KI-A5 朗读与在线书源三项（要接，待排期）** —— 覆盖 A-09 朗读悬浮窗分离提醒（`readAloudDetachReminderEnabled`，`ReadBookConfig.kt:80`）、A-10 自动切换书源（`autoChangeSource`，`ReadSettings.kt:42`，含 `defaultSourceChangeAll:15`）、A-11 换源结果应用于全部书籍。

朗读（TTS）与在线书源抓取自 2026-11-09 起**已纳入范围、尚未排期**（[PROJECT.md](PROJECT.md) `:24-44`）；因开关已上屏，判 `未接`。补法：随对应子系统接入。

**KI-A8 使用新版目录（不接）** —— 覆盖 A-14（`useNewTocSheet`，`ReadSettings.kt:37`）。

上游这个字段是「阅读页内开 Sheet」与「跳独立目录页」两种呈现的切换开关（`ui/book/read/ReadBookViewModel.kt:193`）。本地目录固定为 `CatalogPage.ets` 独立页一种形态，没有第二态可切。为它造一个不存在的新旧目录等于凭空加功能，**不补**。

**KI-A10 主题网格列数（不接）** —— 覆盖 A-18（`themeGridColumns`，`ReadSettings.kt:40`，默认 4）。

本地背景/主题是 `READER_BACKGROUND_STYLES` 六个内置方案的自绘列表（`entry/src/main/ets/data/ReaderSettingsRepository.ets:339-346`，入口 `ReaderSettingsPage.ets:1281`），不是网格布局，该字段没有消费面。**不补**；将来若把面板改成网格，再一并接。

**KI-A11 预下载两项（要接，待排期）** —— 覆盖 A-19 向后预下载章节数（`preDownloadNum`，`ReadSettings.kt:58`，默认 10）、A-20 向前预下载章节数（`preDownloadNumPrev`，`:59`，默认 0）。

依赖离线缓存/预下载子系统；本地 `AppDownloadCacheSettingsPage.ets:31` 是预览页，没有缓存实现。预下载服务于在线书源，后者自 2026-11-09 起**已纳入范围、尚未排期**（[PROJECT.md](PROJECT.md) `:24-44`），故记「要接，待排期」。补法：随下载缓存子系统与在线书源一起接入。

**KI-A12 在浏览器打开（要接，待排期）** —— 覆盖 A-21（`readUrlInBrowser`，`ReadSettings.kt:64`）。打开的是书源页面，随在线书源一起做。

需要外部应用跳转（`module.json5` 的 browser skill），属跨应用能力而非配置接线。补法：加 browser skill 后用 `startAbility(ACTION_VIEW)` 打开。打开的是书源页面，随在线书源一起排期（[PROJECT.md](PROJECT.md) `:24-44`）。

### C 正文排版

**KI-C6 字体文件夹（不接）** —— 覆盖 C-26（`fontFolder`，`ReadSettings.kt:79`）。

上游是「用户指定一个目录，扫描其中所有 TTF/OTF」（`ui/book/read/ReadBookScreen.kt:470`）。HOS 应用无法递归扫描任意用户目录；本地等价能力是 `ReaderFontRepository.listFonts()` 列系统字体 + 导入字体到应用私有目录（r265 起可用），入口就在排版设置面板。**不补**，差别只在导入方式。

### D 翻页与手势交互

**KI-D3 朗读时允许音量键翻页（要接，待排期）** —— 覆盖 D-04（`volumeKeyPageOnPlay`，`ReadSettings.kt:30`）。朗读子系统未接入，随 TTS 一起做。

### E 菜单与主题外观

**整块共同的前置条件（2026-11-09 重写）**：这段原写「本地阅读页没有菜单外观渲染层，`readMenu*`/`titleBar*` 只命中 `data/BackupRepository.ets`，`ReaderPage.ets` 零命中」——**已被 READER-CONFIG 批 4/E 块落地推翻**。实测 `pages/ReaderPage.ets` 有 **121 处** `readMenu*`/`titleBar*` 命中，是真消费点：底栏圆角与悬浮（`:6529`/`:6539`-`:6544`/`:6560`）、底栏模糊与液态玻璃（`:1175`/`:1192`）、顶栏模糊与合并按钮（`:1206`/`:1242`）、菜单底色/容器色/强调色/文字色日夜分叉（`:1277`/`:1289`/`:1299`/`:1322`）、边框与模糊半径透明度（`:1333`/`:1346`/`:1367`）、顶栏标题胶囊与 `titleBarMode`（`:2998`-`:3014`）、悬浮图标玻璃与位置（`:3130`/`:6412`/`:6429`）；字段存在 `data/ReaderSettingsRepository.ets`（该文件 2085 行、`readMenu` 命中 215 处、`load` `:780` / `save` `:1562`），`pages/ReaderSettingsPage.ets`（3954 行）是设置入口。**结论：这一整块现在已经接了渲染层**，下面各条的判断按当年记录保留，不再把「没有渲染层」当共同前提。

**另有一层备份侧证据（2026-11-09 复核）**：这些 `readMenu*` 外观键在 `config.xml` 的两个方向都只走了一部分——导出段是 `BackupRepository.ets:822`-`:943`（49 处 upsert），**其中没有一处写 `readMenu*` 键**（该段只命中 `:928` 注释与 `:931` 的 `titleBarCompact`）；恢复段 `restoreReaderSettings`（定义 `:1883`）只读回四个：`readMenuIconShowText`（`:2145`）、`readMenuIconStyle`（`:2148`）、`readMenuIconItemsPerRow`（`:2150`）、`readMenuIconRowCount`（`:2152`）。这批键同时列在 `preferenceKeysByCategory.readConfig`（`:384`-`:406`）里作类别忽略时的排除名单。→ **准确的说法是「本地有渲染层、有本地持久化，但安卓备份里的菜单外观值几乎读不进来」**，不再是「没有渲染层」。

### B 页眉页脚

B 块唯一的 `未接` 行（页眉/页脚独立字体）已于 2026-10-31 复核改判 `已接`：排版设置面板的字体目标四按钮可选「页眉」「页脚」并落 `headerFont`/`footerFont`。**残留问题（2026-11-09 复核：已不存在）**：原文说「页眉页脚 tab 里那条「选择字体」仍走 `showNotMigrated('页眉/页脚字体选择')`」。实测 `grep -rn "页眉/页脚字体选择" entry/src/main/ets` **零命中**，`showNotMigrated` 全仓只剩 9 处调用，无一处与该文案相关；`ReaderSettingsPage.ets:799`-`:801` 现在是护眼/日夜相关的 `.fillColor`/`Image(app_moon)` 段。→ 这条占位已随排版设置面板的字体目标四按钮一并清理，不用再补。

## 深色模式行登记（ZIP-THEME.md 的未接行）

本节登记 [深色模式对照表](parity/ZIP-THEME.md) A–F 块里 **6 行 `未接`**（r298 建表时是 83 行，r300–r316 逐批落地后降到 6 行；22 个 KI 组里 18 个已实现的全文已移到 [深色模式 KI 组落地记录](history/known-issues/theme-landed.md)，本机归档、不随公开仓库发布）的「接不接、怎么接」。编号 `KI-TH-<块><组>` 与对照表「备注」列的 `**要接**` / `**不接**` 标记一一对应，组内逐行列出覆盖的对照表行。**本节只登记，除阶段一（r300）已落地者外不改 `.ets` 代码。**

判定口径按[项目范围](PROJECT.md)：**在线书源抓取、RSS、TTS、WebDAV 自 2026-11-09 起已纳入范围、尚未排期**（`PROJECT.md:24-44`），依赖它们的上游行为记「要接，待排期」；仍在[范围之外](PROJECT.md)（`PROJECT.md:46-48`）的 AI 在线服务、云同步与**额外设备形态适配**不因开关已上屏而算已实现；上游没有的行为不补；上游机制在本平台根本不存在的不照抄。判「不接」的**不删行、不改状态**，对照表里仍按 `未接` 计，只在备注与本节点明理由。

**与对照表状态的关系**：对照表状态只有 `已接 / 未接 / 不适用` 三值，不设「部分接」。本节的 `要接` 是排期结论，`不接` 是范围结论，两者都不改变对照表的 `未接` 状态——只有真正落地并验证过才改 `已接`。

**83 行的排期去向**：r298 建表时 83 行 `未接`，按「阶段一 6 行 → 阶段二 61 行 → 阶段三 16 行」排期，其中 `不接` 5 行。r300–r316 逐批落地后，75 行转 `已接`、4 行判 `不适用`，剩 **6 行 `未接`**（全部是 `不接`）。每一批落地时改判了哪几行、为什么改判、设备实测到什么，逐批记录在[深色模式 KI 组落地记录](history/known-issues/theme-landed.md) 里对应组的「本轮判定」段。

**全局前置**：这 83 行里 **78 行都要先有 F4（两套颜色资源）**才可能「看起来变了」。F4 没落地时，任何开关即使接了状态，界面也不会有可见变化——这是本表与其它对照表最大的不同，排期不能按「先接开关、后补皮肤」的顺序做。

### A 主题设置页

**A 块共同前提（2026-11-09 重写）**：这段原写「本地 `pages/ThemeSettingsPage.ets`（333 行）整页零持久化、39 处一律 `onUnavailableAction`」，**已被 r300–r316 逐批落地推翻**。实测该页现 **1070 行、7 个 `@State` + 88 个 `@Prop`、125 个回调 prop**，`onUnavailableAction` 只剩 **4 处真实占位**（`:548` 主题风格切换、`:550` 切换图标、`:724` 导航布局、`:726` 多窗布局），持久化走 `data/ThemeSettingsRepository.ets` 的 `ThemeSnapshot`（`load`/`save` 逐键读写）与 `data/MainNavigationSettings.ets`、`data/TopBottomBarSettings.ets`、`data/BookInfoBackdropStyle.ets`、`data/CustomThemeColors.ets`、`data/ThemePalette.ets` 六个配套模块。下面各组「已实现」的落地记录仍是准的，只有这段前提过时。

**KI-TH-A2 Miuix 引擎两项（不接）** —— 覆盖 A3 Miuix 动态取色（Monet）、A7 主题引擎切换。

**判定理由**：`composeEngine` 是上游 Compose 侧的**全局渲染分支开关**，`ui/theme/LegadoTheme.kt` 暴露后被 30+ 处读取，决定用 Miuix 还是 Material 控件；`useMiuixMonet` 只在 `isMiuixEngine` 为真时出现（`ThemeConfigScreen.kt:199` 在 `:187` 的引擎分支内）。ArkUI 只有一套控件体系，**没有可切换的等价分支**，也没有引擎概念，因此这两行按「上游机制在本平台根本不存在」判不接。

**保留部分**：`composeEngine` 与 `useMiuixMonet` 两个键仍在 `data/BackupRepository.ets:407`-`:423` 的 53 键组里，随 themeConfig 备份进出（F6 已接），只是没有界面。本地 `:138`「主题风格」这一行**不改成引擎切换**——文案与上游 `compose_engine` 语义不同，按文案对齐会错。

**验收**：无（不接）。备份里出现 `composeEngine` 键时原样保留、不报错。

**KI-TH-A5 主界面组六项（A14 已实现 r311、A17 已实现 r312、A15/A16 已实现 r304 / 不接 2）** —— 覆盖 A14 首页与导航、A15 显示状态栏、A16 启用滑动时动画、A17 顶栏与底栏、A18 平板界面（**不接**）、A19 多窗布局（**不接**）。

**上游口径**：A14 sheet 可拖排主导航顺序、逐项显隐（`SetMainNavigationOrder`/`SetMainDestinationVisible`）；A15 `showStatusBar`；A16 `enableSwipeAnimation`；A17 sheet 10 个键（`topBarOpacity`/`bottomBarOpacity`/`topBarBlurRadius`/`bottomBarBlurRadius`/`topBarBlurAlpha`/`bottomBarBlurAlpha`/`topBarHeight`/`bottomBarHeight` 等）；A18 `tabletInterface`、A19 `multiPaneMode` 都按设备形态显示。

**判定**：A14–A17 **要接**（A14 已 r311、A17 已 r312 落地）；A18 平板界面与 A19 多窗布局属**额外设备形态**，按 [项目范围](PROJECT.md)「范围之外」判**不接**——本地 `:161` 的「多窗布局」条目保留在界面上，但不实施、不删行。

**补法**：**A17 已在 r312 落地**：新建 `entry/src/main/ets/data/TopBottomBarSettings.ets`（`TOP_BAR_BUTTON_STYLES` 五档 + `topBarButtonStyleLabel` 逐条对齐上游 `values-zh-rCN/arrays.xml:226-232`、`TopBottomBarSnapshot` 15 字段、7 个 `normalize*`、`resolveBarBackgroundColor` 按上游 `GlassDefaults.glassColor()` + `AppNavigationBar.kt:60` 合成、`resolveTopBarBackground`/`resolveBottomBarBackground`/`resolveBottomBarCornerRadius`）；`data/ThemeSettingsRepository.ets` 的 `ThemeSnapshot` 增加 15 字段（现 53 字段）；`pages/Index.ets` 新增 15 个 `@State`、`topBottomBarSnapshot()`、`publishTopBottomBarStyle()`（广播 `themeTopBarBackground`/`themeBottomBarBackground`/`themeTopBarBlurRadius`/`themeBottomBarBlurRadius`/`themeBottomBarRadius` 五个键）与 15 个 `selectTheme*` 回调；底栏渲染改成 `if (this.themeShowBottomView && ...)`，并按 `useFloatingBottomBar` 改宽度/圆角、按合成色设底色、按 `enableBlur` 挂 `backdropBlur`；顶栏底色由 `components/CollapsingSettingsHeader.ets`（12 个设置子页）与 `HomePage.ets`/`SearchPage.ets`/`ThemeSettingsPage.ets` 三处内联 header 消费。A18/A19 不动。**A14 已在 r311 落地**：新建 `data/MainNavigationSettings.ets`（`MAIN_NAVIGATION_ROUTES`、`mainNavigationLabel`、`orderedMainNavigation` 逐条对齐上游 `MainDestination.ordered` 的「过滤未知与重复 + 补齐未出现项」、`moveNavigationUp`/`moveNavigationDown`、`normalizeDefaultHomePage` 的不可见回落、`isMainDestinationVisible`/`visibleMainNavigation`）；`data/ThemeSettingsRepository.ets` 的 `ThemeSnapshot` 增加 `showHome`/`showDiscovery`/`showRss`/`defaultHomePage`/`mainNavigationOrder`/`labelVisibilityMode` 六字段（现 38 字段）；`pages/Index.ets` 的底栏由 5 个硬编码 `TabItem` 改为 `ForEach(this.visibleNavigationRoutes())`，并新增 `applyDefaultHomePage()`（启动与关掉当前页时回落）；`pages/ThemeSettingsPage.ets` 的「首页与导航」改为可展开组（三枚显隐开关 + 默认主页面下拉 + 导航标签显示下拉 + 逐项上下移按钮）。**与上游的差异**：上游用可拖列表（`rememberReorderableLazyListState`）改顺序，本地用「上移/下移」两枚按钮承接同一个 `onSetOrder` 语义；上游还有「导航栏图标」子 sheet（`NavIconManageSheet`，10 个自定义图标键），本地未做。**A15 已在 r304 落地**：`pages/ThemeSettingsPage.ets` 的「显示状态栏」改为 `@Prop showStatusBarVisible` + `onShowStatusBarChange`；`pages/Index.ets` 的 `selectThemeShowStatusBar()` 写 `themeShowStatusBar` + `applyThemeStatusBar()`（`setSpecificSystemBarEnabled('status', visible, false)`）+ 落盘；`restoreOnboarding()` 启动时读回并应用。**A16 已在 r304 落地**：同构的 `themeSwipeAnimation` / `selectThemeSwipeAnimation()`，**只落盘不造效果**——上游这个键本身没有任何渲染消费者（`ThemeConfigScreen.kt:361` 原文 TODO「这个可以不要了」），照实对齐现状。

**验收**：A15 已验（r304：关掉 → 顶部状态栏立即消失、页面顶到屏幕边，重启仍隐藏，prefs `showStatusBar` = `false`）；A16 已验（r304：关掉 → prefs `swipeAnimation` = `false`，重启后开关仍为关）；A14 已验（r311：①关「首页」→ 底栏 5 项变 4 项，截图 changed pixels 25092；②`mainNavigationOrder` 改 `my,home,bookshelf,explore,rss` 重启 → 底栏首项变「我的」；③`defaultHomePage` 改 `explore` 重启 → 冷启动停在发现页；④关掉「发现」且默认页是发现 → 自动回落书架）；A17 已验（r312：①关「显示导航栏」重启 → 底栏消失，`(640,2700)` 由 `(255,255,255)` 变 `(245,246,248)`；②「顶栏按钮样式」选「液态玻璃」→ prefs `topBarButtonStyle=liquid`；③开「悬浮底栏」→ 底栏变胶囊；④`bottomBarOpacity=40` 重启 → 底栏底色 `(255,255,255)`→`(249,250,252)`；⑤`topBarOpacity=40` 重启 → 外观页顶栏像素 `(16,15,13)`→`(107,107,107)`、`ImageChops` bbox `(0,56,1280,616)`、changed 616208；⑥拖「顶栏模糊半径」→ prefs `topBarBlurRadius` 24→7）；A18/A19 无（不接）。

**KI-TH-A6 书籍详情页组四项（A20/A21/A22 已实现 r307，A23 不接）** —— 覆盖 A20 界面颜色跟随封面取色、A21 网络封面背景设置、A22 默认封面背景设置、A23 作者搜索回退。

**本轮判定**：A20/A21/A22 要接，r307 已实现；A23 不接——上游唯一消费者 `BookInfoViewModel.kt:2007-2016` 依赖书源实体 `source.ruleBookInfo.relatedBooks`，本地无网络书源（`entry/src/main/ets/` 里 `bookSource` 只作为备份/规则壳出现），属 [项目范围](PROJECT.md)「在线书源抓取…不因出现在页面或备份归档中而视为已实现」。

**上游口径**：
- A20 `ThemeConfigScreen.kt:399` → `BookInfoScreen.kt:807-847 rememberBookInfoColorTheme`：`book == null || !enabled || !followCoverColor` 时返回 null；取色用 `ImageSeedColorExtractor.kt` 的 `QuantizerCelebi.quantize` + `Score.score`，常量 `IMAGE_COLOR_EXTRACT_SIZE_PX = 128`、`IMAGE_QUANTIZE_BITMAP_MAX_SIZE = 64`、`IMAGE_MAX_QUANTIZE_COLORS = 64`、`IMAGE_FALLBACK_SEED_COLOR = 0xFF4285F4`；叠层是 `lerp(secondaryContainer, seedColor, 0.42f)` 再 `alpha 0.34`。
- A21/A22 `ThemeConfigScreen.kt:407`/`:416` 两个 `DropdownListSettingItem`，值域 `off`/`on`/`off_for_default`（`res/values/array_values.xml:135-139`），中文文案 `关闭模糊封面`/`开启模糊封面`/`不显示背景封面`（`values-zh-rCN/strings.xml:1751-1753`）；语义在 `BookInfoBackdropStyle.kt:9-30`：`off` → (showCover=true, blurCover=false, applySeedOverlay=true)、`off_for_default` → 全 false、else → (true, true, true)。`BookInfoScreen.kt:863-875` 按 `usesDefaultCover` 在两个键之间选。
- A23 见上「本轮判定」。

**本地落地**（r307）：
1. `data/ThemeSettingsRepository.ets`：`ThemeSnapshot` 扩到 8 字段，新增 `bookInfoFollowCoverColor`/`bookInfoNetworkCoverBackground`/`bookInfoDefaultCoverBackground`；导出 `BOOK_INFO_BACKGROUND_OFF`/`BOOK_INFO_BACKGROUND_ON`/`BOOK_INFO_BACKGROUND_OFF_FOR_DEFAULT` 与 `normalizeBookInfoBackground`；`load`/`save` 逐键读写。
2. 新建 `data/BookInfoBackdropStyle.ets`：`BookInfoBackdropStyle` 三字段 + `resolveBookInfoBackdropStyle(backgroundMode)`（三档语义逐条照抄上游）+ `resolveBookInfoBackdropStyleFor(usesDefaultCover, defaultCoverBackground, networkCoverBackground)`。
3. 新建 `data/ImageSeedColorExtractor.ets`：`ImageSeedColorExtractor.extract(uri)` 用 `image.createImageSource` → `createPixelMap({ desiredSize: { width: 16, height: 16 } })` → `readPixelsToBufferSync` 取像素均值，再按 1.6 倍提饱和度；失败回落 `#4285F4`。
4. `pages/ThemeSettingsPage.ets`：书籍详情页组三项改真回调；新增 `ThemeSettingsDropdown` 组件（`bindMenu` + `MenuItem`，与 `OtherSettingsPage.ets` 的 `OtherSettingsDropdown` 同写法）。
5. `pages/Index.ets`：新增 `@State bookInfoFollowCoverColor`/`bookInfoNetworkCoverBackground`/`bookInfoDefaultCoverBackground`、`selectBookInfoFollowCoverColor`、`selectBookInfoCoverBackground`，并接进 `saveThemeSettings` 与 `restoreOnboarding`。
6. `pages/BookInfoPage.ets`：新增三个 `@Prop`、`backdropStyle()`、`loadCoverSeedColor()`、`seedOverlayColor()`；背景封面按 `showCover`/`blurCover` 分支，叠层按 `applySeedOverlay` 挂载。

**与上游的两条差异**（如实记录）：
- 取色算法不同：上游是 Celebi 量化 + Score 打分，本地是 16×16 像素均值 + 提饱和——都产出「代表封面的主色」，但同一张图给的具体色值不会相同。
- 叠层取色不同：上游 `lerp(secondaryContainer, seedColor, 0.42f)`，本地直接用主色（A2 未接，本地没有 secondaryContainer 这一层）。

**验收**（2026-11-01 模拟器实测通过，见 [验证记录](VALIDATION.md) r307 节）：
- A20：开/关「界面颜色跟随封面取色」→ 详情页顶部同一区域平均色 `(87.2, 88.9, 156.9)` → `(81.9, 83.9, 142.7)`。
- A21：三档各重启一次进详情页——`on` 背景模糊、`off` 背景清晰、`off_for_default` 背景封面整块消失。
- A22：设置页选「不显示背景封面」→ 重启 → prefs `bookInfoDefaultCoverBackground` 为 `off_for_default`。

### B 主题包管理

**B 块整体判定：12 行已在 r316 全部落地（`已接`）。** r316 之前本地没有主题包这个概念——`pages/ThemeSettingsPage.ets:563` 的「主题管理」是 `onUnavailableAction('主题包管理尚未迁移')`，入口文案在、页面不在。上游是三份文件：`help/config/ThemePackageManager.kt`（1254 行）、`help/config/ThemeImportExport.kt`（393 行）、`ui/config/themeManage/EditThemeSheet.kt`（403 行），加列表页 `ThemeManageScreen.kt`（331 行）。r316 新建了一整页 + 一套包格式，逐行落地情况见下三节。

### C 首次启动向导

### D 阅读页日夜快捷按钮

**D 块前提**：本地阅读页**有**日夜按钮（`ReaderPage.ets:3162` 的 `else if (kind === 'theme') { this.onToggleNightMode(); }` 与 `:7154` 的动作条图标、`ReaderSettingsPage.ets:800`-`:802` 「背景」行的月亮 `Image(app_moon/app_daynight)` + `onToggleNightMode()`），切的是阅读页私有 `readerNightMode` 布尔（`ReaderSettingsRepository.ets:165`），**不写全局 `themeMode`**。所以 D 块的问题不是「按钮没有」，是「按钮只管自己那一页」。

### E 日夜提醒

**E 块整体判定：7 行里 6 行已实现（r302 核实）、1 行不接。** r297 盘点时判「本地只有 `ReaderSettingsPage.ets:898` 一个开关壳、全仓零命中」是**误判**——提醒机制其实早已存在于仓库（`pages/Index.ets` 的传感器订阅与判定、`pages/ReaderPage.ets` 的提醒胶囊、`pages/ReaderSettingsPage.ets:1495` 的真开关、`data/ReaderSettingsRepository.ets:240-241/1583` 的持久化），只是当时没查到。r302 逐行核实后 E1–E6 改判 `已接`，并在模拟器上验通了胶囊弹出、5 秒消失、点击切换、关闭后不再弹四条。

**KI-TH-E3 提醒的 intent/effect 链路（不接）** —— 覆盖 E7。

**判定理由**：本地阅读页用 `@Prop` 回调直连（`onToggleNightMode`），**没有 intent/effect 分层**，这是架构差异而非缺功能。上游这一层还有历史包袱：`ReadBookContract.kt:1271 data object ToggleDayNight : ReadBookEffect` 定义了但 `ReadBookController.kt:2563-2565` 注释写明「Handled directly by ViewModel — effect not currently emitted」，即**上游这个 effect 从不发出**。为一行从不生效的分层引入整套架构，违背「上游没有就不要这个效果」。

**保留部分**：提醒的实际行为在 KI-TH-E1/E2 里直接实现，不依赖该层（这两组的全文已移到本机归档 `docs/history/known-issues/theme-landed.md`）。

**验收**：无（不接）。提醒功能照 KI-TH-E2 的验收走（验收原文见本机归档 `docs/history/known-issues/theme-landed.md`）。

### F 网关与全局换肤

**F 块是整张表的地基**：F1/F2/F3/F4 四行不落地，A/B/C/D/E 五块的所有开关接了也不会有可见变化。这四行必须在阶段一一起做完。

## 书架布局行登记（ZIP-BOOKSHELF-LAYOUT.md 的未接行）

本节登记 [书架布局总账](parity/ZIP-BOOKSHELF-LAYOUT.md) A–F 块里 43 行 `未接` 的「接不接、怎么接」。编号 `KI-SL-<块><序号>` 与对照表「备注」列的 `**要接**` / `**不接**` 标记一一对应，组内逐行列出覆盖的对照表行号（行号为 ZIP-BOOKSHELF-LAYOUT.md 的行号）。**本节只登记，不改 `.ets` 代码。**

**判定口径**：按 [PROJECT.md](PROJECT.md) 与 PARITY-RULES.md 第三节。在线书源抓取自 2026-11-09 起已纳入范围（`PROJECT.md:24-44`，尚未排期），依赖它的行记「要接，待排期」；仍在[范围之外](PROJECT.md)（`PROJECT.md:46-48`）的只有 AI 在线服务、云同步与额外设备形态。判「不接」的**不删行、不改状态**，对照表里仍按 `未接` 计，只在备注与本节点明理由。

**与对照表状态的关系**：ZIP-BOOKSHELF-LAYOUT.md 只有 `已接 / 未接 / 不适用` 三值，不设「部分接」。本节的 `要接` 是排期结论，`不接` 是范围结论，两者都不改变对照表的 `未接` 状态。全表 122 行 = 76 已接 / 43 未接 / 3 不适用（r331/r332 落 38 行后）；43 行未接 = 2 `要接` + 41 `不接`。

**排期分布**：40 条 `要接` 里 **38 条已在 r331/r332 落地**（对照表状态转 `已接`），**剩 2 条未接**——`**要接**` 的两行即「首屏封面预加载列数」与「书架设置字段全集（51 字段）」。41 条 `不接` 里 11 条依赖「列表模式」这一不存在的前提，10 条是角标与提示类，其余分散在标签体系、标签配色、分组卡片增强、批量更新、加载态与锁定书。

**全局前置（三条均已在 r331/r332 落地）**：这三件原本是 `要接` 组的前置障碍，现在全部完成，保留清单只为说明「当初为什么按这个顺序排」——

1. **列表模式**：已做。`pages/BookshelfPage.ets` 现在有独立的列表分支（`bookshelfLayout*List*` 一套键），不再是「把网格列数压成 1 列」。
2. **横竖屏取值**：已做。`pages/BookshelfPage.ets:99-100` 有 `@State isLandscape`，`:169 this.isLandscape = rect.width > rect.height;` 订阅 `windowSizeChange` 后立即刷新，Landscape 那套字段（`bookshelfLayoutGridLandscape` 等）都已接上。
3. **分组样式第三档**：已做。`model/BookshelfLayout.ets:98-102` 的 `BOOK_GROUP_STYLE_OPTIONS` 现在是三项 `{ value: 0, label: '页签' }`、`{ value: 1, label: '隐藏页签' }`、`{ value: 2, label: '文件夹' }`，文件夹视图（`folderViewGroup`）已实现。

### A/B/E 的未接行（11 组要接 / 9 组不接）

**KI-SL-A1 分组样式三档与文件夹视图** —— 覆盖 A 块 `:40`、`:44`、`:45`、`:46`、`:48`、`:49`，E 块 `:179`（共 7 行）

- **上游口径**：`bookGroupStyle` 三档（`BookshelfConfigSheet.kt:84-90`，`values-zh-rCN/arrays.xml:24-28` = 标签 / 隐藏标签 / 文件夹）；第 2 档出现后，`BookshelfScreen.kt:983` `if (bookGroupStyle == 2 && isRoot …)` 改走文件夹网格，`:1023` 再按 `bookshelfFolderLayoutMode` 决定 `BookGroupItemList` 还是网格；配置面板随之展开文件夹的布局模式（`:143`）、网格列数（`:164`）、列表列数（`:186`）、列表样式（`:220`）、横排封面数（`:230`）。
- **本地现状**：`entry/src/main/ets/pages/BookshelfPage.ets:585-587` 只有一个开关，写值只有 0/1；`entry/src/main/ets/model/BookshelfLayout.ets:43-46` 选项数组两项；无文件夹根视图、无 `bookshelfFolderLayoutMode*` / `bookshelfFolderLayoutGrid*` / `bookshelfFolderLayoutList*` / `bookshelfGroupListStyle` / `bookshelfGroupCoverCount` 字段。
- **补法**：`BookshelfLayout.ets` 先补 8 个字段，并在 `entry/src/main/ets/data/BookshelfLayoutRepository.ets` 的 `load`（`:30-66`）/ `save`（`:69-93`）/ `mergeFromAndroidValues`（`:101-133`）/ `toAndroidValues`（`:136-152`）四处同步键名（键名照 `entry/src/main/ets/data/BackupRepository.ets:424`-`:438` 的 39 键数组）；面板把 `LayoutSwitchRow` 换成三档 `LayoutMenuRow`；渲染层在 `BookshelfPage.ets:719-733`（页签区）与 `:734-799`（卡片区）之间插入文件夹根视图分支。
- **验收**：面板选「文件夹」后，书架根层显示分组卡片（每张卡显示组内前 N 个封面），点进去是该组的书；返回回到根层；横竖屏各一套列数。
- **已实现（r331）**：A 块 `:40`、`:44`、`:45`、`:46`、`:48`、`:49`，E 块 `:179` 共 7 行已改 `已接`。`BookshelfLayout.ets:95-99` 补第三档「文件夹」并新增 `:114-118` / `:120-124` 两组选项；`BookshelfPage.ets:796-798` 分组样式开关改三档下拉、`:803-834` 展开文件夹六项与列表样式/横排封面数面板、`:1008-1018` 文件夹导航条、`:1033-1053` 根层分组卡片网格、`:266-289` 进组/返回、`:569-601` 按方向取六值。新建 `components/BookGroupCard.ets`。截图 `b5-folder-root.png`（根层）/ `b5-folder-inside.png`（组内）/ `b5-back.json`（返回）/ `b5-panel-expanded.png`（面板）。**横屏三行 C `:142`/`:143`/`:144` 与 C1 同型，代码已落地但本机模拟器无旋转入口、设备横屏行为未验，留 `未接`，卡点见证据包第 4 节。**

**KI-SL-A2 网格样式与紧凑模式** —— 覆盖 A 块 `:51`、`:59`，B 块 `:98`、`:122`（共 4 行）

- **上游口径**：`bookshelfGridLayout` 三档「标准 / 紧凑 / 仅封面」（`BookshelfConfigSheet.kt:273`，`values-zh-rCN/arrays.xml:249-253`），只在 `layoutMode == 1`（网格）时出现（`:267`）；`BookItem.kt:110` 在 `gridStyle == 1` 时把标题画在封面内（白字），`:135` 在 `gridStyle == 0` 时画在封面下方。`bookshelfLayoutCompact`（`:388` `compact_details`）进入 `BookItem.kt:230` 与 `:738`，控制卡片是否渲染作者 / 简介等副信息。
- **本地现状**：无 `bookshelfGridLayout`、无 `bookshelfLayoutCompact`；网格卡片恒为「封面 + 封面下方的书名」（`BookshelfPage.ets:738-755`），书名位置写死。
- **补法**：两字段进 `BookshelfLayout.ets` + 仓储四处；渲染层在 `BookshelfPage.ets:749-754` 外面加 `gridStyle` 分支（1 → 书名移进 `BookCover` 上叠层，2 → 不渲染 `Text`）；`compact_details` 打开时补渲染作者行。
- **验收**：选「仅封面」后网格卡片不再显示书名；选「紧凑」后书名变封面内白字；开「精简详情」后卡片只留封面与书名。
- **已实现（r331）**：A 块 `:51`、`:59` 与 B 块 `:98`、`:122` 已改 `已接`。字段与面板条目在 `BookshelfPage.ets:692-694`（网格样式）/`:714-715`（精简详情）；渲染在 `:859-899`。三张截图 `a2-compact.png` / `a2-coveronly.png` / `b2-default.png`，重启后值保持见 `b2-restart.json`。验收方式已写进总账对应行。

**KI-SL-A3 分组列表样式与横排封面数** —— 覆盖 B 块 `:109`、`:110`（共 2 行）

- **上游口径**：`bookshelfGroupListStyle` 三档「分组 / 紧凑列表 / 横排封面数量」（`BookshelfConfigSheet.kt:220-226`，`entryValues` `"0"`/`"1"`/`"2"`）；`BookItem.kt:504` 在 `== 2` 时走 `BookGroupItemHorizontalCovers`，`:530` 在 `== 1` 时置 `isCompact = true`；`bookshelfGroupCoverCount` 由 `:627-628` `previewBooks.take(coverCount)` 消费，`:657` 不足时补 `Spacer`，面板入口在 `BookshelfConfigSheet.kt:230`（仅 `bookshelfGroupListStyle == 2` 时出现，`:229`）。
- **本地现状**：无这两个字段；分组从不以卡片形式出现在书架网格里。
- **补法**：随 KI-SL-A1 一起补字段与仓储；`BookGroupItemHorizontalCovers` 在本地需要新建分组卡片组件，横排封面数取 `bookshelfGroupCoverCount`。
- **验收**：选「横排封面数量」并把数量改为 6 后，分组卡片一行 6 个封面，不足 6 本时右侧留空。
- **已实现（r331）**：B 块 `:109`、`:110` 已改 `已接`。新建 `components/BookGroupCard.ets`：`previewBooks()`（`:29-32`）按 `coverCount` 取前 N 本、`emptySlots()`（`:35-40`）补不足空位、`listStyle===2`（`:51-72`）走横排封面分支、`===1` 紧凑、`===0` 普通；点击整卡 `onOpen` 进组。数量 4→6 后样本每组仅 1 本 → 1 封面 + 5 空位右侧留空，见 `b5-folder-covercount6.png`，重开读回 6 见 `b5-reopen.json`。

**KI-SL-A4 卡片背景色（日 / 夜）** —— 覆盖 A 块 `:57`、`:58`，B 块 `:105`（共 3 行）

- **上游口径**：`bookshelfCardColor` / `bookshelfCardColorDark`（`BookshelfConfigSheet.kt:346` 日间、`:367` 夜间，写回 `:680` / `:689`），消费在 `BookItem.kt:176`、`:570`；ZIP 类别按「会动到哪个类别」判为 `bookshelfLayout / themeConfig`（两色键同时进主题导出：`data/repository/ThemePackageSettingsRepository.kt:76-77`、`domain/model/settings/ThemeExportData.kt:62-63`）。
- **本地现状**：卡片底色取自主题，无这两个字段。
- **补法**：字段 + 仓储四处；卡片外层容器按 `isNight` 取对应色，未设（0）时回落主题色。
- **验收**：日间色改为米色后亮色模式卡片底色变米色、暗色模式仍取夜间色；两色都设为 0 时与现在一致。
- **已实现（r331）**：A 块 `:57`、`:58` 与 B 块 `:105` 已改 `已接`。`ColorPickerRow` 在 `BookshelfPage.ets:630-642`（复用 `CustomThemeColors.ets:100-105` 的 `normalizeCustomColor`），取色在 `:528-532` `cardBackgroundColor()`。日/夜两色 hex 输入重启后值保持见 `b2-restart.json`，生效截图 `b2-colors-applied.png`。

**KI-SL-A5 列表封面宽度** —— 覆盖 A 块 `:60`，B 块 `:100`（共 2 行）

- **上游口径**：`bookshelfListCoverWidth` **只在列表分支被读**——`BookItem.kt:965`（`BookshelfListItem` 调用处）、`:549`（分组列表）、`:1041`（锁定书列表分支），网格分支 `:825-843` 不读。
- **本地现状**：面板有条目（`entry/src/main/ets/pages/BookshelfPage.ets:629-631`）、仓储读写（`entry/src/main/ets/data/BookshelfLayoutRepository.ets:58-59` / `:86` / `:130` / `:150`）、备份带出（`entry/src/main/ets/data/BackupRepository.ets:606` / `:1331`），但**没有任何渲染代码读它**：`:745` 传给 `BookCover` 的 `maxWidth` 来自 `bookshelfCoverWidthLimit()`，该函数只用 `bookshelfGridCoverWidth`（`:462`）。
- **补法**：**与列表模式一起做**（见全局前置 1）。本地当前只有网格，即使把该字段接到 `:745` 也不会改变外观——上游网格分支本来就不读它。
- **验收**：切到列表模式后调该项，列表封面宽度随之变化；网格模式下调该项外观不变（与上游一致）。
- **已实现（r331）**：A 块 `:60` 与 B 块 `:100` 已改 `已接`。列表模式卡片（`BookshelfPage.ets:926-965`）封面 `displayWidth` 取 `bookshelfListCoverWidth`（`:936-937`），面板步进器 `:788-791`；列表 84→114 的封面变宽见 `b4-list-default.png` / `b4-list-width-after.png`，网格下调该项外观不变见 `b4-grid-width-unchanged.png`。

**KI-SL-A6 列表详情（简介 / 最新章节）** —— 覆盖 A 块 `:64`、`:65`，B 块 `:112`、`:120`（共 4 行）

- **上游口径**：`bookshelfShowLatestChapter`（`BookshelfConfigSheet.kt:447`，消费 `BookItem.kt:942`）；`bookshelfShowIntro`（`:456`，消费 `:739`）；总开关 `showListDetails = layoutMode == 0 && !isCompact && settings.showBookIntro`（`:738`）。
- **本地现状**：两字段都没有；卡片唯一副信息是封面上的章节数角标（`entry/src/main/ets/components/BookCover.ets:193-200`），不是章节名。
- **补法**：随列表模式一起做，`BookItem.kt:738-760` 的详情区在本地按 `Column` + 两行 `Text` 还原；章节名取书籍模型里的最新章节名。
- **验收**：开「显示最新章节」后列表卡片出现章节名一行；开「显示简介」后出现简介段落。
- **已实现（r331）**：A 块 `:64`、`:65` 与 B 块 `:112`、`:120` 已改 `已接`。面板两开关 `:793-798`，列表卡片简介 `Text(book.description ?? )`（`:951-956`）与最新章节 `Text(book.lastChapter)`（`:958-963`），`bookCardKey`（`:136-137`）纳入两字段。关「显示最新章节」后章节名行消失见 `b4-list-no-details.png`；**样本书 `titleonly-test` 的 `description` 为空，显示简介的可见效果在本机样本上得不到视觉证据，卡点见证据包第 4 节**。

**KI-SL-A7 搜索按钮点击 / 长按分流** —— 覆盖 A 块 `:80`，D 块 `:166`（共 2 行）

- **上游口径**：`bookshelfSearchActionDirectToSearch`（`BookshelfConfigSheet.kt:616`）；`BookshelfScreen.kt:570` 与 `:577` 两处手势按该布尔互换（点击搜索 / 长按筛选），`:1343` `val searchFirst = uiState.settings.bookshelfSearchActionDirectToSearch`。
- **本地现状**：无该字段；搜索按钮单击即进搜索，无长按分流（`BookshelfPage.ets` 里未查到搜索分流代码，`:756-765` 是卡片手势）。
- **补法**：字段 + 仓储；搜索按钮加长按手势，按字段决定点击与长按各自的动作。
- **验收**：开启后单击搜索按钮直接进搜索页、长按先进筛选；关闭后两者互换。
- **已实现（r331）**：A 块 `:80` 与 D 块 `:166` 已改 `已接`。`BookshelfPage.ets:800-816` 的 `.onClick` 与 `.priorityGesture(LongPressGesture)` 两分支按 `bookshelfSearchActionDirectToSearch` 对调，字段开关在 `:736`。

**KI-SL-A8 快速滚动条** —— 覆盖 A 块 `:81`，E 块 `:181`（共 2 行）

- **上游口径**：`showBookshelfFastScroller`（`BookshelfConfigSheet.kt:626`）；`BookshelfScreen.kt:1723` `val showFastScroll = uiState.settings.showBookshelfFastScroller`，`:1752` 传给 `FastScrollLazyVerticalGrid`，文件夹侧 `:1004`、`:987` 同型。是**带字母索引的快速滚动条**，不是系统滚动条。
- **本地现状**：无该字段；`entry/src/main/ets/pages/BookshelfPage.ets:772` `scrollBar(BarState.Off)` 写死。
- **补法**：字段 + 仓储；`Grid` 改 `scrollBar(BarState.On)` 只是最小形态，上游的字母索引需要另做叠层（ArkUI 无现成控件）。
- **验收**：开启后书架右侧出现可拖动滚动条，拖动时显示当前分组 / 索引。
- **已实现（r331，最小形态）**：A 块 `:81` 与 E 块 `:181` 已改 `已接`。`BookshelfPage.ets:915` 用系统 `scrollBar(BarState.On/Off)`；上游 `FastScrollLazyVerticalGrid` 的字母索引属增强，本轮未做，已在总账差异说明列写明。字段开关在 `:739`，重启后值保持见 `b2-restart.json`。

**KI-SL-A9 记住上次所在分组** —— 覆盖 E 块 `:186`（共 1 行）

- **上游口径**：`saveTabPosition`（`BookshelfViewModel.kt:110` 读、`:955` `changeGroup` 写、`:734` / `:763-764` 恢复）；落盘键名是 `bookshelfSelectedGroupId`（`constant/PreferKey.kt:73`），另读 `rawPrefValue(PreferKey.saveTabPosition)`（`:72`）。
- **本地现状**：无该字段，进书架恒落「全部」（`BookshelfPage.ets:131-134` `activeFilter()` 只在选中组被隐藏时回落）。
- **补法**：字段 + 仓储；`activeFilter` 初始化时读该值，页签切换时写回。
- **验收**：切到某分组后退出再进书架，仍停在该分组；该分组被删或隐藏时回落「全部」。
- **已实现（r331）**：E 块 `:186` 已改 `已接`。`BookshelfPage.ets:59` `@Prop @Watch`、`:126-128` `aboutToAppear`、`:132-141` `onLayoutChanged`、`:143-148` `selectGroup` 写回；落盘键 `bookshelfSelectedGroupId`。页签与分组菜单点击在 `:293`/`:844` 改走 `selectGroup`。

**KI-SL-A10 空态里的「全局搜索」按钮** —— 覆盖 E 块 `:189`（共 1 行）

- **上游口径**：`BookshelfScreen.kt:1675-1683`，`:1673` `if (uiState.isSearch)` 时显示按钮，文案 `bookshelf_empty_global_search`，点击跳全局搜索。
- **本地现状**：`entry/src/main/ets/pages/BookshelfPage.ets:795` 只把文案换成「没有匹配的书籍」，无按钮、无跳转。
- **补法**：`BookshelfPage.ets:788-799` 的空态分支加一个按钮，走现有的全局搜索路由。
- **验收**：搜索无结果时显示按钮，点它跳到全局搜索页。
- **已实现（r331）**：E 块 `:189` 已改 `已接`。`BookshelfPage.ets:942-946` 在无匹配空态加「全局搜索」按钮，`.onClick` 走 `Index.ets:6714` 传入的 `onSearch`。

**KI-SL-A11 字段全集与备份归类** —— 覆盖 F 块 `:198`、`:206`（共 2 行）

- **上游口径**：`domain/model/settings/BookshelfSettings.kt:6-56` 共 51 字段；分类数组 `help/storage/BackupConfig.kt:319-359` 39 键；`bookGroupStyle`（`constant/PreferKey.kt:13`）与 `hideEmptyGroups`（`:14`）不在 39 键内，走 `keyIsNotIgnore` 的 `else -> true`（`help/storage/BackupConfig.kt:413`），即不受任何类别开关控制。
- **本地现状**：`entry/src/main/ets/model/BookshelfLayout.ets:7-34` 只有 13 字段（本地 13 个名字在上游 51 名单里全部存在，无本地独有字段；上游另有 38 个名字本地未声明）；本地这两个键**不在** `bookshelfLayout` 键组（`entry/src/main/ets/data/BackupRepository.ets:424`-`:438`）里，写出时落在类别门控 `:682` **之前**的无条件块 `:675`/`:676`，所以取消勾选「书架布局」也照样写出。
- **补法**：字段按 KI-SL-A1~A10 分批补；两个归类错位的键从 `bookshelfLayout` 数组移出，改为无条件写出。
- **验收**：备份勾选里取消「书架布局」后，`config.xml` 仍含 `bookGroupStyle` 与 `hideEmptyGroups` 两项。
- **已实现（r331，部分）**：F 块 `:206` 已改 `已接`——`BackupRepository.ets:424`-`:438` 的 `bookshelfLayout` 键组不含这两键，`:675`/`:676` 在类别门控 `:682` 之前无条件写出。F 块 `:198` **仍留 `未接`**：本地 `BookshelfLayout.ets:7-86` 现 39 字段（原 13 + 批次 1 补 26），上游 51 字段里剩 12 个名字未声明（`showUnread`/`showUnreadNew`/`showTip`/`showBookCount`/`showLastUpdateTime`/`showBookIntro`/`bookshelfShowTag`/`bookshelfShowCustomTags`/`bookshelfShowSourceTags`/`bookshelfShowWordCount`/`showWaitUpCount`/`shouldShowExpandButton`），全部落在 KI-SL N2/N4「不接」组，任务书硬约束「9 组 41 行不接一行不碰」「不为做角标新建 Book 字段」禁止补这 12 个；按任务书「做不完留未接」处置，卡点与需要谁来判见证据包第 4 节。

**KI-SL-N1 列表专属版式与详情微调（不接）** —— 覆盖 A 块 `:47`、`:56`、`:62`、`:63`、`:66`、`:67`，B 块 `:106`、`:107`、`:111`、`:113`、`:114`（共 11 行）

- **判定理由**：这 11 行的前提都是「列表卡片」或「卡片副信息区」，本地既无列表模式（全局前置 1）也无详情区。判 `不接` 是**范围结论，不是上游无此行为**——逐行的上游依据都保留在对照表「上游位置」列，日后补列表模式时可原样复用。
- **特别说明**：`:47`（文件夹区列表封面宽度）与 `:60`（书籍区列表封面宽度）在上游是**同一字段** `bookshelfListCoverWidth` 的两个显示位置（`BookshelfConfigSheet.kt:202` 与 `:399`），所以书籍区那行判 `要接`（KI-SL-A5）、文件夹区这行判 `不接`，避免同一字段排两次。
- **验收**：本组无独立验收，随 KI-SL-A1 / A5 / A6 的验收一并覆盖。
- **前提已变化（r333，状态未重判）**：本组 10 行的判定理由写的是「本地既无列表模式（全局前置 1）也无详情区」。列表模式已在 r331 批次 4 落地（`entry/src/main/ets/pages/BookshelfPage.ets:1171` 起的 `Column` 分支），详情区总开关 `showBookIntro` 与四项子控制在 r333 落地（字段 `entry/src/main/ets/model/BookshelfLayout.ets:86`；`showsListDetails()` `BookshelfPage.ets:568-570`；面板 `:939-976`；渲染 `:1193-1200`、`:1214`、`:1216-1224`、`:1226-1230`）。按 `docs/PARITY-RULES.md` 第五节，`已接 / 未接 / 不适用` 属判断段产出，本组状态本轮**一行未改**，仍全部 `未接`；`docs/parity/ZIP-BOOKSHELF-LAYOUT.md` 对应 A 块 `:56`/`:62`/`:63`/`:66`/`:67` 与 B 块 `:106`/`:107`/`:111`/`:113`/`:114` 的「差异说明」列（原写「本地无 xxx」）也保持原样。要不要改判由判断段或用户决定。

**KI-SL-N2 标签体系（不接）** —— 覆盖 A 块 `:68`、`:69`，B 块 `:118`、`:119`（共 4 行）

- **判定理由**：标题标签依赖 `kindList`（`BookItem.kt:878-885`、`:888`），本地卡片无标签行、无标签数据源；`bookshelfShowTag` / `bookshelfShowCustomTags` / `bookshelfShowSourceTags` / `bookshelfShowWordCount` 四个字段本地都没有。上游这三个勾选项还在二级弹层里（`BookshelfConfigSheet.kt:695-742` 的 `BookshelfTagContentDialog`），本地面板无二级弹层结构。判 `不接`：标签属于卡片信息密度扩展，先补列表模式与紧凑模式（KI-SL-A2 / A6）再看是否需要。
- **验收**：无。

**KI-SL-N3 标签配色（不接）** —— 覆盖 A 块 `:70`、`:71`（共 2 行）

- **判定理由**：ZIP 类别是 `themeConfig` 不是 `bookshelfLayout`——`custom_tag_colors`（`BookshelfConfigSheet.kt:517`）与 `manage_tag_colors`（`:524`）改的是标签色板，落在主题体系（[ZIP-THEME.md](parity/ZIP-THEME.md)）里，本类别只借用入口。判 `不接`，转 ZIP-THEME.md 的 KI-TH 组处理。
- **验收**：无（归 ZIP-THEME.md）。

**KI-SL-N4 角标与提示信息（不接）** —— 覆盖 A 块 `:74`、`:75`、`:76`、`:77`、`:78`、`:79`，B 块 `:115`、`:116`、`:117`、`:121`（共 10 行）

- **判定理由**：`showUnread`（`BookItem.kt:752`）、`showUnreadNew`（`:753`）、`showTip`（`:754`）、`showBookCount`（`BookshelfScreen.kt:1011`）、`showLastUpdateTime`（`BookItem.kt:944`）、`showWaitUpCount`（`BookshelfViewModel.kt:1289`）这 6 个字段**都不在 bookshelfPrefKeys 39 键内**（`help/storage/BackupConfig.kt:319-359`），对照表里 ZIP 类别标 `—`；但它们对应的可视元素是未读数 / 红点 / 类型标签 / 分组计数 / 更新时间，本地卡片都没有。判 `不接`：这些是信息密度扩展，且本地封面角标已有「章节数 + 书签 + 缺正文红标」三件（`entry/src/main/ets/components/BookCover.ets:187-211`），再加未读角标会与章节数抢同一位置。
- **验收**：无。

**KI-SL-N5 二级弹层三项（不接）** —— 覆盖 A 块 `:84`、`:85`、`:86`（共 3 行）

- **判定理由**：这是 `BookshelfTagContentDialog`（`BookshelfConfigSheet.kt:695-742`）里的三个 `CheckboxItem`（`:711` / `:716` / `:721`），是 KI-SL-N2 的二级面板形态，本地既无标签行也无弹层。判 `不接`：与 KI-SL-N2 同因，随标签体系一起排期。
- **验收**：无。

**KI-SL-N6 分组卡片增强（不接）** —— 覆盖 A 块 `:82`，B 块 `:108`，E 块 `:180`、`:182`（共 4 行）

- **判定理由**：`shouldShowExpandButton`（`BookshelfScreen.kt:806-821`，「更多分组」按钮）、分组封面阴影（`BookItem.kt:349`）、分组根目录书籍数量（`BookshelfScreen.kt:1011`）三个都以「分组卡片在书架网格里」为前提，本地分组只在页签栏出现（`entry/src/main/ets/pages/BookshelfPage.ets:719-733`）。判 `不接`：等 KI-SL-A1 落地后再评估。
- **验收**：无。

**KI-SL-N7 批量更新与后台任务（要接，待排期）** —— 覆盖 A 块 `:83`，E 块 `:183`、`:184`、`:185`（共 4 行）

- **判定理由**：`bookshelfRefreshingLimit`（`BookshelfViewModel.kt:1114-1115`、`:1165-1166`）、`showWaitUpCount`（`:1289`）、`autoRefreshBook`（`:786`，键名 `auto_refresh`，`constant/PreferKey.kt:146`）三者都是「批量更新书籍目录」的配套。本地目前没有在线书源，目录刷新无对象；但**在线书源抓取自 2026-11-09 起已纳入范围**（[PROJECT.md](PROJECT.md) `:24-44` 的「在线服务」节，尚未排期），故改判「**要接，待排期**」——等书源接通后再补这三项，补法：`auto_refresh` 先做成开关，`bookshelfRefreshingLimit` 与 `showWaitUpCount` 随批量更新一起接。
- **验收**：无。

**KI-SL-N8 加载态与分页（不接）** —— 覆盖 E 块 `:187`、`:190`（共 2 行）

- **判定理由**：加载对话框（`BookshelfScreen.kt:1575-1602`，`if (uiState.isLoading)`）与分页惰性渲染（`:1669`，`!isCurrentPage` 时 return）都不由 bookshelfLayout 字段驱动，是主屏骨架行为，归 [BOOKSHELF.md](parity/BOOKSHELF.md) A1 的界面完整性。就本类别而言判 `不接`，不因此从对照表删行。
- **验收**：无。

**KI-SL-N9 锁定书卡片（不接）** —— 覆盖 B 块 `:123`（共 1 行）

- **判定理由**：`PrivateLockedBookItem`（`BookItem.kt:979`）的网格 / 列表两分支（`:1012` / `:1031`）读各自封面宽度（`:1025` / `:1041`）。本地无隐私书架锁定书卡片，无对应渲染分支。判 `不接`。
- **验收**：无。

---

### C 布局矩阵（3 组要接）

**KI-SL-C1 书籍横屏三项** —— 覆盖 C 块 `:136`、`:137`、`:138`（共 3 行）

- **上游口径**：`BookshelfScreen.kt:1698-1699` 取 `isLandscape`，`:1700-1701` / `:1705-1706` / `:1710-1711` 分别按横竖屏取 `bookshelfLayoutMode*` / `bookshelfLayoutGrid*` / `bookshelfLayoutList*`，`:1715` 统一成 `columns`。
- **本地现状**：字段只有竖屏三键（`entry/src/main/ets/model/BookshelfLayout.ets:17`、`:19`、`:21`）；无横竖屏判断（全局前置 2）。
- **补法**：先建窗口尺寸读取入口（HOS 用 `window.getLastWindow` 取窗口矩形或 `display.getDefaultDisplaySync()`，**不是** Android 的 `LocalConfiguration`），再补 3 个 Landscape 字段与仓储，`BookshelfPage.ets:419-427` 的 `bookshelfColumnsTemplate()` 按方向取不同值。
- **验收**：同一台设备横屏后网格列数变为横屏设置值，转回竖屏恢复竖屏值。
- 实现记录（r331）：`BookshelfPage.ets` 已落地 `isLandscape`（`:100`）、窗口矩形读取（`:160-177`）、`activeLayoutMode`/`activeGridColumns`/`activeListColumns`（`:551-565`）与三处按方向取值（`:1216`）。
- **已补横屏面板入口（r332）**：修复前面板布局模式的两个分支都写竖屏字段（`draft.bookshelfLayoutModePortrait`），横屏下改不了横屏值。现改为 `activeDraftLayoutMode()`/`activeDraftGridColumns()`/`activeDraftListColumns()`（`:569-585`）按 `isLandscape` 读写，标签随之变为「横屏下的书架呈现方式」（`:883-890`），对齐上游 `BookshelfConfigSheet.kt:247-265`、`:284-300`、`:412-424` 的 `it.copy(...Landscape = value)`。
- **已补列数上限（r332）**：`bookshelfColumnsTemplate()`/`bookshelfColumnCount()`（`:620-638`）原 `maximum = mode === 1 ? 6 : 5` 把横屏默认 7 压成 6，现改为渲染处只设下限 `Math.max(1, Math.round(configured))`，步进器上限改网格 1..15、列表 1..5，对齐上游 `BookshelfConfigSheet.kt:288`（`1f..15f`）与 `:412`（`1f..5f`）。
- **设备横屏已验（r332）**：模拟器实例 `config.ini` 的 `hw.lcd.single.width/height` 对调冷启动即得横屏 2832×1280（`hw.lcd.phy.*` 同步对调），C 块 `:136`/`:137`/`:138` 三行已改 `已接`，证据 `land-list.jpeg`、`land-after4.json`、`land-modemenu.json`。

**KI-SL-C2 文件夹六项** —— 覆盖 C 块 `:139`、`:140`、`:141`、`:142`、`:143`、`:144`（共 6 行）

- **上游口径**：`BookshelfScreen.kt:526-539` 按横竖屏取 6 个 `bookshelfFolderLayout*` 值，`:985` `folderColumns = if (bookshelfFolderLayoutMode == 0) bookshelfFolderLayoutList else bookshelfFolderLayoutGrid`，`:988` `GridCells.Fixed(folderColumns.coerceAtLeast(1))`。
- **本地现状**：6 个字段全无，且无文件夹视图（KI-SL-A1）。
- **补法**：随 KI-SL-A1 一起做；取值分支照 `:985` 的两级判断。
- **验收**：开文件夹样式后，竖屏改网格列数为 4、横屏为 6，两种方向各生效。
- **已实现（r331）**：C 块 `:139`、`:140`、`:141`（竖屏三项）改 `已接`。`BookshelfPage.ets:587-603` 的 `activeFolderLayoutMode` / `activeFolderGridColumns` / `activeFolderListColumns` 按 `isLandscape` 取值，`:609-618` `folderColumnsTemplate()` 照上游 `:985` 的两级判断（mode===0 取列表列数否则网格列数）并只设下限，`:1110` 挂到 `.columnsTemplate`。竖屏网格列数 3→4 生效见 `b5-folder-col4.png`、重开读回 4 见 `b5-col4v.json`。
- **横屏三项已验（r332）**：C 块 `:142`、`:143`、`:144` 改 `已接`。横屏下分组样式选「文件夹」后面板展开「文件夹（横屏）」分区（`:841-857`），实测：网格列数 7→15 后根层两张分组卡宽 159≈2832/15（`land-c15.json`）；模式切「列表」后单卡铺满整行（`land-flist.json`）；列表列数 1→3 后两张卡横向并排、各宽 907≈2832/3（`land-flc3.json`、`land-flc3.jpeg`）。
- **顺带修掉的一处缺陷（r332）**：`文件夹列表列数·竖屏/横屏` 与 `书名行数` 三个步进器的回调原先直接 `+= delta` 不夹取，实测把横屏列表列数减到了 **-22**；现三处都改为 `Math.max(下限, Math.min(上限, 值 + delta))`，与其余步进器一致。

**KI-SL-C3 首屏封面预加载列数** —— 覆盖 C 块 `:145`（共 1 行）

- **上游口径**：`ui/main/bookshelf/BookshelfCoverPreloader.kt:261-280` `resolveFirstScreenLayout`：列表时 1 列，网格时按横竖屏取 `bookshelfLayoutGrid*`，`:278` 乘预估可见行数并夹在 `MAX_PRELOAD_BOOKS` 内。
- **本地现状**：本地无预加载器，封面图由各卡片自行加载（`entry/src/main/ets/components/BookCover.ets`）。
- **补法**：随 KI-SL-C1 一起做（要先有横竖屏取值）；预加载数量按列数 × 可见行数算，超上限截断。
- **验收**：首屏滚动时封面不出现空窗，且预加载数量不超过列数 × 可见行数。
- 实现记录（r331）：本地无封面预加载器（`grep -rni preload entry/src/main/ets` 零命中），按任务书 `:166-168` 处置为「记录为无预加载器、按 0 处理」，落点是 `BookshelfPage.ets:20-26` 的 `BOOKSHELF_FIRST_SCREEN_PRELOAD_COLUMNS = 0` 常量与中文注释；不新建预加载系统，C 块 `:145` 留 `未接`，卡点见证据包第 4 节。

### 不接行归属核对

上节只对 `要接` 组给了补法与验收；41 条 `不接` 行同样逐行登记在上文 K 组（KI-SL-N1 ~ N9），覆盖关系如下，**没有一行 `不接` 缺少落点**：

| 组 | 覆盖行 | 行数 | 归属 |
| --- | --- | --- | --- |
| KI-SL-N1 列表专属版式与详情微调 | A `:47`、`:56`、`:62`、`:63`、`:66`、`:67`；B `:106`、`:107`、`:111`、`:113`、`:114` | 11 | 随列表模式（前置 1） |
| KI-SL-N2 标签体系 | A `:68`、`:69`；B `:118`、`:119` | 4 | 随列表模式与紧凑模式 |
| KI-SL-N3 标签配色 | A `:70`、`:71` | 2 | 转 [ZIP-THEME.md](parity/ZIP-THEME.md) |
| KI-SL-N4 角标与提示信息 | A `:74`~`:79`；B `:115`、`:116`、`:117`、`:121` | 10 | 信息密度扩展，暂不做 |
| KI-SL-N5 二级弹层三项 | A `:84`、`:85`、`:86` | 3 | 随标签体系 |
| KI-SL-N6 分组卡片增强 | A `:82`；B `:108`；E `:180`、`:182` | 4 | 等 KI-SL-A1 |
| KI-SL-N7 批量更新与后台任务 | A `:83`；E `:183`、`:184`、`:185` | 4 | 要接，随在线书源排期 |
| KI-SL-N8 加载态与分页 | E `:187`、`:190` | 2 | 归 BOOKSHELF.md A1 |
| KI-SL-N9 锁定书卡片 | B `:123` | 1 | 无隐私书架 |

合计 41 行，与对照表 `**不接**` 计数一致。

---

## 封面配置行登记（ZIP-COVER.md 的未接行）

本节登记 [封面设置总账](parity/ZIP-COVER.md) A–E 块里 6 行 `未接` 的「接不接、怎么接」。编号 `KI-COVER<序号>` 与对照表「备注」列的 `KI-COVERn` 标记一一对应，组内先列覆盖的对照表行号（行号为 ZIP-COVER.md 的行号），再给上游口径、本地现状、补法或理由、验收。**本节只登记，不改 `.ets` 代码。**

**判定口径**：按 [PROJECT.md](PROJECT.md) 与 PARITY-RULES.md 第三节。在线书源抓取自 2026-11-09 起已纳入范围（`PROJECT.md:24-44`，尚未排期），依赖它的封面规则求值（C6）与网络封面（A10）等记「要接，待排期」；仍在[范围之外](PROJECT.md)（`PROJECT.md:46-48`）的只有 AI 在线服务、云同步与额外设备形态。判「不接」的**不删行、不改状态**，对照表里仍按 `未接` 计，只在备注与本节点明理由。

**与对照表状态的关系**：ZIP-COVER.md 只有 `已接 / 未接 / 不适用` 三值，不设「部分接」。本节的「要接」是排期结论，「不接」是范围结论，两者都不改变对照表的 `未接` 状态。全表 66 行 = 58 已接 / 6 未接 / 2 不适用（r334 实现段收口，C8 于 2026-11-09 改判 `已接`）；6 行未接分别是 A1 仅 WiFi（`:86`）、A10 网络书籍角标（`:95`）、B15 旧版默认封面迁移（`:131`）、C6 规则求值（`:146`）、C9 备份开关（`:149`）、D18 预加载（`:180`）。

**排期分布**：原登记 39 条 `要接`，r334 实现段（批 0–4）落地后已收口 32 条，2026-11-09 C8 单独接通后再收口 1 条，剩 6 条未接（A1 仅 WiFi、A10 网络书籍角标、B15 旧版默认封面迁移、C6 规则求值、C9 备份开关、D18 预加载）。其中 **B15 是 r334 收尾时才从 `已接` 改回 `未接` 的**——相册三视图与数据层都做了，但「旧版 `defaultCover` 偏好 → `default-cover` 相册」这条迁移本地没有实现，也没有迁移对象（`CoverSettings.defaultCover` 全仓无人写值）。各组的原始排期口径保留在下面各组里，作为「当初为什么这么切」的记录。

**全局前置（r334 已全部完成，保留作为当初的排期依据）**：

1. ~~**`CoverSettings` 字段补齐与键名映射**~~ **已完成（r334 批 0）**：`CoverSettings` 已补到 18 字段（`data/CoverSettingsRepository.ets:13`-`:55`，新增 `loadOnlyOnWifi`/`useDefaultCover`/`restrictCoverRatio`/`exploreFilterState`/`defaultCover`/`defaultCoverDark`）；双向映射表落在 `data/CoverSettingsRepository.ets:262 coverSettingsToAndroid()`（14 对）与 `:286 applyAndroidCoverPreferences()`。落盘键仍是裸字段名（`:135-146`），备份时经映射表转成上游 PreferKey 名——两套名字并存但已不再是缺口。
2. ~~**`config.xml` 白名单**~~ **已完成（r334 批 4）**：写出改成 `data/BackupRepository.ets:946`-`:951`（14 键按映射表逐键写，受 `:946` 的 `if (!ignoredCategories.includes('coverConfig'))` 门控）；恢复侧 `restoreCoverSettings()` 定义 `:1825`（`:1825`-`:1839` 逐键读回、`:1535` 调用点）。本地仍是白名单式逐键写（与上游「整表 `asMap()` + 黑名单」不同），这是本地备份写入方式决定的，不是缺口。

---

### 未接行（7 组）

**KI-COVER1 仅 WiFi 下载封面 / 使用默认封面 / 封面预加载** —— 覆盖 A 块 `:86`（A1）、`:88`（A3）、D 块 `:180`（D18），共 3 行

- **上游口径**：三个开关串成一条取图链路。`useDefaultCover` 打开时 `model/BookCover.kt:125` 直接返回默认封面图并 `centerCrop()`；`loadOnlyOnWifi` 经 `OkHttpModelLoader.loadOnlyWifiOption`（`model/BookCover.kt:129`）挂到每个图片请求上，消费点还有 `CoilBookCover.kt:227`、`ui/main/bookshelf/BookshelfCoverPreloader.kt:183`、`ui/book/info/BookInfoViewModel.kt:852`、`:2151`、`ui/book/readaloud/player/PlayerThemeOverride.kt:52`；预加载器 `ui/main/bookshelf/BookshelfCoverPreloader.kt:125` 在 `MainActivity.kt:341` 起，`preloadCurrentGroupFirstScreen()`（`:149`）按首屏可见量批量入队。
- **本地现状（r334 之后按实测定稿，三行分化）**：
  - **A3 使用默认封面 → 已接**。字段 `data/CoverSettingsRepository.ets:46`（默认 `:79`、落盘 `:185`、回填 `:149`-`:150`）；设置页开关 `pages/AppCoverSettingsPage.ets:281`-`:285`；渲染侧 `components/BookCover.ets:93`-`:99` 的 `effectiveCoverUri()`——`useDefaultCover` 为真时返回 `CoverAlbumRepository.defaultCoverPath(this.isNight)`（定义 `data/CoverAlbumRepository.ets:92`），没有相册图就返回空串走文字占位（`:152` `if (this.hasCoverImage())` 早退）。**开关关掉再打开、切夜间换图，屏幕上都看得见。**
  - **A1 仅 WiFi → 仍 `未接`**。字段与开关都在（`CoverSettingsRepository.ets:44` / `AppCoverSettingsPage.ets:277`-`:278`），也参与备份往返（映射 `:277` 的 `loadCoverOnlyWifi`、回填 `:354`-`:356`），但 `entry/src/main/ets` 全目录 `loadOnlyOnWifi` 除设置页与仓储外**零命中**——没有请求侧消费端，开关拨了不改变任何屏幕现象。按 PARITY-RULES 第三节「`已接` 必须写得出屏幕现象」判 `未接`。
  - **D18 预加载 → 仍 `未接`**。`entry/src/main/ets` 全目录 `preload|预加载` 只命中 `pages/BookshelfPage.ets:24`-`:29` 的说明注释与 `BOOKSHELF_FIRST_SCREEN_PRELOAD_COLUMNS = 0` 常量，封面由各卡片自行加载（`components/BookCover.ets` 直接 `Image(...)`）。
- **补法**：~~先在 `CoverSettingsRepository.ets` 补 `loadOnlyOnWifi` / `useDefaultCover` 两字段；`useDefaultCover` 的分支加在 `components/BookCover.ets:154` 之前~~ **已完成（r334）**——两字段在（键名照 `data/BackupRepository.ets:450`-`:454` 的 `coverConfig` 键组取 `loadCoverOnlyWifi` / `useDefaultCover`），`useDefaultCover` 分支落在 `components/BookCover.ets:93`-`:99`。剩两件：①`loadOnlyOnWifi` 的消费端——需先确认本地图片加载是否走 `@ohos.net.http`，若是，在请求前读一次网络类型；②预加载（D18）单独排期，用 `List` 的可见区回调取首屏条目，不要照搬上游的行列算法（本地没有横竖屏取值）。
- **验收**：断 WiFi 用蜂窝网络进书架，开着「仅 WiFi 下载封面」时封面显示书本图标占位、不发起请求；接上 WiFi 后封面加载出来。打开「使用默认封面」后书架所有书封面变成默认封面图，关掉后真实封面回来。

**KI-COVER2 封面规则（UI + 求值 + 存储 + 备份）** —— 覆盖 A 块 `:87`（A2），C 块 `:141`、`:142`、`:143`、`:144`、`:145`、`:146`、`:147`、`:148`、`:149`（C1–C9），共 10 行

- **上游口径**：入口在设置页 `ui/config/coverConfig/CoverConfigScreen.kt:105-109`，sheet 是 `ui/config/coverConfig/CoverRuleConfigSheet.kt:25-83`（勾选 `:61-65`、搜索 URL `:67-72`、规则表达式 `:74-80`、恢复默认 `:35-43`、保存 `:44-52`）。保存校验 `ui/config/coverConfig/CoverConfigViewModel.kt:130-133`（URL 或规则为空时 toast `cover_rule_fields_required` 并 return）。运行期存 `CacheManager` 键 `legadoCoverRuleConfig`（`model/BookCover.kt:51`，读 `:246-249`、写 `:276-278`、删 `:280-282`），`coverRule.json`（`:52`）只用于备份写出（`help/storage/Backup.kt:251-256`）与恢复读入（`help/storage/Restore.kt:339-346`）。求值 `model/BookCover.kt:251-269`：未启用/空 URL/空规则返回 null，否则 `AnalyzeUrl` + `getStrResponseAwait()` + `AnalyzeRule.getString(coverRule, isUrl = true)`；唯一调用点 `ui/book/info/BookInfoViewModel.kt:1275`，前置条件 `:1274` 是 `coverUrl` 与 `customCoverUrl` 都为空。
- **本地现状（r334 之后按实测定稿，10 行分化）**：
  - **C1–C5、C7、C9 → 已接**。模型 `data/CoverRuleRepository.ets`（155 行）有 `export interface CoverRule`（`:22`-`:43`，9 字段齐：`enable`/`searchUrl`/`coverRule`/`concurrentRate`/`loginUrl`/`loginUi`/`header`/`jsLib`/`enabledCookieJar`）、`DEFAULT_COVER_RULE`（`:41`）、`copyCoverRule`（`:54`）、`isDefaultCoverRule`（`:69`）、`class CoverRuleRepository`（`:75`，`get` `:80`、`load` `:89` 逐 9 字段读回、`save` `:113`、`del` `:135`）。UI 入口在 `pages/AppCoverSettingsPage.ets:280`（`CoverSettingsAction({ title: '封面规则', detail: '编辑按规则获取封面用的搜索源与规则表达式', onSelect: () => this.openRuleSheet() })`），sheet 打开 `:98`-`:99`（先 `loadRuleIntoDraft(CoverRuleRepository.get())`）、标题 `:389`、启用勾选 `:400`-`:402`、搜索 URL `:406` 起、规则表达式 `:416` 起、恢复默认 `:391`、保存 `:393` + `:115`-`:126`（校验失败 `:122` 提示「封面规则保存失败，当前值未更改」）。**C8 备份读写也已接**：写出 `data/BackupRepository.ets:956`-`:960`（`:957` `if (!isDefaultCoverRule(coverRule))` 门控，与默认一致则不写）、恢复 `:1468`-`:1481`、解析 `parseCoverRule` 定义 `:2673`；清单登记在 `:459`-`:467`（`fileNames`）与 `:474`。
  - **C6 规则求值 → 仍 `未接`**（见补法②）。
  - 本地仍没有 `CacheManager` 等价物：规则值直接落本地 preferences，不存运行期缓存。
- **补法**：**拆成两段**。①UI + 存储（C1–C5、C7、C9）是纯本地：按 `CoverRule` 9 字段（`model/BookCover.kt:286-294`）建模型，存到 preferences（本地没有 `caches` 表，用独立 prefs 文件更贴近现有做法），sheet 照 `CoverRuleConfigSheet.kt` 三段布局。②求值（C6）**随规则引擎一起接**（`coverRule.json` 的备份读写 C8 已在 r334 单独接通，见上面「本地现状」）——默认规则 `app/src/main/assets/defaultData/coverRule.json` 的 `coverRule` 是一段 `@js:` 脚本，里面用 `java.base64Encode`、`java.ajaxAll`、`com.jayway.jsonpath.JsonPath` 这些 Java 桥接口，终点是 `https://pre-api.tuishujun.com/...` 与 `http://m.ypshuo.com/...` 两个在线搜索接口，没有规则引擎与 JS 运行时就是死代码。注意封面规则求值走的是同一套 `AnalyzeUrl`/`AnalyzeRule` 管线，在线书源抓取自 2026-11-09 起**已纳入范围、尚未排期**（[PROJECT.md](PROJECT.md) `:24-44`），所以这一条不是「不接」，而是「要接，随规则引擎与在线书源一起做」。
- **验收**：①UI 段——设置页点「封面规则」弹 sheet，勾「启用」、填 URL 与表达式，点保存后退出重进内容还在；URL 或表达式留空时点保存弹「请填写必填项」且不落盘；点「恢复默认」后两个输入框变默认脚本。②求值段——书详情页对一本 coverUrl 与 customCoverUrl 都为空的网络书，规则命中后封面自动变成搜索结果图。

**KI-COVER3 默认封面相册（整块）** —— 覆盖 A 块 `:89`（A4），B 块 `:117`、`:118`、`:119`、`:120`、`:121`、`:122`、`:123`、`:124`、`:125`、`:126`、`:127`、`:128`、`:129`、`:130`、`:131`（B1–B15），E 块 `:193`（E4）、`:194`（E5）、`:195`（E6），共 19 行

- **上游口径**：数据层 `data/repository/CoverAlbumRepository.kt`（508 行）——根目录 `:49-53` `File(context.getExternalFilesDir(null) ?: context.filesDir, "cover_albums")`，索引 `albums.json`（`:43`），`FORMAT_VERSION = 2`（`:41`），迁移遗留相册 id `"default-cover"`（`:44`）；JSON 只存文件名（`:357-358`），图片按 SHA-256 命名（`:325-326`），写入走临时文件 + `ATOMIC_MOVE`（`:349-380`）。三个选择键在 `data/local/preferences/LocalPreferences.kt:61-63`（`selected_cover_album_id` / `selected_light_cover_album_id` / `selected_dark_cover_album_id`），读取 `CoverAlbumRepository.kt:55-70`，优先链 `albumId ?: lightAlbumId ?: darkAlbumId`（`:75-81`）。日夜两套图是 `CoverAlbum.lightImages` / `darkImages`（`domain/model/CoverAlbum.kt:8-9`），取用 `:90-96`。UI 两块：选择 sheet `ui/config/coverConfig/CoverAlbumSelectSheet.kt`（164 行，「无」项 `:61-71`，相册项 `:72-85`，条目组件 `:90-164`）与管理页 `ui/config/coverConfig/CoverAlbumManageScreen.kt`（449 行，顶栏新建 `:135-139`，空态 `:144-166`，卡片 `:215-297`，编辑器 `:299-381`，对话框 `:383-418`，命名框 `:420-449`）。空相册行为：选「无」时 `onSelect(null)`（`CoverAlbumSelectSheet.kt:67-70`），相册本身为空时管理页显示 `cover_album_empty` 空态（`:161-164`）。迁移 `CoverAlbumRepository.kt:231-284`：读 `PreferKey.defaultCover` / `defaultCoverDark` 逗号串，合并进 `default-cover` 相册并 `distinctBy { it.id }`（`:266-273`），写 `COVER_ALBUM_MIGRATED = true`（`:281`）。
- **本地现状（r334 之后按实测定稿，19 行分化）**：
  - **A4 与 B1–B14、E4–E6 共 18 行 → 已接**。数据层 `data/CoverAlbumRepository.ets`（357 行）已落地：根目录 `context.filesDir/cover_albums`（`:105`，`directoryName` 定义 `:61`）、索引 `albums.json`（`:62`）、`class CoverAlbumRepository` `:60`、`defaultCoverPath(isNight)` `:92`、`load` `:141` 区、`createAlbum`/`renameAlbum`/`deleteAlbum`/`setSelection`/`addImages`/`removeImage`、`previewPath`。头注释 `:10`-`:18` 说明「本地没有 `getExternalFilesDir`，统一用 `context.filesDir/cover_albums`」。UI 在 `pages/AppCoverSettingsPage.ets`（729 行）的同一个 `bindSheet` 里按 `albumView` 分四层（`:53` `@State albumView: string = 'select'`）：`select` `:427`-`:470`（标题「选择封面相册」`:430`、「无」项 `:440`-`:443`、相册项 `:456`-`:469`）、`manage` `:472`-`:525`（「封面相册」`:477`、「暂无相册」空态 `:489`、卡片 `:498`-`:523`、「使用中」标记 `:505`）、`editor` `:527`-`:570`（白天/夜间页签 `:540`/`:544`、「添加图片」`:563`）、`name` `:572`-`:594`（「新建相册」/「重命名相册」`:572`、取消 `:580`、确定 `:583`）。删除二次确认 `:194`-`:198`（文案带相册名）。`CoverSettings` 两字段在（`data/CoverSettingsRepository.ets:52`/`:54`，默认 `:82`/`:83`，落盘 `:188`/`:189`，不参与备份）；渲染侧 `components/BookCover.ets:93`-`:99` 已走 `CoverAlbumRepository.defaultCoverPath`。
  - **B15 旧版默认封面迁移 → 仍 `未接`**：`CoverSettings.defaultCover` 全仓无人写值，没有迁移对象，也没有迁移代码。
  - 本地封面来源除相册外仍是两条：EPUB 内嵌封面（`data/EpubRepository.ets:109` `coverUri = 'file://${coverPath}'`）与手动选图（`pages/Index.ets:6151`-`:6166 chooseBookCover()` / `:6168`-`:6176 restoreBookCover()`，落 `data/BookRepository.ets:605`-`:607 copyWithCover`）。
- **补法（r334 已按四件套落地，保留作为当初的拆解依据）**：①仓储 —— `data/CoverAlbumRepository.ets` 已建，根目录 `context.filesDir/cover_albums`（本地没有 `getExternalFilesDir` 等价物）；②两页 UI —— 选择 sheet 与「管理 / 编辑器 / 命名」三视图都做在 `pages/AppCoverSettingsPage.ets` 的同一个 `bindSheet` 里，按 `albumView` 切换，没有另开页面；③`CoverSettings` 的 `defaultCover` / `defaultCoverDark` 两字段已在（`:52`/`:54`）；④渲染侧 `components/BookCover.ets:93`-`:99` 已接「从相册取图」，取不到走文字占位。**剩 B15 一项**：旧版 `defaultCover` 偏好 → `default-cover` 相册的迁移没有实现，本地也确实没有旧版 `defaultCover` 字符串可迁，这一条保留 `未接` 但属于「要接了才有意义」。
- **验收**：设置页「默认封面」→ 弹相册选择 sheet 看到「无」与自建相册；新建一个相册、白天加 3 张图、夜间加 2 张；返回设置页该行摘要变成「相册名 · 日 3 / 夜 2」；书架页无封面的书显示相册里的图，切到夜间模式后换成夜间那 2 张；杀掉进程重进相册还在。

**KI-COVER4 限制封面比例** —— 覆盖 A 块 `:93`（A8）、E 块 `:191`（E2），共 2 行

- **上游口径**：设置项 `ui/config/coverConfig/CoverConfigScreen.kt:158-165`（`checked = settings.restrictCoverRatio`，`:161`）；字段 `domain/model/settings/CoverSettings.kt:10`（默认 `true`，注释「开启（默认）时搜索/发现/详情页封面固定 5:7」）；消费点两处——`ui/book/info/BookInfoScreen.kt:1169` 与 `ui/widget/components/book/SearchBookItem.kt:85`，都是 `!LocalAppUiConfiguration.current.cover.restrictCoverRatio` 决定封面用固定 5:7 还是按图片真实宽高比。键不在 14 个 `coverPrefKeys` 里（`help/storage/BackupConfig.kt:396-411`），也不在 `alwaysIgnoredPreferenceKeys`（`:11-33`），所以参与备份但不受忽略开关控制。
- **本地现状（r334 已接）**：字段在（`data/CoverSettingsRepository.ets:48`，默认 `true` `:80`，落盘 `:186`，回填 `:151`-`:152`）；设置页在「书架显示」组有开关（`pages/AppCoverSettingsPage.ets:312`-`:316`）；渲染侧 `components/BookCover.ets:73` 的 `if (!this.applyAspectRatio || this.coverSettings.restrictCoverRatio)` 与 `:292` 的 `if (this.applyAspectRatio && !this.coverSettings.restrictCoverRatio && this.coverAspectRatio > 0)`——关掉后按原图宽高比（`ImageSeedColorExtractor.coverAspectRatio`，`:82`-`:84` 取比例，读不到回落 5:7）。备份往返：写出 `data/BackupRepository.ets:678`（`coverRestrictRatio`，无条件区 `:675`-`:679` 之一）、恢复 `:1835`/`:1855`。
- **补法**：~~`CoverSettingsRepository.ets` 补 `restrictCoverRatio`；设置页加一条 Switch；渲染侧把固定的 `7/5` 改成条件~~ **已完成（r334）**——字段（默认 `true`，与上游一致）、开关、`BookCover.ets:73`/`:292` 的条件分支都在。**遗留一处口径差**：上游这个开关只作用于搜索/发现/详情页，书架页封面恒为固定比例；本地是把 `applyAspectRatio` 作为调用点开关（`BookCover.ets:73`），哪些界面打开它由调用方决定，因此需要在接搜索/发现/详情页时逐个确认是否传 `applyAspectRatio: true`。
- **验收**：关掉「限制封面比例」后，搜索结果页与书籍详情页的封面按图片原始宽高比显示（宽图变宽、窄图变窄），书架页封面形状不变；重开后回到 5:7。

**KI-COVER5 网络书籍角标（发现页筛选）** —— 覆盖 A 块 `:95`（A10）、E 块 `:192`（E3），共 2 行

- **上游口径**：设置项 `ui/config/coverConfig/CoverConfigScreen.kt:184-197`，四档 `entryValues = arrayOf("0","1","2","3")`（全部 / 书架内隐藏 / 同名同作者隐藏 / 只显示不在书架内的）；字段 `CoverSettings.kt:23` 默认 `0`；唯一消费点 `ui/book/explore/ExploreShowViewModel.kt:249` `filterStateId = coverSettings.exploreFilterState`。键名是 **`explore_filter_state`**（`constant/PreferKey.kt:429`），不是字段名 `exploreFilterState`——按字段名 grep 会误判成 0 命中。不在 14 个 `coverPrefKeys`、不在 `alwaysIgnoredPreferenceKeys`。
- **本地现状（r334 之后按实测定稿，2 行分化）**：
  - **E3 上游键归属 → 已接**：键 `explore_filter_state` 的备份往返在——写出 `data/BackupRepository.ets:679`（无条件区 `:675`-`:679`），恢复 `:1836`/`:1856`。
  - **A10 网络书籍角标 → 仍 `未接`**：字段 `data/CoverSettingsRepository.ets:50`（默认 `0` `:81`，落盘 `:187`，回填 `:153`-`:154`）；设置页有四档条目 `pages/AppCoverSettingsPage.ets:317`-`:324` 的 `CoverSettingsChoice`（`['全部显示','隐藏书架内','隐藏同名同作者','仅显示书架外']`，`onSelect` 写 `draft.exploreFilterState = index` `:321`）；但 `entry/src/main/ets` 全目录 `exploreFilterState|filterState` 除设置页写值与备份读写外**零命中消费端**——发现页 `pages/DiscoverPage.ets:62` 只有本地示范数据过滤（`this.sources.filter(...)`），不读这个字段。**有字段、有四档条目、有备份往返，缺的是筛选消费点。**
- **补法**：~~先补字段与设置项（四档 Dropdown）~~ **已完成（r334）**——字段与四档条目都在（见上）。**剩筛选消费点，取决于发现页本身**：本地发现页是示范数据页（`pages/DiscoverPage.ets`），没有真实书源列表，「按是否在书架内筛选」没有筛选对象。筛选逻辑跟着发现页的数据源一起写。这里不判「不接」，因为发现页本身不在任何「范围之外」条目里；在线书源抓取自 2026-11-09 起已纳入范围（[PROJECT.md](PROJECT.md) `:24-44`，尚未排期），发现页接真实数据后可随之排期。
- **验收**：发现页出现书籍列表后，设置页把「网络书籍角标」切到「书架内隐藏」，发现页里已在书架的书消失；切回「全部」后重新出现。

**KI-COVER8 夜间·显示书名 / 显示作者** —— 覆盖 A 块 `:102`（A17）、`:103`（A18），共 2 行

- **上游口径**：`ui/widget/components/image/cover/CoilBookCover.kt:518-520` 按 `isNight` 分叉选字段（`if (isNight) coverSettings.showNameDark else coverSettings.showName`），`:522` `if (!showName && !showAuthor) return`；设置页两项 `CoverConfigScreen.kt:306-313` 与 `:315-323`，后者 `enabled = settings.showNameDark`（`:319`）。
- **本地现状（r334 已接）**：字段在（`data/CoverSettingsRepository.ets:13`-`:55` 有 `showNameDark` / `showAuthorDark`），开关能落盘，**渲染层也已读**——`components/CoverTextLayout.ets:66`-`:69` 签名带 `isNight: boolean = false`，`:77 const showName = isNight ? settings.showNameDark : settings.showName;`、`:78 const showAuthor = (isNight ? settings.showAuthorDark : settings.showAuthor) && showName;`；`components/BookCover.ets:48 @Prop isNight`、`:154` 传进 `buildCoverTextLayout`；`pages/BookshelfPage.ets:1153`/`:1182`/`:1242` 传 `readerNightMode`。旧描述里提到的 `effectiveShowName()`/`effectiveShowAuthor()` 两个按日夜分叉的中间函数**已整个删除**（全仓 grep 零命中），r331 之前那种「夜间关掉『显示书名』字仍在」的现象已不存在。字段接口实测为 `data/CoverSettingsRepository.ets:13`-`:55`（18 字段），`showNameDark` 在 `:19`、`showAuthorDark` 在 `:21`。
- **补法**：~~把 `isNight` 传进排版函数~~ **已完成（r334）**——`components/BookCover.ets:153`-`:154` 调用 `buildCoverTextLayout(widthVp, heightVp, this.book.title, this.book.author, this.coverSettings, 1.2, this.isNight);`，签名在 `components/CoverTextLayout.ets:66`-`:69`，字段三元式在 `:77`-`:78`。`enabled` 联动也已完成：`pages/AppCoverSettingsPage.ets:343` 日间作者行 `disabled: !this.settings.showName`、`:365` 夜间作者行 `disabled: !this.settings.showNameDark`（**KI-COVER7 一并结清**）。
- **验收**：书架页任一无封面书籍，切到夜间模式后关掉「夜间·显示书名」，卡片上的书名与作者一起消失（白天模式下仍显示）；再打开后恢复；关掉夜间「显示书名」时夜间「显示作者」那一行置灰不可点。

**KI-COVER9 14 个 `coverPrefKeys` 的读写** —— 覆盖 E 块 `:190`（E1），共 1 行

- **上游口径**：`help/storage/BackupConfig.kt:396-411` 列了 14 个键（`useDefaultCover`、`loadCoverOnlyWifi`、`coverShowName`、`coverShowAuthor`、`coverShowNameN`、`coverShowAuthorN`、`coverShowShadow`、`coverShowStroke`、`coverTextColor`、`coverTextColorN`、`coverShadowColor`、`coverShadowColorN`、`coverDefaultColor`、`coverInfoOrientation`）；写出在 `help/storage/Backup.kt:258`（`AppConfigStore.preferences.asMap()` 全量导出后按忽略规则过滤），恢复在 `help/storage/Restore.kt` 的 config.xml 分支。样本 `N:\HarmonyProjects\测试\backup2026-10-22\config.xml` 里 14 个键全在（`:227`、`:228`、`:229`、`:231`、`:233`、`:236`、`:238`、`:240`、`:242`、`:245`、`:247`、`:249`、`:251`、`:252`）。
- **本地现状**：14 键清单常量在（`entry/src/main/ets/data/BackupRepository.ets:450`-`:454`，与上游逐键一致），同时也是 `filterAndroidConfigXml`（定义 `:2703`）的 `excludedKeys` 来源，用于从上游备份里剥掉这些键。**r334 已把读写都接通**：写出 `:946`-`:951`、恢复 `:1825`-`:1839`，键名映射走 `data/CoverSettingsRepository.ets:262 coverSettingsToAndroid` / `:286 applyAndroidCoverPreferences`（本地落盘仍是裸字段名 `showName`/`textColor`，`:172`-`:189` 的 `save` 段）。
- **补法**：先做上面「全局前置 1」的键名映射表（本地 `showName` ↔ `coverShowName`、`showNameDark` ↔ `coverShowNameN`、`textColor` ↔ `coverTextColor`、`textColorDark` ↔ `coverTextColorN`、`infoOrientation` ↔ `coverInfoOrientation`，其余同理）；r334 已按此补法落地：写出 `entry/src/main/ets/data/BackupRepository.ets:946`-`:951` 按 `coverSettingsToAndroid` 的映射逐键 upsert，恢复 `:1825`-`:1839` 反向回填。`data/CoverSettingsRepository.ets:4-12` 的头注释已改为「本地 preferences 用裸字段名，双向映射集中在 `coverSettingsToAndroid` / `applyAndroidCoverPreferences`」，与实现对上了。
- **验收**：把「显示字体描边」关掉 → 备份 → 解压 `config.xml` 里有 `<boolean name="coverShowStroke">false</boolean>`；把本地值改回 `true` → 恢复该 ZIP → 设置页「显示字体描边」变回关、书架页描边消失。

### 已接行上的残留差异（不属于上面 6 行未接，单独登记）

这两组在对照表里对应的行状态是 `已接`，功能可用、能看见屏幕效果，只是与上游的呈现方式不同。写在这里是为了让「改哪边算数」有落点，**不计入 6 行未接**。

**KI-COVER6 取色面板：任意取色 vs 6 个预置色轮换** —— 关联 A 块 `:96`（A11）、`:97`（A12）、`:100`（A15）、`:101`（A16）

- **上游口径**：点颜色行弹 `ColorPickerSheet`（调用 `ui/config/coverConfig/CoverConfigScreen.kt:349-372`，初始色映射 `:350-355`，`onColorSelected` 按 `CoverColorField` 分发到四个 intent `:361-370`），可在色环上取任意色。
- **本地现状**：`pages/AppCoverSettingsPage.ets:327`（日间文字颜色）/`:332`（日间阴影颜色）/`:349`（夜间文字颜色）/`:354`（夜间阴影颜色）四行是圆点式颜色行 + 点一下在 6 个预置色之间轮换，预置色 `TEXT_COLOR_OPTIONS`（定义 `:264` 起）＝ `'#000000', '#FFFFFF', '#E7E8ED', '#AFC2FF', '#E8B77B', '#9AD0B7'`。类型也不同：上游 `textColor: Int`（ARGB，默认 `-16777216`），本地 `textColor: string`（`'#RRGGBB'`，默认 `'#000000'`）。
- **补法**：若要与上游对齐，需要建一个取色器组件（HOS 有 `ColorPicker` 一类能力，具体 API 未查证），并把 `CoverSettings` 的颜色类型从 string 改成 number（会影响 `CoverSettingsRepository.ets:139`-`:142` 的 `readColor` 调用、`:205`-`:209` 的 `readColor` 定义、`:228`/`:241` 的 `coverColorToAndroidInt`/`androidIntToCoverColor`，以及 `components/BookCover.ets:114`-`:120` 的 `coverTextColor()`/`coverShadowColor()`）。
- **验收**：设置页点「文字颜色」弹出取色面板，任选一个色号后书架页无封面书籍的书名变成该色。

**KI-COVER7 开关联动置灰：`enabled = showName`** —— 关联 A 块 `:99`（A14）、`:103`（A18）

- **上游口径**：`CoverConfigScreen.kt:256` `enabled = settings.showName`（日间作者）/ `:319` `enabled = settings.showNameDark`（夜间作者）——书名关掉时作者那一行置灰不可点。
- **本地现状（r334 已接）**：`pages/AppCoverSettingsPage.ets:343` 日间作者行传 `disabled: !this.settings.showName`、`:365` 夜间作者行传 `disabled: !this.settings.showNameDark`；`CoverSettingsSwitch`（`AppCoverSettingsPage.ets:637`，`:645 @Prop disabled: boolean = false`）里 `.enabled(!this.disabled)` + `.opacity(this.disabled ? 0.4 : 1)`，disabled 时保留原值不重置，与上游一致。语义本身两边也一致（`components/CoverTextLayout.ets:77` 的 `&& showName`）。
- **补法**：~~`CoverSettingsSwitch` 加一个 `disabled` 参数~~ **已完成**——参数在 `:645`，两个调用点已传参（`:343`/`:365`）。
- **验收**：关掉「显示书名」后「显示作者」那一行变灰点不动；重开书名后恢复可点。

### 未接行归属核对

上表 7 组覆盖关系如下（KI-COVER6 / KI-COVER7 属「已接行上的残留差异」，不在本表），**r334 收口后 6 行未接没有一行缺少落点**：

| 组 | 覆盖行 | 行数 | 归属 | r334 后状态 |
| --- | --- | --- | --- | --- |
| KI-COVER1 仅 WiFi / 使用默认封面 / 预加载 | A `:86`、`:88`；D `:180` | 3 | 要接 | `:88` 已接；`:86`（仅 WiFi）与 `:180`（预加载）仍 `未接` |
| KI-COVER2 封面规则 | A `:87`；C `:141`、`:142`、`:143`、`:144`、`:145`、`:146`、`:147`、`:148`、`:149` | 10 | UI 要接；求值随规则引擎 | `:87`、`:141`–`:145`、`:147`–`:148` 已接；`:146`（规则求值）、`:149`（备份开关）仍 `未接` |
| KI-COVER3 默认封面相册 | A `:89`；B `:117`、`:118`、`:119`、`:120`、`:121`、`:122`、`:123`、`:124`、`:125`、`:126`、`:127`、`:128`、`:129`、`:130`、`:131`；E `:193`、`:194`、`:195` | 19 | 要接 | `:131`（B15 旧版迁移）仍 `未接`，其余 18 行已接 |
| KI-COVER4 限制封面比例 | A `:93`；E `:191` | 2 | 要接 | 全部已接 |
| KI-COVER5 网络书籍角标 | A `:95`；E `:192` | 2 | 要接（依赖发现页真实数据） | `:192` 已接；`:95` 仍 `未接`（本机不可观察） |
| KI-COVER8 夜间两开关 | A `:102`、`:103` | 2 | 要接（改两行） | 全部已接 |
| KI-COVER9 14 个封面键读写 | E `:190` | 1 | 要接（依赖键名映射） | 已接 |

合计 39 行登记，其中 33 行已接、6 行仍 `未接`（与对照表 `未接` 计数一致）。不适用 2 行（D 块 `:178` `CoverImageView`、`:179` `CoverBlurBackdrop`）不进本节——前者在上游全仓除定义处零调用点，后者本地没有播放器封面背景这类场景。

---

## 设备范围

- API 12 真机兼容尚未验证。HOS 模拟器检查只代表验证记录中列出的操作；N 端 API 26 数据不作为 E 端或 API 12 结论。
- r257 设备没有自定义分组，卡片上新增的私有标记/刷新状态文案未在设备上直接显示验证。

构建与设备记录见[验证记录](VALIDATION.md)，Android ZIP 字段边界见[备份恢复说明](BACKUP-RESTORE.md)。
