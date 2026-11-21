# 已知问题与验收边界

更新：2026-11-17。以下仅列出公开源码和 E 端记录能够支持的状态，不包含测试书名、个人文件名、设备地址、日志或截图。

2026-11-17 自造与降级清算（11 批）已收口：门槛判据全绿（scripts/selfmade-scan.py 六词口径归零、tmp/batch11_gate.py 22 项全过），七表合计未变（1226 行 / 已接 1038 / 未接 157 / 不适用 31）。下文批 5/6/10 各节已按清算后的实际状态更新；本批新增的十类「不做」项集中登记在「## 批11：自造与降级清算——十类不做的项」。

## 批13：朗读三处平台做不到（KI-ALOUD-RATE / KI-ALOUD-VOICEFX / KI-ALOUD-CAPSULE 补充）

九批实现后对三处「上游有、平台做不到」集中登记，编号顺延当前最大号（批12），不复用。

1. **KI-ALOUD-RATE 系统朗读不支持调速**：SDK `TextToSpeechEngine` 只有 `setListener/speak/listVoices/stop/isBusy/shutdown`，无 `setSpeechRate/setPitch/setVolume`（`sdk/default/hms/ets/kits/@kit.CoreSpeechKit.d.ts`）。`ttsSpeechRate` 偏好字段与滑杆都保留，但系统朗读下不调 API、不变速；滑杆下方如实标注「系统朗读不支持调速，此设置用于 HTTP 朗读源」。只有 HTTP 源经 `AVPlayer.setSpeed`（10 档）真正变速。
2. **KI-ALOUD-VOICEFX 变声器不可实现**：上游变声器依赖 `android.media.audiofx.Equalizer` 等播放侧音频效果；鸿蒙 SDK `@ohos.multimedia.audio.d.ts` 仅有 loopback 的 `AudioLoopbackEqualizerPreset/AudioLoopbackReverbPreset`（通话/录音回环），无面向媒体播放的 Equalizer/混响/变调 API。入口保留，点开如实说明「平台不支持音频效果」，不做空页面。
3. **KI-ALOUD-CAPSULE 已并入批12**：朗读胶囊是应用内浮层、退出阅读器即消失（`SYSTEM_FLOAT_WINDOW` 为 `system_basic` 权限，三方拿不到），详见批12 条目，此处不重复编号。

## 批12：朗读胶囊是应用内浮层，不是系统悬浮窗（KI-ALOUD-CAPSULE）

上游朗读胶囊（`ui/book/read/ReadAloudCapsule.kt`，458 行）是系统悬浮窗（`SYSTEM_FLOAT_WINDOW`），画在 Nav3 叠层之上，退出阅读器仍能看到。鸿蒙三方应用拿不到该权限：SDK `PermissionDefinitions.json` 中 `SYSTEM_FLOAT_WINDOW` 的 `level=system_basic`（第 615 行），只向系统应用授权。故本地胶囊做在 `pages/ReaderPage.ets` 顶层 `Stack` 内，是应用内浮层：**退出阅读器即消失**，`onToggleReadAloud` 停止后也不显示。

胶囊结构照上游 `ReadAloudCapsule.kt:339-458` 实际实现，不是「进度环/播放暂停/展开按钮」：

- **封面圆图**（上游 `BookCoverImage`，`:369-399`）：折叠态唯一可见元素；播放时旋转（20 秒/圈，暂停即停）；点击 = 折叠/半展开态展开、完全展开态打开 player（上游 `onOpenPlayer`，`:310-313`）。
- **播放暂停按钮**（`:415-432`，`isPaused ? PlayArrow : Pause`）。
- **进度环内含停止按钮**（`:433-454`，`CircularProgressIndicator` + `Close` → `onStop`）。
- 底色日白夜黑、不跟随主题（上游 `capsuleSurfaceColor/capsuleContentColor:325-337`）。
- 展开是封面宽度连续变化（tween 320ms，`:175-179`），揭示两个按钮；**不是**「打开朗读面板」。

能力边界与降级项（如实记录，非「胶囊已完全实现」）：

1. **展开态点封面 → 打开听书界面（player）**：已按上游 onOpenPlayer 语义实现，打开 `pages/ReadAloudPlayerPage.ets`（全屏浮层，见下节「听书界面」）。上游是 Activity 级 morph 浮层、不在导航栈；本地用 Index 根 `Stack` 的全屏浮层近似——退出阅读器后同样消失。
2. 显隐开关 `showReadAloudCapsule`、自动收起 `capsuleAutoCollapse`（3 秒无操作折叠、任何触摸重置、拖边缘折叠）、位置可拖与钳位、位置复位（设置面板「复位朗读胶囊位置」对应 `ReadAloudConfigContent.kt:243`）均保留；位置存 `read_aloud_capsule_offset_x/y` 偏好，杀进程重开仍在。
3. 位置语义已按上游 `CapsulePosition.kt` 实现为「相对屏幕底部中央的中心偏移」，贴边（±edge）保存、重开即折叠、展开让位防出屏均已还原；差异仅在于本地钳位在应用视口内（无系统悬浮窗的跨应用边界）。
4. 外观定制页（`CastCapsuleStyleScreen.kt`，774 行）本批不做，`AppReadAloudSettingsPage.ets` 的「朗读胶囊设置」行继续留占位。

## 听书界面（player，`pages/ReadAloudPlayerPage.ets`）

对照上游 `ui/book/readaloud/player/ReadAloudPlayerScreen.kt`（773 行）+ Contract 实现，全屏浮层，三页 Swiper（目录 / 封面 / 正文）+ 顶栏（书名/章名/设置）+ 底栏。

能真实现并已接 `SystemTtsPlayer` 单例的控件：上一句 / 下一句（`previous`/`next`）、上一章 / 下一章（复用换章链）、播放暂停、进度条与正文点选 seek（`seekTo`）、目录选章、切换经典（回朗读面板）、正文逐句跟随高亮（读 `onTextChange`），当前句/下一句取 `unitText`。背景模式四档对齐上游 `ReadAloudBgMode`（`PreferKey.kt:509-514`）：纯色 / 封面模糊 / 流动光 / 透明，由 `readAloudPlayerBgMode` 偏好持久化，设置面板与 player 双向同步。其中流动光档用封面模糊 + 静态渐变呈现——上游的 `BgEffectBackground` 流动着色器是 Compose 专属，鸿蒙 SDK 无对应能力，动态流动这一视觉细节做不到。

平台边界（如实记录）：

- **音色**：系统 TTS 实测仅 3 条（聆小珊 person13 / 凌飞哲 person21 / 英语 person8）；选音色会重建引擎并从当前句续播。上游音色目录还含 HTTP 朗读源音色，本批无 HTTP 源，故只列系统 3 条。
- **语速**：系统 TTS 无 `setSpeechRate`，滑杆只写 `ttsSpeechRate` 偏好、不调 API，界面如实标注「系统朗读不支持调速，此设置用于 HTTP 朗读源」。
- **定时**：分钟档到点立刻停（对齐上游 `finishCurrentChapterAfterTimer=false`），章节档按已读章数累计；复用批5 `onAloudTimerChange`。
- 上游 `PlayerBackground` 的 haze 流动光背景、morph 形变动画、3 个 bottom sheet 的花字动画是 Compose 专属效果，本地以静态背景/普通浮层近似。

## 批11：自造与降级清算——十类「不做」项集中登记

本轮清算逐条比对上游，以下十项判「不做」，证据按任务书 11.3 三类之一给出（平台无对应物 / 范围之外 / 备份互通但无界面）。不改变功能级对照表判定，故七表合计未变。

1. **主题风格（composeEngine / Miuix）**：鸿蒙 `ets/api/` 无 Miuix 或等价第二套组件库；上游 `ThemeResolver.isMiuixEngine` 依赖 Android 侧 `top.yukonga.miuix.kmp`。平台无对应物，批 6 已整行删（见批 6 节 KI-THEME1）。
2. **Cronet 网络栈**：Chromium `org.chromium.net` native 库，鸿蒙 SDK 无对应物；批 7 已整行删（见 KI-DOWN1）。
3. **匿名统计 Firebase**：鸿蒙 SDK 无 Firebase / HiAnalytics / AGC；批 5 已整行删（见 KI-PRIV2）。
4. **生物识别 UnsupportedSystem 档**：上游 `PrivateBiometricStatus` 五态含 UnsupportedSystem（Android 侧系统不支持），鸿蒙基线 6.0.0(20) 无此限制、该档不可达；本地 `data/PrivateAccessRepository.ets` 的 `enum PrivateBiometricStatus` 为五态 `NOT_SET_PASSWORD / AVAILABLE / NOT_ENROLLED / NO_HARDWARE / UNAVAILABLE`，无 UnsupportedSystem。
5. **导航布局（tabletInterface）/ 多栏布局（multiPaneMode）**：`docs/PROJECT.md:46-48` 明确列为「额外设备形态适配」范围之外；批 6 已整行删（见批 6 节）。
6. **整本正文内存缓存上限**：上游无此字段，本地 `data/BookRepository.ets` 架构差异引入，`pages/AppDownloadCacheSettingsPage.ets` 保留该行并加代码注释写明；属「上游没有但本地有架构理由」，保留，另见 `docs/CODE-CONVENTIONS.md:284`。
7. **朗读界面形态（整页播放器）**：判「不做」时的依据是当时零 TTS 引擎（`@kit.CoreSpeechKit` 未接），扩成整页只会是空壳。此后批 3 已接系统 TTS、批 5 已做朗读面板，现新增 `pages/ReadAloudPlayerPage.ets` 听书界面（真实控件已接单例播放器，见上节「听书界面」）。本条历史判定保留作记录，当前状态以上节为准。
8. **书籍导出入口（详情页溢出菜单）**：上游导出在书架管理页（`BookshelfManageScreen.kt:186-338` 的 `ExportBookService` 流程），不在详情页；本地 `data/EpubExporter.ets` 写出能力保留，入口待建（见 KI-EPUB1）。
9. **翻译页只读**：翻译属在线服务且上游默认走 Google 翻译接口，本页两个 `TranslationSettingsChoice`（提供商 / 目标语言）设 `disabled`，落盘实现等判断段定范围；属范围之外。
10. **实验室页 `eyeProtection` 行**：上游 `LabSettings` 有该字段，本地 `data/LabSettingsRepository.ets` 有 `eyeProtection` 字段但 `pages/AppLabSettingsPage.ets` 无对应界面行（只有「启用实验室 / 墨水屏显示」两行）；补行要接护眼渲染链，属另一个域，本批不补。

## 批10：朗读界面形态差异（KI-ALOUD1，等朗读功能实现时一并做）

**KI-ALOUD1 朗读页仍是底部浮层，不是上游整页播放器** —— 上游 `ui/book/readaloud/player/ReadAloudPlayerScreen.kt`（773 行）是整页播放器，前提是「正在朗读」：运输条、逐句高亮、说话人/引擎行、定时进度。本地零 TTS 引擎（`@kit.CoreSpeechKit` 未接）、零音频播放层（`data/HttpTtsRepository.ets` / `data/ReadAloudVoiceRepository.ets` 仅备份互通用，网络层与播放层未接），把 262 行浮层扩成整页只会得到「点了没声音」的空壳，比现在的浮层更不诚实。故批10 只改文案与配色、形态保持底浮层（`pages/ReaderAloudSettingsPage.ets`）：标题「朗读设置」→「朗读」、「朗读语速」→「调整语速」、删无上游依据的「跟随系统」档、六处硬编码色换主题 token。形态变更留到朗读功能实现那一批，届时一并做运输条 + 逐句高亮 + 整页播放器。这是明确待办，属「已纳入范围、尚未排期」，不是「不适用」。

## 批5：隐私页两行按「平台无此能力」删除（KI-PRIV1、KI-PRIV2）

**KI-PRIV1 后台运行权限（电池优化白名单）整项删** —— 上游 `ui/config/privateConfig/PrivateConfigScreen.kt` 的 `background_permission` 是查电池优化白名单状态（`BatteryOptimizationUtils.isIgnoringBatteryOptimizations`）并跳厂商设置页。鸿蒙无等价 API：`D:\Program Files\Huawei\DevEco Studio\sdk\default\openharmony\ets\api\` 下 `@ohos.settings.d.ts` 的全部开页函数（`:1271`-`:1410`）无任何 startup/background/battery/白名单项；`ohos.settings.*` action 字面量仅 `ohos.settings.wireless` / `ohos.settings.manage.applications` / `ohos.settings.application.details` 三条（均在已 `@deprecated since 9` 的旧 `wantConstant` 模块）；`backgroundTaskManager`（长时任务）、`deviceStandby`（空命名空间）、`backgroundProcessManager`（进程优先级）三者都不是「本应用是否在白名单」的查询。最接近的 `settings.openAppDetailSettingsPage`（`@ohos.settings.d.ts:1383`，@since 26）只到「应用详情」通用页而非启动管理专项页，且状态判断做不了。按任务书 5.5「查不到就整项删、不许保留点了弹『尚未接入』的项」，`pages/AppPrivacySettingsPage.ets` 的该行已删。

**KI-PRIV2 匿名统计（Firebase）整项删** —— 上游 `firebase_enable_title` = 匿名统计，控制 `utils/FirebaseManager.kt`。鸿蒙无 Firebase / HiAnalytics / AGC SDK：`$DEVECO_SDK/ets/api/` 下 `firebase` 与 `analytics` 零命中。按「上游没有的不要自己加」的反向判据（平台无此能力，属合法「不适用」），`pages/AppPrivacySettingsPage.ets` 的该行已删；**不**改成「匿名统计」假开关（任务书 5.6 明令禁止）。

> 上两行属四类合法「不适用」里的第二类（平台无此能力），不是功能缺失，不排期补。

## 批6：外观页三行按「不适用 / 范围之外」删除、切换图标未做（KI-THEME1）

**KI-THEME1 主题风格（composeEngine）整项删** —— 上游 `compose_engine` = 主题风格是个 `DropdownListSettingItem`，两个选项 `Material Design` / `Miuix`；`ThemeResolver.isMiuixEngine` 被九个界面据此分叉，Miuix 是 Android 侧第三方组件库（`top.yukonga.miuix.kmp`）。鸿蒙 `D:\Program Files\Huawei\DevEco Studio\sdk\default\openharmony\ets\api\` 无任何 Miuix 或等价的第二套组件库，选项只能剩一个，单选项下拉=假控件。按任务书 6.2c「平台无此能力」整行删（原行 `title: '主题风格', detail: 'Material Design'` + `onUnavailableAction`），不改成假下拉、不保留「尚未接入」。

**导航布局（tabletInterface）与多窗布局（multiPaneMode）整行删** —— 上游 `ThemeConfigScreen.kt:379-397` 两项都是 `DropdownListSettingItem`（切平板界面 / 切多栏），属 `docs/PROJECT.md:46-48` 明确列出的「额外设备形态适配」范围之外。按任务书 6.2b 三类证据里的「范围之外」整行删，不保留禁用态（禁用下拉=点了没反应）。本地原名「多窗布局」与上游 `multi_pane_layout`=多栏布局的文案差异随整行删除一并消失。这两项属「不适用」而非缺陷，不登记为待修。

**切换图标（启动图标）本批未做** —— `pages/ThemeSettingsPage.ets` 该行仍是 `onUnavailableAction('启动图标设置尚未迁移')`，全页唯一保留的占位。上游是 `ShowSheet(LauncherIcon)`；鸿蒙换应用图标要预置多套 `layered_image` 并改 `module.json5` 的 `icon`，能做但工作量大，任务书 6.5 判本批不动、登记在案。这是待办不是「不适用」，后续要做时按此条定位。批 11 收口复查：`onUnavailableAction` 全页仅此一处调用，保持登记。

> 上述「主题风格 / 导航布局 / 多窗布局」三条属合法「不适用」（平台无能力 / 范围之外），不排期；「切换图标」是明确待办。

## 批7：下载缓存页 Cronet 整项删（KI-DOWN1）

**KI-DOWN1 Cronet 开关整项删** —— 上游 `pref_cronet_summary` = 使用 Cronet 网络组件，控制是否用 Chromium 的 Cronet 网络栈。Cronet 是 Android 侧 `org.chromium.net` 的 native 库，鸿蒙 SDK（`D:\Program Files\Huawei\DevEco Studio\sdk\default\openharmony\ets\api\`）无任何 Cronet 或等价网络栈开关，开关拨动不会产生任何行为差异，按任务书 7.3「整行删、登记平台无此能力」处置：`pages/AppDownloadCacheSettingsPage.ets` 该行已删，不改假开关、不保留「尚未接入」。属合法「不适用」，不排期。

> 同批封面缓存按路线①真算（本地封面落盘在 `${filesDir}/covers`，遍历目录累加 `statSync.size` 得 MB），不是假数字；漫画缓存因本地无漫画形态整行删。

## 批8：详情页溢出菜单删自造「导出为 EPUB」入口（能力保留，入口待建）

**KI-EPUB1 导出入口从详情页溢出菜单移除** —— 上游 `BookInfoScreen.kt:1033-1142` 的 `BookInfoOverflowMenu` 没有「导出为 EPUB」项；上游的书籍导出在书架管理页（`ui/book/manage/BookshelfManageScreen.kt:81` 引入 `ExportBookService`，`:1147` 有 `parallelExportBook` 配置，`:186-338` 是整套导出流程）。本地 `pages/BookInfoPage.ets` 的 `export_epub` 是实现方自造的溢出菜单入口，按「上游没有的不要自己加」从 `overflowItems()` 删除（连同 `onExportEpub` 入参与 `pages/Index.ets` 的接线一并删）。**能力不删**：`data/EpubExporter.ets` 与 `pages/Index.ets` 的 `exportBookAsEpub()` 是上游书架管理页导出能力在本地的实现，保留；入口待建（应在书架管理页，而非详情页溢出菜单）。属待办，不是「不适用」。

## 发布版五条已知问题（r323，前四条已修、第五条未修）与后续新增（KI-REL6、KI-REL7、KI-REL8、KI-REL9）

0.1.0 开发预览发布时用户报了五条体验问题。发布当时代码一行未改；此后 KI-REL1 已在 r325、KI-REL2 在 r326、KI-REL3 在 r327、KI-REL4 在 r328 修复，**只剩 KI-REL5 未修**。KI-REL6、KI-REL7 不属于那五条，是后续新发现后按同一编号续排的：**KI-REL7 已在 r344 修复**，KI-REL6 仍未修。派活时按编号引用，根因已在下面各条末尾给出行号，不要重新定位。

**KI-REL1 滚动阅读跳章闪烁** —— 换章时整章重新分页，重排期间画布空着。入口 `entry/src/main/ets/pages/ReaderPage.ets:1531 onReaderContentChanged()`（清 `localReaderPages` + `scrollOffset = 0` 后 `rebuildReaderPages()`），`:5706-5712` 注释说明照上游 `ReaderCanvasSurface.kt:254` 不用滚动兜底。补法：跨章增量追加，或重排期保留上一章尾页作过渡帧；**不要**改两套排版兜底。
> 已盘点，见 [TXT-READER.md](parity/TXT-READER.md) B8「跨章换页与页窗口拼接」第 222 行起（11 行，222–232；根因行 222）。上游那一层共 11 个能力，本地只接住 2 个（页窗口同步换装、四页纵向堆叠绘制）。
> **r325 已修（现象层）**：换章不再清空页表（`chapterHandoffPending` 保留上一章页作过渡帧）、向上翻章落章末（`chapterHandoffUpward`）、拖动到章末即换章（`PanGesture.onActionUpdate` 改用 `applyReaderScrollDelta` 的返回值 + `scrollDragBoundaryTurned` 防连跳）、换书作废交接标记（`chapterHandoffBookId`）、提示页只在真没有当前页时顶上（`appendBoundaryPlaceholders`）。设备验收见 [VALIDATION.md](VALIDATION.md)「r325 KI-REL1」节：分页模式第 2 章末换第 3 章无空窗，滚动模式两向换章均正常。**仍未做**：跨章滚动偏移延续（上游延续余量，本地归零）与「占位页装进页窗口」，故 B8 第 227/229 行状态仍为 `未接`。
> **页层批次 3（结构第一步，不改上面任何状态）**：上游跨章页表的根是 `ReaderPageId(chapterIndex, pageIndex)` 这个页身份，`ReaderPageNavigator.kt:32-33` 注释「Page-table insertions, removals and same-id replacements must not reuse an old index.」。本地 `LocalReaderPage`（`entry/src/main/ets/pages/LocalReaderPaginator.ets:82`）此前无显式身份、`currentPageIndex` 是纯数组下标。本批给它补两个可选字段 `chapterIndex` / `pageIndex`，`paginate()` 加可选末参 `chapterIndex = 0`（不动已有形参顺序）给每页填章内页号；新建 `entry/src/main/ets/reader/ReaderPageIdentity.ets` 只放纯函数 `rebasePageIndex(pages, prevChapterIndex, prevPageIndex): number`——按身份在新页表里重查下标，找不到返回 `-1`（对应上游 `.takeIf { it >= 0 }`）。本批页表仍单章、行为零变化；页表跨章、定位函数抽取留到页层批次 4。
> **页层批次 4（结构第二步，不改上面任何状态）**：`localReaderPages` 由「单章页表」改为「窗口页表」——当前章新排页 + 换章时保留的相邻章旧页，`ReaderPage.ets:1798 mergeChapterPages` 保留 `chapterIndex ± 1`、丢弃旧表当前章页、按 `(chapterIndex, pageIndex)` 升序（对应上游 `retainChapterWindow` `ReaderPageNavigator.kt:36-43`，按任务书不单独抽成导出函数）。`currentPageIndex` 改**页表内下标**（不是全书下标，也不是章内下标），章内页号由 `chapterPosition()` 现算。`reader/ReaderPageIdentity.ets` 补齐 5 纯函数（上游 `:121-126`/`:134-139`/`:188-197`/`:199-207`）：`locateOrNull`（只在当前章页范围内扫、`if (page.startPosition > chapterPosition) break`、不把未定位折叠成 0）、`chapterPosition`、`locateChapterPage`（`coerceIn` 钳位）、`canTurnNext`/`canTurnPrevious`（忠实 `window.next/previous != null` 语义，直接看 `pages[pageIndex±1]`）；合计 6 导出，`locateReadyPage`/`missingAdjacentChapters`/`retainChapterWindow` 不抽。`ReaderPage.ets` 连带改 5 组：定位循环 → 三纯函数；前后翻 ±1/±delta、`canTurnToPrevious/Next`、跳转、Slider onChange → 章内页号现算；显示/进度（无障碍页码 / footer / `getReaderInfoValue` / `getWholeBookProgress` / `getWholeBookPageIndex` / `getProgressSliderMaximum` / slider 三处赋值）→ `currentChapterPageIndex()`/`currentChapterPageCount()`；滚动（`readerScrollContentHeight`/`readerScrollAbsoluteOffset`/`seekReaderScrollAbsolute`/`scrollLastPageIndex`）→ 按本章过滤，避免邻章旧页污染本章可滚高度、章末 20dp padding（`ReaderCanvasSurface.ets:1220`）与进度分母；`ReaderScrollPolicy.apply` 的 `hasPrevious`/`hasNext` 由 `window.previous/next !== undefined` 改按本章算——否则本章首页的 previous 是上一章旧页，会让 `apply` 走 PREVIOUS crossing 而非钳回边界，往回滚偏移量算错且不触发换章；改后本章边界 `hitBoundary=true` 由 `turnReaderScrollPage`（`:2279-2281`）交 `onTurnChapterBoundary` 换章。转场一行不动：`ReaderCanvasWindow.of()` 按 `pages[pageIndex±1/±2]` 取四页，窗口表跨章后 next/previous 自然取到邻章页。**仍未做**：滚动跨章偏移延续（偏移归零在 `onReaderContentChanged`，与页表无关，B8 第 233 行仍 `未接`）、占位页装进页窗口、流式页流出、增量分页只排缺的章、三槽正文常驻（任务书明令不做）。本批只交代码与预检原始输出、不改任何状态词，屏幕现象与完成态待验收方判定。
> **页层批次 4 收口（2026-11-10，`99d616e`）**：用户实测否决了批 4 的验收结论（「滚动到下一章还是会跳，有时还能看到『继续滚动到下一张』，完全不是首尾相连」），复查后找到三个真根因并已修。①`applyReaderScrollDelta` 按「本章是否还有页」（`position.pageIndex + 1 >= position.pageCount`）判章末：页表跨章后本章末页的下一页就是邻章真页，条件却照样成立，于是走「钳住 `scrollOffset` 等异步换章」那条分支，**从不推进 `currentPageIndex`**，手指还在动画面钉住不动。现改为按「页表里是否还有下一页」（`this.currentPageIndex + 1 < pages.length`）判，有就推进；滚进邻章页时只置 `scrollDrivenHandoffChapter`（`ReaderPage.ets:509`）由调用方发换章，位置一秒不动。②`@Prop` 首次赋值不触发 `@Watch`：`onBookChanged`（`ReaderPage.ets:1613`）拿 `chapterHandoffBookId` 认书，首次进书是空串，于是滚动模式下第一次 `book` 赋值（恰好是换章那一帧）被判成「换书」，把刚置上的 `scrollDrivenHandoffChapter` 清成 -1，守位从来没生效。现改用独立 `observedBookId`（`ReaderPage.ets:539`）并在 `aboutToAppear` 初始化。③换章时有四处按「宿主整章百分比」覆盖位置：`onChapterTitleChanged` 清零 `scrollOffset`、`restoreProgressPosition` 绝对位移还原、`getWholeBookProgress` 按宿主章号算、`emitReaderProgress` 按宿主章号报。滚动驱动换章时全部让位给 `currentPageIndex + scrollOffset`。
> 同时收口三处跨章「错位」：邻章预排与真页重排统一走 `resolvePaginationTitle`（`ReaderPage.ets:4616`，原来邻章传空串、真页吃滞后的 `displayChapterTitle`，同一章排出来 6 页与 7 页不一致，页表整表替换必然错位）；章末占位页文案清空成**空白承接页**（`insertBoundaryPlaceholders` `ReaderPage.ets:2030`，画「继续滑动以加载下一章…」等于把加载态怼到用户脸上，与首尾相连正相反）；邻章预读请求加 1.5s 在途超时重发（`ADJACENT_REQUEST_TIMEOUT_MS`），宿主对「这一章刚变成正文」静默不回应时不会永久卡住。
> 设备验收（2026-11-10）：向下 `18/18 66.7%` → `1/6 66.7%`（连拍 14 帧）、向上 `1/6 66.7%` → `18/18 66.7%`（连拍 14 帧），同一屏内新旧章正文连续堆叠、无提示文字、一次手势只跨一章；章内短滑页脚 `1/6 → 2/6 → 3/6 → 5/6 → 6/6` 单调无回退。B8 五行与 D6 两行已按代码落点改判（见 [TXT-READER.md](parity/TXT-READER.md)）。**仍未做**：正文三槽常驻、流式页流出、整本串成无限长页表（任务书明令不做）；滚动模式下跨章瞬间页脚整本进度仍有首帧 `0.0%` 的短暂闪动（`readerProgress` 尚未回填，跨章稳定后立即回到正确值）。

**KI-REL2 标题与正文分离** —— 标题画在正文之外的独立 ArkUI 组件里，不是画布画的。`ReaderPage.ets:5712-5733` 的 `else if (currentPageIndex === 0)` 分支，`Canvas` 在其下；`ReaderCanvasSurface.ets` 全文只有 `:1129` 用到 `titleOnly`（算页高）。上游把标题当正文块流里的 `isTitle` 块（`ReaderChapterBlockMeasurer.kt:260-320`）。补法：标题作首行块交给画布，删画布外的标题分支与 `measureTitleReservedLines()`。

> **r326 已修**：标题已进排版流。`LocalReaderPaginator` 新增 `LocalReaderTitleBlock` / `LocalReaderTitleSegment`，`paginate()` 与 `countPagesIncrementally()` 各加第 15 参 `titleBlock`，`addTitleBlock()` 把标题段逐 cluster 折成带 `titleLine` / `titleAlign` / `titleFontScale` 的真实 `LocalReaderLine`，与正文共用 `appendLine`/`advanceColumn`/`flushPage`；`ReaderCanvasSurface.layoutPage()` 按 `titleAlign` 居中、按 `itemTextStyle()` 换标题样式、按 `page.centerVertical` 整页下移。三个派生条件逐条对齐上游：`centered = titleMode === 1 || isVolume || !hasBody || singleImage`、`pageBreakAfter = singleImage && hasBody`、`centerVertical = !hasBody || singleImage`（`LegacyReaderChapterPaginator.kt:291`、`:326`、`:321-325`）。画布外 `ReaderTitleSegments` 分支与 `measureTitleReservedLines()` 预留行数已从绘制路径摘除。设备验收见 [VALIDATION.md](VALIDATION.md)「r326 KI-REL2」节：分页模式标题与正文首行同屏连排、滚动模式标题随正文一起被裁、单图模式第 1 页纯标题页水平+垂直居中（18 页 = 1 标题页 + 17 正文页）。**仍未做**：标题折行仍是逐 cluster 硬切、不按词断行，故 B9 第 252 行仍为 `未接`（其余 9 行已改判 `已接`）。
> 已盘点，见 [TXT-READER.md](parity/TXT-READER.md) B9「标题块在排版流里」第 242 行起（10 行，242–251；结构根因行 242，行为偏差行 247）。`titlePageBreakAfter`/`titlePageCenterVertical` 不是用户开关，取值由「本章正文是否为空」×「是否单图模式」四种组合派生；本地只实现其中 D 一档（第 249 行）。

**KI-REL3 目录打开慢、滑动卡** —— 慢：`pages/CatalogPage.ets:85-92` 在 `showWordCount`（默认 true）时先 `loadChapterWordCounts()`（`:361-385`）整本逐章算字数。卡：`:578` 用 `ForEach` 而非 `LazyForEach`，`getChapters()`（`:127-159`）每帧全量重算。补法：关字数时不触发算字数、字数惰性/缓存、列表换 `LazyForEach`。

> **r327 已修**：三条一起改。①字数改读预存字段——`chapter.wordCount`（`BookRepository.buildChapterRows()` 在切章时由 `content.substring(charStart, charEnd).trim().length` + `wordCountFormat()` 写入，与上游 `TextFile.kt:317-325` 同口径），`loadChapterWordCounts()` / `wordCountsLoading` / `wordCountGeneration` / `formatWordCount()` 整块删除，「正在统计章节字数」中间态不再存在；②列表换 `LazyForEach` + 新增 `class CatalogChapterDataSource implements IDataSource`（`totalCount` / `getData` / 注册注销监听 / `setItems` 整批 `onDataReloaded()`），屏幕外的章节行不建子树；③派生结果缓存进 `@State chapterView`，由 `@Watch('onChapterViewInputChanged')` 挂在 `query` / `ascending` / `useTitleReplacement` / `collapsedVolumes` 上重算一次，`build()` 不再调 `getChapters()`。顺带把反序从「整个扁平数组翻转」改成按卷分组反转（`reverseTocHierarchy()`，卷标题仍排在子章之前）。设备验收见 [VALIDATION.md](VALIDATION.md)「r327 KI-REL3」节：进目录列表与字数同帧出现、状态行只有「正序/倒序」，滚动到第 11/12 章无白块，搜索「3」只剩「第3章(1)」。**仍未做**：多选次级菜单缺上游的「从最后起选」；反序的「卷名在子章之前」因测试书无分卷，缺屏幕证据，C5 对应行维持 `未接`。
> 已盘点，见 [TXT-READER.md](parity/TXT-READER.md) C5「目录页」第 326 行起（6 行，326–331）+ A4 第 119 行。上游字数是 `BookChapter.wordCount` 预存字段、目录页永不读正文（第 326 行）；列表 `FastScrollLazyColumn` 惰性 + 数据源 `flowOn(Dispatchers.Default)` 不逐帧重算（327/328 行）；反序在数据源层一次反转，本地在渲染期倒序复制导致卷名跑到子章后面（329 行，本轮唯一确定行为偏差）；多选缺「从最后起选」（330 行）。

**KI-REL4 同名同作者的第二本书加不进书架** —— `pages/Index.ets:5602-5617` 按 `format` + `title` + `author` 判重，上游 `model/localBook/LocalBook.kt:249 importFile(uri)` 按 `bookUrl` 判重（`:260-266` 另有失效记录接回）。补法：判重键改 `bookUrl`，再补接回分支。

> **r328 已修（判重键）**：把判重键换成 `bookUrl`，并让 `bookUrl` 真正由文件路径派生——`BookRepository.importLocalBook` 的正文文件名从 `local-${Date.now()}.txt` 改成 `local-${md5Encode16(uri)}.txt`（对齐上游 `LocalBook.kt:252-259` 的 `bookUrl = FileDoc.fromUri(uri).toString()`）。`Index.ets` 的判重整段重写：命中同一个 `contentPath` 时按上游 `:280-288` 走「更新」分支（书目行沿用原记录，只换 `chapterCount`/`lastChapter`/`tocRule`，`latestChapterTime = 0` 触发重新分页，`saveChapters` 整本重建目录），不再 `discardImportedCopy` + 拒绝；未命中才新增。设备验收见 [VALIDATION.md](VALIDATION.md)「r328 KI-REL4」节：书架 1 本 `the-metamorphosis` 时导入同名同作者的第二个 `the-metamorphosis.txt` → 变 2 本；紧接着再导入同一个文件 → 仍 2 本。**仍未做**：失效记录接回（`planLocalBookImportReuse` / `rebindLocalBook`，对照表 F 块第 2、3 行仍 `未接`）、多选导入、导入页「已上架」标记、从文件名解析作者。**迁移后果**：本改动前导入的书用时间戳命名，`bookUrl` 与新键对不上，那本同名书会被当成另一本书再新增一次。
> 已盘点，见 [BOOKSHELF.md](parity/BOOKSHELF.md) F「本地书导入与判重」第 533 行起（7 行，533–539；根因行 533）。上游四条链路四个判重键（`bookUrl` / `originName` / `hasFile` / `bookUrl`+`name+author`），本地只有第四种；另缺失效接回（534 行）、接回判据（535 行）、多选导入与「已上架」标记（537/538 行）、文件名解析书名作者（539 行——本地 `author` 恒空，是判重键失效的上游原因）。
>
> **r341 已补齐 F 块其余 5 行**：失效记录接回与判据（`data/LocalBookImportPlanner.ets` 的 `planLocalBookImportReuse`，接回时只删旧 `bookUrl` 的 `chapters` 行、保留分组与阅读记录）、多选导入（`BookRepository.pickLocalBookUris` 的 `maxSelectNumber = 500` + `importLocalBooks` 串行导入、部分失败不打断）、导入确认页「已在书架」标记（`pages/LocalBookImportPage.ets`）、文件名解析书名作者（`BookRepository.parseNameAuthor`，作者不再恒空、也不再写死「本地 TXT」）。三处与上游不同：接回判据的「文件名相同」改用 `title`（本地 `originName` 落的是 `local-<md5>.txt`，不是文件名，因此手工改过书名的记录接不回）；只放开多选、未放开 PDF/MOBI/AZW3/ZIP 后缀（本地没有这几种格式的解析器）；确认页取代上游的「浏览文件夹列表页」（鸿蒙 `DocumentViewPicker` 不提供目录枚举）。


**KI-REL5 浅色模式适配差** —— 深色模式的适配明显好于浅色，浅色模式配色未打磨。根因：r300–r317 的深色模式改造集中在夜间配色与主题包，日间配色基本沿用改造前的旧值，`entry/src/main/resources/base/element/color.json` 里的 `theme_*` 日间色没重新对齐上游浅色方案。补法：按上游 `ThemeConfigScreen.kt` 的浅色档逐项对齐日间色，与深色同一套 token。

**KI-REL6 向上换章落点落在上一章末页顶部** —— 滚动模式往回滚进入上一章时，`currentPageIndex` 会正确落到上一章末页（`scrollDriven land pageIdx=…` 日志与画面一致），但**页内偏移不精确**：`applyReaderScrollDelta` 的 PREVIOUS 分支把越界位移钳成正值（`Math.max(0, Math.min(previousExtentVp, rawOffsetVp))`），而 `rebuildReaderPages` 的落点钳位是 `Math.max(-landingExtentVp, Math.min(0, this.pendingChapterScrollVp))`，正值会被 `Math.min(0, …)` 抹成 0，于是停在上一章末页顶部而不是「接着往回滚的位置」。
> 本轮取舍：向上跨章的**连续性**（能滚进去、画面不跳、手势不断）优先，落点精度不追求。用户观感是「回到上一章最后一页的顶部」，比之前的「跳回章首」已经接近很多，但与向下换章（能精确停在 `scrollOffset=-13.9` 这类中间位置）不对称。
> 修法留待后续：`pendingChapterScrollVp` 需要一个能表达「向上余量是多少」的符号约定，或者让落点钳位在向上换章时允许取正区间 `[0, landingExtentVp]`，两者都要先确认不会与向下的 `Math.min(0, …)` 语义打架。代码里已在 PREVIOUS 分支写了这个取舍的注释。

**KI-REL7 页眉在“状态栏显示时隐藏”档位下永不显示** —— 阅读页把页眉模式设成“状态栏显示时隐藏”（`headerMode = 0`）且阅读时隐藏系统状态栏（`hideStatusBar = true`）时，页眉本应显示，实际整块不画。原因只在可见性判定少了一支：`entry/src/main/ets/pages/ReaderPage.ets:6536` 的 `isReaderHeaderVisible()` 写成 `return this.infoSettings.headerMode === 1;`，只认“显示”档，模式 0 没有回落到 `hideStatusBar`；同函数 `:6537` 的注释“HOS 目前保留系统状态栏”也不成立——`syncReaderSystemBars()`（`:1134`）在 `hideStatusBar` 为真时已 `setSpecificSystemBarEnabled('status', false, false)` 把状态栏关掉。页脚**不是**缺陷：`isReaderFooterVisible()`（`:6541`）的 `footerMode !== 1` 与上游一致，当前设备 `footerMode = 1`（隐藏）是设置值本身。
> 上游口径：`legado-with-MD3/app/src/main/java/io/legado/app/feature/reader/legacy/LegacyReaderPageDecorationFactory.kt:333` 写的是 `when (headerMode) { 1 -> true; 2 -> false; else -> ReadBookConfig.hideStatusBar }`，模式 0 就是“状态栏可见时隐藏页眉、状态栏已隐藏则显示页眉”。
> 设备实证：把档位临时切到“显示”后页眉立刻出现（左 `第1章(1)`、右 `02:50 100%`、下方一条分隔线，正文整体下移，`getReaderInfoReserve(true)` 的预留也跟着生效），说明绘制链路（`buildReaderHeaderDecoration`（`:5725`）→ `entry/src/main/ets/reader/ReaderCanvasSurface.ets:1141` 的 `drawPageDecoration()`）本身正常，坏的只有这一个判定；试完已把 `headerMode` 改回 0。
> 修法（**r344 已修**）：把 `isReaderHeaderVisible()`（`entry/src/main/ets/pages/ReaderPage.ets:6742`）改成三支——`1` 返回 `true`、`2` 返回 `false`、其余返回 `this.hideStatusBar`，并把原来那条「HOS 目前保留系统状态栏」的错误注释订正为引用上游 `LegacyReaderPageDecorationFactory.kt:333` 三档口径。同时给 `onSystemBarSettingsChanged()`（`:404`）补一支：`headerMode` 不是 1 也不是 2 时调 `onPaginationInputsChanged()`，否则切 `hideStatusBar` 后页眉会出现但不重排。设备验收见 [VALIDATION.md](VALIDATION.md)「r344 阅读域 UI 八批对齐」节：四档行为全部符合，隐藏状态栏开 / 关时正文首行位置相差 80px（页眉行高），证明重排确实发生。

**KI-REL8 详情页不认私密锁** —— 书架对私密书显示锁定并要密码，但点进详情页后封面、书名、简介、最新章节全部直接显示，编辑入口也能进。入口 `entry/src/main/ets/pages/BookInfoPage.ets`（全文 `isBookLocked` / `requiresPrivateUnlock` 零命中）；对照 `pages/BookshelfPage.ets:852` 的 `isBookLocked`、`:868` 的 `isGroupLocked` 与 `:2699`/`:2720` 的遮罩分支。上游整页脱敏（`BookInfoViewModel.kt:170-174`、`BookInfoScreen.kt:355-373`、`:665-734`、`:1343-1353` 的 `PrivateMaskLine`）。
> 修法：`BookInfoPage` 加 `@StorageProp` 读 `PrivateAccessRepository` 的解锁态，未解锁时把封面 / 简介 / 章节名替换成遮罩行并禁用编辑与阅读记录入口。判为**安全相关的行为不一致**（不是纯观感），所以记在这里而不是只记在验证记录里。

**KI-REL9 外观页与欢迎页各留一套主题选择器（批6 已修）** —— 欢迎页第 4 页已改用 `entry/src/main/ets/components/ThemeSelectors.ets`（`ThemeModeSelector` / `ThemeColorSelector`，提交 `0d9d769`），但外观页 `entry/src/main/ets/pages/ThemeSettingsPage.ets` 仍是自己的 `ThemeModeItem`（`:939-966`）与 `ThemePaletteItem`（`:969-1013`）。同一件事两套画法，观感不同：模式档选中底前者的 `themeColorSurfaceElevated`（tonal）vs 后者的 `themeColorAccent`（filled）；圆角前者「首尾 14 / 中间 0 / 无缝」vs 后者「首尾 20 / 内角 2 / 档间 2vp」；配色卡选中勾前者有 `themeColorAccent` 底色 + 20 号 `#20212A` 勾（`:998-1002`）vs 后者无底色 + 24 号勾（`ThemeSelectors.ets:172-177`）；名字间距 8 vs 12。
> 上游只有一个 `ThemeModeSelector`（`ThemeConfigScreen.kt:1004-1040`）与一个 `ThemeColorButton`（`:1077-1183`），欢迎页（`OnboardingScreen.kt:339-357`）与外观页（`ThemeConfigScreen.kt:223`/`:237`）调的是同一对组件，所以上游不存在这个差异。配色卡那处**无底色的勾**是上游真实形态（`:1157-1171` 那个 `Box` 没有 `background`），外观页现版是旧的。
> 修法见 [VALIDATION.md](VALIDATION.md) 的「追加（r346 之后）」一节。判为**观感不一致**（不是功能缺失），所以只登记、本轮不改代码。
> **批6 已修**：`pages/ThemeSettingsPage.ets` 已切成公共件 `ThemeModeSelector` / `ThemeColorSelector`（themeMode 字符串三值转 number 传入），私有 `ThemeModeItem` / `ThemePaletteItem` 两个 struct 已删；外观页模式三档与配色卡现与欢迎页第 4 页同一套画法。



## 书架与分组

- r250 的全局排序档位和分组 `bookSort` 覆盖逻辑已接入；E 端尚未使用多本书和多组分组逐档核对真实列表顺序。
- 书架布局九字段的 Android ZIP 差异值往返、外部 Android ZIP 分组导入导出尚未完成 E 端设备验收。
- r256 已验证隐藏页签后从分组管理切换到“本地未分组”并在冷启动后保留；没有自定义分组的设备场景未覆盖自定义筛选项。
- 分组卡片的拖拽排序、封面实际选择/冷启动读回仍未验。
- `isPrivate` 已不再是纯标记：批 6（r341）接通密码校验（PBKDF2）、解锁授权集、私密分组锁定页与封面遮罩；批 5（2026-11-17 自造与降级清算）又接通生物识别快捷解锁（`userAuth` 人脸/指纹，需 `ACCESS_BIOMETRIC` 权限，真机可验、模拟器无硬件时开关置灰）与三个 verifyOn* 时机开关、应用启动验证门、离开应用重新验证。`enableRefresh` 仍不控制分组更新（分组刷新未接入）。

## Android ZIP 兼容

- r255 已在 E 端 HOS 模拟器验证 `readConfig × themeConfig` 两类别各自包含或忽略的四种组合，阅读设置与护眼六键按相应类别恢复或保留。
- `bookGroup.json` 的备份导出和恢复导入代码路径已接入；仍需验证外部 Android ZIP、冲突合并和完整设备往返。
- 书架布局类别已有九字段写入/恢复路径，但没有用九个不同哨兵值逐项验证。真实 Android ZIP 的完整兼容范围尚未验收。
- 阅读记录会话、按日明细和按书汇总已由原生本地仓储承载；Android ZIP 中的 `readRecord.json`、`readRecordDetail.json`、`readRecordSession.json` 仍仅作兼容归档保留，不导入原生阅读记录。
- ZIP 兼容不代表完整 Android 数据库迁移、跨类别事务回滚、凭据恢复或正文打包。
- `keyboardAssists`：本地无该表（`data/RdbSchema.ets` 20 张 `CREATE TABLE` 无此项，`allStatements` 亦未追加），恢复时该条目只进保留目录（主循环兜底 `data/BackupRepository.ets:1482`-`:1483`），备份时仅当保留目录存有副本才原样拷出（`copyPreservedEntries` `:2573`-`:2599`）。上游该表的业务消费方为零（`grep -rn 'keyboardAssistsDao' --include=*.kt app/src/main/java` 恰 4 行，全在备份/恢复与建表/DI）。忽略项一侧本地有效，但跳的是 ZIP 条目而非数据库行。

### 本地书籍行登记（BOOKSHELF.md 的 localBook 未接行）

本节登记 [书籍总账](parity/BOOKSHELF.md) 里 `localBook` 名下 **72 行 `未接`** 的「为什么不修」。编号 `KI-LB<n>` 与对照表「备注」列的标记一一对应。判定口径按 [PROJECT.md](PROJECT.md)：只有上游存在、且属于本地书籍这条链路的能力才补；依赖尚未迁移的体系或纯视觉差异的，登记不修。**2026-11-09 起 WebDAV 与在线书源已纳入范围（`PROJECT.md:24-44`，尚未排期）**，依赖它们的两类不再按「范围之外」处理，改为「要接，待排期」；仍在[范围之外](PROJECT.md)（`PROJECT.md:46-48`）的是 AI 在线服务、云同步与额外设备形态。 **r341 收口按语（2026-11-13）**：下面 KI-LB1–LB6 与「附注」是 **r323 当时的历史登记**——当时 `localBook` 名下有 72 行 `未接`，这些段落写的是「为什么不修 / 补法」的快照，其中的本地代码行号、`selectBooksSql` 列数、「全仓 0 命中」等断言**已随 r341 批 1–12 落地而过时**。现状以 [书籍总账](parity/BOOKSHELF.md) 的 `scripts/parity-rows.py` 实跑为准：批 2 补齐书籍卡片信息行与 `latestChapterTitle`/`lastCheckCount`/`wordCount` 等字段读取、批 5 接通选择模式与批量动作、批 6 接通私密体系（`isPrivate` 从库里读出并参与访问控制）、批 7 接通详情页更多菜单/头部三行/封面手势/摘要三分支/chip 标签编辑/自绘删除面板、批 9 新建书架管理整页。下列标「r341 已接」的行即已被推翻者；仍依赖在线书源、逐章下载器、EPUB 打包器的部分维持 `**要接**`，逐行阻塞原因见 [BOOKSHELF.md](parity/BOOKSHELF.md) 的 `## r340 复核结论` 收口说明。下面把几处最扎眼的「本地现状」断言就地改为 r341 现状（标 `r341 已接`）；「为什么不修 / 补法」等 r323 规划文字保留供追溯，不再逐句改写。

**KI-LB1 书架卡片信息行（16 行，属 bookshelfLayout 视觉差异，本轮不修）** —— 覆盖卡片副标题作者行、紧凑模式「作者 · N 未读」副标题、列表卡片描述行显示当前章、标题区未读徽标叠加更新图标、封面无障碍描述、未读章节数角标、更新小红点、更新中进度指示、书籍类型标签、来源标签（搜索模式）、自定义标签行、列表模式简介、最后更新时间、最新章节、字数统计、等待更新数。
上游 `ui/main/bookshelf/BookItem.kt:865`（`subTitle`）、`:870`（`desc`）、`:855-864`（`TextCard` 未读徽标）、`:754-765`（`bookTypeLabel`）、`:765-773`（`matchedSourceLabel`）、`:888`（`bookshelfShowTag`）、`:919`（`BookItemIntro`）、`:944-951`（最后更新时间）、`:952-959`（最新章节）、`:814`/`:838`（`accessibilityLabel`）；计数来源 `BookShelfItem.kt:48`（`isNew` = `lastCheckCount > 0`）、`:50`（`getUnreadChapterNum` = `max(totalChapterNum - durChapterIndex - 1, 0)`）；开关 `BookshelfConfigSheet.kt:511`（标签内容二级面板）、`:579`（等待更新数）、`:703`/`:734`（`bookshelfShowWordCount`）。
本地（r341 已接）：批 2 已在书籍卡片上补齐作者/紧凑「作者 · N 未读」、未读角标与更新红点、书籍类型标签、横向标签行、最新章节、最后更新时间、列表标题右侧未读徽标；r323 此处写的「只有 `BookCover` + 书名 `Text`」「封面角标是总章数」已不成立。
为什么不修（r323 历史结论，r341 已被推翻）：批 2 已按 `bookshelfLayout` 补齐整套计数与开关（`showUnread`/`showUnreadNew`/`showTip`/`bookshelfShowTag`/`bookshelfShowWordCount` 等 10 个键）并落卡片渲染；本节「全仓命中为 0」的断言已过时。其余排版层仍以 bookshelfLayout 独立排期项的形态登记。
补法：先补 `lastCheckCount` / `totalChapterNum` 的读出（见 KI-LB1 附注），再按 `bookshelfLayout` 单独立项做卡片信息行。

**KI-LB2 书架菜单与批量操作（9 行）** —— 覆盖更多菜单·添加网址、导出书单、导入书单、拖拽重排书架、移动到分组、批量私密标记、批量删除、删除时勾选删除源文件、私密分组锁定页。
上游：`ui/main/bookshelf/BookshelfScreen.kt:729`（添加网址）、`:756`（导出书单）、`:764`（导入书单）、`:1743-1748`/`:1795-1800`（`rememberReorderableLazyGridState` 拖拽）、`:643`（移动到分组）、`:655-668`（批量私密）、`:679`（批量删除）、`:1540-1572`/`:1552-1563`（删除时勾选删源文件）、`:1619-1646`（私密分组锁定页）。
- 本地：`pages/BookshelfPage.ets` 的「更多」菜单里「导出书单 / 导入书单 / 日志」三项已于 r341 批 1 接通（书单 JSON 落盘与导入、AppLog 日志页）；「网址导入」仍是占位（`onUnavailableAction`），随在线书源模块；批量操作已于 r341 批 5 接通。
为什么不修：网址导入依赖在线书源模块（要解析远端网址），不在 r341 范围内；「书单导入导出」与「批量/私密」曾登记为缺口，现已分别由 r341 批 1 / 批 5 / 批 6 接通（`Book.isPrivate` 已补字段与三处读取，`pages/BookshelfPage.ets` 的「私有标记未生效」占位文案已去掉）。
补法：书单导入导出与网址导入各自单独立项；私密体系要先把书级 `isPrivate` 从 `books` 表读出来（`data/BookRepository.ets:127-131` 的 `selectBooksSql` 目前不 SELECT 该列）。

**KI-LB3 详情页顶栏与更多菜单（10 行）** —— 覆盖顶栏更多菜单（18 项）及其中的上传书籍、同步到远端、禁用阅读记录、置顶、设置书籍变量、允许更新、长按分章、删除确认、设为私密。
上游：`ui/book/info/BookInfoScreen.kt:1033-1141`（更多菜单）、`ui/book/info/BookInfoContract.kt:376-396`（菜单项定义）。
本地（r341 已接）：批 7 把详情页「更多」按钮从 `onUnavailableAction` 占位改成 `BookInfoMoreMenu()` （置顶、刷新书籍信息、删除确认开关），批 6 补上「设为私密/取消私密」，批 7 还接通置顶 `topBook` 与刷新 `refreshBookInfo`；r323 此处写的「整组 18 项没有入口」已不成立（其余仍依赖在线书源）。
为什么不修：其中「上传书籍」「同步到远端」依赖 WebDAV（本表 E 块已登记 WebDAV 四行未接）；「禁用阅读记录」「允许更新」「设为私密」需要 `books` 表的 `disableReadRecord`/`canUpdate`/`isPrivate` 三列——DDL 里有（`data/RdbSchema.ets:253`、`:252`、`:91`），但 `data/BookRepository.ets:127-131` 的 `selectBooksSql` 只 SELECT 22 列、`:674-717` 的 `readBookRow` 也没读它们，属于「列在库里但读不出来」；「长按分章」需要 `splitLongChapter`，本地全仓 0 命中。
补法：先把上述三列加进 `selectBooksSql` 与 `readBookRow`，再逐项接菜单；`splitLongChapter` 要单独设计存储（上游内嵌在 `ReadConfig`）。

**KI-LB4 详情页头部与摘要（13 行）** —— 覆盖移出书架后「点击移出」提示、头部书名（含长按菜单）、头部作者行（点击/长按）、头部来源行、封面点击与长按、封面无障碍描述、加入书架（含冲突提示）、长按加入书架选分组、动作卡·换源、摘要·已读状态三分支、摘要·目录加载失败提示、摘要·备注卡片可点编辑、私密锁定内容页。
上游：`ui/book/info/BookInfoScreen.kt:1405-1416`/`:1425`（`click_to_remove`/`long_press_group` 两段轮播提示）、`:1298-1320`（书名 `AnimatedTextLine` + `combinedClickable`）、`:1326`（作者）、`:1335-1339`（来源行）、`:1144`（封面点击/长按）、`:1164`（封面无障碍）、`:1390-1485`（加入书架与冲突提示）、`:1533-1625`（摘要）、`:664`（私密锁定内容页）。
本地（r341 已接）：批 7 已给书名加点击进搜索 + 长按「搜索/展开收起」菜单、作者点击进搜索、封面点击换封面 + 长按全屏看图 + 无障碍描述、备注块可点进编辑、摘要第三段改成「未读/已读完/已读 N 章」三分支；r323 此处写的「全是纯 `Text`、封面不可点、两分支、备注只读」已不成立。
为什么不修：「加入书架/长按选分组」依赖搜索进详情的路径（本地还没有在线书源搜索）；「动作卡·换源」依赖书源体系；「私密锁定内容页」依赖 KI-LB2 的私密体系；其余是交互与无障碍细节，属独立排期。
补法：「已读三分支」可随 `totalChapterNum` 读出一起补；备注可点编辑可复用已有的元数据编辑面板。

**KI-LB5 详情页编辑与各类面板（11 行）** —— 覆盖编辑·标签编辑器、编辑·知识卡编辑、书架删除面板、书架删除面板·同名副本切换、书架删除面板·删除源文件勾选、面板·分组多选、面板·在线换封面、面板·网络文件选择、面板·压缩包条目选择、面板·不支持文件提示、目录选择（book tree uri）。
上游：`edit/BookInfoEditScreen.kt:435-517`（标签编辑器 `add_tag`/`edit_tag`/`reset`）、`:310-343`（知识卡）、`ShelfDeleteSheet.kt`（182 行，`:102-128` 同名副本切换、`:167-168` 删除源文件）、`BookInfoSheets.kt:109`（`GroupSelectSheet`）、`:194`（`ChangeCoverSheet`）、`:70`（`WebFileSheet`）、`BookInfoContract.kt` 的 `ArchiveEntries`/`UnsupportedWebFile`、`BookInfoScreen.kt:243`（`SetDefaultBookTreeUri`）。
本地：`pages/BookInfoPage.ets:350-353` 的自定义标签是逗号分隔单行 `TextInput`；`:324-338` 的分组多选塞在元数据编辑面板内（不是独立 `GroupSelectSheet`）；`:84-85` 移出书架只弹系统确认框，没有「同时删除文件」与同名副本切换；封面只能选本地图片（`:304-307`），没有在线换封面/网络文件/压缩包条目。
为什么不修：删除源文件与同名副本切换依赖书级 `isPrivate`/本地文件删除语义（`BookRepository.deleteBook` 只删书目与章节，不删 `filesDir/books` 下的正文）；在线换封面、网络文件、压缩包条目都依赖在线书源与 WebDAV；知识卡是独立模块。
补法：删除面板三项可先补（不依赖在线能力），但需要先定「删源文件」在 HarmonyOS 沙箱里的等价物。

**KI-LB6 书架管理页（13 行，整页未迁移）** —— 覆盖整个页面（`BookshelfManageScreen.kt` 1777 行 + `BookshelfManageScreenViewModel.kt` 1136 行）及其顶栏标题随分组名变化、分组筛选按钮、书籍行、行内加分组、行内更多菜单、选择模式·批量换源、选择模式·移入分组、选择模式·删除、书源选择面板、换源预览面板、其它书源选项、删除确认框。
上游：`ui/book/manage/BookshelfManageScreen.kt`（全文件）与同名 ViewModel。
本地：批 9（r341）已新建 `pages/BookshelfManagePage.ets` 整页；`pages/BookshelfPage.ets:2117`–`:2118` 的「书架管理」菜单项已改调 `onOpenBookshelfManage(activeFilter())`，不再是 `onUnavailableAction('书架管理尚未迁移')`。
为什么不修（r323 历史结论，r341 已被推翻）：批 9 已新建 `pages/BookshelfManagePage.ets` 整页并接通标题/分组筛选/书籍行/行内加分组/行内更多/移入分组/删除/删除确认框（见上一行）；仅 5 行（批量换源、书源选择面板、换源预览面板、其它书源选项）仍依赖书源体系、维持 `**要接**`。
补法：整页单独立项，先做不依赖书源的 8 行（标题、分组筛选、书籍行、行内加分组、行内更多菜单、移入分组、删除、删除确认框）。

**附注：`localBook` 六个「列在库里」的字段（r341 已补进 `selectBooksSql` / `readBookRow`）**
`data/RdbSchema.ets` 的 `books` 表 DDL 早有 `isPrivate`/`latestChapterTitle`/`canUpdate`/`disableReadRecord`/`totalChapterNum`/`lastCheckCount` 六列。r323 时这些列「在库里但 `selectBooksSql` 不 SELECT、`readBookRow` 不读、`model/Book.ets` 无字段」；**r341 已改**：批 2 把 `latestChapterTitle`/`lastCheckCount`/`wordCount` 追加进 `selectBooksSql`（末尾索引 24/25/26）与 `readBookRow`/`toBookArgs`，批 6 同样补 `isPrivate` 三处读取并参与访问控制。本节「六列读不出来」的直接原因已消除；`splitLongChapter`/`deleteAlert` 另有处理（`deleteAlert` 由批 7 新建 `data/BookInfoSettings.ets` 落盘）。

## 阅读与规则

- **本地 EPUB 重开被当 TXT（已补 `books.format` 列；存量书需重新导入）** —— `books` 表原先没有 format 列，落库时只存了 EPUB 抽出的 `.txt` 副本路径（`contentPath`），回读时按 `bookUrl` 后缀猜格式、恒判 `txt`，于是杀进程重开后顶栏多出「目录规则」等只对该类书有意义的动作、正文分章与替换规则走错分支。`fd4e56c` 给 `books` 表补 `format TEXT NOT NULL DEFAULT ''` 并在 `RdbSchema.ensure()` 里加幂等 ALTER，`be096c4` 把 `format` 接进 `selectBooksSql`/`upsertBookSql`/`toBookArgs`/`readBookRow`（新增 `normalizeFormat`）。**已知限制**：补列前已导入的存量 EPUB，其 `format` 列是建列时的默认空串，`normalizeFormat` 对空串退回按路径后缀判（仍是 `.txt` 副本 → `txt`），所以存量 EPUB 不会自动修好；**怎么修：删掉重导**——重新导入会走 `upsertBookSql`，`format` 从内存 `Book` 对象带进去。
- 阅读设置尚未逐控件完成回归。系统字体选择已检查；自定义 TTF/OTF 实际导入、CJK fallback、EPUB 字体和多设备排版仍待验证。
- r258 阅读正文高亮规则已在 N 端 HOS 模拟器完成面板可达、创建、命中、停用、冷启读回、滚动模式与删除七项闭环；E 端交接时面板打不开的问题在 N 端未复现。HOS `RegExp` 只覆盖 Android Java Pattern 的安全兼容子集，规则长度、章正文长度和规则条数分别限 256/150000/64，且没有执行超时保证。
- 高亮规则还差两样：**按排版 `configName` 绑定**（`data/ReaderHighlightRuleEngine.ets:54` 对 `configName` 非空的规则直接跳过）、**标题规则不执行**（同处只接受 `targetScope` 0 与 2，`targetTitle=1` 跳过）。**SVG 线型已接通**（`reader/ReaderSvgPath.ets` 解析路径串，画布 `reader/ReaderCanvasSurface.ets:3036-3124` 按 100×50 基准横向拉伸绘制；面板 `pages/ReaderHighlightRuleSheet.ets:701-703` 有「SVG 路径」输入框，规则字段经 `pages/ReaderPage.ets:6590` 注入样式区间）。解析失败或含未支持的 `A`/`a` 弧线时该行不画，不退化成长实线。图片背景、九宫格切线、字体替换、字距行距**已经接通**（`pages/ReaderPage.ets:5273`/`:5291`-`:5293`、`reader/ReaderCanvasSurface.ets:3062`/`:2171`-`:2187`），详见下一条。`highlightRule.json` 的备份写出与 ZIP 恢复已接入并在 N 端设备双向验证，恢复采用合并语义（本地独有规则保留），与上游 `replaceAll` 全量替换不同。Android 默认规则预设导入已在 r260 接入，但与上游有 3 处已注明的差异：`bracket_note_default` 补转义、`date_time_default` 由 314 裁到 179 字符、`title_emphasis_default` 只导入不执行。
- 阅读页书签角标与「书签标记大小」已在 r264 接通：角标显示在正文区右上角，宽度取 `bookmarkBadgeSize`（默认 10dp，0 不显示，上限 50），仅在分页模式与本地书籍显示，翻页与下拉偏移一并作用，`config.xml` 恢复时读回。**自定义角标图片已在 r265 接通**（选择、保存到应用私有目录、渲染、恢复默认，`config.xml` 双向映射）；书签导出于 r263 接通（「所有书签」页按书导出 JSON/Markdown），「书签标记」样式入口的 `migrated` 也已转正。上游没有跨章批量删除/移动书签的能力，本地同样不提供，此项不算缺口。
- 划线/笔记的颜色预设已在 r266 从 6 色扩到上游 `MarkingPresetColors` 的 15 色，并加了内联自定义取色器（8×12 色板 + 手输 `#RRGGBB`/`#AARRGGBB`）。与上游仍有两处差异：上游取色器是独立 `ColorPickerSheet`，本地改成同一面板内展开；上游色板是横向滚动的单行色带，本地改成换行排列（外层遮罩会吃掉横向手势）。取色面板展开时正文区可滚动、按钮行固定在底部，这个溢出缺陷已在 r266 一并修掉。
- 「所有书签」页的书签条目点击=编辑、长按=跳转正文（r263 对齐上游）；笔记条目仍只有点击跳转，没有编辑入口，笔记编辑需在阅读页划线处进入。这与上游一致——`AllBookmarkScreen.kt` 的 `BookmarkDetailItemUi.Marking` 分支只渲染选中文本与备注，本就没有点击行为。
- 「所有书签」页的排序与跨书源提示已在 r268 对齐上游：条目按 `(chapterIndex, chapterPosition)` 排序（上游 `AllBookmarkViewModel.kt:214`），书籍列表按书名排序（上游 `:186` `.sortedBy { it.key.name }`），来源书源与当前书不同的条目在章名右侧标红显示「其他书源」（上游 `marks_other_source`）。排序只在渲染层做，preferences 里的存储顺序不变。
- 目录页搜索栏右侧「更多」菜单已在 r267 接通三项（更新目录 / 替换规则 / 本地 TXT 目录规则），不再是占位。上游 `TocScreen.kt:427-535` 里还有两项未做：「新建替换规则并预填本书作用域」（本地 `openReplaceRuleEditor(id)` 只接受已有规则 id，没有草稿通道）与「拆分超长章节」（`Book` 模型没有 `splitLongChapter` 字段，全仓零命中）。
- 更新目录（单书与书架级 `refreshAllToc`）**不再重映射**书签与划线/笔记（r276 起对齐上游）：上游 `BookmarkRepository`/`BookMarkingRepository` 更新目录时完全不碰这两张表，r267 曾按新旧正文偏移重算（`remapNoTocBookmarks`/`remapNoTocMarkings`），会把用户锚点悄悄挪到别的章节，已整段删除。书签与划线一律按原章节号保留，位置是否需要提醒交给 r270 的跳转前校验（`titleMismatch` 弹「位置可能已偏移」）。N 端实测：把 2 章伪造成 12 章再更新回真实 6 章，书签 4 条与划线 1 条逐字段完全未变，长按第 2 章书签仍能跳转并弹出偏移提示。
- 书签/笔记跳转前的定位校验已在 r270 接入（`data/ReaderBookmarkTarget.ets`）：源指纹不一致报 `sourceChanged`、章节标题不一致报 `titleMismatch`，两种都弹确认框由用户决定是否仍跳。笔记额外先按「选中文本 + 前后文」重定位，同分即歧义并退回确认框。**已知边界**：源指纹取 `androidOriginalPath ?? contentPath ?? id`，书籍换源后若这两者恰好都没变则判为 `match`，不会提示；重定位候选只覆盖 `chapterIndex` 指向的那章与标题同名章，目录大改后可能找不到锚点而退回确认框。
- 标记编辑器的「样式来源」下拉已在 r269 接入，可复用已有高亮规则的样式。**这是有损映射**：只把规则换算成标记的 `effect + color` 两个字段落盘，规则里的下划线粗细/偏移/自定义 SVG 路径、背景图（拉伸/裁剪/九宫格）、字体类字段本地渲染层不支持，换算时丢弃；因此规则日后调整不会回溯改变已有标记。上游 `MarkingSheet` 同样是当场取值、不建立引用，此处与上游一致。
- 阅读记录真实跨午夜持久化、损坏数据扫描/修复提示、阅读字数采集仍未完成或未验。书籍别名归属已接通（`pages/Index.ets:5946` 的 `checkReadRecordAlias` 在 `:5995` 的 `openBook` 开头调用，合并走 `data/ReadRecordRepository.ets:862`/`:884`/`:894`/`:906`）。
- TXT 目录规则完整 CRUD/批量组合和含非空规则的应用备份恢复仍需补测。
- **替换规则正则已加 3000ms 预算并支持超时自动停用**（TXT-READER 批次 4）：`data/ReplaceRuleEngine.ets` 在 taskpool worker 里逐条计时（`DEFAULT_REPLACE_TIMEOUT_MILLIS = 3000`，规则自带 `timeoutMillisecond > 0` 时用它），超预算的规则 id 回传后由 `ReplaceRuleRepository.disableTimedOutRules` 落库停用，该章正文换成「规则名 + 该规则执行超过 3000 毫秒，已自动停用」。**边界**：`ReplaceRuleRepository.applyContentWithResult`（同步入口，供 `applyContentForLength` 与规则预览使用）仍未限时，只有阅读链路的 `applyContentWithResultAsync` 有预算；异步并发保存覆盖风险、完整恢复提示仍待验证。
- **TXT 规则层已按上游补齐七项**（TXT-READER 批次 4）：①编码识别改成「utf-8 / gb18030 / big5 三候选各解前 16384 字节打分」（`BookRepository.ets:2259 detectTextEncoding`、`:2302 scoreDecodedText`），探测阶段不再往 hilog 刷失败日志；②规则库空表自愈（`TxtTocRuleRepository.ets:130 seedBuiltinRules`）；③单章超 102400 字节二次拆成 `原章名(1)`（`BookRepository.ets:2537 appendChapterRange`）；④第一个标题前插「前言」章并取前 500 字作 `intro`（`:2497`）；⑤空标题补「无标题章节」；⑥净化管线补齐十步（去重复标题 / 特殊样式占位与还原 / 逐行 trim 去空行，`:1761 applyChapterContentAsync`）；⑦内容编辑面板加「仅正文」折叠（`reader/ReaderBodyOnlyFilter.ets`）。
- **目录规则预览页已接通**（TXT-READER 批次 4）：目录页「更多 → 本地 TXT 目录规则」进 `pages/TxtTocRulePreviewPage.ets`，双列网格逐条显示「N 章」徽章（`totalCount < 0` 时转圈），点卡片弹章节清单（最多 500 章 + 「仅预览前 500 章」），底部「应用」直接重切全书目录（`Index.ets:5765 applyTocRule` → `BookRepository.refreshToc(..., forcedRule)`）。**扫描必须在 taskpool 里跑**（`data/TocRulePreviewEngine.ets:26`）：主线程逐条同步扫会 `THREAD_BLOCK_6S`，主线程分帧 + `setTimeout` 同样会卡在 `libtimer.z.so SetTimeoutInnerCore` 的 hilog 写 socket 上被杀。3.9MB 书、26 条规则实测约 20 秒，界面全程可操作。
- **打开本地大书会 `THREAD_BLOCK_6S` 的根因已修**（2026-11-03）：`BookRepository.readChapter` 在拿不到章节行时退化成 `deriveChapters`（把整本正文按规则重切 + 逐章折算字节偏移），几 MB 的书在主线程要 2.2 秒，叠加渲染触发 6 秒看门狗、正文空白然后被系统杀掉。现在改成三级取章节行（传入 → `cachedChapters` → `deriveChapters`），并由 `Index.ets` 的 `openBook` 在取正文前先 `await BookRepository.loadChapters` 预热缓存。修复后同一本 8MB 书首屏正文亮像素比例从 0.0134 升到 0.1517，无新 appfreeze。
- **画布绘制与选词菜单第二批已对齐上游**（TXT-READER 批次 6 第二轮）：①文字背景色带合并（`reader/ReaderCanvasSurface.ets` 的 `drawBackgroundBands` + `mergeBackgroundBands`，对齐上游 `ReaderBackgroundBounds.kt` 的 `minimumLineOverlap = 0.5f`）；②划词菜单进出场动画（`pages/ReaderPage.ets` 的 `animateCanvasSelectionMenu`，出现 400ms 淡入 + 0.94→1，收起 320ms 淡出 + →0.96，时长同 `SelectionMenuMotion.kt`）；③正中格状态优先级（`shouldUseCenterPriorityTap`：自动翻页中先开自动翻页面板）；④点划线文字打开该条笔记（`handleMarkingTap`，对齐上游 `markingId` 分支）；⑤图片点击四档（`handleImageTap` + `ReaderCanvasSurface.hitTestImageBox`，按 `clickImgWay` 走）；⑥折叠态一行横向滚动快捷条（首项左距 16、其余 10、右端 1dp 分隔线 + 三点钮）；⑦「更多」二级弹层（主卡 0.96/α0.82，二级卡含返回箭头、240dp 可滚列表与「编辑菜单项」）。
  仍在缺（第七批之后）：滚动整页 PixelMap 缓存、图片双尺寸缓存、选区跨下两页（页层批次 2 已落地代码路径与预检，完成态待验收方判定，此处不删「仍缺」措辞）。分层绘制、文字背景图与九宫格、每格动作、顶栏/标题栏/浮动图标三处配置面板、高亮规则的命中排版与字体替换与文字背景图均已落地，见下一条。
- **高亮规则已能改命中排版、换字体、挂气泡背景图**（TXT-READER 批次 6 第三/四轮）：①编辑面板新增三块（`pages/ReaderHighlightRuleSheet.ets:682-780`）——命中排版四个步进（字前距/字后距/行上距/行下距，0~40 dp 步 0.5）、字体替换（选沙箱字体 + 字重 + 斜体 + 字号偏移 -10~10 sp）、文字背景图（选图 + 四种填充方式 + 0.1~5 倍缩放 + 左右伸出 + 九宫格四条切线 + 手动切图开关）；②画布按上游 `LegacyReaderStyleRangeMapper.kt:270-330` 把一次命中拆成「首字带前距 / 段内不带 / 末字带后距」三段，字体与字号偏移在 `segmentStyle` 里逐段覆盖；③分页器新增 `LocalReaderSizeOffset`，只有字号偏移改行高、行上下距改行间留白（对齐 `ReaderChapterBlockMeasurer.kt:376-392` 的「高亮只改绘制，除字号偏移外不改行高」）；④文字背景图按上游顺序插在色带与字形之间，`.9.png` 原尺寸解码、其余按 density 降采样，排版期预取。**未设备验证的部分**：气泡图实际渲染与命中排版的实际行高变化——设备沙箱与应用数据库对 `shell` 用户均不可写，造不出带 `bgImage` / 字号偏移的规则；编辑器三块本身已在模拟器上逐项看到（1280×2832）。
- **TXT 目录解析仍是整本读入**（TXT-READER 批次 4 未接的两行）：`BookRepository.readTextFile` 一次性 `new ArrayBuffer(fileSize)`，`readTextFileAsync` 虽按 512KB 分块但仍拼成一个整串；切章、`deriveChapters`、`forEachChapter` 全部基于整本字符串。上游 `TextFile.kt` 是 512000 字节/块扫标题 + 正文 8MB 窗口缓存。50MB 以上 TXT 本地会先卡住再出目录，低内存设备长时间阅读有被系统杀后台的风险。
- **全文搜索的正则模式已加 500ms 单章预算**（TXT-READER 批次 3）：`data/ReaderSearchRegex.ets` 用 `taskpool.Task` + `Promise.race` 做截止时间，超时 `taskpool.cancel` 后跳过该章并计入 `timedOutChapterCount`（`pages/ReaderSearchPage.ets:224-226`）。这是**搜索链路**，与上面这条「替换规则同步正则未限时」是两条不同的正则，后者仍未限时。
- **章边界占位页已接通**（TXT-READER 批次 3）：分页模式在章末再翻一页会整屏居中显示「加载数据中…」，滚动模式给「继续滑动以加载下一章…」，新章正文到达后自动撤（`pages/ReaderPage.ets:4186-4203`、`reader/ReaderCanvasSurface.ets:1394-1417`）。设备用 hilog 验过绘制与撤销时序；该中间态只有约 690ms，`snapshot_display` 抓不到截图。
- 在线 URL 规则导入、在线书源抓取、RSS、TTS、WebDAV 未接入，但**自 2026-11-09 起已纳入项目范围、尚未排期**（[PROJECT.md](PROJECT.md) `:24-44`）；AI 在线服务、云同步与额外设备形态适配仍未接入且**仍在[范围之外](PROJECT.md)**（`PROJECT.md:46-48`）。
- **画布绘制细节已按上游补齐一批**（TXT-READER 批次 6，七行）：①高亮规则的下划线线型改成逐行手绘（`reader/ReaderCanvasSurface.ets:2845 drawStyledUnderlines`、`:2876 drawOneStyledUnderline`）：虚线 8vp 实 5vp 空、波浪振幅 3vp 波长 12vp、双线第二条在线下 3vp+线宽、删除线画在行盒 52% 高、荧光填行盒下半截，1 实线仍交给系统段落；**SVG 档（mode 5）已接通**（`reader/ReaderSvgPath.ets` + `reader/ReaderCanvasSurface.ets:3102-3119` 横向拉伸绘制，解析失败不画）。②自动翻页从「到点整页跳」改成逐帧揭示（`pages/ReaderPage.ets:1353 startAutoPageTurn` 用 `createAnimator`；`reader/ReaderCanvasSurface.ets:906 drawAutoPageReveal` 按 `clipRect(bottom=reveal)` 贴下一页并在揭示线下沿画 1px 指示线），滚动模式匀速推进 `scrollOffset` 且到书末不自动关闭；**墨水屏 DISCRETE 分支不做**（ArkUI 侧无 e-ink 检测）。③滚动模式（`pageAnimation === 3`）不画书签角标（`pages/ReaderPage.ets:1937`）。④覆盖转场补 36dp 尾部渐变阴影（`reader/ReaderCanvasSurface.ets:912 drawCoverShadow`、`pages/ReaderPage.ets:4301-4313` 算起点）。⑤淡入转场松手阈值降到 10% 且不看速度（`reader/ReaderCanvasSurface.ets:137 FADE_COMMIT_PROGRESS`、`:219 release()` 新增 `commitProgress` 参数）。⑥「文字背景透明度 0~100」这一行此前判为未接是**误判**：上游 `ReaderBackgroundAlpha.kt` 唯一调用点（`ReadBookRouteScreen.kt:692`/`:712`）传的是 `styleConfig.bgAlpha`，管的是整页背景图透明度，本地 `pages/ReaderPage.ets:4995 backgroundImageAlpha` + `:5220 .opacity(...)` 早已等价，已按上游实际语义改判 `已接`。⑦「同位置多条高亮规则」复核后改判 `已接`：画布按区间边界切段时 `winner` 覆盖赋值（`reader/ReaderCanvasSurface.ets:1952 splitStyledSegments`），同一段字只保留最后命中的那一套样式，不会出现「字色 + 下划线 + 底色」叠加。**第七批补齐**：分层绘制（`drawPage` 拆成底色层 / 背景图层 / 字形层 / 选区层 / 下划线层，选区不再压住下划线）、文字背景图与九宫格切图、相邻同色背景合并成色带、无障碍选区快照。**仍缺**：滚动整页 PixelMap 缓存、图片双尺寸缓存、选区跨下两页（页层批次 2 已落地代码路径，见 KI-EXP3；此处历史清单不删，完成态待验收方判定）。
- **各二级面板已按上游补齐形态**（TXT-READER 批次 5，十四行）：①菜单系统页改成三页签 + `Swiper` 横滑（`pages/ReaderSettingsPage.ets:851`、`MenuSettingsTabPage()` `:869`），「每行图标数」「图标行数」换成「− 数值 ＋」步进器行、点整行才展开滑杆（对齐上游 `TinySliderSettingItem`）；②字号滑杆右侧 56×56 排版方卡（`:718`，图标 24×24 `#B7B8C1`、无文字）；③更多操作面板改成 4 列正方形 + 每页 8 格 `Swiper` + 底部圆点（`pages/ReaderPage.ets:5690-5740`），换源 / 刷新 / 自定义按钮三格带向下箭头；④`image_style` 与 `page_anim` 点一下直接展开单选（翻页动画六档：覆盖 / 滑动 / 仿真 / 滚动 / 淡入淡出 / 无动画）；⑤排版页拆出「正文 / 标题 / 页眉 / 页脚」四个子页签 + 右侧边距方卡（`ReaderSettingsPage.ets:2327`）；⑥页眉页脚补图形型 tip（电池外框、框内电池、纯图标、胶囊五种，用基础形状画）与「同一 tip 只显示首个位置」去重（`ReaderPage.ets:5085 ReaderInfoBattery`、`:5119 ReaderInfoSlot`）；⑦页眉页脚字体从「未迁移」提示改成真正打开字体选择器（`ReaderSettingsPage.ets:1441 openInfoFontSelection`）；⑧高亮规则编辑改成「规则信息 / 样式设置 / 预览效果」三分区 + 作用范围按钮 + 启用开关 + 实时预览卡，下划线档位扩到 7 档；⑨划线面板预设色补到 16 个（含纯黑 `#111111`）、色格改 32dp 圆 + 2dp 描边；⑩主题列表改成网格（2..6 列可切）+ 管理态（全选 / 反选 / 删除 / 置顶 / 置底 / 导出，前 5 份内置带锁不可选）；⑪下划线细调搬进独立「文字下划线」面板、线段高度上限从 10 提到 20；⑫文本处理面板搜索匹配 `group`、行标题显示「名称 (分组)」、规则行加拖拽把手并能真拖动落库（`data/ReplaceRuleRepository.ets:749 reorder`）；⑬底栏按钮配置的拖拽把手从装饰改成真拖动（`ReaderSettingsPage.ets:3196-3252`）。**第七批补齐**：顶栏图标与标题栏动作按钮两处配置面板（连底栏共三处，行内都有自定义图标、眼睛开关、拖拽把手，启用项自动排前）；高亮规则的命中排版 / 字体替换 / 文字背景图（含九宫格切线与手动切图）三块。**仍缺**：高亮规则的「应用排版 chip」——本地没有「命名排版方案」这个实体（`READER_BACKGROUND_STYLES` 只有日夜两色，无完整排版参数），chip 无数据源可列。


### 书签与标注（r268–r276 盘点遗留）

本节由 2026-10-29 的 [ZIP-BOOKMARK 对照表](parity/ZIP-BOOKMARK.md) 盘点得出，2026-10-30 第二轮独立复核后扩为 85 条（已接 72 / 未接 9 / 不适用 4）。9 条 `未接` 全部是用户可感知的能力缺口，逐条登记如下；4 条 `不适用` 是上游内部形态（无 Room 数据库、无 AI 助手、移出书架本就不清书签、Android 独有的 `ACTION_PROCESS_TEXT`），理由写在对照表 B/E 块。

1. **划线/笔记渲染不校验锚点文本**（已设备取证）。上游 `app/src/main/java/io/legado/app/domain/model/BookContentProcessEngine.kt:25-46` 在渲染前对每条 `KIND_USER_UNDERLINE`/`KIND_USER_HIGHLIGHT` 解析 `anchorJson`，`findTargetRange`（`:101-131`）按「选中文本 → 去空白文本 → 全空白归一化」三级退让在离近似位置最近处重定位，解析不到就不计入 `effectiveProcesses`、直接不渲染。本地 `entry/src/main/ets/pages/ReaderPage.ets:1999 getMarkingForTextRange` 只判 `chapterPosition < end && endPosition > start` 的区间相交，**完全不看 `selectedText`**，正文一变高亮就落在错误位置；三处调用点 `ReaderPage.ets:2148`（切段）、`:2326`、`:2431`（逐字 Span）都走这个判断。等价能力 `entry/src/main/ets/data/BookContentProcessEngine.ets:93 findTargetRange` 已存在但只服务高亮规则与正文处理，没接到标记渲染。设备取证：手工构造 `chapterPosition=0`、`selectedText="这一段是占位正文"`（真实位置约 480）的失效标记，本地仍在第 0-10 字渲染高亮。

2. **划词菜单缺「行内快速标记」模式**。上游按 `MarkingUiState.inlineMode` 在 `MarkingSelectionMenu`（行内预览、当场应用上次样式）与 `TextActionSelectionMenu`（完整动作条）之间切换，对应意图 `ReadBookContract.kt:870 OpenQuickMarking`、`:871 OpenQuickMarkingEdit`、`:872 ApplyQuickMarking`、`:875 DismissQuickMarking`，行内态还带 `previewStyle`/`inlineDirty` 两个状态位。本地 `entry/src/main/ets/pages/ReaderPage.ets` 的选区菜单只有 sheet 一条路径（r273 已补「复制」「书签」两项），没有行内预览态。

3. **目录页书签/笔记缺多选与批量操作**。上游 `app/src/main/java/io/legado/app/ui/book/toc/TocScreen.kt:325 selectionSecondaryActions` 提供反选、选中后续、批量加书签、批量去分组、批量删音频；本地 `entry/src/main/ets/pages/CatalogPage.ets` 的书签条目与笔记条目只有单击与长按。**章节行的多选已在 TXT-READER 批次 3 接通**（长按进多选、勾选圈、工具条「已选 N 章 / 操作 / 完成」、菜单全选/反选/加书签/取消选择，`CatalogPage.ets:430-500`），本项现在只剩书签与笔记两个列表没有多选。

4. **目录页缺反序**。上游 `TocScreen.kt:447 reverse_toc` 提供章节与书签列表的倒序开关；本地无排序方向开关，恒按 `chapterIndex` 升序（`CatalogPage.ets:185-200`）。

5. **书签无障碍播报未接**。上游 `feature/reader/core/accessibility/ReaderAccessibilityPolicy.kt:19` 用 `isBookmarked` 把「已加书签」状态提供给读屏软件；本地阅读页没有无障碍策略层，`entry/src/main/ets` 全仓只有一处 `accessibilityText`（`pages/ProfileSubPages.ets:3579`，与阅读无关），读屏用户拿不到「已加书签」状态。

6. **划词菜单「替换」缺预填规则入口**。上游 `ui/book/read/ReadBookController.kt:2065-2068` 在划词菜单选「替换」时发 `ReadBookIntent.TextActionReplace`，`ReadBookRouteScreen.kt:426-433` 接住后把选中文本按行 `trim` 拼成 `pattern`、把 `bookName`/`bookSourceUrl` 拼成 `scope`，直接打开新建替换规则页。本地 `entry/src/main/ets/pages/ProfileSubPages.ets:660-700` 的 `ReplaceRuleEditor` 本身完整（正则、作用域、排除作用域、试跑、分组都在），但只接受 `editingRule: ReplaceRule` 整条回填（`:706 applyEditingRule`），**没有「只预填 pattern」的草稿通道**，`Index.ets` 也只暴露 `openReplaceRuleEditor(id)`。补法：给编辑器加一个可选的 `initialPattern`/`initialScope` 入参，`applyEditingRule` 在无 `editingRule` 时用它回填。

7. **划词菜单「搜索内容」缺预填关键词入口**。上游 `ReadBookController.kt:2096-2099` → `ReadBookViewModel.kt:1564-1569`（`searchContentQuery` 落状态 + `ReadBookEffect.OpenSearch(text, bookUrl)` 打开搜索页）。本地 `entry/src/main/ets/pages/ReaderSearchPage.ets` 全书搜索页完整（历史、正则、替换开关、进度都有），但 `aboutToAppear`（`:52`）只加载历史，**没有 `initialQuery` 入参**，`Index.ets:4104-4112` 打开时也未传关键词。补法：加 `@Prop initialQuery: string`，`aboutToAppear` 里非空则直接触发一次搜索。

8. **划词菜单另外 8 项本地无对应能力**。上游 `ReadBookController.kt:2159-2183` 共 14 项，除已接的复制/书签/划线笔记、上面两条、以及不适用的第三方文本扩展外，还有：分享（`:2269` `activity.share`）、浏览器（`:2270-2286` `ACTION_VIEW`/`ACTION_WEB_SEARCH`）、朗读（`:2036-2044`）、词典（`:2101-2104`）、正文编辑（`:2060-2063`）、AI 清洗（`:2070-2082`）、AI 改写（`:2084-2096`）、插入 BGM 前后（`:2106-2108`）。本地全仓：分享零 `systemShare`（`pages/BookInfoPage.ets:269` 自己也是「书籍分享尚未迁移」）、浏览器零 `startAbility` 且 `module.json5` 无 browser skill、朗读 `pages/ReaderPage.ets:1265` 明确「朗读播放尚未迁移」、词典/正文编辑/AI/BGM 零命中。**这些不是「补个菜单项」就能解决的**，各自依赖一整个未迁移的子系统，应按子系统推进，补齐后再在 `ReaderPage.ets:2067-2073` 挂入口。按项目约定不塞占位。

9. **目录页信息 tab 缺「备注」行**。上游 `ui/book/read/sheet/ReaderBookSheet.kt:531-533` 在信息页渲染 `book_remark`（`remark.takeIf { it.isNotBlank() }` 条件显示，排在书源与简介之间）。本地 `entry/src/main/ets/pages/CatalogPage.ets:330-346` 只有作者（`:334`）、书源（`:335`）、简介（`:336-338`）三行，**没有备注行**；但本地 `model/Book.ets:46` 的 `remark?: string` 字段是存在的，属「字段有、界面没渲染」。补法：在书源行后插一条 `if ((this.book.remark ?? '').trim().length > 0) { CatalogInformationRow({ label: '备注', value: this.book.remark ?? '' }) }`。

另：目录页**拆分超长章节**未接入，属目录能力而非本模块（上游 `TocScreen.kt:496 split_long_chapters` + `model/localBook/TextFile.kt:328-351` 按 `book.getSplitLongChapter() && chapter.end - chapter.start > maxLengthWithToc` 拆分子章、命名 `"$lastTitle(${index+1})"`，提示文案 `split_long_chapters_enabled`/`_disabled` 在 `TocViewModel.kt:825-826`）。本地 `entry/src/main/ets/model/Book.ets` 没有 `splitLongChapter` 字段、全仓零命中，开关无处落地；连带 r271 为目录页补的「章名为空回退第 N 章」在超长章节场景下会与上游子章命名不一致。

以上 9 项与「拆分超长章节」均为**只登记未实施**，本轮不改 `.ets` 代码。

### 2026-10-30 复核：核实「不是缺口」的三项

第二轮独立复核（用户要求重新确认书签/划线/笔记是否还有缺口）推翻了三条曾疑似缺口的判断，记录在此避免后人重复排查：

- **上游 `TocScreen.kt` / `TocRouteScreen` 全仓无调用点**（grep 只命中自身），那套 3-tab 目录页是未接线代码。上游真正在用的是 `ReaderBookSheet.kt:275` 的 4 tab。因此「本地目录页 4 tab vs 上游 3 tab」**不是缺口**，本地是自有设计。
- **目录页笔记条目点按进编辑 / 长按跳转**与上游阅读面板 `ReaderBookSheet.kt:1300-1304` 同口径（该处注释明写「与书签一致，点按进入编辑，长按跳转到标记位置」），不是缺口。
- **书签列表自动滚动**本地 `CatalogPage.ets:206-224` 用 `chapterIndex <= 当前章节` 取最后一个，与上游 `ReaderBookSheet.kt:1187-1194` 的 `indexOfLast { it.chapterIndex <= currentChapterIndex }` 完全一致，只是本地多了「只自动定位一次」的保护，不是缺口。

注意：③多选（`TocScreen.kt:325`）与④反序（`TocScreen.kt:447`）仍按缺口登记，理由是它们属「上游真实写过但未接线」的设计，补不补由用户定调；这与「tab 数差异不算缺口」并不矛盾。

## 阅读体验：翻页空白与开书排版跳变

本节登记两个用户可感知的阅读体验缺陷，**2026-11-02 已随「正文改画布逐行绘制」一起消除**。二者的根因都不是「某个开关没接」，而是渲染架构与上游不同——上游正文是画布逐行绘制（`feature/reader/ReaderCanvasSurface.kt`，3747 行 Compose `Canvas`，`:2049` `native.drawText(...)`），本地原本是 ArkUI 组件树逐字 `Span`。本地现已同构：`entry/src/main/ets/reader/ReaderCanvasSurface.ets` 用 `text.Paragraph` + `drawing.Canvas` 逐行绘制。

**状态口径（只有三值）**：KI-EXP1 **已接**、KI-EXP2 **已接**、KI-EXP3 **已接**。

### KI-EXP1 翻页出现整页空白（用户原话「差不多一页的空白才翻到另一页」）—— 已接

**原根因（历史记录）**：`ReaderPage.ets` 的 `turnReaderPage(delta)` 是「半程出、半程进」的整页替换，且只有一层内容在同一时刻存在。

```typescript
// 历史实现：前半程旧页滑出到 offset = horizontalTravel
animateTo({ duration: duration / 2, curve: Curve.EaseIn }, () => {
  this.pageTurnOffsetX = direction * horizontalTravel;
});
// 历史实现：中点切页 → 新页从反方向屏外滑入
this.pageTurnTimer = setTimeout(() => {
  this.currentPageIndex = nextPageIndex;
  this.pageTurnOffsetX = reverseDirection * horizontalTravel;
  animateTo({ duration: duration / 2, curve: Curve.EaseOut }, () => { this.pageTurnOffsetX = 0; });
}, duration / 2);
```

- 默认 `pageAnimation = 0`（cover）、`animationSpeed = 2` → `durationBySpeed[2] = 360`，即 180ms 出 + 180ms 进；`pageAnimation === 0` 时 `horizontalTravel = pageWidth`，旧页整页移出、新页整页自屏外移入，中间那一瞬两层都不在可视区。
- 切页必然整树重建（`ForEach` key 含 `currentPageIndex`），新页布局+字体测量耗时正好落在空白窗口里。
- `pageTurnAnimating` 只在 setTimeout 末尾复位，快速连点被吞。

**上游语义**：`feature/reader/core/transition/ReaderPageTransition.kt` 的 `transforms(mode)` 对 `COVER` 返回 `current = ReaderPageTransform(translationX = offsetPx)` + **`next = ReaderPageTransform()`（位移 0，就在原位）+ `currentOnTop = true`** —— 新页是静止的底页，旧页盖在上面滑走，屏幕全程有内容。

**已由上游实机视频佐证（2026-11-02）**：E 端在 Android 模拟器上采集的基准包（`<workspace>project-resources\legado-with-MD3\screenshots\android\reader-baseline-2026-11-02\`，仓库外不入库）里，`android-reader-animation-cover-frame-during.png`（翻页中间帧 1.55s）实测为**左右两页同屏**：左为旧页（页码 `1/11 27.3%`）正滑出，右为新页（页码 `2/11 29.5%`）已停在最终位置，画面无空白。同一批里 `android-reader-animation-slide-frame-during.png`（1.40s）则是**两页都在位移**——证实 COVER 与 SLIDE 是两套不同动作，本地曾把两者实现成同一套。采集基线与边界见 [VALIDATION](VALIDATION.md) 的「2026-11-02 Android 阅读界面基准包核对」节（`appDebug` / API 37 模拟器，不是 release 证据也不是 API 12 设备证据）。

**本地现状（已接）**：
- 翻页不再改节点树，而是改画布内部的 `turnTransition.offsetPx`：`ReaderPage.ets` 的 `turnReaderPage()` 用 `getUIContext().createAnimator(...)` 的 `onFrame(progress)` 逐帧调 `paintReaderCanvas()`，**`onFinish` 才改 `currentPageIndex`**。
- 位移全部由 `ReaderCanvasSurface.ets` 的 `ReaderPageTransitionPolicy.transforms(mode, transition, pageWidthPx)` 给出，与上游逐分支同式：COVER（`current.translationX = offsetPx` + `currentOnTop = true`）、SLIDE（另给 `next.translationX = width + offsetPx`）、FADE（`next.alpha = progress`）、折页（`ReaderPageCurl.ets` 的 `PageCurlGeometry`）、SCROLL（`ReaderScrollPolicy` 的 `pageStep` / `stepDurationMillis` / `apply` 逐项照 `ReaderScrollState.kt`，四页按 `scrollExtentPx` 堆叠后整体平移，画布内滚动）。
- 绘制前先按 `pageBackgroundArgb` 铺满整块画布，每个 slot 再各自 `fillPageSurface()` 铺纸面，**任何一帧都不会露出空白**。
- 时长一律经 `ReaderPageTransitionPolicy.settleDurationMillis()`（FADE 用整段基准、其余按剩余距离缩放），基准值来自 `animationSpeed` 索引 `[240, 300, 360, 540]`，与上游 `ReaderPageTurnSpeed.kt` 的四档一致。

**验收**：模拟器 `127.0.0.1:5555`（API 26）上五种转场（COVER / SLIDE / FADE / 折页 / 滚动）各连翻 20 页，每帧都有完整正文、无整页空白；滚动模式另验跨章 12 次翻页。详见 [VALIDATION](VALIDATION.md) 的「2026-11-02 N 端正文改画布逐行绘制」。

### KI-EXP2 开书时排版先乱 1-2 秒（用户原话「排版总是会先乱一秒两秒」）—— 已接

**原根因（历史记录）**：分页未就绪时走的是**另一套排版**，不是同一套排版的中间态。`ReaderPage.ets` 的分支 `if ((format === 'txt' || 'epub') && this.localReaderPages.length > 0 && pageAnimation !== 3) { 分页 } else { Scroll 整章连续铺开 }` —— 首帧 `readerContentWidth` / `viewportHeight` 初值都是 0，`rebuildReaderPages()` 一进来就清空分页返回，于是先渲染整章滚动，等尺寸到位再切分页。

**放大因素（历史记录）**：① 约 40 个 `@Prop` 共用 `onPaginationInputsChanged`，设置分几次到达就重建几次；② `Index.ets` 的 `restoreReaderSettings(context)` 是 async 且未 await；③ 尺寸三条到达路径都调 `rebuildReaderPages()`；④ 每次重建跑全章解析与高亮匹配；⑤ 带图章节缺图片尺寸就清空整章分页，走两轮「滚动 → 分页」切换。

**本地现状（已接，五条逐个消除）**：
1. 分页判据去掉 `localReaderPages.length > 0`，现在只要 `format === 'txt' || 'epub'` 就**一律进画布**（连续滚动模式也是同一张画布，不再有第二套 ArkUI 排版）。没有排好页时画布什么都不画（`ReaderCanvasRenderer.draw()` 开头 `window.current === undefined` 直接 return，注释点名上游 `ReaderCanvasSurface.kt:254` 的 `val current = pages.current ?: return`），**绝不换一套排版兜底**。else 分支的 `Scroll` 整章滚动已删除。
2. 约 40 个 `@Watch('onPaginationInputsChanged')` 现在只调 `scheduleReaderPaginationRebuild()`：`refreshReaderFontFamilies()` 立即执行，重建合并到 16ms 防抖窗口内只跑一次（`PAGINATION_DEBOUNCE_MILLIS = 16`）。
3. `Index.ets` 的 `ReaderPage` 外层加了渲染门控 `if (this.readerSettingsLoaded || this.route !== AppRoute.READER)`，设置没载入完时显示与阅读页同色的空白占位 + `LoadingProgress`，不再按初值先排一次错的。
4. 图片尺寸未就绪不再清空整章分页：`rebuildReaderPages()` 里用 `paginationImageSizes.set(part.value, { width: placeholderExtent, height: placeholderExtent })`（`placeholderExtent = max(1, lineHeight)`，对齐上游 `ReaderChapterBlockMeasurer.kt:457-462` 的占位口径），并置 `paginationUsesImagePlaceholder`；尺寸异步到达后只重排一次。
5. 画布侧新增 `syncReaderCanvasBodyHeight()`：`Canvas.onAreaChange` 把实测正文高写进 `readerCanvasBodyHeightVp`，分页时 `pageHeight = min(公式值, 实测值)`，保证「分页算得下」与「画布画得下」同源。

**验收**：冷启动 → `aa start` → 点书架进书，连续 6 次 `uitest dumpLayout` 每次都只有 `Canvas=1 Scroll=0`，**开书全程从未出现整章滚动分支**；详见 [VALIDATION](VALIDATION.md) 同节。

### KI-EXP3 改画布会连带失效的选区能力 —— 已接

**原风险（历史记录）**：本地选区完全依赖 ArkUI `Text` 的原生能力（`.copyOption(CopyOptions.InApp)`、`.onTextSelectionChange(...)`、`.bindSelectionMenu(TextSpanType.TEXT, this.readerMarkingSelectionMenu(), TextResponseType.LONG_PRESS, {...})`），正文改自绘后这些全部失效，阅读页会掉「长按选词、拖把手、标笔记」三项。

**本地现状（已接，按上游 `feature/reader/core/selection/` 六文件 503 行自绘）**：
- 几何：`ReaderCanvasRenderer` 把绘制拆成「先 `layoutPage()` 算几何、再逐元素画」，`ReaderCanvasPageGeometry` 记录每个 item 的 `left/top/widthPx/heightPx`，命中测试与绘制共用同一套坐标，不会漂移。
- 命中与选词：`hitTestTextBox(x, y)` → `glyphOffsetAt(box, x, y, style)`（`Paragraph.getGlyphPositionAtCoordinate`）→ `wordRangeAt(box, offset, style)`（`Paragraph.getWordBoundary` 取整词，空词退化成单字）。**偏移已贴到元素末尾时起点要回退一格**：否则 `start === end` 得到零长选区，`getRectsForRange` 拿不到矩形、两个把手也无处可放，表现为「长按有菜单但看不见选区、也抓不到把手」（`startCanvasSelectionAt` 里已处理）。
- 绘制：`drawSelection()` 用 `Paragraph.getRectsForRange(range, TIGHT, TIGHT)` 拿条带矩形，`drawing.Brush` 填 `0x63858585`（上游 `legacySelectionFill`），再用 `drawing.Brush` + `drawing.Pen` 各画一次 `drawCircle` 作两个把手（半径 7vp、描边 2vp，对齐上游 `SelectionHandleRadius`/`SelectionHandleStrokeWidth`）。
- 交互：`ReaderPage.ets` 的 `Stack` 挂 `LongPressGesture({ duration: 600 })` 起选（对齐上游 `LONG_PRESS_TIMEOUT_MILLIS = 600L`），横向 `PanGesture` 先 `canvasHandleHit()` 判把手命中，命中则拖 `dragCanvasSelectionTo()` 不翻页；`canvasSuppressTap` 标记吞掉长按抬手的那次 tap（对齐上游 `suppressTap`）。
- 坐标口径（三处，缺一就会「选区跑到屏幕外」或「抓不到把手」）：
  1. `drawPage` 只对**当前页**记几何（`recordGeometry`）和画选区（`drawSelection`），四页窗口里邻页一律不记——否则最后画的邻页会顶掉当前页坐标。（页层批次 2 后另有一份 `scrollWindowGeometry` 登记 current+next+nextPlus 供跨页命中，见本节末条；`this.geometry` 与把手端点仍只由 current 写，邻页只画条带不回填，本条口径不变。）
  2. 手指坐标换算 `canvasViewportY()`：`finger.localY` 相对外层 `Stack`，画布顶边用 `getComponentUtils().getRectangleById(CANVAS_ID).windowOffset.y` 与 `STACK_ID` 的同名值相减求得（两者同口径，状态栏自动抵消）；**不要**直接减 `Area.position.y`，它会漏掉父容器的页眉占位。
  3. 滚动模式下再减 `scrollOffset`：`canvasContentY()` = 视口 y − `vp2px(scrollOffset)`（`drawScrollSlot` 里是 `translate(0, scrollOffsetPx)`）。
- 把手几何与命中照上游 `drawPinHandle` / `handleHitRadius`：圆心在矩形 `bottom + radius`，竖线只画到矩形 `bottom`（不画到圆心），命中热区 28vp 且按「竖线顶端—圆心」胶囊中轴线求最短距离；拖动时端点跟**把手**走而不是跟手指走（记 `canvasHandleGrabOffsetX/Y`），再减 `radius` 回到行底做 `positionAt()`。
- 跨元素/跨行扩展：拖动取位用 `ReaderCanvasRenderer.positionAt(x, y, style)`，它在一行的**所有**元素间推进、超出最后一个元素就返回该行 `endPosition`；不能沿用单元素的 `glyphOffsetAt`（分页器会把一行按标点/样式切成多个小元素，单元素会被行末 clamp 住，选区再也扩不出去）。
- 把手淡入淡出：`animateCanvasHandleTo()` 用 `UIContext.createAnimator` 做真补间，淡出 90ms、淡入 140ms（对齐上游 `SelectionHandleFadeOutMillis` / `SelectionHandleFadeInMillis`），拖动时另一侧把手同时淡出。
- 菜单：菜单浮层 `Column(){ readerMarkingSelectionMenu() }.position(...)`，锚点由 `refreshCanvasSelectionMenuAnchor()` 按选区条带的 `selectionStartX/Y`、`selectionEndX/Y`、`selectionTopY/BottomY` 回填；沿用既有 `runSelectionMenuAction()`（复制 / 书签 / 划线 — 笔记）与 `createMarkingFromCurrentSelection()`。
- 清理：程序化翻页的 `animator.onFinish` 调 `resetCanvasSelectionState()`（对齐上游 `ReaderSelectionLifecyclePolicy.shouldClearForPageChange`）。
- 滚动模式跨页选区（页层批次 2 落地，完成态待验收方判定）：上游滚动模式 `ReaderSelection.kt` 的 `last = 2` 允许选区扩到 current+next+nextPlus，翻页模式 `last = 0` 只当前页。本地 `drawScroll` 在 `selectionStart >= 0` 期间按 `pageIndex` 把三页几何登记进 `scrollWindowGeometry`（复用 draw 期已算好的 `layoutPage()` 结果，不再排版），每帧覆盖登记以跟住自动滚动换 current；`positionAtScrollWindow(x, y, style)` 按内容坐标落在哪页的 `scrollContentTopPx..+scrollExtentPx` 区间选该页几何再做 `positionAtGeometry`，返回值仍是章内全局 `startPosition`，使 `[start,end]` 跨页连续。邻页 `drawScrollSlot` 传 `drawSelection=selectionActive` 让高亮条带跨过页交界，但 `reportHandles=recordGeometry=false`（只有 current 为真）——邻页 canvas 已 `translate(0, stackOffsetY)`，若回填 `selectionStartX/Y` 等端点会顶掉 current 的坐标，让菜单锚点与把手 hit-test 跑偏。`ReaderPage.ets` 的 `dragCanvasSelectionTo` 在 `usesCanvasScroll()` 时改走四页命中，翻页模式与「点划线」的 `handleMarkingTap` 仍走单页 `positionAt`。转场五档一行未动（预检 `git diff | grep -c "drawPageCurl|drawSlide|drawFade|drawCover"` = 0）。

**验收**：模拟器上长按出选区带 + 两个把手 + 浮动菜单；拖起始把手把选区从单字扩到两行、拖结束把手跨行；点「划线 — 笔记」面板回显完整选中文本并可保存，保存后正文出现绿色下划线；详见 [VALIDATION](VALIDATION.md) 同节。

### 顺带补回：高亮规则（正则命中的字色/底色/下划线）—— 已接

画布化时先只搬了「用户划线/笔记」（`markings`），`ReaderHighlightRule` 的正则命中样式一度完全没画——这是 Span 分支删除后的真实功能退化，2026-11-02 已补齐。

- 上游口径：`legacy/LegacyReaderStyleRangeMapper.kt` 的 `map()` 把启用规则按 `position` 升序展开成区间，`priority = index`；用户划线走 `priority = 10_000 + index` 压在高亮规则之上。
- 本地实现：`ReaderPage.ets` 的 `buildReaderCanvasHighlights()` 把 `readerHighlightRanges` 转成 `ReaderCanvasStyleRange`（`textColorArgb` / `backgroundArgb` / `decoration` / `decorationArgb`），再把 `markings` 里 `effect === 'text'` 的字色区间追加在数组末尾；`ReaderCanvasSurface.ets` 的 `splitStyledSegments()` 按区间端点切段、每段取「完全覆盖它的最后一个 range」，`getParagraph()` 用 `ParagraphBuilder.pushStyle / addText / popStyle` 逐段套样式。
- `underlineMode` 映射：`6 → LINE_THROUGH`、`1..4 → UNDERLINE`、否则 NONE；线型 `2 → DASHED`、`3 → WAVY`、`4 → DOUBLE`、否则 SOLID。
- 验收：设备上原本无高亮规则数据，用 UI 造了一条「文字颜色」划线（`uitest uiInput longClick 400 1000` → 菜单「划线 / 笔记」→ 样式「文字颜色」→ 保存），第 2 次翻页后屏幕上出现绿色字形像素（738 个，bbox `(392,2374)-(540,2440)`），确认分段样式确实下到了 `Paragraph` 并画出。**通过。**

### 已删除：默认参数把所有人推到最慢的渲染分支

原记录点名的 `ReaderPage.ets` 分支 `if (this.currentPageContainsImages() || this.readerBottomJustifyGap > 0) { ReaderPageTextLines } else { ReaderPageTextJoined }` 与 `textBottomJustify` 默认 true 导致每页新建 400-900 个 Span 节点的代价，**已随 Span 渲染分支整体删除而消失**：现在一页的绘制成本与行数线性相关，与默认值无关。`textBottomJustify` 的语义仍保留（画布下表现为 `ReaderCanvasLayout.bottomJustifyGapPx` 按行 y 摊分）。

### 滚动模式跨章换页顿挫：先量再削（2026-11-10 计时与取舍）

用户报 `pageAnimation = 3` 下滚到章末继续下滑进下一章时会顿一下。本轮先补 `[ReaderBench]` 计时（提交 `75ee736`），再按测量结果决定两处削减（提交 `8cde93c`、`ccad0cc`），逐场景耗时与原始 hilog 见仓库外 `<workspace>tmp/reader-handoff-evidence.md`。

**时间花在哪**：三个场景（首次进下一章 / 同一章末第二次 / 往回上一章末页定位）各测 3 轮取中位数，真 `LocalReaderPaginator.paginate`（日志字段 `paginatorMs`）为 57 / 60 / 48 ms，分别占 `contentChanged totalMs` 77 / 79 / 57 的约 75%；`contentMs`（整本正文缓存读盘）= 0、`applyMs`（替换规则 taskpool 往返）= 0~1、`semanticsMs`（语义解析 + 高亮扫描）= 0~1、`renderMs`（定位 + 钳位 + 预解图 + 重绘）= 7~16。任务给的日志模板里 `paginateMs` 实为语义段（1~2 ms），`positionMs` 才是含真 paginate 的大头，故另补 `paginatorMs` / `renderMs` 两个字段判定——按模板字面 `paginateMs` 不是最大项，按「整章同步排版是大头」的意图成立。

**批 2（滚动模式不启动全书分页）**：默认配置下 `needsFullBookPageData()` 恒 false（`DEFAULT_READER_INFO_SETTINGS` 六个页眉页脚值 1,0,2,7,0,6 都不是 19/20/18，设备 prefs 无覆盖），全书分页本就不启动，该改动对默认配置是 no-op。注入 `<double key="tipFooterRight" value="20.000000"/>` 构造触发配置后：滚动模式 `fullBookPagination skipScroll=1 needs=1` 且无 `started`；分页模式 `skipScroll=0 needs=1` 且出现 `started gen=...`，底部 `17/41 33.3%`，进度条数值未坏。三场景 `contentChanged totalMs` 由批 1 的 77 / 79 / 57 到批 2 的 70 / 72 / 51，差在冷启动与调度抖动范围内，不构成可测下降。

**批 3（换章不重复排版）—— 判定「不需要做」，理由**：任务假设「`loadContentImageSizes()` 回来触发 `rebuildReaderPages(true, true)`，含图章整章排两遍」。实测不成立：`primeContentImageSizesSync()`（`ReaderPage.ets:1604`）在首次排版前已用 `getImageInfoSync()` 同步量好本章图片尺寸，注释 `:4792-4802` 明写「排版期就用真实尺寸，不再有二次重排」；`loadContentImageSizes()` 只在有未量到尺寸的新图片段时 `changed=true` 才走 100ms 防抖重排，纯文字书与含图书实测都是 `imageSizesReloaded rebuildAgain=false`。含图书（`爱情潮湿`，含 2 个 `[[EPUB_IMAGE:...]]` 段、1 章）与纯文字书（`yushen`）各测一次，结论一致：不存在由图片尺寸触发的 `onlyImageSizesChanged=true` 二次重排，故按任务 3.2「若没有触发，这一批直接标不需要做」不做等待 150ms 的改动。

**与任务断言不符处（如实登记，不是「未做」）**：换章确有 2 次全量 `rebuildReaderPages()`（两次都 `onlyImages=false reuseSemantic=false`），但来源不是图片尺寸路径——实测 `imageSizesReloaded rebuildAgain=false`、无 `canvasHeightRebuild`、无 `debouncedRebuild`，且 `titleChangedRebuild` 恰好紧跟在第 2 次 rebuild 之前。链路是 `Index.selectChapter` 一次性赋多个 `@Prop`：`content` 的 `@Watch` 触发 `onReaderContentChanged()` 首排（第 1 次），`chapterTitle` 的 `@Watch` 经 `refreshDisplayChapterTitle()` 异步定稿后赋 `displayChapterTitle`，其 `@Watch` `onDisplayChapterTitleChanged()` 无条件再排一次（第 2 次）。`onChapterTitleChanged():1496-1498` 的注释已点明「两处都排就是同一章排两遍」。消除它要改标题块定稿与页表一致性，风险超出本批「图片尺寸等待」的授权范围，本批未改；真 paginate 与这 2 次 rebuild 都仍在。

**主观判断（三档之一）**：设备上做 5 次换章观测，每次 `contentChanged totalMs` 为 70 / 68 / 69 / 73 / 101 ms，每次仍是 2 次全量 rebuild。**改善不明显**——换章那一帧的真 paginate（约 48~60 ms）与第 2 次 rebuild 都未被削掉。实测手数：5 次换章。

**测量手法偏离**：任务要求用「滚到章末继续下滑」的手势触发。`uinput -T -g 640 2400 640 200 600 9000`（press=600）触发 `LongPressGesture` 选区菜单；改 press=500 与 `uitest uiInput swipe` 都进不了 ArkUI `PanGesture.onActionUpdate` 逐帧通道，滚不到章末。改用向 prefs 注入 `bottomActions` 打开 `prev_chapter` / `next_chapter` 按钮，点按钮走 `onTurnChapterBoundary(±1)` → `selectChapter(..., delta < 0 ? 100 : 0)`，与滚过章末是同一条 `selectChapter → onReaderContentChanged → rebuildReaderPages` 同步链路，且能覆盖场景 3 的 `initialProgress = 100` 末页定位分支。运行时确认是滚动模式（prefs `pageAnimation=3.000000`、设置面板「滚动」高亮、底部 `33.3%` 符合 `getWholeBookProgress()` 滚动分支）。

**文档改判结论**：`grep -rn "顿挫\|换章\|跨章" docs/parity/TXT-READER.md docs/KNOWN-ISSUES.md` 命中的行讲的是 KI-REL1 空窗/闪烁、B8 增量分页能力、跨章边界占位页与跨章定位，没有描述「换章那一帧排版耗时」且状态因本轮改变的行；B8「增量分页 / 正文三槽 / 邻章页直接发布」等行判 `未接`，本轮未实现这些能力，状态一律不改判。按任务 4.3「没有相关行就不要硬加」不动 TXT-READER.md 表格状态列（避免破坏 parity-pipes / parity-rows），只在本文件追加本条如实记录。

## 阅读进度与章首定位

本节登记 2026-11-02 修复的四个阅读缺陷：**阅读进度不落库（开书回章首）**、**目录跳章自激循环**、**带图章节图片尺寸到达后整章重排 N 次**、**折页阴影偏移疑点**。前三项已改并设备验收（见各条「验收」），第四项经比对上游源码判定**不是缺陷、不改**。

### KI-PROG1 每次开书都回到章首，读到的页数不记录 —— 已修

两处叠加，缺一不可：

1. **`Index.ets` 的 `openBook()` 无条件把「从本章开头读」置真**。该标志 `readerStartAtChapterBeginning` 的语义应是「用户主动要求从本章开头重读」，`Index.ets` 里书签跳转（`:1718`、`:1952`）与 `selectChapter`（`:6163`）都赋 `false`，只有 `openBook()` 赋了 `true`，于是每次进书都强制丢掉章内进度。改为 `false`。
2. **`BookRepository.ets` 的 `readBookRow()` 漏读 `androidCharacterPosition`**。`books` 表第 7 列（索引 6，`durChapterPos`）存的是章内字符位置，`readBookRow()` 却把它读进 `chapterProgress`，导致 `ReaderPage.ets:1602` 的 `const savedPosition = Math.max(0, this.book.androidCharacterPosition ?? 0);` 恒为 0。写入侧 `Index.ets:5980` 的 `updateReadingProgress` 一直是好的，坏在 `toBookArgs()` 第 25 列写的是 `chapterProgress`（章内百分比 0-100），把两个语义不同的量塞进了同一列。

修法：`StoredReadConfig` 加 `chapterProgress?: number`，百分比随 `readConfig` JSON 一起存（`durChapterPos` 只有一列，`readBookRow` 是同步函数拿不到章长、算不出百分比）；`durChapterPos` 回归字符位置。**兼容存量**：`readConfig` 里有 `chapterProgress` 键的才是新格式，没有的是旧行（那时 `durChapterPos` 存的是百分比，当字符位置用会把 2% 读成「第 2 个字符」），旧行留 `undefined`、渲染侧仍按百分比定位。

- 验收：设备 the-metamorphosis 翻到 `5/17 2.3%` → 退出 → 重开仍是 `5/17 2.3%`（修前是 `1/9 0.1%`）；zh-book 翻到 `3/10 2.7%` → `aa force-stop` 杀进程 → 冷启动 → 仍是 `3/10 2.7%` 标题「第15章 对练」。**通过**（三级口径第 3 级）。

### KI-PROG2 从目录跳章自激循环 —— 已修

完整链路（`@Watch` 互相触发，`titleGeneration` 只挡 `displayChapterTitle` 赋值，挡不住 `onReplaceRulesRefresh` 本身）：

```
onChapterTitleChanged()
  → refreshDisplayChapterTitle()
    → onReplaceRulesRefresh()
      → Index.ets:6674  this.replaceRules = ReplaceRuleRepository.getAll()
        → ReplaceRuleRepository.ets:97-99  cachedRules.map(copyRule)   // 每次都是新数组引用
          → @Prop @Watch('onReplaceRulesChanged') replaceRules（ReaderPage.ets:156）
            → onReplaceRulesChanged()
              → refreshDisplayChapterTitle()   // 回到起点
```

修法两处：`refreshDisplayChapterTitle()` 里删掉 `this.onReplaceRulesRefresh();`；`onChapterTitleChanged()` 里删掉 `this.rebuildReaderPages();`（末尾 `refreshDisplayChapterTitle()` 赋值 `displayChapterTitle` 会触发 `onDisplayChapterTitleChanged()` 再排一次，两处都排就是同一章排两遍）。

- 验收：13 章的 the-metamorphosis 连续从目录跳第 8–13 章，每次标题正确、`pidof` 恒为同一进程未变。**通过**（三级口径第 3 级）。
- **边界**：`replace_rules` 表 0 条时 `getAll()` 返回空数组、`applyTitle` 是 `async` 会让出事件循环，所以这个自激循环在当前数据下不会真卡死 —— A/B 对照（stash 改动后重新构建装机）在 13 章书上跳章同样正常。改动去掉的是确定存在的自激回路，**「跳章卡死」这个现象本身在本机复现不出来**。
- **另有一处既有缺陷不算在本条**：zh-book 有 572 章，打开目录页必 ANR（`/data/log/faultlog/faultlogger/` 里 `appfreeze-...` 全部 `Reason:THREAD_BLOCK_6S`，主线程栈只有 `BCStub_HandleLdaV8StwCopy` / `BCStub_HandleMovV4V4StwCopy`）。基线（stash 改动）同样 ANR，根因是 `CatalogPage.ets:281 loadChapterWordCounts()` → `BookRepository.forEachChapter()`（`BookRepository.ets:1447`，逐章 `applyChapterContentAsync` 全文处理）在 572 章上的全量遍历。**该缺陷已在 KI-PROG5 修复**。

### KI-PROG5 大目录（上千章）打开目录页必 ANR —— 已修

两处叠加，都在 `CatalogPage` 打开时同步占用界面线程：

1. **`loadChapterWordCounts()` 没把 `chapterRows` 传给 `forEachChapter()`**。`BookRepository.forEachChapter(book, cb, useReplaceRules, chapters = [])` 的 `chapters` 默认是空数组，不传时 `BookRepository.ets:1458` 走 `chapters.length > 0 ? chapters : deriveChapters(book, content)` —— 即对 8.4MB 全书正文**再跑一遍目录规则正则**（`splitChapters` → `TxtTocRuleRepository.splitChapterStarts`），只为拿回一份调用方手里早就有的章节行。
2. **`chapterBody()` 逐章调用 `byteOffsetToCharIndex()`**。这个函数每次从全书开头逐字符累加字节宽度直到命中目标偏移，`forEachChapter` 的循环里每章都要调两次（start、end），1378 章就是 **O(N²)**：平均每章扫半本书约 42 万个字符，合计约 **11.6 亿次字符迭代**，全部在界面线程上同步执行。

对照实验（决定性证据）：把 preferences 里 `tocCountWords` 改成 `false` 关掉字数统计后，1378 章的目录**立刻正常渲染**（`共 1378 章`，进程存活）；改回 `true` 就必被杀。说明卡死来自字数统计这条路径，不是目录本身渲染。

修法两处：

- `CatalogPage.ets` 的 `aboutToAppear()` 改为在需要统计字数时走新增的 `loadChapterWordCountsAfterRows()`：先 `await this.loadChapterRows()`，确认 `chapterRows.length > 0` 后再 `await this.loadChapterWordCounts()`；`loadChapterWordCounts()` 里的 `forEachChapter` 补传第四个参数 `this.chapterRows`。**两处缺一不可** —— 只补传参不串行等待，`chapterRows` 那时还是空数组，仍然会退回 `deriveChapters()`。
- `BookRepository.ets` 新增 `byteOffsetsToCharIndices(content, byteOffsets, encoding)`（一次顺序扫描换算一组递增的字节偏移，写法与既有的 `charOffsetsToByteOffsets` 同构）与 `sequentialChapterRanges(content, rows, encoding)`（预先算出每章字符区间，任一行缺 `start`/`end` 就返回 `undefined` 让调用方退回逐章换算）；`chapterBody()` 增加可选参数 `charRange`，`forEachChapter()` 在循环前算一次区间表再逐章传进去。`chapterBody()` 的原有逐章换算路径保留，增量导入等只处理少数章节的调用方行为不变。

- 验收（三级口径第 3 级，**通过**）：
  - 1378 章的 `EPUB 测试用书`：点目录到 `共 1378 章` 渲染完成 **6461 ms**（修复前必被杀），章节标题与右侧字数（`2179字` / `2108字` …）全部正常显示，目录滚动流畅，`pidof` 全程 13273 未变。
  - 连续 5 轮从目录跳章：目标章节与实际落地章节逐轮一致（第19章 / 第24章 / 第29章），进程始终存活。
  - 572 章的 zh-book（修复前必 ANR）：目录 **2522 ms** 打开，跳第 21 章成功，`pidof` 14043 未变。
  - `/data/log/faultlog/faultlogger/` 最新一条 `appfreeze-...` 停在 **14:56**（修复前那一轮），之后整轮验收（15:00 起）**没有再产生任何新的 appfreeze 日志**。

### KI-PROG3 带图章节图片尺寸到达后整章重排 N 次 —— 已修

`loadContentImageSizes()` 原本每读到一张图的尺寸就调一次 `rebuildReaderPages()`，而 `rebuildReaderPages()` 每次都做 `LocalTextSemantics.parse(全章)` + `ReaderHighlightRuleEngine.findBodyRanges(全章)` + 全量分页。带 N 张图的章节就是 N 次全章解析 + N 次全量分页。

修法：`rebuildReaderPages(forceProgressCommit = false, onlyImageSizesChanged = false)`，第二个参数为真时复用 `this.localSemanticDocument`、跳过语义解析与高亮区间重算，只重排；`loadContentImageSizes()` 改为走新增的 `scheduleImageSizesPaginationRebuild()`（100ms 防抖，复用 `scheduleReaderPaginationRebuild()` 的定时器，`paginationRebuildDelayMillis` 用后复位成 16ms），一批尺寸一起到达只重排一次。

- 验收：带图 EPUB（`EPUB 测试用书`，1378 章）开书到可读时间，改后 3645 / 4046 / 3981 ms，基线 3982 / 4131 / 4029 ms，**在测量噪声内、无可测退化**。**通过**（三级口径第 3 级，口径是「不退化」而非「变快」——这本 EPUB 全书只有 1 张图，N=1 的路径本来就只重排一次，收益体现在多图章节，本机没有可用样本）。

### KI-PROG4 折页阴影 `25 * 1.414` 疑点 —— 经比对上游源码，不是缺陷，不改

`entry/src/main/ets/reader/ReaderPageCurl.ets:340-341`：

```typescript
const shadowX = frame.touch.x + 25 * 1.414 * Math.cos(angle);
const shadowY = frame.touch.y + (reverse ? 1 : -1) * 25 * 1.414 * Math.sin(angle);
```

**上游逐字原值**，不是本地自拟：`<workspace>legado-with-MD3\app\src\main\java\io\legado\app\feature\reader\ReaderCanvasSurface.kt:2583-2585` 写的就是

```kotlin
val shadowX = (frame.touch.x + 25f * 1.414f * cos(angle)).toFloat()
val shadowY = (frame.touch.y + (if (reverse) 1 else -1) * 25f * 1.414f * sin(angle)).toFloat()
```

同一类里其余也逐行一致：`reverse` 判据、`angle` 的 `PI/4 - atan2(...)`、`front` / `reveal` / `back` 三个路径的顶点序列、`mirror` 的 scaleX/skewX/skewY/scaleY/translateX/translateY 公式、`frontShadowHorizontal` / `frontShadowVertical` 的楔形顶点。阴影色也一致（上游 `PageCurlGeometry.kt:47-49` 的 `0x99111111` / `0x4D111111` / `0x73333333` ↔ 本地 `ReaderPageCurl.ets:68-70` 的 `BACK_SHADOW_DARK_ARGB` / `FRONT_SHADOW_DARK_ARGB` / `FOLDER_SHADOW_DARK_ARGB`）。**结论：不改。**

- 观感差异仅在于宿主绘制 API 不同（上游 Compose `drawRect(Brush.horizontalGradient(...))`，本地 `drawing.Brush.setShaderEffect(drawing.ShaderEffect.createLinearGradient(...))` + `canvas.rotate()`），`drawCurlBackShadow` / `drawCurlFolderShadow` / `drawCurlFrontShadows` 三个函数的几何参数已与上游同构。基准包 `android-reader-animation-simulation-frame-during.png`（1080×2400）里折页是右上角一条细暗带，与本机抓到的折页中间帧方向、位置一致。

### KI-SCROLL1 滚动模式拖拽方向相反、量纲错、跨页收口未实现 —— 已修

连续滚动模式（`pageAnimation === 3`）下手指向上滑，内容跟着向上走但只走一点点就停；换页永远不触发。三个错误叠在同一条路径上：

1. **方向符号反了**。`dragReaderScrollBy()` 里 `const next = Math.max(0, Math.min(total, this.scrollDragStartOffset - offsetYVp));` 的减号是错的。`offsetPx = 0` 表示当前页顶边对齐视口顶边，`deltaPx` 为负才是内容上移（往后读）；ArkUI `PanGesture` 的 `offsetY` 手指向下为正，与上游 `ReaderCanvasSurface.kt:1333-1342` 直接拿 `moveDelta.y` 当 delta 同口径，不该取负。
2. **钳制量纲错**。`scrollOffset` 的正常值域是 `[-currentExtent, 0]`，而 `total` 来自 `readerScrollTotalHeight()`（整章内容高减一屏），不是同一量纲。只改符号不修夹取，位移会被 `Math.max(0, …)` 钳成 0，表现为「手指向上滑完全没反应」。
3. **跨页收口从未实现**。`onActionEnd` 只有 `this.updateProgress();`，注释却写着「跨页要等抬手后的 applyReaderScrollDelta 收口」——那条调用根本不存在。

修法：删掉 `dragReaderScrollBy()` 与字段 `scrollDragStartOffset`，换成 `scrollDragLastY`；纵向 `PanGesture` 的 `onActionUpdate` 把 ArkUI 的累计 `offsetY` 换算成逐帧 delta 后直接调 `applyReaderScrollDelta(vp2px(delta))`（它内部负责换页、`refreshReaderBottomJustifyGap()` 与重绘），`onActionEnd` 保持只 `updateProgress()`。

- 验收：纯观测（不点击）下手指上滑 200 px，正文条带位移 `-198 px`、`residual=0.05`，正文文本顺序同步前进；连续 8 次上滑可正常跨页；退出重进保持 `17/17`；分页模式横向翻页与滚动模式长按选词均不受影响。**通过**（三级口径第 3 级）。

**抬手惯性 fling —— 已接**（2026-11-02 第二批）。上游 `ReaderCanvasSurface.kt:1414-1452` 用 `animateDecay(velocity, scrollDecay)` 做松手后的减速滑行，本地补了同形状的指数衰减：`ReaderPage.ets:2122` 的 `startReaderScrollFling(velocityYVpPerSecond)` 配 `ReaderCanvasSurface.ets` 的 `ReaderScrollDecay`（`DECAY_RATE_PER_SECOND = 3.3`、`DURATION_MILLIS = 1200`，位移 `v0/λ·(1-e^(-λt))`），撞章边界立即停。滚动 PanGesture 的 `onActionEnd` 现在是 `this.updateProgress(); this.startReaderScrollFling(event.velocityY ?? 0);`。

- 验收：滚动模式下快速上滑一次松手，页码从 `14/17` 自动滑到 `12/17`（抬手后继续滑过 2 页）✔。

### KI-SHELF1 书架网格与无封面文字封面与上游的差异 —— 已对齐

书架原先有两组与上游不一致的地方，本轮全部对齐。上游基准：`ui/main/bookshelf/BookItem.kt`（网格项与封面容器）与 `ui/widget/components/image/cover/CoilBookCover.kt`（无封面时的文字封面）。

**A 部分：书架网格**

| # | 差异 | 修法 |
|---|---|---|
| 1 | 封面是固定 70×100 的小块，不填满格子 | `BookCover` 新增 `fillWidth` / `maxWidth`：宽取格子可用宽，高按 **5:7** 算，对齐上游 `BookItem.kt:271` 的 `aspectRatio(5f / 7f)` |
| 2 | 卡片左对齐、标题也左对齐 | 卡片 `alignItems(HorizontalAlign.Center)`；标题 `width('100%')` + `textAlign` 由新字段 `bookshelfTitleCenter` 决定（默认 true，对齐上游 `BookshelfGridItem` 的 `titleCenter = true`） |
| 3 | 网格间距写死 `rowsGap(16)` / `columnsGap(10)` / 左右 padding 14 | 统一成常量 `BOOKSHELF_GRID_GAP = 8` / `BOOKSHELF_GRID_PADDING = 8`，对齐上游 `BookshelfScreen.kt:1748-1772` 的 `spacedBy(8.dp)` + `horizontal = 8.dp` |
| 4 | 标题没有内边距、字号写死 13 | 标题 `padding({ left: 4, right: 4, bottom: 4 })`（上游 `padding(start = 4.dp, end = 4.dp, bottom = 4.dp)`）；字号由新字段 `bookshelfTitleSmallFont` 在 11（`labelSmall`）与 13（`labelMedium`）之间切 |
| 5 | 没有封面宽度设置 | 新增 `bookshelfGridCoverWidth`（默认 120）/ `bookshelfListCoverWidth`（默认 84），对齐上游 `BookshelfSettingsRepository.kt:82-83`；布局面板补「网格封面宽度」「列表封面宽度」两个步进器 |

**B 部分：无封面书的文字封面**

| # | 差异 | 修法 |
|---|---|---|
| 1 | 无封面时只显示一个书名首字 | 改成 `Canvas` 逐字绘制完整书名与作者，排版规则复刻上游 `CoilBookCover.kt`：书名 `w/8` 粗体、作者 `w/12`；竖排起点 `w*0.16 / h*0.16`、作者列 `w*0.84`；横排书名 3 行、作者居中 `h*0.75`；拉丁文占比 > 0.3 时强制横排（`CoilBookCover.kt:505-509`） |
| 2 | 没有居中书本图标 | 无封面时居中叠 `AppGlyph('book')`，占封面 35%，对齐上游 `CoilBookCover.kt:210-218` 的 `fillMaxSize(0.35f)` |
| 3 | 竖排/横排不可选 | 新增 `infoOrientation`（`'0'` 竖向 / `'1'` 横向），封面设置页可切 |
| 4 | 没有文字颜色、描边、阴影设置 | 新建 `data/CoverSettingsRepository.ets`，12 个字段与上游 `CoverSettings.kt` 逐项对齐（`showShadow` 默认 false、`showStroke` 默认 true、`useDefaultColor` 默认 true、日/夜两套文字色与阴影色、显示书名/作者开关） |
| 5 | 封面设置页是静态占位，改了不生效 | `AppCoverSettingsPage` 整体重写为受控页面，改动经 `Index.saveCoverSettings` 落 `legado_cover_settings` preferences 并即时回传书架 |

**模型裁剪（有意为之）**：本地没有 EInk 形态，上游 `ReadStyleItem` / `CoverSettings` 里与墨水屏相关的字段不引入；`CoverSettings` 只保留实际会参与绘制的那 12 项。

**踩到的坑（已修，留作记录）**：

- **`Canvas` 文字量纲**：`CanvasRenderingContext2D` 的 `context.width/height` 与绘制坐标同为 vp，但 `context.font` 字符串里的 `px` 是**物理像素**。一开始把 `onAreaChange` 拿到的 vp 宽度直接当像素算字号，字号小了 density 倍（本机 3.47），文字缩成一条条细线。正确写法是排版用 vp、写 `font` 时经 `vp2px()` 换算，`lineWidth` 保持 vp 量纲（换算成像素会粗一个 density 倍，字糊成一团）。
- **竖排基线**：第一字的 y 就是起点本身，不要再加一个字号（加了整体下移一格）。
- **日/夜文字色**：深色主题下生效的是 `*Dark` 那套，改日间颜色看不到变化，容易误判成「设置无效」。

**验收（第 3 级）**：A 部分 ①封面填满 5:7（3 列时 361 px 宽）②卡片与标题居中 ③间距 8/8/8 ④标题 padding 与 11/13 字号切换 ⑤封面宽度 50/200 生效且 200 时居中不撑满（694 px = 200vp × 3.47）✔；B 部分 ⑥无封面书显示图标 + 竖排书名/作者 ⑦竖向/横向切换 ⑧显示书名/作者开关（关书名时作者同隐）⑨文字颜色与阴影生效且冷启动保持 ✔。

### KI-STYLE1 背景样式区与上游的五处差异 —— 已对齐（含样式可增删）

全局设置页「背景」样式卡行原先与上游 `GlobalThemePage.kt` 的背景样式区有 5 处差异，本轮全部对齐：

| # | 差异 | 修法 |
|---|---|---|
| 1 | 选中态是卡片下方的小勾图标 | 改成**底部满宽横带 + 勾**（`ReaderSettingsPage.ets` 的 `BackgroundOption`：外层 `Column` 内分两段，下半段 `height(12).backgroundColor('#C6D3FF')` 里放 10×10 的勾），对齐上游 `StyleCard` 的 `Box(align BottomCenter, fillMaxWidth, height 12.dp)` |
| 2 | 没有「+」新增样式卡 | `ForEach` 之后追加 `BackgroundStyleActionCard($r('app.media.app_add'))` → `onAddBackgroundStyle()` |
| 3 | 没有最右侧主题列表入口卡 | 追加 `BackgroundStyleActionCard($r('app.media.reader_arrow_forward'))` → `openDetailSheet('主题列表', ...)`（本仓没有 chevron_right 图标，用等价的右箭头） |
| 4 | 样式卡只有 `onClick` | 加 `LongPressGesture({ duration: 500 })` → 选中该份 + `openDetailSheet('编辑背景样式', ...)`，对齐上游 `StyleCard.onLongClick → onOpenBgTextConfig` |
| 5 | `READER_BACKGROUND_STYLES` 是硬编码 6 条常量，不可增删 | 改成持久化的样式表（见下） |

**样式表模型**：`ReaderSettingsSnapshot` 新增 `backgroundStyles: ReaderBackgroundStyle[]`，随 `legado_reader_settings` 一起存（键 `backgroundStyles`，值是 JSON 字符串）。`ReaderBackgroundStyle` 在原有 `name`/`dayColor`/`nightColor` 之外补了 `id`。

- 上游 `ReadStyleItem` 还带 `bgType` / `textColor` / 三个 `*EInk` 字段，本地**故意不搬**：本地背景类型（`bgType`/`bgTypeNight`）与文字颜色是全局单份，不随样式独立，搬过来会让同一份状态有两个来源。
- `READER_STYLE_PRESET_COUNT = 5`（对齐上游 `ReadStyleState.kt:41`）。默认表仍是 6 条（上游 `readConfig.json` 就是 6 条），所以第 6 份「预设5」与上游一致地算**自建、可删可移**。
- `paperIndex` / `dayPaperIndex` / `nightPaperIndex` 的语义从「6 个内置方案的下标」扩成「样式表下标」，原来写死 `Math.min(5, ...)` 的四处（`ReaderSettingsRepository.save()` 三处、`clampStyleIndex`、`Index.setReaderPaperIndex`、`Index.getPaperColor`）都改成按 `backgroundStyles.length - 1` 夹取。
- 新增样式的背景**整组回默认纯色**（日间 `#EEEEEE`、夜间 `#000000`，即上游 `ReadBookConfig.Config()` 的构造默认值）、名字留空，对齐上游 `ReadBookConfig.asNewStyle()` 的「复刻排版但不继承背景图」；空名字在卡片上回落显示「背景样式」（上游 `StyleCard` 的 `ifBlank`）。
- 增删排序语义全部照上游：`removeReaderBackgroundStyle` 只允许 `index >= READER_STYLE_PRESET_COUNT`，删后 `paperIndex` 按「删的那份取前一份、之后的左移一位」修正；`moveReaderBackgroundStyle` 只在自建区内生效，下标按上游 `shiftIndexAfterMove` 的 `index==from→to; from<index<=to→index-1; to<=index<from→index+1` 修正。

**踩到的两个坑（已修，留作记录）**：

- `ForEach` 的 key 一开始用 `style.id`，于是**改名/改色后卡片不刷新**（id 没变，ArkUI 认为子项未变，界面一直显示旧名字，要重启才更新）。改成 `${style.id}|${style.name}|${style.dayColor}|${style.nightColor}` 后即时生效。
- 主题列表行里把 `.layoutWeight(1)` 写在名字 `Text` 上，会把 `Column` 撑高、名字与「预设/自建」标签被拉开一大截。`layoutWeight(1)` 要放在 `Column` 上并配 `justifyContent(FlexAlign.Center)`。

**验收（第 3 级）**：①选中态横带+勾 ✔（截图 crop `(100,2150,1280,2400)`）②「+」卡 ✔ ③「>」卡 ✔ ④长按开「编辑背景样式」✔ ⑤新增样式（卡片显示「背景样式」）✔ 删除自建样式 ✔ 上移排序 ✔ 改名后卡片即时更新 ✔ 冷启动后样式表与选中项保持（preferences 里 `backgroundStyles` 7 条、`paperIndex` 指向自建那份）✔。

## 关系型存储迁移第五批（r284）遗留

本节登记 2026-10-30 第五批（preferences 老数据清理）设备验收后仍待处理的三项。**第 1 项已于 r290 修掉，保留记录备查；第 2、3 项仍未处理。**

1. ~~**`RdbCleanup` 漏删两个键**~~ —— **已于 r290 修掉**。`legado_read_records` 里的 `details_v1` 与 `summaries_v1` 在 r284 清理时未被删除（当时只删了 `sessions_v1`），这两个键存的是第三批之前的老格式「按日明细」与「书籍汇总」，第三批起已改存 `readRecordDetail` / `readRecord` 两表，全仓 `.ets` 已无读取点（`grep -rn "details_v1\|summaries_v1" --include=*.ets` 零命中）。r290 的修法两处同时做：`entry/src/main/ets/data/RdbCleanup.ets` 的删除清单改为 `['sessions_v1', 'details_v1', 'summaries_v1']`；同文件 `markerKey` 由 `rdb_cleanup_v1_1` 提到 `rdb_cleanup_v1_2`——**只改第一处无效**，因为标记已写的设备不会重跑清理。详见[验证记录](VALIDATION.md)的「r290 修补」。

2. **书签与划线的设备验收在模拟器上走不通**。`bookmarks` 与 `book_marks` 在第五批验收中始终为 0 行，新代码下的写入路径未经验证。已验证可行的入口是：进阅读页 → 长按正文 → 选词菜单（复制 / 书签 / 划线·笔记，y 366–493）→ 点「书签」→「添加书签」面板 → 保存。但该手势在模拟器上极不稳定：本轮只在首次成功一次，之后 12 次循环探测、5 个不同纵坐标（900/1200/1500/1800/2100）、重启、双击、慢速拖拽、`uinput -T` 触摸轨迹、菜单开合状态下长按均无法复现；且**首次成功那一轮点「保存」落在了面板外**（面板关闭但未入库），保存按钮的准确 bounds 从未 dump 到。注意 `uitest uiInput longClick` 稳定返回 `No Error` 却不保证手势被应用识别，返回码不能当成功依据。这与 r281 节的既有结论一致（正文走滚动模式，长按划词在模拟器上一直不可靠），**不是本次改动引入的问题**。后续两条替代路径：① 数据层直接构造标记行 + 渲染像素比对（r281 验证划线渲染用的就是此法，做过「改 DB 颜色 → 界面由黄变红」的决定性验证）；② 改在真机上走完整 UI 闭环。另注意底栏默认只启用 `['search','autoPage','catalog','voice','settings']`（`entry/src/main/ets/data/ReaderSettingsRepository.ets:292`），`addBookmark` 不在其中，所以底栏没有书签按钮，长按选词是唯一入口。

3. **按书净化开关的冷启闭环未验**。`book_overrides_v1` 已搬进 `books.readConfig.useReplaceRule`，读写路径已构建通过（设备实测两本书的 `readConfig` 为 `{"reSegment":false,"fixedType":false}`，无 `useReplaceRule` 键，符合「未设置 = 跟随全局默认」），但「关掉某一本书的净化 → 冷启 → 仍关闭」这条闭环没有上机走。验收要点：关闭后 `books.readConfig` 应出现 `"useReplaceRule":false`，重启后阅读该书的替换仍不生效，重置后该键应重新消失。

## 阅读配置行登记（READER-CONFIG.md 的未接行）

本节登记 [READER-CONFIG 对照表](parity/READER-CONFIG.md) A–G 块里 **11 行 `未接`** 的「为什么不修」。编号 `KI-<块><组>` 与对照表「备注」列的标记一一对应，组内逐行列出覆盖的对照表行。**本节只登记不实施，本轮不改 `.ets` 代码。**

> 数字沿革：本节最初写于 r297，当时是 97 行 `未接`；r300–r316 深色模式与阅读配置各批落地后，实测已降到 **11 行**（189 行 = 176 已接 / 11 未接 / 2 不适用，用 `python scripts/reader-config-pending.py` 复算）。
>
> **2026-11-05 拆分**：本节原来把 30 个 KI 组全放在这里（含 22 个已实现组，516 行），占掉了整份文件的三分之一。现在只留 8 个仍未接的组（A4/A5/A8/A10/A11/A12/C6/D3），22 个已实现组的全文移到了 [阅读配置 KI 组落地记录](history/known-issues/reader-config-landed.md)（本机归档，不随公开仓库发布）。组的编号、标题、正文一字未改；对照表「备注」列的 `KI-xx` 标记仍指向本节——组标题不是标题级元素，从来没有独立锚点，所以搬迁不影响任何链接。

判定口径按[项目范围](PROJECT.md)：**在线书源抓取、RSS、TTS 朗读、WebDAV 自 2026-11-09 起已纳入范围、尚未排期**（见 `PROJECT.md:24-44` 的「在线服务」节），依赖它们的上游行为记「**要接，待排期**」而不记「不接」；仍在[范围之外](PROJECT.md)（`PROJECT.md:46-48`）的是 AI 在线服务、云同步与额外设备形态，这些不因开关已上屏而算已实现，记「不接」。上游没有的行为一律不补。凡上游行为在本地已有等价实现、或上游分支在本平台根本不存在，直接记「不接」；其余记「要接，待排期」并写补法。

与字段口径的关系：本节按 **A–G 明细表的行**登记（现 11 行）。对照表 §一 1.5 按**上游声明名**判定的 112 项里，另有 9 项判「不接」但不对应任何 KI 组，理由直接写在 1.5 表内，不在此重复——`menuBgColor`、`menuBgColorNight`、`menuAcColor`、`menuAcColorNight`、`menuBottomCornerRadius`、`menuBottomHorizontalMargin`、`menuBottomBottomMargin`（都是上游 `Config` 里 `@Transient` 的主题包承载字段，上游没有用户设置入口）、`readStyleSelect`、`comicStyleSelect`（图片书/漫画，本地无该内容形态，明细表 A 块已判 `不适用`）。两个口径不可相加。

### A 阅读界面基础

**KI-A4 优化正文渲染（不接）** —— 覆盖 A-07（`optimizeRender`，`ReadSettings.kt:49`）。

上游这条只在 `feature/reader/legacy/LegacyReaderPaginationStyleFactory.kt:49` 的 `Build.VERSION.SDK_INT <= Q`（Android 10 及以下）分支里生效，是给老设备减少渲染开销的兼容路径。HOS 没有对应的老渲染管线，接了也没有可切换的实现。**不补**；设置页该条保留占位文案，不假装生效。

**KI-A5 朗读与在线书源三项（要接，待排期）** —— 覆盖 A-09 朗读悬浮窗分离提醒（`readAloudDetachReminderEnabled`，`ReadBookConfig.kt:80`）、A-10 自动切换书源（`autoChangeSource`，`ReadSettings.kt:42`，含 `defaultSourceChangeAll:15`）、A-11 换源结果应用于全部书籍。

朗读（TTS）与在线书源抓取自 2026-11-09 起**已纳入范围、尚未排期**（[PROJECT.md](PROJECT.md) `:24-44`）；因开关已上屏，判 `未接`。补法：随对应子系统接入。

**KI-A8 使用新版目录（不接）** —— 覆盖 A-14（`useNewTocSheet`，`ReadSettings.kt:37`）。

上游这个字段是「阅读页内开 Sheet」与「跳独立目录页」两种呈现的切换开关（`ui/book/read/ReadBookViewModel.kt:193`）。本地目录固定为 `CatalogPage.ets` 独立页一种形态，没有第二态可切。为它造一个不存在的新旧目录等于凭空加功能，**不补**。

**KI-A10 主题网格列数（要接，约 10 行）** —— 覆盖 A-18（`themeGridColumns`，`ReadSettings.kt:40`，默认 4）。

**复核（r348）：原判断「本地不是网格布局、该字段没有消费面」为误。** 本地主题列表就是 `Grid`：`ReaderSettingsPage.ets:2706-2716` 的 `Grid()` + `.columnsTemplate(this.themeGridTemplate())`，列数由 `:1960-1963` 的 `Math.max(2, Math.min(6, this.themeGridColumns))` 算，`:2696` 右上角显示「N 列」、`:2698` 点击 `cycleThemeGridColumns()` 循环 2…6。**与上游同构**（上游 `ReadSettings.kt:40` → `ThemeListContent.kt:370`/`:465` 的 `GridCells.Fixed(gridColumns.coerceIn(2, 6))`）。真缺口只有一个：`themeGridColumns` 是 `@State`（`:390`），全仓 4 处命中全在本页，`data/ReaderSettingsRepository.ets` 与 `data/BackupRepository.ets` 均零命中 → **退出即丢**。补法：加进 `ReaderSettingsRepository` 的读写与 `BackupRepository` 的键组（上游 `PreferKey.kt:448` 与 `ReadSettingsRepository.kt:644` 都把它记为偏好），约 10 行。

**KI-A11 预下载两项（要接，待排期）** —— 覆盖 A-19 向后预下载章节数（`preDownloadNum`，`ReadSettings.kt:58`，默认 10）、A-20 向前预下载章节数（`preDownloadNumPrev`，`:59`，默认 0）。

**复核（r348）：原判断「`AppDownloadCacheSettingsPage.ets:31` 是预览页、滑块无持久化」为误。** 该文件 186 行、`:31` 是 `@State cacheSettings` 初始化；两个滑块在 `:161`/`:162`，落盘走 `saveSettings()` → `data/CacheSettingsRepository.ets`（字段 `preloadBehind`/`preloadAhead`，默认 10/0，读 `:92`/`:93`、写 `:121`/`:122`），往返正常。真缺口是**除仓储与设置页外全仓零消费**（`preloadBehind\|preloadAhead\|preDownloadNum` 共 12 处命中，全在这两处）→ 调大不驱动任何缓存动作。仍记「要接，待排期」：预下载服务于在线书源的离线缓存，后者自 2026-11-09 起已纳入范围、尚未排期（[PROJECT.md](PROJECT.md) `:24-44`）。补法：随下载缓存子系统与在线书源一起接入。

**KI-A12 在浏览器打开（要接，待排期）** —— 覆盖 A-21（`readUrlInBrowser`，`ReadSettings.kt:64`）。打开的是书源页面，随在线书源一起做。

需要外部应用跳转（`module.json5` 的 browser skill），属跨应用能力而非配置接线。补法：加 browser skill 后用 `startAbility(ACTION_VIEW)` 打开。打开的是书源页面，随在线书源一起排期（[PROJECT.md](PROJECT.md) `:24-44`）。

### C 正文排版

**KI-C6 字体文件夹（不接）** —— 覆盖 C-26（`fontFolder`，`ReadSettings.kt:79`）。

上游是「用户指定一个目录，扫描其中所有 TTF/OTF」（`ui/book/read/ReadBookScreen.kt:470`）。HOS 应用无法递归扫描任意用户目录；本地等价能力是 `ReaderFontRepository.listFonts()` 列系统字体 + 导入字体到应用私有目录（r265 起可用），入口就在排版设置面板。**不补**，差别只在导入方式。

### D 翻页与手势交互

**KI-D3 朗读时允许音量键翻页（要接，待排期）** —— 覆盖 D-04（`volumeKeyPageOnPlay`，`ReadSettings.kt:30`）。朗读子系统未接入，随 TTS 一起做。

### E 菜单与主题外观

**整块共同的前置条件（2026-11-09 重写）**：这段原写「本地阅读页没有菜单外观渲染层，`readMenu*`/`titleBar*` 只命中 `data/BackupRepository.ets`，`ReaderPage.ets` 零命中」——**已被 READER-CONFIG 批 4/E 块落地推翻**。实测 `pages/ReaderPage.ets` 有 **121 处** `readMenu*`/`titleBar*` 命中，是真消费点：底栏圆角与悬浮（`:6529`/`:6539`-`:6544`/`:6560`）、底栏模糊与液态玻璃（`:1175`/`:1192`）、顶栏模糊与合并按钮（`:1206`/`:1242`）、菜单底色/容器色/强调色/文字色日夜分叉（`:1277`/`:1289`/`:1299`/`:1322`）、边框与模糊半径透明度（`:1333`/`:1346`/`:1367`）、顶栏标题胶囊与 `titleBarMode`（`:2998`-`:3014`）、悬浮图标玻璃与位置（`:3130`/`:6412`/`:6429`）；字段存在 `data/ReaderSettingsRepository.ets`（该文件 2085 行、`readMenu` 命中 215 处、`load` `:780` / `save` `:1562`），`pages/ReaderSettingsPage.ets`（3954 行）是设置入口。**结论：这一整块现在已经接了渲染层**，下面各条的判断按当年记录保留，不再把「没有渲染层」当共同前提。

**另有一层备份侧证据（2026-11-09 复核）**：这些 `readMenu*` 外观键在 `config.xml` 的两个方向都只走了一部分——导出段是 `BackupRepository.ets:822`-`:943`（49 处 upsert），**其中没有一处写 `readMenu*` 键**（该段只命中 `:928` 注释与 `:931` 的 `titleBarCompact`）；恢复段 `restoreReaderSettings`（定义 `:1883`）只读回四个：`readMenuIconShowText`（`:2145`）、`readMenuIconStyle`（`:2148`）、`readMenuIconItemsPerRow`（`:2150`）、`readMenuIconRowCount`（`:2152`）。这批键同时列在 `preferenceKeysByCategory.readConfig`（`:384`-`:406`）里作类别忽略时的排除名单。→ **准确的说法是「本地有渲染层、有本地持久化，但安卓备份里的菜单外观值几乎读不进来」**，不再是「没有渲染层」。

### B 页眉页脚

B 块唯一的 `未接` 行（页眉/页脚独立字体）已于 2026-10-31 复核改判 `已接`：排版设置面板的字体目标四按钮可选「页眉」「页脚」并落 `headerFont`/`footerFont`。**残留问题（2026-11-09 复核：已不存在）**：原文说「页眉页脚 tab 里那条「选择字体」仍走 `showNotMigrated('页眉/页脚字体选择')`」。实测 `grep -rn "页眉/页脚字体选择" entry/src/main/ets` **零命中**，`showNotMigrated` 全仓只剩 9 处调用，无一处与该文案相关；`ReaderSettingsPage.ets:799`-`:801` 现在是护眼/日夜相关的 `.fillColor`/`Image(app_moon)` 段。→ 这条占位已随排版设置面板的字体目标四按钮一并清理，不用再补。

## 深色模式行登记（ZIP-THEME.md 的未接行）

本节登记 [深色模式对照表](parity/ZIP-THEME.md) A–F 块里 **6 行 `未接`**（r298 建表时是 83 行，r300–r316 逐批落地后降到 6 行；22 个 KI 组里 18 个已实现的全文已移到 [深色模式 KI 组落地记录](history/known-issues/theme-landed.md)，本机归档、不随公开仓库发布）的「接不接、怎么接」。编号 `KI-TH-<块><组>` 与对照表「备注」列的 `**要接**` / `**不接**` 标记一一对应，组内逐行列出覆盖的对照表行。**本节只登记，除阶段一（r300）已落地者外不改 `.ets` 代码。**

判定口径按[项目范围](PROJECT.md)：**在线书源抓取、RSS、TTS、WebDAV 自 2026-11-09 起已纳入范围、尚未排期**（`PROJECT.md:24-44`），依赖它们的上游行为记「要接，待排期」；仍在[范围之外](PROJECT.md)（`PROJECT.md:46-48`）的 AI 在线服务、云同步与**额外设备形态适配**不因开关已上屏而算已实现；上游没有的行为不补；上游机制在本平台根本不存在的不照抄。判「不接」的**不删行、不改状态**，对照表里仍按 `未接` 计，只在备注与本节点明理由。

**与对照表状态的关系**：对照表状态只有 `已接 / 未接 / 不适用` 三值，不设「部分接」。本节的 `要接` 是排期结论，`不接` 是范围结论，两者都不改变对照表的 `未接` 状态——只有真正落地并验证过才改 `已接`。

**83 行的排期去向**：r298 建表时 83 行 `未接`，按「阶段一 6 行 → 阶段二 61 行 → 阶段三 16 行」排期，其中 `不接` 5 行。r300–r316 逐批落地后，75 行转 `已接`、4 行判 `不适用`，剩 **6 行 `未接`**（全部是 `不接`）。每一批落地时改判了哪几行、为什么改判、设备实测到什么，逐批记录在[深色模式 KI 组落地记录](history/known-issues/theme-landed.md) 里对应组的「本轮判定」段。

**全局前置**：这 83 行里 **78 行都要先有 F4（两套颜色资源）**才可能「看起来变了」。F4 没落地时，任何开关即使接了状态，界面也不会有可见变化——这是本表与其它对照表最大的不同，排期不能按「先接开关、后补皮肤」的顺序做。

### A 主题设置页

**A 块共同前提（2026-11-09 重写）**：这段原写「本地 `pages/ThemeSettingsPage.ets`（333 行）整页零持久化、39 处一律 `onUnavailableAction`」，**已被 r300–r316 逐批落地推翻**。实测该页批 6 后 **937 行**，主题风格 / 导航布局 / 多窗布局三行已按「不适用 / 范围之外」整行删，`onUnavailableAction` 只剩 **1 处真实占位**（切换图标，见批 6 节），持久化走 `data/ThemeSettingsRepository.ets` 的 `ThemeSnapshot`（`load`/`save` 逐键读写）与 `data/MainNavigationSettings.ets`、`data/TopBottomBarSettings.ets`、`data/BookInfoBackdropStyle.ets`、`data/CustomThemeColors.ets`、`data/ThemePalette.ets` 六个配套模块。下面各组「已实现」的落地记录仍是准的，只有这段前提过时。

**KI-TH-A2 Miuix 引擎两项（不接）** —— 覆盖 A3 Miuix 动态取色（Monet）、A7 主题引擎切换。

**判定理由**：`composeEngine` 是上游 Compose 侧的**全局渲染分支开关**，`ui/theme/LegadoTheme.kt` 暴露后被 30+ 处读取，决定用 Miuix 还是 Material 控件；`useMiuixMonet` 只在 `isMiuixEngine` 为真时出现（`ThemeConfigScreen.kt:199` 在 `:187` 的引擎分支内）。ArkUI 只有一套控件体系，**没有可切换的等价分支**，也没有引擎概念，因此这两行按「上游机制在本平台根本不存在」判不接。

**保留部分**：`composeEngine` 与 `useMiuixMonet` 两个键仍在 `data/BackupRepository.ets:407`-`:423` 的 53 键组里，随 themeConfig 备份进出（F6 已接），只是没有界面。本地 `:138`「主题风格」这一行**不改成引擎切换**——文案与上游 `compose_engine` 语义不同，按文案对齐会错。

**验收**：无（不接）。备份里出现 `composeEngine` 键时原样保留、不报错。

**KI-TH-A5 主界面组六项（A14 已实现 r311、A17 已实现 r312、A15/A16 已实现 r304 / 不接 2）** —— 覆盖 A14 首页与导航、A15 显示状态栏、A16 启用滑动时动画、A17 顶栏与底栏、A18 平板界面（**不接**）、A19 多窗布局（**不接**）。

**上游口径**：A14 sheet 可拖排主导航顺序、逐项显隐（`SetMainNavigationOrder`/`SetMainDestinationVisible`）；A15 `showStatusBar`；A16 `enableSwipeAnimation`；A17 sheet 10 个键（`topBarOpacity`/`bottomBarOpacity`/`topBarBlurRadius`/`bottomBarBlurRadius`/`topBarBlurAlpha`/`bottomBarBlurAlpha`/`topBarHeight`/`bottomBarHeight` 等）；A18 `tabletInterface`、A19 `multiPaneMode` 都按设备形态显示。

**判定**：A14–A17 **要接**（A14 已 r311、A17 已 r312 落地）；A18 平板界面与 A19 多窗布局属**额外设备形态**，按 [项目范围](PROJECT.md)「范围之外」判**不接**——批 6（2026-11-17 自造与降级清算）已把这两行整行删除，不再保留禁用态。

**补法**：**A17 已在 r312 落地**：新建 `entry/src/main/ets/data/TopBottomBarSettings.ets`（`TOP_BAR_BUTTON_STYLES` 五档 + `topBarButtonStyleLabel` 逐条对齐上游 `values-zh-rCN/arrays.xml:226-232`、`TopBottomBarSnapshot` 15 字段、7 个 `normalize*`、`resolveBarBackgroundColor` 按上游 `GlassDefaults.glassColor()` + `AppNavigationBar.kt:60` 合成、`resolveTopBarBackground`/`resolveBottomBarBackground`/`resolveBottomBarCornerRadius`）；`data/ThemeSettingsRepository.ets` 的 `ThemeSnapshot` 增加 15 字段（现 53 字段）；`pages/Index.ets` 新增 15 个 `@State`、`topBottomBarSnapshot()`、`publishTopBottomBarStyle()`（广播 `themeTopBarBackground`/`themeBottomBarBackground`/`themeTopBarBlurRadius`/`themeBottomBarBlurRadius`/`themeBottomBarRadius` 五个键）与 15 个 `selectTheme*` 回调；底栏渲染改成 `if (this.themeShowBottomView && ...)`，并按 `useFloatingBottomBar` 改宽度/圆角、按合成色设底色、按 `enableBlur` 挂 `backdropBlur`；顶栏底色由 `components/CollapsingSettingsHeader.ets`（12 个设置子页）与 `HomePage.ets`/`SearchPage.ets`/`ThemeSettingsPage.ets` 三处内联 header 消费（**r343 后这半句已过时**：顶栏统一到 `components/TopBar.ets` 的 `AppTopBar`，底色与模糊只由它一个消费，详见 `docs/parity/ZIP-THEME.md` 的 A17 行）。A18/A19 不动。**A14 已在 r311 落地**：新建 `data/MainNavigationSettings.ets`（`MAIN_NAVIGATION_ROUTES`、`mainNavigationLabel`、`orderedMainNavigation` 逐条对齐上游 `MainDestination.ordered` 的「过滤未知与重复 + 补齐未出现项」、`moveNavigationUp`/`moveNavigationDown`、`normalizeDefaultHomePage` 的不可见回落、`isMainDestinationVisible`/`visibleMainNavigation`）；`data/ThemeSettingsRepository.ets` 的 `ThemeSnapshot` 增加 `showHome`/`showDiscovery`/`showRss`/`defaultHomePage`/`mainNavigationOrder`/`labelVisibilityMode` 六字段（现 38 字段）；`pages/Index.ets` 的底栏由 5 个硬编码 `TabItem` 改为 `ForEach(this.visibleNavigationRoutes())`，并新增 `applyDefaultHomePage()`（启动与关掉当前页时回落）；`pages/ThemeSettingsPage.ets` 的「首页与导航」改为可展开组（三枚显隐开关 + 默认主页面下拉 + 导航标签显示下拉 + 逐项上下移按钮）。**与上游的差异**：上游用可拖列表（`rememberReorderableLazyListState`）改顺序，本地用「上移/下移」两枚按钮承接同一个 `onSetOrder` 语义；上游还有「导航栏图标」子 sheet（`NavIconManageSheet`，10 个自定义图标键），本地未做。**A15 已在 r304 落地**：`pages/ThemeSettingsPage.ets` 的「显示状态栏」改为 `@Prop showStatusBarVisible` + `onShowStatusBarChange`；`pages/Index.ets` 的 `selectThemeShowStatusBar()` 写 `themeShowStatusBar` + `applyThemeStatusBar()`（`setSpecificSystemBarEnabled('status', visible, false)`）+ 落盘；`restoreOnboarding()` 启动时读回并应用。**A16 已在 r304 落地**：同构的 `themeSwipeAnimation` / `selectThemeSwipeAnimation()`，**只落盘不造效果**——上游这个键本身没有任何渲染消费者（`ThemeConfigScreen.kt:361` 原文 TODO「这个可以不要了」），照实对齐现状。

**验收**：A15 已验（r304：关掉 → 顶部状态栏立即消失、页面顶到屏幕边，重启仍隐藏，prefs `showStatusBar` = `false`）；A16 已验（r304：关掉 → prefs `swipeAnimation` = `false`，重启后开关仍为关）；A14 已验（r311：①关「首页」→ 底栏 5 项变 4 项，截图 changed pixels 25092；②`mainNavigationOrder` 改 `my,home,bookshelf,explore,rss` 重启 → 底栏首项变「我的」；③`defaultHomePage` 改 `explore` 重启 → 冷启动停在发现页；④关掉「发现」且默认页是发现 → 自动回落书架）；A17 已验（r312：①关「显示导航栏」重启 → 底栏消失，`(640,2700)` 由 `(255,255,255)` 变 `(245,246,248)`；②「顶栏按钮样式」选「液态玻璃」→ prefs `topBarButtonStyle=liquid`；③开「悬浮底栏」→ 底栏变胶囊；④`bottomBarOpacity=40` 重启 → 底栏底色 `(255,255,255)`→`(249,250,252)`；⑤`topBarOpacity=40` 重启 → 外观页顶栏像素 `(16,15,13)`→`(107,107,107)`、`ImageChops` bbox `(0,56,1280,616)`、changed 616208；⑥拖「顶栏模糊半径」→ prefs `topBarBlurRadius` 24→7）；A18/A19 无（不接）。

**KI-TH-A6 书籍详情页组四项（A20/A21/A22 已实现 r307，A23 不接）** —— 覆盖 A20 界面颜色跟随封面取色、A21 网络封面背景设置、A22 默认封面背景设置、A23 作者搜索回退。

**本轮判定**：A20/A21/A22 要接，r307 已实现；A23 不接——上游唯一消费者 `BookInfoViewModel.kt:2007-2016` 依赖书源实体 `source.ruleBookInfo.relatedBooks`，本地无网络书源（`entry/src/main/ets/` 里 `bookSource` 只作为备份/规则壳出现），属 [项目范围](PROJECT.md)「在线书源抓取…不因出现在页面或备份归档中而视为已实现」。

**上游口径**：
- A20 `ThemeConfigScreen.kt:399` → `BookInfoScreen.kt:807-847 rememberBookInfoColorTheme`：`book == null || !enabled || !followCoverColor` 时返回 null；取色用 `ImageSeedColorExtractor.kt` 的 `QuantizerCelebi.quantize` + `Score.score`，常量 `IMAGE_COLOR_EXTRACT_SIZE_PX = 128`、`IMAGE_QUANTIZE_BITMAP_MAX_SIZE = 64`、`IMAGE_MAX_QUANTIZE_COLORS = 64`、`IMAGE_FALLBACK_SEED_COLOR = 0xFF4285F4`；叠层是 `lerp(secondaryContainer, seedColor, 0.42f)` 再 `alpha 0.34`。
- A21/A22 `ThemeConfigScreen.kt:407`/`:416` 两个 `DropdownListSettingItem`，值域 `off`/`on`/`off_for_default`（`res/values/array_values.xml:135-139`），中文文案 `关闭模糊封面`/`开启模糊封面`/`不显示背景封面`（`values-zh-rCN/strings.xml:1751-1753`）；语义在 `BookInfoBackdropStyle.kt:9-30`：`off` → (showCover=true, blurCover=false, applySeedOverlay=true)、`off_for_default` → 全 false、else → (true, true, true)。`BookInfoScreen.kt:863-875` 按 `usesDefaultCover` 在两个键之间选。
- A23 见上「本轮判定」。

**本地落地**（r307）：
1. `data/ThemeSettingsRepository.ets`：`ThemeSnapshot` 扩到 8 字段，新增 `bookInfoFollowCoverColor`/`bookInfoNetworkCoverBackground`/`bookInfoDefaultCoverBackground`；导出 `BOOK_INFO_BACKGROUND_OFF`/`BOOK_INFO_BACKGROUND_ON`/`BOOK_INFO_BACKGROUND_OFF_FOR_DEFAULT` 与 `normalizeBookInfoBackground`；`load`/`save` 逐键读写。
2. 新建 `data/BookInfoBackdropStyle.ets`：`BookInfoBackdropStyle` 三字段 + `resolveBookInfoBackdropStyle(backgroundMode)`（三档语义逐条照抄上游）+ `resolveBookInfoBackdropStyleFor(usesDefaultCover, defaultCoverBackground, networkCoverBackground)`。
3. 新建 `data/ImageSeedColorExtractor.ets`：`ImageSeedColorExtractor.extract(uri)` 用 `image.createImageSource` → `createPixelMap({ desiredSize: { width: 16, height: 16 } })` → `readPixelsToBufferSync` 取像素均值，再按 1.6 倍提饱和度；失败回落 `#4285F4`。
4. `pages/ThemeSettingsPage.ets`：书籍详情页组三项改真回调；新增 `ThemeSettingsDropdown` 组件（`bindMenu` + `MenuItem`，与 `OtherSettingsPage.ets` 的 `OtherSettingsDropdown` 同写法）。
5. `pages/Index.ets`：新增 `@State bookInfoFollowCoverColor`/`bookInfoNetworkCoverBackground`/`bookInfoDefaultCoverBackground`、`selectBookInfoFollowCoverColor`、`selectBookInfoCoverBackground`，并接进 `saveThemeSettings` 与 `restoreOnboarding`。
6. `pages/BookInfoPage.ets`：新增三个 `@Prop`、`backdropStyle()`、`loadCoverSeedColor()`、`seedOverlayColor()`；背景封面按 `showCover`/`blurCover` 分支，叠层按 `applySeedOverlay` 挂载。

**与上游的两条差异**（如实记录）：
- 取色算法不同：上游是 Celebi 量化 + Score 打分，本地是 16×16 像素均值 + 提饱和——都产出「代表封面的主色」，但同一张图给的具体色值不会相同。
- 叠层取色不同：上游 `lerp(secondaryContainer, seedColor, 0.42f)`，本地直接用主色（A2 未接，本地没有 secondaryContainer 这一层）。

**验收**（2026-11-01 模拟器实测通过，见 [验证记录](VALIDATION.md) r307 节）：
- A20：开/关「界面颜色跟随封面取色」→ 详情页顶部同一区域平均色 `(87.2, 88.9, 156.9)` → `(81.9, 83.9, 142.7)`。
- A21：三档各重启一次进详情页——`on` 背景模糊、`off` 背景清晰、`off_for_default` 背景封面整块消失。
- A22：设置页选「不显示背景封面」→ 重启 → prefs `bookInfoDefaultCoverBackground` 为 `off_for_default`。

### B 主题包管理

**B 块整体判定：12 行已在 r316 全部落地（`已接`）。** r316 之前本地没有主题包这个概念——`pages/ThemeSettingsPage.ets:563` 的「主题管理」是 `onUnavailableAction('主题包管理尚未迁移')`，入口文案在、页面不在。上游是三份文件：`help/config/ThemePackageManager.kt`（1254 行）、`help/config/ThemeImportExport.kt`（393 行）、`ui/config/themeManage/EditThemeSheet.kt`（403 行），加列表页 `ThemeManageScreen.kt`（331 行）。r316 新建了一整页 + 一套包格式，逐行落地情况见下三节。

### C 首次启动向导

### D 阅读页日夜快捷按钮

**D 块前提**：本地阅读页**有**日夜按钮（`ReaderPage.ets:3162` 的 `else if (kind === 'theme') { this.onToggleNightMode(); }` 与 `:7154` 的动作条图标、`ReaderSettingsPage.ets:800`-`:802` 「背景」行的月亮 `Image(app_moon/app_daynight)` + `onToggleNightMode()`），切的是阅读页私有 `readerNightMode` 布尔（`ReaderSettingsRepository.ets:165`），**不写全局 `themeMode`**。所以 D 块的问题不是「按钮没有」，是「按钮只管自己那一页」。

### E 日夜提醒

**E 块整体判定：7 行里 6 行已实现（r302 核实）、1 行不接。** r297 盘点时判「本地只有 `ReaderSettingsPage.ets:898` 一个开关壳、全仓零命中」是**误判**——提醒机制其实早已存在于仓库（`pages/Index.ets` 的传感器订阅与判定、`pages/ReaderPage.ets` 的提醒胶囊、`pages/ReaderSettingsPage.ets:1495` 的真开关、`data/ReaderSettingsRepository.ets:240-241/1583` 的持久化），只是当时没查到。r302 逐行核实后 E1–E6 改判 `已接`，并在模拟器上验通了胶囊弹出、5 秒消失、点击切换、关闭后不再弹四条。

**KI-TH-E3 提醒的 intent/effect 链路（不接）** —— 覆盖 E7。

**判定理由**：本地阅读页用 `@Prop` 回调直连（`onToggleNightMode`），**没有 intent/effect 分层**，这是架构差异而非缺功能。上游这一层还有历史包袱：`ReadBookContract.kt:1271 data object ToggleDayNight : ReadBookEffect` 定义了但 `ReadBookController.kt:2563-2565` 注释写明「Handled directly by ViewModel — effect not currently emitted」，即**上游这个 effect 从不发出**。为一行从不生效的分层引入整套架构，违背「上游没有就不要这个效果」。

**保留部分**：提醒的实际行为在 KI-TH-E1/E2 里直接实现，不依赖该层（这两组的全文已移到本机归档 `docs/history/known-issues/theme-landed.md`）。

**验收**：无（不接）。提醒功能照 KI-TH-E2 的验收走（验收原文见本机归档 `docs/history/known-issues/theme-landed.md`）。

### F 网关与全局换肤

**F 块是整张表的地基**：F1/F2/F3/F4 四行不落地，A/B/C/D/E 五块的所有开关接了也不会有可见变化。这四行必须在阶段一一起做完。

## 书架布局行登记（ZIP-BOOKSHELF-LAYOUT.md 的未接行）

本节登记 [书架布局总账](parity/ZIP-BOOKSHELF-LAYOUT.md) A–F 块里 43 行 `未接`（r331 版行数；2026-11-15 复核后为 8 行、收口字段全集行后为 7 行）的「接不接、怎么接」。编号 `KI-SL-<块><序号>` 与对照表「备注」列的 `**要接**` / `**不接**` 标记一一对应，组内逐行列出覆盖的对照表行号（行号为 ZIP-BOOKSHELF-LAYOUT.md 的行号）。**本节只登记，不改 `.ets` 代码。**
> **2026-11-15 复核**：本节写于 r331 时代，当时 41 行判 `**不接**` 的依据是「本地无列表模式 / 无详情区 / 无隐私书架」这类**整体前提**。本轮逐行回到代码取证后，35 行改判 `已接`（面板与渲染两侧都有落点：`showUnread` → `unreadTextOf()`、锁定书卡片 → `BookCover.locked`、加载中对话框 → `busyText` 遮罩、`LazyForEach` + `cachedCount(6)`），5 行仍 `未接` 但已改判 `**要接**`。**当前全表只剩 1 行 `**不接**`**（B 块 `:124` 分组封面阴影，`components/BookGroupCard.ets` 全文 `shadow` 零命中）。下文 KI-SL-N1~N9 九组保留作历史判定记录，其覆盖行号对应 r331 版对照表行号，与当前表行号已不对应。

**判定口径**：按 [PROJECT.md](PROJECT.md) 与 PARITY-RULES.md 第三节。在线书源抓取自 2026-11-09 起已纳入范围（`PROJECT.md:24-44`，尚未排期），依赖它的行记「要接，待排期」；仍在[范围之外](PROJECT.md)（`PROJECT.md:46-48`）的只有 AI 在线服务、云同步与额外设备形态。判「不接」的**不删行、不改状态**，对照表里仍按 `未接` 计，只在备注与本节点明理由。

**与对照表状态的关系**：ZIP-BOOKSHELF-LAYOUT.md 只有 `已接 / 未接 / 不适用` 三值，不设「部分接」。本节的 `要接` 是排期结论，`不接` 是范围结论，两者都不改变对照表的 `未接` 状态。全表 122 行 = 112 已接 / 7 未接 / 3 不适用（r331/r332 落 38 行、2026-11-15 复核改判 35 行并收口字段全集行后）；7 行未接 = 6 `要接` + 1 `不接`。

**排期分布**：45 条 `要接` 里 **39 条已在 r331/r332 与 2026-11-15 复核中落地**（对照表状态转 `已接`），**剩 6 条未接**：「显示等待更新数量」「书架更新数量限制」「批量更新数量限制」「打开书架时自动刷新目录」「首屏封面预加载列数」「等待更新数量」。前四条的共同断点是**字段与面板都在、消费面零命中**（`showWaitUpCount` / `bookshelfRefreshingLimit` / `autoRefreshBook` 只在面板出现），后两条（预加载列数、等待更新数量的 BookItem 侧）是**消费面真的没建**；「书架设置字段全集（51 字段）」已在 2026-11-15 复核中一并收口：本地 `interface BookshelfLayoutSettings` 53 字段，去掉 2 个本地扩展后与上游 51 个 `val` 一一对应。

**全局前置（三条均已在 r331/r332 落地）**：这三件原本是 `要接` 组的前置障碍，现在全部完成，保留清单只为说明「当初为什么按这个顺序排」——

1. **列表模式**：已做。`pages/BookshelfPage.ets` 现在有独立的列表分支（`bookshelfLayout*List*` 一套键），不再是「把网格列数压成 1 列」。
2. **横竖屏取值**：已做。`pages/BookshelfPage.ets:99-100` 有 `@State isLandscape`，`:169 this.isLandscape = rect.width > rect.height;` 订阅 `windowSizeChange` 后立即刷新，Landscape 那套字段（`bookshelfLayoutGridLandscape` 等）都已接上。
3. **分组样式第三档**：已做。`model/BookshelfLayout.ets:98-102` 的 `BOOK_GROUP_STYLE_OPTIONS` 现在是三项 `{ value: 0, label: '页签' }`、`{ value: 1, label: '隐藏页签' }`、`{ value: 2, label: '文件夹' }`，文件夹视图（`folderViewGroup`）已实现。

### A/B/E 的未接行（11 组要接 / 9 组不接）

**KI-SL-A1 分组样式三档与文件夹视图** —— 覆盖 A 块 `:40`、`:44`、`:45`、`:46`、`:48`、`:49`，E 块 `:179`（共 7 行）

- **上游口径**：`bookGroupStyle` 三档（`BookshelfConfigSheet.kt:84-90`，`values-zh-rCN/arrays.xml:24-28` = 标签 / 隐藏标签 / 文件夹）；第 2 档出现后，`BookshelfScreen.kt:983` `if (bookGroupStyle == 2 && isRoot …)` 改走文件夹网格，`:1023` 再按 `bookshelfFolderLayoutMode` 决定 `BookGroupItemList` 还是网格；配置面板随之展开文件夹的布局模式（`:143`）、网格列数（`:164`）、列表列数（`:186`）、列表样式（`:220`）、横排封面数（`:230`）。
- **本地现状**：`entry/src/main/ets/pages/BookshelfPage.ets:585-587` 只有一个开关，写值只有 0/1；`entry/src/main/ets/model/BookshelfLayout.ets:43-46` 选项数组两项；无文件夹根视图、无 `bookshelfFolderLayoutMode*` / `bookshelfFolderLayoutGrid*` / `bookshelfFolderLayoutList*` / `bookshelfGroupListStyle` / `bookshelfGroupCoverCount` 字段。
- **补法**：`BookshelfLayout.ets` 先补 8 个字段，并在 `entry/src/main/ets/data/BookshelfLayoutRepository.ets` 的 `load`（`:30-66`）/ `save`（`:69-93`）/ `mergeFromAndroidValues`（`:101-133`）/ `toAndroidValues`（`:136-152`）四处同步键名（键名照 `entry/src/main/ets/data/BackupRepository.ets:424`-`:438` 的 39 键数组）；面板把 `LayoutSwitchRow` 换成三档 `LayoutMenuRow`；渲染层在 `BookshelfPage.ets:719-733`（页签区）与 `:734-799`（卡片区）之间插入文件夹根视图分支。
- **验收**：面板选「文件夹」后，书架根层显示分组卡片（每张卡显示组内前 N 个封面），点进去是该组的书；返回回到根层；横竖屏各一套列数。
- **已实现（r331）**：A 块 `:40`、`:44`、`:45`、`:46`、`:48`、`:49`，E 块 `:179` 共 7 行已改 `已接`。`BookshelfLayout.ets:95-99` 补第三档「文件夹」并新增 `:114-118` / `:120-124` 两组选项；`BookshelfPage.ets:796-798` 分组样式开关改三档下拉、`:803-834` 展开文件夹六项与列表样式/横排封面数面板、`:1008-1018` 文件夹导航条、`:1033-1053` 根层分组卡片网格、`:266-289` 进组/返回、`:569-601` 按方向取六值。新建 `components/BookGroupCard.ets`。截图 `b5-folder-root.png`（根层）/ `b5-folder-inside.png`（组内）/ `b5-back.json`（返回）/ `b5-panel-expanded.png`（面板）。**横屏三行 C `:142`/`:143`/`:144` 与 C1 同型，代码已落地但本机模拟器无旋转入口、设备横屏行为未验，留 `未接`，卡点见证据包第 4 节。**

**KI-SL-A2 网格样式与紧凑模式** —— 覆盖 A 块 `:51`、`:59`，B 块 `:98`、`:122`（共 4 行）

- **上游口径**：`bookshelfGridLayout` 三档「标准 / 紧凑 / 仅封面」（`BookshelfConfigSheet.kt:273`，`values-zh-rCN/arrays.xml:249-253`），只在 `layoutMode == 1`（网格）时出现（`:267`）；`BookItem.kt:110` 在 `gridStyle == 1` 时把标题画在封面内（白字），`:135` 在 `gridStyle == 0` 时画在封面下方。`bookshelfLayoutCompact`（`:388` `compact_details`）进入 `BookItem.kt:230` 与 `:738`，控制卡片是否渲染作者 / 简介等副信息。
- **本地现状**：无 `bookshelfGridLayout`、无 `bookshelfLayoutCompact`；网格卡片恒为「封面 + 封面下方的书名」（`BookshelfPage.ets:738-755`），书名位置写死。
- **补法**：两字段进 `BookshelfLayout.ets` + 仓储四处；渲染层在 `BookshelfPage.ets:749-754` 外面加 `gridStyle` 分支（1 → 书名移进 `BookCover` 上叠层，2 → 不渲染 `Text`）；`compact_details` 打开时补渲染作者行。
- **验收**：选「仅封面」后网格卡片不再显示书名；选「紧凑」后书名变封面内白字；开「精简详情」后卡片只留封面与书名。
- **已实现（r331）**：A 块 `:51`、`:59` 与 B 块 `:98`、`:122` 已改 `已接`。字段与面板条目在 `BookshelfPage.ets:692-694`（网格样式）/`:714-715`（精简详情）；渲染在 `:859-899`。三张截图 `a2-compact.png` / `a2-coveronly.png` / `b2-default.png`，重启后值保持见 `b2-restart.json`。验收方式已写进总账对应行。

**KI-SL-A3 分组列表样式与横排封面数** —— 覆盖 B 块 `:109`、`:110`（共 2 行）

- **上游口径**：`bookshelfGroupListStyle` 三档「分组 / 紧凑列表 / 横排封面数量」（`BookshelfConfigSheet.kt:220-226`，`entryValues` `"0"`/`"1"`/`"2"`）；`BookItem.kt:504` 在 `== 2` 时走 `BookGroupItemHorizontalCovers`，`:530` 在 `== 1` 时置 `isCompact = true`；`bookshelfGroupCoverCount` 由 `:627-628` `previewBooks.take(coverCount)` 消费，`:657` 不足时补 `Spacer`，面板入口在 `BookshelfConfigSheet.kt:230`（仅 `bookshelfGroupListStyle == 2` 时出现，`:229`）。
- **本地现状**：无这两个字段；分组从不以卡片形式出现在书架网格里。
- **补法**：随 KI-SL-A1 一起补字段与仓储；`BookGroupItemHorizontalCovers` 在本地需要新建分组卡片组件，横排封面数取 `bookshelfGroupCoverCount`。
- **验收**：选「横排封面数量」并把数量改为 6 后，分组卡片一行 6 个封面，不足 6 本时右侧留空。
- **已实现（r331）**：B 块 `:109`、`:110` 已改 `已接`。新建 `components/BookGroupCard.ets`：`previewBooks()`（`:29-32`）按 `coverCount` 取前 N 本、`emptySlots()`（`:35-40`）补不足空位、`listStyle===2`（`:51-72`）走横排封面分支、`===1` 紧凑、`===0` 普通；点击整卡 `onOpen` 进组。数量 4→6 后样本每组仅 1 本 → 1 封面 + 5 空位右侧留空，见 `b5-folder-covercount6.png`，重开读回 6 见 `b5-reopen.json`。

**KI-SL-A4 卡片背景色（日 / 夜）** —— 覆盖 A 块 `:57`、`:58`，B 块 `:105`（共 3 行）

- **上游口径**：`bookshelfCardColor` / `bookshelfCardColorDark`（`BookshelfConfigSheet.kt:346` 日间、`:367` 夜间，写回 `:680` / `:689`），消费在 `BookItem.kt:176`、`:570`；ZIP 类别按「会动到哪个类别」判为 `bookshelfLayout / themeConfig`（两色键同时进主题导出：`data/repository/ThemePackageSettingsRepository.kt:76-77`、`domain/model/settings/ThemeExportData.kt:62-63`）。
- **本地现状**：卡片底色取自主题，无这两个字段。
- **补法**：字段 + 仓储四处；卡片外层容器按 `isNight` 取对应色，未设（0）时回落主题色。
- **验收**：日间色改为米色后亮色模式卡片底色变米色、暗色模式仍取夜间色；两色都设为 0 时与现在一致。
- **已实现（r331）**：A 块 `:57`、`:58` 与 B 块 `:105` 已改 `已接`。`ColorPickerRow` 在 `BookshelfPage.ets:630-642`（复用 `CustomThemeColors.ets:100-105` 的 `normalizeCustomColor`），取色在 `:528-532` `cardBackgroundColor()`。日/夜两色 hex 输入重启后值保持见 `b2-restart.json`，生效截图 `b2-colors-applied.png`。

**KI-SL-A5 列表封面宽度** —— 覆盖 A 块 `:60`，B 块 `:100`（共 2 行）

- **上游口径**：`bookshelfListCoverWidth` **只在列表分支被读**——`BookItem.kt:965`（`BookshelfListItem` 调用处）、`:549`（分组列表）、`:1041`（锁定书列表分支），网格分支 `:825-843` 不读。
- **本地现状**：面板有条目（`entry/src/main/ets/pages/BookshelfPage.ets:629-631`）、仓储读写（`entry/src/main/ets/data/BookshelfLayoutRepository.ets:58-59` / `:86` / `:130` / `:150`）、备份带出（`entry/src/main/ets/data/BackupRepository.ets:606` / `:1331`），但**没有任何渲染代码读它**：`:745` 传给 `BookCover` 的 `maxWidth` 来自 `bookshelfCoverWidthLimit()`，该函数只用 `bookshelfGridCoverWidth`（`:462`）。
- **补法**：**与列表模式一起做**（见全局前置 1）。本地当前只有网格，即使把该字段接到 `:745` 也不会改变外观——上游网格分支本来就不读它。
- **验收**：切到列表模式后调该项，列表封面宽度随之变化；网格模式下调该项外观不变（与上游一致）。
- **已实现（r331）**：A 块 `:60` 与 B 块 `:100` 已改 `已接`。列表模式卡片（`BookshelfPage.ets:926-965`）封面 `displayWidth` 取 `bookshelfListCoverWidth`（`:936-937`），面板步进器 `:788-791`；列表 84→114 的封面变宽见 `b4-list-default.png` / `b4-list-width-after.png`，网格下调该项外观不变见 `b4-grid-width-unchanged.png`。

**KI-SL-A6 列表详情（简介 / 最新章节）** —— 覆盖 A 块 `:64`、`:65`，B 块 `:112`、`:120`（共 4 行）

- **上游口径**：`bookshelfShowLatestChapter`（`BookshelfConfigSheet.kt:447`，消费 `BookItem.kt:942`）；`bookshelfShowIntro`（`:456`，消费 `:739`）；总开关 `showListDetails = layoutMode == 0 && !isCompact && settings.showBookIntro`（`:738`）。
- **本地现状**：两字段都没有；卡片唯一副信息是封面上的章节数角标（`entry/src/main/ets/components/BookCover.ets:193-200`），不是章节名。
- **补法**：随列表模式一起做，`BookItem.kt:738-760` 的详情区在本地按 `Column` + 两行 `Text` 还原；章节名取书籍模型里的最新章节名。
- **验收**：开「显示最新章节」后列表卡片出现章节名一行；开「显示简介」后出现简介段落。
- **已实现（r331）**：A 块 `:64`、`:65` 与 B 块 `:112`、`:120` 已改 `已接`。面板两开关 `:793-798`，列表卡片简介 `Text(book.description ?? )`（`:951-956`）与最新章节 `Text(book.lastChapter)`（`:958-963`），`bookCardKey`（`:136-137`）纳入两字段。关「显示最新章节」后章节名行消失见 `b4-list-no-details.png`；**样本书 `titleonly-test` 的 `description` 为空，显示简介的可见效果在本机样本上得不到视觉证据，卡点见证据包第 4 节**。

**KI-SL-A7 搜索按钮点击 / 长按分流** —— 覆盖 A 块 `:80`，D 块 `:166`（共 2 行）

- **上游口径**：`bookshelfSearchActionDirectToSearch`（`BookshelfConfigSheet.kt:616`）；`BookshelfScreen.kt:570` 与 `:577` 两处手势按该布尔互换（点击搜索 / 长按筛选），`:1343` `val searchFirst = uiState.settings.bookshelfSearchActionDirectToSearch`。
- **本地现状**：无该字段；搜索按钮单击即进搜索，无长按分流（`BookshelfPage.ets` 里未查到搜索分流代码，`:756-765` 是卡片手势）。
- **补法**：字段 + 仓储；搜索按钮加长按手势，按字段决定点击与长按各自的动作。
- **验收**：开启后单击搜索按钮直接进搜索页、长按先进筛选；关闭后两者互换。
- **已实现（r331）**：A 块 `:80` 与 D 块 `:166` 已改 `已接`。`BookshelfPage.ets:800-816` 的 `.onClick` 与 `.priorityGesture(LongPressGesture)` 两分支按 `bookshelfSearchActionDirectToSearch` 对调，字段开关在 `:736`。

**KI-SL-A8 快速滚动条** —— 覆盖 A 块 `:81`，E 块 `:181`（共 2 行）

- **上游口径**：`showBookshelfFastScroller`（`BookshelfConfigSheet.kt:626`）；`BookshelfScreen.kt:1723` `val showFastScroll = uiState.settings.showBookshelfFastScroller`，`:1752` 传给 `FastScrollLazyVerticalGrid`，文件夹侧 `:1004`、`:987` 同型。是**带字母索引的快速滚动条**，不是系统滚动条。
- **本地现状**：无该字段；`entry/src/main/ets/pages/BookshelfPage.ets:772` `scrollBar(BarState.Off)` 写死。
- **补法**：字段 + 仓储；`Grid` 改 `scrollBar(BarState.On)` 只是最小形态，上游的字母索引需要另做叠层（ArkUI 无现成控件）。
- **验收**：开启后书架右侧出现可拖动滚动条，拖动时显示当前分组 / 索引。
- **已实现（r331，最小形态）**：A 块 `:81` 与 E 块 `:181` 已改 `已接`。`BookshelfPage.ets:915` 用系统 `scrollBar(BarState.On/Off)`；上游 `FastScrollLazyVerticalGrid` 的字母索引属增强，本轮未做，已在总账差异说明列写明。字段开关在 `:739`，重启后值保持见 `b2-restart.json`。

**KI-SL-A9 记住上次所在分组** —— 覆盖 E 块 `:186`（共 1 行）

- **上游口径**：`saveTabPosition`（`BookshelfViewModel.kt:110` 读、`:955` `changeGroup` 写、`:734` / `:763-764` 恢复）；落盘键名是 `bookshelfSelectedGroupId`（`constant/PreferKey.kt:73`），另读 `rawPrefValue(PreferKey.saveTabPosition)`（`:72`）。
- **本地现状**：无该字段，进书架恒落「全部」（`BookshelfPage.ets:131-134` `activeFilter()` 只在选中组被隐藏时回落）。
- **补法**：字段 + 仓储；`activeFilter` 初始化时读该值，页签切换时写回。
- **验收**：切到某分组后退出再进书架，仍停在该分组；该分组被删或隐藏时回落「全部」。
- **已实现（r331）**：E 块 `:186` 已改 `已接`。`BookshelfPage.ets:59` `@Prop @Watch`、`:126-128` `aboutToAppear`、`:132-141` `onLayoutChanged`、`:143-148` `selectGroup` 写回；落盘键 `bookshelfSelectedGroupId`。页签与分组菜单点击在 `:293`/`:844` 改走 `selectGroup`。

**KI-SL-A10 空态里的「全局搜索」按钮** —— 覆盖 E 块 `:189`（共 1 行）

- **上游口径**：`BookshelfScreen.kt:1675-1683`，`:1673` `if (uiState.isSearch)` 时显示按钮，文案 `bookshelf_empty_global_search`，点击跳全局搜索。
- **本地现状**：`entry/src/main/ets/pages/BookshelfPage.ets:795` 只把文案换成「没有匹配的书籍」，无按钮、无跳转。
- **补法**：`BookshelfPage.ets:788-799` 的空态分支加一个按钮，走现有的全局搜索路由。
- **验收**：搜索无结果时显示按钮，点它跳到全局搜索页。
- **已实现（r331）**：E 块 `:189` 已改 `已接`。`BookshelfPage.ets:942-946` 在无匹配空态加「全局搜索」按钮，`.onClick` 走 `Index.ets:6714` 传入的 `onSearch`。

**KI-SL-A11 字段全集与备份归类** —— 覆盖 F 块 `:198`、`:206`（共 2 行）

- **上游口径**：`domain/model/settings/BookshelfSettings.kt:6-56` 共 51 字段；分类数组 `help/storage/BackupConfig.kt:319-359` 39 键；`bookGroupStyle`（`constant/PreferKey.kt:13`）与 `hideEmptyGroups`（`:14`）不在 39 键内，走 `keyIsNotIgnore` 的 `else -> true`（`help/storage/BackupConfig.kt:413`），即不受任何类别开关控制。
- **本地现状**：`entry/src/main/ets/model/BookshelfLayout.ets:7-34` 只有 13 字段（本地 13 个名字在上游 51 名单里全部存在，无本地独有字段；上游另有 38 个名字本地未声明）；本地这两个键**不在** `bookshelfLayout` 键组（`entry/src/main/ets/data/BackupRepository.ets:424`-`:438`）里，写出时落在类别门控 `:682` **之前**的无条件块 `:675`/`:676`，所以取消勾选「书架布局」也照样写出。
- **补法**：字段按 KI-SL-A1~A10 分批补；两个归类错位的键从 `bookshelfLayout` 数组移出，改为无条件写出。
- **验收**：备份勾选里取消「书架布局」后，`config.xml` 仍含 `bookGroupStyle` 与 `hideEmptyGroups` 两项。
- **已实现（r331，部分）**：F 块 `:206` 已改 `已接`——`BackupRepository.ets:424`-`:438` 的 `bookshelfLayout` 键组不含这两键，`:675`/`:676` 在类别门控 `:682` 之前无条件写出。F 块 `:198` **仍留 `未接`**：本地 `BookshelfLayout.ets:7-86` 现 39 字段（原 13 + 批次 1 补 26），上游 51 字段里剩 12 个名字未声明（`showUnread`/`showUnreadNew`/`showTip`/`showBookCount`/`showLastUpdateTime`/`showBookIntro`/`bookshelfShowTag`/`bookshelfShowCustomTags`/`bookshelfShowSourceTags`/`bookshelfShowWordCount`/`showWaitUpCount`/`shouldShowExpandButton`），全部落在 KI-SL N2/N4「不接」组，任务书硬约束「9 组 41 行不接一行不碰」「不为做角标新建 Book 字段」禁止补这 12 个；按任务书「做不完留未接」处置，卡点与需要谁来判见证据包第 4 节。

**KI-SL-N1 列表专属版式与详情微调（不接）** —— 覆盖 A 块 `:47`、`:56`、`:62`、`:63`、`:66`、`:67`，B 块 `:106`、`:107`、`:111`、`:113`、`:114`（共 11 行）

- **判定理由**：这 11 行的前提都是「列表卡片」或「卡片副信息区」，本地既无列表模式（全局前置 1）也无详情区。判 `不接` 是**范围结论，不是上游无此行为**——逐行的上游依据都保留在对照表「上游位置」列，日后补列表模式时可原样复用。
- **特别说明**：`:47`（文件夹区列表封面宽度）与 `:60`（书籍区列表封面宽度）在上游是**同一字段** `bookshelfListCoverWidth` 的两个显示位置（`BookshelfConfigSheet.kt:202` 与 `:399`），所以书籍区那行判 `要接`（KI-SL-A5）、文件夹区这行判 `不接`，避免同一字段排两次。
- **验收**：本组无独立验收，随 KI-SL-A1 / A5 / A6 的验收一并覆盖。
- **前提已变化（r333，状态未重判）**：本组 10 行的判定理由写的是「本地既无列表模式（全局前置 1）也无详情区」。列表模式已在 r331 批次 4 落地（`entry/src/main/ets/pages/BookshelfPage.ets:1171` 起的 `Column` 分支），详情区总开关 `showBookIntro` 与四项子控制在 r333 落地（字段 `entry/src/main/ets/model/BookshelfLayout.ets:86`；`showsListDetails()` `BookshelfPage.ets:568-570`；面板 `:939-976`；渲染 `:1193-1200`、`:1214`、`:1216-1224`、`:1226-1230`）。按 `docs/PARITY-RULES.md` 第五节，`已接 / 未接 / 不适用` 属判断段产出，本组状态本轮**一行未改**，仍全部 `未接`；`docs/parity/ZIP-BOOKSHELF-LAYOUT.md` 对应 A 块 `:56`/`:62`/`:63`/`:66`/`:67` 与 B 块 `:106`/`:107`/`:111`/`:113`/`:114` 的「差异说明」列（原写「本地无 xxx」）也保持原样。要不要改判由判断段或用户决定。

**KI-SL-N2 标签体系（不接）** —— 覆盖 A 块 `:68`、`:69`，B 块 `:118`、`:119`（共 4 行）

- **判定理由**：标题标签依赖 `kindList`（`BookItem.kt:878-885`、`:888`），本地卡片无标签行、无标签数据源；`bookshelfShowTag` / `bookshelfShowCustomTags` / `bookshelfShowSourceTags` / `bookshelfShowWordCount` 四个字段本地都没有。上游这三个勾选项还在二级弹层里（`BookshelfConfigSheet.kt:695-742` 的 `BookshelfTagContentDialog`），本地面板无二级弹层结构。判 `不接`：标签属于卡片信息密度扩展，先补列表模式与紧凑模式（KI-SL-A2 / A6）再看是否需要。
- **验收**：无。

**KI-SL-N3 标签配色（不接）** —— 覆盖 A 块 `:70`、`:71`（共 2 行）

- **判定理由**：ZIP 类别是 `themeConfig` 不是 `bookshelfLayout`——`custom_tag_colors`（`BookshelfConfigSheet.kt:517`）与 `manage_tag_colors`（`:524`）改的是标签色板，落在主题体系（[ZIP-THEME.md](parity/ZIP-THEME.md)）里，本类别只借用入口。判 `不接`，转 ZIP-THEME.md 的 KI-TH 组处理。
- **验收**：无（归 ZIP-THEME.md）。

**KI-SL-N4 角标与提示信息（不接）** —— 覆盖 A 块 `:74`、`:75`、`:76`、`:77`、`:78`、`:79`，B 块 `:115`、`:116`、`:117`、`:121`（共 10 行）

- **判定理由**：`showUnread`（`BookItem.kt:752`）、`showUnreadNew`（`:753`）、`showTip`（`:754`）、`showBookCount`（`BookshelfScreen.kt:1011`）、`showLastUpdateTime`（`BookItem.kt:944`）、`showWaitUpCount`（`BookshelfViewModel.kt:1289`）这 6 个字段**都不在 bookshelfPrefKeys 39 键内**（`help/storage/BackupConfig.kt:319-359`），对照表里 ZIP 类别标 `—`；但它们对应的可视元素是未读数 / 红点 / 类型标签 / 分组计数 / 更新时间，本地卡片都没有。判 `不接`：这些是信息密度扩展，且本地封面角标已有「章节数 + 书签 + 缺正文红标」三件（`entry/src/main/ets/components/BookCover.ets:187-211`），再加未读角标会与章节数抢同一位置。
- **验收**：无。

**KI-SL-N5 二级弹层三项（不接）** —— 覆盖 A 块 `:84`、`:85`、`:86`（共 3 行）

- **判定理由**：这是 `BookshelfTagContentDialog`（`BookshelfConfigSheet.kt:695-742`）里的三个 `CheckboxItem`（`:711` / `:716` / `:721`），是 KI-SL-N2 的二级面板形态，本地既无标签行也无弹层。判 `不接`：与 KI-SL-N2 同因，随标签体系一起排期。
- **验收**：无。

**KI-SL-N6 分组卡片增强（不接）** —— 覆盖 A 块 `:82`，B 块 `:108`，E 块 `:180`、`:182`（共 4 行）

- **判定理由**：`shouldShowExpandButton`（`BookshelfScreen.kt:806-821`，「更多分组」按钮）、分组封面阴影（`BookItem.kt:349`）、分组根目录书籍数量（`BookshelfScreen.kt:1011`）三个都以「分组卡片在书架网格里」为前提，本地分组只在页签栏出现（`entry/src/main/ets/pages/BookshelfPage.ets:719-733`）。判 `不接`：等 KI-SL-A1 落地后再评估。
- **验收**：无。

**KI-SL-N7 批量更新与后台任务（要接，待排期）** —— 覆盖 A 块 `:83`，E 块 `:183`、`:184`、`:185`（共 4 行）

- **判定理由**：`bookshelfRefreshingLimit`（`BookshelfViewModel.kt:1114-1115`、`:1165-1166`）、`showWaitUpCount`（`:1289`）、`autoRefreshBook`（`:786`，键名 `auto_refresh`，`constant/PreferKey.kt:146`）三者都是「批量更新书籍目录」的配套。本地目前没有在线书源，目录刷新无对象；但**在线书源抓取自 2026-11-09 起已纳入范围**（[PROJECT.md](PROJECT.md) `:24-44` 的「在线服务」节，尚未排期），故改判「**要接，待排期**」——等书源接通后再补这三项，补法：`auto_refresh` 先做成开关，`bookshelfRefreshingLimit` 与 `showWaitUpCount` 随批量更新一起接。
- **验收**：无。

**KI-SL-N8 加载态与分页（不接）** —— 覆盖 E 块 `:187`、`:190`（共 2 行）

- **判定理由**：加载对话框（`BookshelfScreen.kt:1575-1602`，`if (uiState.isLoading)`）与分页惰性渲染（`:1669`，`!isCurrentPage` 时 return）都不由 bookshelfLayout 字段驱动，是主屏骨架行为，归 [BOOKSHELF.md](parity/BOOKSHELF.md) A1 的界面完整性。就本类别而言判 `不接`，不因此从对照表删行。
- **验收**：无。

**KI-SL-N9 锁定书卡片（不接）** —— 覆盖 B 块 `:123`（共 1 行）

- **判定理由**：`PrivateLockedBookItem`（`BookItem.kt:979`）的网格 / 列表两分支（`:1012` / `:1031`）读各自封面宽度（`:1025` / `:1041`）。本地无隐私书架锁定书卡片，无对应渲染分支。判 `不接`。
- **验收**：无。

---

### C 布局矩阵（3 组要接）

**KI-SL-C1 书籍横屏三项** —— 覆盖 C 块 `:136`、`:137`、`:138`（共 3 行）

- **上游口径**：`BookshelfScreen.kt:1698-1699` 取 `isLandscape`，`:1700-1701` / `:1705-1706` / `:1710-1711` 分别按横竖屏取 `bookshelfLayoutMode*` / `bookshelfLayoutGrid*` / `bookshelfLayoutList*`，`:1715` 统一成 `columns`。
- **本地现状**：字段只有竖屏三键（`entry/src/main/ets/model/BookshelfLayout.ets:17`、`:19`、`:21`）；无横竖屏判断（全局前置 2）。
- **补法**：先建窗口尺寸读取入口（HOS 用 `window.getLastWindow` 取窗口矩形或 `display.getDefaultDisplaySync()`，**不是** Android 的 `LocalConfiguration`），再补 3 个 Landscape 字段与仓储，`BookshelfPage.ets:419-427` 的 `bookshelfColumnsTemplate()` 按方向取不同值。
- **验收**：同一台设备横屏后网格列数变为横屏设置值，转回竖屏恢复竖屏值。
- 实现记录（r331）：`BookshelfPage.ets` 已落地 `isLandscape`（`:100`）、窗口矩形读取（`:160-177`）、`activeLayoutMode`/`activeGridColumns`/`activeListColumns`（`:551-565`）与三处按方向取值（`:1216`）。
- **已补横屏面板入口（r332）**：修复前面板布局模式的两个分支都写竖屏字段（`draft.bookshelfLayoutModePortrait`），横屏下改不了横屏值。现改为 `activeDraftLayoutMode()`/`activeDraftGridColumns()`/`activeDraftListColumns()`（`:569-585`）按 `isLandscape` 读写，标签随之变为「横屏下的书架呈现方式」（`:883-890`），对齐上游 `BookshelfConfigSheet.kt:247-265`、`:284-300`、`:412-424` 的 `it.copy(...Landscape = value)`。
- **已补列数上限（r332）**：`bookshelfColumnsTemplate()`/`bookshelfColumnCount()`（`:620-638`）原 `maximum = mode === 1 ? 6 : 5` 把横屏默认 7 压成 6，现改为渲染处只设下限 `Math.max(1, Math.round(configured))`，步进器上限改网格 1..15、列表 1..5，对齐上游 `BookshelfConfigSheet.kt:288`（`1f..15f`）与 `:412`（`1f..5f`）。
- **设备横屏已验（r332）**：模拟器实例 `config.ini` 的 `hw.lcd.single.width/height` 对调冷启动即得横屏 2832×1280（`hw.lcd.phy.*` 同步对调），C 块 `:136`/`:137`/`:138` 三行已改 `已接`，证据 `land-list.jpeg`、`land-after4.json`、`land-modemenu.json`。

**KI-SL-C2 文件夹六项** —— 覆盖 C 块 `:139`、`:140`、`:141`、`:142`、`:143`、`:144`（共 6 行）

- **上游口径**：`BookshelfScreen.kt:526-539` 按横竖屏取 6 个 `bookshelfFolderLayout*` 值，`:985` `folderColumns = if (bookshelfFolderLayoutMode == 0) bookshelfFolderLayoutList else bookshelfFolderLayoutGrid`，`:988` `GridCells.Fixed(folderColumns.coerceAtLeast(1))`。
- **本地现状**：6 个字段全无，且无文件夹视图（KI-SL-A1）。
- **补法**：随 KI-SL-A1 一起做；取值分支照 `:985` 的两级判断。
- **验收**：开文件夹样式后，竖屏改网格列数为 4、横屏为 6，两种方向各生效。
- **已实现（r331）**：C 块 `:139`、`:140`、`:141`（竖屏三项）改 `已接`。`BookshelfPage.ets:587-603` 的 `activeFolderLayoutMode` / `activeFolderGridColumns` / `activeFolderListColumns` 按 `isLandscape` 取值，`:609-618` `folderColumnsTemplate()` 照上游 `:985` 的两级判断（mode===0 取列表列数否则网格列数）并只设下限，`:1110` 挂到 `.columnsTemplate`。竖屏网格列数 3→4 生效见 `b5-folder-col4.png`、重开读回 4 见 `b5-col4v.json`。
- **横屏三项已验（r332）**：C 块 `:142`、`:143`、`:144` 改 `已接`。横屏下分组样式选「文件夹」后面板展开「文件夹（横屏）」分区（`:841-857`），实测：网格列数 7→15 后根层两张分组卡宽 159≈2832/15（`land-c15.json`）；模式切「列表」后单卡铺满整行（`land-flist.json`）；列表列数 1→3 后两张卡横向并排、各宽 907≈2832/3（`land-flc3.json`、`land-flc3.jpeg`）。
- **顺带修掉的一处缺陷（r332）**：`文件夹列表列数·竖屏/横屏` 与 `书名行数` 三个步进器的回调原先直接 `+= delta` 不夹取，实测把横屏列表列数减到了 **-22**；现三处都改为 `Math.max(下限, Math.min(上限, 值 + delta))`，与其余步进器一致。

**KI-SL-C3 首屏封面预加载列数** —— 覆盖 C 块 `:145`（共 1 行）

- **上游口径**：`ui/main/bookshelf/BookshelfCoverPreloader.kt:261-280` `resolveFirstScreenLayout`：列表时 1 列，网格时按横竖屏取 `bookshelfLayoutGrid*`，`:278` 乘预估可见行数并夹在 `MAX_PRELOAD_BOOKS` 内。
- **本地现状**：本地无预加载器，封面图由各卡片自行加载（`entry/src/main/ets/components/BookCover.ets`）。
- **补法**：随 KI-SL-C1 一起做（要先有横竖屏取值）；预加载数量按列数 × 可见行数算，超上限截断。
- **验收**：首屏滚动时封面不出现空窗，且预加载数量不超过列数 × 可见行数。
- 实现记录（r331）：本地无封面预加载器（`grep -rni preload entry/src/main/ets` 零命中），按任务书 `:166-168` 处置为「记录为无预加载器、按 0 处理」，落点是 `BookshelfPage.ets:20-26` 的 `BOOKSHELF_FIRST_SCREEN_PRELOAD_COLUMNS = 0` 常量与中文注释；不新建预加载系统，C 块 `:145` 留 `未接`，卡点见证据包第 4 节。

### 不接行归属核对

上节只对 `要接` 组给了补法与验收；r331 版那 41 条 `不接` 行同样逐行登记在上文 K 组（KI-SL-N1 ~ N9），覆盖关系如下。**注意：这是 2026-11-15 复核前的历史判定**，复核后 41 行里 35 行改判 `已接`、5 行改判 `**要接**`，只剩 B 块 `:124` 分组封面阴影仍是 `**不接**`，故下表的覆盖关系不再对应现表的 `不接` 计数：

| 组 | 覆盖行 | 行数 | 归属 |
| --- | --- | --- | --- |
| KI-SL-N1 列表专属版式与详情微调 | A `:47`、`:56`、`:62`、`:63`、`:66`、`:67`；B `:106`、`:107`、`:111`、`:113`、`:114` | 11 | 随列表模式（前置 1） |
| KI-SL-N2 标签体系 | A `:68`、`:69`；B `:118`、`:119` | 4 | 随列表模式与紧凑模式 |
| KI-SL-N3 标签配色 | A `:70`、`:71` | 2 | 转 [ZIP-THEME.md](parity/ZIP-THEME.md) |
| KI-SL-N4 角标与提示信息 | A `:74`~`:79`；B `:115`、`:116`、`:117`、`:121` | 10 | 信息密度扩展，暂不做 |
| KI-SL-N5 二级弹层三项 | A `:84`、`:85`、`:86` | 3 | 随标签体系 |
| KI-SL-N6 分组卡片增强 | A `:82`；B `:108`；E `:180`、`:182` | 4 | 等 KI-SL-A1 |
| KI-SL-N7 批量更新与后台任务 | A `:83`；E `:183`、`:184`、`:185` | 4 | 要接，随在线书源排期 |
| KI-SL-N8 加载态与分页 | E `:187`、`:190` | 2 | 归 BOOKSHELF.md A1 |
| KI-SL-N9 锁定书卡片 | B `:123` | 1 | 无隐私书架 |

合计 41 行，与 r331 版对照表的 `**不接**` 计数一致；2026-11-15 复核后对照表只剩 1 行 `**不接**`（B 块 `:124`，分组封面阴影），其余 40 行已分别改判 `已接` 或 `**要接**`。

---

## 封面配置行登记（ZIP-COVER.md 的未接行）

本节登记 [封面设置总账](parity/ZIP-COVER.md) A–E 块里 6 行 `未接` 的「接不接、怎么接」。编号 `KI-COVER<序号>` 与对照表「备注」列的 `KI-COVERn` 标记一一对应，组内先列覆盖的对照表行号（行号为 ZIP-COVER.md 的行号），再给上游口径、本地现状、补法或理由、验收。**本节只登记，不改 `.ets` 代码。**

**判定口径**：按 [PROJECT.md](PROJECT.md) 与 PARITY-RULES.md 第三节。在线书源抓取自 2026-11-09 起已纳入范围（`PROJECT.md:24-44`，尚未排期），依赖它的封面规则求值（C6）与网络封面（A10）等记「要接，待排期」；仍在[范围之外](PROJECT.md)（`PROJECT.md:46-48`）的只有 AI 在线服务、云同步与额外设备形态。判「不接」的**不删行、不改状态**，对照表里仍按 `未接` 计，只在备注与本节点明理由。

**与对照表状态的关系**：ZIP-COVER.md 只有 `已接 / 未接 / 不适用` 三值，不设「部分接」。本节的「要接」是排期结论，「不接」是范围结论，两者都不改变对照表的 `未接` 状态。全表 66 行 = 58 已接 / 6 未接 / 2 不适用（r334 实现段收口，C8 于 2026-11-09 改判 `已接`）；6 行未接分别是 A1 仅 WiFi（`:86`）、A10 网络书籍角标（`:95`）、B15 旧版默认封面迁移（`:131`）、C6 规则求值（`:146`）、C9 备份开关（`:149`）、D18 预加载（`:180`）。

**排期分布**：原登记 39 条 `要接`，r334 实现段（批 0–4）落地后已收口 32 条，2026-11-09 C8 单独接通后再收口 1 条，剩 6 条未接（A1 仅 WiFi、A10 网络书籍角标、B15 旧版默认封面迁移、C6 规则求值、C9 备份开关、D18 预加载）。其中 **B15 是 r334 收尾时才从 `已接` 改回 `未接` 的**——相册三视图与数据层都做了，但「旧版 `defaultCover` 偏好 → `default-cover` 相册」这条迁移本地没有实现，也没有迁移对象（`CoverSettings.defaultCover` 全仓无人写值）。各组的原始排期口径保留在下面各组里，作为「当初为什么这么切」的记录。

**全局前置（r334 已全部完成，保留作为当初的排期依据）**：

1. ~~**`CoverSettings` 字段补齐与键名映射**~~ **已完成（r334 批 0）**：`CoverSettings` 已补到 18 字段（`data/CoverSettingsRepository.ets:13`-`:55`，新增 `loadOnlyOnWifi`/`useDefaultCover`/`restrictCoverRatio`/`exploreFilterState`/`defaultCover`/`defaultCoverDark`）；双向映射表落在 `data/CoverSettingsRepository.ets:262 coverSettingsToAndroid()`（14 对）与 `:286 applyAndroidCoverPreferences()`。落盘键仍是裸字段名（`:135-146`），备份时经映射表转成上游 PreferKey 名——两套名字并存但已不再是缺口。
2. ~~**`config.xml` 白名单**~~ **已完成（r334 批 4）**：写出改成 `data/BackupRepository.ets:946`-`:951`（14 键按映射表逐键写，受 `:946` 的 `if (!ignoredCategories.includes('coverConfig'))` 门控）；恢复侧 `restoreCoverSettings()` 定义 `:1825`（`:1825`-`:1839` 逐键读回、`:1535` 调用点）。本地仍是白名单式逐键写（与上游「整表 `asMap()` + 黑名单」不同），这是本地备份写入方式决定的，不是缺口。

---

### 未接行（7 组）

**KI-COVER1 仅 WiFi 下载封面 / 使用默认封面 / 封面预加载** —— 覆盖 A 块 `:86`（A1）、`:88`（A3）、D 块 `:180`（D18），共 3 行

- **上游口径**：三个开关串成一条取图链路。`useDefaultCover` 打开时 `model/BookCover.kt:125` 直接返回默认封面图并 `centerCrop()`；`loadOnlyOnWifi` 经 `OkHttpModelLoader.loadOnlyWifiOption`（`model/BookCover.kt:129`）挂到每个图片请求上，消费点还有 `CoilBookCover.kt:227`、`ui/main/bookshelf/BookshelfCoverPreloader.kt:183`、`ui/book/info/BookInfoViewModel.kt:852`、`:2151`、`ui/book/readaloud/player/PlayerThemeOverride.kt:52`；预加载器 `ui/main/bookshelf/BookshelfCoverPreloader.kt:125` 在 `MainActivity.kt:341` 起，`preloadCurrentGroupFirstScreen()`（`:149`）按首屏可见量批量入队。
- **本地现状（r334 之后按实测定稿，三行分化）**：
  - **A3 使用默认封面 → 已接**。字段 `data/CoverSettingsRepository.ets:46`（默认 `:79`、落盘 `:185`、回填 `:149`-`:150`）；设置页开关 `pages/AppCoverSettingsPage.ets:281`-`:285`；渲染侧 `components/BookCover.ets:93`-`:99` 的 `effectiveCoverUri()`——`useDefaultCover` 为真时返回 `CoverAlbumRepository.defaultCoverPath(this.isNight)`（定义 `data/CoverAlbumRepository.ets:92`），没有相册图就返回空串走文字占位（`:152` `if (this.hasCoverImage())` 早退）。**开关关掉再打开、切夜间换图，屏幕上都看得见。**
  - **A1 仅 WiFi → 仍 `未接`**。字段与开关都在（`CoverSettingsRepository.ets:44` / `AppCoverSettingsPage.ets:277`-`:278`），也参与备份往返（映射 `:277` 的 `loadCoverOnlyWifi`、回填 `:354`-`:356`），但 `entry/src/main/ets` 全目录 `loadOnlyOnWifi` 除设置页与仓储外**零命中**——没有请求侧消费端，开关拨了不改变任何屏幕现象。按 PARITY-RULES 第三节「`已接` 必须写得出屏幕现象」判 `未接`。
  - **D18 预加载 → 仍 `未接`**。`entry/src/main/ets` 全目录 `preload|预加载` 只命中 `pages/BookshelfPage.ets:24`-`:29` 的说明注释与 `BOOKSHELF_FIRST_SCREEN_PRELOAD_COLUMNS = 0` 常量，封面由各卡片自行加载（`components/BookCover.ets` 直接 `Image(...)`）。
- **补法**：~~先在 `CoverSettingsRepository.ets` 补 `loadOnlyOnWifi` / `useDefaultCover` 两字段；`useDefaultCover` 的分支加在 `components/BookCover.ets:154` 之前~~ **已完成（r334）**——两字段在（键名照 `data/BackupRepository.ets:450`-`:454` 的 `coverConfig` 键组取 `loadCoverOnlyWifi` / `useDefaultCover`），`useDefaultCover` 分支落在 `components/BookCover.ets:93`-`:99`。剩两件：①`loadOnlyOnWifi` 的消费端——需先确认本地图片加载是否走 `@ohos.net.http`，若是，在请求前读一次网络类型；②预加载（D18）单独排期，用 `List` 的可见区回调取首屏条目，不要照搬上游的行列算法（本地没有横竖屏取值）。
- **验收**：断 WiFi 用蜂窝网络进书架，开着「仅 WiFi 下载封面」时封面显示书本图标占位、不发起请求；接上 WiFi 后封面加载出来。打开「使用默认封面」后书架所有书封面变成默认封面图，关掉后真实封面回来。

**KI-COVER2 封面规则（UI + 求值 + 存储 + 备份）** —— 覆盖 A 块 `:87`（A2），C 块 `:141`、`:142`、`:143`、`:144`、`:145`、`:146`、`:147`、`:148`、`:149`（C1–C9），共 10 行

- **上游口径**：入口在设置页 `ui/config/coverConfig/CoverConfigScreen.kt:105-109`，sheet 是 `ui/config/coverConfig/CoverRuleConfigSheet.kt:25-83`（勾选 `:61-65`、搜索 URL `:67-72`、规则表达式 `:74-80`、恢复默认 `:35-43`、保存 `:44-52`）。保存校验 `ui/config/coverConfig/CoverConfigViewModel.kt:130-133`（URL 或规则为空时 toast `cover_rule_fields_required` 并 return）。运行期存 `CacheManager` 键 `legadoCoverRuleConfig`（`model/BookCover.kt:51`，读 `:246-249`、写 `:276-278`、删 `:280-282`），`coverRule.json`（`:52`）只用于备份写出（`help/storage/Backup.kt:251-256`）与恢复读入（`help/storage/Restore.kt:339-346`）。求值 `model/BookCover.kt:251-269`：未启用/空 URL/空规则返回 null，否则 `AnalyzeUrl` + `getStrResponseAwait()` + `AnalyzeRule.getString(coverRule, isUrl = true)`；唯一调用点 `ui/book/info/BookInfoViewModel.kt:1275`，前置条件 `:1274` 是 `coverUrl` 与 `customCoverUrl` 都为空。
- **本地现状（r334 之后按实测定稿，10 行分化）**：
  - **C1–C5、C7、C9 → 已接**。模型 `data/CoverRuleRepository.ets`（155 行）有 `export interface CoverRule`（`:22`-`:43`，9 字段齐：`enable`/`searchUrl`/`coverRule`/`concurrentRate`/`loginUrl`/`loginUi`/`header`/`jsLib`/`enabledCookieJar`）、`DEFAULT_COVER_RULE`（`:41`）、`copyCoverRule`（`:54`）、`isDefaultCoverRule`（`:69`）、`class CoverRuleRepository`（`:75`，`get` `:80`、`load` `:89` 逐 9 字段读回、`save` `:113`、`del` `:135`）。UI 入口在 `pages/AppCoverSettingsPage.ets:280`（`CoverSettingsAction({ title: '封面规则', detail: '编辑按规则获取封面用的搜索源与规则表达式', onSelect: () => this.openRuleSheet() })`），sheet 打开 `:98`-`:99`（先 `loadRuleIntoDraft(CoverRuleRepository.get())`）、标题 `:389`、启用勾选 `:400`-`:402`、搜索 URL `:406` 起、规则表达式 `:416` 起、恢复默认 `:391`、保存 `:393` + `:115`-`:126`（校验失败 `:122` 提示「封面规则保存失败，当前值未更改」）。**C8 备份读写也已接**：写出 `data/BackupRepository.ets:956`-`:960`（`:957` `if (!isDefaultCoverRule(coverRule))` 门控，与默认一致则不写）、恢复 `:1468`-`:1481`、解析 `parseCoverRule` 定义 `:2673`；清单登记在 `:459`-`:467`（`fileNames`）与 `:474`。
  - **C6 规则求值 → 仍 `未接`**（见补法②）。
  - 本地仍没有 `CacheManager` 等价物：规则值直接落本地 preferences，不存运行期缓存。
- **补法**：**拆成两段**。①UI + 存储（C1–C5、C7、C9）是纯本地：按 `CoverRule` 9 字段（`model/BookCover.kt:286-294`）建模型，存到 preferences（本地没有 `caches` 表，用独立 prefs 文件更贴近现有做法），sheet 照 `CoverRuleConfigSheet.kt` 三段布局。②求值（C6）**随规则引擎一起接**（`coverRule.json` 的备份读写 C8 已在 r334 单独接通，见上面「本地现状」）——默认规则 `app/src/main/assets/defaultData/coverRule.json` 的 `coverRule` 是一段 `@js:` 脚本，里面用 `java.base64Encode`、`java.ajaxAll`、`com.jayway.jsonpath.JsonPath` 这些 Java 桥接口，终点是 `https://pre-api.tuishujun.com/...` 与 `http://m.ypshuo.com/...` 两个在线搜索接口，没有规则引擎与 JS 运行时就是死代码。注意封面规则求值走的是同一套 `AnalyzeUrl`/`AnalyzeRule` 管线，在线书源抓取自 2026-11-09 起**已纳入范围、尚未排期**（[PROJECT.md](PROJECT.md) `:24-44`），所以这一条不是「不接」，而是「要接，随规则引擎与在线书源一起做」。
- **验收**：①UI 段——设置页点「封面规则」弹 sheet，勾「启用」、填 URL 与表达式，点保存后退出重进内容还在；URL 或表达式留空时点保存弹「请填写必填项」且不落盘；点「恢复默认」后两个输入框变默认脚本。②求值段——书详情页对一本 coverUrl 与 customCoverUrl 都为空的网络书，规则命中后封面自动变成搜索结果图。

**KI-COVER3 默认封面相册（整块）** —— 覆盖 A 块 `:89`（A4），B 块 `:117`、`:118`、`:119`、`:120`、`:121`、`:122`、`:123`、`:124`、`:125`、`:126`、`:127`、`:128`、`:129`、`:130`、`:131`（B1–B15），E 块 `:193`（E4）、`:194`（E5）、`:195`（E6），共 19 行

- **上游口径**：数据层 `data/repository/CoverAlbumRepository.kt`（508 行）——根目录 `:49-53` `File(context.getExternalFilesDir(null) ?: context.filesDir, "cover_albums")`，索引 `albums.json`（`:43`），`FORMAT_VERSION = 2`（`:41`），迁移遗留相册 id `"default-cover"`（`:44`）；JSON 只存文件名（`:357-358`），图片按 SHA-256 命名（`:325-326`），写入走临时文件 + `ATOMIC_MOVE`（`:349-380`）。三个选择键在 `data/local/preferences/LocalPreferences.kt:61-63`（`selected_cover_album_id` / `selected_light_cover_album_id` / `selected_dark_cover_album_id`），读取 `CoverAlbumRepository.kt:55-70`，优先链 `albumId ?: lightAlbumId ?: darkAlbumId`（`:75-81`）。日夜两套图是 `CoverAlbum.lightImages` / `darkImages`（`domain/model/CoverAlbum.kt:8-9`），取用 `:90-96`。UI 两块：选择 sheet `ui/config/coverConfig/CoverAlbumSelectSheet.kt`（164 行，「无」项 `:61-71`，相册项 `:72-85`，条目组件 `:90-164`）与管理页 `ui/config/coverConfig/CoverAlbumManageScreen.kt`（449 行，顶栏新建 `:135-139`，空态 `:144-166`，卡片 `:215-297`，编辑器 `:299-381`，对话框 `:383-418`，命名框 `:420-449`）。空相册行为：选「无」时 `onSelect(null)`（`CoverAlbumSelectSheet.kt:67-70`），相册本身为空时管理页显示 `cover_album_empty` 空态（`:161-164`）。迁移 `CoverAlbumRepository.kt:231-284`：读 `PreferKey.defaultCover` / `defaultCoverDark` 逗号串，合并进 `default-cover` 相册并 `distinctBy { it.id }`（`:266-273`），写 `COVER_ALBUM_MIGRATED = true`（`:281`）。
- **本地现状（r334 之后按实测定稿，19 行分化）**：
  - **A4 与 B1–B14、E4–E6 共 18 行 → 已接**。数据层 `data/CoverAlbumRepository.ets`（357 行）已落地：根目录 `context.filesDir/cover_albums`（`:105`，`directoryName` 定义 `:61`）、索引 `albums.json`（`:62`）、`class CoverAlbumRepository` `:60`、`defaultCoverPath(isNight)` `:92`、`load` `:141` 区、`createAlbum`/`renameAlbum`/`deleteAlbum`/`setSelection`/`addImages`/`removeImage`、`previewPath`。头注释 `:10`-`:18` 说明「本地没有 `getExternalFilesDir`，统一用 `context.filesDir/cover_albums`」。UI 在 `pages/AppCoverSettingsPage.ets`（729 行）的同一个 `bindSheet` 里按 `albumView` 分四层（`:53` `@State albumView: string = 'select'`）：`select` `:427`-`:470`（标题「选择封面相册」`:430`、「无」项 `:440`-`:443`、相册项 `:456`-`:469`）、`manage` `:472`-`:525`（「封面相册」`:477`、「暂无相册」空态 `:489`、卡片 `:498`-`:523`、「使用中」标记 `:505`）、`editor` `:527`-`:570`（白天/夜间页签 `:540`/`:544`、「添加图片」`:563`）、`name` `:572`-`:594`（「新建相册」/「重命名相册」`:572`、取消 `:580`、确定 `:583`）。删除二次确认 `:194`-`:198`（文案带相册名）。`CoverSettings` 两字段在（`data/CoverSettingsRepository.ets:52`/`:54`，默认 `:82`/`:83`，落盘 `:188`/`:189`，不参与备份）；渲染侧 `components/BookCover.ets:93`-`:99` 已走 `CoverAlbumRepository.defaultCoverPath`。
  - **B15 旧版默认封面迁移 → 仍 `未接`**：`CoverSettings.defaultCover` 全仓无人写值，没有迁移对象，也没有迁移代码。
  - 本地封面来源除相册外仍是两条：EPUB 内嵌封面（`data/EpubRepository.ets:109` `coverUri = 'file://${coverPath}'`）与手动选图（`pages/Index.ets:6151`-`:6166 chooseBookCover()` / `:6168`-`:6176 restoreBookCover()`，落 `data/BookRepository.ets:605`-`:607 copyWithCover`）。
- **补法（r334 已按四件套落地，保留作为当初的拆解依据）**：①仓储 —— `data/CoverAlbumRepository.ets` 已建，根目录 `context.filesDir/cover_albums`（本地没有 `getExternalFilesDir` 等价物）；②两页 UI —— 选择 sheet 与「管理 / 编辑器 / 命名」三视图都做在 `pages/AppCoverSettingsPage.ets` 的同一个 `bindSheet` 里，按 `albumView` 切换，没有另开页面；③`CoverSettings` 的 `defaultCover` / `defaultCoverDark` 两字段已在（`:52`/`:54`）；④渲染侧 `components/BookCover.ets:93`-`:99` 已接「从相册取图」，取不到走文字占位。**剩 B15 一项**：旧版 `defaultCover` 偏好 → `default-cover` 相册的迁移没有实现，本地也确实没有旧版 `defaultCover` 字符串可迁，这一条保留 `未接` 但属于「要接了才有意义」。
- **验收**：设置页「默认封面」→ 弹相册选择 sheet 看到「无」与自建相册；新建一个相册、白天加 3 张图、夜间加 2 张；返回设置页该行摘要变成「相册名 · 日 3 / 夜 2」；书架页无封面的书显示相册里的图，切到夜间模式后换成夜间那 2 张；杀掉进程重进相册还在。

**KI-COVER4 限制封面比例** —— 覆盖 A 块 `:93`（A8）、E 块 `:191`（E2），共 2 行

- **上游口径**：设置项 `ui/config/coverConfig/CoverConfigScreen.kt:158-165`（`checked = settings.restrictCoverRatio`，`:161`）；字段 `domain/model/settings/CoverSettings.kt:10`（默认 `true`，注释「开启（默认）时搜索/发现/详情页封面固定 5:7」）；消费点两处——`ui/book/info/BookInfoScreen.kt:1169` 与 `ui/widget/components/book/SearchBookItem.kt:85`，都是 `!LocalAppUiConfiguration.current.cover.restrictCoverRatio` 决定封面用固定 5:7 还是按图片真实宽高比。键不在 14 个 `coverPrefKeys` 里（`help/storage/BackupConfig.kt:396-411`），也不在 `alwaysIgnoredPreferenceKeys`（`:11-33`），所以参与备份但不受忽略开关控制。
- **本地现状（r334 已接）**：字段在（`data/CoverSettingsRepository.ets:48`，默认 `true` `:80`，落盘 `:186`，回填 `:151`-`:152`）；设置页在「书架显示」组有开关（`pages/AppCoverSettingsPage.ets:312`-`:316`）；渲染侧 `components/BookCover.ets:73` 的 `if (!this.applyAspectRatio || this.coverSettings.restrictCoverRatio)` 与 `:292` 的 `if (this.applyAspectRatio && !this.coverSettings.restrictCoverRatio && this.coverAspectRatio > 0)`——关掉后按原图宽高比（`ImageSeedColorExtractor.coverAspectRatio`，`:82`-`:84` 取比例，读不到回落 5:7）。备份往返：写出 `data/BackupRepository.ets:678`（`coverRestrictRatio`，无条件区 `:675`-`:679` 之一）、恢复 `:1835`/`:1855`。
- **补法**：~~`CoverSettingsRepository.ets` 补 `restrictCoverRatio`；设置页加一条 Switch；渲染侧把固定的 `7/5` 改成条件~~ **已完成（r334）**——字段（默认 `true`，与上游一致）、开关、`BookCover.ets:73`/`:292` 的条件分支都在。**遗留一处口径差**：上游这个开关只作用于搜索/发现/详情页，书架页封面恒为固定比例；本地是把 `applyAspectRatio` 作为调用点开关（`BookCover.ets:73`），哪些界面打开它由调用方决定，因此需要在接搜索/发现/详情页时逐个确认是否传 `applyAspectRatio: true`。
- **验收**：关掉「限制封面比例」后，搜索结果页与书籍详情页的封面按图片原始宽高比显示（宽图变宽、窄图变窄），书架页封面形状不变；重开后回到 5:7。

**KI-COVER5 网络书籍角标（发现页筛选）** —— 覆盖 A 块 `:95`（A10）、E 块 `:192`（E3），共 2 行

- **上游口径**：设置项 `ui/config/coverConfig/CoverConfigScreen.kt:184-197`，四档 `entryValues = arrayOf("0","1","2","3")`（全部 / 书架内隐藏 / 同名同作者隐藏 / 只显示不在书架内的）；字段 `CoverSettings.kt:23` 默认 `0`；唯一消费点 `ui/book/explore/ExploreShowViewModel.kt:249` `filterStateId = coverSettings.exploreFilterState`。键名是 **`explore_filter_state`**（`constant/PreferKey.kt:429`），不是字段名 `exploreFilterState`——按字段名 grep 会误判成 0 命中。不在 14 个 `coverPrefKeys`、不在 `alwaysIgnoredPreferenceKeys`。
- **本地现状（r334 之后按实测定稿，2 行分化）**：
  - **E3 上游键归属 → 已接**：键 `explore_filter_state` 的备份往返在——写出 `data/BackupRepository.ets:679`（无条件区 `:675`-`:679`），恢复 `:1836`/`:1856`。
  - **A10 网络书籍角标 → 仍 `未接`**：字段 `data/CoverSettingsRepository.ets:50`（默认 `0` `:81`，落盘 `:187`，回填 `:153`-`:154`）；设置页有四档条目 `pages/AppCoverSettingsPage.ets:317`-`:324` 的 `CoverSettingsChoice`（`['全部显示','隐藏书架内','隐藏同名同作者','仅显示书架外']`，`onSelect` 写 `draft.exploreFilterState = index` `:321`）；但 `entry/src/main/ets` 全目录 `exploreFilterState|filterState` 除设置页写值与备份读写外**零命中消费端**——发现页 `pages/DiscoverPage.ets:62` 只有本地示范数据过滤（`this.sources.filter(...)`），不读这个字段。**有字段、有四档条目、有备份往返，缺的是筛选消费点。**
- **补法**：~~先补字段与设置项（四档 Dropdown）~~ **已完成（r334）**——字段与四档条目都在（见上）。**剩筛选消费点，取决于发现页本身**：本地发现页是示范数据页（`pages/DiscoverPage.ets`），没有真实书源列表，「按是否在书架内筛选」没有筛选对象。筛选逻辑跟着发现页的数据源一起写。这里不判「不接」，因为发现页本身不在任何「范围之外」条目里；在线书源抓取自 2026-11-09 起已纳入范围（[PROJECT.md](PROJECT.md) `:24-44`，尚未排期），发现页接真实数据后可随之排期。
- **验收**：发现页出现书籍列表后，设置页把「网络书籍角标」切到「书架内隐藏」，发现页里已在书架的书消失；切回「全部」后重新出现。

**KI-COVER8 夜间·显示书名 / 显示作者** —— 覆盖 A 块 `:102`（A17）、`:103`（A18），共 2 行

- **上游口径**：`ui/widget/components/image/cover/CoilBookCover.kt:518-520` 按 `isNight` 分叉选字段（`if (isNight) coverSettings.showNameDark else coverSettings.showName`），`:522` `if (!showName && !showAuthor) return`；设置页两项 `CoverConfigScreen.kt:306-313` 与 `:315-323`，后者 `enabled = settings.showNameDark`（`:319`）。
- **本地现状（r334 已接）**：字段在（`data/CoverSettingsRepository.ets:13`-`:55` 有 `showNameDark` / `showAuthorDark`），开关能落盘，**渲染层也已读**——`components/CoverTextLayout.ets:66`-`:69` 签名带 `isNight: boolean = false`，`:77 const showName = isNight ? settings.showNameDark : settings.showName;`、`:78 const showAuthor = (isNight ? settings.showAuthorDark : settings.showAuthor) && showName;`；`components/BookCover.ets:48 @Prop isNight`、`:154` 传进 `buildCoverTextLayout`；`pages/BookshelfPage.ets:1153`/`:1182`/`:1242` 传 `readerNightMode`。旧描述里提到的 `effectiveShowName()`/`effectiveShowAuthor()` 两个按日夜分叉的中间函数**已整个删除**（全仓 grep 零命中），r331 之前那种「夜间关掉『显示书名』字仍在」的现象已不存在。字段接口实测为 `data/CoverSettingsRepository.ets:13`-`:55`（18 字段），`showNameDark` 在 `:19`、`showAuthorDark` 在 `:21`。
- **补法**：~~把 `isNight` 传进排版函数~~ **已完成（r334）**——`components/BookCover.ets:153`-`:154` 调用 `buildCoverTextLayout(widthVp, heightVp, this.book.title, this.book.author, this.coverSettings, 1.2, this.isNight);`，签名在 `components/CoverTextLayout.ets:66`-`:69`，字段三元式在 `:77`-`:78`。`enabled` 联动也已完成：`pages/AppCoverSettingsPage.ets:343` 日间作者行 `disabled: !this.settings.showName`、`:365` 夜间作者行 `disabled: !this.settings.showNameDark`（**KI-COVER7 一并结清**）。
- **验收**：书架页任一无封面书籍，切到夜间模式后关掉「夜间·显示书名」，卡片上的书名与作者一起消失（白天模式下仍显示）；再打开后恢复；关掉夜间「显示书名」时夜间「显示作者」那一行置灰不可点。

**KI-COVER9 14 个 `coverPrefKeys` 的读写** —— 覆盖 E 块 `:190`（E1），共 1 行

- **上游口径**：`help/storage/BackupConfig.kt:396-411` 列了 14 个键（`useDefaultCover`、`loadCoverOnlyWifi`、`coverShowName`、`coverShowAuthor`、`coverShowNameN`、`coverShowAuthorN`、`coverShowShadow`、`coverShowStroke`、`coverTextColor`、`coverTextColorN`、`coverShadowColor`、`coverShadowColorN`、`coverDefaultColor`、`coverInfoOrientation`）；写出在 `help/storage/Backup.kt:258`（`AppConfigStore.preferences.asMap()` 全量导出后按忽略规则过滤），恢复在 `help/storage/Restore.kt` 的 config.xml 分支。样本 `<workspace>测试\backup2026-10-22\config.xml` 里 14 个键全在（`:227`、`:228`、`:229`、`:231`、`:233`、`:236`、`:238`、`:240`、`:242`、`:245`、`:247`、`:249`、`:251`、`:252`）。
- **本地现状**：14 键清单常量在（`entry/src/main/ets/data/BackupRepository.ets:450`-`:454`，与上游逐键一致），同时也是 `filterAndroidConfigXml`（定义 `:2703`）的 `excludedKeys` 来源，用于从上游备份里剥掉这些键。**r334 已把读写都接通**：写出 `:946`-`:951`、恢复 `:1825`-`:1839`，键名映射走 `data/CoverSettingsRepository.ets:262 coverSettingsToAndroid` / `:286 applyAndroidCoverPreferences`（本地落盘仍是裸字段名 `showName`/`textColor`，`:172`-`:189` 的 `save` 段）。
- **补法**：先做上面「全局前置 1」的键名映射表（本地 `showName` ↔ `coverShowName`、`showNameDark` ↔ `coverShowNameN`、`textColor` ↔ `coverTextColor`、`textColorDark` ↔ `coverTextColorN`、`infoOrientation` ↔ `coverInfoOrientation`，其余同理）；r334 已按此补法落地：写出 `entry/src/main/ets/data/BackupRepository.ets:946`-`:951` 按 `coverSettingsToAndroid` 的映射逐键 upsert，恢复 `:1825`-`:1839` 反向回填。`data/CoverSettingsRepository.ets:4-12` 的头注释已改为「本地 preferences 用裸字段名，双向映射集中在 `coverSettingsToAndroid` / `applyAndroidCoverPreferences`」，与实现对上了。
- **验收**：把「显示字体描边」关掉 → 备份 → 解压 `config.xml` 里有 `<boolean name="coverShowStroke">false</boolean>`；把本地值改回 `true` → 恢复该 ZIP → 设置页「显示字体描边」变回关、书架页描边消失。

### 已接行上的残留差异（不属于上面 6 行未接，单独登记）

这两组在对照表里对应的行状态是 `已接`，功能可用、能看见屏幕效果，只是与上游的呈现方式不同。写在这里是为了让「改哪边算数」有落点，**不计入 6 行未接**。

**KI-COVER6 取色面板：任意取色 vs 6 个预置色轮换** —— 关联 A 块 `:96`（A11）、`:97`（A12）、`:100`（A15）、`:101`（A16）

- **上游口径**：点颜色行弹 `ColorPickerSheet`（调用 `ui/config/coverConfig/CoverConfigScreen.kt:349-372`，初始色映射 `:350-355`，`onColorSelected` 按 `CoverColorField` 分发到四个 intent `:361-370`），可在色环上取任意色。
- **本地现状**：`pages/AppCoverSettingsPage.ets:327`（日间文字颜色）/`:332`（日间阴影颜色）/`:349`（夜间文字颜色）/`:354`（夜间阴影颜色）四行是圆点式颜色行 + 点一下在 6 个预置色之间轮换，预置色 `TEXT_COLOR_OPTIONS`（定义 `:264` 起）＝ `'#000000', '#FFFFFF', '#E7E8ED', '#AFC2FF', '#E8B77B', '#9AD0B7'`。类型也不同：上游 `textColor: Int`（ARGB，默认 `-16777216`），本地 `textColor: string`（`'#RRGGBB'`，默认 `'#000000'`）。
- **补法**：若要与上游对齐，需要建一个取色器组件（HOS 有 `ColorPicker` 一类能力，具体 API 未查证），并把 `CoverSettings` 的颜色类型从 string 改成 number（会影响 `CoverSettingsRepository.ets:139`-`:142` 的 `readColor` 调用、`:205`-`:209` 的 `readColor` 定义、`:228`/`:241` 的 `coverColorToAndroidInt`/`androidIntToCoverColor`，以及 `components/BookCover.ets:114`-`:120` 的 `coverTextColor()`/`coverShadowColor()`）。
- **验收**：设置页点「文字颜色」弹出取色面板，任选一个色号后书架页无封面书籍的书名变成该色。

**KI-COVER7 开关联动置灰：`enabled = showName`** —— 关联 A 块 `:99`（A14）、`:103`（A18）

- **上游口径**：`CoverConfigScreen.kt:256` `enabled = settings.showName`（日间作者）/ `:319` `enabled = settings.showNameDark`（夜间作者）——书名关掉时作者那一行置灰不可点。
- **本地现状（r334 已接）**：`pages/AppCoverSettingsPage.ets:343` 日间作者行传 `disabled: !this.settings.showName`、`:365` 夜间作者行传 `disabled: !this.settings.showNameDark`；`CoverSettingsSwitch`（`AppCoverSettingsPage.ets:637`，`:645 @Prop disabled: boolean = false`）里 `.enabled(!this.disabled)` + `.opacity(this.disabled ? 0.4 : 1)`，disabled 时保留原值不重置，与上游一致。语义本身两边也一致（`components/CoverTextLayout.ets:77` 的 `&& showName`）。
- **补法**：~~`CoverSettingsSwitch` 加一个 `disabled` 参数~~ **已完成**——参数在 `:645`，两个调用点已传参（`:343`/`:365`）。
- **验收**：关掉「显示书名」后「显示作者」那一行变灰点不动；重开书名后恢复可点。

### 未接行归属核对

上表 7 组覆盖关系如下（KI-COVER6 / KI-COVER7 属「已接行上的残留差异」，不在本表），**r334 收口后 6 行未接没有一行缺少落点**：

| 组 | 覆盖行 | 行数 | 归属 | r334 后状态 |
| --- | --- | --- | --- | --- |
| KI-COVER1 仅 WiFi / 使用默认封面 / 预加载 | A `:86`、`:88`；D `:180` | 3 | 要接 | `:88` 已接；`:86`（仅 WiFi）与 `:180`（预加载）仍 `未接` |
| KI-COVER2 封面规则 | A `:87`；C `:141`、`:142`、`:143`、`:144`、`:145`、`:146`、`:147`、`:148`、`:149` | 10 | UI 要接；求值随规则引擎 | `:87`、`:141`–`:145`、`:147`–`:148` 已接；`:146`（规则求值）、`:149`（备份开关）仍 `未接` |
| KI-COVER3 默认封面相册 | A `:89`；B `:117`、`:118`、`:119`、`:120`、`:121`、`:122`、`:123`、`:124`、`:125`、`:126`、`:127`、`:128`、`:129`、`:130`、`:131`；E `:193`、`:194`、`:195` | 19 | 要接 | `:131`（B15 旧版迁移）仍 `未接`，其余 18 行已接 |
| KI-COVER4 限制封面比例 | A `:93`；E `:191` | 2 | 要接 | 全部已接 |
| KI-COVER5 网络书籍角标 | A `:95`；E `:192` | 2 | 要接（依赖发现页真实数据） | `:192` 已接；`:95` 仍 `未接`（本机不可观察） |
| KI-COVER8 夜间两开关 | A `:102`、`:103` | 2 | 要接（改两行） | 全部已接 |
| KI-COVER9 14 个封面键读写 | E `:190` | 1 | 要接（依赖键名映射） | 已接 |

合计 39 行登记，其中 33 行已接、6 行仍 `未接`（与对照表 `未接` 计数一致）。不适用 2 行（D 块 `:178` `CoverImageView`、`:179` `CoverBlurBackdrop`）不进本节——前者在上游全仓除定义处零调用点，后者本地没有播放器封面背景这类场景。

## 六格式实现（r344）留下的已知差异

批 1–13 把 TXT / EPUB / PDF / MOBI·AZW3 / UMD / 压缩包六条导入与阅读链路落地时，遇到六处「当时没修」或「只能近似」的地方。它们不影响主路径可用，但都真实存在，按 [`TXT-READER.md`](parity/TXT-READER.md) E–I 五块验收时逐条碰到过，登记在这里让「为什么是这个形态」有落点。**本节只登记，不改 `.ets` 代码。**

**KI-FMT1 导入失败的完整提示到不了屏幕** —— 关联 E16、F1、F7

- **现象**：源码层给的是可读文案（如「这台设备不支持 PDF 渲染（缺少 PDFKit 能力），暂时打不开 PDF」），但模拟器上看到的 toast 是「没有导入任何书籍」。
- **根因**：`pages/Index.ets` 的 `importSelectedLocalBooks()` 逐本调 `importOneLocalBook()`，「一本都没成功」时统一抛自己的提示，把内层 `showUnavailableAction('导入失败：' + message)` 那条覆盖掉了。用户读不到具体原因。
- **补法**：`importSelectedLocalBooks()` 汇总时把内层失败原因带出来（收 `failed: string[]` 后拼成「导入失败：<第一本的原因>」），或单本导入时直接显示内层文案、只在多本时补计数。
- **验收**：在模拟器上从文件选择器选一本 PDF，toast 里出现「这台设备不支持 PDF 渲染」，而不是「没有导入任何书籍」。

**KI-FMT2 PDF 页图没按屏宽渲染，分辨率由平台默认值决定** —— 关联 F4

- **现象**：`data/PdfRepository.ets` 用的是无参 `PdfPage.getPagePixelMap()`，渲出来的 PixelMap 是平台默认分辨率；「等比缩到屏宽」这一步交给排版层（`ReaderCanvasSurface` 按页宽缩放绘制），导入期不做重采样。
- **根因**：本批取的是「无参数、最少未知量」的那条渲染路径，因为模拟器没有 PDFKit 能力、带尺寸的渲染参数在真机上行为未核实，不想写一条自己验不了的调用。
- **平台能力其实够**：`@hms.officeservice.pdfservice.d.ts:2562` 的 `getAreaPixelMap(matrix, bitmapwidth, bitmapHeight, isGray, drawAnnotations)` 是 `@since 5.0.0(12)`，在本项目基线 `6.0.0(20)` 内；`getAreaPixelMapWithOptions(...)`（`:2573`）才是 `@since 5.1.0(18)`。所以这不是平台限制，是本批的取舍——**不能写成「平台做不到」**。
- **后果**：页图内存占用与落盘体积偏大，字号小的 PDF 全屏显示时可能不够锐利。上游 `PdfFile.openPdfPage` 是显式按屏幕宽算渲染尺寸的，本地这一步缺失。
- **补法**：真机上先验 `getAreaPixelMap` 的 `bitmapwidth`/`bitmapHeight` 语义（d.ts 写的是 points，不是像素），再按「屏宽 × 页宽高比」渲；验不通就退回无参版本并在本文件写明原因。
- **验收**：真机导入一本 45 页 PDF，页图落盘体积明显下降且放大后正文小字清晰。

**KI-FMT3 `docs/FEATURES.md` 的文件选择器描述已过时** —— 关联 F1、G1、H1、I1

- **现象**：`docs/FEATURES.md:26` 仍写「导入本地书：系统文件选择器，只列 `.txt` 与 `.epub`（`data/BookRepository.ets:437` 的 `fileSuffixFilters`）」，实际 `fileSuffixFilters` 已是七项（TXT / EPUB / PDF / MOBI / AZW3 / UMD / 压缩包），行号也从 `:437` 漂到 `:502` 一带。
- **根因**：r344 的范围文档改动按任务书只点了 `docs/PROJECT.md:9` 与 `docs/FEATURES.md:13` 两处，这一行不在点名范围，未擅自扩大改动。
- **补法**：把该行的后缀清单与行号更新为七项，并说明 rar / 7z 不在其中（平台无能力）。
- **验收**：无屏幕现象；以 `grep -n '只列' docs/FEATURES.md` 不再只命中 `.txt` 与 `.epub` 两项为准。

**KI-FMT4 ruby 注音删除是字符级近似，中文注音会留残形** —— 关联 E7

- **现象**：开了「删除ruby标签」后，日文书里连续假名被整段删掉（符合预期）；但中文注音书（`<ruby>汉字<rt>hànzì</rt></ruby>` 一类的拉丁字母或拼音）删完会剩下「汉字 + 零散字母」的残形。
- **根因**：本地正文在导入期就经 `htmlToText` 转成纯文本，`<rp>` / `<rt>` 标签此时已不存在，运行时只能按字符类别近似删除（`/[぀-ゟ゠-ヿｦ-ﾝ]+/g` 删连续假名）。上游是在 DOM 层按标签精确删的。
- **补法**：要精确只有两条路——①导入时把 ruby 元素边界标记写进正文（改动 `.txt` 中间格式，影响全部既有书），②运行时回原 xhtml 取（要留解压目录、重解析）。两条成本都远超本行价值，暂不做。
- **验收**：打开一本中文注音 EPUB 点「删除ruby标签」，正文里不该出现孤立字母。当前做不到，故登记。

**KI-FMT5 `display:none` 净化是有意近似，嵌层与自闭合认不全** —— 关联 E5

- **现象**：`<div style="display:none">…</div>` 这类「开标签带 style + 有对应闭标签」的隐藏块能被删；但嵌套结构、自闭合标签、`display : none` 中间夹换行的写法会漏。
- **根因**：本地没有 DOM，净化走正则。上游用 Jsoup 的 `[style*=display:none]` 选择器，也只匹配「属性里含这个子串」的元素，同样不是完整 CSS 求值——两边都是近似，只是容错面不同。
- **补法**：在片段级复用 EPUB 导入已有的 markup 中间态做元素裁剪，而不是在纯文本上补正则。
- **验收**：找一本用嵌套 `display:none` 藏脚注的 EPUB，正文里不该出现脚注文字。当前对嵌套形态做不到。

**KI-FMT6 MOBI 导入异常时不写 `intro` 兜底，简介字段留空** —— 关联 G13

- **现象**：EXTH 里没有 103（简介）记录的 MOBI，导入后详情页简介为空；上游在导入异常时写「书籍导入异常」。
- **根因**：本地 `MobiRepository.importFromUri` 的 `description` 一律给空串，没有照抄上游那条异常兜底文案。正常路径两边一致（都读 EXTH 103），差的是异常路径的一个可见提示。
- **补法**：导入流程 catch 到 MOBI 解析异常时把 `book.intro` 置成「书籍导入异常」再落库。
- **验收**：导入一个头部损坏的 .mobi，详情页简介显示「书籍导入异常」而不是空白。
---

## 动效六批（r347）留下的已知缺口

**KI-MOTION1 设置子页切换没有转场** —— 关联 [`VALIDATION.md`](VALIDATION.md) r347 一节批 4

- **现象**：r347 给非阅读页的路由分支补了统一转场，书架 ↔ 详情页 ↔ 编辑页都有动画；但从「设置」进任何子页仍是瞬切。动效批 4（提交 `8b4d9dd`）已在 36 个分支根容器挂上 `.transition(this.routeTransition())`，代码侧已修；上机观感验证待做（模拟器被别的会话占用）。
- **根因（原记录写错，已更正）**：原记录说「子页在 `ProfileSubPages.ets` 内部按 `profileSubpage` 状态用 `if` 换子树」是错的——`grep -c 'profileSubpage' ProfileSubPages.ets` = 0，该文件只是 15 个 struct 的宿主。真正的换子树发生在 `pages/Index.ets` 的 `PROFILE_SUBPAGE` 渲染分支里那 35 个 `if (this.profileSubpage === ProfileRoute.XXX)` 分支（全文件 `profileSubpage ===` 42 处，渲染分支组 35 处），该段原本 `.transition(` 计数为 0。
- **补法（已做）**：在 `pages/Index.ets` 那 35 个 `profileSubpage` 分支 + 1 个末尾 `else` 分支的根容器上各挂一次 `.transition(this.routeTransition())`，共 36 行（提交 `8b4d9dd`，全文件 `transition(this.routeTransition())` 8 → 44）。`ProfileSubPages.ets` 一字未改；`routeTransition()` 的 280/220ms 与 40/-60vp 位移未动。
- **验收**：设置列表点「外观」时能看到新页滑入 + 旧页左移淡出；连点两次返回不出现半透明中间态残留。（代码已挂；上机待补，勿写成已通过。）

---

## 阅读页正文压状态栏（r349 已修）

**KI-REL10 阅读页正文压住系统状态栏** —— 关联 [`VALIDATION.md`](VALIDATION.md) r349 一节

- **现象**：阅读页顶部正文与系统状态栏重叠。分页档同一本书同一页，正文首行占 `y=24..100`，状态栏时间与图标也在 `y=59..100`，字压在时间上。
- **根因**：正文纵向起点只算了两笔——`paddingSettings.paddingTop` 与页眉预留，没有算系统栏占位。`appTopInset`（`pages/Index.ets:799-807` 的 `publishAppTopInset()` 广播）在 `entry/src/main/ets/pages/ReaderPage.ets` 里此前只被顶栏按钮用（修前版本 `:7736` 的 `.padding({ top: 12 + this.appTopInset })`），排版链路完全没读它。上游是分开两笔的：`ui/book/read/ReaderContentAvoidancePolicy.kt:30-48` 的 `statusPlaceholderGone` 给正文留出状态栏那一整条，`LegacyReaderChapterPaginator.kt:267` 的 `paddingTopPx = paddingTop + contentPaddingTop + headerExtentPx` 再把页眉叠上去。
- **修法**：新增 `private readerStatusBarReserve(): number`（`entry/src/main/ets/pages/ReaderPage.ets:4899`）——`hideStatusBar` 为真返回 0（对齐上游 `statusPlaceholderGone`），否则返回 `@StorageProp('appTopInset')` 取整到 0.5vp。接进五处：`getBodyContentHeight()`（`:4865`）、`buildReaderCanvasLayout()` 的 `layout.originYpx`（`:6379`，与页眉预留相加）、`buildReaderHeaderDecoration()` 的 `row.originYpx`（`:6321`）、`onAreaChange` 画布实测扣高（`:7481`）、书签角标 margin.top（`:7509`）。另外 `onSystemBarSettingsChanged()`（`:1136`）去掉 headerMode 条件改为一律重排——否则切 `hideStatusBar` 后占位变了但页不重排。
- **页脚口径**：`buildReaderFooterDecoration()`（`:6267`）改成 `row.originYpx = request.layout.originYpx + request.layout.bodyHeightPx;`（贴正文底边）。不采用「贴画布底」式，实测页脚文字 `y=2722..2754` 与正文末行底 `y=2689` 不重叠、页脚底距画布底 78px≈22vp，符合正常留白。
- **验收**：同一本书同一页 A/B——修前正文首行 `y=24..100`（压状态栏）、修后 `y=153` 起（状态栏 `y=59..100` 下方）；分页档翻 3 页后正文首行仍在状态栏下方；滚动档章标题 `y=268..404`、退出重进同位置；`hideStatusBar=true` 时正文与页眉一起上移（268→247）、状态栏图标消失，占位归零分支正常；切回 `hideStatusBar=false` 后正文回到状态栏下方。

**r351 追加：底部对齐的单位错（同一批 r348 引入，本轮修掉）** —— 分页器侧算位移整条链路是 vp，画布侧 `layout.bottomJustifyGapByColumn` 是 px，`entry/src/main/ets/reader/ReaderCanvasSurface.ets` 合并页内值与 layout 值进同一个 `gaps` 数组时漏乘 `vp`，页内分支的位移只有应有的 1/3.5。修法是页内值先 `* vp` 再合并（分页器不必知道 vpScale，换算留在画布侧）。实测同一章首页：关对齐末行底 `y=2676`，开对齐修复版 `y=2701`（下移 25px≈7.1vp），带 bug 版 `y=2683`（只下移 7px），比值 25/7≈3.57≈密度 3.5。

---

## M3 色位缺口（r352 盘点，未修）

**KI-THEME2 上游 34 个在用色位本地只落 9 个，容器色与错误色一律降级或写死** —— 状态：**部分修**（r354 补 11 色位广播、收口阅读域硬编码；余下见本节末「r354 本轮」）。r352 把缺口量化到行号级，代价也算清了，但没有排期（理由见本节末「判断」）。

### 上游真实用量

上游 `ui/theme/LegadoTheme.kt` 的 `data class LegadoColorScheme` 共 **53 个字段**，全仓 `colorScheme.xxx` 引用 **1,531 处**。按字段逐个数，**34 个有引用、19 个零引用**。

| 色位 | 引用 | 本地是否已广播 |
| --- | ---: | --- |
| `onSurfaceVariant` | 343 | 是（themeColorTextSecondary） |
| `primary` | 171 | 是（themeColorAccent） |
| `onSurface` | 139 | 是（themeColorTextPrimary） |
| `surface` | 137 | 是（themeColorSurfacePrimary） |
| `surfaceContainerLow` | 117 | 是（themeColorSurfaceSecondary） |
| `onSheetContent` | 83 | 否，可派生 = surface |
| `error` | 63 | 否 |
| `surfaceContainer` | 63 | 是（themeColorSurfaceTertiary） |
| `secondaryContainer` | 62 | 否 |
| `outlineVariant` | 53 | 否 |
| `surfaceContainerHigh` | 48 | 是（themeColorSurfaceElevated） |
| `outline` | 35 | 是（themeColorTextTertiary） |
| `primaryContainer` | 28 | 否 |
| `onSecondaryContainer` | 26 | 否 |
| `onPrimaryContainer` | 20 | 否 |
| `secondary` | 20 | 否（仅色块预览用） |
| `surfaceVariant` | 16 | 否 |
| `surfaceContainerHighest` | 15 | 是（themeColorSurfaceHighest） |
| `surfaceInput` | 15 | 否，上游由 bookInfoInputColor 取色 |
| `cardContainer` | 7 | 否，可派生 = surfaceContainerLow |
| `background` | 6 | 否 |
| `onCardContainer` | 6 | 否，可派生 = primary |
| `onPrimary` | 4 | 否 |
| `onTertiaryContainer` | 4 | 否 |
| `inverseSurface` | 4 | 否 |
| `errorContainer` | 4 | 否 |
| `scrim` | 4 | 否 |
| `surfaceBright` | 4 | 否 |
| `tertiaryContainer` | 3 | 否 |
| `onErrorContainer` | 3 | 否 |
| `tertiary` | 2 | 否（仅色块预览用） |
| `inverseOnSurface` | 2 | 否 |
| `onBackground` | 1 | 否，可派生 = onSurface |
| `onError` | 1 | 否 |

**19 个零引用字段**（上游自己一次都没用，抄过来纯占地方，不必补）：

`inversePrimary` / `onSecondary` / `onTertiary` / `surfaceTint` / `surfaceDim` / `surfaceContainerLowest` / `primaryFixed` / `primaryFixedDim` / `onPrimaryFixed` / `onPrimaryFixedVariant` / `secondaryFixed` / `secondaryFixedDim` / `onSecondaryFixed` / `onSecondaryFixedVariant` / `tertiaryFixed` / `tertiaryFixedDim` / `onTertiaryFixed` / `onTertiaryFixedVariant` / `cardPrimaryContainer`

### 本地现状

- `entry/src/main/ets/data/ThemePalette.ets`（580 行）：`interface ThemePaletteColors` **11 个字段**（`:32-44`）——9 个参与换肤，外加 `secondary` / `tertiary` 两个只给调色板色块预览用（接口注释明写「不参与全局换肤」）。
- `publishPaletteColors(colors)`（`:544-554`）只广播 **9 个** `AppStorage` 键：`themeColorAccent` / `themeColorTextPrimary` / `themeColorTextSecondary` / `themeColorTextTertiary` / `themeColorSurfacePrimary` / `themeColorSurfaceSecondary` / `themeColorSurfaceTertiary` / `themeColorSurfaceElevated` / `themeColorSurfaceHighest`。
- 消费面：`@StorageProp('themeColor*')` 共 **555 处**、涉及 **62 个 .ets 文件**（`themeColorTextSecondary` 96 / `themeColorTextPrimary` 85 / `themeColorTextTertiary` 85 / `themeColorAccent` 81 / `themeColorSurfacePrimary` 65 / `themeColorSurfaceElevated` 59 / `themeColorSurfaceSecondary` 45 / `themeColorSurfaceTertiary` 37 / `themeColorSurfaceHighest` 1）。
- `resources/base|dark/element/color.json` 各只有 8 个 `theme_*` + `start_window_background`，`$r('app.color.theme_*')` 在 .ets 里只剩 **1 处**引用 —— 色资源这条路基本没在用，全靠 `AppStorage` 广播。

### 缺口账（25 个要补，三种性质）

| 性质 | 个数 | 色位 |
| --- | ---: | --- |
| 值需新增 | 18 | `error` / `secondaryContainer` / `outlineVariant` / `primaryContainer` / `onSecondaryContainer` / `onPrimaryContainer` / `surfaceVariant` / `background` / `onPrimary` / `onTertiaryContainer` / `inverseSurface` / `errorContainer` / `scrim` / `surfaceBright` / `tertiaryContainer` / `onErrorContainer` / `inverseOnSurface` / `onError` |
| 值已有、只缺广播键 | 2 | `secondary` / `tertiary`（色块预览已在用同一份值） |
| 可派生、不新增值 | 5 | `onSheetContent`←`surface` / `cardContainer`←`surfaceContainerLow` / `onCardContainer`←`primary` / `onBackground`←`onSurface` / `surfaceInput`←`bookInfoInputColor`（上游 `ui/theme/ThemeColorSchemeOverride.kt:74-77`） |

9（已广播）+ 25（缺口）= 34，与上游有引用的字段数正好对上。

### error 色位：16 种红，没有统一来源

本地全仓 `themeColorError` / `errorContainer` **零命中**，危险色全靠写死。去重后 16 种：`#FF0000`(1) `#E53935`(2) `#F44848`(1) `#FE4D55`(3) `#C62828`(1) `#E5484D`(1) `#FF6B6B`(7) `#DB4B4B`(1) `#CF3E40`(3) `#B3261E`(1) `#FF7417`(1) `#D95656`(2) `#FF8A80`(2) `#FF8C00`(2) `#E57373`(2) `#AD1457`(1)。其中 `#FFB4AB` 10 处全在 `pages/ReaderHighlightRuleSheet.ets`（`:589` / `:611` / `:615` / `:761` / `:783` / `:845` / `:855` / `:868` / `:888` 等）。同一个「红」散成六种色调，换主题时一个都不会跟着变。

### 27 处降级点（11 个文件）

全仓 `secondaryContainer` / `primaryContainer` / `onSecondaryContainer` / `onPrimaryContainer` 共 27 处，每处都在注释里写着「本地没有该色位，用 xxx 顶」：

| 文件 | 处数 | 代表位置 |
| --- | ---: | --- |
| `pages/BookInfoPage.ets` | 5 | `:37`（`themeColorSurfaceElevated` 注释顶替 secondaryContainer）、`:214-216`（`lerp(secondaryContainer, seedColor, 0.42f)` 封面主色）、`:1180` |
| `pages/CatalogPage.ets` | 4 | `:279-280`（目录三档：多选 primaryContainer / 当前章 secondaryContainer / 其余 surfaceContainerLow）、`:702`、`:760` |
| `pages/ThemeSettingsPage.ets` | 3 | `:305-306`、`:489` |
| `pages/ReaderSearchPage.ets` | 3 | `:42`、`:339`（搜索结果高亮 = accent 前景 + primaryContainer 背景）、`:367` |
| `pages/ReaderPage.ets` | 3 | `:1612`（选中走 secondaryContainer）、`:1623`、`:9137` |
| `pages/ReaderSettingsPage.ets` | 2 | `:4296`、`:4319` |
| `pages/Index.ets` | 2 | `:11350-11351`（`AppNavigationBar.kt:148-156` 用 secondaryContainer） |
| `components/ThemeSelectors.ets` | 2 | `:17-18`；`:21-22` 是**刻意的设计取舍**（三档并排时整块强调色更能表达当前档位），改造时要保留原判断 |
| `pages/TxtTocRulePreviewPage.ets` | 1 | `:219`（徽章 primaryContainer α0.85） |
| `pages/ReaderAloudSettingsPage.ets` | 1 | `:244`（tonal 按钮近似） |
| `pages/ReadAloudConfigPanel.ets` | 1 | `:89`（页签选中） |

### 代价

| 项 | 量 | 性质 |
| --- | --- | --- |
| 色值数据 | **432 个**（18 色位 × 日/夜 × 12 套内置配色） | 对着上游 `*ColorScheme.kt` 逐套抄，机械但易错 |
| `publishPaletteColors` | 9 行 → 34 行 | 简单，但键名定了就改不动 |
| `@StorageProp` 声明 | 预估 **+150–250 行** | 纯样板。Compose 靠 `CompositionLocal` 自动继承，ArkUI 必须在每个 `@Component` struct 单独声明一行 |
| 降级点改造 | 27 处 / 11 文件 | 不是批量替换，部分要保留刻意取舍 |
| `ThemePaletteColors` | 11 → 36 字段 | 牵动所有构造点 |
| 备份兼容 | 无需改 | 本地自定义色按 6 个手选色存（`data/CustomThemeColors.ets`） |
| **小计（不含 Monet）** | **约 700–900 行** | |
| Monet / HCT 算法 | 约 1,500 行新代码 | 另立项。「动态取色」档要真做必须移植 Material Color Utilities 的 HCT 色彩空间 + 9 种 paletteStyle 生成算法 |

### 一处文档失真（本节点出，已改）

`docs/parity/ZIP-THEME.md` 的 A2 行原写「上游 45 个 Material 色位本地只落 8 个（其余色位全仓无引用）」，三处都错：上游 `LegadoColorScheme` 是 **53** 个字段不是 45；本地广播 **9** 个不是 8；「其余色位全仓无引用」不成立（上游 34 个有引用）。已在本轮改成本节的数字。

### 判断：值得做，但不排现在

支持做：这是结构性欠账而非缺功能。27 处降级点是 27 个「看起来差一点」的地方，累积成「UI 有点平」的整体观感；光补 `error` 一个色位就能收掉散落各处的六种红。

暂缓：它不改任何能力，纯观感；本地还挂着私密脱敏、朗读两个死控件、阅读记录三视图等真功能缺口。且 Monet 不做的话「动态取色」档永远是假的（现在回落到内置默认配色），补 18 个色位只是让 11 套内置配色更准。

排期建议（真要做时）：放在「功能缺口清完之后、Miuix 之前」，拆 4 批——

1. **地基**：`ThemePaletteColors` 扩字段 + 432 个色值 + `publishPaletteColors` 扩键。改完界面无可见变化（新键没人读），但这是所有后续的地基。
2. **高频三色**：`error`(63) / `secondaryContainer`(62) / `outlineVariant`(53)。补上后删除按钮、选中态、分隔线立刻变对。
3. **容器族**：`primaryContainer` / `onSecondaryContainer` / `onPrimaryContainer` / `surfaceVariant` / `surfaceInput` + 改 27 处降级点。
4. **收尾**：剩余 10 个小用量色位 + `outlineVariant` 分隔线全局归位 + 文档订正。

关联：[`docs/parity/ZIP-THEME.md`](parity/ZIP-THEME.md) 的 A2/A3/A7 行、[`docs/FEATURES.md`](FEATURES.md) 5.2 第五点、KI-REL5（浅色配色未打磨，与本条同源）。

### r354 本轮：阅读域硬编码深色收敛到主题色位

本轮把「167 处硬编码深色」逐条判类后，只改其中真正跟随主题的消费点，兜底默认值、色板数组、纯黑分支、正确实现一律没动。

- **地基**：`ThemePaletteColors` 11 → 22 字段（补 `error`/`onError`/`errorContainer`/`secondaryContainer`/`onSecondaryContainer`/`primaryContainer`/`onPrimaryContainer`/`onPrimary`/`outlineVariant`/`surfaceBright`/`scrim`）；12 套配色的日/夜档都填了上游真值（264 个色值）；`publishPaletteColors()` 广播 9 → 20 键。`CustomThemeColors.ets` 两个构造点补 11 字段取 fallback。
- **rset 四键**：`ReaderSettingsPage.ets` 的 `rsetSelectedBg`/`rsetSelectedText`/`rsetChipBgAlt`/`rsetTrack` 改走 `secondaryContainer`/`onSecondaryContainer`/`surfaceElevated`/`outlineVariant` 真色位。
- **消费点**：批 3 六文件 C 类 51 处 + Z 类 1 处、批 4 选中态 7 处、批 5 错误红 10 处、批 6 降级点 4 处，都换成主题色位；每一处都补了所在 struct 的 `@StorageProp`（默认值为本地默认配色「草野」夜档真值）。
- **判断为「不改」**：ReaderPage 朗读胶囊封面 2 处三元——上游 `ReadAloudCapsule.kt:320-334` 明确写着「胶囊底色刻意不用 `LegadoTheme.colorScheme`……黑白两色在任何背景上都读得清」，属正确实现，收敛反会破坏对比度。`readerSelectionCardColor()` 的纸色派生属 KI-THEME3 另案（待 M3 能力），本轮不动。
- **逻辑缺陷**：`ReaderPage` 两处「按纸色三色比较判夜间」改用 `readerMenuIsNight()`（对齐上游 `ReadStyleResolver.isNightTheme()` 按主题模式判的语义）。
- **没做**：HCT/Monet 派生能力（约 1500 行，另立项），动态取色档仍回落内置配色；全仓 `pages/` 下其余 622 处硬编码不属阅读域，本轮没碰；`docs/parity/` 七表盘面数没变。

验收：`doc-links.py docs` / `parity-pipes.py` / `parity-rows.py --file TXT-READER.md` 三脚本全过（TXT-READER 296 行：已结 253 / 进行中 12 / 未结 31，盘面未变）；每批 `build-hap.sh` 均 BUILD SUCCESSFUL。上机换肤验收视设备占用情况另记。

---

## 阅读器菜单取色链与上游的九条差异（r353 盘点）

**KI-THEME3 阅读器菜单底色取错了属性，且本地没有 M3 派生能力** —— 状态：**部分修**（r353 修掉 3/4/5/7/9 五条，1/2/6/8 待 M3 色位补齐）。

### 根因：本地照抄了「状态栏用色」，不是「菜单底色」

本地 `entry/src/main/ets/pages/ReaderPage.ets:1586-1596` 的 `readerMenuBaseColor()` 逐条照上游 `help/config/ReadBookConfig.kt:154-178` 的 `resolvedMenuBgColor`，注释也标着这个出处。

但上游这个属性**全仓只有 1 个消费点**：

```
ReadBookController.kt:1904
activity.setLightStatusBar(ColorUtils.isColorLight(ReadBookConfig.resolvedMenuBgColor))
```

它只用来决定系统状态栏图标是黑是白，**不参与菜单绘制**。

菜单真正的底色走 `ui/book/read/ReadBookMenuBar.kt:1033-1040`：

```kotlin
private fun readMenuColors(readBarStyle: Int): ReadMenuColors {
    val themeBackground = LegadoTheme.colorScheme.surfaceContainerHigh
    val themeContent = LegadoTheme.colorScheme.onSurface
    return when (readBarStyle) {
        2 -> ReadMenuColors(surfaceContainerHigh, primary)
        else -> ReadMenuColors(themeBackground, themeContent)
    }
}
```

**菜单底色恒为 `surfaceContainerHigh` 色位**，不是手工算出来的 hex。

### 上游的架构：ColorScheme override，不是第二套色板

`ui/book/read/ReadBookColorTheme.kt:30` 用 `ProvideThemeOverride` 把整个阅读界面包住，先派生整套 M3 色位，再按 `readBarStyle` 覆盖：

| `readBarStyle` | 上游做什么 | 本地做什么 |
| --- | --- | --- |
| 0 跟随系统 | `rememberReadBookColorTheme` `:47-63` 返回 `null` → **完全继承应用主题** | 按纸色明暗返回 `#000000`/`#FFFFFF` |
| 1 跟随阅读背景（默认） | 纸色作 `seedColor`，经 `dynamicColorScheme` 派生整套 47 色位，再 `withReadSurfaceColors` 覆盖 5 个 surface | 直接返回 `paperColor` |
| 2 自定义 | 同样派生整套，再 `withCustomReadMenuColors` 覆盖 `primary`/`onPrimary`/`surfaceTint`/`surfaceContainerHigh`/`surfaceContainerLow` | 取 `readMenuBgColor`/`Night`，空则按 `readMenuColorMode` 取强调色或黑白 |

### 九条差异逐条

| # | 项 | 上游 | 本地（r353 前） | r353 是否修 |
| --- | --- | --- | --- | --- |
| 1 | 底色来源 | `surfaceContainerHigh` 色位 | `resolvedMenuBgColor`（状态栏用色） | 否，见「为什么 1/2 没修」 |
| 2 | 默认档（style 1） | 纸色作种子派生，`surfaceContainerHigh` 比纸面**深一档** | `paperColor` 原值，菜单与纸面**同色**、看不出边界 | 否，同因 |
| 3 | style 0 | 返回 `null` 继承应用主题 | 按纸色明暗返回 `#000000`/`#FFFFFF` | **已修**：改用 `themeColorSurfaceElevated` |
| 4 | style 2 未设色回落 | `menuBgColor(isNight)` = `#EEEFE3`(日)/`#BFCBAD`(夜) | 强调色或黑白 | **已修**：填对两个默认值 |
| 5 | 强调色未设回落 | `menuAccentColor(isNight)` = `#EEEFE3`(日)/`#586249`(夜) | **硬编码 `#FFB1C8`（粉）** | **已修**：填对两个默认值 |
| 6 | 选中态 | `secondaryContainer`（派生色位） | `mixHexColor(accent, base, 0.7)` 手工混 | 否，需派生能力 |
| 7 | 夜间判据 | `themeMode`：`"1"`=日 / `"2"`=夜 / 其他 `sysConfiguration.isNightMode` | 纸色亮度 `< 0.5` | **已修**：改用 `readerNightMode` |
| 8 | `readMenuColorMode == 0`（种子档） | 用强调色作**种子派生整套** | 直接拿强调色**当底色** | 否，需派生能力 |
| 9 | `readMenuTintColor` | 三段回落，第三段 `readMenuBlurColor.takeIf { it != 0 }` 兜日间值 | 只有两段，夜间且 `Night` 为空时不兜日间值 | **已修**：补第三段 |

第 5 条最直观：本地那个 `#FFB1C8` 粉是错的。上游未设强调色时用草野配色的 `#586249`（夜间）／`#EEEFE3`（日间）。

第 2 条最容易被忽略：默认档下本地菜单底色 = 纸面色**完全一样**，上游是「纸色派生出来的 `surfaceContainerHigh`」，比纸面深一档 —— 所以上游菜单浮在纸面上有边界感，本地是糊在一起。

### 为什么 1/2 没修：本地没有 M3 派生能力

上游 style 1 的 `surfaceContainerHigh` 是 `dynamicColorScheme(seed = 纸色)` 派生出来的 tonal 值，不是任何一个现成的 hex。本地要拿到它只有两条路：

- **用 `themeColorSurfaceElevated`**（应用主题的 `surfaceContainerHigh`）：色位语义对了，但**丢失「跟随纸色」** —— 用户换纸色菜单不再跟。
- **手工把 `paperColor` 压暗一档**：保住「跟随纸色」，但压多少没有依据，是拍数字。

两条都不是「照上游」，所以 r353 不动，留待 KI-THEME2 的派生能力落地后一起做。**当前 style 1 的菜单底色 = 纸色原值，与上游差「深一档」**。

### 还有第三层：167 处写死深色

这些连「算」都没算，直接写死，不属于本条（菜单取色链），单列在 KI-THEME2 的 27 处降级点之外：

按 `'#[0-3][0-9A-Fa-f]{5}'` 统计：`pages/ReaderSettingsPage.ets` **52** / `pages/ReaderPage.ets` **35** / `pages/ReaderHighlightRuleSheet.ets` **20** / `pages/ReaderMarkingEditor.ets` **18** / `pages/ReaderTextProcessingSheet.ets` **15** / `pages/ReaderSearchPage.ets` **9** / `pages/ReaderAloudSettingsPage.ets` **7** / `pages/ReadAloudPlayerPage.ets` **6** / `pages/ReadAloudConfigPanel.ets` **5**。

最典型是三个 62% 高配置面板的 `'#D91A1B21'`：`ReaderPage.ets:4759`、`ReaderSettingsPage.ets:3549`、`:3773`。commit `f78bc70` 改了主面板内外两层底色，**漏了这三个子面板**。

### 已对齐的部分（不需要动）

- `readBarStyle` 默认 **1**（`ReaderPage.ets:385` ↔ `ReadSettings.kt:69`）
- `readMenuColorMode` 默认 **1**（`:389` ↔ `ReadSettings.kt:88`）
- `readerMenuContainerBaseColor()` 的「空则继承底色」回落链（`:1604` ↔ `ReadBookColorTheme.kt:322-326`）
- 渐变方向（`readerTopBarGradient` `:1478` / `readerBottomBarGradient` `:1438` ↔ `ReaderMenuVisuals.kt:12-25`，上浓下透 / 上透下浓，第二段全透明）
- `readMenuBorderWidth` 夹 0–4（`:1673` ↔ `ReadBookConfig.kt:115`）
- 状态栏图标明暗（`applyReaderStatusBarIcon()` `:1320` 用 `darkStatusIcon`/`Night` ↔ `BaseActivity.kt:167`）

关联：KI-THEME2（M3 色位缺口，本条 1/2/6/8 条要等它）、[`docs/parity/ZIP-THEME.md`](parity/ZIP-THEME.md)、[`docs/FEATURES.md`](FEATURES.md) 5.2。

---

## 形状与面板：令牌有但阅读域不读，面板没有公共容器（r354 盘点）

**KI-THEME4 形状设置只有设置类页面跟随，阅读域完全不读；面板没有公共容器，高度/圆角/遮罩各写各的** —— 状态：**未修**。

颜色之外还有两层差距，性质完全不同：形状是「令牌层齐备、消费面缺失」，面板是「压根没有抽象层」。

### 一、上游的形状体系：没有自定义 Shapes，靠 M3 默认值加两处容器

`grep -rn "RoundedCornerShape" --include=*.kt ui/theme/` **零命中** —— 上游没有定义自己的 `Shapes`。`grep -rn "Shapes()"` 全仓只 4 处，全是直接构造 M3 默认值（`ui/theme/ThemeComponents.kt:283`、`ui/widget/components/menuItem/RoundDropdownMenu.kt:100` 与 `:179`、`ui/widget/components/modalBottomSheet/AppModalBottomSheet.kt:143`）。

所以形状实际由两处决定：

**1. `SplicedColumnGroup`（拼接分组容器）**，`ui/widget/components/SplicedColumnGroup.kt:50-54`：

```kotlin
val cornerRadius = when {
    themeSettings.disableSplicedColumnGroupCornerRadius -> 0.dp
    themeSettings.overrideBaseCardCornerRadius -> themeSettings.baseCardCornerRadius.dp
    else -> 16.dp
}
```

边框 `:55-66`：`overrideBaseCardBorder` 为真时 `BorderStroke(baseCardBorderWidth.dp, 配置色非 0 用之否则 outlineVariant)`。组内分隔线由 `SplicedColumnGroupState(enableItemDivider, currentIndex, incrementIndex)` 加 `SettingItemDivider` 驱动；`currentIndex` 用 `remember { IntArray(1) }` 而不是 `mutableStateOf`（源码注释：「换成 mutableStateOf 会让每轮组合都重新失效别的作用域，画面不变却持续重组」）。

**2. 各组件就地写 `RoundedCornerShape(N.dp)`**，阅读域共 **26 处**：`10.dp`×4 / `8.dp`×3 / `16.dp`×3 / `12.dp`×3 / `50`（胶囊）×2 / `6.dp` / `40.dp` / `32.dp` / `3.dp` / `24.dp` 各 1。注意 `ui/book/read/sheet/` 目录内 `RoundedCornerShape` **零命中** —— 所有 sheet 内容都是裸 `Column`，圆角由 `ModalBottomSheet` 容器自己给。

`MaterialTheme.shapes.*` 全仓只 9 处使用，不是主要路径。

主题设置页的形状控制项在 `ui/config/themeConfig/ThemeConfigScreen.kt:580-680`，四项按顺序：

| 项 | 偏好字段 | 默认 | 附加控件 |
| --- | --- | --- | --- |
| 关闭拼接分组圆角 | `disableSplicedColumnGroupCornerRadius` | false | — |
| 覆盖卡片圆角 | `overrideBaseCardCornerRadius` | false | 滑杆 `0f..40f`、79 步、默认 16 |
| 覆盖卡片边框 | `overrideBaseCardBorder` | false | 宽度滑杆 `0f..5f`、49 步、默认 1 + 日间色 + 夜间色 |
| 显示分隔线 | `enableItemDivider` | false | — |

对应字段与默认值在 `domain/model/settings/ThemeSettings.kt:27-66`。

### 二、本地形状层：令牌齐备、设置页真在跟随

本地这块**做得比颜色好**：

- `entry/src/main/ets/data/ThemeCardStyle.ets` 字段齐全（`containerOpacity` / `overrideBaseCardCornerRadius` / `baseCardCornerRadius` / `overrideBaseCardBorder` / `baseCardBorderWidth` / `itemDividerWidth` / `itemDividerLength` 全套 + 归一化函数）。
- `entry/src/main/ets/pages/Index.ets:3710-3727` 的 `publishThemeCardStyle()` 广播 **10 个**键：`themeCardRadius` / `themeCardBorderWidth` / `themeCardBorderColor` / `themeCardBackground` / `themeDividerWidth` / `themeDividerLength` / `themeDividerColor` / `themeContainerBackground` / `themeItemBackground` / `themePureBlack`（另有 `themeAppBackground`）。
- `themeCardRadius` 消费面 **12 个文件 40 处**：`components/settings/UiSection.ets` 2 / `components/UiTokens.ets` 1（注释）/ `pages/AppBackupSettingsPage.ets` 3 / `AppLabSettingsPage.ets` 4 / `AppReadAloudSettingsPage.ets` 2 / `CustomThemePage.ets` 6 / `Index.ets` 1 / `PrivacyNoticePage.ets` 2 / `ProfileSubPages.ets` 4 / `ReadAloudEnginePage.ets` 1 / `ThemeManagePage.ets` 5 / `ThemeSettingsPage.ets` 9。
- `components/settings/UiSection.ets:44-45` 直接吃三键：

```ts
.borderRadius(this.themeCardRadius)
.border({ width: this.themeCardBorderWidth, color: this.themeCardBorderColor })
```

- `components/ThemeItemDivider.ets` 已按 `itemDividerWidth` / `itemDividerLength` / `itemDividerColor` 三键实现。

**结论：设置类页面（外观 / 主题管理 / 自定义主题 / 隐私 / 备份 / 实验室 / 朗读设置…）全部跟随形状设置。**

### 三、阅读域字样圆角与上游一致，不是缺口

九个阅读域文件对 `themeCardRadius` / `themeCardBorderWidth` / `themeDividerWidth` **全部 0 命中**：

`pages/ReaderPage.ets` / `pages/ReaderSettingsPage.ets` / `pages/ReaderMarkingEditor.ets` / `pages/ReaderSearchPage.ets` / `pages/ReaderHighlightRuleSheet.ets` / `pages/ReaderTextProcessingSheet.ets` / `pages/ReadAloudPlayerPage.ets` / `pages/ReadAloudConfigPanel.ets` / `pages/ReaderAloudSettingsPage.ets`。

这一点与上游行为一致：上游阅读域绝大多数不用 `GlassCard` / `BaseCard`，自己写字面 `RoundedCornerShape`（`ui/book/read/sheet/ReaderBookSheet.kt:572` 10dp、`:1040` 8dp，`ui/book/read/sheet/TextProcessingSheet.kt:158` 6dp，`ui/book/read/sheet/AiCastDialogSheet.kt:546` 12dp，`ui/book/readaloud/download/ReaderAudioDownloadSheet.kt:391` 3dp 等；全域 `RoundedCornerShape(N.dp)` 命中 3/6/8/10/12/16/24/40dp）。唯一例外是 `ui/book/read/sheet/ClickActionConfigSheet.kt:213` 用了一处 `GlassCard`。因此本地阅读域 0 消费 `themeCardRadius` 是符合上游口径的，原记录把它判成「本地缺口」方向反了——外观页的圆角设置本来就只影响用 `GlassCard` 的地方（书架、设置页、详情页），阅读器内部不跟随。

阅读域自己用了一套字面圆角，同一个「卡片」概念 `borderRadius` 用了 **18 / 20 / 22 / 24 / 26** 五种值。下表只记录分布，不暗示「散值应当收口」——上游字面圆角同样分散（3–40dp），两边都散，收口到统一令牌属于新增能力，上游没有：

| 文件 | ≥18 的圆角处数 | 具体行 |
| --- | --- | --- |
| `pages/ReaderPage.ets` | 21 | `:4286 20`、`:4329 20`、`:4474 18`、`:4745 18`、`:4748 20`、`:5575 20`、`:5627 18`、`:5635 18`、`:5640 20`、`:8112 24` 等 |
| `pages/ReaderSettingsPage.ets` | 8 | `:3023 18`、`:3091 18`、`:3095 18`、`:3274 18`、`:3311 22`、`:3505 18`、`:3729 18`、`:3787 22` |
| `pages/ReaderHighlightRuleSheet.ets` | 7 | `:635 22`、`:640 22`、`:850 20`、`:868 18`、`:871 18`、`:914 20`、`:919 20` |
| `pages/ReaderSearchPage.ets` | 6 | `:364 22`、`:371 18`、`:377 18`、`:407 24`、`:494 20`、`:577 26` |
| `pages/ReaderTextProcessingSheet.ets` | 5 | `:183 18`、`:187 18`、`:252 18`、`:378 18`、`:402 18` |
| `pages/ReaderMarkingEditor.ets` | 2 | `:546 18`、`:549 20` |

`ReaderSearchPage.ets` 一个文件里出现 18/20/22/24/26 五档；对照上游同样分散，不构成需要消除的差异。

### 四、缺口二：面板没有公共容器

上游 **30 处** `AppModalBottomSheet(` 全走同一个容器（`ui/widget/components/modalBottomSheet/AppModalBottomSheet.kt`），关键三条：

| 项 | 上游 | 本地阅读域 |
| --- | --- | --- |
| 高度 | `animateContentSize = true`（`:60` 默认）+ `heightIn(max = 容器高 × 0.8f)`（`:134-137`/`:165`）→ 内容多高面板多高 | 写死百分比 |
| 内边距 | 固定 `start/end/bottom = 16.dp`（`:159-163`） | 7 种值 |
| 抓手 | `BottomSheetDefaults.DragHandle`（`:150`），颜色 `onSurfaceVariant`（`:64`） | 尺寸对、颜色分两派 |
| 容器色 | `surfaceContainer` / 内容 `onSurface`（`:63-65`） | 各写各的 |

本地阅读域只有 **5 个手写 `Stack({ alignContent: Alignment.Bottom })` 弹层**：`pages/ReaderPage.ets:4754`、`:8512`、`:8568`，`pages/ReaderSettingsPage.ets:3469`、`:3675`。全仓 `bindSheet(` 有 19 处，但**阅读域一处都没有**（分布：`ProfileSubPages.ets` 9 / `TxtTocRulePreviewPage` / `SubscriptionSubPages` / `OtherSettingsPage` / `HomePage` / `BookshelfPage` / `BookshelfManagePage` / `BookInfoPage` / `AppTranslationSettingsPage` / `AppCoverSettingsPage` / `AppBackupSettingsPage` 各 1）。

四个具体后果：

**① 高度写死百分比，切页签硬跳。** `pages/ReaderSettingsPage.ets:2548-2555`：

```ts
private settingsSheetHeight(): string {
  if (this.selectedSettingsTab >= 2) { return '80%'; }
  return this.selectedSettingsTab === 0 ? '62%' : '68%';
}
```

源码注释自陈：「本地做不到内容自适应（探针实证：把信息页内容换成两行文字，面板高度不变，仍是固定百分比）」。宽度同样写死：`settingsSheetWidth()`（`:2557-2559`）= `selectedSettingsTab === 3 ? '100%' : '88%'`。另有三处：`ReaderPage.ets:4786 height('62%')`、`:8643 height('52%')`、`:8833 height('76%') width('92%')`；`ReaderSettingsPage.ets:3311 height('86%') width('88%')`、`:3549 height('62%')`、`:3773 height('62%')`。

**② 遮罩 9 种值。** 阅读域：`#99000000`×10 / `#88000000`×6 / `#D91A1B21`×3 / `#33FFFFFF`×2 / `#66000000`×2 / `#52000000`×2 / `#E6242127` / `#A0000000` / `#D92B2D35` 各 1。全仓 `#99000000` 共 18 处、`#88000000` 6、`#66000000` 5、`#52000000` 2。

上游口径：`BgmSceneSheet.kt:119` 与 `ReadAloudCastSheet.kt:132` 用 `scrim.copy(alpha = 0.42f * scrimAlpha)`；`SearchBookItem.kt:142`/`:308` 用 `0.58f`；M3 `ModalBottomSheet` 默认 32%。

**③ 内边距 7 种值。** 阅读域 `padding({left, right})` 分布：`18`×26 / `16`×18 / `14`×14 / `12`×20 / `10`×4 / `16,14`×1 / `12,16`×1。上游固定 16。

**④ 抓手尺寸对、颜色分两派。** 6 处全是 `Row().width(32).height(4)`（`ReadAloudConfigPanel.ets:121`、`ReaderAloudSettingsPage.ets:76`、`ReaderPage.ets:4758` 与 `:8575`、`ReaderSettingsPage.ets:768` / `:2566` / `:3473` / `:3679`），与 M3 默认一致；但 `ReaderPage.ets:4758` 与 `:8575` 写死 `'#C5C6CD'`，其余走 `this.rsetHandle`。上游统一 `onSurfaceVariant`。

### 五、UiTokens 圆角常量：只留一个在用的

`components/UiTokens.ets:46` 现只定义 `RADIUS_INNER = 8`，消费面 **2 处**：`components/settings/UiColorSheet.ets:120`、`components/settings/UiInput.ets:82`。另两个常量 `RADIUS_SHEET = 16` / `RADIUS_MENU = 16`（原 `:48`/`:50`）零消费，本轮已删除。`:41-43` 的注释「卡片圆角**不在这里**：它由主题系统拥有（themeCardRadius）」保留，仍是真实约束。

原记录把定义行号写成 `:64-68`、消费面写成「4 处」都不准：实读定义在 `:46`/`:48`/`:50`，`pages/BookInfoEditPage.ets:9` 只是未使用的 import（不计消费）。

### 六、已对齐、不需要动

- 抓手尺寸 32×4 与 M3 `BottomSheetDefaults.DragHandle` 一致。
- `components/settings/UiSection.ets` 的卡片圆角/边框三键接线正确。
- `components/ThemeItemDivider.ets` 的分隔线三键接线正确。
- `ThemePackageRepository.ets`（`:66`/`:185`/`:303`/`:368`/`:452`/`:531`）与 `ThemeSettingsRepository.ets`（`:74-75`/`:276`/`:336`/`:400-401`/`:515`）的读写链完整，备份透传键组在 `data/BackupRepository.ets:484`/`:495-501`/`:538-539`。

### 七、判断：三块性质不同，不能一起做

| 块 | 缺什么 | 修法性质 | 相对成本 |
| --- | --- | --- | --- |
| 颜色（KI-THEME2） | 25 个色位没建 | 补数据 + 补广播键 | 中（432 个色值抄写） |
| 形状（本条三） | 与上游一致：阅读域用字面圆角 | 不动（上游阅读域也不跟随形状设置） | — |
| 面板（本条四） | 没有公共容器 | 新建组件 + 迁 5 个弹层 | 大（唯一要新建抽象层的一块） |

**面板这块要先探针再动手**：ArkUI 上「内容自适应高度 + 上限 80%」是否成立，本地源码注释已经写了「探针实证做不到」，但那次探针只测了固定百分比面板换成两行文字后高度不变 —— 还没测过用 `bindSheet` 的 `detents` 或 `SheetSize.FIT_CONTENT` 能不能做到。不确认这一点就动 5 个弹层，等于赌。

### 八、本轮落地（形状与面板实现批 1–4，对齐上游）

本节记录 r354 盘点后的实际落地；逐处映射见 `docs/history/shape-batch2-mapping.md`，探针证据见 `docs/history/shape-batch0-probes.md`。**一至七节为 r354 历史盘点底稿，其中的旧统计（themeCardRadius 12 文件 40 处、遮罩 9 种值、UiSection 三键接线、`:1447` 的「还没测过 bindSheet」疑问等）反映的是修复前状态；当前实际状态以本节为准。**

- **形状解析三偏差**（`data/ThemeCardStyle.ets`）：拆出 `resolveGroupCornerRadius`（仅分组容器看 `disableSplicedColumnGroupCornerRadius`，对齐上游 `SplicedColumnGroup.kt:49-70`）；`resolveCardCornerRadius(snapshot, perCardRadius)` / `resolveCardBorderWidth(snapshot, perCardWidth)` 只看覆盖开关、未覆盖时保留调用点值（对齐 `GlassCard.kt` 的 `BaseCard` 不看 disable）；边框色空串回落改读 `themeColorOutlineVariant` 令牌（对齐上游 `colorScheme.outlineVariant`，`ThemePalette.ets:919` 广播，浅 `#C5C8BA` / 深 `#44483D`）。
- **阅读域消费**：`ReaderSettingsPage.ets` 按上游取值收敛 10 处卡片圆角（13→12、10→8/12、18→12、16→12、9→8），经 `@StorageProp('themeCardRadius')` 建立响应式依赖；属"同类对应"精度（上游为拆多文件）。其余阅读域散值经逐处盘点判定为上游无对应物或非卡片装饰，保持不改并留取证（见 mapping 文档：全量 195 处 = 改 10 / 有依据保持 56 / 无对应物 129）。判据①「阅读域 10 文件对 8 键命中 > 0」实际只有 ReaderSettingsPage 命中，其余 9 文件 0 命中——属任务书判断段「不统一 95 处 / 无对应物不改」既定范围，非漏做。
- **面板公共容器**：新建 `components/ReaderSheetShell.ets`（67 行），手写弹层统一复用（圆角 28 / 抓手 32×4 rsetHandle / 内边距 16 / 点击关闭遮罩 `#66000000` / 80% 上限）。9 个调用点 + 8 个 import；`ReaderHighlightRuleSheet.ets:933` 的预设规则弹层是 zIndex 居中叠层、非贴底弹层，未迁（报告如实记录）。

**参数卡（对齐上游文件:行号）**：

| 参数 | 本地值 | 上游依据 |
| --- | --- | --- |
| 顶部圆角 | 28vp | `AppModalBottomSheet.kt:139-144` `Shapes()` → M3 extraLarge 28dp（无自定义 Shapes） |
| 抓手 | 32×4vp、圆角 4、色 `rsetHandle`（onSurfaceVariant） | `AppModalBottomSheet.kt:150` `BottomSheetDefaults.DragHandle(color=sheetDragHandleColor)`、`:64` onSurfaceVariant（上游圆角 2/4 源码未取证，本地保持 4） |
| 内容内边距 | start/end/bottom 16vp | `AppModalBottomSheet.kt:159-163` |
| 高度上限 | 内容驱动 + `constraintSize({maxHeight:'80%'})` | `AppModalBottomSheet.kt:134-137` `containerHeight*0.8f`、`:165` `heightIn(max=maxHeight)` |
| 切页过渡 | `animateTo({duration:220,curve:Friction})` 作用于 Swiper 自身 | `PagerHeight.kt:30` `rememberPagerAnimatedHeight`、`ReadStyleSheet.kt:86` `.pagerHeight(animatedHeight)`（上游为 `currentPage+offsetFraction` 连续插值 + 弹簧，ArkUI 用 onChange 后 220ms 补间，属平台能力差异） |
| 遮罩 | 点击关闭类统一 `#66000000` | 上游 scrim 由 `ModalBottomSheet` 平台自带（无业务色值），本地取值为统一口径而非上游取证 |

**为何用 `constraintSize` 而非 `bindSheet` detents / FIT_CONTENT**（回答 :1447 的遗留疑问）：探针已实测（`docs/history/shape-batch0-probes.md`）——普通 Column 不写 `height`、只写 `.constraintSize({maxHeight:'80%'})` 即可做到内容驱动高度 + 80% 上限；`bindSheet` 的 detents / `SheetSize.FIT_CONTENT` 未采用，因阅读器是自绘 Canvas，`bindSheet` 的层级与自绘内容会打架。上游用 Compose `ModalBottomSheet`，二者实现层级不同，仅对齐视觉/行为参数，不照搬控件。

**验收**：构建 `BUILD SUCCESSFUL`；模拟器深色主路径逐个面板打开，全局页约 56% 高、菜单页内容多时更高、信息页顶到 80%——高度随内容变化，无截断。切页高度过渡经探针抓到中间帧（121.7vp→702.9vp 之间有 413.7vp 中间值），证明平滑非瞬跳。

**交付核查后的回归修复（r347，用户核查报告触发）**：

- **① 死开关回归（我引入，已修）**：批1 把 `resolveCardCornerRadius` 拆成 group/card 两义后，`Index.ets` 只剩单一 `themeCardRadius` 广播走"不看 disable"的新函数，导致依赖它的 `UiSection` 分组卡片不再响应「关闭设置分组圆角」开关——开关变成死开关（完成态判据③不过）。修法采纳用户授权的"分离两键"：`pages/Index.ets:135` import `resolveGroupCornerRadius`，`:3744` publishThemeCardStyle 新增广播 `themeGroupRadius = resolveGroupCornerRadius(snapshot)`（看 disable 开关）；`components/settings/UiSection.ets:17/47` 分组卡片改读 `@StorageProp('themeGroupRadius')`。`themeCardRadius` 保持不看 disable（普通卡片对齐上游 `GlassCard.kt` 的 `BaseCard`）。链路 grep 成对：`Index.ets:135/3744` + `UiSection.ets:15/17/47` + `ThemeCardStyle.ets:134/136`。
- **⑤ 探针3 漏分类的 6 处点击关闭遮罩（已修）**：`#99000000`→`#66000000`，`ReaderTextProcessingSheet.ets:368/386`（viewedProcess/deleteProcess 确认框）、`ReaderPage.ets:4739`（moreActionUnavailableSheet）、`ReaderSettingsPage.ets:2640`（detailSheet）、`ReaderMarkingEditor.ets:429`（onClose）、`ReaderBookmarkEditor.ets:31`（onClose）。非阅读域与 ReaderPage 内部叠层 `#88000000` 不在范围、不动。
- **真机验证（①，深色，模拟器 127.0.0.1:5555）**：在同一 UiSection 页面「我的→设置→下载与缓存」（`AppDownloadCacheSettingsPage`）对比开关开/关，像素差分四角圆角弧区各约 52–56 像素差异、卡片中间内容区差异为 0，证明卡片圆角随开关从圆角变直角再恢复、非渲染抖动。同时确认外观页 `ThemeSettingsPage` 自身卡片用 `themeCardRadius`（普通卡片）不受该开关影响——符合上游「开关只作用于 SplicedColumnGroup」语义（`ThemeConfigScreen.kt:601` 开关 + `SplicedColumnGroup.kt:49-54` 消费）。构建 `BUILD SUCCESSFUL in 1min25s`。⑤ 的 6 处遮罩改色仅做源码核对 + 构建通过，未逐处上机确认色值。

**遗留事项（已知、不影响行为，r346 决定不改代码）**：`entry/src/main/ets/pages/ReaderSettingsPage.ets:370` 的字段注释仍写着「animatedHeight 由切页时 animateTo 驱动；>0 时外壳用动画高度，否则用 constraintSize 内容驱动兜底」，与当前实现矛盾。批4 反复试错后已按上游修正：`animatedHeight` 只作用于内层 Swiper 自身（对齐 `ReadStyleSheet.kt:86` `.pagerHeight(animatedHeight)`），外壳是纯 `.constraintSize({maxHeight:'80%'})`（对齐 `AppModalBottomSheet.kt`，见 `:3868`），外壳不再读取 animatedHeight。该注释是试错期漏清的过期注释，**仅措辞错、不影响行为**；按用户决定保留不改，日后清理时把该行改为「animatedHeight 由切页 animateTo 驱动，>0 时作用于内层 Swiper 高度做过渡；外壳始终按内容驱动 + 80% 上限」即可。

关联：KI-THEME2（M3 色位缺口）、KI-THEME3（菜单取色链）、[`docs/parity/ZIP-THEME.md`](parity/ZIP-THEME.md)、[`docs/FEATURES.md`](FEATURES.md) 5.2。

---

## 排版、图标、动效、模糊、阴影、无障碍：外观体系里另外六块（r355 粗盘）

**KI-THEME5 除颜色/菜单取色/形状面板外，主题体系还有六块从未盘过；本条只做粗测，未逐行取证** —— 状态：**未修**。

这一条与前三条的区别要说清楚：KI-THEME2/3/4 是逐文件、逐行号实测出来的；本条六块只做了关键词计数与取样，**没有逐处读代码确认语义**。数字可信（都是 `grep -c` / `grep -rho` 直接数出来的），但「这一处是不是真的该用令牌」这类判断没做。当作摸底，不当作取证。

### 一、排版（Typography）

上游有完整的语义阶梯，本地没有。

- 上游 `ui/theme/LegadoTheme.kt:85-119` 定义 `data class LegadoTypography`，**24 个槽位**：headline / title / body / label 各三档（Large/Medium/Small），每档再加一个 `*Emphasized` 变体。
- 引用面：`grep -rho "typography\.[a-zA-Z]*"` 共 **696 处**，分布在 **186 个文件**。用量前六：`bodySmall` 155 / `labelSmall` 104 / `bodyMedium` 97 / `labelMedium` 74 / `titleMedium` 45 / `titleSmall` 39。`*Emphasized` 变体合计约 130 处（`labelSmallEmphasized` 39 / `labelMediumEmphasized` 39 / `labelLargeEmphasized` 18 / `titleSmallEmphasized` 16 / `titleMediumEmphasized` 14 / `titleLargeEmphasized` 4）。
- 本地（改造前粗测，状态已过期，见下方 r348 复核与批 0–8）：**没有排版层**。`fontSize(N)` 字面量 **1,189 处**（实测 1,282），字号 **20 种**：14(311) / 13(206) / 12(177) / 11(123) / 16(98) / 15(88) / 10(50) / 18(39) / 20(37) / 17(21) / 9(10) / 19(7) / 32(5) / 8(3) / 24(3) / 23(3) / 28(2) / 26(2) / 22(2) / 48(1)。**现状：字面量已归零，全部迁入 `TypographyTokens.ets` 24 槽位常量**。
- `components/UiTokens.ets:13-29` 原 9 个 `FONT_*` 常量（6 个真消费共 32 处、`FONT_LABEL_SMALL` 在 `pages/ProfileSubPages.ets:5384` 有 1 处非零消费，3 个零消费）；旧文档写「5 个消费、3 个零消费」为粗测失真。**现已统一**：settings 组件族 32 处按上游 settingItem 语义换成 TypographyTokens 槽位常量、15 处补 Emphasized 字重，UiTokens 删全部 9 个定义（详见 `VALIDATION.md`「修正偏离上游②」段）。
- 后果（改造前）：同一层级的东西在不同页面大小不一。上游靠 24 个槽位保证「所有分组标题一样大、所有说明文字一样小」，本地靠 1,282 处手写数字维持——该后果已由批 0–8 消除。
- 关联：`fontScale`（全局字号缩放 8..16，默认 10）本地是真接的 —— `entry/src/main/ets/pages/Index.ets:3839` 调 `setFontSizeScale(scale)`，`AppFontSettings.ets` 与 `Index.ets:3867-3872` 用 `getFont().registerFont` + `setFont` 换应用字体。这一层与排版阶梯是两件事，不要混为一谈。

#### 批 0 探针与行高实测（2026-11-20，基线 HEAD 91dad2c）

上面 1,189/9 个/5 个那几个数字是粗测旧值，复核后应为 **1282 处 / 20 种 / 9 个 FONT_* 中 6 个真消费**（逐值分布见文末"已知文档错误清单"对应的订正；`FONT_LABEL_SMALL` 在 `pages/ProfileSubPages.ets:5384` 有 1 处消费，不是零消费）。以下为本轮新建 `entry/src/main/ets/components/typography/TypographyTokens.ets`（24 槽位常量 / 行高常量 / `TextStyleToken` / `resolveTextStyle`）后，三个能力探针 + 真机行高测量的实测结论。

**探针 A：`@Extend(Text)` 跨文件 —— 不通过（整条路线弃用）**。在 `components/typography/TextExtend.ets` 定义 `@Extend(Text) export function slotTitleMedium(...)`，在 `pages/TypographyProbePage.ets` import 后调用，编译报 `Property 'slotTitleMedium' does not exist on type 'TextAttribute'`。注意 `import` 本身没报 "not a module"（与本文件 :1609 的 `@AnimatableExtend` 不同），但跨文件的属性扩展**没有注册到调用文件**，调用点看不到这个方法。根因同样是 `@Extend` 走文件级注册：定义文件里能用，跨文件后调用方 `TextAttribute` 上没有这个方法。结论：`@Extend` 不能跨文件复用，24 槽位不能靠它封装成 `.titleMedium()` 短语法。

**探针 B：`AttributeModifier<TextAttribute>` —— 通过，字号+行高+字重三者都生效，定为首选**。定义 `class SlotModifier implements AttributeModifier<TextAttribute>`，`applyNormalAttribute(instance)` 里 `instance.fontSize/size`、`instance.lineHeight`、`instance.fontWeight` 各设一次。`AttributeModifier` / `TextAttribute` 是 SDK 全局声明接口（`component/common.d.ts:16148` / `component/text.d.ts:92`），**不从 `@kit.ArkUI` 导出**，直接 implements 即可（若写 `import { AttributeModifier } from '@kit.ArkUI'` 会报 `'AttributeModifier' is not exported from Kit '@kit.ArkUI'`）。上机证据：同文本 `WEIGHT-SAMPLE-16`、同字号 16，Normal 行 bounds 宽 545px，挂 `titleMediumEmphasized` 的行宽 553px（+8px，证明 Medium 字重生效）、高 84px=24vp（证明行高生效）、字号 16（证明字号生效）。

**探针 C：`.font({ size, weight, family })` —— 字号+字重生效，但不能带行高**。`Font` 接口（`component/units.d.ts:2021-2064`）只有 `size/weight/family/style` 四个字段，**没有 lineHeight**，所以 `.font()` 只能设三件套里的两件，行高必须另起一行 `.lineHeight()`。上机证据：同文本同字号，`.font({size:16,weight:Medium})` + `.lineHeight(24)` 的行宽 553px（与 B 相同，字重生效）、高 84px=24vp（行高生效）。定位为不需要独立封装时的一次性快捷写法，承担不了单调用表达完整槽位。

**真机 11 个行高实测**（设备 API 26 模拟器 `127.0.0.1:5555`，密度实测 3.5，vp→px ×3.5；`uitest dumpLayout` 读 Text 节点 bounds 高度）：

| 槽位 | 字号/令牌行高(fp) | 实测 px | 实测 vp | 偏差 |
| --- | --- | --- | --- | --- |
| headlineLarge | 32 / 40 | 140 | 40.00 | 0 |
| headlineMedium | 24 / 30.86 | 108 | 30.857 | −0.003 |
| headlineSmall | 20 / 26.67 | 93 | 26.571 | −0.099 |
| titleLarge | 18 / 22.91 | 80 | 22.857 | −0.053 |
| titleMedium | 16 / 24 | 84 | 24.00 | 0 |
| titleSmall | 14 / 20 | 70 | 20.00 | 0 |
| bodyLarge | 17 / 25.5 | 89 | 25.429 | −0.071 |
| bodyMedium | 16 / 22.86 | 80 | 22.857 | −0.003 |
| bodySmall | 12 / 16 | 56 | 16.00 | 0 |
| labelLarge | 14 / 18.67 | 65 | 18.571 | −0.099 |
| labelMedium | 13 / 17.33 | 61 | 17.429 | +0.099 |

11 个值全部吻合，最大偏差 0.099fp（远低于 0.5fp 记录阈值）——4.4 表按 Material3 规范比 × 字号推算的行高值**经上机确认可用，无需修正**，`TypographyTokens.ets` 文件头"无本地源码可核、需上机量"的声明已由本轮实测消除，实测值就写在上面这张表。

**路线定案**：B（`AttributeModifier`）为主——类型安全、可传参、能进 Builder；C（`.font` + 单独 `.lineHeight`）作不需要封装的快捷写法；A（`@Extend`）整条弃用。探针页 `pages/TypographyProbePage.ets` 与 `components/typography/TextExtend.ets` 在验证后删除，临时的 `EntryAbility.ets` loadContent 指向与 `main_pages.json` 入口恢复原状（`EntryAbility.ets:137` 回到 `pages/Index`、`main_pages.json` 回到 `["pages/Index"]`）；报错原文与实测数据已逐字留在本段作证据。留下的只有 `components/typography/TypographyTokens.ets`（令牌正式产物）。

#### 15 号字归类决策（用户拍板「怎么还原上游怎么来」）

用户 2026-11-20 对 15 号字 106 处的取舍答复是「怎么还原上游怎么来」。按 `AGENTS.md` 的最高口径（用户感知范围内一律 1:1，参数逐项照抄上游、不取近似值、不自造值），**排除丙方案（新增第 25 槽位）**——上游 24 槽位、10 个字号（11/12/13/14/16/17/18/20/24/32）里根本没有 15，本地自造 15 号槽位就是「多做」。执行方向 = **甲方案的精神：每一处 15 号字按它在上游对应控件的真实槽位归位**，落到 24 槽位里对应的档位，而不是全仓统一改成某一个值。

上游槽位证据（已逐条读源码确认，路径相对 `legado-with-MD3/app/src/main/java/io/legado/app/ui/`）：

| 上游语义 | 控件/锚点 | 上游槽位 | 字号 |
| --- | --- | --- | --- |
| 设置行主标题 | `widget/components/settingItem/SettingItem.kt:173` | `titleMedium` | 16 |
| 紧凑设置项标题 | `widget/components/settingItem/TinySettingItems.kt:167` | `titleSmallEmphasized` | 14 |
| 设置项说明/副标题 | `SettingItem.kt:137` / `:130` | `labelMediumEmphasized` / `bodySmallEmphasized` | 13 / 12 |
| 按钮文字 | `ui/theme/Typography.kt:298` `button = button.withLineHeightRatio(material.labelLarge)` | `labelLarge` | 14 |
| Tab 标题 | `widget/components/tabRow/AppTabRow.kt:90` | `labelLargeEmphasized` | 14 |
| 书籍描述 | `main/bookshelf/BookItem.kt:233` | `labelSmallEmphasized` | 11 |

据此，本地 15 号字的落点原则（批 5 执行时逐处以上游对应控件核对，不硬套）：按钮（取消/确定/导入/拉取/删除）→ `labelLarge`(14)；设置行主标题/右侧当前值 → `titleMedium`(16)；说明/副标题 → `labelMedium`(13) 或 `bodySmall`(12)；输入框内文字与下拉选项 → 执行时查上游对应控件后定档，暂不预设。

**边界（避免误读）**：这条「按上游定档」只解决**15 号字无同字号槽位**的问题——上游 10 个字号里没有 15，必须按语义决定它落到 14 还是 16。它**不适用于**本地已有的 14/13/12/11/16 等字号：这些在 24 槽位里有同字号槽位，迁移就是**等值替换**（14→`labelLarge`/`titleSmall` 都是 14，只是行高 18.67/20 二选一；13→`labelMedium`、12→`bodySmall`、11→`labelSmall`），**不改字号、视觉保持**。任务书 5.2 对 14/16 号的语义分流（按 maxLines/可变长文本决定行高大小档）继续有效，不要因为上游 `SettingItem.kt:173` 主标题是 16 就把本地写 14 的设置行标题改成 16——那是视觉还原改造，不是本次令牌化迁移，会引入全仓视觉回归，不在当前范围。

**批 5 逐处定档结果（已落地，106 处）**：按钮/输入框文字 51 处→`LABEL_LARGE`(14，上游 `Button`=`labelLarge`、本地 `FONT_INPUT`=14 一致)；说明/空状态/符号/开关值 14 处→`LABEL_MEDIUM`(13，上游 option/说明档)；行主标题/右侧值/条目名/状态值 41 处→`TITLE_MEDIUM`(16，上游 `SettingItem.kt:173`=`titleMedium`)。逐处决策表存 `tmp/typography-batch5-final.json`（开发机，不入公开仓库），含每处 `rel:line`、档位、判定依据、准确源码行。这是本次改造**唯一字号变化**的批次：15→14/13/16，用户已确认接受该预期视觉变化。高风险的 15 号字所在页（书架/我的/设置首页）已上机确认无错位裁切；30 个文件/106 处未逐页截图（用户确认接受定档）。

### 二、图标（Iconography）

数量差得不多，但命名不成体系。

- 上游 Material Icons 引用 **1,195 处**（口径：`grep -rho 'Icons\.' --include=*.kt app/src/main/java | wc -l`；族限定末端名 **225 种**、全末端名 **241 种**，原记录的「263 种」未查到复现口径），另有 **177 个** vector drawable（`res/drawable` 下共 **225 个** xml，无 `drawable-*` 子目录：按 `<vector` 子串口径 177、按严格根标签口径 173）。用量前十按族限定末端名口径：`Check` 55 / `Delete` 49 / `Add` 45 / `Refresh` 37 / `Close` 34 / `Edit` 33 / `Save` 28 / `PlayArrow` 21 / `MoreVert` 21 / `Settings` 20；按全末端名口径：`Check` 67 / `Delete` 62 / `Close` 46 / `Add` 45 / `Edit` 43 / `MoreVert` 42 / `Refresh` 38 / `Search` 28 / `Save` 28 / `Settings` 28。两套口径的差异来自 `Icons.AutoMirrored.*` 与 `Icons.Outlined.*` 这类族前缀，写数字时必须带口径，不许只留一套。
- 本地 `components/AppGlyph.ets` 的 `AppGlyphName` union 有 **84 个**名字，83 个 `this.name ===` 分支；`resources/base/media/` 下 146 个文件，其中 140 个 svg（`app_` 前缀 57、`reader_` 前缀 38）。
- 命名不成体系：`profileCheck` / `profileClose` / `profileSave` / `profileRefresh` / `profileExpandMore` / `profileFolder` 等 20 多个带 `profile` 前缀，而 `add` / `delete` / `edit` / `search` / `settings` / `download` / `share` / `star` 不带；`clock` 与 `accessTime` 是两个名字指同一类语义；`brightness_medium` / `light_mode` / `dark_mode` 三个用下划线，其余全是驼峰。
- 上游 top10 里本地**没有独立名字**的：`Refresh`（本地只有 `profileRefresh`）、`PlayArrow` / `Stop` / `Save` / `Close` / `SelectAll` / `FindReplace`（本地有 `profileSave` / `profileClose` / `profileFindReplace` 但都在 `profile` 命名空间下）、`KeyboardArrowDown`（本地是 `profileExpandMore`）。
- 播放/暂停/停止图标不在 `AppGlyph` 里，是 `resources/base/media/` 的独立资源（`reader_play.svg` / `reader_pause.svg` / `app_stop_square.svg`），调用方直接 `Image($r(...))` 绕过 `AppGlyph`。

### 三、动效（Motion）

有底座，动效令牌已定义、已部分接线。

- 上游 `ui/theme/ThemeComponents.kt:282` 挂 `motionScheme = MotionScheme.expressive()`，全应用动效由 M3 motion scheme 统一接管；`tween(` **154 处**、`spring(` **16 处**（旧记 143/15 是旧快照，按上游 HEAD `bba5c64` 现跑 `grep -rn` 重算）。
- 动效令牌已定义在 `components/UiTokens.ets:55-61`（四个常量：`DURATION_FADE=220` / `DURATION_PAGE_SWITCH=300` / `HEADER_COLLAPSE_THRESHOLD=70` / `HEADER_EXPAND_THRESHOLD=24`），批 1/2 已接线；`DURATION_PAGE_SWITCH` 仍未消费。本地 `duration:` 后跟具体时长值 **77 处**（其中 33 处写 `DURATION_FADE` 常量、44 处仍是数字字面量），10 种：220(34，含 33 处 `DURATION_FADE` + 1 处面板高度动画) / 500(24) / 300(8) / 200(3) / 180(2) / 160(2) / 600 / 400 / 320 / 280 各 1，另有 5 处 `duration:` 后面跟的是变量。`curve` 4 种：`Curve.EaseInOut` 23 / `Curve.EaseOut` 5 / `Curve.FastOutSlowIn` 2 / `Curve.Friction` 1。
- 220 出现 34 次（含 33 处已收口到 `DURATION_FADE`，字面量只剩 `ReaderSettingsPage.ets:1034` 的面板高度动画 1 处）；常量接线后不必再全仓找。

### 四、模糊与玻璃（Haze）

主界面通了，阅读域与朗读域全靠硬编码。

- 上游 `ui/theme/hazeStyle/HazeLegado.kt` 提供四档预设（`ultraThinPlus` / `ultraThin` / `regular` / `custom`），`ultraThin` 与 `regular` 都从 `LocalAppUiConfiguration.current.theme.topBarBlurAlpha / 100f` 取 alpha；`hazeSource` / `hazeEffect` / `HazeState` 在 **20 个文件**里使用。
- 本地 `backdropBlur` **24 处**，其中 18 处是硬编码数字（12 / 16 / 20 / 30），只有两处读偏好：`components/TopBar.ets:195` `.backdropBlur(this.themeTopBarBlurRadius)` 与 `pages/Index.ets:11262` `.backdropBlur(this.themeEnableBlur ? this.themeBottomBarBlurRadius : 0)`。其余 18 处分布在 `pages/ReaderAloudSettingsPage.ets`（11 处）、`pages/ReadAloudConfigPanel.ets`（4 处）、`pages/ReadAloudPlayerPage.ets`（1 处）、`components/ReadAloudGlassWidgets.ets:141`（1 处）、`pages/ReaderPage.ets:8197`/`:8359`/`:8384`（3 处，读的是阅读域自己的 `readerTopBarBlurRadiusVp()` / `readerBottomBarBlurRadiusVp()`）。
- 四个模糊偏好键的消费面要分清：`themeTopBarBlurRadius` 有 1 处 `@StorageProp`（`TopBar.ets:59`）；`themeBottomBarBlurRadius` 是 **0 处** `@StorageProp`（只有 `pages/Index.ets:11262` 直接读 `@State`）；`themeTopBarBlurAlpha` / `themeBottomBarBlurAlpha` 是 **0 处** `@StorageProp` —— 它们经 `entry/src/main/ets/data/TopBottomBarSettings.ets:126-139` 的 `resolveBarBackgroundColor(baseColor, opacityPercent, blurAlphaPercent, enableBlur)` 参与底色 alpha 计算，所以**不是死键，但没有广播**。
- 语义差异已记在 `pages/Index.ets:11254-11261` 的注释里：上游开模糊时面板 alpha 归零（`GlassDefaults.TransparentAlpha = 0f`）靠背后 haze 显形，本地没有 haze，全透明会让底栏彻底看不见，所以乘的是 `bottomBarBlurAlpha`（默认 40）而不是 0。

### 五、阴影（Elevation）

方向相反：本地比上游更「拟物」。

- 上游 `Modifier.shadow` / `.shadow(` 投影调用 **3 处**（`ui/main/bookshelf/BookItem.kt:274`、`ui/widget/components/image/cover/CoilBookCover.kt:388`、`ui/book/readaloud/ReadAloudBarCapsule.kt:186`；另两处 `Shadow(...)` 是文字阴影构造器，非容器投影）；另有 `tonalElevation` / `shadowElevation` **12 处**（如 `ui/book/read/ReadAloudCapsule.kt:297` 的 12dp 胶囊投影、`RoundDropdownMenu.kt:57` 的 4dp 下拉菜单、`GlassCard.kt:116`、`GroupManageSheet.kt:307` 拖拽态 8dp）——上游同时用投影与色位分层，不是「只靠色位分层不靠投影」（`core/ui/player/PlayerMorphHost.kt:358` 只在一处全屏图层显式关掉投影）。
- 本地 `.shadow(` 实测 **11 处命中**（含 `components/BookGroupCard.ets:34` 一处注释误命中，真实调用 10 处）；本轮删除了 3 处（`components/PullRefreshIndicator.ets`、`pages/ReadAloudPlayerPage.ets` 两处）。其中 8 处有上游锚点保留，1 处本地手绘 sheet 无上游锚点保留并在此记录（`pages/ReadAloudEnginePage.ets:240`）。
- 逐处对照后没有「全部应当改成色位分层」的统一结论；原记录「M3 口径下这 10 处应当改成色位分层」已删除。

### 六、无障碍（Accessibility）

差两个数量级。

- 上游 `contentDescription` / `semantics` **1,017 处**（`ui/` 目录）。
- 本地 `accessibilityText` / `accessibilityDescription` / `accessibilityLevel` **14 处**。
- 这一条严格说不是「外观」，但图标按钮不带语义标签，读屏用户听到的就是一串「按钮」。若要补，前提是先把图标命名统一（见本条二）。

### 七、外围一：主题包字段覆盖

上游 `domain/model/settings/ThemeExportData.kt` 约 **120 个字段**；本地 `data/ThemePackageRepository.ets:56` 的 `ThemePortableConfig` 只保留本地有对应功能的字段。

已知**有意放弃**（不是漏做，文件头注释 `:49-53` 写明）：

| 字段组 | 数量 | 放弃理由 |
| --- | --- | --- |
| `navIconHome` / `navIconBookshelf` / `navIconExplore` / `navIconRss` / `navIconMy` 及五个 `*Selected` | 10 | 本地无导航图标自定义（全仓零命中） |
| `selectedCoverAlbumId` | 1 | 本地无封面图集（全仓零命中） |
| `launcherIcon` | 1 | 切换应用图标，平台不适用 |
| 封面相关（`coverShowShadow` / `coverShowStroke` / `coverTextColor` / `coverInfoOrientation` 等） | 12 | 本地无封面图集 |

其余字段本地都有对应（`fontScale` 32 处引用、`enableDeepPersonalization` 24 处、`isPredictiveBackEnabled` 5 处、`coverShowShadow` 4 处是备份透传）。

### 八、外围二：沉浸式覆盖

本地 13 处 `expandSafeArea` / `setWindowLayoutFullScreen`。此前记录过「四个整页未吃 `appTopInset`」，**r355 复核后只剩两个**：`pages/TxtTocRulePreviewPage.ets`、`pages/ReaderSearchPage.ets`。`pages/ReadRecordOverviewPage.ets:345`/`:449` 与 `pages/FileManagerPage.ets:28`/`:153` 已经接了。

### 九、判断

| 块 | 差距性质 | 是否值得现在做 |
| --- | --- | --- |
| 排版 | ~~没有语义阶梯，1,282 处手写数字~~ 已建 `TypographyTokens.ets` 24 槽位，字面量归零（批 0–8，2026-11-20）；33 处手写行高亦已在独立批次统一（2026-11-20） | **已做** —— 字号、行高两批均收口 |
| 动效 | 有底座、令牌已定义并部分接线，77 处 10 种时长 | **已做** —— 常量收口（折叠阈值 19 处 + 淡入淡出 33 处） |
| 图标 | 命名不成体系，功能不缺 | 值得，但要与无障碍一起做 |
| 模糊 | 主界面通、其余硬编码 | 值得，成本小 |
| 阴影 | 本地比上游多（方向相反） | 看产品取向，M3 口径下应改成色位分层 |
| 无障碍 | 差两个数量级 | 差距最大，但属纯功能项，不属外观 |

排版这块要先查的理由：它和动效一样，是「同一层级在不同页面长得不一样」的根因。但**本条没做逐行取证**，查的时候要重新盘，不能直接引用本条的数字当证据。

关联：KI-THEME2（M3 色位缺口）、KI-THEME3（菜单取色链）、KI-THEME4（形状与面板）、[`docs/parity/ZIP-THEME.md`](parity/ZIP-THEME.md)、[`docs/FEATURES.md`](FEATURES.md) 5.2。

---

## 组件级形变：ArkUI 能做，`@AnimatableExtend` 已上机验证（r356）

**KI-THEME6 上游十二类「会变的控件」本地只有两个有等价物；关键能力 `@AnimatableExtend` 本仓从未用过，但实测可用** —— 状态：**未修**（只做了能力验证，没做任何控件改造）。

这条与前五条的区别：KI-THEME2/3/4/5 盘的是「配色、令牌、排版这些静态东西对不对」；本条盘的是**控件在动的时候形状怎么变**。它此前被误判成「平台做不到」，r356 已上机证伪。第六节另记一条**不属于形变、但常被误认成形变**的东西：阅读器底栏的进度拖动条（r360）。它的拇指自始至终是同一个胶囊，只被仿射缩放，真正的差异在阻尼动画与玻璃材质上。

### 一、先把能力这条钉死：`@AnimatableExtend` 能驱动 `Polygon.points` 逐帧插值

这是本条最重要的结论，因为它推翻了此前「ArkUI 没有形状插值 API」的判断。

- 官方接口：`component/common.d.ts:1029` `declare const AnimatableExtend: MethodDecorator & ((value: Object) => MethodDecorator);`（@since 10）；`:1195` `declare interface AnimatableArithmetic<T>`（@since 10），四个方法 `plus` `:1207` / `subtract` `:1219` / `multiply` `:1231` / `equals` `:1244`。**基线 20 就能用，不需要抬基线**。
- 官方文档原话（`arkts-custom-attribute-animation`）：「通过自定义可动画属性接口和可动画数据类型，通过逐帧回调函数修改不可动画属性接口的值，能够让不可动画属性接口实现动画效果」，并明确以 `Polyline.points` 为示例 —— 因为「系统不支持 Polyline 组件 points 属性的动画」。
- 编译期不是语法糖：`ets-loader` 的 `process_ui_syntax.js` 里 `processAnimatableExtend` 会给装饰函数注入 `elmtId` / `isInitialRender` / `parent` 三个隐藏参数，生成 `if (isInitialRender) { createAnimatableProperty(...) } else { updateAnimatableProperty(...) }`；这两个函数在 JS 侧只有字符串常量，真实实现在 `libace_compatible.dll` 里 —— 引擎 native 能力。
- 本仓现状：`grep -rn "AnimatableExtend\|AnimatableArithmetic" --include=*.ets .` → **0 命中**；`Polygon()` / `Polyline()` → **0 命中**。这条正规路一次都没试过。

### 二、上机实测数据（模拟器 127.0.0.1:5555，探针在仓库外 `<workspace>tmp/probe-animatable/`）

| 测什么 | 结果 |
| --- | --- |
| 圆 → 八瓣软爆裂（幅度 0.055，上游 `AnimatedPlayPauseButton.kt` 真实值） | 形变成功，观感即 M3 LoadingIndicator 的软爆裂 |
| 幅度 0.35（放大到肉眼易辨） | 形变成功，八个尖瓣清晰 |
| 中间帧是否连续 | **连续**。0.5s 时瓣刚起、1.7s 时瓣已明显，不是两个形状硬跳 |
| 插值速率（`linear` 4000ms） | **118.6–240.0 次/秒**（`multiply` 调用数 ÷ 时间跨度），多数采样落在 118–141 |
| `multiply` 在 `springMotion(0.35, 0.9)` 下是否被调用 | **仍被调用**（spring 3000ms 时 `mul 79` / `plus 78` / `eq 28`）→ 此前担心的「spring 曲线不提供插值」不成立 |
| 128 顶点 Polygon 的流畅度 | 无卡顿；插值速率 >100 次/秒说明帧率不受 128 点影响 |
| 72vp / 36vp 小尺寸（上游播放按钮真实尺寸）下是否过密 | 不过密，无毛刺（用 `scale` 缩放整块后观察） |

### 三、四条实现硬约束（都是实测撞出来的）

1. **`@AnimatableExtend` 装饰的函数必须与使用它的 `build()` 在同一个 `.ets` 文件**。抽到 `ProbeShared.ets` 后 import，编译报 `Property 'animatablePoints' does not exist on type 'PolygonAttribute'` 与 `File '...ProbeShared.ets' is not a module`。根因：`@Extend` 用模块级全局 Map（`_component_map.EXTEND_ATTRIBUTE`），而 `@AnimatableExtend` 用**文件级** Map（`storedFileInfo.getCurrentArkTsFile().animatableExtendAttribute`，每文件重建）。→ 实现时不能抽到 `components/` 下，只能就地定义。
2. **两端采样点数必须一致**。官方示例的 `plus` 用 `Math.min(this.length, rhs.length)` 截断，点数不同会静默丢点、形变错位。
3. **`Polygon.points` 是绝对坐标，不随 `width`/`height` 缩放**。小尺寸下会溢出到组件外且**不裁切**（dump 实测 200vp 的 Polygon 实际 bounds 是 `[290,795][990,1495]`，比 200vp 大）。三种处理方式实测：`Shape` + `viewPort` 包裹**图形完全不显示**（不可用）；`Polygon.viewPort` 不存在（编译报 `Property 'viewPort' does not exist on type 'PolygonAttribute'`）；**`scale()` 缩放整块可行**，代价是描边跟着缩。
4. **`extends Array<number>` / `extends Array<PointClass>` 在本仓 ArkTS 配置下可编译**。115 条 `arkts-*` linter 规则里没有禁止继承内置类型的规则（只有 `arkts-extends-only-class`）。

### 四、上游十二类「会变的控件」与本地对应

| # | 上游控件 | 怎么变 | 本地 |
| --- | --- | --- | --- |
| 1 | `AppPullToRefresh`（`ui/widget/components/AppPullToRefresh.kt`，116 行） | M3 `PullToRefreshDefaults.LoadingIndicator`：圆 ↔ SoftBurst 八瓣连续形变 + 旋转；7 处调用点 | **有等价物**，`entry/src/main/ets/components/PullRefreshIndicator.ets` 自绘 Canvas 径向函数 |
| 2 | `AnimatedPlayPauseButton`（166 行） | 三重形变：容器圆↔八瓣（128 点，`baseRadius = r*(1-0.055p)`、`lobe = r*0.055p`、转 30°）+ 图标 play/pause 顶点插值 + 容器色 `primaryContainer`↔`secondaryContainer`；`tween(300, FastOutSlowIn)`；72dp | **无**。`entry/src/main/ets/pages/ReadAloudPlayerPage.ets:309` 的 `PlayerIconBtn` 纯换 `Image` 资源，零形变；54×54 圆底写死 `#CF3E40` |
| 3 | `AnimatedText` / `AdaptiveAnimatedText`（`ui/widget/components/text/AnimatedText.kt`） | **逐字符** `AnimatedContent` + `slideInVertically`/`slideOutVertically`；9 处调用点，含底栏标签 `AppNavigationBar.kt:185`/`:218` | **无**。底栏 `TabItem`（`entry/src/main/ets/pages/Index.ets:11339-11380`）是 `if (this.selected && this.showLabel) { Text(...) }` —— 选中才出现，无逐字动画 |
| 4 | `SmallAnimatedButton`（75 行） | 点击后图标按钮**临时展开成带文字的按钮**，`delay(1000)` 自动收起；9 处调用点 | **无** |
| 5 | `MediumAnimatedButton`（63 行） | 同机制 | **无**（上游自己也是 0 调用点） |
| 6 | `AppFloatingActionButtonMenu`（`AppFloatingActionButton.kt`，255 行） | M3 Expressive `FloatingActionButtonMenu`：出现/消失形变 + 图标 Close↔MenuOpen 形变 | **无**，本地只有 `pages/BookInfoPage.ets:23` `READ_FAB_HEIGHT = 56` 的静态 FAB |
| 7 | `AppContainedLoadingIndicator`（25 行） | M3 `ContainedLoadingIndicator` 形变+旋转；6 处调用点 | **无**，本地 `LoadingProgress()` 7 处全是原生组件 |
| 8 | `AdaptiveSwitch`（`IconSwitch.kt`，139 行） | M3 `Switch` + `thumbContent = Icon(Check)` + `scale` | **有等价物**，`entry/src/main/ets/components/UiSwitchControl.ets`（266 行，`springMotion(0.35,0.9)`、按下 28/选中 24/未选中 16 滑块） |
| 9 | `VoiceAuditionButton`（342 行） | `busy` 时无限旋转（`tween(900, LinearEasing)`）+ 图标三态 | **无** |
| 10 | `DampedDragAnimation`（`ui/animation/DampedDragAnimation.kt`，142 行） | `Animatable` + `spring` + `VelocityTracker`；浮动底栏拖拽 | **无** |
| 11 | morph 浮层族（8 文件） | 封面从书架**无缝展开**到阅读器/听书页 | **无**。`geometryTransition` 可用，但圆角只同步绑定处、不管子组件 |
| 12 | `ToggleChip`（122 行） | `FilterChip` + `AnimatedVisibility` 勾 | 本地 `ReplaceScopeChip`（`pages/ProfileSubPages.ets:1381`）自绘，无勾动画 |

统计口径（旧快照数字）：上游 `Expressive` 143 处（旧值，现跑 `tween(` 154 / `spring(` 16）/ `ButtonGroup` 29 / `ToggleButton` 20 / `ContainedLoadingIndicator` 15 / `FloatingActionButtonMenu` 13 / `LoadingIndicator` 3；`updateTransition|animateFloatAsState|animateColorAsState|animateFloat(` 共 **41 个文件**。本地 `springMotion` 34 处 / `animateTo(` 28 处 / `displaySync` 0 处。

### 五、抬基线的真实收益（查过了，不是猜的）

- 本机 SDK 只有一套 `D:/Program Files/Huawei/DevEco Studio/sdk/default/`，`sdk-pkg.json` 是 `apiVersion: "26"` / `26.0.0.105` / `Release`。仓库 `build-profile.json5` 停在 `6.0.0(20)` 是**自己的选择**，抬基线不用装新 SDK，只改两个数字（且 `compatibleSdkVersion <= targetSdkVersion` 必须同步抬）。
- **API 20+**：`Polygon` 的 `points` 可经 `AttributeUpdater.updateConstructorParams` 绕过状态系统直改顶点，高频形变省一轮状态 diff。
- **API 26**：组件级沉浸光感（`@ohos.arkui.uiMaterial`，`MaterialLevel` 三档 `EXQUISITE`/`GENTLE`/`SMOOTH` + `ImmersiveStyle` 五档 `ULTRA_THIN`/`THIN`/`REGULAR`/`THICK`/`ULTRA_THICK`）—— 唯一与玻璃质感直接相关的新能力，但它是系统材质档位，不是任意形状的折射（见第六节）。
- **任何基线都没有**：M3 `RoundedPolygon` 式的内建形状插值类 API（6.1.0 Beta2 与 26.0.0 变更清单都读过，无形状形变类 API）。所以形变只能靠 `@AnimatableExtend` 自己算。

### 六、玻璃材质：模糊有、折射没有（r360 初记，r361 补到十层）

这一小节回答一个具体问题：上游阅读器底栏那条进度拖动条能不能照做。答案是「能补大半，但补不了最关键的那一下」。

#### 上游那条滑块是十层叠在一起，形变占比为零

`ui/book/read/ReadBookMenuBarTool.kt:115` 起的 `ReadMenuLiquidSlider`（玻璃档，`glassThumbEnabled && backdrop != null` 才走）实测十层：

| # | 层 | 上游做法 | 位置 |
| --- | --- | --- | --- |
| 1 | 位置 | `translationX = -w/2 + trackW*progress`，两端各夹 `w/4` | `:260-268` |
| 2 | 拇指形状 | `.size(40f.dp, 24f.dp)` + `shape = { ContinuousCapsule }`（连续曲率胶囊） | `:298` 附近 |
| 3 | 阻尼动画 | `DampedDragAnimation` 五条 spring | `ui/animation/DampedDragAnimation.kt` |
| 4 | 速度驱动惯性拉伸 | `layerBlock { val velocity = dampedDragAnimation.velocity / 10f; scaleX /= 1f - (velocity*0.75f).coerceIn(-0.2f, 0.2f); scaleY *= 1f - (velocity*0.25f).coerceIn(-0.2f, 0.2f) }` | `:275-280` |
| 5 | 按压时白底淡出 | `onDrawSurface = { drawRect(thumbColor.copy(alpha = 1f - pressProgress)) }` | `:317` |
| 6 | 玻璃材质 | `drawBackdrop(effects = { blur(8dp*(1-p)); lens(10dp*p, 14dp*p, chromaticAberration = true) }, highlight = Ambient 缩 1/1.5 * p, shadow = Shadow(8dp, 黑 12%), innerShadow = 4dp*p)` | `:281-307` |
| 7 | 拇指采样轨道层而非整页背景 | `rememberLayerBackdrop()` → `Box(Modifier.layerBackdrop(trackBackdrop))` 包住底轨与进度；拇指 `backdrop = rememberCombinedBackdrop(backdrop, rememberBackdrop(trackBackdrop) { scale(2f/3f + 1f/3f*pressProgress, pressProgress) { drawBackdrop() } })` | `:135` / `:209` / `:290` 附近 |
| 8 | 轨道自身也是玻璃 | 轨道 `drawBackdrop(... shadow = Shadow(8dp, 黑 12%), onDrawSurface = { drawRect(trackColor.copy(alpha = enabledAlpha)) }).height(6f.dp)`；进度是独立 Box `.clip(ContinuousCapsule).background(accentColor)` | `:225` / `:246` |
| 9 | 点击轨道带一次完整按压脉冲 | `detectTapGestures` → `dampedDragAnimation.animateToValue(target)`，内部 `press()` → 动画 → `release()` | `:249` 附近 |
| 10 | 无障碍 | `semantics { progressBarRangeInfo = ProgressBarRangeInfo(current, range, steps); setProgress { ... } }` | `:146` 附近 |

`p` 是 `DampedDragAnimation.pressProgress`（五条 spring：value `spring(1, 1000, visibilityThreshold)`、velocity `spring(0.5, 300, threshold*10)`、pressProgress `spring(1, 1000, 0.001)`、scaleX `spring(0.6, 250, 0.001)`、scaleY `spring(0.7, 250, 0.001)`；`pressedScale = 1.5f`）。

**第 7 层是「拇指所在位置的轨道断开、露出背景」的真正机制**：`scale(scaleX, pressProgress)` 的第二个参数是纵向缩放，不按时 `pressProgress = 0`，轨道层被压成零高度，于是拇指采样的合成结果里没有轨道 —— 拇指压到哪，哪里的轨道就「消失」。按下时 `pressProgress → 1`，纵向从 0 展开、横向从 2/3 涨到 1，轨道在拇指内长回来并被 `lens` 放大。

**两端固定留白**：`ReadBookMenuBarBottom.kt:164` 的 Row `padding(horizontal = 16.dp)` 加 `:191-193` 滑块自身 `.padding(horizontal = 8.dp)`，每侧 24vp；再加 `translationX` 的 `coerceIn` 让拇指中心最远只到距轨道两端 10dp，视觉上两端各约 34vp 空白。

**这条滑块不是形变**：拇指从头到尾是同一个胶囊，只被 `graphicsLayer` 做仿射缩放。真正逐顶点形变的是 `AnimatedPlayPauseButton`（见本节第二、四节）。

#### 刻度条：普通档有，玻璃档没有

这是两档之间最容易被忽略的一处差异。

| 档 | 拇指 | 刻度 |
| --- | --- | --- |
| 普通档（`glassThumbEnabled == false`） | material3 框架圆点 | **有**，框架按 `steps` 自绘，上游零代码 |
| 玻璃档（`glassThumbEnabled == true`） | 自绘液态胶囊 | **完全没有** |

依据：

- 普通档走 `ReadBookMenuBarTool.kt:101` 的 `BaseReaderMenuSlider`（`:64` 的 `import io.legado.app.ui.widget.components.reader.ReaderMenuSlider as BaseReaderMenuSlider`），即 `ui/widget/components/reader/ReaderMenuPrimitives.kt:109` 的 `fun ReaderMenuSlider`，内部转 `AppSlider` → material3 `Slider(steps = steps)`，刻度由框架画。
- 玻璃档整个 `:115-322` 里 `steps` 只出现两次：`:119` 形参声明、`:146` 塞进 `semantics` 的 `ProgressBarRangeInfo`。**零绘制用途。** 全函数只有三处绘制：`:225` 底轨、`:246` 已读进度、`:317` 拇指白底，没有 `drawLine`、没有 tick 循环。
- `onDrag` 里 `nextValue` 是连续浮点累加（`range * (dragAmount.x / trackWidth)`），**不按 steps 取整、不吸附**。

即：**打开液态玻璃按钮后，上游底栏进度条的刻度直接消失**，只剩底轨 + 强调色进度 + 液态拇指。`steps` 在玻璃档只服务无障碍朗读与调用方的整数语义。

上游唯一画刻度的地方是**朗读播放器**的 `ui/widget/components/player/PlayerProgressSlider.kt:99-111`（`tickSpacing = 4.dp`、`tickHeight = 2.dp`、`strokeWidth = 1.5.dp`、`RoundRect` 全圆角裁剪、`scaleY = trackScale`），与阅读器底栏这条滑块无关。

#### 本地现状

`entry/src/main/ets/pages/ReaderPage.ets:8284-8290` 的拇指是一根静态竖条：

```ts
// 自绘竖条拇指：M3 的 handle 是 4dp 宽、44dp 高的圆角竖条，
// ArkUI 系统 Slider 的拇指只能是圆点（SHAPE 档要 RectAttribute 实例，
// 组件构建器造不出来），所以在轨道上按同一百分比叠一根竖条。
Row()
  .width(4).height(44).borderRadius(2)
  .backgroundColor(this.readerMenuForeground())
  .offset({ x: this.sliderThumbOffset() })
  .hitTestBehavior(HitTestMode.None)
```

配套三个常量：`SLIDER_THUMB_WIDTH = 4`（`:142`）、`SLIDER_THUMB_TRAVEL_INSET = 14.3`（`:151`）、`sliderThumbOffset()`（`:1723`）。改值只改 `offset`，没有按压、没有回弹、没有材质、没有惯性。

**本地当前是两档之外的第三种混搭**：`:8257` 有 `.showSteps(true).stepColor(this.readerMenuForegroundAlpha('73')).stepSize(4)`（框架刻度），同时 `:8284` 又是自绘竖条拇指（系统圆点被 `.blockColor(Color.Transparent)` 涂透明）。上游普通档是「框架刻度 + 框架圆点」，玻璃档是「无刻度 + 自绘胶囊」，本地这个组合两档都不是。

另外本地**连玻璃档的开关都没接**：`readMenuBottomBarLiquidGlassButtons` 只在 `entry/src/main/ets/data/ReaderSettingsRepository.ets:334` 声明、在 `entry/src/main/ets/data/BackupRepository.ets:477`/`:526`/`:2548`/`:2555` 透传与忽略，**零 UI 消费**。所以本地恒等于普通档。

顺带记一条：`readSliderMode`（`constant/PreferKey.kt:85` = `"read_slider_mode"`，`ReadSettings.kt:25` 默认 `"0"`）在 `ReadBookMenuBarBottom.kt:161` 只判 `!= "1"` —— 值 1 是**整条滑块隐藏**，不是换形态。

#### 鸿蒙能做什么

本地已有基础设施：`backdropBlur` 24 处、`springMotion` 34 处。

| 上游层 | 鸿蒙对应 | 备注 |
| --- | --- | --- |
| 1 位置 | `.offset()` / `.translate()` | 直接对应 |
| 2 连续曲率胶囊 | `.borderRadius()` 近似；要真连续曲率得自绘 `Path` | 近似 |
| 3 阻尼回弹（五条 spring） | `curves.springMotion(response, dampingFraction)` | 参数不同名；`entry/src/main/ets/components/UiSwitchControl.ets` 已在用 `springMotion(0.35, 0.9)` |
| 4 速度惯性拉伸 | 从 `onTouch` 的位移差自算 velocity，`scaleX`/`scaleY` 用两条不同参数的 `springMotion` 回弹 | **能做**，需自己实现速度跟踪 |
| 5 按压白底淡出 | `.opacity(1 - pressProgress)` 或按 alpha 算色 | 直接对应 |
| 6 `blur(8dp*(1-p))` | `.backdropBlur(number)`；另 `.backgroundBlurStyle(BlurStyle, options)`（`component/common.d.ts:17891`，`BlurStyle` 13 档，`:6614` 起） | 有。注意 `:19055` 的 `blur(value, options)` 是**前景**模糊，不是背景 |
| 6 `highlight = Ambient * p` | `.linearGradient()` 叠一层白色渐变 | 近似，非真实光照 |
| 6 `shadow(8dp, 黑 12%)` / `innerShadow(4dp*p)` | `.shadow()` + `.border()` | 近似 |
| 7 拇指处轨道断开 | 给拇指加 `.backdropBlur(8)` + 白色 90% 底，视觉上等同「一块模糊背景胶囊盖在轨道上」 | **能近似**，与上游不按时几乎一样；但机制不同（上游是采样层被压扁，本地是盖一层） |
| 9 点击脉冲 | `Slider` 的 `onChange` 已有点击语义，补一次 press→release 动画 | 能做 |
| 10 无障碍 | `.accessibilityText()` + `accessibilityValue` / `onAccessibilityAction` | 本地 `:8265` 已用 `accessibilityText` 挂「第 x / 共 y 页」 |

#### 鸿蒙做不到什么

| 上游效果 | 鸿蒙 | 证据 |
| --- | --- | --- |
| `lens(10dp*p, 14dp*p)` 实时背景折射 | **无** | `@ohos.graphics.uiEffect.d.ts` 的 `interface Filter`（`:43`）只有 `blur(blurRadius)`（`:55`，@since 12）与 `hdrBrightnessRatio(ratio)`（`:75`，@since 24，需 `ohos.permission.HDR_BRIGHTNESS`）；`interface VisualEffect`（`:95`）是**空接口**，`createEffect()` 造出来的对象没有可用方法 |
| `chromaticAberration = true` 色散 | **无** | 全 SDK 搜 chromatic 只命中 `component/common.d.ts:19331-19352` 的 saturation 属性文档注释（讲色度分量），无 API |
| 任意形状的运行时着色器 | **无** | `@ohos.graphics.drawing.d.ts` 的 `class ShaderEffect`（`:3924`）只有 `createColorShader`、四个渐变、`createImageShader`、`createComposeShader`（`:4011-4067`），没有运行时着色器；全 SDK 搜 `RuntimeShader` 零命中 |
| 第 7 层的「把某个组件注册成 backdrop 采样源」 | **无** | ArkUI 的 `backdropBlur` 只能采样组件背后的实时背景，没有 `rememberLayerBackdrop` / `layerBackdrop` 那种「指定层」概念 |

`@ohos.arkui.uiMaterial`（API 26）是**系统材质档位**，不是任意形状的折射：`MaterialLevel` 三档（`EXQUISITE = 0` / `GENTLE = 1` / `SMOOTH = 2`，`:237-268`）、`ImmersiveStyle` 五档（`ULTRA_THIN = 0` / `THIN = 1` / `REGULAR = 2` / `THICK = 3` / `ULTRA_THICK = 4`，`:174-224`）。玻璃观感由系统决定，业务只能选档。

#### 判断

- 进度条**不属于 KI-THEME6 的形变范畴**，归「阻尼动画 + 玻璃材质」。十层里能补八层（1/2/3/4/5/8/9/10），第 6 层的模糊与阴影能补、折射与色散不能，第 7 层只能近似。
- **刻度与液态拇指互斥**：要走上游玻璃档，必须先关掉本地的 `showSteps(true)`，否则就是「一排点 + 一块胶囊」，比现在更乱。
- 本地目前是两档之外的混搭（框架刻度 + 自绘竖条），且玻璃档开关根本没接，所以「对齐上游」的第一步不是加动效，是**先把玻璃档这个开关接上**，再让两档各自成立。
- 补不了的是**按住时背景被透镜放大的果冻感**。这与 KI-THEME2 的色位缺口同一性质：不是实现没写，是没有对应 API。
- 若要做，按「能做多少做多少」写，验收时明确「折射与色散做不到、轨道断开只是近似」，不要拿放大加模糊冒充透镜。

### 七、判断

- 能力不缺：**A 档（播放按钮三重形变、加载圈、试听旋转、下拉刷新）基线 20 就够做**，已上机证明。B 档（底栏逐字、SmallAnimatedButton 展开）靠 `animateTo` + 条件渲染 + `transition` 也能做。C 档（封面 morph）`geometryTransition` 可用但有圆角/子组件限制。
- 本仓缺的是**实现**，不是平台能力。所以这一条不能判「不适用」，应判 `未接` + `**要接**`。
- 做的时候优先级：播放按钮（每屏可见、差异最刺眼）> 加载圈（`LoadingProgress` 7 处一次性换）> 底栏逐字（每页可见）> 其余。
- 落地注意：`@AnimatableExtend` 函数写在页面文件里，不要抽公共组件；128 点是性能上限不是必需，72vp 尺寸下 64 点足够。

关联：KI-THEME2（M3 色位缺口，`secondaryContainer` 缺位会连带影响播放按钮的颜色形变）、KI-THEME5（动效六块的粗测）、[`docs/parity/TXT-READER.md`](parity/TXT-READER.md)、[`docs/FEATURES.md`](FEATURES.md) 5.2。

---

## 云端 TTS 整层未建（r357 盘点，未做）

上游朗读有**三条**引擎路径：系统 TTS、用户自建 HTTP 源、**云端 provider（七家）**。本地只落了前两条，第三条整层没有——不是「平台做不到」，是这一层从来没搬。

### 上游的四层结构

| 层 | 上游文件 | 行数 |
| --- | --- | --- |
| 引擎配置表 | `data/entities/CloudTtsEngineEntity.kt`（`cloud_tts_engines`，13 列：`id` / `name` / `provider` / `baseUrl` / `apiKey` / `secretKey` / `region` / `appId` / `model` / `optionsJson` / `enabled` / `createdAt` / `updatedAt`，主键 `id`，索引 `(provider, enabled)`） | 26 |
| provider 接口与注册表 | `help/readaloud/playback/CloudTtsProvider.kt`（`CloudTtsProviderRegistry` 注册七家） | 73 |
| 七家实现 | `OpenAiCloudTtsProvider` 73 / `GeminiCloudTtsProvider` 94 / `MimoCloudTtsProvider` 89 / `AzureSpeechCloudTtsProvider` 96 / `AlibabaCloudTtsProvider` 95 / `AwsPollyCloudTtsProvider` 149 / `VolcengineCloudTtsProvider` 86 | 682 |
| 合成与映射 | `CloudTtsAudioSynthesizer.kt` 98 / `CloudTtsEmotionMapper.kt` 93 / `CloudTtsRoleInstructionMapper.kt` 20 | 211 |

provider 类型枚举七值（`domain/model/readaloud/CloudTtsModels.kt:19-26`）：`openai_speech` / `gemini_tts` / `mimo` / `azure_speech` / `alibaba_cloud` / `aws_polly` / `volcengine`，`fromStorage` 缺省回落 `Mimo`。

界面侧三文件合计 **2,885 行**：`ui/book/readaloud/cloudtts/CloudTtsScreen.kt` 1,337 / `CloudTtsViewModel.kt` 1,324 / `CloudTtsContract.kt` 224。

### 上游云端引擎怎么进播放链（这一点最容易搞错）

上游**没有第三条播放通道**。`model/ReadAloud.kt:70-101` 的 `getReadAloudClass()` 里，`ttsEngine` 解析成 `engineType == ENGINE_CLOUD`（`domain/model/readaloud/ReadAloudSpeechModels.kt:23`，值 `"cloud_tts"`）时：

```
httpTTS = HttpTTS(id = Long.MIN_VALUE, name = selection.displayName.ifBlank { "Cloud TTS" })
return HttpReadAloudService::class.java
```

即**云端引擎合成出一个假的 `HttpTTS` 源，塞进同一条 HTTP 播放服务**。合成产物是文件（`CloudTtsAudioSynthesizer.synthesize(engine, request, output: File)` 写盘），播放仍是 `ExoPlayer`（`service/HttpReadAloudService.kt:164`）。

连 MiMo 这种发 SSE 流的 provider 也一样：`MimoCloudTtsProvider.kt` 里 `put("stream", true)`、逐行读 `data:`、`choices[0].delta.audio.data` 取 base64、`Base64.decode` 累进 `ByteArrayOutputStream`，收完后 `CloudTtsAudio(pcm16MonoToWav(bytes, SAMPLE_RATE), "wav", SAMPLE_RATE)`——**上游是「流式收、整段落盘、文件播放」，没有边收边播**。默认地址 `https://api.xiaomimimo.com/v1`，采样率 24,000。

### 本地现状（三条证据，均为 r357 实测）

1. **表不存在**：`entry/src/main/ets/data/RdbSchema.ets` 共 27 张表，朗读相关只有 `httpTTS`（`:421`）与 `read_aloud_voices`（`:444`），`cloud_tts_engines` 零命中。
2. **代码不存在**：`grep -rni "mimo\|xiaomimimo" --include=*.ets entry/src/main/ets` 空；`grep -rn "cloudTts\|CloudTts"` 全仓仅 `pages/ReadAloudEnginePage.ets:7` 一处注释（说明该页对标 `CloudTtsScreen.kt`）。
3. **引擎类型只有一种**：`entry/src/main/ets/model/ReadAloudVoice.ets:45` 只定义 `READ_ALOUD_VOICE_ENGINE_HTTP = 'http'`；`pages/ReadAloudEnginePage.ets:67` 还有一行显式过滤 `if (voice.engineType !== READ_ALOUD_VOICE_ENGINE_HTTP) { return; }`。上游的 `ENGINE_SYSTEM` / `ENGINE_CLOUD` 两个值本地都没有。

### 界面现状：引擎 tab 是借壳的

`pages/ReadAloudEnginePage.ets` 的骨架确实照 `CloudTtsScreen.kt` 画的（标题「朗读引擎与音色」+ 音色/引擎两 tab + 右下 FAB + 行尾编辑/删除/拉取），但 `activeTab === 1`（引擎页）渲染的是 `this.sourceList()`——列的是 `httpTTS` 源，不是云端引擎。所以用户看到的「引擎」不是上游语义上的引擎。

### 平台侧并没有拦着（推翻「因为平台限制」这个前提）

| 能力 | SDK 依据 |
| --- | --- |
| 流式接收响应体 | `rcp.ResponseBodyDestination` 含 `IncomingDataCallback = (incomingData: ArrayBuffer) => void \| Promise<void>`，`@hms.collaboration.rcp.d.ts:292`，`@since 5.0.0(12)` |
| 逐段收数据事件 | `HttpEventsHandler.onDataReceive` / `onDataEnd` / `onCanceled`，`@hms.collaboration.rcp.d.ts:2337` 起，`@since 4.1.0(11)`；挂在 `TracingConfiguration.httpEventsHandler`（`:1467`） |
| 流式播放 PCM | `AudioRenderer.write(buffer: ArrayBuffer)`，`@ohos.multimedia.audio.d.ts:6105`（callback）/ `:6116`（Promise） |
| 播放端变速 | `AudioRenderer.setSpeed(speed: number)`，范围 0.25–4.0，`:6344`，`@since 11` |

基线 `6.0.0(20)` 全部覆盖。真正的缺口是本地没建这一层（`AudioRenderer` / `cloudTts` / `event-stream` 三个关键词在 `.ets` 里都是零命中）。

### 与「自研 MiMo 客户端」方案的四处偏离

有人提过一个方案：新建 `readaloud/MimoTtsClient.ets` + `StreamingPcmPlayer.ets` + `StreamingTtsReader.ets`，并在 `readaloud/SystemTtsPlayer.ets:339` 的二元分支后加第三条。按上游核对，这四处都偏离：

1. **provider 层从「七家可配置」退化成「一家写死」**。上游是接口 + 注册表 + 引擎表，用户能配七家、填各自的 key、切模型；单家硬编码协议对了、架构反了。
2. **播放层引入了上游不存在的东西**。`StreamingPcmPlayer`（AudioRenderer + 环形缓冲 + 段末补零）在整条朗读链路上游不存在——上游 `AudioTrack` 的所有命中都在注释里说变声器拿不到会话号（`model/ReadAloud.kt:61`/`:139`、`service/HttpReadAloudService.kt:2122`），不是流式播放实现。
3. **分支位置与上游设计相反**。上游是「云端走 HTTP 通道」，不是「三条并列通道」。本地对应的注入点是现成的 `SystemTtsPlayer.configureHttp(context, source, voice, rate)`（`readaloud/SystemTtsPlayer.ets:123`），选源在 `pages/Index.ets:7853 configureHttpSource()`。
4. **多出一处上游没有的凭据存储面**。`cloud_tts_engines` 不在上游备份白名单里（`help/storage/BackupConfig.kt:96` 的 `dbIgnoreKeys` 19 项无 `cloudTts`），说明上游自己也没给这张表做备份互通；新方案的 MiMo 配置若存本地偏好，又多一处「上游没有、备份对不上」的面。

另有一条不是「不对齐」而是**功能缺陷**：`this.httpSource !== null` 在 `readaloud/SystemTtsPlayer.ets` 里出现 **3 次**——`:168`（`pause()` 走 `HttpTtsPlayer.pause()` 保留当前段）、`:194`（`stop()` 走 `HttpTtsPlayer.stop()`）、`:339`（`speakNextUnit()` 分发合成）。只改 `:339` 的话，流式模式下 pause/stop 会掉进系统 TTS 引擎分支（`engine.stop()`），AudioRenderer 不会被停、缓冲不会清。

### 一处文档口径打架

`docs/PROJECT.md:42` 把「TTS 服务」列在**范围之内**（「在线书源抓取、RSS 拉取、TTS 服务、WebDAV 属于本项目范围之内」），但 `docs/READALOUD-BATCH-REPORT.md:115` 把七家云端 provider 判为「**范围之外**」，`:128` 与第六章第 6 条也照此口径。云端 TTS 属于「TTS 服务」而非 `PROJECT.md:46-48` 排除的「AI 在线服务 / 云同步 / 额外设备形态」，按现有范围定义应在范围内。r357 只记录这个矛盾，未改口径——口径由用户定。

### 判断

- 状态：`未接`。这是**整层缺失**，不是个别能力受限。
- 如果要接，正确顺序是搬上游四层（表 → 接口与七家 → 合成 → 挂进现有 HTTP 通道），MiMo 只是 registry 里的一个条目，不是独立客户端。
- 「边收边播」若确实想要，那是**上游没有的增强**，应加在 provider 之下（provider 仍返回完整音频，另加可选流式合成入口），不要动 `SystemTtsPlayer` 的通道结构——否则对齐与增强会互相污染。
- 未验证项：本地从未编译或运行过任何云端 provider 代码；上表 SDK 能力只核对了声明（`@since` 与签名），没有跑过探针。

关联：KI-THEME2（M3 色位缺口）、[`docs/FEATURES.md`](FEATURES.md) 3.1/3.2、[`docs/READALOUD-BATCH-REPORT.md`](READALOUD-BATCH-REPORT.md) 第五章与第六章、[`docs/PROJECT.md`](PROJECT.md)「在线服务（已纳入范围）」。

---

## 朗读的平台底座：能做什么、不能做什么（r358 盘点）

与上一节盘点的是不同的东西：上一节说「上游有云端 TTS 而本地没建」，这一节说「平台给了什么、没给什么」。素材来自并行项目 `<workspace>Frigivox` 的可行性分析（`docs/FEASIBILITY-ANALYSIS.md`，363 行；该项目 2026-11-19 已暂停，零代码、零构建、零上机）。凡标「未复核」的，是它读 OpenHarmony native 源码或外部文档得出的结论，本机 SDK 验证不了；其余 SDK 声明我都逐条复核过。

### 一、鸿蒙没有「系统 TTS 引擎插槽」——五条证据链

Android 的 `TextToSpeechService` 提供三件事：**注册**（`intent-filter action=android.intent.action.TTS_SERVICE`）、**发现**（调用方不指定引擎，系统自己枚举）、**选择**（用户在设置里选默认引擎）。鸿蒙三件都没有：

| # | 证据 | 出处 |
| --- | --- | --- |
| 1 | ExtensionAbility 类型白名单 **24 类**里没有 TTS：accessibility / action / asset / cert / dataShare / deviceManager / fence / fileShare / form / ime / inputMethod / node / preview / print / push / screen / service / share / uiExtension / userAuth / vpn / wallpaper / window / workScheduler | `build-tools/ets-loader` 里的 ExtensionAbility 类型枚举 |
| 2 | `wantConstant` 没有任何 TTS / Speech 相关 action | `@ohos.app.ability.wantConstant.d.ts` |
| 3 | Core Speech Kit 只是库不是插槽：`@hms.ai.textToSpeech.d.ts` 只暴露 `createEngine(CreateEngineParams)`，四个字段 `language` / `person` / `online` / `extraParams`，**没有 engineId、没有枚举、没有注册入口** | `@hms.ai.textToSpeech.d.ts:40` / `:57` |
| 4 | 全 SDK 无 `TtsEngine` / `ITtsEngine` 声明；`@ohos.ai` 下只有 `mindSporeLite` | 全 SDK 递归 grep 零命中 |
| 5 | 系统设置里没有「首选 TTS 引擎」项 | 官方支持页路径 + 未找到反证，**未真机实测** |

补充一条否决：`AppServiceExtensionAbility`（API 20+）看起来像「给第三方提供后台服务」的入口，但它**仅 2in1 设备 + 需 ACL `ohos.permission.SUPPORT_APP_SERVICE_EXTENSION` + 仅企业应用**，个人开发者用不上。

**后果**：任何「让别的 App 调用本应用的 TTS」的方案都退化成五处硬编码——端口、端点路径、参数名、标记 header、`bundleName` + `abilityName`。准确说法不是「私有协议」，是「**无发现机制的硬编码对接**」：只有预先知道对方存在的两个应用才能配对，第三方无法发现也无法复用。

### 二、推流播放：能做，而且这是整包问题的唯一解

本地现状是**整包**：`readaloud/HttpTtsPlayer.ets` 用 `session.downloadToFile()` 把整段音频落到 cacheDir，再 `media.createAVPlayer()` + `fdSrc` 播放——音频一个字节都没穿过阅读器的内存，阅读器只说「有个文件，你播」。所以首音延迟 = 整段合成时长。

平台侧并没有拦着，`@ohos.multimedia.audio.d.ts` 里推流 API 齐全（我逐条复核存在）：

| 能力 | 声明 |
| --- | --- |
| 创建渲染器 | `:182` AsyncCallback 重载、`:208` `createAudioRenderer(options): Promise<AudioRenderer>` |
| 逐帧要数据 | `:6871` `on(type: 'writeData', callback: AudioRendererWriteDataCallback): void` |
| 推一块 PCM | `:6116` `write(buffer: ArrayBuffer): Promise<number>`（**`write()` 已 deprecated since 11**，新写法走 `writeData` 回调） |
| 变速 | `:6344` `setSpeed(speed: number): void`，范围 0.25–4.0 |
| 采样率常量 | `:1090` `SAMPLE_RATE_24000 = 24000` |
| 打断事件 | `:6688` `on('audioInterrupt', callback: Callback<InterruptEvent>)` |

三条硬约束（前两条来自 native 源码，未复核；第三条我复核过）：

1. **回调 buffer 只有 100ms**。`audio_info.h:78` `constexpr uint64_t MAX_CBBUF_IN_USEC = 100000;` → 24kHz × 0.1s × 2 字节 = **4800 字节**。所以「合成一块、播一块」的粒度就是 100ms，不能指望一次喂一大段。
2. **回调里不能等网络**。`napi_audio_renderer_write_data_callback.cpp` 的 `WRITE_CALLBACK_TIMEOUT_IN_MS = 1000`，`napi_call_threadsafe_function(..., napi_tsfn_blocking)` 同步等 JS 返回，超时打 `"Client OnWriteData operation timed out"`。所以回调里只做 memcpy：不够就返回 `AudioDataCallbackResult.INVALID`（`:5834` `= -1`，@since 12）让系统重试（框架收到 INVALID 会置 `bufDesc.dataLength = 0`，不消耗缓冲）；段末剩多少就读多少、补零填满，返回 `VALID`（`:5838`）。
3. **编码枚举名写错就编不过**：`ENCODING_PCM_16BIT` 在 SDK 里**根本不存在**（全 SDK grep 计数 0）。正确写法是 `ENCODING_TYPE_RAW = 0`（`:1187`）+ `SAMPLE_FORMAT_S16LE`。这条纠正了此前多处的口误。

### 三、变速不变调：`setSpeed` 走 Sonic，0.5x 以上不改音高

`frameworks/native/audiorenderer/src/audio_renderer.cpp:2662-2683` 的 `SetSpeed` 末尾调 `SetPitch(AudioSpeed::GetPitchForSpeed(speed))`；`frameworks/native/audioutils/src/audio_speed.cpp:48` 是 `sonicCreateStream`，`:121-130` 的 `GetPitchForSpeed` 在 `speed > 0.5` 时把 pitch 固定为 `SPEED_NORMAL`。（两处都是 native 源码，未复核；`setSpeed` 声明本身我复核过。）

对本仓的实际含义：`HttpTtsPlayer.ets:136-152` 的十档是 `[0.75, 1.00, 1.25, 1.75, 2.00, 0.50, 1.50, 3.00, 0.25, 0.125]`，**只有最后两档（0.25x / 0.125x）会降调**，其余八档用 `renderer.setSpeed()` 即可，不需要「变速靠重新合成」那条路。

### 四、一个反向坑：别用 `STREAM_USAGE_MUSIC` / `AUDIOBOOK`

官方 `power-saving-for-playback.md`：这两种用途默认走**低功耗渲染器**，熄屏时缓存上限 **10000ms**、亮屏 1000ms，且「应用无法快速提供数据时会降级到普通渲染器周期」。对 TTS 是双向负面——填不满必然降级，能填满时 10 秒缓存会把「停止 / 暂停」延迟拉到秒级。

正确做法是用 `STREAM_USAGE_VOICE_ASSISTANT = 3`（`@ohos.multimedia.audio.d.ts:1309`）。它不属于「媒体类型」，按 `continuous-task.md` 走 `AUDIO_PLAYBACK` 长时任务即可，不需要 AVSession；本地现有的 AVSession（`readaloud/ReadAloudBackgroundTask.ets`）保留也不违规。

顺带一条与上一节相关的：`AUDIO_PLAYBACK` 长时任务从 API 20 起要求「真在播放」且需连 AVSession，否则 `SYSTEM_CANCEL_AUDIO_PLAYBACK_NOT_RUNNING = 6` 会被系统取消。这也是「独立 HAP 只起 HTTP 服务不放音」那条路拿不到后台保活的原因。

### 五、流式合成的两个硬要求

MiMo 这类 SSE 供应商的音频块是裸 PCM（`format: "pcm16"`，24kHz / 16bit / mono，**采样率与声道由客户端写死，响应里不带**）。两条必须自己做的：

1. **必须 `pcm16` 不能 `mp3`**。mp3 流式每块自带 Xing 头帧，逐块拼接会每 ~0.3s 突一下。
2. **必须自己做 PCM 帧对齐**。16bit 意味着一个采样 2 字节，奇数长度的尾字节会让后续所有样本错位（听起来是持续噪声）。做法是把不足一帧的尾字节留到下一块拼接。

### 六、上游自己也没做「单请求长流边播」

这条容易被忽略：`LonePheasantWarrior/TalkifyTTS`（Android）不是靠「一次请求播完整章」，而是 `chunkMaxLength = 768` 切文本 + `ChunkPipelineExecutor` 默认 `DEFAULT_WINDOW = 2` 两路预取，类注释明写「适用于『单块文本一次 HTTP 请求、响应体内嵌音频数据』的供应商」。所以即便供应商真流式，首块延迟也不够稳——**要抄的是「切块 + 两路预取 + 块内流式」这个三层结构，不是单层**。

本仓对应的现成件是 `readaloud/SpeechSegmenter.ets`（切段）与 `readaloud/SystemTtsPlayer.ets:346-355` 的 `preload` 循环（预取），改造方向是把「预下载文件」换成「预取下一段音频流」。

### 七、判断

- **不该做的事**：把朗读做成「独立 HAP + 本机 HTTP 中转」。平台没有 TTS 插槽，这条路的每一环都在模拟一个不存在的能力：整包（服务端收完才回、客户端下完才播，双重整包）、无取消（无 `/cancel`，用户点停止后合成仍跑到底并占住管线）、语速语义错位（本仓 `HttpTtsPlayer.ets:154-156` 的 `speakSpeed(source) = (source.speed ?? 5) + 5`，speed=5 送 10；对端若当倍率解释就是 10 倍速），还压在「跨应用 `127.0.0.1` 回环」这个**至今没有任何官方依据**的地基上。
- **该做的事**：合成内核直接跑在阅读器进程里 + `AudioRenderer` 推流播放。改动面是三个新文件（请求与 SSE 解析、渲染器与环形缓冲、对外门面）+ 一处分支（`SystemTtsPlayer.ets` 的 `isHttpMode()` 二元判断变三元），现有 HTTP 源路径与系统 TTS 兜底一行不动。
- **仍然做不到的**：被别的 App 当系统 TTS 调用（无插槽）、多角色朗读（要自建 `MultiRoleParser` / `RoleAttributor` / `SpeechPlan` 编排层，属工作量不属平台限制）。
- **仍未验证的六条**（引用时照标）：`SONIC_ENABLE` 编译开关在目标设备是否开启（关闭时 `setSpeed` 静默不变速）、`writeData` 回调 1000ms 超时余量、`STREAM_USAGE_VOICE_ASSISTANT` 与现有 AVSession 的实际配合、首块延迟实测值、段间空窗、环形缓冲欠载。


---

## 书源引擎：能接、已上机验证、但还差调度层（r359）

与「在线书源抓取仍未排期」那条不冲突：这一节说的是**技术上能不能接**，不是「排期到了」。素材来自工程外最小验证工程 `<workspace>tmp\probe-sourceengine`（包名 `io.legado.probe.sourceengine`），**主仓一行未改**。被测对象是社区实现 [`wip3l/harmony-book-source-engine`](https://github.com/wip3l/harmony-book-source-engine)（GPL-3.0）的 `sourceengine/` 与 `quickjs/` 两个目录，zip 1,844,595 B。

### 一、结论先说

**能接，而且已经在本机跑通。** 三层都实测过：

| 层 | 结论 | 证据 |
| --- | --- | --- |
| 编译链 | 76 个 `.ts` + 295 行入口，共 **25,999 行**，在 `compatibleSdkVersion 6.0.0(20)` + `targetSdkVersion 26.0.0` 下被 hvigor 当源码编进编译图，**零 ERROR** | `BUILD SUCCESSFUL in 19 s 257 ms`，49 个 task |
| native 库 | `libquickjs.so` 在 **x86_64 模拟器**上加载成功，并真的执行了 JS | 探针页第 3–6 关 |
| 规则解析 | CSS 选择器、属性取值、列表、JSONPath、`@js:` 脚本规则**全部返回正确结果** | 探针页第 7 关 |
| 真实书源端到端 | 用真实书源合集里的一条纯 CSS 书源跑通 **搜索 → 目录（1302 章）→ 正文**，书名/作者/章节名/正文全对 | 见第八节 |

剩下没验的是**调度层**——`SearchCoordinator` / `ExploreCoordinator` / `WebBookService` 这些不在 `sourceengine` 包里，作者自己 README 写明要宿主实现（他指向自己的阅读器项目 `wip3l/qingye-reader`，那边三个文件合计约 8,000 行）。所以「能接」不等于「接完就能搜书」，见第五节。

**但「能接」也不等于「对齐上游」。** 用 463 条真实书源统计，`java.*` 桥的覆盖率是 **92.5%（50 种 / 3,436 次调用命中）**，缺 43 种 / 280 次；而且引擎的 `ScriptCompatibility.ts` 明写这是 allow-list，文件系统、进程、反射、UI 四类**有意不模拟**。分层的准确判断在第九节。

### 二、编译链：怎么接才行（这一条最要紧，两种接法结果相反）

`sourceengine` 的 `main` 是 `Index.ts`（不是 `.ets`、不是编译产物），所以它不是普通 HAR 依赖，必须**作为工程内模块**参与编译。实测两种接法：

| 接法 | 配置 | 结果 |
| --- | --- | --- |
| ✅ 模块 | 根 `build-profile.json5` 的 `modules` 里加 `{ "name": "sourceengine", "srcPath": "..." }` 与 `{ "name": "quickjs", "srcPath": "..." }` | **成功**，产物正常 |
| ❌ `file:` 依赖 | `entry/oh-package.json5` 里写 `"@legado/sourceengine": "file:..."` | **失败**，两种表现见下 |

`file:` 依赖的两种失败模式（都实测过）：

- 指向**工程外绝对路径**：编译阶段过（只报 HAR 内部的 `Cannot import files outside of the current module using relative paths` 告警 368 条），但**打包 .abc 阶段崩**：`hvigor ERROR: 00305010 Syntax Error / Cannot read properties of undefined (reading 'split')`，stacktrace 落在 `ets-loader/lib/utils.js` 的 `toUnixPath` ← `genContentAndSourceMapInfo` ← `ModuleSourceFile.writeSourceFile` ← `generateModuleAbc`。
- 指向**工程内相对路径**（`file:../quickjs`）：编译阶段直接报 `10311002 ArkTS: ERROR / Failed to resolve OhmUrl. Failed to get a resolved OhmUrl for "...\quickjs\Index.ts"`，一条 import 报一次。

`file:` 依赖本身能被 ohpm 正常安装（`entry/oh_modules/@legado/sourceengine` 会出现，`oh-package-lock.json5` 里 `registryType: "local"`），所以问题不在依赖解析，在 OhmUrl 的生成——`file:` 装进来的包不会被登记为模块。

**`srcPath` 可以指向工程目录之外。** 实测把 `srcPath` 写成 `../hbse_src/harmony-book-source-engine-main/sourceengine`（工程外）同样构建成功、装机运行正常。两条路径的相对基准不一样，容易写错：

- `build-profile.json5` 的 `srcPath`：相对**工程根**
- `entry/oh-package.json5` 的 `file:`：相对**entry 目录**（所以工程外要写 `../../hbse_src/...`）

**`hvigorw` 不会自动装 `file:` 依赖**，得先手工装一次（`ohpm install --all`，装在 `entry/oh_modules`，不是根 `oh_modules`），否则报 `Cannot find module '@devzeng/quickjs'`。

### 三、native 库：x86_64 模拟器上加载并执行成功

`quickjs/` 是 38 个文件 3.6 MB 的 MIT 包（`@devzeng/quickjs` 0.1.0），自带两套预编译静态库：`libs/arm64-v8a/libquickjs.a` 与 `libs/x86_64/libquickjs.a`。模拟器实测 `uname -m` = `x86_64`，所以用的是后者。

产物 hap 里两个架构的 `.so` 都在：

```
libs/arm64-v8a/libc++_shared.so   1,262,504
libs/arm64-v8a/libquickjs.so      1,316,672
libs/x86_64/libc++_shared.so      1,294,904
libs/x86_64/libquickjs.so         1,439,008
```

探针页六关（`JSContext` 的 TS 封装，`quickjs/src/main/ets/JSContext.ts`）：

| 关 | 做什么 | 结果 |
| --- | --- | --- |
| 3 | `new JSContext(opts)` | 创建成功（native 库已加载） |
| 4 | `evaluateScript('1 + 2 * 3')` | `7` |
| 4 | `evaluateScript('"abc".toUpperCase()')` | `ABC` |
| 5 | `var host = { name: "legado" }` 后取 `host.name` | `legado` |
| 6 | `release()` | 成功 |

`JSContext` 的构造参数是 `JSRuntimeOptions { memoryLimitBytes; stackLimitBytes }`；另有 `evaluateBounded(script, sourceURL, timeoutMs, maxPendingJobs)` 做带超时的执行，与 `JSScriptSession`（独立后台线程跑 QuickJS，脚本调 `__host(name, payload)` 同步等 ArkTS 回答）——后两者探针没验。

### 四、规则解析：七项实测全部正确

探针页第 7 关用 `AnalyzeRule`（`sourceengine/src/main/ets/core/rule/AnalyzeRule.ts`，3,014 行）跑真实规则串：

| 规则 | 结果 |
| --- | --- |
| `@css:.name@text` | `书名一` / `书名二` |
| `@css:.name@href`（`isUrl = true`） | `https://example.com/book/42`（相对地址补全生效） |
| `@css:.name@text` 列表 | `书名一 \| 书名二` |
| `@css:.author@text` | `作者甲` / `作者乙` |
| `$.data.name`（JSONPath） | `JSON书名` |
| `$.data.chapters[*].t` | `第一章 \| 第二章` |
| `@css:.author@text@js:result.toUpperCase()` | `作者甲` / `作者乙`（`@js:` 的 `result` 是前一段规则的结果） |
| `@css:.name@text@js:"《" + result + "》"` | `《书名一》` / `《书名二》` |

关键 API 形态（写实现时别踩）：`getString` / `getStringList` / `getElements` 是**实例方法**，构造签名 `constructor(content: string = '', baseUrl: string = '', ctx?: RuleContext)`；`JavaRegexCompat` 的 `convert` / `compile` / `isSupported` / `notes` / `convertReplacement` **全是静态方法**，`new JavaRegexCompat()` 是错的。

### 五、还没验的（引用时照标）

- **调度层不存在**：`SearchCoordinator` / `ExploreCoordinator` / `WebBookService` 不在 `sourceengine` 包里，作者指向 `wip3l/qingye-reader`。要接完整搜索/发现/正文，得再搬那约 8,000 行。
- **宿主适配一件没接**：`BookSourceRuntimeStore.install()`、ArkWeb（`BookSourceStageWebRuntime.get().attach(controller)`）、`TlsTrustStore.load(context)`、`NativeSourceInteraction.setHandler`、`SourceEngineHost.install(adapter)`、五个 AppStorage 键（`pendingVerificationUrl` / `Title` / `Time` / `SourceUrl` / `LoginUrl`）。探针只验了纯函数层，这些全没碰。
- **模型是两套**：它自带 `model/data/Book.ts`（16,179 B，含 `Book` / `ReadConfig` / `BookChapter` / `BookSource` / `BookSearchRule`），与本地 `entry/src/main/ets/model/Book.ets` / `BookSource.ets` 不同构，接的时候要做映射层。
- **登录验证没跑**：`loginUrl` / `loginUi` / `loginCheckJs` 三个字段的交互没验（`@js:` 里 `java.*` 桥接同理）。
- **只验了一条书源**：463 条真实书源里挑的是纯 CSS 那类；带 `@js:`、`java.*`、gbk 编码、`{{page}}` 分页的书源一条都没跑。
- **Cookie 落盘没验**：`HttpClient` 的 `useCookieJar` 走通了请求，但持久化到 `BookSourceRuntimeStore` 那层没接。
- **`@Concurrent` 那条注释要留意**：`Index.ts` 里作者写明「带 `@Concurrent` 等 ArkTS 语法的 `.ets` 不能从 `.ts` 引用，统一放 `Diagnostics.ets` 子入口」——意味着部分能力只能从子入口拿。

### 六、告警与体积

构建告警 137 条，分布：`entry`（探针页）3 条、`sourceengine` 130 条、`quickjs` 2 条。`sourceengine` 那 130 条里 61 条是 `Function may throw exceptions. Special handling is required.`，其余是 crypto API 的 `The system capacity of this api '...' is not supported on all devices`（`CryptoMode` 9 / `createSymKeyGenerator` 7 / `createMd` 6 / `clearMem` 6 / `createCipher` 5 / `ENCRYPT_MODE` 5 / `DECRYPT_MODE` 4 / `init` 3 / `pubKey` 1）+ `decodeWithStream` 已废弃 9 条。**零 ERROR**。

体积：hap 8,450,316 B（未签名），其中两套 `libquickjs.so` 合计 2.76 MB、两套 `libc++_shared.so` 合计 2.56 MB、`ets/modules.abc` 1,885,784 B、`ets/sourceMaps.map` 1,246,825 B。**真接入时 sourceMaps 与多余架构可裁**（模拟器只需 x86_64，真机只需 arm64-v8a）。

### 七、许可

本仓、上游 legado、`harmony-book-source-engine`、`qingye-reader` **全是 GPL-3.0**，`quickjs` 层是 MIT。→ **可整包引入或改，不需换许可、不需隔离进程**。

### 八、真实书源端到端（r359 补测，用用户提供的合集）

素材：`https://www.yckceo.com/yuedu/shuyuans/json/id/1331.json`（6,728,267 B，**463 条书源 / 31 个字段**），下载必须带 `--tlsv1.2`，否则 curl 报 `exit 35`。合集塞进探针工程的 `entry/src/main/resources/rawfile/yck1331.json`。

被测书源：`bookSourceUrl = https://www.deqitxt.com`（「得奇小说（优+++）」），`ruleSearch` / `ruleToc` / `ruleContent` **全是纯 CSS 规则**，无 `@js:`、无 `java.`。

五步实测输出（截图 `<workspace>tmp/shots/sbe_real2.jpeg`）：

| 步 | 实测 |
| --- | --- |
| 读合集 | 463 条，解析成功 |
| 挑书源 + 映射 | `bookList = @css:div.container div.item`，`chapterList = id.list@tag.li@tag.a` |
| 搜索 | HTTP 200，正文 1,774 字符 → 书名「剑来」/ 作者「烽火戏诸侯」/ 地址 `https://www.deqitxt.com/75/` |
| 目录 | HTTP 200，正文 69,431 字符 → **1302 章**，第 1 章「新书感言」、第 2 章「第一章 惊蛰」 |
| 正文 | HTTP 200，正文 3,137 字符 → 1 段 / 93 字，开头「新书的重点在于"构建一个光怪陆离却合理有趣的仙侠世界"…」 |

**这一步暴露的硬事实：Android 键名映射不在包里。** 全仓 `grep -rn "ruleSearch\|ruleBookInfo\|ruleToc\|ruleContent\|ruleExplore"` 在 `sourceengine/src/main/ets` 下**零命中**，只在 `docs/book-source-development.md` 里出现过一次（「导入器也接受本项目内部键名 `searchRule`…」）。引擎自己的模型 `BookSource`（`sourceengine/src/main/ets/model/data/Book.ts:317`）用的是内部名 `searchRule` / `exploreRule` / `bookInfoRule` / `tocRule` / `contentRule`（`Book.ts:345-349`）。所以**从真实书源 JSON 到引擎模型的那层键名翻译必须宿主自己写**（探针里是 30 行手写赋值），与「调度层不在本包」是同一件事。

### 九、`java.*` 桥覆盖率：92.5%，**不算对齐上游**（r359 补测）

上面第八节证明了「一条纯 CSS 书源能跑通」，但**能跑通一条不等于对齐上游**。这一节给的是覆盖率实测。

**上游的 `java` 就是 `AnalyzeRule` 自己**：`model/analyzeRule/AnalyzeRule.kt:834` 是 `bindings["java"] = this`，`data/entities/BaseSource.kt:335` 同（`bindings["source"] = this`）。所以脚本里的 `java.getString` / `java.ajax` / `java.put` / `java.md5Encode16` 全是这两个类的成员方法，不存在「Java 互操作」这回事。

**实测覆盖率**（用用户提供的 463 条真实书源统计，`<workspace>tmp/yck1331.json`）：

| 项 | 数字 |
| --- | --- |
| 真实书源用到的 `java.*` 方法种类 | **93 种** |
| 调用总次数 | **3,716 次** |
| 引擎桥接面提供的名字数 | **122 个** |
| 命中 | **50 种 / 3,436 次 = 92.5%** |
| 缺失 | **43 种 / 280 次 = 7.5%** |

引擎桥接面那 122 个名字来自三处（都是**照着书源实际用法手挑的**，不是按上游逐个移植）：`core/rule/ScriptEngine.ts:571-580` 的 `isJavaRuntimeCall` 白名单 30 个、`core/book/BookSourceRuntimeRouter.ts:58-76` 的 `FULL_JAVA_METHODS` 64 个、`core/book/BookSourceStageWebRuntime.ts` 里 `name:function` 形式的 90 个（三者有重叠）。

**缺失清单（按调用次数，前 15 项）**：

| 方法 | 次数 | 上游有无 | 说明 |
| --- | --- | --- | --- |
| `java.getElements` | 73 | **有**（`AnalyzeRule.kt:419`） | 真缺，可补 |
| `java.security` | 19 | 无 | Android 类访问，**不该模拟** |
| `java.copyText` | 17 | 无（UI 侧） | 剪贴板，**不该模拟** |
| `java.io` / `java.net` / `java.nio` | 23 | 无 | 文件与网络类访问，**不该模拟** |
| `java.toNumChapter` | 13 | 有 | 真缺，可补 |
| `java.getUserAgent` | 12 | 有 | 真缺，可补 |
| `java.digestHex` / `HMacHex` / `HMacBase64` | 22 | 部分 | 真缺，可补 |
| `java.refreshTocUrl` / `refreshBookInfo` / `refreshToc` / `refreshBookUrl` | 24 | 有 | 真缺，属调度层 |
| `java.ajaxAll` / `ajaxTestAll` / `connect` / `getResponse` / `getStrResponse` | 38 | 有 | 真缺，属网络层 |
| `java.getVerificationCode` / `reLoginView` / `upLoginData` | 27 | 有 | 真缺，属登录流程 |
| `java.s2t`（繁转简） | 4 | 有 | 真缺，`t2s` 引擎已实现而反向没有 |
| 其余 20 余种 | <5 各 | 多为无 | 零散能力 |

**这不是「漏了」，是引擎作者的有意选择。** `core/rule/ScriptCompatibility.ts` 文件头原文：「This is deliberately an allow-list: filesystem, process, reflection and UI access must never be emulated by imported rules.」——它只模拟书源脚本真正需要的那一档，文件系统、进程、反射、UI 一律不模拟。所以 `java.io` / `java.nio` / `java.security` / `java.copyText` 这 4 类（合计 54 次）**即使补也不该按上游语义补**，鸿蒙这边没有对应能力，强行模拟是安全风险。

**结论要分四层说，不能一句话概括**：

| 层 | 状态 | 对齐上游？ |
| --- | --- | --- |
| 规则语法（CSS / XPath / JSONPath / `@js:` / 正则替换 / URL 选项） | 引擎已实现，七项实测全对 | **是** |
| 书源字段与导入 | 引擎用内部名 `searchRule`…，Android 键名 `ruleSearch`… 的映射**不在包里**，宿主手写 | **差一层胶水** |
| `java.*` 桥 | 92.5% 覆盖，白名单策略 | **否，且作者不打算对齐** |
| 调度层（搜索 / 发现 / 正文 / 换源 / 调试） | 完全不在包里（约 8,000 行在作者自己的阅读器） | **完全缺失** |

第八节跑通的那条「得奇小说」是纯 CSS 书源、不调 `java.*`，正好落在 92.5% 那档里——所以它是有效证据，但不能拿来当「已对齐」的证据。

---

## 替换规则：Repository 混装五类职责，上游两个浮层其实是死代码（r362 盘点）

这一节回答「本地 `data/ReplaceRuleRepository.ets` 1,217 行是不是不正常、要不要按上游拆」。结论分两半：**混装是真债，但「缺两个浮层」是我上一轮的误判——那两个浮层在上游根本没有调用点。**

### 一、上游的真实分工：16 个文件、约 2,700 行

引擎层（真正做替换）：

| 文件 | 行数 | 职责 |
| --- | --- | --- |
| `help/book/ContentProcessor.kt` | 297 | 正文应用替换规则、净化全流程、`mContent != tmp` 才计入生效 |
| `help/ReplaceAnalyzer.kt` | 46 | 解析 `##正则##替换` 语法 |
| `domain/model/BookContentProcessEngine.kt` | 196 | 内容处理引擎（应用哪些规则、什么顺序） |
| `domain/model/BookContentProcessModels.kt` | 105 | 引擎数据模型 |
| `domain/usecase/SaveBookContentProcessUseCase.kt` | 71 | 保存内容处理配置 |

数据层：

| 文件 | 行数 |
| --- | --- |
| `data/entities/ReplaceRule.kt` | 119 |
| `data/entities/BookContentProcess.kt` | 60 |
| `data/dao/ReplaceRuleDao.kt` | 189 |
| `data/dao/BookContentProcessDao.kt` | 57 |
| `data/repository/ReplaceRuleRepository.kt` | 239 |
| `data/repository/BookContentProcessRepository.kt` | 44 |

界面层：`ui/book/read/sheet/TextProcessingSheet.kt` 602（**唯一真正接线的那一个**）、`ui/book/read/ReadReplaceRuleDelegate.kt` 93、`ui/book/read/ReadContentProcessDelegate.kt` 169。

设置里的独立管理页：`ui/replace/` 七个文件（`ReplaceRuleScreen` / `ReplaceRuleViewModel` / `ReplaceRuleContract` / `ReplaceEditRoute` / `edit/ReplaceEditScreen` / `edit/ReplaceEditViewModel` / `edit/ReplaceEditContract`）。

### 二、本地现状：一个文件混装五类职责

`entry/src/main/ets/data/ReplaceRuleRepository.ets` 1,217 行，五类内容挤在一起：

| 层 | 行号 | 约计 |
| --- | --- | --- |
| SQL 常量（`upsertSql` / `deleteSql` / `updateOrderSql` / `updateGroupSql` 等十条） | `:71`–`:104` | 34 |
| 持久化与迁移（`load` / `writeAll` / `loadFromPreferences` / `migrateFromPreferences` / `readAll` / `toArgs`） | `:105`–`:310` | ~205 |
| 分组与排序（`getGroups` / `splitGroups` / `moveToTop` / `moveBatchToTop` / `reorder` / `rewriteGroups`） | `:310`–`:800` | ~490 |
| 导入导出（`importRules` / `exportRules` / `pickImportFile` / `saveExportFile`） | `:801`–`:910` | ~110 |
| **正文替换执行**（`applyContent` / `previewContent` / `applyContentWithResult` / `applyContentWithResultAsync` / `applyContentForLength` / `applyTitle`） | `:910`–`:1120` | ~210 |

对应的本地文件与上游的映射关系：

| 上游 | 本地 | 说明 |
| --- | --- | --- |
| `help/book/ContentProcessor.kt` + `domain/model/BookContentProcessEngine.kt` | `data/BookContentProcessEngine.ets` 192 行 | 引擎独立，**但正文替换的编排不在它里面** |
| `domain/model/BookContentProcessModels.kt` | `model/BookContentProcess.ets` 83 行 | 对得上 |
| `data/entities/ReplaceRule.kt` | `model/ReplaceRule.ets` 21 行 | 上游是带 Room 注解的实体，本地纯字段模型 |
| `data/repository/ReplaceRuleRepository.kt` + 两个 DAO + `help/ReplaceAnalyzer.kt` | `data/ReplaceRuleRepository.ets` 1,217 行 | **四合一** |
| `help/ReplaceAnalyzer.kt` 的正则执行部分 | `data/ReplaceRuleEngine.ets` 80 行 | 只有 worker 函数，不含编排 |
| `ui/book/read/sheet/TextProcessingSheet.kt` | `pages/ReaderTextProcessingSheet.ets` 410 行 | 两页签，与上游一致 |

### 三、为什么会这样：本地没有 DAO 层

`data/RdbSchema.ets` 只建表、不生成 DAO，所有 SQL 手写在 Repository 里。这是**全仓一致的架构选择**，不是替换规则这一处特殊。`data/*Repository.ets` 体量排名：`BackupRepository.ets` 3,865、`BookRepository.ets` 3,383、`ReaderSettingsRepository.ets` 2,118、`ReadRecordRepository.ets` 1,373、`EpubRepository.ets` 1,283、`ReplaceRuleRepository.ets` 1,217（第六）。

所以 1,217 行本身是「一致的债」，不是「这一处特别乱」。真正值得动的是**执行逻辑那 210 行**：它本该在 `ReplaceRuleEngine.ets`（现在只有 80 行 worker 函数），留在 Repository 里导致「想单独测一条替换规则，必须先构造整个 Repository 的静态状态」（`cachedRules` / `defaultEnabled` / `injectedContext`）。上游把它独立成 `ContentProcessor.kt` 正是为了可测。

### 四、有没有 Room 的对等物：官方没有，社区三个都不够格（r363 查证）

这一节回答「本地缺 DAO 层，那有没有现成的 ORM 库可以直接补上」。结论：**官方没有，社区有三个，但都拿不到 Room 真正的价值。**

**官方：没有。** SDK 26 的 `ets/api/` 下只有一个数据库模块：

```
$ ls .../sdk/default/openharmony/ets/api/ | grep -i relational
@ohos.data.relationalStore.d.ts
@ohos.data.sendableRelationalStore.d.ets
$ ls .../sdk/default/openharmony/ets/api/ | grep -i orm
（无输出）
```

API 8/9 时代 OpenHarmony 确实有过 `@ohos.data.orm` 模块（`@Entity` / `@Columns` 注解 + `OrmObject` 基类），HarmonyOS NEXT 已移除，现在只剩裸 `relationalStore`。

**社区：三个，都在 ohpm 上。**

| 库 | ohpm 包名 | 版本 | 下载量 | 最低 API | 许可 | 最近更新 |
| --- | --- | --- | --- | --- | --- | --- |
| IBest-ORM | `@ibestservices/ibest-orm` | 2.0.4 | 1,910 | 17 | Apache-2.0 | 2026-03 |
| OCORM | `@offlinecat/ocorm` | 3.2.0 | 304 | 12 | MIT | 约 3 个月前 |
| ArkORM | `@explore-in-hmos/arkorm` | 1.0.0 | 17 | 20 | MIT | 2026-09 |

三者都声称支持装饰器定义实体、链式查询、关系映射、事务、自动迁移。ArkORM 的 README 直接写「Inspired by Android Room」，API 风格最接近；IBest-ORM 功能最全（软删除、验证装饰器、嵌套事务、查询缓存），维护最久；OCORM 刻意不用装饰器，改用 `defineEntity({...})` 对象描述表结构。

**为什么都不是 Room：三条核心价值在 ArkTS 上都落不了地。**

先看编译器的实际配置（`.../sdk/default/openharmony/ets/build-tools/ets-loader/tsconfig.json`）：

- `:1055` `"experimentalDecorators": true` —— 自定义装饰器语法可用，官方《从 TypeScript 到 ArkTS 的适配规则》也明写「ArkTS 支持自定义装饰器，语法与 TS 一致」。
- 同一份文件里**没有** `emitDecoratorMetadata` —— 装饰器拿不到属性类型，只能靠运行时手工登记。
- `:1064` `"lib": ["es2021"]` —— `Reflect` API 本身存在，但没有编译期元数据喂给它。

| Room 的能力 | 靠什么实现 | ArkTS 能否做到 |
| --- | --- | --- |
| 列名写错就编译失败 | 注解处理器在编译期生成 `XxxDao_Impl` | 否。没有注解处理器；用 hvigor 插件自写一套代码生成器是独立工程，不在本轮范围 |
| `Flow<List<T>>` 响应式，库表一变 UI 自动刷新 | Kotlin Flow | 否。要在写路径自己发通知 |
| 零运行时开销 | 生成的实现类直接调 SQLite | 否。全是运行时登记 + 运行时拼 `RdbPredicates` |

**实测 ArkORM 源码**（1,920 行，克隆在 `<workspace>tmp/probe-arkorm/`，只读）：

- `src/main/ets/core/MetadataRegistry.ets:5` 的注释自陈：`Heart of ArkORM: a registry holding entity metadata at runtime in pure ArkTS, without reflect-metadata`。它用「属性装饰器先跑、类装饰器最后跑」的两阶段 staging 手工累积元数据，正是因为拿不到 `emitDecoratorMetadata` 那层信息。
- `src/main/ets/query/QueryBuilder.ets:79` 的签名是 `where(field: string): Condition<T>` —— 传的是**裸字符串**，不是 `keyof T`。README 里写的 `db.from<User>(User).where('age').gte(18)`，字段名写错编译期不报错。「type-safe」名不副实。

**本地为什么不引入**（实测统计）：

```
46 个 Repository 文件 / 24,049 行
32 个手写 SQL 常量、145 处 SQL 字面量
JOIN：0 处
聚合（COUNT/SUM/MAX/GROUP BY）：1 处（BookRepository.ets:212 的 SELECT COUNT(*)）
INSERT OR REPLACE / INSERT OR IGNORE：38 处
事务调用：122 处
```

SQL 复杂度极低——零 `JOIN`、只有一条 `COUNT(*)`，全是单表 CRUD。引入 ORM 换来的收益，抵不上重写 24,049 行数据访问层的成本；三个库的维护度也都不高（下载量 17 / 304 / 1,910，其中下载量最高的 IBest-ORM 已 8 个月未更新）；本地大量用 `INSERT OR` 方言与 `IN (?,?,?)` 动态占位符，第三方 ORM 未必覆盖得住。

**该借鉴的是分层，不是库。** Room 真正值钱的地方，是把「SQL 在哪、业务在哪、执行在哪」三件事拆清楚——这一点本地不用装任何依赖就能拿到：把 `ReplaceRuleRepository.ets:910`–`:1120` 那 210 行执行编排搬进 `ReplaceRuleEngine.ets`（理由与第三节相同：可测性），Repository 回到「只存取」。补 DAO 层等于自建一套代码生成工具链，收益不抵成本；装第三方 ORM 则是用 24,049 行的重写换一个编译期仍然不校验字段名的库。

### 五、纠正一处误判：`EffectiveReplacesSheet` 与 `ContentProcessesSheet` 是死代码

我上一轮说「本地缺 `EffectiveReplacesSheet`，这是功能缺失」——**错了**。实测：

- `ui/book/read/sheet/EffectiveReplacesSheet.kt`（168 行）与 `ui/book/read/sheet/ContentProcessesSheet.kt`（270 行）**全仓零调用点**。`grep -rn "EffectiveReplacesSheet\|ContentProcessesSheet"` 只命中它们自己的 `fun` 声明行。
- `ReadBookScreen.kt` 里渲染浮层的块（`:387` 起二十余处 `if (state.activeSheet is ReadBookSheet.XXX)`）**没有这两个**；`ReadBookContract.kt:1307`/`:1308` 定义了 `ReadBookSheet.EffectiveReplaces` 与 `ReadBookSheet.ContentProcesses` 两个 sheet 类型，但从未被 `ShowSheet` 触发。
- `ReadBookScreen.kt:442-453` 只渲染 `ReadBookSheet.TextProcessing` 一个，它内部用 `CardTabRow` 分两页签（`R.string.replace_purify` 与 `R.string.content_processes`），内容分别是 `ReplaceRulesPage`（`:224`）与 `ContentProcessesPage`（`:390`）——**上游把「正文处理」做成了 TextProcessingSheet 的第二页签**，那两个独立浮层是被这套重构留在仓库里的旧实现。

本地正好对得上：`pages/ReaderTextProcessingSheet.ets` 也是两页签（`activeTab === 0` 替换净化 / `activeTab === 1` 正文处理），且比上游多做了「当前有效」筛选档：

- 上游 `ReplaceFilter.Effective -> rule.id in effectiveIds`（`:242`），只看 id 是否在本章生效集合里。
- 本地 `:110` 是 `this.replaceFilter === '当前有效' && this.replaceEnabled && rule.isEnabled && this.effectiveRuleIds.includes(rule.id)`，多判了 `replaceEnabled` 与 `rule.isEnabled`。这两个条件在上游语境下是冗余的（没启用的规则不会跑，也就不会进 `effectiveIds`），但本地多判的结果更保守——关掉净化后不会把上一章的缓存 id 显示成「当前有效」。

**所以这一项不是缺口，本地已经比上游多走了一步。**

### 六、判断

- **不该按文件数对齐上游。** 16 个文件是「DAO / Entity / Delegate / Sheet 全部拆开」的产物，本地没有 DAO 层，硬拆只会得到一层空转发。
- **该做的一件：把执行逻辑搬进 `ReplaceRuleEngine.ets`。** 把 `applyContent` / `previewContent` / `applyContentWithResult` / `applyTitle` / `applyContentForLength` 这 210 行从 Repository 移到 Engine，Repository 回到「只存取」。理由是可测性，不是像上游（这条的通用依据见第四节：可借鉴的是 Room 的分层，不是它的库）。
- **不该做的一件：补 `EffectiveReplacesSheet` / `ContentProcessesSheet`。** 上游自己都没接，补了等于实现上游的死代码。
- **已知残留**：`applyContentWithResult`（同步入口）仍未限时，只有阅读链路的 `applyContentWithResultAsync` 有 3000ms 预算——这一条已在上一节「阅读与规则」里登记，本轮不变。

关联：[`docs/ARCHITECTURE.md`](ARCHITECTURE.md) 5.3（仓储是无状态工具类）、[`docs/FEATURES.md`](FEATURES.md) 第二章（替换净化）、[`docs/parity/TXT-READER.md`](parity/TXT-READER.md)。

---

## 缺失的层：真缺什么、平台不给什么、别处有等价物（r364 盘点）

这一节回答「本地还缺哪些层」。方法是把上游 17 个顶层包逐个量过（`find <pkg> -name '*.kt'` 计文件、`cat` 计行），再对照本地 9 个顶层目录，把结论分成三类：**真缺且该补**、**平台不给（含社区替代方案查证）**、**本地用了别的形态（含更等价方案查证）**。所有社区库数据取自 ohpm 页面与官方文档，查证日期 2026-11-20。

上游顶层包实测：`ui` 778 文件 / 204,312 行、`help` 174 / 33,107、`data` 227 / 27,204、`model` 58 / 15,807、`feature` 78 / 14,595、`domain` 186 / 13,524、`utils` 93 / 11,504、`service` 13 / 9,078、`lib` 97 / 8,086、`base` 21 / 2,357、`core` 5 / 1,207、`constant` 14 / 1,068、`di` 2 / 955、`api` 7 / 858、`web` 5 / 514、`receiver` 4 / 290、`exception` 8 / 48。

本地顶层实测：`pages` 44 / 49,930、`data` 114 / 35,589、`reader` 10 / 5,776、`components` 25 / 3,506、`readaloud` 4 / 1,407、`model` 25 / 1,326、`lib` 6 / 1,023、`bookSource` 8 / 554、`entryability` 1 / 188。

### 一、真缺且该补的三层

#### 1. 网络请求层（最紧迫）

上游 `help/http/` **15 文件 / 2,789 行**：`OkHttpUtils.kt` 201、`CookieManager.kt` 170、`CookieStore.kt` 122、`StrResponse.kt` 88、`SSLHelper.kt` 194、`ObsoleteUrlFactory.kt` 1,200（WebView 拦截请求）、`BackstageWebView.kt` 377、`DecompressInterceptor.kt` 45、`Cronet.kt` 28、`LocalNetworkBlockedNotifier.kt` 59、`OkHttpExceptionInterceptor.kt` 24、`RequestMethod.kt` 5、`api/CookieManagerInterface.kt` 27、`OkhttpUncaughtExceptionHandler.kt` 11。

本地实测：全仓 `rcp.` 调用 **20 处**，`rcp.createSession` 只有 **2 处**（`lib/WebDav.ets:115`、`readaloud/HttpTtsPlayer.ets:462`），`AbortSignal` **零命中**。

后果：超时、重试、cookie、并发限流、取消全部散落在各调用点，没有统一入口。正在做的 `bookSource/SourceHttp.ets`（55 行）是一个 `HttpClient` 单例 + 模板替换，没有 cookie 与取消。

**社区替代：`@ohos/axios` 可用且成熟。** ohpm 实测：V2.2.15、下载量 **226,521**、被依赖 **59**、MIT、43 个版本、基于 npm axios v1.3.4 适配。提供请求/响应拦截器、取消请求、自动 JSON 转换——这三样正好覆盖上游 `OkHttpUtils` + `Interceptor` 的职责。**但要注意它解决不了 `ObsoleteUrlFactory` 那 1,200 行的活**（拦截 WebView 请求转给 OkHttp），那是平台机制差异，不是库能补的。

#### 2. 封面下载与缓存层

上游 `help/coil/` 12 文件 + `help/glide/` 14 文件，核心是 `help/coil/CoverFileCache.kt`。它的注释写明存在理由：书源封面最终 URL 常带时效 token，每次解析都不同 → 常规缓存全 miss，重启后书架要重新走网络，而且解析过程会执行书源里的 JS/Java 检查脚本，触发「未登录」「非官方版本」等自定义弹窗。所以它用**书架存下的原始封面地址**的 MD5 做键，把解密后的字节落 `filesDir`。

本地实测：`data/BookRepository.ets:862` 的 `resolveCoverUri` 只认两种本地路径——`customCoverPath` 与 `${context.filesDir}/covers/${bookId}.img`；全仓 `grep 'covers/'` 只有 `:866` 与 `:898` 两处**读**路径，**没有任何把 http 封面下载到 `covers/` 的写路径**。

这条现在就是书源线上的实际阻塞：`bookSource/WebBookService.ets:70`/`:103` 已经把 `coverUrl` 解析出来、`:78`/`:110` 做了 URL 拼接，但这个 URL 没有落点。`components/BookCover.ets:118` 的 `effectiveCoverUri()` 直接把它当本地路径喂 `Image()`。

**社区替代：两个，都不建议直接装。**

| 库 | 版本 | 下载量 | 最低 API | 许可 | 状态 |
| --- | --- | --- | --- | --- | --- |
| `@ohos/imageknife` | V3.2.10 | 161,103 | 18 | Apache-2.0 | ohpm 页面首行自陈「**已停止演进**，推荐迁移至 imageknifepro」 |
| `@ohos/imageknifepro` | V1.0.19 | 15,647 | 12 | Apache-2.0 | 53 天前发布，C 化实现，包体 **7.3 MB** |

两者都提供内存 LRU + 磁盘二级缓存 + 自定义网络下载/解码/文件缓存 + 拦截器。**但对本项目不合适**：① 我们要的不是通用图片缓存，而是「用原始封面 URL 的 MD5 做键、跳过书源脚本执行」这一条特定语义——上游 `CoverFileCache` 的价值就在这个键的选择上，通用库给的是 URL 缓存；② imageknifepro 包体 7.3 MB，为一个封面缓存引入 C 化图库不划算；③ 本地 `ImageSeedColorExtractor`（取封面主色）已经自己用 `image.createImageSource` 实现了，两套并存会更乱。**建议自己写 `CoverCache`（约 150 行：URL → md5 → 落 filesDir → 命中直接返回 file://），而不是装库。**

#### 3. 常量层

上游 `constant/` **14 文件 / 1,068 行**（`AppConst`、`AppPattern`、`PreferKey`、`BookType`、`PageAnim`、`ReadTipType`、`SourceType`、`Status`、`Theme`、`EventBus`、`IntentAction`、`NotificationId`、`AppLog`、`BookSourceType`）。

本地**没有 `constant/` 目录**。常量散在各文件顶部：`pages/ReaderSettingsPage.ets` 14 个、`ReaderPage.ets` 8 个、`BookInfoEditPage.ets` 8 个、`ReaderMarkingEditor.ets` 6 个、`BookshelfPage.ets` 5 个……`pages/` 下共 55 处顶层 `const`。`lib/AppLog.ets` 32 行。

这一层没有「等价物」可找——它本来就是纯约定，不是库。**建议只在新增模块时抽，不回头大改**（否则 55 处 const 的搬迁会污染 diff，收益却只是整理）。

### 二、平台不给：三个，且都查过社区有没有替代

| 上游层 | 规模 | 本地 | 社区有没有等价物 |
| --- | --- | --- | --- |
| `di/` 依赖注入（Koin） | 2 文件 / 955 行 | 无 | **没有**。`docs/ARCHITECTURE.md` 7.1 已查过 GitHub 与 SDK 两处：搜到的全是示例工程（CoolMallArkTS ⭐79、HarmonyKit ⭐46、arkts-mvvm-v1-skill、HarmonyStudy ⭐8），没有可 `ohpm install` 的 DI 容器；SDK 里按 `inject|di\.|ioc|provider` 过滤只命中 `insightIntentProvider.d.ts` 这类无关声明。本轮复查 ohpm 亦无。 |
| `domain/gateway/`（63 个接口） | 63 文件 / 1,349 行 | 无 | **不搬，但理由要说对。** 先更正本节初稿的一处错误判据：初稿写「Gateway 的前提是多实现可切换，本地 `new XxxRepository(` 全仓 0 处」——这个 grep 证明不了任何事，它只是本地「46 个 Repository 里 45 个无 `constructor`、全是静态方法」的产物。实测上游 63 个 Gateway **每个都只有一个生产实现**（按 `: XxxGateway {` 检索实现类，无一例外），测试里的 24 个 `Fake*Gateway`/`Stub*Gateway` 才是第二个实现。Gateway 的真实作用是**隔离层间依赖**：`domain/gateway/*.kt` 里 `import androidx.room` / `@Entity` / `@Dao` **零命中**，domain 不依赖 Room。但**上游自己也没做干净**：`domain/usecase/` 54 个文件里 **26 个仍 `import io.legado.app.data.*`**（`data.entities.Book` 11 次、`data.repository.BookRepository` 7 次、`data.dao.BookSourceDao` 2 次），`domain/` 下 `import android.`/`androidx.` 共 19 处（含 `androidx.compose.runtime.Stable`）。本地根本没有 `domain` 目录（`grep 'UseCase|Gateway'` 命中 7 个文件全是注释引用上游），**没有对象可隔离**，所以不搬。真正该借鉴的是「业务决策与存储分离」这条写法，见第四节。 |
| `base/`（Activity / DialogFragment 基类） | 21 文件 / 2,357 行 | 无 | **平台机制不同**。ArkUI 没有 Activity 生命周期，页面是 `@Component` struct。`base/` 里真正可搬的只有 `AppContextWrapper`（字号缩放），本地已等价实现：`data/AppFontSettings.ets` + `pages/Index.ets:3839` 的 `setFontSizeScale`。 |

补充一条容易误判的：`lib/prefs/`（上游 14 文件 / 1,531 行）**不是缺口**——平台 `@ohos.data.preferences` 就是等价物，本地已在用。`lib/mobi/`（34 文件 / 1,632 行）也不是——本地 `data/mobi/MobiRepository.ets` 已实现。

### 三、测试：本地几乎没有，这是比常量层更要紧的缺口

上游 `app/src/test/` 是 **359 文件 / 43,999 行**（`find` + `cat` 实测）。本地 `entry/src/ohosTest/` 全部 **126 行**：`testability/TestAbility.ets` 30、`testrunner/OpenHarmonyTestRunner.ets` 57，加上两个 smoke 用例（`LaunchSmoke.test.ets`、`List.test.ets`），没有一条覆盖数据层或业务逻辑。

这条列在这里，是因为它决定了别的层「补了有没有用」：上游那 24 个 `Fake*Gateway`（`AnalyzeChapterSpeechUseCaseTest` 的 `MemoryChapterSpeechGateway`、`ResolveBookshelfConflictUseCaseTest` 的 `StubOtherSettingsGateway`、`AboutViewModelTest` 的 `FakeBackupSettingsGateway` 等）全部服务于这套测试。**本地没有测试体系，Gateway 的测试替身价值在本地也落不了地**——这是「不搬 Gateway」的第二个理由，比第一条更硬。

同时它也是第四节那条写法的价值所在：把业务决策抽成不碰存储的纯函数，才可能在没有测试体系的地方先补上单测。

### 四、那 28 个干净 usecase 代表什么写法

`domain/usecase/` 54 个文件里，28 个不 `import io.legado.app.data`。但这 28 个不能一概而论，实测分两类：

**纯转发，没有借鉴价值。** `GetReadingProgressUseCase.kt` 26 行全是 `return gateway.xxx()`；`HomeDashboardUseCase.kt` 91 行里 10 次 `gateway.` 调用、0 行 `if/for/when` 控制流；`CoverAlbumUseCase.kt` 38 行 11 次调用；`WebDavBackupUseCase.kt` 41 行 1 次调用。这类抄过来只是多一层空壳。

**有真业务，且业务不碰存储。** `GenerateBookshelfAutoGroupPlanUseCase.kt` **487 行，只有 5 次 gateway 调用**，几乎全是规则与冲突处理；`AiChatGenerationUseCase.kt` 430 行 / 6 次调用；`BuildSpeechPlanUseCase.kt` 179 行 / 1 次调用；`DeleteBooksUseCase.kt` 27 行，核心是这一段：

```kotlin
books.forEach { book ->
    if (book.isLocal) {
        localBookGateway.deleteBook(book.bookUrl, deleteOriginal)
    } else {
        bookSourceCallbackGateway.onDeleteFromShelf(book.bookUrl)
    }
    bookRepository.deleteChaptersByBook(book.bookUrl)
}
```

它写的是「本地书删文件、网络书通知书源、都删章节、最后删书」这个**顺序与条件**，不是「怎么删 SQL」。`if (book.isLocal)` 是业务判断，`deleteChaptersByBook` 只是被调用。

**判据**：新文件不碰 `getStore(`、不碰 `context`，只接收数据、返回数据。这样它能被直接测，不需要先造 Repository 的静态状态。

**本地可落地的三处**（都不是建 `domain/` 包）：

| 上游 | 本地现状 | 可落地形态 |
| --- | --- | --- |
| `DeleteBooksUseCase` 的删除编排 | `data/BookRepository.ets:1576` 的注释自陈「照上游 DeleteBooksUseCase：外键 CASCADE 在 relationalStore 里实测不生效」，逻辑搬了但落在 Repository 里 | 抽成 `data/BookDeletionPolicy.ets`，只收 `Book[]`，返回删除顺序 |
| `GenerateBookshelfAutoGroupPlanUseCase` 487 行业务 | 本地书架自动分组逻辑位置未查证 | 抽成纯函数模块：输入书架列表 + 规则，输出分组计划 |
| `ContentProcessor.kt` 297 行执行编排 | `data/ReplaceRuleRepository.ets:910`–`:1120` 的 210 行 | 搬进 `ReplaceRuleEngine.ets`（现只有 80 行 worker 函数） |

### 五、本地用了别的形态：三条，都查了有没有更等价的方案

#### 1. 事件总线：`AppStorage` 广播 vs `@ohos.events.emitter`

上游 `constant/EventBus.kt` + `utils/EventBusExtensions.kt`（EventBus 库）。本地实测：`AppStorage.setOrCreate` / `AppStorage.link` **76 处**用来做跨页通知，`@ohos.events.emitter` **零命中**。

**更等价的方案：SDK 自带的 `@ohos.events.emitter`，不需要装任何库。** SDK 26 实测 `@ohos.events.emitter.d.ts` 共 **684 行 / 17 个 function**，提供 `on(eventId: string, callback)` / `once` / `off` / `emit`，并有泛型版 `on<T>(eventId: string, callback: Callback<GenericEventData<T>>)`（`:100`/`:136`/`:222`），**类型安全**。

为什么它比 `AppStorage` 更合适：`AppStorage` 是**状态容器**，用它做通知等于「把事件塞进全局状态再读出来」，语义错位且会留下无人清理的键；`emitter` 是**发布-订阅**，正是上游 EventBus 的语义，且 `off` 能正确解绑。`docs/ARCHITECTURE.md` 7.6 已经把「一个极简事件广播（几十行，`@ohos.events.emitter` 就够）」列为朗读的硬前置——**这条结论现在有了 SDK 行号支撑，可以直接执行**。

#### 2. ViewModel 层：`@State`/`@Prop` 直传 vs `@ObservedV2` Store

上游 `domain/usecase` 55 文件 + 各页 ViewModel 共 99 个。本地实测：`@State` **1,004 处**、`@Prop` **870 处**、`@StorageProp` **933 处**、`@Link` **0 处**、`@ObservedV2` **0 处**。

**更等价的方案：官方 `@ObservedV2` + `@Trace` + `AppStorageV2.connect`，也不需要装库。** 这条已在 `docs/ARCHITECTURE.md` 7.2 判定为「该搬，唯一真有价值的一层」，7.3 给了混用写法的四条硬约束与最小验证步骤。本轮补充两点查证：

- 官方有专门教程《MVVM 模式（状态管理 V2）》与《@ObservedV2 装饰器和 @Trace 装饰器》，说明这是官方推荐路径而非民间方案。
- 社区**没有**可 `ohpm install` 的状态管理库——和 DI 一样，官方立场是「ArkTS 的状态管理是语言级内置的，不需要第三方库」。

#### 3. 工具层：`lib/` 6 文件 vs 上游 `utils/` 86 文件

上游 `utils/` **93 文件 / 11,504 行**：`EncodingDetect`、`EncoderUtils`、`MD5Utils`、`TimeUtils`、`StringUtils`、`ColorUtils`、`Throttle`、`Debounce`、`RegexDeadlineSequence`、`SvgUtils`、`QRCodeUtils`、`NetworkUtils` 等 86 个。

本地 `lib/` **6 文件 / 1,023 行**（`AppLog`、`TagColorUtils`、`TimeAgo`、`WebDav`、`WebDavConfig`、`WebDavSync`）。逐项抽查：`debounce`/`throttle` 全仓仅 1 个文件命中且是业务局部变量；`UUID` 零命中；`MD5` 只在 `data/BackupCrypto.ets` 内部实现。

**没有「更等价的方案」**——这些都是纯函数工具，装库不如按需写。**建议遇到再补，不预先建层**：这类文件单个都很小（上游 86 个平均 134 行），预先抽象反而增加理解成本。

### 六、还有一层容易被忽略：RSS 整层

本地**有数据层无功能层**：`model/RssSource.ets`、`data/RssSourceRepository.ets`（182 行）、`RssSourceImporter.ets`、`RssStarRepository.ets`（194 行）、`RssStarImporter.ets` 都在，但只做**备份导入导出**——`RssSourceRepository.ets` 里 `grep 'fetch|http|rcp|parse'` 只命中一条注释。

本地**没有任何 RSS 页面**（`ls pages/ | grep -i rss` 零输出），没有 feed 抓取，没有 feed 解析。上游 RSS 是 **33 文件 / 6,996 行**。

`docs/FEATURES.md:453` 写着「书源、RSS 源、RSS 收藏、规则订阅、服务器配置都已接通」——**这句话只对备份导入导出成立**，对抓取与阅读不成立。这是本轮发现的**文档失真**，已在 FEATURES 该行加了限定说明。

**平台侧不缺能力**：`@ohos.xml`（`XmlPullParser`，`:611` 起，`parseXml` `:645`、SAX `:680`）与 `@ohos.convertxml`（`ConvertXML.convertToJSObject` `:255`）都能解析 feed。社区也有 `prof18/RSS-Parser`（KMP），但那是 Kotlin 的，ArkTS 用不上。**该不该做取决于范围**：这一条不在「缺一层」的范畴，是「整块功能没做」，需先确认是否在范围内。

### 七、判断与顺序

1. **测试体系** —— 本地 126 行 vs 上游 43,999 行，没有一条覆盖数据层或业务逻辑。它排在最前不是因为它最急，而是因为**别的层补了有没有用取决于它**：Gateway 的测试替身价值、第四节那批纯函数的可测性，都要落在这上面。先补最小可行的一层（对纯函数与策略模块的单测），再谈补别的层。
2. **网络请求层** —— 真缺。`@ohos/axios` 可用（22.6 万下载、59 个被依赖），能补拦截器/取消/JSON，但补不了 WebView 请求拦截。是否引入取决于书源这条线要不要统一请求入口。
3. **事件总线** —— 已有等价物，**改用 `@ohos.events.emitter`**（684 行声明、17 个 function、带泛型），替掉 `AppStorage` 做通知。零依赖。
4. **ViewModel 层** —— 已有等价物，按 ARCHITECTURE 7.2/7.3 用 `@ObservedV2`，零依赖。存量不动，新模块立规矩。
5. **常量层** —— 真缺但收益最小，新模块顺手抽，不回头大改。
6. **业务决策与存储分离**（第四节）—— 不是一层，是一条写法。三处具体位置已列出，按可测性收益排序做：`ReplaceRuleRepository:910`-`:1120` 的 210 行 > `BookRepository` 的删除编排 > 书架自动分组。
7. **utils 工具层** —— 零碎，遇到再补，不预先建层。
8. **RSS 整层** —— 不属于「缺一层」，是整块功能未做，先确认范围。

**这一节的取证边界**：所有社区库数据来自 ohpm 页面（版本/下载量/许可/最低 API）与官方文档，**没有一个装进工程编译验证过**；上游行数为 `wc -l` 实测；本地命中数为 `grep -c` 实测。RSS 的范围问题未查 `docs/PROJECT.md` 原始表述；本地书架自动分组逻辑的具体位置未查证（第四节表格已标注）。

**本节的自我更正记录**：初稿用 `new XxxRepository( = 0` 论证「不需要 Gateway」，该判据不成立（见第二节该行）；初稿把 28 个干净 usecase 一概说成「好写法」，实测约一半是纯转发、没有借鉴价值（见第四节）。两处均已在正文改正，保留此记录以免后续误引。

关联：[`docs/ARCHITECTURE.md`](ARCHITECTURE.md) 第七章（该不该重构、7.1 DI 与状态管理库查证、7.6 事件广播与播放器持有者）、[`docs/FEATURES.md`](FEATURES.md) 第四章（RSS 能力口径）。

---

## 设备范围

- API 12 真机兼容尚未验证。HOS 模拟器检查只代表验证记录中列出的操作；N 端 API 26 数据不作为 E 端或 API 12 结论。
- r257 设备没有自定义分组，卡片上新增的私有标记/刷新状态文案未在设备上直接显示验证。

构建与设备记录见[验证记录](VALIDATION.md)，Android ZIP 字段边界见[备份恢复说明](BACKUP-RESTORE.md)。

---

## 滚动模式三批修复（2026-11-18~19，commit ebfaa08/eeec428/343749c）

**KI-REL11 滚动模式每页末行被下一页整屏纸面盖掉半行** —— commit `ebfaa08`

- **现象**：滚动档（pageAnimation=3）每滑到一页末尾，最后一行只露上半截、下半截消失，或整段空白。
- **根因**：`entry/src/main/ets/reader/ReaderCanvasSurface.ets` 的 `drawScrollSlot()` 里，每一页绘制前都 `fillPageSurface(canvas, request, layout.viewportWidthPx, layout.viewportHeightPx)` 铺一张整屏纸面；next 页的纸面起点 `offset + currentExtent` 会盖掉 current 页末尾约一个 `originYpx`（≈61vp≈2 行）。上游 `feature/reader/ReaderCanvasSurface.kt:1964-1998` 的 `drawOne` 只 translate 不填充，整屏底色由 `draw()` 开头统一刷。
- **修法**：删掉 `drawScrollSlot()` 里那三行 `if (request.pageSurfaceOpaque) { fillPageSurface(...); }`，原位留中文注释说明上游只 translate。`draw()` 开头 `:1155-1159` 已刷整屏 `pageBackgroundArgb`，无背景图时它与 `paperColor` 同源（`ReaderPage.ets:6200-6204`），有背景图时 `pageSurfaceOpaque=false` 两分支都不执行。不改 `pageScrollExtent()`、不动 `drawSlot`/`drawCurl` 的填充。
- **验收（上机，深色）**：同一本书滑到页边界横跨屏幕中部，修前包截图 `tmp/b1_before_reverse.jpeg`：屏幕中部「可恶！是数百只大小了吗？」一行被笔直水平线从字中间切断、下半截消失（逐行亮像素统计 1700–1760px 行仅 18 个亮点，为切痕带）；修后包截图 `tmp/b1_after_boundary.jpeg` + 放大 `tmp/b1_after_rowzoom.png`：页边界附近各行文字完整、无水平切痕，连滑 10 屏无整片空白/纸色块。写"第 N 屏末行从被切掉 X 像素变成完整"；未做浅色单独验收（按惯例，见 KI-REL5）。
- **副作用**：页间纸色缝隙消失属预期；章首顶部空白本就存在（originYpx 一直在），非本批引入，未动 originYpx。

**KI-REL12 底栏进度条留白窄、竖条端点与粉色进度不同源** —— commit `eeec428`

- **现象**：进度条两端留白比上游窄；竖条端点不到轨道端或越界；粉色已读端点与竖条不在同一位置（本地按轨道宽 −4 算，系统 Slider 按拇指实际行程算）。
- **根因**：本地滑块容器只有 16vp 留白，上游滑块每侧真实内缩 18vp——Row 的 `padding(horizontal=16)` 之后，滑块自己的 `padding(horizontal=8)`（`ReadBookMenuBarBottom.kt:188-190`，本地此前整层漏掉）、`ReadBookMenuBarTool.kt:104` 与 `ReaderMenuPrimitives.kt:121` 各 5vp 继续叠加（Compose 的 `Modifier.padding` 是叠加，不是取最大）；`sliderThumbOffset()` 的 travel 用 `sliderTrackWidth - SLIDER_THUMB_WIDTH(=4)`，而系统 Slider 默认 blockSize 12×12、两端 InSet 6vp，实测真实行程远小于轨道宽。
- **修法**：Slider 容器 Stack `.height(52)` 后加 `.padding({ left: 18, right: 18 })`（Row 的 16vp 不动）；新增常量 `SLIDER_THUMB_TRAVEL_INSET = 14.07`（`ReaderPage.ets:153`，带完整实测注释；2026-11-20 按洋红拇指逐像素重标定 A1=13.857 / A2=14.286），`sliderThumbOffset()` 改用 `travel = Math.max(0, sliderTrackWidth - SLIDER_THUMB_TRAVEL_INSET * 2)` 保留 `ratio*travel - travel/2`。
- **探针实测**（2026-11-18，1280×2832/密度3.5/视口365×809vp）：Slider bounds `[295,2371][985,2553]`px，X1=295/X2=985/宽 690px=197.03vp，max=100。非 clamp 区 7 点最小二乘 slope=0.169676 v/px、travel=589.4px=168.39vp、X0=344.7px；A1=(X0−X1)/3.5=14.21vp、A2=(197.03−168.39)/2=14.38vp，多组标定极差≤0.5vp（<1vp 无需重测），取 14.07。另做了对照实验：把外层 padding 从 5vp 改成 18vp 各构建一次，两端内缩逐像素相同（48.5px / 50.0px），证明该内缩是 Slider 相对自身 bounds 的固定量、与 padding 无关。探针 `console.info('[SliderProbe]...')` 两处验收后已删净（grep -c SliderProbe=0）。
- **验收（上机，深色）**：100% 竖条中心实测 935px（系统拇指理论 934.1px，差 0.9px），旧公式约 970.6px 越界约 36px；50% 竖条压在粉色右端（像素差 4–6px）；7 点拖动残差<0.4。截图 `tmp/b2_final_menu.jpeg`、`tmp/b2_drag_mid.jpeg`，布局 `tmp/b2lay.json`、`tmp/b2drag.json`。未做浅色单独验收。

**KI-REL13 滚动档进度条刻度连成线、拖动位置与读数不符** —— commit `343749c`

- **现象**：滚动档进度条上 100 个 4vp 刻度点铺满约 220vp 轨道连成一条线；拖到底时位置与页码读数不一致。
- **根因**：`isPageProgressMode()` 排除了 `effectivePageAnim() === 3`，滚动档恒走 `getProgressSliderMaximum()` 的 100 特判；`onChange` 又把滚动档分支排最前，导致滚动 + 页码档仍按百分比滚。上游 `ReadBookViewModel.kt:2172-2181` 的 `calculateSeekMax` 只看 progressBarBehavior 不分滚动档。
- **修法**：`isPageProgressMode()` 只留 `progressBehavior==='page' && localReaderPages.length>0`；删除滚动恒 100 特判，页码档上限 `currentChapterPageCount()-1`、章节档 `getChapterCount()-1`；Slider 加 `.enabled(Math.max(0, getProgressSliderMaximum())>0)`；新增唯一重置入口 `syncProgressIndexFromPosition()`（7 处赋值替换）；`onChange` 改为页码档走 `seekToChapterPage(index)`（章内页号→窗口页下标），章节档松手才 `onSelectChapterIndex(index)`；删 `seekToProgress()`。
- **验收（上机，深色）**：滚动档刻度点从"连成一片"变为本章页数对应的约 10 个可数点（`tmp/b3_scroll_slider_zoom.png`）；页码档拖到 1/4 显示 3/10、拖到 3/4 显示 8/10，跟手（`tmp/b3_drag_quarter.jpeg`、`tmp/b3_drag_threequarter.jpeg`）；翻页档回归：翻页前后页码 5/10→6/10，动作正常无退化（`tmp/b3_pageturn_menu.jpeg`、`tmp/b3_pageturn_after.jpeg`）。
- **未验项**：章节档「拖动中不动、松手才跳章」在当前 EPUB 书（暂无目录、章节档未真正切换）上未取得有效证据；代码已按上游语义实现（`onChange` 仅 End/Click 调 `onSelectChapterIndex`），但未在带目录的 TXT 书上机确认，记为"代码改到位、屏幕未确认"。无障碍文案滚动档念"页"按代码推断为预期，未设备取证。
- **保留**：`getProgressAccessibilityText` 滚动档语义、`getReaderFooterProgress`（全仓零调用）、`updateProgress`/`getWholeBookProgress` 均未改；页表未就绪时短暂回落章号语义不去对齐。

**KI-RR1 时间线删除单条会话后，合并段仍然存在**

- **现象**：上游 `ReadRecordRepository.kt:526-600` 的 deleteSession 会把「同书同日、20 分钟间隔内连续的一组会话」整组删除；
  本地 `data/ReadRecordRepository.ets:422` deleteSessionById 按五元组只删单条，删完整表重算派生层。
  时间线里一段合并显示 40 分钟的会话，删除后变成 25 分钟的那一段（只掉了最后一条），而不是整段消失。
- **影响**：不会算错时长（派生层是重算的），但「删掉这个阅读时段」的语义没兑现。
- **修法**：把时间线条目的身份从「首条会话的起止时间」改成「合并段包含的所有会话 id」，删除时整段删除；
  同时要改 isInSelectionMode 的选中集合与 selectionKey 口径，牵连侧滑、批量删除、合并对话框三处。
- **状态**：代码未改，待排期。

**KI-RR2 背景样式里的文字色只驱动卡片标签，正文文字色仍是全局单份**

- **现象**：上游 `ReadStyleItem`（`domain/model/settings/ReadStyleState.kt:21-33`）的 `textColor` / `textColorNight` / `textColorEInk` 随「当前选中的那一份样式」切换，切样式会连带改正文文字色（`ReadStyleResolver.currentMode` + `readStyleTextColor`，`ui/book/read/sheet/ThemeListContent.kt:869-878`）。本地正文文字色只有一份全局 `textColor` / `textColorNight`（`data/ReaderSettingsRepository.ets` 的 `ReaderSettingsSnapshot`），切背景样式不会改正文文字色。
- **本轮的落地范围**：给 `ReaderBackgroundStyle` 补 `textColor` / `textColorNight` 两个字段（默认表六条按上游 `assets/defaultData/readConfig.json` 逐条取值），只用于**背景样式卡片的标签字体色**——阅读设置页 `BackgroundOption`（`pages/ReaderSettingsPage.ets:4302`）与主题网格 `ThemeGridCard`（`:2069`）改成 `readerNightMode ? style.textColorNight : style.textColor`。这一处修掉了原来「按背景色明暗猜标签色」的错误启发式。
- **未做的部分（明确登记，不是遗漏）**：正文文字色没有样式级化，仍是全局单份。整体上游化会牵动 `ReaderPage.readingTextColor` 的整条 `@Prop` 链、备份 `readConfig.json` 的 `textColor` 语义、以及「信息颜色」面板的取值口径，爆炸半径远超卡片标签问题，本轮按任务书路线 B 只做卡片标签。
- **用户看得见的差别**：卡片标签色现在与上游一致（预设2 深棕 `#3E3422`、预设3 深绿 `#596C44` 等，不再是统一的 `#585963`）；但把样式从预设1 切到预设3，正文文字色不会跟着变，上游会变。
- **备份影响**：`readConfig.json` 的写出内容未变（仍是单元素数组 + 全局 `textColor`），样式表结构变化只影响本地偏好键 `legado_reader_settings` 里的 `backgroundStyles` JSON；老备份恢复后新字段走内置预设按下标补齐。

## 在线书源实现批（P0–P11，r352）遗留的已知问题

本组记录 12 批书源实现后明确保留的缺口，不是遗漏。三批准入数据、逐批提交号与未验证清单见[批次交付报告](booksource/BATCH-REPORT.md)。范围是 A1/A2 纯 URL 源（P0-ter 实测各 60%），A3/A4/C 不承诺。

**KI-BS1 段评/书评规则（ruleReview）整块缺**

- **现象**：上游书源支持 `ruleReview`（段评、书评的抓取规则），本仓引入的 `sourceengine` 规则引擎没有 `ReviewRule` 类，没有对应解析入口。
- **影响**：即使书源 JSON 里带了段评/书评规则，界面也不会展示段评/书评入口；这类规则在映射时被静默跳过。
- **状态**：代码未改、引擎能力边界，待引擎补齐后再接；不伪造「已支持」。

**KI-BS2 十个规则字段在映射时丢失**

- **现象**：`LegadoSourceMapper` 把书源 JSON 投影成引擎 `BookSource` 时，以下十个字段引擎模型无对应槽位、被静默跳过：`ruleSearch.checkKeyWord`、`ruleBookInfo.canReName` / `downloadUrls` / `relatedBooks`、`ruleToc.preUpdateJs` / `formatJs` / `isVolume`、`ruleContent.subContent` / `webJs` / `callBackJs`。
- **影响**：用了这些字段的书源相应能力不生效（如目录预更新 JS、格式 JS、正文分段子规则、回调 JS）。原 `sourceJson` 始终完整保留，不丢用户数据，只是引擎侧不用。
- **状态**：明确登记，不在本批补；补齐需先扩展引擎模型。

**KI-BS3 coverDecodeJs 与 exploreScreen 缺**

- **现象**：上游书源里的 `coverDecodeJs`（封面解码脚本）与 `exploreScreen`（发现页筛选规则）在本工程无对应消费点——引擎把二者挪到原生书源定义，本工程走的是兼容书源路径。
- **影响**：需要脚本解码的封面显示原始 URL 或空白，发现页筛选规则不生效。
- **状态**：明确登记，走兼容路径，不承诺。

**KI-BS4 `java.*` 桥 32 方法未支持，影响 107 源（11.8%）**

- **现象**：书源脚本里常用的 `java.*` 桥方法引擎只实现了一部分，缺 32 个；904 条真实库里有 107 条（11.8%）用到未支持方法。P0-ter 分层实测里 `java.connect` / `java.hexDecodeToByteArray` 是最集中的两类缺失。
- **影响**：这些脚本源执行到缺方法处即失败，是 A3/A4/C 层通过率为 0 的主因之一。P0-ter 已确证 `getElements`（55 源）、`connect`（24 源）**可能**有等价实现，但本批未验证替代路径，不记作已支持。
- **状态**：明确登记；脚本源不承诺，`getElements`/`connect` 的替代有待专门验证批次。

**KI-BS5 书源校验（单条 / 批量 / 六项设置）整块未做**

- **现象**：上游有书源健康度校验（单条校验、批量校验与六项校验设置）；P4 管理页批量面板里「校验书源」按钮虽显示，但点开没有真正的校验执行链。
- **影响**：用户无法在应用内批量检验书源是否可用、哪些规则失效。
- **状态**：明确登记未做，不把按钮显示冒充功能可用。

**KI-BS6 首页模块（homepageModules）不做**

- **现象**：上游书源可声明首页模块（`homepageModules`），本工程首页不消费它。
- **影响**：书源提供的自定义首页模块不展示。
- **状态**：明确登记，范围外。
