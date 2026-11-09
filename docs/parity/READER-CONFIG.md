# 阅读配置对照表

本表按 [盘点规约](../PARITY-RULES.md) 第二节点完一次，行粒度是**一个界面上的一个可感知操作**（不是「与本功能相关的几个按钮」，见第四节「盘点单位是界面，不是按钮」）。
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

1. **改名不等于未接。** 上游 `textSize`、`lineSpacingExtra`、`shadowColor`、`pageAnim`、`menuIconItemsPerRow` 等在本地以 `fontSize`、`lineSpacing`、`textShadowColor`、`pageAnimation`、`bottomItemsPerRow` 落地，语义等价。这类判 `已接`，映射关系见[第二节改名映射表](#二改名映射表)。**但 `textColor` 不属此类**——本轮之前本地正文色是硬编码，是真缺口；已于 KI-C1 补上 `textColor`/`textColorNight` 字段（详见 C 块首两行）。
2. **控件存在不等于已接。** `entry/src/main/ets/pages/ReaderSettingsPage.ets` 的菜单外观条目（`menuSettingsContent()`，`:399`；条目由 `getMenuSettingsEntries()`，`:1788` 生成）共 41 条，其中 5 条是分组标题，真实条目 36 条。绝大多数控件齐备、点击有响应，但 `menuBorderEnabled`（`:168`）、`menuBarStyleMode`（`:165`）、`menuColorMode`（`:166`）等状态只存在于页面 `@State`，在 `ReaderSettingsRepository.ets` 中检索命中数为 0。退出设置页即丢失，也不驱动阅读页渲染。这类判 `未接`，不判 `已接`。**例外只有两条**：`底栏按钮配置` 与 `标题栏操作按钮` 走 `handleMenuSettingsEntryClick()`（`:517-531`）打开真实配置面板并落盘（见 E 块对应两行）。
3. **上游配置有两个来源文件，缺一不可。** 本表早期只盘了 `ReadBookConfig.kt`（单本书可覆盖的 `Config`），漏掉 `domain/model/settings/ReadSettings.kt`（全书统一设置，114 个字段）。后者有一半字段与前者同名或同义，其余 53 个字段此前从未进表。两个文件合计声明 267 个名字，是本节字段口径的基数。
4. **`showNotMigrated()` 是显式占位。** `grep -c "showNotMigrated(" entry/src/main/ets/pages/ReaderSettingsPage.ets` 得 21 行命中，其中 1 行是 `:1242` 的函数定义，实际调用 20 处、18 个不同名称（`:485`、`:494`、`:801`、`:837`、`:838`、`:839`、`:840`、`:848`、`:851`、`:863`、`:864`、`:867`、`:868`、`:869`、`:870`、`:873`、`:879`、`:883`、`:886`、`:887`），点开只弹提示。凡走这条路的判 `未接`，不因界面上显示了开关而判已接。

## 盘面

| 块 | 条数 | 已接 | 未接 | 不适用 |
| --- | --- | --- | --- | --- |
| A 阅读界面基础 | 37 | 26 | 9 | 2 |
| B 页眉页脚 | 24 | 24 | 0 | 0 |
| C 正文排版 | 49 | 48 | 1 | 0 |
| D 翻页与手势交互 | 20 | 19 | 1 | 0 |
| E 菜单与主题外观 | 42 | 42 | 0 | 0 |
| F 护眼与书签角标 | 9 | 9 | 0 | 0 |
| G 页边距 | 8 | 8 | 0 | 0 |
| 合计 | 189 | 176 | 11 | 2 |

现 11 行未接**逐行**在 [KNOWN-ISSUES](../KNOWN-ISSUES.md#阅读配置行登记reader-configmd-的未接行) 登记了「为什么不修」与补法，本表备注列的 `KI-xx` 即其锚点，无裸「未接」。

> 逐条落库日志（改判理由、设备实测数值、锚点踩坑、已知差异）已搬到 [阅读配置 KI 落库过程日志](../history/validation/reader-config-ki-landing-log.md)。对照表只留状态与验收方式，过程记录归验证记录。

## A 阅读界面基础

上游主体：`legado-with-MD3/app/src/main/java/io/legado/app/help/config/ReadBookConfig.kt`（1054 行）、`app/src/main/java/io/legado/app/domain/model/settings/ReadSettings.kt`（122 行）。
本地主体：`entry/src/main/ets/data/ReaderSettingsRepository.ets`（2085 行）、`entry/src/main/ets/pages/ReaderSettingsPage.ets`（3954 行）。

| 上游能力 | 上游位置 | 本地位置 | 状态 | 差异说明 | 验收方式 | 备注 |
| --- | --- | --- | --- | --- | --- | --- |
| 屏幕方向 | `ReadSettings.kt` | `ReaderSettingsRepository.ets:184` | 已接 | 本地 `screenOrientation` 存字符串，页面上为三选一 | 切横屏后阅读页方向变化 | — |
| 保持屏幕常亮 | `ReadSettings.kt` | `ReaderSettingsRepository.ets:185` | 已接 | 本地 `keepLight` 存 `'0'`/`'60'`/`'300'`/`'600'`/`'-1'` | 设 60 秒后无操作自动息屏 | — |
| 隐藏状态栏 | `ReadBookConfig.kt:74` | `ReaderSettingsRepository.ets:178` | 已接 | — | 开关后状态栏消失 | — |
| 隐藏导航栏 | `ReadBookConfig.kt:75` | `ReaderSettingsRepository.ets:179` | 已接 | — | 开关后导航栏消失 | — |
| 阅读布局共享 | `ReadBookConfig.kt:71` | `ReaderSettingsRepository.ets:166` | 已接 | — | 开关后配置作用域变化 | — |
| 自动阅读速度 | `ReadBookConfig.kt:68` | `ReaderSettingsRepository.ets:181` | 已接 | — | 调速后滚动速率变化 | 朗读自 2026-11-09 起已纳入范围、尚未排期（[PROJECT.md](../PROJECT.md) `:24-44`），本行只描述调速本身已接 |
| 阅读位置锚点 | `ReadBookConfig.kt:79` | `ReaderSettingsRepository.ets:189` | 已接 | — | 开关后跳转章节可返回原位 | — |
| 底栏图标显示文字 | `ReadBookConfig.kt:77` | `ReaderSettingsRepository.ets:167` | 已接 | 上游 `readMenuIconShowText` → 本地 `showBottomActionText` | 开关后图标下方文字显隐 | — |
| 底栏图标样式 | `ReadBookConfig.kt:100` | `ReaderSettingsRepository.ets:168` | 已接 | 上游 `readMenuIconStyle` → 本地 `bottomIconStyle`，取值 0–2 | 切换后图标填充/描边变化 | — |
| 底栏每行图标数 | `ReadBookConfig.kt:102` | `ReaderSettingsRepository.ets:169` | 已接 | 上游夹取 2–8，本地滑块同区间 | 拖动后每行图标个数变化 | — |
| 底栏图标行数 | `ReadBookConfig.kt:103` | `ReaderSettingsRepository.ets:170` | 已接 | 上游夹取 1–2，本地滑块同区间 | 切到 2 行后底栏变高 | — |
| 正文行高适配 | `ReadSettings.kt:14` `readBodyToLh` | `ReaderSettingsRepository.ets:260`、读 `:741`、写 `:1184`；`ReaderSettingsPage.ets:1119`；`ReaderPage.ets:212` | 已接 | 上游文案是「扩展到刘海」；**上游没有渲染消费点**——`ReadBookConfig.kt:67` 只把它映射成只读快照，全仓 grep 20 处全是设置项/落库/契约/资源串，无一处读取用于排版。按「上游没有就不要这个效果」，本地只做可配 + 落库 + 随备份，不改渲染 | 开关落库为 `readBodyToLh`，重启后回显保持 | 存储键与字段同名（`PreferKey.kt:104`），随 config.xml 无条件备份 |
| 中文排版 | `ReadBookConfig.kt:76` `useZhLayout` | `ReaderSettingsRepository.ets:264`、读 `:743`、写 `:1186`；`ReaderSettingsPage.ets:1131`；`ReaderPage.ets:214`、布局 key `:1802` | 已接 | 上游文案是「使用自定义中文分行」。断行器 `ChineseLineBreaker.kt` 在 `ReaderPaginator.kt:559`/`:721` **无条件**使用、不看开关；开关唯一去处是 `PageEstimateConfig.kt:61` 的 `add(useZhLayout)` 进布局签名。本地照此只把 `useZhLayout` 拼进 `getFullBookPaginationLayoutKey()`，改它触发重排，不改断行算法。**r329 起本地断行已换成系统原生 `@ohos.graphics.text`（与上游 `StaticLayout` 同一底座），自造的 `ChineseLineBreaker.ets` 已删**——所以「开关不改变断行算法」这条在本地与上游都成立，不是遗漏 | 开关落库为 `useZhLayout`；改动后旧页数缓存失效并重算 | 存储键同名（`PreferKey.kt:150`） |
| 适配刘海屏 | `ReadSettings.kt:11` `paddingDisplayCutouts` | `ReaderSettingsRepository.ets:268`、读 `:745`、写 `:1188`；`ReaderSettingsPage.ets:1125`；`ReaderPage.ets:216`、`applyReaderDisplayCutout()` `:812`、`readerCutoutLeftInset()` `:842` | 已接 | 上游文案是「填充刘海区域」。真实消费点 `ui/book/read/ReaderContentAvoidancePolicy.kt:30-48`：`val cutout = if (paddingDisplayCutouts) insets else SystemBarInsets()`，左右取 `cutoutLeftPx`/`cutoutRightPx`、底部 `navigationBarBottomPx + cutoutBottomPx`，顶部只在状态栏占位消失时才避让。本地用 `getWindowAvoidArea(TYPE_CUTOUT)` 取左右与底部写进三个 inset，`getBodyContentWidth()`/`getBodyContentHeight()` 各减一次。**已知差异：顶部避让仍由外层状态栏 padding 承担，未按「占位消失」分支再补 cutoutTopPx** | 开关落库为 `paddingDisplayCutouts`，左侧有缺口时正文左边界内缩 | 存储键同名（`PreferKey.kt:337`），缺省 0（无缺口设备无变化） |
| 适配特殊样式 | `ReadSettings.kt:18` `adaptSpecialStyle` | `ReaderSettingsRepository.ets:272`、读 `:747`、写 `:1190`；`ReaderSettingsPage.ets:1137`；`ReaderPage.ets:218`、`onAdaptSpecialStyleChanged()` `:886`；`LocalTextSemantics.ets:94`/`:107`；`LocalReaderPaginator.ets:492`/`:742` | 已接 | 上游 `ReaderChapterSource.kt:158-166`：`[newpage]` 独占一段即成为 `PageBreak`，`<usehtml>...</usehtml>` 整段成为 `Html` 块；关闭时按字面文字显示。本地 `LocalTextSemantics.parse()` 增第三参识别两个标记并打 `pageBreak`/`richHtml`；分页器两条路径都按 `pageBreak` 强制换页；`<usehtml>` 整段单 part 不逐字排版。改开关触发重读章节 | 开关落库为 `adaptSpecialStyle`；正文含 `[newpage]` 时该段独占新页 | 存储键同名（`PreferKey.kt:117`）；本地不执行 HTML，富文本段按纯文本整段渲染 |
| 显示菜单图标 | `ReadBookConfig.kt:78`（`ReadSettings.kt:119`，默认 `false`） | `ReaderSettingsPage.ets:1512` | 已接 | 存储键 `showMenuIcon`，`ReaderSettingsRepository.ets:443` 声明、`:1043` 读、`:1389` 归一、`:1625` 写；面板 `ReaderSettingsPage.ets:1512` 的 `MenuSettingSwitch`；消费 `ReaderPage.ets:4586-4593`（「更多」网格面板图标）；在 `BackupConfig.kt:258` 忽略清单内，不随 config.xml 导出 | 总开关关闭后阅读页菜单图标消失 | 2026-11-01 KI-A2 落库：面板拨动即落库、`aa force-stop` 重启后回显保持；「更多」面板的图标显隐因模拟器无正文可读的书未做像素级取证，见 [VALIDATION](../VALIDATION.md) |
| 禁用返回键 | `ReadSettings.kt:50` `disableReturnKey`；面板 `MoreConfigSheet.kt:443-448`、`ReadConfigScreen.kt:404-407`；契约 `ReadBookContract.kt:2061`、`ReadConfigUpdateDelegate.kt:724-726` | `ReaderSettingsRepository.ets:236`、读 `:709`、写 `:1141`；`ReaderSettingsPage.ets:1151`；`BackupRepository.ets:878`（config.xml 写出）、`:2037`-`:2038`（恢复） | 已接 | 存储键与上游同名 `disableReturnKey`（`PreferKey.kt:420`），默认 `false`。**上游只有这个配置项，没有对应的拦截实现**：全仓对 `disablereturn` 大小写不敏感共 21 处，全部是设置项/落库/契约/资源字符串/一个单元测试断言，没有任何 `BackHandler`/`onBackPressed`/`KEYCODE_BACK` 消费点；阅读页真正的返回处理在 `ReadBookRouteScreen.kt:240-249`，只按 sheet/搜索/自动翻页/菜单层级分支，不读该字段。按「上游有这个配置就保留、上游没有这个效果就不要」，本地只做可配 + 落库 + 随备份，不加返回键拦截。 | 开关拨到开 → 偏好文件出现 `<bool key="disableReturnKey" value="true"/>`；注入 `true` 重启后开关回显为开；拨回关 → `false`。 | 见 本机归档 `docs/history/known-issues/reader-config-landed.md` 的 KI-A3（不随公开仓库发布） |
| 优化正文渲染 | `ReadSettings.kt` | `ReaderSettingsPage.ets:863` | 未接 | 走 `showNotMigrated('优化正文渲染')` | 开关后长章节渲染耗时变化 | 见 [KNOWN-ISSUES](../KNOWN-ISSUES.md#阅读配置行登记reader-configmd-的未接行) KI-A4 |
| 阅读标题补充信息 | `ReadSettings.kt:55`（`showReadTitleAddition`） | `ReaderSettingsRepository.ets:451` | 已接 | 上游 `showReadTitleAddition` 默认 **true**；全仓 29 处命中全是键名/落库/映射/字段/契约/设置界面/只读快照/单测，**没有任何渲染消费点**，本地只做可配 + 落库，不造渲染效果。存储键 `showReadTitleAddition`，读 `ReaderSettingsRepository.ets:1044`、写 `:1626`；面板 `ReaderSettingsPage.ets:1511`（文案对齐上游「展示顶部工具栏附加区域」，`values-zh-rCN/strings.xml:1395`）；`BackupRepository.ets:939` 导出、`:2132-2133` 恢复 | 拨动「展示顶部工具栏附加区域」→ 偏好文件出现 `showReadTitleAddition`；`aa force-stop` 重启后保持 | 见 本机归档 `docs/history/known-issues/reader-config-landed.md` 的 KI-A2（不随公开仓库发布） |
| 朗读悬浮窗分离提醒 | `ReadBookConfig.kt:80` | `ReaderSettingsPage.ets:887` | 未接 | 走 `showNotMigrated('朗读悬浮窗分离提醒')` | — | 朗读自 2026-11-09 起**已纳入范围、尚未排期**（[PROJECT.md](../PROJECT.md) `:24-44`），开关已上屏故判 `未接`；见 [KNOWN-ISSUES](../KNOWN-ISSUES.md#阅读配置行登记reader-configmd-的未接行) KI-A5 |
| 自动切换书源 | `ReadSettings.kt` | `ReaderSettingsPage.ets:868` | 未接 | 走 `showNotMigrated('自动切换书源')` | — | 在线书源抓取自 2026-11-09 起**已纳入范围、尚未排期**（[PROJECT.md](../PROJECT.md) `:24-44`），开关已上屏故判 `未接`；见 [KNOWN-ISSUES](../KNOWN-ISSUES.md#阅读配置行登记reader-configmd-的未接行) KI-A5 |
| 换源结果应用于全部书籍 | `ReadSettings.kt` | `ReaderSettingsPage.ets:869` | 未接 | 走 `showNotMigrated('换源结果应用于全部书籍')` | — | 同上；见 [KNOWN-ISSUES](../KNOWN-ISSUES.md#阅读配置行登记reader-configmd-的未接行) KI-A5 |
| 自动切换日夜模式提醒 | `ReadSettings.kt` | `ReaderSettingsPage.ets:1138` | 已接 | 上游 `ReadSettings.kt:43`，面板 `ReadConfigScreen.kt:339-345`；采集 `ReadBookRouteScreen.kt:1089-1138`（`TYPE_LIGHT` + `SENSOR_DELAY_NORMAL` + `delay(1.seconds)` 取一帧 + `delay(15.minutes)` 循环），判定 `ReadStyleDelegate.kt:503-555`（`DARK_LUX_THRESHOLD=8f`/`BRIGHT_LUX_THRESHOLD=100f`/`LIGHT_LUMINANCE_THRESHOLD=0.35`/10 分钟冷却），胶囊 `ReadBookFloatingActionBar.kt:122-154`（底距 88dp、5 秒自动消失、切换/关闭）。本地存储键同名；订阅 `Index.ets` 的 `startReaderAmbientLightWatch()`（`sensor.on(sensor.SensorId.AMBIENT_LIGHT, …, { interval: 1000000000 })`），判定 `checkReaderDayNightReminder()`，胶囊 `ReaderPage.ets` 的 `ReaderDayNightReminderCapsule()` | `hidumper -s SensorService -a '-l'` 可见 `AMBIENT LIGHT \|sensorId:5`，订阅后 `-a '-o'` 显示已打开；注入 `autoSuggestDayNight=true` + `readerNightMode=false` 后进阅读页，连续 4 轮 dump 前 2 轮读到「当前环境光较暗，是否切换至深色模式？」与「关闭」，后 2 轮消失（弹出 + 5 秒自动消失都对） | 见 本机归档 `docs/history/known-issues/reader-config-landed.md` 的 KI-A6（不随公开仓库发布） |
| 阅读进度条触感反馈 | `ReadSettings.kt:36`（`sliderVibrator`） | `ReaderSettingsPage.ets:892` | 已接 | **上游本身没有这个效果**：`sliderVibrator` 全仓只出现在设置项 `MoreConfigSheet.kt:360`、`ReadConfigScreen.kt:293` 与仓储读写，`feature/reader` 零消费点，`ReadBookMenuBarBottom.kt` 也没有 haptic。按「上游有就保留、没有就不要」本地只做可配+落库+随备份，不加振动。存储键 `sliderVibrator`，读 `ReaderSettingsRepository.ets:538`、写 `:872` | 开关可拨并落库：拨到开→偏好文件出现 `sliderVibrator` = `true`，拨回→`false` | 见 本机归档 `docs/history/known-issues/reader-config-landed.md` 的 KI-A7（不随公开仓库发布） |
| 使用新版目录 | `ReadSettings.kt` | `ReaderSettingsPage.ets:873` | 未接 | 走 `showNotMigrated('使用新版目录')` | 开关后目录面板形态变化 | 见 [KNOWN-ISSUES](../KNOWN-ISSUES.md#阅读配置行登记reader-configmd-的未接行) KI-A8 |
| 文字选择触感反馈 | `ReadSettings.kt:41`（`selectVibrator`） | `ReaderSettingsPage.ets:897` | 已接 | 上游消费点 `ReadBookRouteScreen.kt:755 selectionHapticsEnabled` → `ReaderCanvasSurface.kt:1109`（`HapticFeedbackType.LongPress`，长按选中首个词）与 `:1225`（`TextHandleMove`，拖手柄后选区变化）。本地 `data/ReaderHaptics.ets` 的 `selectionStart`（40ms）/`selectionMove`（15ms），触发点 `ReaderPage.ets:1984`/`:1986`（`updatePendingLineSelection` 里选区真的变化才振）。存储键 `selectVibrator`，读 `ReaderSettingsRepository.ets:539`、写 `:873` | 开关可拨并落库：拨到开→偏好文件出现 `selectVibrator` = `true`，拨回→`false`；模拟器无马达，振动本身无法在设备上确认 | 见 本机归档 `docs/history/known-issues/reader-config-landed.md` 的 KI-A7（不随公开仓库发布） |
| 漫画阅读样式 | `ReadBookConfig.kt:70` | — | 不适用 | 上游 `comicStyleSelect` 为漫画阅读专用 | — | 漫画/图片书不在[项目队列](../PROJECT.md)范围，本地无图片书类型 |
| 阅读样式选择（漫画分支） | `ReadBookConfig.kt:69` | — | 不适用 | 上游 `readStyleSelect` 在漫画会话下生效 | — | 同上，`styleSelect`（`:98`）取漫画分支时无意义 |
| 阅读亮度 | `ReadSettings.kt:22` | `ReaderSettingsRepository.ets:243` | 已接 | 上游 `readBrightness: Int = 100`（`ReadSettings.kt:22`），存储键是 `brightness`（`PreferKey.kt:151`，**字段名与键名不同**）；`ReadBookController.kt:3179-3187` 把 `readBrightness / 100f` 写进窗口亮度，`brightnessAuto` 为真时用 `BRIGHTNESS_OVERRIDE_NONE` 交回系统；开书时 `:1833` 应用、`:3192` 退出时还原原值。本地 `ReaderSettingsRepository.ets:243`/读 `:733`/写 `:1174`，`ReaderPage.ets:747` 走 `setWindowBrightness(readBrightness / 100)`，`:741` `restoreReaderBrightness()` 用 `-1` 还原（HOS 的 `-1` 等价 `BRIGHTNESS_OVERRIDE_NONE`），底栏亮度条 `ReaderPage.ets:2544` | 调暗后退出重进亮度保持；`brightness=20` 与 `100` 两次截图对比 | 见 本机归档 `docs/history/known-issues/reader-config-landed.md` 的 KI-A9（不随公开仓库发布） |
| 阅读菜单不透明度 | `ReadSettings.kt:13` | `ReaderSettingsRepository.ets:456` | 已接 | 上游 `menuAlpha` 默认 100（`ReadSettings.kt:13`），是整层不透明度；**全仓没有任何渲染消费点**（`ReadBookMenuBar.kt:484-492` 的 `dragMenuAlpha` 是 `readMenuBlurAlpha` 的局部变量、`TextActionSelectionMenu.kt:197` 的 `quickMenuAlpha` 也是局部变量、`res/xml/pref_config_read.xml:53` 那份旧 xml 全仓已无引用），因此本地只做落库、不上屏。存储键 `menuAlpha`，读 `ReaderSettingsRepository.ets:1045`、写 `:1627`；`BackupRepository.ets:941` 导出、`:2134` 恢复（不在上游忽略清单，随 `config.xml` 备份） | 拨动后偏好文件出现 `menuAlpha`；`aa force-stop` 重启后值不变 | 与 E 块 `readMenuBlurAlpha` 是不同字段（后者已由 KI-E4/E2 接上并驱动底色）；见 本机归档 `docs/history/known-issues/reader-config-landed.md` 的 KI-A2（不随公开仓库发布） |
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

本地主体：`ReaderSettingsRepository.ets:138-161`、渲染侧 `entry/src/main/ets/pages/ReaderPage.ets`（7194 行）。

| 上游能力 | 上游位置 | 本地位置 | 状态 | 差异说明 | 验收方式 | 备注 |
| --- | --- | --- | --- | --- | --- | --- |
| 正文日间颜色 | `ReadBookConfig.kt:55` | `ReaderSettingsRepository.ets:228` | 已接 | 上游 `textColor` 可配（默认 `#3E3D3B`）；本地新增 `textColor` 字段，默认 `#38383B`（沿用原硬编码观感，见 `:505`），读 `:835`、写 `:956`；`ReaderPage.ets` 的 `getReadingTextColor()` 改为「配置色非空优先，空则回落原三值判断」 | 在「自定义阅读背景」面板的「日间文字颜色」色板选色 → 阅读页正文字变该色。已实测：注入 `#DB4B4B` 后正文与章节标题同时变红，改回 `#38383B` 恢复正常（docs/VALIDATION.md 2026-10-31 KI-C1/KI-C2 节） | 上游默认 `#3E3D3B` 与本地原硬编码 `#38383B` 差一档，取本地原值以免升级后观感突变；见 本机归档 `docs/history/known-issues/reader-config-landed.md` 的 KI-C1（不随公开仓库发布） |
| 正文夜间颜色 | `ReadBookConfig.kt:56` | `ReaderSettingsRepository.ets:230` | 已接 | 上游 `textColorNight`（默认 `#ADADAD`）；本地新增 `textColorNight` 字段，默认 `#D8D8DC`（沿用原硬编码，见 `:506`），读 `:836`、写 `:957`；`ReaderPage.ets` 夜间取该值 | 切夜间后在「夜间文字颜色」色板选色 → 阅读页正文字变该色 | 同上；见 本机归档 `docs/history/known-issues/reader-config-landed.md` 的 KI-C1（不随公开仓库发布） |
| 正文强调色 | `ReadBookConfig.kt:62` | `ReaderSettingsRepository.ets:235` | 已接 | 上游 `textAccentColor`/`Night` 两套（`#834E00`/`#FE4D55`），消费点是链接文字、搜索结果与朗读中段落（`ReaderCanvasSurface.kt:2997`）；本地新增 `textAccentColor`/`textAccentColorNight` 两字段，默认与上游一致（`:508` 起），读 `:837`、写 `:958`，随 `ReaderPage.ets` 的 `textAccentColor` prop 传入 | 面板「日间强调色」「夜间强调色」选色 → 落库并可随备份导出 | **本地没有链接/搜索结果/朗读高亮这三条着色路径**（阅读页搜索只切路由、朗读尚未迁移），按「上游有这个问题就保留、上游没有就不要这个效果」，只做可配+落库+随备份，不发明新着色效果；见 本机归档 `docs/history/known-issues/reader-config-landed.md` 的 KI-C1（不随公开仓库发布） |
| 背景透明度 | `ReadBookConfig.kt:198` | `ReaderSettingsRepository.ets:247` | 已接 | 上游 `bgAlpha` 0..100 百分比，只作用于背景图片（`ReaderBackgroundAlpha.kt` 的 `percent / 100f`）；本地新增 `bgAlpha` 字段，默认 100（`:516`），读 `:846`、写 `:964`，`ReaderPage.ets` 的 `backgroundImageAlpha()` 做同样换算 | 面板「背景透明度」滑块 0..100 → 落库；设了背景图时图按比例透出 | 与上游一致，**只作用于背景图片、不作用于纯色背景**；见 本机归档 `docs/history/known-issues/reader-config-landed.md` 的 KI-C2（不随公开仓库发布） |
| 背景颜色/图片 | `ReadBookConfig.kt:537-551` | `ReaderSettingsRepository.ets:241-246` | 已接 | 上游 `bgStr` 存任意颜色串、`bgType` 区分 0=颜色/1=assets 图/2=自选图，颜色与图片共用 `bgStr`（`ReadBookConfig.kt:549`）；本地新增 `bgStr`/`bgStrNight`/`bgType`/`bgTypeNight` 四字段（默认空串 + 0，见 `:511-515`），读 `:842-845`、写 `:960-963`。`paperIndex` 六方案降级为「未自定义时的预设」：`Index.getPaperColor()` 先看 `bgType === 0 && bgStr 非空`，否则回落六方案。背景图由新建的 `data/ReaderBackgroundImageRepository.ets` 选择并复制进 `filesDir/reader-background/`，`ReaderPage.ets` 用 `Image(...).objectFit(ImageFit.Cover).opacity(...)` 铺在正文下层 | 面板「日间/夜间背景颜色」色板选色 → 阅读页背景变该色（已实测：日间 `#FFFFFF` 后阅读页中心像素为 `(255,255,255)`）；「日间/夜间背景图片」选择按钮 → 系统文件选择器弹出（已实测弹出），选中后背景铺图 | 图片选择器在模拟器上能弹出但无可选图片、且沙箱 `files` 目录不可写，**背景图渲染与透明度只到代码层核对**；见 本机归档 `docs/history/known-issues/reader-config-landed.md` 的 KI-C2（不随公开仓库发布） |
| 白天是否暗色状态栏 | `ReadBookConfig.kt:552` | `ReaderSettingsRepository.ets:249` | 已接 | 上游 `darkStatusIcon`/`darkStatusIconNight`（默认 true/false），Android 侧落在 `isAppearanceLightStatusBars`；本地新增两字段（`:518` 起），读 `:847`、写 `:965`，`ReaderPage.ets` 的 `applyReaderStatusBarIcon()` 用 `window.setWindowSystemBarProperties({ statusBarContentColor })` 落地（深色图标 `#E5000000`、浅色 `#E5FFFFFF`），退出阅读页由 `restoreReaderStatusBarIcon()` 还原 | 面板「日间/夜间深色状态栏图标」拨动 → 阅读页状态栏图标变深/变浅。已实测：`darkStatusIconNight` false 时状态栏亮像素 6726，改 true 后同一区域 0 | 见 本机归档 `docs/history/known-issues/reader-config-landed.md` 的 KI-C2（不随公开仓库发布） |
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
| 下划线偏移量 | `ReadBookConfig.kt:322` | `ReaderSettingsRepository.ets:161`、`ReaderCanvasSurface.ets` 的 `drawLineUnderline` | 已接 | 上游 `underlinePadding` 默认 10，绘制时取 `(值 - 10)` 作相对偏移（`LegacyReaderPaginationStyleFactory.kt:68`）。本地同名落地：接口 `:161`、默认 `:506`、读 `:620`、写 `:1018`，绘制：`ReaderPage.ets` 的 `resolveUnderlineOffsetVp()` 换算成 `ReaderCanvasStyle.underlineOffsetPx`，由 `ReaderCanvasSurface.ets` 的 `drawLineUnderline()` 用 `drawing.Pen` 画在画布上 | 设备实测：`underlinePadding` 0 / 10 / 20 三档，同一行下划线所在 y 分别为 409 / 444 / 478，每档差 ~35px（10vp × 3.5 密度），线性关系成立 | 见 本机归档 `docs/history/known-issues/reader-config-landed.md` 的 KI-C3（不随公开仓库发布） |
| 下划线延伸 | `ReadBookConfig.kt:325` | `ReaderSettingsRepository.ets:162`、`ReaderCanvasSurface.ets`（`drawLineUnderline`） | 已接 | 上游 `underlineExtend` 对应 `ReaderPaginator.kt:449` 的 `extendToColumn`：整列 or 该行实际文字左右边界。本地同名落地：接口 `:162`、默认 `:507`、读 `:621`、写 `:1019`，绘制：`ReaderPage.ets` 的 `resolveUnderlineWidthVp()`/`underlineExtend` 换算成画布样式，由 `ReaderCanvasSurface.ets` 的 `drawLineUnderline()` 决定右端（`underlineExtend ? bodyWidthPx : min(bodyWidthPx, line.contentWidth * vpScale)`） | 设备实测：关闭时短行 `x0=56 x1=720`（宽 665）；打开后所有行统一 `x0=56 x1=1223`（宽 1168），即延伸到正文列宽 | 见 本机归档 `docs/history/known-issues/reader-config-landed.md` 的 KI-C3（不随公开仓库发布） |
| 自定义虚线长度基准 | `ReadBookConfig.kt:331` | `ReaderSettingsRepository.ets:163`、`ReaderCanvasSurface.ets`（`drawLineUnderline`） | 已接 | 上游 `dottedBase` 默认 6f，经 `ReaderPageDecorationDrawCache.kt:72 DashPathEffect(dashOn, dashOff)` 画虚线段。本地同名落地：接口 `:163`、默认 `:508`、读 `:622`、写 `:1020`，绘制：`ReaderPage.ets` 的 `resolveUnderlineDashArray()` 第一项经 `vp2px` 写进 `ReaderCanvasStyle.dashIntervals`，由 `drawLineUnderline()` 的 `drawing.PathEffect.createDashPathEffect(dashIntervals, 0)` 落笔 | 设备实测：`dottedLine` 开时，`dottedBase=6` 单行 34 段、`dottedBase=20` 单行 18 段（线段变长则段数变少），可复现 | 见 本机归档 `docs/history/known-issues/reader-config-landed.md` 的 KI-C3（不随公开仓库发布） |
| 自定义虚线间隔比例 | `ReadBookConfig.kt:334` | `ReaderSettingsRepository.ets:164`、`ReaderCanvasSurface.ets`（`drawLineUnderline`） | 已接 | 上游 `dottedRatio` 默认 6f，作 `DashPathEffect` 的 `dashOffPx`。本地同名落地：接口 `:164`、默认 `:509`、读 `:623`、写 `:1021`，绘制：同上，`resolveUnderlineDashArray()` 第二项作 `createDashPathEffect` 的间隔项 | 同上一条的实测：`strokeDashArray([dottedBase, dottedRatio])` 直接决定段数与间隔，改这两项段数即变（34 → 18） | 见 本机归档 `docs/history/known-issues/reader-config-landed.md` 的 KI-C3（不随公开仓库发布） |
| 标题位置模式 | `ReadBookConfig.kt:267` | `ReaderSettingsRepository.ets:255`、`ReaderPage.ets:2163`、`ReaderPage.ets:2200` | 已接 | 上游三值 `titleMode`：0 居左 / 1 居中 / 2 隐藏（`ReadBookConfig.kt:267`）。本地同名落地，`resolveTitleAlign()` 决定对齐、`isReaderTitleVisible()` 决定是否绘制与是否单占标题页；界面 `ReaderSettingsPage.ets:360` 三选一。 | 设「居中显示」后标题居中；设「隐藏标题」后标题整块消失且不再单独占页 | 见 本机归档 `docs/history/known-issues/reader-config-landed.md` 的 KI-C4（不随公开仓库发布） |
| 标题字号 | `ReadBookConfig.kt:269` | `ReaderSettingsRepository.ets:260`、`ReaderPage.ets:2140` | 已接 | 上游 `titleSize` 支持「相对正文偏移」与「绝对 sp」两模式（`ReadBookConfig.kt:669-676`）。本地同名落地，`resolveTitleSizeFp()` 统一解析；原先 9 处硬编码 `this.fontSize + 4` 已全部清除。 | 改标题字号后标题字变大，且章节页数随之重算 | 默认 4 + 相对模式，等价于原「正文 + 4」；见 本机归档 `docs/history/known-issues/reader-config-landed.md` 的 KI-C4（不随公开仓库发布） |
| 标题字号是否相对正文 | `ReadBookConfig.kt:270` | `ReaderSettingsRepository.ets:266`、`ReaderPage.ets:2140` | 已接 | 上游 `titleSizeRelative` 为 `Boolean?`，null 时按旧约定 auto（`titleSize < 8` 视为相对）。本地存 `boolean` 并显式默认 `true`，等价于上游 null + 默认 4 的结果；界面 `ReaderSettingsPage.ets:369` 有「字号相对正文」开关并注明「关闭后按绝对号数显示」。 | 关闭后标题不随正文字号变化 | 上游 null 态用显式默认值等价覆盖；见 本机归档 `docs/history/known-issues/reader-config-landed.md` 的 KI-C4（不随公开仓库发布） |
| 标题上间距 | `ReadBookConfig.kt:298` | `ReaderSettingsRepository.ets:268`、`ReaderPage.ets:2168` | 已接 | 上游 `titleTopSpacing` 默认 0，`LegacyReaderPaginationStyleFactory.kt:98-101` 用 `dpToPx()` 折算。本地同名落地，`resolveTitleTopSpacing()` 出值并进入分页度量。 | 调上间距后标题上方空白变化 | 见 本机归档 `docs/history/known-issues/reader-config-landed.md` 的 KI-C4（不随公开仓库发布） |
| 标题下间距 | `ReadBookConfig.kt:301` | `ReaderSettingsRepository.ets:270`、`ReaderPage.ets:2173` | 已接 | 上游 `titleBottomSpacing` 默认 0；本地原先在两处标题处写死 `.margin({ bottom: 24 })`，已改由本字段承担。 | 调下间距后标题下方空白变化 | 见 本机归档 `docs/history/known-issues/reader-config-landed.md` 的 KI-C4（不随公开仓库发布） |
| 标题日间颜色 | `ReadBookConfig.kt:304` | `ReaderSettingsRepository.ets:276`、`ReaderPage.ets:2157` | 已接 | 上游 `titleColor` 默认 0 表示未设置、回落正文色（`LegacyReaderPaginationStyleFactory.kt:52`）。本地存可选 `#RRGGBB`，空串即「跟随正文」，与上游 0 的语义一一对应；`resolveTitleColor()` 按日夜取值。 | 日间设色后标题变色、正文不变 | 见 本机归档 `docs/history/known-issues/reader-config-landed.md` 的 KI-C4（不随公开仓库发布） |
| 标题夜间颜色 | `ReadBookConfig.kt:307` | `ReaderSettingsRepository.ets:277`、`ReaderPage.ets:2157` | 已接 | 上游 `titleColorNight` 默认 0。本地同名落地，`resolveTitleColor()` 在夜间取该值、空串回落正文色。 | 切夜间后标题取该值 | 设备实测：夜间模式注入 `#FF8C00` 后，标题区橙色像素 6153 个、整页也是 6153 个（正文零橙色）；见 本机归档 `docs/history/known-issues/reader-config-landed.md` 的 KI-C4（不随公开仓库发布） |
| 标题字重 | `ReadBookConfig.kt:228` | `ReaderSettingsRepository.ets:279`、`ReaderPage.ets:2149` | 已接 | 上游 `titleBold` 独立于正文 `textBold`，口径 `resolveWeight()`：1→900、2→300、100..900 原值、其它→400（`LegacyReaderPaginationStyleFactory.kt:113-119`）。本地同名落地并照搬该口径，默认 500 按上游会落到 400。 | 切标题粗体后标题加粗 | 见 本机归档 `docs/history/known-issues/reader-config-landed.md` 的 KI-C4（不随公开仓库发布） |
| 标题行距 | `ReadBookConfig.kt:255` | `ReaderSettingsRepository.ets:281`、`ReaderPage.ets:2182` | 已接 | 上游 `titleLineSpacingExtra` 默认 12，按十分之一行高参与排版（`LegacyReaderPaginationStyleFactory.kt:98-101`）。本地同名落地，`resolveTitleLineSpacingFactor()` 除以 10。 | 调后标题多行时行间变化 | 见 本机归档 `docs/history/known-issues/reader-config-landed.md` 的 KI-C4（不随公开仓库发布） |
| 标题行距子项 | `ReadBookConfig.kt:258` | `ReaderSettingsRepository.ets:283`、`ReaderPage.ets:2182` | 已接 | 上游 `titleLineSpacingSub` 默认 12，只作用于分段后的副标题段。本地同名落地，`resolveTitleLineSpacingFactor(isSubtitle)` 按段落类型分取两值。 | 分段标题的第二段行距变化 | 见 本机归档 `docs/history/known-issues/reader-config-landed.md` 的 KI-C4（不随公开仓库发布） |
| 标题分段模式 | `ReadBookConfig.kt:280` | `ReaderSettingsRepository.ets:285`、`ReaderPage.ets:2188`、`data/ReaderTitleSegmentation.ets` | 已接 | 上游 `titleSegType` 默认 0：0 不分段 / 1 按字数 / 2 按分隔符（逗号分隔多词）/ 3 按正则（`ReaderTitleSegmentation.kt` 全文 44 行）。本地移植同名模块 `ReaderTitleSegmentation.ets`（109 行），`segmentReaderTitle()` 输出分段数组，`resolveTitleSegments()` 供渲染与分页度量共用。 | 设「按字数」并给 4 后长标题拆成两段；改回「不分段」恢复单段 | 设备实测：分段时 dump 出两个独立 Text 节点（「第二章」+「乙」），改回不分段变成单个「第二章 乙」；见 本机归档 `docs/history/known-issues/reader-config-landed.md` 的 KI-C4（不随公开仓库发布） |
| 标题分段缩放 | `ReadBookConfig.kt:283` | `ReaderSettingsRepository.ets:287`、`ReaderPage.ets:2188` | 已接 | 上游 `titleSegScaling` 默认 1f，负值非法回落 1、上限 2（`ReadBookConfig.kt:283-286`）。本地同名落地，`normalizeFraction(…, 1, 2, …)` 照搬该归一规则；界面为「副标题字号比例」滑块（1–2，步长 0.1）。 | 调比例后第二段字号变化 | 见 本机归档 `docs/history/known-issues/reader-config-landed.md` 的 KI-C4（不随公开仓库发布） |
| 标题分段起始位置 | `ReadBookConfig.kt:287` | `ReaderSettingsRepository.ets:289`、`ReaderPage.ets:2188` | 已接 | 上游 `titleSegDistance` 默认 4，type=1 时作为切点字数；越界或非正时不分段。本地同名落地，`splitTitleLine()` 的 type 1 分支同口径。 | 调值后分段切点前移/后移 | 见 本机归档 `docs/history/known-issues/reader-config-landed.md` 的 KI-C4（不随公开仓库发布） |
| 标题分段识别字符 | `ReadBookConfig.kt:290` | `ReaderSettingsRepository.ets:291`、`ReaderPage.ets:2188` | 已接 | 上游 `titleSegFlag` 默认空串：type=2 时按逗号分词再转义成 `a\|b\|c` 的正则，type=3 时整串当正则，都构造零宽后行断言切分，构造失败回落整行。本地 `splitTitleLine()` 与 `escapeRegExp()` 同口径移植。 | 填入字符后在该处拆段 | 正则能力以 ArkTS 支持为限；见 本机归档 `docs/history/known-issues/reader-config-landed.md` 的 KI-C4（不随公开仓库发布） |
| 繁简转换 | `ReadSettings.kt:118` | `ReaderSettingsRepository.ets:222`、`ChineseTextConverter.ets` | 已接 | 上游三档 `chineseConverterType`（0 不转换 / 1 繁转简 / 2 简转繁），正文应用点在 `ContentProcessor.kt:161-171`、标题应用点在 `BookChapter.kt:103-116`。本地存储键 `chineseConverterType`，读 `ReaderSettingsRepository.ets:548`、写 `:885`；转换实现用系统 ICU 的 `i18n.Transliterator`（`Traditional-Simplified` / `Simplified-Traditional`），正文接入 `BookRepository.ets:1653`（净化之后）、标题接入 `ReplaceRuleRepository.ets:954`（替换规则之前）；设置项在排版面板「正文」页 `ReaderSettingsPage.ets:1403`，切换后 `Index.ets:2343` 重读当前章节 | 三档都能切换并落库；选「简体转繁体」后正文与章节标题同时变繁体（`第一卷 风起` → `第一卷 風起`、`这一段是占位正文` → `這一段是佔位正文`），改回「关闭简繁转换」后恢复简体。已实测（docs/VALIDATION.md 2026-10-31 KI-C5 节） | 上游用 `quick-chinese-transfer` 字表并带约 110 条 t2s 排除词，本地用 ICU 转换，个别词形可能有差异 |
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
| 自定义翻页按键 | `ReadSettings.kt:60-61`（`prevKeys`/`nextKeys`，存储键 `prevKeyCodes`/`nextKeyCodes`，见 `PreferKey.kt:48-49`） | `ReaderSettingsRepository.ets:209`/`:211`（接口）、读 `:671-672`、写 `:1091-1092`、归一 `:1241`；消费 `ReaderPage.ets:479` `syncVolumeKeyPage`、`:515` `parsePageKeyCodes`、`:528` `collectPageKeyCodes`、`:508` `isConsumablePageKey`、`:545` `matchPageKey`、`:3869` `onAxisEvent`、`:3878` `onKeyEvent`；面板 `ReaderSettingsPage.ets:1126`、`:1921-1950`；备份 `BackupRepository.ets:859`/`:861`（config.xml 写出）、`:2012-2013`/`:2014-2015`（恢复） | 已接 | 上游 `ReadBookController.kt:3241-3255` 用 `split(",").contains(keyCode.toString())` 判键、`:2699` `onKeyDown` 里自定义键先于内置键，本地 `matchPageKey` 同序。**SDK 限制**：`inputConsumer` 的 `KeyPressedConfig.key` 在 API 20 及以下只放开 `KEYCODE_VOLUME_UP`/`VOLUME_DOWN`，API 21+ 才加媒体三键，故只有这五键能被应用级抢占；其余键值照常保存并随备份同步，按下时靠 ArkUI `onKeyEvent` 冒泡（需窗口持焦点）才生效，与上游「任意键都行」不同，已在面板文案中说明 | 面板「上一页按键」填 `2069` 点「确定」→ 列表副标题变 `上 2069 / 下 —`，偏好文件出现 `<string key="prevKeyCodes">2069</string>`；改回空串后副标题回「未配置」、偏好文件两串为空。按键真正触发翻页未在本模拟器取证（`uitest keyEvent`/`uinput -K` 连可滚动列表都推不动，见 VALIDATION 同日对照实验） | KI-D1 已实现（全文见本机归档 `docs/history/known-issues/reader-config-landed.md` 的 KI-D1，不随公开仓库发布） |
| 选中文字菜单 | `ReadSettings.kt:53` | `ReaderSettingsRepository.ets:226`、`ReaderSettingsPage.ets:1824`（面板分支） | 已接 | 上游 `textSelectMenuConfig` 是 JSON 串 `[{id, enabled, showState}]`，`showState` 0 一级 / 1 折叠 / 2 隐藏（`ReadBookController.kt:3351`）；本地同名存储键，编解码在 `ReaderSelectionMenu.ets`，序列化字段与上游 `SelectionMenuConfigItem` 一一对应，面板的排序 / 分组 / 隐藏点「保存」后整体落库 | 设备实测：把「分享」移入折叠后保存，偏好文件写出 `menu_share_str` 的 `enabled:false,showState:1`；把 `menu_mark` 移入折叠同样写出 `showState:1`；恢复出厂后该键为空串 | 见 本机归档 `docs/history/known-issues/reader-config-landed.md` 的 KI-D2（不随公开仓库发布） |
| 鼠标滚轮翻页 | `ReadSettings.kt:28`（`mouseWheelPage: Boolean = true`） | `ReaderSettingsRepository.ets:213`（接口）、读 `:673`、写 `:1093`；消费 `ReaderPage.ets:3869` 根容器 `onAxisEvent`；面板 `ReaderSettingsPage.ets:1087-1088`；备份 `BackupRepository.ets:863`（config.xml 写出）、`:2016-2017`（恢复） | 已接 | 上游 `ReadBookController.kt:2845` `mouseWheelPage(direction)` 在 `menuLayoutIsVisible` 或开关关闭时直接 return，本地同样先判 `controlsVisible` 与开关；本地额外要求 `pageAnimation !== 3`（滚动模式本来靠滚轮滚动，不该被接管），对齐上游「只在分页模式生效」的语义。阈值 `\|axisVertical\| < 0.5` 过滤触摸板抖动 | 点开关 → 偏好文件 `<bool key="mouseWheelPage" value="false"/>`；再点一次回 `true`。滚轮实际滚动翻页未在本模拟器取证（`uinput -M` 滚轮注入在设置页的 Scroll 列表上也不生效，见 VALIDATION 同日对照实验） | KI-D1 已实现（全文见本机归档 `docs/history/known-issues/reader-config-landed.md` 的 KI-D1，不随公开仓库发布） |
| 朗读时允许音量键翻页 | `ReadSettings.kt:30` | `ReaderSettingsPage.ets:851` | 未接 | 走 `showNotMigrated('朗读时音量键翻页')` | — | 朗读自 2026-11-09 起**已纳入范围、尚未排期**（[PROJECT.md](../PROJECT.md) `:24-44`），开关已上屏故判 `未接`；见 [KNOWN-ISSUES](../KNOWN-ISSUES.md#阅读配置行登记reader-configmd-的未接行) KI-D3 |
| 横屏双页 | `ReadSettings.kt:26` | `ReaderSettingsRepository.ets:228`、`ReaderColumnMode.ets`、`LocalReaderPaginator.ets`、`ReaderPage.ets`、`ReaderSettingsPage.ets:1097` | 已接 | 上游四档 `0/1/2/3` 分别为全局单页、全局双页、横屏双页、平板/横屏双页（`array_values.xml:64` 与 `values-zh-rCN/arrays.xml:42`），判定逻辑在 `ReaderColumnMode.kt` 的 `columnCount()`：`1` 恒双列（含滚动模式）、`2` 仅横屏且非滚动、`3` 横屏或平板且非滚动；列几何照 `ReaderPaginator.kt:86-87`，列宽 = 视口宽 / 列数，每列各自减左右内边距。本地同名落地，存储键 `doubleHorizontalPage`（`PreferKey.kt:157`），读 `:703`、写 `:1132`、归一 `:1295`，判定在 `ReaderColumnMode.ets`，分页换列在 `LocalReaderPaginator.ets` 的 `advanceColumn()`（`lineColumns` 记录每行所属列），渲染按列 `Row` 在 `ReaderPage.ets`，面板四档在 `ReaderSettingsPage.ets:1097`。平板判定本地按短边 ≥ 600vp 近似 Android sw600dp | 把档位设为「全局双页」后阅读页正文分成左右两栏、页码不变；设为「横屏双页」在竖屏下保持单栏。实测：档位 `1` 时正文两栏 bounds `[56,342][584,2591]` 与 `[696,342][1224,2591]`，档位 `0` 时整块铺满 `[112,342][1280,445]…`；档位 `2` 竖屏下为单栏 | 见 本机归档 `docs/history/known-issues/reader-config-landed.md` 的 KI-D4（不随公开仓库发布） |
| 进度条行为 | `ReadSettings.kt:27` | `ReaderSettingsRepository.ets:173` | 已接 | 上游 `progressBarBehavior` → 本地 `progressBehavior`，取值 `page`/`chapter`，面板 `ReaderSettingsPage.ets:847` | 拖动进度条按章节或页码定位 | — |
| 翻页触摸灵敏度 | `ReadSettings.kt:35`（`pageTouchSlop: Int = 0`） | `ReaderSettingsRepository.ets:175` | 已接 | 上游 0 表示用平台默认阈值（`ReaderGestureSettingsPolicy.touchSlopPx`）；本地同口径：`pageTouchSlop > 0` 时取该值，否则回落 36vp。存储键 `pageTouchSlop`，读 `:493`、写 `:816`（夹 0–1000），面板「翻页控制」段的 `MenuSettingSlider`（`ReaderSettingsPage.ets:854-861`，0–1000 步长 10），消费点 `ReaderPage.ets:2947-2948` 的水平 `PanGesture` 阈值 | 把滑块从 0 调到 310 → 横滑 400px（≈141vp）截图 md5 不变、不翻页，滑 1200px（≈424vp）翻页；调回 0（平台默认 36vp）后同样 400px 能翻页。已实测（docs/VALIDATION.md 2026-10-31 KI-D5 节） | 上游把选择拖选阈值刻意与它解耦（`selectionDragSlopPx` 用平台值），本地未联动，保持解耦 |
| 进度条模式 | `ReadSettings.kt:25`（`readSliderMode: String = "0"`） | `ReaderSettingsRepository.ets:174` | 已接 | 上游语义是**显示/不显示**（`ReadBookMenuBarBottom.kt:161` `AnimatedVisibility(visible = readSliderMode != "1")`），选项「常驻」/「不显示」；本地存储键 `readSliderMode`，读 `:492`、写 `:815`，面板「底栏布局」tab 首项 `ReaderSettingsPage.ets:424-430`，消费点 `ReaderPage.ets:3109` 整行进度条外包 `if (this.readSliderMode !== '1')` | 选「不显示」→ 打开阅读菜单，底栏上方那行「上一章 / 滑块 / 下一章」消失，底部图标行仍在；选「常驻」→ 该行恢复。落库已实测：选「不显示」后偏好文件出现 `readSliderMode` = `1`，改回「常驻」回到 `0`（docs/VALIDATION.md 2026-10-31 KI-D5 节） | 顺带纠正了历史错位：该位置原本挂的是本地 `progressBehavior`（页码/章节），与上游 `readSliderMode` 语义不同，现分别由「滑动条显示样式」和「进度条行为」两项承担 |
| 允许选择正文 | `ReadSettings.kt:46` | `ReaderSettingsRepository.ets:195` | 已接 | 开关在 `ReaderSettingsPage.ets:874`，阅读页 `ReaderPage.ets:169` 消费 | 长按正文出现选择菜单 | — |
| 展开文字菜单 | `ReadSettings.kt:51` | `ReaderSettingsRepository.ets:218`、`ReaderSettingsPage.ets:1829`、`ReaderPage.ets:2470` | 已接 | 上游默认 false（`ReadSettings.kt:51`），`TextActionSelectionMenu.kt:166` 为真时一级 + 折叠项一起平铺（`MultiLineMenuView`），为假时一行 + 「更多」弹层。本地同名存储键；为真时 `Flex` 换成 `Wrap` 平铺，为假时折叠项收在「更多」里就地展开（本地没有 Popup 层，语义等价） | 设备实测：偏好文件出现 `<bool key="expandTextMenu" value="false"/>`；面板开关可直接切换 | 见 本机归档 `docs/history/known-issues/reader-config-landed.md` 的 KI-D2（不随公开仓库发布） |
| 显示选择菜单图标 | `ReadSettings.kt:52` | `ReaderSettingsRepository.ets:220`、`ReaderSettingsPage.ets:1834`、`ReaderPage.ets:2473` | 已接 | 上游默认 true（`ReadSettings.kt:52`），`TextActionSelectionMenu.kt:181`/`:227`/`:294` 三处传 `showIcons = showSelectMenuIcon`。本地同名存储键，控制条目图标以及图标与文字的间距，关闭时只剩文字 | 设备实测：偏好文件出现 `<bool key="showSelectMenuIcon" value="true"/>`；面板开关可直接切换 | 见 本机归档 `docs/history/known-issues/reader-config-landed.md` 的 KI-D2（不随公开仓库发布） |
| 上次标记样式 | `ReadSettings.kt:54`（`lastMarkingStyle: String = ""`） | `ReaderSettingsRepository.ets:181` | 已接 | 上游在 `ReadBookViewModel.kt:1519` 把 `TextProcessStyle` 的 JSON 存进该键，消费点 `MarkingSelectionMenu.kt:166` 取 `state.editing?.styleJson ?: lastMarkingStyle`（编辑已有标记优先用标记自身样式，新建才沿用上次）。本地同口径：存储键 `lastMarkingStyle`，读 `:501`、写 `:826`；写点 `Index.ets` 的 `saveReaderMarking()` 在标记保存成功后调 `setReaderLastMarkingStyle(ReaderMarkingRepository.encodeStyle(effect, color))`；消费点 `ReaderMarkingEditor.ets:222` 的 `@Prop lastMarkingStyle` + `:255-264 applyLastMarkingStyle()`（仅 `isNew` 且非空时应用）。JSON 形态复用 `ReaderMarkingRepository.encodeStyle`/`decodeStyle`，与标记自身的 styleJson 共用同一份转换 | 新建一条划线并选「波浪 + 红色」保存 → 再新建另一条，面板打开时效果已预选「波浪」、颜色已预选红色；编辑已有标记时不预选（保留该标记自身样式） | 顺带纠正历史错位：`ReaderMarkingEditor` 的 `useRule` 原默认 `true`，与上游 `MarkingSelectionMenu.kt:181` 的 `mutableStateOf(false)` 相反，已改为 `false`，只在 `loadHighlightRules()` 后按样式匹配到规则时才置 `true`。备份口径：`BackupConfig.kt` 的 `readPrefKeys` 忽略清单不含该键，故随 `config.xml` 无条件导出，已补导出 `BackupRepository.ets:918` / 恢复 `:2167-2168` |

## E 菜单与主题外观

上游主体：`ReadBookConfig.kt:77-131`（`readMenu*` 系列 getter）、`Config` 内的 `@Transient menu*` 字段（`:643-658`）。
本地主体：`ReaderSettingsPage.ets:399-462`（`menuSettingsContent()`）、条目清单 `:1788-1840`。

**本块共同差异**：42 个条目里 **4 个未接的已全部由 KI-E6 处理完**：其中 3 条（菜单镜头半径、阅读栏样式、阅读栏样式跟随页面）上游本身就**没有设置入口**，本地只落库不上屏；剩下 1 条（更多操作配置）本来就有完整的运行时实现（`ReaderMoreActionsRepository`），本轮补的是它在 `ReaderSettingsRepository` 里的备份投影。**E 块至此 42 条全部为 `已接`，没有 `未接` 行。** 已接的 42 条分八类：2 条完整持久化链路（底栏按钮配置、标题栏操作按钮）；3 条是 KI-A9 接上的亮度侧字段（显示亮度视图、亮度条位置、自动亮度）；7 条是 KI-E4 接上的底栏外观七行（含本地新增的一条「底栏模糊样式」入口，故 7 行对应上游 6 个字段）；8 条是 KI-E5 接上的标题栏形态八行（标题栏胶囊、标题栏模式、标题栏紧凑、标题栏图标样式、顶栏模糊、顶栏模糊样式、顶栏液态玻璃按钮、合并标题栏按钮）；7 条是 KI-E1 接上的配色七行（工具栏样式、调色板风格、菜单颜色来源、种子色、菜单背景颜色、菜单容器颜色、菜单强调颜色）；7 条是 KI-E2 接上的边框与模糊七行（菜单栏边框、菜单栏边框宽度、菜单栏边框颜色、菜单模糊半径、菜单模糊透明度、菜单文字颜色、菜单模糊颜色）；4 条是 KI-E3 接上的浮动图标四项（显示标题栏图标、标题栏悬浮图标配置、标题栏悬浮图标位置、悬浮图标液态玻璃按钮），4 条是 KI-E6 接上的无上屏四项（菜单镜头半径、阅读栏样式、阅读栏样式跟随页面、更多操作配置，其中阅读栏样式实际由 KI-E1 一并落库）。

| 上游能力 | 上游位置 | 本地位置 | 状态 | 差异说明 | 验收方式 | 备注 |
| --- | --- | --- | --- | --- | --- | --- |
| 工具栏样式 | `ReadBookConfig.kt:99` | `ReaderSettingsPage.ets:2518` | 已接 | 上游 `readBarStyle: Int = 1`（`ReadSettings.kt:69`）三值 0 跟随系统 / 1 跟随阅读背景 / 2 自定义（`SystemMenuPage.kt:262-275`），在 `BackupConfig.readPrefKeys` 忽略清单内（`:216`）不随备份导出；「跟随系统」由 `ReadBookColorTheme.kt:52-63` 的 `else -> null` 退回 Material 默认色板。本地存 `ReaderSettingsRepository.ets:372`（默认 1，夹 0–2）、读 `:928`、写 `:1453`；面板 `ReaderSettingsPage.ets:2518` 条目游 `:1028 getMenuSelectedIndex` 读真值，段落下拉 `:886` 立即落库 | 把「工具栏样式」切「自定义」后列表立刻多出「菜单颜色来源」与三个颜色项；`aa force-stop` 重启后仍显示「自定义」；prefs `readBarStyle` 为 `2.000000` | 见 本机归档 `docs/history/known-issues/reader-config-landed.md` 的 KI-E1（不随公开仓库发布） |
| 调色板风格 | `ReadBookConfig.kt:113` | `ReaderSettingsPage.ets:2519` | 已接 | 上游 `readMenuPaletteStyle: String = ""`（`ReadSettings.kt:109`），空串即「跟随系统」，非空取 `paletteStyle_value` 九项之一（`values/array_values.xml:101-111`），下拉首项固定拼「跟随系统」+ 空值（`SystemMenuPage.kt:277-291`）；可见性 `showPaletteStyle = bottomMode == 1 \|\| (bottomMode == 2 && colorMode == 0)`（`:276`），在忽略清单内（`:247`）不导出。本地存 `ReaderSettingsRepository.ets:377`（`normalizePaletteStyle` 只认九值或空串，`:1610`）、读 `:929`、写 `:1454`；面板十项下拉 `ReaderSettingsPage.ets:2519`→`getMenuSelectedIndex :1030`→`MENU_PALETTE_VALUES :30` | 「工具栏样式」为「跟随阅读背景」或「自定义+种子色」时该项出现；选「鲜艳」后副标题变「鲜艳」，`aa force-stop` 重启后仍是「鲜艳」 | 见 本机归档 `docs/history/known-issues/reader-config-landed.md` 的 KI-E1（不随公开仓库发布） |
| 菜单颜色来源 | `ReadBookConfig.kt:99` | `ReaderSettingsPage.ets:2520` | 已接 | 上游 `readMenuColorMode: Int = 1`（`ReadSettings.kt:88`）两值 0 种子色 / 1 自定义颜色（`SystemMenuPage.kt:293-307` 的 `read_menu_color_source`，中文串 `strings.xml:2462` 与 `:42 custom_theme_colors`「自定义颜色」），`ReadBookConfig.kt:99` 夹 0–1，在忽略清单内（`:227`）；落地侧 `ReadBookColorTheme.kt:144-162`（种子色只把 accentColor 当 seed，自定义走 `withCustomReadMenuColors :286-298`）。本地存 `ReaderSettingsRepository.ets:379`（默认 1，夹 0–1）、读 `:930`、写 `:1456`；面板 `ReaderSettingsPage.ets:2520` | 切「种子色」后三个自定义颜色项消失、「种子色」出现；切回「自定义颜色」后又出现三项；`aa force-stop` 重启后仍是「自定义颜色」 | 见 本机归档 `docs/history/known-issues/reader-config-landed.md` 的 KI-E1（不随公开仓库发布） |
| 种子色 | `ReadBookConfig.kt:62` | `ReaderSettingsPage.ets:2521` | 已接 | 上游「种子色」与「菜单强调颜色」**共用同一对字段** `readMenuAccentColor` / `readMenuAccentColorNight`（`SystemMenuPage.kt:309-320` 与 `:349-368` 都传 `dayMenuAccentColor`/`nightMenuAccentColor`），只在 `bottomMode == 2 && colorMode == 0` 时出现（`:293`+`:309`）；0 表示未设置、生成色板时回落主题 accent（`ReadBookConfig.kt:120-122`）。本地存 `ReaderSettingsRepository.ets:392`/`:394`（两个 string，空串 = 未设置）、读 `:936`/`:937`、写 `:1464`/`:1466`；面板 `ReaderSettingsPage.ets:2521`，点击开配色弹层 `:1877-1905`（日/夜两块 `MenuSettingPalette` + `MENU_COLOR_PALETTE :33`），写回走 `applyMenuColor :978` | 点「种子色」→ 弹层出现「种子色（日间）」「种子色（夜间）」两块色板；点某色后标题行右侧显示该色号；再点同色可清除；选中的色号在 `aa force-stop` 重启后仍在；打开「菜单强调颜色」显示同一色号（共用字段） | 见 本机归档 `docs/history/known-issues/reader-config-landed.md` 的 KI-E1（不随公开仓库发布） |
| 菜单背景颜色 | `ReadBookConfig.kt:117` | `ReaderSettingsPage.ets:2522` | 已接 | 上游 `readMenuBgColor: Int = 0` / `readMenuBgColorNight: Int = 0`（`ReadSettings.kt:80`/`:83`），0 表示未设置、回落当前阅读背景（`ReadBookConfig.kt:154-178` 的 `resolvedMenuBgColor`：`readBarStyle == 1` 取阅读背景、`== 2` 取本字段、`else` 日夜黑白）；中文串 `strings.xml:2459 read_menu_bg_color_summary`「阅读顶栏和底栏背景色」；只在 `bottomMode == 2 && colorMode == 1` 时出现；在忽略清单内（`:219`/`:222`）。本地存 `ReaderSettingsRepository.ets:384`/`:386`、读 `:931`/`:932`、写 `:1457`/`:1458`；面板 `ReaderSettingsPage.ets:2522`，配色弹层 `:1877-1905` | 「自定义 + 自定义颜色」时该项出现；选色后条目两个色点变为所选色；`aa force-stop` 重启后色点仍是该色；再点同色清除、色点回占位灰 | 见 本机归档 `docs/history/known-issues/reader-config-landed.md` 的 KI-E1（不随公开仓库发布） |
| 菜单容器颜色 | `ReadBookConfig.kt:123` | `ReaderSettingsPage.ets:2523` | 已接 | 上游 `readMenuContainerColor: Int = 0` / `Night`（`ReadSettings.kt:82`/`:85`），0 表示未设置、回落菜单背景色（`ReadBookConfig.kt:117-132`）；中文串 `strings.xml:2464 read_menu_container_color_summary`「用于生成阅读菜单色板的基础表面色」；只在 `bottomMode == 2 && colorMode == 1` 时出现；在忽略清单内（`:221`/`:224`）。本地存 `ReaderSettingsRepository.ets:388`/`:390`、读 `:933`/`:934`、写 `:1460`/`:1462`；面板 `ReaderSettingsPage.ets:2523` | 同「菜单背景颜色」的走法；本项单独选色后不影响背景色项（两个独立字段） | 见 本机归档 `docs/history/known-issues/reader-config-landed.md` 的 KI-E1（不随公开仓库发布） |
| 菜单强调颜色 | `ReadBookConfig.kt:120` | `ReaderSettingsPage.ets:2524` | 已接 | 上游 `readMenuAccentColor: Int = 0` / `Night`（`ReadSettings.kt:81`/`:84`），与「种子色」共用同一对字段，`ReadBookConfig.kt:64 val menuColor get() = readMenuAccentColor`；0 表示未设置；中文串 `strings.xml:2465 read_menu_accent_color_summary`「阅读顶栏和底栏文字与图标颜色」；只在 `bottomMode == 2 && colorMode == 1` 时出现；在忽略清单内（`:220`/`:223`）。本地存 `ReaderSettingsRepository.ets:392`/`:394`、读 `:936`/`:937`、写 `:1464`/`:1466`；面板 `ReaderSettingsPage.ets:2524` | 在「种子色」里选 `#31282A` 后打开本项，弹层显示同一个 `#31282A`（共用字段的直接证据） | 见 本机归档 `docs/history/known-issues/reader-config-landed.md` 的 KI-E1（不随公开仓库发布） |
| 显示亮度视图 | `ReadBookConfig.kt:94` | `ReaderSettingsPage.ets:2239` | 已接 | 上游 `showBrightnessView: String = "0"` 三值（`ReadSettings.kt:20`），存储键 `readBrightnessMode`（`PreferKey.kt:112`），在 `BackupConfig.readPrefKeys` 忽略清单内、不随备份导出；消费 `ReadBookMenuBarBottom.kt:139-163`（`== "1"` 底栏横排）、`ReadBookMenuBar.kt:250-268`（顶栏竖排）。本地 `ReaderSettingsRepository.ets:249`/读 `:734`/写 `:1175`，`ReaderSettingsPage.ets:2239` 三段控件回显 `getBrightnessViewDetail()`，`ReaderPage.ets:3805` 按 `'1'`/`'2'` 挂亮度条 | 切「竖排」后列表副标题变「竖排」，`readBrightnessMode` 落库为 `2` | 见 本机归档 `docs/history/known-issues/reader-config-landed.md` 的 KI-E1（不随公开仓库发布） |
| 亮度条位置 | `ReadBookConfig.kt:95` | `ReaderSettingsPage.ets:2240` | 已接 | 上游 `brightnessVwPos: String = "1"`（`ReadSettings.kt:21`），存储键 `readBrightnessControlPosition`（`PreferKey.kt:193`），同样在忽略清单内不导出；`ReadBookMenuBar.kt:250-268` 的 `onTogglePosition` 在 `"0"`/`"1"` 间切换。本地 `ReaderSettingsRepository.ets:254`/读 `:735`/写 `:1176`，`ReaderSettingsPage.ets:2240` 回显 `getBrightnessPositionDetail()`，且该项**只在「显示亮度视图」为「竖排」时可见**（`ReaderSettingsPage.ets:926`，对齐上游 `brightnessVwPos == "2"` 的条件） | 切「竖排」后「亮度条位置」出现；点「左侧」后 `readBrightnessControlPosition` 落库为 `0`，返回列表副标题变「左侧」 | 见 本机归档 `docs/history/known-issues/reader-config-landed.md` 的 KI-E1（不随公开仓库发布） |
| 菜单栏边框 | `ReadBookConfig.kt:88` | `ReaderSettingsPage.ets:2590` | 已接 | 上游**没有独立布尔字段**：开关本体就是 `readMenuBorderWidth > 0`（`SystemMenuPage.kt:398` 的 `val borderEnabled = preferences.readMenuBorderWidth > 0`），`TinySwitchSettingItem(read_menu_border)` 的 `checked = borderEnabled`、写回 `ConfigUpdate.BorderWidth(if (it) 1 else 0)`（`:399-406`）；`AnimatedVisibility(visible = borderEnabled)` 包住宽度与颜色两项（`:408`）；`readMenuBorderWidth` 夹 0–4（`ReadBookConfig.kt:115`），默认 1（`ReadSettings.kt:111`），在忽略清单内（`BackupConfig.kt:249`）。本地存 `ReaderSettingsRepository.ets:396`（默认 1、夹 0–4）、读 `:964`、写 `:1512`；面板 `ReaderSettingsPage.ets:2590` 的 Toggle 读写同一字段；渲染 `ReaderPage.ets:1067 readerMenuBorderSettings()` → 顶栏 `:4272`、底栏 `:4379` 的 `.border(...)` | 关掉「菜单栏边框」后「菜单栏边框宽度」「菜单栏边框颜色」两行整行消失、下方各项上移约 98 px；重新打开后恢复（实测两方向）；边框宽度拖到 4 后 `aa force-stop` 重启仍是 4、关掉开关后重启仍是关 | 见 本机归档 `docs/history/known-issues/reader-config-landed.md` 的 KI-E2（不随公开仓库发布） |
| 菜单栏边框宽度 | `ReadBookConfig.kt:115` | `ReaderSettingsPage.ets:2591` | 已接 | 上游 `readMenuBorderWidth get() = readSettings.readMenuBorderWidth.coerceIn(0, 4)`（`ReadBookConfig.kt:115`），默认 1（`ReadSettings.kt:111`）；滑块 `TinySliderSettingItem(read_menu_border_width)` 的 `value = preferences.readMenuBorderWidth.coerceIn(1, 4)`、`valueRange = 1f..4f`、→ `ConfigUpdate.BorderWidth(it.toInt())`（`SystemMenuPage.kt:411-425`）；在忽略清单内（`BackupConfig.kt:249`）不导出。本地存 `ReaderSettingsRepository.ets:396`、读 `:964`、写 `:1512`（`Math.max(0, Math.min(4, Math.round(...)))`）；面板滑块 `ReaderSettingsPage.ets:2591` → `onReadMenuBorderWidthChange` → `menuSliderValue/menuSliderMaximum/menuSliderMinimum`；渲染同「菜单栏边框」的 `.border(...)` | 拖到 `4.000000` 后 `aa force-stop` 重启仍是 `4.000000`；点 `click 60 1497` 回到 `1.000000` | 见 本机归档 `docs/history/known-issues/reader-config-landed.md` 的 KI-E2（不随公开仓库发布） |
| 菜单栏边框颜色 | `ReadBookConfig.kt:88-89` | `ReaderSettingsPage.ets:2592` | 已接 | 上游 `readMenuBorderColor: Int = 0` / `readMenuBorderColorNight: Int = 0`（`ReadSettings.kt:112`/`:113`），0 表示未设置、回落 `outlineVariant`（`ReadBookMenuBarShared.kt:96-105`），日夜取值走 `resolvedMenuBorderColor`（`ReadBookConfig.kt:187`）；`TinyClearColorModeSettingItem(read_menu_border_color)` 支持清除（清空写 `BorderColor(0)`/`BorderColorNight(0)`，`SystemMenuPage.kt:426-437`）；在忽略清单内（`:250`/`:251`）。本地存 `ReaderSettingsRepository.ets:398`/`:400`（两个 string，空串 = 未设置）、读 `:965`/`:966`、写 `:1513` 起；面板 `ReaderSettingsPage.ets:2592` 的 `MenuSettingColor` 双色点 → 配色弹层 `:1877-1905` → `applyMenuColor`；渲染 `readerMenuBorderSettings()` 的颜色分支（空串回落 `readerMenuForegroundAlpha('73')`） | 点条目开弹层（日间/夜间两块色板各 8 个圆点）；选 `#3D3D46` 后标题行右侧显示该色号、`aa force-stop` 重启仍显示；再点同色清除、色号消失 | 见 本机归档 `docs/history/known-issues/reader-config-landed.md` 的 KI-E2（不随公开仓库发布） |
| 菜单模糊半径 | `ReadBookConfig.kt:109` | `ReaderSettingsPage.ets:2594` | 已接 | 上游 `readMenuBlurRadius get() = … .coerceIn(0, 32)`（`ReadBookConfig.kt:109`），默认 24（`ReadSettings.kt:105`）；滑块 `TinySliderSettingItem(read_menu_blur_radius)` `valueRange = 0f..32f` `steps = 31` → `ConfigUpdate.MenuBlurRadius(it.toInt())`，`description = read_menu_blur_radius_summary`「模糊半径越大，系统运行越卡顿」（`SystemMenuPage.kt:438-447`）；消费 `ReadBookMenuBarTitle.kt:131`、`ReadBookMenuBar.kt:1027`、`ReadBookMenuBarShared.kt:49-85`；在忽略清单内（`:243`）。本地存 `ReaderSettingsRepository.ets:402`（默认 24、夹 0–32）、读 `:968`、写 `:1512` 起；面板 `ReaderSettingsPage.ets:2594` → `onReadMenuBlurRadiusChange`；渲染 `ReaderPage.ets:1080 readerMenuBlurRadiusVp()` → 顶栏 `:4273`、底栏 `:4380` 的 `.backdropBlur(...)` | 拖到 `32.000000` 后 `aa force-stop` 重启仍是 `32.000000`；复原 `click 939 2064` → 25、再 `swipe 1200 2064 920 2064 500` → `24.000000` | 见 本机归档 `docs/history/known-issues/reader-config-landed.md` 的 KI-E2（不随公开仓库发布） |
| 菜单模糊透明度 | `ReadBookConfig.kt:110` | `ReaderSettingsPage.ets:2595` | 已接 | 上游 `readMenuBlurAlpha get() = … .coerceIn(0, 100)`（`ReadBookConfig.kt:110`），默认 85（`ReadSettings.kt:106`）；滑块 `TinySliderSettingItem(read_menu_blur_alpha)` `valueRange = 0f..100f` `steps = 99` → `ConfigUpdate.MenuBlurAlpha(it.toInt())`（`SystemMenuPage.kt:448-456`）；**该字段在「菜单栏」与「底栏布局」两个 tab 各出现一次，上游共用一个键**；在忽略清单内（`:244`）。**字段本身由 KI-E4 落库**（`ReaderSettingsRepository.ets:411`），KI-E2 补的只是「菜单栏」tab 这处入口的接线：面板 `ReaderSettingsPage.ets:2595` → `onReadMenuBlurAlphaChange`、`menuSliderValue` 返回 `readMenuBlurAlpha`；渲染 `readMenuBlurAlpha` 参与 `readerMenuTintAlphaString`（`ReaderPage.ets:1041`，上限 0.6） | 拖动后读数变化（实测 `click 520 2341` → `39.000000`）；复原 `swipe 1200 2341 1008 2341 1500` → `85.000000`，`aa force-stop` 重启仍是 85 | 见 本机归档 `docs/history/known-issues/reader-config-landed.md` 的 KI-E2（不随公开仓库发布） |
| 菜单文字颜色 | `ReadBookConfig.kt:90-91` | `ReaderSettingsPage.ets:2596` | 已接 | 上游 `readMenuTextColor: Int = 0` / `readMenuTextColorNight: Int = 0`（`ReadSettings.kt:86`/`:87`），0 表示未设置、回落 `onSurface`（`ReadBookMenuBarShared.kt:107-115`），日夜取值走 `resolvedMenuTextColor`（`ReadBookConfig.kt:190`）；`TinyClearColorModeSettingItem(read_menu_text_color)` 支持清除（`SystemMenuPage.kt:457-475`）；在忽略清单内（`:225`/`:226`）。本地存 `ReaderSettingsRepository.ets:404`/`:406`、读 `:969`/`:970`、写 `:1513` 起；面板 `ReaderSettingsPage.ets:2596` → 配色弹层 → `applyMenuColor`；渲染 `ReaderPage.ets:1023 readerMenuForeground()` 优先取这两项、空串才回落日夜反色（`#D5C2C6`/`#3E3D3B`） | 点条目开弹层；选 `#000000` 后显示；再点同色清除（实测通过） | 见 本机归档 `docs/history/known-issues/reader-config-landed.md` 的 KI-E2（不随公开仓库发布） |
| 菜单模糊颜色 | `ReadBookConfig.kt:111-112` | `ReaderSettingsPage.ets:2597` | 已接 | 上游 `readMenuBlurColor: Int = 0` / `readMenuBlurColorNight: Int = 0`（`ReadSettings.kt:107`/`:108`），0 表示未设置；**与其余颜色项不同，这一项没有 `onClearColor`（不能清除）**（`SystemMenuPage.kt:476-489` 的 `TinyColorModeSettingItem` 只给 `onClickColor`，弹 `COLOR_BLUR_TINT`/`COLOR_BLUR_TINT_NIGHT`）；消费 `ReadBookMenuBarShared.kt:76-92 readMenuTintColor()` —— **模糊着色优先于整套底色推导**（`:49-85` 的 `surfaceColor = readMenuTintColor(menuConfig) ?: colors.background`）；在忽略清单内（`:245`/`:246`）。本地存 `ReaderSettingsRepository.ets:408`/`:410`、读 `:972`/`:973`、写 `:1513` 起；渲染 `ReaderPage.ets:1043 readerMenuTintColor()`，并在 `readerMenuBaseColor()` 开头优先返回（`:1008`） | 需先滚到该项（`[42,1903]`）并点文字本身；开弹层后选 `#3D3D46` 显示、再点同色清除（实测通过） | 见 本机归档 `docs/history/known-issues/reader-config-landed.md` 的 KI-E2（不随公开仓库发布） |
| 显示标题栏图标 | `ReadBookConfig.kt:92` | `ReaderSettingsPage.ets:2639` | 已接 | 上游 `showTitleBarIcons: Boolean = false`（`ReadSettings.kt:117`，`PreferKey.kt:416`），开关 `TinySwitchSettingItem(show_title_bar_icons)` → `ConfigUpdate.ShowTitleBarIcons(it)`（`SystemMenuPage.kt:491-497`），它包住的三项被 `AnimatedVisibility(visible = preferences.showTitleBarIcons)` 控制（`:498` 起）；渲染消费 `ReadBookMenuBar.kt:172`（位置 0/1 在顶栏区）与 `:310-330`（位置 2/3 在菜单浮层区）。本地存 `ReaderSettingsRepository.ets:412`（默认 false）、默认值 `:828`、读 `:1002`、归一 `:1344`、写 `:1573`；面板 `ReaderSettingsPage.ets:2639` 的 Toggle 读写该字段，可见性 `:1247` 读同一字段；渲染 `ReaderPage.ets:1979 readerFloatingIconTopVisible()` / `:1984 readerFloatingIconBottomVisible()`，挂载 `:4371`（顶栏区）与 `:4388`（菜单浮层区） | 关掉「显示标题栏图标」后，「标题栏悬浮图标配置」「标题栏悬浮图标位置」「悬浮图标液态玻璃按钮」三项整行消失（实测三项计数全为 0），重新打开后三项恢复；`aa force-stop` 重启后开关仍为开 | 备份口径：`showTitleBarIcons` 在 `BackupConfig.kt:257` 的 `readPrefKeys` 忽略清单里，不随 `config.xml` 导出，恢复只取本机现值；见 本机归档 `docs/history/known-issues/reader-config-landed.md` 的 KI-E3（不随公开仓库发布） |
| 标题栏悬浮图标配置 | `ReadBookConfig.kt:146`、`:149` | `ReaderSettingsPage.ets:2640` | 已接 | 上游两个 Map 字段 `readMenuCustomIcons`（`ReadSettings.kt:114`）与 `titleBarCustomIcons`（`:115`），`ReadBookConfig.kt:146-150` 用 `parseReadMenuCustomIcons` 解析成 `Map<String,String>`；入口 `TinyClickableSettingItem(title_bar_icons)` → `ShowSheet(FloatingBarIconConfig)`（`SystemMenuPage.kt:501-508`），副标题按 `customIconCount == 0` 取「使用默认图标」/「已自定义 %1$d 个图标」（`strings.xml:2476`/`:2477`）；配置面板 `FloatingBarIconConfigSheet.kt:25-46` 复用 `ButtonIconConfigSheet`，**图标池与「标题栏操作按钮」同池**（`ReadButtonConfigDelegate.kt:36` 的 `TITLE_BAR_ICON_PREFS`/`TITLE_BAR_ICON_KEY`，`:204-205`），渲染 `ReadBookMenuBarFloating.kt:399-425 loadFloatingIcons()`。本地存 `ReaderSettingsRepository.ets:424`（`floatingIcons`，默认池取 `READER_LOCAL_BOTTOM_ACTION_DEFAULTS`，对齐上游 `DEFAULT_ENABLED_BUTTON_IDS` = search/auto_page/catalog/read_aloud/setting）、`:426`/`:428` 两个自定义图标串；编码归一 `:1778 normalizeCustomIconMap`、解码 `:1797 decodeCustomIconMap`（`id,path;` 形式，只保留合法 id 与非空路径）；面板 `ReaderSettingsPage.ets:2640` 点击走 `:978-985` 把 `floatingIcons` 拷进 `draftTopActions` 并置 `floatingIconConfigVisible`，复用 `topActionConfigurationSheet()`（`:2852` 标题在「浮动图标」与「顶栏按钮配置」间切换、`:2861-2864` 保存按标志分流）；渲染 `ReaderPage.ets:1989 readerFloatingIconCustomUri()` 自定义图标走 `Image(...)` 圆形裁剪、否则 `ReaderControlGlyph` | 打开「显示标题栏图标」后点「标题栏悬浮图标配置」→ 面板标题为「浮动图标」，列表是顶栏按钮池（更多操作 / 全文搜索 / 自动翻页 / 目录 / 朗读 / 护眼模式 / 设置等）；关掉「自动翻页」并保存后，prefs `floatingIcons` 中 `autoPage` 由 `true` 变 `false`，`aa force-stop` 重启后仍为 `false`；复原后回到 `true` | 备份口径：`readMenuCustomIcons`/`titleBarCustomIcons` 在 `BackupConfig.kt:252`/`:255` 忽略清单里，不导出。已知差异：本地**没有实现换自定义图标图片**（`titleBarCustomIcons`/`readMenuCustomIcons` 已落库、渲染侧已能解码并显示，但配置面板里没有选图入口，上游走 `OpenTitleBarCustomIconPicker`）；见 本机归档 `docs/history/known-issues/reader-config-landed.md` 的 KI-E3（不随公开仓库发布） |
| 标题栏悬浮图标位置 | `ReadBookConfig.kt:116` | `ReaderSettingsPage.ets:2641` | 已接 | 上游 `titleBarIconPosition: Int = 3`（`ReadSettings.kt:116`），`ReadBookConfig.kt:116` 夹 0–3；下拉 `TinyDropdownSettingItem(title_bar_icon_position)`，`entryValues = ["0","1","2","3"]`（`SystemMenuPage.kt:509-520`），中文串「左上 / 右上 / 左下 / 右下」（`strings.xml:2486-2489`）；渲染分两处：0/1 挂顶栏区、2/3 挂菜单浮层区（`ReadBookMenuBar.kt:172`、`:310-330`），对齐用 `Alignment.Start`/`End`。本地存 `ReaderSettingsRepository.ets:417`（默认 3）、默认值 `:829`、读 `:1003`、归一 `:1347`（夹 0–3）、写 `:1574`；面板 `ReaderSettingsPage.ets:2641` 四值下拉（`getMenuChoices :1106` 与 `getDetailChoices :1849` 两处都返回「左上/右上/左下/右下」），选中态 `:1123`、段落 `onSelect :947`、弹层 `applyDetailChoicePreview :1173` 三处都落库；渲染 `ReaderPage.ets:1974 readerFloatingIconAlignment()`（0/2 → Start、1/3 → End） | 打开「显示标题栏图标」后该项显示「右下」；点开下拉可见四项「左上 / 右上 / 左下 / 右下」；选「左上」后条目摘要变「左上」，`aa force-stop` 重启后仍是「左上」（prefs `titleBarIconPosition` 为 `0.000000`）；复原选回「右下」（`3.000000`） | 备份口径：`titleBarIconPosition` 在 `BackupConfig.kt:256` 忽略清单里，不导出。**本轮修掉的真 bug**：弹层分支原先只写进段落 `onSelect`，`applyDetailChoicePreview` 缺这一支，导致点弹层选项不落库；已补 `:1173`。见 本机归档 `docs/history/known-issues/reader-config-landed.md` 的 KI-E3（不随公开仓库发布） |
| 悬浮图标液态玻璃按钮 | `ReadBookConfig.kt:87` | `ReaderSettingsPage.ets:2642` | 已接 | 上游 `readMenuFloatingIconLiquidGlass: Boolean = false`（`ReadSettings.kt:102`，`PreferKey.kt:401`），开关 `TinySwitchSettingItem(read_menu_bar_liquid_glass_buttons)` → `ConfigUpdate.MenuFloatingIconLiquidGlass(it)`（`SystemMenuPage.kt:521-527`）——**注意与底栏同名串但字段不同**；渲染 `ReadBookMenuBarFloating.kt:63-150` 的 `glassEnabled = !isCustom && readMenuFloatingIconLiquidGlass && readerMenuLiquidGlassAvailable(backdrop)`。本地存 `ReaderSettingsRepository.ets:419`（默认 false）、默认值 `:830`、读 `:1004`、归一 `:1348`、写 `:1576`；面板 `ReaderSettingsPage.ets:2642` 的 Toggle（名单 `:998`、checked `:866-868`、onChange `:895`）；渲染 `ReaderPage.ets:2002 readerFloatingIconButton()` 的底色 `this.readMenuFloatingIconLiquidGlass ? this.readerMenuForegroundAlpha('1F') : '#00000000'` | 开关可拨动；打开后 prefs `readMenuFloatingIconLiquidGlass` 为 `true`，`aa force-stop` 重启后仍为 `true`；复原后为 `false` | 备份口径：`readMenuFloatingIconLiquidGlass` 在 `BackupConfig.kt:240` 忽略清单里，不导出。已知差异：ArkUI 无 `backdropBlur` 之外的液态玻璃材质，本地用「半透明前景色底」近似，**玻璃质感本身未做像素级取证**。**本轮修掉的真 bug**：该条目原先不在 `isMenuToggle` 名单里，被渲染成「尚未迁移」的普通条目、Toggle 根本不存在；已补进名单。见 本机归档 `docs/history/known-issues/reader-config-landed.md` 的 KI-E3（不随公开仓库发布） |
| 底栏按钮配置 | `ReadSettings.kt` | `ReaderSettingsRepository.ets:171-172` | 已接 | 链路完整：`ReaderSettingsPage.ets:470-472` 分流 → `handleMenuSettingsEntryClick()`（`:517-531`）→ `bottomActionConfigurationSheet()`（`:1897-1956`，显示开关 `:1936`、上下移 `:1938-1944`）→ `onBottomActionsChange` → `Index.ets:2218` → 写 `bottomActions`（`ReaderSettingsRepository.ets:804`） | 改显示与顺序后退出设置页，重进仍生效，阅读页底栏同步变化 | 只做显示/排序，未做长按动作自定义 |
| 底栏圆角 | `ReadBookConfig.kt:104`（`readMenuBottomCornerRadius: Int = 32`） | `ReaderSettingsRepository.ets:290`、`ReaderSettingsPage.ets:211`/`:2357`、`ReaderPage.ets:236`/`:4028-4031` | 已接 | 上游夹取 0–32（`SystemMenuPage.kt:645-655` 滑块 `0f..32f` steps 31），本地 `save()` 同样夹 0–32、`load()` 用 `normalizeInteger(...,0,32,...)`。渲染：`ReaderPage.ets:4028-4031` 的 `borderRadius` 四角取该值，**非悬浮时下方两角强制 0**（卡片贴屏幕底边不能有下圆角） | 设置 → 阅读界面 → 菜单 tab → 底栏布局，把「底栏圆角」拖到 0 再拖到 32，退出设置页重进值保持；阅读页调出菜单，底栏卡片圆角随之从直角变圆角 | 备份口径：`readMenuBottomCornerRadius` 在 `BackupConfig.kt:232` 的 `readPrefKeys` 忽略清单里，不随 `config.xml` 导出，恢复备份不改本机值 |
| 底栏悬浮 | `ReadBookConfig.kt:82`（`readMenuFloatingBottomBar: Boolean = true`） | `ReaderSettingsRepository.ets:296`、`ReaderSettingsPage.ets:769`/`:783`/`:2358`、`ReaderPage.ets:238`/`:4022`/`:4033` | 已接 | 上游默认 `true`（`ReadSettings.kt:95`），本地上屏在底栏布局 tab，Toggle 直连。渲染三处同时变化：宽度 `92%`↔`100%`（`:4022`）、下方两角圆角 `0`↔`readMenuBottomCornerRadius`（`:4030-4031`）、底部外边距 `16`↔`0`（`:4033`） | 关闭「底栏悬浮」后阅读页底栏铺满屏宽、下圆角消失、贴底无空隙；重新打开恢复悬浮卡片。设置页退出重进值保持 | 同一开关还决定底栏布局 tab 里「底栏模糊样式」与「底栏液态玻璃」两项互斥显示（见该两行） |
| 底栏模糊 | `ReadBookConfig.kt:106`（`readMenuBottomBarBlurMode: Int = ReadMenuBlurMode.None`） | `ReaderSettingsRepository.ets:301`、`ReaderSettingsPage.ets:215`/`:771`/`:784`/`:2359`、`ReaderPage.ets:240` | 已接 | 上游三档 `ReadMenuBlurMode`（`PreferKey.kt:498`）：`None = 0` / `LiquidGlass = 1` / `Haze = 2`，但**开关控件只写 2 与 0**（`SystemMenuPage.kt` 的 `TinySwitchSettingItem(read_menu_bar_blur)` 写 `if (it) Haze else None`），`LiquidGlass` 由「底栏液态玻璃」那个开关写。本地把三条入口都保留：本行开关写 2/0，「底栏液态玻璃」写 1。**非悬浮时存的 1 会降级成 2**（`ReaderSettingsPage.ets:849-852 effectiveBottomBarBlurMode()`，对齐 `SystemMenuPage.kt:560-568`）。存储夹 0–2 | 打开「底栏模糊」后底栏背景从不透明变半透雾化；关掉恢复 | 备忘录：上游没有名为「模糊效果」的独立三档下拉，只有这个二值开关 + 液态玻璃开关，本地按此还原，未造三档 |
| 底栏模糊透明度 | `ReadBookConfig.kt:110`（`readMenuBlurAlpha: Int = 85`） | `ReaderSettingsRepository.ets:317`、`ReaderSettingsPage.ets:872`/`:882`/`:2361`、`ReaderPage.ets:246`/`:842-843` | 已接 | **上游只有一个字段 `readMenuBlurAlpha`（夹 0–100），底栏与顶栏、整块菜单共用**；本地照此只建一个字段，底栏消费点 `ReaderPage.ets:842-843 readerBottomBarFillColor()` 取 `alpha = min(0.6, 值/100)`，**上限 0.6** 对齐上游 `ReadBookMenuBarShared.kt:49-85` 的 `coerceAtMost(0.6f)`。滑块范围 0–100、步长 1（`menuSliderMaximum()` → 100） | 把「底栏模糊透明度」拖到 20 与 100，底栏背景浓淡明显变化且 100 也不会完全遮住正文（上限 0.6）；退出重进值保持 | 本地的「菜单模糊透明度」行（E2 块）绑同一字段，两处改一处会同时生效——这是上游行为，非本地缺陷 |
| 底栏模糊样式 | `ReadBookConfig.kt:108`（`readMenuBottomBarBlurStyle: Int = ReadMenuBlurStyle.Solid`） | `ReaderSettingsRepository.ets:306`、`ReaderSettingsPage.ets:217`/`:911`/`:942`/`:2360`、`ReaderPage.ets:242`/`:856-858` | 已接 | 上游 `ReadMenuBlurStyle`（`PreferKey.kt:504`）：`Solid = 0` / `Progressive = 1`，是**下拉**而非常驻行，且被 `AnimatedVisibility(visible = !floatingBottomBar)` 包着——只在非悬浮时出现。本地同样只在「底栏悬浮」关闭时显示该条目（`ReaderSettingsPage.ets:999`）。渲染：`ReaderPage.ets:856-858 readerBottomBarGradient()`，`Solid` 时两段同色（视觉等价纯色），`Progressive` 时上浓下淡（`alpha` → `max(0, alpha - 0.25)`），`angle: 180`。存储只认 1 否则 0 | 关闭「底栏悬浮」后该项出现，切「渐变」，阅读页底栏背景呈上深下浅；退出重进仍为「渐变」 | **本地新增的条目行**（上游是同一 Tab 内的下拉项，本地条目表里没有对应的历史行），因此 E 块已接数比未接减行数多 1 |
| 底栏液态玻璃 | `ReadBookConfig.kt:86`（`readMenuBottomBarBlurMode` 取 `LiquidGlass = 1`） | `ReaderSettingsRepository.ets:301`、`ReaderSettingsPage.ets:774`/`:788-790`/`:2362`、`ReaderPage.ets:240` | 已接 | **上游没有独立字段**：这个开关写的就是 `readMenuBottomBarBlurMode = LiquidGlass(1)`（`SystemMenuPage.kt` 的 `TinySwitchSettingItem(read_menu_bar_liquid_glass)`，`checked = readMenuBottomBarBlurMode == LiquidGlass`，关时 `if (bottomBarBlurMode != None) Haze else None`）。本地逐字对齐该三态回写：`enabled ? 1 : (effectiveBottomBarBlurMode() !== 0 ? 2 : 0)`（`ReaderSettingsPage.ets:788-790`）。该条目被 `AnimatedVisibility(visible = floatingBottomBar)` 包着——**只在悬浮时出现**，本地同（`:1000`） | 打开「底栏悬浮」后「底栏液态玻璃」出现、「底栏模糊样式」隐藏；开启液态玻璃后关掉「底栏悬浮」，液态玻璃自动降级为雾化（开关显示关闭、「底栏模糊」显示开启） | 与上一行共用同一字段，两行是**同一上游开关的两个 UI 侧**，不是两个配置项 |
| 底栏按钮液态玻璃 | `ReadBookConfig.kt:86`（`readMenuBottomBarLiquidGlassButtons: Boolean = false`） | `ReaderSettingsRepository.ets:311`、`ReaderSettingsPage.ets:219`/`:777`/`:793`/`:2363`、`ReaderPage.ets:244`/`:874-875` | 已接 | 这一行才是独立字段 `readMenuBottomBarLiquidGlassButtons`（默认 `false`，`ReadSettings.kt:101`），控制底栏**每个按钮**的表面是否用玻璃质感，与底栏整体背景无关。上游给的中文说明是「需要 Android 13 及以上系统」。本地只做可配+落库：`ReaderPage.ets:874-875 readerBottomBarButtonGlassEnabled()` 已就位，**但尚无调用点**，按钮底色未真驱动（见 KNOWN-ISSUES KI-E4 已知差异） | 开关可拨动、退出重进值保持；按钮玻璃质感本身**未取证**（模拟器无 API 13+ 液态玻璃材质，ArkUI 也无对应 `backdropBlur` 等效物） | 与「底栏液态玻璃」**不是**同一字段，此前表内写「同上字段」是错的，已纠正 |
| 标题栏胶囊 | `ReadBookConfig.kt:85`（`readMenuTopBarTitleCapsule: Boolean = false`，`ReadSettings.kt:100`） | `ReaderSettingsRepository.ets:322`、`ReaderSettingsPage.ets:224`/`:804`/`:827`/`:2441`、`ReaderPage.ets:248`/`:1743-1757`、`BackupRepository.ets:2078`（恢复取本机现值） | 已接 | 上游 `SystemMenuPage.kt` 的 TopBarTab 首项 `TinySwitchSettingItem(read_menu_top_bar_title_capsule)`。开胶囊后书名与章节名合并进一个 pill（`ReadBookMenuBarTitle.kt:492-620` 的 `TitleCapsuleGlassLayout`），并且**「标题栏模式」下拉整项被 `AnimatedVisibility(visible = !preferences.readMenuTopBarTitleCapsule)` 藏起来**（同文件 `:730` 一带）——本地按此加互斥可见（`ReaderSettingsPage.ets:1063`），两个方向都做过 dump 对照。渲染侧 `ReaderPage.ets:4083-4094` 在胶囊开启时用 `readerTitleCapsule()` 替换「行内书名 + 操作按钮」之外的标题区 | 设置 → 阅读界面 → 菜单 tab → 顶栏布局，打开「标题栏胶囊」后「标题栏模式」整行消失，关闭后重新出现（实测「在独立行上显示」）；退出设置页重进与 `aa force-stop` 重启后仍保持 | 备份口径：`readMenuTopBarTitleCapsule` 在 `BackupConfig.kt:238` 的 `readPrefKeys` 忽略清单里，不随 `config.xml` 导出，恢复备份只取本机现值 |
| 标题栏模式 | `ReadSettings.kt:12`（`titleBarMode: String = "1"`） | `ReaderSettingsRepository.ets:329`、`ReaderSettingsPage.ets:226`/`:961`/`:998`/`:1063`/`:2442`、`ReaderPage.ets:254`/`:1760-1777`/`:4083-4106` | 已接 | **上游是四值不是三值**：`values-zh-rCN/arrays.xml:242-247` = 在应用栏上显示 / 在独立行上显示 / 仅显示标题 / 不显示，`values/array_values.xml:146-151` 值 `"0"`–`"3"`，默认 `"1"`。消费点 `ReadBookMenuBarTitle.kt`：`:207` 非胶囊时只有 `"0"`/`"2"` 把书名放应用栏行内、`:239` 只有 `"1"` 让书名单独占一行、`:259` 只有 `"0"`/`"1"` 显示章节行、`:198` 只有 `"3"` 才把胶囊整体隐藏。本地此前是三值且顺序与上游不对应（「完整信息/仅标题/标题与章节」），本轮两处 `getDetailChoices` 与 `getMenuChoices` 全部改成上游四值，选中态用 `['0','1','2','3'].indexOf()` 换算 | 弹层里四项文案与上游中文串一致；选「在应用栏上显示」后条目摘要变「在应用栏上显示」，返回重进与重启应用后仍保持；选「不显示」时书名行与章节行都不渲染 | 备份口径：`titleBarMode` 在 `BackupConfig.kt:259` 的忽略清单里，不随 `config.xml` 导出 |
| 标题栏操作按钮 | `ReadSettings.kt` | `ReaderSettingsPage.ets:1832` | 已接 | 链路与底栏同构：`:470-472` → `handleMenuSettingsEntryClick()`（`:517-531`）→ `topActionConfigurationSheet()`（`:2006` 起）→ `onTopActionsChange` → `Index.ets:2227` → 写 `topActions`（`ReaderSettingsRepository.ets:805`） | 改显示与顺序后重进仍生效，阅读页顶栏同步变化 | 与底栏共用 `ReaderBottomActionConfig` |
| 标题栏紧凑 | `ReadBookConfig.kt:81`（`titleBarCompact: Boolean = false`，`ReadSettings.kt:120`） | `ReaderSettingsRepository.ets:335`、`ReaderSettingsPage.ets:228`/`:828`/`:2444`、`ReaderPage.ets:256`/`:1646`、`BackupRepository.ets:931`（写出）/`:2080-2081`（恢复） | 已接 | 上游消费点 `ReadMenuActionDefs.kt:505-506`：`if (state.menuConfig.titleBarCompact) return listOf(moreDef)` —— **开启后顶栏只保留「更多」按钮**；另 `ReadBookMenuBarFloating.kt:190` 把「换源」「朗读音频下载」等搬进悬浮菜单。本地在 `ReaderPage.ets:1646` 的 `getVisibleTopActions()` 开头短路返回 `[{ id: 'more_actions' }]`，与上游同语义 | 开关可拨动、退出重进与重启后值保持 | **备份口径与同组另外七项相反**：`titleBarCompact` **不在** `BackupConfig.readPrefKeys` 忽略清单里（该文件 grep `titleBar` 只有 `:254`/`:255`/`:256`/`:259`），随 `config.xml` 无条件导出；本地已在导出段补 `BackupRepository.ets:931`、恢复段读 xml 并 `current` 兜底 `:2080-2081` |
| 标题栏图标样式 | `ReadBookConfig.kt:101`（`titleBarIconStyle: Int = 0`，夹 0–2） | `ReaderSettingsRepository.ets:341`、`ReaderSettingsPage.ets:230`/`:962`/`:1001`/`:2445`、`ReaderPage.ets:258`/`:930-942` | 已接 | 上游三档在 `ReadBookMenuBarTitle.kt` 折算成按钮表面：`iconStyle == 1 → surfaceContainerLow` 底色（`:1008-1013`、`:534-540`）、`iconStyle == 2 → BorderStroke(1.dp, tint.copy(alpha = 0.45f))` 描边（`:436`、`:873-876`）、`0` 透明底无描边。本地 `ReaderPage.ets:930-931 readerTopBarButtonFillColor()` 返回 `#2A2B31`（色调）或 `Transparent`（纯色），`:938-942 readerTopBarButtonBorderWidth()` 在 2 且未开液态玻璃时返回 1，按钮边框色 `#73D5C2C6`（≈45% alpha） | 弹层三项「纯色 / 色调 / 描边」与上游一致；切「色调」后条目摘要变「色调」，返回重进与重启应用后仍保持 | 备份口径：`titleBarIconStyle` 在 `BackupConfig.kt:254` 的忽略清单里，不随 `config.xml` 导出 |
| 顶栏模糊 | `ReadBookConfig.kt:105`（`readMenuTopBarBlurMode: Int = ReadMenuBlurMode.None`，夹 0–2） | `ReaderSettingsRepository.ets:347`、`ReaderSettingsPage.ets:232`/`:809`/`:831`/`:2446`、`ReaderPage.ets:260`/`:902`/`:909` | 已接 | 上游是 `TinySwitchSettingItem(read_menu_bar_blur)`，`checked = preferences.readMenuTopBarBlurMode == ReadMenuBlurMode.Haze` —— **只认 Haze(2)，不认 LiquidGlass(1)**；`ReadBookMenuBarTitle.kt:1000-1006 readMenuTopBarHazeEnabled()` 同样只判 `== Haze`（顶栏没有底栏那种「非悬浮时把液态玻璃降级为雾化」的逻辑）。本地接真为二值开关：开写 2、关写 0（`ReaderSettingsPage.ets:829-832`），存储夹 0–2；渲染侧顶栏底色见下一行与「底栏模糊透明度」一行的 `readMenuBlurAlpha` | 打开「顶栏模糊」后 Toggle 为开、退出重进与重启应用后仍保持；关闭恢复 | 备份口径：`readMenuTopBarBlurMode` 在 `BackupConfig.kt:234` 的忽略清单里，不随 `config.xml` 导出 |
| 顶栏模糊样式 | `ReadBookConfig.kt:107`（`readMenuTopBarBlurStyle: Int = ReadMenuBlurStyle.Solid`，夹 0–1） | `ReaderSettingsRepository.ets:352`、`ReaderSettingsPage.ets:234`/`:963`/`:1004`/`:2447`、`ReaderPage.ets:262`/`:909-928` | 已接 | `ReadMenuBlurStyle`（`PreferKey.kt:504`）：`Solid = 0` / `Progressive = 1`，选项中文串「填充 / 渐变」。**与底栏不同：顶栏这个下拉没有 `AnimatedVisibility` 包裹，常驻可见**（上游 `SystemMenuPage.kt` 的 `TinyDropdownSettingItem(read_menu_bar_blur_style)`），本地也没有加任何可见性条件。渲染 `ReaderPage.ets:909-928 readerTopBarGradient()`：`Solid` 时两段同色（视觉等价纯色），`Progressive` 时上浓下淡（`alpha` → `max(0, alpha - 0.25)`），`angle: 180`，与底栏渐变的算法一致 | 切「渐变」后条目摘要变「渐变」，返回重进与重启应用后仍保持；切回「纯色」恢复 | 备份口径：`readMenuTopBarBlurStyle` 在 `BackupConfig.kt:240` 的忽略清单里，不随 `config.xml` 导出 |
| 顶栏液态玻璃按钮 | `ReadBookConfig.kt:83`（`readMenuTopBarLiquidGlassButtons: Boolean = false`，`ReadSettings.kt:98`） | `ReaderSettingsRepository.ets:357`、`ReaderSettingsPage.ets:236`/`:811`/`:833`/`:2448`、`ReaderPage.ets:264`/`:942` | 已接 | 上游 `TinySwitchSettingItem(read_menu_bar_liquid_glass_buttons)` → `ConfigUpdate.MenuTopBarLiquidGlassButtons`，消费点 `ReadBookMenuBarTitle.kt:996-1000 readMenuTopBarButtonLiquidGlassEnabled()`（`readMenuTopBarLiquidGlassButtons && readerMenuLiquidGlassAvailable(backdrop)`）。本地**只做可配 + 落库**：`ReaderPage.ets:942` 的 `readerTopBarButtonBorderWidth()` 用它抑制描边（开玻璃质感时不画 1vp 边框），但**玻璃材质本身无实现** | 开关可拨动、退出重进与重启应用后值保持；玻璃质感本身**未取证**（ArkUI 无 `backdropBlur` 等效物，模拟器也无 API 13+ 液态玻璃材质） | 备份口径：`readMenuTopBarLiquidGlassButtons` 在 `BackupConfig.kt:236` 的忽略清单里。与「底栏按钮液态玻璃」是**两个独立字段**，不要混 |
| 合并标题栏按钮 | `ReadBookConfig.kt:84`（`readMenuTopBarMergeButtons: Boolean = false`，`ReadSettings.kt:99`） | `ReaderSettingsRepository.ets:362`、`ReaderSettingsPage.ets:238`/`:812`/`:834`/`:2449`、`ReaderPage.ets:266`/`:946-947`/`:1699-1728` | 已接 | 上游 `ReadBookMenuBarTitle.kt:973-996`：为真时走 `MenuTitleBarMergedGlassButton`（`Row(height 40.dp)` + pillShape，按钮之间插 `MergedGlassDivider`），为假时走 `Row(spacedBy(6.dp))` 逐个排。本地 `readerTopBarMergeEnabled()` 为真时把顶栏按钮包进一个 `Row().height(40).borderRadius(20)` 胶囊容器（`readerTopActionGroup()`），按钮外间距归零、底色与描边由容器统一承担 | 开关可拨动、退出重进与重启应用后值保持；合并后的胶囊容器形态**未取证**（模拟器无正文可读进不了阅读页） | 备份口径：`readMenuTopBarMergeButtons` 在 `BackupConfig.kt:237` 的忽略清单里，不随 `config.xml` 导出 |
| 菜单镜头半径 | `ReadBookConfig.kt:114`（`readMenuLensRadius: Float = 24f`，夹 0–48；`ReadSettings.kt:110`） | `ReaderSettingsRepository.ets:439`（接口）/`:863`（默认 24）/`:1040`（读）/`:1387-1388`（夹 0–48）/`:1621-1622`（写）；`Index.ets:198`/`:1981`/`:2130`/`:3685`；`BackupRepository.ets:2124`（恢复取本机现值） | 已接 | 上游只有字段与落库：`grep -rn "MenuLensRadius" app/src/main/java/io/legado/app/` 共 16 处，全部是 `PreferKey.kt:409` 键名、`ReadSettingsRepository.kt:307-308` 落库与映射、`ReadSettings.kt:110` 字段、`ReadBookConfig.kt:114` 夹取、`ReadBookContract.kt:484`/`:1920` 契约、`ReadConfigUpdateDelegate.kt:457-461` 委托、`ReadBookViewModel.kt:2130` 快照、`ReadBookMenuBarShared.kt:78` 渲染消费、`BackupConfig.kt:248` 忽略清单，**没有任何 UI 发送点**（`SystemMenuPage.kt` 与 `ReadConfigScreen.kt` 都查无此项）。消费端把它当 `readerMenuLiquidGlass` 的 `lensRadius`，而该材质只在 API 33+ 可用。本地按「上游有字段就保留、上游没有效果就不造」处理：字段与落库齐备、随备份忽略清单走，**不上屏**（与 KI-A3 `disableReturnKey` 同一判据）；ArkUI 无液态玻璃材质，`lens` 效果不实现 | 偏好文件出现 `<double key="readMenuLensRadius" value="24.000000"/>`，任一阅读设置改动触发保存后仍为 24；面板无该条目（与上游一致） | 备份口径：`readMenuLensRadius` 在 `BackupConfig.kt:248` 忽略清单里，不随 `config.xml` 导出 |
| 自动亮度 | `ReadBookConfig.kt:97` | `ReaderSettingsRepository.ets:256` | 已接 | 上游 `brightnessAuto: Boolean = true`（`ReadSettings.kt:23`），存储键 `brightnessAuto`（`PreferKey.kt:194`），不在忽略清单里、随 config.xml 备份；`ReadBookController.kt:3183` 为真时把窗口亮度交回系统。本地 `ReaderSettingsRepository.ets:256`/读 `:736`/写 `:1177`，`ReaderPage.ets:747` `const value = this.brightnessAuto ? -1 : Math.max(0, Math.min(1, this.readBrightness / 100));`，`@Watch('onReadBrightnessChanged')` 联动，备份在 `BackupRepository.ets` 的 config.xml 导出与恢复段 | 注入 `brightnessAuto=false` 后窗口亮度按 `brightness/100` 生效；恢复 `true` 后交回系统 | 见 本机归档 `docs/history/known-issues/reader-config-landed.md` 的 KI-E6（不随公开仓库发布） |
| 阅读栏样式 | `ReadSettings.kt:69`（`readBarStyle: Int = 1`，夹 0–2） | `ReaderSettingsRepository.ets:372`（接口）/`:775`（默认 1）/`:928`（读）/`:1453`（写）；`ReaderSettingsPage.ets:2518`（条目）/`:886`（段落落库）/`:1028`（选中态）；`ReaderPage.ets:1023`（`readerMenuBaseColor()` 消费） | 已接 | 三值 0 跟随系统 / 1 跟随阅读背景 / 2 自定义（`values-zh-rCN/strings.xml:271 flow_sys`、`:2064 follow_read_background`、`:1965 custom`），**由 KI-E1 一并接上，不是 KI-E6 新做**。上游消费点 `ReadBookColorTheme.kt:52-63`（1 → `rememberReadBackgroundTheme`、2 → `rememberCustomReadMenuTheme`、else → null）、`ReadBookConfig.kt:157`、`ReadBookMenuBar.kt:144`/`:1033-1036`。本地折算在 `ReaderPage.ets:1023 readerMenuBaseColor()`：1 取当前纸色、2 取日/夜自定义背景色（空串回落强调色）、其余按日夜黑白 | 面板「工具栏样式」切三档后条目摘要随之变化，退出重进与重启应用后保持（KI-E1 已验） | 备份口径：`readBarStyle` 在 `BackupConfig.kt:216` 忽略清单里，不随 `config.xml` 导出 |
| 阅读栏样式跟随页面 | `ReadSettings.kt:68`（`readBarStyleFollowPage: Boolean = false`） | `ReaderSettingsRepository.ets:447`（接口）/`:864`（默认 false）/`:1041`（读）/`:1389-1390`（归一）/`:1623`（写）；`Index.ets:204`/`:1982`/`:2131`/`:3686`；`BackupRepository.ets:2125`（恢复取本机现值） | 已接 | 上游同样只有字段与落库、**没有 UI 发送点**：全仓 `readBarStyleFollowPage` 只命中 `PreferKey.kt:290`、`ReadSettingsRepository.kt:206`/`:557`/`:691`、`ReadSettings.kt:68`、`BackupConfig.kt:217`、`ReadConfig.kt:56` 只读快照，以及两个消费点 `model/ReadBook.kt:724-726`（阅读样式档位变化时刷新动作栏）与 `ui/book/read/ReadStyleDelegate.kt:445-449 postActionBarUpdateIfFollowingPage()`（`colorSelected` 的 TEXT_COLOR `:376` / TEXT_ACCENT_COLOR `:384` / BG_COLOR `:392` 三处调用）。本地 `ReaderPage.ets:1023 readerMenuBaseColor()` 直接由 `@Prop paperColor`/`readingTextColor` 等响应式重算，颜色一变菜单底色即重算，**语义天然等价于上游「跟随页面」**，故只落库、不加开关 | 偏好文件出现 `<bool key="readBarStyleFollowPage" value="false"/>`；阅读页改正文色/背景色后菜单底色同步重算（响应式 @Prop，未做像素级取证） | 备份口径：`readBarStyleFollowPage` 在 `BackupConfig.kt:217` 忽略清单里，不随 `config.xml` 导出 |
| 更多操作配置 | `ReadSettings.kt:121`（`moreActionsConfig: String = ""`） | `ReaderSettingsRepository.ets:454`（接口）/`:865`（默认空串）/`:1042`（读）/`:1391-1392`（归一）/`:1624`（写）/`:1896 encodeMoreActions`/`:1905 decodeMoreActions`；`Index.ets:2134`（快照编码）/`:3695-3696`（恢复解码并写回仓储）/`:2047-2058`（`setReaderMoreActions` 保存后回写快照）；`BackupRepository.ets:935`（config.xml 导出）/`:2127-2128`（恢复优先读 config.xml） | 已接 | 上游格式 `id,enabled;id,enabled`（`ReadButtonConfigDelegate.kt:75-84 saveMoreActions`），解析 `parseMoreActions`（`:86-98`）：**空串 = 全部默认开启**，串里未出现的项补 `true`（与顶栏/底栏「默认关闭」相反），本地 `decodeMoreActions` 照抄。**运行时真源仍是本地已有的 `ReaderMoreActionsRepository`（独立 prefs `legado_reader_more_actions`，23 项）**，本字段是它在 `ReaderSettingsRepository` 里的备份投影：导出时由 `Index.getCurrentReaderSettingsSnapshot()` 现编码，恢复时解码后立刻 `ReaderMoreActionsRepository.save` 写回，否则备份里改过的条目会被旧仓储值覆盖。`moreActionsConfig` 不在上游 `readPrefKeys` 忽略清单（该清单只有 `:216`/`:217`/`:248` 三条相关命中），**随 `config.xml` 无条件备份**，与 E5 的 `titleBarCompact` 同类 | 偏好文件出现 `<string key="moreActionsConfig">source_custom_button,true;change_source,true;…</string>`（23 项）；「更多」面板增删条目后该串随之变化并跨进程保持 | 备份口径：不在 `BackupConfig.readPrefKeys` 忽略清单里，**随 `config.xml` 导出**；本地 `BackupRepository.ets` 的 `preferenceKeysByCategory.readConfig` 也未列该键 |

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

**本节与 A–G 明细表是两个不同的计数口径，不可相加。** A–G 按「一次用户可感知的操作」计 189 行（11 行未接，逐行在 [KNOWN-ISSUES](../KNOWN-ISSUES.md#阅读配置行登记reader-configmd-的未接行) 登记）；本节按「上游声明名」计字段差集 112 项，逐项判定见 1.5。一个操作可能对应多个字段（「菜单背景颜色」对应 `readMenuBgColor` + `readMenuBgColorNight`），也有上游字段在本地连条目都没有（`readMenuLensRadius`、`brightnessAuto`）。硬凑成一个数字会反复返工，因此两处各记各的。

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

其中 `highlightRules` 已由独立仓储承接（见 1.4），真正需要补的是 **111 项**。

**2026-11-01 消账结果**：这 111 项里 **91 项已由 KI-A1..A12 / C1..C6 / D1..D6 / E1..E6 逐组接上**（存储键、读/写、消费端行号见 1.5 各表逐行），**20 项判「不接」并逐条写明理由**（上游虽有但本地不补、或属[项目范围](../PROJECT.md)之外的设备/内容形态）。**没有「要接」残留**，本节的 112 项至此全部有结论。

### 1.4 既不是缺口也不是改名的两种情况

- **改名已接 15 项**：`lineSpacingExtra`、`menuIconItemsPerRow`、`menuIconRowCount`、`menuIconShowText`、`menuIconStyle`、`pageAnim`、`pageAnimSpeed`、`shadowColor`、`shadowColorN`、`textSize`、`useUnderline`、`progressBarBehavior`、`clickImgWay`、`tocUiUseReplace`、`tocCountWords`，见第二节映射表。
- **数组合并 9 项**：`clickActionTL`…`clickActionBR` 九个整型字段由本地一个 `clickRegionActions: string[]` 承接（`ReaderSettingsRepository.ets:177`，默认值 `:243-245`，消费 `ReaderPage.ets:1125`）。字段名比对会把这 9 项全判缺失，实际是已接。
- **容器合并 12 项**：`ReadBookConfig.kt:604-615` 的 12 个页边距字段由本地 `ReaderPaddingSettings` 容器承接（`ReaderSettingsRepository.ets:99-112`，默认值 `:114-118`）。注意 `ReadSettings.kt:11` 的 `paddingDisplayCutouts` 是另一个字段，**不在此列**，已由 KI-A1 单独接上。
- **非配置项 2 项**：`name`（`ReadBookConfig.kt:536`，书名字段）与 `id`（`:659`，`@Transient` 进程内列表身份，注释明写「不写入主题包」）。
- **另有独立仓储 1 项**：`highlightRules`（`ReadBookConfig.kt:656`）不在 `ReaderSettingsRepository.ets` 中，但本地对应 `entry/src/main/ets/model/ReaderHighlightRule.ets`、`data/ReaderHighlightRuleRepository.ets`、`data/ReaderHighlightRuleEngine.ets` 三个文件，属高亮规则的独立模块。它在 1.3 的 112 项里占一格，但不需补仓储字段。

> 1.3 的 112 项与 A–G 明细表的 189 行是两个口径：明细表按「一次用户可感知的操作」计，字段表按「上游声明名」计。**两处数字不可相加，也不必相加。**

### 1.5 逐项判定（112 项，逐条给结论）

判定口径：**要接** = 上游有该行为、本地范围内应当补；**不接** = 上游虽有但本地不补，理由必须写明（上游没有的行为一律不补）；**已接** = 已有等价实现，无需动作。「要接」项的去处指向 1.3 与 [KNOWN-ISSUES](../KNOWN-ISSUES.md#阅读配置行登记reader-configmd-的未接行) 的 KI 登记组，两组编号同源。

| 判定 | 项数 | 说明 |
| --- | --- | --- |
| 已接 | 92 | 判「要接」的 91 项已由 KI-A1..A12、C1..C6、D1..D6、E1..E6 逐组实现并落库，另有 `highlightRules` 1 项原本就是独立仓储的等价实现 |
| 要接 | 0 | 无剩余待接项 |
| 不接 | 20 | 上游虽有但本地不补，逐条理由见各节 |
| 合计 | 112 | |

**本表 112 行与 1.3 的 14 个字段组逐组对齐，无未判项，也无「要接」残留。** 判定与实现分两阶段：先逐项判「接不接」，再由 KI 分组逐组实现；92 项已接的状态列都附了存储键与读/写/消费行号，可逐条复核。判「不接」的 20 项保持原判据不动（上游没有的行为一律不补）。其中依赖在线服务（书源/RSS/TTS/WebDAV）的若干项自 2026-11-09 起已属范围之内但尚未排期，判据仍记「不接」**仅指当前一轮不做**，不再表示「永远不做」。

#### 1.5.1 背景与颜色（9 项）：已接 9

| 字段 | 判定 | 理由与去处 |
| --- | --- | --- |
| `bgAlpha` | 已接 | 上游背景透明度，本地无字段（KI-C2）；**KI-C2 已实现**（存储键 `bgAlpha`，`ReaderSettingsRepository.ets:247`，只作用于背景图片） |
| `bgStr` | 已接 | 上游任意颜色串，本地只有六方案索引（KI-C2）；**KI-C2 已实现**（存储键 `bgStr`，六方案降级为预设） |
| `bgStrNight` | 已接 | 同上，夜间侧（KI-C2）；**KI-C2 已实现**（存储键 `bgStrNight`） |
| `bgType` | 已接 | 上游 0=颜色/1=assets 图/2=自选图，本地无（KI-C2）；**KI-C2 已实现**（自选图写 2，`ReaderBackgroundImageRepository.ets` 负责选图与复制） |
| `bgTypeNight` | 已接 | 同上，夜间侧（KI-C2）；**KI-C2 已实现** |
| `textColor` | 已接 | 正文字色被 `ReaderPage.ets` 的 `getReadingTextColor()` 硬编码（KI-C1）；**KI-C1 已实现**（存储键 `textColor`，默认 `#38383B` 沿用原硬编码观感） |
| `textColorNight` | 已接 | 同上，夜间侧（KI-C1）；**KI-C1 已实现**（存储键 `textColorNight`，默认 `#D8D8DC`） |
| `textAccentColor` | 已接 | 强调色无字段（KI-C1）；**KI-C1 已实现**（存储键 `textAccentColor`，默认 `#834E00`）。上游真实消费点是链接/搜索结果/朗读段落，本地这三条路径都还没有，故只做可配+落库+随备份 |
| `textAccentColorNight` | 已接 | 同上，夜间侧（KI-C1）；**KI-C1 已实现**（默认 `#FE4D55`） |

#### 1.5.2 状态栏（2 项）：已接 2

| 字段 | 判定 | 理由与去处 |
| --- | --- | --- |
| `darkStatusIcon` | 已接 | 上游按背景亮度决定状态栏图标色，本地无字段（KI-C2）；**KI-C2 已实现**（`ReaderPage.ets` 的 `applyReaderStatusBarIcon()` 走 `setWindowSystemBarProperties`） |
| `darkStatusIconNight` | 已接 | 同上，夜间侧（KI-C2）；**KI-C2 已实现**（设备实测亮像素 6726→0） |

#### 1.5.3 下划线与虚线（4 项）：已接 4

| 字段 | 判定 | 理由与去处 |
| --- | --- | --- |
| `underlinePadding` | 已接 | **KI-C3 已实现**（存储键 `underlinePadding`，默认 10，绘制时取 `值 - 10` 作相对偏移；`ReaderCanvasSurface.ets` 的 `drawLineUnderline`） |
| `underlineExtend` | 已接 | **KI-C3 已实现**（存储键 `underlineExtend`，默认 false；打开后线段右端取整列宽；现由 `ReaderCanvasSurface.ets` 的 `drawLineUnderline()` 绘制） |
| `dottedBase` | 已接 | **KI-C3 已实现**（存储键 `dottedBase`，默认 6；作 `createDashPathEffect` 的线段项，现由 `ReaderCanvasSurface.ets` 的 `drawLineUnderline()` 绘制） |
| `dottedRatio` | 已接 | **KI-C3 已实现**（存储键 `dottedRatio`，默认 6；作 `createDashPathEffect` 的间隔项，现由 `ReaderCanvasSurface.ets` 的 `drawLineUnderline()` 绘制） |

#### 1.5.4 标题排版（14 项）：已接 14

| 字段 | 判定 | 理由与去处 |
| --- | --- | --- |
| `titleMode` | 已接 | **KI-C4 已实现**（存储键 `titleMode`，三值 0/1/2；渲染 `ReaderPage.ets:2163`、`:2200`；面板 `ReaderSettingsPage.ets:360`） |
| `titleSize` | 已接 | **KI-C4 已实现**（存储键 `titleSize`，默认 4；9 处 `fontSize + 4` 已清除，统一走 `ReaderPage.ets:2140`） |
| `titleSizeRelative` | 已接 | **KI-C4 已实现**（存储键 `titleSizeRelative`，显式 boolean 默认 true，等价覆盖上游 null 态） |
| `titleBold` | 已接 | **KI-C4 已实现**（存储键 `titleBold`，口径 `resolveWeight()` 照搬上游 `:113-119`；渲染 `ReaderPage.ets:2149`） |
| `titleColor` | 已接 | **KI-C4 已实现**（存储键 `titleColor`，空串 = 跟随正文，对应上游默认 0；渲染 `ReaderPage.ets:2157`） |
| `titleColorNight` | 已接 | **KI-C4 已实现**（存储键 `titleColorNight`；夜间实测注入 `#FF8C00` 后标题区橙色像素 6153 个、正文零橙色） |
| `titleLineSpacingExtra` | 已接 | **KI-C4 已实现**（存储键 `titleLineSpacingExtra`，除以 10 作行高倍率，见 `ReaderPage.ets:2182`） |
| `titleLineSpacingSub` | 已接 | **KI-C4 已实现**（存储键 `titleLineSpacingSub`，按 `isSubtitle` 分取两值） |
| `titleTopSpacing` | 已接 | **KI-C4 已实现**（存储键 `titleTopSpacing`，参与分页度量 `measureTitleReservedLines()`） |
| `titleBottomSpacing` | 已接 | **KI-C4 已实现**（存储键 `titleBottomSpacing`，取代原先写死的 `.margin({ bottom: 24 })`） |
| `titleSegType` | 已接 | **KI-C4 已实现**（存储键 `titleSegType`；分段模块 `data/ReaderTitleSegmentation.ets`；设「按字数」后 dump 出两个独立 Text 节点） |
| `titleSegScaling` | 已接 | **KI-C4 已实现**（存储键 `titleSegScaling`；`normalizeFraction(…,1,2,…)` 照搬上游负值回落 1 的规则） |
| `titleSegDistance` | 已接 | **KI-C4 已实现**（存储键 `titleSegDistance`，type=1 时作切点字数） |
| `titleSegFlag` | 已接 | **KI-C4 已实现**（存储键 `titleSegFlag`，type=2 按逗号分词转义、type=3 整串作正则） |

#### 1.5.5 菜单颜色（14 项）：已接 10、不接 4

| 字段 | 判定 | 理由与去处 |
| --- | --- | --- |
| `readMenuAccentColor` | 已接 | 菜单强调色用户可配（KI-E1）；**已实现**（存储键 `readMenuAccentColor`，`ReaderSettingsRepository.ets:392`，与「种子色」共用同一字段） |
| `readMenuAccentColorNight` | 已接 | 同上，夜间侧（KI-E1）；**已实现**（`ReaderSettingsRepository.ets:394`） |
| `readMenuContainerColor` | 已接 | 菜单容器色，未设时回落到背景色（KI-E1）；**已实现**（`ReaderSettingsRepository.ets:388`） |
| `readMenuContainerColorNight` | 已接 | 同上，夜间侧（KI-E1）；**已实现**（`ReaderSettingsRepository.ets:390`） |
| `readMenuBlurColor` | 已接 | **KI-E2 已实现**（存储键 `readMenuBlurColor`，空串 = 未设置；`ReaderSettingsRepository.ets:408`、读 `:972`、写 `:1513` 起；渲染 `ReaderPage.ets:1043 readerMenuTintColor()`，在 `readerMenuBaseColor()` 开头优先返回 `:1008`） |
| `readMenuBlurColorNight` | 已接 | 同上，夜间侧（KI-E2）；**已实现**（`ReaderSettingsRepository.ets:410`、读 `:973`） |
| `readMenuBorderColor` | 已接 | **KI-E2 已实现**（存储键 `readMenuBorderColor`，空串回落 `outlineVariant` 等价的 `#73` 前景色；`ReaderSettingsRepository.ets:398`、读 `:965`、写 `:1513` 起；渲染 `ReaderPage.ets:1067 readerMenuBorderSettings()`） |
| `readMenuBorderColorNight` | 已接 | 同上，夜间侧（KI-E2）；**已实现**（`ReaderSettingsRepository.ets:400`、读 `:966`） |
| `readMenuTextColor` | 已接 | **KI-E2 已实现**（存储键 `readMenuTextColor`，空串回落日夜反色 `#D5C2C6`/`#3E3D3B`；`ReaderSettingsRepository.ets:404`、读 `:969`、写 `:1513` 起；渲染 `ReaderPage.ets:1023 readerMenuForeground()` 优先取本项） |
| `readMenuTextColorNight` | 已接 | 同上，夜间侧（KI-E2）；**已实现**（`ReaderSettingsRepository.ets:406`、读 `:970`） |
| `menuBgColor` | 不接 | `Config` 内 `@Transient` 的主题包承载字段（`ReadBookConfig.kt:540`），上游没有设置入口，改它的只有 `withMenuCurBg`（`:1002`）这类程序化调用；用户可配的是 `readMenuBgColor` 系列。本地没有主题包功能，无对应物。**注意**：按本表「语义重复按一项计」的口径，用户可配的 `readMenuBgColor` 记在这一行名下，它已由 KI-E1 接上（`ReaderSettingsRepository.ets:384`，对应明细表「菜单背景颜色」一行）；此处判「不接」只针对 `Config` 内这个 `@Transient` 字段本身 |
| `menuBgColorNight` | 不接 | 同上（`:544`）；用户可配的 `readMenuBgColorNight` 已由 KI-E1 接上（`ReaderSettingsRepository.ets:386`） |
| `menuAcColor` | 不接 | 同上（`:542`） |
| `menuAcColorNight` | 不接 | 同上（`:546`） |

#### 1.5.6 菜单样式选择（2 项）：已接 2

| 字段 | 判定 | 理由与去处 |
| --- | --- | --- |
| `readMenuColorMode` | 已接 | 菜单配色来源（跟随/自定义），本地只有页面 `@State`（KI-E1）；**已实现**（`ReaderSettingsRepository.ets:379`，默认 1，夹 0–1，页面假 `@State` 已删除） |
| `readMenuPaletteStyle` | 已接 | 调色板风格，本地条目存在无状态（KI-E1）；**已实现**（`ReaderSettingsRepository.ets:377`，空串 = 跟随系统，`normalizePaletteStyle :1657` 只认九值） |

#### 1.5.7 菜单模糊与边框数值（5 项）：已接 4、不接 1

| 字段 | 判定 | 理由与去处 |
| --- | --- | --- |
| `readMenuBlurAlpha` | 已接 | **KI-E4 已实现字段与底栏消费**（存储键同名，夹 0–100：读 `ReaderSettingsRepository.ets:822`/`:1116`、写 `:1296`；面板滑块 `ReaderSettingsPage.ets:2361`/`:872`/`:882`；底栏消费 `ReaderPage.ets:842-843`，上限 0.6）。该字段上游本就是底栏与整块菜单共用一个值，字段链路不再重复建。**KI-E2 已把两处入口都接上**：菜单栏 tab 的「菜单模糊透明度」滑块原先完全没接线（`menuSettingsEntry()` 的 onChange 与 `menuSliderValue` 都没有这一项），补两行分支后与底栏共用同一字段（`ReaderSettingsPage.ets:2595`、`menuSliderValue` 返回 `readMenuBlurAlpha`），两处改动任一处都会同步 |
| `readMenuBlurRadius` | 已接 | **KI-E2 已实现**（存储键 `readMenuBlurRadius`，默认 24、夹 0–32：`ReaderSettingsRepository.ets:402`、读 `:968`、写 `:1512` 起；面板滑块 `ReaderSettingsPage.ets:2594`；渲染 `ReaderPage.ets:1080 readerMenuBlurRadiusVp()` → 顶栏 `:4273`、底栏 `:4380` 的 `.backdropBlur(...)`） |
| `readMenuBorderWidth` | 已接 | **KI-E2 已实现**（存储键 `readMenuBorderWidth`，默认 1、夹 0–4：`ReaderSettingsRepository.ets:396`、读 `:964`、写 `:1512`；`> 0` 即「边框开关」本身，对齐上游 `SystemMenuPage.kt:398`；面板 Toggle `ReaderSettingsPage.ets:2590` + 滑块 `:2591`；渲染 `ReaderPage.ets:1067 readerMenuBorderSettings()` → 顶栏 `:4272`、底栏 `:4379`） |
| `readMenuLensRadius` | 已接 | **KI-E6 已实现**：存储键同名 `readMenuLensRadius`（默认 24、夹 0–48），读 `ReaderSettingsRepository.ets:1040`、写 `:1621-1622`；**上游没有任何 UI 发送点**（全仓 `MenuLensRadius` 16 处全是键名/落库/契约/委托/快照/渲染消费/忽略清单），本地同样不上屏，只落库 + 随备份忽略清单；渲染消费端 `ReadBookMenuBarShared.kt:78` 的 `lensRadius` 只服务 API 33+ 液态玻璃材质，ArkUI 无对应材质 |
| `menuBottomCornerRadius` | 不接 | `Config` 内 `@Transient`（`ReadBookConfig.kt:651`），与 `readMenuBottomCornerRadius` 是同一配置的两处声明；上游用户项是后者，本地已接 |

#### 1.5.8 菜单布局与玻璃效果（12 项）：已接 10、不接 2

| 字段 | 判定 | 理由与去处 |
| --- | --- | --- |
| `readMenuBottomBarBlurMode` | 已接 | **KI-E4 已实现**（存储键同名，夹 0–2：读 `ReaderSettingsRepository.ets:819`/`:1110`、写 `:1290`；面板 Toggle `ReaderSettingsPage.ets:784-787` 写 2/0、液态玻璃开关 `:788-791` 写 1；非悬浮降级 `:849-852`；消费 `ReaderPage.ets:240`） |
| `readMenuBottomBarBlurStyle` | 已接 | **KI-E4 已实现**（存储键同名，夹 0–1：读 `ReaderSettingsRepository.ets:820`/`:1112`、写 `:1292`；下拉 `ReaderSettingsPage.ets:2360`、选中态 `:911`、写回 `:942`；消费 `ReaderPage.ets:856-858 readerBottomBarGradient()`） |
| `readMenuBottomBarLiquidGlassButtons` | 已接 | **KI-E4 已实现**（存储键同名，布尔：读 `ReaderSettingsRepository.ets:821`/`:1114`、写 `:1294`；面板 `ReaderSettingsPage.ets:2363`/`:793`；消费方法 `ReaderPage.ets:874-875` —— 可配+落库已通，按钮底色尚无调用点，见 KNOWN-ISSUES KI-E4） |
| `readMenuFloatingBottomBar` | 已接 | **KI-E4 已实现**（存储键同名，布尔默认 true：读 `ReaderSettingsRepository.ets:818`/`:1108`、写 `:1289`；面板 `ReaderSettingsPage.ets:2358`/`:783`；消费 `ReaderPage.ets:4022`/`:4030-4031`/`:4033` 三处，并决定另两项互斥可见 `ReaderSettingsPage.ets:999-1000`） |
| `readMenuFloatingIconLiquidGlass` | 已接 | **KI-E3 已实现**（存储键同名，布尔默认 false：读 `ReaderSettingsRepository.ets:1004`/`:1348`、写 `:1576`；面板 Toggle `ReaderSettingsPage.ets:2642`/`:998`/`:866-868`/`:895`；消费 `ReaderPage.ets:2002` 浮动图标按钮底色） |
| `readMenuTopBarBlurMode` | 已接 | **KI-E5 已实现**（存储键同名，夹 0–2：读 `ReaderSettingsRepository.ets:881`/`:1189`、写 `:1383`；面板 Toggle `ReaderSettingsPage.ets:829-832` 只写 2/0，对齐上游 `checked = readMenuTopBarBlurMode == Haze`；消费 `ReaderPage.ets:260`） |
| `readMenuTopBarBlurStyle` | 已接 | **KI-E5 已实现**（存储键同名，夹 0–1：读 `ReaderSettingsRepository.ets:882`/`:1191`、写 `:1384`；下拉 `ReaderSettingsPage.ets:2447`、选中态 `:963`、写回 `:1004`；消费 `ReaderPage.ets:909-928 readerTopBarGradient()`） |
| `readMenuTopBarLiquidGlassButtons` | 已接 | **KI-E5 已实现**（存储键同名，布尔：读 `ReaderSettingsRepository.ets:883-884`/`:1193`、写 `:1385`；面板 `ReaderSettingsPage.ets:2448`/`:833`；消费 `ReaderPage.ets:942` 抑制描边 —— 玻璃材质本身无实现，见 KNOWN-ISSUES KI-E5） |
| `readMenuTopBarMergeButtons` | 已接 | **KI-E5 已实现**（存储键同名，布尔：读 `ReaderSettingsRepository.ets:885`/`:1195`、写 `:1386`；面板 `ReaderSettingsPage.ets:2449`/`:834`；消费 `ReaderPage.ets:946-947` + `:1699-1728 readerTopActionGroup()`） |
| `readMenuTopBarTitleCapsule` | 已接 | **KI-E5 已实现**（存储键同名，布尔：读 `ReaderSettingsRepository.ets:877`/`:1181`、写 `:1378`；面板 `ReaderSettingsPage.ets:2441`/`:827`，并让「标题栏模式」互斥隐藏 `:1063`；消费 `ReaderPage.ets:4083-4094 readerTitleCapsule()`） |
| `menuBottomHorizontalMargin` | 不接 | `Config` 内 `@Transient`（`:653`）主题包边距，上游无设置入口；本地底栏边距是布局常量 |
| `menuBottomBottomMargin` | 不接 | 同上（`:655`） |

#### 1.5.9 标题栏与图标（8 项）：已接 8

| 字段 | 判定 | 理由与去处 |
| --- | --- | --- |
| `readMenuCustomIcons` | 已接 | **KI-E3 已实现**（`id,path;` 编码串：读 `ReaderSettingsRepository.ets:1009`/`:1353`、写 `:1580`，归一 `:1778 normalizeCustomIconMap`；本地无选图入口，见 KNOWN-ISSUES KI-E3 已知差异） |
| `titleBarCustomIcons` | 已接 | **KI-E3 已实现**（同上：读 `ReaderSettingsRepository.ets:1008`/`:1352`、写 `:1578`，解码 `:1797 decodeCustomIconMap` 供 `ReaderPage.ets:1989` 渲染自定义图标；本地无选图入口） |
| `showMenuIcon` | 已接 | 存储 `ReaderSettingsRepository.ets:443`（默认 `false`）、读 `:1043`/归一 `:1389`、写 `:1625`；面板 `ReaderSettingsPage.ets:1512`；消费 `ReaderPage.ets:4586-4593`（「更多」网格面板图标）；在 `BackupConfig.kt:258` 忽略清单内，不随 config.xml 导出（KI-A2） |
| `showTitleBarIcons` | 已接 | **KI-E3 已实现**（存储键同名，布尔默认 false：读 `ReaderSettingsRepository.ets:1002`/`:1344`、写 `:1573`；面板 Toggle `ReaderSettingsPage.ets:2639`/`:866`/`:894`，并让三项互斥可见 `:1247`；消费 `ReaderPage.ets:1979`/`:1984`，挂载 `:4371`/`:4388`） |
| `titleBarCompact` | 已接 | **KI-E5 已实现**（存储键同名，布尔：读 `ReaderSettingsRepository.ets:879`/`:1187`、写 `:1381`；面板 `ReaderSettingsPage.ets:2444`/`:828`；消费 `ReaderPage.ets:1646` —— 开启后顶栏只留「更多」，对齐上游 `ReadMenuActionDefs.kt:506`；**随 config.xml 备份** `BackupRepository.ets:931`/`:2080-2081`） |
| `titleBarIconPosition` | 已接 | **KI-E3 已实现**（存储键同名，夹 0–3 默认 3：读 `ReaderSettingsRepository.ets:1003`/`:1347`、写 `:1574`；面板四值下拉 `ReaderSettingsPage.ets:2641`/`:1106`/`:1849`/`:1123`/`:947`/`:1173`；消费 `ReaderPage.ets:1974` 对齐） |
| `titleBarIconStyle` | 已接 | **KI-E5 已实现**（存储键同名，夹 0–2：读 `ReaderSettingsRepository.ets:880`/`:1189`、写 `:1382`；下拉 `ReaderSettingsPage.ets:2445`、选中态 `:962`、写回 `:1001`；消费 `ReaderPage.ets:930-942` 底色与描边） |
| `titleBarMode` | 已接 | **KI-E5 已实现**（存储键同名，**字符串四态** `"0"`–`"3"` 白名单：读 `ReaderSettingsRepository.ets:878`/`:1184-1186`、写 `:1379-1380`；面板两处选项改四值 `ReaderSettingsPage.ets:961`/`:998`/`:2442`；消费 `ReaderPage.ets:1760-1777` 四个可见性方法 + `:4083-4106`） | 

#### 1.5.10 亮度与滑块（5 项）：已接 5

| 字段 | 判定 | 理由与去处 |
| --- | --- | --- |
| `showBrightnessView` | 已接 | 亮度条显隐三值（KI-E1） |
| `brightnessVwPos` | 已接 | **KI-A9 已实现**（存储键 `readBrightnessControlPosition`，读 `ReaderSettingsRepository.ets:735`、写 `:1176`、面板 `ReaderSettingsPage.ets:2240`、条件可见 `:926`） |
| `brightnessAuto` | 已接 | **KI-A9 已实现**（存储键同名，读 `ReaderSettingsRepository.ets:736`、写 `:1177`、消费 `ReaderPage.ets:747`；随 config.xml 备份） |
| `readBrightness` | 已接 | **KI-A9 已实现**（存储键是 `brightness` 而非字段名，读 `ReaderSettingsRepository.ets:733`、写 `:1174`、消费 `ReaderPage.ets:747`；随 config.xml 备份） |
| `readSliderMode` | 已接 | 进度条显示/不显示默认 `"0"`；**KI-D5 已实现**（存储键 `readSliderMode`，`ReaderPage.ets:3109` 消费） |

#### 1.5.11 阅读模式与排版开关（4 项）：已接 2、不接 2

| 字段 | 判定 | 理由与去处 |
| --- | --- | --- |
| `readBodyToLh` | 已接 | **KI-A1 已实现**（存储键同名 `PreferKey.kt:104`，读 `ReaderSettingsRepository.ets:741`、写 `:1184`、面板 `ReaderSettingsPage.ets:1119`、`ReaderPage.ets:212`）。上游无渲染消费点，只做可配 + 落库 + 随备份；正文行高归一，本地只有恒 true 的占位开关（KI-A1） |
| `useZhLayout` | 已接 | **KI-A1 已实现**（存储键同名 `PreferKey.kt:150`，读 `:743`、写 `:1186`、面板 `:1131`、`ReaderPage.ets:214` + 布局 key `:1802`）。断行器不变，只进分页布局签名。r329 起正文断行改系统原生 `@ohos.graphics.text`，自造断行器已删，与上游「唯一断行器 + 开关只进布局签名」完全对齐；中文标点排版由系统断行承担（KI-A1 / r329） |
| `readStyleSelect` | 不接 | 图片书/漫画的排版样式索引；本地无图片书类型，属[项目范围](../PROJECT.md)之外的设备/内容形态（明细表 A 块 `:96` 已判 `不适用`） |
| `comicStyleSelect` | 不接 | 同上，漫画侧（明细表 A 块 `:97` 已判 `不适用`） |

#### 1.5.12 朗读提醒（1 项）：不接 1

| 字段 | 判定 | 理由与去处 |
| --- | --- | --- |
| `readAloudDetachReminderEnabled` | 不接 | 朗读（TTS）自 2026-11-09 起已纳入[项目范围](../PROJECT.md)、尚未排期（`PROJECT.md:24-44`）；朗读播放链路未落地，无「分离提醒」可提醒；开关已上屏，明细表 A 块按 `未接` 登记（KI-A5） |

#### 1.5.13 高亮规则（独立仓储，1 项）：已接 1

| 字段 | 判定 | 理由与去处 |
| --- | --- | --- |
| `highlightRules` | 已接 | 本地由 `entry/src/main/ets/model/ReaderHighlightRule.ets` + `data/ReaderHighlightRuleRepository.ets` + `data/ReaderHighlightRuleEngine.ets` 独立模块承接，备份与恢复已在 r258/r260 接通；不需要在 `ReaderSettingsRepository.ets` 里再建字段 |

#### 1.5.14 仅见于 ReadSettings.kt 的其余字段（31 项）：已接 21、不接 10

| 字段 | 判定 | 理由与去处 |
| --- | --- | --- |
| `adaptSpecialStyle` | 已接 | **KI-A1 已实现**（存储键同名 `PreferKey.kt:117`，读 `:747`、写 `:1190`、面板 `:1137`、`LocalTextSemantics.ets:94`/`:107`、`LocalReaderPaginator.ets:492`/`:742`）。`[newpage]` 换页与 `<usehtml>` 整段单 part；保留书籍自带样式，本地占位恒 true（KI-A1） |
| `paddingDisplayCutouts` | 已接 | **KI-A1 已实现**（存储键同名 `PreferKey.kt:337`，读 `:745`、写 `:1188`、面板 `:1125`、`ReaderPage.ets:216`/`applyReaderDisplayCutout()` `:812`）。顶部避让仍由状态栏 padding 承担；刘海屏安全区，本地占位恒 true（KI-A1） |
| `disableReturnKey` | 已接 | **KI-A3 已实现**（存储键同名 `disableReturnKey`，读 `ReaderSettingsRepository.ets:709`、写 `:1141`、面板 `ReaderSettingsPage.ets:1151`、备份 `BackupRepository.ets:878`/`:2037-2038`）。只做可配 + 落库 + 随备份：上游全仓无任何读该字段的 `BackHandler`/`onBackPressed`，本地也不加拦截 |
| `autoSuggestDayNight` | 已接 | **KI-A6 已实现**（`sensor.on(AMBIENT_LIGHT)` 订阅 + 10 分钟冷却 + 5 秒自动消失胶囊，存储键同名） |
| `sliderVibrator` | 已接 | 进度条触感反馈；**KI-A7 已实现**（存储键 `sliderVibrator`；上游 UI 侧无消费点，本地只做可配+落库+随备份，不加振动） |
| `selectVibrator` | 已接 | 选字触感反馈；**KI-A7 已实现**（存储键 `selectVibrator`，`ReaderPage.ets:1984`/`:1986` 经 `ReaderHaptics` 消费） |
| `prevKeys` | 已接 | **KI-D1 已实现**（存储键 `prevKeyCodes`，`ReaderSettingsRepository.ets:209`/读 `:671`/写 `:1091`，面板 `ReaderSettingsPage.ets:1921`） |
| `nextKeys` | 已接 | **KI-D1 已实现**（存储键 `nextKeyCodes`，`ReaderSettingsRepository.ets:211`/读 `:672`/写 `:1092`，面板 `ReaderSettingsPage.ets:1921`） |
| `mouseWheelPage` | 已接 | **KI-D1 已实现**（`ReaderSettingsRepository.ets:213`/读 `:673`/写 `:1093`，消费 `ReaderPage.ets:3869` `onAxisEvent`，面板 `ReaderSettingsPage.ets:1087`） |
| `textSelectMenuConfig` | 已接 | **KI-D2 已实现**（存储键同名，编解码 `ReaderSelectionMenu.ets`，面板 `ReaderSettingsPage.ets:1824`，渲染 `ReaderPage.ets:2496`） |
| `expandTextMenu` | 已接 | **KI-D2 已实现**（存储键同名，读 `ReaderSettingsRepository.ets:691`、写 `:1117`，渲染 `ReaderPage.ets:2470`） |
| `showSelectMenuIcon` | 已接 | **KI-D2 已实现**（存储键同名，读 `ReaderSettingsRepository.ets:692`、写 `:1118`，渲染 `ReaderPage.ets:2473`） |
| `doubleHorizontalPage` | 已接 | 横屏双页四档，**KI-D4 已实现**（存储键同名 `doubleHorizontalPage`，判定 `ReaderColumnMode.ets`，换列 `LocalReaderPaginator.ets` 的 `advanceColumn()`，渲染 `ReaderPage.ets` 按列 `Row`，面板 `ReaderSettingsPage.ets:1097`） |
| `pageTouchSlop` | 已接 | 翻页触摸阈值，0=平台默认；**KI-D5 已实现**（存储键 `pageTouchSlop`，`ReaderPage.ets:2947-2948` 消费） |
| `lastMarkingStyle` | 已接 | 沿用上次标记样式；**KI-D6 已实现**（存储键 `lastMarkingStyle`，`ReaderMarkingEditor.ets:255-264` 消费） |
| `chineseConverterType` | 已接 | 繁简转换三档，需自带字表；**KI-C5 已实现**（ICU Transliterator，`ChineseTextConverter.ets`） |
| `menuAlpha` | 已接 | 存储 `ReaderSettingsRepository.ets:456`（默认 100，夹 0–100）、读 `:1045`/归一 `:1391`、写 `:1627`；面板无条目（上游也没有）；`BackupRepository.ets:941` 导出、`:2134` 恢复；上游全仓无渲染消费点，本地只落库不上屏（KI-A2） |
| `showReadTitleAddition` | 已接 | 存储 `ReaderSettingsRepository.ets:451`（默认 `true`）、读 `:1044`/归一 `:1390`、写 `:1626`；面板 `ReaderSettingsPage.ets:1511`；`BackupRepository.ets:939` 导出、`:2132-2133` 恢复；上游全仓无渲染消费点，本地只落库不上屏（KI-A2） |
| `readBarStyle` | 已接 | 阅读栏样式默认 1，上游被 `BackupConfig.kt:216` 列入备份键；**由 KI-E1 一并接上、KI-E6 复核确认不重复实现**（`ReaderSettingsRepository.ets:372` 接口、`:775` 默认 1、`:928` 读、`:1453` 写，夹 0–2；面板 `ReaderSettingsPage.ets:2518`/`:886`/`:1028`；渲染 `ReaderPage.ets:1023 readerMenuBaseColor()`） |
| `readBarStyleFollowPage` | 已接 | **KI-E6 已实现**：存储键同名（默认 false），读 `ReaderSettingsRepository.ets:1041`、写 `:1623`；**上游没有任何 UI 发送点**（只有 `ReadBook.kt:724` 与 `ReadStyleDelegate.kt:446` 两个消费点 + `ReadConfig.kt:56` 只读快照）；本地 `ReaderPage.ets:1023 readerMenuBaseColor()` 由 `@Prop paperColor` 等响应式重算，语义天然等价，故只落库不上屏 |
| `moreActionsConfig` | 已接 | **KI-E6 已实现**：`ReaderSettingsRepository.ets:454` 接口、编解码 `:1896 encodeMoreActions`/`:1905 decodeMoreActions`；运行时真源仍是 `ReaderMoreActionsRepository`（独立 prefs，23 项），本字段是备份投影，`Index.ets:2134` 编码、`:3695-3696` 恢复解码并写回；**不在 `BackupConfig.readPrefKeys` 忽略清单里，随 `config.xml` 导出** |
| `autoChangeSource` | 不接 | 在线书源切换，[项目范围](../PROJECT.md)之外（KI-A5） |
| `defaultSourceChangeAll` | 不接 | 换源结果应用于全部书籍，同上（KI-A5） |
| `preDownloadNum` | 不接 | 章节预下载，依赖离线缓存子系统（KI-A11） |
| `preDownloadNumPrev` | 不接 | 同上（KI-A11） |
| `readUrlInBrowser` | 不接 | 跨应用跳转，需 browser skill（KI-A12） |
| `themeGridColumns` | 不接 | 本地背景面板是六方案列表而非网格，无消费面（KI-A10） |
| `optimizeRender` | 不接 | 上游只在 `Build.VERSION.SDK_INT <= Q` 分支生效，HOS 无对应老渲染管线（KI-A4） |
| `useNewTocSheet` | 不接 | 上游是「页内 Sheet / 独立目录页」二选一，本地固定独立目录页一态，无第二态可切（KI-A8） |
| `fontFolder` | 不接 | HOS 无法递归扫描任意用户目录；本地等价能力是系统字体枚举 + 导入到应用私有目录（KI-C6） |
| `volumeKeyPageOnPlay` | 不接 | 朗读期间的音量键行为；TTS 自 2026-11-09 起已纳入范围、尚未排期，等朗读接通后再补（KI-D3） |

## 二、改名映射表

下列上游字段在本地以不同名字落地，语义等价，**不属缺口**。命名不一致会给后续比对带来误判，记录在此。

**2026-11-01 逐条核对落库（第二轮）**：下表 18 行全部走完五项证据链——接口字段（`ReaderSettingsSnapshot`，`ReaderSettingsRepository.ets:143` 起）→ 默认值（`load()` 内 `const defaults`，`:728` 起）→ 读取（`store.get`）→ 写回（`store.put`）→ 至少一处消费端。**结论：18 行全部真落库**，没有一行只是「名字记在这儿」；其中 15 行是纯改名（语义等价、只是本地换了名），另外 3 行（`textColor`/`textColorNight`、`textSize` 标题侧、`bgStr`/`bgStrNight`）原本被记为「真缺口」，现分别由 KI-C1、KI-C4、KI-C2 补上同名或新名字段，也已落库。

**行号说明**：上一版表格里的行号是 2026-10-31 的旧值，此后 KI-A1..A12/C1..C6/D1..D6/E1..E6 陆续往 `ReaderSettingsRepository.ets` 里加了上百个字段，全部行号已下移。本表行号是 2026-11-01 用脚本按「接口声明行 / defaults 里六空格缩进的赋值行 / `store.get('键')` / `store.put('键')`」四种形态重新实测取的，可逐条 grep 复核。

核对时按**存储键**而非本地字段名查：`clickImgWay`/`tocUiUseReplace`/`tocCountWords`/`lineSpacingExtra`/`shadowColor` 五个的上游名就是本地存储键，`fontSize`/`pageAnimation`/`bottomItemsPerRow` 等则换成了本地名。

| 上游字段 | 上游位置 | 本地字段 | 本地位置 | 落库证据（接口 / 默认值 / 读键 / 写键 / 消费端） |
| --- | --- | --- | --- | --- |
| `textSize` | `ReadBookConfig.kt:246` | `fontSize` | `ReaderSettingsRepository.ets:145` | 默认 `:756`；读 `:944 store.get('fontSize')`；写 `:1498 put('fontSize')` 夹 5–50；消费 `Index.ets:4961`、`ReaderPage.ets:1406` 排版 |
| `textColor` / `textColorNight` | `ReadBookConfig.kt:55-56` | `textColor` / `textColorNight`（同名） | `ReaderSettingsRepository.ets:507`/`:509` | **原判「不属改名，是真缺口」，已于 KI-C1 补上。** 默认 `:903`/`:904` 取原硬编码值（`#38383B`/`#D8D8DC`）以免升级后观感突变；读 `:1079`/`:1080`；写 `:1669`/`:1670`；消费 `ReaderPage.ets:3957` 的 `readingTextColor` 与面板 `ReaderSettingsPage.ets` 的「日间/夜间文字颜色」色板 |
| `textSize`（标题侧） | `ReadBookConfig.kt:269` | `titleSize`（同名） | `ReaderSettingsRepository.ets:539` | **原判「真缺口」，已于 KI-C4 补上同名 `titleSize`（默认 4，夹 0–100）。** 配套 `titleSizeRelative`（`:545`，默认 `true`）决定语义：相对模式 = 正文字号 + `titleSize`，绝对模式 = `titleSize`（`ReaderPage.ets:2895`）。默认 `:921`/`:922`；读 `:1092`/`:1093`；写 `:1681`/`:1682`；消费 `ReaderPage.ets:2895`、面板 `ReaderSettingsPage.ets:552` 的「标题字号（正文 + n）」滑块与 `:1657` 的标签换算。原 9 处 `fontSize + 4` 硬编码已全部清除 |
| `lineSpacingExtra` | `ReadBookConfig.kt:252` | `lineSpacing` | `ReaderSettingsRepository.ets:147` | 默认 `:758`；读 `:946 get('lineSpacingExtra')`；写 `:1500 put('lineSpacingExtra')` 夹 0–20；消费 `Index.ets:4963` |
| `shadowColor` / `shadowColorN` | `ReadBookConfig.kt:543-544` | `textShadowColor` / `textShadowColorN` | `ReaderSettingsRepository.ets:159`/`:160` | 默认 `:770`/`:771`；读 `:958 get('shadowColor')`、`:959 get('shadowColorN')`；写 `:1512`/`:1514`；备份写出 `BackupRepository.ets:847`/`:849`、恢复 `:1994-1995`/`:1996-1997` |
| `pageAnim` | `ReadBookConfig.kt:201` | `pageAnimation` | `ReaderSettingsRepository.ets:204` | 默认 `:810`；读 `:995 get('pageAnimation')`；写 `:1567` 夹 0–5；消费 `Index.ets:5103` |
| `pageAnimSpeed` | `ReadBookConfig.kt:565` | `animationSpeed` | `ReaderSettingsRepository.ets:205` | 默认 `:811`；读 `:996 get('animationSpeed')`；写 `:1568` 夹 0–3；消费 `Index.ets:5104`、`ReaderPage.ets` 折算翻页时长 |
| `readMenuIconShowText` | `ReadBookConfig.kt:77` | `showBottomActionText` | `ReaderSettingsRepository.ets:181` | 默认 `:788`；读 `:977 get('showBottomActionText')`；写 `:1546`；消费 `Index.ets:1921`/`:2186`、`ReaderPage.ets:4460`（`showLabel`）与 `:4477`（底栏高度按是否显示文字在 64/48 间切换） |
| `readMenuIconStyle` | `ReadBookConfig.kt:100` | `bottomIconStyle` | `ReaderSettingsRepository.ets:182` | 默认 `:789`；读 `:978`；写 `:1547` 夹 0–2；消费 `Index.ets:1922`/`:2187`、`ReaderPage.ets` 底栏按钮样式 |
| `readMenuIconItemsPerRow` | `ReadBookConfig.kt:102` | `bottomItemsPerRow` | `ReaderSettingsRepository.ets:183` | 默认 `:790`；读 `:979`；写 `:1548` 夹 2–8；消费 `Index.ets:1923`/`:2188`、`ReaderPage.ets` 底栏分列 |
| `readMenuIconRowCount` | `ReadBookConfig.kt:103` | `bottomRowCount` | `ReaderSettingsRepository.ets:184` | 默认 `:791`；读 `:980`；写 `:1549` 夹 1–2；消费 `Index.ets:1924`/`:2189`、`ReaderPage.ets:4477` 底栏高度 |
| `bgStr` / `bgStrNight` | `ReadBookConfig.kt:537-538` | 新增同名 `bgStr` / `bgStrNight`；旧的 `dayPaperIndex` / `nightPaperIndex` 降级为「未自定义时的预设」 | `ReaderSettingsRepository.ets:520`/`:521`（新）；`:163`/`:164`（旧索引，现 `:165`/`:166` 一带） | **KI-C2 已补上同名 `bgStr`/`bgStrNight` 任意色串**：默认 `:909`/`:910` 为空串，读 `:1083`/`:1084`，写 `:1673`/`:1674`；消费 `Index.ets:4002` 的 `getPaperColor()`（先看自定义色再回落六方案）、装载 `:2010-2011`、下发 `:4989`。旧索引字段仍在：`BackupRepository.ets` 做索引↔色串互转 |
| `useUnderline` | `ReadSettings.kt:24` | `underline` | `ReaderSettingsRepository.ets:161` | 默认 `:772`；读 `:960 get('underline')`；写 `:1516`；消费 `ReaderPage.ets:3024`/`:3029`/`:3034` 驱动 `TextDecorationType`、`BackupRepository.ets` 备份 |
| `progressBarBehavior` | `ReadSettings.kt:27` | `progressBehavior` | `ReaderSettingsRepository.ets:187` | 默认 `:798`；读 `:983 get('progressBehavior')`；写 `:1552` 只认 `'chapter'` 否则 `'page'`；消费 `Index.ets:1927`/`:2192` |
| `clickImgWay` | `ReadSettings.kt:48` | `clickImageBehavior` | `ReaderSettingsRepository.ets:198` | 默认 `:804`；读 `:989 get('clickImgWay')`（**存储键仍写上游名**）；写 `:1558` 限 `['0'..'4']`；消费 `Index.ets:2042`/`:2250` |
| `tocUiUseReplace` | `ReadSettings.kt:62` | `tocUseReplace` | `ReaderSettingsRepository.ets:196` | 默认 `:802`；读 `:987 get('tocUiUseReplace')`；写 `:1556`；消费 `Index.ets:2040`/`:2248` |
| `tocCountWords` | `ReadSettings.kt:63` | `tocShowWordCount` | `ReaderSettingsRepository.ets:197` | 默认 `:803`；读 `:988 get('tocCountWords')`；写 `:1557`；消费 `Index.ets:2041`/`:2249` |
| `clickActionTL`…`clickActionBR` | `ReadSettings.kt:70-78` | `clickRegionActions` | `ReaderSettingsRepository.ets:199` | 默认 `:805` 取 `[...READER_CLICK_REGION_DEFAULTS]`；读 `:990 get('clickRegionActions')`（JSON）；写 `:1560` `JSON.stringify`；消费 `Index.ets:2043`/`:2251`、`BackupRepository.ets` 把 9 个整型键逐项转成动作标签。9 个整型字段 → 1 个 9 元素字符串数组 |

## 三、阻塞项与后续顺序

盘点结论指向三个互不重叠的缺口，按收益排序：

1. ~~**E 块菜单外观 4 行未接**~~ —— **2026-10-31 KI-E6 已全部处理**（菜单镜头半径/阅读栏样式跟随页面只落库不上屏，上游本就没有设置入口；阅读栏样式由 KI-E1 落库；更多操作配置补上 `ReaderSettingsRepository` 备份投影）。原描述：全部有控件无持久化（2026-10-31 底栏外观七行由 KI-E4、标题栏形态八行由 KI-E5、配色七行由 KI-E1、边框与模糊七行由 KI-E2、浮动图标四项由 KI-E3 接上，见复核段）。所需字段都是纯 UI 参数（颜色、圆角、模糊半径、玻璃开关），不触碰渲染引擎与排版算法，是唯一可以整块推进的部分，字段明细见 1.3 的「菜单」与「标题栏与图标」各组。前置条件：先在 `ReaderSettingsRepository.ets` 补齐字段与 `save` 分支，再把 `ReaderSettingsPage.ets` 的 `@State` 改为读仓储。可照抄同块已接的两条（`bottomActions`/`topActions`，`ReaderSettingsRepository.ets:804-805`）的链路。
2. ~~**C 块标题排版 14 项**~~ —— **2026-10-31 KI-C4 已完成**。当初估计的改动面正确（9 处 `fontSize + 4` 硬编码确实全部清除，`titleSizeRelative` 用显式 `boolean` 默认 `true` 等价覆盖上游 null 态）。实际风险点不在取值而在两处 UI：面板缺少可滚动容器、`ForEach` key 不含选中项，两处都已修（详见本节末段与 `docs/VALIDATION.md` 的 KI-C4 节）。
3. ~~**C 块正文与背景 6 行 + 下划线虚线 4 行**~~ —— **正文与背景 6 行已由 2026-10-31 KI-C1/KI-C2 完成**（11 个字段全部落库：正文日/夜颜色 2、正文强调色 2、背景透明度 1、背景自定义 4、白天暗色状态栏 2；`getReadingTextColor()` 的硬编码已改走 `textColor`/`textColorNight`，背景预设 `READER_BACKGROUND_STYLES` 降级为「自定义 `bgStr` 为空时的回退」）。**下划线虚线 4 行已由 2026-10-31 KI-C3 完成**：这四项不能用 `Text.decoration`（ArkUI 只开放 `type`/`color`/`style`/`thicknessScale`），改为 `ReaderPage.ets` 的 `ReaderUnderlineLayer` 用 `Line()` 逐行自绘，并把 6 处正文 `Text.decoration` 收敛为 `None`；滚动模式无行几何，仍用 Text 装饰（已知差异）。**2026-11-02 正文改画布逐行绘制后，Span 分支与 `ReaderUnderlineLayer` 已删除，下划线改由 `entry/src/main/ets/reader/ReaderCanvasSurface.ets` 的 `drawLineUnderline()` 用 `drawing.Pen` + `PathEffect.createDashPathEffect` 直接画在画布上，四项参数语义不变。**

三处阻塞已全部关闭（E 块于 2026-10-31 由 KI-E6 清零），明细表口径共 11 行未接，全部是单点开关。A–G 明细表的 11 行未接分布为：A 块 9 行、D 块 1 行、C 块 1 行，B/E/F/G 四块清零。（B 块已于 2026-10-31 复核清零；A 块同日因 KI-A7 接上 `sliderVibrator`/`selectVibrator` 由 21 减到 19、再因 KI-A6 接上 `autoSuggestDayNight` 减到 18、又因 KI-A3 接上 `disableReturnKey` 减到 17，再因 KI-A9 接上 `readBrightness` 减到 16，第八次因 KI-A1 接上正文渲染适配四项减到 12，第十四次因 KI-A2 接上菜单层依赖三项（`menuAlpha`/`showReadTitleAddition`/`showMenuIcon`）三行减到 9；E 块同日因 KI-E4 接上底栏外观六字段七行由 37 减到 30，又因 KI-E5 接上标题栏形态八行减到 22，第十次因 KI-E1 接上配色七行减到 15，第十一次因 KI-E2 接上边框与模糊七行减到 8，第十二次因 KI-E3 接上浮动图标四项减到 4，第十三次因 KI-E6 接上无上屏四项（其中阅读栏样式由 KI-E1 落库）减到 0；D 块先因 KI-D5 接上 `pageTouchSlop`/`readSliderMode` 由 10 减到 8，再因 KI-D6 接上 `lastMarkingStyle` 减到 7，第五次因 KI-D1 接上 `prevKeys`/`nextKeys`/`mouseWheelPage` 减到 5；第六次因 KI-D2 接上 `textSelectMenuConfig`/`expandTextMenu`/`showSelectMenuIcon` 减到 2，第七次因 KI-D4 接上 `doubleHorizontalPage` 减到 1C 块同日因 KI-C5 接上 `chineseConverterType` 由 2 减到 1，再因 KI-C1/KI-C2 接上正文与背景 6 行由 25 减到 19，第三次因 KI-C4 接上标题排版 14 行由 19 减到 5，第四次因 KI-C3 接上四个下划线几何参数由 5 减到 1），余下均为单点占位开关，不单独列阻塞。字段口径的 112 项见 1.3，与这里的行数不可相加。

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

`feature/reader/legacy/LegacyReaderChapterPaginator.kt`（406 行，`:132` `titleMode: Int = ReadBookConfig.titleMode`）、`LegacyReaderPageDecorationFactory.kt`（340 行）、`LegacyReaderPaginationStyleFactory.kt`（119 行）、`LegacyReaderStyleRangeMapper.kt`（428 行，`:337` 注释「即 `ReadBookConfig.textColor`，不是写死的主题绿」）、`model/FullBookPaginator.kt`（97 行，`:48` `tipHeaderLeft`）、`model/ReadSessionState.kt`（45 行，`:32` `durConfig.curBgDrawable`）、`domain/model/settings/ReadStyleState.kt`（42 行，`:10` 只投影排版底座）、`model/ReadBook.kt`（在 4.1 已分配，此处单列说明它是阅读页模型）。

**排除理由**：这些是 Compose 自绘管线的分页与装饰实现，本地对应物是 `pages/ReaderPage.ets` 的 ArkUI 声明式渲染（无「分页器」「装饰工厂」这种中间层）。上游把配置读在管线内部，本地读在页面里，**同一批配置项在 A–G 块已有行**，此处不重复列行。

### 4.3 已排除：数据层接线与初始化，界面由别处承载（10 个）

`di/appModule.kt`（862 行，`:374` 把 `ReadBookConfig.titleMode` 注入 provider）、`domain/usecase/AddBookUseCase.kt`（80 行，`:17` 注入 gateway）、`domain/usecase/ChangeBookSourceUseCase.kt`（249 行，`:76` 注入 gateway）、`data/repository/SearchContentRepository.kt`（321 行，`:26` 注入 gateway）、`help/book/BookExtensions.kt`（747 行，`:54` `readGateway`）、`help/book/BookHelp.kt`（1116 行，`:75` `readGateway`）。

**排除理由**：`ReadSettingsGateway` 的注入点，没有自己的界面。它们消费的配置项在 A–G 块已有行（换源相关在 A 块、搜索内容在 D 块）。

另有 4 个同类，但各有额外分量，单列在这里：

- `App.kt`（385 行，`:132` `ReadBookConfig.initialize(...)`）——**应用启动时初始化配置**。本地对应 `entryability/EntryAbility.ets` 里 `RdbMigration`/`RdbCleanup` 之后由 `pages/Index.ets` 载入 `ReaderSettingsRepository`，无独立界面。
- `data/entities/Book.kt`（515 行，`:280`/`:282` 读 `ReadBookConfig.pageAnim` 作为按书翻页动画的回落）——**实体层的配置回落**。本地对应 `model/Book.ets` 的 `readConfig` JSON 字段，已在 [BOOKSHELF.md](BOOKSHELF.md) B 块「阅读配置覆盖」行记录。
- `help/storage/Backup.kt`（406 行，`:94-95`/`:233`/`:237` 备份 `configFileName` 与 `shareConfigFileName`）与 `help/storage/Restore.kt`（609 行，`:347` 恢复 `configFileName`）——**配置文件的备份与恢复**。本地对应 `data/BackupRepository.ets` 的 `config.xml` 读写，归备份模块，不在本表。

### 4.4 已排除：属别的 ZIP 类别（16 个）

朗读 10 个：`ui/book/read/ReadAloudDelegate.kt`（676 行）、`model/AudioPlay.kt`（481 行）、`service/HttpReadAloudService.kt`（2149 行）、`service/readaloud/ReadAloudBookSession.kt`（279 行）、`help/readaloud/cast/CastRenderOptions.kt`（104 行，`:102` `bound.contains(ReadBookConfig.durConfig.name)`）、`ui/book/audio/AudioPlayViewModel.kt`（370 行）、`ui/book/readaloud/ReadAloudPlayerMorphHost.kt`（306 行）、`ui/book/readaloud/casting/CastBubbleSheet.kt`（80 行，`:61` `textSize = ReadBookConfig.textSize`）、`ui/book/readaloud/player/ReadAloudConfigIntentMapper.kt`（145 行）、`ui/book/readaloud/player/ReadAloudPlayerViewModel.kt`（335 行）。朗读自 2026-11-09 起**已纳入范围、尚未排期**（[PROJECT.md](../PROJECT.md) `:24-44`），归 `httpTTS` 类别。

漫画 3 个：`ui/book/manga/MangaReaderViewModel.kt`（1500 行）、`ui/book/manga/MangaSettingsPanel.kt`（862 行）、`data/repository/manga/MangaReaderActionRepository.kt`（259 行）。归 `mangaConfig` 类别。

其余 3 个：`ui/main/MainNavGraph.kt`（2041 行，`:1063` `initReadBookConfig(initRequest)` 只是导航参数传递，归导航）；`model/webBook/BookChapterList.kt`、`model/webBook/BookContent.kt`（网络书内容加载，归 `bookSource`）。

### 4.5 已排除：本地书与导出，界面由别的模块承载（6 个）

`model/localBook/LocalBook.kt`（649 行）、`model/localBook/TextFile.kt`（519 行）、`help/book/ContentProcessor.kt`（297 行）、`service/ExportBookService.kt`（1010 行）、`help/DefaultData.kt`（143 行，`:55` `readConfigs` 默认配置预设）、`help/JsExtensions.kt`（1220 行，`:1191` `getReadBookConfig()` 是书源脚本接口）。

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
- `ui/config/ConfigTag.kt`（11 行，`const val READ_CONFIG = "readConfig"`，同类还有 `THEME_CONFIG`/`COVER_CONFIG`/`BACKUP_CONFIG` 等 6 个）——**配置页面的路由标签常量**，不是备份逻辑。本地对应 `pages/` 下各设置页的路由名，无独立界面。
- `constant/PreferKey.kt`（521 行）——靠三个界面字段名关键词进接触面：`:498` `object ReadMenuBlurMode`、`:504` `object ReadMenuBlurStyle` 两个枚举在这里定义（E 块「顶栏模糊样式」「底栏模糊样式」的取值域），`expandTextMenu`/`showSelectMenuIcon`/`lastMarkingStyle` 三个 `const val` 键常量也在这里。**它是 readConfig 全部偏好键的常量表**，本表 A–G 各行的「上游位置」列凡是引用 `PreferKey.xxx` 的都落在这里。

这三个文件都是靠「类别键名字面量 / 字段名」而非配置类名被捞到的，正是 [KEYWORDS.md](KEYWORDS.md) 存储层维度要解决的漏检。`BackupConfig.kt` 与 `PreferKey.kt` 此前从未出现在 `readConfig` 的覆盖证明里，但它们分别是该类别忽略开关与偏好键的唯一定义处。

### 4.9 渲染管线与目录页：r323 补关键词后新进接触面（12 个）

这批文件是 2026-11-03 补 `ReaderPageWindow`/`ReaderPaginator`/`ReaderChapterBlockMeasurer`/`ReaderPaginationSession`/`ReaderPartialPagePolicy`/`ScrollPageDrawCache`/`TocScreen`/`TocHierarchy`/`TocViewModel` 九个关键词后才进接触面的。补词的原因与逐文件证据见 [KEYWORDS.md](KEYWORDS.md) 的「为什么原关键词漏掉渲染管线与目录页」节。

**它们不在本表开行，落点在 [TXT-READER.md](TXT-READER.md)。** 本表盘的是配置项（「哪个设置字段接了没有」），这批文件盘的是**排版快照的消费端与界面状态**——它们读的是已经算好的 `ReaderPageWindow`、`ReaderChapterPaginationStyle`、`TocUiState`，**不出现任何配置类全名、也不出现配置字段名**。同一个配置项（如标题字号）的「有没有这个设置」在本表 C 块已有行，「设了之后排版流怎么用它」在 TXT-READER.md B9 块。

| 上游文件 | 行数 | 为什么不进本表 | TXT-READER.md 落点 |
| --- | --- | --- | --- |
| `feature/reader/core/layout/ReaderChapterBlockMeasurer.kt` | 771 | 读排版期快照 `ReaderChapterPaginationStyle`（把配置翻译成快照的工厂 `LegacyReaderPaginationStyleFactory.kt` 在 4.2 已排除） | B1 全部测量行 + B2 图片三档 + **B9 全部 10 行** |
| `feature/reader/core/navigation/ReaderPageNavigator.kt` | 284 | 页窗口导航，读 `ReaderPageWindow`，无配置 | B3「四页预取窗口」+ B8 ⑨ + D7「跨章定位」 |
| `feature/reader/core/navigation/ReaderPartialPagePolicy.kt` | 132 | 流式页发布策略，读页位置不读配置 | B8 ⑪「增量发布策略」 |
| `feature/reader/core/model/ReaderPageContentClip.kt` | 90 | 绘制裁剪，读已算好的 bounds | B4「绘制顺序」「覆盖阴影」 |
| `feature/reader/core/accessibility/ReaderAccessibilityPolicy.kt` | 22 | 无障碍补偿，读视口不读配置 | C1「隐藏状态栏后正文默认留白」 |
| `feature/reader/core/gesture/ReaderPageViewportLayout.kt` | 70 | 视口分区，读尺寸不读配置 | B1「视口≤0 不排版」+ D2 翻页手势视口分区 |
| `feature/reader/core/readaloud/ReaderVisibleTextPositionPolicy.kt` | 81 | 朗读高亮定位，业务属 `httpTTS` | B6「页眉页脚与角标绘制」的可见文本定位 |
| `feature/reader/ScrollPageDrawCache.kt` | 67 | 整页 PixelMap LRU 缓存 | B3「滚动模式整页 PixelMap 缓存（容量 8 的 LRU）」 |
| `ui/book/read/ReaderRenderUiState.kt` | 54 | 首帧保护状态，无配置字段 | C1「首帧保护」 |
| `ui/book/read/sheet/ReaderBookSheet.kt` | 1433 | 阅读页内的目录/书签/笔记四页签面板 | C5 全部 16 行 + 新增 6 行 |
| `ui/book/toc/TocScreen.kt` | 1259 | 全屏目录页 | C5「粘性卷头」「自动滚到当前章」「FAB 四项」+ 新增「目录列表惰性加载」 |
| `ui/book/toc/TocHierarchy.kt` | 86 | 卷层级与反序算法 | C5「卷折叠」+ 新增「反序在数据源层一次反转」 |

**排除理由**：与 4.2 同性质——上游把配置读在管线内部，本地读在页面里，同一批配置项在 A–G 块已有行；这些文件带来的**新问题**（跨章闪烁、标题与正文分离、目录慢）不是配置问题，已按 [PARITY-RULES](../PARITY-RULES.md) 第四节「盘点单位是界面」在 TXT-READER.md 新开 B8/B9 两块与 C5 六行登记。

**本轮接触面变化的完整账**：关键词 105 → 122（+17 个文件，其中 12 个落本表 4.9、5 个落 4.1/4.2 已有清单：`feature/reader/ReaderCanvasSurface.kt`、`core/model/ReaderPage.kt`、`ui/book/read/ReadBookController.kt`、`ReadBookRouteScreen.kt`、`ui/book/read/sheet/HighlightRuleEditSheet.kt`），加白名单 2 个 = **124**。实跑：`上游接触面 124 / 已分配 124 / 未分配 0 / 通过`。

---

## 维护

改本表时同步改两处：

- `entry/src/main/ets/data/ReaderSettingsRepository.ets` 的字段定义——本表「本地位置」一列直接引用其行号。
- [ZIP 兼容总账](STATUS.md) 的 `readConfig` 行——本表是它的明细表。

改完本表须重跑「盘面」与第一节的计数，两处数字必须与实际表格行数闭合。

新增上游字段时先跑第一节的复核命令，确认是「真缺失」还是「改名已接」再落表，避免把改名误记为缺口。
