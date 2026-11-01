# 2026-10-31-reading-config-ki-rounds

> 本文件是[验证记录](../../VALIDATION.md)的历史归档，阅读配置 KI 组逐轮落地（含正文排版三缺陷、r296/r297/r298）。
> 内容原样搬运，未压缩、未改写设备实测数值（按《盘点规约》的沉淀约定）。
> 主文件只保留验证等级口径、设备操作规范与最近 8 轮记录；按功能分组找历史见主文件的索引表。

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

**范围**：`docs/parity/READER-CONFIG.md` A 块的 A-05 展示菜单项图标（`showMenuIcon`）、A-08 阅读标题补充信息（`showReadTitleAddition`）、A-17 阅读菜单不透明度（`menuAlpha`）。三项对应上游 `domain/model/settings/ReadSettings.kt:119`、`:55`、`:13`，恰好是「上游有配置」的三种形态：有设置入口且有渲染消费点、有设置入口但无消费点、两者都没有。判据与证据见 [KNOWN-ISSUES](../../KNOWN-ISSUES.md) 的 KI-A2 段。

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

- 本轮以文档为主（新建 `docs/parity/ZIP-THEME.md`，改 `docs/parity/KEYWORDS.md`、`STATUS.md`、`docs/INDEX.md`、`docs/BACKUP-RESTORE.md`），`.ets` 只动一处文案：`entry/src/main/ets/data/BackupRepository.ets:327` 的 `title: '主题模式'` → `'深色模式'`（与上游 `strings.xml:660`、[备份恢复](../../BACKUP-RESTORE.md) 的写法对齐）。按仓库规约，改了 `.ets` 就要跑 `assembleHap`。
- 12:04 的构建 `BUILD SUCCESSFUL in 36 s 683 ms`（33 任务），产物 `entry/build/default/outputs/default/entry-default-unsigned.hap`（8253847 字节）。**从 HAP 的 abc 字符串表取证**：offset 182284 处为「深色模式」，与相邻的「阅读配置」「主题配置」「封面配置」同在一个连续区间；「主题模式」在该表只剩 `pages/ThemeSettingsPage.ets` 的分组标题一处（offset 1194470）。即新文案确实进了产物。
- 12:21 之后的复跑 `BUILD FAILED`，`default@CompileArkTS` 报 `COMPILE RESULT:FAIL {ERROR:3}`，三条错误全部落在**并行会话尚未完成的 `.ets` 改动**上，与本轮文案无关：
  1. `ReaderPage.ets:206:9` `Property 'backgroundImage' in type 'ReaderPage' is not assignable to the same property in base type 'CustomComponent'. Type 'string' is not assignable to type '{ (src: ResourceStr | PixelMap, ...) }'` —— 新加的 `@Prop backgroundImage: string` 与 ArkUI 组件基类同名成员冲突。
  2. `BackupRepository.ets:1119:5` `Type '{ paddingSettings: ... }' is missing the following properties from type 'ReaderSettingsSnapshot': textColor, textColorNight, textAccentColor, textAccentColorNight, and 7 more.` —— 并行会话给 `ReaderSettingsSnapshot` 加了字段，但恢复侧的返回对象还没补齐（该处不是本轮的 `title` hunk）。
  3. 再复跑一次后错误变为 7 条（`ReaderSettingsPage.ets:148:9 Duplicate identifier 'readerNightMode'`、`Index.ets:4116/4454/4657/4802:15 An object literal cannot have multiple properties with the same name`），说明对方仍在编辑中，工作区处于中间态。
- **结论**：本轮的 `.ets` 改动（单条字符串字面量）不会引入类型错误，12:04 的成功构建已证明它能编译进产物；当前 `BUILD FAILED` 是并行会话的中间态，未改其代码，待其收尾后重跑即可。
- 覆盖率脚本复跑：`--coverage themeMode docs/parity/ZIP-THEME.md <上游根>` → 80 个 `.kt`，已分配 80，未分配 0；`--coverage themeConfig` → 132 个 `.kt`，已分配 132，未分配 0。
- 本记录只代表 N 端编译结果，不涉及设备安装，也不代表 API 12 真机兼容。
