# Compose 与 ArkUI：语义对照与移植规则

本文件回答一个问题：**照着上游 Kotlin 代码写 ArkTS 时，哪些能直接搬、哪些是看起来像其实不一样。**

[架构说明](ARCHITECTURE.md) 讲的是「本地与上游的组织结构与为什么不重构」，属于工程层。本文件讲的是**语言层**：同一个界面意图，在 Compose 和 ArkUI 里分别怎么写，代价差在哪里。写给两类人看——照着上游搬代码的人，和判断「这件事在两边的工费是否相同」的人。

实测基准：本地 `entry/src/main/ets` 与上游 `app/src/main/java/io/legado/app`；SDK 为 `sdk/default/openharmony`（基线 `6.0.0(20)`，`97c653b` 抬的）。所有数字可复跑，命令在[末节](#八怎么复核本文)。

## 一、结论

**界面怎么画：等价。状态怎么传、副作用怎么跑、组件怎么复用：不等价。**

| 层 | 判定 | 一句话 |
| --- | --- | --- |
| 布局与绘制 | 等价 | 容器、属性链、自绘 Canvas 都能一一对上，搬的时候只是换 API 名 |
| 状态存放 | **不等价** | Compose 有「这一次组合」的局部作用域与订阅；ArkUI V1 只有 struct 字段 |
| 副作用 | **不等价** | Compose 有 key、可取消、状态转流；ArkUI 只有两个生命周期钩子 |
| 复用 | **不等价** | Compose 是 `@Composable` 函数加 slot 参数；ArkUI 是 struct 加 `@BuilderParam` |

这四层里只有第一层是真正等价的，而它恰好是最容易被「界面看起来一样」说服的一层。下面所有内容都在拆后三层。

## 二、逐项对照

「判定」列只有四种取值：**等价**（搬过来就行）、**部分**（有对应物但语义窄）、**缺**（没有对应物，要自己搭）、**假等价**（有对应物但含义不同，详见第三节）。

| 上游 Compose | 本地 ArkUI | 判定 | 差别 |
| --- | --- | --- | --- |
| `@Composable fun Foo()` | `@Component struct Foo` | 部分 | 上游是函数，可重载、可内联 lambda；本地是 struct，一实例一节点 |
| `Row` / `Column` / `Box` | `Row` / `Column` / `Stack` | 等价 | — |
| `Spacer` | `Blank` | 等价 | — |
| `Modifier.fillMaxWidth()` 链 | `.width('100%')` 等链式属性 | 等价 | 表达力相同，但没有「修饰符值」这个东西 |
| `modifier: Modifier = Modifier` 参数 | 无对应 | 缺 | 上游 324 处靠它让调用方定制外框；本地只能另开 `@Prop` 或专用参数 |
| `content: @Composable () -> Unit` slot | `@BuilderParam` | 部分 | 上游 68 处；本地 3 处（`components/TopBar.ets:73`/`:74`、`components/settings/UiSection.ets:24`），都是「空默认值 + 外部注入」一种用法 |
| `remember { mutableStateOf(x) }` | `@State x` | **假等价** | 作用域从「这一次组合」变成「这个 struct 的整个存活期」 |
| `remember { 非状态值 }` | 无对应 | 缺 | 只能提成成员字段，于是每个组件都长期持有一份 |
| `derivedStateOf` | `@Computed` | 部分 | `@Computed` 是 `MethodDecorator`（`common.d.ts:942`，`@since 12`），只能装饰 V2 类的 getter；上游 69 处，本地 0 处 |
| `LaunchedEffect(key)` | `aboutToAppear` | **假等价** | 无 key、不可取消、不能在 build 中途按条件触发；上游 652 处，本地 29 处 |
| `DisposableEffect` | `aboutToDisappear` | 部分 | 只有「销毁」一个时点，没有成对的进入/退出；上游 84 处 |
| `rememberCoroutineScope` | 无对应 | 缺 | 上游 130 处；本地靠回调把工作抛给上层页面 |
| `snapshotFlow` | 无对应 | 缺 | 上游 84 处，作用是「状态变化转成流」 |
| `collectAsStateWithLifecycle` / `collectAsState` | `@StorageProp` / `@Watch` | **假等价** | 上游 253 / 10 处；本地用 754 处 `@StorageProp` 硬顶，只覆盖全局量 |
| `StateFlow` / `MutableStateFlow` | 无对应 | 缺 | 上游 129 / 346 处，没有背压与组合子 |
| `viewModel()` + ViewModel | `@ObservedV2` 单例手动取 | 缺 | 上游 1150 处、242 个文件含 ViewModel；本地 0 处 |
| `LazyColumn` / `LazyRow` / `LazyVerticalGrid` | `List` / `Grid` + `LazyForEach` | 部分 | 能力等价，但要自己写 `IDataSource` 类；上游 235 / 51 / 28 处 |
| `items(n)` / `itemsIndexed` | `ForEach` / `LazyForEach` | 等价 | 上游 `items` 955 处、`itemsIndexed` 62 处；本地 145 处 `ForEach` 对 2 处 `LazyForEach` |
| `rememberSaveable` | 无自动 | 缺 | 上游 123 处；本地要自己写 preferences 读写 |
| `produceState` / `rememberUpdatedState` | 无对应 | 缺 | 上游 29 / 125 处 |
| `animate*AsState` | `animateTo` / `.animation()` | 部分 | 上游是按状态的动画对象，本地是一次性调用；本地 `animateTo` 27 处、`.transition(` 39 处 |
| `@Preview` | `@Preview`（`common.d.ts:398`） | 等价 | 两边都没用：本地 0 处 |
| Koin `koinViewModel()` / 构造注入 | 无 DI | 缺 | 本地仓储是静态方法，没有需要注入的东西 |

## 三、五处「假等价」

这一节是全文最该记住的部分。五行代码里最贵的事，全是把左边当成右边。

### 3.1 `@State` 不是 `State`

Compose 的 `State<T>` 是一个**带订阅凭证的值**：谁读它，谁就进入它的快照作用域，它变了只有读它的那段重组。`mutableStateOf` 上游 1150 处，几乎都和 `remember`（1740 处）成对出现，意思是「这个状态只活在这个函数里，只影响读它的那几行」。

ArkUI V1 的 `@State` 是一个**带脏标记的 struct 字段**。它没有「订阅者」这个概念，变化单位是所在的自定义组件。ArkUI 内部有部分更新机制（不会整棵树重画），但**没有「订阅某段表达式」的语法**——你写不出「只有这 3 行依赖它」。

这解释了一个看起来很奇怪的事实：本地 `@Link`、`@Provide`、`@Consume`、`@Observed`、`@ObjectLink`、`@StorageLink`、`@Track` **全部 0 处**，只用单向的 `@State`（876）与 `@Prop`（783）。不是不知道这些装饰器，是细粒度订阅不存在时，双向绑定只会放大重刷范围。

### 3.2 `@Watch` 不是 `LaunchedEffect(key)`，也不是 `snapshotFlow`

`@Watch('cb')` 在**赋值之后同步调用**回调，只有这一个行为：监听单个变量、给一次通知。它做不到三件事——不能取消、不能合并连续变化、不能「等这几个值都稳定了再跑」。

所以凡是从上游搬 `LaunchedEffect(someKey) { ... }` 的地方，不能等价换成 `@Watch`。正确写法是 `aboutToAppear` 里跑一次，并在自己维护的字段里记下「上次用的 key 是什么」，下一个会改变 key 的入口里比对。本地 93 处 `@Watch` 基本都是「改了值就重算一次」，不是副作用。

### 3.3 `@Prop` 不是「参数」

Compose 里参数就是值，传下去之后子组件爱怎么读怎么读，没有方向问题。ArkUI 的 `@Prop` 是**单向的一次下行**：父变子跟着变，子改不回父。想回写只能用 `@Link`（本地 0 处）或回调（本地全部走回调）。

后果是链式复制：一个值要传给三层，就得在中间每个 struct 上写一个 `@Prop`，而中间那些组件根本不关心它。这就是 `pages/Index.ets`（10,189 行、294 个 `@State`）与 `pages/ReaderSettingsPage.ets`（**206 个 `@Prop`**）这种形态的直接来源，不是谁偷懒。

另有两点要记住：`@Prop` 对对象与数组按官方口径是**深拷贝**，大数组传下去是有成本的；`common.d.ts:508` 只有 `declare const Prop: PropertyDecorator;` 一行，**`.d.ts` 里没有任何行为信息**，语义全在编译器和运行时里——这一条对全文所有装饰器都成立。

### 3.4 `LazyForEach` 不是 `items`

Compose 写 `LazyColumn { items(list) { ... } }`，惰性是免费的。ArkUI 要惰性，必须先写一个类：

```ets
class FooDataSource implements IDataSource {
  totalCount(): number { ... }
  getData(index: number): T { ... }
  registerDataChangeListener(l: DataChangeListener): void { ... }
  unregisterDataChangeListener(l: DataChangeListener): void { ... }
}
```

四个方法一个不能少，还要自己决定数据变了之后发 `onDataReloaded()` 还是 `onDataAdd()`。本地两处范例：`pages/CatalogPage.ets:650`（数据源类在 `:34`，`CatalogChapterDataSource`）与 `pages/BookshelfPage.ets:2281`（数据源由 `:154` 处的 `bookshelfData` 提供）。**能力上完全等价，工费上一个量级。** 这就是 145 处 `ForEach` 对 2 处 `LazyForEach` 的全部原因。

### 3.5 `@Builder` 不是 `@Composable`

`@Builder`（`common.d.ts:984`，`MethodDecorator`）只能是无返回值的构建函数：不能有状态、不能有副作用、不能返回一个值、不能自己决定重刷。它适合「同一段 UI 写两遍太啰嗦」，不适合「一个需要自己状态的子组件」——后者必须建 struct。

上游 413 个文件里有 1,440 个 `@Composable`（其中行首声明 1,215 个），平均每文件 3.5 个，一个 `Row` 一个函数是常态；本地 57 个文件共 149 个 `@Component`。差的不是风格，是每拆一次组件要付出的固定成本。

## 四、这个仓的形态是这套模型的产物

把上面的结论代进实际代码，`Index.ets` 就不是「写得不好」，而是这套模型的必然结果：

| 现象 | 直接原因 |
| --- | --- |
| `pages/Index.ets` 10,189 行、294 个 `@State` | 没有 ViewModel 层，状态只能上提到页面根 |
| `pages/ReaderSettingsPage.ets` 206 个 `@Prop` | 没有 `@Link` 与 Store，值只能逐层复制 |
| 全仓 145 处 `ForEach`、2 处 `LazyForEach` | 惰性列表要先写 `IDataSource` 类 |
| `aboutToAppear` 29 处、`LaunchedEffect` 对应物为零 | 副作用只挂在组件生命周期上 |
| `@ObservedV2`/`@Trace`/`@Local`/`@Param`/`@Monitor`/`@Computed` 全 0 处 | 现有页面全用 V1；V2 类不能塞进 `@State`/`@Prop` 等 V1 状态装饰器（基线 20 下 `enableV2Compatibility` 已可用，但本仓尚未采用） |

## 五、移植时的机械替换规则

照着上游写 ArkTS 时，按下表一条条过，比凭感觉改可靠：

| 看到 | 写成 | 必须同时想到 |
| --- | --- | --- |
| `@Composable fun X()` | `@Component struct X` | 它需要自己的状态或生命周期吗？不需要就用 `@Builder` |
| `remember { mutableStateOf(v) }` | `@State v` | 父组件重建时它的值会重置；要跨重建保留就得往上提 |
| `remember { 非状态 }` | `private` 成员字段 | 它会一直活到 struct 销毁 |
| `LaunchedEffect(key) { }` | `aboutToAppear` + 自己比对 key | 没有取消、没有重跑；key 变化要自己驱动 |
| `DisposableEffect { onDispose { } }` | `aboutToDisappear` | 只有退出，没有进入时的配对清理 |
| `rememberCoroutineScope()` | 回调抛给上层 | 组件自己不该持有长任务 |
| `collectAsState()` + StateFlow | 找到最终消费点，改成 `@State` + 回调改它 | 中间那串 `combine` / `stateIn` 要手工展开 |
| `viewModel()` + `uiState` | 页面级状态进 `Index.ets`；跨页面进 `@ObservedV2` Store | 见 [架构说明](ARCHITECTURE.md) 7.3–7.4 |
| `LazyColumn { items(list) { } }` | `List` + `LazyForEach` + 新建 DataSource | 先写类，再改渲染 |
| `modifier: Modifier = Modifier` | 改成具体属性参数 | 不要伪造一个 Modifier 等价值 |
| `content: @Composable () -> Unit` | `@BuilderParam content: () => void = this.emptyContent` | 要配一个空的默认 Builder |
| `rememberSaveable { }` | preferences 读写 | 没有自动化的状态保存 |

## 六、什么能直接搬，什么必须重写

**能逐行搬的：算法与数据。** 分页（`reader/ReaderTextLayoutEngine.ets` 来自上游同一套算法）、正则、SQL、字节与编码处理、AES/ECB、ZIP 读写、Canvas 的绘制调用序列。这些不经过状态系统，两边行为等价，[架构说明](ARCHITECTURE.md) 第六节说的「不受影响」就是这一批。

**要换名但照原样写的：布局与样式。** `Row`/`Column`/`Box` 到 `Row`/`Column`/`Stack`，`padding`、`background`、`clip` 基本同名。这一层的对应关系是确定的，出错会立刻在屏幕上看见。

**必须重写的：状态、生命周期、异步调度。** 这三样没有对应物，只有替代方案，替代方案会改变代码形状。

由此得出一条判断工费的准则：**先数这个界面里有多少「状态」和「副作用」，再数有多少「布局」。** 前两个数字大，照搬的代价就大，`LazyColumn` 尤其——每搬一个惰性列表，等于多写一个类。

## 七、还有一条没被用过的路：整页 V2

[架构说明](ARCHITECTURE.md) 7.3 讨论的是**混用**（V1 组件里塞一个 V2 类当普通成员），因为那是既有页面的唯一走法。这里补一条**不混用**的路：

`@ComponentV2`（`common.d.ts:307`）与 `@Local`（`:431`）、`@Param`（`:442`）、`@Once`（`:453`）、`@Event`（`:464`）、`@Provider`（`:577`）、`@Consumer`（`:931`）、`@Monitor`（`:1040`，类型见 `:1055`）、`@Computed`（`:942`）全部 `@since 12`，本地基线够。**新页面整页用 V2、不与任何 V1 装饰器混用，是官方支持的**，限制只发生在同一个组件内。

这条路能补回一部分 Compose 的语义：`@Param` 是单向入参、`@Event` 是显式出参、`@Monitor` 能监听多个路径、`@Computed` 能缓存派生值。它补不回的是重组作用域（刷新单位仍是组件）与 `remember`（局部状态仍要写在 struct 上）。

现在本地一处都没用。要不要开这个口子与「先做六个模块」不冲突——它只影响新页面怎么写，不动存量。

## 八、怎么复核本文

```bash
# 本地装饰器分布（除前五项外应全为 0）
cd entry/src/main/ets && for d in State Prop StorageProp Watch Builder BuilderParam Link Provide Consume Observed ObjectLink StorageLink ObservedV2 Trace Local Param Event; do
  printf "%-14s %s\n" "@$d" "$(grep -rho "@$d\\b" --include=*.ets . | wc -l)"; done

# 列表能力
grep -rc 'LazyForEach' --include=*.ets . | grep -v ':0'
grep -rho 'ForEach' --include=*.ets . | wc -l

# 组件与生命周期
grep -rho '@Component\b' --include=*.ets . | wc -l
for h in aboutToAppear aboutToDisappear aboutToReuse onPageShow onBackPress; do
  printf "%-18s %s\n" "$h" "$(grep -rho "\\b$h\\b" --include=*.ets . | wc -l)"; done

# 上游 Compose 用量
cd /n/HarmonyProjects/legado-with-MD3/app/src/main/java/io/legado/app
for k in Composable remember mutableStateOf derivedStateOf LaunchedEffect DisposableEffect snapshotFlow collectAsStateWithLifecycle; do
  printf "%-28s %s\n" "$k" "$(grep -rho "\\b$k\\b" --include=*.kt . | wc -l)"; done
```

SDK 侧的行号在 `sdk/default/openharmony/ets/component/common.d.ts`，用 `grep -n 'declare const Prop'` 这类命令定位；`@since` 与装饰器种类都写在该行上方的注释里。

相关：[架构说明](ARCHITECTURE.md) 讲工程结构与为什么不重构，[编码规约](CODE-CONVENTIONS.md) 讲改代码时要避的坑，[模块概览](MODULES.md) 讲入口与责任范围。
