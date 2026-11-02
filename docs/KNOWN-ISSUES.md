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
  1. `drawPage` 只对**当前页**记几何（`recordGeometry`）和画选区（`drawSelection`），四页窗口里邻页一律不记——否则最后画的邻页会顶掉当前页坐标。
  2. 手指坐标换算 `canvasViewportY()`：`finger.localY` 相对外层 `Stack`，画布顶边用 `getComponentUtils().getRectangleById(CANVAS_ID).windowOffset.y` 与 `STACK_ID` 的同名值相减求得（两者同口径，状态栏自动抵消）；**不要**直接减 `Area.position.y`，它会漏掉父容器的页眉占位。
  3. 滚动模式下再减 `scrollOffset`：`canvasContentY()` = 视口 y − `vp2px(scrollOffset)`（`drawScrollSlot` 里是 `translate(0, scrollOffsetPx)`）。
- 把手几何与命中照上游 `drawPinHandle` / `handleHitRadius`：圆心在矩形 `bottom + radius`，竖线只画到矩形 `bottom`（不画到圆心），命中热区 28vp 且按「竖线顶端—圆心」胶囊中轴线求最短距离；拖动时端点跟**把手**走而不是跟手指走（记 `canvasHandleGrabOffsetX/Y`），再减 `radius` 回到行底做 `positionAt()`。
- 跨元素/跨行扩展：拖动取位用 `ReaderCanvasRenderer.positionAt(x, y, style)`，它在一行的**所有**元素间推进、超出最后一个元素就返回该行 `endPosition`；不能沿用单元素的 `glyphOffsetAt`（分页器会把一行按标点/样式切成多个小元素，单元素会被行末 clamp 住，选区再也扩不出去）。
- 把手淡入淡出：`animateCanvasHandleTo()` 用 `UIContext.createAnimator` 做真补间，淡出 90ms、淡入 140ms（对齐上游 `SelectionHandleFadeOutMillis` / `SelectionHandleFadeInMillis`），拖动时另一侧把手同时淡出。
- 菜单：菜单浮层 `Column(){ readerMarkingSelectionMenu() }.position(...)`，锚点由 `refreshCanvasSelectionMenuAnchor()` 按选区条带的 `selectionStartX/Y`、`selectionEndX/Y`、`selectionTopY/BottomY` 回填；沿用既有 `runSelectionMenuAction()`（复制 / 书签 / 划线 — 笔记）与 `createMarkingFromCurrentSelection()`。
- 清理：程序化翻页的 `animator.onFinish` 调 `resetCanvasSelectionState()`（对齐上游 `ReaderSelectionLifecyclePolicy.shouldClearForPageChange`）。

**验收**：模拟器上长按出选区带 + 两个把手 + 浮动菜单；拖起始把手把选区从单字扩到两行、拖结束把手跨行；点「划线 — 笔记」面板回显完整选中文本并可保存，保存后正文出现绿色下划线；详见 [VALIDATION](VALIDATION.md) 同节。

### 顺带补回：高亮规则（正则命中的字色/底色/下划线）—— 已接

画布化时先只搬了「用户划线/笔记」（`markings`），`ReaderHighlightRule` 的正则命中样式一度完全没画——这是 Span 分支删除后的真实功能退化，2026-11-02 已补齐。

- 上游口径：`legacy/LegacyReaderStyleRangeMapper.kt` 的 `map()` 把启用规则按 `position` 升序展开成区间，`priority = index`；用户划线走 `priority = 10_000 + index` 压在高亮规则之上。
- 本地实现：`ReaderPage.ets` 的 `buildReaderCanvasHighlights()` 把 `readerHighlightRanges` 转成 `ReaderCanvasStyleRange`（`textColorArgb` / `backgroundArgb` / `decoration` / `decorationArgb`），再把 `markings` 里 `effect === 'text'` 的字色区间追加在数组末尾；`ReaderCanvasSurface.ets` 的 `splitStyledSegments()` 按区间端点切段、每段取「完全覆盖它的最后一个 range」，`getParagraph()` 用 `ParagraphBuilder.pushStyle / addText / popStyle` 逐段套样式。
- `underlineMode` 映射：`6 → LINE_THROUGH`、`1..4 → UNDERLINE`、否则 NONE；线型 `2 → DASHED`、`3 → WAVY`、`4 → DOUBLE`、否则 SOLID。
- 验收：设备上原本无高亮规则数据，用 UI 造了一条「文字颜色」划线（`uitest uiInput longClick 400 1000` → 菜单「划线 / 笔记」→ 样式「文字颜色」→ 保存），第 2 次翻页后屏幕上出现绿色字形像素（738 个，bbox `(392,2374)-(540,2440)`），确认分段样式确实下到了 `Paragraph` 并画出。**通过。**

### 已删除：默认参数把所有人推到最慢的渲染分支

原记录点名的 `ReaderPage.ets` 分支 `if (this.currentPageContainsImages() || this.readerBottomJustifyGap > 0) { ReaderPageTextLines } else { ReaderPageTextJoined }` 与 `textBottomJustify` 默认 true 导致每页新建 400-900 个 Span 节点的代价，**已随 Span 渲染分支整体删除而消失**：现在一页的绘制成本与行数线性相关，与默认值无关。`textBottomJustify` 的语义仍保留（画布下表现为 `ReaderCanvasLayout.bottomJustifyGapPx` 按行 y 摊分）。

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

> 数字沿革：本节最初写于 r297，当时是 97 行 `未接`；r300–r316 深色模式与阅读配置各批落地后，实测已降到 **11 行**（189 行 = 176 已接 / 11 未接 / 2 不适用，用 `python scripts/reader-config-pending.py` 复算）。KI 组保留原编号不动，已实现组在组内标注「已实现」，不删组——删了会让对照表「备注」列的 `KI-xx` 锚点变成死链。

判定口径按[项目范围](PROJECT.md)「范围之外」段：在线书源抓取、RSS、TTS 朗读、WebDAV、AI、云同步与额外设备形态，不因开关已上屏而算已实现；上游没有的行为不补。凡上游行为在本地已有等价实现、或上游分支在本平台根本不存在，直接记「不接」；其余记「要接，待排期」并写补法。

与字段口径的关系：本节按 **A–G 明细表的行**登记（现 11 行）。对照表 §一 1.5 按**上游声明名**判定的 112 项里，另有 9 项判「不接」但不对应任何 KI 组，理由直接写在 1.5 表内，不在此重复——`menuBgColor`、`menuBgColorNight`、`menuAcColor`、`menuAcColorNight`、`menuBottomCornerRadius`、`menuBottomHorizontalMargin`、`menuBottomBottomMargin`（都是上游 `Config` 里 `@Transient` 的主题包承载字段，上游没有用户设置入口）、`readStyleSelect`、`comicStyleSelect`（图片书/漫画，本地无该内容形态，明细表 A 块已判 `不适用`）。两个口径不可相加。

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
- **`<usehtml>` 富文本段实际没有渲染层**：`richHtml` 字段只在 `entry/src/main/ets/data/LocalTextSemantics.ets:16/103/125/158` 四处定义与赋值，全仓 grep `richHtml` 无任何消费点，`ReaderPage` 也不读它。2026-11-01 r299 实测：`adaptSpecialStyle=true` 下正文仍**字面显示** `<usehtml><b>粗体富文本块</b> 与 <i>斜体</i> …</usehtml>` 源码（截图 `tmp/y2.png`、`r4.png`）。即当前行为与「关闭适配特殊样式」在渲染结果上无差别，只有 `[newpage]` 换页是真生效的。
- `[newpage]` 换页**已于 2026-11-01 r299 设备取证通过**：`np-test`（1450 B）在 `adaptSpecialStyle=true` 下分页 1/3→2/3→3/3、第 3 页首行是「　　第9段正文，出现在」、全文无字面 `[newpage]`；`false` 下同一本变 1/6 页。页数 3 vs 6 构成决定性对照。`paddingDisplayCutouts` 仍属未验（模拟器无显示缺口，`getWindowAvoidArea(TYPE_CUTOUT)` 返回 `visible=false`）。详见 `docs/VALIDATION.md` 的 r299 节。

**验收**：见 `docs/VALIDATION.md` 的「2026-10-31 N 端 KI-A1 正文渲染适配四项」节。四个 Toggle 与四个存储键一一对应、拨动即落库、重启回显保持、测试值已复原出厂值。

**本轮顺带修复的环境故障**（记入 VALIDATION 备查）：KI-A1 设备验收时发现 prefs 完全不落盘。排查后定位为 **prefs XML 被测试期 `hdc file send` 反复整文件覆盖后损坏** —— `hilog` 报 `E C01653/NativePreferences: ParseNodeElement: An unsupported element type was encountered in parsing = text` / `E ReadSettingXml: The error occurred during getting xml child elements` / `W ReloadFromDisk: ... reload result is 0`，于是 store 与磁盘脱钩，`put()`+`flush()` 静默成功但不写盘。推入一个只有 `<?xml version="1.0" encoding="UTF-8"?><preferences version="1.0"/>` 的空文件即恢复。**后续设备验收不要再整文件覆盖 prefs**。要注入测试值优先用 sed 就地改单个键（`sed 's|旧值|新值|' $P > /data/local/tmp/pv.xml && cp /data/local/tmp/pv.xml $P`，2026-11-01 r299 实测这条路安全，`bgStrNight`/`readBarStyle`/`readMenuBgColorNight` 等都即时生效），或直接拨 UI 控件；整文件 base64 覆盖会踩内存快照与磁盘脱钩（r299 改 `adaptSpecialStyle` 时复现过一次假阴性）。

**KI-A2 菜单层依赖三项（已实现）** —— 覆盖 A-05 展示菜单项图标（`showMenuIcon`，`ReadSettings.kt:119`）、A-08 阅读标题补充信息（`showReadTitleAddition`，`ReadSettings.kt:55`）、A-17 阅读菜单不透明度（`menuAlpha`，`ReadSettings.kt:13`）。

**上游口径**：三项恰好覆盖「上游有配置」的三种形态，判据因此各不相同 ——

- `showMenuIcon`：**有设置入口也有渲染消费点**。入口 `MoreConfigSheet.kt:463` 与 `ReadConfigScreen.kt:426`（中文串「展示菜单项图标」`values-zh-rCN/strings.xml:1324`），落库 `ReadSettingsRepository.kt:332`，字段 `ReadSettings.kt:119` 默认 `false`，夹取 `ReadBookConfig.kt:78`；消费在 `ReadBookMenuBarFloating.kt:174` `val showIcon = state.menuConfig.showMenuIcon`，`:175-181` 只在 `showIcon` 为真时给 `RoundDropdownMenuItem` 传 `leadingIcon`。
- `showReadTitleAddition`：**有设置入口但没有渲染消费点**。字段 `ReadSettings.kt:55` 默认 **`true`**，入口 `MoreConfigSheet.kt:458` 与 `ReadConfigScreen.kt:418`（中文串 `values-zh-rCN/strings.xml:1395`「展示顶部工具栏附加区域」）。全仓 29 处命中全部是键名、`ReadSettingsRepository.kt:169-170`/`:422`/`:544`/`:678` 落库与映射、字段本身、`ReadBookContract.kt:2070` 契约、`ReadConfigUpdateDelegate.kt:739-741` 委托、两处设置界面、`ApplyReadSettingUseCase.kt:23`、`ReadConfig.kt:62` 只读快照、`ReadConfigContract.kt:49`/`:108`、`ReadConfigScreen.kt:418-420`、`ReadConfigViewModel.kt:146`/`:219`、以及单测 `ReadSettingsMappingTest.kt:246`/`:299` 与 `ConfigUpdateActionsInvariantTest.kt:157` —— **没有任何渲染处读取它**。
- `menuAlpha`：**既没有设置入口也没有渲染消费点**。字段 `ReadSettings.kt:13` 默认 `100`，键 `PreferKey.kt:367`，落库 `ReadSettingsRepository.kt:64-65`，映射 `:373`/`:505`/`:637`；中文串 `values-zh-rCN/strings.xml:1912`「菜单不透明度」与 `:1911`「当前 %d%%」。全仓再无消费：`ReadBookMenuBar.kt:484-492` 的 `menuSurfaceAlpha`/`dragMenuAlpha` **取的是 `readMenuBlurAlpha`**（`:482` `val menuSurfaceAlpha = state.menuConfig.readMenuBlurAlpha.coerceIn(0, 100)`），`TextActionSelectionMenu.kt:197-208` 的 `quickMenuAlpha` 是局部动画变量，`res/xml/pref_config_read.xml:53` 那份旧 xml 全仓已无引用（`grep -rn "pref_config_read" app/src/main/java/ app/src/main/res/` 为空）。

**本地落地**（按上游形态一一对应）：

- `showMenuIcon`：存储键同名、布尔默认 `false`。数据层 `entry/src/main/ets/data/ReaderSettingsRepository.ets:443`（接口）、`:866`（默认值）、`:1043`（读）、`:1389`（归一）、`:1625`（写）；`Index.ets` `@State readerShowMenuIcon`、装载与恢复各一行、`setReaderShowMenuIcon`、快照一行、prop 6 处、回调 4 处；面板 `ReaderSettingsPage.ets:1512` 的 `MenuSettingSwitch`（副标题「在「更多」面板中显示每项图标」）；消费 `ReaderPage.ets:4586-4593` —— 「更多」网格面板里 `AppGlyph` 整块包进 `if (this.showMenuIcon)`，对齐上游只在 `showIcon` 为真时给菜单项加前置图标。**在 `BackupConfig.kt:258` 的忽略清单里，不随 config.xml 导出**（`BackupRepository.ets:332` 的忽略键表原本就含 `showMenuIcon`）。
- `showReadTitleAddition`：存储键同名、布尔默认 `true`。数据层 `:451`（接口）、`:867`（默认值）、`:1044`（读）、`:1390`（归一）、`:1626`（写）；面板 `ReaderSettingsPage.ets:1511` 的 `MenuSettingSwitch`（文案对齐上游「展示顶部工具栏附加区域」，副标题直接写「上游只落库，无渲染效果」）；`BackupRepository.ets:702-703` 导出、`:1504-1505` 恢复（不在忽略清单，随 config.xml 备份）。
- `menuAlpha`：存储键同名、整型默认 `100` 夹 0–100。数据层 `:456`（接口）、`:868`（默认值）、`:1045`（读）、`:1391`（归一）、`:1627`（写）；面板无条目（上游也没有）；`BackupRepository.ets:704-705` 导出、`:1506-1507` 恢复。

**已知差异**：

- `menuAlpha` 与 `showReadTitleAddition` **只落库不上屏** —— 上游本就没有消费点，本地不发明效果（与 KI-A3 `disableReturnKey`、KI-E6 `readMenuLensRadius` 同一判据）。
- `showMenuIcon` 的作用域是本地「更多」**网格面板**，不是上游那种下拉菜单：本地顶栏溢出菜单 `TopActionOverflowMenu()`（`ReaderPage.ets:1836-1843`）用的 `MenuItem` 只接受 `startIcon: ResourceStr`，不接受自定义 Builder 组件，而本地图标是自绘的 `AppGlyph`（`components/AppGlyph.ets`）。
- ~~「更多」面板的图标显隐未做像素级取证~~ —— **2026-11-01 r299 已补齐**。阅读页已可进（`the-metamorphosis` 正文完好），把底栏首格从 `settings` 换成 `more_actions` 打开「更多」网格面板后，`showMenuIcon` false vs true 的 changed px=79021（其中 78309 落在面板区 y>1400），即每个网格项左上角的 `AppGlyph` 图标整块出现/消失。同层另外两项也一并取了像素证据：`showMenuIcon` 对顶栏小图标位 changed px=792（bbox `x187-214 y59-99`，全落状态栏区）、`showBottomActionText` changed px=375981（底栏区 375553，开启后出现「更多操作 / 全文搜索 / 自动翻页 / 目录 / 朗读」五个标签）。详见 `docs/VALIDATION.md` 的 r299 节。

**验收**：见 `docs/VALIDATION.md` 的「2026-11-01 N 端 KI-A2 菜单层依赖三项」节。两个 Toggle 拨动即落库、`aa force-stop` 重启后回显保持、prefs 三键（`showMenuIcon`/`showReadTitleAddition`/`menuAlpha`）齐备，测试值已复原。
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

验收：注入 `textColor = #DB4B4B` 后重进阅读页，截图彩色像素 top8 全为红色系（`(213,77,77)` 等），正文与章节标题同时变红；改回 `#38383B` 恢复正常深灰。见 [VALIDATION](VALIDATION.md)。

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

验收：日间 `bgStr = #FFFFFF` 后阅读页中心像素为 `(255,255,255)`；`darkStatusIconNight` false 时状态栏亮像素 6726、改 true 后同一区域 0。见 [VALIDATION](VALIDATION.md)。

**KI-C3 下划线绘制参数四项（已实现）** —— 覆盖 C-07 下划线偏移量（`underlinePadding`，`ReadBookConfig.kt:322`，默认 10）、C-08 下划线延伸（`underlineExtend`，`:325`）、C-09 自定义虚线长度基准（`dottedBase`，`:331`，默认 6f）、C-10 自定义虚线间隔比例（`dottedRatio`，`:334`，默认 6f）。

上游口径：默认值集中在 `help/config/ReadBookConfig.kt:600-609`。组装在 `feature/reader/legacy/LegacyReaderPaginationStyleFactory.kt:65-77`：`ReaderPageUnderline(colorArgb = …, widthPx = underlineHeight.toFloat(), offsetPx = (ReadBookConfig.underlinePadding - 10).dpToPx().toFloat(), extendToColumn = ReadBookConfig.underlineExtend, dashed = dottedLine && !isEInkMode, dashOnPx = durConfig.dottedBase, dashOffPx = durConfig.dottedRatio)` —— **`offsetPx` 是 `(underlinePadding - 10)` 的相对量，默认 10 时偏移为 0**。绘制在 `feature/reader/core/layout/ReaderPaginator.kt:435-455 addPageUnderline()`：`start = if (extendToColumn) columnLeft() else rowElements.minOf { it.bounds.left }`、`end = if (extendToColumn) columnLeft() + config.contentWidthPx else rowElements.maxOf { it.bounds.right }`、`y = lineBottom + offsetPx`，产出一条 `ReaderElement.Rule`；真实画笔在 `feature/reader/platform/ReaderPageDecorationDrawCache.kt:56-77`：`strokeWidth = widthPx.coerceAtLeast(1f)`、`pathEffect = DashPathEffect(floatArrayOf(dashOnPx.coerceAtLeast(0.1f), dashOffPx.coerceAtLeast(0.1f)), 0f)`、`canvas.drawLine(...)`。设置面板 `ui/book/read/sheet/UnderlineConfigSheet.kt:80-145`，四个滑块范围都是 `0f..20f`。

**为什么必须自绘（本轮最重要的判断）**：ArkUI 的 `Text.decoration()` 参数类型 `DecorationStyleInterface`（SDK `ets/component/styled_string.d.ts:760`）只有 `type`、`color`、`style`、`thicknessScale` 四个字段，**没有虚线段长、间隔或竖直偏移**，`TextDecorationStyle.DASHED` 的段长由系统固定。也就是说上游这四项在 HOS 上根本无处可传 —— 这不是「本地没接」，是「本地表达手段不够」。结论：改用 `Line()` 自绘，它的 `CommonShapeMethod` 提供 `stroke`/`strokeWidth`/`strokeDashArray`/`strokeDashOffset`，`strokeDashArray` 恰好是「dash、gap」循环数组，与 `DashPathEffect(dashOn, dashOff)` 一一对应。

本地落地：
1. 仓储 `entry/src/main/ets/data/ReaderSettingsRepository.ets` —— 接口加同名四字段 `:161`–`:164`，默认 `:506`–`:509`（10 / false / 6 / 6），读 `:620`–`:623`，归一 `:768`–`:773`（三个数值夹 0–20），写 `:1018`–`:1021`。
2. 分页器 `entry/src/main/ets/pages/LocalReaderPaginator.ets` —— `interface LocalReaderLine` 新增 `contentWidth: number`（该行未拉伸时的文字实际宽度），在 `appendLine()` 里赋 `contentWidth: naturalWidth`，供自绘线决定右端；这是「不撑满时线只到该行文字右边界」所需的几何。
3. 渲染参数 —— `entry/src/main/ets/pages/ReaderPage.ets` 里保留四个 `@Prop`（`underlinePadding` 10 / `underlineExtend` false / `dottedBase` 6 / `dottedRatio` 6），换算成画布样式的四个量后交给绘制层：`underlineOffsetPx = vp2px(resolveUnderlineOffsetVp())`（`underlinePadding - 10`，直接对齐上游相对量口径）、`underlineWidthPx = vp2px(max(1, underlineHeight))`（对齐 `coerceAtLeast(1f)`）、`dashIntervals = resolveUnderlineDashArray().map(vp2px)`（非虚线为空数组即实线，虚线为 `[max(0.1, dottedBase), max(0.1, dottedRatio)]`，对齐 `coerceAtLeast(0.1f)`）。**真实绘制在 `entry/src/main/ets/reader/ReaderCanvasSurface.ets`**：`layoutPage()` 记下每行的 `top` 与 `line.contentWidth`，`drawLineUnderline()` 用 `drawing.Pen`（`setStrokeWidth(style.underlineWidthPx)` + 虚线段 `setPathEffect(drawing.PathEffect.createDashPathEffect(style.dashIntervals, 0))`）+ `canvas.drawLine(x0, y, x1, y)` 直接画在画布上，右端 `x1 = underlineExtend ? bodyWidthPx : min(bodyWidthPx, line.contentWidth * vpScale)`。2026-11-02 画布重写后，原 `ReaderPage.ets` 的 `resolveUnderlineLineEnd()`、`readerPageLineOffset()`、`readerUnderlineY()` 与 `@Builder ReaderUnderlineLayer`（`Line()` 自绘）已随 Span 分支一起删除。
4. 避免双线（历史记录，现已不适用）—— 画布重写前曾把 6 处 `Text.decoration` 里的正文下划线回落收敛为 `TextDecorationType.None`，避免与 `Line()` 自绘的那条重复。2026-11-02 之后正文里已没有任何 `Text` 组件，下划线只由画布的 `drawLineUnderline()` 画一次，不存在双线问题。
5. 备份 `entry/src/main/ets/data/BackupRepository.ets` —— `AndroidReadConfigBackupRecord` 补四字段，导出写 `config.xml`（`int` / `boolean` / `float` / `float`），恢复按 `readJsonNumber`/`readJsonBoolean`/`readXmlInteger`/`readXmlFloat` 取值并夹 0–20，缺键保留现值。这四键不在上游 `BackupConfig.readPrefKeys` 忽略清单里，随 `config.xml` 无条件备份。
6. 面板 `entry/src/main/ets/pages/ReaderSettingsPage.ets` —— 「文字效果」面板在「下划线粗细」之后补「离字间距」滑块（0–20）、「撑满整行」开关；`dottedLine` 为 true 时再展开「实线段长」（0–20）与「空隙长度」（0–20）两个滑块。

已知差异：
- **滚动模式不支持这四项**。`ReaderPageTextJoined`/`ReaderPageTextLine` 之外，滚动模式（`Scroll` 里那串 `Text`）拿不到逐行几何，无法自绘，仍用 `Text.decoration` 表达下划线，因此虚线段长/间隔/偏移/延伸只在分页模式生效。已在代码注释与本节同时记录。
- 单位：上游 `dottedBase`/`dottedRatio` 是 px，本地按 vp 传给 `strokeDashArray`，两者在 3.5 密度屏上比值为 3.5，视觉疏密随设备密度略有不同。

验收：设备实测三档 `underlinePadding` 0 / 10 / 20 时同一行下划线 y 依次为 409 / 444 / 478（每档差 ~35px = 10vp × 3.5 密度，线性成立）；`underlineExtend` 关闭时短行 `x0=56 x1=720`（宽 665），打开后所有行统一 `x0=56 x1=1223`（宽 1168）；`dottedBase=6` 单行 34 段、`dottedBase=20` 单行 18 段。见 [VALIDATION](VALIDATION.md)。

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
- 渲染：`entry/src/main/ets/pages/ReaderPage.ets` 新增 `resolveReaderColumnCount()`、`getColumnStrideWidth()`、`lineColumnAt()`、`readerColumnIndexes()`、`getBodyContentWidth()`（按列宽折算）；列几何交给画布：`buildReaderCanvasLayout()` 把 `columnCount` / `columnStridePx` / `bodyWidthPx` 写进 `ReaderCanvasLayout`，`ReaderCanvasSurface.ets` 的 `layoutPage()` 用 `left = originXpx + column * columnStridePx` 与 `used[column]` 分列累加行高，与 `advanceColumn()` 的「先填满第 0 列再填第 1 列」一致。2026-11-02 画布重写后，原 `readerColumnFirstLineIndex()`、按列 `ForEach(readerColumnIndexes())` 的 ArkUI 列容器、按列分组的 `ReaderUnderlineLayer` 都已删除（`readerColumnFirstLineIndex()` 与 `ReaderUnderlineLayer` 随 Span 分支删除）。`getFullBookPaginationLayoutKey()` 仍拼进列数。
- 面板：`entry/src/main/ets/pages/ReaderSettingsPage.ets:1097` 的「横屏双页」由占位改为四档下拉，副标题 `readerColumnModeTitle(this.doubleHorizontalPage)`，`getDetailChoices` 返回 `READER_COLUMN_MODE_TITLES`，`applyDetailChoicePreview` 落库，`openDetailSheet` 按当前档位回显。
- 备份：`entry/src/main/ets/data/BackupRepository.ets` 的 `AndroidReadConfigBackupRecord` 加 `doubleHorizontalPage: string`，config.xml 与 readConfig.json 双向导出、恢复走 `readJsonString ?? readXmlString ?? current.xxx` 并校验四档。

**已知差异**
- 平板判定：本地按「视口短边 ≥ 600vp」近似 Android 的 `sw600dp`；上游用资源限定 `isTablet`，在折叠屏/分屏等非常规尺寸上可能判定不同。
- 底部两端对齐：`ReaderPage.ets` 的 `calculateReaderBottomJustifyGap()` 在列数 > 1 时直接返回 0。原因是本地按「整页行数」摊分末行空隙，双列下会把两列的高度算错；上游是 `justifyColumnBottom()` 逐列独立摊分。因此**双列模式下末行不做两端对齐**，这是有意为之的保守处理。
  - 单列下的位移实现（2026-11-02 画布重写后已改为直接算进行 y）：画布 `layoutPage()` 里 `top = originYpx + used[column] + line.verticalSpaceBefore * vpScale + layout.bottomJustifyGapPx * lineCount[column]`，即第 i 行直接按 `i * gap` 下移，不经过任何布局流累加，等价于上游 `justifyColumnBottom()` 的逐行 `offsetY(deltaY)`。Span 时代的 `.translate({ y })` 实现已随分支删除；当时的历史教训仍然有效：**位移不能塞进 `margin`**，margin 参与布局流会让位移逐行累加（总和 `gap·n²/2`），表现为行距越往下越疏、末行溢出屏幕并与页脚重叠。
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
3. ~~边框描边、模糊半径、模糊着色、文字色的视觉变化未做像素级取证~~ —— **2026-11-01 r299 已补齐**：边框宽度 0 vs 4 changed px=222402、模糊半径 0 vs 32 changed px=358357（正文区 0 变化）、模糊透明度 100 vs 20 changed px=290444、描边色 `#00FFFF` 后青色像素 19578 且横竖带位置与面板 `bounds` 一致。详见 `docs/VALIDATION.md` 的「2026-11-01 N 端 r299 菜单与正文视觉取证」。
4. 上游「模糊色没有清除入口」这一约束本地照搬（`applyMenuColor` 对模糊色也支持再点同色清除，属**放宽**，不影响已有行为）。
5. **`readMenuTopBarBlurMode` / `readMenuBottomBarBlurMode` 无消费点**：`ReaderPage.ets:261`/`:241` 只有 `@Prop` 声明，全仓 grep 只命中这两行；实测改值 `changed px=0`，即「顶栏/底栏模糊模式」开关落库但不改变任何像素。

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
3. ~~浮动图标行的实际渲染未做像素级取证~~ —— **2026-11-01 r299 已补齐位置两项**：`titleBarIconPosition` 0 vs 3 changed px=131697（正文区 103120，图标行从顶栏下方移到菜单浮层上方）、0 vs 1 changed px=10541（bbox `x92-1189 y570-629`，同行改右对齐），像素分区与 `readerFloatingIconTopVisible()`/`readerFloatingIconBottomVisible()` 分支一致；「自定义圆形图 36dp」「玻璃底」仍只有代码与面板证据。详见 `docs/VALIDATION.md` 的 r299 节。

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
4. ~~圆角/悬浮/透明度/渐变的像素级视觉对比未取证~~ —— **2026-11-01 r299 已补齐三组**：圆角 0 vs 32 changed px=13651（圆角 0 时 y=2250 行面板左缘 x=51 即开始、圆角 32 时 x=155，内缩 104px ≈ 30vp）、悬浮 vs 非悬浮 changed px=121541（悬浮态 x 155-1124、关闭后贴满 x 0-1279）、透明度 20 vs 100 changed px=290444。**仍未取证**：纯色 vs 渐变的渐变方向。详见 `docs/VALIDATION.md` 的 r299 节。
5. **`readMenuBottomBarBlurMode` 无消费点**：`ReaderPage.ets:241` 只有 `@Prop` 声明、全仓无消费点，改值 `changed px=0`；`readerBottomBarButtonGlassEnabled()`（`:948`）全仓无调用点，底栏按钮液态玻璃也无渲染效果。两项都只做到「可配 + 落库」。

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
5. ~~顶栏的像素级视觉未取证~~ —— **2026-11-01 r299 已补齐五组**：`titleBarMode` 四档顶栏文字带各不相同（行投影区间见 r299 节）、胶囊 vs 非胶囊 changed px=242055、紧凑 changed px=2721（bbox `x187-1156 y59-280`）、图标样式三档 0→1 changed px=30656 / 1→2 changed px=29947、底色随透明度见 KI-E2 条。**仍未取证**：合并按钮的胶囊容器。详见 `docs/VALIDATION.md` 的 r299 节。

**验收**：`assembleHap` BUILD SUCCESSFUL（两次：39 s 738 ms / 21 s 843 ms，无 ERROR）；设备实测（`127.0.0.1:5555`，API 26）：开「标题栏胶囊」后「标题栏模式」整行消失、关闭后恢复（两个方向都做了 `dumpLayout` 对照）；八项逐项拨动后退出设置页重进 + `aa force-stop` 重启应用，值全部跨进程保持；「标题栏模式」弹层四项文案与上游中文串一致。详见 [VALIDATION](VALIDATION.md) 的 2026-10-31 KI-E5 节。

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
2. `readBarStyleFollowPage` 只落库不上屏，靠 `ReaderPage.ets:1023 readerMenuBaseColor()` 的 `@Prop` 响应式重算等价实现。**2026-11-01 r299 已补像素级取证**：`readBarStyle=1` + `bgStrNight=#1E88E5` 下顶栏主色 `(31,136,230)` 与正文主色 `(30,135,228)` 几乎同色；改 `readBarStyle=2` + `readMenuBgColorNight=#FF0000` 后顶栏变 `(202,34,57)` 而正文保持 `(30,135,228)`，两种底色来源的差异是决定性的。
3. `moreActionsConfig` 的运行时真源仍是本地独立仓储 `ReaderMoreActionsRepository`（prefs `legado_reader_more_actions`，23 项，比上游 28 项少 `source_login`/`source_pay`/`edit_source`/`disable_source`/`ai_chat` 五项，与「在线书源 / AI」范围外一致），快照字段是它的备份投影，两者靠 `Index` 的双向编解码保持一致。
4. 上游 `parseMoreActions` 的「未出现的项补 `true`」语义本地照抄；但本地默认池只有 23 项，备份串里若出现本地不认识的 id 会被 `decodeMoreActions` 过滤掉。

**验收**

`assembleHap` 两次 BUILD SUCCESSFUL（53 s 447 ms / 35 s 399 ms），无 ERROR。设备实测（HOS 模拟器 `127.0.0.1:5555`，API 26）：改一次阅读设置触发保存后，偏好文件出现 `<double key="readMenuLensRadius" value="24.000000"/>`、`<bool key="readBarStyleFollowPage" value="false"/>`、`<string key="moreActionsConfig">source_custom_button,true;change_source,true;…</string>`（23 项，全部 `,true`），`aa force-stop` 重启后不变；面板无这三项。详见 [验证记录](VALIDATION.md)。

### B 页眉页脚

B 块唯一的 `未接` 行（页眉/页脚独立字体）已于 2026-10-31 复核改判 `已接`：排版设置面板的字体目标四按钮可选「页眉」「页脚」并落 `headerFont`/`footerFont`。**残留问题**：页眉页脚 tab 里那条「选择字体」（`ReaderSettingsPage.ets:799-801`）仍走 `showNotMigrated('页眉/页脚字体选择')`，是重复的占位入口，功能已由排版设置面板提供。补法：把该行改指向 `openFontSelection()` 并带 `fontTarget: 'header'`，属一行改动，本轮不动。

## 深色模式行登记（ZIP-THEME.md 的未接行）

本节登记 [深色模式对照表](parity/ZIP-THEME.md) A–F 块里 **83 行 `未接`**（r316 后剩 6 行，见下「排期分布」）的「接不接、怎么接」。编号 `KI-TH-<块><组>` 与对照表「备注」列的 `**要接**` / `**不接**` 标记一一对应，组内逐行列出覆盖的对照表行。**本节只登记，除阶段一（r300）已落地者外不改 `.ets` 代码。**

判定口径按[项目范围](PROJECT.md)「范围之外」段：在线书源抓取、RSS、TTS、WebDAV、AI、云同步与**额外设备形态适配**不因开关已上屏而算已实现；上游没有的行为不补；上游机制在本平台根本不存在的不照抄。判「不接」的**不删行、不改状态**，对照表里仍按 `未接` 计，只在备注与本节点明理由。

**与对照表状态的关系**：对照表状态只有 `已接 / 未接 / 不适用` 三值，不设「部分接」。本节的 `要接` 是排期结论，`不接` 是范围结论，两者都不改变对照表的 `未接` 状态——只有真正落地并验证过才改 `已接`。

**83 行的排期分布**：阶段一 6 行（F1/F2/F3/F4 + A1/C4/D2）、阶段二 61 行、阶段三 16 行；`不接` 5 行。**阶段一已于 r300 全部落地**（7 行转 `已接`：A1/C4/D2/F1/F2/F3/F4）；**阶段二第一批 r301 落地护眼 6 行 + F7**（A24/A25/A26/A27/A28/A29/F7）；**阶段三 r302 落地 E 块 6 行 + D7**（E1/E2/E3/E4/E5/E6/D7）；**阶段二备份侧 r303 落地 3 行**（F9 `themeMode` 的 config.xml 写出与恢复读回、F11 两类忽略开关接真实效果、F12 恢复侧键过滤——F12 由「未接」改判「已接」，理由见 KI-TH-F3）；**阶段二外观三项 r304 落地 3 行**（A11 字体大小缩放、A15 显示状态栏、A16 启用滑动时动画）；**向导 r305 落地 2 行**（C1 向导第 4 页深色模式点选即写全局并立刻换肤、C2 向导调色板选择落盘 `paletteIndex`）；**r306 复查改判 3 行**（D3 三值派生布尔、D5 日夜两套背景、D8 阅读菜单日夜配色——三行在 r297 判 `未接` 时点早于实现，D3/D5 随 r300 的全局 `themeMode` 派生成立，D8 由 `9902eb8`/`154f91e` 落地配色后又随 r300 打通日夜来源）。**书籍详情页 r307 落地 3 行**（A20 界面颜色跟随封面取色、A21 网络封面背景设置、A22 默认封面背景设置），同批把 A23 作者搜索回退由「要接」改判「不接」（上游唯一消费者依赖书源 `relatedBooks`，本地无网络书源）。**容器设置 r308 落地 16 行**（A32 容器背景图总开关、A33 大容器背景图片、A34 项目背景图片、A35 容器背景不透明度、A36 关闭设置分组圆角、A37 覆盖卡片圆角总开关、A38 卡片圆角数值、A39 覆盖卡片边框总开关、A40 边框宽度、A41 日间边框颜色、A42 夜间边框颜色、A43 显示分隔线、A44 分隔线宽度、A45 分隔线长度、A46 分隔线颜色、A47 恢复默认主题配置）。**纯黑 r309 落地 1 行**（A4 纯黑深色模式：`ThemeSnapshot.pureBlack` + `Index.ets` 的 `selectThemePureBlack()` 与 `AppStorage` 广播 `themePureBlack`（条件 `isDark && pureBlack`）+ 60 个 struct 的 `@StorageProp` 把 `theme_surface_primary`/`tertiary`/`elevated` 压成 `#000000`/`#0A0A0A`/`#121212`）。**背景图片 r310 落地 1 行**（A13 全 App 背景图片：`ThemeSnapshot` 四个字段 `backgroundImage`/`backgroundImageNight`/`backgroundImageBlurring`/`backgroundImageNightBlurring`、`Index.ets` 的 `pickThemeBackgroundImage()` 选图复制进 `files/theme-backgrounds/` 与 `appBackgroundSource()`/`appBackgroundBlur()`、根 `Stack` 首子节点的 `Image(...).objectFit(ImageFit.Cover).blur(...)`、30 个页面/组件文件 208 处页面底色在「有背景图时透明」的让位改造）。**导航与转场 r311 落地 3 行**（A9 预见性返回手势仅落盘、A10 阅读界面共享元素动画用 `TransitionEffect` 近似、A14 首页与导航设置）。**顶栏底栏与模糊 r312 落地 3 行**（A17 顶栏与底栏 13 键——新增 `data/TopBottomBarSettings.ets` 做归一与底色合成、`Index.ets` 的 `publishTopBottomBarStyle()` 广播五个键、底栏按 `showBottomView`/`useFloatingBottomBar` 动态渲染、顶栏底色由 `components/CollapsingSettingsHeader.ets` 与三处内联 header 消费；A30 启用控件模糊用 ArkUI `backdropBlur` 近似；A31 启用渐变模糊落盘，ArkUI 无 `HazeProgressive.verticalGradient` 等价物）。**字体设置 r313 落地 1 行**（A5：新增 `data/AppFontSettings.ets`，`ThemeSnapshot` 加 `appFontPath` 第 54 字段，`Index.ets` 的 `pickThemeAppFont()`/`clearThemeAppFont()`/`pruneThemeAppFonts()`/`applyThemeAppFont()` 走 `UIContext.getFont().registerFont` + `ApplicationContext.setFont`，设置页字体行改可展开组），同批把 A8 切换图标由「要接」改判「不适用」（HarmonyOS 无运行时改启动图标 API）。**主题配色 r314 落地 1 行**（A2：新建 `data/ThemePalette.ets` 承载上游 14 套配色 × 日/夜各 8 个语义色位，`pages/ThemeSettingsPage.ets` 三个取色函数查表、`ThemePaletteItem` 改成上下两半圆 + 中心圆点 + 选中 2dp 边框、调色板行改横向 `Scroll` 容纳 14 项，`pages/OnboardingPage.ets` 共用同一份数据，`pages/Index.ets:2824` 在 `applyThemeMode` 里调 `applyPalette`，8 个 `theme_*` 资源的 1102 处引用改成 422 个 `@StorageProp('themeColor*')` 订阅 AppStorage 广播）。**自定义主题配色 r315 落地 1 行**（A6：新建 `data/CustomThemeColors.ets` 承载 `CustomThemeSnapshot` 与上游三张取值表、`buildCustomPaletteColors` 把 6 个手选色位映射到本地 8 个语义色位、`resolveCustomColorSet` 夜间回落日间、`resolveCustomPaletteColors` 种子色全空时返回 `undefined` 交回调色板表；新建 `pages/CustomThemePage.ets`（开关取反控制深度个性化，开则「白天」「夜间」各 6 行、关则日夜两个种子色 + 三个下拉）；`pages/ThemeSettingsPage.ets` 在 `paletteIndex === 12` 时显示「自定义颜色」入口；`pages/Index.ets` 的 `applyThemeMode` 在 12 号主题下改走 `applyThemeColors`；`ThemeSnapshot` 加 `customTheme` 单键存 JSON）。**主题包管理 r316 落地 14 行**（A12 主题包管理入口 + B1–B12 主题包管理 12 行 + F5 `themeConfig.json` 导出）：新建 `data/ThemePackageRepository.ets`（1159 行，清单/落盘/打包/解包/资产/迁移）、`pages/ThemeManagePage.ets`（五个入口 + 已存主题四动作 + 底部命名面板）、`data/ThemeConfigStore.ets`（`themeConfig.json` 读写与 `MD3-Day`/`MD3-Night` 生成）；`pages/ThemeSettingsPage.ets` 的「主题管理」改真入口、`ProfileRoute` 加 `APP_THEME_MANAGE`、`BackupRepository.createBackup` 补 `themeConfig.json` 写出与恢复解析。累计 75 行转 `已接`、4 行判 `不适用`，剩余 **6 行 `未接`**（全部不接）。

**全局前置**：这 83 行里 **78 行都要先有 F4（两套颜色资源）**才可能「看起来变了」。F4 没落地时，任何开关即使接了状态，界面也不会有可见变化——这是本表与其它对照表最大的不同，排期不能按「先接开关、后补皮肤」的顺序做。

### A 主题设置页

**A 块共同前提**：本地 `pages/ThemeSettingsPage.ets`（333 行）**整页零持久化**——`grep preferences|getPreferences|store.put|Repository` 命中 0；除 A1 的 `selectedMode`、A2 的 `selectedPalette`、A4 的 `pureBlack`、A11 的 `fontScalePreview`、A30 的 `blurEnabled`、A32 的 `containerBackgroundEnabled`、A37 的 `overrideCardCornerRadius`、A39 的 `overrideCardBorder`、A43 的 `dividerEnabled` 这 9 个纯 `@State` 外，**其余 39 处一律 `onUnavailableAction`**（`:1274-1276` 打开 sheet 写「…尚未迁移」）。因此 A 块的补法不是「逐行改开关」，而是**先建一个主题配置仓库 + 全局状态，再让这 47 行共用它**。

**KI-TH-A1 深色模式三选一与主题配色（A1 已实现 r300、A2 已实现 r314、A6 已实现 r315）** —— 覆盖 A1 深色模式三选一、A2 主题配色选择、A6 自定义主题配色（12 号主题）。三行全部落地，本组无剩余工作。

**A1 已实现（r300）**：`pages/ThemeSettingsPage.ets` 删掉 `@State selectedMode`，改 `@Prop themeMode: string` + `onThemeModeChange(themeMode: string)`；三个 `ThemeModeItem` 的 `selected` 用 `this.themeMode === '0'/'1'/'2'`、`onSelect` 回调对应三值字符串。写入路径在 `pages/Index.ets` 的 `selectThemeMode` → `applyThemeMode(context, themeMode, paletteIndex, persist)`：写 `@State themeMode` + `ThemeSettingsRepository.save`（preference 名 `legado_theme`）+ `ThemeModeResolver.apply`（`ApplicationContext.setColorMode`）。验收已过：点「深色」全 App 立刻变深、杀进程重进仍深、`legado_theme` 里 `themeMode = "2"`。

**上游口径**：`ThemeConfigScreen.kt:187-198` `DropdownListSettingItem(title = theme_mode, displayEntries = R.array.theme_mode, entryValues = R.array.theme_mode_v)` → `SetThemeMode`；`:212` `DropdownListSettingItem(theme)` → `SelectTheme`；非 Miuix 引擎时 `:222-229` 换成 `ThemeModeSelector` + `:231-250` `ThemeColorSelector`（`visibleThemes` 按 `showEInkTheme` 过滤掉 `"4"`，并分别传 `customLightSeedColor = theme.customPrimary` / `customNightSeedColor = theme.customNightPrimary`）。

**本地现状**：**A2 已在 r314 落地**。新建 `entry/src/main/ets/data/ThemePalette.ets`（261 行）：`ThemePaletteColors` 10 个字段（8 个换肤色位 `primary`/`onSurface`/`onSurfaceVariant`/`outline`/`surface`/`surfaceContainerLow`/`surfaceContainer`/`surfaceContainerHigh`，外加 2 个只供调色板色块预览的 `secondary`/`tertiary`）、`ThemePaletteDefinition`、`THEME_PALETTE_MIN = 0`/`THEME_PALETTE_MAX = 13`、`DEFAULT_LIGHT`/`DEFAULT_DARK`（= base/dark `color.json` 现值，供「动态取色」与「自定义」两项回落）、`THEME_PALETTES` 14 套（中文名逐条对齐 `values-zh-rCN/arrays.xml:160-175`，色值由上游 12 个 `ui/theme/colorScheme/*ColorScheme.kt` 抽取 8 个语义位）、`normalizePaletteIndex`、`themePaletteName`、`resolvePaletteColors`、`publishPaletteColors`、`applyPalette`。`pages/ThemeSettingsPage.ets` 的 `paletteColor`/`paletteArcColor`/`paletteCenterColor` 三个函数查表取色，`ThemePaletteItem` 重写为上下两半圆拼圆 + 中心 `primary` 圆点 + 选中 34dp 圆与 ✓，调色板行由 `Row(){ForEach([0..4])}` 改横向 `Scroll` 容纳全部 14 项（对齐上游 `LazyRow`）。`pages/OnboardingPage.ets` 共用同一份 `THEME_PALETTES`。`pages/Index.ets:2824` 在 `applyThemeMode` 里调 `applyPalette(context, normalizePaletteIndex(paletteIndex), themeMode)`，日夜切换与点选调色板走同一条路径。8 个 `theme_*` 颜色资源的 1102 处引用（36 文件 / 155 struct）由 `$r('app.color.theme_*')` 改成 422 个 `@StorageProp('themeColor*')` 订阅 AppStorage 广播（键名按资源映射：`primary`→`themeColorAccent`、`onSurface`→`themeColorTextPrimary`、`onSurfaceVariant`→`themeColorTextSecondary`、`outline`→`themeColorTextTertiary`、`surface`→`themeColorSurfacePrimary`、`surfaceContainerLow`→`themeColorSurfaceSecondary`、`surfaceContainer`→`themeColorSurfaceTertiary`、`surfaceContainerHigh`→`themeColorSurfaceElevated`）。`data/ThemeSettingsRepository.ets` 读写两侧的 `Math.max(0, Math.min(4, ...))` 换成 `THEME_PALETTE_MIN/MAX`。**A6 已在 r315 落地**：新建 `entry/src/main/ets/data/CustomThemeColors.ets`——`CustomThemeColorSet`（`primary`/`secondary`/`primaryText`/`secondaryText`/`background`/`labelContainer`，空串 = 未设置，对应上游 Int 0）、`CustomThemeSnapshot`（`enableDeepPersonalization`/`paletteStyle`/`customContrast`/`materialVersion`/`seedColorDay`/`seedColorNight`/`day`/`night`）、上游三张取值表 `CUSTOM_PALETTE_STYLES`（9 项 `tonalSpot`…`content`）/`CUSTOM_CONTRASTS`（`Default`/`Medium`/`High`）/`CUSTOM_MATERIAL_VERSIONS`（`material3`/`material3Expressive`）、`SLOT_FALLBACK`（= 上游 `AppTheme.kt:110-121` 的 `#6750A4`/`#625B71`/`#1C1B1F`/`#49454F`/`#FEF7FF`/`#F7F2FA`）、`CUSTOM_OUTLINE = '#79747E'`，以及 `normalizeCustomColor`/`defaultCustomThemeSnapshot`/`normalizeCustomThemeSnapshot`/`resolveCustomColorSet`/`hasCustomColor`/`buildCustomPaletteColors`/`resolveCustomPaletteColors`。`data/ThemePalette.ets` 加 `applyThemeColors(context, index, themeMode, customColors)`（有自定义色优先，否则回落 `resolvePaletteColors`）。`data/ThemeSettingsRepository.ets` 的 `ThemeSnapshot` 加 `customTheme` 字段（上游 16 个平铺键合成单键存 JSON），新增 `parseCustomThemeSnapshot(raw)` 对空串/坏 JSON/非对象一律回落默认。新建 `pages/CustomThemePage.ets`（`CollapsingSettingsHeader` + 分组卡片，`@State editingSlot` 用 -1/0..5/6..11/12/13 区分关闭/日间六项/夜间六项/两个种子色，底部固定「选择颜色」面板含「重置」「保存」+ 48dp 预览块 + hex `TextInput`）。`pages/ThemeSettingsPage.ets` 在 `paletteIndex === 12` 时于「主题风格」之前插入「自定义颜色」行（对齐上游 `ThemeConfigScreen.kt:266-270`），摘要由 `customColorSummary()` 生成；`model/Book.ets` 的 `ProfileRoute` 加 `APP_CUSTOM_THEME`；`pages/Index.ets` 加 `@State themeCustomColors`、`saveCustomTheme()`、`isProfileSettingsPage` 白名单与渲染分支，`applyThemeMode` 在 `normalizedIndex === 12` 时改走 `applyThemeColors(context, 12, themeMode, resolveCustomPaletteColors(...))`。A2 里「自定义」（12）与「动态取色」（0）两项的差别由此明确：12 号主题现在读用户自定义色，0 号仍是内置默认。

**补法**：**A2、A6 均无剩余工作**。与上游的差异已写进对照表——A2 三处（① 动态取色在本平台无对应能力，SDK 里 `dynamicColor`/`Monet` 零命中；② 换肤走 AppStorage 广播而非 Compose 的 CompositionLocal 重建 colorScheme；③ 上游 45 个 Material 色位本地只落 8 个），A6 三处（① 上游用 `ColorPickerSheet` 的 8×12 色环任意取色，本地 SDK 无 `ColorPicker` 组件，改成 hex 输入 + 预览块 + 重置 + 保存；② 上游种子色模式用 `CustomColorScheme` 做 HCT 生成整套 45 色位，ArkUI 无 HCT 生成器，本地只把种子色落到 `primary`、其余 7 位用调色板表兜底；③ 上游 16 个平铺 prefs 键本地合成单键 `customTheme` 存 JSON）。

**验收**：A2 已验（r314 真机：外观页调色板行横向滑动依次到全部 14 项「动态取色/草野/柠檬/黑白/电子书」→「黑白/电子书/晴空/八月/新浪潮」→「八月/新浪潮/春/千禧年/隐海修会」→「隐海修会/乐队/自定义/透明」；亮色 + 草野 → 页面底色 `(231,233,222)`、强调色 `(77,102,45)`；亮色 + 柠檬 → 页面底色 `(238,232,218)`；暗色 + 草野 → `(42,43,37)` / `(177,210,141)`；亮色 + 透明 → `(255,255,255)` / `(0,0,0)`，暗色 + 透明强调色 `(255,255,255)`；点色块前后整屏 changed px 798332；prefs `paletteIndex` 依次写为 `1`/`2`/`12`/`13`；杀进程重启后仍停在草野 + 深色）。A6 已验（r315 真机：外观页 `paletteIndex=12` 时出现「自定义颜色 / 用种子色生成整套配色」行 `[112,1739][392,1805]`；进入页面种子色模式渲染「使用色板生成颜色」开关 + 「种子色（日间）」「种子色（夜间）」「色板风格=柔和」「对比度=默认」「Material 版本=Material 3 (2021)」；种子色日间设 `#FF8800` → prefs `seedColorDay` 写入、行右侧显示 `#FF8800` + 橙色圆点；关开关后深度个性化开，出现「白天」「夜间」各 6 项；白天·主题色设 `#FF8800` 保存 → prefs `enableDeepPersonalization:true` 与 `day.primary:"#FF8800"`，整 App 立即换色（底色 `(254,247,255)`、强调色 `(255,131,0)`）；夜间·主题色设 `#00FF88` → 强调色变绿 `(2,255,136)`；白天·背景色设 `#FFCC00` → 整屏底色 `(255,204,1)`；杀进程重启后颜色保持；`paletteIndex=1` 时「自定义颜色」行消失且配色回到草野）。

**KI-TH-A2 Miuix 引擎两项（不接）** —— 覆盖 A3 Miuix 动态取色（Monet）、A7 主题引擎切换。

**判定理由**：`composeEngine` 是上游 Compose 侧的**全局渲染分支开关**，`ui/theme/LegadoTheme.kt` 暴露后被 30+ 处读取，决定用 Miuix 还是 Material 控件；`useMiuixMonet` 只在 `isMiuixEngine` 为真时出现（`ThemeConfigScreen.kt:199` 在 `:187` 的引擎分支内）。ArkUI 只有一套控件体系，**没有可切换的等价分支**，也没有引擎概念，因此这两行按「上游机制在本平台根本不存在」判不接。

**保留部分**：`composeEngine` 与 `useMiuixMonet` 两个键仍在 `data/BackupRepository.ets:261-277` 的 53 键组里，随 themeConfig 备份进出（F6 已接），只是没有界面。本地 `:138`「主题风格」这一行**不改成引擎切换**——文案与上游 `compose_engine` 语义不同，按文案对齐会错。

**验收**：无（不接）。备份里出现 `composeEngine` 键时原样保留、不报错。

**KI-TH-A3 纯黑深色模式（已实现 r309）** —— 覆盖 A4 纯黑深色模式（AMOLED）。

**上游口径**：键 `constant/PreferKey.kt:365 pure_black`、`domain/model/settings/ThemeSettings.kt:6 isPureBlack = false`、`data/repository/FeatureSettingsRepositories.kt:355/441` 读写；界面在 `ThemeConfigScreen.kt:255 SwitchSettingItem(pure_black)`（仅非 Miuix）。生效点是 `ui/theme/ThemeEngine.kt:132-146 applyAmoledIfNeeded(darkTheme, isAmoled)`：`if (!darkTheme || !isAmoled) return this`，否则 `copy(surface = Color.Black, background = Color.Black, surfaceContainerLow = Color(0xFF0A0A0A), surfaceContainer = Color(0xFF121212))`，调用点在 `:64`。`pure_black` **不在** `themePrefKeys` 53 键里，所以不进 `themeConfig.json` 备份。

**本地落地**：
1. `data/ThemeSettingsRepository.ets`：`ThemeSnapshot` 增加第 26 个字段 `pureBlack: boolean`，`load()` 读 `store.get('pureBlack', false)`、`save()` 写 `store.put('pureBlack', snapshot.pureBlack)`。
2. `pages/Index.ets`：`@State themePureBlack = false`；`restoreOnboarding()` 读回 `this.themePureBlack = theme.pureBlack`；`saveThemeSettings()` 带上该字段；`resetThemeDefaults()` 复位为 `false`；`publishThemeCardStyle()` 末尾 `AppStorage.setOrCreate('themePureBlack', isDark && this.themePureBlack)`——**条件与上游一致，浅色下即使开关为 true 也不生效**；新增 `selectThemePureBlack(context, enabled)`（写状态 → 广播 → 落盘，失败提示「纯黑模式设置保存失败，请重试」）。
3. `pages/ThemeSettingsPage.ets`：删掉 `@State pureBlack`，改 `@Prop pureBlack` + `onPureBlackChange`，`Toggle` 的 `.onChange` 调回调。
4. 60 个 struct 的 `@StorageProp('themePureBlack')`：把 `theme_surface_primary` 换成 `#000000`（对齐上游 `surface`/`background`）、`theme_surface_tertiary` 换成 `#0A0A0A`（对齐 `surfaceContainerLow`）、`theme_surface_elevated` 换成 `#121212`（对齐 `surfaceContainer`）。

**与上游的差异**：上游是整套 `ColorScheme.copy()`，本地没有 ColorScheme 令牌层，只压了三档底色（primary/tertiary/elevated）；`surfaceContainerHigh`/`Highest` 等本地未建令牌，故不参与。`Index` 里 `@StorageProp` 字段改名为 `themePureBlackActive`，避免与它自己的 `@State themePureBlack`（开关源）重名。

**验收**（r309，模拟器 127.0.0.1:5555 / API 26）：外观页打开「纯黑深色模式」→ `legado_theme` 的 `pureBlack` 变 `true`；深色下截图取色 `(20,400)=(0,0,0)`、`(640,1500)=(0,0,0)`，关掉后同点变 `(17,18,23)`；切回浅色重启同点 `(245,246,248)`（不生效）；再切深色重启同点回 `(0,0,0)`（持久化成立）。

**KI-TH-A4 外观杂项七项（A5 已实现 r313、A12 已实现 r316、A9/A10 已实现 r311、A11 已实现 r304、A13 已实现 r310、A8 改判不适用 / 本组无剩余）** —— 覆盖 A5 字体设置、A8 切换图标、A9 预见性返回手势、A10 阅读界面共享元素动画、A11 字体大小缩放、A12 主题包管理入口、A13 背景图片。

**上游口径**：A5 走 `fontFolderLauncher`（`OpenDocumentTree` → `SetFontFolder`）；A8 走 `navigationIconLauncher`（`GetContent` + MD5 命名落 `nav_icons/`）；A9/A10 是布尔键，分别驱动返回手势与阅读页转场；A11 `fontScale` 驱动全局字号；A12 是主题包管理页入口（B 块）；A13 `AppBackground.kt:22-29` 按日夜读 `backgroundImageDark`/`backgroundImageLight`/`backgroundImageDarkBlur` 等键。

**本地现状**：A12 仍是 `onUnavailableAction`。**A5 已在 r313 落地**：新增 `data/AppFontSettings.ets`（`APP_FONT_EXTENSIONS = ['.ttf', '.otf', '.ttc']`、`APP_FONT_FAMILY = 'LegadoAppFont'`、`normalizeAppFontPath`、`appFontDisplayName`）；`data/ThemeSettingsRepository.ets` 的 `ThemeSnapshot` 增加 `appFontPath`（第 54 字段）并在 `load()`/`save()` 里读写；`pages/Index.ets` 的 `pickThemeAppFont()` 用 `picker.DocumentViewPicker`（`fileSuffixFilters = ['字体|.ttf', '字体|.otf', '字体|.ttc']`）选文件后复制到 `${context.filesDir}/fonts/app_font_${Date.now()}${ext}`、`pruneThemeAppFonts()` 只保留当前副本（对齐上游 `pruneCopiedFonts()` 只删 `app_font` 前缀）、`applyThemeAppFont()` 走 `this.getUIContext().getFont().registerFont({ familyName: APP_FONT_FAMILY, familySrc: 'file://' + path })` + `context.getApplicationContext().setFont(APP_FONT_FAMILY)`，清空时 `setFont('')` 回落系统字体；`pages/ThemeSettingsPage.ets` 的「字体设置」由 `onUnavailableAction` 改为可展开组（行摘要显示文件名 / 「系统默认字体」，展开后「选择字体文件」+「恢复系统字体」）。**A8 在 r313 改判不适用**：见下「补法」。**A11 已在 r304 落地**：`pages/ThemeSettingsPage.ets` 的字体大小 Slider 改为读 `@Prop fontScale`、回调 `onFontScaleChange`；`pages/Index.ets` 的 `selectThemeFontScale()` 写 `themeFontScale` + `applyThemeFontScale()` + `saveThemeSettings()`；`applyThemeFontScale()` 调 `context.getApplicationContext().setFontSizeScale(this.themeFontScale / 10)`；`data/ThemeSettingsRepository.ets` 的 `ThemeSnapshot` 增加 `fontScale` 并在 `load()`/`save()` 里读写，`normalizeFontScale()` 夹到 8..16。

**A12 已在 r316 落地**：`pages/ThemeSettingsPage.ets:563` 的「主题管理」由 `onUnavailableAction('主题包管理尚未迁移')` 改成 `onOpenThemeManage()`，`pages/Index.ets` 的 `isProfileSettingsPage` 白名单加 `ProfileRoute.APP_THEME_MANAGE`，点进去是 r316 新建的 `pages/ThemeManagePage.ets`（详见 KI-TH-B1）。**A5 无剩余工作**（与上游一处差异：上游 `FontSelectSheet` 能列出私有目录里已导入的多个字体供二次选择，本地每次只能重新选文件——`DocumentViewPicker` 无法回读 `filesDir` 生成可点列表，已在对照表差异说明里记录）。**A8 判「不适用」的依据**：Android 靠 `AndroidManifest` 里预置多个 `<activity-alias>` + `PackageManager.setComponentEnabledSetting` 切换启用项；HarmonyOS NEXT 的 `module.json5` 只允许一个 `abilities` 图标，SDK 侧 `grep -rln "setAppIcon\|changeAppIcon\|updateAppIcon"` 在 `sdk/default/openharmony/ets/api` 下**零命中**；`@ohos.bundle.launcherBundleManager.d.ts` 只有 `getLauncherAbilityInfoSync`（只读），`@ohos.enterprise.applicationManager.d.ts` 只有 `addHideLauncherIcon`/`removeHideLauncherIcon`（需企业 MDM 的 `admin: Want`，普通应用不可用）。按「上游有、平台无」记平台缺项，保留入口文案与 `onUnavailableAction` 提示，不伪造效果。**A11 无剩余工作**。**A9 已在 r311 落地（仅落盘）**：`data/ThemeSettingsRepository.ets` 的 `ThemeSnapshot` 增加 `predictiveBack`（引 `AppShellSettings.kt:9`），`pages/ThemeSettingsPage.ets` 的「预见性返回手势」改为 `@Prop predictiveBack` + `onPredictiveBackChange`，`pages/Index.ets` 的 `selectThemePredictiveBack()` 写状态 + 落盘。**已核实 ArkUI 侧没有任何预测性返回能力**：SDK 里 `grep -rln "predictiveBack" --include=*.d.ts` **零命中**，上游 `BaseActivity.kt:111` 的 `registerOnBackInvokedCallback` 在本平台没有等价物，所以按「上游有、平台无」记为平台缺项，只保留开关落盘、不伪造效果。**A10 已在 r311 落地（近似）**：同构的 `readerSharedElement` 字段 + `pages/Index.ets` 的 `readerRouteTransition()`——关闭时只做 `TransitionEffect.OPACITY`（220ms 淡入淡出），打开时 `combine(TransitionEffect.scale({ x: 0.92, y: 0.92 }))`；ArkUI 的 `geometryTransition` 要求源与目标组件同时在场，而本地阅读页是整页 `if/else` 切换，做不到上游 Compose `SharedTransitionLayout` 那样的书封展开，故用缩放淡入近似并在对照表差异说明里如实标注。**A13 已在 r310 落地**：`data/ThemeSettingsRepository.ets` 的 `ThemeSnapshot` 增加 `backgroundImage`/`backgroundImageNight`/`backgroundImageBlurring`/`backgroundImageNightBlurring` 四字段（现 30 字段）与 `normalizeBackgroundBlur()`（夹 0..40）；`pages/ThemeSettingsPage.ets` 的「背景图片」行改为可展开组（日间背景图片 / 日间虚化滑块 / 夜间背景图片 / 夜间虚化滑块 / 移除背景图片）；`pages/Index.ets` 的 `pickThemeBackgroundImage()` 用 `picker.DocumentViewPicker` 选图并复制进 `files/theme-backgrounds/`（**必须保留原扩展名**，否则 `Image()` 解不出）、`selectThemeBackgroundBlur()`/`clearThemeBackgroundImage()` 落盘并广播、`appBackgroundSource()` 按 `ThemeModeResolver.isDarkTheme` 选日/夜路径、`appBackgroundBlur()` 取对应虚化度；渲染放在根 `Stack` 首子节点（`Image(...).objectFit(ImageFit.Cover).blur(...)`），与上游 `AppBackground.kt:17-48` 的「背景在下、内容在上」一致；另把 30 个页面/组件文件的 208 处页面底色包成「有背景图时 `Color.Transparent`」，否则各页不透明底色会把背景图整块盖住。**A13 无剩余工作**（上游的 `.9.png` 九宫格拉伸未做，已在对照表差异说明里记录）。

**验收**：A11 已验（r304：滑块拖到最右 → 全 App 文字 1.0x→1.6x，杀进程重进仍 1.6x，prefs `legado_theme` 的 `fontScale` = `16.000000`）；A5 已验（r313：外观页展开「字体设置」→「选择字体文件」→ 浏览 → 我的手机 → Documents → `font-test.ttf` → prefs `appFontPath` = `/data/storage/el2/base/haps/entry/files/fonts/app_font_1793536581141.ttf`、`files/fonts/` 下只剩这一个副本（前一次选的已被 prune）、行摘要变文件名、外观页英文字形变化（与关字体态 `ImageChops` changed 300873）；点「恢复系统字体」→ prefs `appFontPath` 置空、`files/fonts/` 被清空、字形回落）；A9 已验（r311：点「预见性返回手势」→ prefs `predictiveBack` = `false`，重启后开关仍为关；无预览动画，平台无该能力）；A10 已验（r311：点「阅读界面共享元素动画」→ prefs `readerSharedElement` = `false`，重启后开关仍为关；打开时进阅读页有 0.92 倍缩放淡入）。

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

**KI-TH-A7 护眼六项（已实现，r301）** —— 覆盖 A24 启用护眼模式、A25 深色模式时自动开启、A26 护眼色温强度、A27 护眼定时开启、A28 护眼开始时间、A29 护眼结束时间。

**本轮判定**：要接，已实现。

**上游口径**：`ui/book/read/EyeProtection.kt`（149 行）—— `MIN_FILTER_TEMPERATURE = 2596` / `MAX_FILTER_TEMPERATURE = 5500`（`:21-22`）、`matrixValuesForIntensity(intensity)`（`:36-50`，9 个二次拟合系数）、`Modifier.eyeProtectionColorFilter(enabled, intensity)`（`:99-117`）；`base/BaseComposeActivity.kt:89-104` 把 `rememberEyeProtectionActive(...)` 的结果套在 `Box(Modifier.fillMaxSize().eyeProtectionColorFilter(...))` 上包住整页 —— **是全 App 级，不只是阅读页**。

**本地落地**：

1. 新建 `entry/src/main/ets/data/EyeProtection.ets`，逐句移植上游：`temperatureForIntensity`、`matrixValuesForIntensity`（9 个系数原样照抄）、`parseTime`、`isActiveAt`（含跨零点分支）。额外加 `overlayColorForIntensity(intensity)` 把矩阵对角线转成覆盖色。
2. **渲染不是近似**：上游矩阵 `[red,0,0,0,0, 0,green,0,0,0, 0,0,blue,0,0, 0,0,0,1,0]` 除对角线外全 0，是纯对角矩阵；`.blendMode(BlendMode.MULTIPLY)` 的混合公式是 `result = 内容 × 覆盖色`，逐通道相乘与对角矩阵数学等价。所以在 `Index.ets:6784-6792` 的根 Stack 上叠一层同尺寸纯色覆盖层（`hitTestBehavior(HitTestMode.None)` + `expandSafeArea` 覆盖状态栏与手势条）即等价实现。**原先根节点的 `.sepia()` 已删除**。
3. 主题设置页六个控件（`ThemeSettingsPage.ets:180-199`）从死 UI 改为 `@Prop` + 回调，与阅读设置页共用 `Index.ets:407-412` 同一份状态，统一走 `setEyeProtection*` 写盘，不再有第二套。
4. `isEyeProtectionActive()` 改为调 `EyeProtection.isActiveAt`，「深色时自动开启」这一支由 `readerNightMode`（全局 `themeMode` 的投影）提供。

**验收**（r301 设备实测，见 [验证记录](VALIDATION.md)）：打开护眼 → 整屏泛暖，截图取色由 `(245,246,248)` 变 `(255,187,122)`，与上游系数算出的 `(255,187,121)` 一致；强度 50→97 暖色加深；只开「深色时自动开启」时浅色不生效、切深色即生效；定时 22:00–07:00 在 14:16 不生效（正确）；改成跨零点的 14:00–07:00 立即生效。

**KI-TH-A8 模糊两项（已实现 r312）** —— 覆盖 A30 启用控件模糊、A31 启用渐变模糊。

**上游口径**：`ThemeConfigScreen.kt:512` `SwitchSettingItem(is_blur_enable)` → `SetBlurEnabled`；`:518` `SwitchSettingItem(is_blur_progressive_enable)` 在 `AnimatedVisibility(enableBlur)` 内。渲染 `ui/theme/HazeStyle.kt:20-24` `responsiveHazeSource`（`if (LocalAppUiConfiguration.current.theme.enableBlur) Modifier.hazeSource(state)`）、`:26-70` `responsiveHazeEffect`（`if (!enableBlur) return this`；`HazeLegado.custom(containerColor, blurRadius, blurAlpha)` + `hazeBlur(input = HazeInput.Sources(state), style = …progressive(if (enableProgressiveBlur) HazeProgressive.verticalGradient(1f, 0f) else null))`）。`enableBlur` 被 `AppScaffold`/`GlassDefaults`/`BookshelfViewModel`/`HomepageModuleFeed` 等 6 处读取决定是否套 `hazeSource`。

**本地落地**（r312）：`data/TopBottomBarSettings.ets` 里 `resolveBarBackgroundColor` 在 `enableBlur` 时把底色压到 `blurAlpha` 再乘 `opacity`（对齐 `GlassDefaults.glassColor()` + `AppNavigationBar.kt:60`）；`pages/Index.ets` 的底栏 `Row()` 挂 `.backdropBlur(this.themeEnableBlur ? this.themeBottomBarBlurRadius : 0)`；`pages/ThemeSettingsPage.ets:696` 「启用控件模糊」与 `:699`「启用渐变模糊」（`if (this.enableBlur)` 内）改真回调，条件显示与上游一致；`components/CollapsingSettingsHeader.ets` 与三处内联 header 挂 `.backdropBlur(this.themeTopBarBlurRadius)`。

**与上游的差异**：① 上游 `hazeSource`/`hazeEffect` 是跨组件采样（顶栏采样下方滚动内容的模糊），ArkUI `backdropBlur` 只采样组件自身背后的内容，语义近似而非等价；② 上游 `enableBlur` 影响 6 处（含内容卡片），本地只作用于顶栏与底栏，内容卡片不模糊；③ A31 的 `HazeProgressive.verticalGradient` 在 ArkUI 无等价物（`backdropBlur` 不支持渐变梯度），本地只落盘并参与摘要文案，**不产生可见渐变**。

**验收**（r312 设备实测）：开「启用控件模糊」→ prefs `enableBlur=true`、出现「启用渐变模糊」行、顶栏组摘要变「模糊 24/8」；开/关对比 `ImageChops` bbox `(0,2511,1280,2832)`、changed 395714（底栏区域变化）；开「启用渐变模糊」→ prefs `enableProgressiveBlur=true`；关闭父开关后该行消失。

**KI-TH-A9 容器设置十五项（已实现 r308）** —— 覆盖 A32 容器背景图总开关、A33 大容器背景图片、A34 项目背景图片、A35 容器背景不透明度、A36 关闭设置分组圆角、A37 覆盖卡片圆角（总开关）、A38 卡片圆角数值、A39 覆盖卡片边框（总开关）、A40 边框宽度、A41 日间边框颜色、A42 夜间边框颜色、A43 显示分隔线、A44 分隔线宽度、A45 分隔线长度、A46 分隔线颜色。

**上游口径**（`ThemeConfigScreen.kt:532-735`）：`:532 SplicedColumnGroup(theme_manage_section_container)`；`:533-540` 容器背景图 Switch；`:541 AnimatedVisibility(enableContainerBackgroundImage)` 包 A33/A34；`:585 SliderSettingItem(container_opacity)`；`:598` 分组圆角；`:608` 覆盖卡片圆角总开关 + `:616-617` 数值；`:630` 覆盖卡片边框总开关 + `:638-663` 宽度与日/夜颜色；`:676` 分隔线开关 + `:683-707` 宽度/长度/颜色。**A41/A42 是整表里唯一成对出现「日间/夜间」两个颜色入口的地方**，是日夜双套在设置界面上的直接体现。

**本地落地**（r308，五个文件 + 一个新建组件 + 一张占位图）：
1. 新建 `entry/src/main/ets/data/ThemeCardStyle.ets`：`ThemeCardStyleSnapshot` 接口 + 四组归一函数（`normalizeContainerOpacity` / `normalizeCardCornerRadius` / `normalizeCardBorderWidth` / `normalizeDividerWidth` / `normalizeDividerLength`）+ 五个解析函数（`resolveCardCornerRadius` / `resolveCardBorderWidth` / `resolveCardBorderColor` / `resolveCardBackgroundColor` / `resolveDividerWidth` / `resolveDividerLength` / `resolveDividerColor`）。`resolveCardCornerRadius` 的三档优先级逐条照抄上游 `SplicedColumnGroup.kt:49-53`：`disable → 0`、`override → baseCardCornerRadius`、`else → 16`。
2. `entry/src/main/ets/data/ThemeSettingsRepository.ets`：`ThemeSnapshot` 从 8 字段扩到 **25 字段**（+8 卡片/边框 + 4 分隔线 + 5 容器背景图），`load()` / `save()` 逐键同步；新增 `export function normalizeThemeColor(value: string): string`（只放行 `#RRGGBB` / `#AARRGGBB`，空串表示上游的 `0`）。
3. `entry/src/main/ets/pages/Index.ets`：新增 17 个 `@State`；`saveThemeSettings()` 整份写全；新增 `themeCardStyleSnapshot()` 与 `publishThemeCardStyle()`——后者把解析结果写进 `AppStorage` 的九个键（`themeCardRadius` / `themeCardBorderWidth` / `themeCardBorderColor` / `themeCardBackground` / `themeDividerWidth` / `themeDividerLength` / `themeDividerColor` / `themeContainerBackground` / `themeItemBackground`），并在 `applyThemeMode()` 之后重发（日夜一变边框色要重选）；新增 12 个 `selectTheme*` 回调与 `resetThemeDefaults()`；`pickThemeContainerBackground(isLarge, isNight)` 用 `picker.DocumentViewPicker` 选图后复制到 `filesDir/theme-backgrounds/`（**保留原扩展名**）。
4. `entry/src/main/ets/pages/ThemeSettingsPage.ets`：15 个控件全部从 `onUnavailableAction` 改为真回调；容器不透明度/卡片圆角/边框宽度/分隔线宽度/分隔线长度五条改用 `ThemeSettingsSlider`；日间边框色/夜间边框色/分隔线颜色三条改用 `ThemeSettingsDropdown`（七档预设，空串 = 「默认描边色」）。
5. 新建 `entry/src/main/ets/components/ThemeItemDivider.ets`：读 `@StorageProp('themeDividerWidth'/'themeDividerLength'/'themeDividerColor')`，`width > 0` 才画；圆角取 `width / 2` 对齐上游 `clip(CircleShape)`。已插入 `ThemeSettingsPage.ets` 27 处、`AppBackupSettingsPage.ets` 14 处、`AppReadAloudSettingsPage.ets` 12 处、`ProfileSubPages.ets` 12 处。
6. 24 个设置分组卡片统一改为 `.backgroundColor(this.themeCardBackground.length > 0 ? this.themeCardBackground : $r('app.color.theme_surface_secondary')).borderRadius(this.themeCardRadius).border({ width: this.themeCardBorderWidth, color: this.themeCardBorderColor })`；容器背景图（Large）挂这 24 张卡，项目背景图（Item）挂 `HomePage`/`ProfilePage`/`BookshelfPage`/`DiscoverPage`/`SearchPage`/`SubscriptionPage`/`SubscriptionSubPages` 的内容卡；`@StorageProp` 必须落在**使用它的那个 struct** 上（否则 ArkTS 报 `Property 'themeItemBackground' does not exist on type '...'`）。
7. 新建 `entry/src/main/resources/base/media/transparent_pixel.png`（1×1 透明 PNG）作 `.backgroundImage()` 的「无背景图」占位。

**与上游的差异**：① A41/A42/A46 上游用 `ColorPickerSheet` 任意取色 + 「重置」置透明，本地只有七档预设下拉，任意取色器留到 B 块一起做；② 容器背景图上游按 `appColumnBackgroundOpacity` / `glassCardBackgroundOpacity` 两套 alpha，本地统一由 A35 的 `containerOpacity` 驱动；③ 容器不透明度在无背景图时退化成「卡片底色透明度」，方向一致但不是同一层；④ 分隔线只在 4 个文件的卡片里插了，`@BuilderParam` 外壳型卡片（`AppAiSettingsPage` 等 7 个）子项在调用方，本轮未插。

**验收**（模拟器 127.0.0.1:5555 / API 26，全部通过）：A32 开关 → prefs `enableContainerBackgroundImage=true` 且放出两行；A33 选图 → prefs 写入沙箱路径、`files/theme-backgrounds/large-day-*.jpg` 出现；A34 同图 → 首页开关前后 changed pixels 1522253；A35 拖到 28% → prefs `containerOpacity=28.000000`、卡片区域 `(251.5,251.5,251.5)`→`(245.1,246.0,247.9)`；A36 打开 → changed pixels 203123、分组变直角；A37/A38 → `baseCardCornerRadius=40.000000`、角落像素由白变底色；A39/A40 → `baseCardBorderWidth=5.000000`；A41/A42 → 日/夜边框色分别写入；A43 → `enableItemDivider=true` 且设置首页 10 个分类间全部带线；A44/A45/A46 → `itemDividerWidth=5`、`itemDividerLength=51`、`itemDividerColor=#3F5BD9`。

**KI-TH-A10 恢复默认主题配置（已实现 r308）** —— 覆盖 A47。

**上游口径**：`ThemeConfigScreen.kt:737` `ClickableSettingItem(theme_config_reset_defaults)` + `:752 AppAlertDialog(ResetDefaults)`；`ThemeConfigViewModel.kt:205-240 resetDefaults()` 先删 6 张背景图文件（限 `appCtx.externalFiles` 内）+ 清 `filesDir/nav_icons` + 删 `appFontPath`，再 `appShellSettingsGateway.update { AppShellSettings() }` + `coverSettingsGateway.update { CoverSettings() }` + `themeSettingsGateway.update { ThemeSettings() }`，emit `ApplyDayNight` / `NotifyMain` / `ChangeLauncherIcon` / `ShowToast(theme_config_reset_success)`。文案 `values-zh-rCN/strings.xml:1776-1778`。

**本地落地**：`pages/ThemeSettingsPage.ets` 新增 `confirmResetDefaults()` 用 `this.getUIContext().showAlertDialog(...)`，标题「恢复默认主题配置」、正文「将恢复外观页中的主题、界面布局、背景图片、应用字体和导航图标等配置。已保存的主题、封面图集和书籍封面不会被删除。」逐字对齐上游；确认按钮回调 `onResetDefaults` → `pages/Index.ets` 的 `resetThemeDefaults()`，把 25 字段快照 + 字号 + 状态栏 + 滑动动画 + 三个书籍详情页项复位，再 `applyThemeFontScale` / `applyThemeStatusBar` / `publishThemeCardStyle` / `saveThemeSettings`，成功提示「已恢复默认主题配置」。

**与上游的差异**：上游会**删掉**沙箱里的背景图文件与导航图标目录；本地只把路径清空、不删文件（文件留在 `files/theme-backgrounds/` 不再被引用）。本地没有导航图标与自定义字体这两块，故无对应删除动作。

**验收**（模拟器 127.0.0.1:5555 / API 26，通过）：先把容器不透明度、卡片圆角、两个边框色、分隔线四项都改掉，再点「恢复默认主题配置」→ 弹确认框（取消 `(306,1599)` / 恢复 `(862,1599)`）→ 点「恢复」→ prefs 全部回默认：`overrideBaseCardBorder=false`、`overrideBaseCardCornerRadius=false`、`baseCardCornerRadius=16.000000`、`baseCardBorderWidth=1.000000`、两个边框色空串、`containerOpacity=100.000000`、`disableSplicedColumnGroupCornerRadius=false`。

### B 主题包管理

**B 块整体判定：12 行已在 r316 全部落地（`已接`）。** r316 之前本地没有主题包这个概念——`pages/ThemeSettingsPage.ets:563` 的「主题管理」是 `onUnavailableAction('主题包管理尚未迁移')`，入口文案在、页面不在。上游是三份文件：`help/config/ThemePackageManager.kt`（1254 行）、`help/config/ThemeImportExport.kt`（393 行）、`ui/config/themeManage/EditThemeSheet.kt`（403 行），加列表页 `ThemeManageScreen.kt`（331 行）。r316 新建了一整页 + 一套包格式，逐行落地情况见下三节。

**KI-TH-B1 主题包管理页与保存/导出/导入（已实现，r316）** —— 覆盖 B1 保存当前配置为主题、B2 导出当前主题为文件、B3 导入主题包（zip）、B4 导入旧版 JSON 主题、B5 迁移旧版已存主题、B6 已存主题列表与搜索。

**上游口径**：`ThemeManageScreen.kt:85-117` 五个 `ClickableSettingItem` —— 保存（`OpenSaveDialog`）、导出（`RequestExport`）、导入包（`RequestImportPackage`）、导入旧版 JSON（`RequestImportLegacyJson`）、迁移旧版（`MigrateLegacyThemes`，仅 `hasLegacyThemes` 时出现）；`:120-150` 已存主题列表（`:122-129 SearchBar`、`:141-149 SavedThemeItem` 四动作）；三个对话框 `:155`/`:184`/`:204`。B4 含**混淆版 v1** 兼容分支（`parseObfuscatedThemeV1`）。

**本地现状（r316）**：新建 `pages/ThemeManagePage.ets` 承载五个入口 + 已存主题列表 + 底部命名面板，`data/ThemePackageRepository.ets` 承载清单/落盘/打包/解包/资产/迁移。B1 命名用页面底部固定输入面板（ArkUI `showAlertDialog` 不能带输入框）；B2/B9 复用 `saveZipToUser`；B3 `importPackage` 解包后校验 4096 条目 / 单文件 64 MB / 总计 512 MB 与防路径穿越；B4 `importLegacyJson` 先把 `file://` uri `copyFileSync` 到 `cacheDir/theme-package-work` 再读（`fileIo.readTextSync` 只认沙箱路径）；B5 `hasLegacySavedThemes` 扫 `saved_themes/*.json`，有才显示入口；B6 列表用 `TextInput` 做搜索框。

**与上游的差异**：① 资产只认本地有对应功能的 7 类（上游 17 类，缺 10 个导航图标与封面图集，导入时计数提示「N 个本地不支持的资源已忽略」）；② B4 不实现混淆版 v1 JSON（`parseObfuscatedThemeV1`，本地从未发布过该格式）；③ 便携配置的调色板字段沿用上游名 `appTheme`，不是 `paletteIndex`。

**验收（r316 真机）**：保存当前设置 → 列表出现「我的主题」且 `saved_themes/theme_%E6%88%91%E7%9A%84%E4%B8%BB%E9%A2%98/manifest.json` 落盘；导出当前主题 → zip 内 `manifest.json` + `assets/container/item/light.jpg` + `assets/container/large/light.jpg` 层级正确；导入主题包（`config.appTheme='3'`）→ prefs `paletteIndex=3`、`themeMode=1`、`fontScale=10`，界面立刻换黑白浅色；导入旧版 JSON → prefs `paletteIndex=2`、`topBarButtonStyle=plain`，换柠檬配色；搜索框输入「NewTheme 2」→ 列表只剩一项。

**KI-TH-B2 已存主题的四动作（已实现，r316）** —— 覆盖 B7 应用已存主题、B8 编辑已存主题、B9 导出已存主题、B10 删除已存主题。

**上游口径**：列表项 `onApply`/`onEdit`/`onExport`/`onDelete`；B7 应用前 `prepareForApply` 把资产拷到可读位置再重建主题；B8 是 `EditThemeSheet.kt`（403 行），**日间 6 色与夜间 6 色并列编辑**，是「日夜两套」最完整的体现；B10 带确认框。

**本地现状（r316）**：B7 走 `confirmApply`/`applySaved` → `Index.applyThemePackage()` 逐字段覆盖主题 `@State` 后重跑 `applyThemeMode(..., persist=true)`；B8 走 `promptRename`/`commitRename`（写新目录 → 删旧目录，中途失败旧主题还在）；B9 走 `exportSaved()` 复用 `saveZipToUser`；B10 走 `confirmDelete`/`deleteSaved()` 整目录递归删除。

**与上游的差异**：B8 本地**只改名、不改色位**。上游 `EditThemeSheet.kt`（403 行）是完整编辑器（改名 + 4 个下拉 + 日/夜各 6 个颜色位 + 两个种子色 + 布局组开关）；本地颜色位的编辑已有一套 `pages/CustomThemePage.ets`，在主题包层再复制一份会让色位 UI 分叉，所以编辑路径是「先应用主题 → 进外观页的自定义颜色页」。

**验收（r316 真机）**：点「应用」→ 确认框「确定应用主题「我的主题」？应用后需要重启才能完全生效。」→ prefs `paletteIndex` 由 3 回到存盘时的 1；点「编辑」→ 改名 `NewTheme` → 目录变 `theme_…%20NewTheme`、列表显示「我的主题 NewTheme」；点「导出」→ 保存对话框预填「我的主题 NewTheme.zip」；点「删除」→ 确认框 → `saved_themes/` 清空、页面回到空态提示。

**KI-TH-B3 主题包格式与资产（已实现，r316）** —— 覆盖 B11 主题包内嵌资产打包与还原、B12 主题包目录结构与清单。

**上游口径**：`ThemeImportExport.kt` 定义包结构（manifest + 配置 + 背景图/封面/字体等内嵌资产），导出时打包、导入时解包并还原资产。

**本地现状（r316）**：目录约定 `files/saved_themes/theme_<URLEncoder(名)>/` + `manifest.json`（`formatVersion` + `name` + `config` + `assets`）+ `assets/…`，与上游 `savedThemeDir`/`writeSavedManifest`/`readSavedThemeFolder` 同构；写入走「先写 `.tmp` 目录再 `renameSync`」，重名走 `uniqueSavedThemeName` 追加「 2」「 3」。资产 key 7 个：`background.light`/`background.dark`/`container.large.light`/`container.large.dark`/`container.item.light`/`container.item.dark`/`font.app`。

**踩到并修掉的两个坑**：① `zlib.compressFiles(files, zipPath, {})` 会把每个文件平铺到 zip 根，`assets/container/item/light.jpg` 与 `assets/container/large/light.jpg` 都变成 `light.jpg` 互相覆盖，改用 `zlib.compressFile(directory, zipPath, {})` 压整个目录才保留层级；② 导入后没有存成已存主题，补 `applyImport()` 里应用之后再 `saveTheme(context, uniqueSavedThemeName(...), provideSource())`，对齐上游 `ThemePackageManager.kt:848 saveImportedTheme`。

**验收（r316 真机）**：导出后解压 zip 见 `manifest.json 1861` / `assets/container/item/light.jpg 130586` / `assets/container/large/light.jpg 130586`；换数据导入后 prefs 的 `itemBackgroundImageLight`/`largeContainerBackgroundImageLight` 指向 `files/theme-package-assets/<时间戳>/…`，且 `saved_themes/` 多出一条「导入的主题」。

### C 首次启动向导

**KI-TH-C1 向导的三处选择已全部落到全局（C1/C2 已实现 r305，C4 已实现 r300）** —— 覆盖 C1 向导第 4 页深色模式三选一、C2 向导调色板选择、C4 启动时读取并应用已保存的 themeMode。

**本轮判定**：三行全部 `已接`。C1/C2 在 r305 落地——向导页内点选即写全局并立刻换肤，不再等「完成」。

**上游口径**：`feature/onboarding/OnboardingScreen.kt:339-357` 第 4 页 `ThemeModeSelector` + `ThemeColorSelector`（配色数据 `R.array.themes_item`，`values-zh-rCN/arrays.xml:160-177` 共 14 套完整 `lightColorScheme`/`darkColorScheme`）；`OnboardingViewModel.kt:120-123` `SetThemeMode` 立即 `appShellSettingsGateway.update { it.copy(themeMode = intent.value) }` 并发出 `ApplyDayNight` effect；`:47` 向导初值直接取 `appShellSettingsGateway.currentSettings.themeMode`。

**本地落地**（r305）：
1. `pages/OnboardingPage.ets` 新增两个回调 prop `onThemeModeChange(themeMode: number)` 与 `onPaletteChange(paletteIndex: number)`；`modeOption()` 的 `.onClick` 改为 `() => { this.themeMode = mode; this.onThemeModeChange(mode); }`，调色板 ForEach 的 `.onClick` 改为 `() => { this.paletteIndex = index; this.onPaletteChange(index); }`。
2. `pages/Index.ets` 新增 `selectOnboardingThemeMode(themeMode: number)`（走 `applyThemeMode(context, ThemeSettingsRepository.fromModeNumber(themeMode), this.themePaletteIndex, true)`，与 A1 同一条写入路径）；调色板复用已有的 `selectThemePalette(paletteIndex)`。
3. `OnboardingPage({...})` 调用处补传两个回调，`const themeContext = this.getUIContext().getHostContext()` 为空时静默返回。
4. `pages/OnboardingPage.ets` 的 18 处颜色字面量全部换成 `$r('app.color.theme_*')`，向导页因此能随 `resources/dark` 翻转（原先写死浅色，在深色模式下是一块白板）；页脚文案由「外观选择会保存用于向导偏好；全局换肤仍在迁移中」改为「深色模式点选即写入主题设置并在整个应用生效；配色序号会一并保存，配色渲染仍在迁移中」。

**与上游的差异**：① 上游点选后显式发 `ApplyDayNight` effect 通知 AppCompat 重算夜间模式，本地 `setColorMode` 改完系统自己按 `resources/dark` 重解析资源，没有独立 effect 层（同 F3/E7 的理由）；② 上游调色板是 14 套完整 colorScheme，本地只有 5 个写死色板（`0 #B9C8FF` / `1 #A6D28A` / `2 #F4D45E` / `3 #B7B8BC` / else `#85B7FF`）且只用于色卡与预览卡，全局 1051 处 `$r('app.color.theme_*')` 与序号无关——**配色渲染缺口归 A2**，C2 只保证「选择被记住」。

**验收**（2026-11-01 模拟器实测，见 `docs/VALIDATION.md` r305 节）：
- C1：把 `legado_first_run` 的 `completed` 置 false → 重启进向导 → 翻到第 4 页「主题样式」→ 点「深色」→ ①`legado_theme` 的 `themeMode` 由 `"1"` 变 `"2"`；②向导页自身立刻变深色（截图取证），此时尚未点「完成」。
- C2：点第 5 个色板「玫瑰」→ `legado_theme` 的 `paletteIndex` 由 `0.000000` 变 `4.000000`，选中态 ✓ 与预览卡文字同步变色。
- C4（r300 已验）：向导结束进书架即为深色；杀进程重进仍是深色。

### D 阅读页日夜快捷按钮

**D 块前提**：本地阅读页**有**日夜按钮（`ReaderPage.ets:1293` 底部动作条 `theme` 项、`ReaderSettingsPage.ets:360-362` 「背景」行的月亮图标），切的是阅读页私有 `readerNightMode` 布尔（`ReaderSettingsRepository.ets:165`），**不写全局 `themeMode`**。所以 D 块的问题不是「按钮没有」，是「按钮只管自己那一页」。

**KI-TH-D1 日夜切换接到全局（D2/D3/D5 全部已实现：D2 r300，D3/D5 r306 复查改判）** —— 覆盖 D2 切换效果写入全局 `themeMode`、D3 日夜派生：三值 → 布尔、D5 阅读背景的日夜三套。

**D2 已实现（r300）**：`pages/Index.ets:2574-2584 toggleReaderNightMode()` 重写为 `const nextMode = this.readerNightMode ? THEME_MODE_LIGHT : THEME_MODE_DARK;` → `applyThemeMode(context, nextMode, this.themePaletteIndex, true)`。`@State readerNightMode` 保留，但语义降级为「全局 themeMode 的投影」，唯一来源是 `applyThemeMode`（注释已写在字段上）。验收已过：阅读页设置面板点月亮图标 → `legado_theme` 从 `"2"` 变 `"1"`，返回书架书架整页变浅。

**上游口径**：`ReadStyleDelegate.kt:455-470` `val nextIsNight = !(ReadSessionState.isDarkThemeOverride ?: host.isNightTheme)`、`val nextMode = if (nextIsNight) "2" else "1"` → 写网关；`ReadBookController.kt:1762-1790 onAppThemeChanged(isDarkTheme)` 处理来源往返（`:1769` 注释「ToggleDayNight installs the target override before DataStore publishes the app configuration」）。D3：`AppUiConfiguration.kt:11-15` 三值派生。D5：`appTheme == "4"` 时整套换墨水屏背景与配色。

**本地现状（r306 复查）**：D3 与 D5 都判 `已接`，原判 `未接` 属盘点时点早于实现。D3：`data/ThemeModeResolver.ets:52-56` `static isDarkTheme(themeMode, systemDark)` 三支对齐上游 `isNightThemeCompat`（`THEME_MODE_LIGHT`→false、`THEME_MODE_DARK`→true、其余 `return systemDark`），派生点三处 `pages/Index.ets:1997`/`:2114`/`:3856` 全部写 `this.readerNightMode = ThemeModeResolver.isDarkTheme(...)`。D5：`pages/Index.ets:4235-4240` `getPaperColor()` 的日/夜两套**结构上与上游一致**——自定义色走 `readerBgType`+`readerBgStr` 对 `readerBgTypeNight`+`readerBgStrNight`（`customType === 0 && custom.length > 0` 时直接用），内置样式走 `READER_BACKGROUND_STYLES[paperIndex]` 的 `dayColor`/`nightColor`。第三套墨水屏在上游靠 `appTheme == "4"` 切，本地归 lab 且无渲染，该维度已在 F8 判 `不适用`（产品定位不同），不计入本行。

**补法**：D3、D5 均无剩余工作。上游的 `ReadSessionState.isDarkThemeOverride` 会话态本地未照抄——阅读页配色由 `paperIndex` 直接跟随全局，不存在「临时覆盖后退出阅读页还要还原」的往返。上游用 `ReadStyleMode` 枚举判定、本地用 `readerNightMode` 布尔，两者对两套背景的取用结果相同。

**验收**：阅读页点日夜 → 退出到书架，书架也是深色（全局生效，r300 已验）；重进阅读页仍深色；把 themeMode 设「跟随系统」+ 系统切深色 → 阅读页跟着变（r300 验收③已验）；在阅读设置里给日/夜各设一个自定义背景色 → 切日夜时两套各自生效（D5）。

**KI-TH-D2 菜单配色与提醒耦合（D7 已实现 r302，D8 r306 复查改判已接）** —— 覆盖 D7 阅读页快速按钮的提醒冷却与去重、D8 阅读页菜单的日夜配色。

**上游口径**：D7 手动切日夜会顺手清掉待弹的提醒（`ReadStyleDelegate.kt:489-491 resetDayNightReminderDismissal()`）；D8 菜单配色由 `isNightTheme` + `paletteStyle` 共同算出（`ReadBookColorTheme.kt:52-63`/`:144-162`/`:286-298`）。

**本地现状**：D7 **已实现**（r302）——`pages/Index.ets` 的 `toggleReaderNightMode()` 开头补了四行：`readerDayNightReminderLastAt = Date.now()`（冷却从本次切换算起）、清 `readerDayNightReminderDismissedDark`/`DismissedLight`（对齐 `resetDayNightReminderDismissal()`）、`readerDayNightReminderRequestId += 1`（作废在途的 5 秒隐藏定时器）、`readerDayNightReminderText = ''`。上游清的是 `reminderQueue` 里排队的项，本地只有一个文案槽位，用 `requestId` 递增达到同样效果。D8 **r306 复查改判 `已接`**：`pages/ReaderPage.ets:1007-1019` `readerMenuIsNight()` 按纸色 sRGB 相对亮度 < 0.5 判日夜，六个取色函数全部按它分支——`readerMenuBaseColor()`（`:1027-1039`，`readBarStyle===1` 取纸色、`===2` 取自定义 `readMenuBgColor`/`Night`、否则日夜取 `#000000`/`#FFFFFF`）、`readerMenuContainerBaseColor()`（`:1045-1048`）、`readerMenuAccentTint()`（`:1055-1058`）、`readerMenuTintColor()`（`:1065-1070`）、`readerMenuForeground()`（`:1078-1082`，`#D5C2C6`/`#3E3D3B`）。配色本体由 `9902eb8 feat(readConfig): 接上配色七项（KI-E1）` 与 `154f91e feat(readConfig): 接上边框与模糊七项（KI-E2）` 落地，r300 打通 `paperColor ← readerNightMode ← themeMode` 之后这条链路才真正随日夜变。原判「全用写死深色字面量」是那两次提交之前的状态。

**补法**：D7、D8 均无剩余工作。D8 与上游的剩余差别是**配色维度**——上游还有 `paletteStyle`（种子色/经典/单调）与 `materialVersion` 两个维度参与计算，本地只有日夜一维（`readMenuColorMode === 0` 的种子色分支只取强调色作基底近似），该缺口归 A2（调色板，未接）。

**验收**：D7 开提醒 → 阅读页手动切日夜 → 不再弹出「是否切换至深色模式」（VALIDATION.md r302 已实测）。D8 切到浅色主题 → 阅读菜单为白底深字（`#FFFFFF` 基底 + `#3E3D3B` 文字）；切回深色 → 深底浅字（r300 验收①/② 已覆盖该链路）。

### E 日夜提醒

**E 块整体判定：7 行里 6 行已实现（r302 核实）、1 行不接。** r297 盘点时判「本地只有 `ReaderSettingsPage.ets:898` 一个开关壳、全仓零命中」是**误判**——提醒机制其实早已存在于仓库（`pages/Index.ets` 的传感器订阅与判定、`pages/ReaderPage.ets` 的提醒胶囊、`pages/ReaderSettingsPage.ets:1495` 的真开关、`data/ReaderSettingsRepository.ets:240-241/1583` 的持久化），只是当时没查到。r302 逐行核实后 E1–E6 改判 `已接`，并在模拟器上验通了胶囊弹出、5 秒消失、点击切换、关闭后不再弹四条。

**KI-TH-E1 提醒开关与采样判定（已实现 r302）** —— 覆盖 E1 「自动切换日夜模式提醒」开关（阅读设置页）、E2 阅读页「更多设置」里的同一开关、E3 环境光传感器采样、E4 亮度阈值判定。

**上游口径**：开关 `autoSuggestDayNight`（`PreferKey.kt:120`），两处入口 —— `ReadConfigScreen.kt:337-344` 与 `MoreConfigSheet.kt:399-404`；采样 `ReadStyleDelegate.kt:500-560 checkSwitchDayNight(lux)`；阈值 `:633 DARK_LUX_THRESHOLD = 8f` / `:634 BRIGHT_LUX_THRESHOLD = 100f`；关键的一层是 `isLightBg` 判定（按 `styleConfig.bgType` 与 `backgroundMeanColor` 算）——用户已经把背景设成深色时，暗环境下不该再提醒切深色。

**本地落地**：E1/E2 是同一份状态的两个入口——`pages/ReaderSettingsPage.ets:1495` 的 `MenuSettingSwitch`（位于 `moreSettingsContent()` 的「其他」段，该面板由阅读页 `onOpenSettings` 以 `asSheet: true` 弹出，上游两处入口在本地合并成同一面板的两个 tab）；`data/ReaderSettingsRepository.ets:240-241` 字段 + `:1583` 落盘 + `data/BackupRepository.ets:250-251/644` 进备份。E3 `pages/Index.ets:2700-2711 startReaderAmbientLightWatch()` 订阅 `sensor.SensorId.AMBIENT_LIGHT`，`@Watch('onReaderRouteChanged')` 进阅读页才订阅、离开即停。E4 `:2590-2598` 两条阈值 + `:2604-2616 computeReaderColorLuminance()`（按 Android `ColorUtils.calculateLuminance` 的 sRGB 线性化 + 0.2126/0.7152/0.0722 加权）+ `:2618-2623 isReaderBackgroundLight()`（阈值 0.35）。

**与上游的差异（未消除，如实记录）**：① 上游每 15 分钟一轮、每轮注册监听 1 秒取 `finalLux` 后注销（`ReadBookRouteScreen.kt:1088-1138`），本地是常驻订阅、1 秒一次回调，**没有 15 分钟节流**；② 上游按 `bgType/bgStr`（含夜间一套）与 `backgroundMeanColor` 判底色，本地只有 `getPaperColor()` 单值 + 亮度阈值，**没有背景图均值色这一支**。

**验收**：开提醒 → 暗处（遮住感光）且当前为浅色背景 → 弹出提醒；当前已是深色背景 → 不弹。模拟器实测见 VALIDATION.md r302（前置条件：`themeMode` 必须是 `"1"`，否则 `readerNightMode` 会被重算成 `true`、非夜间分支进不去）。

**KI-TH-E2 提醒的防骚扰与呈现（已实现 r302）** —— 覆盖 E5 提醒冷却与去重、E6 提醒胶囊 UI。

**上游口径**：`:636 REMINDER_COOLDOWN_MS = 10 * 60 * 1000L`、`:574-576` 用户点掉后置 `hasDismissedDarkReminder`/`hasDismissedLightReminder`；胶囊 UI 5 秒自动消失，点击执行 `ReadBookIntent.ToggleDayNight`（即 D1 同一个动作）。

**本地落地**：`:2625-2627 isReaderDayNightReminderCoolingDown()`（10 分钟）、`:2633-2645 checkReaderDayNightReminder()`（`dismissed*` 标记 + `isReaderBackgroundLight()` 双闸）、`:2647-2661 showReaderDayNightReminder()`（`setTimeout` 5 秒清空）、`:2672-2681 dismissReaderDayNightReminder()`（按 target 置标记）、`:2928-2938 setReaderAutoSuggestDayNight()`（开启时复位两个标记，对齐 `resetDayNightReminderDismissal()`）；胶囊 UI 在 `pages/ReaderPage.ets:3161-3181 ReaderDayNightReminderCapsule()`，点击复用 `toggleReaderNightMode()`，未新建第二条切换路径。

**差异**：上游有 `reminderQueue` 排队，本地只有单个 `readerDayNightReminderText`。

**验收**：弹出后点掉 → 本轮不再弹（实测 14 秒内未再弹）；10 分钟内重复触发 → 不弹；胶囊 5 秒后自动消失；点胶囊左侧 → `themeMode` 由 `"1"` 变 `"2"`。见 VALIDATION.md r302。

**KI-TH-E3 提醒的 intent/effect 链路（不接）** —— 覆盖 E7。

**判定理由**：本地阅读页用 `@Prop` 回调直连（`onToggleNightMode`），**没有 intent/effect 分层**，这是架构差异而非缺功能。上游这一层还有历史包袱：`ReadBookContract.kt:1271 data object ToggleDayNight : ReadBookEffect` 定义了但 `ReadBookController.kt:2563-2565` 注释写明「Handled directly by ViewModel — effect not currently emitted」，即**上游这个 effect 从不发出**。为一行从不生效的分层引入整套架构，违背「上游没有就不要这个效果」。

**保留部分**：提醒的实际行为在 KI-TH-E1/E2 里直接实现，不依赖该层。

**验收**：无（不接）。提醒功能照 KI-TH-E2 的验收走。

### F 网关与全局换肤

**F 块是整张表的地基**：F1/F2/F3/F4 四行不落地，A/B/C/D/E 五块的所有开关接了也不会有可见变化。这四行必须在阶段一一起做完。

**KI-TH-F1 全局网关与三值派生（已实现，r300）** —— 覆盖 F1 `themeMode` 全局网关、F2 `isDarkTheme` 派生、F3 应用夜间模式。

**上游口径**：F1 `constant/PreferKey.kt:9` + `AppShellSettings.kt:4 val themeMode: String = "0"` + `App.kt:194-203` 注释（唯一来源 + 三个写入方）；F2 `AppUiConfiguration.kt:11-15` `isDarkTheme = when (themeMode) { "1" -> false; "2" -> true; else -> isSystemDarkTheme }`；F3 `ThemeConfigStore.kt:70-89 initNightMode()` → `AppCompatDelegate.setDefaultNightMode(mode)`。

**本地落地**：新建 `entry/src/main/ets/data/ThemeSettingsRepository.ets`（preference 名 `legado_theme`，字段 `themeMode: string` + `paletteIndex: number`，含 `hasStoredThemeMode`/`fromModeNumber`/`toModeNumber` 边界换算）与 `entry/src/main/ets/data/ThemeModeResolver.ets`（`isDarkTheme(themeMode, systemDark)` 照搬上游三段；`isSystemDark` 读 `context.resourceManager.getConfigurationSync().colorMode === resourceManager.ColorMode.DARK`；`toColorMode` 把三值映射成 `COLOR_MODE_LIGHT`/`COLOR_MODE_DARK`/`COLOR_MODE_NOT_SET`）。`pages/Index.ets` 加 `@State themeMode: string = '0'` / `@State themePaletteIndex: number = 0` 与唯一写入点 `applyThemeMode(context, themeMode, paletteIndex, persist)`，三个写入方（主题页 A1、阅读页 D2、向导 C4）全部走它。`entryability/EntryAbility.ets` 在 `loadContent` 之后 `applyStoredThemeMode()`，并用 `SystemBarEnvironmentCallback`（`EnvironmentCallback.onConfigurationUpdated`）监听系统深浅色变化同步系统栏。

**与上游的机制差异（F3，不照抄）**：ArkUI 无 `AppCompatDelegate`。本地走 `ApplicationContext.setColorMode()` 让系统按 `resources/dark` 限定目录重新解析资源，再由 `@State` 驱动重建。三档映射：`MODE_NIGHT_NO`→`COLOR_MODE_LIGHT`、`MODE_NIGHT_YES`→`COLOR_MODE_DARK`、`MODE_NIGHT_FOLLOW_SYSTEM`→`COLOR_MODE_NOT_SET`（**必须**是 `NOT_SET`，否则应用会盖住系统设置）。

**踩过的坑**：`resourceManager.getConfigurationSync().colorMode` 的类型是 `resourceManager.ColorMode`，与 `ConfigurationConstant.ColorMode` 是两个互不相通的枚举，混比会报 `10505001 ArkTS Compiler Error ... have no overlap`。

**验收（全部已过，见 VALIDATION.md r300）**：`themeMode="2"` → 全 App 深色且 `legado_theme` 里读得到 `themeMode="2"`；杀进程重进仍深；`themeMode="0"` + 系统切深色 → 全 App 跟着变；`themeMode="1"` + 系统深色 → App 仍为浅色。

**KI-TH-F2 两套颜色资源（已实现，r300）** —— 覆盖 F4。

**这是整张表最大的一行，也是唯一真正的前置。** 本地原 2252 处颜色字面量全部内联在 `.ets` 里，`entry/src/main/resources/` 只有 `base/` 与 `rawfile/`、**无 `dark/`**，`base/element/color.json` 只有 1 个颜色（`start_window_background = #F6F4F0`），全仓 `$r('app.color.*')` 引用 **0 处**。

**本地落地**：新建 `entry/src/main/resources/dark/element/color.json`，扩写 `base/element/color.json`，两边各 9 个键成对：`start_window_background`、`theme_text_primary`、`theme_text_secondary`、`theme_text_tertiary`、`theme_accent`、`theme_surface_primary`、`theme_surface_secondary`、`theme_surface_tertiary`、`theme_surface_elevated`。`base` 提供浅色值（`theme_text_primary = #1B1C22`、`theme_surface_primary = #F5F6F8`、`theme_accent = #3F5BD9` …），`dark` 提供深色值（`theme_text_primary = #E3E4E8`、`theme_surface_primary = #111217`、`theme_accent = #AFC2FF` …）。高频 8 色映射：`D8D9E0→theme_text_secondary`、`AFC2FF→theme_accent`、`92949E→theme_text_tertiary`、`E3E4E8→theme_text_primary`、`1C1D23→theme_surface_elevated`、`111217→theme_surface_primary`、`1A1B21→theme_surface_secondary`、`1B1C22→theme_surface_tertiary`。

**替换结果**：34 个 `.ets` 文件、**926 处**字面量换成 `$r('app.color.*')`（属性调用 `fontColor`/`backgroundColor`/`borderColor`/`fillColor`/`stroke`/`selectedColor`/`trackColor`/`color`/`placeholderColor`/`caretColor`/`blockColor`/`border`/`stepColor`）。`components/AppGlyph.ets:7` 的 `@Prop tint: string` 改为 `@Prop tint: ResourceColor = '#C5C7D0'` 才能吃资源。剩 1336 处未抽：低频色 + 自定义组件 prop 传参（改 `Resource` 会引发类型连锁，需逐个改声明）。

**替换方法的坑**：正则批量改 `.ets` **必须靠括号配对**取实参范围，不能用简单正则闭合——第一次用 `\(...\)` 把属性调用的闭括号吃掉，34 个文件全改坏，靠 `git show HEAD:<path>` 逐个恢复。

**验收（已过，见 VALIDATION.md r300）**：`assembleHap` 通过；切深/浅两档同页配色整体翻转。

**KI-TH-F3 主题配置随备份走（F7/F9/F11/F12 已实现 r303，F5 已实现 r316）** —— 覆盖 F5 `themeConfig.json` 导出、F7 `themeConfig` 的 6 个护眼键双向落盘、F9 `themeMode` 的备份写出与恢复读回、F11 备份忽略开关的界面、F12 恢复时的 `config.xml` 键过滤。

**上游口径**：`help/storage/BackupConfig.kt` —— themeConfig 是 53 键的数组类别（`:263-317`），`themeMode` 是单键类别（`:147`/`:173` 直接列进 ignoreKeys/backupIgnoreKeys），门控在 `:422`/`:434`；`keyIsNotIgnore(key, isBackup)`（`:413-439`）**按 key 逐个判**。

**本地现状（r303 核实）**：
- **F7 已接**：备份侧 6 个护眼键双向通（`data/BackupRepository.ets` 的 `createBackup` 写 6 键、`applyEyeProtection` 读回），且 r301 之后功能侧也通了——读回的 6 个值经 `pages/Index.ets` 的 `isEyeProtectionActive()` 与 `eyeProtectionOverlayColor()` 直接驱动全 App 覆盖层。
- **F9 已接**：`createBackup` 新增 `if (!ignoredCategories.includes('themeMode')) { upsertAndroidPreference(configText, 'string', 'themeMode', normalizeThemeModeForBackup(themeMode)) }`，值域先归一成 `"0"/"1"/"2"`；恢复侧新增 `restoreThemeMode(directory, ignoredCategories)` 与 `RestoreResult.themeMode`，`pages/Index.ets` 的 `restoreLocalBackup()` 拿到后 `await this.applyThemeMode(context, result.themeMode, this.themePaletteIndex, true)` 真正改全 App 配色。同一处把 `this.readerNightMode = result.settings.readerNightMode` 改成按全局投影重算（`ThemeModeResolver.isDarkTheme(this.themeMode, ThemeModeResolver.isSystemDark(context))`），否则备份里的旧布尔会冲掉刚恢复的模式。
- **F11 已接**：`pages/AppBackupSettingsPage.ets` 的两个 sheet（`ignoreBackup` / `ignoreRestore`）经 `pages/Index.ets` 的 `backupIgnoreKeys` / `restoreIgnoreKeys` 传给 `BackupRepository`，r303 之后两类开关都有真实效果。
- **F12 已接（改判）**：原判「`filterAndroidConfigXml` 按类别整体剔除，不是上游那种按 key 逐个判」——复核后认为两者结果等价：上游 `keyIsNotIgnore` 逐 key 查的也是那几组 `*PrefKeys` 集合，等价于「该 key 是否属于某个被忽略类别」。本地另外给 `themeMode` 加了 `restoreThemeMode` 里的独立早退，`themeConfig` 被忽略时 `applyEyeProtection` 早退，两条都对。r297 盘点时判「未接」属口径过严，已在对照表改判并写明理由。
- **F5 已接（r316）**：`createBackup` 在 `!ignoredCategories.includes('themeConfig')` 时用 `buildCurrentThemeConfigs(paletteIndex, customTheme)` 现算 `MD3-Day`/`MD3-Night` 两条，`themeConfigsToJson` 序列化后 `writeTextFile` 到暂存目录；恢复侧遇到 `themeConfig.json` 时 `parseThemeConfigs` 逐条校验 4 个颜色可解析（坏条目跳过、全坏回落内置 4 套），`saveThemeConfigs` 落 `files/themeConfig.json` 并 `upThemeConfig` 重新装载，对齐上游 `Restore.kt:327-336` 的 `copyFileAtomic` + `upConfig()`。条目结构逐字段对齐上游 `ThemeConfigStore.kt:265-274` 的 `Config(themeName, isNightTheme, primaryColor, accentColor, backgroundColor, bottomBackground, backgroundImgPath, backgroundImgBlur)`。

**补法**：F5 已在 r316 完成，本组无剩余工作。唯一与上游的差异：上游 `configList` 是「内置 4 套 + 用户 `addConfig` 过的」，本地没有 `addConfig` 入口，所以只写当前日夜两条（`MD3-Day`/`MD3-Night`），内置 4 套（默认/典雅蓝/黑白/A屏黑）保留在 `data/ThemeConfigStore.ets` 的 `defaultThemeConfigs()` 里供回落。

**验收（r303 已在模拟器实测，见 [验证记录](VALIDATION.md) r303 节）**：
1. `themeMode` 设 `"2"` → 备份 → 解压 `config.xml` 含 `<string name="themeMode">2</string>`（实测通过）。
2. prefs 改回 `"1"` → 恢复该 ZIP → prefs 变回 `"2"`（实测通过）。
3. 备份排除项打开「深色模式」→ 备份 → `config.xml` 不含 `themeMode`（实测 66 行、grep 0 命中）。
4. 恢复排除项打开「深色模式」→ 恢复含 `themeMode=2` 的 ZIP → prefs 仍为 `"1"`（实测通过）。
5. **F5（r316 实测通过）**：改一套配色 → 备份 → 解压得到 `themeConfig.json` 304 字节，内容是 `[{"themeName":"MD3-Day","isNightTheme":false,"primaryColor":"#FF8800","accentColor":"#5C5C5C","backgroundColor":"#FFCC00","bottomBackground":"#F7F3F2"},{"themeName":"MD3-Night","isNightTheme":true,"primaryColor":"#00FF88","accentColor":"#C7C6C6","backgroundColor":"#141313","bottomBackground":"#1C1B1B"}]`，与当前配色一致；恢复该 ZIP → `files/themeConfig.json` 落盘 304 字节、预览列表显示「themeConfig.json 2 条」。

## 设备范围

- API 12 真机兼容尚未验证。HOS 模拟器检查只代表验证记录中列出的操作；N 端 API 26 数据不作为 E 端或 API 12 结论。
- r257 设备没有自定义分组，卡片上新增的私有标记/刷新状态文案未在设备上直接显示验证。

构建与设备记录见[验证记录](VALIDATION.md)，Android ZIP 字段边界见[备份恢复说明](BACKUP-RESTORE.md)。
