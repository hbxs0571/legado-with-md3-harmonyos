# 书签 / 划线 / 笔记 对照表

本表按 [模块对照要求](../CODE-CONVENTIONS.md) 第四节点完一次，行粒度是**一个界面**（不是界面上与本功能相关的几个按钮）。
状态三值：`已接` / `未接` / `不适用`；`不适用` 写理由。**本表无 `待定` 行。**

> **r286 结构性重盘（2026-10-30）**
>
> 一、**盘点方法换了两条**：①盘点单位由「操作的按钮」改为「整个界面」——只要涉及某界面（进了这个页、开了这个弹层、这个界面被改动），就把该界面完整列进表，未迁移的显式标 `未接`，不再只列与本功能相关的按钮；②完成判据仍是覆盖证明，见下面的「覆盖证明」节。
>
> 二、**A–E 块的行是迁移前证据，未逐行复核**：A/B/C/D/E 五块共 83 行写于 r277–r280（关系型存储迁移之前），本轮只修正了因 `book_marks` 改结构而失效的列名与字段引用（`bookId` 落库 → 读时派生、`styleJson` 不再拍平、`double` 已删除、`preferences` → SQLite 两张表），其余行未逐条重核。
>
> 三、**新增 F 块**：长按选词菜单按「整个界面」盘完，18 条菜单项 + 4 条菜单形态 + 8 条配置页自身 + 4 条持久化，共 34 行，详见块内。
>
> 四、**新增「覆盖证明」节**：63 个上游接触面文件逐个分配，未分配的写明排除理由。

- 盘点日期：2026-10-29，复核 2026-10-30（第二轮独立复核，新增 6 条、拆细划词菜单）
- 结构性重盘：2026-10-30（r286，改盘点单位、修失效引用、补 F 块与覆盖证明）
- 上游基线：`legado-with-MD3`（Android，Compose）
- 本地实现：`entry/src/main/ets`（HarmonyOS，ArkTS）
- 对应 ZIP 类别：`bookmark`（`bookmark.json`、`bookMarking.json`），见 [ZIP 兼容总账](STATUS.md)

## 盘面

上游接触面用 `scripts/upstream-surface.sh bookmark <上游根>` 枚举（`<上游根>` 指法见[对照关键词](KEYWORDS.md)的用法节）：

- 关键词 `Bookmark|BookMarking`（见[对照关键词](KEYWORDS.md)），**内容引用命中 63 个 .kt 文件**、646 行；
- 若按类别键名当文件名去找只有 20 个，**差额 43 个只能靠内容引用找到**——这正是 [编码规约](../CODE-CONVENTIONS.md) 第四节强调「不按文件名划」的实例。

| 块 | 条数 | 已接 | 未接 | 不适用 |
| --- | --- | --- | --- | --- |
| A 阅读页书签 | 20 | 19 | 1 | 0 |
| B 阅读页划线 / 笔记 | 20 | 15 | 4 | 1 |
| C 目录页信息 / 书签 / 笔记三 tab | 15 | 12 | 3 | 0 |
| D 所有书签页 | 13 | 13 | 0 | 0 |
| E 数据、导出与备份 | 15 | 13 | 0 | 2 |
| F 长按选词菜单（整界面，r286 新增） | 34 | 11 | 22 | 1 |
| 合计 | 117 | 83 | 30 | 4 |

> **A–E 的 83 行写于 r277–r280，是迁移前证据，未逐行复核**；F 块 34 行是 r286 按「整界面」新盘的。全表状态三值，无 `待定`。
>
> A 块 21 → 20：原「划词菜单『书签』项」一行移入 F1。B 块 21 → 20：「替换」「搜索内容」「其余 8 项」三行合并为指向 F 块的一句，留「划线/笔记」归属行。E 块 15 行不变但状态分布变了：原判 `不适用` 的「数据库 DAO 层」两行，在关系型存储迁移（r284）落地后本地已真有 SQLite 表，改判 `已接`，故 `不适用` 3 → 2。

> **30 条未接全部是用户可感知的能力缺口**，按块分布：A 1 条、B 4 条、C 3 条、F 22 条（F 里细分见 F 块小结），凡属缺陷而非缺功能的已记入 [已知问题](../KNOWN-ISSUES.md)。
>
> **A–C 块的未接 8 条**（D/E 两块全已接）：①书签无障碍播报（本地无阅读页无障碍策略层）；②标记渲染前校验锚点文本（`BookContentProcessEngine.kt:25-46`，**唯一已设备取证的缺陷**）；③划词菜单「行内快速标记」inline 模式；④划词菜单「替换」缺预填规则入口（`ReplaceRuleEditor` 完整，缺 pattern 草稿通道）；⑤划词菜单其余 8 项本地确实无对应能力（分享 / 浏览器 / 朗读 / 词典 / 正文编辑 / AI 清洗 / AI 改写 / 插入 BGM）；⑥目录页缺书签/笔记多选与批量操作；⑦目录页缺书签/笔记反序；⑧信息页四行缺「备注」行（`model/Book.ets:46 remark?: string` 字段存在，只是界面没渲染）。
>
> 其中 ④ 与 ⑤ 属「底层能力已具备、只差一个入口」，与「本地完全没有这个能力」是两回事，2026-10-30 复核时拆开登记。
>
> **F 块 22 条**是 r286 按「整界面」新盘出来的，此前被压成「划词菜单另外 8 项」一行：菜单项本体 11 条（分享 / 浏览器 / 朗读 / 词典 / 替换 / 正文编辑 / AI 清洗 / AI 改写 / 全文搜索 / 插入 BGM 前后）、菜单形态 4 条、配置页 3 条（拖拽排序 / 保存按钮 / 无障碍播报）、持久化 4 条。其中「替换」与「全文搜索」属「底层能力已具备、只差一个入口」，与「本地完全没有这个能力」是两回事，2026-10-30 复核时拆开登记。
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
| 书签按书查询（书名 + 作者） | `BookmarkDao.kt:26 flowByBook`、`BookmarkRepository.kt:28` | `ReaderBookmarkRepository.ets:22 selectAll` | 已接 | 存储无 `bookId` 列（对齐上游），读出时由 `bookUrl` 反推 `bookId`（`ReaderBookmarkRepository.ets:144 bookIdFromBookUrl`） | 换书后读不到别书书签 | r284 迁移后：本地也按 `bookName + bookAuthor` 存，`bookId` 只是读时派生 |
| 书签按章节范围查询 | `BookmarkDao.kt:34 flowSearch`、`BookmarkRepository.kt:28` | `Index.ets:1139` | 已接 | 本地在内存里按 chapterIndex 区间过滤 | 翻页显示角标判定正确 | — |
| 当前页书签角标（默认黄色丝带） | `BookmarkBadgeDelegate.kt:30`、`ReaderBookmarkBadgeRenderer.kt:32` | `ReaderPage.ets:955-987`、`:2893` | 已接 | 贴在正文区右上角，随翻页动画一起偏移 | 有书签的页右上角出现丝带 | — |
| 自定义角标图片（SVG 与位图） | `BookmarkBadgeDelegate.kt:63 copyToAppStorage`、`ReaderBookmarkBadgeRenderer.kt:37-52` | `ReaderBookmarkBadgeRepository.ets:33 chooseImage`、`ReaderPage.ets:979-982` | 已接 | 支持 `.png/.jpg/.jpeg/.webp/.bmp/.svg`，上限 8 MB | 选图后角标变自定义图 | 上游存 `files/bookmark_badge.$ext` |
| 恢复默认角标 | `BookmarkBadgeDelegate.kt:51 clearBadgeImage` | `ReaderBookmarkBadgeRepository.ets:68 removeImage` | 已接 | 清空路径即回默认丝带 | 点「恢复默认」角标变丝带 | — |
| 角标尺寸设置 | `MoreConfigSheet.kt:309-325`；`ReadConfigUpdateDelegate.kt:649` | `ReaderSettingsRepository.ets:192,438`、`ReaderSettingsPage.ets:1655` | 已接 | 滑块 0–N dp，0 表示不显示 | 调小到 0 角标消失 | 上游默认 10dp，本地同 |
| 下滑添加书签（手势开关） | `PullBookmarkGesture.kt`（整文件）；`MoreConfigSheet.kt:304`；`PreferKey.kt:204` | `ReaderPage.ets:164`、`:1006`、`:2926`、`:3023`；`ReaderSettingsPage.ets:854` | 已接 | 阈值 80dp、纵向占优 1.5、提示「松手以添加书签」 | 开启后下拉一段见提示，松手生成书签 | 手势常量按上游取值 |
| 书签加入备份 ZIP | `Restore.kt:157`（`bookmark.json`）、`BackupConfig.kt:76` | `BackupRepository.ets:299`、`:712` | 已接 | 读写两侧都走 `ReaderBookmarkImporter`/导出 | 备份 ZIP 含 `bookmark.json`，恢复后书签还在 | 见 [ZIP 兼容总账](STATUS.md) |
| 书签无障碍播报 | `ReaderAccessibilityPolicy.kt:19`（`isBookmarked`） | — | 未接 | 本地无阅读页无障碍策略层，`entry/src/main/ets` 全仓只有一处 `accessibilityText`（`ProfileSubPages.ets:3579`，与阅读无关） | 读屏软件播报「已加书签」 | 上游在 `feature/reader/core/accessibility`，本地无对应模块 |

## B 阅读页划线 / 笔记

上游主体：`ui/book/read/MarkingDelegate.kt`、`ui/book/read/sheet/MarkingSheet.kt`（469 行）、`domain/usecase/SaveMarkingUseCase.kt`、`domain/model/BookContentProcessEngine.kt`、`help/book/ContentProcessor.kt`。
本地主体：`entry/src/main/ets/pages/ReaderMarkingEditor.ets`、`pages/ReaderPage.ets`（切段与渲染）、`data/ReaderMarkingRepository.ets`、`data/BookContentProcessEngine.ets`。

| 上游能力 | 上游位置 | 本地位置 | 状态 | 差异说明 | 验收方式 | 备注 |
| --- | --- | --- | --- | --- | --- | --- |
| 划词菜单「笔记 / 划线」项 | `ReadBookController.kt:2158-2178`；`MarkingContract.kt:21-32` | `ReaderPage.ets:2073`、`:1989` | 已接 | 无本地正文时 toast「划线与笔记仅支持已有本地正文的书籍」 | 划词点「划线 / 笔记」出面板 | r273 把三项并排；r284 起划词菜单整体移入 F 块，本行只留「划线/笔记」这一项的归属 |
| 划词菜单「替换」项（预填规则）〔r286 起该项整体归 F 块，此处只留归属〕 | `ReadBookController.kt:2065-2068`、`:2165`；`ReadBookRouteScreen.kt:426-433` | `ProfileSubPages.ets:660-700 ReplaceRuleEditor` | 未接 | 规则编辑器完整，但只接受整条 `ReplaceRule` 回填，**没有预填 pattern 的草稿通道** | 划词点「替换」应带出预填正则的新建规则面板 | 明细见 F 块 |
| 划词菜单其余 8 项（分享 / 浏览器 / 朗读 / 词典 / 正文编辑 / AI 清洗 / AI 改写 / 插入 BGM） | `ReadBookController.kt:2135-2155`（菜单项）、`:2036-2110`（处理） | — | 未接 | 本地确实无对应能力：分享全仓无 `systemShare`；浏览器全仓无 `startAbility`，`module.json5` 无 browser skill；朗读 `ReaderPage.ets:1286` 明确「朗读播放尚未迁移」；词典 / 正文编辑 / AI 清洗 / AI 改写 / BGM 全仓零功能实现 | — | 逐项明细见 F 块 |
| 第三方 `ACTION_PROCESS_TEXT` 菜单项 | `ReadBookController.kt:2190-2206`（`queryIntentActivities`）；`:2210-2216` 受 `showSelectMenuIcon` / `textSelectMenuConfig` 控制 | — | 不适用 | Android 独有的文本处理扩展机制，HarmonyOS 无对等物，无法映射成任何本地能力 | — | 架构差异 |
| 标记面板（样式 + 颜色 + 笔记） | `MarkingSheet.kt:72` | `ReaderMarkingEditor.ets:210-490` | 已接 | 三块齐全，另有「样式来源」 | 面板见样式/颜色/笔记 | — |
| 样式来源：套用高亮规则 | `MarkingSheet.kt:187-197`（`state.highlightRules` 下拉） | `ReaderMarkingEditor.ets:352-400` | 已接 | 选规则时把规则样式写进 `styleJson` | 选一条规则后样式与颜色随之变 | r269 补齐；r284 起本地也存 `styleJson`，不再拍平 |
| 样式来源：自定义 | `MarkingSheet.kt:282 MarkingColorRow`、`:353 MarkingEffectGrid` | `ReaderMarkingEditor.ets:419`、`:430` | 已接 | 7 种 effect + 15 预设色 + 取色器 | 切「自定义」可任选样式与颜色 | r266 起 |
| 颜色预设与取色器 | `MarkingSheet.kt:305-324` | `ReaderMarkingEditor.ets:299 pickColor`、`:306 ColorPickerPanel` | 已接 | 支持 `#RRGGBB` 与 `#AARRGGBB`，背景色叠加约 20% 透明 | 输入十六进制色值后色块变色 | — |
| 笔记备注输入 | `MarkingSheet.kt:118 noteState` | `ReaderMarkingEditor.ets:463-470` | 已接 | TextArea「添加笔记（可选）」 | 输入后保存，再开面板仍在 | — |
| 选区已有标记时转编辑态 | `SaveMarkingUseCase.kt:66`（`find` 按位置 + 文本去重） | `Index.ets:1002-1008` | 已接 | 本地按 `bookId + chapterIndex + chapterPosition + selectedText` 找重（`bookId` 为读时派生值） | 同一选区再划一次直接进编辑 | 上游 `normalizeProcessText` 归一化，本地 `trim()` |
| 保存标记（新建 / 更新） | `SaveMarkingUseCase.kt:50 save` | `Index.ets:1052 saveReaderMarking` | 已接 | 同 id 覆盖，`updatedAt` 刷新 | 改样式保存后正文样式变 | — |
| 删除标记 | `SaveMarkingUseCase.kt:141 delete` | `Index.ets:1088 deleteReaderMarking` | 已接 | 面板内「删除」直删 | 删除后正文恢复原样 | — |
| 按段落切分渲染标记区间 | `BookContentProcessEngine.kt:25-46`（`KIND_USER_UNDERLINE`/`KIND_USER_HIGHLIGHT`） | `ReaderPage.ets:2111-2150 getReaderHighlightTextRuns` | 已接 | 标记区间优先于全局高亮规则 | 标记处样式不被规则盖掉 | — |
| 七种划线/高亮效果渲染 | `TextProcessStyle`（`underlineMode` 等）；`ContentProcessor.kt:270-296 toRenderProcess` | `ReaderMarkingRepository.ets:8`（effects）、`ReaderPage.ets:2326`、`:2431` | 已接 | `solid / dashed / wave / strike / highlight / background / text`（上游 7 种，逐字对齐） | 每种效果在正文可辨 | r284 起本地删除了上游没有的「双下划线」`double`，存量按 `solid` 处理 |
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
| 标记实体字段 | `data/entities/BookMarking.kt:11-30` | `model/ReaderMarking.ets`、`data/ReaderMarkingRepository.ets:118 toAnchorJson` / `:136 toStyleJson` | 已接 | 存储为 `anchorJson` + `styleJson` 两段 JSON（与上游同名同构），`id`/`bookUrl`/`chapterIndex`/`note`/`enabled`/`createdAt`/`updatedAt` 为普通列。模型仍 20 字段，`bookId` 与 `endPosition` 不落库 | 导出到 Android 时两者互转 | r284 迁移后与上游存储结构一致；`book_marks` 共 12 列 |
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
| 书签分渠道保存到不同表 | `AppDatabase.kt`、`di/appDatabaseModule.kt`、`di/appModule.kt` | `data/RdbSchema.ets:21`（`bookmarks`）、`:41`（`book_marks`） | 已接 | 本地两张 relationalStore 表，与上游同名同列 | 杀进程重开数据仍在 | r284 迁移后由 preferences 改为 SQLite，表结构与上游 `132.json` 逐字对齐 |
| 数据库 DAO 层 | `data/dao/BookmarkDao.kt`、`data/dao/BookMarkingDao.kt` | `data/ReaderBookmarkRepository.ets:22`、`data/ReaderMarkingRepository.ets:50` | 已接 | 本地无 Room，仓储里直接写 SQL，接口形态对齐 DAO | 各页书签读取行为可分别验证 | r284 前判「不适用（无数据库）」，迁移后改为已接 |

## F 长按选词菜单（整界面）

> 本块是 2026-10-30 重盘新增，依据 [编码规约](../CODE-CONVENTIONS.md) 第四节「盘点单位是界面，不是按钮」。此前的 A、B 块只记了「与本功能相关的那几项」（书签一项、划线一项、其余 8 项压成一行），把同一界面上的配置页、图标、形态切换、持久化全部漏掉了。本块把整个界面列全，A/B 块对应的行保留但改为指向本块。

上游主体：`ui/book/read/ReadBookController.kt`（`:2133-2155` 项定义、`:2179-2206` 按配置排序、`:2219-2230` 保存）、`ui/book/read/TextActionSelectionMenu.kt`（585 行；`:161`/`:178` 形态分派、`:585-600` 图标映射）、`ui/book/read/sheet/TextSelectMenuConfigSheet.kt`（460 行）。
本地主体：`pages/ReaderPage.ets:2085 readerMarkingSelectionMenu`（阅读页实弹菜单）、`pages/ReaderSettingsPage.ets:27-42` + `:1433-1524`（配置页）。

### F1 菜单项本体（14 个内置项）

本地实弹菜单只有 3 个纯文字项（`ReaderPage.ets:2085`：复制 / 书签 / 划线·笔记），无图标、无第 4 项起。以下 14 项全部列全，`已接` 只给真正在阅读页可用的。

| 上游能力 | 上游位置 | 本地位置 | 状态 | 差异说明 | 验收方式 | 备注 |
| --- | --- | --- | --- | --- | --- | --- |
| 复制 | `ReadBookController.kt:2133`（`menu_copy`） | `ReaderPage.ets:2092`、`:2103 copyCurrentSelection` | 已接 | 写系统剪贴板，无图标 | 划词点「复制」提示「已复制」 | — |
| 分享 | `ReadBookController.kt:2134`（`menu_share_str`） | — | 未接 | 全仓无 `systemShare`；`BookInfoPage.ets:269` 自身也是「书籍分享尚未迁移」 | 划词点「分享」调起系统分享面板 | — |
| 浏览器打开 | `ReadBookController.kt:2135`（`menu_browser`） | — | 未接 | 全仓无 `startAbility`，`module.json5` 无 browser skill | 划词点「浏览器」用外部浏览器打开选中文本 | — |
| 朗读 | `ReadBookController.kt:2136`（`menu_aloud`） | `ReaderPage.ets:1286`（提示未迁移） | 未接 | 底栏 `voice` 也走同一句「朗读播放尚未迁移」，TTS 整体未接 | 划词点「朗读」从选中处开始朗读 | — |
| 书签 | `ReadBookController.kt:2137`（`menu_bookmark`）；`ReadBookIntent.TextActionBookmark:866` | `ReaderPage.ets:2096-2109 bookmarkCurrentSelection` | 已接 | 以选区起点为 `chapterPos`、选区文字为 `bookText`，随后开编辑面板 | 划词点「书签」直接出面板且原文已填 | A 块保留同名行 |
| 标记（划线 / 笔记） | `ReadBookController.kt:2138`（`menu_mark`）；`MarkingContract.kt:21-32` | `ReaderPage.ets:2104-2109`、`:1989` | 已接 | 无本地正文时 toast「划线与笔记仅支持已有本地正文的书籍」 | 划词点「划线 / 笔记」出面板 | B 块保留同名行 |
| 词典 | `ReadBookController.kt:2139`（`menu_dict`） | — | 未接 | 本地有 `dictRule` 备份类别与 `LocalTextReSegmenter` 里的局部 `dict` 变量，但无查词能力 | 划词点「字典」弹出词义 | — |
| 替换 | `ReadBookController.kt:2140`（`menu_replace`） | `ProfileSubPages.ets:660-700 ReplaceRuleEditor` | 未接 | 规则编辑器完整，缺「预填 pattern」草稿通道；`Index.ets` 只暴露 `openReplaceRuleEditor(id)` | 划词点「替换」带出预填正则的新建规则面板 | 见 [已知问题](../KNOWN-ISSUES.md) |
| 编辑（正文） | `ReadBookController.kt:2141`（`menu_edit`） | — | 未接 | 无正文编辑入口。`ReaderSettingsPage.ets:36` 的 `menu_edit` 只是菜单清单里的一个 id 与图标，不是功能 | 划词点「编辑」可改写正文该段 | — |
| AI 清洗 | `ReadBookController.kt:2142`（`menu_ai_clean`） | `model/BookContentProcess.ets:49`（仅 `ai_clean` 常量） | 未接 | 只有 `CONTENT_PROCESS_KIND_AI_CLEAN` 常量与 `BookContentProcess` 记录类型，无 AI 调用；AI 助手整体不在范围 | 划词点「AI 清洗」返回清洗后文本 | — |
| AI 改写 | `ReadBookController.kt:2143`（`menu_ai_rewrite`） | `model/BookContentProcess.ets`（同上） | 未接 | 同「AI 清洗」 | 划词点「AI 改写」返回改写文本 | — |
| 全文搜索 | `ReadBookController.kt:2144`（`menu_search_content`）；`ReadBookViewModel.kt:1564-1569` | `ReaderSearchPage.ets`、`Index.ets:4104-4112` | 未接 | 搜索页完整（历史/正则/替换开关），但 `aboutToAppear`（`:52`）无 `initialQuery` 入参 | 划词点「全文搜索」带出预填关键词 | 见 [已知问题](../KNOWN-ISSUES.md) |
| 插入 BGM（段前） | `ReadBookController.kt:2146-2151`（`menu_insert_bgm_before`） | — | 未接 | 无音频插入能力（朗读与播放整体未接） | 划词点后在该段前插入音频标记 | — |
| 插入 BGM（段后） | `ReadBookController.kt:2146-2151`（`menu_insert_bgm_after`） | — | 未接 | 同上 | 段后插入音频标记 | — |
| 第三方 `ACTION_PROCESS_TEXT` 项 | `ReadBookController.kt:2157-2176`（`queryIntentActivities`）、`:2210-2216` | — | 不适用 | Android 独有文本处理扩展机制，HarmonyOS 无对等物 | — | 架构差异 |
| 菜单项图标 | `TextActionSelectionMenu.kt:585-600 builtInIcon` | `ReaderSettingsPage.ets:937-970 readerTextMenuIcon` | 已接（仅配置页） | 13 个图标资源齐全（`reader_menu_copy.svg` … `reader_menu_playlist_add.svg`，AI 两项共用 `smart_toy`），但**只有配置页在画，阅读页实弹菜单不画** | 配置页打开「显示菜单图标」后每项左侧见图标 | r286 核实资源全部存在 |
| 项级三档状态（一级 / 折叠 / 隐藏） | `ReadBookController.kt:3288`（`showState: Int`） | `ReaderSettingsPage.ets:146-149`（`textMenuEntries[i].group` 0/1/2） | 已接（仅配置页） | 数据结构与三档语义对齐，但没有持久化，也没有消费方 | 配置页把某项移到「隐藏项」后该区计数 +1 | — |
| 菜单显示条件（有选区才出） | `TextActionSelectionMenu.kt`（选区菜单基座） | `ReaderPage.ets:2378`、`:2425`、`:2482` `.bindSelectionMenu(... TextResponseType.LONG_PRESS ...)` | 已接 | 三处正文 Text 各绑一次 | 长按正文出菜单、单击不出 | — |

### F2 菜单形态

| 上游能力 | 上游位置 | 本地位置 | 状态 | 差异说明 | 验收方式 | 备注 |
| --- | --- | --- | --- | --- | --- | --- |
| 默认形态：一排主项 + 「更多」浮层 | `TextActionSelectionMenu.kt:161`、`:355 QuickMenuView`、`:469 MoreMenuView` | — | 未接 | 本地是单行 `Row`，没有「更多」与浮层 | 一级项超过一行宽度时出现「更多」，点开浮层显示折叠项 | — |
| 展开形态：多行平铺 | `TextActionSelectionMenu.kt:178`、`:311 MultiLineMenuView`（`FlowRow`，`.heightIn(max = 300.dp)` + `verticalScroll`） | — | 未接 | 无多行形态 | 打开「展开文字菜单」后所有项平铺、超高时可滚动 | — |
| 两套形态按 `expandTextMenu` 切换 | `ReadBookController.kt`；默认值 `ReadSettings.kt:49`（`false`） | `ReaderSettingsPage.ets:144 expandTextMenuPreview` | 未接 | 配置页有这个开关，但只是页面 `@State`，不持久化、不生效 | 切换后阅读页划词菜单形态随之改变 | — |
| 显示/隐藏菜单图标开关 | `ReadSettings.kt:51`（`showSelectMenuIcon`，默认 `true`） | `ReaderSettingsPage.ets:145 showTextMenuIconsPreview` | 未接 | 同上，仅预览态 | 关掉后配置页与阅读页菜单都不显示图标 | — |

### F3 配置页自身

| 上游能力 | 上游位置 | 本地位置 | 状态 | 差异说明 | 验收方式 | 备注 |
| --- | --- | --- | --- | --- | --- | --- |
| 配置页入口与标题 | `TextSelectMenuConfigSheet.kt:128`（`edit_select_menu`） | `ReaderSettingsPage.ets:884`（「选中文字菜单」入口）、`:1433` | 已接 | 入口文案「配置文本选择后的操作」 | 阅读设置 → 菜单 → 选中文字菜单 | — |
| 14 项清单与 id | `ReadBookController.kt:2133-2155` | `ReaderSettingsPage.ets:27-42 READER_TEXT_MENU_DEFAULTS` | 已接 | 14 项 id 与上游逐字一致，中文标题齐 | 配置页主菜单区显示 14 项 | — |
| 三个分区（主菜单 / 折叠菜单 / 隐藏项） | `TextSelectMenuConfigSheet.kt:176`、`:229`、`:287` | `ReaderSettingsPage.ets:1445-1516` | 已接 | 每区带条数、可折叠 | 三区各显示条数，点标题可折叠 | — |
| 组内上下移动排序 | `TextSelectMenuConfigSheet.kt:89 moveWithinGroup`、`:209`（无障碍播报） | `ReaderSettingsPage.ets:906-923 reorderTextMenuEntry` | 已接 | 上下箭头逐位交换 | 点下箭头后该项下移一位 | — |
| 跨分区移动 | `TextSelectMenuConfigSheet.kt:194`、`:248`（`groupActionContentDescription`） | `ReaderSettingsPage.ets:899 moveTextMenuEntry` | 已接 | 主菜单只能下移、折叠区可上下移、隐藏区只能上移 | 把某项从主菜单移到折叠菜单后两区计数同步变 | — |
| 拖拽排序（长按拖动） | `TextSelectMenuConfigSheet.kt`（`SelectMenuItemRow :329`、`HiddenItemsFlowView :374`） | — | 未接 | 本地只有箭头点按，无拖拽 | 长按某行可拖动改顺序 | — |
| 保存按钮 | `TextSelectMenuConfigSheet.kt:136`（`save`） | `ReaderSettingsPage.ets:1517-1523` | 未接 | 按钮在，点击走 `onUnavailableAction('选中文字菜单配置尚未保存')`，页面自己写着「均为预览，保存功能尚未迁移」 | 点保存后配置持久化，重开仍在 | **本块最关键的一条** |
| 无障碍播报（重排提示） | `TextSelectMenuConfigSheet.kt:209`、`:263`（`a11y_reorder_named`） | — | 未接 | 本地无该项播报 | 读屏软件播报「已移到第 N 位」 | — |

### F4 持久化链路

| 上游能力 | 上游位置 | 本地位置 | 状态 | 差异说明 | 验收方式 | 备注 |
| --- | --- | --- | --- | --- | --- | --- |
| 菜单配置落盘 | `ReadBookController.kt:2219-2230 saveMenuConfig` → `viewModel.setTextSelectMenuConfig(GSON.toJson(configs))` → `PreferKey.textSelectMenuConfig`（`constant/PreferKey.kt:154`） | — | 未接 | `grep -rn textSelectMenuConfig entry/src/main/ets` 零命中，配置页的三档状态只活在 `@State` | 改完保存、杀进程重开配置仍在 | — |
| 配置项结构 `{id, enabled, showState}` | `ReadBookController.kt:3323 SelectionMenuConfigItem` | `ReaderSettingsPage.ets:22-26 ReaderTextMenuEntry`（仅 `{id, title, group}`） | 未接 | 本地少了 `enabled` 维度（上游可单项禁用而不移出列表） | 配置里可单独禁用某项但保留位置 | — |
| 按配置顺序重排菜单 | `ReadBookController.kt:2179-2206`（`savedConfigs` 顺序重排、未记录的项追加在后） | — | 未接 | 阅读页菜单是硬编码 3 项，不读任何配置 | 配置里把「划线 / 笔记」放第一，阅读页菜单第一项随之变 | — |
| 两个开关的偏好键 | `PreferKey.kt:152 expandTextMenu`、`:153 showSelectMenuIcon`；默认值 `ReadSettings.kt:49-51` | — | 未接 | 未接进 `ReaderSettingsRepository` | 两个开关的值能在重启后保持 | — |

**F 块小结**：块内 34 条 = 已接 11、未接 22、不适用 1。分节看：菜单项本体 18 条里 **6 条已接**（复制 / 书签 / 标记 / 菜单项图标 / 项级三档状态 / 菜单显示条件，后三条都只在配置页成立）、11 条未接、1 条不适用；菜单形态 4 条全未接；配置页自身 8 条里 5 条已接、3 条未接；持久化 4 条全未接。**这个界面的形状是「壳齐了、线没接」**——14 项清单、13 个图标、三分区、排序与跨区移动都在，缺的是保存链路与阅读页消费。按成本排序，补的顺序应是 F4 → F2 → F3 拖拽，前两项补完，配置页立刻从预览变可用。

## 覆盖证明

判据见 [术语表](../GLOSSARY.md) 的 **覆盖证明**：上游接触面里每个 `.kt` 必须落到「已映射到某行」或「已排除 + 理由」，两者都没有就是未分配。

复现命令：

```bash
bash scripts/upstream-surface.sh --coverage bookmark docs/parity/ZIP-BOOKMARK.md <上游根>
```

（`<上游根>` 指法见[对照关键词](KEYWORDS.md)的用法节。）

r286 实跑：上游接触面 **63 个 `.kt`**，已分配 **63**，未分配 **0**。下表是这份分配本身——不是行数统计，是逐文件的处置。

### 一、映射到既有行（8 个，此前只是没在表里点名）

| 上游文件 | 命中的 bookmark 符号 | 映射到本表哪一行 |
| --- | --- | --- |
| `io/legado/app/data/repository/ReadSettingsRepository.kt` | `:400` `Keys.SwipeToAddBookmark`、`:401` `Keys.BookmarkBadgeImage`、`:402` `Keys.BookmarkBadgeSize` | A 块「下滑添加书签（手势开关）」「自定义角标图片」「角标尺寸设置」三行。本文件是这三项的配置读写端，本地对应 `data/ReaderSettingsRepository.ets:190`（`swipeToAddBookmark`）、`:196-199`（角标两项） |
| `io/legado/app/domain/usecase/VerifyBookmarkTargetUseCase.kt` | `:6-11` `sealed interface BookmarkTargetVerdict`（`Match` / `SourceChanged(storedBookUrl)`） | A 块书签跳转校验行。本地同构实现在 `data/ReaderBookmarkTarget.ets:8` `export type BookmarkTargetVerdict = 'match' \| 'sourceChanged' \| 'titleMismatch'`，调用点 `pages/Index.ets:1381`、`:1454` |
| `io/legado/app/ui/book/read/ReadBookmarkNavigateDelegate.kt` | `:3-7` import `BookMarking` / `Bookmark` / `BookmarkTargetVerdict` | 同上——上游把「校验 + 跳转 + 失败确认」收在一个委托类里，本地收在 `pages/Index.ets:1322 askJumpAnyway` / `:1380` 一段，语义一致 |
| `io/legado/app/ui/book/read/ReadBookScreen.kt` | `:20` `BookmarkTargetVerdict`、`:53` `BookmarkEditSheet`、`:72` `onPickBookmarkBadgeImage` | A 块书签编辑面板行 + 自定义角标图片行。上游这三个符号都是从控制器透传进 `ReadBookScreen` 的参数，本身无独立逻辑 |
| `io/legado/app/ui/main/MainNavKey.kt` | `:289` `data object MainRouteAllBookmark : MainRoute` | D 块「所有书签页」的路由键。本地对应 `pages/ProfilePage.ets:79` 入口 + `pages/ProfileSubPages.ets:2598 AllBookmarksPage` |
| `io/legado/app/ui/main/MainNavigator.kt` | `:330` `MainRouteAllBookmark`（导航注册） | 同上，同一个页面的注册端 |
| `io/legado/app/ui/main/MainScreen.kt` | `:174` `onNavigateToAllBookmark`、`:658` `PrefClickEvent.OpenAllBookmark -> onNavigateToAllBookmark()` | 同上，同一个页面的派发端 |
| `io/legado/app/my/MyViewModel.kt` | `:36` `object OpenAllBookmark : PrefClickEvent()` | D 块「「我的」页书签入口」行。`io/legado/app/my/` 前缀下只有一个 `.kt`，实际是「我的」页事件枚举 |

### 二、已排除：渲染管线差异（2 个）

| 上游文件 | 引用位置 | 排除理由 |
| --- | --- | --- |
| `io/legado/app/feature/reader/ReaderCanvasSurface.kt` | `:96-97` import `PullBookmarkDefaults` / `PullBookmarkGesture`、`:157` `ReaderBookmarkBadgeRenderer` | 上游是 Compose `Canvas` + 自绘管线，手势与角标都要手动挂进绘制层。本地是 ArkUI 组件树，手势走 `pages/ReaderPage.ets:2946 PanGesture` 声明式绑定、角标是独立组件叠在正文之上，没有对应的「surface 接线点」。**功能已在 A 块两行覆盖，本文件是架构差异不是缺口** |
| `io/legado/app/feature/reader/legacy/LegacyReaderPageDecorationFactory.kt` | `:9` import `ReaderBookmarkBadge`、`:108` 参数 `hasBookmark: Boolean = false`、`:158` `bookmarkBadge = ReaderBookmarkBadge.create(...)` | 同上。上游把「这一页有没有书签」传进页面装饰工厂，由工厂造出带角标的分页对象；本地没有页面对象，角标按 `chapterIndex + pageIndex` 现算现画（`pages/ReaderPage.ets:955-987`） |

### 三、已排除：仅图标名命中，功能属其他界面（4 个）

这四个文件在 `bookmark` 关键词下命中，是因为引用了 Material 图标常量（`Icons.Default.Bookmarks` 等），与书签功能无关。它们各自的界面归 `BOOKSHELF.md` 与 `STATUS.md` 的其他类别。

| 上游文件 | 引用位置 | 图标实际用途 | 归属 |
| --- | --- | --- | --- |
| `io/legado/app/ui/book/info/BookInfoScreen.kt` | `:52` import、`:1423` `else -> Icons.Default.BookmarkAdd` | 详情页「加入书架 / 已在书架」按钮的图标 | `localBook` 类别，见 [BOOKSHELF.md](BOOKSHELF.md) B 块 |
| `io/legado/app/ui/book/manage/BookshelfManageScreen.kt` | `:35` import、`:409` `Icons.Default.Bookmarks`、`:700` | 书架管理页的分类图标 | `bookGroup` / `bookshelfLayout` 类别，见 [BOOKSHELF.md](BOOKSHELF.md) A2/A3 块 |
| `io/legado/app/ui/book/searchContent/SearchContentScreen.kt` | `:25` import、`:383` `Icons.Default.CollectionsBookmark` | 搜索结果按书分组的图标 | `searchHistory` 类别，见 [ZIP 兼容总账](STATUS.md) |
| `io/legado/app/ui/main/bookshelf/BookshelfScreen.kt` | `:58` import、`:642` `Icons.Default.Bookmarks`、`:753` | 书架页分组筛选入口的图标 | `bookshelfLayout` 类别，见 [BOOKSHELF.md](BOOKSHELF.md) A1 块 |

### 未分配：0

本表在 `bookmark` 类别下已无未分配文件。新增上游文件或改 `KEYWORDS.md` 关键词后重跑上面的命令，未分配不为 0 就是盘点没做完。

## 结论

1. **书签与划线的主干已经完整**：添加、编辑、删除（含二次确认）、角标、下滑手势、导出、备份往返、两个列表页（目录页内 + 所有书签页）全部通了，并且都上过设备。

2. **30 条未接全部是用户能感知的能力缺口**，其中 2 条是「底层能力已具备、只差一个入口」。按块分布：

   **A–C 块 8 条**（D/E 两块全已接）：
   - 书签无障碍播报（本地无阅读页无障碍策略层）；
   - 标记渲染前校验锚点文本（`BookContentProcessEngine.kt:25-46`，**唯一已设备取证的缺陷**，会造成「正文变了标记还画在原偏移」）；
   - 划词菜单「行内快速标记」inline 模式；
   - 划词菜单「替换」缺预填规则入口（`ReplaceRuleEditor` 完整，缺 pattern 草稿通道）；
   - 划词菜单其余 8 项（分享 / 浏览器 / 朗读 / 词典 / 正文编辑 / AI 清洗 / AI 改写 / 插入 BGM）本地确实无对应能力；
   - 目录页缺书签/笔记多选与批量操作；
   - 目录页缺书签/笔记反序；
   - 信息页四行缺「备注」行（`model/Book.ets:46 remark?: string` 字段存在，只是界面没渲染）。

   **F 块 22 条**（r286 按「整界面」新盘，此前被压成「划词菜单另外 8 项」一行）：
   - 菜单项本体 11 条（分享 / 浏览器 / 朗读 / 词典 / 替换 / 正文编辑 / AI 清洗 / AI 改写 / 全文搜索 / 插入 BGM 前后）；
   - 菜单形态 4 条（一排+更多浮层、多行平铺、`expandTextMenu` 切换、图标开关）；
   - 配置页 3 条（拖拽排序、保存按钮、无障碍播报）；
   - 持久化 4 条（配置落盘、`enabled` 维度、按配置顺序重排、两个开关的偏好键）。

3. **4 条 `不适用` 是架构差异**，不产生独立操作：标记数据随书删除清理、AI 工具检索书签、Android 独有的 `ACTION_PROCESS_TEXT`（两处：阅读页菜单与选词菜单各一条）。理由逐行写在 E 块与 F1 表内。另注：E 块原「数据库 DAO 层」一行判 `不适用`，r284 关系型存储迁移落地后本地已真有 SQLite 表，改判 `已接`。此外若干上游内部形态（意图总线、Gateway、DI、进程级单例、图标名命中）未单列成行，已在各块小结与「覆盖证明」节注明。

4. **上游自身有两处口径不一致**，本表按阅读页内那套收口，并已在 C 块备注写明：目录页书签/笔记条目的点按/长按语义在 `ReaderBookSheet.kt` 与 `TocScreen.kt` 两处不同；且后者全仓无调用点，是未接线代码。

## 建议后续顺序

1. 先补「标记渲染前校验锚点文本」——它是唯一会让用户看到错误结果的缺陷，且本地 `BookContentProcessEngine.ets:93 findTargetRange` 已具备等价能力，接线成本低。
2. 再做目录页多选与反序——两者都是列表页交互，可一轮清完，且不依赖新数据字段。
3. 然后是两个「只差入口」的划词项：「替换」预填 pattern、「搜索内容」（F1 的「全文搜索」）预填关键词。底层面板都完整，各自只需加一个可选入参（`ReplaceRuleEditor` 加 `initialPattern`、`ReaderSearchPage` 加 `initialQuery`），是本表里成本最低的两条。
4. 目录页信息 tab 补「备注」行——单行渲染，`Book.remark` 字段已在，`remark.takeIf { isNotBlank }` 条件照抄上游即可。
5. 然后是「行内快速标记」——需要新引入 `inlineMode`/`previewStyle`/`inlineDirty` 三个状态，属新面板形态，工作量最大。
6. 书签无障碍播报要等阅读页无障碍策略层落地（上游在 `feature/reader/core/accessibility`，本地无对应模块），可随无障碍整体迁移一起做。
7. **F 块按 F4 → F2 → F3 拖拽 的顺序补**（r286 新增建议）：先接持久化链路（`textSelectMenuConfig` 落盘 + `SelectionMenuConfigItem` 的 `enabled` 维度 + 按配置重排），再补两套菜单形态与两个开关，最后补配置页的拖拽排序与保存按钮。前两步补完，配置页立刻从「预览」变可用。
8. 划词菜单剩下 11 项未接（分享 / 浏览器 / 朗读 / 词典 / 替换 / 正文编辑 / AI 清洗 / AI 改写 / 全文搜索 / BGM 前后）**除「替换」与「全文搜索」外不建议单独立项**：它们各自依赖一整个未迁移的子系统（系统分享、外部浏览器、TTS、词典、正文编辑、AI、BGM 场景），应按所属子系统各自推进，补齐后在 `ReaderPage.ets:2085` 的菜单里挂入口即可。
9. 拆分超长章节属目录页能力（`Book` 需补 `splitLongChapter` 字段），与书签模块只有「第 N 章」回退这一处交集，可等目录页单独开一轮时一并处理——它不在本表行内。

## 维护

本表按模块维度组织，与 [ZIP 类别总账](STATUS.md) 的 `bookmark` 行对应：ZIP 维度只看 `bookmark.json`/`bookMarking.json` 的读写往返（本表 E 块），本表其余块覆盖书签/划线/笔记的全部用户可感操作。改本表时同步检查 [`STATUS.md`](STATUS.md) 的 `bookmark` 行链接与 [`KEYWORDS.md`](KEYWORDS.md) 的关键词是否仍一致。

**r286 起的两条硬要求**（见 [编码规约](../CODE-CONVENTIONS.md) 第四节与 [术语表](../GLOSSARY.md) 的 **界面清单**）：

1. **盘点单位是界面，不是按钮。** 新增任何与书签/划线相关的界面（页、弹层、配置页），要按整个界面列全，未迁移的显式标 `未接`，不能只列「与本功能相关的那个按钮」——F 块的教训就是 A/B 块原来把整个长按选词菜单压成了两行。
2. **每轮盘点结束必须当轮落盘，并重跑覆盖证明。** 命令见「覆盖证明」节；未分配不为 0 就是没盘完，不能只凭「表里没有 `待定`」结案。
