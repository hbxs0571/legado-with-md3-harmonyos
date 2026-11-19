# 架构：本地与上游的结构差异

本文件回答一个问题：**这套移植在原理上和上游一致吗。** 答案分两半——数据与算法那半是刻意保真的，代码怎么组织那半是有意不同的。两半都给出实测数字和复核命令，避免日后凭印象争论。

适用范围：`entry/src/main/ets`（本地）与 `app/src/main/java/io/legado/app`（上游，仓库 `legado-with-MD3`）。所有数字按 2026-11-11 的 HEAD 实测，复核命令见末节。

## 一、结论

**上游是三层：界面 / 编排 / 数据。本地是两层：页面 / 数据。中间那层（ViewModel + UseCase + Gateway）没有对应的东西。**

这不是漏做，是 ArkTS 侧没有 Flow、Koin 那一套的等价物——界面那一层是有的，ArkUI 就是（能对上的是布局与绘制；状态传播、副作用、复用三层对不上，逐条见[Compose 与 ArkUI 语义对照](COMPOSE-ARKUI-MAP.md)）。硬造这一层等于自研框架。当前的取舍是：把保真预算全部投在「备份包能互通、正文能排版、目录能解析」上，界面与数据的连接方式按鸿蒙的写法重来。

## 二、两部分各自的判定

| 维度 | 判定 | 依据 |
| --- | --- | --- |
| 备份包格式 | 一致 | 30 个文件名与目录结构按上游 `Backup.kt` 逐条对齐 |
| 数据库表结构 | 已建的逐字段一致 | 本地 26 张表与上游对应实体逐字段对齐；上游 65 个实体里另有 39 个属于尚未移植的领域（书源解析、AI、朗读等） |
| 阅读渲染 | 一致 | 两边都是自绘画布，不依赖系统文本控件 |
| 分页算法 | 一致 | 本地 `reader/ReaderTextLayoutEngine.ets` 来自上游同一套算法 |
| 网络与加密 | 一致 | WebDAV 协议与 AES/ECB/PKCS5 按上游行为实现 |
| 界面与数据的连接 | **不一致** | 上游走 ViewModel + Intent + StateFlow，本地走页面直连仓储 + 回调上抛 |
| 状态传播 | **不一致** | 上游单向数据流，本地靠逐层传属性 |
| 领域编排 | **不一致** | 上游 51 个 UseCase + 59 个 Gateway，本地为零 |

## 三、上游的骨架（实测）

| 层 | 规模 | 关键要素 |
| --- | --- | --- |
| `ui/` | 783 文件 / 206,302 行 | 403 个文件含 `@Composable`（共 1,409 处），99 个 `*ViewModel.kt` |
| `domain/` | 186 文件 / 13,710 行 | 51 个 `*UseCase.kt`、59 个 `*Gateway.kt` |
| `data/repository/` | 96 文件 / 101 个 class / 15,769 行 | 构造函数注入依赖，`viewModelScope` 管生命周期 |
| 数据库 | Room `version = 133` | 65 个实体、87 个 `AutoMigration`、1 个 view |
| 事件 | `constant/EventBus.kt` | 44 行，跨模块刷新靠它 |

上游界面拿数据的写法（`ui/main/bookshelf/BookshelfScreen.kt:174`、`:187`、`:206`）：

```kotlin
viewModel: BookshelfViewModel = koinViewModel(),
val state by viewModel.uiState.collectAsStateWithLifecycle(),
onIntent = viewModel::onIntent,
```

也就是说界面不知道仓储存在。但**上游自己也不是纯分层**：`ui/` 有 88 个文件直接 import `data.repository`，其中 55 个是 ViewModel（可接受），另 33 个是普通 Composable（`ui/book/read/ReadBookScreen.kt` 是已知例外）。这一点要如实记下，否则会把上游当成理想模型去追。

## 四、本地的骨架（实测）

| 层 | 规模 | 关键要素 |
| --- | --- | --- |
| `pages/` | 41 文件 / 42,490 行 | 130 个 `@Component`、55 个 `export struct` |
| `data/` | 108 文件 / 33,773 行 | 1,073 个 `static` 方法、320 个 `static` 字段 |
| 数据库 | `data/RdbSchema.ets` `version = 7` | 26 条 `CREATE TABLE`、10 条 `CREATE INDEX`、1 条 `ALTER TABLE` |
| 事件 | 无 | `emitter`、`EventHub`、`AppStorage.subscribe`、`observable` 全仓零命中 |

页面拿数据的写法（`pages/BookshelfPage.ets:67`-`:74`）：

```ets
@Prop books: Book[] = [];
@Prop groups: BookGroup[] = [];
@Prop @Watch('onLayoutChanged') layout: BookshelfLayoutSettings = DEFAULT_BOOKSHELF_LAYOUT;
```

数据由 `pages/Index.ets` 取好塞进来，操作靠回调抛回去。

## 五、四条具体差异

### 5.1 `Index.ets` 事实上是一个 ViewModel 兼 God Object

`pages/Index.ets` 10,189 行、294 个 `@State`、400 处 `Repository.` 调用、100 处 `AppRoute.` 分支。上游对应的是 99 个 ViewModel，每个数十到两千行。

直接后果：**每加一个功能都要动这同一个文件**。这件事在[功能交付清单](FEATURES.md)的「卡在这几处」里反复出现，根因是它。

### 5.2 状态传播靠逐个传属性

全仓 `@State` 876 处、`@Prop` 783 处、`@StorageProp` 754 处、`@Watch` 93 处；而 `@Link`、`@Provide`、`@Consume`、`@Observed`、`@ObjectLink`、`@StorageLink` **全部零命中**。

没有双向绑定，也没有跨层注入。`AppStorage` 只承担主题色一类全局量：`AppStorage.setOrCreate` 52 处、41 个去重键，写入点是 `data/PrivateAccessRepository.ets`、`data/ThemePalette.ets`、`pages/Index.ets`、`pages/ReaderSettingsPage.ets` 四个文件。

主题色这一类的实际规模：`data/ThemePalette.ets:544-554` 的 `publishPaletteColors` 一次广播 **9 个** `themeColor*` 键，消费侧 `@StorageProp('themeColor*')` 共 **555 处**、散在 **62 个 .ets 文件**里。Compose 那边 `LegadoTheme.colorScheme.xxx` 随处可取（`CompositionLocal` 自动继承），ArkUI 没有等价机制，**每个用到主题色的 `@Component` struct 都必须自己声明一行 `@StorageProp`**——这是本仓 `@StorageProp` 数量（754 处）远高于 `@State`（876）与 `@Prop`（783）同量级的主因，也是补齐上游 34 个在用色位要付的主要代价（预估 +150–250 行样板，见[已知问题](KNOWN-ISSUES.md)的 KI-THEME2）。

同一种结构性劣势在**排版**上更彻底：上游 `LegadoTypography` 有 24 个语义槽位（`ui/theme/LegadoTheme.kt:85-119`），靠 `CompositionLocal` 自动继承，全仓引用 696 处却不需要在调用点声明任何东西；本地没有这一层，1,189 处 `fontSize(N)` 直接写字面量、用到 20 种字号，`components/UiTokens.ets` 的 9 个 `FONT_*` 常量只有 5 个真被消费。要补这一层，等于把 1,189 处字面量逐个归到槽位上，且每个消费 struct 仍要自己声明一行——成本比补色位更高（见[已知问题](KNOWN-ISSUES.md)的 KI-THEME5）。

**动效这条上 ArkUI 反而给得更多**，但没人用：上游要画非规则形状的连续形变（播放键的圆↔八瓣、下拉刷新的软爆裂、加载圈的 morph），只能靠 Compose 的 `RoundedPolygon` / 逐点插值自己算；ArkUI 提供了 `@AnimatableExtend` + `AnimatableArithmetic<T>`（`component/common.d.ts:1029` / `:1195`，均 `@since 10`），把「怎么在两个点集之间插值」交给业务实现四个方法（`plus`/`subtract`/`multiply`/`equals`），框架逐帧回调。r356 上机实测：驱动 `Polygon.points` 插值速率 **118.6–240 次/秒**，`springMotion` 下 `multiply` 仍被逐帧调用，128 顶点无卡顿。本仓 `grep AnimatableExtend` **0 命中**——能力在，一行没用（见[已知问题](KNOWN-ISSUES.md)的 KI-THEME6）。

这条也说明本仓的问题性质：**平台缺的比想象少，缺的是把平台能力接到业务上**。上面排版、色位那两条是真受 ArkUI 的结构性限制（没有 `CompositionLocal` 等价物）；形变这条不受限，纯粹是没做。

页面直连仓储的密度：`pages/` 下 571 处 `Repository.` 调用，按文件排前三位是 `pages/Index.ets` 400、`pages/ReaderPage.ets` 47、`pages/ProfileSubPages.ets` 30。

### 5.3 仓储是无状态工具类，不是实例

`data/` 的仓储全部是 `export class XxxRepository` + 静态方法，缓存挂在静态字段上，例如 `data/BookRepository.ets:140` 的章节缓存、`:143` 的单本正文缓存（32 MB 上限）、`:138` 的写队列。数据库句柄走 `data/RdbStore.ets:24` 的进程级单例，全仓 91 处 `getStore(`。

上游相反：84 个 `class XxxRepository` 由 Koin 注入，生命周期跟着作用域走。差别在于**「什么时候该释放」这件事本地无法表达**——静态缓存没有宿主，页面关掉它还在。

### 5.4 迁移机制不同

上游 Room 用 87 个 `AutoMigration` 加显式迁移管理 133 个版本（65 个实体）。本地 `data/RdbSchema.ets` 是「`IF NOT EXISTS` 全量重跑 + 手写 `ALTER TABLE` + try/catch 吞掉重复列」（`data/RdbSchema.ets:590` 是唯一一条 `ALTER TABLE`）。能用，但没有版本化的升级路径；每加一列都要同时改建表语句、`select` 列序、`insert` 占位符三处，漏一处就是静默错位。

## 六、会影响什么

**不受影响**：备份包的读写与往返、TXT/EPUB 正文解析与排版、目录规则、替换净化、书签与阅读记录——这些都不经过中间层，两边行为等价。

**受影响**：

- **朗读**（[功能交付清单](FEATURES.md)第 3 项）：需要长生命周期播放器，且播放状态要跨页面存活。静态工具类加无事件总线撑不住。
- **在线书源抓取**：需要可取消、可并发限流的请求调度。本地目前连请求层都没有——`lib/WebDav.ets` 一个 rcp 会话是全部网络能力，`taskpool` 全仓只用过一处（`data/ReaderSearchRegex.ets:10`），`AbortSignal` 零命中。
- **功能增长速度**：见 5.1，边际成本落在 `Index.ets` 的行数上。

## 七、现在的判断

**不重构。** 这套两层的结构已经被 1,226 行对照表、26 张表和 41 个页面证明「撑得住」，而它省下的是整个领域层的自研成本。ArkTS 有界面框架（ArkUI 对应 Compose），缺的是 Flow、Koin 与 ViewModel 那一层，补中间这一层是造框架，不是补缺口。

下面六个小节是这条判断的依据：有没有现成等价物、哪些差异能补、混用该怎么写、先做功能还是先改架构、以及两件要提前做的事。

### 7.1 有没有现成的等价物：依赖注入与状态管理库都没有

- **GitHub 上没有可用的库。** 搜出来的全是示例工程或脚手架：`Joker-x-dev/CoolMallArkTS`（⭐79，电商 demo，分层是示范写法）、`Joker-x-dev/HarmonyKit`（⭐46）、`Mxl5352/arkts-mvvm-v1-skill`（讲分层排查的 Codex skill）、`seasonZhu/HarmonyStudy`（⭐8）。**没有一个是可 `ohpm install` 的依赖注入容器或状态管理库。**
- **SDK 里也没有依赖注入。** 在 `sdk/default/openharmony/ets/api/` 下按 `inject|di\.|ioc|provider` 过滤，只命中 `insightIntentProvider.d.ts`、`formProvider.d.ts` 这类与依赖注入无关的声明。
- **这是语言选择，不是生态缺口。** 华为云社区文章原话：「别找了。鸿蒙有自己的状态管理系统，而且不需要第三方库。ArkTS 的状态管理是语言级内置的」（`https://bbs.huaweicloud.com/blogs/480642`）。

取证边界：ohpm 官方仓库未实测，本节只断言 GitHub 与本地 SDK 两处。

### 7.2 哪些差异能补，哪些不能

| 上游构件 | ArkTS 有等价物吗 | 该不该搬 | 依据 |
| --- | --- | --- | --- |
| Compose（Screen 是纯函数） | 有，ArkUI 就是 | 布局层可直接搬；状态 / 副作用 / 复用三层不等价 | 全仓 149 个 `@Component`（散在 57 个文件）；四层判定与逐项对照见 [Compose 与 ArkUI 语义对照](COMPOSE-ARKUI-MAP.md) |
| Koin 依赖注入 | **没有**，生态也没有 | 不搬 | 本地 `new XxxRepository(` 全仓 **0 处**，仓储本来就是静态方法，没有需要注入的东西 |
| Gateway 接口层（上游 59 个） | 没有接口实现切换的诉求 | 不搬 | 没有多实现与测试替身场景 |
| UseCase（上游 51 个） | 无框架依赖 | 选择性搬 | 本地 `UseCase` 命中 6 处，**全是注释里引用上游** |
| **ViewModel（上游 99 个）** | **有**：`@ObservedV2` 类 + `AppStorageV2.connect` | **该搬，唯一真有价值的一层** | 见 7.3 |
| Flow / StateFlow | 无 | 用 `@Trace` + `@Monitor` 顶 | 能观察属性变化，补不回背压与组合子（见语义对照 3.2） |

### 7.3 混用怎么写：V2 类当普通成员

官方文档《状态管理V1和V2混用指导（API version 19及之后）》限制条件第 1 条（`https://developer.huawei.com/consumer/cn/doc/harmonyos-Guides/arkts-v1-v2-mixusage`，页面更新于 2026-11-10）原文：

> V1装饰器不能和 @ObservedV2 一起使用。因为@ObservedV2/@Trace有自己独立的观察能力，不仅可以在 @ComponentV2 中使用，也可以独立在 @Component 中使用，状态管理框架不希望其观察能力和V1的观察能力混合使用，所以依旧维持禁止现状。

这句话划出了可用区间：**类可以加 `@ObservedV2` + `@Trace`，只要不把它塞进 V1 的状态装饰器。**

- 可以：`@Component` 里写普通成员 `private store = XxxStore.get();`
- 不可以：`@Component` 里写 `@State store = new XxxStore();` —— 编译报错。同一文档的限制条件原文：「使用@ObservedV2与@Trace装饰的类不能和 @State 等V1的装饰器混合使用，编译时报错」
- 也不可以靠继承绕：`class Sub extends ObservedV2Class` 再做 `@State` —— 运行时报错（同一文档：「继承自@ObservedV2的类无法和@State等V1的装饰器混用，运行时报错」）
- 另两条硬限制：`@ObservedV2` 只能装饰 class，不能装饰 struct；`@Trace` 只能装饰 `@ObservedV2` 类里的属性，且不支持 Function 类型（改了不刷新）

官方另提供 `enableV2Compatibility` / `makeV1Observed`（`UIUtils`）把 V2 类喂给 `@Prop` / `@ObjectLink`，两者 **`@since 19`**（`@ohos.arkui.StateManagement.d.ts:416` / `:431`，`makeObserved` 是 `@since 12`，见 `:393`）。本地基线已在 `97c653b` 抬到 `6.0.0(20)`，两者**已可用**；实测探针（`@ObservedV2` 类既作 `@Component` 普通成员、又经 `enableV2Compatibility` 喂给 `@State`）一次编译通过，所以上面那条最小路径不再是唯一选项，但仍是最省事的一条。

装饰器与本机基线（`sdk/default/openharmony/ets/component/common.d.ts` 实测）：`ComponentV2` `:307`、`ObservedV2` `:387`、`Local` `:431`、`Param` `:442`、`Trace` `:497`、`Provider` `:577`、`Consumer` `:931`、`Computed` `:942`、`LocalBuilder` `:995`、`Monitor` `:1040`，全部 `@since 12`；`AppStorageV2` 在 `@ohos.arkui.StateManagement.d.ts:125`，同样 `@since 12`。

**未在本仓实测的一点**：`@ObservedV2` 类作为 V1 组件的普通成员时，`@Trace` 属性变化能否触发该组件刷新。官方原文说可以，但第一个 Store 落地时要先花五分钟验证：写一个 `@ObservedV2` 计数器，在 `@Component` 里 `Text(String(this.store.count))` + 一个按钮 `this.store.count++`，看数字变不变。

### 7.4 顺序：先做六个模块，同时立一条规矩

先改架构会让六个模块返工——架构改动要拿真实页面当验证载体，六个模块没做完时等于拿半成品做手术。反过来，先做六个模块只在「继续沿旧路子加 `@Prop`」这一种情况下返工，而这可以用规矩堵住：

> **跨页面共享的新状态一律进 `@ObservedV2` 单例 Store，不再往 `Index.ets` 加 `@State`、往页面加 `@Prop`。存量不动。**

这样六个模块做完时，朗读的播放器状态、阅读记录的统计、外观的配色天然是 store 形态，`Index.ets` 不再变大；收尾时再回头收存量，改动量只减不增。写进[编码规约](CODE-CONVENTIONS.md)第八节。

改动量按 2026-11-11 实测估算：只做 Store 化约 2,000–3,000 行改动、`Index.ets` 可减 1,500–2,000 行，可分模块增量做；全量对齐上游四层（Screen + ViewModel + UseCase + DI）是 2–3 万行，等于重做整个界面层，不可行也不必要。

### 7.5 提前做的一小块：`ReaderSettingsPage` 的四处挂载

`pages/Index.ets` 里同一个页面挂了四份：`:8351`（303 个键）、`:9140`（302 个）、`:9519`（292 个）、`:9816`（288 个），合计 **1,200 行**。键集还不一致：`:9140` 比 `:8351` 缺 `openBottomActionConfigOnAppear`，`:9519` 缺 11 个（`bottomIconStyle`、`bottomItemsPerRow`、`bottomRowCount`、`bottomActions`、`topActions` 等），`:9816` 缺 15 个。

这件事与做不做架构无关，它现在就在拖累每一次改阅读设置。改阅读器模块时收敛到一处，或至少把重复的键抽成常量。

### 7.6 动朗读之前仍要先补两个薄东西

而不是继续往 `Index.ets` 加回调：

1. 一个极简事件广播（几十行，`@ohos.events.emitter` 就够）——只做「某类数据变了」的通知，不承载状态。
2. 一个真正的实例化播放器持有者——跟着页面生命周期创建与销毁，而不是静态字段。

这两样都是朗读的硬前置，且都是新增文件，不波及现有页面。做完再谈要不要继续长成一层。

补完这两样之后，朗读本身还差一层结构。上游的朗读有三条引擎路径：系统 TTS、自建 HTTP 源、七家云端 provider。本地前两条已落，第三条整层未建（见[已知问题](KNOWN-ISSUES.md)的「云端 TTS 整层未建」）；而上游云端那一层并不是第三条通道——它把云端引擎合成成一个假的 `HttpTTS` 源，塞进同一条 HTTP 播放服务。这一点对本地的影响是：要补云端，改的是数据层（一张 `cloud_tts_engines` 表 + 一个 provider 接口 + 七家实现），不是播放层。

平台侧给出的能力分布也值得记在这里，因为它决定了架构的天花板：**推流给了，插槽没给**。`AudioRenderer.on('writeData')`（`@ohos.multimedia.audio.d.ts:6871`）能让应用自己喂 PCM，所以「边合成边播」是架构上做得到的；但鸿蒙没有系统 TTS 引擎插槽（五条证据链见[已知问题](KNOWN-ISSUES.md)的「朗读的平台底座」），所以「把朗读做成独立服务、让别的应用调用」这条路在鸿蒙上不存在对应物，不要按那个形态设计。本仓现状是整包播放（`readaloud/HttpTtsPlayer.ets` 的 `downloadToFile` + `AVPlayer(fdSrc)`），`createAudioRenderer` 在 `entry/src/main/ets` 里零命中。

## 八、怎么复核本文

数字全部可复跑，命令在仓库根执行：

```bash
# 本地两层规模
cd entry/src/main/ets && wc -l pages/*.ets data/*.ets | tail -1
# 本地装饰器分布（最后六项应为 0）
for d in '@State' '@Prop' '@StorageProp' '@Watch' '@Link' '@Provide' '@Consume' '@ObjectLink' '@StorageLink'; do
  printf '%-14s %s\n' "$d" "$(grep -rho "$d" --include=*.ets . | wc -l)"; done
# 页面直连仓储密度
grep -rho 'Repository\.' pages/*.ets | wc -l
# 上游三层规模
cd /n/HarmonyProjects/legado-with-MD3/app/src/main/java/io/legado/app
for d in ui domain data help; do printf '%-8s %s\n' "$d" "$(find $d -name '*.kt' | wc -l)"; done
find ui -name '*ViewModel.kt' | wc -l; find domain -name '*UseCase.kt' | wc -l
```

相关：[模块概览](MODULES.md)只讲入口与责任范围，[功能交付清单](FEATURES.md)讲每个功能到哪算做完，[编码规约](CODE-CONVENTIONS.md)讲改代码时要避的坑。本文件只讲结构，不重复那三份。[Compose 与 ArkUI 语义对照](COMPOSE-ARKUI-MAP.md)讲语言层的搬代码规则。
