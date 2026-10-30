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

本节登记 2026-10-30 第五批（preferences 老数据清理）设备验收后仍待处理的三项，**只登记未实施**。

1. **`RdbCleanup` 漏删两个键**。`legado_read_records` 里的 `details_v1` 与 `summaries_v1` 未被清理，实测设备上仍在。这两个键存的是第三批之前的老格式「按日明细」与「书籍汇总」，第三批起已改存 `readRecordDetail` / `readRecord` 两表，全仓 `.ets` 已无读取点（`grep -rn "details_v1\|summaries_v1" --include=*.ets` 零命中），属纯残留。修法两处必须同时做：`entry/src/main/ets/data/RdbCleanup.ets:101` 的 `deleteKeys(context, 'legado_read_records', ['sessions_v1'])` 改为 `['sessions_v1', 'details_v1', 'summaries_v1']`；`entry/src/main/ets/data/RdbCleanup.ets:25` 的 `markerKey` 由 `rdb_cleanup_v1_1` 提到 `rdb_cleanup_v1_2`——**只改第一处无效**，因为标记已写的设备不会重跑清理。

2. **书签与划线的设备验收在模拟器上走不通**。`bookmarks` 与 `book_marks` 在第五批验收中始终为 0 行，新代码下的写入路径未经验证。已验证可行的入口是：进阅读页 → 长按正文 → 选词菜单（复制 / 书签 / 划线·笔记，y 366–493）→ 点「书签」→「添加书签」面板 → 保存。但该手势在模拟器上极不稳定：本轮只在首次成功一次，之后 12 次循环探测、5 个不同纵坐标（900/1200/1500/1800/2100）、重启、双击、慢速拖拽、`uinput -T` 触摸轨迹、菜单开合状态下长按均无法复现；且**首次成功那一轮点「保存」落在了面板外**（面板关闭但未入库），保存按钮的准确 bounds 从未 dump 到。注意 `uitest uiInput longClick` 稳定返回 `No Error` 却不保证手势被应用识别，返回码不能当成功依据。这与 r281 节的既有结论一致（正文走滚动模式，长按划词在模拟器上一直不可靠），**不是本次改动引入的问题**。后续两条替代路径：① 数据层直接构造标记行 + 渲染像素比对（r281 验证划线渲染用的就是此法，做过「改 DB 颜色 → 界面由黄变红」的决定性验证）；② 改在真机上走完整 UI 闭环。另注意底栏默认只启用 `['search','autoPage','catalog','voice','settings']`（`entry/src/main/ets/data/ReaderSettingsRepository.ets:292`），`addBookmark` 不在其中，所以底栏没有书签按钮，长按选词是唯一入口。

3. **按书净化开关的冷启闭环未验**。`book_overrides_v1` 已搬进 `books.readConfig.useReplaceRule`，读写路径已构建通过（设备实测两本书的 `readConfig` 为 `{"reSegment":false,"fixedType":false}`，无 `useReplaceRule` 键，符合「未设置 = 跟随全局默认」），但「关掉某一本书的净化 → 冷启 → 仍关闭」这条闭环没有上机走。验收要点：关闭后 `books.readConfig` 应出现 `"useReplaceRule":false`，重启后阅读该书的替换仍不生效，重置后该键应重新消失。

## 设备范围

- API 12 真机兼容尚未验证。HOS 模拟器检查只代表验证记录中列出的操作；N 端 API 26 数据不作为 E 端或 API 12 结论。
- r257 设备没有自定义分组，卡片上新增的私有标记/刷新状态文案未在设备上直接显示验证。

构建与设备记录见[验证记录](VALIDATION.md)，Android ZIP 字段边界见[备份恢复说明](BACKUP-RESTORE.md)。
