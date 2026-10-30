# 书签 / 划线 / 笔记 对照表

本表按 [模块对照要求](../CODE-CONVENTIONS.md) 第四节点完一次，行粒度是一次用户可感知的操作。
状态四值：`已接` / `未接` / `不适用` / `待定`；`不适用` 写理由，`待定` 写阻塞项。**本表无 `待定` 行。**

- 盘点日期：2026-10-29，复核 2026-10-30（第二轮独立复核，新增 6 条、拆细划词菜单）
- 上游基线：`legado-with-MD3`（Android，Compose）
- 本地实现：`entry/src/main/ets`（HarmonyOS，ArkTS）
- 对应 ZIP 类别：`bookmark`（`bookmark.json`、`bookMarking.json`），见 [ZIP 兼容总账](STATUS.md)

## 盘面

上游接触面用 `scripts/upstream-surface.sh bookmark /n/HarmonyProjects/legado-with-MD3` 枚举：

- 关键词 `Bookmark|BookMarking`（见[对照关键词](KEYWORDS.md)），**内容引用命中 63 个 .kt 文件**、646 行；
- 若按类别键名当文件名去找只有 20 个，**差额 43 个只能靠内容引用找到**——这正是 [编码规约](../CODE-CONVENTIONS.md) 第四节强调「不按文件名划」的实例。

| 块 | 条数 | 已接 | 未接 | 不适用 |
| --- | --- | --- | --- | --- |
| A 阅读页书签 | 21 | 20 | 1 | 0 |
| B 阅读页划线 / 笔记 | 21 | 15 | 5 | 1 |
| C 目录页信息 / 书签 / 笔记三 tab | 15 | 12 | 3 | 0 |
| D 所有书签页 | 13 | 13 | 0 | 0 |
| E 数据、导出与备份 | 15 | 12 | 0 | 3 |
| 合计 | 85 | 72 | 9 | 4 |

> **9 条未接全部是用户可感知的能力缺口，已在 [已知问题](../KNOWN-ISSUES.md) 登记**：①划线/笔记渲染不校验锚点文本（已设备取证）；②划词菜单缺「行内快速标记」；③目录页缺书签/笔记多选与批量操作；④目录页缺书签/笔记反序；⑤书签无障碍播报；⑥划词菜单「替换」缺预填规则入口；⑦划词菜单「搜索内容」缺预填关键词入口；⑧划词菜单另外 8 项本地确实无对应能力（分享 / 浏览器 / 朗读 / 词典 / 正文编辑 / AI 清洗 / AI 改写 / 插入 BGM）；⑨目录页信息 tab 缺「备注」行。
>
> 其中 ⑥⑦ 属「底层能力已具备、只差一个入口」，与 ⑧ 的「本地完全没有这个能力」是两回事，2026-10-30 复核时拆开登记。
>
> 4 条 `不适用` 都是上游内部形态，理由逐行写在表内：无 Room 数据库、无 AI 助手、移出书架本就不清书签、Android 独有的 `ACTION_PROCESS_TEXT` 文本扩展。
>
> 另有两项与书签相关但**不属于本类别**，故不设行：目录页「拆分超长章节」（属目录能力，`Book` 模型无 `splitLongChapter` 字段，已记在[已知问题](../KNOWN-ISSUES.md)目录页那条）与目录页「更多」菜单里的「新建替换规则并预填本书作用域」（属替换净化类别，已记在[已知问题](../KNOWN-ISSUES.md)目录页那条）。
>
> 注意别把后者与 B 块新增的「划词菜单『替换』项（预填规则）」混为一谈：两者入口不同（目录页更多菜单 vs 阅读页划词菜单）、预填内容也不同（前者预填 `scope` 为本书，后者把选中文本当 `pattern` 并预填 `scope`），但**卡在同一处**——`ReplaceRuleEditor` 缺草稿通道。补一处即可同时解开两条。

## A 阅读页书签

上游主体：`ui/book/read/ReadBookmarkDelegate.kt`（180 行）、`ui/widget/components/bookmark/BookmarkEditSheet.kt`、`ui/book/read/BookmarkBadgeDelegate.kt`、`feature/reader/core/model/ReaderBookmarkState.kt`。
本地主体：`entry/src/main/ets/pages/ReaderPage.ets`、`pages/ReaderBookmarkEditor.ets`、`pages/Index.ets`（书签域方法）。

| 上游能力 | 上游位置 | 本地位置 | 状态 | 差异说明 | 验收方式 | 备注 |
| --- | --- | --- | --- | --- | --- | --- |
| 菜单/工具栏「添加书签」 | `ReadMenuActionDefs.kt:206`、`:423`；`ReaderMoreActionsSheet.kt:371` | `ReaderPage.ets:59`、`:1137`、`:1388` | 已接 | 底部菜单项与文案一致 | 阅读页点「添加书签」出面板 | — |
| 长按菜单「添加书签」 | `ReadBookMenuBarFloating.kt:247` | `ReaderPage.ets:1137` | 已接 | 本地长按与点按走同一入口 | 长按呼出菜单见该项 | — |
| 当前页书签切换（有则删、无则加） | `ReadBookmarkDelegate.kt:98 toggleForCurrentPage` | `Index.ets:1131 toggleReaderBookmarkForPage` | 已接 | 本地按页首/页尾区间找最近一条书签，命中即删 | 同一页连续点两次，书签增删各一次 | 上游 `ToggleBookmark` 意图同语义 |
| 分页未完成时禁止加书签 | `ReadBookmarkDelegate.kt:141 addForCurrentPage` | `ReaderPage.ets:1282` | 已接 | 本地 toast「当前页尚未完成分页，暂时无法添加书签」 | 立刻点添加书签见提示 | — |
| 添加时用当前页正文预填原文 | `ReadBookmarkDelegate.kt:141` | `ReaderPage.ets:1287`、`:2107` | 已接 | 传入 `start` 与当前页语义正文 | 面板打开时「原文」非空 | 划词加书签时取选区文字 |
| 书签编辑面板（原文 + 备注两输入框） | `BookmarkEditSheet.kt:105`（`bookmark_original_text`）、`:115`（`bookmark_note`） | `ReaderBookmarkEditor.ets:31-42` | 已接 | 两个 TextArea，标签「原文」「备注」 | 面板出现两个输入框 | — |
| 面板标题按新建/编辑切换 | `BookmarkEditSheet.kt:30` | `ReaderBookmarkEditor.ets:28` | 已接 | 「添加书签」/「编辑书签」 | 两种入口标题不同 | — |
| 面板显示书名与章名 | `BookmarkEditSheet.kt:91 BookmarkEditContent` | `ReaderBookmarkEditor.ets:29-30` | 已接 | 书名 + 章名（章名主色） | 面板顶部见书名章名 | — |
| 保存书签 | `BookmarkEditSheet.kt:62`（`action_save`） | `ReaderBookmarkEditor.ets:53`、`Index.ets:1201` | 已接 | 双字段一并写回 | 编辑后保存，重开面板值仍在 | — |
| 删除书签 | `BookmarkEditSheet.kt:49`（`delete`） | `ReaderBookmarkEditor.ets:47`、`Index.ets:1219` | 已接 | 仅编辑态显示删除 | 编辑态见「删除」，新建态不见 | — |
| 删除前二次确认 | `BookmarkEditSheet.kt:78-85`（`confirm_delete_bookmark`） | `Index.ets:1213` | 已接 | `AppAlertDialog` 同款两按钮 | 点删除先弹确认 | r275 补齐 |
| 书签按书查询（书名 + 作者） | `BookmarkDao.kt:26 flowByBook`、`BookmarkRepository.kt:16` | `ReaderBookmarkRepository.ets:8` | 已接 | 本地按 `bookId` 过滤 | 换书后读不到别书书签 | 上游键是书名作者，本地是 id |
| 书签按章节范围查询 | `BookmarkDao.kt:34 flowSearch`、`BookmarkRepository.kt:28` | `Index.ets:1139` | 已接 | 本地在内存里按 chapterIndex 区间过滤 | 翻页显示角标判定正确 | — |
| 当前页书签角标（默认黄色丝带） | `BookmarkBadgeDelegate.kt:30`、`ReaderBookmarkBadgeRenderer.kt:32` | `ReaderPage.ets:955-987`、`:2893` | 已接 | 贴在正文区右上角，随翻页动画一起偏移 | 有书签的页右上角出现丝带 | — |
| 自定义角标图片（SVG 与位图） | `BookmarkBadgeDelegate.kt:63 copyToAppStorage`、`ReaderBookmarkBadgeRenderer.kt:37-52` | `ReaderBookmarkBadgeRepository.ets:33 chooseImage`、`ReaderPage.ets:979-982` | 已接 | 支持 `.png/.jpg/.jpeg/.webp/.bmp/.svg`，上限 8 MB | 选图后角标变自定义图 | 上游存 `files/bookmark_badge.$ext` |
| 恢复默认角标 | `BookmarkBadgeDelegate.kt:51 clearBadgeImage` | `ReaderBookmarkBadgeRepository.ets:68 removeImage` | 已接 | 清空路径即回默认丝带 | 点「恢复默认」角标变丝带 | — |
| 角标尺寸设置 | `MoreConfigSheet.kt:309-325`；`ReadConfigUpdateDelegate.kt:649` | `ReaderSettingsRepository.ets:192,438`、`ReaderSettingsPage.ets:1655` | 已接 | 滑块 0–N dp，0 表示不显示 | 调小到 0 角标消失 | 上游默认 10dp，本地同 |
| 下滑添加书签（手势开关） | `PullBookmarkGesture.kt`（整文件）；`MoreConfigSheet.kt:304`；`PreferKey.kt:204` | `ReaderPage.ets:164`、`:1006`、`:2926`、`:3023`；`ReaderSettingsPage.ets:854` | 已接 | 阈值 80dp、纵向占优 1.5、提示「松手以添加书签」 | 开启后下拉一段见提示，松手生成书签 | 手势常量按上游取值 |
| 书签加入备份 ZIP | `Restore.kt:157`（`bookmark.json`）、`BackupConfig.kt:76` | `BackupRepository.ets:299`、`:712` | 已接 | 读写两侧都走 `ReaderBookmarkImporter`/导出 | 备份 ZIP 含 `bookmark.json`，恢复后书签还在 | 见 [ZIP 兼容总账](STATUS.md) |
| **划词菜单「书签」项** | `ReadBookController.kt:2158-2178`；`TextActionSelectionMenu.kt:590`；`ReadBookIntent.TextActionBookmark:866` | `ReaderPage.ets:2070`、`:2096-2109` | 已接 | 用选区文字为 `bookText` 新建书签，随后打开编辑面板 | 划词点「书签」直接出面板且原文已填 | r273 补齐 |
| 书签无障碍播报 | `ReaderAccessibilityPolicy.kt:19`（`isBookmarked`） | — | 未接 | 本地无阅读页无障碍策略层，`entry/src/main/ets` 全仓只有一处 `accessibilityText`（`ProfileSubPages.ets:3579`，与阅读无关） | 读屏软件播报「已加书签」 | 上游在 `feature/reader/core/accessibility`，本地无对应模块 |

## B 阅读页划线 / 笔记

上游主体：`ui/book/read/MarkingDelegate.kt`、`ui/book/read/sheet/MarkingSheet.kt`（469 行）、`domain/usecase/SaveMarkingUseCase.kt`、`domain/model/BookContentProcessEngine.kt`、`help/book/ContentProcessor.kt`。
本地主体：`entry/src/main/ets/pages/ReaderMarkingEditor.ets`、`pages/ReaderPage.ets`（切段与渲染）、`data/ReaderMarkingRepository.ets`、`data/BookContentProcessEngine.ets`。

| 上游能力 | 上游位置 | 本地位置 | 状态 | 差异说明 | 验收方式 | 备注 |
| --- | --- | --- | --- | --- | --- | --- |
| 划词菜单「笔记 / 划线」项 | `ReadBookController.kt:2158-2178`；`MarkingContract.kt:21-32` | `ReaderPage.ets:2073`、`:1989` | 已接 | 无本地正文时 toast「划线与笔记仅支持已有本地正文的书籍」 | 划词点「划线 / 笔记」出面板 | r273 把三项并排 |
| 划词菜单「替换」项（预填规则） | `ReadBookController.kt:2065-2068`、`:2165`；`ReadBookRouteScreen.kt:426-433`（划词文本按行 `trim` 后当 `pattern` 新建规则，`bookName`/`bookSourceUrl` 拼成 `scope`） | `ProfileSubPages.ets:660-700 ReplaceRuleEditor` | 未接 | 规则编辑器本身完整，但只接受 `editingRule: ReplaceRule` 整条回填（`:706 applyEditingRule`），**没有「预填 pattern」的草稿通道**，`Index.ets` 也只暴露 `openReplaceRuleEditor(id)` | 划词点「替换」应带出预填正则的新建规则面板 | r280 复核；见 [已知问题](../KNOWN-ISSUES.md) |
| 划词菜单「搜索内容」项（预填关键词） | `ReadBookController.kt:2096-2099`、`:2169`；`ReadBookViewModel.kt:1564-1569`（`searchContentQuery` + `OpenSearch(text, bookUrl)`） | `ReaderSearchPage.ets`、`Index.ets:4104-4112` | 未接 | 全书搜索页完整（历史/正则/替换开关都有），但 `aboutToAppear`（`ReaderSearchPage.ets:52`）只加载历史，**没有 `initialQuery` 入参**，`Index.ets` 打开时也未传关键词 | 划词点「搜索内容」应带出预填关键词的全书搜索页 | r280 复核；见 [已知问题](../KNOWN-ISSUES.md) |
| 划词菜单其余 8 项（分享 / 浏览器 / 朗读 / 词典 / 正文编辑 / AI 清洗 / AI 改写 / 插入 BGM） | `ReadBookController.kt:2159-2183`（菜单项）、`:2036-2110`（处理）、`:2266-2287`（分享/浏览器） | — | 未接 | 本地确实无对应能力：分享全仓无 `systemShare`（`BookInfoPage.ets:269` 自己也是「书籍分享尚未迁移」）；浏览器全仓无 `startAbility`，`module.json5` 无 browser skill；朗读 `ReaderPage.ets:1265` 明确「朗读播放尚未迁移」；词典 / 正文编辑 / AI 清洗 / AI 改写 / BGM 全仓零命中 | — | 按项目约定不塞占位，`ReaderPage.ets:2062` 注释已说明 |
| 第三方 `ACTION_PROCESS_TEXT` 菜单项 | `ReadBookController.kt:2190-2206`（`queryIntentActivities`）；`:2210-2216` 受 `showSelectMenuIcon` / `textSelectMenuConfig` 控制 | — | 不适用 | Android 独有的文本处理扩展机制，HarmonyOS 无对等物，无法映射成任何本地能力 | — | 架构差异 |
| 标记面板（样式 + 颜色 + 笔记） | `MarkingSheet.kt:72` | `ReaderMarkingEditor.ets:210-490` | 已接 | 三块齐全，另有「样式来源」 | 面板见样式/颜色/笔记 | — |
| 样式来源：套用高亮规则 | `MarkingSheet.kt:187-197`（`state.highlightRules` 下拉） | `ReaderMarkingEditor.ets:352-400` | 已接 | 选规则时把规则样式换算成 effect + color | 选一条规则后样式与颜色随之变 | r269 补齐；上游存 `styleJson`，本地拍平 |
| 样式来源：自定义 | `MarkingSheet.kt:282 MarkingColorRow`、`:353 MarkingEffectGrid` | `ReaderMarkingEditor.ets:419`、`:430` | 已接 | 7 种 effect + 15 预设色 + 取色器 | 切「自定义」可任选样式与颜色 | r266 起 |
| 颜色预设与取色器 | `MarkingSheet.kt:305-324` | `ReaderMarkingEditor.ets:299 pickColor`、`:306 ColorPickerPanel` | 已接 | 支持 `#RRGGBB` 与 `#AARRGGBB`，背景色叠加约 20% 透明 | 输入十六进制色值后色块变色 | — |
| 笔记备注输入 | `MarkingSheet.kt:118 noteState` | `ReaderMarkingEditor.ets:463-470` | 已接 | TextArea「添加笔记（可选）」 | 输入后保存，再开面板仍在 | — |
| 选区已有标记时转编辑态 | `SaveMarkingUseCase.kt:66`（`find` 按位置 + 文本去重） | `Index.ets:1018-1024` | 已接 | 本地按 `bookId + chapterIndex + chapterPosition + selectedText` 找重 | 同一选区再划一次直接进编辑 | 上游 `normalizeProcessText` 归一化，本地 `trim()` |
| 保存标记（新建 / 更新） | `SaveMarkingUseCase.kt:50 save` | `Index.ets:1052 saveReaderMarking` | 已接 | 同 id 覆盖，`updatedAt` 刷新 | 改样式保存后正文样式变 | — |
| 删除标记 | `SaveMarkingUseCase.kt:141 delete` | `Index.ets:1088 deleteReaderMarking` | 已接 | 面板内「删除」直删 | 删除后正文恢复原样 | — |
| 按段落切分渲染标记区间 | `BookContentProcessEngine.kt:25-46`（`KIND_USER_UNDERLINE`/`KIND_USER_HIGHLIGHT`） | `ReaderPage.ets:2111-2150 getReaderHighlightTextRuns` | 已接 | 标记区间优先于全局高亮规则 | 标记处样式不被规则盖掉 | — |
| 七种划线/高亮效果渲染 | `TextProcessStyle`（`underlineMode` 等）；`ContentProcessor.kt:270-296 toRenderProcess` | `ReaderMarkingRepository.ets:8`（effects）、`ReaderPage.ets:2326`、`:2431` | 已接 | solid/double/dashed/wave/strike/highlight/background | 每种效果在正文可辨 | 上游 `fromStyle` 不认「双下划线」，本地补了 |
| **标记渲染前校验锚点文本** | `BookContentProcessEngine.kt:25-46`（`findTargetRange` 为空则不计入）、`:101-131`（三级退让重定位） | `ReaderPage.ets:1999 getMarkingForTextRange` | 未接 | 本地只判 `chapterPosition < end && endPosition > start` 相交，**完全不看 `selectedText`**；等价能力 `BookContentProcessEngine.ets:93 findTargetRange` 已存在但没接到标记渲染 | 把正文改动后标记应重定位或不渲染，本地仍按旧偏移渲染 | **已设备取证**；见 [已知问题](../KNOWN-ISSUES.md) |
| 目录页标记按章节序定位 | `TocViewModel.kt:375 markingUiList`、`BookMarkingDao.kt:70` | `CatalogPage.ets:194-200` | 已接 | 本地按 `chapterIndex` 再按 `createdAt` 排 | 目录页笔记 tab 顺序与正文一致 | r272 补齐 |
| 标记所属书源标记（其他书源红字） | `ReaderBookSheet.kt:1320`（`isOtherSource`）、`:1346` | `CatalogPage.ets:227-231`、`ProfileSubPages.ets:2886` | 已接 | `bookUrl` 与当前书不同则标红「其他书源」 | 导入他书标记后见红字 | — |
| 标记加入备份 ZIP | `Restore.kt:163`（`bookMarking.json`）、`BackupConfig.kt:76` | `BackupRepository.ets:299`、`:797` | 已接 | `mergeMarkings` 合并后落盘 | 备份 ZIP 含 `bookMarking.json`，恢复后标记还在 | 见 [ZIP 兼容总账](STATUS.md) |
| **划词菜单「行内快速标记」模式** | `ReadBookRouteScreen.kt`（按 `MarkingUiState.inlineMode` 切换）；`ReadBookContract.kt:870 OpenQuickMarking`、`:871 OpenQuickMarkingEdit`、`:872 ApplyQuickMarking`、`:875 DismissQuickMarking` | — | 未接 | 本地只有 sheet 一条路径，无 inline 预览态（`previewStyle` / `inlineDirty` 未建模） | 划词后当场应用上次样式，不弹面板 | 见 [已知问题](../KNOWN-ISSUES.md) |
| 标记启用开关 | `BookMarkingRepository.kt:38 setEnabled`、`BookMarking.enabled` | `ReaderMarkingRepository.ets:52`（`enabled` 字段） | 已接 | 字段存盘、渲染门控读它 | 停用的标记不在正文显示 | 本地面板不提供开关，与上游 UI 同 |

> **不占独立行的上游文件**（属本块内部实现，无独立用户操作）：`MarkingDelegate.kt`、`ReadBookContract.kt`（意图枚举）、`SaveMarkingUseCase.kt:117 find`、`MarkingContract.kt`、`domain/gateway/BookMarkingGateway.kt`、`data/dao/BookMarkingDao.kt`、`di/appModule.kt`、`di/appDatabaseModule.kt`、`data/AppDatabase.kt`。

## C 目录页信息 / 书签 / 笔记三 tab

上游主体：`ui/book/read/sheet/ReaderBookSheet.kt`（`:1117 ReaderBookBookmarksPage`、`:1179`、`:1225`、`:1320`、`:1346`）、`ui/book/toc/TocScreen.kt`（`:666`、`:1005 BookmarkListContent`、`:1070 MarkingListContent`）、`ui/book/toc/TocViewModel.kt`（`:96 TocBookmarkItemUi`、`:108 TocMarkingItemUi`、`:338`、`:375`）。
本地主体：`entry/src/main/ets/pages/CatalogPage.ets`（560 行）。

| 上游能力 | 上游位置 | 本地位置 | 状态 | 差异说明 | 验收方式 | 备注 |
| --- | --- | --- | --- | --- | --- | --- |
| 书签页顶部搜索框 | `ReaderBookSheet.kt:1117`（`CompactSearchField`） | `CatalogPage.ets:431` | 已接 | 占位「搜索」，清空按钮条件显示 | 输入后列表只剩匹配项 | 按 `bookmark.content` 过滤 |
| 书签页「更多」导出菜单 | `ReaderBookSheet.kt:1117`（`export_bookmarks_json`/`_markdown`） | `CatalogPage.ets:296-305`、`:444` | 已接 | 两项 JSON / Markdown | 点开见两项，点后弹保存框 | — |
| 书签条目点按进编辑 | `ReaderBookSheet.kt:1225`（`onClick = onEditBookmark`） | `CatalogPage.ets:487` | 已接 | 本地与上游同口径 | 点条目出编辑面板 | r271 由「行内双按钮」改为整行 |
| 书签条目长按跳转正文 | `ReaderBookSheet.kt:1225`（`onLongClick = onBookmarkNavigate`） | `CatalogPage.ets:488-489` | 已接 | 500ms 长按 | 长按条目跳回正文并提示 | r271 |
| 当前章节条目高亮 + 定位图标 | `ReaderBookSheet.kt:1225`（`isDur` + `Icons.Default.LocationOn` 16dp） | `CatalogPage.ets:469-472`、`:485` | 已接 | 当前章节底色 `#303442`，右侧 `locate` 图标 | 停在第二章时第二章条目高亮 | r271 |
| 打开时自动滚到当前章节 | `ReaderBookSheet.kt:1179`（`scrollToItem(currentPosition)`） | `CatalogPage.ets:206-224`、`:496` | 已接 | 只自动定位一次，之后由用户滚动 | 从第十章进目录页，书签列表停在第十章附近 | r271 |
| 书签条目两行正文 + 主色备注 | `ReaderBookSheet.kt:1225`（`bookText` 2 行、`content` primary 2 行） | `CatalogPage.ets:474-482` | 已接 | `bookText` `#BFC1CA`、`content` `#AFC2FF` 均 2 行 | 长原文被截为两行 | r271 |
| 信息页四行（作者 / 书源 / 备注 / 简介） | `ReaderBookSheet.kt:504-538 ReaderBookInformation`（`:524` 作者、`:526` 书源、`:531-533` 备注、`:534-536` 简介） | `CatalogPage.ets:330-346` | 未接 | 本地只有作者（`:334`）、书源（`:335`）、简介（`:336-338`）三行，**缺「备注」行**；本地 `model/Book.ets:46 remark?: string` 字段存在，只是界面没渲染。上游 `:531` 是 `remark.takeIf { it.isNotBlank() }` 条件显示，本地补时照抄条件即可 | 给书加备注后目录页信息 tab 应多一行「备注」 | r280 复核新发现；见 [已知问题](../KNOWN-ISSUES.md) |
| 笔记条目点按进编辑 / 长按跳转 | `ReaderBookSheet.kt:1300-1304`（注释明写「与书签一致，点按进入编辑（MarkingSheet），长按跳转到标记位置」）、`:1330-1348` | `CatalogPage.ets:517-548` | 已接 | 本地与上游**实际在用的**阅读面板同口径。注意上游 `TocScreen.kt:1103` 是另一套（点按=跳转、无长按），但 `TocScreen` 全仓无调用点，属未接线代码，不作为基线 | 点笔记条目出编辑面板，长按跳回正文 | r280 复核确认不是缺口 |
| 笔记页空态 | `ReaderBookSheet.kt:1320`（`marks_empty`） | `CatalogPage.ets:506` | 已接 | 「暂无笔记」/「没有找到相关笔记」 | 无笔记时见空态 | — |
| 笔记条目第一行：创建时间 + 章名 | `ReaderBookSheet.kt:1346`（`yyyy-MM-dd HH:mm`） | `CatalogPage.ets:518` | 已接 | 同样式 `yyyy-MM-dd HH:mm` | 第一行左侧时间、右侧章名 | r271 |
| 章名为空回退「第 N 章」 | `ReaderBookSheet.kt:1346`（`chapter_index_format`） | `CatalogPage.ets:151`、`:465`、`:521` | 已接 | 「第 N 章」，N = `chapterIndex + 1` | 章名为空的条目显示「第 3 章」 | — |
| 笔记条目两行正文 + 主色备注 | `ReaderBookSheet.kt:1346`（`text` 2 行、`note` primary 2 行） | `CatalogPage.ets:531-540` | 已接 | 与上游同 | 长笔记截两行 | r271 |
| **书签/笔记多选与批量操作** | `TocScreen.kt:325 selectionSecondaryActions`（反选 / 选中后续 / 批量加书签 / 批量去分组 / 批量删音频） | — | 未接 | 章节行与书签条目都只有单击，无选择模式 | 长按进选择模式后可批量操作 | 见 [已知问题](../KNOWN-ISSUES.md) |
| **书签/笔记反序** | `TocScreen.kt:447 reverse_toc` | — | 未接 | 本地无排序方向开关，恒按章节升序 | 点反序后列表倒排 | 见 [已知问题](../KNOWN-ISSUES.md) |

> `TocScreen.kt` 的书签 tab 用 `BookmarkItem`（`ui/widget/components/bookmark/BookmarkItem.kt:31`），而阅读页内的 `ReaderBookSheet` 用 `ReaderSheetBookmarkItem`——上游自己就有两套条目组件，本地目录页只迁了后者（`ReaderBookSheet` 那套）。`TocScreen.kt:1050` 的点击/长按语义是「点按跳转、长按跳转」，与阅读页内那套「点按编辑、长按跳转」不同，属上游两处口径不一致，本表按阅读页内那套收口。
>
> **2026-10-30 复核更正**：`TocScreen.kt` 与 `TocRouteScreen` 在全仓**没有任何调用点**（grep 只命中自身），上游这套 3-tab 目录页是未接线代码。上游真正在用的阅读面板是 `ReaderBookSheet.kt:275` 的 4 tab（information / chapter_list / bookmark / marks）。因此 C 块以 `ReaderBookSheet` 为准，`TocScreen` 只作为「上游曾设计过什么」的参考——③多选、④反序两条仍按缺口登记，是因为它们属真实存在但未接线的上游设计，是否补由用户定调；而「tab 数差异」（本地 4 tab = 信息/目录/书签/笔记）**不是缺口**，是本地自有设计且比上游在用版本少一层入口。

## D 所有书签页

上游主体：`ui/book/bookmark/AllBookmarkScreen.kt`（513 行）、`ui/book/bookmark/AllBookmarkViewModel.kt`（约 300 行）、`ui/main/my/MyScreen.kt:209-211`、`ui/main/MainNavGraph.kt:1781`。
本地主体：`entry/src/main/ets/pages/ProfileSubPages.ets`（`:2598 AllBookmarksPage`）、`pages/ProfilePage.ets:79`。

| 上游能力 | 上游位置 | 本地位置 | 状态 | 差异说明 | 验收方式 | 备注 |
| --- | --- | --- | --- | --- | --- | --- |
| 「我的」页书签入口 | `MyScreen.kt:209-211`（`PrefClickEvent.OpenAllBookmark`） | `ProfilePage.ets:79`、`:114` | 已接 | 行标题「书签」，图标 `profileBookmark` | 我的 → 书签进入 | — |
| 书籍总览（按书聚合） | `AllBookmarkViewModel.kt:170-186` | `ProfileSubPages.ets:1638`、`Index.ets:1599` | 已接 | 本地按 `bookId` 归并，上游按 `(书名, 作者)` | 每本书一张卡片 | 本地有 `bookId` 就不必回退键 |
| 搜索时只保留有匹配笔记的书 | `AllBookmarkViewModel.kt:170-186`（`filter { selectedBook != null \|\| query.isBlank() \|\| matchedMarkingId != null }`） | `ProfileSubPages.ets:2638` | 已接 | 同口径 | 搜一个只在笔记里存在的词，只列该书的笔记 | r274 收口 |
| 「包含匹配笔记」主色提示 | `AllBookmarkScreen.kt:356-410`（`feature_bookmarks_match_hint`） | `ProfileSubPages.ets:2841` 起 | 已接 | 命中时卡片显示该行 | 搜索命中笔记的卡片见提示 | r274 |
| 书籍卡片封面（52dp 宽） | `AllBookmarkScreen.kt:356-410`（`CoilBookCover`） | `ProfileSubPages.ets:2841` 起（`BookCover`） | 已接 | 复用 `components/BookCover.ets`，无封面时首字占位 | 卡片右侧出现封面 | r274 |
| 计数行「N 个书签 · N 个笔记」 | `AllBookmarksScreen.kt:356-410`（`feature_bookmarks_counts`） | `ProfileSubPages.ets:2841` 起 | 已接 | 文案与上游一致（r275 由「条」改为「个」） | 卡片见「1 个书签 · 0 个笔记」 | — |
| 两 tab：书签 / 笔记 | `AllBookmarkScreen.kt:75-78`（`BOOKMARK_TAB`/`NOTE_TAB`） | `ProfileSubPages.ets:2781` | 已接 | tab 标签带计数 `书签 N` / `笔记 N` | 切换 tab 列表内容变化 | — |
| 条目合并后按章节序 | `AllBookmarkViewModel.kt:200-216`（`compareBy(chapterIndex, chapterPosition)`） | `ProfileSubPages.ets:2646` | 已接 | 同口径 | 书签 tab 顺序与正文章节一致 | — |
| 条目正文最多 3 行 | `AllBookmarkScreen.kt:75-78`（`DETAIL_TEXT_MAX_LINES = 3`） | `ProfileSubPages.ets:2876` 起 | 已接 | `maxLines(3)` | 长条目截为 3 行 | — |
| 书签条目点按与长按都进编辑 | `AllBookmarkScreen.kt:424-513`（`onClick`/`onLongClick` 同绑 `editingBookmark`） | `ProfileSubPages.ets:2876` 起 | 已接 | 本地 r274 砍掉多余的「长按跳转」，两条路径都进编辑 | 点或长按书签条目都出编辑面板 | — |
| 笔记条目点按无行为 | `AllBookmarkScreen.kt:424-513`（Marking 分支无 `onClick`） | `ProfileSubPages.ets:2876` 起 | 已接 | 本地 r274 砍掉「点笔记跳转」 | 点笔记条目不跳转 | 上游就是不给行为 |
| 章名为空回退「第 N 章」 | `AllBookmarkScreen.kt:424-513`（`feature_bookmarks_chapter_fallback`） | `ProfileSubPages.ets:2876` 起 | 已接 | `chapterIndex + 1` | 空章名条目显示「第 2 章」 | — |
| 按书导出书签与笔记 | `AllBookmarkViewModel.kt` 导出路径；`help/bookmark/BookmarkExporter.kt:13 formatToMarkdown`、`:33 exportToUri` | `ProfileSubPages.ets:2701`、`Index.ets:960` 起、`ReaderBookmarkExporter.ets:149/176` | 已接 | 走 `{ bookmarks, notes }` 双数组 + 两小节 Markdown，文件名带 `-notes-` | 选中书后「更多」导出两种格式 | r274 |

## E 数据、导出与备份

| 上游能力 | 上游位置 | 本地位置 | 状态 | 差异说明 | 验收方式 | 备注 |
| --- | --- | --- | --- | --- | --- | --- |
| 书签实体字段 | `data/entities/Bookmark.kt` | `model/ReaderBookmark.ets` | 已接 | 11 字段与上游一致 | 导出的 `bookmark.json` 能被上游读回 | — |
| 标记实体字段 | `data/entities/BookMarking.kt` | `model/ReaderMarking.ets`、`ReaderMarkingRepository.ets:52` | 已接 | 本地 20 字段拍平存，上游是 `anchorJson + styleJson` 两段 JSON | 导出到 Android 时两者互转 | 上游字段见 `BookMarking.kt:11-30` |
| 恢复 `bookmark.json` | `Restore.kt:157`、`help/storage/Backup.kt` | `BackupRepository.ets:797`、`ReaderBookmarkImporter.ets:34 mergeBookmarks` | 已接 | 按 `(bookName, bookAuthor)` 找本地书 | 导入 Android 备份后书签出现 | — |
| 恢复 `bookMarking.json` | `Restore.kt:163` | `BackupRepository.ets:797`、`ReaderBookmarkImporter.ets:79 mergeMarkings` | 已接 | `resolveEffect` 把 `styleJson` 换算成 effect + color | 导入后划线样式正确 | — |
| 写出 `bookmark.json` | `help/storage/Backup.kt`（`dbKeyBookmark`） | `ReaderBookmarkExporter.ets:189`、`BackupRepository.ets` | 已接 | 字段与上游一致，含 `chapterPos` | Android 能读回本地导出的 ZIP | — |
| 写出 `bookMarking.json` | `help/storage/Backup.kt` | `ReaderBookmarkExporter.ets:196`、`:224 toAndroidMarking` | 已接 | 生成 `anchorJson`（含 `normalizedTextHash` md5）与 `styleJson` | Android 读回后划线位置正确 | — |
| 书签导出 Markdown | `BookmarkExporter.kt:13 formatToMarkdown` | `ReaderBookmarkExporter.ets:83 toMarkdown` | 已接 | 本书书签清单 | 导出后 Markdown 可读 | — |
| 书签导出 JSON 文件名带时间 | — | `ReaderBookmarkExporter.ets:117 buildFileName` | 已接 | `书名_yyyyMMdd_HHmm.json` | 文件名含时间戳 | 上游 `ReaderBookSheet.kt:1117` 同格式 |
| 恢复忽略项 `bookmark` | `BackupConfig.kt:76`（`dbKeyBookmark`）、`:97` | `BackupRepository.ets:322`、`:1539 isIgnored` | 已接 | 忽略该类别时两个条目都跳过 | 勾选忽略后恢复不带书签 | — |
| 标记数据随书籍删除清理 | `BookmarkRepository.kt:42 deleteAll`、`:50 delete` | `Index.ets:3127` 段 | 不适用 | 上游「移出书架」不清书签（`removeLocalBookFromShelf` 不碰书签表），本地同；专门的 `deleteAll` 本地无对应入口 | 移出书架后书签仍在 | 与上游一致，故不设行 |
| AI 工具检索书签 | `data/repository/AiToolRepository.kt:80 TOOL_SEARCH_BOOKMARKS`、`:267-283 searchBookmarks` | — | 不适用 | 本地无 AI 能力（[项目队列](../PROJECT.md)范围之外） | — | 理由：AI 助手整体未迁移 |
| 阅读页书签状态全局单例 | `model/ReaderBookmarkState.kt:16`（`object ReaderBookmarkState`）、`ReadBookmarkDelegate.kt:64 start` | `Index.ets:120`（`@State readerBookmarks`） | 已接 | 本地用页面级 `@State` 数组，上游用进程级单例 + Flow | 翻页时角标判定即时更新 | 本地随 `Index.ets` 生命周期 |
| 书签意图枚举 | `ReadBookContract.kt:672-677`、`:781-782`、`:866` | `ReaderPage.ets:310`（`onAddBookmark`）、`Index.ets:1131`、`:1201`、`:1219` | 已接 | 本地用回调替代意图总线 | 各入口行为可分别验证 | 架构差异，不设独立行 |
| 书签分渠道保存到不同表 | `AppDatabase.kt`、`di/appDatabaseModule.kt`、`di/appModule.kt` | `ReaderBookmarkRepository.ets:6`、`ReaderMarkingRepository.ets:6` | 已接 | 本地两个 preferences 文件（`legado_reader_bookmarks`、`legado_reader_markings`） | 杀进程重开数据仍在 | 存储介质不同，语义一致 |
| 数据库 DAO 层 | `data/dao/BookmarkDao.kt`、`data/dao/BookMarkingDao.kt` | — | 不适用 | 本地无 Room，仓储里直接读写 preferences 文本 | — | 理由：上游用 Room，本地无数据库 |

## 结论

1. **书签与划线的主干已经完整**：添加、编辑、删除（含二次确认）、角标、下滑手势、导出、备份往返、两个列表页（目录页内 + 所有书签页）全部通了，并且都上过设备。

2. **9 条未接全部是用户能感知的能力缺口**，其中 2 条是「底层能力已具备、只差一个入口」：
   - 划线/笔记渲染不校验锚点文本（唯一已设备取证的缺陷，会造成「正文变了标记还画在原偏移」）；
   - 划词菜单缺「行内快速标记」inline 模式；
   - 目录页缺书签/笔记多选与批量操作；
   - 目录页缺书签/笔记反序；
   - 书签无障碍播报（本地无阅读页无障碍策略层）；
   - 划词菜单「替换」缺预填规则入口（`ReplaceRuleEditor` 完整，缺 pattern 草稿通道）；
   - 划词菜单「搜索内容」缺预填关键词入口（`ReaderSearchPage` 完整，缺 `initialQuery`）；
   - 划词菜单另外 8 项（分享/浏览器/朗读/词典/正文编辑/AI 清洗/AI 改写/插入 BGM）本地确实无对应能力；
   - 目录页信息 tab 缺「备注」行（`Book.remark` 字段存在，只是没渲染）。

3. **4 条 `不适用` 是架构差异**，不产生独立操作：Room DAO 层、AI 工具检索、标记随书删除清理、Android 独有的 `ACTION_PROCESS_TEXT`。理由逐行写在 E 块与 B 块表内。另有若干上游内部形态（意图总线、Gateway、DI、进程级单例、图标名命中）未单列成行，已在各块小结注明。

4. **上游自身有两处口径不一致**，本表按阅读页内那套收口，并已在 C 块备注写明：目录页书签/笔记条目的点按/长按语义在 `ReaderBookSheet.kt` 与 `TocScreen.kt` 两处不同；且后者全仓无调用点，是未接线代码。

## 建议后续顺序

1. 先补「标记渲染前校验锚点文本」——它是唯一会让用户看到错误结果的缺陷，且本地 `BookContentProcessEngine.ets:93 findTargetRange` 已具备等价能力，接线成本低。
2. 再做目录页多选与反序——两者都是列表页交互，可一轮清完，且不依赖新数据字段。
3. 然后是两个「只差入口」的划词项：「替换」预填 pattern、「搜索内容」预填关键词。底层面板都完整，各自只需加一个可选入参（`ReplaceRuleEditor` 加 `initialPattern`、`ReaderSearchPage` 加 `initialQuery`），是本表里成本最低的两条。
4. 目录页信息 tab 补「备注」行——单行渲染，`Book.remark` 字段已在，`remark.takeIf { isNotBlank }` 条件照抄上游即可。
5. 然后是「行内快速标记」——需要新引入 `inlineMode`/`previewStyle`/`inlineDirty` 三个状态，属新面板形态，工作量最大。
6. 书签无障碍播报要等阅读页无障碍策略层落地（上游在 `feature/reader/core/accessibility`，本地无对应模块），可随无障碍整体迁移一起做。
7. 划词菜单剩下 8 项（分享 / 浏览器 / 朗读 / 词典 / 正文编辑 / AI 清洗 / AI 改写 / BGM）**不建议单独立项**：它们各自依赖一整个未迁移的子系统（系统分享、外部浏览器、TTS、词典、正文编辑、AI、BGM 场景），应按所属子系统各自推进，补齐后在 `ReaderPage.ets:2067-2073` 的菜单里挂入口即可。
8. 拆分超长章节属目录页能力（`Book` 需补 `splitLongChapter` 字段），与书签模块只有「第 N 章」回退这一处交集，可等目录页单独开一轮时一并处理——它不在本表行内。

## 维护

本表按模块维度组织，与 [ZIP 类别总账](STATUS.md) 的 `bookmark` 行对应：ZIP 维度只看 `bookmark.json`/`bookMarking.json` 的读写往返（本表 E 块），本表其余块覆盖书签/划线/笔记的全部用户可感操作。改本表时同步检查 [`STATUS.md`](STATUS.md) 的 `bookmark` 行链接与 [`KEYWORDS.md`](KEYWORDS.md) 的关键词是否仍一致。
