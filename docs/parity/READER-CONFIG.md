# 阅读配置对照表

本表按 [模块对照要求](../CODE-CONVENTIONS.md) 第四节点完一次，行粒度是**一个界面上的一个可感知操作**（不是「与本功能相关的几个按钮」，见第四节「盘点单位是界面，不是按钮」）。
状态三值：`已接` / `未接` / `不适用`；`不适用` 写理由。**本表无 `待定` 行。**

> **r286 结构性重盘（2026-10-30）**
>
> **一、盘点方法换了两条**：行粒度改以「整个界面」为单位；完成判据改为**覆盖证明**（见文末「覆盖证明」节）。
>
> **二、A–G 七块共 189 行是迁移前证据，未逐行复核。** 这 189 行写于 2026-10-29，本轮只做了两件事：把已完成的关系型存储迁移带来的字段口径变化核过一遍（本表不涉及 `chapters` / `bookmarks` / `book_marks` 三张表，无失效引用），并把 `readConfig` 类的上游接触面补齐（原表只覆盖 6 个上游文件）。行内容本身未逐条重跑验收。
>
> **三、新增「覆盖证明」节**：`readConfig` 类的上游接触面由旧的错误关键词 `backupIgnoreReadConfig`（只命中 2 个文件，等于自证成功）改为 `ReadBookConfig|ReadSettings`（命中 **76** 个文件），逐个分配。（r294 再补键名字面量 `"readConfig"`，复算 **78** 个，见 [KEYWORDS.md](KEYWORDS.md) 的「存储层维度」一节。）
>
> **四、本表的口径基数未变**：上游配置来源两个文件 `help/config/ReadBookConfig.kt`（1054 行）与 `domain/model/settings/ReadSettings.kt`（122 行），合计声明 **267** 个名字。这 267 个是**字段级**基数；本表的 189 行是**界面级**基数。两者不可相加也不可相减，1.3 的 112 项差集属字段口径。

- 盘点日期：2026-10-29（r286 结构性重盘：2026-10-30）
- 上游基线：`legado-with-MD3`（Android，Compose）
- 本地实现：`entry/src/main/ets`（HarmonyOS，ArkTS）
- 对应 ZIP 类别：`readConfig` 180 行、`themeConfig` 7 行、`—` 2 行。**本表不逐行加「ZIP 类别」列**，理由见下节。

## ZIP 类别归属（整表口径）

本表 189 行按「这一行要改代码时会动到哪个 ZIP 类别的键或文件」逐块归属，结果只有三档：

| 块 | 条数 | ZIP 类别 | 依据 |
| --- | --- | --- | --- |
| A 阅读界面基础 | 37 | `readConfig` | `hideStatusBar`/`hideNavigationBar` 等 `ReadBookConfig` 字段 → `BackupConfig.kt:197-262 readPrefKeys` |
| B 页眉页脚 | 24 | `readConfig` | `tipHeaderLeft` 等属 `ReadBookConfig`，键在 `readPrefKeys` |
| C 正文排版 | 49 | `readConfig` | `textColor`/`textSize` 等属 `ReadBookConfig.kt`，键在 `readPrefKeys` |
| D 翻页与手势交互 | 20 | `readConfig` | 9 个 `clickAction*` 键全在 `readPrefKeys` |
| E 菜单与主题外观 | 42 | `readConfig` | 34 个 `readMenu*` 键在 `readPrefKeys`（**注意不是 `themeConfig`**——菜单配色是阅读界面的一部分，不是主题配色） |
| F 护眼与书签角标 | 9 | **混合** | 护眼 6 键（`eyeProtectionEnabled`/`colorTemperature`/`eyeProtectionAutoNight`/`eyeProtectionSchedule`/`eyeProtectionStartTime`/`eyeProtectionEndTime`，`BackupConfig.kt:311-316`）+ 跨零点判定共 7 行 → `themeConfig`；**书签角标 2 行**（`bookmarkBadgeImage`/`bookmarkBadgeSize`，`PreferKey.kt:205-206`）→ `—` |
| G 页边距 | 8 | `readConfig` | `paddingTop/Bottom/Left/Right` 在 `readPrefKeys` |

合计 **`readConfig` 180 + `themeConfig` 7 + `—` 2 = 189**。

`—` 的语义是「**参与备份，但不受任何忽略开关控制**」：书签角标两键照样写进 `config.xml`，只是不在五个类别数组里（上游 `help/storage/BackupConfig.kt:413 fun keyIsNotIgnore` 的 `else -> true` 分支）。F 块这两行若按类别派活，落到哪一类都会漏掉。

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
| B 页眉页脚 | 24 | 24 | 0 | 0 |
| C 正文排版 | 49 | 23 | 26 | 0 |
| D 翻页与手势交互 | 20 | 10 | 10 | 0 |
| E 菜单与主题外观 | 42 | 2 | 40 | 0 |
| F 护眼与书签角标 | 9 | 9 | 0 | 0 |
| G 页边距 | 8 | 8 | 0 | 0 |
| 合计 | 189 | 90 | 97 | 2 |

> 早前口头估计「菜单外观 30-40 项全占位」方向对、原因错：不是没有控件，是有控件无持久化无渲染（见口径第 2 条）。逐项核完 E 块共 42 条：40 条未接，2 条已接（底栏按钮配置、标题栏操作按钮）。
>
> 2026-10-31 复核：B 块唯一一行（页眉/页脚独立字体）改判 `已接`——排版设置面板的字体目标四按钮可选「页眉」「页脚」，经 `openFontSelection()` → `setFontPathForCurrentTarget()` 分别落 `headerFont`/`footerFont`，`ReaderPage.ets:711-715 readerInfoFontFamily()` 按其取字体族。原先判 `未接` 是因为只看了页眉页脚 tab 里那条 `showNotMigrated` 占位入口，未查到另一条可达路径。现 97 行未接**逐行**在 [KNOWN-ISSUES](../KNOWN-ISSUES.md#阅读配置行登记reader-configmd-的未接行) 登记了「为什么不修」与补法，本表备注列的 `KI-xx` 即其锚点，无裸「未接」。

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
| 正文行高适配 | `ReadSettings.kt` | `ReaderSettingsPage.ets:838` | 未接 | 走 `showNotMigrated('正文行高适配')`，无对应仓储字段 | 开关后特殊排版的书行距被修正 | 上游 `readBodyToLh`（`ReadBookConfig.kt:67`）；见 [KNOWN-ISSUES](../KNOWN-ISSUES.md#阅读配置行登记reader-configmd-的未接行) KI-A1 |
| 中文排版 | `ReadBookConfig.kt:76` | `ReaderSettingsPage.ets:839` | 未接 | 走 `showNotMigrated('中文排版')`，`useZhLayout` 无对应字段 | 开关后中文标点挤压生效 | 见 [KNOWN-ISSUES](../KNOWN-ISSUES.md#阅读配置行登记reader-configmd-的未接行) KI-A1 |
| 适配刘海屏 | `ReadSettings.kt` | `ReaderSettingsPage.ets:837` | 未接 | 开关恒为 `checked: true` 且点击即占位提示 | 开关后正文避让显示缺口 | 见 [KNOWN-ISSUES](../KNOWN-ISSUES.md#阅读配置行登记reader-configmd-的未接行) KI-A1 |
| 适配特殊样式 | `ReadSettings.kt` | `ReaderSettingsPage.ets:840` | 未接 | 走 `showNotMigrated('适配特殊样式')` | 开关后书籍自带样式被保留 | 见 [KNOWN-ISSUES](../KNOWN-ISSUES.md#阅读配置行登记reader-configmd-的未接行) KI-A1 |
| 显示菜单图标 | `ReadBookConfig.kt:78` | `ReaderSettingsPage.ets:883` | 未接 | 走 `showNotMigrated('显示菜单图标')` | 总开关关闭后阅读页菜单图标消失 | 见 [KNOWN-ISSUES](../KNOWN-ISSUES.md#阅读配置行登记reader-configmd-的未接行) KI-A2 |
| 禁用返回键 | `ReadSettings.kt` | `ReaderSettingsPage.ets:864` | 未接 | 走 `showNotMigrated('禁用返回键')` | 开关后返回键在阅读页无响应 | 见 [KNOWN-ISSUES](../KNOWN-ISSUES.md#阅读配置行登记reader-configmd-的未接行) KI-A3 |
| 优化正文渲染 | `ReadSettings.kt` | `ReaderSettingsPage.ets:863` | 未接 | 走 `showNotMigrated('优化正文渲染')` | 开关后长章节渲染耗时变化 | 见 [KNOWN-ISSUES](../KNOWN-ISSUES.md#阅读配置行登记reader-configmd-的未接行) KI-A4 |
| 阅读标题补充信息 | `ReadSettings.kt` | `ReaderSettingsPage.ets:886` | 未接 | 走 `showNotMigrated('阅读标题补充信息')`，`checked` 恒 `false` | 开关后阅读页标题出现补充行 | 见 [KNOWN-ISSUES](../KNOWN-ISSUES.md#阅读配置行登记reader-configmd-的未接行) KI-A2 |
| 朗读悬浮窗分离提醒 | `ReadBookConfig.kt:80` | `ReaderSettingsPage.ets:887` | 未接 | 走 `showNotMigrated('朗读悬浮窗分离提醒')` | — | 朗读整体在[范围之外](../PROJECT.md)，判 `未接` 而非 `不适用`，因开关已上屏；见 [KNOWN-ISSUES](../KNOWN-ISSUES.md#阅读配置行登记reader-configmd-的未接行) KI-A5 |
| 自动切换书源 | `ReadSettings.kt` | `ReaderSettingsPage.ets:868` | 未接 | 走 `showNotMigrated('自动切换书源')` | — | 在线书源在[范围之外](../PROJECT.md)，开关已上屏故判 `未接`；见 [KNOWN-ISSUES](../KNOWN-ISSUES.md#阅读配置行登记reader-configmd-的未接行) KI-A5 |
| 换源结果应用于全部书籍 | `ReadSettings.kt` | `ReaderSettingsPage.ets:869` | 未接 | 走 `showNotMigrated('换源结果应用于全部书籍')` | — | 同上；见 [KNOWN-ISSUES](../KNOWN-ISSUES.md#阅读配置行登记reader-configmd-的未接行) KI-A5 |
| 自动切换日夜模式提醒 | `ReadSettings.kt` | `ReaderSettingsPage.ets:870` | 未接 | 走 `showNotMigrated('自动切换日夜模式提醒')` | 到点后弹出切换背景提示 | 见 [KNOWN-ISSUES](../KNOWN-ISSUES.md#阅读配置行登记reader-configmd-的未接行) KI-A6 |
| 阅读进度条触感反馈 | `ReadSettings.kt` | `ReaderSettingsPage.ets:867` | 未接 | 走 `showNotMigrated('进度条触感反馈')` | 拖动进度条有振动 | 见 [KNOWN-ISSUES](../KNOWN-ISSUES.md#阅读配置行登记reader-configmd-的未接行) KI-A7 |
| 使用新版目录 | `ReadSettings.kt` | `ReaderSettingsPage.ets:873` | 未接 | 走 `showNotMigrated('使用新版目录')` | 开关后目录面板形态变化 | 见 [KNOWN-ISSUES](../KNOWN-ISSUES.md#阅读配置行登记reader-configmd-的未接行) KI-A8 |
| 文字选择触感反馈 | `ReadSettings.kt` | `ReaderSettingsPage.ets:879` | 未接 | 走 `showNotMigrated('文字选择触感反馈')` | 选中正文有振动 | 见 [KNOWN-ISSUES](../KNOWN-ISSUES.md#阅读配置行登记reader-configmd-的未接行) KI-A7 |
| 漫画阅读样式 | `ReadBookConfig.kt:70` | — | 不适用 | 上游 `comicStyleSelect` 为漫画阅读专用 | — | 漫画/图片书不在[项目队列](../PROJECT.md)范围，本地无图片书类型 |
| 阅读样式选择（漫画分支） | `ReadBookConfig.kt:69` | — | 不适用 | 上游 `readStyleSelect` 在漫画会话下生效 | — | 同上，`styleSelect`（`:98`）取漫画分支时无意义 |
| 阅读亮度 | `ReadSettings.kt:22` | — | 未接 | 上游 `readBrightness` 随书保存亮度，本地无字段，亮度不随书记忆 | 调暗后退出重进亮度保持 | 见 [KNOWN-ISSUES](../KNOWN-ISSUES.md#阅读配置行登记reader-configmd-的未接行) KI-A9 |
| 阅读菜单不透明度 | `ReadSettings.kt:13` | — | 未接 | 上游 `menuAlpha` 默认 100，是整层不透明度；E 块的「菜单模糊透明度」对应 `readMenuBlurAlpha`，不是此项 | 调后菜单整体通透度变化 | 与 E 块 `readMenuBlurAlpha` 不同字段；见 [KNOWN-ISSUES](../KNOWN-ISSUES.md#阅读配置行登记reader-configmd-的未接行) KI-A2 |
| 主题网格列数 | `ReadSettings.kt:40` | — | 未接 | 上游 `themeGridColumns` 默认 4，本地无字段 | 主题面板每行列数变化 | 见 [KNOWN-ISSUES](../KNOWN-ISSUES.md#阅读配置行登记reader-configmd-的未接行) KI-A10 |
| 向后预下载章节数 | `ReadSettings.kt:58` | — | 未接 | 上游 `preDownloadNum` 默认 10；`AppDownloadCacheSettingsPage.ets:31` 是预览页，滑块无持久化 | 调大后缓存章节数变化 | 下载缓存模块整体未接；见 [KNOWN-ISSUES](../KNOWN-ISSUES.md#阅读配置行登记reader-configmd-的未接行) KI-A11 |
| 向前预下载章节数 | `ReadSettings.kt:59` | — | 未接 | 上游 `preDownloadNumPrev` 默认 0，同上 | 同上 | 同上；见 [KNOWN-ISSUES](../KNOWN-ISSUES.md#阅读配置行登记reader-configmd-的未接行) KI-A11 |
| 在浏览器打开 | `ReadSettings.kt:64` | — | 未接 | 上游 `readUrlInBrowser`，本地无字段 | 开启后链接在系统浏览器打开 | 见 [KNOWN-ISSUES](../KNOWN-ISSUES.md#阅读配置行登记reader-configmd-的未接行) KI-A12 |
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
| 页眉/页脚独立字体 | `ReadBookConfig.kt:210`、`:213` | `ReaderSettingsRepository.ets:20-21` | 已接 | 字段已建模且可达：排版设置面板的字体目标四按钮（`ReaderSettingsPage.ets:1339`）选中「页眉」/「页脚」后，`:1344` 的「字体」条目（`migrated: true`）→ `openFontSelection()`（`:975-983`）设 `fontTarget` → `setFontPathForCurrentTarget()`（`:1008-1018`）分别落 `headerFont`/`footerFont`；仓储 `:82-83` 合并、`:224-225` 默认空串；渲染侧 `ReaderPage.ets:711-715 readerInfoFontFamily()` 按 `infoSettings.headerFont/footerFont` 取字体族，`:1566-1567` 参与分页 key | 选中「页眉」→ 换一个导入字体 → 页眉字形变化且退出重进保持；再切「页脚」同样变化 | 页眉页脚 tab 里的 `ReaderInfoOptionRow`「选择字体」（`ReaderSettingsPage.ets:799-801`）仍走 `showNotMigrated('页眉/页脚字体选择')`，是**残留占位入口**，功能已由排版设置面板提供；本轮不改 .ets，登记在 [KNOWN-ISSUES](../KNOWN-ISSUES.md) KI-B-01 |

## C 正文排版

本地主体：`ReaderSettingsRepository.ets:138-161`、渲染侧 `entry/src/main/ets/pages/ReaderPage.ets`（3562 行）。

| 上游能力 | 上游位置 | 本地位置 | 状态 | 差异说明 | 验收方式 | 备注 |
| --- | --- | --- | --- | --- | --- | --- |
| 正文日间颜色 | `ReadBookConfig.kt:55` | `ReaderPage.ets:2710-2713` | 未接 | 上游 `textColor` 可配（默认 `#3E3D3B`）；本地 `getReadingTextColor()` 硬编码，按 `paperColor` 三值判断日/夜后返回固定色 | 改正文颜色后正文字变色 | 属于「有默认值但不可配」；见 [KNOWN-ISSUES](../KNOWN-ISSUES.md#阅读配置行登记reader-configmd-的未接行) KI-C1 |
| 正文夜间颜色 | `ReadBookConfig.kt:56` | `ReaderPage.ets:2710-2713` | 未接 | 上游 `textColorNight`（默认 `#ADADAD`）；本地同上硬编码为 `#D8D8DC` | 切夜间后正文字取该值 | 同上；见 [KNOWN-ISSUES](../KNOWN-ISSUES.md#阅读配置行登记reader-configmd-的未接行) KI-C1 |
| 正文强调色 | `ReadBookConfig.kt:62` | — | 未接 | 上游 `textAccentColor`/`Night` 三套，本地无字段 | 改强调色后划线高亮色变化 | 与 E 块「种子色」同源；见 [KNOWN-ISSUES](../KNOWN-ISSUES.md#阅读配置行登记reader-configmd-的未接行) KI-C1 |
| 背景透明度 | `ReadBookConfig.kt:198` | — | 未接 | 上游 `bgAlpha` 默认 100，本地无字段 | 调透明度后背景图透出 | 见 [KNOWN-ISSUES](../KNOWN-ISSUES.md#阅读配置行登记reader-configmd-的未接行) KI-C2 |
| 背景颜色/图片 | `ReadBookConfig.kt:537-551` | `ReaderSettingsRepository.ets:162-164` | 未接 | 本地 `paperIndex`/`dayPaperIndex`/`nightPaperIndex` 存索引，指向 `READER_BACKGROUND_STYLES`（`:339-346`）六个内置方案，用户只能在这六个里选；上游 `bgStr` 存任意颜色串、`bgType` 支持 assets 与自选图片，自定义能力本地为零。行内「背景图片」条目（`ReaderSettingsPage.ets:1281`）也只弹提示 | 六方案可切换；自选颜色或图片不可用 | 六个预设可用属既有能力，不改变本行「自定义背景」未接；见 [KNOWN-ISSUES](../KNOWN-ISSUES.md#阅读配置行登记reader-configmd-的未接行) KI-C2 |
| 白天是否暗色状态栏 | `ReadBookConfig.kt:552` | — | 未接 | 上游 `darkStatusIcon`/`Night`，本地无字段 | 浅色背景下状态栏图标变暗 | 见 [KNOWN-ISSUES](../KNOWN-ISSUES.md#阅读配置行登记reader-configmd-的未接行) KI-C2 |
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
| 下划线偏移量 | `ReadBookConfig.kt:322` | — | 未接 | 上游 `underlinePadding` 默认 10，仓储无字段 | 调偏移后下划线与文字距离变化 | 见 [KNOWN-ISSUES](../KNOWN-ISSUES.md#阅读配置行登记reader-configmd-的未接行) KI-C3 |
| 下划线延伸 | `ReadBookConfig.kt:325` | — | 未接 | 上游 `underlineExtend`，仓储无字段 | 开关后下划线延伸到页边 | 见 [KNOWN-ISSUES](../KNOWN-ISSUES.md#阅读配置行登记reader-configmd-的未接行) KI-C3 |
| 自定义虚线长度基准 | `ReadBookConfig.kt:331` | — | 未接 | 上游 `dottedBase` 默认 6f，仓储无字段 | 调基准后虚线每段变长 | 见 [KNOWN-ISSUES](../KNOWN-ISSUES.md#阅读配置行登记reader-configmd-的未接行) KI-C3 |
| 自定义虚线间隔比例 | `ReadBookConfig.kt:334` | — | 未接 | 上游 `dottedRatio` 默认 6f，仓储无字段 | 调比例后虚线间隔变化 | 见 [KNOWN-ISSUES](../KNOWN-ISSUES.md#阅读配置行登记reader-configmd-的未接行) KI-C3 |
| 标题位置模式 | `ReadBookConfig.kt:267` | — | 未接 | 上游三值：居左/居中/隐藏；本地 `ReaderPage.ets:824` 固定按左对齐绘制 | 切「居中」后标题居中 | 见 [KNOWN-ISSUES](../KNOWN-ISSUES.md#阅读配置行登记reader-configmd-的未接行) KI-C4 |
| 标题字号 | `ReadBookConfig.kt:269` | — | 未接 | 上游 `titleSize` 有绝对值/相对正文两模式（`isTitleSizeRelative()`，`:660-668`）；本地无字段，改为 9 处硬编码 `this.fontSize + 4`：`ReaderPage.ets:824`、`:1651`、`:1656`、`:2857`、`:2859`、`:2867`、`:2869`、`:2941`、`:2943` | 改标题字号后标题字变大 | 相对偏移量固定为 4，不可配置；见 [KNOWN-ISSUES](../KNOWN-ISSUES.md#阅读配置行登记reader-configmd-的未接行) KI-C4 |
| 标题字号是否相对正文 | `ReadBookConfig.kt:270` | — | 未接 | 上游 `titleSizeRelative` 为三态（null/true/false），本地无字段亦无 UI | 切绝对模式后标题不随正文字号变 | 见 [KNOWN-ISSUES](../KNOWN-ISSUES.md#阅读配置行登记reader-configmd-的未接行) KI-C4 |
| 标题上间距 | `ReadBookConfig.kt:298` | — | 未接 | 上游 `titleTopSpacing` 默认 0 | 调上间距后标题上方空白变化 | 见 [KNOWN-ISSUES](../KNOWN-ISSUES.md#阅读配置行登记reader-configmd-的未接行) KI-C4 |
| 标题下间距 | `ReadBookConfig.kt:301` | — | 未接 | 上游 `titleBottomSpacing` 默认 0 | 调下间距后标题下方空白变化 | 见 [KNOWN-ISSUES](../KNOWN-ISSUES.md#阅读配置行登记reader-configmd-的未接行) KI-C4 |
| 标题日间颜色 | `ReadBookConfig.kt:304` | — | 未接 | 上游 `titleColor` 默认 0（跟随正文） | 改色后标题变色 | 见 [KNOWN-ISSUES](../KNOWN-ISSUES.md#阅读配置行登记reader-configmd-的未接行) KI-C4 |
| 标题夜间颜色 | `ReadBookConfig.kt:307` | — | 未接 | 上游 `titleColorNight` 默认 0 | 切夜间后标题取该值 | 见 [KNOWN-ISSUES](../KNOWN-ISSUES.md#阅读配置行登记reader-configmd-的未接行) KI-C4 |
| 标题字重 | `ReadBookConfig.kt:228` | — | 未接 | 上游 `titleBold` 独立于正文 `textBold` | 切标题粗体后标题加粗 | 见 [KNOWN-ISSUES](../KNOWN-ISSUES.md#阅读配置行登记reader-configmd-的未接行) KI-C4 |
| 标题行距 | `ReadBookConfig.kt:255` | — | 未接 | 上游 `titleLineSpacingExtra` 默认 12 | 调后标题多行时行间变化 | 见 [KNOWN-ISSUES](../KNOWN-ISSUES.md#阅读配置行登记reader-configmd-的未接行) KI-C4 |
| 标题行距子项 | `ReadBookConfig.kt:258` | — | 未接 | 上游 `titleLineSpacingSub` 默认 12 | 分段标题的第二段行距变化 | 见 [KNOWN-ISSUES](../KNOWN-ISSUES.md#阅读配置行登记reader-configmd-的未接行) KI-C4 |
| 标题分段模式 | `ReadBookConfig.kt:280` | — | 未接 | 上游 `titleSegType` 默认 0 | 开关后长标题按规则拆两段 | 见 [KNOWN-ISSUES](../KNOWN-ISSUES.md#阅读配置行登记reader-configmd-的未接行) KI-C4 |
| 标题分段缩放 | `ReadBookConfig.kt:283` | — | 未接 | 上游夹取 0–2，负值回落 1 | 调比例后第二段字号变化 | 见 [KNOWN-ISSUES](../KNOWN-ISSUES.md#阅读配置行登记reader-configmd-的未接行) KI-C4 |
| 标题分段起始位置 | `ReadBookConfig.kt:287` | — | 未接 | 上游 `titleSegDistance` 默认 4 | 调值后分段切点前移/后移 | 见 [KNOWN-ISSUES](../KNOWN-ISSUES.md#阅读配置行登记reader-configmd-的未接行) KI-C4 |
| 标题分段识别字符 | `ReadBookConfig.kt:290` | — | 未接 | 上游 `titleSegFlag` 默认空串 | 填入字符后在该处拆段 | 见 [KNOWN-ISSUES](../KNOWN-ISSUES.md#阅读配置行登记reader-configmd-的未接行) KI-C4 |
| 繁简转换 | `ReadSettings.kt:118` | — | 未接 | 上游 `chineseConverterType` 三档（不转换/繁体/简体），本地无字段 | 选繁体后正文以繁体显示 | 见 [KNOWN-ISSUES](../KNOWN-ISSUES.md#阅读配置行登记reader-configmd-的未接行) KI-C5 |
| 字体文件夹 | `ReadSettings.kt:79` | — | 未接 | 上游 `fontFolder` 指定扫描目录，本地只支持系统字体与内置字体 | 指定文件夹后出现自定义字体 | 本地 `systemTypefaces` 只覆盖系统字体枚举；见 [KNOWN-ISSUES](../KNOWN-ISSUES.md#阅读配置行登记reader-configmd-的未接行) KI-C6 |

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
| 自定义翻页按键 | `ReadSettings.kt` | `ReaderSettingsPage.ets:884` | 未接 | 点开 `showNotMigrated` 语义提示「按键映射面板尚未迁移」，无按键映射数据结构 | 绑键后按键触发对应动作 | 见 [KNOWN-ISSUES](../KNOWN-ISSUES.md#阅读配置行登记reader-configmd-的未接行) KI-D1 |
| 选中文字菜单 | `ReadSettings.kt` | `ReaderSettingsPage.ets:885` | 未接 | 点开提示「文本操作菜单配置尚未迁移」 | 选中文字后菜单项可按配置增减 | 见 [KNOWN-ISSUES](../KNOWN-ISSUES.md#阅读配置行登记reader-configmd-的未接行) KI-D2 |
| 鼠标滚轮翻页 | `ReadSettings.kt` | `ReaderSettingsPage.ets:848` | 未接 | 开关 `checked` 恒 `false` 且绑定 `showNotMigrated` | 接鼠标滚轮可翻页 | 见 [KNOWN-ISSUES](../KNOWN-ISSUES.md#阅读配置行登记reader-configmd-的未接行) KI-D1 |
| 朗读时允许音量键翻页 | `ReadSettings.kt:30` | `ReaderSettingsPage.ets:851` | 未接 | 走 `showNotMigrated('朗读时音量键翻页')` | — | 朗读在[范围之外](../PROJECT.md)，开关已上屏故判 `未接`；见 [KNOWN-ISSUES](../KNOWN-ISSUES.md#阅读配置行登记reader-configmd-的未接行) KI-D3 |
| 横屏双页 | `ReadSettings.kt:26` | `ReaderSettingsPage.ets:844` | 未接 | 上游 `doubleHorizontalPage` 三值，本地打开详情面板但面板内无落盘 | 横屏时左右双页显示 | 见 [KNOWN-ISSUES](../KNOWN-ISSUES.md#阅读配置行登记reader-configmd-的未接行) KI-D4 |
| 进度条行为 | `ReadSettings.kt:27` | `ReaderSettingsRepository.ets:173` | 已接 | 上游 `progressBarBehavior` → 本地 `progressBehavior`，取值 `page`/`chapter`，面板 `ReaderSettingsPage.ets:847` | 拖动进度条按章节或页码定位 | — |
| 翻页触摸灵敏度 | `ReadSettings.kt:35` | — | 未接 | 上游 `pageTouchSlop` 默认 0，本地无字段 | 调节后误触减少 | 见 [KNOWN-ISSUES](../KNOWN-ISSUES.md#阅读配置行登记reader-configmd-的未接行) KI-D5 |
| 进度条模式 | `ReadSettings.kt:25` | — | 未接 | 上游 `readSliderMode` 默认 `"0"`，本地无字段 | 进度条显示形态变化 | 见 [KNOWN-ISSUES](../KNOWN-ISSUES.md#阅读配置行登记reader-configmd-的未接行) KI-D5 |
| 允许选择正文 | `ReadSettings.kt:46` | `ReaderSettingsRepository.ets:195` | 已接 | 开关在 `ReaderSettingsPage.ets:874`，阅读页 `ReaderPage.ets:169` 消费 | 长按正文出现选择菜单 | — |
| 展开文字菜单 | `ReadSettings.kt:51` | `ReaderSettingsPage.ets:1437` | 未接 | 仅 `expandTextMenuPreview` 页面 `@State`，无持久化 | 折叠菜单项多行展开 | 见 [KNOWN-ISSUES](../KNOWN-ISSUES.md#阅读配置行登记reader-configmd-的未接行) KI-D2 |
| 显示选择菜单图标 | `ReadSettings.kt:52` | — | 未接 | 上游 `showSelectMenuIcon` 默认 true，本地无字段 | 选择菜单显示图标 | 见 [KNOWN-ISSUES](../KNOWN-ISSUES.md#阅读配置行登记reader-configmd-的未接行) KI-D2 |
| 上次标记样式 | `ReadSettings.kt:54` | — | 未接 | 上游 `lastMarkingStyle` 记录上次标注样式，本地无字段 | 连续标注沿用上次样式 | 见 [KNOWN-ISSUES](../KNOWN-ISSUES.md#阅读配置行登记reader-configmd-的未接行) KI-D6 |

## E 菜单与主题外观

上游主体：`ReadBookConfig.kt:77-131`（`readMenu*` 系列 getter）、`Config` 内的 `@Transient menu*` 字段（`:643-658`）。
本地主体：`ReaderSettingsPage.ets:399-462`（`menuSettingsContent()`）、条目清单 `:1788-1840`。

**本块共同差异**：39 个条目里 37 个有控件、可点击、有 `@State` 承载，但没有一条写入 `ReaderSettingsRepository.ets`，也不驱动 `ReaderPage.ets` 渲染。判 `未接` 的依据是「退出设置页即丢失 + 阅读页外观不变」，不是「没有控件」。剩下 2 条（底栏按钮配置、标题栏操作按钮）是完整持久化链路，判 `已接`。

| 上游能力 | 上游位置 | 本地位置 | 状态 | 差异说明 | 验收方式 | 备注 |
| --- | --- | --- | --- | --- | --- | --- |
| 工具栏样式 | `ReadBookConfig.kt:99` | `ReaderSettingsPage.ets:1791` | 未接 | 三选一存 `@State menuBarStyleMode`（`:165`），仓储无字段 | 切「自定义」后菜单栏换配色 | 见 [KNOWN-ISSUES](../KNOWN-ISSUES.md#阅读配置行登记reader-configmd-的未接行) KI-E1 |
| 调色板风格 | `ReadBookConfig.kt:113` | `ReaderSettingsPage.ets:1792` | 未接 | 上游 `readMenuPaletteStyle`，本地条目存在无状态 | 切换后调色板按钮形态变化 | 见 [KNOWN-ISSUES](../KNOWN-ISSUES.md#阅读配置行登记reader-configmd-的未接行) KI-E1 |
| 菜单颜色来源 | `ReadBookConfig.kt:99` | `ReaderSettingsPage.ets:1793` | 未接 | 存 `@State menuColorMode`（`:166`），无持久化 | 切「自定义主题色」后配色来源变化 | 见 [KNOWN-ISSUES](../KNOWN-ISSUES.md#阅读配置行登记reader-configmd-的未接行) KI-E1 |
| 种子色 | `ReadBookConfig.kt:62` | `ReaderSettingsPage.ets:1794` | 未接 | 上游 `textAccentColor`/`Night`/`EInk` 三套，本地无字段 | 改种子色后强调色变化 | 见 [KNOWN-ISSUES](../KNOWN-ISSUES.md#阅读配置行登记reader-configmd-的未接行) KI-E1 |
| 菜单背景颜色 | `ReadBookConfig.kt:117` | `ReaderSettingsPage.ets:1795` | 未接 | 上游 `readMenuBgColor`/`Night` | 改色后菜单底变色 | 见 [KNOWN-ISSUES](../KNOWN-ISSUES.md#阅读配置行登记reader-configmd-的未接行) KI-E1 |
| 菜单容器颜色 | `ReadBookConfig.kt:123` | `ReaderSettingsPage.ets:1796` | 未接 | 上游 `readMenuContainerColor`/`Night` | 改色后菜单卡片变色 | 见 [KNOWN-ISSUES](../KNOWN-ISSUES.md#阅读配置行登记reader-configmd-的未接行) KI-E1 |
| 菜单强调颜色 | `ReadBookConfig.kt:120` | `ReaderSettingsPage.ets:1797` | 未接 | 上游 `readMenuAccentColor`/`Night` | 改色后选中态变色 | 见 [KNOWN-ISSUES](../KNOWN-ISSUES.md#阅读配置行登记reader-configmd-的未接行) KI-E1 |
| 显示亮度视图 | `ReadBookConfig.kt:94` | `ReaderSettingsPage.ets:1799` | 未接 | 上游 `showBrightnessView` 三值，本地无字段 | 切「竖向」后亮度条竖排 | 见 [KNOWN-ISSUES](../KNOWN-ISSUES.md#阅读配置行登记reader-configmd-的未接行) KI-E1 |
| 亮度条位置 | `ReadBookConfig.kt:95` | `ReaderSettingsPage.ets:1800` | 未接 | 上游 `brightnessVwPos` | 切位置后亮度条换到另一端 | 见 [KNOWN-ISSUES](../KNOWN-ISSUES.md#阅读配置行登记reader-configmd-的未接行) KI-E1 |
| 菜单栏边框 | `ReadBookConfig.kt:88` | `ReaderSettingsPage.ets:1802` | 未接 | 存 `@State menuBorderEnabled`（`:168`），无持久化 | 开关后菜单出现描边 | 见 [KNOWN-ISSUES](../KNOWN-ISSUES.md#阅读配置行登记reader-configmd-的未接行) KI-E2 |
| 菜单栏边框宽度 | `ReadBookConfig.kt:115` | `ReaderSettingsPage.ets:1803` | 未接 | 上游 `readMenuBorderWidth` 夹取 0–4 | 调宽后描边变粗 | 见 [KNOWN-ISSUES](../KNOWN-ISSUES.md#阅读配置行登记reader-configmd-的未接行) KI-E2 |
| 菜单栏边框颜色 | `ReadBookConfig.kt:88-89` | `ReaderSettingsPage.ets:1804` | 未接 | 上游 `readMenuBorderColor`/`Night` | 改色后描边变色 | 见 [KNOWN-ISSUES](../KNOWN-ISSUES.md#阅读配置行登记reader-configmd-的未接行) KI-E2 |
| 菜单模糊半径 | `ReadBookConfig.kt:109` | `ReaderSettingsPage.ets:1806` | 未接 | 上游夹取 0–32 | 调半径后背景模糊程度变化 | 见 [KNOWN-ISSUES](../KNOWN-ISSUES.md#阅读配置行登记reader-configmd-的未接行) KI-E2 |
| 菜单模糊透明度 | `ReadBookConfig.kt:110` | `ReaderSettingsPage.ets:1807` | 未接 | 上游夹取 0–100 | 调透明度后模糊可见度变化 | 见 [KNOWN-ISSUES](../KNOWN-ISSUES.md#阅读配置行登记reader-configmd-的未接行) KI-E2 |
| 菜单文字颜色 | `ReadBookConfig.kt:90-91` | `ReaderSettingsPage.ets:1808` | 未接 | 上游 `readMenuTextColor`/`Night` | 改色后菜单文字变色 | 见 [KNOWN-ISSUES](../KNOWN-ISSUES.md#阅读配置行登记reader-configmd-的未接行) KI-E2 |
| 菜单模糊颜色 | `ReadBookConfig.kt:111-112` | `ReaderSettingsPage.ets:1809` | 未接 | 上游 `readMenuBlurColor`/`Night` | 改色后模糊层色调变化 | 见 [KNOWN-ISSUES](../KNOWN-ISSUES.md#阅读配置行登记reader-configmd-的未接行) KI-E2 |
| 显示标题栏图标 | `ReadBookConfig.kt:92` | `ReaderSettingsPage.ets:1811` | 未接 | 存 `@State menuTitleIconsVisible`（`:484` 赋值），无持久化 | 关闭后标题栏图标消失 | 见 [KNOWN-ISSUES](../KNOWN-ISSUES.md#阅读配置行登记reader-configmd-的未接行) KI-E3 |
| 标题栏悬浮图标配置 | `ReadBookConfig.kt:146`、`:149` | `ReaderSettingsPage.ets:1812` | 未接 | 上游 `readMenuCustomIcons`、`titleBarCustomIcons` 两个 Map，本地无字段 | 换图标后标题栏图标变化 | 见 [KNOWN-ISSUES](../KNOWN-ISSUES.md#阅读配置行登记reader-configmd-的未接行) KI-E3 |
| 标题栏悬浮图标位置 | `ReadBookConfig.kt:116` | `ReaderSettingsPage.ets:1813` | 未接 | 上游 `titleBarIconPosition` 夹取 0–3 | 换位置后图标换到另一侧 | 见 [KNOWN-ISSUES](../KNOWN-ISSUES.md#阅读配置行登记reader-configmd-的未接行) KI-E3 |
| 悬浮图标液态玻璃按钮 | `ReadBookConfig.kt:87` | `ReaderSettingsPage.ets:1814` | 未接 | 上游 `readMenuFloatingIconLiquidGlass` | 开关后图标按钮出现玻璃质感 | 见 [KNOWN-ISSUES](../KNOWN-ISSUES.md#阅读配置行登记reader-configmd-的未接行) KI-E3 |
| 底栏按钮配置 | `ReadSettings.kt` | `ReaderSettingsRepository.ets:171-172` | 已接 | 链路完整：`ReaderSettingsPage.ets:470-472` 分流 → `handleMenuSettingsEntryClick()`（`:517-531`）→ `bottomActionConfigurationSheet()`（`:1897-1956`，显示开关 `:1936`、上下移 `:1938-1944`）→ `onBottomActionsChange` → `Index.ets:2218` → 写 `bottomActions`（`ReaderSettingsRepository.ets:804`） | 改显示与顺序后退出设置页，重进仍生效，阅读页底栏同步变化 | 只做显示/排序，未做长按动作自定义 |
| 底栏圆角 | `ReadBookConfig.kt:104` | `ReaderSettingsPage.ets:1821` | 未接 | 上游 `readMenuBottomCornerRadius` 夹取 0–32 | 调圆角后底栏卡片变圆 | 见 [KNOWN-ISSUES](../KNOWN-ISSUES.md#阅读配置行登记reader-configmd-的未接行) KI-E4 |
| 底栏悬浮 | `ReadBookConfig.kt:82` | `ReaderSettingsPage.ets:1822` | 未接 | 上游 `readMenuFloatingBottomBar` | 开关后底栏脱离屏幕边缘 | 见 [KNOWN-ISSUES](../KNOWN-ISSUES.md#阅读配置行登记reader-configmd-的未接行) KI-E4 |
| 底栏模糊 | `ReadBookConfig.kt:106` | `ReaderSettingsPage.ets:1823` | 未接 | 上游 `readMenuBottomBarBlurMode` 夹取 0–2 | 切三档后底栏背景变化 | 见 [KNOWN-ISSUES](../KNOWN-ISSUES.md#阅读配置行登记reader-configmd-的未接行) KI-E4 |
| 底栏模糊透明度 | `ReadBookConfig.kt:110` | `ReaderSettingsPage.ets:1824` | 未接 | 与「菜单模糊透明度」共用上游字段，本地无字段 | 调后底栏通透度变化 | 见 [KNOWN-ISSUES](../KNOWN-ISSUES.md#阅读配置行登记reader-configmd-的未接行) KI-E4 |
| 底栏模糊样式 | `ReadBookConfig.kt:108` | `ReaderSettingsPage.ets:1823` | 未接 | 上游 `readMenuBottomBarBlurStyle` 夹取 0–1（纯色/渐变） | 切「渐变」后底栏背景为渐变 | 见 [KNOWN-ISSUES](../KNOWN-ISSUES.md#阅读配置行登记reader-configmd-的未接行) KI-E4 |
| 底栏液态玻璃 | `ReadBookConfig.kt:86` | `ReaderSettingsPage.ets:1825` | 未接 | 上游 `readMenuBottomBarLiquidGlassButtons` | 开关后底栏出现玻璃质感 | 见 [KNOWN-ISSUES](../KNOWN-ISSUES.md#阅读配置行登记reader-configmd-的未接行) KI-E4 |
| 底栏按钮液态玻璃 | `ReadBookConfig.kt:86` | `ReaderSettingsPage.ets:1826` | 未接 | 同上字段的按钮级开关 | 开关后单个按钮出现玻璃质感 | 见 [KNOWN-ISSUES](../KNOWN-ISSUES.md#阅读配置行登记reader-configmd-的未接行) KI-E4 |
| 标题栏胶囊 | `ReadBookConfig.kt:85` | `ReaderSettingsPage.ets:1830` | 未接 | 上游 `readMenuTopBarTitleCapsule` | 开关后标题与章节合并成胶囊 | 见 [KNOWN-ISSUES](../KNOWN-ISSUES.md#阅读配置行登记reader-configmd-的未接行) KI-E5 |
| 标题栏模式 | `ReadSettings.kt:12` | `ReaderSettingsPage.ets:1831` | 未接 | 上游 `titleBarMode` 是字符串三态，本地选项为「完整信息/仅标题/标题与章节」（`:570`），仅存页面态 | 切「仅标题」后标题栏变矮 | 见 [KNOWN-ISSUES](../KNOWN-ISSUES.md#阅读配置行登记reader-configmd-的未接行) KI-E5 |
| 标题栏操作按钮 | `ReadSettings.kt` | `ReaderSettingsPage.ets:1832` | 已接 | 链路与底栏同构：`:470-472` → `handleMenuSettingsEntryClick()`（`:517-531`）→ `topActionConfigurationSheet()`（`:2006` 起）→ `onTopActionsChange` → `Index.ets:2227` → 写 `topActions`（`ReaderSettingsRepository.ets:805`） | 改显示与顺序后重进仍生效，阅读页顶栏同步变化 | 与底栏共用 `ReaderBottomActionConfig` |
| 标题栏紧凑 | `ReadBookConfig.kt:81` | `ReaderSettingsPage.ets:1833` | 未接 | 上游 `titleBarCompact`（布尔），与「标题栏模式」是两个独立字段，本地两个条目各自独立上屏、均无持久化 | 开关后标题栏收紧 | 见 [KNOWN-ISSUES](../KNOWN-ISSUES.md#阅读配置行登记reader-configmd-的未接行) KI-E5 |
| 标题栏图标样式 | `ReadBookConfig.kt:101` | `ReaderSettingsPage.ets:1834` | 未接 | 上游 `titleBarIconStyle` 夹取 0–2 | 切「描边」后图标变线框 | 见 [KNOWN-ISSUES](../KNOWN-ISSUES.md#阅读配置行登记reader-configmd-的未接行) KI-E5 |
| 顶栏模糊 | `ReadBookConfig.kt:105` | `ReaderSettingsPage.ets:1835` | 未接 | 上游 `readMenuTopBarBlurMode` 夹取 0–2 | 开关后顶栏背景模糊 | 见 [KNOWN-ISSUES](../KNOWN-ISSUES.md#阅读配置行登记reader-configmd-的未接行) KI-E5 |
| 顶栏模糊样式 | `ReadBookConfig.kt:107` | `ReaderSettingsPage.ets:1836` | 未接 | 上游 `readMenuTopBarBlurStyle` 夹取 0–1 | 切「渐变」后顶栏背景为渐变 | 见 [KNOWN-ISSUES](../KNOWN-ISSUES.md#阅读配置行登记reader-configmd-的未接行) KI-E5 |
| 顶栏液态玻璃按钮 | `ReadBookConfig.kt:83` | `ReaderSettingsPage.ets:1837` | 未接 | 上游 `readMenuTopBarLiquidGlassButtons` | 开关后顶栏按钮出现玻璃质感 | 见 [KNOWN-ISSUES](../KNOWN-ISSUES.md#阅读配置行登记reader-configmd-的未接行) KI-E5 |
| 合并标题栏按钮 | `ReadBookConfig.kt:84` | `ReaderSettingsPage.ets:1838` | 未接 | 上游 `readMenuTopBarMergeButtons` | 开关后相邻按钮合并 | 见 [KNOWN-ISSUES](../KNOWN-ISSUES.md#阅读配置行登记reader-configmd-的未接行) KI-E5 |
| 菜单镜头半径 | `ReadBookConfig.kt:114` | — | 未接 | 上游 `readMenuLensRadius` 夹取 0–48f，本地上屏条目都没有 | 调半径后高光范围变化 | 见 [KNOWN-ISSUES](../KNOWN-ISSUES.md#阅读配置行登记reader-configmd-的未接行) KI-E6 |
| 自动亮度 | `ReadBookConfig.kt:97` | — | 未接 | 上游 `brightnessAuto`，本地无字段无条目 | 开关后亮度跟随环境光 | 见 [KNOWN-ISSUES](../KNOWN-ISSUES.md#阅读配置行登记reader-configmd-的未接行) KI-E6 |
| 阅读栏样式 | `ReadSettings.kt:69` | — | 未接 | 上游 `readBarStyle` 默认 1；`BackupRepository.ets:244` 仅在导入时读取该键名，无渲染 | 切换后底栏形态变化 | 见 [KNOWN-ISSUES](../KNOWN-ISSUES.md#阅读配置行登记reader-configmd-的未接行) KI-E6 |
| 阅读栏样式跟随页面 | `ReadSettings.kt:68` | — | 未接 | 上游 `readBarStyleFollowPage`，本地无字段 | 底栏样式随背景变化 | 见 [KNOWN-ISSUES](../KNOWN-ISSUES.md#阅读配置行登记reader-configmd-的未接行) KI-E6 |
| 更多操作配置 | `ReadSettings.kt:121` | — | 未接 | 上游 `moreActionsConfig` 存「更多」面板的条目配置，本地无字段 | 增删「更多」面板项后生效 | 相关入口提示「更多操作配置保存失败」；见 [KNOWN-ISSUES](../KNOWN-ISSUES.md#阅读配置行登记reader-configmd-的未接行) KI-E6 |

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

**本节与 A–G 明细表是两个不同的计数口径，不可相加。** A–G 按「一次用户可感知的操作」计 189 行（97 行未接，逐行在 [KNOWN-ISSUES](../KNOWN-ISSUES.md#阅读配置行登记reader-configmd-的未接行) 登记）；本节按「上游声明名」计字段差集 112 项，逐项判定见 1.5。一个操作可能对应多个字段（「菜单背景颜色」对应 `readMenuBgColor` + `readMenuBgColorNight`），也有上游字段在本地连条目都没有（`readMenuLensRadius`、`brightnessAuto`）。硬凑成一个数字会反复返工，因此两处各记各的。

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

### 1.5 逐项判定（112 项，逐条给结论）

判定口径：**要接** = 上游有该行为、本地范围内应当补；**不接** = 上游虽有但本地不补，理由必须写明（上游没有的行为一律不补）；**已接** = 已有等价实现，无需动作。「要接」项的去处指向 1.3 与 [KNOWN-ISSUES](../KNOWN-ISSUES.md#阅读配置行登记reader-configmd-的未接行) 的 KI 登记组，两组编号同源。

| 判定 | 项数 |
| --- | --- |
| 要接 | 91 |
| 不接 | 20 |
| 已接 | 1 |
| 合计 | 112 |

**本表 112 行与 1.3 的 14 个字段组逐组对齐，无未判项。** 判定只做「接不接」，本轮不实现（按目标约束，1.3 的代码实现不在本轮范围）。

#### 1.5.1 背景与颜色（9 项）：要接 9

| 字段 | 判定 | 理由与去处 |
| --- | --- | --- |
| `bgAlpha` | 要接 | 上游背景透明度，本地无字段（KI-C2） |
| `bgStr` | 要接 | 上游任意颜色串，本地只有六方案索引（KI-C2） |
| `bgStrNight` | 要接 | 同上，夜间侧（KI-C2） |
| `bgType` | 要接 | 上游 0=颜色/1=assets 图/2=自选图，本地无（KI-C2） |
| `bgTypeNight` | 要接 | 同上，夜间侧（KI-C2） |
| `textColor` | 要接 | 正文字色被 `ReaderPage.ets:2710-2713` 硬编码（KI-C1） |
| `textColorNight` | 要接 | 同上，夜间侧（KI-C1） |
| `textAccentColor` | 要接 | 强调色无字段，被划线高亮与菜单种子色引用（KI-C1） |
| `textAccentColorNight` | 要接 | 同上，夜间侧（KI-C1） |

#### 1.5.2 状态栏（2 项）：要接 2

| 字段 | 判定 | 理由与去处 |
| --- | --- | --- |
| `darkStatusIcon` | 要接 | 上游按背景亮度决定状态栏图标色，本地无字段（KI-C2） |
| `darkStatusIconNight` | 要接 | 同上，夜间侧（KI-C2） |

#### 1.5.3 下划线与虚线（4 项）：要接 4

| 字段 | 判定 | 理由与去处 |
| --- | --- | --- |
| `underlinePadding` | 要接 | 上游下划线偏移量默认 10，本地绘制参数写死（KI-C3） |
| `underlineExtend` | 要接 | 上游下划线延伸开关，本地无（KI-C3） |
| `dottedBase` | 要接 | 上游虚线长度基准默认 6f，本地无（KI-C3） |
| `dottedRatio` | 要接 | 上游虚线间隔比例默认 6f，本地无（KI-C3） |

#### 1.5.4 标题排版（14 项）：要接 14

| 字段 | 判定 | 理由与去处 |
| --- | --- | --- |
| `titleMode` | 要接 | 居左/居中/隐藏三态，本地恒左对齐（KI-C4） |
| `titleSize` | 要接 | 标题字号被 9 处 `fontSize + 4` 写死（KI-C4） |
| `titleSizeRelative` | 要接 | 绝对/相对三态语义，本地无（KI-C4） |
| `titleBold` | 要接 | 标题字重独立于正文（KI-C4） |
| `titleColor` | 要接 | 标题日间颜色（KI-C4） |
| `titleColorNight` | 要接 | 标题夜间颜色（KI-C4） |
| `titleLineSpacingExtra` | 要接 | 标题行距默认 12（KI-C4） |
| `titleLineSpacingSub` | 要接 | 分段标题第二段行距（KI-C4） |
| `titleTopSpacing` | 要接 | 标题上间距（KI-C4） |
| `titleBottomSpacing` | 要接 | 标题下间距（KI-C4） |
| `titleSegType` | 要接 | 长标题分段模式（KI-C4） |
| `titleSegScaling` | 要接 | 分段缩放夹 0–2（KI-C4） |
| `titleSegDistance` | 要接 | 分段起始位置默认 4（KI-C4） |
| `titleSegFlag` | 要接 | 分段识别字符（KI-C4） |

#### 1.5.5 菜单颜色（14 项）：要接 10、不接 4

| 字段 | 判定 | 理由与去处 |
| --- | --- | --- |
| `readMenuAccentColor` | 要接 | 菜单强调色用户可配（KI-E1） |
| `readMenuAccentColorNight` | 要接 | 同上，夜间侧（KI-E1） |
| `readMenuContainerColor` | 要接 | 菜单容器色，未设时回落到背景色（KI-E1） |
| `readMenuContainerColorNight` | 要接 | 同上，夜间侧（KI-E1） |
| `readMenuBlurColor` | 要接 | 模糊层着色（KI-E2） |
| `readMenuBlurColorNight` | 要接 | 同上，夜间侧（KI-E2） |
| `readMenuBorderColor` | 要接 | 菜单描边色（KI-E2） |
| `readMenuBorderColorNight` | 要接 | 同上，夜间侧（KI-E2） |
| `readMenuTextColor` | 要接 | 菜单文字色（KI-E2） |
| `readMenuTextColorNight` | 要接 | 同上，夜间侧（KI-E2） |
| `menuBgColor` | 不接 | `Config` 内 `@Transient` 的主题包承载字段（`ReadBookConfig.kt:540`），上游没有设置入口，改它的只有 `withMenuCurBg`（`:1002`）这类程序化调用；用户可配的是 `readMenuBgColor` 系列。本地没有主题包功能，无对应物 |
| `menuBgColorNight` | 不接 | 同上（`:544`） |
| `menuAcColor` | 不接 | 同上（`:542`） |
| `menuAcColorNight` | 不接 | 同上（`:546`） |

#### 1.5.6 菜单样式选择（2 项）：要接 2

| 字段 | 判定 | 理由与去处 |
| --- | --- | --- |
| `readMenuColorMode` | 要接 | 菜单配色来源（跟随/自定义），本地只有页面 `@State`（KI-E1） |
| `readMenuPaletteStyle` | 要接 | 调色板风格，本地条目存在无状态（KI-E1） |

#### 1.5.7 菜单模糊与边框数值（5 项）：要接 4、不接 1

| 字段 | 判定 | 理由与去处 |
| --- | --- | --- |
| `readMenuBlurAlpha` | 要接 | 模糊透明度夹 0–100（KI-E2） |
| `readMenuBlurRadius` | 要接 | 模糊半径夹 0–32（KI-E2） |
| `readMenuBorderWidth` | 要接 | 描边宽度夹 0–4（KI-E2） |
| `readMenuLensRadius` | 要接 | 镜头半径夹 0–48f；本地连条目都没有，需先上屏（KI-E6） |
| `menuBottomCornerRadius` | 不接 | `Config` 内 `@Transient`（`ReadBookConfig.kt:651`），与 `readMenuBottomCornerRadius` 是同一配置的两处声明；上游用户项是后者，本地已接 |

#### 1.5.8 菜单布局与玻璃效果（12 项）：要接 10、不接 2

| 字段 | 判定 | 理由与去处 |
| --- | --- | --- |
| `readMenuBottomBarBlurMode` | 要接 | 底栏模糊三档（KI-E4） |
| `readMenuBottomBarBlurStyle` | 要接 | 底栏模糊样式（纯色/渐变，KI-E4） |
| `readMenuBottomBarLiquidGlassButtons` | 要接 | 底栏按钮液态玻璃（KI-E4） |
| `readMenuFloatingBottomBar` | 要接 | 底栏悬浮（KI-E4） |
| `readMenuFloatingIconLiquidGlass` | 要接 | 悬浮图标液态玻璃（KI-E3） |
| `readMenuTopBarBlurMode` | 要接 | 顶栏模糊三档（KI-E5） |
| `readMenuTopBarBlurStyle` | 要接 | 顶栏模糊样式（KI-E5） |
| `readMenuTopBarLiquidGlassButtons` | 要接 | 顶栏液态玻璃（KI-E5） |
| `readMenuTopBarMergeButtons` | 要接 | 合并标题栏按钮（KI-E5） |
| `readMenuTopBarTitleCapsule` | 要接 | 标题栏胶囊（KI-E5） |
| `menuBottomHorizontalMargin` | 不接 | `Config` 内 `@Transient`（`:653`）主题包边距，上游无设置入口；本地底栏边距是布局常量 |
| `menuBottomBottomMargin` | 不接 | 同上（`:655`） |

#### 1.5.9 标题栏与图标（8 项）：要接 8

| 字段 | 判定 | 理由与去处 |
| --- | --- | --- |
| `readMenuCustomIcons` | 要接 | 标题栏悬浮图标映射（`Map<String,String>`，KI-E3） |
| `titleBarCustomIcons` | 要接 | 同上第二个 Map（KI-E3） |
| `showMenuIcon` | 要接 | 显示菜单图标（KI-A2，随菜单层） |
| `showTitleBarIcons` | 要接 | 显示标题栏图标，本地只有页面 `@State`（KI-E3） |
| `titleBarCompact` | 要接 | 标题栏紧凑（KI-E5） |
| `titleBarIconPosition` | 要接 | 图标位置夹 0–3（KI-E3） |
| `titleBarIconStyle` | 要接 | 图标样式夹 0–2（KI-E5） |
| `titleBarMode` | 要接 | 字符串三态，本地选项已有、仅不落盘（KI-E5） |

#### 1.5.10 亮度与滑块（5 项）：要接 5

| 字段 | 判定 | 理由与去处 |
| --- | --- | --- |
| `showBrightnessView` | 要接 | 亮度条显隐三值（KI-E1） |
| `brightnessVwPos` | 要接 | 亮度条位置（KI-E1） |
| `brightnessAuto` | 要接 | 自动亮度，本地连条目都没有（KI-E6） |
| `readBrightness` | 要接 | 阅读亮度默认 100，本地无亮度控制（KI-A9） |
| `readSliderMode` | 要接 | 进度条形态默认 `"0"`（KI-D5） |

#### 1.5.11 阅读模式与排版开关（4 项）：要接 2、不接 2

| 字段 | 判定 | 理由与去处 |
| --- | --- | --- |
| `readBodyToLh` | 要接 | 正文行高归一，本地只有恒 true 的占位开关（KI-A1） |
| `useZhLayout` | 要接 | 中文标点排版，本地无分支（KI-A1） |
| `readStyleSelect` | 不接 | 图片书/漫画的排版样式索引；本地无图片书类型，属[项目范围](../PROJECT.md)之外的设备/内容形态（明细表 A 块 `:96` 已判 `不适用`） |
| `comicStyleSelect` | 不接 | 同上，漫画侧（明细表 A 块 `:97` 已判 `不适用`） |

#### 1.5.12 朗读提醒（1 项）：不接 1

| 字段 | 判定 | 理由与去处 |
| --- | --- | --- |
| `readAloudDetachReminderEnabled` | 不接 | 朗读（TTS）在[项目范围](../PROJECT.md)之外，无朗读即无「分离提醒」可提醒；开关已上屏，明细表 A 块按 `未接` 登记（KI-A5） |

#### 1.5.13 高亮规则（独立仓储，1 项）：已接 1

| 字段 | 判定 | 理由与去处 |
| --- | --- | --- |
| `highlightRules` | 已接 | 本地由 `entry/src/main/ets/model/ReaderHighlightRule.ets` + `data/ReaderHighlightRuleRepository.ets` + `data/ReaderHighlightRuleEngine.ets` 独立模块承接，备份与恢复已在 r258/r260 接通；不需要在 `ReaderSettingsRepository.ets` 里再建字段 |

#### 1.5.14 仅见于 ReadSettings.kt 的其余字段（31 项）：要接 21、不接 10

| 字段 | 判定 | 理由与去处 |
| --- | --- | --- |
| `adaptSpecialStyle` | 要接 | 保留书籍自带样式，本地占位恒 true（KI-A1） |
| `paddingDisplayCutouts` | 要接 | 刘海屏安全区，本地占位恒 true（KI-A1） |
| `disableReturnKey` | 要接 | 需拦系统返回，与退出手势冲突待定调（KI-A3） |
| `autoSuggestDayNight` | 要接 | 到点提示切换背景（KI-A6） |
| `sliderVibrator` | 要接 | 进度条触感反馈（KI-A7） |
| `selectVibrator` | 要接 | 选字触感反馈（KI-A7） |
| `prevKeys` | 要接 | 上一页按键映射（KI-D1） |
| `nextKeys` | 要接 | 下一页按键映射（KI-D1） |
| `mouseWheelPage` | 要接 | 滚轮翻页，随桌面形态（KI-D1） |
| `textSelectMenuConfig` | 要接 | 划词菜单条目配置（KI-D2） |
| `expandTextMenu` | 要接 | 菜单展开态，本地只有预览 `@State`（KI-D2） |
| `showSelectMenuIcon` | 要接 | 选择菜单图标（KI-D2） |
| `doubleHorizontalPage` | 要接 | 横屏双页，属分页引擎改造（KI-D4） |
| `pageTouchSlop` | 要接 | 翻页触摸阈值（KI-D5） |
| `lastMarkingStyle` | 要接 | 沿用上次标记样式（KI-D6） |
| `chineseConverterType` | 要接 | 繁简转换三档，需自带字表（KI-C5） |
| `menuAlpha` | 要接 | 菜单不透明度，随菜单层（KI-A2） |
| `showReadTitleAddition` | 要接 | 阅读标题补充信息（KI-A2） |
| `readBarStyle` | 要接 | 阅读栏样式默认 1，上游被 `BackupConfig.kt:216` 列入备份键（KI-E6） |
| `readBarStyleFollowPage` | 要接 | 阅读栏样式跟随页面，上游 `model/ReadBook.kt:724` 消费（KI-E6） |
| `moreActionsConfig` | 要接 | 「更多」面板条目配置，上游 `ReadBookViewModel.kt:2150` 消费（KI-E6） |
| `autoChangeSource` | 不接 | 在线书源切换，[项目范围](../PROJECT.md)之外（KI-A5） |
| `defaultSourceChangeAll` | 不接 | 换源结果应用于全部书籍，同上（KI-A5） |
| `preDownloadNum` | 不接 | 章节预下载，依赖离线缓存子系统（KI-A11） |
| `preDownloadNumPrev` | 不接 | 同上（KI-A11） |
| `readUrlInBrowser` | 不接 | 跨应用跳转，需 browser skill（KI-A12） |
| `themeGridColumns` | 不接 | 本地背景面板是六方案列表而非网格，无消费面（KI-A10） |
| `optimizeRender` | 不接 | 上游只在 `Build.VERSION.SDK_INT <= Q` 分支生效，HOS 无对应老渲染管线（KI-A4） |
| `useNewTocSheet` | 不接 | 上游是「页内 Sheet / 独立目录页」二选一，本地固定独立目录页一态，无第二态可切（KI-A8） |
| `fontFolder` | 不接 | HOS 无法递归扫描任意用户目录；本地等价能力是系统字体枚举 + 导入到应用私有目录（KI-C6） |
| `volumeKeyPageOnPlay` | 不接 | 朗读期间的音量键行为，TTS 在范围之外（KI-D3） |


## 二、改名映射表

下列上游字段在本地以不同名字落地，语义等价，**不属缺口**。命名不一致会给后续比对带来误判，记录在此。

**2026-10-31 逐条核对落库**：15 项改名全部走完五项证据链——接口字段（`ReaderSettingsSnapshot`，`ReaderSettingsRepository.ets:137-203`）→ 默认值（`:381-449`）→ 读取（`:452-600`）→ 写回（`:756-866`）→ 至少一处消费端。**结论：15 项全部真落库**，没有一项只是「名字记在这儿」。核对时按**存储键**而非本地字段名查：`clickImgWay`/`tocUiUseReplace`/`tocCountWords`/`lineSpacingExtra`/`shadowColor` 五个的上游名就是本地存储键，`fontSize`/`pageAnimation`/`bottomItemsPerRow` 等则换成了本地名。

| 上游字段 | 上游位置 | 本地字段 | 本地位置 | 落库证据（接口 / 默认值 / 读键 / 写键 / 消费端） |
| --- | --- | --- | --- | --- |
| `textSize` | `ReadBookConfig.kt:246` | `fontSize` | `ReaderSettingsRepository.ets:139` | 默认 `:381`；读 `:452 store.get('fontSize')`；写 `:756 put('fontSize')` 夹 5–50；消费 `Index.ets:1677`、`ReaderPage.ets` 排版 |
| `textColor` / `textColorNight` | `ReadBookConfig.kt:55-56` | — | — | **不属改名，是真缺口。** 本地正文颜色由 `ReaderPage.ets:2710-2713` 的 `getReadingTextColor()` 硬编码：背景为 `#000000`/`#343832`/`#3C3F43` 时返回 `#D8D8DC`，否则 `#38383B`。用户不可配（登记 KI-C1） |
| `textSize`（标题侧） | `ReadBookConfig.kt:269` | 无字段 | `ReaderPage.ets:824` 硬编码 `fontSize + 4` | 这一条是真缺口，不是改名（登记 KI-C4，同一硬编码共 9 处） |
| `lineSpacingExtra` | `ReadBookConfig.kt:252` | `lineSpacing` | `ReaderSettingsRepository.ets:141` | 默认 `:383`；读 `:454 get('lineSpacingExtra')`；写 `:758 put('lineSpacingExtra')` 夹 0–20；消费 `Index.ets:1677`、`:1784` |
| `shadowColor` / `shadowColorN` | `ReadBookConfig.kt:543-544` | `textShadowColor` / `textShadowColorN` | `ReaderSettingsRepository.ets:153-154` | 默认 `:395`/`:396`；读 `:466 get('shadowColor')`、`:467 get('shadowColorN')`；写 `:770`/`:772`；消费 `BackupRepository.ets:539`、`:965`、`:1138` |
| `pageAnim` | `ReadBookConfig.kt:201` | `pageAnimation` | `ReaderSettingsRepository.ets:182` | 默认 `:428`；读 `:496 get('pageAnimation')`；写 `:818` 夹 0–5；消费 `Index.ets:1736` |
| `pageAnimSpeed` | `ReadBookConfig.kt:565` | `animationSpeed` | `ReaderSettingsRepository.ets:183` | 默认 `:429`；读 `:497 get('animationSpeed')`；写 `:819` 夹 0–3；消费 `Index.ets:1737`、`ReaderPage.ets:1063` 折算翻页时长 |
| `readMenuIconShowText` | `ReadBookConfig.kt:77` | `showBottomActionText` | `ReaderSettingsRepository.ets:167` | 默认 `:409`；读 `:481 get('showBottomActionText')`；写 `:800`；消费 `Index.ets:1703`/`:1810`、`ReaderPage.ets:3156` |
| `readMenuIconStyle` | `ReadBookConfig.kt:100` | `bottomIconStyle` | `ReaderSettingsRepository.ets:168` | 默认 `:410`；读 `:482`；写 `:801` 夹 0–2；消费 `Index.ets:1704`/`:1811`、`ReaderPage.ets:3159` |
| `readMenuIconItemsPerRow` | `ReadBookConfig.kt:102` | `bottomItemsPerRow` | `ReaderSettingsRepository.ets:169` | 默认 `:411`；读 `:483`；写 `:802` 夹 2–8；消费 `Index.ets:1705`/`:1812`、`ReaderPage.ets:1213-1237` 分列 |
| `readMenuIconRowCount` | `ReadBookConfig.kt:103` | `bottomRowCount` | `ReaderSettingsRepository.ets:170` | 默认 `:412`；读 `:484`；写 `:803` 夹 1–2；消费 `Index.ets:1706`/`:1813`、`ReaderPage.ets:3171` 底栏高度 |
| `bgStr` / `bgStrNight` | `ReadBookConfig.kt:537-538` | `dayPaperIndex` / `nightPaperIndex` | `ReaderSettingsRepository.ets:163-164` | 默认 `:405`/`:406`；读 `:477`/`:478`（仅 `styleVersion>=1` 认索引）；写 `:796`/`:797`，旧版本迁移分支在 `:605`/`:606`；消费 `BackupRepository.ets:948-951`、`:1085-1116` 与 `bgStr` 互转。本地用索引指向内置配色，上游存颜色字符串 |
| `useUnderline` | `ReadSettings.kt:24` | `underline` | `ReaderSettingsRepository.ets:155` | 默认 `:397`；读 `:468 get('underline')`；写 `:774`；消费 `ReaderPage.ets:2159` 驱动 `TextDecorationType`、`BackupRepository.ets:535`/`:967` |
| `progressBarBehavior` | `ReadSettings.kt:27` | `progressBehavior` | `ReaderSettingsRepository.ets:173` | 默认 `:419`；读 `:487 get('progressBehavior')`；写 `:806` 只认 `'chapter'` 否则 `'page'`；消费 `Index.ets:1709`/`:1816` |
| `clickImgWay` | `ReadSettings.kt:48` | `clickImageBehavior` | `ReaderSettingsRepository.ets:176` | 默认 `:422`；读 `:490 get('clickImgWay')`（**存储键仍写上游名**）；写 `:809` 限 `['0'..'4']`；消费 `Index.ets:1730`/`:1837` |
| `tocUiUseReplace` | `ReadSettings.kt:62` | `tocUseReplace` | `ReaderSettingsRepository.ets:174` | 默认 `:420`；读 `:488 get('tocUiUseReplace')`；写 `:807`；消费 `Index.ets:1728`/`:1835` |
| `tocCountWords` | `ReadSettings.kt:63` | `tocShowWordCount` | `ReaderSettingsRepository.ets:175` | 默认 `:421`；读 `:489 get('tocCountWords')`；写 `:808`；消费 `Index.ets:1729`/`:1836` |
| `clickActionTL`…`clickActionBR` | `ReadSettings.kt:70-78` | `clickRegionActions` | `ReaderSettingsRepository.ets:177` | 默认 `:423` 取 `[...READER_CLICK_REGION_DEFAULTS]`；读 `:491 get('clickRegionActions')`（JSON）；写 `:811` `JSON.stringify`；消费 `BackupRepository.ets:1170-1180` 把 9 个整型键逐项转成动作标签。9 个整型字段 → 1 个 9 元素字符串数组 |

## 三、阻塞项与后续顺序

盘点结论指向三个互不重叠的缺口，按收益排序：

1. **E 块菜单外观 40 行未接**：全部有控件无持久化。所需字段都是纯 UI 参数（颜色、圆角、模糊半径、玻璃开关），不触碰渲染引擎与排版算法，是唯一可以整块推进的部分，字段明细见 1.3 的「菜单」与「标题栏与图标」各组。前置条件：先在 `ReaderSettingsRepository.ets` 补齐字段与 `save` 分支，再把 `ReaderSettingsPage.ets` 的 `@State` 改为读仓储。可照抄同块已接的两条（`bottomActions`/`topActions`，`ReaderSettingsRepository.ets:804-805`）的链路。
2. **C 块标题排版 14 项**：需要同时改 `ReaderPage.ets` 的 9 处 `fontSize + 4` 硬编码（`:824`、`:1651`、`:1656`、`:2857`、`:2859`、`:2867`、`:2869`、`:2941`、`:2943`），并新增 `titleSizeRelative` 三态语义（上游回落规则见 `ReadBookConfig.kt:660-668`）。改动面比 E 块小但风险高，属排版视觉回归。
3. **C 块正文与背景 6 行 + 下划线虚线 4 行**：正文与背景 6 行对应 11 个字段（正文日/夜颜色 2、正文强调色 2、背景透明度 1、背景自定义 4、白天暗色状态栏 2），下划线虚线 4 行对应 4 个字段，均为单点参数，适合随其它模块顺带补齐。其中**正文日/夜颜色（`ReaderPage.ets:2710-2713` 的 `getReadingTextColor()` 硬编码）优先做**——它是用户最容易察觉的「不能改字色」，且与背景预设（`READER_BACKGROUND_STYLES`，`ReaderSettingsRepository.ets:339-346`）天然配套。

三处阻塞共 40 + 14 + 10 = 64 行未接（明细表口径），占明细表 97 行未接的多数。余下 33 行分布在 A 块 21 行、C 块 2 行、D 块 10 行（B 块已于 2026-10-31 复核清零），均为单点占位开关，不单独列阻塞。字段口径的 112 项见 1.3，与这里的行数不可相加。

未列为阻塞项的两类：EInk 相关 8 项判 `不适用`（范围之外）；颜色缓存字段 15 项不是缺口（上游 `@Transient` 解析缓存，本地用字符串不需要等价物）。

## 四、覆盖证明

本表对应 ZIP 类别 `readConfig`。按 [KEYWORDS.md](KEYWORDS.md) 的检索词 `ReadBookConfig|ReadSettings|ReadMenuConfig|"readConfig"|menuConfig|ReadPreferences|ReadBookStyleConfig|ReadSheetConfigUiState|expandTextMenu|showSelectMenuIcon|lastMarkingStyle` 命中 **105 个上游 `.kt` 文件**，并上界面白名单精确点名的 2 个（`ReadBookMenuBarSearch.kt`、`SelectionMenuMotion.kt`，见 [KEYWORDS.md](KEYWORDS.md) 的「界面白名单」节），接触面合计 **107 个**。本节把它们逐个分配：要么落到上面 A–G 某块的具体行，要么写明排除理由。判定可复跑：

```bash
bash scripts/upstream-surface.sh --coverage readConfig docs/parity/READER-CONFIG.md <上游根>
```

（`<上游根>` 指法见 [KEYWORDS.md](KEYWORDS.md) 的用法节。）最近一次实跑结果：`上游接触面：107 个 .kt 文件（其中界面白名单 2 个）/ 已分配 107 / 未分配 0 / 结论：覆盖证明通过（107 / 107 全部已分配）`。

### 接触面是怎么从 78 涨到 107 的（逐轮增量清单）

关键词是分五轮补的，每轮都补在一种具体的漏检形态上。下表是逐轮的净新增文件——**这 29 个文件就是本轮扩表的全部增量**，也是「未分配=0」这个结论背后真正被检查过的范围：

| 轮次 | 补的关键词 | 命中数 | 净新增 | 新增的文件 |
| --- | --- | --- | --- | --- |
| 起点 | `ReadBookConfig\|ReadSettings\|"readConfig"` | 78 | — | —（两个配置声明源 + 类别键名字面量） |
| ① | `ReadMenuConfig` | 85 | **7** | `ReadBookMenuBar.kt`、`ReadBookMenuBarBottom.kt`、`ReadBookMenuBarShared.kt`、`ReadBookMenuBarTitle.kt`、`sheet/BgmSceneSheet.kt`、`sheet/CastSheetCard.kt`、`sheet/ReadAloudCastSheet.kt` |
| ② | `menuConfig` | 91 | **6** | `ReadBookMenuBarFloating.kt`、`ReadBookMenuBarTool.kt`、`ReadBookRouteScreen.kt`、`ReadBookScreen.kt`、`ReadMenuActionDefs.kt`、`sheet/ReaderMoreActionsSheet.kt` |
| ③ | `ReadPreferences` | 94 | **3** | `sheet/GlobalThemePage.kt`、`sheet/ReadStyleSheet.kt`、`sheet/SystemMenuPage.kt` |
| ④ | `ReadBookStyleConfig`、`ReadSheetConfigUiState` | 100 | **6** | `sheet/BgTextConfigSheet.kt`、`sheet/HighlightRuleConfigSheet.kt`、`sheet/ShadowSetSheet.kt`、`sheet/ThemeListContent.kt`、`sheet/TypographyPage.kt`、`sheet/UnderlineConfigSheet.kt` |
| ⑤ | `expandTextMenu`、`showSelectMenuIcon`、`lastMarkingStyle` | 105 | **5** | `constant/PreferKey.kt`、`ui/book/read/MarkingSelectionMenu.kt`、`ui/book/read/TextActionSelectionMenu.kt`、`sheet/TextSelectMenuConfigSheet.kt`、`ui/config/readConfig/ReadConfigContract.kt` |
| 白名单 | 精确点名（不做目录 glob） | 107 | **2** | `ReadBookMenuBarSearch.kt`、`SelectionMenuMotion.kt` |

78 + 7 + 6 + 3 + 6 + 5 + 2 = **107**。

每轮的漏检形态不同，这是关键词一路加下去而不是一次拍脑袋定全的原因：

- ① `ReadMenuConfig` 是 `ReadBookContract.kt:467` 的 `data class`，菜单外观配置的**运行时载体**，只在界面层出现——引用它的文件写类型名，不写 `state.menuConfig`。
- ② `menuConfig` 是界面层写法 `state.menuConfig.xxx`，**只写字段不写类型名**的文件靠它捞到（`ReadBookScreen.kt:393/404/503` 就是典型）。
- ③ `ReadPreferences` 是 `ReadSettingsRepository.kt:21` 的 `typealias`，设置页拿的是这个别名，写全名 `ReadSettings` 的文件里反而没有它。
- ④ `ReadBookStyleConfig`（`ReadBookContract.kt:74`）与 `ReadSheetConfigUiState`（`:121`）是另外两个**只在界面层流动的配置载体**，参数类型既不叫 `ReadMenuConfig` 也不叫 `menuConfig`，字段名与 `ReadSettings` 大量重名却一个配置类名都不出现。
- ⑤ 三个字段名（`expandTextMenu`/`showSelectMenuIcon`/`lastMarkingStyle`）在界面层当**参数名**一路传递，宿主的读取点已被前几轮覆盖，但接收端（选择菜单、配置弹层、`PreferKey` 常量表）此前完全不在接触面里。
- 白名单只留 2 个：`ReadBookMenuBarSearch.kt`（只画已经算好的颜色，`colors: ReadMenuColors` 是值不是配置）与 `SelectionMenuMotion.kt`（55 行纯动画时长常量）。**不做目录 glob**——`ui/book/read` 目录共 114 个 `.kt`，整目录纳入会把 `pageestimate/`、`config/*Span.kt` 这类与配置无关的实现拖进来，多出的只是待解释条目。

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

### 4.6 阅读页菜单层：渲染端，落点已在 A–G 有行（21 个）

这批是 `ReadMenuConfig` 的**渲染端**：它们读 `state.menuConfig.xxx` 或收 `menuConfig: ReadMenuConfig` 参数，把 E 块的菜单外观行与 D 块的文字菜单行画上屏。不新增配置项，因此不产生新的 A–G 行，按「已排除：同一批配置项已有行」分配。

**为什么单列一节**：它们此前完全不在接触面里——文件里只出现 `menuConfig` 这个字段名和参数类型，不出现任何配置全名。补上 `ReadMenuConfig`/`menuConfig` 关键词后才被捞到，是这次扩表的主要增量。其中 `ReadBookMenuBarSearch.kt` 与 `SelectionMenuMotion.kt` 连 `menuConfig` 都没有，是逐个人工判断后按精确文件名进白名单的（见 [KEYWORDS.md](KEYWORDS.md) 的「界面白名单」节）。

| 上游文件 | 行数 | 读的配置 | 落到哪一行 |
| --- | --- | --- | --- |
| `ui/book/read/ReadBookScreen.kt` | 944 | `:393`/`:404` `menuConfig = state.menuConfig`、`:503` `menuConfig.bottomBarButtons` | E 块「底栏按钮配置」（已接）、E 块菜单外观各行的消费侧 |
| `ui/book/read/ReadBookRouteScreen.kt` | 1181 | `:214-217` `readMenuTopBarBlurMode`/`readMenuBottomBarBlurMode`/`readMenuFloatingBottomBar`；`:953` `showSelectMenuIcon` | E 块「顶栏模糊」「底栏模糊」「底栏悬浮」、D 块「显示选择菜单图标」 |
| `ui/book/read/ReadBookMenuBar.kt` | 1044 | `:172` `showTitleBarIcons`/`titleBarIconPosition`、`:190` `showBrightnessView` | E 块「显示标题栏图标」「标题栏悬浮图标位置」「显示亮度视图」 |
| `ui/book/read/ReadBookMenuBarBottom.kt` | 461 | `:138-144` `showBrightnessView`/`readBrightness`/`brightnessAuto`、`:217-218` `bottomBarButtons`/`readMenuCustomIcons`、`:237-238` `readMenuIconItemsPerRow`/`readMenuIconRowCount` | E 块底栏按钮与亮度相关的 6 行 |
| `ui/book/read/ReadBookMenuBarTitle.kt` | 1014 | `:92-95` `readMenuBorderWidth`/`readMenuBorderColor`/`readMenuBlurAlpha` | E 块「菜单栏边框宽度」「菜单栏边框颜色」「菜单模糊透明度」 |
| `ui/book/read/ReadBookMenuBarShared.kt` | 117 | `:48` `menuConfig: ReadMenuConfig` 参数、`:50-51` `readMenuBlurRadius`/`readMenuBlurAlpha` | E 块「菜单模糊半径」「菜单模糊透明度」 |
| `ui/book/read/ReadBookMenuBarFloating.kt` | 428 | `:73` `titleBarButtons`、`:110-111` `titleBarCustomIcons` | E 块「标题栏操作按钮」（已接）、「标题栏悬浮图标配置」 |
| `ui/book/read/ReadBookMenuBarTool.kt` | 478 | `:351` `menuConfig`、`:373` `readMenuIconShowText`、`:453` `readMenuCustomIcons` | E 块「菜单文字颜色」「标题栏悬浮图标配置」 |
| `ui/book/read/ReadBookMenuBarSearch.kt` | 201 | 无直接配置读取，`SearchBottomMenuContent(state: ReadBookUiState)` 走同一菜单壳 | E 块菜单外观行的消费侧（搜索模式下的底栏） |
| `ui/book/read/ReadMenuActionDefs.kt` | 517 | `:506` `titleBarCompact`、`:508` `titleBarActions` | E 块「标题栏紧凑」「标题栏操作按钮」 |
| `ui/book/read/TextActionSelectionMenu.kt` | 725 | `:86` `fun TextActionSelectionMenu(showSelectMenuIcon = …, …)` 由宿主传入 | D 块「显示选择菜单图标」「展开文字菜单」「上次标记样式」 |
| `ui/book/read/MarkingSelectionMenu.kt` | 592 | 无配置读取，`fun MarkingSelectionMenu(lastMarkingStyle: String, …)` 由宿主传入 | D 块「上次标记样式」 |
| `ui/book/read/SelectionMenuMotion.kt` | 55 | 无，纯动画时长常量 | D 块「选中文字菜单」的渲染实现，同批排除 |
| `ui/book/read/sheet/TextSelectMenuConfigSheet.kt` | 460 | `:67` `fun TextSelectMenuConfigSheet(showSelectMenuIcon: Boolean, onShowSelectMenuIconChange: …)` | D 块「选中文字菜单」「展开文字菜单」「显示选择菜单图标」 |
| `ui/book/read/sheet/ReaderMoreActionsSheet.kt` | 473 | `:91` `state.menuConfig.moreActionItems` | E 块「更多操作配置」 |
| `ui/book/read/sheet/SystemMenuPage.kt` | 905 | `:82`/`:227`/`:554` `preferences: ReadPreferences`；`:232-245` `titleBarCustomIcons`/`readBarStyle`/`readMenuColorMode`/`readMenuBgColor`/`readMenuAccentColor` | E 块菜单外观 42 行的设置面板主体（`:553` `BottomBarTab`、`:739` `TopBarTab`） |
| `ui/book/read/sheet/GlobalThemePage.kt` | 562 | `:82` `fun GlobalThemePage(styleConfig: ReadBookStyleConfig, preferences: ReadPreferences)`、`:95-100` `textSize`/`pageAnim`/`pageAnimSpeed`/`styleSelect`/`shareLayout` | A 块阅读设置主页、C 块排版入口 |
| `ui/book/read/sheet/ReadStyleSheet.kt` | 151 | `:40` `fun ReadStyleContent(preferences: ReadPreferences, …)` 排版设置页容器 | C 块正文排版 49 行的设置面板入口 |
| `ui/book/read/sheet/BgmSceneSheet.kt` | 336 | `:47` import `ReadMenuConfig`、`:78` `menuConfig: ReadMenuConfig? = null` | E 块菜单外观行的消费侧（段首配乐卡片沿用菜单配色）；业务归 `httpTTS` |
| `ui/book/read/sheet/CastSheetCard.kt` | 228 | `:25` import、`:43` 注释「圆角、模糊、液态玻璃、着色都取底栏那一套 `ReadMenuConfig`」、`:51` 参数 | E 块底栏圆角/模糊/液态玻璃 6 行；业务归 `httpTTS` |
| `ui/book/read/sheet/ReadAloudCastSheet.kt` | 325 | `:41` import、`:76` `menuConfig: ReadMenuConfig? = null` | 同上；业务归 `httpTTS` |

**排除理由**：这批文件没有引入 A–G 之外的新配置项，读的都是 E 块（菜单外观 42 行）与 D 块（文字菜单 4 行）已经登记过的字段。它们的缺口就是 E 块那 40 行「有控件无持久化」——本地 `ReaderSettingsPage.ets:399-462` 有对应条目但没有仓储字段，所以这些渲染端在本地没有对应的消费代码。**补 E 块字段时会自然补上这些渲染点，此处不重复计行。**

三个朗读外侧文件（`BgmSceneSheet.kt`、`CastSheetCard.kt`、`ReadAloudCastSheet.kt`）的业务归属是 `httpTTS` 类别，本次单列是因为它们靠 `ReadMenuConfig` 参数才被捞进接触面；配置口径上只贡献 E 块菜单外观的消费证据。

### 4.7 配置面板与状态载体：读的不是 `ReadMenuConfig`，是另外两个载体（7 个）

这批文件此前也不在接触面里，原因和 4.6 不同：它们的参数类型既不是 `ReadMenuConfig`，也不叫 `menuConfig`，而是**另外两个配置载体**——

- `ReadSheetConfigUiState`（`ReadBookContract.kt:121`，data class，正文/标题/下划线/阴影/页眉页脚的全量快照，约 60 字段）——弹层面板拿它当只读入参；
- `ReadBookStyleConfig`（`ReadBookContract.kt:74`，data class，阅读样式的可观察状态，含 `styleSelect`/`bgStr`/`bgType`/`gridColumns`/`styleItems` 等）——主题网格与背景面板拿它当入参。

两者都只在界面层出现，字段名与 `ReadSettings`/`ReadBookConfig` 大量重名，但**没有任何一个配置类的全名**。补 `ReadBookStyleConfig`、`ReadSheetConfigUiState` 两个类型名关键词后一次性捞到 6 个；再加三个字段名关键词（`expandTextMenu`/`showSelectMenuIcon`/`lastMarkingStyle`，它们只在界面层当参数传递，宿主的读取点已被 `ReadPreferences` 覆盖）捞到 `ReadConfigContract.kt` 与两个选择菜单。

| 上游文件 | 行数 | 读的配置 | 落到哪一行 |
| --- | --- | --- | --- |
| `ui/book/read/sheet/TypographyPage.kt` | 345 | `:56` `config: ReadSheetConfigUiState`；`:105-120`/`:252-253` 读 `tipHeader{Left,Middle,Right}`、`tipFooter{Left,Middle,Right}`、`headerMode`/`footerMode`/`showHeaderLine`/`showFooterLine` 共 10 个字段 | B 块页眉页脚 10 行（页眉页脚模式、两条分割线、六槽内容） |
| `ui/book/read/sheet/UnderlineConfigSheet.kt` | 163 | `:36` `config: ReadSheetConfigUiState`；`:40-47` 读 `underline`/`dottedLine`/`underlineExtend`/`underlineColor`/`underlineHeight`/`underlinePadding`/`dottedBase`/`dottedRatio` 共 8 个字段 | C 块「下划线开关/虚线/下划线颜色/粗细」（已接 4 行）+ C 块下划线虚线绘制参数 4 行（C-07..10） |
| `ui/book/read/sheet/ShadowSetSheet.kt` | 106 | `:35-39` 读 `textShadow`/`textShadowColor`/`shadowRadius`/`shadowDx`/`shadowDy` 共 5 个字段 | C 块文字阴影 5 行（已接） |
| `ui/book/read/sheet/BgTextConfigSheet.kt` | 311 | `:67` `styleConfig: ReadBookStyleConfig`；`:71-79` 读 `bgAlpha`/`bgStr`/`bgStrNight`/`bgType`/`bgTypeNight`/`darkStatusIcon`/`styleName`/`styleSelect` | C 块背景 6 行（C-04 背景透明度、C-05 背景颜色/图片、C-06 白天是否暗色状态栏）+ A 块阅读样式选择 |
| `ui/book/read/sheet/ThemeListContent.kt` | 882 | `:144` `styleConfig: ReadBookStyleConfig`；`:167`/`:370`/`:419` 读 `styleItems`/`gridColumns`/`styleSelect` | A 块「主题网格列数」（A-18，判**不接**：本地是六方案列表不是网格）+ A 块阅读样式选择 |
| `ui/book/read/sheet/HighlightRuleConfigSheet.kt` | 294 | `:55` `config: ReadSheetConfigUiState` 透传给子面板、`:53` `state: HighlightRuleConfigUiState` | 1.4「独立仓储 1 项」`highlightRules`（本地已有独立模块，判**已接**） |
| `ui/config/readConfig/ReadConfigContract.kt` | 118 | `:7` `data class ReadConfigUiState`，50 个字段的页面状态载体（`screenOrientation`/`keepLight`/`hideStatusBar`/`paddingDisplayCutouts`/`titleBarMode`/`readBodyToLh`/`useZhLayout`/`showBrightnessView`/`mouseWheelPage`/`volumeKeyPageOnPlay`/`expandTextMenu`/`showSelectMenuIcon`/`optimizeRender`/`disableReturnKey`/`prevKeys`/`nextKeys` 等） | A 块阅读配置总入口的状态定义；每个字段的落点见 A 块对应行 |

**排除理由**：和 4.6 一样，这 7 个文件没有引入 A–G 之外的新配置项——`TypographyPage` 读的是 B 块字段，`UnderlineConfigSheet`/`ShadowSetSheet`/`BgTextConfigSheet` 读的是 C 块字段，`ThemeListContent` 读的是 A 块字段，`HighlightRuleConfigSheet` 读的是独立仓储，`ReadConfigContract` 是 A 块那些字段的页面状态定义。**补对应字段时这些面板会自然接上，此处不重复计行。**

### 4.8 未分配

**0 个。** 107 个上游接触面文件全部分配完毕：映射到 A–G 行 **36** 个 + 排除 **71** 个（4.2 的 8、4.3 的 10、4.4 的 16、4.5 的 6、4.6 的 21、4.7 的 7，以及本节补记的 3 个）。

补记的 3 个是靠「类别键名字面量」与「字段名」而非配置类名进接触面的文件：

- `help/storage/BackupConfig.kt`（489 行，`:69` `private const val readConfigKey = "readConfig"`、`:146`/`:172` 进 `ignoreKeys`/`backupIgnoreKeys`、`:442`/`:461` 两个 `backupIgnoreReadConfig` 取值器）——**该类忽略开关的定义处**。整份 `config.xml` 的忽略语义都在这里，本地对应 `entry/src/main/ets/data/BackupRepository.ets` 的 `preferenceKeysByCategory` 与 `ignoreKeys` 判定。归「备份恢复」块（见 [BACKUP-RESTORE.md](../BACKUP-RESTORE.md)），不在本表的阅读界面行里。
- `ui/config/ConfigTag.kt`（15 行，`const val READ_CONFIG = "readConfig"`，同类还有 `THEME_CONFIG`/`COVER_CONFIG`/`BACKUP_CONFIG` 等 6 个）——**配置页面的路由标签常量**，不是备份逻辑。本地对应 `pages/` 下各设置页的路由名，无独立界面。
- `constant/PreferKey.kt`（521 行）——靠三个界面字段名关键词进接触面：`:498` `object ReadMenuBlurMode`、`:504` `object ReadMenuBlurStyle` 两个枚举在这里定义（E 块「顶栏模糊样式」「底栏模糊样式」的取值域），`expandTextMenu`/`showSelectMenuIcon`/`lastMarkingStyle` 三个 `const val` 键常量也在这里。**它是 readConfig 全部偏好键的常量表**，本表 A–G 各行的「上游位置」列凡是引用 `PreferKey.xxx` 的都落在这里。

这三个文件都是靠「类别键名字面量 / 字段名」而非配置类名被捞到的，正是 [KEYWORDS.md](KEYWORDS.md) 存储层维度要解决的漏检。`BackupConfig.kt` 与 `PreferKey.kt` 此前从未出现在 `readConfig` 的覆盖证明里，但它们分别是该类别忽略开关与偏好键的唯一定义处。

---

## 维护

改本表时同步改两处：

- `entry/src/main/ets/data/ReaderSettingsRepository.ets` 的字段定义——本表「本地位置」一列直接引用其行号。
- [ZIP 兼容总账](STATUS.md) 的 `readConfig` 行——本表是它的明细表。

改完本表须重跑「盘面」与第一节的计数，两处数字必须与实际表格行数闭合。

新增上游字段时先跑第一节的复核命令，确认是「真缺失」还是「改名已接」再落表，避免把改名误记为缺口。
