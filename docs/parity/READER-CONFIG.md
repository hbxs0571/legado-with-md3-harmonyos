# 阅读配置对照表

本表按 [模块对照要求](../CODE-CONVENTIONS.md) 第四节点完一次，行粒度是**一个界面上的一个可感知操作**（不是「与本功能相关的几个按钮」，见第四节「盘点单位是界面，不是按钮」）。
状态三值：`已接` / `未接` / `不适用`；`不适用` 写理由。**本表无 `待定` 行。**

> **r286 结构性重盘（2026-10-30）**
>
> **一、盘点方法换了两条**：行粒度改以「整个界面」为单位；完成判据改为**覆盖证明**（见文末「覆盖证明」节）。
>
> **二、A–G 七块共 189 行是迁移前证据，未逐行复核。** 这 189 行写于 2026-10-29，本轮只做了两件事：把已完成的关系型存储迁移带来的字段口径变化核过一遍（本表不涉及 `chapters` / `bookmarks` / `book_marks` 三张表，无失效引用），并把 `readConfig` 类的上游接触面补齐（原表只覆盖 6 个上游文件）。行内容本身未逐条重跑验收。
>
> **三、新增「覆盖证明」节**：`readConfig` 类的上游接触面由旧的错误关键词 `backupIgnoreReadConfig`（只命中 2 个文件，等于自证成功）改为 `ReadBookConfig|ReadSettings`（命中 **76** 个文件），逐个分配。
>
> **四、本表的口径基数未变**：上游配置来源两个文件 `help/config/ReadBookConfig.kt`（1054 行）与 `domain/model/settings/ReadSettings.kt`（122 行），合计声明 **267** 个名字。这 267 个是**字段级**基数；本表的 189 行是**界面级**基数。两者不可相加也不可相减，1.3 的 112 项差集属字段口径。

- 盘点日期：2026-10-29（r286 结构性重盘：2026-10-30）
- 上游基线：`legado-with-MD3`（Android，Compose）
- 本地实现：`entry/src/main/ets`（HarmonyOS，ArkTS）
- 对应 ZIP 类别：`readConfig`

## 口径说明

四处容易误判的地方，先说清楚，避免后续重复返工：

1. **改名不等于未接。** 上游 `textSize`、`lineSpacingExtra`、`shadowColor`、`pageAnim`、`menuIconItemsPerRow` 等在本地以 `fontSize`、`lineSpacing`、`textShadowColor`、`pageAnimation`、`bottomItemsPerRow` 落地，语义等价。这类判 `已接`，映射关系见[第二节改名映射表](#二改名映射表)。**但 `textColor` 不属此类**——本地正文色是硬编码，是真缺口（详见 C 块首行）。
2. **控件存在不等于已接。** `entry/src/main/ets/pages/ReaderSettingsPage.ets` 的菜单外观条目（`menuSettingsContent()`，`:399`；条目由 `getMenuSettingsEntries()`，`:1788` 生成）共 41 条，其中 5 条是分组标题，真实条目 36 条。绝大多数控件齐备、点击有响应，但 `menuBorderEnabled`（`:168`）、`menuBarStyleMode`（`:165`）、`menuColorMode`（`:166`）等状态只存在于页面 `@State`，在 `ReaderSettingsRepository.ets` 中检索命中数为 0。退出设置页即丢失，也不驱动阅读页渲染。这类判 `未接`，不判 `已接`。**例外只有两条**：`底栏按钮配置` 与 `标题栏操作按钮` 走 `handleMenuSettingsEntryClick()`（`:517-531`）打开真实配置面板并落盘（见 E 块对应两行）。
3. **上游配置有两个来源文件，缺一不可。** 本表早期只盘了 `ReadBookConfig.kt`（单本书可覆盖的 `Config`），漏掉 `domain/model/settings/ReadSettings.kt`（全书统一设置，114 个字段）。后者有一半字段与前者同名或同义，其余 53 个字段此前从未进表。两个文件合计声明 267 个名字，是本节字段口径的基数。
4. **`showNotMigrated()` 是显式占位。** `grep -c "showNotMigrated(" entry/src/main/ets/pages/ReaderSettingsPage.ets` 得 21 行命中，其中 1 行是 `:1242` 的函数定义，实际调用 20 处、18 个不同名称（`:485`、`:494`、`:801`、`:837`、`:838`、`:839`、`:840`、`:848`、`:851`、`:863`、`:864`、`:867`、`:868`、`:869`、`:870`、`:873`、`:879`、`:883`、`:886`、`:887`），点开只弹提示。凡走这条路的判 `未接`，不因界面上显示了开关而判已接。

## 盘面

| 块 | 条数 | 已接 | 未接 | 不适用 |
| --- | --- | --- | --- | --- |
| A 阅读界面基础 | 37 | 14 | 21 | 2 |
| B 页眉页脚 | 24 | 23 | 1 | 0 |
| C 正文排版 | 49 | 23 | 26 | 0 |
| D 翻页与手势交互 | 20 | 10 | 10 | 0 |
| E 菜单与主题外观 | 42 | 2 | 40 | 0 |
| F 护眼与书签角标 | 9 | 9 | 0 | 0 |
| G 页边距 | 8 | 8 | 0 | 0 |
| 合计 | 189 | 89 | 98 | 2 |

> 早前口头估计「菜单外观 30-40 项全占位」方向对、原因错：不是没有控件，是有控件无持久化无渲染（见口径第 2 条）。逐项核完 E 块共 42 条：40 条未接，2 条已接（底栏按钮配置、标题栏操作按钮）。

## A 阅读界面基础

上游主体：`legado-with-MD3/app/src/main/java/io/legado/app/help/config/ReadBookConfig.kt`（1054 行）、`app/src/main/java/io/legado/app/domain/model/settings/ReadSettings.kt`（122 行）。
本地主体：`entry/src/main/ets/data/ReaderSettingsRepository.ets`（966 行）、`entry/src/main/ets/pages/ReaderSettingsPage.ets`（2444 行）。

| 上游能力 | 上游位置 | 本地位置 | 状态 | 差异说明 | 验收方式 | 备注 |
| --- | --- | --- | --- | --- | --- | --- |
| 屏幕方向 | `ReadSettings.kt` | `ReaderSettingsRepository.ets:184` | 已接 | 本地 `screenOrientation` 存字符串，页面上为三选一 | 切横屏后阅读页方向变化 | — |
| 保持屏幕常亮 | `ReadSettings.kt` | `ReaderSettingsRepository.ets:185` | 已接 | 本地 `keepLight` 存 `'0'`/`'60'`/`'300'`/`'600'`/`'-1'` | 设 60 秒后无操作自动息屏 | — |
| 隐藏状态栏 | `ReadBookConfig.kt:74` | `ReaderSettingsRepository.ets:178` | 已接 | — | 开关后状态栏消失 | — |
| 隐藏导航栏 | `ReadBookConfig.kt:75` | `ReaderSettingsRepository.ets:179` | 已接 | — | 开关后导航栏消失 | — |
| 阅读布局共享 | `ReadBookConfig.kt:71` | `ReaderSettingsRepository.ets:166` | 已接 | — | 开关后配置作用域变化 | — |
| 自动阅读速度 | `ReadBookConfig.kt:68` | `ReaderSettingsRepository.ets:181` | 已接 | — | 调速后滚动速率变化 | 自动朗读功能本身在范围之外 |
| 阅读位置锚点 | `ReadBookConfig.kt:79` | `ReaderSettingsRepository.ets:189` | 已接 | — | 开关后跳转章节可返回原位 | — |
| 底栏图标显示文字 | `ReadBookConfig.kt:77` | `ReaderSettingsRepository.ets:167` | 已接 | 上游 `readMenuIconShowText` → 本地 `showBottomActionText` | 开关后图标下方文字显隐 | — |
| 底栏图标样式 | `ReadBookConfig.kt:100` | `ReaderSettingsRepository.ets:168` | 已接 | 上游 `readMenuIconStyle` → 本地 `bottomIconStyle`，取值 0–2 | 切换后图标填充/描边变化 | — |
| 底栏每行图标数 | `ReadBookConfig.kt:102` | `ReaderSettingsRepository.ets:169` | 已接 | 上游夹取 2–8，本地滑块同区间 | 拖动后每行图标个数变化 | — |
| 底栏图标行数 | `ReadBookConfig.kt:103` | `ReaderSettingsRepository.ets:170` | 已接 | 上游夹取 1–2，本地滑块同区间 | 切到 2 行后底栏变高 | — |
| 正文行高适配 | `ReadSettings.kt` | `ReaderSettingsPage.ets:838` | 未接 | 走 `showNotMigrated('正文行高适配')`，无对应仓储字段 | 开关后特殊排版的书行距被修正 | 上游 `readBodyToLh`（`ReadBookConfig.kt:67`） |
| 中文排版 | `ReadBookConfig.kt:76` | `ReaderSettingsPage.ets:839` | 未接 | 走 `showNotMigrated('中文排版')`，`useZhLayout` 无对应字段 | 开关后中文标点挤压生效 | — |
| 适配刘海屏 | `ReadSettings.kt` | `ReaderSettingsPage.ets:837` | 未接 | 开关恒为 `checked: true` 且点击即占位提示 | 开关后正文避让显示缺口 | — |
| 适配特殊样式 | `ReadSettings.kt` | `ReaderSettingsPage.ets:840` | 未接 | 走 `showNotMigrated('适配特殊样式')` | 开关后书籍自带样式被保留 | — |
| 显示菜单图标 | `ReadBookConfig.kt:78` | `ReaderSettingsPage.ets:883` | 未接 | 走 `showNotMigrated('显示菜单图标')` | 总开关关闭后阅读页菜单图标消失 | — |
| 禁用返回键 | `ReadSettings.kt` | `ReaderSettingsPage.ets:864` | 未接 | 走 `showNotMigrated('禁用返回键')` | 开关后返回键在阅读页无响应 | — |
| 优化正文渲染 | `ReadSettings.kt` | `ReaderSettingsPage.ets:863` | 未接 | 走 `showNotMigrated('优化正文渲染')` | 开关后长章节渲染耗时变化 | — |
| 阅读标题补充信息 | `ReadSettings.kt` | `ReaderSettingsPage.ets:886` | 未接 | 走 `showNotMigrated('阅读标题补充信息')`，`checked` 恒 `false` | 开关后阅读页标题出现补充行 | — |
| 朗读悬浮窗分离提醒 | `ReadBookConfig.kt:80` | `ReaderSettingsPage.ets:887` | 未接 | 走 `showNotMigrated('朗读悬浮窗分离提醒')` | — | 朗读整体在[范围之外](../PROJECT.md)，判 `未接` 而非 `不适用`，因开关已上屏 |
| 自动切换书源 | `ReadSettings.kt` | `ReaderSettingsPage.ets:868` | 未接 | 走 `showNotMigrated('自动切换书源')` | — | 在线书源在[范围之外](../PROJECT.md)，开关已上屏故判 `未接` |
| 换源结果应用于全部书籍 | `ReadSettings.kt` | `ReaderSettingsPage.ets:869` | 未接 | 走 `showNotMigrated('换源结果应用于全部书籍')` | — | 同上 |
| 自动切换日夜模式提醒 | `ReadSettings.kt` | `ReaderSettingsPage.ets:870` | 未接 | 走 `showNotMigrated('自动切换日夜模式提醒')` | 到点后弹出切换背景提示 | — |
| 阅读进度条触感反馈 | `ReadSettings.kt` | `ReaderSettingsPage.ets:867` | 未接 | 走 `showNotMigrated('进度条触感反馈')` | 拖动进度条有振动 | — |
| 使用新版目录 | `ReadSettings.kt` | `ReaderSettingsPage.ets:873` | 未接 | 走 `showNotMigrated('使用新版目录')` | 开关后目录面板形态变化 | — |
| 文字选择触感反馈 | `ReadSettings.kt` | `ReaderSettingsPage.ets:879` | 未接 | 走 `showNotMigrated('文字选择触感反馈')` | 选中正文有振动 | — |
| 漫画阅读样式 | `ReadBookConfig.kt:70` | — | 不适用 | 上游 `comicStyleSelect` 为漫画阅读专用 | — | 漫画/图片书不在[项目队列](../PROJECT.md)范围，本地无图片书类型 |
| 阅读样式选择（漫画分支） | `ReadBookConfig.kt:69` | — | 不适用 | 上游 `readStyleSelect` 在漫画会话下生效 | — | 同上，`styleSelect`（`:98`）取漫画分支时无意义 |
| 阅读亮度 | `ReadSettings.kt:22` | — | 未接 | 上游 `readBrightness` 随书保存亮度，本地无字段，亮度不随书记忆 | 调暗后退出重进亮度保持 | — |
| 阅读菜单不透明度 | `ReadSettings.kt:13` | — | 未接 | 上游 `menuAlpha` 默认 100，是整层不透明度；E 块的「菜单模糊透明度」对应 `readMenuBlurAlpha`，不是此项 | 调后菜单整体通透度变化 | 与 E 块 `readMenuBlurAlpha` 不同字段 |
| 主题网格列数 | `ReadSettings.kt:40` | — | 未接 | 上游 `themeGridColumns` 默认 4，本地无字段 | 主题面板每行列数变化 | — |
| 向后预下载章节数 | `ReadSettings.kt:58` | — | 未接 | 上游 `preDownloadNum` 默认 10；`AppDownloadCacheSettingsPage.ets:31` 是预览页，滑块无持久化 | 调大后缓存章节数变化 | 下载缓存模块整体未接 |
| 向前预下载章节数 | `ReadSettings.kt:59` | — | 未接 | 上游 `preDownloadNumPrev` 默认 0，同上 | 同上 | 同上 |
| 在浏览器打开 | `ReadSettings.kt:64` | — | 未接 | 上游 `readUrlInBrowser`，本地无字段 | 开启后链接在系统浏览器打开 | — |
| 无目录书籍分段长度 | `ReadSettings.kt:38` | `ReaderSettingsRepository.ets:196` | 已接 | 上游 `maxLengthWithNoToc` 默认 3000，本地同名滑块 `ReaderSettingsPage.ets:865` 区间 3000–100000 | 调节后无目录书籍分段点变化 | — |
| 目录使用替换规则 | `ReadSettings.kt:62` | `ReaderSettingsRepository.ets:174` | 已接 | 上游 `tocUiUseReplace` → 本地 `tocUseReplace` | 目录中替换规则生效 | 存储键仍写 `tocUiUseReplace` |
| 目录显示字数 | `ReadSettings.kt:63` | `ReaderSettingsRepository.ets:175` | 已接 | 上游 `tocCountWords` → 本地 `tocShowWordCount` | 目录条目显示字数 | 存储键仍写 `tocCountWords` |

## B 页眉页脚

本地主体：`ReaderInfoSettings`（`ReaderSettingsRepository.ets:1-29`）、页面区块 `ReaderSettingsPage.ets:742-824`。

| 上游能力 | 上游位置 | 本地位置 | 状态 | 差异说明 | 验收方式 | 备注 |
| --- | --- | --- | --- | --- | --- | --- |
| 页眉模式 | `ReadBookConfig.kt:429` | `ReaderSettingsRepository.ets:4` | 已接 | 三值：状态栏显示时隐藏 / 显示 / 隐藏 | 切「隐藏」后页眉消失 | — |
| 页脚模式 | `ReadBookConfig.kt:432` | `ReaderSettingsRepository.ets:5` | 已接 | 本地只有显示/隐藏两值，上游同为两值 | 切「隐藏」后页脚消失 | — |
| 页眉分割线 | `ReadBookConfig.kt:373` | `ReaderSettingsRepository.ets:6` | 已接 | — | 开关后页眉下出现横线 | — |
| 页脚分割线 | `ReadBookConfig.kt:376` | `ReaderSettingsRepository.ets:7` | 已接 | — | 开关后页脚上出现横线 | — |
| 页眉左槽内容 | `ReadBookConfig.kt:393` | `ReaderSettingsRepository.ets:8` | 已接 | 上游 `tipHeaderLeft`，枚举值本地按 `:1237` 的列表对齐 | 左槽显示时间 | — |
| 页眉中槽内容 | `ReadBookConfig.kt:396` | `ReaderSettingsRepository.ets:9` | 已接 | — | 中槽显示所选内容 | — |
| 页眉右槽内容 | `ReadBookConfig.kt:399` | `ReaderSettingsRepository.ets:10` | 已接 | — | 右槽显示电量 | — |
| 页脚左槽内容 | `ReadBookConfig.kt:402` | `ReaderSettingsRepository.ets:11` | 已接 | — | 左槽显示章节标题 | — |
| 页脚中槽内容 | `ReadBookConfig.kt:405` | `ReaderSettingsRepository.ets:12` | 已接 | — | 中槽显示所选内容 | — |
| 页脚右槽内容 | `ReadBookConfig.kt:408` | `ReaderSettingsRepository.ets:13` | 已接 | — | 右槽显示页码/总页 | — |
| 页眉自定义左槽文本 | `ReadBookConfig.kt:412` | `ReaderSettingsRepository.ets:17` | 已接 | 槽内容选「自定义」时生效 | 输入文本后页眉左槽显示 | — |
| 页眉自定义中槽文本 | `ReadBookConfig.kt:415` | `ReaderSettingsRepository.ets:18` | 已接 | — | 同上 | — |
| 页眉自定义右槽文本 | `ReadBookConfig.kt:418` | `ReaderSettingsRepository.ets:19` | 已接 | — | 同上 | — |
| 页脚自定义左槽文本 | `ReadBookConfig.kt:421` | `ReaderSettingsRepository.ets:14` | 已接 | — | 同上 | — |
| 页脚自定义中槽文本 | `ReadBookConfig.kt:424` | `ReaderSettingsRepository.ets:15` | 已接 | — | 同上 | — |
| 页脚自定义右槽文本 | `ReadBookConfig.kt:427` | `ReaderSettingsRepository.ets:16` | 已接 | — | 同上 | — |
| 页眉字号 | `ReadBookConfig.kt:216` | `ReaderSettingsRepository.ets:22` | 已接 | 上游为 `takeIf { it > 0 } ?: 12`，本地默认 12 | 调字号后页眉文字变大 | — |
| 页脚字号 | `ReadBookConfig.kt:219` | `ReaderSettingsRepository.ets:23` | 已接 | 同上回落规则 | 调字号后页脚文字变大 | — |
| 应用页眉样式到页脚 | `ReadBookConfig.kt:222` | `ReaderSettingsRepository.ets:24` | 已接 | — | 开关后页脚继承页眉字体 | — |
| 页眉日间文字颜色 | `ReadBookConfig.kt:435` | `ReaderSettingsRepository.ets:25` | 已接 | — | 改色后页眉文字变色 | — |
| 页眉夜间文字颜色 | `ReadBookConfig.kt:438` | `ReaderSettingsRepository.ets:26` | 已接 | — | 切夜间后取该值 | — |
| 页脚日/夜文字颜色 | `ReadBookConfig.kt:441`、`:444` | `ReaderSettingsRepository.ets:27-28` | 已接 | — | 切换日夜后页脚颜色变化 | — |
| 页眉页脚分割线颜色 | `ReadBookConfig.kt:453` | `ReaderSettingsRepository.ets:29` | 已接 | 上游默认 `-1`，本地同 | 改色后分割线变色 | — |
| 页眉/页脚独立字体 | `ReadBookConfig.kt:210`、`:213` | `ReaderSettingsRepository.ets:20-21` | 未接 | 字段已建模但 UI 无选择入口：`ReaderSettingsPage.ets:1339` 的字体目标只有正文/标题/页眉/页脚四按钮，点「页眉」「页脚」走 `:485` 的 `showNotMigrated('页眉/页脚字体选择')` | 选择页眉字体后页眉字形变化 | 字段存在不等于功能可达 |

## C 正文排版

本地主体：`ReaderSettingsRepository.ets:138-161`、渲染侧 `entry/src/main/ets/pages/ReaderPage.ets`（3562 行）。

| 上游能力 | 上游位置 | 本地位置 | 状态 | 差异说明 | 验收方式 | 备注 |
| --- | --- | --- | --- | --- | --- | --- |
| 正文日间颜色 | `ReadBookConfig.kt:55` | `ReaderPage.ets:2710-2713` | 未接 | 上游 `textColor` 可配（默认 `#3E3D3B`）；本地 `getReadingTextColor()` 硬编码，按 `paperColor` 三值判断日/夜后返回固定色 | 改正文颜色后正文字变色 | 属于「有默认值但不可配」 |
| 正文夜间颜色 | `ReadBookConfig.kt:56` | `ReaderPage.ets:2710-2713` | 未接 | 上游 `textColorNight`（默认 `#ADADAD`）；本地同上硬编码为 `#D8D8DC` | 切夜间后正文字取该值 | 同上 |
| 正文强调色 | `ReadBookConfig.kt:62` | — | 未接 | 上游 `textAccentColor`/`Night` 三套，本地无字段 | 改强调色后划线高亮色变化 | 与 E 块「种子色」同源 |
| 背景透明度 | `ReadBookConfig.kt:198` | — | 未接 | 上游 `bgAlpha` 默认 100，本地无字段 | 调透明度后背景图透出 | — |
| 背景颜色/图片 | `ReadBookConfig.kt:537-551` | `ReaderSettingsRepository.ets:162-164` | 未接 | 本地 `paperIndex`/`dayPaperIndex`/`nightPaperIndex` 存索引，指向 `READER_BACKGROUND_STYLES`（`:339-346`）六个内置方案，用户只能在这六个里选；上游 `bgStr` 存任意颜色串、`bgType` 支持 assets 与自选图片，自定义能力本地为零。行内「背景图片」条目（`ReaderSettingsPage.ets:1281`）也只弹提示 | 六方案可切换；自选颜色或图片不可用 | 六个预设可用属既有能力，不改变本行「自定义背景」未接 |
| 白天是否暗色状态栏 | `ReadBookConfig.kt:552` | — | 未接 | 上游 `darkStatusIcon`/`Night`，本地无字段 | 浅色背景下状态栏图标变暗 | — |
| 正文字号 | `ReadBookConfig.kt:246` | `ReaderSettingsRepository.ets:139` | 已接 | 上游 `textSize` → 本地 `fontSize` | 调字号后正文字变大 | — |
| 段距 | `ReadBookConfig.kt:261` | `ReaderSettingsRepository.ets:140` | 已接 | 上游默认 2 | 调段距后段落间隙变化 | — |
| 行距 | `ReadBookConfig.kt:252` | `ReaderSettingsRepository.ets:141` | 已接 | 上游 `lineSpacingExtra` → 本地 `lineSpacing` | 调行距后行间空白变化 | — |
| 字距 | `ReadBookConfig.kt:249` | `ReaderSettingsRepository.ets:142` | 已接 | 上游默认 0.1f | 调字距后字符间隙变化 | — |
| 段落缩进 | `ReadBookConfig.kt:313` | `ReaderSettingsRepository.ets:143` | 已接 | 上游默认两个全角空格 | 改缩进后首行缩进变化 | — |
| 正文字体 | `ReadBookConfig.kt:204` | `ReaderSettingsRepository.ets:144` | 已接 | — | 换字体后正文字形变化 | — |
| 标题字体 | `ReadBookConfig.kt:207` | `ReaderSettingsRepository.ets:145` | 已接 | — | 换字体后章节标题字形变化 | — |
| 系统字体数量 | `ReadSettings.kt` | `ReaderSettingsRepository.ets:146` | 已接 | 本地 `systemTypefaces` | 字体面板列出系统字体 | — |
| 斜体 | `ReadBookConfig.kt:231` | `ReaderSettingsRepository.ets:147` | 已接 | — | 开关后正文倾斜 | — |
| 字重 | `ReadBookConfig.kt:225` | `ReaderSettingsRepository.ets:148` | 已接 | 上游 0/1/2 = 正常/粗/细，上游默认 500 视为正常档 | 切三档后笔画粗细变化 | 上游注释与取值不一致，本地按 0/1/2 落地 |
| 文字阴影开关 | `ReadBookConfig.kt:234` | `ReaderSettingsRepository.ets:149` | 已接 | — | 开关后文字出现投影 | — |
| 阴影模糊半径 | `ReadBookConfig.kt:237` | `ReaderSettingsRepository.ets:150` | 已接 | 上游默认 16f | 调半径后投影扩散程度变化 | — |
| 阴影 X 偏移 | `ReadBookConfig.kt:240` | `ReaderSettingsRepository.ets:151` | 已接 | 上游默认 1f | 调偏移后投影横向位移 | — |
| 阴影 Y 偏移 | `ReadBookConfig.kt:243` | `ReaderSettingsRepository.ets:152` | 已接 | 上游默认 1f | 调偏移后投影纵向位移 | — |
| 阴影日间颜色 | `ReadBookConfig.kt:543`（`shadowColor`） | `ReaderSettingsRepository.ets:153` | 已接 | 上游 `shadowColor` → 本地 `textShadowColor` | 改色后投影变色 | — |
| 阴影夜间颜色 | `ReadBookConfig.kt:544`（`shadowColorN`） | `ReaderSettingsRepository.ets:154` | 已接 | 上游 `shadowColorN` → 本地 `textShadowColorN` | 切夜间后投影取该值 | — |
| 下划线开关 | `ReadBookConfig.kt:316` | `ReaderSettingsRepository.ets:155` | 已接 | — | 开关后正文加下划线 | — |
| 虚线样式 | `ReadBookConfig.kt:328` | `ReaderSettingsRepository.ets:156` | 已接 | — | 开关后下划线变虚线 | — |
| 下划线日间颜色 | `ReadBookConfig.kt:379` | `ReaderSettingsRepository.ets:157` | 已接 | — | 改色后下划线变色 | — |
| 下划线夜间颜色 | `ReadBookConfig.kt:380` | `ReaderSettingsRepository.ets:158` | 已接 | — | 切夜间后取该值 | — |
| 下划线粗细 | `ReadBookConfig.kt:319` | `ReaderSettingsRepository.ets:159` | 已接 | 上游默认 1 | 调粗细后下划线变粗 | — |
| 两端对齐 | `ReadBookConfig.kt:72` | `ReaderSettingsRepository.ets:160` | 已接 | — | 开关后行尾对齐到页边 | — |
| 底部对齐 | `ReadBookConfig.kt:73` | `ReaderSettingsRepository.ets:161` | 已接 | — | 开关后正文贴底排版 | — |
| 下划线偏移量 | `ReadBookConfig.kt:322` | — | 未接 | 上游 `underlinePadding` 默认 10，仓储无字段 | 调偏移后下划线与文字距离变化 | — |
| 下划线延伸 | `ReadBookConfig.kt:325` | — | 未接 | 上游 `underlineExtend`，仓储无字段 | 开关后下划线延伸到页边 | — |
| 自定义虚线长度基准 | `ReadBookConfig.kt:331` | — | 未接 | 上游 `dottedBase` 默认 6f，仓储无字段 | 调基准后虚线每段变长 | — |
| 自定义虚线间隔比例 | `ReadBookConfig.kt:334` | — | 未接 | 上游 `dottedRatio` 默认 6f，仓储无字段 | 调比例后虚线间隔变化 | — |
| 标题位置模式 | `ReadBookConfig.kt:267` | — | 未接 | 上游三值：居左/居中/隐藏；本地 `ReaderPage.ets:824` 固定按左对齐绘制 | 切「居中」后标题居中 | — |
| 标题字号 | `ReadBookConfig.kt:269` | — | 未接 | 上游 `titleSize` 有绝对值/相对正文两模式（`isTitleSizeRelative()`，`:660-668`）；本地无字段，改为 9 处硬编码 `this.fontSize + 4`：`ReaderPage.ets:824`、`:1651`、`:1656`、`:2857`、`:2859`、`:2867`、`:2869`、`:2941`、`:2943` | 改标题字号后标题字变大 | 相对偏移量固定为 4，不可配置 |
| 标题字号是否相对正文 | `ReadBookConfig.kt:270` | — | 未接 | 上游 `titleSizeRelative` 为三态（null/true/false），本地无字段亦无 UI | 切绝对模式后标题不随正文字号变 | — |
| 标题上间距 | `ReadBookConfig.kt:298` | — | 未接 | 上游 `titleTopSpacing` 默认 0 | 调上间距后标题上方空白变化 | — |
| 标题下间距 | `ReadBookConfig.kt:301` | — | 未接 | 上游 `titleBottomSpacing` 默认 0 | 调下间距后标题下方空白变化 | — |
| 标题日间颜色 | `ReadBookConfig.kt:304` | — | 未接 | 上游 `titleColor` 默认 0（跟随正文） | 改色后标题变色 | — |
| 标题夜间颜色 | `ReadBookConfig.kt:307` | — | 未接 | 上游 `titleColorNight` 默认 0 | 切夜间后标题取该值 | — |
| 标题字重 | `ReadBookConfig.kt:228` | — | 未接 | 上游 `titleBold` 独立于正文 `textBold` | 切标题粗体后标题加粗 | — |
| 标题行距 | `ReadBookConfig.kt:255` | — | 未接 | 上游 `titleLineSpacingExtra` 默认 12 | 调后标题多行时行间变化 | — |
| 标题行距子项 | `ReadBookConfig.kt:258` | — | 未接 | 上游 `titleLineSpacingSub` 默认 12 | 分段标题的第二段行距变化 | — |
| 标题分段模式 | `ReadBookConfig.kt:280` | — | 未接 | 上游 `titleSegType` 默认 0 | 开关后长标题按规则拆两段 | — |
| 标题分段缩放 | `ReadBookConfig.kt:283` | — | 未接 | 上游夹取 0–2，负值回落 1 | 调比例后第二段字号变化 | — |
| 标题分段起始位置 | `ReadBookConfig.kt:287` | — | 未接 | 上游 `titleSegDistance` 默认 4 | 调值后分段切点前移/后移 | — |
| 标题分段识别字符 | `ReadBookConfig.kt:290` | — | 未接 | 上游 `titleSegFlag` 默认空串 | 填入字符后在该处拆段 | — |
| 繁简转换 | `ReadSettings.kt:118` | — | 未接 | 上游 `chineseConverterType` 三档（不转换/繁体/简体），本地无字段 | 选繁体后正文以繁体显示 | — |
| 字体文件夹 | `ReadSettings.kt:79` | — | 未接 | 上游 `fontFolder` 指定扫描目录，本地只支持系统字体与内置字体 | 指定文件夹后出现自定义字体 | 本地 `systemTypefaces` 只覆盖系统字体枚举 |

> C 块的标题排版是整组缺口：14 个标题字段全部未接，本地用 9 处硬编码的 `this.fontSize + 4` 代替（`ReaderPage.ets:824`、`:1651`、`:1656`、`:2857`、`:2859`、`:2867`、`:2869`、`:2941`、`:2943`）。这 9 处必须同时改，否则测量、绘制与渲染三处会不一致——`:824`/`:1651` 用于行数与宽度测量，`:1656` 用于预留行高，`:2857` 起为实际绘制。

## D 翻页与手势交互

本地主体：`ReaderSettingsPage.ets:844-885`、`ReaderPage.ets:179-180`、`:1063`。

| 上游能力 | 上游位置 | 本地位置 | 状态 | 差异说明 | 验收方式 | 备注 |
| --- | --- | --- | --- | --- | --- | --- |
| 翻页动画类型 | `ReadBookConfig.kt:201` | `ReaderSettingsRepository.ets:182` | 已接 | 上游 `pageAnim` → 本地 `pageAnimation` | 切动画后翻页效果变化 | — |
| 翻页动画速度 | `ReadBookConfig.kt:206`（`Config.pageAnimSpeed`，`:565`） | `ReaderSettingsRepository.ets:183` | 已接 | 上游四档 240/300/360/540ms，本地 `ReaderPage.ets:1063` 按 `durationBySpeed[animationSpeed]` 折算 | 切「极速」后翻页更快 | — |
| 音量键翻页 | `ReadSettings.kt` | `ReaderSettingsRepository.ets:186` | 已接 | — | 按音量键翻页 | — |
| 长按按键连续翻页 | `ReadSettings.kt` | `ReaderSettingsRepository.ets:187` | 已接 | — | 长按音量键连续翻页 | — |
| 滑动不播动画翻页 | `ReadSettings.kt` | `ReaderSettingsRepository.ets:188` | 已接 | — | 快速滑动时跳过动画 | — |
| 下滑添加书签 | `ReadSettings.kt` | `ReaderSettingsRepository.ets:190` | 已接 | 本地仅对本地书生效（`ReaderPage.ets:1006` 判 `book.isLocal`） | 下滑后书签角标出现 | — |
| 九宫格点击区域 | `ReadSettings.kt` | `ReaderSettingsRepository.ets:177` | 已接 | 本地 `clickRegionActions` 存 9 格动作数组 | 改某格动作后点击该区执行新动作 | — |
| 点击图片行为 | `ReadSettings.kt` | `ReaderSettingsRepository.ets:176` | 已接 | — | 点插图后行为符合所选 | — |
| 自定义翻页按键 | `ReadSettings.kt` | `ReaderSettingsPage.ets:884` | 未接 | 点开 `showNotMigrated` 语义提示「按键映射面板尚未迁移」，无按键映射数据结构 | 绑键后按键触发对应动作 | — |
| 选中文字菜单 | `ReadSettings.kt` | `ReaderSettingsPage.ets:885` | 未接 | 点开提示「文本操作菜单配置尚未迁移」 | 选中文字后菜单项可按配置增减 | — |
| 鼠标滚轮翻页 | `ReadSettings.kt` | `ReaderSettingsPage.ets:848` | 未接 | 开关 `checked` 恒 `false` 且绑定 `showNotMigrated` | 接鼠标滚轮可翻页 | — |
| 朗读时允许音量键翻页 | `ReadSettings.kt:30` | `ReaderSettingsPage.ets:851` | 未接 | 走 `showNotMigrated('朗读时音量键翻页')` | — | 朗读在[范围之外](../PROJECT.md)，开关已上屏故判 `未接` |
| 横屏双页 | `ReadSettings.kt:26` | `ReaderSettingsPage.ets:844` | 未接 | 上游 `doubleHorizontalPage` 三值，本地打开详情面板但面板内无落盘 | 横屏时左右双页显示 | — |
| 进度条行为 | `ReadSettings.kt:27` | `ReaderSettingsRepository.ets:173` | 已接 | 上游 `progressBarBehavior` → 本地 `progressBehavior`，取值 `page`/`chapter`，面板 `ReaderSettingsPage.ets:847` | 拖动进度条按章节或页码定位 | — |
| 翻页触摸灵敏度 | `ReadSettings.kt:35` | — | 未接 | 上游 `pageTouchSlop` 默认 0，本地无字段 | 调节后误触减少 | — |
| 进度条模式 | `ReadSettings.kt:25` | — | 未接 | 上游 `readSliderMode` 默认 `"0"`，本地无字段 | 进度条显示形态变化 | — |
| 允许选择正文 | `ReadSettings.kt:46` | `ReaderSettingsRepository.ets:195` | 已接 | 开关在 `ReaderSettingsPage.ets:874`，阅读页 `ReaderPage.ets:169` 消费 | 长按正文出现选择菜单 | — |
| 展开文字菜单 | `ReadSettings.kt:51` | `ReaderSettingsPage.ets:1437` | 未接 | 仅 `expandTextMenuPreview` 页面 `@State`，无持久化 | 折叠菜单项多行展开 | — |
| 显示选择菜单图标 | `ReadSettings.kt:52` | — | 未接 | 上游 `showSelectMenuIcon` 默认 true，本地无字段 | 选择菜单显示图标 | — |
| 上次标记样式 | `ReadSettings.kt:54` | — | 未接 | 上游 `lastMarkingStyle` 记录上次标注样式，本地无字段 | 连续标注沿用上次样式 | — |

## E 菜单与主题外观

上游主体：`ReadBookConfig.kt:77-131`（`readMenu*` 系列 getter）、`Config` 内的 `@Transient menu*` 字段（`:643-658`）。
本地主体：`ReaderSettingsPage.ets:399-462`（`menuSettingsContent()`）、条目清单 `:1788-1840`。

**本块共同差异**：39 个条目里 37 个有控件、可点击、有 `@State` 承载，但没有一条写入 `ReaderSettingsRepository.ets`，也不驱动 `ReaderPage.ets` 渲染。判 `未接` 的依据是「退出设置页即丢失 + 阅读页外观不变」，不是「没有控件」。剩下 2 条（底栏按钮配置、标题栏操作按钮）是完整持久化链路，判 `已接`。

| 上游能力 | 上游位置 | 本地位置 | 状态 | 差异说明 | 验收方式 | 备注 |
| --- | --- | --- | --- | --- | --- | --- |
| 工具栏样式 | `ReadBookConfig.kt:99` | `ReaderSettingsPage.ets:1791` | 未接 | 三选一存 `@State menuBarStyleMode`（`:165`），仓储无字段 | 切「自定义」后菜单栏换配色 | — |
| 调色板风格 | `ReadBookConfig.kt:113` | `ReaderSettingsPage.ets:1792` | 未接 | 上游 `readMenuPaletteStyle`，本地条目存在无状态 | 切换后调色板按钮形态变化 | — |
| 菜单颜色来源 | `ReadBookConfig.kt:99` | `ReaderSettingsPage.ets:1793` | 未接 | 存 `@State menuColorMode`（`:166`），无持久化 | 切「自定义主题色」后配色来源变化 | — |
| 种子色 | `ReadBookConfig.kt:62` | `ReaderSettingsPage.ets:1794` | 未接 | 上游 `textAccentColor`/`Night`/`EInk` 三套，本地无字段 | 改种子色后强调色变化 | — |
| 菜单背景颜色 | `ReadBookConfig.kt:117` | `ReaderSettingsPage.ets:1795` | 未接 | 上游 `readMenuBgColor`/`Night` | 改色后菜单底变色 | — |
| 菜单容器颜色 | `ReadBookConfig.kt:123` | `ReaderSettingsPage.ets:1796` | 未接 | 上游 `readMenuContainerColor`/`Night` | 改色后菜单卡片变色 | — |
| 菜单强调颜色 | `ReadBookConfig.kt:120` | `ReaderSettingsPage.ets:1797` | 未接 | 上游 `readMenuAccentColor`/`Night` | 改色后选中态变色 | — |
| 显示亮度视图 | `ReadBookConfig.kt:94` | `ReaderSettingsPage.ets:1799` | 未接 | 上游 `showBrightnessView` 三值，本地无字段 | 切「竖向」后亮度条竖排 | — |
| 亮度条位置 | `ReadBookConfig.kt:95` | `ReaderSettingsPage.ets:1800` | 未接 | 上游 `brightnessVwPos` | 切位置后亮度条换到另一端 | — |
| 菜单栏边框 | `ReadBookConfig.kt:88` | `ReaderSettingsPage.ets:1802` | 未接 | 存 `@State menuBorderEnabled`（`:168`），无持久化 | 开关后菜单出现描边 | — |
| 菜单栏边框宽度 | `ReadBookConfig.kt:115` | `ReaderSettingsPage.ets:1803` | 未接 | 上游 `readMenuBorderWidth` 夹取 0–4 | 调宽后描边变粗 | — |
| 菜单栏边框颜色 | `ReadBookConfig.kt:88-89` | `ReaderSettingsPage.ets:1804` | 未接 | 上游 `readMenuBorderColor`/`Night` | 改色后描边变色 | — |
| 菜单模糊半径 | `ReadBookConfig.kt:109` | `ReaderSettingsPage.ets:1806` | 未接 | 上游夹取 0–32 | 调半径后背景模糊程度变化 | — |
| 菜单模糊透明度 | `ReadBookConfig.kt:110` | `ReaderSettingsPage.ets:1807` | 未接 | 上游夹取 0–100 | 调透明度后模糊可见度变化 | — |
| 菜单文字颜色 | `ReadBookConfig.kt:90-91` | `ReaderSettingsPage.ets:1808` | 未接 | 上游 `readMenuTextColor`/`Night` | 改色后菜单文字变色 | — |
| 菜单模糊颜色 | `ReadBookConfig.kt:111-112` | `ReaderSettingsPage.ets:1809` | 未接 | 上游 `readMenuBlurColor`/`Night` | 改色后模糊层色调变化 | — |
| 显示标题栏图标 | `ReadBookConfig.kt:92` | `ReaderSettingsPage.ets:1811` | 未接 | 存 `@State menuTitleIconsVisible`（`:484` 赋值），无持久化 | 关闭后标题栏图标消失 | — |
| 标题栏悬浮图标配置 | `ReadBookConfig.kt:146`、`:149` | `ReaderSettingsPage.ets:1812` | 未接 | 上游 `readMenuCustomIcons`、`titleBarCustomIcons` 两个 Map，本地无字段 | 换图标后标题栏图标变化 | — |
| 标题栏悬浮图标位置 | `ReadBookConfig.kt:116` | `ReaderSettingsPage.ets:1813` | 未接 | 上游 `titleBarIconPosition` 夹取 0–3 | 换位置后图标换到另一侧 | — |
| 悬浮图标液态玻璃按钮 | `ReadBookConfig.kt:87` | `ReaderSettingsPage.ets:1814` | 未接 | 上游 `readMenuFloatingIconLiquidGlass` | 开关后图标按钮出现玻璃质感 | — |
| 底栏按钮配置 | `ReadSettings.kt` | `ReaderSettingsRepository.ets:171-172` | 已接 | 链路完整：`ReaderSettingsPage.ets:470-472` 分流 → `handleMenuSettingsEntryClick()`（`:517-531`）→ `bottomActionConfigurationSheet()`（`:1897-1956`，显示开关 `:1936`、上下移 `:1938-1944`）→ `onBottomActionsChange` → `Index.ets:2218` → 写 `bottomActions`（`ReaderSettingsRepository.ets:804`） | 改显示与顺序后退出设置页，重进仍生效，阅读页底栏同步变化 | 只做显示/排序，未做长按动作自定义 |
| 底栏圆角 | `ReadBookConfig.kt:104` | `ReaderSettingsPage.ets:1821` | 未接 | 上游 `readMenuBottomCornerRadius` 夹取 0–32 | 调圆角后底栏卡片变圆 | — |
| 底栏悬浮 | `ReadBookConfig.kt:82` | `ReaderSettingsPage.ets:1822` | 未接 | 上游 `readMenuFloatingBottomBar` | 开关后底栏脱离屏幕边缘 | — |
| 底栏模糊 | `ReadBookConfig.kt:106` | `ReaderSettingsPage.ets:1823` | 未接 | 上游 `readMenuBottomBarBlurMode` 夹取 0–2 | 切三档后底栏背景变化 | — |
| 底栏模糊透明度 | `ReadBookConfig.kt:110` | `ReaderSettingsPage.ets:1824` | 未接 | 与「菜单模糊透明度」共用上游字段，本地无字段 | 调后底栏通透度变化 | — |
| 底栏模糊样式 | `ReadBookConfig.kt:108` | `ReaderSettingsPage.ets:1823` | 未接 | 上游 `readMenuBottomBarBlurStyle` 夹取 0–1（纯色/渐变） | 切「渐变」后底栏背景为渐变 | — |
| 底栏液态玻璃 | `ReadBookConfig.kt:86` | `ReaderSettingsPage.ets:1825` | 未接 | 上游 `readMenuBottomBarLiquidGlassButtons` | 开关后底栏出现玻璃质感 | — |
| 底栏按钮液态玻璃 | `ReadBookConfig.kt:86` | `ReaderSettingsPage.ets:1826` | 未接 | 同上字段的按钮级开关 | 开关后单个按钮出现玻璃质感 | — |
| 标题栏胶囊 | `ReadBookConfig.kt:85` | `ReaderSettingsPage.ets:1830` | 未接 | 上游 `readMenuTopBarTitleCapsule` | 开关后标题与章节合并成胶囊 | — |
| 标题栏模式 | `ReadSettings.kt:12` | `ReaderSettingsPage.ets:1831` | 未接 | 上游 `titleBarMode` 是字符串三态，本地选项为「完整信息/仅标题/标题与章节」（`:570`），仅存页面态 | 切「仅标题」后标题栏变矮 | — |
| 标题栏操作按钮 | `ReadSettings.kt` | `ReaderSettingsPage.ets:1832` | 已接 | 链路与底栏同构：`:470-472` → `handleMenuSettingsEntryClick()`（`:517-531`）→ `topActionConfigurationSheet()`（`:2006` 起）→ `onTopActionsChange` → `Index.ets:2227` → 写 `topActions`（`ReaderSettingsRepository.ets:805`） | 改显示与顺序后重进仍生效，阅读页顶栏同步变化 | 与底栏共用 `ReaderBottomActionConfig` |
| 标题栏紧凑 | `ReadBookConfig.kt:81` | `ReaderSettingsPage.ets:1833` | 未接 | 上游 `titleBarCompact`（布尔），与「标题栏模式」是两个独立字段，本地两个条目各自独立上屏、均无持久化 | 开关后标题栏收紧 | — |
| 标题栏图标样式 | `ReadBookConfig.kt:101` | `ReaderSettingsPage.ets:1834` | 未接 | 上游 `titleBarIconStyle` 夹取 0–2 | 切「描边」后图标变线框 | — |
| 顶栏模糊 | `ReadBookConfig.kt:105` | `ReaderSettingsPage.ets:1835` | 未接 | 上游 `readMenuTopBarBlurMode` 夹取 0–2 | 开关后顶栏背景模糊 | — |
| 顶栏模糊样式 | `ReadBookConfig.kt:107` | `ReaderSettingsPage.ets:1836` | 未接 | 上游 `readMenuTopBarBlurStyle` 夹取 0–1 | 切「渐变」后顶栏背景为渐变 | — |
| 顶栏液态玻璃按钮 | `ReadBookConfig.kt:83` | `ReaderSettingsPage.ets:1837` | 未接 | 上游 `readMenuTopBarLiquidGlassButtons` | 开关后顶栏按钮出现玻璃质感 | — |
| 合并标题栏按钮 | `ReadBookConfig.kt:84` | `ReaderSettingsPage.ets:1838` | 未接 | 上游 `readMenuTopBarMergeButtons` | 开关后相邻按钮合并 | — |
| 菜单镜头半径 | `ReadBookConfig.kt:114` | — | 未接 | 上游 `readMenuLensRadius` 夹取 0–48f，本地上屏条目都没有 | 调半径后高光范围变化 | — |
| 自动亮度 | `ReadBookConfig.kt:97` | — | 未接 | 上游 `brightnessAuto`，本地无字段无条目 | 开关后亮度跟随环境光 | — |
| 阅读栏样式 | `ReadSettings.kt:69` | — | 未接 | 上游 `readBarStyle` 默认 1；`BackupRepository.ets:244` 仅在导入时读取该键名，无渲染 | 切换后底栏形态变化 | — |
| 阅读栏样式跟随页面 | `ReadSettings.kt:68` | — | 未接 | 上游 `readBarStyleFollowPage`，本地无字段 | 底栏样式随背景变化 | — |
| 更多操作配置 | `ReadSettings.kt:121` | — | 未接 | 上游 `moreActionsConfig` 存「更多」面板的条目配置，本地无字段 | 增删「更多」面板项后生效 | 相关入口提示「更多操作配置保存失败」 |

## F 护眼与书签角标

本地主体：`ReaderSettingsRepository.ets:192-204`、页面区块 `:349-352`、`:1660-1663`。

| 上游能力 | 上游位置 | 本地位置 | 状态 | 差异说明 | 验收方式 | 备注 |
| --- | --- | --- | --- | --- | --- | --- |
| 护眼模式开关 | `EyeProtection.kt` | `ReaderSettingsRepository.ets:197` | 已接 | — | 开启后屏幕泛黄 | — |
| 自动夜间切换 | `EyeProtection.kt` | `ReaderSettingsRepository.ets:198` | 已接 | — | 到点后自动切夜间背景 | — |
| 定时区间开关 | `EyeProtection.kt` | `ReaderSettingsRepository.ets:199` | 已接 | — | 开关后按区间生效 | — |
| 色温强度 | `EyeProtection.kt` | `ReaderSettingsRepository.ets:200` | 已接 | 本地默认 50 | 调强度后泛黄程度变化 | — |
| 起始时间 | `EyeProtection.kt` | `ReaderSettingsRepository.ets:201` | 已接 | 本地默认 `'22:00'` | 改时间后生效时刻变化 | — |
| 结束时间 | `EyeProtection.kt` | `ReaderSettingsRepository.ets:202` | 已接 | 本地默认 `'07:00'` | 改时间后失效时刻变化 | — |
| 书签角标大小 | `ReadSettings.kt` | `ReaderSettingsRepository.ets:192` | 已接 | — | 调大小后角标尺寸变化 | — |
| 自定义书签角标图片 | `ReadSettings.kt` | `ReaderSettingsRepository.ets:194` | 已接 | 选图后存路径，`:1660` 可选择、`:1663` 可恢复默认 | 选图后阅读页角标换成该图 | — |
| 护眼定时跨零点边界 | `EyeProtection.kt` | `Index.ets:2127-2137` | 已接 | `:2136` 对 `start > end` 走 `current >= start \|\| current < end` 分支，23:00–07:00 跨零点正确生效；起止相等时恒生效（`:2133`）、解析失败时恒生效（`:2132`） | 设 22:00–07:00 后凌晨 2 点仍泛黄 | 生效判定在 `Index.ets`，不在设置页 |

## G 页边距

本地主体：`ReaderPaddingSettings`（`ReaderSettingsRepository.ets:100-111`）、默认值 `:115-117`。

| 上游能力 | 上游位置 | 本地位置 | 状态 | 差异说明 | 验收方式 | 备注 |
| --- | --- | --- | --- | --- | --- | --- |
| 正文上边距 | `ReadBookConfig.kt:607` | `ReaderSettingsRepository.ets:100` | 已接 | 上游默认 6 | 调后正文上留白变化 | — |
| 正文下边距 | `ReadBookConfig.kt:604` | `ReaderSettingsRepository.ets:101` | 已接 | — | 调后正文下留白变化 | — |
| 正文左边距 | `ReadBookConfig.kt:605` | `ReaderSettingsRepository.ets:102` | 已接 | 上游默认 16 | 调后左侧留白变化 | — |
| 正文右边距 | `ReadBookConfig.kt:606` | `ReaderSettingsRepository.ets:103` | 已接 | — | 调后右侧留白变化 | — |
| 页眉上/下边距 | `ReadBookConfig.kt:610`、`:608` | `ReaderSettingsRepository.ets:104-105` | 已接 | 上游默认 0 | 调后页眉与正文间距变化 | — |
| 页眉左/右边距 | `ReadBookConfig.kt:611`、`:609` | `ReaderSettingsRepository.ets:106-107` | 已接 | — | 调后页眉左右缩进变化 | — |
| 页脚上/下边距 | `ReadBookConfig.kt:614`、`:612` | `ReaderSettingsRepository.ets:108-109` | 已接 | — | 调后页脚与正文间距变化 | — |
| 页脚左/右边距 | `ReadBookConfig.kt:615`、`:613` | `ReaderSettingsRepository.ets:110-111` | 已接 | — | 调后页脚左右缩进变化 | — |

## 一、真缺失的字段清单

**本节与 A–G 明细表是两个不同的计数口径，不可相加。** A–G 按「一次用户可感知的操作」计 189 行（98 行未接）；本节按「上游声明名」计字段差集 112 项。一个操作可能对应多个字段（「菜单背景颜色」对应 `readMenuBgColor` + `readMenuBgColorNight`），也有上游字段在本地连条目都没有（`readMenuLensRadius`、`brightnessAuto`）。硬凑成一个数字会反复返工，因此两处各记各的。

字段差集的计算过程：

| 项 | 数 |
| --- | --- |
| 上游 `ReadBookConfig.kt` 声明并集（全文 1054 行） | 210 |
| 上游 `ReadSettings.kt` 声明（全文 122 行） | 114 |
| 两文件合并去重后并集 | 267 |
| 本地 `ReaderSettingsSnapshot` 有效字段（自身 63 + 继承 `ReaderInfoSettings` 26） | 89 |
| 两边同名（上游名直接命中本地） | 61 |
| 直接差集（上游有、本地无同名） | 206 |
| − 内部辅助属性（见下） | 26 |
| − EInk 专用（见 1.1） | 8 |
| − `@Transient` 颜色缓存（见 1.2） | 15 |
| − `readMenuXxx` 与 `Config` 内 `menuXxx` 的语义重复对 | 7 |
| − 改名已接（见第二节） | 15 |
| − 9 个 `clickAction*` 合并为 `clickRegionActions[]` | 9 |
| − `paddingDisplayCutouts` 之外的页边距 12 项并入 `paddingSettings` 容器 | 12 |
| − 非配置项（`id` 为进程内列表身份、`name` 为书名字段） | 2 |
| **= 字段级差集** | **112** |

26 项内部辅助属性（不是用户可配置项，逐项列出便于复核）：

- 上下文引用 2：`config`、`readSettings`。
- 颜色/字号解析结果 11：`resolvedMenuAccentColor`、`resolvedMenuBgColor`、`resolvedMenuBlurColor`、`resolvedMenuBorderColor`、`resolvedMenuContainerColor`、`resolvedMenuTextColor`、`resolvedTipFooterColor`、`resolvedTipHeaderColor`、`resolvedTitleColor`、`resolvedTitleSize`、`resolvedTitleSizeRelative`。
- 配置容器与存取 5：`defaults`、`background`、`menuColor`、`styleSelect`、`durConfig`。
- 导入导出与共享 3：`exportConfig`、`configFilePath`、`shareConfigFilePath`（`shareConfig` 另计 1）。
- 枚举与常量名表 3：`tipColorNames`、`tipDividerColorNames`、`isMiddleTitle`。
- 状态判断 2：`isNight`、`shareConfig`。

`readMenuXxx` 与 `Config` 内 `menuXxx` 的 7 对语义重复：`readMenuBgColor`、`readMenuBgColorNight`、`readMenuBottomCornerRadius`、`readMenuIconItemsPerRow`、`readMenuIconRowCount`、`readMenuIconShowText`、`readMenuIconStyle`——两边各声明一次，按一项计。


复核脚本（必须整段跑，不能截取文件局部——早前用 `awk 'NR>=500 && NR<=900'` 只读了 1054 行里的 400 行，漏掉六成字段，是本节旧数据错误的根源）：

```python
import io, re

UP = 'legado-with-MD3/app/src/main/java/io/legado/app/help/config/ReadBookConfig.kt'
LO = 'legado-with-md3-harmonyos/entry/src/main/ets/data/ReaderSettingsRepository.ets'
DECL = re.compile(r'^\s+(?:private\s+|internal\s+|public\s+)?(?:val|var)\s+([a-zA-Z0-9_]+)')

cf, gf, in_cfg, end = set(), set(), False, 0
for i, line in enumerate(io.open(UP, encoding='utf-8').read().split('\n'), 1):
    if 'data class Config(' in line:
        in_cfg = True
        continue
    if in_cfg:
        # 结束行是 '    ) {' 而不是 '    )'，正则漏写 \{ 会让边界识别失败
        if re.match(r'^    \)\s*\{?\s*$', line):
            in_cfg, end = False, i
            continue
        m = DECL.match(line)
        if m:
            cf.add(m.group(1))
        continue
    if i <= end:
        continue
    m = DECL.match(line)
    if m:
        gf.add(m.group(1))

lo = set()
for line in io.open(LO, encoding='utf-8'):
    m = re.match(r'^  ([a-zA-Z][a-zA-Z0-9]*)\??:', line)
    if m:
        lo.add(m.group(1))

print(len(cf), len(gf), len(cf | gf), len(rs), len(cf | gf | rs), len(lo))
# 109 181 210 114 267 89
```

`readMenuXxx` 与 `Config` 内 `menuXxx` 的 7 对语义重复：`readMenuBgColor`、`readMenuBgColorNight`、`readMenuBottomCornerRadius`、`readMenuIconItemsPerRow`、`readMenuIconRowCount`、`readMenuIconShowText`、`readMenuIconStyle`——两边各声明一次，按一项计。

### 1.1 EInk 专项（8 项）：判 `不适用`

`bgStrEInk`、`bgTypeEInk`、`darkStatusIconEInk`、`textColorEInk`、`textAccentColorEInk`、`pageAnimEInk`、`textColorIntEInk`、`textAccentColorIntEInk`。

其中 `textColorIntEInk`、`textAccentColorIntEInk` 同时也是颜色缓存，按 EInk 归类计数，不与 1.2 重复计。

理由统一：EInk 是墨水屏设备形态的专用配色与动画，属 [项目队列](../PROJECT.md)「范围之外」的「额外设备形态适配」。本地只建模日/夜两套（`paperIndex`/`dayPaperIndex`/`nightPaperIndex`，`ReaderSettingsRepository.ets:162-164`）。

### 1.2 颜色缓存字段（15 项）：不是缺口

`hex`、`initAccentColorInt`、`initColorInt`、`menuAcColorInt`、`menuAcColorNightInt`、`menuBgColorInt`、`menuBgColorNightInt`、`shadowColorInt`、`shadowColorNightInt`、`textColorInt`、`textColorIntNight`、`textAccentColorInt`、`textAccentColorIntNight`、`underlineColorInt`、`underlineColorNightInt`。

这些是上游 `Config` 里的 `@Transient` 解析缓存（`ReadBookConfig.kt:683-710`），把颜色字符串解析成 `Int` 后缓存，不属于用户可配置项。本地直接用颜色字符串（`textShadowColor`、`underlineColor` 存 `string`），不需要等价物。**不列入缺口计数。**

### 1.3 字段级差集（112 项）

按字段组列出，不按 A–G 块归类——块归属以明细表的实际行为准，这里只给完整名单，便于逐项消账。

| 字段组 | 条数 | 字段 |
| --- | --- | --- |
| 背景与颜色 | 9 | `bgAlpha`、`bgStr`、`bgStrNight`、`bgType`、`bgTypeNight`、`textColor`、`textColorNight`、`textAccentColor`、`textAccentColorNight` |
| 状态栏 | 2 | `darkStatusIcon`、`darkStatusIconNight` |
| 下划线与虚线 | 4 | `underlinePadding`、`underlineExtend`、`dottedBase`、`dottedRatio` |
| 标题排版 | 14 | `titleMode`、`titleSize`、`titleSizeRelative`、`titleBold`、`titleColor`、`titleColorNight`、`titleLineSpacingExtra`、`titleLineSpacingSub`、`titleTopSpacing`、`titleBottomSpacing`、`titleSegType`、`titleSegScaling`、`titleSegDistance`、`titleSegFlag` |
| 菜单颜色 | 14 | `menuAcColor`、`menuAcColorNight`、`menuBgColor`、`menuBgColorNight`、`readMenuAccentColor`、`readMenuAccentColorNight`、`readMenuBlurColor`、`readMenuBlurColorNight`、`readMenuBorderColor`、`readMenuBorderColorNight`、`readMenuContainerColor`、`readMenuContainerColorNight`、`readMenuTextColor`、`readMenuTextColorNight` |
| 菜单样式选择 | 2 | `readMenuColorMode`、`readMenuPaletteStyle` |
| 菜单模糊与边框数值 | 5 | `readMenuBlurAlpha`、`readMenuBlurRadius`、`readMenuBorderWidth`、`readMenuLensRadius`、`menuBottomCornerRadius` |
| 菜单布局与玻璃效果 | 12 | `menuBottomBottomMargin`、`menuBottomHorizontalMargin`、`readMenuBottomBarBlurMode`、`readMenuBottomBarBlurStyle`、`readMenuBottomBarLiquidGlassButtons`、`readMenuFloatingBottomBar`、`readMenuFloatingIconLiquidGlass`、`readMenuTopBarBlurMode`、`readMenuTopBarBlurStyle`、`readMenuTopBarLiquidGlassButtons`、`readMenuTopBarMergeButtons`、`readMenuTopBarTitleCapsule` |
| 标题栏与图标 | 8 | `readMenuCustomIcons`、`showMenuIcon`、`showTitleBarIcons`、`titleBarCompact`、`titleBarCustomIcons`、`titleBarIconPosition`、`titleBarIconStyle`、`titleBarMode` |
| 亮度与滑块 | 5 | `brightnessAuto`、`brightnessVwPos`、`readBrightness`、`readSliderMode`、`showBrightnessView` |
| 阅读模式与排版开关 | 4 | `comicStyleSelect`、`readBodyToLh`、`readStyleSelect`、`useZhLayout` |
| 朗读提醒 | 1 | `readAloudDetachReminderEnabled` |
| 高亮规则（独立仓储） | 1 | `highlightRules` |
| 仅见于 `ReadSettings.kt` 的其余字段 | 31 | `adaptSpecialStyle`、`autoChangeSource`、`autoSuggestDayNight`、`chineseConverterType`、`defaultSourceChangeAll`、`disableReturnKey`、`doubleHorizontalPage`、`expandTextMenu`、`fontFolder`、`lastMarkingStyle`、`menuAlpha`、`moreActionsConfig`、`mouseWheelPage`、`nextKeys`、`optimizeRender`、`pageTouchSlop`、`paddingDisplayCutouts`、`preDownloadNum`、`preDownloadNumPrev`、`prevKeys`、`readBarStyle`、`readBarStyleFollowPage`、`readUrlInBrowser`、`selectVibrator`、`showReadTitleAddition`、`showSelectMenuIcon`、`sliderVibrator`、`textSelectMenuConfig`、`themeGridColumns`、`volumeKeyPageOnPlay`、`useNewTocSheet` |

9 + 2 + 4 + 14 + 14 + 2 + 5 + 12 + 8 + 5 + 4 + 1 + 1 + 31 = 112。

其中 `highlightRules` 已由独立仓储承接（见 1.4），真正需要在 `ReaderSettingsRepository.ets` 补齐的是 **111 项**。

### 1.4 既不是缺口也不是改名的两种情况

- **改名已接 15 项**：`lineSpacingExtra`、`menuIconItemsPerRow`、`menuIconRowCount`、`menuIconShowText`、`menuIconStyle`、`pageAnim`、`pageAnimSpeed`、`shadowColor`、`shadowColorN`、`textSize`、`useUnderline`、`progressBarBehavior`、`clickImgWay`、`tocUiUseReplace`、`tocCountWords`，见第二节映射表。
- **数组合并 9 项**：`clickActionTL`…`clickActionBR` 九个整型字段由本地一个 `clickRegionActions: string[]` 承接（`ReaderSettingsRepository.ets:177`，默认值 `:243-245`，消费 `ReaderPage.ets:1125`）。字段名比对会把这 9 项全判缺失，实际是已接。
- **容器合并 12 项**：`ReadBookConfig.kt:604-615` 的 12 个页边距字段由本地 `ReaderPaddingSettings` 容器承接（`ReaderSettingsRepository.ets:99-112`，默认值 `:114-118`）。注意 `ReadSettings.kt:11` 的 `paddingDisplayCutouts` 是另一个字段，**不在此列**，仍判未接。
- **非配置项 2 项**：`name`（`ReadBookConfig.kt:536`，书名字段）与 `id`（`:659`，`@Transient` 进程内列表身份，注释明写「不写入主题包」）。
- **另有独立仓储 1 项**：`highlightRules`（`ReadBookConfig.kt:656`）不在 `ReaderSettingsRepository.ets` 中，但本地对应 `entry/src/main/ets/model/ReaderHighlightRule.ets`、`data/ReaderHighlightRuleRepository.ets`、`data/ReaderHighlightRuleEngine.ets` 三个文件，属高亮规则的独立模块。它在 1.3 的 112 项里占一格，但不需补仓储字段。

> 1.3 的 112 项与 A–G 明细表的 189 行是两个口径：明细表按「一次用户可感知的操作」计，字段表按「上游声明名」计。**两处数字不可相加，也不必相加。**

## 二、改名映射表

下列上游字段在本地以不同名字落地，语义等价，**不属缺口**。命名不一致会给后续比对带来误判，记录在此。

| 上游字段 | 上游位置 | 本地字段 | 本地位置 | 说明 |
| --- | --- | --- | --- | --- |
| `textSize` | `ReadBookConfig.kt:246` | `fontSize` | `ReaderSettingsRepository.ets:139` | 字号 |
| `textColor` / `textColorNight` | `ReadBookConfig.kt:55-56` | — | — | **不属改名，是真缺口。** 本地正文颜色由 `ReaderPage.ets:2710-2713` 的 `getReadingTextColor()` 硬编码：背景为 `#000000`/`#343832`/`#3C3F43` 时返回 `#D8D8DC`，否则 `#38383B`。用户不可配 |
| `textSize`（标题侧） | `ReadBookConfig.kt:269` | 无字段 | `ReaderPage.ets:824` 硬编码 `fontSize + 4` | 这一条是真缺口，不是改名 |
| `lineSpacingExtra` | `ReadBookConfig.kt:252` | `lineSpacing` | `ReaderSettingsRepository.ets:141` | 行距 |
| `shadowColor` / `shadowColorN` | `ReadBookConfig.kt:543-544` | `textShadowColor` / `textShadowColorN` | `ReaderSettingsRepository.ets:153-154` | 阴影色 |
| `pageAnim` | `ReadBookConfig.kt:201` | `pageAnimation` | `ReaderSettingsRepository.ets:182` | 翻页动画 |
| `pageAnimSpeed` | `ReadBookConfig.kt:565` | `animationSpeed` | `ReaderSettingsRepository.ets:183` | 翻页速度 |
| `readMenuIconShowText` | `ReadBookConfig.kt:77` | `showBottomActionText` | `ReaderSettingsRepository.ets:167` | 底栏图标文字 |
| `readMenuIconStyle` | `ReadBookConfig.kt:100` | `bottomIconStyle` | `ReaderSettingsRepository.ets:168` | 底栏图标样式 |
| `readMenuIconItemsPerRow` | `ReadBookConfig.kt:102` | `bottomItemsPerRow` | `ReaderSettingsRepository.ets:169` | 每行图标数 |
| `readMenuIconRowCount` | `ReadBookConfig.kt:103` | `bottomRowCount` | `ReaderSettingsRepository.ets:170` | 图标行数 |
| `bgStr` / `bgStrNight` | `ReadBookConfig.kt:537-538` | `dayPaperIndex` / `nightPaperIndex` | `ReaderSettingsRepository.ets:163-164` | 本地用索引指向内置配色，上游存颜色字符串 |
| `useUnderline` | `ReadSettings.kt:24` | `underline` | `ReaderSettingsRepository.ets:155` | 下划线开关，`ReaderPage.ets:2159` 驱动 `TextDecorationType` |
| `progressBarBehavior` | `ReadSettings.kt:27` | `progressBehavior` | `ReaderSettingsRepository.ets:173` | 进度条定位方式，取值 `page`/`chapter` |
| `clickImgWay` | `ReadSettings.kt:48` | `clickImageBehavior` | `ReaderSettingsRepository.ets:176` | 点击图片行为，存储键仍写 `clickImgWay` |
| `tocUiUseReplace` | `ReadSettings.kt:62` | `tocUseReplace` | `ReaderSettingsRepository.ets:174` | 目录应用替换规则，存储键仍写 `tocUiUseReplace` |
| `tocCountWords` | `ReadSettings.kt:63` | `tocShowWordCount` | `ReaderSettingsRepository.ets:175` | 目录显示字数，存储键仍写 `tocCountWords` |
| `clickActionTL`…`clickActionBR` | `ReadSettings.kt:70-78` | `clickRegionActions` | `ReaderSettingsRepository.ets:177` | 9 个整型字段 → 1 个 9 元素字符串数组 |

## 三、阻塞项与后续顺序

盘点结论指向三个互不重叠的缺口，按收益排序：

1. **E 块菜单外观 40 行未接**：全部有控件无持久化。所需字段都是纯 UI 参数（颜色、圆角、模糊半径、玻璃开关），不触碰渲染引擎与排版算法，是唯一可以整块推进的部分，字段明细见 1.3 的「菜单」与「标题栏与图标」各组。前置条件：先在 `ReaderSettingsRepository.ets` 补齐字段与 `save` 分支，再把 `ReaderSettingsPage.ets` 的 `@State` 改为读仓储。可照抄同块已接的两条（`bottomActions`/`topActions`，`ReaderSettingsRepository.ets:804-805`）的链路。
2. **C 块标题排版 14 项**：需要同时改 `ReaderPage.ets` 的 9 处 `fontSize + 4` 硬编码（`:824`、`:1651`、`:1656`、`:2857`、`:2859`、`:2867`、`:2869`、`:2941`、`:2943`），并新增 `titleSizeRelative` 三态语义（上游回落规则见 `ReadBookConfig.kt:660-668`）。改动面比 E 块小但风险高，属排版视觉回归。
3. **C 块正文与背景 6 行 + 下划线虚线 4 行**：正文与背景 6 行对应 11 个字段（正文日/夜颜色 2、正文强调色 2、背景透明度 1、背景自定义 4、白天暗色状态栏 2），下划线虚线 4 行对应 4 个字段，均为单点参数，适合随其它模块顺带补齐。其中**正文日/夜颜色（`ReaderPage.ets:2710-2713` 的 `getReadingTextColor()` 硬编码）优先做**——它是用户最容易察觉的「不能改字色」，且与背景预设（`READER_BACKGROUND_STYLES`，`ReaderSettingsRepository.ets:339-346`）天然配套。

三处阻塞共 40 + 14 + 10 = 64 行未接（明细表口径），占明细表 98 行未接的多数。余下 34 行分布在 A 块 21 行、B 块 1 行、C 块 2 行、D 块 10 行，均为单点占位开关，不单独列阻塞。字段口径的 112 项见 1.3，与这里的行数不可相加。

未列为阻塞项的两类：EInk 相关 8 项判 `不适用`（范围之外）；颜色缓存字段 15 项不是缺口（上游 `@Transient` 解析缓存，本地用字符串不需要等价物）。

## 四、覆盖证明

本表对应 ZIP 类别 `readConfig`。按 [KEYWORDS.md](KEYWORDS.md) 的检索词 `ReadBookConfig|ReadSettings` 命中 **76 个上游 `.kt` 文件**，本节把它们逐个分配：要么落到上面 A–G 某块的具体行，要么写明排除理由。判定可复跑：

```bash
bash scripts/upstream-surface.sh --coverage readConfig docs/parity/READER-CONFIG.md <上游根>
```

> **旧关键词的教训**：本表原先用 `backupIgnoreReadConfig` 检索，只命中 2 个文件（`help/storage/BackupConfig.kt`、`help/storage/Backup.kt`），等于「2 个文件全过 = 覆盖通过」，永远测不出缺口。已改用两个配置来源文件的名字作检索词。

### 4.1 映射到 A–G 块的行（36 个）

| 上游文件 | 命中内容 | 落到哪一行 |
| --- | --- | --- |
| `help/config/ReadBookConfig.kt` | 1054 行，单本书可覆盖的 `Config` | A–G 全部 189 行的「上游位置」列主体 |
| `domain/model/settings/ReadSettings.kt` | 122 行，全书统一设置 114 字段 | A–G 中约 30 行的「上游位置」列（其余在 C 块与 1.3 差集） |
| `ui/config/readConfig/ReadConfig.kt` | `:23` 已 `@Deprecated`，指向 `ReadSettingsGateway` | A 块阅读配置总入口 |
| `ui/config/readConfig/ReadConfigViewModel.kt` | 225 行，配置总页状态 | A 块阅读配置总入口 |
| `ui/book/read/sheet/TypographyTabs.kt` | 1250 行，五个 tab：`TypographyBodyTab`（`:265` 正文）、`TypographyTitleTab`（`:432` 标题）、`TypographyHeaderTab`（`:676` 页眉）、`TypographyFooterTab`（`:792` 页脚）、`TypographyMarginTab`（`:919` 页边距） | C 块正文排版（`TypographyBodyTab`）、C 块标题排版（`TypographyTitleTab`）、B 块页眉页脚（`TypographyHeaderTab`/`TypographyFooterTab`）、G 块页边距（`TypographyMarginTab`） |
| `ui/book/read/sheet/TypographyTabs.kt` 内的 `TipPositionDropdown`（`:200`）与 `PaddingSliders`（`:219`） | 页眉页脚位置下拉与四向内边距滑块 | B 块「页眉/页脚位置」、G 块「四向内边距」 |
| `constant/ReadTipType.kt` | `:6-10` 注释说明这批值是编译期常量、不是配置状态，真正的配置项是 `ReadBookConfig.tipHeaderLeft` 等六项 | B 块「页眉/页脚显示内容」六项 |
| `ui/book/read/sheet/MoreConfigSheet.kt` | 466 行「更多设置」面板，含 `R.string.more_setting`、`progress_bar_behavior`、`click_regional_config`、`custom_page_key`、`bookmark_badge*`、`eye_protection` 等 | D 块全部 20 行（翻页行为、点击区域、自定义按键、鼠标滚轮、触摸灵敏度）+ F 块书签角标 9 行 |
| `ui/book/read/sheet/ClickActionConfigSheet.kt` | 230 行，`ClickAreaCell` 九宫格动作选择，含 12 个动作字符串 | D 块「九宫格点击区域」 |
| `ui/book/read/sheet/PageKeyConfigSheet.kt` | 147 行，`custom_page_key`/`prev_page_key`/`next_page_key`/`page_key_set_help`/`reset` | D 块「自定义翻页按键」 |
| `ui/book/read/sheet/AutoReadSheet.kt` | 173 行，`auto_page_speed`/`chapter_list`/`setting`/`stop` | A 块「自动阅读」相关行 |
| `ui/book/read/sheet/CustomTipTarget.kt` | 58 行，`ConfigUpdate` 派发到 `ReadBookConfig` | B 块页眉页脚自定义入口 |
| `ui/book/read/sheet/HighlightRuleEditSheet.kt` | 1389 行，高亮规则编辑面板 | 1.4「独立仓储 1 项」`highlightRules` |
| `ui/config/themeConfig/ThemeConfigViewModel.kt` | 618 行，主题配置状态 | E 块主题外观 42 行 |
| `ui/replace/ReplaceRuleViewModel.kt` | 497 行，替换净化规则状态（`PreferKey.replaceSortMode` 在此） | E 块「替换净化」相关行 |
| `ui/book/read/ReadBookViewModel.kt` | 2748 行，阅读页主状态 | A–G 全部行的「消费侧」主体 |
| `ui/book/read/ReadBookController.kt` | 3327 行，阅读页控制器 | A–G 全部行的运行时行为 |
| `ui/book/read/ReadBookContract.kt` | 2011 行，`Style config (reactive state for ReadBookConfig)`（`:337`）、`Menu config`（`:340`） | E 块菜单外观与主题的意图定义 |
| `ui/book/read/ReadBookLoadDelegate.kt` | 444 行，加载时读取 `ReadSettingsRepository` | A 块阅读界面初始化 |
| `ui/book/read/ReadStyleDelegate.kt` | 505 行，排版样式变更处理 | C 块正文排版 49 行 |
| `ui/book/read/ReadConfigUpdateDelegate.kt` | 898 行，配置变更落盘管线 | A 块配置写入链路 |
| `ui/book/read/ReadButtonConfigDelegate.kt` | 231 行，底栏/顶栏按钮配置 | E 块「底栏按钮配置」「标题栏操作按钮」两条已接 |
| `ui/book/read/ReadContentEditDelegate.kt` | 267 行，正文编辑 | C 块「正文编辑」相关行 |
| `ui/book/read/ReadHighlightRuleDelegate.kt` | 386 行，高亮规则应用（`:64` `ReadBookConfig.durConfig.name`） | 1.4「独立仓储 1 项」`highlightRules` |
| `ui/book/read/ReadBookColorTheme.kt` | 350 行，`:76` `ReadStyleResolver.currentBackground(ReadBookConfig.durConfig, ...)` | E 块主题外观、C 块背景 6 行 |
| `ui/book/read/MarkingDelegate.kt` | 286 行，`:99` 按 `durConfig.name` 加载高亮规则 | 1.4「独立仓储 1 项」`highlightRules` |
| `ui/book/read/BookmarkBadgeDelegate.kt` | 91 行，书签角标图片与尺寸 | F 块书签角标 9 行 |
| `ui/book/read/ReadAiDelegate.kt` | 1417 行，`:1372` `ReadBookConfig.paragraphIndent` | C 块「段首缩进」 |
| `ui/book/toc/TocViewModel.kt` | 1141 行，目录页状态（读 `ReadSettingsRepository`） | G 块页边距之外的目录相关配置（`tocShowWordCount` 等） |
| `help/config/ReadStyleResolver.kt` | 197 行，`:62-65` 按 `ReadBookConfig.Config` 解析最终样式 | C 块正文排版、E 块主题 |
| `help/config/AppConfig.kt` | 125 行，`:31` `readGateway` 进程内快照 | A 块配置读取链路 |
| `feature/reader/core/source/ReaderBodyOnlyFilter.kt` | `:56` 注释要求与 `ReadSettings.adaptSpecialStyle` 同源 | C 块「适配特殊样式」 |
| `data/repository/ReadSettingsRepository.kt` | 742 行，配置仓储实现 | A–G 全部行的「写入侧」 |
| `domain/gateway/ReadSettingsGateway.kt` | 18 行，`interface ReadSettingsGateway { val currentSettings: ReadSettings }` | A 块配置读取接口 |
| `data/repository/ReadStyleConfigStore.kt` | 142 行，`:10-13` 写面收进 gateway 后 `ReadBookConfig` 只剩「选哪一份 + 怎么读」 | E 块主题存储链路 |
| `data/repository/ReadStyleRepository.kt` | 291 行，`:29`/`:31` 配置文件路径（`ReadBookConfig.configFileName`/`shareConfigFileName`） | E 块主题导入导出 |
| `data/repository/ReadBookStyleConfigRepository.kt` | 393 行，`:91-93` 预设复制到 `ReadBookConfig.durConfig` | E 块主题预设 14 项 |

### 4.2 已排除：渲染与分页管线，无独立界面（8 个）

`feature/reader/legacy/LegacyReaderChapterPaginator.kt`（403 行，`:132` `titleMode: Int = ReadBookConfig.titleMode`）、`LegacyReaderPageDecorationFactory.kt`（340 行）、`LegacyReaderPaginationStyleFactory.kt`（119 行）、`LegacyReaderStyleRangeMapper.kt`（421 行，`:337` 注释「即 `ReadBookConfig.textColor`，不是写死的主题绿」）、`model/FullBookPaginator.kt`（97 行，`:48` `tipHeaderLeft`）、`model/ReadSessionState.kt`（45 行，`:32` `durConfig.curBgDrawable`）、`domain/model/settings/ReadStyleState.kt`（29 行，`:10` 只投影排版底座）、`model/ReadBook.kt`（在 4.1 已分配，此处单列说明它是阅读页模型）。

**排除理由**：这些是 Compose 自绘管线的分页与装饰实现，本地对应物是 `pages/ReaderPage.ets` 的 ArkUI 声明式渲染（无「分页器」「装饰工厂」这种中间层）。上游把配置读在管线内部，本地读在页面里，**同一批配置项在 A–G 块已有行**，此处不重复列行。

### 4.3 已排除：数据层接线与初始化，界面由别处承载（10 个）

`di/appModule.kt`（862 行，`:374` 把 `ReadBookConfig.titleMode` 注入 provider）、`domain/usecase/AddBookUseCase.kt`（80 行，`:17` 注入 gateway）、`domain/usecase/ChangeBookSourceUseCase.kt`（249 行，`:76` 注入 gateway）、`data/repository/SearchContentRepository.kt`（321 行，`:26` 注入 gateway）、`help/book/BookExtensions.kt`（747 行，`:54` `readGateway`）、`help/book/BookHelp.kt`（1116 行，`:75` `readGateway`）。

**排除理由**：`ReadSettingsGateway` 的注入点，没有自己的界面。它们消费的配置项在 A–G 块已有行（换源相关在 A 块、搜索内容在 D 块）。

另有 4 个同类，但各有额外分量，单列在这里：

- `App.kt`（385 行，`:132` `ReadBookConfig.initialize(...)`）——**应用启动时初始化配置**。本地对应 `entryability/EntryAbility.ets` 里 `RdbMigration`/`RdbCleanup` 之后由 `pages/Index.ets` 载入 `ReaderSettingsRepository`，无独立界面。
- `data/entities/Book.kt`（515 行，`:280`/`:282` 读 `ReadBookConfig.pageAnim` 作为按书翻页动画的回落）——**实体层的配置回落**。本地对应 `model/Book.ets` 的 `readConfig` JSON 字段，已在 [BOOKSHELF.md](BOOKSHELF.md) B 块「阅读配置覆盖」行记录。
- `help/storage/Backup.kt`（406 行，`:94-95`/`:233`/`:237` 备份 `configFileName` 与 `shareConfigFileName`）与 `help/storage/Restore.kt`（609 行，`:347` 恢复 `configFileName`）——**配置文件的备份与恢复**。本地对应 `data/BackupRepository.ets` 的 `config.xml` 读写，归备份模块，不在本表。

### 4.4 已排除：属别的 ZIP 类别（16 个）

朗读 10 个：`ui/book/read/ReadAloudDelegate.kt`（676 行）、`model/AudioPlay.kt`（481 行）、`service/HttpReadAloudService.kt`（2149 行）、`service/readaloud/ReadAloudBookSession.kt`（279 行）、`help/readaloud/cast/CastRenderOptions.kt`（104 行，`:102` `bound.contains(ReadBookConfig.durConfig.name)`）、`ui/book/audio/AudioPlayViewModel.kt`（370 行）、`ui/book/readaloud/ReadAloudPlayerMorphHost.kt`（306 行）、`ui/book/readaloud/casting/CastBubbleSheet.kt`（80 行，`:61` `textSize = ReadBookConfig.textSize`）、`ui/book/readaloud/player/ReadAloudConfigIntentMapper.kt`（145 行）、`ui/book/readaloud/player/ReadAloudPlayerViewModel.kt`（335 行）。朗读在[范围之外](../PROJECT.md)，归 `httpTTS` 类别。

漫画 3 个：`ui/book/manga/MangaReaderViewModel.kt`（1500 行）、`ui/book/manga/MangaSettingsPanel.kt`（862 行）、`data/repository/manga/MangaReaderActionRepository.kt`（259 行）。归 `mangaConfig` 类别。

其余 3 个：`ui/main/MainNavGraph.kt`（2017 行，`:1063` `initReadBookConfig(initRequest)` 只是导航参数传递，归导航）；`model/webBook/BookChapterList.kt`、`model/webBook/BookContent.kt`（网络书内容加载，归 `bookSource`）。

### 4.5 已排除：本地书与导出，界面由别的模块承载（6 个）

`model/localBook/LocalBook.kt`（649 行）、`model/localBook/TextFile.kt`（519 行）、`help/book/ContentProcessor.kt`（297 行）、`service/ExportBookService.kt`（1010 行）、`help/DefaultData.kt`（130 行，`:55` `readConfigs` 默认配置预设）、`help/JsExtensions.kt`（1220 行，`:1191` `getReadBookConfig()` 是书源脚本接口）。

**排除理由**：本地书导入/导出归 `localBook` 类别（见 [BOOKSHELF.md](BOOKSHELF.md)）；书源脚本接口归 `bookSource`；备份恢复归备份模块。它们读 `ReadBookConfig` 只是为了拿当前配置的副本，没有配置界面。

### 4.6 未分配

**0 个。** 76 个上游接触面文件全部分配完毕（映射到行 **36** 个 + 排除 **40** 个）。

---

## 维护

改本表时同步改两处：

- `entry/src/main/ets/data/ReaderSettingsRepository.ets` 的字段定义——本表「本地位置」一列直接引用其行号。
- [ZIP 兼容总账](STATUS.md) 的 `readConfig` 行——本表是它的明细表。

改完本表须重跑「盘面」与第一节的计数，两处数字必须与实际表格行数闭合。

新增上游字段时先跑第一节的复核命令，确认是「真缺失」还是「改名已接」再落表，避免把改名误记为缺口。
