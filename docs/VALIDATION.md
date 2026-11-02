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

## 按功能分组的历史索引

主文件放两类记录：①最近 8 轮深色模式（r310–r317）；②当前仍在推进的专题（画布重写、基准包核对）。更早的轮次原样归档在 `docs/history/validation/`，按下面这张表找。
归档规则与理由见[盘点规约](PARITY-RULES.md)。

| 功能分组 | 涵盖轮次 | 归档文件 |
| --- | --- | --- |
| 阅读器画布重写 | 2026-11-02（画布逐行绘制 + 四项缺陷修复） | 本文件（下方各节） |
| Android 阅读界面基准包 | 2026-11-02 采集与核对 | 本文件（下方各节） |
| 深色模式 / 主题 | r310–r317 | 本文件（下方各节） |
| 深色模式 / 主题 | r300–r309 | [2026-11-01-n-r300-r309-theme.md](history/validation/2026-11-01-n-r300-r309-theme.md) |
| 阅读配置 KI 落地 | KI-A1–A12 / C1–C6 / D1–D6 / E1–E6、r296–r298 | [2026-10-31-reading-config-ki-rounds.md](history/validation/2026-10-31-reading-config-ki-rounds.md) |
| 阅读渲染与视觉取证 | 正文排版三缺陷、r299 像素级 | [2026-11-01-n-r299-visual-evidence.md](history/validation/2026-11-01-n-r299-visual-evidence.md) |
| 关系型存储迁移 | r281–r284（第一至第五批） | [2026-10-storage-migration-batches.md](history/validation/2026-10-storage-migration-batches.md) |
| E 端早期阅读/高亮/书签 | r241–r262 及更早 | [2026-10-r241-r262-e-rounds.md](history/validation/2026-10-r241-r262-e-rounds.md) |

**为什么这么分**：验证记录的价值分两种——「最近发生了什么」（决定下一步做什么）与「当时怎么验的」（事后追溯）。前者要短，后者要全。混在一个 1690 行的文件里，前者被后者淹没。

## 2026-11-02 Android 阅读界面基准包核对（纯取证，无代码改动）

**这批证据的用途**：与 HarmonyOS 端做**私下视觉对照**，补上「上游界面到底长什么样」这一层。此前 `PARITY-RULES.md` 第四节写的「与上游成对核实」有两种形态，实际只能用形态二（按源码参数逐项核对），因为本机无 Android 运行时、上游截图存量仅 43 张且阅读相关只有 7 张。本包把形态一（成对截图）解锁了。

**包与校验**

| 项 | 值 |
| --- | --- |
| 来源 | E 端采集，`测试/android-reader-baseline-2026-11-02.zip`，44,437,409 字节 |
| ZIP SHA-256 | `D27B12B66F00E21A26C4A90B1D39F3B9DA4A780157C63009D151EBA9D29AD82D`（与移交声明一致） |
| 包内校验 | `SHA256SUMS.txt` 共 71 条，**全部 OK**。注意该文件是 CRLF 行尾，直接 `sha256sum -c` 会因文件名带 `\r` 报「No such file」，须先 `tr -d '\r'` |
| 解包位置 | `N:\HarmonyProjects\project-resources\legado-with-MD3\screenshots\android\reader-baseline-2026-11-02\`（仓库外，不入库） |
| 内容 | 62 张 PNG、6 段 H.264 MP4、3 个 fixtures（合成 TXT / EPUB / 插图源） |
| 采集基线 | Android 源码 `67970a10b16f90d3cdaf50b487a31bf75950f938`；`appDebug`；AVD `Medium_Phone_API_37.0`；Android 17 / API 37；1080×2400 @420dpi；系统字体缩放 1.0；系统夜间模式 `no`；**应用主题显式深色、纯黑关闭**；隐藏状态栏/导航栏均关闭 |

**边界（照移交声明原样记录，不扩大）**：这是 `appDebug` 构建在 API 37 模拟器上的结果，**不是 release 包证据，也不是 API 12 设备证据**。跨平台不要求像素级一致，只用于判断「动作语义是否相同」。

### 一、翻页转场：三种动画确认为两页同屏

判据是各模式原视频抽出的 `*-frame-during.png`（中间帧），不是翻页后的静态图。

| 档位 | 中间帧文件名 | 相对时间 | 画面实测 |
| --- | --- | --- | --- |
| `0` 覆盖 | `android-reader-animation-cover-frame-during.png` | 1.55s | **左右两页同屏**：左为旧页（页码 `1/11 27.3%`）正滑出，右为新页（页码 `2/11 29.5%`）已停在最终位置。画面无空白 |
| `1` 滑动 | `android-reader-animation-slide-frame-during.png` | 1.40s | 两页都在位移：左页滑出、右页自右缘滑入，右页排版位置与终态不同 |
| `2` 仿真 | `android-reader-animation-simulation-frame-during.png` | 1.55s | 页面右上角掀起折页，折线下方露出下一页内容，底部页码仍 `1/11 27.3%` |
| `3` 滚动 | `android-reader-animation-scroll-frame-during.png` | 1.60s | 竖向上滑，帧间 OCR 可辨段落 01→02→03 |
| `4` 渐变 | `android-reader-animation-fade-frame-during.png` | 1.60s | 新旧两页文字交叉淡入 |
| `5` 无动画 | 按该档行为**不列中间帧** | — | 仅 `-before` / `-after` 两张 |

**结论（已由视频验证）**：COVER 是「新页静止底页 + 旧页盖在上面滑走」，不是「两页同时位移」。这与 `ReaderPageTransition.kt` 的 `transforms(COVER)` 返回 `next = ReaderPageTransform()`（位移 0）+ `currentOnTop = true` 完全吻合，**KI-EXP1 里那条依据源码推断的语义描述，现升级为有视频佐证**。SLIDE 与 COVER 是两套不同动作，本地曾把两者实现成同一套，该判断得到独立确认。

### 二、开书排版：上游无「整章滚动」中间态

- `android-reader-txt-layout-page-01.png`（TXT 第 1 章第 1 页，24sp、覆盖）：顶部有 `第1章 基线章节1` 标题，正文从段落 `01` 起。
- `android-reader-txt-layout-page-02.png`（同一章第 2 页，右向左滑动一次）：**顶部无重复标题**，正文自上一段续行开始，段落 `04` 出现在中部。

**结论（已由截图验证）**：上游两页的正文起点口径一致，没有出现「先渲染整章连续滚动、再切成分页」的形态切换。KI-EXP2 的修法方向（首帧即为分页）与上游行为一致。

### 三、滚动档在极小字号下的形态

`android-reader-txt-font-min-5sp.png`（5sp）显示整章连续铺开、进度 `1/1 50.0%`。这不是切换了渲染形态，而是「一页容得下整章」——仍属分页容器，只是页数为 1。**不能拿它当作「上游也存在整章滚动兜底」的证据**。

### 四、进度条：圆点分段 + 竖线滑块

`android-reader-progress-position.png`、`android-reader-controls-expanded.png` 实测：滑块是一根细长**竖线**（不是圆点），轨道按页分段显示为**圆点**，已读段实心填充，左右各有 `←` / `→` 切换章节按钮。

**本地差异**：`entry/src/main/ets/pages/ReaderPage.ets:4726` 用 `.blockSize({ width: 12, height: 12 })`，滑块是 12×12 的圆。**这是视觉差异，不是功能缺陷**；是否对齐留待产品判断，本轮不改。

### 五、目录面板与更多操作

- `android-reader-directory-panel.png`：顶部四页签 `信息 / 目录 / 书签 / 笔记`；搜索框右侧五个按钮（搜索、刷新、`#`、排序、更多）；章目行右侧显示字数（如 `3877字`）。
- `android-reader-more-actions.png`：两行四列共 8 项——`听书下载 / 编辑内容 / 添加书签 / 文本处理 / 反转内容 / 重新分段 / TXT 目录规则 / 设置编码`。

这两张可用于 `BOOKSHELF.md` B 块与 `READER-CONFIG.md` E 块的界面级对照，但**本轮只登记证据存在，不据此改任何行的状态**。

### 六、选词菜单：未采到实际弹出画面（重要边界）

- 包内 `android-reader-selection-menu-config.png` / `-actions.png` / `-hidden-items.png` 是**设置页**（`阅读器控制栏 → 设置 → 更多 → 编辑选择菜单`），可见一级菜单项 `复制 / 分享 / 浏览器 / 朗读 / 书签 / …` 及每项的显隐、排序图标。
- **未捕获**：长按正文后的选区手柄、实际选词弹出菜单及其展开态、点「标记」后的样式面板。
- 原因（移交声明原文）：ADB 注入的长按被阅读页识别为翻页，没有产生可核实的选区。
- 因此：`ZIP-BOOKMARK.md` F 块那 34 行**继续标「依据源码推断」**，不得改标「已由截图验证」。若要收口，需另做人工长按采集。

### 七、与 HarmonyOS 端当前状态的对照（本轮新发现）

核对基准包时同步复查了本地实现，画布会话（`baf856f` → `38debc1`，9 个提交）已完成：

- 五种转场全部接到画布：COVER / SLIDE / FADE 在 `ReaderCanvasSurface.ets`，折页在 `ReaderPageCurl.ets`（390 行，照 `PageCurlGeometry.kt`），滚动在 `ReaderScrollPolicy`。
- 选区自绘已落地（`ReaderCanvasSurface.ets` 内 `selection` 命中 41 处），把手半径 7vp + 描边 2vp，长按 600ms 起选。
- 老 Span 路径已删净：`ReaderPageTextLines` / `ReaderPageTextJoined` / `ReaderGlyphSpan` 命中 **0**。
- `ReaderPage.ets` 5269 行，`entry/src/main/ets/reader/` 三个模块合计 2406 行。

**结论**：KI-EXP1 / KI-EXP2 / KI-EXP3 三者在 `KNOWN-ISSUES.md:122` 已标「已接」，与本轮基准包的实测语义**方向一致、无冲突**。基准包的价值转为「后续复核的参照物」，而非「待修清单」。

**未验**：本轮的对照是「读图 vs 读代码」，**没有在 HarmonyOS 设备上做逐帧比对**。跨平台不要求像素级一致，但「COVER 是否真的不露空白」仍以 `VALIDATION.md` 里那次五种转场各连翻 20 页的设备记录为准，基准包不替代它。

**复原**：本轮无代码改动、无设备操作、无设置变更。基准包只解包到仓库外目录。

## 2026-11-02 N 端阅读器四项缺陷与两项发版风险（画布缓存释放 / 无动画重绘 / 进度条重绘 / 启动恢复 await / catch 日志 / .tmp 忽略）

- 基线：`main` HEAD `af3651f`（任务书写的 `8d89325` 是它的祖先，`8d89325..af3651f` 有 8 个提交，行号已整体偏移，全部按语义定位）。工作区开工时干净，无其他会话改动。
- 设备：HarmonyOS 模拟器 `127.0.0.1:5555`（API 26），包 `io.legado.harmony`，1280×2832。
- 构建：`bash scripts/build-hap.sh` → `BUILD SUCCESSFUL in 1 min 10 s 502 ms`（33 tasks，17 executed），产物 `entry/build/default/outputs/default/entry-default-unsigned.hap`；`hdc install -r` 覆盖安装成功。唯一告警仍是既有的 `No signingConfig found for product default`。

### 改动清单（源码接入：源码已接入）

| 项 | 文件:行 | 改动 |
| --- | --- | --- |
| 缺陷一 画布图片缓存不释放 | `entry/src/main/ets/pages/ReaderPage.ets:690` | `aboutToDisappear()` 在 `resetPageTurnTransition()` 之后补 `this.readerCanvasRenderer.clear();`，与退出阅读页那批释放同处 |
| 缺陷二 无动画翻页不重绘 | `entry/src/main/ets/pages/ReaderPage.ets:1930-1936` | `turnReaderPage()` 的 `pageAnimation === 5` 分支补 `this.paintReaderCanvas()` |
| 缺陷三 拖动进度条不重绘 | `entry/src/main/ets/pages/ReaderPage.ets:4738-4743` | `Slider.onChange` 的 `isPageProgressMode()` 分支补 `this.paintReaderCanvas()` |
| 缺陷四 12 个 restore 未 await | `entry/src/main/ets/pages/Index.ets:638,653` | 14 行 restore 调用抽成 `private async restoreStartupState(context: Context)`，其中只 `await this.restoreReaderSettings(context)`；其余保持并发（`aboutToAppear` 是同步生命周期，不能直接写 await） |
| 风险五 catch (_) 空吞 | `ReaderPage.ets` 12 处、`BookRepository.ets` 18 处、`BackupRepository.ets` 13 处 | 全部改 `catch (error)` + `console.error('[模块] 动作失败: ${error}')`，控制流不变（失败后继续） |
| 风险六 .tmp-* 未忽略 | `.gitignore:8-9` | 加中文注释 + `.tmp-*` |

缺陷一的边界按任务书守住：`clear()` 只加在 `aboutToDisappear()`，**没有**加进 `onReaderContentChanged()`——换章要复用缓存，那条路径仍然只走 `clearParagraphs()`。

批量改 catch 时用花括号深度跟踪脚本查过一遍变量遮蔽：唯一真嵌套在 `entry/src/main/ets/data/BackupRepository.ets:2338`（`ensureDirectory()` 的内层 try），已改名 `catch (probeError)`，外层 `if (error instanceof Error) { throw error; }` 语义恢复。改后三文件 `grep -c "catch (_)"` 全为 0。

### 缺陷二 设备验收通过

前置：阅读设置 → 翻页动画选「无动画」（`pageAnimation = 5`）。**必须用无动画模式**，其余四种动画本来每帧重绘，看不出这个缺陷。

- 改前行为：`pageAnimation === 5` 只改 `currentPageIndex` 就 return；`currentPageIndex` 是 `@State` 但没有 `@Watch`（22 个 `@Watch` 无一盯页码），画布重绘全靠显式调用。
- 实测：第 1 页按右侧翻页 → 底部进度 `1/17 0.5%` → `2/17 0.9%`；正文区（crop `(0,560,1280,2200)`）像素比对 **changed 426996 / 2099200 = 20.3%**，两页画面不同 → 画布确实重绘了。**通过。**

### 缺陷三 设备验收通过

同模式（无动画）下把底部 `Slider` 从第 2 页拖到第 15 页：

- 进度 `2/17 0.9%` → `15/17 6.8%`；正文区像素比对 **changed 380176 / 2099200 = 18.1%** → 重绘生效。**通过。**

两个数字与上一轮（b3 记录里 21.9% / 17.1%）同量级，口径一致。

### 缺陷一 设备验收未验（阻塞原因已定位）

**结论：源码已接入、构建通过、覆盖安装成功，但设备验收未验。** 不能写「通过」。

阻塞原因不在本次改动，而是画布图片渲染链路本身在本地没打通：

1. 造了两本带图 EPUB 并都导入成功：探针书（6 章 × 3 张手写 PNG = 18 张，刻意小于 `ReaderCanvasSurface.ets:704` 的 `IMAGE_CACHE_LIMIT = 32`，这样 LRU 不会淘汰，`clear()` 是唯一释放路径）、以及用户指定的 `测试/古神？这分明是白发兽耳小萝莉 作者：尚简.epub`（5.49 MB，1378 章，封面 JPEG 600×800）。
2. 两本的图片文件都确实落到了沙箱：探针书 `files/epub-assets/local-1793587448804/0.img … 17.img`，真实书 `files/covers/local-1793588129455.img`（268022 字节，pull 下来确认是合法 JPEG）；正文里 `[[EPUB_IMAGE:file:///...]]` 标记齐全。
3. 但阅读页画布**一个图片像素都没画**：正文区颜色统计只有背景色与正文白字，既没有图、也没有 `drawImageBox()` 的灰底占位（`0x2E808080`）。探针书整页 `distinct = 1` 全黑。
4. **这是既有缺陷，不是本次改动引入**：把 5 个改动 `git stash` 掉、用 HEAD `af3651f` 原样构建装机，探针书同样不出图（`distinct = 1`、`nonblack_px = 0`）；恢复改动重新构建装机后现象一致。

因此 `imageCache` 里根本没有 `PixelMap`，无论调不调 `clear()` 都观测不到 pixelMap 泄漏。已采集的内存曲线**只能说明「进出阅读页本身不涨 native heap」，不能作为缺陷一通过的证据**：

真实 EPUB 进出 10 次（`hidumper --mem <pid>`，书架点开 → 7 s → 返回 → 4 s）：

| 次数 | native heap (kB) 阅读页 | native heap (kB) 书架 |
| --- | --- | --- |
| 1 | 36881 | 43635 |
| 2 | 38367 | 43643 |
| 3 | 38755 | 43803 |
| 4 | 39215 | 43939 |
| 5 | 38903 | 43899 |
| 6 | 39227 | 44255 |
| 7 | 39259 | 44095 |
| 8 | 39459 | 44287 |
| 9 | 39537 | 44265 |
| 10 | 39325 | 44273 |

第 1 次之后平台在 43.6–44.3 MB（±700 kB 抖动），不随次数线性增长。探针书同样在第 1–2 次后平台在 44 MB 左右。**但因为缓存里没有 pixelMap，这份数据与缺陷一无关。**

排查结论（供下一轮接手，本轮按「只改这几处」的范围没有动它）：尺寸拿不到时 `entry/src/main/ets/pages/LocalReaderPaginator.ets:251` 的 `if (sourceWidth <= 0 || sourceHeight <= 0) { continue; }` 会直接跳过这张图，既不画图也不画占位；`ReaderPage.ets:1546-1560` 虽然准备了 `placeholderExtent` 占位并写进 `paginationUsesImagePlaceholder`，但**该字段全仓没有任何读取点**（只在 `:460` 声明、`:1560` 赋值）。也就是说「占位兜底」这条路实际上没接上。

另：这台模拟器上读不到 ArkTS 的 `console.*` 输出（`hilog -x` 全量 7064 行里没有任何 `A03d00/JSAPP` 域，`hilog -x -T JSAPP` 为空），所以无法用日志确认 `image.createImageSource()` 是否抛错。风险五新增的 `console.error` 在这台设备上同样**无法取证**，只保证源码接入与构建通过。

### 缺陷四 设备验收未验

`restoreReaderSettings` 现在会 await 完再返回，理论上开书不会再「先按默认排版排一次再跳变」。但排版跳变是个瞬时现象，模拟器截图（`uitest screenCap` 单帧）抓不到这个时序，本轮**没有**做出可信的前后对比，按「未验」记录。源码与构建均已通过。

### 风险六 无法按任务书口径验证

任务书说 `.gitignore` 加 `.tmp-*` 后「确认 git status 里那 18 个 `??` 文件消失」，但本工作区开工时**就没有任何 `.tmp-*` 文件**（`find` 全仓无匹配，`git status --porcelain` 无 `??` 条目）。规则已加，属预防性改动，无法验证「18 个文件消失」这件事。

### 提交

用 `git diff` 生成的 patch 只挑本会话的 5 个文件（`.gitignore`、`ReaderPage.ets`、`Index.ets`、`BookRepository.ets`、`BackupRepository.ets`），没有 `git add -A`；一次性改写脚本 `scripts/tmp-add-catch-logs.py` 已删除，未入库。

## 2026-11-02 N 端阅读设置背景样式区对齐上游（KI-STYLE1）

目标：全局设置页「背景」样式卡行与上游 `GlobalThemePage.kt` 的背景样式区对齐——选中态、新增卡、主题列表入口卡、长按编辑，以及样式表从硬编码常量改成可增删并持久化。登记见 [KNOWN-ISSUES.md](KNOWN-ISSUES.md) 的 KI-STYLE1。

### 源码接入

| 文件 | 改动 |
| --- | --- |
| `entry/src/main/ets/data/ReaderSettingsRepository.ets` | `ReaderBackgroundStyle` 补 `id`；新增 `READER_STYLE_PRESET_COUNT = 5`、`READER_STYLE_NEW_DAY_COLOR = '#EEEEEE'`、`READER_STYLE_NEW_NIGHT_COLOR = '#000000'`、`copyReaderBackgroundStyles()`；`ReaderSettingsSnapshot` 新增 `backgroundStyles`；`load`/`save` 增 `backgroundStyles` 键（JSON 字符串），四处写死 `Math.min(5, ...)` 的夹取改成按表长夹取；新增 `encodeBackgroundStyles` / `decodeBackgroundStyles` |
| `entry/src/main/ets/pages/Index.ets` | 新增 `@State backgroundStyles`；`getPaperColor` / `setReaderPaperIndex` 改按表长取；`persistReaderSettings` 与两处设置恢复都带上 `backgroundStyles`；新增 `addReaderBackgroundStyle` / `updateReaderBackgroundStyle` / `removeReaderBackgroundStyle` / `moveReaderBackgroundStyle`；`ReaderSettingsPage` 四处调用点同步补参数 |
| `entry/src/main/ets/pages/ReaderSettingsPage.ets` | `BackgroundOption` 选中态改成底部满宽横带+勾；样式行 `ForEach` 改遍历 `backgroundStyles`、补长按手势、追加「+」与「>」两张 `BackgroundStyleActionCard`；新增「编辑背景样式」「主题列表」两个 `detailSheet` 分支；新增 `getBackgroundStyleLabel()` 处理空名字回落 |
| `entry/src/main/ets/data/BackupRepository.ets` | `toAndroidReadConfig` 与 `paperIndexFromAndroidConfig` 改从 `settings.backgroundStyles` 取色 / 找下标，不再读常量表 |

### 构建通过

`bash scripts/build-hap.sh` → `BUILD SUCCESSFUL`（最后一次增量 37 s 349 ms）。期间遇到并修掉一个编译错误：`Property 'justifyContent' does not exist on type 'StackAttribute'`——ArkUI 的 `Stack` 没有 `justifyContent`，改用外层 `Column().justifyContent(FlexAlign.Center)` 包内层 `Stack({ alignContent: Alignment.Center })`。`hdc install -r` 覆盖安装成功。

### 设备验收

设备 `127.0.0.1:5555`（API 26 模拟器），包 `io.legado.harmony`。入口：书架点书 → 正文中部 `(640,1400)` 唤出菜单 → 右下齿轮 `(1100,2532)`。样式卡行在 y `2180-2376`，横向滚动**必须用 `uitest uiInput fling`**（`drag` 在这条 `Scroll` 上完全滚不动）。

| 验收项 | 证据 | 结论 |
| --- | --- | --- |
| ① 选中态 = 底部满宽横带 + 勾 | 截图 crop `(100,2150,1280,2400)`：选中卡「微信读书」底部整条浅紫横带，带内深色勾 | **通过** |
| ② 「+」新增样式卡 | 滚到右端后同口径截图可见「预设3 预设4 预设5 ＋ →」 | **通过** |
| ③ 「>」主题列表入口卡 | 同上，右箭头卡在最右；点击打开标题为「主题列表」的详情页 | **通过** |
| ④ 长按进「编辑背景样式」 | `uitest uiInput longClick` 500 ms 打开详情页，显示「样式名称 / 日间背景颜色 / 夜间背景颜色 / 保存」 | **通过** |
| ⑤ 新增样式 | 点「+」后样式表新增一条，卡片显示回落名「背景样式」，选中态跟到新卡 | **通过** |
| ⑥ 删除自建样式 | 主题列表里删掉一条自建样式，行数减一，`预设5` 与另一条自建样式保留 | **通过** |
| ⑦ 上移排序 | 点自建行的上箭头，该行与 `预设5` 交换位置（dumpLayout 里 `背景样式` 的 y 从 1910 变 1658、`预设5` 从 1429 变 1933） | **通过** |
| ⑧ 改名即时生效 | 改名保存后卡片立刻显示新名字（不再需要重启） | **通过** |
| ⑨ 冷启动保持 | `aa force-stop` 后重启：preferences 里 `backgroundStyles` 存了 7 条（6 条预设 + 1 条自建），自建那条 `id=style-…-7`、`name`/`dayColor` 均为用户设定值；重开设置页选中项仍指向自建那份 | **通过** |

### 边界与教训

- 上游 `ReadStyleItem` 的 `bgType` / `textColor` / `*EInk` 字段没有搬过来：本地背景类型与文字颜色是全局单份，搬过来会出现「同一份状态两个来源」。因此本地样式条目只有名字与日/夜背景色，属于**有意的模型裁剪**，不是漏做。
- 主题列表页按上游 `ThemeListContent` 的「列表」形态实现（预览卡 + 名字 + 预设/自建标签 + 上移/删除），没有做网格布局、搜索、批量勾选、置顶置底与拖动排序——这些是上游那一页的完整能力，本轮目标是「样式可增删 + 能在设置页管理」，其余留待需要时再对齐。
- `ForEach` 的 key 必须带上会被就地改动的字段（名字与两个颜色）。只按 `id` 做 key 时，改名/改色后 ArkUI 认为子项未变，卡片一直显示旧值，要重启才更新——这个坑在验收 ⑧ 之前踩到过。
- `layoutWeight(1)` 放在 `Text` 上会把外层 `Column` 撑高，导致名字与副标签被拉开；要放在 `Column` 上并配 `justifyContent(FlexAlign.Center)`。
- 模拟器上 `uitest uiInput text` 是**追加**而不是替换，`inputText` 需要坐标且对已聚焦输入框不生效；清空输入框要用 `uitest uiInput keyEvent 2055`（`KEYCODE_DEL`）连按，`keyEvent 2072` 无效。

### 提交

用 `git diff` 生成的 patch 只挑本会话的 4 个文件（`ReaderSettingsRepository.ets`、`Index.ets`、`ReaderSettingsPage.ets`、`BackupRepository.ets`）加两份文档，没有 `git add -A`。

## 2026-11-02 N 端阅读进度与目录 ANR（KI-PROG1–KI-PROG5）

- 设备：HarmonyOS 模拟器 `127.0.0.1:5555`（API 26），包 `io.legado.harmony`，1280×2832。
- 构建：`bash scripts/build-hap.sh` 每次源码改动后均跑，全程 `BUILD SUCCESSFUL`。唯一告警是 `No signingConfig found for product default`。
- 提交：`git diff -- <本次 3 个文件>` 生成 patch 后 `git apply --cached`，**没有用 `git add -A`**。

### 源码接入（第 1 级）

| 项 | 文件 | 状态 |
| --- | --- | --- |
| KI-PROG1 开书回章首 | `entry/src/main/ets/pages/Index.ets`（`openBook()` 的 `readerStartAtChapterBeginning`）、`entry/src/main/ets/data/BookRepository.ets`（`StoredReadConfig.chapterProgress`、`readBookRow()`、`toBookArgs()`） | 源码已接入 |
| KI-PROG2 目录跳章自激循环 | `entry/src/main/ets/pages/ReaderPage.ets`（`refreshDisplayChapterTitle()`、`onChapterTitleChanged()`） | 源码已接入 |
| KI-PROG3 图片尺寸防抖重排 | `entry/src/main/ets/pages/ReaderPage.ets`（`rebuildReaderPages()`、`scheduleImageSizesPaginationRebuild()`、`loadContentImageSizes()`） | 源码已接入 |
| KI-PROG4 折页阴影 `25 * 1.414` | `entry/src/main/ets/reader/ReaderPageCurl.ets` | 经比对上游源码确认不是缺陷，**不改** |
| KI-PROG5 大目录 ANR | `entry/src/main/ets/pages/CatalogPage.ets`（`aboutToAppear()`、`loadChapterWordCountsAfterRows()`、`loadChapterWordCounts()`）、`entry/src/main/ets/data/BookRepository.ets`（`byteOffsetsToCharIndices()`、`sequentialChapterRanges()`、`chapterBody()`、`forEachChapter()`） | 源码已接入 |

### 构建通过（第 2 级）

全部改动落盘后 `BUILD SUCCESSFUL`（多次，最长一次 `in 1 min 2 s 826 ms`），产物 `entry/build/default/outputs/default/entry-default-unsigned.hap`，`hdc install -r` 覆盖安装成功。ArkTS 只有既有 `WARN`（RdbSchema/RdbStore/RdbCodec 废弃 API、`Function may throw exceptions`），无 ERROR。

### 设备验收（第 3 级）

**验收 1 阅读进度跨退出保留 —— 通过。** the-metamorphosis（17 页）打开 → 点正文中部 `(640,1400)` 唤出菜单 → 拖滑块到 `5/17 2.3%` → 收起菜单 → Back 回书架 → 重新打开，**仍是 `5/17 2.3%`、标题「第1章(1)」**。修复前是 `1/9 0.1%`。

**验收 2 阅读进度跨进程冷启动保留 —— 通过。** zh-book 打开 → 拖滑块到 `3/10 2.7%` → Back → `aa force-stop` → `aa start` 冷启动 → 重新打开，**仍是 `3/10 2.7%`、标题「第15章 对练」**。

**验收 3 大目录不卡死 —— 通过。** 见 KI-PROG5：1378 章的 `古神？这分明是白发兽耳小萝莉` 目录 6461 ms 渲染完成（`共 1378 章` + 每章字数），572 章的 zh-book 2522 ms；两本修复前都必 ANR。`/data/log/faultlog/faultlogger/` 最新一条 `appfreeze-...` 停在修复前那一轮（14:56），此后整轮验收未再产生新日志。

**验收 4 连续从目录跳章 —— 通过。** 1378 章书连续 5 轮跳章，落地章节与目标一致（第19章 / 第24章 / 第29章），`pidof` 全程 13273 未变；zh-book 跳第 21 章成功，`pidof` 14043 未变。

**验收 5 带图 EPUB 开书时间 —— 通过（口径是「不退化」）。** 改后 3645 / 4046 / 3981 ms，基线 3982 / 4131 / 4029 ms，噪声内无可测退化。这本 EPUB 全书只有 1 张图，N=1 的路径本来就只重排一次，KI-PROG3 的收益体现在多图章节，本机没有可用样本。

**验收 6 翻页动画无整页空白 —— 通过。** 仿真动画连翻 6 页 `2/16 → 8/16`，正文区文字像素占比 9.19% / 9.53% / 9.95% / 9.53% / 9.57% / 9.28%，无空白页。

### 边界与教训

- **KI-PROG2 的「跳章卡死」现象本机复现不出来**：A/B 对照（stash 掉改动重新构建装机）在 13 章书上跳章同样正常，因为 `replace_rules` 表 0 条、`applyTitle` 是 `async` 会让出事件循环。改动去掉的是确定存在的自激回路，只能按「源码已修 + 跳章验收通过」登记。
- **A/B 对照必须做**：不做就会把「改动正确」误报成「现象已修复」。
- **KI-PROG5 的决定性证据是关开关对照**：把 `tocCountWords` 改成 `false` 后 1378 章目录立刻正常渲染，改回 `true` 必被杀 —— 直接把卡死定位到字数统计路径。
- **只补传参不够**：`loadChapterWordCounts()` 补传 `chapterRows` 之外还必须等 `loadChapterRows()` 完成，否则那时 `chapterRows` 还是空数组，`forEachChapter` 仍会退回 `deriveChapters()`。第一版只补了传参，实测目录仍打不开。

## 2026-11-02 N 端阅读器正文改画布逐行绘制（KI-EXP1/KI-EXP2/KI-EXP3 收口）

- 设备：HarmonyOS 模拟器 `127.0.0.1:5555`（API 26），包 `io.legado.harmony`，1280×2832。
- 构建：`bash scripts/build-hap.sh` 每次源码改动后均跑，全程 `BUILD SUCCESSFUL`（12 s – 1 min 6 s）。唯一告警是 `No signingConfig found for product default`。
- 改动文件：
  - 新增 `entry/src/main/ets/reader/ReaderCanvasSurface.ets`（1892 行，画布绘制主体：页面窗口、逐行排版、五种转场策略、滚动模型、选区自绘、高亮样式分段、图片预取）。
  - 新增 `entry/src/main/ets/reader/ReaderPageCurl.ets`（390 行，折页几何与触点策略，照上游 `PageCurlGeometry.kt` / `ReaderCurlTouchPolicy`）。
  - 改 `entry/src/main/ets/pages/ReaderPage.ets`（5358 → 5253 行：接入画布、翻页改逐帧动画、删掉全部 Span 渲染分支与整章 `Scroll` 分支；末尾按「画布渲染 / 分页 / 手势 / 菜单」四块加了分区横幅与文件头索引）。
  - 新增 `entry/src/main/ets/reader/ReaderCanvasStyleCodec.ets`（124 行，画布样式的纯函数编解码：颜色串转 ARGB、标记/规则效果转画布 decoration 口径、把手命中距离、长度量归一、字形计数）。
  - 改 `entry/src/main/ets/pages/Index.ets`（17 行：阅读页渲染门控）。
  - 新增 `scripts/build-hap.sh`（构建封装，导出 `JAVA_HOME=$DEVECO_ROOT/jbr`）。

**关键实现选择**：
1. **单位口径定死为 px**。`new DrawingRenderingContext(LengthMetricsUnit.PX)`，分页器 `LocalReaderPaginator` 产出的量全是 vp，进绘制层统一乘 `ReaderCanvasLayout.vpScale`（= `vp2px(1)`）。这条不统一会出真实事故：初版把 vp 当 px 用，一页 22 行的行高只剩应有值的约 1/2.25，所有行叠在页面左上角。
2. **每页先铺纸面**。上游是整页位图快照，天然不透明；本地逐元素自绘，转场时两页重叠会互相透出形成双重字影（折页首轮实测）。修法是 `drawSlot()` 里先 `fillPageSurface()`（`pageSurfaceArgb` + 不透明 Brush）再画字，`drawCurl()` 的底页/reveal/纸背/兜底四处同样先铺。
3. **绘制拆成「先算几何、再逐元素画」**。`layoutPage()` 产出 `ReaderCanvasPageGeometry`（每个 item 的 `left/top/widthPx/heightPx`），绘制与命中测试共用同一套坐标。此前两套算法各算一遍的写法已经出现过「日志坐标对、屏幕画不出」的排查成本。
4. **`Paragraph.paint()` 会改画笔状态且不恢复**。`drawTextBox()` 里必须用 `canvas.save()` / `canvas.restore()` 包住，否则同一块画布后续的 `attachBrush + drawRect`（选区条带、把手、下划线）全部不落像素 —— 日志照样打印 `drawRect done`，屏幕上什么都没有。
5. **滚动模式也搬进画布**。分页与连续滚动共用同一张画布（上游 `ScrollPageStack` 一条通路），`ReaderScrollPolicy`（`pageStep` / `stepDurationMillis` / `apply`，逐项照 `ReaderScrollState.kt`）算步距与越界，四页按 `scrollExtentPx` 堆叠、整体 `translate(0, stackOffsetY)` 平移，`clipRect` 保证不画出视口。滚动模式额外两个不变量：`calculateReaderBottomJustifyGap()` 必须返回 0（连续滚动没有「页底」，摊进剩余高度会把下一页首行推到本页已画的行上），进度必须按「当前页 + 全部前置页高度」的绝对位移算（`readerScrollAbsoluteOffset()`），否则每换一页进度条就打回 0。
6. **高亮规则与选区一样走画布自绘**。`ReaderHighlightRule` 的正则命中区间转成 `ReaderCanvasStyleRange`，交给 `ParagraphBuilder` 逐段 `pushStyle`（字色 / 背景块 / 下划线），用户划线里 `effect === 'text'` 的字色排在高亮规则之后（对齐上游 `LegacyReaderStyleRangeMapper` 的 `priority = 10_000 + index`）。`RectStyle` 的四个圆角是 API 12 必填项，漏写报 `10505001`。
7. **选区按上游 `feature/reader/core/selection/` 自绘**，不做简化：几何走 `getRectsForRange` / `getGlyphPositionAtCoordinate` / `getWordBoundary`，条带色 `0x63858585`（上游 `legacySelectionFill`），两个把手半径 7vp + 描边 2vp，长按 600 ms 起选，`canvasSuppressTap` 吞掉长按抬手那次 tap（对齐上游 `suppressTap`）。把手是「竖线 + 圆柄」胶囊：圆心在矩形 `bottom + radius`，竖线只画到矩形 `bottom`，命中热区 28vp 且按胶囊中轴线求最短距离（对齐上游 `drawPinHandle` / `handleHitRadius`）；淡出 90 ms、淡入 140 ms 用 `UIContext.createAnimator` 做真补间。
8. **选区有三套坐标口径，必须各自对齐**：① 四页窗口只对当前页记几何与画选区（`recordGeometry` / `drawSelection` 两个标志），否则最后画的邻页顶掉当前页坐标；② 手指 `finger.localY` 相对外层 `Stack`，画布顶边用 `getComponentUtils().getRectangleById()` 的 `windowOffset.y` 两者相减（同口径，状态栏自动抵消），**不能**直接减 `Area.position.y`；③ 滚动模式再减 `scrollOffset`。拖动取位用 `positionAt()` 在一行所有元素间推进，不能沿用单元素的 `glyphOffsetAt`（分页器按标点/样式切元素，单元素会被行末 clamp 住，选区再也扩不出去）。

**踩坑**：
1. **未被引用的 `.ets` 不参与类型检查**。往 `ReaderCanvasSurface.ets` 末尾塞 `const __probe: number = "not-a-number";` 后构建仍 `BUILD SUCCESSFUL`，构建产物里也搜不到该文件 —— **构建通过不等于新文件过了编译**，必须先有 import + 使用再拿构建当证据。
2. **`Area.width/height` 本来就是 vp**（与 `toDimension` 同口径），再套一次 `px2vp()` 会让分页高度缩小 2.75 倍、一页只剩 6 行。`position.y` 是 `Length | undefined`，必须 `?? 0`，否则报 `10605999`。
3. **`refreshCanvasSelectionMenuAnchor()` 必须「差值 > 0.5 才写 `@State`」**，否则 `paint → 写状态 → 重建 → paint` 形成无限重绘循环（hilog 里每秒刷几十条）。
4. **底部对齐的 gap 是全局单值**，只在 `rebuildReaderPages()` 里按当时的 `currentPageIndex` 算一次；翻页 `onFinish` 不重算就会沿用上一页的位移，把最后一行推出画布下边缘（表现为末行只露上半截）。修法是 `refreshReaderBottomJustifyGap()` 在 `onFinish` 里重算。
5. **删调试日志用正则批量删 `console.info(` 的前半行会留下孤儿续行**，一次删出 56 个 `10505001 ';' expected`。多行日志必须整段按行号删。
6. **`uinput -T` 不支持长按**，长按要用 `uitest uiInput longClick <x> <y>`；`hdc` 命令在 Git-Bash 下必须 `export MSYS_NO_PATHCONV=1`，否则 `/data/...` 被转成 Windows 路径报 `realpath nullptr`。

**验收①KI-EXP1 翻页无整页空白**：COVER 连翻过程中每帧都有完整正文，进度从 `1/9 0.0%` 走到 `3/9 0.1%` 无空白帧；SLIDE（`pageAnimation=1`）抓到旧页左移约半屏、新页紧贴其右缘进入；FADE（`pageAnimation=4`）抓到新旧两页文字交叉淡入；折页（`pageAnimation=2`）抓到左半当前页 / 右半新页的中间态。**通过。**

**验收②KI-EXP2 开书不出现整章滚动**：冷启动 `aa force-stop` → `aa start` → 点书架进书，连续 6 次 `uitest dumpLayout` 每次都只有 `Canvas=1、Scroll=0`，全程从未进入整章滚动分支；首屏 21 个文字带、末行带底部未触画布下边缘（无裁切）。**通过。**

**验收③KI-EXP3 选区与划词**：`uitest uiInput longClick 400 1000` 出灰色选区带 + 两个圆形把手 + 浮动菜单「复制 / 书签 / 划线 / 笔记」；拖把手跨行扩展（`longClick 400 800` 起选 → `drag 378 864 800 1100 700`，选区从 `sel=102-103` 扩到 `102-127`、终点把手随拖移到 `E=804,1203`，截图确认灰底覆盖两行、起点把手在上行终点把手在下行）；点「划线 — 笔记」面板回显完整选中文本（「“让我们来采访一下展馆主人金先生。」）与章节「zh-book / 第3章 盗神将至」，保存后正文下方出现绿色下划线；点「复制」菜单收起、选区色块保留。**通过。**

本轮修掉的两个真实缺陷（都在设备上先复现、修完复验）：① 长按落在元素末尾时 `start === end` 得到**零长选区**，`getRectsForRange` 拿不到矩形 → 屏幕上「有菜单但看不见选区、也抓不到把手」；`startCanvasSelectionAt` 现在会把起点回退一格。② 拖把手时端点跟手指走而不是跟把手走，且取位被单元素 clamp；改为记 `canvasHandleGrabOffsetX/Y` 再减 `radius` 回到行底做 `positionAt()`。

**验收④五种转场各连翻 20 页**：每改一次 `pageAnimation` 都 `aa force-stop` → `aa start` → 点书架进书，再连点右侧翻页 20 次。COVER(`0`) 到第 16 章 5/10；SLIDE(`1`) 到第 18 章 1/10；折页(`2`) 到第 18 章；FADE(`4`) 到第 20 章 2/10；滚动(`3`) 到第 22 章 8/9 `4.0%`。全程每帧都有完整正文，无整页空白、无末行裁切、无两页文字互相透出。滚动模式另验跨章：连点 12 次从第 4 章滚到第 5 章，`scrollOffset` 越界时正确换页并清选区。**通过。**

滚动模式修复前实测到两个真实缺陷（均已在画布侧修掉）：① 底部对齐位移让「当前页末行与下一页首行叠在同一处」；② `scrollOffset` 是相对当前页的偏移，进度条每换一页就打回 0。

**验收⑤阶段 D 拆分与死代码清理**：`ReaderPage.ets` 里 `getMarkingBackground` / `getMarkingDecorationType` / `getMarkingDecorationStyle` 三个只被 Span 分支用过的标记样式 helper 已删除；`readerCanvasArgb`、`readerCanvasHighlightDecoration`、`readerCanvasMarkingBackgroundArgb`、`readerCanvasMarkingDecoration`、`canvasHandleDistance`、`toDimension`、`getReaderTextGlyphCount` 七个纯函数搬到新建的 `ReaderCanvasStyleCodec.ets`（不再挂在 `this` 上）。文件按四块加分区横幅（画布渲染 / 分页 / 手势 / 菜单）并在 struct 顶部写明索引。`onTextSelectionChange` / `copyOption` / `ReaderGlyphSpan` / `ReaderPageTextLine` / `getReaderTextGlyphs` 的命中数全为 0，`bindSelectionMenu` 只剩一条解释历史行为的注释，确认无两套渲染并存。装机后 `uitest dumpLayout` 仍是 `Canvas=1`、无 `Scroll` 节点；长按选词 + 拖把手跨行复验通过。**通过。**

**未验 / 已知差异**：
- 折页在程序化翻页（点击翻页，非手势拖拽）下触点轨迹全程近水平，曲线弧度很浅，视觉上接近「左右半屏分界」；与上游 `programmaticX/Y` 同款轨迹，未额外调参。
- 受限于模拟器，只能验证点击翻页与长按选区两种输入；手势拖拽折页的跟手效果需真机补验。
- 页眉页脚、章节标题、书签角标仍由 ArkUI 绘制（不搬画布），与上游一致的只有正文层。

**复原**：`pageAnimation` 回 `0`（COVER）、`pageTouchSlop` 回 `500`；阅读设置其余键未改。

**改 prefs 的正确写法**：`re.sub(r'(key="%s" value=")[^"]*(")', ...)` 单键替换后必须 `xml.dom.minidom.parseString` 校验再推设备。本轮曾用 `re.sub(r'key="%s"[^/]*', ...)` 吞掉了 `/>` 的结尾斜杠，把 XML 写坏成 `//>`，应用把 `legado_reader_settings` 改名 `.broken` 并重置成 6 个键——**设备上的阅读进度与所有面板自定义值都会被清掉**。

## 2026-11-01 N 端 r317 深色模式收口复核：四条地基验收重新取证（纯验证，无代码改动）

r300–r316 十六批已把 [ZIP-THEME](parity/ZIP-THEME.md) 的 91 行推到「已接 81 / 未接 6 / 不适用 4」，剩余 6 行全部判「不接」。本节把任务书要求的地基四条在最终代码上重新取证一遍，避免结论停留在早期批次。

**复核环境**

- 设备 `127.0.0.1:5555`（API 26），包 `io.legado.harmony`，HAP 由 `assembleHap` 产出后 `hdc install -r` 装入。
- 起点 prefs：`legado_theme` 里 `paletteIndex=2.000000`（柠檬）、`themeMode=1`（浅色）。

**四条地基验收**

| # | 验收项 | 操作 | 结果 |
| --- | --- | --- | --- |
| ① | 主题设置页点「深色」→ 全 App 变深 | 我的 `(1152,2660)` → 设置 `(290,2244)` → 外观 `(168,729)` → 主题模式行点「深色」`(1029,2002)` | 整屏变深：`(640,300)=(18,18,20)`、`(60,1200)=(22,19,12)`；prefs `themeMode` 由 `1` 变 `2` |
| ① | 同上，重启保持 | `aa force-stop io.legado.harmony` + `aa start -a EntryAbility -b io.legado.harmony` | 重进书架仍是深色：`(640,300)=(22,19,12)`、`(640,2600)=(68,68,68)` |
| ② | 阅读页日夜按钮改全局 `themeMode` | 书架点书封面 `(150,900)` 进阅读页 → 点正文中部 `(640,1300)` 唤出菜单 → 点底栏齿轮 `(1090,2542)` 打开阅读设置面板 → 「背景」行右侧月亮图标 `(1122,2120)` | prefs `themeMode` 由 `2` 变 `1`（浅色）；阅读页纸张与底栏同时变浅 `(640,1000)=(88,112,90)`；返回书架后整页变浅 `(640,300)=(255,250,238)`、`(640,2200)=(255,250,238)` |
| ③ | 「跟随系统」跟随系统深浅 | r300 已验（见本文件 r300 节验收③），本轮未重跑 | 沿用 r300 结论 |
| ④ | prefs 读到 `themeMode` 三值 | `hdc shell "cat .../preferences/legado_theme"` | `string key="themeMode">2` → `1`，与界面同步变化 |

**踩坑（本轮新增）**

- 阅读页菜单在**深色纸色下几乎不可见**：`b.jpeg` 里顶栏 `#111217`、底栏同色，肉眼与正文的 `#000000` 混在一起，逐行亮度扫描才看出 137–520 与 2100–2700 两段有内容；判断菜单是否弹出不能靠截图肉眼看，要把截图整体提亮 5–6 倍再看，或直接比对 `uitest dumpLayout` 的节点数（弹出前后 82 → 82 时说明**没弹**）。
- `uitest dumpLayout` 对菜单里的图标按钮不暴露 text/description，只能靠提亮截图定位；底栏齿轮在 `(1090,2542)`、阅读设置面板「背景」行的月亮图标在 `(1122,2120)`。
- 阅读页单次点击正文中部偶尔不弹菜单（`handleReaderTapAt` 有 90ms 去抖 + 100ms `setTimeout`），连点或稍等再截图即可。

**结论**

四条地基验收全部成立。配合 ZIP-THEME 的 91 行盘面（无裸「未接」行、剩余 6 行均判「不接」并各附理由）与 r300–r316 每批的 `assembleHap` 记录，深色模式（`themeMode`）与主题配置（`themeConfig`）两个类别的落地工作到此收口。

## 2026-11-01 N 端 r316 深色模式阶段三：主题包管理（A12、B1–B12）与 themeConfig.json 导出（F5）

**改动**

- 新建 `entry/src/main/ets/data/ThemePackageRepository.ets`（1159 行）：主题包清单/落盘/打包/解包/资产/迁移。常量 `THEME_PACKAGE_FORMAT_VERSION = 1`、`THEME_MANIFEST_PATH = 'manifest.json'`、`SAVED_THEME_DIR = 'saved_themes'`、`MAX_THEME_ENTRY_COUNT = 4096`、`MAX_THEME_ENTRY_BYTES = 64 * 1024 * 1024`、`MAX_THEME_TOTAL_BYTES = 512 * 1024 * 1024`；资产 key 7 个（`background.light`/`background.dark`/`container.large.light`/`container.large.dark`/`container.item.light`/`container.item.dark`/`font.app`）；`ThemePortableConfig` 63 字段（对齐上游 `ThemeExportData` 中有本地对应功能的部分）；静态方法 `saveTheme`/`deleteSavedTheme`/`renameSavedTheme`/`readSavedTheme`/`loadSavedThemes`/`exportCurrentTheme`/`exportSavedTheme`/`importPackage`/`importLegacyJson`/`hasLegacySavedThemes`/`migrateLegacySavedThemes`/`uniqueSavedThemeName`/`validateExtracted`。
- 新建 `entry/src/main/ets/pages/ThemeManagePage.ets`：`CollapsingSettingsHeader` + 五个入口（保存当前设置 / 导出当前主题 / 导入主题包 / 导入旧版主题配置 / 迁移旧版主题，最后一项仅 `hasLegacyThemes` 时显示）+ 搜索框 + 已存主题列表（日/夜各 3 个 12dp 色点 + 应用/编辑/导出/删除）+ 底部命名面板（保存与重命名共用）。
- 新建 `entry/src/main/ets/data/ThemeConfigStore.ets`：`ThemeConfigEntry`（对齐上游 `ThemeConfigStore.Config` 8 字段）、`defaultThemeConfigs()` 内置 4 套（默认/典雅蓝/黑白/A屏黑）、`parseThemeConfigs`/`themeConfigsToJson`/`loadThemeConfigs`/`saveThemeConfigs`/`addThemeConfig`/`buildCurrentThemeConfigs`/`upThemeConfig`/`currentThemeConfig`。
- `entry/src/main/ets/model/Book.ets`：`ProfileRoute` 加 `APP_THEME_MANAGE = 'appThemeManage'`。
- `entry/src/main/ets/pages/ThemeSettingsPage.ets`：`onOpenThemeManage` prop；「主题管理」由 `onUnavailableAction('主题包管理尚未迁移')` 改为 `onOpenThemeManage()`。
- `entry/src/main/ets/pages/Index.ets`：`isProfileSettingsPage` 白名单加 `APP_THEME_MANAGE`；新增 `applyThemePackage(patch, assets)`、`applyThemePackageAssets(assets)`、`themePackageSource()`；渲染分支接 `ThemeManagePage`。
- `entry/src/main/ets/data/BackupRepository.ets`：`createBackup` 签名加 `paletteIndex`/`customTheme` 两参（现 8 参），未忽略 `themeConfig` 时写出 `themeConfig.json`；恢复侧遇 `themeConfig.json` 解析校验后落盘并 `upThemeConfig`。

**与上游的差异**

- 资产只认本地有对应功能的 7 类（上游 17 类，缺 10 个导航图标与封面图集——本地 `grep navIcon|coverAlbum` 全仓 0 命中），导入时计数提示「N 个本地不支持的资源已忽略」。
- B8「编辑已存主题」本地只改名、不改色位：上游 `EditThemeSheet.kt`（403 行）是完整编辑器，本地颜色位编辑已有一套 `pages/CustomThemePage.ets`，在主题包层再复制一份会让色位 UI 分叉。
- B4 不实现混淆版 v1 JSON（`parseObfuscatedThemeV1`）：本地从未发布过该格式，无历史数据。
- F5 只写 `MD3-Day`/`MD3-Night` 两条（上游 `configList` 是「内置 4 套 + 用户 `addConfig` 过的」，本地无 `addConfig` 入口）；内置 4 套保留在 `defaultThemeConfigs()` 供回落。
- 保存/重命名用页面底部固定输入面板，不是对话框：ArkUI 的 `showAlertDialog` 不能带输入框。

**验收（模拟器 127.0.0.1:5555，`assembleHap` 通过后 `hdc install -r`）**

| 项 | 操作 | 结果 |
| --- | --- | --- |
| A12 入口 | 外观页上滑 → 点「主题管理」 | 进入「主题包」页，五个入口与空态提示全部渲染 |
| B1 保存 | 点「保存当前设置」→ 面板预填「我的主题」→ 保存 | 列表出现该项；`files/saved_themes/theme_%E6%88%91%E7%9A%84%E4%B8%BB%E9%A2%98/manifest.json` + `assets/…` 落盘 |
| B2 导出当前主题 | 点「导出当前主题」→ 保存 | zip 内 `manifest.json 1861` / `assets/container/item/light.jpg 130586` / `assets/container/large/light.jpg 130586`，层级正确 |
| B3 导入主题包 | 导入 `appTheme='3'` 的包 | prefs `paletteIndex=3`、`themeMode=1`、`fontScale=10`，界面立刻换黑白浅色 |
| B4 导入旧版 JSON | 导入 `legacy-theme.json` | prefs `paletteIndex=2`、`themeMode=1`、`topBarButtonStyle=plain`，换柠檬配色 |
| B5 迁移旧版主题 | `saved_themes/` 有 `.json` 时入口出现 | 入口条件显示正确；本机 shell 对 `files/` 无写权限，未能构造 `.json` 做真机迁移 |
| B6 列表与搜索 | 存 2 套 → 搜索框输入「NewTheme 2」 | 列表从 2 项过滤到 1 项 |
| B7 应用 | 点「应用」→ 确认框 → 应用 | prefs `paletteIndex` 由 3 回到存盘时的 1、`themeMode` 回到 2 |
| B8 编辑改名 | 点「编辑」→ 改名 `NewTheme` → 保存 | 目录变 `theme_…%20NewTheme`、列表显示「我的主题 NewTheme」 |
| B9 导出已存主题 | 点「导出」 | 保存对话框预填「我的主题 NewTheme.zip」，zip 内 `manifest.json 1717`（该主题无资产） |
| B10 删除 | 点「删除」→ 确认框 → 删除 | `saved_themes/` 清空、页面回到空态提示 |
| F5 备份 | 备份到本地 → 解压 zip | 含 `themeConfig.json 304`，内容为 `MD3-Day`/`MD3-Night` 两条且颜色与当前配色一致 |
| F5 恢复 | 恢复该 zip → 预览底部「导入此 ZIP」 | `files/themeConfig.json` 落盘 304 字节；预览显示「themeConfig.json 2 条」 |

**踩坑**

- `zlib.compressFiles(files, zipPath, {})` 会把每个文件平铺到 zip 根，`assets/container/item/light.jpg` 与 `assets/container/large/light.jpg` 都变成 `light.jpg` 互相覆盖；改用 `zlib.compressFile(directory, zipPath, {})` 压整个目录才保留层级。
- 文件选择器给的 `file://` uri 不能直接喂 `fileIo.readTextSync`（只认沙箱路径，报 `No such file or directory`），必须先 `copyFileSync(fd, 临时路径)`。
- 便携配置里调色板字段叫 `appTheme`（对齐上游 `ThemeExportData.appTheme`），不是 `paletteIndex`；改错字段名时导入「看起来成功」但配色不动。
- `DocumentViewPicker` 目标文件已存在时提示重名且不会覆盖，必须先删旧文件。
- `hdc shell` 是 `uid=2000(shell)`，对 `files/`、`cache/`、`files/saved_themes/` 无写权限（只有 `preferences/` 可写，`run-as` 不存在），构造测试数据只能走应用自身入口或 `hdc file send` + 文件选择器。

**未验**

- B5 迁移旧版主题的真机执行（受上面 shell 权限限制，只验证了入口条件与代码路径）。
- 主题包跨设备导入（同一台设备上导出再导入已验）。

## 2026-11-01 N 端 r315 深色模式阶段二：自定义主题配色（A6）

**改动**

- 新建 `entry/src/main/ets/data/CustomThemeColors.ets`：`CustomThemeColorSet`（`primary`/`secondary`/`primaryText`/`secondaryText`/`background`/`labelContainer`，空串 = 未设置，对应上游 Int 0）、`CustomThemeSnapshot`（`enableDeepPersonalization`/`paletteStyle`/`customContrast`/`materialVersion`/`seedColorDay`/`seedColorNight`/`day`/`night`）、三张取值表 `CUSTOM_PALETTE_STYLES`（9 项）/`CUSTOM_CONTRASTS`（3 项）/`CUSTOM_MATERIAL_VERSIONS`（2 项）与中文标签、`SLOT_FALLBACK`（= 上游 `AppTheme.kt:110-121`）、`CUSTOM_OUTLINE = '#79747E'`；函数 `normalizeCustomColor`、`defaultCustomThemeSnapshot`、`normalizeCustomThemeSnapshot`、`resolveCustomColorSet`（夜间未设回落日间）、`hasCustomColor`、`buildCustomPaletteColors`（6 色位 → 本地 8 语义色位）、`resolveCustomPaletteColors`（种子色全空返回 `undefined`）。
- `entry/src/main/ets/data/ThemePalette.ets`：新增 `applyThemeColors(context, index, themeMode, customColors)`，有自定义色优先，否则回落 `resolvePaletteColors`。
- `entry/src/main/ets/data/ThemeSettingsRepository.ets`：`ThemeSnapshot` 加 `customTheme: CustomThemeSnapshot`（上游 16 个平铺键合成单键存 JSON）；`load`/`save` 各一处读写；新增导出 `parseCustomThemeSnapshot(raw)`。
- `entry/src/main/ets/pages/CustomThemePage.ets`（新建）：`CollapsingSettingsHeader` + 分组卡片；`@State editingSlot` 用 -1 / 0..5 / 6..11 / 12 / 13 区分关闭、日间六项、夜间六项、两个种子色；底部固定「选择颜色」面板（「重置」「保存」+ 48dp 预览块 + hex `TextInput` + 提示文案）。
- `entry/src/main/ets/pages/ThemeSettingsPage.ets`：`paletteIndex === 12` 时于「主题风格」之前插入「自定义颜色」行，摘要由 `customColorSummary()` 生成。
- `entry/src/main/ets/model/Book.ets`：`ProfileRoute` 加 `APP_CUSTOM_THEME = 'appCustomTheme'`。
- `entry/src/main/ets/pages/Index.ets`：`@State themeCustomColors`、`saveCustomTheme()`、`isProfileSettingsPage` 白名单、渲染分支，`applyThemeMode` 在 `normalizedIndex === 12` 时改走 `applyThemeColors`。

**与上游的差异**

- 上游 `ColorPickerSheet` 用 8×12 色环任意取色，本地 SDK 无 `ColorPicker` 组件（全仓与 SDK 检索均零命中），改成「hex 输入 + 48dp 预览块 + 重置 + 保存」，能力边界对齐上游的 `hexInput`/「重置」/「保存」三项。
- 上游种子色模式用 `CustomColorScheme` 做 HCT 生成整套 45 色位，ArkUI 无 HCT 生成器（`hct`、`materialkolor` 检索零命中），本地只把种子色落到 `primary`、其余 7 位用调色板表兜底。
- 上游 16 个平铺 prefs 键，本地合成单键 `customTheme` 存 JSON。

**验收**

| # | 操作 | 期望 | 结果 |
| --- | --- | --- | --- |
| 1 | 外观页 `paletteIndex=12` | 出现「自定义颜色」行 | 通过：`[112,1739][392,1805]`，摘要「用种子色生成整套配色」 |
| 2 | 进入自定义颜色页（种子色模式） | 渲染开关 + 日夜两个种子色 + 三个下拉 | 通过：「使用色板生成颜色」开关 on、「种子色（日间）」「种子色（夜间）」「色板风格=柔和」「对比度=默认」「Material 版本=Material 3 (2021)」 |
| 3 | 种子色（日间）输入 `#FF8800` 保存 | prefs 写入、行内显示 hex + 色块 | 通过：`seedColorDay:"#FF8800"`，行右侧 `#FF8800` + 橙色圆点 |
| 4 | 关闭「使用色板生成颜色」 | 深度个性化开，出现「白天」「夜间」各 6 项 | 通过：12 行全部渲染（主题色/次要主题色/主要字体色/次要字体色/背景色/标签容器色） |
| 5 | 白天·主题色设 `#FF8800` 保存 | 整 App 立刻换色 | 通过：`enableDeepPersonalization:true`、`day.primary:"#FF8800"`，底色 `(254,247,255)`、强调色 `(255,131,0)` |
| 6 | 夜间·主题色设 `#00FF88` 保存 | 暗色下强调色变绿 | 通过：`night.primary:"#00FF88"`，强调色 `(2,255,136)` |
| 7 | 白天·背景色设 `#FFCC00` 保存 | 整屏底色变黄 | 通过：`day.background:"#FFCC00"`，整屏底色 `(255,204,1)` |
| 8 | 杀进程重启 | 颜色保持 | 通过：重启后底色仍 `(255,204,1)` |
| 9 | `paletteIndex` 改 1 后重启 | 「自定义颜色」行消失、配色回草野 | 通过：行不再渲染，底色 `(17,19,14)` |

**踩坑**

- `bindMenu` 用参数化的 `@Builder Menu` 报 `Error Message: No overload matches this call. Argument of type 'MenuAttribute' is not assignable to parameter of type 'boolean'.`，改用 `bindMenu(MenuElement[], { placement: Placement.Bottom })` 后通过。
- `@Prop` 对象默认值不能调函数，只能内联字面量（`customTheme` 在 `ThemeSettingsPage` 与 `CustomThemePage` 两处都是内联默认对象）。
- `uitest uiInput inputText` 必须带坐标（`inputText <x> <y> <text>`），不带坐标报 `Missing parameter`。
- 改 prefs 里的数值键要按 `key="paletteIndex" value="1.000000"` 匹配，用 `name="..."` 匹配不到。

**未验**

- 只在亮色下逐项验证了六色与种子色；暗色下只验了「夜间·主题色」一项。
- 色板风格 / 对比度 / Material 版本三个下拉只验了默认值渲染，未逐个切换验证（ArkUI 无 HCT，切换对配色无可见影响）。

**复原**

- `paletteIndex` 已从 12 改回 1，`customTheme` 保留用户值（不影响非 12 号主题）。

## 2026-11-01 N 端 r314 深色模式阶段二：主题配色选择 14 套（A2）

**改动**

- 新建 `entry/src/main/ets/data/ThemePalette.ets`（261 行）：`ThemePaletteColors` 10 字段（8 个换肤色位 + 2 个只供色块预览的 `secondary`/`tertiary`）、`ThemePaletteDefinition`、`THEME_PALETTE_MIN = 0`/`THEME_PALETTE_MAX = 13`、`DEFAULT_LIGHT`/`DEFAULT_DARK`（= `resources/base|dark/element/color.json` 现值）、`THEME_PALETTES` 14 套（中文名对齐 `values-zh-rCN/arrays.xml:160-175`，色值由上游 12 个 `ui/theme/colorScheme/*ColorScheme.kt` 抽取 8 个语义位）、`normalizePaletteIndex`、`themePaletteName`、`resolvePaletteColors`、`publishPaletteColors`、`applyPalette`。
- `entry/src/main/ets/pages/Index.ets`：`applyThemeMode` 里 `ThemeModeResolver.apply(...)` 之后加 `applyPalette(context, normalizePaletteIndex(paletteIndex), themeMode)`（:2824）；`ThemeSettingsPage` 与 `OnboardingPage` 的调用各补一个 `readerNightMode: this.readerNightMode`。
- `entry/src/main/ets/pages/ThemeSettingsPage.ets`：`paletteColor`/`paletteArcColor`/`paletteCenterColor` 三个函数查 `THEME_PALETTES`；调色板行由 `Row(){ForEach([0..4])}` 改横向 `Scroll` + `ForEach(THEME_PALETTES)`；`ThemePaletteItem` 重写为上下两半圆 + 中心 `primary` 圆点 + 选中 34dp 圆与 ✓；顶部手机模型预览的两处取色改用 `themeColorAccent`。
- `entry/src/main/ets/pages/OnboardingPage.ets`：`paletteSurface`/`paletteCenter` 查表，`ForEach(THEME_PALETTES)` 渲染 14 项。
- `entry/src/main/ets/data/ThemeSettingsRepository.ets`：`paletteIndex` 读写两侧的 `Math.max(0, Math.min(4, ...))` 换成 `THEME_PALETTE_MIN/MAX`。
- 35 个页面/组件文件的 8 个 `theme_*` 颜色资源引用（1102 处 / 36 文件 / 155 struct）由 `$r('app.color.theme_*')` 改成 422 个 `@StorageProp('themeColor*')` 订阅 AppStorage 广播。

**与上游的差异**

- 动态取色（`appTheme == "0"`）在本平台无对应能力：SDK `sdk/default/openharmony/ets/api` 下 `dynamicColor|DynamicColor|Monet` 零命中，本地回落 `DEFAULT_LIGHT`/`DEFAULT_DARK`。
- 自定义配色（`appTheme == "12"`）同样回落默认，A6 另接。
- 上游 `ThemeEngine.getColorScheme` 走 Compose CompositionLocal 重建整套 `ColorScheme`；本地走「`Index.ets` 一个写入点 → AppStorage → 各 struct `@StorageProp` 订阅」，与 r308 `themeCardRadius`、r309 `themePureBlack`、r310 `themeAppBackground` 同一套机制。
- 上游每套 45 个 Material 色位，本地只落 8 个（其余色位全仓无引用）。

**验收**

| 项 | 操作 | 期望 | 实际 |
| --- | --- | --- | --- |
| 14 项齐全 | 外观页调色板行横向滑动，逐屏 `uitest dumpLayout` | 14 个中文名全部出现且顺序与上游一致 | 依次 dump 到「动态取色/草野/柠檬/黑白/电子书」→「黑白/电子书/晴空/八月/新浪潮」→「八月/新浪潮/春/千禧年/隐海修会」→「隐海修会/乐队/自定义/透明」 ✅ |
| 亮色 + 草野 | 点第 2 个色块 | 页面底色与强调色变草野 | `page bg (231,233,222)`、`accent (77,102,45)`；prefs `paletteIndex = 1` ✅ |
| 亮色 + 柠檬 | 点第 3 个色块 | 换成柠檬底色 | `page bg (238,232,218)`；prefs `paletteIndex = 2` ✅ |
| 暗色 + 草野 | 切深色 | 草野的 darkScheme 生效 | `page bg (42,43,37)`、`accent (177,210,141)` ✅ |
| 亮色 + 透明 | 滑到最后一格点选 | 底色纯白、强调色纯黑 | `page bg (255,255,255)`、`accent (0,0,0)`；prefs `paletteIndex = 13` ✅ |
| 暗色 + 透明 | 切深色 | 强调色反转为白 | `accent (255,255,255)`，与上游 `TransparentColorScheme` 的 `primary` 亮 `#000000` / 暗 `#FFFFFF` 一致 ✅ |
| 整屏换肤 | 点色块前后截图比对 | changed px 远大于色块本身面积 | `ImageChops` + numpy 阈值 10，changed px **798332** ✅ |
| 自定义项 | 点「自定义」 | 回落内置默认配色 | `paletteIndex = 12`，页面回到默认色 ✅ |
| 重启保持 | 杀进程重进 | 仍停在草野 + 深色 | 书架页 `bg (17,19,14)`、外观页 `bg (42,43,37)`，prefs `paletteIndex = 1`/`themeMode = 2` ✅ |

**踩坑**

1. **AppStorage 广播键必须与 `@StorageProp` 键逐字一致**。第一版 `publishPaletteColors` 按上游字段名广播 `themeColorPrimary`/`themeColorOnSurface`/…，而 130 个 struct 的 `@StorageProp` 是按 8 个 `theme_*` 资源命名的（`themeColorTextPrimary` 等）——键名对不上，点色块 prefs 变了、界面完全不变（changed px 只有 51726，全是色块自己）。改成按资源映射（`primary`→`themeColorAccent`、`onSurface`→`themeColorTextPrimary`、`onSurfaceVariant`→`themeColorTextSecondary`、`outline`→`themeColorTextTertiary`、`surface`→`themeColorSurfacePrimary`、`surfaceContainerLow`→`themeColorSurfaceSecondary`、`surfaceContainer`→`themeColorSurfaceTertiary`、`surfaceContainerHigh`→`themeColorSurfaceElevated`）后同一动作 changed px 798332。
2. 生成脚本里 `SLOTS` 少了 `PREVIEW` 两项，`emit_colors` 漏出 `secondary`/`tertiary`，编译报 `Type '{...}' is missing the following properties from type 'ThemePaletteColors': secondary, tertiary`。
3. `uitest uiInput click` 要落在 56×56 色块圆内：点 `(448,2382)`（标题行）无效，点 `(448,2312)` 才命中。

**未验**

- 只逐套验了草野、柠檬、透明、自定义四套 + 默认（动态取色）；黑白/电子书/晴空/八月/新浪潮/春/千禧年/隐海修会/乐队 9 套只验了「色块在列表里」，没逐套截图比对底色。
- 未验墨水屏（`appTheme == "4"`）的隐藏逻辑——本地无 `showEInkTheme` 概念，见 F8。

## 2026-11-01 N 端 r313 深色模式阶段二：应用字体（A5）、切换图标改判不适用（A8）

**改动**

- 新建 `entry/src/main/ets/data/AppFontSettings.ets`：`APP_FONT_EXTENSIONS = ['.ttf', '.otf', '.ttc']`、`APP_FONT_FAMILY = 'LegadoAppFont'`、`normalizeAppFontPath()`（非三个扩展名之一返回空串）、`appFontDisplayName()`。
- `entry/src/main/ets/data/ThemeSettingsRepository.ets`：`ThemeSnapshot` 53 → **54 字段**，新增 `appFontPath: string`；`load()` 的 defaults/读取/归一与 `save()` 的 `store.put` 各补一处。
- `entry/src/main/ets/pages/Index.ets`：`@State themeAppFontPath`；`restoreOnboarding()` / `resetThemeDefaults()` / `saveThemeSettings()` 各补一处；新增 `pickThemeAppFont()`（`picker.DocumentViewPicker`，`fileSuffixFilters = ['字体|.ttf', '字体|.otf', '字体|.ttc']`，复制到 `${context.filesDir}/fonts/app_font_${Date.now()}${ext}` 并校验 `statSync(target).size > 0`）、`clearThemeAppFont()`、`pruneThemeAppFonts(directory, keep)`（只删 `app_font` 前缀）、`applyThemeAppFont()`（`this.getUIContext().getFont().registerFont({ familyName: APP_FONT_FAMILY, familySrc: 'file://' + path })` + `context.getApplicationContext().setFont(APP_FONT_FAMILY)`，路径为空时 `setFont('')`）；`applyThemeFontScale()` 末尾串一次 `applyThemeAppFont()`，使启动与改字号时都重建字体。
- `entry/src/main/ets/pages/ThemeSettingsPage.ets`：「字体设置」由 `onUnavailableAction` 改为可展开组——行摘要 `appFontSummary()`（未选显示「系统默认字体」，已选显示文件名），展开后「选择字体文件」（detail「支持 .ttf / .otf / .ttc」）与「恢复系统字体」（detail「清除已选择的应用字体」）。
- 文档：`docs/parity/ZIP-THEME.md` 的 A5 转 `已接`、A8 改判 `不适用` 并补检索证据；`docs/KNOWN-ISSUES.md` 的 KI-TH-A4 与「排期分布」同步；`docs/parity/STATUS.md` 的 `themeConfig` 行改 48 已接 / 22 未接 / 2 不适用。

**与上游的差异**

1. 上游 `FontSelectSheet`（`ThemeConfigScreen.kt:948`）列出私有目录里已导入的多个字体供二次选择；本地每次只能重新选文件——`DocumentViewPicker` 无法回读 `filesDir` 生成可点列表。已记入对照表 A5 差异说明。
2. 上游靠 `base/AppContextWrapper.kt` 改写 `Configuration` 换字体；本地走 `UIContext.getFont().registerFont` + `ApplicationContext.setFont`（`ApplicationContext.d.ts:481`，要求窗口已创建且 `loadContent` 之后调）。
3. 复制与清理逻辑逐条对齐：`ThemeConfigViewModel.kt:555` 的 `substringAfterLast('.', "ttf")` 对应 `APP_FONT_EXTENSIONS` 校验，`:582` 的 `pruneCopiedFonts(keep = target)` 对应 `pruneThemeAppFonts`，`:589` 的 `clearAppFont()` 清路径后一并 prune 也照做。
4. A8 切换图标判「不适用」：Android 靠预置 `<activity-alias>` + `PackageManager.setComponentEnabledSetting`；HarmonyOS NEXT 的 `module.json5` 只允许一个 `abilities` 图标，SDK 里 `setAppIcon`/`changeAppIcon`/`updateAppIcon` 在 `sdk/default/openharmony/ets/api` 下零命中，`@ohos.bundle.launcherBundleManager.d.ts` 只有只读的 `getLauncherAbilityInfoSync`，`@ohos.enterprise.applicationManager.d.ts` 只有需企业 MDM `admin: Want` 的 `addHideLauncherIcon`/`removeHideLauncherIcon`。

**验收**（模拟器 `127.0.0.1:5555`，API 26，包 `io.legado.harmony`，测试字体 `C:\Windows\Fonts\Candara.ttf` 经 `hdc file send` 放到 `/storage/media/100/local/files/Docs/Documents/font-test.ttf`）

| 项 | 操作 | 期望 | 结果 |
| --- | --- | --- | --- |
| A5 选择字体 | 外观页上滑 1 次 → 点「字体设置」`(400,1560)` 展开 → 点「选择字体文件」`(400,1770)` → 浏览 `(783,290)` → 我的手机 `(640,897)` → Documents `(244,1052)` → `font-test.ttf` `(244,1250)` | 行摘要变文件名；prefs 写入；字体文件被复制 | 通过：摘要变 `app_font_1793536581141.ttf`；prefs `appFontPath` = `/data/storage/el2/base/haps/entry/files/fonts/app_font_1793536581141.ttf`；`files/fonts/` 下 242012 字节 |
| A5 旧副本清理 | 选第二次字体（`app_font_1793536505517.ttf`）后查目录 | 只剩最新一个 | 通过：目录里只有 `app_font_1793536505517.ttf` |
| A5 字体生效 | 同一页面开字体 / 关字体各截一张（重启使 `setFont` 重新执行） | 字形不同 | 通过：`ImageChops` bbox `(56,1583,1224,2657)`、changed **300873** |
| A5 恢复系统字体 | 点「恢复系统字体」`(400,1985)` | prefs 置空、字体副本被删、字形回落 | 通过：`appFontPath` 变空串、`files/fonts/` 目录清空 |
| A5 重启保持 | 杀进程重启 | 字体仍生效 | 通过：重启后 `files/fonts/` 仍有当前副本、prefs 仍有路径、渲染仍为自定义字形 |
| A8 入口保留 | 点「切换图标」`(400,2440)` | 提示未迁移，不崩溃 | 通过：`onUnavailableAction('启动图标设置尚未迁移')` |

**踩坑**

1. 首次实现 `clearThemeAppFont()` 只清 prefs 不删文件，与上游 `:589` 的 `pruneCopiedFonts()` 不一致——补 `this.pruneThemeAppFonts(\`${context.filesDir}/fonts\`, '')` 后才对齐。
2. 文件选择器进入后默认停在「最近」，且该 tab 下**不显示** `hdc file send` 放进去的文件（显示「没有文件」），必须切「浏览」→「我的手机」→「Documents」才看得到。
3. `applyThemeAppFont()` 必须挂在 `applyThemeFontScale()` 之后串行调用——`registerFont` + `setFont` 要求窗口已创建且页面已 `loadContent`，启动时只能排在那之后。

**复原**

点「恢复系统字体」，或 `hdc shell` 把 prefs `legado_theme` 里的 `appFontPath` 置空后重启；`files/fonts/` 下的 `app_font*` 副本可一并删除。

**未验项**

1. `.otf` / `.ttc` 两种扩展名未实测（只验了 `.ttf`）。
2. 中文字形未验——Candara 无中文字形，中文回落系统字体，只在英文字符上比对到差异。
3. A8 无验收（平台无该能力）。

## 2026-11-01 N 端 r312 深色模式阶段二：顶栏与底栏、控件模糊、渐变模糊（A17/A30/A31）

本轮把 [深色模式对照表](parity/ZIP-THEME.md) 的 A17（顶栏与底栏 13 个键）、A30（启用控件模糊）、A31（启用渐变模糊）三行从 `未接` 转为 `已接`。

**改了什么**

1. 新建 `entry/src/main/ets/data/TopBottomBarSettings.ets`：`TOP_BAR_BUTTON_STYLES` 五档（`plain`/`tonal`/`outlined`/`glass`/`liquid`）与 `topBarButtonStyleLabel`（普通/填充/描边/半透明/液态玻璃，逐条对齐上游 `values-zh-rCN/arrays.xml:226-232`）；`TopBottomBarSnapshot` 15 字段；7 个 `normalize*`；`resolveBarBackgroundColor` 按上游 `GlassDefaults.glassColor()` + `AppNavigationBar.kt:60` 合成（未开模糊用底色，开了先把底色压到 `blurAlpha` 再乘 `opacity`，结果 `>= 0.999` 时返回空串以保持组件资源色）；`resolveTopBarBackground` / `resolveBottomBarBackground` / `resolveBottomBarCornerRadius`。
2. `entry/src/main/ets/data/ThemeSettingsRepository.ets`：`ThemeSnapshot` 从 38 扩到 **53 字段**（+15），`load()` / `save()` 逐键同步。
3. `entry/src/main/ets/pages/Index.ets`：新增 15 个 `@State`、`topBottomBarSnapshot()`、`publishTopBottomBarStyle()`（广播 `themeTopBarBackground`/`themeBottomBarBackground`/`themeTopBarBlurRadius`/`themeBottomBarBlurRadius`/`themeBottomBarRadius`）与 15 个 `selectTheme*` 回调；底栏渲染改成 `if (this.themeShowBottomView && ...)`，按 `useFloatingBottomBar` 改宽度与圆角，按合成色设底色，按 `enableBlur` 挂 `backdropBlur`。
4. `entry/src/main/ets/pages/ThemeSettingsPage.ets`：「模糊效果」两项改真回调；「顶栏与底栏」由 `ThemeSettingsOption` 改为可展开组，13 项全部接上（使用折叠应用栏 / 顶栏按钮样式 / 合并顶栏按钮 / 显示导航栏 / 悬浮底栏 / 液态玻璃 / 底栏模糊强度 / 顶栏与底栏模糊半径 / 顶栏与底栏模糊透明度 / 顶栏与底栏不透明度），并按 `enableBlur` 与 `useFloatingBottomBar` 决定显示哪几项。
5. 顶栏底色消费端：`entry/src/main/ets/components/CollapsingSettingsHeader.ets`（12 个设置子页）+ `HomePage.ets`/`SearchPage.ets`/`ThemeSettingsPage.ets` 三处内联 header，各加两个 `@StorageProp` 与 `.backgroundColor(...)` + `.backdropBlur(...)`。

**与上游的差异**（已写进对照表 A17/A30/A31 三行）

1. 上游 `hazeSource`/`hazeEffect` 是跨组件采样（顶栏采样下方滚动内容做毛玻璃），ArkUI `backdropBlur` 只采样组件自身背后的内容——语义近似而非等价。上游 `enableBlur` 影响 6 处（含内容卡片），本地只作用于顶栏与底栏。
2. A31 的 `HazeProgressive.verticalGradient(1f, 0f)` 在 ArkUI 无等价物（`backdropBlur` 不支持渐变梯度），本地只落盘并参与摘要文案，**不产生可见渐变**。
3. `useFlexibleTopAppBar` 只落盘不改折叠行为（本地顶栏本就是固定高度 + `collapsedHeader` 折叠）；`topBarButtonStyle` 五种样式只落盘不改按钮外观。
4. 上游是独立 sheet，本地用可展开组承接。

**验收**（模拟器 127.0.0.1:5555 / API 26 / 包 `io.legado.harmony`；构建 `BUILD SUCCESSFUL in 40 s 836 ms` / `36 s 858 ms` / `38 s 448 ms`）

| # | 设备操作 | 预期 | 实际 |
| --- | --- | --- | --- |
| 1 | 外观 → 主界面组 →「顶栏与底栏」→ 关「显示导航栏」→ 重启 | 底栏消失 | 通过：`(640,2700)` 由 `(255,255,255)` 变 `(245,246,248)`（页面底色） |
| 2 | 「顶栏按钮样式」→ 选「液态玻璃」 | prefs `topBarButtonStyle=liquid` | 通过：菜单五项文案为普通/填充/描边/半透明/液态玻璃，选中后 prefs 变 `liquid` |
| 3 | 开「悬浮底栏」 | 底栏变胶囊 | 通过：`.pwork/float.jpeg` 底栏左右留出页面底色（`x=10`/`x=1270`），`x=60`/`x=1220` 为卡片描边 |
| 4 | prefs `bottomBarOpacity=40` → 重启 | 底栏底色变淡 | 通过：`(255,255,255)`→`(249,250,252)` |
| 5 | prefs `topBarOpacity=40` → 重启 → 进外观页 | 顶栏底色变淡 | 通过：顶栏像素 `(16,15,13)`→`(107,107,107)`，`ImageChops` bbox `(0,56,1280,616)`、changed 616208 |
| 6 | 拖「顶栏模糊半径」滑块 | prefs `topBarBlurRadius` 变化 | 通过：`24.000000`→`7.000000`（`uitest uiInput swipe 200 2334 400 2334 800`） |
| 7 | 开「启用控件模糊」 | prefs `enableBlur=true`、出现「启用渐变模糊」行 | 通过：prefs 变 `true`，顶栏组摘要变「模糊 24/8」 |
| 8 | 开/关「启用控件模糊」对比截图 | 顶栏与底栏出现毛玻璃 | 通过：`ImageChops` bbox `(0,2511,1280,2832)`、changed 395714（变化集中在底栏） |
| 9 | 开「启用渐变模糊」 | prefs `enableProgressiveBlur=true` | 通过：prefs 变 `true` |

**踩坑**

1. `ThemeSettingsPage.ets` 的头部是**页面内联写的**（不是 `CollapsingSettingsHeader` 组件），第一版漏改，导致 `topBarOpacity` 改了但截图 `ImageChops` changed 为 0。补三处内联 header（`HomePage`/`SearchPage`/`ThemeSettingsPage`）后才生效——**改广播式主题键时，要先把所有消费点找全，组件与内联两套都要覆盖**。
2. `uitest uiInput swipe` 拖 Slider 必须从轨道内起手且距离适中：`swipe 120 y 1100 y 700` 无效，`swipe 200 y 400 y 800` 才落到滑块上。
3. `uitest uiInput click` 落在 Toggle 上偶发第一次无效（r308 的「关闭设置分组圆角」也是第二次才生效），一律以 prefs 变值为准。

**复原**：`topBarOpacity`/`bottomBarOpacity` 回 `100.000000`、`topBarBlurRadius` 回 `24.000000`、`bottomBarBlurRadius` 回 `8.000000`、`topBarButtonStyle` 回 `tonal`、`showBottomView`/`useFloatingBottomBar` 回 `true`/`false`、`backgroundImage` 清空、`fontScale` 回 `10.000000`、`enableProgressiveBlur` 回 `false`。

**未验**：液态玻璃效果（`useFloatingBottomBarLiquidGlass`）与底栏模糊强度滑块只确认落盘，未做像素级比对；顶栏按钮五档样式的外观差异未验（本地未实现样式渲染）。

## 2026-11-01 N 端 r311 深色模式阶段二：首页与导航、预见性返回、共享元素动画（A9/A10/A14）

- 设备：HarmonyOS 模拟器 `127.0.0.1:5555`（API 26），包 `io.legado.harmony`。
- 构建：`assembleHap` 两次 `BUILD SUCCESSFUL`（`2 s 62 ms` / `35 s 5 ms`），均 `hdc install -r` 覆盖安装成功。

**改了什么**

- 新建 `entry/src/main/ets/data/MainNavigationSettings.ets`：`MAIN_NAVIGATION_ROUTES`、`mainNavigationLabel()`、`orderedMainNavigation()`（对齐上游 `MainDestination.ordered` 的「过滤未知与重复 → 补齐未出现项」）、`moveNavigationUp()`/`moveNavigationDown()`、`normalizeDefaultHomePage()`（不可见回落 `bookshelf`）、`isMainDestinationVisible()`/`visibleMainNavigation()`、`LABEL_VISIBILITY_VALUES` 与 `labelVisibilityLabel()`。
- `entry/src/main/ets/data/ThemeSettingsRepository.ets`：`ThemeSnapshot` 由 30 字段扩到 **38 字段**，新增 `showHome`/`showDiscovery`/`showRss`/`defaultHomePage`/`mainNavigationOrder`/`labelVisibilityMode`/`predictiveBack`/`readerSharedElement`；`load()`/`save()` 逐键读写。
- `entry/src/main/ets/pages/Index.ets`：8 个 `@State`；底栏由 5 个硬编码 `TabItem` 改为 `ForEach(this.visibleNavigationRoutes())`（`TabItem` 新增 `@Prop showLabel`）；新增 `applyDefaultHomePage()`、`selectThemeNavigationVisibility()`、`moveThemeNavigationUp/Down()`、`selectThemeDefaultHomePage()`、`selectThemeLabelVisibilityMode()`、`selectThemePredictiveBack()`、`selectThemeReaderSharedElement()`、`readerRouteTransition()`；阅读页整块收尾追加 `.transition(this.readerRouteTransition())`。
- `entry/src/main/ets/pages/ThemeSettingsPage.ets`：A9/A10 两个 `ThemeSwitchRow` 改真回调；「首页与导航」由 `ThemeSettingsOption` 改为可展开组（三枚显隐开关 + 默认主页面下拉 + 导航标签显示下拉 + 逐项上下移按钮）；`ThemeSettingsDropdown` 新增 `labelBuilder` 回调以便同一组件既显示封面背景三档文案又显示导航项名称。

**与上游的三处差异**

1. **A9 平台缺项**：SDK 里 `grep -rln "predictiveBack" --include=*.d.ts` 零命中，上游 `BaseActivity.kt:111` 的 `registerOnBackInvokedCallback` 在本平台没有等价物，所以只落盘、不伪造预览动画。
2. **A10 用近似**：ArkUI 的 `geometryTransition` 要求源与目标组件同时在场，本地阅读页是整页 `if/else` 切换，做不到上游 Compose `SharedTransitionLayout` 的书封展开；关闭时只做 220ms 淡入淡出，打开时叠 0.92 倍缩放。
3. **A14 用按钮代替拖拽**：上游 `MainNavigationSettingsSheet` 用可拖列表（`rememberReorderableLazyListState`）改顺序，本地用「上移/下移」两枚按钮承接同一个 `onSetOrder` 语义；上游的「导航栏图标」子 sheet（`NavIconManageSheet`，10 个自定义图标键）未做。

**验收**

| 项 | 操作 | 预期 | 实际 |
| --- | --- | --- | --- |
| A14 显隐 | 外观 → 上滑 2 次 → 点「首页与导航」行展开 → 关「首页」→ 重启 | 底栏由 5 项变 4 项，「首页」消失 | 通过；prefs `showHome` = `false`；截图 `nav1.jpeg` vs `nav2.jpeg` changed pixels **25092**、bbox `(63,0,1184,105)` |
| A14 顺序 | `mainNavigationOrder` 改 `my,home,bookshelf,explore,rss` → 重启 | 底栏首项变「我的」 | 通过；底栏截图首项是「我的」、当前选中「书架」 |
| A14 默认主页面 | `defaultHomePage` 改 `explore` → 重启 | 冷启动直接停在发现页 | 通过；dumpLayout 读到「发现 | 当前没有发现源！」 |
| A14 回落 | `showDiscovery=false` + `defaultHomePage=explore` → 重启 | 自动回落书架（对齐上游 `MainNavigationSettingsSheet.kt:81-84`） | 通过；dumpLayout 读到书架列表 `np-test` 等 |
| A9 | 外观 → 点「预见性返回手势」 | prefs 变 `false`，重启保持；无预览动画 | 通过；`<bool key="predictiveBack" value="false"/>` |
| A10 | 外观 → 点「阅读界面共享元素动画」 | prefs 变 `false`，重启保持；打开时进阅读页有缩放淡入 | 通过；`<bool key="readerSharedElement" value="false"/>` |

**复原**：`showHome`/`showDiscovery`/`showRss` 回 `true`、`defaultHomePage` 回 `bookshelf`、`mainNavigationOrder` 回 `home,bookshelf,explore,rss,my`、`predictiveBack`/`readerSharedElement` 回 `true`（已 grep 确认）。

**未验**：导航标签显示四档（`auto`/`selected`/`labeled`/`unlabeled`）只做了落盘与渲染分支，未逐档截图；A10 的缩放幅度（0.92）是目测选定，未与上游共享元素的曲线做像素级对比。

## 2026-11-01 N 端 r310 深色模式阶段二：全 App 背景图片（A13）

- 设备：HarmonyOS 模拟器 `127.0.0.1:5555`（API 26），包 `io.legado.harmony`。
- 构建：`assembleHap` 三次 `BUILD SUCCESSFUL`（`47 s 189 ms` / `46 s 708 ms`，第一次因 ArkTS 属性名冲突失败），均 `hdc install -r` 覆盖安装成功。
- 改动文件：`data/ThemeSettingsRepository.ets`（`ThemeSnapshot` 26 → **30 字段**，新增 `backgroundImage`/`backgroundImageNight`/`backgroundImageBlurring`/`backgroundImageNightBlurring` 与 `normalizeBackgroundBlur()`）、`pages/Index.ets`（4 个 `@State` + `pickThemeBackgroundImage()`/`selectThemeBackgroundBlur()`/`clearThemeBackgroundImage()`/`appBackgroundSource()`/`appBackgroundBlur()` + `publishThemeCardStyle()` 广播 `themeAppBackground` + 根 `Stack` 首子节点的背景 `Image` + 根 `Column` 让位）、`pages/ThemeSettingsPage.ets`（「背景图片」行改为可展开组，4 个 `@Prop` + 3 个回调）、以及 30 个页面/组件文件的 **59 个 struct** 加 `@StorageProp('themeAppBackground')` 并把 208 处页面底色包成「有背景图时 `Color.Transparent`」。

**关键实现选择**：上游 `ui/theme/AppBackground.kt:17-48` 把背景图放在 `Box` 的**第一个子节点**、内容层在其上，按 `hasBackgroundImage(darkTheme)` 选 `backgroundImageDark`/`backgroundImageLight` 与对应虚化度，`AsyncImage(...).fillMaxSize().blur(blur.dp)`、`ContentScale.Crop`。本地照此把 `Image` 放在根 `Stack` 首子节点。**但本地各页自己带不透明底色**（`theme_surface_primary`），会把背景图整块盖住——上游没有这个问题，因为它的页面底色来自 `SplicedColumnGroup`/`GlassCard` 的卡片层。所以本轮把 30 个文件的 208 处页面底色统一改成「有背景图时 `Color.Transparent`」，这是实现差异，不是行为差异。

**踩坑**：
1. `@Prop backgroundImage` 与 ArkUI `CustomComponent.backgroundImage` 方法同名，编译报 `Property 'backgroundImage' in type 'ThemeSettingsPage' is not assignable to the same property in base type 'CustomComponent'`（`ThemeSettingsPage.ets:118:9`）。四个 prop 全部改名为 `appBackgroundImage`/`appBackgroundImageNight`/`appBackgroundBlur`/`appBackgroundNightBlur` 才通过。**`@Prop` 命名要避开所有 `CustomComponent` 内置属性方法名。**
2. 选图后只 `saveThemeSettings()` 不广播，根背景层与页面底色不同步——必须同时 `publishThemeCardStyle()`。虚化与清空回调同理。
3. 只改各页面底色、漏了 `Index.ets` 根 `Column` 的 `theme_surface_primary`，背景图仍被根容器盖住（第一版实测整屏无变化）。补上根 `Column` 的条件透明后才可见。
4. 复制进沙箱时必须保留原扩展名（`.jpg`/`.png`），存成 `.img` 会让 `Image()` 解不出、背景图不显示（r308 容器背景图已踩过同一坑）。

**验收①日间背景图**：外观 → 上滑到「背景图片」→ 点行展开 → 点「日间背景图片」→ 系统文件选择器 `浏览` → `我的手机` → `Documents` → 点 `cover-test.jpg` 图标 → 返回，行摘要变「已选日间，点击展开」、子行变「已选择，点击换图」，prefs `backgroundImage` = `/data/storage/el2/base/haps/entry/files/theme-backgrounds/app-day-1793531889381.jpg`。重启后书架整屏显示该图；与清空状态对比 `ImageChops`：changed pixels **2259594**、bbox `(0,0,1280,2100)`、区域均值 `(219.1,219.0,221.6)` vs `(32.9,33.2,38.8)`。**通过。**

**验收②虚化**：拖日间虚化滑块到右端 → prefs `backgroundImageBlurring` 由 `0.000000` 变 `40.000000`；截图对比 changed pixels **704394**、区域标准差由 `(29.9,29.2,34.2)` 降到 `(25.1,24.1,29.6)`（图变糊）。**通过。**

**验收③移除**：点「移除背景图片」→ prefs `backgroundImage` 变空串、`backgroundImageNight` 仍空；重启后整屏回纯色底，与开图状态对比 changed pixels **864843**。**通过。**

**未验**：夜间背景图（需把 `themeMode` 切 `"2"` 后再选图；键与日间共用同一段代码，本轮只验证日间分支）；上游 `.9.png` 九宫格拉伸未做（本地按 `ImageFit.Cover` 平铺，已在对照表差异说明记录）。

**复原**：`backgroundImage` 清空、`backgroundImageBlurring` 回 `0.000000`、`themeMode` 保持 `"1"`、`pureBlack` 保持 `false`。

**本仓库提供开发预览源码，不代表稳定版、签名发行包或已完成 API 12 兼容验收。**
