# 编码规约

本文件收纳已经踩过的实现类缺陷，写成可对照的检查项。它不是风格指南，每条都对应一次真实故障。

## 一、ForEach 的 key 必须覆盖会变的展示字段

**规则**：`ForEach` 的键函数不得只返回 `item.id`。只要条目外观依赖某个可变更字段，该字段就必须进入 key，否则 ArkUI 会复用旧节点，出现「数据已改、界面还是旧的」。

原因是 ArkUI 按 key 做节点复用：key 不变即视为同一条目，只更新绑定的属性值；而条目内部由 `if`/`Text` 直接读取的字段不会重新求值。

**本项目已统一改用键函数的四处**（改这些文件时不要退回 `item.id`）：

| 键函数 | 位置 | 纳入 key 的字段 |
| --- | --- | --- |
| `replaceRuleRowKey(rule)` | `entry/src/main/ets/model/ReplaceRule.ets:19` | `id`、`isEnabled`、`name`、`group`、`pattern`、`replacement`、`scope`、`excludeScope`、两个 scope 布尔、`isRegex` |
| `bookCardKey(book)` | `entry/src/main/ets/pages/BookshelfPage.ets:64` | `id`、`chapterCount`、`chapterIndex`、`chapterProgress`、`coverMark`、`bodyMissing` |
| `markingItemKey(marking)` | `entry/src/main/ets/pages/CatalogPage.ets:136` | `id`、`effect`、`color`、`note`、`enabled` |
| `ruleItemKey(rule)` | `entry/src/main/ets/pages/ReaderHighlightRuleSheet.ets:193` | `id`、`enabled`、`position`、`name`、`pattern`、`underlineMode` |

共享模型上的键函数放在模型文件里（如 `ReplaceRule.ets`），页面私有的放页面内，两者不要互相复制。

**新增列表时**：先问「这条目显示什么」，把其中所有随状态变化的字段全部拼进 key。只有纯静态条目（打开后内容永不改变，如搜索历史）才可以用 `item.id`。

**检查方法**：改完列表页后，在一次运行内切换条目状态（启停、选中、改样式），确认条目文案/颜色即时变化，无需退出重进。

## 二、存储与备份改动必须同时交代三件事

历史缺陷里有四处都出在「只写了主路径」：

| 缺陷 | 漏掉的是什么 |
| --- | --- |
| 备份 `config.xml` 创建顺序错 | 写入顺序（配置尚未成形就被打包） |
| 恢复合并漏 `latestChapterTime`/`durChapterTime`/`order` | 读回字段与写入字段不对齐 |
| 键名写成变量名 `bookshelfLayoutPortrait`（字符串值不同） | 键名字面量未核对 |
| 保存失败仍更新界面缓存 | 失败态回滚 |

因此任何涉及持久化、序列化、ZIP 备份恢复的改动，交付说明里必须写清：

1. **写入顺序**：哪些键必须在哪些键之前落盘，`config.xml` 与各 JSON 的生成先后。
2. **读取路径**：旧版本数据怎么读（保留几个旧版分支）、字段索引是否有位移、缺失字段用什么默认值。
3. **失败态**：写盘失败时界面与内存缓存如何表现，是否回滚，用户看到什么。

**键名核对**：序列化键一律写字面量字符串，不写变量名。改完用 `grep` 回读一次实际写入的字符串，与 Android 侧键名逐字比对。

## 三、上游事实必须先检索再断言

「上游没有实现」「上游不支持某功能」是本项目代价最高的断言，因为它直接决定方案走向。历史上有三处断言错误：

| 错误断言 | 实际 |
| --- | --- |
| 上游没有高亮规则备份 | `app/src/main/java/io/legado/app/help/storage/Backup.kt:212` 已有 `highlightRule.json` 写入，`Restore.kt:269-270` 已有 `replaceAll` |
| 字段名不一致需映射层 | 本地 33 字段与上游 `data/entities/HighlightRule.kt` 36 字段中同名同义 33/33，无需映射 |
| `viewBox="92 92 186 186"` 需修正 | 首行注释写明由 `ic_launcher_foreground.xml` 原样转换，是刻意裁剪 |

**规则**：写「上游没有 X」时必须附检索命令与命中位置；无检索证据的此类结论不得进入任务清单。同理，判断某个转换方法「零调用所以功能没接入」时，要连同调用方一起查（历史上有一次正是因为只查方法定义而误判）。

## 四、模块对照必须一次盘完

按单个上游文件逐轮读改，每轮只发现一两个缺口，反复构建和上设备，是历史上最长的返工循环。书签模块出现 15 个提交、每轮 1~6 项，根因是枚举单位取成了「一个文件」。

**枚举上游接触面**：按内容引用划，不按文件名划。用 `grep -rl "<类别关键词>" app/src/main/java --include=*.kt`，不是 `find -name`。书签模块文件名 `find -iname '*bookmark*'` 命中 20 个、内容引用 `grep -rlE 'Bookmark|BookMarking'` 命中 63 个，差三倍（2026-10-30 在 `<上游根>/app/src/main/java` 实测，关键词见 [对照关键词](parity/KEYWORDS.md)）。

**先出对照表，再写第一行代码**。表中每行是一次用户可感知的操作，状态只允许 `已接`/`未接`/`不适用`/`待定` 四值；`不适用` 须写理由，`待定` 须写阻塞项，盘点结束时不得残留 `待定`。表的位置与字段见 [ZIP 兼容总账](parity/STATUS.md)。

**盘点单位是界面，不是按钮**。盘某个功能时，先定位它所在的界面，然后把这个界面的**完整构成**列进表——包括与当前功能无关的部分。判定「涉及这个界面」只要满足一条：进了这个页、开了这个弹层、这个界面被改动。未迁移的部分显式标 `未接` 并写明差距，归到对应界面的说明里，不要因为「与本次功能无关」就省略。

**每行的 `ZIP 类别` 按「会动到哪个类别」判，不按「数据落在哪」判**。跨类项（一行同时动两三个类别的键或文件）必须标全，否则按类别派活时会被漏掉一半。`—`（参与备份但不受任何忽略开关控制）与 `不备份`（连 `config.xml` 都进不去）是两档不同的取值，都不属于 28 类，按类别名派活覆盖不到，必须单独派。四档取值的完整语义与判定依据见[备份恢复](BACKUP-RESTORE.md)的「三张对照表的「ZIP 类别」列怎么读」。

反例（2026-10-30 实测）：盘「划线/笔记」时，长按选词菜单只记了 2 行（把 8 个内置项压成一行、第三方扩展一行）。而该界面的实际构成是：上游 `ReadBookController.kt:2133-2155` 的 **14 个内置项**（复制/分享/浏览器/朗读/书签/标记/词典/替换/编辑/AI 清洗/AI 改写/搜索内容/插入 BGM 前/后），每项都有图标（`TextActionSelectionMenu.kt:585-600`），两套形态由 `expandTextMenu` 切换（`QuickMenuView` 一排 + 「更多」浮层 / `MultiLineMenuView` 多行平铺），项级 `showState` 三档（一级/折叠/隐藏），外加一个 460 行的菜单管理器页 `TextSelectMenuConfigSheet.kt` 与 `textSelectMenuConfig` 一条持久化链路。按按钮盘只有 2 行，按界面盘是 14 项 + 1 页 + 1 条链路。
_避免_：只盘「与本功能相关的按钮」，把同一界面上其余未迁移部分从表里抹掉——这类漏法在书签、划线、书架三张表上都出现过。

**完成判据是覆盖证明，不是「无待定」**。上游接触面的每一个 `.kt` 文件都必须被显式分配到「已映射到某行」或「已排除 + 理由」二者之一，表格行数由这个分配决定。只满足「表中无空行、无待定」不算盘完——行数由盘点者决定，写多少行就有多少行，该判据证明的是表格自洽，不是上游被覆盖。用 `./scripts/upstream-surface.sh --coverage <类别> <表格路径>` 生成待分配的清单。

**覆盖证明通过 ≠ 上游被覆盖，关键词本身可能选错。** 这个判据的分子分母都由关键词决定，关键词只认「实体类名」时会系统性漏掉一整层。上游的类别有两副面孔——实体类名（`data/entities/Bookmark.kt`）与忽略项键名字符串（`help/storage/BackupConfig.kt` 的 `dbKeyBookmark = "bookmark"`），而导出/恢复主文件 `help/storage/Backup.kt` 里一个实体类名都不出现（`grep -cE "Bookmark|BookMarking"` = 0），19 个类别全写成 `dbIsNotIgnored("bookmark")`。按实体类名选词，`Backup.kt` 就不在接触面里——而它正是该类别导出逻辑的唯一所在地，于是「表格显示通过、导出逻辑从未被检查」长期共存。r294 给 28 类全部补上键名字面量后 `Backup.kt` 才进入接触面；补完后仍有 18 个存储层文件对全部 28 类零命中，它们的共同点是「处理所有类别一起的动作」，只能靠[书籍总账](parity/BOOKSHELF.md)的 E 备份恢复块整块承载。新增或复核类别关键词时，先把「这个类别的逻辑会不会出现在按类别名检索不到的位置」问一遍。

**「已接」的证据必须是「看到什么」，不是「键落库了」。** 字段对上不等于行为对上。`pageAnim` 这条判过 `已接`：存储键同名对位、默认值一致、面板能改、能落库——但上游 `COVER` 是「新页在原位不动、旧页盖上去滑走」（`feature/reader/core/transition/ReaderPageTransition.kt` 的 `transforms(COVER)` 里 `next = ReaderPageTransform()` 位移为 0、`currentOnTop = true`），本地 `ReaderPage.ets:1683-1701` 是「旧页滑出 → 中点切页 → 新页从另一侧滑入」，中间 360ms 屏幕是空的。数据层完全等价，屏幕效果完全不是一回事，表上写的是 `已接`。

因此凡是改变屏幕呈现的行（排版、翻页、渲染、动画、手势判定、绘制），验收列必须写一句**屏幕现象**。写不出这句话就只能判 `未接`，哪怕字段全对、面板全上屏——字段级证据只能支撑「字段已接」，不能支撑「这项已接」。

**「架构差异」不能单独作为排除理由。** 上游 `feature/reader/ReaderCanvasSurface.kt` 是 3747 行的 Compose `Canvas` 自绘管线，本地是 ArkUI 组件树；拿这条理由把它整体排除，等于把渲染主体排除在检查范围之外（[书签对照表](parity/ZIP-BOOKMARK.md) 的「已排除：渲染管线差异」就是这么写的，两行都写了「架构差异不是缺口」）。

排除「实现方式」可以，但必须同时回答一句：**上游这个实现方式带来的效果，由哪一行负责？** 没有任何一行负责就不能排除，必须新开块。判断依据是「用户能不能感知到差别」，不是「代码结构像不像」。

**渲染与公共管线不属于任何类别，必须单独立块。** 有一层代码对所有类别关键词零命中，因为它们处理的是「所有类别一起」的动作：`help/storage/` 的整批规划与规整、`feature/reader/core/` 的分页器 / 文字整形 / 转场策略 / 选区几何。按类别名派活永远覆盖不到，散在「已排除」里就永久隐身。处置方式是整块承载——[书籍总账](parity/BOOKSHELF.md) 的 E 备份恢复块是这个模式，渲染管线同样要单独立块。

**语义等价比行为等价更深一层：同样的输入要给同样的输出。** 上游这批重构把判定逻辑大量抽成了纯函数（`BookRestorePlanner.planBookRestore`、`BackupConfig.keyIsNotIgnore`、`BookExtensions.isLocal`、`ReaderPageTransitionPolicy.release` 的 `commitProgress = 0.35f` / `flingVelocityPxPerSecond = 900f`、`AppUiConfiguration.isDarkTheme`、`RestoreConfigNormalizer.normalizeConfigMap`）。纯函数意味着可以逐条对拍：把上游判定分支全排列成决策表，一行一个用例，本地实现必须逐行通过。

这类差异的共同特征是**正常路径一致、边界路径才分叉**，人工点一遍永远发现不了。仓库里已经有一例：`ReaderPage.ets:1999 getMarkingForTextRange` 只判区间相交、不看 `selectedText`，而上游 `domain/model/BookContentProcessEngine.kt:101-131` 按「选中文本 → 去空白 → 全空白归一化」三级退让重定位——用户不改字号时两者一模一样，一改字号本地高亮就落到错误的文字上。这条已登记在[已知问题](KNOWN-ISSUES.md)，但它是散文，不是可复跑的断言。

**盘点结论必须当轮落盘，没落盘等于没盘**。每轮盘点结束必须把结论写进对照表或已知问题，不能只留在对话里。理由：对话会被压缩，未落盘的结论等于没产生，同一件事会被重新发现第三次。

**验收合并成一次**：全部差异改完，构建一次，上设备走完整清单。不以单个文件的差异作为一轮交付。

违反后会发生什么：差异清单不完整，每一轮都以「又发现一处」结束，构建与设备验证被重复消耗，交付节奏由未被发现的缺口数量决定。

## 五、功能做完必须恢复到上游默认状态

**规则**：一处功能改完、验证完之后，把该功能的设置项恢复成上游默认值再交付，不要留在测试时用的取值上。

**为什么**：验证过程必然会改设置——改字号看排版、改主题看配色、开关一堆选项看差异。这些值留在设备上，下一个人接手时看到的不是「代码的默认行为」，而是「上一个人测试到一半的状态」。更麻烦的是它会被误读成缺陷：r299 取证时把 `readBarStyle` 改成 `2`、把 `readMenuBgColorNight` 改成 `#FF0000`，如果不清回，后续任何人打开阅读页都会看到红色顶栏，而默认值本来是跟随纸色。

**上游默认在哪里**：两份声明就是唯一事实来源，不要凭印象记：

- `domain/model/settings/ReadSettings.kt`（阅读设置，如 `:16` `textFullJustify: Boolean = true`、`:17` `textBottomJustify: Boolean = true`）
- `help/config/ReadBookConfig.kt`（书级配置，如 `:561` `private val pageAnim: Int = 0`）

本地对应 `entry/src/main/ets/data/ReaderSettingsRepository.ets` 的 `defaults` 对象（`:781` `textFullJustify: true`、`:782` `textBottomJustify: true`、`:810` `pageAnimation: 0`、`:811` `animationSpeed: 2`），三者必须逐项相同。**本地 defaults 与上游声明不一致时，以上游为准改本地，不是以本地为准改文档。**

**怎么恢复**：优先走应用内设置面板把值改回去；面板做不到的（如 `titleBarMode` 是字符串键、`readMenuLensRadius` 没有设置项）直接改设备上的偏好文件，再 `aa force-stop` + `aa start` 冷启复核。r299 记录的做法是 `sed` 就地改单个键后 `cp` 覆盖（`preferences/` 下新建文件会 `Permission denied`，覆盖已有文件可以；模拟器上没有 `run-as`）。

**交付前自查**：列出本轮改过的所有设置项，逐项对照上游默认值，确认已复原。这一条要写进验收说明——「已恢复到上游默认」是和「构建通过」「设备验收通过」并列的交付项。

## 六、构建不是可选项

每次源码改动后必须执行一次 `assembleHap`。命令见 [构建说明](BUILDING.md)。历史上有一次交付因 ArkTS 不接受对象展开写法而在目标工程构建失败，N 端未跑构建即交出。构建通过也不等于功能正确，等级口径见 [验证记录](VALIDATION.md) 开头的「验证等级口径」。

## 七、ArkTS 类型约束易错点

- 不支持对象展开（`...obj`）用于类型化对象；需要复制时逐字段赋值或写显式拷贝方法。
- 变量名与字符串值不要指望一致：设置在存储里的键是**字面量**，不是变量标识符；改名时两者会脱钩。
- 索引访问接口字段时注意旧版本位移，解析器要同时兼容历史布局。
