# 本地前端组件清单（components/ 70 个 @Component + 设计令牌）

> 用途：写书架 / 详情页 / 设置页的代码之前，先在这里找一遍现成的组件，别重造。
> 后端（data / reader / bookSource / lib）见另一份 [本地后端清单](COMPONENT-CATALOG-DATA.md)。
> 基线：`<workspace>/legado-with-md3-harmonyos` 工作区。
> **快照时间 2026-11-24 14:40**。上一版是 2026-11-23 02:26，收录 41 个真组件；本版 70 个，是全量重取不是增量补几条。行号会随并发会话改动漂移，用之前 `grep -n` 复核一次（第十四节写了同一件事）。
> **上游映射 70 条已于 2026-11-24 两轮查证完毕**——表格「上游等价物」列每条都带 `查证 2026-11-24` 或 `查证 2026-11-24·二轮`，旧标注保留在 `；原标注：` 后缀。

## 〇、怎么读这份表，以及本版相对上一版改了什么

### 0.1 三条读法

1. **「上游等价物」一列 70 条已全部读过上游源码**，分两轮查证，每条都带 `；原标注：…` 保留查证前的说法：
   - **查证 2026-11-24** —— 第一轮 33 条（原标「文件级 / 索引匹配 / 未查到 / 本地自造」）：定义行、签名原文、结构级 props、结论（等价 / 近似 / 不匹配 / 上游确实没有）。
   - **查证 2026-11-24·二轮** —— 第二轮 37 条（原标「注释已注明·行级」33 条 + 「文件级」3 条 + `AppGlyph`）：定义行、签名原文、标注差异判定（无差异 / 描述过时 / 描述错误 / 描述不完整 / 未查到）。
   - **两档都已读上游源码，可以照抄。** 但「关键 props」列仍是结构级口径——逐参数对照在 `tmp/component-catalog-verify2.md` 第 2 项，尚未写回本表。
2. **`关键 props` 只列常用的，不是全部。** 完整签名看定义行往下 20 行，`@Prop` 都有默认值。
3. **`首个调用点` 给的是文件:行号。** 这是全仓扫描出的第一个调用位置，不一定是最典型的用法——多行调用的整段自己去看，那才是能照抄的东西。

### 0.2 本版相对上一版（2026-11-23 02:26）的差异

**数字对比**

| 指标 | 上一版 | 本版 | 说明 |
| --- | --- | --- | --- |
| 表格收录的真组件 | 41 | **70** | 上一版 63 个唯一名里，20 个是令牌常量、`UiMenuItem` 是 interface、`ReadAloudGlassWidgets` 是文件名，减去这些才是真组件 |
| `components/` | 未统计 | 61 文件 / 12,170 行 / 64 个 `@Builder` | 70 个 struct 全在这里 |
| `entry/src/main/ets` 总 struct | 未统计 | 217 / 379 文件 | `pages/` 独占 147 个 |
| 上游 Composable 索引 | 1,123 | 1,122 | 本次重扫 `tmp/_up_comp.txt` 得 1,122 行；差 1 行**未追查原因**，别当成上游改了 |

**补录的 29 个 struct**（上一版表格里完全没有的）

`AppAlertDialog`、`BookCard`、`DialogTextInput`、`DialogCheckRow`、`AloudStepper`、`AloudSliderSetting`、`ThemeColorItem`、`UiSwitchControl`、`ConflictBookCard`、`ConflictRadio`、`BookshelfConflictSheet`、`ChangeCoverSheet`、`ContentQualitySheet`、`ExpandedSourceContent`、`ExploreKindItem`、`ExploreKindSelectSheet`、`LoadMoreFooter`、`ScopeSelectSheet`、`SearchBar`、`SearchBookTagChip`、`SearchBookListItem`、`SearchBookGridItem`、`SearchBookPreviewSheet`、`SearchSettingsSheet`、`SelectionItemCard`、`SmallPlainIconButton`、`LoginKindItem`、`BackgroundImageManageSheet`、`MainNavigationSettingsSheet`。

**新增文件的时间出处**（`git log --diff-filter=A --date=short -- entry/src/main/ets`）

| 日期 | 新增 `components/` 文件 | 新 struct |
| --- | --- | --- |
| 2026-11-23 | `CoverBlurBackdrop` / `ProgressiveBackdrop` / `RelatedBooksBanner` / `booksource/BookshelfConflictSheet` / `booksource/ExploreKindItem` / `booksource/LoadMoreFooter` / `booksource/SearchBookItems` / `booksource/SearchBookPreviewSheet` / `settings/AppFontSheet` / `settings/LauncherIconPickerSheet` / `settings/NavIconManageSheet` / `settings/TopBottomBarSettingsSheet` / `theme/BackgroundImageManageSheet` / `theme/MainNavigationSettingsSheet` | 14 |
| 2026-11-24 | `AppAlertDialog` / `DialogInputs` / `booksource/ChangeCoverSheet` / `booksource/ContentQualitySheet` / `booksource/ExpandedSourceContent` / `booksource/ScopeSelectSheet` / `booksource/SearchBar` / `booksource/SearchSettingsSheet` / `booksource/SelectionItemCard` | 10 |

上一版只收了 11-23 那批里的 4 个 settings 面板；`CoverBlurBackdrop` / `ProgressiveBackdrop` / `RelatedBooksBanner` 三个视觉组件一个没写。

**四处结论过时，本版已改**

1. **`AutoGroup` 已经不是 0 命中了。** 上一版写「AI 自动分组整套一套都没有，`AutoGroup` 全仓 0 命中」。**实测 133 处命中**：`data/AutoGroupEngine.ets` 已落地（上游 `AiAutoGroupContract.kt` 的八种阶段、六种错误都建了类型），`pages/BookshelfPage.ets` 已在调用。这一条作废。
2. **完整标注表已经有了。** 上一版写「只有阅读页的快捷标注面板，没有独立整表」。**`pages/ReaderMarkingEditor.ets` 就是独立标注编辑页**，逐条对齐 `MarkingSheet.kt:449-464` 的 16 个预设色、`:175` 的 TinyDropdown 样式、`:288-296` 的色格口径。上一版那句是错的。
3. **页面行数整体涨了 10–70%。** `Index.ets` 13,522 → **15,140**，`BookshelfPage.ets` 3,072 → **5,150**（涨 68%），`ProfileSubPages.ets` 7,929 → **8,260**，`ReaderSettingsPage.ets` 4,606 → **4,649**，`BookInfoPage.ets` 1,764 → **3,045**。第十一节已全部重取。
4. **`.fontSize(数字)` 不再是 0 处。** 上一版与排版批的记录都说「全仓 0 处，唯一残留是 ohosTest 的测试脚手架」。**实测 47 处**：`components/BookKnowledgeSheet.ets` 42、`components/theme/BackgroundImageManageSheet.ets` 3、`pages/BookSourceDebugPage.ets` 1、`components/theme/MainNavigationSettingsSheet.ets` 1。全仓 `.fontSize(` 共 1,731 处，这 47 处占 2.7%。

### 0.3 上游映射查证：第一轮 33 条 + 第二轮 37 条（2026-11-24）

原先标成「注释已注明·文件级」「索引匹配」「未查到」「本地自造」的 33 条，已逐条到上游读源码查实。明细见 `tmp/component-upstream-verify.md`（595 行，逐条签名原文 + props 对照 + 检索命中数）。

**结论分布：** 近似 24 / 不匹配 4 / 等价 4 / 上游确实没有 1。

**修正 14 处**，其中 6 处是结论层面的更正：

| # | 组件 | 原标注 | 查实 |
| --- | --- | --- | --- |
| 15 | `BookKnowledgeSheet` | `BookInfoScreen.kt:2325` | 2325 只是详情页「知识」预览区块；真正对应 `ui/book/knowledge/` 四个 Screen |
| 22 | `TopBarButton` | `TopBarButton.kt:214` | `:214` 是 `private fun`；公开入口是 `:333 TopBarActionButton` |
| 24 | `BookCard` | 索引匹配 `BookItem.kt:674` | 上游 `BookItem` 是完整书籍行、参数面不同；本地零调用属死代码 |
| 28 | `UiSection` | `SectionTitle.kt:14` | 上游只有一行标题文字、无容器；本地是「标题+内容」容器 |
| 30 | `SmallPlainIconButton` | 未查到 | 改判近似：`AppIconButton.kt:20` 覆盖语义 |
| 32 | `DialogCheckRow` | 上游无通用复选行 | 不成立：`CheckboxItem.kt:21` 就是 |

其余 8 处是行号或等价关系更正，逐条列在 `tmp/component-upstream-verify.md` 末节「推翻了哪些现标注」。

**这次没做到：** props 只给了结构级对照（按调用关系的关键几组），不是上游参数与本地 props 的一对一逐项；完整检索命令附录只有 13 组汇总。要逐个 props 核到底，得另跑一遍（见 `tmp/component-catalog-verify-prompt.md`）。

### 0.3b 第二轮：37 条未查证映射 + 33 条复核（2026-11-24 16:08）

第一轮没覆盖到的 37 条（原标「注释已注明·行级」33 条 + 「文件级」3 条 + `AppGlyph`），连同第一轮 33 条的定义行复核、props 一对一、第十二节 6 条、70 个调用点，一起跑完了。明细见 `tmp/component-catalog-verify2.md`（489 行）。

**37 条结论分布：** 近似 31 / 等价 4 / 不匹配 1 / 上游确实没有 1。
**按标注差异：** 无差异 13 / 描述过时 14 / 描述错误 4 / 描述不完整 5 / 未查到 1。

四处**描述错误**——标注落到了别的函数、别的文件或 data class 上：

| 组件 | 原标注 | 查实 |
| --- | --- | --- |
| `ThemeColorItem` | `ThemeConfigScreen.kt:1077`（行号对，名字错） | 真名 `ThemeColorButton`，且是公开函数——本文件第十三节「只能 `ThemeColorSelector` 内部用」与上游不符 |
| `LoadMoreFooter` | `ExploreShowScreen.kt:500` | 那是调用包装处；定义在 `LoadMoreFooter.kt:43` |
| `SearchBookPreviewSheet` | `SearchBook.kt:41` | 那是实体字段；组件在 `SearchBookPreviewSheet.kt:42` |
| `LoginKindItem` | `SourceLoginContract.kt:23` | 那是 data class `LoginRowLayoutUi`；上游无同名组件，最近的是 `SourceLoginSheets.kt:195 private fun SourceLoginRow` |

另 14 条是**行号漂移**（原标落在 `@Composable` 注解行、`val` 行、import 行或函数体内），已逐条改为 `fun` 定义行；5 条是**描述不完整**（只给了文件级或容器/指示器其中一处），也补齐了。

**第一轮 33 条定义行：独立复核 33/33 全对**——不采信第一轮结论，逐条重读 `fun` 那一行（含 6 条重点：`TopBarButton.kt:214` 确为 `private`、`:333` 才对公开入口；`BookItem.kt:674`；本地 `BookCard` 零独立调用已单独 grep 坐实；`SectionTitle.kt:14` 无容器、带容器的是同目录 `SplicedColumnGroup.kt:42`；`AppIconButton.kt:20` 有 `miuixMinHeight/minWidth` 可做 32dp；`CheckboxItem.kt:21` 有 `checked`/`onCheckedChange`）。

**第十二节 6 条「上游有、本地没有」：** 本地定义级与调用级均 0 命中，文档里写的替代方案逐条实地核过。其中 `MediumFlexibleTopAppBar` 属 M3 外部库（`BookInfoScreen.kt:63 import androidx.compose.material3.MediumFlexibleTopAppBar`），本仓无源码。

**70 个调用点复验：** 有效 58 / 失效 6 / 为空 6。失效 6 条全在 `pages/SearchPage.ets`，整体下移 24 行（本表记的是 11-24 快照值），已逐条改成本轮实测行号。

**仍未做：** 33 条的 props 一对一明细在 `tmp/component-catalog-verify2.md` 第 2 项，没有逐条写回本表——本表「关键 props」列仍是第一轮结构级口径。

### 0.4 诚实声明

第一轮 33 条 + 第二轮 37 条 = **70 条上游映射全部读过上游源码**（定义行 + 签名原文，逐条带行号，旧说法保留在 `；原标注：` 后缀）。仍未做的两件：props 一对一逐项对照（明细在 `tmp/component-catalog-verify2.md` 第 2 项，未写回本表）；上机验证渲染效果（本文件全程只读源码）。

**没有为了凑满表格而编造任何上游行号**——查不到就写「未查到」，那是可信的状态，不是缺陷。

---

## 一、导航与顶栏（4 个）

| 组件 | 定义 | 上游等价物 | 关键 props | 首个调用点 |
| --- | --- | --- | --- | --- |
| `AppTopBar` | `components/TopBar.ets:63` | `GlassTopAppBar.kt:28` + `GlassMediumFlexibleTopAppBar.kt:43`（**查证 2026-11-24·近似**：本地一个 struct 覆盖上游固定/折叠两个 composable；原注「`:76` 是标题」实为 title 的 style 行）；原标注：`GlassTopAppBar.kt:28`（注释已注明·文件级，`TopBar.ets:9` 另引 `:76`） | `title` / `titleRevealStep` / `subtitle` / `collapsed` / `collapseFraction` / `hasNavigation` / `navigationIcon`(Builder) / `actions`(Builder) | `pages/BookInfoEditPage.ets:748` |
| `TopBarButton` | `components/TopBar.ets:313` | **不匹配** → `TopBarButton.kt:333 TopBarActionButton`（**查证 2026-11-24**；原标 `:214` 是 `private fun TopBarButton`，对外公开入口在 `:333`）；原标注：`TopBarButton @ui/widget/components/topbar/TopBarButton.kt:214`（索引匹配） | `icon` / `tint` / `disabled` / `showDivider` / `menuMode` / `accessibilityLabel` / `onSelect` | `pages/BookInfoEditPage.ets:726` |
| `TopBarBackButton` | `components/TopBar.ets:434` | `TopBarButton.kt:304 TopBarNavigationButton`（**查证 2026-11-24·等价**）；原标注：`TopBarNavigationButton @ui/widget/components/topbar/TopBarButton.kt:304`（索引匹配） | `onSelect` / `accessibilityLabel` | `pages/BookInfoEditPage.ets:720` |
| `CollapsingSettingsHeader` | `components/CollapsingSettingsHeader.ets:16` | `GlassMediumFlexibleTopAppBar.kt:43`（**查证 2026-11-24·近似**）；原标注：`GlassMediumFlexibleTopAppBar @ui/widget/components/topbar/GlassMediumFlexibleTopAppBar.kt:43`（注释已注明·文件级；索引匹配补到 `:43`） | `title` / `collapsed` / `collapseFraction` / `onBack` | `pages/AppAiSettingsPage.ets:29` |

`AppTopBar` 还导出 8 个度量常量（`components/TopBar.ets:12`–`:26`）：`TOP_BAR_COLLAPSED_HEIGHT` / `TOP_BAR_EXPANDED_HEIGHT` / `TOP_BAR_EXPANDED_HEIGHT_SUBTITLE` / `TOP_BAR_TITLE_EXPANDED_SIZE` / `TOP_BAR_TITLE_COLLAPSED_SIZE` / `TOP_BAR_SUBTITLE_SIZE` / `TOP_BAR_SIDE_PADDING` / `TOP_BAR_TITLE_START`。

**设置子页别自己写顶栏。** `CollapsingSettingsHeader` 就是给它们的（**16 个设置子页在用**），它只做形态适配，结构交给 `AppTopBar`。

---

## 二、卡片与封面（9 个）

| 组件 | 定义 | 上游等价物 | 关键 props | 首个调用点 |
| --- | --- | --- | --- | --- |
| `BookCover` | `components/BookCover.ets:28` | ui/widget/components/image/cover/CoilBookCover.kt:275（**查证 2026-11-24·二轮·近似**：无差异（文档 :100 标 CoilBookCover.kt:275 与真身吻合）；差在参数面：上游 name/author/path 三元组 + shared transition 参数，本地 book + displayWidth/mini）；原标注：`CoilBookCover.kt:275`（注释已注明·行级；另引 `BookItem.kt:703`/`:706` 与 `PrivateLockedContent.kt:54`） | `book` / `compact` / `mini` / `displayWidth` / `displayHeight` / `cornerRadius` / `showChapterBadge` / `badgeText` / `showBadgeDot` / `isUpdating` / `leftBottomText` / `shadowEnabled` / `fillWidth` / `isNight` / `sharedKey` | `pages/BatchChangeSourceSheet.ets:571` |
| `BookGroupCard` | `components/BookGroupCard.ets:25` | `BookItem.kt:327` 封面 / `:452` 网格 / `:491` 列表 / `:557` 横排（**查证 2026-11-24·近似**：上游四个 composable，本地用一个 `listStyle` 覆盖）；原标注：`BookGroupCover @BookItem.kt:327`（注释已注明·文件级；`BookGroupCard.ets:15` 写明三形态对齐 `BookItem.kt` 三个 composable：`:452` 网格 / `:491` 列表 / `:557` 横排封面） | `groupName` / `books` / `coverCount` / `listStyle` / `coverSettings` / `isNight` / `listCoverWidth` / `showCount` / `coverShadow` / `locked` / `showDivider` / `onOpen` / `onLongPress` | `pages/BookshelfPage.ets:4668` |
| `BookCard` | `components/BookCard.ets:6` | **不匹配** → `BookItem.kt:674 fun BookItem` 是完整书籍行（**查证 2026-11-24**）；本地 `BookCard.ets` 全仓零调用是死代码，参数面与上游不同；原标注：`BookItem.kt:674`（索引匹配；**但这是死代码**） | `book` / `onOpen` | 无（外部调用 0，同文件 1） |
| `PullRefreshIndicator` | `components/PullRefreshIndicator.ets:42` | ui/widget/components/AppPullToRefresh.kt:34；指示器 :104（**查证 2026-11-24·二轮·近似**：描述不完整（:34 容器函数与 :104 指示器是两处；本地只做纯指示器，文档引 :104-110 已注明）；差在粒度）；原标注：`AppPullToRefresh.kt:34`（注释已注明·行级 `:104-110`） | 无 props，纯指示器 | `pages/BookshelfPage.ets:705` |
| `ReadRecordHeatmap` | `components/ReadRecordHeatmap.ets:11` | `ReadRecordOverviewScreen.kt:285` 整卡 + `HeatmapCalendarComponents.kt:204` 格子层（**查证 2026-11-24·近似**：本地只还原格子层，原注漏了整卡含标题/统计/图例）；原标注：`HeatmapCard @ui/book/readRecord/ReadRecordOverviewScreen.kt:285`（注释已注明·文件级，`ReadRecordHeatmap.ets:5` 引 `HeatmapCalendarComponents.kt`） | `dailyReadCounts` / `dailyReadTimes` / `selectedDate` / `mode` / `onDateSelected` | `pages/ProfileSubPages.ets:6836` |
| `RelatedBooksBanner` | `components/RelatedBooksBanner.ets:33` | ui/book/info/BookInfoScreen.kt:2125（**查证 2026-11-24·二轮·近似**：无差异（文档 :105 标 BookInfoScreen.kt:2125 与真身吻合）；差在参数面：上游无 coverSettings/isNight）；原标注：`RelatedBooksBanner @BookInfoScreen.kt:2125`（注释已注明·行级 `:2125-2171`；另引 `BannerModule.kt:57`/`:70`/`:73`） | `title` / `books` / `showMore` / `coverSettings` / `isNight` / `onSelectBook` / `onMore` | `pages/BookInfoPage.ets:321` |
| `CoverBlurBackdrop` | `components/CoverBlurBackdrop.ets:17` | ui/widget/components/image/cover/CoverBlurBackdrop.kt:17（**查证 2026-11-24·二轮·等价**：描述过时（文档 :106 标 CoverBlurBackdrop.kt:25，:25 是函数体内 val tint，真身 17））；原标注：`CoverBlurBackdrop.kt:25`（注释已注明·行级；另引 `PlayerBackground.kt:34`） | `coverUri` / `seedColor` / `blurRadius`(48) / `coverScale`(1.2) | `pages/ReadAloudPlayerPage.ets:178` |
| `ProgressiveBackdrop` | `components/ProgressiveBackdrop.ets:15` | ui/theme/HazeStyle.kt:27；progressive :50；fixed :65（**查证 2026-11-24·二轮·近似**：描述过时（文档 :107 标 HazeStyle.kt:47，47 是 progressive 调用非 fun 定义行）；差在形态）；原标注：`HazeStyle.kt:47`（注释已注明·行级 `:47-61`） | `blurRadius` / `bands` / `reversed` | `pages/BookInfoPage.ets:2472` |
| `ConflictBookCard` | `components/booksource/BookshelfConflictSheet.ets:70` | `BookshelfConflictSheet.kt:198`（**查证 2026-11-24·等价**）；原标注：`ConflictBookCard @ui/widget/components/conflict/BookshelfConflictSheet.kt:198`（索引匹配，同名） | `summary` / `onOpenBook` | `pages/BookInfoPage.ets:1006` |

**`components/BookCard.ets:6` 是死代码，上一版就写了、这版仍然成立**：55 行，`grep -rn "BookCard'" entry/src/main/ets` **0 命中**。书架的书卡是**内联**画在 `pages/BookshelfPage.ets` 里的。抽组件时不要参考它，也不要「顺手修好它」。

**`CoverBlurBackdrop` 与 `ProgressiveBackdrop` 不是一回事**：前者吃封面图算种子色做磨砂背景（朗读播放页在用），后者按 `bands` 分带做渐进模糊（详情页头图在用）。

---

## 三、菜单 · 面板 · 对话框（7 个）

| 组件 | 定义 | 上游等价物 | 关键 props | 首个调用点 |
| --- | --- | --- | --- | --- |
| `UiMenuPanel` | `components/UiMenu.ets:67` | ui/widget/components/menuItem/RoundDropdownMenu.kt:52（**查证 2026-11-24·二轮·近似**：描述过时（文档 :120 标 RoundDropdownMenu.kt:57，:57 是 shadowElevation 参数行，真身 52）；差在语义）；原标注：`RoundDropdownMenu.kt:57`（注释已注明·行级；另引 `PillDivider.kt:23`/`:24`） | `items: UiMenuItem[]` / `panelWidth` / `onSelect(key)` | `pages/BookInfoEditPage.ets:415` |
| `ReaderSheetShell` | `components/ReaderSheetShell.ets:18` | `AppModalBottomSheet.kt:48`（**查证 2026-11-24·近似**：上游建在 M3 ModalBottomSheet 上，本地自绘 scrim + 固定宽高）；原标注：`AppModalBottomSheet.kt:48`（注释已注明·文件级，`ReaderSheetShell.ets:3` 引其「Material 默认分支」） | `scrimColor` / `panelColor` / `panelWidth` / `panelHeight` / `showHandle` / `contentPadding` / `blurRadius` / `onDismiss` / `content`(Builder) | `pages/ReadAloudConfigPanel.ets:118` |
| `AppAlertDialog` | `components/AppAlertDialog.ets:20` | `AppAlertDialog.kt:33`（**查证 2026-11-24·近似**）；原标注：`AppAlertDialog @ui/widget/components/alert/AppAlertDialog.kt:33`（注释已注明·文件级 `AppAlertDialog.ets:2`，同名） | `title` / `text` / `confirmText` / `dismissText` / `confirmEnabled` / `onConfirm` / `onDismiss` / `content`(Builder) | `pages/BookInfoEditPage.ets:624` |
| `DialogTextInput` | `components/DialogInputs.ets:13` | `AppTextField.kt:37`（**查证 2026-11-24·近似**：上游无对话框专用输入件，属 AppTextField 一族非同名等价）；原标注：本地自造（对话框内输入控件；上游对应 `AppTextField.kt:37` 的一族，非同名等价） | `initialText` / `placeholder` / `maxLines` / `isPassword` / `onValueChange` | `pages/BookshelfPage.ets:1670` |
| `DialogCheckRow` | `components/DialogInputs.ets:68` | **不匹配** → `CheckboxItem.kt:21` 是通用复选行（**查证 2026-11-24**；原注「上游无通用复选行」不成立）；原标注：本地自造（对话框内复选行；上游无同名组件，散在各自对话框里） | `label` / `initialChecked` / `onCheckedChange` | `pages/BookshelfPage.ets:1314` |
| `UiColorSheet` | `components/settings/UiColorSheet.ets:19` | `ColorPickerSheet.kt:51`（**查证 2026-11-24·近似**）；原标注：`ColorPickerSheet.kt:51`（注释已注明·文件级 `UiColorSheet.ets:4`；索引匹配补到 `:51`） | `title`(默认「选择颜色」) / `initialColor` / `resetColor` / `onCancel` / `onConfirm(color)` | `pages/AppCoverSettingsPage.ets:452` |
| `SmallPlainIconButton` | `components/booksource/SelectionItemCard.ets:155` | `AppIconButton.kt:20`（**查证 2026-11-24·近似**：上游无独立 32dp 小图标按钮，语义由 AppIconButton 覆盖；另有 `private RoundIconButton @MarkingSelectionMenu.kt:447`）；原标注：**未查到**（上游 `RoundIconButton @MarkingSelectionMenu.kt:447` 名字不符，未确认） | `icon` / `iconSize` / `buttonSize` / `label` / `onSelect` | `pages/SearchPage.ets:1524` |

**`UiMenuItem` 是 interface 不是组件**（`components/UiMenu.ets:9`），上游对应 `RoundDropdownMenuItem.kt:44`（索引匹配）。上一版把它算进 63 个唯一名里，那是计数错误。

**`DialogTextInput` / `DialogCheckRow` 为什么单独做成 struct，注释写得很清楚，别改回页面 `@State`**：`openCustomDialog({ builder })` 的 builder 是页面实例上的一个 `@Builder`，它捕获的是页面状态；但对话框是独立窗口，页面状态变化**不一定能可靠触发对话框重绘**（`DialogInputs.ets:4-8` 记录实测：部分机型上输入框会卡住不刷新）。文本状态放在 struct 内部由它自己的 `@State` 驱动，页面只通过回调拿到最终值。

**`AppAlertDialog` 是 11-24 新增的，23 处已在用**，是全仓第三热的组件（仅次于 `AppGlyph` 293 与 `ThemeGroupItem` 61 之外的那一档）。它带 `content` Builder，所以「只有标题+正文」和「要夹自定义内容」两种用法都走它，别另写 `AlertDialog.show()`。

---

## 四、设置行控件（9 个，写设置页基本只用这一族）

`components/settings/` 与 `components/UiSwitchControl.ets` 一共 9 个，**同一个视觉骨架（`ROW_PADDING_H=16` / `ROW_PADDING_V=14` / 可选分隔线），右侧控件不同**。选型只看右侧那一块是什么。

| 组件 | 定义 | 上游等价物 | 关键 props | 右侧是什么 | 首个调用点 |
| --- | --- | --- | --- | --- | --- |
| `UiAction` | `components/settings/UiAction.ets:17` | `ClickableSettingItem.kt:17`（**查证 2026-11-24·近似**；原注另引 `:44-50` 实为 `ChevronRight` 默认值，不是函数定义）；原标注：`ClickableSettingItem.kt:17`（注释已注明·文件级 `UiAction.ets:7`；行级引 `:44-50`） | `title` / `detail` / `option` / `swatchColor` / `swatchDisabled` / `chevronSize`(15) / `showDivider` / `detailMaxLines` / `onSelect` | 可选色块 + 可选值文本 + 尖括号 | `pages/AppAiSettingsPage.ets:34` |
| `UiSwitch` | `components/settings/UiSwitch.ets:20` | `SwitchSettingItem.kt:20` 整行（**查证 2026-11-24·近似**；右侧开关 `AdaptiveSwitch` 定义在 `IconSwitch.kt:22`、由 `:52` 调用——整行与开关是两个东西）；原标注：`SwitchSettingItem @ui/widget/components/settingItem/SwitchSettingItem.kt:20`（注释已注明·文件级 `UiSwitch.ets:15` 写明右侧是「对齐上游 AdaptiveSwitch」；索引匹配补到 `:20`） | `title` / `detail` / `value` / `disabled` / `showDivider` / `onChange` | 开关（内部就是 `UiSwitchControl`） | `pages/AppCoverSettingsPage.ets:339` |
| `UiSwitchControl` | `components/UiSwitchControl.ets:32` | `IconSwitch.kt:22 AdaptiveSwitch`（**查证 2026-11-24·近似**）；原标注：`AdaptiveSwitch @ui/widget/components/IconSwitch.kt:22`（注释已注明·文件级；`UiSwitchControl.ets:4-16` 按 M3 `SwitchTokens` 自写几何） | `switchEnabled` / `showIcon` / `scaleValue` / `interactive` / `onChange` | 裸开关，**不带任何文字** | `pages/AppBackupSettingsPage.ets:912` |
| `UiSlider` | `components/settings/UiSlider.ets:8` | `SliderSettingItem.kt:48`（**查证 2026-11-24·近似**）；原标注：`SliderSettingItem @ui/widget/components/settingItem/SliderSettingItem.kt:48`（索引匹配） | `title` / `detail` / `value` / `minValue` / `maxValue` / `stepValue` / `showDivider` / `onChange` | 滑杆（值文本可选） | `pages/AppDownloadCacheSettingsPage.ets:160` |
| `UiDropdown` | `components/settings/UiDropdown.ets:19` | `ListSettingItem.kt:19`（**查证 2026-11-24·近似**）；原标注：`DropdownListSettingItem @ListSettingItem.kt:19`（索引匹配；`UiDropdown.ets:29` 注释引 `SettingItem.kt:53`/`:73-79` 的卡形态） | `cardSurface` / `title` / `detail` / `option` / `options` / `showDivider` / `onSelect` / `onStateChange` | 当前值 + 弹出选项列表 | `pages/AppBackupSettingsPage.ets:525` |
| `UiChoice` | `components/settings/UiChoice.ets:12` | `ListSettingItem.kt:19 DropdownListSettingItem`（**查证 2026-11-24·近似**：上游是下拉弹窗、双数组、回传值，本地点选循环 options、回传下标，交互形态不同）；原标注：`DropdownListSettingItem @ListSettingItem.kt:19` 的简化形态（注释已注明·文件级，`UiChoice.ets:7`；索引匹配） | `title` / `detail` / `options` / `selectedIndex` / `showDivider` / `onSelect` | 点一下在几项间**循环切换** | `pages/AppCoverSettingsPage.ets:374` |
| `UiInput` | `components/settings/UiInput.ets:17` | `InputSettingItem.kt:30`（**查证 2026-11-24·近似**）；原标注：`InputSettingItem @ui/widget/components/settingItem/InputSettingItem.kt:30`（注释已注明·文件级，`UiInput.ets:11`「行为照上游」） | `title` / `detail` / `value` / `defaultValue` / `showDivider` / `onConfirm` | 可编辑文本框 | `pages/AppDownloadCacheSettingsPage.ets:172` |
| `UiColorModeRow` | `components/settings/UiColorModeRow.ets:12` | `TinySettingItems.kt:476`（**查证 2026-11-24·近似**）；原标注：`TinyColorModeSettingItem @ui/widget/components/settingItem/TinySettingItems.kt:476`（注释已注明·文件级 `UiColorModeRow.ets:4`） | `title` / `dayColor` / `nightColor` / `dayLabel`(日间) / `nightLabel`(夜间) / `colors` / `showFollow` / `onDayChange` / `onNightChange` | 日/夜两个色点（就地展开预设色板） | `pages/ReaderSettingsPage.ets:748` |
| `UiSection` | `components/settings/UiSection.ets:12` | `SectionTitle.kt:14`（**查证 2026-11-24·近似**：上游只有一行标题文字 `SectionTitle(title: String)`，无容器；本地是「标题+内容」容器）；原标注：`SectionTitle @ui/widget/components/SectionTitle.kt:14`（索引匹配；`UiSection.ets:15` 注释说明分组卡对应上游 `SplicedColumnGroup`） | `title` / `content`(Builder) | —（本组件就是「区块标题 + 一张卡」的容器） | `pages/AppAiSettingsPage.ets:33` |

**`UiSwitch` 是受控组件，父级必须回写 `value`，否则开关会弹回原状**（`UiSwitch.ets:10` 注释）。它刻意不存值副本——改造前 `CacheSettingsSwitch` / `PrivacySettingsSwitch` 用 `@Prop` + `@State` + `aboutToAppear` 同步，而 `aboutToAppear` 只跑一次，父级之后改值开关不跟着动，这个缺陷是这么修掉的。

**`UiSwitchControl` 与 `UiSwitch` 的分工**：前者是裸开关（39 处调用，`@Prop scaleValue` 可缩放、`showIcon` 控制滑块里那颗勾），后者是「整行可点 + 标题 + 说明 + 右侧开关」（40 处调用）。**不要为了一个没有文字的开关去写 `Row { Text(); Toggle() }`**，用 `UiSwitchControl`。它的几何是照 M3 `SwitchTokens` 自算的：轨道 52×32、滑块 24/16、按下 28、描边 2、留白 4（`UiSwitchControl.ets:5-16`）。

**`UiAction` 与 `UiChoice` 的区别是能力，不是外观**：`UiChoice` 只报「切到了第几个」，值存不存、存哪都由父级决定（`UiChoice.ets:9` 原文：「值与回调都在父级：本组件只报『切到了第几个』，不自己存 selectedIndex」）。要展示一串选项让用户挑，用 `UiDropdown`；只是几档循环切换，用 `UiChoice`。

**`pressedBackground()` 是这一族的共同约定**（`UiAction.ets:48-54`，`UiChoice.ets:30` 也有）：把主题强调色 `#RRGGBB` 前面补 `#26` 成 15% alpha 的 `#AARRGGBB`；主题色不是 7 位 hex 时退回 `themeColorSurfaceTertiary`。新写设置行时照抄这段，不要自造按压色。

**分隔线默认画**（`showDivider` 默认 `true`）。一组里最后一行传 `showDivider: false`，或者在分组容器里用 `ThemeGroupItem` 的 `first` 控制。

**`UiSection` 是「取代七份私有实现」的容器**（`UiSection.ets:8`）：Ai / Cover / Cache / Privacy / Read / Translation / OtherSettings 七个设置页原来各写一份 Section，现在统一走它。**阅读菜单的 `MenuSettingSection` 不在范围内**——那是深色专用、不跟随主题的，别合并。

---

## 五、主题选择与分组（6 个）

| 组件 | 定义 | 上游等价物 | 关键 props | 首个调用点 |
| --- | --- | --- | --- | --- |
| `ThemeModeSelector` | `components/ThemeSelectors.ets:28` | ui/config/themeConfig/ThemeConfigScreen.kt:1004（**查证 2026-11-24·二轮·等价**：无差异（文档 :170 标 :1004 与真身吻合））；原标注：`ThemeModeSelector @ThemeConfigScreen.kt:1004`（注释已注明·行级，文件头 `ThemeSelectors.ets:8` 引 `:1004-1040`；另引 `OnboardingScreen.kt:340`） | `selectedMode` / `onModeSelected(mode)` | `pages/OnboardingPage.ets:324` |
| `ThemeColorSelector` | `components/ThemeSelectors.ets:95` | ui/config/themeConfig/ThemeConfigScreen.kt:1043（**查证 2026-11-24·二轮·近似**：无差异（文档 :171 标 :1043 与真身吻合）；差在参数面：上游 context/themes/isAmoled/paletteStyle/种子色，本地 selectedIndex/isDark）；原标注：`ThemeColorSelector @ThemeConfigScreen.kt:1043`（注释已注明·行级 `:1043`／`:234`） | `selectedIndex` / `isDark` / `onPaletteSelected` / `onSelect` | `pages/OnboardingPage.ets:336` |
| `ThemeColorItem` | `components/ThemeSelectors.ets:143` | ui/config/themeConfig/ThemeConfigScreen.kt:1077（**查证 2026-11-24·二轮·近似**：描述错误（文档 :172 标 ThemeConfigScreen.kt:1077 行号对但名字错，真名 ThemeColorButton；文档第十三节称「只能 ThemeColorSelector 内部用」与上游公开函数不符））；原标注：`ThemeConfigScreen.kt:1077`（注释已注明·行级） | `title` / `paletteIndex` / `isDark` / `selected` / `onSelect` | 无外部调用（被同文件 `ThemeColorSelector:95` 内部用） |
| `ThemeItemDivider` | `components/ThemeItemDivider.ets:15` | ui/widget/components/divider/SettingItemDivider.kt:19（**查证 2026-11-24·二轮·近似**：描述过时（文档 :173 标 SettingItemDivider.kt:16，:16 是 import 行，真身 19）；差在参数面）；原标注：`SettingItemDivider.kt:16`（注释已注明·行级 `:16-45`） | 无 | `pages/AppReadAloudSettingsPage.ets:44` |
| `ThemeGroupColumn` | `components/settings/ThemeGroupColumn.ets:30` | ui/widget/components/SplicedColumnGroup.kt:42（**查证 2026-11-24·二轮·等价**：无差异（文档 :174 标 :42 与真身吻合））；原标注：`SplicedColumnGroup.kt:42`（注释已注明·行级 `:42-138`；另有 `:50`/`:55` 三来源优先级） | `title` / `surfaceFill` / `content`(Builder) | `pages/AppBackupSettingsPage.ets:469` |
| `ThemeGroupItem` | `components/settings/ThemeGroupColumn.ets:110` | ui/widget/components/SplicedColumnGroup.kt:150（**查证 2026-11-24·二轮·近似**：描述过时（文档 :175 标 :149，落在注解行，真身 150））；原标注：`SplicedColumnGroup.kt:149`（注释已注明·行级；另引 `SettingItemDivider.kt:23`） | `first` / `content`(Builder) | `pages/AppBackupSettingsPage.ets:470` |

**`ThemeGroupItem` 是全仓最热的设置类组件（61 处调用）**，`ThemeGroupColumn` 10 处。新设置页首选 `ThemeGroupColumn` + `ThemeGroupItem` + `Ui*` 这一套。

**一个容易踩的坑**：分组卡片的圆角必须读 `themeGroupRadius`，**不是** `themeCardRadius`。`ThemeGroupColumn.ets:9-12` 的注释写了原因——只有 `themeGroupRadius` 响应「关闭设置分组圆角」那个开关，读错键会让开关管不到分组。三来源优先级（上游 `SplicedColumnGroup.kt:50-54`）：`disableSplicedColumnGroupCornerRadius` → 0、`overrideBaseCardCornerRadius` → `baseCardCornerRadius`、否则 16。本地已由 `data/ThemeCardStyle.ets` 的 `resolveGroupCornerRadius()` 算好并广播。

`ThemeColorItem` 是 `ThemeColorSelector` 的内部件（外部调用 0，同文件内 2 处），**别在别处直接用它**——直接用 `ThemeColorSelector`。

---

## 六、图标与文本渲染（5 个）

| 组件 | 定义 | 上游等价物 | 关键 props | 首个调用点 |
| --- | --- | --- | --- | --- |
| `AppGlyph` | `components/AppGlyph.ets:4` | 上游无单一组件；对应物是 ui/widget/components/icon/AppIcon.kt:29 fun AppIcon( 与 Icons.Default.* + Icon(（**查证 2026-11-24·二轮·上游确实没有**：未查到。命令：`grep -rn "fun AppGlyph(" "$ROOT" --include=*.kt 2>/dev/null）；原标注：**上游无单一组件**——等价物是 `Icons.Default.*` 扩展 + `Icon(imageVector = ...)`。`AppGlyphName`（84 个成员）与上游图形名的对应关系见 `tmp/icon-impl-prompt.md` | `name: AppGlyphName`(默认 `'home'`) / `glyphSize`(22) / `tint: ResourceColor`(`'#C5C7D0'`) | `pages/AppBackupSettingsPage.ets:621` |
| `MarkdownIntro` | `components/MarkdownIntro.ets:140` | ui/widget/components/text/MarkdownBlock.kt:116（**查证 2026-11-24·二轮·近似**：无差异（文档 :190 标 MarkdownBlock.kt:116 与真身吻合）；差在参数面）；原标注：`MarkdownBlock.kt:116`（注释已注明·行级 `:119`） | `source` / `textColor` / `bodySize`(=`TITLE_SMALL` 14) / `bodyLineHeight`(=`TITLE_SMALL_LINE_HEIGHT` 20) / `onLinkClick` / `onImageClick` | `pages/BookSourceDebugPage.ets:583` |
| `RichIntro` | `components/RichIntro.ets:96` | ui/book/info/BookInfoScreen.kt:1635（**查证 2026-11-24·二轮·近似**：无差异（文档 :191 标 BookInfoScreen.kt:1635 与真身吻合）；差在参数面：上游 bookSource/onJumpToAnotherApp，本地 textColor/webNotice）；原标注：`BookInfoIntro @BookInfoScreen.kt:1635`（注释已注明·行级 `:1710 parseBookInfoIntro`；另引 `HtmlContent.kt:377-395`） | `intro` / `baseUrl` / `textColor` / `webNotice` / `onButtonClick` / `onImageClick` / `onImageLongClick` / `onLinkClick` | `pages/BookInfoPage.ets:2401` |
| `AloudStepper` | `components/ReadAloudGlassWidgets.ets:36` | ui/widget/components/ValueStepper.kt:20（**查证 2026-11-24·二轮·近似**：无差异（文档 :192 标 ValueStepper.kt:20 与真身吻合）；差在参数面：上游 value/displayValue/valueRange，本地 valueText/onDec/onInc）；原标注：`ValueStepper.kt:20`（注释已注明·行级 `:20-73`；另引 `GlassCard.kt:155` / `AppContainerBackground.kt:60-63`） | `valueText` / `stepperEnabled` / `onDec` / `onInc` | 无外部调用（同文件内 2 处） |
| `AloudSliderSetting` | `components/ReadAloudGlassWidgets.ets:77` | ui/widget/components/settingItem/TinySettingItems.kt:287（**查证 2026-11-24·二轮·近似**：无差异（文档 :193 标 :287 与真身吻合）；差在参数面：上游 imageVector/color/steps，本地 label/description/stepping 回调）；原标注：`TinySliderSettingItem @TinySettingItems.kt:287`（注释已注明·行级 `:287-373`，写明「常态显示 ValueStepper，点卡片才展开 AppSlider」） | `label` / `description` / `valueText` / `value` / `min` / `max` / `step` / `settingEnabled` / `onChange` / `onCommit` / `onDec` | `pages/ReadAloudConfigPanel.ets:178` |

**`AppGlyph` 是全仓第一热（293 处调用）**，比第二名 `ThemeGroupItem`(61) 多近 5 倍。它的着色与尺寸别自己改：140 个 svg 全部写死 `fill`、`currentColor` 零命中，所以 `tint` 走的是**渲染期覆盖**（`.fillColor(this.tint)`），不是改 svg；`tint` 类型是 `ResourceColor` 而不是 `string`，就是为了让调用方能传 `$r('app.color.*')` 从而跟随深浅色（`AppGlyph.ets:7-9` 注释）。

**`RichIntro` 与 `MarkdownIntro` 不是一个东西**：前者渲染书籍简介（可能含 HTML），后者渲染 Markdown（书源调试页在用）。选哪个看数据源是什么格式。`MarkdownIntro` 明确不做表格（上游 `MarkdownBlock.kt` 用 FlowRow 排版，本地 `| a | b |` 原样显示），这是已知偏差不是 bug。

**`AloudStepper` 与 `AloudSliderSetting` 都出自 `ReadAloudGlassWidgets.ets`**，是朗读面板的磨砂玻璃一族。鸿蒙没有 Compose 的 nine-patch 容器背景图，本地用「带 alpha 的主题色 + `backdropBlur`」近似上游半透明磨砂玻璃（`ReadAloudGlassWidgets.ets:15-16`）。

---

## 七、阅读与知识（3 个）

| 组件 | 定义 | 上游等价物 | 关键 props | 首个调用点 |
| --- | --- | --- | --- | --- |
| `ReaderQuickMarkPanel` | `components/ReaderQuickMarkPanel.ets:25` | `MarkingSelectionMenu.kt:89`（**查证 2026-11-24·近似**；同族 `:388` 色行 / `:474` 效果块 / `:550` 规则块）；原标注：`MarkingSelectionMenu @MarkingSelectionMenu.kt:89`（注释已注明·文件级 `ReaderQuickMarkPanel.ets:8` 引 `ReadBookRouteScreen.kt` 的 `inlineMode` 预览态；同族 `MarkingColorRow:388` / `MarkingEffectTile:474` / `MarkingRuleTile:550`） | `quickStyle` / `quickNote` / `existingMarking` / `onStyleChange` / `onNoteChange` / `onApply` / `onDelete` / `onClose` | `pages/ReaderPage.ets:8533` |
| `BookKnowledgeSheet` | `components/BookKnowledgeSheet.ets:21` | **不匹配** → `ui/book/knowledge/` 四个 Screen：`BookKnowledgeListScreen.kt:44` / `BookCharacterListScreen.kt:71` / `BookEventListScreen.kt:44` / `BookKnowledgeDetailScreen.kt:61`（**查证 2026-11-24**；原标 `BookInfoScreen.kt:2325` 只是详情页「知识」预览区块）；原标注：`BookInfoKnowledge @BookInfoScreen.kt:2325`（注释已注明·文件级 `BookKnowledgeSheet.ets:11`「对齐上游 ui/book/knowledge 四个列表 Screen」；同族 `KnowledgeInfoCard:2374` / `BookKnowledgeEditCard @BookInfoEditScreen.kt:297` / `BookKnowledgeDetailScreen.kt:61`） | `bookUrl` / `initialTab` / `onClose` | `pages/BookInfoEditPage.ets:882` |
| `BookSourceStageRuntimeHost` | `components/BookSourceStageRuntimeHost.ets:9` | **上游确实没有**（**查证 2026-11-24**：书源规则由 Rhino 在 JVM 内求值，`App.kt:346 initRhino` / `AnalyzeUrl.kt:406 eval`，解析链路不经 Web 控制器）；原标注：**本地自造**（书源 ArkWeb 阶段运行时宿主，上游没有对应物——上游脚本跑在 JVM 里不需要 Web 控制器） | 无对外 props | `pages/Index.ets:14778` |

**`BookKnowledgeSheet` 的数据层是齐的**：`data/BookKnowledgeRepository.ets` 里的类 + 5 个接口（角色卡 / 事件 / 关系网 / 知识卡 / 大纲）+ 4 个 `New*` 写入接口。做详情页知识功能时先读这个文件，别另起表。它 616 行、四面板（人物 / 关系网 / 世界知识 / 事件），手工增删改全部落地；**「AI 识别人物」按钮故意没画**——上游那个按钮调 `AiToolRepository`，本地 AI 面 0 命中，画出来只能弹提示，属假控件（`BookKnowledgeSheet.ets:14-15` 注释）。

**`BookSourceStageRuntimeHost` 是 1×1 透明 Web 挂在 `Index` 根 Stack 常驻**（不随页面销毁），因为书源脚本的 `execute()` 需要一个真实 Web 控制器才能跑登录/脚本。它是全局唯一实例，别在别处再挂一个。

---

## 八、书源与搜索（21 个，`components/booksource/` 为主）

这一族是 11-23 之后长得最快的一块：`booksource/` 从 4 个组件涨到 15 个。它们都服务于「书源管理 / 发现 / 搜索 / 校验 / 登录」四条链路，**互相之间的耦合比 UI 层其他族更紧**——`SearchBookItems.ets` 一个文件里三个 struct，`ExploreKindItem.ets` 与 `SourceLoginSheet.ets` 各两个。

| 组件 | 定义 | 上游等价物 | 关键 props | 首个调用点 |
| --- | --- | --- | --- | --- |
| `AppFab` | `components/booksource/AppFab.ets:15` | ui/widget/components/AppFloatingActionButton.kt:60（**查证 2026-11-24·二轮·近似**：无差异（文档 :223 标 :60 与真身吻合）；差在参数面：图标类型）；原标注：`AppFloatingActionButton.kt:60`（注释已注明·行级 `:60-68`；另引 `:100` / `Tooltip.kt:98`） | `icon: AppGlyphName`(默认 `'profileSave'`) / `fabAccessibilityText` / `onFabClick` / `onStateChange` | `pages/BookSourceDebugPage.ets:531` |
| `BookshelfConflictSheet` | `components/booksource/BookshelfConflictSheet.ets:178` | `BookshelfConflictSheet.kt:88`（**查证 2026-11-24·等价**）；原标注：`BookshelfConflictSheet @ui/widget/components/conflict/BookshelfConflictSheet.kt:88`（注释已注明·文件级 `booksource/BookshelfConflictSheet.ets:3`，同名） | `conflict` / `isResolving` / `onDismissRequest` / `onOpenExistingBook` / `onCoexist` / `onMigrate` / `onPick` / `onOpenBook` / `onDisappear` | `pages/ExploreShowPage.ets:1424` |
| `ConflictRadio` | `components/booksource/BookshelfConflictSheet.ets:149` | `AppRadioButtom.kt:14`（**查证 2026-11-24·等价**；上游文件名自己把 Button 拼成 Buttom）；原标注：`AppRadioButton @ui/widget/components/AppRadioButtom.kt:14`（索引匹配；上游文件名把 Button 拼成 Buttom，不是笔误抄错） | `selected` / `onPick` | 无外部调用（同文件内 2 处） |
| `ChangeCoverSheet` | `components/booksource/ChangeCoverSheet.ets:42` | ui/book/info/BookInfoSheets.kt:194（**查证 2026-11-24·二轮·近似**：无差异（文档 :226 标 BookInfoSheets.kt:194 与真身吻合）；差在参数面）；原标注：`ChangeCoverSheet @ui/book/info/BookInfoSheets.kt:194`（注释已注明·行级 `:194-272`） | `bookName` / `author` / `isNight` / `onSelect` / `onMessage` | `pages/BookInfoEditPage.ets:732` |
| `ContentQualitySheet` | `components/booksource/ContentQualitySheet.ets:26` | ui/book/search/SearchScreen.kt:835（**查证 2026-11-24·二轮·近似**：描述过时（文档 :227 标 SearchScreen.kt:834，:834 是 @Composable 注解行，真身 835）；差在参数面）；原标注：`SearchScreen.kt:834`（注释已注明·行级） | `chapterSpec` / `keywords` / `skipHeadChars` / `isRunning` / `stage` / `processedBooks` / `totalBooks` / `currentBookName` / `resultCount` / `excludedCount` / `onChapterSpecChange` / `onKeywordsChange` | `pages/SearchPage.ets:1741` |
| `ExpandedSourceContent` | `components/booksource/ExpandedSourceContent.ets:21` | ui/book/search/SearchScreen.kt:1120（**查证 2026-11-24·二轮·近似**：描述过时（文档 :228 标 SearchScreen.kt:1119，:1119 是 @Composable 注解行，真身 1120）；差在参数面：savedScrollIndex/Offset 等）；原标注：`SearchScreen.kt:1119`（注释已注明·行级） | `sourceName` / `books` / `isLoading` / `isEnd` / `errorMsg` / `coverSettings` / `isNight` / `onLoadMore` / `onBookClick` / `onBookLongClick` / `onSelect` / `onLongPress` / `onRetry` | `pages/SearchPage.ets:1816` |
| `ExploreKindItem` | `components/booksource/ExploreKindItem.ets:62` | `ExploreKindItem.kt:28`（**查证 2026-11-24·近似**；原标 `:52` 落在函数体内）；原标注：`ExploreKindItem @ui/widget/components/explore/ExploreKindItem.kt:52`（注释已注明·文件级 `:4`；另引 `ExploreKindMultiTypeItem.kt` / `ExploreKindSelectSheet.kt`） | `kind` / `sourceUrl` / `selected` / `submitOnClick` / `toggleOnClick` / `onOpenUrl` / `onItemClick` / `onRefreshKinds` / `onMessage` / `onSelect` / `onStateChange` / `onDisappear` | 无外部调用（同文件内 2 处，由 `ExploreKindSelectSheet:409` 用） |
| `ExploreKindSelectSheet` | `components/booksource/ExploreKindItem.ets:409` | `ExploreKindSelectSheet.kt:42`（**查证 2026-11-24·近似**）；原标注：`ExploreKindSelectSheet @ui/widget/components/explore/ExploreKindSelectSheet.kt:42`（注释已注明·文件级 `:11`；索引匹配补到 `:42`） | `sourceUrl` / `multiple` / `initialSelectedTitles` / `onSelected` / `onDismissRequest` / `onOpenUrl` / `onItemClick` / `onRefreshKinds` / `onMessage` | `pages/ExploreShowPage.ets:1486` |
| `LoadMoreFooter` | `components/booksource/LoadMoreFooter.ets:35` | ui/widget/components/LoadMoreFooter.kt:43（调用包装 :502 ExploreShowScreen.kt）（**查证 2026-11-24·二轮·近似**：描述错误（文档 :231 标 ExploreShowScreen.kt:500，标到调用点文件而非定义文件；真身 LoadMoreFooter.kt:43）；差在粒度）；原标注：`ExploreShowScreen.kt:500`（注释已注明·行级） | `isLoading` / `errorMsg` / `isEnd` / `autoLoad` / `showLoadMore` / `onRetry` / `onLoadMore` | `pages/ExploreShowPage.ets:1230` |
| `ScopeSelectSheet` | `components/booksource/ScopeSelectSheet.ets:36` | `ScopeSelectSheet.kt:35`（**查证 2026-11-24·近似**）；原标注：`ScopeSelectSheet @ui/book/search/ScopeSelectSheet.kt:35`（注释已注明·文件级 `:4`，同名） | `initialIsAll` / `initialIsSourceScope` / `initialGroupNames` / `initialSourceUrls` / `groups` / `sources` / `onOpenSourceManage` / `onApplyScope` / `onDismissRequest` / `onQueryChange` | `pages/SearchPage.ets:1771` |
| `SearchBar` | `components/booksource/SearchBar.ets:22` | `SearchBar.kt:42`（**查证 2026-11-24·近似**）；原标注：`SearchBar @ui/widget/components/SearchBar.kt:42`（注释已注明·文件级 `:4`，同名） | `placeholder` / `showClear` / `clearLabel` / `autoFocus` / `onQueryChange` / `onSearch` / `onClear` | `pages/ProfileSubPages.ets:1604` |
| `SearchBookTagChip` | `components/booksource/SearchBookItems.ets:112` | ui/widget/components/book/SearchBookItem.kt:360（**查证 2026-11-24·二轮·等价**：描述过时（文档 :234 标 SearchBookItem.kt:357，:357 是上一函数收尾，真身 360））；原标注：`SearchBookItem.kt:357`（注释已注明·行级） | `text` | `components/booksource/SearchBookPreviewSheet.ets:139` |
| `SearchBookListItem` | `components/booksource/SearchBookItems.ets:143` | ui/widget/components/book/SearchBookItem.kt:68（**查证 2026-11-24·二轮·近似**：描述过时（文档 :235 标 SearchBookItem.kt:76，:76 在函数体内，真身 68）；差在参数面）；原标注：`SearchBookItem.kt:76`（注释已注明·行级） | `item` / `shelfState` / `showPadding` / `sourceCount` / `qualityMasked` / `adaptCoverAspectRatio` / `coverSettings` / `isNight` / `sharedKey` / `onSelect` / `onLongPress` | `pages/ExploreShowPage.ets:1076` |
| `SearchBookGridItem` | `components/booksource/SearchBookItems.ets:349` | ui/widget/components/book/SearchBookItem.kt:265（**查证 2026-11-24·二轮·近似**：描述过时（文档 :236 标 SearchBookItem.kt:264，:264 是 @OptIn 注解行，真身 265）；差在参数面）；原标注：`SearchBookItem.kt:264`（注释已注明·行级） | `item` / `shelfState` / `qualityMasked` / `coverSettings` / `isNight` / `sharedKey` / `onSelect` / `onLongPress` | `pages/ExploreShowPage.ets:1131` |
| `SearchBookPreviewSheet` | `components/booksource/SearchBookPreviewSheet.ets:39` | ui/widget/components/book/SearchBookPreviewSheet.kt:42（**查证 2026-11-24·二轮·近似**：描述错误（文档 :237 标 SearchBook.kt:41，落在该实体字段而非组件；真身 SearchBookPreviewSheet.kt:42）；差在参数面）；原标注：`SearchBook.kt:41`（注释已注明·行级） | `item` / `shelfState` / `coverSettings` / `isNight` / `sharedKey` / `onOpenDetail` / `onAddToShelf` | `pages/ExploreShowPage.ets:1394` |
| `SearchSettingsSheet` | `components/booksource/SearchSettingsSheet.ets:40` | ui/book/search/SearchScreen.kt:686（宿主 fun SearchScreen :144 内）（**查证 2026-11-24·二轮·近似**：描述不完整（文档 :238 标 :686-767 是 SearchScreen 内一段内联 sheet，无可独立引用的签名）；差在粒度）；原标注：`SearchScreen.kt:686`（注释已注明·行级 `:686-767`） | `layoutMode` / `selectedSourceTypes` / `onLayoutModeChange` / `onOpenContentQuality` / `onToggleSourceType` / `onClearAllSourceTypes` / `onSelect` / `onToggleSelection` | `pages/SearchPage.ets:1799` |
| `SelectionItemCard` | `components/booksource/SelectionItemCard.ets:25` | `SelectionItemCard.kt:59`（**查证 2026-11-24·近似**；Content 在同文件 `:134`）；原标注：`SelectionItemCard @ui/widget/components/card/SelectionItemCard.kt:59`（注释已注明·文件级 `:4`，同名；另引 `SelectionItemCardContent:134`） | `title` / `subtitle` / `isSelected` / `inSelectionMode` / `cardCornerRadius` / `containerColor` / `selectedContainerColor` / `contentDescription` / `onToggleSelection` / `trailingAction` | `pages/SearchPage.ets:1451` |
| `SourceCheckSheet` | `components/booksource/SourceCheckSheet.ets:17` | ui/book/source/manage/CheckSourceBottomSheet.kt:22（**查证 2026-11-24·二轮·近似**：无差异（文档 :240 标 CheckSourceBottomSheet.kt:22 与真身吻合）；差在参数面）；原标注：`CheckSourceBottomSheet.kt:22`（注释已注明·行级 `:67-101`；另引 `BookSourceContract.kt:33-40` 的默认值） | **`@Link visible: boolean`** / `onConfirm(options: SourceCheckOptions)` / `onDisappear` | `pages/ProfileSubPages.ets:1897` |
| `SourceCheckRunSheet` | `components/booksource/SourceCheckRunSheet.ets:21` | ui/book/source/manage/BookSourceScreen.kt:781（**查证 2026-11-24·二轮·近似**：描述过时（文档 :241 标 BookSourceScreen.kt:780，落在注解行，真身 781）；差在参数面）；原标注：`BookSourceScreen.kt:780`（注释已注明·行级 `:780-819`） | **`@Link visible: boolean`** / `sourceCount` / `onOpenSettings` / `onConfirm(keyword)` / `onDisappear` | `pages/ProfileSubPages.ets:1906` |
| `SourceLoginSheet` | `components/booksource/SourceLoginSheet.ets:163` | ui/login/SourceLoginSheets.kt:60（**查证 2026-11-24·二轮·近似**：无差异（文档 :242 标 SourceLoginSheets.kt:60 与真身吻合）；差在参数面）；原标注：`SourceLoginSheetHost @ui/login/SourceLoginSheets.kt:60`（注释已注明·行级 `:59-106`；另引 `SourceLoginContract.kt:23-28` / `SourceLoginViewModel.kt:154`/`:238-244`） | **`@Link visible: boolean`** / `onClose` / `onOpenWeb(url)` / `onUnavailableAction(message)` / `onItemClick` / `onOptionPick` / `onWillDismiss` | `pages/Index.ets:15044` |
| `LoginKindItem` | `components/booksource/SourceLoginSheet.ets:74` | ui/login/SourceLoginSheets.kt:195（SourceLoginContract.kt:23 是 data class，:31 sealed interface）（**查证 2026-11-24·二轮·不匹配**：描述错误（标注指向 data class 而非 composable，且上游无同名组件）；差在名字与粒度）；原标注：`SourceLoginContract.kt:23`（注释已注明·行级；另引 `ExploreKindItem.kt:46`） | `label` / `glyphName` / `alignEnd` / `itemEnabled` / `options` / `onItemClick` / `onOptionPick` | 无外部调用（同文件内 4 处） |

**三个 `@Link visible` 组件必须被父级的 `@State` 绑定**，不是传值。父级写法：`@State checkVisible: boolean = false` → `SourceCheckSheet({ visible: $checkVisible, ... })`。传字面量 `visible: false` 不会响应，也不会报错——只是面板永远不出现。这是这一族最容易踩的一个坑（第十三节也列了）。

**`SelectionItemCard` 的 `SmallPlainIconButton` 在同一个文件里**（`SelectionItemCard.ets:155`），它已经被上一节收进「菜单·面板」表，此处不重复。

**`SearchBookItems.ets` 一个文件三个 struct 是刻意的**：标签 chip / 列表行 / 网格项共享同一份「封面板式 + 书架态 + 质量遮罩」逻辑，拆成三个文件会各写一遍。改其中一个时先确认另外两个没有共用那段。

**`ContentQualitySheet` / `ExpandedSourceContent` / `SearchSettingsSheet` 三个都挂 `SearchScreen.kt`**（`:834` / `:1119` / `:686`），它们同属搜索页的三块浮层：内容质量过滤、按源展开结果、搜索设置。搜索页改版时必须一起动。

---

## 九、设置与主题弹层（6 个，全部挂 `pages/ThemeSettingsPage.ets`）

这六个面板的共同点是：**一个页面开六个 sheet**，全部由 `ThemeSettingsPage.ets` 挂载（`:608`–`:681`），不在别处复用。所以改它们只有两个入口——改组件本身，或改那个页面的挂载与传参。

| 组件 | 定义 | 上游等价物 | 关键 props | 挂载点 |
| --- | --- | --- | --- | --- |
| `AppFontSheet` | `components/settings/AppFontSheet.ets:34`（351 行） | ui/widget/components/FontSelectSheet.kt:49；ui/widget/components/FontSelectGrid.kt:99（**查证 2026-11-24·二轮·近似**：描述不完整（文档 :261 只给文件级 FontSelectSheet.kt + FontSelectGrid.kt，未给确切行；真身 49/99）；差在粒度）；原标注：`FontSelectSheet.kt` + `FontSelectGrid.kt`（注释已注明·文件级 `:11`，含 `FontSelectSheet.kt:95-146` / `:127-133` / `:136-143` / `FontSelectGrid.kt:70` / `:250-280`） | `selectedPath` / `folderPath` + 内部 `@State fonts/folderState/query/sortIndex/sortMenuVisible` | `pages/ThemeSettingsPage.ets:608` |
| `NavIconManageSheet` | `components/settings/NavIconManageSheet.ets:36`（242 行） | ui/config/themeConfig/NavIconManageSheet.kt:48（**查证 2026-11-24·二轮·近似**：描述不完整（文档 :262 只给文件级 ui/config/themeConfig/NavIconManageSheet.kt(:1)，真身 48）；差在参数面）；原标注：`ui/config/themeConfig/NavIconManageSheet.kt`（225 行，注释已注明·文件级 `:1`；另引 `ThemeConfigRouteScreen.kt:59-86`） | `slotPaths: string[]` / `onSelectIcon(slot,path)` / `onClearIcon(slot)` | `pages/ThemeSettingsPage.ets:622` |
| `TopBottomBarSettingsSheet` | `components/settings/TopBottomBarSettingsSheet.ets:46`（216 行） | ui/config/themeConfig/TopBottomBarSettingsSheet.kt:25（**查证 2026-11-24·二轮·近似**：描述过时（文档 :263 标 :49，:49 在函数体内，真身 25）；差在参数面）；原标注：`TopBottomBarSettingsSheet.kt`（177 行，注释已注明·行级 `:49-174`，十三个键一一对应） | `useFlexibleTopAppBar` / `topBarButtonStyle` / `mergeTopBarActions` / `showBottomView` / `useFloatingBottomBar` / `useFloatingBottomBarLiquidGlass` / `bottomBarLensRadius`(24) / `enableBlur` / `topBarBlurRadius`(24) / `bottomBarBlurRadius`(8) / `topBarBlurAlpha`(73) / `bottomBarBlurAlpha`(40) / `topBarOpacity`(100) / `bottomBarOpacity`(100) | `pages/ThemeSettingsPage.ets:628` |
| `LauncherIconPickerSheet` | `components/settings/LauncherIconPickerSheet.ets:31`（186 行） | ui/config/themeConfig/LauncherIconPickerSheet.kt:49（**查证 2026-11-24·二轮·近似**：描述过时（文档 :264 标 :69，:69 在函数体内，真身 49）；差在数据源语义）；原标注：`ui/config/themeConfig/LauncherIconPickerSheet.kt`（199 行，注释已注明·行级 `:69-127`；内置图标表 `:139-194`） | `selectedId` / `onDismiss` / `onIconChanged(iconId)` | `pages/ThemeSettingsPage.ets:658` |
| `BackgroundImageManageSheet` | `components/theme/BackgroundImageManageSheet.ets:88`（256 行） | ui/config/themeConfig/BackgroundImageManageSheet.kt:56（**查证 2026-11-24·二轮·近似**：描述不完整（文档 :265 只给文件级 :3，真身 56）；差在参数面）；原标注：`ui/config/themeConfig/BackgroundImageManageSheet.kt`（199 行，注释已注明·文件级 `:3`，结构逐条写在 `:5-15`） | `title` / `lightPath` / `darkPath` / `extraOption: BackgroundImageExtraOption` | `pages/ThemeSettingsPage.ets:666` |
| `MainNavigationSettingsSheet` | `components/theme/MainNavigationSettingsSheet.ets:41`（258 行） | ui/config/themeConfig/MainNavigationSettingsSheet.kt:34（**查证 2026-11-24·二轮·近似**：描述过时（文档 :266 标 :63，:63 在函数体内，真身 34）；差在交互形态）；原标注：`ui/config/themeConfig/MainNavigationSettingsSheet.kt`（195 行，注释已注明·行级 `:63-85` 的三条逻辑） | `mainNavigationOrder` / `defaultHomePage` / `labelVisibilityMode` / `showHome` / `showDiscovery` / `showRss` / `customNavIconCount` | `pages/ThemeSettingsPage.ets:681` |

**六处「本地做不到上游那样」的近似，都写在各自文件头注释里，别当 bug 修**：

- `BackgroundImageManageSheet` 的上游滑块范围是 0..100，本地背景虚化此前被 `data/ThemeSettingsRepository.ets:222-227` 的 `normalizeBackgroundBlur()` 夹在 0..40，本面板落地时同一批把上限改成 100，**两处不再打架**。上游 `AsyncImage` 直接吃路径，本地 `Image` 必须 `file://` 前缀（由调用方传已可用的 uri）。
- `NavIconManageSheet` 没有上游的 `NormalCard`，用 `Column` + 圆角 + `themeColorSurfaceTertiary` 承接；菜单用本地 `UiMenuPanel`（上游是 `RoundDropdownMenu`）；选图走 `picker.PhotoViewPicker`（上游 `ActivityResultContracts.GetContent()`），落盘口径一致——复制进 `filesDir/nav_icons/<内容摘要>.png`。
- `LauncherIconPickerSheet` **唯一的实质差异在数据源**：上游写死 8 个内置 mipmap（`LauncherIcons.list`），鸿蒙图标包由 AGC 下发、应用侧无法写死，改成向系统查询（`data/LauncherIconLibrary.ets` 的 `queryLauncherIcons`）。多出来的「恢复默认」入口是本地补的——上游靠禁用其余 component 回默认，鸿蒙必须显式调 `disableDynamicIcon`。
- `MainNavigationSettingsSheet` 上游用 `rememberReorderableLazyListState` 长按拖拽，本地用 `List` + `editMode(true)` + `onItemDragStart`/`onItemDrop`，与外观页「主导航顺序」同一套，并**保留下移按钮作为无障碍回退**。
- `AppFontSheet` 上游标题行三栏的左右 action 是 `MediumTonalButton`，本地没有这个组件，画成文字 + 图标（同类近似见 `pages/ReaderAloudSettingsPage.ets:235`）。
- `TopBottomBarSettingsSheet` 本地原先是外观页里的一个可展开组，改 sheet 是为了与其余六个面板形态一致；十三个键与上游 `:49-174` 一一对应。

---

## 十、设计令牌与非组件模块（5 个文件，不是组件但必须知道）

`components/` 下 61 个文件里，**5 个不导出 struct**。改 UI 时它们的权重比任何一个组件都高——组件是「长什么样」，这五个是「用什么值」。

| 文件 | 行数 | 导出面 | 用途 |
| --- | --- | --- | --- |
| `components/UiTokens.ets` | 62 | 20 个 `export const`（间距 / 圆角 / 时长 / 阈值） | 非文字类几何与时长令牌 |
| `components/typography/TypographyTokens.ets` | 131 | 52 个 `export const`（24 槽位 × 字号/行高 + 4 个 M3 原生 TypeScale） | 字号与行高令牌 |
| `components/ProfileUiMetrics.ets` | 8 | 6 个 `export const` | 「我的」页专用字号与行距 |
| `components/CoverTextLayout.ets` | 175 | 3 个 function + 2 个 interface | 封面书名折行计算（不画界面） |
| `components/motion/CubicBezier.ets` | 85 | 1 个 function `cubicBezierEasing` | 自定义贝塞尔曲线（11-22 新增） |

### 10.1 UiTokens 的 20 个常量（按用途分组）

| 组 | 常量 |
| --- | --- |
| 间距 | `SPACE_2` `SPACE_4` `SPACE_8` `SPACE_12` `SPACE_16` `SPACE_20` `SPACE_24` |
| 行内边距 | `ROW_PADDING_H` `ROW_PADDING_V` |
| 分节 | `SECTION_TITLE_TOP` `SECTION_TITLE_BOTTOM` `SECTION_GAP` |
| 展开区 | `EXPAND_PADDING_BOTTOM` `EXPAND_BUTTONS_TOP` `EXPAND_BUTTONS_BOTTOM` |
| 圆角 | `RADIUS_INNER` |
| 时长 | `DURATION_FADE` `DURATION_PAGE_SWITCH` |
| 阈值 | `HEADER_COLLAPSE_THRESHOLD` `HEADER_EXPAND_THRESHOLD` |

`RADIUS_INNER` 只有 1 个圆角常量，是为了「内层卡片比外层小一档」这种用法；**分组圆角不在这里**，见 10.4。

### 10.2 TypographyTokens 的 24 槽位（字号 / 行高，字重另配）

| 槽位 | 字号 | 行高 | 上游 `LegadoTheme.kt` 行 | 对应 miuix |
| --- | --- | --- | --- | --- |
| `HEADLINE_LARGE` | 32 | 40 | `:86` | title1（比 1.25） |
| `HEADLINE_MEDIUM` | 24 | 30.86 | `:88` | title2（1.2857） |
| `HEADLINE_SMALL` | 20 | 26.67 | `:90` | title3（1.3333） |
| `TITLE_LARGE` | 18 | 22.91 | `:93` | title4（1.2727） |
| `TITLE_MEDIUM` | 16 | 24 | `:95` | headline2（1.5） |
| `TITLE_SMALL` | 14 | 20 | `:97` | subtitle（1.4286，**Bold**） |
| `BODY_LARGE` | 17 | 25.5 | `:101` | paragraph（1.5） |
| `BODY_MEDIUM` | 16 | 22.86 | `:103` | body1（1.4286） |
| `BODY_SMALL` | 12 | 16 | `:105` | body2（1.3333） |
| `LABEL_LARGE` | 14 | 18.67 | `:108` | footnote1.copy(14sp) |
| `LABEL_MEDIUM` | 13 | 17.33 | `:110` | footnote1 |
| `LABEL_SMALL` | 11 | 16 | `:112` | footnote2（1.4545） |

每个槽位再配一个 `_EMPHASIZED` 变体（同字号同高、字重 Medium），**共 24 个**。

三个必须知道的事实：

1. **`TITLE_SMALL` 是 Bold，而 `TITLE_SMALL_EMPHASIZED` 是 Medium —— Emphasized 反而更轻。** 上游 `Typography.kt:30` 的 `subtitle` 作者注释写「14.sp, Bold」，`:109` 的 Emphasized 变体降到 Medium。所以「加粗到 titleSmall」在本地要显式 `.fontWeight(FontWeight.Bold)`，写 `TITLE_SMALL_EMPHASIZED` 是在往轻里改。
2. **行高是绝对 fp 不是比例，这是能力边界。** 上游 `Typography.kt:90` 用 `(lineHeight / fontSize).em` 表达相对行高；ArkUI 的 `lineHeight` 收 `number | string | Resource`，字符串支持 `"10"` / `"10fp"`，**不支持 em**（`component/units.d.ts` 全文搜 em 零命中）。所以本地把「比例 × 字号」预乘成绝对 fp。响应性没丢：`pages/Index.ets:3869` 的 `setFontSizeScale` 会缩放 fp，行高跟着缩，效果与上游 em 一致。
3. **ArkUI 没有 `CompositionLocal`**（SDK 全目录 grep 零命中），所以上游那种「调用点只写 `LegadoTheme.typography.titleMedium` 由层隐式提供」的写法搬不过来。本地每个调用点必须显式写出槽位名——这是能力边界不是设计取舍。

### 10.3 4 个 M3 原生 TypeScale（与上面 24 槽位是两套，不许合并）

| 常量 | 值 | 上游出处 |
| --- | --- | --- |
| `TYPE_SCALE_HEADLINE_MEDIUM` | 28 | `GlassMediumFlexibleTopAppBar.kt` 展开态标题取 M3 `headlineMedium` |
| `TYPE_SCALE_TITLE_LARGE` | 22 | `GlassTopAppBar.kt:76` 收起态标题取 M3 `titleLarge` |
| `TYPE_SCALE_LABEL_LARGE` | 14 | M3 `labelLarge`（与 24 槽位的 `LABEL_LARGE` 同值不同源） |
| `TYPE_SCALE_BODY_LARGE` | 16 | M3 `bodyLarge`，对应 M3 `TextField` 的默认输入样式 |

为什么必须分成两套：上游 `ThemeComponents.kt:257` 的 `val base = Typography()` 是 **M3 无参构造**，`:281` 以 `typography = materialTypography` 传给 `MaterialExpressiveTheme`；而 24 槽位来自 `Typography.kt:18-40` 的 miuix 映射。**两套同时存在**。顶栏标题用的是第二套，所以 28 / 22 不是本地自造值，也不该「就近」归进 24 槽位的 24 / 20。

### 10.4 圆角与分组（一个反复出错的点）

分组容器的圆角**读 `themeGroupRadius`，不读 `themeCardRadius`**。原因：只有 `themeGroupRadius` 响应「关闭设置分组圆角」那个开关；读错键会让开关管不到分组。三来源优先级（上游 `SplicedColumnGroup.kt:50-54`）：`disableSplicedColumnGroupCornerRadius` → 0、`overrideBaseCardCornerRadius` → `baseCardCornerRadius`、否则 16。本地由 `data/ThemeCardStyle.ets` 的 `resolveGroupCornerRadius()` 算好并广播。

### 10.5 剩下三个小模块

`ProfileUiMetrics.ets` 8 行 6 个常量，专给「我的」页：`PROFILE_PAGE_TITLE_SIZE` / `PROFILE_PAGE_SUBTITLE_SIZE` / `PROFILE_SECTION_TITLE_SIZE` / `PROFILE_ROW_TITLE_SIZE` / `PROFILE_ROW_DETAIL_SIZE` / `PROFILE_ROW_VERTICAL_PADDING`。**它绕开了 `TypographyTokens`**，是「我的」页字号与其余页面不同步的地方——要统一就改这 6 个值的取用方式，别改页面里的字面量。

`CoverTextLayout.ets` 175 行 3 个 function（`isLatinBasedText` / `isCoverTextHorizontal` / `buildCoverTextLayout`）+ 2 个 interface（`CoverTextGlyph` / `CoverTextLayout`）。它只算排版不算绘制：给定书名、字号、可用宽度，返回逐行折好的字形坐标。封面组件拿结果去画。**改封面书名排版改这里，不要改 `BookCover`**。

`motion/CubicBezier.ets` 85 行 1 个 function `cubicBezierEasing`，11-22 新增。ArkUI 的 `curves` 只提供预设曲线，需要自定义贝塞尔时用它算插值再喂给 `animateTo`。

---

## 十一、页面在哪（`pages/` 51 文件 / 71,702 行 / 147 个 struct）

这份文档只收 `components/` 下的 70 个对外的可复用组件。但**大部分界面代码不在这 70 个里**——它在 `pages/` 的 147 个 struct 里，其中很多是「某个页面专用的面板，有名字、有 props，但从没被第二个页面用过」。

判断一个组件该不该进本表，用一条标准：**它是否被 ≥2 个调用点用过，或是否被用作页面的组成部分而非页面本身。** 只在一个页面里用一次且与页面逻辑强耦合的，留在页面里。

### 11.1 行数前 22 的页面

| 页面 | 行数 | struct 数 | 说明 |
| --- | --- | --- | --- |
| `Index.ets` | 15,140 | 2 | 总入口。**只有 2 个 struct 却 1.5 万行**，绝大多数 UI 内联在 @Builder 里 |
| `ReaderPage.ets` | 9,968 | 3 | 阅读主界面，含翻页、菜单、划词、目录等全部浮层 |
| `ProfileSubPages.ets` | 8,260 | 32 | 「我的」下的全部二级页，**32 个 struct 挤一个文件** |
| `BookshelfPage.ets` | 5,150 | 2 | 书架。书卡内联在 `:2640` 起（`components/BookCard.ets` 是死代码） |
| `ReaderSettingsPage.ets` | 4,649 | 19 | 阅读设置 |
| `BookInfoPage.ets` | 3,045 | 4 | 书籍详情 |
| `BookshelfManagePage.ets` | 2,347 | 1 | 书架管理 |
| `SearchPage.ets` | 2,036 | 1 | 搜索 |
| `ExploreShowPage.ets` | 1,588 | 2 | 发现/书源展示 |
| `CatalogPage.ets` | 1,327 | 2 | 目录 |
| `LocalReaderPaginator.ets` | 1,250 | 0 | **0 个 struct**，纯排版计算 |
| `ThemeSettingsPage.ets` | 1,093 | 2 | 外观设置，挂九节的六个 sheet |
| `ReaderHighlightRuleSheet.ets` | 997 | 1 | 高亮规则 |
| `AppBackupSettingsPage.ets` | 982 | 7 | 备份与恢复 |
| `BookSourceEditPage.ets` | 963 | 1 | 书源编辑 |
| `BookInfoEditPage.ets` | 926 | 1 | 书籍信息编辑 |
| `ReadAloudPlayerPage.ets` | 773 | 5 | 朗读播放器 |
| `BatchChangeSourceSheet.ets` | 768 | 1 | 批量换源 |
| `HomePage.ets` | 708 | 2 | 首页 |
| `AppCoverSettingsPage.ets` | 688 | 2 | 封面设置 |
| `ReaderSearchPage.ets` | 618 | 2 | 阅读内搜索 |
| `BookSourceDebugPage.ets` | 602 | 2 | 书源调试 |

**`ProfileSubPages.ets` 32 个 struct 与 `ReaderSettingsPage.ets` 19 个 struct 值得单独留意**：它们是「一堆小面板塞进一个文件」，改其中任何一个都要在 8 千 / 4 千行里定位。要找某个面板时先在这个文件里搜 `@Component`，再往下找 `struct`。

---

## 十二、上游有、本地没有的（本节是清单，不是待办）

这一节只收**本轮有源码证据能确认**的条目。**完整比对没做**，原因写在后面。

| 上游组件 | 定义 | 本地情况 |
| --- | --- | --- |
| `NormalCard` | `ui/widget/components/card/NormalCard.kt` | 无独立组件。各面板用 `Column` + 圆角 + `themeColorSurfaceTertiary` 各自承接（见九节三处注释） |
| `MediumTonalButton` / `SmallTonalButton` | `ui/widget/components/button/` | 无独立组件。用文字 + 图标近似（`AppFontSheet.ets:24-27` 记录） |
| `RoundDropdownMenu` | `RoundDropdownMenu.kt` | 用本地 `UiMenuPanel`（`components/UiMenu.ets`）承接，形态一致但动画不同 |
| `NavigationIconSlot` | `NavIconManageSheet.kt` 内部 | 内联在 `NavIconManageSheet.ets` 里，没单独抽 struct |
| `MediumFlexibleTopAppBar`（M3） | material3 库 | 用 `CollapsingSettingsHeader` 近似折叠行为；M3 的展开/收缩过渡曲线没有照搬 |
| `ReorderableSelectionItem` | `ui/widget/components/` | 用 `List` + `editMode(true)` + `onItemDragStart`/`onItemDrop` 承接（`MainNavigationSettingsSheet.ets:22-25`） |

**为什么没做完整比对**：上游 `ui/` 下 `@Composable` 函数有 **1,122 个**（`tmp/_up_comp.txt` 索引），其中大量是**页面内的局部 composable**（一个 screen 文件里几十个私有函数），并不是可复用组件。要判定「上游有这个组件、本地没有」，必须逐个读上游实现确认它是否被跨页复用——这是另一项独立工作的工作量，本轮没做。上表的 6 条都是**本地注释自己记录了「对齐上游 X，但用了 Y 近似」**，属于可靠来源。

**要重做这项比对**，可用的索引是 `tmp/_up_comp.txt`（1,122 行，格式 `文件:行号 Composable名`）对 `tmp/_cat_comp3.tsv`（70 行本地 struct）。但注意：**名字相同不等于等价**（`SearchBar` 同名但属性不同），名字不同也不等于缺失（`UiSection` 对 `SectionTitle.kt`）。

---

## 十三、已知坑（每条都踩过）

1. **`@BuilderParam` 不许直接传方法引用。** 必须 `() => { this.navigationSlot() }` 包裹。直接传 `this.navigationSlot` 会让 `this` 被重绑，点返回时抛 `undefined is not callable` 并**直接退出 app**。事故记录在 `components/CollapsingSettingsHeader.ets:9-13`。
2. **三个 `@Link visible` 组件必须绑父级 `@State`。** `SourceCheckSheet` / `SourceCheckRunSheet` / `SourceLoginSheet` 的 `visible` 是 `@Link` 不是 `@Prop`。父级要 `@State checkVisible: boolean = false` 再 `visible: $checkVisible`；传字面量 `visible: false` **不报错也不响应**，面板永远不出现。
3. **分组容器读 `themeGroupRadius`，不读 `themeCardRadius`**（见 10.4）。读错键「关闭设置分组圆角」开关就失灵，而且是静默的。
4. **`components/BookCard.ets:6` 是死代码**（外部调用 0）。书架的书卡内联在 `pages/BookshelfPage.ets:2640` 起。改书卡别改 `BookCard.ets`。
5. **`AppTopBar` 的 `collapsed`（布尔）与 `collapseFraction`（0–1 连续）是两套，不联动。** `collapseFraction` 默认 `-1` 表示「不用连续值」。只给 `collapsed` 时折叠是跳变；要跟手滚动必须同时喂 `collapseFraction`。
6. **`.fontSize(数字)` 还剩 47 处**（`components/BookKnowledgeSheet.ets` 42 / `components/theme/BackgroundImageManageSheet.ets` 3 / `pages/BookSourceDebugPage.ets` 1 / `components/theme/MainNavigationSettingsSheet.ets` 1）。全仓 `.fontSize(` 共 1,731 处，其余都走常量。新增代码不要再用数字。
7. **`ThemeColorItem` 只能在 `ThemeColorSelector` 内部用。** 它是后者的私有件（外部调用 0），别处直接用会漏掉选中态与深浅色切换的联动。
8. **`BookSourceStageRuntimeHost` 是全局唯一的 1×1 透明 Web**，挂在 `Index` 根 Stack 常驻。别在别处再挂第二个——两个实例会抢同一个书源运行上下文。
9. **`AppGlyph` 的 `tint` 是渲染期覆盖，不是改 svg。** 140 个 svg 全部写死 `fill`、`currentColor` 零命中，所以传 `$r('app.color.*')` 才能跟随深浅色；传硬编码 hex 会在夜间模式下不变色。
10. **同一文件多个 struct 不是冗余。** `SearchBookItems.ets`（3 个）、`ExploreKindItem.ets`（2 个）、`SourceLoginSheet.ets`（2 个）都是刻意合并的——它们共享同一段逻辑，拆开会各写一遍。改一个先确认另外几个没共用。

---

## 十四、来源与失效

### 14.1 快照时间与基线

- 快照时间：**2026-11-24**。文件行数、调用点、struct 计数全部以这一刻的 `entry/src/main/ets/` 为准。
- 本地基线：`legado-with-md3-harmonyos` 分支 `main`，HEAD 见 `git log -1 --format=%h`。文档写作时仓库工作区有并发会话改动，**不影响本文的只读测量**。
- 上游基线：`legado-with-MD3`，HEAD `bba5c64`（2026-10-26）。上游口径是 **core 基础包**，不含 comic 增强版。

### 14.2 数据怎么来的（可重跑）

下表脚本都在**工作区根** `<workspace>/tmp/` 下，不在本仓库内——它们是测量工具，不入库。

| 数据 | 脚本 | 输出 |
| --- | --- | --- |
| 70 个 struct 的定义行号 / 行数 / props / 调用点 | `<workspace>/tmp/_cat_scan.py` → `_cat_comp.py` → `_cat_call3.py` | `<workspace>/tmp/_cat_comp3.tsv`（9 列） |
| 令牌文件面与 pages 排行 | `<workspace>/tmp/_cat_misc.py` | 终端 |
| 上游映射（注释里的 `文件:行号`） | `<workspace>/tmp/_cat_ups.py` / `_cat_note.py` / `_cat_head2.py` | 终端 |
| 上游 @Composable 索引（1,122 条） | `<workspace>/tmp/_cat_match.py` 配套的 `<workspace>/tmp/_up_comp.txt` | 文本索引 |
| `.fontSize(数字)` 计数 | 一行 grep（见 0.2） | 终端 |

最快的一次全量复算，四条命令：

```bash
cd N:/HarmonyProjects/tmp && python _cat_scan.py && python _cat_comp.py && python _cat_call3.py
cd N:/HarmonyProjects/legado-with-md3-harmonyos && grep -rc '@Component' entry/src/main/ets/components/ | head
```

### 14.3 什么时候本文件会失效

以下任一发生，本文件的对应节就要重测，不能靠「差不多」推断：

- **新增或删除 `components/` 下的 struct** → 全文 70 这个数字、以及所属节的行数全部变。这是最常发生的，11-23 到 11-24 两天就新增了 10 个。
- **页面被拆分或合并** → 第十一节的行数表失效。`ProfileSubPages.ets` 与 `ReaderSettingsPage.ets` 这种「一堆 struct 塞一个文件」的最容易变。
- **`TypographyTokens` 或 `UiTokens` 增删常量** → 第十节的常量数（20 / 52 / 6）失效。
- **上游基线切换**（`bba5c64` 之后有新提交）→ 第十二节与分析全部要重核。

### 14.4 三条口径声明

1. **本文不判「该不该做」**。它只回答「本地有哪些组件、定义在哪、谁在用、对应上游哪个」。要不要补、先补哪个，是另一件事。
2. **上游映射标了来源级别**（正文表里每条都标）：`查证 2026-11-24` > `注释已注明·行级` > `注释已注明·文件级` > `索引匹配` > `未查到/本地自造`。**后三级没有读上游实现验证**，用之前先自己核一遍。
3. **「本地没有」不等于「平台做不到」**。第十二节全是「本地没写」，没有一条是平台限制。真要判平台无能力，必须指到 SDK 声明文件的具体行。

## 十五、上游映射查证记录（第一轮 33 条，2026-11-24 15:26）

33 条的明细在 `tmp/component-upstream-verify.md`（595 行）：定义行、签名原文、props 对照、结论，以及末节「推翻了哪些现标注」14 条。

- **覆盖范围：** 只覆盖原先标成「文件级 / 索引匹配 / 未查到 / 本地自造」的 33 条。原本就是「注释已注明·行级」的 30 条不在这次范围内，仍按注释照抄。
- **行号可信度：** 行号是读文件数出来的，不是推算。事后抽查 12 个点（`GlassTopAppBar.kt:28` / `:76`、`ExploreKindItem.kt:28` / `:52`、`TopBarButton.kt:214` / `:333`、`BookItem.kt:327` / `:674`、`CheckboxItem.kt:21`、`AppIconButton.kt:20`、`IconSwitch.kt:22`、`SectionTitle.kt:14`）全部命中。
- **props 对照是结构级的**，不是逐参数；要逐项对齐得另跑一遍，提示词在 `tmp/component-catalog-verify-prompt.md`。
- **检索命令与命中数**见 `tmp/component-upstream-verify.md` 的「本次真实执行过的检索（命中行数）」一节。

## 十五点一、第二轮查证记录（37 条新查 + 33 条复核，2026-11-24 16:08）

明细在 `tmp/component-catalog-verify2.md`（489 行）：五项共 109 条查证对象（37 + 33 + 33 + 6），另加 70 个调用点行号复验。

- **覆盖范围：** 第一轮漏的 37 条上游映射（表格「上游等价物」列现已全部带 `查证 2026-11-24·二轮`）、第一轮 33 条的定义行独立复核（33/33 行号对）、第十二节 6 条、70 个调用点。
- **本表由此改动：** 37 行「上游等价物」列换成查证结论，旧值保留在 `；原标注：` 后缀；6 个 `pages/SearchPage.ets` 调用点行号 +24。
- **未查到的 3 条：** `AppGlyph`（上游确实没有，图标是 `AppIcon.kt:29 fun AppIcon(` + `Icons.Default.*`）、`ReaderQuickMarkPanel`、`BookSourceStageRuntimeHost`（书源由 Rhino 在 JVM 内求值，不经 Web 控制器）。每条都带原样命令与输出。
- **检索命令：** 逐条在 `tmp/component-catalog-verify2.md` 各节 `N.3` 围栏里，可原样重跑。
- **没做的：** props 一对一对照没有写回本表；上游 1,122 个 `@Composable` 仍未逐个比对（第十二节只列 6 条）。
