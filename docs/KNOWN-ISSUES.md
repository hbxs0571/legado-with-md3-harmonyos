# 已知问题与验收边界

更新：2026-10-29。以下仅列出公开源码和 E 端记录能够支持的状态，不包含测试书名、个人文件名、设备地址、日志或截图。

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

### 本地书籍行登记（BOOKSHELF.md 的 localBook 未接行）

本节登记 [书籍总账](parity/BOOKSHELF.md) 里 `localBook` 名下 **72 行 `未接`** 的「为什么不修」。编号 `KI-LB<n>` 与对照表「备注」列的标记一一对应。判定口径按 [PROJECT.md](PROJECT.md)「范围之外」段：只有上游存在、且属于本地书籍这条链路的能力才补；依赖尚未迁移的体系（WebDAV、书源、私密）或纯视觉差异的，登记不修。

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

- 阅读设置尚未逐控件完成回归。系统字体选择已检查；自定义 TTF/OTF 实际导入、CJK fallback、EPUB 字体和多设备排版仍待验证。
- r258 阅读正文高亮规则已在 N 端 HOS 模拟器完成面板可达、创建、命中、停用、冷启读回、滚动模式与删除七项闭环；E 端交接时面板打不开的问题在 N 端未复现。HOS `RegExp` 只覆盖 Android Java Pattern 的安全兼容子集，规则长度、章正文长度和规则条数分别限 256/150000/64，且没有执行超时保证。
- 高亮规则的按排版 `configName` 绑定、标题规则执行、图片背景/九宫格/SVG、字体替换和字距行距样式未接入。`highlightRule.json` 的备份写出与 ZIP 恢复已接入并在 N 端设备双向验证，恢复采用合并语义（本地独有规则保留），与上游 `replaceAll` 全量替换不同。Android 默认规则预设导入已在 r260 接入，但与上游有 3 处已注明的差异：`bracket_note_default` 补转义、`date_time_default` 由 314 裁到 179 字符、`title_emphasis_default` 只导入不执行。
- 阅读页书签角标与「书签标记大小」已在 r264 接通：角标显示在正文区右上角，宽度取 `bookmarkBadgeSize`（默认 10dp，0 不显示，上限 50），仅在分页模式与本地书籍显示，翻页与下拉偏移一并作用，`config.xml` 恢复时读回。**自定义角标图片已在 r265 接通**（选择、保存到应用私有目录、渲染、恢复默认，`config.xml` 双向映射）；书签导出于 r263 接通（「所有书签」页按书导出 JSON/Markdown），「书签标记」样式入口的 `migrated` 也已转正。上游没有跨章批量删除/移动书签的能力，本地同样不提供，此项不算缺口。
- 划线/笔记的颜色预设已在 r266 从 6 色扩到上游 `MarkingPresetColors` 的 15 色，并加了内联自定义取色器（8×12 色板 + 手输 `#RRGGBB`/`#AARRGGBB`）。与上游仍有两处差异：上游取色器是独立 `ColorPickerSheet`，本地改成同一面板内展开；上游色板是横向滚动的单行色带，本地改成换行排列（外层遮罩会吃掉横向手势）。取色面板展开时正文区可滚动、按钮行固定在底部，这个溢出缺陷已在 r266 一并修掉。
- 「所有书签」页的书签条目点击=编辑、长按=跳转正文（r263 对齐上游）；笔记条目仍只有点击跳转，没有编辑入口，笔记编辑需在阅读页划线处进入。这与上游一致——`AllBookmarkScreen.kt` 的 `BookmarkDetailItemUi.Marking` 分支只渲染选中文本与备注，本就没有点击行为。
- 「所有书签」页的排序与跨书源提示已在 r268 对齐上游：条目按 `(chapterIndex, chapterPosition)` 排序（上游 `AllBookmarkViewModel.kt:214`），书籍列表按书名排序（上游 `:186` `.sortedBy { it.key.name }`），来源书源与当前书不同的条目在章名右侧标红显示「其他书源」（上游 `marks_other_source`）。排序只在渲染层做，preferences 里的存储顺序不变。
- 目录页搜索栏右侧「更多」菜单已在 r267 接通三项（更新目录 / 替换规则 / 本地 TXT 目录规则），不再是占位。上游 `TocScreen.kt:427-535` 里还有两项未做：「新建替换规则并预填本书作用域」（本地 `openReplaceRuleEditor(id)` 只接受已有规则 id，没有草稿通道）与「拆分超长章节」（`Book` 模型没有 `splitLongChapter` 字段，全仓零命中）。
- 更新目录（单书与书架级 `refreshAllToc`）**不再重映射**书签与划线/笔记（r276 起对齐上游）：上游 `BookmarkRepository`/`BookMarkingRepository` 更新目录时完全不碰这两张表，r267 曾按新旧正文偏移重算（`remapNoTocBookmarks`/`remapNoTocMarkings`），会把用户锚点悄悄挪到别的章节，已整段删除。书签与划线一律按原章节号保留，位置是否需要提醒交给 r270 的跳转前校验（`titleMismatch` 弹「位置可能已偏移」）。N 端实测：把 2 章伪造成 12 章再更新回真实 6 章，书签 4 条与划线 1 条逐字段完全未变，长按第 2 章书签仍能跳转并弹出偏移提示。
- 书签/笔记跳转前的定位校验已在 r270 接入（`data/ReaderBookmarkTarget.ets`）：源指纹不一致报 `sourceChanged`、章节标题不一致报 `titleMismatch`，两种都弹确认框由用户决定是否仍跳。笔记额外先按「选中文本 + 前后文」重定位，同分即歧义并退回确认框。**已知边界**：源指纹取 `androidOriginalPath ?? contentPath ?? id`，书籍换源后若这两者恰好都没变则判为 `match`，不会提示；重定位候选只覆盖 `chapterIndex` 指向的那章与标题同名章，目录大改后可能找不到锚点而退回确认框。
- 标记编辑器的「样式来源」下拉已在 r269 接入，可复用已有高亮规则的样式。**这是有损映射**：只把规则换算成标记的 `effect + color` 两个字段落盘，规则里的下划线粗细/偏移/自定义 SVG 路径、背景图（拉伸/裁剪/九宫格）、字体类字段本地渲染层不支持，换算时丢弃；因此规则日后调整不会回溯改变已有标记。上游 `MarkingSheet` 同样是当场取值、不建立引用，此处与上游一致。
- 阅读记录真实跨午夜持久化、损坏数据扫描/修复提示、阅读字数采集和书籍别名合并仍未完成或未验。
- TXT 目录规则完整 CRUD/批量组合和含非空规则的应用备份恢复仍需补测。
- 替换规则的同步正则未受 `timeoutMillisecond` 限时；异步并发保存覆盖风险、完整恢复提示仍待验证。
- 在线 URL 规则导入、在线书源抓取、RSS、TTS、AI、WebDAV、云同步和 Web 服务未接入。

### 书签与标注（r268–r276 盘点遗留）

本节由 2026-10-29 的 [ZIP-BOOKMARK 对照表](parity/ZIP-BOOKMARK.md) 盘点得出，2026-10-30 第二轮独立复核后扩为 85 条（已接 72 / 未接 9 / 不适用 4）。9 条 `未接` 全部是用户可感知的能力缺口，逐条登记如下；4 条 `不适用` 是上游内部形态（无 Room 数据库、无 AI 助手、移出书架本就不清书签、Android 独有的 `ACTION_PROCESS_TEXT`），理由写在对照表 B/E 块。

1. **划线/笔记渲染不校验锚点文本**（已设备取证）。上游 `app/src/main/java/io/legado/app/domain/model/BookContentProcessEngine.kt:25-46` 在渲染前对每条 `KIND_USER_UNDERLINE`/`KIND_USER_HIGHLIGHT` 解析 `anchorJson`，`findTargetRange`（`:101-131`）按「选中文本 → 去空白文本 → 全空白归一化」三级退让在离近似位置最近处重定位，解析不到就不计入 `effectiveProcesses`、直接不渲染。本地 `entry/src/main/ets/pages/ReaderPage.ets:1999 getMarkingForTextRange` 只判 `chapterPosition < end && endPosition > start` 的区间相交，**完全不看 `selectedText`**，正文一变高亮就落在错误位置；三处调用点 `ReaderPage.ets:2148`（切段）、`:2326`、`:2431`（逐字 Span）都走这个判断。等价能力 `entry/src/main/ets/data/BookContentProcessEngine.ets:93 findTargetRange` 已存在但只服务高亮规则与正文处理，没接到标记渲染。设备取证：手工构造 `chapterPosition=0`、`selectedText="这一段是占位正文"`（真实位置约 480）的失效标记，本地仍在第 0-10 字渲染高亮。

2. **划词菜单缺「行内快速标记」模式**。上游按 `MarkingUiState.inlineMode` 在 `MarkingSelectionMenu`（行内预览、当场应用上次样式）与 `TextActionSelectionMenu`（完整动作条）之间切换，对应意图 `ReadBookContract.kt:870 OpenQuickMarking`、`:871 OpenQuickMarkingEdit`、`:872 ApplyQuickMarking`、`:875 DismissQuickMarking`，行内态还带 `previewStyle`/`inlineDirty` 两个状态位。本地 `entry/src/main/ets/pages/ReaderPage.ets` 的选区菜单只有 sheet 一条路径（r273 已补「复制」「书签」两项），没有行内预览态。

3. **目录页书签/笔记缺多选与批量操作**。上游 `app/src/main/java/io/legado/app/ui/book/toc/TocScreen.kt:325 selectionSecondaryActions` 提供反选、选中后续、批量加书签、批量去分组、批量删音频；本地 `entry/src/main/ets/pages/CatalogPage.ets` 的书签条目（`:487-489`）与笔记条目（`:545-546`）只有单击与长按，章节行同样无选择模式。

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

## 关系型存储迁移第五批（r284）遗留

本节登记 2026-10-30 第五批（preferences 老数据清理）设备验收后仍待处理的三项。**第 1 项已于 r290 修掉，保留记录备查；第 2、3 项仍未处理。**

1. ~~**`RdbCleanup` 漏删两个键**~~ —— **已于 r290 修掉**。`legado_read_records` 里的 `details_v1` 与 `summaries_v1` 在 r284 清理时未被删除（当时只删了 `sessions_v1`），这两个键存的是第三批之前的老格式「按日明细」与「书籍汇总」，第三批起已改存 `readRecordDetail` / `readRecord` 两表，全仓 `.ets` 已无读取点（`grep -rn "details_v1\|summaries_v1" --include=*.ets` 零命中）。r290 的修法两处同时做：`entry/src/main/ets/data/RdbCleanup.ets` 的删除清单改为 `['sessions_v1', 'details_v1', 'summaries_v1']`；同文件 `markerKey` 由 `rdb_cleanup_v1_1` 提到 `rdb_cleanup_v1_2`——**只改第一处无效**，因为标记已写的设备不会重跑清理。详见[验证记录](VALIDATION.md)的「r290 修补」。

2. **书签与划线的设备验收在模拟器上走不通**。`bookmarks` 与 `book_marks` 在第五批验收中始终为 0 行，新代码下的写入路径未经验证。已验证可行的入口是：进阅读页 → 长按正文 → 选词菜单（复制 / 书签 / 划线·笔记，y 366–493）→ 点「书签」→「添加书签」面板 → 保存。但该手势在模拟器上极不稳定：本轮只在首次成功一次，之后 12 次循环探测、5 个不同纵坐标（900/1200/1500/1800/2100）、重启、双击、慢速拖拽、`uinput -T` 触摸轨迹、菜单开合状态下长按均无法复现；且**首次成功那一轮点「保存」落在了面板外**（面板关闭但未入库），保存按钮的准确 bounds 从未 dump 到。注意 `uitest uiInput longClick` 稳定返回 `No Error` 却不保证手势被应用识别，返回码不能当成功依据。这与 r281 节的既有结论一致（正文走滚动模式，长按划词在模拟器上一直不可靠），**不是本次改动引入的问题**。后续两条替代路径：① 数据层直接构造标记行 + 渲染像素比对（r281 验证划线渲染用的就是此法，做过「改 DB 颜色 → 界面由黄变红」的决定性验证）；② 改在真机上走完整 UI 闭环。另注意底栏默认只启用 `['search','autoPage','catalog','voice','settings']`（`entry/src/main/ets/data/ReaderSettingsRepository.ets:292`），`addBookmark` 不在其中，所以底栏没有书签按钮，长按选词是唯一入口。

3. **按书净化开关的冷启闭环未验**。`book_overrides_v1` 已搬进 `books.readConfig.useReplaceRule`，读写路径已构建通过（设备实测两本书的 `readConfig` 为 `{"reSegment":false,"fixedType":false}`，无 `useReplaceRule` 键，符合「未设置 = 跟随全局默认」），但「关掉某一本书的净化 → 冷启 → 仍关闭」这条闭环没有上机走。验收要点：关闭后 `books.readConfig` 应出现 `"useReplaceRule":false`，重启后阅读该书的替换仍不生效，重置后该键应重新消失。

## 阅读配置行登记（READER-CONFIG.md 的未接行）

本节登记 [READER-CONFIG 对照表](parity/READER-CONFIG.md) A–G 块里 **97 行 `未接`** 的「为什么不修」。编号 `KI-<块><组>` 与对照表「备注」列的标记一一对应，组内逐行列出覆盖的对照表行。**本节只登记不实施，本轮不改 `.ets` 代码。**

判定口径按[项目范围](PROJECT.md)「范围之外」段：在线书源抓取、RSS、TTS 朗读、WebDAV、AI、云同步与额外设备形态，不因开关已上屏而算已实现；上游没有的行为不补。凡上游行为在本地已有等价实现、或上游分支在本平台根本不存在，直接记「不接」；其余记「要接，待排期」并写补法。

与字段口径的关系：本节按 **A–G 明细表的行**登记（97 行）。对照表 §一 1.5 按**上游声明名**判定的 112 项里，另有 9 项判「不接」但不对应任何 KI 组，理由直接写在 1.5 表内，不在此重复——`menuBgColor`、`menuBgColorNight`、`menuAcColor`、`menuAcColorNight`、`menuBottomCornerRadius`、`menuBottomHorizontalMargin`、`menuBottomBottomMargin`（都是上游 `Config` 里 `@Transient` 的主题包承载字段，上游没有用户设置入口）、`readStyleSelect`、`comicStyleSelect`（图片书/漫画，本地无该内容形态，明细表 A 块已判 `不适用`）。两个口径不可相加。

### A 阅读界面基础

**KI-A1 正文渲染适配四项（已实现）** —— 覆盖 A-01 正文行高适配（`readBodyToLh`，`ReadBookConfig.kt:67`）、A-02 中文排版（`useZhLayout`，`:76`）、A-03 适配刘海屏（`paddingDisplayCutouts`，`ReadSettings.kt:11`）、A-04 适配特殊样式（`adaptSpecialStyle`，`:18`）。

**本轮判定**：四项全部接上，但**四项的性质完全不同**，不能一律按「接上渲染」写。

**上游口径**

- `readBodyToLh`（`ReadSettings.kt:14`，存储键同名 `PreferKey.kt:104`，默认 `true`）：上游**没有渲染消费点**。`help/config/ReadBookConfig.kt:67` 只有 `val readBodyToLh get() = readSettings.readBodyToLh` 这个只读快照；全仓（`--include=*.kt --include=*.xml`）grep `readBodyToLh|ReadBodyToLh` 共 20 处，除 `PreferKey`/`ReadSettingsRepository`/`ReadSettings`/`ReadBookConfig`/`MoreConfigSheet.kt:230-231`（开关项）/`ReadConfigContract.kt:15`/`ReadConfigScreen.kt:123-124`/`ReadConfigViewModel.kt:114,185`/`res/values*/strings.xml`（文案「扩展到刘海」，`values-zh-rCN/strings.xml:967`）/`res/xml/pref_config_read.xml:60-61` 之外，**没有任何渲染或分页读取点**。按「上游没有就不要这个效果」，本地只做可配 + 落库 + 随备份，不实现扩展正文到刘海。
- `useZhLayout`（`ReadSettings.kt:19`，`PreferKey.kt:150`，默认 `false`）：上游断行器唯一。`feature/reader/core/layout/ChineseLineBreaker.kt` 是平台无关实现，`ReaderPaginator.kt:559`/`:721` 两处**无条件**使用它、不看开关；`ChineseLineBreaker.kt:58`/`:128` 的注释也只说「旧 ZhLayout 的语义已并入」。开关的唯一去处是 `ui/book/read/pageestimate/PageEstimateConfig.kt:23` `val useZhLayout: Boolean = false` 与 `:61` `add(useZhLayout)`（进 `stableHash` 布局签名），由 `model/ReadBook.kt:420` 传入。
- `paddingDisplayCutouts`（`ReadSettings.kt:11`，`PreferKey.kt:337`，默认 `false`）：有真实消费点 `ui/book/read/ReaderContentAvoidancePolicy.kt:34-51` —— `val cutout = if (paddingDisplayCutouts) insets else SystemBarInsets()`，`left = cutout.cutoutLeftPx`、`right = cutout.cutoutRightPx`、`bottom = (if (navPlaceholderGone) 0 else insets.navigationBarBottomPx) + cutout.cutoutBottomPx`，顶部 `top = (if (statusPlaceholderGone) 0 else insets.statusBarTopPx) + (if (statusPlaceholderGone) cutout.cutoutTopPx else 0)`。接线 `ReadBookRouteScreen.kt:195`。
- `adaptSpecialStyle`（`ReadSettings.kt:18`，`PreferKey.kt:117`，默认 `true`）：有真实消费点 `feature/reader/core/source/ReaderChapterSource.kt:158-166` —— `if (adaptSpecialStyle && trimmed == "[newpage]") { result += ReaderChapterSourceBlock.PageBreak(position); return@forEachIndexed }`、`if (adaptSpecialStyle && trimmed.startsWith("<usehtml>") && trimmed.endsWith("</usehtml>")) { ... result += ReaderChapterSourceBlock.Html(html, position, semanticLength) }`；另有 `help/book/ContentProcessor.kt:173-179` 与 `ReaderBodyOnlyFilter.kt:56-70` 同源判断。关闭时两者按字面文字显示。

**备份口径**：四个键都**不在** `help/storage/BackupConfig.kt` 的 `readPrefKeys` 忽略清单里（grep 四个键名零命中），随 config.xml 无条件备份。

**本地落地**

1. `entry/src/main/ets/data/ReaderSettingsRepository.ets`：接口 `:260` `readBodyToLh`、`:264` `useZhLayout`、`:268` `paddingDisplayCutouts`、`:272` `adaptSpecialStyle`；默认值 `:621-624`（`true`/`false`/`false`/`true`，与上游一致）；读 `:741`/`:743`/`:745`/`:747`；归一四个 `typeof === 'boolean'`；写 `:1184`/`:1186`/`:1188`/`:1190`。存储键全部与字段同名。
2. `entry/src/main/ets/pages/Index.ets`：`@State readerReadBodyToLh`/`readerUseZhLayout`/`readerPaddingDisplayCutouts`/`readerAdaptSpecialStyle`（`:231-245`）；装载、快照、恢复备份各四行；四个 setter（`setReaderReadBodyToLh`/`setReaderUseZhLayout`/`setReaderPaddingDisplayCutouts`/`setReaderAdaptSpecialStyle`），其中 `setReaderAdaptSpecialStyle` 末尾额外调 `reloadSelectedChapterForTransform()`（改它要重建正文语义）。
3. `entry/src/main/ets/pages/ReaderPage.ets`：四个 prop（`:212` 不带 Watch、`:214`/`:216` 带 `onPaginationInputsChanged`、`:218` 带 `onAdaptSpecialStyleChanged`）；三个缺口 inset 字段与 `readerCutoutLeftInset()`/`readerCutoutRightInset()`/`readerCutoutBottomInset()`（`:842` 一带）；`applyReaderDisplayCutout()`（`:812`）用 `getWindowAvoidArea(TYPE_CUTOUT)` + `this.getUIContext().px2vp(...)` 换算，`aboutToAppear()` 里调用；`getBodyContentWidth()`/`getBodyContentHeight()` 各减 inset；`onAdaptSpecialStyleChanged()`（`:886`）触发重排；`LocalTextSemantics.parse()` 两处补第三参；`getFullBookPaginationLayoutKey()` 加 `this.useZhLayout`。
4. `entry/src/main/ets/data/LocalTextSemantics.ets`：`interface LocalSemanticParagraph` 增 `pageBreak`/`richHtml` 两个必填布尔；`static parse(rawBody, paragraphIndent, adaptSpecialStyle = true)` 增第三参；`:94` 识别 `[newpage]` 推 `pageBreak: true` 段、`:107` 识别 `<usehtml>...</usehtml>` 并把 `:113` 整段做一个 part 打 `richHtml: true`；普通段 `:158` 补 `pageBreak: false, richHtml: false`。
5. `entry/src/main/ets/pages/LocalReaderPaginator.ets`：`paginate()` 的 `:306` 与 `countPagesIncrementally()` 的 `:515` 都是 `if (paragraph.pageBreak) { if (<已积累行数> > 0) { flushPage(); } continue; }`。**注意两条路径判空的变量不同**：`paginate` 用 `pageLines.length`，`countPagesIncrementally` 用 `pageLineCount`（该函数内部用计数器，`flushPage` 在 `:350` 判 `pageLineCount === 0`）。
6. `entry/src/main/ets/pages/ReaderSettingsPage.ets`：四个 prop + 四个回调；`:1119`/`:1125`/`:1131`/`:1137` 四个原本 `showNotMigrated(...)` 的占位改真 `MenuSettingSwitch`，文案按上游 strings.xml（「扩展到刘海」`read_body_to_lh:967`、「填充刘海区域」`padding_display_cutouts:1802`、「使用自定义中文分行」`use_zh_layout:1156`、「适配特殊样式」`adapt_special_style:2021`）。
7. `entry/src/main/ets/data/BackupRepository.ets`：接口 `:264-275` 四字段；config.xml 导出四条（`:647` 一带，`'boolean'`）；readConfig.json 记录四条（`:1110` 一带）；恢复段四条（`:1401` 一带，`readJsonBoolean ?? readXmlBoolean ?? current`）。

**已知差异**

- `readBodyToLh` 上游本就没有渲染效果，本地保持同样口径（只有可配 + 落库 + 随备份），不额外发明行高归一。
- `paddingDisplayCutouts` 只处理左右与底部缺口，**顶部避让仍由外层状态栏 padding 承担**；上游在「状态栏占位消失」时还会额外补 `cutoutTopPx`，本地未实现该分支。
- `<usehtml>` 富文本段本地按纯文本整段渲染（单个 part、不逐字排版），不执行 HTML。
- `[newpage]` 换页与 `<usehtml>` 富文本段**未做设备端像素级取证**：当前模拟器没有一本正文可读的书（书架三本正文文件均已丢失），只做了代码侧只读证据链核对（`LocalTextSemantics.ets:94`/`:107`/`:113` 与 `LocalReaderPaginator.ets:306`/`:515`）。

**验收**：见 `docs/VALIDATION.md` 的「2026-10-31 N 端 KI-A1 正文渲染适配四项」节。四个 Toggle 与四个存储键一一对应、拨动即落库、重启回显保持、测试值已复原出厂值。

**本轮顺带修复的环境故障**（记入 VALIDATION 备查）：KI-A1 设备验收时发现 prefs 完全不落盘。排查后定位为 **prefs XML 被测试期 `hdc file send` 反复整文件覆盖后损坏** —— `hilog` 报 `E C01653/NativePreferences: ParseNodeElement: An unsupported element type was encountered in parsing = text` / `E ReadSettingXml: The error occurred during getting xml child elements` / `W ReloadFromDisk: ... reload result is 0`，于是 store 与磁盘脱钩，`put()`+`flush()` 静默成功但不写盘。推入一个只有 `<?xml version="1.0" encoding="UTF-8"?><preferences version="1.0"/>` 的空文件即恢复。**后续设备验收不要再整文件覆盖 prefs**，要注入测试值只拨 UI 控件。

**KI-A2 菜单层依赖三项（要接，随 KI-E1）** —— 覆盖 A-05 显示菜单图标（`showMenuIcon`，`ReadBookConfig.kt:78`）、A-08 阅读标题补充信息（`showReadTitleAddition`，`ReadSettings.kt:55`）、A-17 阅读菜单不透明度（`menuAlpha`，`:13`）。

三项都作用在阅读页菜单层，而本地没有菜单外观渲染层：全仓 `readMenu*`/`titleBar*` 只命中 `data/BackupRepository.ets`，`ReaderPage.ets` 零命中。没有菜单的地方单独接这三个开关等于给不存在的界面加配置，因此与 E 块合并处理（见 KI-E1）。

**KI-A3 禁用返回键（已实现，只做可配 + 落库 + 随备份）** —— 覆盖 A-06（`disableReturnKey`，`ReadSettings.kt:50`）。

**这条判据的转折点：上游有这个配置项，但没有这个效果。** 上一版写的是「需要补 `onBackPress()` 拦截」，那是按照设置项文案推断的；本轮把上游全仓翻了一遍，结论相反：

- 上游有这个配置：`ReadSettings.kt:50` `val disableReturnKey: Boolean = false`，偏好键 `PreferKey.kt:420` `const val disableReturnKey = "disableReturnKey"`（与字段同名），落库在 `ReadSettingsRepository.kt:160-161` `setDisableReturnKey()`，映射在 `:417` 与 `:673`；两处设置项 `MoreConfigSheet.kt:443-448` 与 `ReadConfigScreen.kt:404-407`；Intent 链 `ReadBookContract.kt:2061` `ConfigUpdate.DisableReturnKey` → `ReadConfigUpdateDelegate.kt:724-726`。
- 上游**没有**这个效果：`grep -rni "disablereturn" --include=*.kt --include=*.xml` 排除 `build/` 后共 21 处命中，全部集中在上面那些文件、资源字符串（`values/strings.xml:1019`、`values-zh-rCN/strings.xml:987`、`values-zh-rHK/strings.xml:827`、`values-zh-rTW/strings.xml:839`、`res/xml/pref_config_read.xml:229-230`）以及一个单元测试断言（`app/src/test/java/io/legado/app/data/repository/ReadSettingsMappingTest.kt:245` `base.copy(disableReturnKey = true)`）。**没有任何 `BackHandler`、`onBackPressed`、`OnBackPressedCallback`、`KEYCODE_BACK` 读取它。**
- 对照：阅读页真正处理返回键的是 `ui/book/read/ReadBookRouteScreen.kt:240-249` 的 `BackHandler(enabled = canHandleBack)`，分支只有 `activeSheet != null → DismissSheet`、`isShowingSearchResult → ExitSearch`、`isAutoPage → StopAutoPage`、`menuState.canNavigateBack → ReadMenuBack`、否则 `requestClose()`。`canHandleBack` 在 `:220` 是 `isTopRoute`，与 `disableReturnKey` 无关。

所以按「上游有这个问题就保留、上游没有就不要这个效果」，本地**只做可配 + 落库 + 随备份**，不加返回键拦截——加了反而会造出上游没有的行为。这与 KI-A7 的 `sliderVibrator` 同一种处理方式。

本地落地：
1. `entry/src/main/ets/data/ReaderSettingsRepository.ets`：接口 `:236` `disableReturnKey: boolean;`（注释引 `ReadSettings.kt:50` 与 `PreferKey.kt:420`）；默认值 `:590` `false`；读 `:709` `store.get('disableReturnKey', ...)`；返回对象 `:982` `typeof === 'boolean'` 归一；写 `:1141`。
2. `entry/src/main/ets/pages/Index.ets`：`@State readerDisableReturnKey`（`:221`）；装载 `:1829`；快照 `:1929`；恢复备份 `:3033` 一带；setter `setReaderDisableReturnKey()`（三行式，不触发章节重读）。
3. `entry/src/main/ets/pages/ReaderSettingsPage.ets`：`@Prop disableReturnKey` 与 `onDisableReturnKeyChange`；`:1151` 的 `showNotMigrated` 占位改成真 `MenuSettingSwitch`。
4. `entry/src/main/ets/data/BackupRepository.ets`：接口字段、config.xml 导出（`upsertAndroidPreference(configText, 'boolean', 'disableReturnKey', ...)`）、readConfig.json 记录、恢复段 `readJsonBoolean ?? readXmlBoolean ?? current.disableReturnKey`。上游 `BackupConfig.readPrefKeys` 忽略清单里没有这个键，随 config.xml 无条件备份。

验收：拨开 → `<bool key="disableReturnKey" value="true"/>`；注入 `true` 重启后面板回显为开；拨回关 → `false`。详见 `docs/VALIDATION.md` 的 `KI-A3` 节。

**KI-A4 优化正文渲染（不接）** —— 覆盖 A-07（`optimizeRender`，`ReadSettings.kt:49`）。

上游这条只在 `feature/reader/legacy/LegacyReaderPaginationStyleFactory.kt:49` 的 `Build.VERSION.SDK_INT <= Q`（Android 10 及以下）分支里生效，是给老设备减少渲染开销的兼容路径。HOS 没有对应的老渲染管线，接了也没有可切换的实现。**不补**；设置页该条保留占位文案，不假装生效。

**KI-A5 朗读与在线书源三项（不接，范围之外）** —— 覆盖 A-09 朗读悬浮窗分离提醒（`readAloudDetachReminderEnabled`，`ReadBookConfig.kt:80`）、A-10 自动切换书源（`autoChangeSource`，`ReadSettings.kt:42`，含 `defaultSourceChangeAll:15`）、A-11 换源结果应用于全部书籍。

朗读（TTS）与在线书源抓取都在[项目范围](PROJECT.md)之外；因开关已上屏，判 `未接` 而非 `不适用`。补法：随对应子系统接入，本轮不动。

**KI-A6 自动切换日夜模式提醒（已实现）** —— 覆盖 A-12（`autoSuggestDayNight`，`ReadSettings.kt:43`）。

上游不是「到点弹提示」，是**环境光传感器驱动**：`ReadBookRouteScreen.kt:1089-1138` 的 `AutoSuggestDayNightObserver` 在 `repeatOnLifecycle(RESUMED)` 里注册 `TYPE_LIGHT` 监听，取 lux 后 `onIntent(CheckSwitchDayNight(lux))`，再 `delay(15.minutes)` 循环；判定在 `ReadStyleDelegate.kt:503-555`（`DARK_LUX_THRESHOLD = 8f`、`BRIGHT_LUX_THRESHOLD = 100f`、`LIGHT_LUMINANCE_THRESHOLD = 0.35`，另有 10 分钟冷却 `REMINDER_COOLDOWN_MS`），命中后由 `ReadBookFloatingActionBar.kt:122-156` 的 `ThemeReminderCapsule` 显示 5 秒自动消失的底部胶囊（切换 / 关闭两个按钮），点过「关闭」后本次会话不再提示。

**为什么早先记为「本轮不做」，以及那条理由为什么作废**

早先的判断是「HOS 侧要完整对齐需 `@kit.SensorServiceKit` 的 `sensor.on(SensorId.AMBIENT_LIGHT, …)` 常驻订阅，模拟器大概率没有环境光传感器」。本轮实测证伪：

- `hdc shell "hidumper -s SensorService -a '-l'"` 在本机模拟器上直接列出 `sensorType:AMBIENT LIGHT |sensorId:5 |sensorName:light |vendorName:Taos |maxRange:10000`；
- 应用订阅之后，`hidumper -s SensorService -a '-o'`（已打开的传感器）会多出 `AMBIENT LIGHT |sensorId:5 |channelSize:1`，说明订阅链路真的通了。

所以「上游有这个问题」在 HOS 侧是**能保留**的，不接反而成了缺口。

**本地落地**

1. `entry/src/main/ets/data/ReaderSettingsRepository.ets`：`ReaderSettingsSnapshot` 加 `autoSuggestDayNight: boolean`（默认 `false`），存储键与上游 `PreferKey.kt:120` 同名，`load`/`save`/默认值三处对齐。
2. `entry/src/main/ets/pages/Index.ets`：`@State @Watch('onReaderAutoSuggestDayNightChanged') readerAutoSuggestDayNight`；`:101` 的 `route` 加 `@Watch('onReaderRouteChanged')`，进 `AppRoute.READER` 时 `startReaderAmbientLightWatch()`、离开时 `stopReaderAmbientLightWatch()` 并清空提醒（对齐上游 `repeatOnLifecycle(RESUMED)` 的生命周期口径）。
3. 订阅：`sensor.on(sensor.SensorId.AMBIENT_LIGHT, (data: sensor.LightResponse) => this.checkReaderDayNightReminder(data.intensity), { interval: 1000000000 })`（1 秒一帧，上游是 `SENSOR_DELAY_NORMAL` + 首帧 `delay(1.seconds)`，本地取等价的最小实现，不再叠 15 分钟节流轮询——1 秒间隔本身开销可忽略，且判定里有 10 分钟冷却兜底）。
4. 判定 `checkReaderDayNightReminder(lux)`：复刻 `ReadStyleDelegate.kt:503-555` 的四个常量 `DARK_LUX_THRESHOLD = 8`、`BRIGHT_LUX_THRESHOLD = 100`、`LIGHT_LUMINANCE_THRESHOLD = 0.35`、`REMINDER_COOLDOWN_MS = 10 * 60 * 1000`；白天且 `lux <= 8` 且当前背景偏亮时提醒切深色，夜间且 `lux >= 100` 且当前背景偏暗时提醒切浅色；背景亮度由 `computeReaderColorLuminance()` 按 sRGB 线性化后以 0.2126/0.7152/0.0722 加权（等价于 Android `ColorUtils.calculateLuminance`）。
5. 两个 dismissed 标记 `readerDayNightReminderDismissedDark`/`ReaderDayNightReminderDismissedLight` 对应上游 `hasDismissedDarkReminder`/`hasDismissedLightReminder`：点「关闭」后本次会话不再提示；`toggleReaderNightMode()` 与「开关被打开」时复位，对齐上游 `resetDayNightReminderDismissal()`。
6. 胶囊 `ReaderPage.ets` 的 `@Builder ReaderDayNightReminderCapsule()`：文案「当前环境光较暗，是否切换至深色模式？」/「当前环境光较亮，是否切换至浅色模式？」（`switch_to_dark_mode_tip`/`switch_to_light_mode_tip`），左侧「切换」按钮直接 `onAcceptDayNightReminder()`，右侧「关闭」`onDismissDayNightReminder()`；贴底居中、`padding({ bottom: 88 })`、`zIndex(900)`、`hitTestBehavior(HitTestMode.Default)`，菜单展开时（`controlsVisible`）不显示，对齐上游 `takeIf { !state.menuVisible }`；5 秒自动消失由 `showReaderDayNightReminder()` 里的 `setTimeout` 按请求序号实现（对齐 `LaunchedEffect(reminder.id) { delay(5.seconds); DismissReminder }`）。
7. `entry/src/main/ets/pages/ReaderSettingsPage.ets:1138`：原占位 `showNotMigrated` 换成真 `MenuSettingSwitch`。
8. `entry/src/main/ets/data/BackupRepository.ets`：`autoSuggestDayNight` 三个方向全接（接口字段、config.xml `upsertAndroidPreference`、readConfig.json 记录、恢复段 `readJsonBoolean ?? readXmlBoolean ?? current`）。上游 `BackupConfig.readPrefKeys` 忽略清单里没有它，随 config.xml 无条件备份。

**已知差异**

- 传感器采样间隔用固定 1 秒（上游 `SENSOR_DELAY_NORMAL` 名义 5Hz 但只在 RESUMED 且每 15 分钟取一帧），本地更密但由 10 分钟冷却与 dismissed 标记兜底，不会刷屏。
- 平板/横屏下背景亮度取自用户配置的背景色；背景是图片时（`bgType != 0`）按「浅色」处理，上游此时读 `ReadSessionState.backgroundMeanColor`（页面背景图片的平均色），本地没有这个采样。
- **胶囊按钮的点击未能取证**：该模拟器当前没有一本正文可读的书（本地书正文文件已丢失，点书架卡片只进详情页，详情页的「阅读」入口也不进阅读页），无法稳定停在阅读页等胶囊出现再点。代码侧 `acceptReaderDayNightReminder()` 直接调 `toggleReaderNightMode()`，与上游「切换」按钮语义一致。

**验收**

- 构建 `BUILD SUCCESSFUL in 31 s 589 ms`，`install bundle successfully`。
- 设备：注入 `autoSuggestDayNight=true` + `readerNightMode=false` 后重启进阅读页，连续 4 轮 `uitest dumpLayout` 的第 1、2 轮读到「当前环境光较暗，是否切换至深色模式？」（bounds `[114,2307][934,2360]`）与「关闭」（`[1074,2307][1166,2360]`），第 3、4 轮消失——**弹出与 5 秒自动消失都对**（模拟器环境光恒为暗，`lux <= 8`）。
- 测试期改动已复原为 `readerNightMode=true`、`autoSuggestDayNight=false`。

**KI-A7 触感反馈两项（已实现）** —— 覆盖 A-13 阅读进度条触感反馈（`sliderVibrator`，`ReadSettings.kt:36`）、A-15 文字选择触感反馈（`selectVibrator`，`:41`）。

**上游口径（关键：两个开关只有一个真消费）**

- `sliderVibrator`：**上游 UI 侧零消费点**。全仓 `grep -rn sliderVibrator app/src/main/java` 只命中 `PreferKey.kt:444`、`ReadSettingsRepository.kt:125`/`:404`/`:527`/`:661`、`ReadSettings.kt:36`、`MoreConfigSheet.kt:360`（设置项）、`ReadConfig.kt:80`、`ReadConfigContract.kt:34`、`ReadConfigScreen.kt:293`、`ReadConfigViewModel.kt:131`/`:204`，`feature/reader` 一处都没有；`ReadBookMenuBarBottom.kt` 也没有 haptic。按「上游没有就不要这个效果」，本地**只做可配 + 落库 + 随备份，不给进度条加振动**。
- `selectVibrator`：真消费。`ReadBookRouteScreen.kt:755 selectionHapticsEnabled = readPreferences.selectVibrator` → `ReaderCanvasSurface.kt:228` 参数、`:312 rememberUpdatedState`，两处触发：`:1109`（长按选中首个词，`HapticFeedbackType.LongPress`）、`:1225`（拖手柄后 `updatedSelection != selection`，`HapticFeedbackType.TextHandleMove`）。

**本地落地**

1. 新文件 `entry/src/main/ets/data/ReaderHaptics.ets`：`ReaderHaptics.selectionStart(enabled)`（40ms）、`selectionMove(enabled)`（15ms），底层 `vibrator.startVibration({ type: 'time', duration }, { usage: 'touch' })`，双层 try/catch 吞异常并 `console.warn`（模拟器无马达会抛 14600101）。
2. 两个字段：`ReaderSettingsSnapshot` 的 `sliderVibrator`（`:211`）/`selectVibrator`（`:217`），默认 `false`；读 `:538`/`:539`，写 `:872`/`:873`。
3. `Index.ets`：`@State readerSliderVibrator`（`:206`）/`readerSelectVibrator`（`:208`），装载 `:1735-1736`、快照 `:1847-1848`、恢复后重载 `:2481-2482`、setter `:2301`/`:2306`；5 处组件调用点（1 处 `ReaderPage` 只传 prop，4 处 `ReaderSettingsPage` prop + 回调）。
4. `ReaderPage.ets`：`@Prop selectVibrator`（`:174`），消费在 `updatePendingLineSelection` 里，只在**选区真的变化**时振（首次 `selectionStart`，之后 `selectionMove`），对应上游「首个词」与「拖手柄」两处。
5. `ReaderSettingsPage.ets`：两个开关从 `showNotMigrated` 占位改为真开关（`:892`/`:897`）。
6. 备份：两键都不在 `BackupConfig.readPrefKeys` 忽略清单里 → 随 `config.xml` 无条件导出；本地导出 `BackupRepository.ets:569-573`、恢复 `:1243-1246`。

**验收**：设备上拨「进度条触感反馈」→ 偏好文件 `sliderVibrator` 变 `true`，拨回变 `false`；「文字选择触感反馈」同样 `selectVibrator` `true`/`false` 往返。振动本身在模拟器上无法确认（无马达），只到「开关落库 + 代码路径核对」这一级。

**KI-A8 使用新版目录（不接）** —— 覆盖 A-14（`useNewTocSheet`，`ReadSettings.kt:37`）。

上游这个字段是「阅读页内开 Sheet」与「跳独立目录页」两种呈现的切换开关（`ui/book/read/ReadBookViewModel.kt:193`）。本地目录固定为 `CatalogPage.ets` 独立页一种形态，没有第二态可切。为它造一个不存在的新旧目录等于凭空加功能，**不补**。

**KI-A9 阅读亮度四项（已实现）** —— 覆盖 A-16（`readBrightness`，`ReadSettings.kt:22`，默认 100）、E-36 显示亮度视图（`showBrightnessView`，`:20`，默认 `"0"`）、E-37 亮度条位置（`brightnessVwPos`，`:21`，默认 `"1"`）、以及原 KI-E6 的「自动亮度」一项（`brightnessAuto`，`:23`，默认 `true`）。

上一版把「自动亮度」单放在 KI-E6 里判「要接，需先补上屏」。实际核对上游后修正：上游**没有**独立的「自动亮度」设置条目 —— `ui/config/readConfig/ReadConfigScreen.kt:182-199` 只有 `show_brightness_view` 与 `brightnessVwPos` 两项，自动亮度是亮度条上的一个内联按钮（`ReadBookMenuBarBottom.kt:316` 的 `BrightnessBar(brightnessAuto, onToggleAuto, ...)`）。所以「没有上屏条目」不是缺口，本地按同一形态挂在亮度条上即可，本轮与 A-16 一并接上。

**上游口径（逐条）**
- **存储键与字段名不一致，这是本组最容易踩的坑**：`data/repository/ReadSettingsRepository.kt:380-391` —— `showBrightnessView = compatDsString(PreferKey.readBrightnessMode)`、`brightnessVwPos = compatDsString(PreferKey.readBrightnessControlPosition)`、`readBrightness = compatDsValue(Keys.ReadBrightness, 100)`、`brightnessAuto = compatDsValue(Keys.BrightnessAuto, true)`。对应 `constant/PreferKey.kt:112 readBrightnessMode`、`:193 readBrightnessControlPosition`、`:151 brightness`、`:194 brightnessAuto`。
- **备份口径也不一致**：`help/storage/BackupConfig.kt` 的 `readPrefKeys` 忽略清单里**有** `readBrightnessMode` 与 `readBrightnessControlPosition`（不导出），**没有** `brightness` 与 `brightnessAuto`（随 config.xml 无条件备份）。本地 `BackupRepository.ets` 的 `preferenceKeysByCategory.readConfig` 早前列的就是前两个键，与上游一致；后两个按 config.xml 条目导出。
- 应用到窗口：`ui/book/read/ReadBookController.kt:3179-3187` `applyReadBrightness()` —— `lp.screenBrightness = if (ReadBookConfig.brightnessAuto) WindowManager.LayoutParams.BRIGHTNESS_OVERRIDE_NONE else ReadBookConfig.readBrightness / 100f`；开书时 `:1833` 调一次；退出 `:3192` 还原 `originalScreenBrightness`（原值在 `:464` 捕获）。拖动滑块实时生效走 `ReadBookEffect.SetBrightness` → `:2465-2469`（**这条不看 `brightnessAuto`**，上游有意的「拖动即覆盖自动」）。
- 亮度条位置：`ui/book/read/ReadBookMenuBarBottom.kt:139-163` 只在 `showBrightnessView == "1"` 时在底栏横排；`ReadBookMenuBar.kt:250-268` 顶栏 `vertical = true` 并给 `onTogglePosition` 在 `"0"`/`"1"` 间切换。
- 设置项可见性：`ReadConfigScreen.kt:182-199` 里「亮度条位置」**只在「显示亮度视图」为「竖排」时出现**。

**本地落地**
1. `entry/src/main/ets/data/ReaderSettingsRepository.ets`：接口 `:243` `readBrightness`、`:249` `showBrightnessView`、`:254` `brightnessVwPos`、`:256` `brightnessAuto`；默认 `:609-612`；读 `:733-736`（存储键分别 `brightness`/`readBrightnessMode`/`readBrightnessControlPosition`/`brightnessAuto`）；归一 `:1009-1014`（亮度夹 1..100 —— 0 会让窗口全黑）；写 `:1174-1177`。
2. `entry/src/main/ets/pages/ReaderPage.ets`：`@Prop @Watch('onReadBrightnessChanged') readBrightness`、`@Prop showBrightnessView`、`@Prop brightnessVwPos`、`@Prop @Watch('onReadBrightnessChanged') brightnessAuto`；`applyReaderBrightness()`（`:747`）用 `this.brightnessAuto ? -1 : Math.max(0, Math.min(1, this.readBrightness / 100))` 调 `setWindowBrightness`，带 requestId 防乱序；`restoreReaderBrightness()` 调 `-1`；`aboutToAppear()`/`aboutToDisappear()` 分别调用。
3. 亮度条 UI：`ReaderPage.ets:2544` 的 `@Builder ReaderBrightnessBar(vertical)` + `ReaderBrightnessSlider(vertical)`，挂载点 `:3805`（底栏进度条上方，`showBrightnessView` 为 `'1'`/`'2'` 时显示）。**自动亮度按钮本轮未做**：本地亮度条只有滑块，没有上游那个内联的「自动」开关 —— 见「已知差异」。
4. 面板：`ReaderSettingsPage.ets:2239`/`:2240` 两条（分段控件 + 详情面板），回显走 `getBrightnessViewDetail()`/`getBrightnessPositionDetail()`；`:926` 让「亮度条位置」只在竖排时可见。
5. 备份：`BackupRepository.ets` 的接口、config.xml 导出（只导 `brightness`/`brightnessAuto`）、readConfig.json 记录（四键都记）、恢复段（四键都恢复）。

**已知差异**
- **窗口亮度的视觉效果无法在模拟器取证**：`setWindowBrightness()` 是真实调用（`-1` 表示恢复系统亮度，与上游 `BRIGHTNESS_OVERRIDE_NONE` 等价），但模拟器截图不叠加窗口亮度 —— `brightness=20` 与 `brightness=100` 两次全屏截图的平均亮度都是 36.16。故本组的验收只到「四键落库 + 面板回显 + 可见性联动 + 代码路径核对」。
- 亮度条上没有「自动亮度」按钮，自动亮度目前只能由备份恢复或面板外写入 `brightnessAuto`。上游该按钮是 `BrightnessBar` 的 `onToggleAuto`，本地 `ReaderBrightnessBar` 尚未加，属于后续 E 块统一做菜单外观时的收尾项。
- 上游拖动滑块会绕开 `brightnessAuto` 直接写窗口亮度；本地滑块只调 `onReadBrightnessChange` 落库，`applyReaderBrightness()` 在 `brightnessAuto` 为真时仍用 `-1`，因此**自动亮度开着时拖滑块不会立刻变亮**。这是本轮的简化，已在 VALIDATION 记明。

**KI-A10 主题网格列数（不接）** —— 覆盖 A-18（`themeGridColumns`，`ReadSettings.kt:40`，默认 4）。

本地背景/主题是 `READER_BACKGROUND_STYLES` 六个内置方案的自绘列表（`entry/src/main/ets/data/ReaderSettingsRepository.ets:339-346`，入口 `ReaderSettingsPage.ets:1281`），不是网格布局，该字段没有消费面。**不补**；将来若把面板改成网格，再一并接。

**KI-A11 预下载两项（不接，范围之外）** —— 覆盖 A-19 向后预下载章节数（`preDownloadNum`，`ReadSettings.kt:58`，默认 10）、A-20 向前预下载章节数（`preDownloadNumPrev`，`:59`，默认 0）。

依赖离线缓存/预下载子系统；本地 `AppDownloadCacheSettingsPage.ets:31` 是预览页，没有缓存实现。补法：随下载缓存子系统接入。

**KI-A12 在浏览器打开（不接，范围之外）** —— 覆盖 A-21（`readUrlInBrowser`，`ReadSettings.kt:64`）。

需要外部应用跳转（`module.json5` 的 browser skill），属跨应用能力而非配置接线。补法：加 browser skill 后用 `startAbility(ACTION_VIEW)` 打开；本轮不动。

### C 正文排版

**KI-C1 正文取色三项（已实现，与 KI-C2 同轮）** —— 覆盖 C-01 正文日间颜色（`textColor`，`ReadBookConfig.kt:55`）、C-02 正文夜间颜色（`textColorNight`，`:56`）、C-03 正文强调色（`textAccentColor`/`Night`，`:62`）。

上游口径：`ReadBookConfig.kt:55-61` 声明 `textColor`/`textColorNight`/`textAccentColor`，默认 `#834E00`（白天）/ `#FE4D55`（夜间）。`textAccentColor` 的真实消费点只有一个——`ReaderCanvasSurface.kt:2997 resolvedColorArgb(text, accentColorArgb)`，即**链接文字、搜索结果、朗读中的段落**三处换色，不是给划线用的。

本地落地（5 处）：
1. `ReaderSettingsRepository.ets:228`/`:230`/`:235` 三对字段（含 `textAccentColorNight`）；默认 `:505`/`:506`/`:508` 取原硬编码值（`#38383B`/`#D8D8DC`）以免升级后观感突变，强调色默认与上游一致；读 `:835`–`:838`；写 `:956`–`:959`。
2. `Index.ets` 加 `readerTextColor` 等四个 `@State` + `getReadingTextColorSetting()`/`getTextAccentColorSetting()`，作为 prop 传给 `ReaderPage`。
3. `ReaderPage.ets` 的 `getReadingTextColor()` 改为「配置色非空优先，空则回落原三值判断」；新增 `textAccentColor` prop（供后续链接/朗读高亮使用）。
4. `ReaderSettingsPage.ets:1373-1430`「自定义阅读背景」面板加「日间文字颜色」「夜间文字颜色」「日间强调色」「夜间强调色」四个色板。
5. `BackupRepository.ets` 导出/恢复两条链路补齐这四个键（上游不在 `readPrefKeys` 忽略清单里，随 `config.xml` 无条件导出）。

已知差异：上游强调色驱动链接/搜索结果/朗读高亮三处着色，**本地这三条路径都还没有**（阅读页搜索只切路由、朗读整体未迁移），按「上游有这个问题就保留、上游没有就不要这个效果」，本地只做可配+落库+随备份，不发明新着色效果。

验收：注入 `textColor = #DB4B4B` 后重进阅读页，截图彩色像素 top8 全为红色系（`(213,77,77)` 等），正文与章节标题同时变红；改回 `#38383B` 恢复正常深灰。见 [VALIDATION](../VALIDATION.md)。

**KI-C2 背景三项（已实现，与 KI-C1 同轮）** —— 覆盖 C-04 背景透明度（`bgAlpha`，`ReadBookConfig.kt:198`，默认 100）、C-05 背景颜色/图片（`bgStr`/`bgStrNight`/`bgType`/`bgTypeNight`，`:537-551`）、C-06 白天是否暗色状态栏（`darkStatusIcon`/`Night`，`:552`）。

上游口径：`bgStr` 存任意颜色串，颜色与图片**共用** `bgStr`，由 `bgType` 区分（`ReadBookConfig.kt:549`，0=颜色/1=assets 图/2=自选图）；`bgAlpha` 0..100 百分比，经 `ReaderBackgroundAlpha.kt` 的 `readerBackgroundAlpha(percent) = (percent / 100f).coerceIn(0f, 1f)` **只作用于背景图片**，不作用于纯色背景；`darkStatusIcon`/`Night` 在 Android 侧落在 `isAppearanceLightStatusBars`。

本地落地（6 处）：
1. `ReaderSettingsRepository.ets:241`–`:249` 七个字段（`bgStr`/`bgStrNight`/`bgType`/`bgTypeNight`/`bgAlpha`/`darkStatusIcon`/`darkStatusIconNight`）；默认 `:511`–`:519`；读 `:842`–`:849`；写 `:960`–`:966`。
2. `Index.getPaperColor()` 改为「自定义色优先，否则回落 `READER_BACKGROUND_STYLES` 六方案」——六方案从「唯一可选项」降级为「预设」。
3. 新建 `entry/src/main/ets/data/ReaderBackgroundImageRepository.ets`（照 `ReaderBookmarkBadgeRepository` 的 picker 那套），负责选图、16 MB 上限、复制进 `filesDir/reader-background/`、删除旧图。
4. `ReaderPage.ets` 加 `readerBackgroundImage` prop（**不能叫 `backgroundImage`**，与 ArkUI 内置属性冲突）+ 背景图 `Image(...).objectFit(ImageFit.Cover).opacity(...)` 层；两处内层容器的 `paperColor` 在铺图时改为透明，否则不透明底色会盖住图。
5. `ReaderPage.ets` 新增 `applyReaderStatusBarIcon()`/`restoreReaderStatusBarIcon()`，走 `window.setWindowSystemBarProperties({ statusBarContentColor })`（深色图标 `#E5000000`、浅色 `#E5FFFFFF`），用请求序号防异步乱序，退出阅读页还原。
6. `ReaderSettingsPage.ets:1368-1433`「自定义阅读背景」面板整块重写：日/夜两组并列（对齐上游 `BgTextConfigSheet` 的 `TinyColorModeSettingItem` 日/夜双色 + `TinyBgImageModeSettingItem` 日/夜双图），含背景色、背景图、透明度、深色状态栏图标、文字色、强调色。原来那 5 个「编辑/删除/恢复/导入/导出」占位按钮与「文件选择与样式保存尚未迁移。」一并删除。

已知差异与限制：
- `bgAlpha` 与上游一致**只作用于背景图片**，不作用于纯色背景。
- 上游 `bgType = 1` 是 assets 内置图，本地没有内置背景图集，只做 `0`（颜色）与 `2`（自选图）。
- 模拟器上图片选择器能正常弹出，但无可选图片、且沙箱 `files` 目录不可写（`mkdir`/`file send` 都 `Permission denied`），**背景图渲染与透明度只到代码层核对**，未做像素级确认。

验收：日间 `bgStr = #FFFFFF` 后阅读页中心像素为 `(255,255,255)`；`darkStatusIconNight` false 时状态栏亮像素 6726、改 true 后同一区域 0。见 [VALIDATION](../VALIDATION.md)。

**KI-C3 下划线绘制参数四项（已实现）** —— 覆盖 C-07 下划线偏移量（`underlinePadding`，`ReadBookConfig.kt:322`，默认 10）、C-08 下划线延伸（`underlineExtend`，`:325`）、C-09 自定义虚线长度基准（`dottedBase`，`:331`，默认 6f）、C-10 自定义虚线间隔比例（`dottedRatio`，`:334`，默认 6f）。

上游口径：默认值集中在 `help/config/ReadBookConfig.kt:600-609`。组装在 `feature/reader/legacy/LegacyReaderPaginationStyleFactory.kt:65-77`：`ReaderPageUnderline(colorArgb = …, widthPx = underlineHeight.toFloat(), offsetPx = (ReadBookConfig.underlinePadding - 10).dpToPx().toFloat(), extendToColumn = ReadBookConfig.underlineExtend, dashed = dottedLine && !isEInkMode, dashOnPx = durConfig.dottedBase, dashOffPx = durConfig.dottedRatio)` —— **`offsetPx` 是 `(underlinePadding - 10)` 的相对量，默认 10 时偏移为 0**。绘制在 `feature/reader/core/layout/ReaderPaginator.kt:435-455 addPageUnderline()`：`start = if (extendToColumn) columnLeft() else rowElements.minOf { it.bounds.left }`、`end = if (extendToColumn) columnLeft() + config.contentWidthPx else rowElements.maxOf { it.bounds.right }`、`y = lineBottom + offsetPx`，产出一条 `ReaderElement.Rule`；真实画笔在 `feature/reader/platform/ReaderPageDecorationDrawCache.kt:56-77`：`strokeWidth = widthPx.coerceAtLeast(1f)`、`pathEffect = DashPathEffect(floatArrayOf(dashOnPx.coerceAtLeast(0.1f), dashOffPx.coerceAtLeast(0.1f)), 0f)`、`canvas.drawLine(...)`。设置面板 `ui/book/read/sheet/UnderlineConfigSheet.kt:80-145`，四个滑块范围都是 `0f..20f`。

**为什么必须自绘（本轮最重要的判断）**：ArkUI 的 `Text.decoration()` 参数类型 `DecorationStyleInterface`（SDK `ets/component/styled_string.d.ts:760`）只有 `type`、`color`、`style`、`thicknessScale` 四个字段，**没有虚线段长、间隔或竖直偏移**，`TextDecorationStyle.DASHED` 的段长由系统固定。也就是说上游这四项在 HOS 上根本无处可传 —— 这不是「本地没接」，是「本地表达手段不够」。结论：改用 `Line()` 自绘，它的 `CommonShapeMethod` 提供 `stroke`/`strokeWidth`/`strokeDashArray`/`strokeDashOffset`，`strokeDashArray` 恰好是「dash、gap」循环数组，与 `DashPathEffect(dashOn, dashOff)` 一一对应。

本地落地：
1. 仓储 `entry/src/main/ets/data/ReaderSettingsRepository.ets` —— 接口加同名四字段 `:161`–`:164`，默认 `:506`–`:509`（10 / false / 6 / 6），读 `:620`–`:623`，归一 `:768`–`:773`（三个数值夹 0–20），写 `:1018`–`:1021`。
2. 分页器 `entry/src/main/ets/pages/LocalReaderPaginator.ets` —— `interface LocalReaderLine` 新增 `contentWidth: number`（该行未拉伸时的文字实际宽度），在 `appendLine()` 里赋 `contentWidth: naturalWidth`，供自绘线决定右端；这是「不撑满时线只到该行文字右边界」所需的几何。
3. 渲染 `entry/src/main/ets/pages/ReaderPage.ets` —— 加四个 `@Prop`（`underlinePadding` 10 / `underlineExtend` false / `dottedBase` 6 / `dottedRatio` 6）。新增 `resolveUnderlineOffsetVp()`（`underlinePadding - 10`，直接对齐上游相对量口径）、`resolveUnderlineWidthVp()`（`max(1, underlineHeight)`，对齐 `coerceAtLeast(1f)`）、`resolveUnderlineDashArray()`（非虚线返回 `[]` 即实线，虚线返回 `[max(0.1, dottedBase), max(0.1, dottedRatio)]`，对齐 `coerceAtLeast(0.1f)`）、`resolveUnderlineLineEnd()`（`underlineExtend` 时取 `getBodyContentWidth()`，否则取 `min(列宽, line.contentWidth)`）、`readerPageLineOffset()`/`readerUnderlineY()`（按 `LocalReaderLine` 的 `verticalSpaceBefore + height + paragraphSpacingAfter` 累加出行底 y；走 `ReaderPageTextJoined` 时整页共用一个 `lineHeight`，改按 `(index + 1) * lineHeight` 定位）。新增 `@Builder ReaderUnderlineLayer(uniform)`：`Stack` 内 `ForEach` 每行画一条 `Line()`，`startPoint([0, y])` → `endPoint([end, y])`，`stroke` 取 `getReaderUnderlineColor()`、`strokeWidth` 取 `resolveUnderlineWidthVp()`、`strokeDashArray` 取 `resolveUnderlineDashArray()`。分页正文外层因此改成 `Stack { Column { 正文 + Blank } ; ReaderUnderlineLayer }`（下划线要按行底定位，只能叠在正文之上）。
4. 避免双线 —— 原来 6 处 `Text.decoration` 里的正文下划线回落全部收敛为 `TextDecorationType.None`：`ReaderGlyphSpan` 的高亮分支与 marking 分支、`ReaderPageTextJoined()` 的整块 Text、`ReaderPageTextLine` 的图片行与正文行、以及 `getReaderHighlightTextRuns()` 里的回落。**但 marking/highlight 自身语义的 decoration 保留**（那是划线/高亮规则的线，与「正文下划线」不是一回事）。
5. 备份 `entry/src/main/ets/data/BackupRepository.ets` —— `AndroidReadConfigBackupRecord` 补四字段，导出写 `config.xml`（`int` / `boolean` / `float` / `float`），恢复按 `readJsonNumber`/`readJsonBoolean`/`readXmlInteger`/`readXmlFloat` 取值并夹 0–20，缺键保留现值。这四键不在上游 `BackupConfig.readPrefKeys` 忽略清单里，随 `config.xml` 无条件备份。
6. 面板 `entry/src/main/ets/pages/ReaderSettingsPage.ets` —— 「文字效果」面板在「下划线粗细」之后补「离字间距」滑块（0–20）、「撑满整行」开关；`dottedLine` 为 true 时再展开「实线段长」（0–20）与「空隙长度」（0–20）两个滑块。

已知差异：
- **滚动模式不支持这四项**。`ReaderPageTextJoined`/`ReaderPageTextLine` 之外，滚动模式（`Scroll` 里那串 `Text`）拿不到逐行几何，无法自绘，仍用 `Text.decoration` 表达下划线，因此虚线段长/间隔/偏移/延伸只在分页模式生效。已在代码注释与本节同时记录。
- 单位：上游 `dottedBase`/`dottedRatio` 是 px，本地按 vp 传给 `strokeDashArray`，两者在 3.5 密度屏上比值为 3.5，视觉疏密随设备密度略有不同。

验收：设备实测三档 `underlinePadding` 0 / 10 / 20 时同一行下划线 y 依次为 409 / 444 / 478（每档差 ~35px = 10vp × 3.5 密度，线性成立）；`underlineExtend` 关闭时短行 `x0=56 x1=720`（宽 665），打开后所有行统一 `x0=56 x1=1223`（宽 1168）；`dottedBase=6` 单行 34 段、`dottedBase=20` 单行 18 段。见 [VALIDATION](../VALIDATION.md)。

**KI-C4 标题排版十四项（已实现）** —— 覆盖 C-11 标题位置模式（`titleMode`，`ReadBookConfig.kt:267`）、C-12 标题字号（`titleSize`，`:269`）、C-13 标题字号是否相对正文（`titleSizeRelative`，`:270`）、C-14 标题上间距（`titleTopSpacing`，`:298`）、C-15 标题下间距（`titleBottomSpacing`，`:301`）、C-16 标题日间颜色（`titleColor`，`:304`）、C-17 标题夜间颜色（`titleColorNight`，`:307`）、C-18 标题字重（`titleBold`，`:228`）、C-19 标题行距（`titleLineSpacingExtra`，`:255`）、C-20 标题行距子项（`titleLineSpacingSub`，`:258`）、C-21 标题分段模式（`titleSegType`，`:280`）、C-22 标题分段缩放（`titleSegScaling`，`:283`）、C-23 标题分段起始位置（`titleSegDistance`，`:287`）、C-24 标题分段识别字符（`titleSegFlag`，`:290`）。

上游口径：十四项全部是 `help/config/ReadBookConfig.kt` 的字段，默认值集中在 `:596-608` 的构造参数块。访问器 `:228`（titleBold）、`:255`（titleLineSpacingExtra）、`:258`（titleLineSpacingSub）、`:267-270`（titleMode/titleSize/titleSizeRelative）、`:280`（titleSegType）、`:283-287`（titleSegScaling/titleSegDistance）、`:290`（titleSegFlag）、`:298-301`（titleTopSpacing/titleBottomSpacing）、`:304-307`（titleColor/titleColorNight）。字号解析 `:669-676`：`isTitleSizeRelative() = titleSizeRelative ?: (titleSize < 8)`，`resolvedTitleSizeSp() = (if (isTitleSizeRelative()) textSize + titleSize else titleSize).coerceAtLeast(1)` —— 即默认 4 属于「相对正文」。颜色回落 `:311` + `feature/reader/legacy/LegacyReaderPaginationStyleFactory.kt:52`：`titleColor.takeIf { it != 0 } ?: bodyStyle.colorArgb`，即 0 表示未设置、回落正文色。字重口径同文件 `:113-119`：`resolveWeight(configured) = when (configured) { 1 -> 900; 2 -> 300; in 100..900 -> configured; else -> 400 }`（**注意默认 500 会落到 else 分支的 400**）。行距与间距 `:98-101`：行距字段除以 10 作行高倍率，间距字段按 dp 折算。分段规则 `feature/reader/core/source/ReaderTitleSegmentation.kt`（44 行）：先按换行切行去空，再按 `type` 分支，type 1 按 `distance` 字数切两段、type 2 把 `delimiter` 逗号分词后逐项 `Regex::escape` 再 `joinToString("|")`、type 3 直接拿 `delimiter` 当正则，两者都以 `Regex("(?<=$pattern)")` 零宽后行断言切分并 `runCatching` 回落整行；首段 `fontSizeScale = 1f`，其余段 `= subtitleScale` 且 `isSubtitle = true`。设置面板在 `ui/book/read/sheet/TypographyTabs.kt:440-451`。

本地落地：
1. 仓储 `entry/src/main/ets/data/ReaderSettingsRepository.ets` —— `ReaderSettingsSnapshot` 加同名 14 字段（`:255`–`:291`），默认值 `:563`–`:576`（titleMode 0、titleSize 4、titleSizeRelative true、间距 0、颜色空串、titleBold 500、两个行距 12、分段模式 0、分段缩放 1、分段起始 4、分段字符空串），读 `:661`–`:674`，归一 `:923`–`:943`，写 `:1061`–`:1074`。新增两个工具函数：`normalizeOptionalHexColor()`（空串合法、表示「未设置、回落正文色」，与上游 0 同义）与`normalizeFraction(…, 1, 2, …)`（负值回落 1、上限 2，照搬上游 `titleSegScaling` 规则）。
2. 分段模块 `entry/src/main/ets/data/ReaderTitleSegmentation.ets`（新建，109 行）—— 照上游同名 Kotlin 文件移植：导出 `ReaderTitleSegment`（text/offset/isSubtitle/fontSizeScale）与 `segmentReaderTitle()`，私有 `splitTitleLine()` 四分支与 `escapeRegExp()` 与上游逐一对应，正则构造失败回落整行。
3. 渲染 `entry/src/main/ets/pages/ReaderPage.ets` —— 加 14 个 `@Prop`（其中 12 个带 `@Watch('onPaginationInputsChanged')`，titleColor/titleColorNight 不带，因为只改颜色不需要重排）。新增 `resolveTitleSizeFp()` `:2140`、`resolveTitleWeight()` `:2149`、`resolveTitleColor()` `:2157`、`resolveTitleAlign()` `:2163`、`resolveTitleTopSpacing()` `:2168`、`resolveTitleBottomSpacing()` `:2173`、`resolveTitleLineSpacingFactor()` `:2182`、`resolveTitleSegments()` `:2188`、`isReaderTitleVisible()` `:2200`、`measureTitleReservedLines()` `:2238`，以及 `@Builder ReaderTitleSegments()` `:2209`。**9 处 `this.fontSize + 4` 硬编码全部清除**（`rebuildReaderPages()` 与 `countPagesIncrementally()` 的整块标题度量被压成一次 `measureTitleReservedLines()` 调用），两处标题写死的 `.margin({ bottom: 24 })` 改由 `titleBottomSpacing` 承担。分页时标题页的判定改走 `isReaderTitleVisible()`，因此 `titleMode = 2` 时标题既不绘制也不单独占一页。
4. 界面 `entry/src/main/ets/pages/ReaderSettingsPage.ets` —— 排版面板的「标题」tab 由占位改为真分支（`if (this.detailSelectedOption === '标题') { this.TitleTypographySettings() }`）：新增 `TitleChoiceRow` 组件 `:336` 与 `TitleTypographySettings` `:357`，含标题位置三选一 `:360`、标题字号滑块、「字号相对正文」开关、上下间距滑块、标题字重五档 `:386`、两个行距滑块、日/夜标题色板（`READER_TITLE_COLORS` `:20`，不含空串，因为空串在色板里会画成无色块）、「标题颜色跟随正文」一行、标题分段四选一 `:419` 与条件展开的分段字数/分隔符输入/副标题字号比例。标签函数 `getTitleSizeLabel()` `:1225`、`getTitleColorLabel()` `:1230`、`getTitleSegTypeLabel()` `:1236`。
5. 备份 `entry/src/main/ets/data/BackupRepository.ets` —— `AndroidReadConfigBackupRecord` 补 14 字段 `:209`–`:223`，导出 `toAndroidReadConfig()` `:1077`–`:1090`，恢复 `:1204`–`:1227`（缺键时保留本机现值）。这 14 个键不在上游 `BackupConfig.readPrefKeys` 忽略清单里，随 `config.xml` 无条件备份，本地口径一致。

已知差异：
- 上游 `titleSizeRelative` 是 `Boolean?`（null 表示按旧约定 auto），本地存 `boolean` 并显式默认 `true`。因为 `titleSize` 默认 4 < 8，上游 null 态与本地 `true` 的解析结果完全相同，不构成差异；唯一差别是本地无法表达「未设置」，备份写出去永远是明确的 true/false 而不是缺键。
- 标题分段用 ArkTS 正则移植，能力以 ArkTS 引擎支持为限（上游是 Kotlin/JVM 正则）。`escapeRegExp()` 与上游 `Regex::escape` 的字符集一致，`(?<=…)` 后行断言在 ArkTS 可用；复杂正则（如含 named group）可能行为不同，但 `runCatching` 的兜底在本地同样存在（回落整行不崩溃）。
- 上游标题颜色是 `Int` 型 ARGB、`0` 表示未设置；本地是可选 `#RRGGBB` 字符串、空串表示未设置。语义一一对应，但备份里一个是整数一个是字符串，跨端还原时由 `BackupRepository` 的键级读写各自处理。
- 上游 `titleLineSpacingExtra`/`titleLineSpacingSub` 参与 `TextPage` 行高计算（除以 10），本地用同样的倍率作用在 `Text.lineHeight()` 上；因为 ArkUI 的 Text 一行内多段行距不是逐段可配，本地按「段」为单位设 lineHeight，与上游按行内 span 处理的粒度略有不同。

验收：
- 面板上屏：设置 → 阅读界面 →「排版」→「标题」tab，14 组控件全部可读到（标题位置/标题字号（正文 + 4）/字号相对正文/标题上间距/标题下间距/标题字重/标题行距/标题副项行距/日间标题颜色/夜间标题颜色/标题颜色跟随正文/标题分段/分段字数/副标题字号比例）。
- 落库：点「居中显示」后偏好文件 `titleMode` = `1.000000`；点「纤细」→ `titleBold` = `300.000000`；点日间色板第 4 颗 → `titleColor` = `#FFFFFF` 且面板标签同步变「日间标题颜色（#FFFFFF）」；点「按字数」→ `titleSegType` = `1.000000` 并联动出现「分段字数」行。
- 渲染决定性证据（正反对照）：`titleSegType=1`（按 4 字分段）时 dump 出两个独立 Text 节点「第二章」`[56,157][1224,342]` + 「乙」`[56,342][1224,527]` 且都居中；改回「不分段」重进同章变成单个「第二章 乙」`[56,157][1224,342]`。`titleMode=2` 时正文直接从 `[56,157]` 开始、标题节点完全不存在。夜间模式下注入 `titleColorNight=#FF8C00` 后，标题区橙色像素 6153 个、整页也是 6153 个（正文零橙色）。
- 验收后测试值已复原（设备偏好文件里 0 个 `title*` 键，回到默认）。
**KI-C5 繁简转换（已实现）** —— 覆盖 C-25（`chineseConverterType`，`ReadSettings.kt:118`，三档）。

上游口径：`chineseConverterType` 取 0/1/2（`arrays.xml:173-177` 的 `chinese_mode`，中文文案见 `values-zh-rCN/arrays.xml:76-80`：关闭简繁转换 / 繁体转简体 / 简体转繁体）。设置项在排版面板（`ui/book/read/sheet/TypographyTabs.kt:310-321`，entryValues 为 `"0"/"1"/"2"`）。两处应用点：正文 `help/book/ContentProcessor.kt:161-171`（`reSegment` 之后、HTML 占位之前，`when (chineseConverterType) { 1 -> ChineseUtils.t2s(mContent); 2 -> ChineseUtils.s2t(mContent) }`），章节标题 `data/entities/BookChapter.kt:103-116`（先转换再逐条套替换规则）。转换库是 `utils/ChineseUtils.kt` 包 `quick-chinese-transfer`，`t2s` 还带约 110 条排除词。该键不在 `BackupConfig.readPrefKeys` 忽略清单里，随 `config.xml` 无条件备份。

本地落地：
1. 转换能力 `entry/src/main/ets/data/ChineseTextConverter.ets`（新建）——HOS 不自带字表，改用系统 ICU 的 `i18n.Transliterator`（`@kit.LocalizationKit`，`getAvailableIDs()` 查 ID 存在再 `getInstance()`，`transform(text)` 转换）。ID 为 `Traditional-Simplified` / `Simplified-Traditional`。取不到转换器时只 `console.warn` 并原样返回，不抛异常。
2. 配置字段 `entry/src/main/ets/data/ReaderSettingsRepository.ets:222`，默认 `0`；读 `:548`、写 `:885`，读写都夹在 0–2。
3. 正文接入 `entry/src/main/ets/data/BookRepository.ets:1653`——`applyChapterContentAsync` 里净化结果之后再转换，位置对齐上游「reSegment 与净化之后」。因为正文管线是静态方法拿不到 Context，档位由 `BookRepository.setChineseConverterType()` 注入（`:91-105`）。
4. 标题接入 `entry/src/main/ets/data/ReplaceRuleRepository.ets:954`——`applyTitle` 里在去换行之后、替换规则之前转换，位置对齐上游「先转换再套规则」。同样走静态注入。
5. 设置项 `entry/src/main/ets/pages/ReaderSettingsPage.ets:1403`（排版面板「正文」页，档位文案由 `:1033 getChineseConverterLabel()` 给出），详情面板三个选项在 `:1206`，落盘在 `:628`。
6. 切换后重读当前章节：`entry/src/main/ets/pages/Index.ets:2343` 调 `:442 reloadSelectedChapterForTransform()`（与 `reloadSelectedChapter` 的差别只在路由判断——档位是在设置页改的，那时 `route` 不是 `READER`）。
7. 备份：导出 `entry/src/main/ets/data/BackupRepository.ets:576`（`int`），恢复 `:1251`（json → xml → 当前值三级回退，夹 0–2）。

验收：设备实测三档都能切换并落库（`chineseConverterType` = 0/1/2）；选「简体转繁体」后正文与章节标题同时变繁体（`第一卷 风起` → `第一卷 風起`、`这一段是占位正文` → `這一段是佔位正文`），改回「关闭简繁转换」后恢复简体。详见 `docs/VALIDATION.md` 2026-10-31 KI-C5 节。

已知差异：上游字表带 t2s 排除词（如「雪梨」「芝士」这类一词多形的），ICU 转换没有这层修正，个别词形可能不同。这是转换库差异，不是接线缺失。

**KI-C6 字体文件夹（不接）** —— 覆盖 C-26（`fontFolder`，`ReadSettings.kt:79`）。

上游是「用户指定一个目录，扫描其中所有 TTF/OTF」（`ui/book/read/ReadBookScreen.kt:470`）。HOS 应用无法递归扫描任意用户目录；本地等价能力是 `ReaderFontRepository.listFonts()` 列系统字体 + 导入字体到应用私有目录（r265 起可用），入口就在排版设置面板。**不补**，差别只在导入方式。

### D 翻页与手势交互

**KI-D1 翻页按键与鼠标滚轮（已实现）** —— 覆盖 D-01 自定义翻页按键（`prevKeys`/`nextKeys`，`ReadSettings.kt:60`/`:61`）、D-03 鼠标滚轮翻页（`mouseWheelPage`，`:28`）。

**上游口径**

- 存储键与字段名不同：`constant/PreferKey.kt:48-49` 是 `prevKeys = "prevKeyCodes"`、`nextKeys = "nextKeyCodes"`，值都是英文逗号分隔的键值串。
- 判键 `ui/book/read/ReadBookController.kt:3241-3255`：`prevKeysStr.split(",").contains(keyCode.toString())`。注意是字符串包含，不是整数比较。
- `:2699` `onKeyDown` 的顺序是**自定义键优先**：先 `isPrevKey`/`isNextKey` 命中就 `handleKeyPage` 并 `return true`，之后才轮到音量键、PAGE_UP/DOWN、SPACE、DPAD、媒体键。菜单可见时（`menuLayoutIsVisible`）直接 `return false` 不接管。
- `:2845` `mouseWheelPage(direction)`：`if (menuLayoutIsVisible || !readSettingsGateway.currentSettings.mouseWheelPage) { return }`，之后走 `keyPageDebounce(direction, mouseWheel = true, longPress = false)`。
- 面板 `ui/book/read/sheet/PageKeyConfigSheet.kt`：两个 `OutlinedTextField`，`onKeyEvent` 里读 `event.nativeKeyEvent.keyCode`，只要不是 BACK/DEL 就追加进串（空串或已以逗号结尾直接接，否则先补逗号）；「重置」清空两串，「确定」调 `ReadSettingsRepository.setPageKeys(prevKeys, nextKeys)`。

**本地落地**

1. `ReaderSettingsRepository.ets:209`/`:211`/`:213` 三字段，`:556-558` 默认值 `''`/`''`/`true`（对齐 `ReadSettings.kt:28`/`:60`/`:61`），读 `:671-673` 用 `prevKeyCodes`/`nextKeyCodes`/`mouseWheelPage` 三个偏好键，写 `:1091-1093`，归一函数 `:1241` `normalizeKeyCodes`（切逗号、只留正整数、去重）。
2. `ReaderPage.ets:545` `matchPageKey(code)` 返回 -1/1/0，`parsePageKeyCodes` `:515` 解析串，`collectPageKeyCodes` `:528` 合并自定义键与音量键（音量键仅在 `volumeKeyPage` 为真时补），`isConsumablePageKey` `:508` 只认五个能被系统让出的键。
3. `syncVolumeKeyPage` `:479` 改成按签名（`volumeKeyPage|keyPageOnLongPress|prevKeys|nextKeys`）比对后重订阅，每个键单独 try/catch，某个键不允许抢占时静默跳过而不是整组失败。
4. 滚轮：根容器 `:3869` `.onAxisEvent`，先判 `pageAnimation === 3`（滚动模式本就靠滚轮滚动，不接管）、`mouseWheelPage`、`controlsVisible`，只响应 `AxisAction.UPDATE`，`|axisVertical| < 0.5` 视为抖动，最后 `turnReaderPage(vertical > 0 ? 1 : -1)`。
5. 键盘兜底：根容器 `:3878` `.onKeyEvent` 走 `matchPageKey`，命中就翻页并 `stopPropagation()`；根容器同时 `.focusable(true)`。
6. 面板 `ReaderSettingsPage.ets:1126` 副标题由 `getPageKeysLabel()` `:1264` 生成（未配置显示「未配置」，否则 `上 X / 下 Y`）；详情面板 `:1921-1950` 两个 `TextInput` + 重置 + 确定，打开时把已存值灌进草稿（`:1349-1351`）。滚轮开关 `:1087-1088` 绑真值。
7. 备份 `BackupRepository.ets:598/600/602` 写进 config.xml（`prevKeyCodes`/`nextKeyCodes` 为 string、`mouseWheelPage` 为 boolean），`:1053-1055` 写进 readConfig.json，`:1306-1311` 恢复时 json 优先、config.xml 次之、否则保当前值。

**已知差异（SDK 硬约束，不是取舍）**

- 上游 `onKeyDown` 能吃掉任意物理键。HOS 侧：`@ohos.multimodalInput.inputConsumer.d.ts` 的 `KeyPressedConfig.key` 注释写明——API 21 起才支持 `KEYCODE_MEDIA_PLAY_PAUSE`/`KEYCODE_MEDIA_NEXT`/`KEYCODE_MEDIA_PREVIOUS`，**API 20 及以下只支持 `KEYCODE_VOLUME_UP`/`KEYCODE_VOLUME_DOWN`**。所以本机能做应用级抢占的只有这五个键（`isConsumablePageKey`）。
- 其余键值照常保存、照常随备份同步，按下时靠 ArkUI `onKeyEvent` 冒泡接收，前置条件是窗口/组件持有焦点（根容器已 `.focusable(true)`，但系统级快捷键、输入法焦点转移仍可能先吃掉事件）。面板文案已把这条写给用户，不做静默丢弃。
- 滚轮：`onAxisEvent` 是 ArkUI 的轴事件，触控板/鼠标滚轮在分页模式下接管；滚动模式（`pageAnimation === 3`）主动不接管，与上游「只在分页模式生效」一致。

**验收**

面板上屏（「鼠标滚轮翻页 / 分页模式下用滚轮翻页」「自定义翻页按键 / 未配置」）；填 `2069` 点确定后列表副标题变 `上 2069 / 下 —`，偏好文件出现 `<string key="prevKeyCodes">2069</string>`；开关点两次在 `<bool key="mouseWheelPage" value="false"/>` 与 `value="true"` 之间往返；测试值已复原为空串/`true`。**按键与滚轮的实际翻页未能取证**：该模拟器上 `uitest uiInput keyEvent` 与 `uinput -K`/`uinput -M` 连设置页明显可滚动的列表都推不动，属工具限制，见 [VALIDATION](VALIDATION.md) 同日对照实验。

**KI-D2 划词菜单三项（已实现）** —— 覆盖 D-02 选中文字菜单（`textSelectMenuConfig`，`ReadSettings.kt:53`）、D-08 展开文字菜单（`expandTextMenu`，`:51`）、D-09 显示选择菜单图标（`showSelectMenuIcon`，`:52`）。

**上游口径**：三个字段都在 `domain/model/settings/ReadSettings.kt:51-53`，偏好键名与字段名完全相同（`constant/PreferKey.kt:153-155`），且都不在 `help/storage/BackupConfig.kt` 的 `readPrefKeys` 忽略清单里，因此随 `config.xml` 无条件备份。`textSelectMenuConfig` 不是自由文本，而是 `ReadBookController.kt:3351` 的 `SelectionMenuConfigItem(id, enabled, showState)` 数组的 JSON：`showState` 0 一级 / 1 折叠 / 2 隐藏（`:3316` 的 `ActionMenuItem.showState` 注释），`enabled` 是派生值 `showState == 0`；`id` 是 `R.id.menu_xxx` 映射出来的 `"menu_xxx"` 字符串（`:3321-3345`）。写盘在 `:2246` 的 `saveMenuConfig()`，读回在 `:2204-2232`——按配置串里的顺序取回已知条目（`allItems.find { it.uniqueId == saved.id }`），配置没提到的条目按内置顺序追加到末尾，`resolvedShowState = saved.showState ?: if (saved.enabled == false) 1 else 0` 兼容只有 `enabled` 的旧配置，整体包在 `runCatching {}.getOrDefault(allItems)` 里，坏 JSON 回落全量条目。渲染消费在 `ui/book/read/TextActionSelectionMenu.kt:122-124`（三组 filter）与 `:166`（`expandTextMenu` 为真走 `MultiLineMenuView`，为假走一行 + 「更多」弹层）；图标开关在 `:181`/`:227`/`:294` 三处传 `showIcons = showSelectMenuIcon`。配置面板是 `ui/book/read/sheet/TextSelectMenuConfigSheet.kt`：两个 `TinySwitchSettingItem`（`:155-172`）+ 一级 / 折叠 / 隐藏三个分组，行内两个按钮（移入折叠、移入隐藏），隐藏项点一下恢复。

**本地落地**：
1. 新建 `entry/src/main/ets/data/ReaderSelectionMenu.ets`：`ReaderSelectionMenuItem { id, title, group }` 条目模型、14 项内置序（出厂全部 `showState = 0`，与上游一致）、`READER_SELECTION_MENU_SUPPORTED = ['menu_copy','menu_bookmark','menu_mark']`、`parseReaderSelectionMenuConfig()`（严格照上游读回算法：配置顺序优先、未提到的追加、未知 id 跳过、空串与非数组回落全量）、`serializeReaderSelectionMenuConfig()`（写出 `{id, enabled, showState}`，`enabled` 恒等于 `group === 0`）。
2. `entry/src/main/ets/data/ReaderSettingsRepository.ets`：三字段落库，存储键与上游同名——接口 `:218`/`:220`/`:226`，默认值 `:573-575`（`false` / `true` / `''`），读 `:691-693`，归一 `:960-962`，写 `:1117-1119`。
3. `entry/src/main/ets/pages/ReaderSettingsPage.ets`：「选中文字菜单」面板接真（`:1824`）——两个开关绑真值与回调，三个分组的排序 / 分组 / 隐藏点「保存」后整体序列化落库（`syncTextMenuEntriesFromConfig()` `:1156`、`saveTextMenuConfig()` `:1164`，每次打开面板都按已落库配置重建条目表 `:1387-1389`）；入口行去掉「未迁移」，改 `migrated: true`（`:1141`）。
4. `entry/src/main/ets/pages/ReaderPage.ets`：划词菜单改为按配置渲染（`:2495` 的 `resolveSelectionMenuItems()` 跳过 `showState === 2` 与未受支持的 id，`expandTextMenu` 为真时一级 + 折叠一起平铺、为假时折叠项收进「更多」，`:2482` 的「更多」点一下就地把折叠项展开——上游是 Popup，本地没有 Popup 层，就地展开语义等价）；图标开关在 `:2473`；三处 `onMenuShow` 都先复位「更多」展开态。
5. `entry/src/main/ets/data/BackupRepository.ets`：三键随 `config.xml` 与 `readConfig.json` 双向导出/恢复（接口 `:240-245`、导出 `:611`/`:613`/`:615` 与 `:1069-1071`、恢复 `:1329-1334`，恢复优先 json 再 xml，缺键保留本机现值以免把已排好的顺序清空）。

**已知差异**：
1. 本地只有 `menu_copy`/`menu_bookmark`/`menu_mark` 三项有真实动作，其余 11 项是尚未迁移的能力（分享、浏览器、朗读、字典、替换、编辑、AI 净化/改写、全文搜索、插入背景音前/后）。因此**面板里可以编排 14 项，阅读页菜单只显示其中已实现的三项**——这是按「上游没有就不要这个效果」的取舍，不是配置丢失；配置串里这 11 项的 `showState` 会照存照备份，待能力接入后自然出现。
2. **阅读页菜单的渲染未能取证**：该模拟器上本地书正文文件已丢失（正文位置显示的是书目 JSON），没有可长按选中的正常正文；`uitest uiInput longClick`、`doubleClick`、`drag` 三种注入方式都只落在系统层、不触发选区，与 KI-D6 记录的是同一限制。

**验收**：面板上屏（14 项一级 / 折叠 / 隐藏三组齐备、两个开关可切）、落库格式（把「分享」移入折叠后保存 → `<string key="textSelectMenuConfig">[{&quot;id&quot;:&quot;menu_share_str&quot;,&quot;enabled&quot;:false,&quot;showState&quot;:1},…]</string>`，字段名与派生规则与上游 `SelectionMenuConfigItem` 逐字段一致）、两个布尔键默认值落库、测试期改动已复原。

**KI-D3 朗读时允许音量键翻页（不接，范围之外）** —— 覆盖 D-04（`volumeKeyPageOnPlay`，`ReadSettings.kt:30`）。朗读子系统未接入，随 TTS 一起做。

**KI-D4 横屏双页（已实现）** —— 覆盖 D-05（`doubleHorizontalPage`，`ReadSettings.kt:26`）。

**上游口径**
- 字段是四档**字符串**而不是布尔：`domain/model/settings/ReadSettings.kt:26` `val doubleHorizontalPage: String = "0"`；偏好键 `constant/PreferKey.kt:157` `const val doublePageHorizontal = "doubleHorizontalPage"`（键值与字段名相同），`data/repository/ReadSettingsRepository.kt:394`/`:651` 读写。
- 四档取值 `res/values/array_values.xml:64` `double_page_value` = `0`,`1`,`2`,`3`，标题 `res/values-zh-rCN/arrays.xml:42` `double_page_title` =「全局单页」「全局双页」「横屏双页」「平板/横屏双页」；设置项自身标题 `values-zh-rCN/strings.xml:1257` `double_page_horizontal` =「平板/横屏双页」。
- 判定集中在 `feature/reader/core/layout/ReaderColumnMode.kt`（全文 22 行）：`SINGLE -> false`、`DOUBLE -> true`（注释原文：显式双页对滚动模式也生效）、`LANDSCAPE -> widthPx > heightPx && !isScroll`、`LANDSCAPE_OR_TABLET -> (widthPx > heightPx || isTablet) && !isScroll`，`columnCount()` 返回 `if (double) 2 else 1`。
- 列几何 `feature/reader/core/layout/ReaderPaginator.kt`：`:86` `columnStridePx get() = viewportWidthPx / columnCount`、`:87` `contentWidthPx get() = (columnStridePx - paddingLeftPx - paddingRightPx).coerceAtLeast(0f)`（**每列各自带左右内边距**）、`:83` `require(columnCount in 1..2)`。换列在 `advanceColumn()`：`if (columnIndex + 1 < config.columnCount) { justifyColumnBottom(); columnIndex++; columnElementStart = elements.size; columnRows.clear(); y = config.paddingTopPx } else finishPage()` —— 一个 page 先填满第 0 列再填第 1 列，两列都满才出页。
- 接线：`feature/reader/legacy/LegacyReaderPaginationStyleFactory.kt:61`、`LegacyReaderChapterPaginator.kt:263`/`:331`、`model/ReadBook.kt:386`；`ui/book/read/ReadBookController.kt:1266` 把 `columnCount` 拼进布局缓存 key，**列数变化必须触发重排**。
- 面板：`ui/book/read/sheet/MoreConfigSheet.kt:271-278` 与 `ui/config/readConfig/ReadConfigScreen.kt:225-234` 都是下拉；Intent `ReadConfigIntent.DoubleHorizontalPageChanged`（`ReadConfigViewModel.kt:124`）。

**本地落地**
- 数据层：`entry/src/main/ets/data/ReaderSettingsRepository.ets:228` 字段、`:584` 默认 `'0'`、`:703` 读、`:974` 返回归一、`:1132` 写、`:1295` `normalizeColumnMode`（只认 `'1'/'2'/'3'`，其余一律 `'0'`）。存储键与上游同名 `doubleHorizontalPage`。
- 判定模块（新建）：`entry/src/main/ets/data/ReaderColumnMode.ets` —— 四档常量、`READER_COLUMN_MODE_TITLES`、`normalizeReaderColumnMode`、`readerColumnModeTitle`、`isReaderTablet`（短边 ≥ 600vp）、`readerColumnCount(mode, widthVp, heightVp, isScroll)`，逻辑逐条照上游 `columnCount()`。
- 分页：`entry/src/main/ets/pages/LocalReaderPaginator.ets` 的 `paginate()` 与 `countPagesIncrementally()` 都新增 `columnCount` 参数，`pageColumns` 记录每行所属列并落进 `LocalReaderPage.lineColumns`，高度超限时调 `advanceColumn()` 换列而不是直接出页。
- 渲染：`entry/src/main/ets/pages/ReaderPage.ets` 新增 `resolveReaderColumnCount()`、`getColumnStrideWidth()`、`lineColumnAt()`、`readerColumnIndexes()`、`readerColumnFirstLineIndex()`；`getBodyContentWidth()` 改为按列宽折算；正文由单个 `Column` 改为按列 `Row` + `ForEach(this.readerColumnIndexes())`，每列各自 `padding({left, right})`，外层容器的左右内边距在双列时置 0；下划线层、行偏移、行高统计、图片行 margin 全部按列分组；`getFullBookPaginationLayoutKey()` 拼进列数。
- 面板：`entry/src/main/ets/pages/ReaderSettingsPage.ets:1097` 的「横屏双页」由占位改为四档下拉，副标题 `readerColumnModeTitle(this.doubleHorizontalPage)`，`getDetailChoices` 返回 `READER_COLUMN_MODE_TITLES`，`applyDetailChoicePreview` 落库，`openDetailSheet` 按当前档位回显。
- 备份：`entry/src/main/ets/data/BackupRepository.ets` 的 `AndroidReadConfigBackupRecord` 加 `doubleHorizontalPage: string`，config.xml 与 readConfig.json 双向导出、恢复走 `readJsonString ?? readXmlString ?? current.xxx` 并校验四档。

**已知差异**
- 平板判定：本地按「视口短边 ≥ 600vp」近似 Android 的 `sw600dp`；上游用资源限定 `isTablet`，在折叠屏/分屏等非常规尺寸上可能判定不同。
- 底部两端对齐：`ReaderPage.ets` 的 `calculateReaderBottomJustifyGap()` 在列数 > 1 时直接返回 0。原因是本地按「整页行数」摊分末行空隙，双列下会把两列的高度算错；上游是 `justifyColumnBottom()` 逐列独立摊分。因此**双列模式下末行不做两端对齐**，这是有意为之的保守处理。
- 翻页动画仍是整页平移：上游双页模式下翻一页 = 跨两列，本地 `turnReaderPage()` 的步长语义没变（`localReaderPages` 的每一个元素本来就是「一页 = 最多两列」），所以跨列已经在排版阶段完成，动画层面无需再改。

**验收**
`BUILD SUCCESSFUL in 25 s 835 ms` 后装机实测三组对照：档位 `1`（全局双页）时正文分成两栏 `[56,342][584,2591]` 与 `[696,342][1224,2591]`；档位 `0`（全局单页）时正文整块铺满 `[112,342][1280,445]…`；档位 `2`（横屏双页）在竖屏下保持单栏。面板上屏、四档选项、落库 `<string key="doubleHorizontalPage">1</string>` 均已验。测试期改动已复原为 `0`。

**KI-D5 触摸灵敏度与进度条模式（已实现）** —— 覆盖 D-06 翻页触摸灵敏度（`pageTouchSlop`，`ReadSettings.kt:35`，默认 0）、D-07 进度条模式（`readSliderMode`，`:25`，默认 `"0"`）。

已按上游语义接上：
- **D-06**：存储键 `pageTouchSlop`，`ReaderSettingsRepository.ets:175` 字段 / `:423` 默认 0 / `:493` 读 / `:816` 写（夹 0–1000）；面板 `ReaderSettingsPage.ets:854-861` 的 `MenuSettingSlider`（0–1000 步长 10）；消费点 `ReaderPage.ets:2947-2948`，`pageTouchSlop > 0` 时用它，否则回落原来的 36vp 平台默认值——与上游 `ReaderGestureSettingsPolicy.touchSlopPx(platformTouchSlopPx, configuredTouchSlopPx)` 同口径。上游刻意让选择拖选阈值（`selectionDragSlopPx`）不受此配置影响，本地保持解耦。
- **D-07**：上游 `readSliderMode` 的语义是**显示 / 不显示**（`ReadBookMenuBarBottom.kt:161` `AnimatedVisibility(visible = readSliderMode != "1")`），不是形态切换。存储键 `readSliderMode`，`ReaderSettingsRepository.ets:174` / `:422` / `:492` / `:815`；面板「底栏布局」tab 首项 `ReaderSettingsPage.ets:424-430`（详情面板选项「常驻」/「不显示」）；消费点 `ReaderPage.ets:3109` 把整行「上一章 / 滑块 / 下一章」包进 `if (this.readSliderMode !== '1')`。
- 顺带纠正历史错位：该面板位置原先挂的是本地 `progressBehavior`（页码/章节），与上游 `readSliderMode` 不是一回事，现在两者分别由「滑动条显示样式」和「进度条行为」承担。
- 备份：两个键都不在 `BackupConfig.readPrefKeys` 忽略清单里，属「无条件随 config.xml 备份」，本地已在 `BackupRepository.ets:561-566`（导出）与 `:1176-1185`（恢复）对齐。

**KI-D6 上次标记样式（已实现）** —— 覆盖 D-10（`lastMarkingStyle`，`ReadSettings.kt:54`）。

上游口径：`ReadBookViewModel.kt:1519` 在 `ApplyQuickMarking` 分支里 `it.copy(lastMarkingStyle = GSON.toJson(intent.style))`，把 `TextProcessStyle` 的 JSON 存进该键；消费点 `MarkingSelectionMenu.kt:166-167` 取 `state.editing?.styleJson ?: lastMarkingStyle`——**编辑已有标记优先用标记自身样式，新建才沿用上次**；两者都没有才回落 `MarkingEffect.BG` + `DEFAULT_COLOR`（`0xFF63C37D`）。`PreferKey.kt:156` 是键常量，`ReadSettingsRepository.kt:421`/`:543`/`:677` 是读/键/写。

本地落地（2026-10-31）：
- 字段与持久化：`ReaderSettingsRepository.ets:181` `lastMarkingStyle: string;`，默认 `''`（`:430`），读 `:501`，写 `:826`。
- 写点：`Index.ets` 的 `saveReaderMarking()` 在 `ReaderMarkingRepository.save()` 成功之后调 `setReaderLastMarkingStyle(ReaderMarkingRepository.encodeStyle(effect, color))`；编码复用 `ReaderMarkingRepository.encodeStyle`/`decodeStyle`（`:137`/`:144`），与标记自身的 styleJson 是同一份转换，没有第二份口径。
- 消费点：`ReaderMarkingEditor.ets:222` 的 `@Prop lastMarkingStyle`，`aboutToAppear()` 里 `applyLastMarkingStyle()`（`:255-264`）——只在 `isNew` 且非空时应用，与上游 `state.editing?.styleJson ?: lastMarkingStyle` 同序。
- 备份：`BackupConfig.kt` 的 `readPrefKeys` 忽略清单**不含**该键，属「随 `config.xml` 无条件导出」，因此补了导出 `BackupRepository.ets:568` 与恢复 `:1188-1189`。
- **顺带纠正的历史错位**：`ReaderMarkingEditor` 的 `useRule` 原默认 `true`，而上游 `MarkingSelectionMenu.kt:181` 是 `mutableStateOf(false)`；已改为 `false`，并删掉 `aboutToAppear()` 里的 `this.useRule = this.isNew;`。现在只有 `loadHighlightRules()` 之后 `selectRuleMatchingCurrentStyle()` 按 `effect`+`color` 匹配到已有规则时才置 `true`，与上游 `LaunchedEffect(storedStyle, state.highlightRules)` 同义。
- 验收限制：模拟器上阅读页正文的单击/长按手势不通（见本文件「模拟器限制」与 VALIDATION 的 KI-D5 节），因此**无法从正文划词路径在设备上验「新建时预选上次样式」**；只做了代码层核对与「编辑路径不覆盖标记自身样式」的核对。详见 `docs/VALIDATION.md` 的 2026-10-31 KI-D6 节。

### E 菜单与主题外观

**整块共同的前置条件**：本地阅读页没有菜单外观渲染层。全仓 `readMenu*`/`titleBar*` 只命中 `data/BackupRepository.ets`，`ReaderPage.ets` 零命中；设置页 36 个真实条目里 34 个只有页面 `@State`，退出即丢。要接这些字段，等于先用 ArkUI 重写一套阅读页菜单（顶栏 / 底栏 / 悬浮图标 / 模糊 / 液态玻璃），属一整轮的工作量。

**另有一层备份侧证据**：这些 `readMenu*` 外观键在 `config.xml` 的两个方向都不走——导出只写 24 个键（`BackupRepository.ets:515-557`），恢复只读约 40 个键（`:1118-1255`，含 `readMenuIconShowText`/`readMenuIconStyle`/`readMenuIconItemsPerRow`/`readMenuIconRowCount` 四个已接的），且这批键只出现在 `preferenceKeysByCategory.readConfig`（`:234-256`）的忽略清单里。**因此即使现在把字段接上，也读不到 Android 备份里的值**；真正的补齐顺序是先建渲染层，再把键加进导出/恢复两组。

**KI-E1 菜单配色与亮度九项（已实现）** —— 覆盖 E-01 工具栏样式（`ReadBookConfig.kt:99`）、E-02 调色板风格（`:113`）、E-03 菜单颜色来源（`:99`）、E-04 种子色（`:62`）、E-05 菜单背景颜色（`:117`）、E-06 菜单容器颜色（`:123`）、E-07 菜单强调颜色（`:120`）、E-08 显示亮度视图（`:94`）、E-09 亮度条位置（`:95`）。其中 E-08/E-09 已由 KI-A9 接上，本组实际交付的是 E-01..E-07 七行。

**上游口径**（`ui/book/read/sheet/SystemMenuPage.kt:255-372` 的「菜单栏」tab 配色段）：
- `:262-275` `TinyDropdownSettingItem(tool_bar_style)`，`selectedValue = bottomMode.toString()`，`displayEntries = [flow_sys, follow_read_background, custom]`、`entryValues = ["0","1","2"]` → `ConfigUpdate.ReadBarStyle(it.toInt())`。默认 `readBarStyle = 1`（`domain/model/settings/ReadSettings.kt:69`，跟随阅读背景）。
- `:276` `val showPaletteStyle = bottomMode == 1 || (bottomMode == 2 && colorMode == 0)` —— **调色板风格只在「跟随阅读背景」或「自定义 + 种子色」时出现**。
- `:277-291` `AnimatedVisibility(visible = showPaletteStyle) { TinyDropdownSettingItem(palette_style, ...) }`，`displayEntries = arrayOf(stringResource(R.string.flow_sys)) + stringArrayResource(R.array.paletteStyle)`、`entryValues = arrayOf("") + stringArrayResource(R.array.paletteStyle_value)` —— **「跟随系统」是拼在最前面的空串项**。默认 `readMenuPaletteStyle = ""`（`ReadSettings.kt:109`）；九项取值见 `res/values/array_values.xml:101-111`（`tonalSpot / neutral / vibrant / expressive / rainbow / fruitSalad / monochrome / fidelity / content`），中文名见 `res/values-zh-rCN/arrays.xml:184-194`（「柔和 / 中性 / 鲜艳 / 表现力 / 彩虹 / 水果拼盘 / 单色 / 仿真 / 内容取色」）。
- `:293-307` `AnimatedVisibility(visible = bottomMode == 2) { TinyDropdownSettingItem(read_menu_color_source, ...) }`，`displayEntries = [seed_color, custom_theme_colors]`、`entryValues = ["0","1"]` → `ConfigUpdate.MenuColorMode(it.toInt())`。默认 `readMenuColorMode = 1`（`ReadSettings.kt:88`），夹 0–1（`ReadBookConfig.kt:99`）。中文串 `values-zh-rCN/strings.xml:2462 read_menu_color_source`「色板来源」、`:2465 read_menu_accent_color_summary`「阅读顶栏和底栏文字与图标颜色」、`:42 custom_theme_colors`「自定义颜色」、`:271 flow_sys`「跟随系统」、`:2053 tool_bar_style`「工具栏样式」、`:2016 palette_style`「调色板样式」。
- `:309-320` `AnimatedVisibility(visible = colorMode == 0) { TinyColorModeSettingItem(seed_color, dayColor = dayMenuAccentColor, nightColor = nightMenuAccentColor, ...) }`。
- `:339-368` `AnimatedVisibility(visible = colorMode == 1) { Column { 背景色 / 容器背景色 / 强调色 三个 TinyColorModeSettingItem } }`，分别传 `dayMenuBgColor`/`nightMenuBgColor`、`dayMenuContainerColor`/`nightMenuContainerColor`、`dayMenuAccentColor`/`nightMenuAccentColor`。
- **两处共用字段**：「种子色」(`:309`) 与「菜单强调颜色」(`:349`) **都绑 `readMenuAccentColor` / `readMenuAccentColorNight`**，上游只有一个字段两个入口。
- 字段与默认值（`ReadSettings.kt`）：`readMenuBgColor = 0`（`:80`）、`readMenuAccentColor = 0`（`:81`）、`readMenuContainerColor = 0`（`:82`）、`readMenuBgColorNight = 0`（`:83`）、`readMenuAccentColorNight = 0`（`:84`）、`readMenuContainerColorNight = 0`（`:85`），**0 表示未设置**；`ReadBookConfig.kt:117-132` 都是 `takeIf { it != 0 } ?: durConfig.menuXxx(isNight)`，且 `ContainerColor` 为 0 时回落 `readMenuBgColor`。
- 解析器：`ReadBookConfig.kt:154-178 resolvedMenuBgColor`（`readBarStyle == 1` 取当前阅读背景/背景图均值色、`== 2` 夜取 Night 日取普通、`else` 夜黑日白）、`:180-194` 的 `resolvedMenuAccentColor`/`resolvedMenuContainerColor` 按 `isNightTheme()` 取日夜一侧、`:64 val menuColor get() = readMenuAccentColor`。
- 色板生成：`ui/book/read/ReadBookColorTheme.kt:52-63`（`readBarStyle` 1 → `rememberReadBackgroundTheme`、2 → `rememberCustomReadMenuTheme`、`else -> null` 退回系统）、`:144-162`（`readMenuColorMode == 0` 只把 accentColor 当 seed 生成整套，否则 `rememberCustomReadMenuThemeOverride`）、`:286-298 ColorScheme.withCustomReadMenuColors(accentColor, menuBackgroundColor, menuContainerColor)`（`primary = accentColor`、`surfaceTint = accentColor`、`surfaceContainerHigh = menuBackgroundColor`、`surfaceContainerLow = menuContainerColor`、`onPrimary = accentColor.contrastContentColor()`）。
- 备份口径：九个键全在 `help/storage/BackupConfig.kt` 的 `readPrefKeys` 忽略清单里（`readBarStyle` `:216`、`readBarStyleFollowPage` `:217`、`readMenuBgColor` `:219`、`readMenuAccentColor` `:220`、`readMenuContainerColor` `:221`、`readMenuBgColorNight` `:222`、`readMenuAccentColorNight` `:223`、`readMenuContainerColorNight` `:224`、`readMenuColorMode` `:227`、`readMenuPaletteStyle` `:247`）⇒ **本组不导出、不参与恢复**。

**本地落地**（逐文件行号）：
- 数据层 `data/ReaderSettingsRepository.ets`：接口 `:369-394`（九字段各带上游行号注释）、默认值 `:775-783`（`1 / '' / 1 / '' x6`）、`load()` `:928-938`、返回归一 `:1252-1264`（`readBarStyle` 夹 0–2、`readMenuColorMode` 夹 0–1、六个颜色走 `normalizeOptionalHexColor`、`readMenuPaletteStyle` 走新增的 `normalizePaletteStyle :1610`，只认九值或空串）、`save()` `:1453-1466`。**颜色用 `string` 存 `#RRGGBB`/`#AARRGGBB`，空串承载上游的「0 = 未设置」**；文件头新增 `PALETTE_STYLE_VALUES :115`（取值表在 `:1614` 消费）。
- 状态与接线 `pages/Index.ets`：九个 `@State reader*` + 装载 + 备份恢复 + 九个 setter（`readBarStyle` 夹 0–2、`readMenuColorMode` 夹 0–1）；**prop 共 6 处**（快照 1、ReaderPage 1、设置面板 4）、**回调共 4 处**（只在设置面板；ReaderPage 不接回调，纯展示型）。
- 设置面板 `pages/ReaderSettingsPage.ets`：`MENU_PALETTE_VALUES :30`（十项，索引 0 空串）、`MENU_COLOR_PALETTE :33`（弹层十色）；九 `@Prop :247-` + 九回调；**删掉三个假 `@State`**（原 `menuBarStyleMode`/`menuColorMode`/`menuPaletteStyleIndex`）；Segments `onSelect :886-888` 三项改真回调；`getMenuChoices :1010-1013`、`getMenuSelectedIndex :1027-1030`、`applyDetailChoicePreview :1043`（三支在 `:1061`/`:1064`/`:1067`）、`isMenuSettingsEntryVisible :1137` 四条规则（`:1152`/`:1155`/`:1157`/`:1158`）读 prop、`getDetailChoices :1747-1750` 两处文案改「跟随系统」「自定义颜色」；四个颜色项 `MenuSettingColor` 分支带 `dayColor`/`nightColor` 真值；**新增配色弹层分支 `:1877-1905`**（日/夜两块 `MenuSettingPalette` + 共用字段说明）；`applyMenuColor :978`（再点同色 = 清除）、`menuColorDay :997`、`menuColorNight :1004`；条目表七行 `:2518-2524`。
- 渲染 `pages/ReaderPage.ets`：九 `@Prop :268-286`；八个折算方法 —— `readerMenuIsNight :969`（用 `paperColor` 的 sRGB 相对亮度对 0.5 判定）、`readerMenuBaseColor :989`（照 `ReadBookConfig.kt:154-178` 三档）、`readerMenuContainerBaseColor :1003`、`readerMenuAccentTint :1013`、`readerMenuForeground :1023`（夜 `#D5C2C6` / 日 `#3E3D3B`）、`readerMenuRgb :1028`、`readerMenuTintAlphaString :1041`（`Math.min(0.6, max(0, min(100, readMenuBlurAlpha))/100)`，上限 0.6）、`readerMenuForegroundAlpha :1049`；`readerBottomBarFillColor :880` / `readerTopBarFillColor :918` 改走容器色 + 不透明度；顶/底栏底色、渐变、图标与文字色、选中态从写死的 `#31282A`/`#D5C2C6`/`#FFB1C8` 全部替换；`ReaderControl`/`ReaderBottomAction`/`ReaderControlGlyph` 三个组件各加 `menuForeground`/`menuAccent` 两个 `@Prop` 并透传。
- 备份 `data/BackupRepository.ets`：恢复返回对象补九行，**一律 `current.<field>`**（注释写明上游把这批键列入忽略清单，恢复保留本机现值）；config.xml 导出段不动。

**已知差异**：
1. **「跟随系统」与九种调色板风格只落库、不生成 Material 派生色板**：ArkUI 没有 `dynamicColorScheme` 等价物，本地按背景明暗反色折算前景色，不跑 HCT 色板算法。上游 `ReadBookColorTheme.kt:52-63` 的三种来源里，本地只实到「按字段取色」这一层。
2. **真实高斯模糊仍未做**：菜单底色的不透明度用 `readMenuBlurAlpha` 折算（与 KI-E4/KI-E5 同口径），没有真的模糊背景。
3. **`ReaderPage` 的自动翻页面板底色仍写死 `#D931282A`**（`ReaderPage.ets:4385`），不属「顶栏/底栏/菜单」三处，本组未纳入。
4. **配色视觉的像素级对比未取证**：模拟器书架无正文可读、进不了阅读页，取不到菜单帧，只有面板值与 prefs 证据。

**验收**：`assembleHap` BUILD SUCCESSFUL；设备（`127.0.0.1:5555`）实测三档可见性互斥（跟随阅读背景 / 自定义+自定义颜色 / 自定义+种子色，各有 `dumpLayout` 对照）；四个颜色项弹层可选色、再点同色可清除；「种子色」选 `#3D3D46` 后打开「菜单强调颜色」显示同一色号（共用字段的直接证据）；「调色板风格」十项下拉选「鲜艳」后副标题变「鲜艳」；`aa force-stop` 重启后八项全部跨进程保持。完整记录见 [VALIDATION](VALIDATION.md)。


**KI-E2 边框与模糊七项（已实现）** —— 覆盖 E-10 菜单栏边框（`ReadBookConfig.kt:88`）、E-11 边框宽度（`:115`，夹 0–4）、E-12 边框颜色（`:88-89`）、E-13 模糊半径（`:109`，夹 0–32）、E-14 模糊透明度（`:110`，夹 0–100）、E-15 菜单文字颜色（`:90-91`）、E-16 菜单模糊颜色（`:111-112`）。

**上游口径**（`app/src/main/java/io/legado/app/ui/book/read/sheet/SystemMenuPage.kt` 的边框与「模糊和颜色」段 `:398-489`）：

- **边框没有独立布尔字段**：`val borderEnabled = preferences.readMenuBorderWidth > 0`（`:398`），`TinySwitchSettingItem(R.string.read_menu_border)` 的 `checked = borderEnabled`、写回 `ConfigUpdate.BorderWidth(if (it) 1 else 0)`（`:399-406`）；宽度与颜色两项被 `AnimatedVisibility(visible = borderEnabled)` 包住（`:408`）。
- 边框宽度 `TinySliderSettingItem(read_menu_border_width)`：`value = preferences.readMenuBorderWidth.coerceIn(1, 4)`、`valueRange = 1f..4f` → `ConfigUpdate.BorderWidth(it.toInt())`（`:411-425`）。
- 边框颜色 `TinyClearColorModeSettingItem(read_menu_border_color)`：日/夜双色，`onClearColor` 写 `BorderColor(0)`/`BorderColorNight(0)`，`onClickColor` 弹 `COLOR_BORDER`/`COLOR_BORDER_NIGHT`（`:426-437`）。
- 模糊半径 `TinySliderSettingItem(read_menu_blur_radius)`：`valueRange = 0f..32f`、`steps = 31` → `ConfigUpdate.MenuBlurRadius(it.toInt())`，`description = read_menu_blur_radius_summary`（「模糊半径越大，系统运行越卡顿」）（`:438-447`）。
- 模糊透明度 `TinySliderSettingItem(read_menu_blur_alpha)`：`valueRange = 0f..100f`、`steps = 99` → `ConfigUpdate.MenuBlurAlpha(it.toInt())`（`:448-456`）。**该字段在「菜单栏」与「底栏布局」两个 tab 各出现一次，共用一个键**。
- 菜单文字颜色 `TinyClearColorModeSettingItem(read_menu_text_color)`：支持清除（`:457-475`）。
- 菜单模糊颜色 `TinyColorModeSettingItem(read_menu_blur_color)`：**没有 `onClearColor`，上游这一项不能清除**（`:476-489`）。
- 夹取与默认：`ReadBookConfig.kt:109`（半径 0–32）、`:110`（透明度 0–100）、`:115`（宽度 0–4）；`ReadSettings.kt:105-113`（半径 24、透明度 85、宽度 1、四个颜色 0）。
- **渲染口径**：`ReadBookMenuBarShared.kt:49-85` 的 `surfaceColor = readMenuTintColor(menuConfig) ?: colors.background` —— **模糊着色优先于整套底色推导**；`readMenuTintColor`（`:76-92`）夜/日取 `readMenuBlurColorNight`/`readMenuBlurColor`，都为 0 时返回 null；`readMenuBorderColor`（`:96-105`）为空时回落 `outlineVariant`；`readMenuTextColor`（`:107-115`）为空时回落 `onSurface`。边框走 `ReadBookMenuBarTitle.kt:433`/`:504-505`、`ReadBookMenuBar.kt:450`；模糊半径走 `ReadBookMenuBarTitle.kt:131`、`ReadBookMenuBar.kt:1027`。
- **备份口径**：`help/storage/BackupConfig.kt:225-251` 把这批键全部列进 `readPrefKeys` 忽略清单，不随 config.xml 导出，恢复一律取本机现值。

**本地落地**：

- `entry/src/main/ets/data/ReaderSettingsRepository.ets`：接口 `:396-410`（八字段）、默认值 `:801-808`、`load()` `:964-974`、返回归一 `:1301-1303`、`save()` `:1512-1513`。宽度默认 1 夹 0–4、半径默认 24 夹 0–32、四个颜色用空串承载「未设置」。
- `entry/src/main/ets/data/BackupRepository.ets`：恢复段 `:1472-1479` 八行全取 `current.xxx`（不读 json/xml）。
- `entry/src/main/ets/pages/Index.ets`：八 `@State`（`readerMenuBorderWidth` 等）、装载、恢复、八个 setter、快照 prop、面板 prop 4 处、回调 4 处。
- `entry/src/main/ets/pages/ReaderSettingsPage.ets`：条目行 `:2590`（菜单栏边框）/`:2591`（宽度）/`:2592`（边框颜色）/`:2594`（模糊半径）/`:2595`（模糊透明度）/`:2596`（文字颜色）/`:2597`（模糊颜色）；Toggle 读写 `readMenuBorderWidth > 0`；两个滑块接 `onReadMenuBorderWidthChange`/`onReadMenuBlurRadiusChange`；三个颜色项走双色点 + 配色弹层（`applyMenuColor` 再点同色即清除）；`菜单栏边框宽度`/`菜单栏边框颜色` 的可见性读 `readMenuBorderWidth > 0`（原先读的是假 `@State menuBorderEnabled`，本轮删掉）；**「菜单模糊透明度」滑块原先完全没接线**（`menuSettingsEntry()` 的 onChange 与 `menuSliderValue` 都没有这一项），补两行分支后与底栏共用 `readMenuBlurAlpha`。
- `entry/src/main/ets/pages/ReaderPage.ets`：`@Prop` 八项；新增 `readerMenuTintColor()` `:1043`、`readerMenuBorderSettings(): BorderOptions` `:1067`（宽度 0 返回 `{ width: 0 }`）、`readerMenuBlurRadiusVp()` `:1080`；`readerMenuBaseColor()` 开头插「模糊着色优先」分支 `:1008`；`readerMenuForeground()` 改为优先 `readMenuTextColor(Night)`、空串才回落日夜反色；顶栏容器加 `.border(...)`/`.backdropBlur(...)` `:4272-4273`、底栏 `:4379-4380`。

**已知差异**：

1. 本地用 ArkUI 的静态 `backdropBlur(radius)`，没有上游 `hazeState` 的内容自适应模糊；实际效果是「半径固定 + 底色按 `readMenuBlurAlpha` 折算不透明度（上限 0.6）」，不是真高斯采样。
2. `readMenuLensRadius`（`ReadBookConfig.kt:114`，夹 0–48）不在本轮七行内；**2026-10-31 KI-E6 已补上落库（只落库不上屏，上游同样没有设置入口）**，见 KI-E6 段。
3. 边框描边、模糊半径、模糊着色、文字色的**视觉变化未做像素级取证**：模拟器书架上书的正文文件已丢失、`ReaderPage` 进不去，只有面板值与 prefs 落库证据。
4. 上游「模糊色没有清除入口」这一约束本地照搬（`applyMenuColor` 对模糊色也支持再点同色清除，属**放宽**，不影响已有行为）。

**验收**：`assembleHap` BUILD SUCCESSFUL（改动后两次，36 s 917 ms / 33 s 848 ms；补「菜单模糊透明度」接线后再一次 23 s 250 ms）。设备实测：边框开关关掉后「菜单栏边框宽度」「菜单栏边框颜色」两行整行消失、下方各项上移约 98 px，重新打开后恢复；边框宽度拖到 `4.000000`、模糊半径拖到 `32.000000`、模糊透明度拖到 `39.000000`，`aa force-stop` 重启后全部保持；三个颜色项弹层选色、跨进程保持、再点同色清除全部通过；复原到「边框开 / 宽度 1 / 半径 24 / 透明度 85 / 三色清空」。详见 [VALIDATION](VALIDATION.md) 的 `2026-10-31 N 端 KI-E2` 节。

**KI-E3 标题栏图标四项（已实现）** —— 覆盖 E-17 显示标题栏图标（`ReadBookConfig.kt:92`）、E-18 标题栏悬浮图标配置（`:146`、`:149` 两个 `Map<String,String>`）、E-19 标题栏悬浮图标位置（`:116`，夹 0–3）、E-20 悬浮图标液态玻璃按钮（`:87`）。

**上游口径**（`ui/book/read/sheet/SystemMenuPage.kt` 的 `GlobalMenuTab` 末尾「Floating icon settings」段，`:491-544`）：
- `:491-497` `SectionTitle(show_title_bar_icons)` + `TinySwitchSettingItem(show_title_bar_icons)`，`checked = preferences.showTitleBarIcons` → `ConfigUpdate.ShowTitleBarIcons(it)`。
- `:498` 起 `AnimatedVisibility(visible = preferences.showTitleBarIcons) { Column { … } }` 包住后面三项 —— **关掉总开关时三项整行消失**。
- `:501-508` `TinyClickableSettingItem(title_bar_icons)`（中文串「浮动图标」，`strings.xml:2478`）→ `ShowSheet(ReadBookSheet.FloatingBarIconConfig)`；`description` 按 `customIconCount == 0` 取 `read_menu_custom_icons_none`「使用默认图标」/ `read_menu_custom_icons_count`「已自定义 %1$d 个图标」（`strings.xml:2476`/`:2477`），`customIconCount = remember(preferences.titleBarCustomIcons) { countCustomIcons(...) }`（`:232-234`）。
- `:509-520` `TinyDropdownSettingItem(title_bar_icon_position)`，`selectedValue = preferences.titleBarIconPosition.toString()`，`entryValues = ["0","1","2","3"]` → `ConfigUpdate.TitleBarIconPosition(it.toInt())`；中文串「左上 / 右上 / 左下 / 右下」（`strings.xml:2486-2489`）。
- `:521-527` `TinySwitchSettingItem(read_menu_bar_liquid_glass_buttons)` → `ConfigUpdate.MenuFloatingIconLiquidGlass(it)` —— **与底栏 E-27 同名串但是不同字段**。
- 字段与默认值（`ReadSettings.kt`）：`:102 readMenuFloatingIconLiquidGlass = false`、`:114 readMenuCustomIcons = ""`、`:115 titleBarCustomIcons = ""`、`:116 titleBarIconPosition = 3`、`:117 showTitleBarIcons = false`；夹取 `ReadBookConfig.kt:116`（位置 0–3）；两个自定义图标在 `ReadBookConfig.kt:146-150` 由 `parseReadMenuCustomIcons` 解析成 `Map<String,String>`。
- 渲染：`ReadBookMenuBar.kt:172` 位置 0/1 挂顶栏区（`Alignment.Start`/`End`）、`:310-330` 位置 2/3 挂菜单浮层区；`ReadBookMenuBarFloating.kt:63-150 FloatingIconRow` 每图标 36dp 圆形、自定义走 `AsyncImage(model = customPath, contentScale = Crop, clip CircleShape)`、否则 `AppIcon(tint = if (isActive) primary else colors.content)`，`glassEnabled = !isCustom && readMenuFloatingIconLiquidGlass && readerMenuLiquidGlassAvailable(backdrop)`。
- **图标池与「标题栏操作按钮」同池**：`ReadBookMenuBarFloating.kt:399-425 loadFloatingIcons()` 读 `state.menuConfig.titleBarButtons`，池子由 `ReadButtonConfigDelegate.kt:36` 的 `TITLE_BAR_ICON_PREFS`/`TITLE_BAR_ICON_KEY` 与 `:204-205` 加载；`DEFAULT_ENABLED_BUTTON_IDS` = search / auto_page / catalog / read_aloud / setting。配置面板 `FloatingBarIconConfigSheet.kt:25-46` 复用通用 `ButtonIconConfigSheet`（排序 + 开关 + 自定义图标，`onSelectIcon = OpenTitleBarCustomIconPicker`、`onClearIcon = ConfigUpdate.TitleBarCustomIcon(id, "")`）。
- **备份口径**：`BackupConfig.kt` 的 `readPrefKeys` 忽略清单里含 `readMenuIconShowText`(`:228`)、`readMenuFloatingIconLiquidGlass`(`:240`)、`readMenuCustomIcons`(`:252`)、`titleBarCustomIcons`(`:255`)、`titleBarIconPosition`(`:256`)、`showTitleBarIcons`(`:257`) ⇒ 本组**全部不导出**，恢复一律取本机现值。

**本地落地**（六字段 + 图标池）：
- 数据层 `entry/src/main/ets/data/ReaderSettingsRepository.ets`：接口 `:412`（`showTitleBarIcons`）/`:417`（`titleBarIconPosition`）/`:419`（`readMenuFloatingIconLiquidGlass`）/`:424`（`floatingIcons: ReaderBottomActionConfig[]`）/`:426`（`titleBarCustomIcons`）/`:428`（`readMenuCustomIcons`）；默认值 `:828-836`（位置 3、图标池取 `READER_LOCAL_BOTTOM_ACTION_DEFAULTS`，对齐上游 `DEFAULT_ENABLED_BUTTON_IDS`）；读取 `:1002-1009`；归一 `:1344-1353`（位置夹 0–3、图标池走 `normalizeActions`、两个自定义图标走 `normalizeCustomIconMap`）；写回 `:1573-1581`；新增 `:1778 normalizeCustomIconMap`（`id,path;` 编码，只保留合法 id 与非空路径、去重）与 `:1797 decodeCustomIconMap`。
- `entry/src/main/ets/pages/Index.ets`：六个 `@State` + 装载 + 备份恢复 + 六个 setter + 快照，prop 6 处、回调 4 处（与 E4/E5 同构）。
- 面板 `entry/src/main/ets/pages/ReaderSettingsPage.ets`：「显示标题栏图标」Toggle `:2639` 接 `showTitleBarIcons`（checked `:866`、onChange `:894`）；「悬浮图标液态玻璃按钮」Toggle `:2642`（名单 `:998`、checked `:866-868`、onChange `:895`）；三项可见性统一读 `showTitleBarIcons`（`:1247`）；「标题栏悬浮图标位置」四值下拉 `:2641`（`getMenuChoices :1106` 与 `getDetailChoices :1849` 两处、选中态 `:1123`、段落 `onSelect :947` 与弹层 `applyDetailChoicePreview :1173` 两处都落库）；「标题栏悬浮图标配置」`:2640` 点击把 `floatingIcons` 拷进 `draftTopActions` 并置 `floatingIconConfigVisible`（`:978-985`），复用 `topActionConfigurationSheet()`（`:2852` 标题切换、`:2861-2864` 保存分流、`:2837-2840 closeButtonConfigSheet()`）。
- 渲染 `entry/src/main/ets/pages/ReaderPage.ets`：`readerFloatingIconKinds()` `:1961`、`readerFloatingIconAlignment()` `:1974`、`readerFloatingIconTopVisible()` `:1979`、`readerFloatingIconBottomVisible()` `:1984`、`readerFloatingIconCustomUri()` `:1989`、`readerFloatingIconButton()` `:2002`、`readerFloatingIconRow()` `:2028`；挂载 `:4371`（顶栏区）/`:4388`（菜单浮层区）。
- 备份 `entry/src/main/ets/data/BackupRepository.ets:1486-1491`：恢复段六行全取 `current.xxx`，config.xml 导出段不动。

**已知差异**：
1. **没有实现「换自定义图标图片」的选图入口**（上游 `OpenTitleBarCustomIconPicker`）。两个自定义图标串已落库、渲染侧 `decodeCustomIconMap` 已能解码并显示圆形图，但面板里选不了图。
2. ArkUI 无液态玻璃材质，`readMenuFloatingIconLiquidGlass` 用「半透明前景色底」近似（`readerMenuForegroundAlpha('1F')`）。
3. 浮动图标行的实际渲染（位置 0/1 在顶栏下、2/3 在菜单浮层上、自定义圆形图、玻璃底）**未做像素级取证** —— 模拟器书架正文文件丢失、`ReaderPage` 进不去。

**验收**：`assembleHap` BUILD SUCCESSFUL（改动后三次：44 s 860 ms / 27 s 44 ms / 27 s 223 ms）。设备实测：关掉「显示标题栏图标」后三项整行消失（dump 三项计数全为 0）、重新打开后恢复；位置下拉四项齐全，选「左上」后 `aa force-stop` 重启仍是「左上」（prefs `titleBarIconPosition` = `0.000000`）；液态玻璃开关打开后 prefs 为 `true`、重启保持；浮动图标配置面板标题为「浮动图标」、列表是顶栏按钮池，关掉「自动翻页」保存后 prefs `floatingIcons` 里 `autoPage` 由 `true` 变 `false`、重启保持；复原到「显示关 / 位置右下(3) / 液态玻璃关 / 图标池默认」。详见 [VALIDATION](VALIDATION.md) 的 `2026-10-31 N 端 KI-E3` 节。

**KI-E4 底栏外观七项（已实现）** —— 覆盖 E-21 底栏圆角（`ReadBookConfig.kt:104`，夹 0–32）、E-22 底栏悬浮（`:82`）、E-23 底栏模糊（`:106`，夹 0–2）、E-24 底栏模糊透明度（`:110`）、E-25 底栏模糊样式（`:108`，夹 0–1）、E-26 底栏液态玻璃（`:86`）、E-27 底栏按钮液态玻璃（`:101` 的 `readMenuBottomBarLiquidGlassButtons`）。本地底栏已能渲染（`ReaderPage.ets:3156-3171` 读 `showBottomActionText`/`bottomIconStyle`/`bottomRowCount`），缺的正是这层外观参数，属渲染层改造里最先能做的一块。

**上游口径**（`ui/book/read/sheet/SystemMenuPage.kt` 的 `BottomBarTab`，`:553-740`；**注意 E 块设置项不在 `MoreConfigSheet.kt`**，该文件 `grep readMenu*` 为零命中）：
- `:645-655` `TinySliderSettingItem(read_menu_bottom_corner_radius)`，`valueRange = 0f..32f`、`steps = 31` → `ConfigUpdate.MenuBottomCornerRadius`。
- `:660` 附近 `TinySwitchSettingItem(read_menu_floating_bottom_bar)` → `ConfigUpdate.FloatingBottomBar`。
- `:668` 附近 `TinySwitchSettingItem(read_menu_bar_blur)`，`checked = bottomBarBlurMode != ReadMenuBlurMode.None`，回写 `if (it) Haze else None` —— **只写 2 与 0，不写 1**。
- `AnimatedVisibility(visible = !floatingBottomBar) { TinyDropdownSettingItem(read_menu_bar_blur_style) }`，选项「纯色 / 渐变」对应 `entryValues = ["0","1"]`。
- `AnimatedVisibility(visible = floatingBottomBar) { TinySwitchSettingItem(read_menu_bar_liquid_glass) }`，`checked = readMenuBottomBarBlurMode == ReadMenuBlurMode.LiquidGlass`，回写 `if (it) LiquidGlass else if (bottomBarBlurMode != None) Haze else None`。
- `TinySwitchSettingItem(read_menu_bar_liquid_glass_buttons)` → `ConfigUpdate.MenuBottomBarLiquidGlassButtons`，说明文案 `read_menu_bottom_bar_liquid_glass_buttons_summary`（`values-zh-rCN/strings.xml:2496`「需要 Android 13 及以上系统」）。
- `bottomBarBlurMode` 推导在 `:560-568`：`if (!floatingBottomBar && preferences.readMenuBottomBarBlurMode == ReadMenuBlurMode.LiquidGlass) ReadMenuBlurMode.Haze else preferences.readMenuBottomBarBlurMode` —— **非悬浮时液态玻璃降级为雾化**。
- 枚举定义 `constant/PreferKey.kt:498`（`ReadMenuBlurMode.None = 0 / LiquidGlass = 1 / Haze = 2`）与 `:504`（`ReadMenuBlurStyle.Solid = 0 / Progressive = 1`）。
- 「底栏模糊透明度」的真实入口不在 `BottomBarTab`，在同文件的模糊/边框段 `:448-456`：`TinySliderSettingItem(read_menu_blur_alpha)`，`valueRange = 0f..100f`、`steps = 99` → `ConfigUpdate.MenuBlurAlpha`；中文串 `values-zh-rCN/strings.xml:2504`「菜单不透明度」。**上游只有一个 `readMenuBlurAlpha`，底栏与整块菜单共用**。

**本地落地**（逐文件行号）：
- 数据层 `data/ReaderSettingsRepository.ets`：接口 `:287-317`（六字段各带上游行号注释）、默认值 `:682-687`（32 / true / 0 / 0 / false / 85）、`load()` `:817-822`、返回归一 `:1106-1117`（圆角 0–32、模式 0–2、样式 0–1、alpha 0–100，均走 `normalizeInteger`；布尔走 `typeof === 'boolean'`）、`save()` `:1287-1296`（样式只认 1 否则 0）。
- 状态与接线 `pages/Index.ets`：六个 `@State readerReadMenu*` + 装载 + 备份恢复 + 六个 setter + 快照六行；**prop 共 6 处**（快照 1、ReaderPage 1、设置面板 4），**回调共 4 处**（只在设置面板的四个 tab 实例上；ReaderPage 不接回调，这组 prop 在阅读页是纯展示型）。
- 设置面板 `pages/ReaderSettingsPage.ets`：六 `@Prop` `:211-222`；Toggle 接真 `:769-793`；Slider 接真 `:804-805`；实际生效模式 `:849-852 effectiveBottomBarBlurMode()`；滑块真值 `:872-873`、上限 `:882`；下拉选中态 `:911`、写回 `:942`；互斥可见 `:999-1000`；条目表 `:2357-2363`（「底栏模糊样式」是**本地新增的一行**，上游是同一 tab 内的下拉项）。
- 渲染 `pages/ReaderPage.ets`：props `:235-246`；`readerBottomBarFillColor()` `:842-843`（`Math.min(0.6, max(0, min(100, alpha)) / 100)`，上限 0.6 对齐 `ReadBookMenuBarShared.kt:49-85` 的 `coerceAtMost(0.6f)`）；`readerBottomBarGradient()` `:856-858`（`Solid` 两段同色、`Progressive` 上浓下淡且第二段 `max(0, alpha - 0.25)`，`angle: 180`）；`readerBottomBarButtonGlassEnabled()` `:874-875`；底栏容器 `:4022`（宽度）、`:4025`（填充）、`:4026`（渐变）、`:4028-4031`（四角圆角，非悬浮时下方两角强制 0）、`:4033`（底部外边距）。原来这五行是硬编码 `.width('92%').backgroundColor('#D931282A').borderRadius(32).margin({bottom:16})`。
- 备份 `data/BackupRepository.ets`：恢复返回对象补六行 `current.<field>`（不读 json/xml）。六个键全在 `help/storage/BackupConfig.kt:232-244` 的 `readPrefKeys` 忽略清单（`readMenuBottomCornerRadius` `:232`、`readMenuFloatingBottomBar` `:233`、`readMenuBottomBarBlurMode` `:235`、`readMenuBottomBarLiquidGlassButtons` `:239`、`readMenuBottomBarBlurStyle` `:242`、`readMenuBlurRadius` `:243`、`readMenuBlurAlpha` `:244`），本地 `preferenceKeysByCategory.readConfig` 早已列全，**因此这组外观项不随备份走、恢复时保留本机现值**。

**已知差异**：
1. **「底栏按钮液态玻璃」只做了可配+落库**：`readerBottomBarButtonGlassEnabled()` 尚无调用点，按钮底色未真驱动。ArkUI 没有 `backdropBlur` 的等效物，上游的液态玻璃按钮在 HOS 上要靠半透明渐变近似，本轮未做近似（避免发明上游没有的视觉效果）。
2. **「底栏模糊」的实际模糊未做**：本地只把「模糊模式」作为背景不透明度与渐变的开关使用，没有真的做背景模糊。上游的 `Haze` 在 `ReadBookMenuBarShared.kt` 里最终是按 alpha 叠半透明色，本地照此；但若上游在 API 13+ 走了真正的模糊材质，本地无法等价。
3. **「底栏模糊样式」是本地新增的一条独立条目**（上游是同一 tab 内的下拉项，本地条目表原本没有它），因此 E 块已接数比未接减行数多 1。
4. 圆角/悬浮/透明度/渐变的**像素级视觉对比未取证**：模拟器书架无正文可读、进不了阅读页，取不到底栏帧。

**验收**：`assembleHap` BUILD SUCCESSFUL；设备（`127.0.0.1:5555`）实测底栏圆角 32→0 后退出重进仍为 0；关闭「底栏悬浮」→「底栏模糊样式」出现且「底栏液态玻璃」消失，重新打开则相反（两个方向都验过）；「底栏模糊」开关落库 `2`、「底栏按钮液态玻璃」落库 `true`；「底栏模糊样式」切「渐变」后条目副标题变「渐变」且**重启应用后保持**；「底栏模糊透明度」85→50 后重进仍为 50。完整记录见 [VALIDATION](VALIDATION.md)。

**KI-E5 标题栏形态八项（已实现）** —— 覆盖 E-28 标题栏胶囊（`ReadBookConfig.kt:85`）、E-29 标题栏模式（`ReadSettings.kt:12`，**字符串四态** `"0"`–`"3"`）、E-30 标题栏紧凑（`ReadBookConfig.kt:81`）、E-31 标题栏图标样式（`:101`，夹 0–2）、E-32 顶栏模糊（`:105`，夹 0–2）、E-33 顶栏模糊样式（`:107`，夹 0–1）、E-34 顶栏液态玻璃按钮（`:83`）、E-35 合并标题栏按钮（`:84`）。

**上游口径**（`ui/book/read/sheet/SystemMenuPage.kt` 的 `TopBarTab`，`:703-868`）：
- `TinySwitchSettingItem(read_menu_top_bar_title_capsule)` → `ConfigUpdate.MenuTopBarTitleCapsule`。
- **`AnimatedVisibility(visible = !preferences.readMenuTopBarTitleCapsule) { TinyDropdownSettingItem(title_bar_mode) }`** —— 胶囊开启时「标题显示方式」整项隐藏。
- `TinySwitchSettingItem(title_bar_compact)` → `ConfigUpdate.TitleBarCompact`；消费点 `ui/book/read/ReadMenuActionDefs.kt:505-506`：`if (state.menuConfig.titleBarCompact) return listOf(moreDef)` —— **开启后顶栏只保留「更多」**。
- `TinyDropdownSettingItem(read_menu_icon_container_style)`，选项「纯色 / 色调 / 描边」= `"0"/"1"/"2"` → `ConfigUpdate.TitleBarIconStyle`。折算在 `ReadBookMenuBarTitle.kt`：`iconStyle == 1 → surfaceContainerLow` 底色（`:1008-1013`、`:534-540`）、`iconStyle == 2 → BorderStroke(1.dp, tint.copy(alpha = 0.45f))`（`:436`、`:873-876`）、`0` 透明底无描边。
- `TinySwitchSettingItem(read_menu_bar_blur)`，**`checked = preferences.readMenuTopBarBlurMode == ReadMenuBlurMode.Haze`** —— 顶栏只认 `Haze(2)`，不认 `LiquidGlass(1)`，也**没有**底栏那种「非悬浮降级」逻辑（只读判定 `ReadBookMenuBarTitle.kt:1000-1006`）。
- `TinyDropdownSettingItem(read_menu_bar_blur_style)`，选项「填充 / 渐变」= `Solid`/`Progressive`；**与底栏不同：顶栏这个下拉没有 `AnimatedVisibility` 包裹，常驻可见**。
- `TinySwitchSettingItem(read_menu_bar_liquid_glass_buttons)` → `ConfigUpdate.MenuTopBarLiquidGlassButtons`；消费 `ReadBookMenuBarTitle.kt:996-1000 readMenuTopBarButtonLiquidGlassEnabled()`（`&& readerMenuLiquidGlassAvailable(backdrop)`）。
- `TinySwitchSettingItem(read_menu_top_bar_merge_buttons)` → `ConfigUpdate.MenuTopBarMergeButtons`；消费 `ReadBookMenuBarTitle.kt:973-996`：为真走 `MenuTitleBarMergedGlassButton`（`Row(height 40.dp)` + pillShape + 分隔线），为假走 `Row(spacedBy(6.dp))`。
- **`titleBarMode` 是四值不是三值**：中文 `values-zh-rCN/arrays.xml:242-247`（在应用栏上显示 / 在独立行上显示 / 仅显示标题 / 不显示），值 `values/array_values.xml:146-151`（`"0"`–`"3"`），默认 `"1"`。消费点 `ReadBookMenuBarTitle.kt`：`:207` 非胶囊时只有 `"0"`/`"2"` 把书名放应用栏行内；`:239` 只有 `"1"` 让书名单独占一行；`:259` 只有 `"0"`/`"1"` 显示章节行；`:198` 只有 `"3"` 才把胶囊整体隐藏。
- 备份口径（**八项里只有一项随备份**）：`readMenuTopBarBlurMode`（`BackupConfig.kt:234`）、`readMenuTopBarLiquidGlassButtons`（`:236`）、`readMenuTopBarMergeButtons`（`:237`）、`readMenuTopBarTitleCapsule`（`:238`）、`readMenuTopBarBlurStyle`（`:240`）、`titleBarIconStyle`（`:254`）、`titleBarMode`（`:259`）**全在** `readPrefKeys` 忽略清单里；**`titleBarCompact` 不在**（该文件 `grep titleBar` 只有 `:254`/`:255`/`:256`/`:259`），随 `config.xml` 无条件导出。

**本地落地**（逐文件行号）：
- 数据层 `data/ReaderSettingsRepository.ets`：接口 `:319-362`（八字段各带上游行号注释）、默认值 `:734-741`（`false / '1' / false / 0 / 0 / 0 / false / false`）、`load()` `:877-885`、返回归一 `:1181-1197`（`titleBarMode` 走四值白名单、`titleBarIconStyle` 0–2、`readMenuTopBarBlurMode` 0–2、`readMenuTopBarBlurStyle` 0–1、两个布尔 `typeof` 保护）、`save()` `:1378-1386`。
- 状态与接线 `pages/Index.ets`：八个 `@State reader*`（`:251-265`）+ 装载 `:1888-1895` + 备份恢复 `:3332-3339` + 八个 setter `:2842-2899` + 快照 `:2009-2016`；**prop 共 6 处**（`:2009`、`:4657`、`:4892`、`:5324`、`:5621`、`:5860`），**回调共 4 处**（只在设置面板的四个 tab 实例，ReaderPage 调用点不接回调）。
- 面板 `pages/ReaderSettingsPage.ets`：八 `@Prop` `:224-238` + 八回调 `:403-409`；五个 Toggle 接真 `:803-834`（`顶栏模糊` 按 `readMenuTopBarBlurMode === 2` 回显、写 2/0）；`getMenuChoices('标题栏模式')` 改成上游四值、`getMenuSelectedIndex` `:961-963`、`applyDetailChoicePreview` `:998-1004`、**Segments 的 `onSelect` 也补了同样三行落库** `:861-863`（原先只有弹层路径落库）；`isMenuSettingsEntryVisible()` `:1063` 在 tab 短路**之前**加「标题栏模式仅在胶囊关闭时可见」；弹层底部提示文案把「标题栏模式 / 标题栏图标样式 / 顶栏模糊样式 / 底栏模糊样式」四项从「仅展示选择预览，不保存设置。」改为「选择后立即应用并保存」，因为这四项已真落库。
- 阅读页 `pages/ReaderPage.ets`：八 `@Prop` `:248-266`；新增 `readerTopBarFillColor()` `:902`、`readerTopBarGradient()` `:909-928`、`readerTopBarButtonFillColor()` `:930-931`、`readerTopBarButtonBorderWidth()` `:938-942`、`readerTopBarMergeEnabled()` `:946-947`、`readerTitleInlineVisible()` `:1760-1761`、`readerTitleOwnLineVisible()` `:1765-1766`、`readerChapterLineVisible()` `:1770-1773`、`readerTitleCapsuleVisible()` `:1776-1777`；`getVisibleTopActions()` 在 `:1646` 按 `titleBarCompact` 短路只留「更多」；新增 `readerTopActionGroup()` `:1699-1728`（合并胶囊容器）、`readerTopActionOverflowButton()` `:1730`、`readerTitleCapsule()` `:1743-1757`；顶栏渲染块 `:4083-4109` 按上面四个可见性方法分流，容器底色由硬编码 `'#D931282A'` 改为 `readerTopBarFillColor()` + `readerTopBarGradient()`。
- 备份 `data/BackupRepository.ets`：导出段补 `titleBarCompact` `:695-698`（唯一随备份项）；恢复段 `:1446-1451` 补八字段（`titleBarCompact` 读 `config.xml` 并 `current` 兜底，其余七项直接取 `current`，因为它们都在忽略清单里）。

**已知差异**：
1. `readMenuTopBarLiquidGlassButtons` 的玻璃材质**无实现**：ArkUI 没有 `backdropBlur` 等效物，本地只做可配 + 落库 + 用它抑制描边（`readerTopBarButtonBorderWidth()`）。
2. 顶栏模糊的实际模糊半径同样未做（ArkUI 无模糊滤镜），只把 `readMenuBlurAlpha` 折算成填充不透明度（上限 0.6，对齐 `ReadBookMenuBarShared.kt:49-85` 的 `coerceAtMost(0.6f)`），与 KI-E4 底栏口径一致。
3. 胶囊里的书名/章节名**只做展示、点不进去书籍详情**：上游 `TitleCapsuleGlassLayout`（`ReadBookMenuBarTitle.kt:492-620`）在非本地书上还有书源小圆点入口，本地 `ReaderPage` 没有 `onOpenBookInfo` 回调，暂无该入口。
4. 「标题栏紧凑」在上游还会把「换源」「朗读音频下载」搬进悬浮菜单（`ReadBookMenuBarFloating.kt:190`）；本地没有悬浮菜单层，只实现「顶栏只留更多」这一半。
5. 顶栏的**像素级视觉未取证**：模拟器书架上的书正文文件丢失、`ReaderPage` 进不去，取不到顶栏帧，六组视觉对比（书名位置四态、胶囊、紧凑、合并容器、图标样式三档、底色随透明度）只有面板值与落库证据。

**验收**：`assembleHap` BUILD SUCCESSFUL（两次：39 s 738 ms / 21 s 843 ms，无 ERROR）；设备实测（`127.0.0.1:5555`，API 26）：开「标题栏胶囊」后「标题栏模式」整行消失、关闭后恢复（两个方向都做了 `dumpLayout` 对照）；八项逐项拨动后退出设置页重进 + `aa force-stop` 重启应用，值全部跨进程保持；「标题栏模式」弹层四项文案与上游中文串一致。详见 [VALIDATION](../VALIDATION.md) 的 2026-10-31 KI-E5 节。

**KI-E6 无上屏条目四项（已实现）** —— 涉及 E-36 菜单镜头半径（`ReadBookConfig.kt:114`，夹 0–48f）、E-38 阅读栏样式（`ReadSettings.kt:69`，默认 1）、E-39 阅读栏样式跟随页面（`:68`）、E-40 更多操作配置（`:121`）。原条目里「E-37 自动亮度」已由 2026-10-31 的 KI-A9 接上，本轮不再涉及。

**上游口径**

这四项里有三项是「上游有字段、没有设置入口」：

- **E-36 `readMenuLensRadius`**（`PreferKey.kt:409`、`ReadSettings.kt:110` 默认 24f、`ReadBookConfig.kt:114` 夹 0–48f）：`grep -rn "MenuLensRadius" app/src/main/java/io/legado/app/` 共 16 处，全部是键名、`ReadSettingsRepository.kt:307-308`/`:483`/`:604`/`:733` 落库与映射、字段声明、夹取、`ReadBookContract.kt:484`/`:1920` 契约、`ReadConfigUpdateDelegate.kt:457-461` 委托、`ReadBookViewModel.kt:2130` 快照、`ReadBookMenuBarShared.kt:78` 渲染消费、`BackupConfig.kt:248` 忽略清单 —— **没有任何 UI 发送点**（`SystemMenuPage.kt` 与 `ReadConfigScreen.kt` 都查无此项）。消费端把它当 `readerMenuLiquidGlass` 的 `lensRadius`（`ReaderMenuGlass.kt:25-53` 的 `lens()`），而该材质只在 `readerMenuLiquidGlassAvailable(backdrop)` 即 API 33+ 生效。
- **E-39 `readBarStyleFollowPage`**（`ReadSettings.kt:68` 默认 false）：全仓只有 `PreferKey.kt:290`、`ReadSettingsRepository.kt:206`/`:557`/`:691`、`BackupConfig.kt:217`、`ReadConfig.kt:56` 只读快照，加两个消费点 `model/ReadBook.kt:724-726`（`upReadBookConfig` 里阅读样式档位变化时刷新动作栏）与 `ui/book/read/ReadStyleDelegate.kt:445-449 postActionBarUpdateIfFollowingPage()`（`colorSelected` 的 TEXT_COLOR `:376` / TEXT_ACCENT_COLOR `:384` / BG_COLOR `:392` 三处调用），**同样没有 UI 发送点**。它控制的是「正文色/强调色/背景色变化后是否刷新动作栏」。
- **E-38 `readBarStyle`**（`ReadSettings.kt:69` 默认 1，`ReadBookConfig.kt:99` 夹 0–2）：**已由 KI-E1 完整接上**，本轮只纠正状态、不重复实现。
- **E-40 `moreActionsConfig`**（`ReadSettings.kt:121` 默认空串）是唯一有完整 UI 与落库链路的：编码 `ReadButtonConfigDelegate.kt:75-84 saveMoreActions` （`joinToString(";") { "${it.id},${it.enabled}" }`），解析 `parseMoreActions`（`:86-98`）**空串 = 全部默认开启**、串里未出现的项补 `true`（与顶栏/底栏「默认关闭」相反），动作池 `ReadBookContract.kt:548-560`（28 项），UI `sheet/ReaderMoreActionsSheet.kt:78-131`。**`moreActionsConfig` 不在 `BackupConfig.readPrefKeys` 忽略清单里**（该清单只有 `:216`/`:217`/`:248` 三条相关命中），随 `config.xml` 无条件备份。

**本地落地**

- 数据层 `entry/src/main/ets/data/ReaderSettingsRepository.ets`：`readMenuLensRadius` 接口 `:439`、默认 `:863`、读 `:1040`、归一 `:1387-1388`、写 `:1621-1622`；`readBarStyleFollowPage` 接口 `:447`、默认 `:864`、读 `:1041`、归一 `:1389-1390`、写 `:1623`；`moreActionsConfig` 接口 `:454`、默认 `:865`、读 `:1042`、归一 `:1391-1392`、写 `:1624`；编解码 `:1896 encodeMoreActions` / `:1905 decodeMoreActions`。
- `entry/src/main/ets/pages/Index.ets`：`@State readerReadMenuLensRadius` `:198`、`@State readerReadBarStyleFollowPage` `:204`；装载 `:1981-1982`；快照 `:2130`/`:2131`/`:2134`；备份恢复 `:3685-3686`；`setReaderMoreActions` 里补 `persistReaderSettings()` 回写 `:2047-2058`；恢复流程里解码写回仓储 `:3695-3696`。
- `entry/src/main/ets/data/BackupRepository.ets`：`config.xml` 导出 `moreActionsConfig` `:701-704`；恢复段 `:1500-1504`（前两项取 `current`，第三项优先读 `config.xml`）。
- 面板 `ReaderSettingsPage.ets` 无这三项条目 —— 与上游一致。

**已知差异**

1. `readMenuLensRadius` 只落库不上屏，`lens` 高光效果不实现（ArkUI 无液态玻璃材质）；这与 KI-A3 `disableReturnKey` 同一判据「上游有字段就保留、上游没有效果就不造」。
2. `readBarStyleFollowPage` 只落库不上屏，靠 `ReaderPage.ets:1023 readerMenuBaseColor()` 的 `@Prop` 响应式重算等价实现，未做像素级取证。
3. `moreActionsConfig` 的运行时真源仍是本地独立仓储 `ReaderMoreActionsRepository`（prefs `legado_reader_more_actions`，23 项，比上游 28 项少 `source_login`/`source_pay`/`edit_source`/`disable_source`/`ai_chat` 五项，与「在线书源 / AI」范围外一致），快照字段是它的备份投影，两者靠 `Index` 的双向编解码保持一致。
4. 上游 `parseMoreActions` 的「未出现的项补 `true`」语义本地照抄；但本地默认池只有 23 项，备份串里若出现本地不认识的 id 会被 `decodeMoreActions` 过滤掉。

**验收**

`assembleHap` 两次 BUILD SUCCESSFUL（53 s 447 ms / 35 s 399 ms），无 ERROR。设备实测（HOS 模拟器 `127.0.0.1:5555`，API 26）：改一次阅读设置触发保存后，偏好文件出现 `<double key="readMenuLensRadius" value="24.000000"/>`、`<bool key="readBarStyleFollowPage" value="false"/>`、`<string key="moreActionsConfig">source_custom_button,true;change_source,true;…</string>`（23 项，全部 `,true`），`aa force-stop` 重启后不变；面板无这三项。详见 [验证记录](VALIDATION.md)。

### B 页眉页脚

B 块唯一的 `未接` 行（页眉/页脚独立字体）已于 2026-10-31 复核改判 `已接`：排版设置面板的字体目标四按钮可选「页眉」「页脚」并落 `headerFont`/`footerFont`。**残留问题**：页眉页脚 tab 里那条「选择字体」（`ReaderSettingsPage.ets:799-801`）仍走 `showNotMigrated('页眉/页脚字体选择')`，是重复的占位入口，功能已由排版设置面板提供。补法：把该行改指向 `openFontSelection()` 并带 `fontTarget: 'header'`，属一行改动，本轮不动。

## 设备范围

- API 12 真机兼容尚未验证。HOS 模拟器检查只代表验证记录中列出的操作；N 端 API 26 数据不作为 E 端或 API 12 结论。
- r257 设备没有自定义分组，卡片上新增的私有标记/刷新状态文案未在设备上直接显示验证。

构建与设备记录见[验证记录](VALIDATION.md)，Android ZIP 字段边界见[备份恢复说明](BACKUP-RESTORE.md)。
