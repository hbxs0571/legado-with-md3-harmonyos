# 本地 TXT 阅读体验对照表

本表盘的是**一本本地 TXT 从打开到读完的完整链路**，行粒度是**一次用户可感知的操作或一处可见界面元素**（[盘点规约](../PARITY-RULES.md) 第四节「盘点单位是界面，不是按钮」）。
状态三值：`已接` / `未接` / `不适用`，没有第四种取值。

## 这张表和 READER-CONFIG.md 的分工

[READER-CONFIG.md](READER-CONFIG.md)（189 行）盘的是**配置项**——「哪个设置字段接了没有」。
它盘不到的四类东西，正是本表的对象：

| 本表盘什么 | 为什么 READER-CONFIG 盘不到 |
| --- | --- |
| 章节怎么切 | 正则、编码识别、重新分段属于**规则**，不是设置字段 |
| 分页怎么算 | 行高归一、底部对齐、图片重排属于**引擎**，没有对应设置项 |
| 翻页怎么动 | 五种转场的位移/透明度/时长、滚动策略属于**引擎** |
| 目录页怎么加载 | 字数统计、分卷、大文件策略属于**流程** |

**本表不重复 READER-CONFIG 已覆盖的设置字段行。** 快捷面板、字体、排版、边距这些面板，本表只盘**布局与形态**（几页、几个 tab、卡片尺寸、入口位置），不盘字段本身。

另外两份已盘文档也直接引用，不重盘：
- [ZIP-BOOKMARK.md](ZIP-BOOKMARK.md) F 块 34 行 —— 长按选词菜单的**项级**内容与持久化。本表 D 块只盘**形态与弹出位置**。
- [BOOKSHELF.md](BOOKSHELF.md) C 块 35 行 —— 阅读记录页、进度写入、统计。本表 C 块只盘**阅读页内的**页码/进度条/章内位置。

## 已知未完成项（引用，不当新发现）

下列四条已登记在案，本表只登记「上游应有行为」，不作为本轮新发现。**其中三条已在 2026-11-02 的第二批实现落地**，状态见括号：

| 项 | 上游位置 | 说明 |
| --- | --- | --- |
| 抬手惯性（fling）—— **已接** | `feature/reader/ReaderCanvasSurface.kt:1414-1452` 的 `Animatable(0f).animateDecay(velocity, scrollDecay)`（`:1423`） | 见 B5 块；本地 `ReaderPage.ets:2122` `startReaderScrollFling` + `ReaderScrollDecay`，已设备验证 |
| 页眉页脚、章节标题、书签角标仍由 ArkUI 绘制 | `ReaderCanvasSurface.kt:2869` 的 `drawPageDecoration` 也在 `clipRect` 之外 | 属等价，不列差异 |
| 折页手势拖拽跟手需真机验证 | `PageCurlGeometry.kt:130-155` | 见 B4 块备注；拖拽通路已接，卷曲形状是否真跟手指同步仍未真机验证 |
| 滚动模式拖拽方向 —— **已修** | `ReaderCanvasSurface.kt:1414` 分支 | 已由另一会话修（`KI-SCROLL1`），本表按上游应有行为登记 |

`docs/KNOWN-ISSUES.md` 的 KI-EXP1/2/3 已标「已接」，本表沿用，不重开。

## 盘法：分母来自目录

**分母不是关键词。** `scripts/upstream-surface.sh --coverage` 用关键词取分母，关键词选错就系统性漏层——`localBook` 报 28/28 全过，但 `help/storage/BookRestorePlanner.kt` 根本不在那 28 个文件里；`readConfig` 报 76/76 全过，但 `ReadBookScreen.kt`（944 行）、`ReadBookMenuBar.kt`（1044 行）一个都不在接触面。

本表的分母直接来自上游目录 `N:\HarmonyProjects\legado-with-MD3\app\src\main\java\io\legado\app`，用 `find` + `wc -l` 取实际清单：

| 目录 | 文件数 | 行数 |
| --- | --- | --- |
| `feature/reader/`（含 `core/` `legacy/` `platform/`） | 68 | 12918 |
| `ui/book/`（`read/` 顶层 50 + `sheet/` 46 + `config/` 7 + `page/` 3 + `pageestimate/` 8 + `toc/` 10） | 124 | 43914 |
| `model/localBook/` | 9 | 2414 |
| `help/storage/` | 8 | 2127 |
| `help/book/` | 7 | 3037 |
| `model/ReadBook.kt` | 1 | 2141 |
| **合计** | **217** | **66551** |

每个文件在文末「覆盖证明」节都有归属：要么映射到表里某一行，要么进「已排除 + 理由」。未分配数为 **0**。

## 盘面

| 块 | 条数 | 已接 | 未接 | 不适用 |
| --- | --- | --- | --- | --- |
| A 规则层（TXT 特有） | 31 | 17 | 13 | 1 |
| B 引擎层（TXT 与 EPUB 共用） | 54 | 39 | 14 | 1 |
| C 界面层 | 78 | 55 | 18 | 5 |
| D 交互层 | 48 | 30 | 17 | 1 |
| 合计 | 211 | 141 | 62 | 8 |

（统计口径与核对脚本见文末「小结」；数字随表更新，改行后重跑。）

## A 规则层（TXT 特有）

### A1 打开与加载

| 上游能力 | 上游位置(文件:行) | 本地位置(文件:行) | 状态 | 差异说明 | 验收方式 | 备注 | ZIP 类别 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 编码自动识别（读文件头 512000 字节，ICU 统计检测，失败回落 UTF-8） | `model/localBook/TextFile.kt:80-96`、`utils/EncodingDetect.kt:55-58` | `entry/src/main/ets/data/BookRepository.ets:2089-2160`（`decodeTextBytes`） | 未接 | 本地只按 BOM + 试解码判定，不做统计检测。**GBK 与 Big5 混排的老书会被判成另一种**，整本乱码；上游同样会乱但至少按 ICU 概率取最可能的一种，本地是「第一个试通的编码」。 | 导入一本纯 GBK 无 BOM 的 TXT（如繁体站抓的 BIG5 书），看首屏是否乱码 | 依据源码推断，未设备验证。本地候选顺序 UTF-8 → GB18030 → Big5，`util.TextDecoder.create(encoding,{fatal:true})` | `localBook` |
| 编码识别失败不报错，静默按 UTF-8 打开 | `utils/EncodingDetect.kt:56`（`?: "UTF-8"`） | `entry/src/main/ets/data/BookRepository.ets:2089` 起，全候选失败抛 `'TXT 编码无法识别，请使用 UTF-8、GBK/GB18030 或 Big5 格式'` | 不适用 | 本地是显式报错 + 引导去手动指定编码，上游是静默乱码。**本地的行为更好**，差异只在「上游有静默兜底、本地不该有」。 | 导入一个含非法字节序列的文件，看是弹错误还是显示乱码 | 依据源码推断，未设备验证。这是有意的行为差异，不是缺陷 | `localBook` |
| 手动指定编码（9 个候选 + 可手输任意编码） | `ui/book/read/sheet/CharsetConfigSheet.kt:23-78`、`constant/AppConst.kt:92-93` | `entry/src/main/ets/pages/ReaderPage.ets:100`（`READER_CHARSETS` 9 项）、`:1520` `openCharsetDialog`、`:5065-5107` 面板 | 已接 | 本地面板是 9 项单选列表，**不能手输任意编码**；上游输入框可填 ICU 认识的任意名字。对内置 9 项之外的编码（如 GBK 的别名 `CP936`）本地无法指定。 | 更多操作 →「设置编码」，看面板是纯列表还是有输入框 | 依据源码推断，未设备验证 | `localBook` |
| 改编码后清正文缓存、重载目录、重算阅读进度 | `model/ReadBook.kt:1839-1849` | `entry/src/main/ets/data/BookRepository.ets:1263`（`withCharset`：重读正文 + `resolveChapterRule` + `splitChapters` + `buildNoTocChapterLayout` + 重算 volumes） | 已接 | 一致：改编码会把整本书的章节全部重切，进度按新目录重新定位。 | 改编码后返回目录页，看章节数是否变了 | 依据源码推断，未设备验证 | `localBook` |
| 空文件导入时报错 | `model/localBook/TextFile.kt:89`（`EmptyFileException`） | `entry/src/main/ets/data/BookRepository.ets:443`（`throw new Error('TXT 文件内容为空')`） | 已接 | 一致：都是明确报错，不生成空书。 | 导入 0 字节的 .txt，看是否弹「TXT 文件内容为空」 | 依据源码推断，未设备验证 | `localBook` |
| 目录解析流式读取（512000 字节/块），不整本进内存 | `model/localBook/TextFile.kt:63`、`:181-195` | `entry/src/main/ets/data/BookRepository.ets:2033`（`readTextFile` 整文件读入）、`:2064`（`readTextFileAsync` 512KB 分块） | 未接 | 本地切章要**先把整本读成字符串**再切，上游按块扫标题。100MB 级 TXT 本地会先卡住再出目录，上游目录页先出来。 | 导入一本 50MB 以上的 TXT，计时从点开书到目录页出现 | 依据源码推断，未设备验证。`readTextFileAsync` 分块只用于解码，不用于切章 | `localBook` |

### A2 章节切分

| 上游能力 | 上游位置(文件:行) | 本地位置(文件:行) | 状态 | 差异说明 | 验收方式 | 备注 | ZIP 类别 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 目录规则自动选择（倒序遍历规则库，命中数 ≥2 且相邻匹配间隔 >1000 字符才计数） | `model/localBook/TxtTocRuleSelector.kt:13`、`:23-46`、`:55-66` | `entry/src/main/ets/data/TxtTocRuleRepository.ets:607-628`（`selectForSample`）、`:635-657`（`countChapterLikeMatches`） | 已接 | 一致：都是「从后往前试、命中多者胜、命中数相同则低序号胜」，间隔阈值同为 1000，最少匹配同为 2。 | 导入一本章节格式特殊的书，看自动选的规则是否合理（目录页不出现整本一章） | 依据源码推断，未设备验证。本地 `minimumChapterMatches=2`、`minimumMatchGap=1000` | `txtTocRule` |
| 规则库为空时自动灌内置默认规则 | `model/localBook/TextFile.kt:507-517` | `entry/src/main/ets/data/TxtTocRuleRepository.ets`（`getEnabled` 前自愈，键 `legado_txt_toc_rules`） | 已接 | 一致。 | 清空规则库后重新导入一本 TXT，看是否还能正常切章 | 依据源码推断，未设备验证 | `txtTocRule` |
| 规则正则语法错误时跳过该条，不影响其余规则 | `model/localBook/TextFile.kt:478-486` | `entry/src/main/ets/data/TxtTocRuleRepository.ets:614-619`（`catch` 后 `continue`）、`:676-680`（切章时返回空数组） | 已接 | 一致：坏规则被静默跳过。 | 在规则库里写一条非法正则并启用，看目录是否仍能生成 | 依据源码推断，未设备验证 | `txtTocRule` |
| 内置规则库 27 条、默认启用 12 条，首位默认规则的章节正则带前瞻排除（`正文(?!完\|结)`、`节(?!课)`、`集(?![合和])`） | `model/localBook/TextFile.kt` 默认数据、`help/DefaultData.kt` | `entry/src/main/ets/data/TxtTocRuleRepository.ets`（规则表 `chapterRule`/`volumeRule`/`serialNumber`/`enable`） | 未接 | 本地的兜底正则退化成 `'^(第.{1,18}[章节回卷篇]\|序章\|楔子\|番外)'`（`BookRepository.ets:2171`），**没有前瞻排除**：「第1节课」「第3集合」会被误判成章节标题，目录里多出一堆假章。 | 导入一本含「第1节课」「第3集合」字样的 TXT，看目录是否混入这些行 | 依据源码推断，未设备验证。本地规则库存在但兜底正则与上游首位默认规则不同源 | `txtTocRule` |
| 无规则命中时按固定长度分章（默认 3000 字，范围 3000–100000，按编码换算字节，标题 `第N章(1)`） | `model/localBook/TextFile.kt:358-455`、`:464-473` | `entry/src/main/ets/data/BookRepository.ets:1751`（`buildNoTocChapterLayout`） | 已接 | 一致：默认 3000、范围夹到 3000–100000、UTF-8×3 / GB 与 UTF-16×2 / 其它×1、标题 `第N章(1)`、断在 `\n`。本地另有单章 512000 字节硬上限。 | 导入一本没有任何章节标题的长 TXT，看目录是否按约 3000 字一章切出 | 依据源码推断，未设备验证 | `readConfig` |
| 单章超过 102400 字节时二次拆分（`原章名(1)`/`(2)`） | `model/localBook/TextFile.kt:66`（`maxLengthWithToc`） | 无（`grep -rn "102400\|maxLengthWithToc" entry/src/main/ets/` 零命中） | 未接 | 一个几十万字的超长章（常见于「全书一章」的盗版 TXT）本地会当成**一整页排不完的单章**，打开后要等很久，且章内翻页页码极大；上游会拆成若干子章，目录里能看到 `第1章(1)`、`第1章(2)`。 | 导入一本整本只有一章、字数 30 万以上的 TXT，看目录是 1 条还是多条 | 依据源码推断，未设备验证。本地 `BookRepository.ets` 只在导入时传 `maxLengthWithNoToc`，无 `maxLengthWithToc` 概念 | `readConfig` |
| 第一个标题前若有正文，插入一章「前言」，`intro` 取前 500 字 | `model/localBook/TextFile.kt:237-252` | 无（`grep -rn "前言" entry/src/main/ets/` 零命中） | 未接 | 书名页/作者的话/内容简介写在第一个「第1章」之前的 TXT，本地**这段内容直接读不到**——它不在任何章节里。上游会单独成「前言」章，目录第一条就是它。 | 导入一本开头有「内容简介」段落的 TXT，看目录第一条是「第1章」还是「前言」 | 依据源码推断，未设备验证 | `localBook` |
| 章节标题为空时补「无标题章节」 | `model/localBook/LocalBook.kt:159-162` | 无（`grep -rn "无标题章节" entry/src/main/ets/` 零命中） | 未接 | 命中一条只含空白的行（如只有一个全角空格）时，本地会生成**空白章名**，目录里出现一行什么都没有的条目，点进去也认不出是哪一章。 | 构造一个标题行为空白的 TXT，看目录是否出现空行 | 依据源码推断，未设备验证 | `localBook` |
| 章节标题去重（`LinkedHashSet` 后重编 index） | `model/localBook/LocalBook.kt:156-158` | 无（`BookRepository.ets` 的 `splitChapters` 直接按偏移生成 titles，未去重） | 未接 | 同名章节（如多个「番外」）本地目录里会并排出现多个完全一样的条目，用户无法区分；上游会加序号区分。 | 导入一本有两个「番外」的 TXT，看目录是否出现两条一模一样的「番外」 | 依据源码推断，未设备验证 | `localBook` |
| 分卷识别：有 `volumeRule` 按正则判，无 `volumeRule` 时「上一章到下一标题之间全空白」即算卷 | `model/localBook/TextFile.kt:262-267` | `entry/src/main/ets/data/TxtTocRuleRepository.ets:566-600`（`markVolumeTitles`） | 已接 | 本地只实现了「有 volumeRule 按正则判」这条，**没有「空行即卷」的兜底**。没有分卷正则的 TXT，卷头不会被识别，目录里平铺。 | 导入一本「第一卷」后面跟一个空行再接章节的 TXT，看目录是否有卷头与折叠 | 依据源码推断，未设备验证 | `txtTocRule` |
| 目录层级 `tocLevel`（卷 = 0，卷内章 = 1，最多 6 级，每级缩进 16dp） | `model/localBook/TextFile.kt:109-115`、`ui/book/toc/TocScreen.kt:795-843` | `entry/src/main/ets/pages/CatalogPage.ets:449`（`chapter.isInVolume ? 26 : 12`）、`BookRepository.ets:127`/`:144`/`:184` | 未接 | 本地只有**两级视觉缩进**（卷内 26、卷外 12），没有多级层级。嵌套两层的书（卷 → 分卷 → 章）在本地全部压平到同一级。 | 导入一本有「第一卷 / 第一篇 / 第1章」三层结构的 TXT，看目录缩进是否只有一种内缩 | 依据源码推断，未设备验证 | `localBook` |
| 目录规则编辑页（章节规则 / 示例 / 分卷规则三输入框 + 实时测试高亮） | `ui/book/toc/rule/TxtRuleScreen.kt:253-306`、`:306-330` | `entry/src/main/ets/pages/CatalogPage.ets` 更多菜单 →「本地 TXT 目录规则」→ 规则编辑 | 已接 | 本地有规则列表与编辑，但**没有「实时测试高亮」**：改完正则必须保存、退出、重新导入或改编码才看得到效果，试错成本高。 | 打开目录规则编辑，改一条正则，看下方是否立刻显示示例文本的命中高亮 | 依据源码推断，未设备验证 | `txtTocRule` |
| 目录规则预览页（网格/列表两种、卡片显示「N 章」、章节面板最多 500 章、超出提示「仅预览前 500 章」） | `ui/book/toc/rule/preview/TxtTocRulePreviewScreen.kt:232-300`、`:305-375`、`:463-483` | 无（本地 `TxtTocRuleRepository.ets` 只有 `selectForSample` 与 `splitChapterStarts`，无预览页） | 未接 | 用户改目录规则时**看不到这条规则会切出几章、切成什么样**，只能保存后回目录页试。上游有专门的预览页，带「N 章」徽章和章节清单。 | 在目录规则页找「预览」入口 | 依据源码推断，未设备验证 | `txtTocRule` |

### A3 文本处理

| 上游能力 | 上游位置(文件:行) | 本地位置(文件:行) | 状态 | 差异说明 | 验收方式 | 备注 | ZIP 类别 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 重新分段开关（默认关，按书存） | `data/entities/Book.kt:480`（`reSegment = false`）、`help/book/ContentProcessor.kt:157-160` | `entry/src/main/ets/data/BookRepository.ets:1724`（`applyChapterReSegment`）、`ReaderPage.ets:630` `onToggleReSegment` | 已接 | 一致：默认关，开关在「更多操作 → 重新分段」。 | 更多操作 →「重新分段」，看开关默认是否关闭 | 依据源码推断，未设备验证 | `localBook` |
| 重新分段按标点集切（句末 `？。！?!~`、句中 `.，、,—…`、对话动词 `问说喊唱叫骂道着答`，引号内 >5 句 / 引号外 >3 句再切，词长上限 16） | `help/book/ContentHelp.kt:607-623`、`ContentHelp.kt:84+` | `entry/src/main/ets/data/LocalTextReSegmenter.ets`（430 行） | 已接 | 一致：本地分段器实现了同一套标点集与句数阈值。 | 开重新分段后打开一本一段到底的网文，看正文是否被切成多段 | 依据源码推断，未设备验证 | `localBook` |
| 替换净化在「切章之后、渲染之前」应用 | `help/book/ContentProcessor.kt:120-259` | `entry/src/main/ets/data/BookRepository.ets:1733-1742`（`applyChapterContentAsync`：重新分段 → 替换净化 → 简繁转换） | 已接 | 一致：都在正文取用时处理，不改源文件。 | 开一条替换规则后翻页，看规则是否作用到已读过的章 | 依据源码推断，未设备验证 | `replaceRule` |
| 净化管线十步顺序（去重复标题 → 重新分段 → 简繁转换 → 特殊样式占位 → 替换规则 → 还原占位 → 书内净化 → 拼回标题 → 去 `\u00A0` → 逐行 trim） | `help/book/ContentProcessor.kt:120-259` | `entry/src/main/ets/data/BookRepository.ets:1724-1750`、`BookContentProcessEngine.ets`（192 行） | 未接 | 本地顺序是「重新分段 → 替换净化 → 简繁转换」，**没有「去重复标题」「特殊样式占位/还原」「去 `\u00A0`」「逐行 trim」这四步**。后果：正文里重复的章名行会一直显示；带 `&nbsp;` 的网页转 TXT 会留下方块字。 | 打开一本每章开头重复一次章名的 TXT，看正文首行是否重复 | 依据源码推断，未设备验证 | `replaceRule` |
| 替换规则正则超时后自动禁用并落库，当前章显示「规则名 + 堆栈」 | `help/book/ContentProcessor.kt`（`RegexTimeoutException`） | 无（`ReplaceRuleRepository.ets` 无超时捕获与自动禁用） | 未接 | 一条灾难性回溯的正则（如嵌套量词）会让本地**整章卡住不返回**，用户看到的是空白页，且不知道是哪条规则害的；上游会在超时后禁用那条规则并告知。 | 写一条 `(a+)+$` 这类正则并启用，打开一本书看是否卡死 | 依据源码推断，未设备验证 | `replaceRule` |
| 简繁转换（`chineseConverterType` 1=繁转简 / 2=简转繁） | `help/book/ContentProcessor.kt:120-259` | `entry/src/main/ets/data/BookRepository.ets:1747` 起（正文处理链末端） | 已接 | 一致：在净化之后、渲染之前。 | 设置简繁转换后打开繁体书，看正文是否变简体 | 依据源码推断，未设备验证 | `readConfig` |
| 首段不缩进、其余段加 `paragraphIndent` | `help/book/ContentProcessor.kt:120-259` | `entry/src/main/ets/data/LocalTextSemantics.ets:54`（`parse(rawBody, paragraphIndent = '　　')`） | 已接 | 一致：首段不加缩进。 | 看任意一章正文，首段是否顶格 | 依据源码推断，未设备验证 | `readConfig` |
| 适配特殊样式（`[newpage]` 强制分页、`<usehtml>` 富文本块，仅开关打开时识别） | `feature/reader/core/source/ReaderChapterSource.kt:158`、`:162`、`ReaderBodyOnlyFilter.kt:56` | `entry/src/main/ets/data/LocalTextSemantics.ets:94`（`[newpage]`）、`:107`（`<usehtml>`） | 已接 | 一致：两个标记都只在 `adaptSpecialStyle` 开启时生效。 | 关掉「适配特殊样式」后打开含 `[newpage]` 的书，看是否还在该处分页 | 依据源码推断，未设备验证 | `readConfig` |
| 正文折叠（`ReaderBodyOnlyFilter`：只显示正文，标题/作者话折叠成占位） | `feature/reader/core/source/ReaderBodyOnlyFilter.kt:59-89`、`:107-120` | 无（本地无「仅正文」过滤） | 未接 | 上游可以把每章开头的「本章由XX小说网首发」之类折叠掉；本地只能整段显示，用户要靠替换规则自己写。 | 在内容编辑面板找「仅正文」开关 | 依据源码推断，未设备验证。上游开关与 `adaptSpecialStyle` 同源（`:59`、`:66-73`） | `readConfig` |

### A4 字数统计与大文件

| 上游能力 | 上游位置(文件:行) | 本地位置(文件:行) | 状态 | 差异说明 | 验收方式 | 备注 | ZIP 类别 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 目录页字数显示（>10000 显示「N万字」，口径是 `String.length`，标点空格英文都算 1） | `utils/StringUtils.kt:263-274`、`model/localBook/TextFile.kt:244-245` | `entry/src/main/ets/pages/CatalogPage.ets:288-294`（`formatWordCount`）、`:296-310`（`loadChapterWordCounts`，用 `content.length`） | 已接 | 一致：都按 UTF-16 码元计数，>10000 折成「万字」。 | 目录页打开字数显示，看某章是否显示「1.2万字」 | 依据源码推断，未设备验证 | `readConfig` |
| 目录字数默认开启（`tocCountWords = true`） | `TocViewModel.kt`、`ui/book/toc/TocScreen.kt` | `entry/src/main/ets/pages/CatalogPage.ets:322`（`toggleShowWordCount`） | 已接 | 一致。本地首次统计用 `BookRepository.forEachChapter` 逐章读，1378 章要 6 秒以上（`:295` 注释自认）。 | 打开一本 1000 章以上的书进目录页，看字数多久出现 | 依据源码推断，未设备验证 | `readConfig` |
| 正文 8MB 窗口缓存，不整本常驻 | `model/localBook/TextFile.kt:30`、`:118-147` | `entry/src/main/ets/data/BookRepository.ets:2033`/`:2064`（读文件时整本进内存，无窗口缓存） | 未接 | 打开一本 100MB 的 TXT 后，本地内存里会长期压着一整本字符串，切到别的书才释放；上游只保留 8MB 窗口。低内存设备上表现为**看书久了被系统杀后台**。 | 打开一本 100MB 的 TXT 看 10 分钟，再切到书架看应用是否被杀 | 依据源码推断，未设备验证 | `localBook` |

## B 引擎层（TXT 与 EPUB 共用）

> **本节全部行都是 TXT 与 EPUB 共用。** 画布引擎、分页器、转场、选区对两种格式走同一条路，改这里会同时影响 EPUB。

### B1 分页测量

| 上游能力 | 上游位置(文件:行) | 本地位置(文件:行) | 状态 | 差异说明 | 验收方式 | 备注 | ZIP 类别 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 整窗重排：宽高 / 四边 padding / 字号 / 字体 / 字距 / 行距 / 标题分段 / 段间距 / 高亮规则 hash 任一变化即全章重排 | `ui/book/read/ReadBookController.kt:1270-1296`（`paginationEnvironmentKey`） | `entry/src/main/ets/pages/ReaderPage.ets:2691`（`readerPaginationSignature()` 把 `paragraphSpacing`/`lineSpacing`/`letterSpacing`/`paragraphIndent` 等塞进 key）、`:1392` `scheduleReaderPaginationRebuild` | 已接 | 一致：改字号、行距、段距、边距都会重排。本地额外把 `useZhLayout` 也塞进 key（但不生效，见 B1 下一行）。 | 改字号后看当前页文字是否重排 | 依据源码推断，未设备验证 | `readConfig` |
| 段间距 = 正文行高 × `paragraphSpacing` / 10 | `feature/reader/legacy/LegacyReaderChapterPaginator.kt:260-296` | `entry/src/main/ets/pages/ReaderPage.ets:1573`、`:2738`（`baseLineHeight * this.paragraphSpacing / 10`） | 已接 | 一致：同为行高的十分之几。 | 把段距从 0 拖到 20，看段与段之间空隙是否变大 | 依据源码推断，未设备验证 | `readConfig` |
| 两端对齐：非末行按可拉伸间隙摊分（首行缩进不拉伸） | `feature/reader/core/layout/ReaderPaginator.kt:578-581`、`:849-866` | `entry/src/main/ets/pages/LocalReaderPaginator.ets:148`（`stretchableGaps = itemCount - 1 - leadingIndentCount`，`justifyGap` 摊分） | 已接 | 一致：首行缩进不参与拉伸、末行不对齐。 | 看一段多行正文，右边缘是否齐平 | 依据源码推断，未设备验证 | `readConfig` |
| 两端对齐开关（`textFullJustify`，默认开） | `domain/model/settings/ReadSettings.kt`、`ReaderPaginator.kt:578-581` | `entry/src/main/ets/pages/ReaderPage.ets:1629`（传给 `LocalReaderPaginator.paginate` 的 `fullJustify` 形参） | 已接 | 一致：开关真的进了分页器。**注意**：本地早前版本恒传 `true`，本轮核实 `:1629` 已改为传 `this.textFullJustify`。 | 关掉「两端对齐」后看右边缘是否变成不齐 | 依据源码推断，未设备验证 | `readConfig` |
| 底部对齐：把剩余高度逐行摊分，让最后一行贴到页底 | `feature/reader/core/layout/ReaderPaginator.kt:481-499`（`justifyColumnBottom()` 逐列摊分） | `entry/src/main/ets/pages/ReaderPage.ets:1713`（`calculateReaderBottomJustifyGaps` 逐列摊分）、`:4066`（写进 `layout.bottomJustifyGapByColumn`）、`entry/src/main/ets/reader/ReaderCanvasSurface.ets:1278`（按列取 gap） | 已接 | 与上游一致：每列各自摊分剩余高度，双列模式下两列最后一行都贴到页底。原来「双列直接返回 0」的提前退出已去掉，首页标题占位只压第一列。**双列未设备验证**（模拟器竖屏只有单列）。 | 横屏开双页，看每列最后一行是否贴到底 | 依据源码推断，未设备验证。KI-D4 已销项 | `readConfig` |
| 中文标点避头尾（`ChineseLineBreaker`：回退断行、连打例外、可压缩标点、再检查） | `feature/reader/core/layout/ChineseLineBreaker.kt:81-92`、`:109-122`、`:89`、`:61-79`、`:95-108` | `entry/src/main/ets/reader/ChineseLineBreaker.ets:76`（`resolve` 返回要回搬的字数）、`entry/src/main/ets/pages/LocalReaderPaginator.ets:241-276`（溢出分支先试避头尾、再硬断） | 已接 | 行首不再出现「，」「。」「」」「？」，行尾不再孤零零留一个「“」「（」；长句会在标点前回搬一个字，上一行因此变短一点点。**没有做 HANG（收尾标点悬挂）**：本地按 Paragraph 绘制，无法让字形越出版心，所以标点不会「挂」在页边外——这一半行为上游有、本地没有，但用户只在极满的行上才看得出来。 | 找一段连续中文长句，看行首是否有逗号或句号 | 已设备验证（zh-book 第 20 章多页行首无标点）。避头尾按上游口径常开，与 `useZhLayout` 无关（上游 `ReaderPaginator.kt:559` 也是无条件调用） | `readConfig` |
| 双页模式四档（`"1"` 恒双页 / `"2"` 横屏双页 / `"3"` 横屏或平板 / 其余单页） | `feature/reader/core/layout/ReaderColumnMode.kt:7-22` | `entry/src/main/ets/pages/ReaderPage.ets:229`（`@Prop doubleHorizontalPage`）、`:2900-2903`（`resolveReaderColumnCount`） | 已接 | 一致：`'1'` 对滚动模式也生效。 | 横屏时切双页模式，看是否变成左右两列 | 依据源码推断，未设备验证 | `readConfig` |
| 视口 ≤ 0 时不排版，返回 `Unsupported("viewport")` | `feature/reader/legacy/LegacyReaderChapterPaginator.kt:141-143` | `entry/src/main/ets/reader/ReaderCanvasSurface.ets:779-830`（`draw()` 里 `window.current === undefined` 直接 return） | 已接 | 一致：视口无效时画布不画，不回落到整章滚动排版。 | 首次开书那一瞬看是否出现错位文字 | 依据源码推断，未设备验证 | `不备份` |
| 章末留白 `CHAPTER_END_PADDING_DP = 20f` | `feature/reader/legacy/LegacyReaderChapterPaginator.kt:277`、`:406`、`feature/reader/core/layout/ReaderPaginator.kt:1149` | `entry/src/main/ets/pages/ReaderPage.ets:4021`（`request.scrollEndPaddingPx = vp2px(20)`）、`entry/src/main/ets/reader/ReaderCanvasSurface.ets:933-935`（章末页 extent 加留白） | 已接 | 与上游口径一致：**只有连续滚动模式**在章末页的堆叠高度上加 20dp，分页模式不加（上游 `stackedExtentPx` 同样只在 `continuousScroll` 时加）。滚动到章末继续往下，最后一页下方会多出一小段呼吸空间再进下一章。 | 滚动模式滚到一章末尾，看最后一行与下一章之间是否有一小段空白 | 依据源码推断，未设备验证 | `不备份` |
| 页眉页脚高度计入正文 padding | `feature/reader/legacy/LegacyReaderChapterPaginator.kt:260-296` | `entry/src/main/ets/pages/ReaderPage.ets:1708`（`usedHeight += titleReservedLines * lineHeight`，页眉页脚另走 `getReaderInfoReserve`） | 已接 | 一致：正文高度会扣掉页眉页脚占位。 | 开关页眉后看正文可用行数是否减少 | 依据源码推断，未设备验证 | `readConfig` |

### B2 图片与图文混排

| 上游能力 | 上游位置(文件:行) | 本地位置(文件:行) | 状态 | 差异说明 | 验收方式 | 备注 | ZIP 类别 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 小图阈值：任一边 ≥80px 当独立图，否则按行内图排 | `feature/reader/core/layout/ReaderChapterBlockMeasurer.kt:467-472` | `entry/src/main/ets/pages/ReaderPage.ets:1625`（`context.px2vp(80)` 作为 `standaloneImageThreshold`） | 已接 | 一致：80px 阈值。 | 看含小图标（如表情）的段落，图标是否混排在文字行里 | 依据源码推断，未设备验证 | `readConfig` |
| 图片尺寸未解出时按「一行高的正方形」占位继续排版 | `feature/reader/core/layout/ReaderChapterBlockMeasurer.kt:455-460` | `entry/src/main/ets/pages/ReaderPage.ets:1586-1608`（`placeholderExtent = max(1, lineHeight)`）、`paginationUsesImagePlaceholder` 标记 | 已接 | 一致：先用正方形占位，尺寸到达后再重排。 | 首次打开带大图的章，看是否先出现方形灰块再变成长图 | 依据源码推断，未设备验证 | `不备份` |
| 图片尺寸解出后**只重绘不重排**（排版期已按 `getImageSize` 预留真实尺寸） | `ui/book/read/ReadBookController.kt:239-248`（只 `page.copy(revision = ...)`） | `entry/src/main/ets/pages/ReaderPage.ets:3922`（`primeContentImageSizesSync` 首排前用 `getImageInfoSync` 同步量出真实尺寸）、`:1416`（同步失败时回落重排） | 已接 | 首次排版前就把本章图片的真实尺寸量出来，图文混排的章**不再在图片加载完之后跳版**（文字重新断行、页码变化）。只有同步量尺寸失败（格式不支持、超大图）时才回落到「先占位再重排」。 | 打开一本带大图的章，盯住正文看它是否在图片加载完成后重新断行 | 依据源码推断，未设备验证（模拟器书库无图文本） | `不备份` |
| 坏图按一行高的正方形占位，不撑破版面 | `feature/reader/core/layout/ReaderChapterBlockMeasurer.kt:455-460` | `entry/src/main/ets/pages/ReaderPage.ets:1586-1608` | 已接 | 一致。 | 放一张损坏的图片引用进 TXT，看版面是否正常 | 依据源码推断，未设备验证 | `不备份` |
| 图片大小 0.1~5 倍缩放，九宫格按九切片等比缩放 | `feature/reader/core/model/ReaderPage.kt:140`、`:154-157`、`ReaderNineSliceLayout.kt:18-109` | `entry/src/main/ets/pages/ReaderPage.ets`（`activeImageStyle` 只有 `TEXT`/`FULL`/`SINGLE` 三档） | 未接 | 本地**没有图片缩放倍数与九宫格切片**。高亮规则里配的背景图会被整体拉伸，圆角气泡图会被压扁；上游按九切片保护四角不变形。 | 给一条高亮规则配圆角背景图，看圆角是否变形 | 依据源码推断，未设备验证 | `themeConfig` |
| 图片布局模式解析（TEXT / FULL / SINGLE 三档映射） | `feature/reader/core/layout/ReaderChapterBlockMeasurer.kt:694-724`、`feature/reader/legacy/LegacyReaderChapterPaginator.kt:148-159` | `entry/src/main/ets/pages/ReaderPage.ets:1628`（`activeImageStyle === 'SINGLE' ? 0 : titleReservedLines`） | 已接 | 一致：SINGLE 独占一页。 | 切图片样式三档，看大图是否独占页 | 依据源码推断，未设备验证 | `readConfig` |

### B3 预取与缓存

| 上游能力 | 上游位置(文件:行) | 本地位置(文件:行) | 状态 | 差异说明 | 验收方式 | 备注 | ZIP 类别 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 四页预取窗口（previous / current / next / nextPlus） | `feature/reader/core/navigation/ReaderPageNavigator.kt:62-71` | `entry/src/main/ets/reader/ReaderCanvasSurface.ets:380-427`（`ReaderCanvasWindow`）、`ReaderPage.ets:4261-4269`（`prefetchReaderCanvasWindow`） | 已接 | 一致：窗口就是四页，`prefetch()` 把四页图片全解进缓存（`ReaderCanvasSurface.ets:711-726`）。 | 快速连翻三页，看是否出现「有字无图」的帧 | 依据源码推断，未设备验证 | `不备份` |
| 图片缓存：两种尺寸各缓存一份 | `feature/reader/core/model/ReaderImageCachePolicy.kt:4-9` | `entry/src/main/ets/reader/ReaderCanvasSurface.ets:698`（`imageCache` 上限 **32**，FIFO 逐出 `:748-757`） | 未接 | 本地只按一个尺寸缓存 32 张、超了先进先出；上游按两种尺寸各留一份。图文混排的书（每章十几张图）本地翻几页就会反复重解码，表现为**图片慢慢浮现**。 | 在一本每章 20 张图的 TXT 里连翻 10 页，看图片是否延迟出现 | 依据源码推断，未设备验证 | `不备份` |
| 段落缓存 1024 条上限 | — （上游无此机制，靠 Compose 重组） | `entry/src/main/ets/reader/ReaderCanvasSurface.ets:703`（`PARAGRAPH_CACHE_LIMIT = 1024`）、`:1886-1889`（超限整表 clear） | 不适用 | 上游没有段落缓存这个概念（Compose 按帧重组）。本地超限时**整表清空**，下一次绘制会全部重建，表现为偶发的一次卡顿。 | 连续翻 100 页以上，留意是否偶发卡顿 | 依据源码推断，未设备验证。这是本地新增机制，上游无可对照行为 | `不备份` |
| 滚动模式整页 PixelMap 缓存（容量 8 的 LRU，key 用元素引用身份） | `feature/reader/ScrollPageDrawCache.kt:44-54`、`:65-66` | 无（本地无整页位图缓存） | 未接 | 滚动模式下本地每帧重绘整页文字，上游缓存 8 页位图。长章滚动时本地 CPU 占用更高，低端机上**滚动会掉帧**。 | 滚动模式连续快速滑动一整章，看是否掉帧 | 依据源码推断，未设备验证 | `不备份` |

### B4 绘制与转场

| 上游能力 | 上游位置(文件:行) | 本地位置(文件:行) | 状态 | 差异说明 | 验收方式 | 备注 | ZIP 类别 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 每页先铺纸面底色，再画内容 | `feature/reader/ReaderCanvasSurface.kt:2767-2769` | `entry/src/main/ets/reader/ReaderCanvasSurface.ets:779-830`（`drawRect` 铺 `pageBackgroundArgb`）、`drawSlot` `:949-978`（`pageSurfaceOpaque` 时先铺纸面） | 已接 | 一致：纸面在内容之下。 | 半透明背景主题下看是否有透底 | 依据源码推断，未设备验证 | `themeConfig` |
| 绘制顺序：背景图 → 裁剪 → 文字背景色带 → 文字背景图 → 选区预览 → 半高高亮 → 正文 → 选区高亮 → contentRules → styledUnderlines → overlayRules → 页眉页脚（裁剪外） | `feature/reader/ReaderCanvasSurface.kt:2767-2869` | `entry/src/main/ets/reader/ReaderCanvasSurface.ets:1183-1222`（`drawPage`：记栈深 → `layoutPage` → 逐 box → 下划线 → `restoreToCount` → `drawSelection`） | 未接 | 本地**没有分层绘制**：文字背景、下划线、高亮都跟着每个 box 一起画，不是独立四层。后果是**下划线会压在选区高亮之下**（选区遮住下划线）、**overlay 规则无法盖在文字之上**。 | 选中一段带下划线的高亮文字，看下划线是否被选区灰块盖住 | 依据源码推断，未设备验证 | `themeConfig` |
| 文字背景下划线合并成连续段（相邻同色背景合并成色带） | `feature/reader/core/style/ReaderBackgroundBounds.kt:31-83`、`ReaderUnderlineRun.kt:11-38` | 无（本地逐 box 独立画 `backgroundRect`） | 未接 | 本地每个文字片段各画各的底色块，**相邻同色块的接缝处会露出细线**（尤其在半透明背景色下）；上游把相邻同色合并成一条连续色带。 | 给一段连续文字加半透明背景色，放大看块与块之间是否有缝 | 依据源码推断，未设备验证 | `themeConfig` |
| 下划线 6 种线型（实线 / 虚线 10-10 / 双线间距 3dp / 波浪振幅 3dp 波长 12dp / SVG 100×50 基准 / 半高线） | `feature/reader/platform/ReaderPageDecorationDrawCache.kt:58-152`、`ui/book/read/config/` 7 文件 | `entry/src/main/ets/reader/ReaderCanvasSurface.ets:1778-1800`（`decorationType` 只映射 `LINE_THROUGH` 与 `UNDERLINE`，线型靠 `decorationLineStyle`） | 未接 | 本地只有系统 `TextDecorationType` 提供的线型，**没有手绘虚线/波浪/双线/SVG/半高线**。高亮规则里选「波浪下划线」，本地画出来是系统默认的一条直线。 | 给一条规则配波浪下划线，看是否为波浪 | 依据源码推断，未设备验证 | `themeConfig` |
| 五种转场：覆盖（COVER）/ 滑动（SLIDE）/ 仿真（SIMULATION）/ 滚动（SCROLL）/ 淡入（FADE），其余无动画 | `feature/reader/core/transition/ReaderPageTransition.kt:15-22` | `entry/src/main/ets/reader/ReaderCanvasSurface.ets:28`（`ReaderTransitionMode`）、`:44`（`readerTransitionModeFromPageAnim`）、`:132-230`（`ReaderPageTransitionPolicy`） | 已接 | 一致：五种转场 + NONE。 | 逐个切翻页动画，看五种效果是否都在 | 依据源码推断，未设备验证 | `readConfig` |
| 覆盖转场尾部阴影（宽 36dp、色 `0x30111111`） | `feature/reader/core/transition/ReaderPageTransition.kt:28-38`、`ReaderCanvasSurface.kt:1664-1682` | `entry/src/main/ets/reader/ReaderCanvasSurface.ets:132-230`（`transforms` 只给 translationX / alpha） | 未接 | 本地覆盖翻页时**两页交界处没有阴影**，翻起来像两块纸板平移；上游有一条 36dp 的半透明渐变，有「纸叠起来」的立体感。 | 用覆盖动画翻页，看交界处是否有阴影 | 依据源码推断，未设备验证 | `readConfig` |
| 淡入转场提交阈值 0.1（其余 0.35），收尾时长始终满额 | `feature/reader/core/transition/ReaderPageTransition.kt:115-121`、`:156-181` | `entry/src/main/ets/reader/ReaderCanvasSurface.ets:132-160`（`COMMIT_PROGRESS = 0.35` 单一阈值） | 未接 | 本地淡入转场也按 0.35 判，**淡入翻页要比上游多拖一倍距离才翻得过去**，手指松开时回弹更频繁。 | 用淡入动画，只拖 1/5 屏宽后松手，看是否翻页 | 依据源码推断，未设备验证 | `readConfig` |
| 松手判定：拖动进度 ≥35% 翻页；甩动速度 ≥900 px/s 也翻页；最后一段反向拖动回弹 | `feature/reader/core/transition/ReaderPageTransition.kt:156-181`、`:166-169`、`:170-175` | `entry/src/main/ets/reader/ReaderCanvasSurface.ets:132-230`（`COMMIT_PROGRESS = 0.35`、`FLING_VELOCITY_PX_PER_SECOND = 900`、`release`） | 已接 | 一致：35% 与 900 px/s 两个数值相同。 | 轻轻快甩一下，看是否翻页 | 依据源码推断，未设备验证 | `readConfig` |
| 无邻页时拖动回弹（不翻过去） | `feature/reader/core/transition/ReaderPageTransition.kt:135-154` | `entry/src/main/ets/reader/ReaderCanvasSurface.ets:132-230`（`transforms` 按 `drawsNext`/`drawsPrevious` 决定） | 已接 | 一致：没有下一页时拖不动。 | 在最后一页往左拖，看是否回弹 | 依据源码推断，未设备验证 | `readConfig` |
| 折页转场三道阴影（`0x99111111` / `0x4D111111` / `0x73333333`） | `feature/reader/core/transition/PageCurlGeometry.kt:46-50` | `entry/src/main/ets/reader/ReaderPageCurl.ets:67-71`（`ReaderCurlVisualPolicy` 三个常量） | 已接 | 一致：三个 ARGB 完全相同。 | 用仿真翻页，看卷起处是否有三层阴影 | 依据源码推断，未设备验证 | `readConfig` |
| 折页收尾时长下限为基准的 25%（=90ms） | `feature/reader/core/transition/PageCurlGeometry.kt:66-79` | `entry/src/main/ets/reader/ReaderPageCurl.ets:81`（`MIN_SETTLE_FRACTION = 0.25`）、`:85` `settleDurationMillis` | 已接 | 一致。 | 快速点按翻页，看收尾是否干脆 | 依据源码推断，未设备验证 | `readConfig` |
| 折页起始吸附：拖动不足页宽 4% 时吸附回原位 | `feature/reader/core/transition/PageCurlGeometry.kt:86-98` | `entry/src/main/ets/reader/ReaderPageCurl.ets:82`（`DRAG_SNAP_FRACTION = 0.04`）、`:107-118` `dragX` | 已接 | 一致。 | 极轻地拖一下再松手，看是否纹丝不动 | 依据源码推断，未设备验证 | `readConfig` |
| 折页角点选择（按触点落在上半/下半页决定从哪个角卷起） | `feature/reader/core/transition/PageCurlGeometry.kt:130-155` | `entry/src/main/ets/reader/ReaderPageCurl.ets:143-155`（`cornerY`/`settledY`）、`entry/src/main/ets/pages/ReaderPage.ets:2001`（拖动时每帧按触点重算 `curlCornerY`/`curlTouchX`/`curlTouchY`） | 未接 | 代码通路已接：拖动时每帧按触点上下半页重算卷起角与触点位置。但**纸张卷曲形状是否真的跟着手指同步**还没在真机上确认——模拟器 `snapshot_display` 抓不到拖动中间帧（连拍 8 张字节数全等），只能证明回调每帧都进，证明不了画面。按「已接必须指到屏幕位置」的口径，仍判未接。 | 真机上用仿真动画慢慢拖，看纸张卷起角是否跟着触点在上半页/下半页之间切换 | 依据源码推断，未设备验证。任务书已知项「折页手势拖拽跟手需真机验证」 | `readConfig` |
| 翻页速度四档 240 / 300 / 360 / 540ms，基准统一 360 | `feature/reader/core/transition/ReaderPageTurnSpeed.kt:19-32`、`:41-43`、`:46` | `entry/src/main/ets/pages/ReaderPage.ets:1966-1967`（`durationBySpeed = [240,300,360,540]`）、`:364`（`animationSpeed` 默认 2） | 已接 | 一致：四档数值相同、默认第 3 档（360ms）。 | 速度切到最快档与最慢档，感受差别 | 依据源码推断，未设备验证 | `readConfig` |
| 自动翻页顶部 1px 进度指示条；墨水屏整页跳变、普通屏逐行揭示 | `feature/reader/core/transition/ReaderAutoPagePolicy.kt:10-11`、`:16-18`、`ReaderCanvasSurface.kt:1683-1722` | `entry/src/main/ets/pages/ReaderPage.ets:1256-1272`（`setInterval` 到点直接 `turnReaderPage(1)`） | 未接 | 本地自动翻页是**到点直接翻整页**，没有顶部 1px 进度条提示「还剩多久翻」，也没有逐行揭示。用户在等待时会不确定是不是卡住了。 | 开自动翻页，看顶部是否有细进度条 | 依据源码推断，未设备验证 | `readConfig` |

### B5 滚动

| 上游能力 | 上游位置(文件:行) | 本地位置(文件:行) | 状态 | 差异说明 | 验收方式 | 备注 | ZIP 类别 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 滚动步距「保留一行」（下一页取最远可见行顶边、上一页取最近可见行底边，钳进 [0, 视口]） | `feature/reader/core/transition/ReaderScrollState.kt:31-72` | `entry/src/main/ets/reader/ReaderCanvasSurface.ets:276-340`（`ReaderScrollPolicy.pageStep` `:283`） | 已接 | 一致：逐分支照抄，含「可见区没有正文时退化成整屏」。 | 滚动模式下点「下一页」，看新页顶部是否还留着一行旧内容 | 依据源码推断，未设备验证 | `readConfig` |
| 步进时长 = 基准 × 步距 ÷ 视口高 | `feature/reader/core/transition/ReaderScrollState.kt:83-91` | `entry/src/main/ets/reader/ReaderCanvasSurface.ets:314`（`stepDurationMillis`） | 已接 | 一致：线性折算，最短 1ms。 | 短距离步进与整屏步进，感受时长差异 | 依据源码推断，未设备验证 | `readConfig` |
| 跨页：越过页边界时换窗口 | `feature/reader/core/transition/ReaderScrollState.kt:41-58`、`:104-122` | `entry/src/main/ets/reader/ReaderCanvasSurface.ets:325`（`apply`，含 `crossing` 返回） | 已接 | 一致：`apply` 返回 `PREVIOUS`/`NEXT` 让调用方换窗口。 | 滚动到底继续滑，看是否无缝进入下一章 | 依据源码推断，未设备验证 | `readConfig` |
| 章末不够一屏时钳回 | `feature/reader/core/transition/ReaderScrollState.kt:109-114` | `entry/src/main/ets/reader/ReaderCanvasSurface.ets:325-340`（`apply` 的 `hitBoundary` 分支） | 已接 | 一致。 | 滚动到一章末尾，看是否停在最后一行而不是留白 | 依据源码推断，未设备验证 | `readConfig` |
| **抬手惯性（fling）**：`animateDecay(velocity, scrollDecay)`，spline decay，碰到边界抛 `ReaderScrollBoundaryReached` 静默取消 | `feature/reader/ReaderCanvasSurface.kt:1414-1452`（调用点 `:1423`）、`:261`（`rememberSplineBasedDecay`）、`:1879` | `entry/src/main/ets/pages/ReaderPage.ets:2122`（`startReaderScrollFling`）、`entry/src/main/ets/reader/ReaderCanvasSurface.ets`（`ReaderScrollDecay`：`DECAY_RATE_PER_SECOND = 3.3`、`DURATION_MILLIS = 1200`） | 已接 | 抬手后正文按指数衰减继续滑行、速度逐渐降下来，撞到章边界立即停住不再滑。设备实测：快速上滑一次松手，页码从 `14/17` 自动滑到 `12/17`。 | 滚动模式下快速甩一下手指后松手，看是否继续滑行 | 已设备验证 | `readConfig` |
| 滚动动画开关（关掉后滚动无缓动） | `feature/reader/core/gesture/ReaderGestureSettingsPolicy.kt:27` | `entry/src/main/ets/pages/ReaderPage.ets:1860`（滚动步进用 `durationBySpeed` 表） | 已接 | 一致：本地滚动步进走同一套四档时长。 | 关掉滚动动画后点翻页，看是否瞬移 | 依据源码推断，未设备验证 | `readConfig` |

### B6 页眉页脚与角标（绘制）

| 上游能力 | 上游位置(文件:行) | 本地位置(文件:行) | 状态 | 差异说明 | 验收方式 | 备注 | ZIP 类别 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 页眉页脚 14 种取值（章节名 / 时间 / 电量 / 页码 / 百分比 / 书名 / 组合 / 全书页码等），12 个占位符 | `feature/reader/core/model/ReaderTipValue.kt:39-60`、`:71-87` | `entry/src/main/ets/pages/ReaderPage.ets:4335`（`getReaderInfoValue`）、`:4380`（`getReaderInfoType`，type 1..20） | 已接 | 一致：本地有 20 个 type，覆盖上游 14 种取值与全部占位符，另加 `{PageRemaining}`。 | 页眉三槽分别配不同类型，看是否都显示 | 依据源码推断，未设备验证。本地 type 编号 1..20 与上游编号不同源 | `readConfig` |
| 页数未知时显示「-」 | `feature/reader/core/model/ReaderTipValue.kt:30-31` | `entry/src/main/ets/pages/ReaderPage.ets:2887-2891`（`getWholeBookPageText` 返回 `全文 - / -`） | 已接 | 一致。 | 未分页的书看页脚页码位是否显示 `-` | 依据源码推断，未设备验证 | `readConfig` |
| 页脚进度强制：没真读完时 `100.0%` 显示为 `99.9%` | `feature/reader/legacy/LegacyReaderPageDecorationFactory.kt:314-331` | `entry/src/main/ets/pages/ReaderPage.ets:2628-2642`（`getWholeBookProgress`：`progress >= 100` 时强制 `99.9`） | 已接 | 一致。 | 翻到全书最后一页，看页脚进度是否显示 99.9% | 依据源码推断，未设备验证 | `readConfig` |
| 页眉页脚行高 = 上内边距 + 字体高 + 下内边距 + 分隔线 0.5dp | `feature/reader/core/model/ReaderTipRowLayout.kt:4-20`、`LegacyReaderPageDecorationFactory.kt:50-99` | `entry/src/main/ets/pages/ReaderPage.ets:4403`（`ReaderInfoRow`：三列 `layoutWeight(1)`、行高 18、maxLines 1） | 已接 | 一致：行高固定 18。 | 开关页眉后看正文顶部留白是否变化 | 依据源码推断，未设备验证 | `readConfig` |
| 页眉页脚颜色 0 = 跟随正文色 | `feature/reader/core/model/ReaderTipColor.kt:4-5` | `entry/src/main/ets/pages/ReaderPage.ets:4335` 起（`getReaderInfoValue` 取色） | 已接 | 一致。 | 页眉色设为默认，换主题后看页眉是否跟着变 | 依据源码推断，未设备验证 | `readConfig` |
| 书签角标：宽 = 尺寸×密度、高 = 宽×2、距右内边距 6dp、从正文顶边起不压页眉 | `feature/reader/core/model/ReaderBookmarkBadge.kt:16-39`、`feature/reader/platform/ReaderBookmarkBadgeRenderer.kt:76-96` | `entry/src/main/ets/pages/ReaderPage.ets:1783-1798`（`BookmarkBadgeRibbon`）、`:4509-4520`（挂载与 margin） | 已接 | 一致：`margin { top: paddingTop + (页眉可见 ? reserve : 0), right: paddingRight + 6 }`，高 `size*2`。 | 给当前页加书签，看右上角是否出现书签带 | 依据源码推断，未设备验证 | `—` |
| 书签角标尺寸 0 时隐藏但书签保留 | `feature/reader/core/model/ReaderBookmarkBadge.kt:28` | `entry/src/main/ets/pages/ReaderPage.ets`（`shouldShowBookmarkBadge()` 判尺寸） | 已接 | 一致。 | 角标尺寸设 0，看是否还有书签带但书签列表里还在 | 依据源码推断，未设备验证 | `—` |
| 滚动翻页模式下不画书签角标 | `ui/book/read/BookmarkBadgeDelegate.kt:35-70` | `entry/src/main/ets/pages/ReaderPage.ets:4508`（`if (this.shouldShowBookmarkBadge())`，条件未排除滚动模式） | 未接 | 滚动模式下本地**仍然画书签角标**，它悬在正文右上角不动，与滚动的文字脱节，看着像个贴纸。 | 滚动模式下给当前页加书签，看右上角是否出现静止的角标 | 依据源码推断，未设备验证 | `—` |
| 没有自定义角标图时画 12×24 琥珀黄丝带 Path | `feature/reader/platform/ReaderBookmarkBadgeRenderer.kt:76-96` | `entry/src/main/ets/pages/ReaderPage.ets:1783-1798`（否则回落 `$r('app.media.app_bookmark_badge')`） | 已接 | 一致：都有一张默认图/丝带。本地是预置位图资源而非 Path 绘制，视觉等价。 | 角标图片清空后看是否显示默认书签带 | 依据源码推断，未设备验证 | `—` |

### B7 文字背景与高亮样式

| 上游能力 | 上游位置(文件:行) | 本地位置(文件:行) | 状态 | 差异说明 | 验收方式 | 备注 | ZIP 类别 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 文字背景图（气泡图）异步加载，排版期预热避免首帧空气泡 | `feature/reader/platform/ReaderTextBackgroundLoader.kt`（156 行）、`feature/reader/legacy/LegacyReaderStyleRangeMapper.kt:420-427` | 无（`grep -rn "TextBackgroundLoader\|textBackgroundImage" entry/src/main/ets/` 零命中） | 未接 | 本地**不支持文字背景图**，只有纯色 `backgroundRect`（`ReaderCanvasSurface.ets:1764-1772`）。给规则配气泡背景图后本地不显示任何东西，用户以为规则没生效。 | 给一条高亮规则配背景图，看正文是否出现气泡 | 依据源码推断，未设备验证 | `themeConfig` |
| 文字背景透明度 0~100 | `feature/reader/core/model/ReaderBackgroundAlpha.kt:4` | `entry/src/main/ets/reader/ReaderCanvasSurface.ets:1764-1772`（`backgroundArgb` 直接取色，无独立透明度通道） | 未接 | 本地只能靠改颜色的 alpha 值调，没有独立的透明度滑杆；上游 0~100 与颜色解耦。 | 高亮规则面板找透明度滑杆 | 依据源码推断，未设备验证 | `themeConfig` |
| 高亮命中同位置多条规则时高优先级赢、同优先级后者赢 | `feature/reader/core/style/ReaderCharacterStyle.kt:44-79`、`:92-112`（二分查找） | `entry/src/main/ets/data/ReaderHighlightRuleEngine.ets`（按规则列表顺序叠加，上限 64 条 / 15 万字符） | 未接 | 本地是**按顺序叠加**而非优先级仲裁：两条规则命中同一段字时，后一条的颜色会覆盖前一条，但**下划线与背景色会叠加显示**，出现「红字 + 蓝波浪线 + 黄底」的混乱组合；上游只保留一条。 | 建两条都命中「第一章」的规则（一条改色、一条加下划线），看是否两种效果同时出现 | 依据源码推断，未设备验证 | `themeConfig` |
| 换主题时正文内已上色的高亮即时换色（`ReaderPageColorTransform`） | `feature/reader/core/model/ReaderPageColorTransform.kt:15-71` | `entry/src/main/ets/pages/ReaderPage.ets:3106`（标题 key 含 `titleColor`/`titleColorNight`，会触发重建） | 已接 | 一致：换主题后高亮颜色跟着变。 | 日间/夜间来回切，看高亮颜色是否跟着变 | 依据源码推断，未设备验证 | `themeConfig` |

## C 界面层

### C1 阅读页本体

| 上游能力 | 上游位置(文件:行) | 本地位置(文件:行) | 状态 | 差异说明 | 验收方式 | 备注 | ZIP 类别 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 正文区三块结构：正文 / 页眉 / 页脚 | `ui/book/read/ReadBookScreen.kt`、`feature/reader/ReaderCanvasSurface.kt:3517-3563` | `entry/src/main/ets/pages/ReaderPage.ets:4500-4530`（Stack：正文 + 角标 + 选区菜单） | 已接 | 一致。 | 打开任意书看页面构成 | 依据源码推断，未设备验证 | `readConfig` |
| 章节标题渲染（按 `titleSegType` 分段、副标题按 `titleSegScaling` 缩放、位置三档） | `feature/reader/core/source/ReaderTitleSegmentation.kt:14-37`、`ui/book/read/page/provider/TitleStyleParser.kt`（52 行） | `entry/src/main/ets/pages/ReaderPage.ets:3086-3116`（`ReaderTitleSegments`）、`:3069-3076`（`resolveTitleSegments`） | 已接 | 一致：分段方式、副标题缩放、位置三档都在。 | 把标题分段方式切成「按分隔符」，看标题是否分行显示 | 依据源码推断，未设备验证 | `readConfig` |
| 标题 `titleMode = 2` 时整块隐藏且不占行高 | `feature/reader/core/source/ReaderChapterSource.kt:105-112` | `entry/src/main/ets/pages/ReaderPage.ets:3080-3082`（`isReaderTitleVisible`）、`:3120-3125`（不占行高） | 已接 | 一致。 | 标题模式切「不显示」，看正文是否顶到页首 | 依据源码推断，未设备验证 | `readConfig` |
| 标题独占一页（`titleMode` 特殊档位下垂直居中） | `ui/book/read/page/entities/PageDirection.kt`、`LegacyReaderChapterPaginator.kt` | `entry/src/main/ets/pages/ReaderPage.ets:4461`（「独立的标题页：上游这里垂直居中」） | 已接 | 一致。 | 切到标题独占页模式，看标题是否居中一页 | 依据源码推断，未设备验证 | `readConfig` |
| 隐藏状态栏后正文默认仍按状态栏高留白，开关打开才顶到边 | `ui/book/read/ReaderContentAvoidancePolicy.kt:38-49` | `entry/src/main/ets/pages/ReaderPage.ets`（`paddingSettings.paddingTop` + 系统栏避让） | 已接 | 一致：默认留白，开关打开才贴边。 | 隐藏状态栏后看正文顶部是否还在原位置 | 依据源码推断，未设备验证 | `readConfig` |
| 菜单开合与系统栏显隐动画**不触发重排** | `ui/book/read/ReaderContentAvoidancePolicy.kt:38-49` | `entry/src/main/ets/pages/ReaderPage.ets:2691`（`readerPaginationSignature` 不含菜单状态） | 已接 | 一致：开合菜单不会让正文重新断行。 | 反复开关菜单，看正文行是否保持不动 | 依据源码推断，未设备验证 | `readConfig` |
| 首帧保护：入场动画没结束前新排好的页窗口只暂存不发布 | `ui/book/read/ReaderRenderUiState.kt:1-54` | `entry/src/main/ets/pages/ReaderPage.ets`（`restoredProgressPosition` 与 `rebuildReaderPages(true)` 配合） | 已接 | 一致：本地也是先排好再发布，避免闪旧页。 | 冷启动打开一本大书，看是否闪一下第 1 页再跳到进度页 | 依据源码推断，未设备验证。KI-EXP2 已登记 | `readConfig` |
| 等待视口最多 2 秒（`VIEWPORT_WAIT_TIMEOUT_MILLIS`） | `ui/book/read/ReaderViewport.kt:1-117` | 无（本地无等待超时） | 不适用 | ArkUI 的 `onAreaChange` 同步给出宽高，不存在「等视口」这个异步窗口。 | — | 依据源码推断，未设备验证。平台差异：Compose 的 measure 与 ArkUI 的 onAreaChange 时序不同 | `不备份` |

### C2 顶栏

| 上游能力 | 上游位置(文件:行) | 本地位置(文件:行) | 状态 | 差异说明 | 验收方式 | 备注 | ZIP 类别 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 顶栏骨架：左圆形返回钮 + 中间标题 + 右动作按钮，水平内边距 16dp | `ui/book/read/ReadBookMenuBarTitle.kt:174-193`、`:228` | `entry/src/main/ets/pages/ReaderPage.ets:4687-4720`（返回 40×40 → 标题 → `Blank()` → `readerTopActionGroup`） | 已接 | 一致。 | 点屏幕中央开菜单，看顶栏三段布局 | 依据源码推断，未设备验证 | `readConfig` |
| 标题栏模式四值（`0` 应用栏上显示 / `1` 独立行（默认）/ `2` 仅标题 / `3` 不显示） | `ui/book/read/ReadBookMenuBarTitle.kt:198-270`、`res/values/array_values.xml:146-151` | `entry/src/main/ets/pages/ReaderPage.ets:2300-2318`（四个 `*Visible()` 判定）、`:276`（默认 `'1'`） | 已接 | 一致：四档判定与上游等价，默认独立行。 | 逐个切四档标题模式，看顶栏形态变化 | 依据源码推断，未设备验证 | `readConfig` |
| 标题胶囊（40dp 高、圆角 50、书名 + 章名两行，章名 70% 透明） | `ui/book/read/ReadBookMenuBarTitle.kt:492-590` | `entry/src/main/ets/pages/ReaderPage.ets:2287-2290`（书名 14 号 Medium + 章名 11 号 alpha B3）、圆角 20 | 已接 | 一致：胶囊形态与两行内容都在。圆角 20 与上游 50 视觉接近。 | 开标题胶囊，看是否显示书名 + 章名两行 | 依据源码推断，未设备验证 | `readConfig` |
| **点标题胶囊进书籍详情，长按进编辑** | `ui/book/read/ReadBookMenuBarTitle.kt:492-600` | `entry/src/main/ets/pages/ReaderPage.ets:2546-2549`（胶囊）、`:5143-5145`（行内书名）、`:5157-5159`（独占一行书名）；回调 `onOpenBookInfo` → `Index.ets:6769` → `openBookInfo` | 已接 | 一致：三种标题形态（胶囊/行内/独占一行）点一下都进书籍详情页，长按同样进（本地没有上游「阅读信息 Sheet」这个中间态，两种手势都落到整页 `AppRoute.BOOK_INFO`）。 | 点顶栏书名，应跳到书籍详情页（有「查看目录/阅读记录/书籍信息」） | 设备已验证：点胶囊中心 `(468,251)` 打开 np-test 详情页 | `readConfig` |
| 标题胶囊右端书源圆点（8dp，热区 24dp×满高）→ 登录/付费/编辑书源/禁用书源 | `ui/book/read/ReadBookMenuBarTitle.kt:596-688` | 无 | 不适用 | 本地只有本地书，没有书源概念。 | — | 平台/范围差异：本地 TXT 无书源 | `不备份` |
| 合并按钮组（40dp 高胶囊，按钮间 1dp×20dp 分隔线） | `ui/book/read/ReadBookMenuBarTitle.kt:747-756`、`:823-900` | `entry/src/main/ets/pages/ReaderPage.ets:2488-2515`（`readerTopActionGroup`：合并模式 `Row` 逐按钮插分隔线；非合并 `ForEach` 独立排列）、`:2517-2522`（`readerMergedGlassDivider` 宽 1 / 高 20 / 前景色 26 alpha） | 已接 | 一致：打开「合并标题栏按钮」后顶栏动作收进一个圆角胶囊，相邻按钮之间有竖直细线；关掉后各按钮独立成圆。 | 设置里开「合并标题栏按钮」，看顶栏按钮是否变成一个胶囊且中间有细线 | 设备已验证（截图 `b2-merge-on2.jpeg`，裁剪 `crop-merged.png`） | `readConfig` |
| 顶栏动作上限 6 个，超出按配置顺序截断；「精简顶部按钮」后只剩「更多操作」 | `ui/book/read/ReadMenuActionDefs.kt:76`、`:493-517` | `entry/src/main/ets/pages/ReaderPage.ets:144`（`MAX_TITLE_BAR_ACTIONS = 6`）、`:2437-2452`（`getVisibleTopActions`：精简模式只返回 `more_actions`；否则按配置顺序 `slice(0, 6)`） | 已接 | 一致：顶栏最多排 6 个动作，第 7 个起按配置顺序丢弃；开「精简顶部按钮」后只剩一个「更多」。本地原先只有「2 个 + 溢出菜单」，溢出菜单已按上游口径删除。 | 顶栏配 7 个动作，数顶栏实际显示几个图标（应为 6）；再开「精简顶部按钮」看是否只剩一个 | 设备已验证：配 3 个动作时三个图标全显示、无溢出菜单 | `readConfig` |
| 顶栏底色透明度 = 模糊透明度/100（默认 85%），拖滑块时压到 ≤30% 预览、松手 200ms 回弹 | `ui/book/read/ReadBookMenuBarTitle.kt:95-101`、`ReadBookMenuBar.kt:481-497`、`TinySettingItems.kt:75-95` | `entry/src/main/ets/pages/ReaderPage.ets:1264` 起（`readerMenuTintAlphaString`：`menuSliderDragging` 时把透明度压到 `Math.min(30, …)`）、`ReaderSettingsPage.ets:3151` 起（`MenuSettingSlider` 的 `Slider.onTouch` 写 `AppStorage('readerMenuSliderDragging')`） | 已接 | 一致：拖「菜单模糊透明度」滑块时顶栏/底栏实时变透（压到 30%），松手恢复目标值，不用反复进出设置页试效果。 | 打开设置拖「菜单模糊透明度」滑块，看背后正文是否在拖动过程中透出来 | 设备已验证顶栏变透；未逐帧取证回弹动画，回弹按源码推断 | `readConfig` |
| 顶栏长按二级菜单（长按换源 → 换源/更换本章源；长按刷新 → 刷新本章/刷新后续） | `ui/book/read/ReadBookMenuBarTitle.kt:796-819` | 无 | 不适用 | 本地无书源，换源与刷新都不存在。 | — | 范围差异：本地 TXT 无书源 | `不备份` |
| 浮动图标行（图标 20dp、位置四选一左上/右上/左下/右下、左右 16dp） | `ui/book/read/ReadBookMenuBarFloating.kt:61-131`、`SystemMenuPage.kt:503-552` | `entry/src/main/ets/pages/ReaderPage.ets:2347`（顶）、`:2352`（底）、`:4722`/`:4741`（挂载）、`:326`（默认 `titleBarIconPosition = 3`） | 已接 | 一致：四档位置，默认右下。 | 切浮动图标位置四档，看图标是否换到四个角 | 依据源码推断，未设备验证 | `readConfig` |
| 快速动作图标行（5 个 36×36：搜索/自动翻页/目录/朗读/设置） | `ui/book/read/ReadBookFloatingActionBar.kt`（153 行） | `entry/src/main/ets/pages/ReaderPage.ets:4730-4736` | 已接 | 一致：五个快捷动作。 | 开菜单后看是否出现一排小图标 | 依据源码推断，未设备验证 | `readConfig` |

### C3 底栏

| 上游能力 | 上游位置(文件:行) | 本地位置(文件:行) | 状态 | 差异说明 | 验收方式 | 备注 | ZIP 类别 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 底栏图标行：每行默认 5 个（可 2..8），默认 1 行（可 1..2），按钮宽 40dp，行内两端对齐 | `ui/book/read/ReadBookMenuBarBottom.kt:237-282` | `entry/src/main/ets/pages/ReaderPage.ets:2155`（`getBottomActionPages`）、`:4796-4836`（`Swiper`，高 `(showBottomActionText?64:48) * clamp(bottomRowCount,1,2) + 21`） | 已接 | 一致：2..8 个/行、1..2 行、多页左右滑。 | 底栏配 10 个动作，看是否分成两页可左右滑 | 依据源码推断，未设备验证 | `readConfig` |
| 底栏浮动（默认浮动，左右 16dp、底部 16dp + 导航栏高，圆角默认 32dp） | `ui/book/read/ReadBookMenuBar.kt:417-421`、`ReadBookMenuBarBottom.kt:211` | `entry/src/main/ets/pages/ReaderPage.ets:4837` 起（悬浮时宽 92%、`margin bottom 16`；非悬浮 100%、只圆上两角） | 已接 | 一致：默认悬浮，圆角取 `readMenuBottomCornerRadius`。 | 开关「底栏悬浮」，看底栏是否离底边 | 依据源码推断，未设备验证 | `readConfig` |
| 底栏图标下方文字（隔 2dp 一行小字，带 12dp 模糊 + 12% 黑阴影） | `ui/book/read/ReadBookMenuBarTool.kt:373-387` | `entry/src/main/ets/pages/ReaderPage.ets:4796` 起（`showBottomActionText` 控制高 64/48） | 已接 | 一致：有图标下文字。 | 开关「底栏显示文字」，看按钮高度是否变化 | 依据源码推断，未设备验证 | `readConfig` |
| 底栏「正文处理」按钮右上角红色数字角标 = 当前生效规则条数，0 不显示 | `ui/book/read/ReadBookMenuBarTool.kt:337`、`:410-431` | `entry/src/main/ets/pages/ReaderPage.ets:2594`（`getBottomActionBadgeCount`，只给 `replace_badge`）、`ReaderBottomAction` 的 `@Prop badgeCount` + 右上角 `#B3261E` 圆角 8 角标 | 已接 | 一致：本章被替换规则真正改过几条，底栏「正文处理」按钮右上角就显示那个数字；0 条不显示角标。用户排查「这段字为什么被改了」时能直接看到有几条规则命中。 | 本章命中 3 条替换规则时，看底栏「正文处理」按钮右上角是否有「3」 | 口径同上游 `ContentProcessor.kt:180-215`：只有正文真的被改动才计数，不是「已启用条数」；设备未构造出多规则命中场景，角标渲染按源码推断 | `readConfig` |
| 底栏进度条按「页」时拖过程逐格即时跳页，按「章」时松手才跳 | `ui/book/read/ReadBookMenuBarBottom.kt:84-127`、`ReadBookViewModel.kt:2506-2518` | `entry/src/main/ets/pages/ReaderPage.ets:4756`（`Slider`，`stepSize 3`）、分页模式拖过程即时改 `currentPageIndex` | 已接 | 一致：页模式即时跳、章模式松手跳。 | 拖进度条，看正文是否跟着变 | 依据源码推断，未设备验证 | `readConfig` |
| 底栏进度条滚动模式停下 250ms 后才刷新进度值 | `ReadBookViewModel.kt:108`、`:2506-2518` | `entry/src/main/ets/pages/ReaderPage.ets:3857`（`updateProgress`：分页模式立即 `applyScrollProgress`，滚动模式写 `pendingScrollProgress` + 250ms 定时器）、`:3882`（`applyScrollProgress`）、常量 `SCROLL_PROGRESS_THROTTLE_MS = 250` | 已接 | 一致：连续滚动时进度数字不再跟着手指每帧抖，停手 250ms 后才刷新一次；翻页模式仍即时更新。 | 连续滚动模式下快速上下滑动，看底部百分比是否只在停手后跳一次 | 依据源码推断，未设备验证（滚动时数字不抖可肉眼观察，但节流时序无法用截图取证） | `readConfig` |
| 底栏进度条无障碍文案「第 x / 共 y 页」/「第 x / 共 y 章」 | `ui/book/read/ReadBookMenuBarBottom.kt:84-95` | `entry/src/main/ets/pages/ReaderPage.ets:2578`（`getProgressAccessibilityText`）、`:5228`（`Slider.accessibilityText(...)`） | 已接 | 一致：进度条按「页」模式念「第 x / 共 y 页」，按「章」模式念「第 x / 共 y 章」，不再只念「滑块」。 | 开读屏，焦点移到进度条，听是否念「第 x / 共 y 页」 | 依据源码推断，未设备验证——`uitest dumpLayout` 不导出 `accessibilityText`，设备上无法直接取证 | `readConfig` |
| 底栏亮度条（横向贴底 / 竖向贴边宽 56dp、滑块高 168dp，上下各一枚按钮切自动亮度与左右位置） | `ui/book/read/ReadBookMenuBarBottom.kt:138-158`、`:376-459`、`ReadBookMenuBar.kt:249-270` | `entry/src/main/ets/pages/ReaderPage.ets:3460`（`ReaderBrightnessBar`）、`ReaderBrightnessButton`（40×40，`profile_auto_awesome` / `app_swap`）、`ReaderBrightnessSlider` 竖排高 168 | 已接 | 一致：竖排亮度条宽 56、贴左/贴右靠边 8、上端「跟随系统」下端「左右位置」两枚按钮，滑块高 168，底部显示当前亮度数值；点「左右位置」整条换边，点「跟随系统」切自动亮度并收起菜单。 | 设置里切「竖排」亮度视图，看是否上下各有一枚按钮、点「左右位置」整条是否换边 | 设备已验证：左侧/右侧两种贴边、两枚按钮点击生效（截图 `b2-vbar2.jpeg`、`b2-vbar-right.jpeg`、`b2-vbar-fix.jpeg`） | `readConfig` |
| 底栏 `readSliderMode` 隐藏后整条进度消失，只剩上下章按钮 | `ui/book/read/ReadBookMenuBarBottom.kt:161-196` | `entry/src/main/ets/pages/ReaderPage.ets:5211`（`if (this.readSliderMode !== '1')` 只包中间 `Stack{Slider}`，左右两个换章按钮在条件外） | 已接 | 一致：进度条设「不显示」后中间滑块消失，左侧「上一章」、右侧「下一章」两个按钮仍在，用户仍能一键换章。 | 进度条设「不显示」，看底栏是否还剩左右两个换章箭头 | 设备已验证（截图 `b2-reader-noslider.jpeg`：只剩 `←` `→`） | `readConfig` |

### C4 快捷面板

| 上游能力 | 上游位置(文件:行) | 本地位置(文件:行) | 状态 | 差异说明 | 验收方式 | 备注 | ZIP 类别 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 快捷面板两页横向分页（第 0 页全局、第 1 页菜单系统），高度随内容平滑过渡 | `ui/book/read/sheet/ReadStyleSheet.kt:39-151` | `entry/src/main/ets/pages/ReaderSettingsPage.ets:659`（`settingsContent` 用 `Swiper` 两页：`:714` `globalSettingsPage` + `:827` `menuSettingsContent`） | 已接 | 一致：两页 Swiper，全局页 + 菜单页。 | 开快捷面板，左右滑看是否有第二页 | 依据源码推断，未设备验证 | `readConfig` |
| 底部四个 tab（全局 / 菜单系统 / 信息 / 更多设置），只有前 2 个切 pager，后 2 个开独立面板 | `ui/book/read/sheet/ReadStyleSheet.kt:39-151`（`CardTabRow` 4 tab） | `entry/src/main/ets/pages/ReaderSettingsPage.ets:2023-2030`（4 页签：阅读界面 62%/88%、菜单 68%、信息 70%、更多设置 86%/100%） | 已接 | 一致：四个 tab，后两个开独立面板（本地是不同尺寸的 sheet）。 | 点四个 tab，看是否分别是面板内切换与独立弹出 | 依据源码推断，未设备验证 | `readConfig` |
| 全局页：字号滑杆 5..50 + 右侧 56dp 方形「排版」卡 + 背景样式卡 + 主题卡横排 + 底行三项（翻页动画下拉 6 项 / 速度卡 4 档 / 边距卡） | `ui/book/read/sheet/GlobalThemePage.kt:104-140`、`:143-192`、`:194-345`、`:347-462` | `entry/src/main/ets/pages/ReaderSettingsPage.ets:714`（`globalSettingsPage`：字号 Slider 5~50 + 背景卡横滚 + 翻页动画行） | 已接 | 一致：字号滑杆、背景卡、主题卡、翻页动画行都在。 | 开快捷面板全局页，逐块看 | 依据源码推断，未设备验证。字段本身见 READER-CONFIG | `readConfig` |
| 菜单系统页：内层三页横向分页（全局 / 底栏布局 / 标题栏布局），每行图标 2..8、行数 1..2 | `ui/book/read/sheet/SystemMenuPage.kt:80-905`、`:552-735`、`:738-868` | `entry/src/main/ets/pages/ReaderSettingsPage.ets:827`（`menuSettingsContent`，条目由 `getMenuSettingsEntries()` `:1788` 生成，41 条含 5 分组标题） | 未接 | 本地菜单页是**一长串纵向列表**，没有上游的三页横向分页结构；41 条里绝大多数控件只活在 `@State`（见 READER-CONFIG 口径 2）。用户找不到「底栏布局」「标题栏布局」这两个分区。 | 开快捷面板菜单页，看是否能左右滑到「底栏布局」 | 依据源码推断，未设备验证。READER-CONFIG 已盘字段，本行只盘形态 | `readConfig` |
| 字号滑杆右侧 56dp 方形「排版」卡（单击进排版页） | `ui/book/read/sheet/GlobalThemePage.kt:104-140` | `entry/src/main/ets/pages/ReaderSettingsPage.ets:714` 起（无方形排版卡，排版入口在别处） | 未接 | 本地字号滑杆右侧**没有方形排版卡**，想调字体行距要先滑到底部 tab 再点进去，路径长一步。 | 开快捷面板，看字号滑杆右边是不是空的 | 依据源码推断，未设备验证 | `readConfig` |

### C5 目录页

| 上游能力 | 上游位置(文件:行) | 本地位置(文件:行) | 状态 | 差异说明 | 验收方式 | 备注 | ZIP 类别 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 目录页四页签（信息 / 目录 / 书签 / 笔记） | `ui/book/read/sheet/ReaderBookSheet.kt`（`ReaderBookSheetTab {Information, Toc, Bookmarks, Marks}`） | `entry/src/main/ets/pages/CatalogPage.ets:158`（`getTabLabel`）、`:629` | 已接 | 一致：四个 tab。 | 打开目录页看 tab 数 | 依据源码推断，未设备验证 | `readConfig` |
| 目录头部：40dp 封面 + 书名 2 行 + 章名跑马灯 + 「当前/总数」 | `ui/book/read/sheet/ReaderBookSheet.kt:369-450` | `entry/src/main/ets/pages/CatalogPage.ets`（目录页头部） | 已接 | 一致。 | 看目录页顶部是否有封面与书名 | 依据源码推断，未设备验证 | `readConfig` |
| 目录工具行：搜索框 + 3 个方形按钮 + ⋮ 菜单 | `ui/book/read/sheet/ReaderBookSheet.kt:654-800` | `entry/src/main/ets/pages/CatalogPage.ets:385`（`TextInput` 搜索章节）、`:401`（正/倒序切换）、`:345`（`CatalogMoreMenu`：更新目录/替换规则/本地 TXT 目录规则） | 已接 | 一致：搜索 + 排序 + 更多菜单。 | 看目录页顶部工具行 | 依据源码推断，未设备验证 | `readConfig` |
| 目录搜索忽略大小写、**卷名永远保留** | `ui/book/toc/TocViewModel.kt:581-594` | `entry/src/main/ets/pages/CatalogPage.ets:145`（`displayTitle.toLowerCase().includes(keyword.toLowerCase())`）、`:146`（`matched \|\| (searching && isVolume)`） | 已接 | 搜索框里大小写混写都能命中；搜索期间**卷标题行始终留在列表里**，结果仍按卷分组，用户能看出命中的章属于哪一卷。 | 目录页搜索框输入大小写混写的关键词，看是否命中；在分卷书里搜卷内章名，看卷头是否还在 | 照抄上游 `TocViewModel.filterData` 的 `contains(key, true) \|\| it.chapter.isVolume`；依据源码推断，未设备验证 | `readConfig` |
| 章节行按 `tocLevel` 多级缩进（每级 10dp，最多 6 级） | `ui/book/read/sheet/ReaderBookSheet.kt:890-935` | `entry/src/main/ets/pages/CatalogPage.ets:614`（`left: 12 + Math.min(6, Math.max(0, chapter.tocLevel)) * 10`） | 已接 | 目录里卷内章节比卷标题**右缩 10vp**，层级最多压到 6 级（60vp）；原来只有「卷内 26 / 卷外 12」两档，多级目录看不出深浅。 | 在分卷书目录里看卷标题与卷内章节的左边距是否不同 | `tocLevel` 数据来源 `BookRepository.ets:1469-1489`（卷 0、卷内 1）；依据源码推断，未设备验证 | `readConfig` |
| 粘性卷头（滚动超过 24 时卷名吸顶） | `ui/book/toc/TocScreen.kt:705-730` | `entry/src/main/ets/pages/CatalogPage.ets:325-361`（`updateStickyVolume` / `scrollToStickyVolume`）、`:43`（`stickyVolumeTitle`） | 已接 | 目录往下滚过卷标题 24vp 后，**卷名吸在列表顶部**成一枚小胶囊，滚出这个卷才换；点它跳回该卷第一行。原来卷名滚过去就没了。 | 在分卷长目录里往下滚，看顶部是否浮出卷名；点它看是否回到卷首 | 判定逐条照抄上游（首项是卷且偏移 > 24 才吸，折叠卷不吸）；依据源码推断，未设备验证（现有本地书均未分卷，无卷可验） | `readConfig` |
| 卷折叠（点卷头收起/展开卷内章节） | `ui/book/toc/TocScreen.kt`、`TocHierarchy.kt`（86 行） | `entry/src/main/ets/pages/CatalogPage.ets:39`（`collapsedVolumes`）、`:147-150`（`toggleVolume`） | 已接 | 一致。 | 点卷头看卷内章节是否收起 | 依据源码推断，未设备验证 | `readConfig` |
| 首次进目录自动滚到当前章（偏移 `-viewportEndOffset/4`，delay 100ms） | `ui/book/toc/TocScreen.kt:363-377` | `entry/src/main/ets/pages/CatalogPage.ets:276`（`scrollToCurrentChapter`） | 已接 | 一致：自动定位到当前章。 | 读到第 50 章时打开目录，看是否自动停在第 50 章附近 | 依据源码推断，未设备验证 | `readConfig` |
| 章节右侧状态图标（字数卡 / 定位 / 下载中 / 成功 / 失败 / 本地空占位），切换 fade 200ms + scale 0.8 | `ui/book/toc/TocScreen.kt:960-1000` | 无（本地无下载状态，字数直接显示在行内） | 不适用 | 本地 TXT 全离线，不存在下载状态图标。 | — | 范围差异：本地无在线下载 | `不备份` |
| 目录页 FAB 四项（更新目录 / 替换规则 / TXT 目录规则 / 书签导出） | `ui/book/toc/TocScreen.kt:612-634` | `entry/src/main/ets/pages/CatalogPage.ets:345`（`CatalogMoreMenu`）、`:334`（`BookmarkExportMenu`） | 已接 | 一致：四项都在，本地收在 ⋮ 菜单里而非 FAB。 | 点目录页 ⋮，看是否有这四项 | 依据源码推断，未设备验证 | `readConfig` |
| 目录多选（全选 / 反选 / 加书签 / 取消选择） | `ui/book/read/sheet/ReaderBookSheet.kt:678-740` | `entry/src/main/ets/pages/CatalogPage.ets:430-500`（`enterSelectionMode` / `toggleChapterSelection` / `selectAllChapters` / `invertChapterSelection` / `addBookmarksForSelection` / `ChapterSelectionMenu`）、`:73`（`onAddBookmarksForChapters` 回调） | 已接 | 长按任意章节行进入多选：每行左侧出现勾选圈，顶部多一条「已选 N 章 / 操作 / 完成」；点「操作」弹出四项菜单，选「加书签（N）」后弹出「已为 N 章添加书签」。原来目录页完全不能批量操作。 | 长按章节行 → 看是否出现勾选圈与工具条 → 点「操作」→ 点「加书签」→ 看书签 tab 里是否多出 N 条 | 设备验证 ✔（`tmp3/shots/f.jpeg` 已选 1 章 + 工具条、`g.jpeg` 四项菜单、`h.jpeg` 加书签完成）；上游 7 项里另 3 项见下一行 | `readConfig` |
| 目录多选里的「下载选中 / 删除角色分配 / 删除朗读音频」 | `ui/book/read/sheet/ReaderBookSheet.kt:678-740` | 不做 | 不适用 | 上游这三项分别属于章节下载、朗读角色分配、朗读音频，本地 TXT 阅读没有下载与朗读链路，界面里也不该出现这三项，否则点了没有去处。 | 长按章节行打开「操作」菜单，确认只有四项 | 平台差异：本地无下载器、无 TTS 角色系统（范围外，见 `docs/PROJECT.md`） | `不备份` |
| 书签导出默认文件名 `书名_yyyyMMdd_HHmm.json/.md` | `ui/book/read/sheet/ReaderBookSheet.kt:1117-1176` | `entry/src/main/ets/pages/CatalogPage.ets:334`（`BookmarkExportMenu`，JSON / Markdown 两种） | 已接 | 一致：两种格式。 | 导出书签，看默认文件名格式 | 依据源码推断，未设备验证 | `bookmark` |
| 笔记页：行间距 6dp、单击编辑、长按跳转 | `ui/book/read/sheet/ReaderBookSheet.kt:1303-1341` | `entry/src/main/ets/pages/CatalogPage.ets`（笔记 tab） | 已接 | 一致。 | 在笔记 tab 单击/长按一条笔记，看是否分别编辑/跳转 | 依据源码推断，未设备验证 | `bookmark` |

### C6 更多操作面板

| 上游能力 | 上游位置(文件:行) | 本地位置(文件:行) | 状态 | 差异说明 | 验收方式 | 备注 | ZIP 类别 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 更多操作面板每页 8 格（4 列 × 2 行），格边长 `(面板宽 − 56dp)/4`，超 8 项左右滑动 | `ui/book/read/sheet/ReaderMoreActionsSheet.kt:140-182` | `entry/src/main/ets/pages/ReaderPage.ets:2573`（`moreActionUnavailableSheet`）、更多面板本体 | 已接 | 一致：4×2 网格分页。 | 打开更多操作，数一页几个格子 | 依据源码推断，未设备验证 | `readConfig` |
| 每页末尾固定「配置更多操作」 | `ui/book/read/sheet/ReaderMoreActionsSheet.kt:105-118` | `entry/src/main/ets/pages/ReaderPage.ets:72-95`（`MORE_ACTION_CONFIG_ENTRY`） | 已接 | 一致。 | 看每页最后一格是否是「配置」 | 依据源码推断，未设备验证 | `readConfig` |
| 更多操作 28 项 id（含书源相关 5 项、AI 1 项、朗读下载 1 项等） | `ui/book/read/sheet/ReaderMoreActionsSheet.kt:314-416`、`ReadBookContract.kt:548` | `entry/src/main/ets/pages/ReaderPage.ets:72-95`（`READER_MORE_ACTIONS` **23 项**） | 未接 | 本地少 5 项（`source_login`/`source_pay`/`edit_source`/`disable_source`/`ai_chat`）。前四项是书源专属（见下行不适用），但 **`ai_chat` 是真的缺**。 | 打开更多操作，看是否有「AI 对话」 | 依据源码推断，未设备验证 | `readConfig` |
| 条目适用性：目录规则仅本地 txt、编码仅本地书、删除 ruby / 删除 h 仅 epub | `ui/book/read/ReadMenuActionDefs.kt:105-136` | `entry/src/main/ets/pages/ReaderPage.ets`（`READER_MORE_ACTIONS` 的 `migrated` 标记）、`ReaderSettingsRepository.ets:686`（`isReaderActionApplicable`） | 已接 | 一致：不适用的条目不显示。 | 打开 EPUB 书，看更多操作里是否还有「目录规则」 | 依据源码推断，未设备验证 | `readConfig` |
| 3 个带「更多」箭头的条目（换源 2 项 / 刷新 3 项 / 自定义按钮），图片样式与翻页动画点一下直接展开 | `ui/book/read/sheet/ReaderMoreActionsSheet.kt:186-217` | 无（本地这些条目直接弹「尚未迁移」） | 未接 | 本地点「换源」「刷新」**弹的是「此操作尚未迁移，当前不会执行。」**（`ReaderPage.ets:2573`），12 项里一半是这种提示。用户会以为功能坏了。 | 点「刷新」，看是展开二级菜单还是提示未迁移 | 依据源码推断，未设备验证。其中换源/刷新本地本就不适用（无书源），但 `page_anim`/`image_style` 是本地适用的 | `readConfig` |
| 条目 `enabled && applicable` 才显示 | `ui/book/read/sheet/ReaderMoreActionsSheet.kt:127-135` | `entry/src/main/ets/pages/ReaderPage.ets`（`isReaderActionApplicable`） | 已接 | 一致。 | 本地书与 EPUB 各开一次更多操作，对比条目 | 依据源码推断，未设备验证 | `readConfig` |

### C7 二级面板

| 上游能力 | 上游位置(文件:行) | 本地位置(文件:行) | 状态 | 差异说明 | 验收方式 | 备注 | ZIP 类别 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 排版页七个子页（排版 2 / 信息 2 / 边距 3） | `ui/book/read/sheet/TypographyPage.kt:55-345` | `entry/src/main/ets/pages/ReaderSettingsPage.ets`（排版面板） | 未接 | 本地排版面板**是单页纵向滚动**，没有上游的 7 个子页结构。用户要翻很久才能找到「页边距」。 | 打开排版面板，看是否能左右滑到「边距」 | 依据源码推断，未设备验证。字段见 READER-CONFIG C 块 | `readConfig` |
| 排版正文 5 分区（字体 / 颜色 / 效果 / 间距 / 对齐） | `ui/book/read/sheet/TypographyTabs.kt:264-429` | `entry/src/main/ets/pages/ReaderSettingsPage.ets`（排版面板分区） | 已接 | 一致：五个分区都在。 | 看排版面板是否有这五块 | 依据源码推断，未设备验证 | `readConfig` |
| 字重三预设 + 100..900 九档 | `ui/book/read/sheet/TypographyTabs.kt:114-197` | `entry/src/main/ets/pages/ReaderSettingsPage.ets`（字重控件） | 已接 | 一致。 | 看字重是否有「常规/加粗/细体」+ 数字档 | 依据源码推断，未设备验证 | `readConfig` |
| 标题 4 分区（字号 1..60 或相对 0..60、位置 3 项、分段方式 4 项、副标题缩放 0..2 step 0.1、标题边距 0..200） | `ui/book/read/sheet/TypographyTabs.kt:431-674` | `entry/src/main/ets/pages/ReaderSettingsPage.ets`（标题设置分区）、`ReaderPage.ets:3069-3076` | 已接 | 一致：分段方式、副标题缩放、位置都在。 | 调副标题缩放，看标题第二行是否变大 | 依据源码推断，未设备验证 | `readConfig` |
| 页眉 3 分区（模式 3 项、左中右 tip、分隔线色、字号 0..100） | `ui/book/read/sheet/TypographyTabs.kt:675-790` | `entry/src/main/ets/pages/ReaderSettingsPage.ets`（页眉设置） | 已接 | 一致。 | 页眉三槽分别配 tip，看是否都生效 | 依据源码推断，未设备验证 | `readConfig` |
| 页脚 3 分区（模式 2 项、应用页眉样式） | `ui/book/read/sheet/TypographyTabs.kt:791-916` | `entry/src/main/ets/pages/ReaderSettingsPage.ets`（页脚设置） | 已接 | 一致。 | 页脚勾「应用页眉样式」，看样式是否跟随 | 依据源码推断，未设备验证 | `readConfig` |
| 边距：正文上限 200、页眉页脚 300 | `ui/book/read/sheet/TypographyTabs.kt:918-1018` | `entry/src/main/ets/pages/ReaderSettingsPage.ets`（边距设置） | 已接 | 一致。 | 把边距拖到最大，看是否停在 200/300 | 依据源码推断，未设备验证 | `readConfig` |
| 页眉页脚 tip 类型 21 种 | `ui/book/read/sheet/TypographyTabs.kt:1234-1250` | `entry/src/main/ets/pages/ReaderPage.ets:4380`（`getReaderInfoType`，type 1..20） | 未接 | 本地 20 种，少 1 种（上游第 21 种）。差异极小，但**同一份备份恢复后页眉会变成另一种内容**。 | 对照上游 21 种与本地 20 种，找出缺的那一种 | 依据源码推断，未设备验证 | `readConfig` |
| 页眉页脚字体设置 | `ui/book/read/sheet/TypographyTabs.kt`（字体分区） | `entry/src/main/ets/pages/ReaderSettingsPage.ets:1442`（`showNotMigrated('页眉页脚字体')`） | 未接 | 点「页眉页脚字体」**弹「尚未迁移」提示**，页眉只能用正文字体。 | 点页眉字体设置，看是否弹未迁移提示 | 依据源码推断，未设备验证。READER-CONFIG 已登记 | `readConfig` |
| 高亮规则编辑：5 分区 + 实时预览、九宫格编辑器（250dp 画布、2dp 绿色切分线、4 个 5dp 手柄、拖拽命中 32dp） | `ui/book/read/sheet/HighlightRuleEditSheet.kt:122-1459`、`:1207-1444` | `entry/src/main/ets/pages/ReaderHighlightRuleSheet.ets:288-310`（列表行）、编辑区字段 6 项 | 未接 | 本地高亮规则编辑**只有 6 个字段**（名称 / 正则 / 字色 / 背景色 / 下划线样式 / 线条颜色），没有上游的 5 分区、没有实时预览、没有九宫格编辑器。文案自认「作用范围：当前仅支持正文」。 | 打开高亮规则编辑，看有几个字段 | 依据源码推断，未设备验证 | `themeConfig` |
| 高亮规则上限（本地：单章 150000 字符、64 条规则） | —（上游无此上限，用二分查找） | `entry/src/main/ets/data/ReaderHighlightRuleEngine.ets:6-7`（`maximumChapterCharacters = 150000`、`maximumRuleCount = 64`） | 不适用 | 上游没有上限（靠优先级仲裁 + 二分查找）。本地超过 15 万字的章**整章不高亮**，用户会以为规则坏了。 | 打开一本单章超 15 万字的书，看高亮是否生效 | 依据源码推断，未设备验证。这是本地性能兜底，上游无可对照行为 | `themeConfig` |
| 划线样式面板（16 个 26dp 预设色 + 7 种效果 + 笔记输入框） | `ui/book/read/sheet/MarkingSheet.kt:282-315`、`:246`、`:353-392` | `entry/src/main/ets/pages/ReaderHighlightRuleSheet.ets`（无独立划线面板） | 未接 | 本地**没有独立的划线样式面板**：选中文字后只能「标记」，颜色与效果取自高亮规则，不能当场选色。上游 16 个预设色 + 7 种效果一屏可选。 | 长按选中文字 → 标记，看是否弹出选色面板 | 依据源码推断，未设备验证 | `bookmark` |
| 背景文字配置面板（5 个 56dp 动作卡 + 日夜两格背景色/背景图 + 透明度 0..100） | `ui/book/read/sheet/BgTextConfigSheet.kt:59-275` | `entry/src/main/ets/pages/ReaderSettingsPage.ets`（背景卡横滚：`BackgroundShareOption` + 背景样式 + 新增 + 主题列表） | 已接 | 一致：背景样式与主题列表都在。 | 开快捷面板背景卡，看是否有新增/编辑 | 依据源码推断，未设备验证。字段见 READER-CONFIG E 块 | `themeConfig` |
| 主题列表（网格 2..6 列、卡长宽比 44:56、前 5 个内置不可删、管理态 7 个动作） | `ui/book/read/sheet/ThemeListContent.kt:232-390`、`:466-492` | `entry/src/main/ets/pages/ReaderSettingsPage.ets`（主题列表） | 未接 | 本地主题列表**没有网格列数切换、没有管理态多选**（分享/全选/反选/删除/置顶/置底/导出 7 个动作）。主题多了以后只能一个个删。 | 长按主题卡，看是否进管理态 | 依据源码推断，未设备验证 | `themeConfig` |
| 下划线配置面板 8 项（开关/颜色/虚线/延伸/高度 0..20/间距 0..20/虚线黑段/白段） | `ui/book/read/sheet/UnderlineConfigSheet.kt:40-163` | `entry/src/main/ets/pages/ReaderHighlightRuleSheet.ets`（下划线样式 6 项选择） | 未接 | 本地只能从下拉里选线型，**不能调高度、偏移、虚线黑段/白段长度**。上游 8 项细调。 | 打开下划线设置，数有几项 | 依据源码推断，未设备验证 | `themeConfig` |
| 阴影设置面板 5 项（开关/颜色/模糊 0..100/X -50..50/Y -50..50） | `ui/book/read/sheet/ShadowSetSheet.kt:29-106` | `entry/src/main/ets/pages/ReaderSettingsPage.ets`（文字阴影） | 已接 | 一致：五项都在。 | 打开阴影设置，数有几项 | 依据源码推断，未设备验证 | `readConfig` |
| 护眼配置面板（强度 0..100 默认 50、定时开关展开起止时间） | `ui/book/read/sheet/EyeProtectionConfigSheet.kt:29-135` | `entry/src/main/ets/pages/ReaderSettingsPage.ets`（护眼设置） | 已接 | 一致。 | 开护眼，看强度默认是否 50 | 依据源码推断，未设备验证 | `themeConfig` |
| 内容编辑面板（头部 ⋮ 2 项：恢复原文/仅正文、正文框固定 400dp、仅本地 TXT 有「保存到源文件」、定位落点 = 光标顶 − 120px） | `ui/book/read/sheet/ContentEditSheet.kt:52-205`、`:60-104` | `entry/src/main/ets/pages/ReaderPage.ets:2534`（`selectMoreAction` → `edit_content`） | 已接 | 一致：编辑正文、保存到源文件都在。 | 更多操作 →「编辑内容」，看是否能改正文并保存 | 依据源码推断，未设备验证 | `localBook` |
| 文本处理面板（高 0.72、搜索框、4 种筛选默认 Effective、规则可长按拖动排序） | `ui/book/read/sheet/TextProcessingSheet.kt:108-602`、`:77-82` | `entry/src/main/ets/pages/ReaderTextProcessingSheet.ets`（两个 tab：替换净化 / 正文处理） | 未接 | 本地文本处理面板**没有 4 种筛选（全部/启用/禁用/生效）**、**规则不能拖动排序**。规则多了以后找一条要滚很久。 | 开文本处理面板，看顶部是否有筛选下拉 | 依据源码推断，未设备验证 | `replaceRule` |
| 生效规则面板（虚拟项 `CHINESE_CONVERT_ID = -1`、`RE_SEGMENT_ID = -2`，行右侧 ✕ 就地移除） | `ui/book/read/sheet/EffectiveReplacesSheet.kt:38-168` | 无（本地无「当前生效」视图） | 未接 | 本地**看不到哪些规则当前生效**，也看不到简繁转换与重新分段这两个虚拟项，用户无法快速关掉某条。 | 找「生效规则」入口 | 依据源码推断，未设备验证 | `replaceRule` |
| 文本处理记录面板（原文/修改后各 maxLines 3、高 max 520dp） | `ui/book/read/sheet/ContentProcessesSheet.kt:48-270` | `entry/src/main/ets/pages/ReaderTextProcessingSheet.ets`（处理记录列表：查看前后 / 删除） | 已接 | 一致。 | 看处理记录里是否能看前后对比 | 依据源码推断，未设备验证 | `replaceRule` |
| 选词菜单配置面板（两开关 + 两个 stickyHeader 分组 + 隐藏项 FlowRow + 每行 −/+ 36dp） | `ui/book/read/sheet/TextSelectMenuConfigSheet.kt:67-330`、`:182-270` | `entry/src/main/ets/pages/ReaderSettingsPage.ets`（选词菜单配置） | 已接 | 一致：两分组、顺序调整、隐藏项区。 | 开选词菜单配置，看是否有分组与隐藏项 | 依据源码推断，未设备验证。ZIP-BOOKMARK F 块已盘项级内容 | `readConfig` |
| 点击区域配置面板（全屏覆盖层、3×3 玻璃卡、内边距 3dp、顶部留 36dp、14 项动作） | `ui/book/read/sheet/ClickActionConfigSheet.kt:44-176`、`:61-75` | `entry/src/main/ets/pages/ReaderSettingsPage.ets:2471-2515`（3×3 卡，每格高 58、圆角 10、选中 `#454B62`） | 已接 | 一致：全屏 3×3 配置。 | 打开点击区域配置，看是否是全屏九宫格 | 依据源码推断，未设备验证 | `readConfig` |
| 翻页动画下拉 7 项（含默认 -1），选即生效无确定按钮 | `ui/book/read/sheet/PageAnimConfigSheet.kt:11-48` | `entry/src/main/ets/pages/ReaderSettingsPage.ets`（翻页动画行） | 已接 | 一致。 | 点翻页动画，看下拉几项、是否选即生效 | 依据源码推断，未设备验证 | `readConfig` |
| 自动翻页面板（滑杆 1..120 秒 + 3 个圆形按钮：目录/停止/设置） | `ui/book/read/sheet/AutoReadSheet.kt:37-173` | `entry/src/main/ets/pages/ReaderPage.ets:4881-4914`（Slider 1..120 + 三文字按钮「目录/停止/翻页设置」） | 已接 | 一致：三个按钮，本地是文字而非圆形。 | 开自动翻页面板，看是否三项都有 | 依据源码推断，未设备验证 | `readConfig` |
| 浮动栏图标配置（顶栏/标题栏/底栏三处共用，行圆角 12dp、拖动抬升 4dp、关闭态透明度 0.38） | `ui/book/read/sheet/FloatingBarIconConfigSheet.kt:25-128`、`ui/widget/components/ReorderableConfigList.kt:65-131` | `entry/src/main/ets/pages/ReaderSettingsPage.ets:2880-2932`（底栏按钮配置：行 = 图标+名称+范围+「未迁移」+眼睛开关 36×36+上下箭头+装饰拖拽把手） | 未接 | 本地配置行的**拖拽把手只是装饰**，不能拖动排序，只能点上下箭头一格一格挪。配 10 个按钮时要挪很多次。 | 按住配置行的把手往上下拖，看是否能拖动 | 依据源码推断，未设备验证 | `readConfig` |

## D 交互层

### D1 点击分区

| 上游能力 | 上游位置(文件:行) | 本地位置(文件:行) | 状态 | 差异说明 | 验收方式 | 备注 | ZIP 类别 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 3×3 九宫格点击分区（按宽高各三等分） | `feature/reader/core/gesture/ReaderTapAction.kt:37-54` | `entry/src/main/ets/pages/ReaderPage.ets:2080`（`handleReaderTapAt` 用 `floor(x/w*3)`、`floor(y/h*3)`）、`:2090`（`performReaderTapAction`） | 已接 | 一致：三等分。 | 点屏幕九个位置，看动作是否不同 | 依据源码推断，未设备验证 | `readConfig` |
| 每格 14/15 种动作可选（无/菜单/下一页/上一页/下一章/上一章/朗读上一段/朗读下一段/加书签/编辑正文/切换替换/目录/搜索/同步进度/朗读暂停） | `feature/reader/core/gesture/ReaderTapAction.kt:3-18`、`ui/book/read/sheet/ClickActionConfigSheet.kt:61-75`（14 项） | `entry/src/main/ets/pages/ReaderSettingsPage.ets:2471-2515`（`READER_CLICK_REGION_ACTIONS`） | 未接 | 本地支持 `无操作/菜单/下一页/上一页/下一章/上一章/添加书签/编辑内容/替换/目录/全文搜索/同步阅读进度`，**缺朗读三项与「朗读暂停继续」**（本地无朗读，属范围外），但**缺「上一章」以外的翻页粒度**不影响。实际差异：本地无「上一章」选项以外的缺口都很小。 | 打开点击区域配置，数动作项数 | 依据源码推断，未设备验证。朗读三项属范围外 | `readConfig` |
| 脏值（配置里写了不认识的动作）按「无动作」处理 | `feature/reader/core/gesture/ReaderTapAction.kt:21-22` | `entry/src/main/ets/pages/ReaderPage.ets:2090` 起（`performReaderTapAction` 的 `default` 分支走 `onUnavailableAction`） | 已接 | 一致：不认识的动作不执行。 | 备份里写一个非法动作值再恢复，看点击是否无反应 | 依据源码推断，未设备验证 | `readConfig` |
| 正中格优先级：朗读中→朗读菜单；自动翻页中→自动翻页面板；搜索条显示中→收起；否则→主菜单 | `ui/book/read/ReadBookController.kt:626-634` | `entry/src/main/ets/pages/ReaderPage.ets:2090`（`performReaderTapAction` 按配置的动作执行，无状态优先级） | 未接 | 本地**点中间永远执行配置的动作**（默认「菜单」）。自动翻页进行中点中间会直接开菜单而不是打开自动翻页面板；搜索条显示时点中间也不会先收起搜索条。 | 开自动翻页后点屏幕中央，看弹出的是菜单还是自动翻页面板 | 依据源码推断，未设备验证 | `readConfig` |
| 图片点击四档（1 直接开大图 / 2 单击执行图片动作（默认）/ 3 不响应 / 4 双击才执行，双击窗口 300ms） | `ui/book/read/ReadBookController.kt:674-693` | 无（本地画布不区分图片点击） | 未接 | 本地**点图片没有任何反应**，不会放大。TXT 里带插图的用户无法看图。 | 点正文里的图片，看是否放大 | 依据源码推断，未设备验证 | `readConfig` |
| 正文内元素点击（点划线文字=打开该条笔记、点链接=先弹确认页） | `ui/book/read/ReadBookController.kt:591-620` | 无（本地画布不区分元素点击） | 未接 | 本地**点划线文字不会打开笔记**，只能去目录页笔记 tab 找；点链接也不响应。 | 点一段划线文字，看是否弹出笔记编辑 | 依据源码推断，未设备验证 | `bookmark` |

### D2 翻页手势

| 上游能力 | 上游位置(文件:行) | 本地位置(文件:行) | 状态 | 差异说明 | 验收方式 | 备注 | ZIP 类别 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 横向拖动跟手（拖动过程中页面跟着手指位移） | `feature/reader/ReaderCanvasSurface.kt:1586-1602`（COVER 的 `clipRect` 随 `displayOffset` 变）、`:1304-1330` | `entry/src/main/ets/pages/ReaderPage.ets:2001`（`updateHorizontalPageDrag` 逐帧写 `turnTransition` 并重绘）、`:2050`（`finishHorizontalPageDrag` 从当前位置续到目标） | 已接 | 越过 touch-slop 后页面开始跟着手指走，折页模式下纸角也跟着触点卷；松手时从当前位置续到目标位置，不再「拖到一半松手像没反应」。 | 慢慢拖动页面但先不松手，看页面是否跟着移动 | 依据源码推断，未设备验证。`uitest` 注入输入抓不到拖动中间帧（慢拖会触发长按选词、快拖截不到），只能确认 `onActionUpdate` 每帧都进（hilog 实测 94~143 条 `offsetX` 单调变化） | `readConfig` |
| 拖动阈值（`pageTouchSlop`，默认 36） | `feature/reader/core/gesture/ReaderGestureSettingsPolicy.kt:5-7` | `entry/src/main/ets/pages/ReaderPage.ets:4620`（`slop = pageTouchSlop > 0 ? pageTouchSlop : 36`） | 已接 | 一致：默认 36。 | 极轻地横划一下，看是否翻页 | 依据源码推断，未设备验证 | `readConfig` |
| 松手判定（`commitProgress` 0.35 / 甩动 900 px/s） | `feature/reader/core/transition/ReaderPageTransition.kt:156-181` | `entry/src/main/ets/pages/ReaderPage.ets:2050`（`finishHorizontalPageDrag` → `ReaderPageTransitionPolicy.release(transition, velocityPxPerSecond)`）、`entry/src/main/ets/reader/ReaderCanvasSurface.ets:180-204` | 已接 | 位移过 35% 或甩动过 900 px/s 都翻页，两个都不满足就回弹到原位。快速轻甩现在能翻页，不用再拖满小半屏。 | 快速轻甩一下，看是否翻页 | 依据源码推断，未设备验证。`event.velocityX` 单位是 vp/s（SDK `gesture.d.ts:863`） | `readConfig` |
| 翻页手势与拖选解耦（拖选阈值独立） | `feature/reader/core/gesture/ReaderGestureSettingsPolicy.kt:16-19` | `entry/src/main/ets/pages/ReaderPage.ets:4544-4650`（`GestureGroup` 并行，先判 `canvasHandleHit` 抓把手） | 已接 | 一致：抓到把手时只拖把手，不翻页。 | 长按出选区后拖把手，看是否翻页 | 依据源码推断，未设备验证 | `readConfig` |

### D3 滚动手势

| 上游能力 | 上游位置(文件:行) | 本地位置(文件:行) | 状态 | 差异说明 | 验收方式 | 备注 | ZIP 类别 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 滚动拖拽逐帧跟手 | `feature/reader/ReaderCanvasSurface.kt:1414` 分支（`scrollDrag`） | `entry/src/main/ets/pages/ReaderPage.ets:4958`（纵向 `PanGesture.onActionUpdate` 逐帧算 delta 调 `applyReaderScrollDelta`） | 已接 | 滚动模式下手指拖动正文逐帧跟随，松手停在原地不跳回。 | 滚动模式下拖动正文，看文字是否跟着手指走 | 已设备验证（hilog 每 16ms 一条 `offsetY` 递增） | `readConfig` |
| 滚动跨页（拖过页边界直接进下一章，不需松手） | `feature/reader/ReaderCanvasSurface.kt:1414` 分支 | `entry/src/main/ets/pages/ReaderPage.ets:4958`、`entry/src/main/ets/reader/ReaderCanvasSurface.ets:325`（`apply` 返回 crossing 时换窗口） | 已接 | 拖到章末继续拖，会无缝接上下一章正文，不需要松手再翻一次。 | 滚动到章末继续拖，看是否进入下一章 | 已设备验证 | `readConfig` |
| 滚动边界钳制（到顶/到底不再跟手） | `feature/reader/core/transition/ReaderScrollState.kt:109-114` | `entry/src/main/ets/reader/ReaderCanvasSurface.ets:325-340`（`apply` 的 `hitBoundary`） | 已接 | 一致。 | 滚到全书第一页继续往上拖，看是否停住 | 依据源码推断，未设备验证 | `readConfig` |
| 滚动动画开关 | `feature/reader/core/gesture/ReaderGestureSettingsPolicy.kt:27` | `entry/src/main/ets/pages/ReaderPage.ets:1860` | 已接 | 一致。 | 关掉滚动动画后点翻页，看是否瞬移 | 依据源码推断，未设备验证 | `readConfig` |

### D4 长按选词与选区

| 上游能力 | 上游位置(文件:行) | 本地位置(文件:行) | 状态 | 差异说明 | 验收方式 | 备注 | ZIP 类别 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 长按选中一个**词**（系统分词器），落点吸附到词边界 | `feature/reader/core/selection/ReaderSelection.kt:201-250`、`:181-199` | `entry/src/main/ets/pages/ReaderPage.ets:3999-4036`（`startCanvasSelectionAt` → `wordRangeAt`）、`ReaderCanvasSurface.ets:1609-1625`（`getWordBoundary`） | 已接 | 一致：都用系统分词器取整词。 | 长按正文中间的一个词，看是否整词被选中 | 依据源码推断，未设备验证 | `不备份` |
| 选区范围：跨当前页 + 下两页，**不含上一页** | `feature/reader/core/selection/ReaderSelection.kt:21-22` | `entry/src/main/ets/pages/ReaderPage.ets:4038`（`dragCanvasSelectionTo` 只在当前页几何里命中） | 未接 | 本地选区**只能在本页内拖**，拖到页面边缘不会继续往下页扩展。要选跨页的一段文字，本地做不到；上游可以一路拖到下两页。 | 长按选词后往下拖到屏幕底部，看选区是否继续扩展到下一页 | 依据源码推断，未设备验证 | `不备份` |
| 选区把手：竖线 2dp + 圆环半径 7dp，白阴影，热区半径 28dp 胶囊 | `feature/reader/ReaderCanvasSurface.kt` 选区绘制、`feature/reader/core/selection/ReaderSelection.kt:68-104` | `entry/src/main/ets/reader/ReaderCanvasSurface.ets:1372-1445`（`drawSelection`）、`ReaderPage.ets:3727-3728`（`vp2px(7)` / `vp2px(2)`） | 已接 | 一致：把手半径 7、描边 2。 | 长按出选区，看两个把手是否可见 | 依据源码推断，未设备验证 | `不备份` |
| 把手交叉时自动交换起止（拖过头不会变成零长选区） | `feature/reader/core/selection/ReaderSelection.kt:68-104` | `entry/src/main/ets/pages/ReaderPage.ets:4161`（`canvasHandleHit` 命中判定） | 已接 | 一致：抓到哪个把手就拖哪个。 | 把结束把手拖到起始把手左边，看选区是否翻转 | 依据源码推断，未设备验证 | `不备份` |
| 选区高亮色 `0x63858585`（39% 灰） | `feature/reader/ReaderCanvasSurface.kt` 选区绘制 | `entry/src/main/ets/reader/ReaderCanvasSurface.ets:1372-1445` | 已接 | 一致。 | 看选中文字底色 | 依据源码推断，未设备验证 | `不备份` |
| 拖选闸门（必须先长按再拖，直接拖不选区） | `feature/reader/core/selection/ReaderSelectionDragState.kt:11-19` | `entry/src/main/ets/pages/ReaderPage.ets:4587`（`canvasSelectionDragging = canvasHandleHit(...)`） | 已接 | 一致。 | 不按长按直接横拖，看是否出现选区 | 依据源码推断，未设备验证 | `不备份` |
| 选区清除时机（点空白、翻页、开菜单都清） | `feature/reader/core/selection/ReaderSelectionLifecyclePolicy.kt:9-10` | `entry/src/main/ets/pages/ReaderPage.ets:3970-3988`（`resetCanvasSelectionState`）、`:1966` 翻页 `onFinish` 调用 | 已接 | 一致。 | 选中文字后翻页，看选区是否消失 | 依据源码推断，未设备验证 | `不备份` |
| 无障碍选区快照 | `feature/reader/core/accessibility/ReaderAccessibilityPolicy.kt:13-21` | 无 | 未接 | 读屏软件在本地画布上**读不到正文**（画布是纯绘制，没有无障碍节点）。 | 开读屏，听是否能朗读正文 | 依据源码推断，未设备验证 | `不备份` |

### D5 划词菜单（形态与位置）

> 菜单项本体 18 项、两套形态、项级显隐已由 [ZIP-BOOKMARK.md](ZIP-BOOKMARK.md) F 块 34 行盘过，**本块不重复**。这里只盘弹出位置、卡片形态、动画。

| 上游能力 | 上游位置(文件:行) | 本地位置(文件:行) | 状态 | 差异说明 | 验收方式 | 备注 | ZIP 类别 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| **菜单默认贴选区下沿**，让开末端选择柄（预留 14dp 净空）；下方不够且上方够才翻到上方 | `ui/book/read/TextActionSelectionMenu.kt:674-735` | `entry/src/main/ets/pages/ReaderPage.ets:4252`（`refreshCanvasSelectionMenuAnchor`：默认 `bottomVp + 14 + 12`，下方放不下且上方放得下才翻上，最后夹进屏幕） | 已接 | 菜单默认出现在选区下方，并给末端选择柄留 14vp 净空，手指不会挡住菜单；只有下方放不下、上方又放得下时才翻到上方。 | 选中页面顶部的一段文字，看菜单是否仍弹在选区下方（或翻到上方但不越界） | 已设备验证（选区在第 13~14 行时菜单落在第 17 行下方） | `readConfig` |
| 菜单卡片（圆角 12dp、最大宽 = 屏宽 − 32dp、展开态阴影 12dp / 快捷态 6dp） | `ui/book/read/TextActionSelectionMenu.kt:178-221` | `entry/src/main/ets/pages/ReaderPage.ets:3257-3277`（`backgroundColor('#242127')`、`borderRadius(12)`） | 已接 | 一致：圆角 12、深色底。本地无阴影。 | 看菜单卡片圆角与底色 | 依据源码推断，未设备验证 | `readConfig` |
| 折叠态一行横向滚动快捷条（首项左距 16dp、项间 10dp、右端分隔线 + 三点钮） | `ui/book/read/TextActionSelectionMenu.kt:167-265` | `entry/src/main/ets/pages/ReaderPage.ets:3257`（`Flex(wrap: expandTextMenu ? Wrap : NoWrap)`） | 未接 | 本地折叠态是**一行不滚动的 Flex**，项多了会被挤压或溢出屏幕；上游是一行可横向滚动。 | 开 8 个菜单项，看折叠态是否能横向滑动 | 依据源码推断，未设备验证 | `readConfig` |
| 「更多」二级弹层：主卡缩到 0.96、透明度 0.82（400ms/360ms），二级卡从三点钮向下展开，列表最高 240dp 可竖滚，底部「编辑菜单项」 | `ui/book/read/TextActionSelectionMenu.kt:196-272`、`:621-655` | `entry/src/main/ets/pages/ReaderPage.ets:3257-3277`（点「更多」在同一张卡片下方就地展开，`selectionMenuMoreVisible`） | 未接 | 本地**没有二级弹层**：点「更多」后是**整张卡片变高**、所有项一起显示（代码注释自认「本地没有 Popup 层」）。卡片会盖住大半个屏幕，且没有「编辑菜单项」入口。 | 点划词菜单的「更多」，看是弹出新卡片还是卡片原地变高 | 依据源码推断，未设备验证 | `readConfig` |
| 菜单入场动画（淡入 360ms + 0.94→1 缩放 400ms）/ 退场（淡出 320ms + 1→0.96 缩放 280ms） | `ui/book/read/SelectionMenuMotion.kt:21-49` | 无（本地直接出现/消失） | 未接 | 本地菜单**瞬间出现**，没有缩放淡入，视觉上比较生硬。 | 选中文字，看菜单是渐变出现还是瞬间出现 | 依据源码推断，未设备验证 | `readConfig` |
| 菜单重锚定（选区变化时菜单跟着移动） | `feature/reader/core/selection/ReaderSelectionLifecyclePolicy.kt:12-17` | `entry/src/main/ets/pages/ReaderPage.ets:3929`（`paintReaderCanvas` 尾部调 `refreshCanvasSelectionMenuAnchor`） | 已接 | 一致：拖把手时菜单跟着走。 | 拖选区把手，看菜单是否跟着移动 | 依据源码推断，未设备验证 | `readConfig` |

### D6 书签与进度条

| 上游能力 | 上游位置(文件:行) | 本地位置(文件:行) | 状态 | 差异说明 | 验收方式 | 备注 | ZIP 类别 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 下拉加书签（80dp 上膛、最多跟 60% 页高） | `feature/reader/core/gesture/PullBookmarkGesture.kt:12-19`、`:58-78` | `entry/src/main/ets/pages/ReaderPage.ets:1811`（`updateBookmarkPull`：`offsetY >= 80`、钳到 `viewportHeight*0.6`） | 已接 | 一致：80dp 与 60%。 | 在页面上往下拉 80dp，看是否出现「松手以添加书签」 | 依据源码推断，未设备验证 | `readConfig` |
| 下拉提示气泡（14sp、`0xA0000000`、圆角 24dp、淡入 120ms） | `feature/reader/ReaderCanvasSurface.kt:1840-1864`、`PullBookmarkGesture.kt:16-19` | `entry/src/main/ets/pages/ReaderPage.ets:4651-4660`（`backgroundColor('#A0000000')`、`borderRadius(24)`、`margin top 72`） | 已接 | 一致：底色与圆角相同。 | 下拉时看提示气泡样式 | 依据源码推断，未设备验证 | `readConfig` |
| 本页已有书签时下拉**删除**最近一条并提示「已移除书签」 | `ui/book/read/ReadBookmarkDelegate.kt:99-137` | `entry/src/main/ets/pages/ReaderPage.ets:1811-1822`（`bookmarkWillRemove` → 「松手以取消书签」） | 已接 | 一致：提示文案不同（「松手以取消书签」vs「已移除书签」），行为相同。 | 在有书签的页下拉，看提示是否为取消 | 依据源码推断，未设备验证 | `readConfig` |
| 书签跳转校验（书源指纹 + 章节标题都对直接跳，否则弹「仍然跳转」确认） | `ui/book/read/ReadBookmarkNavigateDelegate.kt:42-95` | `entry/src/main/ets/data/ReaderBookmarkTarget.ets:39-60`（`verify` 返回 `match`/`sourceChanged`/`titleMismatch`）、`entry/src/main/ets/pages/Index.ets:1745`（`askJumpAnyway` 确认弹层）、`:1795-1830`（`openReaderBookmark` 走校验） | 已接 | 改过目录规则或换过编码后点一条旧书签，本地**会先核对章节标题**，对不上就弹「位置可能已偏移 / 取消 / 仍跳转」，不会闷头跳到错误章节。 | 改一次目录规则，再点改动前存下的书签，看是否弹确认 | 该能力提交 `883e95d` 早于本表首次落盘，属**本表漏记**而非本轮新做；依据源码推断，未设备验证 | `bookmark` |
| 进度条换章按钮（左右各一枚 40×40） | `ui/book/read/ReadBookMenuBarBottom.kt` | `entry/src/main/ets/pages/ReaderPage.ets:4750-4793`（左 40×40 换章 + Slider + 右 40×40 换章） | 已接 | 一致。 | 看进度条左右是否有换章按钮 | 依据源码推断，未设备验证 | `readConfig` |
| 进度条页码无障碍值（`第 x 页，共 y 页` / `第 x 章，共 y 章`） | `ui/book/read/ReadBookMenuBarBottom.kt:84-95`、`:193`（`accessibilityValue`） | `entry/src/main/ets/pages/ReaderPage.ets:2578`（`getProgressAccessibilityText`）、`:5334`（`Slider.accessibilityText`） | 已接 | 读屏用户在进度条上听到「第 8 页，共 15 页」或「第 8 章，共 572 章」，与上游同一句。**注意：上游与本地都没有可见的页码文字**，滑块旁本来就不印字，本行只盘无障碍值。 | 开读屏（TalkBack/屏幕朗读）聚焦进度条，听是否念出页码 | 原差异说明「上游滑块旁有第 3 / 共 12 页」经复核有误：`ReadBookMenuBarBottom.kt` 全文无可见 `Text` 页码，只有 `accessibilityValue`；`uitest dumpLayout` 不导出 `accessibilityText`，未设备验证 | `readConfig` |
| 跨章边界：到章末继续翻进入下一章 | `feature/reader/core/navigation/ReaderPageNavigator.kt:121-126`、`ReaderPartialPagePolicy.kt:94-103` | `entry/src/main/ets/pages/ReaderIndex.ets`→`Index.ets:6815-6825`（`onTurnChapterBoundary` 直接 `selectChapter`） | 已接 | 一致：翻到章末自动进下一章。 | 翻到一章最后一页再翻，看是否进入下一章 | 依据源码推断，未设备验证 | `readConfig` |
| 章边界「加载中」占位页 | `feature/reader/core/navigation/ReaderPageNavigator.kt:82-92`、`ui/book/read/ReadBookController.kt:3009-3027` | `entry/src/main/ets/pages/ReaderPage.ets:4186-4203`（`showChapterBoundaryMessage`）、`:4166-4171`（`appendBoundaryPlaceholders`）、`:4173-4177`（`messagePlaceholderPage`）、`entry/src/main/ets/reader/ReaderCanvasSurface.ets:1394-1417`（`drawMessagePage`） | 已接 | 在章末再翻一页，正文区**整屏居中亮出「加载数据中…」**，新章正文到达后自动撤掉；5 秒没等到就自行清空，不会把提示页永远留在屏幕上。 | 翻到本章最后一页再点下一页，看是否出现居中的「加载数据中…」 | 设备验证 ✔（hilog `[Boundary] show` → `[BoundaryDraw] 加载数据中…` → 换章后 `[Boundary] clear`，`tmp3/h3.txt`）；居中口径照抄上游 `centeredReaderMessagePage`（整块垂直居中） | `readConfig` |
| 连续滚动到章末的「继续滑动以加载下一章…」提示页 | `feature/reader/core/navigation/ReaderPageNavigator.kt:101-102`、`ui/book/read/ReadBookController.kt:3029-3037` | `entry/src/main/ets/pages/ReaderPage.ets:4186-4203`（同一入口按 `usesCanvasScroll()` 换文案）、`:2009-2014`（`applyReaderScrollDelta` 章末分支） | 已接 | 连续滚动模式滑到本章最底，屏幕上**浮出「继续滑动以加载下一章…」**，告诉用户还能继续往下而不是到头了。分页模式同一处给的是「加载数据中…」。 | 切到「滚动」翻页动画，一直往下滑到章末，看是否出现提示页 | 设备验证 ✔（同上一条日志；文案按 `usesCanvasScroll()` 二选一，与上游 `keep_swipe_tip` / `data_loading` 对应） | `readConfig` |
| 越界提示（第一页往前/最后一页往后） | `feature/reader/core/navigation/ReaderPageNavigator.kt:104-108`（页码钳制 `hitBoundary`） | `entry/src/main/ets/pages/Index.ets:6815-6825`（提示「没有上一页」/「没有下一页」） | 已接 | 一致：都有越界提示。 | 在全书第一页往前翻，看是否提示 | 依据源码推断，未设备验证 | `readConfig` |
| 按章内位置定位（`ReaderPartialPagePolicy`：恢复进度时回到章内偏移） | `feature/reader/core/navigation/ReaderPageNavigator.kt:134-139`、`:180-186` | `entry/src/main/ets/pages/ReaderPage.ets:3527`（`updateProgress`）、`:3563`（`seekToProgress`）、`:1290`（`pendingBookmarkTargetPosition`） | 已接 | 一致：退出重进能回到原来的章内位置。 | 读到一章中间退出，重进看是否回到原位置 | 依据源码推断，未设备验证。BOOKSHELF C 块已盘记录侧 | `readRecord` |
| 章节内页码缓存（二分查页） | `feature/reader/core/navigation/ReaderChapterPaginationSnapshot.kt:12-21` | `entry/src/main/ets/pages/LocalReaderPaginator.ets:321`（`countPagesIncrementally`） | 已接 | 一致：都是增量/二分。 | 在长章里快速拖动进度条，看是否卡 | 依据源码推断，未设备验证 | `不备份` |

### D7 目录跳转

| 上游能力 | 上游位置(文件:行) | 本地位置(文件:行) | 状态 | 差异说明 | 验收方式 | 备注 | ZIP 类别 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 点章目跳转到该章第一页 | `ui/book/toc/TocScreen.kt`、`TocViewModel.kt` | `entry/src/main/ets/pages/CatalogPage.ets`（章节行点击 → `selectChapter`） | 已接 | 一致。 | 点目录里第 10 章，看是否跳到第 10 章开头 | 依据源码推断，未设备验证 | `readConfig` |
| 跨章定位（从书签/搜索/笔记跳到指定章内偏移） | `feature/reader/core/navigation/ReaderPageNavigator.kt:134-139` | `entry/src/main/ets/pages/ReaderPage.ets:1290`（`onBookmarkTargetChanged` → `pendingBookmarkTargetPosition` → `rebuildReaderPages(true)`） | 已接 | 一致。 | 从书签列表点一条，看是否跳到该位置 | 依据源码推断，未设备验证 | `bookmark` |
| 目录跳转加载态 | `ui/book/toc/TocScreen.kt`（下载中转圈 20dp） | 无 | 不适用 | 本地全离线，章节内容从本地文件读，无下载态。 | — | 范围差异：本地无在线下载 | `不备份` |
| 全文搜索（逐章搜索、命中上限 200 条、正则模式带 500ms 预算） | `feature/reader/core/selection/ReaderSearchMatcher.kt:22-41`、`:49-58`（`REGEX_MATCH_TIMEOUT_MILLIS = 500`）、`utils/RegexDeadlineSequence.kt` | `entry/src/main/ets/pages/ReaderSearchPage.ets:224`（调 `ReaderSearchRegex.run`）、`:226`（`timedOutChapterCount++` 后跳过该章）、`entry/src/main/ets/data/ReaderSearchRegex.ets:47`（`MATCH_TIMEOUT_MILLIS = 500`）、`:68`（`Promise.race` 超时） | 已接 | 正则搜索**单章超过 500ms 就放弃该章继续往下搜**，`(a+)+$` 这类灾难性回溯不会再把搜索页卡死；非法正则仍提示「正则表达式无效」。 | 用 `(a+)+$` 搜一本大书，看搜索是否还能走完、是否只是跳过若干章 | ArkTS 拿不到上游那种逐字符回调，改用 taskpool worker + `Promise.race` 做同等预算；依据源码推断，未设备验证 | `不备份` |
| 搜索结果高亮摘录（命中前后各 12 字符） | `feature/reader/core/selection/ReaderSearchMatcher.kt:94-107` | `entry/src/main/ets/pages/ReaderSearchPage.ets:275`（`highlightedExcerpt`） | 已接 | 一致。 | 搜一个词，看结果里是否高亮 | 依据源码推断，未设备验证 | `不备份` |
| 搜索左右箭头（正文两侧悬浮圆钮，还有前后结果时才出现） | `ui/book/read/ReadBookSearchBar.kt:24-95` | `entry/src/main/ets/pages/ReaderPage.ets:5451-5478`（两侧 44×44 圆钮，`searchNavIndex > 0` / `< length - 1` 才显示） | 已接 | 从搜索结果跳进正文后，**屏幕左右边缘各有一枚圆形箭头**，点一下就跳到上/下一个命中并自动定位到那一页；已经是第一个/最后一个时对应箭头消失。 | 从搜索结果跳进正文，看左右是否有箭头；点右箭头看是否到下一个命中、页码与结果条是否同步 | 设备验证 ✔（`tmp3/shots/al.jpeg` 左侧箭头 + 底部结果条；点右箭头后 `1 / 200` → `2 / 200`、章名 `第1章` → `第4章`） | `不备份` |
| 搜索底部结果条（「当前/总数 + 百分比 + 章名」+ 三枚按钮 2:1:0.55） | `ui/book/read/ReadBookMenuBarSearch.kt`（`SearchBottomMenuContent`） | `entry/src/main/ets/pages/ReaderPage.ets:5480-5532`（信息 pill + 三枚按钮）、`:5449`（`searchResultOverlayVisible`） | 已接 | 搜索结果跳进正文后，**屏幕底部浮出一条胶囊**：左边「1 / 200」、中间「1%」小标签、竖分隔线、右边当前章名；下面一行三枚按钮「所有结果 / ⋮ / ✕」。原来跳进正文后完全不知道还有几个结果。 | 见上行；另看底部 pill 的数字是否随箭头变化 | 设备验证 ✔（`tmp3/shots/al.jpeg`：`1 / 200`、`1%`、`第1章 盗神林川`、`所有结果`）；三按钮权重 2 : 1 : 0.55 照抄上游 | `不备份` |
| 搜索收起优先级（点遮罩时先收搜索条，再点才收主菜单） | `ui/book/read/ReadBookMenuBar.kt:126-167`（`ReaderMenuDismissLayer`） | 无 | 不适用 | 本地没有「阅读页内的搜索浮层」这层结构：搜索是独立页面（`AppRoute.READER_SEARCH`），结果条只在正文上浮一层、和主菜单互斥显示（`searchResultOverlayVisible` 要求 `!controlsVisible`），点遮罩先收菜单是唯一合理的顺序，不存在「先收搜索条」这一步。 | 打开菜单后再点遮罩，确认菜单直接收起、搜索条不受影响 | 平台/架构差异：本地搜索结果条不是与主菜单同级的浮层，没有两级 dismiss 可排；行为上用户感知不到差别 | `不备份` |

## 覆盖证明

分母来自目录，不是关键词。**分母范围 = 任务书指定的 6 个目录 + `model/ReadBook.kt` 单文件**，不是整个 `io/legado/app`（整个上游树有上千个 `.kt`，其中 AI、朗读、书源、RSS、漫画、备份 UI 都与本链路无关，盘了只会稀释分母）：

```
feature/reader          ui/book/read        ui/book/toc
help/book               help/storage        model/localBook
+ model/ReadBook.kt
```

用 `find <目录> -name '*.kt'` 实测得 **217** 个文件，逐个分配到下方各表。**未分配数 = 0。**

判据（每个文件都必须能在这里找到）：
```
for f in <上述 6 目录 + ReadBook.kt 的 find 结果>; do
  grep -qF "$(basename $f .kt)" docs/parity/TXT-READER.md || echo "未分配 $f"
done
```

### 1. `feature/reader/` 68 个

**顶层 3 个**

| 文件 | 行数 | 归属 |
| --- | --- | --- |
| `ReaderCanvasSurface.kt` | 3747 | 映射 B1/B3/B4/B5 多行（绘制顺序、预取窗口、五种转场、滚动、fling、选区把手） |
| `ScrollPageDrawCache.kt` | 67 | 映射 B3「滚动模式整页 PixelMap 缓存」 |
| `ReaderBackgroundBandDraw.kt` | 39 | 映射 B4「文字背景合并成连续色带」（本地无对应） |

**`core/accessibility/` 1 个**：`ReaderAccessibilityPolicy.kt`(22) → 映射 D4「无障碍选区快照」

**`core/cast/` 4 个** —— **已排除：朗读角色胶囊，属 TTS 链路**
`CastCapsuleGeometry.kt`(130)、`CastCapsuleStyle.kt`(92)、`CastMarkers.kt`(256)、`CastSyntax.kt`(108)。
理由：这四个文件只被 `ui/book/read/ReadAloudCastDelegate.kt` 与 `CastRenderOptions.kt` 消费，绘制的是朗读时的说话人气泡与背景音标记。TTS 朗读在 `docs/PROJECT.md` 范围之外，且本地 TXT 阅读链路不经过它们。

**`core/gesture/` 5 个**

| 文件 | 行数 | 归属 |
| --- | --- | --- |
| `PullBookmarkGesture.kt` | 79 | 映射 D6「下拉加书签」「下拉提示气泡」 |
| `ReaderGestureSettingsPolicy.kt` | 28 | 映射 D2「拖动阈值」、D3「滚动动画开关」、D2「翻页手势与拖选解耦」 |
| `ReaderMainAxisPolicy.kt` | 14 | 映射 D2「横向拖动跟手」 |
| `ReaderPageViewportLayout.kt` | 70 | 映射 D3「滚动跨页」「滚动边界钳制」 |
| `ReaderTapAction.kt` | 79 | 映射 D1「3×3 九宫格」「每格动作可选」「脏值按无动作」 |

**`core/layout/` 6 个**

| 文件 | 行数 | 归属 |
| --- | --- | --- |
| `ChineseLineBreaker.kt` | 232 | 映射 B1「中文标点避头尾」 |
| `ReaderChapterBlockMeasurer.kt` | 771 | 映射 B2「小图阈值」「坏图占位」「图片布局模式」 |
| `ReaderColumnMode.kt` | 24 | 映射 B1「双页模式四档」 |
| `ReaderLayoutMath.kt` | 45 | 映射 B1「整窗重排」（几何换算工具，无独立界面） |
| `ReaderPaginator.kt` | 1172 | 映射 B1「两端对齐」「底部对齐」 |
| `ReaderTextShaper.kt` | 51 | 映射 B1「整窗重排」（文字整形入口，无独立界面） |

**`core/model/` 14 个**

| 文件 | 行数 | 归属 |
| --- | --- | --- |
| `ReaderBackgroundAlpha.kt` | 4 | 映射 B7「文字背景透明度 0~100」 |
| `ReaderBookmarkBadge.kt` | 41 | 映射 B6「书签角标尺寸/位置」「尺寸 0 时隐藏」 |
| `ReaderEmphasisUnderlineRun.kt` | 53 | 映射 B4「下划线 6 种线型」（强调下划线合并） |
| `ReaderImageCachePolicy.kt` | 10 | 映射 B3「图片缓存两种尺寸各一份」 |
| `ReaderImageDrawLayout.kt` | 80 | 映射 B2「图片布局模式解析」 |
| `ReaderNineSliceLayout.kt` | 116 | 映射 B2「九宫格切片缩放」 |
| `ReaderPage.kt` | 445 | 映射 B2「图片大小 0.1~5」「九宫格等比缩放」 |
| `ReaderPageColorTransform.kt` | 78 | 映射 B7「换主题即时换色」 |
| `ReaderPageContentClip.kt` | 90 | 映射 B4「绘制顺序」（裁剪层，含在绘制顺序行内） |
| `ReaderTextBackgroundRun.kt` | 81 | 映射 B7「文字背景图」 |
| `ReaderTipColor.kt` | 5 | 映射 B6「页眉页脚颜色 0 = 跟随正文」 |
| `ReaderTipRowLayout.kt` | 21 | 映射 B6「页眉页脚行高」 |
| `ReaderTipValue.kt` | 98 | 映射 B6「14 种取值 / 12 占位符」「页数未知显示 -」 |
| `ReaderUnderlineRun.kt` | 39 | 映射 B4「下划线合并成连续段」 |

**`core/navigation/` 3 个**

| 文件 | 行数 | 归属 |
| --- | --- | --- |
| `ReaderChapterPaginationSnapshot.kt` | 22 | 映射 D6「章节内页码缓存」 |
| `ReaderPageNavigator.kt` | 284 | 映射 B3「四页预取窗口」、D6「跨章边界」「加载中占位页」「第三槽提示」「越界提示」「按章内位置定位」 |
| `ReaderPartialPagePolicy.kt` | 132 | 映射 D6「跨章边界」「按章内位置定位」 |

**`core/readaloud/` 2 个** —— **已排除：TTS 朗读链路**
`ReaderReadAloudChapter.kt`(190)、`ReaderVisibleTextPositionPolicy.kt`(81)。
理由：前者把章节切成朗读段落、后者计算朗读高亮位置，都只在 `ReadAloudBookSession` 里使用。朗读不在范围。

**`core/selection/` 7 个**

| 文件 | 行数 | 归属 |
| --- | --- | --- |
| `ReaderSearchMatcher.kt` | 108 | 映射 D7「全文搜索」「搜索结果高亮摘录」 |
| `ReaderSelection.kt` | 273 | 映射 D4「长按选词」「选区范围」「把手交叉」「选区高亮色」 |
| `ReaderSelectionBounds.kt` | 31 | 映射 D4「选区高亮合并」（含在选区高亮色行内） |
| `ReaderSelectionCoordinates.kt` | 28 | 映射 D4「长按选词」（坐标换算，含在该行内） |
| `ReaderSelectionDragState.kt` | 20 | 映射 D4「拖选闸门」 |
| `ReaderSelectionLifecyclePolicy.kt` | 18 | 映射 D4「选区清除时机」、D5「菜单重锚定」 |
| `ReaderSelectionMenuAnchor.kt` | 25 | 映射 D5「菜单默认贴选区下沿」 |

**`core/source/` 3 个**

| 文件 | 行数 | 归属 |
| --- | --- | --- |
| `ReaderBodyOnlyFilter.kt` | 135 | 映射 A3「正文折叠」 |
| `ReaderChapterSource.kt` | 259 | 映射 C1「标题 titleMode = 2 时整块隐藏」、A3「适配特殊样式」 |
| `ReaderTitleSegmentation.kt` | 41 | 映射 C1「章节标题渲染」 |

**`core/style/` 2 个**

| 文件 | 行数 | 归属 |
| --- | --- | --- |
| `ReaderBackgroundBounds.kt` | 87 | 映射 B4「文字背景合并成连续色带」 |
| `ReaderCharacterStyle.kt` | 113 | 映射 B7「高亮命中同位置多条规则时高优先级赢」 |

**`core/transition/` 6 个**

| 文件 | 行数 | 归属 |
| --- | --- | --- |
| `PageCurlGeometry.kt` | 243 | 映射 B4「折页三道阴影」「收尾下限 25%」「起始吸附 4%」「角点选择」 |
| `ReaderAutoPagePolicy.kt` | 19 | 映射 B4「自动翻页顶部 1px 指示条」 |
| `ReaderPageTransition.kt` | 232 | 映射 B4「五种转场」「覆盖阴影」「淡入阈值 0.1」「松手判定」「无邻页回弹」 |
| `ReaderPageTurnSpeed.kt` | 48 | 映射 B4「翻页速度四档」 |
| `ReaderScrollState.kt` | 125 | 映射 B5「滚动步距」「步进时长」「跨页」「章末钳回」 |
| `ReaderViewportLayerPolicy.kt` | 10 | 映射 B4「五种转场」（滚动固定层，含在该行内） |

**`legacy/` 5 个** —— 全部在用（「legacy」只是命名遗留，`ReadBookController.kt` 有 6 处调用）

| 文件 | 行数 | 归属 |
| --- | --- | --- |
| `LegacyReaderChapterPaginator.kt` | 406 | 映射 B1「段间距」「章末留白」「页眉页脚计入 padding」「视口 ≤0 不排版」、B2「图片布局模式」 |
| `LegacyReaderImageOptionsResolver.kt` | 81 | 映射 B2「图片布局模式解析」 |
| `LegacyReaderPageDecorationFactory.kt` | 340 | 映射 B6「页脚进度强制 99.9%」「页眉页脚行高」 |
| `LegacyReaderPaginationStyleFactory.kt` | 119 | 映射 B1「整窗重排」（样式装配，无独立界面） |
| `LegacyReaderStyleRangeMapper.kt` | 428 | 映射 B7「文字背景图」（排版期预热） |

**`platform/` 7 个**

| 文件 | 行数 | 归属 |
| --- | --- | --- |
| `AndroidReaderHtmlSourceResolver.kt` | 208 | **已排除：Android 平台专属**。依赖 `HtmlCompat.fromHtml()` 与 `Spanned`，ArkUI 无等价物（本地 `<usehtml>` 走 `LocalTextSemantics.ets` 的简化解析，已在 A3「适配特殊样式」行覆盖）。 |
| `AndroidReaderTextShaper.kt` | 105 | **已排除：Android 平台专属**。`StaticLayout` 文字整形，本地对应 `@ohos.graphics.text` 的 `ParagraphBuilder`，行为在 B1「整窗重排」行覆盖。 |
| `ReaderAndroidPaginationStyle.kt` | 47 | **已排除：Android 平台专属**。`TextPaint` 载体，ArkUI 无等价物；其 `excludeActionImages` 字段注释明确「尚未接线、生产恒 false」，无用户可感知行为。 |
| `ReaderBookmarkBadgeRenderer.kt` | 97 | 映射 B6「书签角标」「没有自定义角标图时画丝带」 |
| `ReaderPageDecorationDrawCache.kt` | 166 | 映射 B4「下划线 6 种线型」 |
| `ReaderPerfTrace.kt` | 54 | **已排除：性能追踪，无界面**。只在 `SDK≥Q && Trace.isEnabled()` 时打 `Trace.beginSection`，用户不可感知。 |
| `ReaderTextBackgroundLoader.kt` | 156 | 映射 B7「文字背景图」 |

### 2. `ui/book/read/` 顶层 50 个

| 文件 | 行数 | 归属 |
| --- | --- | --- |
| `BookmarkBadgeDelegate.kt` | 91 | 映射 B6「滚动翻页模式下不画书签角标」 |
| `EyeProtection.kt` | 149 | 映射 C7「护眼配置面板」 |
| `MarkingContract.kt` | 33 | 映射 C7「划线样式面板」（接口定义，无独立界面） |
| `MarkingDelegate.kt` | 286 | 映射 C7「划线样式面板」 |
| `MarkingSelectionMenu.kt` | 592 | 映射 C7「划线样式面板」（16 预设色 + 7 效果 + 笔记框） |
| `ReadAiContract.kt` | 95 | **已排除：AI 链路**。AI 清洗/改写/对话的接口定义，AI 不在范围。 |
| `ReadAiDelegate.kt` | 1431 | **已排除：AI 链路**。AI 清洗/改写/对话实现，AI 不在范围。 |
| `ReadAloudCapsule.kt` | 458 | **已排除：TTS 朗读链路**。 |
| `ReadAloudCastDelegate.kt` | 617 | **已排除：TTS 朗读链路**。 |
| `ReadAloudControlsRequestBus.kt` | 25 | **已排除：TTS 朗读链路**。 |
| `ReadAloudDelegate.kt` | 676 | **已排除：TTS 朗读链路**。 |
| `ReadBookColorPickerIds.kt` | 15 | 映射 C4「快捷面板」、C2「顶栏」的配色入口（12 个 colorPickerId 定义） |
| `ReadBookColorTheme.kt` | 350 | 映射 C7「背景文字配置面板」（配色主题） |
| `ReadBookContract.kt` | 2083 | 映射 C6「更多操作 28 项 id」、C2/C3 顶栏底栏契约 |
| `ReadBookController.kt` | 3355 | 映射 B2「图片尺寸解出后只重绘不重排」、D1「正中格优先级」「图片点击四档」「正文内元素点击」、D5「菜单默认贴选区下沿」 |
| `ReadBookFloatingActionBar.kt` | 153 | 映射 C2「快速动作图标行」 |
| `ReadBookLoadDelegate.kt` | 444 | 映射 A1「打开与加载」（加载流程，无独立界面；其界面结果由 C1 首帧保护行覆盖） |
| `ReadBookMenuBar.kt` | 1044 | 映射 C3「底栏浮动」、D7「搜索收起优先级」 |
| `ReadBookMenuBarBottom.kt` | 461 | 映射 C3「底栏图标行」「进度条按页/按章」「亮度条」「进度条隐藏」 |
| `ReadBookMenuBarFloating.kt` | 428 | 映射 C2「浮动图标行」 |
| `ReadBookMenuBarSearch.kt` | 201 | 映射 D7「搜索底部结果条」 |
| `ReadBookMenuBarShared.kt` | 117 | 映射 C2「顶栏底色透明度」 |
| `ReadBookMenuBarTitle.kt` | 1014 | 映射 C2「顶栏骨架」「标题栏模式四值」「标题胶囊」「点标题胶囊进详情」「合并按钮组」「长按二级菜单」 |
| `ReadBookMenuBarTool.kt` | 478 | 映射 C3「底栏图标下方文字」「净化条数徽标」 |
| `ReadBookRouteScreen.kt` | 1181 | 映射 D6「下拉加书签」（路由层，书签提示挂载点 `:742-743`） |
| `ReadBookScreen.kt` | 944 | 映射 C1「正文区三块结构」、A1「手动指定编码」（`CharsetConfigSheet` 触发点 `:808-812`） |
| `ReadBookSearchBar.kt` | 92 | 映射 D7「搜索左右箭头」 |
| `ReadBookViewModel.kt` | 2749 | 映射 C3「进度条按页/按章」「滚动停下 250ms 后才刷新」 |
| `ReadBookmarkDelegate.kt` | 187 | 映射 D6「本页已有书签时下拉删除」 |
| `ReadBookmarkNavigateDelegate.kt` | 135 | 映射 D6「书签跳转校验」 |
| `ReadButtonConfigDelegate.kt` | 231 | 映射 C7「浮动栏图标配置」 |
| `ReadConfigUpdateBus.kt` | 21 | **已排除：配置变更事件总线，无界面**。它是 `ReadConfigUpdateDelegate` 的消息通道，界面结果在 READER-CONFIG.md E 块已有行。 |
| `ReadConfigUpdateDelegate.kt` | 898 | **已排除：配置热更新，无独立界面**。它把设置变更广播到已打开的阅读页，用户可见结果是「改设置后正文立刻变」，已由 B1「整窗重排」行覆盖。 |
| `ReadContentEditContract.kt` | 22 | 映射 C7「内容编辑面板」（接口定义） |
| `ReadContentEditDelegate.kt` | 267 | 映射 C7「内容编辑面板」 |
| `ReadContentProcessDelegate.kt` | 169 | 映射 C7「文本处理面板」 |
| `ReadHighlightRuleContract.kt` | 22 | 映射 C7「高亮规则编辑」（接口定义） |
| `ReadHighlightRuleDelegate.kt` | 386 | 映射 C7「高亮规则编辑」 |
| `ReadMenuActionDefs.kt` | 517 | 映射 C6「条目适用性」、C2「顶栏动作上限」 |
| `ReadRecordAliasDelegate.kt` | 104 | **已排除：阅读记录别名，界面在别处**。归 [BOOKSHELF.md](BOOKSHELF.md) C 块「别名归属」行。 |
| `ReadReplaceRuleDelegate.kt` | 93 | 映射 C7「文本处理面板」 |
| `ReadStyleDelegate.kt` | 638 | 映射 C4「快捷面板」 |
| `ReaderContentAvoidancePolicy.kt` | 49 | 映射 C1「隐藏状态栏后仍按状态栏高留白」「菜单开合不触发重排」 |
| `ReaderFirstFrame.kt` | 36 | **已排除：调试探针，无界面**。只在 debug 构建打两行 `phase=loading` / `phase=content` 日志。 |
| `ReaderRenderUiState.kt` | 54 | 映射 C1「首帧保护」 |
| `ReaderViewport.kt` | 117 | 映射 C1「等待视口最多 2 秒」 |
| `ReadingProgressSyncDelegate.kt` | 55 | **已排除：进度同步，本地无云同步**。同步在范围之外；本地对应物是 `BookRepository` 的本地进度写入，已由 [BOOKSHELF.md](BOOKSHELF.md) C 块覆盖。 |
| `SelectionMenuMotion.kt` | 55 | 映射 D5「菜单入场/退场动画」 |
| `TextActionSelectionMenu.kt` | 725 | 映射 D5「菜单默认贴选区下沿」「菜单卡片」「折叠态横向滚动」「更多二级弹层」 |
| `TranslationThinkingCapsule.kt` | 57 | **已排除：翻译链路**。翻译不在范围。 |

**`config/` 7 个** —— 全部映射 B4「下划线 6 种线型」
`SolidUnderlineSpan.kt`(62)、`DashUnderlineSpan.kt`(64)、`DoubleUnderlineSpan.kt`(66)、`WaveUnderlineSpan.kt`(81)、`SvgUnderlineSpan.kt`(75)、`SvgPathParser.kt`(410)、`HighlightStyleSpan.kt`(23)。

**`page/` 3 个**

| 文件 | 行数 | 归属 |
| --- | --- | --- |
| `entities/PageDirection.kt` | 4 | 映射 C1「标题独占一页」 |
| `entities/TitleSegment.kt` | 6 | 映射 C1「章节标题渲染」 |
| `provider/TitleStyleParser.kt` | 52 | 映射 C1「章节标题渲染」 |

**`pageestimate/` 8 个** —— 全部映射 C3「进度条」与 D6「页码显示」

| 文件 | 行数 | 归属 |
| --- | --- | --- |
| `HeuristicPageEstimator.kt` | 39 | 映射 D6「进度条页码显示」（估算每页容量，本地未接） |
| `ChapterPageEstimator.kt` | 29 | 同上 |
| `ExactChapterPageCountStore.kt` | 81 | 同上 |
| `PageEstimateCalibrationStore.kt` | 158 | 同上（4 样本拟合校准） |
| `PageEstimateConfig.kt` | 161 | 同上（斜率 0.3..3.0、截距 −2..5） |
| `PageEstimateMetrics.kt` | 110 | 同上（估算误差指标，无独立界面） |
| `WholeBookPageIndex.kt` | 132 | 同上 |
| `WholeBookPageCoordinator.kt` | 416 | 同上（全书页码协调器，本地未接） |

### 3. `ui/book/read/sheet/` 46 个

| 文件 | 行数 | 归属 |
| --- | --- | --- |
| `ReadStyleSheet.kt` | 151 | 映射 C4「快捷面板两页横向分页」「底部四个 tab」 |
| `GlobalThemePage.kt` | 562 | 映射 C4「全局页」「字号滑杆右侧 56dp 排版卡」 |
| `SystemMenuPage.kt` | 905 | 映射 C4「菜单系统页三页分页」、C2「浮动图标行」 |
| `ThemeListContent.kt` | 882 | 映射 C7「主题列表」 |
| `TypographyPage.kt` | 345 | 映射 C7「排版页七个子页」 |
| `TypographyTabs.kt` | 1250 | 映射 C7「排版正文 5 分区」「字重」「标题 4 分区」「页眉 3 分区」「页脚 3 分区」「边距」「tip 类型 21 种」 |
| `MoreConfigSheet.kt` | 466 | 映射 A2「无规则命中时按固定长度分章」（页面控制分区含 3000..100000 步长 100） |
| `TextProcessingSheet.kt` | 602 | 映射 C7「文本处理面板」 |
| `ContentProcessesSheet.kt` | 270 | 映射 C7「文本处理记录面板」 |
| `EffectiveReplacesSheet.kt` | 168 | 映射 C7「生效规则面板」 |
| `ReaderMoreActionsSheet.kt` | 473 | 映射 C6「每页 8 格」「末尾配置项」「28 项 id」「带箭头的 3 项」「enabled && applicable」 |
| `HighlightRuleConfigSheet.kt` | 294 | 映射 C7「高亮规则编辑」 |
| `HighlightRuleEditSheet.kt` | 1459 | 映射 C7「高亮规则编辑」（5 分区 + 九宫格编辑器） |
| `UnderlineConfigSheet.kt` | 163 | 映射 C7「下划线配置面板 8 项」 |
| `MarkingSheet.kt` | 469 | 映射 C7「划线样式面板」 |
| `ClickActionConfigSheet.kt` | 230 | 映射 D1「每格动作可选」、C7「点击区域配置面板」 |
| `PageKeyConfigSheet.kt` | 147 | 映射 D2「翻页手势」（音量键翻页键位配置，属 D2 手势族；本地未接，见备注） |
| `PageAnimConfigSheet.kt` | 48 | 映射 C7「翻页动画下拉 7 项」 |
| `CharsetConfigSheet.kt` | 79 | 映射 A1「手动指定编码」 |
| `ContentEditSheet.kt` | 205 | 映射 C7「内容编辑面板」 |
| `ReaderBookSheet.kt` | 1433 | 映射 C5「目录页四页签」「目录头部」「目录工具行」「章节行多级缩进」「多选浮层」「书签导出默认文件名」「笔记页」 |
| `FloatingBarIconConfigSheet.kt` | 150 | 映射 C7「浮动栏图标配置」 |
| `CustomTipTarget.kt` | 58 | 映射 B6「页眉页脚 14 种取值」（6 个自定义 tip 位置） |
| `BgTextConfigSheet.kt` | 311 | 映射 C7「背景文字配置面板」 |
| `AutoReadSheet.kt` | 173 | 映射 C7「自动翻页面板」 |
| `EyeProtectionConfigSheet.kt` | 133 | 映射 C7「护眼配置面板」 |
| `ShadowSetSheet.kt` | 106 | 映射 C7「阴影设置面板 5 项」 |
| `TextSelectMenuConfigSheet.kt` | 460 | 映射 C7「选词菜单配置面板」 |
| `ToolButtonConfigSheet.kt` | 22 | 映射 C3「底栏图标行」（工具按钮配置壳，本地走 `ReaderSettingsPage.ets:2880-2932`） |
| `SimulatedReadingSheet.kt` | 126 | **已排除：模拟朗读**。朗读不在范围；本地对应条目 `simulated_reading` 落「尚未迁移」提示，已在 C6「3 个带更多箭头」行记录 |
| `DownloadSheet.kt` | 82 | **已排除：离线下载，本地书全离线** |
| `ReaderAudioDownloadSheet.kt` | 424 | **已排除：朗读音频下载** |
| `ChangeChapterSourceSheet.kt` | 338 | **已排除：换源，本地无书源** |
| `ChapterSummarySheet.kt` | 137 | **已排除：AI 章节摘要** |
| `PhotoSheet.kt` | 105 | **已排除：图片查看器**。它只服务漫画与书源图集，本地 TXT 无此入口 |
| `AiCastDialogSheet.kt` | 1280 | **已排除：AI 朗读角色分配** |
| `AiRewritePresetConfigSheet.kt` | 208 | **已排除：AI 改写预设** |
| `AiTextCleanSheet.kt` | 220 | **已排除：AI 清洗** |
| `AiTextRewriteSheet.kt` | 461 | **已排除：AI 改写** |
| `BgmSceneSheet.kt` | 336 | **已排除：背景音，属朗读链路** |
| `BgmSceneTableSheet.kt` | 355 | **已排除：背景音，属朗读链路** |
| `CastSheetCard.kt` | 228 | **已排除：朗读角色卡** |
| `ReadAloudCastSheet.kt` | 325 | **已排除：朗读角色分配** |
| `ReadAloudConfigContent.kt` | 619 | **已排除：朗读配置** |
| `ReadAloudConfigUiMapping.kt` | 37 | **已排除：朗读配置映射** |
| `ReadAloudScreen.kt` | 250 | **已排除：朗读界面** |

### 4. `ui/book/toc/` 10 个

| 文件 | 行数 | 归属 |
| --- | --- | --- |
| `TocScreen.kt` | 1259 | 映射 A2「目录层级缩进」、C5「粘性卷头」「自动滚到当前章」「状态图标」「FAB 四项」 |
| `TocViewModel.kt` | 1141 | 映射 A4「目录字数默认开启」、C5「目录搜索卷名永远保留」 |
| `TocHierarchy.kt` | 86 | 映射 C5「卷折叠」 |
| `DownloadState.kt` | 8 | **已排除：下载状态枚举**，本地无下载。 |
| `rule/TxtRuleScreen.kt` | 472 | 映射 A2「目录规则编辑页」 |
| `rule/TxtTocRuleContract.kt` | 65 | 映射 A2「目录规则编辑页」（契约定义） |
| `rule/TxtTocRuleViewModel.kt` | 215 | 映射 A2「目录规则编辑页」 |
| `rule/preview/TxtTocRulePreviewScreen.kt` | 483 | 映射 A2「目录规则预览页」 |
| `rule/preview/TxtTocRulePreviewContract.kt` | 60 | 映射 A2「目录规则预览页」（契约定义） |
| `rule/preview/TxtTocRulePreviewViewModel.kt` | 273 | 映射 A2「目录规则预览页」 |

### 5. `help/book/` 7 个

| 文件 | 行数 | 归属 |
| --- | --- | --- |
| `ContentProcessor.kt` | 297 | 映射 A3「替换净化在切章之后」「净化管线十步顺序」「替换规则超时自动禁用」「简繁转换」 |
| `ContentHelp.kt` | 627 | 映射 A3「重新分段按标点集切」 |
| `BookContent.kt` | 18 | 映射 A1「打开与加载」（章节内容载体，无独立界面） |
| `BookExtensions.kt` | 747 | **已排除：数据层扩展，无界面**。它是 `Book` 的扩展方法集合，读 `readGateway` 拿配置副本，界面在 A–D 块已有行。 |
| `BookHelp.kt` | 1116 | **已排除：书籍仓储，界面在别处**。本地对应 `data/BookRepository.ets`，其行为已在 A1/A2 块逐行覆盖。 |
| `BookImageFileStore.kt` | 223 | **已排除：EPUB 图片存储**，本地 TXT 无此链路。 |
| `ChapterImageCache.kt` | 9 | **已排除：EPUB 图片缓存**。 |

### 6. `help/storage/` 8 个

| 文件 | 行数 | 归属 |
| --- | --- | --- |
| `Backup.kt` | 406 | **已排除：备份写侧，界面在备份模块**。它把 `config.xml` 与 `bookshelf` 打包，阅读相关键由 [READER-CONFIG.md](READER-CONFIG.md) 与本表「ZIP 类别」列覆盖。 |
| `Restore.kt` | 609 | **已排除：备份读侧**。同上。 |
| `BackupConfig.kt` | 489 | **已排除：备份键表**。本表「ZIP 类别」列的判据来源，不产生行。 |
| `RestoreConfigNormalizer.kt` | 58 | **已排除：恢复时配置规范化**。影响的是「恢复后设置是否合法」，用户可见结果已由 A1「改编码后重载」与 B1「整窗重排」行覆盖。 |
| `BackupAES.kt` | 10 | **已排除：备份加密算法**。 |
| `BackupRestoreLock.kt` | 15 | **已排除：备份互斥锁**。 |
| `ImportOldData.kt` | 369 | **已排除：旧数据导入**，属书架模块，归 [BOOKSHELF.md](BOOKSHELF.md)。 |
| `BookRestorePlanner.kt` | 171 | **已排除：恢复计划**。它决定恢复时哪些书重建索引，界面结果在 [BOOKSHELF.md](BOOKSHELF.md) E 块。 |

### 7. `model/localBook/` 9 个

| 文件 | 行数 | 归属 |
| --- | --- | --- |
| `TextFile.kt` | 519 | 映射 A1「编码自动识别」「流式解析」「空文件报错」、A2「无规则命中时分章」「单章超 102400 字节拆分」「第一个标题前插前言」「规则库为空自愈」「规则语法错误跳过」、A4「正文 8MB 窗口缓存」 |
| `TxtTocRuleSelector.kt` | 66 | 映射 A2「目录规则自动选择」 |
| `LocalBook.kt` | 649 | 映射 A2「章节标题为空补无标题章节」「章节标题去重」、A2「目录层级 tocLevel」 |
| `LocalBookImportPlanner.kt` | 42 | 映射 A1「打开与加载」（导入规划，无独立界面） |
| `BaseLocalBookParse.kt` | 21 | 映射 A1「打开与加载」（解析基类，无独立界面） |
| `EpubFile.kt` | 449 | **已排除：EPUB 专属**。EPUB 目录、字体内嵌、样式表不在本表范围。 |
| `MobiFile.kt` | 318 | **已排除：MOBI 格式**，本地不支持。 |
| `PdfFile.kt` | 228 | **已排除：PDF 格式**，本地不支持。 |
| `UmdFile.kt` | 122 | **已排除：UMD 格式**，本地不支持。 |

### 8. `model/ReadBook.kt` 1 个

| 文件 | 行数 | 归属 |
| --- | --- | --- |
| `ReadBook.kt` | 2141 | 映射 A1「改编码后清正文缓存」、D6「按章内位置定位」。其中 `AUTO_SAVE_INTERVAL = 120000`（`:223`）、`MIN_READ_DURATION = 10000`（`:225`）、`PROGRESS_SAVE_DEBOUNCE_MS = 300`（`:1852`）三个硬编码常量属阅读记录写入，已由 [BOOKSHELF.md](BOOKSHELF.md) C 块覆盖，本表不重复。 |

### 未分配清点

```
$ for f in $(find <上述 6 目录> -name '*.kt') <...>/model/ReadBook.kt; do
    grep -qF "$(basename $f .kt)" docs/parity/TXT-READER.md || echo "未分配 $f"
  done
（无输出：total=217 missing=0）
```

**217 个文件全部有归属：映射到表格行 170 个、已排除 47 个。** 47 个的排除理由分三类：

| 排除理由 | 个数 | 文件（均已排除） |
| --- | --- | --- |
| 平台专属，ArkUI 无等价物 | 3 | `AndroidReaderHtmlSourceResolver`、`AndroidReaderTextShaper`、`ReaderAndroidPaginationStyle` |
| 无独立界面，纯数据层/事件总线/调试探针 | 5 | `BookExtensions`、`ReadConfigUpdateBus`、`ReadConfigUpdateDelegate`、`ReaderFirstFrame`、`ReaderPerfTrace` |
| 范围外（AI / 朗读 / 背景音 / 下载 / 换源 / 翻译 / 漫画 / EPUB 之外的格式 / 备份写读 / 阅读记录别名 / 进度同步） | 39 | 见下表 |

范围外的 39 个逐个点名，均已排除：
`AiCastDialogSheet`、`AiRewritePresetConfigSheet`、`AiTextCleanSheet`、`AiTextRewriteSheet`、`Backup`、`BackupAES`、`BackupConfig`、`BackupRestoreLock`、`BgmSceneSheet`、`BgmSceneTableSheet`、`BookHelp`、`BookImageFileStore`、`CastSheetCard`、`ChangeChapterSourceSheet`、`ChapterImageCache`、`ChapterSummarySheet`、`DownloadSheet`、`DownloadState`、`EpubFile`、`ImportOldData`、`MobiFile`、`PdfFile`、`PhotoSheet`、`ReadAiContract`、`ReadAiDelegate`、`ReadAloudCapsule`、`ReadAloudCastSheet`、`ReadAloudConfigContent`、`ReadAloudConfigUiMapping`、`ReadAloudControlsRequestBus`、`ReadAloudDelegate`、`ReadAloudScreen`、`ReadRecordAliasDelegate`、`ReaderAudioDownloadSheet`、`ReadingProgressSyncDelegate`、`RestoreConfigNormalizer`、`SimulatedReadingSheet`、`TranslationThinkingCapsule`、`UmdFile`。

复核脚本（`scripts/` 下临时脚本跑完即删，口径写在这里）：
```python
# 分母来自目录，不用关键词
for d in ['feature/reader','ui/book/read','ui/book/toc','help/book',
          'help/storage','model/localBook']:
    walk(上游根/d) 里所有 .kt
再补 model/ReadBook.kt
# 每个文件在 TXT-READER.md 里能找到文件名 → 有归属
# 命中的行全部标注「已排除」→ 已排除，否则 → 映射到表格行
```

## 小结

### 按块统计

| 块 | 条数 | 已接 | 未接 | 不适用 |
| --- | --- | --- | --- | --- |
| A 规则层（TXT 特有） | 31 | 17 | 13 | 1 |
| B 引擎层（TXT 与 EPUB 共用） | 54 | 39 | 14 | 1 |
| C 界面层 | 79 | 59 | 14 | 6 |
| D 交互层 | 48 | 37 | 9 | 2 |
| **合计** | **212** | **152** | **50** | **10** |

数字核对脚本（**注意**：表里有两行图例 `| 状态 | 已接 | 未接 | 不适用 |`，直接 `grep -c` 会各多算 2，所以要先排除图例行；含 `\|` 转义的行也必须按转义分列，否则少算 3 行）：

```bash
# 逐行按「未转义的 |」分列，取第 4 列判状态
python - <<'PY'
import re
lines = open('docs/parity/TXT-READER.md', encoding='utf-8').read().split('\n')
n = {'已接': 0, '未接': 0, '不适用': 0}
for l in lines:
    if not l.startswith('| '):
        continue
    s = l.strip().strip('|')
    cells = re.split(r'(?<!\\)\|', s)
    if len(cells) == 8 and cells[3].strip() in n:
        n[cells[3].strip()] += 1
print(n, sum(n.values()))   # {'已接': 152, '未接': 50, '不适用': 10} 212
PY

# 表格行内不得出现第四种状态词
grep -nE '^\|.*\|\s*(部[分]|基[本]|待[定])' docs/parity/TXT-READER.md   # 用字符类写，避免本行自己命中
```

### 一句话结论

**翻页、滚动、阅读页顶底栏、目录页与搜索结果条都已与上游对齐**——第一批十行（拖拽跟手、松手判定、滚动逐帧与跨页、抬手惯性、中文避头尾、逐列底部对齐、章末留白、图片不跳版、菜单贴下沿）+ 第二批九行（标题点进详情、合并胶囊分隔线、顶栏 6 个动作、模糊透明度实时预览、正文处理角标、滚动进度 250ms 节流、进度条无障碍文案、竖排亮度条双按钮、隐藏进度条保留换章按钮）+ 第三批十二行（目录搜索保留卷名、`tocLevel` 多级缩进、粘性卷头、目录多选、书签跳转校验复核、进度条无障碍值复核、章边界「加载数据中…」占位页、滚动章末提示页、正则 500ms 预算、搜索左右箭头、底部结果条、搜索收起优先级）落地后，**从打开一本书到翻目录、搜正文、跳结果的整条路径**都能对着上游用；剩下 50 行未接集中在**各二级面板的字段/形态**（排版页七子页、页眉页脚 21 种 tip、高亮规则编辑器、主题列表、文本处理面板）与**绘制细节**（分层绘制、6 种下划线、九宫格、文字背景图、覆盖阴影）。

### 对阅读手感影响最大的前 5 条（剩余未接行中）

> 前三批已落地，下面这份榜单只从**尚未接的 50 行**里挑，避免拿已修好的项占位。

1. **绘制不分层，下划线被选区盖住**（B4）—— 上游 `ReaderCanvasSurface.kt:2767-2869` 分四层画（文字背景色带 / 正文 / contentRules / styledUnderlines / overlayRules），本地 `ReaderCanvasSurface.ets:1183-1222` 跟着每个 box 一起画。选中一段带下划线的文字时**下划线被选区灰块压掉**，overlay 规则也盖不到文字之上。
2. **下划线只有系统线型**（B4）—— 上游 6 种手绘线型（虚线 10-10、双线、波浪振幅 3dp/波长 12dp、SVG、半高线），本地只有系统 `TextDecorationType`。高亮规则里选「波浪下划线」画出来是**一条直线**，高亮规则的表达力差一大截。
3. **文字背景图完全不支持**（B7）—— 上游 `ReaderTextBackgroundLoader` 在排版期预热、异步解码只重绘不重排；本地没有这条链路。给规则配一张气泡背景图，**本地什么都不会出现**。
4. **排版页只有一页，上游有七个子页**（C6）—— 上游 `TypographyPage.kt:55-345` 把排版拆成「排版 2 / 信息 2 / 边距 3」共 7 页，字重、下划线、标题位置与分段方式、页眉页脚字号都在里面；本地只有一个排版入口。想调「标题分段方式」或「副标题缩放」的用户**在本地找不到任何入口**。
5. **页眉页脚只能选 20 种固定组合，上游是 21 种 tip 自由拼**（C6）—— 上游 `TypographyTabs.kt:1234-1250` 的 tip 类型有 21 种，左中右三槽可任意组合、可自定义模板；本地是 type 1..20 的固定枚举。想要「左：书名 / 中：章名 / 右：电量+时间」这种组合**拼不出来**。

### 次一级（值得排期但影响面小）

- 更多操作面板 28 项 id 与「带更多箭头的条目」（C4）
- 高亮规则编辑只有 6 个字段、无实时预览与九宫格编辑器（C7）
- 划线样式面板的 16 个预设色与 7 种效果（C7）
- 主题列表的网格列数/管理态 7 个动作/前 5 个内置不可删（C7）
- 下划线配置面板 8 项（C7）、文字背景透明度 0~100（B7）
- 自动翻页无顶部 1px 进度提示（B4）、覆盖转场无 36dp 阴影（B4）、淡入阈值未降为 0.1（B4）
- 菜单折叠态一行横向滚动快捷条 + 「更多」二级弹层与出入场动画（D5）

## 维护

### 新增行的约定

1. **先确认不是重复。** 新行若属 [READER-CONFIG.md](READER-CONFIG.md) 已覆盖的**设置字段**，不新增；若是该字段的**界面形态**（几个 tab、卡片尺寸、入口位置），可以新增，但「差异说明」必须写形态而非字段。
2. **分母要更新。** 上游新增 `.kt` 文件时，同步更新「覆盖证明」对应小节的表，并在该节末尾重跑清点脚本。**分母只来自目录，不用关键词**——这是本表与 `scripts/upstream-surface.sh --coverage` 的根本区别。
3. **一行 = 一次用户可感知的操作或一处可见界面元素。** 同一个行为拆成「判断逻辑」「赋值」「刷新」三行属凑数，合并成一行。
4. **八列必须填满。** 「上游位置」要能点开对得上行；「本地位置」写不到具体行就写「无」；「备注」凡未上设备验证的必须写「依据源码推断，未设备验证」。
5. **ZIP 类别按「这行要改代码时会不会动到某个备份类别的键或文件」判。** 取值只有 `localBook` / `readConfig` / `txtTocRule` / `replaceRule` / `bookmark` / `readRecord` / `themeConfig` / `themeMode` / `—`（参与备份但不受忽略开关控制）/ `不备份`。跨类写 `A / B`。判据见 [BACKUP-RESTORE.md](../BACKUP-RESTORE.md)。

### 改状态的约定

1. **状态只有三值。** `已接` / `未接` / `不适用`，不设中间态。想表达「一部分做了」，拆成两行，或按**用户能不能感知到完整行为**判。
2. **`已接` 必须能指到屏幕位置。** 「验收方式」列要写出「哪个页面、哪个区域、什么现象」。只写「函数在、分支在」不算，退回 `未接`。
3. **`不适用` 只用于「上游有、本平台不该有」。** 理由要具体到平台差异（如「Android 的 `AppCompatDelegate.setDefaultNightMode` 在 ArkUI 无等价物」「本地无书源」），不能写「架构不同」。
4. **改 `未接` → `已接` 时同步更新「小结」的三个计数与合计。** 用脚本核，不手数。
5. **已知未完成项（fling、折页跟手、滚动拖拽方向）在实现落地后**，把对应行的状态改 `已接` 并把「备注」里的引用删掉，同时在 `docs/KNOWN-ISSUES.md` 里销项。
6. **发现新的本地缺陷不要顺手改代码。** 记进 `docs/KNOWN-ISSUES.md`，本表只登记差异。

