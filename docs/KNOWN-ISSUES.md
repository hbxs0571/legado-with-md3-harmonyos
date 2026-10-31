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

**KI-A1 正文渲染适配四项（要接，待排期）** —— 覆盖 A-01 正文行高适配（`readBodyToLh`，`ReadBookConfig.kt:67`）、A-02 中文排版（`useZhLayout`，`:76`）、A-03 适配刘海屏（`paddingDisplayCutouts`，`ReadSettings.kt:11`）、A-04 适配特殊样式（`adaptSpecialStyle`，`:18`）。

上游四项都落在排版管线：`MoreConfigSheet.kt:231`、`model/ReadBook.kt:420`、`ReadBookRouteScreen.kt:195`、`feature/reader/core/source/ReaderBodyOnlyFilter.kt:56`。本地这四条在 `entry/src/main/ets/pages/ReaderSettingsPage.ets:837-840` 是恒 `checked: true` 的占位开关，分页由 `ReaderPage.ets` 自己做，没有「行高归一 / 保留书籍自带样式 / 中文标点挤压」这三条分支。**先接线不会改变渲染，属假已接**，所以整组留到排版引擎那一轮。补法：分页测量处按 `readBodyToLh` 归一特殊排版行高、按 `adaptSpecialStyle` 决定是否套书籍自带样式、按 `useZhLayout` 走中文标点挤压；刘海屏在 HOS 由窗口安全区处理，接入前先确认 `ReaderPage` 是否已 `expandSafeArea`。

**KI-A2 菜单层依赖三项（要接，随 KI-E1）** —— 覆盖 A-05 显示菜单图标（`showMenuIcon`，`ReadBookConfig.kt:78`）、A-08 阅读标题补充信息（`showReadTitleAddition`，`ReadSettings.kt:55`）、A-17 阅读菜单不透明度（`menuAlpha`，`:13`）。

三项都作用在阅读页菜单层，而本地没有菜单外观渲染层：全仓 `readMenu*`/`titleBar*` 只命中 `data/BackupRepository.ets`，`ReaderPage.ets` 零命中。没有菜单的地方单独接这三个开关等于给不存在的界面加配置，因此与 E 块合并处理（见 KI-E1）。

**KI-A3 禁用返回键（要接，待产品定调）** —— 覆盖 A-06（`disableReturnKey`，`ReadSettings.kt:50`）。

需要拦截系统返回手势，与阅读页现有的下拉/侧滑退出手势冲突；`ReaderPage.ets` 目前没有 `onBackPress` 覆盖。补法：`onBackPress()` 返回 `true`，并在设置里给出「仍需退出」的二次确认，避免把用户困在阅读页。

**KI-A4 优化正文渲染（不接）** —— 覆盖 A-07（`optimizeRender`，`ReadSettings.kt:49`）。

上游这条只在 `feature/reader/legacy/LegacyReaderPaginationStyleFactory.kt:49` 的 `Build.VERSION.SDK_INT <= Q`（Android 10 及以下）分支里生效，是给老设备减少渲染开销的兼容路径。HOS 没有对应的老渲染管线，接了也没有可切换的实现。**不补**；设置页该条保留占位文案，不假装生效。

**KI-A5 朗读与在线书源三项（不接，范围之外）** —— 覆盖 A-09 朗读悬浮窗分离提醒（`readAloudDetachReminderEnabled`，`ReadBookConfig.kt:80`）、A-10 自动切换书源（`autoChangeSource`，`ReadSettings.kt:42`，含 `defaultSourceChangeAll:15`）、A-11 换源结果应用于全部书籍。

朗读（TTS）与在线书源抓取都在[项目范围](PROJECT.md)之外；因开关已上屏，判 `未接` 而非 `不适用`。补法：随对应子系统接入，本轮不动。

**KI-A6 自动切换日夜模式提醒（要接，待排期）** —— 覆盖 A-12（`autoSuggestDayNight`，`ReadSettings.kt:43`）。

上游是到点弹「是否切换背景」的应用内提示，依赖定时判定；本地日夜切换只有手动入口，没有提层。补法：`ReaderPage` 在前台时按整点判断一次，弹应用内提示即可，不引系统通知（HOS 通知需要授权，成本不成比例）。

**KI-A7 触感反馈两项（要接，待排期）** —— 覆盖 A-13 阅读进度条触感反馈（`sliderVibrator`，`ReadSettings.kt:36`）、A-15 文字选择触感反馈（`selectVibrator`，`:41`）。

HOS 有振动能力，本地一处都没接。补法：封装一个触感工具，进度条拖动与选区变化各调一次；落地前先确认 API 12 的振动接口与权限口径。

**KI-A8 使用新版目录（不接）** —— 覆盖 A-14（`useNewTocSheet`，`ReadSettings.kt:37`）。

上游这个字段是「阅读页内开 Sheet」与「跳独立目录页」两种呈现的切换开关（`ui/book/read/ReadBookViewModel.kt:193`）。本地目录固定为 `CatalogPage.ets` 独立页一种形态，没有第二态可切。为它造一个不存在的新旧目录等于凭空加功能，**不补**。

**KI-A9 阅读亮度（要接，待排期）** —— 覆盖 A-16（`readBrightness`，`ReadSettings.kt:22`，默认 100）。

上游按书保存亮度，本地没有亮度控制，退出重进也不记忆。补法：`ReaderPage` 用窗口亮度接口设置，值落 `ReaderSettingsRepository` 新字段，退出阅读页恢复系统亮度。

**KI-A10 主题网格列数（不接）** —— 覆盖 A-18（`themeGridColumns`，`ReadSettings.kt:40`，默认 4）。

本地背景/主题是 `READER_BACKGROUND_STYLES` 六个内置方案的自绘列表（`entry/src/main/ets/data/ReaderSettingsRepository.ets:339-346`，入口 `ReaderSettingsPage.ets:1281`），不是网格布局，该字段没有消费面。**不补**；将来若把面板改成网格，再一并接。

**KI-A11 预下载两项（不接，范围之外）** —— 覆盖 A-19 向后预下载章节数（`preDownloadNum`，`ReadSettings.kt:58`，默认 10）、A-20 向前预下载章节数（`preDownloadNumPrev`，`:59`，默认 0）。

依赖离线缓存/预下载子系统；本地 `AppDownloadCacheSettingsPage.ets:31` 是预览页，没有缓存实现。补法：随下载缓存子系统接入。

**KI-A12 在浏览器打开（不接，范围之外）** —— 覆盖 A-21（`readUrlInBrowser`，`ReadSettings.kt:64`）。

需要外部应用跳转（`module.json5` 的 browser skill），属跨应用能力而非配置接线。补法：加 browser skill 后用 `startAbility(ACTION_VIEW)` 打开；本轮不动。

### C 正文排版

**KI-C1 正文取色三项（要接，待与 KI-C2 一并做）** —— 覆盖 C-01 正文日间颜色（`textColor`，`ReadBookConfig.kt:55`）、C-02 正文夜间颜色（`textColorNight`，`:56`）、C-03 正文强调色（`textAccentColor`/`Night`，`:62`）。

本地`ReaderPage.ets:2710-2713 getReadingTextColor()` 按纸色三值返回硬编码颜色，强调色同时被划线高亮与 E 块「种子色」引用。这三项若单独接，会出现「纸色是六方案、文字色是任意色」的错配，必须与背景系统一起改。补法：给 `ReaderSettingsSnapshot` 加 `textColor`/`textColorNight`/`textAccentColor(+Night)`，`getReadingTextColor()` 改为读字段，空值时回落到现有硬编码值以保持旧观感。

**KI-C2 背景三项（要接，独立一轮）** —— 覆盖 C-04 背景透明度（`bgAlpha`，`ReadBookConfig.kt:198`，默认 100）、C-05 背景颜色/图片（`bgStr`/`bgStrNight`/`bgType`/`bgTypeNight`，`:537-551`）、C-06 白天是否暗色状态栏（`darkStatusIcon`/`Night`，`:552`）。

本地背景收敛为六个内置方案（`paperIndex`/`dayPaperIndex`/`nightPaperIndex` → `READER_BACKGROUND_STYLES`，`ReaderSettingsRepository.ets:162-164`、`:339-346`），上游是「任意颜色串 + assets 图 + 自选图」三类，自定义能力本地为零；`ReaderSettingsPage.ets:1281` 的「背景图片」条目只弹提示。接入需要图片选择、应用私有目录存储、渲染三层（可复用 r265 书签角标图片那套），`darkStatusIcon` 又要跟背景亮度联动，所以整组一起做。补法：先加 `bgStr`/`bgStrNight`/`bgType`/`bgAlpha` 与取色器，把 `READER_BACKGROUND_STYLES` 降级为「预设」；`darkStatusIcon` 由背景亮度推导或加显式开关。

**KI-C3 下划线绘制参数四项（要接，待排期）** —— 覆盖 C-07 下划线偏移量（`underlinePadding`，`ReadBookConfig.kt:322`，默认 10）、C-08 下划线延伸（`underlineExtend`，`:325`）、C-09 自定义虚线长度基准（`dottedBase`，`:331`，默认 6f）、C-10 自定义虚线间隔比例（`dottedRatio`，`:334`，默认 6f）。

本地下划线只用了 `underline`/`dottedLine`/`underlineHeight`/颜色四个字段，绘制集中在 `ReaderPage.ets:2159`，四个几何参数从未参数化。补法：先确认 ArkUI 的 `TextDecorationType` 是否开放虚线段长，不开放就得改成自绘下划线，再把四个值传进去。

**KI-C4 标题排版十四项（要接，需先做排版模型改造）** —— 覆盖 C-11 标题位置模式（`titleMode`，`ReadBookConfig.kt:267`）、C-12 标题字号（`titleSize`，`:269`）、C-13 标题字号是否相对正文（`titleSizeRelative`，`:270`）、C-14 标题上间距（`titleTopSpacing`，`:298`）、C-15 标题下间距（`titleBottomSpacing`，`:301`）、C-16 标题日间颜色（`titleColor`，`:304`）、C-17 标题夜间颜色（`titleColorNight`，`:307`）、C-18 标题字重（`titleBold`，`:228`）、C-19 标题行距（`titleLineSpacingExtra`，`:255`）、C-20 标题行距子项（`titleLineSpacingSub`，`:258`）、C-21 标题分段模式（`titleSegType`，`:280`）、C-22 标题分段缩放（`titleSegScaling`，`:283`）、C-23 标题分段起始位置（`titleSegDistance`，`:287`）、C-24 标题分段识别字符（`titleSegFlag`，`:290`）。

共同前提：本地标题把字号写成 `this.fontSize + 4` 硬编码，共 9 处——`ReaderPage.ets:824`、`:1651`、`:1656`、`:2857`、`:2859`、`:2867`、`:2869`、`:2941`、`:2943`，覆盖测量与绘制两类调用点。字段接进去而不改这九处等于没接；改这九处又必须先定标题排版模型（绝对/相对字号、分段规则、颜色回退）。补法：抽 `resolveTitleStyle()` 统一产出字号/行距/颜色/字重/分段，九处调用点全改走它，再逐项接字段。

**KI-C5 繁简转换（要接，待排期；需自带字表）** —— 覆盖 C-25（`chineseConverterType`，`ReadSettings.kt:118`，三档）。

需要简繁/繁简两套字表（上游由第三方库提供），本地全仓零命中，属独立能力而非配置接线。补法：引入一份常用字表 + 三态开关，挂在正文处理管线（`entry/src/main/ets/data/BookContentProcessEngine.ets`）里做全文转换。

**KI-C6 字体文件夹（不接）** —— 覆盖 C-26（`fontFolder`，`ReadSettings.kt:79`）。

上游是「用户指定一个目录，扫描其中所有 TTF/OTF」（`ui/book/read/ReadBookScreen.kt:470`）。HOS 应用无法递归扫描任意用户目录；本地等价能力是 `ReaderFontRepository.listFonts()` 列系统字体 + 导入字体到应用私有目录（r265 起可用），入口就在排版设置面板。**不补**，差别只在导入方式。

### D 翻页与手势交互

**KI-D1 翻页按键与鼠标滚轮（要接，分批）** —— 覆盖 D-01 自定义翻页按键（`prevKeys`/`nextKeys`，`ReadSettings.kt:60`/`:61`）、D-03 鼠标滚轮翻页（`mouseWheelPage`，`:28`）。

D-01 需要按键映射面板 + 键盘事件；D-03 依赖鼠标滚轮事件，属「额外设备形态」（[项目范围](PROJECT.md)之外）。补法：D-01 先做固定映射（音量键之外再补两键），再做可配置面板；D-03 随桌面形态一起。

**KI-D2 划词菜单三项（要接，需先抽条目模型）** —— 覆盖 D-02 选中文字菜单（`textSelectMenuConfig`，`ReadSettings.kt:53`）、D-08 展开文字菜单（`expandTextMenu`，`:51`）、D-09 显示选择菜单图标（`showSelectMenuIcon`，`:52`）。

本地划词菜单是 `ReaderPage.ets` 内联面板，条目写死；`textSelectMenuConfig` 全仓零命中，`expandTextMenu` 只有一处 `@State expandTextMenuPreview`（`ReaderSettingsPage.ets:144`）无持久化，`showSelectMenuIcon` 零命中。与本节「书签与标注」第 2 条（行内快速标记）同属划词菜单改造。补法：先抽划词菜单条目模型（id/显示/顺序/图标），再接这三个字段。

**KI-D3 朗读时允许音量键翻页（不接，范围之外）** —— 覆盖 D-04（`volumeKeyPageOnPlay`，`ReadSettings.kt:30`）。朗读子系统未接入，随 TTS 一起做。

**KI-D4 横屏双页（要接，属分页引擎改造）** —— 覆盖 D-05（`doubleHorizontalPage`，`ReadSettings.kt:26`）。

需要双列排版 + 翻页动画跨双页，本地 `ReaderPage` 是单列（滚动/分页两模式）。补法：分页测量阶段按可用宽度拆双列，翻页步长改 2，并同步改阅读进度换算。

**KI-D5 触摸灵敏度与进度条模式（已实现）** —— 覆盖 D-06 翻页触摸灵敏度（`pageTouchSlop`，`ReadSettings.kt:35`，默认 0）、D-07 进度条模式（`readSliderMode`，`:25`，默认 `"0"`）。

已按上游语义接上：
- **D-06**：存储键 `pageTouchSlop`，`ReaderSettingsRepository.ets:175` 字段 / `:423` 默认 0 / `:493` 读 / `:816` 写（夹 0–1000）；面板 `ReaderSettingsPage.ets:854-861` 的 `MenuSettingSlider`（0–1000 步长 10）；消费点 `ReaderPage.ets:2947-2948`，`pageTouchSlop > 0` 时用它，否则回落原来的 36vp 平台默认值——与上游 `ReaderGestureSettingsPolicy.touchSlopPx(platformTouchSlopPx, configuredTouchSlopPx)` 同口径。上游刻意让选择拖选阈值（`selectionDragSlopPx`）不受此配置影响，本地保持解耦。
- **D-07**：上游 `readSliderMode` 的语义是**显示 / 不显示**（`ReadBookMenuBarBottom.kt:161` `AnimatedVisibility(visible = readSliderMode != "1")`），不是形态切换。存储键 `readSliderMode`，`ReaderSettingsRepository.ets:174` / `:422` / `:492` / `:815`；面板「底栏布局」tab 首项 `ReaderSettingsPage.ets:424-430`（详情面板选项「常驻」/「不显示」）；消费点 `ReaderPage.ets:3109` 把整行「上一章 / 滑块 / 下一章」包进 `if (this.readSliderMode !== '1')`。
- 顺带纠正历史错位：该面板位置原先挂的是本地 `progressBehavior`（页码/章节），与上游 `readSliderMode` 不是一回事，现在两者分别由「滑动条显示样式」和「进度条行为」承担。
- 备份：两个键都不在 `BackupConfig.readPrefKeys` 忽略清单里，属「无条件随 config.xml 备份」，本地已在 `BackupRepository.ets:561-566`（导出）与 `:1176-1185`（恢复）对齐。

**KI-D6 上次标记样式（要接，待排期）** —— 覆盖 D-10（`lastMarkingStyle`，`ReadSettings.kt:54`）。

上游用字符串记上一次用的标记样式，连续标注时默认沿用（`MarkingSelectionMenu` 的 `lastMarkingStyle` 入参即此值）。本地标记面板每次重置为默认。补法：面板关闭时把当前 `effect+color` 存一条「最近使用」，下次打开预选。

### E 菜单与主题外观

**整块共同的前置条件**：本地阅读页没有菜单外观渲染层。全仓 `readMenu*`/`titleBar*` 只命中 `data/BackupRepository.ets`，`ReaderPage.ets` 零命中；设置页 36 个真实条目里 34 个只有页面 `@State`，退出即丢。要接这些字段，等于先用 ArkUI 重写一套阅读页菜单（顶栏 / 底栏 / 悬浮图标 / 模糊 / 液态玻璃），属一整轮的工作量。

**另有一层备份侧证据**：这些 `readMenu*` 外观键在 `config.xml` 的两个方向都不走——导出只写 24 个键（`BackupRepository.ets:515-557`），恢复只读约 40 个键（`:1118-1255`，含 `readMenuIconShowText`/`readMenuIconStyle`/`readMenuIconItemsPerRow`/`readMenuIconRowCount` 四个已接的），且这批键只出现在 `preferenceKeysByCategory.readConfig`（`:234-256`）的忽略清单里。**因此即使现在把字段接上，也读不到 Android 备份里的值**；真正的补齐顺序是先建渲染层，再把键加进导出/恢复两组。

**KI-E1 菜单配色与亮度九项（要接，随菜单渲染层）** —— 覆盖 E-01 工具栏样式（`ReadBookConfig.kt:99`）、E-02 调色板风格（`:113`）、E-03 菜单颜色来源（`:99`）、E-04 种子色（`:62`）、E-05 菜单背景颜色（`:117`）、E-06 菜单容器颜色（`:123`）、E-07 菜单强调颜色（`:120`）、E-08 显示亮度视图（`:94`）、E-09 亮度条位置（`:95`）。上游这组由 `resolvedMenuBgColor`/`resolvedMenuAccentColor`/`resolvedMenuContainerColor`（`ReadBookConfig.kt:154/:180/:183`）三套解析器统一产出日/夜/EInk 三份取色，本地连取色器都只落在 `@State`。

**KI-E2 边框与模糊七项（要接，随菜单渲染层）** —— 覆盖 E-10 菜单栏边框（`ReadBookConfig.kt:88`）、E-11 边框宽度（`:115`，夹 0–4）、E-12 边框颜色（`:88-89`）、E-13 模糊半径（`:109`，夹 0–32）、E-14 模糊透明度（`:110`，夹 0–100）、E-15 菜单文字颜色（`:90-91`）、E-16 菜单模糊颜色（`:111-112`）。这组依赖 ArkUI 的模糊/描边能力，需先做一次原型确认效果等价再上屏。

**KI-E3 标题栏图标四项（要接，随菜单渲染层）** —— 覆盖 E-17 显示标题栏图标（`ReadBookConfig.kt:92`）、E-18 标题栏悬浮图标配置（`:146`、`:149` 两个 `Map<String,String>`）、E-19 标题栏悬浮图标位置（`:116`，夹 0–3）、E-20 悬浮图标液态玻璃按钮（`:87`）。注意 E-18 的「标题栏悬浮图标配置」入口虽走 `handleMenuSettingsEntryClick()`（`ReaderSettingsPage.ets:470-472`），但 `:517-531` 的 `else` 分支只 `openDetailSheet`，**并未落盘**，仍属未接。

**KI-E4 底栏外观七项（要接，随菜单渲染层）** —— 覆盖 E-21 底栏圆角（`ReadBookConfig.kt:104`，夹 0–32）、E-22 底栏悬浮（`:82`）、E-23 底栏模糊（`:106`，夹 0–2）、E-24 底栏模糊透明度（`:110`）、E-25 底栏模糊样式（`:108`，夹 0–1）、E-26 底栏液态玻璃（`:86`）、E-27 底栏按钮液态玻璃（`:86` 同字段的按钮级开关）。本地底栏已能渲染（`ReaderPage.ets:3156-3171` 读 `showBottomActionText`/`bottomIconStyle`/`bottomRowCount`），缺的正是这层外观参数，属渲染层改造里最先能做的一块。

**KI-E5 标题栏形态八项（要接，随菜单渲染层）** —— 覆盖 E-28 标题栏胶囊（`ReadBookConfig.kt:85`）、E-29 标题栏模式（`ReadSettings.kt:12`，字符串三态）、E-30 标题栏紧凑（`ReadBookConfig.kt:81`）、E-31 标题栏图标样式（`:101`，夹 0–2）、E-32 顶栏模糊（`:105`，夹 0–2）、E-33 顶栏模糊样式（`:107`，夹 0–1）、E-34 顶栏液态玻璃按钮（`:83`）、E-35 合并标题栏按钮（`:84`）。E-29 的本地选项文案为「完整信息 / 仅标题 / 标题与章节」（`ReaderSettingsPage.ets:570`），一旦有顶栏即可直接接。

**KI-E6 无上屏条目五项（要接，需先补上屏）** —— 覆盖 E-36 菜单镜头半径（`ReadBookConfig.kt:114`，夹 0–48f）、E-37 自动亮度（`:97`）、E-38 阅读栏样式（`ReadSettings.kt:69`，默认 1）、E-39 阅读栏样式跟随页面（`:68`）、E-40 更多操作配置（`:121`）。这五项连设置条目都没有：`getMenuSettingsEntries()`（`ReaderSettingsPage.ets:1788-1840`）里查无对应项，上游消费点却真实存在（`readBarStyle` 在 `data/repository/ReadSettingsRepository.kt:209` 夹 0–2 并被 `help/storage/BackupConfig.kt:216` 列入备份键；`moreActionsConfig` 被 `ReadBookViewModel.kt:2150` 解析为「更多」面板条目）。要接得先补上屏。

### B 页眉页脚

B 块唯一的 `未接` 行（页眉/页脚独立字体）已于 2026-10-31 复核改判 `已接`：排版设置面板的字体目标四按钮可选「页眉」「页脚」并落 `headerFont`/`footerFont`。**残留问题**：页眉页脚 tab 里那条「选择字体」（`ReaderSettingsPage.ets:799-801`）仍走 `showNotMigrated('页眉/页脚字体选择')`，是重复的占位入口，功能已由排版设置面板提供。补法：把该行改指向 `openFontSelection()` 并带 `fontTarget: 'header'`，属一行改动，本轮不动。

## 设备范围

- API 12 真机兼容尚未验证。HOS 模拟器检查只代表验证记录中列出的操作；N 端 API 26 数据不作为 E 端或 API 12 结论。
- r257 设备没有自定义分组，卡片上新增的私有标记/刷新状态文案未在设备上直接显示验证。

构建与设备记录见[验证记录](VALIDATION.md)，Android ZIP 字段边界见[备份恢复说明](BACKUP-RESTORE.md)。
