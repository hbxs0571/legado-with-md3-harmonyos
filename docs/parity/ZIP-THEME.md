# 深色模式对照表

本表按 [模块对照要求](../CODE-CONVENTIONS.md) 第四节点完一次，行粒度是**一个界面**——不是「一个备份键」，也不是「一个按钮」。`themeMode`（上游中文名「深色模式」）与 `themeConfig`（主题配置）两类共用「主题设置页」这一个界面，所以合成一张表盘：拆开盘会把同一个页面的四十多个条目写两遍。

状态只允许三个值：**已接** / **未接** / **不适用**。`不适用` 必须写理由。

> **r298 结构性重盘（2026-10-31）**：`themeMode` 与 `themeConfig` 此前在 [STATUS](STATUS.md) 里分别是「零行」与「[阅读配置总账](READER-CONFIG.md) F 块 7 行护眼字段」，都没有界面级盘点。本轮首次把两者合成一张表，并**先修关键词**（见[对照关键词](KEYWORDS.md)：`themeMode` 32→80、`themeConfig` 3→132）——不修的话接触面只有 32/3 个文件，阅读页日夜换肤的那批核心文件一个都进不来，后面全是假通过。

- 盘点日期：2026-10-31
- 上游基线：`legado-with-MD3`（Android，Compose；`<上游根>` 指法见[对照关键词](KEYWORDS.md)的用法节）。主要文件：`ui/config/themeConfig/ThemeConfigScreen.kt` 1362 行、`help/config/ThemePackageManager.kt` 1254 行、`ui/config/themeManage/EditThemeSheet.kt` 403 行
- 本地实现：`entry/src/main/ets/pages/ThemeSettingsPage.ets`（333 行）、`pages/ReaderSettingsPage.ets`、`pages/ReaderPage.ets`、`pages/OnboardingPage.ets`、`data/BackupRepository.ets`
- 对应 ZIP 类别：`themeMode`、`themeConfig`

## 先读这一段：本地缺的不是「键没接」，是整套浅色主题不存在

只看备份侧很容易以为「补个键就完事」：本地确实有 `themeMode` 键组、`themeConfig` 53 键组，键名与上游 `themePrefKeys` 逐个比对完全一致（双向差集皆空）。但界面侧是另一回事，四条实测：

1. **没有浅色主题**。`entry/src/main/ets` 内 `darkMode|isDark|DarkTheme` 零命中；颜色字面量 `'#RRGGBB'` 共 **2252** 处，Top 全是深色系——`#D8D9E0` 242、`#AFC2FF` 180、`#92949E` 177、`#E3E4E8` 169、`#1C1D23` 80、`#111217` 80、`#1A1B21` 61；浅色只有 `#FFFFFF` 9、`#F0F1F5` 6、`#F1F2F6` 5。
2. **没有第二套资源**。`entry/src/main/resources/` 下只有 `base/` 与 `rawfile/`，**没有 `dark/` 目录**；`base/element/color.json` 只定义 1 个颜色（`start_window_background = #F6F4F0`），全仓 `$r('app.color.*')` 引用 **0 处**——连「颜色走资源引用、切目录即换肤」这条路都没铺。
3. **主题设置页零持久化**。`pages/ThemeSettingsPage.ets` 内 `preferences|getPreferences|store.put|Repository` 命中 **0**；47 处 widget 调用、46 个可见条目里，**39 处**走 `onUnavailableAction('…尚未迁移')`，其余 7 处（三个模式项、五个调色板）只改 `@State`，退出即丢。页面入口 `pages/Index.ets:4135` 是 `ThemeSettingsPage({ onBack, onUnavailableAction })`——**没传任何主题状态**。
4. **唯一落盘的 themeMode 没人读**。`data/OnboardingRepository.ets` 把 `{ completed, themeMode, paletteIndex }` 写进 preferences（`legado_first_run`），但 `pages/Index.ets:1653-1657` 的 `restoreOnboarding` 只读 `state.completed`，`themeMode` 读出来就丢。

结论：**在本地，「深色模式」不是「一个没接的键」，而是一整层没建的地基**。只补 `themeMode` 的读写分支，结果只是备份文件里多一个键，界面上不会有任何变化——真正的成本在 A 块与 F 块：建浅色资源、把 2252 处字面量改成引用、让设置页落盘、再让全局跟随。下面 91 行里 83 行 `未接`，原因基本都收束到这一条。

## ZIP 类别归属（整表口径）

| 块 | 条数 | ZIP 类别 | 依据 |
| --- | --- | --- | --- |
| A 主题设置页 | 47 | `themeConfig`（A1/A2/A4 另涉 `themeMode`） | 页面主体是 53 个 themeConfig 键的设置项；深色模式三选一是 `themeMode` 的唯一设置界面 |
| B 主题包管理 | 12 | `themeConfig` | 主题包就是 themeConfig 的序列化集合（`themeConfig.json`），管理页读写它 |
| C 首次启动向导 | 5 | `themeMode` | 向导第 4 页直接写 `themeMode` 与调色板 |
| D 阅读页日夜快捷按钮 | 8 | `themeMode`（D5 另涉 `themeConfig` 的三套背景） | 按钮的唯一效果是改 `themeMode` 网关 |
| E 日夜提醒 | 7 | `themeConfig`（`autoSuggestDayNight` 是 53 键之一），触发后写 `themeMode` | 开关落在 themeConfig，效果落在 themeMode |
| F 网关与全局换肤 | 12 | 两者 | `themeMode` 的存储/派生/应用 + `themeConfig` 的导出与忽略门控 |

合计 **91 行**：已接 5 / 未接 83 / 不适用 3。按 ZIP 类别列归属，`themeConfig` 72 行、`themeMode` 19 行。`themeMode` 与 `themeConfig` 交叉出现在 A1–A4、D5、E、F，按类别派活时两张都要看。

## 盘面

| 块 | 条数 | 已接 | 未接 | 不适用 |
| --- | --- | --- | --- | --- |
| A 主题设置页 | 47 | 0 | 47 | 0 |
| B 主题包管理 | 12 | 0 | 12 | 0 |
| C 首次启动向导 | 5 | 1 | 3 | 1 |
| D 阅读页日夜快捷按钮 | 8 | 2 | 5 | 1 |
| E 日夜提醒 | 7 | 0 | 7 | 0 |
| F 网关与全局换肤 | 12 | 2 | 9 | 1 |
| **合计** | **91** | **5** | **83** | **3** |

## A 主题设置页

上游主体：`ui/config/themeConfig/ThemeConfigScreen.kt`（1362 行，`SplicedColumnGroup` 七组 + 末尾重置组）。按 widget 调用数共 **49 处**，其中 theme 组存在 Miuix / 非 Miuix 两条互斥引擎分支（`:187`+`:199`+`:212` 对 `:222`+`:237`），按可见性归并后是 **39 条**（分组口径：theme 3 / 无标题 11 / main_activity 6 / book_info_page 4 / eye_protection 5 / blur_effects 2 / container 8）。本表把两条引擎分支各自拆行（A2/A3），故 A 块 **47 行**。

本地主体：`entry/src/main/ets/pages/ThemeSettingsPage.ets`（333 行）。widget 调用 **47 处**，ForEach 循环折叠后 **46 个可见条目**，分七组：主题模式 4 / 无标题 9 / 主界面 6 / 书籍详情页 3 / 护眼 6 / 模糊 2 / 容器 15，另有 1 个「恢复默认主题配置」独立卡片。

> **口径说明**：任务书里「本地 19 条」是只数开关类控件的粗口径（主界面 2 = 2 个 Switch、护眼 3 = 3 个 Switch……）。本表按**页面上真实可见的行**计数（46 条），因为本地「设置项」既有 `ThemeSwitchRow` 也有 `ThemeSettingsOption`（点开才有 sheet 的条目），只数 Switch 会把「主题管理」「背景图片」「字体设置」这类条目从盘面里漏掉——这正是 [编码规约](../CODE-CONVENTIONS.md) 第四节警告的「只盘相关按钮」漏法。

| 上游能力 | 上游位置 | 本地位置 | 状态 | 差异说明 | 验收方式 | 备注 | ZIP 类别 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| **A1** 深色模式三选一（跟随系统 / 亮色 / 暗色） | `ui/config/themeConfig/ThemeConfigScreen.kt:187`（Miuix `DropdownListSettingItem(theme_mode, theme_mode_v)`）、`:222-229`（非 Miuix `ThemeModeSelector`）、`:1004-1040`（定义，三段 `ToggleButton` + `Role.RadioButton`）；intent `SetThemeMode` | `pages/ThemeSettingsPage.ets:106`/`:108`/`:110` 三个 `ThemeModeItem`（跟随系统/浅色/深色） | 未接 | 三选项都在，但 `onSelect` 只执行 `this.selectedMode = n`：不写 preferences、不改任何配色、退出即丢。上游同一点击走 `appShellSettingsGateway.update { it.copy(themeMode = ...) }` 并触发 `AppCompatDelegate.setDefaultNightMode` | 真机：主题页点「深色」→ 全 App 立刻变深色；杀进程重进仍为深色；偏好里 `themeMode = "2"` | 上游取值 `"0"`/`"1"`/`"2"` 字符串，本地 `@State selectedMode` 是 `number` 2，类型与取值域都不同 | `themeMode` |
| **A2** 主题配色选择（配色方案 / 调色板） | `ThemeConfigScreen.kt:237`（非 Miuix `ThemeColorSelector`，参数含 `themes`/`selectedTheme`/`isDark`/`isAmoled`/`paletteStyle`/`customLightSeedColor`/`customNightSeedColor`）、`:1043` 定义；intent `SelectTheme` | `pages/ThemeSettingsPage.ets:115-126` ForEach 5 个 `ThemePaletteItem`（动态取色/草野/柠檬/黑白/晴空），`:37` `paletteColor(index)` 硬编码 5 色 | 未接 | 本地 5 个写死色块，`onClick` 只改 `selectedPalette`；上游数据驱动 + 日夜两套种子色，选中即改 `appTheme` 键并重建 colorScheme。本地 5 个调色板与上游 `R.array.theme` 条目也不对应 | 真机：点任一调色板 → 主界面主色立即变化；重启保持 | 上游墨水屏主题 `appTheme == "4"` 按 `showEInkTheme` 隐藏，本地无此概念（见 F8） | `themeConfig` |
| **A3** Miuix 引擎下的动态取色（Monet） | `ThemeConfigScreen.kt:199` `SwitchSettingItem(miuix_monet)` → `SetMiuixMonet`；键 `useMiuixMonet`；同组 `:212` 的 `DropdownListSettingItem(theme)` 是此条的下游 | 无 | 未接 | 本地无引擎概念；`useMiuixMonet` 键在 `data/BackupRepository.ets:261-277` 的 53 键组里存在，但没有任何界面或代码读它 | 无（需先有引擎分支 A7） | 上游此条只在 `isMiuixEngine` 为真时出现 | `themeConfig` |
| **A4** 纯黑深色模式（AMOLED） | `ThemeConfigScreen.kt:255` `SwitchSettingItem(pure_black)`（仅非 Miuix）；键 `isPureBlack` | `pages/ThemeSettingsPage.ets:134` `Toggle`（标题「纯黑深色模式」） | 未接 | 本地 Toggle 只改 `@State pureBlack`，而且**没有调用 `onUnavailableAction`**——比其它条目更容易被误读成「已接」。上游打开后 `ui/theme/ThemeEngine.kt`、`OpaqueColorScheme.kt`、`ThemeOverride.kt` 把背景压到纯黑 | 真机：打开后主界面与阅读页背景变 `#000000`；重启保持 | 本地阅读页另有独立「纯黑纸张」概念（`ReaderPage.ets:2756` 的 `isNightPaper` 判定），与全局纯黑无关 | `themeConfig` |
| **A5** 字体设置（字体文件选择） | `ThemeConfigScreen.kt:263` `ClickableSettingItem(font_setting)` → `ShowSheet(ThemeConfigSheet.Font)`；键 `appFontPath` | `pages/ThemeSettingsPage.ets:137`「字体设置」 | 未接 | 本地 `onUnavailableAction`，无 sheet、无字体选择器 | 真机：选一个字体文件 → 全 App 字体变化 | 上游 sheet 由 `ThemeConfigRouteScreen.kt` 的 `fontFolderLauncher`（`OpenDocumentTree`）承接 | `themeConfig` |
| **A6** 自定义主题配色（12 号主题） | `ThemeConfigScreen.kt:268` `ClickableSettingItem(custom_theme_colors)` → `onNavigateToCustomTheme`（条件 `theme.appTheme == "12" && (!isMiuixEngine \|\| theme.useMiuixMonet)`） | 无 | 未接 | 本地无自定义配色页。上游 `ui/config/customTheme/CustomThemeScreen.kt`（269 行）可分别调日/夜 6 组颜色 + 对比度 + 深度个性化 | 无（页面不存在） | 上游键：`customContrast`、`enableDeepPersonalization`、`materialVersion`、`paletteStyle` | `themeConfig` |
| **A7** 主题引擎切换（Miuix / Material） | `ThemeConfigScreen.kt:273` `DropdownListSettingItem(compose_engine)` → `SetComposeEngine`；键 `composeEngine` | `pages/ThemeSettingsPage.ets:138`「主题风格」 | 未接 | 本地只有一行「主题风格」走 `onUnavailableAction`。上游 `composeEngine` 是全局渲染分支开关，`ui/theme/LegadoTheme.kt` 暴露后被 30+ 处读取，决定用哪套控件 | 真机：切换引擎 → 全 App 控件形态变化 | 本地「主题风格」文案与上游 `compose_engine`（引擎）语义不同，按文案对齐会错 | `themeConfig` |
| **A8** 切换图标（启动器图标） | `ThemeConfigScreen.kt:284` `ClickableSettingItem(change_icon)` → `ShowSheet(ThemeConfigSheet.LauncherIcon)` | `pages/ThemeSettingsPage.ets:139`「切换图标」 | 未接 | 本地 `onUnavailableAction`。上游由 `ThemeConfigRouteScreen.kt` 的 `navigationIconLauncher`（`GetContent` + MD5 命名）落盘到 `nav_icons/` | 真机：换图标 → 桌面图标变化 | 上游键 `launcherIcon` 在 `data/BackupRepository.ets:231-236` 的 `alwaysIgnoredPreferenceKeys` 里，**永不进备份**——与上游 `alwaysIgnoredPreferenceKeys` 一致，不算差异 | `themeConfig` |
| **A9** 预见性返回手势 | `ThemeConfigScreen.kt:291` `SwitchSettingItem(predictive_back)` → `SetPredictiveBackEnabled`；键 `isPredictiveBackEnabled` | `pages/ThemeSettingsPage.ets:140` `ThemeSwitchRow` | 未接 | 本地 `onUnavailableAction` | 真机：打开后返回手势有预览动画 | 依赖系统能力，上游只在支持的版本显示 | `themeConfig` |
| **A10** 阅读界面共享元素动画 | `ThemeConfigScreen.kt:301` `SwitchSettingItem(reader_shared_element)` → `SetReaderSharedElementEnabled` | `pages/ThemeSettingsPage.ets:141` `ThemeSwitchRow` | 未接 | 本地 `onUnavailableAction` | 真机：打开后书籍封面→详情页有共享元素过渡 | — | `themeConfig` |
| **A11** 字体大小缩放 | `ThemeConfigScreen.kt:309` `SliderSettingItem(font_scale, 8f..16f, steps 7)` → `SetFontScale`；键 `fontScale` | `pages/ThemeSettingsPage.ets:142-149` Slider（8..16） | 未接 | 本地 Slider 只改 `@State fontScalePreview`，不写盘、不影响任何文字 | 真机：拖到 16 → 全 App 字号变大；重启保持 | 本地阅读页字号另有独立设置（[阅读配置总账](READER-CONFIG.md) 已盘），与全局 `fontScale` 是两套 | `themeConfig` |
| **A12** 主题包管理入口 | `ThemeConfigScreen.kt:324` `ClickableSettingItem(theme_pack)` → `onNavigateToThemeManage` | `pages/ThemeSettingsPage.ets:150`「主题管理」 | 未接 | 本地 `onUnavailableAction('主题包管理尚未迁移')`——**入口文案在、页面不在**。整块展开见 B | 真机：点进去能保存/导入/导出主题包 | 上游目标页 `ui/config/themeManage/ThemeManageScreen.kt`（331 行） | `themeConfig` |
| **A13** 背景图片（日间/夜间各一张 + 模糊图） | `ThemeConfigScreen.kt:329` `ClickableSettingItem(background_image)` → `ShowSheet(ThemeConfigSheet.BackgroundImage(...))`；键 `backgroundImage`/`backgroundImageNight`/`backgroundImageBlurring`/`backgroundImageNightBlurring` | `pages/ThemeSettingsPage.ets:151`「背景图片」 | 未接 | 本地 `onUnavailableAction('背景图片设置尚未迁移')`。上游按日夜选图：`ui/theme/AppBackground.kt:22-29` 读 `backgroundImageDark`/`backgroundImageLight`/`backgroundImageDarkBlurring`/`backgroundImageBlurring` | 真机：日间/夜间各设一张图 → 切日夜时背景跟着换 | 本地无任何全 App 背景图能力 | `themeConfig` |
| **A14** 首页与导航设置 | `ThemeConfigScreen.kt:345` `ClickableSettingItem(main_navigation_settings)` → `ShowSheet(ThemeConfigSheet.MainNavigation)` | `pages/ThemeSettingsPage.ets:156`「首页与导航」 | 未接 | 本地 `onUnavailableAction`。上游 sheet 里可拖排主导航顺序、逐项显隐（`SetMainNavigationOrder`/`SetMainDestinationVisible`） | 真机：关掉「发现」→ 底部导航少一项 | — | `themeConfig` |
| **A15** 显示状态栏 | `ThemeConfigScreen.kt:352` `SwitchSettingItem(show_status)` → `SetShowStatusBar`；键 `showStatusBar` | `pages/ThemeSettingsPage.ets:157` `ThemeSwitchRow` | 未接 | 本地 `onUnavailableAction` | 真机：关掉后全 App 顶部状态栏消失 | — | `themeConfig` |
| **A16** 启用滑动时动画 | `ThemeConfigScreen.kt:362` `SwitchSettingItem(show_swipe_animation)` → `SetSwipeAnimation`；键 `swipeAnimation` | `pages/ThemeSettingsPage.ets:158` `ThemeSwitchRow` | 未接 | 本地 `onUnavailableAction` | 真机：关掉后翻页无过渡动画 | 上游此条带 TODO 注释「这个可以不要了」，仍属可见条目 | `themeConfig` |
| **A17** 顶栏与底栏设置 | `ThemeConfigScreen.kt:371` `ClickableSettingItem(top_bottom_bar_settings)` → `ShowSheet(ThemeConfigSheet.TopBottomBar)`；`ui/config/themeConfig/TopBottomBarSettingsSheet.kt` | `pages/ThemeSettingsPage.ets:159`「顶栏与底栏」 | 未接 | 本地 `onUnavailableAction`。上游 sheet 有 10 个键：`topBarOpacity`/`bottomBarOpacity`/`topBarBlurRadius`/`bottomBarBlurRadius`/`topBarBlurAlpha`/`bottomBarBlurAlpha`/`bottomBarLensRadius`/`useFlexibleTopAppBar`/`topBarButtonStyle`/`mergeTopBarActions` | 真机：调顶栏不透明度 → 滚动时顶栏透出背景 | 渲染端在 `ui/widget/components/topbar/*` 与 `FloatingBottomBar.kt`/`AppNavigationBar.kt` | `themeConfig` |
| **A18** 平板界面 | `ThemeConfigScreen.kt:378` `DropdownListSettingItem(tabletInterface)` → `SetTabletInterface` | 无 | 未接 | 本地无此条目（**条目本身都缺**，不只是开关没接） | 无 | 上游按设备形态显示 | `themeConfig` |
| **A19** 多窗布局 | `ThemeConfigScreen.kt:389` `DropdownListSettingItem(multi_pane_layout)` → `SetMultiPaneMode` | `pages/ThemeSettingsPage.ets:161`「多窗布局」 | 未接 | 本地 `onUnavailableAction` | 真机：宽屏下切单/双栏 | 本地 `:160`「导航布局」是上游没有的额外条目（对应 `labelVisibilityMode`），本表不单列 | `themeConfig` |
| **A20** 界面颜色跟随封面取色 | `ThemeConfigScreen.kt:399` `SwitchSettingItem(book_info_follow_cover_color)`；键 `bookInfoFollowCoverColor` | `pages/ThemeSettingsPage.ets:166` `ThemeSwitchRow` | 未接 | 本地 `onUnavailableAction` | 真机：打开后详情页配色随封面变 | 渲染端 `ui/book/info/BookInfoScreen.kt` | `themeConfig` |
| **A21** 网络封面背景设置 | `ThemeConfigScreen.kt:407` `DropdownListSettingItem(book_info_network_cover_background)`；键 `bookInfoNetworkCoverBackground` | `pages/ThemeSettingsPage.ets:167`「网络封面背景设置」 | 未接 | 本地 `onUnavailableAction` | 真机：选「模糊」→ 网络封面背后出模糊底 | 渲染端 `ui/book/info/BookInfoViewModel.kt` | `themeConfig` |
| **A22** 默认封面背景设置 | `ThemeConfigScreen.kt:416` `DropdownListSettingItem(book_info_default_cover_background)`；键 `bookInfoDefaultCoverBackground` | `pages/ThemeSettingsPage.ets:168`「默认封面背景设置」 | 未接 | 本地 `onUnavailableAction` | 真机：选「跟随主题」→ 无封面书用主题底色 | — | `themeConfig` |
| **A23** 作者搜索回退 | `ThemeConfigScreen.kt:425` `SwitchSettingItem(book_info_author_search_fallback)`；键 `bookInfoAuthorSearchFallback` | 无 | 未接 | 本地无此条目。上游在详情页点作者时按此键决定是搜作者名还是搜书名 | 无 | 属 book_info 组第 4 条，本地整组只有 3 条 | `themeConfig` |

| **A24** 启用护眼模式 | `ThemeConfigScreen.kt:436` `SwitchSettingItem(eye_protection_enabled)`；键 `eyeProtectionEnabled`；渲染 `ui/book/read/EyeProtection.kt:99-117` `Modifier.eyeProtectionColorFilter` 由 `base/BaseComposeActivity.kt:89-104` 全 App 套一层 `graphicsLayer { colorFilter = ColorFilter.colorMatrix(...) }` | `pages/ThemeSettingsPage.ets:173` `ThemeSwitchRow`「启用护眼模式」 | 未接 | 本地这一行 `onUnavailableAction('护眼模式设置暂未保存')`，开关只改 `@State`。**注意**：护眼在本地另有「可用那套」——`ReaderSettingsPage.ets:1622` 的护眼 sheet，状态在 `Index.ets:206-212` 与 `ReaderSettingsRepository.ets:205-207`，但那套只把 `eyeProtectionActive` 传给 `ReaderPage.ets:305` 用于底部动作条高亮（`:3166`），**没有任何色温滤镜渲染**（全仓无 `colorFilter`/`blendMode`/遮罩层） | 真机：打开 → 全 App（不只阅读页）泛暖色；调强度 0→100 色温跟着变 | 两套状态互不相通：主题页这套是死 UI，阅读设置页那套能存盘但不渲染。上游是「一份状态、全 App 生效」 | `themeConfig` |
| **A25** 深色模式时自动开启护眼 | `ThemeConfigScreen.kt:445` `SwitchSettingItem(eye_protection_auto_night)`；键 `eyeProtectionAutoNight`；判定 `EyeProtection.kt:52-78 isActiveAt(..., autoNight, isDark, ...)` | `pages/ThemeSettingsPage.ets:174` `ThemeSwitchRow` | 未接 | 本地 `onUnavailableAction`。阅读设置页那套有同名开关（`ReaderSettingsPage.ets:1628`）且能存盘，但 `isEyeProtectionActive()`（`Index.ets:2069-2079`）**不读它**——只按「开关 + 定时」判定，日夜这个维度根本没进判定式 | 真机：打开后把系统切深色 → 护眼自动生效 | 上游判定式的第二参就是 `isDark`，本地缺这一支 | `themeConfig` |
| **A26** 护眼色温强度 | `ThemeConfigScreen.kt:456` `SliderSettingItem(color_temperature, 0..100, 默认 50)`（`AnimatedVisibility(isEyeProtectionConfigured)` 内）；键 `colorTemperature`；映射 `EyeProtection.kt:30-50 temperatureForIntensity/matrixValuesForIntensity`（2596K..5500K，9 个系数） | `pages/ThemeSettingsPage.ets:176`「色温」 | 未接 | 本地 `onUnavailableAction('色温调节尚未迁移')`。阅读设置页那套有 `护眼强度` Slider 0..100（`ReaderSettingsPage.ets:1633`）且存盘为 `eyeProtectionIntensity`，但**没有映射到 2596K..5500K 的色矩阵**，也没有任何渲染 | 真机：拖到 100 → 屏幕明显变暖；拖回 0 → 恢复 | 备份侧 `data/BackupRepository.ets:580-581` 把 `eyeProtectionIntensity` 取整后写成 `colorTemperature`，键对上了、渲染没对上 | `themeConfig` |
| **A27** 护眼定时开启 | `ThemeConfigScreen.kt:470` `SwitchSettingItem(eye_protection_schedule)`；键 `eyeProtectionSchedule` | `pages/ThemeSettingsPage.ets:178` `ThemeSwitchRow` | 未接 | 本地 `onUnavailableAction`。阅读设置页那套有同名开关且能存盘（`ReaderSettingsRepository.ets:207`），`Index.ets:2069-2079` 也真的按它判定，但判定结果只用于高亮态 | 真机：打开并设 22:00–07:00 → 到点自动变暖、跨零点仍生效 | 上游 `EyeProtection.kt:80-88 parseTime` 解析 `HH:mm`；本地 `Index.ets:2081-2090 parseEyeProtectionMinutes` 等价 | `themeConfig` |
| **A28** 护眼开始时间 | `ThemeConfigScreen.kt:481` `ClickableSettingItem(start_time)`（`TimePicker` 对话框，`ThemeConfigDialog.TimePicker`） | `pages/ThemeSettingsPage.ets:181`「开始时间」 | 未接 | 本地 `onUnavailableAction('时间选择尚未迁移')`；阅读设置页那套有 `开始时间`（`ReaderSettingsPage.ets:1645`）可点开选择并存盘 | 真机：设 22:00 → 到 22:00 生效 | — | `themeConfig` |
| **A29** 护眼结束时间 | `ThemeConfigScreen.kt:493` `ClickableSettingItem(end_time)` | `pages/ThemeSettingsPage.ets:183`「结束时间」 | 未接 | 同 A28；跨零点逻辑本地已有（`Index.ets:2072-2074` 的 `start < end ? ... : current >= start \|\| current < end`） | 真机：设 07:00 → 07:00 恢复 | — | `themeConfig` |
| **A30** 启用控件模糊 | `ThemeConfigScreen.kt:512` `SwitchSettingItem(is_blur_enable)` → `SetBlurEnabled`；键 `enableBlur`；渲染 `ui/theme/HazeStyle.kt:20`（`if (LocalAppUiConfiguration.current.theme.enableBlur) Modifier.hazeSource(state)`）、`ui/util/MiuixUtils.kt:142` | `pages/ThemeSettingsPage.ets:191` `ThemeSwitchRow` | 未接 | 本地 `onUnavailableAction('模糊效果设置暂未保存')`，开关只改 `@State`。上游 `enableBlur` 被 `AppScaffold`/`GlassDefaults`/`BookshelfViewModel`/`HomepageModuleFeed` 等 6 处读取决定是否套 `hazeSource` | 真机：打开后顶栏/底栏出现毛玻璃 | 本地无 `haze`/`blur` 渲染管线 | `themeConfig` |
| **A31** 启用渐变模糊 | `ThemeConfigScreen.kt:518` `SwitchSettingItem(is_blur_progressive_enable)`（`AnimatedVisibility(enableBlur)` 内）；键 `enableProgressiveBlur` | `pages/ThemeSettingsPage.ets:193` `ThemeSwitchRow`（`if (this.blurEnabled)` 内） | 未接 | 本地 `onUnavailableAction`；条件显示逻辑与上游一致（父开关打开才出现） | 真机：打开后模糊有渐变过渡而非硬边 | 依赖 A30 先成立 | `themeConfig` |
| **A32** 容器背景图总开关 | `ThemeConfigScreen.kt:533` `SwitchSettingItem`（**无 string 资源，硬编码标题「容器背景图」**）；键 `enableContainerBackgroundImage` | `pages/ThemeSettingsPage.ets:200` `ThemeSwitchRow`「容器背景图」 | 未接 | 本地 `onUnavailableAction('容器背景图片设置暂未保存')`。上游开关打开后 `AnimatedVisibility` 放出 A33/A34 两条 | 真机：打开 → 下面两行出现 | 上游这一条用硬编码中文，本地也是硬编码，两侧一致 | `themeConfig` |
| **A33** 大容器背景图片 | `ThemeConfigScreen.kt:545` `ClickableSettingItem`（硬编码「大容器背景图片」）；`ThemeConfigSheet.BackgroundImage(ContainerBackgroundTarget.LargeContainer)` | `pages/ThemeSettingsPage.ets:202`「大容器背景图片」 | 未接 | 本地 `onUnavailableAction('背景图片选择尚未迁移')` | 真机：选图 → 大容器出背景图 | 与大容器不透明度 A35 叠加生效 | `themeConfig` |
| **A34** 项目背景图片 | `ThemeConfigScreen.kt:564` `ClickableSettingItem`（硬编码「项目背景图片」） | `pages/ThemeSettingsPage.ets:204`「项目背景图片」 | 未接 | 本地 `onUnavailableAction` | 真机：选图 → 设置项卡片出背景图 | 上游 `ContainerBackgroundTarget` 区分大小容器 | `themeConfig` |
| **A35** 容器背景不透明度 | `ThemeConfigScreen.kt:585` `SliderSettingItem(container_opacity, 0..100, 默认 100)`；键 `containerOpacity` | `pages/ThemeSettingsPage.ets:207`「容器背景不透明度」 | 未接 | 本地 `onUnavailableAction('容器不透明度尚未迁移')`。上游 `ui/widget/components/card/GlassCard.kt` 读它决定卡片底色透明度 | 真机：拖到 30 → 卡片半透明透出背景 | 上游有 3 个不透明度：容器/顶栏/底栏（A17 另两个） | `themeConfig` |
| **A36** 关闭设置分组圆角 | `ThemeConfigScreen.kt:598` `SwitchSettingItem(disable_spliced_group_corner_radius)` | `pages/ThemeSettingsPage.ets:208` `ThemeSwitchRow` | 未接 | 本地 `onUnavailableAction('设置分组圆角暂未保存')`。上游读 `ui/widget/components/SplicedColumnGroup.kt` | 真机：打开后设置分组变直角 | — | `themeConfig` |
| **A37** 覆盖卡片圆角（总开关） | `ThemeConfigScreen.kt:608` `SwitchSettingItem(base_card_corner_radius_override)`；`AnimatedVisibility(theme.overrideBaseCardCornerRadius)` 放出 A38 | `pages/ThemeSettingsPage.ets:209` `ThemeSwitchRow`「覆盖卡片圆角」 | 未接 | 本地 `onUnavailableAction('卡片圆角设置暂未保存')`；条件显示逻辑与上游一致 | 真机：打开 → 「卡片圆角」行出现 | — | `themeConfig` |
| **A38** 卡片圆角数值 | `ThemeConfigScreen.kt:617` `SliderSettingItem(base_card_corner_radius, 0..40, steps 79, decimal)`；键 `baseCardCornerRadius` | `pages/ThemeSettingsPage.ets:211`「卡片圆角」 | 未接 | 本地 `onUnavailableAction('卡片圆角调节尚未迁移')` | 真机：拖到 40 → 卡片明显变圆 | 上游是小数步进（79 步 / 40dp），本地无 Slider 只有一行点击项 | `themeConfig` |
| **A39** 覆盖卡片边框（总开关） | `ThemeConfigScreen.kt:630` `SwitchSettingItem(base_card_border_override)`；`AnimatedVisibility(theme.overrideBaseCardBorder)` 放出 A40–A42 | `pages/ThemeSettingsPage.ets:214` `ThemeSwitchRow`「覆盖卡片边框」 | 未接 | 本地 `onUnavailableAction('卡片边框设置暂未保存')` | 真机：打开 → 下面三行出现 | — | `themeConfig` |
| **A40** 边框宽度 | `ThemeConfigScreen.kt:640` `SliderSettingItem(border_width, 0..5, steps 49)`；键 `baseCardBorderWidth` | `pages/ThemeSettingsPage.ets:216`「边框宽度」 | 未接 | 本地 `onUnavailableAction('边框宽度设置尚未迁移')` | 真机：拖到 5 → 边框变粗 | — | `themeConfig` |
| **A41** 日间边框颜色 | `ThemeConfigScreen.kt:652` `BaseCardBorderColorSettingItem(base_card_border_color_day)`（`:973-1000` 定义，内部 `:979 ClickableSettingItem`）；键 `baseCardBorderColorDay` | `pages/ThemeSettingsPage.ets:218`「日间边框颜色」 | 未接 | 本地 `onUnavailableAction('边框颜色选择尚未迁移')`。上游点开是取色盘（`ThemeConfigSheet.BaseCardBorderColor(dark = false)`） | 真机：选红色 → 浅色模式下卡片红边 | 这一行本身就是「日夜两套」的直接证据——本地连一行都没接 | `themeConfig` |
| **A42** 夜间边框颜色 | `ThemeConfigScreen.kt:663` `BaseCardBorderColorSettingItem(base_card_border_color_night)`；键 `baseCardBorderColorNight` | `pages/ThemeSettingsPage.ets:220`「夜间边框颜色」 | 未接 | 同 A41（`ThemeConfigSheet.BaseCardBorderColor(dark = true)`） | 真机：选蓝色 → 深色模式下卡片蓝边 | — | `themeConfig` |
| **A43** 显示分隔线 | `ThemeConfigScreen.kt:676` `SwitchSettingItem(show_divider_line)`；键 `enableItemDivider`；`if (theme.enableItemDivider)` 放出 A44–A46 | `pages/ThemeSettingsPage.ets:223` `ThemeSwitchRow` | 未接 | 本地 `onUnavailableAction('分隔线设置暂未保存')` | 真机：打开 → 条目之间出现分隔线 | — | `themeConfig` |
| **A44** 分隔线宽度 | `ThemeConfigScreen.kt:684` `SliderSettingItem(theme_config_divider_width)`；键 `dividerWidth` | `pages/ThemeSettingsPage.ets:225`「分隔线宽度」 | 未接 | 本地 `onUnavailableAction('分隔线宽度设置尚未迁移')` | 真机：调粗可见 | — | `themeConfig` |
| **A45** 分隔线长度 | `ThemeConfigScreen.kt:696` `SliderSettingItem(theme_config_divider_length, 30..100)`；键 `dividerLength` | `pages/ThemeSettingsPage.ets:227`「分隔线长度」 | 未接 | 本地 `onUnavailableAction('分隔线长度设置尚未迁移')` | 真机：拖到 30 → 分隔线缩短且居中 | — | `themeConfig` |
| **A46** 分隔线颜色 | `ThemeConfigScreen.kt:707` `ClickableSettingItem(tip_divider_color)` → `ShowSheet(ThemeConfigSheet.DividerColor)`；键 `dividerColor` | `pages/ThemeSettingsPage.ets:229`「分隔线颜色」 | 未接 | 本地 `onUnavailableAction('分隔线颜色选择尚未迁移')` | 真机：选色 → 分隔线变色 | — | `themeConfig` |
| **A47** 恢复默认主题配置 | `ThemeConfigScreen.kt:737` `ClickableSettingItem(theme_config_reset_defaults)` + `:752 AppAlertDialog(ResetDefaults)`；intent `ThemeConfigIntent.ResetDefaults` | `pages/ThemeSettingsPage.ets:233-235`「恢复默认主题配置」 | 未接 | 本地 `onUnavailableAction`，无二次确认对话框。上游弹 `AppAlertDialog` 确认后重置全部 themeConfig 键 | 真机：改乱配色后点恢复 → 全部回默认 | 上游 `ThemeConfigViewModel` 有 `ResetDefaults` 分支；本地既无确认框也无重置逻辑 | `themeConfig` |

## B 主题包管理

上游主体：`ui/config/themeManage/ThemeManageScreen.kt`（331 行，5 个入口 + 已存主题列表 + 3 个确认框）、`help/config/ThemePackageManager.kt`（1254 行，保存/导入/导出/资产打包全在这）、`help/config/ThemeImportExport.kt`（393 行，资产嵌入与旧版 JSON 解析）、`ui/config/themeManage/EditThemeSheet.kt`（403 行，已存主题编辑器）。
本地主体：**无**。`pages/ThemeSettingsPage.ets:150` 的「主题管理」只弹一句「主题包管理尚未迁移」，`pages/` 目录 34 个文件里没有任何主题包相关页面。

> **这一块整块缺失**，按 [编码规约](../CODE-CONVENTIONS.md) 第四节「发现整块缺失仍要新开块」处理：不把它压进 A12 一行，而是逐条列出上游可见能力，让后续实现时能按行认领。

| 上游能力 | 上游位置 | 本地位置 | 状态 | 差异说明 | 验收方式 | 备注 | ZIP 类别 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| **B1** 保存当前配置为主题 | `ui/config/themeManage/ThemeManageScreen.kt:86-90` `theme_manage_save_current` → `ThemeManageIntent.OpenSaveDialog`；`:155-` `AppAlertDialog(theme_manage_save_theme)`；落盘 `ThemePackageManager.kt:265 saveTheme` | 无 | 未接 | 本地无保存入口、无命名对话框、无 `savedThemeDir` 目录 | 真机：改一套配色 → 保存为「我的主题」→ 列表出现该项 | 上游保存的是 `ThemeExportData` 全量快照（`domain/model/settings/ThemeExportData.kt`） | `themeConfig` |
| **B2** 导出当前主题为文件 | `ThemeManageScreen.kt:91-95` `theme_manage_export_current` → `RequestExport()`；`ThemePackageManager.kt:74 exportPackage` | 无 | 未接 | 本地无导出入口、无文件保存对话框 | 真机：导出得到 `.zip`，换机导入后配色一致 | 上游包内含 `manifest` + 背景图 + 封面相册 + 字体 | `themeConfig` |
| **B3** 导入主题包（zip） | `ThemeManageScreen.kt:96-100` `theme_manage_import_package` → `RequestImportPackage`；`ThemePackageManager.kt:112 importPackage(uri): Result<Unit>`、`:904 extractPackage` | 无 | 未接 | 本地无导入入口。`data/BackupRepository.ets` 只处理 `config.xml`/`themeConfig.json` 的备份归档，与主题包无关 | 真机：选一个主题包 → 配色、背景图、字体一起变 | 上游导入会做 `resolvePackageFile`/`uniqueImportedAlbumName` 等去重 | `themeConfig` |
| **B4** 导入旧版 JSON 主题 | `ThemeManageScreen.kt:101-105` `theme_manage_import_config` → `RequestImportLegacyJson`；`ThemePackageManager.kt:194 importLegacyJson`；`ThemeImportExport.kt:238-270 prepareLegacyJson/parseThemeData/parseLegacyThemeData/parseObfuscatedThemeV1` | 无 | 未接 | 本地无旧版 JSON 导入。注意上游有**混淆版 v1**（`parseObfuscatedThemeV1`）这条兼容分支 | 真机：导入旧版 `.json` 主题 → 配色生效 | 这是「读取路径」必须交代的旧版分支（[编码规约](../CODE-CONVENTIONS.md) 第二节） | `themeConfig` |
| **B5** 迁移旧版已存主题 | `ThemeManageScreen.kt:106-116` `theme_manage_migrate_legacy` → `MigrateLegacyThemes`（仅 `state.hasLegacyThemes` 时出现）；`ThemePackageManager.kt:237 hasLegacySavedThemes`、`:241 migrateLegacySavedThemes`、`:227 loadSavedThemes` | 无 | 未接 | 本地无旧版目录、无迁移入口，条件显示逻辑也不存在 | 无（本地无旧版数据可迁） | 上游为从 SharedPreferences 时代的主题列表迁到文件夹结构而设 | `themeConfig` |
| **B6** 已存主题列表与搜索 | `ThemeManageScreen.kt:120-150`：`:122-129 SearchBar(state.searchQuery)`、`:132-138 AppText(theme_manage_saved_themes)`、`:141-149 items(filteredSavedThemes) → SavedThemeItem(...)` | 无 | 未接 | 本地无列表、无搜索。上游列表项支持应用/编辑/导出/删除四个动作 | 真机：存 3 套主题 → 列表 3 项，搜索能过滤 | 上游 `ThemePackageManager.kt:312 readSavedThemeFolder` 负责扫描目录 | `themeConfig` |
| **B7** 应用已存主题 | `ThemeManageScreen.kt:141-149` `onApply → OpenApplyDialog`、`:184 AppAlertDialog(theme_manage_apply_theme)`；`ThemePackageManager.kt:291 applySavedTheme`、`:97 prepareForApply`、`:156 applyAssets` | 无 | 未接 | 本地没有「应用」这个动作，也没有可应用的对象：`pages/ThemeSettingsPage.ets:150` 的「主题管理」直接 `onUnavailableAction('主题包管理尚未迁移')`，连列表页都不存在。上游点「应用」会先 `prepareForApply` 把资产拷到可读位置再重建 colorScheme | 真机：点「应用」→ 全 App 立刻换配色与背景 | 上游应用前会 `prepareForApply` 把资产拷到可读位置 | `themeConfig` |
| **B8** 编辑已存主题 | `ThemeManageScreen.kt:141-149` `onEdit → OpenEditSheet`；`ui/config/themeManage/EditThemeSheet.kt:44 fun EditThemeSheet`：`:95` 基础组、`:96/:103/:110/:117` 4 个 `CompactDropdownSettingItem`（`theme_mode`/`palette_style`/`material_version`/`preferred_contrast`）、`:129 use_palette_colors`、`:136-151` 日间 6 个 `ColorItem`、`:155-170` 夜间 6 个 `ColorItem`、`:174/:177` 日/夜种子色、`:186-202` 布局组开关 | 无 | 未接 | 本地无编辑器。**这张 sheet 是「日夜两套」最完整的体现**：日间 6 色与夜间 6 色并列编辑 | 真机：编辑一套主题 → 日/夜各自改色 → 保存后应用可见 | 上游在这里能改 `themeMode` 本身，说明主题包可以绑定推荐模式 | `themeConfig` |
| **B9** 导出已存主题 | `ThemeManageScreen.kt:141-149` `onExport → RequestExport(theme)`；`ThemePackageManager.kt:390 exportSavedThemeFolder` | 无 | 未接 | 本地没有已存主题，因此也无从导出单条：`ThemeSettingsPage.ets:150` 的「主题管理」是 `onUnavailableAction`，`data/BackupRepository.ets` 的 33 项归档清单里也没有任何主题包目录。上游从列表对某套主题导出，与 B2 的整包导出复用 `exportPackage` | 真机：从列表导出某套主题 → 得到 zip | 与 B2 复用 `exportPackage` | `themeConfig` |
| **B10** 删除已存主题 | `ThemeManageScreen.kt:141-149` `onDelete → OpenDeleteDialog`、`:204 AppAlertDialog(theme_manage_delete_theme)`；`ThemePackageManager.kt:278 deleteSavedTheme` | 无 | 未接 | 本地无删除动作、无确认框 | 真机：删除后列表少一项，重启不回来 | — | `themeConfig` |
| **B11** 主题包内嵌资产打包与还原 | `ThemePackageManager.kt:509 copyAssetsToFolder`、`:535 copyEmbeddedAssetsToFolder`、`:613 copyCoverAlbumsToFolder`、`:657 resolveSavedAssets`、`:682 exportAssets`、`:699 exportCoverAlbums`、`:743 importAssets`、`:982 toPortableConfig`、`:1006 toSavedConfig`、`:1010 assetSources`、`:1102 copyLimitedTo`（大小上限）；`ThemeImportExport.kt:22 withEmbeddedAssets`、`:28 exportAssets`、`:77 exportCoverAssets` | 无 | 未接 | 本地无资产打包：背景图、封面相册、字体都不会随主题走 | 真机：主题包换机后背景图仍在 | `copyLimitedTo` 说明上游对包大小设了上限，实现时要照抄这个限制 | `themeConfig` |
| **B12** 主题包目录结构与清单 | `ThemePackageManager.kt:667 savedThemeDir`、`:673 writeSavedManifest`、`:312 readSavedThemeFolder`、`:352 saveThemeFolder`、`:872 uniqueSavedThemeName`、`:1088 writeEntry`、`:1094 copyToPackageFile`、`:1070 openSource`、`:1079 sourceExtension` | 无 | 未接 | 本地无目录约定，无 manifest | 无 | 上游用「文件夹 + manifest」而非单文件，便于增量替换单张背景图 | `themeConfig` |

## C 首次启动向导

上游主体：`feature/onboarding/OnboardingScreen.kt:339-357`（第 4 页，`ThemeModeSelector` + `ThemeColorSelector`）、`feature/onboarding/OnboardingContract.kt`（`OnboardingUiState.themeMode: String = "0"`、`OnboardingIntent.SetThemeMode(value: String)`、`OnboardingEffect.ApplyDayNight`）、`feature/onboarding/OnboardingViewModel.kt:47`（初值读网关）、`:120-123`（点击立即写网关并派 `ApplyDayNight`）、`feature/onboarding/OnboardingRouteScreen.kt`（承接 `ApplyDayNight` effect）。
本地主体：`entry/src/main/ets/pages/OnboardingPage.ets`（`onComplete(themeMode, paletteIndex)`）、`data/OnboardingRepository.ets`（preferences `legado_first_run`）、`pages/Index.ets:1653-1670`（`restoreOnboarding` / `finishOnboarding`）。

| 上游能力 | 上游位置 | 本地位置 | 状态 | 差异说明 | 验收方式 | 备注 | ZIP 类别 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| **C1** 向导第 4 页深色模式三选一 | `OnboardingScreen.kt:341` `ThemeModeSelector(selectedMode = state.themeMode, onModeSelected = { onIntent(SetThemeMode(it)) })`；`OnboardingViewModel.kt:120-123` 点击即 `appShellSettingsGateway.update { it.copy(themeMode = intent.value) }` + `_effects.tryEmit(OnboardingEffect.ApplyDayNight)` | `pages/OnboardingPage.ets:90-94` Row 内 `:91` `modeOption('跟随系统', 0)`、`:92` `('浅色', 1)`、`:93` `('深色', 2)`；`:122-128` `modeOption` 只 `onClick(() => this.themeMode = mode)` | 未接 | 选项齐全、文案一致，但点选只改 `@State themeMode`：**不写盘、不换肤、没有 `ApplyDayNight` 等价 effect**。上游是「点一下就立刻写网关并套用夜间模式」 | 真机：向导里点「深色」→ 向导页自身立刻变深色 | 本地 `:115` 的文案自己写着「外观选择会保存用于向导偏好；全局换肤仍在迁移中」——向导作者已经知道这一步没接 | `themeMode` |
| **C2** 向导调色板选择 | `OnboardingScreen.kt:343-357` `ThemeColorSelector(...)` | `pages/OnboardingPage.ets:95-108` ForEach 5 个调色板（`:104` `['动态色','草原','柠檬','黑白','玫瑰']`），`:99-103` 选中态 ✓ + 边框 | 未接 | 本地 5 个调色板与 A2 那 5 个是同一套写死色，点选只改 `@State paletteIndex` | 真机：选「玫瑰」→ 向导预览与主界面都变玫瑰色 | 与 A2 共用同一份缺口 | `themeMode` |
| **C3** 外观选择写入偏好 | `OnboardingViewModel.kt:120-123` 写 `themeMode` 网关；`OnboardingRepository` 等价物在上游是 `AppShellSettings` 持久化 | `data/OnboardingRepository.ets:10` `preferenceName = 'legado_first_run'`、`:13` `defaults = { completed: false, themeMode: 0, paletteIndex: 0 }`、`:29-31` `static async complete(context, themeMode, paletteIndex)` → `store.put('themeMode', ...)`；调用方 `pages/Index.ets:1659-1670` `finishOnboarding` | 已接 | 本地确实把 `themeMode`（number 0..2）与 `paletteIndex` 写进了 preferences，`:21` 还做了 0..2 夹取。与上游的差别是**写的位置不同**：上游写 `AppShellSettings`（全局网关，写了就生效），本地写独立的 `legado_first_run`（只有向导自己知道） | 真机：走完向导 → 读 preferences 能看到 `themeMode` | 这是全表**唯一**真正落盘 `themeMode` 的地方；也正因它写在了错的容器里，才有 C4 | `themeMode` |
| **C4** 启动时读取并应用已保存的 themeMode | `OnboardingViewModel.kt:47` `themeMode = appShellSettingsGateway.currentSettings.themeMode`（向导初值就取网关） | `pages/Index.ets:1653-1657` `restoreOnboarding(context)` **只** `this.onboardingComplete = state.completed` | 未接 | 本地读得出 `themeMode`/`paletteIndex`，但**读完就丢**，从不赋给任何 `@State`、从不参与配色。这是 C3 白写的直接原因 | 真机：向导选深色 → 杀进程重进 → 仍是深色 | 修法很窄：把 `restoreOnboarding` 里读到的两个字段接到全局主题状态即可；难点仍在「全局主题状态本身不存在」（见开篇第 1、2 条） | `themeMode` |
| **C5** 向导主题预览卡 | 上游无独立预览卡——`ThemeColorSelector` 自身带选中态预览 | `pages/OnboardingPage.ets:109-114`「主题预览」卡（底色 `#FFFFFF`、外框 `#E8E9F2`） | 不适用 | 上游没有这个界面元素，按「上游没有就不要这个效果」本不该有；本地这块还是写死的浅色，与它周围的全深色页面不一致 | 无 | 建议随 A2 一起处理：调色板真接上以后，这张卡自然会被真实配色取代 | `themeMode` |

## D 阅读页日夜快捷按钮

上游主体：`ui/book/read/ReadStyleDelegate.kt:451-482`（`toggleDayNight()`，改网关 + 清提醒 + 通知重绘）、`ui/book/read/sheet/GlobalThemePage.kt:181-189`（阅读页「主题」sheet 里的 `SmallTonalButton`）、`ui/book/read/sheet/ThemeListContent.kt:284-289`（主题列表页搜索框右侧同款按钮）、`help/config/ReadStyleResolver.kt:27-59`（日夜派生：`themeMode` → `isNightThemeCompat`，再被 `ReadSessionState.isDarkThemeOverride` 覆盖）。
本地主体：`pages/Index.ets:2062-2067` `toggleReaderNightMode()`、`:2723-2726` `getPaperColor()`、`pages/ReaderPage.ets:1293`（底部动作条 `theme` 项）、`pages/ReaderSettingsPage.ets:360-362`（「背景」行月亮图标）、`data/ReaderSettingsRepository.ets:165`（`readerNightMode` 字段）。

> **重要修正**：任务书说「本地阅读页无日夜切换入口」，实测**有**，而且有两处。缺的不是入口，是**语义**——本地切的是阅读页私有的 `readerNightMode` 布尔，上游切的是全局 `themeMode` 三值网关。这两者的差别决定了下表大部分行的判定。

| 上游能力 | 上游位置 | 本地位置 | 状态 | 差异说明 | 验收方式 | 备注 | ZIP 类别 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| **D1** 阅读页「主题」sheet 的日夜切换按钮 | `ui/book/read/sheet/GlobalThemePage.kt:181-189` `SmallTonalButton(onClick = onToggleDayNight, icon = if (isNightTheme) Icons.Default.DarkMode else Icons.Default.LightMode, contentDescription = stringResource(R.string.theme_mode))`；同排 `:170-180` 是护眼按钮（长按开护眼 sheet） | `pages/ReaderPage.ets:1293` `else if (kind === 'theme') { this.onToggleNightMode(); }`（底部动作条 `theme` 项）；实现在 `pages/Index.ets:2062-2067` | 已接 | 入口位置不同（上游在 sheet 里、本地在底部动作条），但**都是阅读页一键切日夜**，都能在阅读中立即改变纸张颜色。图标语义也一致：亮色时显示月亮、深色时显示太阳（本地 `ReaderSettingsPage.ets:360-362` 的 `app_moon`/`app_daynight`） | 真机：阅读中点「主题」→ 纸张在深/浅之间切换 | 图标名 `app_daynight` 与上游 `Icons.Default.LightMode` 同义 | `themeMode` |
| **D2** 切换效果写入全局 `themeMode` | `ReadStyleDelegate.kt:455-470`：`val nextIsNight = !(ReadSessionState.isDarkThemeOverride ?: host.isNightTheme)` → `val nextMode = if (nextIsNight) "2" else "1"` → `appShellSettingsGateway.update { it.copy(themeMode = nextMode) }` | `pages/Index.ets:2062-2067` `toggleReaderNightMode()`：只翻转 `this.readerNightMode`、切 `paperIndex`、`persistReaderSettings()` | 未接 | 本地切换**不写 `themeMode`**，也不碰任何全局夜间模式。上游切换后会：① 改全局网关（退出阅读页后全 App 跟着变）② 置 `ReadSessionState.isDarkThemeOverride` ③ 清日夜提醒 ④ `readStyleGateway.notifyModeChanged()` ⑤ 派 `emitConfigUpdate(UpdateBackground, UpdateStyle)` | 真机：阅读页切深色 → 退出到书架，书架也是深色 | 这是 D 块的核心差异。本地实现是「阅读页私有偏好」，上游是「全局主题的快捷入口」 | `themeMode` |
| **D3** 日夜派生：三值 → 布尔 | `help/config/ReadStyleResolver.kt:27-32` `isNightThemeCompat = when (themeMode) { "1" -> false; "2" -> true; else -> sysConfiguration.isNightMode }`；`:57-59` `isNightTheme() = ReadSessionState.isDarkThemeOverride ?: isNightThemeCompat`；`domain/model/settings/AppUiConfiguration.kt:11-15` `isDarkTheme` 同构 | `pages/Index.ets:2723-2726` `getPaperColor()` 按 `this.readerNightMode` 二选一 `style.nightColor`/`style.dayColor` | 未接 | 本地没有「跟随系统」这一支：`readerNightMode` 是纯布尔（`ReaderSettingsRepository.ets:415` 默认 `true`），不存在「未选择、跟随系统」的第三态。上游三值里 `"0"` 走 `isSystemDarkTheme`，本地无从跟随 | 真机：`themeMode` 留「跟随系统」→ 系统切深色时阅读页自动变深 | 上游 `isDarkThemeOverride` 是「本次阅读页临时覆盖」，退出阅读页即失效；本地 `readerNightMode` 是持久偏好，语义正好相反 | `themeMode` |
| **D4** 主题列表页的日夜切换按钮 | `ui/book/read/sheet/ThemeListContent.kt:284-289` `SmallTonalButton(onClick = onToggleDayNight, icon = if (isNightTheme) Icons.Outlined.DarkMode else Icons.Outlined.LightMode)`；`:136` 形参 `onToggleDayNight`；`:869` `readStyleTextColor(config, isNightTheme)`、`:881 buildThemeKeys` | 无 | 不适用 | 本地**没有主题列表页**（`pages/` 34 个文件里无对应页面，阅读页也没有「主题列表」sheet），这个按钮所在界面整体未迁移 | 无 | 按「上游没有就不要、上游有本地整页没有则标不适用并写理由」处理；若将来迁移主题列表页，此按钮随页一起做 | `themeMode` |
| **D5** 阅读背景的日夜三套（日/夜/墨水屏） | `ReadStyleResolver.kt:37-41` `enum class ReadStyleMode { Day, Night, EInk }`、`:48-51 currentMode()`、`:61-109 withCurrentBackground/currentBackground/backgroundPath`（三套：`bgType/bgStr`、`bgTypeNight/bgStrNight`、`bgTypeEInk/bgStrEInk`）；墨水屏判定 `:34-35 appTheme == "4"` | `pages/Index.ets:2723-2726` + `READER_BACKGROUND_STYLES`（**只有 day/night 两套**，无墨水屏）；`ReaderPage.ets:2756` `const isNightPaper = this.paperColor === '#000000' \|\| this.paperColor === '#343832' \|\| this.paperColor === '#3C3F43'` | 未接 | 本地两套背景（日/夜）已能按 `readerNightMode` 选，但**没有第三套墨水屏背景**，也没有「按 `paperColor` 反推日夜」之外的模式判定。上游 `appTheme == "4"` 时整套换成墨水屏背景与配色 | 真机：选墨水屏主题 → 阅读页背景变墨水屏专用 | 本地墨水屏只有 `pages/AppLabSettingsPage.ets:8` 一个 lab 开关 + `:36` 文案「可在"主题 → 显示"中调整墨水屏设置」，无实际渲染。`isNightPaper` 用三个色值反推日夜，是本地特有的补丁写法，上游用模式枚举 | `themeConfig` |
| **D6** 阅读页纸张在日夜之间的记忆 | `ReadStyleResolver.kt:73-93 currentBackground`（按当前 mode 取对应 `bgStr`/`bgStrNight`）；切换时 `ReadBookController.kt:1762-1790 onAppThemeChanged(isDarkTheme)` 派 `ReaderThemeColorChange(oldBodyArgb, newBodyArgb, oldTitleArgb, newTitleArgb, ...)` | `pages/Index.ets:2062-2067`（切 `paperIndex` 到 `nightPaperIndex`/`dayPaperIndex`）+ `:2052-2060 setReaderShareLayout`（`shareReaderStyleLayout` 时日夜共用背景索引） | 已接 | 本地两套背景索引各自记忆，切日夜时来回切的是同一对索引；`shareReaderStyleLayout` 打开后日夜共用一套背景。这与上游「日/夜各有一套 bgStr」等价 | 真机：日间选背景 2、夜间选背景 5 → 来回切日夜时各自回到自己那套 | 本地比上游多一个「日夜共用背景」开关（上游无此概念），属本地额外能力，不构成缺口 | `themeMode` |
| **D7** 阅读页快速按钮的提醒冷却与去重 | `ReadStyleDelegate.kt:451-482` `toggleDayNight()` 内：`lastSwitchDayNightReminderTime = System.currentTimeMillis()`、`resetDayNightReminderDismissal()`、清 `activeReminder` 里的 `DayNightReminder`、`reminderQueue.removeAll { it.type is ReminderType.DayNightReminder }` | 无 | 未接 | 本地没有提醒机制，所以也不需要冷却（E 块整块未接）。这一行是为了记录「切换动作与提醒的耦合」：上游手动切日夜会顺手清掉待弹的提醒 | 无 | 与 E 块同源，E 块接上后必须同时补这一支，否则切完日夜还会弹出「要不要切日夜」 | `themeMode` |
| **D8** 阅读页菜单的日夜配色 | `ui/book/read/ReadBookColorTheme.kt`（读 `isDarkTheme`/`isNightTheme`/`materialVersion`/`paletteStyle` 算菜单配色）、`ui/book/read/ReadBookMenuBarShared.kt`（`isNightTheme`）、`ui/book/read/sheet/SystemMenuPage.kt`（`paletteStyle`） | `pages/ReaderPage.ets` 菜单配色为固定深色字面量；本地另有 `readMenuColorMode`/`menuColorMode`（8 处，属菜单形态而非主题） | 未接 | 本地阅读菜单的颜色不随日夜变，全用写死深色。上游菜单配色由 `isNightTheme` + `paletteStyle` 共同算出 | 真机：切到浅色阅读 → 菜单变浅底深字 | `menuColorMode` 是「菜单是浮层还是内嵌」的形态开关，与主题无关，不要误当已接 | `themeMode` |

## E 日夜提醒

上游主体：`constant/PreferKey.kt:120`（`autoSuggestDayNight`）、`ui/book/read/ReadStyleDelegate.kt:489-576`（`resetDayNightReminderDismissal`/`isDayNightSwitchCoolingDown`/`checkSwitchDayNight`/阈值常量）、`ui/book/read/ReadBookRouteScreen.kt:1088-1130`（`AutoSuggestDayNightObserver`，环境光传感器）、`ui/book/read/ReadBookContract.kt:46`（`DayNightReminder`）、`ui/book/read/ReadBookFloatingActionBar.kt:121-133`（提醒胶囊）、`ui/config/readConfig/ReadConfigScreen.kt:337-344` 与 `ui/book/read/sheet/MoreConfigSheet.kt:399-404`（两个开关入口）。
本地主体：`pages/ReaderSettingsPage.ets:898` 一个恒 `false` 的开关壳。本地全仓 `autoSuggestDayNight|DayNight|dayNight` **零命中**。

| 上游能力 | 上游位置 | 本地位置 | 状态 | 差异说明 | 验收方式 | 备注 | ZIP 类别 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| **E1** 「自动切换日夜模式提醒」开关（阅读设置页） | `ui/config/readConfig/ReadConfigScreen.kt:337-344` `SwitchSettingItem(title = auto_switch_theme_reminder_title, description = auto_switch_theme_reminder_desc, checked = settings.autoSuggestDayNight, onCheckedChange = { onIntent(ReadConfigIntent.AutoSuggestDayNightChanged(it)) })`；写 `data/repository/ReadSettingsRepository.kt:140 setAutoSuggestDayNight` | `pages/ReaderSettingsPage.ets:898` `MenuSettingSwitch({ title: '自动切换日夜模式提醒', detail: '提示切换阅读背景', checked: false }).onClick(() => this.showNotMigrated('自动切换日夜模式提醒'))` | 未接 | 本地有这一行、文案也接近，但 `checked` **恒为 `false` 字面量**、点击走 `showNotMigrated`（`:1274-1276` 打开 sheet 写「此选项的原版 UI 已呈现；实际设置逻辑尚未迁移。」）。上游是真的布尔设置项，改动即写 `autoSuggestDayNight` 键 | 真机：打开开关 → 杀进程重进仍是打开 | 本地无 `autoSuggestDayNight` 键、无持久化字段（`ReaderSettingsRepository.ets` 里没有这个名字） | `themeConfig` |
| **E2** 阅读页「更多设置」里的同一开关 | `ui/book/read/sheet/MoreConfigSheet.kt:399-404` `TinySwitchSettingItem(同两资源, checked = preferences.autoSuggestDayNight, onCheckedChange = onAutoSuggestDayNightChange)` | 无 | 未接 | 本地阅读页没有「更多设置」sheet 里的这一项 | 真机：阅读中打开更多设置 → 能开关提醒 | 上游两处入口改的是同一个键，实现时不要做成两份状态 | `themeConfig` |
| **E3** 环境光传感器采样 | `ui/book/read/ReadBookRouteScreen.kt:1088-1130` `AutoSuggestDayNightObserver(viewModel, autoSuggestDayNight, lifecycleOwner)`：`LaunchedEffect(autoSuggestDayNight) { if (!autoSuggestDayNight) return@LaunchedEffect; lifecycleOwner.repeatOnLifecycle(RESUMED) { 取 TYPE_LIGHT 传感器，registerListener 1 秒，finalLux → viewModel.onIntent(ReadBookIntent.CheckSwitchDayNight(lux)) } }` | 无 | 未接 | 本地无环境光采样。`entry/src/main/ets` 里唯一的传感器引用是 `data/ReaderHaptics.ets:1` 的 `vibrator`（震动），与光线无关 | 真机：打开开关后在暗处停留 → 弹出切换提示 | 上游用 `repeatOnLifecycle(RESUMED)` 保证只在阅读页前台采样 1 秒，这个生命周期约束要照抄，否则会后台常驻耗电 | `themeConfig` |
| **E4** 亮度阈值判定 | `ReadStyleDelegate.kt:500-560 checkSwitchDayNight(lux: Float)`：`!isNight && lux <= DARK_LUX_THRESHOLD`（`:633` = `8f`）→ 建议切深色；`isNight && lux >= BRIGHT_LUX_THRESHOLD`（`:634` = `100f`）→ 建议切浅色。另有 `isLightBg` 判定（按 `styleConfig.bgType`：0 取 `bgStr.toColorInt()` 默认 `0xFFEEEEEE`，否则取 `ReadSessionState.backgroundMeanColor`），只有背景确实偏亮/偏暗才提醒 | 无 | 未接 | 本地无阈值、无背景亮度判定。上游的 `isLightBg` 这一层是关键：用户已经把阅读背景设成深色时，暗环境下不该再提醒「切深色」 | 真机：背景已深色时在暗处 → **不**弹提示 | 三个常量都要照抄：`DARK_LUX_THRESHOLD = 8f`、`BRIGHT_LUX_THRESHOLD = 100f`、`REMINDER_COOLDOWN_MS = 10 * 60 * 1000L`（`:636`） | `themeConfig` |
| **E5** 提醒冷却与去重 | `ReadStyleDelegate.kt:493-494 isDayNightSwitchCoolingDown()`（`now - lastSwitchDayNightReminderTime < REMINDER_COOLDOWN_MS`）；`:68` `lastSwitchDayNightReminderTime`；`:70-71` `hasDismissedDarkReminder`/`hasDismissedLightReminder`；`:489-491 resetDayNightReminderDismissal()`；`:574-576` 用户点掉后置对应 `hasDismissed*` | 无 | 未接 | 本地无冷却、无「点掉后不再弹」状态。上游两条防骚扰：10 分钟冷却 + 用户明确拒绝后本轮不再弹 | 真机：连点两次切换 → 10 分钟内不再弹提示 | `resetDayNightReminderDismissal()` 在手动切日夜（D7）与改设置（`ReadConfigUpdateDelegate.kt:53`）时都会调 | `themeConfig` |
| **E6** 提醒胶囊 UI | `ui/book/read/ReadBookContract.kt:46 data class DayNightReminder(val targetIsNight: Boolean) : ReminderType`；`ui/book/read/ReadBookFloatingActionBar.kt:121-133 ThemeReminderCapsule`：`val isDark = (reminder.type as? ReminderType.DayNightReminder)?.targetIsNight == true`、actionText 取 `switch_to_dark_mode_action`/`switch_to_light_mode_action`、`LaunchedEffect(reminder.id) { delay(5.seconds); onIntent(ReadBookIntent.DismissReminder) }` | 无 | 未接 | 本地阅读页没有提醒胶囊层。上游胶囊 5 秒自动消失，点击执行 `ReadBookIntent.ToggleDayNight`（即 D1 同一个动作） | 真机：暗处停留 → 底部浮出「切换到深色模式」胶囊，5 秒后消失 | 胶囊的 action 复用 D1，所以 E 接上后 D 必须已经能改网关，否则点了没效果 | `themeConfig` |
| **E7** 提醒的 intent/effect 链路 | `ReadBookContract.kt:588 data class CheckSwitchDayNight(val lux: Float) : ReadBookIntent`、`:851 data object ToggleDayNight : ReadBookIntent`、`:1271 data object ToggleDayNight : ReadBookEffect`（`ReadBookController.kt:2563-2565` 注明「Handled directly by ViewModel — effect not currently emitted」）、`:2036 data class AutoSuggestDayNight(val value: Boolean) : ConfigUpdate`；分发 `ReadBookViewModel.kt:771`/`:1494`/`:413-414`；设置联动 `ReadConfigUpdateDelegate.kt:684-689` | 无 | 未接 | 本地阅读页用 `@Prop` 回调直连（`onToggleNightMode`），没有 intent/effect 分层。上游这里有一条「`ToggleDayNight` 既走 intent 也定义成 effect 但 effect 从不发出」的历史包袱，实现时不要照抄这层冗余 | 无 | `AutoSuggestDayNight` 作为 `ConfigUpdate` 会触发 `host.resetDayNightReminderDismissal()`——改设置就重置拒绝状态 | `themeConfig` |

## F 网关与全局换肤

上游主体：`domain/model/settings/AppShellSettings.kt:4`（`themeMode: String = "0"`）、`domain/model/settings/AppUiConfiguration.kt:11-15`（`isDarkTheme` 派生）、`help/config/ThemeConfigStore.kt:70-89`（`applyDayNightLive`/`applyDayNightInit`/`initNightMode` → `AppCompatDelegate.setDefaultNightMode`）、`help/storage/Backup.kt:241-246`（`themeConfig.json` 导出）、`help/storage/BackupConfig.kt:413-475`（两个忽略开关 + 门控）。
本地主体：`data/BackupRepository.ets`（`themeMode` 键组 `:310`、`themeConfig` 53 键组 `:261-277`、`categoryOptions:324-333`、`preferenceKeysForCategory:386-396`、`filterAndroidConfigXml:1620-1646`、`applyEyeProtection:1062-1084`）、`pages/Index.ets:1649-1670`、`entry/src/main/resources/base/element/color.json`。

| 上游能力 | 上游位置 | 本地位置 | 状态 | 差异说明 | 验收方式 | 备注 | ZIP 类别 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| **F1** `themeMode` 全局网关（唯一日夜来源） | `constant/PreferKey.kt:9 const val themeMode = "themeMode"`；`domain/model/settings/AppShellSettings.kt:4 val themeMode: String = "0"`；`App.kt:194-203` 注释「themeMode 是日夜的唯一来源，除外观设置外（阅读页快捷按钮、主题包、恢复备份）也会直接写网关。AppCompat 的夜间模式统一跟随网关」 | 无全局网关。`themeMode` 全仓只出现在 4 处备份代码（`data/BackupRepository.ets:217/:310/:327/:392`）+ 向导链路（`OnboardingRepository.ets`/`OnboardingPage.ets`/`Index.ets`），**没有一处把它当全局状态用** | 未接 | 本地没有任何模块读取 `themeMode` 来决定配色。上游 `App.kt` 那句注释点明了「唯一来源 + 三个写入方」，本地连来源都没有 | 真机：任何地方改 `themeMode` → 全 App 配色跟着变 | 这是 A1/C1/D2 三处「点了没效果」的共同根因 | `themeMode` |
| **F2** `isDarkTheme` 派生（三值 + 跟随系统） | `domain/model/settings/AppUiConfiguration.kt:11-15` `isDarkTheme = when (themeMode) { "1" -> false; "2" -> true; else -> isSystemDarkTheme }`；`data/repository/AppUiConfigurationRepository.kt` 提供 `isDarkTheme`/`isSystemDarkTheme`；`domain/gateway/AppUiConfigurationGateway.kt` 暴露 | 无 | 未接 | 本地既无 `isDarkTheme` 也无 `isSystemDarkTheme`。系统深色状态都没读（HarmonyOS 侧可用 `Configuration.colorMode`，全仓 `colorMode` 8 处命中全是阅读菜单的 `readMenuColorMode`，与系统色模式无关） | 真机：`themeMode` = 跟随系统 → 系统切深色时全 App 变深 | 「跟随系统」这一支的实现成本被低估过：本地连系统色模式监听都没有 | `themeMode` |
| **F3** 应用夜间模式到 AppCompat | `help/config/ThemeConfigStore.kt:70-89`：`applyDayNightLive()`、`applyDayNightInit(context)`、`initNightMode()` 把 `"1"/"2"/else` 映射为 `MODE_NIGHT_NO`/`MODE_NIGHT_YES`/`MODE_NIGHT_FOLLOW_SYSTEM`，调 `AppCompatDelegate.setDefaultNightMode(mode)` | 无 | 未接 | ArkUI 无 `AppCompatDelegate` 等价物，本地必须走「资源目录 + 全局状态驱动重建」路线。这条差异不是「没接」，而是**平台机制不同**——照抄上游写法不可能实现 | 无（需先定方案） | 上游这套是 Android 平台能力；本地对应物是 `entry/src/main/resources/dark/` + `colorMode` 监听，两者都还没有 | `themeMode` |
| **F4** 浅色/深色两套颜色资源 | 上游 `app/src/main/res/values/colors.xml` + `values-night/colors.xml` 成对提供，全项目颜色都走 `R.color.*` / Material colorScheme | `entry/src/main/resources/` 只有 `base/` 与 `rawfile/`，**无 `dark/`**；`base/element/color.json` 只有 1 个颜色 `start_window_background = #F6F4F0`；全仓 `$r('app.color.*')` 引用 **0 处**；2252 处颜色字面量全部内联在 `.ets` 里 | 未接 | 这是本表最大的一行。上游换肤靠资源目录，本地要换肤**必须先把 2252 处内联字面量抽成颜色资源**，否则无论 `themeMode` 怎么接，界面都不会变。抽完还要建 `dark/element/color.json` 提供第二套值 | 真机：系统切深色 → 任意页面配色变化 | 建议先抽「高频 8 色」（`#D8D9E0`/`#AFC2FF`/`#92949E`/`#E3E4E8`/`#1C1D23`/`#111217`/`#1A1B21`/`#1B1C22`，合计 916 处）再逐页推进 | `themeConfig` |
| **F5** `themeConfig.json` 导出（主题配置随备份走） | `help/storage/Backup.kt:241-246` `if (!BackupConfig.backupIgnoreThemeConfig) { GSON.toJson(ThemeConfigStore.configList) → ThemeConfigStore.configFileName }`；`help/config/ThemeConfigStore.kt:308` 行含 `configFileName` | `data/BackupRepository.ets:321` 归档清单里有 `'themeConfig.json'`、`:328` `categoryOptions` 里 `files: ['themeConfig.json', 'config.xml']`，但 **`createBackup`（`:420-`）没有任何写 `themeConfig.json` 的分支** | 未接 | 本地只在「清单」里承认这个文件，实际从不生成它；备份包里永远不会有 `themeConfig.json`。恢复侧 `copyPreservedEntries`（`:1583-1609`）对非 `config.xml` 条目是原样 `copyFile`，所以从 Android 迁来的 `themeConfig.json` 会被搬运但**无人解析**（`grep themeConfig.json` 全仓只有 `:321`/`:328` 两处） | 真机：改一套配色 → 备份 → 解压看得到 `themeConfig.json` 且内容含 53 键 | 「写」侧的缺口。README-CONFIG.md F 块那 7 行盘的是「护眼 6 键」，不含整个 JSON | `themeConfig` |
| **F6** `themeConfig` 53 键的备份键组 | `help/storage/BackupConfig.kt:263-317 themePrefKeys`（53 个 `PreferKey.*`） | `data/BackupRepository.ets:261-277` `themeConfig` 键组 53 键，与上游 `themePrefKeys` 的**真实字符串值**逐个比对完全一致（双向差集皆空） | 已接 | 键组本身完整、键名逐字对上。但「键组对」只影响「恢复时哪些键算被忽略类别的成员」，不等于能写出/读回（见 F5、F7） | 无（静态比对已通过） | 这也是本轮关键词改造的副产品：把 53 个常量名换成真实字符串值去检索，接触面才从 3 涨到 132 | `themeConfig` |
| **F7** `themeConfig` 的 6 个护眼键双向落盘 | `help/storage/BackupConfig.kt:263-317` 含 `eyeProtectionEnabled`/`colorTemperature`/`eyeProtectionAutoNight`/`eyeProtectionSchedule`/`eyeProtectionStartTime`/`eyeProtectionEndTime`；渲染 `ui/book/read/EyeProtection.kt` | `data/BackupRepository.ets:571-587` `createBackup` 的 themeConfig 分支只写这 6 个键（`:580-581` 由 `settings.eyeProtectionIntensity` 取整 0..100 写 `colorTemperature`）；`:1062-1084` `applyEyeProtection` 恢复时读回 6 键到 `ReaderSettingsSnapshot`，并按 `ignoredCategories.includes('themeConfig')` 早退 | 未接 | 备份侧 6 键**确实双向通**（这也是 [阅读配置总账](READER-CONFIG.md) F 块判「已接」的那部分）。但**功能侧不通**：读回来的 6 个值只进了 `ReaderSettingsSnapshot`，而本地护眼没有渲染（见 A24–A29）。按「盘点单位是界面」的口径，键通了而界面没效果，这一行仍是 `未接` | 真机：Android 备份 → 本地恢复 → 打开护眼确实变暖 | 与 READER-CONFIG.md F 块不矛盾：那边盘的是「阅读设置页那套状态」，本表盘的是「主题设置页 + 实际渲染」 | `themeConfig` |
| **F8** 墨水屏主题（`appTheme == "4"`） | `help/config/AppConfig.kt:76`、`base/BasePrefDialogFragment.kt:16`、`lib/prefs/EditTextPreferenceDialog.kt:45`、`ListPreferenceDialog.kt:48`、`MultiSelectListPreferenceDialog.kt:50`、`ui/book/read/ReadBookRouteScreen.kt:202`、`ui/book/searchContent/SearchContentViewModel.kt:92`、`feature/reader/legacy/LegacyReaderPaginationStyleFactory.kt:31`；`ReadStyleResolver.kt:34-35` 派生 `isEInkModeCompat` | `pages/AppLabSettingsPage.ets:8` `@State eInkEnabled`、`:34` `LabSettingsSwitch('墨水屏显示')`、`:35-36` 文案「可在"主题 → 显示"中调整墨水屏设置」 | 不适用 | 上游的墨水屏是**主题的一种**（`appTheme` 取 `"4"`），会同时改全局配色与阅读页第三套背景。本地只有一个 lab 里的布尔开关，且**文案指向的「主题 → 显示」页面里根本没有这一项**（`ThemeSettingsPage.ets` 全页无墨水屏条目）。按「上游有、本地整页缺失」通常应判 `未接`，但本地把它归到 lab（实验功能）而非主题，属**产品定位不同**，故判不适用并留此说明 | 无 | 若将来要做，它落在 A2（主题选择）与 D5（三套背景）两处，不单独成项 | `themeConfig` |
| **F9** `themeMode` 的备份忽略开关 | `help/storage/BackupConfig.kt:145-155 ignoreKeys` 与 `:171-181 backupIgnoreKeys` 都直接列 `PreferKey.themeMode`；getter `:443-444 ignoreThemeMode = ignoreConfig[PreferKey.themeMode] == true`、`:462-463 backupIgnoreThemeMode`；门控 `:422 PreferKey.themeMode == key && backupIgnoreThemeMode -> false`、`:434` 同构 | `data/BackupRepository.ets:324-333` `categoryOptions` 里有 `:327 { key: 'themeMode', title: '主题模式', files: ['config.xml'], preferenceKeys: ...themeMode }`，`:386-396` `preferenceKeysForCategory('themeMode')` 返回 `['themeMode']` | 未接 | 本地有「类别条目」但**没有真正的写出/读回分支**：`createBackup` 的 `config.xml` 写出清单（`:474-482` 书架布局 9 键、`:520-563` 阅读外观与护眼）**不含 `themeMode`**。恢复侧 `filterAndroidConfigXml`（`:1620-1646`）是「剔除被忽略类别的键、其余原样保留」，所以从 Android 迁来的 `themeMode` 会原样躺在归档里，但**不进本地功能**——写了不用、读了不认 | 真机：本地备份 → 解压 `config.xml` 里有 `<string name="themeMode">2</string>` | 忽略开关本身（`isIgnored`）本地有等价物，但作用于「恢复时剔键」，不作用于「创建时写键」，方向与上游相反 | `themeMode` |
| **F10** 类别显示名「深色模式」 | `app/src/main/res/values-zh-rCN/strings.xml:660` `theme_mode` 的中文是「**深色模式**」；`arrays.xml:36-40` `theme_mode` = 跟随系统 / 亮色主题 / 暗色主题 | `data/BackupRepository.ets:327` 原为 `title: '主题模式'`，本轮已改为 `'深色模式'` | 已接 | 本轮之前文案与上游不一致（上游叫「深色模式」，本地叫「主题模式」）；改完与上游 `strings.xml:660` 逐字一致。注：这里只对齐显示名，该类别本身仍无读写分支（见 F9） | 真机：备份类别列表显示「深色模式」 | 这是本轮唯一的代码改动，只改文案，不动逻辑 | `themeMode` |
| **F11** 备份忽略开关的界面 | `ui/config/backupConfig/BackupConfigScreen.kt`（各 `backupIgnore*` 开关的 UI） | `pages/AppBackupSettingsPage.ets`（本地备份设置页） | 未接 | 本地备份设置页的类别开关作用于 `categoryOptions`，但 `themeMode` 与 `themeConfig` 都没有可切换的实际效果（F9 的写出分支不存在） | 真机：关掉「深色模式」类别 → 备份里不含该键 | 该页在 [书籍总账](BOOKSHELF.md) E 块盘过；这里只记与 themeMode/themeConfig 相关的部分 | `themeMode` |
| **F12** 恢复时的 `config.xml` 键过滤 | `help/storage/BackupConfig.kt:413-439 keyIsNotIgnore(key, isBackup)` 两套分支（`ignore*` 与 `backupIgnore*`） | `data/BackupRepository.ets:1620-1646 filterAndroidConfigXml`：`excludedKeys = alwaysIgnoredPreferenceKeys` + 每个被忽略类别的 `preferenceKeysForCategory` 键，正则 `/<(string\|int\|long\|float\|boolean\|set)\b[^>]*\bname=["']([^"']+)["'][^>]*(?:\/>\|>[\s\S]*?<\/\1>)/gi` | 未接 | 过滤机制存在且能剔除忽略类别的键，但**没有「主题配置被忽略 → 连护眼 6 键一起不恢复」之外的主题语义**，也没有上游那种「按 key 逐个判」的细粒度（本地是按类别整体剔除）。`themeConfig` 被忽略时 `applyEyeProtection`（`:1062-1084`）会早退，这条是对的 | 真机：忽略 themeConfig → 恢复后护眼设置不变 | 正则里的 `\|` 是文档转义，实际代码里是竖线 | `themeConfig` |

## 四、覆盖证明

判据按 [编码规约](../CODE-CONVENTIONS.md) 第四节：上游接触面的**每一个 `.kt` 文件**都必须被显式分配到「已映射到某行」或「已排除 + 理由」，未分配必须为 0。

```bash
bash scripts/upstream-surface.sh --coverage themeMode docs/parity/ZIP-THEME.md <上游根>
bash scripts/upstream-surface.sh --coverage themeConfig docs/parity/ZIP-THEME.md <上游根>
```

实跑（2026-10-31）：

- `themeMode`：上游接触面 **80** 个 `.kt`，已分配 80，未分配 **0**
- `themeConfig`：上游接触面 **132** 个 `.kt`，已分配 132，未分配 **0**
- 两类并集 **173** 个（交集 39），本表逐个分配：**映射到某行 157 个 / 已排除 16 个 / 未分配 0 个**（157 + 16 = 173）

`SURFACE_DIR_WHITELIST` 本类别**未新增**条目：两个类别的关键词已经能捞到全部界面文件，没有「只画颜色和动画、关键词永远捞不到」的文件。

### 接触面是怎么从 32/3 涨到 80/132 的（逐轮增量清单）

这一步必须先做。旧关键词下接触面只有 `themeMode` 32 个、`themeConfig` 3 个文件——**阅读页日夜换肤的那批核心文件一个都不在里面**（`ReadBookController.kt` 3355 行、`ReadBookViewModel.kt` 2749 行、`BaseReadAloudService.kt` 2149 行、`ReadBookRouteScreen.kt` 1181 行全部缺席），照着旧接触面盘点，结论必然是「themeMode 只在备份里出现过 4 次」，与事实相反。

**`themeMode`：32 → 80，七轮**

| 轮 | 追加的词 | 命中 | 增量 | 新增文件（及之前为什么漏） |
| --- | --- | --- | --- | --- |
| 1 | `themeMode`、`"themeMode"` | 32 | 基线 | 只有直接写这个键名的文件。**漏因**：上游大量代码不写 `themeMode` 而写它的派生值 `isDarkTheme`/`isNightTheme` |
| 2 | `isNightMode`、`isDarkTheme`、`isSystemDarkTheme`、`setDefaultNightMode`、`NIGHT_MASK` | 46 | +14 | `BaseComposeActivity.kt`、`AppUiConfigurationRepository.kt`、`appModule.kt`、`AppUiConfigurationGateway.kt`、`ReadSessionState.kt`、`BaseReadAloudService.kt`、`ReadBookColorTheme.kt`、`ReadBookController.kt`、`ReadBookRouteScreen.kt`、`ReadBookViewModel.kt`、`BgEffectBackground.kt`、`TinySettingItems.kt`、`ConfigurationExtensions.kt`、`WebSettingsExtensions.kt`。**漏因**：这些文件只消费派生布尔，从不提原始键名——正是「按类别名检索不到的位置」 |
| 3 | `DayNight` | 67 | +21 | `ReadSettingsRepository.kt`、`ReadSettings.kt`、`OnboardingRouteScreen.kt`、`Restore.kt`、`ThemeModePreference.kt`、`ReadBookContract.kt`、`ReadBookFloatingActionBar.kt`、`ReadBookMenuBar.kt`、`ReadConfigUpdateDelegate.kt`、`ReadMenuActionDefs.kt`、`GlobalThemePage.kt`、`MoreConfigSheet.kt`、`ReadStyleSheet.kt`、`ThemeListContent.kt`、`ReadConfigContract.kt`、`ReadConfigScreen.kt`、`ReadConfigViewModel.kt`、`ThemeConfigContract.kt`、`ThemeConfigRouteScreen.kt`、`RssReadRouteScreen.kt`、`RssReadWebController.kt`。**漏因**：日夜提醒（E 块）与日夜切换按钮（D 块）整条链路的命名都以 `DayNight` 为核心词，与 `themeMode` 无字面交集 |
| 4 | `isNightTheme` | 71 | +4 | `ReadBookConfig.kt`、`CastCapsuleStyleStore.kt`、`PreferenceCategory.kt`、`ReadBookMenuBarShared.kt`。**漏因**：这是 `ReadStyleResolver` 的对外派生名，写在第 3 层 |
| 5 | `uiMode`、`UI_MODE` | 74 | +3 | `ThemeStore.kt`、`ThemeComponents.kt`、`ContextExtensions.kt`。**漏因**：系统侧色模式（`Configuration.uiMode`）是「跟随系统」那一支的落点 |
| 6 | `isAmoled`、`amoled` | 78 | +4 | `CustomColorScheme.kt`、`OpaqueColorScheme.kt`、`ThemeEngine.kt`、`ThemeOverride.kt`。**漏因**：纯黑深色模式（A4）在上游叫 AMOLED，代码里不出现 `pureBlack` |
| 7 | `isPureBlack`、`pureBlack` | 80 | +2 | `ThemeSettings.kt`、`ThemeManageScreen.kt`。**漏因**：纯黑开关的键名是 `isPureBlack`，与 A4 界面标题「纯黑深色模式」不同字 |

试过但**不采纳**的两轮：`+isLight|lightTheme|LightTheme` 到 85（5 个新增全是注释或弱相关）、`+Night` 到 109（把 `nightMode`/`GoodNight` 之类全拖进来，接触面失去判别力）。并集每轮为 142 / 152 / 168 / 171 / 172 / 173 / 173。

**`themeConfig`：3 → 132，一轮**

| 轮 | 追加的词 | 命中 | 说明 |
| --- | --- | --- | --- |
| 1 | `backupIgnoreThemeConfig`、`"themeConfig"` | 3 | 只捞到 `help/storage/Backup.kt`、`help/storage/BackupConfig.kt`、`ui/config/ConfigTag.kt`——**存储层的三个文件**，界面层一个没有 |
| 2 | 53 个键的**真实字符串值**（`colorMD3Primary`、`backgroundImageNight`、`colorMD3OnSurface`……） | 132 | +129。**这是本类别最关键的一条经验**：`themeConfig` 的 53 个键在上游 `BackupConfig.kt:263-317` 里写的是**常量名**（`cPrimary`、`bgImageN`、`primaryTextColor`），真正落盘的**字符串值**完全不同（`colorPrimary`、`backgroundImageNight`、`colorMD3OnSurface`）。按常量名检索只能找到定义处，界面代码里一个都搜不到 |

53 个键里 **22 个常量名 ≠ 字符串值**（`cPrimary=colorPrimary`、`bgImageN=backgroundImageNight`、`primaryTextColor=colorMD3OnSurface`、`labelContainerColor=colorMD3SurfaceContainerLow` 等），**31 个同名**（`paletteStyle`、`enableBlur`、`eyeProtectionEnabled` 等）。后者必须靠词边界或人工判读控制噪声，前者是本轮增量的主要来源。

> **保留旧词的理由**：`help/storage/Backup.kt`（`:241` `if (!BackupConfig.backupIgnoreThemeConfig)`——`themeConfig.json` 的唯一导出点）与 `ui/config/ConfigTag.kt`（`:6 const val THEME_CONFIG = "themeConfig"`）在改用 53 键真实值后**不在命中集里**，所以新关键词必须同时保留 `backupIgnoreThemeConfig|"themeConfig"`，否则会丢掉导出逻辑本身——这正是规约里 r294 那个「导出主文件一个实体类名都不出现」的同类陷阱。

**词边界取舍**：`themeConfig` 无边界 132 / 加 `-w` 130。差的 2 个是 `lib/prefs/ColorPreference.kt`（`material.R.attr.colorPrimaryContainer` 子串误命中）与 `ui/config/themeConfig/ThemeConfigRouteScreen.kt`（`backgroundImageLauncher`，本身属本类别）。**决定用无边界 132**，把 `ColorPreference.kt` 归「已排除」——用 130 会为了躲一个误命中而丢掉一个真文件。

### 4.1 映射到既有行（157 个）

#### 主题设置页与其渲染端（A 块）

| 上游文件 | 命中的符号 | 映射到本表哪一行 |
| --- | --- | --- |
| ThemeConfigScreen.kt | 全部 53 键 + themeMode/isDarkTheme/isPureBlack/isAmoled/composeEngine/useMiuixMonet/colorTemperature/eyeProtection* | A1–A47（主界面本身） |
| ThemeConfig.kt | backgroundImage backgroundImageBlurring containerOpacity customMode enableBlur isPureBlack materialVersion paletteStyle setDefaultNightMode themeMode | A1 A2 A4 A7 A13 A17 A35（配置门面） |
| ThemeConfigContract.kt | DayNight + 全部 `ThemeConfigIntent`/`Sheet`/`Dialog` 定义 | A1–A47（intent 层） |
| ThemeConfigViewModel.kt | DayNight backgroundImage composeEngine containerOpacity enableBlur enableProgressiveBlur eyeProtection* themeMode useMiuixMonet | A1–A47（状态层） |
| ThemeConfigRouteScreen.kt | DayNight backgroundImage | A5 A8 A13（`fontFolderLauncher`/`navigationIconLauncher`/背景图选择器承接） |
| TopBottomBarSettingsSheet.kt | bottomBarBlurAlpha bottomBarBlurRadius bottomBarLensRadius bottomBarOpacity enableBlur mergeTopBarActions topBarBlurAlpha topBarBlurRadius topBarButtonStyle topBarOpacity useFlexibleTopAppBar | A17 |
| CustomThemeContract.kt | customContrast enableDeepPersonalization materialVersion paletteStyle | A6 |
| CustomThemeScreen.kt | 同上 | A6 |
| CustomThemeViewModel.kt | 同上 | A6 |
| AppBackground.kt | backgroundImage backgroundImageBlurring | A13（`AppBackground.kt:22-29` 按日夜选图） |
| BgEffectBackground.kt | isDarkTheme | A13（背景图渲染端） |
| AppContainerBackground.kt | backgroundImage | A13（`:35` 形参、`:57` 消费） |
| AppScaffold.kt | backgroundImage backgroundImageBlurring composeEngine enableBlur enableProgressiveBlur topBarButtonStyle | A13 A17 A30（顶栏/背景/模糊渲染端） |
| SplicedColumnGroup.kt | composeEngine | A36（设置分组圆角） |
| AppAlertDialog.kt | composeEngine | A47 B1 B7 B10（三个确认框） |
| ClickableSettingItem.kt | composeEngine | A5 A8 A12 A13 A14 A17 A33 A34 A46 A47（点开型条目） |
| SwitchSettingItem.kt | composeEngine | A4 A9 A10 A15 A16 A20 A23 A24 A25 A27 A30 A31 A32 A36 A37 A39 A43（开关型条目） |
| SliderSettingItem.kt | composeEngine | A11 A26 A35 A38 A40 A44 A45（滑条型条目） |
| ListSettingItem.kt | composeEngine | A1（Miuix 下拉）A18 A19 A21 A22 |
| CompactSettingItems.kt | composeEngine | B8（EditThemeSheet 的 4 个 CompactDropdown） |
| InputSettingItem.kt | composeEngine | A5（字体路径输入） |
| TinySettingItems.kt | isNightMode | E2（`TinySwitchSettingItem`，`MoreConfigSheet` 用的就是它） |
| GlassCard.kt | containerOpacity | A35（容器不透明度渲染端） |
| PillDivider.kt | composeEngine | A46（分隔线渲染端） |
| RestoreConfigNormalizer.kt | bookInfoBackgroundBlur bookInfoDefaultCoverBackground bookInfoNetworkCoverBackground | A20 A21 A22（恢复时规范化 book_info 三键） |
| BookInfoContract.kt | bookInfoDefaultCoverBackground bookInfoFollowCoverColor bookInfoNetworkCoverBackground | A20 A21 A22 |
| BookInfoScreen.kt | 同上 + composeEngine | A20 A21 A22（渲染端） |
| BookInfoViewModel.kt | 上述 + bookInfoAuthorSearchFallback | A20 A21 A22 A23 |
| ThemeCardPreference.kt | backgroundImage colorPrimary containerOpacity | A2 A13（旧版主题卡片偏好） |
| ThemeModePreference.kt | DayNight | A1（`themeMode` 的 ListPreference 旧界面） |
| MainViewModel.kt | enableDeepPersonalization | A6（`:125` `deepPersonalizationActive = theme.appTheme == "12" && theme.enableDeepPersonalization`） |

#### 主题包管理（B 块）

| 上游文件 | 命中的符号 | 映射到本表哪一行 |
| --- | --- | --- |
| ThemeManageScreen.kt | enableDeepPersonalization isPureBlack | B1–B12（主界面本身） |
| EditThemeSheet.kt | bottomBarBlurAlpha bottomBarBlurRadius bottomBarOpacity containerOpacity customContrast enableBlur enableDeepPersonalization isPureBlack materialVersion paletteStyle themeMode topBarBlurAlpha topBarBlurRadius topBarOpacity useFlexibleTopAppBar | B8（主题编辑器，日/夜各 6 色） |
| ThemePackageManager.kt | setDefaultNightMode themeMode | B1–B12（保存/导入/导出/资产打包全在此） |
| ThemeImportExport.kt | `"themeMode"` bottomBar* composeEngine containerOpacity customContrast customMode enableBlur enableDeepPersonalization enableProgressiveBlur isPureBlack materialVersion paletteStyle themeMode topBar* useFlexibleTopAppBar useMiuixMonet | B2 B3 B4 B11 |
| ThemeExportData.kt | 全部 53 键 | B1 B11（导出快照模型） |
| ThemePackageSettingsRepository.kt | 全部 53 键 | B1–B12（主题包的持久化后端） |
| FeatureSettingsRepositories.kt | 全部 53 键 + themeMode + isPureBlack/pureBlack + eyeProtection* + colorTemperature | F6 F7（53 键的真实存储实现） |
| ThemeSettings.kt | 全部 53 键（含 `colorTemperature = 50` 默认） | F6 F7 |
| ThemeSettingsGateway.kt | customMode | F6 |
| Constant/PreferKey.kt | 全部 53 键 + `"themeMode"` + DayNight | F6（53 键定义总表，`:9` `themeMode`、`:120` `autoSuggestDayNight`、`:491` `colorTemperature`） |

#### 首次启动向导（C 块）

| 上游文件 | 命中的符号 | 映射到本表哪一行 |
| --- | --- | --- |
| OnboardingScreen.kt | isAmoled isPureBlack paletteStyle themeMode | C1 C2（`:339-357` 第 4 页） |
| OnboardingContract.kt | DayNight themeMode | C1 C3（`themeMode: String = "0"`、`SetThemeMode`、`ApplyDayNight`） |
| OnboardingViewModel.kt | DayNight backgroundImage containerOpacity themeMode | C1 C3 C4（`:47` 读网关、`:120-123` 写网关） |
| OnboardingRouteScreen.kt | DayNight | C1（承接 `ApplyDayNight` effect） |

#### 阅读页日夜按钮与背景（D 块）

| 上游文件 | 命中的符号 | 映射到本表哪一行 |
| --- | --- | --- |
| ReadStyleDelegate.kt | DayNight colorTemperature eyeProtection* isDarkTheme isNightTheme themeMode | D1 D2 D3 D7 D8 + E3 E4 E5 |
| GlobalThemePage.kt | DayNight eyeProtectionEnabled isNightTheme | D1（`:181-189` 日夜按钮） |
| ThemeListContent.kt | DayNight isNightTheme | D4（主题列表页按钮） |
| ReadBookColorTheme.kt | isDarkTheme isNightTheme materialVersion paletteStyle | D8（阅读菜单配色） |
| ReadBookMenuBarShared.kt | isNightTheme | D8 |
| SystemMenuPage.kt | paletteStyle | D8 |
| ReadStyleResolver.kt | isDarkTheme isNightMode isNightTheme themeMode | D3 D5（日夜派生核心） |
| ReadBookConfig.kt | isNightTheme | D3 |
| AppConfig.kt | customMode isNightMode isNightTheme isPureBlack pureBlack themeMode | F8（墨水屏 `appTheme == "4"`） |
| ReadSessionState.kt | isDarkTheme | D2 D3（`isDarkThemeOverride`） |
| ReadBookController.kt | DayNight isDarkTheme | D2 D6（`:1762-1790 onAppThemeChanged`） |
| ReadBookViewModel.kt | DayNight colorTemperature eyeProtection* isDarkTheme isNightTheme | D2 D3 E7 |
| ReadConfigUpdateDelegate.kt | DayNight | E5 E7（`:53`/`:684-689`） |
| ReadBookRouteScreen.kt | DayNight backgroundImage isDarkTheme | E3（`:1088-1130` 环境光采样） |
| ReadBookContract.kt | DayNight | E6 E7（`:46 DayNightReminder`、`:588/:851/:1271/:2036`） |
| ReadBookFloatingActionBar.kt | DayNight | E6（`:121-133 ThemeReminderCapsule`） |
| ReadMenuActionDefs.kt | DayNight | D1（菜单项定义） |
| ReadBookMenuBar.kt | DayNight eyeProtectionEnabled | A24（护眼按钮所在菜单） |
| ReadBookMenuBarBottom.kt | eyeProtectionEnabled | A24 |
| ReadBookMenuBarTool.kt | eyeProtectionEnabled | A24 |
| ReadStyleSheet.kt | DayNight eyeProtectionEnabled | A24（护眼 sheet） |
| MoreConfigSheet.kt | DayNight | E2（`:399-404` 第二个开关入口） |
| ReadConfig.kt | DayNight isNightMode isNightTheme themeMode | E1（阅读配置门面） |
| ReadConfigContract.kt | DayNight | E1 |
| ReadConfigScreen.kt | DayNight | E1（`:337-344` 开关） |
| ReadConfigViewModel.kt | DayNight colorTemperature eyeProtection* | E1 A26 |
| ReadSettingsRepository.kt | DayNight | E1（`:140` 写、`:410` 读、`:532`/`:666` 键映射） |
| ReadSettings.kt | DayNight | E1（`:43 val autoSuggestDayNight: Boolean = false`） |

#### 全局换肤与备份门控（F 块）

| 上游文件 | 命中的符号 | 映射到本表哪一行 |
| --- | --- | --- |
| App.kt | DayNight customMode themeMode | F1（`:194-203` 「themeMode 是日夜的唯一来源」） |
| BaseActivity.kt | customMode isDarkTheme isNightMode isPureBlack themeMode uiMode | F1 F2 |
| BaseComposeActivity.kt | colorTemperature composeEngine eyeProtection* isDarkTheme isNightMode uiMode | A24（`:89-104` 全 App 护眼滤镜） |
| LegacyUiConfiguration.kt | NIGHT_MASK UI_MODE themeMode | F3 |
| AppShellSettings.kt | composeEngine themeMode | F1（`:4 val themeMode: String = "0"`） |
| AppUiConfiguration.kt | backgroundImage backgroundImageBlurring customMode isDarkTheme isPureBlack isSystemDarkTheme themeMode | F2（`:11-15 isDarkTheme`） |
| AppUiConfigurationRepository.kt | isDarkTheme isSystemDarkTheme | F2 |
| AppUiConfigurationGateway.kt | isDarkTheme | F2 |
| appModule.kt | isNightMode | F2（DI 注入） |
| ThemeConfigStore.kt | DayNight backgroundImage backgroundImageBlurring isNightMode isNightTheme setDefaultNightMode themeMode | F3 F5（`:70-89 initNightMode`、`configFileName`） |
| Backup.kt | backupIgnoreThemeConfig | F5（`:241-246` themeConfig.json 唯一导出点） |
| BackupConfig.kt | `"themeConfig"` backupIgnoreThemeConfig 全部 53 键 themeMode | F6 F9 F12（`:263-317 themePrefKeys`、`:413-439 keyIsNotIgnore`） |
| ConfigTag.kt | `"themeConfig"` | F5（`:6 const val THEME_CONFIG`） |
| Restore.kt | DayNight | F9（恢复侧日夜相关处理） |
| JsExtensions.kt | themeMode | F1（js 接口暴露） |
| PreferenceCategory.kt | isNightTheme | F1（偏好分类按日夜过滤） |
| ThemeStore.kt | colorBackground colorPrimary uiMode | F4（旧版主题存储） |
| AppTheme.kt | composeEngine customContrast enableDeepPersonalization isAmoled isDarkTheme isPureBlack materialVersion paletteStyle themeMode | F4 |
| LegadoTheme.kt | composeEngine paletteStyle themeMode | F1 F4 |
| ThemeColorSchemeOverride.kt | composeEngine materialVersion paletteStyle themeMode | F1 |
| ThemeEngine.kt | customContrast isAmoled materialVersion paletteStyle | A4 F4 |
| ThemeOverride.kt | customContrast isAmoled isPureBlack materialVersion paletteStyle | A4 F4 |
| CustomColorScheme.kt | isAmoled | A4 |
| OpaqueColorScheme.kt | isAmoled isPureBlack materialVersion paletteStyle | A4 |
| ThemeComponents.kt | enableDeepPersonalization materialVersion paletteStyle uiMode useMiuixMonet | F4 |
| ThemeResolver.kt | composeEngine materialVersion paletteStyle | F4 |
| AdaptivePadding.kt | composeEngine | F4（`:13` 按引擎给不同内边距） |
| HazeStyle.kt | composeEngine enableBlur enableProgressiveBlur topBarBlurAlpha topBarBlurRadius | A30（`:20 if (...enableBlur) Modifier.hazeSource(state)`） |
| HazeLegado.kt | composeEngine topBarBlurAlpha topBarBlurRadius | A17（`:33 blurAlpha = topBarBlurAlpha / 100f`） |
| MiuixUtils.kt | enableBlur | A30（`:38`/`:142`） |
| BookshelfViewModel.kt | enableBlur | A30 |
| HomepageModuleFeed.kt | enableBlur | A30 |
| GlassDefaults.kt | enableBlur enableDeepPersonalization | A30 A6 |
| FloatingBottomBar.kt | bottomBarBlurAlpha bottomBarBlurRadius bottomBarLensRadius enableDeepPersonalization | A17 |
| AppNavigationBar.kt | bottomBarOpacity composeEngine enableDeepPersonalization | A17 |
| TopBarButton.kt | composeEngine mergeTopBarActions topBarButtonStyle | A17 |
| GlassMediumFlexibleTopAppBar.kt | composeEngine enableBlur topBarOpacity useFlexibleTopAppBar | A17 |
| BookCover.kt | isNightMode isNightTheme themeMode | F2（`:58-62` 封面按日夜取色/取图） |
| CoverImageView.kt | isNightMode isNightTheme themeMode | F2（`:62-68` `colorKey`/`shadowKey` 按日夜二选一） |
| BottomWebViewDialog.kt | DayNight isDarkTheme isNightMode isNightTheme themeMode | F2 F3（`:132-136` 按 themeMode 取色、`:543 applyDayNight`） |
| ConfigurationExtensions.kt | NIGHT_MASK UI_MODE isNightMode uiMode | F2（`:10-13 val Configuration.isNightMode`） |
| ViewExtensions.kt | isNightMode isNightTheme themeMode | F2（`:61-64 isNightTheme()`、`:82`/`:89` 默认参数） |
| WebSettingsExtensions.kt | DayNight NIGHT_MASK UI_MODE uiMode | F2（`:45-50 fun WebView.applyDayNight`） |
| CastCapsuleStyleStore.kt | backgroundImage isNightTheme | F6（朗读胶囊按日夜取样式） |
| BaseReadAloudService.kt | isNightMode | F6 |
| ReadAloudBarCapsule.kt | bottomBarBlurAlpha bottomBarBlurRadius bottomBarLensRadius | F6（朗读条模糊参数） |
| AboutScreen.kt | composeEngine | F4（引擎分支渲染端） |
| BookshelfManageScreen.kt | composeEngine | F4 |
| SearchScreen.kt | composeEngine | F4 |
| SourceLoginSheets.kt | composeEngine | F4 |
| MainActivity.kt | composeEngine | F4 |
| MainScreen.kt | composeEngine | F4 |
| BookshelfScreen.kt | composeEngine | F4 |
| ExploreScreen.kt | composeEngine | F4 |
| ButtonGroupModule.kt | composeEngine | F4 |
| AppFloatingActionButton.kt | composeEngine | F4 |
| AppPullToRefresh.kt | composeEngine | F4 |
| AppRadioButtom.kt | composeEngine | F4 |
| AppSearchBar.kt | composeEngine | F4 |
| AppSlider.kt | composeEngine | F4 |
| AppTextField.kt | composeEngine | F4 |
| AppVerticalSlider.kt | composeEngine | F4 |
| IconSwitch.kt | composeEngine | F4 |
| SearchBar.kt | composeEngine | F4 |
| SelectionBottomBar.kt | composeEngine | F4 |
| AppButton.kt | composeEngine | F4 |
| AppIconButton.kt | composeEngine | F4 |
| ConfirmDismissButtonsRow.kt | composeEngine | F4 |
| ToggleChip.kt | composeEngine | F4 |
| SelectionItemCard.kt | composeEngine | F4 |
| SettingCard.kt | composeEngine | F4 |
| AppCheckbox.kt | composeEngine | F4 |
| ExploreKindSelectSheet.kt | composeEngine | F4 |
| AppIcons.kt | composeEngine | F4 |
| RoundDropdownMenu.kt | composeEngine | F4 |
| RoundDropdownMenuItem.kt | composeEngine | F4 |
| AppModalBottomSheet.kt | composeEngine | F4 |
| AppCircularProgressIndicator.kt | composeEngine | F4 |
| AppContainedLoadingIndicator.kt | composeEngine | F4 |
| AppLinearProgressIndicator.kt | composeEngine | F4 |
| AppTabRow.kt | composeEngine | F4 |
| SmallTitle.kt | composeEngine | F4 |
| GlassSmallTopAppBar.kt | composeEngine | F4 |
| GlassTopAppBar.kt | composeEngine | F4 |

> **关于上表 40 余个「composeEngine 渲染端」**：它们只读 `LegadoTheme.composeEngine` 决定走 Miuix 还是 Material 控件分支，本身不存任何主题配置。之所以仍要逐个列出而不是一句「其余同理」，是因为它们正是 A7 的**成本证据**——`composeEngine` 一个开关牵动 40 多个控件文件，实现 A7 时不能只看 `ThemeConfigScreen.kt` 那一行。

### 4.2 已排除（16 个）

| 上游文件 | 引用位置 | 排除理由 |
| --- | --- | --- |
| ColorPreference.kt | `material.R.attr.colorPrimaryContainer` | **子串误命中**：命中的是 Android 主题属性名里的 `colorPrimary`，不是 themeConfig 的 `colorPrimary` 键。属主题配置的**取色控件实现**，本身不存值 |
| ReaderCanvasSurface.kt | `backgroundImage` | 命中的是 `ReaderTextBackgroundImage`（**正文内联文字背景图**），阅读渲染管线概念，与主题背景图 `backgroundImage` 键同名异义。归 [阅读配置总账](READER-CONFIG.md) 的阅读渲染块 |
| CastCapsuleStyle.kt | `backgroundImage` | 同上，正文文字背景图 |
| ReaderChapterBlockMeasurer.kt | `backgroundImage` | 同上，`:38` `if (element.style.backgroundImage != null) { brokenByImage = true }` 是排版测量 |
| ReaderPaginator.kt | `backgroundImage` | 同上 |
| ReaderPage.kt | `backgroundImage` | 同上 |
| ReaderTextBackgroundRun.kt | `backgroundImage` | 同上，这个类本身就是文字背景图的数据模型 |
| ReaderBackgroundBounds.kt | `backgroundImage` | 同上 |
| ReaderCharacterStyle.kt | `backgroundImage` | 同上，`:21 val backgroundImage: ReaderTextBackgroundImage? = null` |
| LegacyReaderStyleRangeMapper.kt | `backgroundImage` | 同上 |
| MangaReaderOverlays.kt | `paletteStyle` | 漫画阅读器的**菜单配色**（`:171 ThemeResolver.resolvePaletteStyle(state.settings.menuPaletteStyle)`），是 `menuPaletteStyle` 而非全局 `paletteStyle` 键。属漫画模块，见 STATUS 的 `mangaConfig` 行 |
| MangaSettingsPanel.kt | `paletteStyle` | 同上（`:646 stringArrayResource(R.array.paletteStyle)` 是漫画菜单面板下拉） |
| RssReadRouteScreen.kt | `DayNight` | **本地无 RSS 阅读页**（`pages/` 34 个文件无 Rss*），整页未迁移，STATUS 已把 `rssSource`/`rssStar` 判不适用。D 块的日夜按钮在这两个页面上没有落点 |
| RssReadWebController.kt | `DayNight isNightTheme` | 同上 |
| FastScroller.kt | `colorPrimary` | `:508 context.theme.resolveAttribute(androidx.appcompat.R.attr.colorPrimary, ...)`——AppCompat 主题属性，与 themeConfig 键无关。同 `ColorPreference.kt` 的误命中 |
| ContextExtensions.kt | `uiMode` | `:453 uiModeManager.currentModeType == Configuration.UI_MODE_TYPE_TELEVISION`——判定设备是否为电视，与日夜模式无关 |

### 4.3 未分配

**0 个。**

## 本轮改动

- `docs/parity/KEYWORDS.md:64`（`themeConfig`）与 `:66`（`themeMode`）关键词替换，命中数 3→132、32→80。
- `entry/src/main/ets/data/BackupRepository.ets:327` 的 `title: '主题模式'` 改为 `'深色模式'`，与上游 `strings.xml:660` 及 [备份恢复](../BACKUP-RESTORE.md) 的写法对齐（F10）。
- 本文件新建。实现代码只动了上面那一处文案，其余未动——按任务约束，本轮只盘点。
- 构建验证记录见 [VALIDATION](../VALIDATION.md) 的「2026-10-31 r298 深色模式盘点轮次收尾构建」：12:04 的 `assembleHap` 成功，HAP 的 abc 字符串表 offset 182284 处已是「深色模式」；之后的失败均来自并行会话未完成的 `.ets` 改动，与本轮无关。

## 结论

1. **本地缺的是整套浅色主题，不是一个备份键。** 2252 处颜色字面量全内联、无 `dark/` 资源目录、`$r('app.color.*')` 引用 0 处。在补完 F4 之前，`themeMode` 怎么接都不会让界面变色。
2. **`themeMode` 的三处界面（A1 主题页、C1 向导、D1 阅读页）全都没有写到全局状态。** 向导把值写进了 `legado_first_run`（C3 已接），但启动时 `restoreOnboarding` 读完就丢（C4）；主题页只改 `@State`（A1）；阅读页切的是私有布尔（D2）。
3. **阅读页日夜按钮其实有**（D1 已接，两处入口），任务书里「本地无入口」的判断需要更正。真正的差异是它只切阅读页纸张，不碰全局网关。
4. **护眼在本地是两套半成品**：主题页那套是死 UI（A24–A29 全 `未接`），阅读设置页那套能存盘但没有色温滤镜渲染。备份侧 6 键双向通（F7），功能侧不通。
5. **主题包管理（B 块 12 行）整块缺失**，本地只有一个弹「尚未迁移」的入口。
6. **日夜提醒（E 块 7 行）整块缺失**，本地只有一个恒 `false` 的开关壳。
7. **关键词是本轮最大的发现**：`themeConfig` 必须用 53 键的**真实字符串值**检索（常量名与值有 22 处不同），`themeMode` 必须补 `isDarkTheme`/`isNightTheme`/`DayNight` 这层派生词。旧词只覆盖存储层三个文件，界面层一个都进不来。

## 建议后续顺序

1. **F4 + F2**：抽颜色资源、建 `dark/element/color.json`、读系统 `colorMode`。这是其它所有行的前置。
2. **F1 + A1**：建全局 `themeMode` 状态并让主题页落盘。做完这一步，A1/C1/D2 三处「点了没效果」同时解决一半。
3. **C4**：把 `restoreOnboarding` 读到的 `themeMode` 接到全局状态（改动很小，收益立现）。
4. **D2**：让阅读页按钮改全局 `themeMode`，而不是私有布尔。
5. **A24–A29**：给护眼补上色温滤镜渲染，并把主题页那套死 UI 接到阅读设置页那套状态上。
6. **F5 + F9**：补 `themeConfig.json` 写出与 `themeMode` 的 `config.xml` 写出分支。
7. **B 块**：主题包管理整块新做，工作量最大，放最后。
8. **E 块**：日夜提醒依赖 D2 与传感器采样，排在 D2 之后。

## 维护

- 改本表前先跑一遍第四节的两条 `--coverage` 命令，确认接触面仍是 80/132。**关键词变了就要重算「逐轮增量」那一节**——它是本表唯一能证明「接触面不是靠猜」的部分。
- 新增 A 块行时，`ThemeConfigScreen.kt` 的 widget 调用数（49 处 / 归并后 39 条）与本地 `ThemeSettingsPage.ets` 的可见条目数（46 条）必须同步更新；两者对不上就说明有行被漏掉或拆细。
- 判 `不适用` 的三行（C5 向导预览卡、D4 主题列表页按钮、F8 墨水屏）都必须保留理由，不要因为「本地没有」就删行——删了下次盘点会当成新缺口重新发现一遍。
