# 架构：本地与上游的结构差异

本文件回答一个问题：**这套移植在原理上和上游一致吗。** 答案分两半——数据与算法那半是刻意保真的，代码怎么组织那半是有意不同的。两半都给出实测数字和复核命令，避免日后凭印象争论。

适用范围：`entry/src/main/ets`（本地）与 `app/src/main/java/io/legado/app`（上游，仓库 `legado-with-MD3`）。所有数字按 2026-11-11 的 HEAD 实测，复核命令见末节。

## 一、结论

**上游是三层：界面 / 编排 / 数据。本地是两层：页面 / 数据。中间那层（ViewModel + UseCase + Gateway）没有对应的东西。**

这不是漏做，是 ArkTS 侧没有 Compose、Flow、Koin 的等价物，硬造一层等于自研框架。当前的取舍是：把保真预算全部投在「备份包能互通、正文能排版、目录能解析」上，界面与数据的连接方式按鸿蒙的写法重来。

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
| `ui/` | 778 文件 / 204,312 行 | 400 个文件含 `@Composable`，99 个 `*ViewModel.kt` |
| `domain/` | 186 文件 / 13,524 行 | 51 个 `*UseCase.kt`、59 个 `*Gateway.kt` |
| `data/repository/` | 82 个 class / 12,977 行 | 构造函数注入依赖，`viewModelScope` 管生命周期 |
| 数据库 | Room `version = 133` | 65 个实体、84 个 `AutoMigration`、1 个 view |
| 事件 | `constant/EventBus.kt` | 44 行，跨模块刷新靠它 |

上游界面拿数据的写法（`ui/main/bookshelf/BookshelfScreen.kt:174`、`:187`、`:206`）：

```kotlin
viewModel: BookshelfViewModel = koinViewModel(),
val state by viewModel.uiState.collectAsStateWithLifecycle(),
onIntent = viewModel::onIntent,
```

也就是说界面不知道仓储存在。但**上游自己也不是纯分层**：`ui/` 有 88 个文件直接 import `data.repository`，其中 55 个是 ViewModel（可接受），1 个是 `ui/book/read/ReadBookScreen.kt`（例外），另 32 个是普通 Composable。这一点要如实记下，否则会把上游当成理想模型去追。

## 四、本地的骨架（实测）

| 层 | 规模 | 关键要素 |
| --- | --- | --- |
| `pages/` | 39 文件 / 39,180 行 | 167 个 `@Component`、61 个 `export struct` |
| `data/` | 86 文件 / 28,071 行 | 877 个 `static` 方法、304 个 `static` 字段 |
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

`pages/Index.ets` 9,241 行、289 个 `@State`、336 处 `Repository.` 调用、93 处 `AppRoute.` 分支。上游对应的是 99 个 ViewModel，每个数十到两千行。

直接后果：**每加一个功能都要动这同一个文件**。这件事在[功能交付清单](FEATURES.md)的「卡在这几处」里反复出现，根因是它。

### 5.2 状态传播靠逐个传属性

全仓 `@State` 792 处、`@Prop` 782 处、`@StorageProp` 718 处、`@Watch` 88 处；而 `@Link`、`@Provide`、`@Consume`、`@Observed`、`@ObjectLink`、`@StorageLink` **全部零命中**。

没有双向绑定，也没有跨层注入。`AppStorage` 只承担主题色一类全局量：`AppStorage.setOrCreate` 26 处、23 个去重键，写入点只有 `data/ThemePalette.ets`、`pages/Index.ets`、`pages/ReaderSettingsPage.ets` 三个文件。

页面直连仓储的密度：`pages/` 下 479 处 `Repository.` 调用，按文件排前三位是 `pages/Index.ets` 336、`pages/ReaderPage.ets` 47、`pages/ProfileSubPages.ets` 28。

### 5.3 仓储是无状态工具类，不是实例

`data/` 的仓储全部是 `export class XxxRepository` + 静态方法，缓存挂在静态字段上，例如 `data/BookRepository.ets:140` 的章节缓存、`:143` 的单本正文缓存（32 MB 上限）、`:138` 的写队列。数据库句柄走 `data/RdbStore.ets:24` 的进程级单例，全仓 85 处 `getStore(`。

上游相反：82 个 `class XxxRepository(` 由 Koin 注入，生命周期跟着作用域走。差别在于**「什么时候该释放」这件事本地无法表达**——静态缓存没有宿主，页面关掉它还在。

### 5.4 迁移机制不同

上游 Room 用 84 个 `AutoMigration` 加显式迁移管理 133 个版本（65 个实体）。本地 `data/RdbSchema.ets` 是「`IF NOT EXISTS` 全量重跑 + 手写 `ALTER TABLE` + try/catch 吞掉重复列」（`data/RdbSchema.ets:590` 是唯一一条 `ALTER TABLE`）。能用，但没有版本化的升级路径；每加一列都要同时改建表语句、`select` 列序、`insert` 占位符三处，漏一处就是静默错位。

## 六、会影响什么

**不受影响**：备份包的读写与往返、TXT/EPUB 正文解析与排版、目录规则、替换净化、书签与阅读记录——这些都不经过中间层，两边行为等价。

**受影响**：

- **朗读**（[功能交付清单](FEATURES.md)第 3 项）：需要长生命周期播放器，且播放状态要跨页面存活。静态工具类加无事件总线撑不住。
- **在线书源抓取**：需要可取消、可并发限流的请求调度。本地目前连请求层都没有——`lib/WebDav.ets` 一个 rcp 会话是全部网络能力，`taskpool` 全仓只用过一处（`data/ReaderSearchRegex.ets:10`），`AbortSignal` 零命中。
- **功能增长速度**：见 5.1，边际成本落在 `Index.ets` 的行数上。

## 七、现在的判断

**不重构。** 这套两层的结构已经被 1,172 行对照表、26 张表和 39 个页面证明「撑得住」，而它省下的是整个领域层的自研成本。ArkTS 没有 Compose、Flow、Koin 的等价物，补这一层是造框架，不是补缺口。

**但动朗读之前，先补两个薄的东西**，而不是继续往 `Index.ets` 加回调：

1. 一个极简事件广播（几十行，`@ohos.events.emitter` 就够）——只做「某类数据变了」的通知，不承载状态。
2. 一个真正的实例化播放器持有者——跟着页面生命周期创建与销毁，而不是静态字段。

这两样都是朗读的硬前置，且都是新增文件，不波及现有页面。做完再谈要不要继续长成一层。

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

相关：[模块概览](MODULES.md)只讲入口与责任范围，[功能交付清单](FEATURES.md)讲每个功能到哪算做完，[编码规约](CODE-CONVENTIONS.md)讲改代码时要避的坑。本文件只讲结构，不重复那三份。
