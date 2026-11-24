# 平台能力缺口清单

上游（Android 版 Legado）有些能力建立在 Android 独有的系统机制上，HarmonyOS 没有对应物；有些只是框架语义不对等，能用替代方案搭出来但代码形状要变；还有些是平台机制把这层需求消掉了，本地反而不需要写。这份清单把三种情况分开，供判断「某个功能为什么没有 / 为什么写成这样」时先查这里是哪一类。

**不收三类**：上游自己就没实现的（例如 PDF 文字提取，上游把 PDF 当图片读，没有文字层）、本项目产品范围外不做的（例如漫画专用界面、平板/多栏布局）、以及纯注解之类没有运行时行为的东西。这三类在七张对照表里各自有行，但不算平台缺口。

盘面口径：在仓库根目录跑 `python scripts/parity-rows.py`，2026-11-24 得 1226 条 = 已接 1116 / 未接 87 / 不适用 23 / 待定 0。本文只汇总平台类条目，不另立判定口径。

## 一、平台没有对应能力

这一节是「真做不到」。上游有这个能力，HarmonyOS 侧没有任何 API 能实现，所以只能删掉入口、或者保留控件并如实提示。

| 能力 | 上游用在哪 | 鸿蒙侧的事实 | 对用户的影响 |
| --- | --- | --- | --- |
| 第三方文本处理扩展（`ACTION_PROCESS_TEXT`） | `parity/ZIP-BOOKMARK.md:112`、`:227`；上游 `ReadBookController.kt:2157-2206` 用 `queryIntentActivities` 收集其它应用注册的划词处理项，`:2210-2216` 受 `showSelectMenuIcon` / `textSelectMenuConfig` 控制 | Android 独有的跨应用文本处理扩展机制，HarmonyOS 无对等物，无法映射成任何本地能力 | 划词菜单只有内置项，没有其它应用提供的处理项 |
| `.rar` / `.7z` 压缩包 | `parity/TXT-READER.md:594`；上游靠原生 libarchive（C++） | 平台 `@ohos.zlib` 只覆盖 zip，`rar` / `7z` 在该模块声明文件里零命中 | 这两种后缀不能导入；ZIP / CBZ 可以 |
| 系统 TTS 的语速 / 音高 / 音量 | `FEATURES.md:195`；上游朗读靠 Android `TextToSpeech` 的 `setSpeechRate` / `setPitch` / `setVolume` | `TextToSpeechEngine` 只有 `setListener` / `speak` / `listVoices` / `stop` / `isBusy` / `shutdown`，没有这三个 setter | 语速滑杆保留并写 `ttsSpeechRate`，但系统朗读不变速；只有 HTTP 源真生效 |
| 系统 TTS 的可用音色 | `FEATURES.md:201` | 实测 zh 只有聆小珊(13) / 凌飞哲(21)，en 一个(8)，`online=0` 不支持在线音色 | 音色列表只有 3 条，不能像上游那样列一长串系统音色 |
| 应用外悬浮窗（朗读胶囊） | `FEATURES.md:197`；上游用 `SYSTEM_ALERT_WINDOW` 在桌面悬浮 | `SYSTEM_FLOAT_WINDOW` 是 `system_basic` 权限（`PermissionDefinitions.json:615`），三方应用拿不到 | 胶囊是应用内浮层，退出阅读器即消失 |
| 播放侧音频效果（变声器） | `FEATURES.md:199`；上游用 Android `AudioEffect` / `Equalizer` 处理播放中的音频 | `@ohos.multimedia.audio.d.ts` 只有 loopback 的混响 / 均衡预设，没有 Equalizer 这类播放侧效果 | 变声器入口保留，点开如实说明，不做空页面 |
| 电池优化白名单查询 | `KNOWN-ISSUES.md:68`（KI-PRIV1）；上游 `BatteryOptimizationUtils.isIgnoringBatteryOptimizations` 查状态并跳厂商设置页 | `@ohos.settings.d.ts` 全部开页函数（`:1271`-`:1410`）无 startup / background / battery / 白名单项；`ohos.settings.*` action 字面量只有 `wireless` / `manage.applications` / `application.details` 三条；`backgroundTaskManager` / `deviceStandby` / `backgroundProcessManager` 都不是「本应用是否在白名单」的查询。最接近的 `settings.openAppDetailSettingsPage`（`:1383`，@since 26）只到通用应用详情页，且状态判断做不了 | 隐私页的「后台运行权限」整行删，不保留点了弹「尚未接入」的项 |
| Cronet 网络栈 | `KNOWN-ISSUES.md:52`、`:86`（KI-DOWN1）；`CODE-CONVENTIONS.md:347` | Cronet 是 Android 侧 `org.chromium.net` 的 native 库，鸿蒙 SDK 无任何 Cronet 或等价网络栈开关 | 下载缓存页的「使用 Cronet」整行删；开关拨动不会产生任何行为差异 |
| 匿名统计（Firebase / AGC） | `KNOWN-ISSUES.md:53`、`:70`（KI-PRIV2） | 鸿蒙无 Firebase / HiAnalytics / AGC SDK：`$DEVECO_SDK/ets/api/` 下 `firebase` 与 `analytics` 零命中 | 隐私页该行整行删，不改成假开关 |
| Miuix 第二套组件库 | `KNOWN-ISSUES.md:51`、`:76`（KI-THEME1）；`parity/ZIP-THEME.md:72` | 上游 `ThemeResolver.isMiuixEngine` 依赖 `top.yukonga.miuix.kmp`（Compose 引擎专有）；鸿蒙 `ets/api/` 无 Miuix 或等价第二套组件库 | 「主题风格」下拉只剩一个选项，等于假控件，整行删 |
| Miuix 引擎下的动态取色（Monet） | `parity/ZIP-THEME.md:72` | ArkUI 没有「渲染引擎」这个概念，也没有 `DynamicScheme` / `dynamicColor` 一类声明 | 主题色不随壁纸派生，只按内置色板 |
| 主题引擎切换（两套控件体系） | `parity/ZIP-THEME.md:76`；上游 `composeEngine` 被 30 余处读取 | ArkUI 只有一套控件体系，没有可切换的等价分支 | 没有「切换控件形态」这个开关 |
| SAF 目录授权（`book tree uri`） | `parity/BOOKSHELF.md:350`；上游用 Android Storage Access Framework 拿目录树的持久授权 | 本地只能选一次目录，拿不到持久化的目录树访问权；`fs.listFile` 只吃沙箱路径，因此列不出所选目录的内容 | 智能扫描走系统选择器多选 + 确认页，不是「扫整棵目录」 |
| JVM（书源脚本任意 Java 可达） | `GLOSSARY.md:90`、`FEATURES.md:483`；上游是 Rhino（Java 版 JS 引擎，脚本可直接访问任意 Java 类） | 鸿蒙没有 JVM。本地做到「完整 ES 引擎 + 白名单化 Java 兼容层」：手写解释器 30 个 `java.*` 白名单 + QuickJS 表达式兜底 + ArkWeb 分阶段；`java.*` 桥对 904 条真实书源覆盖 92.5% | 依赖 `java.*` 深度调用的书源跑不起来；A3/A4 与 C 层脚本源通过率 0% / 4% |
| HTTP 源的 AnalyzeUrl 模板 / JS、`loginCheckJs`、`jsLib` | `FEATURES.md:204` | 这三项都依赖 JS 引擎执行任意脚本，鸿蒙无对应物 | 字段保留但不执行；HTTP 朗读源只支持纯 URL |
| 扫码 | `FEATURES.md:491` | 平台无对应扫码 API | 导入环节的扫码保留提示，弹真实说明，不伪造 |
| Android 12+ 的 stretch 回弹档位 | `VALIDATION.md:2208`；上游 `StretchingOverscrollEffect` | `enums.d.ts:1494-1526` 的 `declare enum EdgeEffect` 只有 `Spring` / `Fade` / `None`，`StretchingOverscrollEffect` 在 `ets/` 全目录 0 命中 | 回弹用 `Spring`（视觉接近但机制不同） |

## 二、框架语义不对等（能搭替代方案，但不能用来判「不适用」）

这一节来自 [Compose 与 ArkUI 语义对照](COMPOSE-ARKUI-MAP.md)：上游 Compose 有一批框架级设施，ArkUI 没有直接对应物，只能换一种写法实现。**这些不是平台 API 缺失，也不是「不适用」的依据**——它们能实现，只是代码形状不同。列在这里是为了让「为什么本地写成这样」有据可查。

| 上游 Compose | 本地 ArkUI | 差别 | 证据 |
| --- | --- | --- | --- |
| `modifier: Modifier = Modifier` 参数 | 具体属性参数 | 上游 324 处靠它让调用方定制外框；ArkUI 没有「修饰符值」这个概念，只能另开 `@Prop` 或专用参数 | `COMPOSE-ARKUI-MAP.md:32`、`:126` |
| `remember { 非状态值 }` | `private` 成员字段 | 上游作用域是「这一次组合」，本地是 struct 整个存活期，每个组件都长期持有一份 | `COMPOSE-ARKUI-MAP.md:35`、`:119` |
| `rememberCoroutineScope` | 回调抛给上层页面 | 上游 130 处；本地组件自己不该持有长任务 | `COMPOSE-ARKUI-MAP.md:39`、`:122` |
| `snapshotFlow` | 无对应 | 上游 84 处，作用是「状态变化转成流」 | `COMPOSE-ARKUI-MAP.md:40` |
| `StateFlow` / `MutableStateFlow` | 无对应 | 上游 129 / 346 处；本地没有背压与组合子，`combine` / `stateIn` 要手工展开 | `COMPOSE-ARKUI-MAP.md:42`、`:123` |
| `viewModel()` + ViewModel | 页面级状态进 `Index.ets`，跨页面进 `@ObservedV2` Store | 上游 1150 处、242 个文件含 ViewModel；本地 0 处 | `COMPOSE-ARKUI-MAP.md:43`、`:124` |
| `rememberSaveable` | preferences 手动读写 | 上游 123 处；本地没有自动化的状态保存 | `COMPOSE-ARKUI-MAP.md:46`、`:128` |
| `produceState` / `rememberUpdatedState` | 无对应 | 上游 29 / 125 处 | `COMPOSE-ARKUI-MAP.md:47` |
| Koin 依赖注入 | 无 DI | 本地仓储是静态方法，没有需要注入的东西 | `COMPOSE-ARKUI-MAP.md:50` |
| `em` 单位 | `fp` 预乘成绝对像素 | ArkUI 无 `em`；`fp` 吃全局 `setFontSizeScale`，响应式不丢 | `CURRENT.md:85` |

## 三、平台机制不同，行为等价

这几条在上游是必须写的一段逻辑，平台机制把这层需求消掉了，所以本地没有对应代码——不是漏做。

| 上游机制 | 为什么本地不需要 | 落点 |
| --- | --- | --- |
| 等待视口最多 2 秒（`VIEWPORT_WAIT_TIMEOUT_MILLIS`） | ArkUI 的 `onAreaChange` 同步给出宽高，不存在「等视口」这个异步窗口 | `parity/TXT-READER.md:285` |
| 搜索收起的两级优先级（点遮罩先收搜索条，再点才收主菜单） | 本地搜索是独立页面（`AppRoute.READER_SEARCH`），结果条与主菜单互斥显示，没有两级 dismiss 可排 | `parity/TXT-READER.md:485` |
| 滚动默认带弹性（Android `EdgeEffect` 默认 spring） | ArkUI `Scroll` 默认 `EdgeEffect.None`，回弹要逐处显式声明；声明后行为一致 | `CODE-CONVENTIONS.md:214` |

## 四、复核方式

每条的平台事实写在对应表格行的备注列里；判定依据的分类见[盘点规约](PARITY-RULES.md)第三节。本清单只是把散落在七表与各专题文档里的平台类条目集中起来，不另立口径——七表是唯一账本，与本文档不一致时以七表为准。

各节证据出处一览（都是本仓库既有文档，未新增检索）：第一节 `parity/ZIP-BOOKMARK.md`、`parity/TXT-READER.md`、`parity/ZIP-THEME.md`、`parity/BOOKSHELF.md`、`FEATURES.md`、`KNOWN-ISSUES.md`、`GLOSSARY.md`、`VALIDATION.md`、`CODE-CONVENTIONS.md`；第二节 `COMPOSE-ARKUI-MAP.md`、`CURRENT.md`；第三节 `parity/TXT-READER.md`、`CODE-CONVENTIONS.md`。
