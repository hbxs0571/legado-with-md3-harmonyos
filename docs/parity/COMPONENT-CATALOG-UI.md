# 本地前端组件清单（components/ + 设计令牌）

> 用途：写书架 / 详情页 / 设置页的代码之前，先在这里找一遍现成的组件，别重造。
> 后端（data / reader / bookSource / lib）见另一份 [本地后端清单](COMPONENT-CATALOG-DATA.md)。
> 基线：`<workspace>/legado-with-md3-harmonyos` 工作区。
> **来源与保鲜期**：2026-11-23 从本机临时清单转入仓库（原文件在工作区 `tmp/`，不入库）；行号是当日 02:26 的实测快照，会随并发会话改动漂移，用之前 `grep -n` 复核一次（第十三节写了同一件事）。

## 〇、三条读法与一处诚实声明

1. **「等价物」一列有两种来源，我已分别标注。**
   - **注释已注明** —— 组件自己的注释里就写了上游 `文件:行号`，这是最可靠的一类，可以照抄。
   - **索引匹配** —— 我在上游 1,123 个 `@Composable` 的全量索引里按名字匹配出来的，**没有**在代码注释里得到确认。用之前扫一眼上游那个函数，确认它是同一件事。
2. **`关键 props` 只列常用的，不是全部。** 完整签名看定义行往下 20 行，`@Prop` 都有默认值。
3. **`调用示例` 给的是文件:行号 + 起手式。** 多行调用的我给了起始行，整段自己去看——那才是能照抄的东西。

**诚实声明**：我没有逐个上机验证这些组件的渲染效果，也没有逐个读上游那个 Composable 的完整实现。等价物是按「代码注释 + 名字索引」得出的，标 `索引匹配` 的那些存在误判可能。

---

## 一、导航与顶栏

| 组件 | 定义 | 上游等价物 | 关键 props | 调用示例 |
| --- | --- | --- | --- | --- |
| `AppTopBar` | `components/TopBar.ets:63` | `GlassTopAppBar.kt:28`（**注释已注明**） | `title` / `subtitle` / `collapsed` / `collapseFraction` / `hasNavigation` / `navigationIcon`(Builder) / `actions`(Builder) | `pages/BookInfoEditPage.ets:421` |
| `TopBarButton` | `components/TopBar.ets:313` | `TopBarButton.kt:214`（索引匹配） | `icon` / `tint` / `disabled` / `showDivider` / `menuMode` / `accessibilityLabel` / `onSelect` | `TopBarButton({ icon: 'profileSave', showDivider: false, onSelect: () => { this.submit(); } })` |
| `TopBarBackButton` | `components/TopBar.ets:430` | `TopBarNavigationButton @TopBarButton.kt:304`（索引匹配） | `onSelect` | `pages/BookInfoEditPage.ets:408` |
| `CollapsingSettingsHeader` | `components/CollapsingSettingsHeader.ets:16` | `GlassMediumFlexibleTopAppBar.kt:43`（注释已注明，无行号） | `title` / `collapsed` / `onBack` | `pages/AppAiSettingsPage.ets:29` |

`AppTopBar` 还导出 8 个度量常量：`TOP_BAR_COLLAPSED_HEIGHT:12` / `TOP_BAR_EXPANDED_HEIGHT:14` / `TOP_BAR_EXPANDED_HEIGHT_SUBTITLE:16` / `TOP_BAR_TITLE_EXPANDED_SIZE:18` / `TOP_BAR_TITLE_COLLAPSED_SIZE:20` / `TOP_BAR_SUBTITLE_SIZE:22` / `TOP_BAR_SIDE_PADDING:24` / `TOP_BAR_TITLE_START:26`。

**设置子页别自己写顶栏。** `CollapsingSettingsHeader` 就是给它们的（16 个设置子页在用），它只做形态适配，结构交给 `AppTopBar`。

---

## 二、卡片与封面

| 组件 | 定义 | 上游等价物 | 关键 props | 调用示例 |
| --- | --- | --- | --- | --- |
| `BookCover` | `components/BookCover.ets:15` | `CoilBookCover.kt:275`（**注释已注明**，另引 `BookItem.kt:269-273` / `CoverSettings.kt:6-10` / `BookshelfCover.kt:104-121`） | `compact` / `mini` / `displayWidth` / `displayHeight` / `cornerRadius` / `showChapterBadge` / `badgeText` / `leftBottomText` / `locked` / `shadowEnabled` / `fillWidth` / `isNight` / `applyAspectRatio` / `a11yText` / `sharedKey` | `pages/BookInfoEditPage.ets:435` |
| `BookGroupCard` | `components/BookGroupCard.ets:17` | `BookGroupCover @BookItem.kt:327`（注释已注明 `BookItem.kt:269-276`） | `groupName` / `books` / `coverCount` / `listStyle` / `coverSettings` / `isNight` / `listCoverWidth` / `showCount` / `coverShadow` / `locked` / `onOpen` / `onLongPress` | `pages/BookshelfPage.ets:2677` |
| `PullRefreshIndicator` | `components/PullRefreshIndicator.ets:42` | `AppPullToRefresh.kt:34`（**注释已注明** `:104-110`） | 无 props，纯指示器 | `pages/BookshelfPage.ets:504` |
| `ReadRecordHeatmap` | `components/ReadRecordHeatmap.ets:11` | `HeatmapCard @ReadRecordOverviewScreen.kt:285`（索引匹配） | `dailyReadCounts` / `dailyReadTimes` / `selectedDate` / `mode` / `onDateSelected` | `pages/ReadRecordOverviewPage.ets:495` |
| `RelatedBooksBanner` | `components/RelatedBooksBanner.ets:33` | `RelatedBooksBanner @BookInfoScreen.kt:2125`（**注释已注明** `:2125-2171`） | `title` / `books` / `showMore` / `coverSettings` / `isNight` / `onSelectBook` / `onMore` | `pages/BookInfoPage.ets:225` |

**`components/BookCard.ets:6` 是死代码**：54 行，全仓零 `import`（`grep -rn "BookCard'" entry/src/main/ets` 无输出）。书架的书卡是**内联**画在 `pages/BookshelfPage.ets:2640`–`:2720` 的。抽组件时不要参考它，也不要「顺手修好它」。

---

## 三、菜单与面板

| 组件 | 定义 | 上游等价物 | 关键 props | 调用示例 |
| --- | --- | --- | --- | --- |
| `UiMenuPanel` | `components/UiMenu.ets:67` | `RoundDropdownMenu.kt:52`（**注释已注明** `:57`；另引 `PillDivider.kt:23`） | `items: UiMenuItem[]`（接口 `@UiMenu.ets:9`）/ `panelWidth` / `onSelect(key)` | `pages/BookInfoEditPage.ets:181` |
| `UiMenuItem` | `components/UiMenu.ets:9` | `RoundDropdownMenuItem.kt:44`（索引匹配） | 见接口定义 | — |
| `ReaderSheetShell` | `components/ReaderSheetShell.ets:18` | `AppModalBottomSheet.kt:48`（索引匹配） | `scrimColor` / `panelColor` / `panelWidth` / `panelHeight` / `showHandle` / `contentPadding` / `blurRadius` / `onDismiss` / `content`(Builder) | `pages/ReadAloudConfigPanel.ets:118` |
| `ThemeGroupColumn` | `components/settings/ThemeGroupColumn.ets:30` | `SplicedColumnGroup.kt:42`（**注释已注明** `:42-138`） | `title` / `content`(Builder) | `pages/ThemeSettingsPage.ets:680` |
| `ThemeGroupItem` | `components/settings/ThemeGroupColumn.ets:97` | `SplicedColumnGroup.kt:42` 内部项 | `first` / `content`(Builder) | `pages/ThemeSettingsPage.ets:681` |
| `ProgressiveBackdrop` | `components/ProgressiveBackdrop.ets:15` | `HazeStyle.kt`（**注释已注明** `:47-61`） | `blurRadius` / `bands` | `pages/BookInfoPage.ets:1543` |
| `CoverBlurBackdrop` | `components/CoverBlurBackdrop.ets:17` | `CoverBlurBackdrop.kt:17`（**注释已注明** `:25`；另引 `PlayerBackground.kt:34`） | `coverUri` / `seedColor` / `blurRadius`(48) / `coverScale`(1.2) | `pages/ReadAloudPlayerPage.ets:178` |

---

## 四、设置行控件（最常用的一族，写设置页基本只用这些）

`components/settings/` 下 9 个组件，**同一个视觉骨架（`ROW_PADDING_H=16` / `ROW_PADDING_V=14` / 可选分隔线），右侧控件不同**。选型只看右侧那一块是什么。

| 组件 | 定义 | 上游等价物 | 关键 props | 右侧是什么 | 调用示例 |
| --- | --- | --- | --- | --- | --- |
| `UiAction` | `components/settings/UiAction.ets:17` | `ClickableSettingItem.kt:17`（索引匹配） | `title` / `detail` / `option` / `swatchColor` / `swatchDisabled` / `chevronSize`(15) / `showDivider` / `detailMaxLines` / `onSelect` | 可选色块 + 可选值文本 + 尖括号 | `pages/AppAiSettingsPage.ets:34` |
| `UiSwitch` | `components/settings/UiSwitch.ets:20` | `SwitchSettingItem.kt:20`（索引匹配） | `title` / `detail` / `value` / `disabled` / `showDivider` / `onChange(enabled)` | 开关 | `pages/AppCoverSettingsPage.ets:338` |
| `UiSlider` | `components/settings/UiSlider.ets:8` | `SliderSettingItem.kt:48`（索引匹配） | `title` / `detail` / `value` / `minValue` / `maxValue` / `stepValue` / `showDivider` / `onChange(value)` | 滑杆 | `pages/AppDownloadCacheSettingsPage.ets:160` |
| `UiDropdown` | `components/settings/UiDropdown.ets:19` | `DropdownListSettingItem @ListSettingItem.kt:19`（索引匹配） | `title` / `detail` / `option` / `options: string[]` / `showDivider` / `labelOf(value)` / `onSelect(value)` | 弹出选项列表 | `pages/OtherSettingsPage.ets:170` |
| `UiChoice` | `components/settings/UiChoice.ets:12` | `DropdownListSettingItem @ListSettingItem.kt:19` 的简化形态（**注释已注明**） | `title` / `detail` / `options: string[]` / `selectedIndex` / `showDivider` / `onSelect(index)` | 点一下就在几项间循环 | `pages/AppCoverSettingsPage.ets:373` |
| `UiInput` | `components/settings/UiInput.ets:17` | `InputSettingItem.kt:30`（索引匹配） | `title` / `detail` / `value` / `defaultValue` / `showDivider` / `onConfirm(text)` | 可编辑文本框 | `pages/AppDownloadCacheSettingsPage.ets:172` |
| `UiColorModeRow` | `components/settings/UiColorModeRow.ets:12` | `TinyColorModeSettingItem @TinySettingItems.kt:476`（索引匹配） | `title` / `dayColor` / `nightColor` / `dayLabel`(日间) / `nightLabel`(夜间) / `colors` / `showFollow` / `onDayChange(color)` / `onNightChange(color)` | 日/夜两个色块 | `pages/ReaderSettingsPage.ets:733` |
| `UiColorSheet` | `components/settings/UiColorSheet.ets:19` | `ColorPickerSheet.kt:51`（索引匹配） | `title`(选择颜色) / `initialColor` / `resetColor` / `onCancel` / `onConfirm(color)` | —（本组件就是取色面板本身） | `pages/AppCoverSettingsPage.ets:451` |
| `UiSection` | `components/settings/UiSection.ets:12` | `SectionTitle.kt:14`（索引匹配） | `title` / `content`(Builder) | —（分组标题容器） | `UiSection({ title: '供应商' }) { ... }` |

**`UiAction` 与 `UiChoice` 的区别是能力，不是外观**：`UiChoice` 只报「切到了第几个」，值存不存、存哪都由父级决定（注释原文：「值与回调都在父级：本组件只报『切到了第几个』，不自己存 selectedIndex」）。要展示一串选项让用户挑，用 `UiDropdown`；只是几档循环切换，用 `UiChoice`。

**`pressedBackground()` 是这一族的共同约定**（`UiAction.ets:48-54`，`UiChoice.ets:30` 也有）：把主题强调色 `#RRGGBB` 前面补 `#26` 成 15% alpha 的 `#AARRGGBB`，主题色不是 7 位 hex 时退回 `themeColorSurfaceTertiary`。新写设置行时照抄这段，不要自造按压色。

**分隔线默认画**（`showDivider` 默认 `true`）。一组里最后一行传 `showDivider: false`，或者在分组容器里用 `ThemeGroupItem` 的 `first` 控制。

---

## 五、主题选择与分组

| 组件 | 定义 | 上游等价物 | 关键 props | 调用示例 |
| --- | --- | --- | --- | --- |
| `ThemeModeSelector` | `components/ThemeSelectors.ets:28` | `ThemeModeSelector @ThemeConfigScreen.kt:1004`（**注释已注明**，文件头 `ThemeSelectors.ets:8` 引 `:1004-1040`） | `selectedMode` / `onModeSelected(mode)` | `pages/OnboardingPage.ets:118` |
| `ThemeColorSelector` | `components/ThemeSelectors.ets:95` | `ThemeColorSelector @ThemeConfigScreen.kt:1043`（索引匹配） | `selectedIndex` / `isDark` / `onPaletteSelected(index)` | `pages/OnboardingPage.ets:130` |
| `ThemeItemDivider` | `components/ThemeItemDivider.ets:15` | `SettingItemDivider.kt:19`（**注释已注明** `:16-45`） | 无 | `ThemeItemDivider()` |
| `ThemeGroupColumn` | `components/settings/ThemeGroupColumn.ets:30` | `SplicedColumnGroup.kt:42`（**注释已注明** `:42-138`） | `title` / `content`(Builder) | `pages/ThemeSettingsPage.ets:680` |
| `ThemeGroupItem` | `components/settings/ThemeGroupColumn.ets:97` | `SplicedColumnGroup.kt:42` 内部项 | `first` / `content`(Builder) | `pages/ThemeSettingsPage.ets:681` |

**新设置页首选 `ThemeGroupColumn` + `ThemeGroupItem` + `Ui*` 这一套。** 任务书 `appearance-impl-prompt.md` 批 1 说的就是「外观页改用统一分组容器」，`ThemeSettingsPage` 已经改过一轮了（提交 `811223f`）。

**一个容易踩的坑**：分组卡片的圆角必须读 `themeGroupRadius`，**不是** `themeCardRadius`。`ThemeGroupColumn.ets:9-12` 的注释写明了原因——只有 `themeGroupRadius` 响应「关闭设置分组圆角」那个开关，读错键会让开关管不到分组。三来源优先级（上游 `SplicedColumnGroup.kt:50-54`）：`disableSplicedColumnGroupCornerRadius` → 0、`overrideBaseCardCornerRadius` → `baseCardCornerRadius`、否则 16。本地已由 `data/ThemeCardStyle.ets:136` 的 `resolveGroupCornerRadius()` 算好并广播。

---

## 六、图标与文本渲染

| 组件 | 定义 | 上游等价物 | 关键 props | 调用示例 |
| --- | --- | --- | --- | --- |
| `AppGlyph` | `components/AppGlyph.ets:4` | 上游无单一组件——等价物是 `Icons.Default.*` 扩展 + `Icon(imageVector = ...)`。`AppGlyphName`（84 个成员）与上游图形名的对应关系见 `tmp/icon-impl-prompt.md` | `name: AppGlyphName`(默认 `'home'`) / `glyphSize`(22) / `tint: ResourceColor`(`'#C5C7D0'`) | `AppGlyph({ name: this.passwordVisible ? 'visibility' : 'visibilityOff', glyphSize: 20, ... })` |
| `MarkdownIntro` | `components/MarkdownIntro.ets:140` | `MarkdownBlock.kt:116`（**注释已注明** `:119`） | `source` / `textColor` / `bodySize`(=`TITLE_SMALL` 14) / `bodyLineHeight`(=`TITLE_SMALL_LINE_HEIGHT` 20) | `pages/BookSourceDebugPage.ets:582` |
| `RichIntro` | `components/RichIntro.ets:96` | `BookInfoIntro @BookInfoScreen.kt:1635`（**注释已注明** `:1710`；另引 `HtmlContent.kt:377-395`） | `intro` / `baseUrl` / `textColor` / `webNotice` | `pages/BookInfoPage.ets:1477` |
| `ReadAloudGlassWidgets` | `components/ReadAloudGlassWidgets.ets:36` | **未查到**（上游朗读配置里的步进器我没在 Composable 索引里匹配到确定项） | `AloudStepper`：`valueText` / `stepperEnabled` / `onDec` / `onInc` | 见 `ReadAloudConfigPanel` |

**`AppGlyph` 的着色与尺寸别自己改**：140 个 svg 全部写死 `fill`，`currentColor` 零命中，所以 `tint` 走的是渲染期覆盖，不是改 svg。尺寸三族网格是 24:88 / 960:46 / 特殊 6。

**`RichIntro` 与 `MarkdownIntro` 不是一个东西**：前者渲染书籍简介（可能含 HTML），后者渲染 Markdown（书源调试页在用）。选哪个看数据源是什么格式，不要「都行」。

---

## 七、阅读与知识

| 组件 | 定义 | 上游等价物 | 关键 props | 调用示例 |
| --- | --- | --- | --- | --- |
| `ReaderQuickMarkPanel` | `components/ReaderQuickMarkPanel.ets:25` | `MarkingSelectionMenu @MarkingSelectionMenu.kt:89`（索引匹配；同族 `MarkingColorRow:388` / `MarkingEffectTile:474` / `MarkingRuleTile:550`） | `quickStyle: ReaderMarkingEffect` / `quickNote` / `existingMarking` / `onStyleChange` / `onNoteChange` / `onApply` / `onDelete` / `onClose` | `pages/ReaderPage.ets:8491` |
| `BookKnowledgeSheet` | `components/BookKnowledgeSheet.ets:21` | `BookInfoKnowledge @BookInfoScreen.kt:2325`（索引匹配；同族 `KnowledgeInfoCard:2374` / `BookKnowledgeEditCard @BookInfoEditScreen.kt:297` / `BookKnowledgeDetailScreen.kt:61`） | `bookUrl` / `initialTab` / `onClose` | `pages/BookInfoEditPage.ets:579` |
| `ReaderSheetShell` | `components/ReaderSheetShell.ets:18` | `AppModalBottomSheet.kt:48`（索引匹配） | 见第三节 | `pages/ReadAloudConfigPanel.ets:118` |
| `BookSourceStageRuntimeHost` | `components/BookSourceStageRuntimeHost.ets:9` | **无上游等价物**（这是本地给书源脚本引擎的挂载宿主，上游没有对应物） | 无对外 props | 见 `BookSourceDebugPage` |

**`BookKnowledgeSheet` 的数据层是齐的**：`data/BookKnowledgeRepository.ets:178` 的类 + 5 个接口（`CharacterProfile:50` 角色卡 / `CharacterEvent:70` 事件 / `CharacterRelation:88` 关系网 / `KnowledgeEntry:106` 知识卡 / `OutlineNode:124` 大纲），另有 4 个 `New*` 写入接口（`:142`/`:152`/`:160`/`:169`）。做详情页知识功能时先读这个文件，别另起表。

---

## 八、设置面板与书源专用

| 组件 | 定义 | 上游等价物 | 关键 props | 调用示例 |
| --- | --- | --- | --- | --- |
| `AppFontSheet` | `components/settings/AppFontSheet.ets:34` | `FontSelectSheet.kt:49`（**注释已注明** `:95-146`；另引 `FontSelectGrid.kt:70`） | `selectedPath` / `folderPath` / `onSelectFont(path)` / `onClearFont` / `onFolderChange(path)` | `pages/ThemeSettingsPage.ets:571` |
| `NavIconManageSheet` | `components/settings/NavIconManageSheet.ets:36` | `NavIconManageSheet.kt:48`（索引匹配；注释引上游 `ThemeConfigRouteScreen.kt:59-86`） | `slotPaths` / `onSelectIcon(slot, path)` / `onClearIcon(slot)` | `pages/ThemeSettingsPage.ets:585` |
| `TopBottomBarSettingsSheet` | `components/settings/TopBottomBarSettingsSheet.ets:46` | `TopBottomBarSettingsSheet.kt:25`（**注释已注明** `:49-174`） | 14 个值与 13 个 `on*Change` 回调，见定义 | `pages/ThemeSettingsPage.ets:591` |
| `LauncherIconPickerSheet` | `components/settings/LauncherIconPickerSheet.ets:31` | `LauncherIconPickerSheet.kt:49`（索引匹配） | `selectedId` / `onDismiss` / `onIconChanged(iconId)` | `pages/ThemeSettingsPage.ets:621` |
| `AppFab` | `components/booksource/AppFab.ets:15` | `AppFloatingActionButton.kt:60`（**注释已注明** `:60-68`） | `icon: AppGlyphName`(默认 `'profileSave'`) / `fabAccessibilityText` / `onFabClick` | `pages/BookSourceDebugPage.ets:531` |
| `SourceCheckSheet` | `components/booksource/SourceCheckSheet.ets:17` | `CheckSourceBottomSheet.kt:22`（**注释已注明** `:67-101`；另引 `BookSourceContract.kt:33-40`） | **`@Link visible: boolean`** / `onConfirm(options: SourceCheckOptions)` | `pages/ProfileSubPages.ets:1893` |
| `SourceCheckRunSheet` | `components/booksource/SourceCheckRunSheet.ets:21` | `CheckSourceBottomSheet.kt:22`（**注释已注明** `BookSourceScreen.kt:780-819`） | **`@Link visible: boolean`** / `sourceCount` / `onOpenSettings` / `onConfirm(keyword)` | `pages/ProfileSubPages.ets:1902` |
| `SourceLoginSheet` | `components/booksource/SourceLoginSheet.ets:163` | `SourceLoginSheets.kt:60`（**注释已注明** `:59-106`；另引 `SourceLoginContract.kt:23-28` / `SourceLoginViewModel.kt:238-244`） | **`@Link visible: boolean`** / `onClose` / `onOpenWeb(url)` / `onUnavailableAction(message)` | `pages/Index.ets:13427` |

**三个 `@Link visible` 组件必须被父级的 `@State` 绑定**，不是传值。父级写法：`@State checkVisible: boolean = false` → `SourceCheckSheet({ visible: $checkVisible, ... })`。传字面量 `visible: false` 不会响应。

---

## 九、设计令牌（数字的唯一出处）

### 9.1 `components/UiTokens.ets`（间距、圆角、时长、折叠阈值）

| 常量 | 值 | 用途 |
| --- | --- | --- |
| `SPACE_2` / `SPACE_4` / `SPACE_8` / `SPACE_12` / `SPACE_16` / `SPACE_20` / `SPACE_24` | 2 / 4 / 8 / 12 / 16 / 20 / 24 | 通用间距 |
| `ROW_PADDING_H` | 16 | 设置行左右内边距 |
| `ROW_PADDING_V` | 14 | 设置行上下内边距 |
| `SECTION_TITLE_TOP` / `SECTION_TITLE_BOTTOM` | 14 / 8 | 分组标题上下留白 |
| `SECTION_GAP` | 8 | 分组间距 |
| `EXPAND_PADDING_BOTTOM` / `EXPAND_BUTTONS_TOP` / `EXPAND_BUTTONS_BOTTOM` | 12 / 12 / 8 | 展开区留白 |
| `RADIUS_INNER` | 8 | 行内元素圆角 |
| `DURATION_FADE` | 220 | 淡入淡出时长（全仓 33 处在用） |
| `DURATION_PAGE_SWITCH` | 300 | 页面切换时长 |
| `HEADER_COLLAPSE_THRESHOLD` | 70 | 顶栏收起阈值（19 处页面在用） |
| `HEADER_EXPAND_THRESHOLD` | 24 | 顶栏展开阈值 |

**折叠顶栏不要再手写字面量。** 以前 19 个文件各写一份 `const shouldCollapse = offset > 70 ? true : offset < 24 ? false : this.collapsedHeader;`，现在收拢成上面两个常量（提交 `316bed5`，`offset > 70` 全仓已归零）。

### 9.2 `components/typography/TypographyTokens.ets`（52 个 `export const`）

10 个字号槽位 × 4 个变体（正体 / Emphasized）+ 每个都有对应行高常量：

| 槽位 | 字号 | 行高 | 上游对应 |
| --- | --- | --- | --- |
| `HEADLINE_LARGE` | 32 | 40 | M3 displaySmall 派生 |
| `HEADLINE_MEDIUM` | 24 | 30.86 | M3 headlineMedium |
| `HEADLINE_SMALL` | 20 | 26.67 | M3 headlineSmall |
| `TITLE_LARGE` | 18 | 22.91 | M3 titleLarge |
| `TITLE_MEDIUM` | 16 | 24 | M3 titleMedium |
| `TITLE_SMALL` | 14 | 20 | M3 titleSmall |
| `BODY_LARGE` | 17 | 25.5 | M3 bodyLarge |
| `BODY_MEDIUM` | 16 | 22.86 | M3 bodyMedium |
| `BODY_SMALL` | 12 | 16 | M3 bodySmall |
| `LABEL_LARGE` | 14 | 18.67 | M3 labelLarge |
| `LABEL_MEDIUM` | 13 | 17.33 | M3 labelMedium |
| `LABEL_SMALL` | 11 | 16 | M3 labelSmall |

另有 4 个 M3 原生 TypeScale 常量（`TYPE_SCALE_HEADLINE_MEDIUM:126`=28 / `TYPE_SCALE_TITLE_LARGE:127`=22 / `TYPE_SCALE_LABEL_LARGE:128`=14 / `TYPE_SCALE_BODY_LARGE:130`=16）。**这 4 个与 24 槽位并存，不要合并**——依据是上游同时挂了两套（`ThemeComponents.kt:135-144` miuix 一套、`:257-286` `Typography()` 另一套）。

**写法规矩**：`.fontSize()` 与 `.lineHeight()` 只许填常量名，不许填数字。这条现在是**达标状态**——`entry/src/main/ets` 内 `.fontSize(数字)` 实测 0 处（唯一残留是 `entry/src/ohosTest/ets/testability/pages/Index.ets:7` 的测试脚手架）。新写代码别破这个。

**Emphasized 与正体的选择**：`*_EMPHASIZED` 在上游不是「更粗」而是「另一个槽位」。`titleSmall`(14/Bold) 比 `titleSmallEmphasized`(14/Medium) **更重**，别默认加 Emphasized 就是加粗。

---

## 十、页面在哪（改一个功能，先找它在哪个页面）

组件是零件，页面是装配。下面六个大页面占了 `pages/` 近八成效能，改功能前先确认落在哪个文件。

| 页面 | 行数 | `@Component` 数 | 里面是什么 |
| --- | --- | --- | --- |
| `pages/Index.ets` | 13,522 | — | 路由总入口 + 全局状态 + 几乎所有跨页回调的汇聚地。**这个文件常年被并发会话改，行号最不可靠** |
| `pages/ReaderPage.ets` | 9,877 | — | 阅读器本体（正文渲染、划词、菜单、翻页）。渲染侧细节在 `reader/` |
| `pages/ProfileSubPages.ets` | 7,929 | 32 | 「我的」下所有子页：书源管理、阅读记录、设置子页、关于等。**一个文件里 32 个 `@Component`** |
| `pages/ReaderSettingsPage.ets` | 4,606 | — | 阅读设置（含色板、字体、行距等） |
| `pages/BookshelfPage.ets` | 3,072 | 2 | 书架：网格/列表/分组/选择态/配置面板全在这一个文件里，书卡内联在 `:2640`–`:2720` |
| `pages/BookInfoPage.ets` | 1,764 | 4 | 书籍详情页 |

次级页面：`pages/BookshelfManagePage.ets`(1,037) 书架管理 · `pages/BookInfoEditPage.ets`(589) 详情编辑 · `pages/HomePage.ets`(512) 首页 · `pages/BookSourceEditPage.ets`(456) 书源编辑 · `pages/BookSourceDebugPage.ets`(265) 书源调试 · `pages/SourceLoginPage.ets`(189) 书源登录 · `pages/SourceWebPage.ets`(74) 网页壳。

**别被「一个文件几千行」吓住**：`ProfileSubPages.ets` 的 32 个 `@Component` 是彼此独立的，改其中一个不用读懂整份。找个 `grep -n 'struct '` 先看边界。

---

## 十一、上游有、本地组件层确实没有的（这一轮实测确认的）

| 上游 | 本地 | 依据 |
| --- | --- | --- |
| AI 自动分组整套：`autoGroup/AiAutoGroupSheet.kt:734` + `AiAutoGroupViewModel.kt:500` + `AiAutoGroupContract.kt:119` = 1,353 行 | **一套都没有**。`AutoGroup` 全仓 0 命中 | `grep -rn 'AutoGroup' entry/src/main/ets` 无输出 |
| 完整标注表 `MarkingSheet.kt:72` | 只有阅读页的快捷标注面板 `ReaderQuickMarkPanel`，没有独立整表 | 本轮组件清单里无对应项 |
| `CheckSourceBottomSheet.kt:22` 的完整流程 | 有 `SourceCheckSheet` + `SourceCheckRunSheet` 两个面板，但 `CheckSource` / `sourceCheck` 标识符全仓 0——**名字不同不等于没有**，判定前要读这两个文件 | 同上 |

**这一节最容易看错**：0 命中不等于没有，已经被 `saveBookOrder` 证伪过一次。上面三行里只有第一行是我确认「真没有」的（`AutoGroup` 是整套专有名词，改名余地小）；第二、三行是「组件清单里没有对应项」，不等于功能缺失。

---

## 十二、五条已知坑（照抄会踩）

1. **`components/BookCard.ets:6` 是死代码。** 54 行，全仓零 `import`。看到它别当成「现成的书卡组件」去用——书架的书卡内联在 `pages/BookshelfPage.ets:2640`–`:2720`。
2. **`@BuilderParam` 不许直接传方法引用。** `CollapsingSettingsHeader.ets:9-13` 的注释记录了事故：直接传 `this.navigationSlot` 时 ArkUI 会把 builder 的 `this` 重绑到接收组件，`navigationSlot` 里的 `this.onBack` 变成 `undefined`——编译与渲染都正常，**点返回按钮才抛 `undefined is not callable` 并把 app 退掉**。必须用箭头函数包装：`navigationIcon: () => { this.navigationSlot() }`。
3. **分组圆角读 `themeGroupRadius`，不是 `themeCardRadius`。** 读错键的表现是「关闭设置分组圆角」开关点了没反应。原因见 `ThemeGroupColumn.ets:9-12`。
4. **三个 `@Link visible` 组件必须绑父级 `@State`。** `SourceCheckSheet` / `SourceCheckRunSheet` / `SourceLoginSheet` 的第一参数是 `@Link`，传字面量不会响应，也不会报错——只是面板永远不出现。
5. **`AppTopBar` 的 `collapsed` 与 `collapseFraction` 是两套**：`collapsed` 是布尔（收起/展开两态），`collapseFraction` 是 0–1 的连续值（用于随滚动渐变）。默认 `collapseFraction: -1` 表示「不用连续值」。两者同时给时行为以组件实现为准，不确定就只用 `collapsed`。

---

## 十三、这份清单怎么来的、什么时候会失效

- **生成方式**：三个一次性脚本，都在 `<workspace>/tmp/`（工作区临时区，不入库）：`_cmp_props.py`（提取 `struct` + `@Prop`/`@Link`/`@BuilderParam`/回调签名）、`_cmp_call.py`（取每个组件的第一个调用点与那一行代码）、`_cmp_up.py`（扫组件注释里的 `上游 …kt:行号` 映射）。上游 Composable 索引是 `_up_scan.py` 生成的 `_up_comp.txt`（1,123 个 `@Composable` / 1,106 个唯一名）。
- **会失效的部分**：行号。`pages/Index.ets`、`pages/ProfileSubPages.ets`、`pages/BookshelfPage.ets` 这几个大文件常年被并发会话改，行号随时漂。用之前 `grep -n` 复核一次，别把这张表当成编译器的保证。
- **不会失效的部分**：组件名、props 名、等价物的上游文件名。这些改名代价高，短期稳定。

**未做的事（说清楚，免得被当成已验证）**：

- 我没有逐个上机渲染这些组件，视觉效果没有截图证据。
- 标 `索引匹配` 的等价物（约 20 条）没有读上游那个 Composable 的实现，只按名字匹配。误判可能存在。
- 本文没有列出 `pages/` 下的页面级组件（`BookInfoPage` 4 个 `@Component`、`ProfileSubPages` 32 个、`BookshelfPage` 2 个等）。它们是页面私有的，复用价值低；要列另开一份。
