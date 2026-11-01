# 验证记录

## 验证等级口径

本仓库对每项能力只承认三级证据，**下级不得写成上级**。判定时先看证据属于哪一级，再决定措辞。

| 级别 | 含义 | 可写的措辞 | 不可写的措辞 |
| --- | --- | --- | --- |
| 1 源码接入 | 代码已写入目标工程，行为有明确调用方，但未编译或未上机 | 「源码已接入」「未构建」 | 「已实现」「已修复」 |
| 2 构建通过 | 目标工程 `assembleHap` 通过，且已覆盖安装到设备 | 「构建通过」「覆盖安装成功」 | 「设备验收通过」 |
| 3 设备验收 | 在设备上按目标操作走完闭环，并记录到达证据与失败排除 | 「设备验收通过」 | — |

**只有第 3 级可以写「通过」。** 第 2 级能编译不代表功能正确：历史缺陷中有构建通过但键名字面量写错、备份写入顺序错、恢复漏字段、保存失败仍更新缓存等情形，全部卡在第 2 级与第 3 级之间。
设备不可用时记「未验」，不得补写通过，也不得以本机模拟器结果代替目标设备结论。

## 设备与 OCR 操作规范

本节适用于已给出具体目标操作的模拟器导航和交互验收；目标操作仍写作「〔待填写〕」时不连接或点击设备。执行前从 [CURRENT.md](CURRENT.md) 读取当前模块，确定要到达的页面与可用文字标志。

1. **选设备**：目标设备已写明时使用其当前序列号。未写时先分别执行 `adb devices`、`hdc list targets`，只考虑在线设备；不可沿用旧记录中的序列号。若 Android、HarmonyOS 或同类设备同时在线，只在当前任务能唯一确定目标应用和设备时自动选择，否则只询问一次设备。两套工具的序列号不可混用。命令不在 PATH 时先解析 SDK 中的 `adb.exe` / `hdc.exe`，已核对的位置见 [构建说明](BUILDING.md)，运行时仍须确认。
2. **识别再点击**：先获取当前屏幕的 OCR 文本、位置和置信度，确认当前页面；找目标文字时结合标题、邻近文案及屏幕区域消歧。同名目标仍不唯一时停止，不点第一个候选。点击位置必须来自本轮 OCR 的文字框或自动化工具的文本点击，不复用历史坐标。
3. **点击后验证**：每次点击后重新 OCR，等待目标页面特有的标题或文字组合出现，并检查相关旧状态是否消失。发出点击、动画开始或截图文件生成均不算到达目标；在设定超时内未得到明确证据就停止。多步导航自动重复这一循环，无需每步向用户确认。
4. **截图与失败**：中间截图仅在本机临时保存和供 OCR 使用，不在成功路径展示、上传或加入常规答复。只有 OCR 无法识别、目标状态无法判定或操作失败时才展示对应失败截图，并说明设备、已识别文字、期望状态和卡住的步骤；若连截图也取不到，明确说明截图不可用。不得以固定坐标盲点作为失败后的替代路径。

Android 使用 `adb-screen-detection` 技能的截屏、OCR 查找和点击脚本；运行前检查脚本所需 Python 包、ADB、Tesseract 与中文识别能力，工具或语言包缺失属于操作阻塞，先说明缺失项，不把它记成应用页面失败。

HarmonyOS 使用 HMNextAuto：从 `hdc list targets` 取得序列号后显式创建 `Driver(serial)`；先用 OCR 识别当前界面，再按文本消歧并点击，最后用等待文本或再次识别判断是否到达。文本点击返回成功只说明找到了文字并发出点击，不能代替目标状态验证。

每次源码或资源变更后，按风险执行一次必要构建；设备可用时安装到明确的目标设备，保存关键截图或录像。设备不可用时记录「未验」，不能补写通过。文本与文档重组后检查链接、空白和引用路径。

页面还原的具体操作步骤见 [UI 还原流程](UI-RESTORE.md)。

## 2026-11-01 N 端 r302 深色模式阶段三：日夜提醒（E1–E6）与 D7 冷却复位

- 设备：HOS 模拟器 `127.0.0.1:5555`（API 26，HarmonyOS 7.0.0），包名 `io.legado.harmony`，构建产物 `entry/build/default/outputs/default/entry-default-unsigned.hap`（`assembleHap` 两次通过，40 s 254 ms / 26 s 373 ms）。
- **本轮性质**：E 块代码在 r302 之前就已存在于仓库（`pages/Index.ets` 的传感器订阅与判定、`pages/ReaderPage.ets` 的提醒胶囊、`pages/ReaderSettingsPage.ets:1495` 的真开关、`data/ReaderSettingsRepository.ets` 的持久化），但 `docs/parity/ZIP-THEME.md` 的 E1–E7 七行一直写着「未接」，是盘点滞后。本轮**只补 D7 的一处代码**，其余是回填 + 设备取证。
- **改了哪些**：`pages/Index.ets` 的 `toggleReaderNightMode()` 开头补上上游 `ReadStyleDelegate.kt:451-482 toggleDayNight()` 的三件事——把 `readerDayNightReminderLastAt` 置为当前时刻（冷却从这次手动切换算起）、清掉 `readerDayNightReminderDismissedDark`/`DismissedLight` 两个拒绝标记、把 `readerDayNightReminderRequestId` 加一（作废在途的 5 秒隐藏定时器），并清空 `readerDayNightReminderText`。`pages/ReaderPage.ets:4823` 把提醒层全屏容器的 `.hitTestBehavior(HitTestMode.Default)` 改为 `HitTestMode.None`（Default 会让这层在提醒弹出的 5 秒里拦住整屏点击）。
- **前置条件（复验必须照做）**：`legado_theme` 的 `themeMode` 必须是 `"1"`（浅色）。若留在 `"2"`，`applyThemeMode` 会把 `readerNightMode` 重新算成 `true`，`checkReaderDayNightReminder` 的「非夜间分支」永远进不去，胶囊不会弹。这是本轮第一次取证失败的原因，记在这里免得下次重踩。

### 验收①胶囊弹出与 5 秒自动消失

- 操作：改 `legado_reader_settings` 的 `autoSuggestDayNight=true`、`readerNightMode=false`，改 `legado_theme` 的 `themeMode="1"`，重启应用 → 书架 → 点 `np-test` 封面 `(127,1088)` 进阅读页，随后连续 `uitest dumpLayout`。
- 预期：进页后提醒胶囊出现，约 5 秒后自动消失。
- 实际：第 1–4 轮 dump 都读到「当前环境光较暗，是否切换至深色模式？」`bounds [114,2307][934,2360]` 与「关闭」`[1074,2307][1166,2360]`，第 5 轮起消失。**通过**。

### 验收②点胶囊左侧 → 切到深色并落盘

- 操作：胶囊出现后立刻点左半 `(524,2333)`。
- 预期：`legado_theme` 的 `themeMode` 由 `"1"` 变 `"2"`，阅读页变深色。
- 实际：`.pwork_cap.sh` 轮询到胶囊后立即点击，点前 `themeMode">1<`，点后 `themeMode">2<`，截图确认阅读页正文与面板转深色。**通过**。这是 r297/r299 两轮都没能取证的那一条。

### 验收③点「关闭」→ 本轮不再弹（E5 拒绝标记）

- 操作：胶囊出现后点右侧「关闭」`(1120,2333)`，然后等 14 秒不再操作。
- 预期：胶囊立即消失；此后 14 秒内（远超 5 秒显示窗口，仍在 10 分钟冷却内）不再弹；`themeMode` 保持 `"1"` 不切。
- 实际：胶囊 1 秒内消失；等 14 秒期间轮询均未再读到提醒文案；`themeMode` 仍 `"1"`。**通过**。

### 未验与回归归因

- **阅读页正文单击唤菜单：未验（工具限制，非本轮引入）**。本轮一度怀疑是 `ReaderPage.ets:4823` 的 `hitTestBehavior` 改动导致，用 `git stash` 把 `Index.ets`/`ReaderPage.ets` 两处改动暂存、构建 HEAD 版本（`BUILD SUCCESSFUL in 40 s 861 ms`）后重测，**现象完全一致**——中心 `(640,1400)`、`(640,660)`、`(640,700)`、`(640,1500)`、`(640,2600)` 与右三分格 `(1100,1400)` 全部无响应，页脚仍是 `1/3`。归因结论：该模拟器对阅读页正文区的单击/滑动注入不稳定，与 `docs/KNOWN-ISSUES.md` 既有的「模拟器上正文单击经常不触发」属同一环境问题，不是本次改动引入。stash 已 pop 回，构建恢复为带改动的版本（`BUILD SUCCESSFUL in 40 s 502 ms`）。
- **与上游的四处差异（如实记录，未消除）**：① 上游 `ReadBookRouteScreen.kt:1088-1138` 是「每 15 分钟一轮、每轮注册监听 1 秒取 `finalLux` 后注销」，本地 `Index.ets:2700-2711` 是 `sensor.on` 常驻订阅（`interval: 1000000000` ns = 1 秒一次回调），没有 15 分钟节流；② 上游按 `bgType/bgStr`（含夜间一套）与 `backgroundMeanColor` 判底色，本地只有 `getPaperColor()` 单值 + 亮度阈值 0.35，**没有背景图均值色这一支**；③ 上游有 `reminderQueue` 排队，本地只有单个 `readerDayNightReminderText`；④ 上游 `toggleDayNight()` 会顺带清队列里的 DayNight 提醒，本轮 D7 已补上「重置冷却 + 清拒绝标记 + 作废在途定时器」等价动作。

## 2026-11-01 N 端 r301 深色模式阶段二第一批：护眼六项（A24–A29）设备验收通过

- 设备：HOS 模拟器 `127.0.0.1:5555`（API 26，HarmonyOS 7.0.0），包名 `io.legado.harmony`，构建产物 `entry/build/default/outputs/default/entry-default-unsigned.hap`（`assembleHap` 两次通过，43 s 356 ms / 44 s 862 ms）。
- **改了哪些**：新建 `entry/src/main/ets/data/EyeProtection.ets`（逐句移植上游 `ui/book/read/EyeProtection.kt` 的 9 个二次拟合系数、`temperatureForIntensity`、`matrixValuesForIntensity`、`parseTime`、`isActiveAt`，另加 `overlayColorForIntensity` 把矩阵对角线转覆盖色）；`pages/Index.ets` 把 `isEyeProtectionActive()` 改为调 `EyeProtection.isActiveAt`，根 `Column` 上的 `.sepia(...)` 换成根 `Stack` 顶层一层 `blendMode(BlendMode.MULTIPLY)` 纯色覆盖层；`pages/ThemeSettingsPage.ets` 护眼组六个控件由 `onUnavailableAction` 改为 `@Prop` + 回调，与阅读设置页共用 `Index.ets` 同一份状态。
- **为什么 blendMode 不是近似**：上游矩阵 `[red,0,0,0,0, 0,green,0,0,0, 0,0,blue,0,0, 0,0,0,1,0]` 除对角线外全 0，是纯对角矩阵；`BlendMode.MULTIPLY` 的公式是 `result = 内容 × 覆盖色`，逐通道相乘与对角矩阵乘法数学等价。这是 F3「ArkUI 无 `AppCompatDelegate` 等价物、必须换机制而不是照抄」的一次具体落法。

### 验收①启用护眼模式 → 全 App 泛暖

- 操作：我的 → 设置 → 外观 → 护眼模式 → 打开「启用护眼模式」。
- 预期：整屏偏暖；`legado_reader_settings` 的 `eyeProtectionEnabled` 变 `true`。
- 实际：开关变开，整屏立刻泛暖；prefs 由 `bool eyeProtectionEnabled=false` 变 `true`。像素取样（同一坐标）：改前 `(245,246,248)`，改后 `(255,187,122)`。按上游系数在强度 50 处算出的理论值为 `(255,187,121)`，**实测与理论只差 1**（JPEG 量化误差）。**通过**。

### 验收②色温强度 → 暖色随强度加深

- 操作：在护眼组把「色温」滑块由 50 拖到约 97。
- 预期：`eyeProtectionIntensity` 变 97；屏幕更暖；文案由「强度 N」变「当前生效：N」。
- 实际：prefs 的 `double eyeProtectionIntensity` 由 `50.000000` 变 `97.000000`；屏幕明显更暖；行尾文案变为「当前生效：97」。**通过**。

### 验收③深色模式时自动开启 → 只随深色生效

- 操作：关掉「启用护眼模式」、只开「深色模式时自动开启」；先在浅色下截图，再切到深色截图。
- 预期：浅色不生效（像素不变），深色生效（泛暖）。
- 实际：浅色下取色 `(254,255,255)`（未泛暖）；切深色后取色 `(17,13,10)`（明显泛暖）。**通过**。
- 说明：这一支在 r301 之前就读了 `autoNight` 但没用，本轮由 `EyeProtection.isActiveAt` 的 `enabled || (autoNight && isDark)` 正式接上，与上游 `EyeProtection.kt:52-78` 同构。

### 验收④定时开启 → 区间外不生效

- 操作：打开「定时开启」，保持默认 22:00–07:00，在 14:16 截图。
- 预期：当前不在区间内，覆盖层不挂。
- 实际：开始/结束两行出现；整屏取色回到未泛暖的基色，与「定时关闭时」一致。**通过**。

### 验收⑤起止时间选择器 → 真能改

- 操作：点「开始时间」→ 弹时间选择器 → 滚到 14:00 → 确定。
- 预期：`eyeProtectionStartTime` 变 `14:00`。
- 实际：选择器弹出且默认停在 22:00；改成 14:00 确定后，prefs 的 `string eyeProtectionStartTime` 变 `14:00`，行尾 detail 同步显示 `14:00`。**通过**。

### 验收⑥跨零点区间 → 14:00–07:00 立即生效

- 操作：起止改为 `14:00`–`07:00`（跨零点），在 14:20 截图。
- 预期：跨零点分支命中，覆盖层生效。
- 实际：覆盖层生效，取色 `(25,20,14)`，色温行显示「当前生效：97」。**通过**。

### 踩坑记录

覆盖层最初用 `.width('100%').height('100%')` 直接贴在根 `Stack` 上，只染到内容区，状态栏与底部手势条保持原色（截图可见两条未染的横带）。加 `.expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])` 后整屏一致。另加 `.hitTestBehavior(HitTestMode.None)` 保证覆盖层不吃点击。

### 复原状态

`legado_reader_settings` 已复原为 `eyeProtectionEnabled=false`、`eyeProtectionAutoNight=false`、`eyeProtectionSchedule=false`、`eyeProtectionIntensity=50`、`eyeProtectionStartTime=22:00`、`eyeProtectionEndTime=07:00`。模拟器系统显示模式仍是「浅色」，应用 `legado_theme` 停在 `themeMode="0"`。

## 2026-11-01 N 端 r300 深色模式阶段一：全局 themeMode 与两套颜色资源（设备验收通过）

- 设备：HOS 模拟器 `127.0.0.1:5555`（API 26，HarmonyOS 7.0.0），包名 `io.legado.harmony`，构建产物 `entry/build/default/outputs/default/entry-default-unsigned.hap`（9503748 字节，`assembleHap` 于 13:33 通过）。
- **改了哪些**：新建 `entry/src/main/ets/data/ThemeSettingsRepository.ets`（preference 名 `legado_theme`）与 `entry/src/main/ets/data/ThemeModeResolver.ets`；`pages/Index.ets` 加 `@State themeMode: string` / `@State themePaletteIndex: number` 与唯一写入点 `applyThemeMode`；`pages/ThemeSettingsPage.ets` 三个 `ThemeModeItem` 改真回调；`entryability/EntryAbility.ets` 在 `loadContent` 后 `setColorMode` 并监听 `'environment'`；新建 `entry/src/main/resources/dark/element/color.json` + 扩写 `base/element/color.json`（各 9 键成对），34 个 `.ets` 文件共 926 处颜色字面量换成 `$r('app.color.*')`。

### 验收①主题页点「深色」→ 全 App 立刻变深、杀进程重进仍深

- 操作：我的 → 设置 → 外观 → 主题模式 → 点「深色」。
- 预期：整页立刻变深；`legado_theme` 里 `themeMode = "2"`；`aa force-stop` 后重进仍是深色。
- 实际：点「深色」后同一屏（外观页）由浅底 `#F5F6F8` 系变为深底 `#111217` 系，标题、卡片、说明文字、色卡边框全部翻转，选中态从「跟随系统」移到「深色」；`/data/app/el2/100/base/io.legado.harmony/haps/entry/preferences/legado_theme` 内容为 `<string key="themeMode">2</string><double key="paletteIndex" value="0.000000"/>`；`aa force-stop` 后重进停在首页，首页仍是深色（最近阅读卡、今日阅读目标、底栏全部深色）。**通过**。

### 验收②阅读页点日夜按钮 → 退出到书架，书架也深

- 操作：书架 → 打开 `np-test` → 点中间唤出菜单 → 齿轮进「阅读界面」面板 → 点「背景」行右侧月亮图标 → 关闭面板 → 返回书架。
- 预期：`legado_theme` 由 `themeMode="2"` 变 `"1"`；退出阅读页后书架整页变浅。
- 实际：点月亮图标后阅读页正文与面板配色即时翻转为浅色（月亮图标变太阳图标），`legado_theme` 变为 `<string key="themeMode">1</string>`；返回书架，书架顶栏、分组标签、封面阴影、底栏全部由深转浅。**通过**。
- 说明：阅读页正文纸张色本身仍由 `paperIndex` 决定（`READER_BACKGROUND_STYLES` 两套），全局 `themeMode` 只驱动「是哪一套」——这与上游「`themeMode` 是日夜唯一来源、背景另有一套配置」的口径一致。

### 验收③themeMode 设「跟随系统」→ 系统切深色全 App 跟着变

- 操作：主题页点「跟随系统」→ 进系统设置 → 显示和亮度 → 显示模式点「深色」→ 回到应用；再把系统切回「浅色」→ 回到应用。
- 预期：`legado_theme` 为 `themeMode="0"`；系统切深色时应用跟着变深，切回浅色时跟着变浅。
- 实际：点「跟随系统」后 `legado_theme` 变为 `<string key="themeMode">0</string>`，此时系统为浅色，应用保持浅色；系统切「深色」后回到应用，外观页整屏变深、选中态回到「跟随系统」；系统切回「浅色」后回到应用，整屏恢复浅色。**通过**。

### 验收④preferences 里读得到 themeMode="2"

- 操作：`hdc shell cat /data/app/el2/100/base/io.legado.harmony/haps/entry/preferences/legado_theme`。
- 实际：三档模式分别读到 `"2"`、`"1"`、`"0"`，与主题页选中态一一对应；`paletteIndex` 始终为 `0`（本轮只接了 themeMode，调色板仍只落盘不改配色，见 ZIP-THEME.md A2）。**通过**。

### 构建踩坑记录

`entry/src/main/ets/data/ThemeModeResolver.ets:28` 首版写成 `configuration.colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK`，报 `10505001 ArkTS Compiler Error`：`'@ohos.resourceManager'.default.ColorMode` 与 `'@ohos.app.ability.ConfigurationConstant'.default.ColorMode` have no overlap。`resourceManager.getConfigurationSync()` 返回的是 `resourceManager.Configuration`，其 `colorMode` 属于 `resourceManager.ColorMode`（`DARK=0`/`LIGHT=1`），必须 `import { resourceManager } from '@kit.LocalizationKit'` 后比 `resourceManager.ColorMode.DARK`。改完 `BUILD SUCCESSFUL in 53 s 682 ms`。

### 复原状态

模拟器系统显示模式已切回「浅色」；应用 `legado_theme` 停在 `themeMode="0"`（跟随系统）+ `paletteIndex=0`。本轮只改代码与资源，未动设备上的书籍与阅读偏好。

## 2026-10-29 N 端 r260 高亮预设导入与划线笔记渲染（通过）

- 设备：HOS 模拟器 `127.0.0.1:5555`（API 26），包名 `io.legado.harmony`，书籍 `vol-test2`（本地 TXT，6 章）。
- **预设面板**：阅读页 → 顶栏更多操作 → 「高亮规则」→「预设规则」。11 条内置预设全部列出，已存在的同 id 规则显示「已有」且勾选框禁用；`title_emphasis_default` 显示「标题规则，本地暂不执行」并默认不勾。说明文案与实际行为一致。
- **规则启停文案刷新**：切换「旁白说明」开关后条目文案由「正文规则 · 已停用」即时变「正文规则 · 已启用」，无需重进面板。
- **滚动模式划线渲染（修复前 0 像素）**：`pageAnimation=3` 下背景高亮标记渲染出 3848 绿色像素；把标记改为波浪下划线后，绿色像素降为 606，裁剪图确认是「她」字下方的波浪线，位置与标记区间一致。
- **笔记列表文案刷新**：笔记页 → 编辑 → 把效果由「背景高亮」改为「波浪下划线」并保存，列表标签即时由「背景高亮」变为「波浪线」。
- **删除标记**：在标记编辑面板点「删除」并确认，存储 `legado_reader_markings` 的 `records` 变为空，列表显示「暂无笔记」，返回阅读页后划线像素归零（491 → 0）。
- **分页模式回归**：`pageAnimation=0` 下划线仍正常渲染（491 绿色像素），预设规则底色也正常显示。
- 本记录只代表 N 端模拟器结果，不替代 E 端结论，也不代表 API 12 真机兼容。

## 2026-10-29 N 端 r262 书签与笔记 ZIP 备份与恢复（通过）

- 设备：HOS 模拟器 `127.0.0.1:5555`（API 26），包名 `io.legado.harmony`。预置 1 条书签（`vol-test2` 第一章）与 1 条笔记（`mk-test-1`，effect=wave、color=#00FF00、note=笔记乙）。
- **备份侧**：设置 → 备份与恢复 → 备份 → 备份到本地 → 保存 `backup2026-10-29.zip`（6276 字节）。解压得 8 个根条目，其中 `bookmark.json` 1123 字节、`bookMarking.json` 562 字节，UTF-8 中文正常，字段与上游 `Bookmark.kt` / `BookMarking.kt` 一致，`anchorJson` 与 `styleJson` 为序列化字符串。**结论：备份写出通过。**
- **恢复侧**：清空 `legado_reader_markings` 后冷启确认「所有书签」页显示「1 条书签 · 0 条笔记」。走「备份与恢复 → 恢复 → 从本地恢复 → 选 backup2026-10-29.zip → 导入此 ZIP」，预览显示「识别 8 个根条目；书架 5 本」且 `bookmark.json 1 条`、`bookMarking.json 1 条`。导入后提示原文：`导入完成：保留 8 个 Android 条目；更新 5 本已有正文书籍的进度，并创建 0 本缺正文书目；替换净化规则覆盖 3 条。TXT 目录规则覆盖 27 条。高亮规则新增 9 条。书签与笔记新增 1 条、覆盖 1 条。`
- **恢复后存储校验**：`legado_reader_markings` 写回 `records`（`mk-test-1|...`，`chapterPos` 由 20 变为 26，说明合并时按导入内容覆盖）；`legado_reader_bookmarks` 同样写回。冷启动后「所有书签」页显示「1 条书签 · 1 条笔记」。**结论：合并语义与双条目先合并后落盘均通过。**
- 本记录只代表 N 端模拟器结果，不替代 E 端结论，也不代表 API 12 真机兼容。

## 2026-10-29 N 端 r259 高亮规则 ZIP 备份与恢复（通过）

- 设备：HOS 模拟器 `127.0.0.1:5555`（API 26），包名 `io.legado.harmony`。预置两条规则（`hl_test_1` pattern=占位 textColor=-65536；`hl_test_2` pattern=测试 enabled=false bgColor=-16711936）写入 `legado_reader_highlight_rules` 后冷启。
- **备份侧**：设置 → 备份与恢复 → 备份 → 备份到本地 → 保存 `backup2026-10-29.zip`。解压得 6 个根条目，其中 `highlightRule.json` 1349 字节，两条规则字段完整、与上游 `HighlightRule` 同名同义，`position` 按 0/1 重排。**结论：备份写出通过。**
- **恢复侧**：构造 `restore-hl.zip`，内含 3 条规则——`hl_import_1` pattern=占位（与本地 `hl_test_1` 同 pattern）、`hl_import_2` pattern=新增关键字、`hl_import_3` pattern=`[`（坏正则）。预览显示「识别 1 个根条目；`highlightRule.json` 3 条」。点「导入此 ZIP」后提示「导入完成：保留 1 个 Android 条目；更新 0 本已有正文书籍的进度，并创建 0 本缺正文书目；高亮规则新增 1 条、覆盖 1 条、跳过 1 条无效规则。」
- **恢复后存储校验**：`legado_reader_highlight_rules` 共 3 条——`hl_test_1` 保留原 id、name 被覆盖为「覆盖同名规则」、textColor 变为 -16776961（同 pattern 覆盖生效）；`hl_test_2` 原样保留（本地独有规则未被删除）；`hl_import_2` 新增，position=2。坏正则 `hl_import_3` 未进入存储。**结论：合并语义与跳过逻辑均通过。**
- 本记录只代表 N 端模拟器结果，不替代 E 端结论，也不代表 API 12 真机兼容。

## 2026-10-28 N 端 r258 阅读正文高亮规则设备验收（通过）

- 在 HOS 模拟器 `127.0.0.1:5555`（API 26）完成面板可达、创建、正文命中、停用、冷启读回、滚动模式连续滚动与删除七项闭环，全部通过。详细步骤与像素数据见 `history/evidence/reader-highlight-rules-n-device-2026-10-28.md`。
- 修复滚动模式下高亮完全不生效：规则变化未递增 `readerContentRevision`，导致内容 `ForEach` 复用旧节点。修复后滚动模式红色像素由 0 变为 6596，连续滚动三次稳定在 6379–6567。
- 修复规则条目启停后文案不刷新：`ForEach` key 只用 `rule.id`，改为 `ruleItemKey()` 覆盖启停等可变字段。
- 分页模式回归通过（红色像素 5720）。测试规则已删除，设备偏好 `legado_reader_highlight_rules` 回到空数组。
- 本记录只代表 N 端模拟器结果，不替代 E 端结论，也不代表 API 12 真机兼容。

## 2026-10-28 E 端 r258 阅读正文高亮规则（源码接入，设备验收未完成）

- 新增 `ReaderHighlightRule` 模型、Preferences 仓储和 HOS 正则引擎，接入 `ReaderPage` 的分页 glyph 与连续滚动文本渲染；阅读页内高亮规则入口改为打开独立规则面板，不再路由到标签抽取规则页。
- 限制正则长度 256 UTF-16 字符、章正文 150000 UTF-16 字符、规则 64 条，并拒绝常见嵌套重复/重复分支/重复反向引用；没有硬超时保证，不宣称完整 Java Pattern 兼容。
- Hvigor `assembleHap` BUILD SUCCESSFUL；33 项任务中 15 项执行、18 项为最新；HAP 未签名。
- HOS 模拟器 `127.0.0.1:5555` 保留数据覆盖安装成功，打开本地 TXT 到第 1 章正文并通过系统返回恢复首页；首页书籍进度仍显示 0%。
- **规则面板未在设备上成功打开**，因此未创建临时规则，也未验证正文样式、启停、冷启读回或滚动模式表现。设备阅读会话期间首页统计卡读数发生变化，没有手动写入或清理阅读统计。
- HMNextAuto `Driver.create` 连接被重置，改用 HDC UI 树、坐标与本机 Tesseract OCR 继续检查；这不代表规则面板验收通过。
- 本记录不代表 API 12 真机兼容。未上传 HAP、测试记录、截图或日志。

## 2026-10-28 E 端 r257 书架状态说明

- Hvigor `assembleHap` 构建成功；33 项任务中 17 项执行、16 项为最新。ArkTS 保留既有异常处理/弃用 API 告警；未配置发行签名。
- r257 稳定快照同步到独立公开副本后，执行 Entry clean 与 `assembleHap`；34 项任务全部执行，构建成功。公开副本产生的 HAP 仅供编译验证、被 Git 忽略且未上传；没有签名配置。
- `entry@ohosTest` Hypium 测试 HAP 单独构建成功；此处只验证测试目标可编译，未安装或运行测试用例。
- HOS 模拟器覆盖安装并启动，原本地应用数据保留。设备没有自定义分组，因此分组卡片新增的私有标记/刷新状态文案未直接显示验证。
- 本记录不代表 API 12 真机兼容。未上传 HAP、测试记录、截图或日志。

## 2026-10-28 E 端 r256 隐藏页签切换

- Hvigor `assembleHap` 构建成功；覆盖安装时保留本地应用数据。
- 在书架启用隐藏分组页签后，打开分组管理，从可用筛选中切换到“本地未分组”；管理面板关闭且书架筛选同步更新。随后恢复默认页签与“全部”筛选，强停冷启动后仍保持。
- 设备没有自定义分组，故只验证内置筛选项。分组排序、私有访问控制、按组刷新与 API 12 真机未验证。

## 2026-10-28 E 端 r255 Android ZIP 类别门控

- 创建兼容备份时从空 `config.xml` map 开始；`readConfig` 门控阅读设置键，`themeConfig` 单独门控护眼六键；恢复时也按各自类别分别应用。
- E 端 HOS 模拟器验证两类分别包含/忽略的四种组合，确认一类被忽略时另一类仍按备份恢复，且忽略项保留本机状态；最后重新导入双包含归档恢复基线。
- 四种恢复均按忽略类别保护本机书架、分组和规则数据；操作结束后回到双包含基线。
- 此结果只验证类别门控路径；未逐个解包核对 XML 原文、外部 Android ZIP、书架布局九字段差异值往返或 API 12 真机。

## 2026-10-28 E 端 r251–r254 阅读设置增量

- r251 系统字体选择与持久化在 HOS 模拟器检查；r252 两端/底部对齐状态冷启动读回并观察到排版行为变化。
- r253 正文粗斜体、阴影及下划线基础设置接入源码，完成构建和保留数据覆盖安装；设备即时效果在该轮未逐项验收。
- r254 检查阴影/下划线颜色、下划线显示效果及冷启动读回，随后恢复默认显示状态。实际 TTF/OTF 文件导入、CJK fallback、EPUB 字体、高亮规则与 API 12 真机仍未验。

## 2026-10-28 E 端 r250 书架布局与 v15 书目字段

- 独立公开副本执行 Entry clean 与 `assembleHap`，Hvigor 34 项任务全部执行，构建成功。ArkTS 有既有异常处理/弃用 API 警告；未配置签名，生成的 HAP 仅用于本地编译验证并受 Git 忽略。
- E 端 HAP 重建并覆盖安装，既有用户数据保留；旧 v14 书目在 v15 源码下仍显示。
- HDC+OCR 检查布局设置后，切换到列表并设置列表列数为 1，强制停止应用后冷启动，读回状态为 `list/list column=1`；随后恢复默认网格。
- 书架 v15 将 `latestChapterTime`、`durChapterTime`、`order` 写入索引 30/31/32，并继续兼容 v1–v14。
- 书架设置落入本地偏好；Android ZIP `config.xml` 映射采用 `bookshelfLayoutPortrait`。本轮未完成每项设置的逐项读回、全量排序数据检查及 ZIP 导入导出往返。
- 未验证分组自定义排序在所有书目数据上的结果、隐藏空分组和各项布局字段的完整矩阵，也未验证 API 12 真机兼容。
- 测试后已恢复默认网格；不公开测试书名、设备地址、截图、日志、HAP 或备份文件。

## 2026-10-28 E 端 r245 书架分组与 r243 正文选择验证

- E 端 HAP 重建、覆盖安装后使用 HDC+OCR 检查分组管理/编辑、排序菜单、刷新设置和“私有”标记保存/读回；测试分组已清理。
- 封面图片的实际选择与冷启动读回、网格卡片拖拽、分组排序实际改变书架列表、私有分组访问控制未验证；刷新设置当前仅确认保存/读回，未证明会改变刷新行为。
- r243“允许选择正文”已接入正文设置、Preferences 和 ReaderPage；E 端检查了开关持久化和正文选择行为。
- 本次 E 端事实不使用 N 端 API 26 模拟器证据；API 12 真机兼容仍未验证。测试分组、书名、设备地址、截图和 HAP 未上传。

## 2026-10-28 E 端 r242 跨午夜汇总与标注/书签检查

- r242 在阅读记录汇总视图按 `ReadRecordDetail.date` 分组；阅读时间线仍按会话开始时间所在日期分组，单条会话不拆段。
- E 端隔离 HOS UI 样例验证按记录日期分日显示；真实跨午夜记录持久化、重启后的日期归属仍未在 E 端验收。
- E 端重建并安装 HAP，之后清理测试夹具。跨行文本选区、标注样式与备注 CRUD、目录定位/冷启动，以及书签新增、编辑、冷启动、定位和删除流程通过；书签/标注两种删除顺序互不影响。
- 本次记录不包含测试书名、截图或 HAP。N 端 API 26 测试不作为 E 端证据，API 12 真机兼容仍未验证。
- 阅读记录启用偏好契约为 `legado_read_records.enabled` 字符串 `'1'`/`'0'`；不要改成布尔值或另造 `enabled_v1` 键。

## 2026-10-28 E 端阅读记录三层整合（r241 检查点）

- E 端 r241 HAP 构建、覆盖安装与冷启动通过。旧 v1 本地阅读记录迁移到会话层后，重启未重复迁入；实际 TXT 阅读后产生的新会话记录可读回。
- 取消清空确认后记录保留；阅读记录开关恢复启用后状态保留。公开记录不包含书名、具体阅读时刻、设备标识或本机日志。
- 三层仓储会话、按日明细和按书汇总已接线；迁移按会话键去重，先重建派生层再清理旧键。源码还包含超长记录截断、逐行损坏恢复和缺失派生数据重建修正，这些修复不代表所有异常路径均经 E 端验证。
- E 端尚未验证跨午夜 HOS 日期持久化、扫描提示/修复、字数统计、书籍别名合并或 API 12 真机。N 端 API 26 的测试属于 N 端，不能作为 E 端验证。
- 共享页面包含开发中的阅读标注/笔记代码；本次仅按稳定检查点同步必要共享依赖，不宣称该功能完成。
- Android ZIP 的三类阅读记录文件仍作为兼容归档保留，未映射到原生三层仓储。

## 2026-10-28 N 端补充验证（不替代 E 端验收）

范围说明：本节记录的是 N 端 OpenHarmony API 26 模拟器上的公开 `main` 复测结果。**它是对 E 端验收的补充输入，不构成 E 端验收通过，也不改变 KNOWN-ISSUES 中遗留项的状态。**

### 已观察到通过

- TXT 目录规则页：既有 26 条规则在覆盖安装后完整保留，启停状态保留，列表渲染正常。
- TXT 目录规则页交互：排序、选择模式（反选、批量启停、批量导出、批量删除带二次确认）、长按菜单（置顶/置底/删除）、文件导入与导出、导入内置规则均可达且表现符合预期。
- 分卷场景：带「第一卷/第二卷」标题的临时 TXT 导入后切出 6 章，目录页卷头显示折叠箭头、卷内章节缩进一级，折叠交互可用。
- 替换净化页：分组页签、条目开关、长按菜单（置顶/置底/删除）表现正常。
- 备份侧：应用备份 ZIP 含 7 个根级条目，`replaceRule.json`（608 B）与 `txtTocRule.json`（9409 B）均正确写出；E 端新增的 `bookGroup.json` 也在其中。
- 恢复侧：自造的合成 ZIP（各含 1 条 `replaceRule.json` 与 `txtTocRule.json`）预览正确识别 2 个根条目，导入后提示两类规则各新增 1 条，冷读存储确认两条规则均已写入。

### 仍未验证（沿用 KNOWN-ISSUES 的边界）

- 书架「更新目录」只在 N 端模拟器上走过一遍，**E 端设备验收仍未做**（KNOWN-ISSUES 第 1 项）。
- TXT 目录规则的编辑、删除、排序、批量启停/删除**完整组合**未逐项覆盖（第 2 项）。
- **非空规则的应用备份再恢复**未做全往返；本次恢复用的是合成 ZIP 单条规则，与应用内已有非空规则时的备份-恢复链路不是同一路径（第 3 项）。
- API 12 真机兼容未验证（第 4 项）。
- 本次全部操作只发生在本机模拟器；未触碰 E 端设备，未清空任何应用数据。

## 2026-10-28 E 端 TXT 目录规则验证

- E 端整合源码构建并覆盖安装成功。导入内置 27 条规则后重启，规则仍保留；TXT 目录规则 JSON 导出后重新导入通过。
- 用临时自定义规则导入 TXT，分卷识别、卷头折叠和阅读进度持久化通过；临时规则与测试数据已清理。
- 合成 Android ZIP 的根级 `txtTocRule.json` 单条规则恢复后冷启动读回通过；规则为空时的应用备份也已读回。
- 本轮结束后原有书架条目和阅读进度仍保留；不在公开文档中列出书名或本机记录。
- 书架序列化保留 E 端 v13 分组/元数据；v14 将 `chapterVolumes`/`tocRule` 写入字段索引 28/29，解析器同时兼容 N 端旧 v13/v14 的索引 27 规则字段。
- 检查使用 HDC 与本地 OCR。HMNextAuto `Driver.create` 返回 WinError 10054；Android ADB shell/截屏曾超时，故未用这些自动化方式作更广的 UI 验收。
- 尚未在 E 端验证书架“更新目录”、完整 CRUD/批量操作、含非空规则的应用备份恢复；API 12 真机也未验。

日期：2026-10-28。记录与公开导出对应的工程快照。

## 2026-10-28 替换净化规则空状态检查

- E 端整合源码构建并覆盖安装到 HOS 后，通过 OCR/HDC 进入“我的→替换净化”空列表状态。
- 本次 E 端检查仅确认入口和空状态可达；没有创建规则，也没有做规则文件导入/导出或 ZIP 规则恢复全往返。
- 本地代码已实现规则 JSON 映射、冲突合并、无效正则跳过和空规则数组备份；这些实现不等同于 E 端全流程已验收。
- E 端未验证恢复结果提示的标点细节；API 12 真机兼容仍未验证。

本次公开副本 clean 构建结果另见下方公开基线构建条目；未签名 HAP 不作为发行文件。

## 2026-10-27 公开基线构建

- 在独立公开副本清理 Entry 旧构建输出后，使用 DevEco 附带的 Hvigor 入口执行 clean 和 assembleHap。
- 构建结果为 BUILD SUCCESSFUL；共 33 项任务，21 项执行，12 项为最新。
- ArkTS 编译有既有异常处理和弃用 API 警告；未出现编译错误。Hvigor 提示没有 signingConfig。
- 生成的 HAP 未签名，仅留在被 Git 忽略的本机构建目录；未作为安装包提交或发布。
- 本次未进行设备安装、API 12 真机或整页 UI 验收。具体模块范围见 MODULE-STATUS.md。

## 既有构建记录（历史，不表示本次重跑）

- DevEco Studio 26.0.0.851 / SDK 26；历史 `assembleHap` 构建成功。
- 历史模拟器记录不代表当前功能验收；任何 N 端 API 26 结果均不作为 E 端或 API 12 兼容证据。
- 配置的 compatible/target SDK 是 HarmonyOS `5.0.0(12)`。API 26 模拟器运行不能证明 API 12 真机兼容。
- 旧的全量工程内含未签名 HAP 构建产物，本仓库导出已排除所有构建输出。本次未将这些历史产物作为发布包。
- 以上设备记录来自原工程的历史工作；不代表 API 12 真机兼容，也不代表新功能全部回归。

## 2026-10-30 关系型存储迁移第五批 preferences 清理（设备验收部分完成）

- 构建：`assembleHap` 通过（`BUILD SUCCESSFUL in 31 s 260 ms`，33 项任务 17 执行 / 16 最新），无编译错误；WARN 全部是既有的「Function may throw exceptions」与弃用 API 提示。
- 设备：HOS 模拟器 `127.0.0.1:5555`（API 26），包名 `io.legado.harmony`。**清理与结构两项已设备确认，书签/划线两项未验**（原因见本节末尾），故本节整体不写「通过」。
- **范围**：`docs/RELATIONAL-STORE-MIGRATION.md` 第 5 阶段。搬迁此前只复制不剪切，老 `preferences` 全留；本批照上游 `SharedPreferencesMigration` 默认删源文件的语义把已迁走的键删掉。
- **上游依据**：上游 `SettingsRepository.kt:34-37` 用 `SharedPreferencesMigration(context, "${context.packageName}_preferences")`，其 `cleanUp()` 默认实现删掉源 SharedPreferences 文件；只有 `LocalUiStatusMigration`（`SettingsRepository.kt:56`）显式写 `override suspend fun cleanUp() = Unit` 才保留。本地此前「13 个键全留 + 8 处兜底读 preferences」对应的正是那个特例写法。
- **新增 `data/RdbCleanup.ets`**：标记键 `rdb_cleanup_v1_1`（preferenceName `legado_rdb_cleanup`），只删一次。**r290 修掉漏删后已提到 `rdb_cleanup_v1_2`**，见本节末尾「r290 修补」。前置检查要求三个搬迁标记 `rdb_migrated_v1_1` / `v1_2` / `v1_3` 全部为真，否则直接返回——**不会误删未搬的数据**。失败只 `console.error` 吞掉，不写标记、不阻塞启动，下个版本重试。
- **删除清单**：整文件删 9 个（`legado_reader_bookmarks`、`legado_reader_markings`、`legado_reader_search_history`、`legado_txt_toc_rules`、`book_group_store`、`legado_reader_highlight_rules`、`legado_book_content_processes`、`legado_local_books`、`legado_read_time_records`）；按键删 2 组（`legado_read_records` 删 `sessions_v1` 保留 `enabled`、`legado_replace_rules` 删 `rules_v1` 与 `book_overrides_v1` 保留 `default_enabled_v1` 与 `sort_mode_v1`）。保留下来的三项都有上游依据：`ReadRecordRepository.kt:78-80` 的 `readRecordEnabled`、`PreferKey.replaceEnableDefault`、`PreferKey.replaceSortMode` 在上游也都放偏好而非表。
- **连带改动一：老扁平记录搬迁挪位**。`ReadRecordRepository.migrateLegacy`（原先由 `pages/Index.ets` 的 `restoreReadTimeRecords` 在首屏调用）整体换成 `migrateLegacyInto(context, store)`，由 `RdbMigration.migrateThirdBatch` 调用。原因：清理会删掉 `legado_read_time_records`，搬迁必须排在清理之前。新版不开事务、不写标记、不清老键（这些原本也由 RdbMigration 与 RdbCleanup 统一管），并抽出 `rewriteDerived(store, sessions)` 供 `rebuildDetailsAndSummaries`、`migrateFromPreferences`、`migrateLegacyInto` 三处共用。
- **连带改动二：八个仓储删「回退 preferences」兜底**。`ReaderBookmarkRepository`、`ReaderMarkingRepository`、`ReaderSearchHistoryRepository`、`TxtTocRuleRepository`、`BookGroupRepository`、`ReaderHighlightRuleRepository`、`BookContentProcessRepository`、`BookRepository` 的 `load()` 在 DB 读失败时不再回读 preferences，改为记日志 + 返回空表/空数组。理由：上游 DAO 读不到就是空表，抛异常会让界面崩。`loadFromPreferences` / `loadLegacy` 方法本身保留，搬迁路径仍要读老数据。
- **连带改动三：`book_overrides_v1` 搬进 `books.readConfig.useReplaceRule`**（上游存 `Book.config.useReplaceRule`，`Book.kt:482`）。`Book` 模型加 `useReplaceRule?: boolean`，`StoredReadConfig` 加同名字段并在 `toBookArgs` / `readBookRow` 双向读写（`undefined` 被 `JSON.stringify` 丢掉，正好对应上游 `null` = 跟随默认）。`ReplaceRuleRepository.isBookEnabled(book)` 改为纯函数，照抄上游 `Book.getUseReplaceRule(defaultReplaceEnabled)`（`Book.kt:250-262`）：有显式值用它，没有则图片类与 epub 本地书返 false，其余跟随全局默认。`setBookEnabled` / `clearBookEnabledOverride` 去掉了 `context` 与 `async`，只改内存对象，落库交给 `BookRepository.saveImportedBooks` —— `ReplaceRuleRepository` 不能 import `BookRepository`（反向已存在，会循环依赖）。`pages/Index.ets` 两个入口同步改为「改对象 + 整表 upsert」，`resetReaderReplaceToDefault` 的取值由 `getDefaultEnabled()` 改为 `isBookEnabled(this.selectedBook)`，因为图片类与 epub 即使跟随默认也是关闭净化。
- **设备实测：清理生效**。启动后读取设备 preferences 目录，文件数由 16 降到 7，与删除清单完全吻合。9 个整文件删除全部生效（`legado_reader_bookmarks`、`legado_reader_markings`、`legado_reader_search_history`、`legado_txt_toc_rules`、`book_group_store`、`legado_reader_highlight_rules`、`legado_book_content_processes`、`legado_local_books`、`legado_read_time_records` 均已消失）；按键删除同样正确——改动替换规则排序方式后 `legado_replace_rules` 重新出现，但只带回 `sort_mode_v1`，`rules_v1` 与 `book_overrides_v1` 没有被写回。`legado_rdb_cleanup` 里已写入标记 `rdb_cleanup_v1_1`（值 `1793354547247`），`legado_rdb_migration` 的三个搬迁标记 `v1_1` / `v1_2` / `v1_3` 也都在。
- **设备实测：需要保留的键都留着**。留下的 7 个文件是 `legado_android_backup_options`、`legado_bookshelf_layout`、`legado_first_run`、`legado_rdb_cleanup`、`legado_rdb_migration`、`legado_read_records`、`legado_reader_settings`，与「不删的」清单一致。
- **设备实测：库结构完好**。`legado.db` 拉回本地用 Python 注册 `LOCALES` collation 后查得 14 张表全部建出：`books` 2 行、`chapters` 6 行（`url` 为 16 位 MD5，`start` / `end` 为字节偏移 `0→3628→7256→10852→14480→18108→21736`，`wordCount` 全为 `1211字`）、`readRecord` 1 行、`readRecordDetail` 1 行、`readRecordSession` 10 行，其余业务表为 0。`books.readConfig` 内容为 `{"reSegment":false,"fixedType":false}`，**没有 `useReplaceRule` 键**——两本书都没设过按书开关，符合「`undefined` 被 `JSON.stringify` 丢掉 = 跟随全局默认」的设计。
- **发现的写入遗漏**：`legado_read_records` 里仍留有 `details_v1` 与 `summaries_v1` 两个键（`RdbCleanup.ets:101` 只删了 `sessions_v1`）。这两个键存的是第三批之前的老格式按日明细与书籍汇总，第三批起已改存 `readRecordDetail` / `readRecord` 两表，全仓 `.ets` 已无任何读取点。**已于 r290 修掉**（见本节末尾）。
- **未验项**：① **书签与划线的写入未验**——`bookmarks` 与 `book_marks` 至今 0 行，无法确认这两张表在新代码下的写入路径；原因是模拟器上长按选词手势不可触发（详见下条），不是应用缺陷。② 按书净化开关「关掉一本书 → 冷启 → 仍关闭」的闭环未上机走。③ 老扁平记录改成搬迁阶段写入后，`readRecordSession` 是否与旧路径逐行一致未做新旧比对（本轮只读到 10 行，未与旧版 HAP 的数据对照）。④ 真机 `getRdbStore` 仍是第一批遗留未验项。
- **模拟器限制（影响走查手法，非应用缺陷）**：阅读页正文的长按选词在模拟器上不可触发。本轮唯一一次成功弹出选词菜单（复制 / 书签 / 划线·笔记）后，点「书签」也弹出了「添加书签」面板，但保存按钮点击落在面板外导致未入库；此后 12 次循环探测、5 个不同纵坐标、重启、双击、慢速拖拽、`uinput -T` 触摸轨迹、菜单开合状态下长按全部无法复现。`uitest uiInput longClick` 稳定返回 `No Error`，但**返回码不能当作手势被识别的证据**，必须 dump 层级或截图确认。这与第一批记录（`docs/VALIDATION.md` 的 r281 节）的结论一致：该页正文走滚动模式，长按划词在模拟器上一直不可靠。后续验书签/划线应改走「数据层直接构造 + 渲染像素比对」（r281 已用此法验证划线渲染），或改在真机上走 UI 闭环。
- 本记录只代表模拟器结果，不替代真机结论。

### r290 修补：补删两个残留键

批次验收时发现的写入遗漏已修掉，未做设备验收（纯删除清单变更，构建通过即可）。

- `entry/src/main/ets/data/RdbCleanup.ets` 的删除清单由 `['sessions_v1']` 改为 `['sessions_v1', 'details_v1', 'summaries_v1']`，并加注释说明后两个是第三批之前的老格式、代码里已无读取点。
- `markerKey` 由 `rdb_cleanup_v1_1` 提到 **`rdb_cleanup_v1_2`**。这一步不可省：v1_1 标记已经写在设备上，只改删除清单的话设备会直接跳过清理，那两个键永远留着。
- 构建：`assembleHap` 通过（`BUILD SUCCESSFUL in 8 s 809 ms`，33 项任务 17 执行 / 16 最新）。
- 预期效果：升级后首次启动应把 `legado_read_records` 里的 `details_v1` / `summaries_v1` 删掉，`enabled` 保留，`legado_rdb_cleanup` 的标记值改为新时间戳。**该项未上机复验**。

## 2026-10-30 关系型存储迁移第三批（通过）

- 设备：HOS 模拟器 `127.0.0.1:5555`（API 26），包名 `io.legado.harmony`。`assembleHap` 通过（`BUILD SUCCESSFUL in 26 s 511 ms`，33 项任务 17 执行 / 16 最新），HAP 覆盖安装成功。
- **范围**：`docs/RELATIONAL-STORE-MIGRATION.md:330` 的第三批两个仓储 `ReadRecordRepository`（669 行）、`BookRepository`（1602 行）由 preferences 整表序列化改为 relationalStore。`RdbSchema.version` 由 2 升到 3，追加五张表 DDL（`books` 35 列 PK `bookUrl`、`chapters` 18 列 PK `(url, bookUrl)`、`readRecord` 5 列、`readRecordDetail` 8 列、`readRecordSession` 8 列自增主键，逐列对齐上游 `132.json`）与 4 条索引（`books` 2 条、`chapters` 2 条）。`Book` 模型删除 8 个字段：`coverColor` / `coverMark`（改为 `bookCoverColor(book)` / `bookCoverMark(book)` 运行时派生）、`bodyMissing`（改 `BookRepository.isBodyMissing`）、`fileSizeBytes`、`readerPositionVersion`，以及 `chapterTitles` / `chapterOffsets` / `chapterVolumes`（章节彻底拆进 `chapters` 表）。
- **章节拆表后的同步访问器靠缓存**：上游用 Room，`BookChapterDao.getChapterList` 同步返回；relationalStore 只能异步读。为此 `BookRepository` 增加 `chapterCache`（`bookUrl → BookChapter[]`），`saveChapters` / `deleteChapters` / `loadChapters` 负责维护，页面侧改用 `cachedChapterTitles` / `cachedChapterOffsets` / `cachedChapterVolumes` / `cachedChapters` 四个同步访问器；`CatalogPage` / `ReaderSearchPage` / `ReaderPage` 各自在 `aboutToAppear` 里 `loadChapters` 预载一次。这是本批唯一一处「不等价于上游」的实现，其余全部照上游语义。
- **字节偏移必须实测，不能换算**：`chapters.start` / `end` 存**字节**偏移（上游 `TextFile.kt` 用 `RandomAccessFile.seek(start)`）。中文 1 字 3 字节、emoji 4 字节、ASCII 1 字节，任何乘除换算都会错。搬迁时 `buildLegacyChapterRows` 用 `charOffsetsToByteOffsets` 逐字符累加，读取时 `readChapter` 按字节切片再解码。设备实测 `chapters` 6 行的 `start` / `end` 为 0/3628、3628/7256、7256/10852、10852/14480、14480/18108、18108/21736，末值等于源文件字节数 21736，**核对通过**；正文渲染中文与 `Hello World，你好世界。` 均正常，说明切片的编码边界没有跨字符。
- **存量搬迁（第一轮，破坏性验证）**：先用 git worktree 构建的**旧版 HAP**（HEAD `d31920a`）卸载重装并造出真实数据（导入 `test-book.txt`、读若干段、产生 2 条阅读会话），再覆盖安装新版触发搬迁。搬迁后拉库比对：`books` 1 行（`type=264` 即 text 8 + local 256、`group=0`、`totalChapterNum=6`、`latestChapterTitle='第一章 出发'`、`readConfig='{"imageStyle":"DEFAULT","reSegment":false,"fixedType":false}'`、`origin='loc_book'`、`canUpdate=1`）、`chapters` 6 行、`readRecordSession` 4 行、`readRecord` 1 行、`readRecordDetail` 1 行。三个标记 `rdb_migrated_v1_1` / `v1_2` / `v1_3` 全部写入（`v1_3=1793349136731`）。实际会话数比 preferences 基线多 2 条，原因是老版本在卸载前又读了两段（时间戳 1793348880251 早于搬迁标记），属正确行为。
- **只搬会话，派生层重算**：`ReadRecordRepository.migrateFromPreferences` 只读 `sessions_v1`，`details_v1` / `summaries_v1` 不搬，改由 `computeDerived` 用同一份算法重算后再写两张派生表。`enabled` 开关留 preferences，与上游一致。
- **`saveImportedBooks` 语义变更**：第二批起改成纯 upsert（`INSERT OR REPLACE` 逐本写 `books` 行），不再整表重写。因此**删除必须显式删行**——`BookRepository.deleteBook` 在一个事务里先 `DELETE FROM chapters WHERE bookUrl = ?` 再 `DELETE FROM books WHERE bookUrl = ?`（**外键 `ON DELETE CASCADE` 在 relationalStore 上实测不生效**，前置验证阶段删书后章节行仍在、`left=2`，故必须手动删），末尾清 `chapterCache`。`Index.ets` 的 `removeLocalBookFromShelf` 先调 `deleteBook` 再 `saveImportedBooks`。
- **本轮修掉的缺陷**：`removeLocalBookFromShelf` 原先只调 `saveImportedBooks`（纯 upsert），从书架移除的书在 `books` / `chapters` 表里残留，重启后由 `loadBooksFromDb` 读全表又回弹。照上游 `DeleteBooksUseCase.kt:13-26`（先 `deleteChaptersByBook` 再 `deleteBooks`）补 `BookRepository.deleteBook`。设备实测：删前 `books=1 / chapters=6`，删后 `books=0 / chapters=0`，重启后书架仍为空不回弹；重新导入同一本书 `books=1 / chapters=6`，导入链路未受影响。
- **UI 走查（第二轮，全部通过）**：
  - **阅读记录**：汇总视图「1 本书 / 9 分钟」，按日「2026-10-30 / 9 分钟」，按书「test-book / 本地 TXT / 9 分钟」，与 DB 的 `readTime=568065` 毫秒（≈9.5 分钟）吻合。
  - **正文与目录**：打开书正文中文渲染正常；点目录按钮打开章节列表，点「第二章 相遇」正确跳转，页码与进度联动。
  - **删除书籍**：长按书架卡片进详情页 → 点「移出书架」→ 二次确认 → DB 两表归零。
  - **备份导出**：我的 → 设置 → 备份与恢复 → 备份 → 备份到本地，导出 `backup2026-10-30.zip`（2951 字节，落在 `/storage/media/100/local/files/Docs/Documents/`）。ZIP 内 10 个根条目，`bookshelf.json` 含 `totalChapterNum:6`、`durChapterIndex:2`、`durChapterPos`、`type:264` —— **导出读的是 `books` 表新字段，未回退 preferences**。
  - **备份恢复（实际执行，非仅预览）**：同页 → 恢复 → 从本地恢复 → 选中该 ZIP → 预览页显示「识别 10 个根条目；书架 1 本，其中本地书籍 1 本 / ZIP 不含 TXT/EPUB 正文」→ 点「导入此 ZIP」→ 显示「导入完成：保留 10 个 Android 条目；更新 0 本已有正文书目的进度，并创建 1 本缺正文书目」。书架上出现「缺正文」标记的占位书，进入详情页正确显示「已恢复书目与阅读位置，缺少正文文件」「Android 原路径：local-1793348394426.txt」并给出「移出缺正文…」「查看目录」「换源」「阅读记录」四个操作；DB 里该书 `bookUrl='local-1793348394426.txt'`（原始路径而非正文路径），`durChapterIndex=2`，`chapters` 表无它的行 —— 与「缺正文」语义一致。
- **冷启动幂等与停写 preferences（决定性验证）**：连续两次 `aa force-stop` + `aa start` 后 `rdb_migrated_v1_3` 的值不变（仍 1793349136731），不重复搬迁。`/data/app/el2/100/base/io.legado.harmony/haps/entry/preferences/` 下 `legado_local_books`（16:19）与 `legado_read_records`（16:30）的 mtime 停留在搬迁完成时刻，经过两次冷启动加一次备份导入后**均未再变化**，说明新版本确实不再写这两个 preferences 文件，**存储对齐判据达成**。
- **模拟器环境与操作坑（非应用缺陷，供后续参考）**：`uitest uiInput click X Y` 传物理像素，坐标须用 `uitest dumpLayout` 读 `attributes.bounds` 定位而非目测截图；`uitest uiInput keyEvent Back` 在页面内可能直接退出应用，改用点返回箭头；`snapshot_display` 两次截图 sha256 相同即表示点击未生效；文件选择器里点文件名会直接关闭选择器，须在预览面板出现后**向下滚动**才能看到「导入此 ZIP」按钮。
- **未验项**：① 真机上 `getRdbStore` 仍未验（第一批遗留，本批未变）；② 真机上的备份导出 / 导入未验（本轮全部为模拟器结果）。
- 本记录只代表模拟器结果，不替代真机结论。

## 2026-10-30 关系型存储迁移第二批（通过）

- 设备：HOS 模拟器 `127.0.0.1:5555`（API 26），包名 `io.legado.harmony`，书籍 `vol-test2`（本地 TXT，6 章）、`test-toc`。`assembleHap` 通过（`BUILD SUCCESSFUL in 30 s 13 ms`，33 项任务 17 执行 / 16 最新），HAP 覆盖安装成功。
- **范围**：`docs/RELATIONAL-STORE-MIGRATION.md:322` 的第二批五个仓储 `BookGroupRepository`、`ReaderHighlightRuleRepository`、`BookContentProcessRepository`、`TxtTocRuleRepository`、`ReplaceRuleRepository` 由 preferences 整表序列化改为 relationalStore。`RdbSchema.version` 由 1 升到 2，追加五张表 DDL（逐字照抄上游 `132.json`）与 6 条索引（`replace_rules.id`、`book_content_processes` 三条）。`RdbCodec` 新增 `real` / `optionalReal`。
- **REAL 列必须走 `getDouble`**：`highlightRules` 有 14 个 REAL 列（下划线宽/偏移、九宫格边距、字距、行距等），用 `getLong` 读会把 `0.1` 静默变成 `0`，界面表现为边距归零、下划线消失。设备实测前 5 条规则 `underlineWidth=1.0 underlineOffset=2.0 npLeft=0.1 npTop=0.1`，无退化。
- **存量搬迁**：`RdbMigration` 拆成两批，各一个事务、各一个标记（`rdb_migrated_v1_1` / `rdb_migrated_v1_2`）。第二批在 `migrateSecondBatch` 里依次调五个仓储的 `migrateFromPreferences`，失败 rollBack 且不写标记。设备上标记文件 `/data/app/el2/100/base/io.legado.harmony/haps/entry/preferences/legado_rdb_migration` 内容为两个 `<double>` 键，**两批都写入了**。搬迁后老 preferences 保留未删。
- **迁移前后行数逐表比对（全部一致）**：`bookmarks` 3、`book_marks` 1、`highlightRules` 9、`replace_rules` 3、`txtTocRules` 27、`book_groups` 0、`book_content_processes` 0、`search_content_history` 0。对照 preferences：`legado_replace_rules` 的 `rules_v1` 3 条（id=1 abc/order=0、id=2 测试规则/order=1、id=8001 E端恢复验证/order=2，group 全 `默认`）、`legado_txt_toc_rules` 的 `rules_v1` 27 条、`legado_reader_highlight_rules` 的 `rules_v1` 9 条、`book_group_store` 的 `android_groups_v1` 0 条。`replace_rules.sortOrder` 落成 0/1/2，说明搬迁时按数组下标重排生效。`groups_v1`（`["GrpXZ"]`）与 `sort_mode_v1`（`asc`）按设计留在 preferences：分组改为从规则派生后 `groups_v1` 已废弃不再读，`sort_mode_v1` 是设置项不随迁移回填。
- **UI 走查（截图证据在 `.tmp-dbcheck/`，未入库）**：

| 页面 | 结果 |
| --- | --- |
| 替换净化列表 | 页签为「全部」「默认」各一个；3 条规则齐全，启用状态开/关/开与 DB 的 `isEnabled` 1/0/1 一致 |
| 替换净化分组筛选 | 点「默认」后 3 条仍全显示，`groupContains` 的拆分包含判断正确 |
| 编辑替换面板 | 规则名称 abc、分组 默认、匹配规则 abc、替换为 XYZ、内容勾选、正则勾选、超时 3000，逐字段与 DB 一致 |
| 分组管理面板 | 自定义分组为空（3 条都属「默认」，上游同样过滤「默认」），符合预期 |
| 更多菜单 | 导入 / 导出 / 分组管理 / 选择模式 / 旧的在前 / 新的在前 / 名称升序 / 名称降序 |
| TXT 目录规则 | 27 条，顺序与 `serialNumber` 一致（目录(去空白)、目录、目录(匹配简介)、目录(古典、轻小说备用)…） |
| 所有书签 | 3 个分组：test-toc「1 个书签 · 0 个笔记」、vol-test2「1 个书签 · 1 个笔记」、vol-test2「1 个书签 · 0 个笔记」，与 `bookmarks` 3 行、`book_marks` 1 行吻合 |
| 书签/笔记双 tab | test-toc 书签 1 / 笔记 0，条目「第1章(1) · 章节」；vol-test2 书签 1 / 笔记 1，笔记条目「第二章 旧名 · 这一段是占位正文 · 歧义笔记」 |
| 划线渲染 | 阅读页第二章正文「今晚就出发。」「(像是忽然想起了什么)」「《百年孤独》」三处按 `highlightRules` 渲染出黄褐底色，9 条规则从 DB 读取后生效 |

- **本轮修掉的两个缺陷**：
  1. **替换净化页显示「暂无替换净化规则」**。根因是竞态：`EntryAbility.onCreate` 里的 `RdbMigration.runIfNeeded` 故意不 await，而 `Index.ets` 的 `aboutToAppear` 同时调 `restoreReplaceRules`，首次启动时表刚建好、搬迁还没写完，`load()` 读到 0 条；搬迁随后完成但界面不刷新。修法照上游时序：把 `runIfNeeded` 移到 `onWindowStageCreate`，`loadContent('pages/Index')` 排到搬迁之后（上游用 Room，建表与迁移在打开库时同步完成，本不存在这个中间态）。`catch` 兜住搬迁失败，仓储层读 DB 失败会自动回退 preferences，界面不会打不开。
  2. **页签出现两个「默认」**。根因是 `getGroups()` 先以 `['默认']` 打底、又从规则里收集到 `默认` 再 push，未去重。修法照上游 `ReplaceRuleDao.dealGroups`：只返回从规则拆出来的分组，不前置「默认」，由各界面自己拼（列表页拼「全部」、编辑页拼「默认」）。
- **三处分组语义按上游改写**：`addGroup` 从「维护分组清单」改为「把无分组规则批量归入该组」（`WHERE group IS NULL OR group = ''` 的 UPDATE）；`renameGroup` / `removeGroup` 用 `WHERE group LIKE '%' || ? || '%'` 捞候选、按 `,` 拆分改写（上游 `upGroup`/`delGroup` 只用逗号，不用 `[,;，；]`）；`getGroups()` 改从规则派生。据此删掉 `explicitGroups` / `persistGroups` / `parseGroups` / `groupsKey` / `persist`（整表 JSON 重写）。
- **`moveToTop`/`moveToBottom` 改上游 min/max 算术**：不再数组重排，而是 `targetOrder = 置顶 ? minOrder - 1 : maxOrder + 1`，其他规则的 order 不动。`sortMode` 默认值由 `'asc'` 改为 `'desc'`（与上游 `PreferKey.replaceSortMode` 默认一致）。
- **未验项**：① 真机上 `getRdbStore` 仍未验（第一批遗留，本批未变）；② 「编辑替换 → 改名 → 保存」这条路径在模拟器上没走通（输入框点击后未聚焦成功，改名未落库），`save` 的单行 upsert 逻辑与第一批已在别处验证过，但该面板的改名保存本身仍属未验。
- 本记录只代表模拟器结果，不替代真机结论。

## 2026-10-30 关系型存储迁移第一批（通过）

- 设备：HOS 模拟器 `127.0.0.1:5555`（API 26），包名 `io.legado.harmony`，书籍 `vol-test2`（本地 TXT，6 章）。`assembleHap` 通过，HAP 覆盖安装成功。
- **范围**：`docs/RELATIONAL-STORE-MIGRATION.md:307` 的第一批三个仓储 `ReaderBookmarkRepository`、`ReaderMarkingRepository`、`ReaderSearchHistoryRepository` 由 preferences 整表序列化改为 relationalStore；同时落地 `data/RdbStore.ets`、`data/RdbSchema.ets`、`data/RdbMigration.ets`、`data/RdbCodec.ets`。
- **建表**：库 `legado.db`（`SecurityLevel.S2`），落在 `/data/app/el2/100/database/io.legado.harmony/entry/rdb/`。`bookmarks`（主键 `time`，索引 `(bookName, bookAuthor)`）、`book_marks`（主键 `id`，索引 `(bookUrl, chapterIndex)`）、`search_content_history`（自增主键 `id`，唯一索引 `(bookName, bookAuthor, query)`）三表按上游实体建出，`RdbStore.version` 置 1。
- **COLLATE LOCALIZED 验证（开工前置，结论与上游写法不同）**：relationalStore 的排序规则名是 **`LOCALES`**，不是 SQLite 文档与上游 Room 写的 `LOCALIZED`——写 `COLLATE LOCALIZED` 报 `errno 25 no such collation sequence`（DDL 报 `code=14800021`）。且必须**先 `store.setLocale('zh')`**，否则 `COLLATE LOCALES` 不报错但静默返回空结果集（界面会显示「没有书签」，比报错更危险）。实测拼音序：默认 BINARY 得 `A|b|安|张|李|王|赵|陈`，设 locale 后 `COLLATE LOCALES` 得 `安|陈|李|王|张|赵|A|b`。`setLocale` 是实例级设置，已写进 `RdbStore.getStore()` 的打开流程。**因此不退回码点序，也无需登记排序差异。**
- **存量搬迁**：`EntryAbility.onCreate` 调 `RdbMigration.runIfNeeded`（故意不 await，不阻塞启动）。标记键 `rdb_migrated_v1_1`，事务包裹「读老 preferences → 逐条 insert → 计数校验 → commit」，失败 rollBack 且不写标记。搬迁成功后老 preferences 保留未删。冷启动复查三表数据完好。
- **待验证清单 7 条（`RELATIONAL-STORE-MIGRATION.md:440`）**：① getRdbStore 在模拟器可打开、库落在 `context.databaseDir` ✔；② 复合主键 / UNIQUE 索引 / 自增主键全部生效 ✔；③ 中文排序见上条 ✔；④ `beginTransaction` + 中途抛错 + `rollBack` 后数据完好（before=4 after=4）✔；⑤ `querySql` 在 rowCount 为 0 时正常返回空集 ✔；⑥ `insert` 在 AUTOINCREMENT 表上返回自增 rowId，读出后转 string 与旧 `id` 语义一致 ✔；⑦ 库文件 40960 字节，远小于 preferences 文本 ✔。真机一项仍未验。
- **结构转换（book_marks 是唯一需要转换的表）**：`anchorJson` 由 `chapterIndex/chapterPosition/selectedText/contextBefore/contextAfter/normalizedTextHash` 合成，结构与上游 `TextProcessAnchor` 一致（实测 `{"chapterIndex":2,"chapterPosition":500,"selectedText":"这一段是占位正文","contextBefore":"","contextAfter":"","normalizedTextHash":"fd185bd2f87259a89f35b8fd002a3d4a"}`）；`styleJson` 由 `effect/color` 合成，highlight 映射到 `{"underlineMode":7,"underlineColor":-13312}`。7 种效果 `solid/dashed/wave/strike/highlight/background/text` 经「写库 → 读回」完整往返。`endPosition` 不落库，由 `chapterPosition + selectedText.length` 推导（500 + 8 = 508 已核）。
- **double 效果删除**：`ReaderMarkingEffect` 去掉 `'double'`，`ReaderMarkingEditor.ets` 效果列表同步为 7 项、`effectFromUnderlineMode` 删掉 `mode === 4` 分支、`ReaderPage.ets` 删掉 `TextDecorationStyle.DOUBLE` 分支。老数据里的 double 在搬迁时按 solid 收下（`ReaderMarkingRepository.loadFromPreferences` 白名单外降级），`ReaderBookmarkExporter.ets:257` 的 double 判断**保留**以兼容读老备份。
- **书签界面走查**：「我的」→「书签」→ 分组 → 条目 → 编辑面板改备注并保存，DB 内容随之更新；点删除 → 二次确认 → DB 行数减少、列表实时刷新。增删改全部落到 DB。
- **搜索历史界面走查**：搜索页输入关键词后**必须回车**才写库（`ReaderSearchPage.ets:309-310`，`.onChange` 只搜索、`.onSubmit` 才调 `saveQuery`），回车后 DB 出现对应行；「清除搜索历史」后该表归零且不影响 `bookmarks`。
- **划线渲染界面走查（决定性验证）**：先确认 highlight 以半透明背景渲染（`#44` + 颜色，`getMarkingBackground`）。为排除「读到的是 preferences fallback」这一可能，把 DB 里 `book_marks.styleJson` 的 `underlineColor` 由 `-13312`（#FFCC00）改成 `-65536`（#FF0000）回写设备，重启后正文同一位置的高亮**由黄变红**（黄色像素 12136 → 红色像素 10577，裁剪图确认是「间的距离，使得每」8 个字），再改回 #FFCC00。→ 渲染确实取自 DB。
- **两处已知差异（按既定决策保留，不修）**：
  1. **书签分组可能被拆开**：`bookmarks` 表无 `bookId` 列（与上游一致），仓储层从 `bookUrl` 末段去 `.txt` 反推 `bookId`，而 `pages/Index.ets:1621-1643` 的 `getBookmarkBookSummaries()` 按 `bookId` 归并。当书签的 `bookUrl` 不是本地书路径（换源、网络书，如 `https://other-source.example/x.txt`）时反推出的 `bookId` 与原值不同，同一本书的书签会被分成两组。上游 `Bookmark.kt` 注释明确 `bookUrl` 是「创建时的源指纹」，书签仍按书名+作者关联，故属预期行为。
  2. **搜索历史按书名+作者归属**：表无 `bookId` 列，`clear(context, bookName, bookAuthor, onlyThisBook)` 与 `visibleHistory()` 均改按书名+作者匹配。`ReaderSearchHistoryRepository.clear` 签名由 `(context, bookId, onlyThisBook)` 改为四参，全项目仅 `ReaderSearchPage.ets:116` 一处调用。这是「表结构对齐上游」的直接代价，计划中「外部引用零改动」在此处不成立。
- **模拟器环境限制（影响走查手法，非应用缺陷）**：该页正文走滚动模式（`ReaderPageTextJoined`），点击左右区域翻页不生效；`uitest uiInput longClick` 与同点长时 swipe 都无法触发长按划词，故划线走查改用「滚动定位 + 像素统计」完成。另：设备自带 `sqlite3` 无法读带 `COLLATE LOCALES` 的表（`no such collation sequence: LOCALES`），排查 DB 须把 `legado.db` 与 `legado.db-wal` 一起拉到本地，用 Python 注册同名 collation 后再查。
- 本记录只代表模拟器结果，不替代真机结论；`docs/RELATIONAL-STORE-MIGRATION.md:440` 的「真机各能打开」一项仍为未验。

## 当前快照状态

- bundleName：`io.legado.harmony`；versionName：`0.1.0`；versionCode：`1000000`。
- `signingConfigs` 未配置；仓库不含签名材料。
- 模块配置未声明 INTERNET 权限；源码没有应用网络客户端/请求代码的初步检索记录。若新版本加入在线服务，须重新审核权限与隐私说明。
- UI 与导航中，阅读器整页及逐项视觉验收未完成；五个阅读相关路由仍为实现中，10 月 26 日增量有模拟器记录但需要继续验收。
- 资源当前 133 SVG / 4 PNG。路径比对报告为 50 个 SVG 与 Android drawable 精确一致；39 个 SVG 有 AndroidX Material / Apache-2.0 来源记录；此前待核的 10 个 SVG 已完成来源映射，其中 2 个箭头是 GPL-3.0 近似 UI 映射，详见 RESOURCE-LICENSES.md。

## 2026-10-28 r245/r243 源码同步后公开副本 clean 构建

- 使用 DevEco Studio 26.0.0.851 附带的 Hvigor 入口，在同步后的公开副本先执行 Entry clean，再执行 `assembleHap`；33 项任务中 32 项执行、1 项为最新，`BUILD SUCCESSFUL`。
- ArkTS 编译有既有异常处理、弃用 API 与剪贴板授权警告；本次未出现编译错误。Hvigor 提示 `No signingConfig found for product default`。
- 构建产生的 HAP 仅作本地编译验证，受 Git 忽略，未作为安装包提交或发行。构建成功不代表 API 12 真机兼容或上述 E 端未验项已通过。

## 2026-11-01 N 端正文排版三缺陷修复（设备验收通过）

**范围**：阅读页正文排版。三个缺陷由用户在一张菜单截图里发现并回报：「整个正文阅读部分都不对吧，右边距去哪儿了，底下还有半行，也没有下边距」。

**设备与素材**：HarmonyOS 模拟器 `127.0.0.1:5555`（1280×2832，密度 3.5 px/vp，API 26），包名 `io.legado.harmony`，书 `the-metamorphosis`（本地 TXT，119736 B，正文文件 `files/books/local-1793481021711.txt` 完好，`ReaderPage` 可正常进入）。设备偏好：`fontSize=20`、`lineSpacing=12`、`paddingLeft/Right=16`、`paddingTop/Bottom=6`、`textBottomJustify=true`、`textBold=500`、`letterSpacing=0.1`、`paragraphIndent=　　`、`readerNightMode=true`。

**取证方法**：`uitest dumpLayout -p /data/local/tmp/x.json` 取布局树逐行 `bounds`（比截图像素统计更精确，不受行内空白干扰），`uitest screenCap` 取图做左右边界复核。

### 缺陷一：左右边距不对称（左边距翻倍、右边距被顶出屏幕）

- **修复前**：正文行 `bounds` 左边界 `x=113`（=32vp）、右边界 `x=1271`（屏幕宽 1280，余量仅 9px）。左边距被叠加两次，右边距被列宽挤出屏幕。
- **根因**：`entry/src/main/ets/pages/ReaderPage.ets` 的 `build()` 里，外层 Column 在单页时补了一次 `left/right: paddingLeft/Right`，而正文那层 `Row` 的每一列又各自 `.padding({ left, right })`，单页时两者相加；`getColumnStrideWidth()` 又按整屏宽 `readerContentWidth / columns` 算列宽（不减外层内边距），列宽把内容顶到屏幕右缘。
- **修复**：外层 Column 左右内边距恒为 `0`，左右内边距一律由每一列自己带（`getColumnStrideWidth()` / `getBodyContentWidth()` 原逻辑不动）。
- **修复后**：正文行 `bounds` 恒为 `x 56-1224`，即左 56px、右 1280-1224=56px，两侧对称 **16vp**，与 `paddingLeft/Right=16` 完全一致。

### 缺陷二：底部对齐位移逐行累加，行距越往下越疏、末行溢出屏幕

- **修复前**：21 行正文中心步进从 96px 单调递增到 158px；末行压到 `y=2828`（屏底 2832），与页脚「第1章(1) / 1/16 0.5%」（`y2626-2675`）直接重叠。
- **根因**：`ReaderPageTextLine` 两个分支都把底部对齐位移塞进 `margin({ top: line.verticalSpaceBefore + this.readerBottomJustifyGap * lineIndex })`。margin 参与布局流，第 i 行再加 `gap*i` 会把前面所有位移一起推下去，累计位移是 `gap·n²/2`。上游 `app/src/main/java/io/legado/app/feature/reader/core/layout/ReaderPaginator.kt:481` 的 `justifyColumnBottom()` 是逐行 `offsetY(deltaY)` 平移，不改变布局流。
- **修复**：两处 `margin` 只保留 `top: line.verticalSpaceBefore`，位移改用 `.translate({ y: this.readerBottomJustifyGap * (lineIndex - this.readerColumnFirstLineIndex(column)) })`（后者原分支漏了 `- readerColumnFirstLineIndex(column)`，一并补上，与前者统一）。
- **修复后**：20 行正文步进为 `105 / 105 / 107 / 105 / 106 / 105 / 106 / 106 / 105 / 106 / 105 / 106 / 106 / 106 / 105 / 105 / 106 / 106` px，理论值 `fontSize × 1.25 × lineSpacing / 10 = 20 × 1.25 × 12 / 10 = 30vp = 105px`，实测均值 105.5px（±1px 为字形升降部差异），**离散度从 62px 降到 2px**。末行底 `y=2469`，页脚顶 `y=2626`，中间留 157px，底部不再溢出。

### 缺陷三：行末丢词（本轮顺带发现并修复）

- **修复前**：屏幕首行显示 `One morning,`，而分页器算出的该行文本是 `　　One morning, when`——**「when」被裁掉了**。多行都有此现象（`bed into a horrible` 丢 `vermin.`、`arches into stiff` 丢 `sections.` 等）。
- **根因**：分页测量用的字重与渲染不一致。`ReaderFontRepository.measureTextWidth()` 走 `MeasureUtils.measureTextSize({ textContent, fontSize })`，未传 `fontWeight`，按默认 **400** 测量；而正文 `Text` 用 `getReaderFontWeight()` = **500**（`textBold=500`）渲染。实测同一串 `One morning, when`：400 → 661px、500 → **670px**、900 → 706px，即渲染比测量宽 1.4%。分页器按偏窄的宽度算行宽，行尾单词本应塞得下；渲染时实际宽度超出行宽，`TextAlign.JUSTIFY` 把它挤到第二行，而每行是 `maxLines(1)` + 固定 `height(line.height)`，多出来的单词直接被裁掉。
- **修复**：`ReaderFontRepository.measureTextWidth()` / `measureTextWidthForPagination()` 增加 `fontWeight: number = 400` 参数并透传给 `measureTextSize` 与 `ParagraphBuilder` 的 `textStyle.fontWeight`，缓存键带上字重；`ReaderPage.ets` 四处调用点分别传入 `getReaderFontWeight()`（正文三处）与 `resolveTitleWeight()`（标题一处）。
- **修复后**：首行显示为 `　　One morning, when`，与分页器文本一致；正文全页无缺词。分页总数由 `1/16` 变为 `1/17`（内容完整后每页行数变化，属预期）。

**复原**：三处调试埋点（`[READER-GAP]`、`[LINE]`、`[W]` 的 `console.info`）已全部删除，`grep -c "READER-GAP\|\[LINE\]\|\[W\]" entry/src/main/ets/pages/ReaderPage.ets` = 0；删后重建仍 `BUILD SUCCESSFUL`，覆盖安装后复查排版不变。

**未取证部分**：

- 上述全部取证在 **API 26 模拟器**上完成，未上真机；真机的字体渲染度量与模拟器可能有微小差异，若真机字重度量偏差更大，行末丢词可能以更隐蔽的形式复现（现有修复已让测量与渲染同源，理论上消除该类偏差，但未在真机验证）。
- `textBold` 取 `1`（→900）与 `2`（→300）两档只做了代码路径核对，未逐档截图比对行末是否仍完整。
- 双列（横屏双页）下的行末丢词与底部对齐未复测：`calculateReaderBottomJustifyGap()` 在 `resolveReaderColumnCount() > 1` 时直接返回 0（KI-D4 已知差异），本轮未改变该行为。

## 2026-11-01 N 端 KI-A2 菜单层依赖三项（面板落库通过；菜单图标视觉已于 r299 补像素取证）

**范围**：`docs/parity/READER-CONFIG.md` A 块的 A-05 展示菜单项图标（`showMenuIcon`）、A-08 阅读标题补充信息（`showReadTitleAddition`）、A-17 阅读菜单不透明度（`menuAlpha`）。三项对应上游 `domain/model/settings/ReadSettings.kt:119`、`:55`、`:13`，恰好是「上游有配置」的三种形态：有设置入口且有渲染消费点、有设置入口但无消费点、两者都没有。判据与证据见 [KNOWN-ISSUES](../KNOWN-ISSUES.md) 的 KI-A2 段。

**构建**：`assembleHap` 两次。第一次 **FAILED**，40 个错（12 × `10605090 arkts-no-implicit-return-types`、28 × `10505001`），全部指向 `entry/src/main/ets/pages/Index.ets` 里 `onShowMenuIconChange` 等三行回调。根因是改写脚本第一次执行只跑了前五步（states / 装载 / 恢复 / 快照 / setter）就退出，**没有写盘**，导致 `Index.ets` 里 setter 定义缺失、回调指向不存在的方法。重跑完整脚本后 **BUILD SUCCESSFUL in 39 s 873 ms**，无 ERROR，`hdc -t 127.0.0.1:5555 install -r` 覆盖安装成功。

**设备**：HarmonyOS 模拟器 `127.0.0.1:5555`（1280×2832，API 26）。

导航：主界面 →「我的」`(1103,2688)` →「设置」`(640,2244)` →「阅读界面」`(640,1099)` → 底部分段**「更多」**`(1084,2629)` → `swipe 640 2400 640 900 400` 连续 8 次滚到底。两个开关在设置页「更多」分段最底部，**不在「菜单栏」或「全局」分段**。

| 项 | 面板初始态 | 拨动后 |
| --- | --- | --- |
| 展示顶部工具栏附加区域 | `[91,2184][592,2237]`，副标题「上游只落库，无渲染效果」，Toggle `[1057,2203][1183,2273]` = **true** | `click 1120 2238` → **false** |
| 展示菜单项图标 | `[91,2376][410,2429]`，副标题「在「更多」面板中显示每项图标」，Toggle `[1057,2395][1183,2465]` = **false** | `click 1120 2430` → **true** |

面板底部同时显示「未迁移项目保留原版设置入口；当前仅呈现设置界面，不执行对应业务。」，说明该分段其余条目仍是占位。

**落库**：先 `aa force-stop` 再 `hdc file recv /data/app/el2/100/base/io.legado.harmony/haps/entry/preferences/legado_reader_settings`（11009 B），三键齐备：

```
<bool key="showMenuIcon" value="true"/>
<bool key="showReadTitleAddition" value="false"/>
<double key="menuAlpha" value="100.000000"/>
```

`menuAlpha` 面板上没有条目（上游也没有），只随阅读设置一起落库，值为默认 100。

**跨进程复查**：`aa start -a EntryAbility -b io.legado.harmony` 重启后重走导航，两个 Toggle 仍为 false / true，与拨动后的状态一致。

**复原**：`click 1120 2238` 把「展示顶部工具栏附加区域」拨回 **true**、`click 1120 2430` 把「展示菜单项图标」拨回 **false**，dump 复核确认出厂默认。

**未取证部分**：

- 「更多」面板里 `showMenuIcon` 的**图标显隐没有像素级取证**：本条取证时模拟器书架三本书的正文文件均已丢失、`ReaderPage` 进不去，只能给到「面板 Toggle 状态 + prefs 落库」两级证据。**该阻塞点此后已解除**——`the-metamorphosis` 的正文文件（`files/books/local-1793481021711.txt`，119736 B）完好，阅读页可正常进入并渲染正文（见同日的「正文排版三缺陷修复」段），本条未借新条件重测。
- `menuAlpha` 与 `showReadTitleAddition` 上游本就没有渲染消费点，本轮按判据**只落库不上屏**，因此也没有视觉可验。
- `showMenuIcon` 在本地的作用域是「更多」网格面板；本地顶栏溢出菜单用的 `MenuItem` 只接受 `startIcon: ResourceStr`，不接受自绘 `AppGlyph` 这样的自定义组件，所以无法复刻上游下拉菜单的 `leadingIcon` 形态。


## 2026-11-01 N 端 KI-E6 无上屏四项（落库通过，面板无条目与上游一致）

**范围**：`docs/parity/READER-CONFIG.md` E 块 E-36..E-40 中最后四行 —— 菜单镜头半径 / 阅读栏样式 / 阅读栏样式跟随页面 / 更多操作配置，对应上游 `ui/book/read/sheet/SystemMenuPage.kt` 与 `domain/model/settings/ReadSettings.kt:68-69`、`:110`、`:121`。原条目里的「E-37 自动亮度」已由 KI-A9 接上，本轮不涉及。

**构建**：`assembleHap` 两次全部 BUILD SUCCESSFUL（53 s 447 ms / 35 s 399 ms），无 ERROR，覆盖安装成功。

**设备**：HarmonyOS 模拟器 `127.0.0.1:5555`（1280×2832，API 26）。这三项在设置面板里**没有条目**（与上游一致：上游 `SystemMenuPage.kt` 与 `ReadConfigScreen.kt` 都查无 `MenuLensRadius` / `readBarStyleFollowPage` 控件），因此无法像前几组那样「拨控件 + 看 dump」，只能走「改一次阅读设置触发保存 → 拉 prefs 核对三键」。

### 上游判据（先于实现查实）

| 字段 | 上游有无设置入口 | 检索证据 |
| --- | --- | --- |
| `readMenuLensRadius` | **无** | `grep -rn "MenuLensRadius" app/src/main/java/io/legado/app/` 共 16 处，全是键名 / 落库与映射 / 字段声明 / 夹取 / 契约 / 委托 / 快照 / 渲染消费 / 备份忽略清单 |
| `readBarStyleFollowPage` | **无** | 全仓只命中 `PreferKey.kt:290`、`ReadSettingsRepository.kt:206`/`:557`/`:691`、`ReadSettings.kt:68`、`BackupConfig.kt:217`、`ReadConfig.kt:56` 只读快照，加 `ReadBook.kt:724-726` 与 `ReadStyleDelegate.kt:445-449` 两个消费点 |
| `readBarStyle` | 有（KI-E1 已接） | 面板「工具栏样式」三档下拉 |
| `moreActionsConfig` | 有（`ReaderMoreActionsSheet.kt`） | 本地已有等价运行时实现 `ReaderMoreActionsRepository` |

前三项按 KI-A3 `disableReturnKey` 同一判据处理：**上游有字段就保留、上游没有效果就不造**，本地只落库、不上屏。

### 落库实测（`aa force-stop` 后 `hdc file recv` 拉偏好文件）

| 键 | 实测值 | 跨进程 |
| --- | --- | --- |
| `readMenuLensRadius` | `<double key="readMenuLensRadius" value="24.000000"/>` | 重启后仍 24 |
| `readBarStyleFollowPage` | `<bool key="readBarStyleFollowPage" value="false"/>` | 重启后仍 false |
| `moreActionsConfig` | `<string key="moreActionsConfig">source_custom_button,true;change_source,true;refresh,true;download,true;audio_download,true;edit_content,true;add_bookmark,true;text_processing,true;reverse_content,true;re_segment,true;del_ruby,true;del_h,true;toc_rule,true;charset,true;image_style,true;page_anim,true;simulated_reading,true;get_progress,true;cover_progress,true;highlight_rule,true;read_style,true;bottom_button_config,true;log,true</string>` | 重启后仍 23 项、全部 `,true` |

**关键发现**：这三键**只在「任意阅读设置改动触发 `persistReaderSettings()`」之后才写入**，纯启动不会落盘（实测首轮 prefs 里三键缺失，文件 10331 B；改一次字号后出现，文件 10875 B）。因此验收时先改字号（`Slider 20 → 49`）触发保存，再拉 prefs。

### 操作踩坑

1. **字号滑块 `[91,417][958,557]` 用 `uitest uiInput click` 完全无效** —— 连点 5 个不同 x 位置读数都不变；只有 `swipe 起点x 487 目标x 487 800/1500` 才生效。复原路径 `swipe 950 487 380 487 1500` → `20.000000`。
2. `legado_reader_more_actions` 这个独立 prefs 文件在模拟器上**不存在**（`hdc file recv` 报 no such file or directory），因为该仓储只在用户改「更多」面板时才写；`moreActionsConfig` 出现在 `legado_reader_settings` 里是 `Index` 快照编码的结果，两者不矛盾。

### 未验部分

1. **面板无这三项**，因此没有「开关互斥 / 控件拨动」类证据，只有 prefs 落库证据。
2. **菜单镜头半径的 `lens` 高光效果不实现**（ArkUI 无液态玻璃材质），也无法取证。
3. ~~**阅读栏样式跟随页面的效果未做像素级取证**~~ —— **已于 r299 补齐**：`readBarStyle=1` + `bgStrNight=#1E88E5` 下顶栏主色 `(31,136,230)` 与正文主色 `(30,135,228)` 几乎同色，改 `readBarStyle=2` + `readMenuBgColorNight=#FF0000` 后顶栏变 `(202,34,57)` 而正文不变，两种底色来源构成决定性对照。详见本文档「2026-11-01 N 端 r299 菜单与正文视觉取证」的 KI-E6 节。
4. **更多操作配置的双向一致性未在设备上走完整闭环** —— 需要进阅读页打开「更多」面板增删条目才能观察 `moreActionsConfig` 变化，本轮只验到「默认 23 项编码正确 + 重启后保持」。

### 复原状态

三项均为默认值（`24` / `false` / 23 项全开），字号已 `swipe` 复原到 `20.000000`，无需其他复原动作。

## 2026-10-31 N 端 KI-E3 浮动图标四项（面板互斥与落库通过；图标行视觉已于 r299 补像素取证）

**范围**：`docs/parity/READER-CONFIG.md` E 块 E-17..E-20 四行（显示标题栏图标 / 标题栏悬浮图标配置 / 标题栏悬浮图标位置 / 悬浮图标液态玻璃按钮），对应上游 `ui/book/read/sheet/SystemMenuPage.kt:491-544` 的「Floating icon settings」段。字段共六项（`showTitleBarIcons`、`titleBarIconPosition`、`readMenuFloatingIconLiquidGlass`、`floatingIcons` 图标池、`titleBarCustomIcons`、`readMenuCustomIcons`）。

**构建**：`assembleHap` 共三次全部 BUILD SUCCESSFUL（44 s 860 ms / 27 s 44 ms / 27 s 223 ms），无 ERROR。三次分别对应：首次（补齐 `readMenuCustomIcons` 缺的 `@Prop` 后）、补「悬浮图标液态玻璃按钮」进 `isMenuToggle` 名单后、补「标题栏悬浮图标位置」弹层落库分支后。

**设备**：HarmonyOS 模拟器 `127.0.0.1:5555`，1280×2832，API 26。导航：主界面 →「我的」`(1103,2688)` →「设置」`(640,2244)` →「阅读界面」`(640,1099)` → 底部分段「菜单」`(493,2629)` → 滚到底部（`swipe 640 2400 640 900 400` 两次）。四项位于「悬浮图标设置」section，是该 tab 的最后一段。

### 互斥显示（决定性对照）

「显示标题栏图标」Toggle 在 `[1106,2387][1232,2457]`（点 `1169 2422`）。

| 状态 | 面板 dump 结果 |
| --- | --- |
| 关 | 「标题栏悬浮图标配置」「标题栏悬浮图标位置」「悬浮图标液态玻璃按钮」**三项计数全为 0**，section 只剩「显示标题栏图标」一行 |
| 开 | 三项全部出现：「标题栏悬浮图标配置」`[42,2015]`（副标题「图标内容与显示位置」）、「标题栏悬浮图标位置」`[28,2219]`（摘要「右下」）、「悬浮图标液态玻璃按钮」`[42,2368]` + Toggle `[1106,2387]` |

与上游 `SystemMenuPage.kt:498` 的 `AnimatedVisibility(visible = preferences.showTitleBarIcons)` 一致。

### 四项落库（逐项，含跨进程复查）

| 项 | 操作 | 结果 |
| --- | --- | --- |
| 显示标题栏图标 | 打开 Toggle | prefs `showTitleBarIcons` = `true`；`aa force-stop` 重启后仍为 `true` |
| 标题栏悬浮图标位置 | 点 `(640,2250)` 开弹层，四项「左上/右上/左下/右下」齐全（`[182,1251]`/`[182,1414]`/`[182,1572]`/`[182,1730]`），选「左上」`(640,1277)` | 条目摘要变「左上」；重启后仍是「左上」；prefs `titleBarIconPosition` = `0.000000` |
| 悬浮图标液态玻璃按钮 | 打开 Toggle | prefs `readMenuFloatingIconLiquidGlass` = `true`；重启后仍为 `true` |
| 标题栏悬浮图标配置 | 点 `(640,2040)` 开 sheet，标题「浮动图标」；滚两次到「更多操作/全文搜索/自动翻页/目录/朗读/护眼模式/设置」段，关掉「自动翻页」`(895,1761)`，点保存 `(1171,1256)` | prefs `floatingIcons` 字符串里 `autoPage` 由 `true` 变 `false`；重启后仍为 `false`。**图标池与「标题栏操作按钮」同池的直接证据** |

### 暴露并修掉的两个问题

1. **「悬浮图标液态玻璃按钮」原先不在 `isMenuToggle` 名单里** —— 面板把它渲染成普通条目，`dump` 里出现 `Text '尚未迁移' [1060,2404]`，Toggle 根本不存在，等于开关无法拨动。补进名单并加 checked 分支后才上屏。
2. **「标题栏悬浮图标位置」弹层不落库** —— 段落（Segments）路径的 `onSelect` 有落库，但 `applyDetailChoicePreview()` 缺这一支，点弹层里的「左上」后条目摘要仍是「右下」。补分支后通过。**教训：Segments 与底部弹层是两条独立路径，凡是 `getMenuChoices` 返回非空的条目，两条路径都要写落库分支。**

### 未验部分

1. ~~**浮动图标行的实际渲染完全没有像素级取证**~~ —— **已于 r299 补齐**：`titleBarIconPosition` 0 vs 3 changed px=131697（正文区 103120，图标行从顶栏下方移到菜单浮层上方）、0 vs 1 changed px=10541（bbox `x92-1189 y570-629`，同行改右对齐），像素分区与 `readerFloatingIconTopVisible()`/`readerFloatingIconBottomVisible()` 的分支一致；「自定义圆形图 36dp」「玻璃底 `readerMenuForegroundAlpha('1F')`」仍只有代码与面板证据。详见 r299 节的 KI-E3 节。
2. **没有「换自定义图标图片」的选图入口**：上游 `OpenTitleBarCustomIconPicker` 本地未迁移，`titleBarCustomIcons`/`readMenuCustomIcons` 两个串可落库、渲染侧已能解码显示，但面板里选不了图。

### 复原终态

`showTitleBarIcons` = `false`、`titleBarIconPosition` = `3.000000`（右下）、`readMenuFloatingIconLiquidGlass` = `false`、`floatingIcons` 里 `autoPage` 回到 `true` —— 全部回到默认，已 `aa force-stop` 后拉 prefs 复核。

## 2026-10-31 N 端 KI-E2 边框与模糊七项（面板互斥与落库通过；菜单视觉已于 r299 补像素取证）

**范围**：`docs/parity/READER-CONFIG.md` E 块 E-10..E-16 七行（菜单栏边框 / 菜单栏边框宽度 / 菜单栏边框颜色 / 菜单模糊半径 / 菜单模糊透明度 / 菜单文字颜色 / 菜单模糊颜色），对应上游 `ui/book/read/sheet/SystemMenuPage.kt:398-489` 的边框与「模糊和颜色」段。字段共八个（七行里「菜单模糊透明度」复用 KI-E4 已落库的 `readMenuBlurAlpha`）。

**构建**：`assembleHap` 共三次全部 BUILD SUCCESSFUL（36 s 917 ms / 33 s 848 ms / 23 s 250 ms），无 ERROR。

**设备**：HarmonyOS 模拟器 `127.0.0.1:5555`，1280×2832，API 26。导航：主界面 →「我的」`(1103,2688)` →「设置」`(640,2244)` →「阅读界面」`(640,1099)` → 底部分段「菜单」`(493,2629)` → 顶部 tab「菜单栏」`[49,318][443,419]`。

### 互斥显示（决定性对照，两个方向都验）

`菜单栏边框` Toggle 在 `[1106,1201][1232,1271]`。

| 状态 | 面板 dump 结果 |
| --- | --- |
| 开（默认） | 有「菜单栏边框宽度」`[42,1374][1214,1427]` + `Slider 1.000000` `[42,1427][1238,1567]` +「菜单栏边框颜色」`[42,1651][361,1704]`；「菜单模糊半径」在 `[42,1941]` |
| 关（点 `1169,1236`） | **「菜单栏边框宽度」「菜单栏边框颜色」两行整行消失**，下方各项整体上移约 98 px（「菜单模糊半径」变为 `[42,1472]`） |
| 重新打开 | 两行恢复、位置复原 |

与上游 `SystemMenuPage.kt:398-408` 的 `borderEnabled = readMenuBorderWidth > 0` + `AnimatedVisibility(visible = borderEnabled)` 一致。

### 三个滑块落库（`aa force-stop` 重启后复查）

| 项 | 操作 | 读回 | 重启后 |
| --- | --- | --- | --- |
| 菜单栏边框宽度 | `swipe 60 1497 1220 1497 300` | `4.000000` | `4.000000` ✅ |
| 菜单模糊半径 | `swipe 940 2064 1225 2064 300` | `32.000000` | `32.000000` ✅ |
| 菜单模糊透明度 | `click 520 2341` | `39.000000` | `39.000000` ✅ |

### 三个颜色项（弹层 / 选色 / 清除 / 跨进程）

弹层结构：日/夜两块 `MenuSettingPalette`，`XXX（日间）` `[182,901][1098,954]`、`XXX（夜间）` `[182,1206][1098,1259]`，各 8 个圆点（日间行圆心 `y≈1055`，`x` 依次 248/381/514/647/780/913/1046/1178）。

| 项 | 入口 | 选色 | 重启后 | 清除 |
| --- | --- | --- | --- | --- |
| 菜单栏边框颜色 | `(640,1672)` | `(780,1055)` = `#3D3D46` | 仍显示 `#3D3D46` ✅ | 再点同色 → 空 ✅ |
| 菜单文字颜色 | `(640,2520)` | `(1180,1055)` = `#000000` | — | 再点同色 → 空 ✅ |
| 菜单模糊颜色 | 先 `swipe 640 2300 640 1500`，再点文字本身 `(179,1929)` | `(780,1055)` = `#3D3D46` | — | 再点同色 → 空 ✅ |

**踩坑**：「菜单模糊颜色」若点行中间偏右 `(640,1930)` 会落到下面的「菜单模糊透明度」行上（弹层标题会变成「菜单模糊透明度」），必须点文字本身。

### 本轮修掉的真 bug

`菜单模糊透明度` 在「菜单栏」tab 的滑块**原先完全没有接线**：`menuSettingsEntry()` 的 onChange 链只有「底栏模糊透明度」，`menuSliderValue` 也没有这一项，拖动后读数不变、不落库（实测拖到 70/89 均无变化）。上游 `read_menu_blur_alpha` 由两个 tab 共用（`SystemMenuPage.kt:448-456`），补 `entry/src/main/ets/pages/ReaderSettingsPage.ets` 两行分支后实测拖到 `39.000000` 生效。

### 未验部分

- ~~**边框描边、模糊半径、模糊着色、文字色的视觉变化全部没有像素级取证**~~ —— **已于 r299 补齐**：边框宽度 0 vs 4 changed px=222402、模糊半径 0 vs 32 changed px=358357（正文区 0 变化）、模糊透明度 100 vs 20 changed px=290444、描边色改 `#00FFFF` 后青色像素 19578 且横竖带位置与面板 `bounds` 一致。详见 r299 节的 KI-E2 节。
- ArkUI 的 `backdropBlur` 是静态半径，没有上游 `hazeState` 的内容自适应模糊，不做效果等价断言。
- `readMenuLensRadius`（夹 0–48）不在本轮七行内，本地未落库。

### 复原终态（重启后 dump 实测）

`菜单栏边框` Toggle `true`、`菜单栏边框宽度` `1.000000`、`菜单模糊半径` `24.000000`、`菜单模糊透明度` `85.000000`、三个颜色项全部清除。

## 2026-10-31 N 端 KI-E1 配色七项（面板可见性与落库通过；菜单视觉已于 r299 补像素取证）

**范围**：READER-CONFIG E 块 E-01..E-07 —— 工具栏样式、调色板风格、菜单颜色来源、种子色、菜单背景颜色、菜单容器颜色、菜单强调颜色。E-08/E-09 亮度两项已由 KI-A9 交付，不在本节。

**设备**：HarmonyOS 模拟器 `127.0.0.1:5555`，API 26，1280×2832。构建 `assembleHap` BUILD SUCCESSFUL（22 s 790 ms），`hdc install -r` 覆盖安装成功。

### 导航链

主界面 →「我的」`(1103,2688)` →「设置」`(640,2244)` →「阅读界面」`(640,1099)` → 底部分段「菜单」`(493,2629)`。顶部三个 tab：菜单栏 `[49,318][443,419]`、底栏布局 `[443,318][837,419]`、顶栏布局 `[837,318][1231,419]`。

### 可见性三档互斥（决定性对照）

上游 `SystemMenuPage.kt:276-320` 有三层 `AnimatedVisibility`，本地必须两两互斥：

| 工具栏样式 | 菜单颜色来源 | 出现 | 不出现 |
| --- | --- | --- | --- |
| 跟随阅读背景 | ——（不显示） | 工具栏样式、调色板风格 | 菜单颜色来源、种子色、菜单背景颜色、菜单容器颜色、菜单强调颜色 |
| 自定义 | 种子色 | 工具栏样式、菜单颜色来源、调色板风格、种子色 | 菜单背景颜色、菜单容器颜色、菜单强调颜色 |
| 自定义 | 自定义颜色 | 工具栏样式、菜单颜色来源、菜单背景颜色、菜单容器颜色、菜单强调颜色 | 调色板风格、种子色 |

三档各自的 `uitest dumpLayout` 条目集合互为补集，与上游一致。操作细节：「工具栏样式」行 `(640,541)` 点开弹层，三项 `跟随系统` `[182,1330][1035,1383]` / `跟随阅读背景` `[182,1493]` / `自定义` `[182,1651]`；点「自定义」`(640,1677)` 后必须点弹层「关闭」`(1094,451)`，否则后续 dump 会混入弹层内容。

### 配色弹层与选色/清除

- 点「种子色」`(640,1012)` 打开弹层：标题「种子色」，两块色板「种子色（日间）」`[182,922]`、「种子色（夜间）」`[182,1227]`，底部说明「「种子色」与「菜单强调颜色」共用同一组字段（上游 readMenuAccentColor / Night）；菜单背景色、容器色未设置时回落到主题默认值。」
- 色板圆点是 `Circle` 节点、无 text，`uitest dumpLayout` 的 labels 里看不到，须用遍历全部节点的 dump 才能取坐标。10 个色点日间行 `y≈1076`，`x` 依次 `248/381/514/647/780/913/1046/1178`，对应 `MENU_COLOR_PALETTE` 的 `#FFFFFF #E6E1E7 #D0CBD1 #9A9CA5 #3D3D46 #31282A #1A1B21 #000000 #FFB1C8 #5A8DEE`。
- 点第 5 个 `(779,1076)` → 弹层标题行右侧出现 `#3D3D46`，选中态渲染正确。
- **再点同一个色 = 清除**（`applyMenuColor` 的 current === color 分支），已验回未设置。
- **共用字段的直接证据**：在「种子色」里选中 `#3D3D46` 后，打开「菜单强调颜色」`(640,1235)`，弹层标题为「菜单强调颜色（日间）」且色号仍是 `#3D3D46` —— 上游这两个入口绑同一对 `readMenuAccentColor`/`Night`（`SystemMenuPage.kt:309` 与 `:349`）。
- 「菜单背景颜色」点 `(640,851)` 开弹层、点 `(1024,1076)` → 标题行显示 `#1A1B21`；「菜单容器颜色」点 `(640,1043)`、点 `(1024,1076)` → 同样 `#1A1B21`，两者独立字段互不影响。
- 「调色板风格」点 `(640,702)` 开十项弹层：`跟随系统` `[182,777]` / `柔和` `[182,940]` / `中性` `[182,1098]` / `鲜艳` `[182,1256]` / `表现力` `[182,1414]` / `彩虹` `[182,1572]` / `水果拼盘` `[182,1730]` / `单色` `[182,1888]` / `仿真` `[182,2046]` / `内容取色` `[182,2204]`（间隔 158 px）。点「鲜艳」`(640,1282)` 后条目副标题变「鲜艳」。

### 落库跨进程

`aa force-stop io.legado.harmony` + `aa start` 后重进设置页复查：工具栏样式=自定义、调色板风格=鲜艳、菜单颜色来源=种子色、种子色（日间）=`#31282A`，全部保持。

prefs 直读（先 `aa force-stop` 再 `hdc file recv /data/app/el2/100/base/io.legado.harmony/haps/entry/preferences/legado_reader_settings`）：

```
<double key="readBarStyle" value="1.000000"/>
<double key="readMenuColorMode" value="1.000000"/>
<string key="readMenuPaletteStyle"></string>
<string key="readMenuBgColor"></string>
<string key="readMenuContainerColor"></string>
<string key="readMenuAccentColor"></string>
```

九键在 prefs 中确实存在。**读出的是复位后的默认值**（拉取时面板已复原到「跟随阅读背景 / 跟随系统 / 清空颜色」），这与「落库失败」不同：落库证据取自上一条的 `force-stop` 后 UI 回显。取键时 XPath 形态是 `key="..."`，不是 `name="..."`。

### 未取证部分

~~**`ReaderPage` 的菜单配色视觉完全没有像素级取证**~~ —— **已于 r299 补齐五组**：「跟随系统 vs 跟随阅读背景 vs 自定义」三种底色来源（跟随态顶栏 `(31,136,230)` ≈ 正文 `(30,135,228)`；自定义态顶栏 `(202,34,57)`）、顶栏/底栏底色随 `readMenuBgColor`/`readMenuContainerColor` 变化（`#FF0000` → 顶栏 `(92,0,0)`/底栏 `(102,10,10)`，`#00AAFF` → `(2,62,93)`/`(12,72,103)`）、强调色随 `readMenuAccentColor` 变化（`#00FF00` 后进度条滑块由 `(90,63,71)` 变 `(2,255,0)`）、文字色随 `readMenuTextColor` 变化（`#FF00FF` 后洋红像素 19668，bbox `x 60-1156 y 222-2560`）、`readMenuBlurAlpha` 对菜单底不透明度的影响（100 vs 20 changed px=290444）。**仍未取证**：前景色明暗反色、渐变方向两组。详见 r299 节的 KI-E1 节。

另：「跟随系统」与九种调色板风格只落库，不生成 Material 派生色板（ArkUI 无 `dynamicColorScheme` 等价物），这一点也无法用截图证明。

### 复原终态

工具栏样式=跟随阅读背景、调色板风格=跟随系统、菜单颜色来源=自定义颜色、种子色/菜单背景颜色/菜单容器颜色/菜单强调颜色全部清除。均已 `dumpLayout` 回读确认。

## 2026-10-31 N 端 KI-E5 标题栏形态八项（面板互斥与落库通过；顶栏视觉已于 r299 补像素取证）

- 设备：HOS 模拟器 `127.0.0.1:5555`（API 26，1280×2832），包名 `io.legado.harmony`。
- 导航：主界面 →「我的」(`1103,2688`) →「设置」(`640,2244`) →「阅读界面」(`640,1099`) → 底部分段「菜单」(`493,2629`) → 顶部 tab「顶栏布局」(`1034,368`)。设置页顶部三个 tab 为「菜单栏」(`49-443`)、「底栏布局」(`443-837`)、「顶栏布局」(`837-1231`)，y 都在 `318-419`。
- 构建：`assembleHap` BUILD SUCCESSFUL（39 s 738 ms / 21 s 843 ms 两次，无 ERROR），`hdc install -r` 覆盖安装成功。

### 互斥显示（决定性对照，两个方向都做过）

- 「标题栏胶囊」的 Toggle 在 `[1057,704][1183,774]`（比同页其它 Toggle 偏左，因为该行带额外图标）。
- 打开胶囊后 `dumpLayout`：**「标题栏模式」整行消失**，其后的「标题栏操作按钮」及以下条目整体上移约 81 px。
- 关闭胶囊后 `dumpLayout`：「标题栏模式」重新出现，摘要显示「在独立行上显示」。
- 结论：与上游 `SystemMenuPage.kt` 的 `AnimatedVisibility(visible = !preferences.readMenuTopBarTitleCapsule)`（把「菜单标题显示方式」下拉藏在胶囊开关之后）一致。

### 落库逐项（退出设置页重进 + `aa force-stop` 重启应用后复查）

- 五个 Toggle 打开后 `checked` 均为 `'true'`：标题栏胶囊、标题栏紧凑、顶栏模糊、顶栏液态玻璃按钮、合并标题栏按钮。
- 「标题栏模式」弹层四项文案与上游中文串完全一致：在应用栏上显示 / 在独立行上显示 / 仅显示标题 / 不显示。选「在应用栏上显示」后条目摘要同步变化。
- 「标题栏图标样式」弹层三项：纯色 / 色调 / 描边。选「色调」后摘要变「色调」，验收末尾手工改回「纯色」。
- 「顶栏模糊样式」弹层两项：纯色 / 渐变（与「底栏模糊样式」是**不同存储键**）。选「渐变」后摘要变「渐变」。
- 应用重启后复查八项**全部跨进程保持**：胶囊 `false`、模式「在应用栏上显示」、紧凑 `true`、图标样式「色调」、顶栏模糊 `true`、顶栏模糊样式「渐变」、液态玻璃按钮 `true`、合并按钮 `true`。

### 验收中暴露并修掉的两处问题

1. **Segments 路径原先不落库**：`MenuSettingSegments` 的 `onSelect` 只处理了五种条目，其余无条件 `openDetailSheet()`，导致「标题栏模式 / 标题栏图标样式 / 顶栏模糊样式」在段落行上点选只开弹层、不写值。已在 `onSelect` 里补同样三行落库（`ReaderSettingsPage.ets:861-863`），并在 `applyDetailChoicePreview`（`:998-1004`）保留同分支，两条路径都落库。
2. **弹层提示文案与事实不符**：底部提示原为「仅展示选择预览，不保存设置。」，但这四项已真落库。已在三元表达式里补入「标题栏模式 / 标题栏图标样式 / 顶栏模糊样式 / 底栏模糊样式」，改为「选择后立即应用并保存；自定义内容需点击保存。」。**这个坑是设备验收才发现的**——`click` 点段落行只会打开弹层，必须在弹层里再点真正的选项才落库；点完还要 `click 1094 451` 关掉弹层，否则后续 dump 会把弹层内容与页面内容混在一起。

### 未取证部分（不得写成通过）

- ~~**顶栏像素级视觉未验**~~ —— **已于 r299 补齐五组**：「书名在应用栏 / 独立行 / 不显示 / 全隐藏」四态（`titleBarMode` 四档顶栏文字带各不相同，行投影区间见 r299 节）、「胶囊 vs 非胶囊」（changed px=242055，顶栏 201651 + 正文区 40404）、「紧凑只留更多」（changed px=2721，bbox `x187-1156 y59-280`）、「图标样式三档底色与描边」（0→1 changed px=30656、1→2 changed px=29947，均落在顶栏图标区）、「顶栏底色随 `readMenuBlurAlpha`」（见 KI-E2 节）。**仍未取证**：「合并按钮的胶囊容器」。详见 r299 节的 KI-E5 节。
- **液态玻璃材质无实现**：`readMenuTopBarLiquidGlassButtons` 只做可配 + 落库 + 抑制描边，ArkUI 没有 `backdropBlur` 等效物，模拟器也没有 API 13+ 液态玻璃材质。
- **胶囊里的书名/章名点不进去书籍详情**：`ReaderPage` 没有 `onOpenBookInfo` 回调，上游 `TitleCapsuleGlassLayout` 的书源圆点入口本地缺。

### 复原终态（实测）

标题栏胶囊 `false`、标题栏模式「在独立行上显示」、标题栏紧凑 `false`、标题栏图标样式「纯色」、顶栏模糊 `false`、顶栏模糊样式「纯色」、顶栏液态玻璃按钮 `false`、合并标题栏按钮 `false` —— 八项全部回到默认。

## 2026-10-31 N 端 KI-E4 底栏外观七项（面板互斥与落库通过；底栏视觉已于 r299 补像素取证）

- 设备：HOS 模拟器 `127.0.0.1:5555`（API 26，1280×2832），包名 `io.legado.harmony`。`assembleHap` 通过（`BUILD SUCCESSFUL`，无 ERROR），HAP 覆盖安装成功。
- **本轮先修掉一个自造 bug 才进入验收**：`ReaderSettingsPage.ets` 的 `isMenuSettingsEntryVisible()` 首行是 `if (this.selectedMenuSettingsTab !== 0) { return true; }`，会把非「菜单栏」tab 的条目全部直接放行。两条互斥规则（「底栏模糊样式」仅在非悬浮时显示、「底栏液态玻璃」仅在悬浮时显示）最初写在函数末尾，**在底栏布局 tab 里永远不会生效**。移到该短路之前才正确，第一版构建能过但面板上一直两项同时存在。
- **互斥显示（决定性对照，两个方向都验过）**：
  - 「底栏悬浮」开启（Toggle `checked: 'true'`）时，`uitest dumpLayout` 里出现「底栏液态玻璃」+「悬浮底栏背景效果」、**不出现**「底栏模糊样式」。
  - 关掉「底栏悬浮」后，同一次 dump 里「底栏模糊样式」+「纯色」+ `⌄` 出现、「底栏液态玻璃」消失。
  - 重新打开「底栏悬浮」，「底栏液态玻璃」回来、「底栏模糊样式」再次消失。三次 dump 的条目集合互为补集，与上游 `SystemMenuPage.kt` 的两个 `AnimatedVisibility(visible = !floatingBottomBar / floatingBottomBar)` 一致。
- **落库逐项**：
  - 「底栏圆角」滑块 32 → 0（`Slider` 读回 `0.000000`），退出设置页再重进仍为 `0`。
  - 「底栏模糊」开关打开后 `Toggle.checked` 为 `'true'`，退出重进保持（对应写回 `Haze = 2`）。
  - 「底栏按钮液态玻璃」开关打开后 `Toggle.checked` 为 `'true'`，退出重进保持。
  - 「底栏模糊样式」点开下拉，面板标题「底栏模糊样式」、描述「纯色 / 渐变」、两项「纯色」「渐变」；点「渐变」后条目副标题由「纯色」变「渐变」，**`aa force-stop` 后重新启动应用再进设置页，该条目仍显示「渐变」**——证明是真落库不是页面态。
  - 「底栏模糊透明度」85 → 50（`Slider` 读回 `50.000000`），退出重进仍为 `50`。
  - 应用重启后复查：底栏圆角 `0`、底栏悬浮关闭、底栏模糊开启、底栏按钮液态玻璃开启、「底栏模糊样式」显示「渐变」，五项全部跨进程保持。
- **未验部分（重要）**：
  - ~~**底栏视觉本身没有像素级取证**~~ —— **已于 r299 补齐三组**：「圆角 0 vs 32」（changed px=13651，圆角 0 时 y=2250 行面板左缘 x=51 即开始、圆角 32 时 x=155，内缩 104px ≈ 30vp）、「悬浮 vs 非悬浮的宽度与下圆角差异」（changed px=121541，悬浮态 x 155-1124、关闭后贴满 x 0-1279）、「透明度 20 vs 100 的底色浓淡」（见 KI-E2 节 changed px=290444）。**仍未取证**：「纯色 vs 渐变的渐变方向」。详见 r299 节的 KI-E4 节。
  - 「底栏按钮液态玻璃」的玻璃质感无消费点（`readerBottomBarButtonGlassEnabled()` 目前没有被调用），ArkUI 也没有 `backdropBlur` 的等效物，本轮按上游「配置存在、效果不发明」只做可配+落库。
  - 「底栏模糊」没有真正的背景模糊，本地把模糊模式折算成背景不透明度与渐变（对照 `ReadBookMenuBarShared.kt:49-85` 的 alpha 叠色实现）。
- 测试期改动已复原：底栏圆角回到 `32`、底栏悬浮回到开启、底栏模糊回到关闭、底栏按钮液态玻璃回到关闭、底栏模糊样式回到「纯色」、底栏模糊透明度回到 `85`。
- 本节结论只代表 N 端模拟器本次构建，不代表真机材质与 API 13+ 液态玻璃效果。

## 2026-10-31 N 端 KI-A1 正文渲染适配四项（开关与落库通过；`[newpage]` 已于 r299 取证通过、`<usehtml>` 未实现）

37. **设备与构建**：模拟器 `127.0.0.1:5555`（1280×2832），`hvigorw --no-daemon --mode module -p product=default -p module=entry@default assembleHap` → `BUILD SUCCESSFUL in 30 s 589 ms`（33 任务 18 执行 / 15 最新）；`hdc install -r ...entry-default-unsigned.hap` → `install bundle successfully`。清埋点前后各构建一次，均通过。
38. **编译期真实错误两处（都修了）**：① `Property 'px2vp' does not exist on type 'Context'. At File: .../ReaderPage.ets:806:61`（`:807:62` 同）—— `Context` 没有 `px2vp`，改用 `this.getUIContext().px2vp(...)`；② `LocalTextSemantics.ets` 报 `Unterminated string literal` / `',' expected` / `Expected 1 arguments, but got 3` —— 写文件时把 `appendBoth('
')` 写成了**真实换行**，用 `chr(10)`/`chr(92)` 拼串重做 replace 修好。
39. **设置项上屏**（我的 `(1103,2688)` → 设置 `(640,2181)` → 阅读界面 `(640,1115)` → 更多 tab `(1084,2629)`，四项在首屏）：`uitest dumpLayout` 读到 `填充刘海区域 / 把显示缺口算进正文可用区`（Toggle `[1057,1231][1183,1301]`，`checked=false`）、`扩展到刘海 / 上游同名字段只做配置，没有对应渲染效果`（`[1057,1423][1183,1493]`，`checked=true`）、`适配特殊样式 / 按标记解释正文里的分段与富文本`（`[1057,1615][1183,1685]`，`checked=true`）、`使用自定义中文分行 / 改后重新计算分页`（`[1057,1807][1183,1877]`，`checked=false`）。**四个默认值与上游 `ReadSettings.kt:11/14/18/19` 完全一致。**
40. **落库决定性证据（四个 Toggle 与四个存储键一一对应）**：依次点 `(1120,1266)`/`(1120,1458)`/`(1120,1650)`/`(1120,1842)` 共两轮（一轮改一轮复原），偏好文件每次立即更新（8028↔8029 字节、mtime 同步变化），读回：`paddingDisplayCutouts` `false→true→false`、`readBodyToLh` `true→false→true`、`adaptSpecialStyle` `true→false→true`、`useZhLayout` `false→true→false` —— **无一处串键**。
41. **重启回显**：`aa force-stop`/`aa start` 后重新进面板，四个 Toggle 的 `checked` 与偏好文件一致（`false`/`true`/`true`/`false`），证明读路径与快照回灌都对。
42. **本条的两种标记渲染已于 r299 实测**（结论：`[newpage]` 通过、`<usehtml>` 未实现，详见 r299 节的 KI-A1 节）。原记录如下：`adaptSpecialStyle` 的两种标记渲染 —— `[newpage]` 独占一段成为换页点、`<usehtml>...</usehtml>` 整段作为富文本块。本条取证时**模拟器没有一本正文可读的书**（书架 `dup-probe`/`test-book` 等正文文件均已丢失，打开只显示「缺正文」详情页），因此只做代码侧只读证据链：`LocalTextSemantics.ets:94`（`[newpage]` → `pageBreak: true`）、`:107`/`:113`（`<usehtml>` → `richHtml: true`）、`LocalReaderPaginator.ets:306`（`paginate` 路径）与 `:515`（`countPagesIncrementally` 路径）都按 `pageBreak` 强制换页。**该阻塞点此后已解除**（`the-metamorphosis` 正文完好、阅读页可进），本条未借新条件重测。`paddingDisplayCutouts` 同理：模拟器无显示缺口，`getWindowAvoidArea(TYPE_CUTOUT)` 返回 `visible=false`，三个 inset 恒 0，正文宽度不变 —— 只能验到开关与落库。
43. **本轮顺带查明并修复了一个环境故障（重要，后续沿用）**：设备验收时发现 prefs **完全不落盘** —— 不只本轮四个新键没写，连已有键（如拨「隐藏状态栏」改 `hideStatusBar`）也不写，文件 mtime 卡死在 `20:59`。排查排除项：`persist start`/`context ok`/`snapshot ok`/`save done` 四行埋点齐全（Promise 正常 resolve、无 `save threw:`）、磁盘 `26%` 充足、`ps` 无多进程、`ls -lZ` 的 SELinux 标签与正常文件一致、`xml.etree` 解析该文件 149 个键良构无重复。**决定性日志**：`hilog -x` 中反复出现 `E C01653/NativePreferences: ParseNodeElement: An unsupported element type was encountered in parsing = text`、`E ReadSettingXml: The error occurred during getting xml child elements`、`W ReloadFromDisk: ... reload result is 0`。**根因**：该 prefs XML 被测试期多次 `hdc file send` 整文件覆盖后，`string` 节点全部变成文本子节点形式（42 个 text-form、0 个 attr-form），`NativePreferences` 回读失败 → 内存 store 与磁盘脱钩 → 此后 `put()`+`flush()` 静默不落盘。**修复**：`aa force-stop` 后推入 67 字节的 `<?xml version="1.0" encoding="UTF-8"?><preferences version="1.0"/>`，重启即恢复（第一次拨开关就把文件写成 8028 字节、四键全部落盘）。**结论：这是测试手法造成的环境损坏，不是本轮代码缺陷。后续注入测试值只拨 UI 控件，不要整文件覆盖 prefs。**
44. **测试期改动已复原**：四个开关回到出厂值 `paddingDisplayCutouts=false`、`readBodyToLh=true`、`adaptSpecialStyle=true`、`useZhLayout=false`（读回确认）；调试埋点（`import { hilog }`、三处 `KI-A1-DBG`、`setter loaded=`）已全部删除，`grep -c "KI-A1-DBG" entry/src/main/ets/pages/Index.ets` = 0，删后重建仍 `BUILD SUCCESSFUL`。
45. **只代表 N 端模拟器**：以上结论基于 HarmonyOS 模拟器（API 26 运行时、`compatibleSdkVersion 5.0.0(12)`），未在真机验证；屏幕缺口与正文标记渲染两项在真机上仍需补验。

## 2026-10-31 N 端 KI-A9 阅读亮度四项（落库与面板通过，窗口亮度视觉效果未验）

27. **设备与构建**：HarmonyOS 模拟器 `127.0.0.1:5555`（1280×2832），包名 `io.legado.harmony`。`assembleHap` → `BUILD SUCCESSFUL in 20 s 155 ms`（33 任务，18 执行 / 15 最新），`hdc install -r` → `install bundle successfully`。首次构建失败并暴露一处真实缺漏：`10505001 Type '{...131 more...}' is missing the following properties from type 'ReaderSettingsSnapshot': readBrightness, showBrightnessView, brightnessVwPos, brightnessAuto At File: .../data/BackupRepository.ets:1241:5` —— 备份恢复返回的对象少了这四个字段，补上后通过。这条再次验证「新增配置字段必须同时改 `ReaderSettingsRepository` 的接口与 `BackupRepository` 恢复返回对象」，否则编译即报。

28. **上游口径核对**：字段在 `domain/model/settings/ReadSettings.kt:20-23`；**存储键与字段名不同**：`readBrightness` → `brightness`（`PreferKey.kt:151`）、`showBrightnessView` → `readBrightnessMode`（`:112`）、`brightnessVwPos` → `readBrightnessControlPosition`（`:193`）、`brightnessAuto` → `brightnessAuto`（`:194`）。备份忽略清单 `BackupConfig.readPrefKeys` 含前两者中的后两个（`readBrightnessMode`/`readBrightnessControlPosition`），不含 `brightness`/`brightnessAuto`。窗口亮度应用点 `ReadBookController.kt:3179-3187`，`BRIGHTNESS_OVERRIDE_NONE` 对应 HOS 的 `setWindowBrightness(-1)`。

29. **设置项上屏（两条都真上屏）**：设置 → 阅读界面 → 菜单 tab（`(493,2629)`）→ 读到「显示亮度调节控件」分组标题、「显示亮度视图 / 当前值与右侧 `⌄`」、「亮度条位置 / 当前值」。默认 `readBrightnessMode` 为 `"0"` 时只显示「显示亮度视图」一行，副标题「关闭」；切到「竖排」后「亮度条位置」行才出现（`ReaderSettingsPage.ets:926` 条件），副标题「右侧」。

30. **显示亮度视图落库（决定性）**：点「显示亮度视图」行 `(640,960)` 打开详情面板，读到标题「显示亮度视图」、描述、「关闭」（`[182,1330][1035,1383]`）、「横排」（`[182,1493][1098,1546]`）、「竖排」（`[182,1651][1098,1704]`）四个选项；点「横排」`(640,1519)` → 偏好文件从**没有该键**变为 `<string key="readBrightnessMode">1</string>`，返回列表副标题同步变「横排」。

31. **亮度条位置落库（决定性）**：注入 `readBrightnessMode=2` 重启后面板出现「亮度条位置 / 右侧」；点该行 `(640,1120)` 打开详情面板，读到「左侧」（`[182,1409][1035,1462]`）与「右侧」（`[182,1572][1098,1625]`），点「左侧」`(640,1435)` → `<string key="readBrightnessControlPosition">0</string>`，返回列表副标题变「左侧」。

32. **亮度与自动亮度两键落库**：默认启动后偏好文件里 `<double key="brightness" value="100.000000"/>` 与 `<bool key="brightnessAuto" value="true"/>` 已写出（与 `ReadSettings.kt:22-23` 默认一致）；注入 `brightness=20` + `brightnessAuto=false` 重启后两键分别读回 `20.000000` / `false`，证明读路径与快照回灌都对。

33. **未验部分：窗口亮度的视觉效果**。这是本组唯一没取到的证据。把 `brightness` 分别设为 `20` 与 `100`（`brightnessAuto` 均为 `false`）后各截一张全屏图，按 7×7 步长统计 `y∈[200,2632]`、`x∈[50,1230]` 区域的平均通道值，两张都是 **36.16** —— 一模一样的数字说明模拟器截图不叠加窗口亮度（`setWindowBrightness` 影响的是面板背光叠加层，不是合成帧内容）。`hidumper` 也没有对应读数可查。因此本项只到「代码路径核对 + 四键落库」，「调暗后确实变暗」需要在真机上看。

34. **已知差异**：亮度条上**没有**上游那个内联「自动亮度」按钮（上游在 `ReadBookMenuBarBottom.kt:316` 的 `BrightnessBar` 里用 `onToggleAuto` 实现），本地本轮只做了滑块；另外上游拖动滑块会绕开 `brightnessAuto` 直接写窗口亮度（`ReadBookController.kt:2465-2469`），本地滑块只落库，自动亮度开着时拖动不会立刻变亮。两条都记在 KNOWN-ISSUES KI-A9 的「已知差异」里。

35. **测试期改动已复原**：`readBrightnessMode` 回到 `0`、`readBrightnessControlPosition` 回到 `1`、`brightness` 回到 `100.000000`、`brightnessAuto` 回到 `true`，四次 `hdc file recv` 读回确认。

36. **只代表 N 端模拟器**：以上均为 HarmonyOS 模拟器（API 26 镜像，工程 `compatibleSdkVersion` 5.0.0(12)）的实测结果，不代表真机窗口亮度行为，也不代表平板/折叠屏形态。

## 2026-10-31 N 端 KI-A3 禁用返回键（开关与落库通过）

19. **设备与构建**：HarmonyOS 模拟器 `127.0.0.1:5555`（1280×2832），包名 `io.legado.harmony`。`assembleHap` → `BUILD SUCCESSFUL in 31 s 592 ms`（33 任务，17 执行 / 16 最新），`hdc install -r` → `install bundle successfully`。

20. **上游判据（决定本轮只做可配、不做拦截）**：`grep -rni "disablereturn" --include=*.kt --include=*.xml`（排除 `build/`）共 21 处，全部是字段/偏好键/落库/映射/两处设置项/Intent 链/五处资源字符串/一个单元测试断言；**没有任何 `BackHandler`、`onBackPressed`、`OnBackPressedCallback`、`KEYCODE_BACK` 消费点**。阅读页真正的返回键处理在 `ReadBookRouteScreen.kt:240-249`，分支只有 sheet/搜索/自动翻页/菜单层级，`canHandleBack` 在 `:220` 取的是 `isTopRoute`。所以本地只做可配 + 落库 + 随备份，不加 `onBackPress()` 拦截。

21. **设置项上屏**：设置 → 阅读界面 → 更多 tab（`(1084,2629)`）→ 连续三次 `swipe 640 2200 640 1000/1300 300` 后读到「禁用返回键 / 阻止阅读时返回键退出」，`Toggle` bounds `[1057,1800][1183,1870]`。此前该条目走 `showNotMigrated`，现在是真的 `MenuSettingSwitch`。

22. **拨动落库（决定性）**：点击 `(1120,1835)` → 偏好文件从**没有该键**变为 `<bool key="disableReturnKey" value="true"/>`，同一时刻 `uitest dumpLayout` 读到该 Toggle 的 `checked` 由 `false` 变 `true`；再点一次 → `<bool key="disableReturnKey" value="false"/>`。

23. **重启持久 + 面板回显**：用 `hdc file recv` 拉回 `legado_reader_settings`，把该键改成 `true` 后 `hdc file send` 推回，`aa force-stop` + `aa start` 重启，进「阅读界面 → 更多」滚到该条，`Toggle` 的 `checked` 为 `true` —— 证明读路径（`ReaderSettingsRepository.ets:709`）与快照回灌都对。

24. **测试期改动已复原**：最终 `disableReturnKey` 为 `false`（出厂值）。

25. **未验部分：拦截效果本身**。这一项**本来就不该有拦截效果**（上游没有消费点），所以「开启后按返回键不退出」不是本轮要验的东西；如果后续产品要加拦截，需要另立条目并明确它与阅读页下拉/侧滑退出手势的冲突处理。

26. **结论只代表 N 端模拟器**：本轮证明了「开关 → 落库 → 重启回显 → 备份序列化」这条链路通，未涉及拦截行为。


## 2026-10-31 N 端 KI-A6 自动切换日夜模式提醒（弹出与自动消失通过，按钮点击仍未验）

10. **设备与构建**：HarmonyOS 模拟器 `127.0.0.1:5555`（1280×2832），包名 `io.legado.harmony`。`assembleHap` → `BUILD SUCCESSFUL in 31 s 589 ms`（33 任务，17 执行 / 16 最新），`hdc install -r` → `install bundle successfully`。

11. **上游口径核对**：`ReadSettings.kt:43` `autoSuggestDayNight: Boolean = false`；`PreferKey.kt:120` 键名同名；采集在 `ReadBookRouteScreen.kt:1089-1138`（`repeatOnLifecycle(RESUMED)` + `TYPE_LIGHT` + `SENSOR_DELAY_NORMAL` + 首帧 `delay(1.seconds)` + 循环 `delay(15.minutes)`）；判定在 `ReadStyleDelegate.kt:503-555`（`DARK_LUX_THRESHOLD = 8f`、`BRIGHT_LUX_THRESHOLD = 100f`、`LIGHT_LUMINANCE_THRESHOLD = 0.35`、`REMINDER_COOLDOWN_MS = 10 * 60 * 1000L`）；胶囊在 `ReadBookFloatingActionBar.kt:122-156`（贴底居中、`padding(bottom = 88.dp)`、`LaunchedEffect` 5 秒自动消失、切换/关闭两个 `MediumTonalButton`）。

12. **环境光传感器在模拟器上真实存在（决定性）**：`hdc shell "hidumper -s SensorService -a '-l'"` 输出含 `sensorType:AMBIENT LIGHT |sensorId:5 |sensorName:light |vendorName:Taos |maxRange:10000`；应用订阅后 `hdc shell "hidumper -s SensorService -a '-o'"` 输出含 `AMBIENT LIGHT |sensorId:5 |channelSize:1`。这条证据直接作废了 KNOWN-ISSUES 里原先「本轮不做」的判断。

13. **设置项上屏**：设置 → 阅读界面 → 更多 tab（`(1084,2629)`）下滚后读到「自动切换日夜模式提醒 / 根据环境光提醒切换浅色/深色模式」，`Toggle` 可点，点后偏好文件写出 `<bool key="autoSuggestDayNight" value="true"/>`。

14. **胶囊弹出（决定性）**：用 `hdc file recv` 拉回 `legado_reader_settings` → 本地改 `autoSuggestDayNight=true`、`readerNightMode=false` → `hdc file send` 推回 → `aa force-stop` + `aa start` → 点书架「最近阅读」卡片 `(640,900)` 进阅读页，随后连续 4 轮 `uitest dumpLayout`：第 1、2 轮读到「当前环境光较暗，是否切换至深色模式？」（bounds `[114,2307][934,2360]`）与「关闭」（`[1074,2307][1166,2360]`），第 3、4 轮消失。**弹出与 5 秒自动消失都成立**（模拟器环境光恒为暗，`lux <= 8`，且当前背景是浅色，正好命中上游 `!isNight && lux <= 8` 分支）。

15. **未验部分：胶囊按钮点击**（r299 已解除「进不去阅读页」这一前提：胶囊的**弹出与 5 秒自动消失已实测通过**，只有「点击切换」仍因注入限制未验，详见 r299 节的 KI-A6 节）。原记录如下：多次尝试 `uitest uiInput click` 命中「切换」与「关闭」的坐标（`(640,2333)`、`(520,2333)`、`(524,2333)`、`(500,2333)`），偏好文件里的 `readerNightMode` 始终未变；加 `hilog` 埋点（tag `KI-A6`，`checkReaderDayNightReminder` / `acceptReaderDayNightReminder` / `dismissReaderDayNightReminder` 三处）后重装重跑，`hdc shell "hilog -x"` 抓 6445 行也没有一条 `KI-A6`，说明点击根本没走到处理函数（不是埋点位置问题）。当时判断的根因（**r299 已证伪**，`the-metamorphosis` 正文完好、阅读页可进，胶囊也确实弹出了）：**没有一本正文可读的书**——本地书正文文件已丢失（`find /data/app/el2/100/base/io.legado.harmony -name '*1793348394426*'` 无结果），点书架卡片只进「缺正文」详情页，点详情页的「阅读」入口（`(1028,2618)` `Row`）也停在详情页；停不住阅读页就无法在胶囊出现的 5 秒窗口内完成「确认位置 + 点击」。这与 KI-D2/KI-D6 记录的手势限制同源。代码侧已保证 `hitTestBehavior(HitTestMode.Default)` + `zIndex(900)`，`acceptReaderDayNightReminder()` 直接调 `toggleReaderNightMode()`。

16. **调试埋点已移除**：排查用的三处 `hilog.info` 与 `import { hilog }` 在最终构建前删除，`grep -c hilog entry/src/main/ets/pages/Index.ets` = 0，删除后重新构建通过（`BUILD SUCCESSFUL in 25 s 357 ms`）。

17. **测试期改动已复原**：`readerNightMode=true`、`autoSuggestDayNight=false`（均为出厂值）。

18. **结论只代表 N 端模拟器**：真机上环境光会随时间变化，提醒的触发条件（`lux <= 8` / `lux >= 100`）与背景亮度判断需要在实机上复验；本轮只证明了「订阅 → 判定 → 弹出 → 5 秒消失」这条链路是通的。


## 2026-10-31 N 端 KI-D2 选中文字菜单三项（面板与落库通过，阅读页菜单渲染未验）

- 设备：HOS 模拟器 `127.0.0.1:5555`（API 26，1280×2832），包名 `io.legado.harmony`。`assembleHap` 通过（`BUILD SUCCESSFUL in 22 s 184 ms`，33 项任务 17 执行 / 16 最新），HAP 覆盖安装成功。
- **编译期修掉一处 ArkTS 违规**：`ReaderSelectionMenu.ets` 初版用 `Record<string, Object>` 接 `JSON.parse` 结果并写匿名对象字面量，`assembleHap` 报 `10605038 ArkTS Compiler Error / Object literal must correspond to some explicitly declared class or interface (arkts-no-untyped-obj-literals) At File: .../data/ReaderSelectionMenu.ets:139:44`。改为具名 `interface SelectionMenuConfigRecord { id?: string; enabled?: boolean; showState?: number; }` 后通过。这条 ArkTS 约束在上游（Kotlin）不存在，是移植 `GSON.fromJsonObject<List<SelectionMenuConfigItem>>` 时必须显式建模的地方。
- **设置项上屏**：设置 → 阅读界面 → 更多 tab，滚动到底可见「选中文字菜单 / 配置文本选择后的操作 / ›」，已去掉原先的「未迁移」标记（`migrated: true`）。注意该入口不在「全局」tab，且「更多」页需要连续几次上滑才露出来。
- **面板内容**：标题「选中文字菜单」、描述「排序、分组与图标开关，保存后随备份同步」、两个开关「展开文字菜单」（副标题「折叠菜单项是否与一级菜单同排展开」）与「显示菜单图标」（「在文字菜单操作项旁显示图标」）、三个分组「主菜单」（14 项：复制、书签、划线 / 笔记、分享、浏览器、朗读、字典、替换、编辑、AI 净化、AI 改写、全文搜索、插入(前)、插入(后)）、「折叠菜单 / 隐藏项目」、底部说明与「保存」按钮。行内四个图标按钮依次是上移、下移、移入折叠、隐藏；折叠组是上移、下移、移回一级、隐藏；隐藏组只有恢复。
- **落库格式（决定性证据，与上游逐字段一致）**：把「分享」移入折叠后点「保存」，`cat .../preferences/legado_reader_settings` 实测写出
  `<string key="textSelectMenuConfig">[{&quot;id&quot;:&quot;menu_copy&quot;,&quot;enabled&quot;:true,&quot;showState&quot;:0},…,{&quot;id&quot;:&quot;menu_share_str&quot;,&quot;enabled&quot;:false,&quot;showState&quot;:1},…]</string>`
  —— 数组元素字段名 `id`/`enabled`/`showState` 与上游 `ReadBookController.kt:3351` 的 `SelectionMenuConfigItem` 完全相同，`enabled` 恒等于 `showState == 0`、`showState` 0/1/2 的三分组语义也与 `:3316` 的注释一致；未被编排的条目按内置顺序保留在串里。随后把「划线 / 笔记」也移入折叠并保存，`menu_mark` 同样变 `enabled:false, showState:1`，且它在面板折叠组里排在「分享」之前（与配置串里的顺序一致，验证了「读回顺序 = 配置串顺序」）。
- **两个布尔键落库**：`<bool key="expandTextMenu" value="false"/>`、`<bool key="showSelectMenuIcon" value="true"/>`，与上游 `ReadSettings.kt:51-52` 的默认值一致；面板上的两个开关可直接切换并即时落库。
- **未验的部分（本记录不写「渲染通过」的原因）**：阅读页划词菜单的实际渲染（按 `showState` 显隐、`expandTextMenu` 决定平铺还是「更多」、图标开关）**未能取证**。r299 已换用正文完好的书（`the-metamorphosis`、`zh-book`）重测，`uitest uiInput longClick`、`uinput -T -d … -u … 1500`（1500ms 长按）仍然只得到 27 个节点、没有任何「复制 / 书签 / 划线」，确认与「有没有正文」无关，纯属注入限制。原记录：该模拟器上本地书 `test-book` 与 `dup-probe` 的正文文件都已丢失，阅读页正文位置显示的是书目 JSON 文本，没有可长按选中的正常正文；`uitest uiInput longClick`、`doubleClick`、`drag`（含 `drag x y x y 1500` 与 `drag x1 y x2 y 2000`）四种注入在 `dumpLayout` 里都只得到 27 个节点（正文 + 页码），没有任何「复制 / 书签 / 划线」文本节点。这与本文档 KI-D6 节已记录的限制是同一原因（该模拟器正文长按与单击手势注入都只落在系统层），不是本次代码的问题：`selectText` 为 `true`、三处 `.textSelectable(...)` 与 `.bindSelectionMenu(TextSpanType.TEXT, …, TextResponseType.LONG_PRESS, …)` 都在位。
- **已知差异**：本地只有 `menu_copy`/`menu_bookmark`/`menu_mark` 三项有真实动作，其余 11 项是尚未迁移的能力，面板里可编排、阅读页菜单里不显示（配置串照常保存，待能力接入后自然出现）。这是按「上游没有就不要这个效果」的取舍，不是配置丢失。
- **测试期改动已复原**：`textSelectMenuConfig` 回空串、`expandTextMenu=false`、`showSelectMenuIcon=true`、`selectText=true`，复原后重新拉取偏好文件确认（前三项分别为空串 / false / true）。
- 本记录只代表 N 端模拟器结果，不替代 E 端结论，也不代表 API 12 真机兼容。

## 2026-10-31 N 端 KI-D4 横屏双页（通过）

- 设备：HOS 模拟器 `127.0.0.1:5555`（API 26，1280×2832），包名 `io.legado.harmony`。`assembleHap` 通过（`BUILD SUCCESSFUL in 25 s 835 ms`，33 项任务 17 执行 / 16 最新），HAP 覆盖安装成功。
- **编译期两处真实错误**：① `LocalReaderPaginator.ets` 的 `lineColumns` 是 `LocalReaderPage` 的必填字段，`ReaderPage.ets` 里补的 `nextPages.push({ …, titleOnly: true })` 缺它，报 `10505001 Argument of type '{ lines: undefined[]; startPosition: number; endPosition: number; titleOnly: true; }' is not assignable to parameter of type 'LocalReaderPage'.`；② `ForEach` 的 itemGenerator 里不能写 `return`，原来按列过滤写成 `if (…) { return; }`，报 `10905209 ArkTS Compiler Error / Only UI component syntax can be written here.`，改为 `if (…) { … }` 包裹整段组件。这两条都是 ArkTS/ArkUI 相对上游 Kotlin 的额外约束。
- **接线遗漏与后果（值得记录）**：第一次构建能过、面板也能点，但点了不落库。原因是 `Index.ets` 里 `ReaderSettingsPage` 的 `onDoubleHorizontalPageChange` 回调 4 处全没插上（`ReaderPage` 的 prop 也漏了），组件走的是默认空实现。用脚本按 `onShowSelectMenuIconChange` 那行做锚点补齐 4 处回调、按 `textSelectMenuConfig` 那行补齐 5 处 prop（快照 + `ReaderPage` + 4 处 `ReaderSettingsPage`）后才真正通。**教训：新增配置项时，prop 与回调必须成对核对 `grep` 命中数，不能只确认「构建通过」。**
- **设置项上屏**：设置 → 阅读界面 → 更多 tab，上滑一次可见「横屏双页 / 全局单页 / ›」（`migrated: true`，副标题随档位变化）。
- **面板上屏**：点开后标题「横屏双页」、描述「选择单页、双页以及双页生效的屏幕形态」、四档选项「全局单页」「全局双页」「横屏双页」「平板/横屏双页」、底部提示「选择后立即应用并保存；自定义内容需点击保存。」（说明条件链已补上该项，不再显示「仅展示选择预览」）。
- **落库**：选「全局双页」后偏好文件出现 `<string key="doubleHorizontalPage">1</string>`。
- **决定性对照（三组，同一本书同一章）**：
  - 档位 `1`（全局双页）：正文分成左右两栏，`uitest dumpLayout` 读到两块文本 `[56,342][584,2591]` 与 `[696,342][1224,2591]`，两栏各占半屏宽并各自带左右内边距。
  - 档位 `0`（全局单页）：正文整块铺满，`[112,342][1280,445]` 起连续多行直到屏幕右侧。
  - 档位 `2`（横屏双页）在竖屏下：仍是单栏，与 `0` 一致——证明判定确实按「横屏且非滚动」把关，而不是简单按档位恒双列。
- 三组数据互相印证了列数判定（`readerColumnCount`）、列宽折算（`columnStride = 视口宽 / 列数`）与按列渲染（`Row` + `ForEach`）三处都真的生效。
- **未验部分**：平板判定（`LANDSCAPE_OR_TABLET` 的 `isTablet` 分支）在模拟器上无平板形态可切，只做代码核对；底部两端对齐在双列下被主动关闭（见 KNOWN-ISSUES KI-D4 已知差异），该模式在双列下未做像素级比对。
- 测试期改动已复原：`doubleHorizontalPage` 回到 `0`。
- 本节结论只代表 N 端模拟器本次构建，不代表真机旋转、折叠屏与分屏形态。

## 2026-10-31 N 端 KI-D1 自定义翻页按键与鼠标滚轮翻页（落库与接线通过，按键与滚轮实际翻页未验）

- 设备与构建：模拟器 `127.0.0.1:5555`（1280×2832，HOS）。`assembleHap` 通过，`BUILD SUCCESSFUL in 36 s 264 ms`，33 项任务 17 执行 / 16 最新；仅既有 ArkTS 警告与 `No signingConfig found for product default`。`hdc install -r` 回 `install bundle successfully`。
- 面板上屏：设置 → 阅读界面 → 底部「更多」tab（y 2618）→ 下滚到「翻页控制」段，读到「鼠标滚轮翻页 / 分页模式下用滚轮翻页」（Toggle bounds x 1057–1183）与「自定义翻页按键 / 未配置」。副标题不再是写死的「尚未迁移」。
- 详情面板：点「自定义翻页按键」读到标题、描述「录制物理按键作为上一页/下一页」、「上一页按键」+ 输入框（hint「按键码，多个用英文逗号分隔」，bounds `[140,1189][1140,1357]`）、「下一页按键」+ 输入框（`[140,1469][1140,1637]`）、两句口径说明、「重置」「确定」。
- 按键串落库：聚焦第一个输入框输入 `2069` 点「确定」后，偏好文件出现 `<string key="prevKeyCodes">2069</string>`，列表副标题同步变为 **`上 2069 / 下 —`**；清空后副标题回「未配置」、偏好文件两串为空。
- 滚轮开关落库：点开关 → `<bool key="mouseWheelPage" value="false"/>`；再点一次回 `value="true"`。符合上游默认开（`ReadSettings.kt:28`）。
- **未验（工具限制）**：按键真正触发翻页、鼠标滚轮真正翻页都没能取证。三项输入注入手段全部无效——`uitest uiInput keyEvent 2069`（PAGE_DOWN）/`2050`（SPACE）/`17`（VOLUME_DOWN）在阅读页不翻页；`uinput -K -d <code> -u <code>` 无反应；`uinput -M -m 640 1400` + `-s 1..10` 连设置页明显可滚动的列表都滚不动（首项仍是「设置 / 外观 / 高级 / 阅读界面 / 朗读设置」）。既然注入在已知可滚动的列表上也不生效，判定为该模拟器的注入能力限制，不是本次代码问题。
- 只读证据链：`syncVolumeKeyPage`（`ReaderPage.ets:479`）按签名重订阅、`collectPageKeyCodes`（`:528`）只收 `isConsumablePageKey`（`:508`）放行的五键、`matchPageKey`（`:545`）自定义键先于音量键，与上游 `ReadBookController.kt:2699`/`:3241-3255` 同序；滚轮在根容器 `onAxisEvent`（`:3869`）且只在分页模式接管，与上游 `:2845` 的早退条件一致。
- 已知差异：`inputConsumer` 在 API 20 及以下只放开音量键、API 21+ 才加媒体三键，其余键值本地照存照备份但需窗口持焦点才能经 `onKeyEvent` 生效；上游 `onKeyDown` 无此限制。详情见 `docs/KNOWN-ISSUES.md` KI-D1。
- 测试期改动已复原：`prevKeyCodes` 与 `nextKeyCodes` 为空串、`mouseWheelPage` 为 `true`。
- 本节只代表 N 端模拟器，不代表真机与 API 12 兼容结论。

## 2026-10-31 N 端 KI-C3 下划线四个几何参数（分页模式通过，滚动模式未接）

1. 设备与构建：HOS 模拟器 `127.0.0.1:5555`（Mate 90 Pro，1280×2832），`io.legado.harmony`。
   `assembleHap` 通过：`BUILD SUCCESSFUL in 31 s 652 ms`，33 项任务 17 执行 / 16 最新，
   仅有既存的 ArkTS「Function may throw exceptions」警告与 `WARN: No signingConfig found for product default`。
   `hdc install -r` 返回 `install bundle successfully`。

2. 面板上屏：设置 → 阅读界面 → 排版图标 →「正文」tab →「效果」→「文字效果」面板。
   打开「正文下划线」后，面板依次出现「夜间下划线颜色（#ADADAD）」「下划线粗细 1」「离字间距 10」
   「撑满整行 / 下划线延伸到页面左右边距」，勾选「虚线下划线」后再展开「实线段长」与「空隙长度」两个滑块。
   四个新控件全部真上屏（`uitest dumpLayout` 读到），不是占位。

3. 落库：`cat /data/app/el2/100/base/io.legado.harmony/haps/entry/preferences/legado_reader_settings` 得到
   `<bool key="underlineExtend" value="false"/>`、`<double key="underlinePadding" value="10.000000"/>`、
   `<double key="dottedBase" value="6.000000"/>`、`<double key="dottedRatio" value="6.000000"/>`，四个键名与默认值都与上游同名同默认。

4. **偏移量决定性证据（三档线性）**：注入 `underlinePadding` 分别为 0 / 10 / 20，重启后进阅读页截图，
   用 PIL 找出下划线色（`#ADADAD`，判据 `abs(r-173)<45 且 abs(g-173)<45 且 abs(b-173)<45 且三通道互差<12`）
   在每行出现的像素行，取第一条完整线段的 y：
   `padding=0 → y 409..411`、`padding=10 → y 444..446`、`padding=20 → y 478..481`。
   相邻档差分别为 35 与 34 像素，等于 10vp × 3.5 屏幕密度 —— **线性关系成立，且与上游
   `(underlinePadding - 10).dpToPx()` 的相对量口径一致**（默认 10 时相对偏移为 0）。

5. **延伸开关决定性证据（同一行前后对比）**：`underlineExtend=false` 时，短行（最后一行不足整行）
   线段为 `x0=56 x1=720`（宽 665）；改成 `true` 后同一行变成 `x0=56 x1=1223`（宽 1168），
   且该页所有行都统一到 `56..1223`。即关闭时线只到该行文字右边界、打开时延伸到正文列宽，与上游
   `ReaderPaginator.kt:449` 的 `extendToColumn` 分支（`columnLeft()` 到 `columnLeft() + contentWidthPx`）逐字对应。

6. **虚线两参数决定性证据（段数反比）**：`dottedLine=true` 时统计同一行线段的连通段数——
   `dottedBase=6, dottedRatio=6` 得 **34 段**（命中像素 624）；
   `dottedBase=20, dottedRatio=6` 得 **18 段**（命中像素 913）。
   段数随实线段长变长而减少、每段变长使总命中像素增加，说明 `strokeDashArray([dottedBase, dottedRatio])`
   真的在按这两个值画 dash/gap，不是系统固定样式的虚线。

7. 只读证据链（未改代码即可复现）：`grep -n "fontSize + 4"` 与本轮无关；本轮的自绘入口用
   `grep -n "ReaderUnderlineLayer" entry/src/main/ets/pages/ReaderPage.ets` 可定位，
   `grep -c "this.underline ? TextDecorationType.Underline"` 现为 2（都留在滚动模式的
   `getReaderHighlightTextRuns()` 里，是刻意的已知差异）。

8. 已知差异（如实记录）：**滚动模式未接这四项**。滚动模式拿不到逐行几何，无法自绘 `Line()`，
   仍用 `Text.decoration` 表达下划线，所以虚线段长/间隔/偏移/延伸只在分页模式生效。
   这一点写进了代码注释与 `KNOWN-ISSUES` KI-C3。

9. 测试期改动已复原：`underline` 回到 `false`、`underlinePadding` 10、`underlineExtend` false、
   `dottedLine` false、`dottedBase` 6、`dottedRatio` 6，偏好文件里四个键与初始值一致。

10. 本节只代表 N 端模拟器；未在真机、EInk 模式或其他密度屏上验证，密度的 3.5 只是本模拟器的换算系数。

## 2026-10-31 N 端 KI-C4 标题排版十四项（通过）

1. 设备与构建：HOS 模拟器 `127.0.0.1:5555`（Mate 90 Pro，1280×2832），`io.legado.harmony`。
   `assembleHap` 通过两次（修 UI 缺陷中各一次）：`BUILD SUCCESSFUL in 21 s 876 ms`、`BUILD SUCCESSFUL in 22 s 102 ms`，
   均 33 项任务 17 执行 / 16 最新，`WARN: No signingConfig found for product default`（既有，不影响安装）。
2. 面板上屏：设置 → 阅读界面 →「排版」→「标题」tab，14 组控件全部可读到：标题位置（居左显示/居中显示/隐藏标题）、
   标题字号（正文 + 4）、字号相对正文开关、标题上间距、标题下间距、标题字重（纤细/常规/中等/粗体/特粗）、
   标题行距、标题副项行距、日间标题颜色、夜间标题颜色、标题颜色跟随正文、标题分段（不分段/按字数/按分隔符/按正则）、
   分段字数、副标题字号比例。
3. 落库（偏好文件 `/data/app/el2/100/base/io.legado.harmony/haps/entry/preferences/legado_reader_settings`）：
   点「居中显示」→ `titleMode=1.000000`；点「纤细」→ `titleBold=300.000000`；
   点日间色板第 4 颗（`#FFFFFF`）→ `titleColor=#FFFFFF`，面板标签同步变「日间标题颜色（#FFFFFF）」；
   点「按字数」→ `titleSegType=1.000000` 且联动出现「分段字数」行（`titleSegDistance=4`、`titleSegScaling=1`、`titleSegFlag` 空串）。
4. 渲染决定性证据（正反对照）：`titleSegType=1`（按 4 字分段）时 `uitest dumpLayout` 读到**两个独立 Text 节点**
   「第二章」`[56,157][1224,342]` 与「乙」`[56,342][1224,527]`，且都居中；把 `titleSegType` 改回 `0` 重进同一章，
   变成**单个**「第二章 乙」`[56,157][1224,342]`（高度从两行收回一行）。反向对照排除巧合。
5. 隐藏标题：`titleMode=2` 时正文直接从 `[56,157]` 开始（正是原先标题所在位置），标题节点完全不存在，
   标题页也不再单独占一页（分页判定改走 `isReaderTitleVisible()`）。
6. 标题颜色决定性证据：夜间模式下注入 `titleColorNight=#FF8C00`，截图像素统计得**标题区（y 120–400）橙色像素 6153 个、
   整页也是 6153 个**——所有橙色都落在标题区内，正文零橙色。改回默认后标题恢复正文色。
7. 本轮修掉两个真实缺陷（都由设备验收暴露，非臆测）：
   - 「标题」tab 内容超出屏幕且**不能滚动**：面板容器 `.width('88%').height('86%')` 而标题 tab 有 14 组控件，
     底部被裁到屏外，`dumpLayout` 里该分支没有任何 `scrollable: true` 的 `Scroll`。
     上游 `ui/book/read/sheet/TypographyTabs.kt` 的标题页在可滚动容器内，本地没有 → 属真实缺失。
     修法：该分支外包 `Scroll(){ … }.width('100%').layoutWeight(1).scrollBar(BarState.Off)`，改后 dump 出现
     `Scroll [77,679][1203,2552]`，滚到底可读到末尾说明文字。
   - 选项行选中态**不刷新**：`TitleChoiceRow` 的 `ForEach` key 生成函数不含 `selectedIndex`，数组内容不变时
     ForEach 判定无需更新 → 子项不重建 → 按钮高亮与右侧标签都停在旧值（偏好文件已落库，界面却显示旧值，
     极易被误判成「改了没生效」）。连续两次 `dumpLayout` 的 json md5 完全相同可佐证。
     修法：key 改为 `` `${title}-${index}-${label}-${selectedIndex}` ``；改后复查截图确认高亮与右侧标签同步。
8. 取证方法备忘：`uitest dumpLayout` 的 json 内中文为 GBK 乱码，须用 python 以 `encoding='utf-8'` 读入后落文件再看；
   判断「按钮是否高亮」**不能靠 dump**（dump 只给文本与 bounds，无颜色），须 `snapshot_display` 截图 + PIL 裁剪 + 读图。
   滚动后布局整体上移，每次点击前必须重新 dump 取当前 bounds。
9. 测试期写入的 14 个 `title*` 键已全部复原（验收后偏好文件里 0 个 `title*` 键，回到默认值）。
10. 只代表 N 端模拟器结果，不替代真机与其它设备形态。

## 2026-10-31 N 端 KI-C1/KI-C2 正文颜色与自定义背景（通过；背景图片渲染已于 r299 补像素取证）

1. **设备与构建**：HOS 模拟器 `127.0.0.1:5555`（API 26，1280×2832），`assembleHap` → `BUILD SUCCESSFUL in 32 s 579 ms`（33 任务 17 执行 / 16 最新），HAP 覆盖安装 `install bundle successfully`。
2. **面板上屏**：设置 → 阅读界面 → 「长按自定义」`(951,675)` 打开「自定义阅读背景」，dump 读到全部条目：`日间背景颜色`、`夜间背景颜色`、`日间背景图片/未选择图片/选择`、`夜间背景图片/…`、`背景透明度 100`、`日间深色状态栏图标`、`夜间深色状态栏图标`、四个文字色/强调色板；底部提示为「选择后立即应用并保存；自定义内容需点击保存。」（不是「仅展示选择预览」）。
3. **色板落库**：日间色板第一颗（`#FFFFFF`）中心 `(248,875)` → `bgStr` = `#FFFFFF`；夜间色板最后一颗 `(1179,1180)` → `bgStrNight` = `#000000`；文字颜色日间板点 `(503,1933)` → `textColorNight` = `#FFFFFF`，点 `(701,1933)` → `#000000`。`bgType`/`bgTypeNight` 均为 `0.000000`。
4. **状态栏图标决定性对比**：`darkStatusIconNight = false` 时阅读页状态栏（y 0..120 全宽）亮像素 **6726**；改为 `true` 后同一区域亮像素 **0**。证明 `setWindowSystemBarProperties({ statusBarContentColor })` 真的生效。
5. **纸色决定性证据**：`readerNightMode` 由 `true` 改 `false` 后，日间 `bgStr = #FFFFFF` 生效——阅读页中心像素 `(255,255,255)`；未设置自定义时默认纸色不是纯白，两次截图对比排除了巧合。
6. **正文文字色决定性证据**：注入 `textColor = #DB4B4B` 后重进阅读页，截图彩色像素统计 top8 全为红色系（`(213,77,77)`/`(220,76,75)`/…），正文与章节标题同时变红；改回 `#38383B` 后恢复正常深灰。
7. **图片选择器可弹出**：点「选择」`(1017,1385)` 后系统 `DocumentViewPicker` 正常弹出（「最近 / 浏览 / ×」）。~~但模拟器里没有可选图片，且沙箱不可写，无法注入测试图，因此背景图片的渲染与透明度只到代码层核对。~~ **该阻塞点已于 r299 解除**：`MSYS_NO_PATHCONV=1 hdc file send` 可把图片推到 `/storage/media/100/local/files/Docs/Download/`（此前报 `permission denied` 是 MSYS 路径转换导致，不是权限问题），再走应用内选择器注入。实测纯绿图 → 整屏 `(0,200,80)`、红图 → `(254,0,0)`；`bgAlpha` 100/50/0 → `(0,200,80)`/`(0,100,40)`/`(0,0,0)`，三点连线证明 `backgroundImageAlpha()` 真实作用于合成。详见 r299 节的 KI-C1/KI-C2 节。
8. **测试期改动已全部复原**：`textColor=#38383B`、`textColorNight=#D8D8DC`、`textAccentColor=#834E00`、`textAccentColorNight=#FE4D55`、`bgStr=''`、`bgStrNight=''`、`bgType=0`、`bgTypeNight=0`、`bgAlpha=100`、`darkStatusIcon=true`、`darkStatusIconNight=false`（已重新拉取偏好文件确认）。
9. **上游口径核对**：`textAccentColor` 在上游只驱动链接/搜索结果/朗读段落三处着色（`ReaderCanvasSurface.kt:2997`），本地这三条路径都没有，故按约束只做可配+落库+随备份；`bgAlpha` 与上游 `ReaderBackgroundAlpha.kt` 一致**只作用于背景图片**，不作用于纯色背景。
10. 本条只代表 N 端模拟器结论。

## 2026-10-31 N 端 KI-C5 简繁转换（通过）

1. 设备与构建：HOS 模拟器 `127.0.0.1:5555`（API 26，1280×2832）。`assembleHap` 通过 `BUILD SUCCESSFUL in 36 s 683 ms`（33 任务 17 执行 / 16 最新），HAP 覆盖安装成功。
2. 转换能力先核对：HOS 不自带简繁字表，改用系统 ICU 的 `i18n.Transliterator`（`@kit.LocalizationKit`）。`ChineseTextConverter` 先 `getAvailableIDs()` 判断 `Traditional-Simplified` / `Simplified-Traditional` 是否存在再 `getInstance()`，本机两个 ID 都在，转换器可用（否则会降级为原样返回）。
3. 设置项上屏：设置 → 阅读界面 → 排版图标（`(1091,459)`）→ 排版面板「正文」页最后一条为「中文简繁体转换」，副标题显示当前档位，初始为「关闭简繁转换」。
4. 详情面板：点开后标题「中文简繁体转换」、描述「按档位转换正文与章节标题的字形」、三个选项「关闭简繁转换」「繁体转简体」「简体转繁体」，底部提示为「选择后立即应用并保存；自定义内容需点击保存。」（不是「仅展示选择预览」）。
5. 落库实测（读 `/data/app/el2/100/base/io.legado.harmony/haps/entry/preferences/legado_reader_settings`）：选「繁体转简体」→ `chineseConverterType` = `1.000000`；选「简体转繁体」→ `2.000000`；选回「关闭简繁转换」→ `0.000000`。三档往返可写。
6. **正文真的变了（决定性证据）**：档位取 `2` 后回书架打开第一本书，`uitest dumpLayout` 读到的正文文本为「第一卷 風起 / 這一段是佔位正文，用來拉 / 開章節之間的距離，使得每一個 / 章節標題之間的字符數足夠多。」——正文与章节标题**同时**变繁体；档位改回 `0` 后重进同一章，文本恢复为「第一卷 风起 / 这一段是占位正文，用来拉 / 开章节之间的距离」。方向相反的两次对比，排除巧合。
7. 备份口径：`chineseConverterType` 不在上游 `BackupConfig.readPrefKeys` 忽略清单里，本地同样补了导出（`BackupRepository.ets:576`，`int`）与恢复（`:1251`）。
8. 已知差异：上游 `ChineseUtils.t2s` 带约 110 条排除词（一词多形的场景），ICU 没有这层修正，个别词形可能不同。属转换库差异，不是接线缺失。
9. 测试期改动已复原：`chineseConverterType` 已回到 `0.000000`（重新拉取确认）。

只代表 N 端模拟器上的结果，Android 侧未做同机对比。

## 2026-10-31 N 端 KI-A7 触感反馈两项（开关落库通过，振动本身未验）

- 设备：HOS 模拟器 `127.0.0.1:5555`（API 26，1280×2832），包名 `io.legado.harmony`。`assembleHap` 通过（`BUILD SUCCESSFUL in 32 s 535 ms`，33 项任务 17 执行 / 16 最新，只有 `ReaderBookmarkBadgeRepository.ets` 的既有警告），HAP 覆盖安装成功。
- **上游口径先核对清楚，避免做出上游没有的效果**：`sliderVibrator`（`ReadSettings.kt:36`）在上游只出现在设置项（`MoreConfigSheet.kt:360`、`ReadConfigScreen.kt:293`）与仓储读写，`feature/reader` 目录零消费点，`ReadBookMenuBarBottom.kt` 也没有 haptic —— 即**上游本身没有「滑进度条振动」这个效果**，本地因此只做可配 + 落库 + 随备份，不给进度条加振动。`selectVibrator`（`:41`）是真消费：`ReadBookRouteScreen.kt:755` → `ReaderCanvasSurface.kt:1109`（长按选中首个词）与 `:1225`（拖手柄后选区变化）。
- **两个开关都上屏**：设置 → 阅读界面 → 更多 → 下滑到「其他」段，「进度条触感反馈」（副标题「拖动时提供触觉反馈」）与「文字选择触感反馈」（副标题「选择正文时提供触觉反馈」）均已是真开关，不再是「尚未迁移」占位。
- **落库实测（关键证据）**：`uitest dumpLayout` 定位到两行的 `Toggle` 节点自带 bounds（进度条行 `[1057,1679][1183,1749]`，文字选择行 `[1057,2340][1183,2410]`），点其中心后直接读偏好文件 `/data/app/el2/100/base/io.legado.harmony/haps/entry/preferences/legado_reader_settings`：
  - `uitest uiInput click 1120 1714` → `sliderVibrator` 由 `true` 变 `false`（此前一次点击已置 `true`，说明写入是双向的）。
  - `uitest uiInput click 1120 2375` → `selectVibrator` 由 `false` 变 `true`；再点一次 → 回到 `false`。
  两键都能随开关往返，且字段名与存储键名一致。
- **未完成的部分（本记录不写「通过」的原因）**：模拟器无振动马达，`vibrator.startVibration` 会抛 `14600101`（代码里已双层 try/catch 吞掉并 `console.warn`，不影响功能）。所以「选中正文真的振一下」这一级只能到代码路径核对：`ReaderPage.ets:1984`/`:1986` 在 `updatePendingLineSelection` 里，仅当选区**真的变化**才调 `ReaderHaptics.selectionStart`（首次）或 `selectionMove`（后续），与上游「首个词一次、拖手柄一次」的节奏对应；正文长按划词在该模拟器上本来就不通（见 KI-D5 记录的模拟器限制），无法从界面触发。
- **踩坑记录（留给后续）**：`uitest dumpLayout` 里 Text 节点一律 `clickable=false`，不能据此判断整行不可点；开关本体是独立的 `Toggle` 节点、有自己的 bounds，按行的 y 中心 + 右侧 x 估点是错的（本轮先按估算点了两次 `click 1108 2170`、`click 1106 2237` 都没命中，改成从 dump 里取 `Toggle` 的 bounds 中心才成功）。
- 测试期改动已复原：两个开关都拨回关闭，重新读偏好文件确认 `sliderVibrator` 与 `selectVibrator` 均为 `false`。
- 本记录只代表 N 端模拟器结果，不替代 E 端结论，也不代表 API 12 真机兼容。

## 2026-10-31 N 端 KI-D6 上次标记样式（源码接入，设备验收未完成）

- 设备：HOS 模拟器 `127.0.0.1:5555`（API 26，1280×2832），包名 `io.legado.harmony`。`assembleHap` 通过（`BUILD SUCCESSFUL in 2 s 188 ms`，33 项任务 15 执行 / 18 最新），HAP 覆盖安装成功。
- **持久化闭环（设备实测，已取证）**：把 `{"underlineMode":3,"underlineColor":4278255360}` 手工写进 `.../preferences/legado_reader_settings` 的 `lastMarkingStyle` 键 → `aa force-stop` 后重启应用 → 在「阅读界面 → 更多」拖动「滑动翻页阈值」滑块触发 `persistReaderSettings()` → 偏好文件 mtime 由 `11:33:13` 变为 `11:34:29`、`pageTouchSlop` 由 `0` 变 `300`，而 `lastMarkingStyle` **仍是注入的那份 JSON**（被 Preferences 转义成 `&quot;` 形式）。说明「读进 `@State` → 快照回写 → `save()` 落盘」这条链没有把该键清空或改写，字段与存储键名对得上。
- **编解码往返一致（离线核对）**：按 `ReaderMarkingRepository.encodeStyle`/`decodeStyle` 的同一份规则，对 solid / wave / dashed / strike / highlight / background / text 七种效果各取两组色值做 encode→decode 往返，10 例全部回到原 effect 与原色值（`background` 的 `0x33` alpha 与 `text` 的整型色都无损）。该脚本只复现算法、不执行 ArkTS，用于确认「存进去的 JSON 能被读回来」这一层，不替代设备验收。
- **未完成的部分（本记录不写「通过」的原因）**：`lastMarkingStyle` 的用户可见效果是「新建标记时面板预选上次的效果与颜色」，入口在阅读页正文的**划词菜单**（`ReaderPage.ets:2085` 的 `bindSelectionMenu` + `TextResponseType.LONG_PRESS` → `:2099` 「划线 / 笔记」→ `Index.ets:990 requestCreateReaderMarking`）。该模拟器上正文的长按与单击手势均不通（详见上一节 KI-D5 记录的「模拟器限制」），`uitest uiInput longClick` 与 `uiInput swipe x y x+1 y+1 1500` 两种注入方式都只落在系统层、不触发选区。另一条能打开标记面板的路径是「目录页 → 笔记条目 → 编辑」（`Index.ets:3806 onEditMarking`），但它走 `isNew = false`，**按上游语义本就不该应用 lastMarkingStyle**，只能证明「编辑时不覆盖标记自身样式」，证明不了预选。
- 因此本条只到**第 2 级（构建通过 + 覆盖安装）**，加上上面的持久化闭环证据；「新建标记预选上次样式」的界面闭环**未验**，需在真机（或手势正常的设备）上补：新建一条划线并选「波浪 + 红色」保存 → 再新建另一条，面板打开时应已预选「波浪」与红色。
- 顺带纠正的历史错位：`ReaderMarkingEditor` 的 `useRule` 默认值原为 `true`，与上游 `MarkingSelectionMenu.kt:181` 的 `mutableStateOf(false)` 相反，已改为 `false`；原先新建标记会被「复用规则」列表盖住、看不到预选样式，这与「预选不生效」的观感容易混淆。
- 测试期改动已全部复原：`pageTouchSlop` 回 `0`、`lastMarkingStyle` 键已删除，复原后重新拉取偏好文件确认（`grep` 该键为 0 条、`pageTouchSlop` 为 `0.000000`）。
- 本记录只代表 N 端模拟器结果，不替代 E 端结论，也不代表 API 12 真机兼容。

## 2026-10-31 N 端 KI-D5 进度条显示样式与滑动翻页阈值（通过）

- 设备：HOS 模拟器 `127.0.0.1:5555`（API 26，1280×2832），包名 `io.legado.harmony`。`assembleHap` 通过（`BUILD SUCCESSFUL in 24 s 832 ms`，33 项任务 17 执行 / 16 最新），HAP 覆盖安装成功。
- **设置项上屏（D-06「滑动条显示样式」）**：设置 → 阅读界面 → 底栏布局 tab，首项显示「滑动条显示样式 / 常驻」。此条原本错挂成「进度条模式」并绑在本地 `progressBehavior`（页码/章节）上，本轮纠正为上游 `readSliderMode` 的「常驻 / 不显示」二值。
- **详情面板与落库**：点开显示标题「滑动条显示样式」、描述「底栏是否显示进度滑动条」、选项「常驻」「不显示」，选中「不显示」后条目副标题即时变「不显示」。`cat .../preferences/legado_reader_settings` 实测出现 `<string key="readSliderMode">1</string>`；改回「常驻」后回到 `0`。
- **面板底部提示（本轮新修）**：条件链原先漏了这个新标题，导致面板底部恒显示「仅展示选择预览，不保存设置」。补上后实测变为「选择后立即应用并保存；自定义内容需点击保存。」，与实际落盘行为一致。
- **设置项上屏（D-07「滑动翻页阈值」）**：设置 → 阅读界面 → 更多 → 「翻页控制」段第一项为「滑动翻页阈值」，初值 `0`，下方说明「滑动翻页阈值（0 = 系统默认值）」；滑块范围 0–1000、步长 10，点滑块约 30% 位置后数值变 `310`，`legado_reader_settings` 出现 `<double key="pageTouchSlop" value="310.000000"/>`。
- **阈值生效（决定性对比）**：同一本书同一页，`pageTouchSlop=310`（≈110vp）时横向短滑 400px（≈141vp）**截图 md5 前后完全一致、不翻页**；滑 1200px（≈424vp）**翻页**。把该值改回 `0`（走平台默认 36vp）后，同样 400px 的短滑**能翻页**（截图 md5 由 `645ad35f…` 变 `dbde7a89…`，稳定后再滑仍变 `c60d86eb…`）。两次对比方向相反，确认阈值确实取自该配置。
- **备份口径**：`readSliderMode`（string）与 `pageTouchSlop`（int）已进 `BackupRepository.ets` 的导出与恢复两段；未加入 `preferenceKeysByCategory.readConfig` 忽略清单，与上游 `BackupConfig.readPrefKeys` 不含这两个键一致（上游 `Backup.kt:257` 全量导出 `preferences.asMap()`）。
- **模拟器限制（影响走读手法，非本次改动引入）**：该模拟器上阅读页正文区的单击手势不稳定——`hilog` 显示 `Click try accept` 后仍无动作，即使把九宫格中心格改成「目录」、把 9 格全改成「菜单」也不弹面板；同一份配置在「点击区域」以外的入口（设置页）均正常。这与 `docs/KNOWN-ISSUES.md` 里既有的「模拟器上长按划词不可靠」属同一类环境问题，故本轮用「设置页读写 + 偏好文件实测 + 滑动距离对比」完成验收，未依赖正文单击。
- 本记录只代表 N 端模拟器结果，不替代 E 端结论，也不代表 API 12 真机兼容。

## 2026-10-31 r297 readConfig 文档轮次收尾构建

- 本轮只改文档与脚本（`docs/parity/READER-CONFIG.md`、`docs/parity/KEYWORDS.md`、`docs/parity/STATUS.md`、`docs/KNOWN-ISSUES.md`、`scripts/upstream-surface.sh` 与三个 `scripts/reader-config-*.py`），未改 `.ets`。构建目的是确认并行工作留下的 `.ets` 改动不破坏编译，以及本轮文档改动没有误伤源码。
- 命令：`hvigorw --no-daemon --mode module -p product=default -p module=entry@default assembleHap`，`BUILD SUCCESSFUL in 3 s 454 ms`，33 项任务 16 执行 / 17 最新。`PackageHap`、`PackingCheck`、`SignHap`、`CollectDebugSymbol` 全部完成，仅 `WARN: No signingConfig found for product default`（与历史记录一致，仓库不含签名材料）。
- **构建环境坑（供后续复跑参考）**：直接调用 `hvigorw.bat` 会报 `00308003 ENOENT ... node_modules\@ohos\hvigor\bin\hvigor.js`，即便该文件 `fs.existsSync` 为 true。原因是 wrapper 用 `child_process.fork` 拉起 hvigor，而沙箱环境拒绝 spawn（`EPERM spawn EPERM`），wrapper 把任何异常都吞成「文件不存在」并提示删缓存——删缓存无效。两个必须条件：① 放开进程 spawn 权限（沙箱 `danger-full-access`）；② 把 `JAVA_HOME/bin` 加进 `PATH`，否则 `PackageHap` 阶段报 `00308018 spawn java ENOENT`（只设 `JAVA_HOME` 不够，`hvigor` 用 `PATH` 找 java）。
- 覆盖率脚本同时复跑：`bash scripts/upstream-surface.sh --coverage readConfig docs/parity/READER-CONFIG.md /n/HarmonyProjects/legado-with-MD3` → 接触面 107 个 `.kt`，已分配 107，未分配 0。

## 2026-10-31 N 端 r296 localBook 恢复期冲突规划（通过）

- 设备：HOS 模拟器 `127.0.0.1:5555`（API 26），包名 `io.legado.harmony`。构建 `assembleHap` 通过，HAP 覆盖安装成功（8175637 字节）。书架基线 2 本：`/data/storage/el2/base/haps/entry/files/books/local-1793351616205.txt`（真实正文，`durChapterIndex=1`）与相对路径占位书 `local-1793348394426.txt`（`durChapterIndex=2`）。
- **取证手法**：设备 `sqlite3` 只读（任何写操作报 `unable to open database file`），`hdc shell` 为 `uid=2000(shell)` 且 SELinux `Enforcing`，无法改库或写应用沙箱，故全部通过「造单条 `bookshelf.json` 的合成 ZIP → 恢复 → 从本地恢复 → 导入此 ZIP」注入数据，再用只读 `sqlite3` 核对 `books` 表。ZIP 经 `hdc file send` 推到 `/storage/media/100/local/files/Docs/Documents/`。
- **场景一 重定位（`isRelocatedCopyOf` + `resolvedTargets`）**：`lb-reloc.zip` 的 `bookUrl` 指向 `files/../cache/local-1793351616205.txt`（父目录在、文件不在，判 `Missing`），`originName`/`name`/`author` 与真实书相同。预览原文「识别 1 个根条目；书架 1 本，其中本地书籍 1 本」「ZIP 不含 TXT/EPUB 正文；1 本本地书未匹配到当前书架中的可读正文。」导入提示原文「导入完成：保留 1 个 Android 条目；更新 1 本已有正文书籍的进度，并创建 0 本缺正文书目；清理 0 本重复书目。」导入后 `books` 仍是 2 行，真实书 `durChapterIndex` 由 1 变 **0**（备份值）、`durChapterTitle` 变为书内真实第 0 章标题「第一卷 风起」。**结论：重定位归并与进度合并均通过，未新增书目。**
- **场景二 `Unknown` 不删书**：`lb-unknown.zip` 的 `bookUrl` 指向整段不存在的 `files/nodir/`（父目录也访问不了 → `Unknown`）。导入提示「…更新 0 本已有正文书籍的进度，并创建 1 本缺正文书目；清理 0 本重复书目。」`books` 由 2 行变 3 行，新增 `files/nodir/local-1793351616205.txt`（`durChapterIndex=5`），原两行一条未删。**结论：`Unknown` 一律不删的保守语义通过。**
- **场景三 `Missing` 重复条目被清理（`booksToDelete`）**：分两步。先导 `lb-del-1.zip`（`bookUrl` 为 `files/../cache/config.xml`，父目录 `haps/entry/cache` 存在、文件不存在 → `Missing`）插入一条占位书 `dup-probe3`，提示「创建 1 本缺正文书目；清理 0 本重复书目」。再导 `lb-del-2.zip`（同 `originName`/书名/作者，路径为真实存在的 `files/android-backup-entries/config.xml` → `Available`，且未被任何书占用），提示「…并创建 1 本缺正文书目；**清理 1 本重复书目**。」`books` 中 `files/../cache/config.xml` 那条占位书消失，只剩 `files/android-backup-entries/config.xml`。**结论：唯一 `Available` 时清理其余 `Missing` 重复条目通过，`deletedDuplicateLocalBookCount` 计数与提示文案一致。**
- **两次失败的造数尝试（供复跑参考）**：① 先用 `name` 不同（`stale-copy` vs `test-book`）造重复，规划器第一分支按「同规范化路径别名」先命中，落不到删书分支；② 用 `android-backup-entries/../cache/` 造 `Missing`，实际解析到不存在的 `files/cache`，父目录判不到 → `Unknown` → `hasUnknownLocation` 使删书分支放弃。正确造法是「同 `originName`/书名/作者 + 一条真实存在且未被占用的 `Available` 路径 + 一条父目录存在的 `Missing` 路径」。
- 本记录只代表 N 端模拟器结果，不替代 E 端结论，也不代表 API 12 真机兼容。

## 2026-10-31 r298 深色模式盘点轮次收尾构建

- 本轮以文档为主（新建 `docs/parity/ZIP-THEME.md`，改 `docs/parity/KEYWORDS.md`、`STATUS.md`、`docs/INDEX.md`、`docs/BACKUP-RESTORE.md`），`.ets` 只动一处文案：`entry/src/main/ets/data/BackupRepository.ets:327` 的 `title: '主题模式'` → `'深色模式'`（与上游 `strings.xml:660`、[备份恢复](BACKUP-RESTORE.md) 的写法对齐）。按仓库规约，改了 `.ets` 就要跑 `assembleHap`。
- 12:04 的构建 `BUILD SUCCESSFUL in 36 s 683 ms`（33 任务），产物 `entry/build/default/outputs/default/entry-default-unsigned.hap`（8253847 字节）。**从 HAP 的 abc 字符串表取证**：offset 182284 处为「深色模式」，与相邻的「阅读配置」「主题配置」「封面配置」同在一个连续区间；「主题模式」在该表只剩 `pages/ThemeSettingsPage.ets` 的分组标题一处（offset 1194470）。即新文案确实进了产物。
- 12:21 之后的复跑 `BUILD FAILED`，`default@CompileArkTS` 报 `COMPILE RESULT:FAIL {ERROR:3}`，三条错误全部落在**并行会话尚未完成的 `.ets` 改动**上，与本轮文案无关：
  1. `ReaderPage.ets:206:9` `Property 'backgroundImage' in type 'ReaderPage' is not assignable to the same property in base type 'CustomComponent'. Type 'string' is not assignable to type '{ (src: ResourceStr | PixelMap, ...) }'` —— 新加的 `@Prop backgroundImage: string` 与 ArkUI 组件基类同名成员冲突。
  2. `BackupRepository.ets:1119:5` `Type '{ paddingSettings: ... }' is missing the following properties from type 'ReaderSettingsSnapshot': textColor, textColorNight, textAccentColor, textAccentColorNight, and 7 more.` —— 并行会话给 `ReaderSettingsSnapshot` 加了字段，但恢复侧的返回对象还没补齐（该处不是本轮的 `title` hunk）。
  3. 再复跑一次后错误变为 7 条（`ReaderSettingsPage.ets:148:9 Duplicate identifier 'readerNightMode'`、`Index.ets:4116/4454/4657/4802:15 An object literal cannot have multiple properties with the same name`），说明对方仍在编辑中，工作区处于中间态。
- **结论**：本轮的 `.ets` 改动（单条字符串字面量）不会引入类型错误，12:04 的成功构建已证明它能编译进产物；当前 `BUILD FAILED` 是并行会话的中间态，未改其代码，待其收尾后重跑即可。
- 覆盖率脚本复跑：`--coverage themeMode docs/parity/ZIP-THEME.md <上游根>` → 80 个 `.kt`，已分配 80，未分配 0；`--coverage themeConfig` → 132 个 `.kt`，已分配 132，未分配 0。
- 本记录只代表 N 端编译结果，不涉及设备安装，也不代表 API 12 真机兼容。

## 2026-11-01 N 端 r299 菜单与正文视觉取证（像素级，逐组补做）

- 设备：HOS 模拟器 `127.0.0.1:5555`（API 26，1280×2832，密度 3.5 px/vp），包名 `io.legado.harmony`。构建 `assembleHap` `BUILD SUCCESSFUL`，`hdc install -r` 回 `install bundle successfully`。
- **本节推翻 r297 那批 KI 组共同的前置条件**。r297 各组的「未验部分」都写着「模拟器书架上的书正文文件已丢失、`ReaderPage` 进不去」，据此判定菜单与正文的像素级视觉无法取证。该前提**不成立**：`the-metamorphosis` 的正文文件 `files/books/local-1793481021711.txt`（119736 B）完好，阅读页可正常进入并渲染正文，菜单也可正常调出。本节据此把 E1/E2/E3/E4/E5/E6、A2、C1/C2 与中文书排版的视觉证据逐组补齐。
- 证据等级：**第 3 级（设备验收）**。所有「通过」结论都附带截图文件与可复算的像素/布局树数据；受工具限制取不到的项列在末尾「仍未取证」里，不写成通过。

### 取证方法（本轮沉淀）

1. **改设置值走 prefs 就地改写**：`$P` = `/data/app/el2/100/base/io.legado.harmony/haps/entry/preferences/legado_reader_settings`。流程 `aa force-stop` → `sed 's|旧值|新值|' $P > /data/local/tmp/pv.xml` → `cp /data/local/tmp/pv.xml $P` → `aa start`。**只改单个键、保留文件其余部分**，实测 `bgStrNight`/`readBarStyle`/`readMenuBgColorNight`/`titleBarMode` 等键即时生效。注意 `preferences/` 下**新建**文件报 `Permission denied`，但**覆盖已有文件**可以；`run-as` 在模拟器上不存在（`/bin/sh: run-as: inaccessible or not found`）。
2. **整文件 base64 覆盖会踩脱钩**：用「pull → 改 → push 整文件」的方式改 `adaptSpecialStyle` 时，改前改后行为完全一致（假阴性），与本节第 1 条的 sed 就地改不同。凡是行为不随值改变的键，先换 sed 就地改复核，再下结论。
3. **截图必须按 base64 解**：`uitest screenCap -p /data/local/tmp/x.png` 后 `hdc shell "base64 /data/local/tmp/x.png"`。取回后三步：① 从 PNG magic 的 base64 头 **`iVBORw0KGgo`（大写 V）** 处开始切，写成 `vBOR...` 或 `BOR...` 都会把首字符切错、产出 0 字节文件；② `re.sub(rb'[^A-Za-z0-9+/=]', b'', ...)` 清掉换行；③ hdc 取回的流尾部可能被截断，`len % 4 == 1` 时先丢掉那一个残余字符再补 `=`，否则报 `binascii.Error: Invalid base64-encoded string: number of data characters (806937) cannot be 1 more than a multiple of 4`。解码后务必用 PIL 断言 `Image.open(p).size == (1280, 2832)`。脚本见 `tmp/cap.sh`。
4. **布局树比截图像素稳**：量边距/行距/控件位置一律用 `uitest dumpLayout` 的 `bounds`，不受行内空白干扰；截图像素统计只用来验颜色与「两态是否有差异」。
5. **菜单是否打开不能靠文字判定**：`showBottomActionText=false` 时菜单只有纯图标、dump 里没有任何文字节点。可靠判据是**全节点计数**——正文态 65–81 个节点，菜单态 132–147 个节点（`>100` 即已打开）。这一点曾让本轮把「菜单已正常显示」误判成「菜单调不出」，白查十几轮。
6. **`uitest uiInput click` 落在正文文字行上经常不触发** `onClick`（同一点 `(640,1500)` 连点 8 次只命中 4 次；`y=400/445/500/550` 完全无响应，`y=660/2600` 有响应）。调菜单要多点几次、换几个 y。A/B 实测 `selectText` 为 `true`/`false` 时命中率都是 0/3，与文字选区无关，属注入层限制。用临时 `console.info` 在 `handleReaderTapAt` 里打点确认过格子计算正确（命中时输出 `idx=4`，中心格=菜单），埋点已删。
7. **向设备注入文件**：`MSYS_NO_PATHCONV=1 hdc file send <本地> /storage/media/100/local/files/Docs/Download/<名>`。不加该环境变量时 MSYS 会把 `/storage/...` 转成 Windows 路径，报 `Error opening file: no such file or directory`（此前据此误判「`hdc file send` 不可用」）。沙箱 `files/`、`cache/`、`preferences/` 直接写都 `Permission denied`，正规注入路径是「推到 Docs/Download，再用应用内 `DocumentViewPicker` 选择」。

### KI-E1 配色七项：通过

- 底色来源三态：`readBarStyle=1`（跟随阅读背景）+ `bgStrNight=#1E88E5` → 顶栏主色 `(31,136,230)`、正文主色 `(30,135,228)`，两者几乎同色，即菜单跟随纸色；改 `readBarStyle=2` + `readMenuBgColorNight=#FF0000` → 顶栏 `(202,34,57)`、底栏 `(102,10,10)`，正文仍是 `(30,135,228)`，自定义底色覆盖生效。两态像素差异构成决定性对照（截图 `e6_style1.png`、`red2.png`）。
- 再换 `#00AAFF`：顶栏 `(2,62,93)`、底栏 `(12,72,103)`（截图 `e1_custom2.png`），说明颜色确实来自配置值而非固定色。
- 强调色：`readMenuAccentColorNight=#00FF00` 后进度条滑块由默认 `#FFB1C8` 的混色 `(90,63,71)` 变为 `(2,255,0)`（截图 `acc2.png`）。
- 文字色：`readMenuTextColorNight=#FF00FF` 后洋红像素 19668 个，bbox `x 60-1156 y 222-2560`，顶栏书名与底栏图标同时变（截图 `e1_txt0.png` 基线洋红 0 / `e1_txt1.png`）。
- **口径提醒**：`readBarStyle` 必须是 `2`（自定义）才吃 `readMenuBgColor`；`1`（跟随阅读背景）时取纸色，改色无效——本轮第一轮就踩了这个坑。
- 仍未实现：ArkUI 无 `dynamicColorScheme` 等价物，「跟随系统」与九种调色板风格只落库、不生成派生色板，此项无法用截图证明。

### KI-E2 边框与模糊七项：通过（两项除外，见功能缺口）

- `readMenuBorderWidth` 0 vs 4：changed px=222402（顶栏 114736 / 正文 26796 / 底栏 80870）；顶栏 y515-525 区最大亮度 97 → 219、均值 28.0 → 51.8（截图 `e2_b0.png`/`e2_b4.png`、`bw4.png`）。
- `readMenuBorderColorNight=#00FFFF`：青色像素 19578，横带 y=136-138 / 520-522（顶栏上下沿）与 2249-2251 / 2676-2678（底栏上下沿），竖带 x=0-2 / 51-53 / 1226-1228（截图 `bc.png`）。描边位置与面板 `bounds` 一致。
- `readMenuBlurRadius` 0 vs 32：changed px=358357（顶栏 202406 + 底栏 155951，正文区 0），证明模糊只作用于菜单层、不污染正文（截图 `br0.png`/`br32.png`）。
- `readMenuBlurAlpha` 100 vs 20：changed px=290444（顶栏 162865 / 底栏 127579），底栏左空白区均值 5.3 → 22.3（截图 `a100.png`/`a20.png`）。
- **缺口**：`readMenuTopBarBlurMode` / `readMenuBottomBarBlurMode` 改值后 changed px=0。代码侧确证 `ReaderPage.ets:241`（BottomBar）与 `:261`（TopBar）只有 `@Prop` 声明，全仓无消费点。已记入 KNOWN-ISSUES。
- ArkUI 的 `backdropBlur` 是静态半径，没有上游 `hazeState` 的内容自适应模糊，不做效果等价断言。

### KI-E3 浮动图标四项：通过

- `showTitleBarIcons=true` 后顶栏出现两个圆形按钮（⋮ 与 译A），底栏上方多出一行浮动图标（截图 `e3_on.png`）。
- 位置四档：`titleBarIconPosition` 0 vs 3 changed px=131697（正文区 103120），图标行从顶栏下方移到菜单浮层上方；0 vs 1 changed px=10541，bbox `x92-1189 y570-629`（同一行改右对齐）；0 vs 2 changed px=131708（截图 `e3p0.png`–`e3p3.png`）。代码侧对应 `readerFloatingIconTopVisible()`（`ReaderPage.ets:1989`，`position<=1`）与 `readerFloatingIconBottomVisible()`（`:1994`，`position>=2`），调用点 `:4391`/`:4408`，像素分区与这两个分支一致。
- 仍未实现：没有「换自定义图标图片」的选图入口（上游 `OpenTitleBarCustomIconPicker` 未迁移），两个图标串可落库、渲染侧 `decodeCustomIconMap` 能解码显示，但面板里选不了图。

### KI-E4 底栏外观七项：通过（一项除外）

- `readMenuBottomCornerRadius` 0 vs 32：changed px=13651，其中 12962 落在底栏区。量化：圆角 0 时 y=2250 行面板左边缘 x=51 即开始，圆角 32 时 x=155 才开始，内缩 104px ≈ 30vp（截图 `e4_c0.png`/`e4_c32.png`）。
- `readMenuFloatingBottomBar` true vs false：changed px=121541（底栏区 120954）。悬浮态面板 x 范围 155-1124（浮起圆角块），关闭后贴满屏宽 x 0-1279（截图 `e4_float1.png`/`e4_float0.png`）。
- **缺口**：`readMenuBottomBarBlurMode` 改值 changed px=0，无消费点；`readerBottomBarButtonGlassEnabled()`（`ReaderPage.ets:948`）全仓无调用点，底栏按钮液态玻璃无渲染效果。两项均记入 KNOWN-ISSUES。
- 「底栏模糊」本地把模糊模式折算成背景不透明度与渐变（对照上游 `ReadBookMenuBarShared.kt:49-85` 的 alpha 叠色），不是真正的背景模糊。

### KI-E5 标题栏形态八项：通过

- `titleBarMode` 四态（`0`/`1`/`2`/`3`）的顶栏文字带各不相同：行投影（`im[130:560]` 亮度>60）分别是 `0`→(222,296)/(352,392)/(426,441)/(473,547)；`1`→(222,297)/(358,413)/(446,486)/(514,530)；`2`→(222,296)/(370,379)/(385,456)/(473,530)；`3`→(232,312)/(369,441)/(473,530)（截图 `e5m0.png`–`e5m3.png`）。
- **该键是字符串型** `<string key="titleBarMode">1</string>`，写成 `<double>` 不生效。
- `readMenuTopBarTitleCapsule` false vs true：changed px=242055（顶栏 201651 + 正文区 40404），胶囊态把书名与章名收进顶栏左侧胶囊（截图 `e5_cap1.png`）。
- `titleBarCompact` false vs true：changed px=2721，bbox `x187-1156 y59-280`，只动顶栏图标区（截图 `e5_cmp0.png`/`e5_cmp1.png`）。
- `titleBarIconStyle` 三档（纯色/色调/描边）：0→1 changed px=30656，1→2 changed px=29947（maxdiff 142），都落在顶栏图标区（截图 `e5_is0.png`–`e5_is2.png`）。
- 仍未实现：胶囊里的书名/章名点不进书籍详情（`ReaderPage` 没有 `onOpenBookInfo` 回调，上游 `TitleCapsuleGlassLayout` 的书源圆点入口本地缺）；`readMenuTopBarLiquidGlassButtons` 只做可配 + 落库 + 抑制描边，ArkUI 没有 `backdropBlur` 等效物。

### KI-E6 阅读栏样式跟随页面：通过

- 原「未验部分」第 3 条（菜单底色是否跟随当前阅读背景）本轮补齐。`readBarStyle=1` + `bgStrNight=#1E88E5` 下顶栏主色 `(31,136,230)` 与正文主色 `(30,135,228)` 几乎同色（截图 `e6_style1.png`）；同一台设备改 `readBarStyle=2` + `readMenuBgColorNight=#FF0000` 后顶栏变 `(202,34,57)` 而正文保持 `(30,135,228)`。两种底色来源的差异是决定性的。
- 链路：`readerMenuIsNight()`（`ReaderPage.ets:1007`，按 `paperColor` 亮度 <0.5）→ `readerMenuBaseColor()`（`readBarStyle===1` 返回 `this.paperColor`，`===2` 取 `readMenuBgColor`/`Night`）→ `readerMenuContainerBaseColor()`。`paperColor` 由 `Index.ets:4002 getPaperColor()` 产出。
- 仍未实现：菜单镜头半径的 `lens` 高光效果（ArkUI 无液态玻璃材质）；`readMenuLensRadius` 在 `Index.ets:1993/2145/3728` 只做装载与 prop 透传，`ReaderPage.ets` 里连 `@Prop` 声明都没有，纯落库。

### KI-A2 菜单图标两项：通过

- `showMenuIcon` false vs true：changed px=792，bbox `x187-214 y59-99`，差异全落在状态栏区（y 0-140），顶栏/正文/底栏三区都是 0——即该开关只影响顶栏返回箭头左侧那个小图标位，不牵动其他区域（截图 `a2_i0.png`/`a2_i1.png`）。
- `showBottomActionText` false vs true：changed px=375981，其中 375553 落在底栏区（y 2100-2832），顶栏与正文区都是 0。开启后底栏每个图标下出现文字：`更多操作`/`全文搜索`/`自动翻页`/`目录`/`朗读`（bounds 依次 `[117,2561][244,2598]`、`[347,2561]`、`[577,2561]`、`[838,2561]`、`[1068,2561]`）（截图 `a2_txt0.png`/`a2_txt1.png`）。
- **「更多」面板的图标显隐也一并取证了**：把底栏第 1 格从 `settings` 换成 `more_actions`（prefs `bottomActions` 里 `settings,false` + `more_actions,true`）后，底栏首格变成「更多操作」，点它弹出「更多」网格面板（听书下载 / 编辑内容 / 添加书签 / 文本处理 / 反转内容 / 重新分段 / TXT目录规则 / 设置编码 / 图片样式 / 翻页动画 / 模拟阅读 / 高亮规则）。`showMenuIcon` false vs true 两态对比：changed px=79021，其中 78309 落在面板区（y>1400），即每个网格项左上角的 `AppGlyph` 图标整块出现/消失。代码侧 `ReaderPage.ets:4605` `if (this.showMenuIcon) { AppGlyph(...) }`（截图 `mi_off.png`/`mi_on.png`）。

### KI-C1/KI-C2 背景图片：通过（原「未验」已解除）

- 原记录的阻塞原因是「模拟器里没有可选图片，沙箱不可写，无法注入测试图」。本轮用 `MSYS_NO_PATHCONV=1 hdc file send` 把 400×400 纯色 PNG 推到 `/storage/media/100/local/files/Docs/Download/`，再走应用内正规路径注入：阅读页点中央调菜单 → 齿轮 → 「全局」tab → 「背景」行右侧「长按自定义」→「自定义阅读背景」面板 → 夜间背景图片「选择」→ 系统 `DocumentViewPicker` →「浏览」→「我的手机」→「Download」→ 点文件。
- 面板回显「已选择图片」，偏好写出 `<double key="bgTypeNight" value="2.000000"/>` 与 `<string key="bgStrNight">/data/storage/el2/base/haps/entry/files/reader-background/bg-1793500485464-422.png`，副本文件 1387 B 确实存在于 `files/reader-background/`。
- 关面板回阅读页，**整屏变成纯绿 `(0,200,80)`**（截图 `r6.png`）；换红图得 `(254,0,0)`（截图 `qe.png`）。纯色背景 `bgType=0` + `bgStr=#FF0000` 同样生效，正文区主色 `(254,0,0)`（截图 `c1c_red.png`）。
- 背景透明度：`bgAlpha` 100 → `(0,200,80)`；50 → `(0,100,40)`（正好一半，即叠在黑底上的 50% alpha）；0 → `(0,0,0)`（截图 `c2_a50.png`/`c2_a0.png`）。三点连线证明 `backgroundImageAlpha()` = `backgroundAlpha/100` 真实作用于合成。
- 代码侧：`Index.ets:4022 getReaderBackgroundImage()` 读 `readerNightMode ? readerBgStrNight : readerBgStr`，`bgType !== 0` 才返回路径；`bgType` 语义 0=纯色 / 1=assets 图片 / 2=自定义图片路径（`ReaderBackgroundImageRepository.ets:7`，对齐上游 `ReadBookConfig.kt:549`）；`ReaderPage.ets:4118-4125` 用 `Image(...)` + `.opacity(...)` 铺满整屏垫底。

### KI-A1 正文渲染适配：`[newpage]` 通过，`<usehtml>` 未实现

- 测试素材：`np-test.txt`（1450 B，8 段长文 + 独立 `[newpage]` 段 + 8 段短句）与 `style-test.txt`（328 B，含 `<usehtml><b>…</b></usehtml>` 段），导入路径同 C1/C2。
- **`[newpage]` 生效（决定性对照）**：`adaptSpecialStyle=true` 时 `np-test` 分页 1/3 → 2/3 → 3/3，第 3 页首行是「　　第9段正文，出现在」，即标记之后的段落被推到新页，全文扫描无字面 `[newpage]`；`adaptSpecialStyle=false` 时同一本分页变成 **1/6**，`[newpage]` 按字面参与排版。两种取值下页数 3 vs 6，排除了「本来就这么分页」的可能。
- **`<usehtml>` 未实现**：`adaptSpecialStyle=true` 下 `style-test` 第 2 页仍**字面显示** `<usehtml><b>粗体富文本块</b> 与 <i>斜体</i> …</usehtml>` 源码（截图 `y2.png`、`r4.png`）。代码侧 `richHtml` 字段只有 `LocalTextSemantics.ets:16/103/125/158` 四处定义与赋值，**全仓无渲染消费点**，即只打了标记、渲染层不消费。已记入 KNOWN-ISSUES。
- **测试素材的坑**：先做的那本 148 B 判别文本即使不识别 `[newpage]` 也会自然分两页，两种取值下都是 1/2，看着像换页生效其实是假阳性。判据文本必须长到「不识别时一页装得下、识别时必换页」，或像 `np-test` 这样用页数差（3 vs 6）作判据。
- `paddingDisplayCutouts` 仍属未验：模拟器无显示缺口，`getWindowAvoidArea(TYPE_CUTOUT)` 返回 `visible=false`，三个 inset 恒 0。

### 中文正文排版：通过

- `N:\HarmonyProjects\测试\失明的她遇上盗神的我.txt`（3861746 B）经 `MSYS_NO_PATHCONV=1 hdc file send` 推到 Docs/Download 后，用「书架页 ⋮ → 添加本地 → 文件选择器」导入，书架出现 `zh-book`（572 章）。
- 阅读页第 1 章「盗神林川」布局树实测：20 行 `bounds` 全为 `[56,y][1224,y+h]`（左右各 16vp，对称）；行距步进 104–105px（理论 `fontSize × 1.25 × lineSpacing / 10` = 20 × 1.25 × 12/10 = 30vp = 105px）；末行底 y=2468、页脚顶 y=2626，不重叠；分页 1/9（截图 `zh3.png`）。
- 与英文书 `the-metamorphosis` 的测量结果一致，即 r298 修的三处排版缺陷（左右边距叠加、底部行距累加、行末丢词）在中文正文上同样不复现。

### KI-A6 自动切换日夜模式提醒：弹出通过，点击未验

- `autoSuggestDayNight=true` + `readerNightMode=false` 后从书架进阅读页，连续 `dumpLayout` 在第 3–5 轮读到「当前环境光较暗，是否切换至深色模式？」bounds `[114,2307][934,2360]`，第 6 轮消失，**5 秒自动消失成立**。可点节点：左胶囊 `[58,2276][990,2391]`、右「关闭」`[1018,2276][1222,2391]`。
- **胶囊点击仍未验**：写脚本轮询 dump、抓到胶囊出现即点 `(524,2333)`，多次抓到但 `readerNightMode` 始终 `false`；反倒在若干秒后自己变 `true`（环境光提醒重新触发或模式切换由别处驱动），无法归因为胶囊点击。与 KI-D2 同源的注入限制，非代码问题。代码侧 `ReaderPage.ets:3161 ReaderDayNightReminderCapsule()` 左胶囊点击调 `onAcceptDayNightReminder`、右「关闭」调 `onDismissDayNightReminder`，挂载点 `:4815`，条件 `dayNightReminderText.length > 0 && !controlsVisible`。

### 仍未取证（工具/环境限制，不得写成通过）

1. **KI-A9 窗口亮度的视觉效果**：`brightness` 分别设 `20` 与 `100`（`brightnessAuto=false`）后各截全屏图，`y∈[200,2632]`、`x∈[50,1230]` 区域的平均通道值都是 **36.16**，一模一样——模拟器截图不叠加窗口亮度（`setWindowBrightness` 影响的是面板背光叠加层，不是合成帧内容），`hidumper` 也没有对应读数。需要在真机上看。
2. **KI-A7 振动本身**：模拟器无马达，只验到开关落库。
3. **KI-D1 按键与滚轮翻页**：`uitest uiInput keyEvent`（2013/2014/2015/2016/2017/2048/16/17）与 `uinput -K -d/-u 16/17` 全部不翻页，页脚恒 `1/17`；系统日志出现 `SCBVolumePanel17` / `SYS_UI: VolumeGroupUnionHideAnimation`，说明音量键被系统音量面板截获，应用层 `inputConsumer` 拿不到。`uinput -M -s ±5` 与 `dircFling` 也都不触发 `.onAxisEvent`（`uitest` 没有 axis 注入能力）。点右侧 `(1000,1500)` 翻页正常（1/17 → 2/17 → 3/17），证明翻页功能本身可用。代码侧接线齐全：`pageKeyHandler`（`ReaderPage.ets:479-490`）、`inputConsumer.on('keyPressed', ...)`（`:637-641`）、`.onAxisEvent`（`:4837-4845`）、`.onKeyEvent`（`:4846-4853`）。
4. **KI-D2 划词菜单的渲染**：`uitest uiInput longClick`、`doubleClick`、`drag`、`uinput -T -d … -u … 1500`（1500ms 长按）全部无效，dump 始终 27 个节点、无「复制 / 书签 / 划线」。`selectText=true`、三处 `.textSelectable(...)` 与 `.bindSelectionMenu(TextSpanType.TEXT, …, TextResponseType.LONG_PRESS, …)`（`ReaderPage.ets:3585`/`:3590`/`:3649`/`:3711`）都在位。
5. **KI-D4 平板判定**：模拟器无平板形态可切，`LANDSCAPE_OR_TABLET` 的 `isTablet` 分支只做代码核对；双列下底部两端对齐被主动关闭，该模式在双列下未做像素级比对。
6. **API 12 真机兼容**：本节全部为 API 26 模拟器结果，不替代真机结论。

### 本节新发现的功能缺口（已同步 KNOWN-ISSUES）

| 字段/函数 | 代码事实 | 实测 |
| --- | --- | --- |
| `readMenuTopBarBlurMode` | `ReaderPage.ets:261` 只有 `@Prop`，全仓无消费点 | 改值 changed px=0 |
| `readMenuBottomBarBlurMode` | `ReaderPage.ets:241` 只有 `@Prop`，全仓无消费点 | 改值 changed px=0 |
| `readMenuLensRadius` | `Index.ets:1993/2145/3728` 只装载与透传，`ReaderPage.ets` 无 `@Prop` | 纯落库 |
| `readerBottomBarButtonGlassEnabled()` | `ReaderPage.ets:948` 全仓无调用点 | 底栏按钮无玻璃效果 |
| `<usehtml>` 的 `richHtml` | `LocalTextSemantics.ets:16/103/125/158` 只有定义与赋值 | 正文仍字面显示标签源码 |

### 复原状态

prefs 已用 `/data/local/tmp/pf.orig` 覆盖还原：`selectText=true`、`readBarStyle=1`、`bgType=0`、`bgTypeNight=0`、`bgStrNight` 空串、`readerNightMode=true`、`adaptSpecialStyle=true`、`readMenuBorderWidth=1`、`readMenuBottomCornerRadius=32`、`showMenuIcon=false`、`showBottomActionText=false`、`showTitleBarIcons=false`、`titleBarIconPosition=3`、`readMenuBlurAlpha=50`、`readMenuBlurRadius=24`、`readMenuLensRadius=24`、`readMenuColorMode=1`、`fontSize=20`、`paddingLeft/Right=16`、`paddingTop/Bottom=6`、`lineSpacing=12`、`textBottomJustify=true`、`menuAlpha=100`。设备书架新增的 `zh-book`、`style-test`、`np-test` 三本测试书及其正文文件仍留在模拟器上（`files/books/` 下 `local-1793500829121.txt`、`local-1793501925606.txt`、`local-1793502426275.txt`），未删。

**本仓库提供开发预览源码，不代表稳定版、签名发行包或已完成 API 12 兼容验收。**
