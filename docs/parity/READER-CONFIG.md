# 阅读配置对照表

本表按 [模块对照要求](../CODE-CONVENTIONS.md) 第四节点完一次，行粒度是一次用户可感知的操作。
状态四值：`已接` / `未接` / `不适用` / `待定`；`不适用` 写理由，`待定` 写阻塞项。**本表无 `待定` 行。**

- 盘点日期：2026-10-29
- 上游基线：`legado-with-MD3`（Android，Compose）
- 本地实现：`entry/src/main/ets`（HarmonyOS，ArkTS）

## 口径说明

三处容易误判的地方，先说清楚，避免后续重复返工：

1. **改名不等于未接。** 上游 `textSize`、`lineSpacingExtra`、`shadowColor`、`pageAnim`、`menuIconItemsPerRow` 等在本地以 `fontSize`、`lineSpacing`、`textShadowColor`、`pageAnimation`、`bottomItemsPerRow` 落地，语义等价。这类判 `已接`，映射关系见[第二节改名映射表](#二改名映射表)。**但 `textColor` 不属此类**——本地正文色是硬编码，是真缺口（详见 C 块首行）。
2. **控件存在不等于已接。** `entry/src/main/ets/pages/ReaderSettingsPage.ets` 的菜单外观条目（`menuSettingsContent()`，`:398`）共 39 个，控件齐备、点击有响应，但 `menuBorderEnabled`（`:168`）、`menuBarStyleMode`（`:165`）、`menuColorMode`（`:166`）等状态只存在于页面 `@State`，在 `ReaderSettingsRepository.ets` 中检索命中数为 0。退出设置页即丢失，也不驱动阅读页渲染。这类判 `未接`，不判 `已接`。
3. **`showNotMigrated()` 是显式占位。** `grep -c "showNotMigrated(" entry/src/main/ets/pages/ReaderSettingsPage.ets` 得 21 处调用、18 个不同名称（`:485`、`:494`、`:801`、`:837`、`:838`、`:839`、`:840`、`:848`、`:851`、`:863`、`:864`、`:867`、`:868`、`:869`、`:870`、`:873`、`:879`、`:883`、`:886`、`:887`、`:1242`），点开只弹提示。凡走这条路的判 `未接`，不因界面上显示了开关而判已接。

## 盘面

| 块 | 条数 | 已接 | 未接 | 不适用 |
| --- | --- | --- | --- | --- |
| A 阅读界面基础 | 28 | 11 | 15 | 2 |
| B 页眉页脚 | 24 | 23 | 1 | 0 |
| C 正文排版 | 47 | 23 | 24 | 0 |
| D 翻页与手势交互 | 12 | 8 | 4 | 0 |
| E 菜单与主题外观 | 39 | 0 | 39 | 0 |
| F 护眼与书签角标 | 9 | 9 | 0 | 0 |
| G 页边距 | 8 | 8 | 0 | 0 |
| 合计 | 167 | 82 | 83 | 2 |

> 早前口头估计「菜单外观 30-40 项全占位」方向对、原因错：不是没有控件，是有控件无持久化无渲染（见口径第 2 条）。逐项核完 E 块共 39 条，全部未接。

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
| 朗读时允许音量键翻页 | `ReadSettings.kt` | `ReaderSettingsPage.ets:851` | 未接 | 走 `showNotMigrated` | — | 朗读在[范围之外](../PROJECT.md)，开关已上屏故判 `未接` |

## E 菜单与主题外观

上游主体：`ReadBookConfig.kt:77-131`（`readMenu*` 系列 getter）、`Config` 内的 `@Transient menu*` 字段（`:643-658`）。
本地主体：`ReaderSettingsPage.ets:398-462`（`menuSettingsContent()`）、条目清单 `:1788-1840`。

**本块共同差异**：38 个条目全部有控件、可点击、有 `@State` 承载，但没有一条写入 `ReaderSettingsRepository.ets`，也不驱动 `ReaderPage.ets` 渲染。判 `未接` 的依据是「退出设置页即丢失 + 阅读页外观不变」，不是「没有控件」。

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
| 底栏按钮配置 | `ReadSettings.kt` | `ReaderSettingsRepository.ets:171-172` | 未接 | 本地已有 `bottomActions`/`topActions` 存配置，`:470` 只弹提示不打开面板 | 点开可排序、改显示与长按动作 | 数据结构在，编辑面板缺 |
| 底栏圆角 | `ReadBookConfig.kt:104` | `ReaderSettingsPage.ets:1821` | 未接 | 上游 `readMenuBottomCornerRadius` 夹取 0–32 | 调圆角后底栏卡片变圆 | — |
| 底栏悬浮 | `ReadBookConfig.kt:82` | `ReaderSettingsPage.ets:1822` | 未接 | 上游 `readMenuFloatingBottomBar` | 开关后底栏脱离屏幕边缘 | — |
| 底栏模糊 | `ReadBookConfig.kt:106` | `ReaderSettingsPage.ets:1823` | 未接 | 上游 `readMenuBottomBarBlurMode` 夹取 0–2 | 切三档后底栏背景变化 | — |
| 底栏模糊透明度 | `ReadBookConfig.kt:110` | `ReaderSettingsPage.ets:1824` | 未接 | 与「菜单模糊透明度」共用上游字段，本地无字段 | 调后底栏通透度变化 | — |
| 底栏模糊样式 | `ReadBookConfig.kt:108` | `ReaderSettingsPage.ets:1823` | 未接 | 上游 `readMenuBottomBarBlurStyle` 夹取 0–1（纯色/渐变） | 切「渐变」后底栏背景为渐变 | — |
| 底栏液态玻璃 | `ReadBookConfig.kt:86` | `ReaderSettingsPage.ets:1825` | 未接 | 上游 `readMenuBottomBarLiquidGlassButtons` | 开关后底栏出现玻璃质感 | — |
| 底栏按钮液态玻璃 | `ReadBookConfig.kt:86` | `ReaderSettingsPage.ets:1826` | 未接 | 同上字段的按钮级开关 | 开关后单个按钮出现玻璃质感 | — |
| 标题栏胶囊 | `ReadBookConfig.kt:85` | `ReaderSettingsPage.ets:1830` | 未接 | 上游 `readMenuTopBarTitleCapsule` | 开关后标题与章节合并成胶囊 | — |
| 标题栏模式 | `ReadBookConfig.kt:81` | `ReaderSettingsPage.ets:1831` | 未接 | 上游 `titleBarCompact`，本地上屏为三选一（`：570`） | 切「仅标题」后标题栏变矮 | — |
| 标题栏操作按钮 | `ReadSettings.kt` | `ReaderSettingsPage.ets:1832` | 未接 | 与「底栏按钮配置」同类，`:470` 只弹提示 | 点开可配置顶栏按钮 | — |
| 标题栏紧凑 | `ReadBookConfig.kt:81` | `ReaderSettingsPage.ets:1833` | 未接 | 与「标题栏模式」同源字段，本地重复上屏两次 | 开关后标题栏收紧 | 同一上游字段被拆成两个条目，属 UI 结构问题 |
| 标题栏图标样式 | `ReadBookConfig.kt:101` | `ReaderSettingsPage.ets:1834` | 未接 | 上游 `titleBarIconStyle` 夹取 0–2 | 切「描边」后图标变线框 | — |
| 顶栏模糊 | `ReadBookConfig.kt:105` | `ReaderSettingsPage.ets:1835` | 未接 | 上游 `readMenuTopBarBlurMode` 夹取 0–2 | 开关后顶栏背景模糊 | — |
| 顶栏模糊样式 | `ReadBookConfig.kt:107` | `ReaderSettingsPage.ets:1836` | 未接 | 上游 `readMenuTopBarBlurStyle` 夹取 0–1 | 切「渐变」后顶栏背景为渐变 | — |
| 顶栏液态玻璃按钮 | `ReadBookConfig.kt:83` | `ReaderSettingsPage.ets:1837` | 未接 | 上游 `readMenuTopBarLiquidGlassButtons` | 开关后顶栏按钮出现玻璃质感 | — |
| 合并标题栏按钮 | `ReadBookConfig.kt:84` | `ReaderSettingsPage.ets:1838` | 未接 | 上游 `readMenuTopBarMergeButtons` | 开关后相邻按钮合并 | — |
| 菜单镜头半径 | `ReadBookConfig.kt:114` | — | 未接 | 上游 `readMenuLensRadius` 夹取 0–48f，本地上屏条目都没有 | 调半径后高光范围变化 | — |
| 自动亮度 | `ReadBookConfig.kt:97` | — | 未接 | 上游 `brightnessAuto`，本地无字段无条目 | 开关后亮度跟随环境光 | — |

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

`ReaderSettingsRepository.ets` 相对上游 `ReadBookConfig.kt` 的 `comm` 差集共 70 项（上游 126 个 `val|var`，本地 111 个字段）。分类后：9 项判 `不适用`、14 项是颜色缓存、10 项改名已接、1 项另有独立仓储、**36 项真缺失**。复核命令（在 `N:\HarmonyProjects` 下执行）：

```
awk 'NR>=500 && NR<=900' legado-with-MD3/app/src/main/java/io/legado/app/help/config/ReadBookConfig.kt \
  | grep -oE "^\s+(private )?(val|var) [a-zA-Z0-9_]+" | awk '{print $NF}' | sort -u > /tmp/up.txt
grep -oE "^\s{2}[a-zA-Z][a-zA-Z0-9]*\??:" \
  legado-with-md3-harmonyos/entry/src/main/ets/data/ReaderSettingsRepository.ets | tr -d ' :?' | sort -u > /tmp/lo.txt
comm -23 /tmp/up.txt /tmp/lo.txt
```

### 1.1 EInk 专项（9 项）：判 `不适用`

`bgStrEInk`、`bgTypeEInk`、`darkStatusIconEInk`、`textColorEInk`、`textColorIntEInk`、`textAccentColorEInk`、`textAccentColorIntEInk`、`pageAnimEInk`、`shadowColorNightInt`。

理由统一：EInk 是墨水屏设备形态的专用配色与动画，属 [项目队列](../PROJECT.md)「范围之外」的「额外设备形态适配」。本地只建模日/夜两套（`paperIndex`/`dayPaperIndex`/`nightPaperIndex`，`ReaderSettingsRepository.ets:162-164`）。

### 1.2 颜色缓存字段（14 项）：不是缺口

`hex`、`initAccentColorInt`、`initColorInt`、`menuAcColorInt`、`menuAcColorNightInt`、`menuBgColorInt`、`menuBgColorNightInt`、`shadowColorInt`、`textColorInt`、`textColorIntNight`、`textAccentColorInt`、`textAccentColorIntNight`、`underlineColorInt`、`underlineColorNightInt`。

这些是上游 `Config` 里的 `@Transient` 解析缓存（`ReadBookConfig.kt:683-710`），把颜色字符串解析成 `Int` 后缓存，不属于用户可配置项。本地直接用颜色字符串（`textShadowColor`、`underlineColor` 存 `string`），不需要等价物。**不列入缺口计数。**

### 1.3 真缺失（36 项）

不按块归类——块归属以 A–G 明细表的实际行为准。这里只给完整字段名单，便于逐项消账。

| 字段组 | 条数 | 字段 |
| --- | --- | --- |
| 背景与颜色 | 9 | `bgAlpha`、`bgStr`、`bgStrNight`、`bgType`、`bgTypeNight`、`textColor`、`textColorNight`、`textAccentColor`、`textAccentColorNight` |
| 状态栏 | 2 | `darkStatusIcon`、`darkStatusIconNight` |
| 下划线与虚线 | 4 | `underlinePadding`、`underlineExtend`、`dottedBase`、`dottedRatio` |
| 标题排版 | 14 | `titleMode`、`titleSize`、`titleSizeRelative`、`titleBold`、`titleColor`、`titleColorNight`、`titleLineSpacingExtra`、`titleLineSpacingSub`、`titleTopSpacing`、`titleBottomSpacing`、`titleSegType`、`titleSegScaling`、`titleSegDistance`、`titleSegFlag` |
| 菜单外观 | 7 | `menuAcColor`、`menuAcColorNight`、`menuBgColor`、`menuBgColorNight`、`menuBottomBottomMargin`、`menuBottomCornerRadius`、`menuBottomHorizontalMargin` |

9 + 2 + 4 + 14 + 7 = 36。

### 1.4 三类之外的两种情况：既不是缺口也不是改名

- **改名已接 10 项**：`lineSpacingExtra`、`menuIconItemsPerRow`、`menuIconRowCount`、`menuIconShowText`、`menuIconStyle`、`pageAnim`、`pageAnimSpeed`、`shadowColor`、`shadowColorN`、`textSize`，见第二节映射表。
- **另有独立仓储 1 项**：`highlightRules`（`ReadBookConfig.kt:656`）不在 `ReaderSettingsRepository.ets` 中，但本地对应 `entry/src/main/ets/model/ReaderHighlightRule.ets`、`data/ReaderHighlightRuleRepository.ets`、`data/ReaderHighlightRuleEngine.ets` 三个文件，属高亮规则的独立模块，不计入本表缺口。

> 计数闭合：70（差集）= 9（EInk 不适用）+ 14（颜色缓存）+ 10（改名已接）+ 1（独立仓储）+ 36（真缺失）。E 块 39 条明细中只有 9 条落在字段差集里，其余 30 条是本地连字段都没有的菜单外观参数（本地按页面 `@State` 硬编码），不参与上面的 `comm` 比对——这正是「控件存在不等于已接」的由来。

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

## 三、阻塞项与后续顺序

盘点结论指向三个互不重叠的缺口，按收益排序：

1. **E 块菜单外观 39 项**：全部有控件无持久化。所需的 30 余个字段都是纯 UI 参数（颜色、圆角、模糊半径、玻璃开关），不触碰渲染引擎与排版算法，是唯一可以整块推进的部分。前置条件：先在 `ReaderSettingsRepository.ets` 补齐字段与 `updateReaderSettings` 分支，再把 `ReaderSettingsPage.ets` 的 `@State` 改为读仓储。
2. **C 块标题排版 14 项**：需要同时改 `ReaderPage.ets` 的 9 处 `fontSize + 4` 硬编码（`:824`、`:1651`、`:1656`、`:2857`、`:2859`、`:2867`、`:2869`、`:2941`、`:2943`），并新增 `titleSizeRelative` 三态语义（上游回落规则见 `ReadBookConfig.kt:660-668`）。改动面比 E 块小但风险高，属排版视觉回归。
3. **正文与背景散点 11 项**（正文日/夜颜色、正文强调色、背景透明度、背景自定义、白天暗色状态栏 2 项）+ **下划线虚线 4 项**：均为单点参数，适合随其它模块顺带补齐。其中**正文日/夜颜色（`ReaderPage.ets:2710-2713` 的 `getReadingTextColor()` 硬编码）优先做**——它是用户最容易察觉的「不能改字色」，且与背景预设（`READER_BACKGROUND_STYLES`，`ReaderSettingsRepository.ets:339-346`）天然配套。

三条合计 39 + 14 + 15 = 68，加上 1.4 的改名已接 10 项与独立仓储 1 项，与 `comm` 差集 70 的差额为 EInk 9 项与颜色缓存 14 项（均不计入缺口）。

未列为阻塞项的两类：EInk 相关 9 项判 `不适用`（范围之外）；颜色缓存字段 14 项不是缺口（上游 `@Transient` 解析缓存，本地用字符串不需要等价物）。

## 维护

改本表时同步改两处：

- `entry/src/main/ets/data/ReaderSettingsRepository.ets` 的字段定义——本表「本地位置」一列直接引用其行号。
- [ZIP 兼容总账](STATUS.md) 的 `readConfig` 行——本表是它的明细表。

改完本表须重跑「盘面」与第一节的计数，两处数字必须与实际表格行数闭合。

新增上游字段时先跑第一节的复核命令，确认是「真缺失」还是「改名已接」再落表，避免把改名误记为缺口。
