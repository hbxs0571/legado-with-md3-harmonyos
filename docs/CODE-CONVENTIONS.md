# 编码规约

本文件收纳已经踩过的**实现类**缺陷，写成可对照的检查项。它不是风格指南，每条都对应一次真实故障。

**盘点方法不在这里**——怎么划上游接触面、怎么定行粒度、怎么判「已接/未接/不适用」、怎么算盘完，见 [盘点规约](PARITY-RULES.md)。两份文件按读者分工：本文件给改代码的人看，那份给派活和做盘点的人看。

## 一、ForEach 的 key 必须覆盖会变的展示字段

**规则**：`ForEach` 的键函数不得只返回 `item.id`。只要条目外观依赖某个可变更字段，该字段就必须进入 key，否则 ArkUI 会复用旧节点，出现「数据已改、界面还是旧的」。

原因是 ArkUI 按 key 做节点复用：key 不变即视为同一条目，只更新绑定的属性值；而条目内部由 `if`/`Text` 直接读取的字段不会重新求值。

**为什么**：这个模式在本项目犯了四次（书架卡片、替换规则、标注、高亮规则各一次），每次的表现都是「改完状态界面不动，退出重进才对」，排查时容易怀疑数据层。

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

**为什么**：备份是唯一会跨设备、跨版本、跨进程流失数据的路径，出错时用户已经换机了，没有第二次机会。上面四条各自都造成过一次「备份看起来成功、恢复后少东西」。

## 三、构建不是可选项

每次源码改动后必须执行一次 `assembleHap`。命令见 [构建说明](BUILDING.md)。历史上有一次交付因 ArkTS 不接受对象展开写法而在目标工程构建失败，N 端未跑构建即交出。构建通过也不等于功能正确，等级口径见 [验证记录](VALIDATION.md) 开头的「验证等级口径」。

**为什么**：ArkTS 的类型检查与运行期行为跟 TS 有出入（对象展开、隐式返回类型、接口字段索引），靠读代码判断「应该能编过」在本项目失败过多次。

## 四、功能做完必须恢复到上游默认状态

**规则**：一处功能改完、验证完之后，把该功能的设置项恢复成上游默认值再交付，不要留在测试时用的取值上。

**为什么**：验证过程必然会改设置——改字号看排版、改主题看配色、开关一堆选项看差异。这些值留在设备上，下一个人接手时看到的不是「代码的默认行为」，而是「上一个人测试到一半的状态」。更麻烦的是它会被误读成缺陷：r299 取证时把 `readBarStyle` 改成 `2`、把 `readMenuBgColorNight` 改成 `#FF0000`，如果不清回，后续任何人打开阅读页都会看到红色顶栏，而默认值本来是跟随纸色。

**上游默认在哪里**：两份声明就是唯一事实来源，不要凭印象记：

- `domain/model/settings/ReadSettings.kt`（阅读设置，如 `:16` `textFullJustify: Boolean = true`、`:17` `textBottomJustify: Boolean = true`）
- `help/config/ReadBookConfig.kt`（书级配置，如 `:561` `private val pageAnim: Int = 0`）

本地对应 `entry/src/main/ets/data/ReaderSettingsRepository.ets` 的 `defaults` 对象（`:781` `textFullJustify: true`、`:782` `textBottomJustify: true`、`:810` `pageAnimation: 0`、`:811` `animationSpeed: 2`），三者必须逐项相同。**本地 defaults 与上游声明不一致时，以上游为准改本地，不是以本地为准改文档。**

**怎么恢复**：优先走应用内设置面板把值改回去；面板做不到的（如 `titleBarMode` 是字符串键、`readMenuLensRadius` 没有设置项）直接改设备上的偏好文件，再 `aa force-stop` + `aa start` 冷启复核。r299 记录的做法是 `sed` 就地改单个键后 `cp` 覆盖（`preferences/` 下新建文件会 `Permission denied`，覆盖已有文件可以；模拟器上没有 `run-as`）。

**交付前自查**：列出本轮改过的所有设置项，逐项对照上游默认值，确认已复原。这一条要写进验收说明——「已恢复到上游默认」是和「构建通过」「设备验收通过」并列的交付项。

## 五、ArkTS 类型约束易错点

- 不支持对象展开（`...obj`）用于类型化对象；需要复制时逐字段赋值或写显式拷贝方法。
- 变量名与字符串值不要指望一致：设置在存储里的键是**字面量**，不是变量标识符；改名时两者会脱钩。
- 索引访问接口字段时注意旧版本位移，解析器要同时兼容历史布局。
