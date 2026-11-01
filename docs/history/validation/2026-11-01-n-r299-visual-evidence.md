# 2026-11-01-n-r299-visual-evidence

> 本文件是[验证记录](../../VALIDATION.md)的历史归档，r299 菜单与正文视觉取证（像素级）。
> 内容原样搬运，未压缩、未改写设备实测数值（按《盘点规约》的沉淀约定）。
> 主文件只保留验证等级口径、设备操作规范与最近 8 轮记录；按功能分组找历史见主文件的索引表。

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
